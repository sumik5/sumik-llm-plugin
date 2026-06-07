# Creational パターン（生成に関するパターン）

オブジェクトの生成方法を抽象化し、柔軟性・再利用性・保守性を高めるパターン群。

---

## 1. Singleton パターン

### 目的
唯一のインスタンスを保証し、グローバルなアクセスポイントを提供する。

### Go実装

#### スレッドセーフな実装（sync.Once使用）

```go
package singleton

import "sync"

type Singleton struct {
    // フィールド
}

var instance *Singleton
var once sync.Once

// GetInstance はSingletonの唯一のインスタンスを返す
func GetInstance() *Singleton {
    once.Do(func() {
        instance = &Singleton{}
        // 初期化処理
    })
    return instance
}
```

#### init関数による実装

```go
package singleton

type Config struct {
    // 設定フィールド
}

var config *Config

func init() {
    config = &Config{}
    // 初期化処理
}

func GetConfig() *Config {
    return config
}
```

### 使用場面
- データベース接続プール
- アプリケーション設定管理
- ロガー
- キャッシュマネージャー

### 注意点
- グローバル状態を導入するため、テストが困難になる
- 並行処理での状態管理に注意が必要
- 依存関係が暗黙的になる
- **原則として使用は最小限に留める**。代わりにDependency Injectionを検討すること

---

## 2. Factory Method パターン

### 目的
オブジェクト生成の責任をサブタイプに委譲し、生成ロジックをカプセル化する。

### Go実装

```go
package factory

// Product はファクトリが生成するオブジェクトのinterface
type Product interface {
    Use() string
}

// ConcreteProductA は具体的な製品A
type ConcreteProductA struct{}

func (p *ConcreteProductA) Use() string {
    return "ProductA"
}

// ConcreteProductB は具体的な製品B
type ConcreteProductB struct{}

func (p *ConcreteProductB) Use() string {
    return "ProductB"
}

// NewProduct は型に応じて適切なProductを生成する
func NewProduct(productType string) Product {
    switch productType {
    case "A":
        return &ConcreteProductA{}
    case "B":
        return &ConcreteProductB{}
    default:
        return nil
    }
}
```

#### エラーハンドリングを含む実装

```go
func NewProduct(productType string) (Product, error) {
    switch productType {
    case "A":
        return &ConcreteProductA{}, nil
    case "B":
        return &ConcreteProductB{}, nil
    default:
        return nil, fmt.Errorf("unknown product type: %s", productType)
    }
}
```

### 使用場面
- 支払いゲートウェイの選択（PayPal / Stripe / Square）
- データベース接続タイプの切替（MySQL / PostgreSQL / SQLite）
- ロガーの選択（Console / File / Remote）

### 実用例：支払い処理システム

```go
package payment

type PaymentProcessor interface {
    ProcessPayment(amount float64) error
}

type PayPalProcessor struct{}

func (p *PayPalProcessor) ProcessPayment(amount float64) error {
    // PayPal固有の処理
    return nil
}

type StripeProcessor struct{}

func (s *StripeProcessor) ProcessPayment(amount float64) error {
    // Stripe固有の処理
    return nil
}

func NewPaymentProcessor(gateway string) (PaymentProcessor, error) {
    switch gateway {
    case "paypal":
        return &PayPalProcessor{}, nil
    case "stripe":
        return &StripeProcessor{}, nil
    default:
        return nil, fmt.Errorf("unsupported gateway: %s", gateway)
    }
}
```

---

## 3. Abstract Factory パターン

### 目的
関連する、または依存するオブジェクト群を、その具体的なクラスを明示せずに生成する。

### Go実装

```go
package abstractfactory

// Button はボタンのinterface
type Button interface {
    Render() string
}

// Checkbox はチェックボックスのinterface
type Checkbox interface {
    Render() string
}

// GUIFactory はGUIコンポーネント群を生成するinterface
type GUIFactory interface {
    CreateButton() Button
    CreateCheckbox() Checkbox
}

// MacFactory はMac用GUIファクトリ
type MacFactory struct{}

func (f *MacFactory) CreateButton() Button {
    return &MacButton{}
}

func (f *MacFactory) CreateCheckbox() Checkbox {
    return &MacCheckbox{}
}

// WindowsFactory はWindows用GUIファクトリ
type WindowsFactory struct{}

func (f *WindowsFactory) CreateButton() Button {
    return &WindowsButton{}
}

func (f *WindowsFactory) CreateCheckbox() Checkbox {
    return &WindowsCheckbox{}
}

// 具体的な実装
type MacButton struct{}

func (b *MacButton) Render() string {
    return "Mac Button"
}

type MacCheckbox struct{}

func (c *MacCheckbox) Render() string {
    return "Mac Checkbox"
}

type WindowsButton struct{}

func (b *WindowsButton) Render() string {
    return "Windows Button"
}

type WindowsCheckbox struct{}

func (c *WindowsCheckbox) Render() string {
    return "Windows Checkbox"
}

// NewGUIFactory はOS固有のファクトリを返す
func NewGUIFactory(os string) GUIFactory {
    switch os {
    case "mac":
        return &MacFactory{}
    case "windows":
        return &WindowsFactory{}
    default:
        return nil
    }
}
```

