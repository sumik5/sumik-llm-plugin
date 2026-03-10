# TypeScriptコンパイラの振る舞いと型システムの深層

TypeScriptの型システムは表面的な型チェックにとどまらず、`satisfies`による型推論の制御、Fresh/Staleオブジェクトの区別、型の世界と値の世界の分離など、多くの精巧な仕組みを持ちます。本ファイルでは「Total TypeScript」（Matt Pocock著, No Starch Press）の知見をもとに、コンパイラの振る舞いを深く理解するための概念を解説します。

---

## satisfiesパターン

**判断基準**: 型アノテーションを付けると変数の型情報が「上書き」されて値の詳細型が失われる。`satisfies` を使うと、型制約を満たしているかチェックしながら、推論された型を保持できる。

```typescript
type Color = string | { r: number; g: number; b: number };

// ❌ 変数アノテーション: 型が勝つ（値の型は忘れられる）
const config: Record<string, Color> = {
  foreground: { r: 255, g: 255, b: 255 },
  background: { r: 0, g: 0, b: 0 },
  border: "transparent",
};
config.foreground.r;       // エラー! Color型 (string | {...}) では .r を参照できない
config.border.toUpperCase(); // エラー! Color型では string メソッドを呼べない

// ❌ アノテーションなし: 値の型が勝つ（制約チェックなし）
const config2 = {
  foreground: { r: 255, g: 255, b: 255 },
  notAColor: [1, 2, 3], // エラーにならない! 型制約がない
};

// ✅ satisfies: 型チェックしつつ値の型を保持（ベスト）
const config3 = {
  foreground: { r: 255, g: 255, b: 255 },
  background: { r: 0, g: 0, b: 0 },
  border: "transparent",
} satisfies Record<string, Color>;

config3.foreground.r;        // OK! { r: number; g: number; b: number } として推論
config3.border.toUpperCase(); // OK! string として推論
```

### satisfiesによるnarrowing（絞り込み）

```typescript
type Album = { format: "CD" | "Vinyl" | "Digital" };

// ❌ アノテーションあり: "CD" | "Vinyl" | "Digital" のまま
const album1: Album = { format: "Vinyl" };
album1.format; // "CD" | "Vinyl" | "Digital"

// ✅ satisfiesあり: リテラル型に絞り込まれる
const album2 = { format: "Vinyl" } satisfies Album;
album2.format; // "Vinyl"（リテラル型に絞り込まれる！）

// ✅ satisfies + as const: 完全な不変リテラル型
const album3 = { format: "Vinyl" } satisfies Album as const;
album3.format; // readonly "Vinyl"
```

### 3パターン比較表

| パターン | 型チェック | 値の型保持 | 用途 |
|---------|----------|---------|------|
| `const x: Type = value` | ✅ | ❌（Typeが勝つ） | 変数の型を明示したい場合 |
| `const x = value` | ❌ | ✅（推論が勝つ） | 制約なしで推論に任せる場合 |
| `const x = value satisfies Type` | ✅ | ✅（両方） | 制約チェックと推論を両立したい場合 |

### 覚えておくべきこと
- `satisfies` は TypeScript 4.9 で追加された演算子
- 型制約に違反していればコンパイルエラーになる（型チェックの恩恵を享受）
- 同時に推論された型（具体的な型）を保持できる（値の型の恩恵も享受）
- `satisfies` + `as const` の組み合わせで最大の型情報を引き出せる

---

## 余剰プロパティチェックの仕組み

**判断基準**: 余剰プロパティチェックは「Fresh（新鮮な）」オブジェクトにのみ適用される。変数に代入した「Stale（古い）」オブジェクトはチェックされない。

```typescript
interface Album {
  title: string;
  releaseYear: number;
}

function processAlbum(album: Album): void {
  console.log(album.title);
}

// Staleオブジェクト: 変数経由のため余剰プロパティチェックが走らない
const rubberSoul = {
  title: "Rubber Soul",
  releaseYear: 1965,
  label: "Parlophone", // 余剰プロパティ
};
processAlbum(rubberSoul); // ✅ OK! チェックされない

// Freshオブジェクト: インラインで渡すとチェックが走る
processAlbum({
  title: "Rubber Soul",
  releaseYear: 1965,
  label: "Parlophone", // エラー! 余剰プロパティはインラインでは許可されない
});
```

