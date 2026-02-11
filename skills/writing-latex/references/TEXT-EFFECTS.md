# テキスト特殊効果（レイアウト・装飾・整形）

テキストの高度な整形・装飾・レイアウト調整のためのパッケージとテクニック。マージンノート、カラーボックス、グリッド組版、絶対配置、ドロップキャップ、図形整形、プルクォートなど。

---

## マージンノート - marginnote

### 概要

**marginnote** パッケージは、テキスト本文の横（マージン領域）に注釈・補足情報を配置。`\marginpar` の制限（float環境内で使用不可等）を克服し、柔軟な配置が可能。

### 基本使用法

```latex
\usepackage{marginnote}
\usepackage{xcolor}

% マージンノートのスタイル定義
\renewcommand*{\marginfont}{\strut\color{blue}\sffamily\scriptsize}

\begin{document}

The concept of microservices architecture\marginnote{See Chapter 3 for details}
has gained significant attention in recent years.

% 反対側のマージンに配置
\marginnote[\textit{Left margin note}]{\textit{Right margin note}}

\end{document}
```

### 主要コマンド

| コマンド | 構文 | 説明 |
|---------|------|------|
| `\marginnote` | `\marginnote[left]{right}[offset]` | マージンノート挿入 |
| `\marginfont` | `\renewcommand*{\marginfont}{...}` | フォントスタイル定義 |

### 垂直位置調整

```latex
% 3行分下にオフセット
\marginnote{Note text}[3\baselineskip]

% 上に移動
\marginnote{Note text}[-1cm]
```

### カラーボックス付きマージンノート

```latex
\usepackage{tcolorbox}
\newcommand{\colorednote}[1]{%
  \marginnote{%
    \begin{tcolorbox}[colback=yellow!10, colframe=orange, width=3cm]
      #1
    \end{tcolorbox}
  }
}

\colorednote{Important reminder}
```

---

## 数値の文字列変換 - fmtcount / numname

### 概要

数値を英語の文字列（"one", "two", "first", "second"等）に自動変換。章番号・ページ番号・カウンタを自然言語表現で出力。

### 基本使用法

```latex
\usepackage{fmtcount}

\begin{document}

% 数値を単語に変換
\numberstringnum{32}  % → thirty-two
\numberstring{page}   % 現在のページ番号を単語で
\numberstring{chapter}  % 現在の章番号を単語で

% 序数（1st, 2nd, 3rd...）
\ordinalnum{5}        % → 5th
\ordinalstring{section}  % → first, second, third...

% 大文字変換
\Numberstringnum{42}  % → Forty-two
\Ordinalstring{section}  % → First, Second...

\end{document}
```

### 実用例: カスタムセクションタイトル

```latex
\usepackage{titlesec}
\usepackage{fmtcount}

\titleformat{\chapter}[display]
  {\normalfont\huge\bfseries}
  {\chaptertitlename\ \Numberstring{chapter}}
  {20pt}
  {\Huge}

% 結果: "Chapter One", "Chapter Two"...
```

### 言語対応

```latex
\usepackage[english,french,german]{babel}
\usepackage{fmtcount}

\selectlanguage{french}
\numberstringnum{21}  % → vingt-et-un

\selectlanguage{german}
\numberstringnum{21}  % → einundzwanzig
```

---

## カラーボックス - tcolorbox

### 概要

**tcolorbox** は高度にカスタマイズ可能なカラーボックスを提供。タイトル付き、2段組、フレーム装飾、影付き、数式・コード・定理環境との統合が可能。

### 基本構造

```latex
\usepackage{tcolorbox}

\begin{tcolorbox}[
  title=\textbf{Examples},
  colback=blue!5!white,
  colframe=blue!75!white
]
  This is a highlighted text box with a title.
\end{tcolorbox}
```

### 2段組ボックス

```latex
\begin{tcolorbox}[title=Definition and Example]
  \textbf{Definition:} A function $f$ is continuous if...
  \tcblower  % 下部セクション開始
  \textbf{Example:} Consider $f(x) = x^2$...
\end{tcolorbox}
```

### よく使うオプション

