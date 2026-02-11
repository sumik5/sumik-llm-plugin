# 特殊な文書クラス（CV・手紙・リーフレット・ポスター）

履歴書（CV）、手紙、折り畳みリーフレット、大型ポスターなど、一般的な文書クラス（article/book/thesis/beamer等）では対応できない特殊な文書作成のためのパッケージとテクニック。

## 履歴書（CV）作成 - moderncv

### 概要

**moderncv** パッケージは、プロフェッショナルな履歴書・CVを作成するための専用クラス。複数のビジュアルスタイルとカラーテーマを提供し、一貫したデザインを維持しながら個人情報・経歴・スキルを構造化して記述可能。

### 基本構造

```latex
\documentclass[11pt,a4paper,sans]{moderncv}
\moderncvstyle{classic}    % classic, casual, oldstyle, banking
\moderncvcolor{blue}       % blue, orange, green, red, purple, grey, black
\usepackage[scale=0.75]{geometry}

% 個人情報
\name{John}{Doe}
\title{Software Engineer}
\address{Street 123}{12345 City}{Country}
\phone[mobile]{+1~(234)~567~890}
\phone[fixed]{+1~(234)~567~890}
\email{john@example.com}
\homepage{www.johndoe.com}
\social[linkedin]{johndoe}
\social[github]{johndoe}
\photo[64pt][0.4pt]{picture}

\begin{document}
\makecvtitle

\section{Education}
\cventry{2015--2018}{Master}{University}{City}{\textit{Grade}}{Description}
\cventry{2011--2015}{Bachelor}{University}{City}{}{Description}

\section{Experience}
\cventry{2018--present}{Position}{Company}{City}{}{
  \begin{itemize}
    \item Achievement 1
    \item Achievement 2
  \end{itemize}
}

\section{Skills}
\cvitem{Programming}{Python, JavaScript, Go}
\cvitem{Frameworks}{React, Django, TensorFlow}
\cvitem{Languages}{English (Native), Japanese (N1)}

\section{Projects}
\cvitem{Project 1}{Brief description}
\cvitem{Project 2}{Brief description}

\end{document}
```

### スタイル選択の基準

| スタイル | 特徴 | 推奨用途 |
|---------|------|----------|
| `classic` | 左カラムにアイコン、伝統的レイアウト | 学術職、研究職 |
| `casual` | よりカジュアルでモダン | IT・スタートアップ |
| `oldstyle` | クラシックな書体、重厚感 | 法律・金融・コンサルティング |
| `banking` | シンプル・ミニマル | 銀行・投資・ビジネス |

### 主要コマンド

| コマンド | 用途 | 構文 |
|---------|------|------|
| `\cventry` | 経歴項目 | `\cventry{years}{degree/job}{institution/employer}{city}{grade}{description}` |
| `\cvitem` | スキル・プロジェクト項目 | `\cvitem{label}{description}` |
| `\cvlistitem` | リスト項目 | `\cvlistitem{item text}` |
| `\cvdoubleitem` | 2カラムリスト | `\cvdoubleitem{label1}{text1}{label2}{text2}` |
| `\cvcomputer` | スキルレベル表示 | `\cvcomputer{category1}{skills1}{category2}{skills2}` |

### 複数ページ対応

```latex
% ページヘッダー・フッターの調整
\usepackage{lastpage}
\rfoot{\addressfont\itshape\textcolor{gray}{Page \thepage\ of \pageref{LastPage}}}
```

### カスタマイズ

```latex
% セクションフォント変更
\renewcommand{\sectionfont}{\Large\bfseries\scshape}

% アイコンカスタマイズ
\renewcommand*{\addresssymbol}{\faHome~}
\renewcommand*{\mobilephonesymbol}{\faMobile~}
\renewcommand*{\emailsymbol}{\faEnvelope~}

% 余白調整
\setlength{\hintscolumnwidth}{3cm}
```

---

## 手紙作成 - scrlttr2

### 概要

**scrlttr2** は KOMA-Script バンドルに含まれる手紙専用クラス。ビジネスレター・公式文書・カバーレターに対応し、国際標準（DIN/ISO）に準拠したフォーマットを自動生成。

### 基本構造

```latex
\documentclass[
  addrfield=true,     % 宛先フィールド表示
  foldmarks=true,     % 折り目マーク表示
  fromalign=right     % 差出人情報の配置（right/left/center）
]{scrlttr2}

% 差出人情報
\setkomavar{fromname}{Thomas Smith}
\setkomavar{fromaddress}{Street 123\\12345 City}
\setkomavar{fromphone}{+1 234 567 890}
\setkomavar{fromemail}{thomas@example.com}
\setkomavar{signature}{Thomas Smith}
\setkomavar{subject}{Application for Software Engineer Position}

\begin{document}

\begin{letter}{%
  HR Department\\
  Tech Company Inc.\\
  5th Avenue\\
  Capital City
}

\opening{Dear Sir or Madam,}

I am writing to apply for the Software Engineer position
advertised on your website. With over five years of experience
in full-stack development...

[本文]

\closing{Yours sincerely}

\end{letter}

\end{document}
```

