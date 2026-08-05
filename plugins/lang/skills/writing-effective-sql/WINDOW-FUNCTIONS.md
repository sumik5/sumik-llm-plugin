# ウィンドウ関数

## 概要

ウィンドウ関数（analytic function / OLAP function とも呼ばれる）は、行を集約して1行にまとめる通常の集約関数とは異なり、**元の行を保持したまま**、指定した範囲（ウィンドウ）に対する計算結果を各行に追加する機能である。1990年代後半に考案され、2000年代に主要DBMSへ順次実装が広がり、現在では主要なDBMSのほとんどでサポートされている。

ウィンドウ関数が重要視される最大の理由は、それまで**行間比較・順位付け・累計計算のために相関サブクエリや手続き型のループに頼らざるを得なかった処理**を、単純で読みやすいSQL文に置き換えられる点にある。「集合演算しかできないはずのSQLに、行の順序という概念を持ち込んだ」機能と捉えるとイメージしやすい。

| 用途 | ウィンドウ関数がなかった時代の手段 | ウィンドウ関数による解法 |
|------|------------------------------------|--------------------------|
| 直前・直後の行との比較 | 相関サブクエリで「1つずらしたテーブル」を結合 | フレーム句で1行に絞ったウィンドウを参照 |
| 順位付け・行番号付与 | 相関サブクエリで「自分以下の件数」をCOUNT | `ROW_NUMBER` / `RANK` / `DENSE_RANK` |
| 累計・移動平均 | 自己結合＋集約、またはアプリ側でのループ | `SUM` / `AVG` をウィンドウ関数として使用 |
| グループ内平均との比較 | 相関サブクエリでグループ平均をサブクエリ実行 | `AVG(...) OVER (PARTITION BY ...)` |

### いつ使う／使わない

| 状況 | 判断 |
|------|------|
| 同一パーティション内で行間の値を比較・参照したい | ウィンドウ関数を第一候補にする |
| ランキング・累計・移動平均を求めたい | ウィンドウ関数を第一候補にする |
| 対象DBMSが古いバージョンでウィンドウ関数を持たない | 相関サブクエリで代替（本ファイル各節に代替コードを併記） |
| 単純な集約（グループごとに1行へ集約してよい） | 通常の`GROUP BY`＋集約関数で十分。ウィンドウ関数は不要 |
| スキーマ設計やデータモデルの変更で対応すべき性能問題 | クエリ技法の範囲を超えるため `lang:developing-databases` を参照 |

---

## 基本構造

ウィンドウ関数は、突き詰めると次の3つの機能の組み合わせにすぎない。

1. **`PARTITION BY`句**によるレコード集合のカット（`GROUP BY`からグループ化＝集約の機能だけを除いたもの）
2. **`ORDER BY`句**によるパーティション内でのレコードの順序付け
3. **フレーム句**によるカレント行を基準にしたサブセットの定義

```sql
-- 無名ウィンドウ構文（実務でよく使われる簡略形）
SELECT product_id, product_name, unit_price,
       AVG(unit_price) OVER (ORDER BY product_id
                              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg
  FROM Products;

-- 名前付きウィンドウ構文（同じウィンドウを使い回す場合に有用）
SELECT product_id, product_name, unit_price,
       AVG(unit_price)   OVER w AS moving_avg,
       SUM(unit_price)   OVER w AS moving_sum,
       COUNT(unit_price) OVER w AS moving_count
  FROM Products
WINDOW w AS (ORDER BY product_id ROWS BETWEEN 2 PRECEDING AND CURRENT ROW);
```

名前付きウィンドウ構文をサポートしないDBMSもあるため、移植性を優先するなら無名構文をデフォルトに選び、複数箇所で同一ウィンドウを使い回す場合のみ名前付き構文の採用をDBMSの対応状況とあわせて検討する。

### フレーム句のキーワード

