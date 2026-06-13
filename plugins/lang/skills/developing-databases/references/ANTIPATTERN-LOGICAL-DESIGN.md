# 論理設計のアンチパターン

データベースの論理設計における8つの代表的なアンチパターンと、それぞれの解決策を解説します。

---

## 1. ジェイウォーク（Jaywalking）

**問題**: カンマ区切りリストで複数の値を1つの列に格納してしまう
**検出シグナル**: `VARCHAR`列の最大長の議論、正規表現による検索、`LENGTH() - REPLACE()`のような文字列操作

| 項目 | 内容 |
|------|------|
| 目的 | 1つの製品に複数の連絡先を関連付けるなど、多対多の関連を表現したい |
| アンチパターン | `account_id`列に`'12,34,56'`のようなカンマ区切りリストを格納する |
| 解決策 | 交差テーブル（インターセクションテーブル）を作成し、各値を個別の行として格納する |
| 例外 | 非正規化によるパフォーマンス向上が必要で、かつリスト内の各要素への個別アクセスが不要な場合 |

**コード例:**

```sql
-- ❌ アンチパターン
CREATE TABLE Products (
  product_id   SERIAL PRIMARY KEY,
  product_name VARCHAR(1000),
  account_id   VARCHAR(100)  -- '12,34,56'
);

SELECT * FROM Products WHERE account_id REGEXP '[[:<:]]12[[:>:]]';

-- ✅ 解決策
CREATE TABLE Products (
  product_id   SERIAL PRIMARY KEY,
  product_name VARCHAR(1000)
);

CREATE TABLE Contacts (
  product_id  BIGINT UNSIGNED NOT NULL,
  account_id  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (product_id, account_id),
  FOREIGN KEY (product_id) REFERENCES Products(product_id),
  FOREIGN KEY (account_id) REFERENCES Accounts(account_id)
);

INSERT INTO Contacts (product_id, account_id)
VALUES (123, 12), (123, 34), (123, 56);

SELECT p.* FROM Products p
INNER JOIN Contacts c ON p.product_id = c.product_id
WHERE c.account_id = 12;
```

**メリット:**
- インデックスを効果的に使用できる
- 集約関数（`COUNT`、`SUM`など）を簡単に使える
- 外部キー制約でデータ整合性を保証できる
- リスト長の制限がなくなる

#### ミニ・アンチパターン: CSV列を複数の行に分割する

レガシーデータでCSV形式の文字列が既に存在する場合、これを複数行に変換する必要が生じることがあります。

**PostgreSQL**:
```sql
-- string_to_array + unnest
SELECT a FROM Products
CROSS JOIN unnest(string_to_array(account_id, ',')) AS a;
```

**MySQL**:
```sql
-- SUBSTRING_INDEX + 連番テーブル
SELECT p.product_id, p.product_name,
  SUBSTRING_INDEX(SUBSTRING_INDEX(p.account_id, ',', n.n), ',', -1) AS account_id
FROM Products AS p
JOIN (SELECT 1 AS n UNION SELECT 2 UNION SELECT 3) AS n
  ON n.n <= LENGTH(p.account_id) - LENGTH(REPLACE(p.account_id, ',', ''));
```

**再帰CTE**（MySQL 8.0+）:
```sql
WITH RECURSIVE cte AS (
  SELECT product_id, product_name,
    SUBSTRING_INDEX(account_id, ',', 1) AS account_id,
    SUBSTRING(account_id, LENGTH(SUBSTRING_INDEX(account_id, ',', 1))+2) AS remainder
  FROM Products
  UNION ALL
  SELECT product_id, product_name, SUBSTRING_INDEX(remainder, ',', 1),
    SUBSTRING(remainder, LENGTH(SUBSTRING_INDEX(remainder, ',', 1))+2)
  FROM cte
  WHERE LENGTH(remainder) > 0
)
SELECT product_id, product_name, account_id FROM cte;
```

これらの解決策は複雑で製品固有です。最善の方法は最初から適切にデータを格納することです。

---

## 2. ナイーブツリー（Naive Trees）