### 使用場面
- クロスプラットフォームUIコンポーネント生成
- データベース固有の操作群（トランザクション、クエリビルダー等）
- テーマ別のUI要素セット

### 実用例：データベース抽象化層

```go
package database

type Connection interface {
    Query(sql string) (Result, error)
    Close() error
}

type Transaction interface {
    Begin() error
    Commit() error
    Rollback() error
}

type DatabaseFactory interface {
    CreateConnection(config string) Connection
    CreateTransaction(conn Connection) Transaction
}

type MySQLFactory struct{}

func (f *MySQLFactory) CreateConnection(config string) Connection {
    // MySQL接続生成
    return &MySQLConnection{}
}

func (f *MySQLFactory) CreateTransaction(conn Connection) Transaction {
    // MySQLトランザクション生成
    return &MySQLTransaction{}
}

type PostgreSQLFactory struct{}

func (f *PostgreSQLFactory) CreateConnection(config string) Connection {
    // PostgreSQL接続生成
    return &PostgreSQLConnection{}
}

func (f *PostgreSQLFactory) CreateTransaction(conn Connection) Transaction {
    // PostgreSQLトランザクション生成
    return &PostgreSQLTransaction{}
}
```

---

## 4. Builder パターン

### 目的
複雑なオブジェクトを段階的に構築する。同じ構築プロセスで異なる表現を可能にする。

### Go実装：メソッドチェーン（Fluent Interface）

```go
package builder

type Car struct {
    make   string
    model  string
    color  string
    doors  int
    engine string
}

type CarBuilder struct {
    car *Car
}

func NewCarBuilder() *CarBuilder {
    return &CarBuilder{car: &Car{}}
}

func (b *CarBuilder) Make(make string) *CarBuilder {
    b.car.make = make
    return b
}

func (b *CarBuilder) Model(model string) *CarBuilder {
    b.car.model = model
    return b
}

func (b *CarBuilder) Color(color string) *CarBuilder {
    b.car.color = color
    return b
}

func (b *CarBuilder) Doors(doors int) *CarBuilder {
    b.car.doors = doors
    return b
}

func (b *CarBuilder) Engine(engine string) *CarBuilder {
    b.car.engine = engine
    return b
}

func (b *CarBuilder) Build() *Car {
    return b.car
}

// 使用例
func Example() {
    car := NewCarBuilder().
        Make("Toyota").
        Model("Camry").
        Color("Blue").
        Doors(4).
        Engine("V6").
        Build()
}
```

### Go idiomatic実装：Functional Options パターン

```go
package server

type Server struct {
    host string
    port int
    timeout int
    maxConns int
}

// Option はServerの設定オプション
type Option func(*Server)

// WithHost はホストを設定する
func WithHost(host string) Option {
    return func(s *Server) {
        s.host = host
    }
}

// WithPort はポートを設定する
func WithPort(port int) Option {
    return func(s *Server) {
        s.port = port
    }
}

// WithTimeout はタイムアウトを設定する
func WithTimeout(timeout int) Option {
    return func(s *Server) {
        s.timeout = timeout
    }
}

// WithMaxConns は最大接続数を設定する
func WithMaxConns(maxConns int) Option {
    return func(s *Server) {
        s.maxConns = maxConns
    }
}

// NewServer は新しいServerを生成する
func NewServer(opts ...Option) *Server {
    // デフォルト値
    s := &Server{
        host: "localhost",
        port: 8080,
        timeout: 30,
        maxConns: 100,
    }

    // オプション適用
    for _, opt := range opts {
        opt(s)
    }

    return s
}

// 使用例
func Example() {
    server := NewServer(
        WithHost("0.0.0.0"),
        WithPort(9000),
        WithTimeout(60),
    )
}
```

