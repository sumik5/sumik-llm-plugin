# 型の関係・互換性・絞り込みリファレンス

**出典**: 現場で使えるTypeScript 詳解実践ガイド — Chapter 5「型の高度な概念」

---

## 1. 型と集合

TypeScriptの型は**値の集合**として捉えられる。

```
┌──────────── number型 ────────────┐
│  ┌─────────────┐  ┌───────────┐ │
│  │  JpnCoin    │  │  UsCoin   │ │
│  │ 1|5|10|50.. │  │ 1|5|10|25 │ │
│  └─────────────┘  └───────────┘ │
└──────────────────────────────────┘
```

| 集合演算 | TypeScript構文 | 意味 |
|---------|---------------|------|
| 和集合 | `A \| B` | AまたはBの要素 |
| 積集合 | `A & B` | AかつBの要素 |
| 空集合 | `never` | 要素が存在しない型 |

```typescript
type JpnCoin = 1 | 5 | 10 | 50 | 100 | 500;
type UsCoin  = 1 | 5 | 10 | 25;

type All   = JpnCoin | UsCoin;  // 1|5|10|50|100|500|25
type Both  = JpnCoin & UsCoin;  // 1|5|10
type Never = number & string;   // never（空集合）
```

---

## 2. サブタイプとスーパータイプ

`B <: A`（BはAのサブタイプ）= **Aが求められる文脈でBが使用できる** = 部分集合関係。

```
┌──────────── Name（スーパータイプ）──────────┐
│  { name: string }                        │
│  ┌──── NameAndAge（サブタイプ）──────┐    │
│  │  { name: string; age: number }    │    │
│  └────────────────────────────────── ┘    │
└──────────────────────────────────────────┘
NameAndAge <: Name
```

```typescript
type Name       = { name: string };
type NameAndAge = { name: string; age: number };

function logName(person: Name) { console.log(person.name); }

logName({ name: "John", age: 20 }); // OK — NameAndAge <: Name
```

**直感の罠**: プロパティが多い方がサブタイプ（集合としては小さい）。

---

## 3. 構造的部分型（Structural Subtyping）

TypeScriptは型の**名前ではなく構造**で互換性を判断する（Java/C++は名前的型付け—同じ構造でも名前が違えば別の型）。

```typescript
interface Person { name: string }
class    Student { name: string; constructor(n: string) { this.name = n; } }

let person: Person = new Student("Jane"); // OK — 構造が同じなら互換
```

---

## 4. オブジェクト型の互換性ルール

型Bが型Aのサブタイプになる2条件: **① AのすべてのプロパティがBに存在** ② **`B.prop <: A.prop`**

```typescript
interface Person { name: string; age: number }

let p: Person;
p = { name: "John", age: 30, gender: "male" }; // ✅ 追加プロパティは無視
p = { name: "Jane", age: "25" };               // ❌ age: string ≠ number
p = { name: "Alice" };                          // ❌ age が欠如
```

---

## 5. 関数型の互換性（反変性と共変性）

**関数Bが関数Aのサブタイプになる**条件:

| 項目 | 条件 | 方向 |
|------|------|------|
| パラメータ型 | `A.param <: B.param` | **反変**（逆転） |
| パラメータ数 | `B.count ≤ A.count` | 以下 |
| 戻り値型 | `B.return <: A.return` | **共変**（同方向） |

```typescript
interface Person  { name: string; age: number }
interface Student extends Person { club: string } // Student <: Person

let fn3 = (person: Person)   => { /* nameとageのみ使用 */ };
let fn4 = (student: Student) => { /* clubも使用 */ };

fn4 = fn3; // ✅ Person(スーパータイプ)を受ける関数 → Student文脈で安全
fn3 = fn4; // ❌ Student前提の関数をPerson文脈に使うと club へのアクセスで実行時エラー
```

---

## 6. 型の拡大（Type Widening）

`let`宣言では**より汎用的な型に拡大**される。

```typescript
let num  = 5;    // number型（リテラル型 5 ではない）
const PI = 3.14; // リテラル型 3.14（constは拡大されない）
let num2 = PI;   // number型（letへの代入で拡大）
let x    = null; // any型（注意）
let arr  = [];   // any[]型（スコープ外で確定）
```

