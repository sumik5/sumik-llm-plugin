# 監視・運用設計（Cloud Operations Suite）

Google Cloud の Cloud Operations Suite（旧 Stackdriver）は、Cloud Monitoring・Cloud Logging・Cloud Trace・Cloud Profiler・Cloud Debugger から構成される統合可観測性プラットフォームである。エンタープライズシステムの監視設計では「すぐに監視方法を考えるのではなく、ユーザー視点のサービスレベル目標（SLO）から逆算して実装を決める」ことが重要。本リファレンスでは SLO/SLI 定義・Cloud Monitoring・Cloud Logging・アラート戦略・ダッシュボード設計・Stackdriver 実践を解説する。

## 監視設計の基本思想

### 監視設計の流れ

```
❌ 誤ったアプローチ: インフラメトリクスを片っ端から監視する
                    → オーバーエンジニアリング・ノイズだらけのアラート

✅ 正しいアプローチ:
  1. クリティカルユーザージャーニー（CUJ）の特定
  2. SLI（サービスレベル指標）の定義
  3. SLO（サービスレベル目標）の設定
  4. SLO を満たすための監視実装
```

### モニタリング方式の分類

| 方式 | 概要 | Cloud Monitoring での実現 |
|------|------|------------------------|
| **ブラックボックスモニタリング** | ユーザー視点でサービス外部から確認 | 稼働時間チェック（Uptime Check） |
| **ホワイトボックスモニタリング** | サービス内部コンポーネントを監視 | カスタム指標（OpenTelemetry/OpenCensus） |
| **グレーボックスモニタリング** | 実行環境の状態を監視 | GCP プロダクト指標（自動収集） |
| **ログベースモニタリング** | ログを基に指標を生成 | ログベース指標 |

## SLI・SLO 設計

### クリティカルユーザージャーニー（CUJ）の特定

SLO 定義の最初のステップ。「ユーザーがサービスで何をするか」を列挙し、ビジネスインパクトが大きい順に並べる。

**EC サイトの例:**

| 優先度 | CUJ | ビジネスインパクト |
|--------|-----|----------------|
| 1 | チェックアウト（購入完了） | 売上に直結・最高優先 |
| 2 | カートに商品を追加 | 購入への前段・高優先 |
| 3 | 商品を検索する | 購入に必ずしも繋がらない |

**なぜ「検索」より「チェックアウト」が高優先か:** 検索するユーザーが必ずしも購入するわけではないが、チェックアウトするユーザーは購入の最終段階にいる。ビジネス損失への直接的影響が最大。

### SLI（サービスレベル指標）の定義

SLI 計算式: `SLI = (Good Events / Valid Events) × 100`

**サービス種別ごとの典型的な SLI:**

| サービス種別 | SLI の例 |
|------------|---------|
| リクエスト型（API/Web） | 可用性（成功率）・レイテンシ |
| データ処理パイプライン | スループット・データ鮮度・処理成功率 |
| ストレージ | 耐久性・可用性 |

**チェックアウト機能の SLI 定義例:**

```
可用性 SLI:
  測定対象: /checkout_service へのHTTP GETリクエスト
  Good Events: 5xx 以外のレスポンス（3xx / 4xx を除く）
  Valid Events: 全リクエスト（3xx / 4xx 除く）
  計測場所: 内部 L7 ロードバランサ

レイテンシ SLI:
  測定対象: /checkout_service へのHTTP GETリクエスト
  Good Events: レスポンスタイムが 500ms 以内のリクエスト
  Valid Events: 成功レスポンス（5xx 除く）
  計測場所: 内部 L7 ロードバランサ
```

### SLO の設定

SLI が決まったら、期間と目標値を設定。

| 稼働率表記 | 意味 | 月間許容ダウンタイム |
|-----------|------|-----------------|
| 99.0%（2-nine） | - | 約 7.3 時間 |
| 99.9%（3-nine） | スリーナイン | 約 43.8 分 |
| 99.95% | - | 約 21.9 分 |
| 99.99%（4-nine） | フォーナイン | 約 4.4 分 |
| 99.999%（5-nine） | ファイブナイン | 約 26 秒 |

**SLO 設定の考え方:**
- 現状のサービスレベルが十分なら「現状値 ≒ SLO」から開始
- SLO は 100% にしない（システムが常時完全であることは不可能）
- ビジネス要件から逆算し、達成可能な目標に収束させる

### エラーバジェットの活用

エラーバジェット = `100% - SLO`

SLO 99.9% の場合、月のエラーバジェットは 0.1%（≒ 43.8分）。バジェット消費速度をモニタリングし、残量が少ない場合は新機能リリースを停止してインフラ改善に集中する（SRE 原則）。

## 可用性向上の数式

```
可用性 = 1 - (MTTD + MTTM) × Impact / MTBF
```

