# 正規化ガイド

正規化はデータベース設計の中核プロセスであり、データの冗長性を削減し、挿入・更新・削除異常を防ぎ、データ整合性を強化します。このガイドでは1NF～BCNFまでの正規形ルール、関数従属の識別、サイクル検出、実装方法を解説します。

---

## 正規化の目的

### 主要な3つの目標

1. **データ冗長性の削減**: 同じ情報を複数箇所に保存しない
2. **異常の防止**: 挿入・更新・削除異常を排除
3. **データ整合性の強化**: 矛盾のないデータ構造を維持

### 異常の例（非正規化テーブル）

**問題のあるテーブル（product_customer）:**

| product_id | product_name | customer_id | customer_name |
|------------|--------------|-------------|---------------|
| 1 | Widget | 101 | Alice |
| 2 | Gadget | 101 | Alice |
| 1 | Widget | 102 | Bob |

**異常:**

- **更新異常**: Aliceの名前を変更するには複数行を更新する必要がある
- **削除異常**: Bobが唯一購入した商品を削除すると、Bobの情報も失われる
- **挿入異常**: 商品を購入していない顧客を登録できない

---

## 正規形の階層

正規形は入れ子人形（nesting dolls）のような階層構造を持ちます。

```
1NF ⊂ 2NF ⊂ 3NF ⊂ BCNF (⊂ 4NF ⊂ 5NF ⊂ 6NF)
```

- **1NF**: 最も外側の人形（基本ルール）
- **BCNF**: 実務で目指すべき最小の人形（完全正規化）
- **4NF, 5NF, 6NF**: 理論的な拡張（本ガイドでは扱わない）

**実務上のルール:**

> 全テーブルがBCNFに達すれば、データベースは完全正規化されたとみなす。

---

## BCNFの特性（まとめ）

BCNFを満たすテーブルは以下の4つの特性を持ちます:

1. **主キー（PK）が存在する**
2. **多値カラムが存在しない**
3. **全カラムがキーに依存し、他に依存しない**
4. **推移的従属が存在しない**

これらを1つずつ検証していくことが正規化プロセスです。

---

## 1NF: 主キーが存在し、多値カラムがない

### 1NFのルール

1. **主キー（Primary Key）が存在する**
2. **多値カラム（multivalued column）が存在しない**

### 多値カラムとは

**定義**: 1つのセルに複数の値を格納するカラム。

**判断基準（ユーザー基準）:**

| 例 | 多値カラムか | 理由 |
|----|--------------|------|
| 電話番号リスト（"555-1234, 555-5678"） | ✅ | 各電話番号が独立した値 |
| メールアドレス（"user@example.com"） | ❌ | ユーザーは分割する必要を感じない |
| 氏名（"山田 太郎"） | ❌ | ユーザーはフルネームを単一値として扱う |

**重要**: 多値カラムかどうかはアプリケーションのユーザーの視点で判断する。

### 違反例と修正

**違反例（course_registrationテーブル）:**

| student_id | student_name | course |
|------------|--------------|--------|
| 1 | Alice | Math, Science |
| 2 | Bob | English |

**問題:**

- `course` カラムが複数の値を持つ
- クエリが困難（"Math"を受講している学生を検索できない）
- データ冗長性（"Math"が複数行に重複）

**修正方法: テーブル分割**

**studentテーブル:**

| student_id | student_name |
|------------|--------------|
| 1 | Alice |
| 2 | Bob |

**course_registrationテーブル:**

| student_id | course |
|------------|--------|
| 1 | Math |
| 1 | Science |
| 2 | English |

---

## 2NF: 部分関数従属がない（1NFの上位）

### 2NFのルール

**前提**: 1NFを満たす（PKが存在し、多値カラムがない）

**追加ルール**: **部分関数従属（partial functional dependency）**が存在しない

### 部分関数従属とは

**定義**: 複合主キーの一部のみに依存するカラムが存在する状態。

