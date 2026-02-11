# LaTeX リスト・Verbatim・コードガイド

リスト環境、定理環境、Verbatim表示、コードリスティング、段組、サンプルテキスト生成の高度な技法を扱う。

---

## 目次

1. [標準リストの拡張](#standard-lists)
2. [enumitem - 高度なリストカスタマイズ](#enumitem)
3. [定理環境](#theorem-environments)
4. [水平方向リスト](#horizontal-lists)
5. [チェックリスト](#checklists)
6. [Verbatim環境](#verbatim)
7. [コードリスティング](#code-listings)
8. [行番号と段組](#lines-columns)
9. [サンプルテキスト生成](#sample-text)

---

## 標準リストの拡張

### 標準リスト環境の構造

LaTeXの標準リスト：

```latex
% 箇条書き
\begin{itemize}
\item 項目1
\item 項目2
\end{itemize}

% 番号付きリスト
\begin{enumerate}
\item 項目1
\item 項目2
\end{enumerate}

% 説明リスト
\begin{description}
\item[用語1] 説明1
\item[用語2] 説明2
\end{description}
```

### リストのネスト

標準では最大4レベルまでネスト可能：

```latex
\begin{enumerate}
\item レベル1
  \begin{enumerate}
  \item レベル2
    \begin{enumerate}
    \item レベル3
      \begin{enumerate}
      \item レベル4
      \end{enumerate}
    \end{enumerate}
  \end{enumerate}
\end{enumerate}
```

---

## enumitem - 高度なリストカスタマイズ

### 基本使用法

```latex
\usepackage{enumitem}

% グローバル設定
\setlist{nosep}  % 項目間スペースをなくす

% 個別リストのカスタマイズ
\begin{itemize}[label=\textbullet, leftmargin=2em]
\item 項目
\end{itemize}
```

### 主要オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `label` | ラベルのフォーマット | `label=\alph*)` → a), b), c) |
| `ref` | 相互参照のフォーマット | `ref=\arabic*` |
| `leftmargin` | 左マージン | `leftmargin=*` (自動) |
| `itemsep` | 項目間の垂直スペース | `itemsep=0pt` |
| `topsep` | リスト前後のスペース | `topsep=5pt` |
| `parsep` | 段落間スペース | `parsep=0pt` |
| `labelwidth` | ラベルの幅 | `labelwidth=2em` |
| `labelsep` | ラベルと本文の間隔 | `labelsep=1em` |

### ラベルのカスタマイズ

```latex
% 番号スタイル
\begin{enumerate}[label=(\alph*)]  % (a), (b), (c)
\begin{enumerate}[label=\Roman*.]  % I., II., III.
\begin{enumerate}[label=\arabic*)]  % 1), 2), 3)

% 記号
\begin{itemize}[label=\textbullet]  % 標準の黒丸
\begin{itemize}[label=\textendash]  % enダッシュ
\begin{itemize}[label=$\triangleright$]  % 右向き三角

% 複数レベルの統一設定
\setlist[enumerate,1]{label=\arabic*.}
\setlist[enumerate,2]{label=\alph*)}
\setlist[enumerate,3]{label=\roman*.}
```

### インラインリスト

```latex
\usepackage[inline]{enumitem}

テキスト中に \begin{enumerate*}[label=(\alph*)]
\item 項目1
\item 項目2
\item 項目3
\end{enumerate*} を埋め込む。
% → テキスト中に (a) 項目1 (b) 項目2 (c) 項目3 を埋め込む。
```

### リストの再開

```latex
\begin{enumerate}
\item 項目1
\item 項目2
\end{enumerate}

中断されるテキスト

\begin{enumerate}[resume]
\item 項目3  % 番号が3から続く
\item 項目4
\end{enumerate}
```

### 説明リストのカスタマイズ

```latex
\begin{description}[
  style=nextline,        % ラベルの次の行から本文
  leftmargin=2cm,        % 左マージン
  font=\bfseries\sffamily  % ラベルのフォント
]
\item[用語1] 説明1
\item[用語2] 説明2
\end{description}
```

---

## 定理環境

### amsthm - 高度な定理宣言

```latex
\usepackage{amsthm}

% 定理スタイルの定義
\theoremstyle{plain}      % イタリック体
\newtheorem{theorem}{定理}[section]
\newtheorem{lemma}[theorem]{補題}
\newtheorem{corollary}[theorem]{系}

\theoremstyle{definition}  % 直立体
\newtheorem{definition}{定義}[section]
\newtheorem{example}{例}[section]

\theoremstyle{remark}      % 直立体、異なるフォーマット
\newtheorem{remark}{注意}
\newtheorem{note}{備考}
```

#### 定理スタイルの種類

| スタイル | 効果 | 用途 |
|---------|------|------|
| `plain` | ヘッド：ボールド、本文：イタリック | 定理・補題・命題 |
| `definition` | ヘッド：ボールド、本文：直立 | 定義・例 |
| `remark` | ヘッド：イタリック、本文：直立 | 注意・備考 |

#### 使用例

```latex
\begin{theorem}[ピタゴラスの定理]
直角三角形において、斜辺の長さを $c$、他の2辺の長さを $a, b$ とすると、
\[ a^2 + b^2 = c^2 \]
が成り立つ。
\end{theorem}

\begin{proof}
証明の内容...
\end{proof}
% 証明の最後に自動的に□（QED記号）が表示される
```

#### カスタム定理スタイル

```latex
\newtheoremstyle{mytheoremstyle}  % スタイル名
  {3pt}       % 上部スペース
  {3pt}       % 下部スペース
  {\itshape}  % 本文フォント
  {0pt}       % インデント
  {\bfseries} % ヘッドフォント
  {.}         % ヘッド後の句読点
  {.5em}      % ヘッド後のスペース
  {}          % ヘッドの仕様（空 = デフォルト）

\theoremstyle{mytheoremstyle}
\newtheorem{mytheorem}{定理}
```

---

### thmtools - 高度な定理ツール

```latex
\usepackage{thmtools}

\declaretheorem[
  name=定理,
  numberwithin=section,
  style=plain,
  refname={定理,定理},
  Refname={定理,定理}
]{theorem}

% 定理リストの生成
\listoftheorems
```

#### 定理の色付け

```latex
\usepackage{xcolor}
\usepackage{thmtools}

\declaretheoremstyle[
  headfont=\bfseries\sffamily\color{blue},
  bodyfont=\normalfont,
  mdframed={
    backgroundcolor=blue!10,
    linecolor=blue,
    linewidth=2pt
  }
]{colored}

\declaretheorem[style=colored, name=定理]{coltheorem}
```

---

## 水平方向リスト

### tasks - 水平配置リスト

```latex
\usepackage{tasks}

\begin{tasks}(4)  % 4列
\task 項目1
\task 項目2
\task 項目3
\task 項目4
\end{tasks}
```

#### カスタマイズ

```latex
\settasks{
  label=$\triangleright$,
  label-width=2em,
  item-indent=2.5em,
  column-sep=1em
}

\begin{tasks}[style=enumerate](3)  % 3列、番号付き
\task 項目1
\task 項目2
\task 項目3
\end{tasks}
```

---

## チェックリスト

### typed-checklist - チェックリスト管理

```latex
\usepackage{typed-checklist}

\begin{checklist}
\item[\started] 開始済みタスク
\item[\done] 完了タスク
\item 未着手タスク
\end{checklist}

% リスト内でのゴール設定
\Goal{main}{プロジェクト完了}

\begin{checklist}{main}
\item[\done] タスク1
\item[\done] タスク2
\item タスク3
\end{checklist}

% 進捗状況を出力
\StatusInfo{main}  % → 2/3 (66%) 完了
```

---

## Verbatim環境

### fancyvrb - 高機能Verbatim

```latex
\usepackage{fancyvrb}

\begin{Verbatim}[
  numbers=left,          % 行番号
  numbersep=5pt,         % 行番号と本文の間隔
  frame=single,          % フレーム
  fontsize=\small,       % フォントサイズ
  commandchars=\\\{\}    % コマンド文字
]
コード行1
コード行2 \textbf{ここは強調}
\end{Verbatim}
```

#### 主要オプション

| オプション | 説明 | 値の例 |
|-----------|------|--------|
| `numbers` | 行番号の位置 | `none`, `left`, `right` |
| `numbersep` | 行番号と本文の間隔 | `5pt` |
| `frame` | フレームの種類 | `none`, `single`, `lines`, `leftline` |
| `framesep` | フレームと本文の間隔 | `3pt` |
| `fontsize` | フォントサイズ | `\small`, `\footnotesize` |
| `baselinestretch` | 行送り | `0.8`, `1.2` |
| `showspaces` | スペースを可視化 | `true`, `false` |
| `showtabs` | タブを可視化 | `true`, `false` |

### ファイルからの入力

```latex
\VerbatimInput[
  numbers=left,
  frame=single,
  firstline=10,
  lastline=20
]{filename.py}
% filename.pyの10-20行目を表示
```

---

### fvextra - fancyvrbの拡張

```latex
\usepackage{fvextra}

\begin{Verbatim}[
  breaklines=true,        % 長い行を自動改行
  breakanywhere=true,     % 任意の位置で改行可
  breakafter=.,           % 特定文字の後で改行
  highlightlines={2-3,5}  % 特定行をハイライト
]
非常に長い行のコード...
\end{Verbatim}
```

### インラインVerbatim

```latex
コード内で \Verb|変数名| を使用。
% | は任意の区切り文字（!, +, @ 等も可）

% fvextraの拡張
\Verb+\command{argument}+  % シンタックスハイライト対応
```

---

## upquote - 真っ直ぐな引用符

プログラムコード内の引用符を垂直に表示：

```latex
\usepackage{upquote}
% verbatim環境内で 'quote' が真っ直ぐに表示される
```

---

## コードリスティング

### listings - コードのプリティプリンティング

```latex
\usepackage{listings}
\usepackage{xcolor}

\lstset{
  language=Python,
  basicstyle=\ttfamily\small,
  keywordstyle=\color{blue}\bfseries,
  commentstyle=\color{green!60!black}\itshape,
  stringstyle=\color{red},
  numbers=left,
  numberstyle=\tiny\color{gray},
  stepnumber=1,
  numbersep=8pt,
  showstringspaces=false,
  breaklines=true,
  frame=single,
  backgroundcolor=\color{gray!10},
  captionpos=b
}

\begin{lstlisting}[caption={Python コード例}]
def hello():
    print("Hello, World!")
\end{lstlisting}
```

### 言語定義

| 言語 | 指定方法 |
|------|---------|
| Python | `language=Python` |
| C | `language=C` |
| C++ | `language=C++` |
| Java | `language=Java` |
| JavaScript | `language=JavaScript` |
| SQL | `language=SQL` |
| HTML | `language=HTML` |
| LaTeX | `language=[LaTeX]TeX` |

### ファイルからの読み込み

```latex
\lstinputlisting[
  language=Python,
  firstline=10,
  lastline=30,
  caption={ファイルの一部}
]{script.py}
```

### インラインコード

```latex
\lstinline|code|
\lstinline[language=Python]|def func():|
```

### カスタム言語定義

```latex
\lstdefinelanguage{MyLang}{
  keywords={if, then, else, while, do, end},
  sensitive=true,
  comment=[l]{//},
  morecomment=[s]{/*}{*/},
  morestring=[b]",
  morestring=[b]'
}
```

---

## 行番号と段組

### lineno - 行番号付け

```latex
\usepackage{lineno}

\linenumbers  % 文書全体に行番号

% 特定範囲のみ
\begin{linenumbers}
行番号が付くテキスト
\end{linenumbers}
```

#### カスタマイズ

```latex
\setlength{\linenumbersep}{1cm}  % 行番号と本文の間隔
\renewcommand{\linenumberfont}{\normalfont\tiny\sffamily}
\modulolinenumbers[5]  % 5行ごとに番号表示
```

---

### paracol - 複数テキストストリームの並列配置

異なる内容を並列配置（対訳、比較等）：

```latex
\usepackage{paracol}

\begin{paracol}{2}
左列のテキスト
\switchcolumn
右列のテキスト
\switchcolumn
左列の続き
\end{paracol}
```

#### 使用場面

| 用途 | 説明 |
|-----|------|
| 対訳 | 原文と翻訳を並列表示 |
| 比較 | 複数バージョンの比較 |
| 注釈 | 本文と注釈を並列表示 |

#### 使用すべきでない場面

- 単純な段組（`multicol` を使用）
- フロート（`paracol` 内でフロートは使えない）

---

### multicol - 柔軟な段組

```latex
\usepackage{multicol}

\begin{multicols}{3}  % 3段組
テキストが自動的に3列に配置される。
列の高さは自動的にバランスされる。
\end{multicols}
```

#### カスタマイズ

```latex
\setlength{\columnsep}{2em}       % 列間スペース
\setlength{\columnseprule}{0.4pt} % 列間の罫線
```

#### フロートと脚注

```latex
% 列にまたがるフロート
\begin{figure*}
  \centering
  \includegraphics{wide-image}
  \caption{全列にまたがる図}
\end{figure*}

% 脚注は各列の下部に配置される
```

---

### multicolrule - 列間のカスタム罫線

```latex
\usepackage{multicolrule}

\SetMCRule{
  line-style=solid,
  width=1pt,
  color=blue
}

\begin{multicols}{2}
テキスト
\end{multicols}
```

---

## サンプルテキスト生成

### lipsum - ダミーテキスト

```latex
\usepackage{lipsum}

\lipsum[1]        % 1段落目
\lipsum[1-3]      % 1-3段落目
\lipsum[2][1-5]   % 2段落目の1-5文
```

### 類似パッケージ

| パッケージ | 言語 | 特徴 |
|-----------|------|------|
| `lipsum` | ラテン語 | 最も一般的 |
| `kantlipsum` | ドイツ語 | カントの著作 |
| `blindtext` | 多言語 | 構造化されたダミー |

---

### blindtext - 高度なレイアウトテスト

```latex
\usepackage{blindtext}

\blindtext       % 1段落
\Blindtext       % 複数段落
\blinddocument   % 文書全体（章・節・段落）

% リストのテスト
\blinditemize
\blindenumerate
\blinddescription
```

---

## 判断基準テーブル

### リスト環境の選択

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| ラベルのカスタマイズ | `enumitem` | 最も柔軟 |
| インラインリスト | `enumitem` (inline) | 文中にリストを埋め込み |
| 水平配置リスト | `tasks` | 複数列の横並び |
| チェックリスト | `typed-checklist` | 進捗管理機能 |

### 定理環境の選択

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| 標準的な定理 | `amsthm` | 数学文書の標準 |
| 高度なカスタマイズ | `thmtools` | 色・フレーム・リスト生成 |

### Verbatim環境の選択

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| 基本的なVerbatim | `fancyvrb` | 行番号・フレーム対応 |
| 長い行の自動改行 | `fvextra` | `fancyvrb`の拡張 |
| シンタックスハイライト | `listings` | 多言語対応 |
| 真っ直ぐな引用符 | `upquote` | プログラムコード用 |

### 段組の選択

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| 行番号付け | `lineno` | 査読原稿 |
| 並列テキスト（対訳） | `paracol` | 異なる内容を並列 |
| 通常の段組 | `multicol` | 自動バランシング |

### ダミーテキスト

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| 基本的なダミー | `lipsum` | 最も一般的 |
| 構造化されたダミー | `blindtext` | 章・節・リストを含む |

---

## まとめ

リストとVerbatim環境の高度な活用ポイント：

1. **enumitem** - リストのカスタマイズには必須
2. **amsthm** - 数学文書には標準的な定理環境
3. **fancyvrb/listings** - コードの表示にはこれらを使い分け
4. **multicol** - 段組の基本、フロート対応
5. **lipsum/blindtext** - レイアウトテストに活用

文書の種類と表現したい内容に応じて、適切なパッケージを選択することが重要。
