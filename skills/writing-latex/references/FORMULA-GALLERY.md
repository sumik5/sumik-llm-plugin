# 数式ギャラリー・実践ガイド

数式作成の実践的なガイドです。複雑な数式の構築手順、実用的な数式例、多行数式環境の選択フローチャート、可換図式の記法を解説します。

---

## 数式構築の手順（ステップ・バイ・ステップ）

複雑な数式は一度に書こうとせず、小さな部品を段階的に組み立てます。以下は8ステップで複雑な数式を構築する実例です。

### 最終目標の数式

```latex
\[
\sum_{i = 1}^{ \left[ \frac{n}{2} \right] }
\binom{ x_{i, i + 1}^{i^{2}} }
{ \left[ \frac{i + 3}{3} \right] }
\frac{ \sqrt{ \mu(i)^{ \frac{3}{2}} (i^{2} - 1) } }
{\sqrt[3]{\rho(i)-2} + \sqrt[3]{\rho(i) - 1}}
\]
```

### ステップ1: ブラケットと分数

まず最も内側の `[n/2]` から始めます。

```latex
$\left[ \frac{n}{2} \right]$
```

### ステップ2: 総和記号

ステップ1の結果を上付き添字にコピー&ペースト：

```latex
\[
\sum_{i = 1}^{ \left[ \frac{n}{2} \right] }
\]
```

### ステップ3: 二項係数の構成要素

二項係数の分子と分母を別々に作成：

```latex
\[
x_{i, i + 1}^{i^{2}}\qquad\left[ \frac{i + 3}{3} \right]
\]
```

- `\qquad`: 一時的な確認用スペース（後で削除）

### ステップ4: 二項係数の組み立て

ステップ3の2つの式を `\binom` でまとめます：

```latex
\[
\binom{x_{i,i + 1}^{i^{2}}}{\left[\frac{i + 3}{3}\right]}
\]
```

### ステップ5: 平方根の下の式

分子の複雑な部分を構築：

```latex
$\mu(i)^{ \frac{3}{2} } (i^{2} - 1)$
```

次に平方根で囲みます：

```latex
$\sqrt{ \mu(i)^{ \frac{3}{2} } (i^{2} - 1) }$
```

### ステップ6: 立方根

分母の2つの立方根を作成：

```latex
$\sqrt[3]{ \rho(i) - 2 }$ $\sqrt[3]{ \rho(i) - 1 }$
```

### ステップ7: 分数の組み立て

ステップ5と6をコピー&ペーストして分数にします：

```latex
\[
\frac{ \sqrt{ \mu(i)^{ \frac{3}{2}} (i^{2} -1) } }
{ \sqrt[3]{\rho(i) - 2} + \sqrt[3]{\rho(i) - 1} }
\]
```

### ステップ8: 全体の組み立て

すべてのパーツをコピー&ペーストして1つの数式にまとめます：

```latex
\[
\sum_{i = 1}^{ \left[ \frac{n}{2} \right] }
\binom{ x_{i, i + 1}^{i^{2}} }
{ \left[ \frac{i + 3}{3} \right] }
\frac{ \sqrt{ \mu(i)^{ \frac{3}{2}} (i^{2} - 1) } }
{\sqrt[3]{\rho(i)-2} + \sqrt[3]{\rho(i) - 1}}
\]
```

### 読みやすいソースファイルのためのTips

**階層的インデント**: 数式の構造を反映してインデントを使う

```latex
\[
\sum_{i = 1}^{ \left[ \frac{n}{2} \right] }      % 最外層
  \binom{ x_{i, i + 1}^{i^{2}} }                  % 第2層
        { \left[ \frac{i + 3}{3} \right] }        % 第2層
  \frac{ \sqrt{ \mu(i)^{ \frac{3}{2}} (i^{2} - 1) } }  % 第2層
       {\sqrt[3]{\rho(i)-2} + \sqrt[3]{\rho(i) - 1}}   % 第2層
\]
```

**スペースで括弧を強調**: テキストエディタの括弧マッチ機能と併用

**複数行に分割**: 長い部分式は改行して見やすくする

**避けるべき記法**:

