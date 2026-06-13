# カスタマイズ・プラグイン・プリセット リファレンス

Tailwind CSS の高度なカスタマイズ手法。v4 の CSS-first アプローチをプライマリとし、v3 レガシー設定も併記する。

---

## 目次

- [v4 カスタマイズ（プライマリ）](#v4-カスタマイズ)
- [v3 カスタマイズ（レガシー）](#v3-カスタマイズ)
- [プリセット配布](#プリセット配布)
- [設定マージの仕組み](#設定マージの仕組み)
- [JavaScript API](#javascript-api)
- [プラグイン作成](#プラグイン作成)

---

## v4 カスタマイズ

### @utility によるカスタムユーティリティ

v4 では CSS ファイル内に直接 `@utility` ディレクティブを記述してカスタムユーティリティを追加する。

```css
/* シンプルなユーティリティ */
@utility content-auto {
  content-visibility: auto;
}

/* ネストを含む複雑なユーティリティ */
@utility scrollbar-hidden {
  &::-webkit-scrollbar {
    display: none;
  }
}
```

#### 機能的ユーティリティ（引数付き）

`tab-*` のようなワイルドカードパターンで、動的に値を受け取るユーティリティを定義できる。

```css
@utility tab-* {
  tab-size: --value(--tab-size-*);
}
```

`--value()` 関数の主要な構文:

| 構文 | 用途 |
|------|------|
| `--value(--theme-key-*)` | テーマ変数の値にマッチ |
| `--value(integer)` | 整数値を受け取る |
| `--value([length])` | Arbitrary Values の長さ型 |
| `--value('literal')` | 固定リテラル値 |

### @custom-variant によるカスタムバリアント

v4 では `@custom-variant` ディレクティブで独自のバリアント（モディファイア）を定義できる。

```css
/* データ属性ベースのテーマバリアント */
@custom-variant theme-dark {
  &:where([data-theme="dark"] *) {
    @slot;
  }
}

/* 短縮構文 */
@custom-variant theme-dark (&:where([data-theme="dark"] *));
```

利用側のマークアップ:

```html
<html data-theme="dark">
  <div class="bg-white theme-dark:bg-gray-900">
    ...
  </div>
</html>
```

### @layer によるベーススタイルの追加

```css
@layer base {
  h1 {
    font-size: var(--text-2xl);
    font-weight: var(--font-bold);
  }
  h2 {
    font-size: var(--text-xl);
  }
}

@layer components {
  .card {
    background-color: var(--color-white);
    border-radius: var(--radius-lg);
    padding: --spacing(6);
  }
}
```

### @theme によるテーマ変数の拡張

カスタムデザイントークンを CSS 変数として `@theme` 内に定義する（v4 の中核）。

```css
@import "tailwindcss";

@theme {
  --color-brand-primary: oklch(0.60 0.20 260);
  --color-brand-secondary: oklch(0.75 0.15 180);
  --breakpoint-xs: 30rem;
  --font-display: "Satoshi", sans-serif;
  --spacing-18: 4.5rem;
}
```

これにより `bg-brand-primary`、`xs:text-sm`、`font-display` などのクラスが自動生成される。

---

## v3 カスタマイズ

> **レガシー注記**: 以下は `tailwind.config.js` を使用する v3 の設定。v4 への移行を推奨。

### safelist: 削除禁止クラスの定義

動的クラス生成などでコンテンツスキャンで検出できないクラスをビルド結果に強制含める。

```js
// tailwind.config.js
module.exports = {
  content: ["./src/**/*.{html,js}"],
  safelist: [
    "bg-red-500",
    "lg:text-4xl",
    {
      pattern: /bg-(red|green|blue)-(100|200|300)/,
      variants: ["lg", "hover", "focus"],
    },
  ],
};
```

**使用場面**: サーバーサイドから動的にクラスを生成するケース、ライブラリとしてビルド結果のクラス一覧を取得したいケース。通常のプロダクトコードでは不要。

### blocklist: 意図しないクラスを除外

コンテンツファイルに偶然含まれる単語がクラスとして誤検知される場合に防ぐ。

```js
module.exports = {
  blocklist: ["container"],
};
```

完全一致の文字列のみ指定可能（正規表現不可）。

### prefix: クラス名にプレフィックスを付与

既存 CSS との名前衝突を防ぐ。Tailwind CSS を既存プロジェクトに後から導入するときに有効。

```js
module.exports = {
  prefix: "tw-",
};
```

- `text-left` → `tw-text-left`
- `hover:text-right` → `hover:tw-text-right`
- 負の値: `-tw-mt-8`
- important: `sm:hover:!tw-font-bold`

**注意**: `darkMode: 'class'` と組み合わせる場合、`.dark` ではなく `.tw-dark` がダークモードの判定クラスになる。

### separator: `:` の代替文字を設定

Pug など特定テンプレートエンジンでは `:` がシンタックスエラーになる。

```js
module.exports = {
  separator: "_",
};
```

---

## プリセット配布

### プリセットの作成

`tailwind.config.js` と同じ形式のオブジェクトをエクスポートするだけでプリセットになる。

```js
// my-preset.js
/** @type {Partial<import('tailwindcss').Config>} */
module.exports = {
  theme: {
    colors: {
      brand: {
        light: "#85d7ff",
        DEFAULT: "#1fb6ff",
        dark: "#009eeb",
      },
    },
  },
  plugins: [
    require("@tailwindcss/typography"),
  ],
};
```

利用側:

```js
// tailwind.config.js
const myPreset = require("./my-preset.js");

module.exports = {
  presets: [myPreset],
  theme: {
    extend: {
      // プロジェクト固有のテーマ拡張
    },
  },
};
```

### npm パッケージとして配布

プリセットを npm パッケージ化するとデザインシステムの基盤ライブラリになる。

```js
// プリセット利用
module.exports = {
  presets: [require("@your-company/design-system-tailwind")],
};
```

異なる Tailwind CSS バージョンをサポートする場合、オブジェクトではなく関数をエクスポートする。

```js
module.exports = function createTailwindConfig({ version = "v3" } = {}) {
  switch (version) {
    case "v3":
      return { /* v3向け設定 */ };
    case "v2":
      return { /* v2向け設定 */ };
    default:
      throw new Error("サポートされていないバージョン");
  }
};
```

利用側:

```js
module.exports = {
  presets: [require("@company/tailwind-config")({ version: "v3" })],
};
```

---

## 設定マージの仕組み

### マージ優先度

以下の設定項目はプリセット側に記述しても、利用側（プロジェクト）の設定が優先される（上書きされる）:

| 設定項目 | 理由 |
|---------|------|
| `content` | プロジェクト固有のファイルパス |
| `darkMode` | プロジェクトの UI 要件 |
| `prefix` | 既存 CSS との兼ね合い |
| `important` | プロジェクトの詳細度方針 |
| `safelist` | プロジェクト固有のクラス |
| `separator` | テンプレートエンジン依存 |

### 再帰的マージ

プリセットの中にさらに `presets` をネストできる。Tailwind CSS は再帰的に `presets` を解決し、最終的にデフォルト設定も含めたフラットな配列に展開してからマージを行う。

```
プロジェクト設定 → プリセット A → プリセット A-1 → ... → デフォルト設定
```

デフォルト設定を完全に無効化したい場合:

```js
module.exports = {
  presets: [],  // デフォルトテーマを完全に排除
  theme: {
    // すべてのテーマを一から定義
  },
};
```

### ビルド結果に関与する設定をプリセットに含めない

共有ライブラリ（プリセット）として配布する際の原則:

- ✅ **含めるべき**: `theme`（デザイントークン）、デザインシステム固有の `plugins`
- ❌ **含めるべきでない**: `content`、`darkMode`、`prefix`、`important`、`corePlugins.preflight`

サードパーティプラグインへの依存は `peerDependencies` で宣言し、バージョン管理を利用側に委ねる:

```json
{
  "peerDependencies": {
    "tailwindcss": ">=3.0.0",
    "@tailwindcss/forms": ">=0.4.0"
  }
}
```

---

## JavaScript API

### resolveConfig によるテーマ値の参照

クライアントサイド JavaScript からテーマの値を参照する（v3）。

```js
import resolveConfig from "tailwindcss/resolveConfig";
import tailwindConfig from "./tailwind.config.js";

const { theme } = resolveConfig(tailwindConfig);

theme.width[4];        // => '1rem'
theme.screens.md;      // => '768px'
theme.boxShadow["2xl"]; // => '0 25px 50px ...'
```

**注意**: `resolveConfig` を使うとバンドルサイズが大きくなる。代替案:
- `babel-plugin-preval` でビルド時にインライン化
- デザイントークンを別パッケージに分離して独立インポート

### プリセットのスナップショットテスト

設定ファイルから生成されるクラスの回帰テストを行う実装例（v3 向け）:

```ts
import tailwindcss from "tailwindcss";
import postcss from "postcss";
import postcssSelectorParser from "postcss-selector-parser";

export async function extractClassNames(
  input: string,
  preset: Partial<import("tailwindcss").Config>
): Promise<string[]> {
  const plugin = tailwindcss({
    presets: [preset],
    safelist: [{ pattern: /./u, variants: [] }], // すべてのクラスを維持
  });

  const result = await postcss([plugin]).process(input, {
    from: undefined,
    to: undefined,
    map: false,
  });

  return getAllClassNames(result);
}

function getAllClassNames(result: postcss.Result): string[] {
  const classNames = new Set<string>();
  const selectorParser = postcssSelectorParser();

  result.root.walkRules((rule) => {
    const { nodes } = selectorParser.astSync(rule.selector);
    nodes.forEach((child) =>
      child.nodes.forEach((node) => {
        if (node.type === "class") {
          classNames.add(node.value.trim());
        }
      })
    );
  });

  return Array.from(classNames);
}
```

---

## プラグイン作成

> **v4 と v3 の違い**: v4 では `@utility`/`@custom-variant` ディレクティブ（CSS-first）が推奨。v3 の JavaScript Plugin API も引き続き利用可能。

### v3 プラグイン API の基本構造

```js
const plugin = require("tailwindcss/plugin");

module.exports = {
  plugins: [
    plugin(({ addUtilities, addComponents, addBase, addVariant, theme, config }) => {
      // ここにプラグイン定義を記述
    }),
  ],
};
```

プラグイン関数が受け取るオブジェクト:

| 関数 | 用途 |
|------|------|
| `addUtilities()` | `@layer utilities` にクラスを追加 |
| `addComponents()` | `@layer components` にクラスを追加 |
| `addBase()` | `@layer base` にスタイルを追加 |
| `addVariant()` | カスタムバリアントを追加 |
| `matchUtilities()` | Arbitrary Values 対応のユーティリティ |
| `matchComponents()` | Arbitrary Values 対応のコンポーネント |
| `theme()` | テーマ設定値を参照 |
| `config()` | 設定値を参照 |

### addUtilities / addComponents

CSS in JS 風の記法でクラスを定義する。

```js
plugin(({ addUtilities, addComponents, theme }) => {
  // ユーティリティの追加
  addUtilities({
    ".kerning-palt": {
      fontKerning: "normal",
      fontFeatureSettings: "'palt'",
    },
  });

  // コンポーネントの追加（ネスト記法対応）
  addComponents({
    ".vstack-4": {
      display: "flex",
      flexDirection: "column",
      "& > * + *": {
        marginTop: theme("spacing.4"),
      },
    },
  });
});
```

### matchUtilities / matchComponents

Arbitrary Values を受け入れる動的なクラスを定義する。

```js
plugin(({ matchComponents, theme }) => {
  matchComponents(
    {
      vstack: (value) => ({
        display: "flex",
        flexDirection: "column",
        "& > * + *": {
          marginTop: value,
        },
      }),
    },
    {
      values: theme("spacing"),
    }
  );
});
```

これにより `vstack-4`（テーマ値）や `vstack-[12px]`（Arbitrary Values）が使えるようになる。

### addBase: グローバルスタイルの定義

CSS Variables を使ったダークモード実装例:

```js
plugin.withOptions(
  ({ light, dark }) =>
    ({ addBase }) => {
      addBase({
        ":root": toCssVariables(light),
        "@media (prefers-color-scheme: dark)": {
          ":root": toCssVariables(dark),
        },
      });
    }
);

function toCssVariables(theme) {
  return Object.fromEntries(
    Object.entries(theme).map(([name, value]) => [`--color-${name}`, value])
  );
}
```

### addVariant / matchVariant: カスタムバリアント

```js
plugin(({ addVariant, matchVariant }) => {
  // 固定のバリアント
  addVariant("lang-en", "&:lang(en)");

  // Arbitrary Values 対応のバリアント
  matchVariant(
    "lang",
    (value) => `&:lang(${value})`,
    {
      values: { ja: "ja", en: "en" },
    }
  );
});
```

利用側:

```html
<p class="leading-relaxed lang-en:leading-loose">
  英語のときは行が広くなる
</p>
<p class="lang-[es]:leading-loose">
  スペイン語のときも
</p>
```

### プラグインに設定を含める

`plugin()` の第2引数でプラグインが使うテーマのデフォルト値を提供できる。

```js
const vstackPlugin = plugin(
  ({ matchComponents, theme }) => {
    matchComponents(
      { vstack: (value) => ({ /* ... */ }) },
      { values: theme("stack") }
    );
  },
  {
    // このプラグインを使うと theme.stack が追加される
    theme: {
      stack: {
        1: "0.25rem",
        2: "0.5rem",
        4: "1rem",
        8: "2rem",
      },
    },
  }
);
```

### プラグインにオプションを渡す

```js
// 方法1: 関数で包む
export function yourPlugin(option) {
  return plugin(({ addUtilities }) => {
    addUtilities(/* option を使った処理 */);
  });
}

// 方法2: plugin.withOptions を使う
export const yourPlugin = plugin.withOptions(
  (options) =>
    ({ addUtilities }) => {
      addUtilities(/* options を使った処理 */);
    },
  (options) => ({
    // options を使ってテーマを拡張
    theme: { /* ... */ },
  })
);
```

---

## AskUserQuestion ガイド

以下の判断が必要な場面でユーザーに確認する:

**確認すべき場面**:
- v4（`@utility` / CSS-first）か v3（JavaScript Plugin API）かの選択
- プリセットを単一プロジェクトで使うか、npm パッケージとして配布するか
- `safelist` の使用が適切かどうか（多くの場合不要）
- デフォルトテーマを `presets: []` で完全無効化するかどうか
- ダークモードを `dark:` モディファイアで対応するか、CSS Variables（セマンティックカラー）で対応するか

**確認不要な場面**:
- `prefix` 設定の使用（既存 CSS との衝突がある場合は必須）
- `peerDependencies` の使用（配布ライブラリでは必須）