### 関数コールバックでのチェック回避

```typescript
type RemapAlbumsCallback = (album: Album) => Album;

function remapAlbums(albums: Album[], fn: RemapAlbumsCallback): Album[] {
  return albums.map(fn);
}

// ❌ コールバック戻り値のチェックが走らない
const newAlbums = remapAlbums(albums, (album) => ({
  ...album,
  releaseYear: album.releaseYear + 1,
  strangeProperty: "excess", // エラーにならない!
}));

// ✅ 戻り値型アノテーションを追加するとチェックが走る
const newAlbums2 = remapAlbums(albums, (album): Album => ({
  ...album,
  releaseYear: album.releaseYear + 1,
  strangeProperty: "excess", // エラー! Album型に strangeProperty は存在しない
}));
```

### Fresh vs Stale の判定基準

| シナリオ | Fresh/Stale | チェック |
|---------|------------|--------|
| オブジェクトリテラルを直接引数に渡す | Fresh | ✅ チェックされる |
| 変数に代入してから渡す | Stale | ❌ チェックされない |
| 関数の戻り値（型アノテーションなし） | Stale | ❌ チェックされない |
| 関数の戻り値（型アノテーションあり） | Fresh | ✅ チェックされる |

### 覚えておくべきこと
- 余剰プロパティチェックは型の安全性の「補助的な」機能であり、構造的型付けの例外的な動作
- オブジェクトリテラルを関数に直接渡す場合にのみチェックが走る
- 変数に代入するとチェックを回避できるが、意図的に利用する場合は慎重に

---

## Open vs Closed Object Types

**判断基準**: TypeScriptはオブジェクト型をデフォルトで「Open（開いた）」として扱い、型定義に存在しないプロパティを持つ値も代入可能とする。

```typescript
interface User {
  name: string;
  age: number;
}

// TypeScriptのデフォルト動作: Open型
// User型は { name: string; age: number; ... } を意味する（追加プロパティ許容）
const user = {
  name: "Alice",
  age: 30,
  email: "alice@example.com", // 余剰プロパティだがStaleなので代入可能
};

const u: User = user; // OK!

// Flow言語はデフォルトでClosed（追加プロパティ禁止）
// TypeScriptでClosedを実現するには never を使う
type ClosedUser = {
  name: string;
  age: number;
  [key: string]: never; // 追加プロパティを禁止
};
```

### 覚えておくべきこと
- TypeScriptの構造的型付けはOpen型が前提
- Flow言語のようなClosed型はインデックスシグネチャ `[key: string]: never` で模倣できる
- Fresh/Staleの仕組みがOpen型とExcess Property Checkの折り合いをつけている

---

## Evolving any型

**判断基準**: 変数を初期値なし（または `[]` や `null`）で宣言すると `any` 型として始まり、代入により型が「進化」していく。この挙動を理解して活用または制御する。

```typescript
// スカラー値での進化
let myVar;                    // any（初期化なし）
myVar = 659457206512;         // number に進化
myVar.toExponential();        // OK
myVar.toUpperCase();          // エラー! number には toUpperCase がない

myVar = "mf doom";            // string に進化
myVar.toUpperCase();          // OK
myVar.toExponential();        // エラー! string には toExponential がない

// 配列での進化
const arr = [];               // any[]
arr.push("abc");              // string[]
arr.push(123);                // (string | number)[]
arr.push({ name: "Alice" });  // (string | number | { name: string })[]

// ❌ null/undefined 初期化でも同様
let value = null;             // null
value = "hello";              // string | null に進化

// ✅ 型アノテーションで進化を防ぎ、早期エラー発見
const strictArr: string[] = [];
strictArr.push("abc");        // OK
strictArr.push(123);          // エラー! string[] に number は入らない
```

### 覚えておくべきこと
- 進化する any は「型の拡大」の特殊ケース
- スコープを抜けると型が確定し、以降は変化しない
- 意図的に使う場合は `any[]` や `any` と明示するよりも型アノテーションを付けることを推奨

---

## 空オブジェクト型 {} の正体

**判断基準**: `{}` 型は「空のオブジェクト」ではなく「`null` と `undefined` 以外のすべての値」を表す。この事実を知らないと予期せぬバグを生む。

