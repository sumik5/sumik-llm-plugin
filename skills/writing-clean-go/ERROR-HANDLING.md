# クリーンなエラーハンドリング

Goにおけるクリーンで保守性の高いエラーハンドリングパターン。

---

## 1. Goのエラー哲学

### エラーは値である

Goでは例外機構は存在せず、エラーは通常の戻り値として扱われる。

```go
type error interface {
    Error() string
}
```

**特徴:**
- エラーは明示的に返却され、呼び出し側が責任を持って処理する
- 制御フローが明確で予測可能
- コンパイラがエラーチェック漏れを検出しやすい

### 例外ベース言語との違い

| 特性 | 例外ベース（Java/Python等） | Goのエラー値 |
|------|---------------------------|-------------|
| 伝搬 | 暗黙的（スタックを遡る） | 明示的（戻り値） |
| 制御フロー | try/catch で分岐 | if err != nil で分岐 |
| 強制力 | checked exception のみ | コンパイラ警告 |
| 可視性 | 見逃しやすい | 明示的で見やすい |

### panic は最終手段

panic は「本当に回復不能な状況」のみに使用する:

- **初期化失敗**: 必須設定ファイルが読めない
- **プログラマエラー**: nil ポインタアクセス、配列外アクセス等の検出
- **不変条件違反**: データ構造の整合性が崩れた

通常の業務ロジックエラー（ファイルが見つからない、バリデーション失敗等）では panic を使わない。

---

## 2. エラーを明確に返す

### 即座にチェック、即座にハンドル

```go
// ❌ エラーチェックを遅延
func badExample(path string) ([]byte, error) {
    data, err := os.ReadFile(path)
    // 50行後にチェック...
    if err != nil {
        return nil, err
    }
    return data, nil
}

// ✅ 即座にチェック
func goodExample(path string) ([]byte, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("failed to read file %s: %w", path, err)
    }
    return data, nil
}
```

**原則:**
- エラーは発生した場所で即座にチェック
- 無視する場合は明示的に `_ = err` と書く（意図的であることを示す）

### コンテキストを追加する（%w）

Go 1.13+ では `%w` を使ってエラーをラップし、コンテキストを追加する。

```go
// ❌ コンテキストなし
func processUser(id int) error {
    user, err := fetchUser(id)
    if err != nil {
        return err  // どのユーザー？どの操作？
    }
    return nil
}

// ✅ コンテキスト付き
func processUser(id int) error {
    user, err := fetchUser(id)
    if err != nil {
        return fmt.Errorf("processing user %d: %w", id, err)
    }
    return nil
}
```

**効果:**
- エラーメッセージが「failed to connect database: processing user 123: user not found」のように積み重なる
- デバッグ時にエラーの発生経路が追跡可能
- `errors.Is` / `errors.As` で元のエラー型を検査可能

### パッケージ境界での抽象化

内部実装の詳細を外部に漏らさない。

```go
// ❌ 内部エラーをそのまま返却
func (r *UserRepository) FindByID(id int) (*User, error) {
    row := r.db.QueryRow("SELECT * FROM users WHERE id = ?", id)
    var user User
    if err := row.Scan(&user.ID, &user.Name); err != nil {
        return nil, err  // sql.ErrNoRows が外部に漏れる
    }
    return &user, nil
}

// ✅ 内部エラーをラップして抽象化
var ErrUserNotFound = errors.New("user not found")

func (r *UserRepository) FindByID(id int) (*User, error) {
    row := r.db.QueryRow("SELECT * FROM users WHERE id = ?", id)
    var user User
    if err := row.Scan(&user.ID, &user.Name); err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrUserNotFound
        }
        return nil, fmt.Errorf("failed to query user: %w", err)
    }
    return &user, nil
}
```

**利点:**
- 外部コードは `sql.ErrNoRows` の存在を知る必要がない
- DB実装を変更してもエラー型が安定
- パッケージのAPI契約が明確

