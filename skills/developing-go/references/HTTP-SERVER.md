# HTTPサーバー

## 現代のウェブアプリケーションの役割

- **JSONベースのAPI**: HTMLではなくJSONでデータを返すのが主流
- **フロントエンド分離**: React/Vue.jsがUI構築を担当
- **静的ファイル配信はCDN**: ウェブサーバーは必要最小限の責務
- **認証はIDプラットフォーム**: シングルサインオン連携が主流
- **Go標準ライブラリで十分**: `net/http`単体で本番運用可能

## net/httpの主要な型とインターフェース

### Handler インターフェース

```go
type Handler interface {
    ServeHTTP(ResponseWriter, *Request)
}
```

このインターフェースを満たせばHTTPハンドラーとして動作する。

### HandlerFunc 型

関数型でHandlerインターフェースを満たす仕組み。

```go
// Good: 関数をハンドラーとして使用
func Hello(w http.ResponseWriter, r *http.Request) {
    w.Write([]byte("hello world!"))
}

http.HandleFunc("/hello", Hello)
```

### ServeMux 型

パスとハンドラーを紐付けるマルチプレクサー。`http.DefaultServeMux`がデフォルト。

## 基本的なHTTPサーバー

```go
func main() {
    http.HandleFunc("/hello", func(w http.ResponseWriter, r *http.Request) {
        w.Write([]byte("hello world!"))
    })
    http.ListenAndServe(":8888", nil)
}
```

## JSONデータの読み書き

### JSONレスポンス

```go
// Good: json.NewEncoder を使用
http.HandleFunc("/comments", func(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")

    comments := []Comment{{Message: "Hello", UserName: "Alice"}}
    if err := json.NewEncoder(w).Encode(comments); err != nil {
        http.Error(w, fmt.Sprintf(`{"status":"%s"}`, err), http.StatusInternalServerError)
        return
    }
})
```

**重要**: ヘッダー → ステータスコード → ボディの順序を守る。何も設定しない場合は200を返す。

### JSONリクエスト

```go
// Good: json.NewDecoder を使用
var c Comment
if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
    http.Error(w, fmt.Sprintf(`{"status":"%s"}`, err), http.StatusInternalServerError)
    return
}
```

### メソッド判定

`net/http`はURLパスでルーティングするため、メソッド制御は`r.Method`で分岐する。

```go
switch r.Method {
case http.MethodGet:
    // GET処理
case http.MethodPost:
    // POST処理
default:
    http.Error(w, `{"status":"permits only GET or POST"}`, http.StatusMethodNotAllowed)
}
```

## バリデーション

### go-playground/validator（推奨）

構造体タグでルールを定義。

```go
type Comment struct {
    Message  string `validate:"required,min=1,max=140"`
    UserName string `validate:"required,min=1,max=15"`
}

validate := validator.New()
if err := validate.Struct(c); err != nil {
    http.Error(w, fmt.Sprintf(`{"status":"%s"}`, err), http.StatusBadRequest)
    return
}
```

### カスタムエラーメッセージ

```go
if err := validate.Struct(c); err != nil {
    var out []string
    var ve validator.ValidationErrors
    if errors.As(err, &ve) {
        for _, fe := range ve {
            switch fe.Field() {
            case "Message":
                out = append(out, "Messageは1〜140文字です")
            case "UserName":
                out = append(out, "UserNameは1〜15文字です")
            }
        }
    }
    http.Error(w, fmt.Sprintf(`{"status":"%s"}`, strings.Join(out, ",")), http.StatusBadRequest)
    return
}
```

## 必須チェックのハマりどころ

### 問題: ゼロ値と未設定を区別できない

```go
// Bad: Priceに0を指定してもrequired違反になる
type Book struct {
    Title string `validate:"required"`
    Price int    `validate:"required"`  // 0が設定されても検出される
}
```

### 解決策: ポインター型を使用

```go
// Good: nilと0を区別可能
type Book struct {
    Title string `validate:"required"`
    Price *int   `validate:"required"`  // nilと0を区別
}
```

- 値未設定: `nil`
- 明示的に0: `&0`

**bool、数値、文字列の必須チェックは常にポインター型を使うべき。**

## ルーター

### 標準ServeMuxの制限

- パスパラメータ非対応
- HTTPメソッド単位のルーティング非対応

### go-chi/chi（推奨）

```go
import "github.com/go-chi/chi/v5"

r := chi.NewRouter()

// パスパラメータ
r.Get("/users/{userID}", func(w http.ResponseWriter, r *http.Request) {
    userID := chi.URLParam(r, "userID")
    // ...
})

// メソッド単位のルーティング
r.Get("/items", listItems)
r.Post("/items", createItem)
r.Put("/items/{id}", updateItem)
r.Delete("/items/{id}", deleteItem)

http.ListenAndServe(":3000", r)
```

