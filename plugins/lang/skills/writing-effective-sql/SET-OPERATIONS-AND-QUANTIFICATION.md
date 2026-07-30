# 集合演算と量化

SQLには2つの理論的な柱がある。1つは集合論で、UNION/INTERSECT/EXCEPTのような「複数の結果セットをどう組み合わせるか」という技法を支える。もう1つは述語論理で、EXISTSを軸にした「特定の条件を満たす行が存在する／しないことをどう問い合わせるか」という量化の技法を支える。本ファイルはこの2つの柱を扱う。

## 1. 述語論理としてのSQL

### 1.1 述語とは何か

SQLの予約語には「述語」に分類されるものが多く登場する（`=`、`<`、`>`などの比較述語、`BETWEEN`、`LIKE`、`IN`、`IS NULL`等）。述語とは、戻り値が真理値（true/false、3値論理では加えてunknown）になる関数のことである。テーブルの1行を1つの命題と見なせば、`WHERE`句は複数の述語を組み合わせて1つの述語を構成し、その述語が真になる行だけをテーブル（命題の集合）から選び出していると解釈できる。この意味で、述語（関数的な側面）と集合（静的なデータの側面）はほぼ同じものを指している。

### 1.2 一階の述語と二階の述語（EXISTSの特異性）

`x = y`や`x BETWEEN y AND z`のような述語の引数は、通常スカラ値（単一の値）である。これに対し`EXISTS`の引数は、括弧内に書かれた`SELECT`文そのもの、つまり行の集合である。

```sql
SELECT id
  FROM Foo F
 WHERE EXISTS (SELECT * FROM Bar B WHERE F.id = B.id);
```

`EXISTS`のサブクエリの`SELECT`句リストが何を選択するか（`*`、定数、列名のどれでも）は結果に一切影響しない。判定されるのは「行が1件でも存在するか」だけである。

述語論理では、この「入力のレベル」に応じて述語を分類する。`=`や`BETWEEN`のように1行（スカラ値）を入力とする述語を**一階の述語**、`EXISTS`のように行の集合を入力とする述語を**二階の述語**と呼ぶ。関数型言語における「高階関数」（関数を引数に取る関数）と同じ発想であり、`EXISTS`は集合という一階の存在を引数に取る高階関数の一種と見なせる。SQLがサポートするのは一階述語論理までであり、「テーブルの中に条件を満たす行が存在するか」は表現できても、「条件を満たすテーブルが存在するか」という一段階上の量化はSQLの範囲外である。

### 1.3 全称量化と存在量化

述語論理には量化子（限量子）と呼ばれる特別な述語が存在する。「すべてのxが条件Pを満たす」と書くための**全称量化子**（∀）、「条件Pを満たすxが（少なくとも1つ）存在する」と書くための**存在量化子**（∃）である。

SQLの`EXISTS`述語は存在量化子を実装したものだが、SQLはもう一方の全称量化子に対応する述語（`FORALL`のようなもの）を持たない。しかし表現力が不足するわけではない。全称量化子と存在量化子は、片方が定義されていればもう片方を導出できるからである（ド・モルガンの法則）。

```
∀xPx = ¬∃x¬Px    （すべてのxが条件Pを満たす = 条件Pを満たさないxが存在しない）
∃xPx = ¬∀x¬Px    （条件Pを満たすxが存在する = すべてのxが条件Pを満たさないわけではない）
```

したがって、SQLで全称量化を表現するには、「すべての行が条件Pを満たす」という文を「条件Pを満たさない行が存在しない」という**二重否定文**に変換し、`NOT EXISTS`で書く。この変換に慣れることが、SQLで全称量化を扱う唯一の実務的な足がかりになる。

### 1.4 「存在しない」データを探す

テーブルに存在するデータへ条件を設定するのではなく、「データが存在するか否か」という一段高い問いを立てたいケースがある。たとえば、複数回の会合とその出席者を記録したテーブルから「欠席者」を求める場合である。

考え方は、全員が皆勤したと仮定した仮想集合をクロス結合で作り、そこから実際の出席記録を引き算するというものである。

