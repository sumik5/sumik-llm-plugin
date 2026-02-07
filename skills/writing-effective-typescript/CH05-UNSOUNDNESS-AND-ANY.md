# CH05 不健全性とany型

TypeScriptは実用性を優先した設計により、型システムが「不健全（unsound）」な箇所を持ちます。不健全性とは、実行時の値の型が静的な型と一致しない状態を指します。この章では、不健全性が発生する典型的なパターンとany型の適切な使用法を学びます。

---

## 項目43　可能なかぎり狭いスコープで`any`型を使う

**判断基準**: やむを得ず`any`を使う場合、その影響範囲を最小限に抑えるため、可能な限り狭いスコープで使用します。

**悪い例（広すぎるスコープ）**:

```typescript
function processBar(b: Bar) { /* ... */ }

// ❌ 悪い例
function f1() {
  const x: any = expressionReturningFoo();
  processBar(x); // 型エラーが隠される
  return x; // anyが外部に漏れる
}

// ❌ さらに悪い例
function f2() {
  const x = expressionReturningFoo() as any;
  processBar(x);
  return x;
}
```

**良い例（狭いスコープ）**:

```typescript
function f3() {
  const x = expressionReturningFoo();
  processBar(x as any); // この行のみanyの影響
  return x; // x の型は Foo として推論される
}
```

**オブジェクトプロパティの場合**:

```typescript
const config: Config = {
  a: 1,
  b: 2,
  c: {
    key: value as any, // ✅ 必要なプロパティのみany
  }
};

// ❌ オブジェクト全体をanyにしない
const badConfig = {
  a: 1,
  b: 2,
  c: {
    key: value
  }
} as any;
```

### 覚えておくべきこと

- `any`を使う際はそのスコープをできるだけ狭くし、コードの他の部分で型安全性が損なわれないようにする
- 関数から`any`型を決して返さない。`any`を返すと、その関数を呼び出すコードで型安全性が静かに失われることになる
- オブジェクト全体ではなく、大きなオブジェクトの個々のプロパティに`as any`を使用する

---

## 項目44　`any`をそのまま使うのではなく、より具体的な形式で使う

**判断基準**: `any`が必要な場合でも、データの構造が分かっているなら、その構造を反映したより具体的な型を使用します。

**配列の場合**:

```typescript
// ❌ 悪い例
function getLengthBad(array: any) {
  return array.length; // 配列以外も受け入れてしまう
}

// ✅ 良い例
function getLength(array: any[]) {
  return array.length; // 配列であることが保証される
}

getLength([1, 2, 3]); // OK
getLength('abc'); // 型エラー
```

**オブジェクトの場合**:

```typescript
// ❌ 曖昧
function hasTwelveLetterKey(o: any) {
  for (const key in o) {
    if (key.length === 12) return true;
  }
  return false;
}

// ✅ より明確
function hasTwelveLetterKey(o: { [key: string]: any }) {
  for (const key in o) {
    if (key.length === 12) return true;
  }
  return false;
}
```

**関数の場合**:

```typescript
type Fn0 = any; // ❌ 何でも許容
type Fn1 = (...args: any[]) => any; // ✅ 関数であることが明確

const numArgsBad = (...args: any) => args.length; // 戻り値: any
const numArgsGood = (...args: any[]) => args.length; // 戻り値: number
```

**具体的な形式の選択肢**:

| データ構造 | 具体的な形式 | 例 |
|----------|------------|-----|
| 配列 | `any[]` | `const arr: any[] = [1, 'a', true]` |
| オブジェクト | `{ [key: string]: any }` | `const obj: { [key: string]: any } = { a: 1 }` |
| 関数 | `(...args: any[]) => any` | `const fn: (...args: any[]) => any = (x, y) => x + y` |
| ネストしたオブジェクト | `{ [key: string]: { [key: string]: any } }` | 2階層のオブジェクト |

