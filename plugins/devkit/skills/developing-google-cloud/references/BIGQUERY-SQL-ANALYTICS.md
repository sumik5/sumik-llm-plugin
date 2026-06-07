# BigQuery SQL分析実践パターン

BigQueryにおけるSQL分析の実践パターン集。数値・文字列・日付関数から始まり、正規表現・統計集計関数、ウィンドウ関数（RANK/LAG/LEAD/累計/移動平均）、GA4/Search Consoleの実データ分析、UDF（ユーザー定義関数）まで体系的に解説する。DWH設計・基本クエリ構文はDATA-WAREHOUSING.md、高度運用（スロット管理・クラスタリング）はBIGQUERY-ADVANCED-OPERATIONS.mdを参照。

---

## 数値を扱う関数

### 丸め処理（FLOOR / CEIL / ROUND）

| 関数 | 処理 |
|-----|------|
| `FLOOR(x)` | x以下の最大整数（切り捨て） |
| `CEIL(x)` / `CEILING(x)` | x以上の最小整数（切り上げ） |
| `ROUND(x, n)` | 桁数nで丸め。n省略時は一の位。nが負なら整数部を丸め |
| `TRUNC(x, n)` | 桁数nで切り捨て（ゼロ方向） |

```sql
WITH master AS (SELECT -98765.4321 AS number)
SELECT
  FLOOR(number)        AS floor_number   -- -98766
  , CEIL(number)       AS ceil_number    -- -98765
  , ROUND(number)      AS round_number   -- -98765
  , ROUND(number, 2)   AS round_2dec     -- -98765.43
  , ROUND(number, -2)  AS round_100s     -- -98800
FROM master
```

> **注意**: 負の数でFLOOR（切り捨て）は「より小さい」方向、CEIL（切り上げ）は「より大きい」方向に丸まる。

### その他の数値関数

| 関数 | 処理 |
|-----|------|
| `ABS(x)` | 絶対値 |
| `MOD(x, y)` | xをyで割った余り |
| `DIV(x, y)` | 整数除算（商） |
| `POWER(x, y)` | xのy乗 |
| `SQRT(x)` | 平方根 |
| `LOG(x)` / `LOG10(x)` | 自然対数 / 常用対数 |

---

## 文字列を扱う関数

### 基本的な文字列操作

| 関数 | 説明 |
|-----|------|
| `CONCAT(s1, s2, ...)` | 文字列連結（異なる型も自動変換） |
| `LENGTH(s)` / `CHAR_LENGTH(s)` | 文字列のバイト長 / 文字数 |
| `UPPER(s)` / `LOWER(s)` | 大文字化 / 小文字化 |
| `TRIM(s)` / `LTRIM(s)` / `RTRIM(s)` | 両端 / 左端 / 右端の空白除去 |
| `REPLACE(s, from, to)` | fromをtoに置換 |
| `SUBSTR(s, pos, len)` / `SUBSTRING(s, pos, len)` | pos文字目からlen文字を抽出 |
| `INSTR(s, target)` | targetが初めて出現する位置を返す（0=なし） |
| `LEFT(s, n)` / `RIGHT(s, n)` | 左からn文字 / 右からn文字 |
| `LPAD(s, len, pad)` / `RPAD(s, len, pad)` | 左埋め / 右埋め |
| `SPLIT(s, delim)` | delimで分割してARRAY返却 |

```sql
-- ユーザー名 + 敬称の連結
SELECT CONCAT(customer_name, "様") AS atesaki
FROM customers

-- セッションIDの生成（文字列型 + 数値型の連結）
SELECT CONCAT(user_pseudo_id, "-", ga_session_number) AS session_id
FROM web_log

-- URLからドメイン部分を抽出
SELECT SUBSTR(url, 1, INSTR(url, "/", 9) - 1) AS domain
FROM web_log
```

---

## 正規表現を利用する関数

正規表現（Regular Expression）はメタ文字を使って文字列パターンを表現する記述方法。BigQueryのREGEXP関数群はRE2構文に対応。

### 主要な正規表現関数

| 関数 | 戻り値 | 処理 |
|-----|-------|------|
| `REGEXP_CONTAINS(s, pattern)` | BOOL | patternに合致する部分が含まれるか判定 |
| `REGEXP_EXTRACT(s, pattern)` | STRING | 最初に合致した部分を抽出 |
| `REGEXP_EXTRACT_ALL(s, pattern)` | ARRAY | 合致するすべての部分をARRAYで返却 |
| `REGEXP_REPLACE(s, pattern, replacement)` | STRING | patternに合致する部分をreplacementに置換 |

