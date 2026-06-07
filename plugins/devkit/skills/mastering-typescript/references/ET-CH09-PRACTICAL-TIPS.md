# CH09 実践のコツ

コードを書いて実行する際の実践的なヒントと注意点を解説します。TypeScriptの独自機能とECMAScript標準の違い、デバッグ、型の実行時検証、パフォーマンス最適化などを扱います。

---

## 項目72　TypeScriptの独自機能の使用を避け、ECMAScriptの機能を使う

**判断基準**: TypeScriptの機能を選択する際、それがECMAScript標準か、TypeScript独自の機能かを区別し、可能な限り標準機能を使用します。

**基本原則**: TypeScriptは「型を持つJavaScript」であるべき。型を取り除けばJavaScriptになる状態を保つ。

### 避けるべきTypeScript独自機能

#### 1. `enum`（代替: 文字列リテラルのユニオン型）

**問題点**:
- 複数の種類があり挙動が異なる（数値enum、文字列enum、const enum）
- 文字列enumは名前的型付けされている（構造的型付けと矛盾）
- JavaScriptユーザーとTypeScriptユーザーで開発体験が乖離

```typescript
// 悪い例: enum
enum Flavor {
  Vanilla = 'vanilla',
  Chocolate = 'chocolate',
  Strawberry = 'strawberry',
}

function scoop(flavor: Flavor) { /* ... */ }
scoop('vanilla'); // 型エラー（TypeScriptユーザーのみ）
scoop(Flavor.Vanilla); // OK

// 良い例: 文字列リテラル型のユニオン
type Flavor = 'vanilla' | 'chocolate' | 'strawberry';

function scoop(flavor: Flavor) { /* ... */ }
scoop('vanilla'); // OK（すべてのユーザーで一貫）
```

#### 2. パラメータープロパティ（代替: 通常のプロパティ定義）

**問題点**:
- コンパイル時にコードが書き足される
- クラスの設計が分かりづらくなる
- パラメーターが未使用に見える

```typescript
// 悪い例: パラメータープロパティ
class Person {
  first: string;
  last: string;
  constructor(public name: string) {
    [this.first, this.last] = name.split(' ');
  }
}
// プロパティが3つあるが、2つしか見えない

// 良い例: 通常のプロパティ
class Person {
  name: string;
  first: string;
  last: string;
  constructor(name: string) {
    this.name = name;
    [this.first, this.last] = name.split(' ');
  }
}

// 代替: interfaceとオブジェクトリテラル
interface Person {
  name: string;
}
const p: Person = { name: 'Jed Bartlet' };
```

#### 3. `namespace`とトリプルスラッシュインポート（代替: ES2015モジュール）

**歴史的機能**: ECMAScript 2015以前のモジュールシステム代替

```typescript
// 悪い例: namespace
namespace foo {
  export function bar() {}
}
/// <reference path="other.ts"/>

// 良い例: ES2015モジュール
export function bar() {}
import { bar } from './other';
```

#### 4. 実験的デコレーター（代替: 標準デコレーター）

**注意**: `experimentalDecorators`を使用している場合は標準版への移行を計画

```typescript
// tsconfig.json を確認
{
  "compilerOptions": {
    // "experimentalDecorators": true // これがあれば非標準
  }
}

// 標準デコレーター（TypeScript 5.0+）
class Greeter {
  @logged
  greet() {
    return `Hello, ${this.greeting}`;
  }
}

function logged(originalFn: any, context: ClassMethodDecoratorContext) {
  return function(this: any, ...args: any[]) {
    console.log(`Calling ${String(context.name)}`);
    return originalFn.call(this, ...args);
  };
}
```

#### 5. メンバーのアクセス修飾子（代替: ECMAScriptプライベートフィールド）

**問題点**: TypeScriptの`private`は実行時に消える

