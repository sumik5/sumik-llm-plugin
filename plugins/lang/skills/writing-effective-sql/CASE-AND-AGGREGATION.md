# CASE式と集約

CASE式による条件分岐と、GROUP BY／HAVING句による集合単位の集計を扱う。スキーマ設計・正規化・実行計画の読み方そのものは対象外（正規化やER設計は `lang:developing-databases`、実行計画に基づくリライトは `PERFORMANCE-REWRITING.md` を参照）。

## 1. CASE式の構文と3つの罠

CASE式には単純CASE式と検索CASE式の2種類がある。検索CASE式は単純CASE式の機能を包含するため、迷ったら検索CASE式を使えばよい。

| 種類 | 構文 | 表現できる条件 |
|------|------|--------------|
| 単純CASE式 | `CASE col WHEN val1 THEN ... WHEN val2 THEN ... ELSE ... END` | 等価比較のみ |
| 検索CASE式 | `CASE WHEN col = val1 THEN ... WHEN col > val2 THEN ... ELSE ... END` | 任意の述語（`>`・`BETWEEN`・`IN`・`EXISTS`など） |

```sql
-- 検索CASE式（推奨デフォルト）
SELECT
    CASE WHEN status = 'active'  THEN '稼働中'
         WHEN status = 'paused'  THEN '一時停止'
         ELSE '不明' END AS status_label
FROM subscriptions;
```

CASE式は上から評価され、最初に真になったWHEN句で評価が打ち切られる。以降のWHEN句は評価されないため、WHEN句は互いに排他的に書くのが安全（`col IN ('a','b')` の次に `col IN ('a')` を書いても、後者に到達することはない）。

CASE式は「式」であり「文」ではない。したがって、列名や定数を書ける場所（SELECT・WHERE・GROUP BY・HAVING・ORDER BY・PARTITION BY・CHECK制約・関数の引数・他の式の中）にはどこにでも書ける。

### 3つの罠

| 罠 | 内容 | 対策 |
|----|------|------|
| 型の不一致 | 分岐によって返す値の型（文字列/数値/日付）が異なるとエラーになる | 全分岐で同じ型を返す。数値と文字列を混在させたいときは明示的にCASTする |
| ENDの書き忘れ | CASE式はENDで終端しないと構文エラー | 「構文は正しいはずなのに動かない」と感じたら真っ先に疑う |
| ELSE句の省略 | ELSEを省略すると暗黙に `ELSE NULL` として扱われ、エラーにはならないままバグになる | ELSEでNULLを返したい場合も明示的に書く。修正時の見落としを防げる |

## 2. WHERE/HAVING句の分岐をSELECT句のCASE式に置き換える

「条件分岐をWHERE句で行うのは素人、SELECT句で分岐させるのが定石」という経験則がある。UNIONで複数のSELECT文をマージして分岐を表現すると、内部的にはテーブルへの複数回アクセスとして実行されやすく、テーブルが大きいほどI/Oコストが線形に増える。CASE式でSELECT句内に分岐を畳み込めば、1回のスキャンで済む。

```sql
-- 冗長: UNIONで分岐（2001年以前/2002年以降で価格列を出し分ける）
SELECT item_name, year, price_tax_ex AS price FROM items WHERE year <= 2001
UNION ALL
SELECT item_name, year, price_tax_in AS price FROM items WHERE year >= 2002;

-- 推奨: SELECT句のCASE式で1回のスキャンにする
SELECT item_name, year,
       CASE WHEN year <= 2001 THEN price_tax_ex
            WHEN year >= 2002 THEN price_tax_in END AS price
FROM items;
```

同様に「HAVING句で分岐させるのも素人のやること」という格言もある。集約結果（COUNT・SUMなどの戻り値）はSELECT句の中では1行につき1つのスカラ値になるため、CASE式の入力に取れる。

```sql
-- HAVING句を3回書いてUNIONする代わりに
SELECT emp_name,
       CASE WHEN COUNT(*) = 1 THEN MAX(team)
            WHEN COUNT(*) = 2 THEN '2つを兼務'
            WHEN COUNT(*) >= 3 THEN '3つ以上を兼務' END AS team
FROM employees
GROUP BY emp_name;
```

### 判断基準: UNION / IN / CASE式のどれを使うか

| 状況 | 推奨 | 理由 |
|------|------|------|
| マージするSELECT文が同一テーブル・同一列構成 | CASE式 | テーブルアクセスが1回に減る |
| マージするSELECT文が異なるテーブルを参照する | UNION | CASE式では代替できない（結合が必要になりかえって遅くなることがある） |
| `(col_a, col_b)` のような複数列の組を定数リストと比較したい | IN + 行式 `(a, b) IN ((1,2),(3,4))` | ORの羅列より簡潔。ただし実行計画はORと同じ場合が多い |
| 対象列にインデックスがあり、UNION側の各枝だけがインデックスを使える | UNION | ORやCASE式に書き換えるとインデックスが使われずフルスキャンになることがある。実測して判断する（詳細は `PERFORMANCE-REWRITING.md`） |

