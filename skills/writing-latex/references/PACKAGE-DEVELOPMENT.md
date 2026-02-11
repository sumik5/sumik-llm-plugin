# パッケージ・クラスファイル開発

LaTeXパッケージ（`.sty`）とクラスファイル（`.cls`）の開発手法。doc/docstrip システム、l3build、および LaTeX プログラミング基礎を扱う。

---

## パッケージ開発の基本

### パッケージファイル（.sty）の構造

```latex
% mypackage.sty
\NeedsTeXFormat{LaTeX2e}
\ProvidesPackage{mypackage}[2024/01/15 v1.0 My Package]

% 1. 依存パッケージの読み込み
\RequirePackage{xcolor}

% 2. オプション宣言
\DeclareOption{draft}{\def\my@draft{true}}
\DeclareOption{final}{\def\my@draft{false}}
\DeclareOption*{\PackageWarning{mypackage}{Unknown option '\CurrentOption'}}

% 3. オプション処理
\ExecuteOptions{final}  % デフォルトオプション
\ProcessOptions\relax

% 4. メインコード
\newcommand{\mycommand}[1]{%
  \textcolor{blue}{#1}%
}

\endinput
```

---

## クラスファイル（.cls）の構造

### 基本構造

```latex
% myclass.cls
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{myclass}[2024/01/15 v1.0 My Class]

% 1. オプション宣言
\DeclareOption{10pt}{\def\my@ptsize{10pt}}
\DeclareOption{11pt}{\def\my@ptsize{11pt}}
\DeclareOption{12pt}{\def\my@ptsize{12pt}}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}

% 2. オプション処理
\ExecuteOptions{10pt}
\ProcessOptions\relax

% 3. 基底クラスの読み込み
\LoadClass[\my@ptsize]{article}

% 4. パッケージの読み込み
\RequirePackage{geometry}
\RequirePackage{fancyhdr}

% 5. カスタマイズ
\geometry{margin=1in}
\pagestyle{fancy}

\endinput
```

---

## コマンド定義

### `\newcommand` — 新しいコマンド定義

```latex
% 引数なし
\newcommand{\mylogo}{My Company}

% 引数あり
\newcommand{\greet}[1]{Hello, #1!}

% オプション引数
\newcommand{\greetopt}[2][World]{Hello, #1 and #2!}
% \greetopt{Alice}       → Hello, World and Alice!
% \greetopt[Bob]{Alice}  → Hello, Bob and Alice!
```

### `\renewcommand` — コマンドの再定義

```latex
\renewcommand{\thesection}{\Roman{section}}  % I, II, III, ...
\renewcommand{\arraystretch}{1.5}            % テーブルの行間
```

### `\DeclareRobustCommand` — ロバストなコマンド

```latex
\DeclareRobustCommand{\myrobust}[1]{%
  \textbf{#1}%
}
% moving argument（見出しなど）でも安全に使用可能
```

### `\providecommand` — 定義されていない場合のみ定義

```latex
\providecommand{\mycommand}{default}
% \mycommand が既に定義されていれば何もしない
```

---

## 環境定義

### `\newenvironment` — 新しい環境

```latex
\newenvironment{myenv}
  {\begin{center}\bfseries}  % 開始コード
  {\end{center}}             % 終了コード

% 使用例
\begin{myenv}
  Content
\end{myenv}
```

### 引数付き環境

```latex
\newenvironment{colorbox}[1]
  {\begin{center}\color{#1}}
  {\end{center}}

% 使用例
\begin{colorbox}{red}
  Red text
\end{colorbox}
```

### `\renewenvironment` — 環境の再定義

```latex
\renewenvironment{abstract}
  {\small\begin{center}\bfseries Abstract\end{center}\begin{quotation}}
  {\end{quotation}}
```

---

## オプション処理

### 基本的なオプション宣言

```latex
\DeclareOption{draft}{%
  \def\my@mode{draft}%
}

\DeclareOption{final}{%
  \def\my@mode{final}%
}

% デフォルトオプション
\ExecuteOptions{final}

% オプション処理
\ProcessOptions\relax
```

