# Podmanコンテナ管理

このスキルはPodmanを使ったコンテナ管理・DevOpsワークフローの実践ガイドです。

## リファレンス

| ファイル | 内容 |
|---------|------|
| [references/ARCHITECTURE.md](references/ARCHITECTURE.md) | コンテナ基礎 + Podman vs Docker アーキテクチャ |
| [references/INSTALLATION.md](references/INSTALLATION.md) | OS別インストール・環境構築 |
| [references/CONTAINERS.md](references/CONTAINERS.md) | コンテナライフサイクル管理・Pods |
| [references/STORAGE.md](references/STORAGE.md) | ストレージ（volumes/bind mounts/tmpfs） |
| [references/BUILDAH.md](references/BUILDAH.md) | Buildah + マルチステージビルド + CI統合 |
| [references/IMAGES.md](references/IMAGES.md) | ベースイメージ選択 + レジストリ + Skopeo |
| [references/SECURITY.md](references/SECURITY.md) | rootless, user namespaces, SELinux, capabilities, signing |
| [references/TROUBLESHOOTING.md](references/TROUBLESHOOTING.md) | デバッグ・モニタリング・ヘルスチェック |
| [references/NETWORKING.md](references/NETWORKING.md) | Netavark, DNS, ポート公開, rootless制限 |
| [references/DOCKER-MIGRATION.md](references/DOCKER-MIGRATION.md) | Docker→Podman移行ガイド |
| [references/SYSTEMD-KUBERNETES.md](references/SYSTEMD-KUBERNETES.md) | Quadlet, systemd統合, K8s YAML生成 |
| [references/DESKTOP-AI.md](references/DESKTOP-AI.md) | Podman Desktop, AI Lab |

---

## 目次

