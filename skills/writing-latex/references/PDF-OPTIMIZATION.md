# PDF最適化

LaTeXで生成したPDFファイルは、適切な設定により、電子配布に最適化された高機能なドキュメントにできます。本リファレンスでは、ハイパーリンク、メタデータ、著作権情報、コメント、フォーム、電子書籍最適化、PDF結合、アニメーションなどの高度な設定をまとめます。

---

## ハイパーリンク詳細設定 (hyperref)

### 基本的な読み込み

```latex
\usepackage{hyperref}
\hypersetup{オプション}
```

**重要原則**: hyperrefは**ほぼすべてのパッケージの後**に読み込む（例外: `cleveref`, `amsrefs`, `bookmark`, `hypcap`, `hypernat`）

### 設定方法の比較

| 方法 | 構文 | 利点 | 欠点 |
|------|------|------|------|
| パッケージオプション | `\usepackage[key=value]{hyperref}` | 単一行で完結 | 値の空白保持に `\` 必要 |
| `\hypersetup` | `\hypersetup{key=value}` | 値の空白保持容易、複数回実行可 | 追加コマンド必要 |

**推奨**: `\hypersetup` を使用（空白・早期展開の問題回避）

### カスタムハイパーリンク

#### 内部リンク

```latex
% アンカー設定
\hypertarget{mytarget}{ここ}にテキストがあります。

% リンク作成
\hyperlink{mytarget}{前のページへ}
```

#### ラベル参照リンク

```latex
\begin{equation}
  \label{eq:einstein}
  E = mc^2
\end{equation}

