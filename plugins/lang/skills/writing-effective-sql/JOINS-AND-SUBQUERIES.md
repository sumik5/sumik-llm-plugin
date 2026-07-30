# 結合とサブクエリ

[← SKILL.md に戻る](SKILL.md)

複数テーブルからデータを取り出す2大手段である「結合（JOIN）」と「サブクエリ」を扱う。両者は機能的に重なる場面が多く、同じ結果を結合でもサブクエリでも書けることが少なくない。本ファイルは、結合の種類ごとの正しい使い分け、サブクエリの種類と相関/非相関の違い、両者を選ぶ判断基準、そして直積・タリーテーブル・外部結合pivot・階層クエリといった応用技法をまとめる。

正規化・ER設計・キー設計そのものの妥当性については `lang:developing-databases` を参照。本ファイルは「テーブルが与えられた前提でどう問い合わせるか」に専念する。

## 結合の基礎と種類

SQLの結合は、関係代数の「結合」「交差」「直積」「和」「差」といった集合演算をキーで実装したものである。まず全体像を判断基準テーブルで押さえる。

| 結合の種類 | 動作 | 主な用途 |
|-----------|------|---------|
| CROSS JOIN（直積） | 両テーブルの全レコードをすべての組み合わせで掛け合わせる（行数 = 行数A × 行数B） | 総当たり組み合わせ生成、タリーテーブルとの掛け合わせ |
| INNER JOIN（内部結合） | 結合条件が一致する行だけを残す | もっとも一般的な用途。結合結果は常にCROSS JOINの部分集合になる |
| LEFT/RIGHT OUTER JOIN（外部結合） | 片方のテーブルの全行を保持し、一致しない場合は反対側をNULLで埋める | 「マスタは全件出したいが詳細は無くてもよい」場合、欠落レコード検出 |
| FULL OUTER JOIN（完全外部結合） | 両テーブルの全行を情報欠落なく保持する | 両テーブルとも「マスタ」として扱いたい場合、和集合の取得 |
| 自己結合（self join） | 同一テーブルに別名を与えて結合する | 行間比較、順列・組み合わせ生成、階層探索 |

自己結合には専用の構文があるわけではなく、同じテーブルに異なる別名（エイリアス）を与えて `INNER JOIN`/`LEFT JOIN` を使うだけでよい。SQL上は「たまたま保持するデータが同じだった2つの異なる集合」を結合していると考えれば動作が理解しやすい。「自己」という接頭辞に特別な演算上の意味はなく、内部結合・外部結合・クロス結合のいずれとも自由に組み合わせられる（例: 自己非等値結合、自己クロス結合）。

自然結合（`NATURAL JOIN`）や `USING` 句は、同名列を暗黙に等値結合できて記述は短くなるが、テーブル定義を知らないと結合条件が読み取れず可読性が落ちる、列名やデータ型が食い違うと使えないといった制約がある。特殊な事情がない限り `ON` 句を明示する内部結合を基本形にする。

```sql
-- 古い構文（FROM句にカンマ区切り）は「結合条件の書き忘れ」を
-- 構文エラーで検出できないため避ける
SELECT e.emp_id, d.dept_name
FROM Employees e, Departments d
WHERE e.dept_id = d.dept_id;  -- WHEREを書き忘れると意図せぬCROSS JOINになる

-- 標準SQLのJOIN構文なら、結合条件を書き忘れた時点で構文エラーになる
SELECT e.emp_id, d.dept_name
FROM Employees e
INNER JOIN Departments d
   ON e.dept_id = d.dept_id;
```

| If X | Then Y |
|------|--------|
| 3つ以上のテーブルを結合する | `JOIN ... ON ...` を必要なテーブル数分チェーンする。結合列名が全テーブルで揃っているなら `USING` の連鎖でも書けるが、条件文の可読性は `ON` の方が高い |
| 複数列で結合する | `ON t1.col_a = t2.col_a AND t1.col_b = t2.col_b` のように `AND` で連結する |
| 結合キーの列名がテーブル間で異なる | `USING` は使えないため `ON` 句を使う |

## 結合アルゴリズムの基礎知識

結合のパフォーマンスはDBMSが選ぶ内部アルゴリズムに左右される。深い実行計画の読み方は `PERFORMANCE-REWRITING.md` に譲り、ここではクエリの書き方に直結する要点だけを押さえる。

