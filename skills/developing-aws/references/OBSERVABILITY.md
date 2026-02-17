# Observability on AWS

AWS上での可観測性（Observability）実践ガイド。CloudWatch、X-Ray、CloudWatch Logs Insights、サーバーレス監視、およびSLI/SLO/SLA設計をカバーします。

---

## 1. 可観測性の3本柱

| 柱 | 説明 | AWSサービス |
|---|------|------------|
| **Metrics（メトリクス）** | 数値データの時系列測定 | CloudWatch Metrics |
| **Logs（ログ）** | イベントの詳細記録 | CloudWatch Logs, CloudWatch Logs Insights |
| **Traces（トレース）** | リクエストの分散追跡 | AWS X-Ray |

**相互関係:**

```
Metricsでアラート → Logsで詳細調査 → Tracesで全体フロー把握
```

---

## 2. Amazon CloudWatch

### 2.1 CloudWatch Metrics

#### 標準メトリクス（自動収集）

| サービス | 主要メトリクス | 収集間隔 |
|---------|--------------|---------|
| **EC2** | CPUUtilization, NetworkIn/Out, DiskReadOps | 5分（詳細モニタリングで1分） |
| **RDS** | CPUUtilization, DatabaseConnections, ReadLatency | 1分 |
| **Lambda** | Invocations, Duration, Errors, Throttles | 1分 |
| **ELB** | RequestCount, TargetResponseTime, HTTPCode_Target_4XX_Count | 1分 |
| **DynamoDB** | ConsumedReadCapacityUnits, WriteThrottleEvents | 1分 |

#### カスタムメトリクス送信

**AWS CLI:**

```bash
aws cloudwatch put-metric-data \
  --namespace "MyApp/Orders" \
  --metric-name "OrdersProcessed" \
  --value 42 \
  --timestamp 2024-01-15T10:00:00Z \
  --dimensions Environment=production,Region=us-east-1
```

**Python (boto3):**

```python
import boto3
from datetime import datetime

cloudwatch = boto3.client('cloudwatch')

def publish_custom_metric(metric_name, value, unit='Count'):
    cloudwatch.put_metric_data(
        Namespace='MyApp/Performance',
        MetricData=[
            {
                'MetricName': metric_name,
                'Value': value,
                'Unit': unit,
                'Timestamp': datetime.utcnow(),
                'Dimensions': [
                    {'Name': 'Environment', 'Value': 'production'},
                    {'Name': 'Service', 'Value': 'OrderService'}
                ]
            }
        ]
    )

# 使用例
publish_custom_metric('CheckoutLatency', 245.3, 'Milliseconds')
publish_custom_metric('ActiveUsers', 1523, 'Count')
```

#### メトリクスの統計

| 統計 | 説明 | 用途 |
|-----|------|------|
| **Average** | 平均値 | CPU使用率、レイテンシの一般的な傾向 |
| **Sum** | 合計値 | リクエスト数、エラー数 |
| **Minimum** | 最小値 | ベースライン確認 |
| **Maximum** | 最大値 | スパイク検出 |
| **SampleCount** | サンプル数 | データポイント数確認 |
| **p50, p90, p99** | パーセンタイル | レイテンシの分布確認 |

### 2.2 CloudWatch Alarms

#### アラーム設定例

```yaml
Resources:
  HighCPUAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: 'EC2-HighCPU-Production'
      AlarmDescription: 'CPU使用率が80%を5分間超過'
      MetricName: CPUUtilization
      Namespace: AWS/EC2
      Statistic: Average
      Period: 300
      EvaluationPeriods: 1
      Threshold: 80
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: InstanceId
          Value: !Ref MyInstance
      AlarmActions:
        - !Ref SNSAlertTopic
      OKActions:
        - !Ref SNSAlertTopic

  ErrorRateAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: 'API-ErrorRate-High'
      AlarmDescription: 'エラー率が5%を超過'
      Metrics:
        - Id: errorRate
          Expression: "(errors / requests) * 100"
        - Id: errors
          MetricStat:
            Metric:
              Namespace: AWS/ApiGateway
              MetricName: 5XXError
              Dimensions:
                - Name: ApiName
                  Value: MyAPI
            Period: 300
            Stat: Sum
          ReturnData: false
        - Id: requests
          MetricStat:
            Metric:
              Namespace: AWS/ApiGateway
              MetricName: Count
              Dimensions:
                - Name: ApiName
                  Value: MyAPI
            Period: 300
            Stat: Sum
          ReturnData: false
      EvaluationPeriods: 2
      Threshold: 5
      ComparisonOperator: GreaterThanThreshold
      TreatMissingData: notBreaching
```

