# Storybook 開発ガイド

Storybookを使ったコンポーネント駆動開発（CDD）の包括ガイド。CSF3によるStory記述、インタラクションテスト、アクセシビリティテスト、ビジュアルリグレッションテスト、フレームワーク統合をカバーする。

## Quick Start

### セットアップ

```bash
# 新規プロジェクトへの導入（自動設定）
npx storybook@latest init

# Next.jsプロジェクトの場合
npx storybook@latest init --framework @storybook/nextjs

# 起動
npm run storybook  # デフォルト: http://localhost:6006
```

### 最小構成ファイル

**.storybook/main.ts**:
```typescript
import type { StorybookConfig } from '@storybook/nextjs';

const config: StorybookConfig = {
  framework: '@storybook/nextjs',
  stories: ['../src/**/*.stories.@(ts|tsx)'],
  addons: ['@storybook/addon-essentials'],
  staticDirs: ['../public'],
};

export default config;
```

**.storybook/preview.ts**:
```typescript
import '@/app/globals.css';
import type { Preview } from '@storybook/nextjs';

const preview: Preview = {
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
    a11y: { test: 'error' }, // a11y違反をエラーとして扱う
  },
};

export default preview;
```

## CSF3 Story記述ルール

### 基本構造

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
  args: {
    onClick: fn(),
    children: 'テキスト',
  },
};
```

### Story作成の判断基準

| 作成すべき | 作成不要 |
|-----------|---------|
| 条件分岐で異なるUIが表示される状態 | 単純なprop値の違い（variant, size, color） |
| エラー状態の表示 | 非表示状態（`isVisible: false`） |
| ローディングスピナー | 見た目が同一のストーリー重複 |
| 空データ状態 | ロジック検証目的のストーリー |
| 認証有無で変わるUI | 内部Hookのモックが必要な状態 |

### 必須ルール

- **Meta設定は最小限**: `component` のみ指定
- **イベントハンドラ**: 各Storyの `args` に `fn()` で定義（metaには含めない）
- **インポート**: バレルインポート禁止。`@/` エイリアスで個別インポート
- **型定義**: `satisfies Meta<typeof Component>` で型安全を確保
- **Story命名**: 日本語で視覚的な違いが即座にわかる名前

### 条件分岐パターン

```typescript
// 通常表示
export const Default: Story = {
  args: {
    data: mockData,
    onItemClick: fn(),
  },
};

// ローディング中（条件分岐: isLoading === true でスピナー表示）
export const Loading: Story = {
  args: {
    data: [],
    isLoading: true,
    onItemClick: fn(),
  },
};

// データなし（条件分岐: data.length === 0 で空状態表示）
export const NoData: Story = {
  args: {
    data: [],
    onItemClick: fn(),
  },
};

// エラー状態（条件分岐: error存在でエラーメッセージ表示）
export const ErrorState: Story = {
  args: {
    error: 'データの取得に失敗しました',
    onRetry: fn(),
  },
};
```

## インタラクションテスト（play関数）

play関数でユーザー操作をシミュレートし、コンポーネントの振る舞いを検証する。

### 基本パターン

```typescript
import { userEvent, waitFor, within, expect, fn } from '@storybook/test';

export const FormSubmit: Story = {
  args: { onSubmit: fn() },
  play: async ({ args, canvasElement, step }) => {
    const canvas = within(canvasElement);

    await step('フォーム入力', async () => {
      await userEvent.type(canvas.getByTestId('email'), 'test@example.com');
      await userEvent.type(canvas.getByTestId('password'), 'password123');
    });

    await step('送信', async () => {
      await userEvent.click(canvas.getByRole('button', { name: '送信' }));
    });

    await waitFor(() => expect(args.onSubmit).toHaveBeenCalled());
  },
};
```

### play関数で使えるAPI

| API | 用途 |
|-----|------|
| `canvas.getByRole()` | アクセシブルなロールで要素取得（推奨） |
| `canvas.getByTestId()` | data-testidで要素取得 |
| `canvas.getByText()` | テキストで要素取得 |
| `userEvent.type()` | テキスト入力 |
| `userEvent.click()` | クリック |
| `userEvent.hover()` | ホバー |
| `expect()` | アサーション（Vitest互換） |
| `waitFor()` | 非同期処理の完了待ち |
| `step()` | テストステップのグループ化 |

### Storybook v9の新API

Storybook v9では `play` 関数のシグネチャが簡略化:

```typescript
// v9: canvas と userEvent が直接引数に
play: async ({ canvas, userEvent }) => {
  await userEvent.type(canvas.getByTestId('email'), 'test@example.com');
  await userEvent.click(canvas.getByRole('button'));
  await expect(canvas.getByText('送信完了')).toBeInTheDocument();
}

