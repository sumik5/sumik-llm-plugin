# PostgreSQL 関数とストアドプロシージャ

PostgreSQL関数・ストアドプロシージャの基本構造、PL/pgSQL、PL/Python3uの実践ガイド。

---

## 1. 関数 vs プロシージャ

### 1.1 比較テーブル

| 特徴 | 関数（Function） | プロシージャ（Procedure） |
|------|-----------------|-------------------------|
| **SQL内での呼出し** | ○（SELECT文内で使用可能） | ×（CALLコマンドが必要） |
| **戻り値** | スカラー値、レコード、テーブル | OUT/INOUTパラメータのみ |
| **トランザクション制御** | ×（呼び出し元のトランザクションに参加） | ○（COMMIT/ROLLBACK/SAVEPOINT使用可能） |
| **オーバーロード** | ○（同名で異なるパラメータリスト可能） | × |
| **呼出し方法** | SELECT内、またはSELECT f_name(...) | CALL p_name(...) |

---

## 2. SQL関数・プロシージャの基本構造

### 2.1 基本構造テンプレート

**関数:**

```sql
CREATE FUNCTION f_function_name (
    IN p_parameter1 <DATATYPE> DEFAULT <value>,
    IN p_parameter2 <DATATYPE>,
    OUT p_result <DATATYPE>
)
IMMUTABLE/STABLE/VOLATILE  -- Volatility分類（任意、デフォルトはVOLATILE）
RETURNS <DATATYPE>          -- 戻り値の型
AS $$
DECLARE
    v_variable1 <DATATYPE>;  -- 変数宣言
BEGIN
    -- SQL/PL/pgSQL statements
    RETURN <value>;
END
$$ LANGUAGE SQL/PLPGSQL;
```

**プロシージャ:**

```sql
CREATE PROCEDURE p_procedure_name (
    IN p_parameter1 <DATATYPE>,
    INOUT p_parameter2 <DATATYPE>
)
AS $$
DECLARE
    v_variable1 <DATATYPE>;
BEGIN
    -- SQL/PL/pgSQL statements
    COMMIT;  -- トランザクション制御可能
END
$$ LANGUAGE SQL/PLPGSQL;
```

### 2.2 パラメータの種類

| パラメータ種類 | 説明 | 使用可能箇所 |
|--------------|------|-------------|
| **IN** | 入力専用（デフォルト） | 関数、プロシージャ |
| **OUT** | 出力専用 | 関数、プロシージャ |
| **INOUT** | 入出力両用 | 関数、プロシージャ |
| **VARIADIC** | 可変長引数（配列として受け取る） | 関数、プロシージャ |

### 2.3 命名規則（推奨）

| 要素 | プレフィックス | 例 |
|------|---------------|-----|
| 関数名 | `f_` | `f_calculate_total` |
| プロシージャ名 | `p_` | `p_update_inventory` |
| パラメータ名 | `p_` | `p_product_id` |
| 変数名 | `v_` | `v_total_price` |

---

## 3. Volatility（揮発性分類）

### 3.1 分類比較テーブル

| 分類 | DB参照（SELECT） | DB変更（INSERT/UPDATE/DELETE） | スナップショット | 最適化 | デフォルト |
|------|-----------------|------------------------------|---------------|--------|----------|
| **IMMUTABLE** | × | × | 不要（DBアクセスなし） | 最大 | × |
| **STABLE** | ○ | × | 呼び出し元と同じ | 中 | × |
| **VOLATILE** | ○ | ○ | **毎回新規取得** | なし | ○ |

### 3.2 各分類の詳細

**IMMUTABLE（不変）:**
- 同じ入力に対して常に同じ結果を返す
- データベースにアクセスしない
- 例: 数学関数、文字列操作

```sql
CREATE FUNCTION f_add_numbers(p_a INTEGER, p_b INTEGER)
RETURNS INTEGER
IMMUTABLE
AS $$
BEGIN
    RETURN p_a + p_b;
END
$$ LANGUAGE PLPGSQL;
```

**STABLE（安定）:**
- データベースをクエリするが、変更しない
- 同じトランザクション内では同じ結果を返す
- 例: 現在の設定値を参照する関数

```sql
CREATE FUNCTION f_get_tax_rate(p_region TEXT)
RETURNS NUMERIC
STABLE
AS $$
BEGIN
    RETURN (SELECT rate FROM tax_config WHERE region = p_region);
END
$$ LANGUAGE PLPGSQL;
```

**VOLATILE（揮発性、デフォルト）:**
- データベースを変更する可能性がある
- 呼び出しごとに異なる結果を返す可能性がある
- 例: INSERT/UPDATE/DELETE実行、乱数生成、時刻取得

