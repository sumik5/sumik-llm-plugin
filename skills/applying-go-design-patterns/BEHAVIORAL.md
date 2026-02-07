# Behavioral Patterns (振舞いパターン)

オブジェクト間の責任分担とアルゴリズムのカプセル化を扱うパターン群。

---

## 1. Chain of Responsibility (責任の連鎖)

### 目的
リクエストを処理者チェーンに沿って渡し、適切な処理者が処理するまで連鎖させる。送信者と受信者を疎結合に保つ。

### Go実装

```go
package main

import "fmt"

// Handler は処理者のインターフェース
type Handler interface {
    SetNext(handler Handler)
    Handle(request float64) string
}

// BaseHandler は共通処理を提供
type BaseHandler struct {
    next Handler
}

func (b *BaseHandler) SetNext(h Handler) {
    b.next = h
}

func (b *BaseHandler) HandleNext(request float64) string {
    if b.next != nil {
        return b.next.Handle(request)
    }
    return "処理できません"
}

// ManagerHandler は10万円以下の承認権限
type ManagerHandler struct {
    BaseHandler
}

func (m *ManagerHandler) Handle(request float64) string {
    if request <= 100000 {
        return fmt.Sprintf("マネージャーが承認: %.0f円", request)
    }
    return m.HandleNext(request)
}

// DirectorHandler は50万円以下の承認権限
type DirectorHandler struct {
    BaseHandler
}

func (d *DirectorHandler) Handle(request float64) string {
    if request <= 500000 {
        return fmt.Sprintf("ディレクターが承認: %.0f円", request)
    }
    return d.HandleNext(request)
}

// CEOHandler は全額承認権限
type CEOHandler struct {
    BaseHandler
}

func (c *CEOHandler) Handle(request float64) string {
    return fmt.Sprintf("CEOが承認: %.0f円", request)
}

// 使用例
func main() {
    manager := &ManagerHandler{}
    director := &DirectorHandler{}
    ceo := &CEOHandler{}

    manager.SetNext(director)
    director.SetNext(ceo)

    requests := []float64{5000, 150000, 600000}
    for _, req := range requests {
        fmt.Println(manager.Handle(req))
    }
}
```

### 使用場面
- 承認ワークフロー（金額に応じて承認者が変わる）
- HTTPミドルウェアチェーン（認証→ロギング→処理）
- イベント処理システム（複数のハンドラが順次処理を試みる）
- バリデーションチェーンの構築

### Goイディオム
HTTPミドルウェアは標準的な実装パターン:

```go
type Middleware func(http.Handler) http.Handler

func Logging(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        log.Println("Request:", r.URL.Path)
        next.ServeHTTP(w, r)
    })
}

func Authentication(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if r.Header.Get("Authorization") == "" {
            http.Error(w, "Unauthorized", http.StatusUnauthorized)
            return
        }
        next.ServeHTTP(w, r)
    })
}

// チェーン構築
handler := Logging(Authentication(http.HandlerFunc(myHandler)))
```

---

## 2. Command (コマンド)

### 目的
リクエストをオブジェクトとしてカプセル化し、操作の履歴管理・取り消し・再実行を可能にする。

### Go実装

```go
package main

import "fmt"

// Command はコマンドのインターフェース
type Command interface {
    Execute()
    Undo()
}

// Device は操作対象
type Device struct {
    name string
    on   bool
}

func (d *Device) TurnOn() {
    d.on = true
    fmt.Printf("%s をオンにしました\n", d.name)
}

func (d *Device) TurnOff() {
    d.on = false
    fmt.Printf("%s をオフにしました\n", d.name)
}

// TurnOnCommand はデバイスをオンにするコマンド
type TurnOnCommand struct {
    device *Device
}

func (c *TurnOnCommand) Execute() {
    c.device.TurnOn()
}

func (c *TurnOnCommand) Undo() {
    c.device.TurnOff()
}

// TurnOffCommand はデバイスをオフにするコマンド
type TurnOffCommand struct {
    device *Device
}

func (c *TurnOffCommand) Execute() {
    c.device.TurnOff()
}

func (c *TurnOffCommand) Undo() {
    c.device.TurnOn()
}

// RemoteControl はコマンドの実行者
type RemoteControl struct {
    history []Command
}

func (r *RemoteControl) Execute(cmd Command) {
    cmd.Execute()
    r.history = append(r.history, cmd)
}

func (r *RemoteControl) Undo() {
    if len(r.history) == 0 {
        return
    }
    last := r.history[len(r.history)-1]
    last.Undo()
    r.history = r.history[:len(r.history)-1]
}

// 使用例
func main() {
    tv := &Device{name: "テレビ"}
    light := &Device{name: "照明"}

    remote := &RemoteControl{}

    remote.Execute(&TurnOnCommand{device: tv})
    remote.Execute(&TurnOnCommand{device: light})
    remote.Execute(&TurnOffCommand{device: tv})

    fmt.Println("\n--- Undo ---")
    remote.Undo()
    remote.Undo()
}
```

