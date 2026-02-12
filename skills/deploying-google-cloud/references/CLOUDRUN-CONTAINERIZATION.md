# コンテナ化（Cloud Run向けDockerfile最適化）

Cloud Run向けのコンテナ化では、軽量性、高速起動、セキュリティを重視したDockerfileの設計が求められる。本リファレンスではCloud Run固有の要件に焦点を当てたコンテナ化のベストプラクティスを解説する。

## Cloud Run向けDockerfileベストプラクティス

### ベースイメージ選択

コンテナイメージのサイズとセキュリティはベースイメージの選択で大きく変わる。

| ベースイメージ | サイズ | 用途 | 注意点 |
|--------------|-------|------|--------|
| Alpine Linux | 最小 | Node.js, Python, Go | 一部ネイティブライブラリが不足する場合あり |
| slim variant | 小 | 公式言語イメージの軽量版 | 基本的なツールは含む |
| distroless | 最小 | セキュリティ重視の本番環境 | デバッグツールなし |
| 標準イメージ | 大 | 開発・ビルド環境 | 本番環境には不適切 |

**推奨パターン（Python）:**

```dockerfile
# 軽量版を使用
FROM python:3.9-slim

# 作業ディレクトリ設定
WORKDIR /app

# 依存関係のみ先にコピー（キャッシュ最適化）
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードをコピー
COPY . .

# Cloud RunはPORT環境変数を設定
ENV PORT=8080
EXPOSE 8080

CMD ["python", "app.py"]
```

**推奨パターン（Node.js）:**

```dockerfile
FROM node:14-alpine

WORKDIR /usr/src/app

# package.jsonのみ先にコピー
COPY package*.json ./
RUN npm install --only=production

COPY . .

EXPOSE 8080
CMD ["node", "server.js"]
```

### マルチステージビルド

ビルドツールと本番環境を分離し、最終イメージサイズを削減する。

**Go アプリケーションの例:**

```dockerfile
# ビルドステージ
FROM golang:1.18-alpine AS builder
WORKDIR /src
COPY . .
RUN go build -o my-app .

# 本番ステージ
FROM alpine:latest
WORKDIR /app
COPY --from=builder /src/my-app .
EXPOSE 8080
CMD ["./my-app"]
```

**Node.js アプリケーションの例:**

```dockerfile
# ビルドステージ
FROM node:14-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# 本番ステージ
FROM node:14-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
EXPOSE 8080
CMD ["node", "dist/server.js"]
```

### レイヤーキャッシュ最適化

Dockerのレイヤーキャッシュを活用してビルド時間を短縮する。

**キャッシュ最適化の原則:**

1. 変更頻度の低いファイルを先にコピー
2. 依存関係インストールとソースコードコピーを分離
3. 一時ファイルは同一RUN命令内で削除

**悪い例:**

```dockerfile
# 全ファイルをコピーしてからインストール
COPY . .
RUN npm install
```

**良い例:**

```dockerfile
# 依存関係定義ファイルのみ先にコピー
COPY package*.json ./
RUN npm install
# ソースコードは後でコピー
COPY . .
```

**レイヤー数削減の例（Python）:**

```dockerfile
# 複数のRUNを結合
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libpq-dev gcc && \
    rm -rf /var/lib/apt/lists/*
```

### .dockerignore設定

不要なファイルをビルドコンテキストから除外し、ビルド速度とセキュリティを向上させる。

**.dockerignore サンプル:**

```
# バージョン管理
.git
.gitignore
.github

# Node.js
node_modules
npm-debug.log

# Python
__pycache__
*.pyc
*.pyo
.pytest_cache
venv/

# 環境変数ファイル（機密情報）
.env
.env.local
*.key
credentials.json

# ログ・一時ファイル
*.log
tmp/
temp/

# IDE設定
.vscode/
.idea/
*.swp

# ドキュメント
README.md
docs/
```

## Cloud Run固有のコンテナ要件

### PORT環境変数のリッスン

Cloud RunはコンテナにPORT環境変数を注入する。アプリケーションはこの値を読み取って待ち受けポートを設定する必要がある。

**Python (Flask) の例:**

```python
import os
from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return 'Hello, Cloud Run!'

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
```

**Node.js (Express) の例:**

```javascript
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.send('Hello, Cloud Run!');
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
```

**Dockerfile での設定:**

```dockerfile
# 環境変数を設定（Cloud Runはこれを上書きする）
ENV PORT=8080
EXPOSE 8080

# アプリケーションがPORT環境変数を読み取る
CMD ["python", "app.py"]
```

### ステートレス設計

Cloud Runはリクエスト駆動でコンテナをスケールする。コンテナインスタンス間で状態を共有してはならない。

