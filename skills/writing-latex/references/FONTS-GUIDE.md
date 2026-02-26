# フォント選択ガイド

LaTeX におけるフォント選択システム（NFSS / fontspec）の包括的ガイド。

---

## 1. NFSS（New Font Selection Scheme）

LaTeX 2εの標準フォント選択メカニズム。30年以上の歴史を持つ堅牢なシステム。

### 5つのフォント属性

NFSS はフォントを以下の5つの独立した属性で管理:

| 属性 | 英語 | 値の例 | 説明 |
|------|------|-------|------|
| エンコーディング | encoding | `OT1`, `T1`, `TU` | グリフの配置規則 |
| ファミリ | family | `cmr`, `ptm`, `lmr` | 書体（Roman, Sans, Mono等） |
| シリーズ | series | `m`, `b`, `bx` | 太さ+幅（medium, bold等） |
| シェイプ | shape | `n`, `it`, `sl`, `sc` | 形状（upright, italic, slanted, small caps） |
| サイズ | size | `10pt`, `12pt` | フォントサイズ |

### 標準フォントコマンド vs 宣言

| コマンド形式 | 宣言形式 | 変更内容 |
|------------|---------|---------|
| `\textrm{...}` | `\rmfamily` | Serifed（ローマン体） |
| `\textsf{...}` | `\sffamily` | Sans Serif |
| `\texttt{...}` | `\ttfamily` | Typewriter（等幅） |
| `\textmd{...}` | `\mdseries` | Medium series |
| `\textbf{...}` | `\bfseries` | Bold series |
| `\textup{...}` | `\upshape` | Upright shape |
| `\textit{...}` | `\itshape` | Italic shape |
| `\textsl{...}` | `\slshape` | Slanted shape |
| `\textsc{...}` | `\scshape` | Small Caps |
| `\emph{...}` | `\em` | Emphasis（文脈依存） |
| `\textnormal{...}` | `\normalfont` | ドキュメント標準フォント |

**使い分け**:
- **コマンド形式**: 短いテキスト片、イタリック補正自動、引数内改段落不可
- **宣言形式**: 環境定義・長いテキスト、イタリック補正手動（`\/`）、改段落可能

**例**:
```latex
% コマンド形式（推奨: 短いテキスト）
This is \textbf{bold} text.

% 宣言形式（環境定義向け）
{\bfseries This is bold.}

\begin{bfseries}
This is bold.
\end{bfseries}
```

### イタリック補正

イタリック・スラント体から upright に戻る際に必要な微調整。

```latex
% コマンド形式: 自動で挿入
This is \textit{italic} text.

% 宣言形式: 手動で挿入（\/）
This is {\itshape italic\/} text.

% 句読点の前では不要
{\itshape italic}, text.
```

### Emphasis のネスト（2020年拡張）

```latex
% デフォルト動作
\emph{First \emph{second}}  % italic → upright

% カスタマイズ
\DeclareEmphSequence{\itshape, \upshape\scshape, \itshape}
\emph{First \emph{second \emph{third}}}
% → italic → upright small caps → italic small caps

% リセットコマンド
\emreset  % ネスト階層をリセット
\emforce  % フォント変更検出を強制
```

### Small Caps の新しい動作（2020年拡張）

従来は「シェイプ」として扱われたが、現在は **「文字ケース状態」として独立**。

```latex
% Italic + Small Caps
\textit{\textsc{Text}}  % → Italic Small Caps（利用可能な場合）

% Upright に戻る（Small Caps は維持）
\textsc{\textup{Text}}  % → Upright Small Caps

% Upper/Lowercase に戻る（新コマンド）
\textsc{\textulc{Text}}  % → Upright Upper/Lowercase
\textsc{\ulcshape Text}  % 宣言形式
```

### サイズ変更コマンド