#### 複合アラーム（Composite Alarms）

```yaml
Resources:
  CriticalSystemFailure:
    Type: AWS::CloudWatch::CompositeAlarm
    Properties:
      AlarmName: 'System-Critical-Failure'
      AlarmDescription: '複数の重要指標が同時に閾値超過'
      AlarmRule: 'ALARM(HighCPUAlarm) AND ALARM(HighMemoryAlarm) AND ALARM(ErrorRateAlarm)'
      ActionsEnabled: true
      AlarmActions:
        - !Ref PagerDutyIntegration
```

### 2.3 CloudWatch Dashboards

```python
import boto3
import json

cloudwatch = boto3.client('cloudwatch')

dashboard_body = {
    "widgets": [
        {
            "type": "metric",
            "properties": {
                "title": "EC2 CPU Utilization",
                "region": "us-east-1",
                "metrics": [
                    ["AWS/EC2", "CPUUtilization", {"stat": "Average"}]
                ],
                "period": 300,
                "yAxis": {"left": {"min": 0, "max": 100}}
            }
        },
        {
            "type": "log",
            "properties": {
                "title": "Recent Errors",
                "region": "us-east-1",
                "query": """SOURCE '/aws/lambda/my-function'
                    | fields @timestamp, @message
                    | filter @message like /ERROR/
                    | sort @timestamp desc
                    | limit 20"""
            }
        },
        {
            "type": "metric",
            "properties": {
                "title": "API Gateway Latency (p50, p90, p99)",
                "metrics": [
                    ["AWS/ApiGateway", "Latency", {"stat": "p50"}],
                    ["...", {"stat": "p90"}],
                    ["...", {"stat": "p99"}]
                ],
                "period": 60
            }
        }
    ]
}

cloudwatch.put_dashboard(
    DashboardName='Production-Overview',
    DashboardBody=json.dumps(dashboard_body)
)
```

### 2.4 CloudWatch Contributor Insights

トップN分析（最も多くリクエストを送信しているIPアドレスなど）:

```json
{
  "Schema": {
    "Name": "CloudWatchLogRule",
    "Version": 1
  },
  "LogGroupNames": ["/aws/apigateway/my-api"],
  "LogFormat": "JSON",
  "Fields": {
    "2": "$.ip",
    "3": "$.requestId"
  },
  "Contribution": {
    "Keys": ["$.ip"],
    "ValueOf": "$.requestId",
    "Filters": [
      {
        "Match": "$.status",
        "In": [500, 502, 503, 504]
      }
    ]
  },
  "AggregateOn": "Count"
}
```

---

## 3. CloudWatch Logs

### 3.1 ログストリーム設計

| パターン | 推奨 | 理由 |
|---------|------|------|
| **Log Group** | サービス/アプリケーション単位 | `/aws/lambda/order-service` |
| **Log Stream** | インスタンス/実行単位 | `i-1234567890abcdef0` |
| **保持期間** | 環境に応じて設定 | dev: 7日, prod: 90日 |

### 3.2 構造化ログ（JSON）

**良い例（検索可能）:**

```json
{
  "timestamp": "2024-01-15T10:30:45.123Z",
  "level": "ERROR",
  "service": "OrderService",
  "traceId": "1-5e8a1b2c-3d4e5f6a7b8c9d0e1f2a3b4c",
  "userId": "user-12345",
  "orderId": "order-67890",
  "errorType": "PaymentFailure",
  "errorMessage": "Credit card declined",
  "paymentProvider": "Stripe",
  "amount": 99.99,
  "currency": "USD"
}
```

**悪い例（非構造化）:**

