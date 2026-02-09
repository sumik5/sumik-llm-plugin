# クエリのアンチパターン（第Ⅲ部）

SQLクエリの記述における6つの典型的なアンチパターンと、それぞれの検出方法・解決策を解説します。

---

## 13. フィア・オブ・ジ・アンノウン（Fear of the Unknown）

**問題**: NULLを通常の値として扱う、または通常の値をNULL代わりに使用する
**検出シグナル**: NULL列の検索に等価演算子（=）を使用、フルネーム連結でブランク表示、集計でNULL行が除外される

| 項目 | 内容 |
|------|------|
| 目的 | 欠けている値・不明な値・適用不能な値をデータベースで表現する |
| アンチパターン | NULL = 0やNULL = ''として扱う、`-1`のような特殊値でNULLを代替、`= NULL`で検索 |
| 解決策 | IS NULL/IS NOT NULL述語、IS DISTINCT FROM、COALESCE関数、適切なNOT NULL制約 |
| 例外 | 外部データの読み書き（CSVなど）、複数の欠損状態を区別する必要がある場合 |

**コード例:**

```sql
-- ❌ アンチパターン
SELECT * FROM Bugs WHERE assigned_to = NULL;  -- 常に結果なし
SELECT first_name || ' ' || middle_initial || ' ' || last_name  -- NULLで全体がNULL
FROM Accounts;
SELECT AVG(hours) FROM Bugs WHERE priority <> 1;  -- priority=NULLが除外される

-- ✅ 解決策
SELECT * FROM Bugs WHERE assigned_to IS NULL;
SELECT first_name || COALESCE(' ' || middle_initial || ' ', ' ') || last_name
FROM Accounts;
SELECT * FROM Bugs WHERE assigned_to IS DISTINCT FROM 1;  -- NULLも含む
```

**NULL の3値論理**:
- NULL = NULL → NULL（TRUEではない）
- NULL AND TRUE → NULL
- NOT(NULL) → NULL
- WHERE句ではTRUEのみが行を返す

#### ミニ・アンチパターン: NOT IN (NULL)

NOT IN述語にNULLが含まれると、どの行にもマッチしなくなる。以下の2つのクエリは等価だが、どちらも結果を返さない:

```sql
-- ❌ アンチパターン
SELECT * FROM Bugs WHERE status NOT IN (NULL, 'NEW');
-- 等価だが、NULLのためどの行もマッチしない

-- 書き換え（ド・モルガンの法則）
SELECT * FROM Bugs WHERE NOT (status = NULL OR status = 'NEW');
-- さらに書き換え
SELECT * FROM Bugs WHERE NOT (status = NULL) AND NOT (status = 'NEW');
-- NOT (status = NULL) は依然としてNULL（unknown）
-- AND でunknownと組み合わせると、全体もunknown → マッチしない
```

`NULL`との比較はunknownであり、unknownの否定も依然としてunknown。AND演算子でunknownを含むとクエリ全体がunknownになり、WHERE句は結果を返さない。

---

## 14. アンビギュアスグループ（Ambiguous Groups）

**問題**: GROUP BY句に指定されていない列を選択リストに含める
**検出シグナル**: 「列が GROUP BY 句に含まれていません」エラー、意図しない値が返される（MySQL/SQLite）

| 項目 | 内容 |
|------|------|
| 目的 | グループ内の最大値だけでなく、その行の他の属性も取得したい |
| アンチパターン | 非グループ化列を選択リストに含め、SQLが自動的に正しい行を選ぶと期待する |
| 解決策 | 相関サブクエリ、導出テーブル、外部結合（LEFT OUTER JOIN）、追加の集約関数 |
| 例外 | 関数従属性がある場合（主キーでグループ化し、同テーブルの他列を参照） |

**コード例:**

