# TT-PRACTICAL-WORKFLOW — IDE 駆動ワークフローと TypeScript 固有の落とし穴

## 目次

1. [IDE 駆動ワークフロー（VS Code）](#1-ide-駆動ワークフロー)
2. [TypeScript 固有の落とし穴](#2-typescript-固有の落とし穴)

---

## 1. IDE 駆動ワークフロー

TypeScript の価値の多くは IDE の支援として現れる。VS Code では TypeScript サーバー（tsserver）がバックグラウンドで常時稼働し、リアルタイムの型情報を提供する。

### 1.1 hover で型を読む

**操作**: 変数・関数・メソッドの上にカーソルを合わせる
**起きること**: 推論された型情報・JSDoc コメント・関数シグネチャが表示される
**有用な理由**: 実行前に型を確認できる。API ドキュメントを開かずにパラメータ型と戻り値型を把握できる

```typescript
let thing = 123;
// hover → let thing: number

const audioElement = document.createElement("audio");
audioElement.p; // hover → (property) HTMLAudioElement.paused: boolean など

document.getElementById("id");
// hover → (method) Document.getElementById(elementId: string): HTMLElement | null
```

**実践**: hover は常用すること。関数名に hover するとシグネチャを確認でき、`.` の後に hover するとプロパティの型がわかる。エラー箇所にも hover すればエラーメッセージが読める。

JSDoc コメントを付けると hover に表示されるため、チームで使う関数には積極的に追加する:

```typescript
/**
 * Adds two numbers together.
 * @example
 * myFunction(1, 2); // 3
 */
const myFunction = (a: number, b: number) => a + b;
// hover → シグネチャ + コメント + @example が表示される
```

### 1.2 autocomplete の活用

**操作**: `Ctrl-Space`（手動トリガー）または自然に型を打ち始める
**起きること**: そのコンテキストで有効なプロパティ・メソッド・識別子の候補一覧が表示される
**有用な理由**: 未知の API を探索できる。タイポを防ぐ

```typescript
// オブジェクト引数の自動補完
const acceptsObj = (obj: {foo: string; bar: number; baz: boolean}) => {};
acceptsObj({
  // Ctrl-Space → foo / bar / baz が一覧表示
  // 選択のたびに残りの必須プロパティが絞られる
});

// イベント名の補完
document.addEventListener(
  "", // Ctrl-Space → "DOMContentLoaded" / "abort" / "drag" など全イベント名が表示
);
```

**注意**: 行の途中で autocomplete を使う場合は**カーソルを末尾に移動してから**実行すること。行中でトリガーすると残りのテキストを意図せず上書きする恐れがある。

自動インポートも autocomplete から行える。未インポートの識別子を入力し `Ctrl-Space` で候補を選ぶと、ファイル先頭に import 文が自動挿入される。

### 1.3 エラーメッセージの読み方

**マルチラインエラーは下から読む**。最下行に根本原因、上に向かって影響箇所が記述される。

```typescript
// 例: 関数に型の合わないオブジェクトを渡した場合の hover
Argument of type '{job: {title: number;};}' is not assignable to
parameter of type '{job: {title: string;};}'.
  The types of 'job.title' are incompatible between these types.
    Type 'number' is not assignable to type 'string'.
// ↑ 最下行が根本原因：number が string に代入不可
// 上に向かって読むと「job.title が問題」→「引数全体が不一致」とわかる
```

赤い波線に hover するとエラーが表示される。最初の行だけ読んで諦めず、最後まで（または下から）読むこと。

### 1.4 ナビゲーション（Go to Definition / References）

| 操作 | macOS | Windows |
|------|-------|---------|
| Go to Definition | `Cmd-Click` | `Ctrl-Click` / F12 |
| Go to References | 定義元で再度 `Cmd-Click` | 同上 |

**活用場面**:
- 外部ライブラリの型定義（`.d.ts`）を確認する（どんな引数・戻り値か）
- 大規模コードベースで変数の定義元を素早く特定する
- リファクタリング前に「どこで使われているか」を洗い出す

### 1.5 Rename Symbol（安全なリネーム）

**操作**: 変数を右クリック → **Rename Symbol**（または F2）
**起きること**: その識別子の全参照が一括でリネームされる。スコープを理解するため無関係な同名識別子は変更されない
**有用な理由**: find & replace とは異なり、型情報に基づく安全なリファクタリングが可能

```typescript
const filterUsersById = (id: string) => {
  return users.filter((user) => user.id === id);
};
// id を Rename Symbol で userIdToFilterBy に変更すると:
const filterUsersById = (userIdToFilterBy: string) => {
  return users.filter((user) => user.id === userIdToFilterBy);
  //                            ↑ user.id は別スコープのため変更されない
};
```

### 1.6 Quick Fixes（`Cmd-. / Ctrl-.`）

**操作**: エラー行または選択範囲で `Cmd-.`（macOS）/ `Ctrl-.`（Windows）
**起きること**: その状況に応じたリファクタリング候補が表示される

代表的な Quick Fix メニュー項目:
- **Add All Missing Imports**: 未インポートの識別子を一括でインポート
- **Extract to Function in Module Scope**: 選択コードを新規関数として抽出
- **Extract Constant in Enclosing Scope**: 選択式をローカル定数として抽出
- **Inline Variable**: 変数をインライン化して削除

```typescript
// 実例: ランダムパーセンテージ計算をリファクタリング
const func = () => {
  // 全体を選択 → Quick Fix → Extract to Function in Module Scope
  const randomPercentage = `${(Math.random() * 100).toFixed(2)}%`;
  console.log(randomPercentage);
};
// 結果:
function getRandomPercentage() {
  return `${(Math.random() * 100).toFixed(2)}%`;
}
const func = () => {
  const randomPercentage = getRandomPercentage();
  console.log(randomPercentage);
};
```

### 1.7 TS Server の再起動

型が混乱している・エラーが正しく表示されない場合:
1. `Cmd-Shift-P`（macOS）/ `Ctrl-Shift-P`（Windows）でコマンドパレットを開く
2. `Restart TS Server` を検索・実行
3. 数秒後にサーバーが再起動して型チェックが正常化する

`tsconfig.json` を変更した後や、特に大きなコードベースで型情報が乱れた場合に有効。

---

## 2. TypeScript 固有の落とし穴

### 2.1 Evolving `any` — 型が変化する変数

型注釈なしで `let` 宣言した変数は `any` として推論されるが、代入するたびに型が絞り込まれる（「evolving any」）。通常の `any` とは異なり、代入後の型で不正なメソッドを呼べばエラーになる。

```typescript
let myVar;                    // any
myVar = 659457206512;         // number
myVar.toExponential();        // OK
myVar = "mf doom";            // string
myVar.toUpperCase();          // OK
myVar.toExponential();        // Error: 'toExponential' は string に存在しない
```

配列でも同様に型が進化する:
```typescript
const arr = [];         // any[]
arr.push("abc");        // string[]
arr.push(123);          // (string | number)[]
arr.push({easy: true}); // (string | number | {easy: boolean})[]
```

**用途**: 段階的にデータを蓄積する限られたユースケース。通常は明示的な型を使うべき。

### 2.2 Excess Property Checks — Fresh vs Stale

TypeScript のオブジェクトは **オープン型**（余剰プロパティを許容）だが、「fresh（新鮮）なオブジェクト」に対してのみ余剰プロパティをチェックする。

| オブジェクトの種類 | 余剰プロパティチェック |
|-----------------|----------------------|
| インラインオブジェクトリテラル（fresh） | ✅ エラーになる |
| 変数に代入済み（stale） | ❌ エラーにならない |
| 関数の返却値（return type 注釈なし） | ❌ エラーにならない |

```typescript
interface Album { title: string; releaseYear: number }
const processAlbum = (album: Album) => {};

// stale → エラーなし（他所で余剰プロパティが必要かもしれないため）
const rubberSoul = { title: "Rubber Soul", releaseYear: 1965, label: "Parlophone" };
processAlbum(rubberSoul); // label があってもエラーなし

// fresh → エラー
processAlbum({ title: "Rubber Soul", releaseYear: 1965, label: "Parlophone" });
// Error: Object literal may only specify known properties. 'label' は Album に存在しない
```

**典型的な落とし穴**: オプションパラメータのタイポは変数経由だと検出されない。

```typescript
const options = { url: "/", timeOut: 1000 }; // timeout → timeOut のタイポ
fetch(options); // エラーなし！（stale オブジェクトなのでチェックされない）

// 対策: 変数に型注釈を付けて fresh 扱いにする
const options: { url: string; timeout?: number } = {
  url: "/",
  timeOut: 1000, // Error: 'timeOut' は型に存在しない
};
```

**関数返却時の対策**: 返却する関数にリターン型アノテーションを付ける。

```typescript
// return type を明示すれば余剰プロパティが検出される
remapAlbums(albums, (album): Album => ({
  ...album,
  releaseYear: album.releaseYear + 1,
  strangeProperty: "strange", // Error: 'strangeProperty' は Album に存在しない
}));
```

### 2.3 `Object.keys()` が `string[]` を返す理由

オープン型の帰結として `Object.keys()` は `keyof typeof obj` ではなく `string[]` を返す。実行時に型定義にないプロパティが存在しうるため。

```typescript
const yetiSeason = { title: "Yeti Season", artist: "El Michels Affair", releaseYear: 2021 };
const keys = Object.keys(yetiSeason); // string[]

keys.forEach((key) => {
  console.log(yetiSeason[key]); // Error: string で index できない
});
```

**対策パターン**:

| アプローチ | コード例 | 備考 |
|-----------|---------|------|
| 型アサーション | `key as keyof typeof yetiSeason` | 余剰プロパティがなければ安全 |
| 型を広げる | `(obj: Record<string, unknown>)` | 型安全だが汎用的すぎる |
| `Object.values()` | `Object.values(obj).forEach(...)` | キーが不要ならこれが最もシンプル |

```typescript
// アサーションを使う例
keys.forEach((key) => {
  console.log(yetiSeason[key as keyof typeof yetiSeason]); // OK
});

// Object.values を使う（キーが不要な場合の最善策）
function printUser(user: User) {
  Object.values(user).forEach(console.log);
}
```

### 2.4 Empty Object Type `{}` の真の意味

`{}` は「空のオブジェクト」ではなく「`null` と `undefined` 以外のすべての値」を意味する。

```typescript
const a: {} = "string";  // OK（string はプロパティを持てるオブジェクト）
const b: {} = 42;        // OK
const c: {} = true;      // OK
const d: {} = null;      // Error
const e: {} = undefined; // Error
```

**理由**: TypeScript のオブジェクトはオープン型なので `string` や `number` も「オブジェクト」として扱える（プロパティ・メソッドを持つ）。`null` と `undefined` だけはプロパティアクセスが実行時エラーになるため除外される。

**活用**: `null` / `undefined` を除いた任意の値を受け入れる関数の型として使える。

```typescript
const acceptNonNullable = (input: {}) => {};
acceptNonNullable("hello"); // OK
acceptNonNullable(42);      // OK
acceptNonNullable(null);    // Error
```

### 2.5 Type World と Value World の境界

TypeScript には **型の世界（type world）** と **値の世界（value world）** がある。`type` や `interface` で定義した型は型の世界にしか存在しない。

```typescript
type Album = { title: string };

processAlbum(Album); // Error: 'Album' は値として存在しない

// 値を型の世界へ持ち込む場合は typeof を使う
type AlbumReturn = ReturnType<processAlbum>; // Error: 値を直接型引数に渡せない
type AlbumReturn = ReturnType<typeof processAlbum>; // OK
```

**両方の世界をまたぐもの**:

| エンティティ | 型として意味 | 値として意味 |
|------------|------------|------------|
| `class Song` | インスタンスの型 | コンストラクタ関数 |
| `this`（クラスメソッド戻り値） | 現在のクラスインスタンス型 | 現在のインスタンス |

**同名の型と値**: 型と値を同じ名前で export すると、インポート側でどちらとしても使える。

```typescript
export const Direction = {
  Up: "up", Down: "down", Left: "left", Right: "right",
} as const;

export type Direction = (typeof Direction)[keyof typeof Direction];
// → type Direction = "up" | "down" | "left" | "right"

// 使用側: 値としても型としても Direction を import できる
import { Direction } from "./direction";
const move = (dir: Direction) => {};   // 型として使用
move(Direction.Up);                    // 値として使用
```

### 2.6 `this` の型付け（`function` キーワード限定）

`function` キーワードで定義した関数では、第一引数として `this` の型を宣言できる（実際の引数ではなく型チェック専用）。

```typescript
function sellAlbum(this: { title: string; sales: number }) {
  this.sales++;
  console.log(`${this.title} has sold ${this.sales} copies.`);
}

// this の要件を満たすオブジェクトから呼ぶ必要がある
const album = { title: "Solid Air", sales: 40000, sellAlbum };
album.sellAlbum(); // OK

// this の型を満たさないオブジェクトから呼ぶとエラー
const noTitle = { sales: 0, sellAlbum };
noTitle.sellAlbum(); // Error: 'title' property が不足
```

**アロー関数は `this` パラメータを持てない**: アロー関数は定義されたスコープの `this` を継承するため、呼び出し側の `this` を受け取れない。`this` パラメータはクラスメソッドか `function` キーワードの関数にのみ使用可能。

```typescript
const sellAlbum = (this: { title: string }) => {}; // Error: An arrow function cannot have a 'this' parameter.
```

### 2.7 関数の引数互換性ルール

関数は「受け取る引数より少なく実装する」ことは許可されているが、「定義より多く要求する」ことはエラー。

```typescript
type CallbackType = (filename: string, volume: number, bassBoost: boolean) => void;

// OK: 引数を一部だけ受け取る実装
handlePlayer((filename) => console.log(filename));      // 1引数 → OK
handlePlayer((filename, volume) => { /* ... */ });      // 2引数 → OK

// Error: 定義より多い引数を要求する実装
handlePlayer((filename, volume, bassBoost, extra) => { /* ... */ });
// Error: Target signature provides too few arguments. Expected 4 or more, but got 3.
```

**実例**: `Array.prototype.map` は常に `(element, index, array)` の3引数でコールバックを呼ぶが、必要な引数だけ宣言すれば良い。

```typescript
["a", "b", "c"].map((file) => file.toUpperCase()); // index / array を無視して OK
```

**型定義のコツ**: コールバック型は「最も引数が多いバリエーション」一つだけを定義すれば、引数が少ない実装もすべて受け入れられる。

### 2.8 関数ユニオン型はパラメータを交差させる

関数のユニオン型（`A | B`）に渡せる引数は、各関数パラメータの **交差型**（`A & B`）になる。

```typescript
const formatterFunctions = {
  title:      (album: {title: string})       => `Title: ${album.title}`,
  artist:     (album: {artist: string})      => `Artist: ${album.artist}`,
  releaseYear: (album: {releaseYear: number}) => `Year: ${album.releaseYear}`,
};

// formatterFunctions[key] の型（ユニオン）を取り出すと:
// ((album: {title: string}) => string)
// | ((album: {artist: string}) => string)
// | ((album: {releaseYear: number}) => string)

// この関数を呼ぶには交差型が必要（どの関数が呼ばれても全プロパティが必要）
const getAlbumInfo = (
  album: {title: string; artist: string; releaseYear: number}, // = 3つの交差
  key: keyof typeof formatterFunctions,
) => {
  const func = formatterFunctions[key];
  return func(album); // OK
};
```

**パラメータが互換しない場合**（`string | number | boolean` の交差 → `never`）は `as never` でのアサーションが必要になる:

```typescript
return formatter(input as never); // 型レベルの回避策（実行時は問題なし）
// ※ as any は never に代入不可なため使えない
```
