# AWS Data Engineering リファレンス

データパイプライン構築のためのAWSサービスと設計パターン。

> **関連**: データベース詳細は [DATABASE-SERVICES.md](./DATABASE-SERVICES.md) を参照

---

## 目次

1. [データ取り込み（Ingestion）](#データ取り込みingestion)
2. [データ変換（Transformation）](#データ変換transformation)
3. [データストア選定](#データストア選定)
4. [データカタログとガバナンス](#データカタログとガバナンス)
5. [パイプラインオーケストレーション](#パイプラインオーケストレーション)
6. [リファレンスアーキテクチャ](#リファレンスアーキテクチャ)

---

## データ取り込み（Ingestion）

### ストリーミング取り込み

#### Amazon Kinesis Data Streams

**特徴**
- リアルタイムデータストリーミング
- 自動スケーリング（オンデマンドモード）
- 保持期間: 24時間〜365日
- Enhanced Fan-out: コンシューマーごとに専用スループット

**容量モード比較**

| 項目 | オンデマンド | プロビジョンド |
|------|------------|--------------|
| 容量計画 | 不要 | シャード数指定 |
| スケーリング | 自動 | 手動/Auto Scaling |
| 料金 | データ量ベース | シャード時間ベース |
| 適用 | 変動大/新規 | 安定/予測可能 |

**シャーディング設計**
- パーティションキーの選択が重要
- 高カーディナリティのキーを使用
- ホットシャード回避

#### Amazon Data Firehose

**特徴**
- サーバーレスETL（ニアリアルタイム）
- S3、Redshift、OpenSearch等へ直接配信
- Lambda連携で軽量変換
- バッファリング（サイズ/時間ベース）

**バッファ設定**

| 宛先 | サイズ | 時間 |
|------|--------|------|
| S3 | 1-128 MB | 60-900秒 |
| Redshift | 1-128 MB | 60-900秒 |
| OpenSearch | 1-100 MB | 60-900秒 |

#### Amazon MSK（Managed Streaming for Apache Kafka）

**特徴**
- Apache Kafka完全互換
- MSK Serverless: 自動スケーリング
- Tiered Storage: 長期データ保持
- MSK Connect: コネクター管理

**Kinesis vs MSK**

| 項目 | Kinesis Data Streams | Amazon MSK |
|------|---------------------|------------|
| プロトコル | AWS独自 | Kafka プロトコル |
| 既存Kafkaアプリ | 要改修 | そのまま使用可 |
| 運用負荷 | 低 | 中 |
| エコシステム | AWS統合 | Kafkaエコシステム |

### バッチ取り込み

#### AWS DMS（Database Migration Service）

**CDCによる継続的レプリケーション**
- ソースDBのトランザクションログを読み取り
- 変更分のみターゲットに適用
- Full Load + CDCでダウンタイム最小化

**詳細**: [DATABASE-MIGRATION.md](./DATABASE-MIGRATION.md) を参照

#### Zero-ETL統合

**サポートする統合**
- Aurora → Redshift
- DynamoDB → OpenSearch
- RDS → Redshift

**特徴**
- ETLパイプライン不要
- ニアリアルタイム同期
- 運用負荷削減

---

## データ変換（Transformation）

### AWS Glue

**コンポーネント**

| コンポーネント | 説明 |
|--------------|------|
| Data Catalog | メタデータリポジトリ |
| Crawlers | スキーマ自動検出 |
| ETL Jobs | Spark/Pythonベース変換 |
| DataBrew | ノーコードデータ準備 |
| Workflows | ジョブオーケストレーション |

**ジョブタイプ**

| タイプ | 用途 | エンジン |
|--------|------|---------|
| Spark | 大規模バッチ | Apache Spark |
| Streaming | リアルタイム | Spark Structured Streaming |
| Python Shell | 軽量変換 | Python |

**DPU（Data Processing Unit）**
- 4 vCPU + 16GB メモリ = 1 DPU
- ワーカータイプ: Standard / G.1X / G.2X / G.4X / G.8X

**Bookmarks**
- 処理済みデータの追跡
- 増分処理の実現
- ジョブ間での状態保持

### Amazon EMR

**デプロイオプション**

| オプション | 特徴 |
|----------|------|
| EMR on EC2 | フル制御、カスタマイズ |
| EMR on EKS | Kubernetes統合 |
| EMR Serverless | インフラ管理不要 |

**フレームワーク**
- Apache Spark
- Apache Hive
- Presto / Trino
- Apache Flink

**ストレージ**
- HDFS（クラスター内）
- EMRFS（S3統合）

### Amazon Managed Service for Apache Flink

**特徴**
- Apache Flink完全互換
- ステートフル処理
- Exactly-once処理保証
- Studio Notebook（対話型開発）

**言語サポート**
- Java
- Scala
- Python
- SQL

### Glue vs EMR 選定

| 観点 | AWS Glue | Amazon EMR |
|------|----------|------------|
| 管理負荷 | 低（サーバーレス） | 中〜高 |
| カスタマイズ | 限定的 | 高い自由度 |
| コスト | DPU時間課金 | インスタンス時間課金 |
| 適用 | 標準的ETL | 複雑な処理/ML |

### Amazon Redshift での変換

**SQL変換機能**
- ウィンドウ関数
- CTEによる複雑なクエリ
- ストアドプロシージャ
- UDF（ユーザー定義関数）

**データロード**
- COPY: S3からの高速ロード
- UNLOAD: S3への高速エクスポート

---

## データストア選定

### ストレージ階層

| 階層 | 特徴 | サービス例 |
|------|------|----------|
| Hot | 低レイテンシ、高コスト | EBS, ElastiCache |
| Warm | バランス | S3 Standard |
| Cold | 高レイテンシ、低コスト | S3 Glacier |

### ファイルフォーマット

**行指向フォーマット**
- CSV, JSON
- 書き込み効率が良い
- 全カラム読み取りに適す

**列指向フォーマット**
- Parquet, ORC
- 分析クエリに最適
- 高い圧縮率

**テーブルフォーマット**
- Apache Iceberg
- Apache Hudi
- Delta Lake

**特徴**
- ACID トランザクション
- スキーマ進化
- タイムトラベル
- 増分処理

### S3ストレージクラス

| クラス | 用途 | 取り出し |
|--------|------|---------|
| Standard | 頻繁アクセス | 即時 |
| Intelligent-Tiering | 不明パターン | 自動最適化 |
| Standard-IA | 低頻度アクセス | 即時 |
| Glacier Instant | アーカイブ（即時） | ミリ秒 |
| Glacier Flexible | アーカイブ | 分〜時間 |
| Glacier Deep Archive | 長期保存 | 時間 |

### データモデリング戦略

**Redshift**
- スタースキーマ / スノーフレークスキーマ
- Distribution Style: EVEN / KEY / ALL / AUTO
- Sort Key: Compound / Interleaved

**DynamoDB**
- シングルテーブル設計
- アクセスパターン駆動
- GSI/LSI の活用

**Data Lake**
- ゾーニング: Raw → Curated → Consumption
- パーティショニング戦略
- 命名規則の標準化

---

## データカタログとガバナンス

### AWS Glue Data Catalog

**機能**
- スキーマ定義の一元管理
- Athena/Redshift Spectrum/EMRと統合
- バージョン管理

**Crawlers**
- 自動スキーマ検出
- スケジュール実行
- 分類子（Classifiers）

### AWS Lake Formation

**機能**
- 細粒度アクセス制御
- 列/行レベルセキュリティ
- データ共有
- Governed Tables

**Lake Formation vs IAM**

| 観点 | IAM | Lake Formation |
|------|-----|----------------|
| 粒度 | リソースレベル | 列/行レベル |
| 管理 | 分散 | 一元化 |
| 適用 | 汎用 | データレイク特化 |

### Amazon DataZone

**機能**
- ビジネスデータカタログ
- データ共有ワークフロー
- セルフサービスアクセス
- ドメイン管理

### データ品質

**AWS Glue Data Quality**
- DQDL（Data Quality Definition Language）
- 自動品質チェック
- CloudWatch統合

**Deequ**
- Apache Sparkベース
- 統計的品質検証
- EMR/Glue統合

---

## パイプラインオーケストレーション

### AWS Step Functions

**特徴**
- サーバーレスワークフロー
- ビジュアルワークフロー設計
- エラーハンドリング内蔵
- 他AWSサービスとの統合

**ワークフロータイプ**
- Standard: 長時間実行（最大1年）
- Express: 短時間高頻度（最大5分）

### Amazon MWAA（Managed Workflows for Apache Airflow）

**特徴**
- Apache Airflow互換
- DAGベースのワークフロー
- Pythonによる定義
- 豊富なオペレーター

### AWS Glue Workflows

**特徴**
- Glue専用オーケストレーション
- トリガーベース実行
- Crawler + Job の連携

### Amazon EventBridge

**特徴**
- イベント駆動型アーキテクチャ
- スケジュール実行
- イベントルーティング
- SaaS統合

### オーケストレーション選定

| ユースケース | 推奨サービス |
|-------------|-------------|
| Glue中心のETL | Glue Workflows |
| 複雑な分岐・並列処理 | Step Functions |
| Airflow経験あり | Amazon MWAA |
| イベント駆動 | EventBridge |
| スケジュール実行 | EventBridge Scheduler |

---

## リファレンスアーキテクチャ

### ストリーミング分析パターン

```
[Data Sources] → API Gateway → MSK/Kinesis
                                    ↓
                           Apache Flink (処理)
                                    ↓
                    ┌───────────────┼───────────────┐
                    ↓               ↓               ↓
              OpenSearch      Lambda/SNS         S3
              (検索/可視化)    (アラート)      (長期保存)
```

### Lakehouseパターン

```
[Data Sources]
      ↓
Kinesis/DMS/Glue (取り込み)
      ↓
S3 Raw Zone (生データ)
      ↓
Glue ETL (変換)
      ↓
S3 Curated Zone (Iceberg/Parquet)
      ↓
┌─────────────┬─────────────┐
↓             ↓             ↓
Athena    Redshift     QuickSight
(アドホック) (DWH)        (BI)
```

### バッチ処理パターン

```
[Data Sources]
      ↓
S3 Landing Zone
      ↓
Glue Crawler (カタログ登録)
      ↓
EMR/Glue ETL (変換)
      ↓
S3 Processed Zone
      ↓
Redshift/Athena (分析)
```

---

## ベストプラクティス

### パイプライン設計

- **冪等性**: 再実行しても同じ結果
- **増分処理**: 差分のみ処理
- **エラーハンドリング**: リトライ・DLQ
- **監視**: CloudWatch メトリクス/ログ

### コスト最適化

- サーバーレス活用（Glue、Firehose）
- 適切なストレージ階層
- 列指向フォーマット使用
- パーティショニング

### セキュリティ

- 保存時暗号化（KMS）
- 転送時暗号化（TLS）
- 最小権限原則（IAM）
- Lake Formationによるアクセス制御

---

## 関連リファレンス

- [DATABASE-SERVICES.md](./DATABASE-SERVICES.md) - データベースサービス詳細
- [DATABASE-MIGRATION.md](./DATABASE-MIGRATION.md) - 移行パターン
- [SERVERLESS-PATTERNS.md](./SERVERLESS-PATTERNS.md) - サーバーレスアーキテクチャ
- [SYSTEM-DESIGN.md](./SYSTEM-DESIGN.md) - システム設計パターン
