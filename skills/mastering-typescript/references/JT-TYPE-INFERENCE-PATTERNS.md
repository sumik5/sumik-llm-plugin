# 型推論メカニズム詳解（実践TypeScript 第3章）

TypeScriptの推論エンジンがどのように型を決定するかのメカニズム解説。
「いつ明示すべきか」のガイドではなく、「エンジンがどう動くか」に焦点を当てる。

---

## 1. Widening Literal Types

### const vs let の推論差異

| 宣言 | 推論結果 | 理由 |
|------|---------|------|
| `let x = 0` | `number` | 再代入可能 → プリミティブ型に拡張 |
| `const x = 0` | `0` (Literal) | 再代入不可 → 値を型として固定 |
| `const x: 0 = 0` | `0` (Non-Widening) | 明示アノテーション → Wideningしない |
| `const x = 0 as 0` | `0` (Non-Widening) | 型アサーション → Wideningしない |

### Wideningが発生する条件

```typescript
const wideningZero = 0        // const wideningZero: 0  ← Widening Literal
const nonWideningZero: 0 = 0  // const nonWideningZero: 0 ← Non-Widening
const asNonWideningZero = 0 as 0 // const asNonWideningZero: 0 ← Non-Widening

// ❌ Widening発生: constのLiteral Typesが再代入可能変数へ代入されると拡張される
let zeroA = wideningZero      // let zeroA: number（0型 → number型に拡張！）

// ✅ Widening防止: 明示的型付与はWideningしない
let zeroB = nonWideningZero   // let zeroB: 0
let zeroC = asNonWideningZero // let zeroC: 0
```

### Widening防止の3パターン

```typescript
// パターン1: 型アノテーション
const a: 'value' = 'value'   // const a: 'value' → let変数に代入してもWideningしない

// パターン2: 型アサーション (as)
const b = 'value' as 'value' // const b: 'value'

// パターン3: as const（オブジェクト/配列全体に適用）
const c = { x: 0, y: 'hello' } as const
// const c: { readonly x: 0; readonly y: 'hello' }
```

---

## 2. Array / Tuple 推論

### Array推論のルール

```typescript
// ✅ 単一型 → T[]
const a1 = [true, false]      // boolean[]

// ✅ 混合型 → Union[]
const a2 = [0, 1, '2']       // (string | number)[]
const a3 = [false, 1, '2']   // (string | number | boolean)[]

// ✅ asアサーションで要素型を固定
const a4 = [0 as 0, 1 as 1]  // (0 | 1)[]
a4.push(2) // ❌ Error! (0 | 1)型のみ許可

// ✅ 型アノテーション変数から推論
const zero: 0 = 0
const one: 1 = 1
const a5 = [zero, one]       // (0 | 1)[]
```

### Tuple推論（asアサーション必須）

```typescript
// ❌ 普通の配列宣言ではTuple型にならない
const t0 = [false, 1]        // (boolean | number)[] ← Tupleではない

// ✅ asでTuple型を明示
const t1 = [false, 1] as [boolean, number]
const v0 = t1[0]  // boolean
const v1 = t1[1]  // number
const v2 = t1[2]  // ❌ Error! index範囲外

// Tupleのpushはindex内型のUnionを受け入れる
const t2 = [false, 1, '2'] as [boolean, number, string]
t2.push(false)  // ✅ OK (boolean | number | string)
t2.push(0)      // ✅ OK
t2.push(null)   // ❌ Error!
```

### lib由来のArray型推論

```typescript
let list = ['this', 'is', 'test']  // string[]
// mapのコールバック引数はstring型に推論される
list.map(item => item.toUpperCase())  // item: string（アノテーション不要）

// reduceも同様
list.reduce((prev, current) => `${prev} ${current}`)  // prev: string, current: string

// target: esnext では flat()も型推論される
const nested = [['a', 'b'], ['c']]  // string[][]
const flat = nested.flat()           // string[]
```

---

## 3. Object推論

```typescript
// constオブジェクトのプロパティはLiteral Typesにならない（再代入可能なため）
const obj = { foo: false, bar: 1, baz: '2' }
// 推論結果: { foo: boolean, bar: number, baz: string }

obj['foo'] = true  // ✅ OK
obj['foo'] = 0     // ❌ Error! (boolean型に非互換)

// ✅ Literal Typesを保持するにはasアサーション
const obj2 = { foo: false as false, bar: 1 as 1 }
obj2['foo'] = true  // ❌ Error! (false型のみ許可)

// ✅ as constで全プロパティをreadonlyなLiteral Typesに
const obj3 = { foo: false, bar: 1 } as const
// { readonly foo: false; readonly bar: 1 }
```

---

## 4. 関数戻り型推論

### 暗黙推論のパターン

