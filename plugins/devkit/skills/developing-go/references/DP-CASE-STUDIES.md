# デザインパターン実践ケーススタディ

実際のシステム開発で複数のデザインパターンがどのように組み合わされるかを示す4つの実践的ケーススタディ。

---

## ケース1: ECサイトシステム

### システム概要

オンライン書籍販売サイトの注文処理システム。注文受付、在庫管理、決済処理、メール通知を統合的に処理する。

### 適用パターン

| パターン | 適用箇所 | 理由 |
|---------|---------|------|
| **Command** | 注文処理 | 注文をオブジェクト化し、実行・取り消し・履歴管理を可能にする |
| **Observer** | 在庫更新通知 | 注文時に在庫システムへ自動通知し、疎結合を維持 |
| **Factory Method** | 商品カテゴリ | 書籍・雑誌・電子書籍で異なる処理を統一的に生成 |
| **Worker Pool** | 並行処理 | 大量注文を効率的に処理 |

### パターン相互作用

```
[ユーザー注文]
    ↓
[OrderCommand] ← Factory Methodで生成
    ↓
[CommandExecutor] ← Worker Poolで並行実行
    ↓
[在庫システム] ← Observerパターンで通知
```

### 核心部分の実装

#### 1. Commandパターン（注文処理）

```go
// Command interface
type OrderCommand interface {
    Execute() error
    Undo() error
    GetOrderID() int
}

// 注文作成コマンド
type CreateOrderCommand struct {
    orderID    int
    items      []Item
    orderRepo  OrderRepository
    inventory  InventoryService
    observers  []OrderObserver
}

func NewCreateOrderCommand(
    orderID int,
    items []Item,
    repo OrderRepository,
    inventory InventoryService,
    observers []OrderObserver,
) *CreateOrderCommand {
    return &CreateOrderCommand{
        orderID:   orderID,
        items:     items,
        orderRepo: repo,
        inventory: inventory,
        observers: observers,
    }
}

func (c *CreateOrderCommand) Execute() error {
    // 在庫確認
    for _, item := range c.items {
        available, err := c.inventory.CheckStock(item.ProductID, item.Quantity)
        if err != nil {
            return fmt.Errorf("inventory check failed: %w", err)
        }
        if !available {
            return fmt.Errorf("insufficient stock for product %d", item.ProductID)
        }
    }

    // 注文作成
    order := &Order{
        ID:     c.orderID,
        Items:  c.items,
        Status: "pending",
    }

    if err := c.orderRepo.Save(order); err != nil {
        return fmt.Errorf("save order failed: %w", err)
    }

    // 在庫減算
    for _, item := range c.items {
        if err := c.inventory.ReduceStock(item.ProductID, item.Quantity); err != nil {
            // ロールバック処理
            c.Undo()
            return fmt.Errorf("reduce stock failed: %w", err)
        }
    }

    // Observerへ通知
    c.notifyObservers(order)

    return nil
}

func (c *CreateOrderCommand) Undo() error {
    // 在庫を元に戻す
    for _, item := range c.items {
        c.inventory.RestoreStock(item.ProductID, item.Quantity)
    }

    // 注文を削除
    return c.orderRepo.Delete(c.orderID)
}

func (c *CreateOrderCommand) GetOrderID() int {
    return c.orderID
}

func (c *CreateOrderCommand) notifyObservers(order *Order) {
    for _, observer := range c.observers {
        observer.OnOrderCreated(order)
    }
}
```

#### 2. Observerパターン（在庫更新通知）

```go
// Observer interface
type OrderObserver interface {
    OnOrderCreated(order *Order)
    OnOrderCancelled(order *Order)
}

// 在庫通知Observer
type InventoryObserver struct {
    inventory InventoryService
}

func NewInventoryObserver(inventory InventoryService) *InventoryObserver {
    return &InventoryObserver{inventory: inventory}
}

func (o *InventoryObserver) OnOrderCreated(order *Order) {
    log.Printf("Inventory notification: order %d created", order.ID)
    // 在庫システムへの追加通知処理（キャッシュ更新等）
}

func (o *InventoryObserver) OnOrderCancelled(order *Order) {
    log.Printf("Inventory notification: order %d cancelled", order.ID)
    // 在庫復元処理
    for _, item := range order.Items {
        o.inventory.RestoreStock(item.ProductID, item.Quantity)
    }
}

// メール通知Observer
type EmailNotificationObserver struct {
    emailService EmailService
}

func NewEmailNotificationObserver(emailService EmailService) *EmailNotificationObserver {
    return &EmailNotificationObserver{emailService: emailService}
}

func (o *EmailNotificationObserver) OnOrderCreated(order *Order) {
    message := fmt.Sprintf("Your order #%d has been confirmed", order.ID)
    o.emailService.Send(order.CustomerEmail, "Order Confirmation", message)
}

func (o *EmailNotificationObserver) OnOrderCancelled(order *Order) {
    message := fmt.Sprintf("Your order #%d has been cancelled", order.ID)
    o.emailService.Send(order.CustomerEmail, "Order Cancellation", message)
}
```

