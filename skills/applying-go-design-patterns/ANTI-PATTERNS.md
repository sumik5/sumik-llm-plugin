# Go アンチパターン・リファクタリングガイド

Goにおける典型的なアンチパターンとその解決策、効果的なリファクタリング戦略を解説します。

---

## 1. アンチパターンとは

**アンチパターン**は、一見合理的で広く使われているものの、長期的には以下の問題を引き起こす設計・実装パターンです：

- **保守性の低下**: 変更が困難になる
- **テスト困難**: 自動テストが書けない
- **スケーラビリティの欠如**: 負荷増加に対応できない
- **バグの温床**: エラーが発生しやすい構造

### アンチパターン対策のサイクル

1. **認識**: Code Smellを検出する
2. **理解**: なぜ問題なのかを把握する
3. **回避**: 適切なパターンで置き換える

---

## 2. Go固有のアンチパターン

### 2.1 Singleton の誤用

#### 問題点
- グローバル状態への依存
- テスト時のモック差し替えが不可能
- 並行処理での競合リスク
- 暗黙的な依存関係

#### ❌ Bad: パッケージレベル変数でのSingleton

```go
package database

import "database/sql"

// グローバルなDB接続
var db *sql.DB

func init() {
    var err error
    db, err = sql.Open("postgres", "host=localhost user=admin")
    if err != nil {
        panic(err)
    }
}

// グローバルDBに直接依存
func GetUsers() ([]User, error) {
    rows, err := db.Query("SELECT * FROM users")
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    var users []User
    // ... rowsを処理
    return users, nil
}

// テスト時にモック不可能
```

#### ✅ Good: Dependency Injectionで置き換え

```go
package repository

import "database/sql"

// interfaceで抽象化
type UserRepository interface {
    GetUsers() ([]User, error)
    GetUser(id int) (*User, error)
}

// 具体的な実装
type PostgresUserRepository struct {
    db *sql.DB
}

// コンストラクタで依存を注入
func NewUserRepository(db *sql.DB) *PostgresUserRepository {
    return &PostgresUserRepository{db: db}
}

func (r *PostgresUserRepository) GetUsers() ([]User, error) {
    rows, err := r.db.Query("SELECT * FROM users")
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    var users []User
    // ... rowsを処理
    return users, nil
}

// テスト用モック実装
type MockUserRepository struct {
    users []User
}

func (m *MockUserRepository) GetUsers() ([]User, error) {
    return m.users, nil
}

func (m *MockUserRepository) GetUser(id int) (*User, error) {
    for _, u := range m.users {
        if u.ID == id {
            return &u, nil
        }
    }
    return nil, ErrNotFound
}
```

---

### 2.2 非効率な並行処理パターン

#### 問題点
- goroutineリーク
- データレース
- 過剰なgoroutine生成
- channelデッドロック

#### ❌ Bad: goroutineリーク

```go
// channelを閉じず、goroutineが永遠に残る
func leak() <-chan int {
    ch := make(chan int)
    go func() {
        for i := 0; i < 10; i++ {
            ch <- i
            // 読み手がいなくなってもgoroutineが残り続ける
        }
    }()
    return ch
}

func main() {
    ch := leak()
    // 最初の値だけ読んで終了
    fmt.Println(<-ch)
    // goroutineはまだ動いている（リーク）
}
```

#### ✅ Good: contextでキャンセル管理

```go
func noLeak(ctx context.Context) <-chan int {
    ch := make(chan int)
    go func() {
        defer close(ch) // 必ずchannelを閉じる
        for i := 0; i < 10; i++ {
            select {
            case <-ctx.Done():
                // contextキャンセル時に即座に終了
                return
            case ch <- i:
            }
        }
    }()
    return ch
}

func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel() // 関数終了時に確実にキャンセル

    ch := noLeak(ctx)
    fmt.Println(<-ch)
    // cancel()が呼ばれてgoroutineも終了
}
```

#### ❌ Bad: データレース

```go
type Counter struct {
    count int
}

func (c *Counter) Increment() {
    c.count++ // 複数goroutineから呼ばれると競合
}

func main() {
    counter := &Counter{}
    for i := 0; i < 1000; i++ {
        go counter.Increment() // データレース発生
    }
    time.Sleep(time.Second)
    fmt.Println(counter.count) // 期待値1000にならない
}
```

#### ✅ Good: mutexで保護

```go
type Counter struct {
    mu    sync.Mutex
    count int
}

func (c *Counter) Increment() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

func (c *Counter) Value() int {
    c.mu.Lock()
    defer c.mu.Unlock()
    return c.count
}

// または sync.atomic を使用
type AtomicCounter struct {
    count atomic.Int64
}

func (c *AtomicCounter) Increment() {
    c.count.Add(1)
}

func (c *AtomicCounter) Value() int64 {
    return c.count.Load()
}
```

#### ❌ Bad: 過剰なgoroutine生成

