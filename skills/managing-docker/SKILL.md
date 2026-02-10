---
name: managing-docker
description: >-
  Comprehensive Docker development and operations guide covering Engine internals, images, containers, Compose, networking, volumes, security, AI (Model Runner), and Wasm.
  MUST load when Dockerfile, docker-compose.yml, docker-compose.yaml, or .dockerignore is detected.
  Covers container management via Docker MCP, multi-stage builds, cache optimization, security hardening, and image size minimization.
  For Terraform IaC, use developing-terraform instead.
---

# Docker開発環境管理

## 🎯 使用タイミング
- **開発環境のコンテナ化時**
- **Dockerfile作成・修正時**
- **マイクロサービス構成時**
- **Docker Composeプロジェクト管理時**
- **コンテナのデバッグ・ログ確認時**
- **イメージサイズ最適化・セキュリティ強化時**

## 📋 基本操作

### 1. コンテナ管理
```typescript
// コンテナ一覧
mcp__docker__list_containers()

// コンテナ起動
mcp__docker__start_container({
  container_name: "app-container"
})

// コンテナ停止
mcp__docker__stop_container({
  container_name: "app-container"
})

// ログ取得
mcp__docker__get_container_logs({
  container_name: "app-container"
})
```

### 2. イメージ管理
```typescript
// イメージビルド
mcp__docker__build_image({
  dockerfile_path: "./Dockerfile",
  image_name: "my-app:latest"
})

// イメージ一覧
// Bash: docker images
```

### 3. Docker Compose管理
```typescript
// Composeプロジェクト起動
mcp__docker__compose_up({
  compose_file: "docker-compose.yml",
  project_name: "my-project"
})

// Composeプロジェクト停止
mcp__docker__compose_down({
  project_name: "my-project"
})
```

## 🏗️ 推奨ワークフロー

### 新規コンテナ化プロジェクト
```
段階1: 設計
- dev1: Dockerfile作成
- dev2: docker-compose.yml設計

段階2: ビルド・テスト
- dev3: イメージビルド・テスト
- dev4: ネットワーク・ボリューム設定

段階3: 統合テスト
- dev1: コンテナ統合テスト
```

### 既存プロジェクトのデバッグ
```
1. コンテナ状態確認
   mcp__docker__list_containers()

2. ログ確認
   mcp__docker__get_container_logs({ container_name: "..." })

3. 問題解決
   - 必要に応じてコンテナ再起動
   - 設定ファイル修正
```

## 🎨 よくあるパターン

### Web + DB構成
```yaml
# docker-compose.yml
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

### マイクロサービス構成
```yaml
services:
  api:
    build: ./api
    ports:
      - "8000:8000"

  worker:
    build: ./worker
    depends_on:
      - redis

  redis:
    image: redis:alpine
```

## 📖 詳細リファレンス

Dockerの各トピックについて、詳細なリファレンスを用意しています:

| トピック | ファイル | 内容 |
|---------|---------|------|
| Engine内部構造 | [ENGINE.md](./references/ENGINE.md) | containerd, runc, shimアーキテクチャ |
| イメージ管理 | [IMAGES.md](./references/IMAGES.md) | レイヤー、レジストリ、マニフェスト |
| コンテナ管理 | [CONTAINERS.md](./references/CONTAINERS.md) | ライフサイクル、再起動ポリシー |
| Dockerfile | [DOCKERFILE-BEST-PRACTICES.md](./references/DOCKERFILE-BEST-PRACTICES.md) | マルチステージビルド、キャッシュ最適化 |
| Compose | [COMPOSE.md](./references/COMPOSE.md) | マルチコンテナアプリ管理 |
| ネットワーク | [NETWORKING.md](./references/NETWORKING.md) | CNM, bridge, overlay, service discovery |
| ボリューム | [VOLUMES.md](./references/VOLUMES.md) | 永続データ管理 |
| セキュリティ | [SECURITY.md](./references/SECURITY.md) | namespaces, cgroups, Scout, DCT |
| AI & Wasm | [AI-WASM.md](./references/AI-WASM.md) | Docker Model Runner, WebAssembly |
| Swarm | [SWARM.md](./references/SWARM.md) | オーケストレーション基礎（軽量版） |

## 📝 Dockerfileベストプラクティス

### 1. マルチステージビルド（必須）
ビルド環境と実行環境を分離し、最終イメージサイズを大幅削減（例: 916MB → 31.4MB）

**Go言語の例**:
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

### 2. キャッシュ最適化（必須）
**変更頻度の低いものを先に配置**

```dockerfile
# 正しい順序
COPY package.json package-lock.json ./  # 依存関係定義（変更少）
RUN npm ci                               # 依存関係インストール
COPY . .                                 # アプリケーションコード（変更多）
```

### 3. .dockerignore（必須）
プロジェクトルートに`.dockerignore`を必ず作成

```dockerignore
# Git
.git
.gitignore

