# 6章　ジェネリックと型レベルプログラミング

ジェネリックは型に対する関数であり、強力な抽象化を提供します。適切に使用すれば、型の重複を減らし、型安全性を向上させます。

---

## 項目50　ジェネリックを型に対する関数と考える

**判断基準**: ジェネリック型を型に対する関数として考え、`extends`を使って型パラメーターのドメインを制約する。

```typescript
// ジェネリック型は型に対する関数
type FirstElement<T extends any[]> = T[0];

type A = FirstElement<[string, number]>;  // string
type B = FirstElement<number[]>;          // number

// 型パラメーターに制約を追加
interface HasLength {
  length: number;
}

function logLength<T extends HasLength>(item: T): void {
  console.log(item.length);
}

logLength('hello');  // OK: string has length
logLength([1, 2, 3]); // OK: array has length
logLength(123);       // エラー: number に length はない

// 読みやすい型パラメーター名とドキュメント
/**
 * 配列の要素を変換します
 * @template InputType 入力配列の要素の型
 * @template OutputType 出力配列の要素の型
 */
function map<InputType, OutputType>(
  array: InputType[],
  fn: (item: InputType) => OutputType
): OutputType[] {
  return array.map(fn);
}
```

### 覚えておくべきこと
- ジェネリック型を型に対する関数と考える
- 型アノテーションを使って関数のパラメーターを制約するのと同じように、`extends`を使って型パラメーターのドメインを制約する
- コードの読みやすさを向上させるような型パラメーターの名前を選び、TSDocを書く
- ジェネリック関数とジェネリッククラスを、ジェネリック型を概念的に定義し、型推論の助けとなるものと考える

---

## 項目51　不必要な型パラメーターを避ける

**判断基準**: 型パラメーターは型を関連付けるためのものであり、すべての型パラメーターは2回以上登場しなければならない。

```typescript
// ❌ 不必要な型パラメーター（1回しか登場しない）
function identity<T>(value: T): void {
  console.log(value);
}

// ✅ 型パラメーターが不要
function identity(value: unknown): void {
  console.log(value);
}

// ❌ 戻り値型のみのジェネリック
function parse<T>(): T {
  return JSON.parse('{}');
}

// ✅ 明示的な型アサーションを使用
function parse(): unknown {
  return JSON.parse('{}');
}
const data = parse() as MyType;

// ✅ 型パラメーターが2回以上登場（正しい使用法）
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

function map<T, U>(array: T[], fn: (item: T) => U): U[] {
  return array.map(fn);
}
```

### 覚えておくべきこと
- 型パラメーターを必要としない関数やクラスは、型パラメーターを追加しない
- 型パラメーターは型を関連付けるためのものであり、すべての型パラメーターは型同士の関連性を成立させるために2回以上登場しなければならない
- 型パラメーターが値の型の推論結果として現れる可能性があることを覚えておく
- 「戻り値型のみのジェネリック」を避ける
- 不必要な型パラメーターはしばしば`unknown`型に置換可能である

---

## 項目52　オーバーロードシグネチャより条件型を優先的に使用する

**判断基準**: オーバーロードシグネチャより条件型を優先する。ユニオンでの分配により、条件型はオーバーロードなしでユニオン型をサポートできる。

```typescript
// ❌ オーバーロードシグネチャ
function double(x: number): number;
function double(x: string): string;
function double(x: number | string): number | string {
  return typeof x === 'number' ? x * 2 : x + x;
}

const num = double(12);         // number
const str = double('hello');    // string
const union = double(Math.random() > 0.5 ? 12 : 'hello'); // number | string

// ✅ 条件型
function double<T extends number | string>(
  x: T
): T extends number ? number : string {
  return (typeof x === 'number' ? x * 2 : x + x) as any;
}

const num = double(12);         // number
const str = double('hello');    // string
const union = double(Math.random() > 0.5 ? 12 : 'hello'); // number | string

// 条件型は自動的にユニオンで分配される
type DoubleType<T> = T extends number ? number : string;
type Result = DoubleType<number | string>;  // number | string
```

### 実装に1つのオーバーロードを使う戦略

```typescript
function double(x: number): number;
function double(x: string): string;
function double<T extends number | string>(
  x: T
): T extends number ? number : string;
function double(x: number | string): number | string {
  return typeof x === 'number' ? x * 2 : x + x;
}
```

