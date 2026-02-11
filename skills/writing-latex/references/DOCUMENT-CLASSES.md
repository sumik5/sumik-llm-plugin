# 文書クラス別テンプレート

## 概要

LaTeXは様々な文書タイプに対応した標準文書クラスを提供しています。各クラスは特定の文書形式（手紙、論文、レポート、書籍）に最適化されています。この文書では、`letter`、`article`、`amsart`、`report`、`book` の各クラスの使い方とテンプレートを解説します。

## 文書クラスの比較

| クラス | 用途 | 主な特徴 | 章サポート |
|--------|------|---------|-----------|
| `letter` | 手紙・書簡 | 送受信者情報、定型句 | なし |
| `article` | 論文・記事 | セクション構造、要約 | なし |
| `amsart` | 数学論文 | article の AMS 拡張版、大文字見出し | なし |
| `report` | レポート | 章サポート、章ごとに番号付け | あり |
| `book` | 書籍 | 前付け・本文・後付け、両面印刷 | あり |

**基本的な宣言**:
```latex
\documentclass[options]{class}
```

一般的なオプション:
- `a4paper`, `letterpaper`: 用紙サイズ
- `10pt`, `11pt`, `12pt`: フォントサイズ
- `twoside`, `oneside`: 片面/両面印刷
- `twocolumn`: 2段組
- `titlepage`: タイトルを別ページに

## letter クラス

### 標準コマンド

`letter` クラスは手紙作成用の専用コマンドを提供します:

| コマンド | 機能 | 配置 |
|---------|------|------|
| `\address{Sender}` | 送信者の住所 | 右上 |
| `\signature{Signature}` | 送信者の署名（名前） | 中央下部 |
| `\begin{letter}{Recipient}` | 受信者の住所 | 左側 |
| `\opening{Salute}` | 冒頭の挨拶 | 本文開始前 |
| `\closing{Anticipate}` | 結びの挨拶 | 本文終了後 |
| `\cc{Copy}` | 写しを送る相手のリスト | 署名後 |
| `\encl{Enclosure}` | 同封物のリスト | cc: の後 |

### 標準テンプレート

```latex
\documentclass[a4paper,12pt]{letter}

\begin{document}

\address{Sender's Address}
\signature{Sender's Name}

\begin{letter}{Recipient's Address}

\opening{Dear Sir,}

Contents of the letter …

\closing{Best regards,}

\cc{1. Secretary \\ 2. Coordinator}
\encl{1. Letter from CEO. \\ 2. Letter from MD.}

\end{letter}

\end{document}
```

**出力例**:
```
Sender's Address
June 10, 2017

Recipient's Address

Dear Sir,

Contents of the letter …

Best regards,

Sender's Name

cc: 1. Secretary
cc: 2. Coordinator
encl: 1. Letter from CEO.
encl: 2. Letter from MD.
```

### 日付のカスタマイズ

デフォルトでは現在の日付が自動的に印刷されます。これを変更するには:

```latex
% 特定の日付を指定
\date{29/02/2016}

% 日付を非表示
\date{}
```

### カスタムフォーマット

標準フォーマットを使わず、独自のレイアウトで作成することもできます:

```latex
\documentclass[a4paper,12pt]{letter}
\usepackage{setspace}
\pagestyle{empty}  % ページ番号を非表示

\begin{document}

From: \\ Sender's Address \\[2mm]
To: \\ Recipient's Address \\
\hspace*{\fill} Date: \today\\[2mm]
{\bf Subject: Regarding … }\\

\begin{spacing}{1.2}

Respected Sir, \\
This is to inform you that …

\par
Therefore, hereby I request you to …

\vskip 5mm
\hspace*{\fill} Thanking you, \\[7mm]
\hspace*{\fill} (Sender's Name) \\[2mm]

{\it Copy to\ /}: President \\[2mm]
{\bf Enclosure:} Detail of the findings.

\end{spacing}

\end{document}
```

