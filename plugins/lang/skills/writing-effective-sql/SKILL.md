---
name: writing-effective-sql
description: >-
  Practical techniques for writing correct, effective, and fast SQL queries across engines:
  set-based declarative thinking, CASE expressions and conditional aggregation, GROUP BY/HAVING
  and characteristic functions, window functions (frames, inter-row comparison, correlated-subquery
  replacement), joins and subqueries (self-join, cross join, outer-join pivot, tally/hierarchical),
  set operations and quantification (EXISTS, universal/existential), NULL and three-valued logic, and
  execution-plan-based query rewriting (SARGable predicates, slow-to-fast rewrite catalog, cross-DBMS
  dialect portability). Use when writing, reviewing, or optimizing SQL SELECT queries, choosing joins
  vs subqueries, applying window functions, or rewriting slow queries. For schema design,
  normalization, SQL antipatterns, DB internals, and PostgreSQL operations, use lang:developing-databases
  instead. For BigQuery/GCP analytics SQL, use cloud:developing-google-cloud instead.
disable-model-invocation: false
---

# 効果的なSQLの書き方

正しく、意図が明確で、速いSQL SELECT文を書くための実践技法集。手続き型言語の発想からSQL固有の宣言的・集合ベースの発想へ切り替えることを起点に、条件分岐・集約・ウィンドウ関数・結合・サブクエリ・集合演算・NULL処理・実行計画に基づくリライトまでを一貫した視点でカバーする。対象読者はSQLの基本文法は書けるが、「動くけど遅い」「結果はいつも同じとは限らない」といった壁にぶつかっている段階の開発者・データ分析者。

---

## 中核思想: 文から式へ ─ 集合ベースの宣言的思考

SQLで書いたクエリが遅い、あるいは意図しない結果を返すとき、原因の多くは構文の誤りではなく「発想の枠組み」のズレにある。手続き型言語に慣れた人は、無意識のうちにSQLにもループや条件分岐の「手続き」を持ち込もうとする。効果的なSQLを書く出発点は、この発想そのものを宣言的な集合操作に切り替えることにある。

### 文（statement）ベースから式（expression）ベースへ

手続き型プログラミングでは、思考の基本単位は「文」である。IF文、CASE文、ループ文はいずれも「何かを実行する手続き」を記述する。この発想のままSQLに向き合うと、条件分岐を複数のSELECT「文」をUNIONでつなぐ形で表現しがちになる。

しかしSQLの世界の基本単位は「文」ではなく「式」である。SELECT・FROM・WHERE・GROUP BY・HAVING・ORDER BYの各パートに書くのはすべて式であり、列名や定数だけを書く場合も「たまたま演算子を持たない式」にすぎない。条件分岐はCASE「文」ではなくCASE「式」で表現し、複数のSELECT文を連結する必要はない。UNIONで多数のSELECT文をつなぎ合わせているコードを見かけたら、それは文ベースの発想がSQLに漏れ出しているサインであり、多くの場合CASE式や条件付き集計への書き換えでスキャン回数を減らせる（詳細: [CASE-AND-AGGREGATION.md](CASE-AND-AGGREGATION.md)）。

具体例として、「性別ごとに集計対象列を分けて表示する」という要件を考える。文ベースの発想では次のように2つのSELECT文をUNIONでつなぎがちである。

```sql
-- 文ベース: テーブルを2回スキャンする
SELECT dept, SUM(sales) AS male_sales, 0 AS female_sales
  FROM employees
 WHERE gender = 'M'
 GROUP BY dept
UNION ALL
SELECT dept, 0 AS male_sales, SUM(sales) AS female_sales
  FROM employees
 WHERE gender = 'F'
 GROUP BY dept;
```

式ベースの発想では、CASE式を集約関数の内側に埋め込むことで1回のスキャンにまとめられる。

```sql
-- 式ベース: テーブルを1回だけスキャンする
SELECT dept,
       SUM(CASE WHEN gender = 'M' THEN sales ELSE 0 END) AS male_sales,
       SUM(CASE WHEN gender = 'F' THEN sales ELSE 0 END) AS female_sales
  FROM employees
 GROUP BY dept;
```

両者は同じ結果を返すが、後者はテーブルへのアクセスが1回で済み、行の絞り込み条件を「集約すべき値の選び方」という式の中に埋め込んでいる点で発想が異なる。UNIONによる分岐は、この式ベースの書き方が思いつかないときの代替手段にすぎない。

### 集合指向（set-oriented）という発想

SQLのもう一つの特徴は、処理を1行ずつではなく行の「集合」単位でまとめて記述することにある。GROUP BY句とHAVING句、およびそれに伴うSUM・COUNT・AVG等の集約関数は、この集合指向が最もよく現れる機能である。手続き型言語であればループと分岐で書かねばならない集計処理を、SQLでは「テーブルを集合として切り分け、集合ごとに演算する」という一段抽象度の高い操作として記述できる。

