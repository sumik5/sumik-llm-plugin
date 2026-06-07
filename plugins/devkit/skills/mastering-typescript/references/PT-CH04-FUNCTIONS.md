# 関数の型付け

> TypeScriptにおける関数の宣言・呼び出し・ジェネリクスの型安全な設計パターン。

## 目次

1. [関数の宣言方法](#1-関数の宣言方法)
2. [パラメーターの型付け](#2-パラメーターの型付け)
3. [thisの型付け](#3-thisの型付け)
4. [ジェネレーターとイテレーター](#4-ジェネレーターとイテレーター)
5. [呼び出しシグネチャ](#5-呼び出しシグネチャ)
6. [オーバーロードシグネチャ](#6-オーバーロードシグネチャ)
7. [ポリモーフィズム（ジェネリック関数）](#7-ポリモーフィズムジェネリック関数)
8. [制限付きポリモーフィズム](#8-制限付きポリモーフィズム)
9. [型駆動開発](#9-型駆動開発)

---

## 1. 関数の宣言方法

TypeScriptでは4つの型安全な方法で関数を宣言できる。

```typescript
// 名前付き関数
function greet(name: string) {
  return 'hello ' + name
}

// 関数式
let greet2 = function(name: string) {
  return 'hello ' + name
}

// アロー関数式
let greet3 = (name: string) => 'hello ' + name
```

**基本原則:**
- パラメーター型は明示的にアノテート（文脈的型付けを除く）
- 戻り値の型は推論可能だが明示的指定も可能
- 関数コンストラクターは型安全でないため使用禁止

---

## 2. パラメーターの型付け

**オプションパラメーターとデフォルトパラメーター:**

```typescript
// オプションパラメーター（?を使用）
function log(message: string, userId?: string) {
  console.log(message, userId || 'Not signed in')
}

// デフォルトパラメーター（推奨）
function log(message: string, userId = 'Not signed in') {
  console.log(message, userId)
}
```

**ルール:**
- オプションパラメーター（`?`）は必須パラメーターの後に配置
- デフォルトパラメーターは型推論が働くため型アノテーション不要

**レストパラメーター（可変長引数）:**

```typescript
// レストパラメーター（推奨）
function sumVariadicSafe(...numbers: number[]): number {
  return numbers.reduce((total, n) => total + n, 0)
}
```

**ルール:**
- `arguments`は型安全でないため使用禁止
- レストパラメーター（`...`）をパラメーターリストの最後に配置

---

## 3. thisの型付け

JavaScriptの`this`は呼び出し方によって値が変わるため脆弱。TypeScriptでは明示的に型付けできる。

```typescript
function fancyDate(this: Date) {
  return `${this.getMonth() + 1}/${this.getDate()}/${this.getFullYear()}`
}

fancyDate.call(new Date) // "6/13/2008"
fancyDate() // エラー: 型 'void' の 'this' を型 'Date' に割り当て不可
```

**重要:**
- 関数の最初のパラメーター（予約語）として`this`の型を宣言
- コンパイル時に`this`の型チェックが行われる

---

## 4. ジェネレーターとイテレーター

**ジェネレーター:**

```typescript
function* createFibonacciGenerator() {
  let a = 0, b = 1
  while (true) {
    yield a
    ;[a, b] = [b, a + b]
  }
}

let fibonacciGenerator = createFibonacciGenerator() // Generator<number>
fibonacciGenerator.next() // {value: 0, done: false}
```

**型アノテーション:** `function* createNumbers(): Generator<number> { ... }`

**イテレーター:**

```typescript
let numbers = {
  *[Symbol.iterator]() {
    for (let n = 1; n <= 10; n++) yield n
  }
}

for (let a of numbers) console.log(a) // 1, 2, 3...
let allNumbers = [...numbers] // number[]
```

**定義:**
- **Iterable**: `Symbol.iterator`プロパティを持ちIteratorを返す
- **Iterator**: `next`メソッドで`{value, done}`を返す

---

## 5. 呼び出しシグネチャ

関数そのものの完全な型を表現する構文。

**短縮形と完全形:**

```typescript
// 短縮形
type Log = (message: string, userId?: string) => void

// 完全な呼び出しシグネチャ
type Log = {
  (message: string, userId?: string): void
}
```

**シグネチャと実装の組み合わせ:**

```typescript
type Log = (message: string, userId?: string) => void

let log: Log = (
  message,  // stringと推論される
  userId = 'Not signed in'  // デフォルト値を追加
) => {
  let time = new Date().toISOString()
  console.log(time, message, userId)
}
```

**重要:**
- 呼び出しシグネチャは型レベルのコードのみ（デフォルト値は表現不可）
- 戻り値の型は明示的なアノテーションが必要

**文脈的型付け:**

TypeScriptが文脈からパラメーター型を推論する機能。

```typescript
function times(f: (index: number) => void, n: number) {
  for (let i = 0; i < n; i++) f(i)
}

times(n => console.log(n), 4) // nはnumberと推論
```

---

## 6. オーバーロードシグネチャ

複数の呼び出しシグネチャを持つ関数の設計パターン。

**基本パターン:**

```typescript
type Reserve = {
  (from: Date, to: Date, destination: string): Reservation
  (from: Date, destination: string): Reservation
}

let reserve: Reserve = (
  from: Date,
  toOrDestination: Date | string,
  destination?: string
) => {
  if (toOrDestination instanceof Date && destination !== undefined) {
    // 宿泊旅行を予約
  } else if (typeof toOrDestination === 'string') {
    // 日帰り旅行を予約
  }
}
```

**ルール:**
- 結合された実装シグネチャを手動で宣言
- 実装シグネチャは呼び出し側から見えない
- `any`を避けて具体的に保つ

**入力依存の戻り値型:**

```typescript
type CreateElement = {
  (tag: 'a'): HTMLAnchorElement
  (tag: 'canvas'): HTMLCanvasElement
  (tag: string): HTMLElement  // 包括的なケースは最後
}
```

**関数プロパティのモデル化:**

```typescript
type WarnUser = {
  (warning: string): void
  wasCalled: boolean
}
```

---

## 7. ポリモーフィズム（ジェネリック関数）

ジェネリック型パラメーター（`<T>`）により、複数の型で動作する関数を型安全に実装できる。

**基本パターン:**

```typescript
// 呼び出し時にバインド（推奨）
type Filter = {
  <T>(array: T[], f: (item: T) => boolean): T[]
}

// 型全体スコープ（事前に型を指定）
type Filter<T> = {
  (array: T[], f: (item: T) => boolean): T[]
}

// 名前付き関数での宣言
function filter<T>(array: T[], f: (item: T) => boolean): T[] {
  // ...
}
```

**複数のジェネリック型:**

```typescript
function map<T, U>(array: T[], f: (item: T) => U): U[] {
  let result = []
  for (let i = 0; i < array.length; i++) {
    result[i] = f(array[i])
  }
  return result
}

map(['a', 'b'], _ => _ === 'a') // T=string, U=boolean
```

**型推論:**
- 推奨: 自動推論に任せる（`map(['a'], _ => ...)`）
- 明示的指定: すべての型パラメーターを指定（`map<string, boolean>(...)`）
- 一部のみ指定はエラー

**ジェネリック型エイリアス:**

```typescript
type MyEvent<T> = { target: T; type: string }
type ButtonEvent = MyEvent<HTMLButtonElement>

function triggerEvent<T>(event: MyEvent<T>): void {
  // ...
}
```

---

## 8. 制限付きポリモーフィズム

`extends`により、ジェネリック型に上限（upper bound）を設定して型を制約する。

**基本パターン:**

```typescript
type TreeNode = { value: string }
type LeafNode = TreeNode & { isLeaf: true }

function mapNode<T extends TreeNode>(
  node: T,
  f: (value: string) => string
): T {
  return { ...node, value: f(node.value) }
}

let b: LeafNode = {value: 'b', isLeaf: true}
let b1 = mapNode(b, _ => _.toUpperCase()) // LeafNode（型保持）
```

**効果:** `T extends TreeNode`により、`node.value`を安全に読み取りつつ、入力ノードの特定の型を保持。

**複数の制約:**

```typescript
function logPerimeter<Shape extends HasSides & SidesHaveLength>(s: Shape): Shape {
  console.log(s.numberOfSides * s.sideLength)
  return s
}
```

**可変長引数のモデル化:**

```typescript
function call<T extends unknown[], R>(
  f: (...args: T) => R,
  ...args: T
): R {
  return f(...args)
}

let a = call(fill, 10, 'a')      // string[]
let b = call(fill, 10)           // エラー: 引数不足
```

**ジェネリック型のデフォルト:**

```typescript
type MyEvent<T extends HTMLElement = HTMLElement> = {
  target: T
  type: string
}

// 型を指定しない場合はHTMLElement
let myEvent: MyEvent = { target: myElement, type: 'click' }

// 特定の要素型を指定
let buttonEvent: MyEvent<HTMLButtonElement> = { target: myButton, type: 'click' }
```

**ルール:** デフォルト型を持つジェネリック型は、デフォルトなしの型の後に配置（`Type extends string, Target = HTMLElement`）。

---

## 9. 型駆動開発

**型駆動開発（Type-Driven Development）:**
まず型シグネチャで概略を記述し、その後で値を埋め込むプログラミングスタイル。

```typescript
// 型シグネチャから関数の動作を理解できる
function map<T, U>(array: T[], f: (item: T) => U): U[] {
  // 実装はシグネチャから予測可能
}
```

**アプローチ:**
1. 関数の型シグネチャを定義（型で先導）
2. 実装を埋める前に高レベルで整合性を確認
3. 詳細を埋める

**利点:**
- 型シグネチャを見るだけで関数の動作を理解できる
- 実装前にすべてのものが理にかなっているか確認可能
- 表現力豊かな型システムが実装を導く

---

## まとめ

**TypeScriptの関数型システム要点:**

1. **宣言方法**: 名前付き関数、関数式、アロー関数が型安全
2. **パラメーター**: オプション（`?`）、デフォルト値、レスト（`...`）
3. **thisの型付け**: 第一パラメーター（予約語）として宣言
4. **呼び出しシグネチャ**: 短縮形と完全形、文脈的型付け
5. **オーバーロード**: 複数の呼び出しシグネチャ、入力依存の戻り値型
6. **ジェネリック**: 型パラメーター（`<T>`）、バインドタイミング、型推論
7. **制限付きポリモーフィズム**: `extends`による制約、デフォルト型
8. **型駆動開発**: 型シグネチャ先行で実装を導く

**推奨アプローチ:** 関数シグネチャを先に定義し、実装は後から埋める。
