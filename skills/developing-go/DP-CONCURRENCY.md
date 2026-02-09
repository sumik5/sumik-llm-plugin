# Go並行処理パターン

Goにおける並行処理の代表的なパターンとベストプラクティスを解説します。

---

## 0. Go並行処理の基礎

### goroutine
軽量スレッド。OSスレッドより低コストで数千〜数万個を同時実行可能。

```go
go func() {
    fmt.Println("Hello from goroutine")
}()
```

### channel
goroutine間の通信とデータ共有に使用。

```go
// unbuffered channel
ch := make(chan int)

// buffered channel
ch := make(chan int, 10)

// send
ch <- 42

// receive
value := <-ch

// close
close(ch)
```

### select
複数のchannel操作を待機。

```go
select {
case msg := <-ch1:
    fmt.Println("Received from ch1:", msg)
case msg := <-ch2:
    fmt.Println("Received from ch2:", msg)
case <-time.After(time.Second):
    fmt.Println("Timeout")
}
```

### sync パッケージ
低レベルな同期プリミティブを提供。

| 型 | 用途 |
|---|------|
| `sync.Mutex` | 排他ロック |
| `sync.RWMutex` | 読み書きロック（複数reader、単一writer） |
| `sync.WaitGroup` | goroutineの完了待機 |
| `sync.Once` | 1回だけの実行を保証 |
| `sync.Pool` | 一時オブジェクトのプール |

### context
キャンセルとタイムアウトの伝播。

```go
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

ctx, cancel := context.WithCancel(context.Background())
defer cancel()
```

---

## 1. Producer-Consumer パターン

### 目的
データ生産と消費を分離し、非同期処理を実現する。

### 実装例

```go
package main

import (
    "fmt"
    "time"
)

func producer(ch chan<- int) {
    for i := 0; i < 10; i++ {
        ch <- i
        time.Sleep(100 * time.Millisecond)
    }
    close(ch) // producerがcloseする
}

func consumer(ch <-chan int, done chan<- bool) {
    for val := range ch {
        fmt.Println("Consumed:", val)
    }
    done <- true
}

func main() {
    ch := make(chan int, 5) // buffered channel
    done := make(chan bool)

    go producer(ch)
    go consumer(ch, done)

    <-done
}
```

### contextによるキャンセル対応

```go
func producer(ctx context.Context, ch chan<- int) {
    defer close(ch)
    for i := 0; ; i++ {
        select {
        case <-ctx.Done():
            return
        case ch <- i:
            time.Sleep(100 * time.Millisecond)
        }
    }
}

func consumer(ctx context.Context, ch <-chan int) {
    for {
        select {
        case <-ctx.Done():
            return
        case val, ok := <-ch:
            if !ok {
                return
            }
            fmt.Println("Consumed:", val)
        }
    }
}

func main() {
    ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
    defer cancel()

    ch := make(chan int, 5)

    go producer(ctx, ch)
    go consumer(ctx, ch)

    <-ctx.Done()
}
```

### ベストプラクティス
- **producerがchannelをclose**: consumerは`range`で安全に読める
- **buffered channelで流量制御**: producer/consumerの速度差を吸収
- **contextでキャンセル可能に**: graceful shutdownを実現

---

## 2. Fan-In / Fan-Out パターン

### Fan-Out（並列処理）
1つの入力を複数のgoroutineで並列処理する。

```go
package main

import (
    "fmt"
    "sync"
)

func worker(id int, jobs <-chan int, results chan<- int) {
    for job := range jobs {
        fmt.Printf("Worker %d processing job %d\n", id, job)
        results <- job * 2
    }
}

func fanOut(input <-chan int, numWorkers int) <-chan int {
    results := make(chan int, numWorkers)
    var wg sync.WaitGroup

    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func(id int) {
            defer wg.Done()
            worker(id, input, results)
        }(i)
    }

    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}
```

### Fan-In（結果集約）
複数のchannelからの出力を1つのchannelに集約する。

```go
func fanIn(channels ...<-chan int) <-chan int {
    var wg sync.WaitGroup
    merged := make(chan int)

    output := func(c <-chan int) {
        defer wg.Done()
        for val := range c {
            merged <- val
        }
    }

    wg.Add(len(channels))
    for _, ch := range channels {
        go output(ch)
    }

    go func() {
        wg.Wait()
        close(merged)
    }()

    return merged
}
```

