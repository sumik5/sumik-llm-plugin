# サーバーレスアーキテクチャパターン

## 概要

このドキュメントでは、サーバーレスアーキテクチャの基本原則と設計パターンについて解説する。AWSのサーバーレスサービス（Lambda、API Gateway、S3、DynamoDB、Aurora Serverless等）を活用した実践的なアーキテクチャパターンを紹介する。

---

## サーバーレスコンピューティングの基本原則

### サーバーレスとは

サーバーレスコンピューティングは、開発者がインフラ管理の負担なくコードの記述に集中できるクラウド実行モデルである。「サーバーレス」という名称ではあるが、実際にはサーバーが存在しないわけではなく、クラウドプロバイダーがインフラ管理を抽象化している。

**主な特徴:**
- インフラ管理不要: プロビジョニング、スケーリング、メンテナンスをプロバイダーが担当
- イベント駆動: イベント発生時のみ実行され、リソースを効率的に利用
- 従量課金: 実行時間とリソース消費量に基づく料金体系
- 自動スケーリング: 需要に応じて自動的にスケール

### サーバーレスのメリット

| メリット | 説明 | 効果 |
|---------|------|------|
| **サーバー管理不要** | プロビジョニング・保守作業の排除 | 開発者はビジネスロジックに集中可能 |
| **弾力的スケーリング** | 需要に応じた自動スケール（0〜数千並列実行） | 過剰プロビジョニングとアイドルコストを排除 |
| **コスト効率** | 実行時間のみ課金（アイドル時は無料） | 最大60%のインフラコスト削減が可能 |
| **市場投入の加速** | 迅速なプロトタイピングとデプロイ | 開発サイクルの短縮 |
| **高可用性** | デフォルトでHA構成 | プロバイダーがインフラの可用性を保証 |
| **マイクロサービス親和性** | 疎結合な関数単位のデプロイ | 独立したスケーリングと開発が可能 |

**コスト削減の実例:**
- スパイキーなワークロード（e-コマース、ゲーム、メディアストリーミング）で特に効果的
- 季節変動の大きいビジネス（税務、教育）での大幅なコスト削減
- 予測不可能なトラフィックパターンへの対応

### サーバーレスの課題と対策

#### 1. コールドスタート

**課題:**
非アクティブ期間後の最初の実行時に初期化遅延が発生する（数百ms〜数秒）。

**対策:**

| 対策 | 実装方法 | 適用場面 |
|------|---------|---------|
| **Provisioned Concurrency** | 事前にウォームな実行環境を保持 | レイテンシ重視のプロダクション環境 |
| **コード最適化** | 依存関係の削減、パッケージサイズの縮小 | すべての関数で実施 |
| **定期的なウォームアップ** | CloudWatch EventsやStep Functionsで定期実行 | 低コストでレイテンシを改善 |
| **SnapStart (Java)** | 初期化済みスナップショットから起動 | Javaランタイムでコールドスタート90%削減 |

**Provisioned Concurrency設定例:**
```bash
aws lambda put-provisioned-concurrency-config \
  --function-name my-function \
  --provisioned-concurrent-executions 10
```

#### 2. ベンダーロックイン

**課題:**
特定クラウドプロバイダーの独自サービスへの依存。

**対策:**

| 戦略 | 実装アプローチ | メリット |
|------|--------------|---------|
| **マルチクラウド戦略** | Kubernetes (Knative)、Terraform、OpenTelemetry活用 | プロバイダー間の移植性向上 |
| **OSSフレームワーク** | OpenFaaS、Serverless Framework | プラットフォーム非依存の実装 |
| **モジュラー設計** | ビジネスロジックとクラウド固有機能の分離 | 移行の容易性確保 |

#### 3. 制御の制約

**課題:**
インフラ詳細（セキュリティ、ネットワーク、ストレージ）への細かい制御が制限される。

**判断基準:**
- **サーバーレス適合**: Webアプリ、API、バッチ処理、イベント駆動処理
- **従来型が適合**: 長時間実行タスク、細かいインフラ制御が必要な場合

---

## サーバーレスの使用パターン

### 1. イベント駆動・トリガーベース

イベント発生時にのみリソースを消費し、タスク完了後はリソースを解放する。

**典型的なトリガー:**
- S3オブジェクト操作（アップロード、削除、変更）
- DynamoDBストリーム（レコード変更）
- API Gatewayリクエスト
- SQS/SNSメッセージ
- CloudWatch Events（スケジュール実行）

