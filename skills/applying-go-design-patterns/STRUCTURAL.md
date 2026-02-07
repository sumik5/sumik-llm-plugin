# Structural パターン（構造）

Structural パターンは、オブジェクトやクラスを組み合わせて大きな構造を作る方法を提供します。既存のコードを変更せずに、新しい機能を追加したり、複雑なシステムを簡素化したりすることができます。

---

## 1. Adapter パターン

### 目的
互換性のないインターフェースを持つクラス同士を接続します。既存のコードを変更せずに、異なるインターフェースを持つコンポーネントを統合できます。

### Go実装例

#### 基本構造
```go
// Target: クライアントが期待するインターフェース
type Target interface {
    Request() string
}

// Adaptee: 既存のインターフェース（互換性がない）
type Adaptee struct{}

func (a *Adaptee) SpecificRequest() string {
    return "specific request from Adaptee"
}

// Adapter: AdapteeをTargetインターフェースに適合させる
type Adapter struct {
    adaptee *Adaptee
}

func (a *Adapter) Request() string {
    return a.adaptee.SpecificRequest()
}
```

#### 実用例：旧APIから新APIへの移行
```go
// 新しいインターフェース
type PaymentProcessor interface {
    ProcessPayment(amount float64) error
}

// 旧システムのAPI
type LegacyPaymentSystem struct{}

func (l *LegacyPaymentSystem) MakePayment(dollars int, cents int) bool {
    // 旧システムのロジック
    return true
}

// Adapter
type PaymentAdapter struct {
    legacy *LegacyPaymentSystem
}

func (p *PaymentAdapter) ProcessPayment(amount float64) error {
    dollars := int(amount)
    cents := int((amount - float64(dollars)) * 100)

    if !p.legacy.MakePayment(dollars, cents) {
        return fmt.Errorf("payment failed")
    }
    return nil
}

// 使用例
func main() {
    legacy := &LegacyPaymentSystem{}
    adapter := &PaymentAdapter{legacy: legacy}

    var processor PaymentProcessor = adapter
    processor.ProcessPayment(99.99)
}
```

#### サードパーティライブラリ統合
```go
// 自社のロガーインターフェース
type Logger interface {
    Log(level string, message string)
}

// サードパーティのロガー
type ThirdPartyLogger struct{}

func (t *ThirdPartyLogger) WriteLog(severity int, msg string) {
    // サードパーティの実装
}

// Adapter
type LoggerAdapter struct {
    thirdParty *ThirdPartyLogger
}

func (l *LoggerAdapter) Log(level string, message string) {
    severity := map[string]int{
        "INFO":  1,
        "WARN":  2,
        "ERROR": 3,
    }[level]

    l.thirdParty.WriteLog(severity, message)
}
```

### 使い所
- 外部ライブラリのAPIを自社システムに適合させる
- レガシーコードを新しいインターフェースで使用する
- テスト用のモックオブジェクトを作成する

---

## 2. Bridge パターン

### 目的
抽象と実装を分離し、それぞれを独立して変更できるようにします。実装の詳細を抽象から切り離すことで、柔軟性が向上します。

### Go実装

#### 基本構造
```go
// Implementor: 実装のインターフェース
type Renderer interface {
    RenderCircle(radius float64)
    RenderSquare(side float64)
}

// ConcreteImplementor: 具体的な実装
type VectorRenderer struct{}

func (v *VectorRenderer) RenderCircle(radius float64) {
    fmt.Printf("Drawing circle with radius %f as vectors\n", radius)
}

func (v *VectorRenderer) RenderSquare(side float64) {
    fmt.Printf("Drawing square with side %f as vectors\n", side)
}

type RasterRenderer struct{}

func (r *RasterRenderer) RenderCircle(radius float64) {
    fmt.Printf("Drawing circle with radius %f as pixels\n", radius)
}

func (r *RasterRenderer) RenderSquare(side float64) {
    fmt.Printf("Drawing square with side %f as pixels\n", side)
}

// Abstraction: 抽象クラス（実装への参照を持つ）
type Shape struct {
    renderer Renderer
}

// RefinedAbstraction: 拡張された抽象クラス
type Circle struct {
    Shape
    radius float64
}

func (c *Circle) Draw() {
    c.renderer.RenderCircle(c.radius)
}

func (c *Circle) Resize(factor float64) {
    c.radius *= factor
}

type Square struct {
    Shape
    side float64
}

func (s *Square) Draw() {
    s.renderer.RenderSquare(s.side)
}
```

