# Beamerプレゼンテーション

Beamerは学術プレゼンテーションに最適なLaTeXドキュメントクラス。プレゼンテーションスライドを高品質に作成でき、数式や参考文献をネイティブにサポートする。

## 基本構造

### ドキュメントクラス宣言

```latex
\documentclass[11pt]{beamer}
\usetheme{Berlin}
\usecolortheme{beaver}
```

利用可能なオプション:
- フォントサイズ: `8pt`, `9pt`, `10pt`, `smaller`, `11pt`（デフォルト）, `12pt`, `bigger`, `14pt`, `17pt`, `20pt`
- アスペクト比: `aspectratio=43`（デフォルト）, `169`, `1610`, `149`, `141`, `54`, `32`
- ナビゲーション圧縮: `compress`

## フレーム構造

フレームは8つのコンポーネントから構成される:

| コンポーネント | 説明 |
|--------------|------|
| **headline/footline** | ヘッダー/フッター（テーマが自動生成） |
| **sidebars** | サイドバー（目次表示用） |
| **navigation bars** | ナビゲーションバー（進行状況表示） |
| **navigation symbols** | 8つのデフォルト記号（右下隅） |
| **logo** | ロゴ（`\logo{}`で全フレームに配置） |
| **frame title** | フレームタイトル（`\frametitle{}`） |
| **background** | 背景（canvas + main background） |
| **frame contents** | フレーム本文 |

### フレーム作成

```latex
% コマンド形式
\frame[オプション]{
  \frametitle{タイトル}
  \framesubtitle{サブタイトル}
  内容
}

% 環境形式（推奨）
\begin{frame}[t]
  \frametitle{タイトル}
  内容
\end{frame}
```

垂直配置オプション:
- `t`: 上揃え
- `c`: 中央揃え（デフォルト）
- `b`: 下揃え

## タイトルページ

### タイトル情報定義

プリアンブルで定義:

```latex
\title[短縮タイトル]{完全なタイトル}
\subtitle{サブタイトル}
\author[短縮名]{著者名 \inst{1} \and 著者名2 \inst{2}}
\institute[短縮所属]{
  \inst{1} 所属1 \\
  \and
  \inst{2} 所属2
}
\date[短縮日付]{完全な日付}
\titlegraphic{\includegraphics[width=20mm]{logo}}
```

### タイトルページ生成

```latex
\frame[plain]{\titlepage}
```

`plain`オプションでheadline/footline/sidebarを非表示化。

## プレゼンテーションテーマ

### テーマ読み込み

```latex
\usetheme[オプション]{テーマ名}
\usecolortheme[オプション]{カラーテーマ名}
\usefonttheme[オプション]{フォントテーマ名}
\useinnertheme[オプション]{内側テーマ名}
\useoutertheme[オプション]{外側テーマ名}
```

### プレゼンテーションテーマ一覧

#### ナビゲーションバーなし

| テーマ | 特徴 |
|-------|------|
| **default** | ミニマルなデザイン |
| **Bergen** | inmargin + rectangles内側テーマベース |
| **Boadilla** | 少スペースで多情報。`secheader`オプションでセクション表示 |
| **Madrid** | Boadillaの強調色版 |
| **AnnArbor** | Boadillaのミシガン大学配色 |
| **CambridgeUS** | BoadillaのMIT配色 |
| **Pittsburgh** | シンプル、右寄せタイトル |
| **Rochester** | 目立つデザイン。`height`オプションでタイトルバー高さ調整 |

#### ツリー型ナビゲーション

| テーマ | 特徴 |
|-------|------|
| **Antibes** | 上部に矩形ナビゲーション |
| **JuanLesPins** | Antibesの滑らかな外観 |
| **Montpellier** | シンプルなナビゲーションヒント |

#### サイドバー型

| テーマ | 特徴 | オプション |
|-------|------|-----------|
| **Berkeley** | サイドバーに目次、現在項目をハイライト | `hideallsubsections`, `hideothersubsections`, `right`, `width=20mm` |
| **PaloAlto** | Berkeley類似 | 同上 |
| **Goettingen** | 完全な目次をサイドバー表示 | 同上 |
| **Marburg** | Goettingen類似 | 同上 |
| **Hannover** | 左サイドバー、右寄せタイトル | `hideallsubsections`, `hideothersubsections`, `width` |

