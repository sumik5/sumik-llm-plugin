# LaTeX 文書構造ガイド

LaTeX文書の構造化、セクショニング、目次生成、相互参照、ドキュメント管理の高度な技法を扱う。

---

## 目次

1. [DocumentMetadata - PDF/A・タグ付きPDF対応](#documentmetadata)
2. [ドキュメントクラスとオプション](#documentclass)
3. [文書の構成要素](#document-parts)
4. [ファイル分割](#file-splitting)
5. [tagging - 文書バリアント管理](#tagging)
6. [セクショニング](#sectioning)
7. [章・セクションのモットー](#mottos)
8. [目次構造のカスタマイズ](#toc)
9. [相互参照](#cross-references)
10. [ドキュメントソース管理](#source-management)

---

## DocumentMetadata

`\DocumentMetadata` コマンドはPDF/A準拠やタグ付きPDFを生成するための新しい機構。`\documentclass` **より前**に記述する。

### 基本使用法

```latex
\DocumentMetadata{
  pdfversion=2.0,
  pdfstandard=a-4,
  lang=ja,
  pdfapart=4,
  pdfaconformance=F
}
\documentclass{article}
```

### 主要オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `pdfversion` | PDF仕様バージョン | `1.7`, `2.0` |
| `pdfstandard` | PDF標準（PDF/A等） | `a-4`, `x-4` |
| `lang` | 文書の主言語 | `en`, `ja`, `de` |
| `pdfapart` | PDF/Aパート番号 | `1`, `2`, `3`, `4` |
| `pdfaconformance` | 適合レベル | `A`, `B`, `U`, `F` |

### 使用タイミング

- 長期保存が求められる学術論文・公文書
- アクセシビリティが必要な文書（スクリーンリーダー対応）
- 出版社がPDF/A提出を要求する場合

---

## ドキュメントクラスとオプション

### 標準クラス

```latex
\documentclass[11pt, a4paper, twoside]{article}
\documentclass[12pt, oneside, openany]{report}
\documentclass[10pt, twocolumn, draft]{book}
```

### 主要オプション

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `10pt`, `11pt`, `12pt` | 基本フォントサイズ | `10pt` |
| `a4paper`, `letterpaper` | 用紙サイズ | `letterpaper` |
| `oneside`, `twoside` | 片面・両面印刷 | クラス依存 |
| `onecolumn`, `twocolumn` | 段組 | `onecolumn` |
| `draft`, `final` | ドラフト・完成版 | `final` |
| `openright`, `openany` | 章の開始ページ（奇数・任意） | クラス依存 |

### KOMA-Script クラス

より柔軟なオプション処理を提供：

```latex
\documentclass[
  fontsize=11pt,
  paper=a4,
  twoside=true,
  headings=small
]{scrartcl}
```

---

## 文書の構成要素

### Front Matter / Main Matter / Back Matter

```latex
\documentclass{book}
\begin{document}

% Front Matter（前付け）
\frontmatter
\tableofcontents
\listoffigures
\listoftables

% Main Matter（本文）
\mainmatter
\chapter{Introduction}
...

% Back Matter（後付け）
\backmatter
\appendix
\chapter{Additional Data}
\bibliography{refs}

\end{document}
```

| 部分 | ページ番号 | 章番号 | 用途 |
|------|----------|-------|------|
| `\frontmatter` | ローマ数字（i, ii, ...） | なし | 目次・序文 |
| `\mainmatter` | アラビア数字（1, 2, ...） | あり | 本文 |
| `\backmatter` | アラビア数字（続き） | なし | 付録・索引 |

---

## ファイル分割

### `\input` vs `\include`

| コマンド | 改ページ | 選択的コンパイル | 使用場面 |
|---------|---------|----------------|---------|
| `\input{file}` | なし | 不可 | プリアンブル・小セクション |
| `\include{file}` | あり | 可（`\includeonly`） | 章単位 |

### 基本使用法

```latex
% main.tex
\documentclass{book}
\includeonly{chapter1,chapter3} % 選択的コンパイル
\begin{document}
\include{chapter1}
\include{chapter2}
\include{chapter3}
\end{document}

% chapter1.tex
\chapter{Introduction}
本文...
```

### askinclude - 対話的ファイル選択

コンパイル時にどのファイルを含めるか対話的に選択：

```latex
\usepackage{askinclude}
% コンパイル時にプロンプトが表示される
\AskInclude
\include{chapter1}
\include{chapter2}
```

---

## tagging - 文書バリアント管理

同一ソースから複数のバリアント（学生版・教員版、印刷版・Web版等）を生成する。

### 基本使用法

```latex
\usepackage{tagging}

% タグを定義
\usetag{student}
% \usetag{teacher}

\begin{document}
共通テキスト

\tagged{student}{学生向けのみの内容}
\tagged{teacher}{教員向けのみの内容}
\end{document}
```

### 複数タグの組み合わせ

```latex
\usetag{print}
\usetag{color}

\tagged{print,color}{カラー印刷版専用}
\tagged{print}{\tagged{!color}{モノクロ印刷版専用}}
```

---

## セクショニング

### 標準セクショニングコマンド

```latex
\part{部}               % レベル -1（book）
\chapter{章}            % レベル 0（book, report）
\section{節}            % レベル 1
\subsection{項}         % レベル 2
\subsubsection{目}      % レベル 3
\paragraph{段落見出し}   % レベル 4
\subparagraph{小段落}   % レベル 5
```

### titlesec - 柔軟な見出しデザイン

#### パッケージオプション

```latex
% グローバル設定
\usepackage[sf, bf, tiny, center]{titlesec}
% sf: サンセリフ, bf: ボールド, tiny: 小サイズ, center: 中央揃え
```

| オプション | 効果 |
|-----------|------|
| `rm`, `sf`, `tt` | フォントファミリ（ローマン・サンセリフ・タイプライタ） |
| `md`, `bf` | フォントウェイト（標準・ボールド） |
| `up`, `it`, `sl`, `sc` | フォントシェイプ（直立・斜体・スラント・スモールキャップ） |
| `tiny`, `small`, `medium`, `big`, `huge` | サイズ |
| `raggedleft`, `center`, `raggedright` | 配置 |
| `compact` | 前後空白を削減 |

#### カスタム見出しフォーマット

```latex
\usepackage{titlesec}

% セクションのフォーマット変更
\titleformat{\section}
  [hang]                        % 形状（hang, block, display等）
  {\Large\bfseries\sffamily}    % フォーマット
  {\thesection.}                % ラベル
  {1em}                         % ラベルと本文の間隔
  {}                            % 前処理コード
  [\titlerule]                  % 後処理コード（下線）

% スペーシング調整
\titlespacing{\section}
  {0pt}        % 左マージン
  {3.5ex plus 1ex minus .2ex}  % 前空白
  {2.3ex plus .2ex}             % 後空白
```

#### 見出しデザインのバリエーション

```latex
% 番号を囲む
\titleformat{\section}
  {\Large\bfseries}
  {\fbox{\thesection}}
  {1em}
  {}

% 番号を右側に配置
\titleformat{\section}
  [leftmargin]
  {\normalfont\sffamily\bfseries}
  {\thesection}
  {0.5em}
  {}
```

---

## 章・セクションのモットー

### quotchap - 章見出しと一体化したモットー

章見出しの一部として引用を組み込む。

```latex
\usepackage[avantgarde]{quotchap}
% オプション: avantgarde, times, palatino

\begin{document}
\chapter[Short Title]{Long Chapter Title}
\end{document}
```

### epigraph - 見出し後のモットー

章・セクション見出しの後に引用を配置。

```latex
\usepackage{epigraph}

% グローバル設定
\setlength{\epigraphwidth}{0.4\textwidth}
\setlength{\epigraphrule}{0pt}
\renewcommand{\epigraphsize}{\small}
\renewcommand{\epigraphflush}{flushright}

\chapter{Title}
\epigraph{The only way to do great work is to love what you do.}%
         {--- Steve Jobs}

本文開始...
```

#### 複数のエピグラフ

```latex
\chapter{Philosophy}
\begin{epigraphs}
\qitem{I think, therefore I am.}{Descartes}
\qitem{The unexamined life is not worth living.}{Socrates}
\end{epigraphs}
```

#### 章扉ページへの配置

```latex
\epigraphhead[70]{
  \epigraph{Quote text}{--- Author}
}
\chapter{Chapter Title}
```

---

## 目次構造のカスタマイズ

### tocdata - 目次への追加情報

目次に著者名や要約を追加：

```latex
\usepackage{tocdata}

\chapter[著者: John Doe]{Chapter Title}
\chapterauthor{John Doe}

\section[期間: 2024]{Section Title}
\sectiondata{Duration: 1 week}
```

### titletoc - 目次デザインの制御

```latex
\usepackage{titletoc}

% 章の目次エントリをカスタマイズ
\titlecontents{chapter}
  [0pt]                    % 左マージン
  {\addvspace{1em}\bfseries}  % 全体のフォーマット
  {\contentslabel{2em}}    % 番号ありエントリ
  {}                       % 番号なしエントリ
  {\hfill\contentspage}    % フィラーとページ番号

% セクションエントリ
\titlecontents{section}
  [2em]
  {}
  {\contentslabel{2em}}
  {}
  {\titlerule*[1pc]{.}\contentspage}
```

### multitoc - 複数列目次

```latex
\usepackage[toc]{multitoc}
% 目次を2列で表示
```

---

## 相互参照

### varioref - 文脈に応じた柔軟な参照

ページが同じか異なるかに応じて表現を変更：

```latex
\usepackage{varioref}

\section{Method}\label{sec:method}
...
\section{Results}
詳細は\vref{sec:method}を参照。
% → "詳細は 2節 (3ページ)を参照。"（異ページの場合）
% → "詳細は 2節を参照。"（同ページの場合）

% ページのみ参照
\vpageref{sec:method}
% → "3ページ"
```

### cleveref - 自動的な参照種別判定

```latex
\usepackage[capitalise, noabbrev]{cleveref}

\section{Introduction}\label{sec:intro}
\begin{figure}...\caption{...}\label{fig:plot}\end{figure}
\begin{table}...\caption{...}\label{tab:data}\end{table}

...

\Cref{sec:intro} で述べたように...     % → Section 1 で述べたように
\cref{fig:plot,tab:data} を参照。       % → figure 1 and table 1 を参照。
```

#### オプション

| オプション | 効果 |
|-----------|------|
| `capitalise` | 文頭では大文字化（Figure, Table） |
| `noabbrev` | 省略形を使わない（Fig. → Figure） |
| `nameinlink` | リンク範囲に種別名も含める |

#### カスタムラベル

```latex
% 日本語化
\crefname{section}{節}{節}
\crefname{figure}{図}{図}
\crefname{table}{表}{表}

\Cref{sec:intro}  % → 節1
```

### nameref - ラベルのテキストを参照

```latex
\usepackage{nameref}

\section{Important Section}\label{sec:important}
...
\nameref{sec:important} で述べたように...
% → "Important Section で述べたように..."
```

### hyperref - ハイパーリンク

```latex
\usepackage[
  colorlinks=true,
  linkcolor=blue,
  citecolor=green,
  urlcolor=cyan,
  pdfauthor={Your Name},
  pdftitle={Document Title}
]{hyperref}

% PDF内部リンク
\href{https://example.com}{リンクテキスト}
\url{https://example.com}

% 相互参照が自動的にリンクになる
\ref{sec:intro}
```

---

## ドキュメントソース管理

### snapshot - 使用パッケージのバージョン記録

```latex
\usepackage{snapshot}
% コンパイル時に .dep ファイルを生成
% 使用したパッケージとバージョンを記録
```

生成される `.dep` ファイル例：

```
\RequirePackage{snapshot}
\RequireVersions{
  *{application}{pdfTeX} {0000/00/00 v1.40.21}
  *{format} {LaTeX2e}     {2023-06-01 v2.e}
  *{package}{article}     {2021/10/04 v1.4n}
  *{package}{graphicx}    {2021/09/16 v1.2d}
  ...
}
```

### bundledoc - 文書の完全なアーカイブ作成

依存するすべてのファイル（ソース・画像・パッケージ）を収集：

```bash
# Perl スクリプトとして実行
bundledoc --config=unix mydocument.dep
```

生成されるアーカイブには以下が含まれる：

- `.tex` ソースファイル
- `.bib` 参考文献ファイル
- `.eps`, `.pdf` 画像ファイル
- `.sty` パッケージファイル（オプション）

### rollback - パッケージのバージョン固定

特定の日付のパッケージを使用：

```latex
% 2020年1月1日時点のパッケージを使用
\usepackage{graphicx}[=2020-01-01]

% ドキュメント全体でrollback
\documentclass{article}[=v1.4n]
```

---

## 判断基準テーブル

### セクショニングパッケージの選択

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| 見出しデザインの微調整 | `titlesec` | 最も柔軟な設定 |
| 章にモットーを統合 | `quotchap` | デザイン一体化 |
| 見出し後にモットー配置 | `epigraph` | 柔軟な配置制御 |
| KOMA-Script使用時 | 組込機能 | 外部パッケージ不要 |

### 相互参照パッケージの選択

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| ページ番号の自動調整 | `varioref` | 文脈に応じた表現 |
| 参照種別の自動判定 | `cleveref` | 手動指定不要 |
| ラベルのテキスト参照 | `nameref` | 番号ではなくテキスト |
| PDFリンク生成 | `hyperref` | 標準的なハイパーリンク |
| すべて組み合わせ | `varioref`, `cleveref`, `hyperref` | 読み込み順: varioref → hyperref → cleveref |

### 目次カスタマイズの選択

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| 追加情報（著者等） | `tocdata` | 拡張目次エントリ |
| 目次デザイン変更 | `titletoc` | `titlesec`と統合 |
| 複数列目次 | `multitoc` | シンプルな解決策 |

---

## まとめ

LaTeX文書構造の高度な制御には以下のアプローチが有効：

1. **DocumentMetadata**: PDF/A・アクセシビリティ対応
2. **titlesec/titletoc**: 見出し・目次の統一的カスタマイズ
3. **varioref/cleveref**: スマートな相互参照
4. **snapshot/bundledoc**: 再現可能性の確保

プロジェクトの規模と要件に応じて適切なパッケージを選択し、組み合わせることが重要。

---

## 相互参照の高度な機能

### varioref の拡張オプションとコマンド

#### [nospace] オプション

```latex
\usepackage[nospace]{varioref}
% \vref と \vpageref の間に余分なスペースを挿入しない
```

#### \vpageref のオプション引数

省略可能な引数で、同ページ・異ページの表現を個別に指定できる：

```latex
% 同ページの場合は空文字列を出力（何も出力しない）
\vpageref[]{sec:method}

% 第1引数：同ページ時のテキスト、第2引数：異ページ時の前置テキスト
\vpageref[above][below]{sec:method}
% → 同ページ上部なら "above"、下部なら "below"、異ページなら "3ページ"
```

#### 範囲参照コマンド

```latex
% 2つのラベル間の範囲参照（テキスト+ページ）
\vrefrange{label1}{label2}
% → "節2から3 (pp. 5–7)" のように範囲とページを表示

% ページ番号の範囲のみ
\vpagerefrange{label1}{label2}
% → "5ページから7ページ"
```

### xr パッケージ - 外部文書への相互参照

```latex
\usepackage{xr}

% 外部ファイルのラベルを取り込む（対象の .aux ファイルが必要）
\externaldocument{other-document}

% プレフィックスを付けて名前衝突を回避
\externaldocument[ext-]{other-document}

% 外部文書の \label を通常の \ref / \pageref で参照
\ref{sec:intro}       % 外部文書の sec:intro を参照
\ref{ext-sec:intro}   % プレフィックス付きで参照
```

**使用場面**：マルチファイル大規模プロジェクトで、別ファイルに定義されたラベルへの相互参照が必要な場合。

### ラベルデバッグ用パッケージ

#### showlabels - \label をマージンに表示

```latex
\usepackage{showlabels}
% すべての \label 定義箇所の余白にラベル名を出力
% ドラフト段階でラベルの確認に便利
```

#### showkeys - \label と \ref の両方を表示

```latex
\usepackage{showkeys}
% \label, \ref, \cite 等のキーを出力に表示
% showlabels より高機能：参照先のキーも表示
% 本番版（final オプション使用時）には非表示
```

#### refcheck - 未使用ラベルの検出

```latex
\usepackage{refcheck}
% コンパイル後、未使用の \label を .log ファイルに警告として記録
% 不要なラベルの整理に活用
```

### ラベル命名のベストプラクティス

カテゴリプレフィックスで体系的に管理：

| プレフィックス | 対象 |
|--------------|------|
| `sec:` | セクション・章 |
| `fig:` | 図 |
| `tab:` | 表 |
| `eq:` | 数式 |
| `lst:` | コードリスト |
| `app:` | 付録 |

```latex
\section{Introduction}\label{sec:intro}
\begin{figure}...\label{fig:architecture}\end{figure}
\begin{equation}\label{eq:euler}\end{equation}

\cref{fig:architecture} と \cref{eq:euler} を参照（\cref{sec:intro} も参照）。
```

---

## 目次の深さ制御と追加パッケージ

### tocdepth カウンタ

目次に表示する最深レベルを制御：

```latex
% プリアンブルで設定
\setcounter{tocdepth}{2}
% -1: part のみ（book クラス）
%  0: chapter のみ
%  1: section まで（article のデフォルト）
%  2: subsection まで（book/report のデフォルト）
%  3: subsubsection まで

% 文書内で一時的に変更（特定章だけ深い目次を表示）
\addtocontents{toc}{\protect\setcounter{tocdepth}{3}}
\section{Important Section}
\subsection{Detail A}
\subsubsection{Deep Detail}
\addtocontents{toc}{\protect\setcounter{tocdepth}{2}}
```

### tocloft - 目次書式の詳細制御

```latex
\usepackage{tocloft}

% 目次タイトル変更
\renewcommand{\contentsname}{Table of Contents}

% 章エントリのフォント変更
\renewcommand{\cftchapfont}{\bfseries\sffamily}

% ページ番号フォント変更
\renewcommand{\cftchappagefont}{\bfseries}

% エントリ間スペース調整
\setlength{\cftbeforechapskip}{10pt}

% リーダー（点線）を追加
\renewcommand{\cftchapleader}{\cftdotfill{\cftdotsep}}

% インデント調整
\setlength{\cftsecindent}{2em}
\setlength{\cftsubsecindent}{4em}
```

### tocbibind - 参考文献・索引を目次に追加

```latex
\usepackage{tocbibind}
% 以下が自動的に目次に追加される:
% - 目次自体（\tableofcontents）
% - 図目次（\listoffigures）
% - 表目次（\listoftables）
% - 参考文献（\bibliography / \printbibliography）
% - 索引（\printindex）

% 特定エントリを除外するオプション
\usepackage[nottoc,notlot,notlof]{tocbibind}
% nottoc: 目次エントリを除外
% notlot: 表目次エントリを除外
% notlof: 図目次エントリを除外
```

### minitoc - 章ごとのミニ目次

```latex
\usepackage{minitoc}

% プリアンブルで初期化
\dominitoc    % 章レベルのミニ目次を有効化

\begin{document}
\tableofcontents
\mtcaddchapter  % 目次章を minitoc に登録

\chapter{Introduction}
\minitoc        % ← この章のミニ目次を挿入
本文...

\end{document}
```

---

## hyperref の詳細設定

### \hypersetup コマンド

ロード時のオプションと、ロード後の `\hypersetup` コマンドは等価：

```latex
\usepackage[colorlinks=true, linkcolor=blue]{hyperref}

% または
\usepackage{hyperref}
\hypersetup{colorlinks=true, linkcolor=blue}

% 両方を組み合わせることも可能
```

### 主要オプション一覧

| オプション | デフォルト | 説明 |
|-----------|-----------|------|
| `draft` | false | すべてのハイパーテキスト機能をオフ |
| `final` | true | すべてのハイパーテキスト機能をオン |
| `colorlinks` | false | ボックスではなく色でリンクを表示 |
| `hidelinks` | — | リンクの強調を完全に無効化（印刷用） |
| `backref` | false | 参考文献から引用箇所へのバックリンク |
| `hyperindex` | true | 索引のページ番号にリンクを追加 |
| `hyperfootnotes` | true | 脚注マーカーをハイパーリンク化 |
| `hyperfigures` | false | 図にハイパーリンクを追加 |
| `linktocpage` | false | 目次でテキストではなくページ番号をリンク |
| `frenchlinks` | false | 色の代わりにスモールキャップでリンク表示 |
| `bookmarks` | true | PDF リーダー用ブックマークを作成 |
| `bookmarksopen` | false | PDF 開時にすべてのブックマークを展開 |
| `bookmarksnumbered` | false | ブックマークにセクション番号を含める |

### リンク色の設定（colorlinks=true 時）

| オプション | デフォルト | 対象リンク |
|-----------|-----------|-----------|
| `linkcolor` | `red` | 内部リンク（章・節・図への参照） |
| `citecolor` | `green` | 参考文献の引用 |
| `urlcolor` | `magenta` | URL アドレス |
| `filecolor` | `cyan` | ファイルリンク |

### PDF メタデータの設定

```latex
\hypersetup{
  pdfauthor   = {Author Name},
  pdftitle    = {Document Title},
  pdfsubject  = {Subject Description},
  pdfkeywords = {keyword1, keyword2},
  pdfcreator  = {LaTeX with hyperref},
  pdfproducer = {pdfTeX}
}
```

| フィールド | 説明 |
|-----------|------|
| `pdftitle` | 文書タイトル |
| `pdfauthor` | 著者名 |
| `pdfsubject` | 文書の主題 |
| `pdfkeywords` | 検索エンジン最適化用キーワード |
| `pdfcreator` | 文書作成ソフトウェア |
| `pdfproducer` | PDF 生成エンジン |

### 手動ハイパーリンクコマンド

```latex
% URL へのリンク（表示テキストを指定）
\href{https://example.com}{リンクテキスト}

% URL をそのまま表示してリンク
\url{https://example.com}

% URL を表示するがリンクしない
\nolinkurl{https://example.com}

% 内部ラベルへのリンク（任意のテキストを指定）
\hyperref[sec:intro]{こちら} を参照

% 任意の位置にアンカー（跳び先）を設定
\hypertarget{my-anchor}{アンカーのテキスト}

% アンカーへのリンク
\hyperlink{my-anchor}{ここをクリック}
```

### \phantomsection - アンカーの手動挿入

`\addcontentsline` は直前のセクションアンカーを参照するため、対応するセクションコマンドがない場合はアンカーがずれる。`\phantomsection` でアンカーを明示的に設置する：

```latex
\cleardoublepage
\phantomsection                                   % ← ここにアンカーを設置
\addcontentsline{toc}{chapter}{Bibliography}
\bibliography{refs}
```

### ロード順序ルール

hyperref は他の多くのパッケージのコマンドを再定義するため、**プリアンブルの最後に**ロードする：

```latex
\usepackage{graphicx}
\usepackage{amsmath}
% ... 他のパッケージ ...
\usepackage{hyperref}   % ← 最後にロード

% hyperref の後にロードが必要なパッケージ（例外）
\usepackage{cleveref}
\usepackage{glossaries}
```

---

## PDF ブックマークの操作

### \pdfbookmark - 手動ブックマーク作成

```latex
% 基本構文
\pdfbookmark[level]{表示テキスト}{内部名}

% 例：目次をレベル 1 のブックマークとして登録
\pdfbookmark[1]{\contentsname}{toc}
\tableofcontents

% 概要をブックマークとして登録
\pdfbookmark[1]{Abstract}{abstract}
\begin{abstract}
...
\end{abstract}
```

ブックマークレベル: 0=part, 1=chapter, 2=section, 3=subsection ...

### 相対的なブックマーク作成

```latex
% 現在のレベルにブックマークを作成
\currentpdfbookmark{テキスト}{名前}

% 1レベル下にブックマークを作成
\belowpdfbookmark{テキスト}{名前}

% 1レベル下に移動してブックマークを作成
\subpdfbookmark{テキスト}{名前}
```

高度なカスタマイズには `bookmark` パッケージを追加で利用可能（フォントスタイル・色の設定など）。

### \texorpdfstring - 数式を含む見出しのブックマーク対応

PDF ブックマークには数学記号が使えないため、TeX 用と PDF 用で別テキストを指定する：

```latex
% 構文
\texorpdfstring{TeXコード}{PDFテキスト}

% 例1：数式を含むセクション
\section{The equation
  \texorpdfstring{$y=x^2$}{y=x squared}}

% 例2：Unicode オプション使用時
\usepackage[unicode, psdextra]{hyperref}
\section{\texorpdfstring{$\gamma$}{\textgamma} radiation}

% 例3：TOC 用の短いテキスト + 本文用の数式
\section[Short TOC Title]{Full title with \texorpdfstring{$\int_a^b f(x)dx$}{integral}}
```