| オプション | 効果 | 値の例 |
|-----------|------|--------|
| `colback` | 背景色 | `blue!5!white`, `yellow!10` |
| `colframe` | フレーム色 | `blue!75!black`, `red` |
| `title` | タイトル | `\textbf{Important}` |
| `rounded corners` | 角の丸み | `5pt`, `10pt` |
| `boxrule` | フレーム線幅 | `1pt`, `2pt` |
| `arc` | 角の曲率 | `0mm`（角張る）～`5mm` |
| `sharp corners` | 角を直角に | （値不要） |

### スタイルプリセット

```latex
% 警告ボックス
\newtcolorbox{warningbox}{
  colback=red!5!white,
  colframe=red!75!black,
  title=\faExclamationTriangle\ Warning,
  fonttitle=\bfseries
}

% ヒントボックス
\newtcolorbox{hintbox}{
  colback=green!5!white,
  colframe=green!50!black,
  title=\faLightbulb\ Hint,
  rounded corners
}

\begin{warningbox}
  Do not run this command as root.
\end{warningbox}

\begin{hintbox}
  Use Ctrl+Z to undo.
\end{hintbox}
```

### 定理環境との統合

```latex
\usepackage{amsthm}
\tcbuselibrary{theorems}

\newtcbtheorem{mytheo}{Theorem}{
  colback=blue!5,
  colframe=blue!35!black,
  fonttitle=\bfseries
}{thm}

\begin{mytheo}{Pythagorean Theorem}{pythag}
  For a right triangle with sides $a$, $b$, and hypotenuse $c$:
  \[ a^2 + b^2 = c^2 \]
\end{mytheo}

Reference: \ref{thm:pythag}
```

---

## レイアウト可視化 - showframe / layout / lua-visual-debug

### showframe: ページ枠線表示

```latex
\usepackage{showframe}

% オプション: ルーラー表示
\usepackage[rulers]{showframe}
```

ページのテキスト領域・マージン・ヘッダー・フッター領域の境界線を可視化。レイアウトデバッグに有用。

### layout: レイアウト寸法ダイアグラム

```latex
\usepackage{layout}

\begin{document}
\layout  % レイアウト寸法図を出力
\end{document}
```

全てのページレイアウトパラメータ（`\textwidth`, `\textheight`, `\oddsidemargin` 等）を図解付きで一覧表示。

### lua-visual-debug: ボックス・グルー・カーンの可視化（LuaLaTeX専用）

```latex
\usepackage{lua-visual-debug}

% LuaLaTeX でコンパイル
```

TeX の内部ボックス構造・グルー（スペース）・カーン（微調整スペース）・ペナルティを色付きで可視化。LaTeX の組版動作を理解するための学習ツール。

**要件**: LuaLaTeX でのコンパイル必須（pdfLaTeX 不可）

---

## グリッド組版 - grid / gridset

### 概要

ベースライングリッドに基づいた組版。全ての行が垂直方向に一定間隔で揃うため、2カラムレイアウトや見開きページで美しい整列が実現。

### 基本使用法

```latex
\usepackage[
  fontsize=10pt,
  baseline=12pt
]{grid}

\begin{document}

\begin{gridenv}
  通常のテキスト段落はグリッドに整列します。

  \begin{equation}
    E = mc^2
  \end{equation}

  数式の前後もグリッドに合わせて調整されます。
\end{gridenv}

\end{document}
```

### 注意事項

- `gridenv` 環境内では、数式・図表・リストの前後スペースがグリッドに合うよう自動調整される
- 大きな数式やフロートは複数行分のスペースを占有
- `\baselineskip` の整数倍でスペースが調整されるため、厳密な垂直リズムが保たれる

---

## 絶対位置配置 - eso-pic / textpos / atbegshi

### eso-pic: ページ上の絶対座標配置

```latex
\usepackage{eso-pic}

\AddToShipoutPictureBG{%
  % ページ左下基準
  \AtPageLowerLeft{%
    \put(1cm, 1cm){\textcolor{red}{Draft}}
  }
  % ページ中央
  \AtPageCenter{%
    \rotatebox{45}{%
      \textcolor{gray!30}{\fontsize{60}{72}\selectfont CONFIDENTIAL}
    }
  }
  % ページ右上
  \AtPageUpperLeft{%
    \put(\paperwidth - 3cm, -1cm){\includegraphics[width=2cm]{logo.png}}
  }
}
```