```typescript
// {} は null/undefined 以外のすべてを受け入れる
function processValue(value: {}) {
  console.log(value);
}

processValue("string");         // OK!
processValue(42);               // OK!
processValue(true);             // OK!
processValue(() => {});         // OK!
processValue({ name: "Alice"}); // OK!
processValue(null);             // エラー! null は {} に代入できない
processValue(undefined);        // エラー! undefined は {} に代入できない

// 型の階層（Hierarchy）
type A = unknown;  // すべての型のスーパータイプ
type B = {};       // null/undefined 以外のすべて（unknownの直下）
type C = string;   // {} のサブタイプ
type D = never;    // すべての型のサブタイプ
```

### 型の階層図

```
unknown
  ├── {}（null/undefined 以外のすべて）
  │    ├── string
  │    ├── number
  │    ├── boolean
  │    ├── symbol
  │    ├── bigint
  │    ├── function
  │    └── object（{}ではなくObjectと等価）
  ├── null
  └── undefined

never（すべての型の底）
```

### 実用的な注意点

```typescript
// ❌ null/undefined を除外したい時に {} を使うのは副作用がある
function fn(value: {}) {
  // value は string でも number でも何でもいい
}

// ✅ null/undefined を除外したいだけなら NonNullable<T> を使う
type NonNullableValue<T> = NonNullable<T>; // T & {} と等価

// ✅ 本当に空のオブジェクトが欲しい場合
type EmptyObject = Record<string, never>;
// または
type EmptyObject2 = { [K in string]: never };
```

### 覚えておくべきこと
- `{}` と `object` は似ているようで異なる（`{}` は primitive も受け入れる）
- `null` と `undefined` を除外したいだけなら `NonNullable<T>` を使う
- `unknown` の型ガードとして `typeof value === "object" && value !== null` を使う

---

## 型の世界と値の世界

**判断基準**: TypeScriptには「型の世界（コンパイル時）」と「値の世界（ランタイム）」が共存する。同じキーワードが両世界で異なる意味を持つことを理解する。

```typescript
const myNumber: number = 42;
//    ^^^^^^^^  ^^^^^^   ^^
//    値の世界  型の世界  値の世界

// typeof は両世界で異なる意味を持つ
const str = "hello";
if (typeof str === "string") {   // 値の世界: ランタイムの型チェック
  console.log(str.toUpperCase());
}

type T = typeof str;             // 型の世界: コンパイル時の型取得 → string

// keyof は型の世界のみ
interface User { name: string; age: number; }
type UserKeys = keyof User;      // "name" | "age"（型の世界）

// in は両世界で異なる
if ("name" in user) { ... }      // 値の世界: プロパティ存在チェック
type HasName<T> = "name" extends keyof T ? true : false; // 型の世界
```

### 両世界を横断できる構文

```typescript
// class: 値（コンストラクタ関数）としても型（インターフェース）としても機能
class Animal {
  constructor(public name: string) {}
}
const myAnimal = new Animal("Cat"); // 値の世界: インスタンス生成
const a: Animal = myAnimal;        // 型の世界: 型アノテーション

// enum: 値（オブジェクト）としても型（Union）としても機能
enum Direction { Up, Down, Left, Right }
const dir = Direction.Up;          // 値の世界
const d: Direction = dir;          // 型の世界

// this: 値（レシーバー）としても型（ポリモーフィックthis）としても機能
class Builder {
  add(): this { return this; }    // 型の世界でも値の世界でも使われる
}
```

### 型の世界にのみ存在するもの

```typescript
// 型は実行時に消える（Type Erasure）
type Point = { x: number; y: number }; // コンパイル後には存在しない
interface Shape { area(): number; }     // コンパイル後には存在しない

// 実行時に型情報を使いたい場合は "value world" の手段が必要
function isPoint(value: unknown): value is Point {
  return typeof value === "object" && value !== null &&
         "x" in value && "y" in value;
}
```

### 覚えておくべきこと
- 型アノテーション（`: Type`）と型アサーション（`as Type`）は型の世界のみで動作し、ランタイムに影響しない
- `class` と `enum` は型と値の両世界に存在できる特殊な構文
- `typeof`, `in`, `instanceof` はランタイムの型ガードとして機能する（値の世界）

---

## Function Assignability（関数の代入可能性）

**判断基準**: パラメーター数が少ない関数は、多い関数型に代入可能。これはJavaScriptの慣習（配列のコールバック等）に合わせた設計である。