```typescript
// 悪い例: TypeScriptのprivate（型レベルのみ）
class Diary {
  private secret = 'my secret';
}
const diary = new Diary();
(diary as any).secret; // 実行時にアクセス可能

// 良い例: ECMAScriptプライベートフィールド（実行時にも保護）
class PasswordChecker {
  #passwordHash: number;

  constructor(passwordHash: number) {
    this.#passwordHash = passwordHash;
  }

  checkPassword(password: string) {
    return hash(password) === this.#passwordHash;
  }
}

const checker = new PasswordChecker(hash('s3cret'));
checker.#passwordHash; // 型エラー + 実行時エラー
```

**注意**: `readonly`は型レベルの構文で、使用しても問題ありません。

### 覚えておくべきこと

- 大まかに言って、コードからすべての型を取り除けば、TypeScriptからJavaScriptに変換できる
- `enum`、パラメータープロパティ、トリプルスラッシュインポート、実験的デコレーター、メンバーのアクセス修飾子はこのルールの歴史的な例外である
- コードベースにおけるTypeScriptの役割を可能なかぎり明確にし、将来の互換性の問題を回避するため、非標準の機能の使用を避ける

---

## 項目73　ソースマップを使ってTypeScriptをデバッグする

**判断基準**: ブラウザやNode.jsでTypeScriptのコードをデバッグする際、常にソースマップを使用します。

**ソースマップの設定**:

```json
// tsconfig.json
{
  "compilerOptions": {
    "sourceMap": true
  }
}
```

これにより`.js`ファイルと`.js.map`ファイルが生成されます。

**ブラウザでのデバッグ**:

```typescript
// index.ts
function addCounter(el: HTMLElement) {
  let clickCount = 0;
  const button = document.createElement('button');
  button.textContent = 'Click me';
  button.addEventListener('click', async () => {
    clickCount++;
    const response = await fetch(`http://numbersapi.com/${clickCount}`);
    const trivia = await response.text();
    button.textContent = `Click me (${clickCount})`;
  });
  el.appendChild(button);
}

addCounter(document.body);
```

ソースマップがあれば、ブラウザーの開発者ツールで元のTypeScriptコードが表示され、ブレークポイントの設定や変数の検査が可能になります。

**Node.jsでのデバッグ**:

```typescript
// bedtime.ts
async function sleep(ms: number) {
  return new Promise<void>(resolve => setTimeout(resolve, ms));
}

async function main() {
  console.log('Good night!');
  await sleep(1000);
  console.log('Morning already!?');
}

main();
```

デバッグ手順:

```bash
# TypeScriptをコンパイル（sourceMapを有効にしておく）
tsc bedtime.ts

# デバッグモードで実行
node --inspect-brk bedtime.js

# ブラウザで chrome://inspect にアクセスして接続
```

**注意点**:

1. **バンドラーとの併用**:
   - バンドラー（webpack、viteなど）もソースマップを生成する場合がある
   - 最終的に元のTypeScriptソースにマップされるよう設定を確認
   - バンドラーがTypeScriptを組み込みサポートしていれば、デフォルトで正しく設定されるはず

2. **本番環境での配信**:
   - JavaScriptファイルがソースマップへの参照を持っていても、デバッガーが開いているときだけロード
   - インラインのソースマップは常にダウンロードされるため本番環境では避ける
   - ソースマップに元のコードのコピーが含まれる場合、公開したくない情報（コメント、内部URL等）に注意

### 覚えておくべきこと

- 生成されたJavaScriptを使ってデバッグしない。ソースマップを使用し、実行時でもTypeScriptコードを使ってデバッグする
- 最終的に使われるコードから元のコードに至るまで、ソースマップが完全にマッピングされていることを確認する
- TypeScriptで書かれたNode.jsのコードをデバッグする方法を知っておく
- 設定によっては、ソースマップに元のコードのインラインコピーが含まれるかもしれない。何が含まれるか把握していないなら、ソースマップを公開しないこと

---

## 項目74　実行時に型を再構築する方法を知る

**判断基準**: 外部データ（API、ユーザー入力など）を検証し、TypeScriptの型と一致することを保証したい場合に使用します。

**問題**: TypeScriptの型は実行時に消去される

```typescript
interface Comment {
  author: string;
  content: string;
  timestamp: number;
}