// v8: canvasElement から within() で取得
play: async ({ canvasElement }) => {
  const canvas = within(canvasElement);
  await userEvent.type(canvas.getByTestId('email'), 'test@example.com');
}
```

## アクセシビリティテスト

### グローバル設定（推奨）

```typescript
// .storybook/preview.ts
const preview: Preview = {
  parameters: {
    a11y: { test: 'error' }, // 全ストーリーでa11y違反をエラーに
  },
};
```

### Story単位のルール設定

```typescript
export const CustomA11y: Story = {
  parameters: {
    a11y: {
      config: {
        rules: [
          { id: 'color-contrast', enabled: true },
          { id: 'image-alt', enabled: false }, // 特定ルール無効化
        ],
      },
    },
  },
};
```

## MSWによるネットワークモック

### セットアップ

```bash
npm install msw msw-storybook-addon --save-dev
npx msw init public/
```

```typescript
// .storybook/preview.ts
import { initialize, mswLoader } from 'msw-storybook-addon';

initialize();

const preview: Preview = {
  loaders: [mswLoader],
};
```

### Story内でのモック定義

```typescript
import { http, HttpResponse, delay } from 'msw';

export const Success: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/users', () => {
          return HttpResponse.json([
            { id: 1, name: '山田太郎' },
            { id: 2, name: '鈴木花子' },
          ]);
        }),
      ],
    },
  },
};

export const Error: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/users', async () => {
          await delay(800);
          return new HttpResponse(null, { status: 500 });
        }),
      ],
    },
  },
};
```

## Next.js統合

### フレームワーク固有の機能

`@storybook/nextjs` は以下をビルトインでサポート:

| 機能 | 自動サポート |
|------|-------------|
| `next/image` | 最適化なしでそのまま表示 |
| `next/font` | フォント読み込み対応 |
| `next/navigation` | モック提供 |
| `next/router` | モック提供 |
| CSS Modules | ネイティブサポート |
| Sass/SCSS | 設定不要 |
| Tailwind CSS | globals.cssインポートで動作 |

### ルーティングのモック

```typescript
export const ProfilePage: Story = {
  parameters: {
    nextjs: {
      appDirectory: true,
      navigation: {
        pathname: '/profile/[id]',
        segments: ['profile', '123'],
      },
    },
  },
};
```

### ナビゲーションのアサーション

```typescript
import { expect } from 'storybook/test';
import { redirect, getRouter } from '@storybook/nextjs/navigation.mock';

export const NavigateBack: Story = {
  play: async ({ canvas, userEvent }) => {
    await userEvent.click(canvas.getByText('戻る'));
    await expect(getRouter().back).toHaveBeenCalled();
  },
};
```

## Decorators & Parameters

### Decoratorsパターン

```typescript
// Theme Provider
const meta = {
  component: MyComponent,
  decorators: [
    (Story) => (
      <ThemeProvider theme="dark">
        <Story />
      </ThemeProvider>
    ),
  ],
} satisfies Meta<typeof MyComponent>;

