# 大規模文書の管理

論文・書籍・包括的レポートなど、複数ファイルにわたる大規模LaTeX文書の構成・管理ガイド。

---

## ファイル分割の概要

大規模文書では、内容を複数の `.tex` ファイルに分割することで保守性が向上する。LaTeXには主に3つの読み込みコマンドがある。

### `\input` vs `\include` vs `\includeonly` 比較

| コマンド | 改ページ | 選択的コンパイル | ネスト可 | 使用場面 |
|---------|---------|----------------|---------|---------|
| `\input{file}` | なし | 不可 | 可 | プリアンブル・マクロ・小セクション |
| `\include{file}` | あり（前後に `\clearpage`） | 可（`\includeonly`と連携） | 不可 | 章単位の大きなブロック |
| `\includeonly{file,...}` | — | — | — | プリアンブルで対象章を指定 |

### 基本的な分割例

```latex
% main.tex（トップレベル文書）
\documentclass{book}
\input{preamble}      % プリアンブルを別ファイルに
\includeonly{chapter1,chapter3}  % 指定章のみコンパイル
\begin{document}
\tableofcontents
\include{chapter1}   % 章ファイル（改ページあり）
\include{chapter2}
\include{chapter3}
\end{document}
```

```latex
% preamble.tex（パッケージ・設定の集約）
\usepackage[english]{babel}
\usepackage[T1]{fontenc}
\usepackage{lmodern}
\usepackage{amsmath}
\usepackage{amsthm}
\newtheorem{thm}{Theorem}[chapter]
```

```latex
% chapter1.tex（章ファイル）
\chapter{Introduction}
\section{Background}
本文...
```

### `\includeonly` の活用

```latex
% 作業中の章のみコンパイルして高速化
% ページ番号・章番号・相互参照は正確に保たれる
\includeonly{chapters/chapter02-methods}
```

**重要**: `\include` された各ファイルに対して `.aux` ファイルが生成・参照されるため、`\includeonly` で除外した章の番号・参照も正確に維持される。作業完了後は `\includeonly` をコメントアウトして全体をコンパイルする。

---

## Front Matter / Back Matter の設計

### `\frontmatter` / `\mainmatter` / `\backmatter`

`book`・`scrbook`・`memoir` クラスはページ番号と章番号を自動制御する3つのコマンドを提供する。

| コマンド | ページ番号 | 章番号 | 用途 |
|---------|----------|-------|------|
| `\frontmatter` | ローマ数字（i, ii, ...） | なし（目次には掲載） | 献辞・序文・目次 |
| `\mainmatter` | アラビア数字（1, 2, ...） | あり | 本文章 |
| `\backmatter` | アラビア数字（続き） | なし（目次には掲載） | 付録・索引・参考文献 |

### 大規模文書の骨格

```latex
\documentclass{book}
\input{preamble}
\begin{document}

% Front Matter（前付け）
\frontmatter
\include{frontmatter/titlepage}
\include{frontmatter/dedication}
\tableofcontents
\listoftables
\listoffigures
\include{frontmatter/preface}

% Main Matter（本文）
\mainmatter
\include{chapters/chapter01-intro}
\include{chapters/chapter02-methods}
\include{chapters/chapter03-results}

% Back Matter（後付け）
\backmatter
\appendix
\include{appendices/appendixA}
\nocite{*}
\bibliographystyle{plainnat}
\bibliography{references}

\end{document}
```

---

## タイトルページのカスタマイズ

### `titlepage` 環境

`\maketitle` で自動生成する代わりに、`titlepage` 環境を使うと完全制御が可能。タイトルページのページ番号は付与されるが印刷されない。

```latex
% frontmatter/titlepage.tex
\begin{titlepage}
  \raggedleft
  {\Large 著者名\\[1in]}
  {\large 〇〇大学 情報工学科\\[0.5in]}
  {\Huge\scshape 論文タイトル\\[0.2in]}
  {\large 博士学位論文\\}
  \vfill
  {\large 2024年3月}
\end{titlepage}
```

### よく使うフォント・レイアウトコマンド

