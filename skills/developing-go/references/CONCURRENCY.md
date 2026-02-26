# Go並行処理

## 設計哲学

> "Do not communicate by sharing memory; instead, share memory by communicating."
> （メモリを共有して通信するのではなく、通信によってメモリを共有せよ）

---

## 並行処理の理論的基礎

### 並行性 vs 並列性

- **並行性（Concurrency）**: コードの性質（構造）
  - プログラムが複数の独立したタスクを扱うように設計されている
  - 例: `go func()` でgoroutineを起動するコード
- **並列性（Parallelism）**: 実行時の性質（動作）
  - 複数のタスクが物理的に同時に実行される
  - 例: 2コアCPUで2つのgoroutineが実際に同時実行

```go
// 並行なコード（goroutineを2つ起動）
go task1()
go task2()

// 実際の動作:
// - 1コアCPU: 並行だが並列ではない（高速切り替えで擬似的に同時実行）
// - 2コアCPU: 並行かつ並列（物理的に同時実行）
```

**重要**: 並行なコードを書くことで、ランタイムが並列実行を自動的に最適化する。

### アトミック性のコンテキスト依存性

「アトミック（不可分）」は**コンテキストによって異なる**：

```go
i++  // 単純な1行に見えるが...

// マシンレベルでは3操作に分解:
// 1. メモリからiの値を読み込む
// 2. 値を1増やす
// 3. 結果をメモリに書き戻す

// コンテキスト別のアトミック性:
// - プログラム内（並行なし）: アトミック
// - goroutine境界: 非アトミック（競合状態の可能性）
// - CPUレベル: 非アトミック（3つの命令）
```

アトミック性を強制する方法：

```go
// 1. sync/atomic パッケージ
var counter int64
atomic.AddInt64(&counter, 1)  // ハードウェアレベルでアトミック

// 2. Mutex
var mu sync.Mutex
var counter int
mu.Lock()
counter++  // Mutexで保護されたクリティカルセクション内はアトミック
mu.Unlock()

// 3. チャネル
counterCh := make(chan int)
go func() {
    count := 0
    for range counterCh {
        count++  // 単一goroutine内で実行されるためアトミック
    }
}()
```

### Coffman条件（デッドロック発生の4条件）

デッドロックが発生するには**4つの条件すべて**が満たされる必要がある：

1. **相互排他（Mutual Exclusion）**: リソースに対する排他的アクセス
2. **条件待ち（Hold and Wait）**: リソース保持しながら追加リソースを待つ
3. **横取り不可（No Preemption）**: リソースは保持者のみが解放可能
4. **循環待ち（Circular Wait）**: プロセスが循環的に他を待つ

```go
// デッドロックの例
var mu1, mu2 sync.Mutex

// Goroutine 1
mu1.Lock()
mu2.Lock()  // ← Goroutine 2が保持 → 待機
// ...
mu2.Unlock()
mu1.Unlock()

// Goroutine 2
mu2.Lock()
mu1.Lock()  // ← Goroutine 1が保持 → 待機
// ...
mu1.Unlock()
mu2.Unlock()

// → 循環待ち発生（デッドロック）
```

**予防戦略**（4条件のうち1つを崩す）：

```go
// 1. 相互排他を排除: sync.RWMutex（読み取りは並行可能）
var mu sync.RWMutex
mu.RLock()  // 複数のgoroutineが同時に読み取り可能
defer mu.RUnlock()

// 2. 条件待ちを排除: 必要なリソースを一度に取得
func acquire(mu1, mu2 *sync.Mutex) {
    mu1.Lock()
    mu2.Lock()  // すべて取得してから処理開始
}

// 3. 横取り可能に: context.WithTimeout
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()
// タイムアウトで強制解放

// 4. 循環待ちを排除: ロックの順序を統一
var mu1, mu2 sync.Mutex

// すべてのgoroutineで同じ順序でロック
mu1.Lock()
mu2.Lock()
// ...
mu2.Unlock()
mu1.Unlock()
```

### ライブロック

**デッドロックとの違い**：
- デッドロック: すべてのプロセスが**停止**
- ライブロック: プロセスは**動作しているが進展なし**

```go
// ライブロックの例（廊下のすれ違い）
type Person struct {
    name string
    left bool  // 左に避けているか
}

func (p *Person) passBy(other *Person) {
    for {
        if p.left == other.left {
            // 両者が同じ方向に避けている → 衝突
            p.left = !p.left  // 方向を変える
            time.Sleep(time.Millisecond)
        } else {
            // すれ違い成功
            break
        }
    }
}

// 問題: 両者が同じタイミングで方向を変え続ける
```

