# 正規化ルール

データベース正規化の理論と実践ガイド。第1正規形から第5正規形まで、各正規形の定義、目的、実装方法を解説します。

## 正規化とは

**正規化（Normalization）**は、データベース設計における体系的なアプローチであり、以下の目的を持ちます：

1. **冗長性の排除**: 同じデータを複数箇所に格納することを防ぐ
2. **更新異常の防止**: 挿入異常、更新異常、削除異常を回避
3. **データ整合性の保証**: 参照整合性と一貫性を維持
4. **理解しやすさの向上**: 現実世界の事実を明確に表現

**重要**: 正規化はパフォーマンス最適化のための手法ではなく、データの正確性と整合性を保証するための手法です。

---

## リレーショナルの5つの性質

テーブルが**リレーション（関係）**であるための基本条件：

### 1. 行に上下の順番がない

`ORDER BY`句で明示的に指定しない限り、行の順序は不定です。行の集合としての内容が等しければ、順序が異なっていても等価です。

```sql
-- これらは論理的に同じ結果
SELECT * FROM Products;  -- 順序不定
SELECT * FROM Products ORDER BY product_id;  -- 順序指定
```

### 2. 列に左右の順番がない

列名で識別されるため、列の物理的な順序に意味はありません。

```sql
-- これらは同じ情報を表現
SELECT bug_id, product_id, assigned_to FROM Bugs;
SELECT assigned_to, bug_id, product_id FROM Bugs;
```

**関連**: インプリシットカラムアンチパターン（列の位置依存を避ける）

### 3. 重複行を許可しない

各行は一意に識別可能でなければなりません。主キー制約によって保証されます。

```sql
CREATE TABLE Teams (
  team_name VARCHAR(50) PRIMARY KEY,
  city      VARCHAR(50) NOT NULL
);

-- 主キーが重複を防ぐ
INSERT INTO Teams VALUES ('RedSox', 'Boston');
INSERT INTO Teams VALUES ('RedSox', 'Boston');  -- エラー: 重複
```

非キー列には重複が許されます（例: 複数チームが同じ都市を本拠地とする）。

### 4. すべての列は1つの型を持ち、各行に1つの値を持つ

**ヘッダー**（列名とデータ型）がテーブル全体で一貫している必要があります。

**違反例**:
- EAVパターン: `attr_value`列が複数の型を混在させる
- ポリモーフィック関連: `object_id`が異なるテーブルのIDを混在させる

```sql
-- ❌ 違反: attr_value列が複数の意味を持つ
CREATE TABLE EAV (
  entity_id  BIGINT,
  attr_name  VARCHAR(50),
  attr_value VARCHAR(255)  -- 日付、数値、文字列が混在
);

-- ✅ 正しい: 各列が明確な型と意味を持つ
CREATE TABLE Bugs (
  bug_id      BIGINT PRIMARY KEY,
  reported_date DATE NOT NULL,
  priority    INTEGER NOT NULL,
  description VARCHAR(255)
);
```

### 5. 行に隠されたコンポーネントがない

列にはデータの値そのものが格納され、物理ストレージの識別子（行番号、オブジェクトID）は含まれません。

**注意**: 一部のDBMSは拡張機能として物理識別子を提供（Oracle `ROWNUM`、PostgreSQL `OID`）しますが、これらはリレーションの一部ではありません。

---

## 正規化の誤解と神話

### 誤解1: 「正規化はデータベースを遅くする」

**真実**: 正規化自体はパフォーマンスとは無関係です。

- 正規化によって`JOIN`が必要になる場合がある → 一部のクエリが遅くなる可能性
- 非正規化によって`JOIN`を減らせる → **特定の**クエリは速くなるが、**他の**クエリは遅くなる
- 例: カンマ区切りリスト（非正規化）は集約が困難で、かえって遅くなる

**原則**: まず正規化して設計し、ベンチマーク結果に基づいて選択的に非正規化する。

### 誤解2: 「正規化とは疑似キーを使うこと」

**真実**: 疑似キー（`id`列）の使用は正規化とは無関係です。

正規化は**データの冗長性排除**に関するもので、主キーの種類（自然キーか疑似キーか）は別の設計判断です。

### 誤解3: 「正規化とは属性をできる限り分離すること」

**真実**: 正規化はデータを**理解しやすく**し、クエリを**書きやすく**します。

EAVのような過度な汎用化は正規化ではなく、むしろアンチパターンです。

### 誤解4: 「第3正規形で十分」

**真実**: 実務データベースの20%以上が第4正規形に違反しています。

第4正規形、第5正規形は稀なケースではなく、多対多関連を扱う際に頻繁に発生します。

