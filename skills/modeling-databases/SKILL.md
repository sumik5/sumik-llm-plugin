---
name: modeling-databases
description: >-
  Comprehensive database model reference covering 15+ models (relational, hierarchical,
  network, document, graph, EAV, temporal, array), storage strategies (row/column-oriented,
  star schema), and distributed processing (MapReduce, Hadoop).
  Use when selecting database models, designing data architecture, or evaluating storage strategies.
  For SQL-level antipatterns and query optimization, use avoiding-sql-antipatterns instead.
---

# データベースモデリングスキル

## スキル概要

このスキルは、データベースモデルの選択、データアーキテクチャ設計、ストレージ戦略の評価を支援します。15以上のデータベースモデル（リレーショナル、階層型、ネットワーク型、ドキュメント、グラフ、EAV、時系列、配列）とストレージ戦略（行指向/列指向、スタースキーマ）、分散処理（MapReduce、Hadoop）をカバーします。

**カバー範囲:**
- データベースモデルの分類体系と特徴
- ユースケース別モデル選択ガイド
- ストレージ戦略の判断基準
- 分散データ処理の適用判断

**対象外:**
- SQLレベルのアンチパターンやクエリ最適化 → `avoiding-sql-antipatterns` スキル参照

---

## データベースモデル分類体系（Taxonomy）

データベースモデルは以下のカテゴリに分類されます：

### 伝統的モデル
- **Flat-file**: 単純なテキストファイルまたはバイナリファイル。インデックスや構造化なし
- **Hierarchical**: 親子関係を持つツリー構造（例: IMS、XMLデータベース）
- **Network**: 多対多の関係を表現可能なグラフ構造

### リレーショナル派生モデル
- **Relational**: テーブル・行・列による正規化データ
- **Dimensional**: OLAP用の非正規化スキーマ
- **Star Schema**: 中心のファクトテーブルと周辺のディメンションテーブル
- **Snowflake Schema**: 正規化されたディメンション階層を持つスタースキーマ
- **EAV (Entity-Attribute-Value)**: スパース属性や動的スキーマ向けの三列構造

### NoSQLモデル
- **Document-oriented**: JSON/XML等の自己記述型ドキュメント（例: MongoDB、CouchDB）
- **Key-Value**: 単純なキー・値ペア（例: Redis、DynamoDB）
- **Graph**: ノードとエッジで関係を表現（例: Neo4j、OrientDB）
- **Column-family**: 列指向の分散ストレージ（例: Cassandra、HBase）

### 特殊用途モデル
- **Temporal Database**: 時間軸を持つデータ（有効時間、トランザクション時間、決定時間）
- **Array DBMS**: 多次元配列データの効率的な格納・処理（例: SciDB、RasdaMan）
- **Multidimensional**: OLAP用のキューブ構造
- **XML Database**: XML文書の階層構造を保持

### データ処理パラダイム
- **MapReduce**: 分散並列処理フレームワーク
- **Hadoop**: HDFS + MapReduceエンジン
- **Column-oriented Storage**: 列単位のデータ格納・圧縮

---

## モデル選択意思決定マトリクス

| ユースケース | 推奨モデル | 理由 |
|------------|----------|------|
| **OLTP（トランザクション処理）** | Relational | ACID保証、整合性制約、正規化による冗長性排除 |
| **OLAP/データウェアハウス** | Star Schema / Snowflake | 分析クエリの高速化、非正規化による結合削減 |
| **多様な属性を持つエンティティ** | EAV / Document | スパース属性・動的スキーマに対応。属性の追加が頻繁な場合に有効 |
| **階層構造データ（組織図・カテゴリツリー）** | Hierarchical / Document | 親子関係の自然な表現。XMLデータベースやドキュメントDBが適合 |
| **複雑な関連を持つデータ（SNS・推薦システム）** | Graph | 多対多の複雑な関係をノード・エッジで効率的にクエリ可能 |
| **時系列データ・監査ログ** | Temporal Database | 有効期間や履歴管理を明示的にサポート。過去状態の再現が容易 |
| **大規模分散データ処理（ログ解析・ETL）** | MapReduce / Hadoop | 水平スケーラビリティ、障害耐性、並列処理 |
| **科学・画像・地理データ（多次元配列）** | Array DBMS | 多次元配列の効率的な格納・スライシング・集計演算 |
| **高速キャッシュ・セッション管理** | Key-Value | シンプルなデータ構造、インメモリ動作、低レイテンシ |
| **CMSやカタログ（柔軟なスキーマ）** | Document | 自己記述型ドキュメント、スキーマレス、ネストした構造のサポート |

