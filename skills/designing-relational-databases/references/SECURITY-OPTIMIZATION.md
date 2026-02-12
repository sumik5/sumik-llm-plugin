# セキュリティと最適化

## セキュリティレビュー

データベースのセキュリティは、データ漏洩を防ぎ、整合性と機密性を維持するために重要です。

### 整合性（Integrity）チェック

データの正確性、完全性、信頼性を維持するための設計原則：

**チェックリスト：**

- [ ] **すべてのカラムに適切なデータ型が設定されているか**
  - 数値は適切な精度とサイズを持つか（INT、DECIMAL等）
  - 文字列は適切な長さ制限を持つか（VARCHAR、CHAR等）
  - 日付時刻型は要件に合致しているか（DATE、DATETIME、TIMESTAMP等）

- [ ] **すべてのテーブルに主キー（Primary Key）が存在するか**
  - 各テーブルが一意の識別子を持つか
  - 主キーは自動的にインデックスされる

- [ ] **外部キー（Foreign Key）制約が正しく設定されているか**
  - 親テーブルと子テーブルの関係が明示的に定義されているか
  - 孤立レコード（orphan record）を防ぐ制約が機能するか

- [ ] **要件分析に基づくNOT NULL、UNIQUE等の制約が反映されているか**
  - 必須カラムにNOT NULL制約が設定されているか
  - 一意性を保証すべきカラムにUNIQUE制約が設定されているか
  - ビジネスルールに基づくCHECK制約が適用されているか

**外部キー制約の例：**

```sql
-- 悪い例：外部キー制約なし
CREATE TABLE book (
  book_id INT PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  author_id INT NOT NULL
);

-- 良い例：外部キー制約あり
CREATE TABLE book (
  book_id INT PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  author_id INT NOT NULL,
  CONSTRAINT FK_author_id
    FOREIGN KEY (author_id)
    REFERENCES author(author_id)
);
```

### 機密性（Confidentiality）

情報への不正アクセスと開示を防ぎ、認可されたユーザーとプロセスのみがデータにアクセスできるようにする。

#### MAC（Mandatory Access Control）

中央集権的な厳格なアクセス制御。データに機密レベルを設定し、ユーザーのクリアランスと照合する。

**特徴：**
- テーブルや行に機密レベル（sensitive、confidential等）を設定
- ユーザーのクリアランスが一致しない場合はアクセス不可
- 例外なし、非常に厳格

**例：高校の生徒データベース**

| テーブル | 機密レベル |
|---------|-----------|
| student_basic | Public |
| student_grades | Sensitive |
| student_health | Confidential |

ユーザーは自分のクリアランスに対応するテーブルにのみアクセス可能。

#### RBAC（Role-Based Access Control）推奨

柔軟で管理しやすいアクセス制御。ロールに権限を割り当て、ユーザーをロールに割り当てる。

**RBACの手順：**

1. **ロール作成**
2. **ロールに権限を付与（GRANT）**
3. **ユーザーにロールを割り当て**

**例：The Sci-Fi Collectiveのデータベース**

対象テーブル：`product`, `purchase`, `purchase_product`, `review`

**USERロール（標準ユーザー）：**

```sql
-- step 1: ロール作成
CREATE ROLE standard_user;

-- step 2: 権限付与
GRANT SELECT ON database_name.product TO standard_user;
GRANT INSERT ON database_name.purchase TO standard_user;
GRANT INSERT ON database_name.purchase_product TO standard_user;
GRANT INSERT ON database_name.review TO standard_user;

-- step 3: ユーザーにロール割当
CREATE USER 'morpheus'@'%' IDENTIFIED BY 'password';
GRANT standard_user TO 'morpheus'@'%';
```

**ANALYSTロール（分析者）：**

```sql
-- step 1: ロール作成
CREATE ROLE analyst;

-- step 2: 権限付与（ビュー専用）
GRANT SELECT ON database_name.product TO analyst;
GRANT SELECT ON database_name.purchase TO analyst;
GRANT SELECT ON database_name.purchase_product TO analyst;
GRANT SELECT ON database_name.review TO analyst;

-- step 3: ユーザーにロール割当
CREATE USER 'smith'@'%' IDENTIFIED BY 'password';
GRANT analyst TO 'smith'@'%';
ALTER USER 'smith'@'%' DEFAULT ROLE analyst;
```

**ADMINロール（管理者）：**

