# エンティティとキー

要件分析で収集した「主語（Subject）」と「特性（Characteristics）」をエンティティ・属性に変換し、主キーを選定してデータ型を決定するための実践的ガイド。

---

## エンティティ識別プロセス

### 要件文からのエンティティ候補抽出

**基本原則：** 要件文の**主語（Subject）**がエンティティ候補、**特性（Characteristics）**が属性候補となる。

#### 手順

1. **インタビューで主語を収集する**
   - ステークホルダー・SME・IT/技術スタッフへのインタビューで、ビジネスの中核となる「人・場所・モノ・イベント」を抽出
   - 例: "ユーザーが商品をレビューする" → `user`, `product`, `review` が主語

2. **特性（Characteristics）を列挙する**
   - 各主語について「どんな情報を保持するか」を質問
   - 例: user の特性 → "アカウント情報、支払い方法"
   - 追加質問で詳細化: "アカウント情報には何が含まれるか？" → "ユーザー名、メールアドレス、電話番号、パスワード"

3. **主語-動詞-目的語パターンでリレーションシップを把握**
   - 要件文の動詞部分がリレーションシップ候補
   - 例: "ユーザーが注文を作成する" → user と order の間に1:N関係
   - 例: "注文が複数の商品を含む" → order と product の間にM:N関係

4. **サンプルデータを取得する**
   - 既存のスプレッドシート・紙フォーム・レガシーDBから実データをもらう
   - データサンプルはデータ型・精度・制約の判断に不可欠

---

### 主語→エンティティ変換の実例

**要件文の例：**
> "ユーザーは商品を購入し、支払い方法を登録し、レビューを投稿できる。商品には名前・価格・在庫数がある。"

**抽出結果：**

| 主語（Subject） | 特性（Characteristics） | エンティティ名 |
|----------------|----------------------|--------------|
| ユーザー | アカウント情報（username, email, phone, password） | user |
| 商品 | 名前、価格、在庫数、製造元 | product |
| レビュー | テキスト、投稿日時 | review |
| 支払い方法 | カード番号、有効期限 | payment_method |
| 購入 | 購入日時、合計金額 | purchase |

---

## 命名規則

一貫した命名規則はデータベースの保守性と使いやすさを大幅に向上させる。

### Singular vs Plural（単数形 vs 複数形）

| 方式 | 例 | 利点 | 欠点 | 推奨度 |
|------|-----|------|------|-------|
| **Singular（単数形）** | `user`, `product`, `order` | OOP的（1クラス=1テーブル）、Edgar Codd（RDBMSの父）が使用 | テーブルが複数行を持つ事実と不一致 | **推奨** |
| **Plural（複数形）** | `users`, `products`, `orders` | 自然な英語（"users table contains users"） | 複数形の不規則変化（person→people）で混乱 | 可 |

**重要：** どちらを選ぶかよりも、**プロジェクト全体で一貫させること**が最優先。本スキルではsingular（単数形）を採用。

---

### カラム名の命名規則比較

| 命名規則 | 例 | 特徴 | RDBMS互換性 | 推奨度 |
|---------|-----|------|------------|-------|
| **snake_case** | `first_name`, `user_id`, `created_at` | 小文字+アンダースコア、可読性高い | 全RDBMS対応 | **推奨** |
| camelCase | `firstName`, `userId`, `createdAt` | JavaScript/Java文化、大小文字区別必要 | 大小文字非区別RDBMSで問題 | △ |
| PascalCase | `FirstName`, `UserId`, `CreatedAt` | .NET文化 | 大小文字非区別RDBMSで問題 | △ |
| UPPERCASE | `FIRST_NAME`, `USER_ID`, `CREATED_AT` | 古典的SQL | 可読性低い | ✕ |
| Hungarian Notation | `strFirstName`, `intUserId` | 型情報を名前に含める | 冗長、メンテナンス困難 | ✕ |

**推奨：** snake_case - 全RDBMSで動作し、SQL予約語との衝突を避けやすく、可読性が最も高い。

---

### カラム名の長さ制限（RDBMS別）

| RDBMS | 最大長 | 備考 |
|-------|-------|------|
| MySQL / MariaDB | 64文字 | 最も一般的な制限 |
| PostgreSQL | 63文字 | NAMEDATALEN定数で変更可能だがデフォルト63 |
| SQL Server | 128文字 | 比較的余裕がある |
| Oracle | 30文字（Oracle 12.1以前）、128文字（12.2以降） | 古いバージョンは非常に厳しい |
| SQLite | 制限なし | 実用上は64文字程度に抑えるべき |

