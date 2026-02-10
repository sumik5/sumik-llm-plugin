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
# 追加セクション（DP-CONCURRENCY.mdに挿入）

## 拘束（Confinement）パターン

並行処理で安全性を保証する方法の一つが**拘束**。データへのアクセスを1つの並行プロセスのみに制限することで、同期が不要になる。

### アドホック拘束 vs レキシカル拘束

**アドホック拘束**: 規約によって達成する拘束（静的解析ツールなしでは維持困難）。

**レキシカル拘束**: レキシカルスコープによってコンパイラレベルで拘束を強制（推奨）。

```go
// レキシカル拘束の例
chanOwner := func() <-chan int {
    results := make(chan int, 5) // 書き込み権限はこのスコープ内に閉じ込める
    go func() {
        defer close(results)
        for i := 0; i <= 5; i++ {
            results <- i
        }
    }()
    return results // 読み込み専用チャネルとして返す
}

consumer := func(results <-chan int) {
    for result := range results {
        fmt.Printf("Received: %d\n", result)
    }
}

results := chanOwner()
consumer(results)
```

**利点**:
- 同期コストがゼロ（クリティカルセクションが不要）
- 可読性が向上（同期処理の心配が不要）
- コンパイラがアクセス制御を保証

---

## for-selectループパターン

Goの並行処理でもっとも頻出するイディオム。

```go
// パターン1: チャネルから繰り返し送出
for _, s := range []string{"a", "b", "c"} {
    select {
    case <-done:
        return
    case stringStream <- s:
    }
}

// パターン2: 停止シグナルを待つ無限ループ
for {
    select {
    case <-done:
        return
    default:
    }
    // 割り込みできない処理
}

// パターン3: default節を使う形式
for {
    select {
    case <-done:
        return
    default:
        // 割り込みできない処理
    }
}
```

---

## or-channelパターン

複数の`done`チャネルを1つに統合し、いずれか1つが閉じたら統合チャネルも閉じる。

```go
var or func(channels ...<-chan interface{}) <-chan interface{}
or = func(channels ...<-chan interface{}) <-chan interface{} {
    switch len(channels) {
    case 0:
        return nil
    case 1:
        return channels[0]
    }

    orDone := make(chan interface{})
    go func() {
        defer close(orDone)

        switch len(channels) {
        case 2:
            select {
            case <-channels[0]:
            case <-channels[1]:
            }
        default:
            select {
            case <-channels[0]:
            case <-channels[1]:
            case <-channels[2]:
            case <-or(append(channels[3:], orDone)...):
            }
        }
    }()
    return orDone
}

// 使用例
sig := func(after time.Duration) <-chan interface{} {
    c := make(chan interface{})
    go func() {
        defer close(c)
        time.Sleep(after)
    }()
    return c
}

start := time.Now()
<-or(
    sig(2*time.Hour),
    sig(5*time.Minute),
    sig(1*time.Second),
    sig(1*time.Hour),
    sig(1*time.Minute),
)
fmt.Printf("done after %v", time.Since(start)) // 約1秒
```

**利点**: モジュール結合部でキャンセル条件を統合できる。

---

## or-done-channelパターン

外部チャネルのキャンセル対応をカプセル化し、冗長な`select`文を排除。

```go
orDone := func(done, c <-chan interface{}) <-chan interface{} {
    valStream := make(chan interface{})
    go func() {
        defer close(valStream)
        for {
            select {
            case <-done:
                return
            case v, ok := <-c:
                if !ok {
                    return
                }
                select {
                case valStream <- v:
                case <-done:
                }
            }
        }
    }()
    return valStream
}

// 使用例: シンプルなfor-rangeに戻せる
for val := range orDone(done, myChan) {
    // valに対して処理
}
```

---

## tee-channelパターン

1つのストリームを2つに分岐（Unixの`tee`コマンドに由来）。

```go
tee := func(
    done <-chan interface{},
    in <-chan interface{},
) (_, _ <-chan interface{}) {
    out1 := make(chan interface{})
    out2 := make(chan interface{})
    go func() {
        defer close(out1)
        defer close(out2)
        for val := range orDone(done, in) {
            var out1, out2 = out1, out2
            for i := 0; i < 2; i++ {
                select {
                case out1 <- val:
                    out1 = nil
                case out2 <- val:
                    out2 = nil
                }
            }
        }
    }()
    return out1, out2
}

// 使用例
out1, out2 := tee(done, take(done, repeat(done, 1, 2), 4))
for val1 := range out1 {
    fmt.Printf("out1: %v, out2: %v\n", val1, <-out2)
}
```

---

## bridge-channelパターン

チャネルのシーケンス（チャネルのチャネル）を単一チャネルに変換。

```go
bridge := func(
    done <-chan interface{},
    chanStream <-chan <-chan interface{},
) <-chan interface{} {
    valStream := make(chan interface{})
    go func() {
        defer close(valStream)
        for {
            var stream <-chan interface{}
            select {
            case maybeStream, ok := <-chanStream:
                if !ok {
                    return
                }
                stream = maybeStream
            case <-done:
                return
            }
            for val := range orDone(done, stream) {
                select {
                case valStream <- val:
                case <-done:
                }
            }
        }
    }()
    return valStream
}

// 使用例: 10個のチャネルを順次消費
genVals := func() <-chan <-chan interface{} {
    chanStream := make(chan (<-chan interface{}))
    go func() {
        defer close(chanStream)
        for i := 0; i < 10; i++ {
            stream := make(chan interface{}, 1)
            stream <- i
            close(stream)
            chanStream <- stream
        }
    }()
    return chanStream
}

for v := range bridge(nil, genVals()) {
    fmt.Printf("%v ", v)
}
```