---

## 各モデルクイックリファレンステーブル

| モデル | データ構造 | 長所 | 短所 | 代表的な実装 |
|-------|----------|------|------|------------|
| **Flat-file** | テキスト/バイナリファイル | シンプル、軽量 | 関係表現不可、スケーラビリティ限界 | CSV、TSV、JSONファイル |
| **Hierarchical** | ツリー構造 | 階層の自然な表現 | 多対多関係が困難 | IMS、XMLデータベース |
| **Network** | グラフ構造 | 多対多関係サポート | 複雑、クエリが難解 | IDMS、CODASYL |
| **Relational** | テーブル・行・列 | 柔軟性、ACID、正規化 | 大規模データで性能劣化 | PostgreSQL、MySQL、Oracle |
| **EAV** | Entity-Attribute-Value | スパース属性対応、動的スキーマ | クエリが複雑、性能劣化 | 医療システム、カスタムフィールド |
| **Star Schema** | ファクト + ディメンション | 分析クエリ高速、理解しやすい | データ冗長性、更新異常 | データウェアハウス |
| **Snowflake Schema** | 正規化されたディメンション | ストレージ効率 | 結合増加、複雑性 | データウェアハウス |
| **Document** | JSON/BSON/XML | スキーマレス、柔軟性 | 結合弱い、整合性保証困難 | MongoDB、CouchDB |
| **Key-Value** | Key → Value | 高速、シンプル | 構造化クエリ不可 | Redis、DynamoDB |
| **Graph** | ノード + エッジ | 関係探索高速、直感的 | 集計クエリ弱い | Neo4j、OrientDB |
| **Column-family** | 列指向ストレージ | 書込スケーラビリティ | トランザクション弱い | Cassandra、HBase |
| **Temporal** | 時間軸付きデータ | 履歴管理、監査対応 | 複雑性増加、ストレージ増大 | Oracle Flashback、Teradata |
| **Array DBMS** | 多次元配列 | 科学計算効率的 | 汎用性低い | SciDB、RasdaMan |

---

## ストレージ戦略選択ガイド

### Row-oriented vs Column-oriented

| 判断基準 | Row-oriented | Column-oriented |
|---------|-------------|----------------|
| **ワークロード** | OLTP（行全体の読み書き） | OLAP（列単位の集計・分析） |
| **読取パターン** | 多くの列を少数の行から取得 | 少数の列を大量の行から取得 |
| **書込パターン** | 頻繁な挿入・更新 | バッチ書込中心 |
| **圧縮効率** | 低い | 高い（列ごとに同じ型のデータ） |
| **代表例** | PostgreSQL、MySQL | Redshift、BigQuery、ClickHouse |

**選択ガイドライン:**
- トランザクション処理が中心 → Row-oriented
- 集計・レポート・分析が中心 → Column-oriented
- ハイブリッドワークロード → パーティション戦略やHybrid Transactional/Analytical Processing (HTAP)を検討

### Star Schema vs Snowflake Schema

| 判断基準 | Star Schema | Snowflake Schema |
|---------|------------|-----------------|
| **クエリ性能** | 高速（結合少ない） | やや遅い（結合増加） |
| **ストレージ効率** | 低い（冗長性） | 高い（正規化） |
| **メンテナンス** | 簡単 | やや複雑 |
| **理解しやすさ** | 高い | やや低い |

**選択ガイドライン:**
- クエリ性能最優先、ストレージコストが問題でない → Star Schema
- ストレージ効率重視、更新頻度が高い → Snowflake Schema
- ディメンションの階層が深い場合 → Snowflake Schema

### 分散処理の適用判断

