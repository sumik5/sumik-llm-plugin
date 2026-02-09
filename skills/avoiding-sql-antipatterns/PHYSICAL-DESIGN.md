# 物理設計のアンチパターン

データベースの物理設計における4つの代表的なアンチパターンと、それぞれの解決策を解説します。

---

## 9. ラウンディングエラー（Rounding Errors）

**問題**: `FLOAT`型を使用して通貨や正確な小数計算を行い、丸め誤差が累積する
**検出シグナル**: 金額計算の不一致、`ABS(column - value) < 0.000001`のような比較、「計算が合わない」という報告

| 項目 | 内容 |
|------|------|
| 目的 | 整数以外の数値（通貨、測定値など）を正確に格納・計算したい |
| アンチパターン | IEEE 754準拠の`FLOAT`や`DOUBLE PRECISION`を使用し、2進数形式の丸め誤差を無視する |
| 解決策 | `NUMERIC`や`DECIMAL`データ型を使用し、10進数形式で正確に格納する |
| 例外 | 科学技術計算で近似値が許容される場合、または非常に広い範囲の値（10^-308〜10^308）を扱う場合 |

**コード例:**

```sql
-- ❌ アンチパターン
CREATE TABLE Accounts (
  account_id    SERIAL PRIMARY KEY,
  hourly_rate   FLOAT  -- 59.95が正確に格納されない
);

CREATE TABLE Bugs (
  bug_id  SERIAL PRIMARY KEY,
  hours   FLOAT
);

-- 丸め誤差が顕在化
SELECT hourly_rate FROM Accounts WHERE account_id = 123;
-- 結果: 59.95（表示上）

SELECT hourly_rate * 1000000000 FROM Accounts WHERE account_id = 123;
-- 結果: 59950000762.939（実際の格納値）

-- 等価比較が失敗
SELECT * FROM Accounts WHERE hourly_rate = 59.95;
-- 結果: 一致しない

-- 集約で誤差が累積
SELECT SUM(b.hours * a.hourly_rate) AS project_cost
FROM Bugs b
INNER JOIN Accounts a ON b.assigned_to = a.account_id;
-- 結果: 誤差が累積された値

-- ✅ 解決策
CREATE TABLE Accounts (
  account_id    SERIAL PRIMARY KEY,
  hourly_rate   NUMERIC(9,2)  -- 精度9桁、小数点以下2桁
);

CREATE TABLE Bugs (
  bug_id  SERIAL PRIMARY KEY,
  hours   NUMERIC(9,2)
);

-- 正確な格納と計算
INSERT INTO Accounts (account_id, hourly_rate) VALUES (123, 59.95);

SELECT hourly_rate FROM Accounts WHERE account_id = 123;
-- 結果: 59.95（正確）

-- 等価比較が成功
SELECT * FROM Accounts WHERE hourly_rate = 59.95;
-- 結果: 一致する行を返す

-- 正確な集約
SELECT SUM(b.hours * a.hourly_rate) AS project_cost
FROM Bugs b
INNER JOIN Accounts a ON b.assigned_to = a.account_id;
-- 結果: 正確な合計
```

**`NUMERIC`/`DECIMAL`の指定方法:**

```sql
-- NUMERIC(精度, スケール)
-- 精度: 全体の桁数
-- スケール: 小数点以下の桁数

NUMERIC(9,2)   -- -9999999.99 〜 9999999.99
NUMERIC(18,4)  -- より高精度な計算
NUMERIC(10,0)  -- 整数（小数点なし）
```

**データ型選択の指針:**

| データ型 | 用途 | 精度 | 範囲 |
|---------|------|------|------|
| `NUMERIC`/`DECIMAL` | 通貨、正確な小数計算 | 完全に正確 | 実装依存（通常38桁まで） |
| `FLOAT`/`DOUBLE` | 科学技術計算、近似値 | 近似（丸め誤差あり） | 10^-308〜10^308 |
| `INTEGER` | 整数のみ | 完全に正確 | -2^31〜2^31-1 |
| `BIGINT` | 大きな整数 | 完全に正確 | -2^63〜2^63-1 |

---

## 10. サーティワンフレーバー（31 Flavors）

**問題**: `ENUM`や`CHECK`制約で値を制限し、値の追加時にDDL変更が必要になる
**検出シグナル**: 列定義に値リストが含まれる、新しいステータス追加のたびにメタデータ変更、廃止された値の削除が困難

