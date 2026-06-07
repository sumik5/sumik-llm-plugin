# グラフィックス高度活用

LaTeX における高度なグラフィックス操作・描画機能のリファレンス。

---

## 1. graphics と graphicx の比較

### パッケージの選択基準

| 項目 | graphics | graphicx | 推奨 |
|------|---------|----------|------|
| 構文 | 標準LaTeX形式 | key/value形式 | graphicx |
| 可読性 | やや低い | 高い | graphicx |
| オプション順序 | 無関係 | **重要** | - |
| 拡張性 | 限定的 | 高い | graphicx |

**推奨**: 現代的な開発では `graphicx` を使用すること。トークンオーバーヘッドは無視できる。

---

## 2. \includegraphics 詳細解説

### 基本構文（graphicx）

```latex
\includegraphics[key/value list]{file}
\includegraphics*[key/value list]{file}  % clip=true と同等
```

### 基本オプション

| キー | 値 | 説明 |
|-----|-----|------|
| `width` | 寸法 | 幅を指定（高さは比率維持） |
| `height` | 寸法 | 高さを指定（幅は比率維持） |
| `totalheight` | 寸法 | 高さ+深さの合計（90度以上の回転時に使用） |
| `scale` | 数値 | 拡大縮小率 |
| `angle` | 角度 | 反時計回りの回転角度 |
| `keepaspectratio` | true/false | width・height両指定時にアスペクト比維持 |

**例**:
```latex
% 幅を指定（高さは自動調整）
\includegraphics[width=0.8\textwidth]{image.pdf}

% 高さ・幅両指定でアスペクト比維持
\includegraphics[width=10cm, height=5cm, keepaspectratio]{image.pdf}

% 回転（注意: totalheightを使用）
\includegraphics[angle=90, totalheight=5cm]{image.pdf}
```

### 高度なオプション

#### クリッピング系

| キー | 値 | 説明 |
|-----|-----|------|
| `clip` | true/false | viewportまたはtrimで指定した領域外を非表示 |
| `viewport` | `llx lly urx ury` | 表示領域（左下・右上の座標、単位: bp） |
| `trim` | `left bottom right top` | 各辺から切り取る量 |

**例**:
```latex
% 画像の一部を切り出し
\includegraphics[viewport=20 20 50 80, clip]{image.pdf}

% 各辺からトリミング（負の値で拡張も可能）
\includegraphics[trim=10 10 10 10, clip]{image.pdf}
```

#### バウンディングボックス制御

| キー | 値 | 説明 |
|-----|-----|------|
| `bb` | `llx lly urx ury` | バウンディングボックスを上書き |
| `hiresbb` | true/false | `%%HiResBoundingBox`（実数座標）を優先 |
| `natwidth`, `natheight` | 寸法 | 自然な幅・高さ |

#### キーの順序依存性（重要）

graphicxでは **キーは左から右へ順次適用** される。

```latex
% 正方形を45度回転→10mmに拡大
\includegraphics[angle=45, width=10mm]{square.pdf}

% 正方形を10mmに拡大→45度回転（結果が異なる）
\includegraphics[width=10mm, angle=45]{square.pdf}
```

### デフォルトキー値の設定

```latex
\setkeys{Gin}{width=\linewidth}  % 全画像を行幅に合わせる

\setkeys{Grot}{origin=ct}  % \rotatebox のデフォルト回転中心
```

### ファイル検索の設定

```latex
% 画像ディレクトリを指定
\graphicspath{{./images/}{./figures/}}

% 検索する拡張子を指定（順序重要）
\DeclareGraphicsExtensions{.pdf,.png,.jpg}

% 拡張子指定を強制（空引数）
\DeclareGraphicsExtensions{}
```

---

## 3. overpic パッケージ

画像上にpicture環境を重ねて注釈を追加。

### 基本構文

```latex
\usepackage{overpic}

\begin{overpic}[key/value list]{file}
  \put(x, y){text}
  \put(x, y){\vector(dx, dy){length}}
  % picture コマンド
\end{overpic}
```