```sql
CREATE FUNCTION f_get_current_time()
RETURNS TIMESTAMP
VOLATILE  -- 明示的に指定（省略可能）
AS $$
BEGIN
    RETURN NOW();
END
$$ LANGUAGE PLPGSQL;
```

### 3.3 パフォーマンスへの影響

- **IMMUTABLE/STABLE**: 呼び出し元のクエリのスナップショットを使用（効率的）
- **VOLATILE**: 関数呼び出しごとに新しいスナップショットを取得（コスト高）

**推奨事項:** 関数の動作に応じて正しいVolatility分類を設定することでパフォーマンスを最適化。

---

## 4. PL/pgSQL

PostgreSQLのネイティブ手続き型言語。SQL中心の操作、フロー制御、トランザクション管理に強い。

### 4.1 制御構造

#### 4.1.1 IF/THEN/ELSE

```sql
DO $$
DECLARE
    v_x INTEGER := 4;
BEGIN
    IF v_x = 1 OR v_x = 2 THEN
        RAISE NOTICE 'The value is either 1 or 2';
    ELSIF v_x = 3 THEN
        RAISE NOTICE 'The value is 3';
    ELSE
        RAISE NOTICE 'The value is neither 1, 2, nor 3';
    END IF;
END $$;
```

#### 4.1.2 CASE

**Simple CASE（単純CASE）:**

```sql
DO $$
DECLARE
    v_x INTEGER := 4;
BEGIN
    CASE v_x
        WHEN 1, 2 THEN
            RAISE NOTICE 'The value is either 1 or 2';
        WHEN 3 THEN
            RAISE NOTICE 'The value is 3';
        ELSE
            RAISE NOTICE 'The value is neither 1, 2, nor 3';
    END CASE;
END $$;
```

**Searched CASE（検索CASE）:**

```sql
DO $$
DECLARE
    v_x INTEGER := 4;
BEGIN
    CASE
        WHEN v_x IN (1, 2) THEN
            RAISE NOTICE 'The value is either 1 or 2';
        WHEN v_x = 3 THEN
            RAISE NOTICE 'The value is 3';
        ELSE
            RAISE NOTICE 'The value is neither 1, 2, nor 3';
    END CASE;
END $$;
```

#### 4.1.3 LOOP

**無条件ループ（EXITで終了）:**

```sql
DO $$
DECLARE
    v_max INTEGER := 4;
    v_ctr INTEGER := 1;
BEGIN
    LOOP
        RAISE NOTICE 'Iteration # %', v_ctr;
        IF v_ctr >= v_max THEN
            EXIT;
        ELSE
            v_ctr := v_ctr + 1;
        END IF;
    END LOOP;
END $$;
```

#### 4.1.4 WHILE LOOP

```sql
DO $$
DECLARE
    v_max INTEGER := 4;
    v_ctr INTEGER := 1;
BEGIN
    WHILE v_ctr <= v_max LOOP
        RAISE NOTICE 'Iteration # %', v_ctr;
        v_ctr := v_ctr + 1;
    END LOOP;
END $$;
```

#### 4.1.5 FOR LOOP

**整数範囲:**

```sql
DO $$
DECLARE
    v_max INTEGER := 4;
BEGIN
    FOR v_ctr IN 1..v_max LOOP
        RAISE NOTICE 'Iteration # %', v_ctr;
    END LOOP;
END $$;
```

**配列イテレーション（FOREACH）:**

```sql
DO $$
DECLARE
    v_array INTEGER[] := '{1,2,3,4}';
    v_i INTEGER;
BEGIN
    FOREACH v_i IN ARRAY v_array LOOP
        RAISE NOTICE 'Iteration # %', v_i;
    END LOOP;
END $$;
```

**レコードセットイテレーション:**

```sql
DO $$
DECLARE
    v_product_record RECORD;
BEGIN
    FOR v_product_record IN
        (SELECT id, label FROM product WHERE price > 100)
    LOOP
        RAISE NOTICE 'Product ID: %, Label: %', v_product_record.id, v_product_record.label;
    END LOOP;
END $$;
```

### 4.2 診断とエラー処理

#### 4.2.1 FOUND

最後に実行したクエリが結果を返したかどうかを示すブール変数。

```sql
DO $$
BEGIN
    PERFORM * FROM product WHERE id = 999;
    IF FOUND THEN
        RAISE NOTICE 'Product found';
    ELSE
        RAISE NOTICE 'Product not found';
    END IF;
END $$;
```

