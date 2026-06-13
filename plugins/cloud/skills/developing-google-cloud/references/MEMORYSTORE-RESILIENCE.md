# Memorystore レジリエンス・DR・監視ガイド

Google Cloud Memorystore における高可用性（HA）、ディザスタリカバリ（DR）、監視・オブザーバビリティ、インシデント管理の包括的な設計・運用ガイド。

---

## 高可用性（HA）アーキテクチャ

### サービスティアとSLA

| ティア | SLA | レプリケーション | 自動フェイルオーバー | データ永続化 | マルチリージョン対応 |
|--------|-----|----------------|---------------------|-------------|---------------------|
| **Basic Tier** | なし | なし | なし | なし | なし |
| **Standard Tier** | **99.9%** | あり（Primary + Replica） | あり（約60秒以内） | インメモリのみ | なし（アプリレベルで実装） |

**SLA計算式**:
```
可用性 = (総時間 - ダウンタイム) / 総時間 × 100%
```

- **99.9% SLA**: 月間最大ダウンタイム約43.8分
- **ダウンタイム定義**: インスタンスエンドポイントが到達不能、または有効なクエリに応答しない期間
- **サービスクレジット**: SLA未達時にダウンタイム時間に比例したクレジット付与

---

## Standard Tier HAの仕組み

### マルチゾーンレプリケーション

```
Region (us-central1)
    ├─ Zone A
    │   └─ Primary Node
    │
    └─ Zone B
        └─ Replica Node
```

**レプリケーション方式**:
- **同期/準同期レプリケーション**: Primaryの書き込みをReplicaに最小遅延で複製
- **ゾーン分離**: ネットワーク・インフラ障害のリスク分散
- **データ一貫性**: Replica昇格時にデータロス最小化

### 自動フェイルオーバー

| フェーズ | 説明 | 所要時間 |
|---------|------|---------|
| **ヘルスモニタリング** | Primary/Replicaの継続的ヘルスチェック | 常時 |
| **障害検出** | Primary無応答検知 | 数秒 |
| **フェイルオーバートリガー** | トラフィックをReplicaへリダイレクト | 秒単位 |
| **ロールスワップ** | 旧Primary復旧時に新Replicaとして再参加 | 自動 |

**フェイルオーバー例（gcloud CLI）**:

```bash
# Standard HA Tierインスタンス作成
gcloud redis instances create my-ha-redis-instance \
    --size=10GB \
    --region=us-central1 \
    --zone=us-central1-a \
    --tier=STANDARD_HA \
    --redis-version=redis_6_x
```

Serviceが自動的にus-central1-a（Primary）とus-central1-b（Replica）にノードを配置し、フェイルオーバーを管理。

---

## ディザスタリカバリ（DR）

### 自動バックアップとスナップショット

#### バックアップ設定

```bash
# バックアップ有効化（60分間隔、4-6AM実行、7日保持）
gcloud redis instances update [INSTANCE_ID] \
    --region=[REGION] \
    --redis-config=backup-enabled=true \
    --backup-frequency=60m \
    --backup-window=04:00-06:00 \
    --backup-retention-days=7
```

| パラメータ | 説明 | 推奨値 |
|-----------|------|--------|
| **backup-frequency** | バックアップ間隔 | RPO要件に基づき設定（例: 60m） |
| **backup-window** | バックアップ実行時間帯 | オフピーク時間（例: 04:00-06:00） |
| **backup-retention-days** | 保持期間 | ビジネス要件に応じて（例: 7-30日） |

#### リストア操作

```bash
# バックアップから新インスタンス作成
gcloud redis instances create [NEW_INSTANCE_ID] \
    --region=[REGION] \
    --redis-version=REDIS_6_X \
    --tier=STANDARD_HA \
    --memory-size=4GB \
    --restore-instance-from-backup=[BACKUP_ID]
```

**リストア時の整合性保証**:
- スナップショットメタデータ・チェックサム検証
- ネットワーク分離（並行書き込み防止）
- メモリロード完了後にインスタンス利用可能化

---

### RPO・RTO設計