```sql
-- step 1: ロール作成
CREATE ROLE admin;

-- step 2: 権限付与（全操作）
GRANT SELECT, INSERT, UPDATE, DELETE
  ON database_name.product TO admin;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON database_name.purchase TO admin;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON database_name.purchase_product TO admin;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON database_name.review TO admin;

-- step 3: ユーザーにロール割当
CREATE USER 'david'@'%' IDENTIFIED BY 'password';
GRANT admin TO 'david'@'%';
ALTER USER 'david'@'%' DEFAULT ROLE admin;
```

**権限の対応：**

| 操作 | SQL | 意味 |
|-----|-----|------|
| ビュー | `SELECT` | テーブルの参照 |
| 追加 | `INSERT` | データの挿入 |
| 更新 | `UPDATE` | データの変更 |
| 削除 | `DELETE` | データの削除 |

#### 暗号化

機密データ（クレジットカード、パスワード等）は暗号化して保存する。

**一方向暗号化（One-way Encryption / Hashing）：**

- ハッシュ化後は元のデータに戻せない
- パスワード保管に使用（ユーザーがパスワードを再利用することが多いため）
- 一般的なアルゴリズム：bcrypt、PBKDF2、Sha512

**例：パスワードカラムの設計**

bcryptでハッシュ化すると40バイトのバイナリデータになる。Base64エンコード後は60バイトの文字列になる。

```sql
-- 修正前
password VARCHAR(20)

-- 修正後（bcrypt対応）
password CHAR(60)

-- 実装済みの場合
ALTER TABLE user MODIFY COLUMN password CHAR(60);
```

**認証プロセス：**

1. ユーザーがログイン時に入力したパスワードをハッシュ化
2. ハッシュ化された値とDB内のハッシュ値を比較
3. 一致すれば認証成功

**Salt（ソルト）：**

- ランダムな文字列をパスワードに連結してからハッシュ化
- ブルートフォース攻撃やレインボーテーブル攻撃を防ぐ
- アプリケーション側で管理

**対称暗号化（Symmetric Encryption）：**

- 暗号化と復号化が可能（可逆的）
- 繰り返し使用する機密情報の保護に使用（クレジットカード情報等）
- 同じ鍵とアルゴリズムで暗号化・復号化
- 一般的なアルゴリズム：AES、3DES、Blowfish

**AES暗号化のプロセス：**

```
平文データ → AES-256 暗号化（秘密鍵使用） → バイナリデータ → Base64エンコード → 保存
保存データ → Base64デコード → バイナリデータ → AES-256 復号化（秘密鍵使用） → 平文データ
```

**例：クレジットカード情報の暗号化**

AES-256 + IV（Initialization Vector）を使用した場合：

- `card_number`（16バイト）→ 16バイトブロック + 16バイトIV = 32バイト → Base64エンコード → 約45バイト
- `expiry_date`（短いデータ）→ パディングで16バイトブロック + 16バイトIV = 32バイト → Base64エンコード → 約45バイト

```sql
-- 修正前
card_number VARCHAR(16)
expiry_date VARCHAR(7)

-- 修正後（AES-256対応）
card_number CHAR(45)
expiry_date CHAR(45)

-- 実装済みの場合
ALTER TABLE payment_method
  MODIFY COLUMN card_number CHAR(45),
  MODIFY COLUMN expiry_date CHAR(45);
```

**暗号化の使い分け：**

| 暗号化方式 | 用途 | 特徴 |
|-----------|------|------|
| 一方向（Hashing） | パスワード | 復号化不可、強固 |
| 対称暗号化 | クレジットカード等の再利用データ | 復号化可能、鍵管理が重要 |

**対称暗号化の注意点：**

- **鍵の管理が重要**：鍵が漏洩するとすべてのデータが危険にさらされる
- **鍵の保管方法**：
  - アプリケーションサーバーの環境変数
  - 鍵管理サービス（Key Management Service）
  - ハードウェアセキュリティモジュール（HSM）
- **DBと同じ場所に鍵を保管しない**

---

## ストレージ最適化

正規化を超えてデータ冗長性をさらに削減し、ストレージ効率を向上させる。

### 冗長テーブルの統合

類似構造のテーブルを統合して冗長性を削減する。

**例：住所テーブルの統合**

**統合前：**

```
billing_address テーブル
├─ billing_address_id (PK)
├─ street_address
├─ address_line_optional
├─ city
├─ state
└─ postal_code

user_address テーブル
├─ user_address_id (PK)
├─ street_address
├─ address_line_optional
├─ city
├─ state
└─ postal_code
```