| 条件 | MapReduce/Hadoop適用 | 従来RDBMS継続 |
|------|-------------------|--------------|
| **データ量** | TB〜PB級 | GB級 |
| **処理頻度** | バッチ処理中心 | リアルタイム要求 |
| **データ構造** | 非構造化・半構造化 | 構造化データ |
| **クエリ複雑度** | シンプルな集計・フィルタ | 複雑な結合・トランザクション |
| **スキーマ** | スキーマオンリード | スキーマオンライト |

---

## EAV（Entity-Attribute-Value）モデルの使いどころ

### 適用すべきケース
- **スパース属性**: エンティティごとに属性の有無が大きく異なる（例: EC商品カタログで「画面サイズ」は家電のみ）
- **動的スキーマ**: ユーザーが任意の属性を追加可能（カスタムフィールド機能）
- **多様なエンティティタイプ**: 同一テーブルで異なる種類のデータを扱う

### 避けるべきケース
- **密な属性**: ほとんどのエンティティが同じ属性を持つ場合（通常のテーブル設計が適切）
- **高頻度クエリ**: パフォーマンスが重要なOLTP処理（ピボット操作のオーバーヘッドが大きい）

### EAVクエリの注意点
```sql
-- 悪い例: 非効率なピボット
SELECT e.entity_id,
  MAX(CASE WHEN a.name = 'price' THEN v.value END) AS price,
  MAX(CASE WHEN a.name = 'brand' THEN v.value END) AS brand
FROM entities e
JOIN values v ON e.entity_id = v.entity_id
JOIN attributes a ON v.attribute_id = a.attribute_id
GROUP BY e.entity_id;

-- 改善策: マテリアライズドビュー、属性ごとのインデックス、JSONBなどの代替検討
```

---

## 時系列データベース設計パターン

### 単一軸: Valid Time（有効時間）
- **ユースケース**: 商品価格履歴、従業員所属履歴
- **実装**: `valid_from`, `valid_to` カラムを追加
- **クエリ例**: 特定日時点での有効レコードを取得

### 双軸: Valid Time + Transaction Time
- **ユースケース**: 監査ログ、金融取引
- **実装**: `valid_from/to` + `transaction_from/to`
- **メリット**: データの修正履歴も追跡可能

### 三軸: Valid + Transaction + Decision Time
- **ユースケース**: 保険契約、医療記録
- **実装**: 意思決定時刻も記録
- **注意**: 複雑度とストレージコストが増大

---

## グラフデータベースの適用判断

### 推奨ケース
- **SNS・ソーシャルグラフ**: フォロー関係、友達の友達クエリ
- **推薦システム**: ユーザー-商品-カテゴリの関係探索
- **不正検知**: トランザクションパターンの異常検出
- **ナレッジグラフ**: エンティティ間の複雑な関係表現

### クエリパターン例
```cypher
-- Neo4j: 友達の友達を探す（2ホップ）
MATCH (me:Person {name: 'Alice'})-[:FRIEND]->()-[:FRIEND]->(fof)
RETURN DISTINCT fof.name

-- RDBでは自己結合が複数必要で非効率
```

### 注意点
- 集計クエリ（SUM、AVG等）は弱い → RDBやOLAPエンジンと併用
- スキーマレスだが、ノード/エッジのラベルとプロパティの設計が重要

---

## 配列データベース（Array DBMS）

### 適用分野
- 科学計算（気候シミュレーション、衛星画像）
- 医療画像処理（CT、MRI）
- 地理空間データ（ラスターデータ）

### 特徴
- **多次元配列の効率的な格納**: チャンク分割、タイル化
- **配列演算のサポート**: スライス、リダクション、集約
- **クエリ例**: 特定範囲の配列セルを取得・集計

### 代表実装
- **SciDB**: 科学計算用の配列データベース
- **RasdaMan**: ラスターデータ管理

---

## ユーザー確認の原則（AskUserQuestion）

データベースモデル選択やストレージ戦略の決定時に、以下の項目を確認してください。

### データベースモデル選択時の確認項目

