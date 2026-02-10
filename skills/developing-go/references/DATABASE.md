# リレーショナルデータベース

## database/sql基礎

### ドライバーのブランクインポート

```go
import (
    "database/sql"
    _ "github.com/jackc/pgx/v4/stdlib" // PostgreSQL
    // _ "github.com/go-sql-driver/mysql" // MySQL
)

func main() {
    db, err := sql.Open("pgx", "host=localhost port=5432 user=testuser dbname=testdb password=pass sslmode=disable")
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    // 接続確認
    if err := db.Ping(); err != nil {
        log.Fatal(err)
    }
}
```

### sql.DB = コネクションプール（ゴルーチンセーフ）

`sql.DB`は**コネクションプール**であり、単一のコネクションではない。ゴルーチンセーフなので複数のゴルーチンから同時に使用可能。アプリケーション全体で1つの`sql.DB`インスタンスを共有する。

```go
// Good: グローバル変数またはDI
var db *sql.DB

func init() {
    var err error
    db, err = sql.Open("pgx", "...")
    if err != nil {
        log.Fatal(err)
    }
}

// Bad: 毎回sql.Openしない
func getUser(id string) (*User, error) {
    db, _ := sql.Open("pgx", "...") // NG: コネクションプール作り直し
    defer db.Close()
    // ...
}
```

### QueryContext/QueryRowContext/ExecContext

| メソッド | 用途 |
|---------|------|
| `QueryContext` | 複数行SELECT |
| `QueryRowContext` | 単一行SELECT |
| `ExecContext` | INSERT/UPDATE/DELETE/CREATE |

#### QueryContext（複数行取得）

```go
rows, err := db.QueryContext(ctx, "SELECT user_id, user_name FROM users WHERE age > $1", 20)
if err != nil {
    log.Fatal(err)
}
defer rows.Close()

var users []*User
for rows.Next() {
    var u User
    if err := rows.Scan(&u.ID, &u.Name); err != nil {
        log.Fatal(err)
    }
    users = append(users, &u)
}

// 必須: rows.Err()でエラーチェック
if err := rows.Err(); err != nil {
    log.Fatal(err)
}
```

#### QueryRowContext（単一行取得）

```go
var u User
err := db.QueryRowContext(ctx, "SELECT user_id, user_name FROM users WHERE user_id = $1", "001").
    Scan(&u.ID, &u.Name)
if err == sql.ErrNoRows {
    // レコードが見つからない
} else if err != nil {
    log.Fatal(err)
}
```

#### ExecContext（INSERT/UPDATE/DELETE）

```go
result, err := db.ExecContext(ctx, "INSERT INTO users (user_id, user_name) VALUES ($1, $2)", "001", "Gopher")
if err != nil {
    log.Fatal(err)
}

rowsAffected, _ := result.RowsAffected()
fmt.Printf("%d rows affected\n", rowsAffected)
```

### Null値（NullString/NullInt64/NullTime）

Goのゼロ値とDBのNULLを区別する。

```go
type User struct {
    ID        string
    Name      string
    MiddleName sql.NullString // Nullable
    Age        sql.NullInt64  // Nullable
}

// 読み込み
var u User
err := db.QueryRowContext(ctx, "SELECT user_id, user_name, middle_name, age FROM users WHERE user_id = $1", "001").
    Scan(&u.ID, &u.Name, &u.MiddleName, &u.Age)

if u.MiddleName.Valid {
    fmt.Println("Middle name:", u.MiddleName.String)
} else {
    fmt.Println("Middle name is NULL")
}

// 書き込み
db.ExecContext(ctx, "INSERT INTO users (user_id, user_name, middle_name) VALUES ($1, $2, $3)",
    "001", "Gopher", sql.NullString{String: "T", Valid: true})
```

### rows.Err()チェック（必須）

`rows.Next()`ループ終了後、必ず`rows.Err()`をチェックする。

```go
for rows.Next() {
    // ...
}

// 必須: ループ中のエラーを検出
if err := rows.Err(); err != nil {
    log.Fatal(err)
}
```

---

## トランザクション

### 3つのパターン

#### 1. シンプル実装（非推奨）

```go
tx, err := db.BeginTx(ctx, nil)
if err != nil {
    log.Fatal(err)
}

_, err = tx.ExecContext(ctx, "INSERT INTO users ...")
if err != nil {
    tx.Rollback() // エラー時はRollback
    log.Fatal(err)
}

if err := tx.Commit(); err != nil {
    log.Fatal(err)
}
```