```typescript
type FullCallback = (filename: string, volume: number, bassBoost: boolean) => void;

// ✅ パラメーターが少ない関数は代入可能
const cb1: FullCallback = (filename) => console.log(filename);
const cb2: FullCallback = (filename, volume) => console.log(filename, volume);
const cb3: FullCallback = (filename, volume, bassBoost) => {}; // 全部使う

// 現実的な例: Array.prototype.map のコールバック
const numbers = [1, 2, 3];
numbers.map(n => n * 2);           // ✅ index, array を使わなくてもOK
numbers.map((n, i) => n + i);      // ✅ 部分的に使ってもOK
numbers.map((n, i, arr) => arr[i]); // ✅ 全部使ってもOK

// ❌ 戻り値の型は厳格
type StringCallback = () => string;
const fn: StringCallback = () => 42;  // エラー! number は string に代入できない
```

### Unions of Functions のパラメーター推論

```typescript
// Unionの関数型はパラメーターをIntersectする
type StringFn = (arg: string) => void;
type NumberFn = (arg: number) => void;
type UnionFn = StringFn | NumberFn;

declare function callFn(fn: UnionFn): void;
callFn((arg) => {
  // arg は string & number = never（両方を満たす必要がある）
  // 実際には arg: string | number として扱われることが多い
});
```

### 覚えておくべきこと
- 関数の代入可能性においてパラメーターは**反変（Contravariant）**
- 戻り値の型は**共変（Covariant）**（サブタイプを返すことは許可される）
- `strictFunctionTypes` フラグにより関数の反変チェックが強制される

---

## Mutabilityと型推論

**判断基準**: `let` と `const`、プロパティの可変性によって推論される型が変わる。`as const` と `satisfies` を組み合わせることで最大限の型情報を引き出せる。

```typescript
// let宣言: 型が広がる（Widening）
let genre = "rock";        // string（再代入可能なので広げられる）
genre = "jazz";            // OK

// const宣言: リテラル型を保持
const genre2 = "rock";    // "rock"（再代入不可なので詳細な型）
// genre2 = "jazz";        // エラー!

// オブジェクトプロパティ: constでもプロパティは可変なので型が広がる
const album = {
  title: "Abbey Road",
  releaseYear: 1969,
};
// album.title は string（"Abbey Road" ではない）
// album.releaseYear は number（1969 ではない）
album.title = "Let It Be"; // ✅ constでもプロパティは変更可能

// as const: 深い不変性（型レベル）
const album2 = {
  title: "Abbey Road",
  releaseYear: 1969,
} as const;
// album2.title は "Abbey Road"（リテラル型）
// album2.releaseYear は 1969（リテラル型）
// album2.title = "Let It Be"; // エラー! readonly

// as const と satisfies の組み合わせ
type MusicFormat = "CD" | "Vinyl" | "Digital";
type AlbumConfig = { title: string; format: MusicFormat };

const config = {
  title: "Abbey Road",
  format: "Vinyl",
} satisfies AlbumConfig as const;
// config.title は "Abbey Road"（リテラル型 + 型チェック済み）
// config.format は "Vinyl"（リテラル型 + MusicFormat制約チェック済み）
```

### as const vs Object.freeze 比較

| 機能 | `as const` | `Object.freeze()` |
|------|-----------|-------------------|
| 実行時の影響 | なし（型のみ） | あり（シャローフリーズ） |
| TypeScript型 | `readonly` + リテラル型 | `Readonly<T>` |
| ネスト | 深い（全プロパティreadonly） | 浅い（トップレベルのみ） |
| 実行時エラー | なし（silentに無視） | strict modeではエラー |

```typescript
// Object.freeze は浅い（Shallow）
const frozen = Object.freeze({ nested: { value: 1 } });
frozen.nested.value = 2; // ✅ ネストは変更可能!
// frozen.nested = {}; // ❌ トップレベルは変更不可

// as const は深い（Deep）
const constValue = { nested: { value: 1 } } as const;
// constValue.nested.value = 2; // ❌ ネストも変更不可（型レベル）
```

### 覚えておくべきこと
- `as const` は型レベルのみの変更であり、ランタイム動作は変わらない
- `Object.freeze` はランタイムで変更を防ぐが、浅いフリーズであり型情報も `Readonly<T>` 止まり
- `as const` + `satisfies` の組み合わせが最強の型安全性を提供する

