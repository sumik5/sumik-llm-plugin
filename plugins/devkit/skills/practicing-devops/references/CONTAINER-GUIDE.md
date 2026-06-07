# コンテナ管理ガイド

DockerとPodmanの統合コンテナ管理ガイド。
マルチステージビルド・セキュリティ強化・rootlessコンテナ・systemd統合まで網羅する。

---

## Docker

### 使用タイミング

- Dockerfile、docker-compose.yml、.dockerignoreが存在する
- Docker Compose でマルチコンテナアプリを管理する
- Docker MCPツールを使ってコンテナを操作する

### Docker MCP基本操作

```typescript
// コンテナ一覧
mcp__docker__list_containers()

// コンテナ起動 / 停止
mcp__docker__start_container({ container_name: "app-container" })
mcp__docker__stop_container({ container_name: "app-container" })

// ログ取得
mcp__docker__get_logs({ container_name: "app-container" })

// Compose起動 / 停止
mcp__docker__deploy_compose({ compose_file: "docker-compose.yml", project_name: "my-project" })
```

### Dockerfileベストプラクティス

#### 1. マルチステージビルド（必須）

ビルド環境と実行環境を分離し、最終イメージサイズを大幅削減（例: 916MB → 31.4MB）:

```dockerfile
# ビルドステージ
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# 実行ステージ
FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app/main /main
USER 65532:65532
ENTRYPOINT ["/main"]
```

#### 2. キャッシュ最適化（必須）

変更頻度の低いものを先に配置:

```dockerfile
COPY package.json package-lock.json ./  # 依存関係定義（変更少）
RUN npm ci                               # 依存関係インストール
COPY . .                                 # アプリケーションコード（変更多）
```

#### 3. セキュリティ強化（必須）

```dockerfile
# 非rootユーザーで実行
USER 65532:65532
# またはDistrolessベースイメージ
FROM gcr.io/distroless/static:nonroot
```

#### Dockerfileチェックリスト

- [ ] マルチステージビルドを使用
- [ ] 依存関係ファイルを先にCOPY
- [ ] .dockerignoreを作成（node_modules, .env*, .git）
- [ ] 非rootユーザーで実行
- [ ] バージョンタグを固定（`:latest`を避ける）

### Docker Composeパターン

```yaml
# Web + DB構成
services:
  web:
    build: ./web
    ports:
      - "3000:3000"
    depends_on:
      - db
  db:
    image: postgres:15
    volumes:
      - db_data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
volumes:
  db_data:
```

### トラブルシューティング

| 症状 | 解決策 |
|------|--------|
| コンテナが起動しない | `mcp__docker__get_logs({ container_name: "..." })` でログ確認 |
| ビルド失敗 | `docker build --no-cache -t image_name .` でキャッシュなし再ビルド |
| ネットワーク問題 | `docker network inspect network_name` で確認 |

### ユーザー確認が必要な場面

| 確認項目 | 選択肢例 |
|---------|---------|
| ベースイメージ | alpine, debian, ubuntu, distroless |
| Compose構成 | 開発用のみ, 本番用も, プロファイル分離 |
| ボリューム戦略 | bind mount, named volume, tmpfs |
| ネットワーク構成 | デフォルト, カスタムネットワーク |

**詳細**: [DOCKER-ENGINE.md](./references/DOCKER-ENGINE.md), [DOCKER-DOCKERFILE-BEST-PRACTICES.md](./references/DOCKER-DOCKERFILE-BEST-PRACTICES.md), [DOCKER-COMPOSE.md](./references/DOCKER-COMPOSE.md), [DOCKER-SECURITY.md](./references/DOCKER-SECURITY.md), [DOCKER-NETWORKING.md](./references/DOCKER-NETWORKING.md)

---

## Podman

### Podman三位一体

| ツール | 役割 | 主な使用場面 |
|--------|------|------------|
| **Podman** | コンテナエンジン・CLI | コンテナ実行・管理・Pod管理 |
| **Buildah** | イメージビルドツール | 高度なイメージビルド・スクリプトビルド |
| **Skopeo** | イメージ操作ツール | レジストリ間コピー・イメージ検査・署名検証 |

### DockerとPodmanの根本的な違い

