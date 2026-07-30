# SQLの基礎とNULL・三値論理

SQLクエリを組み立てる上で土台となる知識を扱う。SELECT文がどの順序で評価されるかという内部モデル、検索・絞り込み・並べ替え・ビュー/サブクエリという基本の道具立て、そしてSQL初級者から中級者への壁になりやすいNULLと三値論理を扱う。テーブル設計・正規化・インデックス設計そのものは対象外（詳細は `lang:developing-databases` を参照）。

---

## 1. SELECT文の論理評価順序

SELECT文は書かれた順序（`SELECT` → `FROM` → `WHERE` → `GROUP BY` → `HAVING` → `ORDER BY`）ではなく、DBMSが内部的に評価する論理的な順序で処理される。この順序を理解しないと、「なぜこの書き方はエラーになるのか」「WHEREとHAVINGはどう使い分けるのか」が場当たり的な暗記になってしまう。

| 評価順 | 句 | 役割 |
|-------|-----|------|
| 1 | `FROM` | 対象テーブル（結合結果を含む）を決定する |
| 2 | `WHERE` | 個々の行に対する絞り込み条件を適用する（集約前） |
| 3 | `GROUP BY` | 行を指定した列の値でグループ（集合）に分割する |
| 4 | `HAVING` | グループ化された集合に対する絞り込み条件を適用する（集約後） |
| 5 | `SELECT` | 出力する列・式を評価する（集約関数はここで確定する） |
| 6 | `ORDER BY` | 出力行を並べ替える |

この順序から次の実務的な帰結が導かれる。

| 疑問 | 評価順序に基づく答え |
|------|---------------------|
| WHERE句でSELECT句のエイリアス（`AS`で付けた別名）を使えないのはなぜか | WHERE（順序2）はSELECT（順序5）より先に評価されるため、SELECT句で定義したエイリアスがまだ存在しない |
| ORDER BY句でSELECT句のエイリアスを使えるのはなぜか | ORDER BY（順序6）はSELECT（順序5）より後に評価されるため、確定済みのエイリアスを参照できる |
| WHERE句とHAVING句はどちらで絞り込むべきか | 集約前の個々の行に対する条件はWHERE、集約後の集合（グループ）に対する条件はHAVINGで書く。両者は「絞り込みの対象が行か集合か」で機械的に決まり、DBMSに依存しない |
| GROUP BYを書かずに集約関数を使うと何が起きるか | テーブル全体を1つの集合として扱う（グループ化キーが空の特殊なグループ化と等価） |

---

## 2. 検索・絞り込み・並べ替えの基本道具立て

### SELECT句とFROM句

SELECT句は取得したい列（または式）をカンマ区切りで指定する。FROM句はデータの取得元テーブルを指定するが、`SELECT 1` のように定数だけを選択する場合はFROM句が不要なDBMSもある（Oracleのように常にFROM句を要求するDBMSもあり、これは実装依存の方言である）。

### WHERE句による絞り込み

WHERE句は個々の行に対する条件を指定する。等号・比較演算子に加えて、複合条件はAND/ORで組み立てる。WHERE句が課す条件は集合演算的に理解するとよく、AND条件は「両方の条件を満たす行の集合（積集合）」、OR条件は「どちらかの条件を満たす行の集合（和集合）」を選び出す操作である。

```sql
-- ANDは積集合、ORは和集合を選択する
SELECT name FROM customers WHERE prefecture = '東京都' AND age >= 30;
SELECT name FROM customers WHERE prefecture = '東京都' OR  prefecture = '千葉県';
```

OR条件が多数連なる場合はINで簡略化できる。

```sql
SELECT name FROM customers WHERE prefecture IN ('東京都', '福島県', '千葉県');
```

### ORDER BY句による並べ替え

SELECT文の結果には本来決まった並び順がなく、並び順を保証したい場合は必ずORDER BY句で明示する。既定は昇順（`ASC`、省略可）で、降順にするには `DESC` を指定する。複数列を基準にする場合は列ごとに昇順・降順を指定できる。

```sql
SELECT user_id, order_id, quantity
  FROM sales
 ORDER BY user_id ASC, order_id DESC;
```

