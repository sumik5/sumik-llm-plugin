# 開発ツール設定ガイド

## mise（ツールバージョン管理 + タスクランナー）

### 概要

miseは、Node.js、pnpm、pre-commit等のツールバージョン統一管理に加え、タスクランナー機能も備えたツール（asdf、rtxの代替）。

### インストール

```bash
# macOS
brew install mise

# Linux
curl https://mise.run | sh

# Windows
# https://mise.jdx.dev/getting-started.html#installation を参照
```

### 設定ファイル

**.mise.toml（プロジェクトルート）:**
```toml
[settings]
experimental = true

[tools]
node = "24"      # Current（開発用）
pnpm = "10"
pre-commit = "latest"

# 環境変数
[env]
_.file = ".env"

# --- タスクランナー ---

# 依存関係
[tasks.install]
description = "依存関係のインストール"
run = "pnpm install"

# 開発サーバー
[tasks.dev]
description = "Next.js開発サーバーの起動"
run = "pnpm dev"

[tasks.build]
description = "Next.jsアプリケーションのビルド"
run = "pnpm build"

[tasks.start]
description = "Next.js本番サーバーの起動"
run = "pnpm start"

# テスト
[tasks.test]
description = "Vitestでテストを実行"
run = "pnpm test"

[tasks."test:e2e"]
description = "PlaywrightでE2Eテストを実行"
run = "pnpm test:e2e"

[tasks."test:coverage"]
description = "テストカバレッジレポートの生成"
run = "pnpm coverage"

# Lint/Format
[tasks.lint]
description = "ESLintの実行"
run = "pnpm lint"

[tasks.format]
description = "Prettierでコードをフォーマット"
run = "pnpm fmt"

# 一括チェック
[tasks."check-all"]
description = "すべてのチェックを実行（build, lint, format, test）"
run = [
  "SKIP_ENV_VALIDATION=true pnpm build || true",
  "pnpm lint",
  "pnpm fmt",
  "pnpm test"
]

# クリーンアップ
[tasks.clean]
description = "プロジェクトのクリーンアップ"
run = [
  "rm -rf node_modules",
  "rm -rf .next"
]
```

### 使用方法

```bash
# プロジェクト初期化（ツールをインストール）
mise install

# タスク実行
mise run dev            # 開発サーバー起動
mise run test           # テスト実行
mise run test:e2e       # E2Eテスト実行
mise run build          # ビルド
mise run check-all      # 全チェック実行
mise run clean          # クリーンアップ
```

## TypeScript設定

### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "esnext",
    "lib": ["dom", "dom.iterable", "esnext"],
    "types": ["node", "react", "react-dom"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "react-jsx",
    "incremental": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true,

    "plugins": [
      {
        "name": "next"
      }
    ],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": [
    "next-env.d.ts",
    "**/*.ts",
    "**/*.tsx",
    ".next/types/**/*.ts",
    ".next/dev/types/**/*.ts",
    "postcss.config.cjs"
  ],
  "exclude": ["node_modules", "eslint.config.mjs"]
}
```

### 重要な設定項目

| 設定 | 説明 |
|------|------|
| `strict: true` | 厳格な型チェック有効（必須） |
| `noUnusedLocals: true` | 未使用変数エラー |
| `noUnusedParameters: true` | 未使用パラメータエラー |
| `noImplicitReturns: true` | 暗黙的なreturnの禁止 |
| `noFallthroughCasesInSwitch: true` | switch文のフォールスルー禁止 |
| `noUncheckedIndexedAccess: true` | 配列・オブジェクトアクセス時の安全性向上（`T \| undefined`を強制） |
| `paths` | パスエイリアス設定（`@/`でsrcディレクトリ参照） |

> **注意**: `exactOptionalPropertyTypes`はライブラリ互換性の問題が多いため、プロダクションでは使用していない。

## ESLint設定（Flat Config）

### eslint.config.mjs

```javascript
/* eslint-disable import-x/no-named-as-default-member */

import comments from "@eslint-community/eslint-plugin-eslint-comments/configs";
import react from "@eslint-react/eslint-plugin";
import js from "@eslint/js";
import nextPlugin from "@next/eslint-plugin-next";
import prettierConfig from "eslint-config-prettier";
import eslintPluginImportX from "eslint-plugin-import-x";
import reactCompilerPlugin from "eslint-plugin-react-compiler";
import reactHooksPlugin from "eslint-plugin-react-hooks";
import regexPlugin from "eslint-plugin-regexp";
import security from "eslint-plugin-security";
import globals from "globals";
import tseslint from "typescript-eslint";

// Tailwind CSS v4との互換性: eslint-plugin-tailwindcss は
// まだv4に完全対応していないため一時的に無効化（安定版リリースを待つ）
// import tailwind from "eslint-plugin-tailwindcss";

