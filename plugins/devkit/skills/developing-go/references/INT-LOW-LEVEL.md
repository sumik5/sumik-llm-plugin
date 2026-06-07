# 低レベルプログラミング

unsafe.Sizeof/Alignof/Offsetof、unsafe.Pointer、reflect.DeepEqual、cgo、GCとの相互作用、ベストプラクティスを解説します。

## unsafe.Sizeof/Alignof/Offsetof

### unsafe.Sizeof - メモリサイズ検査

型や値のメモリサイズ（バイト）を返します:

```go
import "unsafe"

fmt.Println(unsafe.Sizeof(int8(0)))    // 1
fmt.Println(unsafe.Sizeof(int16(0)))   // 2
fmt.Println(unsafe.Sizeof(int32(0)))   // 4
fmt.Println(unsafe.Sizeof(int64(0)))   // 8
fmt.Println(unsafe.Sizeof(int(0)))     // 8（64ビットシステム）

// 構造体
type Example struct {
    a int32
    b bool
    c float64
}
fmt.Println(unsafe.Sizeof(Example{}))  // 16（パディング含む）
```

**重要**: スライスやマップは**ヘッダのサイズ**のみ返します:

```go
s := make([]int, 1000)
fmt.Println(unsafe.Sizeof(s))  // 24（ヘッダ: pointer + len + cap）

m := make(map[string]int, 1000)
fmt.Println(unsafe.Sizeof(m))  // 8（ポインタのサイズ）
```

### unsafe.Alignof - アラインメント要件

型の推奨メモリアラインメント（バイト境界）を返します:

```go
fmt.Println(unsafe.Alignof(int8(0)))   // 1
fmt.Println(unsafe.Alignof(int16(0)))  // 2
fmt.Println(unsafe.Alignof(int32(0)))  // 4
fmt.Println(unsafe.Alignof(int64(0)))  // 8
fmt.Println(unsafe.Alignof(float64(0))) // 8
```

**CPUアーキテクチャ依存**: 異なるCPUでは異なる値になる可能性があります。

### unsafe.Offsetof - フィールドオフセット

構造体フィールドの開始位置（バイト）を返します:

```go
type Data struct {
    a bool    // offset 0
    b int32   // offset 4（3バイトのパディング後）
    c int8    // offset 8
    d int64   // offset 16（7バイトのパディング後）
}

var d Data
fmt.Println(unsafe.Offsetof(d.a))  // 0
fmt.Println(unsafe.Offsetof(d.b))  // 4
fmt.Println(unsafe.Offsetof(d.c))  // 8
fmt.Println(unsafe.Offsetof(d.d))  // 16
```

### パディング可視化ツール

```go
func printStructLayout(v interface{}) {
    val := reflect.ValueOf(v)
    typ := val.Type()

    fmt.Printf("Struct: %s (size=%d bytes)\n", typ.Name(), typ.Size())

    for i := 0; i < typ.NumField(); i++ {
        field := typ.Field(i)
        fmt.Printf("  %s: offset=%d size=%d align=%d\n",
            field.Name,
            field.Offset,
            field.Type.Size(),
            field.Type.Align(),
        )
    }
}

printStructLayout(Data{})
// 出力:
// Struct: Data (size=24 bytes)
//   a: offset=0 size=1 align=1
//   b: offset=4 size=4 align=4
//   c: offset=8 size=1 align=1
//   d: offset=16 size=8 align=8
```

## 構造体のパディング最適化

### フィールド順序の影響

**❌ 非最適化（24バイト）**:

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

**✅ 最適化（16バイト）**:

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

### 最適化ルール

1. **大きいフィールドから並べる**: int64 → int32 → int16 → int8/bool
2. **同じサイズをグループ化**: bool複数をまとめる
3. **ホットフィールドを先頭に**: 頻繁にアクセスするフィールド

### 実例: キャッシュライン最適化

CPUのL1キャッシュライン（通常64バイト）を意識:

```go
// ✅ ホットフィールド（頻繁にアクセス）を先頭に
type CacheOptimized struct {
    // ホットフィールド（64バイト以内）
    ID      uint64
    Counter uint64
    Flags   uint32
    Status  uint32

    // コールドフィールド
    Name        string
    Description string
    Metadata    map[string]string
}
```

## unsafe.Pointerの4つの合法パターン

### パターン1: *T1 → unsafe.Pointer → *T1

元の型に戻す（無害）:

```go
var x int = 42
p := unsafe.Pointer(&x)
y := (*int)(p)
fmt.Println(*y)  // 42
```

### パターン2: unsafe.Pointer → uintptr → unsafe.Pointer

ポインタ演算（注意が必要）:

```go
arr := [4]int{10, 20, 30, 40}
p := unsafe.Pointer(&arr[0])

// 次の要素へのポインタ
next := unsafe.Pointer(uintptr(p) + unsafe.Sizeof(arr[0]))
fmt.Println(*(*int)(next))  // 20
```

**重要**: `uintptr`はポインタとして扱われないため、GCが追跡しません。
**即座に変換**する必要があります:

```go
// ✅ 良い例（1行で変換）
next := unsafe.Pointer(uintptr(p) + unsafe.Sizeof(arr[0]))

// ❌ 悪い例（変数に保存）
offset := uintptr(p) + unsafe.Sizeof(arr[0])
// ... 他のコード（GCが発生する可能性）
next := unsafe.Pointer(offset)  // 危険！pが移動している可能性
```

### パターン3: unsafe.Pointer → uintptr（syscall専用）

syscallパッケージでのみ有効:

```go
syscall.Syscall(SYS_WRITE, uintptr(fd), uintptr(unsafe.Pointer(&buf[0])), uintptr(len(buf)))
```

### パターン4: reflect.Value.Pointer/UnsafeAddr

リフレクションとの組み合わせ:

```go
var x int = 42
v := reflect.ValueOf(&x)
p := unsafe.Pointer(v.Pointer())
y := (*int)(p)
fmt.Println(*y)  // 42
```

## reflect.DeepEqual

### 深い等価性比較

`reflect.DeepEqual`は再帰的に値を比較:

```go
import "reflect"

a := []int{1, 2, 3}
b := []int{1, 2, 3}
fmt.Println(reflect.DeepEqual(a, b))  // true

c := []int{1, 2, 4}
fmt.Println(reflect.DeepEqual(a, c))  // false
```

### 構造体の比較

```go
type Person struct {
    Name string
    Age  int
}

p1 := Person{"Alice", 30}
p2 := Person{"Alice", 30}
p3 := Person{"Bob", 25}

fmt.Println(reflect.DeepEqual(p1, p2))  // true
fmt.Println(reflect.DeepEqual(p1, p3))  // false
```

### ポインタとnilの扱い

```go
var a *int = nil
var b *int = nil
fmt.Println(reflect.DeepEqual(a, b))  // true

x := 42
c := &x
d := &x
fmt.Println(reflect.DeepEqual(c, d))  // true（値が同じ）
```

### マップの順序非依存比較

```go
m1 := map[string]int{"a": 1, "b": 2}
m2 := map[string]int{"b": 2, "a": 1}
fmt.Println(reflect.DeepEqual(m1, m2))  // true
```

### 制約と注意点

1. **パフォーマンス**: リフレクション使用のため遅い
2. **循環参照**: 無限ループの可能性（未対応）
3. **関数比較**: 関数は常にfalse（比較不可）

```go
f1 := func() {}
f2 := func() {}
fmt.Println(reflect.DeepEqual(f1, f2))  // false
```

## cgoの基礎

### C関数呼び出し

```go
/*
#include <stdio.h>
#include <stdlib.h>

void printMessage(char* message) {
    printf("%s\n", message);
}
*/
import "C"
import "unsafe"

func main() {
    message := C.CString("Hello from Go!")
    defer C.free(unsafe.Pointer(message))
    C.printMessage(message)
}
```

**重要**: `C.CString`で確保したメモリは**手動でfree**が必要。

### #cgoディレクティブ

コンパイルフラグやリンクフラグを指定:

```go
/*
#cgo CFLAGS: -I/usr/local/include
#cgo LDFLAGS: -L/usr/local/lib -lmylib
#include <mylib.h>
*/
import "C"
```

### 型変換

```go
// Go → C
goInt := 42
cInt := C.int(goInt)

goFloat := 3.14
cFloat := C.double(goFloat)

// C → Go
cResult := C.someFunction()
goResult := int(cResult)
```

## cgoの応用

### C構造体操作

```go
/*
#include <stdlib.h>

typedef struct {
    int x;
    int y;
} Point;

Point* createPoint(int x, int y) {
    Point* p = (Point*)malloc(sizeof(Point));
    p->x = x;
    p->y = y;
    return p;
}

void freePoint(Point* p) {
    free(p);
}
*/
import "C"
import "unsafe"

func main() {
    p := C.createPoint(10, 20)
    defer C.freePoint(p)

    fmt.Printf("x=%d, y=%d\n", p.x, p.y)

    // フィールド変更
    p.x = 100
    fmt.Printf("x=%d, y=%d\n", p.x, p.y)
}
```

### コールバック関数

Go関数をCから呼び出す:

```go
/*
#include <stdlib.h>

typedef int (*callback_fn)(int);

int applyCallback(callback_fn cb, int value) {
    return cb(value);
}
*/
import "C"

//export doubleValue
func doubleValue(x C.int) C.int {
    return x * 2
}

func main() {
    result := C.applyCallback(C.callback_fn(C.doubleValue), 21)
    fmt.Println(int(result))  // 42
}
```

### メモリ管理（C.malloc/C.free）

```go
/*
#include <stdlib.h>
*/
import "C"
import "unsafe"

func allocateBuffer(size int) unsafe.Pointer {
    return C.malloc(C.size_t(size))
}

func freeBuffer(ptr unsafe.Pointer) {
    C.free(ptr)
}

func main() {
    buffer := allocateBuffer(1024)
    defer freeBuffer(buffer)

    // bufferを使用
}
```

