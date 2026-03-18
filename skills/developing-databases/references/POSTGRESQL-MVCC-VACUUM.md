# MVCC・VACUUM・ANALYZE リファレンス

PostgreSQLにおけるマルチバージョン同時実行制御（MVCC）の仕組み、テーブル膨張の原因と対処、VACUUMプロセスの種別と設定、ANALYZE による統計情報管理、および関連する保守タスクをまとめる。

---

## 1. MVCC（Multi-Version Concurrency Control）概要

PostgreSQLのMVCCは「読み取りが書き込みをブロックせず、書き込みが読み取りをブロックしない」という原則を実現する。この目標は**行バージョニング**（Row Versioning）によって達成される。各トランザクションはデータベースの一貫したスナップショットを保持し、選択した分離レベルに応じた整合性が保証される。

### PostgreSQL の MVCC が他DBと異なる2点

| 特徴 | 説明 |
|------|------|
| **行内バージョン管理** | バージョン情報は行自体の隠しカラム（xmin/xmax）に格納。SQL Serverのような別途バージョンテーブルは存在しない |
| **更新は新バージョン作成** | INSERT・UPDATE は常に新しい行バージョンを作成。DELETE は行をマーク（即削除しない）。不要になった古い行（dead tuple）はVACUUMが後から回収する |

---

## 2. 行バージョン（xmin / xmax）

すべての行に対して、どのトランザクションが作成・削除したかを記録する隠しカラムが存在する。

| カラム | 役割 |
|--------|------|
| **xmin** | 行を作成したトランザクションID（XID）。INSERT時に設定される |
| **xmax** | 行を削除・更新したXID。削除・更新されるまで 0（ゼロ）のまま |

```sql
-- xmin/xmax を明示的に確認する
SELECT xmin, xmax, id, user_data
FROM mvcc_example;
```

### 行バージョンの状態遷移

```
-- (1) INSERT 直後
INSERT INTO mvcc_example (user_data) VALUES ('Hello!');
xmin=30, xmax=0   → コミット済み、XID > 30 のトランザクションに可視

-- (2) DELETE 後（dead tuple）
DELETE FROM mvcc_example WHERE id=1;
xmin=30, xmax=75  → xmax が設定された。dead tuple。後でVACUUMが回収

-- (3) UPDATE 後（新旧バージョンが共存）
UPDATE mvcc_example SET user_data = 'Hello World!';
xmin=30, xmax=75  → 旧バージョン（dead tuple）
xmin=75, xmax=0   → 新バージョン（現在の値）
```

> **注意**: 値が変わらない UPDATE（`SET col = col`）でも新バージョンが作成される。PostgreSQLは変更有無をチェックしない。

### トランザクションIDの割り当てタイミング

XIDは `BEGIN` の発行時ではなく、**最初のSQL文が実行されたとき**に割り当てられる。マルチステートメントトランザクション内では、先に実行したSQL変更結果が後続のSQLから参照可能。

---

## 3. Row Visibility（行の可視性）判定ルール

あるトランザクションが行を「見える」と判定するには、以下の条件を満たす必要がある。

| カラム | 可視性条件 |
|--------|----------|
| **xmin** | 現在のXIDより小さく、かつコミット済みであり、かつ現在トランザクション開始時に実行中でなかった |
| **xmax** | ゼロ、または現在のXIDより大きい（つまり「未来の」XIDが削除した = 現時点では可視） |

この仕組みにより、各トランザクションは開始時点のデータの「スナップショット」を持ち、他の並行トランザクションの変更に影響を受けない。

---

## 4. Transaction ID Space（XID 循環問題）

PostgreSQLのXIDは**符号付き32ビット整数の循環空間**で管理される。

- 利用可能なXID総数: 約 4.2 億
- 任意のXIDから見て、「過去」のXID: 約 2.1 億
- 任意のXIDから見て、「未来」のXID: 約 2.1 億

### Wraparound 問題

XIDが再利用される段階になると、コミット済みの古いトランザクションが「未来のXID」として認識され、データが突然見えなくなる**XIDラップアラウンド**が発生する。

これを防ぐのがVACUUMの「Freeze（凍結）」処理。

---

## 5. VACUUM プロセス

MVCCの副作用として発生する2つの問題——dead tuples と XID空間の消費——を管理するのがVACUUMの役割。

### 5.1 VACUUM の実行

```sql
-- 特定テーブルのVACUUM（dead tuple除去 + 行の凍結）
VACUUM bluebox.rental;

-- データベース全体をVACUUM（通常は不要）
VACUUM;

-- VERBOSE オプションで進捗確認
VACUUM VERBOSE bluebox.rental;
```

### 5.2 通常VACUUM vs VACUUM FULL

| 種別 | 動作 | ロック | 推奨度 |
|------|------|--------|--------|
| **VACUUM** | Dead tupleを除去し、空き領域として内部再利用 | 読み書き可能（低影響） | ✅ 通常使用 |
| **VACUUM FULL** | Dead tuple除去 + 生きたタプルを詰め直しページを縮小 | 排他ロック（読み書き不可） | ⚠️ 緊急時のみ |