#### 実用例：通知システム
```go
// Implementor
type MessageSender interface {
    Send(message string, recipient string) error
}

// ConcreteImplementors
type EmailSender struct{}

func (e *EmailSender) Send(message string, recipient string) error {
    fmt.Printf("Email to %s: %s\n", recipient, message)
    return nil
}

type SMSSender struct{}

func (s *SMSSender) Send(message string, recipient string) error {
    fmt.Printf("SMS to %s: %s\n", recipient, message)
    return nil
}

type PushNotificationSender struct{}

func (p *PushNotificationSender) Send(message string, recipient string) error {
    fmt.Printf("Push to %s: %s\n", recipient, message)
    return nil
}

// Abstraction
type Notification struct {
    sender MessageSender
}

// RefinedAbstractions
type UrgentNotification struct {
    Notification
}

func (u *UrgentNotification) Notify(message string, recipient string) error {
    urgentMessage := "[URGENT] " + message
    return u.sender.Send(urgentMessage, recipient)
}

type NormalNotification struct {
    Notification
}

func (n *NormalNotification) Notify(message string, recipient string) error {
    return n.sender.Send(message, recipient)
}

// 使用例
func main() {
    emailSender := &EmailSender{}
    smsSender := &SMSSender{}

    // 緊急メール通知
    urgentEmail := &UrgentNotification{
        Notification: Notification{sender: emailSender},
    }
    urgentEmail.Notify("Server down", "admin@example.com")

    // 通常のSMS通知
    normalSMS := &NormalNotification{
        Notification: Notification{sender: smsSender},
    }
    normalSMS.Notify("Your order has shipped", "+1234567890")
}
```

### 使い所
- 抽象と実装を独立して変更したい
- 複数の実装を切り替えられるようにしたい
- プラットフォーム依存のコードを分離したい

---

## 3. Composite パターン

### 目的
オブジェクトをツリー構造で表現し、個別のオブジェクトと複合オブジェクトを統一的に扱います。クライアントは単一オブジェクトと複合オブジェクトの違いを意識せずに操作できます。

### Go実装

#### 基本構造
```go
// Component: 共通インターフェース
type Component interface {
    Operation() string
    Add(child Component)
    Remove(child Component)
    GetChild(index int) Component
}

// Leaf: 葉ノード（子を持たない）
type Leaf struct {
    name string
}

func (l *Leaf) Operation() string {
    return l.name
}

func (l *Leaf) Add(child Component) {
    // 葉ノードは子を持たない
}

func (l *Leaf) Remove(child Component) {
    // 葉ノードは子を持たない
}

func (l *Leaf) GetChild(index int) Component {
    return nil
}

// Composite: 複合ノード（子を持つ）
type Composite struct {
    name     string
    children []Component
}

func (c *Composite) Operation() string {
    result := c.name + " ("
    for i, child := range c.children {
        if i > 0 {
            result += ", "
        }
        result += child.Operation()
    }
    result += ")"
    return result
}

func (c *Composite) Add(child Component) {
    c.children = append(c.children, child)
}

func (c *Composite) Remove(child Component) {
    for i, existingChild := range c.children {
        if existingChild == child {
            c.children = append(c.children[:i], c.children[i+1:]...)
            break
        }
    }
}

func (c *Composite) GetChild(index int) Component {
    if index >= 0 && index < len(c.children) {
        return c.children[index]
    }
    return nil
}
```

#### 実用例：ファイルシステム
```go
// Component
type FileSystemNode interface {
    GetSize() int64
    Print(indent string)
}

// Leaf: File
type File struct {
    name string
    size int64
}

func (f *File) GetSize() int64 {
    return f.size
}

func (f *File) Print(indent string) {
    fmt.Printf("%s- %s (%d bytes)\n", indent, f.name, f.size)
}

// Composite: Directory
type Directory struct {
    name     string
    children []FileSystemNode
}

func (d *Directory) GetSize() int64 {
    var total int64
    for _, child := range d.children {
        total += child.GetSize()
    }
    return total
}

func (d *Directory) Print(indent string) {
    fmt.Printf("%s+ %s/ (%d bytes)\n", indent, d.name, d.GetSize())
    for _, child := range d.children {
        child.Print(indent + "  ")
    }
}

func (d *Directory) Add(node FileSystemNode) {
    d.children = append(d.children, node)
}

// 使用例
func main() {
    root := &Directory{name: "root"}

    home := &Directory{name: "home"}
    root.Add(home)

    user := &Directory{name: "user"}
    home.Add(user)

    user.Add(&File{name: "resume.pdf", size: 12000})
    user.Add(&File{name: "photo.jpg", size: 250000})

    root.Add(&File{name: "boot.img", size: 5000000})

    root.Print("")
    fmt.Printf("Total size: %d bytes\n", root.GetSize())
}
```