**特徴**:
- `\pagestyle{empty}`: ページ番号を抑制
- `\today`: コンパイル日を自動挿入
- `\hspace*{\fill}`: 右寄せ
- `spacing` 環境: 行間調整（`setspace` パッケージ）

## article クラス

### 基本構造

`article` クラスは論文や記事作成に使用され、章（chapter）はサポートしません。

**基本テンプレート**:

```latex
\documentclass[a4paper,12pt]{article}
\date{}  % 日付を非表示（デフォルトで表示される）

\title{My First Article in \LaTeX}
\author{Author's Name and Address}

\begin{document}

\maketitle

\begin{abstract}
The article explains …
\end{abstract}

\section{First Section}
First level of numbered section.

\subsection{First subsection}
Second level of numbered section.

\subsubsection{First sub-subsection}
Third and last level of numbered section.

\section{Second Section}
Texts of the second section …

\end{document}
```

**出力の特徴**:
- タイトルと著者名は中央揃え
- セクション見出しは左揃え
- 各セクションは新しい行から開始
- デフォルトでコンパイル日が表示（`\date{}` で非表示可）

### amsart クラス

`amsart` は American Mathematical Society による `article` の拡張版です。

**基本テンプレート**:

```latex
\documentclass[a4paper,12pt]{amsart}

\title{My First Article in \LaTeX}
\author{Author's Name and Address}

\begin{document}

\maketitle

\begin{abstract}
The article explains …
\end{abstract}

\section{First Section}
First level of numbered section.

\subsection{First subsection}
Second level of numbered section.

\subsubsection{First sub-subsection}
Third and last level of numbered section.

\section{Second Section}
Texts of the second section …

\end{document}
```

### article vs amsart の違い

| 項目 | article | amsart |
|------|---------|--------|
| タイトル | 左揃え | 中央揃え、**大文字** |
| 著者名 | 左揃え | 中央揃え、**大文字** |
| セクション見出し | 左揃え、新しい行 | 中央揃え、新しい行 |
| サブセクション | 新しい行 | **同じ行に続く** |
| Abstract見出し | Abstract | Abstract. （ピリオド付き） |
| Abstract内容 | 新しい行 | **同じ行に続く** |
| 日付 | デフォルトで表示 | 表示されない |

**出力例（amsart）**:
```
MY FIRST ARTICLE IN LATEX

AUTHOR'S NAME AND ADDRESS

Abstract. The article explains …

1. First Section

First level of numbered section.

1.1. First subsection. Second level of numbered section.

1.1.1. First sub-subsection. Third and last level of numbered section.

2. Second Section
```

### Abstract見出しの変更

両クラスで Abstract の見出しを変更できます:

```latex
\renewcommand{\abstractname}{Summary}
```

## 著者フォーマット

### 縦並び（デフォルト）

```latex
\author
{
  {\bf 1st author's name}\\
  Affiliation\\
  Address\\[2mm]
  %
  {\bf 2nd author's name}\\
  Affiliation\\
  Address
}
```

**出力**:
```
1st author's name
Affiliation
Address

2nd author's name
Affiliation
Address
```

### 横並び（tabular 環境）

```latex
\author
{
  \begin{tabular}[t]{c@{\extracolsep{30mm}}c@{\extracolsep{30mm}}c}
    {\it Author-1} & {\it Author-2} & {\it Author-3}\\
    Affiliation & Affiliation & Affiliation\\
    Address & Address & Address\\
    e-mail & e-mail & e-mail\\
  \end{tabular}
}
```

**出力**:
```
Author-1             Author-2             Author-3
Affiliation          Affiliation          Affiliation
Address              Address              Address
e-mail               e-mail               e-mail
```

- `@{\extracolsep{30mm}}`: 列間に30mm の余白
- `[t]`: 上揃え

### 脚注形式（\thanks コマンド）

著者の詳細情報をページ下部に表示:

```latex
\documentclass[a4paper,12pt]{article}
\date{}

\title{My First Article in \LaTeX}
\author
{
  Mr.\,X\thanks{X's Address} \and
  Mr.\,Y\thanks{Y's Address}
}

\begin{document}

\maketitle

\begin{abstract}
The article explains …
\end{abstract}

\section{Introduction}
Introduction to the problem …

\end{document}
```