function processComment(comment: Comment) {
  // 型は静的チェックのみ。実行時には何でも入る可能性がある
}
```

**解決策の選択肢**:

### 1. Zodのような実行時型システム

**長所**:
- TypeScriptの型を推論できる
- 詳細なバリデーション（メールアドレス、整数など）が可能
- 追加のビルドステップが不要

**短所**:
- 型定義の方法が2つになる（TypeScript構文とZod構文）
- 伝染性がある（依存する型もZodで定義が必要）

```typescript
import { z } from 'zod';

const commentSchema = z.object({
  author: z.string(),
  content: z.string(),
  timestamp: z.number(),
});

type Comment = z.infer<typeof commentSchema>;

function processComment(data: unknown) {
  const comment = commentSchema.parse(data); // 検証 + 型アサーション
  // comment は Comment 型として扱える
}
```

### 2. スキーマからTypeScriptの型を生成（json-schema-to-typescript）

**長所**:
- 外部仕様が信頼できる情報源になる
- JSON Schemaは広く使われている標準

**短所**:
- 追加のビルドステップが必要
- スキーマのメンテナンスが必要

```bash
npm install -D json-schema-to-typescript

json2ts comment-schema.json > comment.ts
```

### 3. TypeScriptの型からスキーマを生成（typescript-json-schema）

**長所**:
- TypeScriptの型が信頼できる情報源
- 外部のTypeScriptの型を参照できる

**短所**:
- 追加のビルドステップが必要

```bash
npm install -D typescript-json-schema

typescript-json-schema tsconfig.json Comment --out comment-schema.json
```

**選択のガイドライン**:

| 状況 | 推奨アプローチ |
|------|--------------|
| 外部スキーマがある（OpenAPI、JSON Schema等） | スキーマからTypeScriptの型を生成 |
| 外部のTypeScript型を参照する必要がある | `typescript-json-schema`を使用 |
| スキーマが頻繁に変更される | Zodのような実行時型システム |
| 複雑なバリデーションが必要 | Zodのような実行時型システム |

### 覚えておくべきこと

- TypeScriptの型はコードの実行前に消去される。追加のツールを利用しなければ、実行時にアクセスできない
- 実行時の型の選択肢を知っておく。（Zodのような）TypeScriptの型とは異なる実行時の型システムを使用する、スキーマからTypeScriptの型を生成する（`json-schema-to-typescript`）、またはTypeScriptの型からスキーマを生成する（`typescript-json-schema`）
- 型を定義するTypeScriptの外部の仕様（スキーマなど）がある場合は、それを信頼できる情報源として使う
- 外部のTypeScriptの型を参照する必要がある場合は、`typescript-json-schema`または同等のツールを使う
- それ以外の場合は、追加のビルドステップと、型を定義する新しい方法と、どちらがいいか考える

---

## 項目75　DOMの型階層を理解する

**判断基準**: ブラウザ向けのTypeScriptコードを書く際、適切な具体性を持つDOM型を使用します。

**DOM型の階層**:

```
EventTarget
  ↑
Node
  ↑
Element
  ↑
HTMLElement
  ↑
HTMLInputElement, HTMLButtonElement, etc.
```

**具体的な型を使用する**:

```typescript
// 悪い例: 曖昧な型
function handleInput(el: Element) {
  el.value; // 型エラー: Element には value がない
}

// 良い例: 具体的な型
function handleInput(el: HTMLInputElement) {
  el.value; // OK
  el.focus(); // OK
}
```

**イベントの型**:

```typescript
// 基本のEvent
function handleEvent(e: Event) {
  e.target; // EventTarget | null
  e.currentTarget; // EventTarget | null
}