```go
func processItems(items []Item) {
    for _, item := range items {
        // 100万件のitemsがあれば100万goroutine生成
        go process(item)
    }
}
```

#### ✅ Good: Worker Pool パターン

```go
func processItems(items []Item, numWorkers int) {
    itemCh := make(chan Item, len(items))
    var wg sync.WaitGroup

    // Worker起動
    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for item := range itemCh {
                process(item)
            }
        }()
    }

    // タスク投入
    for _, item := range items {
        itemCh <- item
    }
    close(itemCh)

    wg.Wait()
}
```

---

### 2.3 過度なエンジニアリング（Over-Engineering）

#### 問題点
- 不必要なパターン適用
- 過度な抽象化
- 読みにくいコード
- YAGNI（You Aren't Gonna Need It）違反

#### ❌ Bad: 実装が1つしかないのにinterface + factory

```go
// 1つしか実装がないのに無駄に抽象化
type UserService interface {
    GetUser(id int) (*User, error)
    CreateUser(name string) (*User, error)
}

type userServiceImpl struct {
    repo UserRepository
}

func (s *userServiceImpl) GetUser(id int) (*User, error) {
    return s.repo.FindByID(id)
}

func (s *userServiceImpl) CreateUser(name string) (*User, error) {
    return s.repo.Save(&User{Name: name})
}

// 不要なFactory
type UserServiceFactory struct{}

func (f *UserServiceFactory) Create(repo UserRepository) UserService {
    return &userServiceImpl{repo: repo}
}

// 使用側
factory := &UserServiceFactory{}
service := factory.Create(repo)
```

#### ✅ Good: シンプルなstruct

```go
// 最初はシンプルに
type UserService struct {
    repo UserRepository
}

func NewUserService(repo UserRepository) *UserService {
    return &UserService{repo: repo}
}

func (s *UserService) GetUser(id int) (*User, error) {
    return s.repo.FindByID(id)
}

func (s *UserService) CreateUser(name string) (*User, error) {
    return s.repo.Save(&User{Name: name})
}

// 将来複数実装が必要になったらinterfaceを導入
```

#### ❌ Bad: 不要な層の追加

```go
// DTOレイヤー（不要）
type UserDTO struct {
    ID   int
    Name string
}

// Mapperレイヤー（不要）
type UserMapper struct{}

func (m *UserMapper) ToDTO(user *User) *UserDTO {
    return &UserDTO{ID: user.ID, Name: user.Name}
}

func (m *UserMapper) ToEntity(dto *UserDTO) *User {
    return &User{ID: dto.ID, Name: dto.Name}
}

// 使用側（複雑化）
user := service.GetUser(id)
dto := mapper.ToDTO(user)
return dto
```

#### ✅ Good: 必要になるまでシンプルに

```go
// ドメインモデルをそのまま返す
func (s *UserService) GetUser(id int) (*User, error) {
    return s.repo.FindByID(id)
}

// JSON変換が必要ならstruct tagで対応
type User struct {
    ID   int    `json:"id"`
    Name string `json:"name"`
}
```

---

### 2.4 密結合（Tight Coupling）

#### 問題点
- 具体的な型への直接依存
- テスト困難
- 変更の影響範囲が広い
- 再利用性の低下

#### ❌ Bad: 具体型に直接依存

```go
type OrderService struct {
    emailer *SMTPEmailer // 具体的な実装に依存
}

func (s *OrderService) PlaceOrder(order *Order) error {
    // 注文処理
    if err := s.processPayment(order); err != nil {
        return err
    }

    // SMTP固定でテスト時にメール送信してしまう
    return s.emailer.SendConfirmation(order.Email, order.ID)
}

type SMTPEmailer struct {
    host string
    port int
}

func (e *SMTPEmailer) SendConfirmation(to string, orderID int) error {
    // 実際のSMTP送信
    return smtp.SendMail(e.host, nil, "noreply@example.com", []string{to}, []byte("Order confirmed"))
}
```

#### ✅ Good: interfaceに依存

```go
// 通知の抽象化
type Notifier interface {
    Send(to string, message string) error
}

type OrderService struct {
    notifier Notifier // interfaceに依存
}

func (s *OrderService) PlaceOrder(order *Order) error {
    if err := s.processPayment(order); err != nil {
        return err
    }

    // 実装に依存しない
    return s.notifier.Send(order.Email, fmt.Sprintf("Order %d confirmed", order.ID))
}

// 本番用実装
type EmailNotifier struct {
    sender EmailSender
}

func (n *EmailNotifier) Send(to string, message string) error {
    return n.sender.SendMail(to, message)
}

// テスト用モック
type MockNotifier struct {
    sentMessages []string
}

func (m *MockNotifier) Send(to string, message string) error {
    m.sentMessages = append(m.sentMessages, message)
    return nil
}

// テスト
func TestPlaceOrder(t *testing.T) {
    mock := &MockNotifier{}
    service := &OrderService{notifier: mock}

    order := &Order{Email: "test@example.com", ID: 123}
    err := service.PlaceOrder(order)

    assert.NoError(t, err)
    assert.Len(t, mock.sentMessages, 1)
}
```

