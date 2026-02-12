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

---

## 7. リファクタリング × デザインパターン

アンチパターンをデザインパターンで段階的に解決する実践的アプローチ。

### 7.1 Code Smell → パターンマッピング

| Code Smell | 推奨パターン | 理由 |
|-----------|------------|------|
| **God Function（巨大関数）** | Strategy / Chain of Responsibility | 責務を複数のクラスに分割し、処理の流れを明示化 |
| **グローバル状態依存** | Dependency Injection | テスト可能性を向上し、依存関係を明示化 |
| **条件分岐の肥大化** | State / Strategy | 状態・戦略ごとにクラスを分割し、開放閉鎖原則に準拠 |
| **API互換性問題** | Adapter | 既存インターフェースを維持しながら新実装を導入 |
| **オブジェクト生成の散在** | Factory Method | 生成ロジックを集約し、変更の影響範囲を限定 |
| **重複コード** | Template Method | 共通処理を親クラスに抽出し、差異のみサブクラスで実装 |
| **複雑な初期化** | Builder | オブジェクト構築手順を段階化し、可読性を向上 |
| **オブジェクト間の密結合** | Mediator | オブジェクト間の通信を仲介役に集約 |
| **複数の責務を持つクラス** | Facade | 複雑なサブシステムを単純なインターフェースでラップ |

---

### 7.2 レガシーコード変換の5ステップ

#### ステップ1: テストの整備（特性テスト）

既存コードの振舞いを保護するため、まず特性テストを作成する。

```go
// レガシーコードの特性を捕捉
func TestLegacyProcessOrder(t *testing.T) {
    // 既存の振舞いを記録するテスト
    tests := []struct {
        name        string
        orderID     int
        wantStatus  string
        wantError   bool
    }{
        {
            name:       "valid order with in-stock items",
            orderID:    123,
            wantStatus: "confirmed",
            wantError:  false,
        },
        {
            name:       "invalid order ID",
            orderID:    999,
            wantStatus: "",
            wantError:  true,
        },
        {
            name:       "out of stock",
            orderID:    456,
            wantStatus: "pending",
            wantError:  false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange
            setupTestDB(t)
            defer cleanupTestDB(t)

            // Act
            status, err := LegacyProcessOrder(tt.orderID)

            // Assert
            if (err != nil) != tt.wantError {
                t.Errorf("error = %v, wantError %v", err, tt.wantError)
            }
            if status != tt.wantStatus {
                t.Errorf("status = %v, want %v", status, tt.wantStatus)
            }
        })
    }
}
```

#### ステップ2: Code Smell の特定

```bash
# 静的解析でCode Smellを検出
gocyclo -over 10 .
golangci-lint run

# 出力例:
# legacy_order.go:45: function ProcessOrder has complexity 25 (> 10)
# legacy_order.go:120: function ProcessOrder is too long (150 lines)
```

具体的なチェックポイント:
- 関数の行数（50行超）
- Cyclomatic Complexity（10以上）
- 同じコードブロックの重複（3回以上）
- グローバル変数への依存
- 具体型への直接依存

#### ステップ3: パターンの選択

マッピングテーブルを参照し、検出されたCode Smellに対応するパターンを選択:

```go
// 検出されたCode Smell:
// - 150行の巨大関数（God Function）
// - switch文での支払い方法分岐（10+ case）
// - グローバルDB変数への依存

// 選択したパターン:
// 1. Strategy: 支払い方法の分岐を戦略クラスに分離
// 2. Dependency Injection: グローバルDB依存を解消
// 3. Chain of Responsibility: 注文処理フローを段階化
```

#### ステップ4: 段階的リファクタリング

一度にすべてを変更せず、小さなステップで進める:

**Phase 1: 関数の分割（Extract Method）**

```go
// Before: 150行の巨大関数
func LegacyProcessOrder(orderID int) (string, error) {
    // 注文取得（20行）
    // 在庫確認（30行）
    // 支払い処理（40行）
    // 在庫減算（30行）
    // メール送信（30行）
}

// After: 責務ごとに分割
func ProcessOrder(orderID int) (string, error) {
    order, err := fetchOrder(orderID)
    if err != nil {
        return "", fmt.Errorf("fetch order: %w", err)
    }

    if err := checkInventory(order); err != nil {
        return "", fmt.Errorf("inventory: %w", err)
    }

    if err := processPayment(order); err != nil {
        return "", fmt.Errorf("payment: %w", err)
    }

    if err := reduceInventory(order); err != nil {
        return "", fmt.Errorf("reduce inventory: %w", err)
    }

    sendConfirmationEmail(order)

    return "confirmed", nil
}
```

