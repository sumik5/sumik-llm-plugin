# PostgreSQL 拡張機能リファレンス

PostgreSQLの最大の差別化要素である拡張機能（Extensions）の仕組み、管理方法、および主要拡張機能のガイドです。

**対応章**: Ch8（Extensions）

---

## 1. 拡張機能とは

PostgreSQL 9.1（2011年9月）から導入された拡張機能システムにより、コアに手を加えずに機能追加が可能になった。これがPostgreSQLが爆発的に普及した主要因の一つ。

### 拡張機能でできること

| レベル | 機能の例 |
|-------|---------|
| **シンプル** | PL/pgSQL関数・ビューのパッケージング。DBAチームのメンテナンス関数をバージョン管理 |
| **中間** | 新しいデータ型、演算子、ルールの追加 |
| **高度** | C/Rustで実装した新インデックス型・クエリプランフック・データ圧縮の変更 |

**約30のフック**がセキュリティ・クエリ計画・実行・PL/pgSQLイベントをカバーしており、拡張機能はこれらを通じてPostgreSQL内部に介入できる。

### 拡張機能の特性

- **データベース単位でインストール**: 同一Cluster内の複数DBそれぞれにCREATE EXTENSIONが必要
- **バージョン管理**: 拡張機能はバージョン番号を持ち、PostgreSQLがどのDBに何のバージョンが入っているかを追跡
- **実装言語**: SQL, PL/pgSQL（シンプル）またはC/Rust pgrx（高性能・高機能）

---

## 2. 拡張機能のライフサイクル

### 利用可能な拡張機能の確認

```sql
-- Clusterで利用可能な拡張機能一覧（デフォルトバージョンと現在インストール済みを表示）
SELECT * FROM pg_available_extensions ORDER BY name;

-- すべてのバージョンを一覧（superuser必須か、trustedかも確認できる）
SELECT name, version, installed, superuser, trusted
FROM pg_available_extension_versions
ORDER BY name, version;
```

| 列名 | 説明 |
|-----|------|
| `default_version` | バージョン未指定でインストールした場合に適用される |
| `installed_version` | 現在このDBにインストールされているバージョン（NULLはインストール未） |
| `superuser` | スーパーユーザーのみインストール可能か |
| `trusted` | `CREATE`権限を持つ通常ユーザーでもインストール可能か |

### インストール（CREATE EXTENSION）

```sql
-- デフォルトバージョンでインストール（簡単だが非推奨）
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- バージョンを明示指定（推奨: 環境間の差異を防ぐ）
CREATE EXTENSION IF NOT EXISTS pg_stat_statements VERSION '1.10';
```

**なぜバージョンを明示するか**: 環境（dev/staging/prod）によってClusterに入っているパッケージバージョンが異なる場合があり、未指定だと想定外のバージョンが入る可能性がある。

**Tip**: `template1`に拡張機能をインストールすると、以後作成するすべてのDBに自動で入る。

```sql
-- template1に入れることで全新規DBへ自動インストール
\c template1
CREATE EXTENSION IF NOT EXISTS pg_stat_statements VERSION '1.10';
\c postgres
```

### 更新（ALTER EXTENSION UPDATE）

```sql
-- 特定バージョンへアップデート（新バージョンがCluster側に必要）
ALTER EXTENSION pg_stat_statements UPDATE TO '1.11';
```

**注意**: UPDATEするバージョンがClusterにインストールされていなければエラー。バージョン指定は必須でありメリットでもある。

### 削除（DROP EXTENSION）

```sql
-- 拡張機能を削除（デフォルト: RESTRICT = 他オブジェクトが依存していれば失敗）
DROP EXTENSION IF EXISTS pg_stat_statements;

-- 依存するオブジェクトごと強制削除（危険: 慎重に使用）
DROP EXTENSION pg_stat_statements CASCADE;
```

### バージョン管理の判断フロー

```
拡張機能を使う前に確認すること:
  ↓
1. pg_available_extension_versionsで利用可能バージョンを確認
  ↓
2. 全環境（dev/staging/prod）で同じバージョンが利用可能か確認
  ↓
3. VERSION '...' を明示してCREATE/UPDATE
  ↓
4. pg_available_extensionsでinstalled_versionを検証
```

---

## 3. 拡張機能の入手方法

### 判断テーブル: 入手先の選択

