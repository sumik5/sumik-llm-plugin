# PostgreSQL 基礎・差分リファレンス

他のRDBMS（特にSQL Server）から移行する際に最初に直面するPostgreSQL固有の用語・SQL構文の差分、サーバー設定、データベース作成の実践ガイドです。

**対応章**: Ch2（基礎と差分）+ Ch5（サーバー設定）+ Ch7（データベース作成）

---

## 1. 用語差分

PostgreSQLでは他のRDBMSと同じ概念でも異なる名称を使います。ドキュメント検索やコミュニティへの質問時に必ず正しい用語を使うこと。

### 主要用語マッピング

| PostgreSQL用語 | 他DB相当語 | 説明 |
|---------------|-----------|------|
| **Cluster** | Instance | 単一の実行中PostgreSQLプロセス。1ホストに複数のClusterを異なるポートで起動可能 |
| **Role** | User / Login | ログイン可能なユーザーとグループの両方を表す。技術的な区別はなく、`LOGIN`属性の有無で使い分ける |
| **Tuple** | Row | 行データの学術的表現。スキーマ（型・制約）に準拠したRowインスタンス |
| **COPY** | BULK INSERT | 大量データ高速ロード専用コマンド。バイナリCOPYプロトコルはほとんどの言語SDKがサポート |
| **TOAST** | LOB / off-row storage | 可変長データのオフロウストレージ技術（後述） |

### Cluster vs Instance の注意点

```
[誤解しやすいケース]
"PostgreSQL cluster" → 単一プロセス（分散クラスターではない）
1ホスト上の複数Clusterは、それぞれ異なるポートを使用:
  Port 5432 → Cluster A (production)
  Port 5433 → Cluster B (staging)
```

### Role vs User の設計パターン

```sql
-- ユーザーロール（LOGIN属性あり = 接続可能）
CREATE ROLE app_user LOGIN PASSWORD 'secure_password';

-- グループロール（LOGIN属性なし = 接続不可、権限の束として機能）
CREATE ROLE readonly_group NOLOGIN;

-- ユーザーをグループに追加
GRANT readonly_group TO app_user;
```

**重要**: ロールはClusterレベルで作成されるが、接続するにはデータベースへの`CONNECT`権限が必要。

### TOAST の仕組み

TOASTは "The Oversized Attribute Storage Technique"（機知の効いた略）の略。

```
[TOASTの動作フロー]
1. 可変長データ（TEXT, BYTEA, JSONB等）が8KBページに収まらない
2. 自動的にオフロウの専用TOASTテーブルに格納
3. 元の行にはポインターを配置
4. クエリ実行時に透過的にマテリアライズして返す
5. 自動圧縮適用（LZ4またはpglzアルゴリズム）
```

**拡張フック**: TimescaleDBなどの拡張機能はTOASTフックを利用して独自圧縮を実装。

---

## 2. SQL構文差分

### データ型

#### オブジェクト名修飾子

| RDBMS | 修飾子 | ANSI準拠 |
|-------|--------|---------|
| SQL Server | `[Table One]`（ブラケット） | ✗ |
| **PostgreSQL** | `"Table One"`（ダブルクォート） | ✅ |

#### Case Rules（最重要注意点）

PostgreSQLはオブジェクト名を自動的に**小文字に変換**する。

```sql
-- 非修飾で作成 → 実際のテーブル名は "camelcase"
CREATE TABLE CamelCase (c1 TEXT);

-- すべて同じテーブルにアクセス可能（すべて小文字変換される）
SELECT * FROM CamelCase;   -- OK
SELECT * FROM camelcase;   -- OK
SELECT * FROM CAMELCASE;   -- OK

-- 修飾すると "CamelCase" を探すためエラー
SELECT * FROM "CamelCase"; -- ERROR: relation "CamelCase" does not exist
```

**ベストプラクティス**: PostgreSQLでは`snake_case`を使用。キャメルケースは避ける。

```sql
-- 推奨
CREATE TABLE camel_case (c1 TEXT);
```

#### TEXT型