| キーワード | 意味 |
|-----------|------|
| `UNBOUNDED PRECEDING` | パーティションの先頭（上限） |
| `n PRECEDING` | カレント行からn行前 |
| `CURRENT ROW` | カレント行 |
| `n FOLLOWING` | カレント行からn行後 |
| `UNBOUNDED FOLLOWING` | パーティションの末尾（下限） |

フレーム句を省略した場合は `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` を指定したものと同じ動作になる（DBMSによる差異があるため要検証）。

### `ROWS` と `RANGE` の使い分け

| 指定方法 | 基準 | 適したケース |
|---------|------|-------------|
| `ROWS` | 物理的な行数 | 連番のような密なデータ、行が歯抜けでも「隣の行」を扱いたい場合 |
| `RANGE` | `ORDER BY`列の値そのもの | 日付や数値が連続していることを前提に「1日前」「1単位前」を扱いたい場合 |

日付データに歯抜け（欠測日）がある場合、`RANGE BETWEEN interval '1' day PRECEDING AND interval '1' day PRECEDING` のような指定では該当データが存在せずNULLになることがある。歯抜けを無視して「物理的な直前の行」を取得したいなら `ROWS` を使う（具体例は後述の「成長・後退・現状維持の判定」を参照）。

### 関数によって使える句が異なる

すべてのウィンドウ関数が `PARTITION BY` / `ORDER BY` / フレーム句を自由に組み合わせられるわけではない。

| 分類 | 代表的な関数 | `PARTITION BY` | `ORDER BY` | フレーム句 |
|------|-------------|----------------|-----------|-----------|
| 番号付け関数 | `RANK` / `DENSE_RANK` / `ROW_NUMBER` / `NTILE` | オプション | 必須 | 利用不可 |
| ナビゲーション関数 | `FIRST_VALUE` / `LAST_VALUE` / `NTH_VALUE` | オプション | 必須 | オプション（結果に影響する） |
| ナビゲーション関数（オフセット型） | `LEAD` / `LAG` | オプション | 必須 | 利用不可 |
| 集計分析関数 | `SUM` / `AVG` / `COUNT` / `MAX` / `MIN` | オプション | オプション | オプション |

`FIRST_VALUE`・`LAST_VALUE` はフレーム句のデフォルト（`RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`）のままだと `LAST_VALUE` が「カレント行までの最後の値」＝カレント行自身を返してしまう典型的な誤用がある。パーティション全体を対象にしたい場合は `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` を明示する。

---

## 行間比較（フレーム句による行のシフト）

フレーム句を使うと「異なる行の値を自分の行に持ってくる」ことができ、これによって行間比較が容易になる。

```sql
-- 「1行前」の値を取得する
SELECT sample_date AS cur_date,
       MIN(sample_date)
         OVER (ORDER BY sample_date
               ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING) AS prev_date
  FROM LoadSample;

-- 「1行後」の値を取得する場合は PRECEDING を FOLLOWING に変えるだけ
SELECT sample_date AS cur_date,
       MIN(sample_date)
         OVER (ORDER BY sample_date
               ROWS BETWEEN 1 FOLLOWING AND 1 FOLLOWING) AS next_date
  FROM LoadSample;
```

ここで使っている集約関数（`MIN`）自体に特別な意味はない。フレームの範囲を1行に限定しているため、`MAX`でも`SUM`でも結果は同じになる。集約関数はあくまで「1行の値を取り出すための入れ物」として使われている。

「n行前」「n行後」への一般化も、`PRECEDING`/`FOLLOWING`の数値を変えるだけでよい。

```sql
SELECT sample_date,
       MIN(sample_date) OVER (ORDER BY sample_date
                               ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING) AS latest_1,
       MIN(sample_date) OVER (ORDER BY sample_date
                               ROWS BETWEEN 2 PRECEDING AND 2 PRECEDING) AS latest_2,
       MIN(sample_date) OVER (ORDER BY sample_date
                               ROWS BETWEEN 3 PRECEDING AND 3 PRECEDING) AS latest_3
  FROM LoadSample;
```