#### 3. Factory Method（商品カテゴリ）

```go
// Product interface
type Product interface {
    GetPrice() float64
    GetCategory() string
    CalculateShipping() float64
}

// 書籍
type Book struct {
    ID     int
    Title  string
    Price  float64
    Weight float64
}

func (b *Book) GetPrice() float64 {
    return b.Price
}

func (b *Book) GetCategory() string {
    return "book"
}

func (b *Book) CalculateShipping() float64 {
    // 重量ベースの配送料
    return b.Weight * 100
}

// 電子書籍
type EBook struct {
    ID    int
    Title string
    Price float64
}

func (e *EBook) GetPrice() float64 {
    return e.Price
}

func (e *EBook) GetCategory() string {
    return "ebook"
}

func (e *EBook) CalculateShipping() float64 {
    return 0 // 配送料なし
}

// Factory
type ProductFactory struct{}

func (f *ProductFactory) CreateProduct(category string, data map[string]interface{}) (Product, error) {
    switch category {
    case "book":
        return &Book{
            ID:     data["id"].(int),
            Title:  data["title"].(string),
            Price:  data["price"].(float64),
            Weight: data["weight"].(float64),
        }, nil
    case "ebook":
        return &EBook{
            ID:    data["id"].(int),
            Title: data["title"].(string),
            Price: data["price"].(float64),
        }, nil
    default:
        return nil, fmt.Errorf("unknown product category: %s", category)
    }
}
```

#### 4. Worker Pool（並行処理）

```go
type OrderProcessor struct {
    commandCh chan OrderCommand
    workers   int
    wg        sync.WaitGroup
}

func NewOrderProcessor(workers int) *OrderProcessor {
    return &OrderProcessor{
        commandCh: make(chan OrderCommand, workers*2),
        workers:   workers,
    }
}

func (p *OrderProcessor) Start(ctx context.Context) {
    for i := 0; i < p.workers; i++ {
        p.wg.Add(1)
        go p.worker(ctx, i)
    }
}

func (p *OrderProcessor) worker(ctx context.Context, id int) {
    defer p.wg.Done()

    for {
        select {
        case <-ctx.Done():
            log.Printf("Worker %d shutting down", id)
            return
        case cmd := <-p.commandCh:
            log.Printf("Worker %d processing order %d", id, cmd.GetOrderID())
            if err := cmd.Execute(); err != nil {
                log.Printf("Worker %d: order %d failed: %v", id, cmd.GetOrderID(), err)
            }
        }
    }
}

func (p *OrderProcessor) Submit(cmd OrderCommand) {
    p.commandCh <- cmd
}

func (p *OrderProcessor) Shutdown() {
    close(p.commandCh)
    p.wg.Wait()
}
```

### 統合使用例

```go
func main() {
    // 依存関係のセットアップ
    orderRepo := NewOrderRepository(db)
    inventoryService := NewInventoryService(db)
    emailService := NewEmailService()

    // Observerの登録
    observers := []OrderObserver{
        NewInventoryObserver(inventoryService),
        NewEmailNotificationObserver(emailService),
    }

    // Worker Pool起動
    processor := NewOrderProcessor(5)
    ctx, cancel := context.WithCancel(context.Background())
    processor.Start(ctx)

    // 注文受付
    items := []Item{
        {ProductID: 1, Quantity: 2},
        {ProductID: 2, Quantity: 1},
    }

    cmd := NewCreateOrderCommand(123, items, orderRepo, inventoryService, observers)
    processor.Submit(cmd)

    // システム終了
    time.Sleep(5 * time.Second)
    cancel()
    processor.Shutdown()
}
```

### パターン選択の判断基準

| 要件 | パターン | 理由 |
|------|---------|------|
| 注文操作の取り消し・履歴管理 | Command | 操作をオブジェクト化し、取り消し可能に |
| 注文後の複数システムへの通知 | Observer | 疎結合な通知メカニズム |
| 異なる商品タイプの統一的な扱い | Factory Method | 商品生成ロジックを集約 |
| 大量注文の効率的処理 | Worker Pool | 並行実行でスループット向上 |

---

## ケース2: チャットアプリケーション

