# Goにおける高度なデザインパターン

本ドキュメントでは、Goにおける高度なデザインパターンと実装テクニックを解説する。

---

## 1. 依存性注入フレームワーク

手動DIが困難な大規模アプリケーションでは、DIフレームワークの活用が有効である。

### 1.1 google/wire（コンパイル時DI）

**特徴:**
- コード生成ベースのDI
- コンパイル時に依存関係を解決
- ランタイムオーバーヘッドなし
- 型安全性が保証される

**実装例:**

```go
// wire.go (injector定義)
//go:build wireinject

package main

import "github.com/google/wire"

func InitializeApp() (*App, error) {
    wire.Build(
        NewDB,
        NewUserRepository,
        NewUserService,
        NewApp,
    )
    return nil, nil
}
```

```go
// main.go
package main

func main() {
    app, err := InitializeApp()
    if err != nil {
        log.Fatal(err)
    }
    app.Run()
}
```

**生成されるコード:**

```go
// wire_gen.go (自動生成)
func InitializeApp() (*App, error) {
    db := NewDB()
    userRepository := NewUserRepository(db)
    userService := NewUserService(userRepository)
    app := NewApp(userService)
    return app, nil
}
```

### 1.2 uber-go/fx（ランタイムDI）

**特徴:**
- ランタイムDI
- ライフサイクル管理機能
- 大規模アプリケーション向け
- グラフベースの依存関係解決

**実装例:**

```go
package main

import (
    "context"
    "go.uber.org/fx"
)

func main() {
    fx.New(
        fx.Provide(
            NewDB,
            NewUserRepository,
            NewUserService,
            NewHTTPServer,
        ),
        fx.Invoke(RegisterRoutes),
    ).Run()
}

func NewHTTPServer(lc fx.Lifecycle, service *UserService) *http.Server {
    server := &http.Server{Addr: ":8080"}

    lc.Append(fx.Hook{
        OnStart: func(ctx context.Context) error {
            go server.ListenAndServe()
            return nil
        },
        OnStop: func(ctx context.Context) error {
            return server.Shutdown(ctx)
        },
    })

    return server
}
```

### 1.3 samber/do（シンプルなDIコンテナ）

**特徴:**
- 軽量でシンプル
- Genericsベース
- 明示的なコンテナ管理

**実装例:**

```go
package main

import "github.com/samber/do"

func main() {
    injector := do.New()

    do.Provide(injector, NewDB)
    do.Provide(injector, NewUserRepository)
    do.Provide(injector, NewUserService)

    service := do.MustInvoke[*UserService](injector)
    service.CreateUser("Alice")
}

func NewUserRepository(i *do.Injector) (*UserRepository, error) {
    db := do.MustInvoke[*DB](i)
    return &UserRepository{db: db}, nil
}
```

### 1.4 DIフレームワークの選定基準

| プロジェクト規模 | 推奨フレームワーク | 理由 |
|--------------|-----------------|------|
| 小規模（<10 struct） | 手動DI | シンプルで理解しやすい |
| 中規模（10-50 struct） | google/wire | コンパイル時検証、ゼロオーバーヘッド |
| 大規模（50+ struct） | uber-go/fx | ライフサイクル管理、動的な依存解決 |
| 最小限のDI | samber/do | 学習コスト低、軽量 |

---

## 2. Event Sourcing パターン

**目的:** 状態変更をイベントの列として保存し、現在の状態はイベントを順に再生して導出する。

### 2.1 基本構造

```go
package eventsourcing

import (
    "encoding/json"
    "time"
)

// Event はドメインで発生した事実を表現
type Event struct {
    Type         string          `json:"type"`
    AggregateID  string          `json:"aggregate_id"`
    Data         json.RawMessage `json:"data"`
    Timestamp    time.Time       `json:"timestamp"`
    Version      int             `json:"version"`
}

// EventStore はイベントの永続化インターフェース
type EventStore interface {
    Append(aggregateID string, events []Event) error
    GetEvents(aggregateID string) ([]Event, error)
    GetEventsByType(eventType string) ([]Event, error)
}
```

### 2.2 Aggregate + Event Sourcing

```go
package account

import (
    "errors"
    "github.com/google/uuid"
)

// AccountCreatedEvent
type AccountCreatedEvent struct {
    AccountID string  `json:"account_id"`
    Owner     string  `json:"owner"`
}

// DepositedEvent
type DepositedEvent struct {
    Amount float64 `json:"amount"`
}

// WithdrawnEvent
type WithdrawnEvent struct {
    Amount float64 `json:"amount"`
}

// Account はAggregateルート
type Account struct {
    ID      string
    Owner   string
    Balance float64
    Version int

    // 未コミットイベント
    uncommittedEvents []Event
}

// NewAccount はコマンドを受けて新しいアカウントを作成
func NewAccount(owner string) (*Account, error) {
    if owner == "" {
        return nil, errors.New("owner cannot be empty")
    }

    account := &Account{}
    event := Event{
        Type:        "AccountCreated",
        AggregateID: uuid.New().String(),
        Data:        AccountCreatedEvent{Owner: owner},
        Timestamp:   time.Now(),
    }

    account.Apply(event)
    account.uncommittedEvents = append(account.uncommittedEvents, event)

    return account, nil
}

// Deposit は入金コマンド
func (a *Account) Deposit(amount float64) error {
    if amount <= 0 {
        return errors.New("amount must be positive")
    }

    event := Event{
        Type:        "Deposited",
        AggregateID: a.ID,
        Data:        DepositedEvent{Amount: amount},
        Timestamp:   time.Now(),
        Version:     a.Version + 1,
    }

    a.Apply(event)
    a.uncommittedEvents = append(a.uncommittedEvents, event)

    return nil
}

// Withdraw は出金コマンド
func (a *Account) Withdraw(amount float64) error {
    if amount <= 0 {
        return errors.New("amount must be positive")
    }
    if a.Balance < amount {
        return errors.New("insufficient balance")
    }

    event := Event{
        Type:        "Withdrawn",
        AggregateID: a.ID,
        Data:        WithdrawnEvent{Amount: amount},
        Timestamp:   time.Now(),
        Version:     a.Version + 1,
    }

    a.Apply(event)
    a.uncommittedEvents = append(a.uncommittedEvents, event)

    return nil
}

// Apply はイベントを適用して状態を更新
func (a *Account) Apply(event Event) {
    switch event.Type {
    case "AccountCreated":
        data := event.Data.(AccountCreatedEvent)
        a.ID = event.AggregateID
        a.Owner = data.Owner
        a.Balance = 0
    case "Deposited":
        data := event.Data.(DepositedEvent)
        a.Balance += data.Amount
    case "Withdrawn":
        data := event.Data.(WithdrawnEvent)
        a.Balance -= data.Amount
    }
    a.Version = event.Version
}

// Rebuild はイベント列から現在の状態を再構築
func (a *Account) Rebuild(events []Event) {
    for _, event := range events {
        a.Apply(event)
    }
}

// GetUncommittedEvents は未コミットイベントを返す
func (a *Account) GetUncommittedEvents() []Event {
    return a.uncommittedEvents
}

// MarkEventsAsCommitted はイベントをコミット済みとしてマーク
func (a *Account) MarkEventsAsCommitted() {
    a.uncommittedEvents = nil
}
```

