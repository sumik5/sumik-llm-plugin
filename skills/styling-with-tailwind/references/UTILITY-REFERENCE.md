# ユーティリティ・モディファイアリファレンス

Tailwind CSS のユーティリティクラス・モディファイア・特殊記法の包括的なリファレンス。
v4をプライマリ、v3をレガシー参照として記述。

## 目次

1. [マークアップ戦略](#マークアップ戦略)
2. [ユーティリティカテゴリ別クイックリファレンス](#ユーティリティカテゴリ別クイックリファレンス)
3. [モディファイア（バリアント）一覧](#モディファイアバリアント一覧)
4. [特殊記法（Arbitrary系）](#特殊記法arbitrary系)
5. [公式プラグイン](#公式プラグイン)
6. [v4変更点まとめ](#v4変更点まとめ)

---

## マークアップ戦略

### クラス重複の防止パターン

ユーティリティクラスで生じる「似たようなクラスのコピー&ペースト」問題への対処法。

| アプローチ | 適用場面 | 例 |
|-----------|---------|-----|
| **ループ（最優先）** | 同じ要素が繰り返し登場する場合 | `items.map(item => <li className="...">{item}</li>)` |
| **コンポーネント抽出** | 複数ファイルで同一マークアップを再利用 | `<VacationCard>`, `<Button>` コンポーネント |
| **変数化** | 同一ファイル内で複数要素が同クラスを共有 | `const wrapperClass = "p-8 bg-gray-100"` |
| **@layer components** | テンプレートエンジン等でJSコンポーネントが使えない場合（最終手段） | `.btn-primary { ... }` |

> **重要**: `@apply` は非推奨。コンポーネント抽出・ループが使える環境では不要。
> 問題の本質は「クラスが長い」ことではなく「同じクラスのコピー&ペーストで変更漏れが起きる」こと。

### クラス管理ツール

```bash
# Prettier + tailwindcss プラグイン（v4対応）
# → クラスの自動ソート
npm install -D prettier prettier-plugin-tailwindcss
```

```js
// prettier.config.js
export default {
  plugins: ['prettier-plugin-tailwindcss'],
  tailwindFunctions: ['clsx', 'cn'],  // クラス結合関数も対象に
}
```

**クラス結合ライブラリの使い分け**

| ライブラリ | 特徴 | 用途 |
|-----------|------|------|
| `clsx` | 条件付きクラス結合、シンプル | 基本的な条件分岐 |
| `classnames` | `clsx` と近い、配列・オブジェクト対応 | レガシーコードとの互換 |
| `tailwind-merge` | Tailwind競合クラスを自動排除 | className propsを受け取るコンポーネント |
| `cva` | バリエーション管理（型安全） | デザインシステムのボタン等 |

**衝突解決の例（tailwind-merge）**

```ts
import { twMerge } from 'tailwind-merge'
// p-4 と p-6 が衝突 → 後者が残る
twMerge('p-4', 'p-6')  // → 'p-6'
```

### クラス抽出の仕組み（v4）

v4はソースコードをパースせず**正規表現でクラスを検出**する。そのためクラス名は必ず文字列として完全に書く必要がある。

```html
<!-- ✅ OK: 完全なクラス名 -->
<div class="text-red-500">

<!-- ❌ NG: 動的結合（クラスが検出されない） -->
<div class="text-{{ color }}-500">
```

---

## ユーティリティカテゴリ別クイックリファレンス

### 背景

| クラスパターン | CSSプロパティ | 例 |
|--------------|-------------|-----|
| `bg-{color}` | `background-color` | `bg-red-500`, `bg-[#0096fa]` |
| `bg-{color}/{opacity}` | `background-color` with opacity | `bg-cyan-500/75` |
| `bg-{gradient}` | `background-image` gradient | `bg-gradient-to-r from-sky-500 to-indigo-500` |
| `bg-{position}` | `background-position` | `bg-center`, `bg-[url('/img.png')]` |
| `bg-{size}` | `background-size` | `bg-cover`, `bg-contain` |

### 文字

| クラスパターン | CSSプロパティ | 例 |
|--------------|-------------|-----|
| `text-{color}` | `color` | `text-gray-700`, `text-white` |
| `text-{size}` | `font-size` + `line-height` | `text-sm`, `text-xl`, `text-lg/loose` |
| `font-{weight}` | `font-weight` | `font-normal`, `font-bold`, `font-semibold` |
| `font-{family}` | `font-family` | `font-sans`, `font-mono` |
| `leading-{value}` | `line-height` | `leading-tight`, `leading-relaxed` |
| `tracking-{value}` | `letter-spacing` | `tracking-wide`, `tracking-tight` |
| `text-{align}` | `text-align` | `text-left`, `text-center` |
| `underline`, `line-through` | `text-decoration-line` | — |
| `decoration-{color}`, `decoration-{style}` | `text-decoration` | `decoration-sky-400 decoration-wavy` |
| `truncate`, `text-ellipsis` | overflow処理 | — |
| `italic`, `not-italic` | `font-style` | — |
| `tabular-nums` | `font-variant-numeric` | 数字の等幅表示 |

### スペーシング

| クラスパターン | CSSプロパティ | 例 |
|--------------|-------------|-----|
| `p-{value}` | `padding`（全方向） | `p-4`, `p-8` |
| `px-{value}`, `py-{value}` | 水平/垂直 padding | `px-6 py-2` |
| `pt/pr/pb/pl-{value}` | 各方向 padding | — |
| `m-{value}`, `mx-{value}`, `my-{value}` | margin | `mx-auto` |
| `mt/mr/mb/ml-{value}` | 各方向 margin | — |
| `space-x-{value}`, `space-y-{value}` | 子要素間スペース | `space-y-4` |
| `gap-{value}` | Grid/Flex gap | `gap-4`, `gap-x-6 gap-y-4` |

### ボーダー

| クラスパターン | CSSプロパティ | 例 |
|--------------|-------------|-----|
| `border`, `border-{width}` | `border-width` | `border`, `border-2` |
| `border-{color}` | `border-color` | `border-gray-300` |
| `border-{style}` | `border-style` | `border-dashed` |
| `rounded`, `rounded-{size}` | `border-radius` | `rounded-lg`, `rounded-full` |
| `ring-{width}` | `box-shadow`（outline風） | `ring-2 ring-blue-500` |
| `outline-{value}` | `outline` | `outline-none`, `outline-2` |
| `divide-{value}` | 子要素間ボーダー | `divide-y divide-gray-200` |

### サイズ・配置

| クラスパターン | CSSプロパティ | 例 |
|--------------|-------------|-----|
| `w-{value}`, `h-{value}` | `width`, `height` | `w-full`, `h-screen`, `w-64` |
| `size-{value}` | `width` + `height`（正方形） | `size-12` |
| `min-w-{value}`, `max-w-{value}` | min/max-width | `max-w-sm`, `max-w-screen-lg` |
| `min-h-{value}`, `max-h-{value}` | min/max-height | `min-h-screen` |
| `aspect-{ratio}` | `aspect-ratio` | `aspect-video`, `aspect-square` |

### Flex

| クラスパターン | 説明 | 例 |
|--------------|------|-----|
| `flex` | `display: flex` | — |
| `flex-row`, `flex-col` | 方向 | — |
| `items-{align}` | `align-items` | `items-center`, `items-start` |
| `justify-{value}` | `justify-content` | `justify-between`, `justify-center` |
| `flex-wrap`, `flex-nowrap` | 折り返し | — |
| `flex-1`, `flex-auto`, `flex-none` | grow/shrink/basis | — |
| `shrink-0` | `flex-shrink: 0`（重要） | — |
| `grow` | `flex-grow: 1` | — |
| `order-{n}` | 並び順 | — |
| `self-{value}` | `align-self` | `self-center` |

### Grid

| クラスパターン | 説明 | 例 |
|--------------|------|-----|
| `grid` | `display: grid` | — |
| `grid-cols-{n}` | カラム数 | `grid-cols-3`, `grid-cols-[1fr_500px_2fr]` |
| `grid-rows-{n}` | 行数 | — |
| `col-span-{n}` | カラム結合 | `col-span-2` |
| `row-span-{n}` | 行結合 | — |
| `auto-cols-{value}` | 暗黙カラム幅 | `auto-cols-fr` |

### 表示・非表示・位置

| クラスパターン | 説明 |
|--------------|------|
| `hidden` | `display: none` |
| `block`, `inline`, `inline-block` | `display` 値 |
| `invisible` | `visibility: hidden`（スペースを保持、アニメーション可） |
| `sr-only` | スクリーンリーダーのみ表示 |
| `relative`, `absolute`, `fixed`, `sticky` | `position` |
| `inset-{value}`, `top/right/bottom/left-{value}` | 位置オフセット |
| `z-{value}` | `z-index` |
| `overflow-{value}` | `overflow` |

### エフェクト・フィルタ

| クラスパターン | 説明 | 例 |
|--------------|------|-----|
| `shadow`, `shadow-{size}` | `box-shadow` | `shadow-md`, `shadow-lg` |
| `opacity-{value}` | `opacity` | `opacity-75`, `opacity-0` |
| `blur`, `blur-{size}` | `filter: blur()` | `blur-sm` |
| `grayscale` | `filter: grayscale(100%)` | — |
| `backdrop-blur-{size}` | `backdrop-filter: blur()` | `backdrop-blur-sm` |
| `mix-blend-{mode}` | `mix-blend-mode` | — |
| `cursor-{value}` | `cursor` | `cursor-pointer`, `cursor-not-allowed` |
| `select-{value}` | `user-select` | `select-none` |
| `pointer-events-{value}` | `pointer-events` | `pointer-events-none` |
| `resize`, `resize-none` | `resize` | — |

### アニメーション・トランスフォーム

| クラスパターン | 説明 | 例 |
|--------------|------|-----|
| `transition`, `transition-{prop}` | `transition-property` | `transition-colors`, `transition-all` |
| `duration-{ms}` | `transition-duration` | `duration-300` |
| `ease-{type}` | `transition-timing-function` | `ease-in-out`, `ease-linear` |
| `delay-{ms}` | `transition-delay` | `delay-150` |
| `animate-spin` | `animation: spin` | ローディングアイコン |
| `animate-bounce` | `animation: bounce` | — |
| `animate-pulse` | `animation: pulse` | スケルトン表示 |
| `animate-none` | `animation: none` | — |
| `scale-{value}` | `transform: scale()` | `hover:scale-105` |
| `rotate-{deg}` | `transform: rotate()` | `rotate-45` |
| `translate-x-{value}`, `translate-y-{value}` | `transform: translate()` | `-translate-x-full`（スライドアウト） |

---

## モディファイア（バリアント）一覧

### インタラクティブ状態

```html
<!-- 基本的なインタラクティブ状態 -->
<button class="bg-blue-500 hover:bg-blue-600 active:bg-blue-700 focus:outline-none focus-visible:ring-2">
```

| モディファイア | 対応擬似クラス | 説明 |
|-------------|-------------|------|
| `hover:` | `:hover` | マウスオーバー時 |
| `active:` | `:active` | 押下中 |
| `visited:` | `:visited` | 訪問済みリンク（色系のみ） |
| `focus:` | `:focus` | フォーカス時（クリック+キーボード） |
| `focus-within:` | `:focus-within` | 子孫がフォーカス中 |
| `focus-visible:` | `:focus-visible` | キーボードフォーカス時のみ |

### フォーム状態

| モディファイア | 説明 |
|-------------|------|
| `disabled:` | `disabled` 属性のある要素 |
| `enabled:` | `disabled` でない要素 |
| `read-only:` | `readonly` 属性のある要素 |
| `checked:` | チェック済みフォーム要素 |
| `indeterminate:` | 中間状態（チェックボックス） |
| `required:` | `required` 属性のある要素 |
| `valid:`, `invalid:` | バリデーション結果 |
| `in-range:`, `out-of-range:` | min/max の範囲判定 |
| `autofill:` | ブラウザ自動補完後 |
| `placeholder:` | プレースホルダースタイル |

### 構造的擬似クラス

| モディファイア | 説明 |
|-------------|------|
| `first:`, `last:` | 最初/最後の子要素 |
| `odd:`, `even:` | 奇数/偶数番目 |
| `nth-{n}:` | n番目（v4で追加） |
| `empty:` | 子を持たない要素 |
| `target:` | URLフラグメントが一致 |
| `has-{selector}:` | 指定の子孫を持つ |
| `not-{selector}:` | 条件の否定 |

### 擬似要素

```html
<span class="after:ml-0.5 after:text-red-500 after:content-['*']">必須</span>
<input class="placeholder:text-gray-400 placeholder:italic" />
<input type="file" class="file:mr-4 file:rounded-full file:bg-violet-50" />
<ul class="list-disc marker:text-sky-400">
<div class="selection:bg-fuchsia-300">
<p class="first-letter:float-left first-letter:text-7xl first-line:uppercase">
```

| モディファイア | 対象 |
|-------------|------|
| `before:`, `after:` | `::before`, `::after` |
| `placeholder:` | `::placeholder` |
| `file:` | `::file-selector-button` |
| `marker:` | `::marker`（リストマーカー） |
| `selection:` | `::selection`（テキスト選択） |
| `first-line:`, `first-letter:` | `::first-line`, `::first-letter` |

### 親・兄弟の状態連動

**Group（親の状態で子をスタイリング）**

```html
<a href="#" class="group">
  <h3 class="group-hover:text-white">タイトル</h3>
  <p class="group-hover:text-gray-300">説明</p>
</a>

<!-- 名前付きグループ（ネスト対応） -->
<li class="group/item hover:bg-gray-50">
  <button class="invisible group-hover/item:visible">編集</button>
</li>
```

**Peer（前の兄弟要素の状態で後続をスタイリング）**

```html
<input type="email" class="peer invalid:border-red-400" />
<p class="invisible peer-invalid:visible text-red-500">有効なメールアドレスを入力してください</p>
```

### レスポンシブ・メディアクエリ

**ブレークポイント（v4デフォルト）**

| プレフィックス | 最小幅 | メディアクエリ |
|-------------|-------|-------------|
| `sm:` | 40rem (640px) | `@media (width >= 40rem)` |
| `md:` | 48rem (768px) | `@media (width >= 48rem)` |
| `lg:` | 64rem (1024px) | `@media (width >= 64rem)` |
| `xl:` | 80rem (1280px) | `@media (width >= 80rem)` |
| `2xl:` | 96rem (1536px) | `@media (width >= 96rem)` |

```html
<!-- モバイルファースト（プレフィックスなし = モバイル） -->
<img class="w-16 md:w-32 lg:w-48" />

<!-- 範囲指定（v4） -->
<div class="md:max-lg:flex"><!-- md以上lg未満 --></div>

<!-- コンテナクエリ（v4） -->
<div class="@container">
  <div class="flex flex-col @md:flex-row">...</div>
</div>
```

**ユーザー設定・システム状態**

| モディファイア | 条件 |
|-------------|------|
| `dark:` | ダークモード |
| `motion-reduce:` | 動きを減らす設定 |
| `motion-safe:` | 動きが安全な設定 |
| `contrast-more:` | コントラスト強調設定 |
| `forced-colors:` | 強制色モード |
| `print:` | 印刷時 |
| `portrait:`, `landscape:` | デバイスの向き |
| `pointer-coarse:` | タッチデバイス |
| `ltr:`, `rtl:` | テキスト方向 |

**属性・データ属性**

```html
<th aria-sort="ascending" class="aria-[sort=ascending]:bg-blue-50">
<div data-active class="data-active:border-purple-500">
<details class="open:border-black/10 open:bg-gray-100">
```

---

## 特殊記法（Arbitrary系）

### Arbitrary Values（任意の値）

設定テーマにない値を一度限り使う場合に `[...]` で囲む。

```html
<!-- 色 -->
<a class="bg-[#0096fa] text-white">外部ブランドカラー</a>

<!-- 寸法 -->
<div class="top-[117px] lg:top-[344px]">

<!-- 複数値（スペースは _ で代替） -->
<div class="grid grid-cols-[1fr_500px_2fr]">

<!-- CSS Variables -->
<div class="h-[var(--parent-height)]">
<!-- 省略記法 -->
<div class="h-[--parent-height]">

<!-- データ型ヒント（変数の型が曖昧な場合） -->
<div class="text-[length:var(--my-var)]">  <!-- 長さ -->
<div class="text-[color:var(--my-var)]">   <!-- 色 -->
```

### Arbitrary Variants（任意のバリアント）

```html
<!-- カスタムセレクタ -->
<li class="[&:nth-child(3)]:underline">3番目のみ下線</li>

<!-- スペースを含むセレクタ -->
<div class="[&_p]:mt-4">  <!-- 子孫のp要素にmt-4 -->

<!-- group/peer との組み合わせ -->
<div class="group-[.is-published]:block hidden">公開時のみ表示</div>
```

### Arbitrary Properties（任意のプロパティ）

Tailwind がカバーしていない CSS プロパティを直接指定。

```html
<div class="[mask-type:luminance] hover:[mask-type:alpha]">
<div class="[--scroll-offset:56px] lg:[--scroll-offset:44px]">
```

> **使い分け**: プロジェクト内で複数箇所で使うなら `@utility` ディレクティブ（v4）または `@layer utilities`（v3）でカスタムクラスを定義するほうが保守性が高い。

### 動的スタイルとCSS Variables の連携

```tsx
// インラインスタイルでCSS Variableを定義 → Arbitrary Valuesで参照
function BrandButton({ color, hoverColor }: Props) {
  return (
    <button
      style={{ '--brand': color, '--brand-hover': hoverColor }}
      className="bg-(--brand) hover:bg-(--brand-hover)"
    >
      {children}
    </button>
  )
}
```

---

## 公式プラグイン

### @tailwindcss/typography

コントロールできないHTML（外部APIのコンテンツ、Markdownレンダリング等）に対して読みやすいタイポグラフィを適用する `prose` クラスを提供。

```bash
npm install -D @tailwindcss/typography
```

```css
/* v4: CSS設定 */
@import "tailwindcss";
@plugin "@tailwindcss/typography";
```

```html
<!-- 基本使用 -->
<article class="prose lg:prose-xl">
  <!-- スタイル制御できないHTML -->
  {{ raw_html }}
</article>

<!-- ダークモード対応 -->
<article class="prose dark:prose-invert">

<!-- サイズバリエーション -->
<article class="prose prose-sm md:prose-lg xl:prose-xl">

<!-- 要素別カスタマイズ -->
<article class="prose prose-headings:underline prose-a:text-blue-600 prose-img:rounded-xl">
```

| クラス | 説明 |
|-------|------|
| `.prose` | デフォルト（グレー系） |
| `.prose-{color}` | カラーテーマ変更（slate/zinc/stone等） |
| `.prose-invert` | 色反転（ダークモード用） |
| `.prose-sm` / `.prose-lg` / `.prose-xl` | サイズ縮尺変更 |
| `.prose-{element}:` | 特定要素スタイル（`prose-headings:`, `prose-a:` 等） |

### @tailwindcss/forms

フォーム要素のデフォルトスタイルをリセットし、ユーティリティで整えやすい状態にする。

```bash
npm install -D @tailwindcss/forms
```

```html
<input type="email" class="rounded-md border-gray-300 focus:border-indigo-500 focus:ring-indigo-500">
<select class="rounded-md border-gray-300">
```

### @tailwindcss/container-queries

コンテナクエリ（`@container`）対応。v4では標準内蔵のため不要。

```html
<!-- v4: 標準で対応済み -->
<div class="@container">
  <div class="flex @md:flex-row @lg:grid @lg:grid-cols-3">
```

---

## v4変更点まとめ

### 削除・変更されたユーティリティ

| v3 | v4 | 変更内容 |
|----|-----|---------|
| `bg-opacity-{value}` | `bg-{color}/{opacity}` | 不透明度の記法統合 |
| `text-opacity-{value}` | `text-{color}/{opacity}` | 同上 |
| `border-opacity-{value}` | `border-{color}/{opacity}` | 同上 |
| `overflow-ellipsis` | `text-ellipsis` | 名称変更 |
| `decoration-slice` | `box-decoration-slice` | 名称変更 |
| `transform` (明示的クラス) | 自動 | transform ユーティリティ使用で自動適用 |

### v4で追加されたユーティリティ

| クラス | 説明 |
|-------|------|
| `size-{value}` | `width` + `height` を同時指定 |
| `nth-{n}:` | `:nth-child()` バリアント |
| `not-{selector}:` | `:not()` バリアント |
| `*:` | 直接子要素へのスタイル |
| `**:` | すべての子孫へのスタイル |
| `starting:` | `@starting-style` バリアント |
| `inset-{value}` | `top/right/bottom/left` 一括指定 |
| `shadow-{color}` | 色付きドロップシャドウ |
| `text-wrap-balance` | `text-wrap: balance` |

### カスタムユーティリティの定義（v4）

```css
/* v4: @utility ディレクティブ */
@utility scrollbar-hidden {
  &::-webkit-scrollbar { display: none; }
}

/* 動的ユーティリティ */
@theme { --tab-size-2: 2; --tab-size-4: 4; }
@utility tab-* {
  tab-size: --value(--tab-size-*);
}
```

```css
/* v3 (レガシー): @layer utilities */
@layer utilities {
  .scrollbar-hidden::-webkit-scrollbar { display: none; }
}
```

---

**関連リファレンス**:
- [SETUP-AND-CONFIG.md](./SETUP-AND-CONFIG.md) — v4/v3 セットアップ・テーマ設定
- [COMPONENT-PATTERNS.md](./COMPONENT-PATTERNS.md) — コンポーネント設計パターン
- [CUSTOMIZATION.md](./CUSTOMIZATION.md) — プラグイン作成・高度な設定