並べ替えの基準は列名の代わりに列位置（1始まりの番号）でも指定できるが、可読性の観点から列名指定を優先し、列位置指定は一時的な確認用途にとどめるのが望ましい。NULLを含む列を並べ替える際の順序はDBMSごとに既定が異なる（詳細は本ファイル「4. 標準SQLとDBMS方言・移植性」を参照）。

### ビューとサブクエリの基礎

よく使うSELECT文はビュー（`CREATE VIEW`）として保存すると、通常のテーブルと同じようにSELECT文の中で参照できる。ビューはデータを保持せず、参照されるたびに内部のSELECT文が実行される「保存されたクエリ」である。

```sql
CREATE VIEW dept_headcount AS
SELECT dept, COUNT(*) AS headcount
  FROM employees
 GROUP BY dept;
```

FROM句に直接SELECT文を書くとサブクエリになる。ビューを毎回定義せずに済む一時的な集合としてサブクエリを使う場面は多い。WHERE句の条件作成でもサブクエリは有用で、特にINの引数にサブクエリを渡す形は頻出パターンである。

```sql
-- 「他方のテーブルにも存在する行」を選択する定番パターン
SELECT name FROM customers
 WHERE customer_id IN (SELECT customer_id FROM orders);
```

サブクエリを使った結合・相関サブクエリ・外部結合によるpivotなど、より高度な組み合わせ方は [JOINS-AND-SUBQUERIES.md](JOINS-AND-SUBQUERIES.md) を参照。CASE式・条件付き集計・ウィンドウ関数はそれぞれ [CASE-AND-AGGREGATION.md](CASE-AND-AGGREGATION.md)・[WINDOW-FUNCTIONS.md](WINDOW-FUNCTIONS.md) で扱う。

### 実例: BigQuery標準SQLでの基本構文

以下はBigQuery標準SQLでの実装例。標準SQLの範囲に収まる基本構文だが、フィールド（列）指定・演算・別名・絞り込みの組み合わせ方の具体例として示す。

```sql
-- 単一・複数フィールドの取得と並べ替え（列位置指定も可能）
SELECT order_id, user_id, quantity
  FROM sample.sales
 ORDER BY user_id ASC, order_id DESC;

-- すべてのフィールドを取得しつつ、不要な列だけ除外する
SELECT * EXCEPT (cost)
  FROM sample.products;

-- 既存フィールドの演算結果に別名を付ける
SELECT order_id,
       revenue / quantity AS unit_price
  FROM sample.sales
 ORDER BY quantity DESC;

-- 結果件数の制限（LIMIT）とページング（OFFSET）
SELECT order_id, date_time
  FROM sample.sales
 ORDER BY date_time DESC
 LIMIT 5 OFFSET 100;

-- 条件による行の絞り込み
SELECT *
  FROM sample.customers
 WHERE gender = 2;
```

`SELECT *` は全フィールドの値をひとまず確認する用途に便利だが、大規模テーブルに対して不用意に実行するとスキャン量（コスト）が増える点に注意する。実務では対象列を明示するSELECT句を基本とし、`*`は探索的な確認作業に限定するのが望ましい。

---

## 3. NULLと三値論理

### 2値論理と3値論理

通常のプログラミング言語の真理値は`true`/`false`の2値論理に基づくが、SQLは`true`/`false`に加えて第三の真理値`unknown`（不明）を持つ3値論理を採用している。この3値論理はNULLの存在に由来する。SQLにNULLを比較述語（`=`・`<>`・`<`・`>`等）で比較すると、結果は常に`unknown`になる。

```sql
-- 以下はすべてunknownに評価される
1 = NULL
NULL = NULL
NULL <> NULL
```

NULLは値でも変数でもなく「値が存在しないことを示すマーク」にすぎない。比較述語は値に対してのみ意味を持つため、値ではないNULLに比較述語を適用すること自体がナンセンスであり、その結果として`unknown`が生じる。したがって「列の値がNULLである」という表現も厳密には誤りで、NULLは値の集合（定義域）に含まれていない。

