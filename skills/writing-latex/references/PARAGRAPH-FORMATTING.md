# LaTeX 段落レベルのフォーマットガイド

段落の行揃え、マイクロタイポグラフィ、特殊文字、脚注、文書開発支援ツールの高度な活用法を扱う。

---

## 目次

1. [行揃えの改善](#line-justification)
2. [マイクロタイポグラフィ](#microtypography)
3. [段落の外観調整](#paragraph-appearance)
4. [行間調整](#line-spacing)
5. [装飾的な段落スタイル](#decorative-paragraphs)
6. [特殊文字とテキスト生成](#special-characters)
7. [ハイライトと引用](#highlighting-quoting)
8. [URL組版](#url-typesetting)
9. [脚注と傍注](#footnotes-sidenotes)
10. [文書開発支援](#document-development)

---

## 行揃えの改善

### ragged2e - 非均等行の改善

標準の `\raggedright` 等は行分割が粗い。`ragged2e` はハイフネーションを保持して改善する。

```latex
\usepackage{ragged2e}

% 文書全体
\RaggedRight

% 環境内
\begin{FlushLeft}
左揃えテキスト（ハイフネーションあり）
\end{FlushLeft}

\begin{FlushRight}
右揃えテキスト
\end{FlushRight}

\begin{Center}
中央揃えテキスト
\end{Center}
```

| 標準コマンド | ragged2e コマンド | 環境 | 効果 |
|------------|-----------------|------|------|
| `\raggedright` | `\RaggedRight` | `FlushLeft` | 左揃え（ハイフネーションあり） |
| `\raggedleft` | `\RaggedLeft` | `FlushRight` | 右揃え |
| `\centering` | `\Centering` | `Center` | 中央揃え |
| `\justifying` | `\justifying` | `justify` | 両端揃え |

#### パラメータ調整

```latex
\setlength{\RaggedRightParindent}{1.5em}  % 段落字下げ
\setlength{\RaggedRightRightskip}{0pt plus 2em}  % 右マージンの柔軟性
```

---

### nolbreaks - 改行禁止

特定のテキスト断片内での改行を防止：

```latex
\usepackage{nolbreaks}

\nolbreaks{2024年1月1日}  % この文字列内で改行しない
\nolbreaks{Dr.~Smith}
```

---

## マイクロタイポグラフィ

### microtype - 高品質組版の決定版

文字の微調整により視覚的品質を向上。**推奨：常に有効化**

```latex
\usepackage[
  activate={true,nocompatibility},  % マイクロタイポグラフィを有効化
  final,              % draftモードでも有効
  tracking=true,      % トラッキング（字間調整）
  kerning=true,       % カーニング
  spacing=true,       % スペーシング
  factor=1100,        % 突出の強度（1000=100%）
  stretch=10,         % 伸長可能量
  shrink=10           % 収縮可能量
]{microtype}
```

#### 主要機能

| 機能 | 説明 | 効果 |
|-----|------|------|
| **文字突出** (protrusion) | 句読点を行末外に微小配置 | 視覚的な行揃えの改善 |
| **字間調整** (expansion) | 文字幅を微調整 | ハイフネーション削減 |
| **トラッキング** (tracking) | 大文字列の字間拡大 | 可読性向上 |
| **カーニング** (kerning) | 文字ペアの間隔調整 | 視覚的バランス |

#### 特定フォントサイズへの適用

```latex
\DeclareMicrotypeSet*[tracking]{my}{
  font = */*/*/sc/*
}
\SetTracking{encoding = *, shape = sc}{40}
% スモールキャップに+40/1000emのトラッキング
```

#### 文字突出のカスタマイズ

```latex
\SetProtrusion{
  encoding = {T1,OT1},
  family = *
}{
  . = {0,800},  % ピリオドを右に800/1000em突出
  , = {0,700},  % カンマを右に700/1000em突出
  - = {0,500}   % ハイフンを右に500/1000em突出
}
```

---

## 段落の外観調整

### parskip - 段落間スペース

段落間に空白を挿入し、字下げをなくす（Webスタイル）：

```latex
\usepackage[
  skip=1em plus 0.5em,  % 段落間スペース
  indent=0pt            % 字下げなし
]{parskip}
```

| パラメータ | 説明 | デフォルト |
|-----------|------|-----------|
| `skip` | 段落間スペース | 各クラス依存 |
| `indent` | 段落字下げ | `0pt` |
| `parfill` | 最終行の余白 | `0pt plus 1fil` |

---

## 行間調整

### setspace - 行送りの変更

```latex
\usepackage{setspace}

% 文書全体
\onehalfspacing   % 1.5倍
\doublespacing    % 2倍
\singlespacing    % 1倍（デフォルト）

% 局所的変更
\begin{spacing}{1.2}
1.2倍の行送り
\end{spacing}
```

| コマンド | 行送り倍率 | 用途 |
|---------|-----------|------|
| `\singlespacing` | 1.0 | 標準 |
| `\onehalfspacing` | 1.5 | 論文（一部の大学が要求） |
| `\doublespacing` | 2.0 | 査読原稿 |

---

## 装飾的な段落スタイル

### lettrine - ドロップキャップ

段落の先頭文字を大きく装飾：

```latex
\usepackage{lettrine}

\lettrine{T}{his is the first paragraph} of the chapter.
% Tが2-3行分の高さで装飾される
```

#### カスタマイズ

```latex
\lettrine[
  lines=3,           % 3行分の高さ
  lhang=0.33,        % 左に33%突出
  loversize=0.2,     % 20%拡大
  findent=0pt,       % 1行目のインデント
  nindent=0.5em      % 2行目以降のインデント
]{T}{his}
```

### fancypar - 装飾段落

特殊な形状の段落（円形、三角形等）：

```latex
\usepackage{fancypar}

\Roundpara{段落テキスト}  % 円形段落
\Circularpara{段落テキスト}  % 円形段落（別実装）
```

---

## 特殊文字とテキスト生成

### ellipsis - 三点リーダー

```latex
\usepackage{ellipsis}

これは\dots 省略記号の例です。
% 前後のスペーシングが自動調整される
```

### extdash - ダッシュの制御

```latex
\usepackage{extdash}

\--/  % ハイフン（行末で改行可）
\---/ % enダッシュ（行末で改行可）
\----/ % emダッシュ（行末で改行可）
```

### underscore - アンダースコア

```latex
\usepackage{underscore}

% verbatimなしでアンダースコアを使用可能
file_name.txt
```

### xspace - スペースの自動挿入

```latex
\usepackage{xspace}

\newcommand{\latex}{\LaTeX\xspace}
% \latexの後に自動的にスペース挿入（句読点の前では挿入しない）

\latex is great. \latex, \latex. \latex!
% → "LaTeX is great. LaTeX, LaTeX. LaTeX!"
```

### fmtcount - 数値のテキスト化

```latex
\usepackage[english]{fmtcount}

\numberstringnum{42}     % → forty-two
\ordinalstringnum{21}    % → twenty-first
\Numberstringnum{3}      % → Three（文頭用）
```

### acro - 略語管理

```latex
\usepackage{acro}

\DeclareAcronym{pdf}{
  short = PDF,
  long = Portable Document Format,
  short-plural = s
}

\ac{pdf}の作成  % 初回 → "Portable Document Format (PDF)の"
\ac{pdf}の変換  % 2回目以降 → "PDFの"
```

### xfrac - 斜め分数

```latex
\usepackage{xfrac}

\sfrac{1}{2}  % → 1/2（斜め表示）
\sfrac[numerator-font=\sffamily]{3}{4}
```

### siunitx - 数値と単位

```latex
\usepackage{siunitx}

\num{12345.67890}              % → 12 345.678 90
\SI{299792458}{\meter\per\second}  % → 299 792 458 m/s
\SI{1.23e-4}{\micro\meter}     % → 1.23×10⁻⁴ μm

\numrange{10}{20}              % → 10–20
\SIrange{10}{20}{\celsius}     % → 10 °C–20 °C
```

---

## ハイライトと引用

### textcase - 大文字小文字変換

```latex
\usepackage{textcase}

\MakeTextUppercase{convert to upper}  % → CONVERT TO UPPER
\MakeTextLowercase{CONVERT TO LOWER}  % → convert to lower
```

### csquotes - 引用符の自動化

```latex
\usepackage[autostyle]{csquotes}

\enquote{引用テキスト}  % 言語に応じた引用符
\enquote{外側\enquote{内側}引用}  % 入れ子対応

\blockquote{長い引用テキスト}  % ブロック引用
```

### ulem - 下線・取消線

```latex
\usepackage[normalem]{ulem}  % normalem: \emph を変更しない

\uline{下線テキスト}
\uuline{二重下線}
\uwave{波下線}
\sout{取消線}
\xout{斜線消去}
```

### dashundergaps - 穴埋め問題

```latex
\usepackage{dashundergaps}

\gap{答え}    % → _____ （印刷時は空欄）
\gap[format-answer=\em]{答え}  % 答えを斜体で表示するモード
```

---

## レタースペーシング

### microtype & soul の組み合わせ

```latex
\usepackage{microtype}
\usepackage{soul}

\so{L e t t e r s p a c i n g}  % 字間拡大
\caps{Small Capitals}            % スモールキャップ+トラッキング
```

---

## URL組版

### url - URL表示

```latex
\usepackage{url}

\url{https://example.com/path/to/resource}
% 自動改行、特殊文字エスケープ不要
```

#### カスタマイズ

```latex
\urlstyle{same}  % 本文と同じフォント
\urlstyle{rm}    % ローマン
\urlstyle{sf}    % サンセリフ
\urlstyle{tt}    % タイプライタ（デフォルト）
```

### uri - 拡張URI処理

```latex
\usepackage{uri}

\uri{mailto:user@example.com}
\uri{ftp://ftp.example.com/file.txt}
```

---

## 脚注と傍注

### footmisc - 脚注スタイルの拡張

```latex
\usepackage[
  bottom,        % ページ下部に固定
  perpage,       % ページごとに番号リセット
  symbol,        % 記号を使用（*, †, ‡, ...）
  hang,          % インデントスタイル
  stable         % 見出し内で使用可能
]{footmisc}
```

| オプション | 効果 |
|-----------|------|
| `perpage` | ページごとに番号リセット |
| `symbol` | 数字の代わりに記号 |
| `multiple` | 連続脚注をカンマで結合 |
| `hang` | 脚注をインデント |
| `bottom` | ページ下部に固定 |

### manyfoot - 複数独立脚注

```latex
\usepackage{manyfoot}

\DeclareNewFootnote{A}[alph]  % アルファベット記号
\DeclareNewFootnote{B}[roman] % ローマ数字

本文\footnote{通常脚注}と追加情報\footnoteA{補足}。
```

### enotez - エンドノート

章末・文書末に注を配置：

```latex
\usepackage{enotez}

\setenotez{
  list-name = 注釈,
  backref = true
}

本文\endnote{エンドノート内容}

% エンドノートを出力
\printendnotes
```

### snotez - 傍注（サイドノート）

```latex
\usepackage{snotez}

\sidenote{傍注テキスト}  % 番号付き傍注
\sidetext{傍注テキスト}  % 番号なし傍注
```

### marginnote - マージンノート

```latex
\usepackage{marginnote}

\marginnote{マージンノート}[0pt]  % 0pt: 垂直位置調整
```

---

## 文書開発支援

### todonotes - TODO管理

```latex
\usepackage[
  colorinlistoftodos,  % カラー表示
  textsize=small       % サイズ
]{todonotes}

\todo{この部分を修正}
\todo[inline]{段落全体に対するTODO}
\missingfigure{図を挿入予定}

% TODOリストを出力
\listoftodos
```

### fixme - 構造化されたTODO

```latex
\usepackage[
  draft,         % ドラフトモード
  author         % 著者情報を表示
]{fixme}

\fxnote{メモ}
\fxwarning{警告}
\fxerror{エラー}
\fxfatal{致命的}

% 著者別TODO
\fxnote[author=Alice]{Aliceのメモ}

% FIXMEリストを出力
\listoffixmes
```

### changes - 変更履歴管理

```latex
\usepackage[
  final  % final: 変更を反映、draft: 変更を表示
]{changes}

\definechangesauthor[name={Alice}, color=blue]{alice}
\definechangesauthor[name={Bob}, color=red]{bob}

% 追加・削除・置換
\added[id=alice]{新しいテキスト}
\deleted[id=bob]{削除されたテキスト}
\replaced[id=alice]{新テキスト}{旧テキスト}

% 変更リストを出力
\listofchanges
```

### pdfcomment - PDF注釈

```latex
\usepackage{pdfcomment}

\pdfcomment{PDFの注釈として表示}
\pdfmarkupcomment{ハイライト}{注釈内容}
\pdftooltip{マウスオーバー}{ツールチップテキスト}
```

### verbars - 変更箇所の視覚化

```latex
\usepackage{verbars}

\begin{changebar}
変更されたテキスト
\end{changebar}
% 左マージンに縦線が表示される
```

---

## 判断基準テーブル

### 行揃えの選択

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| 左揃え（ハイフネーション維持） | `ragged2e` | 標準コマンドより美しい |
| 非分割テキスト | `nolbreaks` | 固有名詞・日付の保護 |

### タイポグラフィ品質向上

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| 高品質組版 | `microtype` | **常に推奨**。視覚的品質を劇的に改善 |
| 段落間スペース | `parskip` | Webスタイル文書 |
| 行間調整 | `setspace` | 論文要件対応 |

### 装飾

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| ドロップキャップ | `lettrine` | 章の開始を装飾 |
| 特殊形状段落 | `fancypar` | デザイン性の高い文書 |

### 脚注

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| 脚注スタイル変更 | `footmisc` | 柔軟なオプション |
| 複数種類の脚注 | `manyfoot` | 異なる記号体系を共存 |
| エンドノート | `enotez` | 章末・文書末に注を配置 |
| 傍注 | `snotez` | マージンに注を配置 |

### 文書開発

| 要件 | 推奨パッケージ | 理由 |
|-----|--------------|------|
| TODO管理 | `todonotes` | 視覚的、リスト生成 |
| 構造化TODO | `fixme` | 重要度分類、著者管理 |
| 変更履歴 | `changes` | 共同執筆の変更追跡 |
| PDF注釈 | `pdfcomment` | レビュー用PDF作成 |

---

## まとめ

段落レベルのフォーマットで重要なポイント：

1. **microtype は常に有効化** - 視覚的品質が大幅に向上
2. **ragged2e** - 非均等行を使う場合は標準コマンドの代わりに使用
3. **footmisc** - 脚注の細かい制御に必須
4. **todonotes/fixme** - 執筆中の管理を効率化

文書の種類と要件に応じて適切なパッケージを組み合わせることで、プロフェッショナルな組版が実現できる。