---

### 2.5 Godオブジェクト（God Object）

#### 問題点
- 1つの構造体に責務が集中
- 単一責任の原則（SRP）違反
- テストが困難
- 変更の影響範囲が広い

#### ❌ Bad: すべてを担当する巨大struct

```go
type UserManager struct {
    db            *sql.DB
    cache         *redis.Client
    emailSender   *SMTPClient
    logger        *Logger
    metrics       *MetricsCollector
    tokenService  *JWTService
    passwordHasher *BcryptHasher
}

func (m *UserManager) RegisterUser(email, password string) error {
    // バリデーション
    if !m.validateEmail(email) {
        return errors.New("invalid email")
    }

    // パスワードハッシュ化
    hash, err := m.passwordHasher.Hash(password)
    if err != nil {
        return err
    }

    // DB保存
    result, err := m.db.Exec("INSERT INTO users (email, password) VALUES (?, ?)", email, hash)
    if err != nil {
        return err
    }

    // キャッシュ更新
    userID, _ := result.LastInsertId()
    m.cache.Set(fmt.Sprintf("user:%d", userID), email, 0)

    // メール送信
    if err := m.emailSender.SendWelcome(email); err != nil {
        m.logger.Error("failed to send welcome email", err)
    }

    // メトリクス記録
    m.metrics.Increment("user.registrations")

    return nil
}

// 他にも多数のメソッド...
func (m *UserManager) LoginUser(email, password string) (string, error) { /* ... */ }
func (m *UserManager) ResetPassword(email string) error { /* ... */ }
func (m *UserManager) UpdateProfile(userID int, data map[string]interface{}) error { /* ... */ }
func (m *UserManager) DeleteUser(userID int) error { /* ... */ }
func (m *UserManager) validateEmail(email string) bool { /* ... */ }
// ... さらに数十のメソッド
```

#### ✅ Good: 責務ごとに分割

```go
// 認証専用
type AuthService struct {
    userRepo      UserRepository
    passwordHasher PasswordHasher
    tokenService  TokenService
}

func (s *AuthService) Register(email, password string) (*User, error) {
    hash, err := s.passwordHasher.Hash(password)
    if err != nil {
        return nil, err
    }

    return s.userRepo.Create(email, hash)
}

func (s *AuthService) Login(email, password string) (string, error) {
    user, err := s.userRepo.FindByEmail(email)
    if err != nil {
        return "", err
    }

    if !s.passwordHasher.Verify(password, user.PasswordHash) {
        return "", ErrInvalidCredentials
    }

    return s.tokenService.Generate(user.ID)
}

// 通知専用
type NotificationService struct {
    emailSender EmailSender
    logger      Logger
}

func (s *NotificationService) SendWelcome(email string) error {
    if err := s.emailSender.Send(email, "Welcome!"); err != nil {
        s.logger.Error("failed to send welcome email", "error", err)
        return err
    }
    return nil
}

// プロフィール管理専用
type ProfileService struct {
    userRepo UserRepository
    cache    Cache
}

func (s *ProfileService) Update(userID int, data map[string]interface{}) error {
    if err := s.userRepo.Update(userID, data); err != nil {
        return err
    }

    // キャッシュ無効化
    s.cache.Delete(fmt.Sprintf("user:%d", userID))
    return nil
}

// 使用側（必要なserviceのみ注入）
type RegistrationHandler struct {
    auth         *AuthService
    notification *NotificationService
    metrics      MetricsCollector
}

func (h *RegistrationHandler) Handle(email, password string) error {
    user, err := h.auth.Register(email, password)
    if err != nil {
        return err
    }

    h.notification.SendWelcome(user.Email)
    h.metrics.Increment("user.registrations")

    return nil
}
```

---

### 2.6 エラーハンドリングの無視

#### 問題点
- エラーの黙殺
- デバッグ困難
- 予期しない動作
- 本番環境での障害

#### ❌ Bad: エラーを無視

```go
// エラーを完全に無視
result, _ := riskyOperation()

// エラーをログだけして処理続行
data, err := fetchData()
if err != nil {
    log.Println("error:", err) // ログだけ
}
processData(data) // nilの可能性があるのに続行

// panicで異常終了
config, err := loadConfig()
if err != nil {
    panic(err) // 本番環境でダウン
}
```

#### ✅ Good: 適切なエラーハンドリング