**出力**:
```
My First Article in LaTeX

Mr. X* Mr. Y†

Abstract
The article explains …

1 Introduction
Introduction to the problem …

─────────────
* X's Address
† Y's Address
```

- `\thanks{}`: 著者情報を脚注として配置
- `\and`: 著者名の間に大きな空白
- `\footnote{}` でも同様の効果

### タイトルと著者の左揃え

デフォルトの中央揃えを左揃えに変更:

```latex
\makeatletter
\def\maketitle
{
  {\bf\Large\raggedright \@title} \vskip 5mm
  {\large\raggedright \@author} \vskip 10mm
}
\makeatother
```

プリアンブルに追加すると:
- `\raggedright`: 左揃え
- `\@title`, `\@author`: LaTeX 内部コマンド
- `\makeatletter`/`\makeatother`: `@` を含むコマンドを有効化

## multi-column 記事

### twocolumn オプション

`\documentclass` のオプションで2段組を指定:

```latex
\documentclass[a4paper,12pt,twocolumn]{article}
\date{}

\title{My First Article in \LaTeX}
\author{Author's Name and Address}

\begin{document}

\maketitle

\begin{abstract}
Abstract of the article … Abstract of the article …
\end{abstract}

\section{Introduction}
Introduction to the work … Introduction to the work …

\end{document}
```

**出力の特徴**（article クラス）:
- タイトルと著者名は1段組で表示
- Abstract と本文は2段組

**注意**: `amsart` クラスでは、タイトルと著者名も2段組になります。

### \twocolumn[] コマンド

タイトル・Abstract を1段、本文を2段にする方法:

```latex
\documentclass[a4paper,12pt]{article}
\date{}

\title{My First Article in \LaTeX}
\author{Author's Name and Address}

\begin{document}

\twocolumn
[
  \maketitle
  \begin{abstract}
  Abstract of the article … Abstract of the article …
  \end{abstract}
  \vspace{1.0cm}
]

\section{Introduction}
Introduction to the work … Introduction to the work …

\end{document}
```

**違い**:
- `twocolumn` オプション: 文書全体の設定
- `\twocolumn[]` コマンド: 柔軟な制御、`[]` 内は1段組

**注意**: `\twocolumn[]` または `\onecolumn[]` は新しいページを開始します。

## セクション別番号付け

### 問題

`article` クラスでは、テーブル・図・数式は連番になります（例: Table 1, Table 2, …）。

### 解決策

セクションごとに番号付けするには、プリアンブルに以下を追加:

```latex
\makeatletter
\@addtoreset{table}{section}
\@addtoreset{figure}{section}
\@addtoreset{equation}{section}
\makeatother

\renewcommand{\thetable}{\thesection.\arabic{table}}
\renewcommand{\thefigure}{\thesection.\arabic{figure}}
\renewcommand{\theequation}{\thesection.\arabic{equation}}
```

**動作**:
1. `\@addtoreset`: セクションが変わるたびにカウンターをリセット
2. `\renewcommand`: 番号形式を「セクション番号.項目番号」に変更

**出力例**:
```
Section 1:
  Table 1.1, Table 1.2
  Figure 1.1
  Equation 1.1

Section 2:
  Table 2.1
  Figure 2.1, Figure 2.2
```

**注意**: `\renewcommand` がないと、内部ではセクション別になっても、出力では「Table 1, Table 2, …」と表示され、セクションをまたいで重複します。

## Part による記事の分割

### 基本的な使い方

```latex
\documentclass{article}

\begin{document}

\part{}

\section{India}
\subsection{Population of India}
\subsubsection{Per Capita Income in India}

\part{}

\section{Delhi}
\subsection{Population of Delhi}

\end{document}
```

**出力**:
```
Part I

1 India
1.1 Population of India
1.1.1 Per Capita Income in India

Part II

2 Delhi
2.1 Population of Delhi
```

