# LaTeX 科学技術パッケージ応用ガイド

LaTeXで科学技術分野の文書を作成する際に有用な専門パッケージ群の使用法を解説します。

---

## 必要パッケージ

```latex
\usepackage{algorithm}        % アルゴリズム環境
\usepackage{algorithmicx}     % アルゴリズム記述
\usepackage{algpseudocode}    % 擬似コードスタイル
\usepackage{listings}         % コードリスティング
\usepackage{luacode}          % LuaLaTeXプログラミング
\usepackage{pgfplots}         % グラフ描画
\usepackage{siunitx}          % 物理量・単位
\usepackage{tikz-feynman}     % ファインマン図
\usepackage{mhchem}           % 化学式
\usepackage{chemfig}          % 分子構造図
\usepackage{circuitikz}       % 電気回路図
```

---

## アルゴリズム組版

### 基本的な擬似コード

```latex
\begin{algorithm}
  \caption{アルゴリズム名}
  \label{alg:example}
  \begin{algorithmic}[1]  % [1]で全行番号表示
    \Require{入力条件}
    \Function{関数名}{引数}
      \State 変数初期化
      \While{条件}
        \State 処理
      \EndWhile
      \If{条件}
        \State \Return{値}
      \EndIf
    \EndFunction
  \end{algorithmic}
\end{algorithm}
```

### カスタムコマンド定義

```latex
% ローカル変数宣言用コマンド
\algnewcommand{\Local}{\State\textbf{local variables: }}

% 代入文用コマンド（左辺幅調整）
\newcommand{\Let}[2]{\State $\mathmakebox[1em]{#1} \gets #2$}
```

---

## コードリスティング

### listings パッケージ

```latex
\usepackage{listings}
\usepackage{xcolor}
\usepackage{inconsolata}  % タイプライターフォント

% グローバル設定
\lstset{
  language         = C++,
  basicstyle       = \ttfamily,
  keywordstyle     = \color{blue}\textbf,
  commentstyle     = \color{gray},
  stringstyle      = \color{red},
  columns          = fullflexible,
  numbers          = left,
  numberstyle      = \scriptsize\sffamily\color{gray},
  showstringspaces = false,
  float
}

% コード挿入
\begin{lstlisting}
// C++コード例
#include <iostream>
int main() {
    std::cout << "Hello LaTeX!" << std::endl;
}
\end{lstlisting}

% インラインコード
\lstinline!#include <iostream>!

% 外部ファイル読み込み
\lstinputlisting[firstline=4, lastline=10]{filename.cpp}

% コード一覧生成
\lstlistoflistings
```

### 言語定義のカスタマイズ

独自言語のシンタックスハイライトはマニュアル参照:
- `texdoc listings`
- https://texdoc.org/pkg/listings

---

## LuaLaTeXプログラミング

### 基本的なLua埋め込み

```latex
\documentclass{article}
\usepackage{luacode}
\begin{document}

% luacode環境（複数行）
\begin{luacode}
  local x = 1
  for i=1,10 do
    x = (x + 2/x)/2
  end
  tex.print(x)
\end{luacode}

% \directluaコマンド（1行）
$\sqrt{2} \approx \directlua{tex.print(math.sqrt(2))}$

\end{document}
```

### pgfplotsとの連携

```latex
\documentclass[border=10pt]{standalone}
\usepackage{pgfplots}
\usepackage{luacode}
\pgfplotsset{width=7cm, compat=1.18}

% Lua関数定義
\begin{luacode}
  function mandelbrot(cx, cy, imax, smax)
    local x, y, x1, y1, i, s = 0, 0, 0, 0, 0, 0
    while (s <= smax) and (i < imax) do
      x1 = x * x - y * y + cx
      y1 = 2 * x * y + cy
      x, y, i = x1, y1, i + 1
      s = x * x + y * y
    end
    if (i < imax) then tex.print(i) else tex.print(0) end
  end
\end{luacode}

\begin{document}
\begin{tikzpicture}
  \begin{axis}[colorbar, point meta max=30, view={0}{90}]
    \addplot3[surf, domain=-1.5:0.5, domain y=-1:1, samples=200, shader=interp]
      { \directlua{mandelbrot(\pgfmathfloatvalueof\x, \pgfmathfloatvalueof\y, 10000, 4)} };
  \end{axis}
\end{tikzpicture}
\end{document}
```

---

## グラフ理論（tkz-graph）

```latex
\usepackage{tkz-graph}
\SetGraphUnit{3}  % 頂点間距離(cm)
\GraphInit[vstyle=Shade]  % スタイル設定

\begin{tikzpicture}
  \Vertices{circle}{A,B,C,D,E}  % 円形配置
  \Edges(A,B,C,D,E,A,D,B,E,C,A)  % 辺の接続
\end{tikzpicture}

% カスタムスタイル
\tikzset{
  VertexStyle/.append style = {inner sep=5pt, font=\Large\bfseries},
  EdgeStyle/.append style   = {->, bend left},
  LabelStyle/.append style  = {fill=yellow!50, text=red}
}

% 頂点配置コマンド: \EA, \WE, \NO, \SO, \NOEA, \NOWE, \SOEA, \SOWE
```