**Phase 2: Strategyパターンの導入**

```go
// Before: switch文での支払い処理
func processPayment(order *Order) error {
    switch order.PaymentMethod {
    case "credit_card":
        // クレジットカード処理（20行）
    case "bank_transfer":
        // 銀行振込処理（20行）
    case "paypal":
        // PayPal処理（20行）
    // ... 10+ cases
    }
}

// After: Strategyパターン
type PaymentStrategy interface {
    Process(order *Order) error
}

type CreditCardPayment struct{}

func (p *CreditCardPayment) Process(order *Order) error {
    // クレジットカード処理
    return nil
}

type BankTransferPayment struct{}

func (p *BankTransferPayment) Process(order *Order) error {
    // 銀行振込処理
    return nil
}

// Factory
func GetPaymentStrategy(method string) (PaymentStrategy, error) {
    switch method {
    case "credit_card":
        return &CreditCardPayment{}, nil
    case "bank_transfer":
        return &BankTransferPayment{}, nil
    default:
        return nil, fmt.Errorf("unknown payment method: %s", method)
    }
}

func processPayment(order *Order) error {
    strategy, err := GetPaymentStrategy(order.PaymentMethod)
    if err != nil {
        return err
    }
    return strategy.Process(order)
}
```

**Phase 3: Dependency Injectionの導入**

```go
// Before: グローバルDB依存
var globalDB *sql.DB

func fetchOrder(orderID int) (*Order, error) {
    row := globalDB.QueryRow("SELECT * FROM orders WHERE id = ?", orderID)
    // ...
}

// After: DI
type OrderRepository interface {
    FindByID(id int) (*Order, error)
}

type PostgresOrderRepository struct {
    db *sql.DB
}

func NewOrderRepository(db *sql.DB) *PostgresOrderRepository {
    return &PostgresOrderRepository{db: db}
}

func (r *PostgresOrderRepository) FindByID(id int) (*Order, error) {
    row := r.db.QueryRow("SELECT * FROM orders WHERE id = ?", id)
    // ...
}

type OrderService struct {
    repo           OrderRepository
    paymentFactory PaymentStrategyFactory
}

func NewOrderService(repo OrderRepository, factory PaymentStrategyFactory) *OrderService {
    return &OrderService{
        repo:           repo,
        paymentFactory: factory,
    }
}

func (s *OrderService) ProcessOrder(orderID int) (string, error) {
    order, err := s.repo.FindByID(orderID)
    // ...
}
```

#### ステップ5: テストでの検証

各フェーズ後にテストを実行し、振舞いが変わっていないことを確認:

```bash
# Phase 1完了後
go test ./... -v

# Phase 2完了後
go test ./... -v

# Phase 3完了後
go test ./... -v

# 最終確認
go test -race ./...
go test -cover ./...
```

---

### 7.3 パターン適用のBefore/Afterコード例

#### 例1: モノリシック関数 → Strategy パターン

**Before: 100行超の価格計算関数**

```go
func CalculatePrice(productType string, basePrice float64, quantity int, customerType string, seasonalDiscount bool) float64 {
    var finalPrice float64

    // 商品タイプによる基本割引
    switch productType {
    case "book":
        if basePrice > 100 {
            finalPrice = basePrice * 0.9
        } else {
            finalPrice = basePrice * 0.95
        }
    case "electronics":
        if basePrice > 500 {
            finalPrice = basePrice * 0.85
        } else {
            finalPrice = basePrice * 0.9
        }
    case "clothing":
        if basePrice > 200 {
            finalPrice = basePrice * 0.8
        } else {
            finalPrice = basePrice * 0.9
        }
    case "food":
        finalPrice = basePrice * 0.98
    default:
        finalPrice = basePrice
    }

    // 顧客タイプによる追加割引
    switch customerType {
    case "premium":
        finalPrice *= 0.95
    case "gold":
        finalPrice *= 0.9
    case "regular":
        // 割引なし
    }

    // 数量割引
    if quantity >= 10 {
        finalPrice *= 0.95
    } else if quantity >= 5 {
        finalPrice *= 0.97
    }

    // 季節割引
    if seasonalDiscount {
        finalPrice *= 0.9
    }

    return finalPrice * float64(quantity)
}
```

