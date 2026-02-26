# GenAI アーキテクチャリファレンス

## パフォーマンス最適化

### Provisioned Throughput

固定スループットを予約して安定したパフォーマンスとコスト予測を実現。

#### On-Demand vs Provisioned比較

| 項目 | On-Demand | Provisioned Throughput |
|------|-----------|----------------------|
| **課金** | リクエスト毎 | 時間課金 |
| **スループット** | 共有 | 専用保証 |
| **レイテンシ** | 変動あり | 安定 |
| **用途** | 開発・テスト、不定期利用 | 本番環境、予測可能な負荷 |
| **コスト** | 低負荷で安価 | 高負荷で安価 |

#### Provisioned Throughput設定

```python
import boto3

bedrock = boto3.client('bedrock')

# Provisioned Throughputの購入
provisioned_model = bedrock.create_provisioned_model_throughput(
    modelId='anthropic.claude-3-sonnet-20240229-v1:0',
    provisionedModelName='prod-claude-sonnet',
    modelUnits=2,  # Model Units数
    commitmentDuration='OneMonth'  # または 'SixMonths'
)

# Provisioned Modelの呼び出し
bedrock_runtime = boto3.client('bedrock-runtime')

response = bedrock_runtime.invoke_model(
    modelId=provisioned_model['provisionedModelArn'],
    body=json.dumps(request_body)
)
```

### レイテンシ最適化

#### 1. ストリーミングレスポンス

```python
# 通常の呼び出し（全体を待つ）
response = bedrock.invoke_model(...)  # 5-10秒待機

# ストリーミング呼び出し（即座に開始）
response = bedrock.invoke_model_with_response_stream(...)
for event in response['body']:
    # リアルタイムで表示
    print(chunk, end='', flush=True)
```

**効果**: ユーザー体感レイテンシを50-80%削減

#### 2. max_tokensの最適化

```python
# 悪い例: 過剰なmax_tokens
request_body = {
    "max_tokens": 4096,  # 最大値を指定
    # ...
}

# 良い例: 必要最小限
request_body = {
    "max_tokens": 512,  # 実際に必要なトークン数
    # ...
}
```

**効果**: レイテンシ30-50%削減、コスト削減

#### 3. 軽量モデルの活用

| タスク | 推奨モデル | レイテンシ |
|--------|----------|----------|
| 簡単な分類 | Claude Haiku | ~1秒 |
| 要約 | Claude Haiku | ~2秒 |
| 複雑な推論 | Claude Sonnet | ~5秒 |
| 最高品質 | Claude Opus | ~10秒 |

### キャッシュ戦略

#### プロンプトキャッシング

```python
# Claude 3.5以降でサポート
request_body = {
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 1024,
    "system": [
        {
            "type": "text",
            "text": "あなたは技術サポートエージェントです...",  # 長いシステムプロンプト
            "cache_control": {"type": "ephemeral"}  # キャッシュを有効化
        }
    ],
    "messages": [
        {"role": "user", "content": "質問..."}
    ]
}
```

**効果**:
- レイテンシ: 最大90%削減
- コスト: キャッシュ読み込みは通常の1/10

#### アプリケーションレベルキャッシング

```python
import redis
import hashlib

redis_client = redis.Redis(host='cache.example.com', port=6379)

def cached_invoke_model(prompt: str, ttl: int = 3600):
    # プロンプトからキャッシュキーを生成
    cache_key = f"bedrock:{hashlib.md5(prompt.encode()).hexdigest()}"

    # キャッシュ確認
    cached_response = redis_client.get(cache_key)
    if cached_response:
        return json.loads(cached_response)

    # キャッシュミス: Bedrockを呼び出し
    response = bedrock_runtime.invoke_model(...)
    response_data = json.loads(response['body'].read())

    # キャッシュに保存
    redis_client.setex(cache_key, ttl, json.dumps(response_data))

    return response_data
```

### バッチ推論

複数のリクエストをバッチ処理してコスト削減:

```python
bedrock = boto3.client('bedrock')

# バッチ推論ジョブ作成
batch_job = bedrock.create_model_invocation_job(
    jobName='batch-inference-job',
    roleArn='arn:aws:iam::123456789012:role/BedrockBatchRole',
    modelId='anthropic.claude-3-sonnet-20240229-v1:0',
    inputDataConfig={
        's3InputDataConfig': {
            's3Uri': 's3://my-bucket/batch-input/',
            's3InputFormat': 'JSONL'
        }
    },
    outputDataConfig={
        's3OutputDataConfig': {
            's3Uri': 's3://my-bucket/batch-output/'
        }
    }
)
```

**入力形式（JSONL）**:
```json
{"recordId": "1", "modelInput": {"messages": [{"role": "user", "content": "質問1"}]}}
{"recordId": "2", "modelInput": {"messages": [{"role": "user", "content": "質問2"}]}}
```

**効果**: On-Demand料金から最大50%割引

---

## セキュリティ・プライバシー

### IAMポリシー（Bedrock固有）

#### 最小権限の原則

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BedrockInvokeModel",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": [
        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
      ]
    },
    {
      "Sid": "DenyExpensiveModels",
      "Effect": "Deny",
      "Action": [
        "bedrock:InvokeModel"
      ],
      "Resource": [
        "arn:aws:bedrock:*:*:foundation-model/anthropic.claude-3-opus-*"
      ]
    }
  ]
}
```

#### Knowledge Base用IAMポリシー

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:Retrieve",
        "bedrock:RetrieveAndGenerate"
      ],
      "Resource": "arn:aws:bedrock:us-east-1:123456789012:knowledge-base/KBID123456"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::knowledge-base-bucket/*"
    }
  ]
}
```

### VPCエンドポイント

プライベートネットワーク経由でBedrockにアクセス:

```python
import boto3

ec2 = boto3.client('ec2')

# VPCエンドポイント作成
vpc_endpoint = ec2.create_vpc_endpoint(
    VpcId='vpc-12345678',
    ServiceName='com.amazonaws.us-east-1.bedrock-runtime',
    VpcEndpointType='Interface',
    SubnetIds=['subnet-12345678'],
    SecurityGroupIds=['sg-12345678'],
    PrivateDnsEnabled=True
)
```

**メリット**:
- インターネットゲートウェイ不要
- データがAWSネットワーク内に留まる
- コンプライアンス要件を満たす

### Guardrails

有害コンテンツのフィルタリング、PII検出・マスク、プロンプト攻撃防御を提供。6つのフィルタータイプ（コンテンツフィルター、拒否トピック、単語フィルター、機密情報フィルター、グラウンディングチェック、自動推論チェック）を組み合わせて多層防御を実現。

→ 詳細は [GUARDRAILS.md](GUARDRAILS.md) を参照

### モデルアクセス制御

```python
# 特定のリージョン・モデルへのアクセス要求
bedrock = boto3.client('bedrock', region_name='us-east-1')

# モデルアクセス有効化
bedrock.put_model_invocation_logging_configuration(
    loggingConfig={
        'cloudWatchConfig': {
            'logGroupName': '/aws/bedrock/modelinvocations',
            'roleArn': 'arn:aws:iam::123456789012:role/BedrockLoggingRole'
        },
        's3Config': {
            'bucketName': 'bedrock-logs',
            'keyPrefix': 'model-invocations/'
        }
    }
)
```

---

## Responsible AI

### バイアス検出

```python
def detect_bias(prompt: str, response: str) -> dict:
    """
    プロンプトと応答のバイアスを検出
    """
    bias_keywords = {
        'gender': ['男性', '女性', 'he', 'she'],
        'race': ['白人', '黒人', 'アジア人'],
        'age': ['若者', '高齢者', '中年']
    }

    detected_biases = {}

    for category, keywords in bias_keywords.items():
        if any(keyword in response for keyword in keywords):
            detected_biases[category] = True

    return detected_biases

# 使用例
response_text = "..."
biases = detect_bias(prompt, response_text)
if biases:
    print(f"検出されたバイアス: {biases}")
```

### 透明性

```python
def add_transparency_metadata(response_data: dict) -> dict:
    """
    レスポンスに透明性メタデータを追加
    """
    response_data['metadata'] = {
        'model_id': 'anthropic.claude-3-sonnet-20240229-v1:0',
        'timestamp': datetime.utcnow().isoformat(),
        'guardrail_applied': True,
        'data_sources': ['knowledge-base-12345'],
        'confidence_score': 0.85
    }
    return response_data
```