### システム概要

リアルタイムメッセージング機能を持つチャットアプリ。複数のチャットルーム、ユーザー間のメッセージ配信、フォーマット変換を実現。

### 適用パターン

| パターン | 適用箇所 | 理由 |
|---------|---------|------|
| **Observer** | メッセージ配信 | ユーザーへのリアルタイム通知を疎結合に実現 |
| **Mediator** | チャットルーム管理 | ユーザー間の複雑な通信をルームが仲介 |
| **Strategy** | メッセージフォーマット | テキスト・画像・ファイルで異なる処理 |

### パターン相互作用

```
[ユーザーA] ─┐
[ユーザーB] ─┼→ [ChatRoom (Mediator)] → [MessageStrategy]
[ユーザーC] ─┘       ↓
                 [Observer通知]
                     ↓
              [全参加者へ配信]
```

### 核心部分の実装

#### 1. Observerパターン（メッセージ配信）

```go
// Observer interface
type ChatObserver interface {
    OnMessageReceived(msg *Message)
    GetUserID() string
}

// User実装
type User struct {
    id       string
    name     string
    conn     net.Conn
    room     *ChatRoom
}

func (u *User) OnMessageReceived(msg *Message) {
    // 自分のメッセージは配信しない
    if msg.SenderID == u.id {
        return
    }

    formatted := fmt.Sprintf("[%s] %s: %s\n", msg.Timestamp.Format("15:04"), msg.SenderName, msg.Content)
    u.conn.Write([]byte(formatted))
}

func (u *User) GetUserID() string {
    return u.id
}

func (u *User) SendMessage(content string, msgType MessageType) {
    msg := &Message{
        ID:         generateID(),
        SenderID:   u.id,
        SenderName: u.name,
        Content:    content,
        Type:       msgType,
        Timestamp:  time.Now(),
    }

    u.room.BroadcastMessage(msg)
}
```

#### 2. Mediatorパターン（チャットルーム管理）

```go
// Mediator interface
type ChatMediator interface {
    RegisterUser(user ChatObserver)
    RemoveUser(userID string)
    BroadcastMessage(msg *Message)
}

// ChatRoom実装
type ChatRoom struct {
    id            string
    name          string
    users         map[string]ChatObserver
    mu            sync.RWMutex
    messageFormat MessageFormatter
}

func NewChatRoom(id, name string, formatter MessageFormatter) *ChatRoom {
    return &ChatRoom{
        id:            id,
        name:          name,
        users:         make(map[string]ChatObserver),
        messageFormat: formatter,
    }
}

func (r *ChatRoom) RegisterUser(user ChatObserver) {
    r.mu.Lock()
    defer r.mu.Unlock()

    r.users[user.GetUserID()] = user
    log.Printf("User %s joined room %s", user.GetUserID(), r.name)

    // 参加通知を全員に送信
    joinMsg := &Message{
        ID:        generateID(),
        Content:   fmt.Sprintf("%s joined the room", user.GetUserID()),
        Type:      SystemMessage,
        Timestamp: time.Now(),
    }
    r.broadcastToAll(joinMsg)
}

func (r *ChatRoom) RemoveUser(userID string) {
    r.mu.Lock()
    defer r.mu.Unlock()

    if _, exists := r.users[userID]; !exists {
        return
    }

    delete(r.users, userID)
    log.Printf("User %s left room %s", userID, r.name)

    // 退出通知を全員に送信
    leaveMsg := &Message{
        ID:        generateID(),
        Content:   fmt.Sprintf("%s left the room", userID),
        Type:      SystemMessage,
        Timestamp: time.Now(),
    }
    r.broadcastToAll(leaveMsg)
}

func (r *ChatRoom) BroadcastMessage(msg *Message) {
    r.mu.RLock()
    defer r.mu.RUnlock()

    // メッセージフォーマット（Strategyパターン）
    formattedMsg := r.messageFormat.Format(msg)

    r.broadcastToAll(formattedMsg)
}

func (r *ChatRoom) broadcastToAll(msg *Message) {
    for _, user := range r.users {
        go user.OnMessageReceived(msg)
    }
}

func (r *ChatRoom) GetUserCount() int {
    r.mu.RLock()
    defer r.mu.RUnlock()
    return len(r.users)
}
```

#### 3. Strategyパターン（メッセージフォーマット）

