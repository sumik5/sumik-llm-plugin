# Goデザインパターンのテスト戦略

デザインパターンのテストは、設計の正しさを保証し、リファクタリング時の安全ネットとなる。本ドキュメントでは、Goにおける各パターンの効果的なテスト手法を解説する。

---

## パターンテストの重要性

### 設計の保証
- デザインパターンは正しく実装されてこそ価値がある
- テストによりパターンの契約（contract）が守られていることを保証
- パターンの意図通りの振舞いを継続的に検証

### リファクタリングの安全性
- テストがあることで安心して構造を改善できる
- パターンの本質を保ったまま最適化が可能
- 退行バグの早期発見

### ドキュメントとしての役割
- テストコードはパターンの使用例となる
- 期待される振舞いを明示的に示す
- チームメンバーへの学習教材

---

## 生成パターンのテスト

### Singleton テスト

#### 基本的な同一性検証
```go
func TestSingleton_ReturnsSameInstance(t *testing.T) {
    instance1 := GetInstance()
    instance2 := GetInstance()

    if instance1 != instance2 {
        t.Error("expected same instance")
    }
}
```

#### スレッドセーフティの検証
```go
func TestSingleton_ThreadSafe(t *testing.T) {
    var wg sync.WaitGroup
    instances := make([]*Singleton, 100)

    for i := 0; i < 100; i++ {
        wg.Add(1)
        go func(idx int) {
            defer wg.Done()
            instances[idx] = GetInstance()
        }(i)
    }
    wg.Wait()

    for _, inst := range instances {
        if inst != instances[0] {
            t.Error("concurrent access returned different instances")
        }
    }
}
```

#### 状態の共有検証
```go
func TestSingleton_SharedState(t *testing.T) {
    instance1 := GetInstance()
    instance1.SetValue(42)

    instance2 := GetInstance()
    if instance2.GetValue() != 42 {
        t.Error("state not shared across instances")
    }
}
```

### Factory Method テスト

#### 正しい型の生成検証
```go
func TestFactory_CreatesCorrectProduct(t *testing.T) {
    tests := []struct {
        name     string
        typ      string
        expected string
    }{
        {"PayPal", "paypal", "PayPal"},
        {"Stripe", "stripe", "Stripe"},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            product := NewPaymentGateway(tt.typ)
            if product == nil {
                t.Fatalf("expected non-nil product for type %s", tt.typ)
            }
            if product.Name() != tt.expected {
                t.Errorf("expected %s, got %s", tt.expected, product.Name())
            }
        })
    }
}
```

#### 不正な型の処理
```go
func TestFactory_HandlesInvalidType(t *testing.T) {
    product := NewPaymentGateway("invalid")
    if product != nil {
        t.Error("expected nil for invalid type")
    }
}
```

#### Interface契約の検証
```go
func TestFactory_ProductImplementsInterface(t *testing.T) {
    product := NewPaymentGateway("paypal")

    // interfaceを満たすことを検証
    var _ PaymentGateway = product

    // 必須メソッドの動作確認
    err := product.ProcessPayment(100.0)
    if err != nil {
        t.Errorf("expected valid payment processing: %v", err)
    }
}
```

### Builder テスト

#### 段階的構築の検証
```go
func TestBuilder_ConstructsObject(t *testing.T) {
    car := NewCarBuilder().
        Make("Toyota").
        Model("Camry").
        Seats(5).
        Build()

    if car.Make != "Toyota" {
        t.Errorf("expected Make=Toyota, got %s", car.Make)
    }
    if car.Model != "Camry" {
        t.Errorf("expected Model=Camry, got %s", car.Model)
    }
    if car.Seats != 5 {
        t.Errorf("expected Seats=5, got %d", car.Seats)
    }
}
```

#### デフォルト値の検証
```go
func TestBuilder_DefaultValues(t *testing.T) {
    car := NewCarBuilder().
        Make("Toyota").
        Build()

    // デフォルト値が適用されていることを確認
    if car.Seats != 4 {
        t.Errorf("expected default Seats=4, got %d", car.Seats)
    }
}
```

#### バリデーションの検証
```go
func TestBuilder_ValidatesInput(t *testing.T) {
    car := NewCarBuilder().
        Make("Toyota").
        Seats(-1).
        Build()

    // 不正な値が修正されているか、エラーが返るべき
    if car.Seats < 0 {
        t.Error("builder should validate seat count")
    }
}
```

### Abstract Factory テスト

