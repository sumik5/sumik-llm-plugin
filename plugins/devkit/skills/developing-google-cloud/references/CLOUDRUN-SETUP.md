# Cloud Run 開発環境セットアップ

Cloud Run でのアプリケーション開発に必要な環境構築のステップバイステップガイド。Google Cloud SDK のインストール、認証設定、複数プロジェクト管理、Cloud Shell 活用、IDE 統合、CLI 自動化までを網羅する。

## Google Cloud SDK のインストール

### インストール方法（OS別）

#### macOS

```bash
# Homebrew を使用
brew install --cask google-cloud-sdk

# インストール確認
gcloud version
```

#### Linux（Debian/Ubuntu）

```bash
# パッケージソースを追加
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# 公開鍵をインポート
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

# SDK をインストール
sudo apt-get update && sudo apt-get install google-cloud-sdk

# 追加コンポーネント（任意）
sudo apt-get install google-cloud-sdk-app-engine-python \
  google-cloud-sdk-app-engine-java \
  google-cloud-sdk-cloud-build-local
```

#### Windows

1. https://cloud.google.com/sdk/docs/install から Windows 用インストーラーをダウンロード
2. インストーラーを実行し、指示に従ってインストール
3. PowerShell または Command Prompt を再起動

### 初期化

```bash
# 対話式初期化
gcloud init

# 以下の手順で設定:
# 1. Google アカウントでログイン
# 2. プロジェクトの選択または新規作成
# 3. デフォルトのリージョン設定（例: asia-northeast1）
```

---

## 認証設定

### ユーザー認証（開発環境）

```bash
# 対話式ログイン（ブラウザが開く）
gcloud auth login

# 認証状態確認
gcloud auth list

# デフォルトアカウント設定
gcloud config set account my-email@example.com
```

### アプリケーションデフォルト認証（ADC）

ローカル開発環境でアプリケーションが Google Cloud API を呼び出す際に使用する。

```bash
# ADC 認証情報を設定
gcloud auth application-default login

# 認証情報の保存場所
# macOS/Linux: ~/.config/gcloud/application_default_credentials.json
# Windows: %APPDATA%\gcloud\application_default_credentials.json
```

**Python コードでの使用例:**

```python
from google.cloud import storage

# ADC が自動的に使用される
client = storage.Client()
buckets = client.list_buckets()
```

### サービスアカウント認証（CI/CD環境）

CI/CDパイプライン（GitHub Actions、GitLab CI等）ではサービスアカウントを使用する。

#### サービスアカウント作成

```bash
# サービスアカウントを作成
gcloud iam service-accounts create cloud-run-deployer \
  --display-name="Cloud Run Deployer" \
  --description="CI/CD pipeline service account"

# Cloud Run デプロイ権限を付与
gcloud projects add-iam-policy-binding my-project-id \
  --member="serviceAccount:cloud-run-deployer@my-project-id.iam.gserviceaccount.com" \
  --role="roles/run.admin"

# Artifact Registry 読み取り権限
gcloud projects add-iam-policy-binding my-project-id \
  --member="serviceAccount:cloud-run-deployer@my-project-id.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"

# 鍵ファイルを作成（ダウンロード）
gcloud iam service-accounts keys create ~/cloud-run-deployer-key.json \
  --iam-account=cloud-run-deployer@my-project-id.iam.gserviceaccount.com
```

#### CI/CDでの使用

**GitHub Actions での例:**

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy my-service \
            --image gcr.io/my-project/my-app:latest \
            --platform managed \
            --region asia-northeast1
```

**GitLab CI での例:**

```yaml
deploy:
  image: google/cloud-sdk:latest
  script:
    - echo $GCP_SA_KEY | gcloud auth activate-service-account --key-file=-
    - gcloud config set project my-project-id
    - gcloud run deploy my-service \
        --image gcr.io/my-project/my-app:latest \
        --platform managed \
        --region asia-northeast1
  only:
    - main
```

---

## プロジェクト管理

### プロジェクトの作成

```bash
# プロジェクト作成
gcloud projects create my-new-project-id \
  --name="My New Project" \
  --labels=environment=dev,team=engineering

# プロジェクト一覧
gcloud projects list