### AI倫理ガイドライン

**実装チェックリスト**:
- [ ] 有害コンテンツフィルタリング（Guardrails）
- [ ] PII検出・匿名化
- [ ] バイアス検出機構
- [ ] 人間によるレビュープロセス
- [ ] 透明性のある回答生成
- [ ] ユーザーへの開示（AIが生成したコンテンツであることを明記）

---

## エンドツーエンドアプリケーション

### リファレンスアーキテクチャ

```
CloudFront
    ↓
API Gateway (REST)
    ↓
Lambda (認証・ルーティング)
    ↓
    ├─ Bedrock (LLM推論)
    ├─ Knowledge Base (RAG)
    ├─ DynamoDB (会話履歴)
    └─ S3 (ドキュメント)
```

### Lambda関数（エントリーポイント）

```python
import boto3
import json
from datetime import datetime

bedrock_runtime = boto3.client('bedrock-runtime')
dynamodb = boto3.resource('dynamodb')

table = dynamodb.Table('ConversationHistory')

def lambda_handler(event, context):
    """
    Bedrock統合のメインハンドラー
    """
    # リクエスト解析
    body = json.loads(event['body'])
    user_id = body['userId']
    session_id = body['sessionId']
    user_message = body['message']

    # 会話履歴を取得
    history = get_conversation_history(user_id, session_id)

    # Bedrock呼び出し
    response_text = invoke_bedrock_with_history(user_message, history)

    # 会話履歴を保存
    save_message(user_id, session_id, 'user', user_message)
    save_message(user_id, session_id, 'assistant', response_text)

    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'response': response_text,
            'sessionId': session_id
        })
    }

def get_conversation_history(user_id: str, session_id: str) -> list:
    """
    DynamoDBから会話履歴を取得
    """
    response = table.query(
        KeyConditionExpression='userId = :uid AND begins_with(sessionId, :sid)',
        ExpressionAttributeValues={
            ':uid': user_id,
            ':sid': session_id
        },
        ScanIndexForward=True,
        Limit=10
    )

    return [
        {'role': item['role'], 'content': item['content']}
        for item in response['Items']
    ]

def invoke_bedrock_with_history(message: str, history: list) -> str:
    """
    会話履歴を含めてBedrockを呼び出し
    """
    messages = history + [{'role': 'user', 'content': message}]

    request_body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "messages": messages
    }

    response = bedrock_runtime.invoke_model(
        modelId='anthropic.claude-3-sonnet-20240229-v1:0',
        body=json.dumps(request_body)
    )

    response_body = json.loads(response['body'].read())
    return response_body['content'][0]['text']

def save_message(user_id: str, session_id: str, role: str, content: str):
    """
    メッセージをDynamoDBに保存
    """
    table.put_item(
        Item={
            'userId': user_id,
            'sessionId': f"{session_id}#{datetime.utcnow().isoformat()}",
            'role': role,
            'content': content,
            'timestamp': datetime.utcnow().isoformat()
        }
    )
```

### API Gateway設定

```yaml
# SAM Template
Resources:
  BedrockApi:
    Type: AWS::Serverless::Api
    Properties:
      StageName: prod
      Cors:
        AllowOrigin: "'*'"
        AllowMethods: "'POST, OPTIONS'"
      Auth:
        DefaultAuthorizer: CognitoAuthorizer
        Authorizers:
          CognitoAuthorizer:
            UserPoolArn: !GetAtt UserPool.Arn

  ChatFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: index.lambda_handler
      Runtime: python3.11
      Environment:
        Variables:
          TABLE_NAME: !Ref ConversationTable
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref ConversationTable
        - Statement:
            - Effect: Allow
              Action:
                - bedrock:InvokeModel
              Resource: '*'
      Events:
        ChatApi:
          Type: Api
          Properties:
            RestApiId: !Ref BedrockApi
            Path: /chat
            Method: post
```

---

## スケーラビリティ

### クォータ管理

#### サービスクォータ

| リソース | デフォルト | 引き上げ可能 |
|---------|----------|------------|
| On-Demand リクエスト/分 | 10,000 | ✓ |
| トークン/分 | 200,000 | ✓ |
| 同時実行数 | 100 | ✓ |
| Knowledge Base数 | 10 | ✓ |
| Agents数 | 10 | ✓ |

