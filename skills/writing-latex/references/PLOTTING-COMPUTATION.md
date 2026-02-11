# pgfplots プロット・計算処理ガイド

LaTeXで数学関数のプロット、幾何図形、計算処理を行うための実用ガイド。

---

## 必要パッケージ

```latex
\usepackage{pgfplots}       % 2D/3Dグラフ
\usepackage{tkz-euclide}    % 幾何図形
\usepackage{fp}             % 浮動小数点計算
\usepackage{spreadtab}      % 表計算
```

---

## pgfplots 2D プロット

### 基本構成

```latex
\documentclass[border=10pt]{standalone}
\usepackage{pgfplots}
\pgfplotsset{compat=1.18}  % バージョン指定（推奨）

\begin{document}
\begin{tikzpicture}
  \begin{axis}[
    axis lines = center,  % 中央配置軸
    xlabel = $x$,
    ylabel = $f(x)$
  ]
    \addplot[domain=-3:3, thick, smooth] {x^3 - 5*x};
  \end{axis}
\end{tikzpicture}
\end{document}
```

### 軸スタイルのバリエーション

```latex
% グリッド付き矩形軸
\begin{axis}[
  grid,
  xtick = {-360,-270,...,360},  % 目盛り位置明示
  xlabel = $x$,
  ylabel = $\sin(x)$
]
  \addplot[domain=-360:360, samples=100, thick] {sin(x)};
\end{axis}

% 簡素化軸（shift style）
\usepgfplotslibrary{shift}
\begin{axis}[shift=15pt]  % 軸オフセット
  \addplot[domain=-2:2, red] {x^2};
\end{axis}
```

### 複数プロット重ね合わせ

```latex
\begin{axis}[legend pos=north west]
  \addplot[domain=-2:2, blue, thick] {x^2};
  \addplot[domain=-2:2, red, dashed] {x^3};
  \legend{$x^2$, $x^3$}
\end{axis}
```

### 極座標プロット

```latex
\usepgfplotslibrary{polar}

\begin{polaraxis}[hide axis]
  \addplot[domain=0:360, samples=300] {sin(6*x)};
\end{polaraxis}
```

---

## pgfplots 3D プロット

### サーフェスプロット

```latex
\begin{axis}[
  colorbar,              % カラーバー表示
  view={30}{45},         % 視点角度（azimuth, elevation）
  xlabel=$x$,
  ylabel=$y$,
  zlabel=$z$
]
  \addplot3[
    surf,
    domain=-2:2,
    domain y=-2:2,
    samples=50,
    shader=interp         % 色補間
  ] {x^2 + y^2};
\end{axis}
```

### scatter plot（散布図）

```latex
\addplot3[
  scatter,
  only marks,
  mark=*,
  mark size=1pt,
  point meta=explicit,
  colormap/viridis
] table[x=x, y=y, z=z, meta=value] {data.dat};
```

### 3D軸の簡素化

```latex
\usepgfplotslibrary{shift}
\begin{axis}[shift=10pt, view={30}{30}]
  \addplot3[surf] {sin(deg(sqrt(x^2+y^2)))/sqrt(x^2+y^2)};
\end{axis>
```

---

## 幾何図形（tkz-euclide）

### 基本的な図形

```latex
\usepackage{tkz-euclide}

\begin{tikzpicture}
  % 点定義
  \tkzDefPoint(0,0){A}
  \tkzDefPoint(3,0){B}
  \tkzDefPoint(1.5,2.6){C}

  % 三角形描画
  \tkzDrawPolygon(A,B,C)

  % 点のラベル
  \tkzLabelPoints[below](A,B)
  \tkzLabelPoints[above](C)

  % 円描画
  \tkzDrawCircle[R](A,2cm)
\end{tikzpicture}
```

### 角度・線分の計算

```latex
% 中点計算
\tkzDefMidPoint(A,B) \tkzGetPoint{M}

% 垂線
\tkzDefPointBy[projection=onto A--B](C) \tkzGetPoint{H}

% 角の二等分線
\tkzDefLine[bisector](B,A,C) \tkzGetPoint{D}

% 角度マーク
\tkzMarkAngle[size=0.8cm](B,A,C)
\tkzLabelAngle[pos=1.2](B,A,C){$\alpha$}
```

---

## 浮動小数点計算（fp パッケージ）

```latex
\usepackage{fp}

% 計算実行
\FPeval{\result}{round(sqrt(2):4)}  % √2を小数点以下4桁で
The value is \result.

% 複雑な計算
\FPeval{\result}{round((3.14159 * 5^2):2)}
Area: \result

% 条件分岐
\FPifgt{\result}{10}
  Large value
\else
  Small value
\fi
```

---

## 表計算（spreadtab）

```latex
\usepackage{spreadtab}

\begin{spreadtab}{{tabular}{|c|c|c|}}
  \hline
  @ 項目 & @ 単価 & @ 合計 \\
  \hline
  リンゴ & 100 & b2*3 \\
  バナナ & 150 & b3*2 \\
  \hline
  @ 総計 & & sum(c2:c3) \\
  \hline
\end{spreadtab}
```

### 計算式の記法

- `a1` : セル参照（列a, 行1）
- `sum(a1:a5)` : 合計
- `a1+b1` : 加算
- `a1*b1` : 乗算
- `round(a1:2)` : 四捨五入（小数点以下2桁）

---

## 判断基準テーブル

| 用途 | ツール | 選択基準 |
|------|-------|----------|
| 2D関数プロット | pgfplots axis | 数式による連続曲線 |
| 3Dサーフェス | pgfplots axis (3D) | z=f(x,y)の可視化 |
| 極座標プロット | polaraxis | 角度依存関数 |
| 幾何図形構成 | tkz-euclide | ユークリッド幾何（点・線・円） |
| 数値計算 | fp | ドキュメント内での計算結果埋め込み |
| 表計算 | spreadtab | 表形式データの自動集計 |

---

## 実用例: 組み合わせ使用

### 計算結果のプロット

```latex
\usepackage{pgfplots}
\usepackage{fp}

% 計算
\FPeval{\maxval}{round(2*3.14159:2)}

\begin{tikzpicture}
  \begin{axis}[domain=0:\maxval]
    \addplot[blue] {sin(deg(x))};
  \end{axis}
\end{tikzpicture}
```

### 幾何図形とプロットの重ね合わせ

```latex
\begin{tikzpicture}
  % 幾何図形
  \tkzDefPoint(0,0){O}
  \tkzDrawCircle[R](O,2cm)

  % プロット重ね
  \begin{axis}[
    at={(0,0)},
    anchor=origin,
    axis lines=none
  ]
    \addplot[red, domain=0:360] {sin(x)};
  \end{axis}
\end{tikzpicture}
```

---

## トラブルシューティング

### コンパイル時間が長い場合

```latex
% externalize機能でプロット画像をキャッシュ
\usepgfplotslibrary{external}
\tikzexternalize
```

### 3Dプロットが荒い場合

```latex
% samplesを増やす（コンパイル時間とトレードオフ）
\addplot3[surf, samples=100] {f(x,y)};
```

### メモリ不足エラー

```latex
% LuaLaTeXを使用（メモリ制限が緩い）
% またはサンプル数削減
```

---

## 参考資料

- pgfplots: `texdoc pgfplots` (700ページ超の詳細マニュアル)
- tkz-euclide: `texdoc tkz-euclide`
- fp: `texdoc fp`
- spreadtab: `texdoc spreadtab`
- オンラインギャラリー: https://pgfplots.net
