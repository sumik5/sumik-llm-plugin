# 高等数学・数式フォント

LaTeX における高度な数式組版とフォント設定の完全ガイド。

---

## 1. amsmath / mathtools 表示数式環境

### 表示数式構造の比較表

| 環境 | 整列 | 番号付け | 複数列 | 用途 |
|------|------|---------|-------|------|
| `equation` | 中央 | 自動1個 | ❌ | 単一数式 |
| `equation*` | 中央 | なし | ❌ | 単一数式（番号なし） |
| `align` | 複数点で整列 | 各行自動 | ✅ | 複数行の等式整列 |
| `align*` | 複数点で整列 | なし | ✅ | 整列数式（番号なし） |
| `gather` | 中央 | 各行自動 | ❌ | 複数行の中央揃え |
| `gather*` | 中央 | なし | ❌ | 中央揃え（番号なし） |
| `flalign` | 左右均等配置 | 各行自動 | ✅ | 全幅に分散整列 |
| `flalign*` | 左右均等配置 | なし | ✅ | 分散整列（番号なし） |
| `alignat` | 手動間隔制御 | 各行自動 | ✅ | 複雑な整列（間隔指定） |
| `alignat*` | 手動間隔制御 | なし | ✅ | 複雑整列（番号なし） |
| `multline` | 分割表示 | 最終行のみ | ❌ | 長い数式の折り返し |
| `multline*` | 分割表示 | なし | ❌ | 折り返し（番号なし） |

### 使い分け判断基準

**単一数式**:
```latex
% 標準: equation
\begin{equation}
  E = mc^2
\end{equation}
```

**複数行・等号揃え**:
```latex
% align（各行番号）
\begin{align}
  a &= b + c \\
  x &= y - z
\end{align}

% gather（等号揃えなし）
\begin{gather}
  a = b + c \\
  x = y - z
\end{gather}
```

**複数列**:
```latex
% align（自動間隔）
\begin{align}
  a &= b  &  x &= y \\
  c &= d  &  z &= w
\end{align}

% alignat（手動間隔、最初の引数 = 列ペア数）
\begin{alignat}{2}
  a &= b  &\qquad  x &= y \\
  c &= d  &\qquad  z &= w
\end{alignat}
```

**長い数式の折り返し**:
```latex
\begin{multline}
  a + b + c + d + e + f \\
  + g + h + i + j + k
\end{multline}
```

**左右均等配置**:
```latex
\begin{flalign}
  a &= b  &&  x &= y  &&
\end{flalign}
```

### 数式番号とタグの制御

```latex
% 個別行の番号抑制
\begin{align}
  a &= b \\
  c &= d  \notag  % この行は番号なし
\end{align}

% カスタムタグ
\begin{equation}
  E = mc^2  \tag{Einstein}
\end{equation}
\begin{equation}
  E = mc^2  \tag*{Einstein}  % 括弧なし
\end{equation}

% サブ番号
\begin{subequations}
  \begin{align}
    a &= b  \label{eq:1a} \\  % (1a)
    c &= d  \label{eq:1b}     % (1b)
  \end{align}
\end{subequations}
```

### breqn パッケージ（自動数式改行）

```latex
\usepackage{breqn}

\begin{dmath}
  % 長い数式を自動で折り返し
  a + b + c + d + e + f + g + h + i + j + k + l + m
\end{dmath}
```

**注意**: 複雑な数式では予期しない結果の可能性あり。手動調整を推奨。

---

## 2. 行列環境

### amsmath 標準行列

| 環境 | 区切り子 | 用途 |
|------|---------|------|
| `matrix` | なし | 基本行列 |
| `pmatrix` | `( )` | 丸括弧 |
| `bmatrix` | `[ ]` | 角括弧 |
| `Bmatrix` | `{ }` | 波括弧 |
| `vmatrix` | `\| \|` | 縦棒（行列式） |
| `Vmatrix` | `\|\| \|\|` | 二重縦棒（ノルム） |

