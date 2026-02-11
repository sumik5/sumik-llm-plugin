# フロート制御（Mastering Floats）

LaTeXのフロート（図表）配置と制御に関する包括的なリファレンス。

---

## 目次

1. [LaTeXフロートの概念](#latexフロートの概念)
2. [フロート配置制御](#フロート配置制御)
3. [フロート概念の拡張](#フロート概念の拡張)
4. [キャプション制御](#キャプション制御)
5. [Key/valueアプローチ](#keyvalueアプローチ)

---

## LaTeXフロートの概念

### フロート用語

**Float classes（フロートクラス）:**
- `figure`: 図
- `table`: 表
- カスタム: `float` パッケージで定義可能

**Float areas（フロート配置エリア）:**
- **Top area**: ページ上部
- **Bottom area**: ページ下部
- **Here area**: テキスト中（インラインフロート）
- **Float page**: フロート専用ページ

**Float placement specifiers（配置パラメータ）:**

| 指定子 | 意味 | 推奨度 |
|--------|------|--------|
| `h` | Here（ここ） | △ 制約が多い |
| `t` | Top（上部） | ◎ 推奨 |
| `b` | Bottom（下部） | ◎ 推奨 |
| `p` | Page（専用ページ） | ◎ 推奨 |
| `!` | 厳格な制約を緩和 | ○ 必要に応じて |
| `H` | 強制的にここ（`float`パッケージ） | × 最後の手段 |

```latex
% 良い例
\begin{figure}[tbp]
  \includegraphics{image.pdf}
  \caption{図の説明}
\end{figure}

% 避けるべき例
\begin{figure}[h]  % 制約が強すぎる
  ...
\end{figure}
```

**Float algorithm parameters（アルゴリズムパラメータ）:**

LaTeXが内部で使用するカウンタと寸法パラメータ。

| パラメータ | デフォルト | 意味 |
|-----------|----------|------|
| `\topnumber` | 2 | ページ上部の最大フロート数 |
| `\bottomnumber` | 1 | ページ下部の最大フロート数 |
| `\totalnumber` | 3 | 1ページの最大フロート数 |
| `\topfraction` | 0.7 | 上部エリアの最大比率 |
| `\bottomfraction` | 0.3 | 下部エリアの最大比率 |
| `\textfraction` | 0.2 | テキストの最小比率 |
| `\floatpagefraction` | 0.5 | フロートページの最小比率 |

```latex
% カスタマイズ例（プリアンブルに記述）
\renewcommand{\topfraction}{0.9}
\renewcommand{\bottomfraction}{0.8}
\setcounter{topnumber}{2}
\setcounter{bottomnumber}{2}
\setcounter{totalnumber}{4}
\renewcommand{\textfraction}{0.1}
\renewcommand{\floatpagefraction}{0.7}
```

---

### フロートアルゴリズムの基本ルール

LaTeXのフロート配置は以下のルールに従う：

1. **順序の保持**: 同じクラスのフロートは入力順に配置される
2. **配置制約の遵守**: 指定された配置パラメータ（`h`, `t`, `b`, `p`）に従う
3. **ページバランス**: `\topfraction`, `\bottomfraction` などの制約を満たす
4. **繰り延べ**: 配置できないフロートは次ページ以降に繰り延べられる
5. **二段組の特殊性**: `figure*`, `table*` は必ず最初に処理される

**アルゴリズムの基本シーケンス：**

```
1. 新しいページ開始
2. 繰り延べられたフロートを処理
   - Top area に配置可能なら配置
   - 不可能なら次のステップへ
3. 本文テキストを処理
   - Here float があれば配置試行
   - 新たなフロートが出現したら繰り延べリストに追加
4. Bottom area にフロート配置試行
5. ページ終了判定
   - フロート専用ページ作成の判定
   - 必要なら次ページへ
6. 次ページへ移行
```

---

### アルゴリズムの結果と影響

**一般的な問題：**

1. **フロートの早期配置**: ソース位置より前にフロートが配置されることがある
2. **二段組フロートの繰り延べ**: `figure*`, `table*` は必ず次ページ以降に配置される
3. **繰り延べ領域の限界**: 最大18個まで（通常は十分）
4. **二段組の底部エリアなし**: `figure*[b]` は無効
5. **不必要なフロートページ**: `\floatpagefraction` が低すぎると発生
6. **ソース位置でのフロートページ**: 位置だけで判定される場合がある
7. **制約による配置不可**: すべてのパラメータが配置を制限する可能性

**対策：**

```latex
% フロートが多い場合の設定
\renewcommand{\floatpagefraction}{0.8}  % フロートページの閾値を上げる
\setcounter{totalnumber}{5}             % 1ページあたりのフロート数を増やす

% 繰り延べを減らす
\clearpage  % 適切な位置でフロートを強制出力
```

---

### fltrace パッケージ

フロートアルゴリズムをトレース（デバッグ用）。

```latex
\usepackage{fltrace}

% .logファイルにフロート配置の詳細ログが出力される
```

**出力例（.logファイル）:**
```
Float: figure [1] at input line 42
  Placement: tbp
  Trying top area... success
  Placed at top of page 3
```

---

## フロート配置制御

### fewerfloatpages パッケージ

LaTeXのフロートアルゴリズムを改善（不必要なフロートページを削減）。

```latex
\usepackage{fewerfloatpages}

% アルゴリズムが自動的に改善される
% 追加の設定は不要
```

**効果：**
- より適切なフロート配置判定
- フロートページの生成を抑制
- テキストとフロートのバランス改善

---

### placeins パッケージ

フロートバリア（フロートが特定の境界を越えないようにする）。

```latex
\usepackage{placeins}

% セクション境界でフロートをバリア
\usepackage[section]{placeins}

% 手動でバリアを配置
\FloatBarrier
```

**実用例：**

```latex
\section{セクション1}
図や表のコンテンツ...

\FloatBarrier  % ここまでのフロートを全て出力

\section{セクション2}
新しいセクションのコンテンツ...
```

**オプション：**
- `section`: セクション境界で自動バリア
- `above`, `below`: フロート配置位置の制限

---

### afterpage パッケージ

ページ境界で制御を取る。

```latex
\usepackage{afterpage}

% 次のページ境界でコマンドを実行
\afterpage{\clearpage}

% フロート配置を遅延
\afterpage{%
  \begin{figure}[t]
    \includegraphics{image.pdf}
    \caption{図}
  \end{figure}
}
```

---

### endfloat パッケージ

図表を文書末尾に配置（査読用原稿向け）。

```latex
\usepackage{endfloat}

% 全ての図表が自動的に文書末尾に移動される
% 元の位置には "[Figure 1 about here.]" のような
% プレースホルダーが挿入される
```

**オプション：**

```latex
\usepackage[
  nomarkers,    % プレースホルダーを非表示
  nolists,      % 図表一覧を非表示
  heads         % ページヘッダーに情報を表示
]{endfloat}
```

**カスタマイズ：**

```latex
% フィギュアのみ末尾に移動（テーブルは通常配置）
\usepackage[figuresonly]{endfloat}

% プレースホルダーのカスタマイズ
\renewcommand{\figureplace}{%
  \begin{center}
  [図 \thepostfig\ をここに配置]
  \end{center}
}
```

---

## フロート概念の拡張

### float パッケージ

新しいフロートタイプを作成。

```latex
\usepackage{float}

% 新しいフロートタイプの定義
\newfloat{program}{tbp}{lop}
\floatname{program}{Program}

% 使用例
\begin{program}
  \begin{verbatim}
  def hello():
      print("Hello, World!")
  \end{verbatim}
  \caption{Pythonプログラム例}
\end{program}
```

**構文：**
```latex
\newfloat{type}{placement}{extension}[outer-counter]
```

- `type`: 新しいフロートタイプ名
- `placement`: デフォルト配置（`tbp` など）
- `extension`: 目次ファイルの拡張子（例: `.lop` = List Of Programs）
- `outer-counter`: 番号付けの親カウンタ（オプション、例: `chapter`）

**フロートスタイル：**

```latex
\floatstyle{style}
\restylefloat{type}

% 利用可能なスタイル:
% - plain: 標準（キャプション下）
% - plaintop: キャプション上
% - boxed: 枠で囲む
% - ruled: 罫線で区切る
```

```latex
\floatstyle{ruled}
\restylefloat{figure}

% 全てのfigure環境が罫線スタイルになる
```

**強制配置（H オプション）：**

```latex
\begin{figure}[H]  % フロートせず、この場所に強制配置
  \includegraphics{image.pdf}
  \caption{図}
\end{figure}
```

**注意:** `H` オプションはフロートの利点を無効化するため、最後の手段としてのみ使用。

---

### 非フロート図表のキャプション

```latex
\usepackage{caption}

% フロート環境外でキャプションを使用
\captionof{figure}{図の説明}
\captionof{table}{表の説明}
```

```latex
% 実用例: minipage内で図を配置
\begin{minipage}{\textwidth}
  \centering
  \includegraphics{image.pdf}
  \captionof{figure}{ここに配置された図}
  \label{fig:nonfloat}
\end{minipage}
```

---

### rotating / rotfloat パッケージ

フロートを回転（横向き図表）。

```latex
\usepackage{rotating}

% ページ全体を回転
\begin{sidewaysfigure}
  \includegraphics[width=\textwidth]{wide-image.pdf}
  \caption{横向きの図}
\end{sidewaysfigure}

\begin{sidewaystable}
  \centering
  \begin{tabular}{llll}
    % 幅広いテーブル
  \end{tabular}
  \caption{横向きの表}
\end{sidewaystable}
```

**rotfloat パッケージ（より柔軟）：**

```latex
\usepackage{rotfloat}

% 任意の角度で回転
\begin{figure}[tbp]
  \rotfloat{90}{%
    \includegraphics{image.pdf}
  }
  \caption{90度回転した図}
\end{figure}
```

---

### wrapfig パッケージ

テキスト回り込みフロート。

```latex
\usepackage{wrapfig}

\begin{wrapfigure}{配置}{幅}
  \includegraphics[width=幅]{image.pdf}
  \caption{回り込み図}
\end{wrapfigure}
```

**配置オプション：**
- `r`, `R`: 右側（大文字は強制）
- `l`, `L`: 左側
- `i`, `I`: 内側（両面印刷）
- `o`, `O`: 外側（両面印刷）

**実用例：**

```latex
\begin{wrapfigure}{r}{0.4\textwidth}
  \centering
  \includegraphics[width=0.35\textwidth]{cat.pdf}
  \caption{猫の写真}
  \label{fig:cat}
\end{wrapfigure}

これはテキストです。この段落は図の周りを回り込みます。
LaTeXが自動的にテキストの折り返しを処理します。
長い段落であれば、図の下までテキストが続きます。
```

**注意点：**
- 段落の最初で使用すること
- 短い段落では使用しない（レイアウト崩れの原因）
- フロートページには配置されない

---

## キャプション制御

### caption パッケージ

キャプションの外観を包括的にカスタマイズ。

```latex
\usepackage{caption}

% グローバル設定
\captionsetup{
  font=small,           % フォントサイズ
  labelfont=bf,         % ラベル（"Figure 1:"）を太字
  textfont=it,          % テキストをイタリック
  format=hang,          % ハンギングインデント
  justification=raggedright,  % 左揃え
  singlelinecheck=false,      % 短いキャプションも左揃え
  skip=10pt             % 図とキャプション間のスキップ
}
```

**主要オプション：**

**フォント関連：**
- `font`: 全体のフォント（`small`, `normalsize`, `large`）
- `labelfont`: ラベル部分（`bf`, `it`, `sl`, `sc`）
- `textfont`: テキスト部分
- `labelsep`: ラベルとテキストの区切り（`colon`, `period`, `space`, `quad`, `newline`, `endash`）

**レイアウト関連：**
- `format`: 全体フォーマット（`plain`, `hang`, `indented`）
- `indention`: インデント幅
- `justification`: 行揃え（`justified`, `centering`, `raggedright`, `raggedleft`）
- `singlelinecheck`: 短いキャプションの自動センタリング（`true`/`false`）

**スペーシング：**
- `skip`: 図表とキャプション間のスペース
- `position`: キャプション位置（`top`, `bottom`, `auto`）

**実用例：**

```latex
% フォーマルな論文スタイル
\captionsetup{
  font=small,
  labelfont={bf,sf},
  format=plain,
  justification=justified
}

% カジュアルなレポートスタイル
\captionsetup{
  font=normalsize,
  labelfont=bf,
  textfont=it,
  format=hang,
  justification=raggedright
}

% 個別のフロートタイプに設定
\captionsetup[figure]{
  position=bottom,
  skip=10pt
}
\captionsetup[table]{
  position=top,
  skip=5pt
}
```

**個別のキャプションに適用：**

```latex
\begin{figure}
  \includegraphics{image.pdf}
  \captionsetup{font=large, labelfont=bf}
  \caption{特別なフォーマットの図}
\end{figure}
```

**ラベルのカスタマイズ：**

```latex
% ラベルフォーマット
\DeclareCaptionLabelFormat{custom}{#1 #2}  % デフォルト
\captionsetup{labelformat=custom}

% ラベル区切り
\captionsetup{labelsep=endash}  % "Figure 1 — Caption"

% カスタムラベル
\DeclareCaptionLabelFormat{bold}{{\bfseries #1 #2}}
\captionsetup{labelformat=bold}
```

---

### subcaption パッケージ

サブフロート（subfigure, subtable）。

```latex
\usepackage{subcaption}

\begin{figure}
  \centering

  \begin{subfigure}{0.45\textwidth}
    \includegraphics[width=\textwidth]{image1.pdf}
    \caption{サブ図1}
    \label{fig:sub1}
  \end{subfigure}
  \hfill
  \begin{subfigure}{0.45\textwidth}
    \includegraphics[width=\textwidth]{image2.pdf}
    \caption{サブ図2}
    \label{fig:sub2}
  \end{subfigure}

  \caption{メインキャプション}
  \label{fig:main}
\end{figure}
```

**参照方法：**

```latex
図~\ref{fig:main}は全体を示す。
図~\ref{fig:sub1}は詳細Aを、
図~\ref{fig:sub2}は詳細Bを示す。

% 出力: "図 1は全体を示す。図 1aは詳細Aを、図 1bは詳細Bを示す。"

% サブ番号のみ参照
\subref{fig:sub1}
% 出力: "a"
```

**カスタマイズ：**

```latex
% サブキャプションのフォーマット
\captionsetup[subfigure]{
  font=small,
  labelfont=bf,
  labelformat=simple,
  labelsep=colon
}

% サブキャプションの配置
\begin{subfigure}[t]{0.45\textwidth}  % 上揃え
  ...
\end{subfigure}
\begin{subfigure}[b]{0.45\textwidth}  % 下揃え
  ...
\end{subfigure}
```

**複数行レイアウト：**

```latex
\begin{figure}
  \centering

  % 1行目
  \begin{subfigure}{0.3\textwidth}
    \includegraphics[width=\textwidth]{img1.pdf}
    \caption{(a)}
  \end{subfigure}
  \hfill
  \begin{subfigure}{0.3\textwidth}
    \includegraphics[width=\textwidth]{img2.pdf}
    \caption{(b)}
  \end{subfigure}
  \hfill
  \begin{subfigure}{0.3\textwidth}
    \includegraphics[width=\textwidth]{img3.pdf}
    \caption{(c)}
  \end{subfigure}

  % 2行目
  \begin{subfigure}{0.3\textwidth}
    \includegraphics[width=\textwidth]{img4.pdf}
    \caption{(d)}
  \end{subfigure}
  \hfill
  \begin{subfigure}{0.3\textwidth}
    \includegraphics[width=\textwidth]{img5.pdf}
    \caption{(e)}
  \end{subfigure}

  \caption{複数のサブ図}
\end{figure}
```

**番号付けのカスタマイズ：**

```latex
% アラビア数字に変更
\renewcommand\thesubfigure{\arabic{subfigure}}

% ローマ数字に変更
\renewcommand\thesubfigure{\roman{subfigure}}

% 括弧付き
\renewcommand\thesubfigure{(\alph{subfigure})}
```

---

## Key/valueアプローチ

### hvfloat パッケージ

洗練されたキャプション配置制御。

```latex
\usepackage{hvfloat}

\hvFloat{type}{float-object}[short-caption]{caption}{label}

% 基本例
\hvFloat{figure}{\includegraphics{image.pdf}}{図の説明}{fig:label}
```

**主要キー：**

| キー | 意味 |
|------|------|
| `floatPos` | フロート配置（`tbp`） |
| `capPos` | キャプション位置（`bottom`, `top`, `left`, `right`, `inner`, `outer`） |
| `capWidth` | キャプション幅（`n`=自然, `w`=図幅, `h`=図高, `0.5`=割合） |
| `capVPos` | 垂直位置（`top`, `center`, `bottom`） |
| `objectAngle` | オブジェクトの回転角度 |
| `rotAngle` | 全体の回転角度 |
| `objectFrame` | オブジェクトを枠で囲む |

**実用例：**

```latex
% キャプションを右側に配置
\hvFloat[
  capPos=right,
  capWidth=0.4,
  capVPos=center
]{figure}{\includegraphics[width=0.5\textwidth]{image.pdf}}
{図の説明}{fig:side}

% オブジェクトを回転
\hvFloat[
  objectAngle=90,
  capPos=right
]{figure}{\includegraphics[width=\textwidth]{wide.pdf}}
{横向きの図}{fig:rotated}

% フルページフロート
\hvFloat[
  fullpage
]{figure}{\includegraphics[width=\textwidth]{large.pdf}}
{大きな図}{fig:full}
```

**スタイル定義：**

```latex
\hvDefFloatStyle{mystyle}{
  capPos=right,
  capWidth=0.4,
  objectAngle=90
}

% スタイルを適用
\hvFloat[style=mystyle]{figure}{...}{...}{...}
```

---

### keyfloat パッケージ

複数パッケージを統合した key/value インターフェース。

```latex
\usepackage{keyfloat}

\keyfig{
  w=0.8\textwidth,
  cap={図の説明},
  lbl={fig:key}
}{image.pdf}
```

**主要キー：**

| キー | 意味 |
|------|------|
| `w` | 幅 |
| `h` | 高さ |
| `cap` | キャプション |
| `scap` | 短縮キャプション（目次用） |
| `lbl` | ラベル |
| `pos` | 配置（`tbp`） |

**複雑な例：**

```latex
% サブフロート
\begin{figure}
  \keyfig[sub]{w=0.45\textwidth, cap={サブ図1}}{img1.pdf}
  \hfill
  \keyfig[sub]{w=0.45\textwidth, cap={サブ図2}}{img2.pdf}
  \caption{メインキャプション}
\end{figure}

% マージンフロート
\keyfig[margin]{
  w=\marginparwidth,
  cap={マージン図}
}{small.pdf}

% 回り込みフロート
\keyfig[wrap]{
  w=0.3\textwidth,
  cap={回り込み図}
}{small.pdf}
```

---

## パッケージ選択ガイド

### フロート配置制御

| 目的 | 推奨パッケージ | 理由 |
|------|-------------|------|
| 基本的な配置 | 標準 `[tbp]` | 追加パッケージ不要 |
| セクション境界で制御 | `placeins` | シンプルで効果的 |
| フロートページ削減 | `fewerfloatpages` | アルゴリズム改善 |
| デバッグ | `fltrace` | アルゴリズムを可視化 |
| 強制配置 | `float` の `[H]` | 最後の手段 |

### 新しいフロートタイプ

| 目的 | 推奨 |
|------|------|
| カスタムフロート作成 | `float` パッケージ |
| 非フロートキャプション | `caption` パッケージの `\captionof` |

### 回転フロート

| 目的 | 推奨 |
|------|------|
| 横向きページ全体 | `rotating` の `sidewaysfigure` |
| 柔軟な回転 | `rotfloat` |

### キャプション制御

| 目的 | 推奨 |
|------|------|
| 基本的なカスタマイズ | `caption` パッケージ |
| サブフロート | `subcaption` パッケージ |
| 高度なレイアウト | `hvfloat` / `keyfloat` |

### 特殊な配置

| 目的 | 推奨 |
|------|------|
| テキスト回り込み | `wrapfig` |
| マージン配置 | `keyfloat` のマージンフロート |
| 文書末尾配置 | `endfloat` |

---

## ベストプラクティス

### 配置パラメータの選び方

```latex
% 推奨: 柔軟な配置
\begin{figure}[tbp]
  ...
\end{figure}

% 避ける: 制約が強すぎる
\begin{figure}[h]   % ❌
  ...
\end{figure}

% 緊急時のみ: 強制配置
\begin{figure}[H]   % ⚠️ 最後の手段
  ...
\end{figure}
```

### キャプションの書き方

```latex
% 良い例: 簡潔で情報豊富
\caption{実験結果: 温度変化による反応速度の推移}

% 避ける: 冗長
\caption{この図は実験結果を示しており、温度が変化すると
         反応速度がどのように推移するかを表しています。}

% 長い説明は短縮版を用意
\caption[短縮版]{詳細な説明...}
```

### フロートの参照

```latex
% 常に \label と \ref を使用
\begin{figure}[tbp]
  \includegraphics{image.pdf}
  \caption{図の説明}
  \label{fig:example}  % caption の後に配置
\end{figure}

図~\ref{fig:example}は...

% autoref（hyperref使用時）
\autoref{fig:example}  % "図 1" と自動表示
```

### フロートが多い文書

```latex
% プリアンブルで調整
\renewcommand{\topfraction}{0.85}
\renewcommand{\bottomfraction}{0.7}
\renewcommand{\textfraction}{0.1}
\renewcommand{\floatpagefraction}{0.8}
\setcounter{topnumber}{3}
\setcounter{bottomnumber}{3}
\setcounter{totalnumber}{6}

% 適切な位置でフロートを出力
\clearpage  % セクション終わりなど
```

### サブフロートの推奨レイアウト

```latex
% 2列レイアウト（推奨）
\begin{figure}
  \centering
  \begin{subfigure}{0.45\textwidth}
    ...
  \end{subfigure}
  \hfill  % 水平スペースを自動調整
  \begin{subfigure}{0.45\textwidth}
    ...
  \end{subfigure}
  \caption{メインキャプション}
\end{figure}

% 3列レイアウト
\begin{figure}
  \centering
  \begin{subfigure}{0.3\textwidth}
    ...
  \end{subfigure}
  \hfill
  \begin{subfigure}{0.3\textwidth}
    ...
  \end{subfigure}
  \hfill
  \begin{subfigure}{0.3\textwidth}
    ...
  \end{subfigure}
  \caption{メインキャプション}
\end{figure}
```

---

## まとめ

- **配置パラメータは柔軟に**: `[tbp]` を基本とする
- **`[h]` の乱用を避ける**: 制約が強すぎてフロートが配置されない原因
- **キャプションは `caption` パッケージでカスタマイズ**: 一貫したスタイル
- **サブフロートは `subcaption`**: 標準的で安定した実装
- **フロートバリアで制御**: `placeins` でセクション境界を管理
- **強制配置は最後の手段**: `[H]` はフロートの利点を失う
- **アルゴリズムパラメータを理解**: 必要に応じて調整
- **デバッグには `fltrace`**: 問題の原因を特定
- **回転は `rotating` / `rotfloat`**: 横向き図表に対応
- **key/value アプローチは `hvfloat` / `keyfloat`**: 一貫したインターフェース