**デフォルトの動作**:
- Part は Roman 数字（I, II, III, …）
- Section は連番（1, 2, 3, …）で、Part をまたいでも継続

### Part 別のセクション番号付け

セクション番号を Part ごとにリセット:

```latex
\documentclass{article}

\makeatletter
\@addtoreset{section}{part}
\makeatother
\renewcommand{\thesection}{\thepart.\arabic{section}}

\begin{document}

\part{}\label{part:country}

\section{India}\label{sec:ind}
\subsection{Population of India}\label{sec:indpop}
\subsubsection{Per Capita Income in India}

\part{}\label{part:state}

\section{Delhi}\label{sec:del}
\subsection{Population of Delhi}\label{sec:delpop}

India is described in \S\ref{sec:ind} of Part~\ref{part:country} …
Population of Delhi can be found in \S\ref{sec:delpop}.

\end{document}
```

**出力**:
```
Part I

I.1 India
I.1.1 Population of India
I.1.1.1 Per Capita Income in India

Part II

II.1 Delhi
II.1.1 Population of Delhi

India is described in §I.1 of Part I …
Population of Delhi can be found in §II.1.1.
```

**注意**: `\renewcommand` がないと、Section は「1, 2, …」と表示され、Part 情報が失われます。

## book クラス

### 基本構造

`book` クラスは書籍作成用で、3つの部分から構成されます:

| 部分 | コマンド | 機能 | ページ番号 | 章番号 |
|------|---------|------|-----------|--------|
| **前付け** | `\frontmatter` | タイトル、序文、目次 | Roman (i, ii, iii, …) | なし |
| **本文** | `\mainmatter` | 本編の章 | Arabic (1, 2, 3, …) | あり |
| **後付け** | `\backmatter` | 付録、参考文献、索引 | 継続 | なし |

### 基本テンプレート

```latex
\documentclass[11pt,a4paper]{book}

\title{\LaTeX\ in 24 Hours \\ A Practical Guide for Scientific Writing}
\author{Dilip Datta}

\begin{document}

\frontmatter
\maketitle

\chapter{Preface}
The necessity for writing this book …

\tableofcontents

\mainmatter

\chapter{Introduction}
Donald E. Knuth developed \TeX\ in the year 1977 …

\chapter{Equation}
Mathematical equations …

\backmatter

\appendix
\chapter{Appendix}
List of symbols …

\bibliographystyle{plain}
\bibliography{mybib}

\printindex

\end{document}
```

### カスタマイズされたテンプレート

```latex
\documentclass[a4paper,11pt,twoside,openany]{book}

\begin{document}

% Cover page
\thispagestyle{empty}
\begin{center}
  {\Huge\bf \LaTeX\ in 24 Hours}\\[5mm]
  {\Large\bf A Practical Guide for Scientific Writing}
\end{center}
\cleardoublepage

% Preface
\pagenumbering{roman}
\chapter*{Preface}
The necessity for writing this book was felt long back …
\cleardoublepage

% Contents
\tableofcontents
\cleardoublepage

% Starting chapters
\pagenumbering{arabic}

\chapter{Introduction}
Donald E. Knuth developed \TeX\ in the year 1977 …

\chapter{Fonts Selection}
There are three modes for processing texts in \LaTeX\ …

% Appendix, Bibliography and Index
\appendix
\chapter{Appendix}
List of symbols …

\bibliographystyle{plain}
\bibliography{mybib}

\printindex

\end{document}
```

**重要なコマンド**:

| コマンド | 機能 |
|---------|------|
| `\thispagestyle{empty}` | 現在のページの番号を非表示 |
| `\cleardoublepage` | 次の奇数ページから開始（前のページが偶数なら空白） |
| `\pagenumbering{roman}` | Roman 数字でページ番号 |
| `\pagenumbering{arabic}` | Arabic 数字でページ番号 |
| `\chapter*{Preface}` | 番号なしの章 |
| `openany` オプション | 章を次の空白ページから開始（偶数でも可） |