```go
// エラーを呼び出し元に伝播
func ProcessData() error {
    data, err := fetchData()
    if err != nil {
        return fmt.Errorf("failed to fetch data: %w", err)
    }

    if err := validateData(data); err != nil {
        return fmt.Errorf("validation failed: %w", err)
    }

    if err := saveData(data); err != nil {
        return fmt.Errorf("failed to save data: %w", err)
    }

    return nil
}

// エラーをログして適切なデフォルト値を返す
func LoadConfig() (*Config, error) {
    config, err := readConfigFile()
    if err != nil {
        log.Printf("failed to load config, using defaults: %v", err)
        return defaultConfig(), nil
    }
    return config, nil
}

// エラーをカスタムエラーでラップ
var ErrNotFound = errors.New("resource not found")

func GetUser(id int) (*User, error) {
    user, err := db.QueryUser(id)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrNotFound
        }
        return nil, fmt.Errorf("database error: %w", err)
    }
    return user, nil
}

// 呼び出し側でエラータイプを判定
user, err := GetUser(123)
if errors.Is(err, ErrNotFound) {
    return http.StatusNotFound, "User not found"
} else if err != nil {
    return http.StatusInternalServerError, "Internal error"
}
```

---

## 3. Code Smell（コードの臭い）の検出

| Code Smell | 説明 | 兆候 | リファクタリング方法 |
|-----------|------|------|-------------------|
| **Long Function** | 関数が長すぎる | 50行以上、ネスト深い | 責務ごとに小さな関数に分割 |
| **Large Struct** | 構造体のフィールドが多すぎる | 10個以上のフィールド | 関連フィールドを別structにグループ化 |
| **Feature Envy** | 他structのデータを多用 | 他structのgetterを連続呼び出し | メソッドを適切なstructに移動 |
| **Primitive Obsession** | 基本型の過度な使用 | string, intをそのまま使用 | ドメイン固有の型を定義 |
| **Duplicate Code** | コードの重複 | コピー&ペースト | 共通関数/interfaceに抽出 |
| **Shotgun Surgery** | 1つの変更で多数ファイル修正 | 同じ修正を10箇所 | 関連ロジックを1箇所に集約 |
| **Data Clumps** | 同じデータセットが複数箇所 | 同じ3つの引数が頻出 | 専用structを定義 |
| **Switch Statements** | 巨大なswitch文 | 10個以上のcase | Strategy/Stateパターン |
| **Speculative Generality** | 使われない抽象化 | 実装が1つしかないinterface | 不要な抽象化を削除 |
| **Magic Numbers** | マジックナンバー | ハードコードされた数値 | 名前付き定数に置き換え |

### 3.1 Long Function の例

#### ❌ Bad: 100行超の長大な関数

```go
func ProcessOrder(orderID int) error {
    // 注文取得（10行）
    order, err := db.Query("SELECT * FROM orders WHERE id = ?", orderID)
    if err != nil {
        return err
    }

    // 在庫確認（15行）
    for _, item := range order.Items {
        stock, err := db.Query("SELECT quantity FROM inventory WHERE product_id = ?", item.ProductID)
        if err != nil {
            return err
        }
        if stock < item.Quantity {
            return errors.New("insufficient stock")
        }
    }

    // 支払い処理（20行）
    paymentReq := &PaymentRequest{
        Amount:   order.Total,
        Currency: "USD",
        CardNumber: order.CardNumber,
        // ... 多数のフィールド
    }
    paymentRes, err := paymentGateway.Charge(paymentReq)
    if err != nil {
        return err
    }

    // 在庫減算（15行）
    for _, item := range order.Items {
        _, err := db.Exec("UPDATE inventory SET quantity = quantity - ? WHERE product_id = ?", item.Quantity, item.ProductID)
        if err != nil {
            // ロールバック処理
            return err
        }
    }

    // メール送信（20行）
    emailBody := fmt.Sprintf("Order %d confirmed...", orderID)
    err = smtp.SendMail("smtp.example.com:587", nil, "noreply@example.com", []string{order.Email}, []byte(emailBody))
    if err != nil {
        log.Println("email failed:", err)
    }

    // ログ記録（10行）
    // ... さらに続く

    return nil
}
```

#### ✅ Good: 責務ごとに分割

```go
func ProcessOrder(orderID int) error {
    order, err := fetchOrder(orderID)
    if err != nil {
        return fmt.Errorf("fetch order: %w", err)
    }

    if err := checkInventory(order.Items); err != nil {
        return fmt.Errorf("inventory check: %w", err)
    }

    if err := chargePayment(order); err != nil {
        return fmt.Errorf("payment: %w", err)
    }

    if err := reduceInventory(order.Items); err != nil {
        return fmt.Errorf("reduce inventory: %w", err)
    }

    sendConfirmationEmail(order) // エラーは内部でログ

    return nil
}

func fetchOrder(orderID int) (*Order, error) {
    // 注文取得ロジック
}

func checkInventory(items []OrderItem) error {
    // 在庫確認ロジック
}

func chargePayment(order *Order) error {
    // 支払い処理ロジック
}

func reduceInventory(items []OrderItem) error {
    // 在庫減算ロジック
}

func sendConfirmationEmail(order *Order) {
    // メール送信ロジック
}
```