### 主要なメタ文字

| メタ文字 | 意味 | 例 |
|---------|------|-----|
| `^` | 先頭 | `^T` → Tで始まる |
| `$` | 末尾 | `com$` → comで終わる |
| `.` | 任意の1文字 | `a.c` → abc, aXc など |
| `*` | 直前の0回以上の繰り返し | `ab*c` → ac, abc, abbc |
| `+` | 直前の1回以上の繰り返し | `ab+c` → abc, abbc |
| `?` | 直前の0または1回 | `ab?c` → ac, abc |
| `[...]` | 文字クラス | `[0-9]` → 数字1文字 |
| `\d` | 数字1文字 | `\d{4}` → 4桁の数字 |

```sql
-- 個人情報（8桁以上の連続数字 or 4桁-4桁パターン）を含む投稿の判定
SELECT post, REGEXP_CONTAINS(post, r"\d{8,}|\d{4}-\d{4}") AS has_pii
FROM s_7_3_a

-- URLからクエリパラメータを除いたパスを抽出
SELECT REGEXP_EXTRACT(page_location, r"^([^?]+)") AS clean_path
FROM web_log

-- 都道府県名をマスキング（正規表現で置換）
SELECT REGEXP_REPLACE(address, r"(東京都|大阪府|京都府)", "***") AS masked_address
FROM users
```

> **実践パターン**: GA4の `page_location` は `?` 以降にパラメータが付くため、`REGEXP_EXTRACT(url, r"^([^?]+)")` でクリーニングするのが定番。

---

## 日付・時刻を扱う関数

### 日付型の種類

| 型 | 形式 | 例 |
|---|------|-----|
| DATE | YYYY-MM-DD | 2024-06-01 |
| DATETIME | YYYY-MM-DD HH:MM:SS | 2024-06-01 09:30:00 |
| TIMESTAMP | UTC基準のタイムスタンプ | 2024-06-01 00:30:00 UTC |
| TIME | HH:MM:SS | 09:30:00 |

### 主要な日付関数

| 関数 | 処理 |
|-----|------|
| `CURRENT_DATE()` | 今日の日付（DATE型） |
| `CURRENT_DATETIME()` | 現在の日時（DATETIME型） |
| `CURRENT_TIMESTAMP()` | 現在のタイムスタンプ（TIMESTAMP型） |
| `DATE_DIFF(d1, d2, unit)` | d1とd2の差をunit単位で取得 |
| `DATE_ADD(d, INTERVAL n unit)` | 日付にn単位を加算 |
| `DATE_SUB(d, INTERVAL n unit)` | 日付からn単位を減算 |
| `DATE_TRUNC(d, unit)` | 指定単位で日付を丸め（切り捨て） |
| `FORMAT_DATE(fmt, d)` | 指定フォーマットで日付を文字列化 |
| `EXTRACT(unit FROM d)` | 日付から指定単位の値を抽出 |
| `PARSE_DATE(fmt, s)` | 文字列を日付にパース |
| `GENERATE_DATE_ARRAY(start, end, INTERVAL n unit)` | 日付の連続配列を生成 |

```sql
-- 購入日から今日までの経過日数を計算
SELECT customer_id,
       DATE_DIFF(CURRENT_DATE(), MAX(purchase_date), DAY) AS days_since_last_purchase
FROM sales
GROUP BY customer_id

-- 月次集計（DATE_TRUNCで月初めに丸める）
SELECT DATE_TRUNC(order_date, MONTH) AS month,
       SUM(revenue) AS monthly_revenue
FROM sales
GROUP BY month
ORDER BY month

-- GA4のevent_timestampはUNIX時マイクロ秒 → 日本時間に変換
SELECT event_date,
       TIMESTAMP_MICROS(event_timestamp) AS event_time_utc,
       DATETIME(TIMESTAMP_MICROS(event_timestamp), "Asia/Tokyo") AS event_time_jst
FROM events
```

### 日付フォーマット文字列（FORMAT_DATE）

| フォーマット | 出力例 |
|------------|--------|
| `%Y` | 2024 |
| `%m` | 06 |
| `%d` | 01 |
| `%A` | Saturday |
| `%j` | 153（年間通算日） |