```latex
% 悪い例: 圧縮しすぎて読めない
\[\sum_{i=1}^{\left[\frac{n}{2}\right]}\binom{x_{i,i+1}^{i^{2}}}{\left[\frac{i+3}{3}\right]}\frac{\sqrt{\mu(i)^{\frac{3}{2}}(i^{2}-1)}}{\sqrt[3]{\rho(i)-2}+\sqrt[3]{\rho(i)-1}}\]
```

**エラー例**: 括弧の対応ミス

```latex
% 誤り: \frac{3}{2 の後が }}} になっている（正しくは }}）
\frac{\sqrt{\mu(i)^{\frac{3}{2}}}(i^{2}-1)}}{\sqrt[3]{\rho(i)-2}+\sqrt[3]{\rho(i)-1}}
```

---

## 数式ギャラリー

実用的な数式例20種を掲載します。各数式のLaTeXソースコードと使用テクニックを解説します。

### 必要なパッケージ

これらの例を試す場合、以下のパッケージをプリアンブルに追加してください：

```latex
\usepackage{amssymb,latexsym}
```

---

### 数式例 1: 集合値関数

```latex
\[
x \mapsto \{ c \in C \mid c \leq x \}
\]
```

**使用テクニック**:
- `\mapsto`: 写像記号（→の代わり）
- `\mid`: 集合の条件記号（縦棒）
- `\leq`: 小なりイコール

---

### 数式例 2: Fraktur文字と大型演算子

```latex
\[
\left| \bigcup ( I_{j} \mid j \in J ) \right| < \mathfrak{m}
\]
```

**使用テクニック**:
- `\left|` ... `\right|`: 伸縮する絶対値記号
- `\bigcup`: 大型和集合記号
- `\mathfrak{m}`: Fraktur文字（ドイツ文字）

---

### 数式例 3: テキスト挿入

```latex
\[
A = \{ x \in X \mid x \in X_{i},
\text{ for some $i \in I$} \}
\]
```

**使用テクニック**:
- `\text{ ... }`: 数式内に通常のテキストを挿入
- テキスト前後にスペースを明示的に挿入
- `\text` 内で `$ ... $` を使えば数式を埋め込める

---

### 数式例 4: 論理構造を反映したスペース

```latex
\[
\langle a_{1}, a_{2} \rangle \leq
\langle a'_{1}, a'_{2}\rangle \qquad \text{if{f}}
\qquad a_{1} < a'_{1} \quad \text{or}
\quad a_{1} = a'_{1} \text{ and } a_{2} \leq a'_{2}
\]
```

**使用テクニック**:
- `\qquad`: 大きな水平スペース（論理グループ間）
- `\quad`: 中程度のスペース
- `\text{if{f}}`: 合字（ligature）を防ぐため `{f}` を使用

---

### 数式例 5: ギリシャ文字と否定記号

```latex
\[
\Gamma_{u'} = \{\gamma \mid \gamma < 2\chi,\ B_{\alpha}
\nsubseteq u', \ B_{\gamma} \subseteq u' \}
\]
```

**使用テクニック**:
- `\Gamma`, `\gamma`, `\chi`, `\alpha`: ギリシャ文字（大文字・小文字）
- `\nsubseteq`: 部分集合でない（否定記号）
- `\␣`（`\ `）: テキスト・数式共用のスペース挿入コマンド

---

### 数式例 6: Blackboard Bold（黒板太字）

```latex
\[
A = B^{2} \times \mathbb{Z}
\]
```

**使用テクニック**:
- `\mathbb{Z}`: 黒板太字（整数集合などに使用）
- `\times`: 直積記号

---

### 数式例 7: 伸縮括弧と上付き・下付きの配置

```latex
\[
y^C \equiv z \vee \bigvee_{ i \in C } \left[ s_{i}^{C}
\right] \pmod{ \Phi }
\]
```

**使用テクニック**:
- `\left[` ... `\right]`: 伸縮する角括弧
- `\bigvee`: 大型論理和記号
- `s_{i}^{C}`: 上付き・下付きが同じ位置に配置される
- `\pmod{...}`: 合同式の法表示

---

### 数式例 8: 複雑な合同式

