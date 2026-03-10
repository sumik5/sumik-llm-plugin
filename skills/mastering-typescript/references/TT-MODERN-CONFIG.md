# モダンTypeScript設定・高度パターン（Total TypeScript）

> **出典**: Matt Pocock著「Total TypeScript」（No Starch Press）の知見に基づく。Ch9（TypeScript-Only Features）・Ch14（tsconfig）・Ch16（Generic Functions）を中心に、現代的なTypeScript開発に必要な設定・パターンを整理。

---

## 1. 推奨 tsconfig.json（Ch14）

### Matt Pocockの推奨ベース設定

```json
{
  "compilerOptions": {
    "skipLibCheck": true,
    "target": "es2022",
    "esModuleInterop": true,
    "allowJs": true,
    "resolveJsonModule": true,
    "moduleDetection": "force",
    "isolatedModules": true,
    "strict": true,
    "noUncheckedIndexedAccess": true
  }
}
```

**各オプションの目的:**

| オプション | 説明 | 理由 |
|-----------|------|------|
| `skipLibCheck` | `.d.ts`ファイルのチェックをスキップ | ビルド高速化・サードパーティ型定義の誤りを無視 |
| `target: "es2022"` | 比較的新しいJS機能を使用可能 | `Array.at()`、`Object.hasOwn()`等のネイティブ機能を利用 |
| `esModuleInterop` | CJS/ESMの互換性向上 | `import fs from 'fs'`のようなデフォルトインポートを可能に |
| `allowJs` | JSファイルのインポートを許可 | 移行期プロジェクトや既存JSライブラリとの共存 |
| `resolveJsonModule` | JSONファイルのインポートを許可 | 設定ファイルや静的データをimportで読み込める |
| `moduleDetection: "force"` | 全`.ts`ファイルをモジュール扱い | グローバルスコープ汚染を防ぎ、各ファイルを独立モジュールに |
| `isolatedModules` | 各ファイルが独立にトランスパイル可能 | ESBuild/swc対応。`const enum`等の孤立型を禁止 |
| `strict` | 厳密型チェック一式を有効化 | `noImplicitAny`・`strictNullChecks`等を一括有効化 |
| `noUncheckedIndexedAccess` | インデックスアクセスに`undefined`を追加 | `arr[0]`が`T \| undefined`になり実行時エラーを防止 |

### 追加設定の決定木

プロジェクトの用途に応じて以下を追加する:

| 質問 | Yes の場合に追加するオプション |
|------|-------------------------------|
| tscでトランスパイルする？ | `"module": "NodeNext"`, `"outDir": "dist"`, `"sourceMap": true` |
| ライブラリを構築する？ | `"declaration": true` |
| モノレポ内のライブラリ？ | `"composite": true`, `"declarationMap": true` |
| tscでトランスパイルしない（ESBuild/swc使用）？ | `"module": "Preserve"`, `"noEmit": true` |
| DOMで実行する？ | `"lib": ["es2022", "dom", "dom.iterable"]` |
| DOM不要（Node.js等）？ | `"lib": ["es2022"]` |

**判断のポイント:**
- バンドラー（Vite/ESBuild）利用時は `noEmit: true` + `module: "Preserve"` が基本
- ライブラリ公開時は `declaration: true` で型定義ファイルを生成必須
- モノレポでは `composite: true` + `declarationMap: true` でプロジェクト参照を有効化

---

## 2. TypeScript-Only Features の注意点（Ch9）

TypeScriptには「ランタイムJSコードを生成する」独自構文が存在する。これらはTypeScriptの将来方向性とは逆行する「レガシー」として位置づけられる。

### Enums の奇妙な振る舞い

```typescript
// 数値Enum: 逆引きマッピングが自動生成される
enum AlbumStatus { NewRelease, OnSale, StaffPick }

// トランスパイル結果（簡略化）:
// {
//   0: "NewRelease", 1: "OnSale", 2: "StaffPick",
//   NewRelease: 0, OnSale: 1, StaffPick: 2
// }

// 🚨 Object.keysの罠: 6キーが返る
console.log(Object.keys(AlbumStatus));
// ["0", "1", "2", "NewRelease", "OnSale", "StaffPick"]  ← 期待は3キー!

// 文字列Enum: 逆引きなし（シンプル）
enum AlbumStatus { NewRelease = "NEW_RELEASE", OnSale = "ON_SALE" }
// { NewRelease: "NEW_RELEASE", OnSale: "ON_SALE" }

// 🚨 数値Enumは任意のnumberを受け入れる（型安全でない）
function logStatus(s: AlbumStatus) { console.log(s); }
logStatus(999); // コンパイルエラーにならない!（数値Enumのみの問題）
```