| 保存場所 | 用途 | Cloud Runでの扱い |
|---------|------|------------------|
| ローカルファイルシステム | ❌ 一時ファイルのみ | インスタンス破棄時に消失 |
| メモリ内セッション | ❌ 使用不可 | インスタンス間で共有されない |
| Cloud Storage | ✅ ファイル保存 | 永続化可能 |
| Cloud Firestore | ✅ データベース | 永続化可能 |
| Memorystore | ✅ セッション/キャッシュ | Redis/Memcached |

**ステートレス設計の原則:**

```dockerfile
# 一時ファイルは /tmp に書き込む（書き込み可能な唯一のディレクトリ）
RUN mkdir -p /tmp/uploads
ENV TEMP_DIR=/tmp/uploads
```

### コールドスタート最適化

コールドスタート（新規コンテナの起動）を高速化する技術。

| 最適化手法 | 効果 | 実装方法 |
|----------|------|---------|
| イメージサイズ削減 | 高 | Alpine/slim/distroless使用 |
| 起動時処理の最小化 | 高 | 遅延初期化、接続プーリング |
| 依存関係の削減 | 中 | 不要なライブラリを除外 |
| min-instances設定 | 高 | 常時1インスタンス維持（有料） |

**起動時処理の最適化例:**

```python
# 悪い例: アプリ起動時に全データをロード
def load_all_data():
    # 大量のデータをロード（起動が遅くなる）
    pass

# 良い例: 遅延初期化
data_cache = None

def get_data():
    global data_cache
    if data_cache is None:
        data_cache = load_data()
    return data_cache
```

**Dockerfile での最適化:**

```dockerfile
# マルチステージビルドで不要なファイルを除外
FROM node:14-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build && npm prune --production

FROM node:14-alpine
WORKDIR /app
# 本番依存関係のみコピー
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
CMD ["node", "dist/server.js"]
```

## Container Registry / Artifact Registry

### イメージプッシュ手順

**Google Container Registry (GCR) の場合:**

```bash
# Docker認証設定
gcloud auth configure-docker

# イメージのビルドとタグ付け
docker build -t gcr.io/my-project/my-app:latest .

# イメージをプッシュ
docker push gcr.io/my-project/my-app:latest
```

**Artifact Registry の場合:**

```bash
# リポジトリ作成
gcloud artifacts repositories create my-repo \
  --repository-format=docker \
  --location=us-central1 \
  --description="Docker repository for Cloud Run"

# Docker認証設定
gcloud auth configure-docker us-central1-docker.pkg.dev

# イメージのビルドとタグ付け
docker build -t us-central1-docker.pkg.dev/my-project/my-repo/my-app:latest .

# イメージをプッシュ
docker push us-central1-docker.pkg.dev/my-project/my-repo/my-app:latest
```

### 脆弱性スキャン

コンテナイメージをスキャンして既知の脆弱性を検出する。

**Trivy によるスキャン:**

```bash
# イメージのスキャン
trivy image gcr.io/my-project/my-app:latest

# 重大度を指定してスキャン（HIGH以上のみ）
trivy image --severity HIGH,CRITICAL gcr.io/my-project/my-app:latest

# 出力形式を指定（JSON）
trivy image -f json -o results.json gcr.io/my-project/my-app:latest
```

**CI/CDパイプラインへの統合（Cloud Build）:**

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']

  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']

  # Trivyスキャンステップ
  - name: 'aquasec/trivy'
    args:
      - 'image'
      - '--exit-code'
      - '1'
      - '--severity'
      - 'HIGH,CRITICAL'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
```

### イメージ一覧・削除コマンド

**GCRの場合:**

```bash
# イメージ一覧
gcloud container images list --repository=gcr.io/my-project

# 特定イメージのタグ一覧
gcloud container images list-tags gcr.io/my-project/my-app

# イメージの削除
gcloud container images delete gcr.io/my-project/my-app:old-tag --quiet
```

**Artifact Registryの場合:**

```bash
# イメージ一覧
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/my-project/my-repo

# イメージの削除
gcloud artifacts docker images delete \
  us-central1-docker.pkg.dev/my-project/my-repo/my-app:old-tag --delete-tags
```

## セキュリティ強化

### 非rootユーザーでの実行

コンテナをrootユーザーで実行するのはセキュリティリスクが高い。専用ユーザーを作成して権限を制限する。

**Dockerfileの例:**

```dockerfile
FROM python:3.9-slim

WORKDIR /app

# 非rootユーザーを作成
RUN addgroup --system appgroup && \
    adduser --system --group appuser

# 依存関係インストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードをコピー
COPY . .

