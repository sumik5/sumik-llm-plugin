# 並行処理・テスト・リファクタリング

Goにおけるクリーンな並行処理パターン、テスト設計、リファクタリング戦略の実践ガイド。

---

## Part 1: クリーンな並行処理

### 1. 並行処理の基本原則

**3つの基本原則:**
1. **goroutineは軽量だが無制限に作らない** - リソース枯渇を避ける
2. **チャネルによる通信 > 共有メモリ** - "Share memory by communicating"
3. **contextでキャンセル・タイムアウト管理** - goroutineリーク防止

```go
// ❌ 共有メモリパターン（避ける）
var counter int
var mu sync.Mutex

func increment() {
    mu.Lock()
    counter++
    mu.Unlock()
}

// ✅ チャネル通信パターン（推奨）
func counter(ops chan int, result chan int) {
    count := 0
    for range ops {
        count++
    }
    result <- count
}
```

---

### 2. クリーンな並行処理パターン

#### Worker Pool パターン

固定数のworkerで大量タスクを処理。goroutine数を制御し、リソース消費を予測可能にする。

```go
// ✅ Worker Pool実装
func workerPool(ctx context.Context, numWorkers int, tasks <-chan int, results chan<- int) {
    var wg sync.WaitGroup

    // Worker起動
    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func(workerID int) {
            defer wg.Done()

            for {
                select {
                case <-ctx.Done():
                    return // キャンセル対応
                case task, ok := <-tasks:
                    if !ok {
                        return // チャネルクローズ
                    }
                    results <- process(task)
                }
            }
        }(i)
    }

    wg.Wait()
    close(results)
}

func process(task int) int {
    // 実際の処理
    time.Sleep(time.Millisecond * 100)
    return task * 2
}

// 使用例
func main() {
    ctx, cancel := context.WithTimeout(context.Background(), time.Second*5)
    defer cancel()

    tasks := make(chan int, 100)
    results := make(chan int, 100)

    // Worker起動
    go workerPool(ctx, 5, tasks, results)

    // タスク投入
    go func() {
        for i := 0; i < 20; i++ {
            tasks <- i
        }
        close(tasks)
    }()

    // 結果収集
    for result := range results {
        fmt.Println("Result:", result)
    }
}
```

---

#### Fan-out/Fan-in パターン

複数goroutineに処理を分散（Fan-out）し、結果を一つのチャネルに集約（Fan-in）。

```go
// ✅ Fan-out: 入力を複数workerに分散
func fanOut(input <-chan int, workers int) []<-chan int {
    outputs := make([]<-chan int, workers)

    for i := 0; i < workers; i++ {
        outputs[i] = work(input)
    }

    return outputs
}

func work(input <-chan int) <-chan int {
    output := make(chan int)

    go func() {
        defer close(output)
        for n := range input {
            output <- n * n // 例: 二乗計算
        }
    }()

    return output
}

// ✅ Fan-in: 複数チャネルを一つに集約
func fanIn(ctx context.Context, inputs ...<-chan int) <-chan int {
    output := make(chan int)
    var wg sync.WaitGroup

    wg.Add(len(inputs))

    for _, ch := range inputs {
        go func(c <-chan int) {
            defer wg.Done()
            for {
                select {
                case <-ctx.Done():
                    return
                case n, ok := <-c:
                    if !ok {
                        return
                    }
                    output <- n
                }
            }
        }(ch)
    }

    go func() {
        wg.Wait()
        close(output)
    }()

    return output
}

// 使用例
func main() {
    ctx := context.Background()

    input := make(chan int)

    // Fan-out: 3つのworkerに分散
    outputs := fanOut(input, 3)

    // Fan-in: 結果を集約
    result := fanIn(ctx, outputs...)

    // 入力投入
    go func() {
        for i := 0; i < 10; i++ {
            input <- i
        }
        close(input)
    }()

    // 結果収集
    for r := range result {
        fmt.Println("Result:", r)
    }
}
```

---

#### セマフォパターン

並行数を動的に制限。外部APIレート制限、DB接続プール等に有効。

```go
// ✅ バッファ付きチャネルでセマフォ実装
func processWithSemaphore(items []int, maxConcurrent int) {
    sem := make(chan struct{}, maxConcurrent)
    var wg sync.WaitGroup

    for _, item := range items {
        wg.Add(1)

        go func(id int) {
            defer wg.Done()

            // セマフォ取得（空きがなければブロック）
            sem <- struct{}{}
            defer func() { <-sem }() // セマフォ解放

            doWork(id)
        }(item)
    }

    wg.Wait()
}

func doWork(id int) {
    fmt.Printf("Processing %d\n", id)
    time.Sleep(time.Millisecond * 100)
}

// ✅ 実践例: API呼び出し制限
func fetchURLs(urls []string, maxConcurrent int) []Result {
    sem := make(chan struct{}, maxConcurrent)
    results := make([]Result, len(urls))
    var wg sync.WaitGroup

    for i, url := range urls {
        wg.Add(1)

        go func(index int, u string) {
            defer wg.Done()

            sem <- struct{}{}
            defer func() { <-sem }()

            resp, err := http.Get(u)
            if err != nil {
                results[index] = Result{Error: err}
                return
            }
            defer resp.Body.Close()

            body, _ := io.ReadAll(resp.Body)
            results[index] = Result{Data: body}
        }(i, url)
    }

    wg.Wait()
    return results
}

type Result struct {
    Data  []byte
    Error error
}
```

