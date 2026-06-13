# nil ハンドリング

GoのnilはC言語のNULLポインタとは根本的に異なる。interfaceの二層構造を理解することがバグ防止の鍵。

→ interfaceの内部構造の詳細は [INT-INTERFACE-INTERNALS.md](./INT-INTERFACE-INTERNALS.md) 参照
→ データ構造のゼロ値については [DATA-STRUCTURES.md](./DATA-STRUCTURES.md) 参照

---

## 1. interfaceのnil値パラドックス

### interface = (type, value) のタプル

interfaceはランタイムで `(type, value)` の2要素タプルとして表現される。**両方がnilのときのみ**、interface値はnilになる。

```go
// ❌ 罠: 具体型のnilポインタをinterfaceに代入する
type MyError struct{ msg string }
func (e *MyError) Error() string { return e.msg }

func mayFail(fail bool) error {
    var err *MyError // nilポインタ（具体型）
    if fail {
        err = &MyError{"something went wrong"}
    }
    return err // ← interface(type=*MyError, value=nil) として返る
}

func main() {
    err := mayFail(false)
    if err != nil { // ← true! typeが*MyErrorなのでnilにならない
        fmt.Println("エラーが発生しました:", err) // 実行される
    }
}
```

```go
// ✅ 正しいパターン: nilを直接返す
func mayFail(fail bool) error {
    if fail {
        return &MyError{"something went wrong"}
    }
    return nil // interface(type=nil, value=nil) → == nil が true
}
```

### nilかどうかの判定方法

```go
// ✅ reflect.ValueOf でnil判定（interface経由で受け取った値）
func isNil(i interface{}) bool {
    if i == nil {
        return true
    }
    v := reflect.ValueOf(i)
    switch v.Kind() {
    case reflect.Ptr, reflect.Map, reflect.Slice,
         reflect.Chan, reflect.Func, reflect.Interface:
        return v.IsNil()
    }
    return false
}

// ✅ 型アサーションで具体型を取得してからnil判定
func checkError(err error) {
    if myErr, ok := err.(*MyError); ok && myErr == nil {
        fmt.Println("*MyError型だがnilポインタ")
    }
}
```

---

## 2. 型別 nil 挙動一覧

| 型 | nil時の読み取り | nil時の書き込み | ゼロ値はnil？ |
|----|--------------|--------------|------------|
| ポインタ (`*T`) | **panic** (デリファレンス) | **panic** (デリファレンス) | ✅ |
| スライス (`[]T`) | `len=0, cap=0`、安全に反復可能 | `append()` 可能 | ✅ |
| マップ (`map[K]V`) | ゼロ値返却、安全に読み取り可 | **panic** (assignment to nil map) | ✅ |
| チャネル (`chan T`) | **永久ブロック** | **永久ブロック** | ✅ |
| 関数 (`func()`) | **panic** (nil function call) | - | ✅ |
| interface | **panic** (メソッド呼び出し時) | - | ✅ |

```go
// ポインタ: nilデリファレンスはpanic
var p *int
// fmt.Println(*p) // ← panic: runtime error: invalid memory address

// スライス: nilスライスは安全
var s []int
fmt.Println(len(s))    // 0（安全）
fmt.Println(cap(s))    // 0（安全）
for _, v := range s {} // 反復も安全（0回実行）
s = append(s, 1)       // append可能（安全）

// マップ: 読み取りは安全だが書き込みはpanic
var m map[string]int
fmt.Println(m["key"]) // 0（安全、ゼロ値が返る）
// m["key"] = 1       // ← panic: assignment to entry in nil map

// チャネル: nilチャネルは永久ブロック
var ch chan int
// ch <- 1  // ← 永久ブロック（goroutineリーク）
// <-ch     // ← 永久ブロック
// select での利用のみ安全（nil caseは選択されない）
```

### selectでのnil channelの活用

```go
// ✅ nil channelはselectで「無効化」として活用できる
func merge(ch1, ch2 <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for ch1 != nil || ch2 != nil {
            select {
            case v, ok := <-ch1:
                if !ok {
                    ch1 = nil // nilにすることでこのcaseを無効化
                    continue
                }
                out <- v
            case v, ok := <-ch2:
                if !ok {
                    ch2 = nil
                    continue
                }
                out <- v
            }
        }
    }()
    return out
}
```

---

## 3. nil receiver ガードパターン

ポインタレシーバのメソッドは、nil receiverでも呼び出し可能。適切に処理することでNPEを防げる。