2つのテーブルはほぼ同一の構造。ユーザーと支払方法が同じ住所を使用する場合、データが重複する。

**統合後：**

1つの`address`テーブルを作成し、`user`と`payment_method`の両方から参照する。

```
address テーブル
├─ address_id (PK, surrogate key)
├─ street_address
├─ address_line_optional
├─ city
├─ state
├─ postal_code
└─ UNIQUE(street_address, address_line_optional, postal_code, city, state)

user テーブル
└─ address_id (FK, NULL可)

payment_method テーブル
└─ address_id (FK, NOT NULL)
```

**Surrogate Key + UNIQUE制約パターン：**

- **Surrogate Key（address_id）**：自動増分の単一カラム、外部キーとして使いやすい
- **UNIQUE制約**：すべての非キーカラムの組み合わせに適用し、重複データを防ぐ

**統合手順（実装済みDBの場合）：**

```sql
-- 1. 古いテーブルを削除
DROP TABLE billing_address;
DROP TABLE user_address;

-- 2. 新しいテーブルを作成
CREATE TABLE IF NOT EXISTS address (
  address_id INT AUTO_INCREMENT PRIMARY KEY,
  street_address VARCHAR(255) NOT NULL,
  address_line_optional VARCHAR(100),
  city VARCHAR(100) NOT NULL,
  state VARCHAR(20) NOT NULL,
  postal_code CHAR(5) NOT NULL,
  CONSTRAINT unique_address_constraint
    UNIQUE (street_address, address_line_optional, postal_code, city, state)
);

-- 3. payment_methodテーブルを更新
ALTER TABLE payment_method
  ADD COLUMN address_id INT NOT NULL;
ALTER TABLE payment_method
  ADD CONSTRAINT fk_address_payment_method
    FOREIGN KEY (address_id)
    REFERENCES address(address_id);

-- 4. userテーブルを更新（NULL可）
ALTER TABLE user
  ADD COLUMN address_id INT NULL;
ALTER TABLE user
  ADD CONSTRAINT fk_address_user
    FOREIGN KEY (address_id)
    REFERENCES address(address_id);
```

**注意点：**

- `user`の`address_id`はNULL可（ユーザー登録時に住所なしで登録可能）
- `payment_method`の`address_id`はNOT NULL（支払方法には住所必須）
- NULLを含む外部キーはオプショナルな関係を表す

### カテゴリカルデータの分離

繰り返しの多い有限値カラムを別テーブルに分離する（ルックアップテーブルパターン）。

**例：州（state）カラムの分離**

**分離前：**

```
address テーブル
├─ address_id (PK)
├─ street_address
├─ address_line_optional
├─ city
├─ state VARCHAR(20)  ← 50州+DC = 51種類のみ、大量の重複
└─ postal_code
```

数百万ユーザーがいても、`state`カラムには51種類の値しか存在しない。大量の冗長データが発生。

**分離後：**

```
state テーブル
├─ state_abbr CHAR(2) (PK, natural key)
└─ state_name VARCHAR(50)

address テーブル
├─ address_id (PK)
├─ street_address
├─ address_line_optional
├─ city
├─ state_abbr CHAR(2) (FK) ← stateテーブルを参照
└─ postal_code
```

**Natural Key（自然キー）の適用：**

- 州の略称（CA、NY等）はすべて2文字で一意
- 実世界のコンセプトとして意味を持つ
- Surrogate Keyではなく、Natural Keyが適する場合

**メリット：**

- ストレージの大幅削減
- データの一貫性向上（州名のタイプミス防止）
- 参照整合性の保証

---

## インデックス戦略

データ検索を高速化するための最適化技術。カラムにインデックスを作成し、データ検索・ソート・検索を効率化する。

### 標準インデックス

B-treeベースの構造で、検索・ソート・シーケンシャルアクセスを対数時間で実現する。

**Bツリー（B-tree）：**

- 自己平衡型ツリー構造
- ソート済みデータを保持
- 対数時間での検索・挿入・削除を可能にする

**インデックス作成例：**

```sql
-- 映画の評価（rating）でソート・検索が頻繁な場合
CREATE INDEX idx_rating ON movie (rating);

-- クエリ実行時にインデックスを使用
SELECT * FROM movie
  ORDER BY rating DESC
  LIMIT 30;

-- WHERE句での検索もインデックスを使用
SELECT * FROM movie
  WHERE rating = 5;
```

**インデックスの動作：**