---

#### パターン選択基準

| パターン | 使用場面 | 特徴 | 例 |
|---------|---------|------|-----|
| **Worker Pool** | バッチ処理、タスクキュー | goroutine数を固定、リソース制御 | 画像変換、ログ処理 |
| **Fan-out/Fan-in** | 独立した計算の並列化 | 分散→集約、パイプライン | データ集計、並列検索 |
| **セマフォ** | リソースアクセス制限 | 並行数の上限設定 | API呼び出し、DB接続 |
| **Pipeline** | データストリーム処理 | ステージ間チャネル接続 | ETL処理、データ変換 |

---

### 3. 並行処理の落とし穴回避

#### 落とし穴 1: goroutineリーク

```go
// ❌ リークするgoroutine
func leakyFunction() {
    ch := make(chan int)

    go func() {
        for {
            // チャネルから受信し続ける
            // 終了条件がない → goroutineがずっと生き続ける
            val := <-ch
            process(val)
        }
    }()

    // chに何も送信せずに関数終了 → goroutineが永遠に待機
}

// ✅ contextでキャンセル可能
func nonLeakyFunction(ctx context.Context) {
    ch := make(chan int)

    go func() {
        for {
            select {
            case <-ctx.Done():
                return // キャンセルシグナルで終了
            case val := <-ch:
                process(val)
            }
        }
    }()
}

// ✅ doneチャネルパターン
func nonLeakyFunctionWithDone() func() {
    ch := make(chan int)
    done := make(chan struct{})

    go func() {
        for {
            select {
            case <-done:
                return
            case val := <-ch:
                process(val)
            }
        }
    }()

    // クリーンアップ関数を返す
    return func() {
        close(done)
    }
}
```

---

#### 落とし穴 2: デッドロック

```go
// ❌ デッドロック: チャネル送受信の順序ミス
func deadlock() {
    ch := make(chan int)

    ch <- 42 // バッファなしチャネル → 受信者がいないとブロック
    val := <-ch // ここに到達しない

    fmt.Println(val)
}

// ✅ バッファ付きチャネル
func noDeadlock1() {
    ch := make(chan int, 1) // バッファサイズ1

    ch <- 42
    val := <-ch

    fmt.Println(val)
}

// ✅ goroutineで送信
func noDeadlock2() {
    ch := make(chan int)

    go func() {
        ch <- 42
    }()

    val := <-ch
    fmt.Println(val)
}

// ❌ 循環デッドロック
func circularDeadlock() {
    ch1 := make(chan int)
    ch2 := make(chan int)

    go func() {
        val := <-ch1 // ch1から受信待ち
        ch2 <- val   // ch2へ送信
    }()

    go func() {
        val := <-ch2 // ch2から受信待ち
        ch1 <- val   // ch1へ送信
    }()

    // どちらのgoroutineも相手の送信待ち → デッドロック
}

// ✅ タイムアウトで回避
func avoidDeadlock(ctx context.Context) error {
    ch := make(chan int)

    select {
    case val := <-ch:
        fmt.Println(val)
    case <-time.After(time.Second):
        return fmt.Errorf("timeout")
    case <-ctx.Done():
        return ctx.Err()
    }

    return nil
}
```

---

#### 落とし穴 3: チャネルの不適切なクローズ

```go
// ❌ 受信側がチャネルをクローズ
func badClose() {
    ch := make(chan int)

    go func() {
        ch <- 42
        ch <- 43
    }()

    val := <-ch
    fmt.Println(val)
    close(ch) // 送信側がまだ送信中！ → panic: send on closed channel
}

// ✅ 送信側のみがクローズ
func goodClose() {
    ch := make(chan int)

    go func() {
        defer close(ch) // goroutine終了時にクローズ
        ch <- 42
        ch <- 43
    }()

    // rangeで受信（チャネルクローズまで継続）
    for val := range ch {
        fmt.Println(val)
    }
}

// ✅ 複数送信者パターン: doneチャネルでシグナル
func multiSenderClose() {
    ch := make(chan int)
    done := make(chan struct{})

    // 複数の送信者
    for i := 0; i < 3; i++ {
        go func(id int) {
            for {
                select {
                case <-done:
                    return
                case ch <- id:
                }
            }
        }(i)
    }

    // 受信
    go func() {
        time.Sleep(time.Second)
        close(done) // 全送信者に停止シグナル
    }()

    for val := range ch {
        fmt.Println(val)
    }
}
```