// 具体的なMouseEvent
function handleClick(e: MouseEvent) {
  e.clientX; // OK
  e.clientY; // OK
  e.button; // OK
}

// さらに具体的な型推論
button.addEventListener('click', (e) => {
  // e は MouseEvent と推論される
  console.log(e.clientX);
});
```

**型を推論させる**:

```typescript
// 良い例: TypeScriptに型を推論させる
const button = document.querySelector('button');
// button: HTMLButtonElement | null

button?.addEventListener('click', (e) => {
  // e: MouseEvent
  console.log(e.clientX);
});

// 型アサーションが必要な場合
const input = document.getElementById('username') as HTMLInputElement;
input.value = 'Alice';
```

### 覚えておくべきこと

- DOMには型階層があるが、JavaScriptを書いているときは通常は無視できる。しかし、これらの型はTypeScriptではより重要になる。これらを理解すれば、ブラウザー向けにTypeScriptを書く際に役立つ
- `Node`、`Element`、`HTMLElement`、`EventTarget`の違いや、`Event`と`MouseEvent`の違いを知っておく
- コードではDOM要素やイベントに対して十分具体的な型を使用するか、それを推論できるような文脈をTypeScriptに与える

---

## 項目76　ターゲットとする環境の正確なモデルを作る

**判断基準**: コードが実行される環境（ブラウザ、Node.js、両方など）に応じて、TypeScriptの設定とlib指定を最適化します。

**環境に応じたlib設定**:

```json
// tsconfig.json（ブラウザ専用）
{
  "compilerOptions": {
    "lib": ["ES2020", "DOM"],
    "target": "ES2020"
  }
}

// tsconfig.json（Node.js専用）
{
  "compilerOptions": {
    "lib": ["ES2020"],
    "target": "ES2020",
    "types": ["node"]
  }
}
```

**グローバル変数のモデリング**:

```typescript
// globals.d.ts
declare const API_KEY: string;
declare const VERSION: string;

// 使用
console.log(API_KEY); // OK
```

**複数の環境を扱う（プロジェクト参照）**:

```
project/
  ├── client/
  │   └── tsconfig.json  # lib: ["ES2020", "DOM"]
  ├── server/
  │   └── tsconfig.json  # lib: ["ES2020"], types: ["node"]
  └── tsconfig.json      # 参照を設定
```

```json
// ルートの tsconfig.json
{
  "files": [],
  "references": [
    { "path": "./client" },
    { "path": "./server" }
  ]
}

// client/tsconfig.json
{
  "compilerOptions": {
    "lib": ["ES2020", "DOM"],
    "composite": true,
    "declaration": true
  }
}

// server/tsconfig.json
{
  "compilerOptions": {
    "lib": ["ES2020"],
    "types": ["node"],
    "composite": true,
    "declaration": true
  }
}
```

**型宣言のバージョン管理**:

```json
// package.json
{
  "devDependencies": {
    "@types/node": "^20.0.0",  // Node.js 20に対応
    "typescript": "^5.0.0"
  }
}
```

### 覚えておくべきこと

- コードは特定の環境で実行される。その環境の正確な静的モデルを作成すれば、TypeScriptはコードのチェックをより適切に行うようになる
- コードと一緒にWebページに読み込まれるグローバル変数やライブラリをモデリングする
- 型宣言のバージョンと、使用するライブラリや実行環境のバージョンを一致させる
- 複数の`tsconfig.json`ファイルとプロジェクト参照を使って、1つのプロジェクト内で複数の異なる環境をモデリングする（たとえば、クライアントとサーバー）

---

## 項目77　型チェックとユニットテストの関係を理解する

**判断基準**: 型チェックとユニットテストの役割分担を理解し、両方を適切に活用します。

**型チェックとユニットテストの違い**:

| 観点 | 型チェック | ユニットテスト |
|------|-----------|---------------|
| 対象 | すべての可能な入力 | 特定の入力 |
| 保証 | 型レベルの正しさ | 動作の正しさ |
| 実行タイミング | コンパイル時 | テスト実行時 |
| カバレッジ | 型で表現できる範囲 | テストケース次第 |

**型チェックが得意なこと**:

```typescript
// 型チェックで検出可能
function add(a: number, b: number): number {
  return a + b;
}

