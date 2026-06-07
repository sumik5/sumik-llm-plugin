# TypeScriptのビルドと実行

> tsconfig設定、プロジェクト参照、サーバー・ブラウザー実行、npm公開、トリプルスラッシュディレクティブ

## 目次

1. [TypeScriptプロジェクトのビルド](#1-typescriptプロジェクトのビルド)
2. [サーバー上での実行](#2-サーバー上での実行)
3. [ブラウザー内での実行](#3-ブラウザー内での実行)
4. [npmへの公開](#4-npmへの公開)
5. [トリプルスラッシュディレクティブ](#5-トリプルスラッシュディレクティブ)

---

## 1. TypeScriptプロジェクトのビルド

### 1.1 推奨プロジェクトレイアウト

```
my-app/
├── dist/              # コンパイル結果
│   ├── index.d.ts
│   ├── index.js
│   └── services/
│       ├── foo.d.ts
│       ├── foo.js
│       ├── bar.d.ts
│       └── bar.js
├── src/               # ソースコード
│   ├── index.ts
│   └── services/
│       ├── foo.ts
│       └── bar.ts
```

**理由:**
- ソースと成果物の明確な分離
- ビルドツール統合が容易
- ソース管理除外が容易

### 1.2 成果物の種類

| 種類 | 拡張子 | tsconfig設定 | デフォルト |
|------|--------|-------------|----------|
| JavaScript | `.js` | `{"emitDeclarationOnly": false}` | はい |
| ソースマップ | `.js.map` | `{"sourceMap": true}` | いいえ |
| 型宣言 | `.d.ts` | `{"declaration": true}` | いいえ |
| 宣言マップ | `.d.ts.map` | `{"declarationMap": true}` | いいえ |

**ソースマップの利点:**
- デバッグ時に元のTSコード表示
- スタックトレースをTSにマップ
- 本番環境でも有効（ブラウザーは条件付き）

### 1.3 コンパイルターゲット（target）

#### 1.3.1 TSCがトランスパイルする機能

| バージョン | 機能 |
|-----------|------|
| ES2015 | const/let、for..of、スプレッド、クラス、ジェネレーター、アロー関数、デフォルト/レストパラメーター、分割代入 |
| ES2016 | べき乗演算子（**） |
| ES2017 | async/await |
| ES2018 | asyncイテレーター |
| ES2019 | catchでオプションパラメーター |
| ESNext | 数値区切り文字（123_456） |

#### 1.3.2 TSCがトランスパイルしない機能（ポリフィル必要）

| バージョン | 機能 |
|-----------|------|
| ES5 | オブジェクトgetter/setter |
| ES2015 | Regexpのy/uフラグ |
| ES2018 | Regexpのsフラグ |
| ESNext | BigInt（123n） |

#### 1.3.3 target設定

```json
{
  "compilerOptions": {
    "target": "es5"  // es3/es5/es2015/es2016/es2017/es2018/esnext
  }
}
```

**推奨:**
- 迷ったら`es5`（最大互換性）
- Node.js管理下なら`es2015`以降
- ブラウザーターゲットはサポート範囲で判断

### 1.4 ライブラリー設定（lib）

```json
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["es2015", "es2016.array.includes", "dom"]
  }
}
```

**libの役割:**
- ターゲット環境で利用可能な機能をTSCに通知
- 実装は提供しない（ポリフィルが必要）

**ポリフィル方法:**
- core-js: https://www.npmjs.com/package/core-js
- @babel/polyfill: https://babeljs.io/docs/en/babel-polyfill

### 1.5 プロジェクト参照（Project References）

大規模プロジェクトのコンパイル時間を劇的に短縮。

#### 1.5.1 設定手順

**1. プロジェクト分割:**

```
my-app/
├── common/
│   ├── tsconfig.json
│   └── src/
├── backend/
│   ├── tsconfig.json
│   └── src/
├── frontend/
│   ├── tsconfig.json
│   └── src/
└── tsconfig.json
```

**2. サブプロジェクトのtsconfig.json:**

```json
{
  "compilerOptions": {
    "composite": true,              // サブプロジェクトマーク
    "declaration": true,            // .d.ts生成（必須）
    "declarationMap": true,         // 宣言マップ生成
    "rootDir": ".",
    "outDir": "./dist"
  },
  "include": ["./**/*.ts"],
  "references": [
    {
      "path": "../common",          // 依存サブプロジェクト
      "prepend": true               // outFile使用時のみ有効
    }
  ]
}
```

**3. ルートtsconfig.json:**

```json
{
  "files": [],
  "references": [
    {"path": "./common"},
    {"path": "./backend"},
    {"path": "./frontend"}
  ]
}
```

**4. ビルドモード実行:**

```bash
tsc --build  # または tsc -b
```

#### 1.5.2 プロジェクト参照のメリット

| メリット | 説明 |
|---------|------|
| 境界形成 | サブプロジェクト間はソースでなく.d.tsでやり取り |
| 再コンパイル回避 | 変更のないサブプロジェクトは型チェックのみ |
| コンパイル時間短縮 | 数百ファイル規模で劇的な効果 |

**extendsで共通設定を継承:**

```json
// tsconfig.base.json
{
  "compilerOptions": {
    "composite": true,
    "declaration": true,
    "declarationMap": true,
    "strict": true,
    "target": "es5"
  }
}

// サブプロジェクト
{
  "extends": "../tsconfig.base",
  "include": ["./**/*.ts"],
  "references": [{"path": "../common"}]
}
```

### 1.6 エラー監視

**推奨ツール:**
- Sentry: https://sentry.io
- Bugsnag: https://bugsnag.com

実行時例外を報告・照合して、コンパイル時に防げなかったバグを修正。

---

## 2. サーバー上での実行

### 2.1 Node.js向け設定

```json
{
  "compilerOptions": {
    "target": "es2015",        // Node.js最新版ならes2015以降
    "module": "commonjs"       // Node.jsはCommonJS
  }
}
```

**結果:**
- `import/export` → `require/module.exports`
- 追加バンドル不要

### 2.2 ソースマップサポート

```bash
npm install source-map-support
```

**対応ツール:**
- PM2: プロセス監視
- Winston: ロギング
- Sentry: エラー報告

---

## 3. ブラウザー内での実行

### 3.1 モジュールフォーマット選択

| ユースケース | module設定 |
|------------|----------|
| SystemJSローダー | `systemjs` |
| Webpack/Rollup（ES2015対応） | `es2015` |
| 動的インポート使用 | `esnext` |
| npmライブラリ公開 | `umd` |
| Browserify | `commonjs` |
| RequireJS（AMD） | `amd` |
| グローバル変数（非推奨） | `none` |

### 3.2 推奨ビルドツールとプラグイン

| ツール | プラグイン |
|--------|----------|
| Webpack | ts-loader |
| Browserify | tsify |
| Babel | @babel/preset-typescript |
| Gulp | gulp-typescript |
| Grunt | grunt-ts |

### 3.3 パフォーマンス最適化ベストプラクティス

```markdown
1. モジュールとして維持（暗黙の依存を避ける）
2. 動的インポートで遅延ロード
3. 自動コード分割を活用
4. ページ読み込み時間を測定（New Relic/Datadog）
5. 本番ビルド = 開発ビルド（差異を最小化）
6. 欠けているブラウザー機能をポリフィル
```

---

## 4. npmへの公開

### 4.1 tsconfig設定

```json
{
  "compilerOptions": {
    "declaration": true,       // 型宣言生成
    "module": "umd",           // または "es2015"
    "sourceMap": true,
    "target": "es5"
  }
}
```

**推奨:**
- UMDとES2015の両方を提供（最大互換性）

### 4.2 .npmignoreと.gitignore

```bash
# .npmignore（npmパッケージから除外）
*.ts       # .tsファイルを除外
!*.d.ts    # .d.tsは含める

# .gitignore（リポジトリから除外）
*.d.ts     # 型宣言を除外
*.js       # JavaScriptを除外
```

### 4.3 package.json設定

```json
{
  "name": "my-awesome-typescript-project",
  "version": "1.0.0",
  "main": "dist/umd.js",          // UMDエントリーポイント
  "module": "dist/es2015.js",     // ES2015エントリーポイント
  "types": "dist/index.d.ts"      // 型宣言エントリーポイント
}
```

**ビルドとパッケージの統合:**
- `module`フィールド: Webpack/Rollupが優先使用
- `main`フィールド: それ以外が使用
- `types`フィールド: TypeScriptユーザー向け

### 4.4 公開前チェックリスト

- [ ] ソースマップ生成
- [ ] 型宣言生成
- [ ] UMD + ES2015フォーマット
- [ ] .npmignore/.gitignore設定
- [ ] package.jsonのmain/module/types設定
- [ ] ビルド実行（最新状態確認）

```bash
npm publish
```

---

## 5. トリプルスラッシュディレクティブ

### 5.1 概要

特別なコメントでTSCに指示を与える機能（ファイル先頭に配置）。

```typescript
/// <ディレクティブ 属性="値" />
```

### 5.2 typesディレクティブ

**用途:** アンビエント型宣言への依存を宣言（インポート省略制御）。

```typescript
// ローカル型宣言への依存
/// <reference types="./global" />

// @types/jasmineへの依存
/// <reference types="jasmine" />
```

**インポート省略の挙動:**

| コード | コンパイル結果 |
|--------|-------------|
| `import {MyType} from './module'` | 省略される（型のみ） |
| `import './module'` | 省略されない（副作用） |

**TypeScript 3.8以降の改善:**

```typescript
// 型のみインポートを明示
import type {SomeThing} from './some-module.js'
export type {SomeThing}  // JavaScript出力なし

// importsNotUsedAsValues: "preserve"で副作用維持
import {SomeThing} from './some-module.js'  // 型のみでもインポート残る
```

### 5.3 amd-moduleディレクティブ

**用途:** AMDモジュールに名前を付ける（`module: "amd"`時）。

```typescript
/// <amd-module name="LogService" />
export let LogService = {
  log() { /* ... */ }
}
```

**コンパイル結果:**

```javascript
define('LogService', ['require', 'exports'], function(require, exports) {
  exports.__esModule = true
  exports.LogService = { log() { /* ... */ } }
})
```

**推奨:** 可能であればES2015モジュールに切り替える。

### 5.4 その他のディレクティブ

| ディレクティブ | 用途 | 推奨度 |
|-------------|------|--------|
| `lib` | lib依存を宣言（tsconfig.jsonなし時） | tsconfigを推奨 |
| `path` | ファイル依存を宣言（outFile時） | import/exportを推奨 |
| `no-default-lib` | lib使用しない宣言 | 通常不要 |
| `amd-dependency` | AMD依存宣言（非推奨） | importを使用 |

---

## まとめ

### ビルド設定の判断フローチャート

```
ターゲット環境は？
├─ Node.js → module: "commonjs", target: "es2015"
├─ ブラウザー（ライブラリ公開）→ module: "umd" + "es2015"
└─ ブラウザー（自社アプリ）→ バンドラーに応じて選択

型安全性は？
├─ TypeScriptユーザー向け → declaration: true
└─ JavaScriptのみ → declaration不要

コンパイル時間は？
├─ 数百ファイル以上 → プロジェクト参照を検討
└─ 小規模 → 単一プロジェクトで十分

デバッグ必要？
└─ sourceMap: true（本番環境含む）
```

### 重要ポイント

**target vs lib:**
- target: トランスパイル先のJavaScriptバージョン
- lib: ターゲット環境で利用可能な機能の宣言
- lib宣言だけでは実装されない（ポリフィルが必要）

**プロジェクト参照:**
- composite/declaration/declarationMapが必須
- tsc --buildで実行
- 大規模プロジェクトで劇的な効果

**npm公開:**
- main（UMD） + module（ES2015） + types提供
- .npmignoreでTSソースを除外
- .gitignoreで成果物を除外