### 2.3 リポジトリパターンとの統合

```go
package account

type AccountRepository struct {
    eventStore EventStore
}

func NewAccountRepository(store EventStore) *AccountRepository {
    return &AccountRepository{eventStore: store}
}

// Save はAggregateの未コミットイベントを保存
func (r *AccountRepository) Save(account *Account) error {
    events := account.GetUncommittedEvents()
    if len(events) == 0 {
        return nil
    }

    err := r.eventStore.Append(account.ID, events)
    if err != nil {
        return err
    }

    account.MarkEventsAsCommitted()
    return nil
}

// Load はイベントを再生してAggregateを復元
func (r *AccountRepository) Load(accountID string) (*Account, error) {
    events, err := r.eventStore.GetEvents(accountID)
    if err != nil {
        return nil, err
    }
    if len(events) == 0 {
        return nil, errors.New("account not found")
    }

    account := &Account{}
    account.Rebuild(events)

    return account, nil
}
```

### 2.4 スナップショット戦略

大量のイベントを再生するコストを削減するため、定期的にスナップショットを作成する。

```go
type Snapshot struct {
    AggregateID string
    Version     int
    State       interface{}
    Timestamp   time.Time
}

type SnapshotStore interface {
    Save(snapshot Snapshot) error
    Load(aggregateID string) (*Snapshot, error)
}

func (r *AccountRepository) LoadWithSnapshot(accountID string) (*Account, error) {
    // スナップショットから復元
    snapshot, err := r.snapshotStore.Load(accountID)
    if err == nil && snapshot != nil {
        account := snapshot.State.(*Account)

        // スナップショット以降のイベントのみ再生
        events, err := r.eventStore.GetEventsAfterVersion(accountID, snapshot.Version)
        if err != nil {
            return nil, err
        }
        account.Rebuild(events)
        return account, nil
    }

    // スナップショットがない場合は全イベントを再生
    return r.Load(accountID)
}
```

### 2.5 利点と注意点

**利点:**
- 完全な監査ログ（すべての変更履歴が保存される）
- 任意時点への状態復元（タイムトラベル）
- イベントリプレイによる分析とデバッグ
- Read Modelの再構築が可能

**注意点:**
- イベントスキーマの進化管理が必要
- 大量のイベントは再生コストが高い（スナップショット戦略が必須）
- イベントの削除は不可（GDPR対応が困難）

---

## 3. CQRS（Command Query Responsibility Segregation）パターン

**目的:** 読み取り（Query）と書き込み（Command）の責任を分離し、それぞれを最適化する。

### 3.1 Command側の実装

```go
package cqrs

// Command はシステムへの操作要求
type Command interface {
    CommandName() string
}

// CommandHandler はコマンドを処理
type CommandHandler interface {
    Handle(cmd Command) error
}

// CreateUserCommand
type CreateUserCommand struct {
    Name  string
    Email string
}

func (c CreateUserCommand) CommandName() string {
    return "CreateUser"
}

// CreateUserHandler
type CreateUserHandler struct {
    repo UserRepository
    bus  EventBus
}

func (h *CreateUserHandler) Handle(cmd Command) error {
    c := cmd.(CreateUserCommand)

    // ドメインロジックを実行
    user := &User{
        ID:    uuid.New().String(),
        Name:  c.Name,
        Email: c.Email,
    }

    // 書き込み用リポジトリに保存
    if err := h.repo.Save(user); err != nil {
        return err
    }

    // イベントを発行してRead Model更新をトリガー
    event := UserCreatedEvent{
        UserID: user.ID,
        Name:   user.Name,
        Email:  user.Email,
    }
    h.bus.Publish(event)

    return nil
}
```

### 3.2 Query側の実装

