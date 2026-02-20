---
name: developing-nextjs
description: Next.js 16.x / React 19.x development guide covering App Router, Server Components, Turbopack, React Compiler, proxy.ts, and React internals. MUST load when package.json contains 'next' or next.config.* is detected. Covers Cache Components, opt-in caching APIs (updateTag/revalidateTag/refresh), strict TypeScript, Tailwind CSS 4.x, Prisma 7.x, Zod 4.x, Vitest 4.x, Playwright, Docker, Vercel performance rules, and advanced React patterns. For SaaS patterns (auth, payments, AI), use building-nextjs-saas instead. For AI integration with Vercel AI SDK and LangChain.js, use integrating-ai-web-apps.
---

# Next.js 16.x / React 19.x Modern Web Development Skill

## 概要

このスキルは、Next.js 16.x + React 19.xを使用した最新のWebアプリケーション開発のベストプラクティスを提供します。

## 使用タイミング

以下のような場面でこのスキルを参照してください：

- **新規プロジェクト作成**: Next.js 16でプロジェクトを開始する前に全体像を把握
- **実装前の確認**: 特定機能（Server Components、Actions、Cache等）の実装方法を確認
- **設定ファイル作成**: mise.toml、tsconfig.json、eslint.config.mjs等の設定例が必要なとき
- **トラブルシューティング**: ビルドエラー、型エラー、Docker問題の解決方法を確認
- **コード品質向上**: TypeScript厳格設定、ESLint、テスト戦略を学ぶ

## 対象技術スタック

- **Next.js**: 16.x（App Router、Server Components、Cache Components、Turbopack default、proxy.ts）
- **React**: 19.x（Actions、useActionState、ref as prop、View Transitions）
- **TypeScript**: 5.x（strict mode + noUncheckedIndexedAccess等の厳格オプション）
- **Tailwind CSS**: 4.x（CSS-first、`@import "tailwindcss"`）+ shadcn/ui 3.x

> **重要**: Tailwind CSS 4.xはCSS-first設定。`tailwind.config.js`はプラグインやshadcn/ui互換のために共存可能。詳細は[STYLING.md](./references/STYLING.md)参照。
- **Prisma ORM**: 7.x（PostgreSQL、prisma.config.ts）
- **Zod**: 4.x（バリデーション）
- **Vitest**: 4.x + **Playwright**: テスト環境（ユニット + E2E）
- **Docker**: マルチステージビルド、tini、GCPデプロイ対応
- **Node.js**: 開発 24.x（Current）/ 本番 22.x（LTS）
- **pnpm**: 最新版（Corepack経由）
- **mise**: ツールバージョン管理 + タスクランナー

## ドキュメント構成（Progressive Disclosure）

このスキルは、必要な情報に素早くアクセスできるよう、以下のファイルに分割されています：

### 🏗️ プロジェクト構成とセットアップ
- **[PROJECT-STRUCTURE.md](./references/PROJECT-STRUCTURE.md)**: プロジェクト全体のフォルダ構成、命名規則、推奨構造
- **[TOOLING.md](./references/TOOLING.md)**: mise.toml、pnpm、ESLint、TypeScript、Prettier等の開発ツール設定

### ⚛️ フレームワーク固有ガイド
- **[NEXTJS-GUIDE.md](./references/NEXTJS-GUIDE.md)**: App Router、Server Components、Cache Components、動的ルーティング等
- **[REACT-GUIDE.md](./references/REACT-GUIDE.md)**: React 19新機能（Actions、useActionState、ref as prop等）

### 🎨 UI・スタイリング
- **[STYLING.md](./references/STYLING.md)**: Tailwind CSS（最新版）設定、shadcn/ui使用方法、カスタムコンポーネント作成

### 🗄️ データ管理とテスト
- **[DATABASE.md](./references/DATABASE.md)**: Prisma ORM設定、マイグレーション、型安全なクエリ
- **[TESTING.md](./references/TESTING.md)**: Vitest設定、MSWモック、テスト戦略、カバレッジ

### 🐳 デプロイと運用
- **[DOCKER.md](./references/DOCKER.md)**: マルチステージビルド、Next.js standalone出力、GCP Cloud Run対応

### 📖 実装例
- **[EXAMPLES.md](./references/EXAMPLES.md)**: page.tsx、layout.tsx、Server Actions、API routes等の実装サンプル

## 他のスキルとの連携

このスキルは、以下の既存スキルと組み合わせて使用してください：

### 必須スキル（実装時に必ず参照）
- **`writing-clean-code`**: SOLID原則、クリーンコード、単一責任原則等
- **`enforcing-type-safety`**: any/Any型禁止、型ガード、厳格な型チェック
- **`testing`**: TDD、AAA パターン、テストカバレッジ100%目標
- **`securing-code`**: セキュアコーディング、CodeGuard実行（実装完了後必須）
- **`writing-effective-prose`**: 7つのC原則を含む技術文書・学術文書の原則

### 推奨MCP（効率的開発）
- **`using-serena`**: コード編集・分析（最優先）
- **`using-next-devtools`**: Next.js専用ツール（診断、アップグレード、Cache Components最適化）
- **`designing-frontend`**: UIコンポーネント管理（shadcn/ui含む）
- **`mcp-search`**: 最新仕様確認（context7、kagi等）

## 学習パス

### 初心者向け
1. **[PROJECT-STRUCTURE.md](./references/PROJECT-STRUCTURE.md)** - プロジェクト全体像を把握
2. **[NEXTJS-GUIDE.md](./references/NEXTJS-GUIDE.md)** - Next.js基本概念（App Router、Server Components）
3. **[EXAMPLES.md](./references/EXAMPLES.md)** - 実装例で学ぶ

