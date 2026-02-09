---
name: writing-latex
description: LaTeX document creation for Japanese academic reports. MUST load when .tex files are detected. Covers upLaTeX + dvipdfmx setup, minted code highlighting with Japanese font support, equations, figures, tables, and cover pages.
---

# LaTeX文書作成ガイド

## 使用タイミング

- `.tex`ファイルの新規作成・編集時
- 実験レポート・課題レポート・期末レポートの作成時
- 数式・図表・コードを含む学術文書の作成時
- minted/listingsの設定が必要な時

## 不明点がある場合

以下の判断が曖昧な場合は**必ずAskUserQuestionツールで確認**すること:

| 確認すべき項目 | 例 |
|---|---|
| 文書クラスのオプション | フォントサイズ、用紙設定 |
| セクション番号の有無 | レポートタイプにより異なる |
| 表紙の形式 | 独立ページ or インライン |
| コードハイライトの言語 | Python, C, MATLAB等 |
| 余白サイズ | 教員指定がある場合 |
| 参考文献の形式 | thebibliography or BibTeX |

## 基本構成

### ドキュメントクラス

```latex
\documentclass[12pt,a4paper,dvipdfmx]{jsarticle}
```

- `12pt`: 本文フォントサイズ（学術レポート標準）
- `a4paper`: A4用紙
- `dvipdfmx`: PDF生成ドライバ（upLaTeX必須）
- `notitlepage`: 表紙を独立ページにしない場合に追加

### 必須パッケージ

```latex
% === 日本語・PDF対応 ===
\usepackage[dvipdfmx]{graphicx}
\usepackage[dvipdfmx]{hyperref}
\usepackage{pxjahyper}              % hyperref + 日本語対応

% === レイアウト ===
\usepackage[top=20mm,bottom=20mm,left=20mm,right=20mm]{geometry}
\usepackage{float}                   % 図表の[H]配置

% === 数式 ===
\usepackage{amsmath,amssymb}
\usepackage{bm}                      % 太字数式 \bm{}

% === 単位 ===
\usepackage{siunitx}                 % \SI{値}{単位}

% === コードハイライト（minted優先） ===
\usepackage[dvipdfmx]{xcolor}
\usepackage{minted}
\usepackage{caption}
\usepackage{etoolbox}

% === 表 ===
\usepackage{booktabs}                % \toprule, \midrule, \bottomrule

% === 図 ===
\usepackage{subcaption}              % subfigure環境

% === 参考文献 ===
\usepackage{url}
\usepackage{cite}
```

### 追加パッケージ（必要時のみ）

```latex
\usepackage[deluxe]{otf}            % 日本語フォント拡張（mintedと併用推奨）
\usepackage{longtable}               % 複数ページにまたがる表
\usepackage{circuitikz}              % 電子回路図
\usepackage{tikz}                    % 図形描画
\usepackage{ascmac}                  % 囲み枠 \begin{itembox}
\usepackage{titlesec}                % セクション書式カスタマイズ
\usepackage{needspace}               % ページ分割制御
\usepackage{fancyvrb}                % 高度なverbatim
\usepackage{listings,jvlisting}      % listingsを使う場合（minted不使用時）
```

## minted設定（最重要）

### 基本設定

```latex
% グローバル設定
\setminted{
    fontsize=\small,
    linenos,
    frame=single,
    breaklines,
    numbersep=5pt,
    formatcom={\gtfamily\upshape}    % 日本語ゴシック・斜体解除
}

% 斜体を完全に無効化（日本語環境で必須）
\AtBeginEnvironment{minted}{%
    \let\textit\textup%
    \let\itshape\upshape%
    \let\em\upshape%
    \let\slshape\upshape%
}
\AtBeginEnvironment{Verbatim}{%
    \let\textit\textup%
    \let\itshape\upshape%
    \let\em\upshape%
    \let\slshape\upshape%
}

% キャプション位置
\captionsetup[listing]{position=below}
```

**重要**: `\gtfamily\upshape`は日本語コメントが斜体で化けるのを防ぐ。`[deluxe]{otf}`パッケージとの併用を推奨。

### 使用方法

```latex
% ブロックコード
\begin{minted}{python}
for i in range(10):
    print(i)  # 日本語コメントも正しく表示
\end{minted}

% コンソール出力（テキスト）
\begin{minted}{text}
実行結果: 42
\end{minted}

% インラインコード
\mintinline{python}{print("hello")}
```

### コンパイル

```bash
# minted使用時は -shell-escape が必須
uplatex -shell-escape document.tex
dvipdfmx document.dvi
# または latexmk
latexmk -pdfdvi -shell-escape document.tex
```

## セクション番号

用途に応じて選択する:

### 番号あり（実験レポート・課題レポート向け）