フレームの定義が異なるため、この3列を名前付きウィンドウで1つにまとめることはできない。

### 判断基準

| 状況 | 使うキーワード |
|------|--------------|
| 直前・直後のちょうど1行だけを参照したい | `ROWS BETWEEN 1 PRECEDING/FOLLOWING AND 1 PRECEDING/FOLLOWING` |
| n行前・n行後を参照したい | `PRECEDING`/`FOLLOWING`の数値をnに変更 |
| データが歯抜けでも物理的な隣接行を扱いたい | `ROWS` |
| 暦日・数値の連続性を前提に「1単位前」を扱いたい | `RANGE` |

---

## 相関サブクエリの置換

かつて行間比較は相関サブクエリの独壇場だったが、コードが複雑になりやすく、パフォーマンスも劣化しやすいという弱点があった。ウィンドウ関数は同じ処理をより簡潔かつ高速に記述できるため、行間比較の第一選択肢になっている。

### 成長・後退・現状維持の判定

前期比で「増えた／減った／変わらなかった」を判定する典型例で比較する。

```sql
-- 相関サブクエリ版
SELECT year, sale,
       CASE
         WHEN sale = (SELECT sale FROM Sales S2 WHERE S2.year = S1.year - 1) THEN '→'
         WHEN sale >  (SELECT sale FROM Sales S2 WHERE S2.year = S1.year - 1) THEN '↑'
         WHEN sale <  (SELECT sale FROM Sales S2 WHERE S2.year = S1.year - 1) THEN '↓'
         ELSE '-'
       END AS trend
  FROM Sales S1
 ORDER BY year;

-- ウィンドウ関数版
SELECT year, current_sale,
       CASE
         WHEN current_sale = pre_sale THEN '→'
         WHEN current_sale >  pre_sale THEN '↑'
         WHEN current_sale <  pre_sale THEN '↓'
         ELSE '-'
       END AS trend
  FROM (SELECT year,
               sale AS current_sale,
               SUM(sale) OVER (ORDER BY year
                                RANGE BETWEEN 1 PRECEDING AND 1 PRECEDING) AS pre_sale
          FROM Sales) TMP
 ORDER BY year;
```

ウィンドウ関数側のポイントは、`SUM`を集約としてではなく「1行だけに絞ったウィンドウから値を取り出す道具」として使っていることである。元のテーブルの行数を変えずに新しい列を追加するだけなので、非破壊的（情報保全的）に動作する。

年度データに歯抜けがある場合、`RANGE BETWEEN 1 PRECEDING AND 1 PRECEDING`（＝「1年前」）では歯抜けの前後で正しく比較できない。「直近の行」を比較したい場合は`RANGE`を`ROWS`に変えるだけで対応できる。相関サブクエリでこの汎用化を行うと、`MAX(year)`を求めるサブクエリがさらにネストし、可読性・性能とも悪化する。

### なぜウィンドウ関数で相関サブクエリを置き換えられるのか

一見まったく異なる構文に見える両者だが、動作原理は共通している。「グループ分類ごとの平均単価より高い商品を選ぶ」という例で確認する。

```sql
-- 相関サブクエリ版：カテゴリごとの平均単価をサブクエリで求め、1行ずつ比較
SELECT category, product_name, unit_price
  FROM Products S1
 WHERE unit_price >
       (SELECT AVG(unit_price) FROM Products S2
         WHERE S1.category = S2.category
         GROUP BY category);

-- ウィンドウ関数版：カテゴリでカットしたウィンドウの平均値を各行に付与してから比較
SELECT product_name, category, unit_price
  FROM (SELECT product_name, category, unit_price,
               AVG(unit_price) OVER (PARTITION BY category) AS avg_price
          FROM Products) TMP
 WHERE unit_price > avg_price;
```

相関サブクエリは「バインド条件で集合を切り出し、その集合に対する計算値と各行を比較する」ことを、テーブルを繰り返し結合しながら実現している。ウィンドウ関数は同じ「集合のカット」を`PARTITION BY`で行い、結果を集約せずに各行へ書き戻すことで同じ結果を得る。つまり両者は**「集合のカット＋行単位のループ」という同じ動作を、異なる構文で表現している**にすぎない。

