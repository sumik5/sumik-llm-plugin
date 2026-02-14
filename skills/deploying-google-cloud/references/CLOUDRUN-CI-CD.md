# CI/CD パイプライン（自動デプロイ基盤）

Cloud Runへの継続的インテグレーション・継続的デリバリー（CI/CD）パイプラインを構築することで、コード変更から本番デプロイまでを自動化できる。本リファレンスではCloud Build、GitHub Actions、Jenkinsを用いたパイプライン設計とベストプラクティスを解説する。

## CI/CDの基本概念

### CI/CD とは

| 用語 | 説明 | Cloud Runでの実装 |
|-----|------|------------------|
| **CI (Continuous Integration)** | コード変更を頻繁にマージし、自動ビルド・テストを実行 | Cloud Buildでイメージビルド・テスト |
| **CD (Continuous Delivery)** | 承認後に本番デプロイ可能な状態を維持 | トラフィック分割でカナリーデプロイ |
| **CD (Continuous Deployment)** | テスト通過後、自動で本番デプロイ | Cloud Buildトリガーで自動デプロイ |

### Cloud Run CI/CD の流れ

```
コード変更 → プッシュ
    ↓
CI/CDツール起動（Cloud Build / GitHub Actions / Jenkins）
    ↓
コンテナイメージビルド
    ↓
自動テスト実行
    ↓
脆弱性スキャン
    ↓
イメージをレジストリにプッシュ
    ↓
Cloud Runにデプロイ
    ↓
トラフィック分割（カナリー）
    ↓
監視・ロールバック判断
```

## Cloud Build 設定

Cloud BuildはGoogleが提供するCI/CDサービスで、Cloud Runとの統合が最もシームレス。

### cloudbuild.yaml の基本構造

**最小構成:**

```yaml
steps:
  # イメージビルド
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']

  # イメージプッシュ
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']

  # Cloud Runデプロイ
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'run'
      - 'deploy'
      - 'my-app'
      - '--image'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
      - '--region'
      - 'us-central1'
      - '--platform'
      - 'managed'
      - '--allow-unauthenticated'

images:
  - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
```

### 環境変数・置換変数

Cloud Buildが提供する組み込み変数:

| 変数 | 説明 | 例 |
|-----|------|-----|
| `$PROJECT_ID` | GCPプロジェクトID | `my-project-123` |
| `$BUILD_ID` | ビルドの一意なID | `abc-123-def` |
| `$SHORT_SHA` | コミットSHAの短縮版（7文字） | `a1b2c3d` |
| `$COMMIT_SHA` | コミットSHAの完全版 | `a1b2c3d4e5f6...` |
| `$BRANCH_NAME` | ブランチ名 | `main` |
| `$TAG_NAME` | タグ名（タグプッシュ時） | `v1.0.0` |

**カスタム置換変数:**

```yaml
substitutions:
  _REGION: us-central1
  _SERVICE_NAME: my-app

steps:
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'run'
      - 'deploy'
      - '${_SERVICE_NAME}'
      - '--region'
      - '${_REGION}'
```

### テストステップの追加

**ユニットテスト:**

```yaml
steps:
  # イメージビルド
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']

  # テスト実行
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'run'
      - '--rm'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
      - 'npm'
      - 'test'

  # イメージプッシュ
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']

  # デプロイ
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'run'
      - 'deploy'
      - 'my-app'
      - '--image'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
      - '--region'
      - 'us-central1'
```

### 脆弱性スキャン統合（Trivy）

**基本的なTrivyスキャン:**

```yaml
steps:
  # イメージビルド
  - name: 'gcr.io/cloud-builders/docker'
    id: 'build'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']

  # 脆弱性スキャン（HIGH/CRITICAL のみ）
  - name: 'aquasec/trivy'
    id: 'security-scan'
    args:
      - 'image'
      - '--exit-code'
      - '1'  # HIGH/CRITICAL が見つかったら失敗
      - '--severity'
      - 'HIGH,CRITICAL'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
    waitFor: ['build']

  # スキャン通過後にイメージプッシュ
  - name: 'gcr.io/cloud-builders/docker'
    id: 'push'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']
    waitFor: ['security-scan']
```

