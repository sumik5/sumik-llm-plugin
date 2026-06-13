# PostgreSQL トランザクションとデータモデリング

PostgreSQLのACID準拠、分離レベル、ロック制御、およびSlowly Changing Dimensions (SCD) を活用したデータモデリングガイド。

---

## 1. ACID準拠

ACID（Atomicity, Consistency, Isolation, Durability）は、信頼性の高いトランザクションデータベースシステムの基盤となる4つの原則。

### 1.1 Atomicity（原子性）

- **定義**: トランザクション内の複数のステートメントは、すべて成功するか、すべて失敗する（部分的な実行は許可されない）
- **トランザクションブロックの重要性**: 単一ステートメントは自動的に`BEGIN`/`COMMIT`で囲まれる。複数ステートメントの場合は明示的なトランザクションブロックが必須

**単一ステートメントトランザクション（暗黙的）:**

```sql
-- 自動的に BEGIN/COMMIT で囲まれる
INSERT INTO product_brand (id, label, description)
VALUES (10001, 'Wrangler Jeans', 'Good Mornings Make for Better Days');
```

**複数ステートメントトランザクション（明示的）:**

```sql
BEGIN;
INSERT INTO product_brand (id, label, description)
    VALUES (10001, 'Wrangler Jeans', 'Good Mornings Make for Better Days');
INSERT INTO product (id, product_category_id, product_brand_id, label, shortdescription)
    VALUES (10000, 1, 10001, 'Jeans by Wrangler', 'Best pants for a great day');
INSERT INTO product_variant (id, product_id, attributes, upc)
    VALUES (10001, 10000, '{"color": "blue", "size": "32/36", "fit": "Boot Leg"}', '1234567890');
COMMIT;
```

### 1.2 Consistency（一貫性）

- **定義**: トランザクションはデータベースを一つの有効な状態から別の有効な状態へ遷移させる
- **CHECK制約による保証**: テーブル制約を使用してビジネスルールを強制

```sql
-- inventory テーブルの制約例
ALTER TABLE product_variant_inventory
ADD CONSTRAINT product_variant_inventory_qty_check CHECK (qty >= 0);
```

この制約により、在庫がマイナスになる更新は自動的に失敗する。

### 1.3 Isolation（分離性）

- **定義**: 複数のトランザクションが並列実行されても、互いに干渉せず、独立して実行されているかのように動作する
- **中間状態の不可視性**: あるトランザクションの中間状態は、コミットされるまで他のトランザクションから見えない

分離性の詳細は次セクションで解説。

### 1.4 Durability（永続性）

- **定義**: コミットされたトランザクションは、システム障害が発生しても永続化される
- **WAL（Write-Ahead Log）**: PostgreSQLは、ユーザーへの結果通知前にトランザクションをWALとして永続ストレージに書き込む

---

## 2. 分離レベル

PostgreSQLはSQL標準の4つの分離レベルのうち3つをサポート（Read Uncommittedは非サポート）。

### 2.1 分離レベル比較テーブル

| 分離レベル | Dirty Read | Non-repeatable Read | Phantom Read | Lost Update | Serialization Failure | スナップショット取得タイミング |
|-----------|-----------|---------------------|--------------|-------------|----------------------|--------------------------|
| **Read Committed** (デフォルト) | × | ○（発生可能） | ○（発生可能） | ○（発生可能） | なし | **ステートメントごと** |
| **Repeatable Read** | × | × | × | × | ○（発生可能） | **トランザクション開始時** |
| **Serializable** | × | × | × | × | ○（発生可能、より厳密） | **トランザクション開始時** |

- **○**: 問題が発生しうる
- **×**: 問題は発生しない

### 2.2 Read Committed（デフォルト）

**特徴:**
- 各ステートメントは最新のコミット済みデータを参照
- 他のトランザクションの影響を即座に受ける
- Lost Update問題のリスクあり

**2つのシナリオ:**

**シナリオ1: 未コミット変更は不可視**

| Session 1 | Session 2 | 説明 |
|-----------|-----------|------|
| Qty := 50 | - | 初期値 |
| BEGIN; | - | トランザクション開始 |
| Qty: 50 | Qty: 50 | 両セッションで同じ値 |
| Qty := qty - 1 | - | Session 1で変更（未コミット） |
| Qty: 49 | Qty: 50 | Session 2には見えない |
| COMMIT; | - | コミット |
| Qty: 49 | Qty: 49 | 変更が可視化 |

**シナリオ2: Lost Update問題**

