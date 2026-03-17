# Docker開発ワークフロー

Docker開発環境のセットアップからCI/CD統合まで、実践的な開発ワークフローを網羅。

---

## プロジェクト構造

### 標準的なDocker開発プロジェクト

```
my-project/
├── src/                 # アプリケーションソースコード
├── tests/               # テストファイル
├── Dockerfile           # コンテナイメージ定義
├── docker-compose.yml   # マルチコンテナ定義
├── .dockerignore        # ビルドコンテキスト除外ファイル
└── README.md            # プロジェクトドキュメント
```

### 各ファイルの役割

- **Dockerfile**: イメージビルド手順（ベースイメージ、環境設定、コード配置、起動コマンド）
- **docker-compose.yml**: 複数サービス定義（Webアプリ + DB + Cacheなど）
- **.dockerignore**: `.gitignore`と同様、ビルドコンテキストから除外するファイル・ディレクトリを指定

---

## Dockerfile for Development

### 基本的な開発用Dockerfile

Python Webアプリケーションの例:

```dockerfile
# ベースイメージ（公式Python slim版）
FROM python:3.9-slim

# コンテナ内作業ディレクトリ
WORKDIR /app

# 依存関係ファイルをコピー
COPY requirements.txt .

# 依存関係をインストール
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードをコピー
COPY src/ .

# アプリケーション起動コマンド
CMD ["python", "app.py"]
```

**ポイント**:
1. Slimイメージで軽量化
2. 依存関係を先にコピー（レイヤーキャッシュ活用）
3. コードは最後にコピー（変更頻度が高い）

---

## Docker Compose for Development

### マルチサービス開発環境

WebアプリケーションとPostgreSQLデータベースの例:

```yaml
version: '3'

services:
  web:
    build: .
    ports:
      - "5000:5000"
    volumes:
      - ./src:/app                    # ホットリロード用ボリュームマウント
    environment:
      - FLASK_ENV=development
    depends_on:
      - db

  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=myuser
      - POSTGRES_PASSWORD=mypassword
    volumes:
      - postgres_data:/var/lib/postgresql/data  # データ永続化

volumes:
  postgres_data:
```

### 起動コマンド

```bash
# 全サービス起動
docker-compose up

# バックグラウンド起動
docker-compose up -d

# 特定サービスのみ起動
docker-compose up web

# 停止と削除
docker-compose down
```

---

## ホットリロード（ライブリロード）

### ボリュームマウントによるコード同期

`docker-compose.yml`で`volumes`を使用すると、ホストマシンのコード変更がコンテナに即座に反映される:

```yaml
services:
  web:
    volumes:
      - ./src:/app    # ホスト:コンテナのマッピング
```

### 言語別設定

#### Python (Flask)

```python
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')
```

- `debug=True`: ファイル変更検知でサーバー自動再起動
- `host='0.0.0.0'`: コンテナ外からアクセス可能

#### Node.js (Express)

```json
{
  "scripts": {
    "dev": "nodemon --watch src server.js"
  }
}
```

`Dockerfile`:
```dockerfile
CMD ["npm", "run", "dev"]
```

#### Go (Air)

`.air.toml`設定ファイル:
```toml
[build]
  cmd = "go build -o ./tmp/main ."
  bin = "tmp/main"
  include_ext = ["go"]
  exclude_dir = ["tmp"]
```

`Dockerfile`:
```dockerfile
RUN go install github.com/cosmtrek/air@latest
CMD ["air", "-c", ".air.toml"]
```

---

## Docker内テスト実行

### テスト用サービス定義

`docker-compose.yml`にテストサービスを追加:

```yaml
services:
  # ... 他のサービス ...

  test:
    build: .
    volumes:
      - ./src:/app
      - ./tests:/app/tests
    command: python -m unittest discover tests
```

### テスト実行コマンド

```bash
# テストサービス実行（完了後コンテナ削除）
docker-compose run --rm test

# 特定のテストファイル実行
docker-compose run --rm test python -m unittest tests.test_auth

# カバレッジ付き
docker-compose run --rm test pytest --cov=src tests/
```

---

## Docker内デバッグ

### 基本的なデバッグコマンド

```bash
# コンテナログ確認
docker logs <container_id>

# 実行中コンテナに対話シェルで接続
docker exec -it <container_id> /bin/bash

# コンテナ状態確認
docker ps
docker inspect <container_id>
```

### リモートデバッグ（VS Code + Python）

#### 1. Dockerfile修正

```dockerfile
# ... 既存のDockerfile ...

# デバッガーインストール
RUN pip install debugpy

# デバッグモードで起動
CMD ["python", "-m", "debugpy", "--listen", "0.0.0.0:5678", "--wait-for-client", "app.py"]
```