---

#### 落とし穴 4: Race Condition

```go
// ❌ Race condition
var counter int

func increment() {
    counter++ // 複数goroutineから同時アクセス
}

func badRace() {
    for i := 0; i < 1000; i++ {
        go increment()
    }

    time.Sleep(time.Second)
    fmt.Println(counter) // 不定な結果
}

// ✅ Mutexで保護
var (
    counter int
    mu      sync.Mutex
)

func safeIncrement() {
    mu.Lock()
    counter++
    mu.Unlock()
}

// ✅ atomic操作
var atomicCounter int64

func atomicIncrement() {
    atomic.AddInt64(&atomicCounter, 1)
}

// ✅ チャネルパターン（最も推奨）
func channelCounter() {
    ops := make(chan int, 100)
    result := make(chan int)

    // カウンター専用goroutine
    go func() {
        count := 0
        for range ops {
            count++
        }
        result <- count
    }()

    // 複数goroutineから操作
    var wg sync.WaitGroup
    for i := 0; i < 1000; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            ops <- 1
        }()
    }

    wg.Wait()
    close(ops)

    finalCount := <-result
    fmt.Println("Count:", finalCount)
}
```

**Race Detectorの活用:**
```bash
# テスト時にrace検出
go test -race ./...

# ビルド時にrace検出
go build -race

# 実行時にrace検出
go run -race main.go
```

---

## Part 2: クリーンなテスト

### 4. テーブル駆動テスト

Goの標準テストパターン。複数のテストケースを構造化して管理。

```go
// ✅ 基本的なテーブル駆動テスト
func TestAdd(t *testing.T) {
    tests := []struct {
        name string
        a, b int
        want int
    }{
        {"positive numbers", 2, 3, 5},
        {"zero values", 0, 0, 0},
        {"negative numbers", -1, 1, 0},
        {"large numbers", 1000, 2000, 3000},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Add(tt.a, tt.b)
            if got != tt.want {
                t.Errorf("Add(%d, %d) = %d; want %d", tt.a, tt.b, got, tt.want)
            }
        })
    }
}

func Add(a, b int) int {
    return a + b
}
```

---

#### エラーケースを含むテーブル駆動テスト

```go
// ✅ エラー処理のテスト
func TestDivide(t *testing.T) {
    tests := []struct {
        name    string
        a, b    int
        want    int
        wantErr bool
    }{
        {"normal division", 10, 2, 5, false},
        {"divide by zero", 10, 0, 0, true},
        {"negative numbers", -10, 2, -5, false},
        {"zero dividend", 0, 5, 0, false},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := Divide(tt.a, tt.b)

            if (err != nil) != tt.wantErr {
                t.Errorf("Divide(%d, %d) error = %v, wantErr %v", tt.a, tt.b, err, tt.wantErr)
                return
            }

            if !tt.wantErr && got != tt.want {
                t.Errorf("Divide(%d, %d) = %d; want %d", tt.a, tt.b, got, tt.want)
            }
        })
    }
}

func Divide(a, b int) (int, error) {
    if b == 0 {
        return 0, fmt.Errorf("division by zero")
    }
    return a / b, nil
}
```

---

#### 複雑な構造体のテスト

```go
type User struct {
    ID    int
    Name  string
    Email string
    Age   int
}

// ✅ 構造体のテーブル駆動テスト
func TestValidateUser(t *testing.T) {
    tests := []struct {
        name    string
        user    User
        wantErr bool
        errMsg  string
    }{
        {
            name:    "valid user",
            user:    User{ID: 1, Name: "Alice", Email: "alice@example.com", Age: 25},
            wantErr: false,
        },
        {
            name:    "missing name",
            user:    User{ID: 1, Name: "", Email: "alice@example.com", Age: 25},
            wantErr: true,
            errMsg:  "name is required",
        },
        {
            name:    "invalid email",
            user:    User{ID: 1, Name: "Bob", Email: "invalid-email", Age: 30},
            wantErr: true,
            errMsg:  "invalid email format",
        },
        {
            name:    "underage",
            user:    User{ID: 1, Name: "Charlie", Email: "charlie@example.com", Age: 15},
            wantErr: true,
            errMsg:  "age must be at least 18",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateUser(tt.user)

            if (err != nil) != tt.wantErr {
                t.Errorf("ValidateUser() error = %v, wantErr %v", err, tt.wantErr)
                return
            }

            if tt.wantErr && err.Error() != tt.errMsg {
                t.Errorf("ValidateUser() error message = %q, want %q", err.Error(), tt.errMsg)
            }
        })
    }
}

func ValidateUser(u User) error {
    if u.Name == "" {
        return fmt.Errorf("name is required")
    }
    if !strings.Contains(u.Email, "@") {
        return fmt.Errorf("invalid email format")
    }
    if u.Age < 18 {
        return fmt.Errorf("age must be at least 18")
    }
    return nil
}
```

