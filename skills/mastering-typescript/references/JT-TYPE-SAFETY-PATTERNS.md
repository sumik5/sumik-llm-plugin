# 型安全パターン詳解 — Weak Type・Excess Property Checks・宣言空間

出典: 実践TypeScript（吉井健文）Chapter 4-5

> **TS-TYPE-SAFETY.mdとの差別化**: あちらはany禁止・型ガード・ジェネリクス中心。
> こちらはWeak Type・Excess Property Checks・宣言空間という「なぜエラーが出る/出ない」に焦点を当てる。

---

## 1. 制約による型安全

### Nullable型とガード節による絞り込み

```typescript
// ❌ 型なし → ランタイムエラー
function format(value) { return `${value.toFixed(1)} pt` }
format(null) // Runtime Error!

// ✅ Nullable型 + ガード節 → コンパイルエラーに変換
function format(value: number | null) {
  if (value === null) return '-- pt' // 早期return後は value: number に絞り込まれる
  return `${value.toFixed(1)} pt`
}
```

### Optional引数とDefault引数の推論パターン

| 宣言方法 | 呼び出し側 | 関数内部での型 |
|---------|-----------|-------------|
| `name?: string` | 省略可 | `string \| undefined`（ガード節が必要） |
| `unit = 'pt'` | 省略可 | `string`（デフォルト値がundefinedを保証） |
| `unit: string \| null = null` | 省略可 | `string \| null`（null チェックが必要） |

```typescript
// ✅ デフォルト引数: 関数内部でundefinedが振り落とされる
function format(value: number, unit = 'pt') {
  return `${value.toFixed(1)} ${unit.toUpperCase()}` // unit: string 確定
}

// ❌ optional引数: 関数内でundefinedを考慮しないとエラー
function greet(name?: string) {
  return `Hello ${name!.toUpperCase()}` // Compile Error!
}
```

### Readonly型とObject.freeze

```typescript
type State = { id: number; name: string }

// Readonly<T>: 全プロパティに readonly を一括付与（コンパイルのみ有効）
const state: Readonly<State> = { id: 1, name: 'Taro' }
state.id = 2 // ✅ Compile Error

// Object.freeze: Readonly<T>型推論 + ランタイムも不変
const frozen = Object.freeze({ id: 1, name: 'Taro' })
frozen.id = 2 // ✅ Compile Error かつ ランタイムでも書き換わらない
```

> `readonly` / `Readonly<T>` はコンパイル時のみ。ランタイムで書き換えを防ぐには `Object.freeze` を使う。

---

## 2. Weak Type検出

**Weak Type** = すべてのプロパティがオプショナルな型。

```typescript
type User = { age?: number; name?: string }
function registerUser(user: User) {}

const maybeUser = { age: 26, name: 'Taro', gender: 'male' }
registerUser(maybeUser) // ✅ No Error（age/nameで一致）

const notUser = { gender: 'male', graduate: 'Tokyo' }
registerUser(notUser)   // ❌ Error（User型と共通プロパティが1つもない）

registerUser({})  // ✅ No Error（空オブジェクトは許容）
registerUser()    // ❌ Error（引数自体は必須）
```

**検出メカニズム**: Weak Typeへの代入時、共通プロパティが1つ以上あるかを検査する。
「全部オプショナルだから何でも渡せる」は誤り。型と無関係なオブジェクトは弾かれる。

---

## 3. Excess Property Checks

同じオブジェクトでも渡し方によってエラーになるかが変わる。

| 渡し方 | EPC発動 | 理由 |
|-------|:-------:|------|
| 変数経由 `registerUser(maybeUser)` | ❌ なし | 構造的部分型互換のみ検査 |
| オブジェクトリテラル直接 `registerUser({ ... })` | ✅ あり | 余分プロパティを厳密チェック |
| スプレッド経由 `registerUser({...obj})` | ❌ なし | 変数経由と同等の扱い |

```typescript
type User = { age?: number; name?: string }

// ✅ 変数経由: No Error
const maybeUser = { age: 26, name: 'Taro', gender: 'male' }
registerUser(maybeUser)

// ❌ 直接リテラル: gender が余分プロパティとしてエラー
registerUser({ age: 26, name: 'Taro', gender: 'male' })

// ✅ スプレッド: No Error（チェック回避 → アンチパターンに注意）
registerUser({ ...{ age: 26, name: 'Taro', gender: 'male' } })
```

**なぜこの仕様か**: 設定オブジェクトを直接記述するユースケースで、タイポや誤った設定キーを早期発見するため。

---

## 4. 抽象度による型安全

### upcast（安全）vs downcast（要注意）

```typescript
// ✅ upcast: 詳細 → 抽象（安全）
const literal: 'orange' = 'orange'
const str: string = literal // No Error

// ⚠️ downcast: 抽象 → 詳細（プログラマーが責任を持つ）
const theme = { bg: 'orange' as 'orange' } // Literal Typeに固定
theme.bg = 'blue' // ✅ Compile Error（意図どおり）

// ❌ 互換性のないdowncastは失敗
const x = 'orange' as false // Error! string と boolean は互換性なし
```