1. [使用タイミング](#使用タイミング)
2. [Podman三位一体](#podman三位一体)
3. [基本操作](#基本操作)
4. [ストレージ](#ストレージ)
5. [ネットワーキング](#ネットワーキング)
6. [セキュリティ](#セキュリティ)
7. [Docker移行チェックリスト](#docker移行チェックリスト)
8. [systemd統合（Quadlet）](#systemd統合quadlet)
9. [トラブルシューティング](#トラブルシューティング)
10. [判断分岐ガイド](#判断分岐ガイド)

---

## 使用タイミング

このスキルを使う場面:

- Podmanでコンテナを起動・管理するとき
- `Containerfile` または `Dockerfile` を使ってイメージをビルドするとき（Podman/Buildah使用時）
- Docker環境からPodmanへ移行するとき
- rootlessコンテナを設計・実装するとき
- systemd Quadletでコンテナサービスを管理するとき
- Buildahを使って高度なイメージビルドを行うとき
- Skopeoでイメージをレジストリ間でコピー・検査するとき

### ユーザー確認の原則（AskUserQuestion）

**コンテナランタイム選択について不明確な場合、推測で進めず必ずAskUserQuestionでユーザーに確認する。**

確認すべき場面:
- DockerとPodmanのどちらを使うか不明な場合
- rootful/rootlessのどちらで運用するか
- Buildah vs `podman build` のどちらを使うか
- ネットワークドライバの要件（bridge/macvlan/ipvlan）
- オーケストレーション戦略（systemd Quadlet vs Kubernetes YAML）

確認不要な場面:
- `Containerfile` が存在する → Podman使用が確定
- `podman` CLIコマンドが明示されている → このスキルを使う

---

## Podman三位一体

Podmanエコシステムは3つのツールで構成される:

| ツール | 役割 | 主な使用場面 |
|--------|------|------------|
| **Podman** | コンテナエンジン・CLI | コンテナ実行・管理・Pod管理 |
| **Buildah** | イメージビルドツール | 高度なイメージビルド・スクリプトビルド |
| **Skopeo** | イメージ操作ツール | レジストリ間コピー・イメージ検査・署名検証 |

### Dockerとの根本的な違い

| 比較軸 | Docker | Podman |
|--------|--------|--------|
| アーキテクチャ | デーモンベース（`dockerd`が常駐） | **デーモンレス**（各コマンドが独立プロセス） |
| デフォルト実行 | rootful（root権限） | **rootless**（一般ユーザー権限） |
| Podサポート | Docker Compose相当 | **ネイティブPodサポート**（Kubernetes互換） |
| イメージビルド | `docker build` | `podman build` / **Buildah**（分離ツール） |
| イメージ操作 | Docker CLI内包 | **Skopeo**（専用ツール） |
| ソケット依存 | `/var/run/docker.sock` 必須 | **不要**（オプションで有効化可能） |
| systemd統合 | 別途設定 | **Quadlet**でネイティブ統合 |

---

## 基本操作

### コンテナライフサイクル

```bash
# イメージ検索
podman search nginx --filter=is-official

# イメージ取得
podman pull docker.io/library/nginx:latest

# コンテナ起動（基本）
podman run -d --name my-nginx -p 8080:80 nginx

# コンテナ起動（rootless推奨オプション付き）
podman run -d \
  --name my-app \
  --userns=keep-id \
  --security-opt=no-new-privileges \
  -p 8080:8080 \
  myimage:latest

# コンテナ一覧
podman ps          # 実行中のみ
podman ps -a       # 全コンテナ

# コンテナ停止・削除
podman stop my-nginx
podman rm my-nginx

# ログ確認
podman logs -f my-nginx

# コンテナ内コマンド実行
podman exec -it my-nginx /bin/bash

# コンテナ詳細情報
podman inspect my-nginx

# リソース使用状況
podman stats

# ファイルコピー
podman cp my-nginx:/etc/nginx/nginx.conf ./nginx.conf
```

### イメージ管理

```bash
# ローカルイメージ一覧
podman images

# イメージビルド（Containerfile/Dockerfile）
podman build -t myapp:v1.0 .
podman build -t myapp:v1.0 -f Containerfile .

# イメージタグ付け
podman tag myapp:v1.0 registry.example.com/myapp:v1.0

# レジストリへPush
podman push registry.example.com/myapp:v1.0

# イメージ削除
podman rmi myapp:v1.0

# 未使用リソースの削除
podman system prune
```

### Pod管理（Podman固有機能）

PodはKubernetesのPodと同概念。同一ネットワーク名前空間を共有するコンテナグループ。

```bash
# Pod作成（ポートはPodに設定）
podman pod create --name my-pod -p 8080:80

# PodにコンテナをAttach
podman run -d --pod my-pod --name web nginx
podman run -d --pod my-pod --name sidecar busybox sleep infinity

# Pod操作
podman pod start my-pod
podman pod stop my-pod
podman pod ps           # Pod一覧
podman pod inspect my-pod

# Kubernetes YAML生成（Podから）
podman generate kube my-pod > my-pod.yaml

# YAML適用
podman play kube my-pod.yaml
```

---

## ストレージ

> **詳細**: [references/STORAGE.md](references/STORAGE.md)

### ストレージ種別の判断フロー

```
データを永続化する必要がある？
├─ Yes → コンテナ内でのみ使う？
│         ├─ Yes → tmpfs (--tmpfs)
│         └─ No → ホストとデータを共有する？
│                   ├─ Yes（特定パス）→ Bind Mount (-v /host:/container)
│                   └─ Yes（Podman管理） → Named Volume
└─ No → コンテナの一時レイヤーを使う（デフォルト）
```

### 主要コマンド

```bash
# Named Volume作成・使用
podman volume create mydata
podman run -d -v mydata:/var/lib/data myimage

# Bind Mount（ホストパス）
podman run -d -v /home/user/data:/var/data:Z myimage
# :Z = SELinux ラベル設定（rootlessで重要）

# tmpfs（揮発性メモリ上ストレージ）
podman run -d --tmpfs /tmp:rw,size=256m myimage

# Volume一覧・削除
podman volume ls
podman volume rm mydata
```

> **rootlessの注意点**: Bind Mountで `:z` または `:Z` オプションを付けてSELinuxラベルを設定することを推奨。

---

## ネットワーキング

> **詳細**: [references/NETWORKING.md](references/NETWORKING.md) ※ implementer-2担当

### Netavark（Podman 4.0+デフォルト）

PodmanのネイティブネットワークスタックはRust製の **Netavark**。

| ドライバ | 用途 |
|---------|------|
| `bridge` | デフォルト。コンテナ間通信に適する |
| `macvlan` | コンテナにホストNIC経由のIPを直接付与 |
| `ipvlan` | macvlanの軽量版 |

```bash
# ネットワーク作成
podman network create mynet

# ネットワーク指定でコンテナ起動
podman run -d --network mynet --name app myimage

# コンテナ間通信（同一ネットワーク内はコンテナ名で解決可能）
podman run -d --network mynet --name db postgres
podman run -d --network mynet --name app myapp  # app → db で到達可能

# ネットワーク一覧・検査
podman network ls
podman network inspect mynet
```

### rootlessネットワークの制限

| 制限事項 | 理由 | 回避策 |
|---------|------|--------|
| 1024以下のポートをbind不可 | 特権ポートはroot専用 | ポートマッピングで1024以上を使う |
| macvlanは通常不可 | raw socketが必要 | rootfulまたはSELinuxポリシーで許可 |
| ホストネットワーク制限あり | ネットワーク名前空間の制約 | `--network=slirp4netns` を使用 |

---

## セキュリティ

> **詳細**: [references/SECURITY.md](references/SECURITY.md) ※ implementer-2担当

### rootless-first原則

**Podmanの設計哲学: 常にrootlessを第一選択にする。**

```
rootless（推奨） vs rootful（必要な場合のみ）
├─ rootless: 一般ユーザーで実行。ホストへの影響を最小化
└─ rootful: 特権ポートbind、macvlan、特定のカーネル操作が必要な場合のみ
```

### AskUserQuestion: rootful vs rootless

```python
# 環境・要件が不明な場合
AskUserQuestion(
    questions=[{
        "question": "コンテナの実行方式を教えてください",
        "header": "rootless vs rootful選択",
        "options": [
            {"label": "rootless（推奨）", "description": "一般ユーザー権限で実行。セキュリティ最大化"},
            {"label": "rootful", "description": "root権限が必要（特権ポート、macvlanなど）"}
        ],
        "multiSelect": False
    }]
)
```

### User Namespaces（rootlessの核心）

rootlessコンテナはUser Namespacesによって実現される:

```
ホストUID 1000（一般ユーザー）
    ↓ User Namespace マッピング
コンテナ内 UID 0（root）
    ↓ 実際のホスト権限はなし
```

```bash
# User Namespace確認
podman unshare cat /proc/self/uid_map

# コンテナ内のID確認
podman run --rm alpine id
```

### capabilities判断表

| 操作 | 必要なcapability | rootlessで可能? |
|------|----------------|----------------|
| ポートbind (>1024) | なし | ✅ |
| ポートbind (<1024) | `CAP_NET_BIND_SERVICE` | ❌（rootful必要） |
| ファイルシステムマウント | `CAP_SYS_ADMIN` | ❌（rootful必要） |
| ネットワーク設定変更 | `CAP_NET_ADMIN` | ❌ |
| rawソケット | `CAP_NET_RAW` | ❌ |

```bash
# 不要なcapabilityを削除（セキュリティ強化）
podman run --cap-drop=ALL --cap-add=NET_BIND_SERVICE myimage

# read-onlyルートファイルシステム
podman run --read-only --tmpfs /tmp myimage
```

---

## Docker移行チェックリスト

> **詳細**: [references/DOCKER-MIGRATION.md](references/DOCKER-MIGRATION.md) ※ implementer-2担当

### コマンド対応表（主要コマンドは同一）

| Docker | Podman | 差異 |
|--------|--------|------|
| `docker run` | `podman run` | ほぼ同一 |
| `docker build` | `podman build` | Containerfileも利用可 |
| `docker compose` | `podman compose` / `podman-compose` | 別途インストール必要 |
| `docker swarm` | 非対応 | Kubernetes/Quadletを使用 |
| `docker ps` | `podman ps` | 同一 |
| `docker pull/push` | `podman pull/push` | 同一 |

### 移行時の注意点

- [ ] `docker.sock` への依存を確認（Podmanはデフォルトでソケット不要）
- [ ] `--privileged` フラグの使用箇所を確認（rootlessで代替可能か検討）
- [ ] Docker Composeファイルはほぼそのまま使用可能
- [ ] ネットワークドライバの違いを確認（`bridge` は共通、`overlay` はPodman非対応）
- [ ] UID/GIDのマッピングを確認（rootlessでは `--userns=keep-id` が有効）

### Docker daemon互換APIの有効化（必要な場合）

```bash
# Podmanソケットを起動（Docker互換API）
systemctl --user enable --now podman.socket

# Docker CLIからPodmanへ向ける
export DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock
docker ps  # Podmanのコンテナを表示
```

---

## systemd統合（Quadlet）

> **詳細**: [references/SYSTEMD-KUBERNETES.md](references/SYSTEMD-KUBERNETES.md) ※ implementer-2担当

### AskUserQuestion: オーケストレーション選択

```python
AskUserQuestion(
    questions=[{
        "question": "コンテナサービスの管理方法を教えてください",
        "header": "オーケストレーション戦略",
        "options": [
            {"label": "systemd Quadlet", "description": "単一ホスト向け。systemdとのネイティブ統合"},
            {"label": "Kubernetes YAML", "description": "podman play kubeで適用。将来的なK8s移行を想定"},
            {"label": "手動管理", "description": "スクリプトやCLIで管理"}
        ],
        "multiSelect": False
    }]
)
```

### Quadlet基本構成

Quadletは systemd unit ファイルでコンテナを宣言的に管理する仕組み。

```ini
# ~/.config/containers/systemd/myapp.container
[Unit]
Description=My Application Container
After=network-online.target

[Container]
Image=myimage:latest
PublishPort=8080:8080
Volume=mydata:/var/data:Z
Environment=APP_ENV=production

[Service]
Restart=always

[Install]
WantedBy=default.target
```

```bash
# Quadletの反映・起動
systemctl --user daemon-reload
systemctl --user enable --now myapp.service

# 状態確認
systemctl --user status myapp.service
podman ps
```

### Kubernetes YAML生成

```bash
# 実行中のコンテナ/PodからKubernetes YAMLを生成
podman generate kube mycontainer > myapp.yaml
podman generate kube mypod > mypod.yaml

# YAML適用
podman play kube myapp.yaml

# YAML削除
podman play kube --down myapp.yaml
```

---

## トラブルシューティング

> **詳細**: [references/TROUBLESHOOTING.md](references/TROUBLESHOOTING.md) ※ implementer-2担当

### よくある問題と解決フロー

| 症状 | 原因 | 解決策 |
|------|------|--------|
| コンテナが起動直後に終了 | CMD/ENTRYPOINTエラー | `podman logs <name>` で確認 |
| ポートbindエラー | 1024以下のポート（rootless） | 1024以上のポートを使用 |
| パーミッションエラー | SELinuxラベル未設定 | `-v /path:/path:Z` を追加 |
| イメージpullエラー | レジストリ認証失敗 | `podman login registry.example.com` |
| ネットワーク到達不能 | rootlessネットワーク制限 | `podman network inspect` で確認 |
| OOMで終了 | メモリ上限 | `--memory=512m` で制限値を上げる |

### 診断コマンド

```bash
# システム情報
podman info

# コンテナの詳細ログ
podman logs --since=1h mycontainer

# コンテナのプロセス確認
podman top mycontainer

# イベント確認
podman events --since=1h

# コンテナ内でデバッグシェル起動
podman exec -it mycontainer /bin/sh

# ネットワーク疎通確認
podman run --rm --network mynet nicolaka/netshoot ping db

# ストレージ使用量
podman system df
```

### SELinuxトラブルシューティング

```bash
# SELinuxエラーの確認
ausearch -m avc -ts recent | audit2why

# 一時的にSELinuxを無効化（診断目的のみ）
podman run --security-opt=label=disable myimage

# ボリュームラベル付け
podman run -v /mydata:/data:Z myimage   # プライベートラベル
podman run -v /mydata:/data:z myimage   # 共有ラベル
```

---

## 判断分岐ガイド

### ツール選択

| 状況 | 推奨ツール |
|------|----------|
| シンプルなコンテナ実行 | `podman run` |
| Dockerfileからイメージビルド | `podman build` |
| スクリプトでの高度なビルド | `buildah` |
| レジストリ間のイメージコピー | `skopeo copy` |
| イメージの検査・署名確認 | `skopeo inspect` |
| 複数コンテナの協調動作 | `podman pod` |
| 本番サービス化 | `systemd Quadlet` |

### ビルドツール選択

```python
# ビルド要件が不明な場合
AskUserQuestion(
    questions=[{
        "question": "イメージビルドの要件を教えてください",
        "header": "ビルドツール選択",
        "options": [
            {"label": "podman build", "description": "Containerfile/Dockerfileから通常ビルド"},
            {"label": "buildah", "description": "スクリプトビルド、スクラッチビルド、きめ細かい制御が必要"}
        ],
        "multiSelect": False
    }]
)
```

### ネットワーク選択

```python
AskUserQuestion(
    questions=[{
        "question": "コンテナのネットワーク要件を教えてください",
        "header": "ネットワーク設定",
        "options": [
            {"label": "bridge（デフォルト）", "description": "コンテナ間通信。ほとんどのユースケースに対応"},
            {"label": "host", "description": "ホストのネットワークを直接使用（rootful限定）"},
            {"label": "macvlan", "description": "コンテナに独立MACアドレスを付与（rootful限定）"},
            {"label": "none", "description": "ネットワーク不要"}
        ],
        "multiSelect": False
    }]
)
```

---

## 参照リファレンス

| ファイル | 内容 |
|---------|------|
| [references/ARCHITECTURE.md](references/ARCHITECTURE.md) | コンテナ技術基礎・Podman/Dockerアーキテクチャ詳細 |
| [references/INSTALLATION.md](references/INSTALLATION.md) | OS別インストール手順 |
| [references/CONTAINERS.md](references/CONTAINERS.md) | コンテナライフサイクル詳細・Pod管理 |
| [references/STORAGE.md](references/STORAGE.md) | ストレージ設定・COW・overlay詳細 |
| [references/BUILDAH.md](references/BUILDAH.md) | Buildah詳細・マルチステージビルド・CI統合 |