## 3. 条件付き集計（横持ち変換）

集約関数の引数にCASE式を渡すと、「行持ち」のデータを「列持ち」（クロス表）に変換できる。これは実務で頻出する技法である。

```sql
-- 都道府県×性別の人口を1行にまとめる
SELECT prefecture,
       SUM(CASE WHEN sex = '1' THEN pop ELSE 0 END) AS pop_men,
       SUM(CASE WHEN sex = '2' THEN pop ELSE 0 END) AS pop_wom
FROM population
GROUP BY prefecture;
```

`SUM` を省略してCASE式だけを書くと、レコードは集約されずに元テーブルの行数のまま返ってくる（CASE式自体には集約機能がない）。列を作るのはCASE式、行をまとめるのは集約関数、という役割分担を混同しないこと。

条件を満たす行数だけを数えたい場合は、`SUM` より `COUNT` を使うほうが意図が伝わりやすい。

```sql
SELECT dept,
       COUNT(CASE WHEN score >= 80 THEN 1 END)          AS high_scorers,
       COUNT(DISTINCT CASE WHEN score >= 80 THEN student_id END) AS unique_high_scorers
FROM exam_results
GROUP BY dept;
```

`COUNT(式)` は式がNULLの行を数えないという性質を利用し、CASE式のELSEを省略（暗黙のELSE NULL）することで「条件を満たす行だけを数える」を簡潔に書ける（一部のDBMSでは `COUNT_IF` や `COUNTIF` という専用関数も用意されている）。

| 目的 | パターン |
|------|---------|
| 条件を満たす値の合計 | `SUM(CASE WHEN cond THEN col ELSE 0 END)` |
| 条件を満たす行数 | `COUNT(CASE WHEN cond THEN 1 END)` |
| 条件を満たすレコードのユニーク数 | `COUNT(DISTINCT CASE WHEN cond THEN key_col END)` |
| 条件を満たす行の平均（満たさない行は計算に含めない） | `AVG(CASE WHEN cond THEN col END)`（`ELSE 0` にすると平均が歪む。4節参照） |

## 4. コード再分類とGROUP BY句でのCASE式

GROUP BYのキーそのものをCASE式で計算すれば、既存のコード体系を分析用の別体系に動的に再分類して集計できる（県→地方、年齢→階級など）。

```sql
SELECT CASE WHEN prefecture IN ('徳島','香川','愛媛','高知') THEN '四国'
            WHEN prefecture IN ('福岡','佐賀','長崎')       THEN '九州'
       ELSE 'その他' END AS district,
       SUM(population) AS total_pop
FROM pop_tbl
GROUP BY CASE WHEN prefecture IN ('徳島','香川','愛媛','高知') THEN '四国'
              WHEN prefecture IN ('福岡','佐賀','長崎')       THEN '九州'
         ELSE 'その他' END;
```

標準SQLでは、SELECT句とGROUP BY句の両方に同じCASE式を書く必要がある。SELECT句で付けた別名をGROUP BY句で再利用できるかはDBMSによって異なる。

| DBMS | `GROUP BY <SELECT句の別名>` | 備考 |
|------|------------------------------|------|
| PostgreSQL / MySQL / BigQuery | 可 | SELECT句のリストを先に評価してからグループ化するため |
| Oracle / SQL Server / Db2 | 不可（構文エラー） | 標準SQL準拠が厳格。同じCASE式を2箇所に書く必要がある |

複数DBMSに配布するコードやポータビリティを重視する場合は、別名参照に依存せずCASE式を重複して書くほうが安全。CTE（`WITH`句）で一段くくり出し、外側のクエリで別名を再利用する書き方も選択肢になる（結合の詳細は `JOINS-AND-SUBQUERIES.md` 参照）。

## 5. CASE式の入れ子（集約関数との組み合わせ）

CASE式は他のCASE式や集約関数を入れ子にできる。「1つだけ条件を満たす場合はA、複数条件を満たす場合はB」のような二段階の分岐に使う。

```sql
-- 1つのクラブに専念する学生はそのクラブID、兼務している学生は「主なクラブ」フラグの立った行を採用
SELECT std_id,
       CASE WHEN COUNT(*) = 1 THEN MAX(club_id)
            ELSE MAX(CASE WHEN main_club_flg = 'Y' THEN club_id END)
       END AS main_club
FROM student_club
GROUP BY std_id;
```

集約関数はSELECT句において最終的に1つのスカラ値に評価されるため、外側のCASE式は結局1つの値を入力に取っているだけであり、文法違反ではない。同様に、CASE式の中に集約関数を書くことも可能。

## 6. GROUP BYの基礎

### 6.1 論理評価順序

SELECT文は書いた順序ではなく、次の順序で評価される。WHERE句とHAVING句を混同するミスの多くはこの順序を誤解していることに起因する。

