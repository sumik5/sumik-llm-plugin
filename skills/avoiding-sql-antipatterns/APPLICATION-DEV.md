# アプリケーション開発のアンチパターン

> データベースを扱うアプリケーションコードにおける設計・実装の落とし穴と、その解決策。

---

### 19. リーダブルパスワード（Readable Passwords）

**問題**: パスワードを平文または復元可能な形式でデータベースに保存している。
**検出シグナル**: パスワード再通知メールに実際のパスワードが記載されている。

| 項目 | 内容 |
|------|------|
| 目的 | ユーザーがパスワードを忘れた際にリカバリー機能を提供する |
| アンチパターン | パスワードを平文または復元可能な暗号化で格納し、リクエストに応じてメールで送信する |
| 解決策 | ソルト付きハッシュ（bcrypt/Argon2/SHA-256以上）でパスワードを格納し、リセット用の一時トークンを発行する |
| 例外 | 外部サービスにアクセスするためのパスワード（アプリケーションがクライアント側の場合）は解読可能な形式で格納する必要がある |

**コード例:**
```sql
-- ❌ アンチパターン（平文保存）
CREATE TABLE Accounts (
  account_id SERIAL PRIMARY KEY,
  password VARCHAR(30) NOT NULL
);
INSERT INTO Accounts (account_id, password) VALUES (123, 'xyzzy');

-- ✅ 解決策（ソルト付きハッシュ）
CREATE TABLE Accounts (
  account_id SERIAL PRIMARY KEY,
  password_hash CHAR(64) NOT NULL,
  salt BINARY(20) NOT NULL
);
INSERT INTO Accounts (account_id, password_hash, salt)
  VALUES (123, SHA2('xyzzy' || 'G0y6cf3$.ydLVkx4I/50', 256), 'G0y6cf3$.ydLVkx4I/50');

-- パスワードリセット用トークンテーブル
CREATE TABLE PasswordResetRequest (
  token CHAR(32) PRIMARY KEY,
  account_id BIGINT UNSIGNED NOT NULL,
  expiration TIMESTAMP NOT NULL,
  FOREIGN KEY (account_id) REFERENCES Accounts(account_id)
);
```

---

### 20. SQLインジェクション（SQL Injection）

**問題**: ユーザー入力を検証せずにSQL文字列に直接挿入している。
**検出シグナル**: SQL文字列の構築に文字列連結や変数展開を使用している箇所。

| 項目 | 内容 |
|------|------|
| 目的 | アプリケーション変数の値を使って動的なSQLクエリを構築する |
| アンチパターン | 未検証の入力値をSQL文字列に直接連結し、SQLの構文を改変できる脆弱性を作り出す |
| 解決策 | プリペアドステートメントを使用し、入力値をフィルタリングし、識別子はマッピング配列で管理する |
| 例外 | 適切なエスケープ処理とバリデーションが完全に実施されている場合でも、プリペアドステートメントが最善策 |

**コード例:**
```php
// ❌ アンチパターン（文字列連結）
<?php
$bug_id = $_REQUEST["bug_id"];
$sql = "SELECT * FROM Bugs WHERE bug_id = $bug_id";
$stmt = $pdo->query($sql);

// ✅ 解決策（プリペアドステートメント）
<?php
$sql = "SELECT * FROM Bugs WHERE bug_id = ?";
$stmt = $pdo->prepare($sql);
$stmt->bindValue(1, $_REQUEST["bug_id"], PDO::PARAM_INT);
$stmt->execute();

// ✅ 識別子のマッピング
<?php
$sortorders = array("status" => "status", "date" => "date_reported");
$directions = array("up" => "ASC", "down" => "DESC");
$sortorder = $sortorders[$_REQUEST["order"]] ?? "bug_id";
$direction = $directions[$_REQUEST["dir"]] ?? "ASC";
$sql = "SELECT * FROM Bugs ORDER BY $sortorder $direction";
```

---

### 21. シュードキー・ニートフリーク（Pseudokey Neat-Freak）

**問題**: 疑似キーの欠番を埋めるために既存行のキー値を再割り当てしている。
**検出シグナル**: 「使用されていない最初のIDを取得するクエリ」「主キー値の更新」。

| 項目 | 内容 |
|------|------|
| 目的 | 主キー値を連続した番号にして欠番をなくす |
| アンチパターン | 欠番に新しい値を割り当てたり、既存行の主キーを更新して欠番を詰める |
| 解決策 | 疑似キーは行の識別子であり行番号ではないと理解する。欠番は放置する。行番号が必要ならROW_NUMBER関数を使う |
| 例外 | 自然キー（意味を持つキー）の値は変更することがある。疑似キーは変更してはならない |

