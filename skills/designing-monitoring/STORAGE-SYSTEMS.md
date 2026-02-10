# テレメトリーストレージシステム比較

## 1. ストレージシステム評価基準

テレメトリーストレージを選定する際の3つの主要評価軸：

| 評価軸 | 定義 | 重要度 |
|-------|------|-------|
| **Ingestion Rate** | 単位時間あたりの書き込み可能データ量 | 高 |
| **Query Rate** | 単位時間あたりのクエリ処理能力 | 高 |
| **Cardinality** | 扱える一意な値の数（メタデータの多様性） | 中 |

---

## 2. ログストレージシステム

### 2.1 Elasticsearch

**特徴**
- 全文検索エンジンベース
- RESTful API
- 動的スキーマ（スキーマレス）

**アーキテクチャ**

```
Ingest → Index → Shard → Query
  ↓        ↓       ↓       ↓
Bulk API  倒置索引  分散配置  DSL
```

**パフォーマンス指標**

| 指標 | 値 | 備考 |
|-----|---|------|
| Ingestion Rate | 50k-200k events/sec | ノード数・ハードウェア依存 |
| Query Rate | 100-1000 queries/sec | クエリ複雑度依存 |
| Cardinality | 高（制約なし） | フィールド爆発に注意 |

**推奨構成**

```yaml
# Elasticsearch設定例
cluster.name: telemetry-cluster
node.name: node-1
node.roles: [ master, data, ingest ]

# インデックステンプレート
PUT _index_template/logs-template
{
  "index_patterns": ["logs-*"],
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1,
      "refresh_interval": "30s"
    },
    "mappings": {
      "properties": {
        "timestamp": {"type": "date"},
        "level": {"type": "keyword"},
        "message": {"type": "text"},
        "service": {"type": "keyword"}
      }
    }
  }
}
```

**最適化技法**

| 技法 | 効果 | 実装方法 |
|-----|------|---------|
| Bulk Indexing | Ingestion Rate 10倍向上 | Bulk APIの使用 |
| Index Lifecycle Management | ストレージコスト削減 | ILMポリシー設定 |
| Shard最適化 | Query Rate向上 | `number_of_shards`調整 |

**Python実装例（Bulk Indexing）**

```python
from elasticsearch import Elasticsearch, helpers

es = Elasticsearch(['http://localhost:9200'])

def bulk_index_logs(logs):
    actions = [
        {
            "_index": "logs-2025.02.10",
            "_source": {
                "timestamp": log["timestamp"],
                "level": log["level"],
                "message": log["message"],
                "service": log["service"]
            }
        }
        for log in logs
    ]
    helpers.bulk(es, actions)

# バッチサイズ500-1000推奨
logs_batch = fetch_logs(batch_size=1000)
bulk_index_logs(logs_batch)
```

**使用判断テーブル**

| 要件 | Elasticsearch適合度 | 代替案 |
|-----|------------------|-------|
| 全文検索必須 | ✓✓✓ | - |
| 構造化クエリのみ | △ | Loki, Cassandra |
| 低コスト | ✗ | Loki |
| リアルタイム検索 | ✓✓ | - |

---

### 2.2 Loki

**特徴**
- Grafana Labs開発
- ラベルベースインデックス（ログ本文は非インデックス）
- コスト効率重視

**アーキテクチャ**

```
Promtail → Distributor → Ingester → Querier
   ↓          ↓            ↓          ↓
ログ収集   ラベル抽出   チャンク作成  LogQL実行
```

**パフォーマンス指標**

| 指標 | 値 | 備考 |
|-----|---|------|
| Ingestion Rate | 10k-50k events/sec | Elasticsearchより低速 |
| Query Rate | 50-200 queries/sec | ラベルクエリは高速 |
| Cardinality | 低-中 | ラベル数制限推奨（<30） |

**推奨構成**

```yaml
# Loki設定例
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1

schema_config:
  configs:
    - from: 2025-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
  max_label_name_length: 1024
  max_label_value_length: 2048
  max_label_names_per_series: 30
```

**Promtail設定例**

```yaml
# promtail-config.yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*.log
```

**LogQLクエリ例**

```python
import requests

# ラベルフィルタークエリ
query = '{service="api", level="error"}'
params = {
    'query': query,
    'start': '2025-02-10T00:00:00Z',
    'end': '2025-02-10T23:59:59Z',
    'limit': 1000
}
response = requests.get('http://loki:3100/loki/api/v1/query_range', params=params)
```

**使用判断テーブル**

| 要件 | Loki適合度 | 代替案 |
|-----|----------|-------|
| コスト削減 | ✓✓✓ | - |
| 全文検索 | ✗ | Elasticsearch |
| Grafana統合 | ✓✓✓ | - |
| 高カーディナリティ | ✗ | Elasticsearch |

---

### 2.3 MongoDB

**特徴**
- ドキュメント指向NoSQL
- 柔軟なスキーマ
- 地理空間クエリ対応