### 3.2 Primitive Obsession の例

#### ❌ Bad: 基本型を直接使用

```go
func ValidateEmail(email string) error {
    if !strings.Contains(email, "@") {
        return errors.New("invalid email")
    }
    return nil
}

func SendEmail(from string, to string, subject string, body string) error {
    // 引数が多すぎて間違いやすい
    return smtp.SendMail("smtp.example.com", nil, from, []string{to}, []byte(subject+"\n"+body))
}

// 使用側
SendEmail("noreply@example.com", "user@example.com", "Welcome", "Thank you for signing up")
// 引数の順序を間違えやすい
```

#### ✅ Good: ドメイン型を定義

```go
type Email struct {
    address string
}

func NewEmail(address string) (Email, error) {
    if !strings.Contains(address, "@") {
        return Email{}, errors.New("invalid email format")
    }
    return Email{address: address}, nil
}

func (e Email) String() string {
    return e.address
}

type EmailMessage struct {
    From    Email
    To      Email
    Subject string
    Body    string
}

func SendEmail(msg EmailMessage) error {
    return smtp.SendMail(
        "smtp.example.com",
        nil,
        msg.From.String(),
        []string{msg.To.String()},
        []byte(msg.Subject+"\n"+msg.Body),
    )
}

// 使用側（型安全）
from, _ := NewEmail("noreply@example.com")
to, _ := NewEmail("user@example.com")
SendEmail(EmailMessage{
    From:    from,
    To:      to,
    Subject: "Welcome",
    Body:    "Thank you for signing up",
})
```

---

## 4. リファクタリング戦略

### 4.1 生成パターンによるリファクタリング

#### グローバル変数 → Factory Method + DI

**Before:**
```go
var logger = log.New(os.Stdout, "APP: ", log.LstdFlags)

func ProcessData() {
    logger.Println("processing...")
}
```

**After:**
```go
type Logger interface {
    Info(msg string)
    Error(msg string)
}

type Service struct {
    logger Logger
}

func NewService(logger Logger) *Service {
    return &Service{logger: logger}
}

func (s *Service) ProcessData() {
    s.logger.Info("processing...")
}
```

#### 複雑なコンストラクタ → Functional Options

**Before:**
```go
func NewServer(addr string, port int, timeout time.Duration, maxConns int, tlsConfig *tls.Config, logger *log.Logger) *Server {
    return &Server{
        addr:      addr,
        port:      port,
        timeout:   timeout,
        maxConns:  maxConns,
        tlsConfig: tlsConfig,
        logger:    logger,
    }
}

// 使用側（引数が多すぎる）
server := NewServer("localhost", 8080, 30*time.Second, 100, nil, logger)
```

**After:**
```go
type ServerOption func(*Server)

func WithTimeout(d time.Duration) ServerOption {
    return func(s *Server) {
        s.timeout = d
    }
}

func WithMaxConns(n int) ServerOption {
    return func(s *Server) {
        s.maxConns = n
    }
}

func WithTLS(config *tls.Config) ServerOption {
    return func(s *Server) {
        s.tlsConfig = config
    }
}

func NewServer(addr string, port int, opts ...ServerOption) *Server {
    s := &Server{
        addr:     addr,
        port:     port,
        timeout:  30 * time.Second, // デフォルト
        maxConns: 100,              // デフォルト
    }

    for _, opt := range opts {
        opt(s)
    }

    return s
}

// 使用側（読みやすい）
server := NewServer("localhost", 8080,
    WithTimeout(60*time.Second),
    WithMaxConns(200),
)
```

---

### 4.2 構造パターンによるリファクタリング

#### if/else型分岐のAPI呼び出し → Adapter

**Before:**
```go
func SendNotification(provider string, message string) error {
    if provider == "email" {
        return smtp.SendMail("smtp.example.com", nil, "noreply@example.com", []string{"user@example.com"}, []byte(message))
    } else if provider == "sms" {
        client := twilio.NewClient("account", "token")
        return client.SendSMS("+1234567890", message)
    } else if provider == "slack" {
        webhook := slack.NewWebhook("https://hooks.slack.com/...")
        return webhook.Post(message)
    }
    return errors.New("unknown provider")
}
```

