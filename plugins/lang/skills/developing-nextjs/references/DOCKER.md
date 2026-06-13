# Docker デプロイガイド

## 概要

Next.js 16.xアプリケーションのマルチステージビルドとGCP Cloud Runへのデプロイガイド。

## Dockerfile（マルチステージビルド）

### 完全なDockerfile

```dockerfile
# ================================
# Base stage - Node.js runtime with pnpm
# ================================
FROM node:22-bookworm-slim AS base

ENV HOSTNAME=0.0.0.0
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV COREPACK_INTEGRITY_KEYS=0

RUN corepack enable && corepack prepare pnpm@latest --activate

RUN apt-get update \
  && apt-get -qq install -y --no-install-recommends \
  tini build-essential \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir /app && chown node:node /app

# ================================
# Builder stage
# ================================
FROM base AS builder

USER node
WORKDIR /app

# ビルド時環境変数（NEXT_PUBLIC_*はビルド時にバンドルされる）
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_FIREBASE_API_KEY
# ... プロジェクト固有のNEXT_PUBLIC_*変数を追加

ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_FIREBASE_API_KEY=$NEXT_PUBLIC_FIREBASE_API_KEY

COPY --chown=node:node package.json pnpm-lock.yaml ./

RUN pnpm install --frozen-lockfile --ignore-scripts

COPY --chown=node:node . .

RUN rm -rf .next && \
  npx next telemetry disable && \
  npx prisma generate && \
  pnpm next build

# ================================
# Runner stage - Production
# ================================
FROM base AS prod

USER node
WORKDIR /app

EXPOSE 3000

# Next.js standaloneアプリケーションをコピー
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/public ./public/
COPY --from=builder /app/.next/static ./.next/static

# Prismaマイグレーション用ファイルをコピー
COPY --from=builder /app/prisma ./prisma/
COPY --from=builder /app/prisma.config.ts ./

COPY --chown=node:node docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["./docker-entrypoint.sh"]
```

### ステージ説明

#### 1. base（基本イメージ）

```dockerfile
FROM node:22-bookworm-slim AS base

ENV HOSTNAME=0.0.0.0
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV COREPACK_INTEGRITY_KEYS=0

RUN corepack enable && corepack prepare pnpm@latest --activate

RUN apt-get update \
  && apt-get -qq install -y --no-install-recommends \
  tini build-essential \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir /app && chown node:node /app
```

**ポイント:**
- `node:22-bookworm-slim`: 軽量なDebianベースイメージ（Node.js 22.x LTS）
- `HOSTNAME=0.0.0.0`: すべてのネットワークインターフェースでリッスン
- `PNPM_HOME` + `PATH`: pnpmのグローバルバイナリパスを設定
- `COREPACK_INTEGRITY_KEYS=0`: Corepackの整合性チェックをスキップ（Docker内での安定動作）
- `corepack enable && corepack prepare pnpm@latest --activate`: pnpmを有効化
- `tini`: プロセスマネージャー（シグナル処理、ゾンビプロセス回避）
- `build-essential`: Prismaネイティブバイナリビルド用

#### 2. builder（ビルドステージ）

```dockerfile
FROM base AS builder

USER node
WORKDIR /app

ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

COPY --chown=node:node package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --ignore-scripts

COPY --chown=node:node . .

RUN rm -rf .next && \
  npx next telemetry disable && \
  npx prisma generate && \
  pnpm next build
```

**ポイント:**
- `USER node`: rootユーザーを使用しない（セキュリティ）
- `ARG NEXT_PUBLIC_*`: ビルド時にバンドルされるクライアント向け環境変数
- `pnpm install --frozen-lockfile --ignore-scripts`: lockfileを厳密に使用、postinstallスキップ
- `COPY --chown=node:node . .`: 簡潔なソースコピー（.dockerignoreで不要ファイル除外）
- `rm -rf .next`: 前回のビルドキャッシュをクリア
- `npx prisma generate`: Prismaクライアント生成
- `pnpm next build`: Next.jsビルド（standalone出力）

#### 3. prod（本番イメージ）

```dockerfile
FROM base AS prod

USER node
WORKDIR /app

EXPOSE 3000

COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/public ./public/
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/prisma ./prisma/
COPY --from=builder /app/prisma.config.ts ./

COPY --chown=node:node docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["./docker-entrypoint.sh"]
```