### 未知のオプションの扱い

```latex
% パッケージの場合
\DeclareOption*{%
  \PackageWarning{mypackage}{Unknown option '\CurrentOption'}%
}

% クラスの場合
\DeclareOption*{%
  \PassOptionsToClass{\CurrentOption}{article}%
}
```

### key=value 構文のオプション

```latex
\RequirePackage{kvoptions}
\SetupKeyvalOptions{
  family=mypkg,
  prefix=mypkg@
}

\DeclareStringOption[blue]{color}  % デフォルト: blue
\DeclareBoolOption[true]{frame}    % デフォルト: true

\ProcessKeyvalOptions*

% 使用
\usepackage[color=red, frame=false]{mypackage}

% 内部で参照
\mypkg@color    % → red
\ifmypkg@frame  % → false
```

---

## カウンタと長さ

### カウンタ定義と操作

```latex
% カウンタ定義
\newcounter{mycounter}
\newcounter{subcounter}[mycounter]  % mycounter がリセットされると subcounter もリセット

% カウンタ操作
\setcounter{mycounter}{5}
\addtocounter{mycounter}{3}
\stepcounter{mycounter}             % +1 してリセット処理

% カウンタ表示
\themycounter                       % アラビア数字
\arabic{mycounter}                  % アラビア数字（明示的）
\roman{mycounter}                   % 小文字ローマ数字（i, ii, iii）
\Roman{mycounter}                   % 大文字ローマ数字（I, II, III）
\alph{mycounter}                    % 小文字アルファベット（a, b, c）
\Alph{mycounter}                    % 大文字アルファベット（A, B, C）
\fnsymbol{mycounter}                % 脚注記号（*, †, ‡）

% 再定義
\renewcommand{\themycounter}{\Roman{mycounter}}
```

### 長さ（length）定義と操作

```latex
% 長さ定義
\newlength{\mylength}
\newlength{\anotherlength}

% 長さ設定
\setlength{\mylength}{10pt}
\setlength{\mylength}{1cm}
\setlength{\mylength}{\textwidth}

% 長さ加算
\addtolength{\mylength}{5pt}

% 長さ計算（calc パッケージ）
\usepackage{calc}
\setlength{\mylength}{\textwidth - 2cm}
\setlength{\mylength}{2\parindent + 3pt}
```

---

## ボックスとルール

### LR ボックス（水平ボックス）

```latex
% \mbox — 改行不可ボックス
\mbox{text}

% \makebox — 幅指定ボックス
\makebox[5cm][l]{left-aligned}   % 左寄せ
\makebox[5cm][c]{centered}        % 中央寄せ
\makebox[5cm][r]{right-aligned}   % 右寄せ

% \fbox — 枠付きボックス
\fbox{text}

% \framebox — 幅指定枠付きボックス
\framebox[5cm][c]{centered in frame}
```

### パラグラフボックス（垂直ボックス）

```latex
% \parbox
\parbox[t]{5cm}{%   % [t] = 上揃え, [c] = 中央, [b] = 下揃え
  Multi-line\\
  text
}

% minipage 環境
\begin{minipage}[t]{5cm}
  Multi-line\\
  text
\end{minipage}
```

### ルール（線）

```latex
% 水平線
\rule{5cm}{1pt}          % 幅5cm、太さ1pt
\rule[2pt]{5cm}{1pt}     % 2pt 上に持ち上げ

% 垂直スペース
\rule{0pt}{10pt}         % 幅0、高さ10pt（見えない支柱）
```

---

## フック管理

LaTeX 2020-10-01 以降の新機能。

### 既存フックへの追加

```latex
% ドキュメント開始時
\AddToHook{begindocument}{%
  \typeout{Document started!}%
}

% ドキュメント終了時
\AddToHook{enddocument}{%
  \typeout{Document ended!}%
}

% ページ先頭
\AddToHook{shipout/before}{%
  % ページ出力前の処理
}
```