| 目標 | 定義 | Memorystore実装 |
|------|------|----------------|
| **RPO（Recovery Point Objective）** | 許容データ損失時間 | バックアップ頻度で制御（例: 5分毎 → RPO 5分） |
| **RTO（Recovery Time Objective）** | 許容ダウンタイム | マルチゾーンHA + 自動フェイルオーバー（約60秒） |

**RPO/RTO最適化フレームワーク**:

```
1. 分類: アプリ重要度に基づくRPO/RTO設定
   例: 金融取引 → RPO:0分, RTO:1分
       分析ワークロード → RPO:60分, RTO:15分

2. 機能マッピング:
   - RPO → バックアップ頻度（hourly/daily）、レプリケーション（sync/async）
   - RTO → Standard Tier HA、自動フェイルオーバー、ホットスタンバイ

3. コスト評価: 各設定の増分コストを計算

4. 検証: 定期的なフェイルオーバー訓練でRPO/RTO達成確認
```

---

### クロスリージョンDR

**ネイティブサポート**: Memorystore はリージョン内マルチゾーンのみ対応（クロスリージョン非対応）

**実装パターン**:

| パターン | 説明 | RPO | RTO |
|---------|------|-----|-----|
| **Active-Passive（バックアップ・リストア）** | 定期バックアップを別リージョンのCloud Storageに保存 → 障害時にリストア | バックアップ間隔（例: 60分） | 数時間 |
| **Active-Passive（アプリレベルレプリケーション）** | アプリがPrimaryリージョンの書き込みをSecondaryリージョンのMemorystoreに非同期複製 | 数秒～数分 | 数分 |
| **Multi-Region Application Deployment** | ステートレスアプリを複数リージョンにデプロイ、各リージョンのMemorystoreを独立利用 | N/A（リージョナル） | リージョン切替時間 |

---

## 監視とオブザーバビリティ

### Cloud Monitoring メトリクス

Memorystore は `redis.googleapis.com` または `memcached.googleapis.com` ネームスペースでメトリクスを公開。

#### 主要メトリクス

| メトリクス | 説明 | 閾値例 |
|-----------|------|--------|
| **instance/uptime** | インスタンスの稼働時間（秒） | - |
| **instance/memory_usage** | メモリ使用量（バイト） | > 80% でアラート |
| **instance/cpu_utilization** | CPU使用率（%） | > 70% でアラート |
| **instance/ops_per_sec** | 秒間オペレーション数 | ベースライン比較 |
| **instance/command_latency** | コマンドレイテンシ（ms、p50/p95/p99） | p99 > 20ms でアラート |
| **instance/failover_events** | フェイルオーバー発生回数 | 累積モニタリング |
| **instance/error_count** | エラーカウント | > 100/min でアラート |

#### アラート設定例（Cloud Monitoring）

```yaml
# 例: メモリ使用率80%超過時アラート
condition:
  displayName: "Memorystore Memory Usage > 80%"
  conditionThreshold:
    filter: 'metric.type="redis.googleapis.com/instance/memory_usage_ratio"'
    comparison: COMPARISON_GT
    thresholdValue: 0.8
    duration: 300s  # 5分間継続
```

---

### Prometheus統合

**方法**: Google Cloud Monitoring Prometheus sidecar または OpenTelemetry Collector経由

```yaml
# prometheus.yml 例
scrape_configs:
  - job_name: 'memorystore'
    scrape_interval: 15s
    static_configs:
      - targets: ['<PROMETHEUS_EXPORTER_ENDPOINT>']
    relabel_configs:
      - source_labels: [__name__]
        regex: 'redis_.*'
        action: keep
```

**Prometheusメトリクス例**:
- `redis_instance_memory_bytes`
- `redis_instance_cpu_percentage`
- `redis_instance_ops_per_sec`
- `redis_command_latency_ms_quantile{quantile="0.99"}`
- `redis_failover_events_total`
- `redis_error_count_total`

**PromQLクエリ例**:

```promql
# 99パーセンタイルレイテンシの1時間平均
avg_over_time(redis_command_latency_ms_quantile{quantile="0.99"}[1h])

# メモリ使用率80%超過インスタンス
redis_instance_memory_bytes / redis_instance_memory_capacity_bytes > 0.8
```

