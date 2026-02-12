# PostgreSQL マイクロサービスデータアーキテクチャ

高トランザクション・高可用性を要求されるモダンアプリケーションにおいて、データベース層をどのように分割・統合・スケールさせるかは重要な設計判断です。このガイドでは、PostgreSQLの機能を活用したマイクロサービスデータアーキテクチャの設計原則と実装パターンを示します。

---

## 1. モジュール化の基本単位

PostgreSQLには複数のデータ表現オブジェクト（サーバー、データベース、スキーマ）がありますが、**データベースをモジュール化の基本単位とすることを推奨**します。

### なぜデータベースをモジュール化単位とするのか

| 判断基準 | データベース単位 | スキーマ単位 | サーバー単位 |
|---------|----------------|------------|------------|
| API定義の分離 | ✅ スキーマでAPI定義可能 | △ 名前空間のみ | × 困難 |
| 独立スケーリング | ✅ 他サーバーへの移動が容易 | × 同一サーバー内に制限 | ✅ しかし粒度が粗すぎる |
| 論理レプリケーション | ✅ データベース間で一貫した通信プロトコル | △ 追加設定が必要 | ✅ しかし粒度が粗すぎる |
| コンテナ環境での適合性 | ✅ 1DB/1サーバーパターンと整合 | × | ✅ |
| モジュール境界の明確さ | ✅ 明確な境界 | △ 同一データベース内で曖昧 | ✅ しかし粒度が粗すぎる |

**推奨パターン:**
```
- データサービスA（スクーターのスケジュール） → データベースA
- データサービスB（スクーターのメンテナンス） → データベースB
- データサービスC（スクーターの位置情報） → データベースC
- データサービスD（スクーターモデル定義） → データベースD
```

各データベースは必要に応じて同一サーバーに配置することも、別々のサーバーに配置することも可能です。データベース単位でモジュール化しておけば、物理配置の変更時もレプリケーション定義やFDW定義のネットワークアドレスを変更するだけで済みます。

### コンテナ化環境での1DB/1サーバーパターン

コンテナ化環境（Docker, Kubernetes等）では、**1つのPostgreSQLインスタンス（サーバー）に1つのデータベース**というパターンが増えています。データベース単位でモジュール化しておけば、このパターンへの移行もスムーズです。

---

## 2. スキーマによるAPI定義

データベースを基本単位としたモジュール化の中で、**スキーマを使って公開APIと内部実装を分離**します。

### API設計の基本原則

```sql
-- データベース内の構造
CREATE DATABASE ecommerce_service;

\c ecommerce_service

-- 内部実装スキーマ（外部からのアクセスを禁止）
CREATE SCHEMA customer;
CREATE SCHEMA sales;
CREATE SCHEMA product_reference;
CREATE SCHEMA inventory;

-- 公開APIスキーマ（外部からアクセス可能な唯一のスキーマ）
CREATE SCHEMA api;
```

### 公開API定義

APIスキーマには、ビュー・関数・プロシージャのみを配置します。実際のテーブルは内部スキーマに隠蔽します。

```sql
-- api スキーマ内のビュー
CREATE VIEW api.customers AS
SELECT customer_id, customer_name, email
FROM customer.customer_base;

-- api スキーマ内の関数
CREATE FUNCTION api.get_customer_orders(p_customer_id INT)
RETURNS TABLE(order_id INT, order_date DATE, total_amount DECIMAL)
LANGUAGE SQL
SECURITY DEFINER  -- ← この関数の実行者権限で内部スキーマにアクセス
AS $$
  SELECT o.order_id, o.order_date, o.total_amount
  FROM sales.orders o
  WHERE o.customer_id = p_customer_id;
$$;
```

### SECURITY DEFINERによる内部スキーマ保護

**SECURITY DEFINER** を指定した関数は、呼び出し元のユーザーではなく、関数の所有者の権限で実行されます。これにより、以下を実現できます:

- アプリケーションユーザーには内部スキーマへの直接アクセス権を与えない
- 内部スキーマへのアクセスはすべてAPI関数・プロシージャ経由に制限
- データ整合性ルールとアクセス制御をAPI層で一元管理

```sql
-- すべてのユーザーから内部スキーマへのアクセスを剥奪
REVOKE ALL ON SCHEMA customer, sales, product_reference, inventory FROM PUBLIC;

-- API経由のアクセスのみ許可
GRANT USAGE ON SCHEMA api TO application_role;
GRANT EXECUTE ON FUNCTION api.get_customer_orders TO application_role;
```

### search_pathによるAPIバージョニング

APIの変更が必要になった場合、新しいAPIスキーマを作成し、`search_path`で切り替えることができます。

```sql
-- 新しいAPIバージョンを作成
CREATE SCHEMA api_v2;

-- 新バージョンのビュー・関数を定義
CREATE VIEW api_v2.customers AS
SELECT customer_id, customer_name, email, phone  -- phoneフィールド追加
FROM customer.customer_base;

-- ユーザー接続時にsearch_pathを変更
ALTER ROLE application_role SET search_path = api_v2, api, public;
```