| コマンド | 相対サイズ |
|---------|----------|
| `\tiny` | 最小 |
| `\scriptsize` | |
| `\footnotesize` | |
| `\small` | |
| `\normalsize` | ドキュメント標準 |
| `\large` | |
| `\Large` | |
| `\LARGE` | |
| `\huge` | |
| `\Huge` | 最大 |

**注意**:
- 実際のサイズはドキュメントクラスとオプション（`10pt`, `11pt`, `12pt`）に依存
- 相対サイズ変更は `relsize` パッケージで実現（後述）

### 低レベルコマンド

```latex
% 個別属性変更
\fontencoding{T1}     % エンコーディング
\fontfamily{ptm}      % ファミリ
\fontseries{b}        % シリーズ
\fontshape{it}        % シェイプ
\fontsize{12pt}{14pt} % サイズ・ベースライン間隔
\selectfont           % 変更を適用（必須）

% 例
{\fontfamily{ptm}\selectfont Times Roman text}
```

---

## 2. フォントエンコーディング

### pdfLaTeX 用エンコーディング

| エンコーディング | 文字数 | 用途 | 推奨度 |
|----------------|-------|------|--------|
| **OT1** | 128 | 英語のみ、アクセント記号は合成 | ❌ 非推奨 |
| **T1** | 256 | ラテン文字30言語以上、ハイフネーション対応 | ✅ 推奨 |

**設定**:
```latex
\usepackage[T1]{fontenc}  % T1エンコーディングを使用
```

### Unicode エンジン用エンコーディング（XeLaTeX/LuaLaTeX）

| エンコーディング | 文字数 | 用途 |
|----------------|-------|------|
| **TU** | Unicode全体 | XeLaTeX/LuaLaTeX の自動デフォルト |

**注意**: Unicode エンジンでは「tofu」（□）に注意。フォントに存在しない文字は警告なしで欠落する。

---

## 3. fontspec パッケージ（Unicode エンジン専用）

XeLaTeX/LuaLaTeX でシステムフォント・OpenType/TrueType フォントを使用。

### 基本構文

```latex
\usepackage{fontspec}

% メインドキュメントフォント
\setmainfont{Times New Roman}
\setsansfont{Helvetica}
\setmonofont{Courier New}

% 追加フォントファミリ
\newfontfamily\japanesefont{Hiragino Mincho Pro}
```

### 主要オプション

| カテゴリ | オプション | 値 | 説明 |
|---------|---------|-----|------|
| **数字** | `Numbers` | `Lining`, `OldStyle`, `Proportional`, `Monospaced` | 数字スタイル |
| **合字** | `Ligatures` | `Common`, `Rare`, `Historic`, `TeX` | 合字の有効化 |
| **文字変形** | `Letters` | `SmallCaps`, `Uppercase`, `UppercaseSmallCaps` | 小文字→大文字変換 |
| **スタイル** | `Style` | `Swash`, `Alternate`, `Historic` | 字体バリエーション |
| **カーニング** | `Kerning` | `On`, `Off` | 文字間調整 |

**例**:
```latex
\setmainfont{EB Garamond}[
  Numbers = OldStyle,
  Ligatures = {Common, TeX},
  Style = Swash
]

\newfontfamily\titlefont{Cinzel}[
  Letters = UppercaseSmallCaps,
  Numbers = Lining
]
```

### 個別フォント設定

```latex
% フォントファイルを直接指定
\setmainfont{MyFont}[
  Extension = .otf,
  UprightFont = *-Regular,
  BoldFont = *-Bold,
  ItalicFont = *-Italic,
  BoldItalicFont = *-BoldItalic
]

% フォント機能の選択
\setmainfont{Minion Pro}[
  UprightFeatures = {SizeFeatures = {
    {Size = -10, Font = *Caption},
    {Size = 10-14, Font = *Regular},
    {Size = 14-, Font = *Subhead}
  }}
]
```

### NFSS コマンドとの連携

fontspec は内部的に NFSS を使用。標準の `\rmfamily`, `\textbf` 等はそのまま動作。

---

## 4. フォント分類と推奨