#### ミニフレームナビゲーション

| テーマ | 特徴 |
|-------|------|
| **Berlin** | headline/footlineに多情報。`compress`で1行化 |
| **Ilmenau** | Berlin類似 |
| **Dresden** | Berlin類似 |
| **Darmstadt** | ナビゲーションと本文の強い分離 |
| **Frankfurt** | Darmstadtの簡潔版 |
| **Singapore** | 控えめなナビゲーション |
| **Szeged** | 水平線が支配的 |

#### セクション/サブセクションテーブル

| テーマ | 特徴 |
|-------|------|
| **Copenhagen** | 上部にセクション/サブセクション、下部にタイトル/著者 |
| **Luebeck** | Copenhagenの変種 |
| **Malmoe** | Copenhagenの簡潔版 |
| **Warsaw** | Copenhagenの強調版 |

### カラーテーマ一覧

#### デフォルト・特殊用途

| テーマ | 用途 |
|-------|------|
| **default** | 最小限の色使用 |
| **sidebartab** | サイドバーの現在項目を背景色で強調 |
| **structure** | 構造色変更。`rgb={r,g,b}`, `RGB={r,g,b}`, `cmyk={c,m,y,k}`, `hsb={h,s,b}`, `named={色名}`オプション |

#### 完全カラーテーマ

| テーマ | 特徴 |
|-------|------|
| **albatross** | 青地に黄色。`overlystylish`オプションで背景canvas追加 |
| **beetle** | グレー背景に白/黒テキスト |
| **crane** | ルフトハンザの配色 |
| **dove** | ほぼモノクロ（グレースケールのみ使用） |
| **fly** | beetle類似、白/黒/グレー |
| **seagull** | 多様なグレーの陰影 |
| **wolverine** | ミシガン大学配色 |
| **beaver** | MIT配色 |

#### 内側カラーテーマ

| テーマ | 効果 |
|-------|------|
| **lily** | ブロックの背景色を除去 |
| **orchid** | 暗地に白文字、alert/exampleブロックは赤/緑背景 |
| **rose** | ブロックタイトル/本文に半透明背景 |

#### 外側カラーテーマ

| テーマ | 効果 |
|-------|------|
| **whale** | headline/footline/sidebarに暗地白文字 |
| **seahorse** | headline/footline/sidebarに半透明背景 |
| **dolphin** | whaleとseahorseの中間 |

### フォントテーマ

| テーマ | 効果 | オプション |
|-------|------|-----------|
| **default** | 全文sans serif | - |
| **serif** | 全文serif | `stillsansserifmath`, `stillsansserifsmall`, `stillsansseriflarge`, `stillsansseriftext`, `onlymath` |
| **structurebold** | タイトル・ヘッダー等を太字化 | `onlysmall`, `onlylarge` |
| **structureitalicserif** | structureboldのserif + italic版 | 同上 |
| **structuresmallcapsserif** | structureboldのserif + small caps版 | 同上 |

### 内側テーマ

| テーマ | 効果 |
|-------|------|
| **default** | itemizeの項目が小三角 |
| **circles** | 項目が小円 |
| **rectangles** | 項目が小矩形 |
| **rounded** | 項目が小球。`shadow`オプションで影追加 |
| **inmargin** | ブロックタイトル/項目マークが左側、本文が右側 |

### 外側テーマ

| テーマ | 効果 | オプション |
|-------|------|-----------|
| **default** | headline/footlineなし、左寄せタイトル | - |
| **infolines** | headlineにセクション/サブセクション、footlineに著者/所属/タイトル/日付/フレーム番号 | - |
| **miniframes** | headlineにセクション毎の小円ナビゲーション | `subsection=false`, `footline=authorinstitute` 等 |
| **sidebar** | サイドバーに目次、フレームタイトルが垂直中央 | `height=10mm`, `hideothersubsections`, `hideallsubsections`, `right`, `width=wdim` |
| **split** | headlineの左にセクション、右にサブセクション | - |
| **shadow** | splitに水平シェーディングと影を追加 | - |
| **tree** | headline3行でナビゲーションツリー | `hooks` |