**問題**: 隣接リスト（`parent_id`のみ）でツリー構造を表現し、深い階層のクエリが困難になる
**検出シグナル**: 「ツリーの深さは何階層までサポートすればいい？」という質問、複数回の再帰的なクエリ実行

| 項目 | 内容 |
|------|------|
| 目的 | コメントのスレッド、組織図など、階層構造のデータを格納・取得したい |
| アンチパターン | `parent_id`列のみで親を参照する隣接リスト設計を採用し、すべての子孫を取得するために複数の`JOIN`が必要になる |
| 解決策 | 経路列挙、入れ子集合、閉包テーブルのいずれかを使用する |
| 例外 | ツリーの深さが固定されており、直近の親子関係のみを扱う場合は隣接リストでも十分 |

**コード例:**

```sql
-- ❌ アンチパターン（隣接リスト）
CREATE TABLE Comments (
  comment_id   SERIAL PRIMARY KEY,
  parent_id    BIGINT UNSIGNED,
  comment      TEXT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Comments(comment_id)
);

-- 4階層までしか取得できない
SELECT c1.*, c2.*, c3.*, c4.*
FROM Comments c1
LEFT OUTER JOIN Comments c2 ON c2.parent_id = c1.comment_id
LEFT OUTER JOIN Comments c3 ON c3.parent_id = c2.comment_id
LEFT OUTER JOIN Comments c4 ON c4.parent_id = c3.comment_id;

-- ✅ 解決策1: 経路列挙
CREATE TABLE Comments (
  comment_id   SERIAL PRIMARY KEY,
  path         VARCHAR(1000),  -- '1/4/6/7/'
  comment      TEXT NOT NULL
);

-- すべての子孫を取得
SELECT * FROM Comments
WHERE path LIKE '1/4/%';

-- ✅ 解決策2: 閉包テーブル
CREATE TABLE Comments (
  comment_id   SERIAL PRIMARY KEY,
  comment      TEXT NOT NULL
);

CREATE TABLE TreePaths (
  ancestor    BIGINT UNSIGNED NOT NULL,
  descendant  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (ancestor, descendant),
  FOREIGN KEY (ancestor) REFERENCES Comments(comment_id),
  FOREIGN KEY (descendant) REFERENCES Comments(comment_id)
);

-- すべての子孫を取得
SELECT c.* FROM Comments c
INNER JOIN TreePaths t ON c.comment_id = t.descendant
WHERE t.ancestor = 4;
```

**各手法の選択指針:**

| 手法 | 長所 | 短所 | 適用場面 |
|------|------|------|----------|
| 経路列挙 | シンプル、先祖・子孫取得が容易 | パス長に制限、参照整合性の保証が困難 | 読み取り中心、深さが予測可能 |
| 入れ子集合 | サブツリー取得が高速 | 挿入・更新のコストが高い | 読み取り専用、頻繁な再編成が不要 |
| 閉包テーブル | 柔軟性が高い、整合性保証が容易 | ストレージ使用量が多い | 頻繁な更新、複雑なクエリが必要 |

#### ミニ・アンチパターン: 開発環境と本番環境の差異

開発環境で新しいデータベースバージョンを使用している場合、本番環境にデプロイしたときだけコードが動作しないことがあります。

**問題の例**:
```sql
-- MySQL 8.0+のCTEを使用
WITH RECURSIVE cte AS (
  SELECT comment_id, parent_id, 1 AS depth FROM Comments WHERE parent_id IS NULL
  UNION ALL
  SELECT c.comment_id, c.parent_id, cte.depth+1
  FROM Comments c JOIN cte ON c.parent_id = cte.comment_id
)
SELECT * FROM cte;
```

MySQL 7.x本番環境にデプロイすると：
```
Error: 1064 You have an error in your SQL syntax near 'WITH'
```

**解決策**:
- 開発環境のDBバージョンを本番と一致させる（マイナーバージョンまで）
- データベース設定オプションも一致させる
- コンテナ化（Docker）で環境の一貫性を保証する
- バージョン固有の新機能に依存する前に本番環境の対応を確認する

---