### 覚えておくべきこと

- `any`を使うときは、本当にどんなJavaScriptの値も許容できるのか考える
- `any[]`、`{[id: string]: any}`、`() => any`など、より具体的な形式の`any`がデータをより正確にモデリングできるなら、ただの`any`ではなくこれらの形式を選択する

---

## 項目45　安全でない型アサーションを、適切に型付けされた関数の内部に隠す

**判断基準**: 型安全でない操作が必要な場合、それを正しい型シグネチャを持つ関数内にカプセル化し、外部には型安全なインターフェイスを提供します。

**配列の最後の要素を取得する例**:

```typescript
// ❌ 悪い例: 呼び出し側で型アサーションが必要
function lastBad<T>(array: readonly T[]): T | undefined {
  return array[array.length - 1];
}

// ✅ 良い例: 関数内部で型アサーションを隠蔽
function cacheLast<T>(fn: (arg: T) => number): (arg: T) => number {
  let lastArg: T | undefined;
  let lastResult: number;
  return (arg: T) => {
    if (arg === lastArg) {
      return lastResult;
    }
    // 内部実装の都合で型アサーションが必要だが、外部には影響しない
    lastArg = arg;
    lastResult = fn(arg);
    return lastResult;
  };
}
```

**flatten関数の例**:

```typescript
// 実装内部で型アサーションを使用
function flatten<T>(array: readonly (T | readonly T[])[]): T[] {
  const result: T[] = [];
  for (const el of array) {
    if (Array.isArray(el)) {
      result.push(...el as T[]); // 内部のみanyを使用
    } else {
      result.push(el as T);
    }
  }
  return result;
}

// 呼び出し側は型安全
const flat = flatten([1, [2, 3], 4]); // number[]
```

### 覚えておくべきこと

- 安全でない型アサーションや`any`型が必要であったり、好都合であったりすることもある。そのような場合は、正しいシグネチャを持つ関数の内部に隠す
- 実装における型エラーを修正するために、関数の型シグネチャを妥協してはならない
- なぜ型アサーションが有効なのかコメントで説明し、コードの徹底的なユニットテストを書く

---

## 項目46　型が不明な値には、`any`ではなく`unknown`を使う

**判断基準**: 値が存在することは分かっているが、その型が何か分からない場合、`any`ではなく`unknown`を使用します。

**`unknown`の特徴**:

```typescript
// unknown は any の型安全な代替
let value: unknown;

value = 123; // OK
value = 'abc'; // OK
value = true; // OK

// ❌ そのまま使用することはできない
value.toFixed(); // 型エラー
value.toString(); // 型エラー

// ✅ 型の絞り込みが必要
if (typeof value === 'number') {
  value.toFixed(); // OK: number に絞り込まれた
}
```

**型ガードとの組み合わせ**:

```typescript
function processValue(value: unknown) {
  if (typeof value === 'string') {
    return value.toUpperCase(); // OK: string
  } else if (typeof value === 'number') {
    return value.toFixed(2); // OK: number
  } else if (value instanceof Date) {
    return value.toISOString(); // OK: Date
  }
  throw new Error('Unsupported type');
}
```

**`{}`、`object`、`unknown`の違い**:

| 型 | 含まれる値 | 備考 |
|----|----------|------|
| `any` | すべての値 | 型チェックを無効化 |
| `unknown` | すべての値 | 型の絞り込みを強制 |
| `{}` | `null`と`undefined`以外 | プリミティブも含む |
| `object` | すべての非プリミティブ型 | オブジェクト、配列、関数 |
| `Object` | `{}`とほぼ同じ | 使用非推奨 |

**ジェネリック関数での使用**:

```typescript
// ❌ 悪い例: 戻り値型のみの型パラメーター
function parseYAMLBad<T>(yaml: string): T {
  // ...
  return result as T; // 偽の安心感
}

// ✅ 良い例: unknown を返す
function parseYAML(yaml: string): unknown {
  // ...
  return result;
}

// 呼び出し側で型ガードまたはアサーションを行う
const data = parseYAML(yamlString);
if (isBookData(data)) {
  // data は BookData として使用可能
}
```