```sql
-- ❌ SQL Serverからの移行でよくある間違い
ALTER TABLE products ADD COLUMN description VARCHAR(500);

-- ✅ PostgreSQLではTEXTを推奨
ALTER TABLE products ADD COLUMN description TEXT;
-- 最大幅制限が必要ならCHECK制約で実装
ALTER TABLE products ADD CONSTRAINT chk_desc_len CHECK (LENGTH(description) <= 500);
```

| 比較項目 | VARCHAR(n) | TEXT |
|---------|-----------|------|
| 最大長制限 | あり（コンパイル時） | なし（制約で後付け可） |
| パフォーマンス | 同等 | 同等 |
| TOAST対応 | ✅ | ✅ |
| 幅変更 | テーブル再書き込みが必要なことも | CHECK制約の変更だけで済む |

#### TIMESTAMPTZ（タイムゾーン付きタイムスタンプ）

```sql
-- データはUTCで保存。出力はセッションのタイムゾーンに変換
SHOW timezone;  -- Etc/UTC

-- セッションのタイムゾーン設定
SET TIME ZONE 'America/New_York';
SELECT NOW(); -- セッションTZで表示

-- 特定TZにキャストして一貫した出力を保証
SELECT last_update AT TIME ZONE 'UTC' FROM orders LIMIT 1;
```

**判断基準**:

| 要件 | 型選択 |
|------|-------|
| タイムゾーン変換が必要 | `TIMESTAMPTZ`（推奨） |
| 常に同一TZで保存・表示 | `TIMESTAMP` |
| 日付のみ | `DATE` |

#### ARRAY型

```sql
-- 型安全な配列カラム定義
CREATE TABLE article (
    id       SERIAL PRIMARY KEY,
    title    TEXT NOT NULL,
    tags     TEXT[]   -- TEXT配列
);

-- 挿入
INSERT INTO article (title, tags)
VALUES ('PostgreSQL Guide', ARRAY['database', 'postgresql', 'tutorial']);

-- 配列演算子での検索（GINインデックスが効く）
SELECT * FROM article WHERE 'postgresql' = ANY(tags);

-- 配列のオーバーラップ検索
SELECT * FROM article WHERE tags && ARRAY['database', 'sql'];
```

**注意**: ARRAYはJayWalkingアンチパターンの代替として使用可能だが、JunctionテーブルのM:N関係には不向き。単純なリスト属性に限定する。→ [`ANTIPATTERN-LOGICAL-DESIGN.md`](ANTIPATTERN-LOGICAL-DESIGN.md)

### SQL関数・演算子差分

| 機能 | SQL Server | PostgreSQL |
|------|-----------|-----------|
| 行数制限 | `SELECT TOP(10) ...` | `SELECT ... LIMIT 10` |
| 日付部分取得 | `DAY()`, `MONTH()`, `YEAR()` | `DATE_PART('day', ...)`, `EXTRACT(DAY FROM ...)` |
| 日付計算 | `DATEADD(MONTH, -1, SYSDATETIME())` | `NOW() - INTERVAL '1 month'` |
| 相関サブクエリ | `CROSS APPLY` / `OUTER APPLY` | `INNER JOIN LATERAL` / `LEFT JOIN LATERAL` |
| 変数付きコードブロック | `DECLARE @var ...` (直接実行) | `DO $$ ... $$` (匿名コードブロック) |

#### DATE_PART の使用例

```sql
-- SQL Server
SELECT YEAR(rental_start), COUNT(*) FROM rental GROUP BY YEAR(rental_start);

-- PostgreSQL: エイリアスをGROUP BY, ORDER BYに再利用可能
SELECT DATE_PART('year', rental_start) AS rental_year, COUNT(*)
FROM rental
GROUP BY rental_year
ORDER BY rental_year DESC;
```

#### INTERVAL による日付演算

```sql
-- 直感的な日付演算
SELECT * FROM orders WHERE created_at > NOW() - INTERVAL '30 days';
SELECT * FROM events WHERE event_date BETWEEN NOW() AND NOW() + INTERVAL '1 week';
SELECT * FROM logs  WHERE ts > NOW() - INTERVAL '2 hours 30 minutes';
```

