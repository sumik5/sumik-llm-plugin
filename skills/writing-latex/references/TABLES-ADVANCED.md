# 高度なテーブル（Tabular Material）

LaTeXにおける高度なテーブル組版技術に関する包括的なリファレンス。

---

## 目次

1. [標準LaTeXテーブル環境の復習](#標準latexテーブル環境の復習)
2. [array パッケージ](#array-パッケージ)
3. [列幅の自動計算](#列幅の自動計算)
4. [マルチページテーブル](#マルチページテーブル)
5. [テーブルの色](#テーブルの色)
6. [罫線とスペーシング](#罫線とスペーシング)
7. [その他の拡張機能](#その他の拡張機能)
8. [テーブル内脚注](#テーブル内脚注)
9. [keyvaltable パッケージ](#keyvaltable-パッケージ)
10. [tabularray パッケージ](#tabularray-パッケージ)

---

## 標準LaTeXテーブル環境の復習

### tabular 環境

基本的なテーブル作成環境。

```latex
\begin{tabular}{列指定}
  セル1 & セル2 & セル3 \\
  セル4 & セル5 & セル6 \\
\end{tabular}
```

**基本的な列指定子：**

| 指定子 | 意味 |
|--------|------|
| `l` | 左揃え |
| `c` | 中央揃え |
| `r` | 右揃え |
| `p{幅}` | 指定幅のパラグラフ型（上揃え） |
| `\|` | 垂直罫線 |
| `@{テキスト}` | カラム間のスペースを指定テキストに置換 |

```latex
\begin{tabular}{|l|c|r|}
  \hline
  左揃え & 中央揃え & 右揃え \\
  \hline
  A & B & C \\
  \hline
\end{tabular}
```

### tabular* 環境

全体幅を指定できるバリエーション。

```latex
\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lcc}
  列1 & 列2 & 列3 \\
\end{tabular*}
```

### tabbing 環境

タブストップベースのアライメント（プログラムコード向き）。

```latex
\begin{tabbing}
  左端 \= タブ位置1 \= タブ位置2 \kill
  A \> B \> C \\
  X \> Y \> Z \\
\end{tabbing}
```

---

## array パッケージ

`tabular` 環境を大幅に拡張する基盤パッケージ。他の多くのテーブルパッケージが依存している。

```latex
\usepackage{array}
```

### \\ コマンドの挙動制御

`array` パッケージは `\\` の挙動を改善し、オプション引数で垂直スペースを追加できる。

```latex
\begin{tabular}{lll}
  行1-1 & 行1-2 & 行1-3 \\[2ex]  % 2ex の追加スペース
  行2-1 & 行2-2 & 行2-3 \\
\end{tabular}
```

### 新しい列指定子

**array パッケージが追加する列指定子：**

| 指定子 | 意味 |
|--------|------|
| `m{幅}` | 指定幅のパラグラフ型（垂直中央揃え） |
| `b{幅}` | 指定幅のパラグラフ型（下揃え） |
| `>{宣言}` | 列の前に挿入されるコマンド |
| `<{宣言}` | 列の後に挿入されるコマンド |
| `!{テキスト}` | `\|` の代わり（垂直スペースを消費しない） |

### プリアンブル指定子の例

**列の前後に書式を挿入：**

```latex
% 数値列を自動的にボールドに
\begin{tabular}{l >{\bfseries}r}
  項目 & 値 \\
  価格 & 1000 \\
  税込 & 1100 \\
\end{tabular}
```

**数式モードを自動適用：**

```latex
\begin{tabular}{l >{$}c<{$}}
  変数 & 式 \\
  x & x^2 + y^2 \\
  y & \sin(\theta) \\
\end{tabular}
```

**カラム間のスペースをカスタマイズ：**

```latex
% 通常のスペースを削除してカスタムスペースを挿入
\begin{tabular}{@{}l@{ = }r@{}}
  A & 1 \\
  B & 2 \\
\end{tabular}
% 出力: "A = 1"（通常の列間スペースなし）
```

**配列（array）環境にも適用：**

```latex
\[
\left(
\begin{array}{>{$}l<{$} @{} >{{}={}}l}
  x + y & 10 \\
  z & 5
\end{array}
\right)
\]
```

### 新しい列指定子の定義

独自の列指定子を定義できる。

```latex
\newcolumntype{指定子}[引数数]{定義}

% 例: 固定幅の中央揃えカラム
\newcolumntype{C}[1]{>{\centering\arraybackslash}p{#1}}

\begin{tabular}{C{3cm}C{3cm}}
  セル1 & セル2 \\
\end{tabular}

% 例: 通貨フォーマット（右揃え+ボールド）
\newcolumntype{€}{>{\bfseries}r<{~\texteuro}}

\begin{tabular}{l€}
  価格 & 99 \\
  税 & 19 \\
\end{tabular}
% 出力: "99 €", "19 €"
```

**注意：** `\centering` などのコマンドは `\\` の挙動に影響するため、`\arraybackslash` を追加する必要がある。

---

## 列幅の自動計算

### パッケージ比較表

| パッケージ | 列幅計算方法 | 環境名 | 最適用途 |
|-----------|------------|--------|----------|
| `tabular*` | 手動（`\extracolsep`） | `tabular*` | 単純な均等配置 |
| `tabularx` | X列を均等に拡張 | `tabularx` | 可変幅列が少数の場合 |
| `tabulary` | コンテンツ比率で自動計算 | `tabulary` | 自然な幅が望ましい場合 |
| `widetable` | テンプレート方式 | `widetable` | 複雑な再利用可能テーブル |
| `xltabular` | tabularx + longtable | `xltabular` | 長い可変幅テーブル |

---

### tabularx パッケージ

全体幅を指定し、`X` 列を自動的に拡張。

```latex
\usepackage{tabularx}

\begin{tabularx}{\textwidth}{lXX}
  項目 & 説明1（自動幅） & 説明2（自動幅） \\
  A & 長いテキスト... & さらに長いテキスト... \\
\end{tabularx}
```

**X列のカスタマイズ：**

```latex
% 中央揃えのX列
\newcolumntype{Y}{>{\centering\arraybackslash}X}

% 右揃えのX列
\newcolumntype{Z}{>{\raggedleft\arraybackslash}X}

\begin{tabularx}{\textwidth}{lYZ}
  項目 & 中央揃え & 右揃え \\
\end{tabularx}
```

**X列の比率指定：**

```latex
\usepackage{tabularx}

% 1:2の比率で2つのX列を配分
\begin{tabularx}{\textwidth}{lXX}
  \hline
  固定列 & X列（1倍） & X列（1倍） \\
  \hline
\end{tabularx}
```

---

### tabulary パッケージ

コンテンツに基づいて列幅を自動計算（より自然な幅）。

```latex
\usepackage{tabulary}

\begin{tabulary}{\textwidth}{LCR}
  左揃え自動幅 & 中央自動幅 & 右揃え自動幅 \\
  短い & ちょっと長めのテキスト & もっと長い... \\
\end{tabulary}
```

**列指定子：**

| 指定子 | 意味 |
|--------|------|
| `L` | 左揃え（自動幅） |
| `C` | 中央揃え（自動幅） |
| `R` | 右揃え（自動幅） |
| `J` | 両端揃え（自動幅） |

---

### tabular* vs tabularx vs tabulary の違い

**選択基準：**

| 状況 | 推奨 | 理由 |
|------|------|------|
| 均等な列幅が必要 | `tabularx` | X列が均等に拡張される |
| 自然な列幅バランス | `tabulary` | コンテンツ比率で自動調整 |
| 細かい制御が必要 | `tabular*` + `\extracolsep` | 手動で完全制御 |
| 列ごとに異なる幅比率 | カスタムX列（`tabularx`） | 新しい列型を定義 |

**実装例：**

```latex
% tabular* - 手動制御
\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lll}
  A & B & C \\
\end{tabular*}

% tabularx - 均等なX列
\begin{tabularx}{\textwidth}{lXX}
  A & B & C \\
\end{tabularx}

% tabulary - 自然な比率
\begin{tabulary}{\textwidth}{LCC}
  A & B & C \\
\end{tabulary}
```

---

### widetable パッケージ

`tabular*` の代替として、テンプレート方式で列幅を制御。

```latex
\usepackage{widetable}

\begin{widetable}{\textwidth}{lcr}
  \hline
  列1 & 列2 & 列3 \\
  \hline
\end{widetable}
```

---

## マルチページテーブル

### パッケージ比較表

| パッケージ | 基盤 | 主な特徴 | 制約 |
|-----------|------|---------|------|
| `supertabular` | `tabular` | シンプル、軽量 | フロート不可、キャプション位置制限 |
| `longtable` | 独自実装 | 強力、フロート統合 | 2-3回のコンパイル必要 |
| `xltabular` | `tabularx` + `longtable` | 自動列幅 + マルチページ | longtableの制約を継承 |

---

### supertabular パッケージ

基本的なマルチページテーブル。

```latex
\usepackage{supertabular}

\begin{supertabular}{lll}
  \hline
  列1 & 列2 & 列3 \\
  \hline
  % 多数の行...
\end{supertabular}
```

**ヘッダー・フッターの設定：**

```latex
\tablehead{%
  \hline
  列1 & 列2 & 列3 \\
  \hline
}
\tablefirsthead{%
  \hline
  列1 & 列2 & 列3 \\
  \hline
}
\tabletail{%
  \hline
  \multicolumn{3}{r}{\small 次ページに続く...} \\
}
\tablelasttail{%
  \hline
}

\begin{supertabular}{lll}
  % データ行...
\end{supertabular}
```

---

### longtable パッケージ

最も強力で広く使用されているマルチページテーブルパッケージ。

```latex
\usepackage{longtable}

\begin{longtable}{lll}
  \caption{長いテーブル} \label{tab:long} \\
  \hline
  列1 & 列2 & 列3 \\
  \hline
  \endfirsthead

  \multicolumn{3}{c}{{\tablename\ \thetable{} の続き}} \\
  \hline
  列1 & 列2 & 列3 \\
  \hline
  \endhead

  \hline
  \multicolumn{3}{r}{\small 次ページに続く...} \\
  \endfoot

  \hline
  \endlastfoot

  % データ行...
  行1 & データ & データ \\
  行2 & データ & データ \\
  % 多数の行...
\end{longtable}
```

**主要コマンド：**

- `\endfirsthead`: 最初のページのヘッダー終了
- `\endhead`: 以降のページのヘッダー終了
- `\endfoot`: 各ページのフッター終了
- `\endlastfoot`: 最後のページのフッター終了

**実用例（シンプル版）：**

```latex
\begin{longtable}{lp{8cm}r}
  \caption{研究データ一覧} \\
  \hline
  ID & 説明 & 値 \\
  \hline
  \endfirsthead

  \caption[]{（続き）} \\
  \hline
  ID & 説明 & 値 \\
  \hline
  \endhead

  \hline
  \endfoot

  001 & 実験データの詳細な説明... & 123 \\
  002 & さらなるデータ... & 456 \\
  % ...
\end{longtable}
```

---

### xltabular パッケージ

`tabularx` と `longtable` を統合（自動列幅 + マルチページ）。

```latex
\usepackage{xltabular}

\begin{xltabular}{\textwidth}{lXr}
  \caption{長くて幅可変なテーブル} \\
  \hline
  項目 & 説明（自動幅） & 値 \\
  \hline
  \endfirsthead

  \caption[]{（続き）} \\
  \hline
  項目 & 説明 & 値 \\
  \hline
  \endhead

  \hline
  \endfoot

  A & 長い説明テキスト... & 100 \\
  B & さらに長い説明... & 200 \\
  % 多数の行...
\end{xltabular}
```

---

### マルチページテーブルの問題と対策

**共通の問題：**

1. **フロートとの競合**: `longtable` はフロート環境ではないため、配置が固定される
2. **コンパイル回数**: `longtable` は列幅を正しく計算するために2-3回のコンパイルが必要
3. **ページ境界での分割**: 手動調整が必要な場合がある

**対策：**

```latex
% ページ境界での改行を禁止
\nopagebreak

% 特定行の前で改ページを推奨
\pagebreak[3]

% longtableの列幅を固定（再コンパイル不要）
\setlongtables  % （非推奨、通常は自動計算が望ましい）
```

---

## テーブルの色

### colortbl パッケージ

```latex
\usepackage[table]{xcolor}  % またはcolortbl

% 行全体の着色
\rowcolor{gray!30}

% 列全体の着色
\begin{tabular}{>{\columncolor{yellow!20}}l c r}
  列1 & 列2 & 列3 \\
\end{tabular}

% 個別セルの着色
\cellcolor{red!20}
```

**実用例：**

```latex
\usepackage[table]{xcolor}

\begin{tabular}{lcc}
  \hline
  \rowcolor{blue!20}
  項目 & 値1 & 値2 \\
  \hline
  A & 10 & 20 \\
  \rowcolor{gray!10}
  B & 15 & 25 \\
  C & 20 & 30 \\
  \hline
\end{tabular}
```

**交互に着色：**

```latex
\rowcolors{開始行}{奇数色}{偶数色}

\rowcolors{2}{white}{gray!10}
\begin{tabular}{lcc}
  \hline
  項目 & 値1 & 値2 \\
  \hline
  A & 10 & 20 \\
  B & 15 & 25 \\
  C & 20 & 30 \\
  \hline
\end{tabular}
```

---

## 罫線とスペーシング

### booktabs パッケージ

フォーマルなテーブル用の洗練された罫線。

```latex
\usepackage{booktabs}

\begin{tabular}{lcc}
  \toprule
  項目 & 値1 & 値2 \\
  \midrule
  A & 10 & 20 \\
  B & 15 & 25 \\
  C & 20 & 30 \\
  \bottomrule
\end{tabular}
```

**主要コマンド：**

| コマンド | 用途 | デフォルト太さ |
|---------|------|--------------|
| `\toprule` | 最上部の罫線 | 太い（0.08em） |
| `\midrule` | 中間の罫線 | 中太（0.05em） |
| `\bottomrule` | 最下部の罫線 | 太い（0.08em） |
| `\cmidrule{開始-終了}` | 部分的な罫線 | 中太 |
| `\addlinespace` | 行間スペース追加 | 調整可能 |

**部分的な罫線：**

```latex
\begin{tabular}{lccc}
  \toprule
  & \multicolumn{3}{c}{測定値} \\
  \cmidrule{2-4}
  項目 & A & B & C \\
  \midrule
  値1 & 10 & 15 & 20 \\
  値2 & 11 & 16 & 21 \\
  \bottomrule
\end{tabular}
```

**スペース調整：**

```latex
\setlength{\aboverulesep}{0.2ex}  % 罫線上のスペース
\setlength{\belowrulesep}{0.2ex}  % 罫線下のスペース

\begin{tabular}{lcc}
  \toprule
  項目 & 値1 & 値2 \\
  \midrule
  A & 10 & 20 \\
  \addlinespace[1ex]  % 追加スペース
  B & 15 & 25 \\
  \bottomrule
\end{tabular}
```

---

### boldline パッケージ

太い罫線（`booktabs` の代替）。

```latex
\usepackage{boldline}

\begin{tabular}{lcc}
  \hlineB{3}  % 3pt の太さ
  項目 & 値1 & 値2 \\
  \hlineB{2}
  A & 10 & 20 \\
  \hlineB{3}
\end{tabular}
```

---

### arydshln パッケージ

破線罫線。

```latex
\usepackage{arydshln}

\begin{tabular}{l:c:c}
  \hdashline
  項目 & 値1 & 値2 \\
  \hdashline
  A & 10 & 20 \\
  \hdashline
\end{tabular}
```

**コマンド：**
- `\hdashline`: 水平破線
- `\cdashline{開始-終了}`: 部分的な破線
- `:`: 垂直破線（列指定に使用）

---

### hhline パッケージ

水平・垂直線の結合を制御。

```latex
\usepackage{hhline}

\begin{tabular}{|l|c|c|}
  \hline
  項目 & 値1 & 値2 \\
  \hhline{|=|=|=|}  % 二重線
  A & 10 & 20 \\
  \hhline{~|-|-|}   % 最初の列をスキップ
  B & 15 & 25 \\
  \hline
\end{tabular}
```

**記法：**
- `=`: 二重線
- `-`: 単線
- `~`: 線なし
- `|`: 垂直線との交差

---

### bigstrut パッケージ

行間スペースを調整（セルごと）。

```latex
\usepackage{bigstrut}

\begin{tabular}{lcc}
  \hline
  項目\bigstrut[t] & 値1 & 値2\bigstrut[b] \\
  \hline
\end{tabular}
```

**オプション：**
- `[t]`: 上部スペース
- `[b]`: 下部スペース
- なし: 上下両方

---

### cellspace パッケージ

最小クリアランスを自動確保。

```latex
\usepackage{cellspace}
\setlength{\cellspacetoplimit}{4pt}
\setlength{\cellspacebottomlimit}{4pt}

\begin{tabular}{Sl Sc Sr}  % S接頭辞で有効化
  項目 & 値1 & 値2 \\
  A & 10 & 20 \\
\end{tabular}
```

---

## その他の拡張機能

### multirow パッケージ

垂直方向のセル結合。

```latex
\usepackage{multirow}

\begin{tabular}{lll}
  \hline
  \multirow{2}{*}{結合} & 行1 & データ1 \\
                        & 行2 & データ2 \\
  \hline
\end{tabular}
```

**構文：**
```latex
\multirow{行数}{幅}{内容}
```

- `行数`: 結合する行数
- `幅`: セル幅（`*` で自動）
- `内容`: 表示するテキスト

**multicolumn との併用：**

```latex
\begin{tabular}{llll}
  \hline
  \multirow{2}{*}{A} & \multicolumn{2}{c}{B} & C \\
                     & B1 & B2 & C \\
  \hline
\end{tabular}
```

---

### diagbox パッケージ

対角線でセルを分割。

```latex
\usepackage{diagbox}

\begin{tabular}{|l|c|c|}
  \hline
  \diagbox{行}{列} & 列1 & 列2 \\
  \hline
  行1 & A & B \\
  行2 & C & D \\
  \hline
\end{tabular}
```

**オプション：**

```latex
\diagbox[オプション]{左下}{右上}

% 例: 3分割
\diagbox[dir=NW]{左上}{中央}{右下}
```

---

### dcolumn パッケージ

小数点揃え。

```latex
\usepackage{dcolumn}
\newcolumntype{d}[1]{D{.}{.}{#1}}

\begin{tabular}{ld{3}}  % 小数点以下3桁
  項目 & 値 \\
  A & 12.3 \\
  B & 1.456 \\
  C & 123.45 \\
\end{tabular}
```

---

### siunitx パッケージ

科学技術向けの数値揃え（最も強力）。

```latex
\usepackage{siunitx}

\begin{tabular}{lS}  % S列で数値揃え
  項目 & {値（単位: mm)} \\
  \midrule
  A & 12.3 \\
  B & 1.456 \\
  C & 123.45 \\
\end{tabular}
```

**高度な設定：**

```latex
\begin{tabular}{
  l
  S[table-format=3.2]  % 整数3桁、小数2桁
  S[table-format=1.3e2]  % 科学記法
}
  項目 & {標準} & {科学記法} \\
  \midrule
  A & 12.34 & 1.23e-4 \\
  B & 123.45 & 9.87e2 \\
\end{tabular}
```

**オプション：**
- `table-format`: 数値フォーマット
- `table-number-alignment`: 揃え位置（`left`, `center`, `right`）
- `table-figures-integer`: 整数部桁数
- `table-figures-decimal`: 小数部桁数

---

### fcolumn パッケージ

金融テーブル向けの書式設定。

```latex
\usepackage{fcolumn}

\begin{tabular}{lF}  % F列で通貨揃え
  項目 & 金額 \\
  収入 & 1000.00 \\
  支出 & -250.50 \\
\end{tabular}
```

---

## テーブル内脚注

### minipage方式

```latex
\begin{table}
  \begin{minipage}{\textwidth}
    \begin{tabular}{ll}
      項目\footnote{脚注1} & 値\footnote{脚注2} \\
    \end{tabular}
  \end{minipage}
\end{table}
```

---

### threeparttable パッケージ

テーブルとノートを統合（推奨）。

```latex
\usepackage{threeparttable}

\begin{table}
  \begin{threeparttable}
    \caption{データ表}
    \begin{tabular}{ll}
      \toprule
      項目\tnote{a} & 値\tnote{b} \\
      \midrule
      A & 100 \\
      B & 200 \\
      \bottomrule
    \end{tabular}
    \begin{tablenotes}
      \item[a] 項目に関する注記
      \item[b] 値に関する注記
    \end{tablenotes}
  \end{threeparttable}
\end{table}
```

---

## keyvaltable パッケージ

データと書式を分離する key/value アプローチ。

```latex
\usepackage{keyvaltable}

% データ定義
\NewKeyValTable{mydata}{
  name=項目, value=値
}{
  row={name=A, value=10},
  row={name=B, value=20},
  row={name=C, value=30}
}

% テーブル生成
\ShowKeyValTable{mydata}{lc}
```

---

## tabularray パッケージ

最新の統合テーブルパッケージ（2020年代の新基準）。

### 基本使用法

```latex
\usepackage{tabularray}

\begin{tblr}{lcc}
  \hline
  項目 & 値1 & 値2 \\
  \hline
  A & 10 & 20 \\
  B & 15 & 25 \\
  \hline
\end{tblr}
```

### 主な特徴

- **統合アプローチ**: `tabularx`, `longtable`, `booktabs`, `multirow` などの機能を統合
- **一貫した構文**: key/value 方式
- **高いカスタマイズ性**: 行・列・セル単位で細かく制御

### 実用例

```latex
\begin{tblr}{
  colspec = {lXX},
  row{1} = {font=\bfseries, bg=blue!20},
  row{2-Z} = {bg=white, odd={bg=gray!10}},
  hlines, vlines
}
  項目 & 説明1 & 説明2 \\
  A & テキスト & テキスト \\
  B & テキスト & テキスト \\
  C & テキスト & テキスト \\
\end{tblr}
```

### マルチページ対応

```latex
\begin{longtblr}{
  caption = {長いテーブル},
  label = {tab:long}
}{lcc}
  \hline
  項目 & 値1 & 値2 \\
  \hline
  % 多数の行...
\end{longtblr}
```

---

## パッケージ選択ガイド

### 基本テーブル

| 目的 | 推奨パッケージ | 理由 |
|------|-------------|------|
| シンプルなテーブル | 標準 `tabular` | 追加パッケージ不要 |
| 拡張機能が必要 | `array` | 多くのパッケージの基盤 |
| モダンな統合環境 | `tabularray` | 最新の統合パッケージ |

### 列幅制御

| 状況 | 推奨 |
|------|------|
| 固定幅が決まっている | `p{幅}`, `m{幅}`, `b{幅}` |
| 全体幅に合わせて均等配分 | `tabularx` の `X` 列 |
| 自然な幅バランス | `tabulary` の `L/C/R/J` |
| 複雑な計算 | `tabularray` の `colspec` |

### マルチページ

| 状況 | 推奨 |
|------|------|
| シンプルなマルチページ | `supertabular` |
| 標準的なマルチページ | `longtable` |
| 自動列幅 + マルチページ | `xltabular` |
| モダンな実装 | `tabularray` の `longtblr` |

### 罫線スタイル

| 目的 | 推奨 |
|------|------|
| フォーマルな論文・書籍 | `booktabs` |
| 太い罫線 | `boldline` |
| 破線 | `arydshln` |
| 複雑な結合 | `hhline` |

### 数値揃え

| 用途 | 推奨 |
|------|------|
| 小数点揃え（シンプル） | `dcolumn` |
| 科学技術データ | `siunitx` の `S` 列 |
| 金融データ | `fcolumn` |

---

## まとめ

- **基盤は `array`**: ほとんどの拡張パッケージが依存
- **フォーマルには `booktabs`**: 垂直罫線を避け、水平罫線を適切に配置
- **マルチページは `longtable`**: 最も安定した実装
- **数値揃えは `siunitx`**: 科学技術文書の標準
- **統合環境は `tabularray`**: 新規プロジェクトでは積極的に検討
- **色の使用は控えめに**: 過度な着色は可読性を下げる
- **脚注は `threeparttable`**: テーブルとノートを適切に統合

---

## tabbing 環境（タブストップによるテキスト揃え）

`tabular` とは異なるアプローチで、タイプライタのタブストップを模倣して列揃えを行う。
**ページまたぎが可能**な点が `tabular` との最大の違い。

### 基本コマンド

| コマンド | 機能 |
|---------|------|
| `\=` | タブストップを設定（最初の行で設定するのが慣例） |
| `\>` | 次のタブストップへジャンプ |
| `\\` | 行末（改行） |
| `\kill` | この行を出力せずにタブストップの設定行として使用 |
| `\+` | 以降の行の左端を1タブストップ右にずらす |
| `\-` | `\+` の逆（1タブストップ左に戻す） |
| `\'` | 以降のテキストを現在のタブストップに右揃え |
| `` \` `` | テキストを右マージンに右揃え |

### 基本的な使い方

```latex
\begin{tabbing}
  \emph{Info:} \= Software \= : \= \LaTeX \\
  \>            Author  \> : \> Leslie Lamport \\
  \>            Website \> : \> www.latex-project.org
\end{tabbing}
```

最初の行の `\=` でタブストップ位置が確定し、以降の行で `\>` を使ってその位置にジャンプする。

### \kill を使ったタブストップの設定

テキストの幅に応じたタブストップを設定したい場合、`\kill` でダミー行を作成する。

```latex
\begin{tabbing}
  % この行はタブストップ設定用（出力されない）
  \= \verb|\textrm{...}| \= Declaration \= Example\kill
  % 実際の出力行
  \> \textbf{Command}    \> \textbf{Declaration} \> \textbf{Example}\\
  \> \verb|\textrm{...}| \> \verb|\rmfamily|      \> \rmfamily text\\
  \> \verb|\textsf{...}| \> \verb|\sffamily|      \> \sffamily text\\
  \> \verb|\texttt{...}| \> \verb|\ttfamily|      \> \ttfamily text
\end{tabbing}
```

`\kill` 行のテキスト幅がタブストップの位置を決定するため、最も幅の広い列内容を
ダミーテキストとして使用するとよい。

### tabbing の特徴と制限

**利点**:
- ページをまたいで継続できる（`longtable` と同様のユースケース）
- シンプルなテキスト整列に素早く使える
- 特別なパッケージが不要

**制限**:
- 列の幅調整が手動（`\kill` でダミー行設定が必要）
- セルの結合や複雑な罫線は不得意
- 複雑な表には `tabular`/`longtable` の方が適切

### tabbing vs tabular の選択基準

| ユースケース | 推奨 |
|------------|------|
| 単純なテキスト整列、ページまたぎあり | `tabbing` |
| 複数ページにわたる表 | `longtable` |
| 縦横の罫線付き正式な表 | `tabular`/`booktabs` |
| 複雑なセル結合・書式 | `tabularray` |