#### 実用例：UIコンポーネントツリー
```go
type UIComponent interface {
    Render() string
}

type Button struct {
    text string
}

func (b *Button) Render() string {
    return fmt.Sprintf("<button>%s</button>", b.text)
}

type Panel struct {
    children []UIComponent
}

func (p *Panel) Render() string {
    result := "<div>"
    for _, child := range p.children {
        result += child.Render()
    }
    result += "</div>"
    return result
}

func (p *Panel) Add(component UIComponent) {
    p.children = append(p.children, component)
}
```

### 使い所
- ツリー構造のデータを扱う（ファイルシステム、組織図、UIツリー）
- 個別オブジェクトと複合オブジェクトを統一的に扱いたい
- 再帰的な構造を表現したい

---

## 4. Decorator パターン

### 目的
既存のオブジェクトに動的に新しい振る舞いを追加します。継承を使わずに機能を拡張できるため、柔軟性が高まります。

### Go実装

#### 基本構造
```go
// Component: 基本インターフェース
type Component interface {
    Operation() string
}

// ConcreteComponent: 具体的なコンポーネント
type ConcreteComponent struct{}

func (c *ConcreteComponent) Operation() string {
    return "ConcreteComponent"
}

// Decorator: 基底デコレータ
type Decorator struct {
    component Component
}

func (d *Decorator) Operation() string {
    return d.component.Operation()
}

// ConcreteDecorators: 具体的なデコレータ
type DecoratorA struct {
    component Component
}

func (d *DecoratorA) Operation() string {
    return "DecoratorA(" + d.component.Operation() + ")"
}

type DecoratorB struct {
    component Component
}

func (d *DecoratorB) Operation() string {
    return "DecoratorB(" + d.component.Operation() + ")"
}

// 使用例
func main() {
    component := &ConcreteComponent{}
    decoratedA := &DecoratorA{component: component}
    decoratedB := &DecoratorB{component: decoratedA}

    fmt.Println(decoratedB.Operation())
    // 出力: DecoratorB(DecoratorA(ConcreteComponent))
}
```

#### Goイディオム：HTTPミドルウェア
```go
// http.Handlerを拡張するミドルウェアパターン
func LoggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        log.Printf("Started %s %s", r.Method, r.URL.Path)

        next.ServeHTTP(w, r)

        log.Printf("Completed in %v", time.Since(start))
    })
}

func AuthMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        token := r.Header.Get("Authorization")
        if token != "valid-token" {
            http.Error(w, "Unauthorized", http.StatusUnauthorized)
            return
        }

        next.ServeHTTP(w, r)
    })
}

func CORSMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE")

        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusOK)
            return
        }

        next.ServeHTTP(w, r)
    })
}

// 使用例
func main() {
    mux := http.NewServeMux()

    handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Write([]byte("Hello, World!"))
    })

    // デコレータをチェーン
    decorated := LoggingMiddleware(
        AuthMiddleware(
            CORSMiddleware(handler),
        ),
    )

    mux.Handle("/", decorated)
    http.ListenAndServe(":8080", mux)
}
```

#### 実用例：ストリーム処理
```go
// Component
type DataReader interface {
    Read() ([]byte, error)
}

// ConcreteComponent
type FileDataReader struct {
    filePath string
}

func (f *FileDataReader) Read() ([]byte, error) {
    return os.ReadFile(f.filePath)
}

// Decorator: 圧縮解凍
type DecompressionDecorator struct {
    reader DataReader
}

func (d *DecompressionDecorator) Read() ([]byte, error) {
    data, err := d.reader.Read()
    if err != nil {
        return nil, err
    }

    // gzip解凍
    gzipReader, err := gzip.NewReader(bytes.NewReader(data))
    if err != nil {
        return nil, err
    }
    defer gzipReader.Close()

    return io.ReadAll(gzipReader)
}

// Decorator: 復号化
type DecryptionDecorator struct {
    reader DataReader
    key    []byte
}

func (d *DecryptionDecorator) Read() ([]byte, error) {
    data, err := d.reader.Read()
    if err != nil {
        return nil, err
    }

    // 復号化ロジック（簡略化）
    block, err := aes.NewCipher(d.key)
    if err != nil {
        return nil, err
    }

    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return nil, err
    }

    nonceSize := gcm.NonceSize()
    nonce, ciphertext := data[:nonceSize], data[nonceSize:]

    return gcm.Open(nil, nonce, ciphertext, nil)
}

// 使用例
func main() {
    reader := &FileDataReader{filePath: "data.bin"}

    // 圧縮 + 暗号化されたファイルを読む
    decoratedReader := &DecompressionDecorator{
        reader: &DecryptionDecorator{
            reader: reader,
            key:    []byte("32-byte-long-key-for-aes-256!!"),
        },
    }

    data, err := decoratedReader.Read()
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println(string(data))
}
```