```
2024-01-15 10:30:45 ERROR: Payment failed for user user-12345 order order-67890 amount $99.99
```

### 3.3 CloudWatch Logs Insights クエリ

#### 基本クエリ

```sql
-- エラーログのみ抽出
fields @timestamp, @message
| filter level = "ERROR"
| sort @timestamp desc
| limit 100

-- 特定時間帯のレイテンシ分析
fields @timestamp, duration
| filter @timestamp >= "2024-01-15T10:00:00" and @timestamp < "2024-01-15T11:00:00"
| stats avg(duration), max(duration), pct(duration, 95) as p95
```

#### 高度なクエリ

```sql
-- エラー種別ごとの集計
fields errorType
| filter level = "ERROR"
| stats count() as errorCount by errorType
| sort errorCount desc

-- ユーザーごとのリクエスト数（Top 10）
fields userId
| stats count() as requestCount by userId
| sort requestCount desc
| limit 10

-- 5XX エラーの原因分析
fields @timestamp, @message, statusCode, path, method
| filter statusCode >= 500 and statusCode < 600
| parse @message /(?<errorDetail>.*)/
| stats count() as errorCount by statusCode, path
| sort errorCount desc

-- レイテンシの時系列推移（5分間隔）
fields @timestamp, duration
| stats avg(duration) as avgLatency by bin(5m)
| sort @timestamp

-- 正規表現でのパターン抽出
fields @message
| filter @message like /timeout/i
| parse @message /timeout after (?<timeoutValue>\d+)ms/
| stats count() by timeoutValue
```

### 3.4 ログサブスクリプション

**Lambda でリアルタイムログ処理:**

```yaml
Resources:
  LogProcessorFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: error-log-processor
      Runtime: python3.11
      Handler: index.handler
      Code:
        ZipFile: |
          import json
          import gzip
          import base64
          import boto3

          sns = boto3.client('sns')

          def handler(event, context):
              # CloudWatch Logsからの圧縮データをデコード
              compressed_data = base64.b64decode(event['awslogs']['data'])
              log_data = json.loads(gzip.decompress(compressed_data))

              for log_event in log_data['logEvents']:
                  message = json.loads(log_event['message'])

                  # ERRORレベルのみ処理
                  if message.get('level') == 'ERROR':
                      sns.publish(
                          TopicArn=os.environ['SNS_TOPIC_ARN'],
                          Subject=f"エラー検知: {message['service']}",
                          Message=json.dumps(message, indent=2)
                      )

  SubscriptionFilter:
    Type: AWS::Logs::SubscriptionFilter
    Properties:
      LogGroupName: /aws/lambda/order-service
      FilterPattern: '{ $.level = "ERROR" }'
      DestinationArn: !GetAtt LogProcessorFunction.Arn
```

---

## 4. AWS X-Ray (分散トレーシング)

### 4.1 X-Ray の概念

| 概念 | 説明 |
|------|------|
| **Trace** | エンドツーエンドのリクエストフロー全体 |
| **Segment** | 個別サービスの処理単位 |
| **Subsegment** | Segment内の細かい処理単位（DB呼び出し、HTTP呼び出しなど） |
| **Annotations** | インデックス化されたキー・値ペア（フィルタリング可能） |
| **Metadata** | 非インデックス化の追加情報 |

### 4.2 X-Ray 計装（Lambda）

```python
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all
import boto3

# AWS SDK自動計装
patch_all()

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Orders')

@xray_recorder.capture('process_order')
def process_order(order_id):
    # Annotation（フィルタリング可能）
    xray_recorder.put_annotation('order_id', order_id)
    xray_recorder.put_annotation('environment', 'production')

    # Metadata（詳細情報）
    xray_recorder.put_metadata('order_details', {
        'id': order_id,
        'timestamp': '2024-01-15T10:30:00Z'
    })

    # Subsegment作成
    subsegment = xray_recorder.begin_subsegment('validate_order')
    try:
        # バリデーション処理
        is_valid = validate(order_id)
        subsegment.put_annotation('validation_result', is_valid)
    finally:
        xray_recorder.end_subsegment()

    # DynamoDB呼び出し（自動計装）
    response = table.get_item(Key={'orderId': order_id})

    return response['Item']

def lambda_handler(event, context):
    order_id = event['orderId']
    result = process_order(order_id)
    return {'statusCode': 200, 'body': result}
```