> **VACUUM FULL は原則使用しない。** テーブルが完全にロックされ、本番環境では重大な影響を与える。通常のVACUUMで定期的にdead tupleを除去するほうが推奨される。

### 5.3 Dead Tuples と Table Bloat

削除・更新でxmaxが設定された行は物理的にはページ上に残る。これが**dead tuple（デッドタプル）**で、スペースを占有し続けると**table bloat（テーブル膨張）**が発生する。

```sql
-- dead tupleの割合を確認
SELECT
    n_live_tup AS live_tuples,
    n_dead_tup AS dead_tuples,
    round((n_dead_tup::numeric / NULLIF(n_live_tup, 0)) * 100, 2) AS percent_dead
FROM pg_stat_user_tables
WHERE relname = 'rental';

-- 詳細情報（pgstattuple拡張が必要）
CREATE EXTENSION IF NOT EXISTS pgstattuple;
SELECT * FROM pgstattuple('bluebox.rental');
```

> `pgstattuple` はテーブル全体をスキャンするため、大きなテーブルでは負荷に注意。

---

## 6. Freezing Live Tuples（凍結）

VACUUMの第2の役割は、XID空間の維持のために古い行バージョンを「凍結」すること。

### 凍結の仕組み

- VACUUMがページをスキャンし、xmin が十分に古い行を発見
- その行を「凍結済み」としてマーク。以降のすべてのトランザクションから可視
- 凍結済みの行はVACUUM時にスキップされるため処理時間を短縮
- ページ上のすべての行が凍結済みの場合、ページ全体が凍結済みとしてマーク → さらにスキャン削減

### 関連パラメータ

| パラメータ | デフォルト | 説明 |
|-----------|------------|------|
| `vacuum_freeze_min_age` | 50000000 (5千万) | 凍結対象となるxminの最小XID差 |
| `vacuum_freeze_table_age` | 150000000 (1.5億) | テーブル全体の積極的な凍結をトリガーするXID差 |

---

## 7. autovacuum の設定と最適化

通常はautovacuumがバックグラウンドで自動的にVACUUMを実行する。

### デフォルトのトリガー条件

```
VACUUM開始 = 更新/削除行数 > autovacuum_vacuum_threshold + autovacuum_vacuum_scale_factor × テーブル行数
デフォルト: 100行 + 20% × テーブル行数
```

大規模テーブル（例: 1000万行）ではデフォルト設定では 200万行変更まで待つことになり、dead tuple が大量に蓄積される。

### テーブル個別の設定（大規模・更新頻度の高いテーブル向け）

```sql
-- 更新頻度が高いテーブルのVACUUMトリガーを5%に設定
ALTER TABLE rental SET (autovacuum_vacuum_scale_factor = 0.05);

-- コスト制限を緩和してVACUUMをより積極的に実行
ALTER TABLE rental SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_vacuum_cost_delay = 2
);
```

### クラスター全体のautovacuum設定（postgresql.conf）

```
# 同時実行するautovacuumワーカー数（デフォルト: 3）
autovacuum_max_workers = 5

# VACUUMのトリガー閾値（行数ベース）
autovacuum_vacuum_threshold = 50

# VACUUMのトリガー閾値（割合）
autovacuum_vacuum_scale_factor = 0.02

# autovacuumコスト制限（I/O負荷調整）
autovacuum_vacuum_cost_delay = 2ms
autovacuum_vacuum_cost_limit = 400
```

> **autovacuum を無効化してはいけない。** パフォーマンス問題の診断中にVACUUMが頻繁に実行されているのを見て無効化したくなることがあるが、無効化は問題を悪化させる。

---

## 8. ANALYZE と autoanalyze

`ANALYZE` はテーブルの統計情報を更新し、クエリプランナーが適切なプランを選択できるようにする。

### ANALYZE の役割

PostgreSQLのコストベースクエリプランナーは、各テーブルの統計情報（行数、値の分布等）に基づいてプランを決定する。統計が古いと不適切なプランが選ばれ、クエリが遅くなる。

### autoanalyze のデフォルトトリガー

```
ANALYZE開始 = 更新/削除行数 > autovacuum_analyze_threshold + autovacuum_analyze_scale_factor × テーブル行数
デフォルト: 50行 + 10% × テーブル行数
```

### 手動ANALYZE

```sql
-- 特定テーブルの統計情報を手動更新
ANALYZE bluebox.rental;

-- テーブルとインデックスの統計を同時更新
VACUUM ANALYZE bluebox.rental;
```

### autoanalyzeのトリガー調整

```sql
-- ANALYZEのトリガーを5%に設定
ALTER TABLE rental SET (autovacuum_analyze_scale_factor = 0.05);
```

### 統計情報が古いサイン

1. クエリのパフォーマンス低下（特定クエリのみ突然遅くなる）
2. `EXPLAIN ANALYZE` の推定行数（Rows）と実際の行数（actual rows）が大きくかけ離れている

---

## 9. pg_stat_user_tables による VACUUM/ANALYZE 監視