### 使用場面
- Undo/Redo機能の実装
- トランザクション処理
- タスクキュー・ジョブスケジューラー
- マクロ記録・再生機能
- 操作ログの保存

### Goイディオム
シンプルなケースでは `func()` で十分:

```go
type Task struct {
    execute func()
    undo    func()
}

func NewTask(exec, undo func()) *Task {
    return &Task{execute: exec, undo: undo}
}

func (t *Task) Execute() { t.execute() }
func (t *Task) Undo()    { t.undo() }

// 使用例
task := NewTask(
    func() { fmt.Println("実行") },
    func() { fmt.Println("取消") },
)
task.Execute()
task.Undo()
```

---

## 3. Iterator (イテレータ)

### 目的
コレクションの内部構造を公開せず、要素に順次アクセスする統一的な方法を提供する。

### Go実装

#### channel-based iterator (Go idiomatic)

```go
package main

import "fmt"

// Collection は要素のコレクション
type Collection struct {
    items []string
}

// Iterator はchannelベースのイテレータを返す
func (c *Collection) Iterator() <-chan string {
    ch := make(chan string)
    go func() {
        defer close(ch)
        for _, item := range c.items {
            ch <- item
        }
    }()
    return ch
}

// 使用例
func main() {
    collection := &Collection{
        items: []string{"Apple", "Banana", "Cherry"},
    }

    for item := range collection.Iterator() {
        fmt.Println(item)
    }
}
```

#### Generics iterator (Go 1.18+)

```go
package main

import "fmt"

// Iterator はジェネリクスを使ったイテレータ
type Iterator[T any] interface {
    HasNext() bool
    Next() T
}

// SliceIterator はスライスのイテレータ
type SliceIterator[T any] struct {
    items []T
    index int
}

func NewSliceIterator[T any](items []T) *SliceIterator[T] {
    return &SliceIterator[T]{items: items, index: 0}
}

func (s *SliceIterator[T]) HasNext() bool {
    return s.index < len(s.items)
}

func (s *SliceIterator[T]) Next() T {
    item := s.items[s.index]
    s.index++
    return item
}

// 使用例
func main() {
    iter := NewSliceIterator([]int{1, 2, 3, 4, 5})

    for iter.HasNext() {
        fmt.Println(iter.Next())
    }
}
```

### 使用場面
- データベース結果セットの走査
- ページネーション処理
- 大規模データセットのストリーミング処理
- カスタムコレクションの実装

### Goイディオム
- **channelベースが最もGo的**: goroutineと相性が良い
- **range構文が使える**: `for item := range collection.Iterator()`
- 標準ライブラリの `bufio.Scanner` もIteratorパターン

```go
scanner := bufio.NewScanner(file)
for scanner.Scan() {
    fmt.Println(scanner.Text())
}
```

---

## 4. Mediator (仲介者)

### 目的
オブジェクト間の直接通信を避け、仲介者オブジェクトを介して通信させることで疎結合を実現する。

### Go実装

```go
package main

import "fmt"

// Mediator は仲介者のインターフェース
type Mediator interface {
    Notify(sender Component, event string)
}

// Component は各コンポーネントの基底
type Component struct {
    mediator Mediator
}

func (c *Component) SetMediator(m Mediator) {
    c.mediator = m
}

// Button はボタンコンポーネント
type Button struct {
    Component
}

func (b *Button) Click() {
    fmt.Println("ボタンがクリックされました")
    b.mediator.Notify(b, "click")
}

// TextBox はテキストボックスコンポーネント
type TextBox struct {
    Component
    text string
}

func (t *TextBox) SetText(text string) {
    t.text = text
    fmt.Printf("テキスト設定: %s\n", text)
    t.mediator.Notify(t, "textChanged")
}

func (t *TextBox) GetText() string {
    return t.text
}

// Checkbox はチェックボックスコンポーネント
type Checkbox struct {
    Component
    checked bool
}

func (c *Checkbox) Check() {
    c.checked = true
    fmt.Println("チェックボックスがチェックされました")
    c.mediator.Notify(c, "check")
}

func (c *Checkbox) Uncheck() {
    c.checked = false
    fmt.Println("チェックボックスのチェックが外れました")
    c.mediator.Notify(c, "uncheck")
}

// DialogMediator は具体的な仲介者
type DialogMediator struct {
    button   *Button
    textBox  *TextBox
    checkbox *Checkbox
}

func NewDialogMediator() *DialogMediator {
    return &DialogMediator{}
}

func (d *DialogMediator) RegisterComponents(b *Button, t *TextBox, c *Checkbox) {
    d.button = b
    d.textBox = t
    d.checkbox = c

    b.SetMediator(d)
    t.SetMediator(d)
    c.SetMediator(d)
}

func (d *DialogMediator) Notify(sender Component, event string) {
    switch event {
    case "click":
        fmt.Println("→ 仲介者: ボタンクリックを検知、テキストを処理")
        if d.checkbox.checked {
            fmt.Printf("→ 処理結果: %s\n", d.textBox.GetText())
        }
    case "check":
        fmt.Println("→ 仲介者: チェックボックスON、送信ボタンを有効化")
    case "uncheck":
        fmt.Println("→ 仲介者: チェックボックスOFF、送信ボタンを無効化")
    }
}

// 使用例
func main() {
    mediator := NewDialogMediator()

    button := &Button{}
    textBox := &TextBox{}
    checkbox := &Checkbox{}

    mediator.RegisterComponents(button, textBox, checkbox)

    textBox.SetText("Hello, Mediator!")
    checkbox.Check()
    button.Click()
}
```