| 宣言 | 型推論 |
|------|--------|
| `const x = 5` | `5`（リテラル型） |
| `let x = 5` | `number` |
| `let x = null` | `any` |
| `let x = []` | `any[]`（スコープ外で確定） |

---

## 7. 型の絞り込み（Type Narrowing）

| 手法 | 対象 | 例 |
|------|------|-----|
| `typeof` | プリミティブ型 | `typeof v === "string"` |
| `in` | プロパティ存在 | `"width" in shape` |
| `instanceof` | クラスインスタンス | `animal instanceof Fish` |
| タグ付きユニオン | オブジェクトのタグ値 | `shape.type === "circle"` |
| 型述語 | カスタム関数 | `v is string` を戻り値型に指定 |

```typescript
// typeof
function printValue(value: string | number) {
  if (typeof value === "string") value.toUpperCase(); // string型確定
  else                           value.toFixed(2);    // number型確定
}

// in — 共通プロパティ名が衝突する場合はタグ付きユニオンを使う
function printArea(shape: Rectangle | Circle) {
  if ("width" in shape) console.log(shape.width * shape.height);
  else                  console.log(shape.radius ** 2 * 3.14);
}
```

### タグ付きユニオン型（Discriminated Unions）

`in`で共通プロパティ名が衝突する場合は**リテラル型タグ**で解決。IDEの自動補完とスペルミス防止が得られる:

```typescript
interface Rectangle { type: "rectangle"; width: number; height: number }
interface Circle    { type: "circle";    radius: number }
interface Square    { type: "square";    width: number }
type Shape = Rectangle | Circle | Square;

function printArea(shape: Shape) {
  switch (shape.type) {
    case "rectangle": console.log(shape.width * shape.height); break;
    case "circle":    console.log(shape.radius ** 2 * 3.14);  break;
    case "square":    console.log(shape.width ** 2);           break;
  }
}
```

### ユーザー定義型ガード（型述語）

外部関数に型チェックを委ねる場合、`boolean`では型情報がスコープ外に漏れない:

```typescript
// ❌ boolean返却では外側スコープへ型情報が伝わらない
// ✅ 型述語で型チェッカーに伝達
function isString(v: unknown): v is string { return typeof v === "string"; }

function printValue(val: number | string) {
  if (isString(val)) val.toUpperCase(); // string型に絞り込まれる
  else               val.toFixed(2);    // number型に絞り込まれる
}
```

**構文**: 戻り値型に `パラメータ名 is 型名` を指定。

---

## 8. `satisfies` キーワード（TypeScript 4.9+）

型注釈（`: Type`）と`satisfies`の違い:

| 特性 | 型注釈 `: Color` | `satisfies Color` |
|------|----------------|------------------|
| 型チェック（タイポ検出） | ✅ | ✅ |
| 型推論結果の保持 | ❌（注釈型で上書き） | ✅（推論結果を維持） |

```typescript
interface Color { red: RGB | string; green: RGB | string; blue: RGB | string }

// ❌ 型注釈: green が string→RGB|string に上書きされ推論が失われる
const c1: Color = { red: [255,0,0], green: "#00ff00", blue: [0,0,255] };
c1.green.toUpperCase(); // NG — string|RGB には toUpperCase が存在しない

// ✅ satisfies: 型チェック + 推論結果の保持
const c2 = { red: [255,0,0], green: "#00ff00", blue: [0,0,255] } satisfies Color;
c2.green.toUpperCase(); // OK — green は string型として推論されている

const c3 = { red: [255,0,0], green: "#00ff00", bleu: [0,0,255] } satisfies Color;
// ❌ 'bleu' は Color型に存在しない（タイポも検出）
```

---

## まとめ: 型関係の全体像

```
never（空集合）
  ↑ <:
リテラル型（1, "hello", true）
  ↑ <:
プリミティブ型（number, string, boolean）
  ↑ <:
unknown（全型のスーパータイプ）

オブジェクト: プロパティが多い → サブタイプ（集合として小さい）
関数パラメータ: スーパータイプを受ける関数がサブタイプ（反変）
関数戻り値: サブタイプを返す関数がサブタイプ（共変）
```