## 3. IDリクワイアド（ID Required）

**問題**: すべてのテーブルに`id`という名前の疑似キー列を強制的に設定する
**検出シグナル**: すべてのテーブルの主キーが`id`、交差テーブルでの重複許可、`USING`句が使えない

| 項目 | 内容 |
|------|------|
| 目的 | テーブルの各行を一意に識別する主キーを設定したい |
| アンチパターン | すべてのテーブルで主キーを`id`という名前の疑似キーにし、自然キーや複合キーを避ける |
| 解決策 | テーブルの性質に応じて、自然キー、複合キー、または意味のある名前の疑似キーを選択する |
| 例外 | ORM（Ruby on Railsなど）の規約に従う場合、ただし主キー名はカスタマイズ可能 |

**コード例:**

```sql
-- ❌ アンチパターン
CREATE TABLE Bugs (
  id            SERIAL PRIMARY KEY,  -- すべて'id'
  reported_by   BIGINT UNSIGNED,
  FOREIGN KEY (reported_by) REFERENCES Accounts(id)
);

CREATE TABLE BugsProducts (
  id          SERIAL PRIMARY KEY,
  bug_id      BIGINT UNSIGNED NOT NULL,
  product_id  BIGINT UNSIGNED NOT NULL
  -- 重複を防げない！
);

-- ✅ 解決策1: 意味のある名前を使用
CREATE TABLE Bugs (
  bug_id        SERIAL PRIMARY KEY,  -- 'bug_id'と明示
  reported_by   BIGINT UNSIGNED,
  FOREIGN KEY (reported_by) REFERENCES Accounts(account_id)
);

-- USING句が使える
SELECT * FROM Bugs
INNER JOIN BugsProducts USING (bug_id);

-- ✅ 解決策2: 複合主キー（交差テーブル）
CREATE TABLE BugsProducts (
  bug_id      BIGINT UNSIGNED NOT NULL,
  product_id  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (bug_id, product_id),  -- 重複防止
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id),
  FOREIGN KEY (product_id) REFERENCES Products(product_id)
);
```

**命名のベストプラクティス:**
- 主キー名はテーブルの種類を表す（`bug_id`、`account_id`など）
- 外部キーも同じ命名規則を使う（参照整合性が明確になる）
- ISO/IEC 11179の命名規則を参照

#### ミニ・アンチパターン: BIGINTは十分に大きい？

自動インクリメントIDが最大値に達することを心配する声がありますが、`BIGINT`の容量は膨大です。

**計算例**（毎分10,000行挿入する場合）:

- **INT（32ビット符号付き）**: 最大値 2,147,483,647
  - 枯渇まで: 約149日
- **INT UNSIGNED（32ビット符号なし）**: 最大値 4,294,967,295
  - 枯渇まで: 約298日
- **BIGINT（64ビット符号付き）**: 最大値 9,223,372,036,854,775,807
  - 枯渇まで: 約**17億5千万年**

`BIGINT`は実質的に枯渇しません。通常のアプリケーションで`BIGINT`が不足することはありえないと保証できます。

---

## 4. キーレスエントリ（Keyless Entry）

**問題**: 外部キー制約を宣言せず、アプリケーションコードで参照整合性を保証しようとする
**検出シグナル**: 孤児行検出クエリの作成、データ品質管理スクリプトの定期実行、「外部キーは遅い」という主張

| 項目 | 内容 |
|------|------|
| 目的 | データベース設計をシンプルにし、柔軟性を高めたい |
| アンチパターン | 外部キー制約を省略し、アプリケーションコードで参照整合性を維持しようとする |
| 解決策 | 外部キー制約を宣言し、カスケード更新（`ON UPDATE CASCADE`、`ON DELETE CASCADE`など）を活用する |
| 例外 | 外部キーをサポートしないDBMS（古いMySQL MyISAM、SQLite 3.6.19未満）を使用する場合 |

**コード例:**