**After:**
```go
type Notifier interface {
    Send(message string) error
}

type EmailNotifier struct {
    to string
}

func (n *EmailNotifier) Send(message string) error {
    return smtp.SendMail("smtp.example.com", nil, "noreply@example.com", []string{n.to}, []byte(message))
}

type SMSNotifier struct {
    client *twilio.Client
    to     string
}

func (n *SMSNotifier) Send(message string) error {
    return n.client.SendSMS(n.to, message)
}

type SlackNotifier struct {
    webhook *slack.Webhook
}

func (n *SlackNotifier) Send(message string) error {
    return n.webhook.Post(message)
}

// Factory
func NewNotifier(provider string) (Notifier, error) {
    switch provider {
    case "email":
        return &EmailNotifier{to: "user@example.com"}, nil
    case "sms":
        return &SMSNotifier{client: twilio.NewClient("account", "token"), to: "+1234567890"}, nil
    case "slack":
        return &SlackNotifier{webhook: slack.NewWebhook("https://hooks.slack.com/...")}, nil
    default:
        return nil, errors.New("unknown provider")
    }
}

// 使用側
notifier, err := NewNotifier("email")
if err != nil {
    return err
}
return notifier.Send("Hello")
```

#### 条件付き機能追加 → Decorator

**Before:**
```go
func ProcessData(data string, shouldLog bool, shouldMetrics bool, shouldCache bool) string {
    result := strings.ToUpper(data)

    if shouldLog {
        log.Println("processed:", result)
    }

    if shouldMetrics {
        metrics.Increment("data.processed")
    }

    if shouldCache {
        cache.Set("data", result)
    }

    return result
}
```

**After:**
```go
type DataProcessor interface {
    Process(data string) string
}

// ベース実装
type BaseProcessor struct{}

func (p *BaseProcessor) Process(data string) string {
    return strings.ToUpper(data)
}

// ログデコレーター
type LoggingDecorator struct {
    processor DataProcessor
    logger    *log.Logger
}

func (d *LoggingDecorator) Process(data string) string {
    result := d.processor.Process(data)
    d.logger.Println("processed:", result)
    return result
}

// メトリクスデコレーター
type MetricsDecorator struct {
    processor DataProcessor
    metrics   MetricsCollector
}

func (d *MetricsDecorator) Process(data string) string {
    result := d.processor.Process(data)
    d.metrics.Increment("data.processed")
    return result
}

// キャッシュデコレーター
type CachingDecorator struct {
    processor DataProcessor
    cache     Cache
}

func (d *CachingDecorator) Process(data string) string {
    if cached := d.cache.Get("data"); cached != "" {
        return cached
    }

    result := d.processor.Process(data)
    d.cache.Set("data", result)
    return result
}

// 使用側（必要な機能のみ追加）
processor := &BaseProcessor{}
processor = &LoggingDecorator{processor: processor, logger: log.Default()}
processor = &MetricsDecorator{processor: processor, metrics: metrics}

result := processor.Process("hello")
```

---

### 4.3 振舞いパターンによるリファクタリング

#### 巨大switch文 → Strategy

**Before:**
```go
func CalculatePrice(productType string, basePrice float64) float64 {
    switch productType {
    case "book":
        if basePrice > 100 {
            return basePrice * 0.9
        }
        return basePrice * 0.95
    case "electronics":
        if basePrice > 500 {
            return basePrice * 0.85
        }
        return basePrice * 0.9
    case "clothing":
        if basePrice > 200 {
            return basePrice * 0.8
        }
        return basePrice * 0.9
    default:
        return basePrice
    }
}
```

**After:**
```go
type PricingStrategy interface {
    Calculate(basePrice float64) float64
}

type BookPricing struct{}

func (s *BookPricing) Calculate(basePrice float64) float64 {
    if basePrice > 100 {
        return basePrice * 0.9
    }
    return basePrice * 0.95
}

type ElectronicsPricing struct{}

func (s *ElectronicsPricing) Calculate(basePrice float64) float64 {
    if basePrice > 500 {
        return basePrice * 0.85
    }
    return basePrice * 0.9
}

type ClothingPricing struct{}

func (s *ClothingPricing) Calculate(basePrice float64) float64 {
    if basePrice > 200 {
        return basePrice * 0.8
    }
    return basePrice * 0.9
}

type DefaultPricing struct{}

func (s *DefaultPricing) Calculate(basePrice float64) float64 {
    return basePrice
}

// Factory
func GetPricingStrategy(productType string) PricingStrategy {
    switch productType {
    case "book":
        return &BookPricing{}
    case "electronics":
        return &ElectronicsPricing{}
    case "clothing":
        return &ClothingPricing{}
    default:
        return &DefaultPricing{}
    }
}

// 使用側
strategy := GetPricingStrategy("book")
finalPrice := strategy.Calculate(120.0)
```

#### 条件分岐の連鎖 → Chain of Responsibility

**Before:**
```go
func HandleRequest(req *Request) error {
    // 認証チェック
    if req.AuthToken == "" {
        return errors.New("unauthorized")
    }
    token, err := validateToken(req.AuthToken)
    if err != nil {
        return err
    }

    // レート制限チェック
    if !checkRateLimit(token.UserID) {
        return errors.New("rate limit exceeded")
    }

    // 権限チェック
    if !hasPermission(token.UserID, req.Resource) {
        return errors.New("forbidden")
    }

    // リクエスト処理
    return processRequest(req)
}
```

