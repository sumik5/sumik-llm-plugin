---
description: |
  OCI イメージ仕様、コンテナレジストリ運用、Universal Base Image（UBI）の選択と活用、Skopeo によるイメージ操作の実践ガイド。
  Use when managing container images, selecting base images, configuring registries, or performing image operations without running containers.
  Supplements SKILL.md with detailed image management procedures.
---

# イメージ管理リファレンス

## 1. OCI Image Specification

### 基本構造

OCI（Open Container Initiative）イメージは 4 要素で構成される:

| 要素 | 役割 |
|------|------|
| **Image Index** | マルチアーキテクチャ対応マニフェストのリスト |
| **Image Manifest** | 単一アーキテクチャのイメージ記述（config + layers 参照） |
| **Image Configuration** | 実行時設定（ENV, CMD, ENTRYPOINT 等）|
| **Filesystem Layers** | イミュータブルな tar.gz 差分レイヤー群 |

### Image Manifest の構造

```json
{
  "schemaVersion": 2,
  "config": {
    "mediaType": "application/vnd.oci.image.config.v1+json",
    "size": 7023,
    "digest": "sha256:b5b2b2c507a0944348e0303114d8d93aaaa081732b86451d9bce1f432a537bc7"
  },
  "layers": [
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "size": 32654,
      "digest": "sha256:9834876dcfb05cb167a5c24953eba58c4ac89b1adf57f28f2f9d09af107ee8f0"
    }
  ],
  "annotations": {
    "com.example.key1": "value1"
  }
}
```

**設計上の重要点**:
- `digest` は SHA-256 ハッシュ。イメージの内容変更で必ず変わる（改ざん検知）
- `layers` は積み重ね順に並ぶ。下から順に Union Filesystem でマウントされる
- `annotations` は任意のメタデータ。CI パイプラインのビルド情報等を埋め込める

---

## 2. コンテナレジストリの選択

### Docker Hub

- **Official Images**: Docker 社が curate するプログラム。セキュリティ審査・最新化が保証される
- **Docker Scout**: 脆弱性スキャン・SBOM 生成ツール（Pull 時に自動解析）
- **レート制限**: 匿名 100 pull/6h、認証済み 200 pull/6h。CI では必ず認証する

```bash
# Docker Hub ログイン
podman login docker.io

# Scout スキャン結果を含む inspect
podman image inspect docker.io/library/nginx:latest
```

### Quay.io

Red Hat が運営するエンタープライズ向けレジストリ。

- **Clair**: 自動脆弱性スキャン（CVE データベース照合）
- **ロボットアカウント**: CI/CD 向けサービスアカウント（人間アカウントとは分離）
- **パブリックリポジトリ**: 認証不要でプル可能

```bash
podman login quay.io
podman pull quay.io/<namespace>/<image>:<tag>
```

### Red Hat Container Registry

`registry.access.redhat.com`（認証不要）と `registry.redhat.io`（要認証）の 2 エンドポイント。

- UBI イメージは `registry.access.redhat.com` で無認証アクセス可
- RHEL 公式イメージは `registry.redhat.io` で Red Hat アカウントが必要
- 全イメージにセキュリティスキャン結果とコンテナグレードが付与される

---

## 3. registries.conf によるレジストリ信頼設定

### ファイル配置

| パス | スコープ |
|------|---------|
| `/etc/containers/registries.conf` | システム全体（要 root） |
| `$HOME/.config/containers/registries.conf` | ユーザー個別 |
| `/etc/containers/registries.conf.d/*.conf` | ドロップイン設定 |

### 基本構造

```toml
# 修飾子なし名前（例: nginx）の検索順
unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]

# デフォルトのレジストリ設定
[[registry]]
location = "registry.example.com"
insecure = false  # HTTPS を強制

# プレフィックスマッチで別レジストリにリダイレクト
[[registry]]
prefix = "example.com/foo"
location = "registry.example.com:5000/foo"

# ミラー設定（高速化・オフライン対応）
[[registry]]
location = "docker.io"

[[registry.mirror]]
location = "mirror.internal.example.com:5000"

# 悪意あるレジストリをブロック
[[registry]]
location = "registry.rogue.io"
blocked = true
```