#### LATERAL JOIN

```sql
-- 各ストアの直近1件のレンタルを取得
SELECT s.store_id, r.customer_id, r.rental_start
FROM store s
INNER JOIN LATERAL (
    SELECT customer_id, rental_start
    FROM rental
    WHERE store_id = s.store_id
    ORDER BY rental_start DESC
    LIMIT 1
) r ON true;
```

#### 匿名コードブロック（DO ブロック）

```sql
-- データ返却が不要な場合のアドホック処理
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM orders WHERE status = 'pending';
    RAISE NOTICE '保留中の注文数: %', v_count;
END;
$$;
```

**制限**: DO ブロックはデータセットを返せない。繰り返し使用するなら関数化する。→ [`DESIGN-POSTGRESQL-FUNCTIONS.md`](DESIGN-POSTGRESQL-FUNCTIONS.md)

---

## 3. サーバー設定

PostgreSQLは350以上の設定項目を持つ。設定は`postgresql.conf`で管理し、クラウド環境ではCLI/コンソールから変更。

```sql
-- 現在の設定値を確認
SHOW shared_buffers;
SHOW work_mem;

-- セッションレベルで変更可能な設定
SET work_mem = '64MB';

-- pg_settings から一覧確認
SELECT name, setting, unit, context FROM pg_settings WHERE name LIKE '%mem%';
```

### メモリ設定の全体像

```
[PostgreSQLのメモリ構造]

shared_buffers (固定確保)
├── 頻繁にアクセスされるデータページのキャッシュ
└── ディスクI/Oを削減する主要バッファ

work_mem (クエリノード単位)
├── ソート、ハッシュ結合ノードごとに確保
├── 複数ノード × 複数コネクションで乗算される
└── 不足するとディスクにスピル

maintenance_work_mem (バックグラウンド処理用)
├── VACUUM、CREATE INDEX、ANALYZE等で使用
└── 1プロセスタイプあたり1つなので影響が限定的

effective_cache_size (プランナーへのヒント)
└── 実際に確保するメモリではなくプランナーへの情報提供
```

### shared_buffers（バッファキャッシュ）

| 設定項目 | 内容 |
|---------|------|
| 役割 | データページの共有メモリキャッシュ |
| 推奨初期値 | 総メモリの25% |
| 上限目安 | 総メモリの35〜40%（超えるとインスタンス増強を検討） |
| 変更反映 | サーバー再起動が必要 |

```sql
-- キャッシュヒット率を監視（目標: 80〜85%以上）
SELECT
    SUM(heap_blks_read)  AS disk_reads,
    SUM(heap_blks_hit)   AS cache_hits,
    ROUND(
        SUM(heap_blks_hit)::NUMERIC
        / NULLIF(SUM(heap_blks_hit) + SUM(heap_blks_read), 0) * 100, 2
    ) AS cache_hit_ratio_pct
FROM pg_statio_user_tables;
```

### work_mem（クエリメモリ）

| 設定項目 | 内容 |
|---------|------|
| 役割 | ソート・ハッシュ等のクエリノードが使用するメモリ |
| デフォルト | 4MB |
| 推奨初期値 | 8〜16MB |
| セッション変更 | 可能（`SET work_mem = '32MB'`） |

```sql
-- ディスクスピルの検出（EXPLAIN ANALYZEの出力を確認）
EXPLAIN ANALYZE SELECT * FROM large_table ORDER BY created_at;
-- "Sort Method: external merge  Disk: 1234kB" が表示されたらwork_mem不足

-- 特定の重いクエリのみセッションで増量
SET work_mem = '256MB';
SELECT * FROM large_table ORDER BY created_at;
RESET work_mem;
```

**安全計算式**:

```
(max_connections × work_mem) + shared_buffers < 総利用可能メモリ
例: (100 × 16MB) + 4096MB = 5696MB → 8GBサーバーには安全
```

### maintenance_work_mem（メンテナンスメモリ）