### 使用場面
- チャットルームの実装（ユーザー同士の直接通信を仲介）
- UIコンポーネント間の協調動作
- 複雑な状態管理が必要なフォーム
- 航空管制システム（飛行機同士の直接通信を管制塔が仲介）

### Goイディオム
channelベースの実装がGo的:

```go
type EventBus struct {
    subscribers map[string][]chan Event
    mu          sync.RWMutex
}

func (e *EventBus) Subscribe(eventType string) <-chan Event {
    e.mu.Lock()
    defer e.mu.Unlock()

    ch := make(chan Event, 10)
    e.subscribers[eventType] = append(e.subscribers[eventType], ch)
    return ch
}

func (e *EventBus) Publish(event Event) {
    e.mu.RLock()
    defer e.mu.RUnlock()

    for _, ch := range e.subscribers[event.Type] {
        go func(c chan Event) { c <- event }(ch)
    }
}
```

---

## 5. Memento (メメント)

### 目的
オブジェクトの状態を保存し、後で復元できるようにする。カプセル化を破らずにスナップショットを作成。

### Go実装

```go
package main

import "fmt"

// Memento は状態のスナップショット
type Memento struct {
    state string
}

// Originator は状態を持つオブジェクト
type Originator struct {
    state string
}

func (o *Originator) SetState(state string) {
    fmt.Printf("状態設定: %s\n", state)
    o.state = state
}

func (o *Originator) GetState() string {
    return o.state
}

// Save はメメントを作成
func (o *Originator) Save() *Memento {
    return &Memento{state: o.state}
}

// Restore はメメントから復元
func (o *Originator) Restore(m *Memento) {
    o.state = m.state
    fmt.Printf("状態復元: %s\n", o.state)
}

// Caretaker は履歴を管理
type Caretaker struct {
    mementos []*Memento
}

func (c *Caretaker) Save(m *Memento) {
    c.mementos = append(c.mementos, m)
}

func (c *Caretaker) Restore(index int) *Memento {
    if index < 0 || index >= len(c.mementos) {
        return nil
    }
    return c.mementos[index]
}

func (c *Caretaker) History() []string {
    var history []string
    for _, m := range c.mementos {
        history = append(history, m.state)
    }
    return history
}

// 使用例
func main() {
    originator := &Originator{}
    caretaker := &Caretaker{}

    originator.SetState("State 1")
    caretaker.Save(originator.Save())

    originator.SetState("State 2")
    caretaker.Save(originator.Save())

    originator.SetState("State 3")
    fmt.Printf("現在の状態: %s\n", originator.GetState())

    fmt.Println("\n--- Undo ---")
    originator.Restore(caretaker.Restore(1))
    fmt.Printf("現在の状態: %s\n", originator.GetState())

    fmt.Println("\n--- 履歴 ---")
    fmt.Println(caretaker.History())
}
```

### 使用場面
- テキストエディタのUndo/Redo機能
- ゲームのセーブポイント・チェックポイント
- トランザクション処理のロールバック
- 設定変更の取り消し機能
- データベースのスナップショット

### Goイディオム
構造体のコピーを利用した簡易実装:

```go
type Editor struct {
    content string
    cursor  int
}

// DeepCopy で状態を保存
func (e *Editor) Snapshot() Editor {
    return *e // 値コピー
}

func (e *Editor) Restore(snapshot Editor) {
    *e = snapshot
}

// 使用例
editor := &Editor{content: "Hello", cursor: 5}
snapshot := editor.Snapshot()

editor.content = "World"
editor.Restore(snapshot) // "Hello" に戻る
```

