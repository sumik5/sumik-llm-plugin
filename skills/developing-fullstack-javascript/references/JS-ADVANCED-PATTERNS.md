# JS-ADVANCED-PATTERNS.md

JavaScript のメタプログラミング・イテレータ・ジェネレータに関するリファレンス。
Proxy/Reflect によるオブジェクト操作の横取り、Symbol を使ったカスタマイズ、
遅延評価を実現するジェネレータパターンを体系的にまとめる。

---

## 1. Symbol

### 1.1 基本

Symbol は **プリミティブだが String でない** オブジェクトキーを作る唯一の手段。

```javascript
const sym = Symbol('label')        // 毎回ユニーク
const sym2 = Symbol('label')
sym === sym2                       // false（同じラベルでも別物）

// キーとして使うには角括弧が必須（ドット記法不可）
const obj = { [sym]: 'value' }
obj[sym] = 'updated'
```

| 用途 | 方法 |
|------|------|
| 単一領域での一意キー | `Symbol('description')` |
| 複数 iframe / Worker 間での共有 | `Symbol.for('com.example.key')` |
| 型確認 | `typeof sym === 'symbol'` |

> **注意**: `new Symbol()` は TypeError。`Symbol()` を直接呼び出す。

Symbol キーを持つプロパティは `for...in` / `Object.keys()` で列挙されない。
意図しない外部アクセスを避ける擬似プライベートキーとして利用できる。

---

### 1.2 Well-known Symbols（周知のシンボル）

`Symbol` クラスが持つ定数は、JavaScript API の**カスタマイズフック**。

| シンボル | カスタマイズできる振る舞い |
|---------|-------------------------|
| `Symbol.iterator` | `for...of`・スプレッド展開 |
| `Symbol.asyncIterator` | `for await...of` |
| `Symbol.toStringTag` | `Object.prototype.toString()` の出力 |
| `Symbol.toPrimitive` | 基本型への変換（`+`・テンプレートリテラル等） |
| `Symbol.hasInstance` | `instanceof` の振る舞い |
| `Symbol.species` | `map`/`filter` 等が返すコレクションのコンストラクタ |
| `Symbol.isConcatSpreadable` | `Array.concat` での展開制御 |

#### Symbol.toStringTag の実装例

```javascript
class Point {
  constructor(x, y) {
    this.x = x
    this.y = y
  }
  get [Symbol.toStringTag]() {
    return `Point(${this.x}, ${this.y})`
  }
}

const p = new Point(3, 4)
Object.prototype.toString.call(p) // '[object Point(3, 4)]'
```

#### Symbol.toPrimitive — ヒントに応じた変換

```javascript
class Percent {
  constructor(rate) { this.rate = rate }

  [Symbol.toPrimitive](hint) {
    if (hint === 'number') return this.rate / 100
    return `${this.rate}%`        // 'string' / 'default'
  }
}

const tax = new Percent(10)
+tax                              // 0.1
`税率: ${tax}`                   // '税率: 10%'
```

`hint` の値は `'number'` / `'string'` / `'default'`（`+` 演算子や `==` 比較）。

---

## 2. プロパティ属性

### 2.1 3つの属性

| 属性 | 意味 | デフォルト（リテラル定義時）|
|------|------|--------------------------|
| `writable` | 値を変更できるか | `true` |
| `enumerable` | `for...in` / `Object.keys()` に現れるか | `true`（Symbol キーは `false`）|
| `configurable` | 削除・属性変更ができるか | `true` |

> **落とし穴**: `strict` モードでのみ `writable: false` / `configurable: false` 違反時に例外が出る。非 strict では黙って無視される。

### 2.2 Object.defineProperty

```javascript
const james = { name: 'James Bond' }

Object.defineProperty(james, 'id', {
  value: '007',
  writable: false,
  enumerable: true,
  configurable: false   // 以後削除・再設定不可
})

// ゲッター / セッターの定義
Object.defineProperty(james, 'lastName', {
  get() { return this.name.split(' ')[1] },
  set(last) { this.name = this.name.split(' ')[0] + ' ' + last }
  // ※ this を使うのでアロー関数は不可
})
```

`Object.defineProperties(obj, { key1: descriptor1, ... })` で複数一括定義可能。

### 2.3 プロパティの列挙

```javascript
// 独自プロパティのディスクリプタを取得（spy に有用）
Object.getOwnPropertyDescriptor(obj, 'name')
Object.getOwnPropertyDescriptors(obj)   // 全プロパティ（Symbol 含む）

// 列挙可能な独自プロパティのみ
Object.keys(obj)                         // 文字列キー配列
Object.values(obj)                       // 値配列
Object.entries(obj)                      // [key, value] ペア配列

// 列挙可能かどうかに関わらず全キー
Object.getOwnPropertyNames(obj)          // 文字列キー
Object.getOwnPropertySymbols(obj)        // Symbol キー
```

