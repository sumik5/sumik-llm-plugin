# 監視・ロギング・トラブルシューティング

Cloud Run アプリケーションの包括的な可観測性を実現するための実践ガイド。Cloud Monitoring、Cloud Logging、Cloud Trace を活用した監視・分析手法。

## Cloud Monitoring

### 標準メトリクス（リクエスト数、レイテンシ、エラー率）

**主要メトリクス一覧:**

| メトリクス | 説明 | 用途 |
|----------|------|------|
| `run.googleapis.com/request_latencies` | リクエスト処理時間 | パフォーマンス監視 |
| `run.googleapis.com/request_count` | リクエスト数 | トラフィック分析 |
| `run.googleapis.com/container/cpu/utilization` | CPU使用率 | リソース最適化 |
| `run.googleapis.com/container/memory/utilization` | メモリ使用率 | メモリリーク検出 |
| `run.googleapis.com/instance_count` | アクティブインスタンス数 | スケーリング分析 |

**MQL クエリ例:**
```mql
# 平均リクエストレイテンシ（1分集計）
fetch cloud_run_revision
| metric 'run.googleapis.com/request_latencies'
| filter (resource.labels.service_name == "my-app")
| align mean(1m)
| every 1m

# リクエスト数（レート計算）
fetch cloud_run_revision
| metric 'run.googleapis.com/request_count'
| filter (resource.service_name == "my-app")
| align rate(1m)
| every 1m

# CPU使用率
fetch cloud_run_revision
| metric 'run.googleapis.com/container/cpu/utilization'
| filter (resource.labels.service_name == "my-app")
| align mean(1m)
| every 1m
```

### カスタムメトリクス

**OpenTelemetry による計装:**
```javascript
// Node.js 例
const { MeterProvider } = require('@opentelemetry/sdk-metrics');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');

const exporter = new PrometheusExporter({ port: 9464 });
const meterProvider = new MeterProvider();
meterProvider.addMetricReader(exporter);

const meter = meterProvider.getMeter('my-app');
const requestCounter = meter.createCounter('custom_request_count');

// リクエストごとにカウント
app.use((req, res, next) => {
  requestCounter.add(1, { route: req.path });
  next();
});
```

**ログベースメトリクス:**
```bash
# Cloud Logging でカスタムメトリクス作成
gcloud logging metrics create http_5xx_count \
  --description="Count of HTTP 5xx errors" \
  --log-filter='resource.type="cloud_run_revision"
    resource.labels.service_name="my-app"
    httpRequest.status>=500'
```

### ダッシュボード設定

**JSON API でダッシュボード作成:**
```bash
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -d '{
    "displayName": "Cloud Run Service Performance",
    "gridLayout": {
      "columns": 2,
      "widgets": [
        {
          "title": "Request Latency",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "query": "fetch cloud_run_revision | metric \"run.googleapis.com/request_latencies\" | filter (resource.labels.service_name == \"my-app\") | align mean(1m) | every 1m"
              }
            }]
          }
        },
        {
          "title": "CPU Utilization",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "query": "fetch cloud_run_revision | metric \"run.googleapis.com/container/cpu/utilization\" | filter (resource.labels.service_name == \"my-app\") | align mean(1m) | every 1m"
              }
            }]
          }
        }
      ]
    }
  }' \
  "https://monitoring.googleapis.com/v3/projects/my-project/dashboards"
```

**ダッシュボード構成要素:**
- リクエストレイテンシ（時系列グラフ）
- CPU・メモリ使用率（折れ線グラフ）
- アクティブインスタンス数（積み上げグラフ）
- エラー率（ゲージ）

## Cloud Logging

### 構造化ロギング

**Node.js 例:**
```javascript
// JSON形式の構造化ログ
console.log(JSON.stringify({
  timestamp: new Date().toISOString(),
  severity: "INFO",
  message: "User login successful",
  userId: "123456",
  requestId: "req-7890"
}));
```

**Python 例:**
```python
import json
import logging

# 構造化ロガー設定
logging.basicConfig(format='%(message)s', level=logging.INFO)

def log_structured(severity, message, **kwargs):
    log_entry = {
        "severity": severity,
        "message": message,
        **kwargs
    }
    logging.info(json.dumps(log_entry))

# 使用例
log_structured("INFO", "Request processed", user_id="123", duration_ms=45)
```

### ログフィルタリング

**基本フィルタ:**
```bash
# エラーログのみ取得
gcloud logging read \
  "resource.type=cloud_run_revision
   resource.labels.service_name=my-app
   severity>=ERROR" \
  --limit 100

# 特定期間のログ
gcloud logging read \
  "resource.type=cloud_run_revision
   timestamp>=\"2024-01-01T00:00:00Z\"
   timestamp<=\"2024-01-31T23:59:59Z\"" \
  --limit 1000

# 特定リクエストIDのログ
gcloud logging read \
  "resource.type=cloud_run_revision
   jsonPayload.requestId=\"req-7890\"" \
  --limit 50
```