```go
type MessageType int

const (
    TextMessage MessageType = iota
    ImageMessage
    FileMessage
    SystemMessage
)

type Message struct {
    ID         string
    SenderID   string
    SenderName string
    Content    string
    Type       MessageType
    Timestamp  time.Time
}

// Strategy interface
type MessageFormatter interface {
    Format(msg *Message) *Message
}

// テキストフォーマッター
type PlainTextFormatter struct{}

func (f *PlainTextFormatter) Format(msg *Message) *Message {
    // そのまま返す
    return msg
}

// Markdownフォーマッター
type MarkdownFormatter struct{}

func (f *MarkdownFormatter) Format(msg *Message) *Message {
    if msg.Type != TextMessage {
        return msg
    }

    // Markdown記法を適用
    formatted := &Message{
        ID:         msg.ID,
        SenderID:   msg.SenderID,
        SenderName: msg.SenderName,
        Content:    f.applyMarkdown(msg.Content),
        Type:       msg.Type,
        Timestamp:  msg.Timestamp,
    }

    return formatted
}

func (f *MarkdownFormatter) applyMarkdown(content string) string {
    // **bold** → <b>bold</b>
    content = strings.ReplaceAll(content, "**", "<b>")
    // *italic* → <i>italic</i>
    content = strings.ReplaceAll(content, "*", "<i>")
    return content
}

// 画像フォーマッター
type ImageFormatter struct{}

func (f *ImageFormatter) Format(msg *Message) *Message {
    if msg.Type != ImageMessage {
        return msg
    }

    // 画像URLを埋め込み形式に変換
    formatted := &Message{
        ID:         msg.ID,
        SenderID:   msg.SenderID,
        SenderName: msg.SenderName,
        Content:    fmt.Sprintf("[Image: %s]", msg.Content),
        Type:       msg.Type,
        Timestamp:  msg.Timestamp,
    }

    return formatted
}

// Formatterファクトリー
func GetFormatter(formatType string) MessageFormatter {
    switch formatType {
    case "markdown":
        return &MarkdownFormatter{}
    case "image":
        return &ImageFormatter{}
    default:
        return &PlainTextFormatter{}
    }
}
```

### 統合使用例

```go
func main() {
    // チャットルーム作成（Mediator）
    formatter := GetFormatter("markdown")
    room := NewChatRoom("room-001", "General", formatter)

    // ユーザー作成と参加（Observer）
    connA, _ := net.Dial("tcp", "localhost:8080")
    userA := &User{
        id:   "user-001",
        name: "Alice",
        conn: connA,
        room: room,
    }
    room.RegisterUser(userA)

    connB, _ := net.Dial("tcp", "localhost:8080")
    userB := &User{
        id:   "user-002",
        name: "Bob",
        conn: connB,
        room: room,
    }
    room.RegisterUser(userB)

    // メッセージ送信
    userA.SendMessage("Hello, **world**!", TextMessage)
    userB.SendMessage("https://example.com/image.png", ImageMessage)

    // ユーザー退出
    room.RemoveUser(userA.GetUserID())

    fmt.Printf("Room has %d users\n", room.GetUserCount())
}
```

### パターン選択の判断基準

| 要件 | パターン | 理由 |
|------|---------|------|
| 複数ユーザーへのメッセージ配信 | Observer | リアルタイム通知の疎結合実装 |
| ユーザー間の通信管理 | Mediator | 複雑な相互通信をルームが集約 |
| メッセージ種類ごとの処理切り替え | Strategy | フォーマット処理を分離 |

---

## ケース3: API Gateway

### システム概要

マイクロサービスへのリクエストを転送するAPI Gateway。認証、ロギング、レート制限、障害耐性を実現。

### 適用パターン

| パターン | 適用箇所 | 理由 |
|---------|---------|------|
| **Proxy** | リクエスト転送 | 実際のサービスを隠蔽し、透過的にアクセス |
| **Chain of Responsibility** | ミドルウェア | 認証→ロギング→レート制限を順次処理 |
| **Circuit Breaker** | 障害耐性 | サービス障害時の自動フォールバック |

### パターン相互作用

```
[クライアント]
    ↓
[Chain of Responsibility]
    ├→ [認証ハンドラ]
    ├→ [ロギングハンドラ]
    ├→ [レート制限ハンドラ]
    └→ [Proxy] → [Circuit Breaker] → [マイクロサービス]
```

### 核心部分の実装

#### 1. Proxyパターン（リクエスト転送）