**必須確認事項:**
```
- データの性質（構造化/半構造化/非構造化）
- ワークロード（OLTP/OLAP/ハイブリッド）
- データ量と成長率（GB/TB/PB級）
- クエリパターン（結合多/集計多/グラフ探索）
- 整合性要件（ACID必須/結果整合性可）
- スキーマ安定性（固定/頻繁に変更）
```

**AskUserQuestion例:**
```python
AskUserQuestion(
    questions=[{
        "question": "このデータベースの主なワークロードは何ですか？",
        "header": "ワークロード",
        "options": [
            {
                "label": "OLTP（トランザクション処理）",
                "description": "頻繁な読み書き、行単位の更新、ACID保証が重要"
            },
            {
                "label": "OLAP（分析処理）",
                "description": "大量データの集計、レポート生成、複雑なクエリ"
            },
            {
                "label": "ハイブリッド",
                "description": "トランザクションと分析の両方"
            }
        ],
        "multiSelect": False
    }]
)
```

### ストレージ戦略選択時の確認項目

**必須確認事項:**
```
- 読取パターン（行全体/特定列のみ）
- 書込頻度（リアルタイム/バッチ）
- クエリタイプ（集計・分析/トランザクション）
- 圧縮率の重要度
```

### 確認不要な場面
- **標準的なOLTPアプリケーション** → Relationalモデルを直接提案
- **明確にドキュメント構造の説明がある** → Document DBを直接提案
- **グラフ探索が明示されている** → Graph DBを直接提案

---

## サブファイル一覧

このスキルは以下の3つのリファレンスファイルに分割されています：

### [MODELS.md](MODELS.md)
伝統的・基盤的データベースモデルの詳細リファレンス。

**含まれるモデル:**
- Flat-file Database
- Hierarchical Model
- Network Model (CODASYL)
- Dimensional Model
- Entity-Attribute-Value (EAV)
- Associative Model
- Semantic Data Model
- Multidimensional Databases

### [NOSQL-MODELS.md](NOSQL-MODELS.md)
NoSQL・特殊用途データベースモデルの詳細リファレンス。

**含まれるモデル:**
- Document-oriented Database
- XML Database
- Graph Database / Triplestore
- Temporal Database（Uni/Bi/Tri-temporal）
- Array DBMS

### [STORAGE-AND-PROCESSING.md](STORAGE-AND-PROCESSING.md)
ストレージ戦略と分散処理フレームワークの詳細リファレンス。

**トピック:**
- Star Schema / Snowflake Schema
- Row-oriented vs Column-oriented Systems
- RCFile（Record Columnar File）
- MapReduce フレームワーク
- Apache Hadoop エコシステム
- BigQuery
- AoS / SoA / AoSoA パターン

---

## 参考：モデル間の変換パターン

実際のプロジェクトでは、複数のデータベースモデルを組み合わせることがよくあります。

| 元モデル | 変換先モデル | ユースケース |
|---------|------------|------------|
| Relational → EAV | カスタムフィールド追加時 | EC商品の任意属性追加 |
| Relational → Document | スキーマ変更が頻繁 | CMS、カタログシステム |
| Relational → Graph | 多対多関係の探索が重要 | SNS、推薦システム |
| Relational → Star Schema | OLAP分析基盤構築 | データウェアハウス移行 |
| Document → Relational | 整合性保証が必要 | トランザクション処理への移行 |
| Row → Column | 分析ワークロード増加 | OLTP + OLAP統合 |

---

## まとめ

データベースモデル選択は、データの性質、ワークロード、スケーラビリティ要件、整合性要件などの複数の要因を総合的に判断する必要があります。このスキルで提供する意思決定マトリクスとクイックリファレンスを活用し、適切なモデルを選択してください。

**選択プロセス:**
1. データ特性の分析（構造、量、成長率）
2. ワークロードの特定（OLTP/OLAP/ハイブリッド）
3. 意思決定マトリクスで候補モデル絞り込み
4. 詳細なトレードオフ評価（サブファイル参照）
5. プロトタイプ検証
6. 最終決定とドキュメント化

複雑な要件の場合は、ハイブリッドアプローチ（例: Relational + Document、Row-oriented + Column-oriented）も検討してください。