**実装例（S3トリガー）:**
```python
import json
import boto3

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    # S3イベントからバケット名とオブジェクトキーを取得
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    # オブジェクト情報を取得
    response = s3_client.get_object(Bucket=bucket, Key=key)
    content = response['Body'].read().decode('utf-8')

    # 処理ロジック（例: 画像のリサイズ、ログの解析等）
    result = process_content(content)

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Processing complete', 'result': result})
    }

def process_content(content):
    # 実際の処理ロジック
    return f"Processed {len(content)} bytes"
```

### 2. API構築

REST API、GraphQL API、WebSocket APIの構築に最適。

**API Gatewayパターン:**
- **REST API**: 従来型のHTTP APIエンドポイント
- **HTTP API**: 低レイテンシ・低コストの軽量REST API
- **WebSocket API**: 双方向リアルタイム通信

**判断基準テーブル:**

| 要件 | REST API | HTTP API | WebSocket API |
|------|----------|----------|---------------|
| **認証** | Cognito、Lambda Authorizer、IAM | JWT、IAM | Cognito、Lambda Authorizer |
| **レイテンシ** | 標準 | 低レイテンシ（最大60%削減） | リアルタイム |
| **料金** | 標準 | 最大70%安価 | 接続時間ベース |
| **キャッシュ** | ✓ | ✗ | ✗ |
| **変換** | リクエスト/レスポンス変換可 | 基本的な変換のみ | 基本的な変換のみ |
| **用途** | フル機能API | シンプルなAPI、マイクロサービス | チャット、リアルタイムダッシュボード |

**REST API実装例:**
```python
import json

def lambda_handler(event, context):
    # HTTPメソッドに応じた処理
    http_method = event['httpMethod']
    path = event['path']

    if http_method == 'GET' and path == '/users':
        return get_users()
    elif http_method == 'POST' and path == '/users':
        body = json.loads(event['body'])
        return create_user(body)
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'Not Found'})
        }

def get_users():
    # ユーザー一覧取得ロジック
    users = [{'id': 1, 'name': 'Alice'}, {'id': 2, 'name': 'Bob'}]
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(users)
    }

def create_user(user_data):
    # ユーザー作成ロジック
    return {
        'statusCode': 201,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'id': 3, **user_data})
    }
```

### 3. 非同期タスク処理

バックグラウンド処理、バッチジョブ、データ変換等。

**典型的なユースケース:**
- メール送信・通知配信
- 画像・動画のトランスコーディング
- ログ解析・集計
- ETL処理

**SQSとLambda連携例:**
```python
import json
import boto3

ses_client = boto3.client('ses')

def lambda_handler(event, context):
    # SQSメッセージをバッチ処理
    for record in event['Records']:
        message = json.loads(record['body'])
        send_email(message)

    return {'statusCode': 200}

def send_email(message):
    ses_client.send_email(
        Source='noreply@example.com',
        Destination={'ToAddresses': [message['to']]},
        Message={
            'Subject': {'Data': message['subject']},
            'Body': {'Text': {'Data': message['body']}}
        }
    )
```

### 4. メッセージオーケストレーション

**サービス選択ガイド:**

| サービス | 特性 | 用途 |
|---------|------|------|
| **SQS** | キュー、FIFO/Standard、デカップリング | 非同期処理、ワークロード平準化 |
| **SNS** | Pub/Sub、ファンアウト | 複数サブスクライバーへの通知 |
| **EventBridge** | イベントバス、ルール、スキーマ | イベント駆動アーキテクチャ、SaaS統合 |
| **Step Functions** | ワークフローオーケストレーション | 複雑な状態遷移、長時間実行 |

**EventBridgeパターン例:**
```json
{
  "source": "com.myapp.orders",
  "detail-type": "Order Placed",
  "detail": {
    "orderId": "12345",
    "amount": 99.99,
    "customerId": "cust-001"
  }
}
```

**対応するEventBridgeルール:**
```json
{
  "EventPattern": {
    "source": ["com.myapp.orders"],
    "detail-type": ["Order Placed"],
    "detail": {
      "amount": [{"numeric": [">=", 100]}]
    }
  },
  "Targets": [
    {
      "Arn": "arn:aws:lambda:region:account:function:process-large-order",
      "Id": "1"
    }
  ]
}
```

### 5. ストレージ・アーカイブ

**S3イベント駆動パターン:**
- オブジェクト作成時の自動処理（サムネイル生成、メタデータ抽出）
- ライフサイクル管理（Glacier移行、削除）
- クロスリージョンレプリケーション
- 静的Webサイトホスティング

**S3ライフサイクルポリシー例:**
```json
{
  "Rules": [
    {
      "Id": "Archive old logs",
      "Status": "Enabled",
      "Filter": {"Prefix": "logs/"},
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 365
      }
    }
  ]
}
```