---

## 6. Observer (オブザーバー)

### 目的
オブジェクトの状態変化を複数の監視者に自動通知する。1対多の依存関係を定義。

### Go実装

#### interface-based (標準的)

```go
package main

import "fmt"

// Observer は監視者のインターフェース
type Observer interface {
    Update(data string)
}

// Subject は監視対象
type Subject struct {
    observers []Observer
    state     string
}

func (s *Subject) Register(o Observer) {
    s.observers = append(s.observers, o)
}

func (s *Subject) Unregister(o Observer) {
    for i, obs := range s.observers {
        if obs == o {
            s.observers = append(s.observers[:i], s.observers[i+1:]...)
            break
        }
    }
}

func (s *Subject) SetState(state string) {
    s.state = state
    s.Notify()
}

func (s *Subject) Notify() {
    for _, obs := range s.observers {
        obs.Update(s.state)
    }
}

// ConcreteObserver は具体的な監視者
type ConcreteObserver struct {
    name string
}

func (c *ConcreteObserver) Update(data string) {
    fmt.Printf("%s が通知を受信: %s\n", c.name, data)
}

// 使用例
func main() {
    subject := &Subject{}

    obs1 := &ConcreteObserver{name: "Observer1"}
    obs2 := &ConcreteObserver{name: "Observer2"}

    subject.Register(obs1)
    subject.Register(obs2)

    subject.SetState("新しい状態")
}
```

#### channel-based (Go idiomatic)

```go
package main

import (
    "fmt"
    "sync"
)

// Subject はchannelベースの監視対象
type Subject struct {
    observers []chan string
    mu        sync.RWMutex
}

func NewSubject() *Subject {
    return &Subject{
        observers: make([]chan string, 0),
    }
}

func (s *Subject) Register() <-chan string {
    s.mu.Lock()
    defer s.mu.Unlock()

    ch := make(chan string, 10)
    s.observers = append(s.observers, ch)
    return ch
}

func (s *Subject) Notify(data string) {
    s.mu.RLock()
    defer s.mu.RUnlock()

    for _, ch := range s.observers {
        go func(c chan string) {
            c <- data
        }(ch)
    }
}

// 使用例
func main() {
    subject := NewSubject()

    ch1 := subject.Register()
    ch2 := subject.Register()

    go func() {
        for msg := range ch1 {
            fmt.Printf("Observer1: %s\n", msg)
        }
    }()

    go func() {
        for msg := range ch2 {
            fmt.Printf("Observer2: %s\n", msg)
        }
    }()

    subject.Notify("イベント1")
    subject.Notify("イベント2")

    // goroutineの終了を待つ
    select {}
}
```

### 使用場面
- イベント駆動アーキテクチャ
- 気象データの配信（複数の観測者が同じデータを受信）
- ログ収集システム
- リアルタイム通知システム
- MVC/MVVMパターンのモデル→ビュー通知

### Goイディオム
**channelベースが最もGo的**:
- goroutineとの親和性が高い
- バッファリングで非同期処理が簡単
- `select` 文で複数のイベントソースを扱える

```go
// 複数のイベントソースを監視
select {
case msg := <-channel1:
    // 処理1
case msg := <-channel2:
    // 処理2
case <-time.After(time.Second):
    // タイムアウト
}
```

---

## 7. State (ステート)

### 目的
オブジェクトの内部状態に応じて振舞いを変更する。状態ごとの処理を別クラスに分離。

### Go実装

```go
package main

import "fmt"

// State は状態のインターフェース
type State interface {
    Handle(ctx *Context)
    String() string
}

// Context は状態を保持するコンテキスト
type Context struct {
    state State
}

func NewContext() *Context {
    return &Context{state: &PlayingState{}}
}

func (c *Context) SetState(s State) {
    fmt.Printf("状態遷移: %s\n", s)
    c.state = s
}

func (c *Context) Request() {
    c.state.Handle(c)
}

// PlayingState はプレイ中状態
type PlayingState struct{}

func (p *PlayingState) Handle(ctx *Context) {
    fmt.Println("ゲームをプレイ中...")
    fmt.Println("→ 一時停止します")
    ctx.SetState(&PausedState{})
}

func (p *PlayingState) String() string {
    return "Playing"
}

// PausedState は一時停止状態
type PausedState struct{}

func (p *PausedState) Handle(ctx *Context) {
    fmt.Println("ゲームが一時停止中...")
    fmt.Println("→ 再開します")
    ctx.SetState(&PlayingState{})
}

func (p *PausedState) String() string {
    return "Paused"
}

// GameOverState はゲームオーバー状態
type GameOverState struct{}

func (g *GameOverState) Handle(ctx *Context) {
    fmt.Println("ゲームオーバー")
    fmt.Println("→ リスタート")
    ctx.SetState(&PlayingState{})
}

func (g *GameOverState) String() string {
    return "GameOver"
}

// 使用例
func main() {
    ctx := NewContext()

    ctx.Request() // Playing → Paused
    ctx.Request() // Paused → Playing

    ctx.SetState(&GameOverState{})
    ctx.Request() // GameOver → Playing
}
```

