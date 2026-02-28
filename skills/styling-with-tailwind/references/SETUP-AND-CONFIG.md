# セットアップ・設定ガイド

Tailwind CSSのプロジェクト導入から設定まで。v4（CSS-first config）をプライマリとして記述し、v3はレガシーとして区別する。

---

## 目次

- [v4セットアップ（推奨）](#v4セットアップ推奨)
- [v4テーマ設定（@theme）](#v4テーマ設定theme)
- [v4ディレクティブ完全リファレンス](#v4ディレクティブ完全リファレンス)
- [v3セットアップ（レガシー）](#v3セットアップレガシー)
- [設定対照表（v4 vs v3）](#設定対照表v4-vs-v3)
- [テーマカスタマイズ詳細](#テーマカスタマイズ詳細)
- [開発ツール](#開発ツール)

---

## v4セットアップ（推奨）

### Vite + React/Vue/Svelte など

最も一般的なセットアップ。`@tailwindcss/vite` プラグインを使用する。

```bash
# 1. プロジェクト作成（未作成の場合）
npm create vite@latest my-project
cd my-project

# 2. Tailwind CSS v4 インストール
npm install tailwindcss @tailwindcss/vite
```

```typescript
// vite.config.ts
import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [
    tailwindcss(),
  ],
})
```

```css
/* src/style.css または src/index.css */
@import "tailwindcss";
```

```bash
# 4. 開発サーバー起動
npm run dev
```

> **v4の特徴**: `tailwind.config.js` が不要。CSSファイル内の `@import "tailwindcss"` 一行がエントリポイント。`content` 設定も不要（自動検出）。

### Next.js（App Router）

Next.js 15以降はv4が推奨。`create-next-app` 実行時にTailwindを選択すると自動設定される。

```bash
npx create-next-app@latest my-app --tailwind
```

手動設定の場合：

```bash
npm install tailwindcss @tailwindcss/postcss postcss
```

```javascript
// postcss.config.mjs
export default {
  plugins: {
    '@tailwindcss/postcss': {},
  },
}
```

```css
/* app/globals.css */
@import "tailwindcss";
```

### PostCSS経由（フレームワーク非依存）

```bash
npm install tailwindcss @tailwindcss/postcss postcss
```

```javascript
// postcss.config.js
module.exports = {
  plugins: {
    '@tailwindcss/postcss': {},
  },
}
```

### スタンドアローンCLI

Node.jsなし環境向け。シングルバイナリをダウンロードして使用。

```bash
# macOS (arm64)
curl -sLO https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-macos-arm64
chmod +x tailwindcss-macos-arm64

# ビルド
./tailwindcss-macos-arm64 -i src/input.css -o dist/output.css --watch
```

---

## v4テーマ設定（@theme）

v4ではJavaScriptの設定ファイルの代わりに、CSSの `@theme` ブロックでデザイントークンを定義する。

### 基本的な使い方

```css
@import "tailwindcss";

@theme {
  /* フォント */
  --font-display: "Satoshi", "sans-serif";
  --font-mono: "JetBrains Mono", monospace;

  /* カラー */
  --color-brand-primary: oklch(0.65 0.2 25);
  --color-brand-secondary: oklch(0.72 0.11 178);

  /* ブレークポイント */
  --breakpoint-3xl: 120rem;

  /* スペーシング追加 */
  --spacing-128: 32rem;
}
```

これにより以下のクラスが自動生成される：

```html
<div class="font-display text-brand-primary p-128 3xl:grid-cols-3">
```

### テーマ変数の名前空間

| 名前空間 | 生成されるユーティリティ | 例 |
|---------|----------------------|-----|
| `--color-*` | カラーユーティリティ全般 | `bg-blue-500`, `text-gray-700` |
| `--font-*` | フォントファミリー | `font-sans`, `font-mono` |
| `--text-*` | フォントサイズ | `text-xl`, `text-2xl` |
| `--font-weight-*` | フォントウェイト | `font-bold`, `font-semibold` |
| `--tracking-*` | レタースペーシング | `tracking-wide` |
| `--leading-*` | 行の高さ | `leading-tight` |
| `--breakpoint-*` | レスポンシブ変数 | `sm:*`, `md:*` |
| `--spacing-*` | スペーシング | `p-4`, `m-8`, `w-16` |
| `--radius-*` | ボーダー半径 | `rounded-sm`, `rounded-lg` |
| `--shadow-*` | ボックスシャドウ | `shadow-md`, `shadow-lg` |
| `--animate-*` | アニメーション | `animate-spin` |

### デフォルトテーマの拡張 vs 上書き

**拡張（追加のみ）**:

```css
@theme {
  /* 既存の色に加えて新しい色を追加 */
  --color-avocado-500: oklch(0.84 0.18 117.33);
}
```

**名前空間全体の置換**:

```css
@theme {
  /* デフォルトの全カラーを削除して独自パレットに置換 */
  --color-*: initial;
  --color-white: #fff;
  --color-slate: #334155;
  --color-brand: oklch(0.65 0.2 25);
}
```

**全テーマの完全置換**:

```css
@theme {
  /* デフォルトをすべてリセット */
  --*: initial;
  --spacing: 4px;
  --font-body: "Inter", sans-serif;
  --color-primary: oklch(0.72 0.11 221.19);
}
```

### @theme と :root の違い

```css
/* @theme: ユーティリティクラスが自動生成される */
@theme {
  --color-brand: oklch(0.65 0.2 25);
}
/* → bg-brand, text-brand, border-brand などが使えるようになる */

/* :root: 単なるCSS変数。ユーティリティクラスは生成されない */
:root {
  --my-custom-color: blue;
}
/* → bg-my-custom-color などは生成されない */
```

### アニメーション定義

```css
@theme {
  --animate-fade-in: fade-in 0.3s ease-out;

  @keyframes fade-in {
    from { opacity: 0; transform: scale(0.95); }
    to   { opacity: 1; transform: scale(1); }
  }
}
```

```html
<div class="animate-fade-in">...</div>
```

### プロジェクト間でのテーマ共有

```css
/* packages/brand/theme.css */
@theme {
  --color-primary: oklch(0.65 0.2 25);
  --font-display: "Satoshi", sans-serif;
}
```

```css
/* apps/admin/app.css */
@import "tailwindcss";
@import "../../../packages/brand/theme.css";
```

---

## v4ディレクティブ完全リファレンス

| ディレクティブ | 用途 | 例 |
|-------------|------|-----|
| `@import "tailwindcss"` | Tailwindを有効化 | エントリCSSファイルの先頭 |
| `@theme { }` | デザイントークン定義 | カスタムカラー・フォント |
| `@source "../lib"` | 自動検出されないファイルを追加 | node_modules内のUIライブラリ |
| `@utility name { }` | カスタムユーティリティ追加 | `hover:`, `lg:` 対応 |
| `@custom-variant name { }` | カスタムバリアント定義 | テーマ切り替え用 |
| `@variant dark { }` | バリアントをカスタムCSSに適用 | インラインでダークスタイル |
| `@apply` | ユーティリティをカスタムCSSに埋め込み | サードパーティCSS上書き時 |
| `@layer base/components/utilities` | CSSレイヤの順序制御 | 詳細度管理 |

**v4でのCSS変数アクセス**（`theme()` 関数は非推奨）:

```css
/* 推奨: CSS変数を直接使用 */
.card {
  padding: var(--spacing-4);
  color: var(--color-gray-700);
}

/* 非推奨（v3レガシー） */
.card {
  padding: theme(spacing.4);
}
```

---

## v3セットアップ（レガシー）

> **注意**: v3は2024年以前のプロジェクトで使用。新規プロジェクトはv4を推奨。

### インストール

```bash
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

### tailwind.config.js

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/**/*.{html,js,jsx,ts,tsx}',
    './pages/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        brand: '#3B82F6',
      },
      spacing: {
        '128': '32rem',
      },
    },
  },
  plugins: [],
}
```

### CSSエントリ（v3）

```css
/* src/index.css */
@tailwind base;
@tailwind components;
@tailwind utilities;
```

### v3のCLI

```bash
# 開発
npx tailwindcss -i ./src/input.css -o ./dist/output.css --watch

# 本番ビルド
npx tailwindcss -i ./src/input.css -o ./dist/output.css --minify
```

### v3の重要オプション

| オプション | 用途 |
|-----------|------|
| `content` | JITがスキャンするファイルパターン（v4では不要） |
| `important` | 詳細度を強制的に上げる（既存CSSとの衝突対策） |
| `prefix` | クラス名のプレフィックス（例: `tw-`） |
| `darkMode: 'class'` | classベースのダークモード（v4は `@custom-variant`） |

---

## 設定対照表（v4 vs v3）

| 設定項目 | v4（CSS） | v3（JavaScript） |
|---------|---------|----------------|
| エントリポイント | `@import "tailwindcss"` | `@tailwind base; @tailwind components; @tailwind utilities;` |
| 設定ファイル | CSSファイル内 `@theme {}` | `tailwind.config.js` |
| content（スキャン対象） | 自動検出 | `content: ['./src/**/*.{html,js}']` |
| カラー追加 | `@theme { --color-brand: ... }` | `theme.extend.colors.brand: '#...'` |
| カラー全置換 | `@theme { --color-*: initial; ... }` | `theme.colors: { ... }` |
| ダークモード（class） | `@custom-variant dark (&:where(.dark, .dark *))` | `darkMode: 'class'` |
| プレフィックス | `@import "tailwindcss" prefix(tw)` | `prefix: 'tw-'` |
| カスタムユーティリティ | `@utility name { }` | `plugins: [plugin(({ addUtilities }) => ...)]` |
| プラグイン読み込み | `@plugin "@tailwindcss/typography"` | `plugins: [require('@tailwindcss/typography')]` |

---

## テーマカスタマイズ詳細

### カラー（colors）

```css
/* v4: デフォルトパレットに追加 */
@theme {
  --color-mint-100: oklch(0.97 0.04 178);
  --color-mint-500: oklch(0.72 0.11 178);
  --color-mint-900: oklch(0.29 0.07 178);
}
```

```javascript
// v3: theme.extend で追加（デフォルトを維持）
module.exports = {
  theme: {
    extend: {
      colors: {
        mint: {
          100: '#dcfce7',
          500: '#22c55e',
          900: '#14532d',
        },
      },
    },
  },
}
```

> **カラー形式**: v4では `oklch()` が推奨（色域が広く、知覚的に均一）。v3では `hex` や `rgb` が一般的。

### スペーシング（spacing）

```css
/* v4 */
@theme {
  --spacing-72: 18rem;   /* 288px */
  --spacing-84: 21rem;   /* 336px */
  --spacing-96: 24rem;   /* 384px */
}
```

```javascript
// v3
theme: {
  extend: {
    spacing: {
      '72': '18rem',
      '84': '21rem',
      '96': '24rem',
    }
  }
}
```

### ブレークポイント（screens）

```css
/* v4 */
@theme {
  /* デフォルトの sm を変更 */
  --breakpoint-sm: 30rem;  /* 480px */
  /* 新しいブレークポイントを追加 */
  --breakpoint-3xl: 120rem; /* 1920px */
}
```

```javascript
// v3
theme: {
  screens: {
    'sm': '480px',
    'md': '768px',
    'lg': '1024px',
    'xl': '1280px',
    '2xl': '1536px',
  }
}
```

### フォント（font-family）

```css
/* v4 */
@theme {
  --font-sans: "Inter", ui-sans-serif, system-ui, sans-serif;
  --font-display: "Satoshi", "sans-serif";
  --font-code: "JetBrains Mono", monospace;
}
```

```javascript
// v3
theme: {
  extend: {
    fontFamily: {
      display: ['Satoshi', 'sans-serif'],
      code: ['JetBrains Mono', 'monospace'],
    }
  }
}
```

---

## 開発ツール

### VS Code 拡張機能

**Tailwind CSS IntelliSense**（tailwindlabs.tailwindcss）:

- クラス名の自動補完
- ホバーでCSSプレビュー
- 構文ハイライト
- リンティング（不正なクラスの警告）

```json
// .vscode/settings.json 推奨設定
{
  "editor.quickSuggestions": {
    "strings": "on"
  },
  "tailwindCSS.experimental.classRegex": [
    ["clsx\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)"],
    ["cn\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)"]
  ]
}
```

### Prettier プラグイン

クラス名を自動的に推奨順序にソートする。

```bash
npm install -D prettier-plugin-tailwindcss
```

```json
// .prettierrc
{
  "plugins": ["prettier-plugin-tailwindcss"]
}
```

> **効果**: `flex items-center p-4 bg-white text-gray-900` のように、レイアウト → 色 → タイポグラフィの順序に自動整理される。

### Play CDN（プロトタイピング用）

HTMLファイル単体でTailwindを試せる（本番非推奨）：

```html
<!doctype html>
<html>
<head>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body>
  <h1 class="text-3xl font-bold text-blue-500">Hello Tailwind!</h1>
</body>
</html>
```

### Tailwind Play（オンラインプレイグラウンド）

- URL: https://play.tailwindcss.com
- ブラウザ上でリアルタイムにTailwindを試せる
- 設定ファイルも編集可能
- URLで共有可能

### @source によるコンテンツ指定（v4）

v4では通常自動検出されるが、node_modules内のUIライブラリなど検出されないケースで使用：

```css
@import "tailwindcss";

/* node_modules内のライブラリのクラスもスキャン対象に追加 */
@source "../node_modules/@my-company/ui-lib";
```

v3の `content` 設定に相当するが、v4では例外的なケースのみで使用。