---

## 統計集計関数

分散・標準偏差・相関係数を算出する集計関数群。GROUP BY句とともに使用し、通常の集計関数（SUM/AVG）と同じ記法で利用可能。

### 関数一覧

| 関数 | 処理 |
|-----|------|
| `VAR_POP(x)` | 母分散（全数対象） |
| `VAR_SAMP(x)` | 標本分散（サンプル対象、不偏分散） |
| `STDDEV_POP(x)` | 母標準偏差（全数対象） |
| `STDDEV_SAMP(x)` | 標本標準偏差（サンプル対象） |
| `CORR(x, y)` | 2変数の相関係数（-1〜1） |

### 利用例

```sql
-- 商品ごとの購入個数の散らばりを比較
SELECT product_id,
       AVG(quantity)        AS avg_qty,
       STDDEV_POP(quantity) AS stddev_qty,
       VAR_POP(quantity)    AS var_qty
FROM sales
WHERE product_id IN (1, 2)
GROUP BY product_id

-- 都道府県別の人口と最低賃金の相関係数を算出
SELECT CORR(estimated_population, min_wage) AS correlation
FROM prefecture_stats
```

> **CORR関数の解釈**:
> - 0.7〜1.0: 強い正の相関
> - 0.4〜0.7: 中程度の正の相関
> - -0.4〜0.4: 相関なし/弱い相関
> - -1.0〜-0.7: 強い負の相関

---

## ウィンドウ関数

通常の集計関数（GROUP BY）はレコードをグループにまとめるが、ウィンドウ関数は**元レコードを保持しながら**グループ内での演算結果を各行に付与する。

### 基本構文

```sql
関数名() OVER (
  PARTITION BY パーティション定義フィールド    -- グループ化（省略可）
  ORDER BY     並べ替えフィールド [ASC|DESC]  -- 関数によっては必須
  ROWS BETWEEN フレーム開始 AND フレーム終了   -- 対象レコード範囲（省略可）
)
```

**WINDOWフレーム指定値**:
| 指定値 | 意味 |
|-------|------|
| `UNBOUNDED PRECEDING` | パーティションの先頭 |
| `n PRECEDING` | 現在行からn行前 |
| `CURRENT ROW` | 現在行 |
| `n FOLLOWING` | 現在行からn行後 |
| `UNBOUNDED FOLLOWING` | パーティションの末尾 |

### ウィンドウ関数の種類と対応表

| 関数 | PARTITION BY | ORDER BY | WINDOWフレーム | 用途 |
|-----|-------------|---------|--------------|------|
| `RANK()` | 省略可 | 必須 | 利用不可 | 同位あり順位付け |
| `DENSE_RANK()` | 省略可 | 必須 | 利用不可 | 密な順位付け（飛びなし） |
| `ROW_NUMBER()` | 省略可 | オプション | 利用不可 | 連続した行番号 |
| `NTILE(n)` | 省略可 | 必須 | 利用不可 | n等分に分割 |
| `FIRST_VALUE(x)` | 省略可 | オプション | オプション | 最初の値を取得 |
| `LAST_VALUE(x)` | 省略可 | オプション | オプション | 最後の値を取得 |
| `NTH_VALUE(x, n)` | 省略可 | 必須 | オプション | n番目の値を取得 |
| `LEAD(x, n, default)` | 省略可 | 必須 | 利用不可 | n行後の値を取得 |
| `LAG(x, n, default)` | 省略可 | 必須 | 利用不可 | n行前の値を取得 |
| `PERCENTILE_CONT(x, p)` | 省略可 | 不要 | オプション | 百分位数を取得 |
| `SUM(x)` | 省略可 | オプション | オプション | 累計 |
| `AVG(x)` | 省略可 | オプション | オプション | 移動平均 |

---

## 番号付け関数（RANK / ROW_NUMBER / NTILE）

### RANK – ランキング（同率あり）

```sql
-- ユーザーごとの購入金額ランキング（同率同順位、次は飛ぶ）
SELECT *,
       RANK() OVER (
         PARTITION BY user_id
         ORDER BY revenue DESC
       ) AS rank_in_user
FROM sales

-- 商品カテゴリ別コストTop3を取得
SELECT *
FROM (
  SELECT product_category, product_name, cost,
         RANK() OVER (PARTITION BY product_category ORDER BY cost DESC) AS cost_rank
  FROM products
)
WHERE cost_rank <= 3
```