### 使用場面
- ゲーム状態管理（Playing/Paused/GameOver）
- 注文処理フロー（注文受付→支払い→発送→完了）
- TCP接続状態（Listen/SynReceived/Established/FinWait）
- ワークフロー管理システム
- ドキュメントの承認フロー

### Goイディオム
シンプルなケースでは `map[State]func()` で実装可能:

```go
type State int

const (
    Playing State = iota
    Paused
    GameOver
)

type Game struct {
    state    State
    handlers map[State]func()
}

func NewGame() *Game {
    g := &Game{state: Playing, handlers: make(map[State]func())}

    g.handlers[Playing] = func() {
        fmt.Println("Playing...")
        g.state = Paused
    }
    g.handlers[Paused] = func() {
        fmt.Println("Paused...")
        g.state = Playing
    }

    return g
}

func (g *Game) Handle() {
    if handler, ok := g.handlers[g.state]; ok {
        handler()
    }
}
```

---

## 8. Strategy (ストラテジー)

### 目的
アルゴリズムをカプセル化し、実行時に動的に切り替え可能にする。

### Go実装

#### interface版

```go
package main

import "fmt"

// Strategy はアルゴリズムのインターフェース
type Strategy interface {
    Execute(a, b int) int
}

// AddStrategy は加算戦略
type AddStrategy struct{}

func (s *AddStrategy) Execute(a, b int) int {
    return a + b
}

// MultiplyStrategy は乗算戦略
type MultiplyStrategy struct{}

func (s *MultiplyStrategy) Execute(a, b int) int {
    return a * b
}

// Context は戦略を使用するコンテキスト
type Context struct {
    strategy Strategy
}

func (c *Context) SetStrategy(s Strategy) {
    c.strategy = s
}

func (c *Context) Execute(a, b int) int {
    return c.strategy.Execute(a, b)
}

// 使用例
func main() {
    ctx := &Context{}

    ctx.SetStrategy(&AddStrategy{})
    fmt.Println("10 + 5 =", ctx.Execute(10, 5))

    ctx.SetStrategy(&MultiplyStrategy{})
    fmt.Println("10 * 5 =", ctx.Execute(10, 5))
}
```

#### func版 (Go idiomatic)

```go
package main

import "fmt"

// Strategy はアルゴリズムを表す関数型
type Strategy func(int, int) int

// Context は戦略を使用するコンテキスト
type Context struct {
    strategy Strategy
}

func (c *Context) SetStrategy(s Strategy) {
    c.strategy = s
}

func (c *Context) Execute(a, b int) int {
    return c.strategy(a, b)
}

// 使用例
func main() {
    ctx := &Context{}

    // 加算戦略
    ctx.SetStrategy(func(a, b int) int {
        return a + b
    })
    fmt.Println("10 + 5 =", ctx.Execute(10, 5))

    // 乗算戦略
    ctx.SetStrategy(func(a, b int) int {
        return a * b
    })
    fmt.Println("10 * 5 =", ctx.Execute(10, 5))
}
```

### 使用場面
- ソートアルゴリズムの切り替え（QuickSort/MergeSort/HeapSort）
- 料金計算ロジック（通常/学生割引/シニア割引）
- 圧縮アルゴリズム（ZIP/GZIP/BZIP2）
- ルーティングアルゴリズム（最短経路/最速経路）
- 支払い方法（クレジットカード/銀行振込/電子マネー）

### Goイディオム
**ベストプラクティス**:
- シンプルなケース（単一メソッド）: `func` 型を使う
- 複数メソッドが必要: interface を使う

標準ライブラリの例:

```go
// sort.Sort は Strategy パターン
type Interface interface {
    Len() int
    Less(i, j int) bool
    Swap(i, j int)
}

sort.Sort(sort.IntSlice([]int{3, 1, 4, 1, 5}))

// http.HandlerFunc も Strategy パターン
http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
    // 処理
})
```

---

## 9. Template Method (テンプレートメソッド)