**コード例:**
```sql
-- ❌ アンチパターン（欠番を詰める）
UPDATE Bugs SET bug_id = 3 WHERE bug_id = 4;  -- 危険: 外部参照が壊れる

-- ✅ 解決策（欠番は放置、行番号が必要な場合）
SELECT t1.* FROM
  (SELECT a.account_name, b.bug_id, b.summary,
     ROW_NUMBER() OVER (ORDER BY a.account_name, b.date_reported) AS rn
   FROM Accounts a INNER JOIN Bugs b ON a.account_id = b.reported_by) AS t1
WHERE t1.rn BETWEEN 51 AND 100;

-- ✅ GUID使用（欠番の概念自体をなくす）
CREATE TABLE Bugs (
  bug_id UNIQUEIDENTIFIER DEFAULT NEWID(),
  summary VARCHAR(200)
);
```

---

### 22. シー・ノー・エビル（See No Evil）

**問題**: データベースAPI関数の戻り値やエラーステータスを確認していない。
**検出シグナル**: 「データベースにクエリを発行した後でプログラムがクラッシュする」「エラー処理でコードをゴチャゴチャさせたくない」。

| 項目 | 内容 |
|------|------|
| 目的 | 簡潔でエレガントなコードを書く |
| アンチパターン | 戻り値チェックや例外処理を省略し、エラーが発生しても気づかない |
| 解決策 | すべてのデータベース操作の後で戻り値と例外をチェックし、構築されたSQLを直接確認してデバッグする |
| 例外 | 接続のcloseなど、エラーが発生しても影響がない操作。または例外を呼び出し元に委譲できる場合 |

**コード例:**
```php
// ❌ アンチパターン（エラーチェックなし）
<?php
$pdo = new PDO("mysql:dbname=test;host=localhost", "user", "pass");
$stmt = $pdo->prepare($sql);
$stmt->execute(array(1, "OPEN"));
$bug = $stmt->fetch();

// ✅ 解決策（適切なエラーハンドリング）
<?php
try {
    $pdo = new PDO("mysql:dbname=test;host=localhost", "user", "pass");
} catch (PDOException $e) {
    report_error($e->getMessage());
    return;
}

if (($stmt = $pdo->prepare($sql)) === false) {
    $error = $pdo->errorInfo();
    report_error($error[2]);
    return;
}

if ($stmt->execute(array(1, "OPEN")) === false) {
    $error = $stmt->errorInfo();
    report_error($error[2]);
    return;
}

if (($bug = $stmt->fetch()) === false) {
    $error = $stmt->errorInfo();
    report_error($error[2]);
    return;
}
```

---

### 23. ディプロマティック・イミュニティ（Diplomatic Immunity）

**問題**: SQLコードを品質管理プロセスの対象外としている。
**検出シグナル**: 「データベース管理者にはバージョン管理のトレーニングは不要」「このテーブルの目的がわからない」。

| 項目 | 内容 |
|------|------|
| 目的 | ソフトウェアエンジニアリングのベストプラクティスを採用する |
| アンチパターン | データベースコードを文書化・バージョン管理・テストの対象外とする |
| 解決策 | SQLコードもアプリケーションコードと同様に、文書化・バージョン管理・テストの対象とする |
| 例外 | その場限りのテストコードや一時的なクエリ（使い終わったらすぐ削除するもの） |

**コード例:**
```sql
-- ✅ 解決策: バージョン管理下に置くべきファイル

-- 1. データ定義スクリプト
CREATE TABLE Bugs (
  bug_id SERIAL PRIMARY KEY,
  summary VARCHAR(200) NOT NULL,
  -- コメントで目的を記述
);

-- 2. トリガーとプロシージャ
CREATE TRIGGER update_timestamp
  BEFORE UPDATE ON Bugs
  FOR EACH ROW
  SET NEW.updated_at = CURRENT_TIMESTAMP;

-- 3. ブートストラップデータ
INSERT INTO BugStatus (status) VALUES ('NEW'), ('OPEN'), ('FIXED'), ('CLOSED');

-- 4. マイグレーションスクリプト（Ruby on Railsの例）
class AddHoursToBugs < ActiveRecord::Migration
  def self.up
    add_column :bugs, :hours, :decimal
  end

  def self.down
    remove_column :bugs, :hours
  end
end
```

**文書化すべき項目:**
- ER図（テーブルと関連の図）
- テーブル・列・ビューの説明
- 参照整合性制約と暗黙の関連
- トリガーとストアドプロシージャの目的
- SQLセキュリティ（ユーザー・権限・ロール）
- データベースインフラ（サーバー・冗長化・バックアップ）
- ORM設定とビジネスルール

---

