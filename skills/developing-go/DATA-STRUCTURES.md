# クリーンなデータ構造設計

Goにおけるクリーンなデータ構造設計のベストプラクティス集。

---

## 1. クリーンな構造体設計（Designing Structs for Clarity）

### 単一責任原則（Single Responsibility Principle）

各構造体は1つの責任のみを持つべきです。複数の責任が混在すると、変更理由が増え、保守性が低下します。

```go
// ❌ モノリス構造体 - 複数の責任が混在
type Customer struct {
    // 顧客情報
    ID        int
    FirstName string
    LastName  string
    Email     string

    // 住所情報
    Street    string
    City      string
    Country   string
    PostCode  string

    // 注文情報
    OrderID   int
    Items     []Item
    Total     float64

    // 支払い情報
    CardNumber string
    ExpMonth   int
    ExpYear    int
}

// ✅ 責任ごとに分割
type Customer struct {
    ID        int
    FirstName string
    LastName  string
    Email     string
}

type Address struct {
    Street   string
    City     string
    Country  string
    PostCode string
}

type Order struct {
    ID         int
    CustomerID int
    Items      []Item
    TotalPrice float64
}

type PaymentMethod struct {
    CardNumber string
    ExpMonth   int
    ExpYear    int
}
```

### フィールドの論理的グループ化

関連するフィールドはグループ化し、空行で視覚的に区切ります。

```go
// ❌ 無秩序なフィールド配置
type User struct {
    ID        int
    CreatedAt time.Time
    Name      string
    UpdatedAt time.Time
    Email     string
    IsActive  bool
}

// ✅ 論理的にグループ化
type User struct {
    // 識別情報
    ID    int
    Email string

    // プロフィール
    Name     string
    IsActive bool

    // タイムスタンプ
    CreatedAt time.Time
    UpdatedAt time.Time
}
```

### 構造体タグの適切な使用

JSONシリアライズ、データベースマッピング、バリデーションなどに構造体タグを活用します。

```go
type Product struct {
    ID          int       `json:"id" db:"product_id"`
    Name        string    `json:"name" db:"name" validate:"required,min=3"`
    Price       float64   `json:"price" db:"price" validate:"required,gt=0"`
    Description string    `json:"description,omitempty" db:"description"`
    CreatedAt   time.Time `json:"created_at" db:"created_at"`

    // JSONに含めないフィールド
    InternalCode string `json:"-" db:"internal_code"`
}
```

### ポインタフィールドによるオプショナル値表現

`nil` を使ってフィールドの「未設定」状態を表現できます。

```go
// ❌ ゼロ値と未設定を区別できない
type Config struct {
    Port    int    // 0 がデフォルト値か未設定か不明
    Timeout int
    Debug   bool   // false がデフォルト値か未設定か不明
}

// ✅ ポインタでオプショナル値を表現
type Config struct {
    Port    *int  // nil なら未設定、値があれば設定済み
    Timeout *int
    Debug   *bool
}

// 使用例
func ApplyDefaults(c *Config) {
    if c.Port == nil {
        defaultPort := 8080
        c.Port = &defaultPort
    }
    if c.Debug == nil {
        defaultDebug := false
        c.Debug = &defaultDebug
    }
}
```

### 値オブジェクトの Equal メソッド実装

値オブジェクト（Value Object）は同一性ではなく等価性で比較します。

```go
type Money struct {
    amount   int64
    currency string
}

func NewMoney(amount int64, currency string) Money {
    return Money{amount: amount, currency: currency}
}

// ✅ Equal メソッドで等価性を定義
func (m Money) Equal(other Money) bool {
    return m.amount == other.amount && m.currency == other.currency
}

// 使用例
price1 := NewMoney(1000, "JPY")
price2 := NewMoney(1000, "JPY")

// ❌ ポインタ比較では false
if &price1 == &price2 {
    // これは false
}

// ✅ Equal メソッドで正しく比較
if price1.Equal(price2) {
    fmt.Println("Same price") // これが実行される
}
```

### 巨大構造体の分割

20フィールドを超える構造体は責任が多すぎる可能性があります。

