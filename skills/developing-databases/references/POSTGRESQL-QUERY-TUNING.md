# PostgreSQL クエリチューニングとインデックス戦略

クエリチューニングは科学であると同時に「芸術」でもある。どのデータベースでも通用する原則はあるが、PostgreSQL固有の仕組み（コストベースプランナー、ヒープベースストレージ）を理解することで、はじめて効果的なチューニングが可能になる。

> **関連リファレンス**: インデックス種別（B-Tree/GIN/GiST等）の概要については `references/POSTGRESQL-CORE-OBJECTS.md` を参照。本ファイルはインデックスの**実践的チューニング戦略**に特化。

---

## 1. EXPLAIN / EXPLAIN ANALYZE の使い方

### 1.1 基本構文

```sql
-- 推定実行計画（クエリは実行しない）
EXPLAIN SELECT * FROM film WHERE release_date > '2023-10-01'::date;

-- 実際の実行計画（クエリを実際に実行する）
EXPLAIN ANALYZE SELECT * FROM film WHERE release_date > '2023-10-01'::date;

-- バッファ情報を追加（最もよく使う組み合わせ）
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM film WHERE release_date > '2023-10-01'::date;
```

> ⚠️ `EXPLAIN ANALYZE` は実際にクエリを実行する。DML文（INSERT/UPDATE/DELETE）の場合、データが変更されるため注意が必要。テスト環境では `BEGIN; ... ROLLBACK;` で囲む。

### 1.2 EXPLAINオプション一覧

| オプション | デフォルト | 説明 |
|-----------|-----------|------|
| `ANALYZE` | off | 実際に実行して実測値を表示 |
| `COSTS` | **on** | 各ノードの推定コストを表示（デフォルト有効）|
| `BUFFERS` | off | バッファ使用量を表示（ANALYZE必須） |
| `TIMING` | **on** | 各ノードの実測時間を表示（デフォルト有効）|
| `VERBOSE` | off | 追加情報（カラム一覧、テーブルスキーマ等）を表示 |
| `SETTINGS` | off | デフォルトから変更された設定を表示 |
| `WAL` | off | WAL書き込み量を表示 |
| `FORMAT` | text | 出力形式（text / json / xml / yaml） |

```sql
-- 複数オプションを指定する場合は括弧必須
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT * FROM film JOIN film_cast USING (film_id);

-- ANALYZEのみの場合は括弧不要（後方互換性）
EXPLAIN ANALYZE SELECT * FROM film;
```

### 1.3 実行計画の読み方

```
QUERY PLAN
----------------------------------------------------------
Seq Scan on film (cost=0.00..962.55 rows=15 width=778)
(actual time=13.870..27.588 rows=63 loops=1)
  Filter: (release_date > '2023-10-01'::date)
  Rows Removed by Filter: 7939

Planning Time: 0.206 ms
Execution Time: 27.649 ms
```

| 表示値 | 意味 |
|--------|------|
| `cost=0.00..962.55` | 推定コスト（開始コスト..合計コスト）。任意単位で相対比較用 |
| `rows=15` | 推定行数 |
| `width=778` | 推定の1行あたりバイト数 |
| `actual time=13.870..27.588` | 実測時間 ms（最初の行を返すまで..最後の行を返すまで） |
| `rows=63` | 実際の行数（推定15 vs 実際63 → 統計情報が古い可能性） |
| `loops=1` | このノードが実行された回数（Nested Loopの内側は複数回） |
| `Planning Time` | プラン生成にかかった時間 |
| `Execution Time` | クエリ全体の実行時間 |

---

## 2. BUFFERS：バッファ使用量の分析

### 2.1 バッファの種類

```
Buffers: shared hit=862
```

| バッファ種別 | 意味 | 速度 |
|------------|------|------|
| `shared hit` | 共有バッファ（メモリ）にあったページ | 最速 |
| `shared read` | ディスクから共有バッファに読み込んだページ | 遅い |
| `shared written` | バッファから書き出したページ | - |
| `shared dirtied` | このクエリで汚したページ | - |
| `temp read/written` | ソート等のwork_memオーバー時のディスク使用 | 最遅 |

**ポイント**: `shared hit` が多いほど高速。`shared read` が多い場合、インデックスや `shared_buffers` の見直しが必要。

### 2.2 バッファ値は累積値

**重要**: 各ノードのバッファ値は、そのノード以下のすべての子ノードの**累積合計**です。