### 実用例

```go
// 並列API呼び出し
func fetchURLs(urls []string, numWorkers int) <-chan string {
    jobs := make(chan string, len(urls))
    results := make(chan string, len(urls))

    // Fan-Out
    for i := 0; i < numWorkers; i++ {
        go func() {
            for url := range jobs {
                content := fetch(url) // HTTP GET
                results <- content
            }
        }()
    }

    // Feed jobs
    go func() {
        for _, url := range urls {
            jobs <- url
        }
        close(jobs)
    }()

    return results
}
```

### 設計ポイント
- **worker数**: `runtime.NumCPU()` を基準に調整
- **buffered channel**: 結果の取りこぼしを防ぐ
- **WaitGroup**: 全goroutineの完了を待つ

---

## 3. Pipeline パターン

### 目的
データ処理ステージをchannel連鎖で構成し、各ステージを独立させる。

### 基本構造

```go
package main

import "fmt"

// Stage 1: データ生成
func generate(nums ...int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for _, n := range nums {
            out <- n
        }
    }()
    return out
}

// Stage 2: 平方
func square(in <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for n := range in {
            out <- n * n
        }
    }()
    return out
}

// Stage 3: フィルタリング
func filter(in <-chan int, predicate func(int) bool) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for n := range in {
            if predicate(n) {
                out <- n
            }
        }
    }()
    return out
}

func main() {
    // パイプライン構築
    nums := generate(1, 2, 3, 4, 5)
    squared := square(nums)
    filtered := filter(squared, func(n int) bool { return n > 10 })

    // 結果出力
    for result := range filtered {
        fmt.Println(result)
    }
}
```

### contextによるキャンセル伝播

```go
func generate(ctx context.Context, nums ...int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for _, n := range nums {
            select {
            case <-ctx.Done():
                return
            case out <- n:
            }
        }
    }()
    return out
}

func square(ctx context.Context, in <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for n := range in {
            select {
            case <-ctx.Done():
                return
            case out <- n * n:
            }
        }
    }()
    return out
}
```

### 並列化されたPipeline

```go
func squareParallel(ctx context.Context, in <-chan int, numWorkers int) <-chan int {
    var wg sync.WaitGroup
    out := make(chan int)

    worker := func() {
        defer wg.Done()
        for n := range in {
            select {
            case <-ctx.Done():
                return
            case out <- n * n:
            }
        }
    }

    wg.Add(numWorkers)
    for i := 0; i < numWorkers; i++ {
        go worker()
    }

    go func() {
        wg.Wait()
        close(out)
    }()

    return out
}
```

### ベストプラクティス
- **各ステージが独立したgoroutine**: 並列実行可能
- **channelのclose管理**: 各ステージが出力channelをclose
- **contextでキャンセル伝播**: すべてのステージに伝播

---

## 4. Worker Pool パターン

### 目的
固定数のworkerでタスクキューを並列実行する。

### 基本実装

```go
package main

import (
    "fmt"
    "sync"
    "time"
)

func worker(id int, jobs <-chan int, results chan<- int) {
    for job := range jobs {
        fmt.Printf("Worker %d started job %d\n", id, job)
        time.Sleep(time.Second) // 処理のシミュレーション
        results <- job * 2
        fmt.Printf("Worker %d finished job %d\n", id, job)
    }
}

func workerPool(jobs <-chan int, results chan<- int, numWorkers int) {
    var wg sync.WaitGroup

    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func(id int) {
            defer wg.Done()
            worker(id, jobs, results)
        }(i)
    }

    go func() {
        wg.Wait()
        close(results)
    }()
}

func main() {
    numJobs := 10
    numWorkers := 3

    jobs := make(chan int, numJobs)
    results := make(chan int, numJobs)

    // Worker poolを起動
    workerPool(jobs, results, numWorkers)

    // ジョブを投入
    for i := 1; i <= numJobs; i++ {
        jobs <- i
    }
    close(jobs)

    // 結果を収集
    for result := range results {
        fmt.Println("Result:", result)
    }
}
```

### contextによるキャンセル

