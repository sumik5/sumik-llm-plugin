# リフレクション

reflect.TypeとValueの操作、構造体フィールド走査、動的呼び出し、パフォーマンスコスト、ベストプラクティスを解説します。

## reflect.Typeとreflect.Valueの基礎

### reflect.Type - 型情報

`reflect.Type`は型のメタデータを表現:

```go
import "reflect"

t := reflect.TypeOf(42)
fmt.Println(t.Name())  // "int"
fmt.Println(t.Kind())  // "int"

s := "hello"
t = reflect.TypeOf(s)
fmt.Println(t.Name())  // "string"
fmt.Println(t.Kind())  // "string"
```

**主要メソッド**:
- `Name()`: 型名（組み込み型やnamed type）
- `Kind()`: 型の種類（int, string, struct, slice等）
- `NumField()`: 構造体のフィールド数
- `Field(i int)`: i番目のフィールド情報

### reflect.Value - 値の操作

`reflect.Value`は値の動的操作を提供:

```go
v := reflect.ValueOf(42)
fmt.Println(v.Int())      // 42
fmt.Println(v.Kind())     // int
fmt.Println(v.Type())     // int
```

**主要メソッド**:
- `Interface()`: 元の値を`interface{}`として取得
- `Int()`, `Uint()`, `Float()`, `String()`: 型別の値取得
- `CanSet()`: 値を設定可能か
- `Set(x Value)`: 値を設定

### KindとTypeの違い

```go
type MyInt int

var x MyInt = 42
v := reflect.ValueOf(x)

fmt.Println(v.Type())  // "main.MyInt"（型名）
fmt.Println(v.Kind())  // "int"（基底型の種類）
```

## 構造体フィールドの動的走査

### 基本的な走査

```go
type Person struct {
    Name string
    Age  int
    City string
}

p := Person{"Alice", 30, "Tokyo"}
v := reflect.ValueOf(p)
t := v.Type()

for i := 0; i < v.NumField(); i++ {
    field := t.Field(i)
    value := v.Field(i)
    fmt.Printf("%s: %v\n", field.Name, value.Interface())
}
// 出力:
// Name: Alice
// Age: 30
// City: Tokyo
```

### フィールド情報の取得

```go
field := t.Field(0)

fmt.Println(field.Name)       // "Name"
fmt.Println(field.Type)       // string
fmt.Println(field.Tag)        // 構造体タグ
fmt.Println(field.Offset)     // メモリオフセット
fmt.Println(field.Anonymous)  // 埋め込みフィールドか
```

### ネストした構造体の走査

```go
type Address struct {
    Street string
    City   string
}

type Person struct {
    Name    string
    Age     int
    Address Address
}

func printFields(v reflect.Value, prefix string) {
    t := v.Type()
    for i := 0; i < v.NumField(); i++ {
        field := t.Field(i)
        value := v.Field(i)

        name := prefix + field.Name

        if field.Type.Kind() == reflect.Struct {
            printFields(value, name+".")  // 再帰
        } else {
            fmt.Printf("%s: %v\n", name, value.Interface())
        }
    }
}

p := Person{"Alice", 30, Address{"Main St", "Tokyo"}}
printFields(reflect.ValueOf(p), "")
// 出力:
// Name: Alice
// Age: 30
// Address.Street: Main St
// Address.City: Tokyo
```

## 変数の動的操作

### CanSetとElem

値を変更するには**アドレス可能（addressable）**である必要があります:

```go
x := 42
v := reflect.ValueOf(x)
fmt.Println(v.CanSet())  // false（xのコピーを指している）

// ポインタ経由で変更可能にする
p := reflect.ValueOf(&x)
v = p.Elem()  // ポインタが指す値を取得
fmt.Println(v.CanSet())  // true
```

### 値の設定

```go
x := 42
v := reflect.ValueOf(&x).Elem()

v.SetInt(100)
fmt.Println(x)  // 100
```

**型別の設定メソッド**:
- `SetInt(x int64)`
- `SetUint(x uint64)`
- `SetFloat(x float64)`
- `SetString(x string)`
- `SetBool(x bool)`
- `Set(x Value)`: 汎用（任意の型）

### 構造体フィールドの変更

```go
type Person struct {
    Name string
    Age  int
}

p := Person{"Alice", 30}
v := reflect.ValueOf(&p).Elem()

// Nameフィールドを変更
nameField := v.FieldByName("Name")
if nameField.CanSet() {
    nameField.SetString("Bob")
}

fmt.Println(p.Name)  // "Bob"
```

### プライベートフィールドの制約

プライベートフィールドは変更**不可**:

```go
type Person struct {
    name string  // プライベート
}

p := Person{"Alice"}
v := reflect.ValueOf(&p).Elem()
nameField := v.FieldByName("name")

fmt.Println(nameField.CanSet())  // false
// nameField.SetString("Bob")  // パニック！
```

## ネストしたフィールドの操作

