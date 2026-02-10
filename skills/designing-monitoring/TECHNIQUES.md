# テレメトリーパイプライン最適化技法

## 1. 正規表現の最適化

テレメトリーパイプライン内での正規表現処理は、大量のログストリームに対して実行されるため、パフォーマンスが重要です。

### 1.1 アンカータグの使用

文字列の先頭と末尾を明示的に指定することで、不要なマッチング試行を削減します。

**判断テーブル: アンカータグの選択**

| パターン | 用途 | パフォーマンス影響 |
|---------|------|------------------|
| `^pattern` | 行頭マッチ | 高速（先頭のみ検査） |
| `pattern$` | 行末マッチ | 高速（末尾のみ検査） |
| `^pattern$` | 完全一致 | 最高速（両端固定） |
| `pattern` | 部分一致 | 低速（全体走査） |

```python
# 悪い例: アンカーなし（全体を走査）
pattern = re.compile(r"ERROR")

# 良い例: 行頭アンカー（先頭のみ検査）
pattern = re.compile(r"^ERROR")
```

### 1.2 Fail Fast戦略

最も失敗しやすいパターンを先頭に配置し、早期にマッチング失敗を検出します。

```python
# 悪い例: 汎用パターンが先
pattern = re.compile(r".*ERROR.*critical")

# 良い例: 具体的なパターンが先
pattern = re.compile(r"^ERROR.*critical")
```

### 1.3 文字セットの最適化

**判断テーブル: 文字セットの選択**

| パターン | 処理速度 | 推奨使用ケース |
|---------|---------|--------------|
| `[0-9]` | 最速 | 数字のみ |
| `\d` | 速い | 数字（可読性優先） |
| `.` | 低速 | 任意文字（最小限に） |
| `[a-zA-Z0-9_]` | 速い | 識別子 |
| `\w` | 速い | 単語文字 |

```python
# 悪い例: ドットの多用
pattern = re.compile(r"user_id=.+")

# 良い例: 文字セットで制約
pattern = re.compile(r"user_id=[0-9]+")
```

### 1.4 Lazy演算子の活用

Greedy（貪欲）マッチングよりもLazy（最小）マッチングを使用し、不要なバックトラックを削減します。

```python
# 悪い例: Greedyマッチング（バックトラック多発）
pattern = re.compile(r"<tag>.*</tag>")

# 良い例: Lazyマッチング（最小マッチ）
pattern = re.compile(r"<tag>.*?</tag>")
```

### 1.5 正規表現のプリコンパイル

パイプライン処理ループ外で正規表現をコンパイルし、再利用します。

```python
# 悪い例: ループ内でコンパイル
for log_line in log_stream:
    if re.match(r"^ERROR", log_line):
        process_error(log_line)

# 良い例: 事前コンパイル
error_pattern = re.compile(r"^ERROR")
for log_line in log_stream:
    if error_pattern.match(log_line):
        process_error(log_line)
```

### 1.6 パフォーマンス最適化チェックリスト

正規表現を実装する際の確認項目:

1. アンカータグ（`^`, `$`）を使用しているか
2. 文字セットを具体的に指定しているか（`.`の多用を避ける）
3. Lazy演算子（`*?`, `+?`）を適切に使用しているか
4. プリコンパイルを実施しているか
5. 最も失敗しやすいパターンを先頭に配置しているか

---

## 2. 構造化ロギングの実装

構造化ロギングは、ログをフラットテキストではなく構造化データ（JSON等）として出力し、検索性と解析性を向上させます。

### 2.1 構造化ロギングのアーキテクチャ

**コンポーネント構成**

```
Logger → Formatter → Writer
  ↓         ↓          ↓
 bind()  構造化変換   出力先
```

| コンポーネント | 役割 | 実装例 |
|--------------|------|--------|
| Logger | ログイベント生成 | structlog.get_logger() |
| Formatter | 構造化変換 | JSONRenderer, KeyValueRenderer |
| Writer | 出力先制御 | StreamWriter, FileWriter |

### 2.2 Python structlogによる実装

#### 基本設定

```python
import structlog

# Loggerの設定
structlog.configure(
    processors=[
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
)

logger = structlog.get_logger()
```

#### コンテキスト情報のbind

```python
# リクエストごとにコンテキストをbind
logger = logger.bind(
    user_id="12345",
    request_id="abc-def-ghi",
    service="api"
)

# 構造化ログ出力
logger.info("user_login", method="oauth", provider="google")
```

**出力例（JSON）**

```json
{
  "event": "user_login",
  "user_id": "12345",
  "request_id": "abc-def-ghi",
  "service": "api",
  "method": "oauth",
  "provider": "google",
  "timestamp": "2025-02-10T12:34:56.789Z",
  "level": "info"
}
```