**デフォルトの動作**:
- `twoside`: 両面印刷用レイアウト
- 章は奇数ページから開始（`openany` で変更可能）
- `\cleardoublepage`: 偶数ページを空白にして次の奇数ページへ

## ルートファイルによる書籍作成

### 構造

大規模な書籍は複数のファイルに分割して管理します:

```
mybook.tex          (ルートファイル)
preamble.tex        (プリアンブル)
coverpage.tex       (表紙)
title.tex           (タイトルページ)
preface.tex         (序文)
dedication.tex      (献辞)
chap_intro.tex      (第1章)
chap_font.tex       (第2章)
...
app_symb.tex        (付録)
mybib.bib           (参考文献データベース)
```

### プリアンブルファイル (preamble.tex)

```latex
% File name: preamble.tex
\documentclass[a4paper,11pt,twoside,openany]{book}

% Basic packages
\usepackage{float}
\usepackage{stmaryrd,amssymb,amsmath}
\usepackage{array}
\usepackage{epsfig,graphicx,subfigure}
\usepackage{wrapfig}
\usepackage{tabularx}
\usepackage{multirow}
\usepackage{longtable}
\usepackage{rotating}
\usepackage{caption}
\usepackage{color}
\usepackage{setspace}
\usepackage{boxedminipage,fancybox}
\usepackage{shadow}
\usepackage{natbib}
\usepackage{varioref}
\usepackage{url}
\usepackage{makeidx}

\makeindex

% Blank space adjustment
\abovecaptionskip
\belowcaptionskip
\raggedbottom

% User-defined new commands
\definecolor{ugray}{gray}{0.25}
\newcommand{\tgray}{\textcolor{ugray}}
\newcommand{\tred}{\textcolor{red}}
\newcommand{\vctr}[1]{\mbox{\boldmath{$#1$}}}

\newtheorem{thm}{Theorem}
\newtheorem{dfn}{Definition}
\newtheorem{lem}{Lemma}
```

### 個別ファイル例

**タイトルページ (title.tex)**:
```latex
\vspace*{\fill}
\begin{titlepage}
\begin{center}
  {\Huge\bf \LaTeX\ in 24 Hours}\\[5mm]
  {\Large\bf A Practical Guide for Scientific Writing}
\end{center}
...
\end{titlepage}
\vspace*{\fill}
```

**序文 (preface.tex)**:
```latex
\chapter*{Preface}
The necessity for writing this book was felt long back,
during my Ph.D work, when I saw students and researchers
struggling with \LaTeX\ for writing their articles and theses …
```

**第1章 (chap_intro.tex)**:
```latex
\chapter{Introduction}\label{chap:intro}

\section{What is \LaTeX?}\label{sec:latex}
\LaTeX\ is a macro-package used as a language-based approach
for typesetting documents. Various \LaTeX\ instructions are
interspersed with the input file of a document, say myfile.tex,
for obtaining the desired output as myfile.dvi or directly as
myfile.pdf …
```

**付録 (app_symb.tex)**:
```latex
\chapter{Symbols and Notations}\label{app:symbol}

There are unlimited number of symbols and notations which may
be required to be used in different documents. Moreover, there
exist many special letters used in different languages. All such
symbols and letters are to be produced in a \LaTeX\ file through
commands …
```

### ルートファイル (mybook.tex)