| アルゴリズム | 得意な場面 | 弱点 |
|------------|-----------|------|
| Nested Loops（多重ループ） | 片方のテーブルが小さく、もう片方の結合キーにインデックスがある | 内部表へのヒット件数が多いと極端に遅くなる |
| Hash | 適切な駆動表がなく、両テーブルとも大きい場合 | ハッシュテーブル構築にメモリを消費し、等値結合にしか使えない |
| Sort Merge | 結合キーで既にソート済み、または不等号結合が必要な場合 | ソートコストが高い |

覚えておくべき経験則は次の2つである。

- 「駆動表を小さく、内部表の結合キーにインデックスを張る」という組み合わせが最も基本的なチューニングであり、これだけで結合の性能問題の多くが解決する。
- 3つ以上のテーブルを結合し、かつ一部のテーブル間に結合条件が存在しない場合（三角結合）、オプティマイザが結合条件のない2テーブルをクロス結合してから残りと結合する実行計画を選ぶことがある。テーブルが小さければ問題にならないが、大きなテーブル同士だと危険なので、可能なら（結果に影響しない範囲で）冗長な結合条件を追加して選択肢を狭める。

結合アルゴリズムは複数存在するがゆえに、データ量の増加に伴って実行計画が変動しやすい。長期的な性能の安定性を重視するなら、そもそも結合そのものを減らす方向（ウィンドウ関数への置き換えなど）を検討する価値がある。詳細は `WINDOW-FUNCTIONS.md` と `PERFORMANCE-REWRITING.md` を参照。

## 左外部結合を正しく書く

LEFT OUTER JOINは「右側テーブルにフィルターをかけたい」場面で最も間違えやすい。典型的な誤りと正解を示す。

**やりたいこと**: 全顧客を表示し、直近四半期に注文していればその注文も表示する（注文がない顧客も消さない）。

```sql
-- ❌ 誤り: WHERE句で右側テーブルの列を条件にすると、
-- 実質的にINNER JOINと同じ結果になってしまう
SELECT c.customer_id, o.order_id, o.order_date
FROM Customers c
LEFT JOIN Orders o
       ON c.customer_id = o.customer_id
WHERE o.order_date BETWEEN '2015-10-01' AND '2015-12-31';
-- 注文がない顧客は o.order_date が NULL なので、
-- BETWEEN 条件がunknownとなり行ごと消えてしまう

-- ✅ 正しい: 右側（差し引かれる側）を先にフィルタしてから結合する
SELECT c.customer_id, of.order_id, of.order_date
FROM Customers c
LEFT JOIN (
    SELECT order_id, customer_id, order_date
    FROM Orders
    WHERE order_date BETWEEN '2015-10-01' AND '2015-12-31'
) AS of
       ON c.customer_id = of.customer_id;
```

データベースエンジンはFROM句→WHERE句→SELECT句の順に処理する。`LEFT JOIN` 自体は左側の全行を保持するが、外側の `WHERE` 句で右側の列にNULL以外の条件をかけると、注文がない顧客の行（右側がNULL）はその時点で弾かれてしまう。正しくは、右側テーブルを先にフィルタ済みの派生テーブル（サブクエリ）にしてから結合する。

| If X | Then Y |
|------|--------|
| LEFT JOINの右側テーブルに条件を付けたいが、右側が存在しない行（NULL）も残したい | 条件はJOINより前（派生テーブル/サブクエリ内、または `ON` 句）に書く。外側の `WHERE` に書かない |
| LEFT JOINの右側テーブルが存在する行だけに絞りたい（実質INNER JOINでよい） | 外側の `WHERE` に書いてよい（意図した絞り込みになる） |

確認不要な場面: NULL値を含む比較の挙動そのもの（`= NULL` が常にunknownになる等）は一義的に決まる仕様であり、AskUserQuestionは不要。詳細は `FOUNDATIONS-AND-NULL.md` を参照。

## 欠落レコード・不一致レコードの検索

「存在しないデータ」を探す代表的な3手法を比較する。