### 目的
アルゴリズムの骨格を定義し、一部のステップをサブクラスに委譲する。アルゴリズムの構造を変えずに特定のステップを再定義可能。

### Go実装

```go
package main

import "fmt"

// DataProcessor はデータ処理のインターフェース
type DataProcessor interface {
    Extract() []byte
    Transform(data []byte) []byte
    Load(data []byte) error
}

// Process はテンプレートメソッド（処理の骨格）
func Process(dp DataProcessor) error {
    fmt.Println("=== データ処理開始 ===")

    // ステップ1: 抽出
    data := dp.Extract()
    fmt.Println("✓ データ抽出完了")

    // ステップ2: 変換
    transformed := dp.Transform(data)
    fmt.Println("✓ データ変換完了")

    // ステップ3: ロード
    if err := dp.Load(transformed); err != nil {
        return err
    }
    fmt.Println("✓ データロード完了")

    fmt.Println("=== データ処理終了 ===")
    return nil
}

// CSVProcessor はCSV処理の実装
type CSVProcessor struct {
    filename string
}

func (c *CSVProcessor) Extract() []byte {
    fmt.Printf("CSV抽出: %s\n", c.filename)
    return []byte("name,age\nAlice,30")
}

func (c *CSVProcessor) Transform(data []byte) []byte {
    fmt.Println("CSV変換: 大文字に変換")
    // 実際は bytes.ToUpper(data) など
    return data
}

func (c *CSVProcessor) Load(data []byte) error {
    fmt.Printf("CSVロード: %d bytes\n", len(data))
    return nil
}

// JSONProcessor はJSON処理の実装
type JSONProcessor struct {
    url string
}

func (j *JSONProcessor) Extract() []byte {
    fmt.Printf("JSON抽出: %s\n", j.url)
    return []byte(`{"name":"Bob","age":25}`)
}

func (j *JSONProcessor) Transform(data []byte) []byte {
    fmt.Println("JSON変換: フィールド追加")
    return []byte(`{"name":"Bob","age":25,"processed":true}`)
}

func (j *JSONProcessor) Load(data []byte) error {
    fmt.Printf("JSONロード: %d bytes\n", len(data))
    return nil
}

// 使用例
func main() {
    csv := &CSVProcessor{filename: "data.csv"}
    Process(csv)

    fmt.Println()

    json := &JSONProcessor{url: "https://api.example.com/data"}
    Process(json)
}
```

### 使用場面
- ETLパイプライン（Extract/Transform/Load）
- レポート生成（データ取得→整形→PDF出力）
- テストフレームワーク（Setup→Test→Teardown）
- ビルドシステム（Clean→Compile→Link→Package）
- データマイグレーション

### Goイディオム
関数を引数に取るパターンも有効:

```go
type ProcessSteps struct {
    Extract   func() []byte
    Transform func([]byte) []byte
    Load      func([]byte) error
}

func Process(steps ProcessSteps) error {
    data := steps.Extract()
    transformed := steps.Transform(data)
    return steps.Load(transformed)
}

// 使用例
Process(ProcessSteps{
    Extract:   func() []byte { return []byte("data") },
    Transform: func(d []byte) []byte { return d },
    Load:      func(d []byte) error { return nil },
})
```

標準ライブラリの例:

```go
// http.HandlerFunc がテンプレートメソッドのような役割
http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
    // 前処理
    // メイン処理
    // 後処理
})
```

---

## 10. Visitor (ビジター)

### 目的
オブジェクト構造を変更せずに新しい操作を追加する。データ構造とアルゴリズムを分離。

### Go実装