---

## 正規形の進行

```
未正規化
    ↓
第1正規形（1NF）：繰り返しグループの排除
    ↓
第2正規形（2NF）：部分関数従属の排除
    ↓
第3正規形（3NF）：推移的関数従属の排除
    ↓
ボイスコッド正規形（BCNF）：全属性がキーに従属
    ↓
第4正規形（4NF）：多値従属性の排除
    ↓
第5正規形（5NF）：結合従属性の排除
```

一般に、上位の正規形を満たすテーブルは、それ以前のすべての正規形も満たします。

---

## 第1正規形（1NF）

### 定義

- テーブルがリレーションである（上記5つの性質を満たす）
- **繰り返しグループ（repeating group）**がない

**繰り返しグループ**: 1つの行が、ある集合の複数の値を含んでいる状態。

### 違反パターン

1. **マルチカラムアトリビュート**: 同じドメインの値を複数列に格納

```sql
-- ❌ 第1正規形違反
CREATE TABLE Bugs (
  bug_id BIGINT PRIMARY KEY,
  tag1   VARCHAR(20),
  tag2   VARCHAR(20),
  tag3   VARCHAR(20)
);
```

2. **ジェイウォーク**: 複数の値を1列に格納

```sql
-- ❌ 第1正規形違反
CREATE TABLE Bugs (
  bug_id BIGINT PRIMARY KEY,
  tags   VARCHAR(100)  -- 'performance,crash,ui'
);
```

### 解決策

別テーブルを作成し、1行に1つの値を格納します。

```sql
-- ✅ 第1正規形
CREATE TABLE BugsTags (
  bug_id BIGINT NOT NULL,
  tag    VARCHAR(20) NOT NULL,
  PRIMARY KEY (bug_id, tag),
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id)
);
```

---

## 第2正規形（2NF）

### 定義

- 第1正規形を満たす
- **複合主キー**を持つ
- すべての非キー属性が、主キー全体に従属する（部分従属がない）

**部分関数従属**: 複合主キーの一部にのみ従属する属性。

### 違反例

```sql
-- ❌ 第2正規形違反
CREATE TABLE BugsTags (
  bug_id  BIGINT NOT NULL,
  tag     VARCHAR(20) NOT NULL,
  tagger  BIGINT NOT NULL,      -- bug_id + tag に従属
  coiner  BIGINT NOT NULL,      -- tag のみに従属（部分従属！）
  PRIMARY KEY (bug_id, tag)
);
```

**問題**: `coiner`（タグ作成者）は`tag`にのみ従属するため、同じタグが複数行に現れると冗長性が発生し、更新異常のリスクがあります。

```
bug_id | tag    | tagger | coiner
-------|--------|--------|--------
1234   | crash  | Alice  | Bob
5678   | crash  | Carol  | Bob
9012   | crash  | Dave   | Charlie  ← データ不整合！
```

### 解決策

部分従属する属性を別テーブルに分離します。

```sql
-- ✅ 第2正規形
CREATE TABLE Tags (
  tag     VARCHAR(20) PRIMARY KEY,
  coiner  BIGINT NOT NULL,
  FOREIGN KEY (coiner) REFERENCES Accounts(account_id)
);

CREATE TABLE BugsTags (
  bug_id  BIGINT NOT NULL,
  tag     VARCHAR(20) NOT NULL,
  tagger  BIGINT NOT NULL,
  PRIMARY KEY (bug_id, tag),
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id),
  FOREIGN KEY (tag) REFERENCES Tags(tag),
  FOREIGN KEY (tagger) REFERENCES Accounts(account_id)
);
```

---

## 第3正規形（3NF）

### 定義

- 第2正規形を満たす
- すべての非キー属性が、主キーに**直接**従属する（推移的従属がない）

**推移的関数従属**: A → B → C のように、非キー属性が他の非キー属性を経由して主キーに従属する状態。

### 違反例

```sql
-- ❌ 第3正規形違反
CREATE TABLE Bugs (
  bug_id         SERIAL PRIMARY KEY,
  assigned_to    BIGINT,
  assigned_email VARCHAR(100),  -- assigned_to に従属（推移的従属！）
  FOREIGN KEY (assigned_to) REFERENCES Accounts(account_id)
);
```

**問題**: `assigned_email`は`bug_id`に直接従属せず、`assigned_to`を経由して間接的に従属します。同じアカウントが複数のバグに割り当てられると、メールアドレスが冗長に格納されます。

### 解決策

推移的従属する属性を、それが従属する属性のテーブルに移動します。