### パフォーマンス比較

| 観点 | 相関サブクエリ | ウィンドウ関数 |
|------|---------------|----------------|
| 対象テーブルへのアクセス回数 | サブクエリの分だけ増える（典型的には2回以上） | 多くの場合1回のスキャンで済む |
| コードの構造 | サブクエリが「相関」しているため単体実行できず、デバッグしづらい | サブクエリ部分だけを単体実行して動作確認できる |
| 実行計画の安定性 | 結合を伴うため結合アルゴリズムの選択に左右されやすい | ソート1回（+パーティション）のシンプルな計画になりやすい |

ランキングの最小値を求めるサブクエリを使うコードは典型的にテーブルスキャンが2回発生するが、同じ計算をウィンドウ関数の`OVER`句に置き換えると1回のスキャンに削減できることが多い。ウィンドウ関数はソートのコストを新たに払う代わりに、スキャン回数を削減しているとも言える。相関サブクエリの書き換えパターン全般（`IN`→`EXISTS`/`JOIN`等）は `PERFORMANCE-REWRITING.md` を参照。

### オーバーラップする期間の検出

宿泊予約のような期間データで、重複（ダブルブッキング）を検出する例。

```sql
-- 相関サブクエリ版：自分以外の予約と期間が重なっているかをEXISTSで判定
SELECT reserver, start_date, end_date
  FROM Reservations R1
 WHERE EXISTS (SELECT * FROM Reservations R2
                WHERE R1.reserver <> R2.reserver
                  AND (R1.start_date BETWEEN R2.start_date AND R2.end_date
                    OR R1.end_date   BETWEEN R2.start_date AND R2.end_date));

-- ウィンドウ関数版：開始日でソートし、1行後の予約者と開始日を取得して比較
SELECT reserver, next_reserver
  FROM (SELECT reserver, start_date, end_date,
               MAX(start_date) OVER (ORDER BY start_date
                                      ROWS BETWEEN 1 FOLLOWING AND 1 FOLLOWING) AS next_start_date,
               MAX(reserver)   OVER (ORDER BY start_date
                                      ROWS BETWEEN 1 FOLLOWING AND 1 FOLLOWING) AS next_reserver
          FROM Reservations) TMP
 WHERE next_start_date BETWEEN start_date AND end_date;
```

ウィンドウ関数版は「誰と誰が重複しているか」をペアで直接出力できるため、3件以上が連鎖して重複しているケースでも、どの予約者同士を調整すべきかが結果から読み取りやすい。

### 判断基準：ウィンドウ関数 vs 相関サブクエリ

| 状況 | 推奨 |
|------|------|
| 対象DBMSがウィンドウ関数をサポートしている | ウィンドウ関数を使う（可読性・性能とも優位） |
| レガシーDBMSでウィンドウ関数が使えない | 相関サブクエリで代替し、将来の移行を見据えてロジックをコメントで明示する |
| 重複ペアなど「相手が誰か」を結果に含めたい | ウィンドウ関数（`LEAD`/`LAG`や1行シフトの技法で相手の情報も同じ行に持てる） |

---

## ランキングと行番号

### `ROW_NUMBER` / `RANK` / `DENSE_RANK` の違い

3つの番号付け関数は、同順位の扱いが異なる。

| 関数 | 同じ値が複数ある場合の挙動 | 例（値: 100, 90, 90, 80） |
|------|--------------------------|---------------------------|
| `ROW_NUMBER` | 同じ値でも一意の連番を振る（並び順は不定） | 1, 2, 3, 4 |
| `RANK` | 同順位に同じ番号を振り、次の番号を欠番にする | 1, 2, 2, 4 |
| `DENSE_RANK` | 同順位に同じ番号を振るが、次の番号は欠番にしない | 1, 2, 2, 3 |