### 覚えておくべきこと

- `unknown`型は`any`の型安全な代替手段である。値があることは知っているが、その型が何か知らない、または気にしない場合に使用する
- 型アサーションや型の絞り込みを強制するために`unknown`型を使用する
- 戻り値型のみに使われる型パラメーターは、誤った安心感を与える可能性があるため避ける
- `{}`や`object`と`unknown`の違いを理解する

---

## 項目47　モンキーパッチではなく、より型安全なアプローチを採用する

**判断基準**: グローバル変数やDOM要素に独自のプロパティを追加する必要がある場合、型安全な方法を選択します。

**問題のあるパターン**:

```typescript
// ❌ 実行時は動くが型エラー
document.monkey = 'Tamarin';
//       ~~~~~~ Property 'monkey' does not exist on type 'Document'

(window as any).someData = data; // anyで逃げる（非推奨）
```

**解決策1: インターフェイスオーグメンテーション**:

```typescript
interface Document {
  monkey: string;
}

document.monkey = 'Tamarin'; // OK

// より安全: undefinedも含める
interface Document {
  monkey: string | undefined;
}
```

**解決策2: より具体的な型へのアサーション**:

```typescript
interface MonkeyDocument extends Document {
  monkey: string;
}

(document as MonkeyDocument).monkey = 'Tamarin';
```

**推奨: 構造化されたアプローチ**:

```typescript
// ✅ 最も良い: WeakMap を使用
const monkeyData = new WeakMap<Document, string>();
monkeyData.set(document, 'Tamarin');
const data = monkeyData.get(document); // string | undefined
```

### 覚えておくべきこと

- グローバル変数やDOMにデータを保持するより、構造化されたコードを優先する
- 組み込みの型にデータを保持しなければならない場合は、型安全なアプローチ（オーグメンテーションやカスタムインターフェイスへのアサーション）を採用する
- オーグメンテーションはスコープの問題を伴うことを理解する。実行時にその可能性がある場合、`undefined`を含める

---

## 項目48　健全性の罠を回避する

**判断基準**: 型システムの不健全性が発生しやすいパターンを認識し、回避します。

**不健全性の主な原因**:

1. **`any`型の使用**
2. **型アサーション（`as`、`is`）**
3. **オブジェクトや配列へのアクセス**
4. **不正確な型定義**
5. **関数パラメーターの変更**
6. **クラスメソッドのオーバーライド**
7. **オプションプロパティ**

**配列の変更による不健全性**:

```typescript
const array: number[] = [];
array.push('abc' as any); // anyで型システムを破る
const num: number = array[0]; // 実際は string
```

**関数パラメーターの変更**:

```typescript
// ❌ 危険: パラメーターを変更
function addToEnd(array: readonly number[], value: number) {
  (array as number[]).push(value); // readonlyを破る
}

const nums: readonly number[] = [1, 2, 3];
addToEnd(nums, 4);

// ✅ 安全: 新しい配列を返す
function addToEnd(array: readonly number[], value: number): number[] {
  return [...array, value];
}
```

**クラスメソッドのオーバーライド**:

```typescript
class Base {
  someMethod(value: number): void {
    // ...
  }
}

// ❌ 危険: シグネチャの不一致
class Derived extends Base {
  someMethod(value: string): void { // 型エラーだが実行時に問題
    // ...
  }
}
```

**オプションプロパティによる不健全性**:

```typescript
interface Options {
  width?: number;
  height?: number;
}

function setDimensions(opts: Options) {
  opts.width = 100;
  opts.height = 100;
}

const opts = { width: 200 } as const;
setDimensions(opts); // 実行時エラーの可能性
```

