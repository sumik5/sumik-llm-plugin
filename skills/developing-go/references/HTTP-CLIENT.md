# HTTPクライアント

## 基本的なHTTPリクエスト

### http.Get（簡易版）

```go
resp, err := http.Get("http://example.com/")
if err != nil {
    // ネットワークエラー等
    return err
}
defer resp.Body.Close()

// ステータスコード確認（必須）
if resp.StatusCode != http.StatusOK {
    return fmt.Errorf("unexpected status: %d", resp.StatusCode)
}

// レスポンスボディ読み取り
body, err := io.ReadAll(resp.Body)
```

**重要**:
- `resp.Body.Close()`は必須（リソースリーク防止）
- ステータスコードは`err == nil`でも40x/50xの可能性あり

### http.Post

```go
type User struct {
    Name string
    Addr string
}

u := User{Name: "O'Reilly Japan", Addr: "東京都新宿区四谷坂町"}
payload, err := json.Marshal(u)
if err != nil {
    return err
}

resp, err := http.Post(
    "http://example.com/",
    "application/json",
    bytes.NewBuffer(payload),
)
if err != nil {
    return err
}
defer resp.Body.Close()
```

## http.Clientのカスタマイズ

### タイムアウト設定

```go
// Good: タイムアウト設定したクライアント
client := &http.Client{
    Timeout:   10 * time.Second,
    Transport: http.DefaultTransport,
}

req, err := http.NewRequestWithContext(ctx, "GET", "http://example.com", nil)
if err != nil {
    return err
}

resp, err := client.Do(req)
```

**重要**: デフォルトの`http.DefaultClient`はタイムアウトなし（非推奨）。

### リクエストヘッダー付与

```go
req, err := http.NewRequestWithContext(ctx, "GET", "http://example.com", nil)
if err != nil {
    return err
}

// ヘッダー追加
req.Header.Add("Authorization", "Bearer XXX...XXX")
req.Header.Add("User-Agent", "MyApp/1.0")

resp, err := client.Do(req)
```

## RoundTripper パターン

### 基本構造

`http.RoundTripper`インターフェースでHTTPリクエストをカスタマイズ。Middlewareパターンのクライアント版。

```go
type RoundTripper interface {
    RoundTrip(*Request) (*Response, error)
}
```

### 基本実装

```go
type customRoundTripper struct {
    base http.RoundTripper
}

func (c *customRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
    // << リクエスト前処理 >>
    resp, err := c.base.RoundTrip(req)
    // << リクエスト後処理 >>
    return resp, err
}

// 使用
client := &http.Client{
    Transport: &customRoundTripper{
        base: http.DefaultTransport,
    },
}
```

### ロギング用RoundTripper

```go
type loggingRoundTripper struct {
    transport http.RoundTripper
    logger    func(string, ...interface{})
}

func (t *loggingRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
    if t.logger == nil {
        t.logger = log.Printf
    }

    start := time.Now()
    resp, err := t.transport.RoundTrip(req)

    if resp != nil {
        t.logger("%s %s %d %s, duration: %dms",
            req.Method, req.URL.String(), resp.StatusCode,
            http.StatusText(resp.StatusCode), time.Since(start).Milliseconds())
    }

    return resp, err
}
```

### 認証用RoundTripper（Basic認証）

```go
type basicAuthRoundTripper struct {
    username string
    password string
    base     http.RoundTripper
}

func (rt *basicAuthRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
    req.SetBasicAuth(rt.username, rt.password)
    return rt.base.RoundTrip(req)
}
```

**他の認証方式**: OAuth 2.0は`golang.org/x/oauth2`を使用。

### 認証トークン付与

```go
type tokenRoundTripper struct {
    token string
    base  http.RoundTripper
}

func (rt *tokenRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
    req.Header.Set("Authorization", "Bearer "+rt.token)
    return rt.base.RoundTrip(req)
}
```

## リトライ戦略

### リトライ対象の判定

```go
func shouldRetry(resp *http.Response, err error) bool {
    // ネットワークエラーによるリトライ
    if err != nil {
        var netErr net.Error
        if errors.As(err, &netErr) && netErr.Temporary() {
            return true
        }
    }

    // レスポンスコードによるリトライ
    if resp != nil {
        // 429 Too Many Requests, 5xx Server Error
        if resp.StatusCode == 429 || (500 <= resp.StatusCode && resp.StatusCode <= 504) {
            return true
        }
    }

    // 4xx Client Error はリトライしない
    return false
}
```

**重要**: 400番台のクライアントエラーはリトライしても無駄。

### Exponential Backoff + Jitter