```latex
% File name: mybook.tex
\input{preamble}

\begin{document}
\begin{spacing}{1.2}

% Cover Page, Title, Preface and Dedication
\thispagestyle{empty} \include{coverpage} \cleardoublepage

\pagenumbering{roman}
\phantomsection\addcontentsline{toc}{chapter}{Title}
\thispagestyle{empty} \include{title} \cleardoublepage

\phantomsection\addcontentsline{toc}{chapter}{Dedication}
\thispagestyle{empty} \include{dedication} \cleardoublepage

\phantomsection\addcontentsline{toc}{chapter}{Preface}
\thispageset{empty} \include{preface} \cleardoublepage

% Contents, List of Tables and List of Figures
\phantomsection\addcontentsline{toc}{chapter}{Contents}
\thispagestyle{empty} \tableofcontents \cleardoublepage

\phantomsection\addcontentsline{toc}{chapter}{List of Tables}
\thispagestyle{empty} \listoftables \cleardoublepage

\phantomsection\addcontentsline{toc}{chapter}{List of Figures}
\thispagestyle{empty} \listoffigures \cleardoublepage

% Chapters
\pagenumbering{arabic}
\include{chap_intro}
\include{chap_font}
\include{chap_format}
\include{chap_table}
...

\end{spacing}

% Appendix, Bibliography and Index
\begin{spacing}{1.0}

\begin{appendix}
\include{app_symb}
\end{appendix}

\phantomsection\addcontentsline{toc}{chapter}{Bibliography}
\bibliographystyle{plain}
\bibliography{mybib}
\clearpage

\phantomsection\addcontentsline{toc}{chapter}{Index}
\printindex
\cleardoublepage

\end{spacing}

\end{document}
```

**重要なコマンド**:

| コマンド | 機能 |
|---------|------|
| `\input{preamble}` | プリアンブルファイルを読み込む |
| `\include{filename}` | `.tex` ファイルを読み込む（章単位） |
| `\phantomsection` | `\addcontentsline` の前に使用（ハイパーリンク対応） |
| `\addcontentsline{toc}{chapter}{Title}` | 番号なし章を目次に追加 |
| `\tableofcontents` | 目次を自動生成 |
| `\listoftables` | 表の一覧を自動生成 |
| `\listoffigures` | 図の一覧を自動生成 |
| `\appendix` | 以降の章を付録として扱う |
| `\printindex` | 索引を生成 |

### \include と \input の違い

| 特徴 | \include{file} | \input{file} |
|------|---------------|--------------|
| ページ分割 | 新しいページから開始 | 現在のページに継続 |
| `\includeonly` | 使用可能 | 使用不可 |
| 用途 | 章など大きな単位 | プリアンブル、小さな部分 |

**\includeonly による部分コンパイル**:

```latex
% プリアンブルに追加
\includeonly{intro,font,format}

% intro.tex, font.tex, format.tex のみコンパイル
```

**注意**: ページ数が変わる場合、最終版では使用しない（ページ番号のずれが生じるため）。

## Part による書籍の分割

### 基本的な使い方

```latex
\part{Part Title}

\chapter{Chapter 1}
...

\chapter{Chapter 2}
...
```

**出力**:
```
Part I
Part Title

Chapter 1
...

Chapter 2
...
```

**デフォルトの動作**:
- Part は Roman 数字（I, II, III, …）
- Chapter は連番（1, 2, 3, …）で、Part をまたいでも継続

### Part 別の章番号付け

章番号を Part ごとにリセット:

```latex
\makeatletter
\@addtoreset{chapter}{part}
\makeatother
\renewcommand{\thechapter}{\thepart.\arabic{chapter}}
```

**出力例**:
```
Part I

Chapter I.1
Chapter I.2

Part II

Chapter II.1
Chapter II.2
```

**注意**: `\renewcommand` がないと、Chapter は「1, 2, …」と表示され、Part 情報が失われ、混乱を招きます。

## コンパイルフロー

### 基本的なコンパイル手順

書籍（参考文献と索引を含む）のコンパイルは以下の手順:

```bash
latex mybook       # 1回目: 本文コンパイル
bibtex mybook      # 参考文献コンパイル
makeindex mybook   # 索引コンパイル
latex mybook       # 2回目: リンク
latex mybook       # 3回目: 最終確定
```

### 生成される中間ファイル

| 拡張子 | 生成元 | 内容 |
|--------|--------|------|
| `.aux` | `latex` | 相互参照情報（各 .tex ファイルごと） |
| `.log` | `latex` | コンパイルログ（エラー、警告） |
| `.dvi` | `latex` | デバイス非依存出力 |
| `.bbl` | `bibtex` | 整形済み参考文献 |
| `.blg` | `bibtex` | BibTeX ログ |
| `.idx` | `\index` | 索引エントリ（未整形） |
| `.ilg` | `makeindex` | makeindex ログ |
| `.ind` | `makeindex` | 整形済み索引 |
| `.toc` | `\tableofcontents` | 目次データ |
| `.lot` | `\listoftables` | 表の一覧データ |
| `.lof` | `\listoffigures` | 図の一覧データ |

