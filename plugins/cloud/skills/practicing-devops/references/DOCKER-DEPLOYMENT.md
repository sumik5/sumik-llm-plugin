# デプロイメントリファレンス

Dockerアプリケーションのデプロイ戦略、CI/CDパイプライン、プライベートレジストリ管理、本番環境設定の実践ガイド。

---

## CI/CDパイプライン統合

### GitHub Actions ワークフロー

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Build Docker image
        run: docker build -t myregistry.com/myapp:${{ github.sha }} .

      - name: Run tests
        run: docker run myregistry.com/myapp:${{ github.sha }} npm test

      - name: Push to Docker Registry
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker push myregistry.com/myapp:${{ github.sha }}

      - name: Deploy to Kubernetes
        run: |
          kubectl set image deployment/myapp myapp=myregistry.com/myapp:${{ github.sha }}
```

**ポイント:**
- Git SHAをタグとして使用（トレーサビリティ確保）
- テスト自動実行
- 認証情報はGitHub Secretsで管理
- デプロイメントイメージ更新を自動化

### GitLab CI/CD パイプライン

```yaml
stages:
  - build
  - test
  - deploy

variables:
  DOCKER_REGISTRY: registry.gitlab.com
  IMAGE_NAME: $CI_PROJECT_PATH
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA

build:
  stage: build
  script:
    - docker build -t $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG .
    - docker push $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG

test:
  stage: test
  script:
    - docker run $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG npm test

deploy:
  stage: deploy
  script:
    - kubectl set image deployment/myapp myapp=$DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG
  only:
    - main
```

### Jenkins パイプライン統合

```groovy
pipeline {
  agent any

  environment {
    DOCKER_REGISTRY = 'your-registry-url:5000'
    IMAGE_NAME = 'your-app'
    IMAGE_TAG = "${env.BUILD_NUMBER}"
  }

  stages {
    stage('Build') {
      steps {
        sh "docker build -t ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} ."
      }
    }

    stage('Test') {
      steps {
        sh "docker run ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} npm test"
      }
    }

    stage('Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'registry-credentials', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
          sh "echo \$PASSWORD | docker login ${DOCKER_REGISTRY} -u \$USERNAME --password-stdin"
          sh "docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
        }
      }
    }

    stage('Deploy') {
      steps {
        sh "kubectl set image deployment/myapp myapp=${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
      }
    }
  }
}
```

### マルチプラットフォームビルド（buildx）

```bash
# Buildx セットアップ
docker buildx create --name multiplatform --use
docker buildx inspect --bootstrap

# マルチプラットフォームビルド＆プッシュ
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag myregistry.com/myapp:latest \
  --push \
  .
```

**GitHub Actions でのマルチプラットフォームビルド:**

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v2

- name: Build and push multi-platform image
  uses: docker/build-push-action@v4
  with:
    context: .
    platforms: linux/amd64,linux/arm64
    push: true
    tags: myregistry.com/myapp:${{ github.sha }}
```

---

## デプロイ戦略

### Blue-Green デプロイ

**概念:** 本番環境（Blue）と新バージョン環境（Green）を並行運用し、切り替え時にトラフィックを瞬時に移行。ロールバックも即座に可能。

**docker-compose 構成:**

```yaml
version: '3.8'

services:
  nginx:
    image: nginx:latest
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app-blue
      - app-green

  app-blue:
    image: myregistry.com/myapp:v1.0
    environment:
      - NODE_ENV=production
    deploy:
      replicas: 3

  app-green:
    image: myregistry.com/myapp:v1.1
    environment:
      - NODE_ENV=production
    deploy:
      replicas: 3
```

**Nginx リバースプロキシ設定（トラフィック切り替え）:**

```nginx
upstream backend {
    # Blue環境をアクティブ化（Greenに切り替える場合はコメントを逆転）
    server app-blue:3000;
    # server app-green:3000;
}

server {
    listen 80;

    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /health {
        access_log off;
        return 200 "healthy\n";
    }
}
```