```sql
-- VACUUMとANALYZEの最終実行時刻を確認
SELECT
    schemaname,
    relname,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE relname = 'rental';

-- dead tupleの状況を一覧表示
SELECT
    schemaname,
    relname,
    n_live_tup,
    n_dead_tup,
    round((n_dead_tup::numeric / NULLIF(n_live_tup, 0)) * 100, 2) AS pct_dead,
    last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

---

## 10. 設定と保守タスク

### 10.1 maintenance_work_mem

VACUUMを含むメンテナンスタスクが使用できるメモリの上限。

```
# postgresql.conf
maintenance_work_mem = 256MB  # デフォルト 64MB から引き上げを検討
```

| バージョン | 動作 |
|-----------|------|
| PostgreSQL 16以下 | VACUUMのメモリ使用は1GBに暗黙的に制限 |
| PostgreSQL 17以上 | 上記の制限が撤廃 |

大規模テーブルで頻繁なVACUUMが必要な場合は 256MB〜1GB に設定。ただし、autovacuumワーカー数 × maintenance_work_mem がメモリ総量を超えないよう注意。

### 10.2 REINDEX（インデックスの再構築）

インデックスも時間とともに肥大化する。定期的な再構築が必要になることがある。

```sql
-- テーブルの全インデックスを並行再構築（ロック最小化）
REINDEX TABLE CONCURRENTLY bluebox.rental;

-- 特定インデックスのみ再構築
REINDEX INDEX CONCURRENTLY rental_rental_period_idx;
```

> `CONCURRENTLY` オプションにより、排他ロックを取らずに再構築可能。ただし処理時間は長くなる。

### 10.3 Fill Factor（フィルファクター）

データページをどの割合まで満杯にするかを制御する。

| 対象 | デフォルト | 推奨シナリオ |
|------|-----------|------------|
| インデックス | 90% | タイムスタンプ等単調増加カラムは 95-100% に |
| テーブル | 100% | 更新頻度が高いテーブルは 70-90% に下げてHOTを有効化 |

```sql
-- インデックスのfill factor設定
CREATE INDEX rental_inventory_id_idx
    ON rental (inventory_id)
    WITH (fillfactor = 75);

ALTER INDEX rental_inventory_id_idx SET (fillfactor = 95);
REINDEX INDEX rental_inventory_id_idx;

-- テーブルのfill factor設定
CREATE TABLE bluebox.inventory (
    inventory_id serial4 NOT NULL,
    film_id int4 NOT NULL,
    store_id int4 NOT NULL,
    last_update timestamptz DEFAULT now() NOT NULL
) WITH (fillfactor = 95);

ALTER TABLE bluebox.inventory SET (fillfactor = 75);
```

### 10.4 Heap-Only Tuples（HOT）

更新時に同一ページ内に空きがある場合、インデックスを変更せずに新しい行バージョンを同一ページに書き込む最適化。

**HOTが発生する条件:**
1. 更新されるカラムがインデックス付きカラムでない
2. 同一データページに空き領域がある（fill factor を下げることで確保）

```sql
-- HOT更新の発生状況を監視
SELECT
    schemaname,
    relname,
    n_tup_upd,       -- 通常の更新行数
    n_tup_hot_upd    -- HOT更新行数
FROM pg_stat_user_tables
ORDER BY n_tup_upd DESC;
```

`n_tup_hot_upd` が `n_tup_upd` に対して少ない場合、fill factor を 75-80% に下げることでHOTが増加する可能性がある。

---

## まとめ

| 概念 | 要点 |
|------|------|
| MVCC | xmin/xmax で行バージョン管理。読み取りと書き込みを非ブロッキングで実現 |
| Dead Tuple | 削除・更新された旧行バージョン。物理的には残り続け、VACUUMで回収 |
| Table Bloat | Dead tupleの蓄積によるテーブルの肥大化。定期的なVACUUMで防止 |
| VACUUM | Dead tuple除去 + XID凍結。通常VACUUMを使い、VACUUM FULLは緊急時のみ |
| autovacuum | 自動VACUUM。scale_factorで閾値調整。絶対に無効化しない |
| XID Wraparound | 32ビット循環空間の問題。凍結（Freeze）で防止 |
| ANALYZE | 統計情報更新。プランナーの行数推定精度を維持 |
| HOT | インデックス変更なしの同一ページ内更新最適化。fill factor調整で有効化 |
| maintenance_work_mem | VACUUMのメモリ。デフォルト64MBから256MB〜1GBへの引き上げを推奨 |

---

## 関連リファレンス

- [INTERNALS-TRANSACTIONS-RECOVERY.md](INTERNALS-TRANSACTIONS-RECOVERY.md) — MVCC理論・ACID・ARIES・分離レベルの詳細
- [POSTGRESQL-QUERY-TUNING.md](POSTGRESQL-QUERY-TUNING.md) — EXPLAIN ANALYZE・インデックス戦略
- [POSTGRESQL-EXTENSIONS.md](POSTGRESQL-EXTENSIONS.md) — pg_stat_statements・pgstattuple などの拡張機能
- [POSTGRESQL-REPLICATION-MONITORING.md](POSTGRESQL-REPLICATION-MONITORING.md) — pg_stat_user_tablesを活用した監視設計