## フレームサイズ

### アスペクト比設定

デフォルトは128mm × 96mm（4:3）。

```latex
\documentclass[aspectratio=169]{beamer}
```

| 値 | アスペクト比 | サイズ |
|----|------------|--------|
| **1610** | 16:10 | 160mm × 100mm |
| **169** | 16:9 | 160mm × 90mm |
| **149** | 14:9 | 140mm × 90mm |
| **141** | 1.41:1 | 148.5mm × 105mm |
| **54** | 5:4 | 125mm × 100mm |
| **43** | 4:3 | 128mm × 96mm（デフォルト） |
| **32** | 3:2 | 135mm × 90mm |

### フレーム縮小

```latex
% 項目間の垂直スペースをゼロに
\begin{frame}[squeeze]
  ...
\end{frame}

% 5%縮小
\begin{frame}[shrink=5]
  ...
\end{frame}
```

### headline/footline/sidebar除去

```latex
\begin{frame}[plain]
  % headline/footline/sidebarが非表示
  \includegraphics[width=\textwidth]{large-figure}
\end{frame}
```

### フレーム自動分割

```latex
% 長い参考文献リスト等を自動分割
\begin{frame}[allowframebreaks]
  \frametitle{参考文献}
  \bibliographystyle{apalike}
  \bibliography{mybib}
\end{frame}
% スライドが自動的に "参考文献 I", "参考文献 II", ... と番号付けされる
```

## オーバーレイ（段階的表示）

### \pauseコマンド

最も簡単な段階的表示:

```latex
\begin{frame}
  \frametitle{季節} \pause
  \begin{enumerate}
    \item 夏 \pause
    \item 秋 \pause
    \item 冬 \pause
    \item 春
  \end{enumerate}
\end{frame}
% 5枚のスライドに自動分割される
```

### 増分指定 <+->

リスト環境全体に適用:

```latex
% 各項目を順次表示
\begin{frame}
  \frametitle{季節}
  \begin{enumerate}[<+->]
    \item 夏
    \item 秋
    \item 冬
    \item 春
  \end{enumerate}
\end{frame}

% 複数リストに適用
\begin{frame}[<+->]
  \frametitle{動物}
  \begin{itemize}
    \item 牛
    \item 山羊
  \end{itemize}
  \begin{itemize}
    \item ライオン
    \item トラ
  \end{itemize}
\end{frame}

% 現在項目をハイライト
\begin{frame}
  \frametitle{季節}
  \begin{enumerate}[<+- | alert@+>]
    \item 夏
    \item 秋
    \item 冬
  \end{enumerate}
\end{frame}
```

### オーバーレイ指定ルール

| 指定 | 意味 |
|------|------|
| `<3>` | スライド3のみ |
| `<1,2,4>` | スライド1, 2, 4のみ |
| `<3-6>` | スライド3〜6 |
| `<3->` | スライド3以降すべて |
| `<-4>` | スライド1〜4 |
| `<2,4-6,8,11->` | スライド2, 4〜6, 8, 11以降 |

### オーバーレイ対応コマンド

| コマンド | 例 | 効果 |
|---------|---|------|
| `\textbf<>{}` | `\textbf<3>{太字}` | 指定スライドで太字、他は通常 |
| `\textit<>{}` | `\textit<4>{斜体}` | 指定スライドで斜体、他は通常 |
| `\alert<>{}` | `\alert<1>{警告}` | 指定スライドで赤色、他は通常 |
| `\color<>[]{}{}` | `\color<2>[rgb]{0,0,1}{青}` | 指定スライドで青色、他は通常 |
| `\only<>{}` | `\only<1>{テキスト}` | 指定スライドのみ表示、他はスペース解放 |
| `\onslide<>{}` | `\onslide<2>{テキスト}` | 指定スライドのみ表示、他はスペース確保 |
| `\uncover<>{}` | `\uncover<3>{テキスト}` | 指定スライドで表示、他は透明/カバー |
| `\visible<>{}` | `\visible<4>{テキスト}` | 指定スライドで表示、他はスペース確保 |
| `\invisible<>{}` | `\invisible<5>{テキスト}` | 指定スライドで非表示、他は表示 |
| `\alt<>{}{]` | `\alt<6>{A}{B}` | 指定スライドでA、他でB |
| `\temporal<>{}{}{}` | `\temporal<7>{前}{中}{後}` | 指定前/指定中/指定後 |
| `\item<>` | `\item<8> 項目` | 指定スライドのみ表示 |