**パフォーマンス指標**

| 指標 | 値 | 備考 |
|-----|---|------|
| Ingestion Rate | 20k-100k events/sec | Bulk Write使用時 |
| Query Rate | 100-500 queries/sec | インデックス依存 |
| Cardinality | 高 | ドキュメント構造自由 |

**推奨構成**

```javascript
// MongoDBインデックス設定
db.logs.createIndex(
  { "timestamp": -1, "level": 1, "service": 1 },
  { background: true }
)

// TTLインデックス（自動削除）
db.logs.createIndex(
  { "timestamp": 1 },
  { expireAfterSeconds: 2592000 }  // 30日後に削除
)
```

**Python実装例（Bulk Write）**

```python
from pymongo import MongoClient, InsertOne

client = MongoClient('mongodb://localhost:27017/')
db = client['telemetry']
collection = db['logs']

def bulk_insert_logs(logs):
    operations = [InsertOne(log) for log in logs]
    result = collection.bulk_write(operations, ordered=False)
    return result.inserted_count

# バッチサイズ500-1000推奨
logs_batch = fetch_logs(batch_size=1000)
bulk_insert_logs(logs_batch)
```

**使用判断テーブル**

| 要件 | MongoDB適合度 | 代替案 |
|-----|------------|-------|
| スキーマ柔軟性 | ✓✓✓ | - |
| 全文検索 | △ | Elasticsearch |
| 地理空間クエリ | ✓✓✓ | - |
| 低レイテンシ | ✓✓ | Cassandra |

---

## 3. 時系列データベース

### 3.1 Prometheus

**特徴**
- プルベース収集
- ラベルベースデータモデル
- 強力なクエリ言語（PromQL）

**アーキテクチャ**

```
Scrape → TSDB → Query
  ↓       ↓       ↓
Pull    圧縮保存  PromQL
```

**パフォーマンス指標**

| 指標 | 値 | 備考 |
|-----|---|------|
| Ingestion Rate | 1M+ samples/sec | 単一インスタンス |
| Query Rate | 100-1000 queries/sec | クエリ複雑度依存 |
| Cardinality | 中（推奨<1M series） | メモリ制約あり |

**メモリ使用量計算**

```
メモリ (GB) ≈ カーディナリティ × 3KB
例: 100万 series × 3KB = 3GB
```

**推奨構成**

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'app'
    static_configs:
      - targets: ['localhost:8080']
    metric_relabel_configs:
      # 高カーディナリティラベル除去
      - source_labels: [user_id]
        action: labeldrop
```

**Python実装例（Pushgateway経由）**

```python
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway

registry = CollectorRegistry()
g = Gauge('job_duration_seconds', 'Job duration', ['job', 'status'], registry=registry)

g.labels(job='backup', status='success').set(123.45)
push_to_gateway('localhost:9091', job='batch', registry=registry)
```

**使用判断テーブル**

| 要件 | Prometheus適合度 | 代替案 |
|-----|---------------|-------|
| メトリクス監視 | ✓✓✓ | - |
| ログ保存 | ✗ | Loki, Elasticsearch |
| 長期保存 | △ | InfluxDB, Thanos |
| アラート | ✓✓✓ | - |

---

### 3.2 InfluxDB

**特徴**
- 時系列データ特化
- SQLライクなクエリ言語（InfluxQL, Flux）
- 長期保存対応

**パフォーマンス指標**

| 指標 | 値 | 備考 |
|-----|---|------|
| Ingestion Rate | 500k+ points/sec | バッチ書き込み時 |
| Query Rate | 100-500 queries/sec | クエリ複雑度依存 |
| Cardinality | 中（設定可能な上限） | `max-series-per-database` |

**推奨構成**

```toml
# influxdb.conf
[data]
cache-max-memory-size = "1g"
cache-snapshot-memory-size = "25m"
max-series-per-database = 1000000
max-values-per-tag = 100000

[retention]
enabled = true
check-interval = "30m"
```

**Python実装例（Batch Write）**

```python
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

client = InfluxDBClient(url="http://localhost:8086", token="my-token", org="my-org")
write_api = client.write_api(write_options=SYNCHRONOUS)

# バッチポイント作成
points = []
for i in range(1000):
    point = Point("measurement") \
        .tag("host", "server01") \
        .tag("region", "us-west") \
        .field("value", i) \
        .time(datetime.utcnow(), WritePrecision.NS)
    points.append(point)

# バッチ書き込み
write_api.write(bucket="telemetry", record=points)
```

**使用判断テーブル**

| 要件 | InfluxDB適合度 | 代替案 |
|-----|-------------|-------|
| 時系列データ | ✓✓✓ | - |
| SQLライク | ✓✓ | - |
| ログ保存 | ✗ | Elasticsearch |
| Prometheus互換 | △ | Prometheus |

---

## 4. トレーシングストレージ

### 4.1 Jaeger

**特徴**
- 分散トレーシング特化
- OpenTelemetry対応
- Zipkin互換

**アーキテクチャ**

```
Agent → Collector → Storage → Query UI
  ↓        ↓          ↓          ↓