```go
// Service interface
type Service interface {
    Call(ctx context.Context, req *Request) (*Response, error)
}

// Real Service（実サービス）
type UserService struct {
    url string
}

func (s *UserService) Call(ctx context.Context, req *Request) (*Response, error) {
    // 実際のHTTPリクエスト
    httpReq, err := http.NewRequestWithContext(ctx, req.Method, s.url+req.Path, strings.NewReader(req.Body))
    if err != nil {
        return nil, err
    }

    client := &http.Client{Timeout: 5 * time.Second}
    resp, err := client.Do(httpReq)
    if err != nil {
        return nil, fmt.Errorf("service call failed: %w", err)
    }
    defer resp.Body.Close()

    body, _ := io.ReadAll(resp.Body)
    return &Response{
        StatusCode: resp.StatusCode,
        Body:       string(body),
    }, nil
}

// Service Proxy
type ServiceProxy struct {
    service        Service
    circuitBreaker *CircuitBreaker
    cache          map[string]*Response
    mu             sync.RWMutex
}

func NewServiceProxy(service Service, breaker *CircuitBreaker) *ServiceProxy {
    return &ServiceProxy{
        service:        service,
        circuitBreaker: breaker,
        cache:          make(map[string]*Response),
    }
}

func (p *ServiceProxy) Call(ctx context.Context, req *Request) (*Response, error) {
    // キャッシュチェック
    if cached := p.getCache(req); cached != nil {
        log.Println("Cache hit")
        return cached, nil
    }

    // Circuit Breaker経由で呼び出し
    resp, err := p.circuitBreaker.Execute(func() (*Response, error) {
        return p.service.Call(ctx, req)
    })

    if err != nil {
        return nil, err
    }

    // キャッシュに保存
    p.setCache(req, resp)

    return resp, nil
}

func (p *ServiceProxy) getCache(req *Request) *Response {
    p.mu.RLock()
    defer p.mu.RUnlock()
    return p.cache[req.Path]
}

func (p *ServiceProxy) setCache(req *Request, resp *Response) {
    p.mu.Lock()
    defer p.mu.Unlock()
    p.cache[req.Path] = resp
}
```

#### 2. Chain of Responsibilityパターン（ミドルウェア）

```go
// Handler interface
type Handler interface {
    Handle(ctx context.Context, req *Request) (*Response, error)
    SetNext(handler Handler)
}

// Base Handler
type BaseHandler struct {
    next Handler
}

func (h *BaseHandler) SetNext(handler Handler) {
    h.next = handler
}

func (h *BaseHandler) CallNext(ctx context.Context, req *Request) (*Response, error) {
    if h.next != nil {
        return h.next.Handle(ctx, req)
    }
    return nil, fmt.Errorf("no next handler")
}

// 認証ハンドラ
type AuthHandler struct {
    BaseHandler
    tokenValidator TokenValidator
}

func NewAuthHandler(validator TokenValidator) *AuthHandler {
    return &AuthHandler{tokenValidator: validator}
}

func (h *AuthHandler) Handle(ctx context.Context, req *Request) (*Response, error) {
    token := req.Headers["Authorization"]
    if token == "" {
        return &Response{StatusCode: 401, Body: "Unauthorized"}, nil
    }

    userID, err := h.tokenValidator.Validate(token)
    if err != nil {
        return &Response{StatusCode: 403, Body: "Forbidden"}, nil
    }

    // コンテキストにユーザーIDを追加
    ctx = context.WithValue(ctx, "userID", userID)

    return h.CallNext(ctx, req)
}

// ロギングハンドラ
type LoggingHandler struct {
    BaseHandler
    logger *log.Logger
}

func NewLoggingHandler(logger *log.Logger) *LoggingHandler {
    return &LoggingHandler{logger: logger}
}

func (h *LoggingHandler) Handle(ctx context.Context, req *Request) (*Response, error) {
    start := time.Now()

    h.logger.Printf("Request: %s %s", req.Method, req.Path)

    resp, err := h.CallNext(ctx, req)

    duration := time.Since(start)
    h.logger.Printf("Response: %d (took %v)", resp.StatusCode, duration)

    return resp, err
}

// レート制限ハンドラ
type RateLimitHandler struct {
    BaseHandler
    limiter *rate.Limiter
}

func NewRateLimitHandler(limiter *rate.Limiter) *RateLimitHandler {
    return &RateLimitHandler{limiter: limiter}
}

func (h *RateLimitHandler) Handle(ctx context.Context, req *Request) (*Response, error) {
    if !h.limiter.Allow() {
        return &Response{StatusCode: 429, Body: "Too Many Requests"}, nil
    }

    return h.CallNext(ctx, req)
}

// サービス呼び出しハンドラ
type ServiceHandler struct {
    BaseHandler
    proxy *ServiceProxy
}

func NewServiceHandler(proxy *ServiceProxy) *ServiceHandler {
    return &ServiceHandler{proxy: proxy}
}

func (h *ServiceHandler) Handle(ctx context.Context, req *Request) (*Response, error) {
    return h.proxy.Call(ctx, req)
}
```