add(1, '2'); // 型エラー
add(1); // 型エラー
```

**ユニットテストが得意なこと**:

```typescript
// 型チェックでは検出できない（ユニットテストが必要）
function divide(a: number, b: number): number {
  return a / b;
}

// テスト
describe('divide', () => {
  it('should divide numbers correctly', () => {
    expect(divide(6, 2)).toBe(3);
  });

  it('should handle division by zero', () => {
    expect(divide(6, 0)).toBe(Infinity);
  });
});
```

**型エラーとなる入力をテストすべきか？**

**推奨**: 通常は不要。TypeScriptユーザーが間違った型で呼び出すことは想定しない。

```typescript
// 避けるべき
it('should reject string input', () => {
  expect(() => add(1, '2' as any)).toThrow();
});

// セキュリティやデータ破損の懸念がある場合のみ
function processPayment(amount: number) {
  // 実行時バリデーション（JavaScriptからの呼び出しに備えて）
  if (typeof amount !== 'number' || amount < 0) {
    throw new Error('Invalid amount');
  }
  // ...
}
```

### 覚えておくべきこと

- 型チェックとユニットテストは、プログラムの正しさを証明するための互いに異なる補完的な技術である。両方が必要だ
- ユニットテストは特定の入力に対して動作が正しいことを実証し、型チェックはある種の不正確な動作をすべて排除する
- 型チェックは型チェッカーに頼る。型によってチェックできない動作に対してはユニットテストを書く
- セキュリティやデータ破損に関する懸念がないかぎり、型エラーとなるような入力のテストは避ける

---

## 項目78　コンパイラーのパフォーマンスに注意を払う

**判断基準**: TypeScriptのビルドが遅い、またはエディターの反応が遅い場合に、パフォーマンス最適化を検討します。

**2つのパフォーマンス問題**:

1. **ビルドのパフォーマンス**（`tsc`）
2. **エディターの反応時間**（`tsserver`）

**基本的な最適化戦略**:

### 1. 型チェックをビルドから分離

```json
// tsconfig.json
{
  "compilerOptions": {
    "noEmit": true  // 型チェックのみ
  }
}
```

別のツール（webpack、viteなど）でトランスパイルを行い、`tsc --noEmit`で型チェックのみ実行。

### 2. デッドコードの削除

```bash
# 使われていないファイルを特定
npx ts-prune

# 使われていない依存パッケージを特定
npx depcheck
```

### 3. インクリメンタルビルド

```json
// tsconfig.json
{
  "compilerOptions": {
    "incremental": true,
    "tsBuildInfoFile": ".tsbuildinfo"
  }
}
```

### 4. プロジェクト参照

大規模なモノリポで有効:

```json
// tsconfig.json（ルート）
{
  "files": [],
  "references": [
    { "path": "./src" },
    { "path": "./test" }
  ]
}

// src/tsconfig.json
{
  "compilerOptions": {
    "composite": true,
    "declaration": true
  },
  "include": ["**/*"]
}

// test/tsconfig.json
{
  "compilerOptions": {
    "composite": true,
    "declaration": true
  },
  "references": [{ "path": "../src" }],
  "include": ["**/*"]
}
```

**注意点**:
- `noEmit`を使っているとプロジェクト参照は役に立たない
- 少数の大きなプロジェクトを作る（1000個の小さなプロジェクトは避ける）

### 5. 型を単純にする

```typescript
// 悪い例: 複雑な型
type Complex = A & B & C & D & E;

// 良い例: interfaceの拡張
interface Simple extends A, B, C, D, E {}

