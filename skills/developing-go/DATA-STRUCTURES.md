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

---

## 7. 構造体の初期化方法（3つの方法と使い分け）

Goでは構造体をインスタンス化する方法が3つあります。それぞれの特徴を理解して使い分けます。

### 1. new()関数で作成

```go
// new()はポインタを返す
type Person struct {
    Name string
    Age  int
}

p := new(Person)
// *Person型、全フィールドはゼロ値で初期化
// p.Name == ""
// p.Age == 0

// フィールドを個別に設定
p.Name = "Alice"
p.Age = 30
```

**使用場面**: あまり使わない（複合リテラルの方が一般的）

### 2. var変数宣言で作成

```go
// var宣言は値型を生成
var p Person
// Person型（ポインタではない）、全フィールドはゼロ値
// p.Name == ""
// p.Age == 0

// ポインタ型のvar宣言
var pp *Person
// *Person型だが、ppは nil（インスタンスは作成されない）
```

**使用場面**: ゼロ値で初期化したい場合、関数内の一時変数

### 3. 複合リテラル（composite literal）で作成

```go
// 値型を生成
p1 := Person{
    Name: "Alice",
    Age:  30,
}
// Person型（値型）

// ポインタ型を生成
p2 := &Person{
    Name: "Bob",
    Age:  25,
}
// *Person型（ポインタ）

// フィールド名省略も可能（非推奨）
p3 := Person{"Charlie", 28}
// 構造体定義の順序に依存（壊れやすい）
```

**使用場面**: 最も一般的。初期値を設定したい場合に使用

### 使い分けの基準

| 方法 | 生成される型 | フィールド初期値 | 使用場面 |
|-----|------------|----------------|---------|
| `new(T)` | `*T` | ゼロ値のみ | ほぼ使わない |
| `var t T` | `T` | ゼロ値のみ | ゼロ値初期化、一時変数 |
| `var t *T` | `*T` (nil) | なし | ポインタ変数の宣言 |
| `T{...}` | `T` | 初期値設定可 | 値型で初期化 |
| `&T{...}` | `*T` | 初期値設定可 | **最も一般的** |

### ファクトリー関数パターン（推奨）

外部に公開する構造体には、ファクトリー関数を用意します。

```go
type Database struct {
    host     string
    port     int
    user     string
    password string
    timeout  time.Duration
}

// ✅ ファクトリー関数を提供
func NewDatabase(host, user, password string) *Database {
    return &Database{
        host:     host,
        port:     5432,  // デフォルト値
        user:     user,
        password: password,
        timeout:  30 * time.Second,  // デフォルト値
    }
}

// 使用例
db := NewDatabase("localhost", "admin", "secret")
// デフォルト値が設定済み
```

**ファクトリー関数のメリット**:
- ゼロ値以外の初期値を設定可能
- バリデーション実行可能
- 複数の初期化パターンを提供可能
- GoDoc上で使い方が明確

```go
// 複数のファクトリー関数の例
func NewDatabase(host, user, password string) *Database { ... }
func NewDatabaseWithTimeout(host, user, password string, timeout time.Duration) *Database { ... }
func NewDatabaseFromConfig(cfg Config) *Database { ... }
```

## 8. 値レシーバー vs ポインタレシーバーの選択基準

メソッドのレシーバーは値型またはポインタ型を選択できます。

### 値レシーバー（Value Receiver）

```go
type Point struct {
    X, Y int
}

// 値レシーバー: 構造体をコピーして渡す
func (p Point) Distance() float64 {
    return math.Sqrt(float64(p.X*p.X + p.Y*p.Y))
}

// 値を変更しても元のインスタンスは変わらない
func (p Point) Move(dx, dy int) {
    p.X += dx  // pはコピーなので元のインスタンスは変わらない
    p.Y += dy
}
```

**使用場面**:
- **イミュータブル（不変）** にしたい場合
- フィールドを変更しないメソッド
- 小さな構造体（数フィールド程度）

### ポインタレシーバー（Pointer Receiver）

```go
type Account struct {
    balance int
}

// ポインタレシーバー: 元のインスタンスを直接操作
func (a *Account) Deposit(amount int) {
    a.balance += amount  // 元のインスタンスが変更される
}

func (a *Account) Balance() int {
    return a.balance
}
```

**使用場面**:
- フィールドを変更するメソッド
- 大きな構造体（コピーコストが高い）
- **nilレシーバーでも動作させたい場合**

### 選択基準の表

| 条件 | レシーバー型 |
|-----|------------|
| フィールドを変更する | ポインタ |
| フィールドを変更しない（読み取りのみ） | 値またはポインタ |
| 構造体が大きい（10フィールド以上） | ポインタ |
| 構造体が小さい（数フィールド） | 値またはポインタ |
| インターフェースを実装する | **一貫してどちらか** |
| 並行アクセスされる | 値（イミュータブル） |

### nilレシーバーでもメソッド呼び出し可能

