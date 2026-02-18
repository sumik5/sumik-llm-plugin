# AWS Database Services リファレンス

AWSの各種データベースサービスの詳細アーキテクチャと実装パターン。

> **関連**: 基本的なDB選定は [SYSTEM-DESIGN.md](./SYSTEM-DESIGN.md) を参照

---

## 目次

1. [Amazon Aurora](#amazon-aurora)
2. [Amazon DynamoDB](#amazon-dynamodb)
3. [Amazon DocumentDB](#amazon-documentdb)
4. [Amazon Neptune](#amazon-neptune)
5. [Amazon Timestream](#amazon-timestream)
6. [Amazon Keyspaces](#amazon-keyspaces)
7. [Amazon OpenSearch Service](#amazon-opensearch-service)
8. [Amazon ElastiCache](#amazon-elasticache)
9. [サービス比較](#サービス比較)

---

## Amazon Aurora

### アーキテクチャ

**ストレージレイヤー**
- 6つのストレージノードに跨る分散ストレージ（3AZ x 2コピー）
- 10GBのProtection Groupsに分割
- ストレージは自動拡張（最大128TB）
- クォーラムベースのレプリケーション（書き込み4/6、読み取り3/6）

**コンピュートレイヤー**
- 1つのWriterインスタンス + 最大15のReaderインスタンス
- Writerのみがストレージに書き込み
- Readerはストレージからの読み取りのみ

### エンドポイント

| エンドポイント | 用途 | 特徴 |
|--------------|------|------|
| Cluster Endpoint | 書き込み | 常にWriterを指す |
| Reader Endpoint | 読み取り負荷分散 | Readerへラウンドロビン |
| Instance Endpoint | 特定インスタンス | 直接接続 |
| Custom Endpoint | カスタム構成 | 特定インスタンス群を指定 |

### Aurora Global Database

**構成**
- 1つのPrimaryリージョン + 最大5つのSecondaryリージョン
- Secondaryリージョンには最大16のRead Replica
- ストレージレベルのレプリケーション（1秒未満のラグ）

**フェイルオーバー**
- RPO: 通常1秒未満
- RTO: 通常1分未満
- Managed Planned Failoverで計画的なリージョン切り替え
- Unplanned Failoverでの手動昇格も可能

### Aurora Serverless v2

**スケーリング特性**
- Aurora Capacity Units (ACU) 単位でスケール
- 最小0.5 ACU〜最大128 ACU
- 秒単位での容量調整
- アイドル時の自動一時停止オプション（v1のみ）

**適用シナリオ**
- 変動が激しいワークロード
- 開発/テスト環境
- 予測困難なトラフィックパターン

### 高度な機能

**Parallel Query**
- 分析クエリをストレージノードにプッシュダウン
- OLTPとOLAP混合ワークロードに有効
- 大量データスキャンの高速化

**Aurora Machine Learning**
- Amazon SageMakerとの統合
- Amazon Comprehendとの統合
- SQLからML推論を直接呼び出し

---

## Amazon DynamoDB

### データモデリング

**Primary Key設計**

| 構成 | 説明 | 使用例 |
|------|------|--------|
| Partition Key のみ | 単純なキー | UserID |
| Partition Key + Sort Key | 複合キー | UserID + Timestamp |

**ベストプラクティス**
- 高カーディナリティのPartition Key
- ホットパーティション回避
- Sort Keyで階層・時系列データを表現

### セカンダリインデックス

| 項目 | Local Secondary Index (LSI) | Global Secondary Index (GSI) |
|------|---------------------------|------------------------------|
| Partition Key | テーブルと同じ | 異なるキーを指定可能 |
| Sort Key | 異なるキーを指定 | 異なるキーを指定可能 |
| 作成タイミング | テーブル作成時のみ | いつでも |
| 容量 | テーブルと共有 | 独立したスループット |
| 整合性 | 強い整合性可 | 結果整合性のみ |
| 上限 | 5個/テーブル | 20個/テーブル |

### キャパシティモード

| 項目 | オンデマンド | プロビジョンド |
|------|------------|--------------|
| 料金モデル | リクエスト単位課金 | 時間単位課金 |
| スケーリング | 自動 | Auto Scaling設定 |
| 適用場面 | 変動大/新規 | 安定/予測可能 |
| スロットリング | まれ | 容量超過時 |

### DynamoDB Accelerator (DAX)

**アーキテクチャ**
- インメモリキャッシュクラスター
- ミリ秒→マイクロ秒のレイテンシ改善
- Write-through キャッシング
- DynamoDB API互換

**キャッシュ種類**
- Item Cache: GetItem/BatchGetItem結果
- Query Cache: Query/Scan結果

**制限事項**
- 強い整合性読み取りはDAXバイパス
- Transact操作は非対応
- VPC内からのみアクセス可能

### DynamoDB Streams

**ストリームレコード**
- KEYS_ONLY: キーのみ
- NEW_IMAGE: 変更後の項目
- OLD_IMAGE: 変更前の項目
- NEW_AND_OLD_IMAGES: 両方

**比較: DynamoDB Streams vs Kinesis Data Streams**

| 項目 | DynamoDB Streams | Kinesis Data Streams |
|------|------------------|---------------------|
| 保持期間 | 24時間 | 1〜365日 |
| シャード数 | 自動 | 手動管理 |
| コンシューマー | Lambda / KCL | 多様なコンシューマー |
| コスト | 無料（読み取り課金） | シャード時間課金 |

### Global Tables

**レプリケーション特性**
- マルチリージョン、マルチアクティブ
- 最終的な整合性（通常1秒以内）
- コンフリクト解決: Last Writer Wins
- すべてのリージョンで読み書き可能

**要件**
- DynamoDB Streamsが有効
- 空のテーブル（初回作成時）
- 同一のテーブル構造

---

## Amazon DocumentDB

### アーキテクチャ

**ストレージ**
- Aurora同様の分散ストレージ
- 6つのコピー（3AZ）
- 最大128TB自動拡張

**クラスター構成**
- 1 Primary + 最大15 Replica
- MongoDB 4.0/5.0 API互換

### エンドポイント

| タイプ | 用途 |
|--------|------|
| Cluster Endpoint | 読み書き（Primary） |
| Reader Endpoint | 読み取り負荷分散 |
| Instance Endpoint | 特定インスタンス |

### MongoDBとの互換性

**サポート機能**
- CRUD操作
- Aggregation Pipeline
- インデックス（B-tree）
- Change Streams

**非サポート/制限**
- サーバーサイドJavaScript
- 一部のインデックスタイプ
- GridFS

### Elastic Clusters

**特徴**
- シャーディングによる水平スケーリング
- ペタバイト規模のデータ
- 数百万の読み書きOps/秒
- コンピュートとストレージの独立スケーリング

---

## Amazon Neptune

### グラフモデル

**Property Graph (Gremlin)**
- ノード（頂点）とエッジ（辺）
- プロパティを持つ
- Apache TinkerPop準拠

**RDF (SPARQL)**
- トリプル（主語-述語-目的語）
- W3C標準
- セマンティックWeb向け

### アーキテクチャ

**ストレージ**
- Aurora同様の分散ストレージ
- 6コピー、3AZ
- 最大128TB

**クラスター構成**
- 1 Primary + 最大15 Read Replica
- マルチAZ対応

### Neptune ML

**機能**
- グラフニューラルネットワーク (GNN)
- ノード分類・リンク予測
- SageMakerとの統合

### Neptune Serverless

**特徴**
- 自動スケーリング
- 使用量に応じた課金
- Neptune Capacity Units (NCU)

### 適用シナリオ

| シナリオ | 説明 |
|---------|------|
| ソーシャルネットワーク | 友人関係、フォロー関係 |
| レコメンデーション | 類似ユーザー、類似商品 |
| ナレッジグラフ | 概念間の関係 |
| 不正検知 | 不正パターンの検出 |
| ネットワーク管理 | IT/ネットワークトポロジー |

---

## Amazon Timestream

### アーキテクチャ

**3層構造**
1. **Ingestion Layer**: 高速データ取り込み
2. **Storage Layer**: Memory Store + Magnetic Store
3. **Query Layer**: アダプティブクエリ処理

**ストレージ階層**

| 層 | 特徴 | 用途 |
|---|------|------|
| Memory Store | 高速、最新データ | リアルタイムクエリ |
| Magnetic Store | コスト効率、履歴データ | 分析クエリ |

### データモデル

**構成要素**
- Database: 論理コンテナ
- Table: 時系列データの集合
- Time Series: 同一ソースからの測定値群
- Record: 単一の測定値（タイムスタンプ + メジャー + ディメンション）

**スキーマ**
- スキーマレス（自動検出）
- ディメンション: 時系列の識別子
- メジャー: 測定値

### クエリ機能

**組み込み関数**
- 時系列補間
- 近似集計
- ウィンドウ関数
- 時間範囲関数

**Scheduled Queries**
- 定期的なクエリ実行
- 結果のマテリアライズ
- ダッシュボード高速化

### 適用シナリオ

| シナリオ | 例 |
|---------|---|
| IoT | センサーデータ、テレメトリ |
| DevOps | メトリクス、ログ分析 |
| 分析 | クリックストリーム、イベント |

---

## Amazon Keyspaces

### 概要

**Apache Cassandra互換**
- CQL (Cassandra Query Language) 対応
- Cassandraドライバー互換
- サーバーレス、フルマネージド

### キャパシティモード

| 項目 | オンデマンド | プロビジョンド |
|------|------------|--------------|
| スケーリング | 自動 | 手動/Auto Scaling |
| 課金 | 読み書き単位 | RCU/WCU時間 |
| 適用 | 変動大 | 安定 |

### Cassandraとの違い

**制限事項**
- Lightweight Transactions (LWT) 制限
- User Defined Types (UDT) 制限
- バッチ操作の制限
- 一部のCQL機能非対応

**追加機能**
- サーバーレス運用
- 自動バックアップ（PITR）
- 暗号化（保存時・転送時）

---

## Amazon OpenSearch Service

### アーキテクチャ

**ドメイン構成**
- Data Nodes: インデックス格納、クエリ処理
- Master Nodes: クラスター管理
- UltraWarm Nodes: ウォームストレージ
- Cold Storage: S3ベースのアーカイブ

**ストレージ階層**

| 層 | 特徴 | コスト |
|---|------|-------|
| Hot | EBS、高速クエリ | 高 |
| UltraWarm | S3バックエンド、頻度低 | 中 |
| Cold | S3、アーカイブ | 低 |

### インデックス設計

**シャード設計**
- 推奨: 10-50GB/シャード
- シャード数 = データサイズ / ターゲットシャードサイズ
- レプリカで可用性向上

**マッピング**
- 動的マッピング（自動検出）
- 明示的マッピング（推奨）

### 統合サービス

**Ingestパイプライン**
- Kinesis Data Firehose → OpenSearch
- Lambda → OpenSearch
- Logstash → OpenSearch

**可視化**
- OpenSearch Dashboards
- Kibana互換

### 適用シナリオ

| シナリオ | 説明 |
|---------|------|
| ログ分析 | アプリケーション/インフラログ |
| 全文検索 | サイト内検索、文書検索 |
| セキュリティ分析 | SIEM、脅威検出 |
| オブザーバビリティ | トレース分析 |

---

## Amazon ElastiCache

### Redis vs Memcached

| 項目 | Redis | Memcached |
|------|-------|-----------|
| データ構造 | 多様（String, Hash, List, Set, Sorted Set等） | Key-Value のみ |
| 永続化 | RDB/AOF | なし |
| レプリケーション | 対応 | 非対応 |
| クラスタリング | Cluster Mode | マルチスレッド |
| Pub/Sub | 対応 | 非対応 |
| Lua スクリプト | 対応 | 非対応 |
| トランザクション | MULTI/EXEC | 非対応 |

### Redis Cluster Mode

**Cluster Mode Disabled**
- 1 Primary + 最大5 Replica
- データはシャーディングなし
- シンプルな構成

**Cluster Mode Enabled**
- 最大500シャード
- 各シャードに最大5 Replica
- 自動シャーディング
- スロット（0-16383）にキー分散

### キャッシング戦略

| 戦略 | 説明 | 適用 |
|------|------|------|
| Lazy Loading | キャッシュミス時にロード | 読み取り中心 |
| Write-Through | 書き込み時に同時キャッシュ | 一貫性重視 |
| TTL | 期限付きキャッシュ | 鮮度管理 |

### Global Datastore

**特徴**
- クロスリージョンレプリケーション
- 1 Primary + 最大2 Secondary リージョン
- サブ秒のレプリケーションラグ
- フェイルオーバー対応

---

## サービス比較

### 用途別選定

| 用途 | 推奨サービス |
|------|------------|
| リレーショナル（高可用性） | Aurora |
| Key-Value（高スケール） | DynamoDB |
| ドキュメント（MongoDB互換） | DocumentDB |
| グラフ | Neptune |
| 時系列 | Timestream |
| 全文検索 | OpenSearch |
| キャッシュ | ElastiCache |
| Cassandra互換 | Keyspaces |

### スケーリング特性

| サービス | 水平 | 垂直 | 自動 |
|---------|-----|-----|------|
| Aurora | Reader追加 | インスタンス変更 | Serverless v2 |
| DynamoDB | パーティション自動 | - | オンデマンド |
| DocumentDB | Reader追加 | インスタンス変更 | Elastic Clusters |
| Neptune | Reader追加 | インスタンス変更 | Serverless |
| Timestream | 自動 | - | 自動 |
| OpenSearch | シャード追加 | ノード変更 | - |
| ElastiCache | シャード追加 | ノード変更 | Auto Scaling |

### コスト最適化

| サービス | コスト削減オプション |
|---------|-------------------|
| Aurora | Reserved Instances, Serverless v2 |
| DynamoDB | Reserved Capacity, オンデマンド切替 |
| OpenSearch | UltraWarm, Cold Storage |
| ElastiCache | Reserved Nodes |

---

## 関連リファレンス

- [SYSTEM-DESIGN.md](./SYSTEM-DESIGN.md) - データベース選定フレームワーク
- [DATABASE-MIGRATION.md](./DATABASE-MIGRATION.md) - 移行パターン
- [SERVERLESS-PATTERNS.md](./SERVERLESS-PATTERNS.md) - サーバーレスアーキテクチャ