**詳細なTrivyスキャン（レポート出力付き）:**

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    id: 'build'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']

  # JSON形式でレポート出力
  - name: 'aquasec/trivy'
    id: 'scan-report'
    args:
      - 'image'
      - '--format'
      - 'json'
      - '--output'
      - 'trivy-report.json'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
    waitFor: ['build']

  # Cloud Storageにレポートをアップロード
  - name: 'gcr.io/cloud-builders/gsutil'
    id: 'upload-report'
    args:
      - 'cp'
      - 'trivy-report.json'
      - 'gs://$PROJECT_ID-security-reports/trivy-$SHORT_SHA.json'
    waitFor: ['scan-report']

  # CRITICAL脆弱性がある場合は失敗
  - name: 'aquasec/trivy'
    id: 'scan-gate'
    args:
      - 'image'
      - '--exit-code'
      - '1'
      - '--severity'
      - 'CRITICAL'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
    waitFor: ['build']

  - name: 'gcr.io/cloud-builders/docker'
    id: 'push'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']
    waitFor: ['scan-gate', 'upload-report']
```

**Trivyスキャンオプション一覧:**

| オプション | 説明 | 推奨値 |
|----------|------|-------|
| `--exit-code` | 脆弱性検出時の終了コード | `1`（失敗扱い） |
| `--severity` | 対象とする深刻度 | `HIGH,CRITICAL` |
| `--format` | 出力形式 | `json`, `table`, `sarif` |
| `--ignore-unfixed` | 修正方法が存在しない脆弱性を無視 | `true`（推奨） |
| `--vuln-type` | 脆弱性タイプ | `os,library`（デフォルト） |
| `--timeout` | スキャンタイムアウト | `5m` |

**本番環境向けTrivyスキャン設定例:**

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']

  # 修正不可能な脆弱性は警告のみ、修正可能なCRITICALは失敗
  - name: 'aquasec/trivy'
    args:
      - 'image'
      - '--exit-code'
      - '1'
      - '--severity'
      - 'CRITICAL'
      - '--ignore-unfixed'
      - '--timeout'
      - '5m'
      - '--format'
      - 'table'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'

  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']
```

### Canaryデプロイ自動化（Cloud Build）

#### 基本的なCanary割り当て（20%）

```yaml
steps:
  # イメージビルド・プッシュ
  - name: 'gcr.io/cloud-builders/docker'
    id: 'build'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']

  - name: 'gcr.io/cloud-builders/docker'
    id: 'push'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']
    waitFor: ['build']

  # トラフィックなしでデプロイ
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'deploy-no-traffic'
    args:
      - 'run'
      - 'deploy'
      - 'my-app'
      - '--image'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
      - '--region'
      - 'us-central1'
      - '--platform'
      - 'managed'
      - '--no-traffic'
    waitFor: ['push']

  # 現在のリビジョンを取得
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'get-current-revision'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        gcloud run services describe my-app \
          --region us-central1 \
          --format="value(status.traffic[0].revisionName)" \
          > /workspace/current_revision.txt
    waitFor: ['deploy-no-traffic']

  # 新リビジョンのヘルスチェック
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'health-check'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        NEW_URL=$(gcloud run services describe my-app \
          --region us-central1 \
          --format="value(status.url)")

        # ヘルスエンドポイントを確認
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $NEW_URL/health)

        if [ $HTTP_CODE -ne 200 ]; then
          echo "Health check failed with HTTP code: $HTTP_CODE"
          exit 1
        fi
        echo "Health check passed"
    waitFor: ['deploy-no-traffic']

  # Canaryトラフィック割り当て（20%）
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'canary-traffic'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        CURRENT_REV=$(cat /workspace/current_revision.txt)
        NEW_REV="my-app-$SHORT_SHA"

        echo "Allocating 20% traffic to $NEW_REV"
        gcloud run services update-traffic my-app \
          --to-revisions=$CURRENT_REV=80,$NEW_REV=20 \
          --region us-central1
    waitFor: ['get-current-revision', 'health-check']
```

#### 段階的Canaryデプロイスクリプト（Bash）