#### ファミリー製品の整合性
```go
func TestAbstractFactory_ProducesConsistentFamily(t *testing.T) {
    factory := NewUIFactory("windows")
    button := factory.CreateButton()
    checkbox := factory.CreateCheckbox()

    if button.Style() != checkbox.Style() {
        t.Error("products from same factory should have consistent style")
    }
}
```

### Prototype テスト

#### クローンの独立性検証
```go
func TestPrototype_CloneIsIndependent(t *testing.T) {
    original := &Document{Title: "Original"}
    clone := original.Clone()

    clone.Title = "Clone"

    if original.Title == clone.Title {
        t.Error("clone should be independent of original")
    }
}
```

#### ディープコピーの検証
```go
func TestPrototype_DeepCopy(t *testing.T) {
    original := &Document{
        Title: "Original",
        Tags:  []string{"tag1", "tag2"},
    }
    clone := original.Clone()

    clone.Tags[0] = "modified"

    if original.Tags[0] == "modified" {
        t.Error("clone should perform deep copy")
    }
}
```

---

## 構造パターンのテスト

### Decorator テスト

#### ベースコンポーネントの呼び出し検証
```go
type mockComponent struct {
    called bool
    output string
}

func (m *mockComponent) Operation() string {
    m.called = true
    return m.output
}

func TestDecorator_CallsBaseComponent(t *testing.T) {
    mock := &mockComponent{output: "base"}
    decorator := &LoggingDecorator{component: mock}

    result := decorator.Operation()

    if !mock.called {
        t.Error("expected base component to be called")
    }
    if !strings.Contains(result, "base") {
        t.Error("expected result to contain base component output")
    }
}
```

#### 複数デコレータの連鎖検証
```go
func TestDecorator_ChainMultipleDecorators(t *testing.T) {
    base := &ConcreteComponent{}
    decorated := &LoggingDecorator{
        component: &CachingDecorator{
            component: base,
        },
    }

    result := decorated.Operation()

    // 各デコレータの効果が適用されていることを確認
    if !strings.Contains(result, "logged") {
        t.Error("logging decorator not applied")
    }
    if !strings.Contains(result, "cached") {
        t.Error("caching decorator not applied")
    }
}
```

### Adapter テスト

#### インターフェース変換の検証
```go
func TestAdapter_TranslatesInterface(t *testing.T) {
    adaptee := &LegacyAPI{}
    adapter := &APIAdapter{legacy: adaptee}

    // adapter は新しいinterfaceを満たすべき
    var target ModernAPI = adapter
    result := target.NewMethod()

    if result == "" {
        t.Error("adapter should translate legacy API call")
    }
}
```

#### 双方向アダプターのテスト
```go
func TestAdapter_Bidirectional(t *testing.T) {
    legacy := &LegacySystem{}
    modern := &ModernSystem{}

    adapter := &BidirectionalAdapter{
        legacy: legacy,
        modern: modern,
    }

    // 両方向の変換が機能することを確認
    adapter.CallLegacy("test")
    adapter.CallModern("test")

    if !legacy.called || !modern.called {
        t.Error("bidirectional adapter should call both systems")
    }
}
```

### Composite テスト

#### 再帰的な操作の検証
```go
func TestComposite_RecursiveOperation(t *testing.T) {
    root := &Composite{}
    child1 := &Leaf{value: 10}
    child2 := &Composite{}
    grandchild := &Leaf{value: 20}

    root.Add(child1)
    root.Add(child2)
    child2.Add(grandchild)

    total := root.Calculate()
    expected := 30

    if total != expected {
        t.Errorf("expected %d, got %d", expected, total)
    }
}
```

### Proxy テスト

#### 遅延初期化の検証
```go
func TestProxy_LazyInitialization(t *testing.T) {
    proxy := &LazyProxy{}

    // 最初のアクセスで初期化
    result1 := proxy.Operation()
    initCount1 := proxy.initializationCount

    // 2回目は初期化しない
    result2 := proxy.Operation()
    initCount2 := proxy.initializationCount

    if initCount1 != 1 || initCount2 != 1 {
        t.Error("proxy should initialize only once")
    }
}
```

#### アクセス制御の検証
```go
func TestProxy_AccessControl(t *testing.T) {
    proxy := &ProtectionProxy{allowedUsers: []string{"admin"}}

    // 許可されたユーザー
    err := proxy.Operation("admin")
    if err != nil {
        t.Error("expected access for allowed user")
    }

    // 許可されていないユーザー
    err = proxy.Operation("guest")
    if err == nil {
        t.Error("expected access denial for unauthorized user")
    }
}
```