# デフォルトプロジェクトを設定
gcloud config set project my-new-project-id
```

### APIの有効化

Cloud Run を使用するには、関連する API を有効化する必要がある。

```bash
# Cloud Run API
gcloud services enable run.googleapis.com

# Artifact Registry（コンテナイメージ保存用）
gcloud services enable artifactregistry.googleapis.com

# Cloud Build（CI/CD用）
gcloud services enable cloudbuild.googleapis.com

# 有効化済みAPIの一覧
gcloud services list --enabled
```

### Artifact Registry リポジトリ作成

Cloud Run で使用するコンテナイメージを保存するための Docker リポジトリを作成する。

```bash
# Docker リポジトリ作成
gcloud artifacts repositories create my-docker-repo \
  --repository-format=docker \
  --location=asia-northeast1 \
  --description="Container images for Cloud Run"

# 認証設定（Docker CLI で push できるようにする）
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

**イメージのビルドとプッシュ:**

```bash
# イメージをビルド
docker build -t asia-northeast1-docker.pkg.dev/my-project-id/my-docker-repo/my-app:latest .

# Artifact Registry にプッシュ
docker push asia-northeast1-docker.pkg.dev/my-project-id/my-docker-repo/my-app:latest
```

---

## 複数環境の管理

開発、ステージング、本番環境を分離して管理するためのベストプラクティス。

### 方式1: プロジェクト分離（推奨）

環境ごとに異なる Google Cloud プロジェクトを使用する。

| 環境 | プロジェクトID | リージョン | 用途 |
|------|--------------|----------|------|
| 開発 | `my-app-dev` | `asia-northeast1` | 開発者の検証環境 |
| ステージング | `my-app-staging` | `asia-northeast1` | QA・統合テスト |
| 本番 | `my-app-production` | `asia-northeast1` | エンドユーザー向け |

**メリット:**
- 完全な環境分離（誤操作リスク低）
- 環境ごとに異なるIAM権限設定が可能
- 課金の透明性（環境別コスト把握が容易）

**デメリット:**
- 管理対象プロジェクトが増える
- プロジェクト間のリソース共有には追加設定が必要

**プロジェクト切り替え:**

```bash
# 開発環境に切り替え
gcloud config set project my-app-dev

# ステージング環境に切り替え
gcloud config set project my-app-staging

# 本番環境に切り替え
gcloud config set project my-app-production
```

### 方式2: サービス名分離（小規模向け）

単一プロジェクト内で環境ごとに異なるサービス名を使用する。

```bash
# 開発環境
gcloud run deploy my-app-dev \
  --image asia-northeast1-docker.pkg.dev/my-project/repo/my-app:dev \
  --region asia-northeast1

# ステージング環境
gcloud run deploy my-app-staging \
  --image asia-northeast1-docker.pkg.dev/my-project/repo/my-app:staging \
  --region asia-northeast1

# 本番環境
gcloud run deploy my-app-prod \
  --image asia-northeast1-docker.pkg.dev/my-project/repo/my-app:latest \
  --region asia-northeast1
```

**メリット:**
- プロジェクト管理がシンプル
- リソース共有が容易

**デメリット:**
- IAM権限の粒度が粗い（環境ごとのアクセス制御が難しい）
- 誤って本番サービスを操作するリスク

### 方式3: gcloud 設定プロファイル活用

環境ごとに gcloud の設定プロファイルを作成し、切り替える。

```bash
# 開発環境用プロファイル作成
gcloud config configurations create dev
gcloud config set project my-app-dev
gcloud config set account dev-user@example.com
gcloud config set run/region asia-northeast1

# ステージング環境用プロファイル作成
gcloud config configurations create staging
gcloud config set project my-app-staging
gcloud config set account staging-user@example.com
gcloud config set run/region asia-northeast1

# 本番環境用プロファイル作成
gcloud config configurations create production
gcloud config set project my-app-production
gcloud config set account prod-user@example.com
gcloud config set run/region asia-northeast1

# プロファイル一覧
gcloud config configurations list

# プロファイル切り替え
gcloud config configurations activate dev
gcloud config configurations activate production
```

**現在の設定を確認:**

```bash
gcloud config list
```

---

## 環境変数の管理

環境ごとに異なる設定値（API エンドポイント、データベース接続情報等）を管理する方法。

### 環境変数ファイル方式

環境ごとに `.env` ファイルを用意する。