```sql
-- ❌ アンチパターン
CREATE TABLE Bugs (
  bug_id        SERIAL PRIMARY KEY,
  reported_by   BIGINT UNSIGNED NOT NULL,
  status        VARCHAR(20) NOT NULL
  -- 外部キー制約なし
);

-- アプリケーションコードで事前チェック（競合状態のリスク）
SELECT account_id FROM Accounts WHERE account_id = 1;
INSERT INTO Bugs (reported_by) VALUES (1);

-- 孤児行検出クエリ（本来不要な作業）
SELECT b.bug_id, b.reported_by
FROM Bugs b LEFT OUTER JOIN Accounts a
  ON b.reported_by = a.account_id
WHERE a.account_id IS NULL;

-- ✅ 解決策
CREATE TABLE Bugs (
  bug_id        SERIAL PRIMARY KEY,
  reported_by   BIGINT UNSIGNED NOT NULL,
  status        VARCHAR(20) NOT NULL DEFAULT 'NEW',
  FOREIGN KEY (reported_by) REFERENCES Accounts(account_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  FOREIGN KEY (status) REFERENCES BugStatus(status)
    ON UPDATE CASCADE
    ON DELETE SET DEFAULT
);

-- データベースが自動的に整合性を保証
INSERT INTO Bugs (reported_by) VALUES (1);  -- アカウント1が存在しなければエラー
```

**カスケードオプション:**

| オプション | 動作 |
|-----------|------|
| `RESTRICT` | 親行の削除/更新を拒否（子行が存在する場合） |
| `CASCADE` | 親行の削除/更新時に子行も自動的に削除/更新 |
| `SET NULL` | 親行の削除/更新時に子行の外部キー列を`NULL`に設定 |
| `SET DEFAULT` | 親行の削除/更新時に子行の外部キー列をデフォルト値に設定 |
| `NO ACTION` | `RESTRICT`と同様だが、チェックをトランザクション終了まで遅延可能 |

---

## 5. EAV（Entity-Attribute-Value）

**問題**: 汎用的な属性テーブルで可変属性を扱い、データ型やクエリの制約が失われる
**検出シグナル**: `attr_name`と`attr_value`のような列名、`MAX(CASE WHEN ...)`を使った複雑なクエリ

| 項目 | 内容 |
|------|------|
| 目的 | 行ごとに異なる属性を持つオブジェクト（サブタイプ）を1つのテーブルに格納したい |
| アンチパターン | エンティティ、属性名、値の3列からなる汎用属性テーブルを作成し、すべてをそこに格納する |
| 解決策 | サブタイプモデリング（シングルテーブル継承、具象テーブル継承、クラステーブル継承）を使用する |
| 例外 | 動的に属性を追加できる必要があり、かつ属性の数が非常に多く（100以上）、大半の行で属性が未定義な場合 |

**コード例:**