**After: Strategyパターンで責務分離**

```go
// 商品タイプ別価格戦略
type ProductPricingStrategy interface {
    CalculateBase(basePrice float64) float64
}

type BookPricing struct{}

func (s *BookPricing) CalculateBase(basePrice float64) float64 {
    if basePrice > 100 {
        return basePrice * 0.9
    }
    return basePrice * 0.95
}

type ElectronicsPricing struct{}

func (s *ElectronicsPricing) CalculateBase(basePrice float64) float64 {
    if basePrice > 500 {
        return basePrice * 0.85
    }
    return basePrice * 0.9
}

type ClothingPricing struct{}

func (s *ClothingPricing) CalculateBase(basePrice float64) float64 {
    if basePrice > 200 {
        return basePrice * 0.8
    }
    return basePrice * 0.9
}

// 顧客タイプ別割引戦略
type CustomerDiscountStrategy interface {
    ApplyDiscount(price float64) float64
}

type PremiumCustomer struct{}

func (c *PremiumCustomer) ApplyDiscount(price float64) float64 {
    return price * 0.95
}

type GoldCustomer struct{}

func (c *GoldCustomer) ApplyDiscount(price float64) float64 {
    return price * 0.9
}

type RegularCustomer struct{}

func (c *RegularCustomer) ApplyDiscount(price float64) float64 {
    return price // 割引なし
}

// 価格計算サービス（複数戦略を統合）
type PriceCalculator struct {
    productStrategy  ProductPricingStrategy
    customerStrategy CustomerDiscountStrategy
}

func NewPriceCalculator(productType, customerType string) (*PriceCalculator, error) {
    productStrategy, err := getProductStrategy(productType)
    if err != nil {
        return nil, err
    }

    customerStrategy := getCustomerStrategy(customerType)

    return &PriceCalculator{
        productStrategy:  productStrategy,
        customerStrategy: customerStrategy,
    }, nil
}

func (pc *PriceCalculator) Calculate(basePrice float64, quantity int, seasonalDiscount bool) float64 {
    // 商品タイプ別基本価格
    price := pc.productStrategy.CalculateBase(basePrice)

    // 顧客タイプ別割引
    price = pc.customerStrategy.ApplyDiscount(price)

    // 数量割引
    price = pc.applyQuantityDiscount(price, quantity)

    // 季節割引
    if seasonalDiscount {
        price *= 0.9
    }

    return price * float64(quantity)
}

func (pc *PriceCalculator) applyQuantityDiscount(price float64, quantity int) float64 {
    if quantity >= 10 {
        return price * 0.95
    } else if quantity >= 5 {
        return price * 0.97
    }
    return price
}

// Factory関数
func getProductStrategy(productType string) (ProductPricingStrategy, error) {
    switch productType {
    case "book":
        return &BookPricing{}, nil
    case "electronics":
        return &ElectronicsPricing{}, nil
    case "clothing":
        return &ClothingPricing{}, nil
    default:
        return nil, fmt.Errorf("unknown product type: %s", productType)
    }
}

func getCustomerStrategy(customerType string) CustomerDiscountStrategy {
    switch customerType {
    case "premium":
        return &PremiumCustomer{}
    case "gold":
        return &GoldCustomer{}
    default:
        return &RegularCustomer{}
    }
}

// 使用例
func main() {
    calculator, err := NewPriceCalculator("book", "premium")
    if err != nil {
        log.Fatal(err)
    }

    finalPrice := calculator.Calculate(120.0, 7, true)
    fmt.Printf("Final price: %.2f\n", finalPrice)
}
```

**改善ポイント:**
- 単一責任の原則：各戦略が1つの責務のみ担当
- 開放閉鎖の原則：新しい商品タイプや顧客タイプの追加が容易
- テスト容易性：各戦略を独立してテスト可能

---

#### 例2: グローバルSingleton → DI（コンストラクタインジェクション）

**Before: テスト不可能なグローバル依存**

