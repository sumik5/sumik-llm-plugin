# TypeScript付録集（A〜H統合）

> 型演算子、Utility Types、宣言の振る舞い、.d.ts書き方、トリプルスラッシュ、TSCフラグ、TSX、ESLint

## 目次

1. [型演算子一覧](#1-型演算子一覧付録a)
2. [型ユーティリティ一覧](#2-型ユーティリティ一覧付録b)
3. [宣言の振る舞い](#3-宣言の振る舞い付録c)
4. [.d.tsファイルの書き方](#4-dtsファイルの書き方付録d)
5. [トリプルスラッシュディレクティブ](#5-トリプルスラッシュディレクティブ付録e)
6. [安全性に関するTSCフラグ](#6-安全性に関するtscフラグ付録f)
7. [TSX型付けフック](#7-tsx型付けフック付録g)

---

## 1. 型演算子一覧（付録A）

### 判断基準テーブル

| 型演算子 | 構文 | 使用対象 |
|---------|------|---------|
| 型クエリー | `typeof`, `instanceof` | 任意の型 |
| キー | `keyof` | オブジェクト型 |
| プロパティ取得 | `O[K]` | オブジェクト型 |
| マップ型 | `[K in O]` | オブジェクト型 |
| 修飾子付加 | `+` | オブジェクト型 |
| 修飾子削除 | `-` | オブジェクト型 |
| 読取専用修飾子 | `readonly` | オブジェクト型、配列型、タプル型 |
| オプション修飾子 | `?` | オブジェクト型、タプル型、関数パラメーター型 |
| 条件型 | `?` | ジェネリック型、型エイリアス、関数パラメーター型 |
| 非null断言 | `!` | null許容型 |
| ジェネリックデフォルト | `=` | ジェネリック型 |
| 型アサーション | `as`, `<>` | 任意の型 |
| 型ガード | `is` | 関数戻り値型 |

---

## 2. 型ユーティリティ一覧（付録B）

### 判断基準テーブル

| 型ユーティリティ | 使用対象 | 説明 |
|---------------|---------|------|
| `ConstructorParameters` | クラスコンストラクター型 | コンストラクターパラメーター型のタプル |
| `Exclude<T, U>` | 合併型 | Uに割当可能な型をTから除外 |
| `Extract<T, U>` | 合併型 | Uに割当可能な型をTから選択 |
| `InstanceType` | クラスコンストラクター型 | newでインスタンス化した型 |
| `NonNullable` | null許容型 | null/undefinedを除外 |
| `Parameters` | 関数型 | 関数パラメーター型のタプル |
| `Partial<T>` | オブジェクト型 | 全プロパティをオプション化 |
| `Pick<T, K>` | オブジェクト型 | 指定キーのみのサブタイプ |
| `Omit<T, K>` | オブジェクト型 | 指定キーを除外したサブタイプ |
| `Readonly<T>` | 配列型、オブジェクト型、タプル型 | 全プロパティを読取専用化 |
| `ReadonlyArray` | 任意の型 | イミュータブル配列 |
| `Record<K, V>` | オブジェクト型 | キーから値へのマッピング |
| `Required<T>` | オブジェクト型 | 全プロパティを必須化 |
| `ReturnType` | 関数型 | 関数戻り値型 |
| `ThisParameterType` | 関数型 | thisパラメーター型 |
| `OmitThisParameter` | 関数型 | thisパラメーターを除いた型 |
| `ThisType` | 任意の型 | thisコンテキストのマーカー |

---

## 3. 宣言の振る舞い（付録C）

### 3.1 型/値の生成テーブル

| キーワード | 型を生成するか | 値を生成するか |
|----------|-------------|-------------|
| `class` | はい | はい |
| `const`, `let`, `var` | いいえ | はい |
| `enum` | はい | はい |
| `function` | いいえ | はい |
| `interface` | はい | いいえ |
| `namespace` | いいえ | はい |
| `type` | はい | いいえ |

### 3.2 マージ可能性テーブル

| マージ元 ↓ \ マージ先 → | 値 | クラス | 列挙型 | 関数 | 型エイリアス | インターフェース | 名前空間 | モジュール |
|---------------------|---|-------|-------|-----|----------|-------------|---------|----------|
| 値 | × | × | × | × | ○ | ○ | × | --- |
| クラス | --- | × | × | × | × | ○ | ○ | --- |
| 列挙型 | --- | --- | ○ | × | × | × | ○ | --- |
| 関数 | --- | --- | --- | × | ○ | ○ | ○ | --- |
| 型エイリアス | --- | --- | --- | --- | × | × | ○ | --- |
| インターフェース | --- | --- | --- | --- | --- | ○ | ○ | --- |
| 名前空間 | --- | --- | --- | --- | --- | --- | ○ | --- |
| モジュール | --- | --- | --- | --- | --- | --- | --- | ○ |

**凡例:** ○ = マージ可能、× = マージ不可、--- = 考慮不要

---

## 4. .d.tsファイルの書き方（付録D）

### 4.1 TypeScriptと型のみの等価表

| TypeScript (.ts) | 型宣言 (.d.ts) |
|-----------------|---------------|
| `var a = 1` | `declare var a: number` |
| `let a = 1` | `declare let a: number` |
| `const a = 1` | `declare const a: 1` |
| `function a(b) { return b.toFixed() }` | `declare function a(b: number): string` |
| `class A { b() { return 3 } }` | `declare class A { b(): number }` |
| `namespace A {}` | `declare namespace A {}` |
| `type A = number` | `type A = number` |
| `interface A { b?: string }` | `interface A { b?: string }` |

### 4.2 エクスポートパターン

#### グローバルエクスポート（スクリプトモード）

```typescript
// グローバル変数
declare let someGlobal: GlobalType

// グローバルクラス
declare class GlobalClass {}

// グローバル関数
declare function globalFunction(): string

// グローバル列挙型
enum GlobalEnum {A, B, C}

// グローバル名前空間
namespace GlobalNamespace {}
```

#### ES2015エクスポート

```typescript
// デフォルトエクスポート
declare let defaultExport: SomeType
export default defaultExport

// 名前付きエクスポート
export class SomeExport {
  a: SomeOtherType
}

// 型エクスポート
export type SomeType = {a: number}
export interface SomeOtherType {b: string}
```

#### CommonJSエクスポート

```typescript
// 単一エクスポート
declare let defaultExport: SomeType
export = defaultExport

// 複数エクスポート（名前空間利用）
declare namespace MyNamedExports {
  export let someExport: SomeType
  export type SomeType = number
  export class OtherExport {
    otherType: string
  }
}
export = MyNamedExports

// デフォルト + 名前付き（宣言マージ）
declare namespace MyExports {
  export let someExport: SomeType
  export type SomeType = number
}
declare function MyExports(a: number): string
export = MyExports
```

#### UMDエクスポート

```typescript
// ES2015と同じ + グローバル宣言
export class SomeExport {a: SomeType}
export type SomeType = {a: number}

export as namespace MyModule  // スクリプトモードでグローバル利用可能
```

### 4.3 モジュール拡張パターン

#### グローバル名前空間拡張（jQueryプラグイン例）

```typescript
// jquery-extensions.d.ts（スクリプトモード）
interface JQuery {
  marquee(speed: number): JQuery<HTMLElement>
}
```

```typescript
// 利用側
import $ from 'jquery'
$(myElement).marquee(3)
```

#### モジュール拡張（React例）

```typescript
import 'react'  // モジュールモード化

declare module 'react' {
  interface Component<P, S> {
    reducer(action: object, state: S): S
  }
}
```

**注意:** モジュール拡張は脆弱（読込順序依存）。可能ならコンポジションを使用。

---

## 5. トリプルスラッシュディレクティブ（付録E）

### 5.1 推奨ディレクティブ

| ディレクティブ | 構文 | 用途 |
|-------------|------|------|
| `amd-module` | `<amd-module name="MyComponent" />` | AMDモジュール名宣言 |
| `lib` | `<reference lib="dom"/>` | lib依存宣言（tsconfig推奨） |
| `path` | `<reference path="./path.ts" />` | ファイル依存宣言（outFile時） |
| `types` | `<reference types="./path.d.ts" />` | 型宣言ファイル依存宣言 |

### 5.2 内部ディレクティブ

| ディレクティブ | 構文 | 用途 |
|-------------|------|------|
| `no-default-lib` | `<reference no-default-lib="true" />` | lib不使用宣言（通常不要） |

### 5.3 非推奨ディレクティブ

| ディレクティブ | 構文 | 代替手段 |
|-------------|------|---------|
| `amd-dependency` | `<amd-dependency path="./a.ts" name="MyComponent" />` | `import`使用 |

---

## 6. 安全性に関するTSCフラグ（付録F）

### 判断基準テーブル

| フラグ | 説明 |
|-------|------|
| `alwaysStrict` | `'use strict'`出力 |
| `noEmitOnError` | 型エラー時にJS出力しない |
| `noFallthroughCasesInSwitch` | switch全caseでreturn/break強制 |
| `noImplicitAny` | any推論時エラー |
| `noImplicitReturns` | 全コードパスでreturn強制 |
| `noImplicitThis` | thisアノテートなし使用時エラー |
| `noUnusedLocals` | 未使用ローカル変数警告 |
| `noUnusedParameters` | 未使用パラメーター警告（`_`プレフィックスで無視可） |
| `strictBindCallApply` | bind/call/apply型安全強制 |
| `strictFunctionTypes` | 関数パラメーター反変強制 |
| `strictNullChecks` | nullを型に昇格 |
| `strictPropertyInitialization` | クラスプロパティ初期化強制 |

**推奨:** `"strict": true`で全フラグ有効化。

---

## 7. TSX型付けフック（付録G）

### 7.1 TSX要素の種類

```
TSX要素
├── 固有要素（intrinsic）: <li>, <div> など（小文字）
└── 値ベース要素（value-based）: <MyComponent />（パスカルケース）
    ├── 関数コンポーネント
    └── クラスコンポーネント
```

### 7.2 グローバルJSX名前空間のフック

```typescript
declare global {
  namespace JSX {
    // ❶ 値ベースTSX要素の型
    interface Element extends React.ReactElement<any> {}

    // ❷ 値ベースクラスコンポーネントインスタンス型
    interface ElementClass extends React.Component<any> {
      render(): React.ReactNode
    }

    // ❸ 属性を参照するプロパティ名
    interface ElementAttributesProperty {
      props: {}
    }

    // ❹ 子の型を参照するプロパティ名
    interface ElementChildrenAttribute {
      children: {}
    }

    // ❺ プロパティ型の別宣言場所（propTypes/defaultProps）
    type LibraryManagedAttributes<C, P> = // ...

    // ❻ 全固有要素がサポートする属性（key等）
    interface IntrinsicAttributes extends React.Attributes {}

    // ❼ 全クラスコンポーネントがサポートする属性（ref等）
    interface IntrinsicClassAttributes<T> extends React.ClassAttributes<T> {}

    // ❽ HTML要素の型定義
    interface IntrinsicElements {
      a: React.DetailedHTMLProps<
        React.AnchorHTMLAttributes<HTMLAnchorElement>,
        HTMLAnchorElement
      >
      // ...すべてのHTML要素
    }
  }
}
```

**用途:**
- React以外でTSXを使用するライブラリー開発時にカスタマイズ
- 通常は触れる必要なし

---

## まとめ

### 付録の活用方法

| 付録 | ユースケース |
|-----|------------|
| A. 型演算子 | 型操作の構文を素早く確認 |
| B. 型ユーティリティ | 標準Utility Types一覧 |
| C. 宣言の振る舞い | 型/値生成、マージ可否の判断 |
| D. .d.ts書き方 | サードパーティーJS型付け |
| E. トリプルスラッシュ | 特殊コンパイラー指示（稀） |
| F. TSCフラグ | strictモードの詳細理解 |
| G. TSX | React等のカスタマイズ（稀） |

### 重要な判断基準テーブル

**優先的に覚えるべき3つ:**

1. **型演算子テーブル（付録A）**: 日常的に使用
2. **型ユーティリティテーブル（付録B）**: 頻繁に使用
3. **宣言マージテーブル（付録C）**: エラー解決に必須

**参照頻度が高い2つ:**

4. **.d.tsエクスポートパターン（付録D）**: サードパーティー型付け時
5. **TSCフラグテーブル（付録F）**: tsconfig設定時
