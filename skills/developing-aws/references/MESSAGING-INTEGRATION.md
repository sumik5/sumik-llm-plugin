# AWSメッセージング・統合サービスガイド

AWSのメッセージングおよびワークフロー統合サービスを活用し、疎結合でスケーラブルなアーキテクチャを構築するための実践的なガイドです。

---

## 1. メッセージングの基礎

### 1.1 同期通信 vs 非同期通信

| 特性 | 同期通信 | 非同期通信 |
|------|---------|-----------|
| **ブロッキング** | 呼び出し側がレスポンスを待機 | 呼び出し側はメッセージ送信後すぐに処理継続 |
| **結合度** | 高 (送信者と受信者が同時にオンラインである必要) | 低 (メッセージキューが仲介) |
| **信頼性** | 受信者が利用不可の場合エラー | メッセージキューが永続化、リトライ可能 |
| **スケーラビリティ** | 受信者の処理能力に依存 | キューでバッファリング、受信者は独立してスケール |
| **ユースケース** | リアルタイム応答が必要 (REST API) | バッチ処理、イベント駆動アーキテクチャ |

### 1.2 メッセージングパターン

| パターン | 説明 | AWSサービス |
|---------|------|-----------|
| **Point-to-Point** | 送信者 → キュー → 単一受信者 | Amazon SQS |
| **Pub/Sub** | 発行者 → トピック → 複数購読者 | Amazon SNS, Amazon EventBridge |
| **Event Streaming** | 連続的なイベントストリーム処理 | Amazon Kinesis, Amazon MSK (Kafka) |

---

## 2. Amazon SQS (Simple Queue Service)

### 2.1 概要

**Amazon SQS**は、フルマネージド型メッセージキューイングサービス。プロデューサーとコンシューマーの疎結合を実現。

**主要特徴**:
- 無制限のスループット、メッセージ数
- メッセージ保持期間: 1分〜14日 (デフォルト4日)
- メッセージサイズ: 最大256KB
- 高可用性 (複数AZに分散)

### 2.2 キュータイプ: Standard vs FIFO

| 特性 | Standard Queue | FIFO Queue |
|------|---------------|------------|
| **スループット** | ほぼ無制限 | 最大3,000メッセージ/秒 (バッチ時30,000/秒) |
| **順序保証** | ベストエフォート (順不同の可能性) | 厳密な順序保証 |
| **重複配信** | 最低1回配信 (重複の可能性あり) | 正確に1回処理 |
| **メッセージグループID** | なし | あり (グループ内で順序保証) |
| **命名規則** | 任意 | `.fifo` サフィックス必須 |
| **ユースケース** | 高スループット、順序不問 | トランザクション処理、順序が重要 |

### 2.3 メッセージの重複排除

**FIFO キューの重複排除メカニズム**:

| 方式 | 説明 | ユースケース |
|------|------|-------------|
| **コンテンツベース** | メッセージ本文のSHA-256ハッシュで自動判定 | メッセージIDが生成困難 |
| **メッセージ重複排除ID** | 送信時に明示的にID指定 | アプリケーション制御重視 |

**重複排除期間**: 5分間 (同じIDのメッセージは5分以内なら重複とみなされる)

### 2.4 Visibility Timeout (可視性タイムアウト)

**仕組み**:
1. コンシューマーがメッセージを受信
2. メッセージは一時的に他のコンシューマーから「不可視」になる (デフォルト30秒)
3. コンシューマーが処理完了→メッセージ削除
4. タイムアウト期限内に削除されない→再度可視化され他のコンシューマーが処理可能

**ベストプラクティス**:
- 処理時間に応じて適切なタイムアウトを設定 (処理時間の6倍が推奨)
- 長時間処理の場合は `ChangeMessageVisibility` APIで動的に延長

**コード例 - SQS キュー作成とメッセージ送受信 (AWS CLI)**:

```bash
# Standard キュー作成
aws sqs create-queue --queue-name my-queue

# FIFO キュー作成
aws sqs create-queue \
    --queue-name my-queue.fifo \
    --attributes '{
        "FifoQueue": "true",
        "ContentBasedDeduplication": "true",
        "MessageRetentionPeriod": "345600"
    }'

# メッセージ送信 (Standard)
aws sqs send-message \
    --queue-url https://sqs.ap-northeast-1.amazonaws.com/123456789012/my-queue \
    --message-body "Hello from SQS"

# メッセージ送信 (FIFO)
aws sqs send-message \
    --queue-url https://sqs.ap-northeast-1.amazonaws.com/123456789012/my-queue.fifo \
    --message-body "Order processed" \
    --message-group-id "order-123" \
    --message-deduplication-id "dedup-456"

# メッセージ受信
aws sqs receive-message \
    --queue-url https://sqs.ap-northeast-1.amazonaws.com/123456789012/my-queue \
    --max-number-of-messages 10 \
    --wait-time-seconds 20

# メッセージ削除
aws sqs delete-message \
    --queue-url https://sqs.ap-northeast-1.amazonaws.com/123456789012/my-queue \
    --receipt-handle "AQEB..."
```

**コード例 - SQS 操作 (Python SDK)**:

```python
import boto3
import json

sqs = boto3.client('sqs')
queue_url = 'https://sqs.ap-northeast-1.amazonaws.com/123456789012/my-queue'

# メッセージ送信
response = sqs.send_message(
    QueueUrl=queue_url,
    MessageBody=json.dumps({'orderId': '123', 'amount': 99.99}),
    MessageAttributes={
        'Priority': {'StringValue': 'high', 'DataType': 'String'}
    }
)
print(f"Message ID: {response['MessageId']}")

# バッチ送信 (最大10件)
entries = [
    {'Id': '1', 'MessageBody': json.dumps({'orderId': '124'})},
    {'Id': '2', 'MessageBody': json.dumps({'orderId': '125'})}
]
response = sqs.send_message_batch(QueueUrl=queue_url, Entries=entries)

# メッセージ受信 (ロングポーリング)
while True:
    messages = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=10,
        WaitTimeSeconds=20,  # ロングポーリング (0-20秒)
        MessageAttributeNames=['All']
    )

    if 'Messages' not in messages:
        print("No messages")
        continue

    for message in messages['Messages']:
        print(f"Processing: {message['Body']}")

        # メッセージ処理
        try:
            process_order(json.loads(message['Body']))

            # 処理成功 - メッセージ削除
            sqs.delete_message(
                QueueUrl=queue_url,
                ReceiptHandle=message['ReceiptHandle']
            )
        except Exception as e:
            print(f"Error: {e}")
            # 処理失敗 - Visibility Timeout延長
            sqs.change_message_visibility(
                QueueUrl=queue_url,
                ReceiptHandle=message['ReceiptHandle'],
                VisibilityTimeout=300  # 5分延長
            )
```

### 2.5 Dead-Letter Queue (DLQ)

**概要**:
処理に失敗したメッセージを自動的に別のキューに移動させる仕組み。

**設定パラメータ**:
- **maxReceiveCount**: メッセージが受信される最大回数 (例: 3回失敗でDLQへ)
- **DLQのARN**: 移動先キュー

**ユースケース**:
- リトライ回数制限
- 問題メッセージの隔離と分析
- アラート通知

**コード例 - DLQ 設定 (AWS CLI)**:

```bash
# DLQ用キュー作成
aws sqs create-queue --queue-name my-dlq

# メインキューにDLQ設定
aws sqs set-queue-attributes \
    --queue-url https://sqs.ap-northeast-1.amazonaws.com/123456789012/my-queue \
    --attributes '{
        "RedrivePolicy": "{\"deadLetterTargetArn\":\"arn:aws:sqs:ap-northeast-1:123456789012:my-dlq\",\"maxReceiveCount\":\"3\"}"
    }'
```

---

## 3. Amazon SNS (Simple Notification Service)

### 3.1 概要

**Amazon SNS**は、Pub/Sub型メッセージングサービス。1つのメッセージを複数のサブスクライバーに同時配信。

**主要特徴**:
- トピック (発行者が送信先)
- サブスクリプション (受信者の登録)
- ファンアウトパターン (1対多配信)
- プロトコル: HTTP/HTTPS, Email, SMS, SQS, Lambda, モバイルプッシュ通知

### 3.2 メッセージフィルタリング

**フィルターポリシー**を使用して、サブスクライバーが受信するメッセージを制御可能。

**フィルター例**:

```json
{
  "store": ["example_corp"],
  "price_usd": [{"numeric": [">", 100]}],
  "event_type": ["order_placed", "order_shipped"]
}
```

**適用場面**:
- 特定条件のメッセージのみ処理 (例: 高額注文のみSlack通知)
- 地域別ルーティング (例: 東京リージョンのイベントのみ)