#### クォータ監視

```python
import boto3

service_quotas = boto3.client('service-quotas')
cloudwatch = boto3.client('cloudwatch')

def monitor_bedrock_usage():
    """
    Bedrockの使用状況を監視
    """
    # CloudWatchメトリクスを確認
    response = cloudwatch.get_metric_statistics(
        Namespace='AWS/Bedrock',
        MetricName='Invocations',
        Dimensions=[
            {'Name': 'ModelId', 'Value': 'anthropic.claude-3-sonnet-20240229-v1:0'}
        ],
        StartTime=datetime.utcnow() - timedelta(minutes=5),
        EndTime=datetime.utcnow(),
        Period=300,
        Statistics=['Sum']
    )

    total_invocations = sum(
        point['Sum'] for point in response['Datapoints']
    )

    # クォータに近づいたら通知
    if total_invocations > 8000:  # 80% threshold
        send_alert("Bedrock quota approaching limit")
```

### リージョン戦略

#### マルチリージョン構成

```python
class MultiRegionBedrockClient:
    def __init__(self, regions: list[str]):
        self.clients = {
            region: boto3.client('bedrock-runtime', region_name=region)
            for region in regions
        }
        self.current_region_index = 0

    def invoke_model_with_failover(self, request_body: dict) -> dict:
        """
        フェイルオーバー付きでモデルを呼び出し
        """
        regions = list(self.clients.keys())

        for i in range(len(regions)):
            region = regions[(self.current_region_index + i) % len(regions)]
            client = self.clients[region]

            try:
                response = client.invoke_model(
                    modelId='anthropic.claude-3-sonnet-20240229-v1:0',
                    body=json.dumps(request_body)
                )
                # 成功したリージョンを記憶
                self.current_region_index = (self.current_region_index + i) % len(regions)
                return json.loads(response['body'].read())

            except ClientError as e:
                if e.response['Error']['Code'] == 'ThrottlingException':
                    # 次のリージョンにフェイルオーバー
                    continue
                raise

        raise Exception("All regions are throttled")

# 使用例
client = MultiRegionBedrockClient(['us-east-1', 'us-west-2', 'eu-west-1'])
response = client.invoke_model_with_failover(request_body)
```

### マルチモデルルーティング

```python
def route_to_optimal_model(query: str, complexity: str) -> str:
    """
    クエリの複雑さに応じて最適なモデルにルーティング
    """
    model_map = {
        'simple': 'anthropic.claude-3-haiku-20240307-v1:0',
        'medium': 'anthropic.claude-3-sonnet-20240229-v1:0',
        'complex': 'anthropic.claude-3-opus-20240229-v1:0'
    }

    model_id = model_map.get(complexity, model_map['medium'])

    request_body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "messages": [{"role": "user", "content": query}]
    }

    response = bedrock_runtime.invoke_model(
        modelId=model_id,
        body=json.dumps(request_body)
    )

    return json.loads(response['body'].read())['content'][0]['text']
```

---

## コスト管理

### トークン課金モデル

#### On-Demand料金構造

| モデル | 入力（1Mトークン） | 出力（1Mトークン） |
|--------|-------------------|-------------------|
| Claude 3 Haiku | $0.25 | $1.25 |
| Claude 3.5 Sonnet | $3.00 | $15.00 |
| Claude 3 Opus | $15.00 | $75.00 |
| Llama 3.1 8B | $0.15 | $0.20 |
| Titan Text Express | $0.20 | $0.60 |

### Provisioned vs On-Demand コスト比較