### なぜ「= NULL」ではなく「IS NULL」なのか

WHERE句で選択されるのは、条件評価が`true`になった行だけである。`false`はもちろん`unknown`に評価された行も選択されない。NULLとの比較は常に`unknown`になるため、`WHERE col = NULL` は構文エラーにこそならないが、結果は常に空になる。NULLを検出するには専用の述語`IS NULL`（否定は`IS NOT NULL`）を使う必要がある。

```sql
-- 誤り: 常に0行になる
SELECT * FROM tbl WHERE col_1 = NULL;

-- 正しい書き方
SELECT * FROM tbl WHERE col_1 IS NULL;
```

### 3値論理の真理表

`unknown`が論理演算（AND/OR/NOT）に混入すると、直観に反する結果を生む。真理表を覚えるよりも、次の優先順位ルールで考えると見通しがよい。

- **AND**: `false` > `unknown` > `true`（強い方が結果を決める。ANDがtrueになるのは両方がtrueのときだけ）
- **OR**: `true` > `unknown` > `false`（強い方が結果を決める）

| AND | true | false | unknown |
|-----|------|-------|---------|
| **true** | true | false | unknown |
| **false** | false | false | false |
| **unknown** | unknown | false | unknown |

| OR | true | false | unknown |
|----|------|-------|---------|
| **true** | true | true | true |
| **false** | true | false | unknown |
| **unknown** | true | unknown | unknown |

`NOT unknown` は `unknown` のままである（trueにもfalseにも反転しない）。

### 排中律が成立しない

2値論理の世界では「Xか、Xでないか、どちらかである」（排中律）は常に真になる。ところがSQLでは、対象列がNULLの場合にこの原則が崩れる。

```sql
-- 排中律のつもりで書いたクエリ:年齢が20歳か20歳でないかで全行を選ぶ意図
SELECT * FROM students WHERE age = 20 OR age <> 20;
```

年齢がNULLの行は、`age = 20` も `age <> 20` も両方 `unknown` に評価され、`unknown OR unknown` は `unknown` のままなので選択されない。NULLを含む行まで確実に含めたい場合は、第三の条件を明示的に足す必要がある。

```sql
SELECT * FROM students
 WHERE age = 20 OR age <> 20 OR age IS NULL;
```

### CASE式とNULL

単純CASE式で `WHEN NULL` と書いても意図通りに動かない。これは `col = NULL` の省略形として解釈されるためで、常に`unknown`となりそのWHEN句は選ばれない。NULL判定をCASE式に含めたい場合は、検索CASE式で `col IS NULL` を明示する。

```sql
-- 誤り: 「NULLなら×」のつもりが、このWHEN句には絶対に到達しない
CASE col_1
  WHEN 1    THEN '○'
  WHEN NULL THEN '×'
END

-- 正しい書き方
CASE WHEN col_1 = 1     THEN '○'
     WHEN col_1 IS NULL THEN '×'
END
```

### NOT INとNOT EXISTSは同値ではない

`IN` を `EXISTS` に書き換えるのはパフォーマンスチューニングの定番技法だが、`NOT IN` を `NOT EXISTS` に書き換えると結果が変わる場合がある。原因は、`NOT IN` のサブクエリが返す列にNULLが1件でも含まれていると、`NOT IN` 全体が常に空集合を返してしまうことにある。

```sql
-- サブクエリの返す年齢列にNULLが含まれると、以下は常に0行になる
SELECT * FROM class_a
 WHERE age NOT IN (SELECT age FROM class_b WHERE city = '東京都');
```

`NOT IN (22, 23, NULL)` は内部的に `age <> 22 AND age <> 23 AND age <> NULL` に展開され、最後の項が必ず`unknown`になり、ANDの優先順位ルール（`false > unknown > true`）によって結果が`true`にならないためである。`EXISTS`/`NOT EXISTS` は述語自体が`true`/`false`しか返さず`unknown`を生じないため、この問題を回避できる。

```sql
-- 正しい書き方: NOT EXISTSはunknownを生じない
SELECT * FROM class_a a
 WHERE NOT EXISTS (
   SELECT * FROM class_b b
    WHERE a.age = b.age AND b.city = '東京都'
 );
```

