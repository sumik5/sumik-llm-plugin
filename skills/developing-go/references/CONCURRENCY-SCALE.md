# 大規模開発での並行処理

Go並行処理を本番環境で運用する際の設計戦略とパターン。エラー伝播、タイムアウト、ハートビート、流量制限、自己修復など、スケーラブルなシステムを構築するための実践的手法。

---

## エラー伝播の体系的設計

### きちんとした形式のエラー要件

並行システムでは、エラー情報が複数のgoroutine間を伝播するため、構造化が重要：

```go
type ConcurrentError struct {
    What   string    // 何が起きたか
    When   time.Time // いつ
    Where  string    // どこで（goroutine ID、関数名）
    Msg    string    // ユーザー向けメッセージ
    Detail error     // 詳細情報へのアクセス
}

func (e *ConcurrentError) Error() string {
    return fmt.Sprintf("[%s] %s at %s: %s (detail: %v)",
        e.When.Format(time.RFC3339), e.What, e.Where, e.Msg, e.Detail)
}
```

### バグ vs 既知のエッジケースの分類

```go
type ErrorType int

const (
    ErrorTypeBug      ErrorType = iota // プログラムのバグ
    ErrorTypeExpected                   // 既知のエッジケース（外部API障害等）
    ErrorTypeUser                       // ユーザー入力の問題
)

type ClassifiedError struct {
    Type    ErrorType
    Err     error
    Context map[string]interface{}
}

func classifyError(err error) ErrorType {
    switch {
    case errors.Is(err, context.DeadlineExceeded):
        return ErrorTypeExpected
    case errors.Is(err, sql.ErrNoRows):
        return ErrorTypeExpected
    default:
        return ErrorTypeBug
    }
}
```

### モジュール境界でのエラーラッピング

goroutineを跨ぐ際は、エラーを適切にラップして文脈を追加：

```go
func (s *Service) ProcessInParallel(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)

    for _, item := range items {
        item := item
        g.Go(func() error {
            if err := s.process(ctx, item); err != nil {
                // モジュール境界で文脈を追加
                return fmt.Errorf("failed to process item %s: %w", item.ID, err)
            }
            return nil
        })
    }

    if err := g.Wait(); err != nil {
        // 上位レイヤーへの伝播時にも文脈を追加
        return fmt.Errorf("parallel processing failed: %w", err)
    }
    return nil
}
```

---

## タイムアウトとキャンセル設計

### タイムアウトの理由を明確化

```go
const (
    TimeoutReason_Saturation   = "saturation"    // システム飽和
    TimeoutReason_DataFreshness = "freshness"    // データ鮮度要件
    TimeoutReason_DeadlockPrevention = "deadlock" // デッドロック防止
)

type TimeoutConfig struct {
    Duration time.Duration
    Reason   string
}

func (s *Service) FetchWithTimeout(ctx context.Context, key string) (*Data, error) {
    config := TimeoutConfig{
        Duration: 5 * time.Second,
        Reason:   TimeoutReason_DataFreshness, // データが5秒以上古いと無意味
    }

    ctx, cancel := context.WithTimeout(ctx, config.Duration)
    defer cancel()

    data, err := s.fetch(ctx, key)
    if errors.Is(err, context.DeadlineExceeded) {
        return nil, fmt.Errorf("timeout (%s): %w", config.Reason, err)
    }
    return data, err
}
```

### キャンセル原因の分類

```go
type CancelReason int

const (
    CancelReason_Timeout CancelReason = iota
    CancelReason_UserIntervention
    CancelReason_ParentCancel
    CancelReason_ReplicatedRequest // 複製リクエストで他が先に完了
)

type CancelContext struct {
    context.Context
    Reason CancelReason
}

func WithCancelReason(parent context.Context, reason CancelReason) (*CancelContext, context.CancelFunc) {
    ctx, cancel := context.WithCancel(parent)
    return &CancelContext{Context: ctx, Reason: reason}, cancel
}
```

### 割り込み可能性の設計

長時間の処理は小さい機能に分割し、各ステップでキャンセルをチェック：

```go
func (s *Service) ProcessLargeDataset(ctx context.Context, data [][]byte) error {
    for i, chunk := range data {
        // 小さい単位でキャンセルチェック
        select {
        case <-ctx.Done():
            return fmt.Errorf("cancelled at chunk %d/%d: %w", i, len(data), ctx.Err())
        default:
        }

        if err := s.processChunk(ctx, chunk); err != nil {
            return err
        }
    }
    return nil
}
```

### 共有状態の変更とロールバック