**問題**: panic時にRollbackされない。

#### 2. defer Rollback（基本パターン）

```go
tx, err := db.BeginTx(ctx, nil)
if err != nil {
    log.Fatal(err)
}
defer tx.Rollback() // panic保護（Commit済みならエラーだが無害）

_, err = tx.ExecContext(ctx, "INSERT INTO users ...")
if err != nil {
    return err // Rollbackは自動実行
}

if err := tx.Commit(); err != nil {
    return err
}
```

#### 3. ラッパー実装（推奨）

```go
func WithTransaction(ctx context.Context, db *sql.DB, fn func(*sql.Tx) error) error {
    tx, err := db.BeginTx(ctx, nil)
    if err != nil {
        return err
    }
    defer func() {
        if p := recover(); p != nil {
            tx.Rollback()
            panic(p) // 再panic
        } else if err != nil {
            tx.Rollback()
        } else {
            err = tx.Commit()
        }
    }()
    err = fn(tx)
    return err
}

// 使用例
err := WithTransaction(ctx, db, func(tx *sql.Tx) error {
    _, err := tx.ExecContext(ctx, "INSERT INTO users ...")
    if err != nil {
        return err
    }
    _, err = tx.ExecContext(ctx, "UPDATE accounts ...")
    return err
})
```

---

## コネクションプール

### 4つのパラメータ

```go
db.SetMaxOpenConns(25)              // 最大オープンコネクション数
db.SetMaxIdleConns(10)              // 最大アイドルコネクション数
db.SetConnMaxLifetime(5 * time.Minute)  // コネクション最大寿命
db.SetConnMaxIdleTime(10 * time.Minute) // アイドル時最大寿命
```

| パラメータ | デフォルト | 説明 |
|----------|----------|------|
| `MaxOpenConns` | 無制限 | 同時に開けるコネクション数上限 |
| `MaxIdleConns` | 2 | プールに保持するアイドルコネクション数 |
| `ConnMaxLifetime` | 無制限 | コネクションの最大寿命（再利用上限） |
| `ConnMaxIdleTime` | 無制限 | アイドル状態での最大寿命 |

### DB側max_connectionsとの調整

**重要**: アプリケーションインスタンス数 × MaxOpenConns < DB側max_connections

```
例: PostgreSQL max_connections=100
    アプリインスタンス4台 → 各インスタンスMaxOpenConns=20以下
```

### 推奨設定

```go
// Webアプリケーション
db.SetMaxOpenConns(25)
db.SetMaxIdleConns(10)
db.SetConnMaxLifetime(5 * time.Minute)
db.SetConnMaxIdleTime(1 * time.Minute)
```

---

## クエリーキャンセル

`context.WithTimeout`でクエリーにタイムアウトを設定。

```go
ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
defer cancel()

rows, err := db.QueryContext(ctx, "SELECT * FROM users WHERE ...") // 3秒でキャンセル
if err != nil {
    if ctx.Err() == context.DeadlineExceeded {
        log.Println("Query timeout")
    }
    log.Fatal(err)
}
defer rows.Close()
```

---

## クエリーログ

### sqlhooksによるフック処理

```go
import "github.com/qustavo/sqlhooks/v2"

type LogHook struct{}

func (h *LogHook) Before(ctx context.Context, query string, args ...interface{}) (context.Context, error) {
    log.Printf("Query: %s Args: %v", query, args)
    return ctx, nil
}

func (h *LogHook) After(ctx context.Context, query string, args ...interface{}) (context.Context, error) {
    return ctx, nil
}

// ドライバーをラップ
sql.Register("pgx-with-hooks", sqlhooks.Wrap(&pq.Driver{}, &LogHook{}))
db, _ := sql.Open("pgx-with-hooks", "...")
```

---

## バッチインサート

### 1. プリペアードステートメント

```go
tx, _ := db.BeginTx(ctx, nil)
defer tx.Rollback()

stmt, err := tx.PrepareContext(ctx, "INSERT INTO users (user_id, user_name) VALUES ($1, $2)")
if err != nil {
    return err
}
defer stmt.Close()

for _, u := range users {
    _, err := stmt.ExecContext(ctx, u.ID, u.Name)
    if err != nil {
        return err
    }
}

tx.Commit()
```

