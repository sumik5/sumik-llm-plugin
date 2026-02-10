# テレメトリーシステムアーキテクチャ詳細

このファイルでは、テレメトリーパイプラインの各ステージ（Emitting, Shipping, Presentation）の詳細設計と実装パターンを解説します。

---

## Emittingステージ（発信）

Emittingステージはテレメトリーがプロダクションシステムから送出される最初のステージです。

### プロダクションコードからの発信

**3つの基本パターン:**

#### 1. ログファイルへの発信

```python
# 構造化ロガーを使用した例（Python）
import logging
from logging.handlers import RotatingFileHandler

metlog = logging.getLogger('metlog')
metfile = RotatingFileHandler(
    filename='/var/log/metrics.log',
    mode="a",
    maxBytes=8*1024*1024,  # 8MB
    backupCount=5
)
metlog.addHandler(metfile)

# 使用例
metlog.info("[counter] [pdf_pages] [2]")
```

**特徴:**
- シンプルで理解しやすい
- ファイルシステムの容量制約あり
- Shippingステージで別プロセスが読み取り

#### 2. システムログ（Syslog）への発信

```python
from logging.handlers import SysLogHandler
from syslog import LOG_LOCAL4

metfile = SysLogHandler(facility=LOG_LOCAL4)
metlog.addHandler(metfile)

# リモートSyslogサーバーへ直接送信
metfile = SysLogHandler(
    facility=LOG_LOCAL4,
    address=("syslog.prod.internal", 514)
)
```

**特徴:**
- ハードウェアとの互換性が高い
- Syslogが自動的にタイムスタンプを付与
- UDP/514でリモート送信可能（emitter/shipper機能）

#### 3. 標準出力（stdout）への発信

```python
import sys
from logging import StreamHandler

metfile = StreamHandler(stream=sys.stdout)
metlog.addHandler(metfile)

# 使用例（コンテナ環境に最適）
metlog.info("[metrics] [counter] [profile_image_upload] [1]")
metfile.flush()  # シャットダウン時の確実な書き込み
```

**特徴:**
- コンテナ・サーバーレス環境に最適
- Docker/Kubernetes/AWS Lambdaがstdoutを自動収集
- stderrとの分離により、エラーを強調表示可能

**構造化ロガーの3コンポーネント:**
1. **Logger** — テレメトリーのエントリーポイント
2. **Formatter** — Shippingステージに合わせたフォーマット変換
3. **Writer** — 実際の書き込み先（ファイル、Syslog、stdout、DB等）

### ハードウェアからの発信

ハードウェアは標準化されたプロトコルでテレメトリーを発信します:

#### 1. Syslog

**標準ログレベル（RFC定義）:**

| ID | Severity | Keyword |
|----|----------|---------|
| 0 | Emergency | emerg, panic |
| 1 | Alert | alert |
| 2 | Critical | crit |
| 3 | Error | err, error |
| 4 | Warning | warn, warning |
| 5 | Notice | notice |
| 6 | Info | info |
| 7 | Debug | debug |

**Cisco ASAファイアウォールの設定例:**

```
logging enable
logging timestamp
logging buffer-size 1000000
logging trap informational
logging host outside 192.0.2.100  # Syslogサーバー
```

#### 2. SNMP（Simple Network Management Protocol）

**2つの動作モード:**

1. **Pollingモード（GET/SET）**
   - 管理ステーションがデバイスに定期的にクエリ
   - メトリクス収集（監視）と設定配布に使用

2. **Trapモード（通知）**
   - デバイスが重要イベントを管理ステーションに自動送信
   - 集中ログ・SIEM用途

### SaaS/IaaSからの発信

**主な発信方法:**

#### 1. Webhook（プッシュ型）

```bash
# GitHub Webhook設定例
curl -X POST https://api.github.com/repos/:owner/:repo/hooks \
  -d '{
    "name": "web",
    "config": {
      "url": "https://telemetry.prod.internal/github",
      "content_type": "json"
    },
    "events": ["push", "pull_request"]
  }'
```

#### 2. APIポーリング（プル型）

```python
# AWS CloudWatch Logs例
import boto3

logs_client = boto3.client('logs')
response = logs_client.get_log_events(
    logGroupName='/aws/lambda/my-function',
    logStreamName='2025/01/01/[$LATEST]abc123'
)
```

---

## Shippingステージ（移送・格納）

Shippingステージはテレメトリーを受け取り、変換・加工してストレージに保存します。

### 直接ストレージへの書き込み

**Emitter/Shipper機能統合例（Elasticsearchへ直接書き込み）:**