| 指標 | 意味 | 改善方法 |
|------|------|---------|
| **MTTD**（Mean Time to Detect） | 障害検知までの平均時間 | アラートの高精度化・稼働時間チェック |
| **MTTM**（Mean Time to Mitigate） | 障害解消・軽減の平均時間 | Runbook の整備・自動復旧 |
| **MTBF**（Mean Time Between Failure） | 次の障害までの平均時間 | 冗長化・信頼性向上 |
| **Impact** | 影響を受けるユーザーの割合 | マルチリージョン・カナリアデプロイ |

**例:** 月 1 回の障害、MTTD=45分、MTTM=135分、Impact=50% の場合：
可用性 ≈ 1 - (180分/60)×0.5 / (30日×24時間) = 約 99.79%

## Cloud Monitoring

### 指標の種類

| 指標タイプ（Kind） | 意味 | 例 |
|----------------|------|-----|
| **GAUGE（ゲージ）** | ある時点の値 | CPU 使用率・メモリ使用量 |
| **DELTA（デルタ）** | 期間内の変化量 | リクエスト数の増加分 |
| **CUMULATIVE（累積）** | 開始からの累積値 | 総リクエスト数 |

GCP プロダクトの指標は自動収集（約 1,500 種類の組み込み指標記述子）。VM・ミドルウェアのカスタム指標は Ops Agent またはカスタムライブラリで収集。

### アラートポリシーの設定

```bash
# gcloud によるアラートポリシー作成例
gcloud monitoring policies create \
  --policy-from-file=alert-policy.json
```

```json
{
  "displayName": "High Error Rate Alert",
  "conditions": [
    {
      "displayName": "Error rate > 1%",
      "conditionThreshold": {
        "filter": "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0.01,
        "duration": "60s",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ]
      }
    }
  ],
  "notificationChannels": ["projects/PROJECT_ID/notificationChannels/CHANNEL_ID"],
  "documentation": {
    "content": "## 対応手順\n1. Cloud Run ログを確認\n2. エラートレースを確認\n3. Runbook: https://..."
  }
}
```

### アラート通知チャネル

| 通知先 | ユースケース |
|-------|-----------|
| Email | 非緊急の通知 |
| PagerDuty / OpsGenie | オンコール体制のインシデント管理 |
| Slack | チームへのリアルタイム通知 |
| Webhook | カスタム自動化（チケット登録等） |
| Pub/Sub | 自動復旧スクリプトのトリガー |
| Cloud Mobile App | モバイルでのインシデント確認 |

**アラート設計の原則:**
- アラートは「アクションが必要な状態」のみを通知する（ノイズを最小化）
- 重要度に応じて通知先を分ける（P1 → PagerDuty + Slack、P3 → Email のみ）
- アラートポリシーにドキュメント（Runbook への URL）を含める

## Cloud Logging

### ログ収集アーキテクチャ

```
アプリケーション / GCP プロダクト
        ↓
Cloud Logging API（自動 or エージェント経由）
        ↓
ログルーター（取り込む / エクスポート / 破棄）
        ↓
    ┌───────────────────────────────┐
    │ ログバケット（デフォルト: 30日）│
    │ BigQuery（長期分析）           │
    │ Cloud Storage（アーカイブ）    │
    │ Pub/Sub（リアルタイム処理）    │
    └───────────────────────────────┘
```

### ログの種類と課金

| ログ種別 | 課金 | 保持期間（デフォルト） |
|---------|------|-------------------|
| **管理者アクティビティ監査ログ** | 無料 | 400日 |
| **データアクセス監査ログ** | 有料（デフォルト無効） | 30日 |
| **システムイベント監査ログ** | 無料 | 400日 |
| **GCP プロダクトのプラットフォームログ** | 有料 | 30日 |
| **ユーザー定義ログ（アプリケーション）** | 有料 | 30日 |

**コスト最適化:** ログルーターで不要なログを除外（_Default の Exclusion Filter）することで課金対象から除外できる。

### 構造化ログの実装

```python
# Python: Cloud Run / App Engine での構造化ログ
import json
import logging
import sys
from typing import Any

class StructuredLogger:
    def __init__(self, service_name: str):
        self.service_name = service_name

    def _log(self, severity: str, message: str, **kwargs: Any) -> None:
        entry = {
            "severity": severity,
            "message": message,
            "service": self.service_name,
            **kwargs
        }
        print(json.dumps(entry, ensure_ascii=False), file=sys.stdout)

    def info(self, message: str, **kwargs: Any) -> None:
        self._log("INFO", message, **kwargs)

    def error(self, message: str, **kwargs: Any) -> None:
        self._log("ERROR", message, **kwargs)

logger = StructuredLogger("checkout-service")
logger.info("Order processed", order_id="ord-123", amount=4980, user_id="usr-456")
logger.error("Payment failed", order_id="ord-124", error_code="insufficient_funds")
```