---

## 3. 再利用可能なエラーパターン

### カスタムエラー型

追加情報を持つ構造体エラー。

```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed on field %s: %s", e.Field, e.Message)
}

// ラップされたエラーを返すためUnwrapを実装
func (e *ValidationError) Unwrap() error {
    return nil  // 必要に応じて内部エラーを返す
}
```

**使用例:**

```go
func validateEmail(email string) error {
    if !strings.Contains(email, "@") {
        return &ValidationError{
            Field:   "email",
            Message: "must contain @ symbol",
        }
    }
    return nil
}

// 呼び出し側
if err := validateEmail(input); err != nil {
    var validationErr *ValidationError
    if errors.As(err, &validationErr) {
        fmt.Printf("Invalid %s: %s\n", validationErr.Field, validationErr.Message)
    }
}
```

### センチネルエラー

特定条件を表す定義済みエラー値。

```go
var (
    ErrNotFound         = errors.New("item not found")
    ErrPermissionDenied = errors.New("permission denied")
    ErrInvalidArgument  = errors.New("invalid argument")
)
```

**使用例:**

```go
func findItem(id int) (*Item, error) {
    item := db.Find(id)
    if item == nil {
        return nil, ErrNotFound
    }
    return item, nil
}

// 呼び出し側
item, err := findItem(123)
if errors.Is(err, ErrNotFound) {
    // 404 Not Found を返す
    http.Error(w, "Item not found", http.StatusNotFound)
    return
}
```

### errors.Is / errors.As （Go 1.13+）

ラップされたエラーの検査。

```go
// errors.Is: エラー等値チェック
if errors.Is(err, ErrNotFound) {
    // ErrNotFound またはそれをラップしたエラー
}

// errors.As: エラー型アサーション
var validationErr *ValidationError
if errors.As(err, &validationErr) {
    // validationErr に実際のエラーが格納される
    fmt.Printf("Field: %s, Message: %s\n",
        validationErr.Field, validationErr.Message)
}
```

**❌ 文字列比較は避ける:**

```go
// ❌ 脆弱
if err != nil && err.Error() == "not found" {
    // エラーメッセージの変更で壊れる
}

// ✅ 型ベース
if errors.Is(err, ErrNotFound) {
    // 安全
}
```

### エラーパターン選択基準

| パターン | 使用場面 | 例 |
|---------|---------|-----|
| `fmt.Errorf + %w` | コンテキスト追加 | `fmt.Errorf("processing item %d: %w", id, err)` |
| カスタムエラー型 | 追加情報が必要 | `ValidationError{Field: "email", Message: "invalid"}` |
| センチネルエラー | 特定条件の定義 | `ErrNotFound`, `ErrPermissionDenied` |
| `errors.Is` | 特定エラーの等値チェック | `errors.Is(err, ErrNotFound)` |
| `errors.As` | エラー型アサーション | `errors.As(err, &validationErr)` |

---

## 4. panic と recover の適切な使い方

### panic の正当な使用場面

```go
// ✅ 初期化時の必須設定ファイル読み込み失敗
func init() {
    data, err := os.ReadFile("config.json")
    if err != nil {
        panic(fmt.Sprintf("Fatal: unable to read config: %v", err))
    }
    // ...
}

// ✅ プログラマエラーの検出
func divide(a, b int) int {
    if b == 0 {
        panic("divide by zero")  // 呼び出し側のバグ
    }
    return a / b
}

// ✅ テスト内での致命的失敗
func TestCriticalSetup(t *testing.T) {
    db, err := setupTestDatabase()
    if err != nil {
        panic("test database setup failed: " + err.Error())
    }
}
```

**❌ 業務ロジックでの panic:**

