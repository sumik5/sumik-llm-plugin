# TypeScript 高度な型機能リファレンス

TypeScriptの高度な型システム機能。リテラル型の制御・型述語・as const・mapped types・条件型・async型・コンパイラオプションなどCh6-9の独自コンテンツを収録。

---

## 1. ユニオン型の伝播（Propagation）

```typescript
type StringOrNumber = string | number;

// ユニオン型のプロパティアクセス結果もユニオン型
type AB = { a: string; b: number } | { a: number; b: string };
// ({ a: string } | { a: number }) → a: string | number
```

### 関数型同士のユニオン

```typescript
type F1 = (x: string) => void;
type F2 = (x: number) => void;
type F = F1 | F2;

// F型の関数を呼び出すとき、引数はインターセクション型になる
declare const f: F;
f("hello" as string & number); // 引数は string & number（実用上は never）
```

### オプショナルチェイニングと型

```typescript
type User = { name: string; address?: { city: string } };

const user: User = { name: "uhyo" };
const city = user.address?.city;
// 型: string | undefined（undefined が伝播する）
```

---

## 2. リテラル型の widening 制御

### wideningされるリテラル型 vs されないリテラル型

```typescript
// letはwidening（推論がstring型に広がる）
let str1 = "hello"; // 型: string

// constはwideningされない（リテラル型のまま）
const str2 = "hello"; // 型: "hello"

// 型注釈を明示するとwideningされない
let str3: "hello" = "hello"; // 型: "hello"

// オブジェクトのプロパティはwideningされる（constでも）
const obj = { mode: "dark" }; // mode の型: string（"dark"ではない）
```

### as const で widening を防ぐ

```typescript
// 4つの効果:
// 1. 配列リテラル → タプル型
// 2. すべてのプロパティが readonly
// 3. リテラルがwideningされないリテラル型
// 4. テンプレート文字列がテンプレートリテラル型

const names = ["uhyo", "John", "Taro"] as const;
// 型: readonly ["uhyo", "John", "Taro"]（string[]ではない）

const config = { mode: "dark", lang: "ja" } as const;
// 型: { readonly mode: "dark"; readonly lang: "ja" }
```

### as const で「値から型を作る」

```typescript
// 型を先に定義してから値を作る（従来の方法）
type Name = "uhyo" | "John" | "Taro";
const names1: Name[] = ["uhyo", "John", "Taro"];

// 値を先に定義して、そこから型を作る（as constの活用）
const NAMES = ["uhyo", "John", "Taro"] as const;
type Name2 = (typeof NAMES)[number]; // "uhyo" | "John" | "Taro"

// メリット: 同じリストを2回書かなくてよい（DRYの実現）
```

---

## 3. テンプレートリテラル型

```typescript
// バッククォートで型の組み合わせを表現
type Greeting = `Hello, ${string}!`;
const g1: Greeting = "Hello, world!";   // OK
const g2: Greeting = "Hello, uhyo!";    // OK
// const g3: Greeting = "Hi, there!";  // エラー

// ユニオン型との組み合わせ
type Color = "red" | "green" | "blue";
type CSSColor = `color-${Color}`;
// = "color-red" | "color-green" | "color-blue"

// as const + テンプレートリテラル型
const template = `prefix-${"value"}` as const;
// 型: "prefix-value"（stringではない）
```

---

## 4. タグ付きユニオンと switch による型絞り込み

### タグ付きユニオン（代数的データ型の実現）

```typescript
type Circle = { kind: "circle"; radius: number };
type Square = { kind: "square"; size: number };
type Shape = Circle | Square;

function area(shape: Shape): number {
  if (shape.kind === "circle") {
    // ここでは shape は Circle 型に絞り込まれる
    return Math.PI * shape.radius ** 2;
  } else {
    return shape.size ** 2;
  }
}
```

### switch文での網羅性チェック

```typescript
function describeShape(shape: Shape): string {
  switch (shape.kind) {
    case "circle":
      return `円（半径: ${shape.radius}）`;
    case "square":
      return `正方形（辺: ${shape.size}）`;
    default:
      // never型になることで全ケース網羅を保証
      const _exhaustive: never = shape;
      throw new Error(`Unknown shape: ${JSON.stringify(_exhaustive)}`);
  }
}
// 新しいShape型を追加し忘れるとここでコンパイルエラーになる
```

---

## 5. keyof型とlookup型 + ジェネリクス

### K extends keyof T パターン