「自然数の連続性・一意性」を利用するテクニック（中央値の算出など）では、欠番や重複が起きない`ROW_NUMBER`を使う必要がある。`RANK`や`DENSE_RANK`を誤って使うと、番号が飛んだり重複したりして計算が壊れる。

### 主キーの構成に応じたナンバリング

```sql
-- 主キーが1列の場合
SELECT student_id, ROW_NUMBER() OVER (ORDER BY student_id) AS seq
  FROM Students;

-- 相関サブクエリで代替する場合（ROW_NUMBER非対応環境向け）
SELECT student_id,
       (SELECT COUNT(*) FROM Students S2
         WHERE S2.student_id <= S1.student_id) AS seq
  FROM Students S1;

-- 主キーが複数列の場合はORDER BYに列を追加するだけ
SELECT class, student_id, ROW_NUMBER() OVER (ORDER BY class, student_id) AS seq
  FROM Students;

-- グループ（クラス）ごとに連番を振り直す場合はPARTITION BYを追加する
SELECT class, student_id, ROW_NUMBER() OVER (PARTITION BY class ORDER BY student_id) AS seq
  FROM Students;
```

複合主キーを相関サブクエリで扱う場合は、行式（`(S2.class, S2.student_id) <= (S1.class, S1.student_id)`）を使うと、暗黙の型変換を避けつつ列数の増減にも対応しやすい。

`UPDATE`文でナンバリング結果を書き込む場合、`ROW_NUMBER`はサブクエリを介して`SET`句に埋め込む必要があるDBMSが多い一方、相関サブクエリはそのまま`SET`句に書けるという違いがある。DBMSごとの`UPDATE`文の構文差はここで詳細に扱わず、対象DBMSのドキュメントで確認すること。

### BigQueryの例：ランキングとデシル分析

```sql
-- 顧客ごとに商品別購入金額の順位を求める（BigQuery）
WITH master AS (
  SELECT user_id, product_id, SUM(revenue) AS sum_rev
    FROM sample.sales
   GROUP BY user_id, product_id
)
SELECT user_id, product_id, sum_rev,
       RANK() OVER (PARTITION BY user_id ORDER BY sum_rev DESC) AS revenue_rank
  FROM master;

-- NTILEによるデシル分析（10等分のグループに分割）
SELECT user_id, sum_rev,
       NTILE(10) OVER (ORDER BY sum_rev DESC) AS decile
  FROM (SELECT user_id, SUM(revenue) AS sum_rev FROM sample.sales GROUP BY user_id);
```

`RANK`は「顧客ごとの1位商品」を集計することで、単純な売上合計ランキングでは見えない「本当に支持されている商品」を分析する用途に使える。`NTILE`は購入金額の上位n%層を切り出すデシル分析・パーセンタイル分析で使われる。

デシル分析と同じく顧客を層やランクに切り分ける実務定型分析（RFM分析・ABC分析）は`CASE-AND-AGGREGATION.md`を参照。

### 判断基準

| 状況 | 推奨関数 |
|------|---------|
| 同順位を許さず一意の連番が必要（中央値算出、ページネーション等） | `ROW_NUMBER` |
| 同順位に同じ順位を振りたいが、次順位を空けたい（一般的な順位表） | `RANK` |
| 同順位に同じ順位を振り、順位を詰めたい | `DENSE_RANK` |
| 上位n%層への分割（デシル分析等） | `NTILE` |

---

## 応用技法

### 中央値（メジアン）の算出

伝統的な集合指向の解法は、自己結合とHAVING句の特性関数で上位集合・下位集合を切り分ける必要があり複雑になりやすい（`CASE-AND-AGGREGATION.md`参照）。ウィンドウ関数を使えば自己結合なしで求められる。