```sql
-- NOT EXISTSによる解法（存在量化の否定を使う）
SELECT DISTINCT M1.meeting, M2.person
  FROM Meetings M1 CROSS JOIN Meetings M2
 WHERE NOT EXISTS (
       SELECT * FROM Meetings M3
        WHERE M1.meeting = M3.meeting
          AND M2.person  = M3.person);

-- 差集合演算による同義の解法
SELECT M1.meeting, M2.person
  FROM Meetings M1, Meetings M2
EXCEPT
SELECT meeting, person FROM Meetings;
```

`NOT EXISTS`は直接的に差集合演算としての機能を持つ。両者は同じ結果を導く同値な表現であり、これは1.1で述べた「述語と集合はほぼ同じもの」という関係を具体的に示す例でもある。

### 1.5 全称量化の書き方: 肯定を二重否定へ変換する

「すべての教科について50点以上を取っている生徒」を選ぶには、「すべての教科が50点以上である」を「50点未満の教科が1つも存在しない」に変換して`NOT EXISTS`で書く。

```sql
SELECT DISTINCT student_id
  FROM TestScores TS1
 WHERE NOT EXISTS (
       SELECT * FROM TestScores TS2
        WHERE TS2.student_id = TS1.student_id
          AND TS2.score < 50);
```

より複雑な条件（「算数80点以上かつ国語50点以上」のように科目ごとに基準が異なる条件）も、同じ行の集合の中で条件を分岐させた全称量化として扱える。`CASE`式で条件を反転してサブクエリに埋め込む。

```sql
SELECT DISTINCT student_id
  FROM TestScores TS1
 WHERE subject IN ('算数', '国語')
   AND NOT EXISTS (
       SELECT * FROM TestScores TS2
        WHERE TS2.student_id = TS1.student_id
          AND 1 = CASE WHEN subject = '算数' AND score < 80 THEN 1
                       WHEN subject = '国語' AND score < 50 THEN 1
                       ELSE 0 END);
```

データが存在しない科目を除外して「両方の科目が必ず揃っている」ことまで要求するなら、`GROUP BY`と`HAVING COUNT(*) = N`（Nは必須科目数）を組み合わせる。CASE式とHAVING句を使った条件分岐の基礎はCASE-AND-AGGREGATION.mdを参照。

### 1.6 EXISTS(NOT EXISTS) vs HAVING

個体ではなく集合レベルの操作という点で、`EXISTS`/`NOT EXISTS`と`HAVING`はよく似ており、どちらか一方で表現できるクエリはもう一方でも表現できることが多い。

「工程1番まで完了しているプロジェクトを選ぶ」という要件（各行の工程番号と状態がすべて特定の条件パターンに一致するかを問う全称量化）を両方式で書き比べる。

```sql
-- 集約ベース（HAVING）の解答
SELECT project_id
  FROM Projects
 GROUP BY project_id
HAVING COUNT(*) = SUM(CASE WHEN step_nbr <= 1 AND status = '完了' THEN 1
                           WHEN step_nbr  > 1 AND status = '待機' THEN 1
                           ELSE 0 END);

-- 述語論理ベース（NOT EXISTS）の解答
SELECT *
  FROM Projects P1
 WHERE NOT EXISTS (
       SELECT status FROM Projects P2
        WHERE P1.project_id = P2.project_id
          AND status <> CASE WHEN step_nbr <= 1 THEN '完了' ELSE '待機' END);
```

| 観点 | NOT EXISTS（全称量化） | HAVING（集約ベース） |
|------|------------------------|----------------------|
| パフォーマンス | 条件に反する行が1件でも見つかれば即座に打ち切れる（短絡評価）。結合列に索引があればさらに高速 | グループ全体を集約してから比較するため基本的に全行を読む |
| 得られる情報量 | 個々の行（明細）をそのまま返せる | `GROUP BY`キーに集約されるため明細情報は失われる |
| 可読性 | 二重否定になるため直感的にはわかりにくい | 「条件を満たす行数を数える」発想のため直感的 |
| 使い分けの目安 | 明細を保持したい／パフォーマンスを優先したい場合 | 集約結果だけで十分／わかりやすさを優先したい場合 |