| 順序 | 句 | 役割 |
|------|-----|------|
| 1 | FROM | 対象データセットを決定 |
| 2 | WHERE | 集約前の行をフィルタリング |
| 3 | GROUP BY | フィルタ後のデータセットを集約（部分集合に「カット」してから集約） |
| 4 | HAVING | 集約後のグループをフィルタリング |
| 5 | SELECT | フィルタ後の集約結果を変換 |
| 6 | ORDER BY | 結果をソート |
| 7 | LIMIT / OFFSET | 表示件数を制御 |

WHERE句で先に絞り込めるだけ絞り込んでおくと、集約対象のデータ量が減りパフォーマンスが向上する。「集約結果に依存するフィルタ」だけをHAVING句に書く。

### 6.2 SELECT句に書ける列の制約

GROUP BYで集約したSELECT句に書けるのは、次の3種類のみ。

- 定数
- GROUP BY句で指定した集約キー（列そのもの、または同じ式）
- 集約関数の結果

これ以外の「裸の列」（集約キーにも集約関数にも属さない列）をSELECT句に書くとエラーになる。GROUP BY句のキーは単純な列名だけでなく、CASE式や計算式（`weight / POWER(height/100, 2)` のようなBMI計算式など）を使うこともできる。GROUP BY句にCASE式や計算式を使っても、実行計画上のアクセスパスには影響しない（データを取得した後のCPU演算が増えるだけ）。

### 6.3 ROLLUP / CUBE / GROUPING SETS

複数粒度の集計をUNIONで組み合わせる代わりに1つのクエリで表現する機能。

| 機能 | 生成される集計粒度 | 使うべき場面 |
|------|-------------------|------------|
| `GROUP BY ROLLUP (a, b)` | `(a,b)` `(a)` `()`（右から順に集約キーを外していく階層集計） | 小計・合計を含む階層レポート（例: 支店→全社） |
| `GROUP BY CUBE (a, b)` | `(a,b)` `(a)` `(b)` `()`（全組み合わせ） | 複数軸すべての切り口でクロス集計したいとき |
| `GROUP BY GROUPING SETS ((a),(b),())` | 指定した組み合わせのみ | 必要な粒度だけをピンポイントに指定したいとき（ROLLUP/CUBEより制御が細かい） |

一部のDBMS（Microsoft Accessなど）はROLLUP/CUBE/GROUPING SETSを未サポート。その場合は、複数のGROUP BYクエリをUNIONで組み合わせる必要がある。

### 6.4 内部動作とパフォーマンスの注意

GROUP BYの集約は内部的にハッシュまたはソートで実装される。近年はハッシュが選ばれることが多く、キーの一意性が高いほど効率が良い。ハッシュ・ソートいずれもワーキングメモリを消費する演算のため、メモリが不足すると一時領域（ストレージ）を使う「TEMP落ち」が発生し、パフォーマンスが大幅に劣化する。集約対象の行数が多いクエリは、本番相当のデータ量で性能試験を行うこと。実行計画に基づく詳細なチューニングは `PERFORMANCE-REWRITING.md` を参照。

なお、「GROUP BY句から集約機能を取り去り、カットの機能だけ残したもの」がウィンドウ関数の `PARTITION BY` 句である。行間比較や移動平均などウィンドウ関数固有の話題は `WINDOW-FUNCTIONS.md` を参照。

## 7. GROUP BY句は短く保つ（関数従属性）

主キー列でグループ化する場合、同じテーブルの他の列は主キーに関数従属している（主キーが同じなら他の列の値も一意に定まる）。そのため、本来はGROUP BY句に主キーだけを書けば十分なはずだが、対応状況はDBMSによって異なる。

| DBMS | 主キーのみのGROUP BYで従属列をSELECTに書けるか |
|------|------------------------------------------------|
| MySQL / PostgreSQL | 可（関数従属性を認識） |
| その他の主要DBMS | 不可（「集約または式の一部として含まれていない列参照」エラー） |

移植性を優先するなら、集約をサブクエリに閉じ込め、詳細列は外側のJOINで取得する形に書き換える。

```sql
-- 集約だけを先に済ませてから詳細列を結合する（GROUP BY句が肥大化しない）
SELECT c.customer_id, c.cust_name, o.order_count, o.total_amount
FROM customers AS c
LEFT JOIN (
    SELECT customer_id, COUNT(*) AS order_count, SUM(order_total) AS total_amount
    FROM orders
    GROUP BY customer_id
) AS o ON c.customer_id = o.customer_id;
```

GROUP BY句に列が多いほど「何を基準に集約しているのか」が読み取りにくくなり、クエリの意図の分析やインデックス設計が難しくなる。集約に本当に必要な列だけをGROUP BY句に残す習慣をつける。

## 8. HAVING句とWHERE句の使い分け

| 観点 | WHERE | HAVING |
|------|-------|--------|
| 適用タイミング | 集約前の行 | 集約後のグループ |
| 対象 | 個々の行の性質 | 集合（グループ）自身の性質 |
| 典型例 | `WHERE status = 'active'` | `HAVING COUNT(*) > 5` |

SELECT句で集約式に別名を付けても、その別名をHAVING句で再利用することはできない（多くのDBMSで文法エラーになる）。同じ集約式をHAVING句にもう一度書く必要がある。