```bash
#!/bin/bash
# canary-deploy.sh - Gradual Canary Deployment Script

set -e

SERVICE_NAME="my-app"
REGION="us-central1"
NEW_IMAGE="gcr.io/$PROJECT_ID/my-app:$SHORT_SHA"
CANARY_PERCENT=${1:-20}  # デフォルト20%

# 1. トラフィックなしでデプロイ
echo "Deploying new revision without traffic..."
gcloud run deploy $SERVICE_NAME \
  --image $NEW_IMAGE \
  --region $REGION \
  --platform managed \
  --no-traffic

# 2. 現在のリビジョンを取得
CURRENT_REV=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format="value(status.traffic[0].revisionName)")

# 3. 新リビジョン名を取得
NEW_REV=$(gcloud run revisions list \
  --service $SERVICE_NAME \
  --region $REGION \
  --format="value(metadata.name)" \
  --limit 1)

echo "Current revision: $CURRENT_REV"
echo "New revision: $NEW_REV"

# 4. ヘルスチェック
NEW_URL=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format="value(status.url)")

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $NEW_URL/health)

if [ $HTTP_CODE -ne 200 ]; then
  echo "Health check failed with HTTP code: $HTTP_CODE"
  exit 1
fi

echo "Health check passed"

# 5. Canaryトラフィック割り当て
STABLE_PERCENT=$((100 - CANARY_PERCENT))
echo "Allocating ${CANARY_PERCENT}% traffic to new revision..."

gcloud run services update-traffic $SERVICE_NAME \
  --to-revisions=$CURRENT_REV=$STABLE_PERCENT,$NEW_REV=$CANARY_PERCENT \
  --region $REGION

echo "Canary deployment complete."
echo "Monitor metrics and run the following to complete rollout:"
echo "  gcloud run services update-traffic $SERVICE_NAME --to-revisions=$NEW_REV=100 --region $REGION"
echo "Or to rollback:"
echo "  gcloud run services update-traffic $SERVICE_NAME --to-revisions=$CURRENT_REV=100 --region $REGION"
```

**使用例:**

```bash
# 20%割り当て
./canary-deploy.sh 20

# 50%割り当て
./canary-deploy.sh 50
```

#### 自動監視付きCanaryデプロイ（Cloud Build）

```yaml
steps:
  # [前段のビルド・プッシュ・デプロイステップ]

  # Canary 10%
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'canary-10'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        CURRENT_REV=$(cat /workspace/current_revision.txt)
        NEW_REV="my-app-$SHORT_SHA"

        gcloud run services update-traffic my-app \
          --to-revisions=$CURRENT_REV=90,$NEW_REV=10 \
          --region us-central1

  # 10分間監視
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'monitor-10'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        echo "Monitoring 10% canary for 10 minutes..."
        sleep 600

        # エラーレート確認
        ERROR_COUNT=$(gcloud logging read \
          "resource.labels.revision_name=my-app-$SHORT_SHA AND severity=ERROR" \
          --limit 1000 \
          --format="value(timestamp)" | wc -l)

        if [ $ERROR_COUNT -gt 10 ]; then
          echo "Error threshold exceeded. Rolling back..."
          CURRENT_REV=$(cat /workspace/current_revision.txt)
          gcloud run services update-traffic my-app \
            --to-revisions=$CURRENT_REV=100 \
            --region us-central1
          exit 1
        fi
    waitFor: ['canary-10']

  # Canary 50%
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'canary-50'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        CURRENT_REV=$(cat /workspace/current_revision.txt)
        NEW_REV="my-app-$SHORT_SHA"

        gcloud run services update-traffic my-app \
          --to-revisions=$CURRENT_REV=50,$NEW_REV=50 \
          --region us-central1
    waitFor: ['monitor-10']

  # 最終的に100%に移行
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'canary-100'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        NEW_REV="my-app-$SHORT_SHA"

        # 30分間監視後に100%に移行
        echo "Monitoring 50% canary for 30 minutes..."
        sleep 1800

        gcloud run services update-traffic my-app \
          --to-revisions=$NEW_REV=100 \
          --region us-central1
    waitFor: ['canary-50']

timeout: '3600s'  # 1時間タイムアウト
```

## GitHub / GitLab 連携

### GitHub Actions ワークフロー

GitHub Actionsは、GitHubリポジトリに統合されたCI/CDプラットフォーム。

#### 基本的なワークフロー: `.github/workflows/deploy.yml`

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches:
      - main

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      # リポジトリチェックアウト
      - name: Checkout code
        uses: actions/checkout@v3

      # Cloud SDK セットアップ
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
        with:
          project_id: ${{ secrets.GCP_PROJECT_ID }}
          service_account_key: ${{ secrets.GCP_SA_KEY }}

      # Docker認証
      - name: Configure Docker
        run: gcloud auth configure-docker

      # イメージビルド
      - name: Build Docker image
        run: |
          IMAGE_TAG=gcr.io/${{ secrets.GCP_PROJECT_ID }}/my-app:${{ github.sha }}
          docker build -t $IMAGE_TAG .

      # イメージプッシュ
      - name: Push Docker image
        run: |
          IMAGE_TAG=gcr.io/${{ secrets.GCP_PROJECT_ID }}/my-app:${{ github.sha }}
          docker push $IMAGE_TAG

      # Cloud Runデプロイ
      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy my-app \
            --image gcr.io/${{ secrets.GCP_PROJECT_ID }}/my-app:${{ github.sha }} \
            --region us-central1 \
            --platform managed \
            --allow-unauthenticated