### 使用場面
- HTTPリクエスト構築
- データベース接続設定
- サーバー設定
- 複雑なクエリビルダー

### ベストプラクティス
- **Goでは Functional Options パターンが idiomatic**
- オプションの順序に依存しない設計
- デフォルト値を明示的に設定
- 必須パラメータはコンストラクタ引数に、オプションパラメータはOption関数に

### 実用例：HTTPクライアント

```go
package httpclient

import (
    "net/http"
    "time"
)

type Client struct {
    httpClient *http.Client
    baseURL    string
    headers    map[string]string
    timeout    time.Duration
}

type Option func(*Client)

func WithBaseURL(url string) Option {
    return func(c *Client) {
        c.baseURL = url
    }
}

func WithHeader(key, value string) Option {
    return func(c *Client) {
        if c.headers == nil {
            c.headers = make(map[string]string)
        }
        c.headers[key] = value
    }
}

func WithTimeout(timeout time.Duration) Option {
    return func(c *Client) {
        c.timeout = timeout
    }
}

func NewClient(opts ...Option) *Client {
    c := &Client{
        httpClient: &http.Client{},
        headers:    make(map[string]string),
        timeout:    30 * time.Second,
    }

    for _, opt := range opts {
        opt(c)
    }

    c.httpClient.Timeout = c.timeout

    return c
}
```

---

## 5. Prototype パターン

### 目的
既存のオブジェクトをコピーして新しいオブジェクトを生成する。

### Go実装

```go
package prototype

type Cloneable interface {
    Clone() Cloneable
}

type Document struct {
    Title    string
    Content  string
    Metadata map[string]string
}

// Clone はDocumentのディープコピーを返す
func (d *Document) Clone() Cloneable {
    // メタデータのディープコピー
    metadata := make(map[string]string)
    for k, v := range d.Metadata {
        metadata[k] = v
    }

    return &Document{
        Title:    d.Title,
        Content:  d.Content,
        Metadata: metadata,
    }
}

// 使用例
func Example() {
    original := &Document{
        Title:   "Original",
        Content: "Content",
        Metadata: map[string]string{
            "author": "John",
        },
    }

    clone := original.Clone().(*Document)
    clone.Title = "Clone"
}
```

### ジェネリクスを使った汎用実装

```go
package prototype

type Cloner[T any] interface {
    Clone() T
}

type User struct {
    ID    int
    Name  string
    Email string
}

func (u *User) Clone() *User {
    return &User{
        ID:    u.ID,
        Name:  u.Name,
        Email: u.Email,
    }
}
```

### 使用場面
- テンプレートからの文書生成
- ゲームオブジェクトのスポーン
- 設定オブジェクトの複製
- プロトタイプベースの設計

### 注意点

#### Deep Copy vs Shallow Copy

```go
// Shallow Copy（参照のコピー）
func (d *Document) ShallowClone() *Document {
    return &Document{
        Title:    d.Title,
        Content:  d.Content,
        Metadata: d.Metadata, // 同じmapを参照
    }
}

// Deep Copy（値のコピー）
func (d *Document) DeepClone() *Document {
    metadata := make(map[string]string)
    for k, v := range d.Metadata {
        metadata[k] = v
    }

    return &Document{
        Title:    d.Title,
        Content:  d.Content,
        Metadata: metadata, // 新しいmap
    }
}
```

- **Shallow Copy**: ポインタ・スライス・マップは同じ参照を共有
- **Deep Copy**: すべてのフィールドを再帰的にコピー
- 状況に応じて適切な方法を選択する

---

## 6. Dependency Injection

### 目的
依存関係を外部から注入することで、テスト容易性を向上させ、疎結合な設計を実現する。

### Go実装：コンストラクタインジェクション

```go
package service

// Service はビジネスロジックのinterface
type Service interface {
    DoSomething() error
}

// Repository はデータアクセスのinterface
type Repository interface {
    Save(data string) error
    Load() (string, error)
}

// Client はServiceとRepositoryに依存する
type Client struct {
    service    Service
    repository Repository
}

// NewClient は新しいClientを生成する（必須依存をコンストラクタで注入）
func NewClient(service Service, repository Repository) *Client {
    return &Client{
        service:    service,
        repository: repository,
    }
}

func (c *Client) Execute() error {
    if err := c.service.DoSomething(); err != nil {
        return err
    }

    return c.repository.Save("result")
}
```