```bash
# ログエクスプローラーでのクエリ例
# エラーログのフィルタリング
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity="ERROR"' \
  --limit=100 \
  --format=json

# ログベース指標の作成（エラー率計測用）
gcloud logging metrics create checkout-errors \
  --description="Checkout service 5xx errors" \
  --log-filter='resource.type="cloud_run_revision" AND httpRequest.status>=500'
```

### ログシンクの設定（長期保存・分析）

```bash
# BigQuery へのエクスポート（長期分析用）
gcloud logging sinks create production-logs-bq \
  bigquery.googleapis.com/projects/PROJECT_ID/datasets/logs_dataset \
  --log-filter='resource.type="cloud_run_revision" AND severity>=WARNING'

# Cloud Storage へのエクスポート（アーカイブ用）
gcloud logging sinks create production-logs-gcs \
  storage.googleapis.com/my-logs-archive \
  --log-filter='resource.type="cloud_run_revision"'
```

## ダッシュボード設計

### エンタープライズ監視ダッシュボード構成

**4つのゴールデンシグナル（Google SRE Book）:**

| シグナル | 指標例 | 説明 |
|---------|-------|------|
| **レイテンシ** | p50/p95/p99 レスポンスタイム | 「遅いリクエスト」の検出 |
| **トラフィック** | リクエスト/秒（RPS） | 負荷の把握 |
| **エラー** | 5xx エラー率 | 障害の早期検出 |
| **飽和度** | CPU/メモリ/ディスク使用率 | リソース枯渇の予測 |

```bash
# カスタムダッシュボードの作成
gcloud monitoring dashboards create \
  --config-from-file=dashboard.json
```

**ダッシュボード設計の原則:**
- トップレベルに「サービス全体の健全性」（SLI/SLO バーン率）を配置
- 次レベルに「4つのゴールデンシグナル」
- 深掘り用に個別コンポーネント・DB クエリレイテンシ等を配置
- アラートダッシュボードとは別に「トレンド分析ダッシュボード」を用意

## Stackdriver 実践（Programmer 向けサービス統合）

### Cloud Trace（分散トレーシング）

マイクロサービス間のリクエスト伝播を可視化し、レイテンシのボトルネックを特定する。

```python
# Python: Cloud Trace の統合
from opentelemetry import trace
from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# トレーサーの初期化
provider = TracerProvider()
provider.add_span_processor(
    BatchSpanProcessor(CloudTraceSpanExporter())
)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

# トレースの記録
with tracer.start_as_current_span("checkout") as span:
    span.set_attribute("order.id", "ord-123")
    span.set_attribute("user.id", "usr-456")
    # チェックアウト処理...
    result = process_checkout(order_id="ord-123")
    span.set_attribute("payment.status", result.status)
```

### Cloud Profiler（パフォーマンスプロファイリング）

本番環境のアプリケーションのプロファイルを継続的に収集し、CPU・メモリの使用状況を分析する。オーバーヘッドは 0.5% 以下。

### Uptime Check（稼働時間チェック）

```bash
# HTTP/HTTPS 稼働時間チェックの作成
gcloud monitoring uptime-check-configs create \
  --display-name="Checkout API Health Check" \
  --http-check-path="/health" \
  --http-check-port=443 \
  --monitored-resource=uptime_url \
  --hostname="api.example.com"
```

## Stackdriver ログによる App Engine / GCE 監視（旧来の知見）

### App Engine のログ収集

App Engine Standard 環境では標準出力・標準エラー出力が自動的に Cloud Logging に収集される（追加設定不要）。GAE のリクエストログ・アプリケーションログ・エラーログを統合的に管理できる。

### GCE の Ops Agent 設定

```yaml
# /etc/google-cloud-ops-agent/config.yaml
metrics:
  receivers:
    nginx:
      type: nginx
  service:
    pipelines:
      default_pipeline:
        receivers: [nginx]

logging:
  receivers:
    nginx-access:
      type: files
      include_paths: [/var/log/nginx/access.log]
    nginx-error:
      type: files
      include_paths: [/var/log/nginx/error.log]
  service:
    pipelines:
      default_pipeline:
        receivers: [nginx-access, nginx-error]
```

## エンタープライズ監視設計パターン

### 既存監視ツールとの併用戦略

多くのエンタープライズ企業は既存の監視ツール（Zabbix・Datadog・Splunk 等）を保有している。Cloud Monitoring への完全移行は運用手順書変更・教育コストが発生するため、段階的アプローチを推奨。

| フェーズ | 方針 |
|---------|------|
| **Phase 1（移行初期）** | 既存ツールをメインに使用し、Cloud Monitoring を補助的に活用 |
| **Phase 2（安定期）** | GCP プロダクト固有の指標は Cloud Monitoring で確認 |
| **Phase 3（成熟期）** | Cloud Monitoring をメインに移行（コスト・統合性のメリット） |

**Cloud Monitoring を補助的に使うメリット:** BigQuery の消費スロット数・GKE のノードリソース使用率など、GCP 固有の指標はコンソールから即座に確認できる。既存ツールとの二重管理コストより価値が高い場合が多い。