#### 主要コマンド

| コマンド | 基準点 |
|---------|--------|
| `\AtPageLowerLeft` | 左下 |
| `\AtPageCenter` | 中央 |
| `\AtPageUpperLeft` | 左上 |
| `\AtTextLowerLeft` | テキスト領域左下 |
| `\AtTextCenter` | テキスト領域中央 |

### textpos: テキストブロックのグリッド配置

```latex
\usepackage[absolute,overlay]{textpos}
\setlength{\TPHorizModule}{1cm}
\setlength{\TPVertModule}{1cm}

\begin{document}

\begin{textblock}{5}(10,15)  % 幅5cm, 位置(10cm, 15cm)
  This text is positioned at absolute coordinates.
\end{textblock}

\end{document}
```

---

## ドロップキャップ（落飾文字）- lettrine

### 概要

**lettrine** パッケージは、段落の最初の文字を大きく装飾的に表示（ドロップキャップ）。中世写本風のエレガントな効果。

### 基本使用法

```latex
\usepackage{lettrine}

\lettrine{O}{nce upon a time}, in a land far away...
```

### カスタマイズオプション

```latex
\lettrine[
  lines=3,          % 3行分の高さ
  loversize=0.2,    % さらに20%拡大
  lhang=0.3,        % 文字の30%を左マージンにはみ出す
  findent=0.3em,    % 1行目のインデント
  nindent=0pt       % 2行目以降のインデント
]{O}{nce upon a time}
```

### カラー付きドロップキャップ

```latex
\usepackage{xcolor}

\lettrine{\textcolor{red}{A}}{nother} story begins here.
```

### デフォルト値設定

```latex
\setcounter{DefaultLines}{3}
\renewcommand{\DefaultLraise}{0.25}
\renewcommand{\DefaultFindent}{0.3em}
\renewcommand{\DefaultNindent}{0pt}

% 以降、オプション省略で上記設定が適用される
\lettrine{O}{nce upon a time}
```

### coloredlettrine: 2色ドロップキャップ（XeLaTeX/LuaLaTeX専用）

**EB Garamond** フォントを使用した装飾的な2色ドロップキャップ。背景装飾とレター部分を別々の色で表現。

```latex
\documentclass{book}
\usepackage[a6paper,hmargin=1.5cm]{geometry}
\usepackage{microtype}
\usepackage{coloredlettrine}

\renewcommand{\EBLettrineBackColor}{SlateBlue}  % 背景装飾の色
\renewcommand{\EBLettrineFrontColor}{DarkBlue} % 文字の色

\setcounter{DefaultLines}{3}
\renewcommand{\DefaultLraise}{0.25}
\renewcommand{\DefaultFindent}{0.3em}
\renewcommand{\DefaultNindent}{0pt}

\begin{document}

\coloredlettrine{O}{nce upon a time}, professional writers
used a mechanical machine called a typewriter.

\coloredlettrine{T}{oday}, we prefer variable-width letters.

\end{document}
```

**要件**:
- XeLaTeX または LuaLaTeX でコンパイル
- EB Garamond フォント（OpenType）のインストール
- `coloredlettrine.sty` の配置

---

## 図形整形 - shapepar

### 概要

**shapepar** パッケージは、テキストを任意の図形（円・ハート・星形等）に整形。テキスト量に応じて図形サイズが自動調整される。

### 基本使用法

```latex
\usepackage{shapepar}
\usepackage{blindtext}

\shapepar{\heartshape}\blindtext[2]
```

### 定義済み図形

| 図形 | コマンド | 短縮形 |
|------|---------|--------|
| 正方形 | `\squareshape` | `\squarepar` |
| 円 | `\circleshape` | `\circlepar` |
| CD/DVD（穴あき円） | `\CDlabshape` | `\CDlabel` |
| ダイヤモンド | `\diamondshape` | `\diamondpar` |
| ハート | `\heartshape` | `\heartpar` |
| 星（5点） | `\starshape` | `\starpar` |
| 六角形 | `\hexagonshape` | `\hexagonpar` |
| ナット（穴あき六角形） | `\nutshape` | `\nutpar` |
| 長方形 | `\rectangleshape{height}{width}` | なし |