# ファイルの所有権を変更
RUN chown -R appuser:appgroup /app

# 非rootユーザーに切り替え
USER appuser

EXPOSE 8080
CMD ["python", "app.py"]
```

### 読み取り専用ファイルシステム

Cloud Runは `/tmp` 以外のディレクトリへの書き込みを制限できる（セキュリティ強化）。

**Dockerfile での対応:**

```dockerfile
# 書き込みが必要なディレクトリは /tmp 配下に配置
RUN mkdir -p /tmp/cache /tmp/uploads
ENV CACHE_DIR=/tmp/cache
ENV UPLOAD_DIR=/tmp/uploads

# 読み取り専用でデプロイ（gcloud run deploy 時に指定）
# --execution-environment=gen2 --no-allow-unauthenticated
```

### 機密情報の管理

Dockerfileに機密情報をハードコードしない。Cloud Runのデプロイ時に環境変数またはSecret Managerで注入する。

**悪い例:**

```dockerfile
# ❌ 機密情報をハードコード
ENV DATABASE_PASSWORD=mysecretpassword
```

**良い例（環境変数）:**

```bash
# デプロイ時に環境変数を注入
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --set-env-vars "DATABASE_URL=postgres://user:pass@host:5432/db"
```

**良い例（Secret Manager）:**

```bash
# Secret Manager にシークレットを作成
echo -n "mysecretpassword" | gcloud secrets create db-password --data-file=-

# Cloud Run デプロイ時にシークレットをマウント
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --update-secrets DATABASE_PASSWORD=db-password:latest
```

**アプリケーションコードでの読み取り:**

```python
import os

# 環境変数から読み取る
database_password = os.environ.get('DATABASE_PASSWORD')
```

## コード例集

### Python Flask アプリケーション

**Dockerfile:**

```dockerfile
FROM python:3.9-slim

WORKDIR /app

# 非rootユーザー作成
RUN addgroup --system appgroup && \
    adduser --system --group appuser

# 依存関係インストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコピー
COPY . .
RUN chown -R appuser:appgroup /app

USER appuser

ENV PORT=8080
EXPOSE 8080

CMD ["python", "app.py"]
```

**app.py:**

```python
import os
from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello():
    return 'Hello, Cloud Run!'

@app.route('/health')
def health():
    return {'status': 'healthy'}, 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
```

### Node.js Express アプリケーション

**Dockerfile:**

```dockerfile
FROM node:14-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM node:14-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

# 非rootユーザー（alpineのデフォルトユーザー）
USER node

EXPOSE 8080
CMD ["node", "dist/server.js"]
```

**server.js:**

```javascript
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.send('Hello, Cloud Run!');
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
```

### Go アプリケーション

**Dockerfile:**

```dockerfile
# ビルドステージ
FROM golang:1.18-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o my-app .

# 本番ステージ（distroless）
FROM gcr.io/distroless/static-debian11
WORKDIR /app
COPY --from=builder /src/my-app .
EXPOSE 8080
CMD ["./my-app"]
```

**main.go:**

```go
package main

import (
    "fmt"
    "log"
    "net/http"
    "os"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "Hello, Cloud Run!")
    })

    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        fmt.Fprintf(w, `{"status":"healthy"}`)
    })

    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    log.Printf("Server starting on port %s", port)
    log.Fatal(http.ListenAndServe(":"+port, nil))
}
```

## トラブルシューティング

### コンテナが起動しない

**症状:**
- Cloud Runにデプロイ後、コンテナが起動エラーとなる

**原因と対処:**

| 原因 | 対処方法 |
|-----|---------|
| PORTを正しくリッスンしていない | 環境変数 `PORT` を読み取る実装を追加 |
| ヘルスチェックに失敗 | `/` または `/health` エンドポイントを実装 |
| 非rootユーザーでファイルアクセスできない | `chown` でファイル所有権を変更 |
| 依存関係不足 | ベースイメージに必要なライブラリを追加 |

**ログ確認コマンド:**

```bash
# Cloud Run のログを確認
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=my-app" --limit 50
```

### イメージサイズが大きすぎる

**対処方法:**

1. マルチステージビルドを使用
2. Alpine/slim ベースイメージに変更
3. 不要なファイルを `.dockerignore` で除外
4. `npm prune --production` で開発依存関係を削除

**サイズ確認:**

```bash
docker images gcr.io/my-project/my-app:latest
```

### ビルドが遅い

**対処方法:**

1. レイヤーキャッシュを最適化
2. 依存関係定義ファイルを先にコピー
3. Cloud Build のマシンタイプを上げる（`--machine-type=E2_HIGHCPU_8`）

**ビルド時間計測:**

```bash
time docker build -t my-app:latest .
```