```typescript
// 型安全なプロパティアクセス関数
function get<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

type Human = { name: string; age: number };
const uhyo: Human = { name: "uhyo", age: 26 };

const name = get(uhyo, "name"); // 型: string
const age = get(uhyo, "age");   // 型: number
// get(uhyo, "gender");          // コンパイルエラー！

// keyof T は string | number | symbol の部分型
// 文字列キーのみを要求する場合:
function getStr<T, K extends keyof T & string>(obj: T, key: K): T[K] {
  const keyStr: string = key; // OK（string の保証がある）
  return obj[key];
}
```

---

## 6. 型アサーション（as）と非nullアサーション（!）

### as の正しい使い方

```typescript
// ❌ 誤用: 型安全性を破壊する
function bad(value: string | number): string {
  return value as string; // 実際にnumberが来たらランタイムエラー
}

// ✅ 正しい使い方: TypeScriptが推論できない絞り込みを補助する
type Animal = { tag: "animal"; species: string };
type Human = { tag: "human"; name: string };
type User = Animal | Human;

function getNamesIfAllHuman(users: readonly User[]): string[] | undefined {
  if (users.every(user => user.tag === "human")) {
    // TypeScriptはevery()の意味を理解できないため、asで補助
    return (users as Human[]).map(user => user.name);
  }
  return undefined;
}
// as を使う際は必ずコメントで理由を明記する
```

### ! 非nullアサーション

```typescript
// value! で null/undefined の可能性を除去
function process(value?: string): string {
  if (value === undefined) return "";
  // TypeScriptが認識できないパターンで使用
  return value!.toUpperCase(); // 実態として確実にstringの場合
}

// as との等価性
// (value as string).toUpperCase() と同じ意味
// ! は短いが分かりにくい → as を使う流派も
```

---

## 7. ユーザー定義型ガード（型述語）

### `value is Type` 形式

```typescript
// 関数を使った型の絞り込み
function isString(value: unknown): value is string {
  return typeof value === "string";
}

const x: unknown = "hello";
if (isString(x)) {
  // ここでは x は string 型
  console.log(x.toUpperCase());
}
```

### 複雑なランタイム型チェック

```typescript
type Human = { type: "Human"; name: string; age: number };

function isHuman(value: unknown): value is Human {
  if (value == null) return false; // null/undefinedを排除
  const v = value as Record<string, unknown>;
  return (
    v["type"] === "Human" &&
    typeof v["name"] === "string" &&
    typeof v["age"] === "number"
  );
}

// 使用例: APIレスポンスの型チェック
const response = JSON.parse(apiData);
if (isHuman(response)) {
  // response は Human 型として扱える
  console.log(response.name);
}
```

### `asserts value is Type` 形式（例外ベース）

```typescript
function assertHuman(value: unknown): asserts value is Human {
  if (!isHuman(value)) {
    throw new Error(`Expected Human, got: ${JSON.stringify(value)}`);
  }
}

function process(value: unknown) {
  assertHuman(value);
  // この行以降、value は Human 型
  console.log(value.name);
}
```

**危険性の比較**（低 → 高）: ユーザー定義型ガード < `as` < `any`

---

## 8. mapped types

```typescript
// 構文: { [P in K]: T }
// K のユニオン型の各要素 P に対してプロパティを生成

type Fruit = "apple" | "orange" | "strawberry";

// 各フルーツのプロパティがnumber型を持つオブジェクト型
type FruitCounts = { [P in Fruit]: number };
// = { apple: number; orange: number; strawberry: number }

// P を T に使うパターン（各フルーツの配列）
type FruitArrays = { [P in Fruit]: P[] };
// = { apple: "apple"[]; orange: "orange"[]; strawberry: "strawberry"[] }

// Homomorphic mapped type: { [P in keyof T]: U }
// → T の構造（配列・オブジェクト）を保存しながら変換
```

---

## 9. conditional types

```typescript
// 構文: X extends Y ? S : T
// 「X が Y の部分型なら S、そうでなければ T」

type IsString<T> = T extends string ? "yes" : "no";
type A = IsString<string>;  // "yes"
type B = IsString<number>;  // "no"

// 実用例: 引数の型で返り値の型を変える
type RestArgs<M> = M extends "string" ? [string, string] : [number, number, number];

function func<M extends "string" | "number">(mode: M, ...args: RestArgs<M>) {
  console.log(mode, ...args);
}

func("string", "uhyo", "hyo");  // OK
func("number", 1, 2, 3);        // OK
// func("string", 1, 2);        // エラー！

// Union Distribution（ユニオンの分配）:
// T がユニオン型の型変数の場合、各要素に分配される
type Wrap<T> = T extends string ? { value: T } : never;
type W = Wrap<"a" | "b">; // { value: "a" } | { value: "b" }
```

