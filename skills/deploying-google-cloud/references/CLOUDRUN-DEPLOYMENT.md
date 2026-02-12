# デプロイ（Cloud Runへの展開戦略）

Cloud Runへのデプロイは、gcloud CLI、Cloud Console、ソースベースデプロイなど複数の方法がある。本リファレンスではデプロイ戦略の選択、トラフィック分割、ロールバック手順を含む包括的なデプロイガイドを提供する。

## デプロイ戦略

### デプロイ方式の選択

| 方式 | 特徴 | 適用場面 | メリット | デメリット |
|-----|------|---------|---------|---------|
| gcloud CLI | コマンドライン | CI/CD、自動化 | スクリプト化可能、細かい制御 | GUIなし |
| Cloud Console | Web UI | 手動デプロイ、初心者 | 視覚的、設定が簡単 | 自動化困難 |
| ソースベース | ソースコードから直接 | Dockerfileなし | Buildpack自動選択 | カスタマイズ制限 |
| Terraform | IaC | インフラコード管理 | バージョン管理可能 | 学習コスト高 |

### デプロイ戦略の種類

#### 1. 直接デプロイ

新しいリビジョンを即座に100%トラフィックに適用する。

**用途:**
- 開発環境
- 内部ツール
- 影響範囲が小さい変更

**gcloud コマンド:**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:v2.0.0 \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

#### 2. Blue-Green デプロイ

2つの環境を用意し、トラフィックを一度に切り替える。

**用途:**
- ミッションクリティカルなアプリケーション
- 大規模な変更
- 即座にロールバック可能にしたい場合

**手順:**

```bash
# Green環境をデプロイ（トラフィックは受け取らない）
gcloud run deploy my-app-green \
  --image gcr.io/my-project/my-app:v2.0.0 \
  --platform managed \
  --region us-central1 \
  --no-traffic

# 動作確認後、トラフィックを100%切り替え
gcloud run services update-traffic my-app \
  --to-revisions=my-app-green=100
```

#### 3. Canary デプロイ

新バージョンに段階的にトラフィックを移行する。

**用途:**
- 本番環境での段階的検証
- リスク最小化
- パフォーマンステストを兼ねる

**手順:**

```bash
# 新リビジョンをデプロイ（トラフィックは受け取らない）
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:v2.0.0 \
  --platform managed \
  --region us-central1 \
  --no-traffic

# 20%のトラフィックを新リビジョンに割り当て
gcloud run services update-traffic my-app \
  --to-revisions=v1=80,v2=20

# 問題なければ50%に増やす
gcloud run services update-traffic my-app \
  --to-revisions=v1=50,v2=50

# 最終的に100%に移行
gcloud run services update-traffic my-app \
  --to-revisions=v2=100
```

## gcloud CLI デプロイ

### 基本コマンド

**最小限のデプロイ:**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1
```

**全オプション指定:**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:v1.0.0 \
  --platform managed \
  --region us-central1 \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 10 \
  --min-instances 1 \
  --concurrency 80 \
  --timeout 300s \
  --set-env-vars "PORT=8080,DEBUG=false,API_ENDPOINT=https://api.example.com" \
  --vpc-connector my-vpc-connector \
  --allow-unauthenticated
```

### 主要オプション解説

| オプション | 説明 | デフォルト値 | 推奨設定 |
|----------|------|------------|---------|
| `--image` | コンテナイメージURL | 必須 | タグ付きイメージ（`:latest`避ける） |
| `--platform` | `managed` 固定 | managed | - |
| `--region` | デプロイリージョン | 必須 | ユーザーに近いリージョン |
| `--memory` | メモリ割り当て | 256Mi | 512Mi～1Gi |
| `--cpu` | CPU数 | 1 | 1（軽量）～2（高負荷） |
| `--max-instances` | 最大インスタンス数 | 100 | コスト制限に応じて設定 |
| `--min-instances` | 最小インスタンス数 | 0 | 0（コールドスタート許容）～1（常時起動） |
| `--concurrency` | 同時リクエスト数/インスタンス | 80 | 50～100（アプリ特性による） |
| `--timeout` | リクエストタイムアウト | 300s | 60s～3600s |
| `--allow-unauthenticated` | 認証なしアクセス許可 | 認証必須 | 公開APIは指定 |