```
Nested Loop (cost=0.84..2664.14 rows=445)
  Buffers: shared hit=8790 read=1445   ← 全ノードの合計
  -> Nested Loop (cost=0.42..2425.16)
       Buffers: shared hit=1127 read=48   ← 子ノードの合計
       -> Seq Scan on film
            Buffers: shared hit=862      ← film単独
       -> Index Scan on film_cast_pk
            Buffers: shared hit=265 read=48  ← film_cast単独
  -> Index Scan on person_pkey
       Buffers: shared hit=7663 read=1397   ← person単独
```

計算確認: `862 + 265 = 1127` ✅、`1127 + 7663 = 8790` ✅

---

## 3. プライマリノード型

### 3.1 スキャンノード

| ノード | 説明 | 選択条件 |
|--------|------|---------|
| **Seq Scan** | テーブル全体をページ順に読む | インデックスがない、または取得行が多い場合 |
| **Index Scan** | インデックスで位置特定 → ヒープからデータ取得 | 少数行を取得 |
| **Index Only Scan** | インデックスのみで完結（ヒープアクセス不要）| カバリングインデックス使用時。最も効率的 |
| **Bitmap Index Scan + Bitmap Heap Scan** | インデックスでビットマップ生成 → ヒープを効率的に読む | 中程度の行数、または複数インデックスのAND/OR |

#### Sequential Scan を見て慌てない

Seq Scanはインデックスがなくても、**あっても**選択される。以下の場合はSeg ScanがIndex Scanより速いことがある:

- テーブルが小さい（数百ページ程度）
- WHERE句にマッチする行が全体の大きな割合を占める
- ヒープ順にページを読む方が、インデックス経由より低コスト

PostgreSQLはコストベースで自動判断するため、「Seq Scanが出た = 問題」ではない。

### 3.2 ジョインノード

| ノード | アルゴリズム | 適した状況 |
|--------|------------|----------|
| **Nested Loop** | 外側の各行に対して内側をスキャン | 外側テーブルが小さい、内側にインデックスある |
| **Hash Join** | 内側テーブルでハッシュ表作成 → 外側でプローブ | 等値結合、内側テーブルがメモリに収まる |
| **Merge Join** | 両側をソートしてマージ | 両側がソート済み（インデックス順等）、大規模テーブル |

```
-- Nested Loop の例
Nested Loop (cost=0.84..2664.14)
  -> Seq Scan on film            ← 外側（小テーブル）
  -> Index Scan on film_cast_pk  ← 内側（インデックスあり）

-- Nested Loopのパフォーマンス改善ポイント:
-- 内側テーブルの結合キーにインデックスを追加する
```

### 3.3 その他の重要ノード

| ノード | 説明 |
|--------|------|
| `Sort` | ORDER BY / GROUP BY のソート。work_mem超過でExternal Sortへ |
| `Aggregate` | SUM/COUNT/AVG等の集計 |
| `Group` | GROUP BY の出力生成（前にSortが入ることが多い） |
| `Window Aggregate` | ウィンドウ関数 |
| `Append` | UNION ALL等で複数サブプランを結合 |
| `CTE Scan` | WITH句（共通テーブル式）の結果をスキャン |
| `Materialize` | 結果を一時的にメモリに保存して再利用 |

---

## 4. work_mem と External Sort Disk 問題

### 4.1 work_mem の役割

`work_mem` は各クエリノードが Sort / Hash / Aggregate 操作に使えるメモリの上限。デフォルトは `4MB`。

```sql
-- 現在の設定確認
SHOW work_mem;

-- セッションレベルで変更（特定の重いクエリ向け）
SET work_mem = '28MB';

-- ロールレベルで設定（夜間バッチ等）
ALTER ROLE reporting_user SET work_mem = '128MB';
```

⚠️ グローバル変更は慎重に。高負荷時に多数の並行クエリが同時にwork_memを消費するとOOMになる可能性がある。

### 4.2 External Sort Disk の検出

work_mem が不足すると `external merge Disk` が表示される:

```
Sort (cost=567486.06..569599.99)
  Sort Key: (sum(payment.amount)) DESC
  Sort Method: external merge Disk: 3552kB  ← ディスク使用
  ...
  -> Sort ...
       Sort Method: external merge Disk: 13896kB
       Buffers: temp read=28699 written=28787  ← tempバッファ使用
```

**解決策**: `work_mem` を `current_work_mem + external_disk_usage` 以上に設定。

```sql
-- work_memを増やしてSortをメモリ内で完結させる
SET work_mem = '28MB';
-- → Sort Method: quicksort Memory: 27108kB  （ディスク不使用）
```