// グローバルDecorator (.storybook/preview.ts)
const preview: Preview = {
  decorators: [
    (Story) => (
      <div style={{ padding: '1rem' }}>
        <Story />
      </div>
    ),
  ],
};
```

### Parameters活用

| パラメータ | 用途 |
|-----------|------|
| `parameters.layout` | `'centered'` / `'fullscreen'` / `'padded'` |
| `parameters.backgrounds` | 背景色の選択肢 |
| `parameters.viewport` | モバイル/タブレットプレビュー |
| `parameters.docs` | ドキュメント生成設定 |
| `parameters.a11y` | アクセシビリティルール |
| `parameters.msw` | MSWハンドラー |
| `parameters.nextjs` | Next.js固有設定 |

## Addonエコシステム

### 必須Addon（essentials）

`@storybook/addon-essentials` に含まれる:
- **Controls**: propsをGUIで動的変更
- **Actions**: イベントハンドラのログ出力
- **Viewport**: レスポンシブプレビュー
- **Backgrounds**: 背景色切替
- **Docs**: 自動ドキュメント生成
- **Measure & Outline**: レイアウトデバッグ

### 推奨Addon

| Addon | 用途 |
|-------|------|
| `@storybook/addon-a11y` | アクセシビリティ検証（axe-core） |
| `@storybook/addon-coverage` | カバレッジ計測 |
| `msw-storybook-addon` | APIモック（MSW統合） |
| `@storybook/addon-themes` | テーマ切替 |
| `storybook-dark-mode` | ダークモード切替 |
| `@chromatic-com/storybook` | Chromaticビジュアルテスト統合 |

## ビジュアルリグレッションテスト

### Chromatic統合

```bash
npm install --save-dev chromatic
npx chromatic --project-token=<token>
```

CI/CDに統合してPRごとにビジュアル差分を検出。

### Storybook Test Runner

```bash
npm install --save-dev @storybook/test-runner
npx test-storybook
```

全ストーリーをヘッドレスブラウザ（Playwright）で実行し、スモークテスト + インタラクションテストを自動検証。

## アンチパターン

| アンチパターン | 問題 | 解決策 |
|--------------|------|--------|
| 全バリアントをStoryに展開 | Story数の爆発、メンテナンス困難 | 条件分岐のあるUI状態のみStory化 |
| 内部Hookのモックを強制 | テストが実装に密結合 | Props経由で状態を注入可能に設計 |
| metaにイベントハンドラ定義 | 全Storyで同一ハンドラ共有 | 各Storyの`args`に`fn()`で定義 |
| バレルインポート | ツリーシェイク不可、ビルド遅延 | `@/`エイリアスで個別インポート |
| 見た目同一の重複Story | ノイズ増加、レビュー困難 | 視覚的に異なる状態のみ |
| Story名が英語の技術用語 | 非エンジニアが理解困難 | 日本語で視覚的違いを表現 |
| play関数内でのDOM直接操作 | テストが脆い | Testing Library API（getByRole等）使用 |

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

| 確認項目 | 例 |
|---|---|
| フレームワーク | `@storybook/nextjs`, `@storybook/react-vite`, `@storybook/vue3-vite` |
| ビジュアルテスト | Chromatic, Percy, reg-suit, なし |
| MSW導入 | API依存コンポーネントの有無 |
| a11yテスト厳格度 | `error`（厳格）, `todo`（警告）, `off`（無効） |
| Storyの粒度 | 条件分岐のみ vs 主要バリアント網羅 |

### 確認不要な場面

- CSF3形式の使用（デフォルト）
- TypeScriptでの型定義（必須）
- `satisfies Meta<typeof Component>` パターン（必須）
- `fn()` でのイベントハンドラ定義（必須）
- `@/` エイリアスでの個別インポート（必須）

## 関連スキル

- **designing-frontend**: フロントエンドUI実装（shadcn/ui統合、デザイン美学）
- **developing-react**: React固有の最適化（Internals、パフォーマンス、RTLテスト）
- **developing-nextjs**: Next.js固有機能（App Router、Server Components）
- **testing-code**: テスト方法論全般（TDD、AAA、カバレッジ戦略）
- **testing-e2e-with-playwright**: E2Eブラウザテスト（Storybook Test Runnerと補完関係）
- **building-design-systems**: デザインシステム構築（Storybookをドキュメンテーションツールとして活用）
- **styling-with-tailwind**: Tailwind CSS方法論（Storybook内でのスタイリング）

## 詳細リファレンス

- **[SETUP.md](references/SETUP.md)**: フレームワーク別セットアップ・設定詳細
- **[TESTING.md](references/TESTING.md)**: テスト戦略（インタラクション・ビジュアル・a11y・Portable Stories）
- **[PATTERNS.md](references/PATTERNS.md)**: 高度なStoryパターン・MSW・Decorators・CI/CD統合