### 中級者向け
1. **[REACT-GUIDE.md](./references/REACT-GUIDE.md)** - React 19新機能を活用
2. **[DATABASE.md](./references/DATABASE.md)** - Prisma ORMでデータ層を構築
3. **[TESTING.md](./references/TESTING.md)** - テスト戦略を学ぶ

### 上級者向け
1. **[TOOLING.md](./references/TOOLING.md)** - 開発ツールの最適化
2. **[DOCKER.md](./references/DOCKER.md)** - 本番環境デプロイ
3. `writing-clean-code`、`enforcing-type-safety`、`securing-code` - コード品質向上

## クイックスタート

### 新規プロジェクト作成
```bash
# 1. Next.js 16プロジェクト作成
npx create-next-app@latest my-app

# 2. mise初期化（推奨。バージョンは参考値、最新を確認）
mise use node@24 pnpm@latest pre-commit@latest

# 3. shadcn/ui初期化
pnpm dlx shadcn@latest init

# 4. Prisma初期化
pnpm add -D prisma
pnpm dlx prisma init

# 5. Vitest初期化
pnpm add -D vitest @vitejs/plugin-react vite-tsconfig-paths jsdom
```

詳細な設定は各ドキュメントを参照してください。

## 重要な原則

### 1. 型安全性（必須）
- **any/Any型禁止**: TypeScript/Python共通（`enforcing-type-safety`スキル参照）
- **厳格な型チェック**: tsconfig.jsonで`strict: true`を必ず有効化
- **型推論の活用**: 可能な限り明示的な型注釈より型推論を使用

### 2. Server-First設計
- **デフォルトはServer Components**: クライアント機能が必要な場合のみ`"use client"`
- **データフェッチはサーバーサイド**: `async/await`で直接データベースアクセス
- **Server Actions活用**: フォーム送信、データ更新はServer Actionsで処理

### 3. コード品質
- **SOLID原則遵守**: `writing-clean-code`スキル参照
- **テストファースト**: `testing`スキル参照
- **セキュアコーディング**: `securing-code`スキル参照（実装完了後にCodeGuard必須実行）

### 4. パフォーマンス最適化
- **キャッシング戦略**: Cache Components、Partial Prerendering活用
- **動的インポート**: 大きなコンポーネントは`dynamic()`で遅延ロード
- **画像最適化**: `next/image`コンポーネント使用

## サポートとフィードバック

このスキルは、実際のプロダクションプロジェクト（信州大学教育プラットフォーム）から抽出されたベストプラクティスに基づいています。

不明点や改善提案があれば、関連ドキュメントを参照するか、最新の公式ドキュメントを確認してください：
- **Next.js公式**: https://nextjs.org/docs
- **React公式**: https://react.dev
- **Tailwind CSS公式**: https://tailwindcss.com
- **shadcn/ui**: https://ui.shadcn.com

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

| 確認項目 | 例 |
|---|---|
| デプロイ先 | Vercel, AWS, Docker, セルフホスト |
| データベース | PostgreSQL, MySQL, SQLite, PlanetScale |
| 認証方式 | NextAuth, Clerk, Supabase Auth, カスタム |
| スタイリング | Tailwind CSS, CSS Modules, styled-components |
| 状態管理 | React state, Zustand, Jotai |
| テスト戦略 | Vitest + RTL, Playwright E2E, 両方 |
| Linting | ESLintフル構成（推奨）, ESLint最小構成, Biome |
| パッケージマネージャ | pnpm（推奨）, npm, yarn, bun |
| pre-commitツール | pre-commit framework（推奨）, husky + lint-staged |
| Node.jsバージョン戦略 | Current + LTS併用（推奨）, LTS統一 |
| ORM | Prisma（推奨）, Drizzle, TypeORM |
| バリデーション | Zod（推奨）, Valibot |

### 確認不要な場面

- App Router vs Pages Router（App Routerがデフォルト）
- TypeScript使用（必須）
- package.jsonで技術スタックが確定済みの場合

---

## React Performance (Vercel Engineering)

Vercel Engineeringによるパフォーマンス最適化ルール集。

| ファイル | 内容 |
|---------|------|
| [RP-AGENTS.md](./references/RP-AGENTS.md) | Vercel AIエージェント向けルール |
| [RP-README.md](./references/RP-README.md) | ルール概要 |
| [RP-rules/](./references/RP-rules/) | 50+の個別パフォーマンスルール |

## React Internals

Reactの内部メカニズム、高度パターン、データ管理。

| ファイル | 内容 |
|---------|------|
| [RI-PATTERNS.md](./references/RI-PATTERNS.md) | 高度なReactパターン |
| [RI-PERFORMANCE.md](./references/RI-PERFORMANCE.md) | レンダリングと最適化の内部構造 |
| [RI-DATA-MANAGEMENT.md](./references/RI-DATA-MANAGEMENT.md) | 状態管理とデータフロー |
| [RI-TYPESCRIPT-REACT.md](./references/RI-TYPESCRIPT-REACT.md) | TypeScript + React統合 |
| [RI-TESTING-AND-TOOLING.md](./references/RI-TESTING-AND-TOOLING.md) | テストとツール |
| [RI-FRAMEWORKS.md](./references/RI-FRAMEWORKS.md) | Reactフレームワーク選定とSSR |

---

**対象バージョン**: Next.js 16.x / React 19.x（詳細は上記「対象技術スタック」を参照）