### 1.7 列方向への量化: ALL/ANY/IN

`EXISTS`が「行方向」の量化（複数行のどれかが条件を満たすか）を扱うのに対し、擬似的に配列を列へ展開したテーブル（`col1`〜`col10`のような列を持つ設計）では「列方向」の量化が必要になることがある。このような列指向の擬似配列テーブル自体は望ましい設計ではなく、可能ならスキーマ変更（行持ちへの正規化）を検討すべきだが、既存スキーマを変更できない場合の次善策として次の書き方がある。

```sql
-- 「すべての列が1」という全称量化
SELECT * FROM ArrayTbl WHERE 1 = ALL (col1, col2, col3, /* ... */ col10);

-- 「少なくとも1つの列が9」という存在量化
SELECT * FROM ArrayTbl WHERE 9 = ANY (col1, col2, col3, /* ... */ col10);
-- IN でも同義に書ける
SELECT * FROM ArrayTbl WHERE 9 IN (col1, col2, col3, /* ... */ col10);
```

標準SQLの`ALL`/`ANY`はもともとサブクエリに対する量化子であり、列のリストへ直接適用できるかどうかは対象DBMSに依存する。移植性を優先するなら`IN`を使うのが安全である。

NULLを条件にする場合はこの書き方が使えない点に注意する。`NULL = ALL(...)`は常に空集合を返す（`col = NULL`という比較自体が3値論理でunknownになるため。詳細はFOUNDATIONS-AND-NULL.mdを参照）。「すべての列がNULL」を判定するには`COALESCE`で代替する。

```sql
SELECT * FROM ArrayTbl
 WHERE COALESCE(col1, col2, col3, /* ... */ col10) IS NULL;
```

### 量化技法の使い分け

| 要件 | 推奨技法 | 理由 |
|------|---------|------|
| 「条件を満たす行が存在する／しない」 | `EXISTS` / `NOT EXISTS` | 存在量化をそのまま表現できる |
| 「すべての行が条件を満たす」 | `NOT EXISTS`（二重否定変換） | SQLに全称量化子が無いための標準的な代替 |
| 集約結果だけで十分・可読性優先 | `HAVING` | 二重否定を避けられる |
| 明細行を保持したい・パフォーマンス優先 | `NOT EXISTS` | 短絡評価と索引利用が効きやすい |
| 列方向の全称／存在量化（擬似配列テーブル） | `ALL`/`ANY`/`IN` | 列リストへの量化を1行で表現できる |
| 上記でNULL自体を条件にしたい | `COALESCE` | 3値論理の比較演算では判定できないため |

## 2. 集合演算（UNION/INTERSECT/EXCEPT）

### 2.1 基本: 和・積・差と重複行の扱い

SQLの集合演算子は、テーブルやビューといった行の集合を入力に取る。標準的な3つの演算子は次のとおりである。

| 演算子 | 意味 | イメージ |
|--------|------|---------|
| `UNION` | 和集合。2つの結果セットを縦に足し合わせる | `WHERE`のORに相当 |
| `INTERSECT` | 積集合。両方に共通する行だけを残す | `WHERE`のANDに相当 |
| `EXCEPT`（Oracleは`MINUS`） | 差集合。一方から他方を引く | 引き算 |

リレーショナルデータベースのテーブルは重複行を許す多重集合（multiset）であるため、集合演算子には重複を排除するデフォルト動作と、それを保持する`ALL`オプションの2種類がある。`UNION`/`INTERSECT`/`EXCEPT`はいずれもデフォルトで重複行を除去し、`UNION ALL`のように`ALL`を付けると重複を保持する。`SELECT`句の`DISTINCT`とは逆の扱いになる点に注意する。

重複除去のためには暗黙のソート（またはハッシュ処理）が発生するため、`ALL`を付けたほうがパフォーマンスは有利になる。重複が発生しないことが確実な場合や、重複を気にする必要がない集計目的の場合は、`ALL`を使うのが基本方針である。