```go
package cqrs

// Query は情報取得の要求
type Query interface {
    QueryName() string
}

// QueryHandler はクエリを処理
type QueryHandler interface {
    Handle(query Query) (interface{}, error)
}

// GetUserQuery
type GetUserQuery struct {
    UserID string
}

func (q GetUserQuery) QueryName() string {
    return "GetUser"
}

// UserReadModel は読み取り最適化されたモデル
type UserReadModel struct {
    ID        string
    Name      string
    Email     string
    CreatedAt time.Time
    PostCount int // 集計データも含む
}

// GetUserHandler
type GetUserHandler struct {
    readRepo UserReadRepository // 読み取り専用リポジトリ
}

func (h *GetUserHandler) Handle(query Query) (interface{}, error) {
    q := query.(GetUserQuery)

    // 読み取り最適化されたデータストアから取得
    user, err := h.readRepo.FindByID(q.UserID)
    if err != nil {
        return nil, err
    }

    return user, nil
}

// ListUsersQuery
type ListUsersQuery struct {
    Page     int
    PageSize int
    SortBy   string
}

func (q ListUsersQuery) QueryName() string {
    return "ListUsers"
}

// ListUsersHandler
type ListUsersHandler struct {
    readRepo UserReadRepository
}

func (h *ListUsersHandler) Handle(query Query) (interface{}, error) {
    q := query.(ListUsersQuery)

    // ページネーションとソートを含む複雑なクエリ
    users, err := h.readRepo.List(q.Page, q.PageSize, q.SortBy)
    if err != nil {
        return nil, err
    }

    return users, nil
}
```

### 3.3 Command/Query Busの実装

```go
package cqrs

import "sync"

// CommandBus はコマンドをハンドラーにルーティング
type CommandBus struct {
    handlers map[string]CommandHandler
    mu       sync.RWMutex
}

func NewCommandBus() *CommandBus {
    return &CommandBus{
        handlers: make(map[string]CommandHandler),
    }
}

func (b *CommandBus) Register(cmdName string, handler CommandHandler) {
    b.mu.Lock()
    defer b.mu.Unlock()
    b.handlers[cmdName] = handler
}

func (b *CommandBus) Execute(cmd Command) error {
    b.mu.RLock()
    handler, ok := b.handlers[cmd.CommandName()]
    b.mu.RUnlock()

    if !ok {
        return errors.New("no handler registered for command: " + cmd.CommandName())
    }

    return handler.Handle(cmd)
}

// QueryBus はクエリをハンドラーにルーティング
type QueryBus struct {
    handlers map[string]QueryHandler
    mu       sync.RWMutex
}

func NewQueryBus() *QueryBus {
    return &QueryBus{
        handlers: make(map[string]QueryHandler),
    }
}

func (b *QueryBus) Register(queryName string, handler QueryHandler) {
    b.mu.Lock()
    defer b.mu.Unlock()
    b.handlers[queryName] = handler
}

func (b *QueryBus) Execute(query Query) (interface{}, error) {
    b.mu.RLock()
    handler, ok := b.handlers[query.QueryName()]
    b.mu.RUnlock()

    if !ok {
        return nil, errors.New("no handler registered for query: " + query.QueryName())
    }

    return handler.Handle(query)
}
```

### 3.4 Event SourcingとCQRSの組み合わせ

```go
package cqrs

// EventBus はイベントを購読者に配信
type EventBus struct {
    subscribers map[string][]EventHandler
    mu          sync.RWMutex
}

type EventHandler func(event interface{}) error

func NewEventBus() *EventBus {
    return &EventBus{
        subscribers: make(map[string][]EventHandler),
    }
}

func (b *EventBus) Subscribe(eventType string, handler EventHandler) {
    b.mu.Lock()
    defer b.mu.Unlock()
    b.subscribers[eventType] = append(b.subscribers[eventType], handler)
}

func (b *EventBus) Publish(event interface{}) {
    eventType := reflect.TypeOf(event).Name()

    b.mu.RLock()
    handlers := b.subscribers[eventType]
    b.mu.RUnlock()

    for _, handler := range handlers {
        go handler(event) // 非同期で処理
    }
}

// Read Model更新ハンドラー
type UserReadModelUpdater struct {
    readRepo UserReadRepository
}

func (u *UserReadModelUpdater) OnUserCreated(event interface{}) error {
    e := event.(UserCreatedEvent)

    readModel := &UserReadModel{
        ID:        e.UserID,
        Name:      e.Name,
        Email:     e.Email,
        CreatedAt: time.Now(),
        PostCount: 0,
    }

    return u.readRepo.Save(readModel)
}
```

### 3.5 実用例：ECサイト

```go
// Command側：注文の書き込み
type PlaceOrderCommand struct {
    UserID  string
    Items   []OrderItem
    Address string
}

type PlaceOrderHandler struct {
    orderRepo OrderRepository
    eventBus  EventBus
}

func (h *PlaceOrderHandler) Handle(cmd Command) error {
    c := cmd.(PlaceOrderCommand)

    order := NewOrder(c.UserID, c.Items, c.Address)
    if err := h.orderRepo.Save(order); err != nil {
        return err
    }

    // Read Model更新イベント発行
    h.eventBus.Publish(OrderPlacedEvent{OrderID: order.ID})

    return nil
}

// Query側：商品検索の読み取り
type SearchProductsQuery struct {
    Keyword  string
    Category string
    MinPrice float64
    MaxPrice float64
}

type SearchProductsHandler struct {
    searchIndex ProductSearchIndex // Elasticsearchなど
}

func (h *SearchProductsHandler) Handle(query Query) (interface{}, error) {
    q := query.(SearchProductsQuery)

    // 検索に最適化されたインデックスから取得
    products, err := h.searchIndex.Search(q.Keyword, q.Category, q.MinPrice, q.MaxPrice)
    if err != nil {
        return nil, err
    }

    return products, nil
}
```

### 3.6 利点と注意点

**利点:**
- 読み書きで異なるデータストアを使用可能（PostgreSQL + Elasticsearch等）
- 読み取りクエリを集計・非正規化データで最適化
- スケーラビリティ向上（読み書きを独立してスケール）

**注意点:**
- Read Modelの最終的整合性（eventual consistency）を許容する必要がある
- インフラの複雑性が増す

---

## 4. マイクロサービスデザインパターン

### 4.1 API Gateway パターン

**目的:** クライアントからの単一エントリポイントを提供し、複数のマイクロサービスへリクエストをルーティング。