### 主要変数（komavars）

| 変数名 | 用途 | 例 |
|--------|------|-----|
| `fromname` | 差出人氏名 | `\setkomavar{fromname}{John Doe}` |
| `fromaddress` | 差出人住所 | `\setkomavar{fromaddress}{Street\\City}` |
| `fromphone` | 電話番号 | `\setkomavar{fromphone}{+1 234 567 890}` |
| `fromemail` | メールアドレス | `\setkomavar{fromemail}{john@example.com}` |
| `subject` | 件名 | `\setkomavar{subject}{Application}` |
| `date` | 日付 | `\setkomavar{date}{\today}` |
| `signature` | 署名 | `\setkomavar{signature}{John Doe}` |
| `place` | 発信地 | `\setkomavar{place}{New York}` |

### レイアウトオプション

```latex
% クラスオプションで制御
\documentclass[
  fromalign=center,      % 差出人情報を中央配置
  enlargefirstpage=true, % 1ページ目の下部余白を拡張
  pagenumber=botright,   % ページ番号の位置
  parskip=half           % 段落間スペース
]{scrlttr2}
```

### 添付ファイル・同封物

```latex
\setkomavar{enclseparator}{: }
\encl{Resume, Portfolio, References}

% または
\setkomavar*{enclseparator}{Enclosures}
\setkomavar{encl}{%
  Resume\\
  Portfolio\\
  Two reference letters
}
```

---

## 折り畳みリーフレット - leaflet

### 概要

**leaflet** クラスは3つ折り（トライフォールド）・2つ折りのパンフレット・リーフレットを作成。1枚の用紙を折り畳んだ状態での読み順を自動調整。

### 基本構造

```latex
\documentclass[
  10pt,
  notumble,      % 折り目で上下を反転しない
  a4paper
]{leaflet}

\usepackage[T1]{fontenc}
\usepackage{lmodern}
\renewcommand{\familydefault}{\sfdefault}
\usepackage{microtype}
\usepackage{graphicx}
\usepackage{xcolor}

% ヘッダー・フッターカスタマイズ
\renewcommand{\thepage}{\arabic{page}}
\pagestyle{empty}

\begin{document}

% ページ1（表紙）
\section{Welcome}
This is the cover page visible when folded.

\newpage

% ページ2（内側左）
\section{About Us}
Company information and mission statement.

\newpage

% ページ3（内側中央）
\section{Services}
\begin{itemize}
  \item Service 1
  \item Service 2
  \item Service 3
\end{itemize}

\newpage

% ページ4（内側右）
\section{Contact}
Phone: +1 234 567 890\\
Email: info@example.com

\newpage

% ページ5（裏面左）
\section{Testimonials}
Client feedback and reviews.

\newpage

% ページ6（裏面 - 背表紙）
\vfill
\centering
\Large\textbf{Company Name}\\
\large\textit{Tagline}
\vfill

\end{document}
```

### ページ配置の理解

3つ折りリーフレットの物理的配置:

```
表面:  [6背表紙] [1表紙] [2内側左]
裏面:  [3内側中央] [4内側右] [5裏面左]
```

### オプション

| オプション | 効果 |
|-----------|------|
| `notumble` | 折り目で上下を反転しない（デフォルト） |
| `tumble` | 短辺綴じ印刷用（折り目で上下反転） |
| `landscape` | 横向き用紙 |
| `portrait` | 縦向き用紙 |

### デザインのヒント

```latex
% カラフルなセクションヘッダー
\usepackage{titlesec}
\titleformat{\section}
  {\Large\bfseries\color{blue}}
  {}
  {0pt}
  {}

% 背景色付きボックス
\usepackage{tcolorbox}
\begin{tcolorbox}[colback=yellow!10, colframe=orange, title=Important]
  Key information here
\end{tcolorbox}

% 画像配置
\includegraphics[width=\linewidth]{logo.png}
```

---

## 大型ポスター - tikzposter / baposter

### 概要

学会発表・展示用の大型ポスター（A0/A1サイズ）を作成。複数カラムのレイアウト、カラフルなブロック、ロゴ配置などをサポート。

### tikzposter の基本