サンプリング 集約    Cassandra/  可視化
                    Elasticsearch
```

**パフォーマンス指標**

| 指標 | 値 | 備考 |
|-----|---|------|
| Ingestion Rate | 10k-50k spans/sec | Collector数依存 |
| Query Rate | 50-200 queries/sec | ストレージ依存 |
| Cardinality | 高 | トレースID無限 |

**推奨構成**

```yaml
# jaeger-all-in-one.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: jaeger-config
data:
  sampling-strategies.json: |
    {
      "default_strategy": {
        "type": "probabilistic",
        "param": 0.01
      }
    }
```

**Python実装例（OpenTelemetry SDK）**

```python
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Jaeger Exporter設定
jaeger_exporter = JaegerExporter(
    agent_host_name="localhost",
    agent_port=6831,
)

# TracerProvider設定
provider = TracerProvider()
processor = BatchSpanProcessor(jaeger_exporter)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)

# トレース作成
tracer = trace.get_tracer(__name__)
with tracer.start_as_current_span("operation"):
    # 処理
    pass
```

**使用判断テーブル**

| 要件 | Jaeger適合度 | 代替案 |
|-----|-----------|-------|
| 分散トレーシング | ✓✓✓ | - |
| メトリクス保存 | ✗ | Prometheus |
| ログ保存 | ✗ | Loki |
| OpenTelemetry | ✓✓✓ | - |

---

## 5. データベース横断比較

### 5.1 総合比較テーブル

| DB | 種類 | Ingestion Rate | Query Rate | Cardinality | 推奨用途 |
|----|------|---------------|-----------|------------|---------|
| **Elasticsearch** | ログ | ★★★★☆ | ★★★★☆ | ★★★★★ | 全文検索ログ |
| **Loki** | ログ | ★★★☆☆ | ★★★☆☆ | ★★☆☆☆ | コスト重視ログ |
| **MongoDB** | ログ | ★★★★☆ | ★★★★☆ | ★★★★★ | スキーマ柔軟ログ |
| **Prometheus** | メトリクス | ★★★★★ | ★★★★☆ | ★★★☆☆ | メトリクス監視 |
| **InfluxDB** | メトリクス | ★★★★★ | ★★★★☆ | ★★★☆☆ | 時系列分析 |
| **Jaeger** | トレース | ★★★☆☆ | ★★★☆☆ | ★★★★★ | 分散トレーシング |

### 5.2 Cassandra（補足）

**特徴**
- 分散NoSQL
- 線形スケーラビリティ
- 高可用性

**パフォーマンス指標**

| 指標 | 値 | 備考 |
|-----|---|------|
| Ingestion Rate | 100k-1M writes/sec | クラスタサイズ依存 |
| Query Rate | 10k-100k reads/sec | パーティションキー依存 |
| Cardinality | 超高 | 制約なし |

**推奨構成（Jaegerバックエンド）**

```cql
-- Cassandraスキーマ例
CREATE KEYSPACE jaeger WITH replication = {
  'class': 'SimpleStrategy',
  'replication_factor': 3
};

CREATE TABLE jaeger.traces (
  trace_id blob,
  span_id blob,
  operation_name text,
  start_time timestamp,
  duration int,
  tags map<text, text>,
  PRIMARY KEY (trace_id, start_time, span_id)
) WITH CLUSTERING ORDER BY (start_time DESC);
```

**使用判断テーブル**

| 要件 | Cassandra適合度 | 代替案 |
|-----|--------------|-------|
| 超高スループット | ✓✓✓ | - |
| 複雑クエリ | ✗ | Elasticsearch |
| 高可用性 | ✓✓✓ | - |
| 低レイテンシ | ✓✓✓ | - |

---

## 6. ストレージ選定フローチャート

```
[テレメトリー種別判定]
    |
    ├─ ログ？
    |   ├─ 全文検索必須？ → Elasticsearch
    |   ├─ コスト重視？ → Loki
    |   └─ スキーマ柔軟性？ → MongoDB
    |
    ├─ メトリクス？
    |   ├─ Prometheus互換？ → Prometheus
    |   └─ 長期保存？ → InfluxDB
    |
    └─ トレース？
        └─ OpenTelemetry？ → Jaeger (+ Cassandra/Elasticsearch)
```

### 6.1 Kubernetesクラスタ推奨構成

| コンポーネント | 推奨製品 | 役割 |
|--------------|---------|------|
| メトリクス | Prometheus | クラスタ・Pod監視 |
| ログ | Loki または Elasticsearch | アプリケーションログ |
| ログ収集 | FluentD または Fluentbit | ログ転送 |
| トレース | Jaeger | 分散トレーシング |
| 可視化 | Grafana | 統合ダッシュボード |