```go
type retryableRoundTripper struct {
    base          http.RoundTripper
    maxAttempts   int
    initialWait   time.Duration
    maxWait       time.Duration
}

func (rt *retryableRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
    var resp *http.Response
    var err error

    wait := rt.initialWait

    for attempt := 0; attempt < rt.maxAttempts; attempt++ {
        resp, err = rt.base.RoundTrip(req)

        if !shouldRetry(resp, err) {
            return resp, err
        }

        // 最終試行ならリトライしない
        if attempt == rt.maxAttempts-1 {
            break
        }

        // Exponential Backoff + Jitter
        jitter := time.Duration(rand.Int63n(int64(wait / 2)))
        sleepTime := wait + jitter

        select {
        case <-req.Context().Done():
            return nil, req.Context().Err()
        case <-time.After(sleepTime):
        }

        // 待機時間を倍増（最大値でキャップ）
        wait *= 2
        if wait > rt.maxWait {
            wait = rt.maxWait
        }
    }

    return resp, err
}
```

**Jitter（ゆらぎ）の重要性**: 複数クライアントが同時リトライするThundering Herd問題を回避。

### Retry-Afterヘッダー考慮

```go
func (rt *retryableRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
    var resp *http.Response
    var err error

    for attempt := 0; attempt < rt.maxAttempts; attempt++ {
        resp, err = rt.base.RoundTrip(req)

        if !shouldRetry(resp, err) {
            return resp, err
        }

        if attempt == rt.maxAttempts-1 {
            break
        }

        // Retry-Afterヘッダー確認
        var sleepTime time.Duration
        if resp != nil && resp.Header.Get("Retry-After") != "" {
            if seconds, err := strconv.Atoi(resp.Header.Get("Retry-After")); err == nil {
                sleepTime = time.Duration(seconds) * time.Second
            }
        } else {
            // Exponential Backoff
            sleepTime = rt.initialWait * time.Duration(1<<attempt)
        }

        select {
        case <-req.Context().Done():
            return nil, req.Context().Err()
        case <-time.After(sleepTime):
        }
    }

    return resp, err
}
```

### hashicorp/go-retryablehttp（推奨）

本番環境では実績あるライブラリを使用。

```go
import "github.com/hashicorp/go-retryablehttp"

client := retryablehttp.NewClient()
client.RetryMax = 3
client.RetryWaitMin = 1 * time.Second
client.RetryWaitMax = 10 * time.Second

resp, err := client.Get("http://example.com/")
```

## プロキシ対応

### 環境変数ベース（推奨）

```go
// Good: 環境変数から自動読み込み
client := &http.Client{
    Transport: &http.Transport{
        Proxy: http.ProxyFromEnvironment,
    },
}
```

環境変数: `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`

### 明示的プロキシ設定

```go
proxyURL, _ := url.Parse("http://proxy.example.com:8080")

client := &http.Client{
    Transport: &http.Transport{
        Proxy: http.ProxyURL(proxyURL),
    },
}
```

### SSL証明書検証スキップ（開発環境のみ）

```go
// Bad: 本番環境では絶対に使用しない
client := &http.Client{
    Transport: &http.Transport{
        TLSClientConfig: &tls.Config{
            InsecureSkipVerify: true, // 危険
        },
    },
}
```

## RoundTripperの組み合わせ

```go
// 複数のRoundTripperを重ねる
client := &http.Client{
    Timeout: 30 * time.Second,
    Transport: &retryableRoundTripper{
        base: &loggingRoundTripper{
            transport: &tokenRoundTripper{
                token: "my-token",
                base:  http.DefaultTransport,
            },
        },
        maxAttempts: 3,
        initialWait: 1 * time.Second,
        maxWait:     10 * time.Second,
    },
}
```

実行順序: Token付与 → ログ → リトライ → 実際のHTTPリクエスト

## ベストプラクティス

| プラクティス | 説明 |
|------------|------|
| 必ずタイムアウト設定 | デフォルトはタイムアウトなし |
| resp.Body.Close()必須 | deferで確実にクローズ |
| ステータスコード確認 | err == nilでも40x/50xあり |
| 40x番台はリトライしない | クライアントエラーは再試行無駄 |
| Exponential Backoff使用 | 固定待機は負荷集中リスク |
| Jitterを加える | 同時リトライ回避 |
| context対応 | time.Sleep不可、time.After使用 |
| RoundTripperで共通処理分離 | ログ/認証/リトライを分離 |
| プロキシは環境変数から | http.ProxyFromEnvironment使用 |
| 本番はライブラリ使用 | go-retryablehttpが実績あり |

## アンチパターン

| パターン | 問題 | 修正 |
|---------|------|------|
| タイムアウト未設定 | 無限待機リスク | client.Timeout設定必須 |
| Body未クローズ | ファイルディスクリプタ枯渇 | defer resp.Body.Close() |
| ステータスコード未確認 | エラー見逃し | 40x/50xを明示的チェック |
| 4xx番台をリトライ | 無駄なリクエスト | 5xx/429のみリトライ |
| 固定間隔リトライ | Thundering Herd | Exponential Backoff + Jitter |
| time.Sleep使用 | context.Done()無視 | time.Afterとselect併用 |
| グローバルDefaultClient使用 | タイムアウト/認証カスタマイズ不可 | 専用http.Client作成 |
| SSL検証スキップ | セキュリティリスク | 本番では絶対禁止 |