| 項目 | 内容 |
|------|------|
| 目的 | 列の値を有効な選択肢のセットに制限したい |
| アンチパターン | `ENUM`型や`CHECK`制約で値を列定義に埋め込み、値の変更時にメタデータを修正する |
| 解決策 | 参照テーブル（ルックアップテーブル）を作成し、外部キー制約で参照する |
| 例外 | 値が完全に固定されている場合（例: 性別、曜日）、ただし将来の変更可能性を考慮すること |

**コード例:**

```sql
-- ❌ アンチパターン（ENUM）
CREATE TABLE Bugs (
  bug_id    SERIAL PRIMARY KEY,
  status    ENUM('NEW', 'IN PROGRESS', 'FIXED')  -- 値を追加するにはALTER TABLE
);

-- 値の追加にメタデータ変更が必要
ALTER TABLE Bugs MODIFY COLUMN status
  ENUM('NEW', 'IN PROGRESS', 'FIXED', 'DUPLICATE');

-- ❌ アンチパターン（CHECK制約）
CREATE TABLE Bugs (
  bug_id    SERIAL PRIMARY KEY,
  status    VARCHAR(20) CHECK (status IN ('NEW', 'IN PROGRESS', 'FIXED'))
);

-- 値の追加にメタデータ変更が必要
ALTER TABLE Bugs DROP CONSTRAINT bugs_status_check;
ALTER TABLE Bugs ADD CONSTRAINT bugs_status_check
  CHECK (status IN ('NEW', 'IN PROGRESS', 'FIXED', 'DUPLICATE'));

-- 廃止された値の扱いが困難
-- 'FIXED'を削除すると既存データがエラーになる

-- ✅ 解決策: 参照テーブル
CREATE TABLE BugStatus (
  status    VARCHAR(20) PRIMARY KEY,
  active    BOOLEAN DEFAULT TRUE  -- 廃止フラグ
);

INSERT INTO BugStatus (status) VALUES
  ('NEW'),
  ('IN PROGRESS'),
  ('FIXED');

CREATE TABLE Bugs (
  bug_id    SERIAL PRIMARY KEY,
  status    VARCHAR(20) NOT NULL DEFAULT 'NEW',
  FOREIGN KEY (status) REFERENCES BugStatus(status)
    ON UPDATE CASCADE  -- ステータス名変更時に自動更新
);

-- 値の追加はINSERT（メタデータ変更不要）
INSERT INTO BugStatus (status) VALUES ('DUPLICATE');

-- 廃止された値の扱い（既存データを保持）
UPDATE BugStatus SET active = FALSE WHERE status = 'FIXED';

-- アクティブなステータスのみ取得
SELECT b.* FROM Bugs b
INNER JOIN BugStatus s ON b.status = s.status
WHERE s.active = TRUE;
```

**参照テーブルの追加属性例:**

```sql
CREATE TABLE BugStatus (
  status          VARCHAR(20) PRIMARY KEY,
  display_order   INT,           -- 表示順序
  description     TEXT,          -- 説明
  css_class       VARCHAR(50),   -- UI用CSSクラス
  active          BOOLEAN DEFAULT TRUE,
  created_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**メリット:**
- 値の追加・削除がDML（`INSERT`/`UPDATE`）で可能
- 廃止された値を`active`フラグで管理できる
- 表示順序や説明など、追加属性を持てる
- クエリで値のリストを動的に取得できる

---

## 11. ファントムファイル（Phantom Files）

**問題**: ファイルのパスのみをデータベースに格納し、ファイル自体は別管理する
**検出シグナル**: `file_path`列のみの保存、ファイルの実体が見つからないエラー、バックアップの不整合

| 項目 | 内容 |
|------|------|
| 目的 | 画像やドキュメントなどのファイルをデータベースで管理したい |
| アンチパターン | ファイルのパスのみをデータベースに格納し、ファイル実体をファイルシステムで別管理する |
| 解決策 | 必要に応じて`BLOB`型でファイルをデータベース内に格納するか、外部ストレージサービスを使用する |
| 例外 | ファイルが非常に大きく（数GB以上）、データベースバックアップへの影響が大きい場合 |

**コード例:**

```sql
-- ❌ アンチパターン
CREATE TABLE Screenshots (
  screenshot_id   SERIAL PRIMARY KEY,
  bug_id          BIGINT UNSIGNED NOT NULL,
  image_path      VARCHAR(255),  -- '/var/images/screenshot1234.jpg'
  caption         VARCHAR(100),
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id)
);

-- 問題点:
-- 1. ファイルの削除をDBが検知できない
-- 2. ファイル名の変更で参照が壊れる
-- 3. ロールバックでファイルが孤立する
-- 4. バックアップが別々に必要
-- 5. ACLがDBとファイルシステムで二重管理