### 2.4 プロパティの存在チェック

```javascript
// in 演算子: プロトタイプチェーンも含む（undefined 値でも true）
'partner' in obj

// 独自プロパティのみ
Object.hasOwn(obj, 'key')                // ES2022 推奨
obj.hasOwnProperty('key')               // 古典的（オーバーライド可能で危険）

// 列挙可能かチェック
obj.propertyIsEnumerable('key')
```

---

## 3. オブジェクトの保護

```javascript
// 3段階の保護（強度の昇順）
Object.preventExtensions(obj)   // 新規プロパティ追加禁止 + prototype 変更禁止
Object.seal(obj)                // さらに: 削除禁止・属性変更禁止
Object.freeze(obj)              // さらに: 値変更禁止

// チェック
Object.isExtensible(obj)
Object.isSealed(obj)
Object.isFrozen(obj)
```

> **重要**: `Object.freeze()` は **浅い凍結（shallow freeze）**。
> ネストしたオブジェクトのプロパティは凍結されない。

```javascript
const config = Object.freeze({ db: { host: 'localhost' } })
config.db.host = 'production'   // OK — config.db 自体は凍結されていない
```

完全な不変性が必要なら再帰的に凍結するか、`structuredClone` 後に凍結する。

---

## 4. オブジェクトクローン

### 4.1 方法の比較

| 方法 | プロトタイプ | 全属性 | 深いコピー | 循環参照 |
|------|------------|--------|-----------|---------|
| `{ ...obj }` | ❌ | ❌（列挙可能のみ）| ❌ | ❌ |
| `Object.assign({}, obj)` | ❌ | ❌ | ❌ | ❌ |
| `Object.create(proto, descriptors)` | ✅ | ✅ | ❌ | ❌ |
| `structuredClone(obj)` | ❌ | △ | ✅ | ✅ |

### 4.2 structuredClone（モダン推奨）

```javascript
const original = { a: 1, nested: { b: 2 } }
const deep = structuredClone(original)
// 深いコピー・循環参照対応・ネイティブ実装（Node 17+ / 全モダンブラウザ）
```

**`structuredClone` の制限**: 関数・クラスインスタンスのプロトタイプ・Symbol キー・DOM ノードは複製できない。

### 4.3 完全クローン（プロトタイプ + 全属性保持）

```javascript
const deepClone = (obj, registry = new Map()) => {
  if (typeof obj !== 'object' || obj === null || Object.isFrozen(obj)) return obj
  if (registry.has(obj)) return registry.get(obj)

  const props = Object.getOwnPropertyDescriptors(obj)
  const result = Array.isArray(obj)
    ? Array.from(obj)
    : Object.create(Object.getPrototypeOf(obj), props)

  registry.set(obj, result)
  for (const key of Reflect.ownKeys(props)) {
    result[key] = deepClone(obj[key], registry)
  }
  return result
}
```

`Map` によるレジストリが循環参照を防ぎ、`Array.isArray` チェックで配列の型を保持する。

---

## 5. Proxy / Reflect

### 5.1 Proxy の構造

```javascript
const proxy = new Proxy(target, handler)
```

- **target**: 操作を制御したい対象オブジェクト
- **handler**: トラップ関数を持つオブジェクト

### 5.2 主要トラップ一覧

| トラップ | 横取りする操作 |
|---------|--------------|
| `get(target, key, receiver)` | `proxy.key` / `proxy[key]` |
| `set(target, key, value, receiver)` | `proxy.key = value` |
| `deleteProperty(target, key)` | `delete proxy.key` |
| `has(target, key)` | `key in proxy` |
| `getPrototypeOf(target)` | `Object.getPrototypeOf(proxy)` |
| `ownKeys(target)` | `Object.keys(proxy)` 等 |
| `getOwnPropertyDescriptor(target, key)` | `Object.getOwnPropertyDescriptor(proxy, key)` |
| `apply(target, thisArg, args)` | `proxy(...args)` |
| `construct(target, args, newTarget)` | `new proxy(args)` |

### 5.3 ロギング Proxy

```javascript
const createLoggingProxy = (target, name) => {
  const handler = {
    get(t, key, receiver) {
      const value = Reflect.get(t, key, receiver)
      console.log(`[${name}] get ${String(key)} → ${value}`)
      return value
    },
    set(t, key, value, receiver) {
      console.log(`[${name}] set ${String(key)} = ${value}`)
      return Reflect.set(t, key, value, receiver)
    }
  }
  return new Proxy(target, handler)
}

const user = createLoggingProxy({ name: 'Alice' }, 'user')
user.name = 'Bob'   // [user] set name = Bob
```

