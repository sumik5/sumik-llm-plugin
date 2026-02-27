# TypeScript オブジェクト型定義パターン リファレンス

TypeScriptのオブジェクト型システムと実践的な型定義パターン。型エイリアス・インデックスシグネチャ・ジェネリクス・Map/SetなどCh3の独自コンテンツを収録。

---

## 1. オブジェクトリテラルの構文バリエーション

### 省略記法（shorthand）

```typescript
const name = "uhyo";
const age = 26;

// プロパティ名と変数名が同じなら省略可能
const human = { name, age };
// 展開: { name: name, age: age } と同じ
```

### 計算されたプロパティ名（Computed Property Names）

```typescript
const propName = "foo";
const obj = { [propName]: 123 };
// 実行時: { foo: 123 }

// 数値キーも文字列キーも型システム上は等価
const obj2 = { 0: "zero", "1": "one" };
obj2["0"] = "ZERO"; // OK
obj2[1] = "ONE";    // OK（実行時は文字列"1"として扱われる）
```

### スプレッド構文と型推論

```typescript
const obj1 = { a: 1, b: 2 };
const obj2 = { b: 3, c: 4 };

// 後ろのプロパティが優先（bは3になる）
const merged = { ...obj1, ...obj2 };
// 型: { a: number; b: number; c: number }

// 重要: スプレッドはシャローコピー
const nested = { x: { y: 1 } };
const copy = { ...nested };
copy.x.y = 99; // nested.x.yも変わる！（同じオブジェクト参照）
```

---

## 2. オブジェクトの同一性と等値比較

```typescript
// === はオブジェクト参照を比較する（値の内容ではない）
const obj1 = { x: 1 };
const obj2 = { x: 1 };
const obj3 = obj1;

console.log(obj1 === obj2); // false（別オブジェクト）
console.log(obj1 === obj3); // true（同じ参照）
```

**実践的意味**: オブジェクトの「内容が同じかどうか」を比較したい場合は
`JSON.stringify`や専用の比較ライブラリが必要。`===`では不十分。

---

## 3. 型エイリアスとオプショナル・readonly

### 基本的なオブジェクト型

```typescript
type Human = {
  name: string;          // 必須
  age?: number;          // オプショナル（age: number | undefined）
  readonly id: string;   // 読み取り専用
};

const h: Human = { name: "uhyo", id: "u001" };
// h.id = "u002"; // コンパイルエラー！
```

### `age?: number` と `age: number | undefined` の違い

```typescript
type A = { age?: number };        // age プロパティ自体が存在しなくてもOK
type B = { age: number | undefined }; // age プロパティは必ず存在しなければならない

const a: A = {};            // OK
const b: B = {};            // エラー！ age が必要
const b2: B = { age: undefined }; // OK
```

**exactOptionalPropertyTypes有効時**（推奨設定）:
`age?: number` に `undefined` を明示的に代入することも禁止される。

---

## 4. インデックスシグネチャとその危険性

```typescript
type PriceData = {
  [key: string]: number;
};

const data: PriceData = { apple: 220, coffee: 120 };

// 型上はnumberだが、実際にはundefinedが返る可能性
const bananaPrice = data.banana; // 型: number（だが実際はundefined！）
```

**問題**: インデックスシグネチャは型安全性を破壊する。存在しないキーへのアクセスも
`number`型として扱われてしまう。

**解決策: Mapを使う**

```typescript
const priceMap = new Map<string, number>([
  ["apple", 220],
  ["coffee", 120],
]);

// get()は V | undefined を返すため安全
const bananaPrice = priceMap.get("banana"); // 型: number | undefined
```

**noUncheckedIndexedAccess有効時**: インデックスシグネチャのアクセス結果が
自動的に `T | undefined` になり、安全性が向上する。

---

## 5. typeofキーワード（型の抽出）

```typescript
const obj = {
  name: "uhyo",
  age: 26,
  nested: { x: 1 }
};

// typeof で変数から型を取得
type ObjType = typeof obj;
// = { name: string; age: number; nested: { x: number } }

// 「型を先に定義する」vs「値を先に定義する」の選択
// → 値が単一のデータソースであるべきなら typeof を使う
// → 型が契約（インターフェース）であるべきなら type/interface を先に定義する
```

### keyof typeof パターン

```typescript
const Direction = {
  Up: "UP",
  Down: "DOWN",
  Left: "LEFT",
  Right: "RIGHT",
} as const;

// "Up" | "Down" | "Left" | "Right"
type DirectionKey = keyof typeof Direction;

// "UP" | "DOWN" | "LEFT" | "RIGHT"
type DirectionValue = (typeof Direction)[DirectionKey];
```