**他の選択肢**: Gin, Echo（より高機能だが標準から離れる）

## Middleware パターン

### 基本形: Handler -> Handler

```go
func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        // 前処理
        next.ServeHTTP(w, r)
        // 後処理
        log.Printf("%s %s %v", r.Method, r.URL.Path, time.Since(start))
    })
}

// 適用
r := chi.NewRouter()
r.Use(loggingMiddleware)
```

### ステータスコードキャプチャ用Middleware

```go
type statusRecorder struct {
    http.ResponseWriter
    statusCode int
}

func (r *statusRecorder) WriteHeader(code int) {
    r.statusCode = code
    r.ResponseWriter.WriteHeader(code)
}

func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        recorder := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}
        next.ServeHTTP(recorder, r)
        log.Printf("%s %s %d", r.Method, r.URL.Path, recorder.statusCode)
    })
}
```

### Panic Recoveryミドルウェア

```go
func recoveryMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if err := recover(); err != nil {
                log.Printf("panic: %v", err)
                http.Error(w, "Internal Server Error", http.StatusInternalServerError)
            }
        }()
        next.ServeHTTP(w, r)
    })
}
```

### タイムアウトミドルウェア

```go
import "time"

func timeoutMiddleware(timeout time.Duration) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.TimeoutHandler(next, timeout, "Request timeout")
    }
}

r.Use(timeoutMiddleware(5 * time.Second))
```

### レートリミット

```go
import "golang.org/x/time/rate"

func rateLimitMiddleware(rps int) func(http.Handler) http.Handler {
    limiter := rate.NewLimiter(rate.Limit(rps), rps)

    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            if !limiter.Allow() {
                http.Error(w, "Too Many Requests", http.StatusTooManyRequests)
                return
            }
            next.ServeHTTP(w, r)
        })
    }
}
```

### DBトランザクション制御ミドルウェア

```go
func txMiddleware(db *sql.DB) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            tx, err := db.BeginTx(r.Context(), nil)
            if err != nil {
                http.Error(w, err.Error(), http.StatusInternalServerError)
                return
            }
            defer tx.Rollback()

            // context経由でtxを渡す
            ctx := context.WithValue(r.Context(), "tx", tx)
            next.ServeHTTP(w, r.WithContext(ctx))

            if err := tx.Commit(); err != nil {
                http.Error(w, err.Error(), http.StatusInternalServerError)
            }
        })
    }
}
```

## SPA（Single Page Application）配信

### embed.FS による静的ファイルバンドル

```go
import (
    "embed"
    "io/fs"
    "net/http"
)

//go:embed dist/*
var staticFiles embed.FS

func main() {
    r := chi.NewRouter()

    // API routes
    r.Route("/api", func(r chi.Router) {
        r.Get("/users", getUsers)
    })

    // SPA配信
    dist, _ := fs.Sub(staticFiles, "dist")
    fileServer := http.FileServer(http.FS(dist))

    r.Get("/*", func(w http.ResponseWriter, r *http.Request) {
        // ファイルが存在しなければindex.htmlを返す（SPAルーティング対応）
        if _, err := dist.Open(strings.TrimPrefix(r.URL.Path, "/")); err != nil {
            r.URL.Path = "/"
        }
        fileServer.ServeHTTP(w, r)
    })

    http.ListenAndServe(":8080", r)
}
```

## Graceful Shutdown

```go
func main() {
    r := chi.NewRouter()
    // ...ルーター設定

    srv := &http.Server{
        Addr:    ":8080",
        Handler: r,
    }

    // 非同期でサーバー起動
    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("listen: %s\n", err)
        }
    }()

    // シグナル待機
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    log.Println("Shutting down server...")

    // タイムアウト付きシャットダウン
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Fatal("Server forced to shutdown:", err)
    }

    log.Println("Server exited")
}
```

## APIドキュメント生成

### oapi-codegen（推奨）

OpenAPI 3.0スキーマからGoコード自動生成。スキーマ駆動開発。

```yaml
# openapi.yaml
openapi: 3.0.0
info:
  title: My API
  version: 1.0.0
paths:
  /users:
    get:
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/User'
components:
  schemas:
    User:
      type: object
      required:
        - id
        - name
      properties:
        id:
          type: integer
        name:
          type: string
```

```bash
# コード生成
oapi-codegen -generate types,chi-server -package api openapi.yaml > api/generated.go
```

### swaggo/swag（代替案）

コードファーストアプローチ。コメントからOpenAPIスキーマ生成。

