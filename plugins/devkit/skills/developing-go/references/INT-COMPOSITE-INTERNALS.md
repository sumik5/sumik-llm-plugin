# 複合型の内部構造

配列、スライス、マップ、構造体の内部実装とメモリ管理を詳解します。

## 配列の内部構造

### 値セマンティクス

配列は**値型**（コピーされる）:

```go
a := [3]int{1, 2, 3}
b := a          // 配列全体をコピー
b[0] = 100

fmt.Println(a)  // [1 2 3]（元の配列は変更されない）
fmt.Println(b)  // [100 2 3]
```

### メモリ上の連続配置

配列要素はメモリ上に連続して配置:

```go
arr := [4]int{10, 20, 30, 40}
// メモリレイアウト（64ビットシステム）:
// [10][20][30][40]
//  ↑   ↑   ↑   ↑
//  0   8  16  24  （バイトオフセット）
```

### 関数引数でのコピー

配列を関数に渡すと**全体がコピー**される:

```go
func modifyArray(arr [5]int) {
    arr[0] = 100  // ローカルコピーを変更
}

func main() {
    a := [5]int{1, 2, 3, 4, 5}
    modifyArray(a)
    fmt.Println(a[0])  // 1（変更されていない）
}
```

**ポインタ渡しで元の配列を変更**:

```go
func modifyArray(arr *[5]int) {
    arr[0] = 100
}

func main() {
    a := [5]int{1, 2, 3, 4, 5}
    modifyArray(&a)
    fmt.Println(a[0])  // 100（変更された）
}
```

### パフォーマンス特性

**利点**:
- コンパイル時にサイズが決定 → 最適化しやすい
- 連続メモリ配置 → キャッシュ効率が高い
- GCオーバーヘッドが少ない

**欠点**:
- サイズ固定（動的にリサイズ不可）
- 関数引数での大量コピー

## スライスの内部構造

### 三要素ヘッダ

スライスは**3つのフィールドを持つヘッダ**:

```go
type sliceHeader struct {
    Data uintptr  // 底層配列の先頭へのポインタ
    Len  int      // 長さ（現在のスライスの要素数）
    Cap  int      // 容量（底層配列の要素数）
}
```

```go
s := make([]int, 3, 5)
// ヘッダ: Data=0x... Len=3 Cap=5
// 底層配列: [0, 0, 0, _, _]（最初の3要素がアクセス可能）
```

### スライス生成の種類

```go
// 1. make（長さと容量を指定）
s1 := make([]int, 3, 5)  // len=3, cap=5

// 2. リテラル（len==capになる）
s2 := []int{1, 2, 3}     // len=3, cap=3

// 3. スライス式（既存配列/スライスから）
arr := [5]int{1, 2, 3, 4, 5}
s3 := arr[1:3]           // len=2, cap=4（arr[1]から末尾まで）
```

### スライス式の詳細

```go
a := []int{0, 1, 2, 3, 4, 5}

// 基本形: a[low:high]
b := a[1:4]  // [1, 2, 3]  len=3, cap=5

// low省略（0から開始）
c := a[:3]   // [0, 1, 2]  len=3, cap=6

// high省略（末尾まで）
d := a[2:]   // [2, 3, 4, 5]  len=4, cap=4

// 完全形: a[low:high:max]（容量も制限）
e := a[1:3:4]  // [1, 2]  len=2, cap=3
```

### 成長戦略とメモリ再割当て

`append`で容量不足になると**新しい底層配列を割り当て**:

```go
s := make([]int, 0, 2)
fmt.Printf("len=%d cap=%d\n", len(s), cap(s))  // len=0 cap=2

s = append(s, 1)
fmt.Printf("len=%d cap=%d\n", len(s), cap(s))  // len=1 cap=2

s = append(s, 2)
fmt.Printf("len=%d cap=%d\n", len(s), cap(s))  // len=2 cap=2

s = append(s, 3)
// 容量不足 → 新しい配列を割り当て（通常は約2倍）
fmt.Printf("len=%d cap=%d\n", len(s), cap(s))  // len=3 cap=4
```

**成長戦略**（Go 1.18以降）:
- 容量 < 256: 約2倍に成長
- 容量 ≥ 256: 約1.25倍に成長（メモリ使用量を抑制）