```go
package gateway

import (
    "net/http"
    "net/http/httputil"
    "net/url"
    "strings"
)

type Gateway struct {
    services map[string]*httputil.ReverseProxy
    auth     AuthService
    limiter  RateLimiter
}

func NewGateway(serviceMap map[string]string, auth AuthService, limiter RateLimiter) *Gateway {
    services := make(map[string]*httputil.ReverseProxy)

    for name, target := range serviceMap {
        targetURL, _ := url.Parse(target)
        services[name] = httputil.NewSingleHostReverseProxy(targetURL)
    }

    return &Gateway{
        services: services,
        auth:     auth,
        limiter:  limiter,
    }
}

func (g *Gateway) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    // 認証チェック
    if !g.auth.Authenticate(r) {
        http.Error(w, "Unauthorized", http.StatusUnauthorized)
        return
    }

    // レート制限
    if !g.limiter.Allow(r) {
        http.Error(w, "Too Many Requests", http.StatusTooManyRequests)
        return
    }

    // サービス名抽出（例: /users/123 → users）
    serviceName := extractServiceName(r.URL.Path)

    proxy, ok := g.services[serviceName]
    if !ok {
        http.Error(w, "Service Not Found", http.StatusNotFound)
        return
    }

    // リクエストをサービスにプロキシ
    proxy.ServeHTTP(w, r)
}

func extractServiceName(path string) string {
    parts := strings.Split(strings.Trim(path, "/"), "/")
    if len(parts) > 0 {
        return parts[0]
    }
    return ""
}
```

### 4.2 Service Discovery パターン

**目的:** サービスの動的な登録と発見。

```go
package discovery

import (
    "context"
    "time"
)

// ServiceRegistry はサービスの登録と発見を管理
type ServiceRegistry interface {
    Register(ctx context.Context, service ServiceInfo) error
    Deregister(ctx context.Context, serviceID string) error
    Discover(ctx context.Context, serviceName string) ([]ServiceInfo, error)
    HealthCheck(ctx context.Context, serviceID string) error
}

type ServiceInfo struct {
    ID      string
    Name    string
    Address string
    Port    int
    Tags    []string
}

// Consulベースの実装例
type ConsulRegistry struct {
    client *consul.Client
}

func (r *ConsulRegistry) Register(ctx context.Context, service ServiceInfo) error {
    registration := &consul.AgentServiceRegistration{
        ID:      service.ID,
        Name:    service.Name,
        Address: service.Address,
        Port:    service.Port,
        Tags:    service.Tags,
        Check: &consul.AgentServiceCheck{
            HTTP:     fmt.Sprintf("http://%s:%d/health", service.Address, service.Port),
            Interval: "10s",
            Timeout:  "2s",
        },
    }

    return r.client.Agent().ServiceRegister(registration)
}

func (r *ConsulRegistry) Discover(ctx context.Context, serviceName string) ([]ServiceInfo, error) {
    services, _, err := r.client.Health().Service(serviceName, "", true, nil)
    if err != nil {
        return nil, err
    }

    var result []ServiceInfo
    for _, service := range services {
        result = append(result, ServiceInfo{
            ID:      service.Service.ID,
            Name:    service.Service.Service,
            Address: service.Service.Address,
            Port:    service.Service.Port,
            Tags:    service.Service.Tags,
        })
    }

    return result, nil
}

// クライアントサイドロードバランシング
type LoadBalancedClient struct {
    registry  ServiceRegistry
    balancer  LoadBalancer
    transport *http.Transport
}

func (c *LoadBalancedClient) Call(ctx context.Context, serviceName, path string) (*http.Response, error) {
    // サービスインスタンスを発見
    instances, err := c.registry.Discover(ctx, serviceName)
    if err != nil {
        return nil, err
    }

    // ロードバランシング
    instance := c.balancer.Choose(instances)

    // リクエスト実行
    url := fmt.Sprintf("http://%s:%d%s", instance.Address, instance.Port, path)
    req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)

    return http.DefaultClient.Do(req)
}
```

### 4.3 Saga パターン（分散トランザクション）

**目的:** 複数のマイクロサービスにまたがるトランザクションを管理。

#### Choreography（イベント駆動）

```go
package saga

// OrderService
type OrderService struct {
    eventBus EventBus
}

func (s *OrderService) CreateOrder(order Order) error {
    // 1. 注文を作成
    if err := s.repo.Save(order); err != nil {
        return err
    }

    // 2. イベント発行
    s.eventBus.Publish(OrderCreatedEvent{OrderID: order.ID, UserID: order.UserID, Amount: order.Amount})

    return nil
}

func (s *OrderService) OnPaymentFailed(event PaymentFailedEvent) error {
    // 補償トランザクション：注文をキャンセル
    order, _ := s.repo.FindByID(event.OrderID)
    order.Status = "Cancelled"
    return s.repo.Save(order)
}

// PaymentService
type PaymentService struct {
    eventBus EventBus
}

func (s *PaymentService) OnOrderCreated(event OrderCreatedEvent) error {
    // 決済処理
    payment := Payment{OrderID: event.OrderID, Amount: event.Amount}

    if err := s.processPayment(payment); err != nil {
        // 失敗イベント発行
        s.eventBus.Publish(PaymentFailedEvent{OrderID: event.OrderID})
        return err
    }

    // 成功イベント発行
    s.eventBus.Publish(PaymentSucceededEvent{OrderID: event.OrderID})
    return nil
}

// ShippingService
type ShippingService struct {
    eventBus EventBus
}

func (s *ShippingService) OnPaymentSucceeded(event PaymentSucceededEvent) error {
    // 配送手配
    shipping := Shipping{OrderID: event.OrderID}
    return s.repo.Save(shipping)
}
```

#### Orchestration（中央制御）