### dot-separated pathでのアクセス

```go
func getFieldByPath(v reflect.Value, path string) reflect.Value {
    parts := strings.Split(path, ".")
    for _, part := range parts {
        v = v.FieldByName(part)
        if !v.IsValid() {
            return reflect.Value{}
        }
    }
    return v
}

type Address struct {
    City string
}

type Person struct {
    Name    string
    Address Address
}

p := Person{"Alice", Address{"Tokyo"}}
v := reflect.ValueOf(p)

city := getFieldByPath(v, "Address.City")
fmt.Println(city.String())  // "Tokyo"
```

## メソッドの動的呼び出し

### MethodByNameとCall

```go
type Calculator struct{}

func (c Calculator) Add(a, b int) int {
    return a + b
}

func (c Calculator) Multiply(a, b int) int {
    return a * b
}

calc := Calculator{}
v := reflect.ValueOf(calc)

// Addメソッドを取得
method := v.MethodByName("Add")

// 引数を準備
args := []reflect.Value{
    reflect.ValueOf(10),
    reflect.ValueOf(20),
}

// メソッドを呼び出し
results := method.Call(args)
fmt.Println(results[0].Int())  // 30
```

### メソッドの動的選択

```go
methodName := "Multiply"  // 実行時に決定
method := v.MethodByName(methodName)

if method.IsValid() {
    results := method.Call(args)
    fmt.Println(results[0].Int())  // 200
} else {
    fmt.Println("メソッドが見つかりません")
}
```

### 可変長引数の扱い

```go
type Printer struct{}

func (p Printer) Print(format string, args ...interface{}) {
    fmt.Printf(format, args...)
}

printer := Printer{}
v := reflect.ValueOf(printer)
method := v.MethodByName("Print")

// 可変長引数を準備
args := []reflect.Value{
    reflect.ValueOf("Hello %s, you are %d years old\n"),
    reflect.ValueOf("Alice"),
    reflect.ValueOf(30),
}

method.Call(args)
// 出力: Hello Alice, you are 30 years old
```

## Deep Copy実装

### 再帰的な値コピー

```go
func DeepCopy(v interface{}) interface{} {
    if v == nil {
        return nil
    }

    original := reflect.ValueOf(v)
    copy := reflect.New(original.Type()).Elem()
    deepCopyRecursive(original, copy)

    return copy.Interface()
}

func deepCopyRecursive(original, copy reflect.Value) {
    switch original.Kind() {
    case reflect.Ptr:
        originalValue := original.Elem()
        if !originalValue.IsValid() {
            return
        }
        copy.Set(reflect.New(originalValue.Type()))
        deepCopyRecursive(originalValue, copy.Elem())

    case reflect.Interface:
        if original.IsNil() {
            return
        }
        originalValue := original.Elem()
        copyValue := reflect.New(originalValue.Type()).Elem()
        deepCopyRecursive(originalValue, copyValue)
        copy.Set(copyValue)

    case reflect.Struct:
        for i := 0; i < original.NumField(); i++ {
            if original.Type().Field(i).PkgPath != "" {
                continue  // プライベートフィールドはスキップ
            }
            deepCopyRecursive(original.Field(i), copy.Field(i))
        }

    case reflect.Slice:
        if original.IsNil() {
            return
        }
        copy.Set(reflect.MakeSlice(original.Type(), original.Len(), original.Cap()))
        for i := 0; i < original.Len(); i++ {
            deepCopyRecursive(original.Index(i), copy.Index(i))
        }

    case reflect.Map:
        if original.IsNil() {
            return
        }
        copy.Set(reflect.MakeMap(original.Type()))
        for _, key := range original.MapKeys() {
            originalValue := original.MapIndex(key)
            copyValue := reflect.New(originalValue.Type()).Elem()
            deepCopyRecursive(originalValue, copyValue)
            copy.SetMapIndex(key, copyValue)
        }

    default:
        copy.Set(original)
    }
}
```

### 使用例

```go
type Person struct {
    Name    string
    Age     int
    Friends []string
}

original := Person{
    Name:    "Alice",
    Age:     30,
    Friends: []string{"Bob", "Charlie"},
}

copied := DeepCopy(original).(Person)
copied.Friends[0] = "David"

fmt.Println(original.Friends[0])  // "Bob"（変更されていない）
fmt.Println(copied.Friends[0])    // "David"
```

## 構造体フィールドタグの活用

### タグの取得

```go
type User struct {
    ID       int    `json:"id" db:"user_id"`
    Name     string `json:"name" db:"username"`
    Password string `json:"-" db:"password"`
}

t := reflect.TypeOf(User{})
field, _ := t.FieldByName("ID")

jsonTag := field.Tag.Get("json")
dbTag := field.Tag.Get("db")

fmt.Println(jsonTag)  // "id"
fmt.Println(dbTag)    // "user_id"
```

### タグの存在確認

