# 型システムの深層

Goの型システムのメモリ表現、精度限界、オーバーフロー検出、文字列の内部構造を詳解します。

## 整数型のメモリ表現

### サイズ別の整数型

Goは以下の整数型を提供:

| 型 | サイズ | 値の範囲（符号付き） | 値の範囲（符号なし） |
|----|--------|------------------|------------------|
| int8 | 1バイト | -128 〜 127 | - |
| uint8 | 1バイト | - | 0 〜 255 |
| int16 | 2バイト | -32768 〜 32767 | - |
| uint16 | 2バイト | - | 0 〜 65535 |
| int32 | 4バイト | -2147483648 〜 2147483647 | - |
| uint32 | 4バイト | - | 0 〜 4294967295 |
| int64 | 8バイト | -9223372036854775808 〜 9223372036854775807 | - |
| uint64 | 8バイト | - | 0 〜 18446744073709551615 |

### プラットフォーム依存のint/uint

`int`と`uint`はプラットフォームに依存:
- 32ビットシステム: 32ビット幅
- 64ビットシステム: 64ビット幅

```go
// プラットフォームに依存しない型
var x int32 = 42

// プラットフォーム依存（推奨：汎用目的）
var y int = 42
```

**選択指針**:
- **汎用目的**: `int`を使用（効率とレンジのバランス）
- **メモリ節約**: 必要に応じて`int8`、`int16`
- **外部データフォーマット**: `int32`、`int64`（固定サイズ必須）
- **バイト操作**: `uint8`（別名`byte`）

### リテラル表記

```go
// 10進数（基数10）
decimal := 42

// 8進数（0プレフィックス）
octal := 052  // 10進数で42

// 16進数（0xプレフィックス）
hex := 0x2A   // 10進数で42

// 2進数（0bプレフィックス、Go 1.13+）
binary := 0b101010  // 10進数で42

// 読みやすくするためのアンダースコア区切り（Go 1.13+）
million := 1_000_000
```

## 整数オーバーフロー

### オーバーフロー/アンダーフローの挙動

整数演算は**ラップアラウンド**（循環）します:

```go
var x int8 = 127
x++  // -128にラップアラウンド

var y int8 = -128
y--  // 127にラップアラウンド

fmt.Printf("x=%d, y=%d\n", x, y)
// 出力: x=-128, y=127
```

### オーバーフロー検出（math/bits）

`math/bits`パッケージで安全な演算:

```go
import "math/bits"

a := uint(math.MaxUint64)
b := uint(1)

sum, overflow := bits.Add64(uint64(a), uint64(b), 0)
if overflow != 0 {
    fmt.Println("オーバーフローが発生しました")
} else {
    fmt.Printf("合計: %d\n", sum)
}
```

**主要関数**:
- `bits.Add64(x, y, carry)`: 加算 + キャリー検出
- `bits.Sub64(x, y, borrow)`: 減算 + ボロー検出
- `bits.Mul64(x, y)`: 乗算 → (high, low)の2つの64ビット値
- `bits.Div64(hi, lo, y)`: 128ビット÷64ビット

### 任意精度演算（math/big）

組み込み整数型の範囲を超える計算には`math/big`:

```go
import "math/big"

// 非常に大きな整数
a := new(big.Int).SetString("12345678901234567890", 10)
b := new(big.Int).SetString("98765432109876543210", 10)

sum := new(big.Int)
sum.Add(a, b)

fmt.Printf("合計: %s\n", sum.String())
// 出力: 合計: 111111111011111111100
```

**使用場面**:
- 暗号化アルゴリズム（RSA等）
- 金融計算（非常に大きな金額）
- 科学計算（天文学的数値）

## 浮動小数点の精度

### IEEE 754標準

Goの浮動小数点型はIEEE 754標準に準拠:

| 型 | サイズ | 精度 | 指数範囲 |
|----|--------|------|---------|
| float32 | 4バイト | 約6-9桁 | ±10^±38 |
| float64 | 8バイト | 約15-17桁 | ±10^±308 |

**推奨**: ほとんどの場合`float64`を使用（精度が高い）

### 精度限界の例

```go
// float32の精度限界
var f float32 = 16777216  // 2^24
fmt.Println(f == f+1)     // true（精度不足で区別できない）

// 有名な0.1 + 0.2 ≠ 0.3問題
fmt.Println(0.1 + 0.2 == 0.3)  // false（2進数で正確に表現できない）

// 実際の値
fmt.Printf("%.17f\n", 0.1+0.2)  // 0.30000000000000004
```

