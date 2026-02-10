# 型について - TypeScript型階層と実践パターン

> TypeScript型システムの階層構造と、型エイリアス・合併型・交差型の効果的な使い方

## 目次

1. [型の定義と制約](#1-型の定義と制約)
2. [型の階層構造](#2-型の階層構造)
3. [リテラル型](#3-リテラル型)
4. [オブジェクト型の細かい制御](#4-オブジェクト型の細かい制御)
5. [型エイリアスとブロックスコープ](#5-型エイリアスとブロックスコープ)
6. [合併型と交差型](#6-合併型と交差型)
7. [配列とタプルの型推論](#7-配列とタプルの型推論)
8. [列挙型の使い分け](#8-列挙型の使い分け)
9. [まとめ](#9-まとめ)

---

## 1. 型の定義と制約

### 型とは何か

**型（type）**: 値と、それを使ってできる事柄の集まり

- `boolean`型: すべてのブール値と演算（`||`、`&&`、`!`）
- `number`型: すべての数値と演算（`+`、`-`、`*`、`/`、`.toFixed`等）
- `string`型: すべての文字列と演算（`+`、`.concat`、`.toUpperCase`等）

### 型による制約の議論

```typescript
function squareOf(n: number) {
  return n * n
}
squareOf(2)     // OK: 4
squareOf('z')   // エラー: 型 '"z"' を型 'number' に割り当て不可
```

**用語**:
- **制約（constraint）**: パラメーター`n`は`number`に制約されている
- **割り当て可能性（assignability）**: `2`は`number`に割り当て可能
- **境界（bound）**: `n`の上限は`number`

---

## 2. 型の階層構造

### TypeScriptの型階層

```
unknown (最上位)
  ├─ any (特殊: 型チェック無効化)
  ├─ object
  │   ├─ オブジェクトリテラル型 {a: string}
  │   ├─ Array<T>
  │   ├─ Function
  │   └─ Date, Map, Set...
  ├─ boolean
  │   ├─ true
  │   └─ false
  ├─ number
  │   ├─ 42
  │   └─ 3.14
  ├─ string
  │   ├─ "hello"
  │   └─ "world"
  ├─ symbol
  │   └─ unique symbol
  ├─ null
  ├─ undefined
  └─ void
never (最下位: ボトム型)
```

### unknown vs any vs never

| 型 | 位置 | 用途 | 操作可否 |
|----|------|------|---------|
| `unknown` | スーパータイプ | 型不明だが安全に絞り込む | 絞り込み後のみ |
| `any` | 特殊（型チェック無効） | 最終手段（避けるべき） | すべて許可 |
| `never` | ボトム型 | 戻らない関数、不可能な分岐 | なし |

```typescript
// unknown: 安全な型不明値
let a: unknown = 30
let c = a + 10              // エラー: unknown は操作不可
if (typeof a === 'number') {
  let d = a + 10            // OK: 絞り込み後
}

// never: 戻らない関数
function throwError(): never {
  throw TypeError('Always error')
}
```

---

## 3. リテラル型

### リテラル型とは

**リテラル型（literal type）**: ただ1つの値を表し、それ以外の値は受け入れない型

```typescript
let a = true                // boolean
var b = false               // boolean
const c = true              // true (リテラル型)
let d: boolean = true       // boolean
let e: true = true          // true (明示的リテラル型)
let f: true = false         // エラー: 型 'false' を型 'true' に割り当て不可
```

### 数値・文字列リテラル型

```typescript
// 数値リテラル型
const c = 5678              // 5678
let f: 26.218 = 26.218      // 26.218
let g: 26.218 = 10          // エラー: 型 '10' を型 '26.218' に割り当て不可

// 文字列リテラル型
const c = '!'               // '!'
let f: 'john' = 'john'      // 'john'
let g: 'john' = 'zoe'       // エラー: 型 '"zoe"' を型 '"john"' に割り当て不可
```

### unique symbol

```typescript
const e = Symbol('e')                // typeof e (unique symbol)
const f: unique symbol = Symbol('f') // typeof f
let g: unique symbol = Symbol('f')   // エラー: 'let' は unique symbol 不可

let h = e === e             // boolean
let i = e === f             // エラー: unique symbol 同士は常に不一致
```

**制約**: `unique symbol`は`const`変数のみ可能

---

## 4. オブジェクト型の細かい制御

### オプションプロパティとインデックスシグネチャ

```typescript
let a: {
  b: number                       // 必須プロパティ
  c?: string                      // オプションプロパティ
  [key: number]: boolean          // インデックスシグネチャ
}

a = {b: 1}                        // OK
a = {b: 1, c: undefined}          // OK
a = {b: 1, c: 'd'}                // OK
a = {b: 1, 10: true}              // OK
a = {b: 1, 10: true, 20: false}   // OK
a = {10: true}                    // エラー: 'b' が欠落
a = {b: 1, 33: 'red'}             // エラー: string は boolean に不可
```

**インデックスシグネチャ制約**:
- キー型は`number`または`string`のみ
- キー名は任意（`key`でなくてもよい）

### readonlyプロパティ

```typescript
let user: {
  readonly firstName: string
} = {
  firstName: 'abby'
}

user.firstName                    // string
user.firstName = 'abbey'          // エラー: readonly なので変更不可
```

### オブジェクト型の宣言方法

| 方法 | 用途 | 推奨度 |
|------|------|--------|
| `{a: string}` | 形状が既知のオブジェクト | ✅ 推奨 |
| `object` | 形状不問のオブジェクト | ✅ 推奨 |
| `{}` | 空オブジェクト型（なんでも割当可） | ❌ 避ける |
| `Object` | `{}`とほぼ同じ | ❌ 避ける |

---

## 5. 型エイリアスとブロックスコープ

### 型エイリアスの基本

```typescript
type Age = number

type Person = {
  name: string
  age: Age
}

let driver: Person = {
  name: 'James May',
  age: 55
}
```

### ブロックスコープと覆い隠し

```typescript
type Color = 'red'

let x = Math.random() < .5

if (x) {
  type Color = 'blue'           // 外側のColorを覆い隠す
  let b: Color = 'blue'
} else {
  let c: Color = 'red'
}
```

**ルール**:
- 型エイリアスは`let`/`const`と同じブロックスコープ
- 同名の型を2回宣言すると重複エラー
- 内側のスコープで外側の型を覆い隠せる

---

## 6. 合併型と交差型

### 合併型（Union）

```typescript
type Cat = {name: string, purrs: boolean}
type Dog = {name: string, barks: boolean, wags: boolean}
type CatOrDogOrBoth = Cat | Dog

// 3パターンすべて許可
let a: CatOrDogOrBoth = {name: 'Bonkers', purrs: true}          // Cat
a = {name: 'Domino', barks: true, wags: true}                   // Dog
a = {name: 'Donkers', barks: true, purrs: true, wags: true}     // Both
```

**重要**: 合併型は「どちらか一方」とは限らない。両方のメンバーを同時に満たせる。

### 交差型（Intersection）

```typescript
type CatAndDog = Cat & Dog

let b: CatAndDog = {
  name: 'Domino',
  barks: true,
  purrs: true,
  wags: true
}
```

### 合併型の実用例

```typescript
function trueOrNull(isTrue: boolean): string | null {
  if (isTrue) {
    return 'true'
  }
  return null
}

function(a: string, b: number) {
  return a || b  // string | number
}
```

---

## 7. 配列とタプルの型推論

### 配列の型推論パターン

```typescript
let a = [1, 2, 3]           // number[]
var b = ['a', 'b']          // string[]
let c: string[] = ['a']     // string[]
let d = [1, 'a']            // (string | number)[]
const e = [2, 'b']          // (string | number)[] (constでも拡張)

let f = ['red']
f.push('blue')              // OK
f.push(true)                // エラー: 型 'true' を型 'string' に不可
```

**注意**: `const`で配列を宣言しても、要素型は狭まらない（オブジェクトと同じ）。

### 空配列の型推論

```typescript
let g = []                  // any[]
g.push(1)                   // number[]
g.push('red')               // (string | number)[]

function buildArray() {
  let a = []                // any[]
  a.push(1)                 // number[]
  a.push('x')               // (string | number)[]
  return a
}

let myArray = buildArray()  // (string | number)[] (最終型確定)
myArray.push(true)          // エラー: スコープ外で型確定済み
```

### タプルの型安全性

```typescript
let a: [number] = [1]

// [名前, 名字, 生まれ年]
let b: [string, string, number] = ['malcolm', 'gladwell', 1963]

// オプション要素
let trainFares: [number, number?][] = [
  [3.75],
  [8.25, 7.70],
  [10.50]
]

// 可変長要素（最小長制約）
let friends: [string, ...string[]] = ['Sara', 'Tali', 'Chloe']
let list: [number, boolean, ...string[]] = [1, false, 'a', 'b', 'c']
```

### 読み取り専用配列

```typescript
let as: readonly number[] = [1, 2, 3]
let bs: readonly number[] = as.concat(4)  // 変更しない方法で更新
let three = bs[2]                         // 読み取りはOK
as[4] = 5                                 // エラー: 読み取り専用
as.push(6)                                // エラー: pushメソッドなし

// 宣言の3つの形式
type A = readonly string[]              // 推奨
type B = ReadonlyArray<string>          // 長い形式
type C = Readonly<string[]>             // Utilityタイプ

// タプルも読み取り専用化可能
type D = readonly [number, string]
type E = Readonly<[number, string]>
```

---

## 8. 列挙型の使い分け

### enum vs const enum vs リテラル型

| 方法 | 安全性 | 逆引き | 実行時コード | 推奨度 |
|------|--------|--------|------------|--------|
| `enum` | △（数値は危険） | ✅ | ✅生成 | △ |
| `const enum` | ○（文字列なら安全） | ❌ | ❌インライン | ✅ |
| 文字列リテラル型 | ✅ | ❌ | ❌ | ✅✅ |

### 数値enumの危険性

```typescript
const enum Flippable {
  Burger,
  Chair,
  Cup
}

function flip(f: Flippable) {
  return 'flipped it'
}

flip(Flippable.Chair)     // OK
flip(12)                  // 🚨 OK (危険!)
```

### 文字列enumの安全性

```typescript
const enum Flippable {
  Burger = 'Burger',
  Chair = 'Chair',
  Cup = 'Cup'
}

function flip(f: Flippable) {
  return 'flipped it'
}

flip(Flippable.Chair)     // OK
flip(12)                  // エラー: 型 '12' を型 'Flippable' に不可
flip('Hat')               // エラー: 型 '"Hat"' を型 'Flippable' に不可
```

**推奨**: enumを使う場合は、文字列値のみを使い、すべてのメンバーに明示的な値を設定する。

---

## 9. まとめ

### 型の階層と具体的サブタイプ

| 型 | サブタイプ |
|----|----------|
| `boolean` | 真偽値リテラル |
| `bigint` | BigIntリテラル |
| `number` | 数値リテラル |
| `string` | 文字列リテラル |
| `symbol` | `unique symbol` |
| `object` | オブジェクトリテラル |
| 配列 | タプル |
| `enum` | `const enum` |

### 型安全性のベストプラクティス

1. **リテラル型を活用**: 値をより狭い型に制約
2. **const vs let**: 推論される型の狭さに影響
3. **配列の均一性**: 1つの配列に複数の型を混在させない
4. **オブジェクト型の明示**: `object`でなく`{...}`で形状を指定
5. **読み取り専用**: イミュータブルな配列は`readonly`修飾子
6. **enumは文字列値**: 数値enumは型安全でない