既存の接続はそのまま `api` スキーマを使い続け、新しい接続は `api_v2` スキーマを優先的に使用します。これにより**ゼロダウンタイムでのAPIバージョンアップ**が可能になります。

---

## 3. クロスサービスデータ共有

データサービスが独立したデータベースに分離されている場合、他サービスのデータを参照する必要が生じます。PostgreSQLでは主に2つのアプローチがあります。

### 3.1 Foreign Data Wrappers (FDW)

**FDWはリモートデータベースのテーブルをローカルテーブルのようにクエリできる**機能です。データの重複はなく、常に最新のデータを参照できます。

#### FDWの特性

| 特性 | 内容 |
|------|------|
| データの重複 | なし（リモートに問い合わせ） |
| レイテンシ | 低レイテンシ環境が必須 |
| 整合性 | リアルタイムで最新データを参照 |
| ネットワーク障害 | 障害時はアクセス不可 |
| 適用ケース | 同一データセンター内のサービス間参照 |

#### FDWの実装例

```sql
-- リモートサーバー定義（スクーターメンテナンスサービス）
CREATE SERVER maintenance_service
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host 'maintenance-db.internal', port '5432', dbname 'maintenance');

-- ユーザーマッピング
CREATE USER MAPPING FOR schedule_user
  SERVER maintenance_service
  OPTIONS (user 'maintenance_reader', password 'secret');

-- 外部テーブル定義（API経由でアクセス）
CREATE FOREIGN TABLE schedule.maintenance_status (
  scooter_id INT,
  next_maintenance_date DATE,
  is_operational BOOLEAN
)
SERVER maintenance_service
OPTIONS (schema_name 'api', table_name 'maintenance_status');

-- ローカルデータとリモートデータを結合したクエリ
SELECT s.scooter_id, s.available_from, m.is_operational
FROM schedule.scooter_schedule s
JOIN schedule.maintenance_status m ON s.scooter_id = m.scooter_id
WHERE s.available_from >= CURRENT_DATE
  AND m.is_operational = true;
```

**重要:** FDWは必ず**API経由**でアクセスします。内部スキーマに直接アクセスすると、サービス間の密結合を招きます。

### 3.2 Logical Replication（論理レプリケーション）

**論理レプリケーションはPostgreSQLのWrite-Ahead Log (WAL)を利用したpub/subフレームワーク**です。データは複製されますが、ネットワーク遅延や一時的な障害に強い特性を持ちます。

#### 論理レプリケーションの特性

| 特性 | 内容 |
|------|------|
| データの重複 | あり（サブスクライバー側に複製） |
| レイテンシ | 高レイテンシ環境でも動作 |
| 整合性 | 若干の遅延あり（eventual consistency） |
| ネットワーク障害 | 一時的な切断を許容し、復旧後に同期 |
| 適用ケース | 参照データ配信、データ統合、地理分散 |

#### 論理レプリケーションの実装例

```sql
-- パブリッシャー側（製品定義サービス）
CREATE PUBLICATION product_reference_pub
FOR TABLE product.product_definition, product.product_price;

-- サブスクライバー側（eコマースサービス East Coast）
CREATE SUBSCRIPTION product_reference_sub
CONNECTION 'host=product-db.internal port=5432 dbname=product_reference user=repl_user password=secret'
PUBLICATION product_reference_pub;
```

#### 行・列レベルフィルタリング

PostgreSQL 15以降、論理レプリケーションで**特定の行・列のみを複製**できます。

```sql
-- 特定リージョンの製品のみをレプリケート
CREATE PUBLICATION product_reference_pub_east
FOR TABLE product.product_definition WHERE (region = 'EAST');

-- 価格情報のうち、割引価格カラムは除外
CREATE PUBLICATION product_reference_pub_limited
FOR TABLE product.product_price (product_id, base_price);  -- discount_priceは除外
```

#### テーブルパーティショニングとの組み合わせ

論理レプリケーションとテーブルパーティショニングを組み合わせることで、**シャーディングしたデータを中央に統合**できます。

```sql
-- 統合先データベース（Central Analytics）
CREATE TABLE analytics.customer (
  customer_id INT,
  customer_name TEXT,
  region TEXT
) PARTITION BY LIST (region);

-- East Coast パーティション
CREATE TABLE analytics.customer_east PARTITION OF analytics.customer
FOR VALUES IN ('EAST');

-- West Coast パーティション
CREATE TABLE analytics.customer_west PARTITION OF analytics.customer
FOR VALUES IN ('WEST');

-- East Coast eコマースサービスから customer_east へレプリケート
CREATE SUBSCRIPTION customer_east_sub
CONNECTION 'host=ecommerce-east.internal ...'
PUBLICATION customer_pub;

-- West Coast eコマースサービスから customer_west へレプリケート
CREATE SUBSCRIPTION customer_west_sub
CONNECTION 'host=ecommerce-west.internal ...'
PUBLICATION customer_pub;
```

このパターンにより、分散したトランザクションデータを単一の分析データベースに統合できます。