```go
func worker(ctx context.Context, id int, jobs <-chan int, results chan<- int) {
    for {
        select {
        case <-ctx.Done():
            fmt.Printf("Worker %d stopped\n", id)
            return
        case job, ok := <-jobs:
            if !ok {
                return
            }
            fmt.Printf("Worker %d processing job %d\n", id, job)
            results <- job * 2
        }
    }
}

func main() {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    numWorkers := 3
    jobs := make(chan int, 10)
    results := make(chan int, 10)

    var wg sync.WaitGroup
    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func(id int) {
            defer wg.Done()
            worker(ctx, id, jobs, results)
        }(i)
    }

    go func() {
        for i := 1; i <= 20; i++ {
            select {
            case <-ctx.Done():
                close(jobs)
                return
            case jobs <- i:
            }
        }
        close(jobs)
    }()

    go func() {
        wg.Wait()
        close(results)
    }()

    for result := range results {
        fmt.Println("Result:", result)
    }
}
```

### 設計ポイント

| 要素 | 考慮点 |
|------|--------|
| **worker数** | `runtime.NumCPU()` を基準に、I/O待ちならCPU数より多めに |
| **jobs channelサイズ** | タスク量に応じて調整。大きすぎるとメモリ消費増 |
| **graceful shutdown** | contextでキャンセル、WaitGroupで完了待機 |
| **エラーハンドリング** | `errgroup` を使用（後述） |

### errgroup による実装

```go
import (
    "context"
    "fmt"
    "golang.org/x/sync/errgroup"
)

func processWithErrgroup(ctx context.Context, jobs []int) error {
    g, ctx := errgroup.WithContext(ctx)
    numWorkers := 3
    jobChan := make(chan int, len(jobs))

    // ジョブを投入
    for _, job := range jobs {
        jobChan <- job
    }
    close(jobChan)

    // Workers
    for i := 0; i < numWorkers; i++ {
        g.Go(func() error {
            for job := range jobChan {
                if err := processJob(ctx, job); err != nil {
                    return err // 最初のエラーで全worker停止
                }
            }
            return nil
        })
    }

    return g.Wait()
}

func processJob(ctx context.Context, job int) error {
    select {
    case <-ctx.Done():
        return ctx.Err()
    default:
        fmt.Println("Processing job:", job)
        return nil
    }
}
```

---

## 5. Circuit Breaker パターン

### 目的
外部サービスの障害がシステム全体に伝播するのを防ぎ、回復力を高める。

### 3つの状態

| 状態 | 説明 |
|------|------|
| **Closed** | 正常動作。リクエストをそのまま通す |
| **Open** | 障害検知。すべてのリクエストを即座に失敗させる |
| **Half-Open** | 回復テスト。一部リクエストを通して状態を確認 |

### 状態遷移

```
Closed ─[閾値超過]→ Open ─[タイムアウト]→ Half-Open
  ↑                                          │
  └──────────────[成功]─────────────────────┘
           [失敗] → Open
```

### 実装例

```go
package main

import (
    "fmt"
    "sync"
    "time"
)

type State string

const (
    StateClosed   State = "closed"
    StateOpen     State = "open"
    StateHalfOpen State = "half-open"
)

type CircuitBreaker struct {
    mu            sync.Mutex
    state         State
    failureCount  int
    successCount  int
    threshold     int
    timeout       time.Duration
    lastFailure   time.Time
}

func NewCircuitBreaker(threshold int, timeout time.Duration) *CircuitBreaker {
    return &CircuitBreaker{
        state:     StateClosed,
        threshold: threshold,
        timeout:   timeout,
    }
}

func (cb *CircuitBreaker) Execute(action func() error) error {
    cb.mu.Lock()
    defer cb.mu.Unlock()

    // Open状態: タイムアウト後にHalf-Openへ
    if cb.state == StateOpen {
        if time.Since(cb.lastFailure) > cb.timeout {
            cb.state = StateHalfOpen
            cb.successCount = 0
        } else {
            return fmt.Errorf("circuit breaker is open")
        }
    }

    // アクションを実行
    err := action()

    if err != nil {
        cb.onFailure()
        return err
    }

    cb.onSuccess()
    return nil
}

func (cb *CircuitBreaker) onSuccess() {
    if cb.state == StateHalfOpen {
        cb.successCount++
        if cb.successCount >= cb.threshold {
            cb.state = StateClosed
            cb.failureCount = 0
        }
    } else {
        cb.failureCount = 0
    }
}

func (cb *CircuitBreaker) onFailure() {
    cb.failureCount++
    cb.lastFailure = time.Now()

    if cb.failureCount >= cb.threshold {
        cb.state = StateOpen
    }
}

func (cb *CircuitBreaker) State() State {
    cb.mu.Lock()
    defer cb.mu.Unlock()
    return cb.state
}
```