---

### 5. モックとインターフェースによる依存注入

外部依存（DB、API等）をインターフェースで抽象化し、テスト時にモック実装を注入。

```go
// ✅ インターフェース定義
type DataStore interface {
    Get(key string) (string, error)
    Set(key, value string) error
    Delete(key string) error
}

// 本番実装（Redis等）
type RedisStore struct {
    client *redis.Client
}

func (r *RedisStore) Get(key string) (string, error) {
    return r.client.Get(context.Background(), key).Result()
}

func (r *RedisStore) Set(key, value string) error {
    return r.client.Set(context.Background(), key, value, 0).Err()
}

func (r *RedisStore) Delete(key string) error {
    return r.client.Del(context.Background(), key).Err()
}

// ✅ モック実装（テスト用）
type MockDataStore struct {
    data map[string]string
    err  error
}

func NewMockDataStore() *MockDataStore {
    return &MockDataStore{
        data: make(map[string]string),
    }
}

func (m *MockDataStore) Get(key string) (string, error) {
    if m.err != nil {
        return "", m.err
    }

    value, ok := m.data[key]
    if !ok {
        return "", fmt.Errorf("key not found: %s", key)
    }
    return value, nil
}

func (m *MockDataStore) Set(key, value string) error {
    if m.err != nil {
        return m.err
    }
    m.data[key] = value
    return nil
}

func (m *MockDataStore) Delete(key string) error {
    if m.err != nil {
        return m.err
    }
    delete(m.data, key)
    return nil
}

// ビジネスロジック（インターフェースに依存）
func ProcessData(store DataStore, key string) (string, error) {
    value, err := store.Get(key)
    if err != nil {
        return "", err
    }

    processed := value + " processed"

    if err := store.Set(key+"_processed", processed); err != nil {
        return "", err
    }

    return processed, nil
}

// ✅ テスト
func TestProcessData(t *testing.T) {
    tests := []struct {
        name      string
        key       string
        setupMock func(*MockDataStore)
        want      string
        wantErr   bool
    }{
        {
            name: "successful processing",
            key:  "testKey",
            setupMock: func(m *MockDataStore) {
                m.data["testKey"] = "testValue"
            },
            want:    "testValue processed",
            wantErr: false,
        },
        {
            name: "key not found",
            key:  "missingKey",
            setupMock: func(m *MockDataStore) {
                // データなし
            },
            want:    "",
            wantErr: true,
        },
        {
            name: "store error",
            key:  "errorKey",
            setupMock: func(m *MockDataStore) {
                m.err = fmt.Errorf("database connection failed")
            },
            want:    "",
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            mockStore := NewMockDataStore()
            tt.setupMock(mockStore)

            got, err := ProcessData(mockStore, tt.key)

            if (err != nil) != tt.wantErr {
                t.Errorf("ProcessData() error = %v, wantErr %v", err, tt.wantErr)
                return
            }

            if got != tt.want {
                t.Errorf("ProcessData() = %q, want %q", got, tt.want)
            }
        })
    }
}
```

---

#### ヘルパー関数とt.Helper()

テストコードの重複を削減し、エラー発生箇所を正確に報告。

```go
// ✅ ヘルパー関数
func assertNoError(t *testing.T, err error) {
    t.Helper() // この関数をスタックトレースから除外
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
}

func assertEqual(t *testing.T, got, want interface{}) {
    t.Helper()
    if got != want {
        t.Errorf("got %v, want %v", got, want)
    }
}

func assertError(t *testing.T, err error, wantMsg string) {
    t.Helper()
    if err == nil {
        t.Fatal("expected error, got nil")
    }
    if err.Error() != wantMsg {
        t.Errorf("error message = %q, want %q", err.Error(), wantMsg)
    }
}

// 使用例
func TestUserService(t *testing.T) {
    store := NewMockDataStore()
    service := NewUserService(store)

    user, err := service.GetUser("user123")
    assertNoError(t, err)
    assertEqual(t, user.Name, "Alice")
}
```

---

### 6. 並行処理のテスト

```go
// ✅ 基本的な並行処理テスト
func TestConcurrentOperation(t *testing.T) {
    done := make(chan bool)

    go func() {
        // 並行操作実行
        result := performOperation()
        if result != "expected" {
            t.Errorf("got %v, want expected", result)
        }
        done <- true
    }()

    select {
    case <-done:
        // テスト成功
    case <-time.After(time.Second):
        t.Fatal("Test timed out")
    }
}

func performOperation() string {
    time.Sleep(time.Millisecond * 100)
    return "expected"
}
```

---