**数式表現:**
```
複合PK = (A, B)
カラムC → 部分関数従属 ⇔ C は A のみに依存（Bは不要）
```

### 違反例と修正

**違反例（purchaseテーブル）:**

| purchase_id | code | product_quantity | product_price | total_price | purchase_time |
|-------------|------|------------------|---------------|-------------|---------------|
| 1 | P001 | 2 | 10.00 | 20.00 | 2024-01-01 |
| 1 | P002 | 1 | 15.00 | 15.00 | 2024-01-01 |

**複合PK**: (purchase_id, code)

**関数従属:**
```
purchase_id → total_price, purchase_time  (部分従属!)
purchase_id, code → product_quantity, product_price
```

**問題:**

- `total_price` と `purchase_time` は `purchase_id` のみに依存
- 複合PKの一部（`code`）は不要 → 部分関数従属

**修正方法: テーブル分割**

**purchaseテーブル:**

| purchase_id | total_price | purchase_time |
|-------------|-------------|---------------|
| 1 | 35.00 | 2024-01-01 |

**purchase_productテーブル（接合テーブル）:**

| purchase_id | code | product_quantity | product_price |
|-------------|------|------------------|---------------|
| 1 | P001 | 2 | 10.00 |
| 1 | P002 | 1 | 15.00 |

---

## 3NF: 推移的従属がない（2NFの上位）

### 3NFのルール

**前提**: 2NFを満たす（部分関数従属がない）

**追加ルール**: **推移的従属（transitive dependency）**が存在しない

### 推移的従属とは

**定義**: 非キーカラムが別の非キーカラムに従属する状態（依存の連鎖）。

**数式表現:**
```
PK → 非キーA → 非キーB

これは推移的従属:
PK → 非キーB (間接的に従属)
```

### 違反例と修正

**違反例（employeeテーブル）:**

| employee_id | employee_name | department_id | department_name |
|-------------|---------------|---------------|-----------------|
| 1 | Alice | 10 | Sales |
| 2 | Bob | 10 | Sales |
| 3 | Charlie | 20 | Engineering |

**関数従属:**
```
employee_id → employee_name, department_id, department_name
department_id → department_name  (推移的従属!)
```

**推移的従属の連鎖:**
```
employee_id → department_id → department_name
```

**問題:**

- `department_name` は `employee_id` に直接依存せず、`department_id` を経由して依存
- 部署名変更時に複数行を更新する必要がある（更新異常）

**修正方法: テーブル分割**

**employeeテーブル:**

| employee_id | employee_name | department_id |
|-------------|---------------|---------------|
| 1 | Alice | 10 |
| 2 | Bob | 10 |
| 3 | Charlie | 20 |

**departmentテーブル:**

| department_id | department_name |
|---------------|-----------------|
| 10 | Sales |
| 20 | Engineering |

---

## BCNF: すべての決定項がキー

### BCNFのルール

**前提**: 3NFを満たす（推移的従属がない）

**追加ルール**: すべての決定項（determinant）が候補キー（candidate key）である。

**簡易表現（実務）:**
> 全カラムが主キー（または候補キー）にのみ関数従属する。

### 3NF ≒ BCNF（実務上）

ほとんどのケースで3NFを満たせばBCNFも満たします。BCNFは3NFのエッジケースを扱います。

**BCNFが3NFと異なるケース（レア）:**

テーブルRに以下の構造がある場合:
- 複合PK: (a, b, c)
- 候補キー: (a, b), (c, d)
- 関数従属: c → d

このケースでは3NFだがBCNFではない（cがキーでないのにdを決定）。

**実務上のアドバイス:**

> 3NFを達成すれば、ほぼBCNFも達成したとみなしてよい。

---

## 関数従属の識別方法

### 関数従属（Functional Dependency）とは

**定義**: カラムAの値が決まれば、カラムBの値が一意に決まる関係。

**数式表現:**
```
A → B  (AはBを関数的に決定する)
```

**例（employeeテーブル）:**

