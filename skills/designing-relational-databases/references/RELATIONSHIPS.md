# リレーションシップとER図

リレーションシップはエンティティ間の「つながり」を定義する設計プロセスの中核です。このガイドではER図の記法、カーディナリティ、強弱エンティティ、接合テーブルの設計方法を解説します。

---

## ER図の基本

### Entity-Relationship Diagram (ER図) とは

ER図はエンティティとそのリレーションシップをグラフィカルに表現する設計言語です。テーブルの**構造（スキーマ）**を表現するもので、データそのものは含みません。数百万行のデータを持つテーブルも、ER図では1つのボックスとして表現されます。

**ER図の構成要素:**

- **ボックス**: エンティティ（テーブル）を表現
- **線**: エンティティ間のリレーションシップを表現
- **記号**: カーディナリティ（数の関係）を表現

### Crow's Foot 記法 (Information Engineering 記法)

実務で最も広く使われる記法です。シンプルで直感的なため、本ガイドではCrow's Foot記法を採用します。

**基本記号:**

| 記号 | 意味 |
|------|------|
| `|` (バー) | 1（one） |
| `o` (円) | 0（zero） |
| `⋗` (鳥の足) | 多数（many） |

**読み方:**
- 内側の記号 = **最小カーディナリティ（min cardinality）**
- 外側の記号 = **最大カーディナリティ（max cardinality）**

---

## リレーションシップ設計プロセス

### Step 1: 要件文からシンプルな文を生成

要件分析で収集した情報を「**主語 - 動詞 - 目的語**」の形に変換します。

**例（The Sci-Fi Collective）:**

要件文:
- A user can make multiple purchases; an order can be made by only one user.
- A user can review multiple products as long as the user bought those products; a product can be reviewed by multiple users.

変換後:
- A **user** makes **purchases**.
- A **user** writes **reviews**.
- A **product** has **reviews**.
- A **user** maintains **payment methods**.
- A **purchase** contains **products**.

### Step 2: 名詞（エンティティ）間に線を引く

シンプルな文から名詞を抽出し、動詞でつながる2つのエンティティ間に線を引きます。

```
[user] ─────── [purchase]
[user] ─────── [review]
[product] ──── [review]
[user] ─────── [payment_method]
[purchase] ─── [product]
```

### Step 3: ステークホルダーとドラフトER図をレビュー

最初のドラフトを関係者（開発者・ビジネスオーナー）に見せてフィードバックを収集します。

**例:**
- 開発者: "オンライン購入には支払い方法が必須です"
- → `payment_method` と `purchase` 間にリレーションシップを追加

### Step 4: フィードバックを反映して反復改善

ドラフトを更新し、カーディナリティを明確化していきます（次セクション）。

---

## カーディナリティ

**カーディナリティ（Cardinality）**: あるエンティティの1つのインスタンスが、別のエンティティの何個のインスタンスと関連するかを示す数的関係。

### 方向性（Direction）

リレーションシップは双方向で分解できます。

**例（銀行システム）:**

- **文1**: A user has zero, one, or more accounts.
- **文2**: An account is associated with one and only one user.

```
[user] ──(文1: 0～多)──> [account]
[user] <──(文2: 1のみ)── [account]
```

統合表記:
```
[user] |o────── ⋗| [account]
       ↑          ↑
    文2の記号    文1の記号
```

---

## カーディナリティのタイプ

### 1. One-to-One（1:1）

**定義**: 両方向の最大カーディナリティが1。

| 方向 | 最小 | 最大 |
|------|------|------|
| A → B | 0 or 1 | 1 |
| B → A | 0 or 1 | 1 |

**判断基準テーブル:**

| 条件 | 1:1判定 |
|------|---------|
| 両エンティティが「1つのみ」関連 | ✅ |
| 片方が「複数」関連 | ❌ |
| 両最小カーディナリティが1 | ⚠️ データ投入順序の問題が発生 → 一方を0に緩和 |

**実装ルール:**

- **外部キー（FK）の配置**: 最小カーディナリティが0の方にFKを配置
  - A → B が "0 or 1" なら、B側にFKを配置

**例（department と manager）:**

```
[department] ||──o| [manager]
                ↑
            FK: department_id
```

- department側の最小カーディナリティを0に緩和
- manager側にFKを配置 → データ投入順序の問題を回避

---

### 2. One-to-Many（1:N）

**定義**: 一方の最大カーディナリティが1、もう一方が多数。

| 方向 | 最小 | 最大 |
|------|------|------|
| A → B | 0 or 1 | 多数 |
| B → A | 0 or 1 | 1 |

**判断基準テーブル:**

| 条件 | 1:N判定 |
|------|---------|
| 片方が「1つのみ」、もう片方が「複数」 | ✅ |
| 両方が「複数」 | ❌ → M:N |
| 両最小カーディナリティが1 | ⚠️ 多側を0に緩和 |

**実装ルール:**

- **外部キー（FK）の配置**: 多側（crow's footが指す側）にFKを配置