**判断基準**: `IN`⇔`EXISTS` の書き換えは常に安全だが、`NOT IN` のサブクエリ結果列にNULLが含まれる可能性がある場合は必ず `NOT EXISTS` を使う。サブクエリ側の列にNOT NULL制約がある、あるいはWHERE句でNULLを確実に除外できていることが保証されている場合に限り `NOT IN` も安全に使える。

### 限定述語（ALL/ANY）とNULL

`ALL`は比較述語をANDで連結した論理式の省略形として定義されているため、サブクエリの返す値にNULLが含まれると、`NOT IN`と同様の理由で結果が空になりやすい。一方、`MIN`/`MAX`のような極値関数は集計の際にNULLを除外する性質を持つため、`ALL`述語を極値関数で代用すると一見同じ結果に見えることがある。

ただし両者は次の点で同値ではない。

| ケース | `ALL`述語 | 極値関数（`MIN`/`MAX`）による代用 |
|--------|-----------|-----------------------------------|
| サブクエリの対象集合にNULLが含まれる | サブクエリ結果にNULLが混じるとANDの優先順位ルールにより結果が空になりやすい | NULLは集計対象から除外されるため、NULLの影響を受けない |
| サブクエリの対象集合が空集合（0行） | 比較対象が存在しないため全行を選択する（「不戦勝」的な扱い） | 空集合に対する集約関数はNULLを返し、NULLとの比較は`unknown`になるため0行になる |

比較対象が空集合になりうる場合、全行を選びたいのか0行にすべきかは要件次第である。極値関数を使う場合はCOALESCE関数でNULLを代替値に変換するなど、意図を明示すること。

### 集約関数とNULL

`COUNT(*)` 以外の集約関数（`SUM`・`AVG`・`MIN`・`MAX`）は、入力が空集合（0行）の場合にNULLを返す。この性質により、次のような一見平凡なクエリも注意が必要になる。

```sql
-- 東京都在住の生徒がいない場合、AVG(age)はNULLを返し、外側のWHEREは常にunknownになる
SELECT * FROM class_a
 WHERE age < (SELECT AVG(age) FROM class_b WHERE city = '東京都');
```

NOT NULL制約付きの列に集約結果をINSERTする場合など、NULLを許容できない文脈では `COALESCE` 関数で既定値へ変換する必要がある。この罠はテーブルの列にNOT NULL制約を付けても防げない（原因が集約関数の仕様そのものにあるため）。

### 文字列とNULL

標準SQLでは、NULLは空文字列とは区別される別概念であり、文字列連結演算子（`||`）にNULLを渡すと結果は必ずNULLになる。一方、空文字列との連結は元の文字列をそのまま返す（空文字列は文字列連結における単位元として振る舞う）。

```sql
SELECT 'abc' || ''   AS s;  -- 'abc'（空文字との連結は変化なし）
SELECT 'abc' || NULL AS s;  -- NULL（NULLとの連結はNULLになる）
```

**一部のDBMS（代表例: Oracle）では、空文字列を実質的にNULLと同一視するローカルルールを持つ**ため、この標準的な挙動と異なる結果になることがある。クロスDBMSでの移植や、空文字列とNULLの区別が業務要件上重要な場合は、対象DBMSでの実際の挙動を検証すること。

### NULL対策の原則

| 原則 | 内容 |
|------|------|
| NULLは値ではない | 比較述語（`=`/`<>`等）をそのまま適用できない。専用の`IS [NOT] NULL`述語を使う |
| unknownの伝播に注意する | ANDに`unknown`が混じるとtrueにならず、ORに`unknown`が混じるとfalseにならない |
| `NOT IN`より`NOT EXISTS` | サブクエリ結果にNULLが混入しうる場面では`NOT IN`を避ける |
| 集約関数の空集合挙動を把握する | `COUNT(*)`以外はNULLを返しうる。後続比較が`unknown`化する可能性を考慮する |
| 根本対策はNOT NULL制約 | クエリ側の防御だけでなく、可能な限りテーブル設計側でNULLを排除する（設計判断は`lang:developing-databases`の領域） |