Goでは、レシーバーが`nil`でもメソッドを呼び出せます。

```go
type Tree struct {
    value int
    left  *Tree
    right *Tree
}

// nilレシーバーでも動作
func (t *Tree) Sum() int {
    if t == nil {
        return 0  // nilの場合は0を返す
    }
    return t.value + t.left.Sum() + t.right.Sum()
}

// 使用例
var tree *Tree  // nil
sum := tree.Sum()  // panic しない（0が返る）
```

### 値型とポインタ型の混在は避ける

同じ型のメソッドでは、値レシーバーとポインタレシーバーを混在させないようにします。

```go
// ❌ Bad: 混在
type User struct {
    Name string
    Age  int
}

func (u User) GetName() string {  // 値レシーバー
    return u.Name
}

func (u *User) SetAge(age int) {  // ポインタレシーバー
    u.Age = age
}

// ✅ Good: 統一（すべてポインタレシーバー）
func (u *User) GetName() string {
    return u.Name
}

func (u *User) SetAge(age int) {
    u.Age = age
}
```

## 9. 埋め込み（Embedding）の詳細

Goの埋め込みは継承に似ていますが、アップキャスト/ダウンキャストはできません。

### メソッドの自動マージ

埋め込んだ構造体のメソッドは、外側の構造体に自動的にマージされます。

```go
type Person struct {
    Name string
    Age  int
}

func (p *Person) Introduce() string {
    return fmt.Sprintf("My name is %s, I'm %d years old", p.Name, p.Age)
}

// Personを埋め込む
type Employee struct {
    Person     // 埋め込み
    Company string
    Salary  int
}

func (e *Employee) Work() string {
    return fmt.Sprintf("%s works at %s", e.Name, e.Company)
}

// 使用例
emp := Employee{
    Person:  Person{Name: "Alice", Age: 30},
    Company: "ACME Corp",
    Salary:  50000,
}

// Personのメソッドが自動的に利用可能
fmt.Println(emp.Introduce())  // "My name is Alice, I'm 30 years old"
fmt.Println(emp.Work())        // "Alice works at ACME Corp"

// フィールドにも直接アクセス可能
fmt.Println(emp.Name)  // "Alice"（emp.Person.Nameと同じ）
```

### 複数の埋め込みと同名フィールドの解決

複数の構造体を埋め込むと、同名フィールドが衝突する可能性があります。

```go
type Address struct {
    City    string
    Country string
}

type Contact struct {
    Email string
    Phone string
}

type Person struct {
    Name string
}

type User struct {
    Person  // 埋め込み1
    Address // 埋め込み2
    Contact // 埋め込み3
}

user := User{
    Person:  Person{Name: "Alice"},
    Address: Address{City: "Tokyo", Country: "Japan"},
    Contact: Contact{Email: "alice@example.com", Phone: "123-456"},
}

// すべてのフィールドに直接アクセス可能
fmt.Println(user.Name)    // "Alice"
fmt.Println(user.City)    // "Tokyo"
fmt.Println(user.Email)   // "alice@example.com"
```

**同名フィールドの場合**:

```go
type A struct {
    Value int
}

type B struct {
    Value int
}

type C struct {
    A
    B
}

c := C{
    A: A{Value: 10},
    B: B{Value: 20},
}

// ❌ コンパイルエラー: どちらのValueか曖昧
// fmt.Println(c.Value)

// ✅ 明示的に指定
fmt.Println(c.A.Value)  // 10
fmt.Println(c.B.Value)  // 20
```

### インターフェース実装の委譲

埋め込みを使ってインターフェースの実装を委譲できます。

```go
type Writer interface {
    Write(p []byte) (n int, err error)
}

// bytes.Bufferを埋め込む
type LogWriter struct {
    *bytes.Buffer  // Writerインターフェースを実装済み
    prefix        string
}

// LogWriter独自のメソッド
func (lw *LogWriter) WriteLog(message string) error {
    _, err := lw.Write([]byte(lw.prefix + message + "\n"))
    return err
}

// 使用例
lw := &LogWriter{
    Buffer: new(bytes.Buffer),
    prefix: "[LOG] ",
}

// bytes.BufferのWriteメソッドを継承
lw.Write([]byte("direct write\n"))

// LogWriter独自のメソッド
lw.WriteLog("custom log")

fmt.Println(lw.String())
// Output:
// direct write
// [LOG] custom log
```

## 10. 構造体タグの活用

構造体タグはメタデータとして、JSON/XML/DBマッピング、バリデーション等に活用されます。

### JSONシリアライズ

```go
type User struct {
    ID        int       `json:"id"`
    Name      string    `json:"name"`
    Email     string    `json:"email,omitempty"`  // 空なら省略
    Password  string    `json:"-"`                // JSONに含めない
    CreatedAt time.Time `json:"created_at"`
}

user := User{
    ID:        1,
    Name:      "Alice",
    Password:  "secret",
    CreatedAt: time.Now(),
}

data, _ := json.Marshal(user)
fmt.Println(string(data))
// Output: {"id":1,"name":"Alice","created_at":"2026-02-10T..."}
// Passwordは含まれない
```

