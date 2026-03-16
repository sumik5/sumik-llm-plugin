---
name: managing-docker
description: Docker image management including layers, registries, manifests, multi-architecture, content addressing, and vulnerability scanning.
---

# Docker イメージ管理

イメージはアプリケーション実行に必要なすべてを含む読み取り専用パッケージです。アプリケーションコード、依存関係、最小限のOS構成要素、メタデータが含まれます。

## 用語の統一

以下の用語はすべて同義：
- Image
- Docker image
- Container image
- OCI image

## イメージの基本概念

### イメージとコンテナの関係

| 特性 | イメージ | コンテナ |
|-----|---------|---------|
| **ライフサイクル** | ビルド時 | ランタイム |
| **状態** | 読み取り専用 | 読み書き可能 |
| **比喩（VM）** | VM template | 実行中のVM |
| **比喩（OOP）** | Class | Object/Instance |
| **多重度** | 1つ | 複数起動可能 |

### イメージサイズの特徴

| OS | 一般的なサイズ | 例 |
|-----|-------------|-----|
| Linux | 数MB〜数百MB | Alpine: 3MB, NGINX: 80MB, Redis: 40MB |
| Windows | GB単位 | 非常に大きい |

**軽量化の理由**:
- カーネルは含まない（ホストのカーネルを使用）
- 実行時に不要なツールは除外
- "Just enough OS"のみ

### Slim Images

最近のトレンド：
- シェル不要
- パッケージマネージャー不要
- ビルドツール不要
- トラブルシューティングツール不要

**原則**: 実行時に不要なものはすべて削除。

## イメージの取得

### Local Repository

| 用語 | 説明 |
|-----|------|
| **Local repository** | ローカルマシン上のイメージ保存領域 |
| **Image cache** | 同上（別名） |
| **Linux保存場所** | `/var/lib/docker/<storage-driver>` |
| **Docker Desktop** | Docker VM内 |

### イメージ確認

```bash
# ローカルイメージ一覧
docker images

# digest付き一覧
docker images --digests

# 特定イメージのみ
docker images alpine
```

### イメージのpull

```bash
# 基本形式
docker pull <repository>:<tag>

# 例：公式リポジトリ
docker pull redis:latest
docker pull redis:8.0-M02
docker pull busybox:glibc
docker pull alpine  # latestタグが暗黙的

# 非公式リポジトリ
docker pull myuser/tu-demo:v2

# 別レジストリ
docker pull ghcr.io/regclient/regsync:latest
```

### Dockerの暗黙的な挙動

pullコマンド実行時の自動判断：

| 省略時 | Dockerの判断 |
|-------|-------------|
| タグ未指定 | `latest`タグを使用 |
| レジストリ未指定 | Docker Hubを使用 |

**注意**: `latest`タグは必ずしも最新ではない。

## レイヤー構造

### レイヤーの概念

イメージは独立した読み取り専用レイヤーの集合：
- 各レイヤーは1つ以上のファイルで構成
- Dockerがスタックして単一オブジェクトとして提示
- レイヤーは複数イメージ間で共有可能

### レイヤー確認方法

#### 1. pullコマンド出力

```bash
$ docker pull redis
Using default tag: latest
latest: Pulling from library/redis
08df40659127: Download complete
4f4fb700ef54: Already exists    # ← 既存レイヤー
57dea0f129a5: Download complete
f546e941f15b: Download complete
...
```

`Already exists`: ローカルに既存のレイヤー（重複ダウンロード回避）

#### 2. docker inspect

```bash
$ docker inspect node:latest

"RootFS": {
    "Type": "layers",
    "Layers": [
        "sha256:c8a75145fc...894129005e461a43875a094b93412",
        "sha256:c6f2b330b6...7214ed6aac305dd03f70b95cdc610",
        "sha256:055757a193...3a9565d78962c7f368d5ac5984998",
        ...
    ]
}
```

SHA256ハッシュで各レイヤーを識別。

#### 3. docker history

```bash
$ docker history <image>
```

**注意**: ビルド履歴を表示（最終イメージのレイヤーリストではない）。
- `ENV`, `EXPOSE`, `CMD`, `ENTRYPOINT`はメタデータのみでレイヤーを作らない

### Base Layer

すべてのイメージは**base layer**から開始：
1. Base layer（例: Ubuntu 24.04）
2. 追加レイヤー（例: Python）
3. アプリケーションレイヤー

### レイヤーのスタッキング

#### ファイルの更新

上位レイヤーのファイルが下位レイヤーのファイルを隠蔽：

```
Layer 3: [File 1, File 2, File 7 (更新版)]
Layer 2: [File 3, File 4, File 5]
Layer 1: [File 6]

統合ビュー: File 1, 2, 3, 4, 6, 7 (6ファイル)
※ Layer 2のFile 5はLayer 3のFile 7で隠蔽
```