#### sync.WaitGroupによる複数goroutineのテスト

```go
// ✅ 複数goroutineの完了待ち
func TestConcurrentWrites(t *testing.T) {
    store := NewMockDataStore()
    var wg sync.WaitGroup

    // 100個のgoroutineで同時書き込み
    for i := 0; i < 100; i++ {
        wg.Add(1)
        go func(id int) {
            defer wg.Done()

            key := fmt.Sprintf("key%d", id)
            value := fmt.Sprintf("value%d", id)

            if err := store.Set(key, value); err != nil {
                t.Errorf("Set(%s, %s) failed: %v", key, value, err)
            }
        }(i)
    }

    // 全goroutineの完了待ち
    wg.Wait()

    // 検証
    if len(store.data) != 100 {
        t.Errorf("expected 100 entries, got %d", len(store.data))
    }
}
```

---

#### Race Detectorの活用

```go
// ✅ Race conditionのテスト
func TestRaceCondition(t *testing.T) {
    counter := 0
    var wg sync.WaitGroup

    for i := 0; i < 1000; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            counter++ // Race condition!
        }()
    }

    wg.Wait()

    // go test -race で実行すると検出される
    t.Logf("Counter: %d", counter)
}
```

**実行方法:**
```bash
# Race detectorを有効化してテスト
go test -race ./...

# 出力例:
# WARNING: DATA RACE
# Write at 0x00c0000b6010 by goroutine 8:
#   TestRaceCondition.func1()
# Previous write at 0x00c0000b6010 by goroutine 7:
#   TestRaceCondition.func1()
```

---

#### チャネルのテスト

```go
// ✅ チャネルのタイムアウトテスト
func TestChannelTimeout(t *testing.T) {
    ch := make(chan int)

    go func() {
        time.Sleep(time.Millisecond * 500)
        ch <- 42
    }()

    select {
    case val := <-ch:
        assertEqual(t, val, 42)
    case <-time.After(time.Second):
        t.Fatal("timeout waiting for channel")
    }
}

// ✅ 複数値の受信テスト
func TestChannelMultipleValues(t *testing.T) {
    ch := make(chan int, 3)

    go func() {
        ch <- 1
        ch <- 2
        ch <- 3
        close(ch)
    }()

    var results []int
    for val := range ch {
        results = append(results, val)
    }

    expected := []int{1, 2, 3}
    if !reflect.DeepEqual(results, expected) {
        t.Errorf("got %v, want %v", results, expected)
    }
}
```

---

### 7. インテグレーションテスト

#### 環境変数でスキップ制御

```go
// ✅ 環境変数による条件付きテスト実行
func TestDatabaseIntegration(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test in short mode")
    }

    if os.Getenv("INTEGRATION") == "" {
        t.Skip("skipping integration test; set INTEGRATION=1 to run")
    }

    // 実際のDB接続
    db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        t.Fatalf("failed to connect to database: %v", err)
    }
    defer db.Close()

    // テスト実行
    // ...
}
```

**実行方法:**
```bash
# ユニットテストのみ（高速）
go test -short ./...

# インテグレーションテスト含む
INTEGRATION=1 go test ./...
```

---

#### TestMainによるセットアップ/ティアダウン

```go
// ✅ テストスイート全体のセットアップ
func TestMain(m *testing.M) {
    // セットアップ
    fmt.Println("Setting up test environment...")

    if err := setupTestDB(); err != nil {
        fmt.Fprintf(os.Stderr, "failed to setup test database: %v\n", err)
        os.Exit(1)
    }

    // テスト実行
    code := m.Run()

    // ティアダウン
    fmt.Println("Cleaning up test environment...")
    teardownTestDB()

    os.Exit(code)
}

func setupTestDB() error {
    // DBマイグレーション、テストデータ投入等
    return nil
}

func teardownTestDB() {
    // DB削除、リソース解放等
}
```

---

#### t.Cleanup()によるリソース管理

```go
// ✅ テストごとのクリーンアップ
func TestUserRepository(t *testing.T) {
    db := setupTestDB(t)

    // テスト終了時に自動実行
    t.Cleanup(func() {
        db.Close()
        cleanupTestData(db)
    })

    repo := NewUserRepository(db)

    // テスト実行
    user := &User{Name: "Alice", Email: "alice@example.com"}
    err := repo.Create(user)
    assertNoError(t, err)

    // 検証
    found, err := repo.FindByEmail("alice@example.com")
    assertNoError(t, err)
    assertEqual(t, found.Name, "Alice")
}

func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()

    db, err := sql.Open("postgres", "postgres://localhost/test?sslmode=disable")
    if err != nil {
        t.Fatalf("failed to connect: %v", err)
    }

    return db
}

func cleanupTestData(db *sql.DB) {
    db.Exec("TRUNCATE users CASCADE")
}
```

---

#### testcontainers-goによるコンテナ化テスト