**切り替え手順:**

```bash
# 1. Green環境をデプロイ
docker compose up -d app-green

# 2. Green環境のヘルスチェック
curl http://app-green:3000/health

# 3. Nginxの設定を切り替え（upstream backend の server 行を変更）
# 4. Nginx設定リロード
docker compose exec nginx nginx -s reload

# 5. 問題があればBlueに即座にロールバック
# （upstream backend をapp-blueに戻してreload）
```

### Canary デプロイ（段階的ロールアウト）

**概念:** 新バージョンを一部のユーザー（5%→10%→50%→100%）に段階的に公開。問題発生時は影響範囲を最小化。

**Nginx 設定（トラフィック比率制御）:**

```nginx
upstream backend {
    # 旧バージョン: 90%
    server app-v1:3000 weight=9;

    # 新バージョン: 10%（Canary）
    server app-v2:3000 weight=1;
}

server {
    listen 80;

    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
    }
}
```

**段階的なCanaryロールアウト:**

```bash
# フェーズ1: 5%トラフィック
# weight=19 (v1) と weight=1 (v2) に設定

# フェーズ2: 10%トラフィック
# weight=9 (v1) と weight=1 (v2) に設定

# フェーズ3: 50%トラフィック
# weight=1 (v1) と weight=1 (v2) に設定

# フェーズ4: 100%トラフィック
# v2のみに切り替え
```

### ローリングアップデート

**Kubernetes デプロイメント:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # 同時に追加できるPod数
      maxUnavailable: 1  # 同時に停止できるPod数
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myregistry.com/myapp:v2
        ports:
        - containerPort: 3000
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
```

**デプロイとロールバック:**

```bash
# ローリングアップデート実行
kubectl set image deployment/myapp myapp=myregistry.com/myapp:v2

# ロールアウト状況確認
kubectl rollout status deployment/myapp

# ロールバック（問題発生時）
kubectl rollout undo deployment/myapp

# 特定リビジョンへロールバック
kubectl rollout undo deployment/myapp --to-revision=3
```

---

## プライベートレジストリ管理

### Docker Registry（セルフホスト）セットアップ

**基本的な起動:**

```bash
docker run -d -p 5000:5000 --name registry registry:2
```

**TLS セキュリティ設定:**

```bash
# 自己署名証明書生成（テスト用）
mkdir certs
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/domain.key \
  -x509 -days 365 \
  -out certs/domain.crt

# TLS有効化したレジストリ起動
docker run -d \
  --restart=always \
  --name registry \
  -v "$(pwd)"/certs:/certs \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  -p 443:443 \
  registry:2
```

**Basic認証の実装:**

```bash
# 認証用パスワードファイル作成
mkdir auth
docker run --entrypoint htpasswd httpd:2 -Bbn testuser testpassword > auth/htpasswd

# 認証付きレジストリ起動
docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name registry \
  -v "$(pwd)"/auth:/auth \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
  registry:2

# 認証テスト
docker login localhost:5000 -u testuser -p testpassword
```

### Harbor（エンタープライズレジストリ）導入

**特徴:**
- UI管理画面
- イメージ脆弱性スキャン
- レプリケーション機能
- ロールベースアクセス制御（RBAC）
- Helm Chart管理

**docker-compose.yml（簡易版）:**

```yaml
version: '3.8'

services:
  harbor-core:
    image: goharbor/harbor-core:v2.8.0
    environment:
      - HARBOR_ADMIN_PASSWORD=Harbor12345
    volumes:
      - harbor-data:/data
    ports:
      - "80:8080"

volumes:
  harbor-data:
```

### レジストリミラーリング

**設定（config.yml）:**

```yaml
version: 0.1

log:
  fields:
    service: registry

storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry

http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]

proxy:
  remoteurl: https://registry-1.docker.io
```

**ミラーレジストリ起動:**

```bash
docker run -d -p 5000:5000 --name registry \
  -v $(pwd)/config.yml:/etc/docker/registry/config.yml \
  registry:2
