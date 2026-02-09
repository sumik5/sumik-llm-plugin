# クリーンな関数設計

Go言語における関数設計・命名・リファクタリングのベストプラクティス。

---

## 1. 単一責任関数（Single Responsibility Functions）

### 原則
関数は**一つのことだけを行う**べきである。関数の機能を「〜と〜をする」（and）で説明する必要があれば、分割すべきサインである。

### Before/After リファクタリング例

#### ❌ Dirty: 一つの関数が全部やる
```go
func processOrder(order Order) error {
    // 検証
    if order.Total <= 0 {
        return errors.New("invalid order total")
    }
    if len(order.Items) == 0 {
        return errors.New("order must have at least one item")
    }

    // 税計算
    taxRate := 0.08
    order.Tax = order.Total * taxRate

    // 在庫更新
    for _, item := range order.Items {
        if err := db.UpdateInventory(item.ProductID, -item.Quantity); err != nil {
            return fmt.Errorf("inventory update failed: %w", err)
        }
    }

    // DB保存
    if err := db.SaveOrder(order); err != nil {
        return fmt.Errorf("save order failed: %w", err)
    }

    // メール送信
    emailBody := fmt.Sprintf("Your order #%d has been confirmed", order.ID)
    if err := emailService.Send(order.CustomerEmail, "Order Confirmation", emailBody); err != nil {
        return fmt.Errorf("email send failed: %w", err)
    }

    return nil
}
```

**問題点:**
- 5つの異なる責任が混在（検証・税計算・在庫・DB・メール）
- テストが困難（全機能をモックする必要がある）
- 変更の影響範囲が広い（税率変更で全体をテストし直す）

#### ✅ Clean: 各関数が単一責任
```go
func validateOrder(order Order) error {
    if order.Total <= 0 {
        return errors.New("invalid order total")
    }
    if len(order.Items) == 0 {
        return errors.New("order must have at least one item")
    }
    return nil
}

func calculateTax(total float64) float64 {
    const taxRate = 0.08
    return total * taxRate
}

func updateInventoryForOrder(order Order) error {
    for _, item := range order.Items {
        if err := db.UpdateInventory(item.ProductID, -item.Quantity); err != nil {
            return fmt.Errorf("inventory update failed for product %d: %w", item.ProductID, err)
        }
    }
    return nil
}

func saveOrderToDB(order Order) error {
    if err := db.SaveOrder(order); err != nil {
        return fmt.Errorf("save order failed: %w", err)
    }
    return nil
}

func sendConfirmationEmail(order Order) error {
    emailBody := fmt.Sprintf("Your order #%d has been confirmed", order.ID)
    if err := emailService.Send(order.CustomerEmail, "Order Confirmation", emailBody); err != nil {
        return fmt.Errorf("email send failed: %w", err)
    }
    return nil
}

func processOrder(order Order) error {
    if err := validateOrder(order); err != nil {
        return err
    }

    order.Tax = calculateTax(order.Total)

    if err := updateInventoryForOrder(order); err != nil {
        return err
    }

    if err := saveOrderToDB(order); err != nil {
        return err
    }

    return sendConfirmationEmail(order)
}
```

**改善点:**
- 各関数が単一責任を持つ
- 個別にテスト可能
- 再利用可能（`calculateTax`は他でも使える）
- `processOrder`がオーケストレーションに専念

---

## 2. 関数の長さと引数（Function Length and Arguments）

### 原則
- **関数の長さ**: 20-30行以内を目安（画面1スクロールで見渡せる）
- **引数の数**: 3つ以下を推奨。超過する場合は構造体にグループ化

### Before/After例: 引数の削減

#### ❌ 引数が多すぎる
```go
func createUser(name, email, password string, age int, isAdmin bool, department string, phoneNumber string) error {
    // 7つの引数を管理するのは困難
    // 呼び出し時に順序を間違えやすい
    user := User{
        Name:        name,
        Email:       email,
        Password:    password,
        Age:         age,
        IsAdmin:     isAdmin,
        Department:  department,
        PhoneNumber: phoneNumber,
    }
    return db.Save(user)
}

// 呼び出し例 - 順序を覚えるのが大変
createUser("Alice", "alice@example.com", "pass123", 30, false, "Engineering", "123-456-7890")
```

#### ✅ 構造体にグループ化
```go
type UserCreationParams struct {
    Name        string
    Email       string
    Password    string
    Age         int
    IsAdmin     bool
    Department  string
    PhoneNumber string
}

func createUser(params UserCreationParams) error {
    user := User{
        Name:        params.Name,
        Email:       params.Email,
        Password:    params.Password,
        Age:         params.Age,
        IsAdmin:     params.IsAdmin,
        Department:  params.Department,
        PhoneNumber: params.PhoneNumber,
    }
    return db.Save(user)
}

// 呼び出し例 - 名前付きで明確
createUser(UserCreationParams{
    Name:        "Alice",
    Email:       "alice@example.com",
    Password:    "pass123",
    Age:         30,
    IsAdmin:     false,
    Department:  "Engineering",
    PhoneNumber: "123-456-7890",
})
```