### 実例: 複雑なオーバーレイ

```latex
\begin{frame}
  \uncover<1->{インドの首都は:}
  \begin{enumerate}
    \item<2-> ムンバイ
    \item<4-> \color<6>[rgb]{0,0,1}{ニューデリー}
  \end{enumerate}
  \vskip 10mm
  \only<3-5>{ヒント:}
  \begin{enumerate}
    \item<3-5> ムンバイはボリウッドで有名
    \item<5> 国会議事堂はニューデリーにある
  \end{enumerate}
\end{frame}
% 6枚のスライドに分割
```

## ブロック環境

### 基本ブロック

```latex
\begin{frame}
  \begin{block}{ルール}
    amsmathとamsymbパッケージを読み込む。
  \end{block}

  \begin{alertblock}<2->{警告}
    数式は数式モードで記述する。
  \end{alertblock}

  \begin{exampleblock}{例}<3>
    $\sin^2\theta + \cos^2\theta = 1$
  \end{exampleblock}
\end{frame}
```

オーバーレイ指定は見出し引数の前後どちらでも可。

### 角丸・影付きブロック

プリアンブルに追加:

```latex
\setbeamertemplate{blocks}[rounded][shadow=true]
```

### 定理環境

```latex
\begin{frame}
  \begin{theorem}
    $(a+b)^2 = a^2 + 2ab + b^2$
  \end{theorem}

  \begin{proof}<2->
    $(a+b)^2 = (a+b)(a+b) = a^2 + 2ab + b^2$
  \end{proof}

  \begin{example}<3->[和の平方]
    $(3+5)^2 = 3^2 + 2 \times 3 \times 5 + 5^2 = 64$
  \end{example}
\end{frame}
```

利用可能な定理環境:
- `theorem`, `proof`, `definition`, `definitions`, `corollary`, `example`, `examples`, `fact`

オプション引数で見出しを追加（`proof`では置き換え）。

## 表と図のオーバーレイ

### 表のオーバーレイ制御

```latex
\begin{frame}
  \frametitle{結果}

  % 表全体をスライド2のみ表示
  \only<2>{\color<2>[rgb]{1,0.3,0.5}{
    \begin{table}
      \begin{tabular}{cccc}
        \hline
        & 合計 & 合格 & 合格率 \\
        \hline
        男子 & 56 & 50 & 89.3\% \\
        女子 & 38 & 36 & 94.7\% \\
        \hline
      \end{tabular}
    \end{table}
  }}

  % セル単位のオーバーレイ
  \onslide<4->{\begin{table}
    \begin{tabularx}{\linewidth}{XXXX}
      \hline
      & 合計 & 合格 & 合格率 \\
      \hline
      \uncover<5->{\alert<5>{男子}} &
      \uncover<5->{\alert<5>{52}} &
      \uncover<5->{\alert<5>{49}} &
      \uncover<5->{\alert<5>{94.2\%}} \\
      \uncover<6>{\alert<6>{女子}} &
      \uncover<6>{\alert<6>{46}} &
      \uncover<6>{\alert<6>{41}} &
      \uncover<6>{\alert<6>{89.1\%}} \\
      \hline
    \end{tabularx}
  \end{table}}
\end{frame}
```

### 図のオーバーレイ制御

```latex
\begin{frame}
  \frametitle{動物}

  % スライド2のみ表示
  \includegraphics<2>[width=5cm]{tiger}

  % スライド2と5で表示
  \includegraphics<2,5>[width=5cm]{lion}
\end{frame}
```

## columns環境（左右分割レイアウト）