**対策**: ランダムなバックオフ、優先順位付け、調整役の導入

```go
// ランダムバックオフで解決
func (p *Person) passBy(other *Person) {
    for {
        if p.left == other.left {
            p.left = !p.left
            time.Sleep(time.Duration(rand.Intn(100)) * time.Millisecond)  // ランダム待機
        } else {
            break
        }
    }
}
```

### リソース枯渇

並行プロセスが必要なリソースを取得できない状態：

```go
// 貪欲なgoroutine
go func() {
    for {
        mu.Lock()
        time.Sleep(3 * time.Nanosecond)  // ロックを長時間保持
        mu.Unlock()
    }
}()

// 行儀の良いgoroutine
go func() {
    for {
        mu.Lock()
        time.Sleep(1 * time.Nanosecond)
        mu.Unlock()
        mu.Lock()
        time.Sleep(1 * time.Nanosecond)
        mu.Unlock()
        mu.Lock()
        time.Sleep(1 * time.Nanosecond)
        mu.Unlock()
    }
}()

// → 貪欲なgoroutineが約2倍の処理量を達成（不公平）
```

**検出方法**: 計測（メトリクス、ログ）で各goroutineの処理速度を監視

### CSP理論（Tony Hoare, 1978）

Communicating Sequential Processes - Goの並行処理モデルの基礎：

- **プロセス**: 独立した計算単位（Goでは goroutine）
- **通信コマンド**:
  - `!` 送信（Goでは `ch <- value`）
  - `?` 受信（Goでは `<-ch`）
- **ガード付きコマンド**: 条件付き実行（Goでは `select`）

```go
// CSPの影響を受けたGoのコード
ch1 := make(chan int)
ch2 := make(chan int)

// プロセス1: 送信
go func() {
    ch1 <- 42  // "ch1!42" in CSP
}()

// プロセス2: 受信とガード付き実行
select {
case val := <-ch1:  // "ch1?val" in CSP
    fmt.Println(val)
case val := <-ch2:
    fmt.Println(val)
default:  // ガード: どのチャネルも準備できていない場合
    fmt.Println("no value")
}
```

---

## CSP vs Mutex 決定木

チャネル（CSP）とMutex、どちらを使うべきか：

```
┌─────────────────────────────────────┐
│ データの所有権を移動する？          │
└──────┬──────────────────────────────┘
       │
       ├─ Yes → チャネル
       │        （例: ワーカープールにタスクを送信）
       │
       └─ No
          │
          └─ 構造体の内部状態を保護？
             │
             ├─ Yes → Mutex
             │        （例: Counterのvalue フィールド）
             │
             └─ No
                │
                └─ 複数のロジックを協調？
                   │
                   ├─ Yes → チャネル
                   │        （例: select で複数チャネルを待機）
                   │
                   └─ パフォーマンスクリティカル？
                      │
                      ├─ Yes → Mutex
                      │        （プロファイル結果に基づいて決定）
                      │
                      └─ No → チャネル（デフォルト）
```

### データ所有権移動 → チャネル

```go
// 生産者-消費者パターン
func producer(out chan<- int) {
    for i := 0; i < 10; i++ {
        out <- i  // 所有権を消費者に移動
    }
    close(out)
}

func consumer(in <-chan int) {
    for val := range in {
        process(val)  // 所有権を受け取って処理
    }
}
```

### 内部状態保護 → Mutex

```go
type Counter struct {
    mu    sync.Mutex
    value int  // 内部状態
}

func (c *Counter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.value++  // 保護されたクリティカルセクション
}
```

### 複数ロジック協調 → チャネル

```go
func worker(ctx context.Context, tasks <-chan Task, results chan<- Result) {
    for {
        select {
        case <-ctx.Done():
            return
        case task := <-tasks:
            results <- process(task)
        case <-time.After(5 * time.Second):
            log.Println("no tasks for 5 seconds")
        }
    }
}
```

### パフォーマンスクリティカル → Mutex

チャネルは内部でMutexを使うため、プロファイル結果でボトルネックなら直接Mutexを使う：

```go
// Before: チャネルでカウンター（遅い）
counterCh := make(chan int)
go func() {
    count := 0
    for range counterCh {
        count++
    }
}()

// After: Mutexで直接保護（速い）
var mu sync.Mutex
var count int

mu.Lock()
count++
mu.Unlock()
```

---

## sync.Cond

`sync.Cond`は**複数のgoroutineに効率的にブロードキャスト**する用途で、チャネルでは実現困難な機能を提供。

### Wait/Signal/Broadcastの使い分け