| 比較軸 | Docker | Podman |
|--------|--------|--------|
| アーキテクチャ | デーモンベース（`dockerd`が常駐） | **デーモンレス**（各コマンドが独立プロセス） |
| デフォルト実行 | rootful（root権限） | **rootless**（一般ユーザー権限） |
| Podサポート | Docker Compose相当 | **ネイティブPodサポート**（Kubernetes互換） |
| イメージビルド | `docker build` | `podman build` / **Buildah** |
| systemd統合 | 別途設定 | **Quadlet**でネイティブ統合 |

### 基本操作

```bash
# コンテナ起動（rootless推奨）
podman run -d \
  --name my-app \
  --userns=keep-id \
  --security-opt=no-new-privileges \
  -p 8080:8080 \
  myimage:latest

# Pod管理（Kubernetes互換）
podman pod create --name my-pod -p 8080:80
podman run -d --pod my-pod --name web nginx
podman generate kube my-pod > my-pod.yaml  # K8s YAML生成
```

### セキュリティ: rootless-first原則

**Podmanの設計哲学: 常にrootlessを第一選択にする。**

| 操作 | rootlessで可能? |
|------|----------------|
| ポートbind (>1024) | ✅ |
| ポートbind (<1024) | ❌（rootful必要） |
| ファイルシステムマウント | ❌（rootful必要） |

```bash
# SELinuxラベル付きボリューム（rootlessで重要）
podman run -d -v /home/user/data:/var/data:Z myimage
# :Z = SELinuxプライベートラベル設定
```