### 座標系

- **デフォルト**: 長辺を100単位とするパーセント座標（`percent`）
- **代替**: `permil`（1000単位）、`rel=<n>`（任意の相対値）

### 主要オプション

| キー | 説明 |
|-----|------|
| `grid` | グリッドを表示（開発時に便利） |
| `tics=<n>` | グリッド間隔を指定 |
| その他 | graphicxの全キーに対応（`width`, `angle`等） |

### 使用例

```latex
\begin{overpic}[width=0.8\textwidth, grid, tics=10]{diagram.pdf}
  \color{red}
  \put(20, 80){\textbf{重要部分}}
  \put(22, 78){\vector(0, -1){15}}
  \put(50, 50){\framebox{注釈}}
\end{overpic}
```

**Overpic環境**: 画像の代わりにLaTeXコードを受け取る版。

```latex
\begin{Overpic}[grid, rel=50, tics=10]{$ \sum_{i=1}^n x_i $}
  \Vector(40, 5)(32, 9)
  \put(42, 3){\footnotesize 説明}
\end{Overpic}
```

---

## 4. adjustbox パッケージ

key/value形式で統一されたボックス操作インターフェース。

### 基本構文

```latex
\usepackage{adjustbox}

\adjustbox{key/value list}{material}
\begin{adjustbox}{key/value list}
  material  % verbatim可能
\end{adjustbox}
```

### 主要機能カテゴリ

#### サイズ制御

| キー | 説明 |
|-----|------|
| `width`, `height`, `totalheight` | 指定サイズに拡大縮小 |
| `min width`, `max width` | 最小・最大幅（必要時のみ拡大縮小） |
| `min size`, `max size` | 全辺の最小・最大サイズ |
| `scale=<h> [<v>]` | 水平・垂直スケール（1つまたは2つの数値） |

#### トリミング・クリッピング

| キー | 説明 |
|-----|------|
| `trim=<all> / <lr> <tb> / <l> <b> <r> <t>` | graphicx拡張版（1/2/4値対応） |
| `Trim`, `Clip` | 複数回使用可能（graphicxのtrim/clipは最後のみ有効） |
| `rndcorners=<r> / <l> <r> / <l> <b> <r> <t>` | 角丸クリッピング |

#### フレーム

| キー | 説明 |
|-----|------|
| `fbox=<rule> [<sep>] [<outer>]` | `\fbox`スタイル（デフォルトあり） |
| `frame=<rule> [<sep>] [<outer>]` | `\frame`スタイル（sep=0pt） |
| `rndframe=<r>... {color=..., width=..., sep=...}` | 角丸フレーム |
| `cfbox`, `cframe` | 色付きフレーム |

#### マージン・配置

| キー | 説明 |
|-----|------|
| `margin`, `padding` | マージン追加（1/2/4値） |
| `margin*`, `padding*` | ベースライン調整版 |
| `vspace=<above> [<below>]` | 垂直スペース追加 |
| `raise=<amt> [<height>] [<depth>]` | ボックスを持ち上げ |
| `valign=T/M/B/t/m/b` | 垂直位置調整 |
| `lap=<amt>`, `llap`, `rlap` | 水平オーバーラップ |

#### テキスト整形

| キー | 説明 |
|-----|------|
| `left`, `center`, `right` | 指定幅内での配置（デフォルト: `\linewidth`） |
| `inner`, `outer` | 奇数偶数ページで自動切替 |
| `pagecenter`, `pageleft`, `pageright` | ページ全体基準の配置 |

#### 色

| キー | 説明 |
|-----|------|
| `color` | 全体の色 |
| `bgcolor` | 背景色 |
| `fgcolor` | 前景色（フレーム除く） |

#### 寸法コマンド