### 4.3 X-Ray フィルタ式

```
service("OrderService") AND fault = true

annotation.environment = "production" AND response.status = 500

duration > 5

annotation.userId = "user-12345"

service("OrderService") AND service("PaymentService")
```

### 4.4 サービスマップ分析

X-Rayサービスマップは以下を可視化:

- **ノード**: 各サービス/リソース
- **エッジ**: サービス間の呼び出し
- **色**: 正常（緑）、エラー（赤）、スロットル（オレンジ）
- **レイテンシ**: エッジに表示される応答時間

**分析観点:**

| 観点 | 確認内容 |
|------|---------|
| **ボトルネック** | レイテンシが最も高いサービス |
| **エラー率** | 赤色のノード・エッジ |
| **依存関係** | ダウンストリームの影響範囲 |
| **スロットリング** | API Gatewayなどの制限超過 |

---

## 5. サーバーレス監視

### 5.1 Lambda Insights

**有効化（CloudFormation）:**

```yaml
Resources:
  MyFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: my-function
      Runtime: python3.11
      Handler: index.handler
      Code: ...
      Layers:
        - !Sub 'arn:aws:lambda:${AWS::Region}:580247275435:layer:LambdaInsightsExtension:21'
      Environment:
        Variables:
          AWS_LAMBDA_EXEC_WRAPPER: /opt/bootstrap
```

**Lambda Insightsメトリクス:**

- `memory_utilization`: メモリ使用率
- `cpu_total_time`: CPU時間
- `tx_bytes`, `rx_bytes`: ネットワーク送受信量
- `init_duration`: コールドスタート時間

### 5.2 API Gateway監視

```yaml
Resources:
  ApiGatewayAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: 'APIGateway-HighLatency'
      MetricName: Latency
      Namespace: AWS/ApiGateway
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 1000
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: ApiName
          Value: !Ref MyApi
        - Name: Stage
          Value: prod

  # CloudWatch Logsへのアクセスログ出力
  ApiLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/apigateway/${MyApi}'
      RetentionInDays: 30

  ApiStage:
    Type: AWS::ApiGateway::Stage
    Properties:
      RestApiId: !Ref MyApi
      DeploymentId: !Ref ApiDeployment
      StageName: prod
      AccessLogSetting:
        DestinationArn: !GetAtt ApiLogGroup.Arn
        Format: >
          {
            "requestId": "$context.requestId",
            "ip": "$context.identity.sourceIp",
            "requestTime": "$context.requestTime",
            "httpMethod": "$context.httpMethod",
            "resourcePath": "$context.resourcePath",
            "status": "$context.status",
            "protocol": "$context.protocol",
            "responseLength": "$context.responseLength",
            "integrationLatency": "$context.integrationLatency",
            "responseLatency": "$context.responseLatency"
          }
```

### 5.3 DynamoDB監視

```python
import boto3

cloudwatch = boto3.client('cloudwatch')

def monitor_dynamodb_throttles(table_name):
    """DynamoDBスロットリング監視"""
    response = cloudwatch.get_metric_statistics(
        Namespace='AWS/DynamoDB',
        MetricName='UserErrors',
        Dimensions=[
            {'Name': 'TableName', 'Value': table_name}
        ],
        StartTime=datetime.utcnow() - timedelta(hours=1),
        EndTime=datetime.utcnow(),
        Period=300,
        Statistics=['Sum']
    )

    for datapoint in response['Datapoints']:
        if datapoint['Sum'] > 0:
            print(f"⚠️ スロットリング発生: {datapoint['Sum']} errors at {datapoint['Timestamp']}")
```

---

## 6. SLI / SLO / SLA 設計

### 6.1 定義