```sql
-- ❌ アンチパターン
SELECT product_id, MAX(date_reported) AS latest, bug_id
FROM Bugs INNER JOIN BugsProducts USING (bug_id)
GROUP BY product_id;  -- bug_idは単一値の原則に違反

-- ✅ 解決策1: 相関サブクエリ
SELECT bp1.product_id, b1.date_reported AS latest, b1.bug_id
FROM Bugs b1 INNER JOIN BugsProducts bp1 USING (bug_id)
WHERE NOT EXISTS (
  SELECT * FROM Bugs b2 INNER JOIN BugsProducts bp2 USING (bug_id)
  WHERE bp1.product_id = bp2.product_id
    AND b1.date_reported < b2.date_reported
);

-- ✅ 解決策2: 導出テーブル
SELECT m.product_id, m.latest, b1.bug_id
FROM Bugs b1
INNER JOIN BugsProducts bp1 USING (bug_id)
INNER JOIN (
  SELECT bp2.product_id, MAX(b2.date_reported) AS latest
  FROM Bugs b2 INNER JOIN BugsProducts bp2 USING (bug_id)
  GROUP BY bp2.product_id
) m ON bp1.product_id = m.product_id AND b1.date_reported = m.latest;

-- ✅ 解決策3: 外部結合
SELECT bp1.product_id, b1.date_reported AS latest, b1.bug_id
FROM Bugs b1 INNER JOIN BugsProducts bp1 ON b1.bug_id = bp1.bug_id
LEFT OUTER JOIN (Bugs AS b2 INNER JOIN BugsProducts AS bp2 ON b2.bug_id = bp2.bug_id)
  ON (bp1.product_id = bp2.product_id
      AND (b1.date_reported < b2.date_reported
        OR b1.date_reported = b2.date_reported AND b1.bug_id < b2.bug_id))
WHERE b2.bug_id IS NULL;
```

**単一値の原則（Single-Value Rule）**: SELECT句の各列は、グループごとに単一の値でなければならない

#### ミニ・アンチパターン: ポータブルSQL

データベース製品ごとにGROUP BYの動作が異なる。全てのSQL製品で動作する「ポータブルSQL」を書こうとすると以下の問題が生じる:

1. **独自拡張機能を使えない**: 各ベンダーの便利な拡張機能を利用できなくなる
2. **標準SQLでも動作が異なる**: 標準機能でさえ製品ごとに解釈・実装が微妙に異なる

**GROUP BYの例（MySQLとPostgreSQL）**:

```sql
-- ❌ MySQL（ONLY_FULL_GROUP_BY無効時）は許可するが、PostgreSQLはエラー
SELECT product_id, MAX(date_reported) AS latest, bug_id
FROM Bugs INNER JOIN BugsProducts USING (bug_id)
GROUP BY product_id;  -- bug_idは非グループ化列なのでエラーになるべき

-- ✅ 解決策: Adapterデザインパターン
-- データベース製品ごとに差し替え可能なコードを設計し、
-- 各製品の強みを活かせるようにする
```

高い移植性を無理に求めるのではなく、データベース製品に合わせてコードを差し替えられるアーキテクチャを採用すべき。

---

## 15. ランダムセレクション（Random Selection）

**問題**: ORDER BY RAND()でデータをソートし、ランダムな行を取得する
**検出シグナル**: データ増加に伴う極端な性能低下、「ランダム検索が非常に遅い」

| 項目 | 内容 |
|------|------|
| 目的 | データセットからサンプル行をランダムに効率的にフェッチする |
| アンチパターン | ORDER BY RAND() LIMIT 1 でテーブル全体をソート（インデックス利用不可、テーブルスキャン） |
| 解決策 | キー値ベースのランダム選択、オフセットベース選択、ベンダー依存の解決策 |
| 例外 | データセットが小さく、性能が問題にならない場合（例: 50州から1つ選択） |

**コード例:**

```sql
-- ❌ アンチパターン
SELECT * FROM Bugs ORDER BY RAND() LIMIT 1;  -- 全行ソート後に1行だけ取得

-- ✅ 解決策1: 1と最大値の間のランダムキー値
SELECT b1.*
FROM Bugs AS b1
INNER JOIN (
  SELECT CEIL(RAND() * (SELECT MAX(bug_id) FROM Bugs)) AS rand_id
) AS b2 ON b1.bug_id = b2.rand_id;

-- ✅ 解決策2: 欠番の穴の後にあるキー値
SELECT b1.*
FROM Bugs AS b1
INNER JOIN (
  SELECT CEIL(RAND() * (SELECT MAX(bug_id) FROM Bugs)) AS bug_id
) AS b2 ON b1.bug_id >= b2.bug_id
ORDER BY b1.bug_id
LIMIT 1;

-- ✅ 解決策3: オフセットベース（アプリケーションコード）
-- 1. 行数をカウント
SELECT COUNT(*) FROM Bugs;
-- 2. ランダムなオフセット値を計算
-- 3. LIMIT/OFFSETで取得
SELECT * FROM Bugs LIMIT 1 OFFSET ?;

-- ✅ 解決策4: ベンダー依存（SQL Server）
SELECT * FROM Bugs TABLESAMPLE (1 ROWS);
```