```sql
-- 平均配達日数が全ベンダー平均を上回るベンダーを検索
SELECT v.vend_name,
       AVG(DATEDIFF(day, p.order_date, p.delivery_date)) AS delivery_days
FROM vendors AS v
JOIN purchase_orders AS p ON v.vendor_id = p.vendor_id
WHERE p.delivery_date IS NOT NULL
GROUP BY v.vend_name
HAVING AVG(DATEDIFF(day, p.order_date, p.delivery_date)) >
       (SELECT AVG(DATEDIFF(day, order_date, delivery_date))
        FROM purchase_orders WHERE delivery_date IS NOT NULL);
```

WHERE句とHAVING句は併用できる。「WHERE句で母集団を絞り込んでからGROUP BYで集約し、HAVING句で集約結果をさらに絞り込む」という組み合わせは自然で頻出のパターンである。

## 9. 集約を使わず最大/最小の詳細行を取得する

`GROUP BY key, MAX(col)` では、その最大値を持つ行の「他の列」（例えば産地や日付）を一緒に取得できない。同じキーで最大値を持つ行以外との比較を自己結合で表現すれば、GROUP BYなしで詳細行を取得できる。

```sql
-- カテゴリごとにアルコール度数が最大の行の詳細（産地・銘柄）を取得
SELECT l.category, l.country, l.style, l.max_abv
FROM beer_styles AS l
LEFT JOIN beer_styles AS r
  ON l.category = r.category AND l.max_abv < r.max_abv
WHERE r.max_abv IS NULL   -- 自分より大きい値を持つ行が存在しない = 最大値
ORDER BY l.category;
```

`ON`句の等価比較がGROUP BYのキーに相当し、不等号比較がMAX/MINに相当する。GROUP BYを使わないため、他のテーブルとの結合が容易になるという利点がある。同じ問題は相関サブクエリでも書けるが、行ごとにサブクエリが実行されるため、テーブルが大きい場合はコストが高くなりやすい。

| 手法 | 向いている場面 |
|------|--------------|
| 自己結合（LEFT JOIN + `col <` 比較） | GROUP BYや集約を避けたい、他テーブルとの結合と組み合わせたい |
| 相関サブクエリ | クエリの意図を最も素直に表現したい（小〜中規模データ） |
| ウィンドウ関数（`ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ... DESC)` など） | 対応DBMSであれば最も簡潔・高速なことが多い。詳細は `WINDOW-FUNCTIONS.md` |

## 10. OUTER JOIN後のCOUNTとDISTINCTの罠

`LEFT OUTER JOIN` の後に `COUNT(*)` を使うと、右側テーブルに一致行がない（＝件数0であるべき）グループでも1件とカウントしてしまう。右側テーブルの列に対して `COUNT(列名)` を使うと、NULLになった行が数えられないため正しい件数になる。

```sql
-- 誤り: レシピが0件のクラスでも COUNT(*) は1になる
SELECT rc.class_name, COUNT(*) AS recipe_count
FROM recipe_classes AS rc
LEFT JOIN recipes AS r ON rc.class_id = r.class_id
GROUP BY rc.class_name;

-- 正しい: 右テーブルの列をCOUNTすればNULL行は数えない
SELECT rc.class_name, COUNT(r.class_id) AS recipe_count
FROM recipe_classes AS rc
LEFT JOIN recipes AS r ON rc.class_id = r.class_id
GROUP BY rc.class_name;
```

`HAVING COUNT(x) < N` で「0件のグループ」を検索したい場合も同じ罠がある。`INNER JOIN` では0件のグループがそもそも結果に現れないため検索できず、`LEFT JOIN` の右側テーブルに絞り込み条件を `WHERE` 句で書くと外部結合の効果が打ち消されて内部結合と同じ結果になってしまう。フィルタ条件はサブクエリの中か `ON` 句に移す。

```sql
-- 香辛料の使用数が2つ以下のメインコースを検索する正しい書き方
SELECT r.recipe_title, COUNT(ri.recipe_id) AS ingred_count
FROM recipes AS r
LEFT JOIN (
    SELECT recipe_id FROM recipe_ingredients WHERE ingredient_class = 'Spice'
) AS ri ON r.recipe_id = ri.recipe_id
WHERE r.recipe_class = 'Main course'
GROUP BY r.recipe_title
HAVING COUNT(ri.recipe_id) < 3;
```

重複を除いた個数が必要なら `COUNT(DISTINCT 列)` を使う。`COUNT(*)`・`COUNT(列)`・`COUNT(DISTINCT 列)` は結果が異なることが多いため、どの意味で「数える」のかを意識して選ぶ。

| 関数 | 数える対象 |
|------|-----------|
| `COUNT(*)` | NULLを含む全行 |
| `COUNT(col)` | `col` がNULLでない行 |
| `COUNT(DISTINCT col)` | `col` の重複を除いた非NULL値の種類数 |

## 11. HAVING句で集合の性質を調べる