#### 2. docker-compose.yml修正

```yaml
services:
  web:
    ports:
      - "5000:5000"
      - "5678:5678"    # デバッグポート公開
```

#### 3. VS Code設定（.vscode/launch.json）

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: Remote Attach",
      "type": "python",
      "request": "attach",
      "port": 5678,
      "host": "localhost",
      "pathMappings": [
        {
          "localRoot": "${workspaceFolder}/src",
          "remoteRoot": "/app"
        }
      ]
    }
  ]
}
```

#### 4. デバッグ手順

1. `docker-compose up`でコンテナ起動（デバッガー待機状態）
2. VS Codeで「Python: Remote Attach」デバッグ設定を実行
3. ブレークポイント設定してアプリにアクセス

### リモートデバッグ（Go + Delve）

`Dockerfile`:
```dockerfile
FROM golang:1.21
WORKDIR /app
COPY . .
RUN go install github.com/go-delve/delve/cmd/dlv@latest
CMD ["dlv", "debug", "--headless", "--listen=:2345", "--api-version=2", "--accept-multiclient"]
```

VS Code `launch.json`:
```json
{
  "name": "Go: Remote Debug",
  "type": "go",
  "request": "attach",
  "mode": "remote",
  "remotePath": "/app",
  "port": 2345,
  "host": "localhost"
}
```

### デバッグフレンドリーなベースイメージ

開発時は slim 版ではなくフル版を使用:

```dockerfile
# 開発用: デバッグツール含む
FROM python:3.9

# 本番用: 軽量版
FROM python:3.9-slim
```

---

## CI/CD統合

### GitHub Actions with Docker

`.github/workflows/ci.yml`:

```yaml
name: CI

on: [push]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Build Docker image
        run: docker build -t myapp .

      - name: Run tests
        run: docker run myapp python -m unittest discover tests

      - name: Push to Docker Hub
        if: success()
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker tag myapp ${{ secrets.DOCKER_USERNAME }}/myapp:${{ github.sha }}
          docker push ${{ secrets.DOCKER_USERNAME }}/myapp:${{ github.sha }}
```

**フロー**:
1. コードチェックアウト
2. Dockerイメージビルド
3. テスト実行
4. 成功時のみDocker Hubにプッシュ

### イメージタグ戦略

```bash
# Git commit SHA（推奨: 一意性保証）
docker tag myapp:latest myapp:${GIT_SHA}

# セマンティックバージョニング
docker tag myapp:latest myapp:v1.2.3

# ブランチ名
docker tag myapp:latest myapp:${BRANCH_NAME}

# 環境別
docker tag myapp:latest myapp:staging
docker tag myapp:latest myapp:production
```

**❌ 避けるべき**:
- `latest`タグのみでの運用（バージョン追跡不可）

---

## 開発ベストプラクティス

### 1. マルチステージビルド（dev/prod分離）

```dockerfile
# 開発ステージ
FROM python:3.9 AS development
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]

# 本番ステージ
FROM python:3.9-slim AS production
WORKDIR /app
COPY --from=development /app /app
COPY --from=development /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
CMD ["gunicorn", "app:app"]
```

**ビルド方法**:
```bash
# 開発用イメージ
docker build --target development -t myapp:dev .

# 本番用イメージ
docker build --target production -t myapp:prod .
```

### 2. ヘルスチェック

```dockerfile
FROM python:3.9-slim

# ... 他の命令 ...

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5000/ || exit 1

CMD ["python", "app.py"]
```

**パラメータ説明**:
- `--interval`: チェック間隔
- `--timeout`: チェックタイムアウト
- `--start-period`: 起動猶予時間
- `--retries`: 失敗回数閾値

### 3. 環境変数管理

`.env`ファイル:
```env
DATABASE_URL=postgresql://user:pass@db:5432/myapp
SECRET_KEY=your-secret-key
DEBUG=true
```

`docker-compose.yml`:
```yaml
services:
  web:
    env_file:
      - .env
    # または
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - SECRET_KEY=${SECRET_KEY}
```

**セキュリティ注意**:
- `.env`を`.gitignore`に追加
- 本番環境ではシークレット管理サービス使用（AWS Secrets Manager等）

### 4. .dockerignore活用

```.dockerignore
# Git
.git/
.gitignore

# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
venv/
env/

# Node
node_modules/
npm-debug.log

# IDE
.vscode/
.idea/

# ドキュメント
*.md
docs/

# テスト・CI
.github/
tests/
*.test.js