### Humanist Serif (Oldstyle)

人文主義的、斜めのストレス、低コントラスト。

| フォント | 特徴 | 推奨用途 |
|---------|------|---------|
| Alegreya | 可読性高い、豊富なウェイト | 人文系学術論文 |
| Coelacanth | 古風な雰囲気 | 歴史・文学 |
| fbb (Cardo派生) | Bembo風、小文字が大きい | 人文系書籍 |

### Garalde Serif (Oldstyle)

ルネサンス期、適度なコントラスト。

| フォント | 特徴 | 推奨用途 | 数式対応 |
|---------|------|---------|---------|
| EB Garamond | Claude Garamond復刻、エレガント | 学術論文・書籍 | garamondx+math |
| Crimson Pro / Cochineal | モダンな Garamond、スワッシュあり | 学術・商業印刷 | cochineal（数式） |
| Libertinus Serif | 広いグリフ範囲、数式対応 | 多言語文書 | libertinus-otf |

### Transitional / Neoclassical

18世紀、垂直ストレス、高コントラスト。

| フォント | 特徴 | 推奨用途 | 数式対応 |
|---------|------|---------|---------|
| Baskerville | バランス良好、汎用性高い | ビジネス・学術 | mathdesign |
| Charter | コンパクト、低解像度対応 | 技術文書 | mathdesign |
| Caslon | 伝統的、落ち着いた印象 | 書籍・公式文書 | - |

### Didone (Modern)

19世紀、高コントラスト、垂直ストレス。

| フォント | 特徴 | 推奨用途 |
|---------|------|---------|
| Bodoni | 極端なコントラスト、エレガント | タイトル・装飾 |
| Didot | フランス革命期、洗練 | ファッション・高級印刷 |
| Old Standard | Cyrillic対応、学術的 | スラブ語文書 |

### Slab Serif (Egyptian)

19世紀、太いセリフ、低コントラスト。

| フォント | 特徴 | 推奨用途 | 数式対応 |
|---------|------|---------|---------|
| Bitter | モダン、読みやすい | Web・プレゼン | - |
| Concrete | Knuth設計、丸みのあるセリフ | 技術文書 | concrete+euler |
| Roboto Slab | Google フォント、幾何学的 | デジタル文書 | - |

### Sans Serif

セリフなし、モダン。

| フォント | 特徴 | 推奨用途 | 数式対応 |
|---------|------|---------|---------|
| Alegreya Sans | Alegreya の Sans 版 | プレゼン・UI | - |
| Fira Sans | Mozilla、多言語対応 | UI・技術文書 | newtx/firamath |
| Lato | ヒューマニスト、読みやすい | ビジネス・Web | - |
| Noto Sans | Google、多言語・tofu防止 | グローバル文書 | - |

### Monospaced

等幅、コード表示向け。

| フォント | 特徴 | 推奨用途 |
|---------|------|---------|
| Fira Mono | Fira ファミリ、読みやすい | コードリスト |
| Inconsolata | コンパクト、プログラミング向け | IDE・コード例 |
| Source Code Pro | Adobe、ゼロスラッシュ | 技術文書 |

### Historical / Decorative

装飾的、特殊用途。

| フォント | 特徴 | 推奨用途 |
|---------|------|---------|
| Cinzel | ローマ碑文風、大文字のみ | タイトル・見出し |
| Fell Types | 17世紀、古風 | 歴史文書・装飾 |

---

## 5. テキスト+数式フォントペアリング推奨表