---

### 分散トレーシング

**OpenTelemetry計装例（Python）**:

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

def cached_get(cache, key):
    with tracer.start_as_current_span("cache.get") as span:
        value = cache.get(key)
        if value is None:
            span.set_attribute("cache.hit", False)
        else:
            span.set_attribute("cache.hit", True)
        return value
```

**トレース活用**:
- キャッシュヒット/ミス比率の可視化
- キャッシュミス時のDB呼び出しレイテンシ追跡
- 分散システム全体のレイテンシ内訳分析

---

## SLO・SLI・アラート設計

### SLI（Service Level Indicator）

| SLI | 定義 | 計測方法 |
|-----|------|---------|
| **キャッシュヒット率** | `(Cache Hits / Total Requests) × 100%` | アプリケーションログ・カスタムメトリクス |
| **キャッシュレイテンシ** | コマンド処理時間（p50, p95, p99） | `instance/command_latency` |
| **キャッシュ驚異度率** | 秒間エビクション数 / 総エントリ数 | カスタムメトリクス |
| **キャッシュ可用性** | インスタンスが応答可能な時間割合 | `instance/uptime` |

### SLO（Service Level Objective）

| SLO | 目標値 | 評価期間 | 例 |
|-----|--------|---------|-----|
| **キャッシュヒット率** | ≥ 90% | 7日間 | ユーザークエリの90%をキャッシュから提供 |
| **レイテンシ（p95）** | < 20ms | 24時間 | 95%のリクエストが20ms以内に完了 |
| **エビクション率** | < 5% | 1時間 | 1時間あたりのエビクションが総エントリの5%未満 |
| **可用性** | ≥ 99.9% | 1ヶ月 | 月間ダウンタイム43.8分以内 |

### アラートポリシー

```pseudo
# アラートルール例: キャッシュヒット率低下検知
if cache_hit_rate < 0.85 for 5 consecutive minutes:
    alert(severity=WARNING, message="Cache hit rate below 85%")

# アラートルール例: レイテンシ急上昇検知
if command_latency_p99 > 50ms for 3 consecutive minutes:
    alert(severity=CRITICAL, message="p99 latency exceeded 50ms")
```

**アラート設計原則**:
- **閾値ベース**: SLO限界値での即座検知
- **変化率ベース**: ベースライン比較での異常早期検出
- **マルチメトリクス相関**: ヒット率低下 + レイテンシ上昇 → バックエンド障害の可能性
- **エスカレーションポリシー**: 重症度に応じた段階的対応（自動修復 → 手動介入）

---

## インシデント管理

### フェイルオーバーテスト

**手順**:

1. **スコープ定義**: 対象サービス・フェイルオーバーパス・成功基準（RTO/RPO達成）
2. **シナリオ準備**: Primaryノードシャットダウン、ネットワークパーティション等の環境構築
3. **実行**: 障害注入 → 監視ダッシュボード・ログ確認
4. **検証**: Replica昇格確認、クライアント接続継続、データ一貫性、レイテンシ基準達成
5. **事後分析**: メトリクス収集、フェイルオーバー時間測定、ギャップ特定 → プレイブック更新

### カオスエンジニアリング

**目的**: 予測不可能な障害に対するシステムレジリエンス検証

**手法**:
- **仮説駆動**: 「Primaryダウン時、Replica昇格でサービス継続」
- **段階的注入**: 影響範囲を限定（1インスタンス → クラスタ全体）
- **セーフガード**: 重大障害時の自動ロールバック機構

**Chaos実験例**:
- 特定マイクロサービスの停止
- 通信チャネルへのレイテンシ注入
- メモリ・CPU枯渇
- 外部依存（DNS、Cloud Storage）の中断

---

### ディザスタシミュレーション

**フェーズ**:

1. **シナリオ設計**: 自然災害、サイバー攻撃、マルチリージョン障害等のプラウザブル脅威
2. **クロスファンクション調整**: 技術チーム・インシデント対応ユニット・経営層・外部ステークホルダーの役割定義
3. **実行**: 障害信号注入、データセンター避難、通信断絶シミュレーション
4. **パフォーマンス測定**: RTO/RPO達成度、意思決定速度、情報精度、プロセス遵守
5. **デブリーフと改善**: 事後レビュー → プレイブック・トレーニング更新

**主要メトリクス**:
- **RTO**: 最大許容ダウンタイム
- **RPO**: 最大許容データ損失時間
- **MTTD (Mean Time to Detect)**: 障害検知までの平均時間
- **MTTR (Mean Time to Recover)**: 復旧までの平均時間

---

## クラウドネイティブ統合

### マイクロサービスキャッシング

```python
# Cloud Run サービス例: Memorystore接続
import redis