```go
import (
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/wait"
)

// ✅ PostgreSQLコンテナでテスト
func TestWithPostgres(t *testing.T) {
    ctx := context.Background()

    // PostgreSQLコンテナ起動
    req := testcontainers.ContainerRequest{
        Image:        "postgres:15",
        ExposedPorts: []string{"5432/tcp"},
        Env: map[string]string{
            "POSTGRES_PASSWORD": "password",
            "POSTGRES_DB":       "testdb",
        },
        WaitingFor: wait.ForListeningPort("5432/tcp"),
    }

    container, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
        ContainerRequest: req,
        Started:          true,
    })
    if err != nil {
        t.Fatalf("failed to start container: %v", err)
    }

    defer container.Terminate(ctx)

    // 接続情報取得
    host, _ := container.Host(ctx)
    port, _ := container.MappedPort(ctx, "5432")

    dsn := fmt.Sprintf("host=%s port=%s user=postgres password=password dbname=testdb sslmode=disable",
        host, port.Port())

    db, err := sql.Open("postgres", dsn)
    if err != nil {
        t.Fatalf("failed to connect: %v", err)
    }
    defer db.Close()

    // テスト実行
    // ...
}
```

---

## Part 3: リファクタリング戦略

### 8. シンプルさのためのリファクタリング

#### リファクタリング 1: Extract Function（関数抽出）

巨大関数を小さな責任単位に分割。

```go
// ❌ Before: 巨大レポート生成関数
func generateReport(data []DataPoint) (string, error) {
    // ソート
    sort.Slice(data, func(i, j int) bool {
        return data[i].Value > data[j].Value
    })

    // 平均計算
    sum := 0.0
    for _, d := range data {
        sum += d.Value
    }
    mean := sum / float64(len(data))

    // 中央値計算
    var median float64
    if len(data)%2 == 0 {
        median = (data[len(data)/2-1].Value + data[len(data)/2].Value) / 2
    } else {
        median = data[len(data)/2].Value
    }

    // レポート生成
    report := fmt.Sprintf("Data Analysis Report\n")
    report += fmt.Sprintf("====================\n")
    report += fmt.Sprintf("Total points: %d\n", len(data))
    report += fmt.Sprintf("Mean: %.2f\n", mean)
    report += fmt.Sprintf("Median: %.2f\n", median)
    report += fmt.Sprintf("\nTop 5 Values:\n")
    for i := 0; i < 5 && i < len(data); i++ {
        report += fmt.Sprintf("  %d. %.2f (%s)\n", i+1, data[i].Value, data[i].Label)
    }

    return report, nil
}

type DataPoint struct {
    Label string
    Value float64
}
```

```go
// ✅ After: 各責任を分離
func generateReport(data []DataPoint) (string, error) {
    if len(data) == 0 {
        return "", fmt.Errorf("no data to analyze")
    }

    sortDataDescending(data)
    mean := calculateMean(data)
    median := calculateMedian(data)

    return formatReport(data, mean, median), nil
}

func sortDataDescending(data []DataPoint) {
    sort.Slice(data, func(i, j int) bool {
        return data[i].Value > data[j].Value
    })
}

func calculateMean(data []DataPoint) float64 {
    sum := 0.0
    for _, d := range data {
        sum += d.Value
    }
    return sum / float64(len(data))
}

func calculateMedian(data []DataPoint) float64 {
    if len(data)%2 == 0 {
        mid := len(data) / 2
        return (data[mid-1].Value + data[mid].Value) / 2
    }
    return data[len(data)/2].Value
}

func formatReport(data []DataPoint, mean, median float64) string {
    var report strings.Builder

    report.WriteString("Data Analysis Report\n")
    report.WriteString("====================\n")
    fmt.Fprintf(&report, "Total points: %d\n", len(data))
    fmt.Fprintf(&report, "Mean: %.2f\n", mean)
    fmt.Fprintf(&report, "Median: %.2f\n", median)

    report.WriteString("\nTop 5 Values:\n")
    for i := 0; i < 5 && i < len(data); i++ {
        fmt.Fprintf(&report, "  %d. %.2f (%s)\n", i+1, data[i].Value, data[i].Label)
    }

    return report.String()
}
```

**メリット:**
- 各関数が単一責任を持つ
- 個別にテスト可能
- 再利用性の向上

---

#### リファクタリング 2: Replace Conditional with Guard Clause（早期リターン）

ネストを減らし、正常系を明確にする。

```go
// ❌ Before: 深いネスト
func processOrder(order *Order) error {
    if order != nil {
        if order.Items != nil && len(order.Items) > 0 {
            if order.Customer != nil {
                if order.Customer.IsVerified {
                    total := 0.0
                    for _, item := range order.Items {
                        total += item.Price * float64(item.Quantity)
                    }

                    if total > 0 {
                        order.Total = total
                        return nil
                    } else {
                        return fmt.Errorf("order total must be positive")
                    }
                } else {
                    return fmt.Errorf("customer not verified")
                }
            } else {
                return fmt.Errorf("customer is required")
            }
        } else {
            return fmt.Errorf("order must have items")
        }
    } else {
        return fmt.Errorf("order is nil")
    }
}
```