```sql
-- ウィンドウ関数による解法1：両端から同時に数えて中心を求める
SELECT AVG(weight) AS median
  FROM (SELECT weight,
               ROW_NUMBER() OVER (ORDER BY weight ASC)  AS hi,
               ROW_NUMBER() OVER (ORDER BY weight DESC) AS lo
          FROM Weights) TMP
 WHERE hi IN (lo, lo + 1, lo - 1);

-- ウィンドウ関数による解法2：行数を2倍に見立てて折り返し地点を求める（ソート1回で済む）
SELECT AVG(weight)
  FROM (SELECT weight,
               2 * ROW_NUMBER() OVER (ORDER BY weight) - COUNT(*) OVER () AS diff
          FROM Weights) TMP
 WHERE diff BETWEEN 0 AND 2;
```

解法1はソートが2回（昇順・降順）発生するのに対し、解法2は`COUNT(*) OVER ()`（フレーム句にORDER BYがないため全体を1回のソートで扱える）を利用してソート1回で完結する。中央値のように「自然数の連続性・一意性」を使う計算では、`ORDER BY`のキーに一意性を保証する列（主キー等）を含めないと、同値が複数ある場合に結果がNULLになることがある点にも注意する。

### 欠番・連続区間の検出（ギャップ＆アイランド）

座席の空き状況やID列の欠番検出など、「連続する区間」を求める問題は業務でよく発生する。

```sql
-- 欠番のカタマリを求める：集合指向的な解法（自己結合が必要）
SELECT (N1.num + 1) AS gap_start, (MIN(N2.num) - 1) AS gap_end
  FROM Numbers N1 INNER JOIN Numbers N2 ON N2.num > N1.num
 GROUP BY N1.num
HAVING (N1.num + 1) < MIN(N2.num);

-- 欠番のカタマリを求める：ウィンドウ関数による解法（結合不要）
SELECT num + 1 AS gap_start, (num + diff - 1) AS gap_end
  FROM (SELECT num,
               MAX(num) OVER (ORDER BY num
                               ROWS BETWEEN 1 FOLLOWING AND 1 FOLLOWING) - num AS diff
          FROM Numbers) TMP
 WHERE diff <> 1;
```

集合指向の解法は「起点となる行より大きい数値の集合」を自己結合で作るため結合コストがかかる一方、ウィンドウ関数の解法は「1行あとの値との差分」を直接比較するだけで済み、結合を必要としない。存在する連続区間（空席のカタマリ）を求める場合も同様の考え方で、`MAX`/`MIN`を使った自己結合か、`ROW_NUMBER`と前後の差分を組み合わせたウィンドウ関数のいずれかで解ける。

n人分の連続した空席を探す問題も、フレーム句で解決できる。

```sql
-- n人分の連続した空席を探す：ウィンドウ関数版
SELECT seat, seat + (:party_size - 1) AS end_seat
  FROM (SELECT seat,
               MAX(seat) OVER (ORDER BY seat
                                 ROWS BETWEEN (:party_size - 1) FOLLOWING
                                          AND (:party_size - 1) FOLLOWING) AS end_seat
          FROM Seats
         WHERE status = '空') TMP
 WHERE end_seat - seat = (:party_size - 1);
```

座席が路線・車両のように途中で区切られる場合は、`PARTITION BY`に区切りのキー（路線ID等）を追加するだけで対応できる。同じ問題を`NOT EXISTS`による全称量化で解くアプローチは`SET-OPERATIONS-AND-QUANTIFICATION.md`を参照。

### 単調増加・単調減少区間の検出

株価の連続上昇期間のように「ある条件を満たす行が連続している区間」を求める場合は、まず条件判定にウィンドウ関数を使い、続いて連続区間のグループ化を行う2段階アプローチが有効である。

```sql
-- 前回の値と比較して上昇・下落・変わらずを判定する
SELECT deal_date, price,
       CASE SIGN(price - MAX(price)
                          OVER (ORDER BY deal_date
                                ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING))
         WHEN 1 THEN 'up' WHEN 0 THEN 'stay' WHEN -1 THEN 'down' ELSE NULL
       END AS trend
  FROM StockPrices;
```