**ポイント:**
- `COPY --from=builder`: ビルド成果物のみコピー（イメージ軽量化）
- `.next/standalone`: Next.jsが生成したスタンドアロンサーバー
- `prisma/` + `prisma.config.ts`: マイグレーション実行用
- `tini`: ENTRYPOINTとしてシグナルハンドリング

## Prisma 7.x対応

### standaloneモードでのPrisma CLI

Next.jsの `output: "standalone"` はnode_modulesをトリミングするため、Prisma CLIが含まれない。本番イメージでマイグレーションを実行するには、Prisma CLIを別ディレクトリにインストールする。

```dockerfile
# prod ステージに追加
RUN mkdir -p /app/prisma-cli
WORKDIR /app/prisma-cli
RUN echo '{"dependencies":{"prisma":"latest","dotenv":"latest"}}' > package.json && \
  pnpm install --prod
WORKDIR /app

ENV PRISMA_CLI_PATH=/app/prisma-cli/node_modules/prisma/build/index.js
ENV NODE_PATH=/app/prisma-cli/node_modules
```

**ポイント:**
- `/app/prisma-cli`: standaloneの `node_modules` を上書きしない独立ディレクトリ
- `PRISMA_CLI_PATH`: マイグレーションスクリプトからPrisma CLIを参照するパス
- `NODE_PATH`: `prisma.config.ts` が `dotenv` 等を解決できるように設定

### prisma.config.ts（Prisma 7.x）

```typescript
// prisma.config.ts
import path from "node:path";
import { defineConfig } from "prisma/config";

export default defineConfig({
  earlyAccess: true,
  migrate: {
    schema: path.join(__dirname, "prisma/schema.prisma"),
  },
});
```

## ビルドコマンド

```bash
# Turbopackでビルド（デフォルト、Next.js 16.x）
pnpm next build

# Webpackでビルド（QEMU互換性が必要な場合）
pnpm next build --webpack
```

**使い分け:**
- **通常**: `pnpm next build` でTurbopackを使用（高速）
- **QEMU/クロスコンパイル環境**: `pnpm next build --webpack` を使用（Turbopackはネイティブバイナリのため、エミュレーション環境で動作しない場合がある）

## docker-entrypoint.sh

```bash
#!/bin/sh
set -e

echo "[docker-entrypoint] Starting Next.js application..."

# Prismaマイグレーション（PRISMA_CLI_PATHが設定されている場合）
if [ -n "$PRISMA_CLI_PATH" ] && [ -z "$SKIP_DB_MIGRATION" ]; then
  echo "[docker-entrypoint] Running database migration..."
  node "$PRISMA_CLI_PATH" migrate deploy
  echo "[docker-entrypoint] Migration completed."
fi

echo "[docker-entrypoint] Starting Node.js server..."
exec node server.js
```

**ポイント:**
- `SKIP_DB_MIGRATION`: 環境変数でマイグレーションをスキップ可能
- `exec node server.js`: PID 1をNode.jsプロセスに置換（tiniがシグナルを適切にフォワード）

## Next.js設定（standalone出力）

### next.config.ts

```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  output: "standalone",

  logging: {
    fetches: {
      fullUrl: false,
    },
  },
};

export default nextConfig;
```

**`output: "standalone"`の効果:**
- `.next/standalone`ディレクトリに最小限のファイルを出力
- `node_modules`全体ではなく、必要な依存関係のみ含む
- イメージサイズを大幅削減

## docker-compose.yml（開発環境）

```yaml
services:
  db:
    image: postgres:16-alpine
    container_name: next-app-db
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: dbname
    ports:
      - "5432:5432"
    volumes:
      - db-data:/var/lib/postgresql/data

  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: prod
    container_name: next-app
    depends_on:
      - db
    environment:
      DATABASE_URL: postgresql://user:password@db:5432/dbname
    ports:
      - "3000:3000"

volumes:
  db-data:
```

## ビルドとデプロイ

### ローカルビルド