```go
package saga

// OrderSagaOrchestrator は中央制御型Saga
type OrderSagaOrchestrator struct {
    orderService    OrderService
    paymentService  PaymentService
    shippingService ShippingService
}

func (o *OrderSagaOrchestrator) ExecuteOrderSaga(order Order) error {
    // 1. 注文作成
    if err := o.orderService.CreateOrder(order); err != nil {
        return err
    }

    // 2. 決済処理
    if err := o.paymentService.ProcessPayment(order.ID, order.Amount); err != nil {
        // 補償：注文キャンセル
        o.orderService.CancelOrder(order.ID)
        return err
    }

    // 3. 配送手配
    if err := o.shippingService.ArrangeShipping(order.ID); err != nil {
        // 補償：決済返金 + 注文キャンセル
        o.paymentService.RefundPayment(order.ID)
        o.orderService.CancelOrder(order.ID)
        return err
    }

    return nil
}
```

### 4.4 Sidecar パターン

**目的:** サービスに付随する補助プロセス（ログ収集、メトリクス送信等）を分離。

```go
package sidecar

// LogSidecar はメインサービスのログを収集
type LogSidecar struct {
    logFile   string
    collector LogCollector
}

func (s *LogSidecar) Start(ctx context.Context) error {
    ticker := time.NewTicker(5 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return nil
        case <-ticker.C:
            logs, err := s.readLogs()
            if err != nil {
                continue
            }
            s.collector.Send(logs)
        }
    }
}

func (s *LogSidecar) readLogs() ([]LogEntry, error) {
    // ログファイルを読み取り
    // ...
}
```

### 4.5 マイクロサービスのベストプラクティス

#### 原則

- **Single Responsibility**: 1サービス = 1責任
- **Interface-based Boundaries**: interfaceでサービス境界を定義
- **独立したデータストア**: 各サービスが独自のDBを持つ

#### 実装例

```go
package service

// UserServiceはinterfaceで定義
type UserService interface {
    CreateUser(ctx context.Context, user User) error
    GetUser(ctx context.Context, userID string) (*User, error)
}

type userService struct {
    repo UserRepository
}

func NewUserService(repo UserRepository) UserService {
    return &userService{repo: repo}
}

func (s *userService) CreateUser(ctx context.Context, user User) error {
    // ビジネスロジック
    if err := user.Validate(); err != nil {
        return err
    }
    return s.repo.Save(ctx, user)
}
```

#### エラーハンドリング

```go
package errors

import "google.golang.org/grpc/codes"

// ServiceError はgRPCコードを含むエラー
type ServiceError struct {
    Code    codes.Code
    Message string
    Details map[string]interface{}
}

func (e ServiceError) Error() string {
    return e.Message
}

func NewNotFoundError(resource string) error {
    return ServiceError{
        Code:    codes.NotFound,
        Message: fmt.Sprintf("%s not found", resource),
    }
}
```

#### ログとメトリクス

```go
package observability

import "go.uber.org/zap"

type Service struct {
    logger  *zap.Logger
    metrics MetricsCollector
}

func (s *Service) ProcessRequest(ctx context.Context, req Request) error {
    start := time.Now()
    defer func() {
        s.metrics.RecordDuration("process_request", time.Since(start))
    }()

    s.logger.Info("processing request", zap.String("request_id", req.ID))

    if err := s.process(ctx, req); err != nil {
        s.logger.Error("failed to process", zap.Error(err))
        s.metrics.IncrementCounter("request_errors")
        return err
    }

    s.metrics.IncrementCounter("request_success")
    return nil
}
```

---

## 5. Reactive Programming パターン

**目的:** 非同期データストリームと変更の伝播を効率的に処理。

### 5.1 Observer パターン（goroutine + channel）

```go
package reactive

import "sync"

// Subject は観察対象
type Subject struct {
    observers []chan string
    mu        sync.RWMutex
}

func NewSubject() *Subject {
    return &Subject{
        observers: make([]chan string, 0),
    }
}

// Attach はオブザーバーを登録
func (s *Subject) Attach(observer chan string) {
    s.mu.Lock()
    defer s.mu.Unlock()
    s.observers = append(s.observers, observer)
}

// Detach はオブザーバーを解除
func (s *Subject) Detach(observer chan string) {
    s.mu.Lock()
    defer s.mu.Unlock()

    for i, obs := range s.observers {
        if obs == observer {
            s.observers = append(s.observers[:i], s.observers[i+1:]...)
            close(observer)
            return
        }
    }
}

// Notify はすべてのオブザーバーに通知
func (s *Subject) Notify(data string) {
    s.mu.RLock()
    defer s.mu.RUnlock()

    for _, observer := range s.observers {
        go func(ch chan string) {
            ch <- data
        }(observer)
    }
}

// 使用例
func main() {
    subject := NewSubject()

    observer1 := make(chan string, 10)
    observer2 := make(chan string, 10)

    subject.Attach(observer1)
    subject.Attach(observer2)

    go func() {
        for data := range observer1 {
            fmt.Println("Observer1 received:", data)
        }
    }()

    go func() {
        for data := range observer2 {
            fmt.Println("Observer2 received:", data)
        }
    }()

    subject.Notify("Event 1")
    subject.Notify("Event 2")
}
```

### 5.2 Reactive Streamsパターン