```go
type Cond struct {
    L Locker  // 通常は *sync.Mutex
}

// Wait(): 条件が満たされるまで待機
// Signal(): 1つのgoroutineを起こす
// Broadcast(): すべての待機goroutineを起こす
```

### チャネルとの比較

| 機能 | sync.Cond | チャネル |
|-----|-----------|---------|
| 1対1通知 | `Signal()` | `ch <- value` |
| 1対多通知 | `Broadcast()` | 困難（各goroutine用のチャネルが必要） |
| 繰り返し通知 | 容易（何度でも`Broadcast()`可能） | 困難（closeは1回のみ） |
| メモリ効率 | 高い | 通知ごとにチャネル作成で非効率 |

### 使用例: イベントリスナー

```go
type Button struct {
    mu      sync.Mutex
    clicked *sync.Cond
}

func NewButton() *Button {
    b := &Button{}
    b.clicked = sync.NewCond(&b.mu)
    return b
}

// イベントリスナーを登録
func (b *Button) OnClick(handler func()) {
    go func() {
        b.clicked.L.Lock()
        defer b.clicked.L.Unlock()

        b.clicked.Wait()  // クリックを待機
        handler()         // ハンドラー実行
    }()
}

// クリックイベントを発火
func (b *Button) Click() {
    b.clicked.Broadcast()  // すべてのリスナーに通知
}

// 使用例
button := NewButton()
button.OnClick(func() { fmt.Println("Handler 1") })
button.OnClick(func() { fmt.Println("Handler 2") })
button.OnClick(func() { fmt.Println("Handler 3") })

button.Click()
// 出力: Handler 1, Handler 2, Handler 3（すべてが実行される）

button.Click()  // 2回目のクリックも可能
```

### キューイングパターン

```go
type Queue struct {
    mu    sync.Mutex
    cond  *sync.Cond
    items []interface{}
    max   int
}

func NewQueue(max int) *Queue {
    q := &Queue{max: max}
    q.cond = sync.NewCond(&q.mu)
    return q
}

func (q *Queue) Enqueue(item interface{}) {
    q.mu.Lock()
    defer q.mu.Unlock()

    for len(q.items) == q.max {
        q.cond.Wait()  // キューが満杯なら待機
    }

    q.items = append(q.items, item)
    q.cond.Signal()  // 1つの待機中のDequeue()を起こす
}

func (q *Queue) Dequeue() interface{} {
    q.mu.Lock()
    defer q.mu.Unlock()

    for len(q.items) == 0 {
        q.cond.Wait()  // キューが空なら待機
    }

    item := q.items[0]
    q.items = q.items[1:]
    q.cond.Signal()  // 1つの待機中のEnqueue()を起こす
    return item
}
```

---

## チャネル所有権パターン

チャネルの**初期化・書き込み・クローズ**の責任を明確化する設計原則。

### 所有権の原則

```go
// ルール:
// 1. チャネルを初期化したgoroutineが所有者
// 2. 所有者だけが書き込みとクローズを行う
// 3. 消費者（非所有者）は読み取りのみ

// Good: 所有権が明確
func producer() <-chan int {  // 読み取り専用を返す（呼び出し側は書き込めない）
    ch := make(chan int)  // 所有者: この関数
    go func() {
        defer close(ch)  // 所有者がクローズ
        for i := 0; i < 10; i++ {
            ch <- i  // 所有者が書き込み
        }
    }()
    return ch
}

func consumer(in <-chan int) {  // 読み取り専用を受け取る
    for val := range in {  // 読み取りのみ
        fmt.Println(val)
    }
}
```

### 単方向チャネルによる責任明確化

```go
// 型システムで所有権を強制
type Producer struct{}

func (p *Producer) Produce() <-chan int {  // 送信専用を返せない（コンパイルエラー防止）
    ch := make(chan int)
    go func() {
        defer close(ch)
        for i := 0; i < 10; i++ {
            ch <- i
        }
    }()
    return ch  // chan int を <-chan int に暗黙変換（送信能力を削除）
}

type Consumer struct{}

func (c *Consumer) Consume(in <-chan int) {  // 受信専用を受け取る
    for val := range in {
        fmt.Println(val)
    }
    // in <- 42  // コンパイルエラー: 受信専用チャネルには送信できない
    // close(in) // コンパイルエラー: 受信専用チャネルはクローズできない
}
```

### パターン: or-done-channel

外部チャネルのキャンセル対応をカプセル化：