| 用語 | 定義 | 例 |
|------|------|-----|
| **SLI** (Service Level Indicator) | サービス品質の測定可能な指標 | API可用性、レスポンスタイム |
| **SLO** (Service Level Objective) | SLIの目標値 | API可用性 99.9%、p95レイテンシ < 200ms |
| **SLA** (Service Level Agreement) | 顧客との契約上の保証 | 99.5%以上の可用性を保証、違反時は返金 |

**関係:**

```
SLI < SLO < SLA
測定 < 目標 < 契約
```

### 6.2 SLI選定基準

| カテゴリ | SLI例 | CloudWatchメトリクス |
|---------|-------|---------------------|
| **可用性** | 成功リクエスト率 | `(TotalRequests - 5XXErrors) / TotalRequests * 100` |
| **レイテンシ** | p95レスポンス時間 | `Latency` (p95統計) |
| **スループット** | 秒間リクエスト数 | `Count` / 期間 |
| **エラー率** | 4XX/5XXエラー率 | `(4XXError + 5XXError) / Count * 100` |

### 6.3 SLO実装例

```yaml
Resources:
  # SLI: API可用性（5XXエラー率 < 0.1%）
  AvailabilitySLI:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: 'SLO-Availability-Warning'
      AlarmDescription: 'API可用性がSLOに近づいています（エラー率 > 0.05%）'
      Metrics:
        - Id: errorRate
          Expression: "(errors / requests) * 100"
        - Id: errors
          MetricStat:
            Metric:
              Namespace: AWS/ApiGateway
              MetricName: 5XXError
            Period: 3600
            Stat: Sum
          ReturnData: false
        - Id: requests
          MetricStat:
            Metric:
              Namespace: AWS/ApiGateway
              MetricName: Count
            Period: 3600
            Stat: Sum
          ReturnData: false
      EvaluationPeriods: 1
      DatapointsToAlarm: 1
      Threshold: 0.05
      ComparisonOperator: GreaterThanThreshold

  # SLI: レイテンシ（p95 < 200ms）
  LatencySLI:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: 'SLO-Latency-Warning'
      MetricName: Latency
      Namespace: AWS/ApiGateway
      Statistic: p95
      Period: 300
      EvaluationPeriods: 3
      Threshold: 200
      ComparisonOperator: GreaterThanThreshold
```

### 6.4 エラーバジェット

**概念:**

```
エラーバジェット = 1 - SLO

例: SLO 99.9% → エラーバジェット 0.1%
→ 月間43分のダウンタイムが許容範囲
```

**Lambda関数での計算:**

```python
import boto3
from datetime import datetime, timedelta

cloudwatch = boto3.client('cloudwatch')

def calculate_error_budget(slo_percentage, period_days=30):
    """エラーバジェット消費状況を計算"""
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(days=period_days)

    # 総リクエスト数
    total_requests = get_metric_sum('Count', start_time, end_time)

    # エラー数
    errors_4xx = get_metric_sum('4XXError', start_time, end_time)
    errors_5xx = get_metric_sum('5XXError', start_time, end_time)
    total_errors = errors_4xx + errors_5xx

    # 実際のエラー率
    actual_error_rate = (total_errors / total_requests) * 100

    # エラーバジェット
    error_budget = 100 - slo_percentage
    remaining_budget = error_budget - actual_error_rate

    return {
        'slo': slo_percentage,
        'error_budget': error_budget,
        'actual_error_rate': actual_error_rate,
        'remaining_budget': remaining_budget,
        'budget_consumed_percentage': (actual_error_rate / error_budget) * 100
    }

# 使用例
result = calculate_error_budget(slo_percentage=99.9, period_days=30)
print(f"エラーバジェット残: {result['remaining_budget']:.4f}%")
print(f"消費率: {result['budget_consumed_percentage']:.1f}%")
```

---

## 7. 統合監視パターン

### 7.1 CloudWatch + X-Ray + Logs 統合

**相関ID（Trace ID）でログとトレースを紐付け:**