**例（user と review）:**

```
[user] |o────── ⋗| [review]
                ↑
            FK: email
```

- user側: 0～多（optional）
- review側: 1のみ（mandatory） → `review.email NOT NULL`

**なぜ多側にFKを配置するか:**

- 1側にFKを置くと、複数の多側レコードに対応するため1側が複数行必要になる（不可能）
- 多側にFKを置けば、複数行が同じFK値を持てる

---

### 3. Many-to-Many（M:N）

**定義**: 両方向の最大カーディナリティが多数。

| 方向 | 最小 | 最大 |
|------|------|------|
| A → B | 0 or 1 | 多数 |
| B → A | 0 or 1 | 多数 |

**判断基準テーブル:**

| 条件 | M:N判定 |
|------|---------|
| 両方向が「複数」 | ✅ |
| 片方が「1つのみ」 | ❌ → 1:N or 1:1 |

**実装ルール:**

- **接合テーブル（junction table）を作成** して2つの1:N関係に分解
- 接合テーブルは両エンティティのPKを複合主キーとして持つ

**例（author と book）:**

```
[author] |o────── ⋗| [author_book] |⋗──────o| [book]
                    ↑ 複合PK (author_id, book_id)
```

接合テーブル `author_book`:
```sql
CREATE TABLE author_book (
  author_id INT NOT NULL,
  book_id INT NOT NULL,
  PRIMARY KEY (author_id, book_id),
  FOREIGN KEY (author_id) REFERENCES author(author_id),
  FOREIGN KEY (book_id) REFERENCES book(book_id)
);
```

**なぜ両エンティティにFKを置けないか:**

- author側に `book_id` を配置すると、複数の本を書いた著者のレコードが重複
- book側に `author_id` を配置すると、複数の著者の本のレコードが重複
- PKが重複するため実装不可能

---

## オプショナリティ（最小カーディナリティ）

**オプショナリティ**: 最小カーディナリティが0（optional）か1（mandatory）かを示す。

### 最小カーディナリティ 0（optional）

- リレーションシップが**任意**（存在しなくてもよい）
- FK列に `NULL` を許可

**例:**
```
[user] |o────── ⋗| [purchase]
       ↑
    optional（ユーザーは購入しなくてもよい）
```

### 最小カーディナリティ 1（mandatory）

- リレーションシップが**必須**（必ず存在する必要がある）
- FK列に `NOT NULL` 制約を設定

**例:**
```
[review] ||────── ⋗| [user]
         ↑
    mandatory（レビューは必ずユーザーに紐づく）
```

### データ投入順序への影響

両最小カーディナリティが1の場合、データ投入時に循環依存が発生します。

**解決策:**
- 一方の最小カーディナリティを0に緩和
- データ投入順序: 0側 → 1側

**例:**
```
[department] |o──o| [manager]
             ↑
          緩和: 0 or 1
```

投入順序: department（FK=NULL可） → manager

---

## 強エンティティと弱エンティティ

### 定義

| タイプ | 定義 | PKの構成 |
|--------|------|----------|
| **強エンティティ** | 独立して存在可能（独自のPKを持つ） | 単独のPKまたは複合PK |
| **弱エンティティ** | 親エンティティに依存（親のPKを含む複合PKを持つ） | 親PK + 部分キー（partial key） |

### 判断基準テーブル

| 条件 | 弱エンティティ化の判断 |
|------|------------------------|
| エンティティが親なしで意味を持たない | ✅ 弱エンティティ化を検討 |
| 複合PKでシンプルになる | ✅ 弱エンティティ化を検討 |
| 単独のPKで十分 | ❌ 強エンティティのまま |
| 弱エンティティ化でパフォーマンスが低下 | ❌ 強エンティティのまま |

### 例（movie と ticket）

**弱エンティティとして設計:**

```
[movie] ||────── ⋗| [ticket]
        ↑
    identifying relationship
```

```sql
CREATE TABLE ticket (
  movie_id INT NOT NULL,
  seat_number CHAR(5) NOT NULL,
  showtime TIMESTAMP NOT NULL,
  PRIMARY KEY (movie_id, seat_number, showtime),
  FOREIGN KEY (movie_id) REFERENCES movie(movie_id)
    ON DELETE CASCADE
);
```

**強エンティティとして設計（代替案）:**

```sql
CREATE TABLE ticket (
  ticket_id INT PRIMARY KEY,  -- 独自のPK
  movie_id INT NOT NULL,
  seat_number CHAR(5) NOT NULL,
  showtime TIMESTAMP NOT NULL,
  FOREIGN KEY (movie_id) REFERENCES movie(movie_id)
);
```

### 弱エンティティ化の判断例（The Sci-Fi Collective）

| エンティティ | 弱エンティティ化 | 理由 |
|--------------|------------------|------|
| `user_address` | ✅ | 1:1関係 → emailをPKにすれば外部キー制約を削減 |
| `billing_address` | ✅ | 同上 |
| `purchase_product` | ✅ | 接合テーブルは常に弱エンティティ（複合PK） |
| `review` | ❌ | 複合PKでパフォーマンス低下 |
| `payment_method` | ❌ | 独自のPKで十分 |
| `purchase` | ❌ | 独自のPKで十分 |