**After:**
```go
type Handler interface {
    Handle(req *Request) error
    SetNext(handler Handler)
}

type BaseHandler struct {
    next Handler
}

func (h *BaseHandler) SetNext(handler Handler) {
    h.next = handler
}

type AuthHandler struct {
    BaseHandler
}

func (h *AuthHandler) Handle(req *Request) error {
    if req.AuthToken == "" {
        return errors.New("unauthorized")
    }

    token, err := validateToken(req.AuthToken)
    if err != nil {
        return err
    }

    req.UserID = token.UserID

    if h.next != nil {
        return h.next.Handle(req)
    }
    return nil
}

type RateLimitHandler struct {
    BaseHandler
}

func (h *RateLimitHandler) Handle(req *Request) error {
    if !checkRateLimit(req.UserID) {
        return errors.New("rate limit exceeded")
    }

    if h.next != nil {
        return h.next.Handle(req)
    }
    return nil
}

type PermissionHandler struct {
    BaseHandler
}

func (h *PermissionHandler) Handle(req *Request) error {
    if !hasPermission(req.UserID, req.Resource) {
        return errors.New("forbidden")
    }

    if h.next != nil {
        return h.next.Handle(req)
    }
    return nil
}

type ProcessHandler struct {
    BaseHandler
}

func (h *ProcessHandler) Handle(req *Request) error {
    return processRequest(req)
}

// 使用側（チェーンの構築）
func NewRequestHandler() Handler {
    process := &ProcessHandler{}
    permission := &PermissionHandler{}
    rateLimit := &RateLimitHandler{}
    auth := &AuthHandler{}

    auth.SetNext(rateLimit)
    rateLimit.SetNext(permission)
    permission.SetNext(process)

    return auth
}

handler := NewRequestHandler()
err := handler.Handle(req)
```

---

### 4.4 リファクタリングの手順

#### ステップ1: テストを先に書く

```go
// 既存コードの振舞いをテストで捕捉
func TestProcessOrder(t *testing.T) {
    tests := []struct {
        name      string
        orderID   int
        wantError bool
    }{
        {"valid order", 123, false},
        {"invalid order", 999, true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ProcessOrder(tt.orderID)
            if (err != nil) != tt.wantError {
                t.Errorf("ProcessOrder() error = %v, wantError %v", err, tt.wantError)
            }
        })
    }
}
```

#### ステップ2: Code Smellを特定

```bash
# コード行数確認
wc -l *.go

# cyclomatic complexity確認
gocyclo .

# 重複コード検出
dupl .
```

#### ステップ3: 適切なパターンを選択

| Code Smell | 推奨パターン |
|-----------|------------|
| Long Function | Extract Method |
| Large Struct | Extract Struct, Facade |
| Feature Envy | Move Method |
| Duplicate Code | Template Method, Strategy |
| Switch Statements | Strategy, State, Adapter |
| Data Clumps | Extract Struct |

#### ステップ4: 小さなステップで変更

```go
// ステップ1: 関数を抽出（動作は変えない）
func ProcessOrder(orderID int) error {
    order, err := fetchOrder(orderID)
    if err != nil {
        return err
    }
    // ... 元のコードをそのまま
}

func fetchOrder(orderID int) (*Order, error) {
    // 抽出したロジック
}

// テスト実行 → 成功

// ステップ2: interfaceを導入
type OrderRepository interface {
    FindByID(id int) (*Order, error)
}

// テスト実行 → 成功

// ステップ3: DI に変更
type OrderService struct {
    repo OrderRepository
}

// テスト実行 → 成功
```

#### ステップ5: 各ステップ後にテスト実行

```bash
go test ./... -v
```

#### ステップ6: 最終確認とコードレビュー

```bash
# 静的解析
go vet ./...
staticcheck ./...

# テストカバレッジ
go test -cover ./...
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

---

## 5. Go クリーンコードのベストプラクティス

### 5.1 SOLID原則

| 原則 | Goでの適用 | 例 |
|------|-----------|-----|
| **単一責任の原則（SRP）** | 1つのstructは1つの責務 | `UserRepository`（DB操作のみ）、`UserService`（ビジネスロジックのみ） |
| **開放閉鎖の原則（OCP）** | interfaceで拡張可能に | `type Notifier interface`で実装を追加可能 |
| **リスコフの置換原則（LSP）** | interfaceの契約を守る | すべての`Notifier`実装は同じ振舞い |
| **インターフェース分離の原則（ISP）** | 小さなinterfaceに分割 | `Reader`, `Writer`を別々に定義 |
| **依存関係逆転の原則（DIP）** | 具体型でなくinterfaceに依存 | `*sql.DB`でなく`UserRepository`に依存 |

### 5.2 DRY（Don't Repeat Yourself）

```go
// ❌ Bad: 重複コード
func GetUser(id int) (*User, error) {
    row := db.QueryRow("SELECT id, name, email FROM users WHERE id = ?", id)
    var user User
    err := row.Scan(&user.ID, &user.Name, &user.Email)
    if err != nil {
        return nil, err
    }
    return &user, nil
}

