---
description: >-
  Data architecture patterns covering read-side optimization (replicas, materialized views,
  CQRS, CDC, event sourcing), domain-based decomposition, polyglot persistence, and caching
  strategies (cache-aside, read-through, write-through, write-around).
  Use when designing data flow architecture, choosing read scalability strategies, or
  implementing caching for enterprise systems.
  For microservices patterns (Saga, granularity), use architecting-microservices instead.
  For DDD domain modeling, use applying-domain-driven-design instead.
  For database engine internals, use understanding-database-internals instead.
  For relational DB schema design, use designing-relational-databases instead.
  For GCP-specific data services (BigQuery, Dataflow, Dataproc), use developing-google-cloud instead.
---

# Architecting Data

## Overview

データアーキテクチャは、ソフトウェアシステムの見えない基盤です。しかし、多くのチームでは暗黙的に扱われており、その結果、パフォーマンス低下、コンプライアンス問題、チームの生産性低下を引き起こします。

本スキルは、データアーキテクチャをファーストクラスの関心事として扱い、以下を実現します：

- **Read-Side最適化**: Read Replicas、Materialized Views、CQRS、CDC、Event Sourcing
- **ドメイン分解とPolyglot Persistence**: ドメイン境界に基づくデータ分割と最適なストレージ選択
- **キャッシュ戦略**: Cache-Aside、Read-Through、Write-Through、Write-Around

本スキルは**トランザクショナルシステムのアーキテクチャパターン**に焦点を当てています。分析システム（Data Warehouses、Data Lakes、Data Lakehouse、Data Mesh、Data Fabric）については、未公開章として概要を掲載しています。

---

## When to Use

以下の状況でこのスキルを参照してください：

- Read負荷がWrite負荷を上回り、クエリパフォーマンスが低下
- ReadモデルとWriteモデルの要件が乖離
- 複数の異なる消費者（顧客向けUI、オペレーションダッシュボード等）が同じデータを異なる形式で要求
- ドメイン境界が明確で、各ドメインが異なるデータアクセスパターンを持つ
- キャッシュ戦略の選択や実装が必要
- データの履歴追跡、監査証跡、時間軸に沿った分析が必要

**他スキルとの使い分け**:
- マイクロサービスのSaga、粒度決定 → `architecting-microservices`
- DDDドメインモデリング → `applying-domain-driven-design`
- データベースエンジン内部構造 → `understanding-database-internals`
- リレーショナルDBスキーマ設計 → `designing-relational-databases`

---

## Core Principles

### 1. データアーキテクチャは戦略的能力

データアーキテクチャは単なる配管作業ではなく、以下を左右する戦略的能力です：

- 新リージョンへの展開速度
- コンプライアンス対応の容易さ
- リアルタイム機能の実現
- チームの独立性と生産性

### 2. ReadとWriteは異なる特性を持つ

- **Write**: データ整合性、トランザクション保証、ビジネスルール適用を優先
- **Read**: スピード、フィルタリング、フォーマッティングを優先

単一モデルで両方を最適化することは困難です。

### 3. ドメイン境界に沿った分解

ビジネスドメイン（注文管理、商品カタログ、プロモーション、顧客分析等）ごとに異なるデータ要件があります。ドメイン境界に沿って分解することで、各ドメインが最適なストレージとアクセスパターンを選択できます。

### 4. Eventual Consistencyの受容

分散システムでは、すべてのデータが即座に同期されるわけではありません。ビジネス要件に応じて、Eventual Consistencyを受け入れることで、スケーラビリティと可用性を向上させます。

---

## Read-Side Optimization Decision Framework

以下のテーブルを参考に、Read-Side最適化パターンを選択してください。

| パターン | 最適化対象 | トレードオフ | 適用タイミング |
|---------|-----------|------------|--------------|
| **Read Replicas** | スケーラビリティ | Eventual Consistency、ルーティングロジック追加 | Read負荷がWrite負荷を上回り、データ鮮度がクリティカルでない |
| **Materialized Views** | 高コストな集計 | リフレッシュロジック必要、staleness risk | メトリクス計算、ダッシュボード、トレンド分析 |
| **CQRS** | 関心の分離 | コンポーネント増加、モデル同期必要 | ReadとWriteのアクセスパターンが著しく異なる |
| **Change Data Capture (CDC)** | 非侵襲的なReadモデル更新 | ドメインイベントの意味的豊かさ欠如 | レガシーシステムにReadビューを後付け |
| **Event Sourcing** | 完全な監査証跡と再現性 | 運用複雑性、イベントバージョニング | 履歴が必要、動的ビュー、ドメイントレーサビリティ |
| **Domain Decomposition** | チーム自律性、スケーラビリティ | 強い境界と統合規律が必要 | システム複雑性がビジネスサブドメインと一致 |
| **Polyglot Persistence** | ワークロード特化パフォーマンス | 運用負荷増加、スキル多様性 | ドメインごとにデータ形状、ボリューム、アクセスが大きく異なる |

詳細は `references/READ-SIDE-PATTERNS.md` を参照してください。

---

## Caching Decision Framework

キャッシュ戦略を選択する際は、以下の判断基準を使用してください。

### キャッシュ要件定義

| 要件 | 考慮事項 |
|------|---------|
| **Data Freshness** | データはどれほど新鮮である必要があるか？ staleになっても許容されるか？ |
| **Fault Tolerance** | キャッシュ障害時もシステムは機能するか？ フェイルオーバーは必要か？ |
| **Scalability** | 負荷増加に応じてキャッシュもスケールできるか？ パーティショニングは必要か？ |
| **Cost** | 実装コストは？ 運用コストは負荷に応じて増加するか？ |