```go
package service

import (
    "database/sql"
    "log"
)

// グローバルDB接続
var db *sql.DB
var logger *log.Logger

func init() {
    var err error
    db, err = sql.Open("postgres", "host=prod-db user=admin password=secret")
    if err != nil {
        panic(err)
    }

    logger = log.New(os.Stdout, "PROD: ", log.LstdFlags)
}

type UserService struct{}

func (s *UserService) GetUser(id int) (*User, error) {
    // グローバルDBに直接依存（テスト時にモック不可）
    row := db.QueryRow("SELECT id, name, email FROM users WHERE id = ?", id)

    var user User
    if err := row.Scan(&user.ID, &user.Name, &user.Email); err != nil {
        logger.Printf("failed to fetch user %d: %v", id, err)
        return nil, err
    }

    logger.Printf("fetched user: %d", id)
    return &user, nil
}

func (s *UserService) CreateUser(name, email string) (*User, error) {
    result, err := db.Exec("INSERT INTO users (name, email) VALUES (?, ?)", name, email)
    if err != nil {
        logger.Printf("failed to create user: %v", err)
        return nil, err
    }

    id, _ := result.LastInsertId()
    logger.Printf("created user: %d", id)

    return &User{ID: int(id), Name: name, Email: email}, nil
}

// テストコード（不可能）
func TestGetUser(t *testing.T) {
    // グローバルDBを変更できないため、テスト不可能
    // 本番DBに接続してしまう
}
```

**After: DIパターンで依存関係を外部化**

```go
package service

import (
    "context"
    "database/sql"
    "fmt"
)

// Repository層のinterface
type UserRepository interface {
    FindByID(ctx context.Context, id int) (*User, error)
    Create(ctx context.Context, name, email string) (*User, error)
}

// Logger interface
type Logger interface {
    Info(msg string)
    Error(msg string)
}

// 本番用Repository実装
type PostgresUserRepository struct {
    db *sql.DB
}

func NewUserRepository(db *sql.DB) *PostgresUserRepository {
    return &PostgresUserRepository{db: db}
}

func (r *PostgresUserRepository) FindByID(ctx context.Context, id int) (*User, error) {
    row := r.db.QueryRowContext(ctx, "SELECT id, name, email FROM users WHERE id = ?", id)

    var user User
    if err := row.Scan(&user.ID, &user.Name, &user.Email); err != nil {
        return nil, fmt.Errorf("scan user: %w", err)
    }

    return &user, nil
}

func (r *PostgresUserRepository) Create(ctx context.Context, name, email string) (*User, error) {
    result, err := r.db.ExecContext(ctx, "INSERT INTO users (name, email) VALUES (?, ?)", name, email)
    if err != nil {
        return nil, fmt.Errorf("insert user: %w", err)
    }

    id, _ := result.LastInsertId()
    return &User{ID: int(id), Name: name, Email: email}, nil
}

// Service層（interfaceに依存）
type UserService struct {
    repo   UserRepository
    logger Logger
}

func NewUserService(repo UserRepository, logger Logger) *UserService {
    return &UserService{
        repo:   repo,
        logger: logger,
    }
}

func (s *UserService) GetUser(ctx context.Context, id int) (*User, error) {
    user, err := s.repo.FindByID(ctx, id)
    if err != nil {
        s.logger.Error(fmt.Sprintf("failed to fetch user %d: %v", id, err))
        return nil, err
    }

    s.logger.Info(fmt.Sprintf("fetched user: %d", id))
    return user, nil
}

func (s *UserService) CreateUser(ctx context.Context, name, email string) (*User, error) {
    user, err := s.repo.Create(ctx, name, email)
    if err != nil {
        s.logger.Error(fmt.Sprintf("failed to create user: %v", err))
        return nil, err
    }

    s.logger.Info(fmt.Sprintf("created user: %d", user.ID))
    return user, nil
}

// テスト用モック実装
type MockUserRepository struct {
    users map[int]*User
}

func NewMockUserRepository() *MockUserRepository {
    return &MockUserRepository{
        users: make(map[int]*User),
    }
}

func (m *MockUserRepository) FindByID(ctx context.Context, id int) (*User, error) {
    if user, ok := m.users[id]; ok {
        return user, nil
    }
    return nil, fmt.Errorf("user not found")
}

func (m *MockUserRepository) Create(ctx context.Context, name, email string) (*User, error) {
    id := len(m.users) + 1
    user := &User{ID: id, Name: name, Email: email}
    m.users[id] = user
    return user, nil
}

type MockLogger struct {
    logs []string
}

func (m *MockLogger) Info(msg string) {
    m.logs = append(m.logs, "INFO: "+msg)
}

func (m *MockLogger) Error(msg string) {
    m.logs = append(m.logs, "ERROR: "+msg)
}

// テストコード（テスト可能）
func TestGetUser(t *testing.T) {
    // Arrange
    mockRepo := NewMockUserRepository()
    mockRepo.users[1] = &User{ID: 1, Name: "Alice", Email: "alice@example.com"}

    mockLogger := &MockLogger{}
    service := NewUserService(mockRepo, mockLogger)

    // Act
    user, err := service.GetUser(context.Background(), 1)

    // Assert
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if user.Name != "Alice" {
        t.Errorf("expected Alice, got %s", user.Name)
    }
    if len(mockLogger.logs) == 0 {
        t.Error("expected log entries")
    }
}

// 本番環境でのDI設定
func main() {
    // 本番DB接続
    db, err := sql.Open("postgres", "host=prod-db user=admin password=secret")
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    // 依存を注入
    repo := NewUserRepository(db)
    logger := &ProductionLogger{}
    service := NewUserService(repo, logger)

    // サービスを使用
    user, err := service.GetUser(context.Background(), 123)
    if err != nil {
        log.Fatal(err)
    }
    fmt.Printf("User: %+v\n", user)
}
```