### 自動化スクリプト (compile)

```bash
#!/bin/bash
# File name: compile

rm *.aux *.log *.dvi *.blg *.bbl *.idx *.ilg *.ind *.toc *.lot *.lof
latex mybook
bibtex mybook
makeindex mybook
latex mybook
latex mybook
dvipdf mybook.dvi
rm *.aux *.log *.dvi *.blg *.bbl *.idx *.ilg *.ind *.toc *.lot *.lof
```

**実行方法**:

```bash
# 実行権限を付与（初回のみ）
chmod 777 compile

# 実行
./compile
```

**スクリプトの動作**:
1. 古い中間ファイルを削除
2. 本文をコンパイル（`latex`）
3. 参考文献をコンパイル（`bibtex`）
4. 索引をコンパイル（`makeindex`）
5. 再度本文をコンパイル（リンク）
6. もう一度コンパイル（最終確定）
7. PDF に変換（`dvipdf`）
8. 中間ファイルを削除

**注意**: バグがあると中間ファイルが残り、修正後も同じエラーが出ることがあります。その場合、手動で中間ファイルを削除してから再コンパイルします。

## report クラス

`report` クラスは `book` とほぼ同じ構造ですが、以下の違いがあります:

| 項目 | book | report |
|------|------|--------|
| デフォルト印刷 | 両面 (`twoside`) | 片面 (`oneside`) |
| 章の開始 | 奇数ページ | 次のページ |
| `\frontmatter` | サポート | なし |
| `\mainmatter` | サポート | なし |
| `\backmatter` | サポート | なし |
| 用途 | 書籍 | レポート、学位論文 |

**基本テンプレート**:

```latex
\documentclass[a4paper,11pt]{report}

\title{My Report}
\author{Author Name}
\date{\today}

\begin{document}

\maketitle

\tableofcontents

\chapter{Introduction}
Introduction text …

\chapter{Methodology}
Methodology text …

\appendix
\chapter{Appendix}
Appendix text …

\bibliographystyle{plain}
\bibliography{mybib}

\end{document}
```

**注意**: 学位論文は `book` または `report` クラスで作成できます。大学の要件に応じて選択してください。

## まとめ

### クラス選択のガイドライン

| 文書タイプ | 推奨クラス | 理由 |
|-----------|-----------|------|
| 手紙・ビジネスレター | `letter` | 定型フォーマット、送受信者情報 |
| 論文（一般） | `article` | シンプル、セクション構造 |
| 論文（数学） | `amsart` | AMS 標準、数式サポート充実 |
| 技術レポート | `report` | 章サポート、片面印刷 |
| 学位論文 | `report` or `book` | 要件に応じて |
| 書籍 | `book` | 前付け/本文/後付け、両面印刷 |

### ベストプラクティス

1. **大規模文書**: ルートファイル方式を使用
2. **プリアンブル**: 別ファイルに分離して再利用
3. **バージョン管理**: `.tex` ファイルのみ管理（中間ファイルは除外）
4. **コンパイル**: 自動化スクリプトを作成
5. **デバッグ**: `.log` ファイルでエラー・警告を確認
6. **相互参照**: 複数回コンパイルして確定

### 一般的な落とし穴

- **日付の自動表示**: `article` はデフォルトで日付表示（`\date{}` で非表示）
- **ページ番号**: `letter` の非標準フォーマットは `\pagestyle{empty}` が必要
- **セクション番号**: `article` でセクション別番号にするには明示的な設定が必要
- **中間ファイル**: バグ修正後も古い中間ファイルが残るとエラーが継続
- **\include vs \input**: 用途を理解して使い分ける
- **\includeonly**: 最終版では使用しない