```

#### 高度なワークフロー（テスト・スキャン・Canary付き）

```yaml
name: Deploy to Cloud Run with Canary

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: us-central1
  SERVICE_NAME: my-app

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Run linter
        run: npm run lint

  build-and-scan:
    runs-on: ubuntu-latest
    needs: test

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
        with:
          project_id: ${{ env.PROJECT_ID }}
          service_account_key: ${{ secrets.GCP_SA_KEY }}

      - name: Configure Docker
        run: gcloud auth configure-docker

      - name: Build Docker image
        run: |
          IMAGE_TAG=gcr.io/${{ env.PROJECT_ID }}/${{ env.SERVICE_NAME }}:${{ github.sha }}
          docker build -t $IMAGE_TAG .

      - name: Run Trivy security scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: gcr.io/${{ env.PROJECT_ID }}/${{ env.SERVICE_NAME }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Push Docker image
        run: |
          IMAGE_TAG=gcr.io/${{ env.PROJECT_ID }}/${{ env.SERVICE_NAME }}:${{ github.sha }}
          docker push $IMAGE_TAG

  deploy-canary:
    runs-on: ubuntu-latest
    needs: build-and-scan
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
        with:
          project_id: ${{ env.PROJECT_ID }}
          service_account_key: ${{ secrets.GCP_SA_KEY }}

      - name: Deploy with no traffic
        run: |
          gcloud run deploy ${{ env.SERVICE_NAME }} \
            --image gcr.io/${{ env.PROJECT_ID }}/${{ env.SERVICE_NAME }}:${{ github.sha }} \
            --region ${{ env.REGION }} \
            --platform managed \
            --no-traffic

      - name: Get current revision
        id: get-revision
        run: |
          CURRENT_REV=$(gcloud run services describe ${{ env.SERVICE_NAME }} \
            --region ${{ env.REGION }} \
            --format="value(status.traffic[0].revisionName)")
          echo "current_revision=$CURRENT_REV" >> $GITHUB_OUTPUT

      - name: Allocate 20% canary traffic
        run: |
          NEW_REV=$(gcloud run revisions list \
            --service ${{ env.SERVICE_NAME }} \
            --region ${{ env.REGION }} \
            --format="value(metadata.name)" \
            --limit 1)

          gcloud run services update-traffic ${{ env.SERVICE_NAME }} \
            --to-revisions=${{ steps.get-revision.outputs.current_revision }}=80,$NEW_REV=20 \
            --region ${{ env.REGION }}

      - name: Comment on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '✅ Canary deployment complete (20% traffic)\n\nMonitor metrics and manually promote to 100% if stable.'
            })
```

#### PR環境のプレビューデプロイ

```yaml
name: Preview Deployment

on:
  pull_request:
    types: [opened, synchronize]

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: us-central1

jobs:
  deploy-preview:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
        with:
          project_id: ${{ env.PROJECT_ID }}
          service_account_key: ${{ secrets.GCP_SA_KEY }}

      - name: Configure Docker
        run: gcloud auth configure-docker

      - name: Build Docker image
        run: |
          IMAGE_TAG=gcr.io/${{ env.PROJECT_ID }}/my-app-pr-${{ github.event.pull_request.number }}:${{ github.sha }}
          docker build -t $IMAGE_TAG .
          docker push $IMAGE_TAG

      - name: Deploy preview service
        run: |
          gcloud run deploy my-app-pr-${{ github.event.pull_request.number }} \
            --image gcr.io/${{ env.PROJECT_ID }}/my-app-pr-${{ github.event.pull_request.number }}:${{ github.sha }} \
            --region ${{ env.REGION }} \
            --platform managed \
            --allow-unauthenticated

      - name: Get service URL
        id: get-url
        run: |
          URL=$(gcloud run services describe my-app-pr-${{ github.event.pull_request.number }} \
            --region ${{ env.REGION }} \
            --format="value(status.url)")
          echo "service_url=$URL" >> $GITHUB_OUTPUT

      - name: Comment preview URL on PR
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `🚀 Preview deployment ready!\n\n**URL**: ${{ steps.get-url.outputs.service_url }}`
            })
```

**シークレット設定:**

GitHubリポジトリの Settings → Secrets and variables → Actions で以下を設定:

| シークレット名 | 説明 | 取得方法 |
|-------------|------|---------|
| `GCP_PROJECT_ID` | GCPプロジェクトID | Cloud Consoleで確認 |
| `GCP_SA_KEY` | サービスアカウントキー（JSON） | `gcloud iam service-accounts keys create` |

**サービスアカウントキーの作成:**

```bash
# サービスアカウント作成
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions"