```python
from elasticsearch import Elasticsearch

esclient = Elasticsearch(
    hosts=[{"host": "escluster.prod.internal", "port": 9200}],
    sniff_on_start=False
)

def counter(msg, count=1):
    metric = {
        "metric_name": msg,
        "metric_value": count,
        "metric_type": "counter"
    }
    esclient.index(index="metrics", body=metric)
```

**利点:**
- シンプルなアーキテクチャ
- プロダクションシステム内で完結

**欠点:**
- ストレージ障害時にプロダクション影響
- 大量の小さな書き込みでストレージ負荷増大

### キュー・ストリームを経由した書き込み

#### キュー（Queue）

**特徴:**
- FIFO（First In, First Out）
- 単一消費者グループ
- 読み取られたデータは削除

**Redis Listを使用した例:**

```python
import redis

redis_client = redis.Redis(host='log-queue.prod.internal')

def counter(msg, count=1):
    metric = {
        "metric_name": msg,
        "metric_value": count
    }
    redis_client.rpush('metrics_counters', json.dumps(metric))
```

**バルクライター（Bulk Writer）:**

```python
while True:
    counter_raw = redis_client.blpop('metrics_counters', wait_limit)
    if counter_raw:
        current_items.append(counter_raw)

    if len(current_items) >= bulk_size or timeout:
        esclient.bulk(current_items, index='metrics')
        current_items = []
```

**効果:**
- 10,000個の小さな書き込み → 50個のバルク書き込み（200件/バッチ）
- ストレージへの書き込みトランザクションを95%削減

#### ストリーム（Stream / Event Bus）

**特徴:**
- 複数の消費者グループがそれぞれ独立してデータを読み取る
- データは削除されず、一定期間保持
- マルチテナンシーに最適

**Redis Streamを使用した例:**

```python
# 発信側
redis_client.xadd('syslog_stream', '*', line)

# 消費側（ネットワークOpsチーム）
redis_client.xgroup_create('syslog_stream', 'noc_team', '$')
line = redis_client.xreadgroup(
    'noc_team',
    'noc_ingest',
    'syslog_stream',
    '>'  # 未読イベントのみ取得
)

# 消費側（セキュリティチーム）
redis_client.xgroup_create('syslog_stream', 'sec_team', '$')
line = redis_client.xreadgroup(
    'sec_team',
    'sec_ingest',
    'syslog_stream',
    '>'
)
```

**ストリームの利点:**
- 同じテレメトリーを複数チームが独立して消費
- 各消費者グループが独自のペースで処理
- 遅いチームが速いチームをブロックしない

### フォーマット統一

#### Shipping Format選択基準

| フォーマット | 可読性 | パース速度 | 用途 |
|------------|-------|-----------|------|
| **Delimited (key-value)** | 高 | 最速 | シンプルなkey-value、フィールド数が少ない |
| **JSON** | 中 | 速い | 構造化データ、ネスト可能 |
| **CSV** | 高 | 最速 | 固定フィールド順、テーブル形式 |
| **XML** | 低 | 遅い | レガシーシステム互換性 |

**フォーマット例（同じデータ）:**

```bash
# CSV（位置依存）
"2026-02-26T17:52:01.002+0:00","pdf_pages exited","ip-172-16-0-12"

# Key-Value（位置非依存）
timestamp="2026-02-26T17:52:01.002+0:00" message="pdf_pages exited" host="ip-172-16-0-12"

# JSON（構造化）
{"timestamp":"2026-02-26T17:52:01.002+0:00","message":"pdf_pages exited","host":"ip-172-16-0-12"}

# 複合（コンテキスト + メッセージ）
[timestamp="2026-02-26T17:52:01.002+0:00" host="ip-172-16-0-12"] [pdf_pages exited]
```

**推奨:**
- **開発環境**: Human-readable（delimited, key-value）
- **プロダクション**: JSON（パース速度とツール互換性のバランス）

#### カーディナリティを意識した設計

**カーディナリティ = フィールド数 × 各フィールドの可能値数**

```python
# 低カーディナリティ（良い例）
{
    "metric_name": "response_time",    # 100種類
    "environment": "prod",              # 3種類（dev, staging, prod）
    "region": "us-east-1"               # 10種類
}
# カーディナリティ = 100 × 3 × 10 = 3,000

# 高カーディナリティ（悪い例）
{
    "metric_name": "response_time",
    "user_id": "user_12345",            # 100万種類
    "request_id": "req_abcdefg"         # 無限
}
# カーディナリティ = 無限 → 検索パフォーマンス劣化
```