キャンセル時に共有状態を一貫性のある状態に戻す：

```go
type Transaction struct {
    mu       sync.Mutex
    state    map[string]interface{}
    rollback []func()
}

func (t *Transaction) Modify(ctx context.Context, key string, value interface{}) error {
    t.mu.Lock()
    defer t.mu.Unlock()

    select {
    case <-ctx.Done():
        // キャンセル検知 → ロールバック実行
        for i := len(t.rollback) - 1; i >= 0; i-- {
            t.rollback[i]()
        }
        return ctx.Err()
    default:
    }

    oldValue := t.state[key]
    t.state[key] = value

    // ロールバック処理を記録
    t.rollback = append(t.rollback, func() {
        t.state[key] = oldValue
    })

    return nil
}
```

---

## ハートビートパターン

### 一定周期ハートビート

長時間実行goroutineの生存確認：

```go
func worker(ctx context.Context, heartbeat chan<- time.Time) {
    ticker := time.NewTicker(2 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return
        case t := <-ticker.C:
            // ハートビート送信
            select {
            case heartbeat <- t:
            default: // 受信側が読まない場合はブロックしない
            }

            // 実際の作業
            doWork()
        }
    }
}

// 監視側
func monitorWorker(ctx context.Context) {
    heartbeat := make(chan time.Time)
    go worker(ctx, heartbeat)

    timeout := time.After(5 * time.Second)
    for {
        select {
        case <-heartbeat:
            timeout = time.After(5 * time.Second) // タイムアウトをリセット
        case <-timeout:
            log.Fatal("worker is not responding")
        case <-ctx.Done():
            return
        }
    }
}
```

### 仕事単位ハートビート

テストの決定性を保証：

```go
func processItems(ctx context.Context, items <-chan Item, heartbeat chan<- struct{}) {
    for {
        select {
        case <-ctx.Done():
            return
        case item, ok := <-items:
            if !ok {
                return
            }
            process(item)

            // 1アイテム処理完了ごとにハートビート
            select {
            case heartbeat <- struct{}{}:
            default:
            }
        }
    }
}

// テストでの使用
func TestProcessItems(t *testing.T) {
    items := make(chan Item)
    heartbeat := make(chan struct{})
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    go processItems(ctx, items, heartbeat)

    // アイテムを送信
    items <- Item{ID: "1"}

    // ハートビートを待機（処理完了を決定的に確認）
    select {
    case <-heartbeat:
        // OK
    case <-time.After(1 * time.Second):
        t.Fatal("timeout waiting for heartbeat")
    }
}
```

### バッファ1のチャネル + default節

ハートビート送信側がブロックしないパターン：

```go
func producer(ctx context.Context, heartbeat chan<- time.Time) {
    for {
        select {
        case <-ctx.Done():
            return
        default:
        }

        // 重い処理
        doExpensiveWork()

        // ハートビート送信（ブロックしない）
        select {
        case heartbeat <- time.Now():
        default: // 受信側が読まない場合はスキップ
        }
    }
}

// 使用例
heartbeat := make(chan time.Time, 1) // バッファ1
go producer(ctx, heartbeat)
```

---

## 複製されたリクエスト

### 最速レスポンス取得

複数のバックエンドに同時リクエストを送り、最初の応答を使用：

```go
func fetchReplicated(ctx context.Context, urls []string) ([]byte, error) {
    ctx, cancel := context.WithCancel(ctx)
    defer cancel()

    results := make(chan []byte, len(urls))
    errors := make(chan error, len(urls))

    for _, url := range urls {
        url := url
        go func() {
            data, err := httpGet(ctx, url)
            if err != nil {
                errors <- err
                return
            }
            results <- data
        }()
    }

    // 最初の成功応答を返す
    for i := 0; i < len(urls); i++ {
        select {
        case data := <-results:
            return data, nil // 最初の成功
        case <-errors:
            // エラーは無視して次を待つ
        case <-ctx.Done():
            return nil, ctx.Err()
        }
    }

    return nil, fmt.Errorf("all replicated requests failed")
}
```

### トレードオフ

- **速度**: レイテンシの改善（最速のサーバーが応答）
- **リソース**: N倍のリクエストコスト（帯域、サーバー負荷）
- **適用場面**: 読み取り専用操作、レイテンシがクリティカルな場合

### ハンドラーの等価性要件

複製リクエストを使う場合、**すべてのハンドラーは等価な結果を返す必要がある**：

```go
// OK: 読み取り専用
func getUser(userID string) (*User, error)

// NG: 副作用がある（複数回実行で問題）
func incrementCounter(key string) error

// OK: 冪等性がある（何度実行しても同じ結果）
func setStatus(orderID string, status Status) error
```