---

## 物理量・単位（siunitx）

### 基本コマンド

```latex
\usepackage{siunitx}

% 量と単位
\qty{1.5e3}{\meter\per\second}  % 1.5×10³ m/s
\qty{25}{\degreeCelsius}        % 25°C

% 数値のみ
\num{12345}           % 12 345（3桁区切り）
\num{1.23e-5}         % 1.23×10⁻⁵

% 単位のみ
\unit{\kg\m\per\square\s}  % kg m/s²
```

### 表示形式カスタマイズ

```latex
% プリアンブルで設定
\sisetup{
  per-mode = symbol,      % m/s形式（デフォルト: m s⁻¹）
  output-decimal-marker = {,}  % 小数点記号
}

% 計算式での強調
\usepackage{cancel}
\usepackage{color}
\qty{1e-3}{\cancel\m\highlight{red}\km\per\s}
```

---

## ファインマン図

```latex
\usepackage{tikz-feynman}
\usetikzlibrary{positioning,quotes}

\feynmandiagram[horizontal=a to b] {
  i1 [particle=$e^-$] -- [fermion] a -- [fermion] f1 [particle=$e^-$],
  a -- [photon, "$\gamma$", red, thick, momentum' = {[arrow style=red]$k$}] b,
  i2 [particle=$\mu^-$] -- [anti fermion] b -- [anti fermion] f2 [particle=$\mu^-$]
};
```

**代替パッケージ**: `feynmf`, `feynmp`
**リソース**: https://feynm.net, https://wiki.physik.uzh.ch/cms/latex:feynman

---

## 化学式

### chemformula パッケージ

```latex
\usepackage{chemformula}

% 化学式
\ch{H2O}                    % H₂O
\ch{2 H2 + O2 -> 2 H2O}     % 化学反応式
\ch{SO4^2-}                 % イオン
\ch{^{14}_{6}C}             % 同位体

% 状態記号
\ch{Fe^{2+}_{(aq)}}
```

### mhchem パッケージ

```latex
\usepackage{mhchem}

\ce{H2O}
\ce{CO2 + C -> 2 CO}
\ce{Zn^2+}
\ce{^{227}_{90}Th+}
```

---

## 分子構造図（chemfig）

```latex
\usepackage{chemfig}

% ベンゼン環
\chemfig{*6(=-=-=-)}

% 置換基付きベンゼン
\chemfig{*6(-=-=-(-OH)=)}  % フェノール

% 複雑な構造
\chemfig{
  H-C(-[2]H)(-[6]H)-C(-[2]H)(-[6]H)-OH
}

% Lewis構造式
\setatomsep{2em}
\chemfig{
  H-\lewis{0:2:,O}-H
}
```

---

## 原子・軌道図（modiagram, bohr）

```latex
\usepackage{modiagram}

% 分子軌道エネルギー図
\begin{MOdiagram}
  \atom[N]{left}{1s, 2s, 2p}
  \atom[N]{right}{1s, 2s, 2p}
  \molecule[O2]{1sMO, 2sMO, 2pMO}
\end{MOdiagram}

% Bohrモデル
\usepackage{bohr}
\bohr[number-of-electrons=18]{18}{Ar}
```

---

## 電気回路図（circuitikz）

```latex
\usepackage{circuitikz}

\begin{circuitikz}[american voltages]
  \draw (0,0) to[battery1, l=$V$] (0,2)
    to[R=$R_1$] (2,2)
    to[C=$C$] (2,0)
    to[short] (0,0);

  % 並列回路
  \draw (2,2) to[R=$R_2$] (4,2)
    to[L=$L$] (4,0) -- (2,0);

  % 測定器
  \draw (4,2) to[ammeter, l=$A$] (6,2);
\end{circuitikz}

% european / american スタイル選択可能
```

---

## 判断基準テーブル

| 用途 | パッケージ | 特徴 |
|------|-----------|------|
| アルゴリズム | algorithmicx | Pascal/C風スタイル選択可 |
| コード表示 | listings | 多言語対応、カスタマイズ豊富 |
| 動的計算 | luacode | プログラミング言語Lua埋め込み |
| グラフ理論 | tkz-graph | 頂点・辺スタイル豊富 |
| 単位系 | siunitx | SI単位標準準拠 |
| 素粒子物理 | tikz-feynman | LuaLaTeX必須 |
| 化学式 | mhchem / chemformula | どちらも実用的 |
| 分子構造 | chemfig | TikZ連携、柔軟な描画 |
| 電気回路 | circuitikz | american/europeanスタイル |

---

## 参考資料

- algorithmicx: `texdoc algorithmicx`
- listings: `texdoc listings`
- luacode: Lua公式ドキュメント https://www.lua.org/docs.html
- siunitx: `texdoc siunitx`
- tikz-feynman: `texdoc tikz-feynman`
- chemfig: `texdoc chemfig`
- circuitikz: `texdoc circuitikz`