---

## 4. スケーリングパターン

PostgreSQLのマイクロサービスデータアーキテクチャでは、以下の2つのスケーリングパターンを組み合わせます。

### 4.1 モジュラーサービスの分散

データサービスごとに負荷が異なる場合、**個々のデータベースを別サーバーに配置**します。

```
[初期構成]
サーバーA: スケジュール、メンテナンス、位置情報、モデル定義

↓ スケジュールサービスの負荷が増大

[スケールアウト後]
サーバーA: メンテナンス、位置情報、モデル定義
サーバーB: スケジュール（専用サーバーに移動）
```

**論理レプリケーションを使ったゼロダウンタイム移行:**

```sql
-- サーバーBに新しいデータベースを作成し、サーバーAからレプリケート
-- 1. サーバーAをパブリッシャーに設定
CREATE PUBLICATION schedule_migration_pub
FOR ALL TABLES;

-- 2. サーバーBをサブスクライバーに設定
CREATE SUBSCRIPTION schedule_migration_sub
CONNECTION 'host=serverA ...'
PUBLICATION schedule_migration_pub;

-- 3. レプリケーションが追いついたら、アプリケーション接続先をサーバーBに切り替え
-- 4. サーバーAのスケジュールデータベースを削除
```

### 4.2 フリート（シャーディング）による水平スケーリング

同じデータサービスの**複数インスタンスを地理的・論理的に分散**します。

```
[フリート構成の例]
- eコマースサービス East Coast（顧客: 東海岸エリア）
- eコマースサービス West Coast（顧客: 西海岸エリア）
- eコマースサービス Midwest（顧客: 中西部エリア）

共通の製品定義データ → 論理レプリケーションで各フリートに配信
各フリートのトランザクションデータ → 中央分析DBに論理レプリケーションで統合
```

---

## 5. 接続管理

マイクロサービスアーキテクチャでは、アプリケーションインスタンスが頻繁にスケールアップ・ダウンします。PostgreSQLへの接続数を効率的に管理するために**接続プーラー（Connection Pooler）**を使用します。

### PgBouncerによる接続プーリング

**PgBouncer**はPostgreSQLの接続プーラーで、アプリケーションとデータベースの間に配置します。

```
[N:1の接続モデル]
アプリケーションインスタンス1 ────┐
アプリケーションインスタンス2 ────┤
アプリケーションインスタンス3 ────┼→ PgBouncer → PostgreSQLデータサービス
     ...                         │
アプリケーションインスタンスN ────┘
```

#### PgBouncerの利点

| 利点 | 説明 |
|------|------|
| 接続のオーバーヘッド削減 | PostgreSQLへの接続数を制限し、リソース消費を抑制 |
| スケーラビリティ向上 | アプリケーションインスタンスを自由に増減可能 |
| 接続の再利用 | 一度確立した接続を複数のクライアントで共有 |

#### PgBouncerの設定例

```ini
[databases]
ecommerce_service = host=postgres-db.internal port=5432 dbname=ecommerce

[pgbouncer]
listen_addr = *
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
```

**pool_mode:**
- `session`: 接続ごとにプール（最も安全、トランザクションをまたぐ状態を維持）
- `transaction`: トランザクションごとにプール（推奨、高いスループット）
- `statement`: 文ごとにプール（最高のスループット、prepared statementが使えない）

---

## 6. アーキテクチャ統合図

すべての要素を統合すると、以下のような構成になります:

```
[アプリケーション層]
  App Instance 1, 2, 3, ... N
         ↓ (libpq / JDBC / psycopg2)
  ┌──────────────────┐
  │   PgBouncer      │ ← 接続プーリング
  └──────────────────┘
         ↓
[データサービス層]
  ┌────────────────────────────────────────┐
  │ データサービスA（Database A）            │
  │ ├ schema: api (公開API)                  │
  │ ├ schema: internal (内部実装)            │
  │ └ FDW → データサービスB (API経由)         │
  └────────────────────────────────────────┘
         ↓ 論理レプリケーション
  ┌────────────────────────────────────────┐
  │ 中央分析サービス（Central Analytics）     │
  │ - パーティションテーブルで統合            │
  │ - East/West/Midwestのデータを統合        │
  └────────────────────────────────────────┘
```

---

## まとめ

PostgreSQLマイクロサービスデータアーキテクチャの設計原則:

1. **データベースをモジュール化の基本単位とする**（スキーマやサーバーではなく）
2. **スキーマでAPIと内部実装を分離**（SECURITY DEFINERで内部保護）
3. **FDWでリアルタイムクロスサービス参照**（低レイテンシ環境）
4. **論理レプリケーションで参照データ配信とデータ統合**（高レイテンシ環境・分散環境）
5. **モジュラーサービス分散とフリートでスケールアウト**（論理レプリケーションでゼロダウンタイム移行）
6. **PgBouncerで接続プーリング**（N:1接続モデル）

このアーキテクチャにより、スケーラビリティ・アジリティ・トランザクション整合性を同時に実現できます。