---

## 流量制限の詳細設計

### トークンバケットアルゴリズム

```go
type TokenBucket struct {
    mu         sync.Mutex
    capacity   int           // バケット容量（深さd）
    tokens     int           // 現在のトークン数
    refillRate time.Duration // 補充速度（r）
    lastRefill time.Time
}

func NewTokenBucket(capacity int, refillRate time.Duration) *TokenBucket {
    return &TokenBucket{
        capacity:   capacity,
        tokens:     capacity,
        refillRate: refillRate,
        lastRefill: time.Now(),
    }
}

func (tb *TokenBucket) Allow() bool {
    tb.mu.Lock()
    defer tb.mu.Unlock()

    // トークン補充
    now := time.Now()
    elapsed := now.Sub(tb.lastRefill)
    tokensToAdd := int(elapsed / tb.refillRate)

    if tokensToAdd > 0 {
        tb.tokens = min(tb.capacity, tb.tokens+tokensToAdd)
        tb.lastRefill = now
    }

    // トークン消費
    if tb.tokens > 0 {
        tb.tokens--
        return true
    }
    return false
}
```

### 多層の流量制限

```go
type MultiTierLimiter struct {
    perSecond *TokenBucket
    perMinute *TokenBucket
    perHour   *TokenBucket
}

func NewMultiTierLimiter() *MultiTierLimiter {
    return &MultiTierLimiter{
        perSecond: NewTokenBucket(10, time.Second/10),     // 10 req/sec
        perMinute: NewTokenBucket(300, time.Minute/300),   // 300 req/min
        perHour:   NewTokenBucket(5000, time.Hour/5000),   // 5000 req/hour
    }
}

func (m *MultiTierLimiter) Allow() bool {
    return m.perSecond.Allow() && m.perMinute.Allow() && m.perHour.Allow()
}
```

### リソース別制限

```go
type ResourceLimiter struct {
    limiters map[string]*TokenBucket
    mu       sync.RWMutex
}

func NewResourceLimiter() *ResourceLimiter {
    return &ResourceLimiter{
        limiters: make(map[string]*TokenBucket),
    }
}

func (r *ResourceLimiter) SetLimit(resource string, capacity int, rate time.Duration) {
    r.mu.Lock()
    defer r.mu.Unlock()
    r.limiters[resource] = NewTokenBucket(capacity, rate)
}

func (r *ResourceLimiter) Allow(resource string) bool {
    r.mu.RLock()
    limiter, ok := r.limiters[resource]
    r.mu.RUnlock()

    if !ok {
        return true // リミットが設定されていない場合は許可
    }
    return limiter.Allow()
}

// 使用例
limiter := NewResourceLimiter()
limiter.SetLimit("api", 100, time.Second/100)
limiter.SetLimit("disk", 10, time.Second/10)
limiter.SetLimit("network", 50, time.Second/50)

if limiter.Allow("api") {
    makeAPICall()
}
```

### MultiLimiterパターン

複数のリミッターをまとめて管理：

```go
type MultiLimiter struct {
    limiters []RateLimiter
}

type RateLimiter interface {
    Allow() bool
}

func (m *MultiLimiter) Allow() bool {
    for _, limiter := range m.limiters {
        if !limiter.Allow() {
            return false
        }
    }
    return true
}

// 使用例
multiLimiter := &MultiLimiter{
    limiters: []RateLimiter{
        NewTokenBucket(10, time.Second/10),
        NewTokenBucket(300, time.Minute/300),
        NewIPBasedLimiter("192.168.1.1", 5, time.Second/5),
    },
}

if multiLimiter.Allow() {
    handleRequest()
}
```

---

## Healingパターン（不健全なgoroutineの自動修復）

### 管理人(steward)と中庭(ward)の関係

```go
// ward: 監視対象のgoroutine
func ward(ctx context.Context, data <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for {
            select {
            case <-ctx.Done():
                return
            case d, ok := <-data:
                if !ok {
                    return
                }
                // 処理（ここでpanicの可能性）
                out <- process(d)
            }
        }
    }()
    return out
}

// steward: 管理人goroutine
func steward(ctx context.Context, data <-chan int, timeout time.Duration) <-chan int {
    out := make(chan int)

    go func() {
        defer close(out)

        var wardCh <-chan int
        startWard := func() {
            wardCh = ward(ctx, data)
        }

        startWard()

        for {
            select {
            case <-ctx.Done():
                return
            case result, ok := <-wardCh:
                if !ok {
                    // wardが終了 → 再起動
                    log.Println("ward stopped, restarting...")
                    startWard()
                    continue
                }
                out <- result
            case <-time.After(timeout):
                // タイムアウト → 不健全と判断して再起動
                log.Println("ward timeout, restarting...")
                startWard()
            }
        }
    }()

    return out
}
```