### データベースマッピング

```go
type Product struct {
    ID          int       `db:"product_id"`
    Name        string    `db:"name"`
    Price       float64   `db:"price"`
    Description string    `db:"description"`
    CreatedAt   time.Time `db:"created_at"`
}

// sqlxなどのライブラリで使用
var products []Product
db.Select(&products, "SELECT * FROM products")
```

### バリデーション

```go
import "github.com/go-playground/validator/v10"

type SignupRequest struct {
    Email    string `json:"email" validate:"required,email"`
    Password string `json:"password" validate:"required,min=8"`
    Age      int    `json:"age" validate:"required,gte=18"`
}

validate := validator.New()
req := SignupRequest{
    Email:    "user@example.com",
    Password: "short",  // 8文字未満
    Age:      16,       // 18歳未満
}

err := validate.Struct(req)
if err != nil {
    for _, err := range err.(validator.ValidationErrors) {
        fmt.Println(err.Field(), err.Tag())
    }
}
// Output:
// Password min
// Age gte
```

### reflectでタグを読み取る

```go
import "reflect"

type Config struct {
    Host string `env:"DB_HOST" default:"localhost"`
    Port int    `env:"DB_PORT" default:"5432"`
}

func LoadConfig(cfg interface{}) {
    v := reflect.ValueOf(cfg).Elem()
    t := v.Type()

    for i := 0; i < t.NumField(); i++ {
        field := t.Field(i)
        envKey := field.Tag.Get("env")
        defaultValue := field.Tag.Get("default")

        fmt.Printf("Field: %s, Env: %s, Default: %s\n",
            field.Name, envKey, defaultValue)
    }
}

// Output:
// Field: Host, Env: DB_HOST, Default: localhost
// Field: Port, Env: DB_PORT, Default: 5432
```

## 11. 機密情報のマスキング（Stringer/GoStringer）

機密情報を含む構造体を出力する際、`fmt.Stringer` や `fmt.GoStringer` を実装してマスキングします。

### fmt.Stringer インターフェース

```go
type User struct {
    Username string
    Password string
}

// String()メソッドを実装してパスワードをマスク
func (u User) String() string {
    return fmt.Sprintf("User{Username: %s, Password: ***}", u.Username)
}

user := User{Username: "alice", Password: "secret123"}
fmt.Println(user)
// Output: User{Username: alice, Password: ***}
```

### fmt.GoStringer インターフェース

`%#v` フォーマット（Go構文形式）でもマスキングしたい場合に実装します。

```go
type APIKey struct {
    Key       string
    ExpiresAt time.Time
}

// GoString()メソッドを実装
func (a APIKey) GoString() string {
    return fmt.Sprintf("APIKey{Key: %s..., ExpiresAt: %v}",
        a.Key[:8], a.ExpiresAt)
}

key := APIKey{
    Key:       "sk_live_EXAMPLE_KEY_DO_NOT_USE_xxxxxxxxx",
    ExpiresAt: time.Now().Add(24 * time.Hour),
}

fmt.Printf("%#v\n", key)
// Output: APIKey{Key: sk_live_..., ExpiresAt: 2026-02-11 ...}
```

### 両方を実装する例

```go
type CreditCard struct {
    Number    string
    CVV       string
    ExpiryMM  int
    ExpiryYY  int
}

func (c CreditCard) String() string {
    masked := "****-****-****-" + c.Number[len(c.Number)-4:]
    return fmt.Sprintf("CreditCard{Number: %s, Expiry: %02d/%02d}",
        masked, c.ExpiryMM, c.ExpiryYY)
}

func (c CreditCard) GoString() string {
    return c.String()  // 同じマスキングを適用
}

card := CreditCard{
    Number:   "1234567812345678",
    CVV:      "123",
    ExpiryMM: 12,
    ExpiryYY: 25,
}

fmt.Println(card)      // String()を使用
fmt.Printf("%#v\n", card)  // GoString()を使用
// Output:
// CreditCard{Number: ****-****-****-5678, Expiry: 12/25}
// CreditCard{Number: ****-****-****-5678, Expiry: 12/25}
```

### ログ出力での活用

```go
type Session struct {
    ID        string
    UserID    int
    Token     string
    CreatedAt time.Time
}

func (s Session) String() string {
    return fmt.Sprintf("Session{ID: %s, UserID: %d, Token: [REDACTED]}",
        s.ID, s.UserID)
}

session := Session{
    ID:        "sess_123",
    UserID:    42,
    Token:     "very_secret_token_1234567890",
    CreatedAt: time.Now(),
}

log.Println("Created session:", session)
// Output: Created session: Session{ID: sess_123, UserID: 42, Token: [REDACTED]}
// Tokenは出力されない
```