```sql
-- ✅ 第3正規形
CREATE TABLE Accounts (
  account_id BIGINT PRIMARY KEY,
  email      VARCHAR(100) NOT NULL
);

CREATE TABLE Bugs (
  bug_id      SERIAL PRIMARY KEY,
  assigned_to BIGINT,
  FOREIGN KEY (assigned_to) REFERENCES Accounts(account_id)
);
```

---

## ボイスコッド正規形（BCNF）

### 定義

- 第3正規形を満たす
- **すべての属性**（キー列を含む）が、候補キーに従属する

第3正規形との違い: 3NFでは非キー属性のみがルール対象だが、BCNFではキー列もルール対象になります。

### 適用ケース

テーブルに**複数の候補キー**が存在する場合に発生します。

### 違反例

タグに3つのタイプ（impact, subsystem, fix）があり、各バグには各タイプ最大1つのタグが付けられるとします。

```sql
-- ❌ ボイスコッド正規形違反
CREATE TABLE BugsTags (
  bug_id   BIGINT NOT NULL,
  tag      VARCHAR(20) NOT NULL,
  tag_type VARCHAR(20) NOT NULL,
  PRIMARY KEY (bug_id, tag)
  -- 候補キー1: (bug_id, tag)
  -- 候補キー2: (bug_id, tag_type) も一意！
);
```

**問題**: `tag`と`tag_type`の間に従属性があるため、冗長性が発生します。

### 解決策

```sql
-- ✅ ボイスコッド正規形
CREATE TABLE Tags (
  tag      VARCHAR(20) PRIMARY KEY,
  tag_type VARCHAR(20) NOT NULL
);

CREATE TABLE BugsTags (
  bug_id BIGINT NOT NULL,
  tag    VARCHAR(20) NOT NULL,
  PRIMARY KEY (bug_id, tag),
  FOREIGN KEY (tag) REFERENCES Tags(tag)
);
```

---

## 第4正規形（4NF）

### 定義

- ボイスコッド正規形を満たす
- **多値従属性（multivalued dependency）**がない

**多値従属性**: 1つのエンティティに対して、独立した複数の多対多関連が存在する状態。

### 違反例

バグに対して、複数の報告者、複数の修正担当者、複数の検証担当者を関連付けたい場合：

```sql
-- ❌ 第4正規形違反
CREATE TABLE BugsAccounts (
  bug_id       BIGINT NOT NULL,
  reported_by  BIGINT,
  assigned_to  BIGINT,
  verified_by  BIGINT,
  PRIMARY KEY (bug_id, reported_by, assigned_to, verified_by)
);
```

**問題**:
1. 主キーに`NULL`許容列が含まれる（修正担当前のバグ）
2. 列間で値の数が不一致だと冗長性が発生

```
bug_id | reported_by | assigned_to | verified_by
-------|-------------|-------------|------------
1234   | Alice       | Bob         | Carol
1234   | Alice       | Bob         | Dave       ← Bob が冗長
1234   | Alice       | Eve         | Carol      ← Alice, Carol が冗長
1234   | Alice       | Eve         | Dave       ← Alice が冗長
```

### 解決策

各多対多関連ごとに独立した交差テーブルを作成します。

```sql
-- ✅ 第4正規形
CREATE TABLE BugsReported (
  bug_id       BIGINT NOT NULL,
  reported_by  BIGINT NOT NULL,
  PRIMARY KEY (bug_id, reported_by),
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id),
  FOREIGN KEY (reported_by) REFERENCES Accounts(account_id)
);

CREATE TABLE BugsAssigned (
  bug_id       BIGINT NOT NULL,
  assigned_to  BIGINT NOT NULL,
  PRIMARY KEY (bug_id, assigned_to),
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id),
  FOREIGN KEY (assigned_to) REFERENCES Accounts(account_id)
);

CREATE TABLE BugsVerified (
  bug_id       BIGINT NOT NULL,
  verified_by  BIGINT NOT NULL,
  PRIMARY KEY (bug_id, verified_by),
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id),
  FOREIGN KEY (verified_by) REFERENCES Accounts(account_id)
);
```

---

## 第5正規形（5NF）

### 定義

- 第4正規形を満たす
- **結合従属性（join dependency）**がない

複数の独立した多対多関連の事実を1つのテーブルに格納すると違反します。

### 違反例

エンジニアが担当可能な製品と、実際にバグ修正に取り組んでいる製品を1つのテーブルで管理：