### 主要フック

| フック名 | タイミング |
|---------|----------|
| `begindocument` | `\begin{document}` の直後 |
| `begindocument/before` | `\begin{document}` の直前 |
| `begindocument/end` | `\begin{document}` の処理完了後 |
| `enddocument` | `\end{document}` の直前 |
| `enddocument/afterlastpage` | 最終ページ出力後 |
| `shipout/before` | ページ出力直前 |
| `shipout/after` | ページ出力直後 |
| `cmd/<command>/before` | コマンド実行前 |
| `cmd/<command>/after` | コマンド実行後 |
| `env/<environment>/before` | 環境開始前 |
| `env/<environment>/begin` | 環境開始時 |
| `env/<environment>/end` | 環境終了時 |
| `env/<environment>/after` | 環境終了後 |

---

## 条件分岐

### `iftex` パッケージ — エンジン判定

```latex
\usepackage{iftex}

\ifPDFTeX
  % pdfLaTeX
\fi

\ifXeTeX
  % XeLaTeX
\fi

\ifLuaTeX
  % LuaLaTeX
\fi
```

### `ifthen` パッケージ — 条件分岐

```latex
\usepackage{ifthen}

\ifthenelse{\equal{#1}{draft}}{%
  % #1 が "draft" の場合
}{%
  % それ以外
}

\ifthenelse{\lengthtest{\mylength > 5cm}}{%
  % mylength が 5cm より大きい
}{%
  % それ以外
}
```

### LaTeX の基本条件分岐

```latex
% 新しいif定義
\newif\ifmydraft
\mydrafttrue   % true に設定
\mydraftfalse  % false に設定

\ifmydraft
  Draft mode
\else
  Final mode
\fi
```

---

## L3 プログラミング層

LaTeX3 の expl3 言語。より堅牢で読みやすいコード。

### 基本構文

```latex
\ExplSyntaxOn

% 変数定義
\tl_new:N \l_mypkg_name_tl         % トークンリスト
\int_new:N \l_mypkg_count_int      % 整数
\bool_new:N \l_mypkg_flag_bool     % 真偽値

% 変数設定
\tl_set:Nn \l_mypkg_name_tl { John }
\int_set:Nn \l_mypkg_count_int { 42 }
\bool_set_true:N \l_mypkg_flag_bool

% 条件分岐
\bool_if:NTF \l_mypkg_flag_bool
  { % true の場合
    \tl_use:N \l_mypkg_name_tl
  }
  { % false の場合
    Unknown
  }

% ループ
\int_step_inline:nn { 10 }
  {
    Item~#1 \par
  }

\ExplSyntaxOff
```

### 命名規則

- `\l_` : ローカル変数
- `\g_` : グローバル変数
- `\c_` : 定数
- `_tl` : トークンリスト
- `_int` : 整数
- `_bool` : 真偽値
- `:N` : 引数が単一トークン
- `:n` : 引数がブレースで囲まれた
- `:TF` : true/false 分岐

---

## doc/docstrip システム

パッケージのドキュメント化と配布。

### .dtx ファイルの構造

```latex
% mypackage.dtx
% \iffalse
%<*driver>
\documentclass{ltxdoc}
\usepackage{mypackage}
\EnableCrossrefs
\CodelineIndex
\RecordChanges
\begin{document}
  \DocInput{mypackage.dtx}
\end{document}
%</driver>
% \fi
%
% \title{The \textsf{mypackage} Package}
% \author{Your Name}
% \maketitle
%
% \section{Introduction}
% This package does something useful.
%
% \section{Usage}
% Use \cs{mycommand} like this:
% \begin{verbatim}
% \mycommand{argument}
% \end{verbatim}
%
% \StopEventually{\PrintIndex\PrintChanges}
%
% \section{Implementation}
%
%    \begin{macrocode}
%<*package>
\NeedsTeXFormat{LaTeX2e}
\ProvidesPackage{mypackage}[2024/01/15 v1.0 My Package]

\newcommand{\mycommand}[1]{%
  \textbf{#1}%
}
%</package>
%    \end{macrocode}
%
% \Finale
\endinput
```