**コード例 - SNS トピック作成とサブスクリプション (AWS CLI)**:

```bash
# SNSトピック作成
aws sns create-topic --name my-topic

# Emailサブスクリプション
aws sns subscribe \
    --topic-arn arn:aws:sns:ap-northeast-1:123456789012:my-topic \
    --protocol email \
    --notification-endpoint user@example.com

# SQSサブスクリプション (ファンアウトパターン)
aws sns subscribe \
    --topic-arn arn:aws:sns:ap-northeast-1:123456789012:my-topic \
    --protocol sqs \
    --notification-endpoint arn:aws:sqs:ap-northeast-1:123456789012:my-queue \
    --attributes '{
        "FilterPolicy": "{\"event_type\":[\"order_placed\"]}"
    }'

# Lambdaサブスクリプション
aws sns subscribe \
    --topic-arn arn:aws:sns:ap-northeast-1:123456789012:my-topic \
    --protocol lambda \
    --notification-endpoint arn:aws:lambda:ap-northeast-1:123456789012:function:my-function

# メッセージ発行
aws sns publish \
    --topic-arn arn:aws:sns:ap-northeast-1:123456789012:my-topic \
    --message "Order placed" \
    --message-attributes '{
        "event_type": {"DataType": "String", "StringValue": "order_placed"},
        "price_usd": {"DataType": "Number", "StringValue": "150"}
    }'
```

**コード例 - SNS 操作 (Python SDK)**:

```python
import boto3
import json

sns = boto3.client('sns')
topic_arn = 'arn:aws:sns:ap-northeast-1:123456789012:my-topic'

# メッセージ発行
response = sns.publish(
    TopicArn=topic_arn,
    Message=json.dumps({
        'orderId': '123',
        'amount': 150.00,
        'customer': 'alice@example.com'
    }),
    Subject='New Order Notification',
    MessageAttributes={
        'event_type': {'DataType': 'String', 'StringValue': 'order_placed'},
        'price_usd': {'DataType': 'Number', 'StringValue': '150'}
    }
)
print(f"Message ID: {response['MessageId']}")

# サブスクリプション作成 (SQS)
response = sns.subscribe(
    TopicArn=topic_arn,
    Protocol='sqs',
    Endpoint='arn:aws:sqs:ap-northeast-1:123456789012:my-queue',
    Attributes={
        'FilterPolicy': json.dumps({
            'event_type': ['order_placed', 'order_shipped']
        })
    }
)

# サブスクリプション一覧取得
response = sns.list_subscriptions_by_topic(TopicArn=topic_arn)
for subscription in response['Subscriptions']:
    print(f"Protocol: {subscription['Protocol']}, Endpoint: {subscription['Endpoint']}")
```

### 3.3 SNS + SQS ファンアウトパターン

**アーキテクチャ**:

```
発行者 → SNS トピック
            ├→ SQS キュー1 (注文処理)
            ├→ SQS キュー2 (在庫更新)
            └→ SQS キュー3 (メール通知)
```

**メリット**:
- 疎結合: 各サービスが独立してスケール
- 並列処理: 複数の処理が同時進行
- 信頼性: SQSが各サービスのバッファとして機能

**設定のポイント**:
- SQSキューのアクセスポリシーにSNSからの送信を許可

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "sns.amazonaws.com"},
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:ap-northeast-1:123456789012:my-queue",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:sns:ap-northeast-1:123456789012:my-topic"
        }
      }
    }
  ]
}
```

---

## 4. Amazon EventBridge

### 4.1 概要

**Amazon EventBridge**は、イベント駆動アプリケーション構築のためのサーバーレスイベントバス。

**主要コンポーネント**:

| コンポーネント | 説明 |
|-------------|------|
| **イベントバス** | イベントの送受信チャネル (デフォルト、カスタム、パートナー) |
| **ルール** | イベントのフィルタリングとターゲットへのルーティング |
| **ターゲット** | イベントの送信先 (Lambda, SQS, SNS, Step Functions等) |

### 4.2 イベントパターン

**イベント構造**:

```json
{
  "version": "0",
  "id": "unique-id",
  "detail-type": "Order Placed",
  "source": "myapp.orders",
  "account": "123456789012",
  "time": "2023-10-01T12:00:00Z",
  "region": "ap-northeast-1",
  "resources": [],
  "detail": {
    "orderId": "123",
    "amount": 99.99,
    "customer": "alice@example.com"
  }
}
```

**イベントパターン例** (特定イベントのみマッチ):

```json
{
  "source": ["myapp.orders"],
  "detail-type": ["Order Placed"],
  "detail": {
    "amount": [{"numeric": [">", 100]}]
  }
}
```

**コード例 - EventBridge ルール作成 (AWS CLI)**:

```bash
# カスタムイベントバス作成
aws events create-event-bus --name my-event-bus

