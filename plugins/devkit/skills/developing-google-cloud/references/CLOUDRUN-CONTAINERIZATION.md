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

### .dockerignore 詳細テンプレート（言語・用途別）

**Python プロジェクト向け:**

```
# バージョン管理
.git
.gitignore
.gitattributes

# Python バイトコード・キャッシュ
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# 仮想環境
venv/
ENV/
env/
.venv

# テスト
.pytest_cache/
.tox/
.coverage
.coverage.*
htmlcov/
.nox/

# 環境変数・機密情報
.env
.env.local
.env.*.local
*.pem
*.key
credentials.json
service-account-key.json

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# ドキュメント
*.md
docs/
LICENSE
```

**Node.js プロジェクト向け:**

```
# 依存関係
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*
package-lock.json
yarn.lock

# ビルド成果物
dist/
build/
.next/
out/
.nuxt

# テスト
coverage/
.nyc_output

# 環境変数・機密情報
.env
.env.local
.env.*.local
*.pem
*.key
.npmrc

# IDE
.vscode/
.idea/
*.swp
.DS_Store

# バージョン管理
.git/
.gitignore

# その他
*.log
tmp/
temp/
```

**Go プロジェクト向け:**

```
# バイナリ
*.exe
*.exe~
*.dll
*.so
*.dylib
/bin/
/dist/

# テスト
*.test
*.out

# 依存関係（go.mod/go.sumは含める）
vendor/

# IDE
.vscode/
.idea/
*.swp

# 環境変数・機密情報
.env
*.pem
*.key

# バージョン管理
.git/
.gitignore

# その他
*.log
tmp/
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

### 非rootユーザー作成の詳細コマンド

**Alpine Linux ベースイメージの場合:**

```dockerfile
# Alpine では adduser/addgroup コマンドの構文が異なる
RUN addgroup -S appgroup && adduser -S -G appgroup appuser
```

**Debian/Ubuntu ベースイメージの場合:**

```dockerfile
# --system オプションでシステムユーザーとして作成（UID < 1000）
RUN groupadd --system --gid 1001 appgroup && \
    useradd --system --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser
```

**UID/GIDを明示的に指定（推奨）:**

固定のUID/GIDを使用することで、ボリュームマウント時のパーミッション問題を回避できる。

```dockerfile
FROM python:3.9-slim

# UID 1001, GID 1001 で作成
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

WORKDIR /app

# ディレクトリ作成と所有権設定
RUN mkdir -p /app /tmp/app-cache && \
    chown -R appuser:appgroup /app /tmp/app-cache

USER appuser

# 以降の COPY は appuser として実行される
COPY --chown=appuser:appgroup requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

COPY --chown=appuser:appgroup . .

ENV PATH="/home/appuser/.local/bin:${PATH}"
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

**読み取り専用ファイルシステム設定の詳細:**

Cloud Run Gen2（第2世代実行環境）では、コンテナファイルシステムをデフォルトで読み取り専用にできる。

**デプロイ時の設定:**

```bash
gcloud run deploy my-app \
  --image asia-northeast1-docker.pkg.dev/my-project/repo/my-app:latest \
  --execution-environment gen2 \
  --no-cpu-throttling \
  --region asia-northeast1
```

**アプリケーションコードでの `/tmp` 使用例（Python）:**

```python
import os
import tempfile

# 一時ファイルは /tmp に作成
TEMP_DIR = os.getenv('TEMP_DIR', '/tmp')

def save_uploaded_file(file_content, filename):
    temp_path = os.path.join(TEMP_DIR, filename)
    with open(temp_path, 'wb') as f:
        f.write(file_content)
    return temp_path

# tempfile モジュールも /tmp を使用
with tempfile.NamedTemporaryFile(mode='w', delete=False) as tmp:
    tmp.write('temporary data')
    tmp_path = tmp.name
```

**Node.js での例:**

```javascript
const os = require('os');
const path = require('path');
const fs = require('fs');

// 一時ディレクトリのパス
const TEMP_DIR = process.env.TEMP_DIR || os.tmpdir();

function saveUploadedFile(buffer, filename) {
  const tempPath = path.join(TEMP_DIR, filename);
  fs.writeFileSync(tempPath, buffer);
  return tempPath;
}
```

**注意事項:**
- `/tmp` のサイズはメモリ制限に依存（例: メモリ512MiBなら `/tmp` も最大512MiB）
- コンテナ再起動時に `/tmp` の内容は失われる
- 永続化が必要なデータは Cloud Storage 等を使用

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

## 言語別完全 Dockerfile テンプレート

### Python Flask アプリケーション（本番用）

**Dockerfile（マルチステージビルド + 非rootユーザー）:**