この発想は結合・サブクエリ・集合演算（UNION/INTERSECT/EXCEPT）・量化述語（EXISTS/ALL/ANY）にも一貫して貫かれている。「この行とこの行を比べる」という行単位の思考ではなく、「この条件を満たす集合とあの条件を満たす集合の関係はどうなっているか」という集合単位の思考に切り替えることが、結合とサブクエリを使い分ける判断力にも直結する（詳細: [JOINS-AND-SUBQUERIES.md](JOINS-AND-SUBQUERIES.md)、[SET-OPERATIONS-AND-QUANTIFICATION.md](SET-OPERATIONS-AND-QUANTIFICATION.md)）。

集合指向の考え方を体感するには、「部署ごとの人数を数える」という処理を手続き型的に考えた場合と比較するとよい。手続き型的な発想では次のような手順を思い浮かべる。

```
1. 空の集計表（部署 → 件数）を用意する
2. 全行を1件ずつ読み、部署列の値ごとに集計表のカウンタを+1する
3. 読み終えたら集計表を出力する
```

SQLではこの手順をループとして書き下す必要はなく、「テーブルを部署という基準で集合に切り分け、各集合の件数を数える」という宣言だけで済む。

```sql
-- 集合指向: 「部署でグループ化し、各グループの件数を数える」という宣言
SELECT dept, COUNT(*) AS headcount
  FROM employees
 GROUP BY dept;
```

グループ化の基準そのものをなくしたい（テーブル全体を1つの集合として扱いたい）場合は、単にGROUP BY句を省略すればよい。これは「集合を1個だけ作る」という意味であり、特殊なケースではなく集合指向の自然な帰結である。

### SELECT文の論理評価順序という土台

宣言的思考へ切り替えるには、SELECT文が書かれた順序（SELECT → FROM → WHERE → ...）ではなく、DBMSが内部的に評価する論理的な順序（FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY）を頭に入れておく必要がある。この評価順序を理解して初めて、「WHERE句でSELECT句のエイリアスが使えない理由」や「HAVING句がなぜ集約後の絞り込みに使われるのか」が腑に落ちる。基礎となるSELECT文の道具立てとNULL/三値論理は [FOUNDATIONS-AND-NULL.md](FOUNDATIONS-AND-NULL.md) にまとめている。

### パラダイムシフトの実務的な意味

手続き型から宣言型への切り替えは、一足飛びに起こるものではなく、技法を1つずつ身につけるたびに徐々に進む心的な変化である。本スキルの各サブファイルは、いずれも「手続き型的な発想で書いたコード（ループ・相関サブクエリ・UNION連結）」と「宣言的な発想で書き直したコード（ウィンドウ関数・CASE式・EXISTS）」を対比する構成を取っている。書いたクエリに「1行ずつ処理する」ような発想が残っていないか、レビュー時に常に自問すること。

### したいこと別クイックルーティング

技法名がまだわからない段階でも、次の表から該当するサブファイルへ直接ジャンプできる。

| したいこと | 使う技法の例 | 詳細ファイル |
|-----------|-------------|-------------|
| 条件によって集計対象・表示列を変えたい | CASE式、条件付き集計（横持ち変換） | [CASE-AND-AGGREGATION.md](CASE-AND-AGGREGATION.md) |
| ランキング・順位・移動平均・前後の行との比較をしたい | ウィンドウ関数（RANK/ROW_NUMBER/LAG/LEAD、フレーム指定） | [WINDOW-FUNCTIONS.md](WINDOW-FUNCTIONS.md) |
| 相関サブクエリが遅い、行ごとに繰り返し実行されている | ウィンドウ関数への置き換え | [WINDOW-FUNCTIONS.md](WINDOW-FUNCTIONS.md) |
| 複数テーブルを組み合わせたい、自己結合したい、階層データを辿りたい | JOIN種別の使い分け、自己結合、階層クエリ | [JOINS-AND-SUBQUERIES.md](JOINS-AND-SUBQUERIES.md) |
| 行と列を入れ替えたい（クロス集計表を作りたい） | 外部結合によるpivot/unpivot | [JOINS-AND-SUBQUERIES.md](JOINS-AND-SUBQUERIES.md) |
| 「Aだが Bではない」「すべてのBに対応するA」を探したい | EXISTS/NOT EXISTS、全称量化・存在量化 | [SET-OPERATIONS-AND-QUANTIFICATION.md](SET-OPERATIONS-AND-QUANTIFICATION.md) |
| 複数の結果セットを結合・比較したい | UNION/INTERSECT/EXCEPT | [SET-OPERATIONS-AND-QUANTIFICATION.md](SET-OPERATIONS-AND-QUANTIFICATION.md) |
| NULLがらみで期待通りの結果が返らない | 三値論理、`IS NULL`、`NOT IN`と`NOT EXISTS`の非同値 | [FOUNDATIONS-AND-NULL.md](FOUNDATIONS-AND-NULL.md) |
| クエリが遅い、インデックスが効いていない気がする | 実行計画確認、SARGable述語、書き換えカタログ | [PERFORMANCE-REWRITING.md](PERFORMANCE-REWRITING.md) |