### Facade テスト

#### 複雑なサブシステムの隠蔽検証
```go
func TestFacade_SimplifiesSubsystems(t *testing.T) {
    facade := NewOrderFacade()

    // 単純なインターフェースで複雑な処理を実行
    err := facade.PlaceOrder("user-1", "item-1", 1)
    if err != nil {
        t.Fatalf("expected successful order: %v", err)
    }

    // 内部的に複数のサブシステムが連携していることを確認
    // （モックやスパイを使って検証）
}
```

---

## 振舞いパターンのテスト

### Observer テスト

#### 通知の配信検証
```go
func TestObserver_NotifiesAllObservers(t *testing.T) {
    subject := &ConcreteSubject{}
    observer1 := &MockObserver{}
    observer2 := &MockObserver{}

    subject.Register(observer1)
    subject.Register(observer2)
    subject.SetState("new state")

    if observer1.lastUpdate != "new state" {
        t.Error("observer1 was not notified")
    }
    if observer2.lastUpdate != "new state" {
        t.Error("observer2 was not notified")
    }
}
```

#### 登録解除の検証
```go
func TestObserver_UnregisterStopsNotification(t *testing.T) {
    subject := &ConcreteSubject{}
    observer := &MockObserver{}

    subject.Register(observer)
    subject.Unregister(observer)
    subject.SetState("changed")

    if observer.lastUpdate == "changed" {
        t.Error("unregistered observer should not receive updates")
    }
}
```

#### 並行通知のテスト
```go
func TestObserver_ConcurrentNotifications(t *testing.T) {
    subject := &ConcreteSubject{}
    var wg sync.WaitGroup

    for i := 0; i < 100; i++ {
        observer := &MockObserver{}
        subject.Register(observer)
        wg.Add(1)
        go func() {
            defer wg.Done()
            subject.SetState("concurrent")
        }()
    }

    wg.Wait()
    // データレースやデッドロックが発生しないことを確認
}
```

### Strategy テスト

#### アルゴリズム切り替えの検証
```go
func TestStrategy_SwitchesAlgorithm(t *testing.T) {
    ctx := &Context{}

    ctx.SetStrategy(&BubbleSort{})
    result1 := ctx.ExecuteStrategy([]int{3, 1, 2})

    ctx.SetStrategy(&QuickSort{})
    result2 := ctx.ExecuteStrategy([]int{3, 1, 2})

    expected := []int{1, 2, 3}
    if !reflect.DeepEqual(result1, expected) {
        t.Error("BubbleSort strategy failed")
    }
    if !reflect.DeepEqual(result2, expected) {
        t.Error("QuickSort strategy failed")
    }
}
```

#### ランタイム戦略変更の検証
```go
func TestStrategy_RuntimeSwitch(t *testing.T) {
    ctx := &PaymentContext{}

    // 通常支払い
    ctx.SetStrategy(&CreditCardStrategy{})
    err := ctx.Pay(100.0)
    if err != nil {
        t.Error("credit card payment failed")
    }

    // 戦略を切り替え
    ctx.SetStrategy(&PayPalStrategy{})
    err = ctx.Pay(100.0)
    if err != nil {
        t.Error("PayPal payment failed")
    }
}
```

### State テスト

#### 状態遷移の検証
```go
func TestState_TransitionsCorrectly(t *testing.T) {
    game := &Game{currentState: &PlayingState{}}

    game.HandleInput("pause")
    if _, ok := game.currentState.(*PausedState); !ok {
        t.Error("expected transition to PausedState")
    }

    game.HandleInput("resume")
    if _, ok := game.currentState.(*PlayingState); !ok {
        t.Error("expected transition back to PlayingState")
    }
}
```

#### 無効な遷移の防止
```go
func TestState_RejectsInvalidTransition(t *testing.T) {
    game := &Game{currentState: &PlayingState{}}

    err := game.HandleInput("game-over")
    // GameOverStateへは特定条件下でしか遷移できない
    if err == nil {
        t.Error("expected error for invalid transition")
    }
}
```

### Command テスト

#### コマンド実行と取り消しの検証
```go
func TestCommand_ExecuteAndUndo(t *testing.T) {
    receiver := &TextEditor{content: ""}
    cmd := &InsertCommand{
        receiver: receiver,
        text:     "Hello",
    }

    cmd.Execute()
    if receiver.content != "Hello" {
        t.Error("command execution failed")
    }

    cmd.Undo()
    if receiver.content != "" {
        t.Error("command undo failed")
    }
}
```