> **RANK vs DENSE_RANK**: RANKは同率が2件あると次は3位（2位を飛ばす）。DENSE_RANKは次も2位（連続）。

### ROW_NUMBER – 行番号（重複なし）

```sql
-- 購入日時順に行番号を付与（重複排除に活用）
SELECT *,
       ROW_NUMBER() OVER (
         PARTITION BY user_id
         ORDER BY purchase_date
       ) AS purchase_seq
FROM sales
```

### NTILE – 等分割

```sql
-- 売上を4分位に分類（RFM分析のF/M計算に応用）
SELECT customer_id, total_revenue,
       NTILE(4) OVER (ORDER BY total_revenue) AS revenue_quartile
FROM customer_summary
```

---

## ナビゲーション関数（FIRST_VALUE / LAST_VALUE / LEAD / LAG）

### FIRST_VALUE / LAST_VALUE – 最初・最後の値

```sql
-- 複数回購入した顧客のうち「初回が最大額」の顧客を分析
WITH analysis AS (
  SELECT user_id, date_time, revenue,
         -- 顧客別の初回購入日
         FIRST_VALUE(date_time) OVER (
           PARTITION BY user_id ORDER BY date_time
         ) AS first_purchase_date,
         -- 顧客別の最大額購入日
         FIRST_VALUE(date_time) OVER (
           PARTITION BY user_id ORDER BY revenue DESC
         ) AS max_revenue_date
  FROM sales
)
SELECT DISTINCT user_id
FROM analysis
WHERE first_purchase_date = max_revenue_date

-- 顧客の最終購入日を取得（休眠防止分析）
SELECT user_id, date_time,
       LAST_VALUE(date_time) OVER (
         PARTITION BY user_id
         ORDER BY date_time
         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS last_purchase_date
FROM sales
```

### LEAD / LAG – 直後・直前の値

```sql
-- 前月比較（LAGで1行前の値を取得）
SELECT user_id, year_month, revenue,
       LAG(revenue, 1) OVER (
         PARTITION BY user_id
         ORDER BY year_month
       ) AS prev_month_revenue
FROM monthly_sales

-- ページ滞在時間を計算（LEADで次イベントのタイムスタンプを取得）
SELECT user_pseudo_id, page_location, event_timestamp,
       LEAD(event_timestamp) OVER (
         PARTITION BY user_pseudo_id
         ORDER BY event_timestamp
       ) - event_timestamp AS time_on_page_microseconds
FROM ga4_events
WHERE event_name = "page_view"
```

### PERCENTILE_CONT – 百分位数（四分位数）

```sql
-- 年度別の売上四分位数を取得（IQR計算）
SELECT year, MAX(q3) - MAX(q1) AS iqr
FROM (
  SELECT year,
         PERCENTILE_CONT(sum_rev, 0.25) OVER (PARTITION BY year) AS q1,
         PERCENTILE_CONT(sum_rev, 0.75) OVER (PARTITION BY year) AS q3
  FROM annual_sales
)
GROUP BY year
```

---

## 集計分析関数（SUM累計 / AVG移動平均）

### SUM – 累計（累積売上）

```sql
-- 月次累計売上を取得
SELECT year_month, monthly_revenue,
       SUM(monthly_revenue) OVER (
         ORDER BY year_month
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS cumulative_revenue
FROM monthly_summary
```

### AVG – 移動平均

```sql
-- 3カ月移動平均を取得（直近3カ月の平均）
SELECT year_month, monthly_revenue,
       AVG(monthly_revenue) OVER (
         ORDER BY year_month
         ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS moving_avg_3m
FROM monthly_summary
```

> **WINDOWフレームの重要性**: `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` が累計、`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` が3カ月移動平均。ORDER BY指定時のデフォルトは `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` で、同じ値をまとめて扱うため意図しない結果になる場合がある。**数値計算では `ROWS BETWEEN` を明示することを推奨。**

---

## 縦持ち↔横持ち変換

データの「持ち方」には縦持ち（レコード数が多い）と横持ち（カラム数が多い）の2種類がある。BigQueryはカラム追加が苦手なため縦持ちが基本。CSVインポートや帳票出力で横持ちへの変換が必要になる。

### 横持ち→縦持ち変換（UNION ALLパターン）