```sql
-- 方法1: NOT IN（理解しやすいが、サブクエリ結果にNULLが混じると
-- 結果が空になる罠があり、実行コストも高くなりがち）
SELECT p.product_id, p.product_name
FROM Products p
WHERE p.product_id NOT IN (SELECT product_id FROM Order_Details);

-- 方法2: NOT EXISTS（最初の1行が見つかった時点で判定を打ち切れるため、
-- 多くのDBMSで最も効率がよい）
SELECT p.product_id, p.product_name
FROM Products p
WHERE NOT EXISTS (
    SELECT 1 FROM Order_Details od WHERE od.product_id = p.product_id
);

-- 方法3: 「挫折結合」（LEFT JOIN + IS NULL）
SELECT p.product_id, p.product_name
FROM Products p
LEFT JOIN Order_Details od ON p.product_id = od.product_id
WHERE od.product_id IS NULL;
```

| 手法 | 長所 | 短所 |
|------|------|------|
| `NOT IN` | もっとも直感的で読みやすい | サブクエリの結果に1件でもNULLが含まれると、比較結果がすべてunknownになり0件になる。サブクエリの列にNOT NULL制約がない限り避ける |
| `NOT EXISTS` | NULLの影響を受けない。オプティマイザが「半結合（anti-join）」に最適化しやすい | 相関サブクエリの形になるため、結合キーにインデックスがないと遅くなることがある |
| `LEFT JOIN` + `IS NULL`（挫折結合） | 実務上非常に高速なことが多い | DBMSによって最適化の癖が異なる。読み手に「差集合を取っている」という意図が伝わりにくい |

どれが最速かはDBMS・データ分布・インデックスの有無に依存するため、パフォーマンスが重要な場面では実測して選ぶ。ただし **`NOT IN` はサブクエリ側の列がNULLを含みうる場合は使わない**（一義的な注意点であり確認不要）。

## 自己結合の応用

自己結合と非等値結合（`<`, `>`, `<>`）を組み合わせると、単純な等値結合では書けない技法が実現できる。

**重複順列・順列・組み合わせの生成**

| 欲しいもの | 結合条件 | 結果行数（要素数N） |
|-----------|---------|-------------------|
| 重複順列（順序あり・重複あり） | `CROSS JOIN`（条件なし） | N² |
| 順列（順序あり・重複なし） | `ON t1.key <> t2.key` | N×(N-1) |
| 組み合わせ（順序なし・重複なし） | `ON t1.key > t2.key`（片方向の不等号） | N×(N-1)/2 |

```sql
-- 組み合わせ（同一要素・順序違いのペアを両方とも除外）
SELECT p1.name AS name_1, p2.name AS name_2
FROM Products p1
INNER JOIN Products p2
        ON p1.name > p2.name;
```

不等号は数値型に限らず、文字列型（辞書順比較）や日付型のように順序を持つ型であれば同様に使える。

**重複行の削除**（自己相関サブクエリ、または自己非等値結合のいずれでも書ける）

```sql
DELETE FROM Products p1
 WHERE EXISTS (
     SELECT 1 FROM Products p2
      WHERE p1.name = p2.name
        AND p1.price = p2.price
        AND p1.rowid < p2.rowid   -- 実装依存の行識別子。DBMSにより代替手段が異なる
 );
```

**部分的に不一致なキーの検索**（本来一致すべき属性が食い違っているレコードの検出）

```sql
-- 同じ家族IDなのに住所が違うレコードを検出
SELECT DISTINCT a1.name, a1.address
FROM Addresses a1
INNER JOIN Addresses a2
        ON a1.family_id = a2.family_id
       AND a1.address <> a2.address;
```

自己結合と非等値結合の組み合わせは、ランキング算出（自分より大きい値を持つ行を数える）にも使えるが、現在の主要DBMSは `RANK()`/`DENSE_RANK()` ウィンドウ関数を提供しているため、新規に書く場合はそちらを優先する。詳細は `WINDOW-FUNCTIONS.md` を参照。

| If X | Then Y |
|------|--------|
| 自己結合の動作がイメージしにくい | 同じテーブルに別名を与えた時点で「たまたまデータが同じだった、名前の異なる2つの集合」として捉え直す（物理的には同一実体、論理的には別集合） |
| 順列・組み合わせのどちらが必要か迷う | 「AとBのペア」と「BとAのペア」を別物として数えたいなら順列（不等号 `<>`）、同じものとして数えたいなら組み合わせ（単方向の不等号 `>` または `<`） |

## サブクエリの種類と相関/非相関

サブクエリは返す形によって3種類に分類できる。