### Storage Driver

レイヤーのスタッキングと統合ビュー提供を担当：

| Driver | 特徴 |
|--------|------|
| **overlay2** | ほぼすべての環境でデフォルト |
| zfs | 代替オプション |
| btrfs | 代替オプション |
| vfs | 代替オプション |

**ユーザー体験**: どのDriverを使用しても同じ操作感。

### レイヤー共有

#### メリット

- **ストレージ効率化**: 同じレイヤーは1度だけ保存
- **ネットワーク効率化**: 既存レイヤーはダウンロード不要
- **レジストリ効率化**: レジストリ側でも1コピーのみ

#### 共有の仕組み

```
Image A: [Layer 1] [Layer 2] [Layer 3]
Image B: [Layer 1] [Layer 4] [Layer 5]

実際の保存: Layer 1（共有）, Layer 2, Layer 3, Layer 4, Layer 5
```

## Image Registries

### レジストリの役割

| 機能 | 説明 |
|-----|------|
| **集中管理** | イメージの中央保存 |
| **配布** | 複数環境からのアクセス |
| **セキュリティ** | 安全な保存と配布 |

### ワークフローにおける位置づけ

```
Build → Share (Registry) → Run
```

### レジストリの種類

| タイプ | 例 |
|-------|-----|
| **パブリッククラウド** | Docker Hub, GHCR, AWS ECR, GCP GCR |
| **プライベート** | オンプレミスレジストリ |
| **OCI準拠** | ほぼすべての現代的なレジストリ |

### レジストリ構造

```
Registry
  ├─ Repository A
  │   ├─ Image 1:tag1
  │   ├─ Image 1:tag2
  │   └─ Image 2:tag1
  ├─ Repository B
  └─ Repository C
```

## Docker Hub

### Official Repositories

**特徴**:
- Docker社とアプリベンダーによるキュレーション
- 最新で高品質なコード
- セキュアでよく文書化
- ベストプラクティス準拠

**識別方法**:
- トップレベルnamespace
- 緑色の"Docker Official Image"バッジ

**例**:
- `nginx`: https://hub.docker.com/_/nginx/
- `redis`: https://hub.docker.com/_/redis/
- `mongo`: https://hub.docker.com/_/mongo/

### Unofficial Repositories

**特徴**:
- セカンドレベルnamespace以下
- **デフォルトで信頼しない**
- インターネットからのソフトウェアと同様の注意

**例**:
- `myuser/gsd`
- `myuser/k8sbook`

**セキュリティ原則**: Official Imagesでも慎重に扱う。

## Image Naming

### 完全修飾名の構造

```
[registry]/[user or org]/[repository]:[tag]
```

**例**:
```
docker.io/myuser/myapp:v1.2
  ↑       ↑           ↑      ↑
registry  user     repository tag
```

### デフォルト値

| 省略要素 | デフォルト値 |
|---------|------------|
| registry | `docker.io` (Docker Hub) |
| tag | `latest` |

### Official Repository形式

```bash
# 形式
docker pull <repository>:<tag>

# 例
docker pull redis:latest
docker pull alpine  # ← alpine:latestと同義
```

### Unofficial Repository形式

```bash
# 形式
docker pull <username>/<repository>:<tag>

# 例
docker pull myuser/tu-demo:v2
```

### 別レジストリ形式

```bash
# 形式
docker pull <registry>/<repository>:<tag>

# 例
docker pull ghcr.io/regclient/regsync:latest
```

## Tagging

### 複数タグの設定

同一イメージに複数タグ付与可能：

```bash
$ docker images
REPOSITORY               TAG       IMAGE ID       CREATED
myuser/tu-demo     latest    b4210d0aa52f   2 days ago
myuser/tu-demo     v1        b4210d0aa52f   2 days ago  # ← 同じID
myuser/tu-demo     v2        6ba12825d092   12 mins ago
```

**注意**: `latest`が最新とは限らない（上記例では`v2`が最新）。

## Content Addressing

### 問題：タグの可変性

タグは以下の特性を持つ：
- **任意**: 自由に設定可能
- **可変**: 同じタグで異なるイメージを指定可能

**リスク例**:
1. `golftrack:1.5`に脆弱性発見
2. 修正版をビルド
3. **同じタグ**で再プッシュ
4. 本番環境でどちらのバージョンか判別不可

### 解決策：Image Digest

| 特性 | 説明 |
|-----|------|
| **Content hash** | イメージ内容の暗号ハッシュ |
| **一意性** | 異なるイメージは必ず異なるdigest |
| **不変性** | 内容変更で新しいdigestが生成 |

### Digest確認方法