### systemd統合（Quadlet）

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
systemctl --user daemon-reload
systemctl --user enable --now myapp.service
```

### Docker移行チェックリスト

| Docker | Podman | 差異 |
|--------|--------|------|
| `docker run` | `podman run` | ほぼ同一 |
| `docker build` | `podman build` | Containerfileも利用可 |
| `docker compose` | `podman compose` | 別途インストール必要 |
| `docker swarm` | 非対応 | Kubernetes/Quadletを使用 |

- [ ] `docker.sock` への依存を確認（Podmanはデフォルトでソケット不要）
- [ ] `--privileged` フラグの使用箇所を確認（rootlessで代替可能か検討）
- [ ] UID/GIDのマッピングを確認（rootlessでは `--userns=keep-id` が有効）

### トラブルシューティング

| 症状 | 原因 | 解決策 |
|------|------|--------|
| コンテナが起動直後に終了 | CMD/ENTRYPOINTエラー | `podman logs <name>` で確認 |
| ポートbindエラー | 1024以下のポート（rootless） | 1024以上のポートを使用 |
| パーミッションエラー | SELinuxラベル未設定 | `-v /path:/path:Z` を追加 |
| ネットワーク到達不能 | rootlessネットワーク制限 | `podman network inspect` で確認 |

**詳細**: [PODMAN-ARCHITECTURE.md](./references/PODMAN-ARCHITECTURE.md), [PODMAN-SECURITY.md](./references/PODMAN-SECURITY.md), [PODMAN-SYSTEMD-KUBERNETES.md](./references/PODMAN-SYSTEMD-KUBERNETES.md), [PODMAN-DOCKER-MIGRATION.md](./references/PODMAN-DOCKER-MIGRATION.md), [PODMAN-BUILDAH.md](./references/PODMAN-BUILDAH.md)

---

## 共通パターン

### Dockerfile/Containerfile共通ベストプラクティス

Dockerとどちらで使う場合も適用されるベストプラクティス:

| 原則 | 説明 |
|------|------|
| マルチステージビルド | ビルド環境と実行環境を分離 |
| 最小ベースイメージ | distroless, alpine, scratch 等を使用 |
| 非rootユーザー実行 | USER命令で専用ユーザーを設定 |
| .dockerignore/.containerignore | 不要ファイルのビルドコンテキスト除外 |
| 依存関係を先にCOPY | キャッシュ効率を最大化 |
| ENTRYPOINTとCMDの使い分け | ENTRYPOINT=固定コマンド、CMD=デフォルト引数 |

### ストレージ選択フロー

```
データを永続化する必要がある？
├─ Yes → コンテナ内でのみ使う？
│         ├─ Yes → tmpfs
│         └─ No → ホストとデータを共有する？
│                   ├─ Yes（特定パス）→ Bind Mount
│                   └─ Yes（管理）→ Named Volume
└─ No → コンテナの一時レイヤーを使う（デフォルト）
```

---

## 詳細ガイド

### Docker references/

| ファイル | 内容 |
|---------|------|
| [DOCKER-ENGINE.md](./references/DOCKER-ENGINE.md) | containerd, runc, shimアーキテクチャ |
| [DOCKER-IMAGES.md](./references/DOCKER-IMAGES.md) | レイヤー、レジストリ、マニフェスト |
| [DOCKER-CONTAINERS.md](./references/DOCKER-CONTAINERS.md) | ライフサイクル、再起動ポリシー |
| [DOCKER-DOCKERFILE-BEST-PRACTICES.md](./references/DOCKER-DOCKERFILE-BEST-PRACTICES.md) | マルチステージビルド、キャッシュ最適化 |
| [DOCKER-COMPOSE.md](./references/DOCKER-COMPOSE.md) | マルチコンテナアプリ管理 |
| [DOCKER-NETWORKING.md](./references/DOCKER-NETWORKING.md) | CNM, bridge, overlay, service discovery |
| [DOCKER-VOLUMES.md](./references/DOCKER-VOLUMES.md) | 永続データ管理、ステートフルコンテナパターン |
| [DOCKER-SECURITY.md](./references/DOCKER-SECURITY.md) | namespaces, cgroups, Scout, DCT |
| [DOCKER-AI-WASM.md](./references/DOCKER-AI-WASM.md) | Docker Model Runner, WebAssembly |
| [DOCKER-SWARM.md](./references/DOCKER-SWARM.md) | オーケストレーション基礎（軽量版） |
| [DOCKER-DEV-WORKFLOWS.md](./references/DOCKER-DEV-WORKFLOWS.md) | ホットリロード、デバッグ、CI/CD統合 |
| [DOCKER-DATABASES.md](./references/DOCKER-DATABASES.md) | PostgreSQL, MySQL, MongoDB, Redis コンテナ化 |
| [DOCKER-MONITORING-LOGGING.md](./references/DOCKER-MONITORING-LOGGING.md) | ログドライバー、Prometheus+Grafana, ELKスタック |
| [DOCKER-DEPLOYMENT.md](./references/DOCKER-DEPLOYMENT.md) | CI/CD、Blue-Green/Canary、プライベートレジストリ |

### Podman references/

| ファイル | 内容 |
|---------|------|
| [PODMAN-ARCHITECTURE.md](./references/PODMAN-ARCHITECTURE.md) | コンテナ基礎 + Podman vs Dockerアーキテクチャ |
| [PODMAN-INSTALLATION.md](./references/PODMAN-INSTALLATION.md) | OS別インストール・環境構築 |
| [PODMAN-CONTAINERS.md](./references/PODMAN-CONTAINERS.md) | コンテナライフサイクル管理・Pods |
| [PODMAN-STORAGE.md](./references/PODMAN-STORAGE.md) | ストレージ（volumes/bind mounts/tmpfs） |
| [PODMAN-BUILDAH.md](./references/PODMAN-BUILDAH.md) | Buildah + マルチステージビルド + CI統合 |
| [PODMAN-IMAGES.md](./references/PODMAN-IMAGES.md) | ベースイメージ選択 + レジストリ + Skopeo |
| [PODMAN-SECURITY.md](./references/PODMAN-SECURITY.md) | rootless, user namespaces, SELinux, capabilities |
| [PODMAN-TROUBLESHOOTING.md](./references/PODMAN-TROUBLESHOOTING.md) | デバッグ・モニタリング・ヘルスチェック |
| [PODMAN-NETWORKING.md](./references/PODMAN-NETWORKING.md) | Netavark, DNS, ポート公開, rootless制限 |
| [PODMAN-DOCKER-MIGRATION.md](./references/PODMAN-DOCKER-MIGRATION.md) | Docker→Podman移行ガイド |
| [PODMAN-SYSTEMD-KUBERNETES.md](./references/PODMAN-SYSTEMD-KUBERNETES.md) | Quadlet, systemd統合, K8s YAML生成 |
| [PODMAN-DESKTOP-AI.md](./references/PODMAN-DESKTOP-AI.md) | Podman Desktop, AI Lab |