```sql
-- ❌ アンチパターン
CREATE TABLE Issues (
  issue_id    SERIAL PRIMARY KEY
);

CREATE TABLE IssueAttributes (
  issue_id    BIGINT UNSIGNED NOT NULL,
  attr_name   VARCHAR(100) NOT NULL,
  attr_value  VARCHAR(100),  -- すべてVARCHAR
  PRIMARY KEY (issue_id, attr_name)
);

INSERT INTO IssueAttributes (issue_id, attr_name, attr_value)
VALUES
  (1234, 'product', '1'),
  (1234, 'date_reported', '2009-06-01'),
  (1234, 'status', 'NEW'),
  (1234, 'severity', '機能の損失');

-- 複雑なクエリが必要
SELECT issue_id,
  MAX(CASE WHEN attr_name = 'date_reported' THEN attr_value END) AS date_reported,
  MAX(CASE WHEN attr_name = 'status' THEN attr_value END) AS status
FROM IssueAttributes
GROUP BY issue_id;

-- ✅ 解決策1: シングルテーブル継承
CREATE TABLE Issues (
  issue_id          SERIAL PRIMARY KEY,
  reported_by       BIGINT UNSIGNED NOT NULL,
  product_id        BIGINT UNSIGNED,
  priority          VARCHAR(20),
  issue_type        VARCHAR(10),  -- 'BUG' or 'FEATURE'
  -- Bug固有
  severity          VARCHAR(20),
  version_affected  VARCHAR(20),
  -- FeatureRequest固有
  sponsor           VARCHAR(50)
);

-- ✅ 解決策2: 具象テーブル継承
CREATE TABLE Bugs (
  issue_id          SERIAL PRIMARY KEY,
  reported_by       BIGINT UNSIGNED NOT NULL,
  severity          VARCHAR(20),
  version_affected  VARCHAR(20)
);

CREATE TABLE FeatureRequests (
  issue_id          SERIAL PRIMARY KEY,
  reported_by       BIGINT UNSIGNED NOT NULL,
  sponsor           VARCHAR(50)
);

-- ✅ 解決策3: クラステーブル継承
CREATE TABLE Issues (
  issue_id    SERIAL PRIMARY KEY,
  reported_by BIGINT UNSIGNED NOT NULL,
  product_id  BIGINT UNSIGNED,
  priority    VARCHAR(20)
);

CREATE TABLE Bugs (
  issue_id          BIGINT UNSIGNED PRIMARY KEY,
  severity          VARCHAR(20),
  version_affected  VARCHAR(20),
  FOREIGN KEY (issue_id) REFERENCES Issues(issue_id)
);

CREATE TABLE FeatureRequests (
  issue_id  BIGINT UNSIGNED PRIMARY KEY,
  sponsor   VARCHAR(50),
  FOREIGN KEY (issue_id) REFERENCES Issues(issue_id)
);
```

**サブタイプモデリング手法の比較:**

| 手法 | 長所 | 短所 | 適用場面 |
|------|------|------|----------|
| シングルテーブル継承 | クエリが簡単、テーブル数が少ない | 多くの`NULL`、列数制限の問題 | サブタイプが少なく、属性の重複が多い |
| 具象テーブル継承 | サブタイプごとに最適化可能 | 共通属性の重複、すべてのサブタイプへのクエリが困難 | サブタイプ間のクエリがほとんど不要 |
| クラステーブル継承 | 正規化、データ重複なし | 結合が必要、テーブル数が増加 | サブタイプが多く、共通属性が多い |

---

## 6. ポリモーフィック関連（Polymorphic Associations）

**問題**: 1つの外部キー列が複数の親テーブルを参照する
**検出シグナル**: `issue_type`のような「タイプ識別子」列、外部キー制約の欠如、「メタデータのトリブル」パターン

| 項目 | 内容 |
|------|------|
| 目的 | 複数のタイプのオブジェクト（BugとFeatureRequest）に同じようにコメントを関連付けたい |
| アンチパターン | `issue_id`列と`issue_type`列を使い、1つの外部キーで複数のテーブルを参照する |
| 解決策 | タイプごとに独立した外部キー列を作成するか、共通の親テーブルを作成する |
| 例外 | フレームワーク（Ruby on Rails等）がポリモーフィック関連を強制し、かつアプリケーションコードで整合性を保証できる場合 |

**コード例:**

```sql
-- ❌ アンチパターン
CREATE TABLE Comments (
  comment_id  SERIAL PRIMARY KEY,
  issue_type  VARCHAR(20),  -- 'Bugs' or 'FeatureRequests'
  issue_id    BIGINT UNSIGNED NOT NULL,
  comment     TEXT
  -- 外部キー制約を宣言できない！
);

-- アプリケーションコードでタイプを判定
SELECT * FROM Comments WHERE issue_type = 'Bugs' AND issue_id = 1234;

-- ✅ 解決策1: 交差テーブル（逆参照）
CREATE TABLE BugComments (
  issue_id    BIGINT UNSIGNED NOT NULL,
  comment_id  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (issue_id, comment_id),
  FOREIGN KEY (issue_id) REFERENCES Bugs(issue_id),
  FOREIGN KEY (comment_id) REFERENCES Comments(comment_id)
);

CREATE TABLE FeatureComments (
  issue_id    BIGINT UNSIGNED NOT NULL,
  comment_id  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (issue_id, comment_id),
  FOREIGN KEY (issue_id) REFERENCES FeatureRequests(issue_id),
  FOREIGN KEY (comment_id) REFERENCES Comments(comment_id)
);

-- ✅ 解決策2: 共通の親テーブル
CREATE TABLE Issues (
  issue_id    SERIAL PRIMARY KEY
);

CREATE TABLE Bugs (
  issue_id    BIGINT UNSIGNED PRIMARY KEY,
  FOREIGN KEY (issue_id) REFERENCES Issues(issue_id)
);

CREATE TABLE FeatureRequests (
  issue_id    BIGINT UNSIGNED PRIMARY KEY,
  FOREIGN KEY (issue_id) REFERENCES Issues(issue_id)
);

CREATE TABLE Comments (
  comment_id  SERIAL PRIMARY KEY,
  issue_id    BIGINT UNSIGNED NOT NULL,
  comment     TEXT,
  FOREIGN KEY (issue_id) REFERENCES Issues(issue_id)
);
```