---

## このスキルの使い方

技法領域ごとにサブファイルへ分割している。目的に応じて該当ファイルを開くこと。

| ファイル | 扱う内容 |
|---------|---------|
| [FOUNDATIONS-AND-NULL.md](FOUNDATIONS-AND-NULL.md) | SELECT文の論理評価順序、検索/更新/分岐/集約/行間比較の基本道具立て、NULLと三値論理（`IS NULL`・排中律非成立・`NOT IN`と`NOT EXISTS`の非同値・限定述語とNULL）、標準SQLとDBMS方言の違い・移植性 |
| [CASE-AND-AGGREGATION.md](CASE-AND-AGGREGATION.md) | CASE式（構文・型統一・ELSE/END漏れの罠）、条件付き集計（横持ち変換）、GROUP BY/HAVING活用、特性関数、関係除算・バスケット解析、歯抜け/欠番検出 |
| [WINDOW-FUNCTIONS.md](WINDOW-FUNCTIONS.md) | ウィンドウ関数の構造（PARTITION/ORDER/フレームROWS・RANGE）、行間比較・移動平均・累計、相関サブクエリからの置き換え、内部動作とパフォーマンス特性 |
| [JOINS-AND-SUBQUERIES.md](JOINS-AND-SUBQUERIES.md) | 結合種別の使い分け、自己結合（順列・組み合わせ生成）、サブクエリ・相関サブクエリ、外部結合によるpivot/unpivot、タリーテーブル、階層クエリ、直積 |
| [SET-OPERATIONS-AND-QUANTIFICATION.md](SET-OPERATIONS-AND-QUANTIFICATION.md) | UNION/INTERSECT/EXCEPT（多重集合・優先順位・実装差）、集合の相等性・差集合、EXISTS/NOT EXISTS、全称量化・存在量化、二重否定変換 |
| [PERFORMANCE-REWRITING.md](PERFORMANCE-REWRITING.md) | 実行計画の読み方と活用、SARGable述語（インデックスを効かせる書き方）、遅い→速いの書き換えカタログ（相関サブクエリ除去・IN→EXISTS/JOIN・OR→UNION等） |

---

## 他スキルとの差別化

同じSQL・データベース領域でも、扱う抽象度が異なる隣接スキルが存在する。迷ったら以下で判断する。

| スキル | 扱う内容 | 本スキルとの違い |
|--------|---------|-----------------|
| **本スキル（writing-effective-sql）** | SELECT文を「どう書くか」というクエリ構築技法 | クエリ本文の技法に閉じる |
| `lang:developing-databases` | テーブル設計（正規化・ER設計・キー選定）、SQLアンチパターン、DBMS内部構造（B-tree・LSM・分散合意）、PostgreSQL運用（バックアップ・レプリケーション・チューニング） | スキーマ・データモデル・運用という「クエリの外側」の設計判断 |
| `cloud:developing-google-cloud` | BigQuery固有の方言（ARRAY/STRUCT型・UNNEST・料金体系・GUI操作）、GCPのデータ基盤サービス全般 | BigQuery/GCPというプラットフォーム固有の知識 |

クエリの書き方そのものに迷ったら本スキル、「そもそもテーブル構造をどう設計すべきか」「このインデックスを追加すべきか」という設計判断に踏み込んだら `lang:developing-databases` へ切り替えること。両者の境界の見分け方は「クエリを書き換えるだけで解決するか（本スキル）」「テーブル定義・インデックス・運用構成を変える必要があるか（developing-databases）」で判定する。

---

## 対象DBMSの確認（AskUserQuestion指針）

SQLクエリ技法の大半はDBMSを問わず通用する一義的なベストプラクティスだが、一部は対象DBMS・方言に依存して結論が変わる。**推測で断定せず、必要な場面では必ずAskUserQuestionで確認する。**

### 確認すべき場面

| 場面 | 理由 |
|------|------|
| 対象DBMS/方言が不明なままLIMIT・TOP・ページネーションを書く | `LIMIT`（PostgreSQL/MySQL/BigQuery系）・`TOP`（SQL Server）・`FETCH FIRST`（標準SQL・Oracle/DB2）・`ROWNUM`（Oracle）のいずれを使うかが変わる |
| ORDER BYでNULLの並び順を制御したい | デフォルトでNULLを大きい値・小さい値のどちらとして扱うかがDBMSごとに異なり、`NULLS FIRST`/`NULLS LAST`のサポート状況も分かれる |
| 日付・時刻の演算や関数を書く | データ型（`DATE`/`DATETIME`/`TIMESTAMP`等）のサポート状況・関数名・演算のセマンティクスがDBMSごとに異なる |
| クエリ書き換えで対処しきれず、索引追加や非正規化などスキーマ変更に及ぶ最適化を検討する | クエリの書き方の範囲を超えた設計判断であり、`lang:developing-databases` の領域に踏み込む |