| 種類 | 返す形 | 使える場所 |
|------|--------|-----------|
| テーブルサブクエリ | 複数行・複数列 | テーブル名/ビュー名を書ける場所（`FROM` 句） |
| 単一列のテーブルサブクエリ | 複数行・単一列 | `IN`/`NOT IN` 述語の値リスト |
| スカラーサブクエリ | 0または1行・単一列 | 列名や式を書ける場所（`SELECT` 句、比較述語の右辺） |

サブクエリはさらに、外側のクエリの値に依存するかどうかで「相関」「非相関」に分かれる。

```sql
-- 非相関サブクエリ: 単独で実行できる
SELECT product_name
FROM Products
WHERE product_id NOT IN (
    SELECT product_id FROM Order_Details
    WHERE order_date BETWEEN '2015-12-01' AND '2015-12-31'
);

-- 相関サブクエリ: 外側のクエリの現在行（c.customer_id）に依存する
SELECT c.customer_id,
       (SELECT COUNT(*) FROM Orders o WHERE o.customer_id = c.customer_id) AS order_count
FROM Customers c;
```

相関サブクエリは「外側の行ごとに実行される」ため一般に非相関サブクエリより低コストに見えるが、必ずしも遅いとは限らない。多くのDBMSは `EXISTS` 述語の相関サブクエリを「半結合（semi-join）」として最適化し、通常のJOINと同等の実行計画に変換する。相関サブクエリでしか書けない要件（例: 行ごとに集計を1列だけ足したい）もあるため、「相関サブクエリ＝悪」という単純化はしない。