| Session 1 | Session 2 | 説明 |
|-----------|-----------|------|
| Qty: 50 | - | 初期値 |
| BEGIN; | - | Session 1トランザクション開始 |
| Qty: 50 | Qty: 50 | 両セッションで同じ値 |
| - | Qty := qty - 1 | Session 2が単一ステートメントで変更 |
| Qty: 49 | Qty: 49 | Session 2の変更が即座に反映 |
| Qty := qty - 1 | - | Session 1も変更（49→48） |
| Qty: 48 | Qty: 49 | Session 1の未コミット変更 |
| COMMIT; | - | Session 1コミット |
| Qty: 48 | Qty: 48 | **Session 2の変更が失われた** |

**使用判断:**
- シンプルなトランザクション向け
- 同じSELECTを複数回実行しない場合
- Lost Update問題への対策が必要（ロック使用など）

### 2.3 Repeatable Read

**特徴:**
- トランザクション開始時のスナップショットを使用
- トランザクション内で同じSELECTは常に同じ結果を返す
- 並行トランザクションが同じデータを変更すると**Serialization Failure**が発生

**シナリオ1: トランザクション内でのスナップショット一貫性**

| Session 1 | Session 2 | 説明 |
|-----------|-----------|------|
| Qty: 50 | - | 初期値 |
| BEGIN; | - | Session 1トランザクション開始 |
| SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; | - | 分離レベル設定 |
| Qty: 50 | Qty: 50 | 両セッションで同じ値 |
| - | Qty := qty - 1 | Session 2が単一ステートメントで変更 |
| Qty: 50 | Qty: 49 | **Session 1は変更を見ない（スナップショット維持）** |
| COMMIT; | - | コミット |
| Qty: 49 | Qty: 49 | コミット後に変更が見える |

**シナリオ2: Serialization Failureによる競合検出**

| Session 1 | Session 2 | 説明 |
|-----------|-----------|------|
| BEGIN; | - | Session 1トランザクション開始 |
| SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; | - | 分離レベル設定 |
| Qty: 50 | Qty: 50 | 両セッションで同じ値 |
| - | Qty := qty - 1 | Session 2が単一ステートメントで変更 |
| Qty: 50 | Qty: 49 | Session 1はスナップショットを維持 |
| Qty := qty - 1 | - | Session 1が変更を試みる |
| **ERROR** | - | **Serialization Failure発生** |

**エラーメッセージ:**

```
ERROR: could not serialize access due to concurrent update
```

**使用判断:**
- 同じSELECTを複数回実行するトランザクション
- データの一貫性が重要な場合
- **リトライロジックの実装が必須**

### 2.4 Serializable

**特徴:**
- 最も厳密な分離レベル
- すべての並行トランザクションがシリアル（順次）実行された場合と同じ結果を保証
- Repeatable Readと同様のSerialization Failureが発生するが、より広範な競合検出

**パフォーマンスコスト:**
- 内部情報を管理してシリアライゼーション競合を評価
- Read Committed/Repeatable Readより高コスト
- **リトライロジックの実装が必須**

**使用判断:**
- 最も厳密なデータ一貫性が必要な場合
- 複雑なビジネスロジックで競合を完全に排除したい場合

### 2.5 分離レベルの設定

```sql
-- データベースレベル
ALTER DATABASE mydatabase SET DEFAULT_TRANSACTION_ISOLATION TO 'REPEATABLE READ';

-- セッションレベル
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- トランザクションレベル（BEGIN後）
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- トランザクション処理
COMMIT;
```

---

## 3. ロック制御

### 3.1 SELECT FOR UPDATE vs SELECT FOR NO KEY UPDATE

**比較テーブル:**

| 特徴 | SELECT FOR UPDATE | SELECT FOR NO KEY UPDATE（推奨） |
|------|-------------------|----------------------------------|
| 行全体のロック | ○ | × |
| PKを除く列の更新ブロック | ○ | ○ |
| PKの更新ブロック | ○ | ○ |
| 親テーブルロック時の子テーブルINSERTブロック | **○（ブロックする）** | **×（ブロックしない）** |
| 行の削除ブロック | ○ | ○ |

**シナリオ1: SELECT FOR UPDATE（子テーブルINSERTをブロック）**

```sql
-- Session 1: 親テーブルを FOR UPDATE でロック
BEGIN;
SELECT * FROM product_brand WHERE id = 10000 FOR UPDATE;
```

```sql
-- Session 2: 子テーブルへのINSERTが**ブロックされる**
INSERT INTO product
  (product_category_id, product_brand_id, label, shortdescription)
VALUES (1, 10000, 'New product', 'Short description');
-- ブロックされる（Session 1のCOMMIT待ち）
```

```sql
-- Session 1: 親テーブルの更新とコミット
UPDATE product_brand SET description = 'New Description' WHERE id = 10000;
COMMIT;
-- Session 2のINSERTがここで実行される
```