### 使用例

```go
func main() {
    cb := NewCircuitBreaker(3, 5*time.Second)

    for i := 0; i < 10; i++ {
        err := cb.Execute(func() error {
            // 外部API呼び出しのシミュレーション
            if i < 5 {
                return fmt.Errorf("service unavailable")
            }
            return nil
        })

        fmt.Printf("Attempt %d: state=%s, err=%v\n", i+1, cb.State(), err)
        time.Sleep(time.Second)
    }
}
```

### 実用的な実装（http.Client統合）

```go
import (
    "context"
    "net/http"
    "time"
)

type HTTPCircuitBreaker struct {
    cb     *CircuitBreaker
    client *http.Client
}

func NewHTTPCircuitBreaker(threshold int, timeout time.Duration) *HTTPCircuitBreaker {
    return &HTTPCircuitBreaker{
        cb: NewCircuitBreaker(threshold, timeout),
        client: &http.Client{
            Timeout: 10 * time.Second,
        },
    }
}

func (hcb *HTTPCircuitBreaker) Get(ctx context.Context, url string) (*http.Response, error) {
    var resp *http.Response

    err := hcb.cb.Execute(func() error {
        req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
        if err != nil {
            return err
        }

        resp, err = hcb.client.Do(req)
        if err != nil {
            return err
        }

        if resp.StatusCode >= 500 {
            return fmt.Errorf("server error: %d", resp.StatusCode)
        }

        return nil
    })

    return resp, err
}
```

### サードパーティライブラリ

```go
// github.com/sony/gobreaker
import "github.com/sony/gobreaker"

cb := gobreaker.NewCircuitBreaker(gobreaker.Settings{
    Name:        "MyService",
    MaxRequests: 3,
    Interval:    time.Minute,
    Timeout:     time.Second * 10,
    ReadyToTrip: func(counts gobreaker.Counts) bool {
        return counts.ConsecutiveFailures > 3
    },
})

result, err := cb.Execute(func() (interface{}, error) {
    return callExternalService()
})
```

### 設計ポイント
- **閾値の設定**: サービスの特性に応じて調整（3〜5回が一般的）
- **タイムアウト**: 短すぎると回復前に閉じる（5〜30秒が目安）
- **Half-Open時のテスト**: 少数のリクエストで状態確認
- **メトリクス収集**: Open回数、成功/失敗率を監視

---

## 6. その他の並行処理パターン

### Semaphore（同時実行数の制限）

```go
// buffered channelで実装
type Semaphore chan struct{}

func NewSemaphore(maxConcurrency int) Semaphore {
    return make(Semaphore, maxConcurrency)
}

func (s Semaphore) Acquire() {
    s <- struct{}{}
}

func (s Semaphore) Release() {
    <-s
}

func main() {
    sem := NewSemaphore(3) // 最大3並列
    var wg sync.WaitGroup

    for i := 0; i < 10; i++ {
        wg.Add(1)
        go func(id int) {
            defer wg.Done()
            sem.Acquire()
            defer sem.Release()

            fmt.Printf("Task %d started\n", id)
            time.Sleep(time.Second)
            fmt.Printf("Task %d finished\n", id)
        }(i)
    }

    wg.Wait()
}
```

### Rate Limiter（リクエスト頻度制限）