| 環境・状況 | 推奨入手先 |
|-----------|----------|
| マネージドDBaaS（RDS, Azure DB等） | クラウドプロバイダーのドキュメントを確認 |
| DockerコンテナでPostgreSQL | 目的に特化した拡張済みイメージを使用 |
| Linux自己管理（Debian/Ubuntu） | aptパッケージマネージャー |
| Linux自己管理（RHEL/Rocky等） | yum/dnfパッケージマネージャー |
| 最新/ニッチな拡張機能を探す | PGXN または Trunk |

### 拡張機能レジストリ

#### PGXN（PostgreSQL Extension Network）

```bash
# pgxnclientのインストール（Python 3必須）
sudo pip install pgxnclient

# 拡張機能をインストール（Clusterへのファイル配置）
pgxn install pgsql_tweaks

# バージョン指定
pgxn install 'pgsql_tweaks=0.10.5'
```

インストール後、DBへの有効化は別途`CREATE EXTENSION`が必要:

```sql
CREATE EXTENSION IF NOT EXISTS pgsql_tweaks;
```

#### Trunk（Tembo社製、より現代的）

```bash
# Trunk CLIのインストール
curl https://trunk.sh/install | bash

# 拡張機能のインストール
trunk install pgvector
```

**PGXN vs Trunk の比較**:

| 特徴 | PGXN | Trunk |
|-----|------|-------|
| 設立 | 2010年代初期（老舗） | 2023年〜（新しい） |
| 管理 | コミュニティ | Tembo社（PGXN創設者が参画） |
| UI | シンプル | よりモダン |
| 登録数 | 多い | 増加中 |

### Dockerコンテナ

拡張機能が事前インストールされた公式・非公式イメージの例:

| イメージ | 特徴 |
|---------|------|
| `postgis/postgis` | PostGIS（地理空間）を含む |
| `timescale/timescaledb` | 時系列特化の拡張機能群 |
| `supabase/postgres` | Supabase向けの拡張機能セット |
| `postgres-ai/custom-images` | 多数の標準拡張機能を含む |

### Linux パッケージマネージャー

```bash
# Debian/Ubuntu での pg_cron インストール例
sudo apt-get -y install postgresql-16-cron

# インストール後、postgresql.confに shared_preload_libraries を追加が必要な場合も
```

### クラウドDBaaS

各クラウドプロバイダーは利用可能な拡張機能リストを個別に管理している。

- **共通点**: `pg_stat_statements`, `pg_partman`, `pg_cron`等はほとんどのプロバイダーで利用可能
- **注意点**: AI/ベクトル拡張は提供状況が異なる（pgvector vs azure_ai vs alloyDB等）
- **権限**: クラウドではsuperuserを持てないため、trusted拡張のみインストール可能な場合がある

---

## 4. 注意点（Two Words of Caution）

### 環境間の拡張管理

**問題**: 開発・ステージング・本番で異なるメンテナンスウィンドウを設けていると、拡張機能バージョンが環境間でズレる。

```
[典型的な障害シナリオ]
1. 開発環境: pg_partman v5.1.0 を使用した新機能をリリース
2. ステージング: pg_partman v5.0.x のまま（メンテナンス未実施）
3. 本番リリース → ステージングで動作確認済みのはずが本番でエラー
```

**対策**:

```sql
-- 定期的に全環境の拡張機能バージョンを記録・比較
SELECT name, installed_version
FROM pg_available_extensions
WHERE installed_version IS NOT NULL
ORDER BY name;
```

常に`VERSION '...'`を明示し、インストール時にバージョン不一致を早期検知する。

### バックアップ・リストア時の注意

**問題**: `pg_dump`のダンプファイルは拡張機能のバージョン情報を保持しない。

```sql
-- ダンプに含まれる内容（バージョン情報なし）
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  -- バージョン未指定

-- リストア先の新Clusterで使われるバージョンはCluster側のデフォルト
-- → 期待と異なるバージョンが入る可能性
```

**対策チェックリスト**:
- [ ] 移行前に`pg_available_extension_versions`でリストア先の利用可能バージョンを確認
- [ ] リストア先に必要バージョンのパッケージをインストール
- [ ] リストア後に各DBの`pg_available_extensions`でバージョンを検証

---

## 5. 主要拡張機能ガイド

### pg_stat_statements（クエリ統計）

**結論: インストール必須。すべてのDBに。**