### 確認不要な場面（一義的に決まる）

| 判断 | 正解 |
|------|------|
| NULLを検出する条件の書き方 | `IS NULL` / `IS NOT NULL` を使う。`= NULL` は常にunknownに評価され機能しない |
| EXISTSでのNULL安全な否定 | `NOT EXISTS` を使う（`NOT IN` はサブクエリの結果にNULLが含まれると常に空集合を返す） |
| CASE式でELSE句・END句を省略してよいか | 省略しない。ELSE省略時の暗黙NULL返却漏れ、END書き忘れの構文エラーは常に避けるべき |
| WHERE句とHAVING句のどちらで絞り込むか | 集約前の行に対する条件はWHERE、集約後の集合に対する条件はHAVING。これはDBMS非依存の論理評価順序で決まる |

AskUserQuestionの実装例（対象DBMSが不明な場合）:

```python
AskUserQuestion(
    questions=[{
        "question": "このクエリの対象DBMSはどれですか？LIMIT/TOP構文・NULLの並び順・日付関数の扱いが変わります。",
        "header": "対象DBMS",
        "options": [
            {"label": "PostgreSQL", "description": "LIMIT/OFFSET、NULLはデフォルトで最大値扱い、NULLS FIRST/LASTをサポート"},
            {"label": "MySQL", "description": "LIMIT/OFFSET、NULLはデフォルトで最小値扱い"},
            {"label": "SQL Server", "description": "TOP句、OFFSET/FETCH（2012以降）、ROW_NUMBER()での代替"},
            {"label": "Oracle", "description": "FETCH FIRST（12c以降）またはROWNUM擬似列、NULLはデフォルトで最大値扱い"},
            {"label": "BigQuery", "description": "標準SQL準拠のLIMIT/OFFSET、ARRAY/STRUCT型やUNNESTなどBigQuery固有の拡張がある"}
        ],
        "multiSelect": False
    }]
)
```

---

## クエリレビューの観点チェックリスト

書いたSQL、あるいはレビュー対象のSQLに対して以下を確認する。

### 正しさ

- [ ] NULLを含みうる列の比較に `=`/`<>` を直接使っていないか（`IS NULL`/`IS NOT NULL`・`NOT EXISTS`で代替できているか）
- [ ] `NOT IN` のサブクエリ結果にNULLが混入する可能性がないか（混入しうるなら `NOT EXISTS` へ書き換えているか）
- [ ] CASE式にELSE句があり、想定外の値がNULLとして黙って通過する余地がないか
- [ ] 集約関数（AVG/SUM/MAX/MIN）が入力の空集合に対してNULLを返す可能性を考慮しているか
- [ ] GROUP BYの粒度とSELECT句の非集約列が一致しているか（意図しない多重化・省略がないか）

### パフォーマンス

- [ ] WHERE句・JOIN条件の左辺に対して関数や演算を適用し、インデックスが効かなくなっていないか（SARGable性、詳細: [PERFORMANCE-REWRITING.md](PERFORMANCE-REWRITING.md)）
- [ ] 条件分岐をUNIONで複数SELECT文に分けて表現していないか（CASE式・条件付き集計で1回のスキャンに集約できないか）
- [ ] 相関サブクエリが行数分繰り返し実行される設計になっていないか（ウィンドウ関数・JOINへの置き換えを検討したか）
- [ ] 実行計画を確認し、想定通りのアクセス方法（インデックススキャン/フルスキャン）になっているか

### 可読性・保守性

- [ ] 複雑な条件式・サブクエリにCTE（WITH句）やビューで名前を与え、意図を追いやすくしているか
- [ ] 列・テーブルのエイリアスが意味を持つ名前になっているか
- [ ] ネストしたサブクエリやビューが深すぎて、実行計画・意図の両方を追いにくくしていないか

### 移植性

- [ ] LIMIT/TOP/FETCH FIRST/ROWNUMなど、DBMS固有構文に依存していることが明示されているか（クロスDBMS移植の予定がある場合）
- [ ] 日付関数・文字列連結演算子など、方言差の大きい機能を使う箇所にコメントで前提DBMSを明記しているか
- [ ] NULLの並び順に依存した結果をORDER BY句だけに頼っていないか（`NULLS FIRST`/`NULLS LAST`の明示、またはDBMS差を許容できるか確認したか）