#### 3. Circuit Breakerパターン（障害耐性）

```go
type State int

const (
    StateClosed State = iota
    StateOpen
    StateHalfOpen
)

type CircuitBreaker struct {
    maxFailures  int
    timeout      time.Duration
    state        State
    failures     int
    lastFailTime time.Time
    mu           sync.Mutex
}

func NewCircuitBreaker(maxFailures int, timeout time.Duration) *CircuitBreaker {
    return &CircuitBreaker{
        maxFailures: maxFailures,
        timeout:     timeout,
        state:       StateClosed,
    }
}

func (cb *CircuitBreaker) Execute(fn func() (*Response, error)) (*Response, error) {
    cb.mu.Lock()

    // 状態確認
    if cb.state == StateOpen {
        if time.Since(cb.lastFailTime) > cb.timeout {
            // Half-Open状態へ移行
            cb.state = StateHalfOpen
            cb.failures = 0
            log.Println("Circuit Breaker: Open → Half-Open")
        } else {
            cb.mu.Unlock()
            return nil, fmt.Errorf("circuit breaker is open")
        }
    }

    cb.mu.Unlock()

    // 実行
    resp, err := fn()

    cb.mu.Lock()
    defer cb.mu.Unlock()

    if err != nil {
        cb.failures++
        cb.lastFailTime = time.Now()

        if cb.failures >= cb.maxFailures {
            cb.state = StateOpen
            log.Printf("Circuit Breaker: %s → Open (failures: %d)", cb.stateName(), cb.failures)
        }

        return nil, err
    }

    // 成功時
    if cb.state == StateHalfOpen {
        cb.state = StateClosed
        cb.failures = 0
        log.Println("Circuit Breaker: Half-Open → Closed")
    }

    return resp, nil
}

func (cb *CircuitBreaker) stateName() string {
    switch cb.state {
    case StateClosed:
        return "Closed"
    case StateOpen:
        return "Open"
    case StateHalfOpen:
        return "Half-Open"
    default:
        return "Unknown"
    }
}
```

### 統合使用例

```go
func main() {
    // 実サービス
    userService := &UserService{url: "http://localhost:8081"}

    // Circuit Breaker
    breaker := NewCircuitBreaker(3, 10*time.Second)

    // Proxy
    proxy := NewServiceProxy(userService, breaker)

    // ハンドラーチェーン構築
    serviceHandler := NewServiceHandler(proxy)
    rateLimitHandler := NewRateLimitHandler(rate.NewLimiter(10, 1))
    loggingHandler := NewLoggingHandler(log.Default())
    authHandler := NewAuthHandler(&SimpleTokenValidator{})

    authHandler.SetNext(loggingHandler)
    loggingHandler.SetNext(rateLimitHandler)
    rateLimitHandler.SetNext(serviceHandler)

    // リクエスト処理
    req := &Request{
        Method:  "GET",
        Path:    "/users/123",
        Headers: map[string]string{"Authorization": "Bearer valid-token"},
    }

    resp, err := authHandler.Handle(context.Background(), req)
    if err != nil {
        log.Fatalf("Request failed: %v", err)
    }

    fmt.Printf("Response: %d - %s\n", resp.StatusCode, resp.Body)
}
```

### パターン選択の判断基準

| 要件 | パターン | 理由 |
|------|---------|------|
| サービスの透過的な呼び出し | Proxy | 実装を隠蔽し、キャッシュや監視を追加 |
| 段階的なリクエスト検証 | Chain of Responsibility | 認証→ロギング→レート制限を順次処理 |
| サービス障害への自動対応 | Circuit Breaker | 連鎖障害を防ぎ、復旧を自動化 |

---

## ケース4: マイクロサービスアーキテクチャ

### システム概要

複数のマイクロサービス（ユーザー管理・注文処理・通知サービス）を統合するシステム。サービス間連携とイベント駆動アーキテクチャを実現。

### 適用パターン

| パターン | 適用箇所 | 理由 |
|---------|---------|------|
| **Facade** | サービス統合 | 複雑なサービス群を単純なAPIで公開 |
| **Observer** | イベント駆動 | サービス間を疎結合に連携 |
| **Circuit Breaker** | 障害分離 | 一部サービス障害が全体に波及しない |

### パターン相互作用

```
[クライアント]
    ↓
[ApplicationFacade]
    ├→ [UserService] ← Circuit Breaker
    ├→ [OrderService] ← Circuit Breaker
    └→ [NotificationService] ← Circuit Breaker
         ↓
    [EventBus (Observer)]
         ↓
    [各サービスがイベント購読]
```