### 6. Webホスティング・UI

**静的サイトホスティングパターン:**
- S3 + CloudFront + Lambda@Edge
- 低レイテンシ、高可用性、グローバル配信
- 動的コンテンツ生成（Lambda@Edge）

**Lambda@Edge用途:**
- URL書き換え・リダイレクト
- A/Bテスト
- 認証・認可
- レスポンスヘッダー追加

---

## AWS Lambda深掘り

### Function as a Service (FaaS)

**FaaSの原則:**
- **イベント駆動**: トリガーに応答して実行
- **コード中心**: インフラではなくビジネスロジックに集中
- **短時間実行**: 短命な関数（AWS Lambdaは最大15分）
- **自動スケーリング**: 需要に応じた並列実行
- **従量課金**: 実行時間とメモリ使用量のみ課金

### AWS Lambda vs 従来型サーバー

| 項目 | AWS Lambda (FaaS) | 従来型サーバー |
|------|------------------|---------------|
| **インフラ管理** | プロバイダーが完全管理 | 手動プロビジョニング・保守 |
| **スケーラビリティ** | 自動スケール（0〜数千並列） | ロードバランサー・手動スケール |
| **コスト** | 実行時のみ課金 | 常時稼働コスト |
| **実行時間制限** | 最大15分 | 制限なし |
| **イベント駆動** | ネイティブサポート | 追加実装が必要 |
| **複雑性** | シンプル | フルスタックセットアップ |
| **セキュリティ** | パッチ・更新は自動 | 手動パッチ適用 |

### Lambda主要用語

#### 1. トリガー (Triggers)

Lambda関数を起動するイベントまたはメッセージ。

**主要トリガーソース:**
- **API Gateway**: HTTP/REST/WebSocket リクエスト
- **S3**: オブジェクト作成・削除・変更
- **DynamoDB Streams**: テーブル変更
- **SQS**: キューメッセージ
- **SNS**: トピック通知
- **CloudWatch Events**: スケジュール・カスタムイベント
- **Kinesis**: ストリームレコード
- **ALB**: Application Load Balancer リクエスト

#### 2. イベントソース (Event Sources)

Lambda関数を起動できるAWSサービス。

**呼び出しモデル:**
- **同期 (Synchronous)**: レスポンスを待機（API Gateway、ALB）
- **非同期 (Asynchronous)**: 実行結果を待たない（S3、SNS）
- **ポーリング (Poll-based)**: Lambdaがソースをポーリング（SQS、Kinesis、DynamoDB Streams）

#### 3. Lambda ARN

AWS Lambdaの一意識別子。

**フォーマット:**
```
arn:aws:lambda:<region>:<account_id>:function:<function_name>[:version]
```

**例:**
```
arn:aws:lambda:us-west-2:123456789012:function:my-function:1
```

#### 4. ハンドラー (Handler)

すべての受信イベントを受け取るマスター関数。

**Pythonハンドラー例:**
```python
def lambda_handler(event, context):
    """
    event: イベントデータ（dict）
    context: ランタイム情報（LambdaContext object）
    """
    # イベント処理ロジック
    return {
        'statusCode': 200,
        'body': 'Success'
    }
```

**Node.jsハンドラー例:**
```javascript
exports.handler = async (event, context) => {
    // イベント処理ロジック
    return {
        statusCode: 200,
        body: JSON.stringify('Success')
    };
};
```

#### 5. ランタイム (Runtime)

プログラミング言語とLambda実行環境を橋渡しするインタプリタ。

**サポート言語:**
- Python 3.8+
- Node.js 18.x, 20.x
- Java 11, 17, 21
- .NET 6, 8
- Go 1.x
- Ruby 3.2+
- カスタムランタイム（Rust、PHP等）

#### 6. アーキテクチャ (Architecture)

Lambda関数が実行されるプロセッサ命令セット。

**選択肢:**
- **x86_64**: 汎用、既存依存関係との互換性
- **arm64 (Graviton2)**: x86_64比で最大34%優れたパフォーマンス/コスト比

**選択基準:**
| 要件 | x86_64 | arm64 (Graviton2) |
|------|--------|-------------------|
| **既存依存関係** | ✓ | 互換性確認必要 |
| **コスト最適化** | - | ✓ 最大20%低コスト |
| **パフォーマンス** | - | ✓ 最大34%高速 |

### Lambda設定パラメータ

#### 1. メモリ設定

**範囲**: 128MB 〜 10,240MB（1MB刻み）