```latex
\[
y \vee \bigvee ( [B_{\gamma}] \mid \gamma
\in \Gamma ) \equiv z \vee \bigvee ( [B_{\gamma}]
\mid \gamma \in \Gamma ) \pmod{ \Phi^{x} }
\]
```

**使用テクニック**:
- 複数の `\bigvee` を配置
- 条件部分に `\mid` を使用

---

### 数式例 9: \nolimitsで添字を制御

```latex
\[
f(\mathbf{x}) =
\bigvee\nolimits_{\!\mathfrak{m}}
\left(
\bigwedge\nolimits_{\mathfrak{m}}
( x_{j} \mid j \in I_{i} )
\mid i < \aleph_{\alpha}
\right)
\]
```

**使用テクニック**:
- `\nolimits`: 大型演算子の添字を横に配置（デフォルトは下）
- `\!`: 負のスペース（記号を近づける）
- `\mathbf{x}`: 太字ベクトル
- `\aleph_{\alpha}`: アレフ記号

---

### 数式例 10: 空の左デリミタ

```latex
\[
\left. \widehat{F}(x) \right|_{a}^{b}
= \widehat{F}(b) - \widehat{F}(a)
\]
```

**使用テクニック**:
- `\left.`: 空のデリミタ（`\right|` とバランスを取るために必須）
- `\widehat{F}`: 広いハット記号
- `\right|_{a}^{b}`: 右側の縦棒に添字

---

### 数式例 11: \undersetと\oversetで新しい記号

```latex
\[
u \underset{\alpha}{+} v \overset{1}{\thicksim} w
\overset{2}{\thicksim} z
\]
```

**使用テクニック**:
- `\underset{\alpha}{+}`: `+` の下に `α` を配置（新しい演算子記号）
- `\overset{1}{\thicksim}`: `~` の上に `1` を配置（新しい関係記号）
- これらは適切なスペーシングを持つ新しい数学記号として扱われる

---

### 数式例 12: 小サイズの太字

```latex
\[
f(x) \overset{ \mathbf{def} }{ = } x^{2} - 1
\]
```

**使用テクニック**:
- `\overset{\mathbf{def}}{=}`: 等号の上に小さく「def」を太字表示
- 定義を表す記法

---

### 数式例 13: 多重アクセント

```latex
\[
\overbrace{a\spcheck + b\spcheck + \dots + z\spcheck}^
{\breve{\breve{n}}}
\]
```

**使用テクニック**:
- `\overbrace{...}^{...}`: 式の上に括弧を表示
- `\spcheck`: チェック記号（amsxtraパッケージが必要）
- `\breve{\breve{n}}`: 二重のブレーヴ記号

---

### 数式例 14: 行列式（vmatrix / Vmatrix）

```latex
\[
\begin{vmatrix}
a + b + c & uv\\
a + b & c + d
\end{vmatrix}
= 7
\]
```

```latex
\[
\begin{Vmatrix}
a + b + c & uv\\
a + b & c + d
\end{Vmatrix}
= 7
\]
```

**使用テクニック**:
- `vmatrix`: 縦棒デリミタ `| ... |` 付き行列
- `Vmatrix`: 二重縦棒デリミタ `|| ... ||` 付き行列
- `&`: カラムの区切り
- `\\`: 行の区切り

---

### 数式例 15: 太字記号とハット付き変数

```latex
\[
\boldsymbol{\alpha}^2\sum_{j \in \mathbf{N}} b_{ij}
\hat{y}_{j} = \sum_{j \in \mathbf{N}}
b^{(\lambda)}_{ij}\hat{y}_{j}
+ (b_{ii} - \lambda_{i}) \hat{y}_{i} \hat{y}
\]
```

**使用テクニック**:
- `\boldsymbol{\alpha}`: ギリシャ文字を太字に
- `\mathbf{N}`: 太字のアルファベット（集合記号）
- `\hat{y}`: ハット付き変数

---

### 数式例 16: デリミタのサイズ調整

```latex
% 自動調整版（サイズが大きすぎる例）
\[
\left( \prod^n_{j = 1} \hat{ x }_{j} \right) H_{c}=
\frac{1}{2} \hat{k}_{ij} \det \hat{ \mathbf{K} }(i|i)
\]
```