-- ✅ 解決策1: BLOB型で格納
CREATE TABLE Screenshots (
  screenshot_id   SERIAL PRIMARY KEY,
  bug_id          BIGINT UNSIGNED NOT NULL,
  image_data      BLOB,               -- ファイル本体
  image_name      VARCHAR(100),       -- 元のファイル名
  mime_type       VARCHAR(50),        -- 'image/jpeg'
  file_size       INT,
  caption         VARCHAR(100),
  created_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id)
);

-- トランザクション内で一貫性を保証
BEGIN;
INSERT INTO Screenshots (bug_id, image_data, image_name, mime_type, file_size)
VALUES (1234, ?, 'screenshot.jpg', 'image/jpeg', 45678);
COMMIT;

-- ✅ 解決策2: 外部ストレージサービス（ハイブリッド）
CREATE TABLE Screenshots (
  screenshot_id   SERIAL PRIMARY KEY,
  bug_id          BIGINT UNSIGNED NOT NULL,
  storage_key     VARCHAR(255),       -- S3キー等
  image_name      VARCHAR(100),
  mime_type       VARCHAR(50),
  file_size       INT,
  checksum        CHAR(64),           -- SHA-256ハッシュ
  caption         VARCHAR(100),
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id)
);

-- アプリケーションレイヤーでファイル整合性を管理
-- 削除時にストレージAPIも呼び出す
```

**判断基準:**

| 要因 | データベース内（BLOB） | ファイルシステム | 外部ストレージサービス |
|------|----------------------|-----------------|----------------------|
| ファイルサイズ | 〜数MB | 数GB以上 | 〜数TB |
| トランザクション整合性 | ✅ 保証される | ❌ 手動管理 | △ アプリで管理 |
| バックアップ | ✅ DB一括 | ❌ 別途必要 | ✅ サービス側 |
| アクセス制御 | ✅ DB ACL | ❌ 別管理 | △ IAM等 |
| スケーラビリティ | △ DB負荷増 | ✅ 分散可能 | ✅ 自動スケール |
| コスト | △ DB容量増 | ✅ 低コスト | △ 従量課金 |

**BLOB使用時のベストプラクティス:**
- メタデータ（ファイル名、MIME型、サイズ）を別列に保存
- チェックサム（SHA-256）で整合性を検証
- 大量のBLOBは専用テーブルに分離
- ストリーミング読み込みを使用

---

## 12. インデックスショットガン（Index Shotgun）

**問題**: パフォーマンス問題に対して推測で闇雲にインデックスを作成する
**検出シグナル**: 使われていないインデックスの大量作成、「念のため」インデックス、インデックス名が不明瞭

| 項目 | 内容 |
|------|------|
| 目的 | クエリのパフォーマンスを改善したい |
| アンチパターン | 測定せずに推測でインデックスを作成し、効果を検証しない |
| 解決策 | **MENTOR原則**（Measure, Explain, Nominate, Test, Optimize, Rebuild）に従ってインデックスを管理する |
| 例外 | 主キーと外部キーのインデックスは通常、事前に作成してよい（ただし効果を測定すること） |

**コード例:**

```sql
-- ❌ アンチパターン
-- 推測でインデックスを大量作成
CREATE INDEX idx1 ON Bugs(bug_id);           -- 主キーに重複
CREATE INDEX idx2 ON Bugs(summary);          -- 全文検索には不適
CREATE INDEX idx3 ON Bugs(date_reported);
CREATE INDEX idx4 ON Bugs(date_reported, status);  -- idx3と重複
CREATE INDEX idx5 ON Bugs(assigned_to, status, priority, date_reported);  -- 広すぎる

-- 効果を測定せず、使われないインデックスが蓄積

-- ✅ 解決策: MENTOR原則

-- 1. Measure（測定）: スロークエリログを有効化
SET GLOBAL slow_query_log = 1;
SET GLOBAL long_query_time = 1;  -- 1秒以上のクエリをログ

-- プロファイリング
SET profiling = 1;
SELECT ... FROM Bugs WHERE status = 'OPEN' ORDER BY date_reported DESC;
SHOW PROFILES;

-- 2. Explain（解析）: クエリ実行計画を取得
EXPLAIN SELECT b.*
FROM Bugs b
INNER JOIN BugsProducts bp USING (bug_id)
INNER JOIN Products p USING (product_id)
WHERE b.summary LIKE '%crash%'
  AND p.product_name = 'Open RoundFile'