```go
package main

import (
    "fmt"
    "math"
)

// Visitor は訪問者のインターフェース
type Visitor interface {
    VisitCircle(c *Circle)
    VisitRectangle(r *Rectangle)
    VisitTriangle(t *Triangle)
}

// Shape は図形のインターフェース
type Shape interface {
    Accept(v Visitor)
}

// Circle は円
type Circle struct {
    Radius float64
}

func (c *Circle) Accept(v Visitor) {
    v.VisitCircle(c)
}

// Rectangle は長方形
type Rectangle struct {
    Width  float64
    Height float64
}

func (r *Rectangle) Accept(v Visitor) {
    v.VisitRectangle(r)
}

// Triangle は三角形
type Triangle struct {
    Base   float64
    Height float64
}

func (t *Triangle) Accept(v Visitor) {
    v.VisitTriangle(t)
}

// AreaVisitor は面積計算の訪問者
type AreaVisitor struct {
    TotalArea float64
}

func (a *AreaVisitor) VisitCircle(c *Circle) {
    area := math.Pi * c.Radius * c.Radius
    fmt.Printf("円の面積: %.2f\n", area)
    a.TotalArea += area
}

func (a *AreaVisitor) VisitRectangle(r *Rectangle) {
    area := r.Width * r.Height
    fmt.Printf("長方形の面積: %.2f\n", area)
    a.TotalArea += area
}

func (a *AreaVisitor) VisitTriangle(t *Triangle) {
    area := (t.Base * t.Height) / 2
    fmt.Printf("三角形の面積: %.2f\n", area)
    a.TotalArea += area
}

// PerimeterVisitor は周囲長計算の訪問者
type PerimeterVisitor struct {
    TotalPerimeter float64
}

func (p *PerimeterVisitor) VisitCircle(c *Circle) {
    perimeter := 2 * math.Pi * c.Radius
    fmt.Printf("円の周囲長: %.2f\n", perimeter)
    p.TotalPerimeter += perimeter
}

func (p *PerimeterVisitor) VisitRectangle(r *Rectangle) {
    perimeter := 2 * (r.Width + r.Height)
    fmt.Printf("長方形の周囲長: %.2f\n", perimeter)
    p.TotalPerimeter += perimeter
}

func (p *PerimeterVisitor) VisitTriangle(t *Triangle) {
    // 簡略化のため、単純な計算
    perimeter := t.Base + t.Height + math.Sqrt(t.Base*t.Base+t.Height*t.Height)
    fmt.Printf("三角形の周囲長: %.2f\n", perimeter)
    p.TotalPerimeter += perimeter
}

// 使用例
func main() {
    shapes := []Shape{
        &Circle{Radius: 5},
        &Rectangle{Width: 4, Height: 6},
        &Triangle{Base: 3, Height: 4},
    }

    fmt.Println("=== 面積計算 ===")
    areaVisitor := &AreaVisitor{}
    for _, shape := range shapes {
        shape.Accept(areaVisitor)
    }
    fmt.Printf("合計面積: %.2f\n\n", areaVisitor.TotalArea)

    fmt.Println("=== 周囲長計算 ===")
    perimeterVisitor := &PerimeterVisitor{}
    for _, shape := range shapes {
        shape.Accept(perimeterVisitor)
    }
    fmt.Printf("合計周囲長: %.2f\n", perimeterVisitor.TotalPerimeter)
}
```

### 使用場面
- AST（抽象構文木）の走査・コード生成
- ドキュメント変換（HTML→PDF、Markdown→HTML）
- グラフ構造の探索・分析
- コンパイラの最適化パス
- ファイルシステムの操作（サイズ計算、検索）

### Goイディオム
type switchを使った簡易実装:

```go
func ProcessShape(shape Shape) {
    switch s := shape.(type) {
    case *Circle:
        fmt.Println("円を処理:", s.Radius)
    case *Rectangle:
        fmt.Println("長方形を処理:", s.Width, s.Height)
    case *Triangle:
        fmt.Println("三角形を処理:", s.Base, s.Height)
    }
}
```

標準ライブラリの例:

```go
// ast.Walk はVisitorパターン
ast.Inspect(node, func(n ast.Node) bool {
    switch x := n.(type) {
    case *ast.FuncDecl:
        fmt.Println("関数:", x.Name.Name)
    case *ast.CallExpr:
        fmt.Println("関数呼び出し")
    }
    return true
})
```

---

## 11. Interpreter (インタープリター)

### 目的
言語の文法を定義し、その言語で書かれた文を解釈・実行する。

### Go実装

