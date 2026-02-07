# LaTeX 詳細リファレンス

## listings設定（minted不使用時の代替）

mintedが使えない環境（`-shell-escape`不可）ではlistingsを使用する。

### 基本設定

```latex
\usepackage{listings,jvlisting}  % jvlistingで日本語対応
\usepackage{xcolor}

\lstset{
    basicstyle={\ttfamily\small},
    identifierstyle={\small},
    commentstyle={\smallitshape},
    keywordstyle={\small\bfseries},
    stringstyle={\small\ttfamily},
    frame={tb},
    breaklines=true,
    postbreak=\mbox{\textcolor{red}{$\hookrightarrow$}\space},
    numbers=left,
    xleftmargin=3zw,
    xrightmargin=0zw,
    numberstyle={\scriptsize},
    stepnumber=1,
    numbersep=1zw,
    lineskip=-0.5ex,
    showstringspaces=false,
    keepspaces=true,
    extendedchars=false,
    inputencoding=utf8,
    upquote=true
}

% キャプション名を日本語化
\renewcommand{\lstlistingname}{コード}
```

### カラー付き設定

```latex
\lstset{
    basicstyle={\ttfamily},
    frame={tbrl},
    breaklines=true,
    numbers=left,
    keywordstyle=\color{blue},
    commentstyle={\color[HTML]{1AB91A}},
    identifierstyle=\color{black},
    stringstyle=\color{brown},
    captionpos=t
}
```

### 使用方法

```latex
\begin{lstlisting}[caption=プログラム名, label=code:name]
# コード
\end{lstlisting}
```

## 数式の応用パターン

### 添字とテキスト

```latex
% 添字に日本語やテキストを使う場合
R_{\mathrm{C}}          % ローマン体添字
V_{\mathrm{CE}}         % 複数文字添字
Z_{\mathrm{in}}         % 入力インピーダンス
h_{\mathrm{ie}}         % トランジスタパラメータ

% 太字ベクトル
\bm{\theta}             % bm使用
\mathbf{x}              % 代替手段
```

### 単位表記（siunitx詳細）

```latex
% 基本
\SI{0.65}{\volt}              % 0.65 V
\SI{10}{\milli\ampere}        % 10 mA
\SI{1.6}{\kilo\ohm}           % 1.6 kΩ
\SI{400}{\mega\hertz}         % 400 MHz
\SI{50}{\micro\ampere}        % 50 µA
\SI{200}{\milli\watt}         % 200 mW

% 複合単位
\SI{9.8}{\meter\per\second\squared}  % 9.8 m/s²

% 数値のみ
\num{1.23e4}                  % 1.23×10⁴
```

### 連立数式

```latex
\begin{align}
  P_{\mathrm{C}} &= V_{\mathrm{CE}} \times I_{\mathrm{C}} \\
  \SI{200}{\milli\watt} &= V_{\mathrm{CE}} \times \SI{10}{\milli\ampere} \\
  V_{\mathrm{CE}} &= \frac{\SI{200}{\milli\watt}}{\SI{10}{\milli\ampere}}
    = \SI{20}{\volt}
\end{align}
```

### 番号なし数式

```latex
% 単一行
\begin{equation*}
  E = mc^2
\end{equation*}

% 複数行
\begin{align*}
  a &= b + c \\
  d &= e + f
\end{align*}
```

### 総和・積分

```latex
\begin{equation}
  A = \sum_{x=0}^{W-1} \sum_{y=0}^{H-1} f(x, y)
\end{equation}

\begin{equation}
  g(x, y) = \sum_{i=-1}^{1} \sum_{j=-1}^{1} f(x+i, y+j) \cdot h(i, j)
\end{equation}
```

## 図の応用パターン

### サブ図の改行

```latex
\begin{figure}[H]
  \centering
  \begin{subfigure}[b]{0.48\textwidth}
    \centering
    \includegraphics[width=\textwidth]{images/before.png}
    \caption{変換前}\label{fig:before}
  \end{subfigure}
  \hfill
  \begin{subfigure}[b]{0.48\textwidth}
    \centering
    \includegraphics[width=\textwidth]{images/after.png}
    \caption{変換後}\label{fig:after}
  \end{subfigure}
  \\[1em]  % 改行して次の行へ
  \begin{subfigure}[b]{0.48\textwidth}
    \centering
    \includegraphics[width=\textwidth]{images/before_hist.png}
    \caption{変換前ヒストグラム}\label{fig:before-hist}
  \end{subfigure}
  \hfill
  \begin{subfigure}[b]{0.48\textwidth}
    \centering
    \includegraphics[width=\textwidth]{images/after_hist.png}
    \caption{変換後ヒストグラム}\label{fig:after-hist}
  \end{subfigure}
  \caption{全体キャプション}\label{fig:comparison}
\end{figure}
```

### 3列レイアウト

```latex
\begin{subfigure}[b]{0.30\textwidth}  % 0.30 × 3 + hfill余白
```