```python
import os
import json
import logging
from aws_xray_sdk.core import xray_recorder

# ロガー設定
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # X-Ray Trace IDを取得
    trace_id = os.environ.get('_X_AMZN_TRACE_ID', '')

    # ログに Trace ID を含める
    log_entry = {
        'timestamp': datetime.utcnow().isoformat(),
        'level': 'INFO',
        'message': 'Processing order',
        'traceId': trace_id,
        'orderId': event['orderId']
    }

    logger.info(json.dumps(log_entry))

    # X-Rayでアノテーション追加
    xray_recorder.put_annotation('orderId', event['orderId'])

    # ビジネスロジック
    process_order(event['orderId'])

    return {'statusCode': 200}
```

**CloudWatch Logs Insights で Trace ID検索:**

```sql
fields @timestamp, traceId, orderId, message
| filter traceId = "1-5e8a1b2c-3d4e5f6a7b8c9d0e1f2a3b4c"
| sort @timestamp
```

### 7.2 カスタムダッシュボード（全体監視）

```python
dashboard_widgets = [
    # ゴールデンシグナル: Latency
    {
        "type": "metric",
        "properties": {
            "title": "API Latency (p50, p95, p99)",
            "metrics": [
                ["AWS/ApiGateway", "Latency", {"stat": "p50", "label": "p50"}],
                ["...", {"stat": "p95", "label": "p95"}],
                ["...", {"stat": "p99", "label": "p99"}]
            ],
            "period": 60,
            "region": "us-east-1",
            "yAxis": {"left": {"min": 0}}
        }
    },
    # ゴールデンシグナル: Traffic
    {
        "type": "metric",
        "properties": {
            "title": "Request Rate (req/sec)",
            "metrics": [
                ["AWS/ApiGateway", "Count", {"stat": "Sum", "label": "Requests"}]
            ],
            "period": 60
        }
    },
    # ゴールデンシグナル: Errors
    {
        "type": "metric",
        "properties": {
            "title": "Error Rate",
            "metrics": [
                ["AWS/ApiGateway", "4XXError", {"stat": "Sum", "label": "4XX"}],
                ["...", "5XXError", {"stat": "Sum", "label": "5XX"}]
            ],
            "period": 60
        }
    },
    # ゴールデンシグナル: Saturation
    {
        "type": "metric",
        "properties": {
            "title": "DynamoDB Throttles",
            "metrics": [
                ["AWS/DynamoDB", "UserErrors", {"stat": "Sum"}]
            ]
        }
    },
    # X-Ray Service Map
    {
        "type": "trace-map",
        "properties": {
            "title": "Service Map",
            "region": "us-east-1"
        }
    }
]
```

---

## 8. ベストプラクティス

### 8.1 監視の優先順位

```
1. ユーザー影響の大きい指標（可用性、レイテンシ）
2. ビジネスメトリクス（注文数、売上）
3. リソース使用率（CPU、メモリ）
4. 詳細な技術メトリクス（個別API呼び出し）
```

### 8.2 アラート設計原則

| 原則 | 説明 |
|------|------|
| **Actionable** | アラートを受けたら具体的なアクションが必要 |
| **User-Impact** | ユーザー影響がある場合のみアラート |
| **Context-Rich** | アラートにダッシュボードリンク、Runbook URLを含める |
| **Avoid Noise** | 誤検知を最小化（適切な閾値、評価期間設定） |

### 8.3 コスト最適化

| 項目 | 推奨 |
|------|------|
| **ログ保持期間** | 環境ごとに設定（dev: 7日、prod: 90日） |
| **カスタムメトリクス** | 必要最小限に絞る（高頻度送信は高コスト） |
| **X-Ray サンプリング** | 本番環境では5-10%（全量は不要） |
| **ログフィルタリング** | DEBUGログは本番環境で無効化 |

---

## 参考リソース

### AWS公式ドキュメント

- [Amazon CloudWatch User Guide](https://docs.aws.amazon.com/cloudwatch/)
- [AWS X-Ray Developer Guide](https://docs.aws.amazon.com/xray/)
- [CloudWatch Logs Insights Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [Lambda Insights](https://docs.aws.amazon.com/lambda/latest/dg/monitoring-insights.html)

### 関連ツール

- [CloudWatch Synthetics](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Synthetics_Canaries.html) - 外形監視
- [AWS Distro for OpenTelemetry](https://aws-otel.github.io/) - OTel標準計装