## GCとの相互作用

### unsafeがGCに与える影響

1. **uintptrへの変換**: GCはuintptrをポインタとして追跡しない

```go
// ❌ 危険（GC後にpが無効になる可能性）
p := unsafe.Pointer(&x)
addr := uintptr(p)
// ... 時間経過（GCが発生）
ptr := unsafe.Pointer(addr)  // 無効なポインタの可能性
```

2. **Pointer → uintptr → Pointer変換**: 即座に行う

```go
// ✅ 安全（1文で完結）
ptr := unsafe.Pointer(uintptr(p) + offset)
```

### cgoとGCの停止

cgo呼び出し中はGCが**一時停止**:

```go
// C関数呼び出し中、Goのgoroutineは停止しない
result := C.longRunningFunction()
```

**影響**: 長時間のC関数呼び出しはレイテンシを増加させる可能性。

### GCとCメモリ

C側で確保したメモリは**GCの対象外**:

```go
// ❌ メモリリーク
for i := 0; i < 1000; i++ {
    ptr := C.malloc(1024)
    // C.free呼び出し忘れ
}

// ✅ 正しい管理
for i := 0; i < 1000; i++ {
    ptr := C.malloc(1024)
    defer C.free(ptr)  // または明示的にC.free(ptr)
}
```

## 低レベルプログラミングのベストプラクティス

### 1. 安全な代替手段を優先

unsafeやcgoを使う前に:
- 標準ライブラリで実現可能か
- 純粋なGoで実装可能か
- サードパーティライブラリが存在するか

### 2. カプセル化

unsafe操作を**パッケージ内に閉じ込める**:

```go
package safebuffer

import "unsafe"

type Buffer struct {
    data unsafe.Pointer
    len  int
}

// 公開API（安全）
func (b *Buffer) Read() []byte {
    // 内部でunsafe使用
}

// 非公開関数（unsafe使用）
func (b *Buffer) unsafeAccess() {
    // ...
}
```

### 3. ドキュメント必須

unsafeを使う理由を明記:

```go
// alignedAlloc allocates memory aligned to 64-byte boundaries
// for optimal cache performance. Uses unsafe.Pointer because
// the standard allocator does not guarantee alignment.
func alignedAlloc(size int) unsafe.Pointer {
    // ...
}
```

### 4. ベンチマーク必須

unsafeによる最適化は**必ず測定**:

```go
func BenchmarkSafe(b *testing.B) {
    for i := 0; i < b.N; i++ {
        // 安全な実装
    }
}

func BenchmarkUnsafe(b *testing.B) {
    for i := 0; i < b.N; i++ {
        // unsafe実装
    }
}
```

### 5. クロスプラットフォームテスト

unsafeとcgoは**プラットフォーム依存**:
- 複数のOS（Linux、macOS、Windows）
- 複数のアーキテクチャ（amd64、arm64）

### 6. ビルドタグの活用

プラットフォーム別実装:

```go
// +build linux

package mylib

import "unsafe"

func platformSpecific() {
    // Linux固有の実装
}
```

```go
// +build windows

package mylib

func platformSpecific() {
    // Windows固有の実装（unsafeを使わない）
}
```

### 7. エラー処理徹底

cgoでのエラー:

```go
result := C.someFunction()
if result == C.NULL {
    return errors.New("C関数がエラーを返しました")
}
```

### 8. メモリリーク監視

```go
import _ "net/http/pprof"

// プロファイリングエンドポイント有効化
go func() {
    log.Println(http.ListenAndServe("localhost:6060", nil))
}()

// http://localhost:6060/debug/pprof/heap でメモリ使用量確認
```

## 使用場面の判断基準

### unsafeを使うべき場面

- **パフォーマンスクリティカル**: プロファイリングで証明済み
- **外部システムとの連携**: バイナリプロトコル、共有メモリ
- **低レベルライブラリ**: カスタムアロケータ、シリアライザ

### cgoを使うべき場面

- **既存Cライブラリ活用**: OpenSSL、libjpeg等
- **システムAPI呼び出し**: OS固有機能
- **レガシーコードとの統合**

### 避けるべき場面

- **ビジネスロジック**: unsafeやcgoを含めない
- **Webアプリケーション**: 純粋なGoで十分
- **早すぎる最適化**: まずプロファイリング

## チェックリスト

unsafe/cgoを使用する前に:
- [ ] 安全な代替手段を調査済み
- [ ] ベンチマークで性能改善を証明
- [ ] コードレビュー実施
- [ ] ドキュメント記述（理由と制約）
- [ ] 徹底的なテスト（エッジケース含む）
- [ ] クロスプラットフォームテスト
- [ ] メモリリーク監視設定

---

**関連ドキュメント**:
- [COMPOSITE-INTERNALS.md](./COMPOSITE-INTERNALS.md) - 構造体のメモリレイアウト
- [REFLECTION.md](./REFLECTION.md) - unsafeとreflectの組み合わせ
- [TYPE-SYSTEM.md](./TYPE-SYSTEM.md) - 基本型のメモリサイズ