1. インデックス作成時、DBエンジンがテーブル全体をスキャン
2. インデックス対象カラムの値とポインタを記録
3. クエリ実行時、インデックスを使用して高速アクセス

**主キーの自動インデックス：**

すべての主キーは自動的にインデックスされる。明示的なCREATE INDEX不要。

### 複合インデックス

複数カラムの組み合わせにインデックスを作成する。

**作成例：**

```sql
-- release_dateとratingの両方でソートが頻繁な場合
CREATE INDEX idx_combo ON movie (rating, date);

-- クエリ実行
SELECT * FROM movie
  ORDER BY rating DESC, date DESC
  LIMIT 30;
```

**カラム順序の重要性：**

- インデックスのカラム順序はクエリのフィルタ順序と一致すべき
- 最も選択性の高いカラムを最初に配置することが多い

### フルテキストインデックス

テキスト検索（キーワード検索、部分一致、ファジー検索）を効率化する。

**標準インデックスとの違い：**

| 標準インデックス | フルテキストインデックス |
|----------------|----------------------|
| 完全一致・ソート | キーワード検索 |
| `=`, `>`, `<` | 部分単語一致 |
| 数値・日付に最適 | テキスト検索に最適 |

**作成例（MySQL/MariaDB）：**

```sql
-- フルテキストインデックス作成
CREATE FULLTEXT INDEX ft_idx_title ON movie (title);

-- 検索実行
SELECT * FROM movie
  WHERE MATCH(title)
  AGAINST('exciting' IN NATURAL LANGUAGE MODE);
```

**非効率な方法（フルテキストインデックスなし）：**

```sql
-- 避けるべき：LIKEによる検索は非効率
SELECT * FROM movie
  WHERE title LIKE '%exciting%';
```

**PostgreSQLの場合：**

```sql
-- フルテキストインデックス作成
ALTER TABLE movie ADD COLUMN tsv_title tsvector;
UPDATE movie
  SET tsv_title = to_tsvector('english', title);
CREATE INDEX gin_idx_title
  ON movie USING gin(tsv_title);
```

**RDBMSごとに構文が異なる**：ChatGPTで適応方法を確認推奨。

### インデックス追加の判断基準テーブル

| 条件 | インデックス追加 | 理由 |
|-----|----------------|------|
| **WHERE/ORDER BY/JOINで頻繁に使用されるカラム** | ✅ 追加 | クエリ性能が大幅に向上 |
| **テーブルの行数が多い** | ✅ 追加 | フルテーブルスキャンを回避 |
| **INSERT/UPDATEが頻繁** | ⚠️ 慎重に | インデックス維持コストが高い |
| **カーディナリティが低い**（値の種類が少ない） | ❌ 不要 | インデックスの効果が薄い |
| **テーブルが小さい**（数千行以下） | ❌ 不要 | フルスキャンでも十分高速 |

**カーディナリティ（Cardinality）：**

- カラム内の一意な値の数
- 高いカーディナリティ：ユーザーID（数百万種類）→ インデックス効果大
- 低いカーディナリティ：性別（2-3種類）→ インデックス効果小

### インデックスの注意点

**過度なインデックスのデメリット：**

- **書き込み性能の低下**：INSERT/UPDATE/DELETE時にインデックスも更新が必要
- **ストレージ消費**：インデックス自体がディスク容量を消費
- **メンテナンスコスト**：不要なインデックスの管理コスト

**ベストプラクティス：**

- 測定に基づいてインデックスを追加（推測ではなく実測）
- 不要なインデックスの定期的な見直し
- クエリログとパフォーマンスメトリクスを分析
- バックエンドエンジニアとの密接な協力

---

## 非正規化（Denormalization）

意図的に正規化ルールを破り、読み取り性能を改善する最終手段。

### 非正規化の定義

**非正規化 = 意図的な冗長性の導入**

- 目的：クエリ性能の向上（特にJOINの削減）
- トレードオフ：データ整合性のリスク増加
- 適用：慎重なコストベネフィット分析の後

### 非正規化パターン

**1. テーブル統合**

頻繁にJOINする2つのテーブルを1つに統合する。

**例：音楽アプリのデータベース**

```
統合前：
artist ← album ← song
(3テーブルのJOIN必須)

統合後：
artist ← song
(2テーブルのJOINで済む)
```

統合により`song`テーブルに`artist_id`を追加し、推移的依存が発生する（正規化違反）。

**2. 冗長カラム追加**

よく参照する値を他のテーブルにコピー保持する。

