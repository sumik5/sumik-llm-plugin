# 3章　型推論と制御フロー解析

TypeScriptの型推論システムを理解し、適切に活用することで、コードをシンプルに保ちながら型安全性を確保できます。

---

## 項目18　推論可能な型でコードを乱雑にしない

**判断基準**: TypeScriptが同じ型を推論できる場合は型アノテーションを省略する。冗長なアノテーションはコードを読みにくくし、保守性を下げる。

```typescript
// ❌ 冗長
let x: number = 12;

// ✅ 推論に任せる
let x = 12;  // number と推論される

// ✅ 関数シグネチャには型を明示
function add(a: number, b: number): number {
  return a + b;
}

// ✅ オブジェクトリテラルは型アノテーションを検討
const person: Person = {
  name: "Alice",
  age: 30
};  // 余剰プロパティチェックが有効になる
```

### 覚えておくべきこと
- TypeScriptが同じ型を推論できる場合は、型アノテーションを書かない
- 関数・メソッドのシグネチャには型アノテーションを付けるが、本体のローカル変数には付けない
- オブジェクトリテラルには明示的な型アノテーションを使用し、余剰プロパティチェックとエラーの早期発見を有効にする
- 関数に複数の`return`がある場合、パブリックAPIの一部である場合、名前付きの型を返させたい場合を除き、戻り値の型アノテーションは省略できる

---

## 項目19　異なる型には異なる変数を使う

**判断基準**: 同じ変数を異なる型の値に再利用しない。人間にとっても型チェッカーにとっても混乱を招く。

```typescript
// ❌ 変数の再利用
let id = "12-34-56";
id = 123456;  // 型エラー

// ✅ 異なる変数を使用
let id = "12-34-56";
let serial = 123456;
```

### 利点
- 無関係な2つの概念（IDとシリアル番号）を分離できる
- より具体的な変数名を使える
- 型推論が改善され、型アノテーションが不要になる
- 型がより単純になる（`string|number`ではなく、具体的な型）
- 変数を`let`ではなく`const`と宣言できる

### 覚えておくべきこと
- 変数の値は変えられるが、その型は通常変わらない
- 人間と型チェッカーの混乱を避けるため、変数を異なる型の値に再利用しない

---

## 項目20　変数の型がどのように決まるか理解する

**判断基準**: TypeScriptは型の拡大によってリテラルから型を推論する。この挙動を理解し、必要に応じて制御する。

```typescript
// 型の拡大
let x = 'x';  // string と推論される
const y = 'y';  // 'y' リテラル型

// as const で型を制約
const config = {
  host: 'localhost',
  port: 8080
} as const;  // readonly { host: 'localhost', port: 8080 }

// satisfies で型チェックと推論を両立
const palette = {
  red: [255, 0, 0],
  green: '#00ff00'
} satisfies Record<string, string | number[]>;
// palette.red は [255, 0, 0] と推論される
```

### 型の拡大を制御する方法
- `const`: 再代入を防ぎ、リテラル型を保持
- 型アノテーション: 明示的に型を指定
- ヘルパー関数: 型パラメーターで型を制約
- `as const`: オブジェクト全体を読み取り専用リテラル型に
- `satisfies`: 型チェックしつつ推論結果を保持

### 覚えておくべきこと
- TypeScriptが型の拡大により、リテラルからどのように型を推論するか理解する
- `const`、型アノテーション、ヘルパー関数、`as const`、`satisfies`など、この挙動を制御する方法に習熟する

---

## 項目21　オブジェクトを一度に構築する

**判断基準**: オブジェクトを段階的に構築すると型推論が妨げられる。スプレッド構文を使って一度に構築する。

```typescript
// ❌ 段階的な構築
const point = {};
point.x = 3;  // 型エラー
point.y = 4;

// ✅ 一度に構築
const point = {
  x: 3,
  y: 4
};

// ✅ スプレッド構文で拡張
const namedPoint = {
  ...point,
  name: 'origin'
};

// ✅ 条件付きプロパティ
const options = {
  ...baseOptions,
  ...(isDebug ? { debug: true } : {})
};
```

### 覚えておくべきこと
- オブジェクトを段階的に構築するより、一度に構築する
- スプレッド構文を使って型安全にプロパティを追加する
- 条件付きでプロパティを追加する方法を知る

---

## 項目22　型の絞り込みを理解する

**判断基準**: 条件分岐や制御フローを使って型を絞り込む方法を理解し、TypeScriptが型を追いやすいコードを書く。