# ルール作成
aws events put-rule \
    --name my-rule \
    --event-bus-name my-event-bus \
    --event-pattern '{
        "source": ["myapp.orders"],
        "detail-type": ["Order Placed"]
    }'

# ターゲット追加 (Lambda関数)
aws events put-targets \
    --rule my-rule \
    --event-bus-name my-event-bus \
    --targets '[
        {
            "Id": "1",
            "Arn": "arn:aws:lambda:ap-northeast-1:123456789012:function:my-function"
        }
    ]'

# イベント送信
aws events put-events --entries '[
    {
        "Source": "myapp.orders",
        "DetailType": "Order Placed",
        "Detail": "{\"orderId\":\"123\",\"amount\":150.00}",
        "EventBusName": "my-event-bus"
    }
]'
```

---

## 5. Amazon API Gateway

### 5.1 概要

**Amazon API Gateway**は、RESTful APIおよびWebSocket APIを作成・公開するためのフルマネージドサービス。

**主要機能**:
- エンドポイント管理
- リクエスト/レスポンス変換
- 認証・認可 (IAM, Cognito, Lambda Authorizer)
- スロットリング、クォータ管理
- キャッシング
- APIバージョニング

### 5.2 APIタイプ

| タイプ | 用途 | プロトコル | レイテンシ | コスト |
|-------|------|---------|-----------|-------|
| **REST API** | フル機能のRESTful API | HTTP/HTTPS | 低 | 中 |
| **HTTP API** | シンプルなHTTP API | HTTP/HTTPS | 超低 (REST APIの60%) | 低 (REST APIの71%) |
| **WebSocket API** | 双方向リアルタイム通信 | WebSocket | 低 | 中 |

**選定基準**:

| 要件 | REST API | HTTP API |
|------|---------|---------|
| リクエスト検証が必要 | ✓ | × |
| APIキー管理が必要 | ✓ | × |
| リソースポリシーが必要 | ✓ | × |
| 低レイテンシ・低コスト重視 | | ✓ |
| JWTオーソライザー | △ (Lambda Authorizer経由) | ✓ (ネイティブ) |

### 5.3 統合タイプ

| 統合タイプ | 説明 | ユースケース |
|----------|------|-------------|
| **Lambda Proxy** | リクエストをそのままLambdaに渡し、レスポンスをそのまま返す | 最も一般的、簡単 |
| **Lambda Non-Proxy** | リクエスト/レスポンスをマッピングテンプレートで変換 | レガシーAPIとの統合 |
| **HTTP Proxy** | 外部HTTPエンドポイントにプロキシ | オンプレミスAPIの公開 |
| **AWS Service** | 他のAWSサービスを直接呼び出し | Lambda不要でDynamoDB操作等 |
| **Mock** | モックレスポンスを返す | 開発・テスト |

**コード例 - REST API 作成 (AWS CLI)**:

```bash
# REST API作成
aws apigateway create-rest-api \
    --name my-api \
    --endpoint-configuration types=REGIONAL

# ルートリソース取得
aws apigateway get-resources \
    --rest-api-id abcdef123

# リソース作成 (/orders)
aws apigateway create-resource \
    --rest-api-id abcdef123 \
    --parent-id xyz789 \
    --path-part orders

# メソッド作成 (GET)
aws apigateway put-method \
    --rest-api-id abcdef123 \
    --resource-id uvw456 \
    --http-method GET \
    --authorization-type NONE

# Lambda統合
aws apigateway put-integration \
    --rest-api-id abcdef123 \
    --resource-id uvw456 \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:ap-northeast-1:lambda:path/2015-03-31/functions/arn:aws:lambda:ap-northeast-1:123456789012:function:get-orders/invocations

# デプロイ
aws apigateway create-deployment \
    --rest-api-id abcdef123 \
    --stage-name prod
```

**Lambda関数例** (Python):

```python
import json