```latex
\begin{frame}
  \frametitle{ページレイアウト}
  レイアウトの構成を以下に示す: \pause\vskip 5mm

  \begin{columns}
    \column{0.4\textwidth}
    \includegraphics[width=\textwidth]{layout}

    \column{0.6\textwidth}
    \begin{itemize}[<+- | alert@+>]
      \item ページは複数のコンポーネントで構成
      \item コンポーネントは長さ単位で指定
      \item コンポーネントの長さは手動変更可能
    \end{itemize}
  \end{columns}
\end{frame}
```

各`\column{幅}`でカラムを定義。

## スライド繰り返し

以前のフレームの特定スライドを再表示:

```latex
% ラベル付きフレーム
\begin{frame}[label=stress]
  \frametitle{重要事項}
  \begin{enumerate}
    \item 第一点
    \item 第二点
    \item 第三点
  \end{enumerate}
\end{frame}

% 中間のフレーム
\begin{frame}
  ...
\end{frame}

% スライド3を再表示
\againframe<3>{stress}

% フレーム全体を再表示
\againframe{stress}
```

`\againframe`はフレーム外で使用。

## ハイパーリンクとボタン

### ボタンコマンド

| コマンド | 表示 |
|---------|------|
| `\beamerbutton{テキスト}` | シンプルなボタン |
| `\beamergotobutton{テキスト}` | 右矢印付きボタン |
| `\beamerreturnbutton{テキスト}` | 左矢印付きボタン |
| `\beamerskipbutton{テキスト}` | 二重右矢印付きボタン |

### ハイパーリンクコマンド

| コマンド | 用途 |
|---------|------|
| `\hyperlink<>{ラベル<スライド>}{ボタン}` | 指定スライドへリンク |
| `\hyperlinkframestart<>{ラベル}{ボタン}` | 現フレームの最初 |
| `\hyperlinkframeend<>{ラベル}{ボタン}` | 現フレームの最後 |
| `\hyperlinkframestartnext<>{}{ボタン}` | 次フレームの最初 |
| `\hyperlinkframeendprev<>{}{ボタン}` | 前フレームの最後 |
| `\hyperlinkpresentationstart<>{}{ボタン}` | プレゼン開始 |
| `\hyperlinkpresentationend<>{}{ボタン}` | プレゼン終了 |

### 実例: 双方向リンク

```latex
% ターゲットフレーム
\begin{frame}[label=layout]
  \frametitle{ページレイアウト}
  \begin{columns}
    \column{0.4\textwidth}
    \includegraphics[width=\textwidth]{layoutpic}

    \column{0.6\textwidth}
    \begin{itemize}[<+- | alert@+>]
      \item ページは複数コンポーネントで構成
        \hfill
        \hyperlink<2>{LaTeX<3>}{\beamerreturnbutton{戻る}}
      \item コンポーネントは長さ単位で指定
      \item 長さは手動変更可能
    \end{itemize}
  \end{columns}
\end{frame}

% リンク元フレーム
\begin{frame}[label=LaTeX]
  \frametitle{LaTeXコンポーネント}
  \begin{itemize}[<+- | alert@+>]
    \item フォント選択
    \item テキスト整形
    \item ページレイアウト
      \hfill
      \hyperlink<3>{layout<2>}{\beamergotobutton{レイアウト図}}
    \item 表、図、数式等
  \end{itemize}
\end{frame}
```

## 目次のオーバーレイ

### 基本的な目次

```latex
\section*{概要}
\begin{frame}
  \frametitle{プレゼンテーション概要}
  \tableofcontents
\end{frame}
```

### セクション毎の段階的表示

```latex
\begin{frame}
  \frametitle{概要}
  \tableofcontents[pausesections]
\end{frame}
```

### 現在セクションのみ表示

各`\section`直後に配置:

```latex
\section{導入}
\frame{\tableofcontents[currentsection]}

\begin{frame}
  ...
\end{frame}
```

### 現在サブセクションのみ表示

各`\subsection`直後に配置:

```latex
\subsection{定義}
\frame{\tableofcontents[currentsubsection]}

\begin{frame}
  ...
\end{frame}
```

## ロゴ配置