```go
package reactive

// Stream はデータのストリーム
type Stream struct {
    source <-chan interface{}
}

func NewStream(source <-chan interface{}) *Stream {
    return &Stream{source: source}
}

// Map は各要素に関数を適用
func (s *Stream) Map(fn func(interface{}) interface{}) *Stream {
    out := make(chan interface{})

    go func() {
        defer close(out)
        for item := range s.source {
            out <- fn(item)
        }
    }()

    return NewStream(out)
}

// Filter は条件を満たす要素のみ通過
func (s *Stream) Filter(predicate func(interface{}) bool) *Stream {
    out := make(chan interface{})

    go func() {
        defer close(out)
        for item := range s.source {
            if predicate(item) {
                out <- item
            }
        }
    }()

    return NewStream(out)
}

// Reduce は累積処理
func (s *Stream) Reduce(initial interface{}, reducer func(interface{}, interface{}) interface{}) interface{} {
    result := initial
    for item := range s.source {
        result = reducer(result, item)
    }
    return result
}

// Take は最初のn個のみ取得
func (s *Stream) Take(n int) *Stream {
    out := make(chan interface{})

    go func() {
        defer close(out)
        count := 0
        for item := range s.source {
            if count >= n {
                return
            }
            out <- item
            count++
        }
    }()

    return NewStream(out)
}

// 使用例
func main() {
    source := make(chan interface{})

    go func() {
        for i := 1; i <= 10; i++ {
            source <- i
        }
        close(source)
    }()

    stream := NewStream(source).
        Filter(func(v interface{}) bool {
            return v.(int)%2 == 0
        }).
        Map(func(v interface{}) interface{} {
            return v.(int) * 2
        }).
        Take(3)

    for item := range stream.source {
        fmt.Println(item) // 4, 8, 12
    }
}
```

### 5.3 Back Pressureパターン

**目的:** プロデューサーとコンシューマーの速度差を調整し、システムの過負荷を防ぐ。

```go
package reactive

import (
    "context"
    "time"
)

// BackPressureStream はバックプレッシャーを実装
type BackPressureStream struct {
    buffer chan interface{}
    ctx    context.Context
}

func NewBackPressureStream(ctx context.Context, bufferSize int) *BackPressureStream {
    return &BackPressureStream{
        buffer: make(chan interface{}, bufferSize),
        ctx:    ctx,
    }
}

// Produce はデータを生成（ブロッキング）
func (s *BackPressureStream) Produce(data interface{}) error {
    select {
    case s.buffer <- data:
        return nil
    case <-s.ctx.Done():
        return s.ctx.Err()
    case <-time.After(5 * time.Second):
        return errors.New("produce timeout: consumer is slow")
    }
}

// Consume はデータを消費
func (s *BackPressureStream) Consume() <-chan interface{} {
    return s.buffer
}

// 使用例
func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    stream := NewBackPressureStream(ctx, 10)

    // プロデューサー
    go func() {
        for i := 0; i < 100; i++ {
            if err := stream.Produce(i); err != nil {
                fmt.Println("Produce error:", err)
                return
            }
        }
    }()

    // スローコンシューマー
    for item := range stream.Consume() {
        fmt.Println("Consumed:", item)
        time.Sleep(100 * time.Millisecond)
    }
}
```

### 5.4 Hot Observable vs Cold Observable

```go
package reactive

// ColdObservable は購読開始時にデータ生成
type ColdObservable struct {
    generator func() <-chan interface{}
}

func (o *ColdObservable) Subscribe() <-chan interface{} {
    return o.generator()
}

// HotObservable は常にデータを生成
type HotObservable struct {
    stream chan interface{}
}

func NewHotObservable() *HotObservable {
    return &HotObservable{
        stream: make(chan interface{}, 100),
    }
}

func (o *HotObservable) Emit(data interface{}) {
    o.stream <- data
}

func (o *HotObservable) Subscribe() <-chan interface{} {
    return o.stream
}
```

---

## 6. Domain-Driven Design（DDD）パターン

### 6.1 Entity（エンティティ）

**特徴:** 一意のIDで識別され、ライフサイクルを持つドメインオブジェクト。

```go
package domain

import "time"

// User はエンティティ
type User struct {
    ID        string
    Name      string
    Email     string
    CreatedAt time.Time
    UpdatedAt time.Time
}

// 等価性はIDで判断
func (u User) Equals(other User) bool {
    return u.ID == other.ID
}

// ビジネスルールをメソッドで実装
func (u *User) ChangeName(newName string) error {
    if newName == "" {
        return errors.New("name cannot be empty")
    }
    u.Name = newName
    u.UpdatedAt = time.Now()
    return nil
}
```

### 6.2 Value Object（値オブジェクト）

**特徴:** IDを持たず、値の等価性で比較される。イミュータブル。

```go
package domain

// Money は値オブジェクト
type Money struct {
    amount   float64
    currency string
}

// コンストラクタで検証
func NewMoney(amount float64, currency string) (Money, error) {
    if amount < 0 {
        return Money{}, errors.New("amount cannot be negative")
    }
    if currency == "" {
        return Money{}, errors.New("currency is required")
    }
    return Money{amount: amount, currency: currency}, nil
}

// イミュータブル：新しいインスタンスを返す
func (m Money) Add(other Money) (Money, error) {
    if m.currency != other.currency {
        return Money{}, errors.New("currency mismatch")
    }
    return Money{amount: m.amount + other.amount, currency: m.currency}, nil
}

func (m Money) Multiply(factor float64) Money {
    return Money{amount: m.amount * factor, currency: m.currency}
}

// 等価性は値で判断
func (m Money) Equals(other Money) bool {
    return m.amount == other.amount && m.currency == other.currency
}

// Getter
func (m Money) Amount() float64 {
    return m.amount
}

func (m Money) Currency() string {
    return m.currency
}
```

**他の値オブジェクト例:**

```go
// Email は値オブジェクト
type Email struct {
    value string
}

func NewEmail(email string) (Email, error) {
    if !isValidEmail(email) {
        return Email{}, errors.New("invalid email format")
    }
    return Email{value: email}, nil
}

func (e Email) String() string {
    return e.value
}

// Address は値オブジェクト
type Address struct {
    street  string
    city    string
    zipCode string
    country string
}

func NewAddress(street, city, zipCode, country string) (Address, error) {
    // バリデーション
    return Address{street, city, zipCode, country}, nil
}
```