---

## 5. インデックス戦略

### 5.1 B-Tree Deduplication（PostgreSQL 13以降）

B-Treeインデックスは通常、同じ値でも行ごとにエントリが作られる。**Deduplication**により同一値を1エントリにまとめ、インデックスサイズを最大3倍縮小できる。

```sql
-- デフォルト（Deduplication有効）
CREATE INDEX rental_inventory_id_idx ON rental USING btree (inventory_id);

-- Deduplication無効
CREATE INDEX rental_inventory_id_idx_nondedup ON rental
USING btree (inventory_id) WITH (deduplicate_items = OFF);

-- サイズ比較
SELECT indexname, pg_size_pretty(pg_relation_size(pg.oid)) AS index_size
FROM pg_indexes pi
JOIN pg_class pg ON pi.indexname = pg.relname
WHERE pi.tablename = 'rental';
```

> ⚠️ PostgreSQL 12以下からアップグレードした場合、既存インデックスはDeduplicationされない。`REINDEX INDEX index_name;` で再構築が必要。

### 5.2 Functional Indexes（式インデックス）

通常のB-Treeインデックスは関数を適用した値でのフィルタには使われない。式インデックスで対応する。

```sql
-- ❌ 通常インデックスはこのクエリで使われない
CREATE INDEX rental_period_upper ON rental USING btree (rental_period);
SELECT * FROM rental WHERE upper(rental_period) IS NULL;

-- ✅ 式インデックスで対応
CREATE INDEX rental_period_upper ON rental
USING btree (upper(rental_period));

-- 効果: 415MBのParallel Scan (990ms) → 100KBのBitmap Index Scan (1.2ms)
```

### 5.3 Partial Indexes（部分インデックス）

`WHERE`句で条件を絞った**部分インデックス**は、サイズが大幅に小さくなり、対象クエリには特に高速。

```sql
-- ❌ 全行を対象とする式インデックス（86MB）
CREATE INDEX rental_upper ON rental
USING btree (upper(rental_period));

-- ✅ 部分インデックス（NULL=未返却のみ対象、88KB = 1/1000のサイズ）
CREATE INDEX rental_upper_null ON rental
USING btree (upper(rental_period))
WHERE upper(rental_period) IS NULL;  -- ← WHERE句で絞り込み

-- このインデックスが使われるクエリ例
SELECT count(*) FROM rental WHERE upper(rental_period) IS NULL;
```

| 指標 | 全体インデックス | 部分インデックス |
|------|--------------|--------------|
| インデックスサイズ | 86MB | 88KB |
| バッファ読み取り | 13ページ | 11ページ |
| スキャン方法 | Bitmap Index Scan | Index Only Scan |
| 実行時間 | 1.2ms | 1.3ms |

### 5.4 Composite Indexes（複合インデックス）の列順序

複数カラムでフィルタする場合、複合インデックスが有効。**列の順序が重要**。

```sql
-- store_id と rental_period の複合部分インデックス
CREATE INDEX rental_store_upper_null_idx
ON rental USING btree (store_id, upper(rental_period))
WHERE upper(rental_period) IS NULL;

-- このインデックスを活用するクエリ
SELECT DISTINCT film_id FROM inventory i
JOIN rental r USING (inventory_id)
WHERE i.store_id = 112
AND upper(rental_period) IS NULL;

-- 効果: 2つの別々インデックスのBitmapAnd (7.8ms) → 単一インデックス (3.1ms) → 50%削減
```

**列順序の原則**:
1. **等値フィルタ（=）カラムを先頭に** 置く
2. **範囲フィルタ（>, <, BETWEEN）カラムは後ろ** に置く
3. 選択性（Cardinality）が高いカラムを先頭に置くと効率的

⚠️ 複合インデックスは列数が多いほどページ分割（Page Split）が増加しやすく、書き込み負荷が増える。本当に必要か慎重に判断する。

### 5.5 Covering Indexes（カバリングインデックス / INCLUDE句）

Index Only Scanを実現するため、インデックスキー以外のカラムを `INCLUDE` で付属させる。

```sql
-- 通常のIndex Scanはヒープアクセスが必要
CREATE INDEX film_id_idx ON film USING btree (film_id);

-- カバリングインデックス: INCLUDE内のカラムはインデックスに格納（検索には使えない）
CREATE INDEX film_id_incl ON film
USING btree (film_id)
INCLUDE (title, popularity, rating, release_date);

-- 上記インデックスで以下のクエリがIndex Only Scanになる
SELECT film_id, title, popularity, rating, release_date
FROM film WHERE film_id = 100;
```