**影響:**
- CPU性能もメモリに比例して割り当て
- ネットワーク帯域もメモリに比例
- 料金はメモリ×実行時間で計算

**最適化戦略:**
- AWS Lambda Power Tuningを使用
- コスト/パフォーマンスのバランスを測定

**Power Tuning使用例:**
```bash
# AWS Lambda Power Tuningツールをデプロイ
sam deploy --template-file template.yml --stack-name lambda-power-tuning

# 特定関数を分析
aws lambda invoke \
  --function-name lambda-power-tuning \
  --payload '{"lambdaARN": "arn:aws:lambda:..."}' \
  output.json
```

#### 2. タイムアウト設定

**範囲**: 1秒 〜 15分（900秒）

**選択基準:**
| ワークロード | 推奨タイムアウト | 理由 |
|-------------|--------------|------|
| **API処理** | 3〜30秒 | ユーザー体験維持 |
| **バッチ処理** | 5〜15分 | データ量に応じて設定 |
| **ストリーム処理** | 1〜5分 | バッチサイズ・処理時間のバランス |

#### 3. 環境変数

設定情報をコードから分離。

**ベストプラクティス:**
```python
import os
import boto3

# 環境変数取得
DB_HOST = os.environ['DB_HOST']
DB_NAME = os.environ['DB_NAME']

# 機密情報はSSM Parameter StoreまたはSecrets Managerから取得
ssm_client = boto3.client('ssm')
db_password = ssm_client.get_parameter(
    Name='/myapp/db/password',
    WithDecryption=True
)['Parameter']['Value']
```

#### 4. VPC統合

プライベートリソース（RDS、ElastiCache等）へのアクセス。

**設定例:**
```yaml
# SAMテンプレート
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: index.handler
      Runtime: python3.11
      VpcConfig:
        SecurityGroupIds:
          - sg-0123456789abcdef0
        SubnetIds:
          - subnet-0123456789abcdef0
          - subnet-0123456789abcdef1
```

**注意点:**
- VPC統合時はENI作成によりコールドスタート遅延が発生
- Hyperplane ENIアーキテクチャ（2019年以降）で大幅に改善
- NAT GatewayまたはVPC Endpointsが必要（外部通信時）

#### 5. Lambda Layers

共通コード・ライブラリの再利用。

**用途:**
- 共通ライブラリ（boto3、requests等）
- カスタムランタイム
- 設定ファイル

**Layer作成例:**
```bash
# ディレクトリ構造
# python/lib/python3.11/site-packages/my_library/

# ZIPアーカイブ作成
cd python
zip -r ../my-layer.zip .

# Layer公開
aws lambda publish-layer-version \
  --layer-name my-common-libs \
  --zip-file fileb://../my-layer.zip \
  --compatible-runtimes python3.11
```

**関数にLayer追加:**
```python
# Lambda関数でLayerライブラリを使用
from my_library import utils

def lambda_handler(event, context):
    result = utils.process_data(event['data'])
    return {'statusCode': 200, 'body': result}
```

---

## API Gateway

### API Gatewayタイプ比較

| 項目 | REST API | HTTP API | WebSocket API |
|------|----------|----------|---------------|
| **プロトコル** | HTTP/HTTPS | HTTP/HTTPS | WebSocket |
| **認証** | IAM、Cognito、Lambda Authorizer、APIキー | IAM、JWT、Lambda Authorizer | IAM、Lambda Authorizer |
| **スロットリング** | ✓ | ✓ | ✓ |
| **キャッシュ** | ✓ | ✗ | ✗ |
| **リクエスト変換** | ✓ VTL使用可 | ✗ | ✗ |
| **コスト** | $3.50/百万リクエスト | $1.00/百万リクエスト（約70%安） | $1.00/百万メッセージ + 接続時間 |
| **レイテンシ** | 標準 | 最大60%低レイテンシ | リアルタイム |
| **用途** | フル機能REST API | 軽量API、マイクロサービス | チャット、ダッシュボード、ゲーム |

### REST API設計パターン

#### 1. Lambda統合

**プロキシ統合 vs カスタム統合:**

| 統合タイプ | メリット | デメリット | 用途 |
|-----------|---------|----------|------|
| **Lambda プロキシ統合** | シンプル、Lambda側で全制御 | API Gatewayの機能（変換、検証）未利用 | 迅速な開発、柔軟な処理 |
| **Lambda カスタム統合** | リクエスト/レスポンス変換可能 | VTL設定が複雑 | レガシーシステム統合 |

**プロキシ統合例:**
```python
def lambda_handler(event, context):
    # API Gatewayプロキシ統合フォーマット
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({'message': 'Success'})
    }
```