### リージョン選択ガイド

| リージョン | 場所 | 用途 |
|----------|------|------|
| `us-central1` | アイオワ | 北米ユーザー |
| `us-east1` | サウスカロライナ | 北米東海岸 |
| `us-west1` | オレゴン | 北米西海岸 |
| `asia-northeast1` | 東京 | 日本ユーザー |
| `asia-northeast2` | 大阪 | 日本（東京障害時の冗長化） |
| `europe-west1` | ベルギー | 欧州ユーザー |

**マルチリージョン戦略:**

```bash
# 複数リージョンにデプロイ
for region in us-central1 asia-northeast1 europe-west1; do
  gcloud run deploy my-app \
    --image gcr.io/my-project/my-app:latest \
    --platform managed \
    --region $region \
    --allow-unauthenticated
done
```

## Cloud Console デプロイ

### 手順

1. **Cloud Console にアクセス**
   - https://console.cloud.google.com/
   - プロジェクトを選択

2. **Cloud Run ページに移動**
   - ナビゲーションメニュー → Cloud Run

3. **サービス作成**
   - 「サービスを作成」ボタンをクリック

4. **コンテナイメージの指定**
   - コンテナイメージURL: `gcr.io/my-project/my-app:latest`
   - または「コンテナイメージを選択」からレジストリを参照

5. **サービス設定**
   - サービス名: `my-app`
   - リージョン: `us-central1`

6. **リソース設定**
   - メモリ: 512 MiB
   - CPU: 1
   - 同時実行リクエスト数: 80

7. **環境変数設定**
   - `PORT=8080`
   - `DEBUG=false`
   - `API_ENDPOINT=https://api.example.com`

8. **ネットワーク設定**
   - 認証: 未認証の呼び出しを許可

9. **デプロイ実行**
   - 「作成」ボタンをクリック

### GUI のメリット・デメリット

| メリット | デメリット |
|---------|----------|
| 視覚的で理解しやすい | 自動化困難 |
| 設定ミスが少ない | 大量のサービスには不向き |
| 初心者に優しい | バージョン管理できない |

## ソースベースデプロイ（Buildpack）

Dockerfileなしでソースコードから直接デプロイする。

### 対応言語

| 言語 | Buildpack | デプロイコマンド |
|-----|-----------|----------------|
| Node.js | Google Cloud Buildpacks | `gcloud run deploy --source .` |
| Python | Google Cloud Buildpacks | `gcloud run deploy --source .` |
| Go | Google Cloud Buildpacks | `gcloud run deploy --source .` |
| Java | Google Cloud Buildpacks | `gcloud run deploy --source .` |

### デプロイ手順

```bash
# ソースコードのディレクトリに移動
cd my-app/

# ソースベースデプロイ
gcloud run deploy my-app \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

**実行内容:**

1. Cloud Buildがソースコードを検出
2. 言語に応じたBuildpackを自動選択
3. コンテナイメージをビルド
4. Artifact Registryにプッシュ
5. Cloud Runにデプロイ

### Buildpack のカスタマイズ

**プロジェクト.toml で設定:**

```toml
[build]
builder = "gcr.io/buildpacks/builder:v1"

[[build.env]]
name = "GOOGLE_RUNTIME_VERSION"
value = "3.9"

[[build.env]]
name = "GOOGLE_ENTRYPOINT"
value = "python app.py"
```

## 環境変数・シークレット設定

### 環境変数の設定

**デプロイ時に指定:**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --set-env-vars "PORT=8080,DEBUG=false,API_ENDPOINT=https://api.example.com"
```

**既存サービスの更新:**

```bash
gcloud run services update my-app \
  --set-env-vars "NEW_VAR=value"
```

**環境変数の削除:**

```bash
gcloud run services update my-app \
  --remove-env-vars "OLD_VAR"
```

