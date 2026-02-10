---
name: managing-docker
description: Dockerセキュリティ。Linuxカーネルセキュリティ技術（namespaces、cgroups、capabilities、seccomp）とDocker固有技術（Scout、DCT、secrets）を網羅。
---

# Dockerセキュリティ

Dockerは複数のセキュリティレイヤーを提供し、ゼロ努力で「適度に安全」な環境を実現する。デフォルト設定は完璧ではないが、優れた出発点となる。

## 📋 目次

- [セキュリティレイヤーの概要](#セキュリティレイヤーの概要)
- [Linuxセキュリティ技術](#linuxセキュリティ技術)
  - [Kernel Namespaces](#kernel-namespaces)
  - [Control Groups (cgroups)](#control-groups-cgroups)
  - [Capabilities](#capabilities)
  - [Mandatory Access Control](#mandatory-access-control)
  - [seccomp](#seccomp)
- [Docker固有セキュリティ技術](#docker固有セキュリティ技術)
  - [Docker Scout](#docker-scout)
  - [Docker Content Trust (DCT)](#docker-content-trust-dct)
  - [Docker Secrets](#docker-secrets)
- [Swarmセキュリティ](#swarmセキュリティ)
- [セキュリティベストプラクティス](#セキュリティベストプラクティス)

---

## セキュリティレイヤーの概要

優れたセキュリティは**多層防御 (defense in depth)** で構成される。Dockerは以下のセキュリティレイヤーを提供する：

| レイヤー | 技術 | 目的 |
|---------|------|------|
| **分離** | Kernel namespaces | プロセス、ネットワーク、ファイルシステムの隔離 |
| **リソース制限** | Control Groups (cgroups) | CPU、メモリ、I/O制限 |
| **権限最小化** | Capabilities | root権限の細分化 |
| **アクセス制御** | AppArmor/SELinux | 必須アクセス制御 (MAC) |
| **システムコール制限** | seccomp | カーネルシステムコールのフィルタリング |
| **脆弱性検出** | Docker Scout | イメージ脆弱性スキャン |
| **署名検証** | Docker Content Trust | イメージ署名・検証 |
| **機密情報管理** | Docker Secrets | パスワード、証明書の暗号化保存 |

**重要原則**: Dockerはこれらすべてに対して合理的なデフォルト設定を提供するが、本番環境ではカスタマイズが必要。

---

## Linuxセキュリティ技術

### Kernel Namespaces

**役割**: OSレベルの仮想化により、コンテナごとに独立したシステムビューを提供。

#### namespaceの種類

| Namespace | 隔離対象 | 効果 |
|-----------|---------|------|
| **pid** | プロセスID | 各コンテナが独自のPID 1を持つ。他コンテナのプロセスにアクセス不可 |
| **net** | ネットワークスタック | 独自のeth0、IPアドレス、ポート範囲、ルーティングテーブル |
| **mnt** | ファイルシステム | 独自のroot (`/`)、`/etc`、`/var`、`/dev` |
| **ipc** | プロセス間通信 | 共有メモリアクセスの隔離 |
| **user** | ユーザーID | コンテナ内rootをホスト非rootユーザーにマッピング可能 |
| **uts** | ホスト名 | 各コンテナが独自のホスト名を持つ |
| **cgroup** | cgroup階層 | cgroupリソース制限の隔離 (Linux 4.6+) |

#### 動作原理

```
ホストOS (root namespaces)
├─ pid: 1, 2, 3, ..., 1000
├─ net: eth0 (192.168.1.10)
└─ mnt: /

コンテナA (isolated namespaces)
├─ pid: 1, 2, 3
├─ net: eth0 (172.17.0.2)
└─ mnt: / (独立)

コンテナB (isolated namespaces)
├─ pid: 1, 2, 3
├─ net: eth0 (172.17.0.3)
└─ mnt: / (独立)
```

#### セキュリティ制限

- ❌ namespacesは**強力なセキュリティ境界ではない**
- ✅ VMと比較してより効率的だが、セキュリティは劣る
- ✅ Docker は追加セキュリティ技術 (cgroups, capabilities, seccomp) で補強

---

### Control Groups (cgroups)

**役割**: コンテナのリソース使用を制限し、リソース枯渇によるDoS攻撃を防止。

#### 制限可能なリソース

| リソース | 制限内容 |
|---------|---------|
| **CPU** | CPU時間、コア数、シェア |
| **メモリ** | RAM使用量、スワップ |
| **ディスクI/O** | 読み取り/書き込み速度 |
| **ネットワークI/O** | 帯域幅制限 |

#### 使用例

```bash
# メモリ制限 (512MB)
docker run --memory="512m" nginx

# CPU制限 (1コア)
docker run --cpus="1.0" nginx

# ディスクI/O制限 (読み取り: 10MB/s)
docker run --device-read-bps /dev/sda:10mb nginx
```

#### なぜ必要か

**ホテルの客室の比喩**: 各部屋(コンテナ)は隔離されているが、水道・電気・空調などの共有リソースを使用する。cgroupsは各部屋がこれらのリソースを独占しないよう制限する。

---

### Capabilities

**役割**: rootユーザーの強大な権限を細分化し、必要最小限の権限のみをコンテナに付与。

#### 主なcapabilities

| Capability | 権限内容 |
|-----------|---------|
| **CAP_CHOWN** | ファイル所有権変更 |
| **CAP_NET_BIND_SERVICE** | 1024未満のポートへのバインド |
| **CAP_SETUID** | プロセス権限の昇格 |
| **CAP_SYS_BOOT** | システム再起動 |
| **CAP_SYS_ADMIN** | 各種システム管理操作 |
| **CAP_NET_ADMIN** | ネットワーク設定変更 |
| **CAP_SYS_TIME** | システム時刻変更 |

#### 最小権限の原則 (Principle of Least Privilege)

```bash
# 例: Webサーバーは低番号ポートのバインドのみ必要
docker run \
  --cap-drop=ALL \
  --cap-add=CAP_NET_BIND_SERVICE \
  nginx
```

#### デフォルト動作

- ✅ Dockerはデフォルトで**合理的なcapabilities**を設定
- ✅ コンテナは削除されたcapabilitiesを再追加できない
- ⚠️ 本番環境では独自のcapabilitiesプロファイルを設定すべき（複雑かつテストが必要）

---

### Mandatory Access Control

**役割**: AppArmor (Debian/Ubuntu) またはSELinux (Red Hat/CentOS) によるアクセス制御。

#### プロファイル適用

```bash
# AppArmorプロファイルを指定
docker run --security-opt apparmor=docker-default nginx

# SELinuxラベルを指定
docker run --security-opt label=level:s0:c100,c200 nginx

# プロファイルを無効化 (非推奨)
docker run --security-opt apparmor=unconfined nginx
```

#### デフォルトポリシー

- ✅ Dockerはすべての新規コンテナにデフォルトプロファイルを適用
- ✅ プロファイルは「適度に保護的」かつ「広範なアプリケーション互換性」を提供
- ⚠️ カスタムポリシーは強力だが、作成に多大な労力が必要

---

### seccomp

**役割**: コンテナがホストカーネルに対して実行できるシステムコールを制限。

#### 基本情報

- **システムコール数**: Linuxは300以上のシステムコールを持つ
- **Dockerデフォルト**: 約40-50のシステムコールを無効化
- **目的**: 攻撃対象領域の縮小

#### seccompプロファイル適用

```bash
# デフォルトseccompプロファイル使用
docker run nginx

# カスタムseccompプロファイル指定
docker run --security-opt seccomp=/path/to/profile.json nginx

# seccompを無効化 (非推奨)
docker run --security-opt seccomp=unconfined nginx
```

#### 制限事項

- ⚠️ システムコールテーブルは長大で、カスタムポリシー作成は複雑
- ✅ デフォルトプロファイルは合理的なセキュリティを提供

---

## Docker固有セキュリティ技術

### Docker Scout

**役割**: イメージ内のソフトウェアパッケージを分析し、既知の脆弱性を検出。

#### 動作原理

1. **SBOM生成**: イメージ内のすべてのソフトウェアパッケージリストを作成 (Software Bill of Materials)
2. **脆弱性データベース照合**: 既知の脆弱性データベースと照合
3. **レポート生成**: 脆弱性の深刻度 (Critical/High/Medium/Low) と修正方法を提示

#### 使用例

```bash
# クイックスキャン
docker scout quickview myimage:latest

# 詳細な脆弱性レポート
docker scout cves myimage:latest
```

**出力例**:
```
Target: myimage:latest    │  0C  4H  2M  0L
  ✗ HIGH CVE-2023-52425 (expat 2.5.0-r2)
    Fixed version: 2.6.0-r0
  ✗ MEDIUM CVE-2023-52426 (expat 2.5.0-r2)
    Fixed version: 2.6.0-r0
```

#### 統合先

- Docker Desktop (UI統合)
- Docker Hub (レジストリ統合)
- Docker CLI
- Docker Scout Dashboard (`scout.docker.com`)

#### 注意点

- ⚠️ イメージのみをスキャン (ネットワーク、ノード、オーケストレータは対象外)
- ⚠️ スキャナーの品質差: 最良のものはバイナリレベルスキャンを実行
- ⚠️ 脆弱性検出後は修正・緩和の責任が発生

---

### Docker Content Trust (DCT)

**役割**: イメージの整合性と発行元を暗号学的に検証。インターネット経由でのイメージ取得時に特に重要。

#### ワークフロー

```
1. イメージビルド
2. 鍵ペアで署名
3. レジストリにプッシュ (署名付き)
   ↓
4. イメージプル
5. 署名検証
6. 検証成功後のみ実行許可
```

#### セットアップ手順

**1. 鍵ペア生成**
```bash
# 新規鍵ペア生成
docker trust key generate mykey

# 既存鍵ペアをインポート
docker trust key load key.pem --name mykey
```

**2. リポジトリと鍵を関連付け**
```bash
docker trust signer add --key mykey.pub mykey username/repo
```

**3. イメージ署名とプッシュ**
```bash
docker trust sign username/repo:tag
```

**4. 署名検証の有効化**
```bash
# DCT有効化 (すべてのイメージに署名・検証を要求)
export DOCKER_CONTENT_TRUST=1

# プル時に自動検証
docker pull username/repo:tag
```

**5. 署名データ確認**
```bash
docker trust inspect username/repo:tag --pretty
```

#### 無効化

```bash
unset DOCKER_CONTENT_TRUST
```

#### 高度な機能

- **コンテキスト**: イメージが特定環境 (prod/dev) 向けに署名されたか確認
- **ステール検出**: イメージが新しいバージョンで置き換えられたかを検知

---

### Docker Secrets

**役割**: パスワード、証明書、SSHキーなどの機密情報を安全に管理。

**⚠️ 重要**: Secretsはswarm modeでのみ動作 (クラスタストアが必要)。

#### セキュリティ機能

| 状態 | セキュリティ対策 |
|------|----------------|
| **保存時 (at rest)** | クラスタストアで暗号化 |
| **転送中 (in flight)** | ネットワーク上で暗号化 |
| **使用時 (in use)** | インメモリファイルシステムにマウント |

#### ワークフロー

```
1. Secretを作成
   ↓
2. 暗号化されたクラスタストアに保存
   ↓
3. Serviceを作成し、Secretへのアクセスを許可
   ↓
4. DockerがSecretを暗号化してネットワーク経由でレプリカに送信
   ↓
5. レプリカ内のインメモリファイルシステムに平文でマウント
   ↓
6. レプリカ終了時、インメモリファイルシステムを破棄しSecretをノードから削除
```

#### 使用例

```bash
# Secret作成
echo "my-secret-password" | docker secret create db_password -

# Serviceにアタッチ
docker service create \
  --name myapp \
  --secret db_password \
  nginx

# Service内でSecretにアクセス
# → /run/secrets/db_password として利用可能
```

#### 最小権限モデル

- ✅ Secretは明示的にアクセス許可されたServiceのみが利用可能
- ✅ 他のServiceやコンテナからはアクセス不可

---

## Swarmセキュリティ

Docker Swarmはデフォルトで複数のセキュリティ機能を自動設定する。

### 自動設定される機能

| 機能 | 説明 |
|------|------|
| **暗号化ノードID** | 各ノードに一意の暗号化IDを付与 |
| **相互TLS認証 (mTLS)** | ノード間通信をTLSで保護 |
| **自動CA設定** | 内部CA自動構築、証明書90日ごとに自動ローテーション |
| **安全なjoinトークン** | Manager用・Worker用の個別トークン |
| **暗号化クラスタストア** | etcdベースの暗号化分散データベース |
| **暗号化ネットワーク** | Overlayネットワークの暗号化オプション |

### 初期化コマンド

```bash
# Swarm初期化 (自動的に上記すべてを設定)
docker swarm init
```

### joinトークン管理

```bash
# Managerトークン表示
docker swarm join-token manager

# Workerトークン表示
docker swarm join-token worker

# トークンローテーション (侵害時)
docker swarm join-token --rotate manager
```

### 証明書管理

```bash
# 証明書ローテーション期間変更 (デフォルト90日)
docker swarm update --cert-expiry 720h

# 外部CA使用
docker swarm init --external-ca <CA-URL>
```

### クライアント証明書確認

```bash
# Linuxでの証明書確認
sudo openssl x509 \
  -in /var/lib/docker/swarm/certificates/swarm-node.crt \
  -text
```

**証明書フィールド**:
- **O (Organization)**: Swarm ID
- **OU (Organizational Unit)**: ノードロール (swarm-manager/swarm-worker)
- **CN (Canonical Name)**: ノードID

---

## セキュリティベストプラクティス

### チェックリスト

#### イメージセキュリティ
- [ ] 最小限のベースイメージを使用 (`alpine`, `distroless`)
- [ ] Docker Scoutで脆弱性スキャン実施
- [ ] Docker Content Trustで署名・検証を有効化
- [ ] マルチステージビルドで不要なツールを除外

#### ランタイムセキュリティ
- [ ] rootユーザーでの実行を避ける (`USER` 指定)
- [ ] Read-onlyファイルシステムを使用 (`--read-only`)
- [ ] 不要なcapabilitiesを削除 (`--cap-drop=ALL`)
- [ ] seccompプロファイルをカスタマイズ
- [ ] リソース制限を設定 (`--memory`, `--cpus`)

#### ネットワークセキュリティ
- [ ] 暗号化Overlayネットワークを使用 (Swarm)
- [ ] 不要なポート公開を避ける
- [ ] ファイアウォールルールを適切に設定

#### 機密情報管理
- [ ] 環境変数に機密情報を含めない
- [ ] Docker Secretsを使用 (Swarm)
- [ ] イメージに機密情報をハードコードしない

#### ホストセキュリティ
- [ ] Dockerデーモンをrootless modeで実行
- [ ] ホストOSを最新状態に保つ
- [ ] Docker Engineを最新版に保つ

### セキュリティ設定例

```bash
# セキュアなコンテナ実行例
docker run \
  --read-only \
  --cap-drop=ALL \
  --cap-add=CAP_NET_BIND_SERVICE \
  --security-opt=no-new-privileges \
  --memory="512m" \
  --cpus="1.0" \
  --user 1000:1000 \
  nginx
```

---

## まとめ

Dockerは**多層防御**アプローチでセキュリティを実現：

1. **Linux技術** (namespaces, cgroups, capabilities, MAC, seccomp): コンテナ分離とリソース制限
2. **Docker技術** (Scout, DCT, Secrets): 脆弱性検出、イメージ検証、機密情報管理
3. **Swarm技術** (mTLS, CA, 暗号化): クラスタセキュリティ

**重要**: デフォルト設定は優れた出発点だが、本番環境では要件に応じたカスタマイズが必須。特にcapabilities、seccomp、MACポリシーのカスタマイズは労力を要するが、強力なセキュリティを提供する。