```sql
-- 年別の最低賃金横持ちを縦持ちに変換
SELECT pref, "R3" AS year, r3_min_wage AS min_wage FROM min_wage_wide
UNION ALL
SELECT pref, "R4" AS year, r4_min_wage AS min_wage FROM min_wage_wide
UNION ALL
SELECT pref, "R5" AS year, r5_min_wage AS min_wage FROM min_wage_wide
ORDER BY pref, year
```

### 縦持ち→横持ち変換（CASE+GROUP BYパターン）

```sql
-- 縦持ちの最低賃金を年別横持ちに変換
SELECT pref,
       MAX(CASE WHEN year = "R3" THEN min_wage END) AS r3_min_wage,
       MAX(CASE WHEN year = "R4" THEN min_wage END) AS r4_min_wage,
       MAX(CASE WHEN year = "R5" THEN min_wage END) AS r5_min_wage
FROM min_wage_long
GROUP BY pref
ORDER BY pref
```

| 操作 | 向いていること |
|-----|--------------|
| 縦持ちテーブル | 集計計算（SUM/AVG/COUNT）が容易 |
| 横持ちテーブル | 人間が読みやすい、Excelで扱いやすい |

---

## GA4データの整形と分析

GA4はBigQueryにヒット単位でデータをエクスポートする。1ヒット = 1イベント。

### GA4テーブルの主要カラム

| カラム名 | データ型 | 内容 |
|---------|---------|------|
| `event_date` | STRING | イベント発生日（YYYYMMDD形式） |
| `event_timestamp` | INT64 | イベント発生時刻（UNIX時マイクロ秒） |
| `event_name` | STRING | イベント名（page_view, scroll, purchase など） |
| `event_params` | ARRAY<STRUCT> | イベントの詳細パラメータ（ネスト構造） |
| `user_pseudo_id` | STRING | 匿名ユーザー識別子 |
| `user_first_touch_timestamp` | INT64 | 初回訪問時刻（UNIX時マイクロ秒） |
| `device.category` | STRING | デバイスカテゴリ |
| `geo.country` | STRING | 国 |
| `collected_traffic_source.manual_campaign_name` | STRING | キャンペーン名 |

### event_paramsの構造とUNNEST

`event_params` は1つのカラムに複数のキー・バリューペアを格納するSTRUCT配列（ネスト構造）。`UNNEST` でフラット化してアクセスする。

```
event_params (ARRAY<STRUCT>)
├── key: "page_location"   → value.string_value: "/about/"
├── key: "page_title"      → value.string_value: "会社概要"
├── key: "ga_session_id"   → value.int_value: 1234567890
├── key: "ga_session_number" → value.int_value: 3
└── key: "session_engaged" → value.string_value: "1"
```

**value の型に応じて適切なフィールドを指定**:
- `value.string_value` – URL・タイトル・文字列パラメータ
- `value.int_value` – セッションID・セッション番号（整数）
- `value.float_value` / `value.double_value` – 数値パラメータ

### UNNEST パターン集

```sql
-- パターン1: サブクエリ方式（最も一般的）
SELECT
  event_date, event_name,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = "page_location") AS page_location,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = "page_title") AS page_title,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = "ga_session_id") AS session_id
FROM `project.analytics_XXXXX.events_20240501`
WHERE event_name = "page_view"

-- パターン2: CROSS JOIN UNNEST方式（複数キーを一括展開）
SELECT event_date, event_name, ep.key, ep.value.string_value, ep.value.int_value
FROM `project.analytics_XXXXX.events_*`
CROSS JOIN UNNEST(event_params) AS ep
WHERE _TABLE_SUFFIX BETWEEN "20240401" AND "20240430"
  AND ep.key IN ("page_location", "ga_session_id")

-- パターン3: ECサイトの商品データ（itemsはARRAY）
SELECT event_date, event_name, it.item_name, it.price
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210104`
CROSS JOIN UNNEST(items) AS it
WHERE event_name = "purchase"
```

### GA4実践分析パターン

```sql
-- 初回訪問LPから購入までの平均セッション数
WITH first_visit AS (
  SELECT DISTINCT user_pseudo_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = "page_location") AS first_lp
  FROM `project.analytics_XXXXX.events_*`
  WHERE event_name = "first_visit"
),
purchase AS (
  SELECT user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = "ga_session_number") AS session_num
  FROM `project.analytics_XXXXX.events_*`
  WHERE event_name = "purchase"
),
first_purchase AS (
  SELECT user_pseudo_id, MIN(session_num) AS min_session_num
  FROM purchase
  GROUP BY user_pseudo_id
)
SELECT fp.first_lp, AVG(fpur.min_session_num) AS avg_sessions_to_purchase
FROM first_visit AS fp
JOIN first_purchase AS fpur USING (user_pseudo_id)
GROUP BY fp.first_lp
ORDER BY avg_sessions_to_purchase