**例**:
```latex
\[
A = \begin{pmatrix}
  a & b \\
  c & d
\end{pmatrix}, \quad
\det A = \begin{vmatrix}
  a & b \\
  c & d
\end{vmatrix}
\]
```

### mathtools 拡張行列

```latex
\usepackage{mathtools}

% * 版: 列揃え指定可能（[l], [c], [r]）
\begin{pmatrix*}[r]
  -1 & 3 \\
  2 & -4
\end{pmatrix*}

% small 版: コンパクト行列
\begin{bsmallmatrix}
  a & b \\
  c & d
\end{bsmallmatrix}
```

### delarray パッケージ（区切り子付き配列）

```latex
\usepackage{delarray}

% 左右に異なる区切り子
\begin{array}({cc})
  a & b \\
  c & d
\end{array}

% 上下にも区切り子
\begin{array}\{{cc}\}
  a & b \\
  c & d
\end{array}
```

### bigdelim パッケージ（大きな区切り子）

```latex
\usepackage{bigdelim}

\[
\begin{array}{ccc}
  & \ldelim\{{3}{3mm}[説明] & \\
  a & b & c \\
  d & e & f \\
  g & h & i
\end{array}
\]
```

---

## 3. 可換図式

### 標準LaTeX方式

```latex
\[
\begin{array}{ccc}
  A & \xrightarrow{f} & B \\
  \downarrow & & \downarrow \\
  C & \xrightarrow{g} & D
\end{array}
\]
```

### amscd（AMSスタイル）

```latex
\usepackage{amscd}

\begin{CD}
  A @>f>> B \\
  @VVV @VVgV \\
  C @>>h> D
\end{CD}
```

### tikz-cd（推奨）

```latex
\usepackage{tikz-cd}

\begin{tikzcd}
  A \arrow{r}{f} \arrow{d} & B \arrow{d}{g} \\
  C \arrow{r}{h} & D
\end{tikzcd}

% 複雑な図式
\begin{tikzcd}[row sep=large, column sep=large]
  A \arrow{r}{\phi} \arrow[swap]{d}{f} & B \arrow{d}{g} \\
  C \arrow{r}{\psi} & D \arrow[dashed]{ul}
\end{tikzcd}
```

---

## 4. 複合構造・装飾

### 分数

| コマンド | 説明 | 用途 |
|---------|------|------|
| `\frac{num}{den}` | 標準分数 | display mode |
| `\dfrac{num}{den}` | display style（強制） | inline mode |
| `\tfrac{num}{den}` | text style（強制） | display mode（小さく） |
| `\cfrac{num}{den}` | 連分数 | 連分数専用 |

**例**:
```latex
% 連分数
\[
x = a_0 + \cfrac{1}{a_1 + \cfrac{1}{a_2 + \cfrac{1}{a_3 + \dotsb}}}
\]

% インライン数式で display style
The fraction $\dfrac{1}{2}$ is half.
```

### 積分記号

```latex
% amsmath標準
\int, \iint, \iiint, \iiiint

% esint パッケージ（追加記号）
\usepackage{esint}
\oint, \oiint, \varint, \fint

% wasysym パッケージ
\usepackage{wasysym}
\sqint  % 四角積分記号
```

### 微分演算子（diffcoeff パッケージ）

```latex
\usepackage{diffcoeff}

\diff{y}{x}              % dy/dx
\diff[2]{y}{x}           % d²y/dx²
\diffp{f}{x}             % ∂f/∂x
\diffp[2,1]{f}{x,y}      % ∂³f/∂x²∂y
```

### ディラック記法（braket パッケージ）

```latex
\usepackage{braket}

\bra{\psi}               % ⟨ψ|
\ket{\phi}               % |φ⟩
\braket{\psi|\phi}       % ⟨ψ|φ⟩
\Braket{\psi|H|\phi}     % ⟨ψ|H|φ⟩
```

### 囲み数式（empheq パッケージ）

