# 高度な型

> TypeScript の型システムの最も強力な機能: 変性、型の絞り込み、条件型、高度なオブジェクト型

## 目次

1. [サブタイプとスーパータイプ](#1-サブタイプとスーパータイプ)
2. [変性（Variance）](#2-変性variance)
3. [割り当て可能性](#3-割り当て可能性)
4. [型の拡大](#4-型の拡大)
5. [型の絞り込み](#5-型の絞り込み)
6. [完全性](#6-完全性)
7. [高度なオブジェクト型](#7-高度なオブジェクト型)
8. [関数にまつわる高度な型](#8-関数にまつわる高度な型)
9. [条件型](#9-条件型)
10. [エスケープハッチ](#10-エスケープハッチ)
11. [名前的型のシミュレート](#11-名前的型のシミュレート)
12. [プロトタイプの安全な拡張](#12-プロトタイプの安全な拡張)
13. [まとめ](#13-まとめ)

---

## 1. サブタイプとスーパータイプ

**サブタイプ（`A <: B`）**: `B` が要求されるところで `A` を安全に使える
**スーパータイプ（`A >: B`）**: `A` が要求されるところで `B` を安全に使える

```typescript
class Animal {}
class Bird extends Animal {}
let animal: Animal = new Bird()  // Bird <: Animal
```

**組み込み関係**: タプル <: 配列 <: オブジェクト、すべて <: any、never <: すべて

---

## 2. 変性（Variance）

### 4種類の変性

| 変性 | 意味 |
|-----|------|
| **不変性（Invariance）** | `T` そのものを必要とする |
| **共変性（Covariance）** | `<:T` であるものを必要とする |
| **反変性（Contravariance）** | `>:T` であるものを必要とする |
| **双変性（Bivariance）** | `<:T` または `>:T` であればOK |

**TypeScript の形状は共変**: オブジェクト `A` が `B` に割り当て可能 ⇔ 対応する各プロパティで `A` のプロパティ `<:` `B` のプロパティ

### 関数の変性

```typescript
// Crow <: Bird <: Animal
function clone(f: (b: Bird) => Bird): void {}

clone((a: Animal) => new Bird())  // OK（パラメータ反変: Animal >: Bird）
clone((c: Crow) => new Bird())    // エラー（Crow <: Bird）

clone((b: Bird) => new Crow())    // OK（戻り値共変: Crow <: Bird）
clone((b: Bird) => new Animal())  // エラー（Animal >: Bird）
```

**関数サブタイプ条件**:
1. `A` の `this` 型 `>:` `B` の `this` 型（または未指定）
2. `A` のパラメータ型 `>:` `B` のパラメータ型（反変）
3. `A` の戻り値型 `<:` `B` の戻り値型（共変）

---

## 3. 割り当て可能性

**ルール**: `A` を `B` に割り当て可能 ⇔ (1) `A <: B` または (2) `A` が `any`

**列挙型**: (1) `A` が列挙型 `B` のメンバー、または (2) `B` に `number` メンバーがあり `A` が `number`

---

## 4. 型の拡大

```typescript
let a = 'x'         // string（拡大）
const b = 'x'       // 'x'（拡大されない）
let c: 'x' = 'x'    // 'x'（明示的型で拡大防止）

let d = {x: 3}                // {x: number}
let e = {x: 3} as const       // {readonly x: 3}（拡大抑制+readonly）
let f = [1, {x: 2}] as const  // readonly [1, {readonly x: 2}]
```

**null/undefined**: `let a = null` → `any`（スコープ内）、関数戻り値では明確な型に

### 過剰プロパティチェック

```typescript
type Options = { baseURL: string; tier?: 'prod' | 'dev' }
new API({ baseURL: '...', tierr: 'prod' })  // エラー（フレッシュ）
new API({ baseURL: '...', tierr: 'prod' } as Options)  // OK（非フレッシュ）
```

**フレッシュ**: オブジェクトリテラル直接 → 過剰プロパティチェック
**非フレッシュ**: 変数経由 or 型アサーション → チェックなし

---

## 5. 型の絞り込み

| ガード | 例 |
|-------|-----|
| `typeof` | `if (typeof x === 'string')` |
| `instanceof` | `if (error instanceof ApiError)` |
| `in` | `if ('permissions' in person)` |
| truthiness | `if (unit) { ... }` |
| タグ付きUnion | `if (event.type === 'TextEvent')` |

### タグ付き合併型

```typescript
type UserTextEvent = { type: 'TextEvent', value: string }
type UserMouseEvent = { type: 'MouseEvent', value: [number, number] }
type UserEvent = UserTextEvent | UserMouseEvent

function handle(event: UserEvent) {
  if (event.type === 'TextEvent') {
    event.value  // string
  } else {
    event.value  // [number, number]
  }
}
```

**良いタグ条件**: (1) 全ケースに存在、(2) リテラル型、(3) 非ジェネリック、(4) 排他的

---

## 6. 完全性

```typescript
type Weekday = 'Mon' | 'Tue'| 'Wed' | 'Thu' | 'Fri'
function getNextDay(w: Weekday): Day {
  switch (w) {
    case 'Mon': return 'Tue'
  }
}
// エラー: 関数に終了の return ステートメントがなく、戻り値の型に 'undefined' が含まれていません
```

**完全性チェック**: すべてのケースがカバーされているかをコンパイル時に検証
**`noImplicitReturns` フラグ**: すべてのパスで値を返すことを強制

---

## 7. 高度なオブジェクト型

### ルックアップ型と keyof

```typescript
type APIResponse = { user: { userId: string; friendList: { friends: { firstName: string }[] } } }
type FriendList = APIResponse['user']['friendList']
type Friend = FriendList['friends'][number]
type ResponseKeys = keyof APIResponse  // 'user'
```

### 型安全なゲッター

```typescript
function get<O extends object, K extends keyof O>(o: O, k: K): O[K] {
  return o[k]
}
```

### レコード型とマップ型

```typescript
type Weekday = 'Mon' | 'Tue' | 'Wed' | 'Thu' | 'Fri'
let nextDay: Record<Weekday, Day> = { Mon: 'Tue' }  // エラー（全キー必須）

type OptionalAccount = { [K in keyof Account]?: Account[K] }
type ReadonlyAccount = { readonly [K in keyof Account]: Account[K] }
type RequiredAccount = { [K in keyof OptionalAccount]-?: Account[K] }  // -? で必須化
```

| Utility型 | 説明 |
|----------|------|
| `Record<K, V>` | キー`K`と値`V`のオブジェクト |
| `Partial<T>` | 全フィールド省略可能 |
| `Required<T>` | 全フィールド必須 |
| `Readonly<T>` | 全フィールド読み取り専用 |
| `Pick<T, K>` | 指定キーのみ抽出 |

### コンパニオンオブジェクトパターン

```typescript
type Currency = { unit: Unit; value: number }
let Currency = {
  from(value: number, unit: Unit): Currency { return {unit, value} }
}

let amountDue: Currency = { unit: 'JPY', value: 83733.10 }  // 型として使用
let other = Currency.from(330, 'EUR')  // 値として使用
```

**利点**: 型と値を一度にインポート可能

---

## 8. 関数にまつわる高度な型

### ユーザー定義型ガード

```typescript
function isString(a: unknown): a is string {
  return typeof a === 'string'
}

if (isString(input)) {
  input.toUpperCase()  // OK（string として扱える）
}
```

---

## 9. 条件型

```typescript
type IsString<T> = T extends string ? true : false
type A = IsString<string>  // true

// 分配条件型
type ToArray2<T> = T extends unknown ? T[] : T[]
type B = ToArray2<number | string>  // number[] | string[]（分配される）

// infer キーワード
type ElementType<T> = T extends (infer U)[] ? U : T
type A = ElementType<number[]>  // number

type SecondArg<F> = F extends (a: any, b: infer B) => any ? B : never
```

| 組み込み条件型 | 説明 |
|-------------|------|
| `Exclude<T, U>` | `T` から `U` を除外 |
| `Extract<T, U>` | `T` から `U` に割り当て可能なもの抽出 |
| `NonNullable<T>` | `null`/`undefined` 除外 |
| `ReturnType<F>` | 関数戻り値型 |
| `InstanceType<C>` | クラスインスタンス型 |

---

## 10. エスケープハッチ

```typescript
// 型アサーション
formatInput(input as string)

// 非nullアサーション
document.getElementById(dialog.id!)!  // T | null | undefined → T

// 明確な割り当てアサーション
let userId!: string  // 初期化前の使用を許可
fetchUser()
userId.toUpperCase()  // OK
```

**制限**: 型アサーションはスーパータイプ・サブタイプのみ

---

## 11. 名前的型のシミュレート

### ブランド型

```typescript
type CompanyID = string & {readonly brand: unique symbol}
type UserID = string & {readonly brand: unique symbol}

function CompanyID(id: string) { return id as CompanyID }
function UserID(id: string) { return id as UserID }

function queryForUser(id: UserID) { /* ... */ }

queryForUser(UserID('d21b1dbf'))      // OK
queryForUser(CompanyID('8a6076cf'))   // エラー: CompanyID ≠ UserID
```

**利点**: 実行時オーバーヘッド最小、コンパイル時型安全

---

## 12. プロトタイプの安全な拡張

```typescript
// 型拡張宣言
declare global {
  interface Array<T> {
    zip<U>(list: U[]): [T, U][]
  }
}

// 実装追加
Array.prototype.zip = function(list) {
  return this.map((v, k) => [v, list[k]])
}

// 使用（明示的import必要）
import './zip'
[1, 2, 3].map(n => n * 2).zip(['a', 'b', 'c'])  // [number, string][]
```

**tsconfig.json**: `"exclude": ["./zip.ts"]` で明示的import強制

---

## 13. まとめ

### 重要概念

**変性（Variance）**:
- 共変（プロパティ・戻り値）: `A <: B` なら OK
- 反変（関数パラメータ）: `A >: B` なら OK
- 不変: `T` そのものが必要
- 双変: `<:T` または `>:T` で OK

**型の拡大と絞り込み**:
- ミュータブル宣言は拡大（`let a = 'x'` → `string`）
- `const`/明示的型/`as const` で拡大防止
- 型ガード（`typeof`, `instanceof`, `in`, カスタム）
- タグ付きUnion
- 完全性チェック

**高度な型**:
- ルックアップ型 (`T[K]`)、`keyof`
- マップ型 (`{[K in keyof T]: ...}`)
- 条件型 (`T extends U ? A : B`)、`infer`
- コンパニオンオブジェクトパターン
- ブランド型（名前的型シミュレート）

### ベストプラクティス

1. 型の拡大を理解、`as const` 活用
2. タグ付きUnionで型安全絞り込み
3. 完全性チェックで網羅性保証
4. エスケープハッチ最小化
5. ブランド型で混同防止