### 短縮形の例

```latex
% 以下は等価
\shapepar{\heartshape} text\ \ $\heartsuit$\par
\heartpar{text}
```

### カットアウト（テキストから図形を切り抜き）

```latex
\cutout{l}(5ex, 2\baselineskip)\setlength{\cutoutsep}{8pt}%
\shapepar{\circleshape} a few words of text\par\blindtext
```

- `l` / `r`: 左側 / 右側に配置
- オフセット: 水平・垂直のシフト量
- `\cutoutsep`: カットアウト図形と周囲テキストの距離（デフォルト12pt）

---

## プルクォート（引用の引き出し）- pullquote

### 概要

**pullquote** パッケージは、2カラムレイアウトで中央にカットアウトウィンドウを作成し、引用や画像を配置。周囲のテキストが自動的に回り込む。

### 基本構造

```latex
\usepackage{lipsum}
\usepackage{pullquote}

\newcommand{\myquote}{%
  \parbox{4cm}{%
    \hrule\vspace{1ex}
    \textit{I can't go to a restaurant and order food
      because I keep looking at the fonts on the menu.}
    \hfill Knuth, Donald (2002)%
    \vspace{1ex}
    \hrule
  }%
}

\begin{document}

\begin{pullquote}{object=\myquote}
  \lipsum[1]
\end{pullquote}

\end{document}
```

### 円形カットアウト + TikZ画像

```latex
\usepackage{tikz}

\newcommand{\mylogo}{%
  \begin{tikzpicture}
    \node[shape=circle, draw=gray!40, line width=3pt,
      fill={gray!15}, font=\Huge] {\TeX};
  \end{tikzpicture}%
}

\begin{pullquote}{shape=circular, object=\mylogo}
  \lipsum[1]
\end{pullquote}
```

### オプション

| オプション | 効果 | 値 |
|-----------|------|-----|
| `object` | 配置するコンテンツ | `\myquote`, `\includegraphics{...}` |
| `shape` | カットアウト形状 | `rectangular`（デフォルト）, `circular` |
| `shape=image` | 画像の形状に合わせる | （ImageMagick要インストール） |

### 制限事項

- 環境内は単純な段落テキストのみ推奨
- リスト（`itemize`）、数式ディスプレイ、セクション見出し、垂直スペース調整は計算エラーを起こす可能性あり
- 画像やテキストボックスには最適

---

## 関連パッケージ

| パッケージ | 用途 |
|----------|------|
| `microtype` | マイクロタイポグラフィ調整（全般に推奨） |
| `xcolor` | カラー定義（tcolorbox, marginnote等で使用） |
| `geometry` | ページレイアウト調整 |
| `tikz` | ベクター図形作成（pullquote, 装飾等） |
| `lipsum` / `blindtext` | ダミーテキスト生成（テスト用） |
| `hyperref` | ハイパーリンク（tcolorbox 定理環境との統合） |

---

## ドキュメント参照

- marginnote: `texdoc marginnote` / https://ctan.org/pkg/marginnote
- fmtcount: `texdoc fmtcount` / https://ctan.org/pkg/fmtcount
- tcolorbox: `texdoc tcolorbox` / https://ctan.org/pkg/tcolorbox
- showframe: `texdoc showframe` / https://ctan.org/pkg/showframe
- layout: `texdoc layout` / https://ctan.org/pkg/layout
- lua-visual-debug: `texdoc lua-visual-debug` / https://ctan.org/pkg/lua-visual-debug
- grid: `texdoc grid` / https://ctan.org/pkg/grid
- eso-pic: `texdoc eso-pic` / https://ctan.org/pkg/eso-pic
- textpos: `texdoc textpos` / https://ctan.org/pkg/textpos
- lettrine: `texdoc lettrine` / https://ctan.org/pkg/lettrine
- coloredlettrine: https://github.com/raphink/coloredlettrine
- shapepar: `texdoc shapepar` / https://ctan.org/pkg/shapepar
- pullquote: https://bazaar.launchpad.net/~tex-sx/tex-sx/development/