### Short Name Aliases

修飾子なしイメージ名を特定レジストリに固定マッピングする:

```toml
# /etc/containers/registries.conf.d/000-shortnames.conf
[aliases]
  "fedora" = "registry.fedoraproject.org/fedora"
  "ubi8"   = "registry.access.redhat.com/ubi8"
  "ubi9"   = "registry.access.redhat.com/ubi9"
```

**利点**: `podman pull ubi8` が確定的に Red Hat レジストリからプルされる。プロンプト（対話的選択）が発生しない。

### AskUserQuestion が必要なケース

以下の場合はユーザーに確認する:
- `insecure = true` を設定する場合（HTTPS を無効化するセキュリティリスク）
- 社内ミラーレジストリの URL をハードコードする場合（環境依存）
- `blocked = true` を既存レジストリに追加する場合（既存イメージが取得不能になる）

---

## 4. Universal Base Image (UBI)

### 4 フレーバーの使い分け

| フレーバー | イメージ名 | サイズ目安 | パッケージマネージャー | 主な用途 |
|-----------|-----------|-----------|----------------------|---------|
| **Standard** | `ubi8` / `ubi9` | ~230MB | `yum` / `dnf` | 一般アプリケーション |
| **Minimal** | `ubi8-minimal` / `ubi9-minimal` | ~115MB | `microdnf` | 依存少ないアプリ |
| **Micro** | `ubi8/ubi-micro` / `ubi9/ubi-micro` | ~45MB | なし | マルチステージビルドの最終ステージ |
| **Init** | `ubi8-init` / `ubi9-init` | ~250MB | `yum` / `dnf` | systemd 必要なサービス |

### Standard UBI

```dockerfile
FROM registry.access.redhat.com/ubi8

RUN yum update -y && \
    yum install -y httpd && \
    yum clean all

EXPOSE 8080
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
```

### Minimal UBI

```dockerfile
FROM registry.access.redhat.com/ubi8-minimal

RUN microdnf upgrade -y && \
    microdnf install -y python3 && \
    microdnf clean all

COPY app.py /app/
CMD ["python3", "/app/app.py"]
```

### Micro UBI（マルチステージビルド）

```dockerfile
# ビルドステージ: Minimal で依存を揃える
FROM registry.access.redhat.com/ubi8-minimal AS builder
RUN microdnf upgrade -y && \
    microdnf install -y golang && \
    microdnf clean all
WORKDIR /src
COPY . .
RUN go build -o /app .

# 最終ステージ: Micro で最小イメージ
FROM registry.access.redhat.com/ubi8/ubi-micro:latest
COPY --from=builder /app /app
ENTRYPOINT ["/app"]
```

### Init UBI（systemd 対応）

```dockerfile
FROM registry.access.redhat.com/ubi8-init

RUN yum install -y httpd && yum clean all && \
    systemctl enable httpd

EXPOSE 80
# systemd が PID 1 として起動
# SIGRTMIN+3 でクリーンシャットダウン
```

```bash
# Init コンテナの起動（systemd には --privileged または特定の権限が必要）
podman run -d --name myservice \
  --systemd=true \
  my-init-image:latest
```

**SIGRTMIN+3**: systemd が認識するクリーンシャットダウンシグナル。通常の SIGTERM と区別される。

### UBI のライセンス

UBI は Red Hat サブスクリプションなしで配布・商用利用可能（ただし Red Hat RPM パッケージを追加した場合はサブスクリプション環境でのみ再配布可）。

---

## 5. Skopeo によるイメージ操作

Podman（実行）・Buildah（ビルド）・**Skopeo（イメージ操作）** が Podman エコシステムの三位一体。
Skopeo はコンテナを起動せずにレジストリ間のコピー・検査を行う。

### Transport 種別

