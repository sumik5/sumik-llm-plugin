---
name: understanding-database-internals
description: >-
  Comprehensive database internals reference covering storage engines (B-trees, LSM-trees,
  file formats, transactions, recovery) and distributed systems (failure detection, leader
  election, replication, consistency models, consensus algorithms).
  Use when designing database-backed systems, choosing storage engines, understanding
  consistency guarantees, or debugging distributed system behavior.
  For SQL-level antipatterns and query optimization, use avoiding-sql-antipatterns instead.
  For relational database design process (entity modeling, ER diagrams, normalization), use designing-relational-databases instead.
  For data architecture patterns (CQRS, event sourcing, caching strategies), use architecting-data instead.
---

# データベース内部構造の理解

## スキルの概要

このスキルは、データベース管理システム（DBMS）の内部動作とアーキテクチャについての包括的な知識を提供します。以下の2つの主要な領域をカバーします：

### 第I部: ストレージエンジン

ディスク上でのデータの格納・取得・更新の仕組みを扱います：

- **DBMSアーキテクチャ**: メモリ/ディスクベース、行/列指向、データ/インデックスファイル
- **Bツリー**: BST→AVL→Bツリーへの進化、ディスク構造、階層・操作、ファイルフォーマット
- **B+ツリー実装**: ページヘッダ、二分探索、スプリット/マージ、圧縮、バキューム
- **トランザクションとリカバリ**: バッファ管理、WAL、ARIES、同時実行制御、分離レベル
- **Bツリー亜種**: コピーオンライト、遅延Bツリー、FDツリー、Bwツリー、キャッシュオブリビアス
- **ログ構造化ストレージ**: LSMツリー、SSTable、ブルームフィルタ、スキップリスト、RUM予想

### 第II部: 分散システム

複数ノードにまたがるデータベースシステムの設計と動作を扱います：

- **分散システム基礎**: 分散コンピューティングの誤謬、障害モデル、FLP不可能性、システムの同期性
- **障害検出とリーダー選出**: ハートビート、φ故障検出器、ゴシップ検出、リーダー選出アルゴリズム
- **レプリケーションと一貫性**: CAP定理、一貫性モデル（線形化・逐次・因果・結果整合性）、CRDTs
- **アンチエントロピーとゴシップ**: 読み取り修復、Merkleツリー、ゴシップ散布、オーバーレイネットワーク
- **分散トランザクション**: 2PC、3PC、Calvin、Spanner、コンシステントハッシュ、Percolator
- **合意アルゴリズム**: Paxos全亜種、Raft、ビザンチン合意、PBFT

---

## 使用タイミング

以下のような状況でこのスキルを参照してください：

### ストレージエンジン選択時

- 新しいアプリケーションのデータベース選定
- 読み取り/書き込みワークロードの性能要件分析
- データ量・クエリパターンに基づく最適化
- トランザクション要件と一貫性保証の評価

### 分散システム設計時

- マイクロサービス間のデータ同期戦略
- レプリケーション設定と一貫性レベルの選択
- 障害耐性とリーダー選出メカニズムの設計
- 分散トランザクションと合意プロトコルの実装

### パフォーマンス分析時

- スロークエリの根本原因調査
- ディスクI/Oボトルネックの特定
- インデックス戦略の最適化
- トランザクション競合の診断

### システムデバッグ時

- レプリケーションラグの原因特定
- 一貫性異常の診断
- 分散システムの障害シナリオ分析
- データ損失・不整合の原因調査

---

## ストレージエンジン選択ガイド

### B-tree vs LSM-tree 比較

| 特性 | B-tree | LSM-tree |
|------|--------|----------|
| **読み取り性能** | ✅ 高速（1〜2回のディスクシーク） | ⚠️ 中程度（複数のSSTableスキャン） |
| **書き込み性能** | ⚠️ 中程度（ランダムI/O） | ✅ 高速（シーケンシャルI/O） |
| **空間効率** | ⚠️ 低（断片化によるオーバーヘッド） | ✅ 高（圧縮率が高い） |
| **書き込み増幅** | 🔴 高（ページ全体を書き換え） | ✅ 低（追記のみ） |
| **更新コスト** | 🔴 高（インプレース更新） | ✅ 低（新バージョン追記） |
| **範囲クエリ** | ✅ 効率的（連続キー） | ⚠️ 中程度（マージスキャン） |
| **トランザクション** | ✅ 容易（WAL） | ⚠️ 複雑（LSMツリー特有の制約） |
| **代表的実装** | PostgreSQL, MySQL InnoDB, SQLite | Cassandra, HBase, RocksDB, LevelDB |

