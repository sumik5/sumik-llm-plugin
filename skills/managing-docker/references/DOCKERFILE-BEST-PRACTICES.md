---
name: managing-docker
description: Guides Dockerfile creation and optimization. Use when Dockerfile or Docker Compose is detected. Supports multi-stage builds, cache optimization, security hardening, and image size minimization.
---

# Dockerfile ベストプラクティス

## 使用タイミング
- **Dockerfile作成・修正時は必ずこのスキルを参照**
- コンテナ化プロジェクトの新規作成
- 既存Dockerfileの最適化
- セキュリティレビュー

---

## 1. マルチステージビルド（必須）

### 基本原則
ビルド環境と実行環境を分離し、最終イメージサイズを大幅削減（例: 916MB → 31.4MB）

### Go言語の例
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

### Node.jsの例
```dockerfile
# ビルドステージ
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# 実行ステージ
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER node
CMD ["node", "dist/index.js"]
```

### Pythonの例
```dockerfile
# ビルドステージ
FROM python:3.12-slim AS builder
WORKDIR /app
RUN pip install --no-cache-dir uv
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

# 実行ステージ
FROM python:3.12-slim AS runner
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY . .
ENV PATH="/app/.venv/bin:$PATH"
USER nobody
CMD ["python", "-m", "app"]
```

---

## 2. キャッシュ最適化（必須）

### レイヤー順序の原則
**変更頻度の低いものを先に配置**

```dockerfile
# 正しい順序
COPY package.json package-lock.json ./  # 依存関係定義（変更少）
RUN npm ci                               # 依存関係インストール
COPY . .                                 # アプリケーションコード（変更多）

# 間違い: ソースコード変更で依存関係キャッシュが無効化
COPY . .
RUN npm ci
```

### RUNコマンドの統合
関連操作を1つのRUNで実行し、レイヤー数とサイズを最小化

```dockerfile
# 推奨
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 非推奨: 不要なレイヤーとキャッシュが残る
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y ca-certificates
```

---

## 3. .dockerignore（必須）

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
*.egg-info

# テスト・ドキュメント
tests
docs
*.md
!README.md

# IDE・エディタ
.vscode
.idea
*.swp

# 環境ファイル（機密情報）
.env*
!.env.example

# Docker関連
Dockerfile*
docker-compose*
.dockerignore
```

---

## 4. セキュリティ強化（必須）

### 非rootユーザー実行
```dockerfile
# UID 65532 (nonroot) を使用
USER 65532:65532

# または名前付きユーザー
USER nobody

# Node.jsの場合
USER node
```

### Distrolessベースイメージ
シェルやパッケージマネージャーを含まない最小イメージ

```dockerfile
# 静的バイナリ用
FROM gcr.io/distroless/static:nonroot

# 動的リンク用
FROM gcr.io/distroless/base:nonroot

# Python用
FROM gcr.io/distroless/python3:nonroot

# Node.js用
FROM gcr.io/distroless/nodejs20:nonroot
```

### ENTRYPOINT vs CMD
```dockerfile
# ENTRYPOINT: 固定コマンド（変更不可）
ENTRYPOINT ["python", "-m", "app"]

# CMD: デフォルト引数（実行時に上書き可能）
CMD ["--port", "8080"]

# 組み合わせ例
ENTRYPOINT ["python", "-m", "app"]
CMD ["--port", "8080"]
# 実行: docker run myapp --port 3000  → python -m app --port 3000
```

---

## 5. イメージ脆弱性スキャン（推奨）

### CI/CDパイプラインに組み込む
```yaml
# GitHub Actions例
- name: Scan for vulnerabilities
  uses: docker/scout-action@v1
  with:
    command: cves
    image: ${{ env.IMAGE_NAME }}
    only-severities: critical,high
    exit-code: true  # 脆弱性検出時に失敗
```

### ローカルスキャン
```bash
# Docker Scout
docker scout cves myimage:latest

# Trivy
trivy image myimage:latest
```

---

## 6. Hadolintによる静的解析（推奨）

### よく指摘される問題
- `latest`タグの使用 → バージョン固定を推奨
- 非効率なレイヤー構造
- キャッシュ最適化の欠如
- セキュリティ上の問題

### 実行方法
```bash
# ローカル実行
hadolint Dockerfile

# Docker経由
docker run --rm -i hadolint/hadolint < Dockerfile
```

### CI/CD統合
```yaml
# GitHub Actions
- name: Lint Dockerfile
  uses: hadolint/hadolint-action@v3.1.0
  with:
    dockerfile: Dockerfile
```

---

## 7. チェックリスト

### 作成時の必須確認事項
- [ ] マルチステージビルドを使用
- [ ] 依存関係ファイルを先にCOPY
- [ ] RUNコマンドを統合
- [ ] .dockerignoreを作成
- [ ] 非rootユーザーで実行
- [ ] ENTRYPOINTとCMDを適切に使い分け
- [ ] バージョンタグを固定（`:latest`を避ける）

### レビュー時の確認事項
- [ ] 不要なファイルがイメージに含まれていない
- [ ] 機密情報（APIキー等）がイメージに含まれていない
- [ ] ヘルスチェックが設定されている
- [ ] 脆弱性スキャンをパス

---

## 8. 参考リソース

- [Docker公式ベストプラクティス](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Google Distroless Images](https://github.com/GoogleContainerTools/distroless)
- [Hadolint](https://github.com/hadolint/hadolint)
- [Docker Scout](https://docs.docker.com/scout/)

---

## 9. docker init による自動生成

### 概要
Docker v23.0以降では、`docker init` コマンドでビルドコンテキストを解析し、ベストプラクティスに基づいたDockerfileを自動生成できます。

### 使い方
```bash
# プロジェクトディレクトリで実行
docker init