| Transport | 書式 | 説明 |
|-----------|------|------|
| `docker://` | `docker://registry/image:tag` | リモートレジストリ（OCI Distribution API） |
| `containers-storage:` | `containers-storage:image:tag` | ローカル Podman ストレージ |
| `dir:` | `dir:/path/to/dir` | OCI 形式ディレクトリ |
| `docker-archive:` | `docker-archive:/path/file.tar` | Docker save 形式 tar |
| `docker-daemon:` | `docker-daemon:image:tag` | Docker デーモンのローカルストレージ |
| `oci:` | `oci:/path/to/dir:tag` | OCI イメージレイアウト |
| `oci-archive:` | `oci-archive:/path/file.tar` | OCI イメージレイアウト tar |

### イメージのコピー

```bash
# レジストリ間コピー（認証情報は自動利用）
skopeo copy \
  docker://docker.io/library/nginx:latest \
  docker://private-registry.example.com/lab/nginx:latest

# ローカルストレージ → リモートレジストリへ push
skopeo copy \
  containers-storage:quay.io/<namespace>/myapp \
  docker://quay.io/<namespace>/myapp:latest

# 別の認証ファイルを明示的に指定
skopeo copy \
  --authfile ${HOME}/.docker/config.json \
  docker://docker.io/library/ubuntu:22.04 \
  docker://mirror.internal.example.com/ubuntu:22.04

# マルチアーキテクチャイメージをそのままコピー
skopeo copy --all \
  docker://docker.io/library/golang:1.22 \
  docker://private-registry.example.com/golang:1.22
```

### イメージの検査

```bash
# マニフェスト・設定情報を JSON で取得
skopeo inspect docker://docker.io/library/nginx

# タグ一覧のみ取得（マニフェスト取得をスキップ）
skopeo inspect --no-tags docker://docker.io/library/nginx

# 利用可能なタグを一覧表示
skopeo list-tags docker://docker.io/library/nginx
skopeo list-tags docker://quay.io/<namespace>/myapp
```

### イメージの同期（sync）

リポジトリ全タグを一括でミラーリングする:

```bash
# レジストリ → ローカルディレクトリへ全タグ同期
skopeo sync \
  --src docker --dest dir \
  registry.example.com/lab/busybox /tmp/images

# --scoped: ソースパスをディレクトリ構造に保持
skopeo sync \
  --src docker --dest dir --scoped \
  registry.example.com/lab/busybox /tmp/images
# → /tmp/images/registry.example.com/lab/busybox:<tag> に保存される

# ローカルディレクトリ → レジストリへアップロード
skopeo sync \
  --src dir --dest docker \
  /tmp/images registry-mirror.example.com
```

### 認証情報の共有

`podman login` が保存した認証トークンは Skopeo・Buildah でも共有される:

```bash
# Podman でログイン（~/.config/containers/auth.json に保存）
podman login quay.io

# Skopeo は同じ auth.json を自動参照
skopeo copy \
  containers-storage:quay.io/<namespace>/app \
  docker://quay.io/<namespace>/app:v2.0

# 明示的に別ファイルを指定する場合
skopeo inspect \
  --authfile /path/to/auth.json \
  docker://registry.redhat.io/ubi9
```

---

## 6. イメージのベストプラクティス

### レイヤー最適化

```dockerfile
# 悪い例: RUN が分散するとレイヤーが増え、キャッシュが無効化されやすい
RUN yum update -y
RUN yum install -y httpd
RUN yum clean all

# 良い例: 1 つの RUN でまとめる + clean all でキャッシュファイルを削除
RUN yum update -y && \
    yum install -y httpd && \
    yum clean all
```

### イメージサイズ削減の判断基準

| 優先度 | 判断 | 使用フレーバー |
|--------|------|--------------|
| セキュリティ重視 + 最小サイズ | マルチステージビルド可能 | UBI Micro |
| パッケージ追加必要・軽量化希望 | `microdnf` で足りる | UBI Minimal |
| RPM パッケージが必要 | `yum`/`dnf` が必要 | UBI Standard |
| systemd サービス | systemd 必要 | UBI Init |

### セキュリティ確認

```bash
# イメージの署名検証（Sigstore/cosign）
podman image trust show
skopeo inspect --raw docker://registry.access.redhat.com/ubi9 | jq '.annotations'

# ダイジェストで固定して pull（タグの差し替え攻撃対策）
podman pull registry.access.redhat.com/ubi9@sha256:<digest>
```