### 共有底層配列の注意点

複数のスライスが同じ底層配列を共有する場合、**一方の変更が他方に影響**:

```go
a := []int{1, 2, 3, 4, 5}
b := a[1:3]  // [2, 3]
c := a[2:5]  // [3, 4, 5]

b[1] = 999   // a[2]を変更

fmt.Println(a)  // [1, 2, 999, 4, 5]
fmt.Println(b)  // [2, 999]
fmt.Println(c)  // [999, 4, 5]（cも影響を受ける！）
```

**独立したスライスを作成（copyを使用）**:

```go
a := []int{1, 2, 3, 4, 5}
b := make([]int, len(a))
copy(b, a)    // 新しい底層配列にコピー

b[0] = 100
fmt.Println(a)  // [1, 2, 3, 4, 5]（影響なし）
fmt.Println(b)  // [100, 2, 3, 4, 5]
```

### メモリリーク防止

大きなスライスの一部だけを保持すると、**底層配列全体がGCされない**:

```go
// ❌ メモリリーク例
func getFirstTwo(data []int) []int {
    return data[:2]  // 底層配列全体への参照を保持
}

func main() {
    largeSlice := make([]int, 1000000)
    subset := getFirstTwo(largeSlice)
    // subsetは2要素だけ使用しているが、1000000要素の配列がGCされない！
    _ = subset
}
```

**✅ 修正版（独立したスライスを作成）**:

```go
func getFirstTwo(data []int) []int {
    subset := make([]int, 2)
    copy(subset, data[:2])
    return subset  // 元の大きな配列は解放可能
}
```

## マップの内部実装

### ハッシュテーブル基盤

マップはハッシュテーブルとして実装:

```go
// 内部構造（簡略化）
type hmap struct {
    count     int       // 要素数
    B         uint8     // バケット数 = 2^B
    buckets   uintptr   // バケット配列へのポインタ
    // ... その他のフィールド
}
```

### バケット構造

各バケットは**最大8つのkey-valueペア**を保持:

```
バケット0: [key1, key2, key3, ..., key8]
           [val1, val2, val3, ..., val8]
バケット1: [...]
バケット2: [...]
...
```

ハッシュ衝突が多い場合、オーバーフローバケットに連結されます。

### 成長戦略

マップが一定の負荷率（約6.5）を超えると**リハッシュ**が発生:

```go
m := make(map[string]int)

// 要素を大量追加
for i := 0; i < 1000; i++ {
    m[fmt.Sprintf("key%d", i)] = i
}
// 内部で複数回のリハッシュが発生（バケット数が倍増）
```

**事前容量指定でリハッシュを削減**:

```go
// 1000要素を追加する予定
m := make(map[string]int, 1000)
```

### イテレーション順序の非決定性

マップのイテレーション順序は**意図的にランダム化**されています:

```go
m := map[string]int{"a": 1, "b": 2, "c": 3}

for k, v := range m {
    fmt.Println(k, v)
}
// 出力順序は実行ごとに異なる可能性あり
```

**理由**: 順序依存のバグを防ぐため。

**順序が必要な場合**:

```go
m := map[string]int{"c": 3, "a": 1, "b": 2}

// キーをソート
keys := make([]string, 0, len(m))
for k := range m {
    keys = append(keys, k)
}
sort.Strings(keys)

// ソート順でイテレーション
for _, k := range keys {
    fmt.Println(k, m[k])
}
// 出力: a 1, b 2, c 3（常にアルファベット順）
```

### マップはポインタセマンティクス

マップは**参照型**（代入やパラメータ渡しで共有される）:

```go
m1 := map[string]int{"a": 1}
m2 := m1       // 同じマップを指す

m2["b"] = 2
fmt.Println(m1)  // map[a:1 b:2]（m1も変更される）
```

## 構造体のメモリレイアウト

### パディングとアラインメント

CPUは特定のメモリアドレス境界（アラインメント）でデータを読むのが効率的です。
コンパイラは自動的に**パディング**（未使用領域）を挿入します。

```go
type Unoptimized struct {
    a bool    // 1バイト
    // [padding: 3バイト]
    b int32   // 4バイト
    // [padding: 0バイト]
    c bool    // 1バイト
    // [padding: 7バイト]
    d int64   // 8バイト
}
// 合計: 24バイト
```