#### ローカルイメージ

```bash
$ docker images --digests alpine
REPOSITORY   TAG     DIGEST                                    IMAGE ID
alpine       latest  sha256:c5b1261d...8e1ad6b                 c5b1261d6d3e
```

#### リモートイメージ（pull前）

```bash
# docker buildx imagetools使用
$ docker buildx imagetools inspect myuser/k8sbook:latest
Name:      docker.io/myuser/k8sbook:latest
MediaType: application/vnd.docker.distribution.manifest.list.v2+json
Digest:    sha256:13dd59a0c74e9a147800039b1ff4d61201375c008b96a29c5bd17244bce2e14b

# curlでレジストリAPIを直接クエリ
$ curl "https://hub.docker.com/v2/repositories/myuser/k8sbook/tags/?name=latest" \
  | jq '.results[].digest'
"sha256:13dd59a0c74e9a147800039b1ff4d61201375c008b96a29c5bd17244bce2e14b"
```

### Digestでのpull

```bash
$ docker pull myuser/k8sbook@sha256:13dd59a0...bce2e14b
```

**メリット**: 常に意図したイメージを取得可能。

## Digest詳細

### Image DigestとLayer Digest

| タイプ | ハッシュ対象 |
|-------|------------|
| **Image digest** | Image manifest file |
| **Layer digest** | Layer contents |

両方とも暗号ハッシュで、変更があれば新しいハッシュ生成。

### Content HashとDistribution Hash

**問題**: push/pull時の圧縮でハッシュが変わる

**解決策**: 各レイヤーに2つのハッシュ

| ハッシュ種別 | 用途 |
|-----------|------|
| **Content hash** | 非圧縮データ（ローカル） |
| **Distribution hash** | 圧縮データ（ネットワーク転送） |

**検証フロー**:
1. push/pull時にdistribution hash同梱
2. ネットワーク改竄をチェック
3. 展開後にcontent hashで検証

**注意**: CLI/レジストリ出力でハッシュが一致しない場合、content hashとdistribution hashの違いの可能性あり。

## Multi-Architecture Images

### 問題：アーキテクチャの多様化

Docker対応プラットフォーム：
- Linux/Windows
- x64, ARM, PowerPC, s390x など

従来の問題：
- アーキテクチャごとに異なるイメージ
- ユーザーが手動で選択
- Docker体験の複雑化

### 解決策：Manifest List

| 概念 | 説明 |
|-----|------|
| **Manifest list** | 対応アーキテクチャのリスト |
| **Manifest** | 各アーキテクチャ固有のイメージ情報 |

**仕組み**:
1. ユーザーが`docker pull alpine`実行
2. DockerがRegistry APIにmanifest list要求
3. 現在のアーキテクチャに一致するmanifest取得
4. 該当レイヤーをpull・組み立て

### アーキテクチャ確認

```bash
$ docker buildx imagetools inspect alpine
Name:      docker.io/library/alpine:latest
MediaType: application/vnd.docker.distribution.manifest.list.v2+json
Digest:    sha256:c5b1261d...f8e1ad6b

Manifests:
  Name:      docker.io/library/alpine:latest@sha256:6457d53f...628977d0
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  linux/amd64

  Name:      docker.io/library/alpine:latest@sha256:b229a851...d144c1d8
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  linux/arm/v6

  Name:      docker.io/library/alpine:latest@sha256:ec299a7b...33b4c6fe
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  linux/arm/v7
  ...
```

### マルチアーキテクチャビルド

#### docker buildx

2つのビルドモード：

| モード | 特徴 |
|-------|------|
| **Emulation** | QEMUで異なるアーキテクチャをエミュレート<br>- 動作は遅い<br>- キャッシュ共有なし |
| **Build Cloud** | クラウド上のネイティブハードウェアでビルド（Docker社サービス）<br>- 高速<br>- チーム間でキャッシュ共有<br>- GitHub Actions統合<br>- **有料サブスクリプション** |

#### ビルド例

```bash
# Build Cloudでマルチアーキテクチャビルド
$ docker buildx build \
  --builder=cloud-myuser-ddd-cloud \
  --platform=linux/amd64,linux/arm64 \
  -t myuser/tu-demo:latest --push .
```

## 脆弱性スキャン

### Docker Scout

**統合レベル**:
- Docker CLI
- Docker Desktop
- Docker Hub
- scout.docker.com ポータル

**注意**: **有料サブスクリプション必要**

### 基本スキャン

```bash
# クイック概要
$ docker scout quickview myuser/tu-demo:latest

  ✓ SBOM of image already cached, 66 packages indexed

Target             │  myuser/tu-demo:latest  │    0C     1H     1M     0L
  digest           │  b4210d0aa52f                 │
Base image         │  python:3-alpine              │    0C     1H     1M     0L
```

