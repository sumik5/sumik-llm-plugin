# データストア・オブザーバビリティ

データストア選定とオブザーバビリティ（監視・可観測性）のベストプラクティスをカバーします。監視システムの詳細設計は `designing-monitoring` スキルを、データベース内部構造は `understanding-database-internals` スキルを、リレーショナルDB設計は `designing-relational-databases` スキルを、それぞれ参照してください。

---

## 1. データストア選定

### RDB vs NoSQL vs NewSQL の判断基準

```yaml
AskUserQuestion:
  質問: "データ特性から最適なデータストアタイプを選択してください"
  選択肢:
    - label: "RDB (Relational Database)"
      特徴:
        - ACID保証、トランザクション、結合演算
        - 正規化されたスキーマ、SQLクエリ
      推奨:
        - トランザクション整合性が必須（金融、在庫管理）
        - 複雑なクエリ（JOIN、集約）
        - スキーマが安定
      ツール: PostgreSQL, MySQL, Oracle
    - label: "NoSQL"
      特徴:
        - 水平スケール、スキーマレス/柔軟
        - 最終的整合性（BASE）
      推奨:
        - 超高スループット、低レイテンシ
        - 柔軟なスキーマ（頻繁な変更）
        - 分散システム（地理的分散）
      ツール: MongoDB, DynamoDB, Cassandra, Redis
    - label: "NewSQL"
      特徴:
        - RDBのACID + NoSQLのスケーラビリティ
        - 分散アーキテクチャ + SQL
      推奨:
        - RDBの整合性 + 水平スケール
        - グローバル分散アプリケーション
      ツール: CockroachDB, Google Cloud Spanner, YugabyteDB
```

### NoSQL分類と判断基準

| タイプ | データモデル | ユースケース | ツール例 |
|-------|------------|------------|---------|
| **Key-Value** | キー → 値 | セッション管理、キャッシュ、シンプルな読み取り | Redis, DynamoDB, Memcached |
| **Document** | JSON/BSONドキュメント | CMS、カタログ、ユーザープロファイル | MongoDB, CouchDB, Firestore |
| **Column-Family** | 列指向、ワイドカラム | 時系列データ、分析、大規模ログ | Cassandra, HBase, ScyllaDB |
| **Graph** | ノード・エッジ | ソーシャルネットワーク、推薦システム、知識グラフ | Neo4j, Amazon Neptune, JanusGraph |

### メッセージキュー / イベントストリーミング

| 手法 | 特徴 | ユースケース | ツール |
|------|-----|------------|-------|
| **メッセージキュー** | ポイントツーポイント、メッセージ消費後削除 | タスクキュー、非同期処理 | RabbitMQ, AWS SQS, Azure Service Bus |
| **イベントストリーミング** | Pub/Sub、メッセージ永続化、リプレイ可能 | イベント駆動アーキテクチャ、リアルタイム分析 | Apache Kafka, AWS Kinesis, Google Pub/Sub |
| **軽量Pub/Sub** | インメモリ、低レイテンシ | リアルタイム通知、WebSocket | Redis Pub/Sub, NATS |

### データウェアハウス / データレイク

| タイプ | 目的 | データ形式 | ツール |
|-------|-----|----------|-------|
| **データウェアハウス** | 分析用の構造化データ | スキーマ定義済み（Star/Snowflakeスキーマ） | Snowflake, BigQuery, Redshift |
| **データレイク** | 生データの大量保存 | 非構造化、半構造化、構造化 | AWS S3 + Athena, Azure Data Lake, GCS |
| **Lakehouse** | ウェアハウス + レイクの統合 | スキーマオンリード、ACID対応 | Databricks, Delta Lake, Apache Iceberg |

### ファイルストア

| サービス | 特徴 | ユースケース |
|---------|-----|------------|
| **AWS S3** | 無制限ストレージ、99.999999999%耐久性 | 静的ファイル、バックアップ、データレイク |
| **Google Cloud Storage** | マルチリージョン、CDN統合 | 画像・動画、アーカイブ |
| **Azure Blob Storage** | ホット/クール/アーカイブ階層 | コスト最適化ストレージ |