```go
// @Summary Get users
// @Description Get all users
// @Tags users
// @Accept json
// @Produce json
// @Success 200 {array} User
// @Router /users [get]
func getUsers(w http.ResponseWriter, r *http.Request) {
    // ...
}
```

## ベストプラクティス

| プラクティス | 説明 |
|------------|------|
| ルーターはchiを推奨 | 標準互換、軽量、パスパラメータ対応 |
| バリデーションはvalidatorを使用 | タグベース、カスタマイズ可能 |
| ゼロ値を持つ型の必須チェックはポインター | nil/ゼロ値を区別 |
| Middlewareで共通関心事を分離 | ロギング、認証、リカバリー等 |
| Graceful Shutdownを実装 | SIGTERM/SIGINTで優雅に終了 |
| 静的ファイルはembed.FSでバンドル | シングルバイナリ化 |
| APIドキュメントは自動生成 | oapi-codegenでスキーマ駆動 |
| ヘッダー設定は先に | ヘッダー → ステータス → ボディの順 |

## クッキー管理

### http.SetCookie / r.Cookie

HTTPクッキーの読み書きは標準ライブラリの `http.SetCookie` と `r.Cookie` で行います。

```go
// クッキーを設定する
http.SetCookie(w, &http.Cookie{
    Name:     "session_id",
    Value:    "abc123",
    Path:     "/",
    MaxAge:   86400, // 1日（秒）
    Secure:   true,
    HttpOnly: true,
    SameSite: http.SameSiteStrictMode,
})

// クッキーを読み取る
cookie, err := r.Cookie("session_id")
if err == http.ErrNoCookie {
    http.Error(w, "no session", http.StatusUnauthorized)
    return
}
sessionID := cookie.Value
```

### http.Cookie 構造体の主要フィールド

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `Name` | string | クッキー名 |
| `Value` | string | クッキー値 |
| `Path` | string | 有効パス（`"/"` 推奨） |
| `MaxAge` | int | 有効秒数（0: セッション終了まで、負値: 即削除） |
| `Secure` | bool | HTTPS通信時のみ送信 |
| `HttpOnly` | bool | JavaScriptからアクセス不可（XSS対策） |
| `SameSite` | SameSite | CSRF対策（Strict/Lax/None） |

**推奨セキュリティ設定:**

```go
&http.Cookie{
    HttpOnly: true,                    // XSS対策: 必須
    Secure:   true,                    // HTTPS専用: 本番環境では必須
    SameSite: http.SameSiteStrictMode, // CSRF対策
    Path:     "/",
}
```

## フラッシュメッセージパターン

### クッキーベースの一時メッセージ

PRG（Post-Redirect-Get）パターンと組み合わせた一時メッセージ。`MaxAge: -1` で読み取り後に即削除します。

```go
// 書き込み（リダイレクト前）
func setFlash(w http.ResponseWriter, message string) {
    http.SetCookie(w, &http.Cookie{
        Name:     "flash",
        Value:    url.QueryEscape(message), // エンコード必須
        Path:     "/",
        MaxAge:   0, // セッション終了まで有効
        HttpOnly: true,
    })
}

// 読み取り＋削除（リダイレクト後）
func getFlash(w http.ResponseWriter, r *http.Request) string {
    cookie, err := r.Cookie("flash")
    if err != nil {
        return ""
    }
    // 即削除（MaxAge=-1）
    http.SetCookie(w, &http.Cookie{
        Name:   "flash",
        MaxAge: -1,
        Path:   "/",
    })
    message, _ := url.QueryUnescape(cookie.Value)
    return message
}

// PRGパターン
func createHandler(w http.ResponseWriter, r *http.Request) {
    // ... POST処理 ...
    setFlash(w, "作成が完了しました")
    http.Redirect(w, r, "/list", http.StatusSeeOther)
}

func listHandler(w http.ResponseWriter, r *http.Request) {
    flash := getFlash(w, r) // 読み取りと同時に削除
    // テンプレートにflashを渡す
    _ = flash
}
```

## アンチパターン

| パターン | 問題 | 修正 |
|---------|------|------|
| json.Marshal/Unmarshal多用 | 無駄なバッファ確保 | json.NewEncoder/NewDecoder使用 |
| 必須フィールドを値型で定義 | ゼロ値と未設定を区別不可 | ポインター型使用 |
| エラーをログ出力のみ | クライアントが原因不明 | http.Errorで適切なステータスコード返却 |
| ステータスコード未設定 | 常に200が返る | 明示的にステータスコード設定 |
| panic対策なし | 1つのリクエストでサーバー全体停止 | Recoveryミドルウェア必須 |
| Graceful Shutdown未実装 | リクエスト処理中に強制終了 | signal.Notifyとsrv.Shutdown()使用 |