### 覚えておくべきこと
- オーバーロードシグネチャより条件型を優先的に使用する
- ユニオンでの分配により、条件型はオーバーロードなしでユニオン型をサポートする宣言を可能にする
- ユニオンが利用できそうになければ、異なる名前を持つ2つ以上の関数に分けたほうが分かりやすくないか検討する
- 条件型で宣言された関数の実装に、オーバーロードを1つ使う戦略を取ることを検討する

---

## 項目53　条件型のユニオンでの分配を制御する

**判断基準**: 条件型がユニオンで分配されてほしいか考える。分配を制御するため、条件の追加やタプルへのラップを使用する。

```typescript
// デフォルトでは分配される
type ToArray<T> = T[];
type Result = ToArray<string | number>;  // string[] | number[]

// 分配を無効にする（タプルでラップ）
type ToArray<T> = [T] extends [any] ? T[] : never;
type Result = ToArray<string | number>;  // (string | number)[]

// 分配の制御例
type Exclude<T, U> = T extends U ? never : T;
type Result = Exclude<'a' | 'b' | 'c', 'a'>;  // 'b' | 'c'
// 分配により各メンバーで評価:
// 'a' extends 'a' ? never : 'a' → never
// 'b' extends 'a' ? never : 'b' → 'b'
// 'c' extends 'a' ? never : 'c' → 'c'

// boolean と never の特殊な挙動
type IsString<T> = T extends string ? true : false;
type A = IsString<boolean>;  // boolean (true | false)
type B = IsString<never>;    // never
```

### 覚えておくべきこと
- 条件型がユニオンで分配されてほしいか考える
- 条件を追加したり、条件を1要素のタプルにラップしたりすることで、分配を有効にしたり無効にしたりする方法を知る
- 条件型が`boolean`型と`never`型で分配されるときの驚くべき挙動に注意する

---

## 項目54　テンプレートリテラル型を使ってDSLや文字列間の関係をモデリングする

**判断基準**: `string`型の構造化された部分集合やDSLをモデリングするのに、テンプレートリテラル型を使う。

```typescript
// 基本的なテンプレートリテラル型
type EventName = 'click' | 'focus' | 'blur';
type EventHandler = `on${Capitalize<EventName>}`;
// 'onClick' | 'onFocus' | 'onBlur'

// マップ型との組み合わせ
type Events = {
  click: MouseEvent;
  focus: FocusEvent;
  blur: FocusEvent;
};

type EventHandlers = {
  [K in keyof Events as `on${Capitalize<K>}`]: (e: Events[K]) => void;
};
// {
//   onClick: (e: MouseEvent) => void;
//   onFocus: (e: FocusEvent) => void;
//   onBlur: (e: FocusEvent) => void;
// }

// DSLのモデリング
type CSSUnit = 'px' | 'em' | 'rem' | '%';
type CSSValue<Unit extends CSSUnit> = `${number}${Unit}`;

type Width = CSSValue<'px' | '%'>;
const width: Width = '100px';  // OK
const height: Width = '50%';   // OK
const invalid: Width = '10em'; // エラー
```

### 注意点
- 不正確な型への一線を越えないように注意する
- 派手な言語機能の知識を必要とすることなく開発者体験を向上させられるような使い方に努める

### 覚えておくべきこと
- `string`型の構造化された部分集合やDSLをモデリングするのに、テンプレートリテラル型を使う
- テンプレートリテラル型をマップ型や条件型と組み合わせることで、型間の微妙な関係を表現できる
- 不正確な型への一線を越えないように注意する。開発者体験を向上させられるような使い方に努める

---

## 項目55　型のテストを書く

**判断基準**: 型をテストするとき、特に関数型では、等価性と代入可能性の違いに注意する。標準的なツールを使う。

```typescript
// vitest と expect-type を使用
import { expectTypeOf } from 'vitest';

// 基本的なテスト
expectTypeOf<number>().toEqualTypeOf<number>();
expectTypeOf<string>().not.toEqualTypeOf<number>();

// 関数のテスト
function map<T, U>(array: T[], fn: (item: T) => U): U[] {
  return array.map(fn);
}

expectTypeOf(map).toBeCallableWith([1, 2, 3], (x) => x.toString());
expectTypeOf(map([1, 2, 3], (x) => x.toString())).toEqualTypeOf<string[]>();

// コールバックのパラメーターの型をテスト
expectTypeOf(map<number, string>).parameters.toMatchTypeOf<
  [number[], (item: number) => string]
>();

// this の型をテスト（APIの一部として this を提供する場合）
interface Button {
  onClick(this: Button, event: MouseEvent): void;
}

expectTypeOf<Button['onClick']>().thisParameter.toEqualTypeOf<Button>();
```

