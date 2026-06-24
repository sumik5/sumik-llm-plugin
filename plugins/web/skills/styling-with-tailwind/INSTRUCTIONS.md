# styling-with-tailwind ガイド

Tailwind CSSのスタイリング方法論。ユーティリティファースト思想からv4設定・コンポーネント設計・デザインシステム構築まで体系的に提供する。

---

## 目次

- [ユーティリティファーストとは](#ユーティリティファーストとは)
- [CSS設計の歴史的文脈](#css設計の歴史的文脈)
- [Tailwind CSSフレームワーク概要](#tailwind-cssフレームワーク概要)
- [コアコンセプト（v4対応）](#コアコンセプトv4対応)
- [既存プロジェクトへの移行](#既存プロジェクトへの移行)
- [ユーザー確認の原則（AskUserQuestion）](#ユーザー確認の原則askuserquestion)
- [クイックリファレンス](#クイックリファレンス)
- [詳細リファレンスファイル](#詳細リファレンスファイル)

---

## ユーティリティファーストとは

### セマンティックCSSとの比較

**従来のセマンティックなアプローチ**: UIの「意味」に基づきクラスを命名し、そこにスタイルを定義する。

```css
/* セマンティックアプローチ */
.primary-button {
  appearance: none;
  cursor: pointer;
  background-color: var(--color-primary);
  color: var(--color-white);
  font-size: 14px;
  font-weight: bold;
  padding: 8px 24px;
  border-radius: 100vh;
}
```

```html
<button class="primary-button">Click Me!</button>
```

**ユーティリティファーストアプローチ**: 各CSSプロパティに対応した小さなクラス（ユーティリティクラス）を直接HTMLに記述する。

```html
<button class="appearance-none cursor-pointer bg-primary text-white
               text-sm font-bold py-2 px-6 rounded-full border-0">
  Click Me!
</button>
```

### ユーティリティファーストの3つのメリット

| メリット | 内容 |
|---------|------|
| **クラス名を考えなくてよい** | `.card__submit-button--disabled` のような苦しい命名が不要。ユーティリティクラスは既成の名前を使うだけ |
| **HTMLとCSSの往復が不要** | スタイル変更はHTMLファイルだけで完結。CSSファイルを行き来するコストがない |
| **影響範囲が明確** | `text-lg` は常に同じフォントサイズを指す。グローバルなCSSの衝突を気にしなくてよい |

### インラインスタイルとの違い

ユーティリティファーストはインラインスタイル（`style=""`）に似て見えるが、本質的に異なる：

- **設計されたスケール**: `text-sm`、`text-base`、`text-lg` など、あらかじめ決められた値の集合から選ぶ
- **レスポンシブ・擬似クラス**: `md:text-lg`、`hover:text-blue-500` など、モディファイアを組み合わせ可能
- **一貫性の強制**: テーマに存在しない任意の値はArbitrary Valuesとして明示的に記述（乱用しない）

---

## CSS設計の歴史的文脈

### 2000年代〜2010年代前半：BEMとコーディング規約の時代

BEM（Block Element Modifier）は命名規則によってCSSのグローバルスコープ問題に対処した：

```html
<!-- BEM記法 -->
<div class="card">
  <div class="card__body">
    <h1 class="card__heading">Title</h1>
    <button class="card__submit-button card__submit-button--disabled">Submit</button>
  </div>
</div>
```

**BEMの限界**: トップレベル（Block）の命名はサイト全体でユニークにする必要があり、大規模プロジェクトでは苦しい命名を余儀なくされる。

### 2010年代中盤：CSS ModulesとScoped CSS

Reactのコンポーネント志向と同期し、ビルド時にクラス名をランダム化して擬似的なスコープを実現：

```jsx
// CSS Modules
import styles from './Card.module.css';
<div className={styles.card}>...</div>
// → <div class="Card__card__a8c7d">...</div>
```

**意義**: 命名衝突の問題は解決。しかしCSSの書き方自体は変わらず、スタイルの増殖・一貫性のなさは残った。

### 2010年代後半：CSS in JS

styled-components・emotionなどがランタイムでスタイルを定義し、テーマオブジェクトを型安全に扱える道を開いた：

```jsx
const Button = styled.button`
  background-color: ${({ theme }) => theme.colors.primary};
  color: ${({ theme }) => theme.colors.white};
`;
```

**CSS in JSが残した功績**: テーマオブジェクト（デザイントークン）という概念の普及。スタイル値の型安全な参照。

### ユーティリティファーストが解決したこと

上記すべての課題を統合的に解決する：

- **CSSの増殖を防ぐ**: 新しいCSSを書かず既存クラスを組み合わせる
- **命名問題を回避**: クラス名は既成のユーティリティ名のみ
- **一貫性の強制**: テーマに基づくスケールから外れた値は明示的に書かなければならない
- **スコープの自然解決**: ユーティリティクラスはもとからグローバルで衝突しない設計

---

## Tailwind CSSフレームワーク概要

### 提供するもの

| 機能 | 説明 |
|------|------|
| **ユーティリティクラスの網羅的な定義** | CSS全プロパティに対応したクラス群を静的CSSで提供 |
| **バリアント（モディファイア）** | `hover:`、`md:`、`dark:`、`focus:` など条件付きスタイルのサポート |
| **カスタマイズ機能** | テーマ（色、スペーシング、フォント等）をプロジェクトに合わせて拡張・上書き |
| **最小サイズのCSS出力** | 実際に使用したクラスのみをビルドに含む（JIT）|

### 提供しないもの

| 非提供 | 理由・代替手段 |
|--------|--------------|
| **UIコンポーネント（ボタン、モーダル等）** | デザインはプロジェクト次第。shadcn/ui・Headless UIなど外部ライブラリと組み合わせる |
| **CSSの理解を不要にするもの** | Flexbox、Grid、カスケーディングの理解は依然として必要 |
| **JavaScriptによる動的挙動** | アニメーション・トランジションの複雑な制御は別途ライブラリが必要 |

---

## コアコンセプト（v4対応）

### JIT（Just-In-Time コンパイル）

v3以降標準搭載。v4でもRust製Oxideエンジンとして進化している。

**JIT以前（AOT時代）の問題**:
- 開発環境と本番環境で使えるCSSが異なった
- 使わないクラスをPurgeCSSで削除する必要があった
- Arbitrary Valuesが使えなかった

**JIT以降**:
- 開発・本番とも使用クラスのみビルドに含まれる
- `text-[13px]`、`grid-cols-[repeat(3,1fr)]` などArbitrary Valuesが使える
- モディファイアの組み合わせに制限がなくなった

### ディレクティブ（v4 vs v3）

#### v4（推奨）

```css
/* v4: CSS-first config */
@import "tailwindcss";

/* テーマカスタマイズ */
@theme {
  --color-brand: oklch(0.65 0.2 25);
  --font-display: "Satoshi", sans-serif;
}

/* カスタムユーティリティ */
@utility tab-4 {
  tab-size: 4;
}

/* カスタムバリアント */
@custom-variant theme-dark (&:where([data-theme="dark"] *));

/* カスタムベーススタイル */
@layer base {
  h1 { font-size: var(--text-2xl); }
}

/* サードパーティCSS統合時 */
.select2-dropdown {
  @apply rounded-b-lg shadow-md;
}
```

#### v3（レガシー参考）

```css
/* v3 */
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer components {
  .btn-primary {
    @apply py-2 px-4 bg-blue-500 text-white rounded;
  }
}
```

> **v4での注意**: `@apply` は依然サポートされているが、`@utility` または通常のCSSクラスを推奨。`theme()` 関数は非推奨で `var(--color-*)` などCSS変数を直接使うことを推奨。

### Preflight

Tailwind CSSが自動的に適用するCSSリセット（`modern-normalize` ベース）。

**主な変更内容**:

| 対象要素 | Preflightの効果 |
|---------|----------------|
| `h1`〜`h6` | フォントサイズ・ウェイトをすべて継承値に（ブラウザデフォルト除去） |
| `ul`、`ol` | マーカー（bullet）を除去 |
| `img`、`video` | `display: block` に変更（デフォルトのインライン配置を除去） |
| すべての要素 | `margin: 0; padding: 0; box-sizing: border-box` |
| `border` | `border: 0 solid` に統一（`border` クラスで即座に1px罫線が入る仕組み） |

**v4でのPreflight制御**:

```css
/* Preflightを無効化（既存プロジェクト移行時） */
@layer theme, base, components, utilities;
@import "tailwindcss/theme.css" layer(theme);
/* @import "tailwindcss/preflight.css" layer(base);  ← この行を省く */
@import "tailwindcss/utilities.css" layer(utilities);
```

**Preflightの拡張**:

```css
@layer base {
  a {
    color: var(--color-blue-600);
    text-decoration-line: underline;
  }
}
```

### ダークモード

#### v4: @custom-variant でカスタマイズ（推奨）

```css
/* app.css */
@import "tailwindcss";

/* classベースのダークモード（手動切り替え） */
@custom-variant dark (&:where(.dark, .dark *));
```

```html
<html class="dark">
  <body>
    <div class="bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
      ...
    </div>
  </body>
</html>
```

#### デフォルト: prefers-color-scheme（メディアクエリ）

```html
<!-- OSのダークモード設定に自動追従 -->
<div class="bg-white dark:bg-gray-800">...</div>
```

#### 三段階テーマ（Light/Dark/System）の実装

```javascript
// ページロード時にFOUCを防ぐため <head> 内インラインスクリプトで設定
document.documentElement.classList.toggle(
  'dark',
  localStorage.theme === 'dark' ||
    (!('theme' in localStorage) &&
      window.matchMedia('(prefers-color-scheme: dark)').matches)
);
```

| 方式 | 用途 | Tailwind設定 |
|------|------|-------------|
| メディアクエリ（デフォルト） | OS設定に追従 | 不要 |
| classベース | 手動切り替え | `@custom-variant dark (&:where(.dark, .dark *))` |
| data属性ベース | 手動切り替え（セマンティック） | `@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *))` |

---

## 既存プロジェクトへの移行

### 移行戦略の選択

**段階的移行**:
1. Tailwindを新規コンポーネントにのみ適用
2. 既存CSSはそのまま残す
3. リファクタ時に順次Tailwindへ置き換える

**Preflightの無効化**（既存CSSとの衝突防止）:

既存プロジェクトでは見出しスタイル・リストスタイルのリセットが既存CSSと衝突する可能性がある。

> **⚠️ 必ずユーザー確認**: Preflightを無効化するかどうかはプロジェクトの既存CSS構造に依存する。AskUserQuestionで確認すること。

### prefixによる命名衝突の回避

既存のCSSクラスと同名のTailwindクラスが存在する場合（例: `.container`、`.prose`）:

**v4でのprefix設定**:

```css
@import "tailwindcss" prefix(tw);
```

これにより `tw-text-white`、`tw-bg-blue-500` のように使用する。

### CSSプリプロセッサとの関係

| プリプロセッサ | 併用可否 | 推奨 |
|-------------|---------|------|
| Sass (.scss) | 可能だが課題あり | 新規なら使わない |
| Less | 可能だが課題あり | 新規なら使わない |
| Stylus | 可能だが課題あり | 新規なら使わない |
| PostCSS | v4でも利用可能 | プロジェクトによる |

> **推奨**: 新規プロジェクトはTailwind v4のCSS-first configのみで管理する。プリプロセッサとの併用は移行期間中の過渡的措置にとどめる。

---

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

- **バージョン確認**: v4（CSS-first config）かv3（tailwind.config.js）か
- **CSS設計方針**: ユーティリティファースト一本 vs セマンティッククラスとのハイブリッド
- **Tailwind導入方法**: Viteプラグイン / PostCSS / スタンドアローンCLI
- **テーマカスタマイズ方針**: デフォルトを拡張 vs 完全カスタムテーマ（`--*: initial`）
- **ダークモード実装方式**: prefers-color-scheme / classベース / data属性ベース
- **コンポーネントのスタイル上書き戦略**: バリエーション定義 vs className props受け入れ
- **デザイントークン命名方針**: リテラル（`--color-blue-500`）vs セマンティック（`--color-primary`）
- **既存プロジェクト移行**: Preflight無効化の要否（既存CSSとの衝突確認）
- **prefixの導入**: 既存CSSクラスとの命名衝突リスクがある場合

### 確認不要な場面

- ユーティリティクラスの基本的な使い方（明確なベストプラクティスがある）
- JITの利用（v3以降は標準、v4でも同様）
- `@apply` の過剰使用（公式に非推奨。代わりに `@utility` またはReactコンポーネント化を推奨）

---

## クイックリファレンス

### バージョン選択

| 状況 | 選択 |
|------|------|
| 新規プロジェクト | v4（CSS-first config）|
| 既存v3プロジェクト | v3のまま継続、v4移行は計画的に |
| Next.js 15以降 | v4が標準 |
| Vite + React/Vue | v4（`@tailwindcss/vite`プラグイン）|

### セットアップ方式

| 方式 | 用途 |
|------|------|
| `@tailwindcss/vite` | Viteベースプロジェクト（推奨） |
| PostCSS plugin | Express・Ruby on Railsなどビルドツール組み込み時 |
| スタンドアローンCLI | Node.jsなしの環境 |

### テーマカスタマイズ

| 操作 | v4 CSS | v3 JS |
|------|--------|-------|
| 色を追加 | `@theme { --color-brand: oklch(...); }` | `theme.extend.colors.brand: '#...'` |
| デフォルト色を全置換 | `@theme { --color-*: initial; ... }` | `theme.colors: { ... }` |
| スペーシング追加 | `@theme { --spacing-72: 18rem; }` | `theme.extend.spacing['72']: '18rem'` |
| ブレークポイント変更 | `@theme { --breakpoint-sm: 30rem; }` | `theme.screens.sm: '480px'` |

### よく使うモディファイア

| カテゴリ | 例 |
|---------|-----|
| レスポンシブ | `sm:`, `md:`, `lg:`, `xl:`, `2xl:` |
| ダークモード | `dark:` |
| 擬似クラス | `hover:`, `focus:`, `active:`, `disabled:`, `checked:` |
| 擬似要素 | `before:`, `after:`, `placeholder:`, `selection:` |
| 子要素制御 | `group-hover:` (`group`親要素必須), `peer-focus:` (`peer`兄弟必須) |
| データ属性 | `data-[state=open]:`, `aria-[hidden=true]:` |

### Arbitrary Values（任意の値）

```html
<!-- スケール外の値を使いたい場合 -->
<div class="text-[13px] w-[calc(100%-2rem)] grid-cols-[1fr_2fr]">
  ...
</div>

<!-- Arbitrary Variants -->
<div class="[&:nth-child(3)]:underline">...</div>

<!-- Arbitrary Properties -->
<div class="[text-shadow:1px_1px_2px_black]">...</div>
```

---

## 詳細リファレンスファイル

| ファイル | 内容 |
|---------|------|
| [`references/SETUP-AND-CONFIG.md`](references/SETUP-AND-CONFIG.md) | v4/v3セットアップ手順・設定ファイル・テーマカスタマイズ詳細 |
| [`references/UTILITY-REFERENCE.md`](references/UTILITY-REFERENCE.md) | 全ユーティリティカテゴリ一覧・モディファイア・Arbitrary記法 |
| [`references/COMPONENT-PATTERNS.md`](references/COMPONENT-PATTERNS.md) | コンポーネント設計パターン・ヘッドレスUI連携・配布戦略 |
| [`references/CUSTOMIZATION.md`](references/CUSTOMIZATION.md) | プラグイン作成・プリセット・JavaScript API |
| [`references/DESIGN-SYSTEMS.md`](references/DESIGN-SYSTEMS.md) | デザイントークン設計・カラーパレット階層・継続的運用 |