-- event_timestampのJST変換 + ページURL正規化
SELECT
  event_date,
  DATETIME(TIMESTAMP_MICROS(event_timestamp), "Asia/Tokyo") AS event_time_jst,
  REGEXP_EXTRACT(
    LOWER((SELECT value.string_value FROM UNNEST(event_params) WHERE key = "page_location")),
    r"^([^?]+)"
  ) AS clean_page_location,
  event_name
FROM `project.analytics_XXXXX.events_*`
WHERE _TABLE_SUFFIX BETWEEN "20240401" AND "20240430"
```

### 複数日付テーブルのワイルドカード指定

```sql
-- _TABLE_SUFFIXでYYYYMMDD形式のテーブルを範囲指定
SELECT *
FROM `project.analytics_XXXXX.events_*`
WHERE _TABLE_SUFFIX BETWEEN "20240101" AND "20240131"

-- 最新30日分を動的に指定
SELECT *
FROM `project.analytics_XXXXX.events_*`
WHERE _TABLE_SUFFIX >= FORMAT_DATE("%Y%m%d", DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
```

---

## Search Consoleデータの整形と分析

Google Search ConsoleのデータをBigQueryにエクスポートすると `searchdata_site_impression` テーブルに蓄積される。

### searchdata_site_impressionの主要カラム

| カラム名 | 内容 |
|---------|------|
| `data_date` | 計測日（DATE型） |
| `query` | 検索クエリ |
| `url` | クリックされたURL |
| `impressions` | 表示回数 |
| `clicks` | クリック数 |
| `sum_top_position` | 表示回数加重掲載順位の合計（0始まり） |

> **平均掲載順位の計算**: `ROUND(SUM(sum_top_position) / SUM(impressions) + 1, 1)` のように `+1` が必要（0始まりのため）。

### Search Console基本集計

```sql
-- 週別の検索パフォーマンスサマリ
SELECT
  DATE_TRUNC(data_date, WEEK) AS week,
  SUM(impressions)             AS sum_imp,
  SUM(clicks)                  AS sum_clk,
  ROUND(SUM(clicks) / SUM(impressions) * 100, 2) AS ctr,
  ROUND(SUM(sum_top_position) / SUM(impressions) + 1, 1) AS avg_pos,
  COUNT(DISTINCT query)        AS unique_query_count
FROM `project.searchconsole.searchdata_site_impression`
WHERE data_date BETWEEN "2024-01-01" AND "2024-03-31"
GROUP BY week
ORDER BY week
```

### 新規クエリの発見（ウィンドウ関数との組み合わせ）

```sql
-- 直近1週間で初めて出現したクエリを抽出
WITH query_history AS (
  SELECT data_date, query, url, impressions, clicks,
         FIRST_VALUE(data_date) OVER (
           PARTITION BY query
           ORDER BY data_date
         ) AS first_day_in_gsc
  FROM `project.searchconsole.searchdata_site_impression`
)
SELECT first_day_in_gsc, query, url,
       SUM(impressions) AS total_imp,
       SUM(clicks)      AS total_clk
FROM query_history
WHERE first_day_in_gsc >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY first_day_in_gsc, query, url
ORDER BY total_imp DESC
```

---

## UDF（ユーザー定義関数）

UDF（User Defined Function）は、ユーザーが独自に定義できる関数。複雑な判定ロジックを再利用可能な形でカプセル化できる。

### UDFの基本構文

```sql
CREATE TEMP FUNCTION 関数名(引数名 型, ...) RETURNS 戻り値の型 AS (
  -- 関数の本体
  式や関数呼び出し
);

-- 本体クエリ（UDFの定義後に続けて記述）
SELECT 関数名(フィールド名, ...) FROM テーブル名
```

| キーワード | 意味 |
|----------|------|
| `CREATE TEMP FUNCTION` | 一時的なUDFを作成（同一クエリ内のみ有効） |
| `RETURNS` | 戻り値のデータ型を指定 |
| `AS (...)` | 関数の本体（SQL式） |

> **セミコロン必須**: UDFの定義末尾（`)`の後）に `;` が必要。それ以外の場合は不要。

### UDFの活用例

```sql
-- 2キーワードのいずれかを含むクエリを判定するUDF
CREATE TEMP FUNCTION TARGET_QUERY(q STRING, x STRING, y STRING)
RETURNS BOOL AS (
  REGEXP_CONTAINS(q, CONCAT(r".*(", x, "|", y, r").*"))
);