```sql
-- postgresql.conf に追加（サーバー再起動が必要）
-- shared_preload_libraries = 'pg_stat_statements'

-- DBへのインストール
CREATE EXTENSION IF NOT EXISTS pg_stat_statements VERSION '1.10';

-- 最も遅いクエリTOP10を確認
SELECT
    query,
    calls,
    mean_exec_time,
    total_exec_time,
    rows
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- 統計をリセット（定期メンテナンス）
SELECT pg_stat_statements_reset();
```

詳細な活用方法 → [`POSTGRESQL-REPLICATION-MONITORING.md`](POSTGRESQL-REPLICATION-MONITORING.md)

---

### postgis（地理空間データベース）

世界最高の地理空間オープンソースDB拡張。PostGISを使えばPostgreSQLがフル機能GISデータベースに変わる。

```sql
CREATE EXTENSION IF NOT EXISTS postgis;

-- 地理座標カラム
CREATE TABLE stores (
    id      SERIAL PRIMARY KEY,
    name    TEXT,
    location GEOMETRY(POINT, 4326)  -- WGS84座標系
);

-- 現在地から最寄り10店舗（緯度35.6762°N, 経度139.6503°E = 東京）
SELECT
    name,
    ST_Distance(location::geography, ST_MakePoint(139.6503, 35.6762)::geography) AS dist_meters
FROM stores
ORDER BY dist_meters
LIMIT 10;
```

**Docker**での簡単セットアップ:

```bash
docker run -d --name postgis -e POSTGRES_PASSWORD=pass postgis/postgis:16-3.4
```

---

### pg_hint_plan（クエリヒント）

PostgreSQLのクエリプランナーにOracleスタイルのヒントを付与する拡張機能。

```sql
CREATE EXTENSION IF NOT EXISTS pg_hint_plan;

-- コメント形式でヒントを追加（HashJoin強制 + SeqScan強制）
EXPLAIN SELECT /*+ HashJoin(a b) SeqScan(a) */
    a.id, b.name
FROM table_a a
JOIN table_b b ON a.id = b.a_id;
```

**利用可能なヒントの分類**:

| カテゴリ | ヒント例 |
|---------|---------|
| スキャン方法 | `SeqScan`, `IndexScan`, `BitmapScan`, `IndexOnlyScan` |
| 結合方法 | `NestLoop`, `HashJoin`, `MergeJoin` |
| 結合順序 | `Leading(t1 t2 t3)` |
| 並列度 | `Parallel(t 4)` |
| 行数推定 | `Rows(t1 t2 #500)` |

**注意**:
1. ヒントが必要な状況はプランナーの問題を示すことが多い → まずは統計情報更新を試みる
2. 定期的にヒントの有効性を見直す（データ量変化で不要になることがある）

---

### pg_cron（ジョブスケジューラー）

PostgreSQL内蔵のcronスケジューラー。

```sql
-- postgresql.conf に追加（再起動が必要）
-- shared_preload_libraries = 'pg_cron'
-- cron.database_name = 'postgres'  -- pg_cronをインストールするDB

-- pg_cronのインストール（1つのDBにのみインストール可能）
\c postgres
CREATE EXTENSION pg_cron;

-- 毎日午前2時（UTC）にANALYZEを実行
SELECT cron.schedule('daily-analyze', '0 2 * * *', 'ANALYZE');

-- 別DBでのSQL実行（schedule_in_database使用）
SELECT cron.schedule_in_database(
    'nightly-cleanup',
    '0 3 * * *',           -- cron式
    'DELETE FROM logs WHERE created_at < NOW() - INTERVAL ''90 days''',
    'myapp'                -- 実行対象DB名
);

-- ジョブ一覧確認
SELECT * FROM cron.job;

-- ジョブ実行ログ確認
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;

-- ジョブ削除
SELECT cron.unschedule('daily-analyze');
```

**制約**: pg_cronは1つのDBにしかインストールできない。他DBのジョブは`schedule_in_database`で管理。

---

### postgres_fdw（外部データラッパー）

PostgreSQL同士（またはその他データソース）をまたいでクエリするためのFDW。

```sql
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- リモートサーバー定義
CREATE SERVER remote_db
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'db2.internal', port '5432', dbname 'inventory');

-- ユーザーマッピング
CREATE USER MAPPING FOR local_user
    SERVER remote_db
    OPTIONS (user 'reader', password 'secret');

-- 外部テーブルのマッピング
CREATE FOREIGN TABLE remote_products (
    product_id  INT,
    name        TEXT,
    stock       INT
)
SERVER remote_db
OPTIONS (schema_name 'public', table_name 'products');

-- ローカルとリモートのデータを結合
SELECT o.order_id, p.name, o.quantity
FROM local_orders o
JOIN remote_products p ON o.product_id = p.product_id;
```