### 使い所
- HTTPミドルウェア（認証、ログ、CORS等）
- ストリーム処理（圧縮、暗号化、バッファリング）
- 動的に機能を追加したい場合

---

## 5. Facade パターン

### 目的
複雑なサブシステムに対してシンプルな統一インターフェースを提供します。クライアントはサブシステムの詳細を知らずに操作できます。

### Go実装

#### 基本構造
```go
// 複雑なサブシステム
type SubsystemA struct{}

func (s *SubsystemA) OperationA1() string {
    return "SubsystemA: OperationA1"
}

func (s *SubsystemA) OperationA2() string {
    return "SubsystemA: OperationA2"
}

type SubsystemB struct{}

func (s *SubsystemB) OperationB1() string {
    return "SubsystemB: OperationB1"
}

type SubsystemC struct{}

func (s *SubsystemC) OperationC1() string {
    return "SubsystemC: OperationC1"
}

// Facade: シンプルなインターフェース
type Facade struct {
    subsystemA *SubsystemA
    subsystemB *SubsystemB
    subsystemC *SubsystemC
}

func NewFacade() *Facade {
    return &Facade{
        subsystemA: &SubsystemA{},
        subsystemB: &SubsystemB{},
        subsystemC: &SubsystemC{},
    }
}

func (f *Facade) Operation() string {
    results := []string{
        "Facade initializes subsystems:",
        f.subsystemA.OperationA1(),
        f.subsystemB.OperationB1(),
        f.subsystemC.OperationC1(),
    }
    return strings.Join(results, "\n")
}
```

#### 実用例：ECサイトの注文処理
```go
// サブシステム：在庫管理
type InventoryService struct{}

func (i *InventoryService) CheckStock(productID string) error {
    fmt.Printf("Checking stock for product %s\n", productID)
    // 在庫確認ロジック
    return nil
}

func (i *InventoryService) ReserveStock(productID string, quantity int) error {
    fmt.Printf("Reserving %d units of product %s\n", quantity, productID)
    return nil
}

// サブシステム：決済処理
type PaymentService struct{}

func (p *PaymentService) ValidateCard(cardNumber string) error {
    fmt.Printf("Validating card %s\n", cardNumber)
    return nil
}

func (p *PaymentService) ProcessPayment(amount float64) error {
    fmt.Printf("Processing payment of $%.2f\n", amount)
    return nil
}

// サブシステム：配送処理
type ShippingService struct{}

func (s *ShippingService) CalculateShipping(address string) float64 {
    fmt.Printf("Calculating shipping to %s\n", address)
    return 9.99
}

func (s *ShippingService) Ship(productID string, address string) error {
    fmt.Printf("Shipping product %s to %s\n", productID, address)
    return nil
}

// サブシステム：通知サービス
type NotificationService struct{}

func (n *NotificationService) SendOrderConfirmation(email string, orderID string) error {
    fmt.Printf("Sending confirmation email to %s for order %s\n", email, orderID)
    return nil
}

// Facade
type OrderFacade struct {
    inventory    *InventoryService
    payment      *PaymentService
    shipping     *ShippingService
    notification *NotificationService
}

func NewOrderFacade() *OrderFacade {
    return &OrderFacade{
        inventory:    &InventoryService{},
        payment:      &PaymentService{},
        shipping:     &ShippingService{},
        notification: &NotificationService{},
    }
}

type Order struct {
    ProductID  string
    Quantity   int
    CardNumber string
    Address    string
    Email      string
    Amount     float64
}

func (f *OrderFacade) PlaceOrder(order Order) error {
    // 在庫確認
    if err := f.inventory.CheckStock(order.ProductID); err != nil {
        return fmt.Errorf("stock check failed: %w", err)
    }

    // 在庫予約
    if err := f.inventory.ReserveStock(order.ProductID, order.Quantity); err != nil {
        return fmt.Errorf("stock reservation failed: %w", err)
    }

    // カード検証
    if err := f.payment.ValidateCard(order.CardNumber); err != nil {
        return fmt.Errorf("card validation failed: %w", err)
    }

    // 配送料計算
    shippingCost := f.shipping.CalculateShipping(order.Address)
    totalAmount := order.Amount + shippingCost

    // 決済処理
    if err := f.payment.ProcessPayment(totalAmount); err != nil {
        return fmt.Errorf("payment processing failed: %w", err)
    }

    // 配送手配
    if err := f.shipping.Ship(order.ProductID, order.Address); err != nil {
        return fmt.Errorf("shipping arrangement failed: %w", err)
    }

    // 確認通知
    orderID := "ORD-" + time.Now().Format("20060102150405")
    if err := f.notification.SendOrderConfirmation(order.Email, orderID); err != nil {
        return fmt.Errorf("notification failed: %w", err)
    }

    fmt.Println("Order placed successfully!")
    return nil
}

// 使用例
func main() {
    facade := NewOrderFacade()

    order := Order{
        ProductID:  "PROD-123",
        Quantity:   2,
        CardNumber: "1234-5678-9012-3456",
        Address:    "123 Main St, City, Country",
        Email:      "customer@example.com",
        Amount:     99.99,
    }

    if err := facade.PlaceOrder(order); err != nil {
        log.Fatal(err)
    }
}
```