**3. 要約テーブル/マテリアライズドビュー**

集計結果を事前計算して保存する。

### 非正規化の判断基準テーブル

| 条件 | 判断 | 理由 |
|-----|------|------|
| **読み取りが書き込みより圧倒的に多い** | ✅ 検討 | 読み取り最適化の効果大 |
| **複雑なJOINが頻繁** | ✅ 検討 | クエリ簡素化・性能向上 |
| **データ整合性が最優先** | ❌ 避ける | 更新異常のリスク高い |
| **テーブル間の更新頻度が高い** | ❌ 避ける | 同期コスト大 |
| **アプリケーションロジックで整合性を保証可能** | ✅ 検討 | リスク軽減可能 |

### 歴史データの保持

**例：purchase_productテーブル**

```
purchase_product テーブル
├─ purchase_product_id (PK)
├─ purchase_id (FK)
├─ code (FK → product)
├─ product_price      ← productテーブルの値をコピー
└─ product_name       ← productテーブルの値をコピー
```

**なぜ冗長にコピーするのか？**

- 製品の価格・名前は時間経過で変わる可能性がある
- 購入時点の価格・名前を記録しないと、過去の購入履歴が不正確になる

**時間経過で変わるデータの設計パターン：**

| パターン | 実装方法 |
|---------|---------|
| **スナップショット保存** | トランザクション時点の値をコピー保持（非正規化） |
| **履歴テーブル** | 別テーブルで時系列データを管理（正規化） |

### 非正規化の実例：The Sci-Fi Collective

**シナリオ：**

ユーザーが注文履歴を頻繁にチェックする。以下のクエリが高頻度で実行される：

```sql
SELECT * FROM purchase
  INNER JOIN payment_method
    ON purchase.payment_method_id = payment_method.payment_method_id
  INNER JOIN user
    ON payment_method.email = user.email
  WHERE user.email = 'customerCat@humor.com';
```

**問題点：**

- 3テーブルのJOINが頻繁
- `payment_method`テーブルは出力にほとんど貢献しない
- パフォーマンスとコストの問題

**非正規化の決定：**

`user`と`purchase`の直接関係を復元する（以前に正規化で削除した関係）。

```
非正規化後：
user ← payment_method
user ← purchase  ← 直接関係を復元

purchase テーブルに email (FK) を追加
→ 推移的依存が発生（BCNF違反）
```

**コストベネフィット分析：**

| 項目 | 評価 |
|-----|------|
| 読み取り頻度 | ✅ 非常に高い（オンラインストアの注文履歴） |
| 更新頻度 | ✅ 低い（emailは変更不可、主キー） |
| 挿入異常 | ✅ なし（購入にはアカウント必須） |
| 削除異常 | ✅ なし（emailは変更不可） |
| 結論 | ✅ 非正規化を実施 |

**推移的依存：**

```
purchase_id → payment_method_id → email
```

ただし、ビジネスロジック上の制約により更新異常は発生しない。

### 非正規化後の注意点

**1. データ整合性の管理**

- 冗長データの更新時、すべての関連テーブルを更新
- アプリケーションロジックで整合性を保証

**2. パフォーマンスの継続監視**

- INSERT/UPDATE/DELETEの頻度が増えると効果が減少
- 定期的な再評価が必要

**3. ドキュメント化と合意形成**

- 非正規化は論争を招く可能性がある
- 根拠・トレードオフ・実装戦略を文書化
- 開発チーム・ステークホルダーとの合意形成

---

## まとめ

### セキュリティ

- **整合性チェックリスト**：データ型、主キー、外部キー、制約の確認
- **RBAC推奨**：柔軟で管理しやすいアクセス制御
- **暗号化**：パスワードは一方向（bcrypt）、再利用データは対称暗号化（AES）

### ストレージ最適化

- **冗長テーブル統合**：Surrogate Key + UNIQUE制約パターン
- **カテゴリカルデータ分離**：ルックアップテーブル、Natural Key活用

### インデックス

- **標準インデックス**：B-tree、ソート・検索の高速化
- **複合インデックス**：複数カラム、順序が重要
- **フルテキストインデックス**：キーワード検索、部分一致
- **判断基準**：頻度・行数・カーディナリティで評価

### 非正規化

- **最終手段**：読み取り性能最適化のための意図的な冗長化
- **判断基準**：読み取り頻度 >> 書き込み頻度
- **リスク**：データ整合性の管理が必須
- **ドキュメント化**：根拠・トレードオフを明確に記録