ORDER BY b.date_reported DESC;

-- 実行計画で以下を確認:
-- - type: ALL（フルスキャン）は要改善
-- - key: NULL（インデックス未使用）は要改善
-- - Extra: Using filesort（ソート）はインデックスで改善可能

-- 3. Nominate（指名）: 必要なインデックスを特定
CREATE INDEX idx_bugs_status_date ON Bugs(status, date_reported);
CREATE INDEX idx_products_name ON Products(product_name);

-- 4. Test（テスト）: 効果を測定
EXPLAIN SELECT ...;  -- 再度実行計画を確認
-- type: ref（インデックス使用）に改善
-- key: idx_bugs_status_date
-- Extra: Using index（カバーリングインデックス）

-- ベンチマーク
SELECT BENCHMARK(1000, (SELECT ...));

-- 5. Optimize（最適化）: キャッシュ設定を調整
-- MySQLの場合
SET GLOBAL key_buffer_size = 256M;  -- MyISAM
SET GLOBAL innodb_buffer_pool_size = 2G;  -- InnoDB

-- 6. Rebuild（再構築）: 定期メンテナンス
ANALYZE TABLE Bugs;
OPTIMIZE TABLE Bugs;
```

**MENTOR原則の詳細:**

### 1. Measure（測定）
- スロークエリログの分析
- プロファイリングツールの使用
- 実行頻度と実行時間の両方を考慮

### 2. Explain（解析）
- `EXPLAIN`でクエリ実行計画を取得
- インデックス使用状況を確認
- ボトルネックを特定

### 3. Nominate（指名）
- カバーリングインデックスの検討
- 複合インデックスの列順序を最適化
- 自動チューニングツール（DB2 Design Advisor、SQL Server Database Engine Tuning Advisor等）の活用

### 4. Test（テスト）
- インデックス作成後に再測定
- 改善率を定量化（「38%改善」など）
- 副作用（書き込みの遅延）を確認

### 5. Optimize（最適化）
- キャッシュサイズの調整
- インデックスの事前ロード

### 6. Rebuild（再構築）
- 定期的なインデックス再構築
- 統計情報の更新

**カバーリングインデックス:**

```sql
-- クエリに必要な列をすべて含むインデックス
CREATE INDEX idx_bug_covering ON Bugs
  (status, bug_id, date_reported, reported_by, summary);

-- クエリがインデックスのみで完結
SELECT bug_id, date_reported, summary
FROM Bugs
WHERE status = 'OPEN';
-- テーブルアクセス不要！
```

**インデックスのメンテナンスコマンド:**

| データベース | コマンド |
|------------|---------|
| MySQL | `ANALYZE TABLE`, `OPTIMIZE TABLE` |
| PostgreSQL | `VACUUM`, `ANALYZE` |
| SQL Server | `ALTER INDEX ... REORGANIZE`, `ALTER INDEX ... REBUILD` |
| Oracle | `ALTER INDEX ... REBUILD` |
| IBM DB2 | `REORG INDEX` |
| SQLite | `VACUUM` |

**インデックス作成の指針:**

```sql
-- ✅ 作成すべきインデックス
-- 1. 主キー（自動作成される場合が多い）
-- 2. 外部キー（参照整合性チェックで使用）
-- 3. WHERE句で頻繁に使う列
-- 4. JOIN条件の列
-- 5. ORDER BY / GROUP BY の列

-- ❌ 避けるべきインデックス
-- 1. カーディナリティが低い列（例: 性別）
-- 2. 頻繁に更新される列
-- 3. 使われないインデックス（定期的に監視）
-- 4. 主キーと完全に重複するインデックス
```

**使われていないインデックスの検出:**

```sql
-- MySQL 5.6以降
SELECT * FROM sys.schema_unused_indexes;

-- PostgreSQL
SELECT schemaname, tablename, indexname
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND indexrelname NOT LIKE 'pg_toast%';
```

---

## まとめ

物理設計のアンチパターンを避けるための原則:

1. **適切なデータ型を選択**: 用途に応じて`NUMERIC`、`FLOAT`を使い分ける
2. **参照テーブルで値を管理**: `ENUM`や`CHECK`制約ではなくテーブルで
3. **ファイル管理戦略を明確化**: トランザクション整合性とスケーラビリティのトレードオフを理解
4. **MENTOR原則でインデックス管理**: 推測ではなく測定に基づいて最適化
5. **定期的なメンテナンス**: インデックス再構築と統計情報更新を忘れずに