```go
// ✅ After: 早期リターン（Guard Clause）
func processOrder(order *Order) error {
    // 異常系を先に処理
    if order == nil {
        return fmt.Errorf("order is nil")
    }

    if order.Items == nil || len(order.Items) == 0 {
        return fmt.Errorf("order must have items")
    }

    if order.Customer == nil {
        return fmt.Errorf("customer is required")
    }

    if !order.Customer.IsVerified {
        return fmt.Errorf("customer not verified")
    }

    // 正常系処理
    total := calculateOrderTotal(order.Items)

    if total <= 0 {
        return fmt.Errorf("order total must be positive")
    }

    order.Total = total
    return nil
}

func calculateOrderTotal(items []OrderItem) float64 {
    total := 0.0
    for _, item := range items {
        total += item.Price * float64(item.Quantity)
    }
    return total
}
```

**メリット:**
- ネストレベルの削減
- エラー条件が明確
- 正常系の可読性向上

---

#### リファクタリング 3: Introduce Parameter Object（引数の構造体化）

多数の引数を構造体にまとめる。

```go
// ❌ Before: 引数が多すぎる
func createUser(
    firstName string,
    lastName string,
    email string,
    phone string,
    address string,
    city string,
    zipCode string,
    country string,
    birthDate time.Time,
) (*User, error) {
    // バリデーションと処理...
}

// 呼び出し側が複雑
user, err := createUser(
    "John",
    "Doe",
    "john@example.com",
    "+1234567890",
    "123 Main St",
    "New York",
    "10001",
    "USA",
    time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
)
```

```go
// ✅ After: 構造体にまとめる
type CreateUserParams struct {
    FirstName string
    LastName  string
    Email     string
    Phone     string
    Address   string
    City      string
    ZipCode   string
    Country   string
    BirthDate time.Time
}

func createUser(params CreateUserParams) (*User, error) {
    // バリデーション
    if err := params.Validate(); err != nil {
        return nil, err
    }

    // 処理...
    user := &User{
        FirstName: params.FirstName,
        LastName:  params.LastName,
        Email:     params.Email,
        // ...
    }

    return user, nil
}

func (p CreateUserParams) Validate() error {
    if p.FirstName == "" {
        return fmt.Errorf("first name is required")
    }
    if !strings.Contains(p.Email, "@") {
        return fmt.Errorf("invalid email")
    }
    // ...
    return nil
}

// 呼び出し側が明確
user, err := createUser(CreateUserParams{
    FirstName: "John",
    LastName:  "Doe",
    Email:     "john@example.com",
    Phone:     "+1234567890",
    Address:   "123 Main St",
    City:      "New York",
    ZipCode:   "10001",
    Country:   "USA",
    BirthDate: time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
})
```

**メリット:**
- 引数順序のミスを防止
- 必須/オプション引数の明確化
- バリデーションロジックの集約
- 拡張性の向上（新規フィールド追加が容易）

---

#### リファクタリング 4: Rename（意図を明確にする命名）

```go
// ❌ Before: 曖昧な命名
func calc(d []float64) float64 {
    s := 0.0
    for _, v := range d {
        s += v
    }
    return s / float64(len(d))
}

func proc(u *User) error {
    if u.e == "" {
        return fmt.Errorf("err")
    }
    return nil
}
```

```go
// ✅ After: 意図が明確な命名
func calculateAverage(values []float64) float64 {
    sum := 0.0
    for _, value := range values {
        sum += value
    }
    return sum / float64(len(values))
}

func validateUser(user *User) error {
    if user.Email == "" {
        return fmt.Errorf("email is required")
    }
    return nil
}
```

**命名ガイドライン:**
- 変数: 名詞（`user`, `orderTotal`, `maxRetries`）
- 関数: 動詞+名詞（`calculateTotal`, `validateInput`, `sendEmail`）
- Bool: is/has/can（`isValid`, `hasPermission`, `canDelete`）
- 定数: 全て大文字スネークケース（`MAX_RETRY_COUNT`, `DEFAULT_TIMEOUT`）

---

### 9. コード品質ツール

Goエコシステムの品質ツールを活用し、自動化された品質保証を実現。

| ツール | 用途 | 実行コマンド |
|-------|------|-------------|
| **gofmt** | コードフォーマット（必須） | `gofmt -w .` |
| **goimports** | import自動整理 | `goimports -w .` |
| **go vet** | 疑わしい構文の検出 | `go vet ./...` |
| **golint** | スタイルチェック | `golint ./...` |
| **golangci-lint** | 複数linterの統合実行 | `golangci-lint run` |
| **go test -race** | race condition検出 | `go test -race ./...` |
| **go test -cover** | カバレッジ計測 | `go test -cover ./...` |
| **staticcheck** | 静的解析 | `staticcheck ./...` |

