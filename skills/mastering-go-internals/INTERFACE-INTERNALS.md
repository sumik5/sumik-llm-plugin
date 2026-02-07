# インターフェースの深層

interface値の内部表現、型アサーション、標準ライブラリの設計哲学、最適なinterface設計指針を解説します。

## interface値の内部表現

### 二要素構造（tab + data）

interface値は**2つのポインタ**で構成されます:

```go
type iface struct {
    tab  *itab        // 型情報（型ディスクリプタ）
    data unsafe.Pointer  // 実際の値へのポインタ
}

type itab struct {
    inter *interfacetype  // インターフェース型情報
    _type *_type         // 具体的な型情報
    hash  uint32         // _type.hashのコピー
    _     [4]byte
    fun   [1]uintptr     // メソッドテーブル
}
```

**図解**:

```
┌─────────────┐
│  interface  │
├─────────────┤
│ tab  ───────┼──→ itab (型情報 + メソッドテーブル)
│ data ───────┼──→ 実際の値
└─────────────┘
```

### 例: 実際のメモリ配置

```go
type Animal interface {
    Speak() string
}

type Dog struct {
    Name string
}

func (d Dog) Speak() string {
    return "Woof!"
}

func main() {
    var a Animal = Dog{Name: "Buddy"}
    // メモリ内:
    // a.tab → Dog型のitab（Speakメソッドへのポインタを含む）
    // a.data → Dog{Name: "Buddy"}のメモリアドレス
}
```

### メソッド呼び出しの仕組み

interfaceを通したメソッド呼び出し:

```go
var a Animal = Dog{Name: "Buddy"}
result := a.Speak()

// 内部処理:
// 1. a.tabからメソッドテーブルを取得
// 2. Speakメソッドのポインタを取得
// 3. a.dataを引数として間接呼び出し
```

**パフォーマンスコスト**: 間接呼び出しのため、直接呼び出しよりわずかに遅い。
ただし、ほとんどの場合その差は無視できます。

## 空interfaceの特殊構造

### interface{}（= any）の内部表現

空interface（`interface{}`または`any`）は異なる構造を使用:

```go
type eface struct {
    _type *_type        // 型情報のみ
    data  unsafe.Pointer  // 実際の値へのポインタ
}
```

**通常のinterfaceとの違い**:
- メソッドテーブル不要（メソッド要件がないため）
- より軽量な構造

```go
var x interface{} = 42
// x._type → int型の情報
// x.data → 42の値へのポインタ
```

### nilインターフェースの注意点

interface値が`nil`なのは**型と値の両方がnil**の場合のみ:

```go
var a Animal
fmt.Println(a == nil)  // true（型も値もnil）

var d *Dog = nil
a = d
fmt.Println(a == nil)  // false（型は*Dog、値はnil）
```

**正しいnilチェック**:

```go
func isReallyNil(a Animal) bool {
    return a == nil || reflect.ValueOf(a).IsNil()
}
```

## 型アサーション

### 単一値形式（パニックあり）

```go
var a interface{} = "hello"

s := a.(string)      // OK: s = "hello"
i := a.(int)         // パニック！
```

### 二値形式（パニック回避）

```go
s, ok := a.(string)
if ok {
    fmt.Println("文字列:", s)
} else {
    fmt.Println("文字列ではありません")
}
```

**ベストプラクティス**: 常に二値形式を使用してパニックを回避。

### パフォーマンス考慮

型アサーションは**内部的に型比較**を行います:

```go
// 高速（型ハッシュの比較）
s, ok := x.(string)

// 遅い（リフレクション使用）
v := reflect.ValueOf(x)
if v.Kind() == reflect.String {
    s := v.String()
}
```

**頻繁な型チェック**: 型スイッチまたは型別の処理関数を使用。

## 型スイッチ

### 基本構文

```go
func describe(x interface{}) {
    switch v := x.(type) {
    case int:
        fmt.Printf("整数: %d\n", v)
    case string:
        fmt.Printf("文字列: %s\n", v)
    case bool:
        fmt.Printf("真偽値: %t\n", v)
    default:
        fmt.Printf("不明な型: %T\n", v)
    }
}
```

### 複数型のケース

```go
switch v := x.(type) {
case int, int64:
    fmt.Printf("整数型: %v\n", v)
case string, []byte:
    fmt.Printf("文字列型: %v\n", v)
}
```

### 網羅的な設計

型スイッチは**網羅性を保証しない**ため、defaultケースを必ず含める:

```go
// ✅ 良い例
switch v := x.(type) {
case int:
    // ...
case string:
    // ...
default:
    return fmt.Errorf("未対応の型: %T", v)
}

// ❌ 悪い例（defaultなし）
switch v := x.(type) {
case int:
    // ...
case string:
    // ...
}  // 他の型が来たら何も処理されない
```

## sort.Interfaceの設計哲学

### 三メソッドの設計

```go
type Interface interface {
    Len() int
    Less(i, j int) bool
    Swap(i, j int)
}
```

**設計理由**:
- **Len**: コレクションのサイズ取得
- **Less**: 要素の順序比較（ソートアルゴリズムに必要）
- **Swap**: 要素の交換（インプレースソート用）

### 実装例

```go
type Person struct {
    Name string
    Age  int
}

type ByAge []Person

func (a ByAge) Len() int           { return len(a) }
func (a ByAge) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByAge) Less(i, j int) bool { return a[i].Age < a[j].Age }

// 使用
people := []Person{
    {"Alice", 30},
    {"Bob", 25},
    {"Charlie", 35},
}
sort.Sort(ByAge(people))
```

### sort.Sliceとの使い分け

**sort.Interface（パフォーマンス重視）**:

```go
sort.Sort(ByAge(people))  // 型安全、高速
```

**sort.Slice（簡潔性重視）**:

```go
sort.Slice(people, func(i, j int) bool {
    return people[i].Age < people[j].Age
})
// リフレクション使用→やや遅い
```

### 複数キーソート

```go
type ByAgeAndName []Person

func (a ByAgeAndName) Len() int      { return len(a) }
func (a ByAgeAndName) Swap(i, j int) { a[i], a[j] = a[j], a[i] }
func (a ByAgeAndName) Less(i, j int) bool {
    if a[i].Age != a[j].Age {
        return a[i].Age < a[j].Age  // 主キー: Age
    }
    return a[i].Name < a[j].Name    // 副キー: Name
}
```

### 安定ソート

```go
// 安定ソート（等価要素の順序を保持）
sort.Stable(ByAge(people))

// または
sort.SliceStable(people, func(i, j int) bool {
    return people[i].Age < people[j].Age
})
```

## http.Handlerの設計

### 単一メソッドインターフェース

```go
type Handler interface {
    ServeHTTP(ResponseWriter, *Request)
}
```

**設計理由**: 単純性とコンポーザビリティ（合成可能性）を両立。

### HandlerFuncアダプタパターン

関数をHandlerに変換:

```go
type HandlerFunc func(ResponseWriter, *Request)

func (f HandlerFunc) ServeHTTP(w ResponseWriter, r *Request) {
    f(w, r)  // 関数を呼び出す
}
```

**使用例**:

```go
func hello(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Hello, World!")
}

// 関数をHandlerに変換
http.Handle("/", http.HandlerFunc(hello))
```

### ミドルウェア合成

Handlerを受け取り、Handlerを返す関数:

```go
func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        log.Printf("%s %s", r.Method, r.URL.Path)
        next.ServeHTTP(w, r)  // 次のハンドラを呼び出し
    })
}

func authMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        token := r.Header.Get("Authorization")
        if token == "" {
            http.Error(w, "Unauthorized", http.StatusUnauthorized)
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

**合成例**:

```go
handler := http.HandlerFunc(hello)
handler = loggingMiddleware(handler)
handler = authMiddleware(handler)

http.ListenAndServe(":8080", handler)
// 実行順序: authMiddleware → loggingMiddleware → hello
```

### チェーン構築パターン

```go
func chain(h http.Handler, middlewares ...func(http.Handler) http.Handler) http.Handler {
    for i := len(middlewares) - 1; i >= 0; i-- {
        h = middlewares[i](h)
    }
    return h
}

// 使用
handler := chain(
    http.HandlerFunc(hello),
    loggingMiddleware,
    authMiddleware,
)
```

## 式エバリュエータの設計例

### Exprインターフェース（Interpreter Pattern）

```go
type Expr interface {
    Eval(env Env) float64
}

type Env map[string]float64
```

### 具体的な実装

```go
// リテラル
type Literal float64

func (l Literal) Eval(env Env) float64 {
    return float64(l)
}

// 変数
type Var string

func (v Var) Eval(env Env) float64 {
    return env[string(v)]
}

// 二項演算
type Binary struct {
    Op   rune  // '+', '-', '*', '/'
    X, Y Expr
}

