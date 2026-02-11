# ビジュアルデザイン

LaTeXは印刷物の高品質な組版のみならず、フォトブック、カレンダー、グリーティングカード、カラフルなプレゼンテーションなど、非標準ドキュメントのデザインにも対応できます。本リファレンスでは、装飾、背景画像、カレンダー、インタラクティブな要素の作成方法をまとめます。

---

## 背景画像の追加

### 必要なパッケージ

```latex
\usepackage{background}
```

### 基本設定

```latex
\backgroundsetup{
  scale = 1,
  angle = 0,
  opacity = 0.2,
  contents = {\includegraphics[width=\paperwidth, height=\paperheight, keepaspectratio]{image.pdf}}
}
```

### 主要オプション

| オプション | 説明 | デフォルト値 |
|-----------|------|------------|
| `contents` | 背景に表示するテキスト・画像・描画コマンド | `Draft` |
| `placement` | 配置（`center`, `top`, `bottom`） | `center` |
| `color` | TikZ形式の色指定 | `red!45` |
| `angle` | 回転角度（-360〜360） | `0`（top/bottom）、`60`（center） |
| `opacity` | 透明度（0〜1） | `0.5` |
| `scale` | 拡大率 | top/bottom: `8`、center: `15` |
| `hshift`, `vshift` | 水平・垂直シフト | `0pt` |

### 動的コンテンツの利用例

```latex
\backgroundsetup{
  placement = top,
  angle = 0,
  scale = 4,
  color = blue!80,
  vshift = -2ex,
  contents = {--\thepage--}
}
```

### TikZ描画との組み合わせ

```latex
\usetikzlibrary{calc}
\backgroundsetup{
  angle = 0,
  scale = 1,
  contents = {
    \tikz[overlay, remember picture]
    \draw[rounded corners=20pt, line width=1pt, color=blue, fill=yellow!20]
      ($(current page.north west)+(1,-1)$)
      rectangle ($(current page.south east)+(-1,1)$);
  }
}
```

**注意**: `background` パッケージはTikZと `everypage` パッケージに依存しており、正確な配置のために複数回コンパイルが必要な場合があります。

---

## 装飾オーナメント (pgfornament)

### 必要なパッケージ

```latex
\usepackage{pgfornament}
\usetikzlibrary{calc}
```

### 基本コマンド

```latex
\pgfornament[options]{番号}
```

### 主要オプション

| オプション | 説明 | デフォルト |
|-----------|------|----------|
| `scale` | 拡大率 | `1` |
| `width`, `height` | 幅・高さ指定 | - |
| `color` | 色指定 | - |
| `ydelta` | 垂直シフト | - |
| `symmetry` | 対称性（`v`, `h`, `c`, `none`） | `none` |

### グリーティングカード例

```latex
\documentclass[a6paper,landscape,fontsize=30pt]{scrartcl}
\areaset{0.9\paperwidth}{0.68\paperheight}
\pagestyle{empty}

\usepackage[T1]{fontenc}
\usepackage{calligra}
\usepackage{pgfornament}
\usetikzlibrary{calc}

\begin{document}
\centering
\begin{tikzpicture}[
  pgfornamentstyle/.style={color=green!50!black, fill=green!80!black},
  every node/.style={inner sep=0pt}
]
  \node[text width=8cm, outer sep=1.2cm, text centered, color=red!90!black] (Greeting)
    {\calligra Happy Birthday,\\Dear Mom!\\[-1ex]
     \pgfornament[color=red!90!black, width=2.5cm]{72}};

  \foreach \corner/\sym in {north west/none, north east/v, south west/h, south east/c} {
    \node[anchor=\corner] (\corner) at (Greeting.\corner)
      {\pgfornament[width=2cm, symmetry=\sym]{63}};
  }

  \path (north west) -- (south west)
    node[midway, anchor=east] {\pgfornament[height=2cm]{9}}
        (north east) -- (south east)
    node[midway, anchor=west] {\pgfornament[height=2cm, symmetry=v]{9}};

  \pgfornamenthline{north west}{north east}{north}{87}
  \pgfornamenthline{south west}{south east}{south}{87}
\end{tikzpicture}
\end{document}
```