```bash
# イメージビルド
docker build -t next-app .

# ビルド引数付き（NEXT_PUBLIC_*変数）
docker build \
  --build-arg NEXT_PUBLIC_API_URL=https://api.example.com \
  -t next-app .

# コンテナ起動
docker run -p 3000:3000 \
  -e DATABASE_URL=postgresql://user:password@localhost:5432/dbname \
  next-app

# docker compose起動
docker compose up -d

# ログ確認
docker compose logs -f
```

### GCP Cloud Runへのデプロイ

#### 1. Artifact Registryにプッシュ

```bash
# 認証設定
gcloud auth configure-docker asia-northeast1-docker.pkg.dev

# イメージビルド
docker build -t asia-northeast1-docker.pkg.dev/PROJECT_ID/next-app/app:latest .

# プッシュ
docker push asia-northeast1-docker.pkg.dev/PROJECT_ID/next-app/app:latest
```

#### 2. Cloud Runデプロイ

```bash
gcloud run deploy next-app \
  --image asia-northeast1-docker.pkg.dev/PROJECT_ID/next-app/app:latest \
  --platform managed \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --set-env-vars "DATABASE_URL=postgresql://user:password@host:5432/dbname" \
  --set-env-vars "NODE_ENV=production"
```

#### 3. Cloud Buildでの自動デプロイ

**cloudbuild.yaml:**
```yaml
steps:
  - name: "gcr.io/cloud-builders/docker"
    args:
      - "build"
      - "-t"
      - "asia-northeast1-docker.pkg.dev/$PROJECT_ID/next-app/app:$SHORT_SHA"
      - "."

  - name: "gcr.io/cloud-builders/docker"
    args:
      - "push"
      - "asia-northeast1-docker.pkg.dev/$PROJECT_ID/next-app/app:$SHORT_SHA"

  - name: "gcr.io/google.com/cloudsdktool/cloud-sdk"
    entrypoint: gcloud
    args:
      - "run"
      - "deploy"
      - "next-app"
      - "--image"
      - "asia-northeast1-docker.pkg.dev/$PROJECT_ID/next-app/app:$SHORT_SHA"
      - "--region"
      - "asia-northeast1"
      - "--platform"
      - "managed"

images:
  - "asia-northeast1-docker.pkg.dev/$PROJECT_ID/next-app/app:$SHORT_SHA"
```

## .dockerignore

```
node_modules
.next
.git
.vscode
coverage
playwright-report
test-results
*.md
!README.md
```

## トラブルシューティング

### イメージサイズが大きい

**解決策:**
- `output: "standalone"`が有効か確認
- `.dockerignore`を設定（上記参照）
- マルチステージビルドでビルド成果物のみコピー

### Prismaクライアントエラー

**解決策:**
```bash
# Prismaクライアント再生成
docker exec -it next-app npx prisma generate
```

### QEMUビルドでTurbopackが失敗

**解決策:**
```bash
# Webpackフォールバック
RUN pnpm next build --webpack
```

### メモリ不足

**Cloud Run設定:**
```bash
gcloud run deploy next-app \
  --memory 1Gi \
  --cpu 1
```

## ベストプラクティス

### 1. マルチステージビルド

**イメージサイズを最小化:**
- 開発依存関係を本番イメージに含めない
- ビルド成果物のみコピー

### 2. セキュリティ

**rootユーザーを使用しない:**
```dockerfile
USER node
```

### 3. ヘルスチェック

**Dockerfile:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD node -e "require('http').get('http://localhost:3000/', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"
```

---

## AskUserQuestion（Docker構成の確認）

プロジェクト初期設定時に確認する項目:

| 確認項目 | 選択肢 | デフォルト |
|---------|--------|----------|
| ベースイメージ | slim（Debian系） / alpine（Alpine Linux） | slim（推奨） |
| プロセスマネージャ | tini / dumb-init | tini（推奨） |

## 参考資料

- **Next.js Dockerガイド**: https://nextjs.org/docs/deployment#docker-image
- **GCP Cloud Run**: https://cloud.google.com/run/docs
- **Docker公式**: https://docs.docker.com

---

**関連ドキュメント:**
- [TOOLING.md](./TOOLING.md) - 開発ツール設定
- [PROJECT-STRUCTURE.md](./PROJECT-STRUCTURE.md) - プロジェクト構造