# 依存関係（ビルド時に再インストール）
node_modules
.venv
__pycache__

# ビルド成果物
dist
build

# 環境ファイル（機密情報）
.env*
!.env.example
```

### 4. セキュリティ強化（必須）

**非rootユーザー実行**:
```dockerfile
# UID 65532 (nonroot) を使用
USER 65532:65532

# またはDistrolessベースイメージ
FROM gcr.io/distroless/static:nonroot
```

**ENTRYPOINT vs CMD**:
```dockerfile
# ENTRYPOINT: 固定コマンド（変更不可）
ENTRYPOINT ["python", "-m", "app"]

# CMD: デフォルト引数（実行時に上書き可能）
CMD ["--port", "8080"]
```

### 5. イメージ脆弱性スキャン（推奨）
```bash
# Docker Scout
docker scout cves myimage:latest

# Trivy
trivy image myimage:latest
```

### 6. Hadolintによる静的解析（推奨）
```bash
# ローカル実行
hadolint Dockerfile

# Docker経由
docker run --rm -i hadolint/hadolint < Dockerfile
```

### チェックリスト
- [ ] マルチステージビルドを使用
- [ ] 依存関係ファイルを先にCOPY
- [ ] RUNコマンドを統合
- [ ] .dockerignoreを作成
- [ ] 非rootユーザーで実行
- [ ] ENTRYPOINTとCMDを適切に使い分け
- [ ] バージョンタグを固定（`:latest`を避ける）

**詳細は [DOCKERFILE-BEST-PRACTICES.md](./references/DOCKERFILE-BEST-PRACTICES.md) を参照してください。**

---

## ⚠️ Docker Composeベストプラクティス

主要ポイント:
1. **環境変数管理**: .envファイルで管理、.gitignore追加
2. **ヘルスチェック**: コンテナの正常性監視
3. **ボリューム活用**: データ永続化
4. **ネットワーク分離**: セキュリティ向上
5. **ログ管理**: ログドライバー設定

## 🔧 トラブルシューティング

### コンテナが起動しない
```bash
# ログ確認
mcp__docker__get_container_logs({ container_name: "..." })

# コンテナ詳細確認
# Bash: docker inspect container_name
```

### イメージビルド失敗
```bash
# キャッシュなしで再ビルド
# Bash: docker build --no-cache -t image_name .
```

### ネットワーク問題
```bash
# ネットワーク確認
# Bash: docker network ls
# Bash: docker network inspect network_name
```

## 📚 主要コマンド
- `list_containers` - コンテナ一覧
- `start_container` - コンテナ起動
- `stop_container` - コンテナ停止
- `build_image` - イメージビルド
- `compose_up` - Compose起動
- `get_container_logs` - ログ取得

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

| 確認項目 | 例 |
|---|---|
| ベースイメージ | alpine, debian, ubuntu, distroless |
| Compose構成 | 開発用のみ, 本番用も, プロファイル分離 |
| ポートマッピング | ホスト側ポート番号、既存サービスとの競合 |
| ボリューム戦略 | bind mount, named volume, tmpfs |
| ネットワーク構成 | デフォルト, カスタムネットワーク |

### 確認不要な場面

- Docker Composeバージョン（v2がデフォルト）
- .dockerignoreの作成（常に必須）
- ヘルスチェックの追加（常に推奨）

## 🔗 関連ツール
- **filesystem MCP**: Dockerfile、docker-compose.yml編集
- **serena MCP**: アプリケーションコード編集
- **bash**: docker CLI直接実行