| 設定項目 | 内容 |
|---------|------|
| 役割 | VACUUM, CREATE INDEX, ANALYZE等で使用 |
| デフォルト | 64MB（work_memの16倍） |
| 推奨計算式 | `(利用可能RAM) × 0.05` |
| 推奨上限 | 1GB（32GB RAM未満の場合） |

```sql
-- maintenance_work_mem の設定
ALTER SYSTEM SET maintenance_work_mem = '256MB';
SELECT pg_reload_conf(); -- 再起動不要
```

### 接続数とコネクションプーリング

```sql
-- デフォルト接続上限: 100
SHOW max_connections;

-- 現在の接続数確認
SELECT COUNT(*), state FROM pg_stat_activity GROUP BY state;
```

**コネクションプーラーの必要性**:

```
[問題] 各コネクションはプロセスを消費
  → アプリ100インスタンス × コネクション = メモリ枯渇リスク

[解決] PgBouncerを導入
  アプリN → PgBouncer（少数の永続接続を管理） → PostgreSQL
```

PgBouncer設定例（`pgbouncer.ini`）:

```ini
[databases]
myapp = host=postgres.internal port=5432 dbname=myapp

[pgbouncer]
listen_port = 6432
auth_type    = scram-sha-256
pool_mode    = transaction   ; session / transaction / statement
max_client_conn  = 1000
default_pool_size = 20
```

| pool_mode | 特性 | 推奨用途 |
|-----------|------|---------|
| `session` | 最も安全。接続状態を保持 | prepared statementを多用する場合 |
| `transaction` | 高スループット（推奨） | 一般的なWebアプリ |
| `statement` | 最高スループット | prepared statement使用不可 |

### クエリプラン設定

#### random_page_cost

| ディスクタイプ | 推奨値 | 理由 |
|-------------|-------|------|
| HDD（旧来） | `4.0`（デフォルト） | ランダムアクセスは順次の4倍遅い |
| SSD | `1.1` | ランダムと順次のコスト差が小さい |
| NVMe | `1.0〜1.1` | ほぼ同等 |

```sql
-- インスタンスレベルで設定
ALTER SYSTEM SET random_page_cost = 1.1;
SELECT pg_reload_conf();
```

#### effective_cache_size

```sql
-- 推奨: 総RAMの50%（shared_buffersを含む）
-- 16GBサーバーの例: 8GB
ALTER SYSTEM SET effective_cache_size = '8GB';
SELECT pg_reload_conf();
```

**重要**: `effective_cache_size`は**実際にメモリを確保しない**。プランナーへのヒントのみ。
高い値を設定するとインデックススキャンが優先されやすくなる。

#### JIT（Just-In-Time コンパイル）

```sql
-- PostgreSQL 11以降でデフォルト有効
SHOW jit;  -- on

-- CPU負荷の高いクエリで効果的。ただしオーバーヘッドになる場合も
-- インスタンスレベルで無効化
ALTER SYSTEM SET jit = off;
SELECT pg_reload_conf();

-- 特定クエリのみ制御
SET jit = off;  -- セッションレベル
EXPLAIN ANALYZE SELECT ...; -- JIT情報がプランに表示される
```

| JITの効果 | 状況 |
|----------|------|
| 有効 | CPU負荷の高い集計・フィルター処理 |
| 逆効果 | 単純なクエリ、短時間のOLTPクエリ |

---

## 4. データベース作成

### データベースの概念

```
[PostgreSQL オブジェクト階層]
Cluster（実行プロセス）
├── Database A
│   ├── Schema public
│   │   ├── Table, View, Index, Function...
│   └── Schema app
├── Database B
└── template0, template1（システムテンプレート）
```

**デフォルトで3つのデータベース**が作成される:

| データベース | 用途 |
|-----------|------|
| `postgres` | 初期接続用デフォルトDB。管理タスクに使用 |
| `template1` | 新規DB作成時のデフォルトテンプレート |
| `template0` | 変更禁止の初期状態テンプレート。エンコーディング変更時等に使用 |

### データベース作成

