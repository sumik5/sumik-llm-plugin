# ユーザー定義マクロ

## 概要

LaTeXは組み込みコマンドや環境を提供していますが、ユーザーは独自のコマンドや環境を定義したり、既存のものを再定義することができます。この機能により、繰り返し使用する長いコマンドや定型文を短いコマンドで表現でき、文書作成の効率が向上します。

## 新規コマンドの定義

### 引数なしの新規コマンド

最も基本的な形式は `\newcommand{newc}{aval}` です。ここで `newc` は新しいコマンド名、`aval` は置き換えられる内容です。

**構文**:
```latex
\newcommand{\newc}{aval}
```

**注意事項**:
- コマンド名はアルファベットのみで構成
- `end` で始まらないこと
- 既存のコマンドと重複しないこと

**コード例**:

| 定義（プリアンブル） | 意味 |
|-------------------|------|
| `\newcommand{\bs}{$\backslash$}` | `\bs` で `\` を出力 |
| `\newcommand{\xv}{\mbox{\boldmath$x$}}` | `\xv` でベクトル **x** を出力 |
| `\newcommand{\veps}{\ensuremath{\varepsilon}}` | `\veps` で ε を出力（モードを問わない） |
| `\newcommand{\cg}{\it Center of Gravity\ /}` | `\cg` で *Center of Gravity* を出力 |

**使用例**:
```latex
\newcommand{\bs}{$\backslash$}
\newcommand{\xv}{\mbox{\boldmath$x$}}