### const assertion（as const）

```typescript
// 通常: { type: string }（Widening）
function increment() { return { type: 'INCREMENT' } }

// as const: { readonly type: 'DECREMENT' }（Literal Type固定）
function decrement() { return { type: 'DECREMENT' } as const }

// 定数ファイルへの一括適用
export default {
  increment: 'INCREMENT',
  decrement: 'DECREMENT'
} as const  // 全値が Literal Types で固定される
```

### 危険なアサーション: Non-null assertion（`!`）

```typescript
// ❌ ! でundefinedを強制除去 → コンパイルは通るがランタイムエラー
function greet(name?: string) {
  console.log(`Hello ${name!.toUpperCase()}`)
}
greet() // Runtime Error!
```

### 危険なアサーション: double assertion

```typescript
// ❌ any を経由して型チェックを完全に回避
const myName = 0 as any as string
console.log(myName.toUpperCase()) // ✅ コンパイルOK → Runtime Error!

// ❌ 戻り値anyがvoidを隠蔽
function greet(): any { console.log('hello') }
const msg = greet()
msg.toUpperCase() // ✅ コンパイルOK → Runtime Error!

// ✅ 型推論に任せれば早期発見できる
function greet() { console.log('hello') }
const msg = greet()
msg.toUpperCase() // ✅ Compile Error（void型で検出）
```

---

## 5. 宣言空間（Declaration Space）

TypeScriptには宣言の種別に応じた3つの独立したグループがある。

| 宣言空間 | 含まれる宣言 |
|---------|------------|
| **Value** | 変数（`const`/`let`/`var`）、関数 |
| **Type** | `interface`、`type alias` |
| **Namespace** | `namespace` |

```typescript
// ✅ 同一名称でも宣言空間が異なれば競合しない
const Test = {}    // Value空間
interface Test {}  // Type空間
namespace Test {}  // Namespace空間
```

### Declaration Typeと宣言空間の対応

| 宣言の種別 | Namespace | Type | Value |
|-----------|:---------:|:----:|:-----:|
| `namespace` | ✓ | | ✓ |
| `class` | | ✓ | ✓ |
| `enum` | | ✓ | ✓ |
| `interface` | | ✓ | |
| `type alias` | | ✓ | |
| `function` / 変数 | | | ✓ |

**実用**: `class` はTypeとValueの両方（型としても値としても使える）。`interface` はTypeのみ。

---

## 6. 宣言結合（Declaration Merging）

### interfaceの結合（open ended）

```typescript
// ✅ interface は同名宣言を重ねて型拡張できる
interface Bounds { width: number; height: number }
interface Bounds { left: number; top: number }
// → { width: number; height: number; left: number; top: number } に自動結合

// ❌ 同名プロパティを異なる型で再宣言はエラー
interface Bounds { width: string } // Error! （元は number）

// ✅ 同名関数メンバーはオーバーロードになる
interface Bounds { move(amount: string): string }
interface Bounds { move(amount: number): string }
// → move は string | number を受け付けるオーバーロードに

// ❌ type alias はopen endedでない
type User = { name: string }
type User = { age: number } // Error!
```

### namespaceの結合（ライブラリ拡張）

```typescript
// Expressが提供する拡張ポイント（空interfaceで結合待ち）
declare global {
  namespace Express {
    interface Request {}
  }
}

// @types/express-session をインストールするだけで自動的に型が拡張される
declare global {
  namespace Express {
    interface Request {
      session?: Session
      sessionID?: string
    }
  }
}
```

---

## 7. モジュール型拡張（Module Augmentation）

`declare module '...'` で既存ライブラリの型をファイルをまたいで拡張する。

```typescript
// vue-plugin.d.ts
import Vue from 'vue'

declare module 'vue/types/vue' {
  interface VueConstructor {
    $myGlobal: string // グローバルプロパティを追加
  }
}

declare module 'vue/types/options' {
  interface ComponentOptions<V extends Vue> {
    myOption?: string // コンポーネントオプションを追加
  }
}
```

### namespace結合 vs モジュール型拡張

| 手法 | 使うタイミング |
|-----|--------------|
| `namespace` 結合 | `@types/xxx` が `declare global { namespace ... }` で拡張ポイントを提供している場合 |
| `declare module` | ライブラリが `.d.ts` をビルトインで持ち、モジュールとして型を公開している場合 |

判断: `node_modules/@types/xxx/index.d.ts` を開き、`namespace` か `module` どちらで定義されているか確認する。

---

## 実務チェックポイント

| 疑問 | 原因と対処 |
|-----|----------|
| 変数経由はOKなのに直接書くとエラー | Excess Property Checks。変数に代入してから渡す |
| 全プロパティoptionalなのにエラー | Weak Type検出。共通プロパティが1つもない |
| 同名の型と値が共存している | 宣言空間の違い（Type空間とValue空間は独立） |
| インストールしただけで型が増えた | namespace結合またはdeclare moduleによるモジュール型拡張 |
| `!` でエラーが消えたが後でクラッシュ | Non-null assertionの乱用。型チェックを欺いている |