```go
import "time"

type RateLimiter struct {
    ticker *time.Ticker
    tokens chan struct{}
}

func NewRateLimiter(rate time.Duration, burst int) *RateLimiter {
    rl := &RateLimiter{
        ticker: time.NewTicker(rate),
        tokens: make(chan struct{}, burst),
    }

    // 初期トークン
    for i := 0; i < burst; i++ {
        rl.tokens <- struct{}{}
    }

    // トークンの補充
    go func() {
        for range rl.ticker.C {
            select {
            case rl.tokens <- struct{}{}:
            default:
            }
        }
    }()

    return rl
}

func (rl *RateLimiter) Wait() {
    <-rl.tokens
}

func (rl *RateLimiter) Stop() {
    rl.ticker.Stop()
}
```

### golang.org/x/time/rate

```go
import "golang.org/x/time/rate"

limiter := rate.NewLimiter(10, 5) // 毎秒10リクエスト、バースト5

for i := 0; i < 20; i++ {
    limiter.Wait(context.Background())
    fmt.Println("Request:", i)
}
```

### Context-based Cancellation

```go
func doWork(ctx context.Context) error {
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
            // 作業実行
            time.Sleep(100 * time.Millisecond)
        }
    }
}

func main() {
    ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
    defer cancel()

    if err := doWork(ctx); err != nil {
        fmt.Println("Error:", err)
    }
}
```

### errgroup（goroutineのエラー管理）

```go
import (
    "context"
    "golang.org/x/sync/errgroup"
)

func fetchAll(urls []string) error {
    g, ctx := errgroup.WithContext(context.Background())

    for _, url := range urls {
        url := url // ループ変数のキャプチャ
        g.Go(func() error {
            return fetch(ctx, url)
        })
    }

    return g.Wait() // 最初のエラーで全goroutineキャンセル
}
```

---

## 並行処理アンチパターン

### 1. goroutineリーク

#### 問題
channelを閉じない、または読み取らないため、goroutineが永久に待機する。

```go
// ❌ 悪い例
func leak() {
    ch := make(chan int)
    go func() {
        ch <- 42 // 誰も読まない
    }()
    // goroutineがリークする
}
```

#### 解決策

```go
// ✅ 良い例
func noLeak(ctx context.Context) {
    ch := make(chan int)
    go func() {
        select {
        case ch <- 42:
        case <-ctx.Done():
            return
        }
    }()

    select {
    case val := <-ch:
        fmt.Println(val)
    case <-ctx.Done():
        return
    }
}
```

### 2. データレース

#### 問題
複数のgoroutineが共有状態に無保護でアクセスする。

```go
// ❌ 悪い例
var counter int

func increment() {
    for i := 0; i < 1000; i++ {
        counter++ // データレース
    }
}

func main() {
    go increment()
    go increment()
    time.Sleep(time.Second)
    fmt.Println(counter) // 不定値
}
```

#### 解決策

```go
// ✅ 良い例 (Mutex)
var (
    counter int
    mu      sync.Mutex
)

func increment() {
    for i := 0; i < 1000; i++ {
        mu.Lock()
        counter++
        mu.Unlock()
    }
}

// ✅ 良い例 (channel)
func incrementWithChannel() {
    ch := make(chan int)
    done := make(chan bool)

    // counter goroutine
    go func() {
        count := 0
        for range ch {
            count++
        }
        fmt.Println(count)
        done <- true
    }()

    // senders
    for i := 0; i < 2; i++ {
        go func() {
            for j := 0; j < 1000; j++ {
                ch <- 1
            }
        }()
    }

    time.Sleep(time.Second)
    close(ch)
    <-done
}
```

### 3. デッドロック

#### 問題
循環的なchannel待ちで、全goroutineがブロックする。

```go
// ❌ 悪い例
func deadlock() {
    ch1 := make(chan int)
    ch2 := make(chan int)

    go func() {
        val := <-ch1 // ch1を待つ
        ch2 <- val
    }()

    go func() {
        val := <-ch2 // ch2を待つ
        ch1 <- val
    }()

    time.Sleep(time.Second)
    // デッドロック: 両方とも相手を待っている
}
```

#### 解決策

```go
// ✅ 良い例 (一方向通信)
func noDeadlock() {
    ch1 := make(chan int)
    ch2 := make(chan int)

    go func() {
        ch1 <- 42 // 送信のみ
    }()

    go func() {
        val := <-ch1
        ch2 <- val * 2
    }()

    result := <-ch2
    fmt.Println(result)
}

// ✅ 良い例 (select + timeout)
func noDeadlockWithTimeout() {
    ch := make(chan int)

    select {
    case val := <-ch:
        fmt.Println(val)
    case <-time.After(time.Second):
        fmt.Println("Timeout")
    }
}
```