| テキストフォント | 数式フォントパッケージ | 備考 |
|---------------|---------------------|------|
| **EB Garamond** | `garamondx`, `newtxmath` | Garamond風数式 |
| **Crimson Pro / Cochineal** | `cochineal` | 統合数式対応 |
| **Libertinus Serif** | `libertinus-otf` | OpenType数式統合 |
| **Baskerville** | `mathdesign[charter]` | Transitional数式 |
| **Charter** | `mathdesign[charter]` | Charter専用数式 |
| **Palatino** | `mathpazo`, `newpxmath` | 古典的組み合わせ |
| **Times** | `mathptmx`, `newtxmath` | ビジネス・学術標準 |
| **Concrete** | `euler` | Knuth組み合わせ |
| **Fira Sans** | `newtxmath`, `firamath` | Sans数式 |
| **Computer Modern** | `amsmath`（標準） | LaTeX デフォルト |
| **Latin Modern** | `lmodern` | CM の Unicode 版 |

**設定例**:
```latex
% pdfLaTeX: EB Garamond + 数式
\usepackage[T1]{fontenc}
\usepackage{ebgaramond}
\usepackage[garamond]{newtxmath}

% XeLaTeX/LuaLaTeX: Libertinus + 数式
\usepackage{libertinus-otf}  % テキスト+数式統合
```

---

## 6. デフォルトフォントの変更

### 方法1: パッケージを使用（推奨）

```latex
\usepackage{ebgaramond}     % EB Garamond
\usepackage{libertinus-otf} % Libertinus（Unicode）
\usepackage{cochineal}      % Crimson Pro / Cochineal
```

### 方法2: 手動設定

```latex
% ファミリ名を変更
\renewcommand{\rmdefault}{ptm}   % Times
\renewcommand{\sfdefault}{phv}   % Helvetica
\renewcommand{\ttdefault}{pcr}   % Courier

% シリーズ・シェイプのデフォルト変更
\DeclareFontSeriesDefault[rm]{bf}{b}  % bold → b
\DeclareFontSeriesDefault[rm]{md}{m}  % medium → m
```

### 方法3: fontspec（Unicode エンジン）

```latex
\usepackage{fontspec}
\setmainfont{EB Garamond}
\setsansfont{Fira Sans}
\setmonofont{Fira Mono}
```

---

## 7. 記号フォント

### pifont パッケージ（ZapfDingbats）

```latex
\usepackage{pifont}

\ding{51}  % ✓ チェックマーク
\ding{55}  % ✗ バツ印
\ding{72}  % ★ 星

% リスト記号として使用
\begin{dinglist}{43}  % ➤
  \item Item 1
  \item Item 2
\end{dinglist}
```

### fontawesome5 パッケージ

```latex
\usepackage{fontawesome5}

\faGithub  % GitHub アイコン
\faTwitter % Twitter アイコン
\faEnvelope % 封筒アイコン
```

### tipa パッケージ（IPA音声記号）

```latex
\usepackage{tipa}

\textipa{["ExA:mpl]}  % ['ɛɡˈzɑːmpl]
```

---

## 8. relsize パッケージ（相対サイズ変更）

```latex
\usepackage{relsize}

% 相対サイズ変更
\relsize{2}       % 2段階大きく
\relsize{-1}      % 1段階小さく
\larger           % 1段階大きく
\smaller          % 1段階小さく
\textlarger{text} % コマンド形式
\textsmaller{text}

% 任意スケール
\relscale{1.2}    % 1.2倍に拡大
```

---

## 9. scalefnt パッケージ（スケーリング）

```latex
\usepackage{scalefnt}

% 現在のフォントをスケール
\scalefont{1.5}  % 1.5倍
\scalefont{0.8}  % 0.8倍
```

---

## ベストプラクティス

### エンコーディング選択

| エンジン | 推奨エンコーディング | パッケージ |
|---------|-------------------|-----------|
| pdfLaTeX | **T1** | `\usepackage[T1]{fontenc}` |
| XeLaTeX / LuaLaTeX | **TU**（自動） | `\usepackage{fontspec}` |

### フォント選択の判断基準

1. **用途**: 学術論文 → Garamond系、技術文書 → Slab Serif、プレゼン → Sans Serif
2. **可読性**: 長文 → Humanist/Garalde、見出し → Didone/Decorative
3. **数式対応**: 理工系論文 → 数式フォントパッケージとの組み合わせを確認
4. **多言語対応**: Noto, Libertinus （Unicode エンジン推奨）