### 2.2 演算子の優先順位

標準SQLでは、`UNION`・`EXCEPT`よりも`INTERSECT`が先に評価されると定められている。`UNION`と`INTERSECT`を併用するクエリで`UNION`を先に評価したい場合は、括弧で明示的に順序を指定する必要がある。差集合の順序を含め、複数の集合演算を組み合わせる際は必ず括弧で意図を明示すること。

### 2.3 DBMSごとの実装差（判断基準テーブル）

集合演算の実装状況はDBMSによってばらつきがある。対象DBMSが不明な場合はSKILL.mdのAskUserQuestion指針に従って確認すること。

| 演算 | 標準SQL | PostgreSQL | MySQL | SQL Server | Oracle | BigQuery |
|------|---------|-----------|-------|-------------|--------|----------|
| `UNION` | `UNION [ALL]` | 対応 | 対応 | 対応 | 対応 | `UNION DISTINCT`/`UNION ALL`の明記が必須（`UNION`単独は非対応） |
| `INTERSECT` | `INTERSECT [ALL]` | 対応 | バージョンにより対応（要確認） | 対応（`ALL`は非対応） | 対応 | `INTERSECT DISTINCT`のみ（`ALL`非対応） |
| 差集合 | `EXCEPT [ALL]` | 対応 | バージョンにより対応（要確認） | `EXCEPT`対応（`ALL`は非対応） | `MINUS`キーワード（`ALL`非対応） | `EXCEPT DISTINCT`のみ（`ALL`非対応） |

古いバージョンのMySQLやMicrosoft Accessのように`INTERSECT`/`EXCEPT`自体を持たないDBMSでは、両方の列に対する内部結合（`INTERSECT`の代替）や、`NOT IN`／外部結合でNULL判定する方法（`EXCEPT`の代替）でエミュレートできる。移植性が必要なコードでは、これらのエミュレーション手段も選択肢に入れる。

### 2.4 BigQueryダイアレクトの実例

BigQueryは標準SQLと異なり、`UNION`に`DISTINCT`または`ALL`の指定を省略できない。また`INTERSECT`/`EXCEPT`は`DISTINCT`のみをサポートし、`ALL`バリアントは存在しない。

```sql
-- BigQuery: UNION は DISTINCT/ALL の明記が必須
SELECT date, product_name, qty FROM sample.small_jan
UNION DISTINCT
SELECT date, product_name, qty FROM sample.small_feb
ORDER BY 1;

-- BigQuery: INTERSECT は DISTINCT のみ
SELECT product_name FROM sample.small_jan
INTERSECT DISTINCT
SELECT product_name FROM sample.small_feb;

-- BigQuery: EXCEPT は DISTINCT のみ。順序を変えると結果が変わる
SELECT product_name FROM sample.small_jan
EXCEPT DISTINCT
SELECT product_name FROM sample.small_feb;
```

集合演算における「重複」は、`SELECT`句で取得したすべての列の組み合わせが一致することを意味する。一部の列だけを比較したい場合は、その列だけを`SELECT`句に列挙すればよい（`date`列を含めたままにすると、日付が異なるだけで重複と判定されなくなる点に注意）。

### 2.5 集合の相等性チェック

2つのテーブルが「集合として等しい」（行数・列数・データ内容が同じ）かどうかを調べたい場面は、環境移行時の検証やバックアップとの突き合わせなどで頻繁に発生する。

事前に両テーブルの行数が同じとわかっている場合は、`UNION`だけを使う簡単な方法が使える。`UNION`は重複行を排除するため、2つのテーブルが等しければ`UNION`の結果行数は元の行数と一致し、異なっていれば行数が増える。

```sql
-- この結果が両テーブルの行数と一致すれば、両者は集合として等しい
SELECT COUNT(*) AS row_cnt
  FROM (SELECT * FROM tbl_A UNION SELECT * FROM tbl_B) TMP;
```

