# ページレイアウト（Page Layout）

LaTeX文書のページレイアウト設計に関する包括的なリファレンス。

---

## 目次

1. [ページレイアウトの幾何学](#ページレイアウトの幾何学)
2. [レイアウト可視化](#レイアウト可視化)
3. [geometry パッケージ](#geometry-パッケージ)
4. [typearea パッケージ](#typearea-パッケージ)
5. [ランドスケープとページサイズ調整](#ランドスケープとページサイズ調整)
6. [動的ページデータ](#動的ページデータ)
7. [ページスタイル](#ページスタイル)
8. [fancyhdr パッケージ](#fancyhdr-パッケージ)
9. [ページ装飾](#ページ装飾)
10. [ビジュアルフォーマット](#ビジュアルフォーマット)
11. [ドキュメントクラス](#ドキュメントクラス)

---

## ページレイアウトの幾何学

### 基本概念

LaTeXのページは以下の要素で構成される：

- **Type area（本文領域）**: テキストが配置される矩形領域
- **Header（ヘッダー）**: ページ上部の情報（ページ番号、セクション名など）
- **Footer（フッター）**: ページ下部の情報
- **Margins（マージン）**: 本文領域の周囲の空白
  - Inner margin（内側マージン）: 綴じ側のマージン
  - Outer margin（外側マージン）: 反対側のマージン
- **Marginal notes（傍注）**: マージン内の小さなテキスト

### 主要な寸法パラメータ

```latex
% 用紙サイズ
\paperwidth     % 用紙の幅
\paperheight    % 用紙の高さ

% テキスト領域
\textwidth      % 本文の幅
\textheight     % 本文の高さ

% 水平方向の配置
\oddsidemargin  % 奇数ページの左マージン（1インチ + この値）
\evensidemargin % 偶数ページの左マージン（1インチ + この値）

% 垂直方向の配置
\topmargin      % ヘッダー上部の追加マージン
\headheight     % ヘッダーの高さ
\headsep        % ヘッダーと本文の間隔
\footskip       % 本文最終行とフッター間の距離

% 傍注
\marginparwidth % 傍注の幅
\marginparsep   % 本文と傍注の間隔
\marginparpush  % 連続する傍注間の最小間隔

% オフセット（通常は変更不要）
\hoffset        % 水平オフセット（デフォルト 0pt）
\voffset        % 垂直オフセット（デフォルト 0pt）
```

### レイアウトパラメータの計算例

```latex
% 50行のページを作成
\setlength\textheight{\baselineskip*49+\topskip}

% 本文高を特定のミリ数に設定（例: 198mm）
\newcounter{tempc}
\newcounter{tempcc}
\setlength\textheight{198mm-\topskip}
\setcounter{tempc}{\textheight}
\setcounter{tempcc}{\baselineskip}
\setcounter{tempc}{\value{tempc}/\value{tempcc}}
\setlength\textheight{\baselineskip*\value{tempc}+\topskip}

% 上下マージンの比率を調整（上:下 = 1:2）
\setlength\topmargin{%
  (297mm-\textheight)/3 - 1in - \headheight - \headsep}
```

### 重要な原則

- **レイアウトパラメータの変更はプリアンブルで行う**: `\begin{document}` より前に設定
- **行長の制限**: 1行あたり60-70文字（10-12単語）が可読性の観点から推奨
- **ページあたりの行数**: タイプサイズに応じて調整（10pt: 53行、11pt: 46行、12pt: 42行）

---

## レイアウト可視化

### layouts パッケージ

現在のレイアウト設定を図示するための強力なツール。

```latex
\usepackage{layouts}

% 抽象的なレイアウト図を表示
\setlayoutscale{0.4}  % スケール調整
\pagediagram

% 現在のレイアウト設定を反映した図を表示
\currentpage
\pagedesign

% 試行レイアウトの作成
\trypaperwidth{11in}
\trypaperheight{8.5in}
\trytextwidth{500pt}
\trytextheight{\topskip + 30\baselineskip}
\tryheadheight{12pt}
\pagedesign
```

**主要コマンド：**

- `\pagediagram`: 抽象的なレイアウト図（パラメータ名を表示）
- `\pagedesign`: 試行値を反映したレイアウト図
- `\currentpage`: 現在の値を試行値として設定
- `\try<param>{<value>}`: 各パラメータの試行値を設定
- `\setlayoutscale{<factor>}`: 表示倍率の設定

**レイアウトオプション：**

```latex
\oddpagelayoutfalse      % 偶数ページを表示（デフォルトは奇数）
\twocolumnlayouttrue     % 二段組レイアウト
\reversemarginpartrue    % 傍注の位置を反転
\marginparswitchfalse    % 傍注の左右切り替えを無効化
```

### layout パッケージ

よりシンプルな可視化ツール。

```latex
\usepackage{layout}

% レイアウト図を生成
\layout
```

- 全サイズを1/2に縮小して表示
- `twoside` オプション使用時は2ページ生成

---

## geometry パッケージ

レイアウト指定を自動補完する最も人気のあるパッケージ。

### 基本使用法

```latex
\usepackage[
  a4paper,           % 用紙サイズ
  margin=2.5cm,      % 全マージンを統一
  top=3cm,           % 上マージン
  bottom=3cm,        % 下マージン
  left=2cm,          % 左マージン
  right=2cm          % 右マージン
]{geometry}

% プリアンブル内で変更
\geometry{
  textwidth=15cm,
  textheight=22cm
}

% ドキュメント内で一時的に変更
\newgeometry{margin=1cm}
% ... コンテンツ ...
\restoregeometry
```

### 主要オプション一覧

**用紙サイズ：**
- `a4paper`, `a5paper`, `letterpaper`, `legalpaper` など

**マージン指定：**
- `margin`: 全マージンを統一
- `hmargin`: 左右マージンを統一
- `vmargin`: 上下マージンを統一
- `top`, `bottom`, `left`, `right`: 個別指定
- `inner`, `outer`: 両面印刷用の内側・外側マージン

**本文領域指定：**
- `textwidth`, `textheight`: 本文領域のサイズ
- `body`: `{width,height}` で本文領域を指定

**ヘッダー・フッター：**
- `headheight`: ヘッダーの高さ
- `headsep`: ヘッダーと本文の間隔
- `footskip`: フッターのスキップ
- `includehead`: ヘッダーを本文領域に含める
- `includefoot`: フッターを本文領域に含める

**レイアウトモード：**
- `landscape`: 横向き
- `twoside`: 両面印刷
- `asymmetric`: 非対称レイアウト（両面でも左右同じ）

**比率指定：**
- `hmarginratio`: 左右マージンの比率（例: `1:2`）
- `vmarginratio`: 上下マージンの比率（例: `2:3`）

**その他：**
- `scale`: 用紙に対する本文領域の比率（例: `0.8`）
- `centering`: センタリング
- `showframe`: レイアウト枠を表示（デバッグ用）

### 実用例

```latex
% シンプルな論文レイアウト
\usepackage[
  a4paper,
  margin=2.5cm,
  includehead
]{geometry}

% 書籍レイアウト（両面印刷）
\usepackage[
  a5paper,
  twoside,
  inner=2cm,
  outer=1.5cm,
  top=2cm,
  bottom=2.5cm,
  bindingoffset=0.5cm  % 綴じ代
]{geometry}

% プレゼンテーション用（横向き）
\usepackage[
  a4paper,
  landscape,
  margin=1.5cm
]{geometry}

% 傍注を広く取るレイアウト
\usepackage[
  a4paper,
  textwidth=12cm,
  marginparwidth=4cm,
  marginparsep=0.5cm
]{geometry}
```

---

## typearea パッケージ

KOMA-Scriptの伝統的なアプローチに基づくタイプエリア計算。

### 基本概念

タイプエリアを用紙サイズと本のバインディング方法に基づいて自動計算。黄金比や古典的な比率を使用。

```latex
\usepackage{typearea}

% 基本使用
\typearea[BCOR]{DIV}
% BCOR: Binding CORrection（綴じ代）
% DIV: 分割数（大きいほど本文領域が広い）

\typearea[12mm]{10}  % 綴じ代12mm、分割数10
```

### DIV値の選択

- **6-8**: 非常に広いマージン（読みやすい）
- **9-12**: 標準的なマージン（書籍用）
- **13-15**: 狭いマージン（論文・レポート用）
- **auto**: 自動計算

```latex
% 自動計算
\usepackage[DIV=calc]{typearea}

% 再計算（フォントサイズ変更後など）
\recalctypearea
```

### KOMA-Scriptクラスとの統合

```latex
% KOMA-Scriptクラスを使用
\documentclass[
  paper=a4,
  DIV=12,
  BCOR=10mm,
  twoside
]{scrbook}
```

---

## ランドスケープとページサイズ調整

### lscape パッケージ

特定のページを横向きに回転。

```latex
\usepackage{lscape}

\begin{landscape}
  % このコンテンツは横向きで表示される
  \includegraphics[width=\textwidth]{wide-image.pdf}
\end{landscape}
```

### pdflscape パッケージ

PDFビューアで自動的に回転表示される横向きページ。

```latex
\usepackage{pdflscape}

\begin{landscape}
  % PDF表示時に自動回転
\end{landscape}
```

### savetrees パッケージ

文書長を削減するための各種設定を自動適用。

```latex
\usepackage[
  moderate,  % subtle, moderate, extreme
]{savetrees}
```

**オプション：**
- `subtle`: 穏やかな削減（〜10%）
- `moderate`: 中程度の削減（〜20%）
- `extreme`: 極端な削減（〜30%、可読性低下）

---

## 動的ページデータ

### LaTeXのページ番号機構

```latex
% ページ番号のスタイル
\pagenumbering{arabic}   % 1, 2, 3, ...
\pagenumbering{roman}    % i, ii, iii, ...
\pagenumbering{Roman}    % I, II, III, ...
\pagenumbering{alph}     % a, b, c, ...
\pagenumbering{Alph}     % A, B, C, ...

% 現在のページ番号を参照
\thepage

% ページカウンタの操作
\setcounter{page}{1}     % ページ番号をリセット
\addtocounter{page}{5}   % ページ番号をスキップ
```

### lastpage パッケージ

最終ページ番号を参照。

```latex
\usepackage{lastpage}

% 使用例: "Page 3 of 42"
Page \thepage\ of \pageref{LastPage}

% または \pageref*{LastPage} でハイパーリンクなし
```

### chappg パッケージ

章ごとにページ番号をリセット。

```latex
\usepackage{chappg}

% ページ番号が "章番号-ページ番号" の形式になる
% 例: 3-1, 3-2, 3-3, ...
```

### マーク機構

LaTeXのマーク機構は、ヘッダー・フッターに動的な情報（章名、節名など）を表示するために使用される。

**新しいマーク機構（LaTeX 2022以降）：**

```latex
% マークの挿入
\InsertMark{章タイトル}

% マークの取得
\TopMark     % ページ最初のマーク
\FirstMark   % ページ最初の変更マーク
\BottomMark  % ページ最後のマーク

% 複数のマーククラス
\NewMarkClass{section}
\InsertMark{section}{セクション名}
\TopMark{section}
```

**旧マーク機構：**

```latex
% 左右のマーク（奇数・偶数ページ用）
\markboth{左マーク}{右マーク}
\markright{右マーク}

% マークの参照
\leftmark   % 左マーク（通常は章名）
\rightmark  % 右マーク（通常は節名）
```

---

## ページスタイル

### 標準ページスタイル

```latex
% 4つの標準スタイル
\pagestyle{plain}      % ページ番号のみ（フッター中央）
\pagestyle{empty}      % ヘッダー・フッターなし
\pagestyle{headings}   % ヘッダーに章・節名とページ番号
\pagestyle{myheadings} % カスタムヘッダー（\markbothで指定）

% 特定ページのみスタイル変更
\thispagestyle{empty}
```

### 低レベルページスタイルインターフェース

カスタムページスタイルの定義。

```latex
\makeatletter
\def\ps@mystyle{%
  \def\@oddhead{...}   % 奇数ページのヘッダー
  \def\@evenhead{...}  % 偶数ページのヘッダー
  \def\@oddfoot{...}   % 奇数ページのフッター
  \def\@evenfoot{...}  % 偶数ページのフッター
}
\makeatother

\pagestyle{mystyle}
```

**利用可能なコマンド：**
- `\thepage`: 現在のページ番号
- `\leftmark`, `\rightmark`: マーク
- `\hfil`: 水平方向のグルー
- フォントコマンド（`\bfseries`, `\itshape` など）

---

## fancyhdr パッケージ

ヘッダー・フッターを柔軟にカスタマイズできる最も人気のあるパッケージ。

### 基本使用法

```latex
\usepackage{fancyhdr}
\pagestyle{fancy}

% ヘッダー・フッターのクリア
\fancyhf{}

% ヘッダーの設定
\fancyhead[L]{左}     % 左側
\fancyhead[C]{中央}   % 中央
\fancyhead[R]{右}     % 右側

% フッターの設定
\fancyfoot[L]{左}
\fancyfoot[C]{中央}
\fancyfoot[R]{右}

% 両面印刷用（奇数・偶数ページ）
\fancyhead[LE,RO]{\thepage}        % 左偶数、右奇数
\fancyhead[LO,RE]{\leftmark}       % 左奇数、右偶数
\fancyfoot[C]{共通フッター}
```

**位置指定子：**
- `L`: 左（Left）
- `C`: 中央（Center）
- `R`: 右（Right）
- `E`: 偶数ページ（Even）
- `O`: 奇数ページ（Odd）

### ヘッダー罫線のカスタマイズ

```latex
% ヘッダー罫線の太さ（デフォルト 0.4pt）
\renewcommand{\headrulewidth}{0.4pt}

% フッター罫線の太さ（デフォルト 0pt）
\renewcommand{\footrulewidth}{0.4pt}

% 罫線なし
\renewcommand{\headrulewidth}{0pt}
```

### 実用的なデザインパターン

**シンプルな論文スタイル：**

```latex
\usepackage{fancyhdr}
\pagestyle{fancy}
\fancyhf{}
\fancyhead[R]{\thepage}
\fancyfoot[C]{\small\itshape My Thesis Title}
\renewcommand{\headrulewidth}{0.4pt}
```

**書籍スタイル（両面印刷）：**

```latex
\usepackage{fancyhdr}
\pagestyle{fancy}
\fancyhf{}
\fancyhead[LE]{\thepage\quad\slshape\leftmark}   % 左偶数
\fancyhead[RO]{\slshape\rightmark\quad\thepage} % 右奇数
\renewcommand{\headrulewidth}{0pt}
```

**レポートスタイル：**

```latex
\usepackage{fancyhdr}
\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\slshape\leftmark}
\fancyhead[R]{\thepage}
\fancyfoot[C]{\small Project Report 2024}
\renewcommand{\headrulewidth}{0.5pt}
\renewcommand{\footrulewidth}{0.5pt}
```

### 章開始ページのカスタマイズ

章開始ページは通常 `plain` スタイルが適用される。これをカスタマイズするには：

```latex
% plainスタイルの再定義
\fancypagestyle{plain}{%
  \fancyhf{}
  \fancyfoot[C]{\thepage}
  \renewcommand{\headrulewidth}{0pt}
}
```

### ヘッダー高さの調整

ヘッダーが複数行の場合、高さを調整：

```latex
\setlength{\headheight}{14.5pt}
\addtolength{\topmargin}{-2.5pt}
```

### マークのカスタマイズ

```latex
% 章・節名の大文字化を防ぐ
\renewcommand{\chaptermark}[1]{%
  \markboth{\thechapter.\ #1}{}}
\renewcommand{\sectionmark}[1]{%
  \markright{\thesection.\ #1}}
```

---

## truncate パッケージ

テキストを指定長に切り詰める（ヘッダーで長いタイトルを扱う際に有用）。

```latex
\usepackage{truncate}

% 基本使用
\truncate{5cm}{非常に長いテキストがここに...}
% 出力: "非常に長いテキ..."

% fancyhdrとの組み合わせ
\fancyhead[L]{\truncate{0.8\textwidth}{\leftmark}}
```

**オプション：**
```latex
\truncate[marker]{width}{text}
% marker: 省略記号（デフォルト "..."）

\truncate[\dots]{10cm}{長いタイトル}
```

---

## continue パッケージ

ページめくり支援（"Continued on next page" などの表示）。

```latex
\usepackage{continue}

% 自動的に継続メッセージを表示
\begin{continued}
  長いコンテンツ...
\end{continued}
```

---

## ページ装飾

### draftwatermark パッケージ

ドラフト版にウォーターマーク（透かし）を追加。

```latex
\usepackage[
  firstpage,           % 最初のページのみ
  % allpages,          % 全ページ
  text={DRAFT},        % 表示テキスト
  color=red!30,        % 色（透明度30%）
  scale=3,             % スケール
  angle=45             % 回転角度
]{draftwatermark}
```

**主要オプション：**
- `text`: 表示するテキスト
- `stamp`: 定型スタンプ（`true` で "DRAFT" を表示）
- `color`: 色指定
- `scale`: サイズ倍率
- `angle`: 回転角度（度）
- `firstpage` / `allpages`: 適用範囲

```latex
% カスタマイズ例
\usepackage[
  text={CONFIDENTIAL},
  color=red!50,
  scale=1.5,
  angle=60
]{draftwatermark}
```

### crop パッケージ

トンボ（トリミングマーク）を追加。

```latex
\usepackage[
  a4,          % ターゲット用紙サイズ
  center,      % センタリング
  cross        % 十字トンボ
]{crop}
```

**オプション：**
- `cross`: 十字トンボ
- `frame`: 枠線
- `cam`: コーナーマーク
- `center`: センタリング
- `info`: ページ情報を表示

---

## ビジュアルフォーマット

### 明示的改ページ制御

```latex
% 改ページを推奨（ペナルティ使用）
\pagebreak[4]   % 0-4の強度（4が最強）

% 強制改ページ
\newpage        % 即座に改ページ
\clearpage      % フロートを出力してから改ページ
\cleardoublepage % 両面印刷で奇数ページから開始

% 改ページを禁止
\nopagebreak[4]

% 段組環境での改段
\columnbreak    % 次の段へ
```

### needspace パッケージ

条件付き改ページ（指定した空きがない場合に改ページ）。

```latex
\usepackage{needspace}

% 最低3行分の空きを確保
\needspace{3\baselineskip}

% セクション前に使用
\needspace{5\baselineskip}
\section{新しいセクション}
```

### ウィドウ・オーファン対策

**ウィドウ（Widow）**: 段落の最後の行だけが次ページに残る
**オーファン（Orphan）**: 段落の最初の行だけが前ページに残る

```latex
% ペナルティを強化（標準的な設定）
\widowpenalty=10000
\clubpenalty=10000

% または moderate な設定
\widowpenalty=300
\clubpenalty=300

% より細かい制御
\interlinepenalty=50  % 段落内の改ページペナルティ
```

### widows-and-orphans パッケージ

ウィドウ・オーファンを自動検出。

```latex
\usepackage{widows-and-orphans}

% ドキュメントコンパイル後、.logファイルに
% 検出されたウィドウ・オーファンがリストアップされる
```

### \looseness — 段落長の微調整

段落の行数を増減させる。

```latex
% 1行短くする
{\looseness=-1
この段落は通常より1行短く組まれます。...
\par}

% 1行長くする
{\looseness=1
この段落は通常より1行長く組まれます。...
\par}
```

**使用例：**
- ページの最後にわずかに足りない場合
- ウィドウ・オーファンの回避
- 見開きの調整

**注意：**
- `\par` の前に適用し、段落の終わりで効果がリセットされる
- 大きな値は組版品質を低下させる可能性がある

---

## ドキュメントクラス

### KOMA-Script

LaTeXの標準クラス（`article`, `report`, `book`）の代替として、より柔軟なレイアウト制御を提供。

**クラス：**
- `scrartcl`: `article` の代替
- `scrreprt`: `report` の代替
- `scrbook`: `book` の代替
- `scrlttr2`: 手紙用

```latex
\documentclass[
  paper=a4,
  fontsize=11pt,
  DIV=12,
  BCOR=10mm,
  twoside,
  headings=big
]{scrbook}
```

**主要オプション：**
- `paper`: 用紙サイズ（`a4`, `letter` など）
- `fontsize`: フォントサイズ（任意の値が指定可能）
- `DIV`: タイプエリアの分割数
- `BCOR`: 綴じ代
- `twoside` / `oneside`: 両面・片面印刷
- `headings`: 見出しスタイル（`small`, `normal`, `big`）

### memoir クラス

複雑な出版物（書籍、論文集など）のための統合クラス。

```latex
\documentclass[
  a4paper,
  11pt,
  twoside,
  openright
]{memoir}
```

**特徴：**
- 標準クラスの機能に加え、多数のパッケージ機能を統合
- 章スタイルのカスタマイズが容易
- ページレイアウトの細かい制御
- 目次・索引の高度なカスタマイズ

**主要機能：**

```latex
% ページレイアウト
\settypeblocksize{22cm}{15cm}{*}
\setlrmargins{*}{*}{1.5}
\setulmargins{*}{*}{1.5}
\checkandfixthelayout

% 章スタイル
\chapterstyle{bianchi}  % 多数のプリセットスタイル

% ヘッダー・フッター
\makepagestyle{mystyle}
\makeevenhead{mystyle}{\thepage}{}{\leftmark}
\makeoddhead{mystyle}{\rightmark}{}{\thepage}
\pagestyle{mystyle}
```

---

## パッケージ選択ガイド

### レイアウト設定

| 目的 | 推奨パッケージ | 理由 |
|------|-------------|------|
| 一般的なレイアウト調整 | `geometry` | 直感的で柔軟なオプション |
| 伝統的な書籍デザイン | `typearea` | 黄金比に基づいた美しいレイアウト |
| 複雑な出版物 | `memoir`クラス | 統合された強力な機能 |
| ヨーロッパスタイル | KOMA-Script | ヨーロッパの組版慣習に準拠 |

### ヘッダー・フッター

| 目的 | 推奨パッケージ | 理由 |
|------|-------------|------|
| 標準的なカスタマイズ | `fancyhdr` | シンプルで強力 |
| 複雑な設計 | `memoir`クラス | より高度な制御 |
| KOMA-Script使用時 | `scrlayer-scrpage` | KOMA-Scriptとの統合 |

### レイアウト可視化

| 目的 | 推奨パッケージ | 理由 |
|------|-------------|------|
| クイックチェック | `layout` | シンプルで高速 |
| 詳細な試行錯誤 | `layouts` | 試行値の設定が可能 |
| デバッグ | `geometry`の`showframe` | 実際のレイアウトを表示 |

---

## まとめ

- **レイアウト設計は最初に決定**: プリアンブルで設定し、ドキュメント途中での変更は避ける
- **可読性を優先**: 行長60-70文字、適切なマージン
- **ツールを活用**: `geometry`、`fancyhdr`、`layouts`で効率的に設計
- **可視化して確認**: `\pagediagram`、`showframe`オプションでレイアウトを確認
- **適切なクラスを選択**: 標準クラス、KOMA-Script、memoirから用途に応じて選択

---

## ドキュメント構造コマンド（セクショニング）

### 階層と対応クラス

| コマンド | レベル | article | report | book |
|---------|--------|---------|--------|------|
| `\part` | -1 | ○ | ○ | ○ |
| `\chapter` | 0 | ✗ | ○ | ○ |
| `\section` | 1 | ○ | ○ | ○ |
| `\subsection` | 2 | ○ | ○ | ○ |
| `\subsubsection` | 3 | ○ | ○ | ○ |
| `\paragraph` | 4 | ○ | ○ | ○ |
| `\subparagraph` | 5 | ○ | ○ | ○ |

### 基本的な使い方

```latex
\chapter{章タイトル}            % book/report クラスのみ
\section{節タイトル}
\subsection{小節タイトル}
\subsubsection{小小節タイトル}
\paragraph{段落見出し}          % テキストと同行（ランイン見出し）
\subparagraph{小段落見出し}
```

### スター形式（番号・目次エントリなし）

```latex
\section*{番号なしの節}         % 番号なし、目次エントリなし、ヘッダーにも出ない
```

### オプション引数（目次の短縮タイトル）

```latex
\chapter[短い目次タイトル]{本文に表示される長いタイトル}
\section[概要]{詳細な節のタイトル（本文に表示）}
```

### 自動的に行われる処理

セクショニングコマンドは以下を自動実行する：
- 階層に応じた書体・サイズでの見出し出力
- 番号の自動カウントと下位カウンタのリセット（`\chapter` → section カウンタをリセット）
- `.toc` ファイルへの目次エントリの書き込み
- `.lof`/`.lot` ファイルへの図表一覧エントリ書き込み
- ページヘッダー用の見出しテキストの保存

---

## 目次（\tableofcontents）

### 基本的な使い方

```latex
\documentclass[a4paper,12pt]{book}
\begin{document}
\tableofcontents    % 目次を出力（通常 \begin{document} 直後）
\chapter{最初の章}
...
\end{document}
```

**重要**: 目次を正しく表示するには **2回コンパイル** が必要。

| 回 | 処理内容 |
|----|---------|
| 1回目 | セクション見出しを `.toc` ファイルに書き込む（目次は空） |
| 2回目 | `.toc` ファイルを読み込み、目次を正しく出力 |

### 対応コマンド

| コマンド | 説明 |
|---------|------|
| `\tableofcontents` | 目次 |
| `\listoffigures` | 図一覧（`.lof` ファイル利用） |
| `\listoftables` | 表一覧（`.lot` ファイル利用） |

### 目次の深さ制御

```latex
\setcounter{tocdepth}{2}   % section（レベル1）まで表示（subsection以下は非表示）
\setcounter{tocdepth}{3}   % subsubsection まで表示
```

---

## ドキュメントクラスオプション

`\documentclass[オプション]{クラス}` で指定するオプション一覧。

### 用紙サイズと基準フォントサイズ

| オプション | 意味 |
|---------|------|
| `a4paper` | A4（210×297mm） |
| `letterpaper` | US レター（デフォルト） |
| `a5paper`, `b5paper` | A5, B5 サイズ |
| `10pt`, `11pt`, `12pt` | 基準フォントサイズ（デフォルト `10pt`） |

### レイアウト

| オプション | 意味 |
|---------|------|
| `landscape` | 横向き（幅と高さを入れ替え） |
| `oneside` | 片面印刷（`article`/`report` のデフォルト） |
| `twoside` | 両面印刷（`book` のデフォルト） |
| `onecolumn` | 1段組（デフォルト） |
| `twocolumn` | 2段組 |
| `openright` | 章を右ページから開始（`book` のデフォルト） |
| `openany` | 章をどちらのページからでも開始（`report` のデフォルト） |

### タイトルページと下書き

| オプション | 意味 |
|---------|------|
| `titlepage` | `\maketitle` で独立したタイトルページ（`book`/`report` のデフォルト） |
| `notitlepage` | タイトルの後に本文が続く（`article` のデフォルト） |
| `final` | 最終版（デフォルト） |
| `draft` | 下書き（オーバーフルラインに黒ボックス表示、画像省略） |

### 数式

| オプション | 意味 |
|---------|------|
| `fleqn` | 別行立て数式を左揃え（デフォルトは中央） |
| `leqno` | 数式番号を左側に配置（デフォルトは右） |

### 2段組のコマンド制御

```latex
\twocolumn[開始テキスト]   % 2段組開始（省略可能な全幅テキスト付き）
\onecolumn                 % 1段組に戻す
```

`multicols` パッケージを使うと3段以上や、ページ末の段のバランス調整が可能。