```go
// チャネル所有者がdoneチャネルを尊重しない場合の対策
func orDone(ctx context.Context, in <-chan interface{}) <-chan interface{} {
    out := make(chan interface{})  // この関数がoutチャネルの所有者

    go func() {
        defer close(out)  // 所有者がクローズ
        for {
            select {
            case <-ctx.Done():
                return
            case val, ok := <-in:
                if !ok {
                    return
                }
                select {
                case out <- val:  // 所有者が書き込み
                case <-ctx.Done():
                    return
                }
            }
        }
    }()

    return out
}

// 使用例
thirdPartyStream := getStreamFromLibrary()  // 外部ライブラリのチャネル（所有権なし）
myStream := orDone(ctx, thirdPartyStream)   // 所有権を持つチャネルに変換

for val := range myStream {  // ctxでキャンセル可能
    process(val)
}
```

### パターン: bridge-channel

チャネルのシーケンスを単一チャネルに統合（所有権の移譲）：

```go
func bridge(ctx context.Context, chanStream <-chan <-chan interface{}) <-chan interface{} {
    out := make(chan interface{})  // bridgeがoutの所有者

    go func() {
        defer close(out)  // 所有者がクローズ

        for {
            var stream <-chan interface{}
            select {
            case <-ctx.Done():
                return
            case maybeStream, ok := <-chanStream:
                if !ok {
                    return
                }
                stream = maybeStream  // 新しいチャネルの所有権を受け取る
            }

            // streamからoutへ転送（所有権の橋渡し）
            for val := range stream {
                select {
                case out <- val:
                case <-ctx.Done():
                    return
                }
            }
        }
    }()

    return out
}

// 使用例
chanStream := make(chan (<-chan interface{}))
go func() {
    defer close(chanStream)
    for i := 0; i < 10; i++ {
        ch := make(chan interface{}, 1)
        ch <- i
        close(ch)
        chanStream <- ch  // 各チャネルの所有権をbridgeに渡す
    }
}()

for val := range bridge(ctx, chanStream) {
    fmt.Println(val)
}
```

---

## 並行処理安全性チェックリスト

並行コードを書く際の必須確認事項：

### 1. 誰が並行処理を担っているか

```go
// 明確な責任分担
func ProcessFiles(files []string) error {
    // ❓ この関数自体がgoroutineを起動するのか、呼び出し側がgoroutineで実行するのか？

    // Good: 関数名とコメントで明示
    // ProcessFilesは内部的にgoroutineを起動する
    // 呼び出し側はブロックされる
}

func ProcessFilesConcurrently(files []string) error {
    // この関数は並行処理を行う
    var wg sync.WaitGroup
    for _, file := range files {
        wg.Add(1)
        go func(f string) {
            defer wg.Done()
            process(f)
        }(file)
    }
    wg.Wait()
    return nil
}

func ProcessFilesAsync(files []string) <-chan error {
    // この関数は非同期で、即座に制御を返す
    errCh := make(chan error, 1)
    go func() {
        defer close(errCh)
        // 処理
    }()
    return errCh
}
```

### 2. 問題空間がどう並行処理プリミティブに対応しているか

```go
// ドメインモデルと並行処理の対応を明確化

// 例: HTTPサーバー
// - 1リクエスト = 1 goroutine（自然な対応）
func handleRequest(w http.ResponseWriter, r *http.Request) {
    // このハンドラーは各リクエストごとにgoroutineで実行される
}

// 例: バッチ処理
// - 1ファイル = 1 タスク = 1 goroutine
func processBatch(files []string) {
    tasks := make(chan string, len(files))
    for _, file := range files {
        tasks <- file  // ファイル → タスク（チャネル）
    }
    close(tasks)

    // ワーカープール（goroutineプール）
    var wg sync.WaitGroup
    for i := 0; i < runtime.NumCPU(); i++ {
        wg.Add(1)
        go worker(&wg, tasks)  // ワーカー goroutine
    }
    wg.Wait()
}
```

### 3. 誰が同期処理を担っているか

```go
// 同期の責任を明確化

// Bad: 同期責任が不明
func Fetch(url string) (*Response, error) {
    // この関数は同期的？非同期的？
    // Mutexで保護されている？チャネルで同期？
}

// Good: 型で同期責任を示す
type Cache struct {
    mu   sync.RWMutex  // Cacheが同期責任を持つことが明確
    data map[string]interface{}
}

func (c *Cache) Get(key string) (interface{}, bool) {
    c.mu.RLock()  // Cacheが同期を担当
    defer c.mu.RUnlock()
    val, ok := c.data[key]
    return val, ok
}

// Good: チャネルで同期責任を外部化
type AsyncCache struct {
    requests chan cacheRequest
}

type cacheRequest struct {
    key      string
    response chan<- interface{}
}

func (c *AsyncCache) Get(key string) <-chan interface{} {
    respCh := make(chan interface{}, 1)
    c.requests <- cacheRequest{key: key, response: respCh}
    return respCh  // チャネルが同期を担当
}
```