# ロール付与
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# キー作成
gcloud iam service-accounts keys create key.json \
  --iam-account=github-actions@$PROJECT_ID.iam.gserviceaccount.com
```

### GitLab CI/CD

**`.gitlab-ci.yml`:**

```yaml
stages:
  - build
  - deploy

variables:
  IMAGE_TAG: gcr.io/$GCP_PROJECT_ID/my-app:$CI_COMMIT_SHORT_SHA

build:
  stage: build
  image: google/cloud-sdk:alpine
  services:
    - docker:dind
  before_script:
    - echo $GCP_SA_KEY | base64 -d > ${HOME}/gcloud-service-key.json
    - gcloud auth activate-service-account --key-file ${HOME}/gcloud-service-key.json
    - gcloud config set project $GCP_PROJECT_ID
    - gcloud auth configure-docker
  script:
    - docker build -t $IMAGE_TAG .
    - docker push $IMAGE_TAG

deploy:
  stage: deploy
  image: google/cloud-sdk:alpine
  before_script:
    - echo $GCP_SA_KEY | base64 -d > ${HOME}/gcloud-service-key.json
    - gcloud auth activate-service-account --key-file ${HOME}/gcloud-service-key.json
    - gcloud config set project $GCP_PROJECT_ID
  script:
    - gcloud run deploy my-app
        --image $IMAGE_TAG
        --region us-central1
        --platform managed
        --allow-unauthenticated
  only:
    - main
```

## パイプライン設計パターン

### ビルド → テスト → デプロイ → 監視

**完全なパイプライン（Cloud Build）:**

```yaml
steps:
  # ================
  # ビルドステージ
  # ================
  - name: 'gcr.io/cloud-builders/docker'
    id: 'build'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']

  # ================
  # テストステージ
  # ================
  # ユニットテスト
  - name: 'gcr.io/cloud-builders/docker'
    id: 'unit-test'
    args:
      - 'run'
      - '--rm'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
      - 'npm'
      - 'test'
    waitFor: ['build']

  # 脆弱性スキャン
  - name: 'aquasec/trivy'
    id: 'security-scan'
    args:
      - 'image'
      - '--exit-code'
      - '0'
      - '--severity'
      - 'HIGH,CRITICAL'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
    waitFor: ['build']

  # ================
  # プッシュステージ
  # ================
  - name: 'gcr.io/cloud-builders/docker'
    id: 'push'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']
    waitFor: ['unit-test', 'security-scan']

  # ================
  # デプロイステージ
  # ================
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'deploy'
    args:
      - 'run'
      - 'deploy'
      - 'my-app'
      - '--image'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
      - '--region'
      - 'us-central1'
      - '--platform'
      - 'managed'
      - '--memory'
      - '512Mi'
      - '--cpu'
      - '1'
      - '--max-instances'
      - '10'
      - '--set-env-vars'
      - 'PORT=8080,DEBUG=false'
      - '--allow-unauthenticated'
    waitFor: ['push']

  # ================
  # 監視ステージ（通知）
  # ================
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'notify'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        SERVICE_URL=$(gcloud run services describe my-app --region us-central1 --format="value(status.url)")
        echo "Deployment complete: $SERVICE_URL"
    waitFor: ['deploy']

images:
  - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'

timeout: '1800s'
```

### マルチ環境デプロイ（dev/staging/prod）

**ブランチ別デプロイ:**

```yaml
steps:
  # イメージビルド
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']

  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']

  # 開発環境デプロイ（developブランチ）
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        if [ "$BRANCH_NAME" == "develop" ]; then
          gcloud run deploy my-app-dev \
            --image gcr.io/$PROJECT_ID/my-app:$SHORT_SHA \
            --region us-central1 \
            --platform managed \
            --set-env-vars "ENV=development"
        fi

  # ステージング環境デプロイ（stagingブランチ）
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        if [ "$BRANCH_NAME" == "staging" ]; then
          gcloud run deploy my-app-staging \
            --image gcr.io/$PROJECT_ID/my-app:$SHORT_SHA \
            --region us-central1 \
            --platform managed \
            --set-env-vars "ENV=staging"
        fi

  # 本番環境デプロイ（mainブランチ）
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        if [ "$BRANCH_NAME" == "main" ]; then
          gcloud run deploy my-app \
            --image gcr.io/$PROJECT_ID/my-app:$SHORT_SHA \
            --region us-central1 \
            --platform managed \
            --set-env-vars "ENV=production" \
            --no-traffic
        fi