```latex
% 元のボックス寸法
\Width, \Height, \Depth, \Totalheight

% 処理後のボックス寸法
\width, \height, \depth, \totalheight

% 最小・最大辺
\Smallestside, \Largestside  % 元の寸法
\smallestside, \largestside  % 処理後の寸法
```

### プリセット・環境定義

```latex
% デフォルト設定
\adjustboxset{frame, margin=2pt}
\adjustboxset*{angle=10}  % ユーザー指定キーの後に適用

% 新しいコマンド定義
\newadjustboxcmd\mybox[1][blue]{cfbox=#1 1pt, angle=10}
\mybox{テキスト}
\mybox[red]{テキスト}

% 新しい環境定義
\newadjustboxenv{myenv}[1]{frame, title=#1}
\begin{myenv}{タイトル}
  内容
\end{myenv}
```

### 画像操作統合

```latex
% adjustbox内で\includegraphics使用
\adjustbox{width=10cm, frame, margin=5pt}{%
  \includegraphics{image.pdf}%
}

% adjustimage（\adjustbox + \includegraphics）
\adjustimage{width=10cm, frame, margin=5pt}{image.pdf}

% adjincludegraphics（\includegraphics互換構文）
\adjincludegraphics[width=10cm, frame, margin=5pt]{image.pdf}
```

---

## 5. tcolorbox パッケージ

多機能カラーボックス（500ページ超のマニュアル）。

### 基本構文

```latex
\usepackage{tcolorbox}

\begin{tcolorbox}[key/value list]
  top part
  \tcblower  % オプション: 上下分割
  bottom part
\end{tcolorbox}

\tcbox[key/value list]{content}  % インライン版
```

### デフォルト設定

```latex
\tcbset{
  colback=blue!10,
  colframe=blue!75!black,
  fonttitle=\bfseries
}
```

### 外部ジオメトリ

| キー | 説明 |
|-----|------|
| `width` | ボックス幅（デフォルト: `\linewidth`） |
| `height` | ボックス高さ（自動計算が通常） |
| `before skip`, `after skip` | 前後の垂直スペース |
| `left skip`, `right skip` | 左右のマージン |
| `nobeforeafter` | 前後スペースをゼロに |
| `grow to left by`, `grow to right by` | バウンディングボックス外への拡張 |

### 内部ジオメトリ

| キー | 説明 |
|-----|------|
| `left`, `right`, `top`, `bottom` | 内部パディング |
| `lefttitle`, `righttitle` | タイトル部の左右パディング |
| `leftupper`, `rightupper` | 上部の左右パディング |
| `leftlower`, `rightlower` | 下部の左右パディング |
| `middle` | 分割線の上下スペース |
| `boxsep` | 全パディングに加算される共通値 |
| `size=normal/small/fbox/tight/minimal` | プリセットサイズ |

### 罫線

| キー | 説明 |
|-----|------|
| `leftrule`, `rightrule`, `toprule`, `bottomrule` | 各辺の罫線幅 |
| `titlerule` | タイトル下の罫線幅 |
| `boxrule` | 全罫線幅（一括設定） |

### テキスト配置

| キー | 値 | 説明 |
|-----|-----|------|
| `halign` | `justify`/`left`/`right`/`center` | テキスト配置（ハイフネーション有効） |
| `halign_title`, `halign_lower` | 同上 | タイトル・下部の配置 |
| `valign`, `valign_lower` | `top`/`center`/`bottom`/`scale` | 垂直配置 |
| `parbox` | true/false | `\parbox`形式（false = 通常段落） |

### 色とフォント

| キー | 説明 |
|-----|------|
| `colback`, `colbacktitle`, `colbackupper`, `colbacklower` | 背景色 |
| `colframe` | 枠線色 |
| `coltext`, `colupper`, `collower`, `coltitle` | テキスト色 |
| `fonttitle`, `fontupper`, `fontlower` | フォント設定 |

### 角の形状