### 全フレームに配置

```latex
\logo{\includegraphics[width=8mm]{logo}}
```

### タイトルページのみ

```latex
\titlegraphic{\includegraphics[width=20mm]{logo}}
```

### フッターに配置

```latex
\institute[TU \quad \epsfig{file=logo.eps,width=10mm}]{}
```

注意: `[]`内に別のオプション引数を持つコマンド（例: `\includegraphics[]{}`)は使用不可。

## verbatimテキスト

```latex
\begin{frame}[containsverbatim]
  \frametitle{コード例}
  \verb|System.out.println("Hello");|

  \begin{verbatim}
def hello():
    print("Hello")
  \end{verbatim}
\end{frame}
```

`containsverbatim`オプション必須（オーバーレイ指定との併用不可）。

## 参考文献

### BibTeX使用

```latex
\begin{frame}[allowframebreaks]
  \frametitle{参考文献}
  \bibliographystyle{apalike}
  \bibliography{mybib}
\end{frame}
```

`allowframebreaks`で長い文献リストを自動分割。

### 手動作成

```latex
\begin{frame}
  \frametitle{参考文献}
  \begin{thebibliography}{99}
    \bibitem{key1} 著者名 (2023). タイトル. 出版社.
    \bibitem{key2} 著者名 (2024). タイトル. ジャーナル.
  \end{thebibliography}
\end{frame}
```

## 完全な最小テンプレート

```latex
\documentclass{beamer}
\usetheme{Berlin}
\usecolortheme{beaver}

% タイトル情報
\title[短縮タイトル]{完全なプレゼンテーションタイトル}
\subtitle{サブタイトル}
\author[著者名]{著者フルネーム}
\institute[所属]{所属機関}
\date{\today}

\begin{document}

% タイトルページ
\frame[plain]{\titlepage}

% 目次
\section*{概要}
\begin{frame}
  \frametitle{プレゼンテーション概要}
  \tableofcontents
\end{frame}

% 本編
\section{導入}
\subsection{背景}
\begin{frame}
  \frametitle{背景}
  \begin{itemize}[<+->]
    \item 第一項目
    \item 第二項目
    \item 第三項目
  \end{itemize}
\end{frame}

\subsection{目的}
\begin{frame}
  \frametitle{研究目的}
  \begin{block}{目的}
    本研究の目的は...
  \end{block}
\end{frame}

\section{方法}
\begin{frame}
  \frametitle{実験方法}
  \begin{columns}
    \column{0.5\textwidth}
    \includegraphics[width=\textwidth]{setup}

    \column{0.5\textwidth}
    \begin{enumerate}
      \item 準備
      \item 実施
      \item 分析
    \end{enumerate}
  \end{columns}
\end{frame}

% 参考文献
\section*{}
\begin{frame}[allowframebreaks]
  \frametitle{参考文献}
  \bibliographystyle{apalike}
  \bibliography{mybib}
\end{frame}

% 謝辞
\section*{}
\begin{frame}
  \begin{center}
    \Large{\textcolor{blue}{ご清聴ありがとうございました}}
  \end{center}
\end{frame}

\end{document}
```

## ポスター作成（beamerposter）

beamerposterパッケージを使用してA0/A1サイズの学術ポスターを作成する。

### サイズと方向の設定

プリアンブルでサイズと方向を指定:

```latex
\usepackage[orientation=landscape,size=a1]{beamerposter}
```

#### オプション一覧

| オプション | 値 | 説明 |
|-----------|---|------|
| **orientation** | `landscape` | 横向き |
| | `portrait` | 縦向き |
| **size** | `a0`, `a1`, `a2`, `a3`, `a4` | 定型サイズ |
| | `custom` | カスタムサイズ（heightとwidthを併用） |
| **height** | `数値`（cm単位） | カスタム高さ |
| **width** | `数値`（cm単位） | カスタム幅 |
| **scale** | `数値`（倍率） | フォントサイズの倍率（デフォルト: 1.0） |

#### カスタムサイズの例

```latex
\usepackage[orientation=portrait,size=custom,height=110,width=80,scale=1.4]{beamerposter}
```