```go
// ❌ 通常のエラーでpanic
func findUser(id int) *User {
    user := db.Find(id)
    if user == nil {
        panic("user not found")  // エラーを返すべき
    }
    return user
}

// ✅ エラーを返す
func findUser(id int) (*User, error) {
    user := db.Find(id)
    if user == nil {
        return nil, ErrNotFound
    }
    return user, nil
}
```

### recover の仕組み

recover は deferred 関数内でのみ有効。

```go
func safeDivide(a, b int) (result int, err error) {
    defer func() {
        if r := recover(); r != nil {
            err = fmt.Errorf("panic recovered: %v", r)
        }
    }()

    result = a / b  // b=0 でpanic
    return result, nil
}
```

### goroutine ごとに recover を設定

goroutine 内の panic は他の goroutine に伝搬しない。

```go
// ❌ 無防備なgoroutine
func unsafeWorker(job func()) {
    go job()  // panicでプログラム全体が落ちる
}

// ✅ safe wrapper
func safeGoroutine(job func()) {
    go func() {
        defer func() {
            if r := recover(); r != nil {
                log.Printf("Recovered from panic in goroutine: %v\n%s",
                    r, debug.Stack())
            }
        }()
        job()
    }()
}
```

**ベストプラクティス:**
- 長時間実行される goroutine には必ず recover を設定
- スタックトレースをログに記録（`runtime/debug.Stack()`）
- HTTP サーバーでは標準ライブラリが自動的に recover する

---

## 5. 並行処理でのエラーハンドリング

### エラーチャネルパターン

goroutine からエラーを伝搬する基本パターン。

```go
func processItems(items []int) error {
    errChan := make(chan error, len(items))  // バッファ付き

    for _, item := range items {
        go func(i int) {
            if err := processItem(i); err != nil {
                errChan <- fmt.Errorf("item %d: %w", i, err)
            } else {
                errChan <- nil
            }
        }(item)
    }

    // すべてのgoroutineの完了を待つ
    for range items {
        if err := <-errChan; err != nil {
            return err  // 最初のエラーを返す
        }
    }
    return nil
}
```

**重要:**
- エラーチャネルは**バッファ付き**で作成（goroutineのブロック防止）
- すべての goroutine が送信を完了するまで受信を続ける

### sync.WaitGroup + エラーチャネル

```go
func processItemsConcurrent(items []int) error {
    var wg sync.WaitGroup
    errChan := make(chan error, len(items))

    for _, item := range items {
        wg.Add(1)
        go func(i int) {
            defer wg.Done()
            if err := processItem(i); err != nil {
                errChan <- err
            }
        }(item)
    }

    // 別goroutineで完了を待つ
    go func() {
        wg.Wait()
        close(errChan)
    }()

    // エラーを収集
    for err := range errChan {
        if err != nil {
            return err
        }
    }
    return nil
}
```

### context によるタイムアウト・キャンセル

```go
func processWithTimeout(ctx context.Context, item int) error {
    errChan := make(chan error, 1)

    go func() {
        errChan <- processItem(item)
    }()

    select {
    case err := <-errChan:
        return err
    case <-ctx.Done():
        return fmt.Errorf("operation cancelled: %w", ctx.Err())
    }
}

// 使用例
func main() {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := processWithTimeout(ctx, 123); err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            log.Println("Operation timed out")
        } else {
            log.Printf("Error: %v", err)
        }
    }
}
```

### errgroup パッケージの活用

`golang.org/x/sync/errgroup` は並行処理のエラーハンドリングを簡潔にする。

```go
import "golang.org/x/sync/errgroup"

func processItemsWithErrGroup(ctx context.Context, items []int) error {
    g, ctx := errgroup.WithContext(ctx)

    for _, item := range items {
        item := item  // ループ変数のキャプチャ
        g.Go(func() error {
            return processItem(item)
        })
    }

    // 最初のエラーでコンテキストがキャンセルされる
    return g.Wait()
}
```

**特徴:**
- 最初のエラーで自動的にコンテキストをキャンセル
- すべての goroutine の完了を待つ
- 最初のエラーを返す