### epsilon比較

浮動小数点数の比較にはepsilon（許容誤差）を使用:

```go
import "math"

const epsilon = 1e-9

func almostEqual(a, b float64) bool {
    return math.Abs(a-b) <= epsilon
}

fmt.Println(almostEqual(0.1+0.2, 0.3))  // true
```

**相対epsilon（より堅牢）**:

```go
func almostEqualRelative(a, b, epsilon float64) bool {
    diff := math.Abs(a - b)
    larger := math.Max(math.Abs(a), math.Abs(b))
    return diff <= epsilon*larger
}
```

### 金額計算の注意

**❌ 悪い例（浮動小数点を直接使用）**:

```go
price := 0.1
quantity := 3
total := price * quantity  // 0.30000000000000004
```

**✅ 良い例（整数で計算）**:

```go
// セント単位で計算
priceInCents := 10
quantity := 3
totalInCents := priceInCents * quantity  // 30
totalInDollars := float64(totalInCents) / 100.0  // 0.30
```

**✅ または専用パッケージ使用**:

```go
// github.com/shopspring/decimal
price := decimal.NewFromFloat(0.1)
quantity := decimal.NewFromInt(3)
total := price.Mul(quantity)  // 正確な0.3
```

### 特殊な浮動小数点値

```go
import "math"

// 無限大
posInf := math.Inf(1)   // +∞
negInf := math.Inf(-1)  // -∞

// NaN（Not a Number）
nan := math.NaN()

// 検証
fmt.Println(math.IsInf(1.0/0.0, 1))   // true（正の無限大）
fmt.Println(math.IsNaN(0.0/0.0))      // true
```

## 文字列の内部構造

### ヘッダ + バイト配列

文字列の内部表現は**2要素のヘッダ**:

```go
type stringHeader struct {
    Data uintptr  // バイト配列へのポインタ
    Len  int      // バイト数（文字数ではない）
}
```

```go
s := "Hello"
// メモリレイアウト:
// ヘッダ: [pointer=0x..., len=5]
// データ: [0x48, 0x65, 0x6C, 0x6C, 0x6F] ("Hello"のUTF-8バイト)
```

**重要**: 文字列のコピーは**ヘッダのみ**をコピー（軽量）。データ自体は共有されます。

### UTF-8エンコーディング

Goの文字列はUTF-8エンコーディング:

```go
s := "こんにちは"

// バイト数
fmt.Println(len(s))  // 15（日本語1文字=3バイト）

// 文字数（rune数）
fmt.Println(utf8.RuneCountInString(s))  // 5
```

**runeとbyteの違い**:

```go
s := "Go言語"

// byteイテレーション（バイト単位）
for i := 0; i < len(s); i++ {
    fmt.Printf("%x ", s[i])
}
// 出力: 47 6f e8 a8 80 e8 aa 9e

// runeイテレーション（文字単位）
for _, r := range s {
    fmt.Printf("%c ", r)
}
// 出力: G o 言 語
```

### イミュータブル性

文字列は**不変（immutable）**:

```go
s := "hello"
// s[0] = 'H'  // コンパイルエラー

// 文字列を変更するには新しい文字列を作成
s = "H" + s[1:]  // "Hello"
```

**パフォーマンス考慮**:

```go
// ❌ 非効率（毎回新しい文字列を作成）
result := ""
for i := 0; i < 1000; i++ {
    result += "a"
}

// ✅ 効率的（strings.Builderを使用）
var builder strings.Builder
for i := 0; i < 1000; i++ {
    builder.WriteString("a")
}
result := builder.String()
```

## 定数の型システム

### Untyped Constants

Goの定数は**untyped（型なし）**で宣言可能:

```go
const Pi = 3.14159  // untyped float constant

var f float32 = Pi  // float32に変換
var d float64 = Pi  // float64に変換
```

**利点**: 高精度を保持し、使用時に適切な型に変換されます。

### 定数のデフォルト型

untyped constantsが式で使用される際のデフォルト型:

| リテラル | デフォルト型 |
|---------|------------|
| 整数 | int |
| 浮動小数点 | float64 |
| 複素数 | complex128 |
| 文字 | rune (int32) |
| 文字列 | string |
| 真偽値 | bool |

