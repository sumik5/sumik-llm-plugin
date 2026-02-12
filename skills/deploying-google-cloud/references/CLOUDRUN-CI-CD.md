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

### 脆弱性スキャン統合

**Trivy によるスキャン:**

```yaml
steps:
  # イメージビルド
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']

  # 脆弱性スキャン
  - name: 'aquasec/trivy'
    args:
      - 'image'
      - '--exit-code'
      - '1'
      - '--severity'
      - 'HIGH,CRITICAL'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'

  # イメージプッシュ
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']
```

### カナリーデプロイの実装

**20%トラフィック割り当て:**

```yaml
steps:
  # イメージビルド・プッシュ
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA', '.']

  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA']

  # トラフィックなしでデプロイ
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'run'
      - 'deploy'
      - 'my-app'
      - '--image'
      - 'gcr.io/$PROJECT_ID/my-app:$SHORT_SHA'
      - '--region'
      - 'us-central1'
      - '--no-traffic'

  # 現在のリビジョンを取得
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'get-current-revision'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        gcloud run services describe my-app --region us-central1 --format="value(status.traffic[0].revisionName)" > /workspace/current_revision.txt

  # カナリートラフィック割り当て
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        CURRENT_REV=$(cat /workspace/current_revision.txt)
        gcloud run services update-traffic my-app \
          --to-revisions=$CURRENT_REV=80,my-app-$SHORT_SHA=20 \
          --region us-central1
```

## GitHub / GitLab 連携

### GitHub Actions

GitHub Actionsは、GitHubリポジトリに統合されたCI/CDプラットフォーム。

**ワークフローファイル: `.github/workflows/deploy.yml`**

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
        uses: actions/checkout@v2

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

## Cloud Build トリガー設定

### GitHubリポジトリ連携

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
2. ソースを選択: GitHub
3. リポジトリを選択
4. トリガー設定:
   - イベント: ブランチにプッシュ
   - ブランチ: `^main$`
   - Cloud Build 構成ファイル: `cloudbuild.yaml`

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