### ページ背景へのオーナメント配置

```latex
\usepackage{pgfornament}
\usepackage{background}

\backgroundsetup{
  angle = 0,
  scale = 1,
  opacity = 1,
  color = black!60,
  contents = {
    \begin{tikzpicture}[remember picture, overlay]
      \foreach \pos/\sym in {north west/none, north east/v, south west/h, south east/c} {
        \node[anchor=\pos] at (current page.\pos)
          {\pgfornament[width=2cm, symmetry=\sym]{63}};
      }
    \end{tikzpicture}
  }
}
```

**補足**: pgfornamentは現在196個の高品質ヴィンテージオーナメントを提供しています。

---

## 見出しデザイン (titlesec)

### 必要なパッケージ

```latex
\PassOptionsToPackage{svgnames}{xcolor}
\usepackage{tikz}
```

### カスタム見出しマクロ

```latex
\newcommand{\tikzhead}[1]{%
  \begin{tikzpicture}[remember picture, overlay]
    \node[yshift=-2cm] at (current page.north west)
      {\begin{tikzpicture}[remember picture, overlay]
         \path[draw=none, fill=LightSkyBlue] (0,0)
           rectangle (\paperwidth, 2cm);
         \node[anchor=east, xshift=.9\paperwidth, rectangle, rounded corners=15pt,
               inner sep=11pt, fill=MidnightBlue, font=\sffamily\bfseries]
           {\color{white}#1};
       \end{tikzpicture}
      };
  \end{tikzpicture}
}
```

### ヘッダーへの統合例

```latex
\usepackage[automark]{scrlayer-scrpage}
\clearscrheadings
\ihead{\tikzhead{\headmark}}
\pagestyle{scrheadings}
```

---

## カレンダー生成

### 必要なパッケージ

```latex
\usepackage{tikz}
\usetikzlibrary{calendar,positioning}
```

### 年間カレンダー例

```latex
\documentclass{article}
\usepackage[margin=2.5cm, a4paper]{geometry}
\pagestyle{empty}

\usepackage{tikz}
\usetikzlibrary{calendar,positioning}

\newcommand{\calyear}{2025}
\newcommand{\mon}[1]{%
  \calendar[dates=\calyear-#1-01 to \calyear-#1-last]
    if (Sunday) [red];
}

\begin{document}
\begin{tikzpicture}[every calendar/.style={
    month label above centered,
    month text={\Large\textsc{\%mt}},
    week list
  }]
  \matrix (Calendar) [column sep=4em, row sep=3em] {
    \mon{01} & \mon{02} & \mon{03} \\
    \mon{04} & \mon{05} & \mon{06} \\
    \mon{07} & \mon{08} & \mon{09} \\
    \mon{10} & \mon{11} & \mon{12} \\
  };
  \node[above=1cm of Calendar, font=\Huge] {\calyear};
\end{tikzpicture}
\end{document}
```

---

## キー・メニュー・ターミナル表示

### menukeysパッケージ

```latex
\usepackage{menukeys}
```

#### 主要コマンド

| コマンド | 用途 | 例 |
|---------|------|-----|
| `\keys{組み合わせ}` | キーボード操作 | `\keys{\cmd + T}` |
| `\menu{シーケンス}` | メニュー項目 | `\menu{File > Save}` |
| `\directory{パス}` | ファイルパス | `\directory{/usr/bin}` |

#### 使用例

```latex
In the main menu, click \menu{Typeset > pdfLaTeX} for choosing the \TeX\ compiler.
Then press \keys{\cmd + T} for typesetting.
The program is installed in \directory{/Applications/TeX/TeXworks.app}.
```

### sim-os-menusパッケージ（コンテキストメニュー・ターミナル）

```latex
\usepackage{xfp}  % TeX Live 2023+ では不要
\usepackage{sim-os-menus}
```

#### コンテキストメニュー

```latex
\ContextMenu[Font=\sffamily]{
  Open,
  Open with(>),
  Rename,
  Run(>)(*),
  Delete §
  LaTeX, BibTeX, MakeIndex
}
```

**記法説明**:
- `(>)`: 右矢印表示
- `(*)`: 新レベル開始（レベルごとに1回）
- `§`: 次レベルの区切り

