# Go命名規則

## 基本原則

### MixedCaps（キャメルケース）
Goでは`snake_case`ではなく`MixedCaps`または`mixedCaps`を使用：

```go
// Good
var userID string
var XMLParser *Parser
func ServeHTTP(w ResponseWriter, r *Request)

// Bad
var user_id string
var xml_parser *Parser
```

### 短く明確な名前
Goは短い名前を好む。スコープが狭いほど短く：

```go
// Good: ループ変数は1文字
for i, v := range items {
    process(v)
}

// Good: レシーバは1-2文字
func (c *Client) Do(req *Request) (*Response, error)

// Good: 関数内の短いスコープ
if err := validate(); err != nil {
    return err
}
```

### 省略形の規則
一般的な省略形は一貫して使用：

```go
// Good: 一般的な省略形
var buf bytes.Buffer     // buffer
var ctx context.Context  // context
var req *http.Request    // request
var resp *http.Response  // response
var err error            // error

// 頭字語は全て大文字または全て小文字
var userID string   // Not: userId
var xmlParser       // Not: XMLparser（エクスポートしない場合）
var XMLParser       // エクスポートする場合
```

## パッケージ名

### 規則
- **小文字のみ**、アンダースコアやMixedCaps不可
- **短く簡潔**に
- **単数形**を使用
- **util, common, misc** などの汎用名は避ける

```go
// Good
package user
package http
package json

// Bad
package userUtils
package http_client
package common
```

### パッケージパスとの関係
```go
// パッケージパス: github.com/user/project/internal/database
package database  // Not: internal_database

// エクスポート名はパッケージ名と重複させない
database.Client   // Good
database.DatabaseClient  // Bad: 冗長
```

## 変数名

### ローカル変数
```go
// Good: スコープに応じた長さ
for i := 0; i < len(items); i++ { }  // ループ変数
if err := f(); err != nil { }        // エラー変数
user := getUser(id)                  // 短いスコープ

// 長いスコープでは説明的に
userRepository := NewUserRepository(db)
requestTimeout := 30 * time.Second
```

### パラメータ名
```go
// Good: 型から意味が明確なら短く
func Copy(dst, src []byte) int
func Read(p []byte) (n int, err error)

// 型だけでは不明確なら説明的に
func NewClient(baseURL string, timeout time.Duration) *Client
```

## 関数名

### 命名パターン
```go
// New + 型名: コンストラクタ
func NewClient(cfg Config) *Client

// Get/Set: アクセサ（ただしGoではGetは省略が一般的）
func (u *User) Name() string        // Not: GetName
func (u *User) SetName(name string) // Setは残す

// Is/Has/Can: bool返却
func (u *User) IsActive() bool
func (f *File) HasPermission(p Permission) bool

// 動詞 + 名詞: アクション
func ProcessOrder(order *Order) error
func ValidateInput(input string) error
```

## インターフェース名

### -erサフィックス
単一メソッドのインターフェースは`メソッド名 + er`：

```go
// Good
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

type Stringer interface {
    String() string
}

type Handler interface {
    Handle(ctx context.Context, req Request) Response
}
```

### 複数メソッドのインターフェース
```go
// 目的を表す名前
type ReadWriter interface {
    Reader
    Writer
}

type Repository interface {
    Find(id string) (*Entity, error)
    Save(entity *Entity) error
    Delete(id string) error
}
```

## 定数とエラー

### 定数
```go
// エクスポートしない定数はcamelCase
const maxRetries = 3
const defaultTimeout = 30 * time.Second

// エクスポートする定数はPascalCase
const MaxConnections = 100
const DefaultBufferSize = 4096

// iotaを使った列挙
type Status int

const (
    StatusPending Status = iota
    StatusActive
    StatusClosed
)
```

### エラー変数
```go
// センチネルエラーはErrプレフィックス
var ErrNotFound = errors.New("not found")
var ErrInvalidInput = errors.New("invalid input")
var ErrTimeout = errors.New("operation timed out")

// エラー型は Errorサフィックス
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed for %s: %s", e.Field, e.Message)
}
```

## アンチパターン

| パターン | 問題 | 修正 |
|---------|------|------|
| `userData` | 冗長なサフィックス | `user` |
| `userList` | 型で明らか | `users` |
| `theUser` | 冠詞は不要 | `user` |
| `GetUser()` | Getは省略 | `User()` |
| `DoProcess()` | Doは冗長 | `Process()` |
| `IUserService` | Iプレフィックス不要 | `UserService` |