### キャッシュ対象の判断

| 対象 | 理由 |
|------|------|
| ✅ **Read-heavy & slowly changing** | 商品カタログ、ユーザー設定、ルックアップテーブル |
| ✅ **Expensive to compute** | アナリティクスデータ、レコメンデーション、集計データ |
| ✅ **Low entropy** | 為替レート、税率、リージョンマッピング |
| ✅ **Unreliable upstream** | 遅い・不安定な上流依存 |
| ❌ **Rapidly changing** | リアルタイム在庫、高頻度トランザクション（Write-Through除く） |

### キャッシュパターン選択

| パターン | 説明 | 適用タイミング |
|---------|------|--------------|
| **Cache-Aside** | アプリケーションがキャッシュを管理 | Read-heavyで頻繁に変更されないデータ。staleness許容可能 |
| **Read-Through** | キャッシュがDBから自動取得 | アプリケーションロジックとキャッシュ動作を分離したい |
| **Write-Through** | 書込み時にキャッシュとDBの両方を更新 | データ整合性が高優先度。Read-after-Write一貫性が必要 |
| **Write-Around** | 書込みはDBのみ、読込み時にキャッシュ | 大量書込み、低頻度読込み。キャッシュ汚染回避 |

詳細は `references/CACHING-STRATEGIES.md` を参照してください。

### AskUserQuestion配置指示

以下の判断分岐箇所では、AskUserQuestionツールを使用してユーザーに選択肢を提示してください：

**Read-Side戦略選択時**:
```
質問: "Read-Side最適化のアプローチを選択してください"
選択肢:
- Read Replicas（シンプル、即効性あり、Eventual Consistency許容）
- Materialized Views（集計クエリ最適化、リフレッシュ戦略必要）
- CQRS（ReadとWriteの完全分離、複雑性増加）
- Event Sourcing（完全履歴、監査証跡、最も複雑）
```

**キャッシュパターン選択時**:
```
質問: "キャッシュ実装パターンを選択してください"
選択肢:
- Cache-Aside（アプリケーション主導、シンプル）
- Read-Through（キャッシュ主導、ロジック分離）
- Write-Through（書込み同期、データ整合性優先）
- Write-Around（書込みバイパス、キャッシュ汚染回避）
```

**Polyglot Persistence選択時**:
```
質問: "ドメインに最適なストレージを選択してください"
選択肢:
- Relational DB（トランザクション整合性、ACID保証）
- Document Store（スキーマレス、検索最適化）
- Key-Value Store（高速ルックアップ、低レイテンシ）
- Time-Series DB（トレンド分析、イベントデータ）
```

---

## 未公開章スケルトン

以下のセクションは、将来的に詳細化される予定のトピックです。現時点では概要のみを掲載しています。

### Part 1: Operational Data（未公開）

#### Partitioning Data
データベースパーティショニングによる水平スケーラビリティ。Sharding戦略とトレードオフ。

#### Data in Monolith Architectures
モノリシックアーキテクチャにおけるデータ管理の課題と最適化。

#### Data in Microservices Architectures
マイクロサービスにおけるデータ所有権、トランザクション境界、Sagaパターン。（詳細は `architecting-microservices` 参照）

#### Data Domain Based Architectures
ドメイン駆動設計に基づくデータアーキテクチャ。（詳細は `applying-domain-driven-design` 参照）

#### Data Architecture for Search
検索最適化データストア（Elasticsearch等）の設計と実装。

#### Data in Motion
ストリーミングデータアーキテクチャ、Event-Driven Architecture、Kafka/Pulsar活用。

---

### Part 2: Analytical Data（未公開）

#### Data Warehouses
トランザクショナルシステムから分析システムへのETL/ELT。OLAPとスタースキーマ。

#### Data Lakes
生データの中央リポジトリ。スキーマオンリード、データレイクハウスへの進化。

#### Data Lakehouse
Data LakeとData Warehouseのハイブリッドアーキテクチャ。Deltaテーブル、Apache Iceberg。

#### Data Mesh
分散型データ所有権とデータプロダクト思考。ドメイン指向の分散分析データアーキテクチャ。

#### Data Fabric
統合データ管理レイヤー。メタデータ駆動、自動化されたデータインテグレーション。

---

### Part 3: Migrating（未公開）

#### Monolith to Component
モノリスをコンポーネント単位に分解する段階的移行戦略。

#### Monolith to Domains
Strangler Figパターンによるドメインベース分解。

#### Monolith to Polyglot
単一データストアから複数専門化ストレージへの移行。

#### Data Warehouse to Data Mesh
中央集権型Data WarehouseからData Meshへの移行。組織変革を含む。

#### Data Warehouse to Data Fabric
Data WarehouseからData Fabricへの移行パス。

---

## Related Skills

- **architecting-microservices**: マイクロサービスの粒度、Saga、CQRS実装
- **applying-domain-driven-design**: 戦略的DDD、ドメインモデリング、境界づけられたコンテキスト
- **understanding-database-internals**: データベースエンジン内部、インデックス、トランザクション分離レベル
- **designing-relational-databases**: 正規化、スキーマ設計、PostgreSQL実装
- **implementing-opentelemetry**: 分散トレーシング、データパイプライン可観測性
- **designing-monitoring**: SLO設計、監視戦略、データ品質メトリクス