**改善ポイント:**
- テスト容易性：モック実装でDBアクセスなしにテスト可能
- 依存関係の明示化：コンストラクタで依存を明示
- 環境切り替え：本番/テスト環境で異なる実装を注入可能

---

#### 例3: switch文の肥大化 → State パターン

**Before: 状態管理が複雑なswitch文**

```go
type Order struct {
    ID     int
    Status string // "pending", "paid", "shipped", "delivered", "cancelled"
    Items  []Item
}

func (o *Order) ProcessAction(action string) error {
    switch o.Status {
    case "pending":
        switch action {
        case "pay":
            // 支払い処理
            o.Status = "paid"
            return nil
        case "cancel":
            o.Status = "cancelled"
            return nil
        default:
            return fmt.Errorf("invalid action %s for pending order", action)
        }

    case "paid":
        switch action {
        case "ship":
            // 発送処理
            o.Status = "shipped"
            return nil
        case "cancel":
            // 返金処理
            o.Status = "cancelled"
            return nil
        default:
            return fmt.Errorf("invalid action %s for paid order", action)
        }

    case "shipped":
        switch action {
        case "deliver":
            // 配送完了処理
            o.Status = "delivered"
            return nil
        default:
            return fmt.Errorf("invalid action %s for shipped order", action)
        }

    case "delivered":
        return fmt.Errorf("order already delivered, no actions allowed")

    case "cancelled":
        return fmt.Errorf("order cancelled, no actions allowed")

    default:
        return fmt.Errorf("unknown order status: %s", o.Status)
    }
}
```

**After: Stateパターンで状態遷移を明確化**