**Logs Explorer の高度なクエリ:**
```
resource.type="cloud_run_revision"
resource.labels.service_name="my-app"
severity>=ERROR
httpRequest.status>=500
jsonPayload.userId="123456"
```

### ログベースアラート

**アラートポリシー作成:**
```bash
# エラー率が5%超で5分継続した場合アラート
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="High Error Rate Alert" \
  --condition-display-name="Error rate > 5%" \
  --condition-threshold-value=0.05 \
  --condition-threshold-duration=300s \
  --condition-filter='metric.type="logging.googleapis.com/user/http_5xx_count"
    resource.type="cloud_run_revision"
    resource.labels.service_name="my-app"'
```

## 分散トレーシング

### Cloud Trace 連携

**自動トレース収集:**
- Cloud Run はデフォルトで基本的なトレースを自動生成
- `X-Cloud-Trace-Context` ヘッダーでトレース伝播

**OpenTelemetry 計装（Node.js）:**
```javascript
const { NodeTracerProvider } = require('@opentelemetry/node');
const { SimpleSpanProcessor } = require('@opentelemetry/tracing');
const { TraceExporter } = require('@google-cloud/opentelemetry-cloud-trace-exporter');

// トレーサー設定
const provider = new NodeTracerProvider();
const exporter = new TraceExporter();
provider.addSpanProcessor(new SimpleSpanProcessor(exporter));
provider.register();

// Express アプリケーション例
const express = require('express');
const app = express();

app.get('/process', (req, res) => {
  const span = provider.getTracer('default').startSpan('handle-request');

  // 処理シミュレーション
  setTimeout(() => {
    span.addEvent('Finished processing request');
    span.end();
    res.send('Request processed successfully');
  }, 200);
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
```

### OpenTelemetry 統合

**トレースコンテキスト伝播:**
```javascript
const http = require('http');

function makeDownstreamRequest(traceId) {
  const options = {
    hostname: 'downstream-service.example.com',
    port: 80,
    path: '/process',
    method: 'GET',
    headers: {
      'X-Cloud-Trace-Context': traceId
    }
  };

  const req = http.request(options, (res) => {
    console.log(`Status: ${res.statusCode}`);
  });

  req.on('error', (e) => {
    console.error(e);
  });

  req.end();
}
```

**トレース分析:**
- スパン単位でレイテンシを分解
- ボトルネックとなるサービス・関数を特定
- エラー発生箇所を追跡

## アラート設定

### アラートポリシー

**高レイテンシアラート:**
```mql
fetch cloud_run_revision
| metric 'run.googleapis.com/request_latencies'
| filter (resource.labels.service_name == "my-app")
| align mean(1m)
| every 1m
| condition gt(val, 0.5)  # 500ms超
```

**エラー率アラート:**
```mql
fetch cloud_run_revision
| metric 'run.googleapis.com/request_count'
| filter (resource.labels.service_name == "my-app")
| filter (metric.labels.response_code_class == "5xx")
| align rate(1m)
| every 1m
| condition gt(val, 0.05)  # 5%超
```

**リソース枯渇アラート:**
```mql
fetch cloud_run_revision
| metric 'run.googleapis.com/container/cpu/utilization'
| filter (resource.labels.service_name == "my-app")
| align mean(1m)
| every 1m
| condition gt(val, 0.8)  # CPU 80%超
```

### 通知チャネル

**メール通知:**
```bash
gcloud alpha monitoring channels create \
  --display-name="Ops Team Email" \
  --type=email \
  --channel-labels=email_address=ops@example.com
```

**Slack 統合:**
```bash
gcloud alpha monitoring channels create \
  --display-name="Slack #alerts" \
  --type=slack \
  --channel-labels=url=https://hooks.slack.com/services/XXX/YYY/ZZZ
```

**PagerDuty 統合:**
```bash
gcloud alpha monitoring channels create \
  --display-name="PagerDuty On-Call" \
  --type=pagerduty \
  --channel-labels=service_key=YOUR_PAGERDUTY_KEY
```

### インシデント対応

**アラート受信時の対応フロー:**
1. **初動確認**: Cloud Logging・Traceでエラー詳細確認
2. **影響範囲特定**: ダッシュボードでユーザー影響を評価
3. **緊急対応**: 必要に応じてロールバック実施
4. **根本原因分析**: ログ・トレースから原因特定
5. **恒久対策**: コード修正・設定変更を実施