```latex
% 全角を鋭角に
\begin{tcolorbox}[sharp corners]
  内容
\end{tcolorbox}

% 一部の角を鋭角に
\begin{tcolorbox}[sharp corners=northwest]
  内容
\end{tcolorbox}

% 方向指定: north/east/south/west/downhill/uphill/northwest/...
```

### スキンライブラリ

```latex
\tcbuselibrary{skins}

% 利用可能なスキン
enhanced      % tikz描画、高度なカスタマイズ可能
bicolor       % 上下で異なる背景色
beamer        % Beamerスタイル（影付き）
tile          % 矩形、異なる背景色
spartan       % 上下同一背景
empty         % 背景・枠なし（注意: タイトル色調整必要）
widget        % グラデーション背景
```

**例**:
```latex
\begin{tcolorbox}[beamer, title=タイトル]
  内容 \tcblower 下部
\end{tcolorbox}
```

### ページ分割

```latex
\tcbuselibrary{breakable}

\begin{tcolorbox}[breakable, beamer]
  長い内容...
\end{tcolorbox}

% 個別に分割禁止
\begin{tcolorbox}[unbreakable]
  内容
\end{tcolorbox}
```

### 影とボーダーライン

```latex
\tcbuselibrary{skins}

% 影
\begin{tcolorbox}[enhanced, drop shadow]  % 右下
\begin{tcolorbox}[enhanced, drop fuzzy shadow]  % ぼかし影
\begin{tcolorbox}[enhanced, drop lifted shadow=blue]  % 持ち上げ影

% ボーダーライン
\begin{tcolorbox}[enhanced, frame hidden, interior hidden,
  borderline west={3pt}{0pt}{blue, dotted}]
  内容
\end{tcolorbox}
```

### 透かし・背景

```latex
\tcbuselibrary{skins}

\begin{tcolorbox}[enhanced,
  watermark graphics=logo.pdf,
  watermark opacity=0.2,
  watermark zoom=0.9]  % または watermark stretch / watermark overzoom
  内容
\end{tcolorbox}

\begin{tcolorbox}[enhanced,
  watermark text=DRAFT,
  watermark color=red,
  watermark opacity=0.1]
  内容
\end{tcolorbox}
```

### カスタム環境定義

```latex
\newtcolorbox[auto counter]{exabox}[2][]{
  colback=blue!5,
  colframe=blue!75!black,
  title=Example~\thetcbcounter: #2,
  #1
}

\begin{exabox}{タイトル}
  内容
\end{exabox}

\begin{exabox}[sharp corners]{タイトル}
  内容
\end{exabox}
```

---

## 6. TikZ 基礎

汎用グラフィックスシステム（1300ページ超のマニュアル）。

### 基本構文

```latex
\usepackage{tikz}
\usetikzlibrary{library1, library2, ...}

\begin{tikzpicture}[key/value list]
  % グラフィック命令（各命令は;で終了）
\end{tikzpicture}

\tikz[key/value list]{グラフィック命令}  % 短縮形
```

### 座標系

| 座標系 | 明示的構文 | 暗黙的構文 |
|--------|----------|----------|
| キャンバス座標 | `(canvas cs: x=1cm, y=2pt)` | `(1cm, 2pt)` |
| キャンバス極座標 | `(canvas polar cs: angle=30, radius=2cm)` | `(30:2cm)` |
| xyz座標 | `(xyz cs: x=1, y=0.5)` | `(1, 0.5)` |
| xyz極座標 | `(xyz polar cs: angle=30, radius=2)` | `(30:2)` |
| ノード参照 | `(node cs: name=A, anchor=south)` | `(A.south)` |

**単位**:
- 寸法単位（`cm`, `pt`等）指定時: キャンバス座標
- 無単位数値: xyz座標（単位ベクトルの倍数、デフォルト1cm）

**式の使用**:
```latex
% 数式評価可能
\draw (0, 0) -- ({sqrt(2)/2}, {sqrt(2)/2});

% ランダム値
\draw (rand, rand) -- (rand, rand) -- cycle;

% テキスト測定（注意: \edefで展開、フォント切替不可）
\draw (0, -{depth("y")+0pt}) -- (0, {height("T")+0pt});
```