```latex
\usepackage{empheq}

% ボックスで囲む
\begin{empheq}[box=\fbox]{align}
  a &= b \\
  c &= d
\end{empheq}

% 左に記号
\begin{empheq}[left=\empheqlbrace]{align}
  a &= b \\
  c &= d
\end{empheq}
```

### テンソル記法（mattens パッケージ）

```latex
\usepackage{mattens}

\tensor{R}{^a_b^c_d}     % R^a_b^c_d（適切な間隔）
\tensor*{T}{^i_j}        % 添字の自動調整
```

---

## 5. 可変記号コマンド

### 水平拡張

| コマンド | 説明 |
|---------|------|
| `\overbrace{...}^{text}` | 上ブレース |
| `\underbrace{...}_{text}` | 下ブレース |
| `\xrightarrow[below]{above}` | 拡張右矢印 |
| `\xleftarrow[below]{above}` | 拡張左矢印 |
| `\xRightarrow, \xLeftarrow` | 二重矢印 |
| `\xleftrightarrow, \xLeftrightarrow` | 双方向矢印 |

**例**:
```latex
\[
\overbrace{a + b + c}^{\text{sum}} = \underbrace{d + e + f}_{\text{total}}
\]

\[
A \xrightarrow{\text{isomorphism}} B
\]
```

### abraces パッケージ（カスタマイズ可能）

```latex
\usepackage{abraces}

\aoverbrace[L1R]{expression}  % 上ブレース（左1・右標準）
\aunderbrace[L2R3]{expression} % 下ブレース（左2・右3）
```

### 垂直拡張

```latex
% 自動サイズ調整
\left( \frac{a}{b} \right)

% 手動サイズ
\bigl( \bigr), \Bigl( \Bigr), \biggl( \biggr), \Biggl( \Biggr)

% 片側のみ
\left. \frac{\partial f}{\partial x} \right|_{x=0}
```

---

## 6. 数式内の言葉

### \text コマンド

```latex
% 数式内にテキスト
\[
f(x) = \begin{cases}
  x^2 & \text{if } x > 0 \\
  0   & \text{otherwise}
\end{cases}
\]

% 数式モードを維持したい場合
\[
a = b \quad \text{and} \quad c = d
\]
```

### 演算子名定義

```latex
% 既存演算子: \sin, \cos, \log, \lim, \max, \min, \det, ...

% カスタム演算子
\DeclareMathOperator{\tr}{tr}           % trace
\DeclareMathOperator*{\argmax}{arg\,max} % argmax（上下に添字）

% 使用例
\[
\tr(A), \quad \argmax_{x \in X} f(x)
\]
```

---

## 7. 数式レイアウトの微調整

### サイズ自動制御

```latex
% 自動（推奨）
\left( \frac{a}{b} \right)

% 手動（より細かい制御）
\biggl( \frac{a}{b} \biggr)  % サイズ選択: \big, \Big, \bigg, \Bigg
```

**判断基準**:
- **自動（`\left`/`\right`）**: 複雑な式、入れ子の深い式
- **手動**: 視覚的バランス重視、細かい調整が必要

### インライン数式の改行制御

```latex
% 改行許可（デフォルトはほぼ許可しない）
\usepackage{amsmath}
\allowdisplaybreaks[4]  % 1-4: 柔軟性（4 = 最も柔軟）

% 個別制御
\begin{align}
  a &= b \\
  c &= d \\*  % この後の改行を禁止
  e &= f
\end{align}
```

### 水平間隔調整

| コマンド | 間隔 | 用途 |
|---------|------|------|
| `\,` | 3/18 quad | 微小間隔 |
| `\:` | 4/18 quad | 小間隔 |
| `\;` | 5/18 quad | 中間隔 |
| `\!` | -3/18 quad | 負の間隔 |
| `\quad` | 1 em | 単語間隔 |
| `\qquad` | 2 em | 大きな間隔 |

**例**:
```latex
\[
\int\!\!\!\int f(x, y) \, dx \, dy
\quad \text{vs} \quad
\iint f(x, y) \, dx \, dy
\]
```