---

## 6. エラーハンドリング ベストプラクティス一覧

### 基本原則

```
✅ エラーは即座にチェックしているか？
✅ fmt.Errorf + %w でコンテキストを追加しているか？
✅ パッケージ境界で内部エラーをラップしているか？
✅ カスタムエラー型に Unwrap() を実装しているか？
✅ errors.Is / errors.As を使っているか？（文字列比較は避ける）
✅ panic は本当に回復不能な場面のみに限定しているか？
✅ goroutineごとに recover を設定しているか？
✅ 並行処理ではバッファ付きエラーチャネルを使っているか？
```

### エラーメッセージの書き方

```go
// ❌ 大文字始まり、句読点付き
return errors.New("Failed to connect.")

// ✅ 小文字始まり、句読点なし
return errors.New("failed to connect")

// ❌ 冗長
return fmt.Errorf("error: failed to open file: %w", err)

// ✅ 簡潔
return fmt.Errorf("failed to open file: %w", err)
```

**原則:**
- 小文字始まり（他のエラーにラップされる前提）
- 句読点なし（末尾のピリオド不要）
- "error:" などの接頭辞は不要

### エラーハンドリングのリファクタリング例

```go
// ❌ エラーハンドリングが散在
func processOrder(orderID int) error {
    order, err := fetchOrder(orderID)
    if err != nil {
        log.Println("Error fetching order:", err)
        return err
    }

    if err := validateOrder(order); err != nil {
        log.Println("Validation error:", err)
        return err
    }

    if err := saveOrder(order); err != nil {
        log.Println("Save error:", err)
        return err
    }

    return nil
}

// ✅ エラーハンドリングを集約
func processOrder(orderID int) (err error) {
    defer func() {
        if err != nil {
            log.Printf("failed to process order %d: %v", orderID, err)
        }
    }()

    order, err := fetchOrder(orderID)
    if err != nil {
        return fmt.Errorf("fetch: %w", err)
    }

    if err := validateOrder(order); err != nil {
        return fmt.Errorf("validate: %w", err)
    }

    if err := saveOrder(order); err != nil {
        return fmt.Errorf("save: %w", err)
    }

    return nil
}
```

### エラーログの記録場所

```go
// ❌ すべての層でログ記録
func serviceLayer() error {
    err := repositoryLayer()
    if err != nil {
        log.Printf("Error in service: %v", err)  // 重複ログ
        return err
    }
    return nil
}

func repositoryLayer() error {
    err := databaseQuery()
    if err != nil {
        log.Printf("Error in repository: %v", err)  // 重複ログ
        return err
    }
    return nil
}

// ✅ 最上位層でのみログ記録
func handler(w http.ResponseWriter, r *http.Request) {
    err := serviceLayer()
    if err != nil {
        log.Printf("Request failed: %v", err)  // ここだけ
        http.Error(w, "Internal Server Error", http.StatusInternalServerError)
    }
}

func serviceLayer() error {
    return repositoryLayer()  // エラーを伝搬するだけ
}

func repositoryLayer() error {
    return databaseQuery()  // エラーを伝搬するだけ
}
```

**原則:**
- エラーは1回だけログに記録（最上位層）
- 中間層ではコンテキストを追加して伝搬
- ログの重複を避ける

---

## まとめ

Goのエラーハンドリングは「明示的」「予測可能」「シンプル」を重視する:

1. **エラーは値** - 通常の制御フローで扱う
2. **即座にチェック** - 発生箇所で処理を分岐
3. **コンテキスト追加** - `%w` でエラーをラップ
4. **パターン選択** - センチネル、カスタム型、ラップを使い分け
5. **panic は最終手段** - 回復不能な状況のみ
6. **並行処理** - エラーチャネル、context、errgroup を活用

これらのパターンを組み合わせることで、デバッグしやすく保守性の高いエラーハンドリングが実現できる。