```go
field, _ := t.FieldByName("Password")

jsonTag, ok := field.Tag.Lookup("json")
if ok {
    fmt.Println("JSONタグ:", jsonTag)  // "-"
} else {
    fmt.Println("JSONタグなし")
}
```

### カスタムタグの実装例

```go
type Validator struct{}

func (v Validator) Validate(s interface{}) error {
    val := reflect.ValueOf(s)
    typ := val.Type()

    for i := 0; i < val.NumField(); i++ {
        field := typ.Field(i)
        value := val.Field(i)

        if tag := field.Tag.Get("validate"); tag != "" {
            if tag == "required" && value.IsZero() {
                return fmt.Errorf("%s is required", field.Name)
            }
        }
    }
    return nil
}

type User struct {
    Name  string `validate:"required"`
    Email string `validate:"required"`
    Age   int
}

validator := Validator{}
user := User{Name: "Alice"}  // Emailが空

err := validator.Validate(user)
if err != nil {
    fmt.Println(err)  // "Email is required"
}
```

## パフォーマンスとベストプラクティス

### リフレクションのコスト

**ベンチマーク例**:

```go
// 直接呼び出し
func BenchmarkDirect(b *testing.B) {
    calc := Calculator{}
    for i := 0; i < b.N; i++ {
        calc.Add(10, 20)
    }
}

// リフレクション経由
func BenchmarkReflection(b *testing.B) {
    calc := Calculator{}
    v := reflect.ValueOf(calc)
    method := v.MethodByName("Add")
    args := []reflect.Value{
        reflect.ValueOf(10),
        reflect.ValueOf(20),
    }

    for i := 0; i < b.N; i++ {
        method.Call(args)
    }
}
```

**典型的な結果**: リフレクションは直接呼び出しの**10-100倍遅い**。

### 5つの重要原則

#### 1. 使用を最小限に

```go
// ❌ 悪い例（不要なリフレクション）
func printInt(x interface{}) {
    v := reflect.ValueOf(x)
    fmt.Println(v.Int())
}

// ✅ 良い例（型パラメータ使用）
func printInt[T ~int](x T) {
    fmt.Println(x)
}
```

#### 2. 結果をキャッシュ

```go
// ❌ 悪い例（毎回MethodByName）
for i := 0; i < 1000; i++ {
    method := v.MethodByName("Process")
    method.Call(args)
}

// ✅ 良い例（一度だけ取得）
method := v.MethodByName("Process")
for i := 0; i < 1000; i++ {
    method.Call(args)
}
```

#### 3. ホットパスを避ける

リフレクションは**初期化時**または**設定時**に使用し、
パフォーマンスクリティカルなループ内では避ける。

```go
// ✅ 良い例（初期化時に型情報を取得）
type Processor struct {
    processMethod reflect.Value
}

func NewProcessor(handler interface{}) *Processor {
    v := reflect.ValueOf(handler)
    return &Processor{
        processMethod: v.MethodByName("Process"),
    }
}

func (p *Processor) Process(data interface{}) {
    args := []reflect.Value{reflect.ValueOf(data)}
    p.processMethod.Call(args)  // 事前取得済み
}
```

#### 4. 型アサーションを優先

```go
// ✅ リフレクションより型アサーションを優先
switch v := x.(type) {
case int:
    fmt.Println(v * 2)
case string:
    fmt.Println(strings.ToUpper(v))
default:
    // 最後の手段としてリフレクション
    reflect.ValueOf(v)
}
```

#### 5. テストとベンチマーク必須

リフレクションを使用するコードは:
- **徹底的なユニットテスト**（エッジケース含む）
- **ベンチマーク**（パフォーマンス影響を測定）
- **プロファイリング**（ボトルネックを特定）

## ベストプラクティスまとめ

### 適切な使用場面

- **JSON/XMLエンコーディング**: 汎用シリアライザ
- **ORMライブラリ**: 動的なSQL構築
- **依存性注入フレームワーク**: 型情報に基づく注入
- **テストフレームワーク**: テーブル駆動テスト
- **プラグインシステム**: 動的ロード

### 回避すべき使用

- **型が既知の場合**: 型パラメータまたは型アサーション使用
- **ホットパス**: パフォーマンスクリティカルなループ内
- **単純な処理**: リフレクションは複雑性を増す

### コード品質

1. **ドキュメント必須**: なぜリフレクションが必要か明記
2. **エラー処理徹底**: `IsValid()`, `CanSet()`を常にチェック
3. **カプセル化**: リフレクション使用箇所を限定
4. **テスト充実**: エッジケース（nil、ゼロ値、プライベートフィールド）

---

**関連ドキュメント**:
- [INTERFACE-INTERNALS.md](./INTERFACE-INTERNALS.md) - interface値の内部構造
- [LOW-LEVEL.md](./LOW-LEVEL.md) - unsafeとの組み合わせ
- [COMPOSITE-INTERNALS.md](./COMPOSITE-INTERNALS.md) - 構造体のメモリレイアウト
