# CH07 レシピ集

TypeScriptの実践的なレシピとパターン集。型チェッカーを活用して従来検出できなかったバグを発見し、困難なパターンを型安全にモデリングする方法を紹介します。

---

## 項目59　`never`型を使って網羅性チェックを行う

**判断基準**: タグ付きユニオンの`switch`文や複数の状態を持つ条件分岐で、すべてのケースを確実に処理したい場合に使用します。

**コード例**:

```typescript
type Shape = Box | Circle | Line;

function assertUnreachable(value: never): never {
  throw new Error(`Missed a case! ${value}`);
}

function drawShape(shape: Shape, context: CanvasRenderingContext2D) {
  switch (shape.type) {
    case 'box':
      context.rect(...shape.topLeft, ...shape.size);
      break;
    case 'circle':
      context.arc(...shape.center, shape.radius, 0, 2 * Math.PI);
      break;
    case 'line':
      context.moveTo(...shape.start);
      context.lineTo(...shape.end);
      break;
    default:
      assertUnreachable(shape); // 新しい型を追加すると型エラーになる
  }
}
```

**積集合の網羅性チェック**（じゃんけんの例）:

```typescript
type Play = 'rock' | 'paper' | 'scissors';

function shoot(a: Play, b: Play) {
  const pair = `${a},${b}` as `${Play},${Play}`;
  switch (pair) {
    case 'rock,rock':
    case 'paper,paper':
    case 'scissors,scissors':
      console.log('draw');
      break;
    case 'rock,scissors':
    case 'paper,rock':
    case 'scissors,paper':
      console.log('A wins');
      break;
    case 'rock,paper':
    case 'paper,scissors':
    case 'scissors,rock':
      console.log('B wins');
      break;
    default:
      assertUnreachable(pair); // 見逃したペアがあれば型エラー
  }
}
```

### 覚えておくべきこと

- `never`型への代入を使用して、ある型が取りうるすべての値が処理されていることを保証する（「網羅性チェック」）
- 複数の分岐から`return`する関数には、戻り値の型アノテーションを付ける。ただし、それでも明示的な網羅性チェックが必要な場合はある
- 複数の値のすべての組み合わせが網羅されているか確認するために、テンプレートリテラル型を使うことを検討する

---

## 項目60　オブジェクトに対して反復処理する方法を知る

**判断基準**: オブジェクトのキーと値を安全に反復処理したい場合、または追加のプロパティを持つ可能性のあるオブジェクトを扱う場合に適切な方法を選択します。

**for-inループの問題**:

```typescript
interface ABC {
  a: string;
  b: string;
  c: number;
}

function foo(abc: ABC) {
  for (const k in abc) {
    // k の型は string（'a' | 'b' | 'c' ではない）
    const v = abc[k]; // 型エラー
  }
}
```

TypeScriptが`k`を`string`と推論する理由は、関数のパラメーターが追加のプロパティを持つ可能性があるためです（構造的型付け）。

**解決策1: Object.entriesを使用**（推奨・安全）:

```typescript
function foo(abc: ABC) {
  for (const [k, v] of Object.entries(abc)) {
    // k: string, v: any（正直な型）
    console.log(v);
  }
}
```

**解決策2: 型アサーション**（キーが正確に分かっている場合）:

```typescript
function foo(abc: ABC) {
  for (const kStr in abc) {
    const k = kStr as keyof ABC;
    const v = abc[k]; // OK
  }
}
```

**解決策3: Mapを使用**（代替手段）:

```typescript
const m = new Map([
  ['one', 'uno'],
  ['two', 'dos'],
  ['three', 'tres'],
]);

for (const [k, v] of m.entries()) {
  // k: string, v: string（安全）
  console.log(v);
}
```

### 覚えておくべきこと

- 関数がパラメーターとして受け取るオブジェクトが、追加のキーを持つ可能性があることに注意する
- オブジェクトのキーと値を反復処理するには`Object.entries`を使用する
- キーが何であるか正確に分かっている場合は、`for-in`ループと明示的な型アサーションを使ってオブジェクトを反復処理する
- オブジェクトの代替手段として、反復処理がより容易な`Map`を検討する