### 覚えておくべきこと

- 「不健全性」とは、シンボルの実行時の値が静的な型から乖離することである。それにより、クラッシュやその他の悪い動作が、型エラーとして検出されなくなる可能性がある
- 不健全性を引き起こすいくつかのよくあるパターンを認識する。`any`型、型アサーション（`as`、`is`）、オブジェクトや配列へのアクセス、不正確な型定義など
- 関数のパラメーターの変更は、不健全性の原因となる可能性があるため、避ける。変更するつもりがなければ、読み取り専用（`readonly`、`Readonly`）と宣言する
- 親クラスと子クラスでメソッドの宣言が一致していることを確認する
- オプションプロパティがどのように不健全性を引き起こすか知っておく

---

## 項目49　型カバレッジを監視し、型安全性のリグレッションを防ぐ

**判断基準**: プロジェクトの型安全性を定量的に測定し、時間の経過とともに改善することを目指します。

**`type-coverage`ツールの使用**:

```bash
# インストール
npm install -D type-coverage

# 実行
npx type-coverage

# 結果例
9985 / 10117 98.69%
type-coverage success.
```

**詳細情報の表示**:

```bash
npx type-coverage --detail

# any型の箇所を表示
src/utils.ts:15:10 - someFunction
src/components/App.tsx:42:5 - props
```

**継続的な監視**:

```json
// package.json
{
  "scripts": {
    "type-coverage": "type-coverage --at-least 95"
  }
}
```

**`any`が侵入する経路**:

1. **明示的な`any`**: `const x: any = ...`
2. **サードパーティの型定義**: `@types`パッケージの`any`
3. **型推論の失敗**: 条件が複雑すぎる場合
4. **外部ライブラリ**: 型定義のない依存関係

**改善の戦略**:

```typescript
// Before: type coverage 85%
function process(data: any) {
  return data.value;
}

// After: type coverage 98%
interface Data {
  value: string;
}

function process(data: Data) {
  return data.value;
}
```

### 覚えておくべきこと

- `noImplicitAny`を設定しても、明示的な`any`やサードパーティの型宣言（`@types`）によって、`any`型がコードに入り込む可能性がある
- `type-coverage`のようなツールを使って、自分のプログラムがどの程度よく型付けされているか監視することを検討する。そうすることで、`any`の使用に関する決定の再検討が促進され、時間の経過とともに型安全性を向上させられる

---

## any使用判断フロー

```
型を正確に定義できるか？
  ├─ Yes → 明示的な型を定義する
  └─ No → 構造は分かるか？
      ├─ Yes → 具体的な形式のanyを使う
      │        （any[], {[key: string]: any}, (...args: any[]) => any）
      └─ No → unknownを使う
          └─ 型ガードで絞り込み

やむを得ずanyを使う場合
  ├─ スコープを最小限にする（関数内、プロパティ単位）
  ├─ 関数の戻り値にanyを使わない
  ├─ コメントで理由を説明
  └─ ユニットテストを書く
```

## anyの代替手段一覧

| 状況 | anyの代替 | 例 |
|------|----------|-----|
| 型が不明 | `unknown` | `function parse(json: string): unknown` |
| 配列だが要素型不明 | `any[]` | `function getLength(arr: any[]): number` |
| オブジェクトだがプロパティ不明 | `{[key: string]: any}` | `function hasKey(obj: {[key: string]: any}): boolean` |
| 関数だがシグネチャ不明 | `(...args: any[]) => any` | `const fn: (...args: any[]) => any` |
| null/undefined以外 | `{}` | `function nonNullable(value: {}): void` |
| 非プリミティブ型 | `object` | `function isObject(value: object): boolean` |
| 型パラメーターの制約 | `extends unknown` | `function identity<T extends unknown>(x: T): T` |
| JSON値 | カスタム型 | `type JSONValue = string \| number \| boolean \| null \| JSONObject \| JSONArray` |