```go
// ❌ 巨大構造体（40+フィールド）
type Employee struct {
    // 基本情報
    ID, DepartmentID, ManagerID int
    FirstName, LastName, Email, Phone string

    // 住所
    Street, City, State, Country, PostCode string

    // 雇用情報
    HireDate, TerminationDate time.Time
    EmploymentType, JobTitle, Level string

    // 給与情報
    Salary, Bonus float64
    Currency string

    // 福利厚生
    HasHealthInsurance, HasDentalInsurance bool
    VacationDays, SickDays int

    // その他...
}

// ✅ ドメインごとに分割
type Employee struct {
    ID         int
    PersonInfo PersonInfo
    Contact    ContactInfo
    Employment EmploymentInfo
}

type PersonInfo struct {
    FirstName string
    LastName  string
}

type ContactInfo struct {
    Email   string
    Phone   string
    Address Address
}

type EmploymentInfo struct {
    HireDate       time.Time
    JobTitle       string
    DepartmentID   int
    Compensation   Compensation
}

type Compensation struct {
    Salary   float64
    Bonus    float64
    Currency string
}
```

---

## 2. インターフェースの賢い使い方（Using Interfaces Wisely）

### 小さく焦点を絞る

理想的なインターフェースは1-2メソッドのみを持ちます。

```go
// ✅ Go標準ライブラリの模範例
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

type Closer interface {
    Close() error
}

// ❌ 巨大インターフェース（Interface Segregation Principle違反）
type FileSystem interface {
    Read(name string) ([]byte, error)
    Write(name string, data []byte) error
    Remove(name string) error
    List(dir string) ([]string, error)
    Rename(oldPath, newPath string) error
    Stat(name string) (FileInfo, error)
    Chmod(name string, mode FileMode) error
    Chown(name string, uid, gid int) error
}

// ✅ 分離されたインターフェース（ISP準拠）
type FileReader interface {
    Read(name string) ([]byte, error)
}

type FileWriter interface {
    Write(name string, data []byte) error
}

type FileRemover interface {
    Remove(name string) error
}

type FileLister interface {
    List(dir string) ([]string, error)
}
```

### 振る舞いベース設計

インターフェースは「何ができるか」を定義します。データではなく動作に焦点を当てます。

```go
// ❌ データベース特化（実装詳細が漏れている）
type MySQLRepository interface {
    ExecuteQuery(query string) (*sql.Rows, error)
    BeginTransaction() (*sql.Tx, error)
}

// ✅ 振る舞いベース（何ができるか）
type UserRepository interface {
    FindByID(id int) (*User, error)
    Save(user *User) error
}

// 実装は自由（MySQL, PostgreSQL, in-memory, mock...）
type mysqlUserRepo struct {
    db *sql.DB
}

func (r *mysqlUserRepo) FindByID(id int) (*User, error) {
    // MySQL固有の実装
    return nil, nil
}
```

### コンポジション（組み合わせ）

小さなインターフェースを組み合わせて大きな機能を表現します。

```go
// ✅ 小さなインターフェース
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

type Closer interface {
    Close() error
}

// ✅ コンポジション
type ReadWriter interface {
    Reader
    Writer
}

type ReadWriteCloser interface {
    Reader
    Writer
    Closer
}

// 使用例: 必要な機能だけを受け取る
func CopyData(dst Writer, src Reader) error {
    buf := make([]byte, 32*1024)
    for {
        n, err := src.Read(buf)
        if n > 0 {
            if _, writeErr := dst.Write(buf[:n]); writeErr != nil {
                return writeErr
            }
        }
        if err != nil {
            if err == io.EOF {
                break
            }
            return err
        }
    }
    return nil
}
```

### テスタビリティ

小さなインターフェースはmock実装が容易です。

```go
// ✅ シンプルなインターフェース
type EmailSender interface {
    Send(to, subject, body string) error
}

// ✅ テスト用mock実装が簡単
type MockEmailSender struct {
    SentEmails []Email
}

type Email struct {
    To      string
    Subject string
    Body    string
}

func (m *MockEmailSender) Send(to, subject, body string) error {
    m.SentEmails = append(m.SentEmails, Email{to, subject, body})
    return nil
}

// テストコード
func TestUserRegistration(t *testing.T) {
    mockSender := &MockEmailSender{}
    service := NewUserService(mockSender)

    service.Register("user@example.com", "password")

    if len(mockSender.SentEmails) != 1 {
        t.Errorf("Expected 1 email, got %d", len(mockSender.SentEmails))
    }
    if mockSender.SentEmails[0].Subject != "Welcome!" {
        t.Errorf("Unexpected subject: %s", mockSender.SentEmails[0].Subject)
    }
}
```

### 「インターフェースを受け取り、構造体を返す」原則

関数の引数には抽象（インターフェース）を、戻り値には具象（構造体）を使います。