```

## ロールバック自動化

### ヘルスチェックとロールバック

**Cloud Build でのヘルスチェック:**

```yaml
steps:
  # デプロイ
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'deploy'
    args:
      - 'run'
      - 'deploy'
      - 'my-app'
      - '--image'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
      - '--region'
      - 'us-central1'
      - '--no-traffic'

  # 新リビジョンのURLを取得してヘルスチェック
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'health-check'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        REVISION_URL=$(gcloud run revisions describe my-app-$SHORT_SHA --region us-central1 --format="value(status.url)")
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $REVISION_URL/health)
        if [ $HTTP_CODE -ne 200 ]; then
          echo "Health check failed with HTTP code: $HTTP_CODE"
          exit 1
        fi
        echo "Health check passed"

  # トラフィック割り当て
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'assign-traffic'
    args:
      - 'run'
      - 'services'
      - 'update-traffic'
      - 'my-app'
      - '--to-revisions=my-app-$SHORT_SHA=20'
      - '--region'
      - 'us-central1'
    waitFor: ['health-check']
```

### Cloud Monitoring アラートでの自動ロールバック

**アラートポリシー作成:**

```bash
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Cloud Run High Error Rate" \
  --condition-display-name="Error rate > 5%" \
  --condition-threshold-value=0.05 \
  --condition-threshold-duration=60s \
  --condition-filter='resource.type="cloud_run_revision" AND metric.type="run.googleapis.com/request_count" AND metric.label.response_code_class="5xx"'
```

**Cloud Functionsでロールバック実行:**

```python
# Cloud Functionのコード（Python）
from google.cloud import run_v2
import os

def rollback_on_alert(data, context):
    """Cloud Monitoringアラートからトリガーされる"""
    client = run_v2.ServicesClient()

    service_name = "my-app"
    project_id = os.environ.get('GCP_PROJECT_ID')
    region = "us-central1"

    service_path = f"projects/{project_id}/locations/{region}/services/{service_name}"

    # 前のリビジョンにロールバック
    service = client.get_service(name=service_path)
    current_traffic = service.traffic

    # 100%トラフィックを前のリビジョンに戻す
    previous_revision = current_traffic[1].revision if len(current_traffic) > 1 else current_traffic[0].revision

    service.traffic = [
        run_v2.TrafficTarget(
            type_=run_v2.TrafficTargetAllocationType.TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION,
            revision=previous_revision,
            percent=100
        )
    ]

    client.update_service(service=service)
    print(f"Rolled back to {previous_revision}")
```

### Jenkins パイプライン連携

Jenkinsは拡張性の高いオープンソースCI/CDツールで、Cloud Runとの統合も可能。

#### Jenkinsfile例（Declarative Pipeline）

```groovy
pipeline {
  agent any

  environment {
    PROJECT_ID = 'my-cloud-run-project'
    SERVICE_NAME = 'my-app'
    REGION = 'us-central1'
    IMAGE_TAG = "gcr.io/${PROJECT_ID}/${SERVICE_NAME}:${env.GIT_COMMIT.take(7)}"
    GCP_KEY = credentials('gcp-service-account-key')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          dockerImage = docker.build("${IMAGE_TAG}")
        }
      }
    }

    stage('Run Tests') {
      steps {
        script {
          dockerImage.inside {
            sh 'npm install'
            sh 'npm test'
          }
        }
      }
    }

    stage('Security Scan') {
      steps {
        sh """
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy image \
            --exit-code 1 \
            --severity HIGH,CRITICAL \
            ${IMAGE_TAG}
        """
      }
    }

    stage('Push to Registry') {
      steps {
        script {
          docker.withRegistry('https://gcr.io', 'gcr:gcp-key') {
            dockerImage.push()
          }
        }
      }
    }

    stage('Deploy to Cloud Run') {
      steps {
        sh """
          gcloud auth activate-service-account --key-file=${GCP_KEY}
          gcloud config set project ${PROJECT_ID}

          gcloud run deploy ${SERVICE_NAME} \
            --image ${IMAGE_TAG} \
            --region ${REGION} \
            --platform managed \
            --allow-unauthenticated
        """
      }
    }

    stage('Health Check') {
      steps {
        sh """
          SERVICE_URL=\$(gcloud run services describe ${SERVICE_NAME} \
            --region ${REGION} \
            --format="value(status.url)")

          HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" \$SERVICE_URL/health)

          if [ \$HTTP_CODE -ne 200 ]; then
            echo "Health check failed with HTTP code: \$HTTP_CODE"
            exit 1
          fi
        """
      }
    }
  }

  post {
    success {
      echo 'Deployment successful!'
    }
    failure {
      echo 'Deployment failed!'
      // Rollback logic here if needed
    }
  }
}
```

#### マルチ環境対応Jenkinsfile

```groovy
pipeline {
  agent any

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'], description: 'Target environment')
  }

  environment {
    PROJECT_ID = 'my-cloud-run-project'
    SERVICE_NAME = "my-app-${params.ENVIRONMENT}"
    REGION = 'us-central1'
    IMAGE_TAG = "gcr.io/${PROJECT_ID}/my-app:${env.GIT_COMMIT.take(7)}"
  }

  stages {
    stage('Build and Test') {
      steps {
        sh 'docker build -t ${IMAGE_TAG} .'
        sh 'docker run --rm ${IMAGE_TAG} npm test'
      }
    }

    stage('Push to Registry') {
      steps {
        sh """
          gcloud auth activate-service-account --key-file=\$GCP_KEY
          gcloud auth configure-docker
          docker push ${IMAGE_TAG}
        """
      }
    }

    stage('Deploy') {
      steps {
        script {
          def envVars = ""
          if (params.ENVIRONMENT == 'dev') {
            envVars = "DEBUG=true,LOG_LEVEL=debug"
          } else if (params.ENVIRONMENT == 'staging') {
            envVars = "DEBUG=false,LOG_LEVEL=info"
          } else {
            envVars = "DEBUG=false,LOG_LEVEL=warn"
          }

          sh """
            gcloud run deploy ${SERVICE_NAME} \
              --image ${IMAGE_TAG} \
              --region ${REGION} \
              --platform managed \
              --set-env-vars="${envVars}"
          """
        }
      }
    }
  }
}
```

---

## Build Triggers とリポジトリ連携

### Cloud Build トリガーの詳細設定

#### GitHubリポジトリ連携

**トリガー作成（gcloud）:**

```bash
gcloud builds triggers create github \
  --repo-name=my-repo \
  --repo-owner=my-org \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml \
  --description="Deploy to Cloud Run on main branch"