#### ターミナルウィンドウ

```latex
\begin{TermMac}{hbox}
  stefan@laptop ~ % ping latex.org
  ...
  stefan@laptop ~ %
\end{TermMac}
```

**環境オプション**:
- `TermMac`: macOSスタイル
- `TermUnix`: Unix/Linuxスタイル
- `TermWin`: Windowsスタイル

**カスタマイズ例**:

```latex
\begin{TermMac}[Title=stefan - shell, Width=10cm]{sharpish corners}
  ...
\end{TermMac}
```

---

## パズル風レイアウト

### thematicpuzzleパッケージ

```latex
\usepackage{xfp}  % TeX Live 2023+ では不要
\usepackage{thematicpuzzle}
\usepackage{fontawesome5}  % アイコン使用時
```

### 使用例

```latex
\ThematicPuzzle[
  FontLabels={\tiny\sffamily},
  Labels={Editor, LaTeX, BibTeX, MakeIndex, Tools, PDF},
  BgColors={green!90, yellow!20, red!20, blue!20, orange!60, yellow!30},
  IconsColor={red!90!black}
]{
  \faEdit, \faFileExport, \faBookOpen,
  \faClipboardList, \faTools, \faFilePdf
}
```

**主要オプション**:
- `FontLabels`: ラベルフォント指定
- `Labels`: パズルピース下のラベルリスト
- `BgColors`: 各ピースの背景色
- `IconsColor`: アイコンとラベルの色

---

## ワードクラウド

### 必要なパッケージ（LuaLaTeX必須）

```latex
\usepackage{wordcloud}
```

### 基本コマンド

```latex
\wordcloud[オプション]{(単語,重み);(単語,重み);...}
```

### 手動指定例

```latex
\textsf{
  \wordcloud[scale=1, rotate=45, margin=0.5pt, usecolor]{
    (\textrm{\LaTeX},10);
    (graphics,6);
    (fonts,7);
    (images,5);
    (tables,5);
    (PDF,5);
    (commands,4)
  }
}
```

### ファイルからの自動生成

```latex
\wordcloudFile[usecolor]{document.txt}{80}
```

**除外ワード指定**:

```latex
\wordcloudIgnoreWords{you, just, want, from, for, the, same}
```

**注意事項**:
- LuaLaTeXコンパイラ必須
- Lua解析、MetaPost生成、luamplib実行の3ステップで動作
- PDF変換にはpdftotext（Xpdf/Poppler）を使用可能

---

## 判断基準テーブル

| 目的 | 推奨手法 | 代替案 |
|------|---------|-------|
| 透かし・レターヘッド | `background` | `watermark`, `eso-pic` |
| ページコーナー装飾 | `pgfornament` | フォントオーナメント（`fourier-orns`, `adforn`） |
| 見出しスタイル変更 | `titlesec` | KOMA-Script（`headings=small`） |
| カレンダー生成 | TikZ `calendar` ライブラリ | 外部ツール |
| キー/メニュー表示 | `menukeys` | `sim-os-menus`（コンテキストメニュー対応） |
| ターミナル出力表示 | `sim-os-menus` (TermMac/Unix/Win) | `tcolorbox`（直接記述） |
| トピック配置 | `thematicpuzzle` | `jigsaw`（大規模パズル） |
| ワードクラウド | `wordcloud` (LuaLaTeX) | 外部ツール→画像挿入 |

---

## 実用的ヒント

1. **複数コンパイルの必要性**: `background`, `pgfornament`はTikZ/everypageに依存し、正確な配置に2-3回のコンパイルが必要
2. **色設定**: `xcolor` パッケージの混色記法（`blue!80`, `green!50!black`）を活用
3. **フォントオーナメント**: pgfornamentの代わりに、フォントベースのオーナメント（`fourier-orns`, `adforn`, `webomints`）も選択肢
4. **カレンダーカスタマイズ**: TikZ manualに詳細な日付計算機能とスタイルオプションが記載（https://texdoc.org/pkg/tikz）
5. **ターミナル模倣**: `sim-os-menus` は `tcolorbox` を内部利用しており、多数のカスタマイズオプション利用可能