```go
// ✅ インターフェースを受け取り、構造体を返す
func ProcessReader(r io.Reader) (*Result, error) {
    // 引数: インターフェース（柔軟性）
    // 戻り値: 具象型（明確性）
    data, err := io.ReadAll(r)
    if err != nil {
        return nil, err
    }
    return &Result{Data: data}, nil
}

// ❌ 逆パターン（柔軟性が低い）
func ProcessFile(f *os.File) (io.Reader, error) {
    // 引数: 具象型（os.Fileしか受け取れない）
    // 戻り値: インターフェース（実装がわからない）
    return f, nil
}
```

### empty interface の回避と generics

Go 1.18+では、`interface{}` の代わりに型パラメータ（generics）を使用します。

```go
// ❌ 型安全性なし（Go 1.17以前のパターン）
func PrintAnything(v interface{}) {
    fmt.Println(v)
}

func Max(a, b interface{}) interface{} {
    // 型アサーションが必要
    aInt := a.(int)
    bInt := b.(int)
    if aInt > bInt {
        return aInt
    }
    return bInt
}

// ✅ generics で型安全（Go 1.18+）
func PrintAnything[T any](v T) {
    fmt.Println(v)
}

func Max[T constraints.Ordered](a, b T) T {
    if a > b {
        return a
    }
    return b
}

// 使用例
result := Max(10, 20)        // int型
price := Max(9.99, 12.50)    // float64型
name := Max("Alice", "Bob")  // string型
```

---

## 3. コレクション操作（Maps, Slices）

### map: キー存在チェックの慣用表現

mapからキーを取得する際は、2つ目の戻り値で存在チェックを行います。

```go
userScores := map[string]int{
    "Alice": 95,
    "Bob":   82,
}

// ❌ 存在チェックなし（ゼロ値と未登録を区別できない）
score := userScores["Charlie"] // 0（未登録だが、0点と区別できない）

// ✅ 存在チェックあり
if score, exists := userScores["Alice"]; exists {
    fmt.Printf("Alice's score: %d\n", score)
} else {
    fmt.Println("Alice not found")
}

// ✅ デフォルト値を設定
score, exists := userScores["Charlie"]
if !exists {
    score = 50 // デフォルト値
}
```

### slice: 容量を事前確保してパフォーマンス改善

要素数が事前にわかっている場合、`make` で容量を確保します。

```go
// ❌ 事前確保なし（リサイズが頻繁に発生）
var data []int
for i := 0; i < 1000; i++ {
    data = append(data, i) // 容量不足のたびにメモリ再割り当て
}

// ✅ 容量を事前確保（効率的）
data := make([]int, 0, 1000) // len=0, cap=1000
for i := 0; i < 1000; i++ {
    data = append(data, i) // メモリ再割り当てなし
}

// ✅ 長さと容量を同時に確保（インデックスアクセス時）
data := make([]int, 1000) // len=1000, cap=1000
for i := 0; i < 1000; i++ {
    data[i] = i // append不要
}
```

### nil map/sliceの安全な扱い

`nil` map/sliceは読み取りは安全ですが、書き込みはpanicします。

```go
// ❌ nil mapへの書き込み（panic）
var scores map[string]int
scores["Alice"] = 95 // panic: assignment to entry in nil map

// ✅ 初期化してから書き込み
scores := make(map[string]int)
scores["Alice"] = 95

// ✅ nil mapからの読み取りは安全（ゼロ値が返る）
var scores map[string]int
score := scores["Alice"] // 0（panic しない）

// ✅ nil sliceは安全
var items []string
fmt.Println(len(items))    // 0
items = append(items, "a") // append は安全に動作

// ❌ nil sliceへのインデックスアクセス（panic）
var items []string
items[0] = "a" // panic: index out of range
```

### nil slice vs 空 slice の返却基準

`nil` slice と空slice（`[]T{}`）は振る舞いがほぼ同じですが、JSONエンコード時に違いが出ます。

```go
// nil slice: 結果が存在しない場合
func FindUsers(query string) []User {
    // データベースで検索
    if noResultsFound {
        return nil // "結果なし"を表現
    }
    return users
}

// 空 slice: 結果は存在するが空の場合
func GetActiveUsers() []User {
    // アクティブユーザーが0人でも、結果セットは存在する
    return []User{} // 明示的に空のコレクション
}

// JSON エンコード時の違い
nilSlice := []int(nil)
emptySlice := []int{}

json.Marshal(nilSlice)   // "null"
json.Marshal(emptySlice) // "[]"
```