これは、`UNION`と`INTERSECT`が「冪等性」（同じ集合同士の演算を繰り返しても結果が変わらない性質、`S UNION S = S`）を持つことに基づく。`UNION ALL`や重複行を含むテーブルに対してはこの性質は成立しない点に注意する。

事前の行数確認を省きたい場合は、集合の相等性に関する一般的な公式`(A ∪ B) = (A ∩ B) ⇔ (A = B)`を使う。`(A UNION B) EXCEPT (A INTERSECT B)`が空集合になれば等しく、1行以上残れば異なる。

```sql
SELECT CASE WHEN COUNT(*) = 0 THEN '等しい' ELSE '異なる' END AS result
  FROM ((SELECT * FROM tbl_A UNION SELECT * FROM tbl_B)
         EXCEPT
        (SELECT * FROM tbl_A INTERSECT SELECT * FROM tbl_B)) TMP;
```

この方法は行数の事前確認が不要な代わりに、集合演算3回分のソートコストがかかる。頻繁に実行するクエリでなければ許容範囲だが、パフォーマンスと簡潔さのトレードオフとして両方式を使い分ける。

相違する行そのものを具体的に列挙したい場合（テーブル同士のdiff）は、排他的和集合を求める。

```sql
(SELECT * FROM tbl_A EXCEPT SELECT * FROM tbl_B)
UNION ALL
(SELECT * FROM tbl_B EXCEPT SELECT * FROM tbl_A);
```

`A-B`と`B-A`の間に共通部分は存在しえないため、マージには`UNION ALL`で十分である。括弧は演算順序を確定させる重要な要素であり、外すと正しい結果が得られない。

| 判定したいこと | 使う技法 |
|---------------|---------|
| 集合として等しいか（行数が事前にわかっている） | `UNION`のみ・結果行数の比較 |
| 集合として等しいか（行数の事前確認なし） | `(A UNION B) EXCEPT (A INTERSECT B)`が空集合か |
| 具体的にどの行が異なるか | `(A EXCEPT B) UNION ALL (B EXCEPT A)` |

### 2.6 差集合による関係除算

標準SQLには関係除算（division: 「ある集合の要素をすべて満たすグループを求める」演算）に対応する演算子がない。代表的な実現方法は、`NOT EXISTS`の入れ子、`HAVING`による一対一対応、差集合を使った引き算への還元の3通りである。ここでは差集合を使う方法を扱う（`NOT EXISTS`の入れ子と`HAVING`を使う方法はCASE-AND-AGGREGATION.mdの特性関数・関係除算の節を参照）。

「必要とされるスキルすべてに精通した社員を探す」という要件は、社員ごとに「要求スキルの集合 − その社員が持つスキルの集合」を計算し、結果が空集合になる社員を選べばよい。

```sql
SELECT DISTINCT emp
  FROM EmpSkills ES1
 WHERE NOT EXISTS (
       SELECT skill FROM Skills
       EXCEPT
       SELECT skill FROM EmpSkills ES2
        WHERE ES1.emp = ES2.emp);
```

相関サブクエリが同じテーブルを社員ごとに関連付けており、除算という難しい演算を「引き算を社員単位で繰り返す」という単純な操作に還元している。この解法は明細（不足しているスキルそのもの）を求めたいときにも拡張しやすい。

### 2.7 等しい部分集合を見つける

「数も種類もまったく同じ要素を扱っている集合のペアをすべて見つける」という問題は、集合同士の比較という点で関係除算と構造が似ているが、比較対象のどちらの集合も固定されていない（すべての組み合わせについてテストする）分、より一般的な問題になる。標準SQLには部分集合や集合の相等性を直接判定する述語がないため、次のように組み立てる。

まず候補ペアを非等値結合で作る。

```sql
SELECT SP1.sup AS s1, SP2.sup AS s2
  FROM SupParts SP1, SupParts SP2
 WHERE SP1.sup < SP2.sup
 GROUP BY SP1.sup, SP2.sup;
```