## コンテキスト引数

```go
// contextは常に最初の引数、名前はctx
func (c *Client) Fetch(ctx context.Context, url string) (*Response, error)

// Not:
func (c *Client) Fetch(url string, ctx context.Context) (*Response, error)
func (c *Client) Fetch(context context.Context, url string) (*Response, error)
```

## レシーバー名の一貫性

### 同一型では統一したレシーバー名を使用

同じ型のメソッド間でレシーバー名を統一します。`this`や`self`は使いません。

```go
// Good: 一貫したレシーバー名
type Request struct {
    URL     string
    Method  string
    Headers map[string]string
}

func (r *Request) SetHeader(key, value string) {
    r.Headers[key] = value
}

func (r *Request) GetHeader(key string) string {
    return r.Headers[key]
}

func (r *Request) Send() error {
    // すべて "r" で統一
    return nil
}

// Bad: レシーバー名がバラバラ
func (req *Request) SetHeader(key, value string) {
    req.Headers[key] = value
}

func (r *Request) GetHeader(key string) string {
    return r.Headers[key]
}

func (request *Request) Send() error {
    return nil
}

// Bad: this/selfは使わない
func (this *Request) SetHeader(key, value string) {
    this.Headers[key] = value
}

func (self *Request) GetHeader(key string) string {
    return self.Headers[key]
}
```

### レシーバー名の選び方

- **型名の頭文字**: `Request` → `r`, `Client` → `c`
- **1-2文字**: 短く簡潔に
- **全メソッドで統一**: プロジェクト内で一貫性を保つ

```go
// Good: 型に応じた適切なレシーバー名
type Client struct { ... }
func (c *Client) Do() { ... }

type Response struct { ... }
func (r *Response) Body() { ... }

type Regexp struct { ... }
func (re *Regexp) Match() { ... }

type HTTPServer struct { ... }
func (s *HTTPServer) Start() { ... }  // HTTPServerでもsでOK
```

## パッケージ名の詳細ルール

### 汎用名を避ける理由

`util`, `common`, `api`などの汎用パッケージ名は、以下の問題があります：

- **意味が不明確**: パッケージの役割がわからない
- **何でも入る**: 関連のないコードが集まる
- **名前空間の汚染**: `util.Parse()`では何をパースするか不明

```go
// Bad: 汎用パッケージ
package util

func Parse(s string) interface{} { ... }
func FormatDate(t time.Time) string { ... }
func SendEmail(to, body string) error { ... }
// 関連のないユーティリティが混在

// Good: 目的別パッケージ
package jsonparser
func Parse(s string) (map[string]interface{}, error) { ... }

package dateformat
func Format(t time.Time) string { ... }

package mailer
func Send(to, body string) error { ... }
```

### パッケージ名と公開関数名の重複回避

パッケージ名は関数呼び出し時の接頭辞になるため、重複を避けます。

```go
// Bad: 冗長な命名
package http
type HTTPServer struct { ... }
// 使用時: http.HTTPServer (http.HTTP... で冗長)

package database
func DatabaseConnect() (*sql.DB, error) { ... }
// 使用時: database.DatabaseConnect (重複)

// Good: 簡潔な命名
package http
type Server struct { ... }
// 使用時: http.Server (明確で簡潔)

package database
func Connect() (*sql.DB, error) { ... }
// 使用時: database.Connect (重複なし)

package zip
func NewWriter() *Writer { ... }
// Not: zip.NewZipWriter (zipが重複)
```

### 具体例

```go
// Bad: パッケージ名を繰り返す
import "github.com/user/project/http"
server := http.NewHTTPServer()  // http.NewHTTPServer は冗長

// Good: パッケージ名を活用
import "github.com/user/project/http"
server := http.NewServer()      // http.Server で意味が通じる

// Bad: 汎用的すぎる
import "github.com/user/project/util"
result := util.Parse()          // 何をパースするか不明

// Good: 具体的な名前
import "github.com/user/project/jsonparser"
result := jsonparser.Parse()    // JSONをパースすることが明確
```

### パッケージパスと名前の対応

フォルダ階層とパッケージ名を適切に対応させます。

```go
// Good: 明確な階層
encoding/json     → package json
encoding/xml      → package xml
net/http          → package http
database/sql      → package sql

// 使用時
import "encoding/json"
data, _ := json.Marshal(obj)  // json.Marshal は明確

// Bad: 階層を無視
encoding/json     → package encodingjson
// 使用時: encodingjson.Marshal (冗長)
```