# 機密情報
.env
.env.local
*.key
*.pem
```

### 5. レイヤーキャッシュ最適化

**❌ 非効率**:
```dockerfile
COPY . .
RUN pip install -r requirements.txt
```

**✅ 効率的**:
```dockerfile
# 依存関係を先にコピー（変更頻度低）
COPY requirements.txt .
RUN pip install -r requirements.txt

# コードは後でコピー（変更頻度高）
COPY src/ .
```

### 6. 非rootユーザー実行

```dockerfile
FROM python:3.9-slim

# アプリユーザー作成
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app
COPY --chown=appuser:appuser . .

# 非rootユーザーに切り替え
USER appuser

CMD ["python", "app.py"]
```

### 7. 依存関係とコードの分離

**Node.js例**:
```dockerfile
# 依存関係レイヤー
COPY package*.json ./
RUN npm ci --only=production

# コードレイヤー
COPY . .
```

**Go例**:
```dockerfile
# 依存関係レイヤー
COPY go.mod go.sum ./
RUN go mod download

# コードレイヤー
COPY . .
RUN go build -o app .
```

### 8. ボリューム戦略

**開発時（ホットリロード）**:
```yaml
volumes:
  - ./src:/app    # ホストマシンと同期
```

**本番時（データ永続化）**:
```yaml
volumes:
  - app_data:/var/lib/postgresql/data    # 名前付きボリューム
```

---

## 開発時のトラブルシューティング

### よくある問題と解決策

#### 問題1: ボリュームマウント後にnode_modules消失

**原因**: ホストの空ディレクトリがコンテナの`node_modules`を上書き

**解決策**: 匿名ボリュームで保護
```yaml
volumes:
  - ./src:/app
  - /app/node_modules    # node_modulesはマウントしない
```

#### 問題2: ファイル変更が反映されない

**確認項目**:
1. ボリュームマウントが正しく設定されているか
2. アプリケーションがファイル変更を監視しているか
3. Docker Desktop設定でファイル共有が有効か

#### 問題3: ポート競合

```bash
# ポート使用確認
lsof -i :5000

# docker-compose.ymlでポート変更
ports:
  - "5001:5000"    # ホストポート5001にマッピング
```

#### 問題4: イメージビルド時のキャッシュ問題

```bash
# キャッシュ無視してビルド
docker build --no-cache -t myapp .

# Composeで再ビルド
docker-compose build --no-cache
docker-compose up --build
```

---

## パフォーマンス最適化

### ビルド時間短縮

1. **BuildKitの使用**:
```bash
DOCKER_BUILDKIT=1 docker build -t myapp .
```

2. **並列ビルド**:
```dockerfile
# BuildKit構文
# syntax=docker/dockerfile:1
FROM python:3.9-slim
```

3. **依存関係の事前ダウンロード**:
```dockerfile
# pip パッケージをキャッシュ
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

### 起動時間短縮

1. **軽量ベースイメージ**:
```dockerfile
# alpine版（最小）
FROM python:3.9-alpine

# slim版（バランス）
FROM python:3.9-slim
```

2. **不要なパッケージ除外**:
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*
```

---

## 複数環境の管理

### docker-compose.override.yml

`docker-compose.yml`（ベース）:
```yaml
services:
  web:
    build: .
    ports:
      - "5000:5000"
```

`docker-compose.override.yml`（開発用、自動読込）:
```yaml
services:
  web:
    volumes:
      - ./src:/app
    environment:
      - DEBUG=true
```

`docker-compose.prod.yml`（本番用）:
```yaml
services:
  web:
    image: myapp:prod
    environment:
      - DEBUG=false
```

**使用方法**:
```bash
# 開発（overrideが自動適用）
docker-compose up

# 本番
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

---

## まとめ: 開発ワークフローチェックリスト

### プロジェクト初期化
- [ ] Dockerfileを作成（開発用設定）
- [ ] docker-compose.ymlを作成（必要なサービス定義）
- [ ] .dockerignoreを作成（不要ファイル除外）
- [ ] ボリュームマウント設定（ホットリロード）

### 開発中
- [ ] ホットリロードが機能しているか確認
- [ ] テスト環境をDockerで構築
- [ ] デバッグ設定（リモートデバッグ）
- [ ] ヘルスチェック実装

### CI/CD準備
- [ ] マルチステージビルド実装（dev/prod分離）
- [ ] GitHub Actions等でビルド・テスト自動化
- [ ] イメージのバージョニング戦略決定
- [ ] Docker Hubまたはレジストリへのプッシュ設定

### セキュリティ
- [ ] 非rootユーザーで実行
- [ ] 機密情報を環境変数化
- [ ] .envを.gitignoreに追加
- [ ] ベースイメージの脆弱性スキャン