```sql
-- 最もシンプルな作成
CREATE DATABASE myapp;

-- オーナー・エンコーディング・テーブルスペース指定
CREATE DATABASE myapp
    OWNER    = app_admin
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    TEMPLATE = template0;   -- カスタムエンコーディングにはtemplate0を使用
```

```bash
# CLIからも作成可能（CREATE DATABASEのラッパー）
createdb -U postgres myapp
```

### データベース変更・削除

```sql
-- オーナー変更
ALTER DATABASE myapp OWNER TO new_owner;

-- 名前変更（接続を切ってから実行）
ALTER DATABASE myapp RENAME TO myapp_v2;

-- 設定のカスタマイズ（接続時に自動適用）
ALTER DATABASE myapp SET datestyle = 'ISO, DMY';
ALTER DATABASE myapp SET timezone = 'Asia/Tokyo';

-- 設定リセット
ALTER DATABASE myapp RESET ALL;

-- 削除（接続中のユーザーがいると失敗）
DROP DATABASE IF EXISTS myapp;

-- アクティブな接続を強制終了して削除（危険: 慎重に使用）
DROP DATABASE IF EXISTS myapp WITH (FORCE);
```

### テンプレートデータベース

```sql
-- template1をカスタマイズすると、以後作成するすべてのDBに引き継がれる
\c template1
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  -- 全新規DBに自動インストール
\c postgres

-- 既存DBをテンプレートにする
ALTER DATABASE myapp_template WITH IS_TEMPLATE = TRUE;

-- カスタムテンプレートから作成
CREATE DATABASE newdb WITH TEMPLATE = myapp_template;
```

**注意**: `template0`は変更禁止。`template1`は慎重に変更する。

### テーブルスペース

テーブルスペースを使うとデータの物理保存場所を制御できる。

```sql
-- テーブルスペース作成（ディレクトリはPostgreSQLユーザーが所有していること）
CREATE TABLESPACE fast_ssd LOCATION '/mnt/nvme/pgdata';

-- テーブルスペースを指定してDB作成
CREATE DATABASE analytics TABLESPACE fast_ssd;

-- 既存DBのデフォルトテーブルスペースを変更
ALTER DATABASE myapp SET TABLESPACE fast_ssd;

-- 特定テーブルだけを別テーブルスペースに移動
ALTER TABLE large_logs SET TABLESPACE fast_ssd;

-- テーブルスペース一覧確認
SELECT spcname, pg_tablespace_location(oid) FROM pg_tablespace;
```

| テーブルスペースの活用 | 具体例 |
|-----------------|-------|
| ホットデータをNVMeに | 頻繁アクセスのトランザクションテーブル |
| コールドデータをHDDに | アーカイブログ、古い履歴データ |
| インデックスを高速ディスクに | `CREATE INDEX idx ON tbl(col) TABLESPACE fast_ssd` |

---

## 5. 相互参照

| トピック | 参照先 |
|--------|-------|
| セキュリティ・ロール設定の詳細 | [`DESIGN-POSTGRESQL-SECURITY.md`](DESIGN-POSTGRESQL-SECURITY.md) |
| 関数・プロシージャ（匿名ブロックの発展） | [`DESIGN-POSTGRESQL-FUNCTIONS.md`](DESIGN-POSTGRESQL-FUNCTIONS.md) |
| インデックス種別（GIN/GiST等） | [`POSTGRESQL-CORE-OBJECTS.md`](POSTGRESQL-CORE-OBJECTS.md) |
| クエリチューニング（work_memのスピル確認） | [`POSTGRESQL-QUERY-TUNING.md`](POSTGRESQL-QUERY-TUNING.md) |
| MVCCとVACUUM（dead tuplesの仕組み） | [`POSTGRESQL-MVCC-VACUUM.md`](POSTGRESQL-MVCC-VACUUM.md) |
| 拡張機能（pg_stat_statements等） | [`POSTGRESQL-EXTENSIONS.md`](POSTGRESQL-EXTENSIONS.md) |
| マイクロサービスデータアーキテクチャ | [`DESIGN-POSTGRESQL-ARCHITECTURE.md`](DESIGN-POSTGRESQL-ARCHITECTURE.md) |