---

## DervivingとDecoupling

**判断基準**: 型を既存の型から派生（Derive）するか、独立した型として定義（Decouple）するかを状況に応じて判断する。どちらにも適切な場面がある。

```typescript
// ─── Derivingの例 ───

// ✅ Deriving が適切: 密接に関連する型
const STATUS_CODES = {
  OK: 200,
  NOT_FOUND: 404,
  SERVER_ERROR: 500,
} as const;

type StatusCode = typeof STATUS_CODES[keyof typeof STATUS_CODES];
// 200 | 404 | 500 （定数オブジェクトから派生）

// STATUS_CODESを変更すると自動的にStatusCodeも更新される ✅

// ─── Decouplingの例 ───

// ❌ Deriving が不適切: 異なる責務の型
interface User {
  id: string;
  name: string;
  email: string;
  imageUrl: string;
  createdAt: Date;
  updatedAt: Date;
}

// ❌ UserからAvatarImagePropsを派生するのは過度なカップリング
type AvatarImageProps = Pick<User, "imageUrl" | "name">;
// Userに変更があるたびにAvatarImagePropsも影響を受ける

// ✅ 独立した型として定義する方が良い
type AvatarImageProps2 = {
  imageUrl: string;
  name: string;
};
// AvatarImagePropsの責務はUI表示であり、Userドメインとは独立している
```

### Deriving vs Decoupling の判断基準

| 判断基準 | Deriving が適切 | Decoupling が適切 |
|---------|---------------|-----------------|
| 責務の関係 | 同一の関心事（データ変換・型の派生） | 異なる責務（ドメイン境界をまたぐ） |
| 変更の伝播 | 元の型の変更を自動追従したい | 変更を独立させたい |
| 典型的な例 | `as const` オブジェクト → 型導出 | `User` → `AvatarImageProps` |
| パターン | `typeof`, `keyof`, `ReturnType`, `Awaited` | 独立した型定義 |

```typescript
// ✅ Derivingが有効な典型例: ユーティリティ型の連鎖
async function fetchUser(id: string) {
  // ... 実装
  return { id, name: "Alice", email: "alice@example.com" };
}

// 戻り値の型を派生させる（関数の実装と自動同期）
type FetchedUser = Awaited<ReturnType<typeof fetchUser>>;
// { id: string; name: string; email: string }

// ✅ Decouplingが有効な典型例: APIレスポンス型とドメイン型の分離
type ApiUserResponse = {
  user_id: string;   // snake_case
  user_name: string;
};

type DomainUser = {
  id: string;        // camelCase
  name: string;
};
// これらは独立した型として定義すべき（責務が異なる）
```

### 覚えておくべきこと
- Derivingのメリット: DRY原則、変更の自動伝播、型の一貫性
- Derivingのデメリット: カップリングの増加、変更の意図しない波及
- **Decouplingが適切な場面**: 異なる責務を持つ境界（UI層とドメイン層、APIとドメイン等）
- **Derivingが適切な場面**: 密接に関連するデータ（定数オブジェクトからの型生成、関数の戻り値型の再利用）

---

## 判断フローチャート: satisfies vs アノテーション vs as const

```
型制約を満たすか確認したい？
│
├─ YES: 値の詳細な型（リテラル型など）を保持したい？
│  ├─ YES: → satisfies（型チェック + 推論保持）
│  │       → 不変性も必要なら satisfies ... as const
│  └─ NO:  → 変数アノテーション（: Type）
│
└─ NO: 不変性（Immutability）が必要？
   ├─ YES: → as const
   └─ NO:  → アノテーションなし（TypeScriptに推論を任せる）
```

---

## 参考: Total TypeScript対応章

| セクション | 参照章 |
|-----------|-------|
| satisfiesパターン | Chapter 11 |
| 余剰プロパティチェック | Chapter 12 |
| Open vs Closed Object Types | Chapter 12 |
| Evolving any型 | Chapter 3 |
| 空オブジェクト型 {} | Chapter 5 |
| 型の世界と値の世界 | Chapter 2 |
| Function Assignability | Chapter 12 |
| Mutabilityと型推論 | Chapter 7 |
| DervivingとDecoupling | Chapter 10 |
