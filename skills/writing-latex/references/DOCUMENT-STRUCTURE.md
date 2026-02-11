# LaTeX 文書構造ガイド

LaTeX文書の構造化、セクショニング、目次生成、相互参照、ドキュメント管理の高度な技法を扱う。

---

## 目次

1. [DocumentMetadata - PDF/A・タグ付きPDF対応](#documentmetadata)
2. [ドキュメントクラスとオプション](#documentclass)
3. [文書の構成要素](#document-parts)
4. [ファイル分割](#file-splitting)
5. [tagging - 文書バリアント管理](#tagging)
6. [セクショニング](#sectioning)
7. [章・セクションのモットー](#mottos)
8. [目次構造のカスタマイズ](#toc)
9. [相互参照](#cross-references)
10. [ドキュメントソース管理](#source-management)

---

## DocumentMetadata

`\DocumentMetadata` コマンドはPDF/A準拠やタグ付きPDFを生成するための新しい機構。`\documentclass` **より前**に記述する。

### 基本使用法

```latex
\DocumentMetadata{
  pdfversion=2.0,
  pdfstandard=a-4,
  lang=ja,
  pdfapart=4,
  pdfaconformance=F
}
\documentclass{article}
```

### 主要オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `pdfversion` | PDF仕様バージョン | `1.7`, `2.0` |
| `pdfstandard` | PDF標準（PDF/A等） | `a-4`, `x-4` |
| `lang` | 文書の主言語 | `en`, `ja`, `de` |
| `pdfapart` | PDF/Aパート番号 | `1`, `2`, `3`, `4` |
| `pdfaconformance` | 適合レベル | `A`, `B`, `U`, `F` |

### 使用タイミング

- 長期保存が求められる学術論文・公文書
- アクセシビリティが必要な文書（スクリーンリーダー対応）
- 出版社がPDF/A提出を要求する場合

---

## ドキュメントクラスとオプション

### 標準クラス

```latex
\documentclass[11pt, a4paper, twoside]{article}
\documentclass[12pt, oneside, openany]{report}
\documentclass[10pt, twocolumn, draft]{book}
```

### 主要オプション

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `10pt`, `11pt`, `12pt` | 基本フォントサイズ | `10pt` |
| `a4paper`, `letterpaper` | 用紙サイズ | `letterpaper` |
| `oneside`, `twoside` | 片面・両面印刷 | クラス依存 |
| `onecolumn`, `twocolumn` | 段組 | `onecolumn` |
| `draft`, `final` | ドラフト・完成版 | `final` |
| `openright`, `openany` | 章の開始ページ（奇数・任意） | クラス依存 |

### KOMA-Script クラス

より柔軟なオプション処理を提供：

```latex
\documentclass[
  fontsize=11pt,
  paper=a4,
  twoside=true,
  headings=small
]{scrartcl}
```

---

## 文書の構成要素

### Front Matter / Main Matter / Back Matter

```latex
\documentclass{book}
\begin{document}

% Front Matter（前付け）
\frontmatter
\tableofcontents
\listoffigures
\listoftables

% Main Matter（本文）
\mainmatter
\chapter{Introduction}
...

% Back Matter（後付け）
\backmatter
\appendix
\chapter{Additional Data}
\bibliography{refs}

\end{document}
```

| 部分 | ページ番号 | 章番号 | 用途 |
|------|----------|-------|------|
| `\frontmatter` | ローマ数字（i, ii, ...） | なし | 目次・序文 |
| `\mainmatter` | アラビア数字（1, 2, ...） | あり | 本文 |
| `\backmatter` | アラビア数字（続き） | なし | 付録・索引 |

---

## ファイル分割

### `\input` vs `\include`

| コマンド | 改ページ | 選択的コンパイル | 使用場面 |
|---------|---------|----------------|---------|
| `\input{file}` | なし | 不可 | プリアンブル・小セクション |
| `\include{file}` | あり | 可（`\includeonly`） | 章単位 |

### 基本使用法

```latex
% main.tex
\documentclass{book}
\includeonly{chapter1,chapter3} % 選択的コンパイル
\begin{document}
\include{chapter1}
\include{chapter2}
\include{chapter3}
\end{document}

% chapter1.tex
\chapter{Introduction}
本文...
```

### askinclude - 対話的ファイル選択

コンパイル時にどのファイルを含めるか対話的に選択：

```latex
\usepackage{askinclude}
% コンパイル時にプロンプトが表示される
\AskInclude
\include{chapter1}
\include{chapter2}
```

---

## tagging - 文書バリアント管理

同一ソースから複数のバリアント（学生版・教員版、印刷版・Web版等）を生成する。

### 基本使用法

```latex
\usepackage{tagging}

% タグを定義
\usetag{student}
% \usetag{teacher}

\begin{document}
共通テキスト

\tagged{student}{学生向けのみの内容}
\tagged{teacher}{教員向けのみの内容}
\end{document}
```

### 複数タグの組み合わせ

```latex
\usetag{print}
\usetag{color}

\tagged{print,color}{カラー印刷版専用}
\tagged{print}{\tagged{!color}{モノクロ印刷版専用}}
```

---

## セクショニング

### 標準セクショニングコマンド

```latex
\part{部}               % レベル -1（book）
\chapter{章}            % レベル 0（book, report）
\section{節}            % レベル 1
\subsection{項}         % レベル 2
\subsubsection{目}      % レベル 3
\paragraph{段落見出し}   % レベル 4
\subparagraph{小段落}   % レベル 5
```

### titlesec - 柔軟な見出しデザイン

#### パッケージオプション

```latex
% グローバル設定
\usepackage[sf, bf, tiny, center]{titlesec}
% sf: サンセリフ, bf: ボールド, tiny: 小サイズ, center: 中央揃え
```

| オプション | 効果 |
|-----------|------|
| `rm`, `sf`, `tt` | フォントファミリ（ローマン・サンセリフ・タイプライタ） |
| `md`, `bf` | フォントウェイト（標準・ボールド） |
| `up`, `it`, `sl`, `sc` | フォントシェイプ（直立・斜体・スラント・スモールキャップ） |
| `tiny`, `small`, `medium`, `big`, `huge` | サイズ |
| `raggedleft`, `center`, `raggedright` | 配置 |
| `compact` | 前後空白を削減 |

#### カスタム見出しフォーマット

```latex
\usepackage{titlesec}

% セクションのフォーマット変更
\titleformat{\section}
  [hang]                        % 形状（hang, block, display等）
  {\Large\bfseries\sffamily}    % フォーマット
  {\thesection.}                % ラベル
  {1em}                         % ラベルと本文の間隔
  {}                            % 前処理コード
  [\titlerule]                  % 後処理コード（下線）

% スペーシング調整
\titlespacing{\section}
  {0pt}        % 左マージン
  {3.5ex plus 1ex minus .2ex}  % 前空白
  {2.3ex plus .2ex}             % 後空白
```

#### 見出しデザインのバリエーション

```latex
% 番号を囲む
\titleformat{\section}
  {\Large\bfseries}
  {\fbox{\thesection}}
  {1em}
  {}

% 番号を右側に配置
\titleformat{\section}
  [leftmargin]
  {\normalfont\sffamily\bfseries}
  {\thesection}
  {0.5em}
  {}
```

---

## 章・セクションのモットー

### quotchap - 章見出しと一体化したモットー

章見出しの一部として引用を組み込む。

```latex
\usepackage[avantgarde]{quotchap}
% オプション: avantgarde, times, palatino

\begin{document}
\chapter[Short Title]{Long Chapter Title}
\end{document}
```

### epigraph - 見出し後のモットー

章・セクション見出しの後に引用を配置。

```latex
\usepackage{epigraph}

% グローバル設定
\setlength{\epigraphwidth}{0.4\textwidth}
\setlength{\epigraphrule}{0pt}
\renewcommand{\epigraphsize}{\small}
\renewcommand{\epigraphflush}{flushright}

\chapter{Title}
\epigraph{The only way to do great work is to love what you do.}%
         {--- Steve Jobs}

本文開始...
```

#### 複数のエピグラフ

```latex
\chapter{Philosophy}
\begin{epigraphs}
\qitem{I think, therefore I am.}{Descartes}
\qitem{The unexamined life is not worth living.}{Socrates}
\end{epigraphs}
```

#### 章扉ページへの配置

```latex
\epigraphhead[70]{
  \epigraph{Quote text}{--- Author}
}
\chapter{Chapter Title}
```

---

## 目次構造のカスタマイズ

### tocdata - 目次への追加情報

目次に著者名や要約を追加：

```latex
\usepackage{tocdata}

\chapter[著者: John Doe]{Chapter Title}
\chapterauthor{John Doe}

\section[期間: 2024]{Section Title}
\sectiondata{Duration: 1 week}
```

### titletoc - 目次デザインの制御

```latex
\usepackage{titletoc}

% 章の目次エントリをカスタマイズ
\titlecontents{chapter}
  [0pt]                    % 左マージン
  {\addvspace{1em}\bfseries}  % 全体のフォーマット
  {\contentslabel{2em}}    % 番号ありエントリ
  {}                       % 番号なしエントリ
  {\hfill\contentspage}    % フィラーとページ番号

% セクションエントリ
\titlecontents{section}
  [2em]
  {}
  {\contentslabel{2em}}
  {}
  {\titlerule*[1pc]{.}\contentspage}
```

### multitoc - 複数列目次

```latex
\usepackage[toc]{multitoc}
% 目次を2列で表示
```

---

## 相互参照

### varioref - 文脈に応じた柔軟な参照

ページが同じか異なるかに応じて表現を変更：

```latex
\usepackage{varioref}

\section{Method}\label{sec:method}
...
\section{Results}
詳細は\vref{sec:method}を参照。
% → "詳細は 2節 (3ページ)を参照。"（異ページの場合）
% → "詳細は 2節を参照。"（同ページの場合）

% ページのみ参照
\vpageref{sec:method}
% → "3ページ"
```

### cleveref - 自動的な参照種別判定

```latex
\usepackage[capitalise, noabbrev]{cleveref}

\section{Introduction}\label{sec:intro}
\begin{figure}...\caption{...}\label{fig:plot}\end{figure}
\begin{table}...\caption{...}\label{tab:data}\end{table}

...

\Cref{sec:intro} で述べたように...     % → Section 1 で述べたように
\cref{fig:plot,tab:data} を参照。       % → figure 1 and table 1 を参照。
```

#### オプション

| オプション | 効果 |
|-----------|------|
| `capitalise` | 文頭では大文字化（Figure, Table） |
| `noabbrev` | 省略形を使わない（Fig. → Figure） |
| `nameinlink` | リンク範囲に種別名も含める |

#### カスタムラベル

```latex
% 日本語化
\crefname{section}{節}{節}
\crefname{figure}{図}{図}
\crefname{table}{表}{表}

\Cref{sec:intro}  % → 節1
```

### nameref - ラベルのテキストを参照

```latex
\usepackage{nameref}

\section{Important Section}\label{sec:important}
...
\nameref{sec:important} で述べたように...
% → "Important Section で述べたように..."
```

### hyperref - ハイパーリンク

```latex
\usepackage[
  colorlinks=true,
  linkcolor=blue,
  citecolor=green,
  urlcolor=cyan,
  pdfauthor={Your Name},
  pdftitle={Document Title}
]{hyperref}

% PDF内部リンク
\href{https://example.com}{リンクテキスト}
\url{https://example.com}

% 相互参照が自動的にリンクになる
\ref{sec:intro}
```

---

## ドキュメントソース管理

### snapshot - 使用パッケージのバージョン記録

```latex
\usepackage{snapshot}
% コンパイル時に .dep ファイルを生成
% 使用したパッケージとバージョンを記録
```

生成される `.dep` ファイル例：

```
\RequirePackage{snapshot}
\RequireVersions{
  *{application}{pdfTeX} {0000/00/00 v1.40.21}
  *{format} {LaTeX2e}     {2023-06-01 v2.e}
  *{package}{article}     {2021/10/04 v1.4n}
  *{package}{graphicx}    {2021/09/16 v1.2d}
  ...
}
```

### bundledoc - 文書の完全なアーカイブ作成

依存するすべてのファイル（ソース・画像・パッケージ）を収集：

```bash
# Perl スクリプトとして実行
bundledoc --config=unix mydocument.dep
```

生成されるアーカイブには以下が含まれる：

- `.tex` ソースファイル
- `.bib` 参考文献ファイル
- `.eps`, `.pdf` 画像ファイル
- `.sty` パッケージファイル（オプション）

### rollback - パッケージのバージョン固定

特定の日付のパッケージを使用：

```latex
% 2020年1月1日時点のパッケージを使用
\usepackage{graphicx}[=2020-01-01]

% ドキュメント全体でrollback
\documentclass{article}[=v1.4n]
```

---

## 判断基準テーブル

### セクショニングパッケージの選択

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| 見出しデザインの微調整 | `titlesec` | 最も柔軟な設定 |
| 章にモットーを統合 | `quotchap` | デザイン一体化 |
| 見出し後にモットー配置 | `epigraph` | 柔軟な配置制御 |
| KOMA-Script使用時 | 組込機能 | 外部パッケージ不要 |

### 相互参照パッケージの選択

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| ページ番号の自動調整 | `varioref` | 文脈に応じた表現 |
| 参照種別の自動判定 | `cleveref` | 手動指定不要 |
| ラベルのテキスト参照 | `nameref` | 番号ではなくテキスト |
| PDFリンク生成 | `hyperref` | 標準的なハイパーリンク |
| すべて組み合わせ | `varioref`, `cleveref`, `hyperref` | 読み込み順: varioref → hyperref → cleveref |

### 目次カスタマイズの選択

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| 追加情報（著者等） | `tocdata` | 拡張目次エントリ |
| 目次デザイン変更 | `titletoc` | `titlesec`と統合 |
| 複数列目次 | `multitoc` | シンプルな解決策 |

---

## まとめ

LaTeX文書構造の高度な制御には以下のアプローチが有効：

1. **DocumentMetadata**: PDF/A・アクセシビリティ対応
2. **titlesec/titletoc**: 見出し・目次の統一的カスタマイズ
3. **varioref/cleveref**: スマートな相互参照
4. **snapshot/bundledoc**: 再現可能性の確保

プロジェクトの規模と要件に応じて適切なパッケージを選択し、組み合わせることが重要。