```typescript
// typeof による絞り込み
function double(x: number | string) {
  if (typeof x === 'number') {
    return x * 2;  // x は number
  }
  return x + x;  // x は string
}

// タグ付きユニオン
type Shape =
  | { kind: 'circle'; radius: number }
  | { kind: 'rectangle'; width: number; height: number };

function area(shape: Shape) {
  switch (shape.kind) {
    case 'circle':
      return Math.PI * shape.radius ** 2;
    case 'rectangle':
      return shape.width * shape.height;
  }
}

// ユーザー定義型ガード
function isInputElement(el: HTMLElement): el is HTMLInputElement {
  return 'value' in el;
}
```

### 覚えておくべきこと
- TypeScriptが条件分岐や制御フローに基づいて型を絞り込む方法を理解する
- タグ付きユニオンやユーザー定義の型ガードを使用して絞り込みを支援する
- TypeScriptがコードを追いやすいようリファクタリングできないか考える

---

## 項目23　エイリアスを作成したら一貫してそれを使う

**判断基準**: エイリアスはTypeScriptの型の絞り込みを妨げることがある。変数にエイリアスを作成する場合は一貫して使用する。

```typescript
interface Polygon {
  bbox?: { x: [number, number]; y: [number, number] };
}

// ❌ エイリアスと元のプロパティを混在
function fn(polygon: Polygon) {
  if (polygon.bbox) {
    const { bbox } = polygon;
    helper(polygon.bbox);  // エイリアスではなく元を使用
  }
}

// ✅ 一貫してエイリアスを使用
function fn(polygon: Polygon) {
  const { bbox } = polygon;
  if (bbox) {
    helper(bbox);  // 一貫してエイリアスを使用
  }
}
```

### 覚えておくべきこと
- エイリアスはTypeScriptの型の絞り込みを妨げることがある。変数にエイリアスを作成する場合は一貫して使用する
- 関数呼び出しによって、プロパティの型の絞り込みが無効になる可能性がある。プロパティよりローカル変数の型の絞り込みを信頼する

---

## 項目24　型推論に文脈がどう使われるか理解する

**判断基準**: 値を変数に持たせると文脈情報が失われる。型アノテーションや`as const`で文脈を保持する。

```typescript
type Language = 'JavaScript' | 'TypeScript' | 'Python';

// ❌ 文脈の喪失
let language = 'TypeScript';
setLanguage(language);  // 型エラー: string は Language に代入できない

// ✅ 型アノテーション
let language: Language = 'TypeScript';

// ✅ as const
let language = 'TypeScript' as const;

// タプルの場合
function panTo(where: [number, number]) { /* ... */ }

// ❌ 配列として推論される
const loc = [10, 20];
panTo(loc);  // 型エラー

// ✅ as const
const loc = [10, 20] as const;

// ✅ 型アノテーション
const loc: [number, number] = [10, 20];
```

### 覚えておくべきこと
- 型推論に文脈がどう使われるか意識する
- 値を変数に持たせたときに型エラーが発生する場合は、型アノテーションを追加する
- 変数が真に定数である場合は`as const`を使用する。ただし、使用する場所でエラーが表示される可能性がある
- 型アノテーションを減らすためインラインで値を使うのが実用的な場合は、この形式がより好ましい

---

## 項目25　進化する型を理解する

**判断基準**: `null`、`undefined`、`[]`で初期化された値は型が進化する。この挙動を理解し、必要に応じて活用する。

```typescript
// 進化する型
let value = null;  // null
value = 'hello';   // string
value = 123;       // string | number

// 配列の進化
const result = [];  // any[]
result.push('a');   // string[]
result.push(1);     // (string | number)[]

// ✅ 明示的な型アノテーションで型エラーを早期発見
const result: string[] = [];
result.push('a');
result.push(1);  // 型エラー
```

### 覚えておくべきこと
- TypeScriptの型は通常絞り込まれるだけだが、`null`、`undefined`、`[]`で初期化された値は進化することがある
- 進化する型が使われたらそれを認識して理解し、必要な型アノテーションを減らすために使用する
- エラーチェックを改善したい場合は、進化する型を使う代わりに明示的な型アノテーションを付ける

---

## 項目26　関数型の標準APIやライブラリを使って型の流れを促進する

**判断基準**: 手書きのループは型の流れを妨げる。関数型APIやユーティリティライブラリを使用して型の流れを改善する。