### コマンド vs 宣言

| 使用場面 | 推奨 |
|---------|------|
| 短いテキスト片 | コマンド形式（`\textbf{...}`） |
| 環境定義 | 宣言形式（`\bfseries`） |
| 長いパラグラフ | 環境形式（`\begin{bfseries}...\end{bfseries}`） |

### イタリック補正

- **自動**: コマンド形式（`\textit{...}`）
- **手動**: 宣言形式 → 句読点以外で `\/` を挿入
- **不要**: 句読点（`,`, `.`）の前

### Small Caps の活用

```latex
% 名前の強調
\newcommand\name[1]{\textsc{\MakeLowercase{#1}}}
\name{JOHN DOE}  % → John Doe（Small Caps）

% 頭字語
\newcommand\acro[1]{\textsc{\MakeLowercase{#1}}}
\acro{NASA}  % → NASA（Small Caps）
```

### フォント組み合わせの原則

1. **同一スーパーファミリ**: Alegreya + Alegreya Sans
2. **コントラスト**: Didone（見出し） + Humanist（本文）
3. **調和**: x-height が近いフォント同士
4. **過剰を避ける**: 1文書に3ファミリまで

---

## 10. pdfLaTeX 対応フォントパッケージ（具体的な読み込みコード）

分類表を補完する、実際の使用例集。すべて pdfLaTeX で動作する。

### セリフ系フォント

#### Latin Modern（デフォルトの推奨代替）

```latex
\usepackage{lmodern}           % Computer Modern の Unicode 対応改良版
\usepackage[T1]{fontenc}       % T1 エンコーディングと組み合わせて使用
```

#### Kp-Fonts（統合フォントセット）

```latex
\usepackage{kpfonts}           % テキスト + 数式の統合フォントセット
\usepackage[light]{kpfonts}    % ライトウェイト版
% \usepackage[oldstylenums]{kpfonts}  % オールドスタイル数字バリアント
```

#### newtx（Times 系、推奨の分割パッケージ）

```latex
\usepackage{newtxtext}  % テキスト: Times Roman 系
\usepackage{newtxmath}  % 数式: Times 系数式フォント
% 注意: \usepackage{times} は非推奨。newtxtext/newtxmath を使用すること
```

#### newpx（Palatino 系、推奨の分割パッケージ）

```latex
\usepackage{newpxtext}  % テキスト: Palatino 系
\usepackage{newpxmath}  % 数式: Palatino 系数式フォント
% 旧: \usepackage{mathpazo} は現在 newpxtext+newpxmath に置き換えが推奨
```

#### mathdesign（Charter / Utopia / Garamond + 数式）

```latex
\usepackage[charter]{mathdesign}   % Charter テキスト + 数式
\usepackage[utopia]{mathdesign}    % Utopia テキスト + 数式
\usepackage[garamond]{mathdesign}  % Garamond テキスト + 数式
```

#### fouriernc（New Century Schoolbook + Fourier 数式）

```latex
\usepackage{fouriernc}
% New Century Schoolbook テキストと Fourier 数式フォントの組み合わせ
```

#### Concrete + Concmath（Knuth の組み合わせ）

```latex
\usepackage{concrete}   % Concrete Roman テキスト
\usepackage{concmath}   % Concrete 数式フォント
% または \usepackage{eulervm} で Euler 数式フォントを追加
```

#### Bookman + Kmath

```latex
\usepackage{bookman}   % Bookman テキストフォント
\usepackage{kmath}     % Kerkis 数式フォント（bookman と相性が良い）
```

### サンセリフ系フォント（数式対応）

#### Arev（数式対応サンセリフ）

```latex
\usepackage{arev}
% テキストと数式の両方をサンセリフに変更
% プレゼンテーションや画面表示に適する
```

#### CM Bright（Computer Modern サンセリフ）