集合の相等性は「(A ⊆ B) かつ (A ⊇ B) ⇒ (A = B)」と同値であり、これは「同じ種類の要素を扱っている」ことと「同数の要素を扱っている（全単射が存在する）」ことの2条件に分解できる。

```sql
SELECT SP1.sup AS s1, SP2.sup AS s2
  FROM SupParts SP1, SupParts SP2
 WHERE SP1.sup < SP2.sup
   AND SP1.part = SP2.part                 -- 条件1: 同じ種類の要素を扱う
 GROUP BY SP1.sup, SP2.sup
HAVING COUNT(*) = (SELECT COUNT(*) FROM SupParts SP3 WHERE SP3.sup = SP1.sup)
   AND COUNT(*) = (SELECT COUNT(*) FROM SupParts SP4 WHERE SP4.sup = SP2.sup);
                                            -- 条件2: 同数の要素を扱う
```

`HAVING`句の2条件は、2.6の関係除算と本質的に同じ発想であり、要素の過不足がないことと種類の一致を同時に保証する。SQLで2つの集合を比較する際は、行単位ではなく集合全体として扱う発想が要点になる。

### 2.8 重複行削除への応用

主キーを持たないテーブルで重複行を削除したい場合、相関サブクエリを使う方法（残す行の最大値を求めて、それより小さいIDを削除する）は素直だが、相関サブクエリはパフォーマンスに難がある。集合演算を使うと、削除対象を「全体から残す行を引いた補集合」として一括で求められる。

```sql
-- 相関サブクエリ版（比較のためのベースライン）
DELETE FROM Products
 WHERE rowid < (SELECT MAX(P2.rowid) FROM Products P2
                 WHERE Products.name = P2.name AND Products.price = P2.price);

-- 補集合をEXCEPTで求める版
DELETE FROM Products
 WHERE rowid IN (SELECT rowid FROM Products
                 EXCEPT
                 SELECT MAX(rowid) FROM Products GROUP BY name, price);

-- 補集合をNOT INで求める版（EXCEPT非対応のDBMSでも使える）
DELETE FROM Products
 WHERE rowid NOT IN (SELECT MAX(rowid) FROM Products GROUP BY name, price);
```

非相関になったサブクエリは残すべきrowidの定数リストを1回だけ求めればよく、行ごとの相関評価が不要になる。どちらが速いかはテーブル規模や削除対象の比率に依存するため実測で判断するが、`EXCEPT`を持たないDBMSでは`NOT IN`版が唯一の選択肢になる。`NOT IN`はサブクエリの結果にNULLが混入すると全体が空になる罠があるため、`rowid`のような非NULL列に限定して使うこと（NULLと`NOT IN`の詳細はFOUNDATIONS-AND-NULL.mdを参照）。

### 集合演算の使い分け

| 要件 | 推奨技法 | 補足 |
|------|---------|------|
| 複数の結果セットを縦に連結したい | `UNION` [`ALL`] | 重複を残したいかで`ALL`の要否を判断 |
| 両方に共通する行だけがほしい | `INTERSECT` | 未対応の古いDBMSでは内部結合でエミュレート |
| 一方にしかない行がほしい | `EXCEPT`（Oracleは`MINUS`） | 順序で結果が変わる点に注意 |
| 2テーブルが集合として等しいか検証したい | 2.5の技法 | 行数事前確認の有無で使い分け |
| グループがある要素集合をすべて満たすか判定したい（関係除算） | 差集合の入れ子（2.6） | `NOT EXISTS`入れ子やHAVINGでも表現可 |
| 主キーがないテーブルの重複行を削除したい | `EXCEPT`または`NOT IN`による補集合 | 相関サブクエリよりパフォーマンス面で有利なことが多い |

## スキーマ設計との境界

除算や相等性チェックはあくまで「既存のスキーマに対してどうクエリを書くか」という技法である。主キー設計や正規化そのものに踏み込む判断（そもそも擬似配列テーブルを行持ちに直すべきか、重複行を防ぐために主キーを追加すべきかなど）は設計判断であり、詳細はlang:developing-databasesを参照すること。