**シナリオ2: SELECT FOR NO KEY UPDATE（子テーブルINSERTを許可）**

```sql
-- Session 1: 親テーブルを FOR NO KEY UPDATE でロック
BEGIN;
SELECT * FROM product_brand WHERE id = 10000 FOR NO KEY UPDATE;
```

```sql
-- Session 2: 子テーブルへのINSERTが**即座に成功**
INSERT INTO product
  (product_category_id, product_brand_id, label, shortdescription)
VALUES (1, 10000, 'New product', 'Short description');
-- ブロックされない（即座に実行）
```

```sql
-- Session 1: 親テーブルの更新とコミット
UPDATE product_brand SET description = 'New Description' WHERE id = 10000;
COMMIT;
```

**推奨事項:**
- PKの更新や親レコードの削除を計画していない限り、**SELECT FOR NO KEY UPDATE を使用**
- 不必要なロックを避け、並行性を向上

### 3.2 Advisory Locks

**用途:**
- アプリケーション間の協調制御
- データベース内にロック情報を保存（行・テーブル・列のロックではない）

**例: 長時間実行レポートの重複起動防止**

```sql
-- アドバイザリロックを取得
SELECT pg_advisory_lock(12345);

-- レポート生成処理
-- ...

-- ロックを解放
SELECT pg_advisory_unlock(12345);
```

---

## 4. トランザクション制御

### 4.1 単一ステートメント vs トランザクションブロック

**単一ステートメント（暗黙的トランザクション）:**

```sql
-- 以下は自動的に BEGIN/COMMIT で囲まれる
INSERT INTO sales_transaction_line
  (sales_transaction_id, product_variant_id, qty, price_at_sale)
VALUES ('east_5316', 10001, 5, 19.99);
```

**問題例: トランザクションブロックなし**

```sql
-- ステートメント1: 成功
INSERT INTO sales_transaction_line
  (sales_transaction_id, product_variant_id, qty, price_at_sale)
VALUES ('east_5316', 10001, 5, 19.99);

-- ステートメント2: 失敗（在庫不足）
UPDATE product_variant_inventory SET qty = qty - 5 WHERE product_variant_id = 10001;
-- ERROR: check constraint violation

-- 結果: sales_transaction_line に行が挿入されたまま（不整合状態）
```

**トランザクションブロック使用:**

```sql
BEGIN;
INSERT INTO sales_transaction_line
    (sales_transaction_id, product_variant_id, qty, price_at_sale)
    VALUES ('east_5316', 10001, 5, 19.99);
UPDATE product_variant_inventory SET qty = qty - 5 WHERE product_variant_id = 10001;
COMMIT;

-- エラー発生時はトランザクション全体がロールバックされる
```

### 4.2 ROLLBACK と EXCEPTION

**ストアドプロシージャ内での明示的なROLLBACK:**

```sql
CREATE OR REPLACE PROCEDURE add_to_sales_transaction (
  p_st_id TEXT,
  p_pv_id INTEGER,
  p_qty INTEGER,
  p_price NUMERIC)
AS
$$
BEGIN
    INSERT INTO sales_transaction_line
        (sales_transaction_id, product_variant_id, qty, price_at_sale)
        VALUES (p_st_id, p_pv_id, p_qty, p_price);
    UPDATE product_variant_inventory
        SET qty = qty - p_qty
        WHERE product_variant_id = p_pv_id;
    EXCEPTION
        WHEN check_violation THEN
            ROLLBACK;
            RAISE NOTICE 'Check constraint failure';
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE NOTICE 'Transaction failed for unknown reasons';
END $$ LANGUAGE PLPGSQL;
```

### 4.3 SAVEPOINT とサブトランザクション

**用途:**
- 長く複雑なトランザクション内で部分的なロールバックを実現
- 例: 1000行のオーダーのうち900行を成功させ、100行の失敗を記録

```sql
BEGIN;
-- ステートメント群1
SAVEPOINT sp1;
-- ステートメント群2（失敗の可能性）
ROLLBACK TO SAVEPOINT sp1; -- sp1までロールバック（ステートメント群1は維持）
-- ステートメント群3
COMMIT;
```

---

## 5. Slowly Changing Dimensions (SCD)

### 5.1 SCD Types 概要

Slowly Changing Dimensions（SCD）は、時間経過に伴って変化する参照データをモデル化する手法。