**FDWのユースケース**:

| ユースケース | 特性 |
|-----------|------|
| 同一DCのDB間参照 | レイテンシ低。FDWが適切 |
| 跨データセンター | レイテンシ高。論理レプリケーション推奨 |
| 分析用データ統合 | postgres_fdwまたは専用FDW（parquet_fdw等） |

**FDWエコシステム**: MySQL FDW, File FDW, S3 FDW, Redis FDW 等多数が利用可能（PostgreSQL Wiki参照）

---

### pg_partman（パーティション管理）

PostgreSQLのネイティブパーティショニングを自動管理する拡張機能。

```sql
CREATE EXTENSION IF NOT EXISTS pg_partman;

-- パーティションテーブルの設定例
CREATE TABLE events (
    id         BIGSERIAL,
    occurred   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payload    JSONB
) PARTITION BY RANGE (occurred);

-- pg_partmanでの自動管理設定
SELECT partman.create_parent(
    p_parent_table := 'public.events',
    p_control      := 'occurred',
    p_interval     := '1 month',   -- 月次パーティション
    p_premake      := 3            -- 3ヶ月先まで事前作成
);

-- 自動メンテナンスの実行（pg_cronと組み合わせ推奨）
SELECT partman.run_maintenance_proc();
```

**pg_partmanが解決する問題**:
- 月次RANGEパーティションを事前に作成しないとINSERTが失敗する
- 古いパーティションのアーカイブ・削除を自動化
- `DEFAULT`パーティションの膨張を防ぐ

---

### pg_trgm（トライグラム類似検索）

B-Treeインデックスでは難しい「任意位置からのLIKE検索」をGINインデックスで高速化。

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- GINインデックスの作成
CREATE INDEX idx_products_name_trgm
    ON products USING GIN (name gin_trgm_ops);

-- 任意位置のLIKE検索（通常のB-Treeでは先頭ワイルドカードが使えない）
SELECT * FROM products WHERE name ILIKE '%グラフ%';

-- 類似度検索（0〜1, 高いほど類似）
SELECT name, similarity(name, '検索キーワード') AS sim
FROM products
WHERE similarity(name, '検索キーワード') > 0.3
ORDER BY sim DESC;
```

**トライグラムの仕組み**:
```
文字列 "PostgreSQL" → トライグラム:
"Pos", "ost", "stg", "tgr", "gre", "reS", "eSQ", "SQL"

これらをGINインデックスに格納 → 任意位置のパターン検索が高速に
```

**注意**: B-Treeインデックスより大きい（時に5〜10倍）。I/Oとのトレードオフを考慮。

---

### hypopg（仮想インデックス）

インデックスを実際に作らずに効果をEXPLAINで確認できる拡張機能。

```sql
CREATE EXTENSION IF NOT EXISTS hypopg;

-- 仮想インデックスを作成（即時、データ量に関係なく）
SELECT * FROM hypopg_create_index(
    'CREATE INDEX ON orders(customer_id, created_at)'
);

-- EXPLAINで仮想インデックスの効果を確認
EXPLAIN SELECT * FROM orders WHERE customer_id = 123 ORDER BY created_at;
-- 仮想インデックスが使われるならコスト改善が見込める

-- 仮想インデックスの一覧確認
SELECT * FROM hypopg_list_indexes();

-- セッション終了または手動でクリア
SELECT hypopg_drop_index(indexrelid) FROM hypopg_list_indexes();
```

**活用フロー**:
```
クエリが遅い
  ↓
hypopgで候補インデックスを仮想作成
  ↓
EXPLANで効果を確認（コスト削減率を確認）
  ↓
効果があれば本番にCREATE INDEX
```

---

## 6. AI・ベクトル拡張機能

### pgvector（ベクトルデータ型・検索）

最もポピュラーなベクトル拡張。全主要クラウドプロバイダーが対応。

```sql
CREATE EXTENSION IF NOT EXISTS vector;

-- ベクトルカラムの追加（1536次元: OpenAI text-embedding-ada-002）
ALTER TABLE documents ADD COLUMN embedding VECTOR(1536);