### 使い所
- 複雑なサブシステムを簡単に使えるようにしたい
- サブシステムへの依存を減らしたい
- レイヤー化されたシステムでエントリポイントを提供したい

---

## 6. Flyweight パターン

### 目的
多数のオブジェクト間でデータを共有してメモリ使用量を削減します。固有状態（intrinsic state）と外部状態（extrinsic state）を分離することで、オブジェクトの再利用を実現します。

### Go実装

#### 基本構造
```go
// Flyweight: 共有されるオブジェクト
type TreeType struct {
    name    string
    color   string
    texture string
}

func (t *TreeType) Draw(x, y float64) {
    fmt.Printf("Drawing %s tree at (%f, %f)\n", t.name, x, y)
}

// Context: 外部状態を持つオブジェクト
type Tree struct {
    x, y     float64        // 外部状態（各インスタンス固有）
    treeType *TreeType      // 固有状態（共有）
}

func (t *Tree) Draw() {
    t.treeType.Draw(t.x, t.y)
}

// FlyweightFactory: Flyweightの生成と管理
type TreeFactory struct {
    treeTypes map[string]*TreeType
}

func NewTreeFactory() *TreeFactory {
    return &TreeFactory{
        treeTypes: make(map[string]*TreeType),
    }
}

func (f *TreeFactory) GetTreeType(name, color, texture string) *TreeType {
    key := name + "_" + color + "_" + texture

    if treeType, exists := f.treeTypes[key]; exists {
        return treeType
    }

    treeType := &TreeType{
        name:    name,
        color:   color,
        texture: texture,
    }
    f.treeTypes[key] = treeType

    fmt.Printf("Created new TreeType: %s\n", key)
    return treeType
}
```

#### 実用例：森林シミュレーション
```go
type Forest struct {
    trees   []*Tree
    factory *TreeFactory
}

func NewForest() *Forest {
    return &Forest{
        trees:   make([]*Tree, 0),
        factory: NewTreeFactory(),
    }
}

func (f *Forest) PlantTree(x, y float64, name, color, texture string) {
    treeType := f.factory.GetTreeType(name, color, texture)
    tree := &Tree{
        x:        x,
        y:        y,
        treeType: treeType,
    }
    f.trees = append(f.trees, tree)
}

func (f *Forest) Draw() {
    for _, tree := range f.trees {
        tree.Draw()
    }
}

// 使用例
func main() {
    forest := NewForest()

    // 100万本の木を植える（実際には3種類のTreeTypeだけが共有される）
    for i := 0; i < 1000000; i++ {
        x := rand.Float64() * 1000
        y := rand.Float64() * 1000

        // ランダムに木の種類を選択
        treeTypes := []struct{ name, color, texture string }{
            {"Oak", "Green", "Rough"},
            {"Pine", "Dark Green", "Smooth"},
            {"Birch", "White", "Papery"},
        }
        treeType := treeTypes[rand.Intn(3)]

        forest.PlantTree(x, y, treeType.name, treeType.color, treeType.texture)
    }

    fmt.Printf("Total trees: %d\n", len(forest.trees))
    fmt.Printf("TreeType instances: %d\n", len(forest.factory.treeTypes))

    // メモリ使用量の比較
    // Flyweightなし: 1,000,000 * sizeof(TreeType) ≈ 24MB（仮定）
    // Flyweightあり: 3 * sizeof(TreeType) + 1,000,000 * sizeof(Tree) ≈ 16MB
}
```