# 対話的に以下を選択
? What application platform does your project use? Node
? What version of Node do you want to use? 23.3.0
? Which package manager do you want to use? npm
? What command do you want to use to start the app? node app.js
? What port does your server listen on? 8080

# 自動生成されるファイル
CREATED: .dockerignore
CREATED: Dockerfile
CREATED: compose.yaml
CREATED: README.Docker.md
```

### 生成されるDockerfileの特徴
- マルチステージビルド（該当する場合）
- BuildKitマウントによる依存関係のキャッシュ最適化
- 非rootユーザーでの実行
- ベストプラクティスに準拠した構成

### 対応プラットフォーム
- Node.js
- Python
- Go
- Rust
- PHP
- Java/Kotlin
- ASP.NET

---

## 10. BuildKit と buildx

### BuildKitの特徴
Dockerの最新ビルドエンジン（Docker v23.0以降はデフォルト）

**主要機能:**
- 並列ビルドによる高速化
- マルチステージビルドの並列実行
- 高度なキャッシュ機構
- bind mount、cache mount、tmpfs mount
- Build secrets（機密情報の安全な受け渡し）

### buildxによるマルチアーキテクチャビルド

**基本構文:**
```bash
# AMD64 + ARM64のマルチアーキテクチャイメージをビルド
docker buildx build \
  --platform=linux/amd64,linux/arm64 \
  -t myapp:latest \
  --push .
```

**ビルダー作成:**
```bash
# docker-containerドライバを使用したビルダー作成
docker buildx create --driver=docker-container --name=container

# デフォルトビルダーとして設定
docker buildx use container

# ビルダー一覧確認
docker buildx ls
```

**対応プラットフォーム例:**
- linux/amd64
- linux/arm64
- linux/arm/v7
- linux/arm/v6
- linux/386
- linux/ppc64le
- linux/s390x
- linux/riscv64

### Docker Build Cloud
有料サブスクリプションで利用可能なクラウドビルドサービス

**メリット:**
- ネイティブハードウェアによる高速ビルド
- チーム全体で共有可能なビルドキャッシュ
- ローカルマシンのリソース消費なし

**使用方法:**
```bash
# クラウドビルダー作成
docker buildx create --driver cloud <org>/<builder-name>

# クラウドビルダーを使用したビルド
docker buildx build \
  --builder=cloud-<org>-<name> \
  --platform=linux/amd64,linux/arm64 \
  -t myapp:latest --push .
```

### キャッシュマウント（BuildKit）
依存関係インストールを劇的に高速化

**例（Node.js）:**
```dockerfile
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev
```

**例（Python）:**
```dockerfile
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

**例（Go）:**
```dockerfile
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download
```

---

## 11. マルチステージビルドの実践パターン

### パターン1: ビルドと実行の分離
```dockerfile
# ビルドステージ
FROM golang:1.23 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o main .

# 実行ステージ
FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app/main /main
USER 65532:65532
ENTRYPOINT ["/main"]
```

### パターン2: 並列ビルドステージ
```dockerfile
FROM golang:1.23-alpine AS base
WORKDIR /src
COPY go.mod go.sum .
RUN go mod download
COPY . .

FROM base AS build-client
RUN go build -o /bin/client ./cmd/client

FROM base AS build-server
RUN go build -o /bin/server ./cmd/server

FROM scratch AS prod
COPY --from=build-client /bin/client /bin/
COPY --from=build-server /bin/server /bin/
ENTRYPOINT [ "/bin/server" ]
```

### パターン3: ビルドターゲット指定
```dockerfile
FROM node:20-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM base AS development
ENV NODE_ENV=development
COPY . .
CMD ["npm", "run", "dev"]

FROM base AS production
ENV NODE_ENV=production
COPY . .
RUN npm run build
USER node
CMD ["node", "dist/index.js"]
```

**ビルド方法:**
```bash
# 開発用イメージ
docker build --target development -t myapp:dev .

# 本番用イメージ
docker build --target production -t myapp:prod .
```

---

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

| 確認項目 | 例 |
|---|---|
| ベースイメージ | node:22-alpine, python:3.13-slim, golang:1.23 |
| マルチステージ構成 | ビルドステージ数、最終イメージの構成 |
| 実行ユーザー | root, 非rootユーザー名 |
| パッケージマネージャー | apt, apk, yum |
| キャッシュ戦略 | BuildKit cache mount使用有無 |
| 用途 | 開発用, 本番用, CI/CD用 |

### 確認不要な場面

- COPY前の.dockerignore確認（常に必須）
- 不要パッケージの削除（常に実施）
- LABELメタデータの付与（常に推奨）