HAVING句はGROUP BYで作った部分集合（数学的には「類」と呼ばれる）そのものの性質を判定する道具である。「実体1つにつき1行ならWHERE句、実体1つにつき複数行が対応するならHAVING句」が基本判断。CASE式でSELECT句を組み立てれば、行を集約せずに「この集合はこの条件を満たすか」を一覧表示することもできる。

### 11.1 特性関数（characteristic function）

行ごとに条件を満たすかどうかを0/1のフラグに変換するCASE式を、特性関数と呼ぶ。集約関数と組み合わせることで、複雑な集合条件をシンプルなHAVING句に落とし込める。

```sql
-- クラスの75%以上が80点以上のクラスを選択
SELECT class
FROM test_results
GROUP BY class
HAVING COUNT(*) * 0.75 <= SUM(CASE WHEN score >= 80 THEN 1 ELSE 0 END);
```

平均を比較する場合、条件を満たさない行を `ELSE 0` にすると「該当者がいない集合の平均が0点」という誤った値になり、比較結果が歪む。「該当者がいない場合は未定義（NULL）」を維持するには `ELSE NULL`（省略時のデフォルトと同じ）にする。AVG関数は空集合に対してNULLを返す仕様であり、これは通常のAVGの挙動とも一致する。

| ELSEの書き方 | 該当者ゼロの集合での挙動 |
|-------------|--------------------------|
| `ELSE 0` | 平均が0点として計算され、比較結果を歪める |
| `ELSE NULL`（推奨） | AVGがNULLを返し、その集合は比較から自然に除外される |

### 11.2 データの歯抜け・欠番検出

連番であるべき列に欠番がないかは、「行数」と「値の範囲」を比較するだけで判定できる。

```sql
-- 欠番があれば1行返る（1から始まる連番が前提）
SELECT '歯抜けあり' AS gap
FROM seq_tbl
HAVING COUNT(*) <> MAX(seq);

-- 発展版: 開始値が1でなくても連続性だけを判定する
SELECT '歯抜けあり' AS gap
FROM seq_tbl
HAVING COUNT(*) <> MAX(seq) - MIN(seq) + 1;
```

欠番の最小値がほしい場合は、「自分の値+1がテーブルに存在しない行」を `NOT EXISTS`（NULL安全なため `NOT IN` より推奨）で検索する。列にNULLが含まれる場合はこの前提が崩れるため、事前にNULLを除外しておく。

### 11.3 最頻値（mode）

外れ値の影響を受けやすい平均値の代わりに、最頻値（母集団内で最も出現数が多い値）を集合操作で求められる。

```sql
-- 極値関数版（ALL述語より可搬性が高い）
SELECT income, COUNT(*) AS cnt
FROM graduates
GROUP BY income
HAVING COUNT(*) >= (
    SELECT MAX(cnt) FROM (SELECT COUNT(*) AS cnt FROM graduates GROUP BY income) AS t
);
```

### 11.4 NULLを含まない集合の判定

`COUNT(*)`（NULLも含めて数える）と `COUNT(列)`（NULLを除外して数える）が一致するかどうかで、その集合にNULLが1件も含まれないかを判定できる。

```sql
-- 全員が提出済みの学部を選択（提出日がNULLの学生が1人もいない）
SELECT dept
FROM students
GROUP BY dept
HAVING COUNT(*) = COUNT(submit_date);
```

### 11.5 全称量化（「すべての要素が条件を満たす」）

「すべてのメンバーが条件Xを満たす」は、「Xを満たさないメンバーが1人も存在しない」という二重否定（`NOT EXISTS`）で書けるほか、HAVING句でも表現できる。

```sql
-- NOT EXISTS版: 個々のメンバーを表示できるが二重否定でやや読みにくい
SELECT team_id, member
FROM teams AS t1
WHERE NOT EXISTS (
    SELECT * FROM teams AS t2
    WHERE t1.team_id = t2.team_id AND status <> '待機'
);

-- HAVING版: 素直な肯定文で読みやすい（特性関数の応用）
SELECT team_id
FROM teams
GROUP BY team_id
HAVING COUNT(*) = SUM(CASE WHEN status = '待機' THEN 1 ELSE 0 END);

-- 別解: 集合内の値が1種類しかないことを MAX = MIN で判定
SELECT team_id
FROM teams
GROUP BY team_id
HAVING MAX(status) = '待機' AND MIN(status) = '待機';
```

| 手法 | 利点 | 欠点 |
|------|------|------|
| `NOT EXISTS` | 条件を満たさない個々の行を特定できる。情報量が多い | 二重否定で直感的に読みにくい |
| `HAVING COUNT(*) = SUM(CASE ...)` | 肯定文で読みやすい。集合単位の判定に自然 | 個々の行の詳細は失われる |
| `HAVING MAX(col) = MIN(col)` | 値の種類数チェックとして簡潔。列にインデックスがあれば高速なことがある | 値が3種類以上ある場合に狙った値との一致を別途確認する必要がある |

### 11.6 多重集合と重複検出

リレーショナルデータベースが扱う集合は重複を許す多重集合である。重複除去した個数（`COUNT(DISTINCT col)`）と重複を許した個数（`COUNT(col)`）を比較すれば、その集合に重複が存在するかを判定できる。