**ベストプラクティス：** 30文字以内に抑えると全RDBMSで互換性が保たれる。

---

### SQL予約語の回避

**重要：** SQL予約語（`SELECT`, `ORDER`, `INSERT`, `GROUP`, `JOIN`, `USER`, `TABLE`等）をエンティティ名・カラム名に使うと、構文エラー・保守性低下を引き起こす。

#### よくある問題と回避策

| 予約語 | 問題 | 回避策（推奨） |
|-------|------|--------------|
| `order` | `SELECT * FROM order` が構文エラー | `purchase`, `customer_order`, `order_record` |
| `user` | `INSERT INTO user` が一部RDBMSでエラー | `app_user`, `customer`, `account` |
| `group` | `CREATE TABLE group` が構文エラー | `user_group`, `team`, `category` |
| `date` | `SELECT date FROM ...` が関数と衝突 | `order_date`, `created_date`, `event_date` |
| `count` | `SELECT count FROM ...` が関数と衝突 | `item_count`, `total_count`, `quantity` |

**確認方法：**
- MySQL: [https://dev.mysql.com/doc/refman/8.0/en/keywords.html](https://dev.mysql.com/doc/refman/8.0/en/keywords.html)
- PostgreSQL: [https://www.postgresql.org/docs/current/sql-keywords-appendix.html](https://www.postgresql.org/docs/current/sql-keywords-appendix.html)
- 汎用: ChatGPTに "What are the common reserved keywords in SQL?" と質問

---

## キーの種類と選択

### キーの階層構造

データベース設計では、以下の順序でキーを絞り込んでいく：

```
Superkey（スーパーキー）
    ↓ 最小化（不要な列を除去）
Candidate Key（候補キー）
    ↓ 最適なものを選択
Primary Key（主キー）
```

#### 定義

| キーの種類 | 定義 | 例 |
|-----------|------|-----|
| **Superkey** | テーブルの行を一意に識別できる列の組み合わせ（冗長な列を含む可能性あり） | `(username, first_name)` - username だけで一意だが first_name も含む |
| **Candidate Key** | 最小のSuperkey（不要な列が含まれない） | `username`, `email`, `phone_number` が各々Candidate Key |
| **Primary Key** | Candidate Key の中から選ばれた1つ。テーブルを代表する主キー | `email` を選択（username より安定） |

---

### Candidate Key（候補キー）の識別プロセス

**手順：**
1. **単一列で一意性チェック** - 各列が単独で行を識別できるか確認
   - 例: `user` テーブル → `username`, `email`, `phone_number` が各々ユニーク
2. **複合列で一意性チェック** - 単一列で不十分なら、2列以上の組み合わせを検討
   - 例: `review` テーブル → `(review_text, review_time)` の組み合わせで一意（ただし完全ではない）
3. **最小性の確認** - 組み合わせから列を削っても一意性が保たれるか確認
   - 例: `(username, first_name)` → `username` だけで一意なら Candidate Key ではない

---

### Primary Key（主キー）の選定基準

複数のCandidate Keyがある場合、以下の5つの基準で評価し、最適なものを主キーに選ぶ。

| 基準 | 説明 | 評価ポイント |
|------|------|------------|
| **Unique（一意性）** | 値が重複しない | 必須条件（Candidate Keyは満たす） |
| **Stable（安定性）** | 値が変更されない | 変更されると外部キーの連鎖更新が必要 |
| **Simple（シンプル性）** | 理解しやすく、短い | 複合キーより単一列、文字列より数値 |
| **Non-null（非NULL性）** | NULLにならない | 必須条件（主キーはNOT NULL） |
| **Access Speed（アクセス速度）** | インデックス効率が高い | 短い数値型が最速 |

#### 実例: `user` テーブルの主キー選定

**Candidate Key 候補：** `username`, `email`, `phone_number`

| Candidate Key | Unique | Stable | Simple | Non-null | Access Speed | 総合評価 |
|--------------|--------|--------|--------|----------|--------------|---------|
| `username` | ✓ | △（ユーザーが変更可） | ✓ | ✓ | ○ | △ |
| `email` | ✓ | ✓（変更不可ポリシー） | ✓ | ✓ | ○ | **◎（推奨）** |
| `phone_number` | ✓ | △ | ✓ | ✕（未登録OK） | ○ | ✕ |

**結論：** `email` を主キーに選定。理由は安定性（ユーザーがメールアドレスを変更できないポリシー）。

---

## Natural Key vs Surrogate Key

### 定義

| キーの種類 | 定義 | 例 |
|-----------|------|-----|
| **Natural Key** | ビジネスデータそのもので一意に識別できる列 | `email`, `product_code`, `ISBN` |
| **Surrogate Key** | データベースが自動生成する人工的な識別子（通常は自動採番INT） | `user_id`, `product_id`, `review_id` |

---

### Natural Key vs Surrogate Key の判断基準

| 判断基準 | Natural Key 推奨 | Surrogate Key 推奨 |
|---------|-----------------|-------------------|
| **Candidate Key の品質** | 安定・単一列・短い・NULLなし | 不安定・複合キー・長い・NULLあり |
| **ビジネス要件** | 外部システムとの統合で Natural Key が必須 | 内部管理のみ（外部公開不要） |
| **冗長性排除の重要性** | 必須（例: user, product） | 許容可能（例: review, purchase） |
| **外部キーとしての使用頻度** | 低頻度 | 高頻度（多数のテーブルから参照） |
| **検索性能** | Natural Key が数値・短い | Natural Key が文字列・長い |

#### 実例1: `product` テーブル

**Candidate Key 候補：**
- `product_code`（UPC: 12桁数値）
- `(name, manufacturer)` の組み合わせ

**比較：**

| Candidate Key | 評価 |
|--------------|------|
| `product_code` | ✓ 安定、✓ シンプル（12桁）、✓ ユニーク、✓ 業界標準 → **Natural Key として採用** |
| `(name, manufacturer)` | ✕ 複合キー、△ 名前が長い、△ 将来的に変更リスク → ✕ |

**結論：** `product_code` を主キー（Natural Key）に選定。

---

#### 実例2: `review` テーブル

**属性：** `review_text`, `review_time`

**問題：**
- 単一列ではユニークではない（同じテキストのレビューが複数存在しうる）
- `(review_text, review_time)` の組み合わせも完全ではない（同時刻に同一テキストの可能性）

**解決策：** Surrogate Key `review_id` を新規作成（自動採番INT）

**冗長性の許容：**
- `user` や `product` では冗長性は致命的（どちらの行が正しいか判断不能）
- `review` では冗長性は許容可能（レビューはリスト表示され、各行を個別に識別できればよい）

**結論：** Surrogate Key `review_id INT AUTO_INCREMENT` を主キーに設定。

---

### Surrogate Key の実装

#### RDBMSごとの自動採番構文

| RDBMS | 自動採番構文 | 例 |
|-------|------------|-----|
| MySQL / MariaDB | `AUTO_INCREMENT` | `review_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY` |
| PostgreSQL | `SERIAL` または `GENERATED ALWAYS AS IDENTITY` | `review_id SERIAL PRIMARY KEY` |
| SQL Server | `IDENTITY(1,1)` | `review_id INT IDENTITY(1,1) PRIMARY KEY` |
| SQLite | `AUTOINCREMENT` | `review_id INTEGER PRIMARY KEY AUTOINCREMENT` |
| Oracle | `GENERATED ALWAYS AS IDENTITY` | `review_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |

---

### 複合キー（Composite Key）

**定義：** 2つ以上の列を組み合わせて主キーとするもの。

**使用場面：**
- M:N リレーションシップの接合テーブル（junction table）
- 例: `user_product_review` テーブルの主キー `(user_id, product_id)`

**メリット：**
- Natural Key として意味がある
- 重複行を自動的に防止

**デメリット：**
- 複雑（他テーブルからの外部キー参照が煩雑）
- パフォーマンス低下（複数列のインデックス）

**推奨：** 複合キーが自然なら採用してよいが、迷ったら Surrogate Key（ID列）を追加する方がシンプル。

---

## データ型選択ガイド

### 文字列型: VARCHAR vs CHAR vs TEXT

#### 基本方針

| データ型 | 使用場面 | 最大長指定 | 例 |
|---------|---------|----------|-----|
| **CHAR(n)** | 固定長文字列 | 必須（例: `CHAR(2)`） | 国コード `CHAR(2)` ("US", "JP") |
| **VARCHAR(n)** | 可変長文字列（短～中程度） | 必須（例: `VARCHAR(255)`） | 氏名 `VARCHAR(100)`, メール `VARCHAR(255)` |
| **TEXT** | 長文テキスト（数千文字以上） | 不要 | 商品説明、ブログ本文 |

---

#### VARCHAR vs CHAR の選択基準

| データの特性 | 推奨型 | 理由 |
|------------|-------|------|
| 長さが常に一定（例: 国コード2文字、郵便番号7桁） | `CHAR(n)` | 固定長なのでストレージ効率最適 |
| 長さが可変だが上限推定可能（例: 氏名≤100文字） | `VARCHAR(n)` | 短いデータはストレージ節約、長いデータも格納可 |
| 長さが不定で上限推定困難（例: 長文レビュー） | `TEXT` | 柔軟性高い、ただし検索性能は劣る |

---

#### VARCHAR長さの推定例

| データ種類 | 推定最大長 | 推奨VARCHAR長 | 備考 |
|----------|----------|-------------|------|
| 氏名（英語圏） | 30-50文字 | `VARCHAR(100)` | マージンを持たせる |
| メールアドレス | 254文字（RFC標準） | `VARCHAR(255)` | 255は一般的な上限 |
| 電話番号 | 15桁（国際標準） | `VARCHAR(15)` | 区切り文字含めて `VARCHAR(20)` も可 |
| URL | 2083文字（IE制限） | `VARCHAR(1000)` or `TEXT` | 長いURLに対応 |
| 商品説明 | 数千文字 | `TEXT` | VARCHAR(5000) より TEXT が適切 |

**推定が困難な場合：** ChatGPTに質問する（例: "What's the maximum length of common names?"）

---

#### TEXT型の注意点

**性能上の問題：**
- 一部RDBMSでは TEXT は行内（inline）に保存されず、別ストレージに保存されるため、検索が遅い
- フルテキストインデックスが必要（一部RDBMSでサポート不足）
- 例: MySQL 5.6以前のInnoDBエンジンはフルテキストインデックス非対応

**推奨：**
- 検索頻度が高い列は `VARCHAR(n)` にとどめる
- TEXT は description, content, notes 等の「長文だが検索頻度低い」列のみに使用

---

### 数値型: 整数型（INT系）

#### 整数型の種類とサイズ

| データ型 | バイト数 | Signed 範囲 | Unsigned 範囲 | 用途例 |
|---------|---------|------------|--------------|-------|
| **TINYINT** | 1 | -128 ~ 127 | 0 ~ 255 | フラグ、小さなカウント |
| **SMALLINT** | 2 | -32,768 ~ 32,767 | 0 ~ 65,535 | 小規模テーブルのID |
| **MEDIUMINT** | 3 | -8,388,608 ~ 8,388,607 | 0 ~ 16,777,215 | 中規模テーブルのID |
| **INT** | 4 | -2,147,483,648 ~ 2,147,483,647 | 0 ~ 4,294,967,295 | **主キー（推奨）** |
| **BIGINT** | 8 | -9,223,372,036,854,775,808 ~ ... | 0 ~ 18,446,744,073,709,551,615 | 超大規模テーブルのID |

**推奨：** 主キー（Surrogate Key）は `INT UNSIGNED` が標準。BIGINT は特殊事情がない限り不要。

---

#### Signed vs Unsigned の選択

| 用途 | 推奨 | 理由 |
|------|------|------|
| 主キー（ID列） | `UNSIGNED` | 負の値は不要。範囲が2倍に拡大 |
| 在庫数・カウント | `UNSIGNED` | 負の値は不要 |
| 金額（整数部分） | `SIGNED` | 返金・調整で負の値が必要な場合あり |
| 温度・座標 | `SIGNED` | 負の値が必須 |

---

#### 整数型でない数値データ（注意）

**カード番号・有効期限等は INT にしない：**

| データ | 誤った型 | 問題 | 正しい型 |
|-------|---------|------|---------|
| カード番号（16桁） | `BIGINT` | 先頭ゼロが消える（例: 0123456789012345 → 123456789012345） | `CHAR(16)` |
| 有効期限（MMYY） | `SMALLINT` | 先頭ゼロが消える（例: 0125 → 125） | `CHAR(4)` |
| 商品コード（UPC 12桁） | `BIGINT` | 先頭ゼロが消える | `CHAR(12)` |

**原則：** 算術演算を行わない数値は文字列型で保存する。

---

### 数値型: 小数型（DECIMAL vs FLOAT）

#### Floating-point vs Fixed-point

| データ型 | 種類 | 精度 | 用途 | 丸め誤差 |
|---------|------|------|------|---------|
| **FLOAT** | 浮動小数点（32bit） | 約7桁 | センサー値、統計、物理シミュレーション | あり（許容） |
| **DOUBLE** | 浮動小数点（64bit） | 約15桁 | 科学計算、座標 | あり（許容） |
| **DECIMAL(p, s)** / **NUMERIC(p, s)** | 固定小数点 | 指定精度 | **金額（必須）**、会計 | なし |

**警告：** 金額・会計データに FLOAT/DOUBLE を使うと、丸め誤差で数セント単位の損失が発生する。必ず DECIMAL を使用すること。

---

#### DECIMAL(p, s) の指定方法

**構文：** `DECIMAL(precision, scale)`
- **precision（精度）**: 全体の桁数（整数部+小数部）
- **scale（スケール）**: 小数点以下の桁数

**例：** `DECIMAL(7, 2)` → 整数5桁+小数2桁 → 最大 99999.99

| データ | 推奨型 | 理由 |
|-------|-------|------|
| 商品価格（\$0.01 ~ \$9,999.99） | `DECIMAL(7, 2)` | 精度7（整数5桁+小数2桁）、スケール2（セント） |
| 取引合計金額（\$0.01 ~ \$999,999,999.99） | `DECIMAL(13, 2)` | 大きな取引に対応 |
| 為替レート（例: 0.83456789） | `DECIMAL(12, 8)` | 高精度が必要 |
| 重量（kg, 0.001単位） | `DECIMAL(10, 3)` | スケール3（グラム単位） |

---

### 日時型: DATE vs TIME vs DATETIME vs TIMESTAMP

#### 日時型の種類

| データ型 | 保存内容 | 例 | 用途 |
|---------|---------|-----|------|
| **DATE** | 日付のみ | `1980-05-15` | 誕生日、期限日 |
| **TIME** | 時刻のみ | `14:30:00` | 営業時間、勤務時間 |
| **DATETIME** | 日付+時刻（タイムゾーン非保持） | `2025-02-12 14:30:00` | ローカルタイム、予約日時 |
| **TIMESTAMP** | 日付+時刻（UTC自動変換） | `2025-02-12 14:30:00 UTC` | ログ、作成/更新日時（**推奨**） |

---

#### DATETIME vs TIMESTAMP の選択基準

| 特性 | DATETIME | TIMESTAMP |
|------|---------|-----------|
| タイムゾーン変換 | なし（保存した値そのまま） | あり（UTCで保存、取得時にローカル変換） |
| 範囲 | 1000-01-01 ~ 9999-12-31 | 1970-01-01 ~ 2038-01-19（一部RDBMSは拡張） |
| 用途 | イベント日時（タイムゾーン固定） | ログ・監査・作成日時（グローバル対応） |
| 推奨場面 | ローカル限定アプリ（飲食店の予約等） | **グローバルアプリ（推奨）** |

**ベストプラクティス：** グローバルアプリでは TIMESTAMP を使い、UTC で保存する。アプリケーション層でローカルタイムに変換して表示。

---

#### UTC（Coordinated Universal Time）の重要性

**問題：** 日時をローカルタイム（例: JST, PST）で保存すると以下の問題が発生：
- 異なるタイムゾーンのユーザー間で時刻比較が困難
- 夏時間（Daylight Saving Time）の切り替えで1時間のずれ
- ユーザーが旅行中にローカルタイムが変わる

**解決策：** UTC（世界協定時）で統一保存。

**実装例：**
```sql
CREATE TABLE review (
    review_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    review_text TEXT NOT NULL,
    review_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- UTCで自動記録
    ...
);
```

**アプリケーション側の変換：**
- JavaScript: `new Date(utc_timestamp).toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' })`
- Python: `datetime.utcnow()` で保存、`pytz` ライブラリで表示時に変換

---

## データ型選択のチェックリスト

設計時に以下を確認すること：

### 文字列型チェック

- [ ] 固定長データ（国コード等）は `CHAR(n)` を使用
- [ ] 可変長データ（氏名・メール等）は `VARCHAR(n)` を使用、長さ上限を適切に設定
- [ ] 長文データ（description等）は `TEXT` を使用
- [ ] SQL予約語を列名に使用していない
- [ ] 列名が64文字以内（MySQL/MariaDB制限）

### 数値型チェック

- [ ] 主キー（ID列）は `INT UNSIGNED` を使用
- [ ] 算術演算を行わない数値（カード番号・商品コード等）は `CHAR(n)` を使用
- [ ] 金額データは `DECIMAL(p, s)` を使用（FLOAT/DOUBLE禁止）
- [ ] スケール（小数点以下桁数）を適切に設定（金額なら2）

### 日時型チェック

- [ ] ローカルアプリでは `DATE`, `TIME`, `DATETIME` を使用
- [ ] グローバルアプリでは `TIMESTAMP` を使用し、UTCで保存
- [ ] ログ・監査・作成日時には `TIMESTAMP` を使用（`DEFAULT CURRENT_TIMESTAMP`）
- [ ] 誕生日等の日付のみのデータは `DATE` を使用

---

**データ型選択は、データベースの性能・整合性・保守性に直結する。サンプルデータを必ず確認し、慎重に決定すること。**