---

## 接合テーブル（Junction Table）

### 目的

M:Nリレーションシップを2つの1:Nリレーションシップに分解するための中間テーブル。

### 設計ルール

1. **複合主キー**: 両エンティティのPKを組み合わせて複合PKを構成
2. **外部キー**: 両エンティティのPKを参照するFKを2つ設定
3. **弱エンティティ**: 接合テーブルは常に弱エンティティ

### 例（purchase と product）

**M:Nリレーションシップ:**
```
[purchase] ⋗────⋗ [product]
```

**接合テーブルで分解:**
```
[purchase] |o────── ⋗| [purchase_product] |⋗──────o| [product]
                      ↑ 複合PK (purchase_id, code)
```

```sql
CREATE TABLE purchase_product (
  purchase_id INT NOT NULL,
  code CHAR(12) NOT NULL,
  PRIMARY KEY (purchase_id, code),
  FOREIGN KEY (purchase_id) REFERENCES purchase(purchase_id),
  FOREIGN KEY (code) REFERENCES product(code)
);
```

### 接合テーブルに追加属性を持たせるケース

接合テーブルにリレーションシップ固有の属性を追加できます。

**例（購入時の商品情報）:**

```sql
CREATE TABLE purchase_product (
  purchase_id INT NOT NULL,
  code CHAR(12) NOT NULL,
  product_quantity INT NOT NULL,      -- 数量
  product_price DECIMAL(7,2) NOT NULL, -- 購入時の価格
  product_name VARCHAR(100) NOT NULL,  -- 購入時の商品名
  PRIMARY KEY (purchase_id, code),
  FOREIGN KEY (purchase_id) REFERENCES purchase(purchase_id),
  FOREIGN KEY (code) REFERENCES product(code)
);
```

**なぜ product_price と product_name を含めるか:**

- 商品の価格・名称は時間とともに変化する
- 過去のレシートを正確に再現するには、購入時点の値を保存する必要がある

---

## CASCADE DELETE との関係

弱エンティティは親エンティティに依存するため、親が削除されたら弱エンティティのレコードも削除されるべきです。

### CASCADE設定例

```sql
CREATE TABLE user_address (
  email VARCHAR(320) PRIMARY KEY,
  street_address VARCHAR(255),
  city CHAR(100) NOT NULL,
  state VARCHAR(20) NOT NULL,
  postal_code CHAR(5) NOT NULL,
  FOREIGN KEY (email) REFERENCES user(email)
    ON DELETE CASCADE  -- ユーザー削除時に住所も削除
    ON UPDATE CASCADE  -- メールアドレス変更時に同期
);
```

**CASCADE判断基準:**

| 条件 | ON DELETE CASCADE | ON UPDATE CASCADE |
|------|-------------------|-------------------|
| 弱エンティティ | ✅ | ✅ |
| 親なしで意味がない | ✅ | ✅ |
| 独立して保持すべき | ❌ SET NULL or RESTRICT | ✅（通常） |

---

## カーディナリティ調整（Cardinality Yoga）

データ投入を可能にするため、最小カーディナリティを1から0に緩和するテクニック。

### 緩和ルール

| リレーションシップタイプ | 緩和対象 | 理由 |
|-------------------------|----------|------|
| 1:1 | 先に作成されるエンティティの相手側 | データ投入順序の問題を回避 |
| 1:N | 多側（crow's foot側） | 1側のエンティティが先に存在可能 |
| M:N | 両側（接合テーブルを使うため不要なケースも） | ビジネスルールに依存 |

**例（department と manager）:**

```
[department] |o──o| [manager]
             ↑
        緩和: 0 or 1
```

投入順序: department（FK=NULL可） → manager

---

## まとめ

| 概念 | 実装のポイント |
|------|----------------|
| **ER図** | Crow's Foot記法で視覚化 |
| **1:1** | 最小カーディナリティ0の側にFK配置 |
| **1:N** | 多側（crow's foot側）にFK配置 |
| **M:N** | 接合テーブルで2つの1:Nに分解 |
| **弱エンティティ** | 親PKを含む複合PKを使用、CASCADE DELETE推奨 |
| **オプショナリティ** | 0=NULLable FK、1=NOT NULL FK |
| **カーディナリティ調整** | 両最小カーディナリティが1なら一方を0に緩和 |

**設計プロセスの順序:**

1. エンティティを特定
2. リレーションシップを特定（線を引く）
3. カーディナリティを決定（記号を追加）
4. 弱エンティティを検討
5. 接合テーブルを作成（M:Nの場合）
6. データ投入順序を検証し、最小カーディナリティを調整

このガイドに従うことで、データ冗長性を排除し、参照整合性を保った堅牢なリレーションシップ設計が可能になります。