---

## 6. 部分型関係（構造的部分型）

TypeScriptは**構造的部分型**（structural subtyping）を採用。
名前ではなく構造によって型の互換性を判断する。

```typescript
type Animal = { name: string; age: number };
type Human = { name: string; age: number; skill: string };

// HumanはAnimalの部分型（Animalが持つプロパティをすべて持つ）
const uhyo: Human = { name: "uhyo", age: 26, skill: "TypeScript" };
const animal: Animal = uhyo; // OK（Human → Animal への代入）
```

### 余剰プロパティチェック（Excess Property Checking）

```typescript
// オブジェクトリテラルを直接代入する場合のみ余剰チェックが働く
type Animal = { name: string; age: number };

// エラー: Object literal may only specify known properties
const animal: Animal = { name: "cat", age: 3, species: "Felis" };

// 変数経由なら余剰プロパティも許容される
const cat = { name: "cat", age: 3, species: "Felis" };
const animal2: Animal = cat; // OK
```

---

## 7. ジェネリック型（型引数）

### 基本パターン

```typescript
// 型引数Tを持つジェネリック型
type Box<T> = {
  value: T;
  label: string;
};

const numBox: Box<number> = { value: 42, label: "number box" };
const strBox: Box<string> = { value: "hello", label: "string box" };
```

### 型引数の制約（extends）

```typescript
// Tはstring | numberの部分型でなければならない
function stringify<T extends string | number>(value: T): string {
  return String(value);
}

// KはTのキー名でなければならない
function get<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

type Human = { name: string; age: number };
const uhyo: Human = { name: "uhyo", age: 26 };

// 型安全なプロパティアクセス
const name = get(uhyo, "name"); // 型: string
const age = get(uhyo, "age");   // 型: number

// 存在しないキーはコンパイルエラー
// get(uhyo, "gender"); // エラー！
```

---

## 8. Map / Set / WeakMap / WeakSet

### Map<K, V>

```typescript
// 型安全なキーと値のペア
const userMap = new Map<string, { name: string; age: number }>();

userMap.set("u001", { name: "uhyo", age: 26 });

// get()はV | undefined を返す（安全！）
const user = userMap.get("u001"); // 型: { name: string; age: number } | undefined

// イテレーション
for (const [key, value] of userMap) {
  console.log(key, value.name);
}
```

**インデックスシグネチャとの違い**: Mapのgetは`undefined`の可能性を型として持ち、
型安全。一方オブジェクトのインデックスシグネチャは`undefined`を型に含めない危険性がある。

### Set<T>

```typescript
const set = new Set<string>(["a", "b", "c"]);

set.add("d");          // void
set.has("a");          // boolean
set.delete("b");       // boolean

// 重複は自動的に除去される
const nums = new Set([1, 2, 2, 3, 3]);
console.log([...nums]); // [1, 2, 3]
```

### WeakMap / WeakSet

```typescript
// キー（WeakMap）や要素（WeakSet）がWeakに参照される
// → キーへの参照がなくなるとGCされる（メモリリーク防止）
// → ただしイテレーション不可、sizeプロパティなし

const weakMap = new WeakMap<object, string>();
let obj = { id: 1 };
weakMap.set(obj, "metadata");
obj = null as any; // この後GCによりweakMapのエントリも消える
```

**ユースケース**: DOM要素や外部オブジェクトへのメタデータ付与、プライベートデータ管理。

---

## 9. {} 型の特殊な挙動

```typescript
// {} 型は null と undefined 以外のすべてを受け入れる
function acceptAny(value: {}) {
  console.log(value);
}

acceptAny(1);        // OK
acceptAny("hello");  // OK
acceptAny(true);     // OK
acceptAny({});       // OK
acceptAny(null);     // エラー！（strictNullChecks有効時）
acceptAny(undefined); // エラー！

// 注意: {} は「プロパティが0個のオブジェクト型」ではなく
// 「null/undefinedではない値の型」と理解する
```

---

## 10. 型 vs typeof演算子

```typescript
// typeof の2つの用法を混同しないこと

// ① typeof演算子（値の文脈）: 実行時に文字列を返す
const x = 42;
console.log(typeof x); // "number"

// ② typeof キーワード（型の文脈）: コンパイル時に型を得る
const obj = { name: "uhyo" };
type ObjType = typeof obj; // { name: string }

// 型の文脈と値の文脈を判断する規則:
// - type文・型注釈・型引数の中 → 型の文脈
// - それ以外（式として使われている）→ 値の文脈
```