```

**トリガー作成（Cloud Console）:**

1. Cloud Build → トリガー → トリガーを作成
2. **ソースを選択**: GitHub
3. **リポジトリを選択**: GitHub アプリ認証後、対象リポジトリを選択
4. **トリガー設定**:
   - **イベント**: ブランチにプッシュ
   - **ブランチ**: `^main$`（正規表現）
   - **Cloud Build 構成ファイル**: `cloudbuild.yaml`
   - **置換変数** (オプション):
     - `_REGION`: `us-central1`
     - `_SERVICE_NAME`: `my-app`

#### GitLabリポジトリ連携

```bash
gcloud builds triggers create gitlab \
  --project-namespace=my-group \
  --repo-name=my-repo \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml
```

#### トリガーの高度な設定

**タグベースデプロイ:**

```bash
gcloud builds triggers create github \
  --repo-name=my-repo \
  --repo-owner=my-org \
  --tag-pattern="^v[0-9]+\.[0-9]+\.[0-9]+$" \
  --build-config=cloudbuild.yaml \
  --description="Deploy to Cloud Run on version tag"
```

**プルリクエストでのプレビュー:**

```bash
gcloud builds triggers create github \
  --repo-name=my-repo \
  --repo-owner=my-org \
  --pull-request-pattern="^main$" \
  --build-config=cloudbuild-preview.yaml \
  --comment-control=COMMENTS_ENABLED
```

**ファイルパスフィルター:**

```bash
gcloud builds triggers create github \
  --repo-name=my-repo \
  --repo-owner=my-org \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml \
  --included-files="src/**,Dockerfile,package.json"
```

**トリガー一覧と管理:**

```bash
# トリガー一覧
gcloud builds triggers list

# トリガー詳細
gcloud builds triggers describe TRIGGER_ID

# トリガー更新
gcloud builds triggers update TRIGGER_ID \
  --branch-pattern="^develop$"

# トリガー削除
gcloud builds triggers delete TRIGGER_ID
```

#### 置換変数の活用

**cloudbuild.yaml with 置換変数:**

```yaml
substitutions:
  _REGION: us-central1
  _SERVICE_NAME: my-app
  _ENV: production

steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/${_SERVICE_NAME}:$SHORT_SHA', '.']

  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/${_SERVICE_NAME}:$SHORT_SHA']

  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'run'
      - 'deploy'
      - '${_SERVICE_NAME}'
      - '--image'
      - 'gcr.io/$PROJECT_ID/${_SERVICE_NAME}:$SHORT_SHA'
      - '--region'
      - '${_REGION}'
      - '--set-env-vars'
      - 'ENV=${_ENV}'
```

**トリガー作成時に置換変数を設定:**

```bash
gcloud builds triggers create github \
  --repo-name=my-repo \
  --repo-owner=my-org \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml \
  --substitutions _REGION=us-central1,_SERVICE_NAME=my-app,_ENV=production
