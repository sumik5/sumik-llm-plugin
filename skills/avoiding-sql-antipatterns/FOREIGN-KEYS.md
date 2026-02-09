# 外部キーのミニ・アンチパターン

> 外部キー制約の実装でよくある間違いとその正しい実装方法。

---

## 標準SQLの外部キーの落とし穴

### 1. 参照方向を逆にしようとする

**問題**: 1対多の関連で、多側ではなく1側に外部キーを定義してしまう。

```sql
-- ❌ 誤った例（親側に外部キー）
CREATE TABLE Child (
  child_id INT PRIMARY KEY
);

CREATE TABLE Parent (
  parent_id INT PRIMARY KEY,
  child_id INT NOT NULL,
  FOREIGN KEY (child_id) REFERENCES Child(child_id)
);
-- 結果: 親は1つの子しか持てない（意図と逆）

-- ✅ 正しい例（子側に外部キー）
CREATE TABLE Parent (
  parent_id INT PRIMARY KEY
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
);
-- 結果: 親は複数の子を持てる
```

外部キーは1対多の「多」側に定義する。

### 2. 作成前のテーブルを参照しようとする

**問題**: まだ作成されていないテーブルを外部キーで参照する。

```sql
-- ❌ 誤った例
CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)  -- Parentがまだ存在しない
);
-- エラー: Failed to open the referenced table 'Parent'

-- ✅ 正しい例
CREATE TABLE Parent (
  parent_id INT PRIMARY KEY
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
);
```

親テーブルを先に作成する。相互参照の場合は`ALTER TABLE`で後から追加。

### 3. 親テーブルのキーを参照していない

**問題**: 参照先の列が`PRIMARY KEY`または`UNIQUE KEY`ではない。

```sql
-- ❌ 誤った例
CREATE TABLE Parent (
  parent_id INT NOT NULL  -- キー制約なし
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
);
-- エラー: Missing index for constraint in the referenced table

-- ✅ 正しい例
CREATE TABLE Parent (
  parent_id INT PRIMARY KEY  -- または UNIQUE KEY
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
);
```

外部キーは`PRIMARY KEY`または`UNIQUE KEY`を参照する必要がある。

### 4. 複合キーの列ごとに個別の制約を作成しようとする

**問題**: 複合主キーの各列に対して別々の外部キーを定義する。

```sql
-- ❌ 誤った例
CREATE TABLE Parent (
  parent_id1 INT,
  parent_id2 INT,
  PRIMARY KEY (parent_id1, parent_id2)
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id1 INT NOT NULL,
  parent_id2 INT NOT NULL,
  FOREIGN KEY (parent_id1) REFERENCES Parent(parent_id1),  -- エラー
  FOREIGN KEY (parent_id2) REFERENCES Parent(parent_id2)
);

-- ✅ 正しい例
CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id1 INT NOT NULL,
  parent_id2 INT NOT NULL,
  FOREIGN KEY (parent_id1, parent_id2)
    REFERENCES Parent(parent_id1, parent_id2)
);
```

複合キーは1つの外部キー制約で参照する。

### 5. 間違った列順で外部キーを定義しようとする

**問題**: 複合キーの列順序が親テーブルと一致していない。

```sql
-- ❌ 誤った例
CREATE TABLE Parent (
  parent_id1 INT,
  parent_id2 INT,
  PRIMARY KEY (parent_id1, parent_id2)
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id1 INT NOT NULL,
  parent_id2 INT NOT NULL,
  FOREIGN KEY (parent_id2, parent_id1)  -- 順序が逆
    REFERENCES Parent(parent_id1, parent_id2)
);
-- データ挿入時にエラー

-- ✅ 正しい例
CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id1 INT NOT NULL,
  parent_id2 INT NOT NULL,
  FOREIGN KEY (parent_id1, parent_id2)  -- 順序一致
    REFERENCES Parent(parent_id1, parent_id2)
);
```

列順序は親テーブルのキー定義と一致させる。

### 6. データ型の不一致

**問題**: 外部キー列と参照先列のデータ型が異なる。

```sql
-- ❌ 誤った例
CREATE TABLE Parent (
  parent_id INT PRIMARY KEY
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id VARCHAR(10) NOT NULL,  -- 型が異なる
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
);
-- エラー: incompatible types

-- ✅ 正しい例
CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,  -- 型を一致
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
);
```