#### 4.2.2 GET DIAGNOSTICS

現在の実行状態に関する情報を取得。

```sql
DO $$
DECLARE
    v_row_count INTEGER;
    v_call_stack TEXT;
BEGIN
    PERFORM * FROM product;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    GET DIAGNOSTICS v_call_stack = PG_CONTEXT;
    RAISE NOTICE 'Query successful. Found % rows', v_row_count;
    RAISE NOTICE 'Call stack: %', v_call_stack;
END $$;
```

#### 4.2.3 EXCEPTION / GET STACKED DIAGNOSTICS

エラー発生時の詳細情報を取得。

```sql
DO $$
DECLARE
    v_MESSAGE_TEXT TEXT;
    v_CONSTRAINT_NAME TEXT;
    v_TABLE_NAME TEXT;
BEGIN
    UPDATE product_variant_price SET price = -0.99 WHERE id = 1;
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'Violated check constraint';
            GET STACKED DIAGNOSTICS
                v_CONSTRAINT_NAME = CONSTRAINT_NAME,
                v_MESSAGE_TEXT = MESSAGE_TEXT,
                v_TABLE_NAME = TABLE_NAME;
            RAISE NOTICE 'CONSTRAINT_NAME: %', v_CONSTRAINT_NAME;
            RAISE NOTICE 'MESSAGE_TEXT: %', v_MESSAGE_TEXT;
            RAISE NOTICE 'TABLE_NAME: %', v_TABLE_NAME;
END $$;
```

#### 4.2.4 カスタム例外（RAISE EXCEPTION）

```sql
DO $$
BEGIN
    UPDATE product_variant_price SET price = 0.01 WHERE id = 1;
    RAISE check_violation USING MESSAGE = 'Price too low';
END $$;
```

### 4.3 トリガー

#### 4.3.1 データトリガー（行レベル/文レベル）

**トリガー関数の特徴:**
- `RETURNS TRIGGER`
- `NEW`レコード（INSERT/UPDATE時）
- `OLD`レコード（UPDATE/DELETE時）
- `TG_NAME`（トリガー名）
- `TG_OP`（INSERT/UPDATE/DELETE/TRUNCATE）
- `TG_WHEN`（BEFORE/AFTER/INSTEAD OF）
- `TG_LEVEL`（ROW/STATEMENT）

**例: 在庫変更履歴の自動記録**

```sql
-- トリガー関数定義
CREATE OR REPLACE FUNCTION tr_inventory_last_update()
RETURNS TRIGGER
AS $$
BEGIN
    NEW.last_update_timestamp = NOW();
    NEW.last_update_user = CURRENT_USER;
    NEW.prior_value = TO_JSONB(OLD);
    RETURN NEW;
END
$$ LANGUAGE PLPGSQL;

-- トリガーをテーブルにアタッチ
CREATE OR REPLACE TRIGGER tr_track_last_update_inventory
    BEFORE INSERT OR UPDATE
    ON product_variant_inventory
FOR EACH ROW EXECUTE FUNCTION tr_inventory_last_update();
```

### 4.4 トランザクションとサブトランザクション

#### 4.4.1 基本トランザクション制御（プロシージャのみ）

```sql
CREATE OR REPLACE PROCEDURE p_update_inventory(p_product_id INTEGER, p_qty INTEGER)
AS $$
BEGIN
    BEGIN;  -- トランザクション開始
    UPDATE product_variant_inventory SET qty = qty - p_qty
    WHERE product_variant_id = p_product_id;
    COMMIT;  -- トランザクションコミット
    EXCEPTION WHEN OTHERS THEN
        ROLLBACK;  -- エラー時ロールバック
        RAISE NOTICE 'Update failed';
END
$$ LANGUAGE PLPGSQL;
```

#### 4.4.2 サブトランザクション

**用途:** 一部の失敗を許容し、成功した部分のみをコミット。