**unsafe.Sizeofで確認**:

```go
import "unsafe"

fmt.Println(unsafe.Sizeof(Unoptimized{}))  // 24
```

### フィールド順序最適化

フィールドを大きい順に並べるとパディングを削減できます:

```go
type Optimized struct {
    d int64   // 8バイト
    // [padding: 0バイト]
    b int32   // 4バイト
    a bool    // 1バイト
    c bool    // 1バイト
    // [padding: 2バイト]
}
// 合計: 16バイト（8バイト削減！）
```

**パディング可視化ツール**:

```go
import "unsafe"

func printStructLayout() {
    var u Unoptimized
    fmt.Printf("Unoptimized: size=%d\n", unsafe.Sizeof(u))
    fmt.Printf("  a offset=%d size=%d\n", unsafe.Offsetof(u.a), unsafe.Sizeof(u.a))
    fmt.Printf("  b offset=%d size=%d\n", unsafe.Offsetof(u.b), unsafe.Sizeof(u.b))
    fmt.Printf("  c offset=%d size=%d\n", unsafe.Offsetof(u.c), unsafe.Sizeof(u.c))
    fmt.Printf("  d offset=%d size=%d\n", unsafe.Offsetof(u.d), unsafe.Sizeof(u.d))
}
```

## JSONエンコーディングの内部

### リフレクション依存

`encoding/json`は**リフレクション**を使用して構造体を走査:

```go
type User struct {
    Name string `json:"name"`
    Age  int    `json:"age"`
}

u := User{Name: "Alice", Age: 30}
data, _ := json.Marshal(u)
// 内部でreflect.ValueOf(u)を使用してフィールドを取得
```

### 構造体フィールドタグ

タグで動作をカスタマイズ:

```go
type Product struct {
    ID       int    `json:"id"`
    Name     string `json:"name"`
    Price    float64 `json:"price,omitempty"`  // ゼロ値を省略
    Internal string `json:"-"`                 // エンコードしない
}
```

### Decoder/Encoderのストリーミング

大きなJSONファイルには`json.Decoder`/`json.Encoder`を使用:

```go
// ストリーミングデコード
file, _ := os.Open("data.json")
defer file.Close()

decoder := json.NewDecoder(file)
var users []User
for decoder.More() {
    var u User
    if err := decoder.Decode(&u); err != nil {
        log.Fatal(err)
    }
    users = append(users, u)
}
```

**利点**: 全体をメモリに読み込まない（メモリ効率的）。

## ベストプラクティス

### スライス

1. **事前容量指定**: 要素数が分かっている場合は`make([]T, 0, n)`
2. **copyで独立化**: 共有底層配列の問題を避ける
3. **メモリリーク注意**: 大きなスライスの一部を保持する場合はコピー
4. **nil vs 空スライス**: `var s []int`（nil）と`s := []int{}`（空）は異なる

### マップ

1. **事前容量指定**: `make(map[K]V, n)`でリハッシュを削減
2. **順序依存禁止**: イテレーション順序に依存しない
3. **存在チェック**: `v, ok := m[key]`の2値形式を使用
4. **並行アクセス**: `sync.RWMutex`または`sync.Map`で保護

### 構造体

1. **フィールド順序**: 大きいフィールドから並べる（パディング削減）
2. **ホットパス最適化**: 頻繁にアクセスするフィールドを先頭に
3. **キャッシュライン**: 64バイトを意識（CPU L1キャッシュライン）

### JSON

1. **大きなデータ**: `json.Decoder`/`json.Encoder`を使用
2. **パフォーマンス重視**: `easyjson`や`jsoniter`などの高速ライブラリを検討
3. **タグ活用**: `omitempty`、`-`で最適化

---

**関連ドキュメント**:
- [TYPE-SYSTEM.md](./TYPE-SYSTEM.md) - 基本型のメモリ表現
- [INTERFACE-INTERNALS.md](./INTERFACE-INTERNALS.md) - interface値の内部構造
- [LOW-LEVEL.md](./LOW-LEVEL.md) - unsafe.Sizeof/Offsetofによる詳細検査