**推奨**: 通常は `nil` を返し、APIレスポンスで空配列 `[]` が必要な場合のみ `[]T{}` を使います。

### `sync.Map` による並行安全なmap操作

複数goroutineから同じmapにアクセスする場合、`sync.Map` または `sync.RWMutex` を使います。

```go
// ❌ 通常のmapは並行アクセス不可（data race）
var cache map[string]string
go func() { cache["key1"] = "value1" }() // data race
go func() { cache["key2"] = "value2" }() // data race

// ✅ sync.Map で並行安全
var cache sync.Map
go func() { cache.Store("key1", "value1") }() // 安全
go func() { cache.Store("key2", "value2") }() // 安全

value, ok := cache.Load("key1")
if ok {
    fmt.Println(value.(string))
}

// ✅ sync.RWMutex で保護（型安全）
type SafeCache struct {
    mu    sync.RWMutex
    items map[string]string
}

func (c *SafeCache) Set(key, value string) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.items[key] = value
}

func (c *SafeCache) Get(key string) (string, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    val, ok := c.items[key]
    return val, ok
}
```

---

## 4. 不変性と読み取り専用構造体（Immutability and Read-Only）

### unexported フィールド + getter メソッドパターン

フィールドを非公開にして、変更不可能な値を提供します。

```go
// ✅ 不変構造体
type Person struct {
    name string // unexported（外部から変更不可）
    age  int
}

func NewPerson(name string, age int) Person {
    return Person{name: name, age: age}
}

// getter のみ提供（setter なし）
func (p Person) Name() string { return p.name }
func (p Person) Age() int     { return p.age }

// 使用例
person := NewPerson("Alice", 30)
fmt.Println(person.Name()) // "Alice"
// person.name = "Bob" // コンパイルエラー（unexported）
```

### Copy-on-Write パターン

変更時に新しいインスタンスを返し、元のインスタンスを変更しません。

```go
type Settings struct {
    theme    string
    fontSize int
    language string
}

func NewSettings() Settings {
    return Settings{
        theme:    "light",
        fontSize: 12,
        language: "en",
    }
}

// ✅ Copy-on-Write メソッド
func (s Settings) WithTheme(newTheme string) Settings {
    return Settings{
        theme:    newTheme,
        fontSize: s.fontSize,
        language: s.language,
    }
}

func (s Settings) WithFontSize(newSize int) Settings {
    return Settings{
        theme:    s.theme,
        fontSize: newSize,
        language: s.language,
    }
}

// ✅ メソッドチェーン可能
settings := NewSettings()
newSettings := settings.WithTheme("dark").WithFontSize(14)

fmt.Println(settings.theme)    // "light" (元のまま)
fmt.Println(newSettings.theme) // "dark" (新しいインスタンス)
```

### 並行処理での不変構造体の価値

不変データは複数goroutineから安全にアクセスできます（ロック不要）。

```go
// ✅ 不変構造体（並行安全）
type Config struct {
    host string
    port int
}

func (c Config) Host() string { return c.host }
func (c Config) Port() int    { return c.port }

// 複数goroutineから安全にアクセス可能
config := Config{host: "localhost", port: 8080}
for i := 0; i < 100; i++ {
    go func() {
        // ロックなしで読み取り可能
        fmt.Printf("Connecting to %s:%d\n", config.Host(), config.Port())
    }()
}

// ❌ 可変構造体（data race）
type MutableConfig struct {
    Host string
    Port int
}

mutableConfig := MutableConfig{Host: "localhost", Port: 8080}
go func() { mutableConfig.Port = 9090 }() // data race
go func() { fmt.Println(mutableConfig.Port) }() // data race
```

### ネストした構造体/sliceのディープコピー

不変性を保つには、ネストしたslice/mapもコピーが必要です。

```go
type Order struct {
    id    int
    items []string
}

// ❌ シャローコピー（sliceは共有される）
func (o Order) AddItem(item string) Order {
    o.items = append(o.items, item) // 元のsliceを変更してしまう
    return o
}

// ✅ ディープコピー
func (o Order) AddItem(item string) Order {
    newItems := make([]string, len(o.items)+1)
    copy(newItems, o.items)
    newItems[len(o.items)] = item

    return Order{
        id:    o.id,
        items: newItems, // 新しいslice
    }
}

// 使用例
order1 := Order{id: 1, items: []string{"Book"}}
order2 := order1.AddItem("Pen")

fmt.Println(order1.items) // ["Book"] (変更されない)
fmt.Println(order2.items) // ["Book", "Pen"]
```