#### 実用例：テキストエディタの文字オブジェクト
```go
// Flyweight: 文字の共有属性
type CharacterStyle struct {
    font   string
    size   int
    color  string
    bold   bool
    italic bool
}

// Context: 文字の位置情報
type Character struct {
    char  rune
    row   int
    col   int
    style *CharacterStyle
}

// FlyweightFactory
type StyleFactory struct {
    styles map[string]*CharacterStyle
}

func NewStyleFactory() *StyleFactory {
    return &StyleFactory{
        styles: make(map[string]*CharacterStyle),
    }
}

func (f *StyleFactory) GetStyle(font string, size int, color string, bold, italic bool) *CharacterStyle {
    key := fmt.Sprintf("%s_%d_%s_%t_%t", font, size, color, bold, italic)

    if style, exists := f.styles[key]; exists {
        return style
    }

    style := &CharacterStyle{
        font:   font,
        size:   size,
        color:  color,
        bold:   bold,
        italic: italic,
    }
    f.styles[key] = style

    return style
}

type TextEditor struct {
    characters []*Character
    factory    *StyleFactory
}

func NewTextEditor() *TextEditor {
    return &TextEditor{
        characters: make([]*Character, 0),
        factory:    NewStyleFactory(),
    }
}

func (e *TextEditor) InsertCharacter(char rune, row, col int, font string, size int, color string, bold, italic bool) {
    style := e.factory.GetStyle(font, size, color, bold, italic)
    character := &Character{
        char:  char,
        row:   row,
        col:   col,
        style: style,
    }
    e.characters = append(e.characters, character)
}
```

#### Go標準ライブラリの代替：sync.Pool
```go
// sync.Poolは一時的なオブジェクトの再利用に使用
type Buffer struct {
    data []byte
}

var bufferPool = sync.Pool{
    New: func() interface{} {
        return &Buffer{
            data: make([]byte, 0, 1024),
        }
    },
}

func ProcessData(input []byte) []byte {
    // Poolからバッファを取得
    buf := bufferPool.Get().(*Buffer)
    defer bufferPool.Put(buf) // 使用後にPoolに返却

    // バッファをリセット
    buf.data = buf.data[:0]

    // 処理
    buf.data = append(buf.data, input...)
    // ...その他の処理

    // 結果をコピーして返す
    result := make([]byte, len(buf.data))
    copy(result, buf.data)
    return result
}
```

### 使い所
- 大量の類似オブジェクトを生成する（ゲームの粒子システム、テキストエディタ）
- メモリ使用量を削減したい
- オブジェクトの固有状態と外部状態が明確に分離できる

---

## 7. Proxy パターン

### 目的
オブジェクトへのアクセスを制御する代理オブジェクトを提供します。実オブジェクトの前にプロキシを配置することで、遅延初期化、アクセス制御、ログ記録、キャッシュなどの機能を追加できます。

### 種類
1. **Virtual Proxy**: 重い処理を遅延初期化
2. **Protection Proxy**: アクセス権限を制御
3. **Caching Proxy**: 結果をキャッシュして性能向上
4. **Remote Proxy**: リモートオブジェクトへのアクセスを提供
5. **Logging Proxy**: アクセスをログに記録

### Go実装

#### 基本構造
```go
// Subject: 共通インターフェース
type Subject interface {
    Request() string
}

// RealSubject: 実際のオブジェクト
type RealSubject struct{}

func (r *RealSubject) Request() string {
    return "RealSubject: Handling request"
}

// Proxy: プロキシオブジェクト
type Proxy struct {
    realSubject *RealSubject
}

func (p *Proxy) Request() string {
    // 遅延初期化
    if p.realSubject == nil {
        fmt.Println("Proxy: Initializing RealSubject")
        p.realSubject = &RealSubject{}
    }

    // アクセス制御、ログ記録等
    fmt.Println("Proxy: Before forwarding request")
    result := p.realSubject.Request()
    fmt.Println("Proxy: After forwarding request")

    return result
}
```

