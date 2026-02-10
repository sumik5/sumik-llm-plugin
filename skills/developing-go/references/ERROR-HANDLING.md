# Goエラーハンドリング

## 基本原則

### エラーは値
Goではエラーは例外ではなく値として扱う：

```go
// 常にエラーをチェック
result, err := doSomething()
if err != nil {
    return err
}

// エラーを無視しない（明示的に無視する場合のみ _ を使用）
_ = file.Close()  // 意図的な無視は明示
```

### エラーの伝播
エラーにコンテキストを追加して伝播：

```go
// Good: コンテキストを追加
func ProcessUser(id string) error {
    user, err := fetchUser(id)
    if err != nil {
        return fmt.Errorf("fetch user %s: %w", id, err)
    }

    if err := user.Validate(); err != nil {
        return fmt.Errorf("validate user %s: %w", id, err)
    }

    return nil
}

// Bad: コンテキストなし
func ProcessUser(id string) error {
    user, err := fetchUser(id)
    if err != nil {
        return err  // どこで失敗したか不明
    }
    return nil
}
```

## エラーラッピング

### %w vs %v
```go
// %w: エラーをラップ（errors.Is/Asで検査可能）
return fmt.Errorf("open config: %w", err)

// %v: エラーを文字列化（元のエラー情報は失われる）
return fmt.Errorf("open config: %v", err)
```

### 使い分け
```go
// %w を使う場合: 呼び出し側がエラー種別を判断する必要がある
func ReadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("read config file: %w", err)
        // 呼び出し側で errors.Is(err, os.ErrNotExist) が使える
    }
    return parseConfig(data)
}

// %v を使う場合: 実装詳細を隠蔽したい
func (s *Service) Process(ctx context.Context) error {
    if err := s.internalStep(); err != nil {
        return fmt.Errorf("process failed: %v", err)
        // 内部実装の詳細を外部に漏らさない
    }
    return nil
}
```

## センチネルエラー

### 定義
```go
package mypackage

import "errors"

// パッケージレベルで定義
var (
    ErrNotFound     = errors.New("not found")
    ErrUnauthorized = errors.New("unauthorized")
    ErrInvalidInput = errors.New("invalid input")
)
```

### 使用
```go
// エラーの判定
if errors.Is(err, ErrNotFound) {
    // 404を返す
}

// switch文での判定
switch {
case errors.Is(err, ErrNotFound):
    return http.StatusNotFound
case errors.Is(err, ErrUnauthorized):
    return http.StatusUnauthorized
default:
    return http.StatusInternalServerError
}
```

## カスタムエラー型

### 構造体エラー
```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation error on %s: %s", e.Field, e.Message)
}

// 使用
func Validate(input Input) error {
    if input.Name == "" {
        return &ValidationError{
            Field:   "name",
            Message: "cannot be empty",
        }
    }
    return nil
}

// errors.Asで型アサーション
var validErr *ValidationError
if errors.As(err, &validErr) {
    fmt.Printf("Field: %s, Message: %s\n", validErr.Field, validErr.Message)
}
```

### エラーのネスト
```go
type QueryError struct {
    Query string
    Err   error
}

func (e *QueryError) Error() string {
    return fmt.Sprintf("query %s: %v", e.Query, e.Err)
}

// Unwrapを実装してエラーチェーン対応
func (e *QueryError) Unwrap() error {
    return e.Err
}
```

## panic と recover

### panicの使用
panicは**本当に回復不能な状況**でのみ使用：

```go
// Good: プログラムの前提条件違反
func MustCompileRegex(pattern string) *regexp.Regexp {
    re, err := regexp.Compile(pattern)
    if err != nil {
        panic(fmt.Sprintf("invalid regex pattern: %s", pattern))
    }
    return re
}

// 初期化時のみ使用
var emailRegex = MustCompileRegex(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)

// Bad: 通常のエラー処理にpanicを使用
func GetUser(id string) *User {
    user, err := db.FindUser(id)
    if err != nil {
        panic(err)  // これはダメ
    }
    return user
}
```

### recoverの使用
```go
// HTTPハンドラでのリカバリ
func RecoveryMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if err := recover(); err != nil {
                log.Printf("panic recovered: %v\n%s", err, debug.Stack())
                http.Error(w, "Internal Server Error", http.StatusInternalServerError)
            }
        }()
        next.ServeHTTP(w, r)
    })
}
```

## エラーハンドリングパターン

