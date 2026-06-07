# Storybook セットアップ・設定詳細

## フレームワーク別セットアップ

### Next.js（推奨）

```bash
npx storybook@latest init --framework @storybook/nextjs
```

**.storybook/main.ts**:
```typescript
import type { StorybookConfig } from '@storybook/nextjs';

const config: StorybookConfig = {
  framework: '@storybook/nextjs',
  stories: ['../src/**/*.stories.@(ts|tsx)'],
  addons: [
    '@storybook/addon-essentials',
    '@storybook/addon-a11y',
  ],
  docs: {
    autodocs: 'tag',
  },
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
    a11y: { test: 'error' },
    nextjs: {
      appDirectory: true,
    },
  },
};

export default preview;
```

#### Next.js固有の注意点

- `@storybook/nextjs` は `next/image`, `next/font`, `next/navigation`, `next/router` を自動モック
- Tailwind CSS: `globals.css` を `.storybook/preview.ts` でインポートするだけで動作
- CSS Modules: ネイティブサポート（追加設定不要）
- Sass/SCSS: `sass` パッケージがインストール済みなら設定不要
- App Router: `parameters.nextjs.appDirectory: true` を設定

### React（Vite）

```bash
npx storybook@latest init --framework @storybook/react-vite
```

```typescript
import type { StorybookConfig } from '@storybook/react-vite';

const config: StorybookConfig = {
  framework: '@storybook/react-vite',
  stories: ['../src/**/*.stories.@(ts|tsx)'],
  addons: ['@storybook/addon-essentials'],
};

export default config;
```

### Vue 3（Vite）

```bash
npx storybook@latest init --framework @storybook/vue3-vite
```

```typescript
import type { StorybookConfig } from '@storybook/vue3-vite';

const config: StorybookConfig = {
  framework: '@storybook/vue3-vite',
  stories: ['../src/**/*.stories.@(ts|tsx)'],
  addons: ['@storybook/addon-essentials'],
};

export default config;
```

## TypeScript設定

### tsconfig補完

Storybookが生成する `.storybook/tsconfig.json` が既存設定と競合する場合:

```json
{
  "extends": "../tsconfig.json",
  "compilerOptions": {
    "jsx": "react-jsx",
    "strict": true
  },
  "include": ["../src/**/*", "./**/*"]
}
```

### パスエイリアス

`@/` エイリアスがStorybook内で動作しない場合、`main.ts` に設定:

```typescript
// Next.jsの場合は自動解決されるため通常不要
// React + Viteの場合
import { mergeConfig } from 'vite';

const config: StorybookConfig = {
  // ...
  viteFinal: async (config) => {
    return mergeConfig(config, {
      resolve: {
        alias: {
          '@': path.resolve(__dirname, '../src'),
        },
      },
    });
  },
};
```

## Addon設定

### @storybook/addon-a11y

```bash
npm install --save-dev @storybook/addon-a11y
```

```typescript
// .storybook/main.ts
const config: StorybookConfig = {
  addons: [
    '@storybook/addon-essentials',
    '@storybook/addon-a11y',
  ],
};
```

### msw-storybook-addon

```bash
npm install --save-dev msw msw-storybook-addon
npx msw init public/
```

```typescript
// .storybook/preview.ts
import { initialize, mswLoader } from 'msw-storybook-addon';

initialize();

const preview: Preview = {
  loaders: [mswLoader],
};

export default preview;
```

### @storybook/addon-themes

```bash
npm install --save-dev @storybook/addon-themes
```

```typescript
// .storybook/preview.ts
import { withThemeByClassName } from '@storybook/addon-themes';

const preview: Preview = {
  decorators: [
    withThemeByClassName({
      themes: {
        light: '',
        dark: 'dark',
      },
      defaultTheme: 'light',
    }),
  ],
};
```

## ディレクトリ構成パターン

### コンポーネント隣接（推奨）

```
src/
├── components/
│   └── Button/
│       ├── Button.tsx
│       ├── Button.stories.tsx   # ストーリー
│       ├── Button.test.tsx      # ユニットテスト
│       └── Button.module.css
```

### 専用ディレクトリ

```
src/
├── components/
│   └── Button/
│       └── Button.tsx
├── stories/
│   └── Button.stories.tsx
```

**判断基準**: コンポーネント隣接が推奨。ストーリーとコンポーネントの関連性が明確で、変更時の見落としを防ぐ。

## 初期セットアップ後の整理

`npx storybook init` 実行後、以下を整理:

1. **`src/stories/` を削除**: 自動生成されるサンプルストーリーは不要
2. **`.storybook/main.ts` の `stories` パスを確認**: プロジェクトのディレクトリ構成に合わせる
3. **`.storybook/preview.ts` にグローバルスタイルをインポート**: Tailwind CSS等
4. **Addon追加**: `@storybook/addon-a11y` は最初から入れておく

## トラブルシューティング

### よくある問題

| 問題 | 原因 | 解決策 |
|------|------|--------|
| CSSが適用されない | グローバルスタイル未インポート | `preview.ts` で `globals.css` をインポート |
| パスエイリアス `@/` が解決されない | Storybook側の設定不足 | Next.jsフレームワーク使用、またはviteFinalでalias設定 |
| `next/image` がエラー | フレームワーク設定が不正 | `@storybook/nextjs` を使用 |
| HMRが効かない | キャッシュの問題 | `node_modules/.cache/storybook` を削除 |
| TypeScriptエラー | tsconfig競合 | `.storybook/tsconfig.json` を確認 |
| Node.jsモジュールエラー（fs, path） | SSR用コードの混入 | Webpack fallbackで `{ fs: false, path: false }` |