```latex
% 手動調整版（推奨）
\[
\biggl( \prod^n_{ j = 1} \hat{ x }_{j} \biggr)
H_{c} = \frac{1}{2}\hat{ k }_{ij}
\det \widehat{ \mathbf{K} }(i|i)
\]
```

**使用テクニック**:
- `\left(` ... `\right)`: 自動的にサイズ調整（時に過度に大きくなる）
- `\biggl(` ... `\biggr)`: 手動で「big」サイズ指定（推奨）
- `\widehat{K}`: 広いハット記号（通常の `\hat` より幅広）

---

### 数式例 17: オーバーラインとバーの使い分け

```latex
\[
\det \mathbf{K} (t = 1, t_{1}, \dots, t_{n}) =
\sum_{I \in \mathbf{n} }(-1)^{|I|} \prod_{i \in I}t_{i}
\prod_{j \in I} (D_{j} + \lambda_{j} t_{j})
\det \mathbf{A}^{(\lambda)}
(\overline{I} | \overline{I}) = 0
\]
```

**使用テクニック**:
- `\overline{I}`: 集合の補集合を表す上線（推奨）
- `\bar{I}`: 短い上線（個別の変数向き）
- `|I|`: 集合の要素数

---

### 数式例 18: \|記号とlim

```latex
\[
\lim_{(v, v') \to (0, 0)}
\frac{H(z + v) - H(z + v') - BH(z)(v - v')}
{\| v - v' \|} = 0
\]
```

**使用テクニック**:
- `\|`: ノルム記号（`||`）
- `\lim_{...}`: 極限記号

---

### 数式例 19: カリグラフィック数学アルファベット

```latex
\[
\int_{\mathcal{D}} | \overline{\partial u} |^{2}
\Phi_{0}(z) e^{\alpha |z|^2}
\geq c_{4} \alpha \int_{\mathcal{D}} |u|^{2}\Phi_{0}
e^{\alpha |z|^{2}}
+ c_{5} \delta^{-2} \int_{A} |u|^{2}
\Phi_{0} e^{\alpha |z|^{2}}
\]
```

**使用テクニック**:
- `\mathcal{D}`: カリグラフィック文字（領域記号に使用）
- `\overline{\partial u}`: 偏微分記号の上線

---

### 数式例 20: 複雑な行列と\hdotsfor

```latex
\[
\mathbf{A} =
\begin{pmatrix}
\dfrac{\varphi \cdot X_{n, 1}} {\varphi_{1} \times
\varepsilon_{1}} & (x + \varepsilon_{2})^{2}
& \cdots & (x + \varepsilon_{n - 1})^{n - 1}
& (x + \varepsilon_{n})^{n}\\[10pt]
\dfrac{\varphi \cdot X_{n, 1}} {\varphi_{2} \times
\varepsilon_{1}} & \dfrac{\varphi \cdot X_{n, 2}}
{\varphi_{2} \times \varepsilon_{2}} & \cdots &
(x + \varepsilon_{n - 1})^{n - 1}
& (x + \varepsilon_{n})^{n}\\
\hdotsfor{5}\\
\dfrac{\varphi \cdot X_{n, 1}} {\varphi_{n} \times
\varepsilon_{1}} & \dfrac{\varphi \cdot X_{n, 2}}
{\varphi_{n} \times \varepsilon_{2}} & \cdots
& \dfrac{\varphi \cdot X_{n, n - 1}} {\varphi_{n}
\times \varepsilon_{n - 1}} &
\dfrac{\varphi\cdot X_{n, n}}
{\varphi_{n} \times \varepsilon_{n}}
\end{pmatrix}
+ \mathbf{I}_{n}
\]
```

**使用テクニック**:
- `\dfrac`: ディスプレイ形式の分数（`\frac`より大きめ）
- `\hdotsfor{5}`: 5カラムにまたがる点線
- `\\[10pt]`: 行間を10pt広げる（分数が密接しすぎるのを防ぐ）
- `\cdots`: 中央揃えの点（行列では推奨）

---

## 多行数式 Visual Guide

多行数式環境の選択フローチャートと分割ルールです。

### 環境選択フローチャート

#### 調整済みカラム（Adjusted Columns）