```sql
-- 同じ資材が複数回搬入されている（ダブついている）拠点を検索
SELECT center
FROM materials
GROUP BY center
HAVING COUNT(material) <> COUNT(DISTINCT material);
```

## 12. 関係除算とバスケット解析

「ある店舗が商品マスタの全商品を扱っているか」のように、複数行にまたがる条件（＝集合に対する条件）は、WHERE句のIN/ORでは表現できない。IN述語は「1つでも当てはまれば真」になるだけで、「すべて当てはまる」ことを保証しない。

```sql
-- 誤り: 1品でも置いていれば選ばれてしまう
SELECT DISTINCT shop FROM shop_items WHERE item IN (SELECT item FROM items);

-- 正しい（剰余ありの関係除算）: 結合後の行数がItemsの行数と一致する店舗を選ぶ
SELECT si.shop
FROM shop_items AS si
JOIN items AS i ON si.item = i.item
GROUP BY si.shop
HAVING COUNT(si.item) = (SELECT COUNT(*) FROM items);
```

「商品マスタにない商品を扱っている店舗」まで除外する厳密な関係除算には、外部結合と両方向のCOUNT比較を使う。

```sql
-- 厳密な関係除算: 過不足なく一致する店舗のみ
SELECT si.shop
FROM shop_items AS si
LEFT JOIN items AS i ON si.item = i.item
GROUP BY si.shop
HAVING COUNT(si.item) = (SELECT COUNT(*) FROM items)   -- 店舗側に不足がない
   AND COUNT(i.item)  = (SELECT COUNT(*) FROM items);  -- 店舗側に余分がない
```

| 除算の種類 | 条件 | 用途 |
|-----------|------|------|
| 剰余ありの関係除算 | 内部結合 + `COUNT(結合列) = 除数の行数` | 「必須商品セットを含んでいるか」だけを見たい（余分な商品があってもよい） |
| 厳密な関係除算 | 外部結合 + 両方向のCOUNT比較 | 「必須商品セットと過不足なく一致するか」まで見たい |

関係除算は、同時に複数の薬を併用している患者の検索や、複数の技術要件をすべて満たす人材の検索など、バスケット解析以外の業務にも同じ形で応用できる。

## 13. 記述統計量の算出

代表値（平均・中央値・最頻値）の算出は11.3および`WINDOW-FUNCTIONS.md`の中央値算出を参照。本節では代表値ではなく、**ばらつき・関係性・分布**を測る統計量を扱う。

### 13.1 分散と標準偏差

分散・標準偏差には母集団（除数がN）と標本（除数がN-1）の2種類があり、対象データが母集団そのものか標本かで使い分ける。

| 関数 | 意味 | 除数 |
|------|------|------|
| `VAR_POP` / `STDDEV_POP` | 母集団の分散・標準偏差 | N |
| `VAR_SAMP` / `STDDEV_SAMP` | 標本の分散・標準偏差（不偏推定） | N-1 |

```sql
SELECT VAR_POP(score)    AS variance_pop,
       STDDEV_POP(score) AS stddev_pop
FROM exam_results;
```

これらの集約関数を持たないDBMSでは、分散の定義式（二乗の平均 − 平均の二乗）から手計算できる。

```sql
-- STDDEV_POP非対応DBMSでの代替式
SELECT AVG(score * score) - AVG(score) * AVG(score) AS variance_pop
FROM exam_results;
```

数値型の丸め誤差など精度に関する注意点は`lang:developing-databases`のラウンディングエラーに関する記述を参照（本節では再解説しない）。

### 13.2 標準化（Zスコア）と偏差値

平均・標準偏差はいずれもウィンドウ関数として1パスで取得できるため、行ごとの標準化もサブクエリなしで書ける。標準偏差が0（全行が同じ値）の集合ではゼロ除算が発生するため`NULLIF`で回避する。

```sql
-- Zスコアと偏差値（1パス・標準偏差0をNULLIFで回避）
SELECT student_id, score,
       (score - AVG(score) OVER ()) / NULLIF(STDDEV_POP(score) OVER (), 0)          AS z_score,
       (score - AVG(score) OVER ()) / NULLIF(STDDEV_POP(score) OVER (), 0) * 10 + 50 AS deviation_value
FROM exam_results;
```

ウィンドウ関数そのものの構文（フレーム句・PARTITION BYの詳細）は`WINDOW-FUNCTIONS.md`を参照。

### 13.3 度数分布表（ビン分割）

CASE式で任意幅のビンに区切りGROUP BYで集計すれば度数分布表が得られる。等幅ビンは`FLOOR((x - min) / width)`で算術的に生成できる。

```sql
-- 得点を10点刻みのビンに分けて度数分布表を作る
SELECT FLOOR(score / 10) * 10 AS bin_start,
       COUNT(*)               AS freq
FROM exam_results
GROUP BY FLOOR(score / 10) * 10
ORDER BY bin_start;
```

