# Storybook 高度なパターン集

## Story構成パターン

### 複合コンポーネント

```typescript
import type { Meta, StoryObj } from '@storybook/react';
import { fn } from '@storybook/test';
import { Card } from '@/components/Card';
import { CardHeader } from '@/components/CardHeader';
import { CardBody } from '@/components/CardBody';

const meta = {
  component: Card,
  // サブコンポーネントをドキュメントに含める
  subcomponents: { CardHeader, CardBody },
} satisfies Meta<typeof Card>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  render: (args) => (
    <Card {...args}>
      <CardHeader title="タイトル" />
      <CardBody>コンテンツ</CardBody>
    </Card>
  ),
  args: {
    onClick: fn(),
  },
};
```

### render関数パターン

argsだけでは表現できないレイアウトや複数コンポーネント連携:

```typescript
export const WithSidebar: Story = {
  render: () => (
    <div className="flex">
      <Sidebar />
      <MainContent />
    </div>
  ),
};
```

### argsの動的生成

```typescript
const generateItems = (count: number) =>
  Array.from({ length: count }, (_, i) => ({
    id: String(i + 1),
    name: `アイテム ${i + 1}`,
  }));

export const ManyItems: Story = {
  args: {
    items: generateItems(100),
    onItemClick: fn(),
  },
};

export const EmptyList: Story = {
  args: {
    items: [],
    onItemClick: fn(),
  },
};
```

## Decoratorパターン集

### Providerスタック

```typescript
// .storybook/preview.ts - 複数のProviderをネスト
const preview: Preview = {
  decorators: [
    // 1. テーマ
    (Story) => (
      <ThemeProvider>
        <Story />
      </ThemeProvider>
    ),
    // 2. 国際化
    (Story) => (
      <IntlProvider locale="ja" messages={jaMessages}>
        <Story />
      </IntlProvider>
    ),
    // 3. レイアウト
    (Story) => (
      <div className="min-h-screen bg-background p-8">
        <Story />
      </div>
    ),
  ],
};
```

### Story単位のDecorator

```typescript
export const InModal: Story = {
  decorators: [
    (Story) => (
      <ModalProvider>
        <div className="fixed inset-0 flex items-center justify-center bg-black/50">
          <Story />
        </div>
      </ModalProvider>
    ),
  ],
};
```

### レスポンシブプレビュー

```typescript
export const Mobile: Story = {
  parameters: {
    viewport: {
      defaultViewport: 'mobile1',
    },
  },
  decorators: [
    (Story) => (
      <div className="max-w-[375px]">
        <Story />
      </div>
    ),
  ],
};
```

## MSW高度なパターン

### GraphQL モック

```typescript
import { graphql, HttpResponse } from 'msw';

export const WithGraphQL: Story = {
  parameters: {
    msw: {
      handlers: [
        graphql.query('GetUser', () => {
          return HttpResponse.json({
            data: {
              user: { id: '1', name: '山田太郎', email: 'yamada@example.com' },
            },
          });
        }),
        graphql.mutation('UpdateUser', ({ variables }) => {
          return HttpResponse.json({
            data: {
              updateUser: { ...variables, id: '1' },
            },
          });
        }),
      ],
    },
  },
};
```

### 遅延・エラーシミュレーション

```typescript
import { http, HttpResponse, delay } from 'msw';

// スローレスポンス
export const SlowResponse: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/data', async () => {
          await delay(3000);
          return HttpResponse.json({ data: 'loaded' });
        }),
      ],
    },
  },
};

// ネットワークエラー
export const NetworkError: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/data', () => {
          return HttpResponse.error();
        }),
      ],
    },
  },
};

// 特定ステータスコード
export const NotFound: Story = {
  parameters: {
    msw: {
      handlers: [
        http.get('/api/data', () => {
          return new HttpResponse(null, { status: 404 });
        }),
      ],
    },
  },
};
```

### ハンドラー共有パターン

```typescript
// mocks/handlers.ts - 共通ハンドラーを定義
import { http, HttpResponse } from 'msw';

export const defaultHandlers = [
  http.get('/api/user', () => {
    return HttpResponse.json({ id: '1', name: '山田太郎' });
  }),
  http.get('/api/settings', () => {
    return HttpResponse.json({ theme: 'dark', locale: 'ja' });
  }),
];

// Story内で共通ハンドラーを活用
import { defaultHandlers } from '@/mocks/handlers';

export const Default: Story = {
  parameters: {
    msw: {
      handlers: defaultHandlers,
    },
  },
};

// 特定のエンドポイントだけオーバーライド
export const ErrorUser: Story = {
  parameters: {
    msw: {
      handlers: [
        ...defaultHandlers.filter((h) => !h.info.path.includes('/api/user')),
        http.get('/api/user', () => new HttpResponse(null, { status: 500 })),
      ],
    },
  },
};
```

## argTypes活用

### カスタムControl定義

```typescript
const meta = {
  component: Button,
  argTypes: {
    variant: {
      control: 'select',
      options: ['primary', 'secondary', 'danger'],
      description: 'ボタンのバリアント',
    },
    size: {
      control: 'radio',
      options: ['sm', 'md', 'lg'],
    },
    disabled: {
      control: 'boolean',
    },
    backgroundColor: {
      control: 'color',
    },
    onClick: {
      action: 'clicked', // Actions panelに表示
    },
  },
} satisfies Meta<typeof Button>;
```

### Controlの無効化

```typescript
const meta = {
  component: Card,
  argTypes: {
    // 複雑なオブジェクトはControlから除外
    children: { control: false },
    ref: { table: { disable: true } },
  },
} satisfies Meta<typeof Card>;
```

