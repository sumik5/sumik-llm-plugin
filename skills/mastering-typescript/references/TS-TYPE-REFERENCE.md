# リファレンス：チェックリスト、ツール設定、型チェッカー（TypeScript編）

このファイルでは、TypeScript型安全性を確保するための実践的なリファレンス情報を提供します。

## 📋 目次

- [型安全性チェックリスト（TypeScript）](#型安全性チェックリスト-typescript)
- [TypeScript設定](#typescript設定)
- [型チェッカー実行コマンド（TypeScript）](#型チェッカー実行コマンド-typescript)
- [トラブルシューティング（TypeScript）](#トラブルシューティング-typescript)
- [CI/CD統合（TypeScript）](#cicd統合-typescript)

## ✅ 型安全性チェックリスト（TypeScript）

### 実装前チェックリスト

コードを書く前に確認する項目：

- [ ] **any型の使用を避ける計画か？**
  - TypeScript: `any` → `unknown` + 型ガード、または明示的な型定義

- [ ] **型定義ファイルの確認**
  - 既存の型を再利用できないか確認
  - 新しい型定義が必要な場合、適切な場所に配置する計画

- [ ] **外部ライブラリの型定義**
  - TypeScript: `@types/*` パッケージの確認

- [ ] **型の共有範囲**
  - ローカル型で十分か、共有型として定義すべきか
  - 型定義ファイルの配置場所（`types/`、`models/`等）

### 実装中チェックリスト（TypeScript/JavaScript）

- [ ] **strict mode有効化**
  - `tsconfig.json` で `"strict": true` が設定されているか
  - `noImplicitAny: true` が有効か

- [ ] **明示的な型注釈**
  - すべての関数の引数と戻り値に型注釈があるか
  - クラスのプロパティに型注釈があるか

- [ ] **any型の不使用**
  - `any` 型を使用していないか
  - `Function` 型を使用していないか

- [ ] **型ガードの実装**
  - `unknown` 型を使用する際は型ガードがあるか
  - カスタム型ガード関数 (`is` 型述語) を実装したか

- [ ] **オプショナルチェイニングの活用**
  - `?.` でnull/undefinedを安全に扱っているか
  - `??` (Nullish Coalescing) でデフォルト値を提供しているか

- [ ] **non-null assertion（!）の濫用回避**
  - `!` を使用している箇所は本当に必要か
  - 型ガードやオプショナルチェイニングで代替できないか

- [ ] **厳密等価演算子の使用**
  - `===` / `!==` を使用しているか（`==` / `!=` は禁止）

### 実装後チェックリスト

コードを書き終えた後に確認する項目：

- [ ] **型チェッカーの実行**
  - TypeScript: `tsc --noEmit` でエラーがないか

- [ ] **コードレビュー観点**
  - [ ] any型が使用されていないか
  - [ ] すべての関数に型注釈があるか
  - [ ] 型ガードが適切に実装されているか
  - [ ] エラーハンドリングが適切か
  - [ ] ユニットテストが型安全か

- [ ] **ドキュメントの更新**
  - 型定義のドキュメントコメントが適切か
  - 使用例が型安全か

## ⚙️ TypeScript設定

### tsconfig.json（推奨設定）

```json
{
  "compilerOptions": {
    // === 型チェック関連（必須） ===
    "strict": true,                          // すべてのstrict系フラグを有効化
    "noImplicitAny": true,                   // 暗黙的なanyを禁止
    "strictNullChecks": true,                // null/undefinedの厳密チェック
    "strictFunctionTypes": true,             // 関数型の厳密チェック
    "strictBindCallApply": true,             // bind/call/applyの型チェック
    "strictPropertyInitialization": true,    // プロパティ初期化チェック
    "noImplicitThis": true,                  // 暗黙的なthisを禁止
    "alwaysStrict": true,                    // 'use strict'を自動挿入

    // === 追加の型チェック（推奨） ===
    "noUnusedLocals": true,                  // 未使用のローカル変数を検出
    "noUnusedParameters": true,              // 未使用のパラメータを検出
    "noImplicitReturns": true,               // すべてのコードパスでreturnを強制
    "noFallthroughCasesInSwitch": true,      // switch文のfallthrough検出
    "noUncheckedIndexedAccess": true,        // インデックスアクセスをundefined許容型に
    "noImplicitOverride": true,              // オーバーライド時にoverrideキーワード必須
    "allowUnusedLabels": false,              // 未使用のラベルを禁止
    "allowUnreachableCode": false,           // 到達不能コードを禁止

    // === モジュール解決 ===
    "moduleResolution": "node",              // Node.jsスタイルのモジュール解決
    "esModuleInterop": true,                 // CommonJSとES Moduleの相互運用
    "allowSyntheticDefaultImports": true,    // デフォルトエクスポートの柔軟な扱い
    "resolveJsonModule": true,               // JSONファイルのインポート許可
    "isolatedModules": true,                 // 各ファイルを独立したモジュールとして扱う

    // === 出力設定 ===
    "target": "ES2020",                      // ECMAScriptターゲットバージョン
    "module": "ESNext",                      // モジュールコード生成方式
    "lib": ["ES2020", "DOM"],                // 使用するライブラリ
    "outDir": "./dist",                      // 出力ディレクトリ
    "rootDir": "./src",                      // ソースルートディレクトリ
    "sourceMap": true,                       // ソースマップ生成
    "declaration": true,                     // .d.ts ファイル生成
    "declarationMap": true,                  // .d.ts のソースマップ

    // === その他 ===
    "skipLibCheck": true,                    // ライブラリの型チェックをスキップ
    "forceConsistentCasingInFileNames": true // ファイル名の大文字小文字を統一
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

### ESLint設定（TypeScript用）

```json
{
  "parser": "@typescript-eslint/parser",
  "parserOptions": {
    "ecmaVersion": 2020,
    "sourceType": "module",
    "project": "./tsconfig.json"
  },
  "plugins": ["@typescript-eslint"],
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "plugin:@typescript-eslint/recommended-requiring-type-checking"
  ],
  "rules": {
    // any型の禁止
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/no-unsafe-assignment": "error",
    "@typescript-eslint/no-unsafe-member-access": "error",
    "@typescript-eslint/no-unsafe-call": "error",
    "@typescript-eslint/no-unsafe-return": "error",

    // 型安全性の強化
    "@typescript-eslint/strict-boolean-expressions": "error",
    "@typescript-eslint/no-unnecessary-condition": "error",
    "@typescript-eslint/prefer-nullish-coalescing": "error",
    "@typescript-eslint/prefer-optional-chain": "error",

    // 命名規則
    "@typescript-eslint/naming-convention": [
      "error",
      {
        "selector": "interface",
        "format": ["PascalCase"]
      },
      {
        "selector": "typeAlias",
        "format": ["PascalCase"]
      }
    ],

    // その他
    "@typescript-eslint/explicit-function-return-type": "error",
    "@typescript-eslint/no-non-null-assertion": "warn",
    "@typescript-eslint/consistent-type-imports": "error"
  }
}
```

## 🚀 型チェッカー実行コマンド（TypeScript）

```bash
# 基本的な型チェック
tsc --noEmit

# watchモード（ファイル変更を監視）
tsc --noEmit --watch

# 特定のファイルのみチェック
tsc --noEmit src/main.ts

# 詳細な出力
tsc --noEmit --pretty --listFiles

# ESLintと組み合わせ
eslint --ext .ts,.tsx src/

# すべてまとめて実行
npm run type-check  # package.jsonで定義
```

**package.json scripts例**:
```json
{
  "scripts": {
    "type-check": "tsc --noEmit",
    "type-check:watch": "tsc --noEmit --watch",
    "lint": "eslint --ext .ts,.tsx src/",
    "lint:fix": "eslint --ext .ts,.tsx src/ --fix",
    "check": "npm run type-check && npm run lint"
  }
}
```

## 🔧 トラブルシューティング（TypeScript）

### Q1. `Cannot find module` エラー

**問題**:
```
Cannot find module '@/types/user' or its corresponding type declarations.
```

**解決策**:
```json
// tsconfig.json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```

### Q2. `Object is possibly 'null'` エラー

**問題**:
```typescript
const element = document.getElementById('app')
element.textContent = 'Hello'  // エラー: Object is possibly 'null'.
```

**解決策**:
```typescript
// 方法1: 型ガード
const element = document.getElementById('app')
if (element !== null) {
  element.textContent = 'Hello'
}

// 方法2: オプショナルチェイニング
const element = document.getElementById('app')
if (element) {
  element.textContent = 'Hello'
}

// 方法3: non-null assertion（確実な場合のみ）
const element = document.getElementById('app')!
element.textContent = 'Hello'
```

### Q3. 型の循環参照エラー

**問題**:
```
'User' implicitly has type 'any' because it does not have a type annotation and is referenced directly or indirectly in its own initializer.
```

**解決策**:
```typescript
// 悪い例
type User = {
  id: string
  friends: User[]  // 循環参照
}

// 良い例: interfaceを使用
interface User {
  id: string
  friends: User[]  // OK
}

// またはtypeで前方参照
type User = {
  id: string
  friends: Array<User>  // OK
}
```

## 🔄 CI/CD統合（TypeScript）

### GitHub Actions（TypeScript）

```yaml
name: Type Check (TypeScript)

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  type-check:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: TypeScript type check
        run: npm run type-check

      - name: ESLint
        run: npm run lint
```

### pre-commit設定（TypeScript）

```yaml
repos:
  - repo: https://github.com/pre-commit/mirrors-eslint
    rev: v8.52.0
    hooks:
      - id: eslint
        files: \.[jt]sx?$
        types: [file]
        args: ['--fix']
        additional_dependencies:
          - '@typescript-eslint/parser'
          - '@typescript-eslint/eslint-plugin'

  - repo: local
    hooks:
      - id: tsc
        name: TypeScript type check
        entry: npx tsc --noEmit
        language: system
        pass_filenames: false
        types: [typescript]
```

## 🔗 関連ファイル

- **[INSTRUCTIONS.md](../INSTRUCTIONS.md)** - mastering-typescript 概要に戻る
- **[TS-TYPE-SAFETY.md](./TS-TYPE-SAFETY.md)** - TypeScript型安全性詳細
- **[TS-TYPE-ANTI-PATTERNS.md](./TS-TYPE-ANTI-PATTERNS.md)** - 避けるべきパターン