```

### タグベースデプロイ

**タグプッシュでトリガー:**

```bash
gcloud builds triggers create github \
  --repo-name=my-repo \
  --repo-owner=my-org \
  --tag-pattern="^v[0-9]+\.[0-9]+\.[0-9]+$" \
  --build-config=cloudbuild.yaml \
  --description="Deploy to Cloud Run on version tag"
```

**cloudbuild.yamlでタグを利用:**

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$TAG_NAME', '.']

  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$TAG_NAME']

  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'run'
      - 'deploy'
      - 'my-app'
      - '--image'
      - 'gcr.io/$PROJECT_ID/my-app:$TAG_NAME'
      - '--region'
      - 'us-central1'
```

**タグのプッシュ:**

```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## ベストプラクティス

### イミュータブルなイメージタグ

**悪い例（`:latest` を使う）:**

```yaml
# ❌ latestタグは変更されるため、ロールバック困難
--image gcr.io/my-project/my-app:latest
```

**良い例（コミットSHAを使う）:**

```yaml
# ✅ 一意なタグでバージョン管理可能
--image gcr.io/my-project/my-app:$SHORT_SHA
```

### 並列ビルドの活用

**waitFor でステップを並列化:**

```yaml
steps:
  # ビルド
  - name: 'gcr.io/cloud-builders/docker'
    id: 'build'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']

  # 以下2つは並列実行（buildの後）
  - name: 'gcr.io/cloud-builders/docker'
    id: 'unit-test'
    args: ['run', '--rm', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', 'npm', 'test']
    waitFor: ['build']

  - name: 'aquasec/trivy'
    id: 'security-scan'
    args: ['image', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']
    waitFor: ['build']

  # プッシュは両方のテスト完了後
  - name: 'gcr.io/cloud-builders/docker'
    id: 'push'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']
    waitFor: ['unit-test', 'security-scan']
```

### キャッシュの活用

**Cloud Build でのDocker レイヤーキャッシュ:**

```yaml
steps:
  # キャッシュをpull
  - name: 'gcr.io/cloud-builders/docker'
    entrypoint: 'bash'
    args:
      - '-c'
      - 'docker pull gcr.io/$PROJECT_ID/my-app:latest || exit 0'

  # キャッシュを使ってビルド
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '--cache-from'
      - 'gcr.io/$PROJECT_ID/my-app:latest'
      - '-t'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
      - '.'

  # 新しいlatestタグをプッシュ
  - name: 'gcr.io/cloud-builders/docker'
    args: ['tag', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', 'gcr.io/$PROJECT_ID/my-app:latest']

  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:latest']
```

### シークレット管理

**Cloud Build でSecret Manager を使用:**

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        echo "$$DATABASE_PASSWORD" | docker login -u myuser --password-stdin registry.example.com
        docker build -t gcr.io/$PROJECT_ID/my-app:$SHORT_SHA .

availableSecrets:
  secretManager:
    - versionName: projects/$PROJECT_ID/secrets/database-password/versions/latest
      env: 'DATABASE_PASSWORD'
```

## トラブルシューティング

### ビルドが失敗する

**ログ確認:**

```bash
# Cloud Build のビルドログ確認
gcloud builds list --limit=5
gcloud builds log BUILD_ID
```

**よくある原因:**

| エラー | 原因 | 対処方法 |
|-------|------|---------|
| "Step timeout" | ステップが長すぎる | `timeout` を増やす |
| "Permission denied" | 権限不足 | Cloud Build サービスアカウントにロール付与 |
| "Image not found" | ベースイメージが存在しない | イメージ名を確認 |
| "Build timeout" | ビルド全体が長すぎる | `timeout` を全体で設定 |

**タイムアウトの設定:**

```yaml
# 全体のタイムアウト（デフォルト10分）
timeout: '1800s'

steps:
  # ステップごとのタイムアウト
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']
    timeout: '600s'
```

### デプロイが遅い

**原因と対策:**

| 原因 | 対策 |
|-----|------|
| イメージサイズが大きい | マルチステージビルド、Alpine使用 |
| ネットワーク遅延 | リージョンを近くに変更 |
| キャッシュ未使用 | `--cache-from` でレイヤーキャッシュ |

### トリガーが起動しない

**確認項目:**

1. トリガー設定のブランチパターンが正しいか
2. GitHubとの連携が有効か
3. Cloud Build APIが有効化されているか

**確認コマンド:**

```bash
# トリガー一覧
gcloud builds triggers list

# トリガー詳細
gcloud builds triggers describe TRIGGER_ID
```