### Secret Manager 連携

**シークレットの作成:**

```bash
# シークレット作成
echo -n "mysecretpassword" | gcloud secrets create db-password --data-file=-

# シークレットの確認
gcloud secrets versions access latest --secret=db-password
```

**Cloud Run にシークレットをマウント:**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --update-secrets "DATABASE_PASSWORD=db-password:latest"
```

**複数シークレットの設定:**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --update-secrets "DATABASE_PASSWORD=db-password:latest,API_KEY=api-key:latest"
```

**アプリケーションでの読み取り:**

```python
import os

# 環境変数として読み取り可能
database_password = os.environ.get('DATABASE_PASSWORD')
api_key = os.environ.get('API_KEY')
```

## Traffic Splitting（トラフィック分割）

### トラフィック割り当て

**リビジョン一覧確認:**

```bash
gcloud run revisions list --service my-app --region us-central1
```

**トラフィック分割設定:**

```bash
# 80:20 の分割
gcloud run services update-traffic my-app \
  --to-revisions=v1=80,v2=20

# 複数リビジョンへの分割
gcloud run services update-traffic my-app \
  --to-revisions=v1=50,v2=30,v3=20
```

### Canary デプロイの実践例

**ステップ1: 新リビジョンをデプロイ（トラフィックなし）**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:v2.0.0 \
  --no-traffic
```

**ステップ2: 10%のトラフィックを割り当て**

```bash
gcloud run services update-traffic my-app \
  --to-revisions=v1=90,v2=10
```

**ステップ3: メトリクスを監視**

```bash
# エラーレート確認
gcloud logging read "resource.type=cloud_run_revision AND severity=ERROR" --limit 50
```

**ステップ4: 段階的に増やす**

```bash
# 50%に増やす
gcloud run services update-traffic my-app \
  --to-revisions=v1=50,v2=50

# 問題なければ100%に
gcloud run services update-traffic my-app \
  --to-revisions=v2=100
```

### Blue-Green デプロイの実践例

**現在の状態（Blue）:**
- サービス: `my-app`
- リビジョン: `v1`（トラフィック100%）

**ステップ1: Green環境をデプロイ**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:v2.0.0 \
  --no-traffic
```

**ステップ2: 動作確認（専用URLでテスト）**

```bash
# 新リビジョンのURLを確認
gcloud run revisions describe v2 --region us-central1 --format="value(status.url)"

# curlでテスト
curl https://v2---my-app-xyz-uc.a.run.app
```

**ステップ3: トラフィックを一括切り替え**

```bash
gcloud run services update-traffic my-app \
  --to-revisions=v2=100
```

**ステップ4: 問題発生時はロールバック**

```bash
gcloud run services update-traffic my-app \
  --to-revisions=v1=100
```

## ロールバック手順

### 即座にロールバック

**前のリビジョンに100%戻す:**

```bash
gcloud run services update-traffic my-app \
  --to-revisions=v1=100
```

### 段階的ロールバック

**80%を旧バージョンに戻す:**

```bash
gcloud run services update-traffic my-app \
  --to-revisions=v1=80,v2=20
```

### 特定のリビジョンを指定

**リビジョンIDを指定:**

```bash
# リビジョンIDを確認
gcloud run revisions list --service my-app --region us-central1

# 特定のリビジョンにロールバック
gcloud run services update-traffic my-app \
  --to-revisions=my-app-00001-abc=100
```

### イメージダイジェストでのロールバック

**正確なイメージバージョンにロールバック:**

```bash
# イメージダイジェストを確認
docker inspect --format='{{index .RepoDigests 0}}' gcr.io/my-project/my-app:v1.0.0

# ダイジェストを指定してデプロイ
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app@sha256:abc123... \
  --region us-central1
```

## Revision 管理

### リビジョン一覧

```bash
# リビジョン一覧（デフォルト: 最新10件）
gcloud run revisions list --service my-app --region us-central1

# 全リビジョン表示
gcloud run revisions list --service my-app --region us-central1 --limit=999
```