**対策:**
- ユーザーIDはハッシュ化または集約
- リクエストIDは分散トレーシング専用ストレージへ
- メトリクスは低カーディナリティに限定

### アーキテクチャのティッピングポイント（Tipping Points）

テレメトリー生成量の増加に伴い、アーキテクチャは段階的に進化します:

| 規模 | アーキテクチャ | 特徴 |
|-----|-------------|------|
| **小規模（〜10ホスト）** | 直接ストレージ書き込み | シンプル、管理容易 |
| **中規模（10〜100ホスト）** | キュー経由 + バルクライター | パフォーマンス改善、ストレージ負荷軽減 |
| **大規模（100〜1000ホスト）** | ストリーム + 複数消費者 + 集約ポリシー | マルチテナンシー、チーム別処理 |
| **エンタープライズ（1000+ホスト）** | 分散ストリーム + リージョン別ストレージ + サンプリング | グローバル展開、コスト最適化 |

---

## Presentationステージ（表示）

Presentationステージは、保存されたテレメトリーをフィルタリング・変換・集約し、意思決定を支援します。

### メトリクスシステムの表示

#### 集約関数（Aggregation Functions）

| 関数 | 説明 | 用途 |
|-----|------|------|
| **sum** | 合計 | トラフィック量、ページ数 |
| **count** | イベント数 | エラー発生回数 |
| **mean/average** | 平均 | 平均応答時間 |
| **median** | 中央値（50thパーセンタイル） | 偏りを排除した中央値 |
| **min/max** | 最小値/最大値 | 範囲の把握 |
| **percentile** | パーセンタイル（5th, 95th等） | データの分布形状 |
| **derivative** | 変化率 | ディスク使用量の増加速度 |
| **spread** | max - min | 変動幅 |

**使用例:**

```bash
# Prometheusクエリ例
# 1分間のsum
sum(rate(http_requests_total[1m]))

# 95thパーセンタイル
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# 変化率（ディスク使用量）
deriv(disk_used_bytes[5m])
```

**注意: 集約の集約は避ける**

```python
# 悪い例（統計的に無効）
raw_data = [1, 2, 3, 4, 5]
hourly_mean = mean(raw_data)  # 3
daily_max = max([hourly_mean])  # 3（嘘のデータ）

# 良い例
daily_max = max(raw_data)  # 5（正しい）
```

**安全な再集約:**
- `sum(sum(x))` → OK
- `mean(sum(x))` → NG（統計的に無効）
- `max(mean(x))` → NG（統計的に無効）

#### グラフ・ダッシュボード設計

**優れたメトリクスPresentationシステムの特徴:**

1. **多様なユーザーがグラフを作成可能** — エンジニアだけでなく、サポート、営業も
2. **ガイド付きUI** — クエリ構文を暗記不要
3. **ダッシュボード整理機能** — フォルダ、タグ、検索
4. **アドホックダッシュボード** — 保存せずに即座に調査
5. **共有可能なURL** — 他のチームメンバーに検索結果を共有

**ダッシュボード設計のベストプラクティス:**
- 最重要グラフを上部に配置
- ダーク/ライトモード両対応の色選択（黄色は避ける）
- 情報密度に注意（多すぎると混乱）

### 集中ログシステムの表示

**必須機能:**

1. **フィールド検索** — `priority:"high"` vs `"high"`（全文検索）
2. **複雑な検索ロジック** — AND, OR, NOT, 正規表現
3. **カスタムフィールド表示** — 必要なフィールドのみテーブル表示
4. **検索の保存と共有** — 再利用可能な検索クエリ
5. **URL共有** — 検索結果のリンクをチームで共有
6. **認証・認可** — PII/PHI保護のため必須

**Kibanaデモ:**

```bash
# 検索例
tags:"firewall" AND NOT target_ip:"1.1.0.0" AND NOT target_ip:"1.1.1.1"

# 結果
- source_ip: 192.0.2.19
- target_ip: 8.8.8.8  # Google DNS（異常な接続）
- firewall_action: Teardown
```

**集中ログ vs SIEM:**

| 項目 | Centralized Logging | SIEM |
|-----|---------------------|------|
| **主な利用者** | 全員 | Security/Compliance + 監査人 |
| **目的** | 問題調査、システム理解 | インシデント対応、監査証跡 |
| **保持期間** | 数日〜数週間 | 数年（7年以上） |
| **データ追加者** | 開発者が自由に追加 | 規制・コンプライアンスフレームワークが定義 |

### 分散トレーシングシステムの表示

**相関（Correlation）によるコンテキスト提供:**