```
-> Index Only Scan using film_id_incl on film
   Index Cond: (film_id = i.film_id)
   Heap Fetches: 0   ← ヒープアクセスゼロ！
```

**効果**: Index Scanのクエリが40%高速化（ヒープアクセスの完全排除）

**注意点**:
- `INCLUDE` 内のカラムは検索条件（WHERE句）には使えない
- インデックスサイズが増大する（トレードオフ）
- 同じカラムセットを常に取得する「特定クエリ専用」インデックスとして設計する

---

## 6. Auto Explain（自動実行計画ロギング）

### 6.1 有効化

```ini
# postgresql.conf
shared_preload_libraries = 'auto_explain'
```

クラスターの再起動が必要。

### 6.2 主要設定

```ini
# postgresql.conf または ALTER SYSTEM SET
auto_explain.log_min_duration = 1000    # 1秒以上かかったクエリをログ
auto_explain.sample_rate = 0.1          # 該当クエリの10%をサンプリング
auto_explain.log_analyze = on           # 実測値も含める（EXPLAIN ANALYZE相当）
auto_explain.log_buffers = on           # バッファ使用量も含める
auto_explain.log_format = json          # JSON形式（ツールで解析しやすい）
```

| 設定 | 推奨値 | 注意 |
|------|--------|------|
| `log_min_duration` | 500ms〜5000ms | 低すぎると全クエリのオーバーヘッドになる |
| `sample_rate` | 0.01〜1.0 | スループットが高い場合は低い値に |
| `log_analyze` | on | クエリ実行コストが増えるが必須の情報 |
| `log_timing` | 状況次第 | タイミング収集自体にオーバーヘッドあり |

### 6.3 セッションレベルで一時的に有効化

```sql
-- 現在のセッションのみ有効化（再起動不要）
LOAD 'auto_explain';
SET auto_explain.log_min_duration = 0;  -- すべてのクエリをログ（テスト用）
SET auto_explain.log_analyze = on;

-- 確認したいクエリを実行
SELECT * FROM film WHERE film_id = 1;
-- → PostgreSQLログに実行計画が出力される
```

---

## 7. 実行計画ビジュアライザ

テキスト形式の実行計画は複雑なクエリでは読みにくい。以下のツールを活用する:

| ツール | 特徴 | 用途 |
|--------|------|------|
| **[explain.depesz.com](https://explain.depesz.com)** | 無料・オンライン、テキスト形式でコスト可視化 | 日常的なプラン分析 |
| **[explain.dalibo.com](https://explain.dalibo.com)** | OSSビジュアルツール、ノード関係図 | 複雑なプランの視覚的把握 |
| **[pgMustard.com](https://pgmustard.com)** | 有料、MLベースの改善提案 | 継続的な最適化 |
| **Redgate Monitor** | auto_explainと連携、クエリプラン履歴 | 本番監視環境 |

---

## 8. チューニングワークフロー

```
1. 遅いクエリを特定
   └─ pg_stat_statements（Ch15参照）または auto_explain のログを確認

2. EXPLAIN (ANALYZE, BUFFERS) を実行
   └─ 高コスト・高バッファノードを特定

3. ボトルネックを分析
   ├─ Seq Scan → インデックス追加を検討
   ├─ External Sort Disk → work_mem を増やす
   ├─ 推定行数 ≠ 実際行数 → ANALYZE を実行して統計更新
   └─ Index Scan → カバリングインデックスでIndex Only Scanに

4. 変更を適用してEXPLAINで再確認
   └─ 改善を定量的に確認（バッファ数、実行時間）

5. 定常監視
   └─ auto_explain + pg_stat_statements で継続監視
```

---

## まとめ

| 問題 | 解決策 |
|------|--------|
| Seq Scan（インデックス不在） | 適切なインデックスを追加 |
| External Sort Disk | `work_mem` をセッションまたはロールレベルで増加 |
| Index Scan → ヒープアクセスが多い | `INCLUDE`句でカバリングインデックスを作成 |
| インデックスが大きすぎる | 部分インデックス（`WHERE`句付き）を使用 |
| 関数フィルタでインデックス未使用 | 式インデックス（Functional Index）を作成 |
| 推定行数が実際と大きく乖離 | `ANALYZE`で統計情報を更新 |
| インデックスが重複・多すぎる | `pg_stat_user_indexes` で未使用インデックスを確認して削除 |