| コマンド | 効果 |
|---------|------|
| `\raggedleft` | 右揃え |
| `\centering` | 中央揃え |
| `\vfill` | 残りの垂直スペースをすべて埋める |
| `\\[寸法]` | 改行 + 追加垂直スペース（例: `\\[1in]`） |
| `\Huge`, `\Large`, `\large` | フォントサイズ指定 |
| `\scshape` | スモールキャップス |

### `titling` パッケージの活用

より高度なタイトルページには `titling` パッケージが便利。テンプレート集は `texdoc titlepages` または CTAN の titlepages パッケージで参照できる。

---

## プロジェクトディレクトリ構成

### 推奨フォルダ構成

```
project/
├── main.tex                  # トップレベル文書
├── preamble.tex              # パッケージ・設定
├── macros.tex                # カスタムコマンド
├── university-style.sty      # 機関スタイルファイル
├── frontmatter/
│   ├── titlepage.tex
│   ├── abstract.tex
│   ├── preface.tex
│   └── acknowledgements.tex
├── chapters/
│   ├── chapter01-intro.tex
│   ├── chapter02-methods.tex
│   └── chapter03-results.tex
├── figures/
│   ├── chapter01/
│   │   ├── diagram.png
│   │   └── plot.pdf
│   └── chapter02/
├── tables/
├── appendices/
│   ├── appendixA.tex
│   └── appendixB.tex
└── backmatter/
    ├── bibliography.bib
    └── declaration.tex
```

### `main.tex` のフォルダ対応例

```latex
\documentclass[12pt,a4paper]{report}
\usepackage{university-style}
\input{preamble}
\input{macros}
\usepackage{graphicx}

% 図の検索パスを一括設定
\graphicspath{
  {figures/}
  {figures/chapter01/}
  {figures/chapter02/}
}

\begin{document}
\input{frontmatter/titlepage}
\input{frontmatter/abstract}
\tableofcontents

\include{chapters/chapter01-intro}
\include{chapters/chapter02-methods}
\include{chapters/chapter03-results}

\appendix
\include{appendices/appendixA}

\input{backmatter/bibliography}
\end{document}
```

**注意**: パス区切りにはバックスラッシュ（`\`）ではなくスラッシュ（`/`）を使用する。ファイル名にスペースや特殊文字は避ける。

---

## テンプレートの活用

### テンプレートの構成要素

独自テンプレートには以下を含める:

- 文書クラスと適切なオプション
- よく使うパッケージとその設定
- ヘッダー・フッター・本文のレイアウト定義
- カスタムマクロ（作業効率化）
- `\include` / `\input` のフレームワーク

### テスト用ダミーテキスト

テンプレート確認には `blindtext` パッケージが便利。

```latex
\documentclass{article}
\usepackage[english]{babel}
\usepackage{blindtext}
\begin{document}
\begin{abstract}
  \blindtext
\end{abstract}
\Blinddocument  % セクション・リスト付きの大きなダミー文書を生成
\end{document}
```

### テンプレート品質の確認

オンラインで見つけたテンプレートやコードには古い手法が含まれる場合がある。`texdoc l2tabuen` で廃止コマンド・パッケージを確認し、最新のベストプラクティスに従っているかチェックする。

---

## 判断基準

### ファイル分割方法の選択

| 状況 | 推奨 | 理由 |
|-----|------|------|
| プリアンブルの分離 | `\input` | 改ページ不要 |
| 章ごとの分割 | `\include` | ページ範囲に適切、`\includeonly` と連携可 |
| 大規模プロジェクトの一部のみコンパイル | `\includeonly` | 参照・番号を維持しつつ高速化 |
| インクルードファイル内でさらに分割 | `\input` | `\include` のネストは不可 |

### ドキュメントクラスの選択

| 文書の種類 | 推奨クラス | 備考 |
|---------|---------|------|
| 学術論文（投稿） | `article` / `scrartcl` | 章なし |
| 修士・博士論文 | `report` / `scrreprt` | 章あり |
| 書籍 | `book` / `scrbook` | front/main/backmatter対応 |
| KOMA-Script | `scrbook`, `scrreprt` | より柔軟なオプション処理 |