#### 2. 認証・認可

**Cognito User Pools認証:**
```yaml
# SAMテンプレート
Resources:
  MyApi:
    Type: AWS::Serverless::Api
    Properties:
      StageName: prod
      Auth:
        DefaultAuthorizer: MyCognitoAuthorizer
        Authorizers:
          MyCognitoAuthorizer:
            UserPoolArn: !GetAtt MyCognitoUserPool.Arn
```

**Lambda Authorizer（カスタム認証）:**
```python
def lambda_handler(event, context):
    # トークン検証ロジック
    token = event['authorizationToken']

    if validate_token(token):
        return generate_policy('user', 'Allow', event['methodArn'])
    else:
        return generate_policy('user', 'Deny', event['methodArn'])

def generate_policy(principal_id, effect, resource):
    return {
        'principalId': principal_id,
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [{
                'Action': 'execute-api:Invoke',
                'Effect': effect,
                'Resource': resource
            }]
        }
    }
```

#### 3. スロットリング・レート制限

**設定レベル:**
- アカウントレベル（デフォルト: 10,000 rps）
- ステージレベル
- メソッドレベル
- 使用量プラン（APIキー）

**使用量プラン設定例:**
```yaml
Resources:
  MyUsagePlan:
    Type: AWS::ApiGateway::UsagePlan
    Properties:
      UsagePlanName: Basic
      Throttle:
        RateLimit: 100  # 毎秒100リクエスト
        BurstLimit: 200  # バースト200リクエスト
      Quota:
        Limit: 10000  # 1日10,000リクエスト
        Period: DAY
```

#### 4. キャッシュ

**設定例:**
```yaml
Resources:
  MyApi:
    Type: AWS::Serverless::Api
    Properties:
      StageName: prod
      CacheClusterEnabled: true
      CacheClusterSize: '0.5'  # 0.5GB〜237GB
      MethodSettings:
        - ResourcePath: /users
          HttpMethod: GET
          CachingEnabled: true
          CacheTtlInSeconds: 300
```

**キャッシュ無効化（クライアント側）:**
```bash
curl -H "Cache-Control: max-age=0" https://api.example.com/users
```

### HTTP API設計パターン

**選択理由:**
- コスト削減（REST APIの約30%）
- 低レイテンシ（最大60%削減）
- シンプルなユースケース

**JWT認証設定:**
```yaml
Resources:
  MyHttpApi:
    Type: AWS::Serverless::HttpApi
    Properties:
      Auth:
        Authorizers:
          MyJwtAuthorizer:
            IdentitySource: $request.header.Authorization
            JwtConfiguration:
              Issuer: https://cognito-idp.region.amazonaws.com/userpool-id
              Audience:
                - my-app-client-id
```

### WebSocket API設計パターン

**接続管理:**
```python
import boto3

apigateway_management = boto3.client(
    'apigatewaymanagementapi',
    endpoint_url='https://<api-id>.execute-api.<region>.amazonaws.com/<stage>'
)

def lambda_handler(event, context):
    connection_id = event['requestContext']['connectionId']
    route_key = event['requestContext']['routeKey']

    if route_key == '$connect':
        # 接続時の処理（認証等）
        return {'statusCode': 200}

    elif route_key == '$disconnect':
        # 切断時の処理（クリーンアップ等）
        return {'statusCode': 200}

    elif route_key == 'sendMessage':
        # メッセージ送信
        message = json.loads(event['body'])
        broadcast_message(message)
        return {'statusCode': 200}

def broadcast_message(message):
    # すべての接続にブロードキャスト
    connections = get_all_connections()  # DynamoDBから取得

    for connection_id in connections:
        try:
            apigateway_management.post_to_connection(
                ConnectionId=connection_id,
                Data=json.dumps(message).encode('utf-8')
            )
        except apigateway_management.exceptions.GoneException:
            # 接続が無効な場合は削除
            remove_connection(connection_id)
```

---

## S3とサーバーレス

### S3イベント通知

**サポートイベント:**
- `s3:ObjectCreated:*`: オブジェクト作成
- `s3:ObjectRemoved:*`: オブジェクト削除
- `s3:ObjectRestore:*`: Glacier復元
- `s3:Replication:*`: レプリケーション

**Lambda統合例:**
```yaml
Resources:
  MyBucket:
    Type: AWS::S3::Bucket
    Properties:
      NotificationConfiguration:
        LambdaConfigurations:
          - Event: s3:ObjectCreated:*
            Function: !GetAtt ImageProcessingFunction.Arn
            Filter:
              S3Key:
                Rules:
                  - Name: prefix
                    Value: uploads/
                  - Name: suffix
                    Value: .jpg
```