```typescript
// ❌ 手書きのループ
const result = [];
for (const item of items) {
  if (item.isValid) {
    result.push(item.name);
  }
}

// ✅ 関数型API
const result = items
  .filter(item => item.isValid)
  .map(item => item.name);

// Lodash を使った例
import _ from 'lodash';

const grouped = _.groupBy(items, item => item.category);
const mapped = _.mapValues(grouped, items => items.length);
```

### 覚えておくべきこと
- 型の流れを促進し、可読性を高め、必要な型アノテーションを減らすため、手書きのループの代わりに関数型の標準APIやLodashのようなユーティリティライブラリを使用する

---

## 項目27　コールバックの代わりに`async`関数を使用して型の流れを改善する

**判断基準**: コールバックよりPromiseを使い、さらに`async`/`await`を使うことで型の流れを改善する。

```typescript
// ❌ コールバック地獄
fetchUser(userId, (user) => {
  fetchPosts(user.id, (posts) => {
    fetchComments(posts[0].id, (comments) => {
      // 型の流れが途切れる
    });
  });
});

// ✅ Promise
fetchUser(userId)
  .then(user => fetchPosts(user.id))
  .then(posts => fetchComments(posts[0].id))
  .then(comments => {
    // 型の流れが保持される
  });

// ✅ async/await（最も推奨）
async function loadData(userId: string) {
  const user = await fetchUser(userId);
  const posts = await fetchPosts(user.id);
  const comments = await fetchComments(posts[0].id);
  return comments;  // 戻り値の型が自動推論される
}
```

### 利点
- Promiseはコールバックより組み合わせやすい
- Promiseを使うコードは型の流れが改善する
- コードがより簡潔で分かりやすくなる
- `async`関数は常にPromiseを返すことが強制される

### 覚えておくべきこと
- 非同期処理の組み合わせやすさと型の流れの改善のため、コールバックではなくPromiseを使用する
- 可能であれば、Promiseをそのまま使うのではなく`async`/`await`を利用する
- 関数がPromiseを返すなら、`async`で宣言する

---

## 項目28　クラスやカリー化を使って型パラメーターを段階的に割り当てる

**判断基準**: 複数の型パラメーターを持つ関数では、推論は全か無かである。型パラメーターを部分的に推論させるには、クラスやカリー化を使う。

```typescript
// ❌ 全パラメーターを明示的に指定
declare function parse<T, U>(data: T, options: U): Result<T, U>;
const result = parse<string, ParseOptions>(data, options);

// ✅ クラスによる段階的割り当て
class Parser<T> {
  constructor(private schema: T) {}

  parse<U>(data: U) {
    // T は推論済み、U は呼び出し時に推論
    return parseData(this.schema, data);
  }
}

const parser = new Parser(stringSchema);  // T は推論される
const result = parser.parse(data);        // U は推論される

// ✅ カリー化
function createParser<T>(schema: T) {
  return function parse<U>(data: U): Result<T, U> {
    return parseData(schema, data);
  };
}

const parser = createParser(stringSchema);  // T は推論される
const result = parser(data);                // U は推論される
```

### 覚えておくべきこと
- 複数の型パラメーターを持つ関数において、推論は全か無かである
- 型パラメーターを部分的に推論させるには、クラスまたはカリー化を使って段階的に割り当てる
- ローカルの型エイリアスを作りたい場合は、カリー化のアプローチを選択する

---

## 判断フローチャート: 型アノテーションを付けるべきか？

```
型アノテーションを付けるべきか？
│
├─ 関数・メソッドのシグネチャ（パラメーター・戻り値）
│  └─ YES: 常に付ける
│
├─ オブジェクトリテラル
│  └─ CONSIDER: 余剰プロパティチェックが必要なら付ける
│
├─ ローカル変数
│  ├─ TypeScriptが正確に推論できる → NO
│  ├─ 型の拡大を制御したい → YES（または as const）
│  ├─ 進化する型でエラーを早期発見したい → YES
│  └─ 文脈情報が失われる場合 → YES
│
└─ その他
   └─ デフォルト: TypeScriptの推論に任せる
```

---

## 型推論に任せるべき場面 vs 明示すべき場面

### 型推論に任せるべき場面
- ローカル変数の型が明らかな場合
- 型の流れが保たれている場合
- 関数型APIや`async`/`await`を使っている場合
- オブジェクトを一度に構築している場合

### 型を明示すべき場面
- 関数・メソッドのシグネチャ
- パブリックAPIの境界
- オブジェクトリテラル（余剰プロパティチェックが必要な場合）
- 型の拡大を制御したい場合
- 文脈情報が失われる場合
- 進化する型でエラーを早期発見したい場合
- 複数の`return`がある関数（推奨）