### 6.3 Aggregate（集約）

**目的:** 一貫性の境界を定義し、トランザクション単位を明確にする。

```go
package domain

// Order はAggregateルート
type Order struct {
    id         string
    customerID string
    items      []OrderItem // 集約内のエンティティ
    status     OrderStatus
    totalPrice Money
}

// OrderItem は集約内のエンティティ
type OrderItem struct {
    productID string
    quantity  int
    price     Money
}

// Aggregateルート経由でのみ変更可能
func (o *Order) AddItem(productID string, quantity int, price Money) error {
    if o.status != OrderStatusDraft {
        return errors.New("cannot add item to submitted order")
    }

    item := OrderItem{
        productID: productID,
        quantity:  quantity,
        price:     price,
    }
    o.items = append(o.items, item)

    // 集約内の整合性を維持
    o.recalculateTotalPrice()

    return nil
}

func (o *Order) Submit() error {
    if len(o.items) == 0 {
        return errors.New("cannot submit empty order")
    }
    o.status = OrderStatusSubmitted
    return nil
}

// 内部の整合性を保つプライベートメソッド
func (o *Order) recalculateTotalPrice() {
    total := Money{amount: 0, currency: "USD"}
    for _, item := range o.items {
        itemTotal := item.price.Multiply(float64(item.quantity))
        total, _ = total.Add(itemTotal)
    }
    o.totalPrice = total
}

// Aggregateルート以外は外部から直接変更しない
// ❌ 悪い例
// order.items[0].quantity = 10

// ✅ 良い例
// order.UpdateItemQuantity(itemID, 10)
```

### 6.4 Repository（リポジトリ）

**目的:** 永続化の抽象化。Aggregateの保存と取得を担当。

```go
package domain

// OrderRepository はinterfaceとして定義
type OrderRepository interface {
    Save(order *Order) error
    FindByID(orderID string) (*Order, error)
    FindByCustomerID(customerID string) ([]*Order, error)
    Delete(orderID string) error
}

// インフラ層での実装
package infrastructure

type PostgresOrderRepository struct {
    db *sql.DB
}

func NewPostgresOrderRepository(db *sql.DB) *PostgresOrderRepository {
    return &PostgresOrderRepository{db: db}
}

func (r *PostgresOrderRepository) Save(order *Order) error {
    // トランザクション内で集約全体を保存
    tx, err := r.db.Begin()
    if err != nil {
        return err
    }
    defer tx.Rollback()

    // Orderを保存
    _, err = tx.Exec(`
        INSERT INTO orders (id, customer_id, status, total_price)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (id) DO UPDATE SET
            status = EXCLUDED.status,
            total_price = EXCLUDED.total_price
    `, order.ID(), order.CustomerID(), order.Status(), order.TotalPrice().Amount())
    if err != nil {
        return err
    }

    // OrderItemsを保存
    for _, item := range order.Items() {
        _, err = tx.Exec(`
            INSERT INTO order_items (order_id, product_id, quantity, price)
            VALUES ($1, $2, $3, $4)
        `, order.ID(), item.ProductID, item.Quantity, item.Price.Amount())
        if err != nil {
            return err
        }
    }

    return tx.Commit()
}

func (r *PostgresOrderRepository) FindByID(orderID string) (*Order, error) {
    // 集約全体を再構築
    // ...
}
```

### 6.5 Domain Service（ドメインサービス）

**目的:** 特定のエンティティに属さないドメインロジックを表現。

```go
package domain

// PricingService は値段計算のドメインサービス
type PricingService struct {
    discountRepo DiscountRepository
}

func NewPricingService(repo DiscountRepository) *PricingService {
    return &PricingService{discountRepo: repo}
}

// CalculateFinalPrice は複数のエンティティを横断するロジック
func (s *PricingService) CalculateFinalPrice(order *Order, customer *Customer) (Money, error) {
    basePrice := order.TotalPrice()

    // 顧客の割引率を取得
    discount, err := s.discountRepo.FindByCustomerTier(customer.Tier())
    if err != nil {
        return Money{}, err
    }

    // 割引適用
    discountAmount := basePrice.Multiply(discount.Rate)
    finalPrice, _ := basePrice.Add(discountAmount.Multiply(-1))

    return finalPrice, nil
}

// TransferService は送金のドメインサービス
type TransferService struct {
    accountRepo AccountRepository
}

func (s *TransferService) Transfer(fromID, toID string, amount Money) error {
    from, err := s.accountRepo.FindByID(fromID)
    if err != nil {
        return err
    }

    to, err := s.accountRepo.FindByID(toID)
    if err != nil {
        return err
    }

    // 2つのAggregateにまたがる操作
    if err := from.Withdraw(amount); err != nil {
        return err
    }

    if err := to.Deposit(amount); err != nil {
        from.Deposit(amount) // 補償処理
        return err
    }

    // トランザクション内で両方を保存
    return s.accountRepo.SaveBoth(from, to)
}
```

### 6.6 Bounded Context（境界づけられたコンテキスト）

**目的:** ドメインモデルの適用範囲を明確にし、大規模システムを分割。

```go
// 販売コンテキスト
package sales

type Product struct {
    ID    string
    Name  string
    Price Money
    Stock int
}

// 配送コンテキスト（同じProductでも異なるモデル）
package shipping

type Product struct {
    ID     string
    Weight float64
    Size   Dimensions
}

// Context Map: 異なるコンテキスト間の変換
package adapter

func SalesProductToShippingProduct(salesProduct sales.Product) shipping.Product {
    return shipping.Product{
        ID:     salesProduct.ID,
        Weight: lookupWeight(salesProduct.ID),
        Size:   lookupSize(salesProduct.ID),
    }
}
```

---

## 7. Generics + Builder パターン（Go 1.18+）

**目的:** 型安全でジェネリックなBuilderパターンの実装。