% 本文で使用
The command \bs\ is used for backslash.
\xv\ is a vector.
```

**重要な注意点**:
- アルファベットで終わるコマンドは、空白を保護するために `\` で終端する必要があります（例: `\xv\`）
- `\mbox{}` は text-mode と math-mode の両方で動作
- `\ensuremath{}` は常に引数を math-mode で処理

### 必須引数付きの新規コマンド

引数を受け取るコマンドは `\newcommand{newc}[n]{..{#1}..{#2}..{#n}..}` の形式で定義します。

**構文**:
```latex
\newcommand{\newc}[n]{..{#1}..{#2}..{#n}..}
```

ここで `n` は引数の数（最大9個）、`#1`, `#2`, ..., `#n` は引数の番号です。

**数学コマンドの定義例**:

| 定義 | 意味 | 使用例 | 出力 |
|------|------|--------|------|
| `\newcommand{\vctr}[1]{\mbox{\boldmath{$#1$}}}` | ベクトル表記 | `\vctr{x}` | **x** |
| `\newcommand{\pde}[2]{\ensuremath{\frac{\partial #2}{\partial #1}}}` | 偏微分 | `\pde{y}{x}` | ∂x/∂y |
| `\newcommand{\ode}[2]{\ensuremath{\frac{d#2}{d#1}}}` | 常微分 | `\ode{y}{x}` | dx/dy |
| `\newcommand{\oded}[2]{\ensuremath{\frac{d^2#2}{d#1^2}}}` | 2階常微分 | `\oded{y}{x}` | d²x/dy² |
| `\newcommand{\odp}[2]{\ensuremath{\frac{d}{d#1}(#2)}}` | 微分（括弧付き） | `\odp{y}{x^2+3xy-5}` | d/dy(x²+3xy-5) |
| `\newcommand{\intg}[2]{\ensuremath{\int(#2)\,d#1}}` | 積分 | `\intg{x}{x^5+4x^2-10}` | ∫(x⁵+4x²-10)dx |
| `\newcommand{\dint}[4]{\ensuremath{\int_{#3}^{#4}(#2)\,d#1}}` | 定積分 | `\dint{p}{p^3q+5pq-q}{0}{3}` | ∫₀³(p³q+5pq-q)dp |
| `\newcommand{\lmt}[4]{\ensuremath{\lim_{#3\to#4}\frac{#1}{#2}}}` | 極限 | `\lmt{x^2+3x-10}{x-2}{x}{2}` | lim(x→2)(x²+3x-10)/(x-2) |

**実用例**:
```latex
\newcommand{\pde}[2]{\ensuremath{\frac{\partial #2}{\partial #1}}}
\newcommand{\dint}[4]{\ensuremath{\int_{#3}^{#4}(#2)\,d#1}}

% 本文で使用
The partial derivative is \pde{y}{x}.
The definite integral is \dint{p}{p^3q+5pq-q}{0}{3}.

% 空の引数も使用可能
\dint{p}{p^3q+5pq-q}{v}{} % 不定積分として使用
```

**便利なテクニック**:
- `\,` コマンドで微分記号の前に小さな空白を追加（例: `d#1`）
- 空の引数 `{}` を使って柔軟な定義が可能（不定積分など）

### オプション引数付きの新規コマンド

1つのオプション引数を持つコマンドは `\newcommand{newc}[n][farg]{..}` の形式で定義します。

**構文**:
```latex
\newcommand{\newc}[n][farg]{..{#1}..{#2}..{#n}..}
```

ここで `farg` はデフォルトの第1引数（オプション）です。

**定義例**:

| 定義 | 意味 |
|------|------|
| `\newcommand{\xv}[1][x]{\mbox{\boldmath{$#1$}}}` | デフォルトで x、オプションで別の文字をベクトル表記 |
| `\newcommand{\drv}[2][y]{\ensuremath{\frac{d}{d#1}(#2)}}` | デフォルトで y に関する微分、オプションで別の変数 |

**使用例**:

| LaTeX入力 | 出力 |
|-----------|------|
| `\xv\` | **x** (デフォルト) |
| `\xv[y]` | **y** (オプション指定) |
| `\drv{x}` | d/dy(x) (デフォルト y) |
| `\drv[x]{\sin x}` | d/dx(sin x) (オプション指定) |

```latex
\newcommand{\xv}[1][x]{\mbox{\boldmath{$#1$}}}
\newcommand{\drv}[2][y]{\ensuremath{\frac{d}{d#1}(#2)}}

% 本文で使用
\xv\ is a vector.        % デフォルトで x
\xv[y] is also a vector. % y を指定

% 微分
\drv{x}           % y に関する x の微分
\drv[x]{\sin x}   % x に関する sin x の微分
```

**注意**: ユーザー定義コマンドに許可されるオプション引数は1つのみです。

## \providecommand との違い

`\providecommand{newc}{aval}` は `\newcommand` と同様ですが、以下の点が異なります:

- `\newcommand`: 既存のコマンドと重複するとエラーを生成
- `\providecommand`: 既存のコマンドが存在する場合、メッセージなしに既存のコマンドを保持

## 既存コマンドの再定義

### \renewcommand の基本

既存のコマンドのスタイルを変更するには `\renewcommand{rcom}[n]{astyle}` を使用します。

**構文**:
```latex
\renewcommand{\rcom}[n]{astyle}
```

**一般的な使用例**:

```latex
% 箇条書きの記号を変更
\renewcommand{\labelitemi}{{\small$\vartriangleright$}}

% 章のラベルを変更
\renewcommand{\chaptername}{Unit}

% Abstract を Summary に変更
\renewcommand{\abstractname}{Summary}
```

### デフォルトラベルワードの変更

LaTeXの見出しコマンドが生成するデフォルトラベルワード:

| コマンド | デフォルトラベル | コマンド | デフォルトラベル |
|---------|----------------|---------|----------------|
| `\abstractname` | Abstract | `\indexname` | Index |
| `\appendixname` | Appendix | `\listfigurename` | List of Figures |
| `\bibname` | Bibliography | `\listtablename` | List of Tables |
| `\chaptername` | Chapter | `\partname` | Part |
| `\contentsname` | Contents | | |

**変更例**:
```latex
\renewcommand{\chaptername}{Unit}
\renewcommand{\abstractname}{Summary}
```

### 再定義の高度なテクニック

既存のコマンドを再定義に含めることはできません（例: `\renewcommand{\alpha}{Symbol-\alpha}` は不可）。以下の方法を使用します:

#### 方法1: \let で既存コマンドを保存

```latex
% 既存の \textcolor を保存
\let\oldtextcolor\textcolor

% 再定義してデフォルトで赤色に
\renewcommand{\textcolor}[2][red]{\oldtextcolor{#1}{#2}}

% 使用
\textcolor{atext}        % 赤色で出力
\textcolor[blue]{atext}  % 青色で出力
```

#### 方法2: \show で内部コーディングを取得

```latex
% \sigma の内部コーディングを取得
\show\sigma  % コンパイル時に "> \sigma=\mathchar"11B" と表示

% 内部コーディングを使って再定義
\renewcommand{\sigma}{\mbox{\boldmath{$\mathchar"11B$}}}
```

**\show コマンドの使い方**:
- LaTeX入力ファイルに `\show\sigma` を挿入
- コンパイルすると一時停止し、内部コーディングが表示される
- 表示された内容（例: `\mathchar"11B`）を使って再定義

## 新規環境の定義

### 引数なしの新規環境

新しい環境は `\newenvironment{nenv}{cstart}{cend}` で定義します。

**構文**:
```latex
\newenvironment{nenv}{cstart}{cend}
```

ここで `nenv` は環境名、`cstart` は開始コマンド、`cend` は終了コマンドです。

**定義例**:

```latex
% 強調された箇条書き環境
\newenvironment{itemem}%
  {\begin{itemize}\em}{\end{itemize}}

% 枠付きノート環境
\newenvironment{boxednote}%
  {\begin{center}\em\begin{tabular}{|p{0.8\textwidth}|}\hline}%
  {\\\hline\end{tabular}\end{center}}
```

**使用例**:

```latex
\begin{itemem}
  \item Emphasized items.
  \item Modified itemize environment.
\end{itemem}

\begin{boxednote}
  This is a new environment for producing important notes
  and observations in emphasized fonts inside a box.
\end{boxednote}
```

### 引数付きの新規環境

引数を持つ環境は `\newenvironment{nenv}[n]{cstart}{cend}` で定義します（最大9個の引数）。

**構文**:
```latex
\newenvironment{nenv}[n]{cstart}{cend}
```

**必須引数の例**:

```latex
% タイトル付きボックス環境
\newenvironment{boxednote}[1]%
  {\begin{center}{\bf #1}\em}%
  {\end{center}}

% 使用
\begin{boxednote}{Important Note\\}
  Contents here...
\end{boxednote}
```

**オプション引数の例**:

```latex
% オプションのタイトル付きボックス環境
\newenvironment{boxednote}[1][]%
  {\begin{center}{\bf #1}\em}%
  {\end{center}}

% 使用
\begin{boxednote}            % タイトルなし
  Contents here...
\end{boxednote}

\begin{boxednote}[Title\\]   % タイトル付き
  Contents here...
\end{boxednote}
```

**注意**: 環境に許可されるオプション引数は1つのみです。

## 定理型環境 (Theorem-Like Environments)

### \newtheorem の基本

数学文書では定理、補題、命題などの環境が必要です。`\newtheorem{akey}{nenv}[aunit]` で定義します。

**構文**:
```latex
\newtheorem{akey}{nenv}[aunit]
```

- `akey`: 環境のキーワード（使用時の名前）
- `nenv`: 表示される環境名
- `aunit` (オプション): 番号付けの基準となる単位（`chapter` や `section`）

**定義例**:

| 定義 | 意味 |
|------|------|
| `\newtheorem{thm}{Theorem}[chapter]` | 章ごとに番号付けされる Theorem 環境 |
| `\newtheorem{dfn}{Definition}[chapter]` | 章ごとの Definition 環境 |
| `\newtheorem{cor}{Corollary}[section]` | 節ごとの Corollary 環境 |
| `\newtheorem{lem}{Lemma}[section]` | 節ごとの Lemma 環境 |
| `\newtheorem{prop}{Proposition}` | グローバル番号付けの Proposition 環境 |
| `\newtheorem{prf}{Proof}` | グローバル番号付けの Proof 環境 |

**使用例**:

```latex
\newtheorem{dfn}{Definition}[chapter]

\begin{dfn}[\bf Center of Mass]\label{dfn-cm}
  This is the point at which the entire mass of a body
  of uniform density can be assumed to be concentrated.
\end{dfn}

\begin{dfn}{\bf Center of Gravity:}
  This is the point though which the resultant of the
  gravitational forces of all elemental weights of a
  body acts.\label{dfn-cg}
\end{dfn}

Definition~\ref{dfn-cm} defines center of mass,
while Definition~\ref{dfn-cg} defines center of gravity.
```

**出力例**:
```
Definition 13.1 (Center of Mass) This is the point at which...

Definition 13.2 Center of Gravity: This is the point though which...

Definition 13.1 defines center of mass, while Definition 13.2
defines center of gravity.
```

### タイトルの付け方

定理型環境にタイトルを付ける方法は2つあります:

1. **オプション引数** `[]`: 括弧付きで表示
   ```latex
   \begin{dfn}[Center of Mass]
   ```

2. **本文内で明示**: そのまま表示
   ```latex
   \begin{dfn}{\bf Center of Gravity:}
   ```

### ラベルと参照

定理型環境は `\label{}` と `\ref{}` でラベル付けと参照が可能です:

```latex
\begin{thm}\label{thm:pythagoras}
  In a right triangle, a² + b² = c².
\end{thm}

As stated in Theorem~\ref{thm:pythagoras}...
```

### amsthm パッケージによる拡張

`amsthm` パッケージは追加機能を提供します:

**\theoremstyle による制御**:

```latex
\usepackage{amsthm}

% スタイルの設定
\theoremstyle{break}  % 新しい行から開始
\newtheorem{thm}{Theorem}

\theoremstyle{plain}  % 同じ行に続ける
\newtheorem{lem}{Lemma}
```

**番号なし環境 (\newtheorem*)**:

```latex
% 番号なしの環境を定義
\newtheorem*{remark}{Remark}

\begin{remark}
  This is an unnumbered remark.
\end{remark}
```

一度しか使わない環境や、番号ではなく特定の名前で識別したい環境に有用です。

## カスタムフロート環境

### \newfloat による定義

`float` パッケージは `\newfloat{afloat}{vpos}{extn}[unit]` でカスタムフロート環境を提供します。

**構文**:
```latex
\newfloat{afloat}{vpos}{extn}[unit]
```

- `afloat`: フロート環境名（例: `algorithm`, `program`）
- `vpos`: 垂直位置（`h`, `b`, `t` またはそれらの組み合わせ）
- `extn`: キャプションを保存する補助ファイルの拡張子（例: `flt`）
- `unit` (オプション): 番号付けの単位（`section`, `chapter`）

**基本的な定義**:

```latex
\usepackage{float}

% アルゴリズム用フロート環境
\floatstyle{ruled}
\newfloat{algorithm}{hbt}{alg}[section]
\floatname{algorithm}{Algorithm}

% プログラム用フロート環境
\floatstyle{boxed}
\newfloat{program}{hbt}{prg}[section]
\floatname{program}{Program}
```

### フロートスタイル

`\floatstyle{style}` は `\newfloat` の前に使用します:

| スタイル | 説明 |
|---------|------|
| `plain` | キャプションを下部に配置（`\caption{}` の位置に関わらず） |
| `boxed` | フロートを枠で囲み、キャプションを下部に配置 |
| `ruled` | キャプションを上部に配置し、フロートを水平線で囲む |

### フロート環境のカスタマイズ

**1. \floatname でラベルを変更**:

```latex
\floatname{algorithm}{Algorithm}
\floatname{program}{Program}
```

デフォルトでは `\newfloat` の第1引数がラベルになりますが、これで変更できます。

**2. ページあたりのフロート数を変更**:

```latex
\setcounter{totalnumber}{10}
```

デフォルトは3つですが、これで最大10個まで許可できます。

**3. フロートのリストを作成**:

```latex
\listof{program}{List of Computer Programs}
```

`\listoftables` や `\listoffigures` と同様に、カスタムフロートのリストを生成できます。

### 実用例

```latex
\documentclass{article}
\usepackage{float}

% アルゴリズム環境の定義
\floatstyle{ruled}
\newfloat{algorithm}{hbt}{alg}[section]
\floatname{algorithm}{Algorithm}

% プログラム環境の定義
\floatstyle{boxed}
\newfloat{program}{hbt}{prg}[section]
\floatname{program}{Program}

\begin{document}

\section{Finding the maximum}

The main steps for finding and printing the maximum
from a given data set of n points are shown in
Algorithm~\ref{algo:max}.

\begin{algorithm}
\caption{Maximum of $n$ data points.}
\label{algo:max}
\begin{enumerate}
  \item Read the number of data points $n$.
  \item Read the data point $a_i$; $i=1$ to $n$.
  \item Set {\it max} $=a_1$.
  \item If max $< a_i$, set max $=a_i$; $i=2$ to $n$.
  \item Print max as the maximum of given $n$ number of data points.
\end{enumerate}
\end{algorithm}

Algorithm~\ref{algo:max} is coded in the C computer programming
language, which is shown here in Program~\ref{prog:max}.

\begin{program}
\caption{Maximum of $n$ data points.}
\label{prog:max}
\begin{verbatim}
#include <stdio.h>
#include <math.h>

int main()
{
  int n, a[101];
  int i, max;

  printf("Number of points = ");
  scanf("%d", &n);

  for(i = 1; i <= n; i++)
  {
    printf("a[%d] = ", i);
    scanf("%d", &a[i]);
  }

  max = a[1];
  for(i = 2; i <= n; i++)
    if(max < a[i]) max = a[i];

  printf("\nLargest value = ");
  printf("%d\n", max);

  return(0);
}
\end{verbatim}
\end{program}

\end{document}
```

**注意**:
- プログラムコードは `verbatim` 環境で挿入し、LaTeXモードを無視して入力そのままを出力
- フロート環境も `\label` と `\ref` でラベル付けと参照が可能

## 既存環境の再定義

### \renewenvironment の使用

既存の環境を再定義するには `\renewenvironment{nenv}{cstart}{cend}` を使用します。

**構文**:
```latex
\renewenvironment{nenv}{cstart}{cend}
```

**注意**: 環境の再定義は文書全体に影響します。一部のみ変更したい場合は、新しい環境を定義する方が適切です。

**実用例**: 箇条書き環境のカスタマイズ

```latex
\documentclass{article}
\usepackage{paralist}

% itemize 環境を再定義
\renewenvironment{itemize}%
  {\em\begin{compactitem}}{\end{compactitem}}

\begin{document}

\begin{itemize}
  \item India
  \begin{itemize}
    \item Assam
    \begin{itemize}
      \item Sonitpur
      \begin{itemize}
        \item Tezpur
        \item Dhekiajuli
        \item Balipara
      \end{itemize}
      \item Kamrup
      \item Cachar
    \end{itemize}
    \item Bihar
    \item Punjab
  \end{itemize}
  \item Pakistan
  \item Sri Lanka
\end{itemize}

\end{document}
```

この例では:
- `itemize` 環境を `compactitem`（`paralist` パッケージ）として再定義
- `\em` コマンドで交互のレベルを強調表示
- アイテム間のスペースを削除

**出力イメージ**:
```
• India
  - Assam
    * Sonitpur
      - Tezpur
      - Dhekiajuli
      - Balipara
    * Kamrup
    * Cachar
  - Bihar
  - Punjab
- Pakistan
- Sri Lanka
```

（奇数レベルが強調表示され、アイテム間のスペースが縮小されます）

## 実用的なマクロパターン集

### 数学マクロ定義の実例

以下は実際のLaTeX文書でよく使われるマクロ定義のテーブルです:

| マクロ | 定義 | 用途 |
|-------|------|------|
| **微分演算子** | | |
| `\pde` | `\newcommand{\pde}[2]{\frac{\partial #2}{\partial #1}}` | 偏微分 ∂x/∂y |
| `\ode` | `\newcommand{\ode}[2]{\frac{d#2}{d#1}}` | 常微分 dx/dy |
| `\oded` | `\newcommand{\oded}[2]{\frac{d^2#2}{d#1^2}}` | 2階微分 d²x/dy² |
| **積分演算子** | | |
| `\intg` | `\newcommand{\intg}[2]{\int(#2)\,d#1}` | 不定積分 ∫f(x)dx |
| `\dint` | `\newcommand{\dint}[4]{\int_{#3}^{#4}(#2)\,d#1}` | 定積分 ∫ₐᵇf(x)dx |
| **ベクトル・行列** | | |
| `\vctr` | `\newcommand{\vctr}[1]{\mathbf{#1}}` | ベクトル太字 |
| `\mat` | `\newcommand{\mat}[1]{\mathbf{#1}}` | 行列太字 |
| **極限・総和** | | |
| `\lmt` | `\newcommand{\lmt}[4]{\lim_{#3\to#4}\frac{#1}{#2}}` | 極限 lim(x→a) |
| `\summ` | `\newcommand{\summ}[3]{\sum_{#1=#2}^{#3}}` | 総和 Σ(i=1→n) |

### 文書構造マクロの実例

```latex
% カスタムセクション環境
\newenvironment{important}%
  {\begin{center}\begin{minipage}{0.9\textwidth}%
   \hrule\vspace{2mm}\textbf{重要:}\ }%
  {\vspace{2mm}\hrule\end{minipage}\end{center}}

% 例題環境
\newtheorem{example}{例題}[section]
\newtheorem{exercise}{演習問題}[section]

% カスタムリスト環境
\newenvironment{checklist}%
  {\begin{itemize}%
   \renewcommand{\labelitemi}{$\square$}}%
  {\end{itemize}}
```

## まとめ

ユーザー定義マクロを効果的に活用することで:

1. **効率性**: 繰り返し使用する長いコマンドを短縮
2. **一貫性**: 文書全体で統一されたスタイルを維持
3. **保守性**: 定義を変更するだけで文書全体に反映
4. **可読性**: LaTeX ソースコードが読みやすくなる

**ベストプラクティス**:
- プリアンブルに整理してコメント付きで定義
- 意味のある名前を使用（`\pd` より `\pde` の方が明確）
- プロジェクト固有のマクロは別ファイルに保存して `\input` で読み込む
- 複雑な定義には使用例をコメントで記載