### メソッドインジェクション（オプション依存）

```go
type Logger interface {
    Log(message string)
}

type Client struct {
    service Service
    logger  Logger // オプション依存
}

func NewClient(service Service) *Client {
    return &Client{
        service: service,
    }
}

// SetLogger はロガーを設定する（オプション）
func (c *Client) SetLogger(logger Logger) {
    c.logger = logger
}

func (c *Client) Execute() error {
    if c.logger != nil {
        c.logger.Log("Executing...")
    }

    return c.service.DoSomething()
}
```

### 使用場面
- **全てのサービス層で推奨**
- テストでモックを注入
- 環境ごとに異なる実装を切替
- プラグイン機構の実装

### ベストプラクティス

#### interfaceで依存を定義

```go
// 悪い例：具体型に依存
type Client struct {
    db *sql.DB
}

// 良い例：interfaceに依存
type Database interface {
    Query(sql string) (Result, error)
}

type Client struct {
    db Database
}
```

#### 必須依存はコンストラクタ、オプション依存はメソッド

```go
// 必須依存
func NewClient(service Service, repo Repository) *Client {
    return &Client{
        service: service,
        repo:    repo,
    }
}

// オプション依存
func (c *Client) SetLogger(logger Logger) {
    c.logger = logger
}
```

#### テストでのモック注入

```go
package service_test

import "testing"

type MockService struct {
    DoSomethingFunc func() error
}

func (m *MockService) DoSomething() error {
    return m.DoSomethingFunc()
}

func TestClient_Execute(t *testing.T) {
    mockService := &MockService{
        DoSomethingFunc: func() error {
            return nil
        },
    }

    client := NewClient(mockService, &MockRepository{})

    if err := client.Execute(); err != nil {
        t.Errorf("expected no error, got %v", err)
    }
}
```

### DIコンテナ

大規模アプリケーションでは依存関係グラフが複雑になる。以下のDIコンテナライブラリを検討：

- **google/wire**: コンパイル時の依存解決（推奨）
- **uber-go/fx**: ランタイムの依存解決
- **uber-go/dig**: リフレクションベースの依存解決

#### google/wire 例

```go
//go:build wireinject
// +build wireinject

package main

import "github.com/google/wire"

func InitializeClient() (*Client, error) {
    wire.Build(
        NewService,
        NewRepository,
        NewClient,
    )
    return nil, nil
}
```

---

## パターン選択の判断基準

| 状況 | 推奨パターン |
|------|------------|
| グローバルに1インスタンスのみ必要 | Singleton（sync.Once使用） |
| 型名や設定による生成分岐 | Factory Method |
| 関連するオブジェクト群を一緒に生成 | Abstract Factory |
| 多数のオプションを持つオブジェクト | Builder（Functional Options推奨） |
| 既存オブジェクトのコピーが必要 | Prototype |
| テスト容易性・疎結合が必要 | Dependency Injection |

---

## 実装時の注意点

### 1. Goらしいパターン使用
- Functional Options はGo idiomaticな Builder パターン
- interfaceは小さく保つ（1-3メソッド）
- エラーハンドリングを忘れない

### 2. 過度な抽象化を避ける
- 必要になってから抽象化する（YAGNI原則）
- シンプルな問題にパターンを強制しない

### 3. テスタビリティ優先
- Dependency Injectionを基本とする
- Singletonは最小限に
- interfaceでモック可能に

### 4. パフォーマンス考慮
- Prototypeパターンではdeep copyのコストに注意
- Singletonの初期化タイミングを考慮
- Factory Methodでの型判定オーバーヘッド

### 5. ドキュメント化
- なぜそのパターンを選択したかをコメントに記載
- 使用例を提供
- 制約や注意点を明記

---

## Genericsを活用したBuilder拡張

Go 1.18以降、Genericsを利用することでBuilderパターンの型安全性と再利用性を向上できる。

### Generic Builder interface

```go
package builder

// Builder は任意の型Tを構築するビルダーの共通インターフェース
type Builder[T any] interface {
    Build() T
}
```

### GenericBuilderによるStep-by-step construction

action関数のスライスで構築ステップを保持し、Build時に順次適用する。