### チェックリストのまとめ

| 項目 | 確認内容 | 悪い例 | 良い例 |
|-----|---------|--------|--------|
| **並行処理責任** | 関数内部でgoroutine起動？ | 不明確 | 関数名・コメントで明示 |
| **問題空間の対応** | ドメインモデルとの対応 | 曖昧 | 1リクエスト=1goroutine等 |
| **同期処理責任** | Mutex？チャネル？誰が持つ？ | 型内部で隠蔽 | 型・インターフェースで明示 |

---

## goroutine

### 基本
```go
// goroutineの起動
go func() {
    // 並行処理
}()

// 関数をgoroutineで実行
go process(data)
```

### goroutineの終了管理
```go
// Bad: goroutineがリークする可能性
func serve() {
    go func() {
        for {
            handleRequest()  // 終了条件がない
        }
    }()
}

// Good: contextでキャンセル可能
func serve(ctx context.Context) {
    go func() {
        for {
            select {
            case <-ctx.Done():
                return  // 終了
            default:
                handleRequest()
            }
        }
    }()
}
```

## チャネル

### 基本操作
```go
// 作成
ch := make(chan int)        // バッファなし
ch := make(chan int, 10)    // バッファあり

// 送信
ch <- 42

// 受信
value := <-ch

// クローズ
close(ch)
```

### チャネルの方向
```go
// 送信専用
func producer(out chan<- int) {
    out <- 42
}

// 受信専用
func consumer(in <-chan int) {
    value := <-in
}

// 双方向（関数内で方向を制限）
func worker(jobs <-chan Job, results chan<- Result) {
    for job := range jobs {
        results <- process(job)
    }
}
```

### パターン: ワーカープール
```go
func workerPool(ctx context.Context, jobs <-chan Job, numWorkers int) <-chan Result {
    results := make(chan Result)

    var wg sync.WaitGroup
    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for {
                select {
                case <-ctx.Done():
                    return
                case job, ok := <-jobs:
                    if !ok {
                        return
                    }
                    results <- process(job)
                }
            }
        }()
    }

    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}
```

### パターン: Fan-out/Fan-in
```go
// Fan-out: 1つのチャネルから複数のワーカーが読み取り
func fanOut(in <-chan int, n int) []<-chan int {
    outs := make([]<-chan int, n)
    for i := 0; i < n; i++ {
        outs[i] = worker(in)
    }
    return outs
}

// Fan-in: 複数のチャネルを1つにまとめる
func fanIn(channels ...<-chan int) <-chan int {
    out := make(chan int)
    var wg sync.WaitGroup

    for _, ch := range channels {
        wg.Add(1)
        go func(c <-chan int) {
            defer wg.Done()
            for v := range c {
                out <- v
            }
        }(ch)
    }

    go func() {
        wg.Wait()
        close(out)
    }()

    return out
}
```

## select文

### 基本
```go
select {
case msg := <-ch1:
    fmt.Println("received from ch1:", msg)
case msg := <-ch2:
    fmt.Println("received from ch2:", msg)
case ch3 <- value:
    fmt.Println("sent to ch3")
default:
    fmt.Println("no channel ready")
}
```

### タイムアウト
```go
select {
case result := <-resultCh:
    return result, nil
case <-time.After(5 * time.Second):
    return nil, errors.New("timeout")
}
```

### contextとの組み合わせ
```go
func doWork(ctx context.Context) error {
    resultCh := make(chan Result)

    go func() {
        resultCh <- heavyComputation()
    }()

    select {
    case result := <-resultCh:
        return processResult(result)
    case <-ctx.Done():
        return ctx.Err()
    }
}
```

## 同期プリミティブ

### sync.Mutex
```go
type Counter struct {
    mu    sync.Mutex
    value int
}

func (c *Counter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.value++
}

func (c *Counter) Value() int {
    c.mu.Lock()
    defer c.mu.Unlock()
    return c.value
}
```

### sync.RWMutex
```go
type Cache struct {
    mu   sync.RWMutex
    data map[string]string
}

func (c *Cache) Get(key string) (string, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    v, ok := c.data[key]
    return v, ok
}

func (c *Cache) Set(key, value string) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.data[key] = value
}
```

### sync.WaitGroup
```go
func processAll(items []Item) {
    var wg sync.WaitGroup

    for _, item := range items {
        wg.Add(1)
        go func(item Item) {
            defer wg.Done()
            process(item)
        }(item)
    }

    wg.Wait()  // 全てのgoroutineが完了するまで待機
}
```

