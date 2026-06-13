# Go実践パターン

## 定数とiota

### 型なし定数と型付き定数

Goの定数は型なしと型付きの2種類がある。型なし定数はコンパイル時に計算され、代入先の型に応じて型が決定する。

```go
// 型なし定数
const a = 1 + 2  // コンパイル時に計算される
var x int32 = a  // int32になる
var y int64 = a  // int64になる

// 型付き定数
const b int32 = 10
// var z int64 = b  // エラー: 型が固定されている
```

### iotaによる列挙型

iotaを使うことで連番の定数を簡潔に定義できる。

```go
type Status int

const (
    StatusPending Status = iota + 1 // 1から始める（推奨）
    StatusProcessing
    StatusCompleted
    StatusFailed
)
```

#### 1オリジン推奨の理由

0始まりだとゼロ値と区別がつかない。1始まりにすることで「値が設定されていない」状態を検出可能にする。

```go
// Bad: 0始まり
const (
    StatusPending Status = iota // 0
    StatusCompleted             // 1
)

var s Status  // ゼロ値0 = StatusPending と区別できない

// Good: 1始まり
const (
    StatusPending Status = iota + 1 // 1
    StatusCompleted                 // 2
)

var s Status  // ゼロ値0で「未設定」を検出可能
```

#### ビットフラグパターン

```go
type Permission int

const (
    PermissionRead Permission = 1 << iota // 0b0001
    PermissionWrite                       // 0b0010
    PermissionExecute                     // 0b0100
)

func hasPermission(p Permission, perm Permission) bool {
    return p&perm != 0
}

// 使用例
userPerm := PermissionRead | PermissionWrite
if hasPermission(userPerm, PermissionWrite) {
    // 書き込み可能
}
```

### iotaを使うべきでない場面

プロセス外で利用される値（DBのステータスコード、APIのエラーコード等）はiotaを使わず明示的に値を指定すべき。

```go
// Bad: 順序変更や追加で値が変わる
const (
    ErrorCodeAuth = iota + 1000
    ErrorCodeNotFound
    ErrorCodeInvalid
)

// Good: 明示的に値を指定
const (
    ErrorCodeAuth     = 1000
    ErrorCodeNotFound = 1001
    ErrorCodeInvalid  = 1002
)
```

### Stringer/Enumerによる文字列変換

`stringer`ツールや`enumer`ライブラリで自動生成。

```bash
# stringer使用
go install golang.org/x/tools/cmd/stringer@latest
stringer -type=Status

# enumerはより高機能（JSON対応等）
go install github.com/dmarkham/enumer@latest
enumer -type=Status -json
```

### error型の定数実現

プリミティブ型の定義型にError()メソッドを実装してconstで定数化。

```go
type ErrorCode int

func (e ErrorCode) Error() string {
    switch e {
    case ErrDatabase:
        return "database error"
    case ErrNotFound:
        return "not found"
    default:
        return "unknown error"
    }
}

const (
    ErrDatabase ErrorCode = 1
    ErrNotFound ErrorCode = 2
)

// 使用
if err == ErrDatabase {
    // DB接続エラー処理
}
```

---

## 関数オプション引数

コンストラクタやファクトリー関数に多数のオプション引数を渡す際の4つのパターン。

### 1. 別名関数パターン

```go
type Server struct {
    addr    string
    timeout time.Duration
}

func NewServer(addr string) *Server {
    return &Server{addr: addr, timeout: 30 * time.Second}
}

func NewServerWithTimeout(addr string, timeout time.Duration) *Server {
    return &Server{addr: addr, timeout: timeout}
}
```

**問題**: オプション増加ごとに関数が増える。

### 2. 構造体パターン

```go
type ServerConfig struct {
    Addr    string
    Timeout time.Duration
}

func NewServer(cfg ServerConfig) *Server {
    if cfg.Timeout == 0 {
        cfg.Timeout = 30 * time.Second
    }
    return &Server{addr: cfg.Addr, timeout: cfg.Timeout}
}

// 使用
srv := NewServer(ServerConfig{
    Addr:    ":8080",
    Timeout: 10 * time.Second,
})
```

**問題**: 必須引数と任意引数の区別が不明確。

### 3. Builderパターン（Fluent Interface）

```go
type ServerBuilder struct {
    addr    string
    timeout time.Duration
}

func NewServerBuilder(addr string) *ServerBuilder {
    return &ServerBuilder{addr: addr, timeout: 30 * time.Second}
}

func (b *ServerBuilder) Timeout(d time.Duration) *ServerBuilder {
    b.timeout = d
    return b
}

func (b *ServerBuilder) Build() *Server {
    return &Server{addr: b.addr, timeout: b.timeout}
}

// 使用
srv := NewServerBuilder(":8080").
    Timeout(10 * time.Second).
    Build()
```

### 4. Functional Optionパターン（推奨）