---

#### golangci-lintの設定例

`.golangci.yml`:
```yaml
linters:
  enable:
    - gofmt
    - goimports
    - govet
    - staticcheck
    - errcheck
    - gosimple
    - ineffassign
    - unused
    - misspell
    - gocyclo  # 循環的複雑度
    - dupl     # 重複コード検出

linters-settings:
  gocyclo:
    min-complexity: 15  # 関数の複雑度上限

  dupl:
    threshold: 100  # 重複行数閾値

issues:
  exclude-rules:
    - path: _test\.go
      linters:
        - gocyclo  # テストコードは複雑度チェック除外
```

**CI/CDでの実行:**
```bash
# 全チェック実行
golangci-lint run --timeout 5m

# 新規追加コードのみチェック
golangci-lint run --new-from-rev=origin/main
```

---

#### カバレッジレポート生成

```bash
# カバレッジ計測
go test -coverprofile=coverage.out ./...

# HTML形式で表示
go tool cover -html=coverage.out -o coverage.html

# カバレッジ率表示
go tool cover -func=coverage.out

# 出力例:
# github.com/example/pkg/user/user.go:10:  CreateUser    100.0%
# github.com/example/pkg/user/user.go:25:  ValidateUser   85.7%
# total:                                    (statements)   92.3%
```

---

### 10. コードレビューのベストプラクティス

#### PRサイズの原則

| サイズ | 行数 | 推奨度 | レビュー時間 |
|-------|-----|--------|------------|
| **Small** | ~100行 | ✅ 最適 | 5-10分 |
| **Medium** | 100-300行 | ⚠️ 許容 | 15-30分 |
| **Large** | 300-500行 | ❌ 分割推奨 | 30-60分 |
| **Huge** | 500行以上 | 🚫 絶対分割 | 60分以上 |

**小さなPRの利点:**
- レビュー品質の向上
- マージまでの時間短縮
- コンフリクトリスク低減
- ロールバック容易

---

#### PRのチェックリスト

**コード品質:**
- [ ] gofmt/goimportsでフォーマット済み
- [ ] go vet でエラーなし
- [ ] golangci-lint でエラーなし
- [ ] 不要なコメントアウトコード削除
- [ ] TODOコメントにIssue番号付与

**テスト:**
- [ ] 新規コードに対応するテスト追加
- [ ] 既存テストが全てパス
- [ ] go test -race でdata race検出なし
- [ ] カバレッジ80%以上維持

**エラーハンドリング:**
- [ ] 全てのエラーを適切に処理
- [ ] エラーメッセージが具体的
- [ ] contextによるキャンセル対応
- [ ] goroutineリーク対策済み

**ドキュメント:**
- [ ] 公開関数にGoDocコメント
- [ ] README更新（API変更時）
- [ ] CHANGELOG更新（機能追加時）

---

#### レビュー時の着眼点

**アーキテクチャ:**
- [ ] 適切な責任分離（単一責任原則）
- [ ] インターフェース活用（依存性逆転）
- [ ] 適切な抽象化レベル

**パフォーマンス:**
- [ ] 不要なメモリアロケーション
- [ ] ループ内での非効率な処理
- [ ] 適切な並行処理の活用

**セキュリティ:**
- [ ] 外部入力のバリデーション
- [ ] SQLインジェクション対策
- [ ] 機密情報のハードコード禁止

**可読性:**
- [ ] 意図が明確な命名
- [ ] 適切なコメント（なぜを説明）
- [ ] 深いネストの回避

---

#### フィードバックの例

**❌ 悪い例:**
```
このコードはダメです。
```

**✅ 良い例:**
```
この関数は複数の責任を持っているようです。
以下のように分割することで、テスト容易性と再利用性が向上します：

1. バリデーション処理を validateInput() に分離
2. DB処理を saveToDatabase() に分離
3. 通知処理を sendNotification() に分離

参考: Clean Architecture, Chapter 7
```

---

## まとめ

### クリーンな並行処理の要点
- Worker Pool、Fan-out/Fan-in、セマフォパターンを適切に選択
- contextでキャンセル・タイムアウト管理
- goroutineリーク・デッドロック・race conditionを回避

### クリーンなテストの要点
- テーブル駆動テストで構造化
- インターフェースとモックで依存を分離
- go test -race で並行処理の安全性を検証

### リファクタリングの要点
- Extract Function、Guard Clause、Parameter Objectで可読性向上
- golangci-lint等のツールで自動品質保証
- 小さなPR、明確なレビューで品質維持

**継続的な改善がクリーンなGoコードを生み出す。**