-- Search ConsoleでBigQuery/SQL関連クエリのみを集計
SELECT
  DATE_TRUNC(data_date, WEEK) AS week,
  SUM(impressions) AS sum_imp,
  SUM(clicks) AS sum_clk,
  ROUND(SUM(clicks) / SUM(impressions) * 100, 2) AS ctr,
  ROUND(SUM(sum_top_position) / SUM(impressions) + 1, 1) AS avg_pos
FROM `project.searchconsole.searchdata_site_impression`
WHERE TARGET_QUERY(query, "bigquery", "sql")
GROUP BY week
ORDER BY week;
```

### UDF設計のポイント

| 場面 | 推奨パターン |
|-----|------------|
| 複雑な正規表現パターンを再利用 | UDFに正規表現ロジックをカプセル化 |
| カテゴリ分類ロジック | CASE WHENをUDFに収める |
| 数値計算の標準化 | 割算・率計算の共通UDFを定義 |
| JavaScriptが必要な高度処理 | UDF内でJavaScriptを記述可能（`LANGUAGE js`） |

---

## Google フォームデータの整形と分析

Google フォームの回答をBigQueryにエクスポートすると横持ち形式で格納される（質問ごとにカラムが作成）。複数回答（チェックボックス）は1つのカラムにセミコロン区切りで格納される。

### 分析の基本パターン

```sql
-- 複数回答をSPLITで分割してUNNESTで展開
SELECT
  respondent_id,
  answer_item
FROM form_responses
CROSS JOIN UNNEST(SPLIT(multi_answer_column, ";")) AS answer_item
WHERE TRIM(answer_item) != ""
```

### 縦持ち変換後の集計

```sql
-- フォーム回答を縦持ちに変換後、選択肢別の回答数を集計
WITH long_format AS (
  SELECT respondent_id, TRIM(answer_item) AS answer_item
  FROM form_responses
  CROSS JOIN UNNEST(SPLIT(interests, ";")) AS answer_item
  WHERE TRIM(answer_item) != ""
)
SELECT answer_item,
       COUNT(*) AS response_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS percentage
FROM long_format
GROUP BY answer_item
ORDER BY response_count DESC
```

---

## ベストプラクティスまとめ

### クエリ設計の判断基準

| 要件 | 推奨アプローチ |
|-----|-------------|
| グループ内順位・ランキング | `RANK()` または `DENSE_RANK()` + サブクエリでフィルタ |
| 前後比較（月次・週次） | `LAG()` / `LEAD()` でOVER句内ORDER BY指定 |
| 累計・移動平均 | `SUM()` / `AVG()` + `ROWS BETWEEN` で明示的フレーム指定 |
| GA4データ抽出 | サブクエリ方式のUNNESTで `value.string_value` / `value.int_value` を選択 |
| 文字列パターンマッチ | `REGEXP_CONTAINS` で判定 → `REGEXP_EXTRACT` で抽出 |
| 統計的比較 | `STDDEV_POP` で散らばり、`CORR` で2変数関係を定量化 |
| テーブル構造変換 | 横持ち→縦持ちはUNION ALL、縦持ち→横持ちはCASE+GROUP BY |

### GA4クエリ最適化のポイント

1. **ワイルドカードテーブル + `_TABLE_SUFFIX`** でスキャンするパーティション数を最小化
2. **`UNNEST` はサブクエリ方式**を基本とし、展開するキーをWHEREで絞り込み
3. **`event_timestamp` のJST変換**は `DATETIME(TIMESTAMP_MICROS(event_timestamp), "Asia/Tokyo")` で一行化
4. **`page_location` のクリーニング**は `REGEXP_EXTRACT(LOWER(url), r"^([^?]+)")` でパラメータを除去
5. **WITH句（CTE）** を使って処理ステップを分割すると可読性・デバッグ性が向上