### 7.1 基本実装

```go
package builder

// Builder は型パラメータTを持つジェネリックビルダー
type Builder[T any] struct {
    steps []func(*T)
}

func NewBuilder[T any]() *Builder[T] {
    return &Builder[T]{
        steps: make([]func(*T), 0),
    }
}

// With はビルドステップを追加
func (b *Builder[T]) With(step func(*T)) *Builder[T] {
    b.steps = append(b.steps, step)
    return b
}

// Build は最終的なオブジェクトを構築
func (b *Builder[T]) Build() T {
    var t T
    for _, step := range b.steps {
        step(&t)
    }
    return t
}

// 使用例
type User struct {
    Name  string
    Email string
    Age   int
}

func main() {
    user := NewBuilder[User]().
        With(func(u *User) { u.Name = "Alice" }).
        With(func(u *User) { u.Email = "alice@example.com" }).
        With(func(u *User) { u.Age = 30 }).
        Build()

    fmt.Printf("%+v\n", user)
}
```

### 7.2 検証付きBuilder

```go
package builder

// ValidatedBuilder は検証機能を持つビルダー
type ValidatedBuilder[T any] struct {
    steps      []func(*T)
    validators []func(*T) error
}

func NewValidatedBuilder[T any]() *ValidatedBuilder[T] {
    return &ValidatedBuilder[T]{
        steps:      make([]func(*T), 0),
        validators: make([]func(*T) error, 0),
    }
}

func (b *ValidatedBuilder[T]) With(step func(*T)) *ValidatedBuilder[T] {
    b.steps = append(b.steps, step)
    return b
}

func (b *ValidatedBuilder[T]) Validate(validator func(*T) error) *ValidatedBuilder[T] {
    b.validators = append(b.validators, validator)
    return b
}

func (b *ValidatedBuilder[T]) Build() (T, error) {
    var t T

    // ビルド
    for _, step := range b.steps {
        step(&t)
    }

    // 検証
    for _, validator := range b.validators {
        if err := validator(&t); err != nil {
            return t, err
        }
    }

    return t, nil
}

// 使用例
type Config struct {
    Host string
    Port int
}

func main() {
    config, err := NewValidatedBuilder[Config]().
        With(func(c *Config) { c.Host = "localhost" }).
        With(func(c *Config) { c.Port = 8080 }).
        Validate(func(c *Config) error {
            if c.Port < 1024 {
                return errors.New("port must be >= 1024")
            }
            return nil
        }).
        Build()

    if err != nil {
        log.Fatal(err)
    }

    fmt.Printf("%+v\n", config)
}
```

### 7.3 Fluent Builder with Generics

```go
package builder

// FluentBuilder は流暢なAPIを提供
type UserBuilder struct {
    user User
}

func NewUserBuilder() *UserBuilder {
    return &UserBuilder{user: User{}}
}

func (b *UserBuilder) WithName(name string) *UserBuilder {
    b.user.Name = name
    return b
}

func (b *UserBuilder) WithEmail(email string) *UserBuilder {
    b.user.Email = email
    return b
}

func (b *UserBuilder) WithAge(age int) *UserBuilder {
    b.user.Age = age
    return b
}

func (b *UserBuilder) Build() User {
    return b.user
}

// Generics版のFluent Builder
type FluentBuilder[T any] struct {
    value T
}

func NewFluentBuilder[T any]() *FluentBuilder[T] {
    return &FluentBuilder[T]{}
}

func (b *FluentBuilder[T]) Set(setter func(*T)) *FluentBuilder[T] {
    setter(&b.value)
    return b
}

func (b *FluentBuilder[T]) Build() T {
    return b.value
}

// 使用例
func main() {
    user := NewFluentBuilder[User]().
        Set(func(u *User) { u.Name = "Bob" }).
        Set(func(u *User) { u.Email = "bob@example.com" }).
        Set(func(u *User) { u.Age = 25 }).
        Build()

    fmt.Printf("%+v\n", user)
}
```

---

## パターン選定フローチャート

```
依存関係管理が必要か？
├─ Yes → 規模は？
│   ├─ 小規模（<10 struct） → 手動DI
│   ├─ 中規模（10-50） → google/wire
│   └─ 大規模（50+） → uber-go/fx
│
完全な監査ログが必要か？
├─ Yes → Event Sourcing + CQRS
│
読み書きの最適化を分離したいか？
├─ Yes → CQRS
│
分散システム間の通信が必要か？
├─ Yes → マイクロサービスパターン
│   ├─ API Gateway
│   ├─ Service Discovery
│   └─ Saga（分散トランザクション）
│
リアルタイムデータ処理が必要か？
├─ Yes → Reactive Programming
│   ├─ Observer
│   ├─ Reactive Streams
│   └─ Back Pressure
│
複雑なビジネスドメインか？
├─ Yes → DDD
│   ├─ Entity / Value Object
│   ├─ Aggregate
│   ├─ Repository
│   ├─ Domain Service
│   └─ Bounded Context
│
型安全なBuilderが必要か？
└─ Yes → Generics Builder
```

---

## まとめ

本ドキュメントでは、Goにおける高度なデザインパターンを網羅的に解説した。各パターンは以下の状況で活用する：

| パターン | 適用場面 |
|---------|---------|
| **DI Framework** | 依存関係管理の自動化（中〜大規模） |
| **Event Sourcing** | 完全な監査ログ、状態の履歴管理 |
| **CQRS** | 読み書きの最適化分離 |
| **Microservices** | 分散システム、サービス間通信 |
| **Reactive Programming** | 非同期データストリーム、リアルタイム処理 |
| **DDD** | 複雑なビジネスドメイン、大規模システム |
| **Generics Builder** | 型安全なオブジェクト構築 |

プロジェクトの特性と要件に応じて適切なパターンを選択し、過度に複雑化しないよう注意すること。