**改善点:**
- フィールドが名前付きで自己文書化
- 順序の間違いがない
- 将来的にフィールド追加が容易
- オプショナルな引数を表現可能（ゼロ値で判定）

### 関数の長さの例

#### ❌ 長すぎる関数
```go
func generateReport(userID int) (string, error) {
    // 100行以上の処理...
    // データ取得
    // フィルタリング
    // 集計
    // フォーマット
    // ファイル書き込み
    // ...
}
```

#### ✅ 適切に分割
```go
func generateReport(userID int) (string, error) {
    data, err := fetchUserData(userID)
    if err != nil {
        return "", err
    }

    filtered := filterRelevantData(data)
    aggregated := aggregateData(filtered)
    formatted := formatReport(aggregated)

    return formatted, nil
}

func fetchUserData(userID int) ([]DataPoint, error) { /* 10-20行 */ }
func filterRelevantData(data []DataPoint) []DataPoint { /* 10-20行 */ }
func aggregateData(data []DataPoint) ReportData { /* 10-20行 */ }
func formatReport(data ReportData) string { /* 10-20行 */ }
```

---

## 3. 記述的な関数名（Descriptive Function Names）

### 原則
- **動詞・動詞句を使う**: `validate`, `process`, `fetch`, `calculate`
- **メソッドのコンテキスト冗長を避ける**: `User.ValidateUser()` → `User.Validate()`
- **bool返却は質問形式**: `isValid`, `hasPermission`, `contains`
- **変換関数はInput→Output明示**: `stringToInt`, `userToJSON`

### 判断基準テーブル
| パターン | ❌ Bad | ✅ Good | 理由 |
|---------|--------|---------|------|
| 略称 | `func c(n int) bool` | `func isPrime(number int) bool` | 意図が明確 |
| 冗長 | `User.ValidateUser()` | `User.Validate()` | レシーバがコンテキスト提供 |
| 汎用名 | `func process(data []byte)` | `func processPayment(data []byte)` | 具体的な処理内容を示す |
| bool | `func check(email string) bool` | `func isValidEmail(email string) bool` | 質問形式で読みやすい |
| 変換 | `func convert(s string) int` | `func stringToInt(s string) int` | 変換内容が明確 |

### Before/After例

#### ❌ 不明瞭な命名
```go
func c(n int) bool {
    // 何をチェックしているのか不明
    for i := 2; i < n; i++ {
        if n%i == 0 {
            return false
        }
    }
    return true
}

func process(data []byte) error {
    // 何を処理しているのか不明
    // ...
}

type User struct {
    Email string
}

func (u User) ValidateUser() bool {
    // "User"が冗長（レシーバで自明）
    return strings.Contains(u.Email, "@")
}
```

#### ✅ 明確な命名
```go
func isPrime(number int) bool {
    if number < 2 {
        return false
    }
    for i := 2; i < number; i++ {
        if number%i == 0 {
            return false
        }
    }
    return true
}

func processPayment(transactionData []byte) error {
    // 支払い処理であることが明確
    // ...
}

type User struct {
    Email string
}

func (u User) Validate() bool {
    // レシーバがUserなので冗長性なし
    return strings.Contains(u.Email, "@")
}

func (u User) IsAdmin() bool {
    // bool返却で質問形式
    return u.Role == "admin"
}

func userToJSON(u User) ([]byte, error) {
    // User → JSON の変換が明確
    return json.Marshal(u)
}
```

---

## 4. 純粋関数と副作用（Pure Functions and Side Effects）

### 原則
- **純粋関数**: 同じ入力→同じ出力、外部状態を変更しない
- **副作用の分離**: ビジネスロジック（純粋）とI/O操作（副作用）を分ける
- **インターフェースで依存を抽象化**: テスタビリティ確保

### 純粋関数の例
```go
// ✅ 純粋関数（テスト容易）
func calculateNewBalance(currentBalance, transaction float64) float64 {
    return currentBalance + transaction
}

func applyDiscount(price, discountRate float64) float64 {
    return price * (1 - discountRate)
}

func filterActiveUsers(users []User) []User {
    active := make([]User, 0)
    for _, u := range users {
        if u.IsActive {
            active = append(active, u)
        }
    }
    return active
}
```

### 副作用の分離