#### 実用例1：Virtual Proxy（遅延初期化）
```go
// 重い処理を行うサービス
type ImageService interface {
    Display() string
}

type HighResolutionImage struct {
    filename string
}

func NewHighResolutionImage(filename string) *HighResolutionImage {
    img := &HighResolutionImage{filename: filename}
    img.loadFromDisk()
    return img
}

func (h *HighResolutionImage) loadFromDisk() {
    fmt.Printf("Loading high-resolution image: %s\n", h.filename)
    time.Sleep(2 * time.Second) // 重い処理をシミュレート
}

func (h *HighResolutionImage) Display() string {
    return fmt.Sprintf("Displaying %s", h.filename)
}

// Virtual Proxy
type ImageProxy struct {
    filename string
    image    *HighResolutionImage
}

func NewImageProxy(filename string) *ImageProxy {
    return &ImageProxy{filename: filename}
}

func (p *ImageProxy) Display() string {
    // 実際に表示する必要があるまで画像をロードしない
    if p.image == nil {
        p.image = NewHighResolutionImage(p.filename)
    }
    return p.image.Display()
}

// 使用例
func main() {
    images := []ImageService{
        NewImageProxy("photo1.jpg"),
        NewImageProxy("photo2.jpg"),
        NewImageProxy("photo3.jpg"),
    }

    fmt.Println("Images created (not loaded yet)")

    // 最初の画像だけを表示（他はロードされない）
    fmt.Println(images[0].Display())
}
```

#### 実用例2：Protection Proxy（アクセス制御）
```go
type DocumentService interface {
    Read() string
    Write(content string) error
}

type Document struct {
    content string
}

func (d *Document) Read() string {
    return d.content
}

func (d *Document) Write(content string) error {
    d.content = content
    return nil
}

// Protection Proxy
type ProtectedDocument struct {
    document *Document
    user     string
    role     string
}

func NewProtectedDocument(user, role string) *ProtectedDocument {
    return &ProtectedDocument{
        document: &Document{content: "Confidential data"},
        user:     user,
        role:     role,
    }
}

func (p *ProtectedDocument) Read() string {
    if p.role != "admin" && p.role != "user" {
        return "Access denied: insufficient permissions"
    }
    return p.document.Read()
}

func (p *ProtectedDocument) Write(content string) error {
    if p.role != "admin" {
        return fmt.Errorf("access denied: only admins can write")
    }
    return p.document.Write(content)
}

// 使用例
func main() {
    admin := NewProtectedDocument("alice", "admin")
    user := NewProtectedDocument("bob", "user")
    guest := NewProtectedDocument("charlie", "guest")

    fmt.Println("Admin read:", admin.Read())
    fmt.Println("User read:", user.Read())
    fmt.Println("Guest read:", guest.Read())

    fmt.Println("Admin write:", admin.Write("Updated data"))
    fmt.Println("User write:", user.Write("Attempt to update"))
}
```

#### 実用例3：Caching Proxy（結果キャッシュ）
```go
type APIService interface {
    GetUser(id string) (*User, error)
}

type User struct {
    ID   string
    Name string
}

type RemoteAPI struct{}

func (r *RemoteAPI) GetUser(id string) (*User, error) {
    fmt.Printf("Fetching user %s from remote API...\n", id)
    time.Sleep(1 * time.Second) // ネットワーク遅延をシミュレート

    return &User{
        ID:   id,
        Name: "User " + id,
    }, nil
}

// Caching Proxy
type CachingAPIProxy struct {
    api   *RemoteAPI
    cache map[string]*User
    mu    sync.RWMutex
}

func NewCachingAPIProxy() *CachingAPIProxy {
    return &CachingAPIProxy{
        api:   &RemoteAPI{},
        cache: make(map[string]*User),
    }
}

func (p *CachingAPIProxy) GetUser(id string) (*User, error) {
    // キャッシュをチェック
    p.mu.RLock()
    if user, exists := p.cache[id]; exists {
        p.mu.RUnlock()
        fmt.Printf("Cache hit for user %s\n", id)
        return user, nil
    }
    p.mu.RUnlock()

    // キャッシュミス：リモートAPIから取得
    user, err := p.api.GetUser(id)
    if err != nil {
        return nil, err
    }

    // キャッシュに保存
    p.mu.Lock()
    p.cache[id] = user
    p.mu.Unlock()

    return user, nil
}

// 使用例
func main() {
    proxy := NewCachingAPIProxy()

    // 1回目：リモートAPIから取得
    user1, _ := proxy.GetUser("123")
    fmt.Println(user1.Name)

    // 2回目：キャッシュから取得（高速）
    user2, _ := proxy.GetUser("123")
    fmt.Println(user2.Name)
}
```