-- IVFFlatインデックス（近似近傍検索）
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);  -- listsはデータ量の平方根程度が目安

-- コサイン類似度で最も近い文書を検索（RAGの基本）
SELECT id, content, 1 - (embedding <=> '[0.1, 0.2, ...]'::vector) AS similarity
FROM documents
ORDER BY embedding <=> '[0.1, 0.2, ...]'::vector
LIMIT 5;
```

| 距離演算子 | 用途 |
|----------|------|
| `<->` | L2距離（ユークリッド距離） |
| `<=>` | コサイン距離（テキスト埋め込みに最適） |
| `<#>` | 内積（符号反転） |

### pgai（Timescale製 AI拡張）

pgvector + pgvectorscale + pgaiをまとめてインストール。LLM連携機能を追加。

```sql
CREATE EXTENSION IF NOT EXISTS ai CASCADE;  -- pgvectorも同時インストール

-- OpenAI APIを使ってPostgres内から埋め込みを生成
SELECT ai.openai_embed('text-embedding-ada-002', 'PostgreSQL拡張機能の説明');

-- Claude Sonnetを直接呼び出し
SELECT ai.anthropic_generate(
    'claude-sonnet-4-6',
    jsonb_build_array(
        jsonb_build_object('role', 'user', 'content', 'PostgreSQLの良いところを教えて')
    )
);
```

**注意**: pgai/pgvectorscaleはまだバージョン1.0未満（積極的に開発中）。本番採用は慎重に。

### azure_ai（Azure専用）

Azure Database for PostgreSQL上でのみ利用可能なベンダー固有拡張。

```sql
CREATE EXTENSION IF NOT EXISTS azure_ai;

-- Azure OpenAI Embeddingの生成
SELECT azure_ai.create_embeddings('text-embedding-ada-002', 'テキストデータ');

-- Azure Cognitive Services（感情分析等）
SELECT azure_cognitive.analyze_sentiment('PostgreSQL is amazing!');
```

**注意**: Azure環境に依存するため、クラウド移行時のポータビリティに制約が生じる可能性。

---

## 7. 拡張機能選択ガイド

### ユースケース別推奨拡張機能

| ユースケース | 推奨拡張機能 |
|-----------|-----------|
| 必ずインストール | `pg_stat_statements` |
| 地理空間データ | `postgis` |
| クエリヒント（最終手段） | `pg_hint_plan` |
| ジョブスケジューリング | `pg_cron` |
| クロスDB参照 | `postgres_fdw` |
| 時系列パーティション管理 | `pg_partman` |
| 全文・類似文字列検索 | `pg_trgm` |
| インデックス設計の事前検証 | `hypopg` |
| ベクトル検索・RAG | `pgvector` |
| Azure統合AI | `azure_ai`（Azure環境のみ） |

### 拡張機能導入チェックリスト

- [ ] `pg_available_extension_versions`で全環境の対応バージョンを確認
- [ ] クラウドプロバイダーのドキュメントで利用可能か確認
- [ ] `VERSION '...'`を明示してインストール
- [ ] `shared_preload_libraries`が必要か確認（pg_stat_statements等）
- [ ] バックアップ/リストア後のバージョン検証手順を整備

---

## 8. 相互参照

| トピック | 参照先 |
|--------|-------|
| コネクションプーリング（PgBouncer） | [`POSTGRESQL-FUNDAMENTALS.md`](POSTGRESQL-FUNDAMENTALS.md) |
| GIN/GiSTインデックスの詳細 | [`POSTGRESQL-CORE-OBJECTS.md`](POSTGRESQL-CORE-OBJECTS.md) |
| pg_stat_statementsを使ったモニタリング | [`POSTGRESQL-REPLICATION-MONITORING.md`](POSTGRESQL-REPLICATION-MONITORING.md) |
| クエリプランの読み方（pg_hint_plan活用前提） | [`POSTGRESQL-QUERY-TUNING.md`](POSTGRESQL-QUERY-TUNING.md) |
| FDWを使ったマイクロサービスデータ共有 | [`DESIGN-POSTGRESQL-ARCHITECTURE.md`](DESIGN-POSTGRESQL-ARCHITECTURE.md) |
| セキュリティ（trusted extensionsとCREATE権限） | [`DESIGN-POSTGRESQL-SECURITY.md`](DESIGN-POSTGRESQL-SECURITY.md) |