```

### ガベージコレクション

**不要なレイヤー削除:**

```bash
# レジストリ停止
docker stop registry

# ガベージコレクション実行
docker run -it --name gc \
  -v /path/to/registry/data:/var/lib/registry \
  registry:2 garbage-collect /etc/docker/registry/config.yml

# レジストリ再起動
docker start registry
```

---

## 本番デプロイ設定

### 本番用 docker-compose.yml

```yaml
version: '3.8'

services:
  web:
    image: myregistry.com/myapp:latest
    restart: always
    ports:
      - "8080:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
    secrets:
      - db_password
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 40s

  db:
    image: postgres:15
    restart: always
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - db_password

volumes:
  postgres_data:

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

**重要な設定項目:**
- `restart: always`: 自動再起動
- `resources.limits`: リソース制限
- `logging`: ログローテーション設定
- `healthcheck`: ヘルスチェック定義
- `secrets`: 機密情報管理

### 環境別設定管理

**ベース設定（docker-compose.yml）:**

```yaml
version: '3.8'

services:
  app:
    image: myregistry.com/myapp:${TAG:-latest}
    environment:
      - NODE_ENV=${NODE_ENV:-production}
```

**本番環境オーバーライド（docker-compose.prod.yml）:**

```yaml
version: '3.8'

services:
  app:
    deploy:
      replicas: 5
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://log-server:514"
```

**開発環境オーバーライド（docker-compose.dev.yml）:**

```yaml
version: '3.8'

services:
  app:
    volumes:
      - ./src:/app/src
    environment:
      - NODE_ENV=development
      - DEBUG=*
```

**起動コマンド:**

```bash
# 本番環境
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 開発環境
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

### Secrets管理

**Docker Swarm Secrets:**

```bash
# Secret作成
echo "mySecretPassword" | docker secret create db_password -

# Secretを使用するサービス定義
docker service create \
  --name myapp \
  --secret db_password \
  myregistry.com/myapp:latest
```

**環境変数ファイル（.env）:**

```bash
# .env（gitignore必須）
DATABASE_URL=postgresql://user:pass@db:5432/mydb
API_KEY=your-secret-api-key
```

```yaml
# docker-compose.yml
services:
  app:
    env_file:
      - .env
```

---

## イメージタグ戦略

### Semantic Versioning

```bash
# メジャー.マイナー.パッチ
docker tag myapp:latest myregistry.com/myapp:1.2.3
docker tag myapp:latest myregistry.com/myapp:1.2
docker tag myapp:latest myregistry.com/myapp:1
docker tag myapp:latest myregistry.com/myapp:latest

# すべてプッシュ
docker push myregistry.com/myapp:1.2.3
docker push myregistry.com/myapp:1.2
docker push myregistry.com/myapp:1
docker push myregistry.com/myapp:latest
```

### Git SHA タグ

```bash
# コミットSHAをタグに使用
GIT_SHA=$(git rev-parse --short HEAD)
docker tag myapp:latest myregistry.com/myapp:${GIT_SHA}
docker push myregistry.com/myapp:${GIT_SHA}
```

**メリット:**
- 完全なトレーサビリティ
- 正確なロールバック
- コードとイメージの1対1対応

### 環境タグ

```bash
# 環境ごとの明示的タグ
docker tag myapp:latest myregistry.com/myapp:dev-20240101
docker tag myapp:latest myregistry.com/myapp:staging-v1.2.3
docker tag myapp:latest myregistry.com/myapp:prod-v1.2.3
```

---

## スケーリング

### Docker Compose スケール

```bash
# webサービスを5インスタンスにスケール
docker compose up --scale web=5 -d

# 確認
docker compose ps
```

**注意:** ポートバインディング競合を避けるため、外部公開ポートを使用しない構成が必要（ロードバランサー経由）。

### ロードバランサー連携

**Nginx + Docker Compose:**

```yaml
version: '3.8'