## トラブルシューティングガイド

### よくある問題と解決策

| 問題 | 症状 | 解決策 |
|------|------|--------|
| **コールドスタート遅延** | 初回リクエストが遅い | concurrency増加、イメージ最適化、CPU Boost活用 |
| **メモリ不足** | OOM エラー、コンテナ再起動 | メモリ割り当て増加（512Mi→1024Mi） |
| **高レイテンシ** | 応答時間が500ms超 | CPU増加、concurrency削減、コード最適化 |
| **エラー率上昇** | HTTP 5xxエラー増加 | ログ確認、依存サービス調査、ロールバック |
| **スケーリング不足** | リクエスト失敗・タイムアウト | max-instances増加、concurrency調整 |
| **ネットワーク接続エラー** | VPC内リソースアクセス失敗 | VPCコネクタ確認、ファイアウォールルール検証 |

### 診断コマンド集

**サービス状態確認:**
```bash
# 詳細情報取得
gcloud run services describe my-app --region us-central1

# 現在のリビジョン一覧
gcloud run revisions list --service my-app --region us-central1

# トラフィック分割状況
gcloud run services describe my-app --region us-central1 --format="value(spec.traffic)"
```

**ログ分析:**
```bash
# 最新のエラーログ
gcloud logging read \
  "resource.type=cloud_run_revision
   resource.labels.service_name=my-app
   severity>=ERROR" \
  --limit 20 \
  --format json

# リクエストごとのレイテンシ
gcloud logging read \
  "resource.type=cloud_run_revision
   httpRequest.latency>0" \
  --format="table(timestamp,httpRequest.requestUrl,httpRequest.latency)"
```

**メトリクス確認:**
```bash
# CPU使用率の時系列データ取得
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/cpu/utilization"
    resource.labels.service_name="my-app"' \
  --format=json
```

### パフォーマンス最適化チェックリスト

- [ ] リクエストレイテンシが目標値（例：200ms）以下
- [ ] CPU使用率が80%未満
- [ ] メモリ使用率が80%未満
- [ ] エラー率が1%未満
- [ ] コールドスタート頻度が低い（インスタンス再利用率が高い）
- [ ] ログにエラー・警告が頻出していない
- [ ] トレースでボトルネックが特定されていない

## ダッシュボード設計例

### 標準ダッシュボード構成

**セクション1: 概要**
- リクエスト数（24時間）
- 平均レイテンシ（24時間）
- エラー率（24時間）
- アクティブインスタンス数

**セクション2: パフォーマンス**
- リクエストレイテンシ分布（P50, P95, P99）
- CPU使用率（時系列）
- メモリ使用率（時系列）
- ネットワークトラフィック

**セクション3: スケーリング**
- インスタンス数推移
- concurrency 使用状況
- コールドスタート頻度

**セクション4: エラー・アラート**
- HTTP ステータスコード分布
- エラーログ一覧
- アクティブアラート

## ロギングベストプラクティス

### ログレベル設定

| 環境 | ログレベル | 理由 |
|-----|-----------|------|
| **本番** | INFO | パフォーマンス重視、重要イベントのみ記録 |
| **ステージング** | DEBUG | 詳細なデバッグ情報が必要 |
| **開発** | DEBUG | 開発時の詳細トレース |

**環境変数で制御:**
```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --set-env-vars "LOG_LEVEL=INFO" \
  --allow-unauthenticated
```

### ログ保持期間

```bash
# ログバケットの保持期間を90日に設定
gcloud logging buckets update _Default \
  --location=global \
  --retention-days=90
```

### ログのエクスポート

**BigQuery へのエクスポート:**
```bash
gcloud logging sinks create my-bigquery-sink \
  bigquery.googleapis.com/projects/my-project/datasets/cloud_run_logs \
  --log-filter='resource.type="cloud_run_revision" AND severity>=ERROR'
```

**Cloud Storage へのエクスポート:**
```bash
gcloud logging sinks create my-storage-sink \
  storage.googleapis.com/my-log-bucket \
  --log-filter='resource.type="cloud_run_revision" AND severity>=ERROR'
```

## 継続的改善

### パフォーマンス分析サイクル

1. **週次レビュー**: ダッシュボード確認、異常検出
2. **月次監査**: リソース使用率分析、コスト最適化
3. **四半期評価**: パフォーマンス目標達成状況、設定見直し

### SLO（Service Level Objective）設定例

| SLI（指標） | SLO（目標） |
|-----------|-----------|
| 可用性 | 99.9%以上 |
| レイテンシ（P95） | 500ms以下 |
| エラー率 | 1%未満 |
| リクエスト成功率 | 99.5%以上 |