| SCD Type | 説明 | Pro | Con |
|---------|------|-----|-----|
| **Type 1** | 上書き（履歴なし） | シンプル | 履歴データなし |
| **Type 2** | 新規行追加（start_date/end_date） | シンプル | ルックアップが高コスト。start/end整合性管理が困難 |
| **Type 3** | 前回値カラム追加 | シンプル | 1つ前のバージョンのみ追跡 |
| **Type 4** | 履歴テーブル分離 | シンプル | "特定日の価格"のクエリが困難 |
| **Type 5** | Type 1 + Type 4 | 現在値への高速アクセス | 2テーブルへの挿入/更新 |
| **Type 6** | Type 1 + 2 + 3統合（**推奨**） | 現在値への高速ルックアップ。将来変更のステージング可能 | start/end整合性管理（PostgreSQLで解決可能） |

### 5.2 SCD Type 6 の PostgreSQL 実装

**なぜType 6か:**
- すべてのデータを1テーブルに統合
- 現在値への高速アクセス（`current`フラグ）
- 将来の変更をステージング可能（eコマースの価格変更予約など）
- PostgreSQLの`DATERANGE`型と`btree_gist`拡張で管理課題を解決

#### 5.2.1 DATERANGEデータ型

**構文:**
- `[start, end)`: start含む、end含まず（推奨）
- `(start, end)`: 両方含まず
- `[start, end]`: 両方含む

**例:**

```sql
-- 2025年6月1日から2025年7月1日の前日まで有効
'[2025-06-01, 2025-07-01)'
```

#### 5.2.2 テーブル定義

```sql
CREATE EXTENSION btree_gist; -- 拡張を有効化

CREATE TABLE product_variant_price (
    id INTEGER PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    product_variant_id INTEGER NOT NULL
          REFERENCES product_variant (id) ON DELETE CASCADE,
    price NUMERIC(10, 2) NOT NULL CHECK (price > 0),
    -- DATERANGEで有効期間を定義（開始日含む、終了日含まず）
    validity DATERANGE NOT NULL,
    current BOOLEAN NOT NULL DEFAULT false,
    -- 排他制約: 同じproduct_variant_idで重複する有効期間を禁止
    EXCLUDE USING GIST (product_variant_id WITH =, validity WITH &&)
);
```

#### 5.2.3 問題1: 範囲境界の管理

**DATERANGE構文:**
- `[2025-06-01, 2025-07-01)`: 6月1日含む、7月1日含まず
- 別々のstart_date/end_dateカラムと異なり、境界の包含/除外が明確

#### 5.2.4 問題2: 特定日の価格検索

**包含演算子（@>）:**

```sql
-- 2025年6月18日の価格を取得
SELECT price FROM product_variant_price
WHERE validity @> '2025-06-18'::date
AND product_variant_id = 12345;
```

#### 5.2.5 問題3: 範囲の重複防止

**EXCLUDE制約:**

```sql
EXCLUDE USING GIST (product_variant_id WITH =, validity WITH &&)
```

**重複挿入の試行:**

```sql
-- 既存データ: product_id=12346, validity='[2025-07-01, 2025-07-31)'
INSERT INTO product_variant_price
  (product_id, price, validity, current)
VALUES (12346, 100.00, '[2025-07-01, 2025-07-02]', false);

-- エラー:
-- ERROR: conflicting key value violates exclusion constraint
-- DETAIL: Key (product_id, validity)=(12346, [2025-07-01,2025-07-03))
--         conflicts with existing key (product_id, validity)=(12346, [2025-07-01,2025-07-31)).
```

#### 5.2.6 データ例

**Product Variant Price Table:**

| product_variant_id | validity | price | current |
|-------------------|----------|-------|---------|
| 1 | [2024-01-01, 2024-07-01) | 95.00 | False |
| 1 | [2024-07-01, 2025-01-01) | 97.50 | False |
| 1 | [2025-01-01, 2025-07-01) | 105.00 | True |
| 1 | [2025-07-01, 2026-01-01) | 109.00 | False |

**クエリ例:**

```sql
-- 現在の価格を取得
SELECT price FROM product_variant_price
WHERE product_variant_id = 1 AND current = true;

-- 2024年8月1日時点の価格を取得
SELECT price FROM product_variant_price
WHERE product_variant_id = 1
AND validity @> '2024-08-01'::date;
```

---

## まとめ

- **ACID準拠**: PostgreSQLは原子性、一貫性、分離性、永続性を完全にサポート
- **分離レベル**: Read Committed（デフォルト、Lost Update注意）、Repeatable Read（スナップショット一貫性、リトライ必須）、Serializable（最厳密、リトライ必須）
- **ロック**: SELECT FOR NO KEY UPDATEを優先使用して不必要なブロックを回避
- **SCD Type 6**: PostgreSQLの`DATERANGE`型と`btree_gist`拡張で、時系列データの管理を効率化