#### マクロコマンドのテスト
```go
func TestCommand_MacroExecution(t *testing.T) {
    editor := &TextEditor{}
    macro := &MacroCommand{
        commands: []Command{
            &InsertCommand{receiver: editor, text: "Hello"},
            &InsertCommand{receiver: editor, text: " World"},
        },
    }

    macro.Execute()
    if editor.content != "Hello World" {
        t.Error("macro command failed")
    }

    macro.Undo()
    if editor.content != "" {
        t.Error("macro undo failed")
    }
}
```

### Chain of Responsibility テスト

#### リクエスト処理の連鎖検証
```go
func TestChain_ProcessesRequest(t *testing.T) {
    handler1 := &ConcreteHandler{level: 1}
    handler2 := &ConcreteHandler{level: 2}
    handler1.SetNext(handler2)

    // handler2が処理すべきリクエスト
    result := handler1.Handle(&Request{priority: 2})
    if !result {
        t.Error("request should be handled by handler2")
    }
}
```

#### 処理不能なリクエストの検証
```go
func TestChain_UnhandledRequest(t *testing.T) {
    handler := &ConcreteHandler{level: 1}

    result := handler.Handle(&Request{priority: 99})
    if result {
        t.Error("request with priority 99 should not be handled")
    }
}
```

### Template Method テスト

#### 共通アルゴリズムの検証
```go
func TestTemplateMethod_ExecutesSteps(t *testing.T) {
    template := &ConcreteAlgorithm{}

    result := template.Execute()

    // 各ステップが正しい順序で実行されたことを確認
    expected := "step1-step2-step3"
    if result != expected {
        t.Errorf("expected %s, got %s", expected, result)
    }
}
```

#### カスタマイズ可能なフックの検証
```go
func TestTemplateMethod_OptionalHook(t *testing.T) {
    template := &ConcreteAlgorithm{useHook: true}

    result := template.Execute()

    if !strings.Contains(result, "hook") {
        t.Error("optional hook was not executed")
    }
}
```

### Iterator テスト

#### コレクション走査の検証
```go
func TestIterator_TraversesCollection(t *testing.T) {
    collection := &ConcreteCollection{items: []int{1, 2, 3}}
    iterator := collection.CreateIterator()

    var result []int
    for iterator.HasNext() {
        result = append(result, iterator.Next().(int))
    }

    if !reflect.DeepEqual(result, []int{1, 2, 3}) {
        t.Error("iterator did not traverse collection correctly")
    }
}
```

---

## 統合テスト

### パターンの組み合わせテスト

#### Factory + Strategy
```go
func TestIntegration_FactoryAndStrategy(t *testing.T) {
    // Factoryで戦略を生成
    strategy := NewSortStrategy("quicksort")

    ctx := &SortContext{}
    ctx.SetStrategy(strategy)

    result := ctx.Sort([]int{3, 1, 2})
    expected := []int{1, 2, 3}

    if !reflect.DeepEqual(result, expected) {
        t.Error("factory + strategy integration failed")
    }
}
```

#### Observer + Command
```go
func TestIntegration_ObserverAndCommand(t *testing.T) {
    // Commandの実行をObserverに通知
    commandManager := &CommandManager{}
    logger := &LogObserver{}
    commandManager.Register(logger)

    cmd := &InsertCommand{text: "test"}
    commandManager.ExecuteCommand(cmd)

    if logger.lastLog == "" {
        t.Error("observer should be notified of command execution")
    }
}
```

### エンドツーエンドのフロー検証
```go
func TestOrderFlow_Integration(t *testing.T) {
    // Factory で支払いゲートウェイを生成
    gateway := NewPaymentGateway("stripe")

    // DI でサービスを構築
    inventory := NewInventoryService()
    service := NewOrderService(gateway, inventory)

    // 注文処理のフルフロー
    err := service.PlaceOrder("item-1", 100.0)
    if err != nil {
        t.Fatalf("order flow failed: %v", err)
    }

    // 在庫が減っていることを確認
    stock := inventory.GetStock("item-1")
    if stock != 99 {
        t.Errorf("expected stock=99, got %d", stock)
    }
}
```

---

## パフォーマンステスト

### Singleton のベンチマーク
```go
func BenchmarkSingleton_GetInstance(b *testing.B) {
    for i := 0; i < b.N; i++ {
        GetInstance()
    }
}

func BenchmarkSingleton_Concurrent(b *testing.B) {
    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            GetInstance()
        }
    })
}
```