#### ❌ 副作用とビジネスロジックが混在
```go
func processTransaction(userID int, amount float64) error {
    // DBから取得（副作用）
    currentBalance, err := db.GetBalance(userID)
    if err != nil {
        return err
    }

    // ビジネスロジック
    newBalance := currentBalance + amount

    // DB更新（副作用）
    if err := db.UpdateBalance(userID, newBalance); err != nil {
        return err
    }

    // ログ出力（副作用）
    log.Printf("Updated balance for user %d: %f", userID, newBalance)
    return nil
}
```

**問題点:**
- ビジネスロジックのテストにDBモックが必須
- DB接続エラーとビジネスロジックエラーが混在

#### ✅ 副作用を分離
```go
// 純粋関数: ビジネスロジックのみ
func calculateNewBalance(currentBalance, transaction float64) float64 {
    return currentBalance + transaction
}

// 副作用を含む関数: I/O操作のみ
type BalanceRepository interface {
    GetBalance(userID int) (float64, error)
    UpdateBalance(userID int, balance float64) error
}

func processTransaction(repo BalanceRepository, userID int, amount float64) error {
    currentBalance, err := repo.GetBalance(userID)
    if err != nil {
        return fmt.Errorf("failed to get balance: %w", err)
    }

    newBalance := calculateNewBalance(currentBalance, amount)

    if err := repo.UpdateBalance(userID, newBalance); err != nil {
        return fmt.Errorf("failed to update balance: %w", err)
    }

    log.Printf("Updated balance for user %d: %f", userID, newBalance)
    return nil
}
```

**改善点:**
- `calculateNewBalance`は純粋関数（ユニットテストが容易）
- `BalanceRepository`インターフェースでDB依存を抽象化
- テスト時はモック実装で`processTransaction`も検証可能

---

## 5. クリーンな戻り値とエラー（Clean Return Values and Errors）

### 原則
- **結果+エラーの多値返却パターン**: `(result, error)` が標準
- **マジックバリューを避ける**: `-1`や`nil`でエラーを表現しない
- **名前付き戻り値**: 複雑な関数でのみ使用
- **エラーコンテキスト**: `fmt.Errorf("...: %w", err)` でラップ

### Before/After例

#### ❌ マジックバリュー
```go
func divide(a, b float64) float64 {
    if b == 0 {
        return -1 // エラーを-1で表現（曖昧）
    }
    return a / b
}

func findUserIndex(users []User, id int) int {
    for i, u := range users {
        if u.ID == id {
            return i
        }
    }
    return -1 // 見つからない場合を-1で表現
}

// 呼び出し側で曖昧な判定
result := divide(10, 0)
if result == -1 {
    // -1がエラーなのか正当な計算結果なのか不明
}
```

#### ✅ 明示的なエラー
```go
func divide(a, b float64) (float64, error) {
    if b == 0 {
        return 0, errors.New("division by zero")
    }
    return a / b, nil
}

func findUserIndex(users []User, id int) (int, error) {
    for i, u := range users {
        if u.ID == id {
            return i, nil
        }
    }
    return 0, fmt.Errorf("user with ID %d not found", id)
}

// 呼び出し側で明確な判定
result, err := divide(10, 0)
if err != nil {
    log.Printf("Division failed: %v", err)
    return
}
```

### エラーコンテキストの追加

#### ❌ コンテキストなしのエラー
```go
func loadUserConfig(userID int) (*Config, error) {
    data, err := fetchFromDB(userID)
    if err != nil {
        return nil, err // どこで失敗したか不明
    }

    config, err := parseConfig(data)
    if err != nil {
        return nil, err // 同様に不明
    }

    return config, nil
}
```

#### ✅ コンテキスト付きエラー
```go
func loadUserConfig(userID int) (*Config, error) {
    data, err := fetchFromDB(userID)
    if err != nil {
        return nil, fmt.Errorf("failed to fetch config for user %d: %w", userID, err)
    }

    config, err := parseConfig(data)
    if err != nil {
        return nil, fmt.Errorf("failed to parse config for user %d: %w", userID, err)
    }

    return config, nil
}

// エラーメッセージ例:
// "failed to parse config for user 123: invalid JSON syntax: unexpected EOF"
```

### 名前付き戻り値の使用例

#### ✅ 適切な使用（複雑な制御フロー）
```go
func processFile(path string) (data []byte, lines int, err error) {
    f, err := os.Open(path)
    if err != nil {
        return // data=nil, lines=0, err=err が返る
    }
    defer f.Close()

    data, err = io.ReadAll(f)
    if err != nil {
        return // 明示的な代入不要
    }

    lines = bytes.Count(data, []byte("\n"))
    return // 全ての名前付き戻り値が返る
}
```

#### ⚠️ 過度な使用を避ける（シンプルな場合）
```go
// 不要に複雑
func add(a, b int) (result int) {
    result = a + b
    return
}

// シンプルで良い
func add(a, b int) int {
    return a + b
}
```

---

## 6. 可読性の改善パターン集

### 早期リターン（ガード節）