```go
type ServerOption func(*Server)

func WithTimeout(d time.Duration) ServerOption {
    return func(s *Server) {
        s.timeout = d
    }
}

func WithMaxConn(n int) ServerOption {
    return func(s *Server) {
        s.maxConn = n
    }
}

func NewServer(addr string, opts ...ServerOption) *Server {
    srv := &Server{
        addr:    addr,
        timeout: 30 * time.Second, // デフォルト
        maxConn: 100,              // デフォルト
    }
    for _, opt := range opts {
        opt(srv)
    }
    return srv
}

// 使用
srv := NewServer(":8080",
    WithTimeout(10*time.Second),
    WithMaxConn(200),
)
```

### パターン選択基準

| パターン | 適用場面 |
|---------|---------|
| 別名関数 | オプション1-2個、今後増えない |
| 構造体 | オプション多数、すべて任意 |
| Builder | 複雑な構築プロセス、段階的設定 |
| Functional Option | **オプション多数、今後も追加予定（推奨）** |

---

## 型定義によるドメインモデリング

プリミティブ型をラップして型安全性を確保する。

### プリミティブ型ラッパー

```go
// Bad: プリミティブ型のまま
func Transfer(from string, to string, amount int) error {
    // from/toの入れ間違いに気づけない
    return nil
}

// Good: 型でラップ
type AccountID string
type Amount int

func Transfer(from AccountID, to AccountID, amount Amount) error {
    // 型が異なるため入れ間違いがコンパイルエラーになる
    return nil
}
```

### スライス・値・列挙への型定義

```go
type UserID string
type UserIDs []UserID

type Temperature float64

type HTTPStatus int

const (
    StatusOK       HTTPStatus = 200
    StatusNotFound HTTPStatus = 404
)
```

### ファクトリー関数の提供

```go
type Email string

// バリデーション付きファクトリー関数
func NewEmail(s string) (Email, error) {
    if !strings.Contains(s, "@") {
        return "", errors.New("invalid email format")
    }
    return Email(s), nil
}
```

### 機密情報マスキング（Stringer/GoStringer）

```go
type Password string

// String() を実装すると %v や %s でマスキング
func (p Password) String() string {
    return "***"
}

// GoString() を実装すると %#v でもマスキング
func (p Password) GoString() string {
    return `Password("***")`
}

// 使用例
pw := Password("secret123")
fmt.Printf("%v\n", pw)   // 出力: ***
fmt.Printf("%#v\n", pw)  // 出力: Password("***")
```

---

## メモリ最適化

### スライスの容量事前確保

```go
// Bad: 再アロケーション発生
var items []Item
for i := 0; i < 1000; i++ {
    items = append(items, Item{ID: i})
}

// Good: 容量を事前確保
items := make([]Item, 0, 1000)
for i := 0; i < 1000; i++ {
    items = append(items, Item{ID: i})
}
```

### mapの容量事前確保

```go
// Bad
m := make(map[string]int)

// Good: 想定サイズを指定
m := make(map[string]int, 100)
```

### deferの落とし穴

#### forループ内でのdefer

```go
// Bad: ファイルが閉じられるのは関数終了時
func processFiles(files []string) error {
    for _, file := range files {
        f, err := os.Open(file)
        if err != nil {
            return err
        }
        defer f.Close() // ループ終了時ではなく関数終了時
        // 処理
    }
    return nil
}

// Good: 即座にクローズ
func processFiles(files []string) error {
    for _, file := range files {
        if err := processFile(file); err != nil {
            return err
        }
    }
    return nil
}

func processFile(file string) error {
    f, err := os.Open(file)
    if err != nil {
        return err
    }
    defer f.Close() // この関数終了時にクローズ
    // 処理
    return nil
}
```

#### Close()のエラー無視

```go
// Bad: Close()のエラーを無視
defer f.Close()

// Good: 名前付き戻り値でエラーを返す
func WriteFile(path string, data []byte) (err error) {
    f, err := os.Create(path)
    if err != nil {
        return err
    }
    defer func() {
        if cerr := f.Close(); cerr != nil && err == nil {
            err = cerr
        }
    }()

    _, err = f.Write(data)
    return err
}
```

---

## 文字列結合

大量の文字列を結合する場合は`strings.Builder`を使う。

```go
// Bad: + 演算子は毎回新しい文字列を生成
var s string
for i := 0; i < 1000; i++ {
    s += strconv.Itoa(i)
}

// Good: strings.Builder は内部バッファを再利用
var b strings.Builder
b.Grow(10000) // 容量事前確保（任意だが推奨）
for i := 0; i < 1000; i++ {
    b.WriteString(strconv.Itoa(i))
}
s := b.String()
```

---

## 日時処理

### time.Timeとtime.Duration