### 核心部分の実装

#### 1. Facadeパターン（サービス統合）

```go
// ApplicationFacade はマイクロサービス群を統合
type ApplicationFacade struct {
    userService         *UserService
    orderService        *OrderService
    notificationService *NotificationService
    eventBus            *EventBus
}

func NewApplicationFacade(
    userSvc *UserService,
    orderSvc *OrderService,
    notifSvc *NotificationService,
    eventBus *EventBus,
) *ApplicationFacade {
    return &ApplicationFacade{
        userService:         userSvc,
        orderService:        orderSvc,
        notificationService: notifSvc,
        eventBus:            eventBus,
    }
}

// 複雑な処理を単一メソッドで提供
func (f *ApplicationFacade) PlaceOrder(ctx context.Context, userID int, items []OrderItem) (*OrderResponse, error) {
    // 1. ユーザー確認
    user, err := f.userService.GetUser(ctx, userID)
    if err != nil {
        return nil, fmt.Errorf("user not found: %w", err)
    }

    // 2. 注文作成
    order, err := f.orderService.CreateOrder(ctx, userID, items)
    if err != nil {
        return nil, fmt.Errorf("create order failed: %w", err)
    }

    // 3. イベント発行（非同期）
    f.eventBus.Publish(&OrderCreatedEvent{
        OrderID:    order.ID,
        UserID:     userID,
        UserEmail:  user.Email,
        TotalPrice: order.TotalPrice,
    })

    return &OrderResponse{
        OrderID: order.ID,
        Status:  "confirmed",
        Message: fmt.Sprintf("Order placed successfully for %s", user.Name),
    }, nil
}

// 他の複雑な操作も統合
func (f *ApplicationFacade) CancelOrder(ctx context.Context, orderID, userID int) error {
    // 権限確認
    order, err := f.orderService.GetOrder(ctx, orderID)
    if err != nil {
        return err
    }

    if order.UserID != userID {
        return fmt.Errorf("permission denied")
    }

    // キャンセル処理
    if err := f.orderService.CancelOrder(ctx, orderID); err != nil {
        return err
    }

    // イベント発行
    f.eventBus.Publish(&OrderCancelledEvent{
        OrderID: orderID,
        UserID:  userID,
    })

    return nil
}
```

#### 2. Observerパターン（イベント駆動）

```go
// Event interface
type Event interface {
    GetEventType() string
}

// 注文作成イベント
type OrderCreatedEvent struct {
    OrderID    int
    UserID     int
    UserEmail  string
    TotalPrice float64
}

func (e *OrderCreatedEvent) GetEventType() string {
    return "order.created"
}

// 注文キャンセルイベント
type OrderCancelledEvent struct {
    OrderID int
    UserID  int
}

func (e *OrderCancelledEvent) GetEventType() string {
    return "order.cancelled"
}

// Event Subscriber interface
type EventSubscriber interface {
    OnEvent(event Event)
}

// EventBus（Pub/Subパターン）
type EventBus struct {
    subscribers map[string][]EventSubscriber
    mu          sync.RWMutex
}

func NewEventBus() *EventBus {
    return &EventBus{
        subscribers: make(map[string][]EventSubscriber),
    }
}

func (bus *EventBus) Subscribe(eventType string, subscriber EventSubscriber) {
    bus.mu.Lock()
    defer bus.mu.Unlock()

    bus.subscribers[eventType] = append(bus.subscribers[eventType], subscriber)
}

func (bus *EventBus) Publish(event Event) {
    bus.mu.RLock()
    defer bus.mu.RUnlock()

    eventType := event.GetEventType()
    for _, subscriber := range bus.subscribers[eventType] {
        go subscriber.OnEvent(event)
    }
}

// メール通知サービス（Subscriber）
type EmailNotificationSubscriber struct {
    emailService EmailService
}

func (s *EmailNotificationSubscriber) OnEvent(event Event) {
    switch e := event.(type) {
    case *OrderCreatedEvent:
        subject := "Order Confirmation"
        body := fmt.Sprintf("Your order #%d has been confirmed. Total: $%.2f", e.OrderID, e.TotalPrice)
        s.emailService.Send(e.UserEmail, subject, body)

    case *OrderCancelledEvent:
        // キャンセル通知
        log.Printf("Order %d cancelled", e.OrderID)
    }
}

// 在庫サービス（Subscriber）
type InventorySubscriber struct {
    inventoryService InventoryService
}

func (s *InventorySubscriber) OnEvent(event Event) {
    switch e := event.(type) {
    case *OrderCreatedEvent:
        // 在庫減算
        log.Printf("Reducing inventory for order %d", e.OrderID)

    case *OrderCancelledEvent:
        // 在庫復元
        log.Printf("Restoring inventory for order %d", e.OrderID)
    }
}
```