**ディレクトリ構成:**

```
project/
├── .env.dev
├── .env.staging
├── .env.production
└── deploy.sh
```

**`.env.dev` サンプル:**

```bash
PROJECT_ID=my-app-dev
REGION=asia-northeast1
SERVICE_NAME=my-app-dev
IMAGE_TAG=asia-northeast1-docker.pkg.dev/my-app-dev/repo/my-app:latest
DB_HOST=10.0.1.1
DB_NAME=mydb_dev
```

**デプロイスクリプト（`deploy.sh`）:**

```bash
#!/bin/bash
set -e

# 引数から環境を取得
ENV=$1

# 環境変数ファイルを読み込み
if [ ! -f ".env.${ENV}" ]; then
  echo "Error: .env.${ENV} not found"
  exit 1
fi

source ".env.${ENV}"

# Cloud Run にデプロイ
gcloud run deploy ${SERVICE_NAME} \
  --image ${IMAGE_TAG} \
  --platform managed \
  --region ${REGION} \
  --project ${PROJECT_ID} \
  --set-env-vars "DB_HOST=${DB_HOST},DB_NAME=${DB_NAME}"

echo "Deployed to ${ENV} environment"
```

**実行例:**

```bash
# 開発環境にデプロイ
./deploy.sh dev

# ステージング環境にデプロイ
./deploy.sh staging

# 本番環境にデプロイ
./deploy.sh production
```

### Secret Manager 統合（推奨）

機密情報（API キー、データベースパスワード等）は Secret Manager に保存し、Cloud Run から参照する。

```bash
# Secret を作成
echo -n "my-secret-password" | gcloud secrets create db-password --data-file=-

# Cloud Run にデプロイ時、Secret をマウント
gcloud run deploy my-service \
  --image asia-northeast1-docker.pkg.dev/my-project/repo/my-app:latest \
  --update-secrets DB_PASSWORD=db-password:latest \
  --region asia-northeast1
```

**コンテナ内での参照:**

```python
import os

# 環境変数として参照
db_password = os.environ.get("DB_PASSWORD")
```

---

## ローカル開発環境

### Docker Compose によるローカルテスト

Cloud Run で動作するコンテナをローカルで検証する。

**`docker-compose.yml` サンプル:**

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      PORT: 8080
      DB_HOST: db
      DB_NAME: mydb
      DB_USER: postgres
      DB_PASSWORD: password
    depends_on:
      - db

  db:
    image: postgres:13
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
```

**実行:**

```bash
# ビルドと起動
docker-compose up --build

# 停止
docker-compose down
```

### Cloud Run Emulator（エミュレータ）

※ Cloud Run には公式のローカルエミュレータは存在しないが、Docker を使用して同等の環境を構築できる。

**Dockerfile ベースのローカル実行:**

```bash
# イメージをビルド
docker build -t my-app:local .

# ローカルで起動（PORT=8080 を自動設定）
docker run -p 8080:8080 -e PORT=8080 my-app:local

# ブラウザまたは curl でアクセス
curl http://localhost:8080
```

---

## トラブルシューティング

### よくあるエラーと対処法

#### エラー: `Permission denied`

```bash
# 原因: 必要な権限がない
# 対処法: IAM権限を確認
gcloud projects get-iam-policy my-project-id
```

#### エラー: `API not enabled`

```bash
# 原因: 必要なAPIが有効化されていない
# 対処法: APIを有効化
gcloud services enable run.googleapis.com
```

#### エラー: `Image not found`

```bash
# 原因: イメージがArtifact Registryに存在しない、または認証エラー
# 対処法: イメージのビルドとプッシュを再実行
docker build -t asia-northeast1-docker.pkg.dev/my-project/repo/my-app:latest .
docker push asia-northeast1-docker.pkg.dev/my-project/repo/my-app:latest

# 認証設定を確認
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

#### エラー: `Port 8080 not responding`

```bash
# 原因: コンテナが PORT 環境変数を読み取っていない
# 対処法: Dockerfileまたはコード内で PORT 環境変数を参照するように修正
# 例（Python Flask）:
# port = int(os.environ.get("PORT", 8080))
# app.run(host='0.0.0.0', port=port)
```

---

## まとめ

Cloud Run の開発環境セットアップでは以下が重要:

1. **Google Cloud SDK のインストールと認証**: ユーザー認証（開発）とサービスアカウント認証（CI/CD）を使い分ける
2. **プロジェクト管理**: 環境ごとにプロジェクトを分離する方式が推奨（dev/staging/production）
3. **APIの有効化**: `run.googleapis.com`、`artifactregistry.googleapis.com` 等を事前に有効化
4. **複数環境の管理**: gcloud 設定プロファイル、環境変数ファイル、Secret Manager を活用
5. **ローカル開発**: Docker Compose で Cloud Run 相当の環境を構築し、デプロイ前に検証

これらのセットアップを正しく行うことで、開発から本番デプロイまでのワークフローがスムーズになり、セキュリティと運用効率が大幅に向上する。

---

## Cloud Shell の活用

### Cloud Shell とは

- **ブラウザベースのシェル環境**: Google Cloud Console から即座にアクセス
- **事前インストール済みツール**: gcloud, kubectl, docker, git, terraform 等
- **認証済み**: 現在ログイン中のアカウントで自動認証
- **永続ストレージ**: ホームディレクトリ（5GB）が保持される

### Cloud Shell 起動方法

1. Google Cloud Console 右上の `>_` アイコンをクリック
2. 新しいペインでシェルが起動
3. 即座に `gcloud` コマンドが利用可能

### Cloud Shell でのコンテナビルド・テスト

**Dockerfile を含むプロジェクトディレクトリに移動:**

```bash
cd ~/my-app
```

**Docker イメージのビルド:**

```bash
docker build -t my-app:latest .
```

**ローカルテスト:**

```bash
docker run -p 8080:8080 my-app:latest
```

**Web Preview 機能でアクセス:**

Cloud Shell の「ウェブでプレビュー」 → ポート 8080 を選択すると、ブラウザでアプリケーションにアクセス可能。

**HTTP リクエストテスト:**

```bash
curl http://localhost:8080
```

### Cloud Shell エディタ

コード編集も可能:

```bash
cloudshell edit app.py
```

ブラウザ内 IDE（Theia ベース）が起動し、シンタックスハイライトやファイルツリー表示が利用できる。

---

## ローカルエミュレーター活用

### Docker でのローカル実行

**Cloud Run 環境変数のシミュレーション:**

```bash
export PORT=8080
export CONCURRENCY=80

docker run \
  -e PORT \
  -e CONCURRENCY \
  -p 8080:8080 \
  my-app:latest
```

**リクエストテスト:**

```bash
curl -v http://localhost:8080/api/status
```

### Google Cloud サービスエミュレーター

#### Cloud Firestore Emulator

```bash
gcloud beta emulators firestore start --host-port=localhost:8081
```

アプリケーションコード内で接続先を変更:

```python
import os
from google.cloud import firestore

if os.getenv('FIRESTORE_EMULATOR_HOST'):
    client = firestore.Client(project='test-project')
else:
    client = firestore.Client()
```

#### Cloud Pub/Sub Emulator

```bash
gcloud beta emulators pubsub start --host-port=localhost:8085
```

環境変数での接続先設定:

```bash
export PUBSUB_EMULATOR_HOST=localhost:8085
```

---

## IDE 統合（VS Code / IntelliJ）

### Cloud Code for Visual Studio Code

**インストール:**

VS Code 拡張機能から「Cloud Code」を検索してインストール。

**機能:**
- プロジェクトテンプレート生成
- ローカルエミュレーターでのデバッグ
- Cloud Run へのワンクリックデプロイ
- ログのリアルタイム表示

**デバッグ設定例（`.vscode/launch.json`）:**

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Cloud Run Emulator",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/app.py",
      "env": {
        "PORT": "8080",
        "DEBUG": "true"
      },
      "console": "integratedTerminal",
      "preLaunchTask": "docker-run: my-app"
    }
  ]
}
```

**タスク定義（`.vscode/tasks.json`）:**

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "docker-run: my-app",
      "type": "shell",
      "command": "docker run -d -p 8080:8080 --name my-app-dev my-app:latest"
    }
  ]
}
```

### Cloud Code for IntelliJ IDEA

**インストール:**

Settings → Plugins → Marketplace から「Cloud Code」を検索。