符号の有無（`INT` vs `INT UNSIGNED`）も一致させる必要がある。

### 7. 文字照合順序の不一致

**問題**: 文字列型で照合順序（collation）が異なる。

```sql
-- ❌ 誤った例
CREATE TABLE Parent (
  parent_id VARCHAR(10) PRIMARY KEY
) CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id VARCHAR(10) NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
) CHARSET utf8mb4 COLLATE utf8mb4_general_ci;  -- 照合順序が異なる
-- エラー: incompatible

-- ✅ 正しい例
CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id VARCHAR(10) NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
) CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;  -- 照合順序を一致
```

文字セットと照合順序を親テーブルと一致させる。

### 8. 孤立したデータを作成しようとする

**問題**: 既存の子テーブルに外部キーを追加する際、親テーブルに対応する行が存在しない。

```sql
-- ❌ 誤った例
CREATE TABLE Parent (
  parent_id INT PRIMARY KEY
);
INSERT INTO Parent (parent_id) VALUES (1234);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL
);
INSERT INTO Child (child_id, parent_id) VALUES (1, 1234), (2, 5678);  -- 5678は存在しない

ALTER TABLE Child
  ADD FOREIGN KEY (parent_id) REFERENCES Parent(parent_id);
-- エラー: Cannot add or update a child row

-- ✅ 正しい例: 孤立データをチェック
SELECT CASE COUNT(*)
  WHEN 0 THEN '外部キーを追加できます'
  ELSE '孤立した行があるので外部キーを追加できません'
  END AS `check`
FROM Child
LEFT OUTER JOIN Parent ON Child.parent_id = Parent.parent_id
WHERE Parent.parent_id IS NULL;
```

外部キー追加前に孤立データを修正する。

### 9. NULLにできない列に対してSET NULLオプションを使おうとする

**問題**: `NOT NULL`列に`ON DELETE SET NULL`を指定する。

```sql
-- ❌ 誤った例
CREATE TABLE Parent (
  parent_id INT PRIMARY KEY
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,  -- NULL不可
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
    ON DELETE SET NULL  -- 矛盾
);
-- エラー: Column cannot be NOT NULL: needed in a foreign key constraint SET NULL

-- ✅ 正しい例
CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NULL,  -- NULL許可
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
    ON DELETE SET NULL
);
```

`SET NULL`を使用する場合は列を`NULL`許可にする。

### 10. 重複する制約識別子を作成しようとする

**問題**: 同じスキーマ内で制約名が重複する。

```sql
-- ❌ 誤った例
CREATE TABLE Parent (
  parent_id INT PRIMARY KEY
);

CREATE TABLE Child1 (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  CONSTRAINT c1 FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
);

CREATE TABLE Child2 (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  CONSTRAINT c1 FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)  -- 重複
);
-- エラー: Duplicate foreign key constraint name 'c1'

-- ✅ 正しい例
CREATE TABLE Child2 (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  CONSTRAINT c2 FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)  -- 一意な名前
);
```

制約名は命名規則を確立するか、自動生成に任せる。

---

## MySQL固有の外部キーの落とし穴

### 1. 互換性のないストレージエンジンを使おうとする

**問題**: 親子テーブルのストレージエンジンが異なる、または外部キーをサポートしていない。

```sql
-- ❌ 誤った例
CREATE TABLE Parent (
  parent_id INT PRIMARY KEY
) ENGINE=MyISAM;  -- 外部キー非対応

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
) ENGINE=InnoDB;
-- エラー: Failed to open the referenced table 'Parent'

-- ✅ 正しい例
CREATE TABLE Parent (
  parent_id INT PRIMARY KEY
) ENGINE=InnoDB;  -- 両方InnoDBに統一

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
) ENGINE=InnoDB;
```

両テーブルをInnoDBに統一する（MySQLのデフォルト）。

### 2. 外部キーに大きなデータ型を使おうとする

**問題**: `BLOB`/`TEXT`型の列に外部キーを定義しようとする。