| employee_id | employee_name |
|-------------|---------------|
| 1 | Alice |
| 2 | Bob |

**関数従属:**
```
employee_id → employee_name
```

`employee_id` の値が決まれば、`employee_name` の値が一意に決まる。

### 方向性がある

関数従属は**片方向**です。

```
employee_id → employee_name  ✅
employee_name → employee_id  ❌ (同姓同名の可能性)
```

### 関数従属のリストアップ手順

1. **全カラムペアを検討**: (カラムA, カラムB) のすべての組み合わせ
2. **PKへの依存を確認**: 各カラムがPKに依存しているか
3. **非キーカラム間の依存を確認**: 推移的従属の検出

**例（productテーブル）:**

| product_id | product_name | supplier_name | supplier_contact |
|------------|--------------|---------------|------------------|
| 1 | Widget | SupplierA | contact@a.com |

**関数従属リスト:**
```
product_id → product_name, supplier_name, supplier_contact
supplier_name → supplier_contact  (推移的従属!)
```

---

## 正規化の実践フロー

### フローチャート

```
各テーブルについて:

1. PKが存在するか確認
   ↓ なければ設定
   ↓
2. 多値カラムがないか確認
   ↓ あればテーブル分割（1NF違反）
   ↓
3. 全カラムの関数従属をリストアップ
   ↓
4. PKへの部分従属がないか確認
   ↓ あればテーブル分割（2NF違反）
   ↓
5. 推移的従属がないか確認
   ↓ あればテーブル分割+FK設定（3NF違反）
   ↓
6. サイクル（3テーブル間のリレーションシップループ）がないか確認
   ↓ あれば推移的従属の可能性
   ↓
7. 完了（BCNF達成）
```

---

## サイクル検出（3テーブル間の推移的従属）

### サイクルとは

3つのテーブル間でリレーションシップが循環する状態。推移的従属が潜在する可能性が高い。

**例（The Sci-Fi Collective）:**

```
[user] ←─┐
  ↓      │
[purchase]│
  ↓      │
[payment_method] ──┘
```

**リレーションシップ:**
- `user` → `purchase` (email FK)
- `purchase` → `payment_method` (payment_id FK)
- `payment_method` → `user` (email FK)

**推移的従属の検出:**

```
purchase.payment_id → payment_method.email
payment_method.email → user (同じemail)
```

**結論**: `purchase.email` は冗長（推移的従属）

### 修正方法

**オプション1: 直接リンクを削除（正規化優先）**

```
[user]
  ↑
  │ email FK
[payment_method]
  ↑
  │ payment_id FK
[purchase]
```

`purchase.email` を削除し、`payment_method` 経由でユーザーを取得。

**オプション2: 非正規化（パフォーマンス優先）**

クエリ速度を優先する場合、`purchase.email` を残す（Ch7で詳述）。

---

## 正規化チェックリスト

### 各正規形のチェックリスト

| 正規形 | ルール | 違反パターン | 修正方法 |
|--------|--------|--------------|----------|
| **1NF** | PKが存在 | PKが未設定 | 候補キーを選択してPKに設定 |
| **1NF** | 多値カラムがない | "Math, Science"のような複数値 | テーブル分割（1行1値） |
| **2NF** | 部分関数従属がない | 複合PKの一部のみに依存するカラム | テーブル分割（PKの部分で新テーブル） |
| **3NF** | 推移的従属がない | 非キー→非キーの依存連鎖 | テーブル分割+FK設定 |
| **BCNF** | 全決定項がキー | 非キーカラムが他を決定 | テーブル分割（実務ではレア） |

### サイクル検出チェックリスト

| チェック項目 | 確認方法 |
|--------------|----------|
| 3テーブル間のリレーションシップがループ | ER図でサイクルを視覚的に確認 |
| 推移的従属が存在するか | 関数従属リストで `A → B → C` の連鎖を確認 |
| 冗長なFKがあるか | 2つの異なる経路で同じテーブルに到達可能か確認 |