#### 3. Circuit Breaker（障害分離）

```go
// サービスごとにCircuit Breakerを適用
type ResilientUserService struct {
    service *UserService
    breaker *CircuitBreaker
}

func NewResilientUserService(service *UserService, breaker *CircuitBreaker) *ResilientUserService {
    return &ResilientUserService{
        service: service,
        breaker: breaker,
    }
}

func (s *ResilientUserService) GetUser(ctx context.Context, userID int) (*User, error) {
    result, err := s.breaker.Execute(func() (interface{}, error) {
        return s.service.GetUser(ctx, userID)
    })

    if err != nil {
        // フォールバック：キャッシュから取得
        log.Printf("User service unavailable, using fallback")
        return s.getUserFromCache(userID)
    }

    return result.(*User), nil
}

func (s *ResilientUserService) getUserFromCache(userID int) (*User, error) {
    // キャッシュ実装
    return &User{ID: userID, Name: "Fallback User"}, nil
}

// サービスごとにCircuit Breakerを管理
type CircuitBreakerFactory struct {
    breakers map[string]*CircuitBreaker
    mu       sync.Mutex
}

func NewCircuitBreakerFactory() *CircuitBreakerFactory {
    return &CircuitBreakerFactory{
        breakers: make(map[string]*CircuitBreaker),
    }
}

func (f *CircuitBreakerFactory) GetBreaker(serviceName string) *CircuitBreaker {
    f.mu.Lock()
    defer f.mu.Unlock()

    if breaker, exists := f.breakers[serviceName]; exists {
        return breaker
    }

    breaker := NewCircuitBreaker(3, 10*time.Second)
    f.breakers[serviceName] = breaker
    return breaker
}
```

### 統合使用例

```go
func main() {
    // Circuit Breaker Factory
    breakerFactory := NewCircuitBreakerFactory()

    // 各サービス初期化
    userService := NewUserService(userDB)
    resilientUserSvc := NewResilientUserService(userService, breakerFactory.GetBreaker("user"))

    orderService := NewOrderService(orderDB)
    notificationService := NewNotificationService()

    // Event Bus
    eventBus := NewEventBus()

    // Subscriber登録
    emailSubscriber := &EmailNotificationSubscriber{emailService: emailSvc}
    inventorySubscriber := &InventorySubscriber{inventoryService: inventorySvc}

    eventBus.Subscribe("order.created", emailSubscriber)
    eventBus.Subscribe("order.created", inventorySubscriber)
    eventBus.Subscribe("order.cancelled", inventorySubscriber)

    // Facade
    facade := NewApplicationFacade(resilientUserSvc, orderService, notificationService, eventBus)

    // 注文処理
    items := []OrderItem{
        {ProductID: 1, Quantity: 2},
    }

    resp, err := facade.PlaceOrder(context.Background(), 123, items)
    if err != nil {
        log.Fatalf("Place order failed: %v", err)
    }

    fmt.Printf("Order Response: %+v\n", resp)
}
```

### パターン選択の判断基準

| 要件 | パターン | 理由 |
|------|---------|------|
| 複雑なサービス群の単純化 | Facade | 複数サービスの呼び出しを1つのAPIに集約 |
| サービス間の非同期連携 | Observer（Event Bus） | サービス追加・削除が容易な疎結合設計 |
| 部分的障害からの保護 | Circuit Breaker | 一部サービス障害が全体に波及しない |

---

## 総括：パターン適用の実践ポイント

### 複数パターンの組み合わせ原則

1. **責務の分離**: 各パターンが異なる責務を担当（例：Command = 操作、Observer = 通知）
2. **段階的導入**: 最初はシンプルに実装し、必要に応じてパターンを追加
3. **トレードオフの理解**: パターン導入でコード量は増えるが、保守性・拡張性が向上

### 実プロジェクトへの適用ステップ

1. **現状分析**: Code Smellを特定（`gocyclo`, `staticcheck`）
2. **パターン選択**: 上記ケーススタディを参考に適切なパターンを選定
3. **段階的移行**: テストを書きながら1パターンずつ導入
4. **レビューと改善**: チームでパターン適用の妥当性をレビュー

### 避けるべきパターン乱用

- **過度な抽象化**: 実装が1つしかないのにFactory/Strategyを導入
- **パターンのための実装**: ビジネス要件ではなくパターン適用が目的化
- **理解なき模倣**: パターンの意図を理解せずにコピー&ペースト