// 悪い例: 大きなユニオン
type ManyOptions = 'a' | 'b' | 'c' | /* ... 100個 */ | 'zz';

// 良い例: 必要に応じて分割
type CommonOptions = 'a' | 'b' | 'c';
type RareOptions = 'x' | 'y' | 'z';
type AllOptions = CommonOptions | RareOptions;
```

### 6. 戻り値の型アノテーション

```typescript
// 型推論の作業を省略
function complexFunction(): ReturnType {
  // ...
}
```

**パフォーマンス診断ツール**:

```bash
# ビルド時間の計測
tsc --diagnostics

# 詳細な診断
tsc --extendedDiagnostics

# 型の複雑さを視覚化（ツリーマップ）
npx ts-unused-exports
```

### 覚えておくべきこと

- TypeScriptのパフォーマンス問題には、ビルドのパフォーマンス（`tsc`）に関するものとエディターの反応時間（`tsserver`）に関するものがある。それぞれの症状を認識し、それに応じて最適化を行う
- 型チェックをビルドプロセスから切り離す
- デッドコードや使われていない依存パッケージを削除し、型の依存によるコードの肥大化に注意する。ツリーマップを使用して、TypeScriptがコンパイルしているものを視覚化する
- インクリメンタルビルドとプロジェクト参照を使用して、ビルドの間に`tsc`が行う作業を減らす
- 型を単純にする。大きなユニオンを避け、`type`のインターセクションではなく`interface`の拡張を使用し、関数に戻り値の型アノテーションを付けることを検討する

---

## TypeScript環境設定ガイド

### tsconfig.json設定の優先順位

#### 必須設定（最重要）

```json
{
  "compilerOptions": {
    "strict": true,              // すべての厳密チェックを有効化
    "target": "ES2020",          // 出力するJavaScriptのバージョン
    "module": "ESNext",          // モジュールシステム
    "moduleResolution": "node",  // モジュール解決方法
    "esModuleInterop": true,     // CommonJSとの相互運用性
    "skipLibCheck": true         // .d.tsファイルのチェックをスキップ（高速化）
  }
}
```

#### 推奨設定（品質向上）

```json
{
  "compilerOptions": {
    "noImplicitReturns": true,     // すべての分岐でreturnを強制
    "noUnusedLocals": true,        // 未使用のローカル変数を検出
    "noUnusedParameters": true,    // 未使用のパラメーターを検出
    "noFallthroughCasesInSwitch": true  // switchのfall-throughを禁止
  }
}
```

#### パフォーマンス最適化

```json
{
  "compilerOptions": {
    "incremental": true,           // インクリメンタルビルド
    "tsBuildInfoFile": ".tsbuildinfo",
    "sourceMap": true,             // デバッグ用（開発時のみ）
    "declaration": true,           // .d.tsファイル生成（ライブラリの場合）
    "declarationMap": true         // .d.ts.mapファイル生成
  }
}
```

#### 環境別設定

**ブラウザ向け**:
```json
{
  "compilerOptions": {
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "target": "ES2015"
  }
}
```

**Node.js向け**:
```json
{
  "compilerOptions": {
    "lib": ["ES2020"],
    "types": ["node"],
    "target": "ES2020"
  }
}
```

### パフォーマンス最適化のポイント

1. **段階的な最適化**:
   - まず測定する（`tsc --diagnostics`）
   - ボトルネックを特定する
   - 最も効果的な最適化から実施

2. **型の複雑さ管理**:
   - 過度に複雑な型を避ける
   - `interface`の拡張を優先
   - 戻り値の型を明示

3. **依存関係の管理**:
   - 不要な依存を削除
   - `@types`の重複を避ける
   - 推移的依存に注意

4. **ビルド戦略**:
   - 型チェックとトランスパイルを分離
   - プロジェクト参照で大規模コードを管理
   - インクリメンタルビルドを活用