### sync.Once
```go
var (
    instance *Singleton
    once     sync.Once
)

func GetInstance() *Singleton {
    once.Do(func() {
        instance = &Singleton{}
        instance.init()
    })
    return instance
}
```

### sync.Pool
```go
var bufferPool = sync.Pool{
    New: func() interface{} {
        return make([]byte, 1024)
    },
}

func process() {
    buf := bufferPool.Get().([]byte)
    defer bufferPool.Put(buf)

    // bufを使用
}
```

## context

### 基本的な使い方
```go
// Background: ルートcontext
ctx := context.Background()

// TODO: 未確定のcontext（後で置き換え）
ctx := context.TODO()

// キャンセル可能
ctx, cancel := context.WithCancel(context.Background())
defer cancel()

// タイムアウト付き
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

// デッドライン付き
ctx, cancel := context.WithDeadline(context.Background(), time.Now().Add(time.Hour))
defer cancel()
```

### 値の伝播
```go
type contextKey string

const userIDKey contextKey = "userID"

// 値の設定
ctx := context.WithValue(ctx, userIDKey, "user-123")

// 値の取得
if userID, ok := ctx.Value(userIDKey).(string); ok {
    fmt.Println("User ID:", userID)
}
```

### HTTPハンドラでの使用
```go
func handler(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    result, err := doWork(ctx)
    if err != nil {
        if errors.Is(err, context.Canceled) {
            // クライアントがキャンセル
            return
        }
        if errors.Is(err, context.DeadlineExceeded) {
            http.Error(w, "Timeout", http.StatusGatewayTimeout)
            return
        }
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    json.NewEncoder(w).Encode(result)
}
```

## ベストプラクティス

### goroutineリークを防ぐ
```go
// Good: contextでキャンセル可能
func stream(ctx context.Context) <-chan Data {
    ch := make(chan Data)
    go func() {
        defer close(ch)
        for {
            select {
            case <-ctx.Done():
                return
            case ch <- fetchData():
            }
        }
    }()
    return ch
}
```

### チャネルの所有者がクローズ
```go
// 送信者がチャネルをクローズ
func producer() <-chan int {
    ch := make(chan int)
    go func() {
        defer close(ch)  // 送信者がクローズ
        for i := 0; i < 10; i++ {
            ch <- i
        }
    }()
    return ch
}
```

### バッファサイズの考慮
```go
// バッファなし: 同期的通信
ch := make(chan int)

// バッファあり: 非同期的（送信者がブロックしない）
ch := make(chan int, 100)

// バッファサイズは予想される最大値か、制限のために設定
```

## アンチパターン

| パターン | 問題 | 修正 |
|---------|------|------|
| ループ変数をgoroutineで直接参照 | レースコンディション | 引数で渡す |
| contextなしのgoroutine | リーク | context.WithCancelを使用 |
| nilチャネルへの送受信 | 永久ブロック | 必ず初期化 |
| closeしたチャネルへの送信 | panic | 送信者のみがclose |
| 共有変数の非同期アクセス | データレース | Mutex/チャネル使用 |

### ループ変数の落とし穴
```go
// Bad: 全てのgoroutineが同じiを参照
for i := 0; i < 10; i++ {
    go func() {
        fmt.Println(i)  // 予期しない値
    }()
}

// Good: 引数で渡す
for i := 0; i < 10; i++ {
    go func(n int) {
        fmt.Println(n)  // 正しい値
    }(i)
}

// Go 1.22+: ループ変数のセマンティクス変更により修正済み
```

## errgroup

`golang.org/x/sync/errgroup`は**複数のgoroutineのエラー管理を簡素化**します。

### インストール

```bash
go get golang.org/x/sync/errgroup
```

### 基本的な使い方

```go
import (
    "context"
    "golang.org/x/sync/errgroup"
)

func processFiles(ctx context.Context, files []string) error {
    g, ctx := errgroup.WithContext(ctx)

    for _, file := range files {
        file := file  // ループ変数のコピー（Go 1.22未満で必要）
        g.Go(func() error {
            return processFile(ctx, file)
        })
    }

    // 全てのgoroutineが完了するまで待機
    // いずれかがエラーを返した場合、そのエラーが返る
    if err := g.Wait(); err != nil {
        return fmt.Errorf("failed to process files: %w", err)
    }
    return nil
}
```

### 最初のエラーで全自動キャンセル

errgroupは**最初のエラーが発生した時点で、contextをキャンセル**します：