redis_client = redis.StrictRedis(
    host='10.0.0.3',  # Memorystore Private IP
    port=6379,
    decode_responses=True
)

def get_user_profile(user_id):
    cache_key = f"user:{user_id}"
    cached = redis_client.get(cache_key)
    if cached:
        return json.loads(cached)

    # DB Fallback
    profile = db.query_user(user_id)
    redis_client.setex(cache_key, 3600, json.dumps(profile))
    return profile
```

### Pub/Sub + Dataflow パターン

```
Pub/Sub (ストリーミングイベント)
    ↓
Dataflow (リアルタイム集計)
    ↓
Memorystore (ホットデータキャッシュ)
    ↓
BigQuery (長期分析)
```

### サーバーレス統合

**Cloud Functions / Cloud Run と Memorystore**:

- **VPC コネクタ**: サーバーレス環境からMemorystore（Private IP）へのアクセス
- **接続プール**: 短命インスタンスでの効率的接続管理
- **冷却開始対策**: 接続確立コストを最小化する lazy initialization

```yaml
# Cloud Run 例（VPCコネクタ経由）
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: my-service
spec:
  template:
    metadata:
      annotations:
        run.googleapis.com/vpc-access-connector: my-connector
    spec:
      containers:
      - image: gcr.io/my-project/my-image
        env:
        - name: REDIS_HOST
          value: "10.0.0.3"
```

---

## ハイブリッド・マルチクラウド対応

### オンプレミス統合

```
オンプレミス DC
    ↓
VPN / Cloud Interconnect
    ↓
GCP VPC
    ↓
Memorystore (Private Service Connect)
```

### マルチクラウドフェイルオーバー

**パターン**: GCP Memorystore（Primary） + AWS ElastiCache（Secondary）

- **アプリレベルレプリケーション**: Pub/Sub → データストリーム → 外部クラウドキャッシュ
- **統一監視**: Prometheus/Grafana でマルチクラウドメトリクス集約
- **自動フェイルオーバー**: DNSベースまたはアプリケーションロジックでエンドポイント切替

---

## ベストプラクティス

### 高可用性設計

- ✅ **Standard Tier を本番環境で使用**: 99.9% SLA + 自動フェイルオーバー
- ✅ **マルチゾーン配置**: ゾーン障害への耐性確保
- ✅ **定期的なフェイルオーバー訓練**: 年4回以上の実施

### バックアップ戦略

- ✅ **自動バックアップ有効化**: RPO要件に合わせた頻度設定
- ✅ **オフピーク実行**: バックアップウィンドウを低負荷時間帯に設定
- ✅ **定期リストアテスト**: 四半期ごとにバックアップからのリストア検証

### 監視・アラート

- ✅ **SLO駆動の監視**: ビジネスインパクトに基づく閾値設定
- ✅ **複合メトリクス活用**: メモリ・CPU・レイテンシを組み合わせた異常検知
- ✅ **アラート疲れ防止**: 閾値調整とサンプリングでノイズ削減

### セキュリティ

- ✅ **Private IP + VPC**: パブリックインターネット露出回避
- ✅ **IAM ベース認証**: サービスアカウントによるアクセス制御
- ✅ **暗号化**: TLS in-transit + at-rest encryption（CMEKオプション）

---

## 参考資料

- [Cloud Memorystore for Redis Documentation](https://cloud.google.com/memorystore/docs/redis)
- [Cloud Monitoring Metrics](https://cloud.google.com/monitoring/api/metrics_gcp)
- [SRE Book: Implementing SLOs](https://sre.google/sre-book/table-of-contents/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