---

## 5. データ関係の管理（Managing Data Relationships）

### フラットな構造（IDで参照）vs 深いネスト

深いネストは避け、IDで関連を表現します。

```go
// ❌ 深いネスト（変更が困難）
type Company struct {
    Name       string
    Departments []struct {
        Name      string
        Employees []struct {
            Name     string
            Projects []struct {
                Name     string
                Tasks    []string
            }
        }
    }
}

// ✅ フラット構造 + ID参照
type Company struct {
    ID   int
    Name string
}

type Department struct {
    ID        int
    CompanyID int // 外部キー
    Name      string
}

type Employee struct {
    ID           int
    DepartmentID int // 外部キー
    Name         string
}

type Project struct {
    ID   int
    Name string
}

type ProjectMember struct {
    ProjectID  int // 多対多の関連
    EmployeeID int
}
```

### Aggregate Root パターン

関連するエンティティ群を1つのルートから管理します（DDD由来のパターン）。

```go
// ✅ Aggregate Root
type Order struct {
    id         int
    customerID int
    items      []OrderItem // Aggregate Root が管理
    status     OrderStatus
}

type OrderItem struct {
    productID int
    quantity  int
    price     float64
}

// ✅ Aggregate Root 経由でのみ操作
func (o *Order) AddItem(productID int, quantity int, price float64) {
    // ビジネスルールをここで強制
    if o.status == OrderStatusShipped {
        panic("cannot add items to shipped order")
    }
    o.items = append(o.items, OrderItem{
        productID: productID,
        quantity:  quantity,
        price:     price,
    })
}

// ❌ 直接 OrderItem を操作させない
// order.items = append(order.items, item) // これを許可しない
```

### 深いネストの回避

3階層を超えるネストは読みにくく、保守が困難です。

```go
// ❌ 深いネスト（4階層以上）
type DeeplyNested struct {
    Field1 string
    Nested struct {
        Field2 int
        MoreNested struct {
            Field3 bool
            EvenMoreNested struct {
                Field4 float64
            }
        }
    }
}

// ネストを辿るのが大変
value := obj.Nested.MoreNested.EvenMoreNested.Field4

// ✅ フラット構造
type Level1 struct {
    Field1 string
    Level2ID int
}

type Level2 struct {
    ID       int
    Field2   int
    Level3ID int
}

type Level3 struct {
    ID     int
    Field3 bool
    Field4 float64
}

// IDで参照
level1 := GetLevel1(1)
level2 := GetLevel2(level1.Level2ID)
level3 := GetLevel3(level2.Level3ID)
```

---

## 6. データ構造設計チェックリスト

実装前・レビュー時に確認すべき項目:

```
構造体設計:
- [ ] 各構造体は単一責任か？
- [ ] フィールドは論理的にグループ化されているか？
- [ ] 20フィールドを超えていないか？（超える場合は分割検討）
- [ ] 構造体タグは適切に設定されているか？（JSON, DB等）
- [ ] オプショナル値はポインタで表現されているか？

インターフェース設計:
- [ ] インターフェースは1-2メソッドに絞られているか？
- [ ] 振る舞い（何ができるか）に焦点を当てているか？
- [ ] empty interface{} を使っていないか？（Go 1.18+ならgenericsを検討）
- [ ] mock実装が容易か？（テスタビリティ）

コレクション操作:
- [ ] mapのキー存在チェックを行っているか？
- [ ] slice容量は事前確保しているか？（パフォーマンス重視時）
- [ ] nil map/sliceの安全な扱いができているか？
- [ ] 並行アクセスされるmapは sync.Map または mutex で保護されているか？

不変性:
- [ ] 並行アクセスされる構造体は不変 or sync保護されているか？
- [ ] Copy-on-Write パターンを適用すべきか？
- [ ] ネストしたslice/mapもディープコピーしているか？

データ関係:
- [ ] データ関係はフラット（ID参照）か？
- [ ] 3階層を超えるネストを避けているか？
- [ ] Aggregate Root パターンが適切に適用されているか？
```

---

## まとめ

クリーンなデータ構造設計の要点:

1. **単一責任**: 1構造体 = 1責任
2. **小さなインターフェース**: 1-2メソッドが理想
3. **容量事前確保**: slice/mapのパフォーマンス最適化
4. **不変性**: 並行処理の安全性向上
5. **フラット構造**: IDで参照し、深いネストを避ける

これらの原則を守ることで、保守性・テスタビリティ・パフォーマンスの高いGoコードが実現できます。