### docstrip によるコード抽出

```latex
% mypackage.ins
\input docstrip.tex
\keepsilent

\usedir{tex/latex/mypackage}

\preamble
This is mypackage.sty
\endpreamble

\generate{\file{mypackage.sty}{\from{mypackage.dtx}{package}}}

\endbatchfile
```

実行：

```bash
latex mypackage.ins     # mypackage.sty を生成
pdflatex mypackage.dtx  # ドキュメント（PDF）を生成
makeindex -s gind.ist mypackage.idx
makeindex -s gglo.ist -o mypackage.gls mypackage.glo
pdflatex mypackage.dtx  # 索引込みで再生成
```

---

## l3build — モダンな開発環境

LaTeX パッケージのテスト・ビルド・リリースを自動化。

### build.lua の基本

```lua
-- build.lua
module = "mypackage"

sourcefiles = {"*.dtx", "*.ins"}
installfiles = {"*.sty"}
typesetfiles = {"*.dtx"}

checkengines = {"pdftex", "xetex", "luatex"}
```

### l3build コマンド

```bash
l3build check      # テスト実行
l3build doc        # ドキュメント生成
l3build install    # ローカルインストール
l3build unpack     # .dtx から .sty を抽出
l3build ctan       # CTAN用アーカイブ作成
l3build upload     # CTANにアップロード
```

### テスト作成

```latex
% testfiles/test1.lvt
\input{regression-test}

\START
\RequirePackage{mypackage}

\TEST{Basic command}{
  \mycommand{test}
}

\END
```

テスト実行：

```bash
l3build check
```

---

## パッケージファイルの完全な例

```latex
% example.sty
\NeedsTeXFormat{LaTeX2e}
\ProvidesPackage{example}[2024/01/15 v1.0 Example Package]

% --- 依存パッケージ ---
\RequirePackage{xcolor}
\RequirePackage{xkeyval}

% --- オプション処理 ---
\define@boolkey{example}{draft}[true]{}
\define@choicekey{example}{color}{red,blue,green}[blue]{%
  \def\example@color{#1}%
}

\setkeys{example}{draft=false, color=blue}
\ProcessOptionsX

% --- 内部マクロ ---
\newcommand{\example@format}[1]{%
  \ifexample@draft
    \textcolor{red}{[DRAFT: #1]}%
  \else
    \textcolor{\example@color}{#1}%
  \fi
}

% --- ユーザーコマンド ---
\newcommand{\highlight}[1]{%
  \example@format{#1}%
}

% --- 環境 ---
\newenvironment{exampleenv}
  {\begin{center}\example@format\bgroup}
  {\egroup\end{center}}

\endinput
```

使用例：

```latex
\usepackage[draft, color=red]{example}

\highlight{Important text}

\begin{exampleenv}
  Centered highlighted text
\end{exampleenv}
```

---

## まとめ

### パッケージ開発のステップ

1. **.sty または .cls ファイルを作成**
2. **`\NeedsTeXFormat` と `\ProvidesPackage` で識別**
3. **依存パッケージを `\RequirePackage` で読み込み**
4. **オプション宣言と処理**
5. **コマンド・環境定義**
6. **`\endinput` で終了**

### ドキュメント化

- **.dtx + .ins** で doc/docstrip システム使用
- **l3build** でテスト・ビルドを自動化
- **ドキュメントに使用例を含める**

### ベストプラクティス

- **ロバストなコマンドを定義**（`\DeclareRobustCommand`）
- **内部マクロに `@` を使用**（`\makeatletter`/`\makeatother`）
- **名前空間を尊重**（`\mypkg@internal` のようなプレフィックス）
- **フックを活用**（LaTeX 2020-10-01 以降）
- **L3 プログラミング層の活用を検討**