def lambda_handler(event, context):
    print(f"Event: {json.dumps(event)}")

    # パスパラメータ取得
    order_id = event.get('pathParameters', {}).get('orderId')

    # クエリパラメータ取得
    query_params = event.get('queryStringParameters', {})

    # ボディ取得
    body = json.loads(event.get('body', '{}'))

    # レスポンス返却
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'message': 'Success',
            'orderId': order_id,
            'data': body
        })
    }
```

---

## 6. AWS AppSync (GraphQL)

### 6.1 概要

**AWS AppSync**は、マネージド型GraphQL APIサービス。

**GraphQLの特徴**:
- クライアント駆動: 必要なフィールドのみ取得
- 単一エンドポイント: 複数リソースを1リクエストで取得
- リアルタイム: Subscriptionでデータ変更を購読

### 6.2 主要概念

| 概念 | 説明 |
|------|------|
| **Schema** | データ型、Query、Mutation、Subscriptionの定義 |
| **Resolver** | データソースからデータを取得・操作する関数 |
| **Data Source** | DynamoDB, Lambda, HTTP, RDS等のバックエンド |
| **VTL (Velocity Template Language)** | リクエスト/レスポンス変換用テンプレート |

**GraphQLスキーマ例**:

```graphql
type Order {
  orderId: ID!
  customerId: ID!
  amount: Float!
  status: String!
  createdAt: AWSDateTime!
}

type Query {
  getOrder(orderId: ID!): Order
  listOrders(limit: Int, nextToken: String): OrderConnection
}

type Mutation {
  createOrder(input: CreateOrderInput!): Order
  updateOrderStatus(orderId: ID!, status: String!): Order
}

type Subscription {
  onOrderCreated: Order
    @aws_subscribe(mutations: ["createOrder"])
}

input CreateOrderInput {
  customerId: ID!
  amount: Float!
}

type OrderConnection {
  items: [Order]
  nextToken: String
}
```

### 6.3 AppSync vs API Gateway

| 特性 | API Gateway (REST) | AppSync (GraphQL) |
|------|-------------------|------------------|
| **エンドポイント** | 複数 (リソースごと) | 単一 |
| **データ取得** | Over-fetching/Under-fetching | 必要なフィールドのみ |
| **リアルタイム** | WebSocket API必要 | Subscription組み込み |
| **キャッシュ** | メソッドレベル | フィールドレベル |
| **学習曲線** | 低 (RESTは一般的) | 中 (GraphQL学習必要) |

---

## 7. AWS Step Functions (ワークフローオーケストレーション)

### 7.1 概要

**AWS Step Functions**は、分散アプリケーションとマイクロサービスを調整するサーバーレスワークフローサービス。

**主要特徴**:
- 視覚的なワークフロー設計
- エラーハンドリング (リトライ、キャッチ)
- 並列実行、条件分岐、待機状態
- 実行履歴の追跡

### 7.2 ワークフロータイプ

| タイプ | 最大実行時間 | 実行履歴 | ユースケース |
|-------|------------|---------|-------------|
| **Standard Workflow** | 1年 | 完全な履歴保存 | 長時間実行、監査要件あり |
| **Express Workflow** | 5分 | CloudWatch Logsに記録 | 高スループット、短時間イベント処理 |

### 7.3 ステートタイプ

| ステートタイプ | 説明 | 例 |
|-------------|------|---|
| **Task** | 作業を実行 (Lambda, ECS, Batch等) | Lambda関数呼び出し |
| **Choice** | 条件分岐 | 注文金額で処理フロー変更 |
| **Parallel** | 並列実行 | 在庫確認と決済処理を同時実行 |
| **Wait** | 指定時間待機 | 30秒待機後に次ステップ |
| **Succeed/Fail** | 成功/失敗で終了 | エラー時に失敗終了 |
| **Pass** | 入力をそのまま出力 (デバッグ用) | データ変換なし |
| **Map** | 配列の各要素に対して処理実行 | 複数注文を並列処理 |

**ステートマシン定義例** (Amazon States Language - ASL):

```json
{
  "Comment": "Order processing workflow",
  "StartAt": "ValidateOrder",
  "States": {
    "ValidateOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:ap-northeast-1:123456789012:function:validate-order",
      "Next": "CheckInventory",
      "Catch": [
        {
          "ErrorEquals": ["ValidationError"],
          "Next": "OrderFailed"
        }
      ],
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ]
    },
    "CheckInventory": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:ap-northeast-1:123456789012:function:check-inventory",
      "Next": "ProcessPayment"
    },
    "ProcessPayment": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:ap-northeast-1:123456789012:function:process-payment",
      "Next": "SendConfirmation"
    },
    "SendConfirmation": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "SendEmail",
          "States": {
            "SendEmail": {
              "Type": "Task",
              "Resource": "arn:aws:lambda:ap-northeast-1:123456789012:function:send-email",
              "End": true
            }
          }
        },
        {
          "StartAt": "UpdateDatabase",
          "States": {
            "UpdateDatabase": {
              "Type": "Task",
              "Resource": "arn:aws:lambda:ap-northeast-1:123456789012:function:update-db",
              "End": true
            }
          }
        }
      ],
      "Next": "OrderComplete"
    },
    "OrderComplete": {
      "Type": "Succeed"
    },
    "OrderFailed": {
      "Type": "Fail",
      "Error": "OrderProcessingFailed",
      "Cause": "Order validation failed"
    }
  }
}
```

**コード例 - Step Functions ステートマシン作成 (AWS CLI)**:

```bash
# IAMロール作成 (Step Functions実行ロール)
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "states.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
    --role-name step-functions-execution-role \
    --assume-role-policy-document file://trust-policy.json

