# JavaScriptとの相互運用

> TypeScriptとJavaScriptの型安全な統合、漸進的移行、型宣言ファイルの作成と管理

## 目次

1. [型宣言（Type Declarations）](#1-型宣言type-declarations)
2. [JavaScriptからTypeScriptへの漸進的移行](#2-javascriptからtypescriptへの漸進的移行)
3. [JavaScriptの型の探索](#3-javascriptの型の探索)
4. [サードパーティーJavaScriptの使用](#4-サードパーティーjavascriptの使用)
5. [まとめ](#5-まとめ)

---

## 1. 型宣言（Type Declarations）

### 1.1 型宣言とは

型宣言（`.d.ts`ファイル）は、型付けされていないJavaScriptコードにTypeScriptの型を結びつける方法。

**型宣言の特徴:**
- 型だけを含む（値を含まない）
- `declare`キーワードで値の存在を宣言
- エクスポートされる型のみを宣言

**型宣言とTypeScriptコードの違い:**

```typescript
// Observable.ts（TypeScript実装）
export class Observable<T> implements Subscribable<T> {
  public _isScalar: boolean = false
  constructor(subscribe?: (this: Observable<T>, subscriber: Subscriber<T>) => TeardownLogic) {
    if (subscribe) this._subscribe = subscribe
  }
  subscribe(observer?: PartialObserver<T>): Subscription
  subscribe(next?: (value: T) => void, error?: (error: any) => void, complete?: () => void): Subscription
  subscribe(...args: any[]): Subscription { /* 実装 */ }
}

// Observable.d.ts（型宣言）
export declare class Observable<T> implements Subscribable<T> {
  _isScalar: boolean
  constructor(subscribe?: (this: Observable<T>, subscriber: Subscriber<T>) => TeardownLogic);
  subscribe(observer?: PartialObserver<T>): Subscription
  subscribe(next?: (value: T) => void, error?: (error: any) => void, complete?: () => void): Subscription
}
```

### 1.2 型宣言の用途

| 用途 | 説明 |
|------|------|
| TypeScriptユーザー向け型提供 | コンパイル済みJSに対応する`.d.ts`で型情報を提供 |
| エディターサポート | VSCodeなどが型ヒントを提示 |
| コンパイル時間短縮 | 不必要な再コンパイルを回避 |

### 1.3 アンビエント宣言の種類

#### 1.3.1 アンビエント変数宣言

グローバル変数の存在をTypeScriptに伝える。

```typescript
// グローバルなprocess.envを宣言
declare let process: {
  env: {
    NODE_ENV: 'development' | 'production'
  }
}

// 実際の定義
process = {
  env: {
    NODE_ENV: 'production'
  }
}
```

#### 1.3.2 アンビエント型宣言

プロジェクト全体でグローバルに利用可能な型を宣言。

```typescript
// types.ts（スクリプトモード）
type ToArray<T> = T extends unknown[] ? T : T[]

type UserID = string & {readonly brand: unique symbol}
```

明示的なインポートなしで、任意のファイルから利用可能。

#### 1.3.3 アンビエントモジュール宣言

JavaScriptモジュールに型を宣言。

```typescript
// 基本形式
declare module 'module-name' {
  export type MyType = number
  export type MyDefaultType = {a: string}
  export let myExport: MyType
  let myDefaultExport: MyDefaultType
  export default myDefaultExport
}

// 型のみ宣言（実装は後回し）
declare module 'unsafe-module-name'

// ワイルドカード利用
declare module 'json!*' {
  let value: object
  export default value
}

declare module '*.css' {
  let css: CSSRuleList
  export default css
}
```

---

## 2. JavaScriptからTypeScriptへの漸進的移行

### 2.1 移行ステップ全体像

```
1. TSCを追加 → allowJs: true
2. 型チェック有効化 → checkJs: true（オプション）
3. JSDocアノテーション追加（オプション）
4. ファイルを.tsにリネーム
5. strictフラグを有効化
```

### 2.2 ステップ1: TSCを追加

```json
// tsconfig.json
{
  "compilerOptions": {
    "allowJs": true
  }
}
```

- JavaScriptファイルもTSCでコンパイル可能に
- 型チェックは行わない（トランスパイルのみ）

### 2.3 ステップ2: JavaScript型チェック有効化（オプション）

```json
{
  "compilerOptions": {
    "allowJs": true,
    "checkJs": true
  }
}
```

**ファイル単位で制御:**
- `// @ts-check`: 個別ファイルでチェック有効
- `// @ts-nocheck`: 個別ファイルでチェック無効

**JavaScript型推論の特徴:**
- すべての関数パラメーターはオプション
- プロパティ型は使用法から推論
- オブジェクト・クラス・関数に後から追加可能

### 2.4 ステップ3: JSDocアノテーション（オプション）

```javascript
/**
 * @param word {string} 変換すべき入力文字列
 * @returns {string} パスカルケースでの文字列
 */
export function toPascalCase(word) {
  return word.replace(
    /\w+/g,
    ([a, ...b]) => a.toUpperCase() + b.join('').toLowerCase()
  )
}
```

**推論結果:** `(word: string) => string`

### 2.5 ステップ4: ファイルを.tsにリネーム

**2つの戦略:**

| 戦略 | アプローチ | メリット | デメリット |
|------|----------|----------|----------|
| 正しく行う | 型を正確に付け、noImplicitAnyを有効化 | 長期的に安全 | 時間がかかる |
| すばやく行う | anyを許容、strictを無効化、段階的に厳格化 | 短期的に移行完了 | 一時的に型安全性が低い |

### 2.6 ステップ5: 厳格化

```json
{
  "compilerOptions": {
    "allowJs": false,
    "checkJs": false,
    "strict": true
  }
}
```

---

## 3. JavaScriptの型の探索

TypeScriptは以下のアルゴリズムでJavaScriptファイルの型宣言を探索。

### 3.1 同一プロジェクト内の場合

```
1. 同名の.d.tsファイルを探す
   例: old-file.js → old-file.d.ts

2. allowJs + checkJsがtrueなら型推論（JSDocも利用）

3. それ以外はanyとして扱う
```

### 3.2 サードパーティーモジュールの場合

```
1. ローカルの型宣言を探す
   例: types.d.ts内のdeclare module 'foo'

2. package.jsonのtypes/typingsフィールドを参照

3. node_modules/@types/ディレクトリを探す
   例: @types/react

4. 上記3ステップに進む
```

**探索例:**

```
my-app/
├── node_modules/
│   ├── @types/
│   │   └── react/        ← 型宣言
│   └── react/            ← 実装
├── src/
│   ├── index.ts
│   └── types.d.ts
```

---

## 4. サードパーティーJavaScriptの使用

### 4.1 3つのシナリオ

| シナリオ | 対応 |
|---------|------|
| 型宣言を備えている | そのまま使用可能 |
| DefinitelyTypedで入手可能 | `@types/`パッケージをインストール |
| 型宣言が存在しない | 以下のオプションから選択 |

### 4.2 型宣言が存在しない場合の対処

#### オプション1: @ts-ignoreで個別無視

```typescript
// @ts-ignore
import Unsafe from 'untyped-module'

Unsafe  // any
```

#### オプション2: 空の型宣言でモジュール全体を許可

```typescript
// types.d.ts
declare module 'nearby-ferret-alerter'
```

#### オプション3: アンビエントモジュール宣言を作成

```typescript
// types.d.ts
declare module 'nearby-ferret-alerter' {
  export default function alert(loudness: 'soft' | 'loud'): Promise<void>
  export function getFerretCount(): Promise<number>
}
```

#### オプション4: npmに公開

1. GitHubリポジトリにPR
2. またはDefinitelyTypedにコントリビュート

### 4.3 DefinitelyTyped利用

```bash
# ライブラリインストール
npm install lodash --save

# 型宣言インストール
npm install @types/lodash --save-dev
```

**検索方法:**
- TypeSearch: https://microsoft.github.io/TypeSearch/
- または直接`npm install @types/<package>`を試行

---

## 5. まとめ

### 5.1 TypeScript-JavaScript相互運用の方法

| アプローチ | tsconfig設定 | 型安全性 |
|----------|-------------|---------|
| 型付けなしJSインポート | `{"allowJs": true}` | 貧弱 |
| JSチェック有効 | `{"allowJs": true, "checkJs": true}` | まあまあ |
| JSDocアノテーション | `{"allowJs": true, "checkJs": true, "strict": true}` | 非常によい |
| 型宣言付きJS | `{"allowJs": false, "strict": true}` | 非常によい |
| TypeScript | `{"allowJs": false, "strict": true}` | 非常によい |

### 5.2 重要ポイント

**型宣言ファイル:**
- `.d.ts`は型のみを含む
- `declare`で値の存在を確約
- スクリプトモードのファイルに配置

**漸進的移行:**
- 一度に1ファイルずつ移行
- checkJsとJSDocで段階的型付け
- strictフラグで最終的な厳格化

**サードパーティーJS:**
- まず組み込み型宣言を確認
- 次にDefinitelyTyped（@types）を探す
- 最終手段として自作＆公開