```latex
\usepackage{cmbright}
% テキストと数式を Computer Modern の明るいサンセリフに変更
```

#### Kurier（幾何学的サンセリフ）

```latex
\usepackage[math]{kurier}
% math オプションで数式フォントも同時に変更
```

#### Helvetica + sfmath（本文をサンセリフに変更）

```latex
\usepackage[scaled=0.95]{helvet}   % Helvetica（scaled: メインフォントに合わせて縮小）
\usepackage{sfmath}                % サンセリフ数式フォント（または sansmath パッケージ）
\renewcommand{\familydefault}{\sfdefault}  % サンセリフをデフォルト本文フォントに
```

### タイプライタ系フォント

#### Inconsolata（コード表示向け推奨）

```latex
\usepackage{inconsolata}
% または区別しやすいグリフのバリアント
\usepackage[varqu,varl]{inconsolata}
% varqu: 直立クォーテーション、varl: 区別しやすい l/1/I
```

#### Bera Mono（コード表示向け）

```latex
\usepackage[scaled]{beramono}
% scaled: メインフォントのサイズに合わせて自動スケール
```

#### Courier

```latex
\usepackage{courier}              % 標準の Courier
\usepackage[scaled]{couriers}     % Courier の scaled バリアント
```

### 装飾・手書きフォント

#### Calligra（カリグラフィ）

```latex
\usepackage{calligra}
% \calligra コマンドでフォント切り替え
% グループ内またはコマンドでスコープを限定する

{\calligra A beautiful calligraphic text}

% または専用コマンドを定義
\newcommand{\calligraphic}[1]{{\calligra #1}}
\calligraphic{Special heading}
```

#### Miama Nueva（優雅な手書き風）

```latex
\usepackage{miama}
% \fmmfamily で手書きフォントに切り替え
% アスセンダー・ディセンダーが特に優雅

{\fmmfamily A graceful handwriting style}
% 招待状・タイトルページなどの装飾テキストに適する
```

### デフォルト本文フォントをサンセリフにする

```latex
% 方法1: familydefault を変更（汎用的）
\renewcommand{\familydefault}{\sfdefault}

% 方法2: 専用パッケージを使用（数式も含めて変更）
\usepackage{arev}       % Arev Sans（数式対応）
\usepackage{cmbright}   % CM Bright（数式対応）
\usepackage[math]{kurier}  % Kurier（数式対応）
```

---

## 11. fontspec の Scale オプション（LuaLaTeX / XeLaTeX）

複数フォントの x-height（小文字の高さ）を揃える：

```latex
\usepackage{fontspec}
\usepackage{unicode-math}   % 数式フォントの選択に必要

% メインフォントに合わせてスケール
\setmainfont{Cambria}
\setsansfont{Segoe UI}[Scale=MatchLowercase]      % x-height を一致させる
\setmonofont{Lucida Console}[Scale=MatchLowercase]
\setmathfont{Cambria Math}[Scale=MatchLowercase]

% 数値でスケール指定
\setsansfont{Helvetica Neue}[Scale=0.95]

% 新しいフォントファミリをコマンドとして定義（特定テキストのみに使用）
\newfontfamily{\calligraphicfont}{Zapfino}
\newcommand{\calligraphic}[1]{{\calligraphicfont #1}}
% 使用例: \calligraphic{A graceful Zapfino example}
```

**LuaLaTeX 推奨**: XeLaTeX より積極的にメンテナンスされており、OpenType/TrueType システムフォントの利用には LuaLaTeX を推奨する。

---

## LaTeX フォントカタログ

利用可能なすべての LaTeX フォントを視覚的に確認できる公式リソース：

- **The LaTeX Font Catalogue**: https://www.tug.org/FontCatalogue/
- TeX Live 収録フォントを網羅、サンプル画像と読み込みコードを提供
- カテゴリ別ブラウズ（セリフ・サンセリフ・タイプライタ・手書き・数式など）
- フォントをクリックすると使用例・ロードコード・詳細情報を確認可能