### 選択基準

#### B-treeが適している場合

- **読み取り重視のワークロード** - OLTP、ユーザーインタラクション
- **頻繁な更新** - インプレース更新が効率的
- **範囲クエリが多い** - ソート順のキー走査
- **トランザクション保証が重要** - ACID要件

#### LSM-treeが適している場合

- **書き込み重視のワークロード** - ログ、メトリクス、イベントストリーム
- **高スループット要件** - シーケンシャルI/Oの恩恵
- **ストレージコストが重要** - 圧縮による容量削減
- **時系列データ** - タイムスタンプ順の挿入

---

## 一貫性モデル早見表

分散システムにおける一貫性保証を理解するための階層的分類：

| 一貫性レベル | 保証内容 | レイテンシ | 可用性 | 代表的実装 |
|------------|---------|----------|-------|----------|
| **線形化可能性 (Linearizability)** | すべての操作が単一のグローバル順序で実行されたように見える | 🔴 高 | 🔴 低 | etcd, Consul |
| **逐次一貫性 (Sequential Consistency)** | すべてのプロセスが同じ操作順序を観測（リアルタイム順序は不要） | 🟠 中〜高 | 🟠 中 | - |
| **因果一貫性 (Causal Consistency)** | 因果関係のある操作のみ順序保証 | 🟢 低〜中 | 🟢 高 | Cassandra (軽量トランザクション) |
| **結果整合性 (Eventual Consistency)** | 更新が最終的にすべてのレプリカに伝播 | ✅ 低 | ✅ 高 | DynamoDB, Cassandra |
| **Read Your Writes** | 自分の書き込みは自分が読める | 🟢 低 | 🟢 高 | - |
| **Monotonic Reads** | 古いバージョンへの逆行なし | 🟢 低 | 🟢 高 | - |

### CAP定理と選択

**CAP定理**: 一貫性 (Consistency)、可用性 (Availability)、分断耐性 (Partition Tolerance) の3つのうち、分散システムは最大2つしか同時に満たせない。

実際には**分断は必ず発生する**ため、選択肢は以下の2つ：

- **CP (一貫性 + 分断耐性)**: 分断時は一部ノードを利用不可にして一貫性を維持
  - 例: etcd, Consul, HBase
  - 用途: 金融トランザクション、在庫管理

- **AP (可用性 + 分断耐性)**: 分断時も全ノード利用可能だが一貫性は緩和
  - 例: Cassandra, DynamoDB, Riak
  - 用途: セッションストア、キャッシュ、分析

---

## 分散トランザクション選択ガイド

| アプローチ | 一貫性 | レイテンシ | 複雑性 | 用途 |
|----------|-------|----------|-------|------|
| **2-Phase Commit (2PC)** | 🟢 強 | 🔴 高 | 🟠 中 | 従来のRDBMS、短命なトランザクション |
| **3-Phase Commit (3PC)** | 🟢 強 | 🔴 極高 | 🔴 高 | 実用上まれ |
| **Saga Pattern** | 🟠 結果整合性 | 🟢 低 | 🟠 中 | マイクロサービス、長時間トランザクション |
| **Paxos/Raft** | 🟢 強 | 🟠 中 | 🔴 高 | 合意ベースの状態マシン |
| **Calvin** | 🟢 線形化 | 🟠 中 | 🔴 高 | 決定論的データベース |
| **Spanner (TrueTime)** | 🟢 線形化 + 外部一貫性 | 🟠 中 | 🔴 極高 | グローバル分散DB（専用ハードウェア） |
| **Percolator** | 🟠 スナップショット分離 | 🟢 低 | 🟠 中 | BigTable上の大規模トランザクション |

---

## 設計時の確認事項

データベースシステムを設計・選定する際、以下の質問に答えることで適切な選択ができます：

### ワークロード特性

- 読み取りと書き込みの比率は？
- 典型的なクエリパターンは？（ポイントクエリ vs 範囲クエリ）
- データサイズと増加率は？
- 同時接続数とスループット要件は？

### 一貫性要件

- トランザクションは必要か？
- 必要な分離レベルは？（Read Uncommitted → Serializable）
- 結果整合性で許容できるか？
- 因果関係の保証は必要か？

### 可用性・耐久性

- ダウンタイムは許容できるか？
- レプリケーション戦略は？（同期 vs 非同期）
- RPO（Recovery Point Objective）とRTO（Recovery Time Objective）は？
- 地理的分散は必要か？

### 運用要件

- バックアップとリストアの要件は？
- スキーマ変更の頻度は？
- 監視・デバッグのしやすさは？
- チームのスキルセットは？