### 24. マジックビーンズ（Magic Beans）

**問題**: ActiveRecordクラスをドメインモデルとして直接使用している。
**検出シグナル**: 「モデルクラスがデータベーステーブルと1対1対応している」「ビジネスロジックがActiveRecordクラスに散在」。

| 項目 | 内容 |
|------|------|
| 目的 | オブジェクト指向設計とリレーショナルデータベースを統合する |
| アンチパターン | ActiveRecordパターンのクラスをドメインモデルとして扱い、データベース構造とドメインモデルを密結合させる |
| 解決策 | ドメインモデルとデータアクセス層を分離し、リポジトリパターンやData Mapperパターンを使用する |
| 例外 | 小規模で単純なCRUDアプリケーション。データ構造がドメインモデルと一致している場合 |

**コード例:**
```ruby
# ❌ アンチパターン（ActiveRecordがドメインモデル）
class Bug < ActiveRecord::Base
  belongs_to :product
  validates :summary, presence: true

  def calculate_priority
    # ビジネスロジックがActiveRecordに混在
  end
end

# ✅ 解決策（ドメインモデルとデータアクセスの分離）
# ドメインモデル
class Bug
  attr_accessor :id, :summary, :priority

  def calculate_priority
    # ビジネスロジックはドメインモデルに
  end
end

# リポジトリ（データアクセス層）
class BugRepository
  def find(id)
    bug_data = BugActiveRecord.find(id)
    map_to_domain(bug_data)
  end

  def save(bug)
    bug_data = map_to_persistence(bug)
    bug_data.save
  end

  private

  def map_to_domain(bug_data)
    Bug.new.tap do |bug|
      bug.id = bug_data.id
      bug.summary = bug_data.summary
    end
  end
end
```

---

### 25. 砂の城（Sand Castle）

**問題**: 運用環境での実際の負荷やデータ量を想定せずに設計している。
**検出シグナル**: 「本番環境でのみ発生するパフォーマンス問題」「データ損失後のリカバリー計画がない」。

| 項目 | 内容 |
|------|------|
| 目的 | 開発環境で動作するアプリケーションを構築する |
| アンチパターン | 運用環境での負荷・データ量・障害を想定せず、ベンチマークやバックアップ計画を立てない |
| 解決策 | 本番相当のデータでベンチマークを実施し、バックアップ・高可用性・障害復旧計画を策定する |
| 例外 | 個人プロジェクトや学習目的のアプリケーション。ただし運用環境に移行する前に必ず見直す |

**コード例:**
```sql
-- ❌ アンチパターン（運用を考慮しない設計）
-- インデックスなし、パーティショニングなし、バックアップ計画なし
CREATE TABLE Logs (
  log_id SERIAL PRIMARY KEY,
  message TEXT,
  created_at TIMESTAMP
);

-- ✅ 解決策（運用を考慮した設計）
-- 適切なインデックス
CREATE TABLE Logs (
  log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  message TEXT,
  created_at TIMESTAMP NOT NULL,
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB
  PARTITION BY RANGE (YEAR(created_at)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026)
  );

-- バックアップスクリプト例
-- mysqldump --single-transaction --routines --triggers mydb > backup.sql

-- レプリケーション設定
-- CHANGE MASTER TO MASTER_HOST='primary.example.com', ...;
```

**運用計画に含めるべき項目:**
- **ベンチマーク**: 本番相当のデータ量とクエリパターンでの性能測定
- **インデックス戦略**: 頻繁に実行されるクエリに対する適切なインデックス
- **パーティショニング**: 大規模テーブルの分割戦略
- **バックアップ計画**: フルバックアップ・増分バックアップの頻度とリストア手順
- **高可用性（HA）**: レプリケーション・クラスタリング・フェイルオーバー
- **障害復旧（DR）**: RPO（目標復旧時点）とRTO（目標復旧時間）の定義
- **監視とアラート**: クエリ性能・ディスク使用率・接続数の監視
- **容量計画**: データ増加率の予測と拡張計画

---

## まとめ

アプリケーション開発におけるデータベース利用では、以下の原則を守ること:

1. **セキュリティ第一**: パスワードはソルト付きハッシュで保存し、SQLインジェクションを防ぐ
2. **データ整合性の維持**: 疑似キーの値は変更せず、エラーを適切にハンドリングする
3. **品質管理の徹底**: SQLコードも文書化・バージョン管理・テストの対象とする
4. **適切な抽象化**: ドメインモデルとデータアクセスを分離する
5. **運用を見据えた設計**: ベンチマーク・バックアップ・高可用性を計画する

これらのアンチパターンを避けることで、安全で保守性の高いデータベースアプリケーションを構築できる。