```sql
-- ❌ 第5正規形違反
CREATE TABLE BugsAssigned (
  bug_id       BIGINT NOT NULL,
  assigned_to  BIGINT NOT NULL,
  product_id   BIGINT NOT NULL,
  PRIMARY KEY (bug_id, assigned_to),
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id),
  FOREIGN KEY (assigned_to) REFERENCES Accounts(account_id),
  FOREIGN KEY (product_id) REFERENCES Products(product_id)
);
```

**問題**:
1. 「エンジニアが製品に割り当て可能」という事実が表現できない
2. エンジニアが同じ製品の複数バグに取り組むと、製品IDが冗長に格納される

```
bug_id | assigned_to | product_id
-------|-------------|------------
1234   | Alice       | ProductA
5678   | Alice       | ProductA   ← ProductA が冗長
9012   | Alice       | ProductB
```

### 解決策

各関連を独立したテーブルに分離します。

```sql
-- ✅ 第5正規形
CREATE TABLE BugsAssigned (
  bug_id       BIGINT NOT NULL,
  assigned_to  BIGINT NOT NULL,
  PRIMARY KEY (bug_id, assigned_to),
  FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id),
  FOREIGN KEY (assigned_to) REFERENCES Accounts(account_id)
);

CREATE TABLE EngineerProducts (
  account_id   BIGINT NOT NULL,
  product_id   BIGINT NOT NULL,
  PRIMARY KEY (account_id, product_id),
  FOREIGN KEY (account_id) REFERENCES Accounts(account_id),
  FOREIGN KEY (product_id) REFERENCES Products(product_id)
);
```

これにより、エンジニアの製品割り当て可能性と、実際のバグ修正作業を独立して記録できます。

---

## その他の正規形

### ドメインキー正規形（DKNF）

テーブルのすべての制約が、ドメイン制約（データ型）とキー制約の論理的帰結である状態。

第3正規形、第4正規形、第5正規形、ボイスコッド正規形はすべてDKNFの対象です。

**例**: 「NEWステータスのバグには作業時間が記録されていない」という制約はDKNFを満たしません（トリガや`CHECK`制約で実装が必要）。

### 第6正規形（6NF）

すべての**結合従属性**を排除し、属性の変更履歴をサポートします。

**用途**: データウェアハウス、時系列データ（Anchor Modeling等）

**注意**: ほとんどのアプリケーションにとって過剰な正規化です。各列ごとに履歴テーブルが必要になり、テーブル数が爆発的に増加します。

---

## 正規化判断テーブル

| 正規形 | チェック項目 | 違反の影響 | 関連アンチパターン |
|-------|-------------|-----------|------------------|
| **1NF** | 繰り返しグループの有無 | クエリ複雑化、集約不可 | ジェイウォーク、マルチカラム |
| **2NF** | 複合キーの部分従属 | 冗長性、更新異常 | - |
| **3NF** | 推移的従属 | 冗長性、更新異常 | - |
| **BCNF** | キー列の従属性 | 冗長性（複数候補キー時） | - |
| **4NF** | 多値従属性 | 冗長性、NULL問題 | - |
| **5NF** | 結合従属性 | 冗長性、関連の混在 | - |

---

## 実践ガイド

### 正規化の進め方

```
ステップ1: エンティティと属性を識別
    ↓
ステップ2: 主キーを決定（自然キーまたは疑似キー）
    ↓
ステップ3: 第1正規形（繰り返しグループ排除）
    ↓
ステップ4: 第2正規形（部分従属排除）
    ↓
ステップ5: 第3正規形（推移的従属排除）
    ↓
ステップ6: ボイスコッド正規形（複数候補キーをチェック）
    ↓
ステップ7: 第4正規形（多対多関連を分離）
    ↓
ステップ8: 第5正規形（独立した関連を分離）
```

### 非正規化の判断基準

正規化後、以下の条件を**すべて**満たす場合のみ非正規化を検討：

1. **測定済みのパフォーマンス問題**: ベンチマークで実証されたボトルネック
2. **頻度の高いクエリ**: アプリケーションの主要なユースケース
3. **JOIN削減の効果**: インデックスやクエリ最適化では解決不可
4. **トレードオフの受容**: 更新コストやデータ整合性リスクを理解

**原則**: パフォーマンス改善は非正規化ではなく、まずインデックスとクエリ最適化で対応（MENTOR原則）。

---

## まとめ

正規化は難解でも複雑でもなく、**データの冗長性を減らし、整合性を保つための常識的な技法**です。

- 正規形を理解し、適用することでデータベース設計の品質が向上します
- 非正規化は測定に基づいて選択的に行います
- 正規化はパフォーマンス最適化ではなく、**正確性の保証**が目的です

この付録で学んだ原則を参考に、より良いデータベース設計を目指してください。