func (b Binary) Eval(env Env) float64 {
    switch b.Op {
    case '+':
        return b.X.Eval(env) + b.Y.Eval(env)
    case '-':
        return b.X.Eval(env) - b.Y.Eval(env)
    case '*':
        return b.X.Eval(env) * b.Y.Eval(env)
    case '/':
        return b.X.Eval(env) / b.Y.Eval(env)
    }
    panic(fmt.Sprintf("未対応の演算子: %c", b.Op))
}
```

### 使用例

```go
// 式: x + 2 * y
expr := Binary{
    Op: '+',
    X:  Var("x"),
    Y: Binary{
        Op: '*',
        X:  Literal(2),
        Y:  Var("y"),
    },
}

env := Env{"x": 3, "y": 4}
result := expr.Eval(env)  // 3 + 2 * 4 = 11
```

### 拡張性

新しい演算を追加するには新しい型を定義するだけ:

```go
// 単項演算（符号反転）
type Unary struct {
    Op rune  // '-'
    X  Expr
}

func (u Unary) Eval(env Env) float64 {
    if u.Op == '-' {
        return -u.X.Eval(env)
    }
    panic(fmt.Sprintf("未対応の単項演算子: %c", u.Op))
}
```

## interfaceの最適な設計指針

### "The bigger the interface, the weaker the abstraction"

**小さなinterfaceを推奨**:

```go
// ✅ 良い例（小さなinterface）
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

// ❌ 悪い例（大きすぎるinterface）
type DataStore interface {
    Read(p []byte) (n int, err error)
    Write(p []byte) (n int, err error)
    Close() error
    Sync() error
    Seek(offset int64, whence int) (int64, error)
    // ... さらに多数のメソッド
}
```

### 消費者側でinterfaceを定義

**✅ 良い例（消費者側で定義）**:

```go
// パッケージA（消費者）
package a

type Logger interface {
    Log(message string)
}

func DoWork(logger Logger) {
    logger.Log("作業開始")
    // ...
}

// パッケージB（提供者）
package b

type FileLogger struct { /* ... */ }

func (f *FileLogger) Log(message string) { /* ... */ }
```

**❌ 悪い例（提供者側で定義）**:

```go
// パッケージB（提供者）
package b

type Logger interface {
    Log(message string)
}

type FileLogger struct { /* ... */ }

func (f *FileLogger) Log(message string) { /* ... */ }

// パッケージAが不要なLoggerインターフェースに依存
```

### 単一メソッドinterfaceを優先

Go標準ライブラリの多くは単一メソッド:

```go
io.Reader
io.Writer
io.Closer
http.Handler
sort.Interface (例外: 3メソッドだが密結合)
```

**利点**:
- 実装が簡単
- テストが容易
- 合成可能（interface embedding）

### interface埋め込みで合成

```go
type ReadWriter interface {
    Reader
    Writer
}

type ReadWriteCloser interface {
    Reader
    Writer
    Closer
}
```

### ゼロメソッドinterfaceの活用

型制約として使用:

```go
type Comparable interface {
    comparable  // Go 1.18+ ジェネリクス
}

func Contains[T comparable](slice []T, value T) bool {
    for _, v := range slice {
        if v == value {
            return true
        }
    }
    return false
}
```

## ベストプラクティス

### 型アサーション

1. **二値形式**: 常に`v, ok := x.(T)`を使用
2. **型スイッチ**: 複数型処理には`switch v := x.(type)`
3. **defaultケース**: 型スイッチに必ず含める

### interface設計

1. **小さく保つ**: 1-3メソッドを目標
2. **消費者側定義**: 使用側でinterfaceを定義
3. **命名規則**: `-er`サフィックス（Reader、Writer、Handler）
4. **composability**: 小さなinterfaceを組み合わせる

### パフォーマンス

1. **直接呼び出し優先**: ホットパスではinterfaceを避ける
2. **プロファイリング**: interface呼び出しが本当にボトルネックか確認
3. **型スイッチ最適化**: コンパイラが最適化する可能性

### テスト

1. **モックの活用**: interface実装でテスト容易性向上
2. **依存性注入**: interfaceを引数に取る設計

---

**関連ドキュメント**:
- [REFLECTION.md](./REFLECTION.md) - interface値の動的操作
- [TYPE-SYSTEM.md](./TYPE-SYSTEM.md) - 基本型とinterface{}
- [COMPOSITE-INTERNALS.md](./COMPOSITE-INTERNALS.md) - 構造体とinterface