## Play関数のコンポジション

ストーリー間でplay関数を再利用し、複雑なフローを段階的に構築:

```typescript
export const StepOne: Story = {
  play: async ({ canvas, userEvent }) => {
    await userEvent.type(canvas.getByLabelText('メール'), 'test@example.com');
    await userEvent.click(canvas.getByRole('button', { name: '次へ' }));
  },
};

// StepOneのplay関数を再利用して拡張
export const StepTwo: Story = {
  play: async (context) => {
    await StepOne.play!(context);
    await context.userEvent.type(
      context.canvas.getByLabelText('パスワード'),
      'password123'
    );
    await context.userEvent.click(
      context.canvas.getByRole('button', { name: '送信' })
    );
  },
};
```

## excludeStoriesパターン

ヘルパーデータをStory一覧から除外:

```typescript
const meta = {
  component: TaskList,
  excludeStories: /.*Data$/, // 正規表現でマッチするエクスポートを除外
} satisfies Meta<typeof TaskList>;

// Storybook UIに表示されないが、他のStoryから参照可能
export const MockData = {
  tasks: [
    { id: '1', title: 'タスク1', state: 'TASK_INBOX' },
    { id: '2', title: 'タスク2', state: 'TASK_PINNED' },
  ],
};

export const Default: Story = {
  args: { tasks: MockData.tasks },
};
```

## Provider/Store デコレータパターン

Redux等の状態管理ライブラリをStorybook内で動作させる:

```typescript
import { Provider } from 'react-redux';
import { configureStore } from '@reduxjs/toolkit';
import taskReducer from '@/store/taskSlice';

// カスタムProviderデコレータ
const MockStore = ({ initialState, children }: {
  initialState: Record<string, unknown>;
  children: React.ReactNode;
}) => (
  <Provider store={configureStore({
    reducer: { tasks: taskReducer },
    preloadedState: initialState,
  })}>
    {children}
  </Provider>
);

const meta = {
  component: TaskList,
  decorators: [
    (Story) => (
      <MockStore initialState={{ tasks: { items: [], status: 'idle' } }}>
        <Story />
      </MockStore>
    ),
  ],
} satisfies Meta<typeof TaskList>;
```

## CI/CD統合パターン

### GitHub Actions: Storybook Build + Test

```yaml
name: Storybook CI
on: [push, pull_request]

jobs:
  storybook:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci

      # Storybookビルド
      - run: npx storybook build --quiet

      # Test Runner実行
      - name: Install Playwright
        run: npx playwright install --with-deps chromium
      - name: Start Storybook and run tests
        run: |
          npx concurrently -k -s first -n "SB,TEST" \
            "npx http-server storybook-static --port 6006 --silent" \
            "npx wait-on tcp:6006 && npx test-storybook --url http://127.0.0.1:6006"
```

### Chromaticとの併用

```yaml
      # ビジュアルリグレッション
      - uses: chromaui/action@latest
        with:
          projectToken: ${{ secrets.CHROMATIC_PROJECT_TOKEN }}
          exitZeroOnChanges: true  # 差分があっても失敗にしない
```

## ドキュメント生成パターン

### autodocs

```typescript
// main.ts
const config: StorybookConfig = {
  docs: {
    autodocs: 'tag', // `tags: ['autodocs']` のあるストーリーのみ
  },
};

// Story側
const meta = {
  component: Button,
  tags: ['autodocs'], // このコンポーネントのドキュメントを自動生成
} satisfies Meta<typeof Button>;
```

### カスタムドキュメント

```typescript
// MDXファイル（Button.mdx）
import { Meta, Story, Canvas, Controls, Description } from '@storybook/blocks';
import * as ButtonStories from './Button.stories';

<Meta of={ButtonStories} />

# Button コンポーネント

<Description of={ButtonStories} />

## 基本的な使い方

<Canvas of={ButtonStories.Default} />

## Props

<Controls />
```

## パフォーマンス最適化

### Storyビルドの高速化

| 施策 | 効果 |
|------|------|
| `stories` パスの限定 | 不要なファイルスキャンを削減 |
| `docs.autodocs` を `'tag'` に | 全コンポーネント自動生成を回避 |
| `@storybook/react-vite` 使用 | Viteの高速ビルド活用（Next.js以外） |
| Lazy compilation | 開発時は表示中のストーリーのみビルド |

### ストーリーの分割ロード

```typescript
// main.ts: ディレクトリごとにストーリーを限定
const config: StorybookConfig = {
  stories: [
    '../src/components/**/*.stories.@(ts|tsx)',
    // pages は必要な場合のみ追加
    // '../src/pages/**/*.stories.@(ts|tsx)',
  ],
};
```

## 命名規則

### Story名の規則（日本語推奨）

```typescript
// 良い例: 視覚的な違いが即座にわかる
export const デフォルト: Story = { ... };
export const ローディング中: Story = { ... };
export const エラー表示: Story = { ... };
export const データなし: Story = { ... };
export const ログイン済み: Story = { ... };
export const 未ログイン: Story = { ... };

// 悪い例: 技術用語で視覚的な違いが不明
export const Default: Story = { ... };
export const WithError: Story = { ... };
export const IsLoading: Story = { ... };
```

### ファイル配置と命名

| パターン | 命名 |
|---------|------|
| コンポーネント | `ComponentName.tsx` |
| ストーリー | `ComponentName.stories.tsx` |
| テスト | `ComponentName.test.tsx` |
| スタイル | `ComponentName.module.css` |