```dockerfile
# ビルドステージ
FROM python:3.9-slim AS builder

WORKDIR /build

# 依存関係定義のみコピー（キャッシュ最適化）
COPY requirements.txt .

# pip 依存関係をビルド
RUN pip install --user --no-cache-dir -r requirements.txt

# 本番ステージ
FROM python:3.9-slim

# 非rootユーザー作成（UID/GID固定）
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --create-home appuser

WORKDIR /app

# ビルドステージから依存関係をコピー
COPY --from=builder --chown=appuser:appgroup /root/.local /home/appuser/.local

# アプリケーションコードをコピー
COPY --chown=appuser:appgroup . .

# 一時ディレクトリ作成
RUN mkdir -p /tmp/app-cache && chown appuser:appgroup /tmp/app-cache

USER appuser

# PATH に user site-packages を追加
ENV PATH="/home/appuser/.local/bin:${PATH}"
ENV PORT=8080
ENV PYTHONUNBUFFERED=1

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

**requirements.txt:**

```
Flask==2.3.0
gunicorn==21.2.0
```

**Gunicorn 使用時（推奨）:**

```dockerfile
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "4", "--timeout", "300", "app:app"]
```

### Node.js Express アプリケーション（本番用）

**Dockerfile（マルチステージビルド + 本番依存のみ）:**

```dockerfile
# ビルドステージ
FROM node:18-alpine AS builder

WORKDIR /app

# package.json のみコピー（キャッシュ最適化）
COPY package*.json ./

# 全依存関係をインストール（devDependencies含む）
RUN npm ci

# ソースコードをコピー
COPY . .

# TypeScript ビルド（該当する場合）
RUN npm run build

# 本番依存のみインストール
RUN npm ci --production

# 本番ステージ
FROM node:18-alpine

# 非rootユーザー（Alpine では node ユーザーが既存）
USER node

WORKDIR /app

# ビルド成果物と本番依存をコピー
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/package*.json ./

ENV NODE_ENV=production
ENV PORT=8080

EXPOSE 8080

CMD ["node", "dist/server.js"]
```

**server.js（または dist/server.js）:**

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
app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
});
```

**package.json:**

```json
{
  "name": "my-app",
  "version": "1.0.0",
  "scripts": {
    "build": "tsc",
    "start": "node dist/server.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/express": "^4.17.0",
    "@types/node": "^18.0.0"
  }
}
```

### Go アプリケーション（本番用 distroless）

**Dockerfile（マルチステージビルド + distroless）:**

```dockerfile
# ビルドステージ
FROM golang:1.21-alpine AS builder

WORKDIR /src

# go.mod/go.sum のみコピー（依存関係キャッシュ最適化）
COPY go.mod go.sum ./
RUN go mod download

# ソースコードをコピー
COPY . .

# 静的リンクバイナリをビルド
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o /app/my-app .

# 本番ステージ（distroless - 最小イメージ）
FROM gcr.io/distroless/static-debian11:nonroot

# distroless の nonroot ユーザー（UID 65532）
USER nonroot:nonroot

WORKDIR /app

# ビルド成果物のみコピー
COPY --from=builder --chown=nonroot:nonroot /app/my-app .

EXPOSE 8080

ENTRYPOINT ["./my-app"]
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

**go.mod:**

```go
module my-app

go 1.21

require (
    // 依存関係をここに追加
)
```

## ベースイメージ選択ガイド（詳細比較）

### イメージタイプ別比較表

| 項目 | Alpine | Slim | Standard | Distroless |
|------|--------|------|----------|-----------|
| **サイズ** | 最小（5-50MB） | 小（100-200MB） | 大（300-1000MB） | 最小（10-50MB） |
| **パッケージマネージャー** | apk | apt/dpkg | apt/dpkg | なし |
| **シェル** | ✅ sh/bash | ✅ bash | ✅ bash | ❌ なし |
| **デバッグツール** | ❌ 最小限 | ⚠️ 一部 | ✅ 豊富 | ❌ なし |
| **セキュリティ** | ⚠️ musl libc | ✅ 良好 | ⚠️ 攻撃面大 | ✅ 最高 |
| **ビルド速度** | 🚀 高速 | ⚠️ 中 | ⚠️ 遅 | 🚀 高速 |
| **互換性** | ⚠️ 一部ライブラリ不可 | ✅ 高 | ✅ 最高 | ⚠️ 静的バイナリのみ |

### Python ベースイメージ選択

**開発環境:**
```dockerfile
FROM python:3.9  # 標準イメージ（デバッグツール豊富）
```

**本番環境（推奨）:**
```dockerfile
FROM python:3.9-slim  # Debian slim（バランス良好）
```

**超軽量化:**
```dockerfile
FROM python:3.9-alpine  # Alpine（最小サイズ、C拡張注意）
```

**注意事項:**
- Alpine は `musl libc` を使用するため、C 拡張モジュール（numpy, pandas等）でビルドエラーが発生する場合がある
- その場合は `python:3.9-slim` を推奨

### Node.js ベースイメージ選択

**開発環境:**
```dockerfile
FROM node:18  # 標準イメージ（全ツール含む）
```

**本番環境（推奨）:**
```dockerfile
FROM node:18-alpine  # Alpine（Node.jsはC拡張少なく相性良）
```

**LTS バージョン:**
```dockerfile
FROM node:lts-alpine  # LTS最新版を自動選択
```

### Go ベースイメージ選択

**ビルドステージ:**
```dockerfile
FROM golang:1.21-alpine  # ビルド専用（軽量で十分）
```

**本番ステージ（推奨）:**
```dockerfile
FROM gcr.io/distroless/static-debian11:nonroot  # 静的バイナリ用
```

**または:**
```dockerfile
FROM gcr.io/distroless/base-debian11:nonroot  # 動的リンク用（CGO使用時）
```

**最軽量（scratch）:**
```dockerfile
FROM scratch  # 空イメージ（静的リンクバイナリのみ）
COPY --from=builder /app/my-app /
CMD ["/my-app"]
```

---

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