**実践例（Enumの代替）:**
```typescript
// 推奨: const assertionを使ったオブジェクト（型安全かつシンプル）
const AlbumStatus = {
  NewRelease: "NEW_RELEASE",
  OnSale: "ON_SALE",
  StaffPick: "STAFF_PICK",
} as const;
type AlbumStatus = typeof AlbumStatus[keyof typeof AlbumStatus];
```

**判断のポイント:**
- 数値Enumは `Object.keys()` が2倍のキーを返す罠がある
- 数値Enumは任意の`number`を受け入れるため型安全性が低い
- 新規コードでは `as const` オブジェクトを優先検討

---

### Namespaces

```typescript
// ❌ レガシー: ECMAScript Modules登場前のTypeScript独自モジュールシステム
namespace Utils {
  export function format(s: string): string { return s.trim(); }
}
Utils.format("  hello  ");
```

**判断のポイント:**
- 現在はレガシー。新規コードでは使用しない
- 唯一の正当なユースケース: 既存の declaration merging との互換性保持
- ESM (`import`/`export`) で代替する

---

### Class Parameter Properties（パラメータープロパティ）

```typescript
// TypeScript独自の糖衣構文
class Rating {
  constructor(public value: number, private max: number) {}
}

// ↓ コンパイル結果（ランタイムコードが生成される）
class Rating {
  constructor(value, max) {
    this.value = value;
    this.max = max;
  }
}
```

**判断のポイント:**
- 型アノテーションとは異なり「ランタイムコードを生成する」構文
- `--erasableSyntaxOnly` 有効時はエラーになる
- 新規プロジェクトでは明示的な`this.x = x`を好むチームも増えている

---

## 3. --erasableSyntaxOnly（TS 5.8+）（Ch9）

### 概念と背景

TypeScript 5.8で導入されたフラグ。TypeScriptの長期的な方向性「**JavaScript with types**」を体現する。

```
Erasable構文（削除してもランタイム動作に影響なし）:
  ✅ 型アノテーション: const x: number = 1
  ✅ interface, type alias
  ✅ generics: <T>

Non-erasable構文（ランタイムJSを生成する）:
  ❌ Enums → ランタイムオブジェクト生成
  ❌ Namespaces → ランタイムオブジェクト生成
  ❌ Parameter Properties → ランタイムthis代入生成
```

### tsconfig.json での有効化

```json
{
  "compilerOptions": {
    "erasableSyntaxOnly": true
  }
}
```

有効化すると Non-erasable 構文はコンパイルエラーになる:
```typescript
enum Direction { Up, Down }  // ❌ Error: Enums are not allowed with --erasableSyntaxOnly
```

### Node.jsネイティブTypeScriptサポートとの親和性

Node.js 22.6+ではTypeScriptを直接実行できるが、Non-erasable構文はサポートされない。`--erasableSyntaxOnly`を有効化することでNode.jsネイティブ実行との完全互換を確保できる。

**判断のポイント:**
- 新規プロジェクトでは有効化を積極的に検討
- 既存コードにEnumsが多い場合は段階的移行が必要
- TypeScriptの将来方向性として「型チェッカーのみに徹する」トレンドを理解する

---

## 4. Generic Function vs Generic Type の区別（Ch16）

### 構文の違い

```typescript
// ① Type alias for a generic function（Tは関数に属する）
type Identity = <T>(arg: T) => void;
//              ^^^  ← 関数の()の前にジェネリクス

// ② Generic type（Tは型に属する）
type Identity<T> = (arg: T) => void;
//           ^^^  ← 型名の後にジェネリクス
```

### 重要な動作の違い

```typescript
// ① Generic Function型: 呼び出し時にTを推論
declare const identity: <T>(arg: T) => T;
const result = identity(42); // T = 42（リテラル型）と推論。型引数省略可能

// ② Generic Type: 使用時にTの指定が必要
type Box<T> = { value: T };
type StringBox = Box<string>; // T = string を明示指定
type AnyBox = Box;            // ❌ Error: Generic type 'Box' requires 1 type argument
```

**実践例（使い分け）:**
```typescript
// Generic Function型: ユーティリティ関数に最適
type Mapper = <T, U>(arr: T[], fn: (item: T) => U) => U[];
const map: Mapper = (arr, fn) => arr.map(fn);

// Generic Type: データ構造・コンテナ型に最適
type Result<T, E = Error> = { ok: true; value: T } | { ok: false; error: E };
```