**重要度表記**:
- `C`: Critical（致命的）
- `H`: High（高）
- `M`: Medium（中）
- `L`: Low（低）

### 詳細スキャン

```bash
$ docker scout cves myuser/tu-demo:latest

    ✓ SBOM of image already cached, 66 packages indexed
    ✗ Detected 1 vulnerable package with 2 vulnerabilities

## Packages and Vulnerabilities
   0C     1H     1M     0L  expat 2.5.0-r2
pkg:apk/alpine/expat@2.5.0-r2?os_name=alpine&os_version=3.19

    ✗ HIGH CVE-2023-52425
      https://scout.docker.com/v/CVE-2023-52425
      Affected range : <2.6.0-r0
      Fixed version  : 2.6.0-r0
```

**提供情報**:
- 脆弱なパッケージ名
- CVE番号
- 影響バージョン
- 修正バージョン
- 詳細情報へのリンク

### Docker Desktop統合

- 視覚的なダッシュボード
- イメージごとの脆弱性表示
- Docker Hubとの統合

### scout.docker.comポータル

機能：
- 概要ダッシュボード
- ポリシー設定
- リモートレジストリ統合
- 複数リポジトリ監視

## イメージ削除

### 基本削除

```bash
# 単一削除
docker rmi <image>

# 複数削除
docker rmi redis:latest af111729d35a sha256:c5b1261d...f8e1ad6b
```

### 削除の挙動

| 状況 | 挙動 |
|-----|------|
| コンテナが使用中 | エラー（削除拒否） |
| 複数タグ付与 | 他タグも使用中なら削除拒否 |
| `-f`フラグ | 強制削除（注意が必要） |

**警告**: 使用中コンテナの強制削除は、イメージをuntagしdangling imageとして残す。

### 共有レイヤーの扱い

- 複数イメージで共有されるレイヤーは保持
- 最後の参照イメージ削除時にレイヤーも削除

### 全イメージ削除

```bash
# すべてのイメージを削除（注意！）
docker rmi $(docker images -q) -f
```

**警告**: 確認なしで実行されるため慎重に使用。

## 主要コマンドリファレンス

| コマンド | 説明 | 例 |
|---------|------|-----|
| **docker pull** | レジストリからイメージダウンロード | `docker pull alpine:latest` |
| **docker images** | ローカルイメージ一覧 | `docker images --digests` |
| **docker inspect** | イメージ詳細情報 | `docker inspect node:latest` |
| **docker manifest inspect** | Manifest list確認 | `docker manifest inspect golang` |
| **docker buildx imagetools** | マニフェスト情報クエリ | `docker buildx imagetools inspect alpine` |
| **docker scout quickview** | 脆弱性クイック概要 | `docker scout quickview <image>` |
| **docker scout cves** | 脆弱性詳細+修正案 | `docker scout cves <image>` |
| **docker rmi** | イメージ削除 | `docker rmi redis:latest` |
| **docker history** | ビルド履歴表示 | `docker history <image>` |

## チェックリスト: イメージ管理

- [ ] イメージとコンテナの違いを説明できる
- [ ] レイヤー構造の仕組みを理解している
- [ ] レイヤー共有のメリットを説明できる
- [ ] タグとdigestの違いを理解している
- [ ] Manifest listの役割を説明できる
- [ ] Content hashとdistribution hashの違いを理解している
- [ ] Official RepositoryとUnofficial Repositoryを区別できる
- [ ] Docker Scoutで脆弱性スキャンができる
- [ ] マルチアーキテクチャイメージの仕組みを理解している

## ベストプラクティス

### セキュリティ

1. **Official Images優先** - ただし慎重に扱う
2. **定期的な脆弱性スキャン** - Docker Scoutやその他ツール活用
3. **Digestの使用** - 本番環境では必須
4. **Slim Images** - 攻撃面を最小化

### パフォーマンス

1. **レイヤー共有の活用** - Base imageの統一
2. **不要なファイル除外** - .dockerignore活用
3. **マルチステージビルド** - ビルドツールを最終イメージから除外

### 運用

1. **タグ戦略** - セマンティックバージョニング
2. **レジストリ選定** - 要件に応じて適切なレジストリ選択
3. **定期的なクリーンアップ** - 未使用イメージの削除

## まとめ

Docker イメージは以下の特徴を持つ：
- **レイヤー構造**: 効率的な保存と転送
- **Content addressing**: digest による確実な識別
- **Multi-architecture**: 透過的なクロスプラットフォーム対応
- **レジストリ**: 集中管理と配布
- **脆弱性スキャン**: セキュリティ管理の統合

タグは可変で便利ですが、本番環境ではdigestによる確実な識別が推奨されます。