### 基本構成

ポスターは1フレーム内にcolumns環境とblock環境を組み合わせて構成:

```latex
\documentclass[final,t]{beamer}
\usetheme{テーマ名}
\usepackage[orientation=landscape,size=a1]{beamerposter}

\begin{document}
\begin{frame}[t]
  \begin{columns}[t]
    \column{.32\linewidth}
    % 左カラムのblock群

    \column{.32\linewidth}
    % 中央カラムのblock群

    \column{.32\linewidth}
    % 右カラムのblock群
  \end{columns}
\end{frame}
\end{document}
```

#### レイアウト推奨パターン

| 方向 | カラム数 | カラム幅 |
|------|---------|---------|
| **landscape**（横向き） | 3カラム | `.32\linewidth` |
| **portrait**（縦向き） | 2カラム | `.45\linewidth` |

### 完全なポスターテンプレート（日本語・3カラム）

```latex
\documentclass[final,t]{beamer}
\usetheme{Berlin}
\usecolortheme{beaver}
\usepackage[orientation=landscape,size=a1,scale=1.4]{beamerposter}

% 日本語対応
\usepackage{luatexja}
\usepackage{graphicx}
\usepackage{tikz}
\usepackage{pgfplots}
\pgfplotsset{compat=1.18}

% タイトル情報
\title{深層学習による画像認識の高速化}
\author{山田太郎 \inst{1} \and 佐藤花子 \inst{2}}
\institute{
  \inst{1} 〇〇大学 情報工学科 \\
  \inst{2} △△研究所 機械学習研究室
}

\begin{document}
\begin{frame}[t]

  % タイトルブロック（全幅）
  \begin{block}{\centering\LARGE\inserttitle}
    \centering
    \insertauthor \\[1ex]
    \insertinstitute
  \end{block}

  \vskip 2ex

  % 3カラムレイアウト
  \begin{columns}[t]

    % 左カラム
    \column{.32\linewidth}

    \begin{block}{研究背景}
      深層学習モデルの推論速度は実用化における重要課題である。
      本研究では、モデル圧縮技術と推論最適化手法を組み合わせることで、
      精度を維持しつつ推論速度を大幅に向上させる手法を提案する。
    \end{block}

    \begin{block}{研究目的}
      \begin{itemize}
        \item モデルサイズの削減（50\%以上）
        \item 推論速度の向上（3倍以上）
        \item 精度の維持（劣化5\%以内）
      \end{itemize}
    \end{block}

    \begin{block}{提案手法}
      \begin{enumerate}
        \item 重み量子化（8bit整数化）
        \item 知識蒸留によるモデル圧縮
        \item 推論グラフの最適化
      \end{enumerate}
    \end{block}

    % 中央カラム
    \column{.32\linewidth}

    \begin{block}{実験結果}
      \begin{center}
      \begin{tabular}{lrrr}
        \hline
        モデル & 精度 & 速度 & サイズ \\
        \hline
        ベースライン & 92.3\% & 100ms & 250MB \\
        提案手法 & 90.1\% & 32ms & 110MB \\
        \hline
      \end{tabular}
      \end{center}

      \vskip 2ex

      \begin{center}
      \begin{tikzpicture}
        \begin{axis}[
          ybar,
          width=\textwidth,
          height=0.5\textwidth,
          ylabel={精度 (\%)},
          symbolic x coords={ベースライン,手法A,手法B,提案手法},
          xtick=data,
          ymin=85,ymax=95,
          legend pos=north west,
        ]
        \addplot coordinates {
          (ベースライン,92.3)
          (手法A,90.5)
          (手法B,88.9)
          (提案手法,90.1)
        };
        \end{axis}
      \end{tikzpicture}
      \end{center}
    \end{block}

    \begin{block}{システム構成}
      \begin{center}
      \begin{tikzpicture}[node distance=2cm]
        \node[draw, rectangle] (input) {入力画像};
        \node[draw, rectangle, right of=input] (preprocess) {前処理};
        \node[draw, rectangle, right of=preprocess] (model) {圧縮モデル};
        \node[draw, rectangle, right of=model] (output) {認識結果};

        \draw[->] (input) -- (preprocess);
        \draw[->] (preprocess) -- (model);
        \draw[->] (model) -- (output);
      \end{tikzpicture}
      \end{center}
    \end{block}

    % 右カラム
    \column{.32\linewidth}

    \begin{block}{考察}
      提案手法により、推論速度を3.1倍に向上させることができた。
      精度の劣化は2.2\%に抑えられ、実用上十分な性能を達成した。

      \vskip 1ex

      \textbf{主な知見:}
      \begin{itemize}
        \item 量子化による速度向上が最も効果的
        \item 知識蒸留でモデルサイズを大幅削減
        \item 推論グラフ最適化で追加的な高速化
      \end{itemize}
    \end{block}

    \begin{block}{今後の課題}
      \begin{itemize}
        \item より複雑なタスクへの適用
        \item エッジデバイスでの実装
        \item リアルタイム処理の実現
      \end{itemize}
    \end{block}

    \begin{block}{参考文献}
      \footnotesize
      \begin{enumerate}
        \item Smith, J. et al. (2023). Model Compression Techniques. ICML.
        \item 田中一郎ら (2024). 深層学習の高速化. 情報処理学会論文誌.
        \item Wang, L. et al. (2023). Quantization Methods. NeurIPS.
      \end{enumerate}
    \end{block}

    \vfill

    \begin{block}{謝辞}
      本研究はJSPS科研費（課題番号 12345678）の助成を受けた。
    \end{block}

  \end{columns}

\end{frame}
\end{document}
```