---

## 実装（DDL生成）

### CREATE TABLE文の基本構造

```sql
CREATE TABLE table_name (
  column1 data_type constraints,
  column2 data_type constraints,
  ...,
  table_constraints
);
```

### 制約の種類と使い分け

| 制約 | 目的 | 使用タイミング |
|------|------|----------------|
| **PRIMARY KEY** | PKを定義 | 全テーブル必須 |
| **FOREIGN KEY** | 参照整合性を強制 | リレーションシップがある場合 |
| **NOT NULL** | NULL値を禁止 | 必須カラム |
| **UNIQUE** | 一意性を強制 | 候補キー、重複禁止カラム |
| **CHECK** | 値の範囲・形式を検証 | ビジネスルール適用 |
| **DEFAULT** | デフォルト値を設定 | タイムスタンプ、フラグ列 |

### CASCADE設定

#### CASCADE DELETE と CASCADE UPDATE

| 操作 | 動作 |
|------|------|
| **ON DELETE CASCADE** | 親テーブルの行削除時、子テーブルの対応行を自動削除 |
| **ON UPDATE CASCADE** | 親テーブルのPK更新時、子テーブルのFKを自動更新 |
| **ON DELETE RESTRICT** | 子テーブルに対応行があれば削除を拒否（デフォルト） |
| **ON DELETE SET NULL** | 親テーブルの行削除時、子テーブルのFKをNULLに設定 |

#### CASCADE判断基準テーブル

| 条件 | ON DELETE CASCADE | ON UPDATE CASCADE |
|------|-------------------|-------------------|
| 弱エンティティ（親なしで意味がない） | ✅ 推奨 | ✅ 推奨 |
| 強エンティティ（独立して存在可能） | ❌ RESTRICT | ✅ 推奨 |
| 履歴保持が必要 | ❌ SET NULL | ✅ 推奨 |
| 親削除時に子を孤立させたい | ❌ SET NULL | ✅ 推奨 |

**例（userとpayment_method）:**

```sql
CREATE TABLE payment_method (
  payment_id INT PRIMARY KEY,
  name VARCHAR(30) NOT NULL,
  card_number CHAR(16) NOT NULL,
  expiry_date CHAR(4) NOT NULL,
  email VARCHAR(320) NOT NULL,
  CONSTRAINT fk_payment_method_user
    FOREIGN KEY (email) REFERENCES user(email)
    ON DELETE CASCADE  -- ユーザー削除時に支払い方法も削除
    ON UPDATE CASCADE  -- メールアドレス変更時に同期
);
```

---

## 実装例（MySQL/PostgreSQL互換）

### 1. 正規化前（3NF違反）

**employeeテーブル（推移的従属あり）:**

```sql
CREATE TABLE employee (
  employee_id INT PRIMARY KEY,
  employee_name VARCHAR(100) NOT NULL,
  department_id INT NOT NULL,
  department_name VARCHAR(100) NOT NULL  -- 推移的従属!
);
```

**関数従属:**
```
employee_id → department_id → department_name
```

### 2. 正規化後（3NF/BCNF達成）

**employeeテーブル:**

```sql
CREATE TABLE employee (
  employee_id INT PRIMARY KEY,
  employee_name VARCHAR(100) NOT NULL,
  department_id INT NOT NULL,
  CONSTRAINT fk_employee_department
    FOREIGN KEY (department_id) REFERENCES department(department_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT  -- 部署削除前に従業員を移動させる
);
```

**departmentテーブル:**

```sql
CREATE TABLE department (
  department_id INT PRIMARY KEY,
  department_name VARCHAR(100) NOT NULL UNIQUE
);
```

### 3. 制約の完全な例（userテーブル）

```sql
CREATE TABLE user (
  email VARCHAR(320) PRIMARY KEY,
  username VARCHAR(30) NOT NULL,
  password VARCHAR(20) NOT NULL,
  first_name VARCHAR(50) NOT NULL,
  last_name VARCHAR(50) NOT NULL,
  phone_number VARCHAR(15),
  last_login_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT unq_username UNIQUE(username),
  CONSTRAINT unq_phone_number UNIQUE(phone_number)
);
```