「上昇」と判定された行だけに`ROW_NUMBER`で連番を振り、「連番－行番号」が一定であるかどうかで連続区間をグループ化するのが定石である。この後段のグループ化は自己結合でも実装できるが、対象行数が絞り込まれているため結合コストは相対的に小さい。

### アクセスログのセッション分析

アクセスログのようなイベント単位の記録を「セッション」という意味のある単位に区切って行動を分析する手法は、実務で頻出する。仕組みは新しいものではなく、直前の2節で導入した2つのイディオム——「`LAG`／フレーム句による前行との差分」と「条件判定によるフラグ立て→連続区間のグループ化」——をそのまま積み上げるだけで実現できる。

まず`LAG`で前行のタイムスタンプを取得し、現在行との差分が一定のしきい値（例: 30分）を超えていたら「新しいセッションの開始」を意味するフラグを立てる。次にそのフラグを累積和（`SUM(...) OVER (... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`）で積み上げると、フラグが立つたびに1つ繰り上がる連番——すなわちセッションIDが得られる。

```sql
-- セッショナイズ: 30分以上の間隔を境界とし、累積和でセッションIDを付与する
SELECT user_id, ts,
       SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY ts
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS session_id
  FROM (SELECT user_id, ts,
               CASE WHEN LAG(ts) OVER (PARTITION BY user_id ORDER BY ts) IS NULL
                      OR ts - LAG(ts) OVER (PARTITION BY user_id ORDER BY ts) > INTERVAL '30' MINUTE
                    THEN 1 ELSE 0 END AS is_new_session
          FROM AccessLog) TMP;
```

累積和を`PARTITION BY user_id`でユーザーごとに区切っている点が要である。これを落とすと、あるユーザーの境界判定に別ユーザーの行のフラグが混入し、セッションIDがユーザーをまたいで連番になってしまう。

セッションIDを付与できたら、セッション単位でイベント名を発生順に文字列連結し、1つの行動系列として1行に集約する。連結には順序保証のため連結関数に`ORDER BY`を指定する必要があり、関数名を含めて方言差が大きい点に注意する（PostgreSQL/BigQueryは`STRING_AGG(expr, sep ORDER BY ...)`、MySQLは`GROUP_CONCAT(expr ORDER BY ... SEPARATOR sep)`、Oracle/Redshiftは`LISTAGG(expr, sep) WITHIN GROUP (ORDER BY ...)`というように、`ORDER BY`の置き場所自体がDBMSごとに異なる）。

```sql
-- セッション単位でイベント名を発生順に連結する（PostgreSQL/BigQueryの例）
SELECT session_id,
       STRING_AGG(event_name, '->' ORDER BY ts) AS action_sequence
  FROM SessionedLog
 GROUP BY session_id;
```

行動系列を1つの文字列にできれば、あとは正規表現や`LIKE`によるパターンマッチで「特定ページを見た直後に離脱した」「特定の順序でイベントが発生した」といった行動パターンを抽出できる。

```sql
-- 「商品詳細ページを見た直後に離脱した」セッションを抽出する
SELECT session_id, action_sequence
  FROM SessionActions
 WHERE action_sequence LIKE '%->product_detail'
    OR action_sequence = 'product_detail';
```

区切り文字の選定には注意が必要である。イベント名に区切り文字と同じ文字が混入していると、意図しない箇所で系列が区切られたかのように誤読され、パターンマッチが壊れる。単一文字（`,`や`|`等）ではなくイベント名に出現しにくい複数文字の区切り（上記の`->`等）を選ぶか、事前にイベント名で使用可能な文字を制約しておくと安全である。

### 移動平均・累計の取得（BigQueryの例）

```sql
-- 累計：パーティションの先頭から現在行までを合計する
SELECT year, quarter, revenue,
       SUM(revenue) OVER (PARTITION BY year ORDER BY quarter
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS revenue_cumulative
  FROM QuarterlySales;

-- 3項移動平均：カレント行と直前2行を対象に平均を取る
SELECT year_month, revenue,
       AVG(revenue) OVER (ORDER BY year_month
                           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3
  FROM MonthlySales;
```