### 署名付きURL

一時的なアクセス権を付与。

**生成例（Python）:**
```python
import boto3
from botocore.client import Config

s3_client = boto3.client(
    's3',
    config=Config(signature_version='s3v4'),
    region_name='us-west-2'
)

# アップロード用署名付きURL
presigned_url = s3_client.generate_presigned_url(
    'put_object',
    Params={'Bucket': 'my-bucket', 'Key': 'file.txt'},
    ExpiresIn=3600  # 1時間有効
)

# ダウンロード用署名付きURL
download_url = s3_client.generate_presigned_url(
    'get_object',
    Params={'Bucket': 'my-bucket', 'Key': 'file.txt'},
    ExpiresIn=300  # 5分有効
)
```

### クロスリージョンレプリケーション (CRR)

**用途:**
- ディザスタリカバリ
- レイテンシ削減（地理的分散）
- コンプライアンス要件

**設定例:**
```json
{
  "Role": "arn:aws:iam::account-id:role/replication-role",
  "Rules": [
    {
      "Status": "Enabled",
      "Priority": 1,
      "Filter": {"Prefix": "important/"},
      "Destination": {
        "Bucket": "arn:aws:s3:::destination-bucket",
        "ReplicationTime": {
          "Status": "Enabled",
          "Time": {"Minutes": 15}
        },
        "Metrics": {
          "Status": "Enabled",
          "EventThreshold": {"Minutes": 15}
        }
      }
    }
  ]
}
```

---

## DynamoDB

### テーブル設計原則

**Single Table Design:**
- アクセスパターンを事前に定義
- パーティションキーとソートキーで多様なクエリをサポート
- GSI/LSIで追加のアクセスパターンに対応

**パーティションキー選択基準:**

| 要件 | 良い設計 | 悪い設計 |
|------|---------|---------|
| **カーディナリティ** | 高（多様な値） | 低（少数の値） |
| **アクセス分散** | 均等分散 | 特定キーに集中 |
| **例** | `userId`, `orderId` | `status`, `category` |

**設計例（Eコマース）:**
```
PK: USER#<userId>        SK: PROFILE#<userId>
PK: USER#<userId>        SK: ORDER#<timestamp>#<orderId>
PK: ORDER#<orderId>      SK: METADATA
PK: ORDER#<orderId>      SK: ITEM#<itemId>
```

### DynamoDB Streams

テーブル変更をリアルタイムにキャプチャ。

**用途:**
- マテリアライズドビュー更新
- 監査ログ
- クロスリージョン同期
- イベント駆動ワークフロー

**Lambda統合例:**
```python
def lambda_handler(event, context):
    for record in event['Records']:
        event_name = record['eventName']  # INSERT, MODIFY, REMOVE

        if event_name == 'INSERT':
            new_image = record['dynamodb']['NewImage']
            handle_new_record(new_image)

        elif event_name == 'MODIFY':
            old_image = record['dynamodb']['OldImage']
            new_image = record['dynamodb']['NewImage']
            handle_update(old_image, new_image)

        elif event_name == 'REMOVE':
            old_image = record['dynamodb']['OldImage']
            handle_delete(old_image)
```

### Global Secondary Index (GSI) vs Local Secondary Index (LSI)

| 項目 | GSI | LSI |
|------|-----|-----|
| **パーティションキー** | 異なるキー可 | ベーステーブルと同じ |
| **ソートキー** | 任意 | 異なるキー必須 |
| **作成タイミング** | いつでも | テーブル作成時のみ |
| **スループット** | 独立して設定 | ベーステーブルと共有 |
| **最大数** | 20個 | 5個 |
| **結果整合性** | 結果整合性のみ | 結果整合性/強整合性 |

**GSI設計例:**
```yaml
Resources:
  MyTable:
    Type: AWS::DynamoDB::Table
    Properties:
      AttributeDefinitions:
        - AttributeName: userId
          AttributeType: S
        - AttributeName: email
          AttributeType: S
      KeySchema:
        - AttributeName: userId
          KeyType: HASH
      GlobalSecondaryIndexes:
        - IndexName: EmailIndex
          KeySchema:
            - AttributeName: email
              KeyType: HASH
          Projection:
            ProjectionType: ALL
          ProvisionedThroughput:
            ReadCapacityUnits: 5
            WriteCapacityUnits: 5
```

### On-Demand vs Provisioned