同じサブクエリを複数箇所で使い回す必要がある場合は、ネストしたサブクエリより CTE（`WITH` 句）の方が可読性が高い。CTEは上から順に読める点、複数箇所から再利用できる点が利点である。ただし再帰CTEで生成した連番列にはインデックスを作成できないため、大量データに対して繰り返し使うなら `TALLY テーブル` の方が効率的な場合がある（[タリーテーブルの活用](#タリーテーブルの活用)を参照）。

```sql
WITH SkateboardOrders AS (
    SELECT DISTINCT customer_id FROM Orders o
    INNER JOIN Order_Details od ON o.order_id = od.order_id
    WHERE od.product_name = 'Skateboard'
),
HelmetOrders AS (
    SELECT DISTINCT customer_id FROM Orders o
    INNER JOIN Order_Details od ON o.order_id = od.order_id
    WHERE od.product_name = 'Helmet'
)
SELECT c.customer_id
FROM Customers c
INNER JOIN SkateboardOrders sk ON c.customer_id = sk.customer_id
INNER JOIN HelmetOrders   he ON c.customer_id = he.customer_id;
```

## サブクエリの弱点と解消

サブクエリは実体を持たない一時的な結果であるため、①アクセスのたびにSELECT文を再計算するコスト、②結果を一時領域に書き出すI/Oコスト、③インデックスや制約の情報を持たずオプティマイザの最適化を受けにくい、という3つの弱点を抱える。特に「サブクエリを結合してから求める」パターンを重ねると、同じ元テーブルへのスキャン回数が増えていく。

```sql
-- ❌ サブクエリを結合して顧客ごとの最古の購入を求める
-- （Receiptsテーブルへのアクセスが実質2回発生する）
SELECT r1.cust_id, r1.seq, r1.price
FROM Receipts r1
INNER JOIN (
    SELECT cust_id, MIN(seq) AS min_seq FROM Receipts GROUP BY cust_id
) r2
        ON r1.cust_id = r2.cust_id AND r1.seq = r2.min_seq;

-- ✅ ウィンドウ関数で1回のスキャンに集約する
SELECT cust_id, seq, price
FROM (
    SELECT cust_id, seq, price,
           ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY seq) AS row_seq
    FROM Receipts
) w
WHERE w.row_seq = 1;
```

相関サブクエリで書き換えても（`WHERE seq = (SELECT MIN(seq) ... WHERE r1.cust_id = r2.cust_id)`）、実行計画上はテーブルへのアクセスが2回発生する点は変わらない。真の解決策は、結合そのものを無くしてスキャン回数を1回に減らすことであり、ウィンドウ関数がその代表的な手段になる。詳細は `WINDOW-FUNCTIONS.md` を参照。

**結合と集約の順序**も性能に影響する。結合してから集約するか、集約してから結合するかは機能的には同値でも、行数が大きく違う場合はパフォーマンスに差が出る。

```sql
-- 解1: 結合を先に行う（結合対象行数が事業所テーブル側の生行数のまま）
SELECT c.co_cd, MAX(c.district), SUM(s.emp_nbr) AS sum_emp
FROM Companies c
INNER JOIN Shops s ON c.co_cd = s.co_cd
WHERE s.main_flg = 'Y'
GROUP BY c.co_cd;

-- 解2: 集約を先に行う（結合対象行数を会社数まで先に絞ってから結合する）
SELECT c.co_cd, c.district, csum.sum_emp
FROM Companies c
INNER JOIN (
    SELECT co_cd, SUM(emp_nbr) AS sum_emp
    FROM Shops WHERE main_flg = 'Y' GROUP BY co_cd
) csum
        ON c.co_cd = csum.co_cd;
```

事業所テーブル側の行数が会社テーブルよりも桁違いに大きい場合、先に集約して結合対象の行数を会社数まで絞り込む解2の方が、結合コストを大きく削減できる可能性が高い。どちらが速いかはデータ量・インデックス・DBMSに依存するため、パフォーマンス上重要な箇所では実測して判断する。

## 結合・サブクエリ・EXISTSの判断基準

| 状況 | 推奨 | 理由 |
|------|------|------|
| 「テーブルBのある属性を条件にテーブルAを絞りたい」で、参照する列がAだけ | `EXISTS`（またはINNER JOIN） | サブクエリ全体の評価が不要になり、多くのオプティマイザが半結合に最適化する |
| Bの列も結果に含めたい | 結合（INNER/LEFT JOIN） | サブクエリでは列を追加するたびにSELECT句の書き換えが必要になる |
| 結合条件に使う側のテーブルにキーの重複がありうる | サブクエリ+`IN`/`EXISTS` | 結合すると重複による行の増殖が起きる可能性がある |
| 外部キーにNULLがあり得て、一致しない行も検索したい | LEFT JOIN + `IS NULL`評価（[欠落レコード・不一致レコードの検索](#欠落レコード不一致レコードの検索)参照） | サブクエリのみでは表現しづらい |
| 同じサブクエリを何度も参照する | CTE（`WITH`句） | 定義が1箇所にまとまり、上から順に読める |

## 直積（CROSS JOIN）の実務活用

直積は実務で単独使用されることは少ないが、「本来あり得るすべての組み合わせ」を人工的に生成する必要がある場面では不可欠な道具になる。

**未購入商品の検出**（全顧客×全商品の直積を作り、実際の購入とLEFT JOINする。内部結合だけでは「買った実績」しか出せない）

```sql
SELECT cp.customer_id, cp.product_id,
       CASE WHEN od.order_count > 0 THEN '購入済み' ELSE NULL END AS status
FROM (SELECT c.customer_id, p.product_id
        FROM Customers c CROSS JOIN Products p) cp
LEFT JOIN (
    SELECT customer_id, product_id, COUNT(*) AS order_count
    FROM Orders GROUP BY customer_id, product_id
) od ON cp.customer_id = od.customer_id AND cp.product_id = od.product_id;
```

**総当たり組み合わせの生成**（対戦表・商品ペア分析など）

```sql
-- 各チームが他の全チームと1回ずつ対戦する組み合わせ
SELECT t1.team_id AS team1, t2.team_id AS team2
FROM Teams t1
CROSS JOIN Teams t2
WHERE t2.team_id > t1.team_id;   -- 順序を無視した組み合わせに絞る
```

N個から2つを選ぶ組み合わせの数はN×(N-1)/2であり、大量のマスタデータに対してCROSS JOINを使うと爆発的に行数が増える点に注意する。関連するカテゴリやベンダーで事前に絞り込んでから使うのが実務的である。

**ランク付けバンド分割**（五分位・十分位などの相対順位）は、`RANK()` で順位を振ってから、`CROSS JOIN` で取得した「対象件数」を使い、順位÷件数の割合をCASE式で判定する。

| If X | Then Y |
|------|--------|
| 「あり得るすべての組み合わせ」に対して実績の有無を判定したい | CROSS JOIN + LEFT JOIN（[外部結合による行列変換](#外部結合による行列変換)の「掛け算としての結合」も参照） |
| 大量マスタ同士のCROSS JOINで行数が爆発しそう | 事前にカテゴリ/期間で絞り込んでから直積を作る |

## タリーテーブルの活用

タリーテーブル（tally table）は、1から連番が振られただけの単純なテーブルである。直積がベーステーブルの実データに依存するのに対し、タリーテーブルは「ベーステーブルに存在しない値も含めた、あり得る全範囲」を人工的に用意できる点が異なる。

| 用途 | やり方 |
|------|--------|
| 空行の生成（帳票のページ埋め等） | タリーテーブルの連番と `<=` で必要件数だけ空行をUNION ALLする |
| シーケンス/連番の生成 | 再帰CTEでも生成できるが、タリーテーブルの列にはインデックスが張れるため大量データでは有利 |
| 値の範囲→カテゴリ変換 | `ON value BETWEEN low AND high` の非等値結合で、数値の範囲をタリーテーブルの行（ラベル）に変換する |
| 日付テーブル（date dimension） | 日付ごとに1行を持つテーブルを作り、曜日名・週番号・四半期等を事前計算しておく。日付関数を毎回呼び出すより結合1発で済み、`sargable`（インデックスが効く）クエリになりやすい |
| ピボット選択 | 列見出しにしたい値ごとに0/1のフラグを持つタリーテーブルを直積し、`SUM(値 * フラグ)` で該当列に集計値を配置する |

```sql
-- 数値の範囲をレターグレードに変換する（非等値結合）
SELECT sg.student, sg.subject, sg.final_grade, gr.letter_grade
FROM StudentGrades sg
INNER JOIN GradeRanges gr
        ON sg.final_grade >= gr.low_grade_point
       AND sg.final_grade <= gr.high_grade_point;
```

日付テーブルはめったに更新されないディメンションテーブルであるため、必要なだけインデックスを作成してよい。ディスクI/Oと引き換えにCPU計算（複雑な日付関数呼び出し）を減らせるかどうかは、日付演算の頻度とデータ量に応じて判断する。

| If X | Then Y |
|------|--------|
| 範囲変換に使うタリーテーブルを設計する | 考えられる値の範囲を漏れなくカバーする。範囲外の値が来た場合の扱い（CHECK制約で弾く／「無効な値」の行を用意する）を決めておく |
| 一度きりの集計でよい | CTE + CASE式で十分。恒久的に使う・再利用する見込みがあるならタリーテーブルの方が保守しやすい |

## 外部結合による行列変換

SQLは本来データ検索のための言語であり、帳票のような「行列変換（ピボット/アンピボット）」は得意分野ではないが、外部結合とCASE式を組み合わせれば十分に実現できる。

**行→列（クロス表化・ピボット）**: マスタとなる集合を表側にして、列見出しごとにフィルタ済みの集合をLEFT OUTER JOINするか、スカラーサブクエリを使う。

```sql
-- 受講者マスタ（C0）に対して、講座ごとにフィルタした集合を左外部結合する
SELECT c0.name,
       CASE WHEN c1.name IS NOT NULL THEN '○' ELSE NULL END AS course_a,
       CASE WHEN c2.name IS NOT NULL THEN '○' ELSE NULL END AS course_b
FROM (SELECT DISTINCT name FROM Courses) c0
LEFT JOIN (SELECT name FROM Courses WHERE course = 'A') c1 ON c0.name = c1.name
LEFT JOIN (SELECT name FROM Courses WHERE course = 'B') c2 ON c0.name = c2.name;
```

同じ結果はスカラーサブクエリでも、`SUM(CASE WHEN ... THEN 1 ELSE NULL END)` を使った集約+CASEの入れ子でも書ける。列の増減が多いなら「列を増やすたびにFROM句とSELECT句の両方を直す」外部結合方式より、SELECT句だけ直せばよいスカラーサブクエリ方式の方が保守しやすい。パフォーマンスは外部結合方式が有利なことが多い。

**列→行（繰り返し項目の展開）**: `UNION ALL` で縦に並べ替える。値が存在しない行も残したい場合は、値の一覧をマスタ化してからLEFT JOINする（外部結合で行→列の変換と対になる考え方）。

**入れ子の表側（複数の軸を表側にする）**: 表側にしたい軸同士を先にCROSS JOINして直積のマスタを作り、そのマスタに対して外部結合を1回だけ行う。表側マスタに外部結合を2回繰り返すと、1回目の結合で発生したNULLが2回目のON条件を満たせず、行が消えてしまう罠があるので注意する。

```sql
-- 年齢階級マスタ × 性別マスタの直積を先に作ってから、集計データと1回だけ外部結合する
SELECT master.age_class, master.sex_cd, data.pop_tohoku, data.pop_kanto
FROM (SELECT age_class, sex_cd FROM AgeMaster CROSS JOIN SexMaster) master
LEFT JOIN (
    SELECT age_class, sex_cd,
           SUM(CASE WHEN pref_name IN ('青森', '秋田') THEN population END) AS pop_tohoku,
           SUM(CASE WHEN pref_name IN ('東京', '千葉') THEN population END) AS pop_kanto
    FROM PopulationTable GROUP BY age_class, sex_cd
) data ON master.age_class = data.age_class AND master.sex_cd = data.sex_cd;
```

**掛け算としての結合**: 結合の行数は掛け算に相当する（一対一なら行数は増えず、一対多なら増える）。マスタとトランザクションを結合してから集約すると、事前にトランザクション側だけを集約する場合よりコードは短くなるが、片方が1対1でなく1対多の関係であれば、集約と結合の順序を入れ替えても結果の行数は変わらない（1を掛けても変わらないのと同じ理屈）。この性質を使うと、中間ビューを作らずに直接 `LEFT JOIN` + `GROUP BY` で書ける。

```sql
SELECT i.item_no, SUM(sh.quantity) AS total_qty
FROM Items i
LEFT JOIN SalesHistory sh ON i.item_no = sh.item_no  -- 一対多の結合
GROUP BY i.item_no;
```

**完全外部結合と集合演算**: 内部結合は積集合（INTERSECT）に、完全外部結合は和集合（UNION）に対応すると考えると理解しやすい。完全外部結合の結果に対してNULL判定を加えることで、差集合や排他的和集合も表現できる。

| 求めたい集合演算 | 外部結合での書き方 |
|-----------------|-------------------|
| 和集合（A∪B） | `FULL OUTER JOIN` してそのまま出力する |
| 差集合（A－B） | `A LEFT JOIN B ON ... WHERE b.key IS NULL` |
| 排他的和集合（A△B） | `FULL OUTER JOIN` の結果に `WHERE a.col IS NULL OR b.col IS NULL` を付ける |

`EXCEPT`/`INTERSECT` を実装していないDBMSでの代替手段として、または実行速度面で有利な選択肢として覚えておく価値がある。関係除算（HAVING句を使う本来の書き方）は `CASE-AND-AGGREGATION.md` に譲るが、外部結合の差集合を応用した以下のような書き方もできることだけ触れておく。

```sql
-- 店舗ごとの取扱商品が、商品マスタの全商品をカバーしているかを
-- 「差集合が空かどうか」で判定する（関係除算の外部結合版）
SELECT DISTINCT si1.shop
FROM ShopItems si1
WHERE NOT EXISTS (
    SELECT i.item
    FROM Items i
    LEFT JOIN ShopItems si2
           ON i.item = si2.item AND si1.shop = si2.shop
    WHERE si2.item IS NULL
);
```

外部結合の構文は方言差が大きい部分でもある。可読性と移植性のため、`(+)` や `*=` のようなベンダー独自構文は避け、標準SQLの `LEFT/RIGHT/FULL OUTER JOIN` を省略せずに書く。

## 階層型データモデルのクエリ

自己参照する親子関係（組織図、カテゴリツリーなど）をリレーショナルモデルで扱う場合、正規化の度合いとクエリの速さ・検索方向の自由度はトレードオフになる。4つのモデルを比較する。

| モデル | メタデータ | 更新の容易さ | 子孫/祖先検索 | 適した場面 |
|--------|-----------|------------|--------------|-----------|
| 隣接リスト（自己参照FK） | なし（正規化を崩さない唯一の方式） | 非常に容易（1行のUPDATEで済む） | 固定深さのみ現実的（自己結合を深さの分だけ重ねる） | 常に併用すべき出発点。他モデルの再構築元にする |
| 入れ子集合（nested set） | 各行に「左」「右」の2値 | 困難（1件の移動で他の多くの行の番号を更新） | 高速（範囲比較1回で子孫/祖先を取得） | 更新が稀（年数回）で、検索速度を優先したい単一ルートの階層 |
| 経路実体化（materialized path） | 各行にルートからのパス文字列 | 中程度 | 子孫検索は`LIKE 'path%'`でsargable。祖先検索はsargableでない | ファイルシステム的な理解しやすさを優先したい場合 |
| クロージャテーブル | 別テーブルに全ノード間の関係を距離付きで格納 | 複雑（関係変更で複数行の挿入/削除が必要） | 子孫・祖先とも高速でsargable。深さ制限も容易 | 複雑な検索・頻繁な更新の両方が必要な場合 |

```sql
-- 隣接リスト: 固定3階層の自己結合
SELECT e1.emp_name AS employee, e2.emp_name AS supervisor, e3.emp_name AS supervisor_of_supervisor
FROM Employees e1
LEFT JOIN Employees e2 ON e1.supervisor_id = e2.employee_id
LEFT JOIN Employees e3 ON e2.supervisor_id = e3.employee_id;

-- 入れ子集合: 指定ノードの子孫をすべて取得
SELECT e.* FROM Employees e WHERE e.lft >= @lft AND e.rgt <= @rgt;

-- クロージャテーブル: 指定ノードの子孫をすべて取得（sargable）
SELECT e.*
FROM Employees e
INNER JOIN EmployeesAncestry a ON e.employee_id = a.supervised_employee_id
WHERE a.supervising_employee_id = @employee_id AND a.distance > 0;
```

任意の深さの階層を1回のクエリで辿りたい場合は、再帰CTE（`WITH RECURSIVE`。DBMSにより `RECURSIVE` キーワードの要否が異なる）も選択肢になる。ただし再帰CTEで生成した列にはインデックスを張れないため、大規模な階層で繰り返し検索するならクロージャテーブルや入れ子集合の方が有利になりやすい。

```sql
WITH RECURSIVE OrgChart (employee_id, employee_name, manager_id, emp_level) AS (
    SELECT employee_id, employee_name, manager_id, 0
    FROM Employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.employee_id, e.employee_name, e.manager_id, o.emp_level + 1
    FROM Employees e
    INNER JOIN OrgChart o ON e.manager_id = o.employee_id
)
SELECT * FROM OrgChart ORDER BY emp_level;
```

| If X | Then Y |
|------|--------|
| 階層の更新頻度が高い（人事異動が頻繁など） | 隣接リストを主とし、必要ならクロージャテーブルをトリガで同期する |
| 階層がほぼ固定で検索速度を最優先したい | 入れ子集合 |
| 複数ルートの階層を扱う必要がある | 入れ子集合は単一ルート前提のため不向き。隣接リスト＋クロージャテーブルを検討する |
| 任意深さの祖先/子孫を都度アドホックに検索したい | 再帰CTEで十分なことが多い。頻出クエリなら専用モデルへの昇格を検討する |

## BigQuery方言の実例

標準SQLの結合・サブクエリの考え方はBigQueryでもそのまま通用するが、方言として押さえておきたい点をまとめる。

- 結合キーの列名が両テーブルで同一なら `USING (列名)` が使え、`ON` 句より簡潔に書ける。ただし `ON` 句では両テーブルの同名列がそれぞれ結果に残るのに対し、`USING` では1列に統合される点が異なる。
- `INNER` キーワードは省略して `JOIN` のみで書ける。3テーブル以上の結合も `JOIN ... ON ...`（または `USING`）を連鎖させるだけで、2テーブルの結合と構文上の大きな違いはない。
- 仮想テーブル（一時的な結果セット）の作り方は `WITH` 句・ビュー・サブクエリの3通りがあり、考え方は標準SQLのCTEと同じである。

```sql
-- 自己結合で前年比成長率を求める（1レコードずらして結合する例）
SELECT self1.year AS base_year, self2.year AS next_year,
       self2.qty / self1.qty AS growth_rate
FROM sample.yearly_sales AS self1
INNER JOIN sample.yearly_sales AS self2
        ON self1.year = self2.year - 1;
```

対象DBMSがBigQuery以外か不明な場合は、`SKILL.md`/`FOUNDATIONS-AND-NULL.md` のAskUserQuestion指針に従い、対象DBMSを確認してから日付関数やLIMIT構文などの方言差を反映する。結合・サブクエリの基本ロジックそのものはDBMSを問わず共通であり、この点についての確認は不要である。

---

[← SKILL.md に戻る](SKILL.md)