const config = tseslint.config(
  {
    ignores: [
      ".next",
      "node_modules",
      "src/components/ui/*",
      "public/mockServiceWorker.js",
      "coverage",
      "wt-*/**",
      "playwright-report/**",
    ],
  },
  // Base
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  eslintPluginImportX.flatConfigs.recommended,
  eslintPluginImportX.flatConfigs.typescript,
  comments.recommended,
  regexPlugin.configs["flat/recommended"],
  security.configs.recommended,

  // Next.js / React
  nextPlugin.configs.recommended,
  {
    name: "react-hooks/recommended",
    plugins: {
      "react-hooks": reactHooksPlugin,
    },
    rules: reactHooksPlugin.configs.recommended.rules,
  },
  {
    name: "react-compiler",
    plugins: {
      "react-compiler": reactCompilerPlugin,
    },
  },
  react.configs["recommended-type-checked"],

  // Tailwind CSS v4との互換性: eslint-plugin-tailwindcss は
  // まだv4に完全対応していないため一時的に無効化（安定版リリースを待つ）
  // ...tailwind.configs["flat/recommended"],

  {
    linterOptions: {
      reportUnusedDisableDirectives: false,
    },
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
        ecmaFeatures: {
          jsx: true,
        },
      },
      globals: {
        ...globals.browser,
        ...globals.node,
      },
    },
    // Tailwind CSS v4との互換性: eslint-plugin-tailwindcss は
    // まだv4に完全対応していないため一時的に無効化（安定版リリースを待つ）
    // settings: {
    //   tailwindcss: {
    //     callees: ["classnames", "clsx", "ctl", "cn", "cva"],
    //     config: "tailwind.config.js",
    //     cssFiles: ["src/app/globals.css"],
    //     skipClassAttribute: false,
    //   },
    // },
    rules: {
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],

      "@typescript-eslint/consistent-type-imports": [
        "warn",
        { prefer: "type-imports", fixStyle: "separate-type-imports" },
      ],

      "@typescript-eslint/no-misused-promises": [
        "error",
        { checksVoidReturn: { attributes: false } },
      ],

      "@typescript-eslint/no-unnecessary-condition": [
        "error",
        {
          allowConstantLoopConditions: true,
        },
      ],

      "@typescript-eslint/consistent-type-exports": [
        "error",
        { fixMixedExportsWithInlineTypeSpecifier: true },
      ],

      // 型安全性の強化（any型の使用禁止）
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-unsafe-assignment": "error",
      "@typescript-eslint/no-unsafe-member-access": "error",
      "@typescript-eslint/no-unsafe-call": "error",
      "@typescript-eslint/no-unsafe-return": "error",
      "@typescript-eslint/no-unsafe-argument": "error",

      "import-x/no-unresolved": [
        "error",
        { ignore: ["geist", "./.next/types/routes.d.ts"] },
      ],
      "react-compiler/react-compiler": "error",
    },
  },

  // CJSファイル用override
  {
    files: ["**/*.cjs", "**/*.cts"],
    languageOptions: {
      sourceType: "commonjs",
    },
  },

  // テストファイル用override（テストではany関連を緩和）
  {
    files: ["**/*.test.ts", "**/*.test.tsx"],
    rules: {
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-call": "off",
    },
  },

  prettierConfig,
);

export default config;
```

### 必要パッケージ

```bash
pnpm add -D \
  @eslint/js \
  typescript-eslint \
  eslint-plugin-import-x \
  @eslint-community/eslint-plugin-eslint-comments \
  eslint-plugin-regexp \
  eslint-plugin-security \
  @next/eslint-plugin-next \
  eslint-plugin-react-hooks \
  eslint-plugin-react-compiler \
  @eslint-react/eslint-plugin \
  eslint-config-prettier \
  globals
```

### 重要なルール

| ルール | 説明 |
|--------|------|
| `react-compiler/react-compiler: "error"` | React Compiler最適化（必須） |
| `@typescript-eslint/no-explicit-any: "error"` | any型禁止（`enforcing-type-safety`スキル参照） |
| `@typescript-eslint/consistent-type-imports` | 型インポート分離 |
| `@typescript-eslint/no-unnecessary-condition` | 不要な条件式検出（型情報ベース） |
| `@typescript-eslint/consistent-type-exports` | 型エクスポート分離 |
| `import-x/no-unresolved` | 未解決インポート検出（geist等は除外） |
| `comments.recommended` | ESLintディレクティブコメントの品質管理 |
| `react.configs["recommended-type-checked"]` | 型チェック付きReactルール |

## Prettier設定

### 方針

Prettierはデフォルト設定を推奨する。設定ファイルを最小化することで、チーム間の不要な議論を減らし、Prettierのバージョンアップ時の互換性を維持する。

### .prettierrc（最小構成）

空ファイルまたはファイルなし（デフォルト設定を使用）。明示的に設定する場合:

```json
{}
```

### .prettierignore

```
.next
node_modules
coverage
pnpm-lock.yaml
playwright-report
```

### 参考: デフォルト設定値

| 設定 | デフォルト値 |
|------|-------------|
| `printWidth` | 80 |
| `tabWidth` | 2 |
| `useTabs` | false |
| `semi` | true |
| `singleQuote` | false |
| `trailingComma` | "all" |

### package.jsonスクリプト

```json
{
  "scripts": {
    "fmt": "prettier --write ."
  }
}
```

## pre-commit（Git Hooks）

### 概要

pre-commit frameworkを使用してコミット時の品質チェックを自動化する。`fail_fast: true`により最初のエラーで停止し、無駄な実行を避ける。

### セットアップ

```bash
# mise経由でインストール
mise use pre-commit@latest

