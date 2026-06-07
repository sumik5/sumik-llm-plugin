# CH08 型宣言と`@types`

TypeScriptの依存関係管理と型宣言の公開・管理方法について解説します。ライブラリ本体と型宣言が別パッケージとして提供される場合の問題と解決策を理解し、優れた型宣言を作成・共有する方法を学びます。

---

## 項目65　TypeScriptと`@types`は`devDependencies`に追加する

**判断基準**: TypeScript関連のパッケージを`package.json`のどのセクションに追加すべきか判断する際に参照します。

**依存パッケージの種類**:

| セクション | 用途 | 推移的インストール |
|-----------|------|-------------------|
| `dependencies` | 実行時に必要 | あり |
| `devDependencies` | 開発・テスト時のみ必要 | なし |
| `peerDependencies` | 実行時に必要だが管理の責任を負いたくない | 条件付き |

**TypeScriptと@typesの配置**:

```json
{
  "devDependencies": {
    "@types/react": "^18.2.23",
    "typescript": "^5.2.2"
  },
  "dependencies": {
    "react": "^18.2.0"
  }
}
```

**理由**:
- TypeScriptは開発ツールであり、実行時には存在しない
- 公開されるのはJavaScriptコードであり、TypeScriptのコードではない
- `@types`への推移的依存を避けることで、利用者の環境をクリーンに保つ

**インストールコマンド**:

```bash
# TypeScriptをプロジェクトに追加
npm install --save-dev typescript

# ライブラリと型宣言を追加
npm install react
npm install --save-dev @types/react

# 実行
npx tsc
```

**Webアプリケーションでの利点**:
- 本番環境に`dependencies`のみをインストール可能（`npm install --production`）
- 依存パッケージ自動更新ツールで`dependencies`を優先できる
- セキュリティアップデートに集中できる

### 覚えておくべきこと

- `package.json`の`dependencies`と`devDependencies`の違いを理解する
- TypeScriptをプロジェクトの`devDependencies`に追加する。TypeScriptをシステム全体にインストールしない
- `@types`も`dependencies`ではなく、`devDependencies`に追加する

---

## 項目66　型宣言の依存関係に関わる3つのバージョンを理解する

**判断基準**: 型エラーや実行時エラーが依存関係のバージョンミスマッチに起因している可能性がある場合に、この項目を参照して問題を診断します。

**3つのバージョン**:
1. パッケージのバージョン（例: `react@18.2.0`）
2. 型宣言のバージョン（例: `@types/react@18.2.23`）
3. TypeScriptのバージョン（例: `typescript@5.2.2`）

**バージョンの対応関係**:

```bash
$ npm install react@18.2.0
$ npm install --save-dev @types/react@18.2.23
```

メジャー・マイナーバージョン（`18.2`）は一致させ、パッチバージョンは型宣言側が大きくなることが一般的です。

**よくあるミスマッチとその解決策**:

### 1. ライブラリを更新したが型宣言を更新し忘れた

**症状**:
- 新機能を使おうとすると型エラーが発生
- 破壊的変更があった場合、型チェックをパスしても実行時エラーが発生

**解決策**:
- 型宣言を更新してバージョンを同期させる
- オーグメンテーションで一時的に新機能を追加（項目71参照）
- DefinitelyTypedに貢献して型宣言を更新

### 2. 型宣言がライブラリより先に進んでいる

**症状**:
- 型チェッカーは最新APIを期待するが、実行時は古いAPIを使用
- 存在しないプロパティやメソッドにアクセスして実行時エラー

**解決策**:
- ライブラリをアップグレード、または型宣言をダウングレード

### 3. 型宣言がより新しいTypeScriptを必要とする

**症状**:
- `@types`宣言自体で型エラーが発生
- 新しい型システムの機能を使用している

**解決策**:
- TypeScriptをアップグレード
- 古いバージョンの型宣言を使用（`npm install --save-dev @types/react@ts4.9`）
- `declare module`で型をもみ消す（最終手段）

### 4. @typesの依存パッケージの重複

**症状**:
- 宣言の重複エラー
- 宣言がマージできないエラー

**診断**:
```bash
npm ls @types/foo
```

**解決策**:
- `@types/foo`または`@types/bar`の依存バージョンを更新して互換性を持たせる

**型宣言のバンドルとDefinitelyTypedの比較**:

| 方式 | 長所 | 短所 |
|------|------|------|
| **バンドル** (`types` in package.json) | バージョン一致が保証される | 型エラーがあっても修正できない、推移的依存が問題になる |
| **DefinitelyTyped** | コミュニティでメンテナンス、推移的依存が自然 | バージョン管理が必要 |

**推奨**: TypeScriptで書かれたライブラリは型をバンドル、JavaScriptライブラリはDefinitelyTypedで公開

### 覚えておくべきこと