```python
def calculate_cost_comparison(
    requests_per_day: int,
    avg_input_tokens: int,
    avg_output_tokens: int
):
    """
    On-DemandとProvisionedのコストを比較
    """
    # On-Demand料金（Claude 3.5 Sonnet）
    input_cost_per_1m = 3.00
    output_cost_per_1m = 15.00

    daily_input_tokens = requests_per_day * avg_input_tokens
    daily_output_tokens = requests_per_day * avg_output_tokens

    on_demand_daily_cost = (
        (daily_input_tokens / 1_000_000) * input_cost_per_1m +
        (daily_output_tokens / 1_000_000) * output_cost_per_1m
    )

    on_demand_monthly_cost = on_demand_daily_cost * 30

    # Provisioned Throughput料金（2 Model Units）
    provisioned_hourly_cost = 2 * 2.50  # 2 Units x $2.50/時
    provisioned_monthly_cost = provisioned_hourly_cost * 24 * 30

    print(f"On-Demand月額コスト: ${on_demand_monthly_cost:.2f}")
    print(f"Provisioned月額コスト: ${provisioned_monthly_cost:.2f}")

    if on_demand_monthly_cost > provisioned_monthly_cost:
        savings = on_demand_monthly_cost - provisioned_monthly_cost
        print(f"Provisionedで${savings:.2f}節約可能")
    else:
        print("On-Demandが経済的")

# 例: 1日10,000リクエスト、平均500入力トークン、200出力トークン
calculate_cost_comparison(10000, 500, 200)
```

### コスト見積もりツール

```python
class BedrockCostEstimator:
    PRICING = {
        'anthropic.claude-3-haiku': {'input': 0.25, 'output': 1.25},
        'anthropic.claude-3-sonnet': {'input': 3.00, 'output': 15.00},
        'anthropic.claude-3-opus': {'input': 15.00, 'output': 75.00}
    }

    def estimate_request_cost(
        self,
        model_id: str,
        input_tokens: int,
        output_tokens: int
    ) -> float:
        """
        単一リクエストのコストを見積もり
        """
        pricing = self.PRICING.get(model_id, self.PRICING['anthropic.claude-3-sonnet'])

        input_cost = (input_tokens / 1_000_000) * pricing['input']
        output_cost = (output_tokens / 1_000_000) * pricing['output']

        return input_cost + output_cost

    def estimate_monthly_cost(
        self,
        model_id: str,
        requests_per_day: int,
        avg_input_tokens: int,
        avg_output_tokens: int
    ) -> dict:
        """
        月間コストを見積もり
        """
        daily_cost = (
            self.estimate_request_cost(model_id, avg_input_tokens, avg_output_tokens)
            * requests_per_day
        )

        return {
            'daily_cost': daily_cost,
            'monthly_cost': daily_cost * 30,
            'yearly_cost': daily_cost * 365
        }

# 使用例
estimator = BedrockCostEstimator()
costs = estimator.estimate_monthly_cost(
    'anthropic.claude-3-sonnet',
    requests_per_day=5000,
    avg_input_tokens=500,
    avg_output_tokens=200
)
print(f"月間コスト: ${costs['monthly_cost']:.2f}")
```

---

## サステナビリティ

### 効率的なモデル選択

```python
def select_sustainable_model(task_complexity: str) -> str:
    """
    環境負荷を考慮したモデル選択
    """
    # 軽量モデルを優先
    if task_complexity == 'simple':
        return 'anthropic.claude-3-haiku-20240307-v1:0'  # 最も効率的
    elif task_complexity == 'medium':
        return 'anthropic.claude-3-sonnet-20240229-v1:0'  # バランス
    else:
        return 'anthropic.claude-3-opus-20240229-v1:0'  # 必要な場合のみ
```

### 推論最適化

```python
# 1. 不要なトークン削減
request_body = {
    "max_tokens": 256,  # 必要最小限
    "stop_sequences": ["\n\n"],  # 早期停止
    # ...
}

# 2. バッチ処理の活用
# 個別リクエストの代わりにバッチ推論を使用
bedrock.create_model_invocation_job(...)  # 50%割引 + 効率化

# 3. キャッシングの活用
# 同じプロンプトの再利用でエネルギー削減
```

---

## まとめ

このリファレンスでは、GenAIアプリケーションのアーキテクチャ設計について解説した。本番環境での実装時は以下の点に注意:

- **パフォーマンス**: Provisioned Throughput、ストリーミング、キャッシュを活用
- **セキュリティ**: IAM、VPCエンドポイント、Guardrailsで多層防御
- **Responsible AI**: バイアス検出、透明性、倫理ガイドラインの遵守
- **スケーラビリティ**: クォータ監視、マルチリージョン、モデルルーティング
- **コスト最適化**: 適切なモデル選択、Provisioned vs On-Demandの判断
- **サステナビリティ**: 効率的なモデル選択と推論最適化