```latex
\section{目的}           % → 1 目的
\subsection{実験装置}     % → 1.1 実験装置
\subsubsection{動作原理}  % → 1.1.1 動作原理
```

### 番号なし（エッセイ・自由形式向け）

```latex
\section*{はじめに}       % 番号なし
```

### 数式番号をセクション連動

```latex
\numberwithin{equation}{section}  % 式(1.1), 式(1.2), ...
```

## 表紙

### 独立ページ表紙（実験レポート標準）

```latex
\thispagestyle{empty}
\begin{center}
  \vspace*{3cm}
  {\LARGE 科目名レポート}
  \vspace{1cm}
  {\Large テーマ名}
  \vspace{3cm}
  {\large 実験日：X月Y日}
  \vspace{0.8cm}
  {\large 学籍番号：XXXXXXX}
  \vspace{0.8cm}
  {\large 氏名：氏名}
\end{center}
\newpage
```

### インライン表紙（課題レポート向け）

```latex
\title{科目名 課題X}
\author{学籍番号, 氏名}
\date{2025/01/01}
\maketitle
```

## 数式

詳細パターンは [REFERENCE.md](REFERENCE.md) を参照。

### 基本パターン

```latex
% インライン数式
時定数は $\tau = RC$ で表される。

% 番号付き数式
\begin{equation}\label{eq:name}
  E = mc^2
\end{equation}

% 複数行（整列）
\begin{align}
  f(x) &= ax^2 + bx + c \\
  f'(x) &= 2ax + b
\end{align}

% 場合分け
\begin{equation}
  g(x, y) =
  \begin{cases}
    255 & \text{if } f(x, y) \geq T \\
    0   & \text{if } f(x, y) < T
  \end{cases}
\end{equation}

% 行列
\begin{equation}
  h = \frac{1}{9}
  \begin{pmatrix}
    1 & 1 & 1 \\
    1 & 1 & 1 \\
    1 & 1 & 1
  \end{pmatrix}
\end{equation}

% 単位表記（siunitx）
\SI{0.65}{\volt}          % 0.65 V
\SI{10}{\milli\ampere}    % 10 mA
\SI{1.6}{\kilo\ohm}       % 1.6 kΩ
```

### 参照

```latex
式~(\ref{eq:name})より...
式~\eqref{eq:name}より...   % amsmathの\eqref推奨
```

## 図

### 基本

```latex
\begin{figure}[H]
  \centering
  \includegraphics[width=0.8\textwidth]{images/filename.png}
  \caption{キャプション}\label{fig:name}
\end{figure}
```

### サブ図（複数画像の並列表示）

```latex
\begin{figure}[H]
  \centering
  \begin{subfigure}[b]{0.32\textwidth}
    \centering
    \includegraphics[width=\textwidth]{images/a.png}
    \caption{画像A}\label{fig:sub-a}
  \end{subfigure}
  \hfill
  \begin{subfigure}[b]{0.32\textwidth}
    \centering
    \includegraphics[width=\textwidth]{images/b.png}
    \caption{画像B}\label{fig:sub-b}
  \end{subfigure}
  \caption{全体キャプション}\label{fig:all}
\end{figure}
```

### 幅指定のパターン

| 指定方法 | 例 | 用途 |
|---|---|---|
| `\textwidth`比率 | `width=0.8\textwidth` | 本文幅に対する比率（推奨） |
| mm指定 | `width=100mm` | 絶対サイズ指定 |
| cm指定 | `width=13cm` | 絶対サイズ指定 |
| scale | `scale=0.8` | 原画像に対する倍率 |

### 参照

```latex
図~\ref{fig:name}に示すように...
```

## 表

```latex
\begin{table}[H]
  \centering
  \caption{キャプション}\label{tab:name}
  \begin{tabular}{ccc}
    \toprule
    列1 & 列2 & 列3 \\
    \midrule
    データ1 & データ2 & データ3 \\
    データ4 & データ5 & データ6 \\
    \bottomrule
  \end{tabular}
\end{table}
```

**必須**: `booktabs`の`\toprule`/`\midrule`/`\bottomrule`を使用。`\hline`は使わない。

## 参考文献

```latex
\begin{thebibliography}{99}
  \bibitem{ref1} 著者名, 「タイトル」,
    \url{https://example.com}, 2025年4月18日
  \bibitem{textbook} 著者名, \textit{教科書名},
    出版社, 出版年.
\end{thebibliography}
```

参照: `\cite{ref1}`

## 詳細リファレンス

- **[REFERENCE.md](REFERENCE.md)**: パッケージ詳細、listings設定、数式応用パターン、TikZ/circuitikz、コンパイル設定

## 関連スキル

- **writing-technical-docs**: 技術文書の7つのCの原則
- **enforcing-type-safety**: 数式の型安全性（単位の一貫性）