### 相対座標

```latex
% +(x, y): 現在位置からの相対座標（現在位置は変わらない）
\draw (0, 0) -- (1, 1) -- +(0, 0.5) -- +(0.5, 0);

% ++(x, y): 相対座標かつ現在位置を更新
\draw (0, 0) -- (1, 1) -- ++(0, 0.5) -- ++(0.5, 0);
```

### 名前付き座標

```latex
\coordinate (A) at (0, 0);
\coordinate (B) at (30:3);
\coordinate (C) at ([shift={(1, -1)}]B);

\draw (A) -- (B) -- (C) -- cycle;
```

**calc ライブラリ**（座標演算）:
```latex
\usetikzlibrary{calc}

% 中間点
\draw ($(A)!0.5!(C)$);

% 射影
\draw ($(A)!(C)!(B)$);
```

### パス操作

| 操作 | 構文 | 説明 |
|------|------|------|
| move-to | `(x, y)` | 現在位置を移動 |
| line-to | `-- (x, y)` | 直線 |
|  | `-| (x, y)` | 水平→垂直 |
|  | `|- (x, y)` | 垂直→水平 |
| curve-to | `.. controls (c1) and (c2) .. (x, y)` | ベジエ曲線 |
| arc | `arc[radius=r, start angle=a1, end angle=a2]` | 円弧 |
| sin/cos | `sin (x, y)` / `cos (x, y)` | 正弦・余弦曲線 |
| rectangle | `rectangle (x, y)` | 矩形 |
| circle | `circle[radius=r]` | 円 |
| ellipse | `ellipse[x radius=rx, y radius=ry]` | 楕円 |
| grid | `grid[step=s] (x, y)` | グリッド |
| cycle | `cycle` | パスを閉じる |

**例**:
```latex
\draw (0, 0) -- (1, 1) -- (2, 0) -- cycle;

\draw (0, 0) arc[radius=1cm, start angle=180, end angle=70];

\draw (0, 0) sin (1, 1) cos (2, 0) sin (3, -1) cos (4, 0);
```

### パスアクション

| アクション | 構文 | 短縮コマンド |
|-----------|------|------------|
| draw | `\path[draw, ...]` | `\draw[...]` |
| fill | `\path[fill, ...]` | `\fill[...]` |
| draw+fill | `\path[draw, fill, ...]` | `\filldraw[...]` |
| pattern | `\path[pattern, ...]` | `\pattern[...]` |
| shade | `\path[shade, ...]` | `\shade[...]` |
| clip | `\path[clip]` | `\clip` |

**例**:
```latex
\usepackage{tikz}
\usetikzlibrary{patterns}

\draw (0, 0) -- (1, 1) -- (2, 0);
\fill[blue] (0, 0) rectangle (1, 1);
\filldraw[fill=red, draw=black] (0, 0) circle[radius=5mm];
\pattern[pattern=fivepointed stars] (0, 0) rectangle (2, 1);
```

### 線のスタイル

| キー | 説明 |
|-----|------|
| `line width=<dim>` | 線幅 |
| `thick`, `thin`, `very thick`, ... | 線幅プリセット |
| `line cap=round/rect/butt` | 線端の形状 |
| `line join=round/bevel/miter` | 線の接合部形状 |
| `dash pattern=on <a> off <b> ...` | 破線パターン |
| `dashed`, `dotted`, `dashdotted` | 破線プリセット |
| `double`, `double distance=<dim>` | 二重線 |
| `color=<color>`, `draw=<color>` | 色 |

### 矢印

```latex
\usetikzlibrary{arrows.meta}

\draw[->] (0, 0) -- (1, 1);
\draw[<-] (0, 0) -- (1, 1);
\draw[<->] (0, 0) -- (1, 1);
\draw[-{Latex[length=10pt]}] (0, 0) -- (1, 1);
\draw[{Bracket[sep] Bracket[]}-] (0, 0) -- (1, 1);
```