---

## 4. 標準SQLとDBMS方言・移植性

標準SQL（ANSI/ISO SQL規格）は多くの部分でDBMS間の互換性を保証するが、日付・時刻の構文、文字列連結、NULLの扱い、大文字小文字の区別など、実装依存の「方言」が残る領域がある。移植性を重視する場合や、初めて触るDBMSでクエリを書く場合は、以下の代表的な差異を確認する。

### 結果セットのソート順（NULLの位置）

SQL規格はNULLとNULL以外の値の間の順序を厳密には規定しておらず、「NULL同士は等しい」「NULLはNULL以外の値より前か後ろかのいずれかで統一する」という制約のみを課している。そのため既定の並び順はDBMSごとに分かれる。

| DBMS | 既定のNULLの扱い | 明示的な制御 |
|------|-----------------|-------------|
| PostgreSQL | NULL以外の値より大きい扱い | `ORDER BY col NULLS FIRST/LAST` |
| Oracle | NULL以外の値より大きい扱い | `ORDER BY col NULLS FIRST/LAST` |
| MySQL | NULL以外の値より小さい扱い | 標準の`NULLS FIRST/LAST`は非対応（列名の符号反転などの代替手段が必要） |
| SQL Server | NULL以外の値より小さい扱い | `NULLS FIRST/LAST`は非対応（`CASE WHEN col IS NULL THEN 0 ELSE 1 END`等で代替） |

**移植性が必要な場合**は既定挙動に依存せず、`NULLS FIRST/LAST`（対応DBMS）または `CASE WHEN col IS NULL THEN ... END` を先頭のソートキーに追加するなど、並び順を明示的に固定する。

### 結果セットの行数制限（LIMIT/TOP/ページング）

SQL規格は行数制限の標準構文として `FETCH FIRST n ROWS ONLY`・ウィンドウ関数（`ROW_NUMBER() OVER (...)`）・カーソルの3通りを定義しているが、実際にサポートする構文はDBMSごとに異なる。

| DBMS | 主な構文 |
|------|---------|
| PostgreSQL | `LIMIT n OFFSET m`、標準の`FETCH FIRST`にも対応 |
| MySQL | `LIMIT n OFFSET m`（標準の`FETCH FIRST`は非対応） |
| SQL Server | `TOP n`、または`OFFSET m ROWS FETCH NEXT n ROWS ONLY`（2012以降） |
| Oracle | `FETCH FIRST n ROWS ONLY`（12c以降）、または`ROWNUM`擬似列・`ROW_NUMBER()` |
| BigQuery | 標準SQL準拠の`LIMIT n OFFSET m` |

`LIMIT`/`TOP`単体では「どのn件」を返すかがDBMS任せになるため、確定的な結果が必要なら必ず`ORDER BY`を併用する。

### 日付・時刻データ型と関数

日付・時刻を表すデータ型のサポート状況、加減算の意味論、関数名はDBMSごとに大きく異なる（例: 一部のDBMSは日付/時刻値を数値に変換してから加減算するため、`INTERVAL`のような専用構文を使わないと意図しない結果になる）。標準SQLは`CURRENT_DATE`/`CURRENT_TIME`/`CURRENT_TIMESTAMP`の3関数を定義しているが、DBMSによっては完全にはサポートしていない。日付・時刻演算を書く際は、対象DBMSのドキュメントで型と関数の対応を確認することが不可欠である。

### 移植性のための判断基準

| 判断 | 対応 |
|------|------|
| 単一DBMS向けに書き、移植の予定がない | DBMS固有の便利な構文（`LIMIT`・`NULLS FIRST`等）を積極的に使ってよい |
| 複数DBMSへの移植・DBMS変更の可能性がある | 標準SQL準拠の構文（`FETCH FIRST`・`CASE`式によるNULL順序制御等）を優先し、DBMS固有構文を使う箇所はコメントで明示する |
| 対象DBMSが不明なまま作業を依頼された | 推測で断定せず、[SKILL.md](SKILL.md) の「対象DBMSの確認（AskUserQuestion指針）」に従って確認する |