services:
  nginx:
    image: nginx:latest
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app

  app:
    image: myregistry.com/myapp:latest
    deploy:
      replicas: 5
```

**nginx.conf:**

```nginx
upstream backend {
    server app:3000;
}

server {
    listen 80;

    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## ロールバック手順

### Kubernetes ロールバック

```bash
# ロールアウト履歴確認
kubectl rollout history deployment/myapp

# 直前のバージョンにロールバック
kubectl rollout undo deployment/myapp

# 特定リビジョンにロールバック
kubectl rollout undo deployment/myapp --to-revision=2

# ロールバック状況監視
kubectl rollout status deployment/myapp
```

### Docker Compose ロールバック

```bash
# 旧イメージタグに変更
docker compose -f docker-compose.yml pull
docker compose -f docker-compose.yml up -d --no-deps app

# または環境変数で指定
TAG=v1.2.2 docker compose up -d
```

### イメージタグによるロールバック

```bash
# 現在の本番イメージ
docker service update --image myregistry.com/myapp:v1.2.3 myapp

# ロールバック（前のバージョンに戻す）
docker service update --image myregistry.com/myapp:v1.2.2 myapp

# または特定のgit SHAに戻す
docker service update --image myregistry.com/myapp:a3b2c1d myapp
```

---

## 高可用性レジストリ構成

### ロードバランサー + 共有ストレージ

**docker-compose.yml:**

```yaml
version: '3.8'

services:
  registry1:
    image: registry:2
    ports:
      - 5000
    volumes:
      - registry-data:/var/lib/registry
    environment:
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
      REGISTRY_HTTP_TLS_KEY: /certs/domain.key

  registry2:
    image: registry:2
    ports:
      - 5000
    volumes:
      - registry-data:/var/lib/registry
    environment:
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
      REGISTRY_HTTP_TLS_KEY: /certs/domain.key

  nginx:
    image: nginx:latest
    ports:
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - registry1
      - registry2

volumes:
  registry-data:
    driver: local
```

**nginx.conf（レジストリロードバランシング）:**

```nginx
upstream registry_backend {
    least_conn;
    server registry1:5000;
    server registry2:5000;
}

server {
    listen 443 ssl;
    server_name registry.example.com;

    ssl_certificate /etc/nginx/certs/domain.crt;
    ssl_certificate_key /etc/nginx/certs/domain.key;

    location / {
        proxy_pass http://registry_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 大きなイメージアップロード対応
        client_max_body_size 0;
    }
}
```

---

## ベストプラクティス

### デプロイフロー

1. **イメージビルド**: マルチステージビルドで最適化
2. **自動テスト**: ビルド後に必ずテスト実行
3. **イメージスキャン**: 脆弱性スキャン（Trivy, Clair等）
4. **ステージング**: 本番前に必ずステージング環境でテスト
5. **段階的ロールアウト**: Canaryデプロイで影響を最小化
6. **モニタリング**: デプロイ後の監視（メトリクス・ログ）
7. **ロールバック準備**: 即座にロールバック可能な状態を維持

### セキュリティ

- **イメージ署名**: Docker Content Trustを有効化
- **最小権限**: コンテナは非rootユーザーで実行
- **Secrets管理**: 環境変数ではなくSecretsを使用
- **ネットワークセグメンテーション**: 不要な通信を制限
- **定期的な更新**: ベースイメージと依存パッケージを最新化

### パフォーマンス

- **レイヤーキャッシュ**: 変更の少ない層を先に配置
- **イメージサイズ削減**: alpine等の軽量ベースイメージ使用
- **ヘルスチェック**: 適切なタイムアウトとリトライ設定
- **リソース制限**: メモリ・CPU制限で安定性向上

### 運用

- **ログ管理**: 集中ログシステム（ELK, Loki等）への転送
- **バックアップ**: レジストリデータとボリュームの定期バックアップ
- **ドキュメント**: デプロイ手順とロールバック手順を文書化
- **自動化**: 手動操作を最小限に抑える