**制約の説明:**

- `PRIMARY KEY`: email（自然キー）
- `NOT NULL`: 必須カラム（username, password, first_name, last_name, last_login_time）
- `UNIQUE`: 重複禁止（username, phone_number）
- `DEFAULT CURRENT_TIMESTAMP`: ログイン時刻の自動設定

### 4. 複合主キーの例（purchase_productテーブル）

```sql
CREATE TABLE purchase_product (
  purchase_id INT NOT NULL,
  code CHAR(12) NOT NULL,
  product_quantity INT NOT NULL,
  product_price DECIMAL(7,2) NOT NULL,
  product_name VARCHAR(100) NOT NULL,
  PRIMARY KEY (purchase_id, code),  -- 複合主キー
  CONSTRAINT fk_purchase_product_purchase
    FOREIGN KEY (purchase_id) REFERENCES purchase(purchase_id)
    ON DELETE CASCADE  -- 購入削除時に明細も削除
    ON UPDATE CASCADE,
  CONSTRAINT fk_purchase_product_product
    FOREIGN KEY (code) REFERENCES product(code)
    ON DELETE RESTRICT  -- 商品削除前に在庫確認
    ON UPDATE CASCADE
);
```

### 5. CHECK制約の例（user_addressテーブル）

```sql
CREATE TABLE user_address (
  email VARCHAR(320) PRIMARY KEY,
  street_address VARCHAR(255),
  city CHAR(100) NOT NULL,
  state VARCHAR(20) NOT NULL,
  postal_code CHAR(5) NOT NULL,
  CONSTRAINT fk_user_address_user
    FOREIGN KEY (email) REFERENCES user(email)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT chk_state
    CHECK (
      state IN (
        'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California',
        'Colorado', 'Connecticut', 'Delaware', 'Florida', 'Georgia',
        'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa',
        'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland',
        'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi', 'Missouri',
        'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey',
        'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio',
        'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina',
        'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont',
        'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming'
      )
    )
);
```

---

## まとめ

### 正規化の段階的アプローチ

| 段階 | ルール | 実装ポイント |
|------|--------|--------------|
| **1NF** | PKが存在、多値カラム排除 | テーブル分割で1行1値 |
| **2NF** | 部分関数従属排除 | 複合PKの部分で新テーブル作成 |
| **3NF** | 推移的従属排除 | 非キー→非キーの連鎖を分割+FK |
| **BCNF** | 全決定項がキー | 実務では3NF≒BCNF |

### 正規化プロセスの順序

1. **PKの設定**: 全テーブルにPKを設定
2. **1NF達成**: 多値カラムを分割
3. **関数従属のリストアップ**: 全カラムの依存関係を記録
4. **2NF達成**: 部分関数従属を排除
5. **3NF達成**: 推移的従属を排除
6. **サイクル検出**: 3テーブル間のループを確認
7. **制約の実装**: FK、NOT NULL、UNIQUE、CHECK、DEFAULT、CASCADEを設定

### 正規化の利点

- ✅ データ冗長性の削減
- ✅ 更新異常・削除異常・挿入異常の防止
- ✅ データ整合性の強化
- ✅ クエリの単純化（JOIN利用）
- ✅ 保守性の向上

### 正規化のトレードオフ（Ch7で詳述）

- ⚠️ JOIN操作の増加（クエリ速度の低下）
- ⚠️ 複雑なクエリ（3テーブル以上のJOIN）

実務では、正規化（整合性）とパフォーマンスのバランスを取る必要があります。基本的には**3NF/BCNFを達成してから、必要に応じて非正規化を検討**するアプローチが推奨されます。

このガイドに従うことで、データの整合性を保ちながら、保守性の高いデータベース設計が可能になります。