**パフォーマンスの問題**: ランダム関数によるソートはインデックスを利用できず、必ずテーブルスキャンが発生する

#### ミニ・アンチパターン: クエリでランダムに複数行を取得する

ランダムに複数行を取得する場合、以下のトレードオフがある:

```sql
-- ❌ 素朴な解決策（コストが高い）
SELECT * FROM Bugs ORDER BY RAND() LIMIT 5;
-- シンプルだが、大量データに対してはテーブルスキャンが発生

-- ✅ 最適化された解決策（複雑）
-- 単一行のランダム選択を5回繰り返す
-- → 重複チェック + リトライロジックが必要
-- → 行数が少ないと無限ループのリスク（4行のテーブルから5行取得など）
```

**選択基準**:
- **高パフォーマンス重視**: 最適化クエリを複数回実行 + 重複チェックロジック
- **シンプルなコード重視**: `ORDER BY RAND() LIMIT N`（データ量が少ない場合）

データセットが小さく性能が問題にならない場合は、素朴な解決策が実用的。

---

## 16. プアマンズ・サーチエンジン（Poor Man's Search Engine）

**問題**: LIKE述語や正規表現でフルテキスト検索を実装する
**検出シグナル**: データ増加で検索が許容できないほど遅くなる、意図しない部分一致

| 項目 | 内容 |
|------|------|
| 目的 | テキスト列に対して語や句による全文検索を行う |
| アンチパターン | `WHERE description LIKE '%crash%'` や正規表現（インデックス利用不可、意図しない一致） |
| 解決策 | ベンダー提供の全文検索機能、サードパーティ検索エンジン、転置インデックスの自作 |
| 例外 | 使用頻度が極めて低いクエリ、データセットが小さい場合、単純なパターンマッチで十分な場合 |

**コード例:**

```sql
-- ❌ アンチパターン
SELECT * FROM Bugs WHERE description LIKE '%crash%';  -- テーブルスキャン
SELECT * FROM Bugs WHERE description REGEXP 'crash';  -- インデックス利用不可
SELECT * FROM Bugs WHERE description LIKE '%one%';  -- 'money', 'prone' も一致

-- ✅ 解決策1: MySQL フルテキストインデックス
ALTER TABLE Bugs ADD FULLTEXT INDEX bugfts (summary, description);
SELECT * FROM Bugs WHERE MATCH(summary, description) AGAINST ('crash');
SELECT * FROM Bugs
WHERE MATCH(summary, description) AGAINST ('+crash -save' IN BOOLEAN MODE);

-- ✅ 解決策2: PostgreSQL テキスト検索
CREATE INDEX bugs_ts ON Bugs USING GIN(ts_bugtext);
SELECT * FROM Bugs WHERE ts_bugtext @@ to_tsquery('crash');

-- ✅ 解決策3: Oracle CONTEXT インデックス
CREATE INDEX BugsText ON Bugs(summary) INDEXTYPE IS CTXSYS.CONTEXT;
SELECT * FROM Bugs WHERE CONTAINS(summary, 'crash') > 0;

-- ✅ 解決策4: 転置インデックス（自作）
CREATE TABLE Keywords (
  keyword_id SERIAL PRIMARY KEY,
  keyword VARCHAR(40) NOT NULL UNIQUE
);
CREATE TABLE BugsKeywords (
  keyword_id BIGINT UNSIGNED NOT NULL,
  bug_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (keyword_id, bug_id),
  FOREIGN KEY (keyword_id) REFERENCES Keywords(keyword_id),
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id)
);
```

**サードパーティ検索エンジン**: Sphinx Search、Apache Lucene/Solr

---

## 17. スパゲッティクエリ（Spaghetti Query）

**問題**: 複雑なタスクを1つのSQLクエリで解決しようとする
**検出シグナル**: SUM/COUNTの結果が異常に大きい、クエリ作成に丸1日かかる、変更が困難

| 項目 | 内容 |
|------|------|
| 目的 | SQLクエリの数を減らし、開発を効率化する |
| アンチパターン | 複数のタスクを1つのクエリに詰め込み、意図しないデカルト積を生成 |
| 解決策 | クエリ分割（分割統治）、UNION、CASE式とSUM関数の組み合わせ |
| 例外 | 単一クエリを要求するBI/レポートツール、複数結果を単一ソート順で表示したい場合 |

**コード例:**