### リビジョン詳細確認

```bash
gcloud run revisions describe my-app-00001-abc \
  --region us-central1
```

### 古いリビジョンの削除

```bash
# 特定リビジョンを削除
gcloud run revisions delete my-app-00001-abc --region us-central1

# トラフィックを受けていないリビジョンを一括削除
gcloud run revisions list --service my-app --region us-central1 --format="value(metadata.name)" | \
  while read revision; do
    traffic=$(gcloud run services describe my-app --region us-central1 --format="value(status.traffic[?revisionName=='$revision'].percent)")
    if [ -z "$traffic" ]; then
      echo "Deleting unused revision: $revision"
      gcloud run revisions delete $revision --region us-central1 --quiet
    fi
  done
```

## デプロイ自動化スクリプト

### シンプルなデプロイスクリプト

**deploy.sh:**

```bash
#!/bin/bash
set -e

PROJECT_ID="my-project"
SERVICE_NAME="my-app"
REGION="us-central1"
IMAGE_TAG=$(git rev-parse --short HEAD)

# イメージビルド
docker build -t gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG .

# イメージプッシュ
docker push gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG

# Cloud Runにデプロイ
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG \
  --platform managed \
  --region $REGION \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 10 \
  --set-env-vars "PORT=8080,DEBUG=false" \
  --allow-unauthenticated

echo "Deployment completed: gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG"
```

### Canaryデプロイスクリプト

**canary-deploy.sh:**

```bash
#!/bin/bash
set -e

SERVICE_NAME="my-app"
REGION="us-central1"
NEW_REVISION=$1
CANARY_PERCENT=${2:-20}

if [ -z "$NEW_REVISION" ]; then
  echo "Usage: $0 <new-revision> [canary-percent]"
  exit 1
fi

# 現在のリビジョンを取得
CURRENT_REVISION=$(gcloud run services describe $SERVICE_NAME --region $REGION --format="value(status.traffic[0].revisionName)")

echo "Current revision: $CURRENT_REVISION"
echo "New revision: $NEW_REVISION"
echo "Canary percent: $CANARY_PERCENT"

# Canaryトラフィック割り当て
STABLE_PERCENT=$((100 - CANARY_PERCENT))
gcloud run services update-traffic $SERVICE_NAME \
  --to-revisions=$CURRENT_REVISION=$STABLE_PERCENT,$NEW_REVISION=$CANARY_PERCENT

echo "Canary deployment complete. Monitor metrics and run:"
echo "  gcloud run services update-traffic $SERVICE_NAME --to-revisions=$NEW_REVISION=100"
echo "to complete the rollout, or:"
echo "  gcloud run services update-traffic $SERVICE_NAME --to-revisions=$CURRENT_REVISION=100"
echo "to rollback."
```

## トラブルシューティング

### デプロイが失敗する

**エラー確認:**

```bash
# デプロイログを確認
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=my-app" --limit 50
```

**よくある原因:**

| エラー | 原因 | 対処方法 |
|-------|------|---------|
| "Container failed to start" | PORTをリッスンしていない | 環境変数 `PORT` を読み取る実装を追加 |
| "Permission denied" | IAMロールが不足 | Cloud Run Admin ロールを付与 |
| "Image not found" | イメージが存在しない | イメージURLを確認、pushを実行 |
| "Quota exceeded" | リソース制限超過 | 割り当てを増やす申請 |

### リビジョンが表示されない

**原因:**
- デプロイが完了していない
- リージョンが間違っている

**確認コマンド:**

```bash
# 全リージョンのサービスを確認
gcloud run services list --platform managed
```

### トラフィック分割が反映されない

**確認コマンド:**

```bash
# 現在のトラフィック設定を確認
gcloud run services describe my-app --region us-central1 --format="value(status.traffic)"
```

**DNS伝播待ち:**
- トラフィック分割の反映には数秒～数十秒かかる
- `curl` で複数回リクエストして確認

```bash
for i in {1..10}; do
  curl -s https://my-app-xyz-uc.a.run.app | grep "version"
done
```