```go
package main

import (
    "fmt"
    "strconv"
    "strings"
)

// Expression は式のインターフェース
type Expression interface {
    Interpret() int
}

// NumberExpression は数値式
type NumberExpression struct {
    value int
}

func (n *NumberExpression) Interpret() int {
    return n.value
}

// AddExpression は加算式
type AddExpression struct {
    left  Expression
    right Expression
}

func (a *AddExpression) Interpret() int {
    return a.left.Interpret() + a.right.Interpret()
}

// SubtractExpression は減算式
type SubtractExpression struct {
    left  Expression
    right Expression
}

func (s *SubtractExpression) Interpret() int {
    return s.left.Interpret() - s.right.Interpret()
}

// MultiplyExpression は乗算式
type MultiplyExpression struct {
    left  Expression
    right Expression
}

func (m *MultiplyExpression) Interpret() int {
    return m.left.Interpret() * m.right.Interpret()
}

// Parser は式を解析してExpressionツリーを構築
// 簡略化のため、逆ポーランド記法（RPN）を想定
// 例: "5 3 + 2 *" → ((5 + 3) * 2) = 16
func Parse(input string) (Expression, error) {
    tokens := strings.Fields(input)
    stack := []Expression{}

    for _, token := range tokens {
        switch token {
        case "+":
            if len(stack) < 2 {
                return nil, fmt.Errorf("不正な式")
            }
            right := stack[len(stack)-1]
            left := stack[len(stack)-2]
            stack = stack[:len(stack)-2]
            stack = append(stack, &AddExpression{left: left, right: right})

        case "-":
            if len(stack) < 2 {
                return nil, fmt.Errorf("不正な式")
            }
            right := stack[len(stack)-1]
            left := stack[len(stack)-2]
            stack = stack[:len(stack)-2]
            stack = append(stack, &SubtractExpression{left: left, right: right})

        case "*":
            if len(stack) < 2 {
                return nil, fmt.Errorf("不正な式")
            }
            right := stack[len(stack)-1]
            left := stack[len(stack)-2]
            stack = stack[:len(stack)-2]
            stack = append(stack, &MultiplyExpression{left: left, right: right})

        default:
            // 数値としてパース
            value, err := strconv.Atoi(token)
            if err != nil {
                return nil, fmt.Errorf("不正なトークン: %s", token)
            }
            stack = append(stack, &NumberExpression{value: value})
        }
    }

    if len(stack) != 1 {
        return nil, fmt.Errorf("不正な式")
    }

    return stack[0], nil
}

// 使用例
func main() {
    expressions := []string{
        "5 3 +",       // 5 + 3 = 8
        "10 2 -",      // 10 - 2 = 8
        "5 3 + 2 *",   // (5 + 3) * 2 = 16
        "10 2 - 3 *",  // (10 - 2) * 3 = 24
    }

    for _, expr := range expressions {
        parsed, err := Parse(expr)
        if err != nil {
            fmt.Printf("エラー: %s - %v\n", expr, err)
            continue
        }
        result := parsed.Interpret()
        fmt.Printf("%s = %d\n", expr, result)
    }
}
```

### 使用場面
- DSL（ドメイン固有言語）の実装
- 数式評価器・電卓
- 設定ファイルパーサー（簡易的なクエリ言語）
- 正規表現エンジン
- SQL解析（簡易版）
- スクリプト言語のインタープリター

### Goイディオム
複雑な文法には専用のパーサーライブラリを使用推奨:
- `go/parser` と `go/ast`: Goコードの解析
- `text/template`: テンプレートエンジン
- サードパーティ: `goyacc`, `antlr`, `participle`

```go
// 標準ライブラリのtext/templateもInterpreterパターン
tmpl := template.Must(template.New("test").Parse("Hello, {{.Name}}!"))
tmpl.Execute(os.Stdout, map[string]string{"Name": "World"})
```

注意:
- 文法が複雑になる場合、Interpreterパターンは保守性が低下
- パーサージェネレーターの使用を検討すべき

---

## 判断基準テーブル

| 状況 | 推奨パターン | 理由 |
|------|------------|------|
| リクエストの連鎖的処理 | Chain of Responsibility | 処理者を動的に追加・削除可能 |
| 操作のカプセル化・Undo | Command | 操作を履歴として保存可能 |
| コレクション走査 | Iterator | 内部構造を隠蔽しつつ要素アクセス |
| 多対多の通信集約 | Mediator | オブジェクト間の結合度を低減 |
| 状態の保存・復元 | Memento | カプセル化を破らずにスナップショット |
| イベント通知（1対多） | Observer | 状態変化を複数オブジェクトに自動通知 |
| 状態による振舞い変更 | State | 状態ごとの処理をクラスに分離 |
| アルゴリズムの動的切替 | Strategy | 実行時にアルゴリズムを変更可能 |
| 処理手順の骨格定義 | Template Method | 共通の流れを維持しつつ特定ステップを変更 |
| 構造を変えず操作追加 | Visitor | データ構造とアルゴリズムを分離 |
| DSL/文法の解釈 | Interpreter | 独自言語の実装が必要な場合 |

### 選択のヒント

**疎結合を重視する場合:**
- Mediator: 複数オブジェクトの通信を集約
- Observer: イベント駆動の疎結合

**柔軟性を重視する場合:**
- Strategy: アルゴリズムの切り替え
- State: 状態による振舞い変更
- Chain of Responsibility: 処理者の動的変更

**履歴管理が必要な場合:**
- Command: 操作の履歴管理
- Memento: 状態のスナップショット

**構造の走査・操作:**
- Iterator: コレクションの走査
- Visitor: 構造への新しい操作追加

**Goでの実装方針:**
- シンプルなケース: `func` 型や channel を優先
- 複雑な状態管理: interface ベースの実装
- 並行処理: channel ベースの Observer/Mediator