```sql
-- ❌ アンチパターン
SELECT p.product_id,
  COUNT(f.bug_id) AS count_fixed,
  COUNT(o.bug_id) AS count_open
FROM BugsProducts p
INNER JOIN Bugs f ON p.bug_id = f.bug_id AND f.status = 'FIXED'
INNER JOIN BugsProducts p2 USING (product_id)
INNER JOIN Bugs o ON p2.bug_id = o.bug_id AND o.status = 'OPEN'
WHERE p.product_id = 1
GROUP BY p.product_id;
-- 結果: count_fixed=77, count_open=77 (実際は11と7) デカルト積！

-- ✅ 解決策1: クエリ分割
SELECT p.product_id, COUNT(f.bug_id) AS count_fixed
FROM BugsProducts p
LEFT OUTER JOIN Bugs f ON p.bug_id = f.bug_id AND f.status = 'FIXED'
WHERE p.product_id = 1
GROUP BY p.product_id;

SELECT p.product_id, COUNT(o.bug_id) AS count_open
FROM BugsProducts p
LEFT OUTER JOIN Bugs o ON p.bug_id = o.bug_id AND o.status = 'OPEN'
WHERE p.product_id = 1
GROUP BY p.product_id;

-- ✅ 解決策2: UNION
(SELECT p.product_id, 'FIXED' AS status, COUNT(f.bug_id) AS bug_count
 FROM BugsProducts p
 LEFT OUTER JOIN Bugs f ON p.bug_id = f.bug_id AND f.status = 'FIXED'
 WHERE p.product_id = 1
 GROUP BY p.product_id)
UNION ALL
(SELECT p.product_id, 'OPEN' AS status, COUNT(o.bug_id) AS bug_count
 FROM BugsProducts p
 LEFT OUTER JOIN Bugs o ON p.bug_id = o.bug_id AND o.status = 'OPEN'
 WHERE p.product_id = 1
 GROUP BY p.product_id)
ORDER BY bug_count DESC;

-- ✅ 解決策3: CASE式とSUM関数
SELECT p.product_id,
  SUM(CASE b.status WHEN 'FIXED' THEN 1 ELSE 0 END) AS count_fixed,
  SUM(CASE b.status WHEN 'OPEN' THEN 1 ELSE 0 END) AS count_open
FROM BugsProducts p
INNER JOIN Bugs b USING (bug_id)
WHERE p.product_id = 1
GROUP BY p.product_id;
```

**節約の原則**: 同じ結果を生む2つのクエリがある場合、単純な方を選ぶべき

---

## 18. インプリシットカラム（Implicit Columns）

**問題**: SELECT * や列名省略のINSERTでワイルドカードに依存する
**検出シグナル**: 列追加/削除/順序変更でアプリケーションが破損、ネットワーク帯域幅の無駄

| 項目 | 内容 |
|------|------|
| 目的 | タイプ数を減らし、クエリを簡潔にする |
| アンチパターン | `SELECT *`、列名を省略したINSERT（列の変更でエラーや誤動作） |
| 解決策 | 必要な列を明示的に指定する |
| 例外 | アドホックなSQL、1回限りのクエリ、開発時の効率を最優先する場合 |

**コード例:**

```sql
-- ❌ アンチパターン
SELECT * FROM Bugs;
INSERT INTO Accounts VALUES (DEFAULT, 'bkarwin', 'Bill', 'Karwin',
  'bill@example.com', SHA2('xyzzy', 256), NULL, 49.95);
-- 列追加/削除/順序変更でエラーや意図しない動作

-- ✅ 解決策
SELECT bug_id, date_reported, summary, description, resolution,
  reported_by, assigned_to, verified_by, status, priority, hours
FROM Bugs;

INSERT INTO Accounts (account_name, first_name, last_name, email,
  password_hash, portrait_image, hourly_rate)
VALUES ('bkarwin', 'Bill', 'Karwin', 'bill@example.com',
  SHA2('xyzzy', 256), NULL, 49.95);

-- テーブルごとのワイルドカード（許容可能）
SELECT b.*, a.first_name, a.email
FROM Bugs b INNER JOIN Accounts a ON b.reported_by = a.account_id;
```

**メリット**:
- 列順変更の影響を受けない
- 列追加の影響を受けない
- 列削除時にエラーで即座に検出可能（修正箇所が特定しやすい）
- 不要なデータのフェッチを避けられる

**ポカヨケ**: できるだけ早い段階で失敗すべし