| 項目 | On-Demand | Provisioned |
|------|-----------|-------------|
| **料金モデル** | リクエスト単位 | 時間単位（予約容量） |
| **スケーリング** | 自動（無制限） | 手動またはAuto Scaling |
| **予測可能性** | 不要 | 必要 |
| **コスト** | 可変ワークロードで有利 | 安定ワークロードで有利 |
| **用途** | スパイキーなトラフィック、新規アプリ | 予測可能なトラフィック |

---

## Aurora Serverless

### Aurora Serverless v2

**特徴:**
- 0.5 ACU〜128 ACU（ACU = Aurora Capacity Unit）
- ミリ秒単位でのスケーリング
- 従来のv1より最大90%高速なスケーリング

**判断基準:**

| ワークロード | Aurora Serverless v2 | Aurora Provisioned |
|-------------|---------------------|-------------------|
| **可変負荷** | ✓ 最適 | - |
| **開発/テスト環境** | ✓ 最適 | - |
| **予測可能な負荷** | - | ✓ コスト効率的 |
| **高負荷維持** | - | ✓ コスト効率的 |

### Data API

HTTP経由でSQLを実行（接続プール不要）。

**使用例:**
```python
import boto3

rds_data = boto3.client('rds-data')

response = rds_data.execute_statement(
    resourceArn='arn:aws:rds:region:account:cluster:my-cluster',
    secretArn='arn:aws:secretsmanager:region:account:secret:my-secret',
    database='mydb',
    sql='SELECT * FROM users WHERE email = :email',
    parameters=[
        {'name': 'email', 'value': {'stringValue': 'user@example.com'}}
    ]
)

records = response['records']
```

**メリット:**
- 接続管理不要
- Lambdaとの相性良好（接続プール問題解消）
- Secrets Manager統合

### RDS Proxy統合

**用途:**
- 接続プーリング
- フェイルオーバー時間短縮（最大66%削減）
- IAM認証

**Lambda統合例:**
```python
import pymysql
import os

def lambda_handler(event, context):
    connection = pymysql.connect(
        host=os.environ['RDS_PROXY_ENDPOINT'],
        user=os.environ['DB_USER'],
        password=os.environ['DB_PASSWORD'],
        database=os.environ['DB_NAME']
    )

    with connection.cursor() as cursor:
        cursor.execute("SELECT * FROM users")
        result = cursor.fetchall()

    connection.close()
    return {'statusCode': 200, 'body': result}
```

---

## EFS for Lambda

### 使用ケース

**適合シナリオ:**
- 大容量ファイル処理（機械学習モデル、動画エンコーディング）
- 複数Lambda間でのステート共有
- レガシーアプリケーションのリフト&シフト

**非適合シナリオ:**
- 小容量データ（S3またはDynamoDB推奨）
- 高頻度の小規模読み書き（レイテンシ影響）

### 設定例

```yaml
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: index.handler
      Runtime: python3.11
      FileSystemConfigs:
        - Arn: !GetAtt EfsAccessPoint.Arn
          LocalMountPath: /mnt/efs
      VpcConfig:
        SecurityGroupIds:
          - !Ref LambdaSecurityGroup
        SubnetIds:
          - !Ref PrivateSubnet1
          - !Ref PrivateSubnet2

  EfsFileSystem:
    Type: AWS::EFS::FileSystem
    Properties:
      PerformanceMode: generalPurpose
      ThroughputMode: bursting

  EfsAccessPoint:
    Type: AWS::EFS::AccessPoint
    Properties:
      FileSystemId: !Ref EfsFileSystem
      PosixUser:
        Uid: 1000
        Gid: 1000
      RootDirectory:
        Path: /lambda
        CreationInfo:
          OwnerUid: 1000
          OwnerGid: 1000
          Permissions: '755'
```

**Lambda関数でのEFS使用:**
```python
import json

def lambda_handler(event, context):
    efs_path = '/mnt/efs/data.json'

    # EFSからデータ読み込み（機密情報はJSONなど安全なフォーマットを使用）
    with open(efs_path, 'r') as f:
        data = json.load(f)

    # 処理実行
    result = process_data(data, event['input'])

    return {'statusCode': 200, 'result': result}

def process_data(data, input_data):
    # データ処理ロジック
    return {'processed': True}
```

### スループットモード選択

| モード | 特性 | 用途 |
|--------|------|------|
| **Bursting** | ファイルシステムサイズに比例したスループット | 断続的なワークロード |
| **Provisioned** | 固定スループット保証 | 高頻度・予測可能なワークロード |
| **Elastic** | 自動スケーリング | 可変ワークロード |

---

## リアルタイムシステム

### AWS AppSync

GraphQL APIのマネージドサービス。

