# SLIDEKIT: デザインガイドライン・制約・チェックリスト

HTMLスライド作成（creating-presentations）のデザインガイドライン、HTMLボイラープレート、制約、品質チェックリスト。

---

## HTMLボイラープレート

```html
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="utf-8" />
    <meta content="width=device-width, initial-scale=1.0" name="viewport" />
    <title>{Slide Title}</title>
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet" />
    <link href="https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6.4.0/css/all.min.css" rel="stylesheet" />
    <link href="https://fonts.googleapis.com/css2?family={PrimaryFont}:wght@300;400;500;700;900&family={AccentFont}:wght@400;600;700&display=swap" rel="stylesheet" />
    <style>
        body { margin: 0; padding: 0; font-family: '{PrimaryFont}', sans-serif; overflow: hidden; }
        .font-accent { font-family: '{AccentFont}', sans-serif; }
        .slide { width: 1280px; height: 720px; position: relative; overflow: hidden; background: #FFFFFF; }
        /* Custom color classes: .bg-brand-dark, .bg-brand-accent, .bg-brand-warm, etc. */
    </style>
</head>
<body>
    <div class="slide {layout-classes}">
        <!-- Content -->
    </div>
</body>
</html>
```

---

## カラーパレット設計

カラーは `<style>` 内に Tailwind スタイルのユーティリティクラスとして定義する。

| ロール | クラス例 | 用途 |
|--------|---------|------|
| Primary Dark | `.bg-brand-dark` | 暗背景・タイトル |
| Primary Accent | `.bg-brand-accent` | ボーダー・ハイライト・アイコン |
| Warm/Secondary | `.bg-brand-warm` | CTA・強調・バッジ |
| Body text | Tailwind grays | 本文・キャプション |

### 実績パレット例

| テンプレ | スタイル | Primary Dark | Accent | Secondary | フォント |
|---------|---------|-------------|--------|-----------|---------|
| 01 Navy & Gold | Elegant | `#0F2027` | `#C5A065` | `#2C5364` | Noto Sans JP + Lato |
| 02 Casual Biz | Professional | `#1f2937` | Indigo | `#F97316` | Noto Sans JP |
| 03 Blue & Orange | Professional | `#333333` | `#007BFF` | `#F59E0B` | BIZ UDGothic |
| 04 Green Forest | Modern | `#1B4332` | `#40916C` | `#52B788` | Noto Sans JP + Inter |
| 05 Dark Tech | Creative | `#0F172A` | `#F97316` | `#3B82F6` | Noto Sans JP + Inter |

---

## フォント設計

| ロール | 例 | 使い方 |
|--------|-----|--------|
| Primary (JP) | Noto Sans JP, BIZ UDGothic | ボディ・見出し |
| Accent (Latin) | Lato, Inter, Roboto | 数字・英語ラベル・ページ番号 |

Primary は `body` に設定。Accent は `.font-accent` クラスで適用。

### フォントサイズ階層

| 用途 | Tailwind クラス |
|------|----------------|
| メインタイトル | `text-3xl`〜`text-6xl` + `font-bold`/`font-black` |
| セクション見出し | `text-xl`〜`text-2xl` + `font-bold` |
| カード見出し | `text-lg` + `font-bold` |
| 本文 | `text-sm`〜`text-base` |
| キャプション | `text-xs` |

---

## 見出し記法

バイリンガル形式（小さい英語ラベル + 大きな日本語タイトル）:

```html
<p class="text-xs uppercase tracking-widest text-gray-400 mb-1 font-accent">Market Analysis</p>
<h1 class="text-3xl font-bold text-brand-dark">市場分析</h1>
```

## 数字強調記法

```html
<p class="text-4xl font-black font-accent">415<span class="text-sm font-normal ml-1">M</span></p>
```

---

## コンテンツ密度ガイドライン

| 要素 | 推奨最大数 |
|------|-----------|
| 箇条書き | 5〜6個 |
| 1行あたりカード数 | 3〜4個 |
| 本文行数 | 6〜8行 |
| KPIボックス | 4〜6個 |
| プロセスステップ | 4〜5個 |

---

## PPTX変換ルール（Critical）

PPTX変換の精度に直接影響する。**必ず遵守すること。**

- `<div>` ではなく `<p>` でテキストを記述（tree-walker が `<div>` テキストを見落とすことがある）
- `::before` / `::after` に表示テキストを入れない
- 装飾要素は `-z-10` / `z-0` で分離
- DOMネスト最大: 5〜6レベル
- Font Awesome アイコンは `<i>` タグに `fa-` クラスで記述
- flex ベースのテーブルを使用（`<table>` 不可）
- `linear-gradient(...)` は対応済み。複雑な多点グラデーションはスクリーンショットにフォールバック

---

## アンチパターン（避けること）

- 意味のないラッパー `<div>`（ネストを増やすだけ）
- パレット外の単発カラー
- レイアウトに `<table>` を使用
- Tailwind で置き換え可能な inline style
- `::before` / `::after` 内のテキスト
- テキストに `<div>`（`<p>`, `<h1>`〜`<h6>` を使用）

---

## 品質チェックリスト（Phase 7）

| チェック項目 | 確認 |
|------------|------|
| 全ファイルで同一の CDN リンクを使用 | |
| カスタムカラーが全 `<style>` で同一定義 | |
| `<body>` 直下が `overflow: hidden` の単一 `<div>` | |
| スライドサイズ正確に 1280×720 | |
| 外部画像なし（ユーザー承認済みを除く） | |
| JavaScript ゼロ（`<script>` タグなし） | |
| 選択枚数分のファイルが揃っている | |
| フォントサイズ階層に従っている | |
| コンテンツスライドでヘッダー/フッターが統一 | |
| ページ番号が正しくインクリメント | |
| フッターに `Confidential` | |
| 装飾要素が低 z-index・低不透明度 | |
| ファイル名: 3桁ゼロパディング（`001.html` 等） | |
| テキストに `<p>` / `<h*>` を使用（`<div>` 不使用） | |
| `::before` / `::after` に表示テキストなし | |
| パレット外の単発カラーなし | |
| コンテンツ密度ガイドラインに従っている | |
| `print.html` が全スライドの iframe を含む | |

---

## PPTX 変換（Phase 8）

全チェックが通過後、ユーザーに確認する:

> 「HTMLスライドの生成が完了しました。PowerPoint（PPTX）に変換しますか？」

断られた場合はワークフロー終了。

**`/pptx` スキルが利用できない場合**、以下を案内する:

```
/pptx スキルが必要ですが現在インストールされていません。
以下のコマンドでインストールできます:
  claude install-skill https://github.com/anthropics/claude-code-agent-skills/tree/main/skills/pptx
インストール後、新しいセッションで /pptx を実行し出力ディレクトリを指定してください。
```

**`/pptx` スキルが利用可能な場合**、Skill ツールで `/pptx` を呼び出す:

```
Convert the HTML slide deck in {output_dir} to a single PPTX file.
- {N} slides (001.html through {NNN}.html)
- Title: {title}
- Colors: {primary_dark}, {accent}, {secondary}
- Fonts: {primary_font} + {accent_font}
- Output: {output_dir}/presentation.pptx
```

**重要**: 自力で HTML→PPTX 変換を試みない。必ず `/pptx` スキルに委譲する。