累計は「フレームの上限をパーティションの先頭に固定し、下限をカレント行に追従させる」（`UNBOUNDED PRECEDING AND CURRENT ROW`）ことで表現し、移動平均は「フレームの上限・下限を両方カレント行に追従させる」（`n PRECEDING AND CURRENT ROW`）ことで表現する、という違いを理解しておくと応用が利く。`PARTITION BY`を追加すれば「年ごとにリセットされる累計」のような集計も自然に書ける。

### 判断基準

| 状況 | 推奨技法 |
|------|---------|
| 中央値・パーセンタイルの算出 | `ROW_NUMBER`の両端比較、または`PERCENTILE_CONT`（対応DBMSの場合） |
| 欠番・連続区間の検出（歯抜けが少ない） | ウィンドウ関数（1行あと/前との差分） |
| 欠番・連続区間の検出（差集合として求めたい） | 連番ビュー＋`EXCEPT`等の集合演算（`SET-OPERATIONS-AND-QUANTIFICATION.md`参照） |
| 累計・移動平均 | 集計分析関数としての`SUM`/`AVG`＋フレーム句 |
| 時間ギャップによるセッション分割 | `LAG`による前行との差分判定＋フラグの累積和（`SUM(...) OVER (... ROWS UNBOUNDED PRECEDING)`）でセッションIDを付与 |
| セッション内の行動系列パターン抽出 | セッション単位で`STRING_AGG`等（方言あり）により発生順に文字列連結し、正規表現/`LIKE`でパターンマッチ |
| 階層構造・タリーテーブルの構築 | ウィンドウ関数の範囲外。`JOINS-AND-SUBQUERIES.md`を参照 |

---

## パフォーマンスと内部動作の要点

- ウィンドウ関数は内部的にソートを伴う処理として実行計画に現れる（PostgreSQLの`WindowAgg`、MySQLの`Using filesort`等）。複数のウィンドウ関数を異なる`ORDER BY`で使うと、その分だけソートが増える可能性がある。
- 同じ`PARTITION BY`・`ORDER BY`を複数の関数で共有する場合は、名前付きウィンドウ構文でDBMSに同一ウィンドウであることを伝えられれば、実装によっては最適化の助けになる。
- 相関サブクエリをウィンドウ関数へ置き換えると、多くの場合テーブルへのアクセス回数が減る（サブクエリ実行の繰り返しがなくなるため）。ただし結果自体は等価でも実行計画は環境によって変わり得るため、性能改善を主張する際は必ず対象環境で実行計画を確認する。
- インデックスオンリースキャンに対応したDBMSでは、ウィンドウ関数の対象列がすべてインデックスに含まれていれば、テーブル本体へのアクセスを回避できることがある。
- 索引設計やクエリ以外のスキーマ変更を伴うチューニングは本ファイルの範囲外。詳細は`PERFORMANCE-REWRITING.md`（クエリ書き換え全般）または`lang:developing-databases`（インデックス・内部構造）を参照。

---

## まとめ

- ウィンドウ関数は「集合のカット（`PARTITION BY`）＋順序付け（`ORDER BY`）＋カレント行基準の範囲定義（フレーム句）」という3機能の組み合わせであり、内部的にはソートを伴うループ処理として実行される。
- 行間比較・ランキング・累計・移動平均を要する場面では、相関サブクエリよりもウィンドウ関数を第一候補にする。可読性・保守性・パフォーマンスのいずれの観点でも優位なことが多い。
- 対象DBMSがウィンドウ関数を持たない、または特定の関数・句をサポートしていない場合にのみ、相関サブクエリによる代替コードを検討する。
- 階層構造の走査（隣接リストモデル・再帰クエリ）や連番生成のためのタリーテーブルはウィンドウ関数の範囲外であり、`JOINS-AND-SUBQUERIES.md`を参照する。