```typescript
// 単一型 → そのまま推論
function getPriceLabel(amount: number, tax: number) {
  return `¥${amount * tax}`
}
// 推論結果: function getPriceLabel(...): string

// 戻り値なし → void
function log(message: string) { console.log(message) }
// 推論結果: function log(...): void

// 条件分岐 → Union Types
function getScore(score: number) {
  if (score < 0 || score > 100) return null
  return score
}
// 推論結果: function getScore(...): number | null

// switch全分岐 → Literal Union Types
function getScoreAmount(score: 'A' | 'B' | 'C') {
  switch(score) {
    case 'A': return 100
    case 'B': return 60
    case 'C': return 30
  }
}
// 推論結果: function getScoreAmount(...): 100 | 60 | 30
```

### 明示的戻り型アノテーションの効果

```typescript
// ✅ 戻り型アノテーションでバグを検出
function getStringValue(value: number, prefix?: string): string {
  if (prefix === undefined) return value  // ❌ Error! number型はstring型に非互換
  return `${prefix} ${value}`
}
```

---

## 5. Promise型推論

### 型が失われるケース

```typescript
// ❌ resolve引数の型が不明 → Promise<{}> に推論される
function wait(duration: number) {
  return new Promise(resolve => {
    setTimeout(() => resolve(`${duration}ms passed`), duration)
  })
}
// 推論結果: function wait(...): Promise<{}>
wait(1000).then(res => {})  // res: {} ← string型が失われている
```

### resolve型を明示する2パターン

```typescript
// パターン1: 関数戻り型アノテーション
function wait(duration: number): Promise<string> {
  return new Promise(resolve => {
    setTimeout(() => resolve(`${duration}ms passed`), duration)
  })
}

// パターン2: Promiseインスタンスに型パラメータ
function wait(duration: number) {
  return new Promise<string>(resolve => {  // ← <string>を付与
    setTimeout(() => resolve(`${duration}ms passed`), duration)
  })
}
wait(1000).then(res => {})  // res: string ✅
```

### async/await推論

```typescript
async function queue() {
  const message = await wait(1000)  // const message: string（Promiseがunwrapされる）
  return message
}
// 推論結果: function queue(): Promise<string>（async関数は常にPromiseを返す）
```

### Promise.all / Promise.race の型推論差異

| メソッド | 推論結果 | 理由 |
|---------|---------|------|
| `Promise.all([p1, p2, p3])` | `Promise<[T1, T2, T3]>` | 全Promise成功 → Tuple型 |
| `Promise.race([p1, p2, p3])` | `Promise<T1 \| T2 \| T3>` | 最初の1つ → Union型 |

```typescript
function waitThenString(d: number) { return new Promise<string>(resolve => resolve('')) }
function waitThenNumber(d: number) { return new Promise<number>(resolve => resolve(0)) }

// ✅ Promise.all → Tuple型
async function main() {
  const [a, b, c] = await Promise.all([
    waitThenString(10),   // string
    waitThenNumber(100),  // number
    waitThenString(1000)  // string
  ])
  // a: string, b: number, c: string

  const result = await Promise.race([waitThenString(10), waitThenNumber(100)])
  // result: string | number
}
```

---

## 6. JSON型推論

```typescript
// tsconfig.json 設定が必要
// "resolveJsonModule": true, "esModuleInterop": true

// users.json をインポート → 構造に基づいて自動推論
import UsersJson from './users.json'
type Users = typeof UsersJson
// Users型はJSONの構造と完全一致（手動でinterfaceを書く必要なし）

// 個別プロパティも型安全にアクセス
const firstName = UsersJson[0].profile.name.first  // string型
const age = UsersJson[0].profile.age               // number型
```

---

## 7. import / dynamic import推論

### 静的import推論

```typescript
// test.ts（エクスポート元）
export const value = 10        // Literal Types: 10
export const label = 'label'   // Literal Types: 'label'
export function returnFalse() { return false }

// index.ts（インポート先）— import構文のみ型推論が有効（require構文は不可）
import { value, label, returnFalse } from './test'
const v1 = value        // const v1: 10
const v2 = label        // const v2: 'label'
const v3 = returnFalse  // const v3: () => boolean
```

### dynamic import推論

```typescript
// dynamic importはPromiseを返すため、awaitまたは.thenで型推論が適用される
import('./test').then(module => {
  const amount = module.value  // const amount: 10
})

async function main() {
  const { value } = await import('./test')
  const amount = value  // const amount: 10
}
```

---

## まとめ: 推論エンジンの動作原則

| 状況 | 推論の挙動 |
|------|-----------|
| `let` + プリミティブ | プリミティブ型（`string`, `number`等） |
| `const` + プリミティブ | Widening Literal Types（`"foo"`, `0`等） |
| `const` + 型アノテーション/`as` | Non-Widening Literal Types（Wideningしない） |
| オブジェクトプロパティ | プリミティブ型（`const`でもLiteral Typesにならない） |
| `as const` | readonly + Non-Widening Literal Types |
| `Promise`（型パラメータなし） | `Promise<{}>` |
| `async`関数 | 戻り値を`Promise<T>`でラップ |
| `Promise.all` | `Promise<[T1, T2, ...]>` (Tuple) |
| `Promise.race` | `Promise<T1 \| T2 \| ...>` (Union) |
| JSON import + `typeof` | JSONの構造に完全一致した型 |