```go
// 現在時刻
now := time.Now()

// 特定の日時
t := time.Date(2025, time.January, 1, 0, 0, 0, 0, time.UTC)

// 期間
d := 30 * time.Minute
future := now.Add(d)

// 差分
elapsed := time.Since(t)
```

### タイムゾーン処理

```go
// ロケーション読み込み
jst, err := time.LoadLocation("Asia/Tokyo")
if err != nil {
    log.Fatal(err)
}

t := time.Now().In(jst)

// タイムゾーンデータ埋め込み（time/tzdata）
import _ "time/tzdata"
```

### 翌月計算の落とし穴（AddDate正規化）

```go
// AddDateは正規化される
t := time.Date(2025, 1, 31, 0, 0, 0, 0, time.UTC)
next := t.AddDate(0, 1, 0) // 2025-03-03（2月31日→3月3日）

// 月末を維持したい場合は明示的に計算
func addMonthKeepEOM(t time.Time, months int) time.Time {
    next := t.AddDate(0, months, 0)
    if next.Day() < t.Day() {
        // 正規化が発生した場合、前月の末日を取得
        next = time.Date(next.Year(), next.Month(), 0, next.Hour(), next.Minute(), next.Second(), next.Nanosecond(), next.Location())
    }
    return next
}
```

---

## Optionalパターン（validフィールド）

ポインタを使わずにゼロ値と「未設定」を区別する方法。`database/sql`の`sql.NullString`パターンの応用。

```go
// シンプルなOptional型
type OptionalInt struct {
    Value int
    Valid bool // trueなら値が設定されている
}

// ゼロ値はValid=false（未設定）
var opt OptionalInt
fmt.Println(opt.Valid) // false（未設定）
fmt.Println(opt.Value) // 0（ゼロ値だが「未設定」を意味する）

// 値を設定する
opt = OptionalInt{Value: 0, Valid: true} // 0が「設定済み」
fmt.Println(opt.Valid) // true

// ポインタとの比較
// ポインタ (*int): ヒープアロケーション発生、GCプレッシャーあり
// Optionalパターン: スタック上に配置可能、GCフレンドリー

// database/sql の sql.NullString との関連
import "database/sql"

type User struct {
    ID       int
    Name     string
    Nickname sql.NullString // NULL許容のDB列
}

// Nullable列の扱い
if user.Nickname.Valid {
    fmt.Println("ニックネーム:", user.Nickname.String)
} else {
    fmt.Println("ニックネームは未設定")
}

// 汎用Optional（Go 1.18+でgenericsを活用）
type Optional[T any] struct {
    Value T
    Valid bool
}

func Some[T any](v T) Optional[T] {
    return Optional[T]{Value: v, Valid: true}
}

func None[T any]() Optional[T] {
    return Optional[T]{}
}

// 使用例
type Config struct {
    Port    Optional[int]
    Timeout Optional[time.Duration]
}

cfg := Config{
    Port:    Some(8080),
    Timeout: None[time.Duration](), // 未設定
}

if cfg.Port.Valid {
    fmt.Printf("Port: %d\n", cfg.Port.Value)
}
```

---

## raw文字列リテラル

バッククォート（`` ` ``）で囲むことで、バックスラッシュエスケープなしに文字列を記述できる。

```go
// 通常の文字列リテラル: エスケープが必要
regex1 := "^\\d{3}-\\d{4}-\\d{4}$"   // 読みにくい
json1  := "{\"name\":\"gopher\"}"      // 読みにくい

// raw文字列リテラル: エスケープ不要
regex2 := `^\d{3}-\d{4}-\d{4}$`       // 読みやすい
json2  := `{"name":"gopher"}`          // 読みやすい

// 正規表現パターン（最も一般的な活用）
import "regexp"

var phoneRegex = regexp.MustCompile(`^\d{3}-\d{4}-\d{4}$`)
var emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)

// 複数行文字列（インデント注意: 行内の空白もそのまま含まれる）
query := `
    SELECT id, name, email
    FROM users
    WHERE active = true
    ORDER BY created_at DESC
`

// SQLテンプレートとの組み合わせ
template := `
INSERT INTO %s (name, email)
VALUES (?, ?)
`

// HTMLテンプレート
html := `<!DOCTYPE html>
<html>
  <body>
    <h1>Hello, World!</h1>
  </body>
</html>`

// 注意: raw文字列にバッククォート自体は含められない
// バッククォートが必要な場合は + で結合する
str := `He said ` + "`" + `hello` + "`"
```

---

## まとめ

実践パターンでは以下を重視：

- **定数・iota**: 1オリジン推奨、プロセス外利用時は明示値
- **関数オプション引数**: Functional Optionパターン推奨
- **型定義**: ドメインモデリングで型安全性確保
- **メモリ最適化**: 容量事前確保、deferの注意点
- **文字列結合**: strings.Builder
- **日時処理**: タイムゾーン対応、AddDate正規化の理解