### 6枚グリッド（3×2）

```latex
% 3枚 + \\[0.5em] + 3枚
\begin{subfigure}[b]{0.30\textwidth}...\end{subfigure}
\hfill
\begin{subfigure}[b]{0.30\textwidth}...\end{subfigure}
\hfill
\begin{subfigure}[b]{0.30\textwidth}...\end{subfigure}
\\[0.5em]
\begin{subfigure}[b]{0.30\textwidth}...\end{subfigure}
\hfill
\begin{subfigure}[b]{0.30\textwidth}...\end{subfigure}
\hfill
\begin{subfigure}[b]{0.30\textwidth}...\end{subfigure}
```

## 電子回路図（circuitikz）

```latex
\usepackage{circuitikz}

\begin{figure}[h]
  \centering
  \begin{circuitikz}
    \draw
    (0,0) node[op amp] (opamp) {}
    (opamp.-) -- ++(-1,0) node[circ] {}
    (opamp.+) -- ++(-1,0) -- ++(0,-1) node[ground] {}
    (opamp.out) -- ++(1,0) node[circ] {};
  \end{circuitikz}
  \caption{オペアンプ回路}\label{fig:circuit}
\end{figure}
```

## TikZフローチャート

```latex
\usepackage{tikz}
\usetikzlibrary{arrows.meta,calc,positioning,shapes.geometric}

\begin{figure}[H]
  \centering
  \begin{tikzpicture}[
    scale=1.0,
    every node/.style={font=\small},
    box/.style={draw, rounded corners, minimum width=2cm, minimum height=0.8cm}
  ]
    \node[box] (start) {開始};
    \node[box, below=1cm of start] (process) {処理};
    \node[box, below=1cm of process] (end) {終了};
    \draw[-Stealth] (start) -- (process);
    \draw[-Stealth] (process) -- (end);
  \end{tikzpicture}
  \caption{処理フロー}\label{fig:flow}
\end{figure}
```

## セクション書式カスタマイズ

### 番号の非表示（構造は維持）

```latex
\usepackage{titlesec}
\usepackage{needspace}

\setcounter{secnumdepth}{4}

\renewcommand{\thesection}{\arabic{section}}
\renewcommand{\thesubsection}{}
\renewcommand{\thesubsubsection}{}

\titleformat{\section}
  {\normalfont\Large\bfseries}
  {}
  {0em}
  {\needspace{10\baselineskip}}
```

## 余白設定のバリエーション

```latex
% 均一余白（標準）
\usepackage[margin=25mm]{geometry}

% 個別指定（課題に応じて）
\usepackage[top=20mm,bottom=20mm,left=20mm,right=20mm]{geometry}

% 綴じ代あり
\usepackage[top=15mm,bottom=25mm,left=25mm,right=25mm]{geometry}
```

## コンパイル設定

### latexmkrc（推奨）

```perl
# .latexmkrc
$latex = 'uplatex -shell-escape -synctex=1 %O %S';
$bibtex = 'upbibtex %O %B';
$dvipdf = 'dvipdfmx %O -o %D %S';
$pdf_mode = 3;  # dvipdfmx
```

### Makefile

```makefile
TEX = uplatex -shell-escape
DVIPDF = dvipdfmx
TARGET = document

all: $(TARGET).pdf

$(TARGET).pdf: $(TARGET).dvi
	$(DVIPDF) $(TARGET).dvi

$(TARGET).dvi: $(TARGET).tex
	$(TEX) $(TARGET).tex
	$(TEX) $(TARGET).tex  # 参照解決のため2回

clean:
	rm -f *.aux *.log *.dvi *.out *.toc *.bbl *.blg
	rm -rf _minted
```

## 日本語特有の注意点

1. **`dvipdfmx`オプション**: `graphicx`、`hyperref`、`xcolor`に必ず付ける
2. **`pxjahyper`**: `hyperref`と日本語の互換性に必要
3. **`jvlisting`**: `listings`使用時の日本語対応
4. **`[deluxe]{otf}`**: 日本語フォント拡張。mintedの`\gtfamily`に必要
5. **`\gtfamily\upshape`**: コード内の日本語コメントが斜体で崩れるのを防止
6. **`zw`単位**: 全角幅（listings の `xleftmargin=3zw` 等）
7. **`-shell-escape`**: minted使用時に必須のコンパイルオプション

## 囲み枠（ascmac）

```latex
\usepackage{ascmac}

\begin{itembox}[l]{タイトル}
  囲み枠の中身
\end{itembox}
```

## enumerate / itemize / description

```latex
% 番号付きリスト
\begin{enumerate}
  \item 手順1
  \item 手順2
\end{enumerate}

% 箇条書き
\begin{itemize}
  \item 項目A
  \item 項目B
\end{itemize}

% 定義リスト
\begin{description}
  \item[用語1] 説明文
  \item[用語2] 説明文
\end{description}
```