### 2.3 Formatterチェーンの設計

**判断テーブル: Formatter選択**

| Formatter | 用途 | 可読性 | 解析性 |
|-----------|------|-------|-------|
| JSONRenderer | 本番環境 | 低 | 高 |
| KeyValueRenderer | 開発環境 | 中 | 中 |
| ConsoleRenderer | デバッグ | 高 | 低 |

```python
import structlog

# 開発環境用設定
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.dev.ConsoleRenderer()
    ]
)

# 本番環境用設定
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ]
)
```

### 2.4 構造化ログのフィールド設計

**推奨フィールド**

| フィールド | 型 | 必須 | 説明 |
|----------|---|-----|------|
| timestamp | ISO8601 | ✓ | イベント発生時刻 |
| level | string | ✓ | ログレベル（info/error等） |
| event | string | ✓ | イベント名 |
| service | string | ✓ | サービス識別子 |
| request_id | string | △ | リクエスト追跡ID |
| user_id | string | △ | ユーザー識別子 |
| error | object | △ | エラー詳細 |

```python
# 良い例: 明確なフィールド構造
logger.info(
    "payment_processed",
    amount=100.50,
    currency="USD",
    payment_method="credit_card",
    transaction_id="txn_12345"
)

# 悪い例: 非構造化メッセージ
logger.info("Payment of $100.50 processed via credit card (txn_12345)")
```

---

## 3. ファイル以外への出力技法

### 3.1 TCP vs UDP プロトコル選択

**判断テーブル: プロトコル選択基準**

| 要件 | TCP | UDP | 推奨 |
|-----|-----|-----|------|
| 信頼性が必須 | ✓ | ✗ | TCP |
| 低レイテンシ優先 | ✗ | ✓ | UDP |
| 順序保証が必要 | ✓ | ✗ | TCP |
| ネットワーク不安定 | ✓ | ✗ | TCP |
| 高スループット | △ | ✓ | UDP |
| メトリクス送信 | △ | ✓ | UDP |
| エラーログ送信 | ✓ | △ | TCP |

#### TCP実装例

```python
import socket
import json

# TCPソケット設定
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(("telemetry-server.example.com", 5140))

# ログ送信
log_entry = {
    "timestamp": "2025-02-10T12:34:56Z",
    "level": "error",
    "message": "Database connection failed"
}
sock.sendall(json.dumps(log_entry).encode('utf-8') + b'\n')
sock.close()
```

#### UDP実装例

```python
import socket
import json

# UDPソケット設定
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# メトリクス送信
metric = {
    "name": "http_requests_total",
    "value": 1234,
    "timestamp": 1707564896
}
sock.sendto(json.dumps(metric).encode('utf-8'), ("metrics-server.example.com", 8125))
sock.close()
```

### 3.2 Kubernetes環境でのテレメトリー

#### 3.2.1 stdoutへのルーティング

コンテナ内アプリケーションは標準出力（stdout）にログを出力し、Kubernetesがログを収集します。

```python
import sys
import json

# stdout出力（Kubernetesが自動収集）
log_entry = {
    "timestamp": "2025-02-10T12:34:56Z",
    "level": "info",
    "service": "api",
    "message": "Request processed"
}
print(json.dumps(log_entry), file=sys.stdout, flush=True)
```

**Kubernetes Logging Stack**

```
Pod (stdout) → Node Agent (FluentD/Fluentbit) → Elasticsearch/Loki
```

#### 3.2.2 Sidecarパターン

アプリケーションコンテナと並行してログ収集コンテナを配置します。

```yaml
# Podマニフェスト例
apiVersion: v1
kind: Pod
metadata:
  name: app-with-sidecar
spec:
  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  - name: log-collector
    image: fluent/fluent-bit:latest
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  volumes:
  - name: logs
    emptyDir: {}
```

#### 3.2.3 統一フォーマットへのルーティング

複数サービスのログを統一フォーマットに変換します。

**FluentDフィルター設定例**

```conf
<filter kubernetes.**>
  @type parser
  key_name log
  <parse>
    @type json
  </parse>
</filter>

<filter kubernetes.**>
  @type record_transformer
  <record>
    cluster_name ${CLUSTER_NAME}
    namespace ${record["kubernetes"]["namespace_name"]}
    pod_name ${record["kubernetes"]["pod_name"]}
  </record>
</filter>
```

### 3.3 Serverless/FaaS環境でのテレメトリー

**判断テーブル: クラウドプロバイダー別実装**