```sql
CREATE OR REPLACE FUNCTION sf_add_lines_to_sales_order (
    p_sales_transaction_id TEXT,
    p_line_info NUMERIC[][][])
RETURNS INTEGER[][]
AS $$
DECLARE
    v_products_ordered INTEGER[][];
    v_pv_id INTEGER;
    v_qty INTEGER;
    v_price NUMERIC;
BEGIN
    FOR v_i IN 1..ARRAY_LENGTH(p_line_info, 1) LOOP
        BEGIN  -- サブトランザクション開始
            v_pv_id := p_line_info[v_i][1];
            v_qty := p_line_info[v_i][2];
            v_price := p_line_info[v_i][3];

            INSERT INTO sales_transaction_line
                (sales_transaction_id, product_variant_id, qty, price_at_sale)
            VALUES (p_sales_transaction_id, v_pv_id, v_qty, v_price);

            UPDATE product_variant_inventory SET qty = qty - v_qty
            WHERE product_variant_id = v_pv_id;

            RAISE NOTICE 'Success with order % for % units', v_pv_id, v_qty;
            v_products_ordered := v_products_ordered || ARRAY[[v_pv_id, v_qty]];

            EXCEPTION WHEN check_violation THEN
                -- このサブトランザクションのみロールバック
                RAISE NOTICE 'Failure with % for % units. Out of inventory', v_pv_id, v_qty;
        END;
    END LOOP;
    RETURN v_products_ordered;
END $$ LANGUAGE PLPGSQL;
```

### 4.5 pg_background拡張（自律トランザクション相当）

**用途:** 呼び出し元のトランザクションコンテキストから独立したプロセスを実行。

**ユースケース:** ロールバックされても記録を残したい（失敗した在庫リクエストのログなど）。

```sql
CREATE EXTENSION pg_background;

-- 在庫リクエストテーブル
CREATE TABLE inventory_request (
    time TIMESTAMP,
    product_variant_id INTEGER,
    sales_transaction_id TEXT,
    qty INTEGER
);

-- バックグラウンドで実行されるプロシージャ
CREATE OR REPLACE PROCEDURE record_inventory_request (
    p_product_variant_id INTEGER,
    p_sales_transaction_id TEXT,
    p_qty INTEGER)
AS $$
BEGIN
    INSERT INTO inventory_request
        (time, product_variant_id, sales_transaction_id, qty)
    VALUES (CLOCK_TIMESTAMP(), p_product_variant_id, p_sales_transaction_id, p_qty);
END
$$ LANGUAGE PLPGSQL;

-- メイン関数内でpg_backgroundを使用
CREATE OR REPLACE FUNCTION sf_add_lines_with_log (
    p_sales_transaction_id TEXT,
    p_line_info NUMERIC[][][])
RETURNS INTEGER[][]
AS $$
DECLARE
    v_background_command TEXT;
    v_bg_worker_pid INTEGER;
BEGIN
    FOR v_i IN 1..ARRAY_LENGTH(p_line_info, 1) LOOP
        -- バックグラウンドでログ記録
        v_background_command := format(
            'CALL record_inventory_request(%L, %L, %L)',
            p_line_info[v_i][1],
            p_sales_transaction_id,
            p_line_info[v_i][2]
        );
        v_bg_worker_pid := pg_background_launch(v_background_command);
        PERFORM pg_background_result(v_bg_worker_pid);

        -- メイントランザクション処理
        -- ...
    END LOOP;
END $$ LANGUAGE PLPGSQL;
```

### 4.6 plpgsql_check リンター

**用途:** PL/pgSQL コードの静的解析（未使用変数、構文エラー検出）。

```sql
-- リンター実行
SELECT plpgsql_check_function('f_function_name', fatal_errors := false);
```

**検出例:**
- 未使用変数
- カラム数とVALUESの不一致
- 型の不整合

---

## 5. PL/Python3u

### 5.1 データ型マッピング

| PostgreSQL型 | Python型 |
|-------------|----------|
| Boolean | bool |
| Smallint, Integer, Bigint, OID | int |
| Real, Double | float |
| Numeric | Decimal |
| Bytea | bytes |
| Char, Text, Varchar | str |
| Array | list |
| NULL | None |
| Composite (Record) | dict (Mapping) |

### 5.2 plpyモジュール

#### 5.2.1 plpy.execute

**用途:** クエリを直接実行（小規模結果セット向け）。

```sql
CREATE OR REPLACE PROCEDURE p_ensure_description_uppercase()
AS $$
import plpy
rows = plpy.execute("SELECT id, description FROM product_category")
for row in rows:
    desc = row['description']
    if desc and not desc[0].isupper():
        new_desc = desc[0].upper() + desc[1:]
        update_sql = (
            "UPDATE product_category "
            "SET description = '%s' WHERE id = %d"
        ) % (new_desc.replace("'", "''"), row['id'])
        plpy.execute(update_sql)
$$ LANGUAGE plpython3u;
```

#### 5.2.2 plpy.prepare（プリペアドステートメント）

**用途:** 実行プランを再利用（パフォーマンス向上）。