> **ベストプラクティス**: トラップ内のデフォルト動作には必ず `Reflect.<trapName>()` を使う。
> `target[key]` 直接アクセスは `receiver`（継承先）を正しく扱えない場合がある。

### 5.4 バリデーション Proxy

```javascript
const createValidated = (schema) => new Proxy({}, {
  set(target, key, value) {
    if (key in schema && !schema[key](value)) {
      throw new TypeError(`Invalid value for ${String(key)}: ${value}`)
    }
    return Reflect.set(target, key, value)
  }
})

const person = createValidated({
  age: v => typeof v === 'number' && v >= 0 && v <= 150
})

person.age = 25    // OK
person.age = -1    // TypeError
```

### 5.5 動的プロパティ Proxy

```javascript
const createRange = (start, end) => {
  const isIndex = key =>
    typeof key === 'string' && /^\d+$/.test(key) && parseInt(key) < end - start

  return new Proxy({}, {
    get(target, key, receiver) {
      return isIndex(key) ? start + parseInt(key) : Reflect.get(target, key, receiver)
    },
    has(target, key) {
      return isIndex(key) || Reflect.has(target, key)
    },
    getOwnPropertyDescriptor(target, key) {
      if (isIndex(key)) {
        return { value: start + Number(key), writable: false, enumerable: true, configurable: true }
      }
      return Reflect.getOwnPropertyDescriptor(target, key)
    },
    ownKeys(target) {
      const indices = Array.from({ length: end - start }, (_, i) => String(i))
      return [...Reflect.ownKeys(target), ...indices]
    }
  })
}
```

> **注意**: 不変条件（invariant）により、ターゲットに存在しないプロパティを `configurable: false` として報告するとエラーになる。動的プロパティは `configurable: true` が必要。

### 5.6 無効化可能 Proxy

```javascript
const { proxy, revoke } = Proxy.revocable(target, handler)
// proxy を信頼していないコードに渡す
revoke()   // 以後 proxy へのすべての操作が TypeError
```

### 5.7 Reflect のスタンドアロンな利用価値

```javascript
// delete の成否を真偽値で返す（delete 演算子は返さない）
Reflect.deleteProperty(obj, 'key')   // → true / false

// 定義の成否を真偽値で返す（Object.defineProperty は例外を投げる）
Reflect.defineProperty(obj, 'key', descriptor)

// apply の保証（f.apply は再定義されている可能性がある）
Reflect.apply(f, thisArg, args)      // Function.prototype.apply を確実に呼ぶ
```

---

## 6. イテレータ・イテラブルプロトコル

### 6.1 プロトコル定義

```
Iterable: { [Symbol.iterator](): Iterator }
Iterator: { next(): { value: any, done: boolean }, return?(): { done: true } }
```

### 6.2 イテラブルが使われる場面

```javascript
for (const v of iterable) { ... }           // for...of
[...iterable]                               // スプレッド
const [a, b, c] = iterable                  // 分割代入
Array.from(iterable)
new Set(iterable) / new Map(iterable)
yield* iterable                             // ジェネレータ内
```

### 6.3 カスタムイテラブルの実装

```javascript
class Range {
  constructor(start, end) {
    this.start = start
    this.end = end
  }

  [Symbol.iterator]() {
    let current = this.start
    const last = this.end
    return {
      next() {
        return current < last
          ? { value: current++ }           // done は省略可（false 扱い）
          : { done: true }                 // value は省略可（undefined 扱い）
      },
      return() {
        // リソース解放（break / return / throw での早期終了時に呼ばれる）
        return { done: true }
      }
    }
  }
}

for (const n of new Range(1, 5)) console.log(n)  // 1 2 3 4
```

---

## 7. ジェネレータ（function*）

### 7.1 基本構文

```javascript
function* rangeGen(start, end) {
  for (let i = start; i < end; i++) {
    yield i                    // 値を1つ生成してサスペンド
  }
}

const iter = rangeGen(10, 13)
iter.next()                   // { value: 10, done: false }
iter.next()                   // { value: 11, done: false }
iter.next()                   // { value: 12, done: false }
iter.next()                   // { value: undefined, done: true }

// イテラブルとして直接使用
[...rangeGen(1, 6)]           // [1, 2, 3, 4, 5]
```

ジェネレータ関数を呼び出しても**本文は実行されない**。`next()` で初めて動き始める。

### 7.2 クラス・オブジェクトのメソッドとして