```sql
-- ❌ 誤った例
CREATE TABLE Parent (
  parent_id TEXT NOT NULL,
  UNIQUE KEY (parent_id(40))  -- プレフィックスインデックス
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id TEXT NOT NULL,
  KEY (parent_id(40)),
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
);
-- エラー: BLOB/TEXT column used in key specification without a key length

-- ✅ 回避策（MySQL 5.7以降）
CREATE TABLE Parent (
  parent_id TEXT NOT NULL,
  parent_id_crc INT UNSIGNED AS (CRC32(parent_id)) STORED,
  UNIQUE KEY (parent_id_crc)
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id_crc INT UNSIGNED,
  FOREIGN KEY (parent_id_crc) REFERENCES Parent(parent_id_crc)
);
```

`BLOB`/`TEXT`を避けるか、生成列のハッシュを使用する。最善は疑似キーを使用すること。

### 3. 一意でないインデックスへの外部キーを定義しようとする

**問題**: 複合キーの左端から始まらない列サブセットを参照する（MySQL非標準機能の誤用）。

```sql
-- ❌ 誤った例
CREATE TABLE Parent (
  parent_id1 INT,
  parent_id2 INT,
  parent_id3 INT,
  PRIMARY KEY (parent_id1, parent_id2, parent_id3)
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id2 INT NOT NULL,
  parent_id3 INT NOT NULL,
  FOREIGN KEY (parent_id2, parent_id3)  -- 左端から始まっていない
    REFERENCES Parent(parent_id2, parent_id3)
);
-- エラー: Missing index for constraint

-- ✅ 推奨（標準準拠）
CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id1 INT NOT NULL,
  parent_id2 INT NOT NULL,
  parent_id3 INT NOT NULL,
  FOREIGN KEY (parent_id1, parent_id2, parent_id3)  -- 全列参照
    REFERENCES Parent(parent_id1, parent_id2, parent_id3)
);
```

MySQLでは左端サブセット参照が可能だが、曖昧さを避けるため全列参照を推奨。

### 4. インライン参照構文を使おうとする

**問題**: MySQLは列定義内での外部キー宣言（インライン構文）をサポートしていない。

```sql
-- ❌ 誤った例（MySQLでは無視される）
CREATE TABLE Parent (
  parent_id VARCHAR(10) PRIMARY KEY
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id VARCHAR(10) NOT NULL REFERENCES Parent(parent_id)  -- 無視される
);
-- エラーなし、しかし外部キーは作成されていない

-- ✅ 正しい例（テーブルレベル制約）
CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id VARCHAR(10) NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
);
```

MySQLではテーブルレベル制約構文のみ使用可能。

### 5. デフォルト参照構文を使おうとする

**問題**: MySQLでは参照列の省略ができない。

```sql
-- ❌ 誤った例
CREATE TABLE Parent (
  parent_id VARCHAR(10) PRIMARY KEY
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id VARCHAR(10) NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent  -- 列名省略
);
-- エラー: Key reference and table reference don't match

-- ✅ 正しい例
CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id VARCHAR(10) NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)  -- 列名明示
);
```

MySQLでは参照列を明示的に指定する。

### 6. 互換性のないテーブルタイプを使おうとする

**問題**: `TEMPORARY`テーブルや`PARTITIONED`テーブルで外部キーを使用する。

```sql
-- ❌ 誤った例（パーティション）
CREATE TABLE Parent (
  parent_id INT PRIMARY KEY
);

CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
) PARTITION BY HASH(child_id) PARTITIONS 11;
-- エラー: Foreign keys are not yet supported in conjunction with partitioning

-- ❌ 誤った例（一時テーブル）
CREATE TEMPORARY TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
);
-- エラー: Cannot add foreign key constraint

-- ✅ 正しい例
CREATE TABLE Child (
  child_id INT PRIMARY KEY,
  parent_id INT NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES Parent(parent_id)
);  -- 通常の永続テーブル
```

MySQLの外部キーは非一時・非パーティションテーブルでのみ使用可能。

---

## 外部キー制約のベストプラクティス

1. **早期の制約定義**: テーブル作成時に外部キーを宣言する
2. **命名規則の確立**: 制約名に`fk_<子テーブル>_<親テーブル>`などの規則を使用
3. **適切なアクション設定**:
   - `ON DELETE CASCADE`: 親削除時に子も削除
   - `ON DELETE SET NULL`: 親削除時に子をNULLに設定
   - `ON DELETE RESTRICT`（デフォルト）: 子が存在する場合は親削除を拒否
4. **インデックスの確認**: 外部キー列には自動的にインデックスが作成されるが、パフォーマンスを監視
5. **マイグレーション順序**: スキーマ変更時は依存関係の順序に注意