```go
package builder

// GenericBuilder はaction関数を蓄積してオブジェクトを構築
type GenericBuilder[T any] struct {
    actions []func(*T)
}

func NewGenericBuilder[T any]() *GenericBuilder[T] {
    return &GenericBuilder[T]{
        actions: make([]func(*T), 0),
    }
}

func (b *GenericBuilder[T]) AddAction(action func(*T)) *GenericBuilder[T] {
    b.actions = append(b.actions, action)
    return b
}

func (b *GenericBuilder[T]) Build() T {
    var result T
    for _, action := range b.actions {
        action(&result)
    }
    return result
}
```

### Method Chainingパターン

具体的なドメインBuilderがGenericBuilderを埋め込み、ドメイン固有のメソッドチェーンを提供する。

```go
package builder

type User struct {
    Name  string
    Email string
    Age   int
}

// UserBuilder はGenericBuilderを埋め込み、User固有のメソッドを提供
type UserBuilder struct {
    *GenericBuilder[User]
}

func NewUserBuilder() *UserBuilder {
    return &UserBuilder{
        GenericBuilder: NewGenericBuilder[User](),
    }
}

func (b *UserBuilder) Name(name string) *UserBuilder {
    b.AddAction(func(u *User) {
        u.Name = name
    })
    return b
}

func (b *UserBuilder) Email(email string) *UserBuilder {
    b.AddAction(func(u *User) {
        u.Email = email
    })
    return b
}

func (b *UserBuilder) Age(age int) *UserBuilder {
    b.AddAction(func(u *User) {
        u.Age = age
    })
    return b
}

// 使用例
func Example() {
    user := NewUserBuilder().
        Name("Alice").
        Email("alice@example.com").
        Age(30).
        Build()

    // user.Name == "Alice", user.Email == "alice@example.com", user.Age == 30
}
```

### Optional[T]型を活用した省略可能フィールド

```go
package builder

// Optional は値の存在/不在を表現する
type Optional[T any] struct {
    value T
    set   bool
}

func Some[T any](value T) Optional[T] {
    return Optional[T]{value: value, set: true}
}

func None[T any]() Optional[T] {
    return Optional[T]{set: false}
}

func (o Optional[T]) Get() (T, bool) {
    return o.value, o.set
}

// OptionalFieldsを持つ構造体
type Config struct {
    Host    string
    Port    Optional[int]
    Timeout Optional[int]
}

type ConfigBuilder struct {
    *GenericBuilder[Config]
}

func NewConfigBuilder() *ConfigBuilder {
    return &ConfigBuilder{
        GenericBuilder: NewGenericBuilder[Config](),
    }
}

func (b *ConfigBuilder) Host(host string) *ConfigBuilder {
    b.AddAction(func(c *Config) {
        c.Host = host
    })
    return b
}

func (b *ConfigBuilder) Port(port int) *ConfigBuilder {
    b.AddAction(func(c *Config) {
        c.Port = Some(port)
    })
    return b
}

func (b *ConfigBuilder) Timeout(timeout int) *ConfigBuilder {
    b.AddAction(func(c *Config) {
        c.Timeout = Some(timeout)
    })
    return b
}

// Build時にOptionalフィールドをチェック
func (b *ConfigBuilder) Build() Config {
    cfg := b.GenericBuilder.Build()

    // デフォルト値設定
    if port, ok := cfg.Port.Get(); !ok {
        cfg.Port = Some(8080)
    } else {
        cfg.Port = Some(port)
    }

    if timeout, ok := cfg.Timeout.Get(); !ok {
        cfg.Timeout = Some(30)
    } else {
        cfg.Timeout = Some(timeout)
    }

    return cfg
}

// 使用例
func ExampleOptional() {
    // Portのみ指定、Timeoutはデフォルト
    cfg := NewConfigBuilder().
        Host("localhost").
        Port(9000).
        Build()

    // cfg.Port == Some(9000), cfg.Timeout == Some(30)
}
```

### 使い分けの判断基準

| アプローチ | 使用場面 | メリット |
|-----------|---------|---------|
| Functional Options | 関数オプションが3-5個程度、標準的な設定 | Goイディオム、デフォルト値が明確 |
| Generic Builder | 複雑な構築ロジック、ステップ順序が重要 | 型安全、再利用可能、ステップの柔軟な組み合わせ |
| 直接構築 | 必須パラメータのみ、単純な構造 | 最もシンプル、オーバーヘッドなし |

**推奨**:
- **単純なケース**: Functional Options（Goコミュニティ標準）
- **複雑な構築フロー**: Generic Builder（ステップ管理が重要）
- **再利用性重視**: Generic Builder（複数ドメインで共通基盤）