- **gather**: 1カラム、すべての行が中央揃え
  ```latex
  \begin{gather}
  x_{1} x_{2} + x_{1}^{2} x_{2}^{2} + x_{3},\\
  x_{1} x_{3} + x_{1}^{2} x_{3}^{2} + x_{2},\\
  x_{1} x_{2} x_{3}
  \end{gather}
  ```

- **multline**: 1つの長い数式を複数行に分割（1行目は左揃え、最終行は右揃え、中間行は中央揃え）
  ```latex
  \begin{multline}
  (x_{1} x_{2} x_{3} x_{4} x_{5} x_{6})^{2}\\
  + (y_{1} y_{2} y_{3} y_{4} y_{5})^{2}\\
  + (z_{1} z_{2} z_{3} z_{4})^{2}
  \end{multline}
  ```

#### 整列カラム（Aligned Columns）

- **align**: 複数カラム、指定位置で整列（最も汎用的）
  ```latex
  \begin{align}
  f(x) &= x + yz    & g(x) &= x + y + z\\
  h(x) &= xy + xz + yz & k(x) &= (x+y)(x+z)(y+z)
  \end{align}
  ```

- **alignat**: 複数カラム、カラム間スペースを制御
  ```latex
  \begin{alignat}{2}
  a_{11}x_{1} + a_{12}x_{2} + a_{13}x_{3} &= y_{1}\\
  a_{21}x_{1} + a_{22}x_{2} + a_{24}x_{4} &= y_{2}\\
  a_{31}x_{1} + a_{33}x_{3} + a_{34}x_{4} &= y_{3}
  \end{alignat}
  ```

- **flalign**: 複数カラム、ページ全幅を使用（最も広く整列）
  ```latex
  \begin{flalign}
  f(x) &= x + yz    & g(x) &= x + y + z\\
  h(x) &= xy + xz + yz & k(x) &= (x+y)(x+z)(y+z)
  \end{flalign}
  ```

### 補助数学環境（Subsidiary Math Environments）

主環境の中で使用し、「大きな数学記号」として機能します。

#### 調整済み補助環境

- **matrix**: 括弧なし行列
  ```latex
  \begin{matrix}
  1 & 0 & 0\\
  0 & 1 & 0\\
  0 & 0 & 1
  \end{matrix}
  ```

- **cases**: 場合分け（左に大括弧）
  ```latex
  \begin{cases}
  -x^2, & \text{if } x < 0;\\
  \alpha + x, & \text{if } 0 \leq x \leq 1;\\
  x^2, & \text{otherwise.}
  \end{cases}
  ```

- **array**: 各カラムを独立に調整（`{ccc}` = center, center, center）
  ```latex
  \begin{array}{lcr}
  1 & 100 & 115\\
  201 & 0 & 1
  \end{array}
  ```

#### 整列補助環境

- **split**: 1カラム、整列指定（通常はequation内で使用）
  ```latex
  \begin{equation}
  \begin{split}
  0 = \langle \dots, d, \dots \rangle
    \wedge \langle \dots, a, \dots \rangle\\
  \equiv \langle \dots, a, \dots \rangle \pmod{\Theta}
  \end{split}
  \end{equation}
  ```

- **aligned**: align環境と同様だが補助環境として機能

- **gathered**: gather環境と同様だが補助環境として機能

### 数式分割のルール

長い数式を複数行に分割する際の基本原則：

1. **分割位置**:
   - 二項関係（`=`, `<`, `\equiv` など）の**前**で分割
   - 二項演算（`+`, `-`, `\times` など）の**前**で分割

2. **演算子の扱い**:
   - 行頭が `+` または `-` の場合は `{}+` または `{}-` と記述
   - これにより正しいスペーシングが確保される

   ```latex
   \begin{multline}
   x_{1} + y_{1}\\
   {}+ z_{1}  % 行頭の+は{}+と記述
   \end{multline}
   ```

3. **括弧内での分割時のインデント**:
   - 括弧内で分割する場合、次の行は開き括弧の右側にインデント

   ```latex
   f(x, y, z, u) = [(x + y + z) \times (x + y + z - 1)\\
                   \times (x + y + z - u) \times (x + y + z + u)]
   ```

