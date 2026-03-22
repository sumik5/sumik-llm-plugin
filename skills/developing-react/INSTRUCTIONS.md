# React 19.x 開発ガイド

## 概要

React固有の開発知識を集約したスキル。React Internals、パフォーマンス最適化（react-doctor 47+ルール）、UIアニメーション、テスト（React Testing Library）の4領域をカバーする。

## ドキュメント構成

### ⚛️ React 19 新機能
- **[REACT-GUIDE.md](./references/REACT-GUIDE.md)**: Actions、useActionState、ref as prop、View Transitions

### 🔬 React Internals（内部構造）
- **[RI-PERFORMANCE.md](./references/RI-PERFORMANCE.md)**: レンダリング原理、メモ化戦略、依存配列
- **[RI-PATTERNS.md](./references/RI-PATTERNS.md)**: Compound Components、Render Props、Custom Hooks
- **[RI-DATA-MANAGEMENT.md](./references/RI-DATA-MANAGEMENT.md)**: 状態管理、データフロー、Context
- **[RI-FRAMEWORKS.md](./references/RI-FRAMEWORKS.md)**: フレームワーク統合パターン
- **[RI-TYPESCRIPT-REACT.md](./references/RI-TYPESCRIPT-REACT.md)**: TypeScript + React型定義
- **[RI-TESTING-AND-TOOLING.md](./references/RI-TESTING-AND-TOOLING.md)**: テストツール・DevTools

### 🚀 パフォーマンス最適化（react-doctor ルール）
- **[RP-AGENTS.md](./references/RP-AGENTS.md)**: 全47+ルールのコンパイル済みガイド（Agent向け）
- **[RP-README.md](./references/RP-README.md)**: ルール構造・メンテナンス方法
- **[RP-rules/](./references/RP-rules/)**: 個別ルールファイル（49ルール）
  - `rerender-*`: 再レンダリング最適化（memo, derived state, transitions等）
  - `rendering-*`: レンダリング最適化（hydration, conditional render, Activity等）
  - `server-*`: サーバーサイド最適化（cache, parallel fetching, serialization等）
  - `bundle-*`: バンドルサイズ最適化（barrel imports, dynamic imports, preload等）
  - `js-*`: JavaScript最適化（cache, Set/Map lookups, early exit等）
  - `client-*`: クライアントサイド最適化（event listeners, localStorage等）
  - `async-*`: 非同期処理最適化（Suspense, parallel, defer等）
  - `advanced-*`: 高度なパターン（event handler refs等）

### 🎨 UIアニメーション
- **[ANIMATION.md](./references/ANIMATION.md)**: CSS/UIアニメーションパターン
  - ボタンフィードバック、ツールチップ、ホバー状態
  - イージング選択ガイド（ease-out / ease-in-out / custom curves）
  - タッチデバイス対応、アクセシビリティ
  - パフォーマンス注意点（will-change, blur上限）

### 🧪 React Testing Library（RTL）
- **[RTL-QUERIES.md](./references/RTL-QUERIES.md)**: クエリ優先順位（getByRole → getByText → getByTestId）
- **[RTL-INTERACTIONS.md](./references/RTL-INTERACTIONS.md)**: userEvent、fireEvent、非同期操作
- **[RTL-ADVANCED.md](./references/RTL-ADVANCED.md)**: カスタムレンダー、Provider、MSWモック
- **[REACT-TDD-PATTERNS.md](./references/REACT-TDD-PATTERNS.md)**: React固有TDDパターン
- **[VITEST-RTL-GUIDELINES.md](./references/VITEST-RTL-GUIDELINES.md)**: Vitest + RTL統合設定