```go
// ✅ nil receiverを安全に処理する
type Node struct {
    Value int
    Left  *Node
    Right *Node
}

// nil receiverでも呼び出せる再帰実装
func (n *Node) Sum() int {
    if n == nil {
        return 0 // nilノードは0を返す（再帰の終端）
    }
    return n.Value + n.Left.Sum() + n.Right.Sum()
}

// 使用例: nilチェック不要で再帰を書ける
tree := &Node{
    Value: 1,
    Left:  &Node{Value: 2},
    Right: nil, // nilでも安全
}
fmt.Println(tree.Sum()) // 3
```

```go
// ✅ Stringerインターフェースのnil guard
type Config struct {
    Host string
    Port int
}

func (c *Config) String() string {
    if c == nil {
        return "<nil config>"
    }
    return fmt.Sprintf("%s:%d", c.Host, c.Port)
}

var cfg *Config
fmt.Println(cfg) // "<nil config>" ← panicせず安全に表示
```

---

## 4. nilスライス vs 空スライス

表面的に同じ動作をするが、JSONマーシャリングで異なる結果になる。

```go
var nilSlice []int         // nil スライス（ゼロ値）
emptySlice := []int{}      // 空スライス（長さ0、nilではない）
madeSlice := make([]int, 0) // make()で作った空スライス

// 長さ・容量はどちらも0
fmt.Println(len(nilSlice), cap(nilSlice))    // 0 0
fmt.Println(len(emptySlice), cap(emptySlice)) // 0 0

// nil判定は異なる
fmt.Println(nilSlice == nil)   // true
fmt.Println(emptySlice == nil) // false

// ❌ JSONマーシャリングで違いが出る
nilJSON, _ := json.Marshal(nilSlice)    // "null"
emptyJSON, _ := json.Marshal(emptySlice) // "[]"

// APIレスポンスで [] を期待する場合は空スライスが必要
type Response struct {
    Items []string `json:"items"`
}
// ❌ nilスライス → {"items": null}
// ✅ 空スライス  → {"items": []}
```

```go
// ✅ 推奨: nilスライスを使い、len()でチェック
var s []string

// nilでもlen()は安全
if len(s) == 0 {
    // 空の処理
}

// APIレスポンス用に変換する場合のみ空スライスに
func toResponse(s []string) []string {
    if s == nil {
        return []string{} // null → [] の変換
    }
    return s
}
```

---

## 5. nilマップの安全な使用パターン

```go
// ✅ 読み取りは安全（ゼロ値が返る）
var m map[string]int
count := m["key"] // 0（panicしない）

// ❌ 書き込みはpanic
// m["key"] = 1 // panic: assignment to entry in nil map

// ✅ 遅延初期化パターン
type Cache struct {
    data map[string]int
}

func (c *Cache) Set(key string, val int) {
    if c.data == nil {
        c.data = make(map[string]int) // 初回書き込み時にinitialize
    }
    c.data[key] = val
}

func (c *Cache) Get(key string) (int, bool) {
    v, ok := c.data[key] // nilマップの読み取りは安全
    return v, ok
}
```

```go
// ✅ sync.Mapを使ったgoroutineセーフなマップ
var sm sync.Map

sm.Store("key", 42)
if v, ok := sm.Load("key"); ok {
    fmt.Println(v.(int)) // 42
}
```

---

## 6. よくある罠と対処法

### 罠: error interfaceへの具体型nil代入

```go
// ❌ 前述の罠（再掲・重要）
func getError() error {
    var p *os.PathError
    return p // (type=*os.PathError, value=nil) → != nil
}

// ✅ 具体型のnilを返す場合はinterface変数経由で
func getError() error {
    var err error // interface型のnil
    return err   // (type=nil, value=nil) → == nil
}
```

### 罠: nilチャネルへのclose

```go
var ch chan int
// close(ch) // ← panic: close of nil channel

// ✅ closeの前にnilチェック
if ch != nil {
    close(ch)
}
```

### 罠: nilレシーバへのメソッドチェーン

```go
// ❌ nilのメソッドチェーン（panicリスク）
type Builder struct { parts []string }
func (b *Builder) Add(s string) *Builder {
    b.parts = append(b.parts, s) // bがnilならpanic
    return b
}

// ✅ nilガード付きチェーン
func (b *Builder) Add(s string) *Builder {
    if b == nil {
        return &Builder{parts: []string{s}}
    }
    b.parts = append(b.parts, s)
    return b
}
```

---

## チェックリスト

- [ ] 関数がerrorを返す場合、具体型のnilポインタではなく `return nil` を使っているか
- [ ] nilマップへの書き込み前にnilチェックまたはmakeで初期化しているか
- [ ] nil channelを送受信しているループでselectを使ってブロックを回避しているか
- [ ] APIレスポンスのスライスフィールドがnullではなく[]になっているか
- [ ] ポインタレシーバのメソッドでnil receiverを安全に処理しているか