---

## 項目61　`Record`型を使って値の同期を保つ

**判断基準**: インターフェイスにプロパティを追加した際に、関連するコードの更新を強制したい場合に使用します。

**問題**: 新しいプロパティ追加時に更新漏れが発生しやすい。

```typescript
interface ScatterProps {
  xs: number[];
  ys: number[];
  xRange: [number, number];
  yRange: [number, number];
  color: string;
  onClick?: (x: number, y: number, index: number) => void;
}

// フェイルオープン: 新しいプロパティを見逃すと不必要な再描画が発生
// フェイルクローズド: 新しいプロパティを見逃すと必要な再描画が漏れる
```

**解決策: Record型で同期を強制**:

```typescript
const REQUIRES_UPDATE: Record<keyof ScatterProps, boolean> = {
  xs: true,
  ys: true,
  xRange: true,
  yRange: true,
  color: true,
  onClick: false, // イベントハンドラは再描画不要
};

function shouldUpdate(
  oldProps: ScatterProps,
  newProps: ScatterProps
) {
  for (const kStr in oldProps) {
    const k = kStr as keyof ScatterProps;
    if (oldProps[k] !== newProps[k] && REQUIRES_UPDATE[k]) {
      return true;
    }
  }
  return false;
}
```

新しいプロパティを`ScatterProps`に追加すると、`REQUIRES_UPDATE`でも定義が必要になり、型エラーが発生します。

### 覚えておくべきこと

- フェイルオープンとフェイルクローズドのジレンマを認識する
- `Record`型を使って、関連する値と型の同期を保つ
- `Record`型を使って、インターフェイスに新しいプロパティを追加した際に、そのプロパティに関する何らかの選択を強制することを検討する

---

## 項目62　レストパラメーターとタプル型を使って、可変長引数の関数をモデリングする

**判断基準**: 引数の型が他の引数の数や型に依存する可変長引数の関数を型安全に定義したい場合に使用します。

**基本的なパターン**:

```typescript
function bindAll<T extends object>(
  obj: T,
  ...keys: Array<keyof T>
): void {
  for (const key of keys) {
    const fn = obj[key];
    if (typeof fn === 'function') {
      obj[key] = fn.bind(obj) as any;
    }
  }
}
```

**タプル型でパラメーター数を制約**:

```typescript
// 引数の型と戻り値の型を関連付ける
function fetch<T extends string[]>(
  ...urls: [...T]
): Promise<{ [K in keyof T]: string }> {
  return Promise.all(urls.map(url => fetch(url).then(r => r.text())));
}

// 使用例
const [html, json] = await fetch('/page', '/api/data');
// html: string, json: string
```

**ラベル付きタプル要素**（パラメーター名を表示）:

```typescript
type Fn = (...args: [first: number, second: string]) => void;
// エディターで関数呼び出し時に 'first' と 'second' が表示される
```

### 覚えておくべきこと

- シグネチャが引数の型に依存する関数をモデリングするために、レストパラメーターとタプル型を使用する
- あるパラメーターの型と、それ以外のパラメーターの数と型の関係をモデリングするには、条件型を使用する
- 呼び出し元に分かりやすいパラメーター名を表示できるよう、タプル型の要素に忘れずにラベルを付ける

---

## 項目63　`never`型のオプションプロパティを使って、排他的論理和をモデリングする

**判断基準**: 「AまたはBのどちらか一方のみ」を表現したい場合に使用します。通常のユニオン型は「AまたはB、またはその両方」を意味するため、排他性が必要な場合は明示的に制約を加えます。

**問題**: 通常のユニオンは包含的論理和（inclusive or）:

```typescript
interface EmailContact {
  name: string;
  email: string;
}

interface PhoneContact {
  name: string;
  phone: string;
}

type Contact = EmailContact | PhoneContact;

// 問題: 両方のプロパティを持つオブジェクトも許容される
const contact: Contact = {
  name: 'Alice',
  email: 'alice@example.com',
  phone: '555-1234', // エラーにならない！
};
```