| プロバイダー | ロギング先 | メトリクス先 | トレース先 |
|------------|-----------|------------|-----------|
| AWS Lambda | CloudWatch Logs | CloudWatch Metrics | X-Ray |
| Azure Functions | Application Insights | Application Insights | Application Insights |
| Google Cloud Functions | Cloud Logging | Cloud Monitoring | Cloud Trace |

#### AWS Lambda実装例

```python
import json
import boto3

cloudwatch = boto3.client('logs')

def lambda_handler(event, context):
    log_entry = {
        "timestamp": context.get_remaining_time_in_millis(),
        "request_id": context.request_id,
        "event": "function_invoked",
        "input": event
    }

    # CloudWatch Logsへ出力（stdout経由）
    print(json.dumps(log_entry))

    return {"statusCode": 200}
```

---

## 4. カーディナリティ管理

カーディナリティ（一意な値の数）は、時系列データベースやログデータベースのパフォーマンスに直接影響します。

### 4.1 時系列データベースのカーディナリティ

#### Prometheusのメモリ制限

```
メモリ使用量 ≈ カーディナリティ × サンプル保持期間 × サンプルサイズ
```

**判断テーブル: ラベル設計**

| ラベル種類 | カーディナリティ | 推奨 | 例 |
|----------|----------------|------|-----|
| 静的ラベル | 低（<100） | ✓ | `service`, `environment` |
| 動的ラベル（制限あり） | 中（<1000） | △ | `status_code`, `method` |
| ユーザーID | 高（>10000） | ✗ | `user_id`, `session_id` |
| タイムスタンプ | 超高（無限） | ✗ | `timestamp`, `request_id` |

```python
# 悪い例: 高カーディナリティラベル
http_requests_total.labels(
    user_id="12345",  # 数百万の一意値
    request_id="abc-def"  # 無限の一意値
).inc()

# 良い例: 低カーディナリティラベル
http_requests_total.labels(
    method="GET",  # 10未満の値
    status="200",  # 10未満の値
    endpoint="/api/users"  # 数百の値
).inc()
```

#### InfluxDBの明示的制限

InfluxDBは`max-series-per-database`設定でカーディナリティを制限します。

```toml
# influxdb.conf
[data]
max-series-per-database = 1000000
max-values-per-tag = 100000
```

### 4.2 ログデータベースのカーディナリティ

#### Elasticsearchのフィールド爆発

動的マッピングにより、一意なフィールド名が無制限に生成される問題。

```python
# 悪い例: 動的フィールド名（フィールド爆発）
logger.info("metric", **{f"user_{user_id}_count": count})
# 結果: user_12345_count, user_67890_count, ... (数百万フィールド)

# 良い例: 固定フィールド名+値
logger.info("metric", user_id=user_id, metric_name="count", value=count)
```

**Elasticsearch Index Mapping**

```json
{
  "mappings": {
    "properties": {
      "user_id": {"type": "keyword"},
      "metric_name": {"type": "keyword"},
      "value": {"type": "long"}
    }
  }
}
```

#### MongoDBのインデックス管理

```javascript
// 悪い例: 高カーディナリティフィールドにインデックス
db.logs.createIndex({ "request_id": 1 })  // 数百万の一意値

// 良い例: 低カーディナリティフィールドにインデックス
db.logs.createIndex({ "level": 1, "service": 1 })  // 数十の一意値
```

### 4.3 カーディナリティ削減戦略

**判断テーブル: 削減手法**

| 手法 | 適用対象 | カーディナリティ削減率 |
|-----|---------|---------------------|
| ラベル除去 | 不要な識別子 | 90%+ |
| 値のバケット化 | 連続値 | 95%+ |
| サンプリング | 高頻度イベント | 50-99% |
| 集約 | 時系列データ | 80%+ |

#### ラベル除去

```python
# Before: カーディナリティ = ユーザー数 × エンドポイント数
metric.labels(user_id=user_id, endpoint=endpoint)

# After: カーディナリティ = エンドポイント数のみ
metric.labels(endpoint=endpoint)
```

#### 値のバケット化

```python
# Before: 連続値（無限カーディナリティ）
response_time_seconds.labels(duration=3.14159)

# After: バケット化（10段階）
def bucket_duration(duration):
    buckets = [0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0, 120.0]
    for i, threshold in enumerate(buckets):
        if duration < threshold:
            return f"le_{threshold}"
    return "le_inf"

response_time_seconds.labels(duration_bucket=bucket_duration(3.14159))
```

#### サンプリング

```python
import random

# 1%サンプリング
if random.random() < 0.01:
    logger.info("detailed_event", user_id=user_id, details=details)
else:
    logger.info("aggregated_event", event_count=1)
```
