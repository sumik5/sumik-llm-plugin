# Storybook テスト戦略

## テストピラミッドにおけるStorybookの位置

```
         E2E (Playwright)
        ──────────────
       インタラクション (Storybook play)
      ─────────────────────
     ビジュアルリグレッション (Chromatic)
    ──────────────────────────
   ユニットテスト (Vitest / Jest)
  ─────────────────────────────────
 アクセシビリティ (axe-core / Storybook a11y)
──────────────────────────────────────────
```

Storybookはユニットテストとの間の「コンポーネントテスト」レイヤーを担当。

## インタラクションテスト詳細

### play関数の完全なAPI

```typescript
play: async ({
  args,           // ストーリーのargs
  canvasElement,  // ストーリーのルートDOM要素（v8）
  canvas,         // Testing Library queries（v9）
  userEvent,      // ユーザー操作API（v9）
  step,           // テストステップのグループ化
  mount,          // カスタムマウント関数
  context,        // ストーリーコンテキスト
}) => { ... }
```

### step()によるテスト構造化

```typescript
export const ComplexFlow: Story = {
  play: async ({ canvas, userEvent, step }) => {
    await step('初期状態の確認', async () => {
      await expect(canvas.getByText('ようこそ')).toBeInTheDocument();
    });

    await step('フォーム入力', async () => {
      await userEvent.type(canvas.getByLabelText('メール'), 'test@example.com');
      await userEvent.type(canvas.getByLabelText('パスワード'), 'pass123');
    });

    await step('送信と結果確認', async () => {
      await userEvent.click(canvas.getByRole('button', { name: '送信' }));
      await waitFor(() => {
        expect(canvas.getByText('送信完了')).toBeInTheDocument();
      });
    });
  },
};
```

### 非同期処理の待機パターン

```typescript
// waitFor: 条件が満たされるまでポーリング
await waitFor(() => expect(canvas.getByText('完了')).toBeInTheDocument());

// findBy: 要素の出現を待つ（waitFor + getBy のショートハンド）
const result = await canvas.findByText('結果');

// delay: 明示的な待機（非推奨だが必要な場合）
await new Promise((resolve) => setTimeout(resolve, 1000));
```

### beforeEachパターン

```typescript
const meta = {
  component: MyForm,
  // 各ストーリーの前に実行される
  beforeEach: async () => {
    // モックのリセット等
    mockApi.reset();
    return () => {
      // クリーンアップ
      mockApi.restore();
    };
  },
} satisfies Meta<typeof MyForm>;
```

## ビジュアルリグレッションテスト

### Chromatic

Storybook公式のビジュアルテストサービス。

```bash
npm install --save-dev chromatic

# 手動実行
npx chromatic --project-token=<token>
```

#### CI/CD統合（GitHub Actions）

```yaml
name: Chromatic
on: push
jobs:
  chromatic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-node@v4
      - run: npm ci
      - uses: chromaui/action@latest
        with:
          projectToken: ${{ secrets.CHROMATIC_PROJECT_TOKEN }}
```

#### Chromaticのモード

| モード | 説明 |
|--------|------|
| `chromatic.modes` | 複数のビューポート/テーマでスナップショット |
| `chromatic.delay` | スナップショット前の待機時間 |
| `chromatic.pauseAnimationAtEnd` | アニメーション完了後にキャプチャ |
| `chromatic.disableSnapshot` | 特定ストーリーのスナップショット無効化 |

### Storybook Test Runner

全ストーリーをヘッドレスブラウザで実行:

```bash
npm install --save-dev @storybook/test-runner

# Storybook起動中に実行
npx test-storybook

# CI用: Storybookビルド + serve + テスト
npx test-storybook --url http://localhost:6006
```

#### カスタムテスト設定

```typescript
// test-runner.ts
import type { TestRunnerConfig } from '@storybook/test-runner';

const config: TestRunnerConfig = {
  async postVisit(page, context) {
    // 各ストーリー訪問後に実行
    // 例: スクリーンショット比較
    const image = await page.screenshot();
    expect(image).toMatchImageSnapshot();
  },
};

export default config;
```

## アクセシビリティテスト詳細

### テストレベル

| レベル | 設定値 | 挙動 |
|--------|--------|------|
| エラー | `test: 'error'` | a11y違反でテスト失敗 |
| TODO | `test: 'todo'` | 警告表示（テストは通過） |
| オフ | `test: 'off'` | チェック無効 |

### ルール単位の設定

```typescript
parameters: {
  a11y: {
    config: {
      rules: [
        // ルール無効化（正当な理由がある場合のみ）
        { id: 'color-contrast', enabled: false },
        // セレクタで対象を限定
        { id: 'autocomplete-valid', selector: '*:not([autocomplete="nope"])' },
      ],
    },
    // axe-coreオプション
    options: {
      runOnly: {
        type: 'tag',
        values: ['wcag2a', 'wcag2aa'],
      },
    },
  },
},
```

### 手動テストモード

```typescript
globals: {
  a11y: {
    manual: true, // 自動チェック無効化（手動で「Run」ボタンを押す）
  },
},
```

## Portable Stories（Vitest統合）

StorybookのストーリーをVitestで直接実行:

```typescript
// Button.test.tsx
import { composeStories } from '@storybook/react';
import { render, screen } from '@testing-library/react';
import * as stories from './Button.stories';

const { Default, Loading, ErrorState } = composeStories(stories);

describe('Button', () => {
  it('デフォルト状態でレンダリングされる', () => {
    render(<Default />);
    expect(screen.getByRole('button')).toBeInTheDocument();
  });

  it('ローディング中はスピナーが表示される', () => {
    render(<Loading />);
    expect(screen.getByRole('progressbar')).toBeInTheDocument();
  });

  it('play関数のインタラクションが動作する', async () => {
    const { container } = render(<ErrorState />);
    await ErrorState.play?.({ canvasElement: container } as any);
    // アサーション
  });
});
```

### Portable Storiesの利点

| メリット | 説明 |
|---------|------|
| DRY原則 | ストーリーとテストでデータ・セットアップを共有 |
| 一貫性 | Storybookで確認した状態をそのままテスト |
| カバレッジ | 既存ストーリーを自動的にテストケース化 |
| play関数の再利用 | インタラクションテストをVitest内で実行 |

## テスト戦略の選択指針

| テスト種別 | ツール | 対象 | 実行速度 |
|-----------|--------|------|---------|
| スモークテスト | Test Runner | 全ストーリーのレンダリング確認 | 速い |
| インタラクション | play関数 | ユーザー操作フロー | 速い |
| ビジュアル | Chromatic | 見た目の差分検出 | 中 |
| a11y | addon-a11y | アクセシビリティ違反 | 速い |
| ユニット | Portable Stories + Vitest | ロジック・状態管理 | 最速 |
| E2E | Playwright | フルアプリフロー | 遅い |

**推奨組み合わせ**: play関数（インタラクション）+ addon-a11y（アクセシビリティ）+ Chromatic（ビジュアル）の3層テスト。