# pre-commitフック有効化
pre-commit install
```

### .pre-commit-config.yaml

```yaml
# 最初のエラーで停止する（後続のフックを実行しない）
fail_fast: true

repos:
  # ローカルフック（prettier → eslint → vitest の順序）
  - repo: local
    hooks:
      # Prettier - コードフォーマット（自動修正 + 自動ステージング）
      - id: prettier
        name: prettier
        entry: bash -c 'eval "$(mise activate bash)" && pnpm fmt && git diff --name-only | xargs git add'
        language: system
        pass_filenames: false
        files: \.(js|jsx|ts|tsx|json|css|md)$

      # ESLint - 静的解析（自動修正 + 自動ステージング）
      - id: eslint
        name: eslint
        entry: bash -c 'eval "$(mise activate bash)" && pnpm lint --fix && git diff --name-only | xargs git add'
        language: system
        pass_filenames: false
        files: \.(js|jsx|ts|tsx)$

      # Vitest - ユニットテスト実行
      - id: vitest
        name: vitest
        entry: bash -c 'eval "$(mise activate bash)" && pnpm test'
        language: system
        pass_filenames: false
        files: \.(js|jsx|ts|tsx)$

      # Playwright - E2Eテスト（手動実行のみ）
      # 実行: pre-commit run --hook-stage manual playwright
      - id: playwright
        name: playwright e2e (manual)
        entry: bash -c 'eval "$(mise activate bash)" && pnpm test:e2e'
        language: system
        pass_filenames: false
        files: \.(js|jsx|ts|tsx)$
        stages: [manual]

  # 汎用フック（プロジェクト全体）
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
        args: ["--unsafe"]
      - id: check-json
      - id: check-added-large-files
        args: ["--maxkb=5120"]
      - id: check-merge-conflict
```

> **ポイント**: `eval "$(mise activate bash)"`によりhook内でmise管理のツールバージョンを使用する。CIとローカルでツールバージョンの差異が発生しない。

## package.json スクリプト

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "test": "NODE_OPTIONS='--max-old-space-size=4096' vitest run",
    "test:e2e": "playwright test",
    "coverage": "vitest run --coverage",
    "lint": "eslint .",
    "fmt": "prettier --write .",
    "migrate:create": "tsx scripts/create-migration.ts",
    "migrate:deploy": "prisma migrate deploy",
    "migrate:status": "prisma migrate status",
    "postinstall": "prisma generate",
    "prepare": "command -v pre-commit >/dev/null 2>&1 && pre-commit install || echo 'pre-commit not installed, skipping hook installation'"
  }
}
```

### スクリプト解説

| スクリプト | 説明 |
|-----------|------|
| `test` | `--max-old-space-size=4096`でメモリ上限を拡張してVitest実行 |
| `test:e2e` | Playwright E2Eテスト |
| `coverage` | Vitestカバレッジレポート生成 |
| `migrate:create` | Prismaマイグレーション作成（カスタムスクリプト経由） |
| `migrate:deploy` | Prismaマイグレーション適用 |
| `migrate:status` | Prismaマイグレーション状態確認 |
| `postinstall` | `pnpm install`後に自動でPrismaクライアント生成 |
| `prepare` | Git hook（pre-commit）の自動インストール |

## 環境変数管理

### .env.example（テンプレート）

```bash
# Next.js
NEXT_PUBLIC_BASE_URL=http://localhost:3000
NODE_ENV=development

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/dbname

# Authentication
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=your-secret-here

# Logging
LOG_FORMAT=text        # text | json | cloud-logging
LOG_LEVEL=debug        # debug | info | warn | error

# Mock Server（開発環境のみ）
ENABLE_MOCK_SERVER=true
```

### 型安全な環境変数管理

```typescript
// src/lib/env.ts
import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  NEXTAUTH_SECRET: z.string().min(32),
  NODE_ENV: z.enum(["development", "production", "test"]),
  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),
});

export const env = envSchema.parse(process.env);
```

## VS Code設定

### .vscode/settings.json

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "typescript.tsdk": "node_modules/typescript/lib"
}
```

### 推奨拡張機能

```json
{
  "recommendations": [
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "bradlc.vscode-tailwindcss",
    "prisma.prisma",
    "vitest.explorer"
  ]
}
```

## 参考資料

- **mise公式**: https://mise.jdx.dev
- **TypeScript公式**: https://www.typescriptlang.org
- **ESLint公式**: https://eslint.org
- **Prettier公式**: https://prettier.io
- **pre-commit公式**: https://pre-commit.com

---

**関連ドキュメント:**
- [PROJECT-STRUCTURE.md](./PROJECT-STRUCTURE.md) - プロジェクト構造
- **`enforcing-type-safety`スキル**: 型安全性の原則