#### 実用例4：Logging Proxy（ログ記録）
```go
type DatabaseService interface {
    Query(sql string) ([]map[string]interface{}, error)
}

type Database struct{}

func (d *Database) Query(sql string) ([]map[string]interface{}, error) {
    // 実際のクエリ実行
    return []map[string]interface{}{
        {"id": 1, "name": "Alice"},
        {"id": 2, "name": "Bob"},
    }, nil
}

// Logging Proxy
type LoggingDatabaseProxy struct {
    db     *Database
    logger *log.Logger
}

func NewLoggingDatabaseProxy() *LoggingDatabaseProxy {
    return &LoggingDatabaseProxy{
        db:     &Database{},
        logger: log.New(os.Stdout, "[DB] ", log.LstdFlags),
    }
}

func (p *LoggingDatabaseProxy) Query(sql string) ([]map[string]interface{}, error) {
    start := time.Now()
    p.logger.Printf("Executing query: %s", sql)

    result, err := p.db.Query(sql)

    duration := time.Since(start)
    if err != nil {
        p.logger.Printf("Query failed: %v (took %v)", err, duration)
        return nil, err
    }

    p.logger.Printf("Query succeeded: returned %d rows (took %v)", len(result), duration)
    return result, nil
}
```

#### 実用例5：APIレート制限Proxy
```go
type RateLimitedAPI struct {
    api       APIService
    limiter   *rate.Limiter
    maxRetries int
}

func NewRateLimitedAPI(api APIService, requestsPerSecond int) *RateLimitedAPI {
    return &RateLimitedAPI{
        api:       api,
        limiter:   rate.NewLimiter(rate.Limit(requestsPerSecond), requestsPerSecond),
        maxRetries: 3,
    }
}

func (r *RateLimitedAPI) GetUser(id string) (*User, error) {
    ctx := context.Background()

    for i := 0; i < r.maxRetries; i++ {
        if err := r.limiter.Wait(ctx); err != nil {
            return nil, fmt.Errorf("rate limit wait failed: %w", err)
        }

        user, err := r.api.GetUser(id)
        if err == nil {
            return user, nil
        }

        fmt.Printf("Attempt %d failed: %v\n", i+1, err)
        time.Sleep(time.Second * time.Duration(i+1))
    }

    return nil, fmt.Errorf("max retries exceeded")
}
```

### 使い所
- 遅延初期化（重いオブジェクトの作成を遅延）
- アクセス制御（権限チェック）
- 結果のキャッシュ（性能向上）
- ログ記録（監査トレイル）
- レート制限（API呼び出し制御）

---

## パターン選択ガイド

### 状況別推奨パターン

| 状況 | 推奨パターン | 理由 |
|------|------------|------|
| 外部ライブラリのAPI変換 | Adapter | インターフェースの不一致を解消 |
| 抽象と実装を独立して変更 | Bridge | 抽象と実装の分離により柔軟性向上 |
| 再帰的なツリー構造 | Composite | 個別/複合オブジェクトを統一的に扱える |
| 機能の動的追加（ミドルウェア等） | Decorator | 継承を使わず機能を追加 |
| 複雑なサブシステムの簡略化 | Facade | シンプルな統一インターフェースを提供 |
| 大量の類似オブジェクトのメモリ最適化 | Flyweight | 共有可能な部分を抽出してメモリ削減 |
| アクセス制御・遅延初期化・キャッシュ | Proxy | 実オブジェクトへのアクセスを制御 |

### パターン間の比較

#### Adapter vs Bridge
- **Adapter**: 既存の互換性のないインターフェースを変換（事後対応）
- **Bridge**: 設計時から抽象と実装を分離（事前設計）

#### Decorator vs Proxy
- **Decorator**: オブジェクトに機能を追加（振る舞いの拡張）
- **Proxy**: オブジェクトへのアクセスを制御（アクセスの管理）

#### Composite vs Decorator
- **Composite**: 再帰的なツリー構造（部分-全体の関係）
- **Decorator**: 線形的な機能追加（ラッパーのチェーン）

### Goでの実装時の注意点

1. **インターフェースを活用**: 小さなインターフェースで柔軟性を確保
2. **埋め込み（Embedding）の活用**: 継承の代わりに構造体埋め込みを使用
3. **エラーハンドリング**: パターン内でのエラー伝播を明確にする
4. **並行処理**: 必要に応じて `sync.Mutex` や `sync.RWMutex` で保護
5. **メモリ管理**: Flyweightやプールパターンでメモリ効率を意識

### アンチパターン

以下の状況では過度な設計になる可能性があります：

- シンプルな問題に対して複雑なパターンを適用
- 将来の拡張性を過度に意識した設計（YAGNI原則違反）
- パターンの適用が目的化してしまう

**原則**: まずシンプルに実装し、必要になったときにパターンを導入する（KISS原則）。