### テストツールの選択
- **vitest + expect-type**: 構造的な型のテスト、リファクタリングサポート
- **eslint-plugin-expect-type**: 型の表示をテスト
- **dtslint**: DefinitelyTypedのコード用
- **Type Challenges**: 学習・練習用

### 覚えておくべきこと
- 型をテストするとき、特に関数型では、等価性と代入可能性の違いに注意する
- コールバックを使用する関数では、コールバックのパラメーターの型もテストする
- APIの一部として`this`を提供しているなら、その型も忘れずにテストする
- 独自の型テストコードを書くのではなく、標準的なツールを使う

---

## 項目56　型の表示に配慮する

**判断基準**: 同じ型を表示するのに有効な方法はいくつもあり、方法によって読みやすさが異なる。`Resolve`ジェネリックなどを使って型の表示を制御する。

```typescript
// 型の表示を制御する Resolve ジェネリック
type Resolve<T> = T extends Function ? T : { [K in keyof T]: T[K] };

// ❌ 読みにくい型の表示
type BadDisplay = Pick<User, 'name'> & Pick<User, 'email'>;
// ホバー時: Pick<User, 'name'> & Pick<User, 'email'>

// ✅ 読みやすい型の表示
type GoodDisplay = Resolve<Pick<User, 'name'> & Pick<User, 'email'>>;
// ホバー時: { name: string; email: string }

// インライン表示のテクニック
type InlineKeys<T> = Exclude<keyof T, never>;
// keyof T をインライン表示させる

type InlineObject<T> = {} & T;
// オブジェクト型をインライン表示させる

// ジェネリック型の特殊ケースのハンドリング
type MyMap<K, V> = K extends string
  ? Record<K, V>  // string の場合はシンプルな表示
  : Map<K, V>;    // それ以外は Map

type A = MyMap<string, number>;  // Record<string, number>
type B = MyMap<object, number>;  // Map<object, number>
```

### 覚えておくべきこと
- 同じ型を表示するのに有効な方法はいくつもあり、方法によって読みやすさが異なる
- TypeScriptには型の表示を制御するツールがいくつかあり、特に`Resolve`ジェネリックが有用である
- これをうまく使って、型の表示を明確にし、実装の詳細を隠す
- 型の表示を改善するために、ジェネリック型の重要な特殊ケースをハンドリングすることを検討する
- リグレッションを避けるために、ジェネリック型とその表示に対するテストを書く

---

## 項目57　再帰的なジェネリック型は末尾再帰にする

**判断基準**: 再帰的なジェネリック型を末尾再帰にすることで、より効率的で、再帰呼び出しの深さの制限が大幅に緩和される。

```typescript
// ❌ 非末尾再帰
type Reverse<T extends any[]> = T extends [infer First, ...infer Rest]
  ? [...Reverse<Rest>, First]  // 末尾位置で Reverse を呼び出していない
  : [];

// ✅ 末尾再帰（アキュムレーターを使用）
type Reverse<T extends any[], Acc extends any[] = []> = T extends [
  infer First,
  ...infer Rest
]
  ? Reverse<Rest, [First, ...Acc]>  // 末尾位置で Reverse を呼び出す
  : Acc;

type A = Reverse<[1, 2, 3, 4, 5]>;  // [5, 4, 3, 2, 1]

// より複雑な例: JSON のパース
type ParseJSON<T extends string, Acc = never> = T extends `${infer Parsed}${infer Rest}`
  ? ParseJSON<Rest, UpdateAcc<Parsed, Acc>>
  : Acc;
```

### 覚えておくべきこと
- 再帰的なジェネリック型を末尾再帰にすることを目指す。より効率的で、再帰呼び出しの深さの制限が大幅に緩和される
- 再帰的な型エイリアスは、多くの場合アキュムレーターを使うように書き直すことで末尾再帰にできる

---

## 項目58　コード生成を複雑な型の代替手段として検討する

**判断基準**: 型レベルのTypeScriptは非常に強力だが、複雑な型の操作には、コードと型を生成することを検討する。

```typescript
// ❌ 複雑すぎる型レベルのコード
type DeepPartial<T> = T extends object
  ? { [K in keyof T]?: DeepPartial<T[K]> }
  : T;
// 複雑になるとメンテナンス困難、エラーメッセージが読みにくい

// ✅ コード生成アプローチ
// schema.json から型を生成
// $ npx json-schema-to-typescript schema.json > types.ts

// OpenAPI から型を生成
// $ npx openapi-typescript openapi.yaml > api.ts

// データベーススキーマから型を生成
// $ npx prisma generate

// GraphQL スキーマから型を生成
// $ npx graphql-codegen
```