### ポスター作成のポイント

1. **カラムレイアウト**: landscape（横向き）は3カラム、portrait（縦向き）は2カラムが標準
2. **block環境の活用**: 各セクションをblock環境で明確に区切る
3. **フォントサイズ**: `scale`オプションで全体のフォントサイズを調整（1.4〜1.6推奨）
4. **視覚的要素**: TikZ/pgfplotsで図表を直接描画し、可読性を向上
5. **カラム幅の調整**: `.32\linewidth`は3カラムの標準。`.30\linewidth`等で調整可能
6. **タイトルブロック**: `\centering`と`\LARGE`で目立たせる
7. **垂直配置**: `\begin{frame}[t]`と`\begin{columns}[t]`で上揃えを指定

## 実践的なTips

### ナビゲーションバーの非表示化

デフォルトで右下に表示されるナビゲーション記号を非表示にする:

```latex
\setbeamertemplate{navigation symbols}{}
```

シンプルなプレゼンや印刷用ハンドアウトに適している。

### ハンドアウトの生成

発表後の配布資料として、オーバーレイなしの静的版を同じソースから生成できる:

```latex
% 1. ドキュメントクラスにhandoutオプションを追加
\documentclass[handout]{beamer}

% 2. pgfmorepagesパッケージで複数スライドを1ページに配置
\usepackage{pgfmorepages}

% 3. レイアウトを指定（例: A4横置き1ページに4枚）
\pgfpagesuselayout{4 on 1}[a4paper, border shrink=0.25cm, landscape]
```

最大16スライドを1ページに配置可能。詳細は `texdoc pgfmorepages` 参照。

### 目次の段階的表示（サブセクション単位）

セクション単位に加え、サブセクション単位でも段階的表示が可能:

```latex
% セクション単位
\tableofcontents[pausesections]

% サブセクション単位
\tableofcontents[pausesubsections]
```

### プレゼン設計のベストプラクティス

効果的なプレゼンのために避けるべきこと:

- スライドのテキストをそのまま読み上げない
- 話すスピードが速くなりすぎない
- 1枚のスライドに内容を詰め込みすぎない
- subsubsectionを使わない（階層が深くなりすぎる）
- スライドに向かって話さず、聴衆に向かって話す
- 詳細な補足情報は付録（appendix）に移動する

有益なプレゼン構成の原則:
- 1スライドに1つの明確なアイデアを持たせる
- 完全な文でなく短いフレーズを使う
- 大きく読みやすいフォントを使う
- セクションタイトルは自己説明的に
- 開始時にトピックと目標を提示し、終わりに短い要約を置く