**適用例**: 寿命が断続的なパイプラインステージ（再起動するgoroutineごとに新しいチャネルが作られる場合）。

---

## キューイング戦略

パイプラインにバッファ（キュー）を導入する効果と注意点。

### キューイングが有効なケース

1. **バッチ処理が時間を節約する場合**:
   - 例: メモリ（高速）→ディスク（低速）のバッファリング
   - `bufio.Writer`の性能向上

2. **遅延がフィードバックループを生む場合**:
   - システム飽和時にリクエストをキューに保存
   - データが古くなる前に処理可能な場合

### 注意点

- **キューはパイプライン全体の実行時間を短縮しない**
- キューは**ステージのブロック時間を短縮**し、各ステージを独立させる
- 早すぎるキューイングはデッドロック/ライブロックを隠蔽する
- 最適化の最終段階で導入すべき

### チャンキング（Chunking）

キューのバッファサイズを調整してパフォーマンスを最適化。

```go
// 例: バッファサイズ100でチャンクを分割
buffer := func(done <-chan interface{}, in <-chan int, size int) <-chan int {
    out := make(chan int, size)
    go func() {
        defer close(out)
        for v := range in {
            select {
            case <-done:
                return
            case out <- v:
            }
        }
    }()
    return out
}
```

### リトルの法則

キューサイズとスループットの関係を定量化する法則。

```
L = λ × W
```

- **L**: システム内の平均リクエスト数
- **λ**: 単位時間あたりの到着率
- **W**: リクエストの平均滞在時間

---

## 並行処理エラーハンドリング

並行プロセスからエラーを適切に伝播する方法。

### Result型パターン

```go
type Result struct {
    Error    error
    Response *http.Response
}

checkStatus := func(done <-chan interface{}, urls ...string) <-chan Result {
    results := make(chan Result)
    go func() {
        defer close(results)
        for _, url := range urls {
            var result Result
            resp, err := http.Get(url)
            result = Result{Error: err, Response: resp}
            select {
            case <-done:
                return
            case results <- result:
            }
        }
    }()
    return results
}

// 使用例: エラーを呼び出し元で判断
for result := range checkStatus(done, urls...) {
    if result.Error != nil {
        fmt.Printf("error: %v\n", result.Error)
        errCount++
        if errCount >= 3 {
            fmt.Println("Too many errors, breaking!")
            break
        }
        continue
    }
    fmt.Printf("Response: %v\n", result.Response.Status)
}
```

**原則**: エラーは値として第一級市民として扱い、正常系と同じ経路で伝播させる。

---

## パイプライン詳細

### ジェネレーター（Generator）

データの塊をチャネル上のストリームに変換する関数。

```go
// repeat: 値を無限に繰り返す
repeat := func(
    done <-chan interface{},
    values ...interface{},
) <-chan interface{} {
    valueStream := make(chan interface{})
    go func() {
        defer close(valueStream)
        for {
            for _, v := range values {
                select {
                case <-done:
                    return
                case valueStream <- v:
                }
            }
        }
    }()
    return valueStream
}

// repeatFn: 関数を無限に呼び出す
repeatFn := func(
    done <-chan interface{},
    fn func() interface{},
) <-chan interface{} {
    valueStream := make(chan interface{})
    go func() {
        defer close(valueStream)
        for {
            select {
            case <-done:
                return
            case valueStream <- fn():
            }
        }
    }()
    return valueStream
}

// take: 最初のnum個だけを取得
take := func(
    done <-chan interface{},
    valueStream <-chan interface{},
    num int,
) <-chan interface{} {
    takeStream := make(chan interface{})
    go func() {
        defer close(takeStream)
        for i := 0; i < num; i++ {
            select {
            case <-done:
                return
            case takeStream <- <-valueStream:
            }
        }
    }()
    return takeStream
}

// 使用例: 無限ストリームから10個だけ取得
for num := range take(done, repeat(done, 1), 10) {
    fmt.Printf("%v ", num)
}
```

### ステージ所有権

パイプラインの各ステージは以下の責任を持つ：

1. **チャネル所有者**: チャネルを初期化・書き込み・クローズする
2. **チャネル消費者**: 読み込み専用チャネルから値を受け取る

```go
// 所有者: 書き込み権限を持つ
producer := func(done <-chan interface{}) <-chan int {
    ch := make(chan int)
    go func() {
        defer close(ch) // 所有者のみがクローズ
        for i := 0; i < 10; i++ {
            select {
            case <-done:
                return
            case ch <- i:
            }
        }
    }()
    return ch // 読み込み専用として公開
}

// 消費者: 読み込み専用チャネルを受け取る
consumer := func(done <-chan interface{}, in <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for v := range in {
            select {
            case <-done:
                return
            case out <- v * 2:
            }
        }
    }()
    return out
}
```

### doneチャネルによるキャンセル伝播

パイプライン全体に`done`チャネルを渡すことで、いずれかのステージでキャンセルが発生すると全体が終了する。

```go
done := make(chan interface{})
defer close(done)

intStream := generator(done, 1, 2, 3, 4)
pipeline := multiply(done, add(done, multiply(done, intStream, 2), 1), 2)

for v := range pipeline {
    fmt.Println(v)
}
```

**割り込み可能性の保証**:
- パイプライン先頭: 生成処理とチャネル送信が`done`に対応
- パイプライン末尾: `range`ループにより自動的に割り込み可能
- パイプライン中間: `select`文で`done`を確認

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