```go
func fetchAll(ctx context.Context, urls []string) ([]Result, error) {
    g, ctx := errgroup.WithContext(ctx)
    results := make([]Result, len(urls))

    for i, url := range urls {
        i, url := i, url
        g.Go(func() error {
            result, err := fetch(ctx, url)
            if err != nil {
                return err  // ここでエラーを返すと他のgoroutineがキャンセルされる
            }
            results[i] = result
            return nil
        })
    }

    if err := g.Wait(); err != nil {
        return nil, err
    }
    return results, nil
}

func fetch(ctx context.Context, url string) (Result, error) {
    select {
    case <-ctx.Done():
        return Result{}, ctx.Err()  // キャンセルされた場合は即座に終了
    default:
        // リクエスト処理
    }
}
```

### 同時実行数の制限

```go
func processWithLimit(ctx context.Context, tasks []Task) error {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(5)  // 最大5個のgoroutineを同時実行

    for _, task := range tasks {
        task := task
        g.Go(func() error {
            return task.Process(ctx)
        })
    }

    return g.Wait()
}
```

### errgroupのベストプラクティス

| プラクティス | 説明 |
|------------|------|
| contextのキャンセルを尊重 | goroutine内で`ctx.Done()`をチェック |
| エラーはラップして返す | `fmt.Errorf("...: %w", err)` |
| 同時実行数を制限 | `SetLimit()`で過負荷を防止 |

## singleflight

`golang.org/x/sync/singleflight`は**重複リクエストを抑制**し、thundering herd問題を解決します。

### インストール

```bash
go get golang.org/x/sync/singleflight
```

### 基本的な使い方

```go
import "golang.org/x/sync/singleflight"

type Cache struct {
    sf singleflight.Group
}

func (c *Cache) GetUser(userID string) (*User, error) {
    // 同じuserIDでの複数リクエストは1回のDB問い合わせに集約
    val, err, shared := c.sf.Do(userID, func() (interface{}, error) {
        return fetchUserFromDB(userID)
    })

    if err != nil {
        return nil, err
    }

    // shared=trueの場合、他のgoroutineの結果を使用した
    return val.(*User), nil
}
```

### キャッシュとの組み合わせ

```go
type UserCache struct {
    cache sync.Map
    sf    singleflight.Group
}

func (c *UserCache) Get(userID string) (*User, error) {
    // 1. キャッシュチェック
    if val, ok := c.cache.Load(userID); ok {
        return val.(*User), nil
    }

    // 2. singleflightで重複リクエストを抑制
    val, err, _ := c.sf.Do(userID, func() (interface{}, error) {
        user, err := fetchUserFromDB(userID)
        if err != nil {
            return nil, err
        }

        // 3. キャッシュに保存
        c.cache.Store(userID, user)
        return user, nil
    })

    if err != nil {
        return nil, err
    }
    return val.(*User), nil
}
```

### DoChan（非ブロッキング版）

```go
func (c *Cache) GetUserAsync(userID string) <-chan singleflight.Result {
    return c.sf.DoChan(userID, func() (interface{}, error) {
        return fetchUserFromDB(userID)
    })
}

// 使用例
func handler(w http.ResponseWriter, r *http.Request) {
    resultCh := cache.GetUserAsync("user-123")

    select {
    case result := <-resultCh:
        if result.Err != nil {
            http.Error(w, result.Err.Error(), 500)
            return
        }
        json.NewEncoder(w).Encode(result.Val)
    case <-r.Context().Done():
        http.Error(w, "Request cancelled", 499)
    }
}
```

## semaphore

`golang.org/x/sync/semaphore`は**同時実行数を制限**する重み付きセマフォを提供します。

### インストール

```bash
go get golang.org/x/sync/semaphore
```

### 基本的な使い方

```go
import (
    "context"
    "golang.org/x/sync/semaphore"
)

func processWithSemaphore(ctx context.Context, tasks []Task) error {
    sem := semaphore.NewWeighted(5)  // 最大5個まで並行実行

    for _, task := range tasks {
        task := task

        // 1. セマフォを取得（空きがない場合はブロック）
        if err := sem.Acquire(ctx, 1); err != nil {
            return err
        }

        go func() {
            defer sem.Release(1)  // 2. 処理完了後にセマフォを解放
            task.Process()
        }()
    }

    // 全てのgoroutineが完了するまで待機
    if err := sem.Acquire(ctx, 5); err != nil {
        return err
    }

    return nil
}
```

### 重み付きセマフォ

```go
type Task struct {
    Weight int64  // タスクの重み（例: メモリ使用量）
}

func processTasks(ctx context.Context, tasks []Task, maxMemory int64) {
    sem := semaphore.NewWeighted(maxMemory)

    for _, task := range tasks {
        task := task

        // タスクの重みに応じてセマフォを取得
        if err := sem.Acquire(ctx, task.Weight); err != nil {
            return
        }

        go func() {
            defer sem.Release(task.Weight)
            task.Process()
        }()
    }

    sem.Acquire(ctx, maxMemory)  // 全完了待機
}
```