**機能:**
- Kubernetes/Cloud Run デプロイメント管理
- サービスログの統合表示
- Docker イメージビルドの自動化
- コンテキストメニューから直接デプロイ

**Run Configuration 例:**

1. Run → Edit Configurations
2. `+` → Cloud Run
3. Image: `gcr.io/my-project/my-app:latest`
4. Region: `asia-northeast1`
5. Environment Variables: `PORT=8080`

### Docker 拡張機能（汎用）

**VS Code Docker Extension:**

- コンテナ一覧表示
- イメージのビルド/プッシュ
- ログの直接表示

**IntelliJ Docker プラグイン:**

- Dockerfile のシンタックスハイライト
- docker-compose.yml のサポート
- コンテナ実行状態の可視化

---

## CLI スクリプティング自動化

### デプロイ自動化スクリプト

**deploy.sh サンプル:**

```bash
#!/bin/bash
set -euo pipefail

PROJECT_ID="my-cloud-run-project"
REGION="asia-northeast1"
SERVICE_NAME="my-app"
IMAGE_TAG=$(date +%Y%m%d%H%M%S)
IMAGE="asia-northeast1-docker.pkg.dev/${PROJECT_ID}/repo/${SERVICE_NAME}:${IMAGE_TAG}"

# プロジェクト設定
gcloud config set project "${PROJECT_ID}"

# Docker イメージビルド
echo "Building Docker image..."
docker build -t "${IMAGE}" .

# Cloud Build でビルド（推奨）
gcloud builds submit --tag "${IMAGE}" .

# Cloud Run へデプロイ
echo "Deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
  --image "${IMAGE}" \
  --region "${REGION}" \
  --platform managed \
  --allow-unauthenticated

echo "Deployment complete!"
gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" --format="value(status.url)"
```

**実行:**

```bash
chmod +x deploy.sh
./deploy.sh
```

### ログ取得自動化

**Cloud Run ログを JSON 形式で取得:**

```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=my-app" \
  --limit 50 \
  --format json
```

**特定エラーのみ抽出:**

```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND severity>=ERROR" \
  --limit 20
```

### サービス一覧取得とフォーマット

```bash
gcloud run services list \
  --platform managed \
  --region asia-northeast1 \
  --format="table(name, status.conditions.status, status.url)"
```

**出力例:**

```
NAME       STATUS   URL
my-app     True     https://my-app-abcd1234-an.a.run.app
other-app  True     https://other-app-xyz789-an.a.run.app
```

### CI/CD 統合スクリプト例

```bash
#!/bin/bash
# CI環境での実行を想定

# サービスアカウントキーで認証
gcloud auth activate-service-account --key-file="${SERVICE_ACCOUNT_KEY}"

# プロジェクト設定
gcloud config set project "${PROJECT_ID}"

# ビルドとデプロイ
gcloud builds submit --config cloudbuild.yaml .

# デプロイ完了確認（最大5分待機）
timeout 300 bash -c 'until gcloud run services describe my-app --region asia-northeast1 --format="value(status.conditions.status)" | grep -q True; do sleep 10; done'

echo "Deployment successful!"
```

---

## 追加コンポーネントのインストール

### kubectl（Kubernetes管理ツール）

GKE や Cloud Run for Anthos を使用する場合に必要。

```bash
gcloud components install kubectl
```

### BigQuery コマンドラインツール

```bash
gcloud components install bq
```

### Cloud Datastore エミュレータ

```bash
gcloud components install cloud-datastore-emulator
```

---

## セキュリティベストプラクティス

| 項目 | 推奨事項 |
|------|---------|
| **サービスアカウント** | 最小権限の原則（必要なロールのみ付与） |
| **キーファイル管理** | Secret Manager で暗号化保存 |
| **環境分離** | 開発/本番で異なるプロジェクト使用 |
| **監査ログ** | Cloud Audit Logs で操作履歴を記録 |
| **認証方式** | 本番環境ではサービスアカウント偽装を優先 |

---

## 次のステップ

環境構築完了後、以下のリファレンスを参照:

- **CLOUDRUN-CONTAINERIZATION.md**: Dockerfile 最適化とコンテナ化
- **CLOUDRUN-DEPLOYMENT.md**: デプロイ戦略（Blue-Green/Canary）
- **CLOUDRUN-CI-CD.md**: Cloud Build による自動化パイプライン