**解決策1: タグ付きユニオン**（推奨）:

```typescript
interface EmailContact {
  type: 'email';
  name: string;
  email: string;
}

interface PhoneContact {
  type: 'phone';
  name: string;
  phone: string;
}

type Contact = EmailContact | PhoneContact;
```

**解決策2: neverプロパティで排他性を強制**:

```typescript
interface EmailContact {
  name: string;
  email: string;
  phone?: never;
}

interface PhoneContact {
  name: string;
  phone: string;
  email?: never;
}

type Contact = EmailContact | PhoneContact;

const contact: Contact = {
  name: 'Alice',
  email: 'alice@example.com',
  phone: '555-1234', // 型エラー！
};
```

### 覚えておくべきこと

- TypeScriptでは、「または（or）」は包含的論理和（inclusive or）である。すなわち、`A | B`は`A`または`B`、またはその両方を意味する
- コードで「その両方」の可能性を考慮し、それを処理するか、または許容しないようにする
- タグ付きユニオンが排他的論理和のモデリングに使えるなら、それを使う。そうでない場合は、`never`型のオプションプロパティを使うことを検討する

---

## 項目64　名前的型付けのためにブランドを使うことを検討する

**判断基準**: 構造的には同じだが意味的に異なる型（例: ユーザーIDと商品ID）を区別したい場合に使用します。

**問題**: 構造的型付けでは意味の違いを区別できない:

```typescript
type UserId = string;
type ProductId = string;

function getUser(id: UserId) { /* ... */ }
function getProduct(id: ProductId) { /* ... */ }

const userId: UserId = 'user123';
const productId: ProductId = 'prod456';

getUser(productId); // エラーにならない！
```

**解決策1: ブランドプロパティ**:

```typescript
type UserId = string & { readonly __brand: 'UserId' };
type ProductId = string & { readonly __brand: 'ProductId' };

function makeUserId(id: string): UserId {
  return id as UserId;
}

function makeProductId(id: string): ProductId {
  return id as ProductId;
}

const userId = makeUserId('user123');
const productId = makeProductId('prod456');

getUser(productId); // 型エラー！
```

**解決策2: unique symbolを使用**:

```typescript
declare const userIdSymbol: unique symbol;
type UserId = string & { [userIdSymbol]: true };

declare const productIdSymbol: unique symbol;
type ProductId = string & { [productIdSymbol]: true };
```

**バリデーション付きブランド型**:

```typescript
type AbsolutePath = string & { readonly __brand: 'AbsolutePath' };

function isAbsolutePath(path: string): path is AbsolutePath {
  return path.startsWith('/');
}

function processFile(path: AbsolutePath) { /* ... */ }

const path = '/home/user/file.txt';
if (isAbsolutePath(path)) {
  processFile(path); // OK
}
```

### 覚えておくべきこと

- 名前的型付けでは、ある型を値が持つのは、その値がその型を持つと宣言されたからであって、その型と同じ形状をしているからではない
- 意味的には異なるが構造的には一致するプリミティブ型やオブジェクト型を区別するために、ブランドを付けることを検討する
- オブジェクト型のプロパティ、文字列の`enum`、プライベートフィールド、`unique symbol`など、ブランドを付けるのに使われるさまざまなテクニックを知る

---

## レシピ逆引きテーブル

| 課題 | 該当項目 |
|------|---------|
| switch文で型の網羅性を保証したい | 項目59 |
| 複数の値の組み合わせをすべて処理したい | 項目59 |
| オブジェクトのキーと値を安全に反復処理したい | 項目60 |
| 追加プロパティを持つオブジェクトを扱いたい | 項目60 |
| インターフェイス変更時に関連コードの更新を強制したい | 項目61 |
| 可変長引数関数で型の関係を保ちたい | 項目62 |
| 「どちらか一方のみ」を表現したい | 項目63 |
| 構造が同じだが意味が異なる型を区別したい | 項目64 |
| プリミティブ型にドメイン固有の意味を持たせたい | 項目64 |