### 早期リターン
```go
// Good: ガード節
func ProcessOrder(order *Order) error {
    if order == nil {
        return errors.New("order is nil")
    }
    if order.Items == nil || len(order.Items) == 0 {
        return errors.New("order has no items")
    }
    if order.CustomerID == "" {
        return errors.New("order has no customer")
    }

    // メインロジック
    return processValidOrder(order)
}
```

### エラーのグループ化
```go
// 複数のエラーをまとめる
func ValidateUser(u *User) error {
    var errs []error

    if u.Name == "" {
        errs = append(errs, errors.New("name is required"))
    }
    if u.Email == "" {
        errs = append(errs, errors.New("email is required"))
    }
    if u.Age < 0 {
        errs = append(errs, errors.New("age must be non-negative"))
    }

    if len(errs) > 0 {
        return errors.Join(errs...)  // Go 1.20+
    }
    return nil
}
```

### deferでのエラーハンドリング
```go
func WriteToFile(path string, data []byte) (err error) {
    f, err := os.Create(path)
    if err != nil {
        return fmt.Errorf("create file: %w", err)
    }

    // 名前付き戻り値でdeferからエラーを設定
    defer func() {
        if cerr := f.Close(); cerr != nil && err == nil {
            err = fmt.Errorf("close file: %w", cerr)
        }
    }()

    if _, err := f.Write(data); err != nil {
        return fmt.Errorf("write data: %w", err)
    }

    return nil
}
```

## アンチパターン

| パターン | 問題 | 修正 |
|---------|------|------|
| `if err != nil { return err }` | コンテキストなし | `fmt.Errorf("context: %w", err)` |
| `panic(err)` | 通常エラーでpanic | `return err` |
| `err.Error() == "not found"` | 文字列比較 | `errors.Is(err, ErrNotFound)` |
| エラーの無視 | バグの温床 | 必ずチェックまたは明示的に`_`で無視 |
| ログ後に再度return err | 二重ログ | どちらか一方のみ |

## Unwrap()メソッドによるエラーチェーン対応

### カスタムエラー型にUnwrap()を実装

`errors.Is()` や `errors.As()` で検査可能にするには、`Unwrap()` メソッドを実装します。

```go
// カスタムエラー型
type LoadConfigError struct {
    Path string
    Err  error
}

func (e *LoadConfigError) Error() string {
    return fmt.Sprintf("failed to load config from %s: %v", e.Path, e.Err)
}

// Unwrap()を実装してエラーチェーンに対応
func (e *LoadConfigError) Unwrap() error {
    return e.Err
}

// 使用例
func LoadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, &LoadConfigError{
            Path: path,
            Err:  err,
        }
    }
    // ...
    return cfg, nil
}

// errors.Is()で元のエラーを検査可能
if err := LoadConfig("config.json"); err != nil {
    if errors.Is(err, os.ErrNotExist) {
        // ファイルが存在しない場合の処理
        fmt.Println("Config file not found")
    }
}

// errors.As()でカスタムエラー型を取得
var loadErr *LoadConfigError
if errors.As(err, &loadErr) {
    fmt.Printf("Failed to load config: %s\n", loadErr.Path)
}
```

### 複数のエラーをラップする場合（Go 1.20+）

```go
type MultiError struct {
    Errors []error
}

func (e *MultiError) Error() string {
    var msgs []string
    for _, err := range e.Errors {
        msgs = append(msgs, err.Error())
    }
    return strings.Join(msgs, "; ")
}

// Unwrap() は最初のエラーを返す
func (e *MultiError) Unwrap() error {
    if len(e.Errors) == 0 {
        return nil
    }
    return e.Errors[0]
}

// または errors.Join() を使用（Go 1.20+）
func ValidateUser(u *User) error {
    var errs []error
    if u.Name == "" {
        errs = append(errs, errors.New("name is required"))
    }
    if u.Email == "" {
        errs = append(errs, errors.New("email is required"))
    }
    if len(errs) > 0 {
        return errors.Join(errs...)  // すべてのエラーをラップ
    }
    return nil
}
```

## エラー文字列比較のアンチパターンと対策

### 文字列比較は避ける

エラーの文字列を直接比較すると、エラーメッセージの変更で壊れやすいコードになります。