---

## 7. マルチカラムアトリビュート（Multicolumn Attributes）

**問題**: 同じ種類の属性を複数の列（`tag1`、`tag2`、`tag3`）として定義する
**検出シグナル**: 列名に連番が付いている、`OR`を多用したクエリ、「いくつまで列を追加すればいい？」という質問

| 項目 | 内容 |
|------|------|
| 目的 | 1つのバグに複数のタグを関連付けたい |
| アンチパターン | `tag1`、`tag2`、`tag3`のように、同じ種類の属性を複数の列として定義する |
| 解決策 | 従属テーブルを作成し、各値を個別の行として格納する |
| 例外 | 属性の数が厳密に固定されている場合（例: 経度・緯度、RGB値） |

**コード例:**

```sql
-- ❌ アンチパターン
CREATE TABLE Bugs (
  bug_id   SERIAL PRIMARY KEY,
  tag1     VARCHAR(20),
  tag2     VARCHAR(20),
  tag3     VARCHAR(20)
);

-- 複雑なクエリ
SELECT * FROM Bugs
WHERE tag1 = 'crash' OR tag2 = 'crash' OR tag3 = 'crash';

-- 集約が困難
SELECT tag1 AS tag FROM Bugs
UNION
SELECT tag2 AS tag FROM Bugs
UNION
SELECT tag3 AS tag FROM Bugs;

-- ✅ 解決策
CREATE TABLE Tags (
  bug_id  BIGINT UNSIGNED NOT NULL,
  tag     VARCHAR(20),
  PRIMARY KEY (bug_id, tag),
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id)
);

INSERT INTO Tags (bug_id, tag)
VALUES (1234, 'crash'), (1234, 'save'), (1234, 'performance');

-- シンプルなクエリ
SELECT * FROM Bugs
INNER JOIN Tags USING (bug_id)
WHERE tag = 'crash';

-- 集約も容易
SELECT tag, COUNT(*) AS bugs_per_tag
FROM Tags
GROUP BY tag;
```

#### ミニ・アンチパターン: 価格の保存

交差テーブルに「現在の値」を保存すると冗長に見えますが、時系列データでは必要です。

**問題**: 商品価格は変動するため、過去の注文の価格と現在の商品マスタの価格が一致しない。

```sql
-- ❌ 誤った設計（価格を保存しない）
CREATE TABLE Orders (
  order_id SERIAL PRIMARY KEY,
  order_date DATE NOT NULL,
  customer_id INT NOT NULL,
  merchandise_id INT NOT NULL,  -- 外部キーのみ
  quantity INT NOT NULL
);

CREATE TABLE Merchandise (
  merchandise_id SERIAL PRIMARY KEY,
  product_name VARCHAR(200),
  price NUMERIC(9,2)  -- 現在の価格
);

-- 過去の注文の金額が不正確になる
SELECT SUM(m.price * o.quantity) AS total
FROM Orders o
JOIN Merchandise m USING (merchandise_id)
WHERE order_date = '2024-01-15';
-- 結果: 現在の価格で計算されてしまう（誤り）

-- ✅ 正しい設計（注文時の価格を保存）
CREATE TABLE Orders (
  order_id SERIAL PRIMARY KEY,
  order_date DATE NOT NULL,
  customer_id INT NOT NULL,
  merchandise_id INT NOT NULL,
  quantity INT NOT NULL,
  price NUMERIC(9,2) NOT NULL,  -- 注文時の価格を保存
  FOREIGN KEY (merchandise_id) REFERENCES Merchandise(merchandise_id)
);

-- 正確な金額計算
SELECT SUM(price * quantity) AS total
FROM Orders
WHERE order_date = '2024-01-15';
-- 結果: 注文時の価格で正確に計算される
```