**判断のポイント:**
- `<T>()` の位置が型名の後か関数括弧の前かで意味が変わる
- Generic Functionは呼び出しごとにTが決まる（柔軟）
- Generic Typeはインスタンス化時にTが決まる（明示的）

---

## 5. /utils フォルダパターン（Ch16）

### 概念

ライブラリ（汎用）とアプリケーション（特定ドメイン）の中間に位置する「プロジェクト固有ユーティリティ」のパターン。

```
/utils
  ├── groupBy.ts       # コレクション操作
  ├── debounce.ts      # タイミング制御
  ├── retry.ts         # エラーハンドリング
  └── predicates.ts    # 型述語集
```

アプリが大きくなると自然に必要になる。Generic Functions + Type Predicates + Assertion Functions + Function Overloads を組み合わせて型安全なユーティリティを作る。

---

### Type Predicates（型述語）

```typescript
// value is string: narrows the type in the if branch
function isString(value: unknown): value is string {
  return typeof value === "string";
}

// 使用例
function processInput(input: string | number) {
  if (isString(input)) {
    console.log(input.toUpperCase()); // ここでは string 確定
  }
}
```

**判断のポイント:**
- 戻り値型が `boolean` ではなく `value is T` になる
- `filter()`との組み合わせで型安全なフィルタリングが可能: `arr.filter(isString)` → `string[]`

---

### Assertion Functions（アサーション関数）

```typescript
// asserts value is string: 失敗すれば例外、成功すれば以降でstring確定
function assertIsString(value: unknown): asserts value is string {
  if (typeof value !== "string") {
    throw new Error(`Expected string, got ${typeof value}`);
  }
}

// 使用例
function processInput(input: unknown) {
  assertIsString(input);
  // ここ以降 input は string 確定
  console.log(input.toUpperCase());
}
```

**判断のポイント:**
- 戻り値型が `void` ではなく `asserts value is T`
- Type Predicateとの違い: 失敗時にfalseを返すのでなく例外をスロー

---

### Function Overloads（関数オーバーロード）

```typescript
// オーバーロードシグネチャ（外部に見える契約）
function createElement(tag: "a"): HTMLAnchorElement;
function createElement(tag: "div"): HTMLDivElement;
function createElement(tag: "span"): HTMLSpanElement;
function createElement(tag: string): HTMLElement;

// 実装シグネチャ（外部からは見えない）
function createElement(tag: string): HTMLElement {
  return document.createElement(tag);
}

// 使用時: 戻り値型が自動的に絞り込まれる
const anchor = createElement("a"); // HTMLAnchorElement
const div = createElement("div");  // HTMLDivElement
```

**判断のポイント:**
- オーバーロードシグネチャは少なくとも2つ必要
- 実装シグネチャは最も広い型を受け入れる必要がある
- Union型で解決できる場合はオーバーロード不要。「入力型によって戻り値型が変わる」ケースに適用

---

## 全体まとめ: 設定・高度パターンの判断フロー

```
新規プロジェクト設定時
  ↓
ベース設定を適用（skipLibCheck, target, strict, noUncheckedIndexedAccess 等）
  ↓
用途別オプション追加
  ├─ tscでビルド → module: "NodeNext", outDir, sourceMap
  ├─ バンドラー使用 → module: "Preserve", noEmit: true
  ├─ ライブラリ公開 → declaration: true
  ├─ DOM使用 → lib: ["es2022", "dom", "dom.iterable"]
  └─ Node.jsのみ → lib: ["es2022"]
  ↓
TypeScript-Only Features の使用を判断
  ├─ Enum → as const オブジェクトで代替を検討
  ├─ Namespace → ESMで代替
  ├─ Parameter Properties → erasableSyntaxOnly有効化で明示的に禁止
  └─ → Node.jsネイティブ実行するなら特に重要
  ↓
/utils パターンの高度な型機能
  ├─ 型で絞り込みたい → Type Predicate (value is T)
  ├─ 失敗時に例外 → Assertion Function (asserts value is T)
  ├─ 入力により戻り値型が変わる → Function Overloads
  └─ 汎用コンテナ型 → Generic Type vs Generic Function を区別
```

**次章への橋渡し:**
- mastering-typescript SKILL.md の「Advanced Types」セクションで Conditional Types・Mapped Types の応用
- `enforcing-type-safety` スキルで `noUncheckedIndexedAccess` 等の設定を実践に落とし込む