### TryAcquire（非ブロッキング）

```go
sem := semaphore.NewWeighted(5)

// ブロックせずに取得を試みる
if sem.TryAcquire(1) {
    defer sem.Release(1)
    // 処理
} else {
    // セマフォが取得できなかった場合の処理
    log.Println("Too many concurrent requests")
}
```

## goroutineリーク検出

### pprof

`net/http/pprof`でgoroutineの状態をリアルタイムで監視：

```go
import (
    _ "net/http/pprof"
    "net/http"
)

func main() {
    // pprof HTTPサーバーを起動
    go func() {
        http.ListenAndServe("localhost:6060", nil)
    }()

    // アプリケーションロジック
}
```

ブラウザで確認：
```bash
# goroutineの一覧
curl http://localhost:6060/debug/pprof/goroutine?debug=1

# goroutineプロファイル
go tool pprof http://localhost:6060/debug/pprof/goroutine
```

### uber/goleak

テストでgoroutineリークを検出：

```bash
go get go.uber.org/goleak
```

```go
import (
    "testing"
    "go.uber.org/goleak"
)

func TestMain(m *testing.M) {
    goleak.VerifyTestMain(m)  // テスト終了時にリークをチェック
}

func TestNoLeak(t *testing.T) {
    defer goleak.VerifyNone(t)  // このテスト終了時にリークをチェック

    // テストコード
    go func() {
        // 適切に終了しないgoroutineがあればエラー
    }()
}
```

特定のgoroutineを無視：
```go
func TestWithIgnore(t *testing.T) {
    defer goleak.VerifyNone(t,
        goleak.IgnoreTopFunction("database/sql.(*DB).connectionOpener"),
    )
    // テストコード
}
```

## Future/Promiseパターン

Goには言語レベルのFuture/Promiseはありませんが、**goroutine + チャネル**で実現可能：

### 基本的な実装

```go
type Future[T any] struct {
    ch chan T
}

func NewFuture[T any](fn func() T) *Future[T] {
    f := &Future[T]{ch: make(chan T, 1)}
    go func() {
        f.ch <- fn()
    }()
    return f
}

func (f *Future[T]) Get() T {
    return <-f.ch
}

// 使用例
func main() {
    future := NewFuture(func() int {
        time.Sleep(2 * time.Second)
        return 42
    })

    // 他の処理
    fmt.Println("waiting...")

    // 結果を取得（ブロック）
    result := future.Get()
    fmt.Println(result)  // 42
}
```

### エラーハンドリング付き

```go
type Result[T any] struct {
    Value T
    Err   error
}

type Future[T any] struct {
    ch chan Result[T]
}

func NewFuture[T any](fn func() (T, error)) *Future[T] {
    f := &Future[T]{ch: make(chan Result[T], 1)}
    go func() {
        val, err := fn()
        f.ch <- Result[T]{Value: val, Err: err}
    }()
    return f
}

func (f *Future[T]) Get() (T, error) {
    result := <-f.ch
    return result.Value, result.Err
}

// 使用例
future := NewFuture(func() (*User, error) {
    return fetchUser("user-123")
})

user, err := future.Get()
if err != nil {
    log.Fatal(err)
}
```

### 複数のFutureを待機

```go
func WaitAll[T any](futures ...*Future[T]) []T {
    results := make([]T, len(futures))
    for i, f := range futures {
        results[i] = f.Get()
    }
    return results
}

// 使用例
f1 := NewFuture(func() int { return 1 })
f2 := NewFuture(func() int { return 2 })
f3 := NewFuture(func() int { return 3 })

results := WaitAll(f1, f2, f3)
fmt.Println(results)  // [1 2 3]
```

---

## デッドロック自動検出

Goランタイムは全goroutineが待機状態になるとデッドロックを自動検出し`fatal error`を発生させる:

```
fatal error: all goroutines are asleep - deadlock!
```

### 検出条件と制限

- **検出される**: 全goroutineが待機状態（実行可能なgoroutineが0個）
- **検出される**: main goroutineのみの場合も検出
- **検出されない**: 一部のgoroutineだけがデッドロック（他が動作中）の場合
- テスト時: `-timeout`フラグ（デフォルト10分）で部分デッドロックも検出可能

### コード例

```go
// Bad: メインgoroutineでブロック
ch := make(chan int)
fmt.Println(<-ch) // fatal error: all goroutines are asleep - deadlock!

// Good: 別goroutineで送信
ch := make(chan int)
go func() { ch <- 42 }()
fmt.Println(<-ch) // 42
```