#### ❌ ネストしたif-else
```go
func DoSomething(x int) (int, error) {
    if x < 0 {
        return 0, errors.New("x must be non-negative")
    } else {
        y := x * 2
        if y > 100 {
            return 100, nil
        } else {
            return y, nil
        }
    }
}

func processOrder(order Order) error {
    if order.IsValid() {
        if order.HasStock() {
            if order.PaymentAuthorized() {
                // 深いネスト...
                return nil
            } else {
                return errors.New("payment not authorized")
            }
        } else {
            return errors.New("insufficient stock")
        }
    } else {
        return errors.New("invalid order")
    }
}
```

#### ✅ 早期リターン
```go
func DoSomething(x int) (int, error) {
    if x < 0 {
        return 0, errors.New("x must be non-negative")
    }

    y := x * 2
    if y > 100 {
        return 100, nil
    }

    return y, nil
}

func processOrder(order Order) error {
    if !order.IsValid() {
        return errors.New("invalid order")
    }

    if !order.HasStock() {
        return errors.New("insufficient stock")
    }

    if !order.PaymentAuthorized() {
        return errors.New("payment not authorized")
    }

    // 正常系のロジックがフラットに
    return saveOrder(order)
}
```

**改善点:**
- ネストが浅くなり読みやすい
- エラーケースが先に処理される
- 正常系のロジックが明確

### ヘルパー関数の抽出

#### ❌ 重複したロジック
```go
func validateUserInput(input UserInput) error {
    if len(input.Name) == 0 || len(input.Name) > 100 {
        return errors.New("invalid name length")
    }

    if len(input.Email) == 0 || len(input.Email) > 255 {
        return errors.New("invalid email length")
    }

    if len(input.Password) < 8 || len(input.Password) > 128 {
        return errors.New("invalid password length")
    }

    return nil
}
```

#### ✅ ヘルパー関数で共通化
```go
func validateStringLength(value, fieldName string, min, max int) error {
    length := len(value)
    if length < min || length > max {
        return fmt.Errorf("%s must be between %d and %d characters", fieldName, min, max)
    }
    return nil
}

func validateUserInput(input UserInput) error {
    if err := validateStringLength(input.Name, "name", 1, 100); err != nil {
        return err
    }

    if err := validateStringLength(input.Email, "email", 1, 255); err != nil {
        return err
    }

    if err := validateStringLength(input.Password, "password", 8, 128); err != nil {
        return err
    }

    return nil
}
```

### 一貫性のある命名

#### ❌ 不統一な命名
```go
func fetchUser(id int) (*User, error) { /* ... */ }
func getUserData(id int) (*User, error) { /* ... */ }  // fetchとgetが混在
func retrieveUserInfo(id int) (*User, error) { /* ... */ }  // さらに別の動詞

func isValid(email string) bool { /* ... */ }
func checkPassword(pass string) bool { /* ... */ }  // isとcheckが混在
```

#### ✅ 統一された命名
```go
// "fetch"で統一
func fetchUser(id int) (*User, error) { /* ... */ }
func fetchUserOrders(userID int) ([]Order, error) { /* ... */ }
func fetchUserProfile(userID int) (*Profile, error) { /* ... */ }

// bool返却は"is/has/can"で統一
func isValidEmail(email string) bool { /* ... */ }
func isValidPassword(pass string) bool { /* ... */ }
func hasPermission(user User, resource string) bool { /* ... */ }
```

### 意図を表現する中間変数

#### ❌ 意図が不明瞭
```go
func calculatePrice(quantity int, unitPrice float64) float64 {
    return quantity * unitPrice * 1.08 * 0.9
}

func isEligibleForDiscount(user User) bool {
    return user.Age > 65 || user.MembershipYears > 5
}
```

#### ✅ 中間変数で意図を明確化
```go
func calculatePrice(quantity int, unitPrice float64) float64 {
    subtotal := float64(quantity) * unitPrice
    withTax := subtotal * 1.08
    withDiscount := withTax * 0.9
    return withDiscount
}

func isEligibleForDiscount(user User) bool {
    isSenior := user.Age > 65
    isLongTermMember := user.MembershipYears > 5
    return isSenior || isLongTermMember
}
```

---

## まとめ

クリーンな関数設計の核心は以下の通り:

1. **単一責任**: 関数は一つのことだけを行う
2. **適切なサイズ**: 20-30行以内、引数は3つ以下
3. **記述的な命名**: 意図が明確な動詞・動詞句
4. **純粋性の追求**: 副作用を分離してテスタビリティ確保
5. **明示的なエラー処理**: マジックバリュー禁止
6. **可読性の優先**: 早期リターン、ヘルパー関数、一貫性

これらの原則を適用することで、保守性・テスト容易性・拡張性の高いGoコードを実現できる。