### 🧩 React開発パターン・実践ガイド（RD-*）
- **[RD-DESIGN-PATTERNS.md](./references/RD-DESIGN-PATTERNS.md)**: Container/Presenter、HOC、Render Props、State Reducer、Headless Components、Control Props等（RI-PATTERNS.mdのProvider/Composite/Summaryを補完）
- **[RD-ERROR-HANDLING.md](./references/RD-ERROR-HANDLING.md)**: ErrorBoundary、react-error-boundary、React 19エラーAPI、配置戦略
- **[RD-ACCESSIBILITY.md](./references/RD-ACCESSIBILITY.md)**: セマンティックHTML、ARIA、フォーカス管理、キーボードナビゲーション、WCAG 2.1 AAチェックリスト
- **[RD-MODERN-REACT.md](./references/RD-MODERN-REACT.md)**: React Compiler、Concurrent Features実践、2025年状態管理推奨（nuqs/Jotai）、アンチパターン

## react-doctor CLIの使用

プロジェクトのReactコード品質を診断する:

```bash
# 基本スキャン（0-100スコア + 診断結果）
npx -y react-doctor@latest .

# 詳細モード（影響ファイル・行番号表示）
npx -y react-doctor@latest . --verbose

# 差分モード（変更ファイルのみスキャン）
npx -y react-doctor@latest . --diff main

# スコアのみ出力
npx -y react-doctor@latest . --score

# lint/dead-codeの個別スキップ
npx -y react-doctor@latest . --no-lint
npx -y react-doctor@latest . --no-dead-code
```

**スコア基準**: 75+ Great / 50-74 Needs work / <50 Critical

## Storybook開発

コンポーネント駆動開発（CDD）のためのStorybookガイド。CSF3 Story記述、インタラクションテスト（play関数）、アクセシビリティテスト（axe-core）、ビジュアルリグレッションテストをカバーする。

### CSF3 基本パターン

```typescript
import type { Meta, StoryObj } from '@storybook/react';
import { fn } from '@storybook/test';
import { MyComponent } from '@/components/MyComponent';

const meta = {
  component: MyComponent,
} satisfies Meta<typeof MyComponent>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: { onClick: fn(), children: 'テキスト' },
};
```

### インタラクションテスト（play関数）

```typescript
play: async ({ canvasElement }) => {
  const canvas = within(canvasElement);
  await userEvent.click(canvas.getByRole('button', { name: '送信' }));
  await waitFor(() => expect(args.onSubmit).toHaveBeenCalled());
}
```

### アクセシビリティテスト

```typescript
// .storybook/preview.ts
parameters: { a11y: { test: 'error' } }  // 全ストーリーでa11y違反をエラーに
```

### Storybook リファレンス

| ドキュメント | 内容 |
|------------|------|
| **[SB-STORYBOOK-GUIDE.md](./references/SB-STORYBOOK-GUIDE.md)** | Quick Start・全機能ガイド（MSW・Next.js統合・Decorators） |
| **[SB-SETUP.md](./references/SB-SETUP.md)** | フレームワーク別セットアップ・設定詳細 |
| **[SB-TESTING.md](./references/SB-TESTING.md)** | テスト戦略（インタラクション・ビジュアル・a11y・Portable Stories） |
| **[SB-PATTERNS.md](./references/SB-PATTERNS.md)** | 高度なStoryパターン・MSW・Decorators・CI/CD統合 |

## 関連スキル

| スキル | 関係 |
|--------|------|
| **`developing-nextjs`** | Next.js固有機能（App Router、Server Components）。React共通部分は本スキル参照 |
| **`testing-code`** | テスト方法論（TDD、AAA パターン）。RTL固有は本スキル参照 |
| **`designing-frontend`** | UIコンポーネント管理（shadcn/ui） |
| **`writing-clean-code`** | SOLID原則、クリーンコード（言語非依存） |
| **`enforcing-type-safety`** | TypeScript型安全性。React型定義は本スキルのRI-TYPESCRIPT-REACT.md参照 |
| **`mastering-typescript`** | TypeScript高度パターン。React統合はFRAMEWORK-INTEGRATION.md参照 |