### CAP定理の実践的解釈

**CAP定理**: 分散システムは「Consistency（一貫性）」「Availability（可用性）」「Partition Tolerance（分断耐性）」のうち2つまでしか満たせない

| 選択 | 特徴 | ユースケース | ツール |
|------|-----|------------|-------|
| **CP** | 一貫性 + 分断耐性（可用性犠牲） | 金融トランザクション、在庫管理 | MongoDB（一部設定）、HBase |
| **AP** | 可用性 + 分断耐性（一貫性犠牲） | ソーシャルメディア、コンテンツ配信 | Cassandra, DynamoDB, Riak |
| **CA** | 一貫性 + 可用性（分断耐性犠牲） | 単一データセンター、RDB | PostgreSQL, MySQL（単一ノード） |

**実務**: ネットワーク分断は現実に起こるため、**CPまたはAPを選択**する。

### データストア選定テーブル

| 要件 | 推奨データストア | 理由 |
|-----|----------------|------|
| トランザクション整合性 | PostgreSQL, MySQL | ACID保証 |
| 超高速読み取り | Redis（インメモリ） | μs単位のレイテンシ |
| 柔軟なスキーマ | MongoDB | ドキュメント指向 |
| 時系列データ（IoT、ログ） | InfluxDB, TimescaleDB | 時系列最適化 |
| グラフ構造 | Neo4j | ノード・エッジクエリ |
| 検索エンジン | Elasticsearch | 全文検索、ファセット |
| セッション管理 | Redis, DynamoDB | TTL、高速アクセス |
| イベント駆動アーキテクチャ | Kafka | イベントストリーミング |
| 分析（BI、レポート） | BigQuery, Snowflake | 列指向、並列クエリ |

---

## 2. スキーマ管理

### マイグレーション戦略

| 手法 | 説明 | ツール |
|------|-----|-------|
| **Forward-Only Migration** | スキーマ変更を前方にのみ適用（ロールバック不可） | Flyway, Liquibase |
| **Reversible Migration** | Up/Downマイグレーションスクリプト | Rails Migrations, Alembic |
| **Declarative Schema** | 宣言的なスキーマ定義、差分自動検出 | Prisma, TypeORM |

### Backward-Compatible Schema Changes

**原則**: スキーマ変更はアプリケーションの旧バージョンでも動作するように設計

| 変更 | 安全性 | 対処法 |
|------|-------|-------|
| **カラム追加** | ✅ 安全 | NULL許可またはデフォルト値設定 |
| **カラム削除** | ❌ 危険 | 2段階: ①アプリケーションが使用停止 → ②削除 |
| **カラム名変更** | ❌ 危険 | 2段階: ①新カラム追加 → ②旧カラム削除 |
| **NOT NULL制約追加** | ❌ 危険 | 既存データがNULLでないことを確認 |
| **テーブル追加** | ✅ 安全 | 影響なし |
| **テーブル削除** | ❌ 危険 | 2段階削除 |

### Blue-Green Database Migrations

**手法**: データベースのバージョンを2つ（Blue/Green）用意し、段階的に移行

```
┌──────────────┐
│ App v1.0     │ → DB Blue (旧スキーマ)
└──────────────┘

┌──────────────┐
│ App v1.1     │ → DB Blue + Green（両方読み書き）
└──────────────┘

┌──────────────┐
│ App v1.2     │ → DB Green (新スキーマ)
└──────────────┘
```

---

## 3. Three Pillars of Observability

### メトリクス（Metrics）

**定義**: 時系列の数値データ（例: CPU使用率、リクエスト数）

#### USE Method（リソース監視）

| 指標 | 意味 | 例 |
|------|-----|-----|
| **Utilization** | 使用率 | CPU 70%, Memory 80% |
| **Saturation** | 飽和度（キュー待ち） | ディスクI/O待ち、スレッドプール待ち |
| **Errors** | エラー率 | ディスク読み取りエラー |

#### RED Method（サービス監視）

| 指標 | 意味 | 例 |
|------|-----|-----|
| **Rate** | リクエスト数/秒 | 1000 req/s |
| **Errors** | エラー率 | 5xx エラー率 1% |
| **Duration** | レイテンシ | P50=100ms, P99=500ms |