func GetUserByEmail(email string) (*User, error) {
    row := db.QueryRow("SELECT id, name, email FROM users WHERE email = ?", email)
    var user User
    err := row.Scan(&user.ID, &user.Name, &user.Email)
    if err != nil {
        return nil, err
    }
    return &user, nil
}

// ✅ Good: 共通処理を抽出
func scanUser(row *sql.Row) (*User, error) {
    var user User
    err := row.Scan(&user.ID, &user.Name, &user.Email)
    if err != nil {
        return nil, err
    }
    return &user, nil
}

func GetUser(id int) (*User, error) {
    row := db.QueryRow("SELECT id, name, email FROM users WHERE id = ?", id)
    return scanUser(row)
}

func GetUserByEmail(email string) (*User, error) {
    row := db.QueryRow("SELECT id, name, email FROM users WHERE email = ?", email)
    return scanUser(row)
}
```

### 5.3 KISS（Keep It Simple, Stupid）

```go
// ❌ Bad: 過度に複雑
func IsValidUserAge(age int) bool {
    return age >= 18 && age <= 120 && age != 0 && age > -1
}

// ✅ Good: シンプル
func IsValidUserAge(age int) bool {
    return age >= 18 && age <= 120
}
```

### 5.4 YAGNI（You Aren't Gonna Need It）

```go
// ❌ Bad: 今必要ないinterface
type UserService interface {
    GetUser(id int) (*User, error)
    CreateUser(name string) (*User, error)
    UpdateUser(id int, name string) (*User, error)
    DeleteUser(id int) error
    GetAllUsers() ([]*User, error)
    SearchUsers(query string) ([]*User, error)
    ExportUsers(format string) ([]byte, error) // まだ必要ない
    ImportUsers(data []byte) error              // まだ必要ない
}

// ✅ Good: 必要なメソッドのみ
type UserService interface {
    GetUser(id int) (*User, error)
    CreateUser(name string) (*User, error)
}

// 将来必要になったら追加
```

### 5.5 Law of Demeter（最小知識の原則）

```go
// ❌ Bad: チェーン呼び出し（密結合）
func ProcessOrder(order *Order) {
    order.User.Address.City.Country.TaxRate
}

// ✅ Good: 直接の依存のみとやり取り
type Order struct {
    user *User
}

func (o *Order) GetTaxRate() float64 {
    return o.user.GetCountryTaxRate()
}

type User struct {
    address *Address
}

func (u *User) GetCountryTaxRate() float64 {
    return u.address.GetCountryTaxRate()
}

// 使用側
func ProcessOrder(order *Order) {
    taxRate := order.GetTaxRate()
}
```

### 5.6 Composition over Inheritance（Goでの組込み活用）

```go
// ✅ Goでの推奨: 組込み（embedding）
type Logger struct {
    level string
}

func (l *Logger) Info(msg string) {
    fmt.Printf("[%s] INFO: %s\n", l.level, msg)
}

type FileLogger struct {
    Logger          // 組込み
    file   *os.File
}

func (fl *FileLogger) Info(msg string) {
    fl.Logger.Info(msg)         // 親のメソッド呼び出し
    fl.file.WriteString(msg)    // 追加処理
}

// 使用側
fileLogger := &FileLogger{
    Logger: Logger{level: "prod"},
    file:   f,
}
fileLogger.Info("message") // 両方のメソッドが実行される
```

---

## 6. まとめ

### リファクタリングの黄金律

1. **テストファースト**: リファクタリング前に既存コードの振舞いをテストで保護
2. **段階的変更**: 小さなステップで進める（Red → Green → Refactor）
3. **継続的改善**: Code Smellを見つけたら即座に修正
4. **パターンの適切な適用**: 過度なエンジニアリングを避ける
5. **レビューの徹底**: 変更前後でコードレビューを実施

### アンチパターン回避のチェックリスト

- [ ] グローバル変数を使用していないか？
- [ ] エラーを無視していないか？
- [ ] goroutineリークの可能性はないか？
- [ ] 1つの関数/structに複数の責務が集中していないか？
- [ ] 具体型に直接依存していないか？（interfaceで抽象化すべきか？）
- [ ] 基本型（string, int）を過度に使用していないか？
- [ ] 重複コードはないか？
- [ ] テストが書けるか？

### 推奨ツール

| ツール | 用途 |
|-------|------|
| `go vet` | 静的解析 |
| `staticcheck` | 高度な静的解析 |
| `gocyclo` | cyclomatic complexity測定 |
| `dupl` | 重複コード検出 |
| `golangci-lint` | 包括的linter |
| `go test -race` | データレース検出 |
| `go test -cover` | テストカバレッジ |