% テキスト付きリンク
\hyperref[eq:einstein]{質量エネルギー等価性}を参照
```

#### インターネットリンク

```latex
% URLテキスト表示
\url{https://tikz.net}

% カスタムテキスト
\href{https://latex.org}{LaTeX Forum}

% リンクなしURL表示
\nolinkurl{https://texdoc.org}
```

#### 複雑なURL構成

```latex
\hyperref{https://tikz.org/chapter-13}{plot}{3D}{3Dプロット}
% → https://tikz.org/chapter-13#plot.3D
```

### リンク外観のカスタマイズ

#### 枠非表示

```latex
\hypersetup{hidelinks}
```

#### 色付きテキスト

```latex
\usepackage{xcolor}
\hypersetup{
  colorlinks,
  linkcolor={red!75!black},
  citecolor={green!40!black},
  urlcolor={blue!40!black}
}
```

#### 一括色設定

```latex
\hypersetup{allcolors=blue!50!black}
```

### 書誌・索引への逆参照

```latex
% 書誌項目への逆リンク（ページ番号）
\hypersetup{pagebackref}

% セクション番号で逆リンク
\hypersetup{backref=section}
```

### 索引のハイパーリンク化

```latex
\hypersetup{hyperindex}
```

---

## メタデータ設定

### 基本メタデータ

```latex
\hypersetup{
  pdfauthor   = 著者名,
  pdftitle    = ドキュメントタイトル,
  pdfsubject  = 件名,
  pdfkeywords = {キーワード1, キーワード2},
  pdfproducer = 製作ツール,
  pdfcreator  = 作成アプリケーション
}
```

**注意**: カンマを含む値（`pdfkeywords`など）は `{}` で囲む

### パッケージオプションでの設定（非推奨）

```latex
\usepackage[
  pdfauthor   = {著者\ 名},
  pdftitle    = {タイトル\ テキスト},
  pdfkeywords = {{キーワード1, キーワード2}}
]{hyperref}
```

**問題点**: 空白保持に `\` 必要、早期展開のリスク

### pdfinfo代替インターフェース

```latex
\hypersetup{pdfinfo={
  Author   = 著者名,
  Title    = タイトル,
  Subject  = 件名,
  Keywords = {キーワード1, キーワード2},
  Version  = 2.0,
  Comment  = カスタムフィールド例
}}
```

---

## 著作権情報埋め込み

### hyperxmpパッケージ

```latex
\usepackage{hyperref}
\usepackage{hyperxmp}

\hypersetup{
  pdfcopyright = {Copyright 2024 by Author. All rights reserved.},
  pdflicenseurl = {https://example.com/license/}
}
```

**背景**: Adobe XMP（eXtensible Metadata Platform）形式でXML構造化メタデータを埋め込み

**効果**: PDF閲覧ソフトで「Copyright Status」と「Copyright Notice」が正しく表示

### xmpinclパッケージ（上級者向け）

```latex
\usepackage{xmpincl}
\includexmp{metadata}  % metadata.xmp ファイルを読み込み
```

**用途**: XML直接記述による柔軟なメタデータ設定

---

## PDFコメント・注釈

### pdfcommentパッケージ

```latex
\usepackage[svgnames]{xcolor}
\usepackage[author={Your name}, icon=Note, color=Yellow, open=true]{pdfcomment}
```

### コメントタイプ

#### 単純コメント

```latex
\pdfcomment{シンプルなドキュメントにはchapterがありません。}
```

#### マージンコメント

```latex
\begin{equation}
  \pdfmargincomment{equation環境は中央揃え数式を生成します。}
  E = mc^2
\end{equation}
```

#### マークアップコメント（ハイライト）

```latex
\pdfmarkupcomment{sections}{subsectionも追加できます。}
```

#### ツールチップ

```latex
\pdftooltip{formulas}{数式はインラインまたは独立段落で表示できます}
```

#### サイドラインコメント

```latex
\begin{pdfsidelinecomment}[color=Red]{箇条書きリスト}
  \begin{itemize}
    \item 項目1
    \item 項目2
  \end{itemize}
\end{pdfsidelinecomment}
```

#### フリーテキストコメント

```latex
\pdffreetextcomment[
  subject={概要},
  width=7.5cm,
  height=2.2cm,
  opacity=0.5,
  voffset=-3cm
]{このドキュメント全体が小規模ドキュメントの書き方例です。}
```

### 主要オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `icon` | アイコン種類 | `Note`, `Comment`, `Insert`, `Help` |
| `color` | 色指定 | `red`, `blue!80` |
| `opacity` | 不透明度 | `0.5` |
| `author` | 著者名 | `Me` |
| `width`, `height` | 寸法 | `5cm`, `3ex` |
| `markup` | マークアップタイプ | `Highlight`, `Underline`, `StrikeOut`, `Squiggly` |
| `final` | コメント非表示化 | `true` |

### 最終版でのコメント非表示

```latex
\usepackage[...,final]{pdfcomment}
```

---

## 入力可能フォーム (hyperref forms)

### Form環境

```latex
\usepackage{hyperref}

\begin{document}
\begin{Form}
  % フォーム要素
\end{Form}
\end{document}
```

**注意**: ドキュメント内に最大1つのForm環境のみ配置

### フォーム要素

#### テキストフィールド

```latex
\TextField[width=5cm, value=デフォルト値]{ラベル:}
```

#### チェックボックス

```latex
\CheckBox[width=0.5cm, checked=true]{選択項目}
```

#### 選択メニュー

```latex
% ドロップダウン
\ChoiceMenu[combo, width=3cm]{エディタ:}{TeXworks, TeXstudio, Emacs, vi}

% ラジオボタン
\ChoiceMenu[radio, radiosymbol=6, width=0.5cm]{ソフトウェア:\quad}{\TeX\ Live, MiK\TeX}
```

#### プッシュボタン（JavaScript連携）

```latex
\PushButton[
  width=1cm,
  onclick={app.alert("LaTeXを始めた動機は何ですか?")}
]{質問}
```

### 主要オプション

| オプション | 説明 | 値例 |
|-----------|------|------|
| `width`, `height` | 寸法 | `5cm`, `10\baselineskip` |
| `charsize` | フォントサイズ | `12pt` |
| `color`, `backgroundcolor` | 色 | `blue`, `yellow!30` |
| `maxlen` | 最大文字数 | `100` |
| `value` | 初期値 | `デフォルトテキスト` |
| `multiline` | 複数行入力 | `true` |
| `radio`, `combo`, `popdown` | 選択タイプ | `true` / `false` |
| `radiosymbol` | ラジオシンボル | Zapf Dingbats番号 |
| `checked` | 初期選択状態 | `true` / `false` |

### JavaScript連携例

```latex
\PushButton[
  width=1cm,
  onclick={app.response("コメントを入力してください")}
]{入力}
```

---

## 電子書籍最適化

### 基本設定

```latex
\documentclass[fontsize=11pt, headings=small, parskip=half]{scrreprt}
\usepackage[papersize={3.6in,4.8in}, margin=0.2in]{geometry}
\usepackage[T1]{fontenc}
\usepackage{lmodern}
\renewcommand{\familydefault}{\sfdefault}
\usepackage{microtype}
\pagestyle{empty}
\renewcommand{\partpagestyle}{empty}
\renewcommand{\chapterpagestyle}{empty}
\usepackage{hyperref}
\hypersetup{colorlinks}
```

### 設計原則

| 設定項目 | 推奨値 | 理由 |
|---------|-------|------|
| 用紙サイズ | 3.6in × 4.8in | タブレット画面比率に対応 |
| 余白 | 0.2in〜0.4cm | デバイスの物理余白を活用 |
| フォント | Sans-serif | 低解像度ディスプレイでの可読性 |
| parskip | `half` | 狭い画面でのインデント削減 |
| ページスタイル | `empty` | ソフトウェア側のページ番号利用 |
| 画像 | 相対サイズ指定 | `width=0.8\textwidth` |

### 単一ページ（endless scroll）アプローチ

**コンセプト**: ページ分割を廃止し、スクロール型ドキュメントに

**参考文献**: Boris Veytsman & Michael Ware, "Ebooks and paper sizes: Output routines made easier", TUGboat Vol.32, No.3
https://www.tug.org/TUGboat/tb32-3/tb102veytsman-ebooks.pdf

---

## 余白削除 (pdfcrop)

### 必要ソフトウェア

- Ghostscript
- Perl
- pdfcrop（TeX Liveに含まれる）

### 基本コマンド

```bash
pdfcrop filename.pdf
# → filename-crop.pdf が生成される
```

### カスタム余白指定

```bash
# 全辺に20 PSポイントの余白
pdfcrop --margins 20 input.pdf output.pdf

# 左・上・右・下に個別指定
pdfcrop --margins '10 20 30 40' input.pdf output.pdf
```

**単位**: PS point (bp) = 1/72 inch

### ソースコードでの余白制御

#### standaloneクラス

```latex
\documentclass{standalone}  % 余白なし

\documentclass[border=10pt]{standalone}  % 全辺10pt

\documentclass[border={10pt 20pt 30pt 40pt}]{standalone}  % 左・右・下・上
```

---

## PDF結合 (pdfpages)

### 基本コマンド

```latex
\documentclass{article}
\usepackage{pdfpages}

\begin{document}
\includepdf[pages=-]{file1.pdf}
\includepdf[pages=-]{file2.pdf}
\end{document}
```

### ページ範囲指定

```latex
\includepdf[pages={3-6}]{document.pdf}
\includepdf[pages={1,3-6,9}]{document.pdf}
```

**用途**: 応募書類（CV、証明書スキャン等）の一括結合

---

## PDFアニメーション (animate)

### 必要なパッケージ

```latex
\usepackage{animate}
```

### インラインアニメーション

```latex
\documentclass[border=10pt]{standalone}
\usepackage{animate}
\usepackage{tikz}
\usetikzlibrary{lindenmayersystems,shadings}

\pgfdeclarelindenmayersystem{Koch curve}{
  \rule{F -> F-F++F-F}
}

\begin{document}
\begin{animateinline}[controls, autoplay, loop]{2}
  \multiframe{5}{n=0+1}{
    \begin{tikzpicture}[scale=80]
      \shadedraw[shading=color wheel]
        [l-system={Koch curve, step=2pt, angle=60, axiom=F++F++F, order=\n}]
        lindenmayer system -- cycle;
    \end{tikzpicture}
  }
\end{animateinline}
\end{document}
```

### 画像ファイルからのアニメーション

```latex
\animategraphics[controls, autoplay, loop]{10}{frame-}{4}{12}
% → frame-4.png, frame-5.png, ..., frame-12.png を10fps再生
```

### 主要オプション

| オプション | 説明 |
|-----------|------|
| `controls` | 再生制御ボタン表示 |
| `autoplay` | 自動再生 |
| `loop` | ループ再生 |
| フレームレート | 数値（fps） |

**注意**: 再生にはAdobe Acrobat Reader等の対応PDF閲覧ソフトが必要

---

## 判断基準テーブル

| 目的 | 推奨パッケージ/方法 | 補足 |
|------|------------------|------|
| ハイパーリンク基本 | `hyperref` | ほぼすべてのパッケージの後に読み込み |
| メタデータ設定 | `\hypersetup` | パッケージオプションより推奨 |
| 著作権情報 | `hyperxmp` | XMP形式で埋め込み |
| PDF注釈 | `pdfcomment` | 多様なコメントタイプ対応 |
| 入力フォーム | `hyperref` Forms環境 | JavaScript連携可能 |
| 電子書籍最適化 | KOMA-Script + `geometry` | Sans-serif推奨 |
| 余白削除 | `pdfcrop` (コマンドライン) | standalone クラスも選択肢 |
| PDF結合 | `pdfpages` | 異なるクラスのドキュメント結合 |
| アニメーション | `animate` | TikZ/PSTricks等と併用 |

---

## 実用的ヒント

1. **hyperref読み込み順**: 最後に読み込むのが原則（例外: `cleveref`, `bookmark`, `hypcap` は後）
2. **メタデータの空白**: `\hypersetup` 使用で空白保持が容易
3. **リンク色の印刷**: 印刷時は `hidelinks` オプションで枠・色を非表示化
4. **フォーム互換性**: Adobe Acrobat Readerでの動作確認を推奨
5. **電子書籍フォント**: 高解像度ディスプレイなら serif フォントも選択肢
6. **pdfcrop単位**: PSポイント（bp）= 1/72 inch、TeX point（pt）= 1/72.27 inch
7. **アニメーション形式**: PNG/JPG/PDF画像シーケンス対応（pdfLaTeX）