### resizegather パッケージ（大きな数式のダウンスケーリング）

```latex
\usepackage{resizegather}

\begin{gather*}
  % 自動で行幅に収まるようスケーリング
  \text{very long equation...}
\end{gather*}
```

---

## 8. 主要数式記号表

### 関係記号

| 記号 | コマンド | 記号 | コマンド |
|-----|---------|-----|---------|
| = | `=` | ≠ | `\neq` |
| < | `<` | > | `>` |
| ≤ | `\leq` or `\le` | ≥ | `\geq` or `\ge` |
| ≪ | `\ll` | ≫ | `\gg` |
| ≈ | `\approx` | ≃ | `\simeq` |
| ≡ | `\equiv` | ∼ | `\sim` |
| ∈ | `\in` | ∉ | `\notin` |
| ⊂ | `\subset` | ⊃ | `\supset` |
| ⊆ | `\subseteq` | ⊇ | `\supseteq` |
| ∝ | `\propto` | ⊥ | `\perp` |

### 二項演算子

| 記号 | コマンド | 記号 | コマンド |
|-----|---------|-----|---------|
| + | `+` | - | `-` |
| × | `\times` | ÷ | `\div` |
| ± | `\pm` | ∓ | `\mp` |
| · | `\cdot` | ∗ | `\ast` |
| ⊕ | `\oplus` | ⊗ | `\otimes` |
| ∪ | `\cup` | ∩ | `\cap` |
| ∧ | `\wedge` or `\land` | ∨ | `\vee` or `\lor` |

### 矢印記号

| 記号 | コマンド | 記号 | コマンド |
|-----|---------|-----|---------|
| → | `\to` or `\rightarrow` | ← | `\leftarrow` |
| ⇒ | `\Rightarrow` | ⇐ | `\Leftarrow` |
| ⇔ | `\Leftrightarrow` | ↦ | `\mapsto` |
| ⇌ | `\rightleftharpoons` | ↗ | `\nearrow` |

### ギリシャ文字

| 小文字 | コマンド | 大文字 | コマンド |
|-------|---------|-------|---------|
| α | `\alpha` | Α | `A` |
| β | `\beta` | Β | `B` |
| γ | `\gamma` | Γ | `\Gamma` |
| δ | `\delta` | Δ | `\Delta` |
| ε | `\epsilon` | Ε | `E` |
| θ | `\theta` | Θ | `\Theta` |
| λ | `\lambda` | Λ | `\Lambda` |
| μ | `\mu` | Μ | `M` |
| π | `\pi` | Π | `\Pi` |
| σ | `\sigma` | Σ | `\Sigma` |
| φ | `\phi` | Φ | `\Phi` |
| ω | `\omega` | Ω | `\Omega` |

**バリエーション**:
- `\varepsilon` (ε), `\varphi` (φ), `\vartheta` (θ), `\varpi` (ϖ), `\varrho` (ϱ), `\varsigma` (ς)

---

## 9. 数式フォント

### mathalpha パッケージ（数式アルファベット簡易設定）

```latex
\usepackage[cal=boondoxo, bb=ams, frak=euler]{mathalpha}

% オプション:
% cal: カリグラフィ体（boondoxo, pxtx, esstix 等）
% bb: 黒板太字（ams, px, boondox 等）
% frak: フラクトゥール体（euler, esstix 等）
% scr: スクリプト体
```

### unicode-math パッケージ（Unicode数式フォント）

**XeLaTeX / LuaLaTeX 専用**

```latex
\usepackage{unicode-math}

% 数式フォント設定
\setmathfont{Latin Modern Math}
\setmathfont{XITS Math}
\setmathfont{TeX Gyre Pagella Math}
\setmathfont{Libertinus Math}

% 個別フォント機能
\setmathfont[range=\mathbb]{TeX Gyre Termes Math}  % 黒板太字のみ
```

### テキスト+数式フォントペアリング推奨表