```go
// ❌ Bad: 文字列比較（壊れやすい）
func FetchUser(id string) (*User, error) {
    user, err := db.Query("SELECT * FROM users WHERE id = ?", id)
    if err != nil {
        // エラーメッセージの文字列で判定（危険）
        if strings.Contains(err.Error(), "not found") {
            return nil, fmt.Errorf("user not found: %s", id)
        }
        return nil, err
    }
    return user, nil
}

// ✅ Good: センチネルエラーで比較
var ErrNotFound = errors.New("not found")

func FetchUser(id string) (*User, error) {
    user, err := db.Query("SELECT * FROM users WHERE id = ?", id)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrNotFound
        }
        return nil, err
    }
    return user, nil
}

// 使用側
user, err := FetchUser("123")
if errors.Is(err, ErrNotFound) {
    // 見つからなかった場合の処理
}
```

### Go 1.16以前の net.ErrClosed 問題

Go 1.15以前は、クローズされたソケットへの読み書きエラーが非公開だったため、やむを得ず文字列比較が必要でした。

```go
// ❌ Go 1.15以前: 文字列比較が必要だった
for {
    buf := make([]byte, 1024)
    _, err := conn.Read(buf)
    if err != nil {
        // 文字列比較でクローズ判定（非推奨だが当時は必須）
        if strings.Contains(err.Error(), "use of closed network connection") {
            break
        }
        return err
    }
    handleRead(buf)
}

// ✅ Go 1.16以降: net.ErrClosedを使用
import "net"

for {
    buf := make([]byte, 1024)
    _, err := conn.Read(buf)
    if err != nil {
        if errors.Is(err, net.ErrClosed) {
            break
        }
        return err
    }
    handleRead(buf)
}
```

### 非公開エラーへの対処

外部パッケージのエラーが非公開の場合、そのパッケージのバージョンアップを待つか、Issueを提起します。

```go
// 外部パッケージが公開エラー型を提供していない場合
// 1. 型アサーションで判定（型が公開されている場合）
var pathErr *fs.PathError
if errors.As(err, &pathErr) {
    fmt.Printf("Path error: %s\n", pathErr.Path)
}

// 2. エラーをラップして独自のエラー型を提供
var ErrExternalServiceFailed = errors.New("external service failed")

func CallExternalAPI() error {
    err := externalLib.Call()
    if err != nil {
        return fmt.Errorf("%w: %v", ErrExternalServiceFailed, err)
    }
    return nil
}

// 使用側
if errors.Is(err, ErrExternalServiceFailed) {
    // 外部サービスエラーとして処理
}
```

## スタックトレースの取得

### 標準ライブラリではサポートなし

Go 1.16時点で、`errors.New()` や `fmt.Errorf()` はスタックトレースを出力しません。

```go
// ❌ スタックトレースなし
err := errors.New("something went wrong")
fmt.Printf("%+v\n", err)
// Output: something went wrong
// スタックトレースは含まれない
```

### golang.org/x/xerrors を使用

`golang.org/x/xerrors` を使うとスタックトレースを取得できます。`pkg/errors` はアーカイブ済みのため非推奨です。

```go
import (
    "fmt"
    "golang.org/x/xerrors"
)

func ProcessFile(path string) error {
    if err := validate(path); err != nil {
        return xerrors.Errorf("validate file: %w", err)
    }
    return nil
}

func validate(path string) error {
    return xerrors.New("invalid file format")
}

func main() {
    err := ProcessFile("/path/to/file")
    if err != nil {
        // %+v でスタックトレースを出力
        fmt.Printf("%+v\n", err)
    }
}

// Output:
// validate file:
//     main.ProcessFile
//         /path/to/main.go:10
// invalid file format:
//     main.validate
//         /path/to/main.go:15
```

### xerrors の主要機能

```go
// エラー生成
err := xerrors.New("error message")

// エラーラップ
return xerrors.Errorf("context: %w", err)

// エラー検査（標準ライブラリと互換）
xerrors.Is(err, target)
xerrors.As(err, &target)
xerrors.Unwrap(err)

// スタックトレース付きフォーマット
fmt.Printf("%+v\n", err)
```

### 本番環境での注意

スタックトレースは情報量が多いため、本番環境では以下に注意：

- **ログファイルサイズ**: 長大なスタックトレースでログが肥大化
- **機密情報**: ファイルパスや変数名から情報漏洩の可能性
- **パフォーマンス**: スタックトレース生成のオーバーヘッド

```go
// 開発環境: 詳細出力
if isDevelopment {
    log.Printf("%+v", err)
}

// 本番環境: 簡潔な出力
if isProduction {
    log.Printf("error: %v", err)
    // 必要に応じてモニタリングサービスに送信
}
```