---

## サブファイル一覧

このスキルは以下のサブファイルで構成されています。Progressive Disclosure原則に従い、概要はこのファイルに記載し、詳細は各サブファイルに分離しています。

### 既存ファイル（モデル・戦略）

| ファイル | 内容 |
|---------|------|
| [`references/MODELS.md`](./references/MODELS.md) | 伝統的データベースモデル（リレーショナル、階層、ネットワーク、オブジェクト指向） |
| [`references/NOSQL-MODELS.md`](./references/NOSQL-MODELS.md) | NoSQL・特殊用途モデル（ドキュメント、列指向、グラフ、時系列、空間DB） |
| [`references/STORAGE-AND-PROCESSING.md`](./references/STORAGE-AND-PROCESSING.md) | ストレージ戦略（SAN/NAS/DAS、RAID）・分散処理（MapReduce、Hadoop、Spark） |

### 第I部: ストレージエンジン

| ファイル | 対応章 | 内容 |
|---------|-------|------|
| [`references/DBMS-ARCHITECTURE.md`](./references/DBMS-ARCHITECTURE.md) | Ch 1 | DBMSアーキテクチャ、メモリ/ディスクベース、行/列指向、データ/インデックスファイル |
| [`references/BTREE-FUNDAMENTALS.md`](./references/BTREE-FUNDAMENTALS.md) | Ch 2+3 | BST、ディスク構造、Bツリー階層・操作、ファイルフォーマット、ページ構造 |
| [`references/BTREE-IMPLEMENTATION.md`](./references/BTREE-IMPLEMENTATION.md) | Ch 4 | ページヘッダ、二分探索、スプリット/マージ、圧縮、バキューム |
| [`references/TRANSACTIONS-RECOVERY.md`](./references/TRANSACTIONS-RECOVERY.md) | Ch 5 | バッファ管理、WAL、ARIES、同時実行制御、分離レベル |
| [`references/BTREE-VARIANTS.md`](./references/BTREE-VARIANTS.md) | Ch 6 | コピーオンライト、遅延Bツリー、FDツリー、Bwツリー、キャッシュオブリビアス |
| [`references/LOG-STRUCTURED-STORAGE.md`](./references/LOG-STRUCTURED-STORAGE.md) | Ch 7 | LSMツリー、SSTable、ブルームフィルタ、スキップリスト、RUM予想 |

### 第II部: 分散システム

| ファイル | 対応章 | 内容 |
|---------|-------|------|
| [`references/DISTRIBUTED-FUNDAMENTALS.md`](./references/DISTRIBUTED-FUNDAMENTALS.md) | Ch 8 | 分散コンピューティングの誤謬、障害モデル、FLP不可能性、システムの同期性 |
| [`references/FAILURE-DETECTION-LEADER-ELECTION.md`](./references/FAILURE-DETECTION-LEADER-ELECTION.md) | Ch 9+10 | ハートビート、φ故障検出器、ゴシップ検出、Bully/招待/リングアルゴリズム |
| [`references/REPLICATION-CONSISTENCY.md`](./references/REPLICATION-CONSISTENCY.md) | Ch 11 | CAP定理、一貫性モデル（線形化・逐次・因果・結果整合性）、CRDTs |
| [`references/ANTI-ENTROPY-GOSSIP.md`](./references/ANTI-ENTROPY-GOSSIP.md) | Ch 12 | 読み取り修復、Merkleツリー、ゴシップ散布、オーバーレイネットワーク |
| [`references/DISTRIBUTED-TRANSACTIONS.md`](./references/DISTRIBUTED-TRANSACTIONS.md) | Ch 13 | 2PC、3PC、Calvin、Spanner、コンシステントハッシュ、Percolator |
| [`references/CONSENSUS-ALGORITHMS.md`](./references/CONSENSUS-ALGORITHMS.md) | Ch 14 | Paxos全亜種、Raft、ビザンチン合意、PBFT |

---

## 関連スキル

- **`avoiding-sql-antipatterns`**: SQLレベルのアンチパターンとクエリ最適化
- **`applying-domain-driven-design`**: ドメイン境界設計とデータ分解
- **`architecting-microservices`**: マイクロサービス粒度決定とデータ所有権
- **`designing-monitoring`**: データベース監視とオブザーバビリティ

---

## 補足: 出典について

このスキルの内容は、業界で広く認識されているデータベース内部構造の一般的な知識とベストプラクティスをまとめたものです。具体的な実装例は、PostgreSQL、MySQL、Cassandra、HBase、RocksDB等のオープンソースプロジェクトから参照しています。