### ノード

```latex
\node[key/value list] (name) at (coordinate) {text};

% パス上のノード
\draw (0, 0) node[above]{A} -- (1, 1) node[below]{B};
```

**主要キー**:
- `anchor=<anchor>`: 基準点（`north`, `south east`, `base`, ...）
- `text=<color>`: テキスト色
- `font=<font commands>`: フォント
- `draw`, `fill`, `double`: 境界・塗りつぶし
- `circle`, `rectangle`: 形状
- `behind path`: パスの背後に描画

**特殊形状**（ライブラリ必要）:
```latex
\usetikzlibrary{shapes, shapes.arrows, shapes.symbols}

\node[shape=single arrow, fill=blue] {right};
\node[shape=star, draw] {Star};
\node[shape=cloud, draw] {Cloud};
```

### 変換

```latex
% 全体変換（tikzpicture環境オプション）
\begin{tikzpicture}[scale=2, rotate=30, xshift=1cm, yshift=2cm]

% xyz単位ベクトル変更
\begin{tikzpicture}[x={(1cm, 0.5cm)}, y={(0cm, 1cm)}]

% 個別変換（パス・ノード単位）
\draw[rotate=45, scale=0.5] (0, 0) rectangle (1, 1);
```

**主要変換キー**:
- `scale=<factor>`, `xscale=<f>`, `yscale=<f>`
- `rotate=<angle>`
- `xshift=<dim>`, `yshift=<dim>`, `shift={(<x>, <y>)}`
- `xslant=<factor>`, `yslant=<factor>`

### スタイル定義

```latex
\tikzset{
  myarrow/.style={->, thick, blue},
  mynode/.style={circle, draw, fill=gray!20}
}

\draw[myarrow] (0, 0) -- (1, 1);
\node[mynode] at (0, 0) {A};
```

### よく使うライブラリ

| ライブラリ | 機能 |
|----------|------|
| `calc` | 座標演算 |
| `arrows.meta` | 高度な矢印スタイル |
| `shapes`, `shapes.geometric`, `shapes.symbols` | 特殊形状 |
| `patterns` | パターン塗りつぶし |
| `positioning` | 相対位置指定（`above=of`, `right=of`等） |
| `backgrounds` | 背景レイヤー |
| `decorations.*` | パス装飾 |
| `matrix` | 行列レイアウト |
| `chains` | 連鎖配置 |

---

## 7. QRコード生成（qrcode パッケージ）

```latex
\usepackage{qrcode}

\qrcode{https://example.com}
\qrcode[height=3cm]{https://example.com}
```

---

## ベストプラクティス

### 画像読み込み

1. **graphicxを使用**（graphicsより機能豊富）
2. **拡張子を省略**（複数フォーマット対応）
   ```latex
   \includegraphics{figure}  % figure.pdf, figure.png を自動検索
   ```
3. **画像ディレクトリを設定**
   ```latex
   \graphicspath{{./images/}}
   ```
4. **キーの順序に注意**（graphicx）
   - 回転→拡大縮小 と 拡大縮小→回転 は結果が異なる

### ボックス操作

1. **adjustbox を活用**
   - 統一されたkey/value インターフェース
   - 複数回適用可能なTrim/Clip
   - 相対寸法コマンド（`\width`, `\totalheight`等）

2. **tcolorbox で複雑なレイアウト**
   - ページ分割可能なボックス
   - スキンで一貫したデザイン
   - カスタム環境定義で再利用性向上

### TikZ

1. **ライブラリを活用**（不要なものは読み込まない）
2. **スタイル定義で可読性向上**
   ```latex
   \tikzset{every picture/.style={line width=1pt}}
   ```
3. **セミコロン忘れに注意**
4. **複雑な計算は事前に実施**（\edef展開の制限回避）
5. **名前付き座標で保守性向上**