```javascript
class InfiniteCounter {
  * [Symbol.iterator]() {       // ジェネレータメソッド
    let i = 0
    while (true) yield i++
  }
}

// アロー関数はジェネレータにできない
// const gen = () => { yield 1 }   // SyntaxError
```

### 7.3 yield* — 別のイテラブルへの委譲

```javascript
function* flatten(arr) {
  for (const item of arr) {
    if (Array.isArray(item)) {
      yield* flatten(item)     // 再帰的にフラット化
    } else {
      yield item
    }
  }
}

[...flatten([1, [2, [3, 4]], 5])]  // [1, 2, 3, 4, 5]
```

> **制限**: `yield` はジェネレータ関数のスコープ内のみ有効。
> 呼び出し先の関数内では使えない → `yield*` で委譲して解決。

`yield*` 式は、委譲したジェネレータの `return` 値をキャプチャできる:

```javascript
function* gen() {
  const count = yield* ['a', 'b', 'c']  // 配列の場合は undefined
  yield `done`
}
```

### 7.4 値を消費するジェネレータ（双方向通信）

```javascript
function* accumulator() {
  let sum = 0
  while (true) {
    const input = yield sum    // yield の戻り値が next(value) の引数
    if (input === null) break
    sum += input
  }
  return sum
}

const acc = accumulator()
acc.next()                     // キックオフ（最初の yield まで進める）
acc.next(10)                   // { value: 10, done: false }
acc.next(20)                   // { value: 30, done: false }
acc.next(null)                 // { value: 30, done: true }
```

`throw(error)` を呼ぶと、ペンディング中の `yield` 式でエラーが発生する:

```javascript
acc.throw(new Error('abort'))  // ジェネレータ内で try/catch していなければ伝播
```

> **現実的な用途**: 双方向ジェネレータは非同期処理の基盤概念（Promise の前身）。
> 通常の async/await が使える場面では async/await を優先すること。

---

## 8. 非同期イテレータ・ジェネレータ

### 8.1 非同期ジェネレータの宣言

```javascript
async function* loadPages(url) {
  let page = 0
  while (true) {
    const res = await fetch(`${url}?page=${++page}`)
    if (!res.ok) return                  // done: true
    yield await res.json()               // await してから yield
  }
}
```

`async function*` の組み合わせで、**非同期 + 遅延評価** を実現する。

### 8.2 for await...of

```javascript
// async 関数の内側で使用する
async function processAll(url) {
  for await (const page of loadPages(url)) {
    if (shouldStop(page)) break          // 早期終了でそれ以上フェッチしない
    process(page)
  }
}
```

> `for await...of` は普通のイテラブルにも使える（`for...of` と同じ動作）。
> 逆に非同期イテラブルを普通の `for...of` / スプレッドで使うことは**不可能**。

### 8.3 Symbol.asyncIterator でカスタム非同期イテラブル

```javascript
class TimedSequence {
  constructor(items, delay) {
    this.items = items
    this.delay = delay
  }

  async *[Symbol.asyncIterator]() {
    for (const item of this.items) {
      await new Promise(r => setTimeout(r, this.delay))
      yield item
    }
  }
}

for await (const v of new TimedSequence([1, 2, 3], 500)) {
  console.log(v)     // 0.5秒ごとに出力
}
```

---

## 9. 判断テーブル

### どのクローン手法を使うか

| 条件 | 推奨手法 |
|------|---------|
| 列挙可能プロパティのみ、プロトタイプ不要 | `{ ...obj }` |
| 深いコピー・循環参照あり、関数不要 | `structuredClone(obj)` |
| プロトタイプ + 全属性を保持したい | `Object.create(proto, descriptors)` |
| 関数・クラスインスタンスを含む深いコピー | カスタム `deepClone` 実装 |

### Proxy を使うべき場面

| 用途 | 適切か |
|------|-------|
| プロパティアクセスのロギング・監視 | ✅ |
| 実行時バリデーション | ✅ |
| リアクティビティ（Vue 3 内部等） | ✅ |
| 動的プロパティ（ORM 等） | ✅（不変条件に注意）|
| 単純な null チェック回避 | ❌（Optional chaining を使う）|
| パフォーマンスが最優先の場面 | ❌（Proxy はオーバーヘッドあり）|

### イテレータ vs ジェネレータ

| 状況 | 推奨 |
|------|------|
| 単純な値シーケンス | `function*` ジェネレータ（実装が容易）|
| 外部リソース（ファイル・DB等）を扱う | 手動イテレータ（`return()` で確実にクローズ）|
| 非同期データストリーム | `async function*` + `for await...of` |
| 無限シーケンス | `function*`（`while(true) yield ...`）|