累積度数は`SUM(...) OVER (ORDER BY bin_start)`、全体比による相対度数は`COUNT(*) OVER ()`との比較で算出する。

該当行が1件もないビンはGROUP BYの結果自体に現れないため、そのままでは度数分布表に「穴」が空く（空ビン問題）。ビンの一覧を持つマスタ表との外部結合で解決する手法は`JOINS-AND-SUBQUERIES.md`のタリーテーブルに関する節を参照。

### 13.4 相関係数と共分散

2つの数値列の関係性を測るピアソンの積率相関係数は`CORR`、共分散は`COVAR_POP`/`COVAR_SAMP`で算出する。

```sql
SELECT CORR(height, weight)      AS correlation,
       COVAR_POP(height, weight) AS covariance_pop
FROM measurements;
```

これらを持たないDBMSでは、共分散の定義式（積の平均 − 平均の積）から手計算できる。

```sql
-- COVAR_POP非対応DBMSでの代替式
SELECT AVG(height * weight) - AVG(height) * AVG(weight) AS covariance_pop
FROM measurements;
```

### 13.5 調和平均・幾何平均

算術平均が適さない場面（比率の平均・成長率の平均）では幾何平均・調和平均を使う。いずれも定義域の制約があるため、対象データが制約を満たすかを事前に確認する。

| 種類 | 算出式 | 定義域の制約 |
|------|--------|------------|
| 幾何平均 | `EXP(AVG(LN(x)))` | `x > 0`（0・負値が混入するとLNがエラーまたはNULLになる） |
| 調和平均 | `COUNT(*) / SUM(1.0 / x)` | `x <> 0`（0が混入するとゼロ除算） |

```sql
-- 年ごとの成長率（倍率）から幾何平均成長率を求める
SELECT EXP(AVG(LN(growth_ratio))) AS geometric_mean_growth
FROM yearly_growth
WHERE growth_ratio > 0;
```

### 13.6 外れ値の検出（IQR法）

四分位数からIQR（四分位範囲）= Q3 − Q1を求め、`Q1 - 1.5 * IQR`未満または`Q3 + 1.5 * IQR`超をCASE式で外れ値としてフラグ付けする。

```sql
-- IQR法による外れ値フラグ付け（標準SQL構文: PERCENTILE_CONT ... WITHIN GROUP）
WITH quartiles AS (
    SELECT PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY score) AS q1,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY score) AS q3
    FROM exam_results
)
SELECT e.student_id, e.score,
       CASE WHEN e.score < q.q1 - 1.5 * (q.q3 - q.q1)
              OR e.score > q.q3 + 1.5 * (q.q3 - q.q1)
            THEN 'outlier' ELSE 'normal' END AS outlier_flag
FROM exam_results AS e
CROSS JOIN quartiles AS q;
```

四分位数の算出関数（`PERCENTILE_CONT`の呼び出し形式）はDBMSごとに異なるため（標準SQLの`WITHIN GROUP`集約関数形式とBigQueryの`OVER()`ウィンドウ関数形式等）、13.7の方言対応表と対象DBMSのドキュメントで確認する。集約関数がNULLを自動的に除外する挙動（`AVG`の分母が実質`COUNT(col)`になる）は、特性関数でCASE式のELSEをNULLにするかゼロにするかの使い分けと同根の注意点であり、対象列にNULLが混在していないか確認する。

### 13.7 統計関数の方言対応表

| 関数 | 用途 | 備考 |
|------|------|------|
| `STDDEV_POP` / `STDDEV_SAMP` | 標準偏差 | 主要DBMSで広くサポート |
| `VAR_POP` / `VAR_SAMP` | 分散 | 主要DBMSで広くサポート |
| `CORR` | 相関係数 | 対応状況がDBMSごとに分かれる |
| `COVAR_POP` / `COVAR_SAMP` | 共分散 | 対応状況がDBMSごとに分かれる |
| `PERCENTILE_CONT` | 四分位数・パーセンタイル | 引数順序・`WITHIN GROUP`構文の要否がDBMSごとに異なる |

非対応の関数は13.1・13.4で示した手計算式のような代替式に置き換える。対応状況は対象DBMSのドキュメントで必ず確認する（15節のBigQuery実務ノートとは扱う粒度が異なり、あちらはCASE/IFの構文選択、こちらは統計関数自体の可用性を扱う）。

## 14. 実務定型分析パターン（RFM分析・ABC分析）

分散や相関のような統計量ではなく、CASE式による顧客・商品のランク分類を中心とした、業務で頻出する定型分析パターンを扱う。

### 14.1 RFM分析

Recency（直近の購買からの経過日数）・Frequency（購買回数）・Monetary（購買金額）の3軸から顧客をスコア化し、優良顧客・休眠顧客等のセグメントに分類する手法。各軸を`NTILE(5)`で5段階にスコア化し、スコアの組み合わせをCASE式でセグメント名に変換する。