**原則**: 時点データ（注文時価格、試合時のメンバー、映画クレジット時の芸名など）は交差テーブルに保存する。これは冗長ではなく、異なるファクトの記録です。

---

## 8. メタデータトリブル（Metadata Tribbles）

**問題**: テーブルや列を年度・カテゴリごとにコピーして増殖させる
**検出シグナル**: `Bugs_2023`、`Bugs_2024`のようなテーブル名、列名に年度が含まれる、毎年DDLの変更が必要

| 項目 | 内容 |
|------|------|
| 目的 | 年度別やカテゴリ別にデータを整理したい |
| アンチパターン | テーブルや列を時間・カテゴリごとにクローンし、メタデータを増殖させる |
| 解決策 | パーティショニングを使用するか、時間・カテゴリを列として正規化する |
| 例外 | アーカイブ目的で過去データを別テーブルに移動する場合（ただしビューで統合する） |

**コード例:**

```sql
-- ❌ アンチパターン（テーブルのクローン）
CREATE TABLE Bugs_2023 (...);
CREATE TABLE Bugs_2024 (...);
CREATE TABLE Bugs_2025 (...);

-- すべてのテーブルにクエリが必要
SELECT * FROM Bugs_2023 WHERE ...
UNION ALL
SELECT * FROM Bugs_2024 WHERE ...
UNION ALL
SELECT * FROM Bugs_2025 WHERE ...;

-- ❌ アンチパターン（列のクローン）
CREATE TABLE ProjectHistory (
  project_id    SERIAL PRIMARY KEY,
  year_2023     INT,
  year_2024     INT,
  year_2025     INT
  -- 毎年列を追加
);

-- ✅ 解決策1: 正規化（列 → 行）
CREATE TABLE ProjectHistory (
  project_id  BIGINT UNSIGNED NOT NULL,
  year        SMALLINT NOT NULL,
  bugs_fixed  INT,
  PRIMARY KEY (project_id, year),
  FOREIGN KEY (project_id) REFERENCES Projects(project_id)
);

-- 集約が容易
SELECT year, SUM(bugs_fixed) AS total_fixed
FROM ProjectHistory
GROUP BY year;

-- ✅ 解決策2: パーティショニング（テーブル分割の代替）
CREATE TABLE Bugs (
  bug_id        SERIAL PRIMARY KEY,
  date_reported DATE NOT NULL,
  ...
)
PARTITION BY RANGE (YEAR(date_reported)) (
  PARTITION p2023 VALUES LESS THAN (2024),
  PARTITION p2024 VALUES LESS THAN (2025),
  PARTITION p2025 VALUES LESS THAN (2026)
);

-- 単一テーブルとして透過的にクエリ可能
SELECT * FROM Bugs WHERE date_reported BETWEEN '2024-01-01' AND '2024-12-31';
```

**パーティショニングのメリット:**
- アプリケーションコードから透過的（単一テーブルとして扱える）
- 範囲検索時に不要なパーティションをスキップできる
- 古いパーティションの削除が高速
- パーティション単位でのメンテナンスが可能

---

## まとめ

論理設計のアンチパターンを避けるための原則:

1. **正規化を優先**: 重複を避け、各事実を1か所にのみ格納する
2. **外部キー制約を宣言**: データベースに整合性を保証させる
3. **メタデータの増殖を防ぐ**: データを列ではなく行に格納する
4. **適切なモデリング手法を選択**: ツリーやサブタイプには専用のパターンを使用する
5. **将来の変更を考慮**: 拡張性のある設計を心がける