```latex
\documentclass[
  25pt,          % フォントサイズ（大型ポスター用）
  a0paper,       % A0サイズ（84.1cm × 118.9cm）
  landscape      % 横向き
]{tikzposter}

\usepackage[utf8]{inputenc}
\usetheme{Wave}         % テーマ: Default, Rays, Basic, Simple, Envelope, Wave, Board, Autumn, Desert
\usecolorstyle{Default} % カラー: Default, Australia, Britain, Sweden, Spain, Russia, Denmark, Germany

\title{Research Project Title}
\author{John Doe, Jane Smith}
\institute{University Name, Department of Computer Science}

\begin{document}
\maketitle

% 2カラムレイアウト
\begin{columns}
  \column{0.65}  % 左カラム（幅65%）

  \block{Introduction}{
    Research background and motivation...
    \begin{itemize}
      \item Point 1
      \item Point 2
    \end{itemize}
  }

  \block{Methodology}{
    \begin{tikzfigure}
      \includegraphics[width=0.8\linewidth]{workflow.png}
    \end{tikzfigure}
    Description of the workflow...
  }

  \column{0.35}  % 右カラム（幅35%）

  \block{Results}{
    \begin{tikzfigure}
      \includegraphics[width=\linewidth]{results.png}
    \end{tikzfigure}
  }

  \block{Conclusion}{
    Summary of findings and future work...
  }

\end{columns}

\block{References}{
  \bibliographystyle{plain}
  \bibliography{references}
}

\end{document}
```

### tikzposter テーマ一覧

| テーマ | 特徴 |
|--------|------|
| Default | シンプル・汎用的 |
| Wave | 波模様の装飾 |
| Board | 掲示板風 |
| Autumn | 暖色系 |
| Desert | 砂漠風カラー |
| Rays | 放射状グラデーション |

### カスタムブロック

```latex
% カスタムブロックスタイル
\defineblockstyle{CustomBlock}{
  titlewidthscale=1, bodywidthscale=1, titleleft,
  titleoffsetx=0pt, titleoffsety=0pt, bodyoffsetx=0pt, bodyoffsety=0pt,
  bodyverticalshift=0pt, roundedcorners=5, linewidth=2pt,
  titleinnersep=1cm, bodyinnersep=1cm
}{
  \draw[color=framecolor, fill=blockbodybgcolor, rounded corners=\blockroundedcorners]
    (blockbody.south west) rectangle (blockbody.north east);
  \ifBlockHasTitle
    \draw[color=framecolor, fill=blocktitlebgcolor, rounded corners=\blockroundedcorners]
      (blocktitle.south west) rectangle (blocktitle.north east);
  \fi
}
```

### baposter の例

```latex
\documentclass[portrait,a0paper,fontscale=0.277]{baposter}

\usepackage{graphicx}
\usepackage{amsmath}
\usepackage{amssymb}

\begin{document}

\begin{poster}{
  grid=false,
  columns=3,
  colspacing=1em,
  headerheight=0.1\textheight,
  background=shadeTB,
  bgColorOne=cyan!10,
  bgColorTwo=cyan!10,
  borderColor=cyan!30,
  headerColorOne=cyan!20,
  headerColorTwo=cyan!20,
  headershape=roundedright,
  headerfont=\Large\bf\textsc,
  textborder=rounded,
  boxColorOne=white,
  boxColorTwo=cyan!10,
  headerFontColor=black,
  headerborder=closed,
  boxshade=plain
}
{}  % アイ追加画像なし
{\textsc{Research Title}}
{\textsc{Author Name}\\University Name}
{\includegraphics[height=4em]{logo.png}}

\headerbox{Introduction}{name=intro,column=0,row=0}{
  Background and motivation...
}

\headerbox{Method}{name=method,column=1,row=0}{
  Methodology description...
}

\headerbox{Results}{name=results,column=2,row=0}{
  \includegraphics[width=\linewidth]{results.png}
}

\headerbox{Conclusion}{name=conclusion,column=0,span=3,below=intro}{
  Summary of findings...
}

\end{poster}

\end{document}
```

---

## 関連パッケージ

| パッケージ | 用途 |
|----------|------|
| `fontawesome5` | CV・手紙のアイコン（\faPhone, \faEnvelope等） |
| `qrcode` | QRコード埋め込み（CV・ポスター） |
| `microtype` | マイクロタイポグラフィ調整（全般） |
| `geometry` | 余白・ページサイズ調整 |
| `graphicx` | 画像挿入（ロゴ・プロフィール写真） |
| `hyperref` | ハイパーリンク（メール・URL） |

---

## ドキュメント参照

- moderncv: `texdoc moderncv` / https://ctan.org/pkg/moderncv
- scrlttr2: `texdoc scrlttr2` / https://ctan.org/pkg/koma-script
- leaflet: `texdoc leaflet` / https://ctan.org/pkg/leaflet
- tikzposter: `texdoc tikzposter` / https://ctan.org/pkg/tikzposter
- baposter: https://www.brian-amberg.de/uni/poster/