```sql
CREATE OR REPLACE FUNCTION f_get_product_price(p_product_id INTEGER)
RETURNS NUMERIC
AS $$
import plpy
plan = SD.get("product_price_plan")
if plan is None:
    plan = plpy.prepare("SELECT price FROM product WHERE id = $1", ["INTEGER"])
    SD["product_price_plan"] = plan
result = plpy.execute(plan, [p_product_id])
return result[0]['price'] if result else None
$$ LANGUAGE plpython3u;
```

#### 5.2.3 plpy.cursor（大規模結果セット）

**用途:** メモリ効率的なイテレーション。

```sql
CREATE OR REPLACE PROCEDURE p_ensure_description_uppercase_cursor()
AS $$
import plpy
cursor = plpy.cursor("SELECT id, description FROM product_category")
while True:
    rows = cursor.fetch(5)  # 5行ずつフェッチ
    if not rows:
        break
    for row in rows:
        desc = row['description']
        if desc and not desc[0].isupper():
            new_desc = desc[0].upper() + desc[1:]
            update_sql = (
                "UPDATE product_category "
                "SET description = '%s' WHERE id = %d"
            ) % (new_desc.replace("'", "''"), row['id'])
            plpy.execute(update_sql)
$$ LANGUAGE plpython3u;
```

### 5.3 例外処理（spiexceptions）

```sql
CREATE OR REPLACE FUNCTION f_insert_product_category(
    p_id INTEGER,
    p_label TEXT,
    p_description TEXT)
RETURNS TEXT
AS $$
import plpy
from plpy import spiexceptions
try:
    sql = (
        "INSERT INTO product_category (id, label, description) "
        "VALUES (%d, '%s', '%s')"
    ) % (p_id, p_label.replace("'", "''"), p_description.replace("'", "''"))
    plpy.execute(sql)
    return "Insert successful"
except spiexceptions.UniqueViolation as e:
    return "Unique constraint violation: " + str(e)
except plpy.SPIError as e:
    return "Error, SQLSTATE %s" % e.sqlstate
$$ LANGUAGE plpython3u;
```

### 5.4 トランザクション制御

| PL/pgSQL | PL/Python |
|----------|-----------|
| BEGIN | 不要（ロールバック後に自動開始） |
| COMMIT | `plpy.commit()` |
| ROLLBACK | `plpy.rollback()` |
| SAVEPOINT | `plpy.subtransaction()` |

**サブトランザクション例:**

```sql
CREATE OR REPLACE PROCEDURE p_update_with_subtransaction()
AS $$
import plpy
with plpy.subtransaction():
    plpy.execute("UPDATE product SET price = price * 1.1 WHERE id = 1")
    # サブトランザクション内の処理
$$ LANGUAGE plpython3u;
```

### 5.5 RAISEレベル対応テーブル

| PL/pgSQL RAISE | PL/Python |
|---------------|-----------|
| DEBUG | `plpy.debug(msg)` |
| LOG | `plpy.log(msg)` |
| INFO | `plpy.info(msg)` |
| NOTICE | `plpy.notice(msg)` |
| WARNING | `plpy.warning(msg)` |
| ERROR | `plpy.error(msg)` （例外も発生） |
| FATAL | `plpy.fatal(msg)` （例外も発生） |

---

## 6. 言語選択判断テーブル

| ユースケース | PL/pgSQL | PL/Python3u |
|------------|---------|------------|
| **SQL中心の操作** | ✓ | - |
| **トランザクション制御** | ✓ | △（可能だが制限あり） |
| **計算集約型処理** | - | ✓ |
| **外部ライブラリ（NumPy, pandas等）** | - | ✓ |
| **ML/AI統合** | - | ✓ |
| **Trusted（信頼された言語）** | ✓ | ×（Untrusted） |
| **複雑な文字列処理** | △ | ✓ |
| **データサイエンス** | - | ✓ |
| **セキュリティ（PostgreSQLの制御下）** | ✓ | ×（スーパーユーザー必須） |

**判断基準:**
- **PL/pgSQL優先**: SQLクエリ中心、トランザクション管理重視、セキュリティ重視
- **PL/Python3u優先**: 計算集約型、外部ライブラリ活用、ML/AI統合

---

## まとめ

- **関数 vs プロシージャ**: 戻り値、トランザクション制御、SQL内呼出しの可否で使い分け
- **Volatility**: 正しい分類（IMMUTABLE/STABLE/VOLATILE）でパフォーマンス最適化
- **PL/pgSQL**: SQL中心、トランザクション制御、トリガー、pg_background拡張で自律トランザクション
- **PL/Python3u**: 外部ライブラリ、ML/AI、計算集約型処理に最適（Untrusted言語）
- **plpgsql_check**: 静的解析で早期バグ検出