```go
const x = 42       // untyped int
const y = 3.14     // untyped float
const z = 1 + 2i   // untyped complex

var a int = x      // OK
var b float64 = y  // OK
var c complex128 = z  // OK
```

### iotaによる列挙

`iota`は定数宣言内でインクリメントされる特殊な定数:

```go
const (
    Sunday = iota     // 0
    Monday            // 1
    Tuesday           // 2
    Wednesday         // 3
    Thursday          // 4
    Friday            // 5
    Saturday          // 6
)
```

**応用例**:

```go
// ビットフラグ
const (
    FlagRead = 1 << iota  // 1 (0b0001)
    FlagWrite             // 2 (0b0010)
    FlagExecute           // 4 (0b0100)
)

// スキップ
const (
    _ = iota  // 0をスキップ
    KB = 1 << (10 * iota)  // 1024
    MB                      // 1048576
    GB                      // 1073741824
)
```

## ベストプラクティス

### 整数型の選択

1. **汎用目的**: `int`を使用
2. **外部フォーマット**: `int32`、`int64`（プロトコル、ファイル形式）
3. **メモリ最適化**: 必要に応じて小さい型（`int8`、`int16`）
4. **バイト操作**: `byte`（`uint8`の別名）

### オーバーフロー対策

1. **範囲チェック**: 計算前に値が範囲内か確認
2. **math/bitsの活用**: オーバーフロー検出機能を使用
3. **math/big**: 範囲を超える計算には任意精度型

### 浮動小数点の扱い

1. **epsilon比較**: 等価比較にはepsilonを使用
2. **金額計算**: 整数（セント単位）またはdecimalパッケージ
3. **float64優先**: 精度が重要な場合は常に`float64`
4. **特殊値チェック**: `math.IsNaN`、`math.IsInf`で検証

### 文字列操作

1. **strings.Builder**: 繰り返し連結する場合
2. **[]rune変換**: 文字単位で操作する場合
3. **イミュータブル性の活用**: 並行処理で安全に共有可能

### 定数の活用

1. **untyped constants**: 柔軟性のためにデフォルトで型指定しない
2. **iota**: 列挙型の定義に活用
3. **定数グルーピング**: 関連する定数はconst()ブロックでまとめる

---

## 型変換 vs 型アサーション

Goには「型変換」と「型アサーション」という2つの異なる型変換メカニズムがあります。

### Type Conversion（型変換）: `T(v)`

**互換性のある具体型間**でのみ有効。コンパイル時に検証されます。

```go
// Good: 互換性のある型間での変換
var i int = 42
var f float64 = float64(i) // int → float64
var u uint = uint(f)       // float64 → uint
var b byte = byte(i)       // int → byte (uint8)

// ❌ コンパイルエラー: 互換性のない型
// var s string = string(42)  // NG（intからstringへは直接変換不可）
```

### Type Assertion（型アサーション）: `v.(T)`

**interface値**の具体型を取り出す操作。ランタイムに検証されます。

```go
var v interface{} = "hello"

// 安全でない方法（panicの恐れ）
s := v.(string) // v が string でなければ panic

// ✅ コンマokパターン（推奨）
s, ok := v.(string)
if !ok {
    fmt.Println("not a string")
    return
}
fmt.Println(s) // "hello"
```

### 2つの違いまとめ

| | Type Conversion `T(v)` | Type Assertion `v.(T)` |
|--|------------------------|------------------------|
| 対象 | 具体型 → 具体型 | interface値 → 具体型 |
| 検証タイミング | コンパイル時 | ランタイム |
| 失敗した場合 | コンパイルエラー | panic（2値形式なら `ok=false`） |
| 典型例 | `int64(x)`, `float64(n)` | `err.(MyError)`, `w.(http.Flusher)` |

```go
// 実践例: インターフェースの実装確認
func process(w http.ResponseWriter) {
    // http.ResponseWriter が http.Flusher を実装しているか確認
    if flusher, ok := w.(http.Flusher); ok {
        flusher.Flush()
    }
}
```

---

**関連ドキュメント**:
- [COMPOSITE-INTERNALS.md](./COMPOSITE-INTERNALS.md) - スライス、マップ、構造体の内部構造
- [LOW-LEVEL.md](./LOW-LEVEL.md) - unsafe.Sizeofによるメモリサイズ検査