```
Trace: upload_document (6.155秒)
├─ get_file_details (0.012秒)
│  └─ file_size: 2.9MB, extension: pdf
├─ get_page_details (0.143秒)
│  └─ page_count: 19
└─ enqueue_pdf_create (6.000秒)
   ├─ pdf_to_png (page 1) (0.315秒)
   ├─ pdf_to_png (page 2) (0.312秒)
   ├─ ...
   └─ pdf_to_png (page 19) (0.318秒)
```

**Honeycomb.io SDK例:**

```python
import libhoney

# 初期化（サンプリングレート25%）
libhoney.init(
    writekey=os.getenv('HC_WRITEKEY'),
    dataset='example.profile.pages',
    sample_rate=4  # 1/4 = 25%
)

def do_work(options):
    hc_event = libhoney.new_event()

    file_details = get_file_details(options)
    hc_event.add_field('file_size', file_details['file_size'])
    hc_event.add_field('file_extension', file_details['extension'])

    page_details = get_page_details(file_details)
    hc_event.add_field('page_count', page_details['count'])

    png_pages = enqueue_png_create(page_details)
    wait_png_pages(png_pages)

    hc_event.send()  # dur_ms自動計測
```

**分散トレーシングの価値:**
- マイクロサービス間の実行フローを可視化
- ボトルネックの特定
- エラー発生箇所の追跡
- サービス境界を越えたコンテキスト保持

---

## マークアップとエンリッチメント

### マークアップ（Markup）

**定義:** Emitting/Shippingステージでコンテキスト情報を付加

**例:**

```python
# Emittingステージでのマークアップ
{
    "message": "pdf_pages completed",
    "page_count": 19,
    # 以下はマークアップ
    "host": "ip-172-16-0-12",
    "environment": "production",
    "app_version": "v2.3.1",
    "region": "us-east-1"
}
```

### エンリッチメント（Enrichment）

**定義:** Shipping/Presentationステージでテレメトリーから詳細を抽出

**Syslogエンリッチメント例:**

```python
# 元のSyslog行
"Feb 19 02:26:26 asa1 %ASA1: Teardown UDP connection 162121 for outside:1.1.0.0/53 to dmz1:192.0.2.19/59232 duration 0:00:00 bytes 136"

# エンリッチメント後
{
    "timestamp": "2026-02-19T02:26:26",
    "host": "asa1.net.prod.internal",
    "firewall_action": "Teardown",
    "firewall_proto": "UDP",
    "firewall_conn": "162121",
    "source_zone": "outside",
    "source_ip": "1.1.0.0",
    "source_port": "53",
    "target_zone": "dmz1",
    "target_ip": "192.0.2.19",
    "target_port": "59232",
    "conn_duration": "0:00:00",
    "conn_bytes": "136"
}
```

---

## マルチテナンシー

### テナント分離パターン

#### 1. 共有ストレージモデル（Pool）

**特徴:**
- すべてのテナントが同じストレージを共有
- `tenant_id`フィールドで識別

**利点:**
- リソース効率が高い
- 管理が容易

**欠点:**
- テナント間の性能影響
- データ漏洩リスク

#### 2. 分離ストレージモデル（Silo）

**特徴:**
- 各テナントが独立したストレージインスタンス

**利点:**
- 完全な分離
- 性能予測可能

**欠点:**
- リソース非効率
- 管理コスト増大

#### 3. ハイブリッドモデル

**特徴:**
- Shippingステージは共有（Stream）
- Presentationステージは分離

**実装例（Redis Stream）:**

```python
# 単一ストリーム
redis_client.xadd('syslog_stream', '*', line)

# チーム別消費者グループ
redis_client.xreadgroup('noc_team', 'noc_ingest', 'syslog_stream', '>')
redis_client.xreadgroup('sec_team', 'sec_ingest', 'syslog_stream', '>')
```

### マルチテナンシー判断基準

| 要件 | 推奨モデル |
|-----|----------|
| コスト最小化 | Pool（共有） |
| セキュリティ最優先 | Silo（分離） |
| 複数チームで異なるストレージ | Hybrid（ストリーム分岐） |
| SaaS提供 | Silo（テナント間完全分離） |

---

## まとめ

テレメトリーシステムアーキテクチャの成功要因:

1. **適切なスタイル選択** — Logging/Metrics/Tracing/SIEMを用途別に使い分け
2. **段階的進化** — 規模に応じてアーキテクチャを変更（ティッピングポイント）
3. **低カーディナリティ維持** — 検索パフォーマンスの確保
4. **マークアップ/エンリッチメント** — コンテキスト情報の充実
5. **マルチテナンシー対応** — チーム別ニーズへの柔軟な対応