**主要機能:**
- リアルタイムサブスクリプション
- オフライン同期
- 複数データソース統合（DynamoDB、Lambda、RDS、HTTP）

**スキーマ例:**
```graphql
type Query {
  getUser(id: ID!): User
  listUsers: [User]
}

type Mutation {
  createUser(name: String!, email: String!): User
}

type Subscription {
  onCreateUser: User
    @aws_subscribe(mutations: ["createUser"])
}

type User {
  id: ID!
  name: String!
  email: String!
}
```

**Lambda Resolver:**
```python
def lambda_handler(event, context):
    field = event['info']['fieldName']
    arguments = event['arguments']

    if field == 'getUser':
        return get_user(arguments['id'])
    elif field == 'listUsers':
        return list_users()
    elif field == 'createUser':
        return create_user(arguments)
```

### Kinesis Data Streams

**用途:**
- リアルタイムデータストリーミング
- ログ集約
- ClickStream分析

**Lambda統合:**
```python
import base64

def lambda_handler(event, context):
    for record in event['Records']:
        # Kinesisデータはbase64エンコード
        payload = base64.b64decode(record['kinesis']['data'])
        data = json.loads(payload)

        # データ処理
        process_record(data)

def process_record(data):
    # リアルタイム分析・集計
    pass
```

**バッチ設定:**
```yaml
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      Events:
        Stream:
          Type: Kinesis
          Properties:
            Stream: !GetAtt MyStream.Arn
            BatchSize: 100
            StartingPosition: LATEST
            MaximumBatchingWindowInSeconds: 10
```

### IoT Core

**MQTTプロトコル対応:**
```python
# デバイスからのメッセージ処理
def lambda_handler(event, context):
    # IoT Ruleからのイベント
    topic = event['topic']
    message = event['message']

    # デバイスIDを抽出
    device_id = topic.split('/')[1]

    # データ処理・保存
    store_device_data(device_id, message)

    # アラートチェック
    if message['temperature'] > 80:
        send_alert(device_id, message)
```

**IoT Rule設定:**
```json
{
  "sql": "SELECT * FROM 'devices/+/telemetry' WHERE temperature > 80",
  "actions": [
    {
      "lambda": {
        "functionArn": "arn:aws:lambda:region:account:function:process-iot-data"
      }
    }
  ]
}
```

---

## まとめ

### サーバーレスパターン選択ガイド

| ユースケース | 推奨パターン | 主要サービス |
|-------------|------------|-------------|
| **REST API** | API Gateway + Lambda + DynamoDB | API Gateway (REST/HTTP), Lambda, DynamoDB |
| **WebSocket** | API Gateway WebSocket + Lambda + DynamoDB | API Gateway WebSocket, Lambda, DynamoDB |
| **非同期処理** | SQS + Lambda | SQS, Lambda, S3 |
| **イベント駆動** | EventBridge + Lambda | EventBridge, SNS, Lambda |
| **ストリーム処理** | Kinesis + Lambda + DynamoDB | Kinesis Data Streams, Lambda, DynamoDB |
| **バッチ処理** | Step Functions + Lambda | Step Functions, Lambda, S3, DynamoDB |
| **静的サイト** | S3 + CloudFront + Lambda@Edge | S3, CloudFront, Lambda@Edge |
| **GraphQL API** | AppSync + Lambda/DynamoDB | AppSync, Lambda, DynamoDB |

### ベストプラクティス

1. **コールドスタート対策**: Provisioned Concurrency、コード最適化、SnapStart活用
2. **コスト最適化**: 適切なメモリ設定、Lambda Power Tuning使用
3. **セキュリティ**: 最小権限の原則、Secrets Manager使用、VPC統合
4. **監視**: CloudWatch Logs、X-Ray、Lambda Insights有効化
5. **エラーハンドリング**: DLQ設定、リトライポリシー、冪等性確保
6. **テスト**: ローカルテスト（SAM CLI）、統合テスト、カナリアデプロイ

### 避けるべきアンチパターン

| アンチパターン | 問題 | 解決策 |
|--------------|------|--------|
| **モノリシックLambda** | デプロイ・スケーリングの非効率 | 関数を適切に分割 |
| **VPC不要なのに設定** | コールドスタート遅延 | 必要な場合のみVPC統合 |
| **同期呼び出しの連鎖** | レイテンシ増大 | 非同期・並列実行の活用 |
| **環境変数に機密情報** | セキュリティリスク | Secrets Manager/SSM Parameter Store使用 |
| **エラーハンドリング未実装** | データロスト | DLQ設定、リトライポリシー |