### コード生成のメリット
- 型レベルのロジックを書く必要がない
- エラーメッセージが分かりやすい
- パフォーマンスが良い
- 外部ソース（スキーマ、API定義）と同期できる

### 注意点
- CIシステムで`git diff`を実行し、生成されたコードが同期を保っていることを確認する

### 覚えておくべきこと
- 型レベルのTypeScriptは非常に強力なツールだが、それが常に最適なわけではない
- 複雑な型の操作には、型レベルのコードを書く代わりに、コードと型を生成することを検討する
- コード生成ツールは、普通のTypeScriptや他の言語で書ける
- CIシステム上でコード生成と`git diff`を実行し、生成されたコードが同期を保っていることを確認する

---

## ジェネリクス使用判断テーブル

| 状況 | 判断 | 理由 |
|------|------|------|
| 型パラメーターが1回しか登場しない | ❌ 使わない | 型を関連付けていない。`unknown`で十分 |
| 戻り値型のみに型パラメーターが登場 | ❌ 使わない | 型アサーションを使用する |
| 型パラメーターが2回以上登場 | ✅ 使う | 型を関連付けている |
| 配列の要素の型を保持したい | ✅ 使う | `map`、`filter`等の関数 |
| オブジェクトのプロパティの型を保持したい | ✅ 使う | `Pick`、`Omit`等のユーティリティ型 |
| 複雑な型操作が必要 | ⚠️ 検討 | コード生成も検討する |
| 条件分岐が必要 | ✅ 条件型を使う | オーバーロードより優先 |
| ユニオンの分配を制御したい | ✅ タプルラップを使う | 分配の有効/無効を制御 |
| 文字列パターンをモデリングしたい | ✅ テンプレートリテラル型を使う | DSLのモデリングに有効 |
| 再帰的な型が必要 | ✅ 末尾再帰にする | パフォーマンスと深さ制限の緩和 |

---

## 使い過ぎの兆候

以下の兆候が見られたら、ジェネリクスの使用を見直してください：

### 🚨 危険信号

1. **型パラメーターが増殖している**
   ```typescript
   // ❌ 複雑すぎる
   function fn<T, U, V, W, X>(a: T, b: U, c: V): W { }
   ```

2. **エラーメッセージが読めない**
   - 型エラーが数行にわたる場合は、型が複雑すぎる

3. **型の表示が理解不能**
   ```typescript
   // ホバー時: Pick<Omit<Partial<User>, 'id'>, 'name' | 'email'> & ...
   ```

4. **実装が型より複雑**
   - 実装が10行なのに型定義が50行ある場合は見直す

5. **パフォーマンス問題**
   - 型チェックに時間がかかる場合は、型を簡略化するかコード生成を検討

### ✅ 適切な使用

1. **型パラメーターが少ない（1-3個）**
2. **エラーメッセージが分かりやすい**
3. **型の表示が読みやすい**
4. **実装と型のバランスが取れている**
5. **型チェックが高速**

---

## ベストプラクティス

### 1. シンプルに保つ
```typescript
// ✅ シンプル
function first<T>(arr: T[]): T | undefined {
  return arr[0];
}

// ❌ 複雑すぎる
function first<T extends any[], U = T[0]>(arr: T): U {
  return arr[0] as U;
}
```

### 2. 読みやすい名前を使う
```typescript
// ✅ 読みやすい
function map<Input, Output>(
  array: Input[],
  fn: (item: Input) => Output
): Output[]

// ❌ 読みにくい
function map<T, U>(arr: T[], fn: (x: T) => U): U[]
```

### 3. ドキュメントを書く
```typescript
/**
 * 配列の各要素に関数を適用します
 * @template T 入力配列の要素の型
 * @template U 出力配列の要素の型
 */
function map<T, U>(array: T[], fn: (item: T) => U): U[] { }
```

### 4. テストを書く
```typescript
import { expectTypeOf } from 'vitest';

expectTypeOf(map([1, 2], x => x.toString())).toEqualTypeOf<string[]>();
```

### 5. 型の表示を制御する
```typescript
type Resolve<T> = T extends Function ? T : { [K in keyof T]: T[K] };

type MyType = Resolve<Pick<User, 'name'> & Pick<User, 'email'>>;
```