### ハートビートによる健全性監視

```go
func stewardWithHeartbeat(ctx context.Context, data <-chan int) <-chan int {
    out := make(chan int)

    go func() {
        defer close(out)

        startWard := func() (<-chan int, <-chan time.Time) {
            heartbeat := make(chan time.Time, 1)
            wardOut := wardWithHeartbeat(ctx, data, heartbeat)
            return wardOut, heartbeat
        }

        wardCh, heartbeat := startWard()

        for {
            select {
            case <-ctx.Done():
                return
            case result, ok := <-wardCh:
                if !ok {
                    wardCh, heartbeat = startWard()
                    continue
                }
                out <- result
            case <-heartbeat:
                // 健全性確認
            case <-time.After(5 * time.Second):
                // ハートビートがない → 再起動
                log.Println("no heartbeat, restarting ward")
                wardCh, heartbeat = startWard()
            }
        }
    }()

    return out
}

func wardWithHeartbeat(ctx context.Context, data <-chan int, heartbeat chan<- time.Time) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)

        pulse := time.NewTicker(2 * time.Second)
        defer pulse.Stop()

        for {
            select {
            case <-ctx.Done():
                return
            case <-pulse.C:
                select {
                case heartbeat <- time.Now():
                default:
                }
            case d, ok := <-data:
                if !ok {
                    return
                }
                out <- process(d)
            }
        }
    }()
    return out
}
```

### 自動再起動ロジック

指数バックオフでの再起動：

```go
func stewardWithBackoff(ctx context.Context, data <-chan int) <-chan int {
    out := make(chan int)

    go func() {
        defer close(out)

        restartCount := 0
        maxRestarts := 5

        startWard := func() <-chan int {
            if restartCount >= maxRestarts {
                log.Fatal("too many restarts, giving up")
            }

            // 指数バックオフ
            backoff := time.Duration(math.Pow(2, float64(restartCount))) * time.Second
            if backoff > 0 {
                log.Printf("waiting %v before restart", backoff)
                time.Sleep(backoff)
            }

            restartCount++
            return ward(ctx, data)
        }

        wardCh := startWard()

        for {
            select {
            case <-ctx.Done():
                return
            case result, ok := <-wardCh:
                if !ok {
                    wardCh = startWard()
                    continue
                }
                restartCount = 0 // 成功したらカウントリセット
                out <- result
            }
        }
    }()

    return out
}
```

### 再帰的監視

steward自体も監視：

```go
func superSteward(ctx context.Context, data <-chan int) <-chan int {
    return steward(ctx, data, 10*time.Second) // stewardを監視するsteward
}
```

### bridgeチャネルによる複数インスタンス統合

複数のwardインスタンスを単一チャネルにまとめる：

```go
func bridge(ctx context.Context, chanStream <-chan <-chan int) <-chan int {
    out := make(chan int)

    go func() {
        defer close(out)

        for {
            var stream <-chan int
            select {
            case <-ctx.Done():
                return
            case maybeStream, ok := <-chanStream:
                if !ok {
                    return
                }
                stream = maybeStream
            }

            // streamからoutへ転送
            for val := range stream {
                select {
                case <-ctx.Done():
                    return
                case out <- val:
                }
            }
        }
    }()

    return out
}

// 使用例
func multiWardSystem(ctx context.Context, numWards int, data <-chan int) <-chan int {
    wardStream := make(chan (<-chan int))

    go func() {
        defer close(wardStream)
        for i := 0; i < numWards; i++ {
            wardStream <- steward(ctx, data, 5*time.Second)
        }
    }()

    return bridge(ctx, wardStream)
}
```

---

## まとめ

大規模並行システムでの実践的パターン：

| パターン | 用途 | 重要度 |
|---------|------|--------|
| エラー伝播設計 | 問題の診断・デバッグ | 🔴 必須 |
| タイムアウト/キャンセル | リソース枯渇防止 | 🔴 必須 |
| ハートビート | 生存確認・決定性テスト | 🟡 推奨 |
| 複製リクエスト | レイテンシ最適化 | 🟢 場合による |
| 流量制限 | 過負荷防止 | 🔴 必須 |
| Healing | 自己修復・耐障害性 | 🟡 推奨 |