#### Golden Signals（Google SRE）

| 指標 | 説明 |
|------|-----|
| **Latency** | リクエスト処理時間 |
| **Traffic** | システムへの需要（req/s, transactions/s） |
| **Errors** | 失敗したリクエストの割合 |
| **Saturation** | システムの飽和度（CPU、メモリ、ディスク） |

**ツール**: Prometheus, Datadog, CloudWatch, Grafana

### ログ（Logs）

**定義**: イベントの記録（テキスト形式）

#### 構造化ログ

```json
// ❌ 非構造化ログ
"User john logged in from 192.168.1.1 at 2025-01-01T10:00:00Z"

// ✅ 構造化ログ（JSON）
{
  "timestamp": "2025-01-01T10:00:00Z",
  "level": "INFO",
  "event": "user_login",
  "user": "john",
  "ip": "192.168.1.1"
}
```

**メリット**: 検索・集約が容易、ログ分析ツールで解析可能

#### ログレベル

| レベル | 用途 | 本番環境での出力 |
|-------|-----|----------------|
| **DEBUG** | 開発時の詳細情報 | ❌ 出力しない |
| **INFO** | 通常の動作記録 | ✅ 出力（適度に） |
| **WARN** | 警告（処理は継続） | ✅ 出力 |
| **ERROR** | エラー（処理失敗） | ✅ 出力 |
| **FATAL** | 致命的エラー（システム停止） | ✅ 出力 |

#### ログ集約

**手法**: 分散システムのログを中央に集約

```
App Server 1 ──┐
App Server 2 ──┼→ Log Aggregator → Log Storage → Analysis
App Server 3 ──┘
```

**ツール**: ELK Stack (Elasticsearch, Logstash, Kibana), Loki, Splunk, CloudWatch Logs

### トレース（Traces）

**定義**: 分散システム内のリクエストのライフサイクルを追跡

#### 分散トレーシング

```
User Request
  ├─ API Gateway (100ms)
  │   ├─ Auth Service (20ms)
  │   └─ User Service (80ms)
  │       ├─ Database Query (50ms)
  │       └─ Cache Lookup (10ms)
```

**ツール**: Jaeger, Zipkin, AWS X-Ray, Google Cloud Trace

#### Context Propagation

**手法**: トレースIDをHTTPヘッダーで伝播

```http
X-Trace-Id: abc123
X-Span-Id: xyz789
```

**詳細は `implementing-opentelemetry` スキル参照。**

---

## 4. 監視設計

### ダッシュボード設計原則

| 原則 | 説明 | 例 |
|------|-----|-----|
| **ゴールデンシグナル優先** | Latency, Traffic, Errors, Saturationを最上部に配置 | 4つのグラフを1行目に配置 |
| **階層化** | 概要 → 詳細の順に配置 | ダッシュボード（概要） → ドリルダウン（詳細） |
| **アクショナブル** | 見て行動できる情報のみ | "CPU 80%"ではなく"スケールアウトが必要" |
| **自動リフレッシュ** | リアルタイムデータ | 30秒〜5分間隔 |

### アラート設計

#### SLO/SLI/SLA ベース

| 用語 | 説明 | 例 |
|------|-----|-----|
| **SLI** (Service Level Indicator) | サービスの測定可能な指標 | 99.9%のリクエストが500ms以内 |
| **SLO** (Service Level Objective) | 内部目標 | 99.95%の可用性 |
| **SLA** (Service Level Agreement) | 顧客との契約 | 99.9%の可用性保証 |

**アラート閾値**: SLOを下回る前に通知（例: SLO 99.9% → アラート 99.5%）

#### アラート疲れの回避

| 問題 | 対策 |
|------|------|
| 偽陽性アラート | 閾値の調整、異常検知の活用 |
| 頻繁すぎるアラート | アラートの集約、サイレンス設定 |
| 対処不可能なアラート | アクション可能なアラートのみ設定 |

**ルール**: すべてのアラートには明確な対処手順（Runbook）を用意する

### オンコール / インシデント対応