- 型宣言の依存関係に関わるバージョンは3つある。ライブラリのバージョン、`@types`のバージョン、TypeScriptのバージョンである
- バージョンミスマッチのタイプごとに、どのような症状がもたらされるか認識する
- ライブラリを更新した場合は、対応する`@types`も必ず更新する
- 型をバンドルすることと、DefinitelyTypedで公開することの長所と短所を理解する。ライブラリがTypeScriptで書かれている場合は型をバンドルし、そうでない場合はDefinitelyTypedで公開することが推奨される

---

## 項目67　パブリックなAPIで使われるすべての型をエクスポートする

**判断基準**: ライブラリを公開する際に、どの型をエクスポートすべきか判断する際に参照します。

**問題**: エクスポートしていない型でも取り出せる

```typescript
// library.ts
interface SecretName {
  first: string;
  last: string;
}

interface SecretSanta {
  name: SecretName;
  gift: string;
}

export function getGift(name: SecretName, gift: string): SecretSanta {
  // ...
}
```

**ユーザー側のコード**:

```typescript
// ユーザーは型を取り出せる
type MySanta = ReturnType<typeof getGift>;
// type MySanta = SecretSanta

type MyName = Parameters<typeof getGift>[0];
// type MyName = SecretName
```

**推奨**: パブリックAPIで使用する型は明示的にエクスポート

```typescript
export interface SecretName {
  first: string;
  last: string;
}

export interface SecretSanta {
  name: SecretName;
  gift: string;
}

export function getGift(name: SecretName, gift: string): SecretSanta {
  // ...
}
```

**理由**:
- ユーザーはいずれにせよ型を取り出せる
- 明示的にエクスポートしたほうが使いやすい
- 型隠蔽による柔軟性の維持は破綻している

### 覚えておくべきこと

- どのような使われ方であれ、パブリックメソッドで使われる型はすべてエクスポートする。ユーザーはいずれにせよそれらを取り出せるので、より簡単に使えるようにしたほうがよい

---

## 項目68　APIのコメントにTSDocを使う

**判断基準**: パブリックAPIにドキュメントを付ける際に、エディターで適切に表示されるようTSDoc形式を使用します。

**悪い例**: インラインコメント

```typescript
// あいさつ文を作る。結果は表示用にフォーマットされる。
function greet(name: string, title: string) {
  return `Hello ${title} ${name}`;
}
```

**良い例**: TSDoc形式

```typescript
/**
 * あいさつ文を作る。
 * @param name あいさつする相手の名前
 * @param title あいさつする相手の肩書き
 * @returns 読みやすいようにフォーマットされたあいさつ文
 */
function greet(name: string, title: string) {
  return `Hello ${title} ${name}`;
}
```

**型定義へのTSDoc**:

```typescript
/** ある時間にある場所で行われた運動量の計測 */
interface Measurement {
  /** 計測の行われた場所 */
  position: Vector3D;
  /** 計測の行われた時間、UNIXエポックからの秒数 */
  time: number;
  /** 観測された運動量 */
  momentum: Vector3D;
}
```

**マークダウンのサポート**:

```typescript
/**
 * データを処理します。
 *
 * **重要**: 以下の形式に対応:
 * - JSON
 * - XML
 * - CSV
 *
 * @param data 入力データ
 */
function process(data: string) { /* ... */ }
```

**非推奨のマーク**:

```typescript
/**
 * @deprecated 代わりに `newMethod` を使用してください
 */
function oldMethod() { /* ... */ }
```

**注意点**:
- JSDocの型情報指定（`@param {string} name`）は使わない（型情報はTypeScriptの型で伝える）
- 短く、要点を押さえたコメントにする

### 覚えておくべきこと

- エクスポートされた関数、クラス、型のドキュメントを書くのに、JSDoc/TSDoc形式のコメントを使用する。そうすれば、エディターが適切なタイミングでその情報をユーザーに表示できる
- `@param`や`@returns`、フォーマットのためのマークダウンを使用する
- 型情報をドキュメントに含めることは避ける
- 非推奨になったAPIを`@deprecated`とマークする

---

## 項目69　コールバックの`this`がAPIの一部なら、それに型を与える

**判断基準**: コールバック関数で`this`を使用するAPIを設計する際、または既存のそのようなAPIを使用する際に参照します。

**JavaScriptの`this`の動作**:

```typescript
class C {
  vals = [1, 2, 3];
  logSquares() {
    for (const val of this.vals) {
      console.log(val ** 2);
    }
  }
}

const c = new C();
c.logSquares(); // OK

const method = c.logSquares;
method(); // TypeError: Cannot read properties of undefined (reading 'vals')
```

**解決策1: アロー関数でthisをバインド**:

```typescript
class ResetButton {
  render() {
    return makeButton({text: 'Reset', onClick: this.onClick});
  }
  onClick = () => {
    alert(`Reset ${this}`); // このthisはResetButtonインスタンスを参照
  }
}
```

**APIで`this`を使用する場合の型付け**:

```typescript
// ライブラリ側
function bindAll<T extends object>(
  obj: T,
  ...keys: Array<keyof T>
): void {
  for (const key of keys) {
    const fn = obj[key];
    if (typeof fn === 'function') {
      obj[key] = fn.bind(obj);
    }
  }
}

// コールバックにthisの型を与える
interface MyButton {
  text: string;
  onClick: (this: MyButton, event: Event) => void;
}

function makeButton(options: MyButton): HTMLButtonElement {
  const button = document.createElement('button');
  button.textContent = options.text;
  button.addEventListener('click', function(event) {
    options.onClick.call(this, event); // thisはMyButtonのインスタンス
  });
  return button;
}
```

**使用例**:

```typescript
const button = makeButton({
  text: 'Click me',
  onClick(event) {
    console.log(this.text); // OK: thisはMyButton型
  }
});
```

### 覚えておくべきこと

- `this`のバインドの仕組みを理解する
- コールバックの`this`がAPIの一部なら、それに型を与える
- 新しいAPIでは、動的な`this`のバインドを避ける

---

## 項目70　型を部分的にコピーして依存を断ち切る

**判断基準**: 公開するnpmパッケージで、型の推移的依存を避けたい場合に使用します。

**問題**: 型宣言の推移的依存が不要な依存を引き起こす

```typescript
// 悪い例: 他の@typesに依存
import { SomeType } from '@types/some-library';

export function myFunction(param: SomeType) { /* ... */ }
```

この場合、ユーザーは`@types/some-library`もインストールする必要があります。

**解決策: 構造的型付けを活用して必要な部分のみコピー**:

```typescript
// 良い例: 必要な部分のみ定義
interface Buffer {
  toString(encoding?: string): string;
  // Node.jsのBufferから必要な部分のみ抜粋
}

export function processBuffer(buf: Buffer): string {
  return buf.toString('utf8');
}
```

**例: Node.jsへの依存を断ち切る**:

```typescript
// 悪い例
import { EventEmitter } from 'events';
export class MyEmitter extends EventEmitter { /* ... */ }

// 良い例
interface EventEmitter {
  on(event: string, listener: (...args: any[]) => void): this;
  emit(event: string, ...args: any[]): boolean;
}

export class MyEmitter implements EventEmitter {
  // 必要なメソッドのみ実装
}
```

**注意点**:
- 実行時の動作には影響しない（型チェックのみ）
- 組み込みの型をより厳密にするのに向いている
- 実行時の現実を反映しない型宣言は避ける

### 覚えておくべきこと

- 公開するnpmパッケージでは、型の推移的依存関係を避ける
- 構造的型付けを使って本質的でない依存を断ち切る
- JavaScriptユーザーに`@types`への依存を強制しない。Web開発者にNode.jsへの依存を強制しない

---

## 項目71　モジュールオーグメンテーションを使って型を改善する

**判断基準**: 既存のライブラリの型宣言に問題がある場合や、組み込みAPIの使用を制限したい場合に使用します。

**基本的なオーグメンテーション**:

```typescript
// 既存の型にプロパティを追加
declare module 'some-library' {
  interface ExistingInterface {
    newProperty: string;
  }
}
```

**メソッドを無効化する**:

```typescript
// 危険なメソッドの使用を禁止
declare global {
  interface Set<T> {
    /** @deprecated Use Array instead */
    constructor(values?: readonly T[]): void;
  }
}
```

**グローバル変数に型を追加**:

```typescript
// カスタムプロパティを型安全に追加
declare global {
  interface Window {
    myCustomProperty: string;
  }
}

window.myCustomProperty = 'value'; // OK
```

**注意点**:
- オーグメンテーションはスコープの問題を伴う
- 実行時にプロパティが存在しない可能性がある場合は`undefined`を含める
- 型レベルでしか機能しない（実行時の動作は変わらない）

### 覚えておくべきこと

- 宣言のマージを使って、既存のAPIを改善したり、問題のある機能の使用を禁止したりする
- `void`やエラー文字列を戻り値にしてメソッドを「ノックアウト」し、`@deprecated`とマークする
- オーバーロードは型レベルでしか適用されないことを覚えておく。型を現実から乖離させない

---

## 型宣言ベストプラクティスチェックリスト

### パッケージ管理
- [ ] TypeScriptを`devDependencies`に追加している
- [ ] `@types`を`devDependencies`に追加している
- [ ] ライブラリと型宣言のバージョンが同期している
- [ ] バージョンミスマッチを理解し対処できる

### 型のエクスポート
- [ ] パブリックAPIで使用するすべての型をエクスポートしている
- [ ] 推移的な型依存を避けている（または適切に管理している）
- [ ] 構造的型付けを活用して不要な依存を断ち切っている

### ドキュメント
- [ ] パブリックAPIにTSDocコメントを付けている
- [ ] `@param`と`@returns`を使用している
- [ ] 型情報をコメントで繰り返していない
- [ ] 非推奨のAPIに`@deprecated`を付けている

### APIの型安全性
- [ ] コールバックの`this`が型付けされている
- [ ] 型宣言とライブラリの実装が一致している
- [ ] オーグメンテーションを適切に使用している