| テキストフォント | 数式パッケージ | エンジン | 備考 |
|---------------|-------------|---------|------|
| **Computer Modern** | `amsmath`（標準） | pdfLaTeX | LaTeX デフォルト |
| **Latin Modern** | `lmodern` | 全エンジン | CM の OTF 版 |
| **EB Garamond** | `garamondx` + `newtxmath` | pdfLaTeX | Garamond風数式 |
| **Crimson Pro / Cochineal** | `cochineal` | pdfLaTeX | 統合対応 |
| **Libertinus** | `libertinus-otf` | XeLaTeX/LuaLaTeX | OTF統合 |
| **Palatino** | `mathpazo` or `newpxmath` | pdfLaTeX | 古典的組み合わせ |
| **Times** | `mathptmx` or `newtxmath` | pdfLaTeX | ビジネス標準 |
| **Charter** | `mathdesign[charter]` | pdfLaTeX | Charter専用 |
| **Concrete** | `euler` | pdfLaTeX | Knuth組み合わせ |
| **Fira Sans** | `newtxmath` or `firamath` | pdfLaTeX | Sans数式 |
| **XITS** | `unicode-math` + XITS Math | XeLaTeX/LuaLaTeX | Times風Unicode |
| **STIX Two** | `unicode-math` + STIX Two Math | XeLaTeX/LuaLaTeX | 科学技術標準 |

**設定例**:
```latex
% pdfLaTeX: Palatino + 数式
\usepackage{mathpazo}

% または newtxtext/newtxmath（より新しい）
\usepackage{newpxtext, newpxmath}

% XeLaTeX/LuaLaTeX: Libertinus統合
\usepackage{unicode-math}
\setmainfont{Libertinus Serif}
\setmathfont{Libertinus Math}
```

---

## 10. 数式フォントスタイル

### 標準スタイル

| コマンド | 説明 | 例 |
|---------|------|-----|
| `\mathrm{...}` | Roman（立体） | $\mathrm{ABC}$ |
| `\mathit{...}` | Italic（斜体） | $\mathit{ABC}$ |
| `\mathbf{...}` | Bold（太字） | $\mathbf{ABC}$ |
| `\mathsf{...}` | Sans Serif | $\mathsf{ABC}$ |
| `\mathtt{...}` | Typewriter | $\mathtt{ABC}$ |
| `\mathcal{...}` | Calligraphic | $\mathcal{ABC}$ |
| `\mathbb{...}` | Blackboard Bold | $\mathbb{ABC}$ |
| `\mathfrak{...}` | Fraktur | $\mathfrak{ABC}$ |

### amsmath 追加スタイル

```latex
\usepackage{amsmath, amssymb}

\boldsymbol{\alpha}  % ギリシャ文字太字
\pmb{x}              % Poor man's bold（疑似太字）
```

---

## ベストプラクティス

### 数式環境の選択

1. **単一数式**: `equation`
2. **複数行・整列あり**: `align`
3. **複数行・整列なし**: `gather`
4. **長い数式の折り返し**: `multline`
5. **複数列**: `align` or `alignat`

### 番号付けの原則

- **重要な式のみ番号**: `*` 版環境を活用
- **参照する式は必ずラベル**: `\label{eq:name}`
- **サブ番号**: 関連する式群は `subequations` でグループ化

### 間隔調整

- **デフォルトを信頼**: LaTeX の自動間隔は通常最適
- **調整が必要な場合のみ**: `\,`, `\!`, `\quad` を使用
- **過剰な間隔調整を避ける**: 可読性低下の原因

### 演算子

- **既存演算子を使用**: `\sin`, `\log` 等
- **カスタム演算子**: `\DeclareMathOperator` で定義
- **演算子スタイル**: `\mathrm` ではなく `\operatorname` 推奨

### フォント

- **統一性**: テキストと数式フォントは調和させる
- **Unicode エンジン**: `unicode-math` + OpenType Math フォント
- **pdfLaTeX**: パッケージの組み合わせ（上記推奨表参照）