### Object Pool のベンチマーク
```go
func BenchmarkObjectPool_GetPut(b *testing.B) {
    pool := NewObjectPool(100)

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        obj := pool.Get()
        pool.Put(obj)
    }
}

func BenchmarkObjectPool_Concurrent(b *testing.B) {
    pool := NewObjectPool(100)

    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            obj := pool.Get()
            pool.Put(obj)
        }
    })
}
```

### Worker Pool のベンチマーク
```go
func BenchmarkWorkerPool(b *testing.B) {
    jobs := make(chan int, b.N)
    results := make(chan int, b.N)

    pool := NewWorkerPool(runtime.NumCPU(), jobs, results)
    pool.Start()

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        jobs <- i
    }
    close(jobs)

    for i := 0; i < b.N; i++ {
        <-results
    }
}
```

### メモリアロケーションの測定
```go
func BenchmarkBuilder_Allocation(b *testing.B) {
    b.ReportAllocs()
    for i := 0; i < b.N; i++ {
        _ = NewCarBuilder().
            Make("Toyota").
            Model("Camry").
            Build()
    }
}
```

---

## TDD（テスト駆動開発）とパターン

### Red-Green-Refactor サイクル

#### Red: 失敗するテストを書く
```go
func TestPaymentGateway_ProcessPayment(t *testing.T) {
    gateway := NewPaymentGateway("stripe")
    err := gateway.ProcessPayment(100.0)
    if err != nil {
        t.Errorf("expected successful payment: %v", err)
    }
}
```

#### Green: 最小限の実装でテスト通過
```go
type StripeGateway struct{}

func (s *StripeGateway) ProcessPayment(amount float64) error {
    // 最小限の実装
    return nil
}
```

#### Refactor: パターンに沿って構造を改善
```go
// Factory Pattern を導入
type PaymentGateway interface {
    ProcessPayment(amount float64) error
}

func NewPaymentGateway(typ string) PaymentGateway {
    switch typ {
    case "stripe":
        return &StripeGateway{}
    case "paypal":
        return &PayPalGateway{}
    default:
        return nil
    }
}
```

### TDDとパターンの相性

| パターン | TDD アプローチ |
|---------|--------------|
| **Strategy** | テストで各戦略の出力を検証してから実装 |
| **Factory** | テストで期待する型を検証してからFactory実装 |
| **Observer** | テストで通知の受信を検証してから通知機構実装 |
| **Decorator** | テストでラップされた振舞いを検証してから実装 |
| **State** | テストで状態遷移を検証してから実装 |

### TDD実践例: Strategy Pattern

```go
// 1. Red: テストを先に書く
func TestSortStrategy_QuickSort(t *testing.T) {
    strategy := &QuickSortStrategy{}
    result := strategy.Sort([]int{3, 1, 2})
    expected := []int{1, 2, 3}
    if !reflect.DeepEqual(result, expected) {
        t.Error("QuickSort failed")
    }
}

// 2. Green: 最小実装
type QuickSortStrategy struct{}

func (q *QuickSortStrategy) Sort(data []int) []int {
    sort.Ints(data)
    return data
}

// 3. Refactor: Strategyパターンで構造化
type SortStrategy interface {
    Sort([]int) []int
}

type SortContext struct {
    strategy SortStrategy
}

func (c *SortContext) SetStrategy(s SortStrategy) {
    c.strategy = s
}

func (c *SortContext) Sort(data []int) []int {
    return c.strategy.Sort(data)
}
```

---

## テストツールとライブラリ

### 標準パッケージ

| ツール | 用途 |
|--------|------|
| `testing` | ユニットテスト・ベンチマーク |
| `testing/quick` | プロパティベーステスト |
| `net/http/httptest` | HTTPハンドラテスト |

### サードパーティライブラリ

| ツール | 用途 |
|--------|------|
| `testify/assert` | アサーションヘルパー |
| `testify/mock` | モック生成 |
| `testify/suite` | テストスイート |
| `gomock` | interfaceモック自動生成 |
| `ginkgo` | BDDスタイルテスト |
| `go-cmp` | 詳細な差分比較 |

### テスト実行オプション

```bash
# 通常実行
go test ./...

# データレース検出
go test -race ./...

# カバレッジ測定
go test -cover ./...
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# ベンチマーク
go test -bench=. ./...
go test -bench=. -benchmem ./...

# 詳細出力
go test -v ./...

# 並列実行
go test -parallel 4 ./...
```