# ステートマシン作成
aws stepfunctions create-state-machine \
    --name order-processing \
    --definition file://state-machine.json \
    --role-arn arn:aws:iam::123456789012:role/step-functions-execution-role

# ステートマシン実行
aws stepfunctions start-execution \
    --state-machine-arn arn:aws:states:ap-northeast-1:123456789012:stateMachine:order-processing \
    --input '{"orderId": "123", "customerId": "alice", "amount": 99.99}'

# 実行履歴確認
aws stepfunctions describe-execution \
    --execution-arn arn:aws:states:ap-northeast-1:123456789012:execution:order-processing:exec-123
```

---

## 8. Amazon Kinesis (リアルタイムストリーミング)

### 8.1 Kinesis サービス比較

| サービス | 用途 | 保持期間 | レイテンシ | ユースケース |
|---------|------|---------|-----------|-------------|
| **Kinesis Data Streams** | リアルタイムデータストリーム処理 | 最大365日 | リアルタイム (<200ms) | ログ分析、リアルタイムダッシュボード |
| **Kinesis Data Firehose** | データ配信 (S3, Redshift, Elasticsearch等) | なし (自動配信) | ニアリアルタイム (最短60秒) | データレイク構築、ETL |
| **Kinesis Data Analytics** | ストリームデータのSQL分析 | - | リアルタイム | リアルタイム集計、異常検出 |
| **Kinesis Video Streams** | 動画ストリーム取り込み・保存 | 最大10年 | 低レイテンシ | 動画監視、ML推論 |

---

## 9. メッセージングサービス選定決定木

```
通信パターンは？
├─ 1対1 (Point-to-Point)
│   ├─ 順序保証必要 → SQS FIFO
│   └─ 順序不問、高スループット → SQS Standard
├─ 1対多 (Pub/Sub)
│   ├─ フィルタリング必要 → SNS (フィルターポリシー)
│   ├─ 複雑なルーティング → EventBridge
│   └─ シンプル → SNS
├─ イベント駆動アーキテクチャ
│   ├─ イベントソーシング → EventBridge
│   └─ リアルタイムストリーム → Kinesis Data Streams
└─ API公開
    ├─ RESTful → API Gateway
    ├─ GraphQL → AppSync
    └─ リアルタイム双方向 → API Gateway WebSocket
```

---

## まとめ

AWSメッセージング・統合サービスの選定では、以下の要素を総合的に評価します:

1. **通信パターン**: Point-to-Point vs Pub/Sub vs イベントストリーム
2. **順序保証**: 必須 (FIFO) vs 不要 (Standard)
3. **スループット**: 高 (Standard, Kinesis) vs 中 (FIFO)
4. **レイテンシ**: リアルタイム vs ニアリアルタイム
5. **ワークフロー**: 単純処理 vs 複雑オーケストレーション (Step Functions)
6. **API型**: REST vs GraphQL vs WebSocket

一般的なベストプラクティスとして、マイクロサービス間の非同期通信にはSQS/SNS、イベント駆動アーキテクチャにはEventBridge、複雑なワークフローにはStep Functions、リアルタイムデータ処理にはKinesisを活用することが推奨されます。