### 4. 過剰goroutine

#### 問題
制限なしにgoroutineを生成し、リソースを枯渇させる。

```go
// ❌ 悪い例
func tooManyGoroutines(urls []string) {
    for _, url := range urls {
        go fetch(url) // 数万URLなら数万goroutine
    }
}
```

#### 解決策

```go
// ✅ 良い例 (Worker Pool)
func limitedGoroutines(urls []string) {
    numWorkers := 10
    jobs := make(chan string, len(urls))
    var wg sync.WaitGroup

    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for url := range jobs {
                fetch(url)
            }
        }()
    }

    for _, url := range urls {
        jobs <- url
    }
    close(jobs)
    wg.Wait()
}
```

---

## パターン選択ガイド

### 状況別推奨パターン

| 状況 | 推奨パターン | 理由 |
|------|------------|------|
| データ生産・消費の分離 | Producer-Consumer | channelによる自然な非同期処理 |
| 処理の並列分散 | Fan-Out | 複数workerで並列実行 |
| 結果の集約 | Fan-In | 複数sourceを1つに統合 |
| ステージごとのデータ変換 | Pipeline | 各ステージの独立性と再利用性 |
| 固定並列数でのタスク実行 | Worker Pool | リソース消費を制御 |
| 外部サービス障害への耐性 | Circuit Breaker | 障害の伝播を防止 |
| 同時実行数の制限 | Semaphore | リソース保護 |
| リクエスト頻度制限 | Rate Limiter | APIレート制限遵守 |

### 複合パターン例

```go
// Pipeline + Worker Pool + Rate Limiter
func complexPipeline(ctx context.Context, urls []string) <-chan Result {
    limiter := rate.NewLimiter(10, 5) // 毎秒10リクエスト

    // Stage 1: URL生成
    urlChan := generate(ctx, urls...)

    // Stage 2: 並列フェッチ (Worker Pool)
    fetched := fanOut(ctx, urlChan, 5, func(url string) (Result, error) {
        limiter.Wait(ctx) // Rate limiting
        return fetch(url)
    })

    // Stage 3: 結果フィルタリング
    filtered := filter(ctx, fetched, func(r Result) bool {
        return r.StatusCode == 200
    })

    return filtered
}
```

---

## デバッグとテスト

### race detector

```bash
go test -race
go run -race main.go
```

### pprof による goroutine プロファイリング

```go
import (
    "net/http"
    _ "net/http/pprof"
)

func main() {
    go func() {
        http.ListenAndServe("localhost:6060", nil)
    }()

    // アプリケーションコード
}
```

ブラウザで `http://localhost:6060/debug/pprof/goroutine` にアクセス。

### テストパターン

```go
func TestWorkerPool(t *testing.T) {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    jobs := make(chan int, 10)
    results := make(chan int, 10)

    // Worker pool起動
    var wg sync.WaitGroup
    for i := 0; i < 3; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for job := range jobs {
                select {
                case <-ctx.Done():
                    return
                case results <- job * 2:
                }
            }
        }()
    }

    // ジョブ投入
    go func() {
        for i := 0; i < 10; i++ {
            jobs <- i
        }
        close(jobs)
    }()

    // 結果検証
    go func() {
        wg.Wait()
        close(results)
    }()

    count := 0
    for range results {
        count++
    }

    if count != 10 {
        t.Errorf("Expected 10 results, got %d", count)
    }
}
```

---

## ベストプラクティスまとめ

1. **Don't communicate by sharing memory; share memory by communicating** - channelを優先
2. **Always close channels from the sender side** - receiverではなくsenderがclose
3. **Use context for cancellation** - 全goroutineにキャンセルを伝播
4. **Limit goroutine creation** - Worker Pool、Semaphoreで制限
5. **Test with -race flag** - データレースを早期発見
6. **Monitor goroutine leaks** - pprof、metricsで監視
7. **Prefer errgroup for error handling** - 複数goroutineのエラー管理
8. **Document concurrency assumptions** - どのgoroutineがchannelをcloseするか明記