```go
// State interface
type OrderState interface {
    Pay(order *Order) error
    Ship(order *Order) error
    Deliver(order *Order) error
    Cancel(order *Order) error
    StatusName() string
}

// Order構造体
type Order struct {
    ID    int
    state OrderState
    Items []Item
}

func NewOrder(id int) *Order {
    return &Order{
        ID:    id,
        state: &PendingState{},
    }
}

func (o *Order) SetState(state OrderState) {
    o.state = state
}

func (o *Order) Pay() error {
    return o.state.Pay(o)
}

func (o *Order) Ship() error {
    return o.state.Ship(o)
}

func (o *Order) Deliver() error {
    return o.state.Deliver(o)
}

func (o *Order) Cancel() error {
    return o.state.Cancel(o)
}

func (o *Order) StatusName() string {
    return o.state.StatusName()
}

// Pending状態
type PendingState struct{}

func (s *PendingState) Pay(order *Order) error {
    // 支払い処理
    fmt.Println("Processing payment...")
    order.SetState(&PaidState{})
    return nil
}

func (s *PendingState) Ship(order *Order) error {
    return fmt.Errorf("cannot ship pending order")
}

func (s *PendingState) Deliver(order *Order) error {
    return fmt.Errorf("cannot deliver pending order")
}

func (s *PendingState) Cancel(order *Order) error {
    fmt.Println("Cancelling pending order...")
    order.SetState(&CancelledState{})
    return nil
}

func (s *PendingState) StatusName() string {
    return "pending"
}

// Paid状態
type PaidState struct{}

func (s *PaidState) Pay(order *Order) error {
    return fmt.Errorf("order already paid")
}

func (s *PaidState) Ship(order *Order) error {
    fmt.Println("Shipping order...")
    order.SetState(&ShippedState{})
    return nil
}

func (s *PaidState) Deliver(order *Order) error {
    return fmt.Errorf("cannot deliver order before shipping")
}

func (s *PaidState) Cancel(order *Order) error {
    fmt.Println("Processing refund...")
    order.SetState(&CancelledState{})
    return nil
}

func (s *PaidState) StatusName() string {
    return "paid"
}

// Shipped状態
type ShippedState struct{}

func (s *ShippedState) Pay(order *Order) error {
    return fmt.Errorf("order already paid and shipped")
}

func (s *ShippedState) Ship(order *Order) error {
    return fmt.Errorf("order already shipped")
}

func (s *ShippedState) Deliver(order *Order) error {
    fmt.Println("Order delivered successfully")
    order.SetState(&DeliveredState{})
    return nil
}

func (s *ShippedState) Cancel(order *Order) error {
    return fmt.Errorf("cannot cancel shipped order")
}

func (s *ShippedState) StatusName() string {
    return "shipped"
}

// Delivered状態
type DeliveredState struct{}

func (s *DeliveredState) Pay(order *Order) error {
    return fmt.Errorf("order already completed")
}

func (s *DeliveredState) Ship(order *Order) error {
    return fmt.Errorf("order already completed")
}

func (s *DeliveredState) Deliver(order *Order) error {
    return fmt.Errorf("order already delivered")
}

func (s *DeliveredState) Cancel(order *Order) error {
    return fmt.Errorf("cannot cancel delivered order")
}

func (s *DeliveredState) StatusName() string {
    return "delivered"
}

// Cancelled状態
type CancelledState struct{}

func (s *CancelledState) Pay(order *Order) error {
    return fmt.Errorf("cannot pay cancelled order")
}

func (s *CancelledState) Ship(order *Order) error {
    return fmt.Errorf("cannot ship cancelled order")
}

func (s *CancelledState) Deliver(order *Order) error {
    return fmt.Errorf("cannot deliver cancelled order")
}

func (s *CancelledState) Cancel(order *Order) error {
    return fmt.Errorf("order already cancelled")
}

func (s *CancelledState) StatusName() string {
    return "cancelled"
}

// 使用例
func main() {
    order := NewOrder(123)

    fmt.Println("Current status:", order.StatusName())

    // 正常フロー
    order.Pay()
    fmt.Println("Current status:", order.StatusName())

    order.Ship()
    fmt.Println("Current status:", order.StatusName())

    order.Deliver()
    fmt.Println("Current status:", order.StatusName())

    // 不正な操作
    if err := order.Ship(); err != nil {
        fmt.Println("Error:", err) // "order already completed"
    }
}
```

**改善ポイント:**
- 状態遷移ロジックが各Stateクラスに分散
- 新しい状態の追加が容易（開放閉鎖の原則）
- 不正な状態遷移がコンパイル時に検出可能

---

### 7.4 まとめ：パターン適用の判断基準

| 状況 | 適用パターン | 適用条件 |
|------|------------|---------|
| 関数が100行超 | Strategy / Template Method | 複数の責務が混在している |
| switch/if-else が10+ | State / Strategy | 条件が状態や戦略の切り替えに相当 |
| グローバル変数に依存 | Dependency Injection | テスト可能性が低い |
| 同じコードが3箇所以上 | Template Method / Decorator | 共通処理を抽出可能 |
| オブジェクト生成が散在 | Factory Method / Builder | 生成ロジックの集約が必要 |
| 複数クラスが密結合 | Mediator / Observer | 相互依存が複雑化している |

**重要:** すべてのCode Smellにパターンが必要なわけではない。シンプルな関数抽出やリネームで解決できる場合も多い。パターンは「複雑性を削減する手段」であり、「目的」ではない。