4. **サブフォーミュラのルール**:
   - 各サブフォーミュラ（`\\` で区切られた部分）は独立してタイプセット可能でなければならない
   - 例: `\left(` と `\right)` は同じサブフォーミュラ内になければならない

### 番号付けとタグ

- **各行の番号**: デフォルトで各行に番号が付く
- **番号抑制**: `\notag` を行末（`\\` の前）に記述
- **カスタムタグ**: `\tag{X}` で任意のタグを設定
- **番号なし環境**: `gather*`, `align*`, `multline*` など（`*` 付き）
- **グループ番号**: 複数式に共通の番号を付ける場合は `\tag{\ref{...}a}` などを使用

---

## 可換図式（amscd）

`amscd`パッケージの`CD`環境で簡単な可換図式を作成します。

### 必要なパッケージ

```latex
\usepackage{amscd}
```

### 基本構文

可換図式は「水平行」と「垂直行」で構成されます。

#### 水平行の矢印

| 記法 | 意味 |
|------|------|
| `@>>>` | 右向き伸縮矢印 |
| `@<<<` | 左向き伸縮矢印 |
| `@=` | 等号（伸縮） |
| `@.` | 空白（矢印なし） |

#### 垂直行の矢印

| 記法 | 意味 |
|------|------|
| `@VVV` | 下向き伸縮矢印 |
| `@AAA` | 上向き伸縮矢印 |
| `@\|` または `@\vert` | 二重縦線 |
| `@.` | 空白（矢印なし） |

### ラベル付き矢印

**水平矢印**:
- 上のラベル: 最初の `>` または `<` の後
- 下のラベル: 2番目と3番目の間

例: `@>H_{1}>>` → 上に `H₁` を表示

**垂直矢印**:
- 左のラベル: 最初の `V` または `A` の後
- 右のラベル: 2番目と3番目の間

例: `@VP_{c,3}VV` → 左に `P_{c,3}` を表示

### 実践例1: 基本図式

```latex
\[
\begin{CD}
A @>>> B\\
@VVV @VVV\\
C @= D
\end{CD}
\]
```

**解説**:
- 1行目: `A → B`（水平矢印）
- 2行目: 垂直矢印（AからC、BからD）
- 3行目: `C = D`（等号）

### 実践例2: ラベル付き矢印

```latex
\[
\begin{CD}
\mathbb{C} @>H_{1}>> \mathbb{C} @>H_{2}>>\mathbb{C}\\
@VP_{c,3}VV @VP_{\bar{c},3}VV @VVP_{-c,3}V\\
\mathbb{C} @>H_{1}>> \mathbb{C} @>H_{2}>> \mathbb{C}
\end{CD}
\]
```

**解説**:
- `@>H_{1}>>`: 上に `H₁` のラベルを持つ右矢印
- `@VP_{c,3}VV`: 左に `P_{c,3}` のラベルを持つ下矢印
- `@VVP_{-c,3}V`: 右に `P_{-c,3}` のラベルを持つ下矢印

### 実践例3: 混合例（テキスト・二重線含む）

```latex
\[
\begin{CD}
A @>\log>> B @>>\text{bottom}> C
@= D @<<< E @<<< F\\
@V\text{one-one}VV @. @AA\text{onto}A @|\\
X @= Y @>>> Z @>>> U\\
@A\beta AA @AA\gamma A @VVV @VVV\\
D @>>> E @>>> H I
\end{CD}
\]
```

**解説**:
- `@.\`: 空白（矢印なし、位置調整用）
- `@|`: 二重縦線
- `\text{...}`: ラベルにテキストを使用
- `@A...AA`: 上向き矢印
- 複数の行にまたがる複雑な図式

### 高度な可換図式

より複雑な図式が必要な場合は、`tikz-cd`パッケージの使用を検討してください。`amscd`はシンプルな図式に最適化されています。

---

## 参考情報

- 数式の基本構文は [REFERENCE.md](./REFERENCE.md) を参照
- 高度な数学環境は [MATHEMATICS-ADVANCED.md](./MATHEMATICS-ADVANCED.md) を参照
- ギリシャ文字一覧は [MATH-SYMBOL-TABLES.md](./MATH-SYMBOL-TABLES.md) を参照