| ステージ | アクション | ツール |
|---------|-----------|-------|
| **検知** | アラート受信、自動エスカレーション | PagerDuty, Opsgenie |
| **トリアージ** | 優先度判定（Severity） | インシデント管理ツール |
| **緩和** | 一時的な修正（ロールバック、スケール） | Runbook、自動化スクリプト |
| **復旧** | 根本原因の修正 | デプロイ、パッチ適用 |
| **事後分析** | ポストモーテム | 根本原因分析、再発防止策 |

### ポストモーテム文化

**原則**: ブレームレス（責任追及しない）、学習重視

**ポストモーテムに含める内容**:
1. **タイムライン**: 発生〜検知〜復旧の時系列
2. **根本原因**: 技術的・プロセス的原因
3. **影響範囲**: ユーザー数、ダウンタイム、売上損失
4. **対処手順**: 実施したアクション
5. **再発防止策**: 具体的なアクションアイテム（担当者・期限付き）

**詳細は `designing-monitoring` スキル参照。**

---

## 5. 監視ツール選定

```yaml
AskUserQuestion:
  質問: "監視要件から最適なツールスタックを選択してください"
  選択肢:
    - label: "Prometheus + Grafana（オープンソース）"
      特徴:
        - プルベースメトリクス収集
        - PromQLクエリ言語
        - セルフホスト
      推奨:
        - Kubernetes環境
        - コスト重視
        - カスタマイズ性重視
      デメリット: スケール時の複雑性、長期保存には追加ストレージ必要
    - label: "Datadog（商用SaaS）"
      特徴:
        - メトリクス・ログ・トレース統合
        - APM（Application Performance Monitoring）
        - 1200+統合
      推奨:
        - マルチクラウド
        - 即時導入
        - サポート重視
      デメリット: コスト高（ホスト数・メトリクス数で課金）
    - label: "CloudWatch / Azure Monitor / GCP Cloud Monitoring"
      特徴:
        - クラウドネイティブ統合
        - 自動メトリクス収集
      推奨:
        - 単一クラウド環境
        - 標準的な監視
        - 低コスト
      デメリット: マルチクラウドでの一元管理が困難
    - label: "OpenTelemetry + Backend選択"
      特徴:
        - ベンダー中立的な計装
        - メトリクス・ログ・トレース統合
        - バックエンド切替可能（Jaeger, Tempo, Datadog等）
      推奨:
        - 将来のツール切替を見据える
        - 標準化重視
        - マルチベンダー回避
```

---

## 6. 監視成熟度モデル

| レベル | 特徴 | 実現内容 |
|-------|-----|---------|
| **1. リアクティブ** | 障害発生後に気づく | 手動監視、ユーザー報告 |
| **2. 基本監視** | サーバー死活監視 | Pingチェック、CPU/メモリ監視 |
| **3. サービス監視** | アプリケーションメトリクス | Latency, Errors, Throughput |
| **4. オブザーバビリティ** | メトリクス・ログ・トレース統合 | 根本原因分析が迅速 |
| **5. プロアクティブ** | 異常検知、予測アラート | 機械学習、AIOps |

---

## 7. 関連スキルとの差別化

| トピック | このスキル（practicing-devops） | 詳細スキル |
|---------|-------------------------------|-----------|
| **データストア選定** | RDB/NoSQL/NewSQLの比較、CAP定理、選定基準 | `understanding-database-internals`: DB内部構造、分散システム理論 |
| **リレーショナルDB設計** | スキーママイグレーション戦略 | `designing-relational-databases`: 正規化、インデックス設計、PostgreSQL実装 |
| **監視システム設計** | Three Pillars、アラート設計の概要 | `designing-monitoring`: 詳細な監視デザインパターン、SLO設計、オンコール運用 |
| **分散トレーシング** | トレースの概念、ツール比較 | `implementing-opentelemetry`: OpenTelemetry SDK実装、計装詳細 |

---

**次のセクション**:
- [CICD-PIPELINE.md](./CICD-PIPELINE.md): CI/CDパイプライン設計
- [PLATFORM-ENGINEERING.md](./PLATFORM-ENGINEERING.md): ネットワーク・セキュリティ・マルチ環境管理