### 2. 動的SQL組み立て

```go
// PostgreSQL VALUES句
values := []interface{}{}
placeholders := []string{}
for i, u := range users {
    placeholders = append(placeholders, fmt.Sprintf("($%d, $%d)", i*2+1, i*2+2))
    values = append(values, u.ID, u.Name)
}

query := "INSERT INTO users (user_id, user_name) VALUES " + strings.Join(placeholders, ", ")
_, err := db.ExecContext(ctx, query, values...)
```

### 3. COPYコマンド（PostgreSQL）

```go
import "github.com/jackc/pgx/v4"

conn, _ := pgx.Connect(ctx, "...")
defer conn.Close(ctx)

_, err := conn.CopyFrom(
    ctx,
    pgx.Identifier{"users"},
    []string{"user_id", "user_name"},
    pgx.CopyFromSlice(len(users), func(i int) ([]interface{}, error) {
        return []interface{}{users[i].ID, users[i].Name}, nil
    }),
)
```

---

## テスト戦略

### 本物のDB推奨

**推奨**: Docker等で実DBを起動してテストする。

```go
func setupTestDB(t *testing.T) *sql.DB {
    db, err := sql.Open("pgx", "host=localhost port=5432 user=test dbname=testdb password=test sslmode=disable")
    if err != nil {
        t.Fatal(err)
    }
    // テーブル初期化
    db.ExecContext(context.Background(), "TRUNCATE TABLE users")
    return db
}

func TestCreateUser(t *testing.T) {
    db := setupTestDB(t)
    defer db.Close()

    // テスト実装
}
```

### go-sqlmockによるモック

```go
import "github.com/DATA-DOG/go-sqlmock"

func TestCreateUserMock(t *testing.T) {
    db, mock, err := sqlmock.New()
    if err != nil {
        t.Fatal(err)
    }
    defer db.Close()

    mock.ExpectExec("INSERT INTO users").
        WithArgs("001", "Gopher").
        WillReturnResult(sqlmock.NewResult(1, 1))

    _, err = db.ExecContext(context.Background(), "INSERT INTO users (user_id, user_name) VALUES ($1, $2)", "001", "Gopher")
    if err != nil {
        t.Fatal(err)
    }

    if err := mock.ExpectationsWereMet(); err != nil {
        t.Errorf("unfulfilled expectations: %s", err)
    }
}
```

---

## ライブラリ比較

### sqlc（推奨: クエリードリブン）

```yaml
# sqlc.yaml
version: "2"
sql:
  - schema: "schema.sql"
    queries: "queries.sql"
    engine: "postgresql"
    gen:
      go:
        package: "db"
        out: "db"
```

```sql
-- queries.sql
-- name: GetUser :one
SELECT * FROM users WHERE user_id = $1;

-- name: ListUsers :many
SELECT * FROM users ORDER BY user_id;
```

**特徴**:
- SQLファイルから型安全なGoコードを自動生成
- コンパイル時に型チェック
- 学習コスト低

### sqlboiler（スキーマドリブン）

```bash
sqlboiler psql
```

**特徴**:
- DBスキーマから構造体を自動生成
- リレーション自動解決
- ActiveRecord風API

### GORM（ORM）

```go
type User struct {
    ID   string `gorm:"primaryKey"`
    Name string
}

db.Create(&User{ID: "001", Name: "Gopher"})
db.First(&user, "id = ?", "001")
```

**特徴**:
- フルORMでマイグレーション対応
- 学習コスト高
- 複雑なクエリーは生SQLが必要なことも

### 選択基準

| ライブラリ | 推奨度 | 適用場面 |
|----------|-------|---------|
| **sqlc** | ⭐⭐⭐ | SQLを書きたい、型安全性重視 |
| sqlboiler | ⭐⭐ | スキーマ駆動、リレーション多用 |
| GORM | ⭐ | プロトタイピング、マイグレーション重視 |

---

## まとめ

DB操作のベストプラクティス：

- **基礎**: ブランクインポート、sql.DB共有、Contextメソッド使用
- **トランザクション**: ラッパー実装推奨、defer Rollback必須
- **コネクションプール**: DB側max_connectionsと調整
- **バッチ**: 大量データはCOPY/動的SQL
- **テスト**: 実DB推奨、モックは限定的に使用
- **ライブラリ**: sqlc推奨（クエリードリブン、型安全）