```sql
-- 顧客ごとのRFMスコアを算出する
WITH rfm AS (
    SELECT customer_id,
           NTILE(5) OVER (ORDER BY DATE_DIFF(@as_of_date, MAX(order_date), DAY) ASC) AS r_score,
           NTILE(5) OVER (ORDER BY COUNT(*) DESC)                                    AS f_score,
           NTILE(5) OVER (ORDER BY SUM(order_total) DESC)                            AS m_score
    FROM orders
    WHERE order_date <= @as_of_date
    GROUP BY customer_id
)
SELECT customer_id,
       CASE WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN '優良顧客'
            WHEN r_score <= 2 AND f_score <= 2                  THEN '休眠顧客'
            ELSE '一般顧客' END AS segment
FROM rfm;
```

基準日（Recency算出の起点）は`CURRENT_DATE`を直書きせず、呼び出し側から渡すパラメータとして必ず外挿する（プレースホルダの構文は`@as_of_date`・`?`・`:as_of_date`等、DBMS・ドライバごとに異なる）。直書きするとクエリを再実行するたびにRecencyの値が変わり、同じ入力に対して同じ結果が返らない（冪等性が損なわれる）。日付差分を求める関数（`DATE_DIFF`等）は方言差が大きいため、対象DBMSの構文を確認する。

### 14.2 ABC分析

売上等を降順ソートし、累積和ウィンドウ関数で累積構成比を求め、閾値（例: 累積70%までをA、90%までをB、残りをC）でランク分類する手法。

```sql
-- 商品を売上降順で並べ、累積構成比からA/B/Cランクを付与する
WITH ranked AS (
    SELECT product_id, sales,
           SUM(sales) OVER (ORDER BY sales DESC, product_id
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(sales) OVER () AS cumulative_ratio
    FROM product_sales
)
SELECT product_id, sales,
       CASE WHEN cumulative_ratio <= 0.70 THEN 'A'
            WHEN cumulative_ratio <= 0.90 THEN 'B'
            ELSE 'C' END AS abc_rank
FROM ranked
ORDER BY sales DESC;
```

`ORDER BY sales DESC`だけでは同じ売上高の商品が複数あるとき順位が非決定的になり、実行のたびに累積和の途中経過（ひいてはランク境界）が変わりうる。`product_id`のような一意キーを`ORDER BY`に追加し、順序を確定させる。

### 14.3 デシル分析との関係

RFM分析・ABC分析はいずれも「対象を層に分けて優先順位付けする」という点で、`WINDOW-FUNCTIONS.md`のデシル分析と同じ系統の定型分析パターンである。デシル分析が単一の指標（例: 購買金額）を10等分するのに対し、RFM分析は複数指標の組み合わせでセグメント化する点が異なる。単一指標での層別だけで十分な場合は`WINDOW-FUNCTIONS.md`のデシル分析節を参照。

## 15. BigQuery実務ノート（方言差のまとめ）

BigQueryは標準SQLの集計関数（`COUNT`・`SUM`・`AVG`・`MAX`・`MIN`）に加え、`STDDEV_POP`・`STDDEV_SAMP` などの統計集計関数を持つ。2値分岐には `IF(条件式, 真の場合, 偽の場合)` 関数も使える。

| 状況 | 使うべき構文 |
|------|------------|
| 2分岐で単純な条件（等価・IS NULL・AND/OR） | `IF(cond, then_val, else_val)`（可読性重視ならCASE式でもよい） |
| 3分岐以上、または特定の値との等価判定 | 単純CASE式（`CASE col WHEN v1 THEN ... END`） |
| 「以上/以下」「BETWEEN」など値の範囲で分岐 | 検索CASE式（`CASE WHEN col >= v THEN ... END`） |

検索CASE式で範囲による年代分類などを行う際、WHEN句は上から順に評価され最初に真になった時点で確定するため、**範囲が広い条件を先に書くと、後続のより狭い条件に永遠に到達しない**。年代・金額帯のような段階的な閾値は、境界が厳しい順（新しい年→古い年、大きい値→小さい値）に並べる。

```sql
-- 誤り: 1980年以降の条件が1990年以降より先に真になり、1990年代生まれが誤分類される
CASE WHEN birthday >= '2000-01-01' THEN '2000年代'
     WHEN birthday >= '1980-01-01' THEN '1980年代'   -- 1990年代の行もここで拾われてしまう
     WHEN birthday >= '1990-01-01' THEN '1990年代'   -- 到達しない
     ELSE '1970年代以前' END

-- 正しい: 新しい年から古い年の順に並べる
CASE WHEN birthday >= '2000-01-01' THEN '2000年代'
     WHEN birthday >= '1990-01-01' THEN '1990年代'
     WHEN birthday >= '1980-01-01' THEN '1980年代'
     ELSE '1970年代以前' END
```

BigQueryの実行順序もSELECT文の論理評価順序（6.1節）に従うため、`WHERE` 句で `SELECT` 句の集計結果の別名を参照するとエラーになる。集計結果を条件にしたい場合は必ず `HAVING` 句を使う。対象DBMSがBigQuery以外か不明な場合は、日付関数・LIMIT構文・NULLソート順の違いも影響するため、`SKILL.md` のAskUserQuestion指針に従って対象DBMSを確認する。