---

## テスト設計のベストプラクティス

### テーブル駆動テスト
```go
func TestPaymentGateway(t *testing.T) {
    tests := []struct {
        name    string
        typ     string
        amount  float64
        wantErr bool
    }{
        {"Stripe success", "stripe", 100.0, false},
        {"PayPal success", "paypal", 50.0, false},
        {"Invalid type", "invalid", 100.0, true},
        {"Negative amount", "stripe", -10.0, true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            gateway := NewPaymentGateway(tt.typ)
            err := gateway.ProcessPayment(tt.amount)

            if (err != nil) != tt.wantErr {
                t.Errorf("wantErr=%v, got err=%v", tt.wantErr, err)
            }
        })
    }
}
```

### AAAパターン（Arrange-Act-Assert）
```go
func TestOrderService_PlaceOrder(t *testing.T) {
    // Arrange: テストの準備
    gateway := NewMockPaymentGateway()
    inventory := NewMockInventory()
    service := NewOrderService(gateway, inventory)

    // Act: テスト対象の実行
    err := service.PlaceOrder("item-1", 100.0)

    // Assert: 結果の検証
    if err != nil {
        t.Errorf("expected success, got error: %v", err)
    }
    if !gateway.Called {
        t.Error("payment gateway should be called")
    }
}
```

### interfaceでモック
```go
// テスト可能な設計
type PaymentGateway interface {
    ProcessPayment(float64) error
}

type OrderService struct {
    gateway PaymentGateway // 具体型ではなくinterfaceに依存
}

// モック実装
type MockPaymentGateway struct {
    Called bool
    Err    error
}

func (m *MockPaymentGateway) ProcessPayment(amount float64) error {
    m.Called = true
    return m.Err
}

// テスト
func TestOrderService_UsesGateway(t *testing.T) {
    mock := &MockPaymentGateway{}
    service := &OrderService{gateway: mock}

    service.PlaceOrder("item-1", 100.0)

    if !mock.Called {
        t.Error("gateway should be called")
    }
}
```

### サブテストの活用
```go
func TestStateMachine(t *testing.T) {
    t.Run("transitions", func(t *testing.T) {
        t.Run("playing to paused", func(t *testing.T) {
            // サブテストで関連テストをグループ化
        })

        t.Run("paused to playing", func(t *testing.T) {
            // 独立して実行可能
        })
    })

    t.Run("invalid transitions", func(t *testing.T) {
        // エラーケースを別グループに
    })
}
```

### テストヘルパーの使用
```go
func setupTestEnvironment(t *testing.T) (*OrderService, *MockGateway) {
    t.Helper() // エラー発生時に正しい行番号を報告

    gateway := &MockGateway{}
    service := NewOrderService(gateway)
    return service, gateway
}

func TestOrderService(t *testing.T) {
    service, gateway := setupTestEnvironment(t)
    // テストコードがシンプルになる
}
```

### テストの独立性確保
```go
// 悪い例: グローバル状態に依存
var globalCache = make(map[string]string)

func TestCache_Bad(t *testing.T) {
    globalCache["key"] = "value" // 他のテストに影響
}

// 良い例: 独立したインスタンスを使用
func TestCache_Good(t *testing.T) {
    cache := NewCache() // 各テストで新規作成
    cache.Set("key", "value")
}
```

### エラーメッセージの明確化
```go
func TestPayment(t *testing.T) {
    gateway := NewPaymentGateway("stripe")
    err := gateway.ProcessPayment(100.0)

    // 悪い例
    if err != nil {
        t.Error("error")
    }

    // 良い例
    if err != nil {
        t.Errorf("ProcessPayment(100.0) failed: %v", err)
    }
}
```

---

## まとめ

### テスト戦略の選択

| パターン種別 | 重点テスト項目 |
|------------|--------------|
| **生成パターン** | 正しい型の生成、スレッドセーフティ |
| **構造パターン** | Interface契約、委譲の正しさ |
| **振舞いパターン** | アルゴリズムの切り替え、状態遷移 |

### テストの優先順位

1. **ユニットテスト**: 各パターンの基本的な振舞い
2. **統合テスト**: パターンの組み合わせ動作
3. **パフォーマンステスト**: ボトルネック特定
4. **並行性テスト**: データレース・デッドロック検出

### 継続的な改善

- テストカバレッジの監視（目標: 80%以上）
- データレース検出の自動化（`-race` フラグ）
- ベンチマークの定期実行
- テストの保守性向上（リファクタリング）