---

## 10. 組み込みユーティリティ型

```typescript
type Human = { name: string; age: number; skill?: string };

// Readonly<T>: 全プロパティをreadonly
type ReadonlyHuman = Readonly<Human>;
// { readonly name: string; readonly age: number; readonly skill?: string }

// Partial<T>: 全プロパティをオプショナル
type PartialHuman = Partial<Human>;
// { name?: string; age?: number; skill?: string }

// Required<T>: 全プロパティを必須に
type RequiredHuman = Required<Human>;
// { name: string; age: number; skill: string }

// Pick<T, K>: 特定のプロパティのみ抽出
type NameOnly = Pick<Human, "name">;
// { name: string }

// Omit<T, K>: 特定のプロパティを除外
type WithoutSkill = Omit<Human, "skill">;
// { name: string; age: number }

// Record<K, V>: キーと値の型でオブジェクト型を生成
type FruitCount = Record<"apple" | "orange", number>;
// { apple: number; orange: number }

// Extract<T, U>: T から U の部分型を抽出
type StringOrNumber = string | number | boolean;
type OnlyStringOrNumber = Extract<StringOrNumber, string | number>;
// string | number

// Exclude<T, U>: T から U の部分型を除外
type WithoutBoolean = Exclude<StringOrNumber, boolean>;
// string | number
```

---

## 11. 型のエクスポート / インポート

```typescript
// export type: 型としてのみエクスポート
export type Animal = { species: string; age: number };

// export {}構文: 変数と型を混在してエクスポート
type Dog = { species: "Canis" };
const tama: Dog = { species: "Canis" };
export { Dog, tama };

// import type: 型のみとしてインポート（バンドルサイズ削減に有効）
import type { Animal } from "./animal.js";
// → ランタイムコードに含まれない（型消去）

// export type でエクスポートされた変数は typeof でのみ使用可能
import { tama } from "./animal.js"; // export type だった場合
const myCat: typeof tama = { species: "Canis" }; // OK
// const copy = tama; // エラー！値としては使えない
```

---

## 12. async関数の型

```typescript
// async関数の返り値は常にPromise<T>
async function getData(): Promise<string> {
  return "data"; // return値がPromiseの結果になる
}

// 返り値型注釈は省略して推論させることも可能
async function getNumber() {
  return 42; // 推論: Promise<number>
}

// Promiseが失敗する場合 → Promiseがrejectされる
async function mayFail(): Promise<string> {
  throw new Error("Failed!");
  // → p.catch() でキャッチできる
}

// await式の型: Promise<T> → T
async function main() {
  const data: string = await getData();      // awaitでPromiseを解除
  const num: number = await getNumber();

  // Promise<void>を返すasync関数
  // return文がない場合や、void値のPromiseの場合
}

// top-level await（モジュールのトップレベルで使用可能）
const result = await getData();
export const processed = result + "!";
```

---

## 13. 重要なコンパイラオプション

### strict（推奨: 常に有効）

以下のオプションをまとめて有効化:
- `strictNullChecks`: null/undefinedを型安全に扱う（null安全性）
- `noImplicitAny`: 型注釈なし引数が暗黙のanyになることを禁止
- `strictFunctionTypes`: 関数型の変性を厳密にチェック
- `useUnknownInCatchVariables`: catch節の変数をunknown型に

### noUncheckedIndexedAccess（推奨: 新規プロジェクトで有効）

```typescript
// 有効時: インデックスシグネチャアクセスが T | undefined になる
type Data = { [key: string]: number };
const data: Data = { a: 1 };

// noUncheckedIndexedAccess 有効時
const val = data.x; // 型: number | undefined（安全！）

// 配列のインデックスアクセスも同様
const arr = [1, 2, 3];
const first = arr[0]; // 型: number | undefined
const out = arr[10];  // 型: number | undefined（実際はundefined）
```

### exactOptionalPropertyTypes（推奨: 新規プロジェクトで有効）

```typescript
type Config = { mode?: "dark" | "light" };

// 有効時: undefined の明示的代入が禁止される
// const c: Config = { mode: undefined }; // エラー！

// オプショナルプロパティを削除したい場合は delete を使う
const config: Config = { mode: "dark" };
delete config.mode; // OK
```

### 新規プロジェクト推奨設定

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

**方針**: 後方互換性のためのオプションは新規プロジェクトでは不要。
`strict: false`は「TypeScriptを使う意義が大きく薄れる」ため避ける。
