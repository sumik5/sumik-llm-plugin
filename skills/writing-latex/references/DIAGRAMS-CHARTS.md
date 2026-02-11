# 図表・チャート作成

LaTeX で作成できる各種ダイアグラム、フローチャート、グラフ、チャートのテクニック集。

## 必須パッケージ

```latex
\usepackage{tikz}                % 基本描画エンジン
\usepackage{smartdiagram}        % スマートダイアグラム
\usepackage{pgfplots}            % グラフ・チャート
\usepackage{pgf-pie}             % 円グラフ
\usepackage{forest}              % ツリー図

% TikZ ライブラリ
\usetikzlibrary{shapes, arrows, positioning, matrix, mindmap, calendar, trees, shapes.geometric}
```

---

## スマートダイアグラム（smartdiagram）

### フロー型ダイアグラム

```latex
\usepackage{smartdiagram}

\smartdiagram[flow diagram]{%
  要件定義, 設計, 実装, テスト, デプロイ%
}

% 横方向
\smartdiagram[flow diagram:horizontal]{%
  入力, 処理, 出力%
}
```

### 循環型ダイアグラム

```latex
\smartdiagram[circular diagram]{%
  計画, 実行, 評価, 改善%
}

% カラーカスタマイズ
\smartdiagramset{
  uniform color list=blue!60!black for 4 items,
  circular distance=3cm
}
\smartdiagram[circular diagram]{%
  Plan, Do, Check, Act%
}
```

### バブルダイアグラム

```latex
\smartdiagram[bubble diagram]{%
  中心概念,
  要素1, 要素2, 要素3, 要素4%
}
```

### コンステレーション型

```latex
\smartdiagram[constellation diagram]{%
  メインテーマ,
  サブトピック1, サブトピック2,
  サブトピック3, サブトピック4%
}
```

### 説明型ダイアグラム

```latex
\smartdiagram[descriptive diagram]{%
  {フェーズ1, 初期設定と準備},
  {フェーズ2, データ収集と分析},
  {フェーズ3, レポート作成}%
}
```

### 優先度付き説明型

```latex
\smartdiagram[priority descriptive diagram]{%
  {重要タスク, 最優先で対応が必要な項目},
  {通常タスク, 定常的に進める項目},
  {低優先度, 時間があれば対応する項目}%
}
```

---

## フローチャート（TikZ）

### 基本的なフローチャート

```latex
\usepackage{tikz}
\usetikzlibrary{shapes, arrows, positioning}

\tikzstyle{startstop} = [rectangle, rounded corners, minimum width=3cm,
                         minimum height=1cm, text centered, draw=black, fill=red!30]
\tikzstyle{process} = [rectangle, minimum width=3cm, minimum height=1cm,
                       text centered, draw=black, fill=blue!30]
\tikzstyle{decision} = [diamond, minimum width=3cm, minimum height=1cm,
                        text centered, draw=black, fill=green!30]
\tikzstyle{arrow} = [thick,->,>=stealth]

\begin{tikzpicture}[node distance=2cm]
  \node (start) [startstop] {開始};
  \node (input) [process, below of=start] {データ入力};
  \node (check) [decision, below of=input, yshift=-0.5cm] {条件判定};
  \node (process1) [process, below of=check, yshift=-0.5cm] {処理A};
  \node (process2) [process, right of=check, xshift=3cm] {処理B};
  \node (stop) [startstop, below of=process1] {終了};

  \draw [arrow] (start) -- (input);
  \draw [arrow] (input) -- (check);
  \draw [arrow] (check) -- node[anchor=east] {Yes} (process1);
  \draw [arrow] (check) -- node[anchor=south] {No} (process2);
  \draw [arrow] (process1) -- (stop);
  \draw [arrow] (process2) |- (stop);
\end{tikzpicture}
```

### Matrix を使ったフローチャート

```latex
\usetikzlibrary{matrix}

\begin{tikzpicture}[
  box/.style={rectangle, draw, minimum width=2cm, minimum height=1cm}
]
  \matrix[row sep=1cm, column sep=1cm] {
    \node[box] (a) {ステップ1}; & \\
    \node[box] (b) {ステップ2}; & \node[box] (c) {分岐}; \\
    \node[box] (d) {ステップ3}; & \\
  };
  \draw[->] (a) -- (b);
  \draw[->] (b) -- (c);
  \draw[->] (c) |- (d);
\end{tikzpicture}
```

---

## ツリー図

### TikZ 基本ツリー

```latex
\begin{tikzpicture}[
  level 1/.style={sibling distance=3cm},
  level 2/.style={sibling distance=1.5cm}
]
  \node {ルート}
    child {node {子1}
      child {node {孫1}}
      child {node {孫2}}
    }
    child {node {子2}
      child {node {孫3}}
      child {node {孫4}}
    }
    child {node {子3}};
\end{tikzpicture}
```

### forest パッケージ

```latex
\usepackage{forest}

\begin{forest}
  for tree={
    draw,
    rounded corners,
    minimum width=2cm,
    minimum height=0.8cm,
    align=center,
    l sep=1cm,
    s sep=0.5cm
  }
  [ルートノード
    [枝1
      [葉1]
      [葉2]
    ]
    [枝2
      [葉3]
      [葉4]
      [葉5]
    ]
    [枝3
      [葉6]
    ]
  ]
\end{forest}
```

### ディレクトリツリー

```latex
\begin{forest}
  for tree={
    font=\ttfamily,
    grow'=0,
    child anchor=west,
    parent anchor=south,
    anchor=west,
    calign=first,
    edge path={
      \noexpand\path [draw, \forestoption{edge}]
      (!u.south west) +(7.5pt,0) |- node[fill,inner sep=1.25pt] {} (.child anchor)\forestoption{edge label};
    },
    before typesetting nodes={
      if n=1
        {insert before={[,phantom]}}
        {}
    },
    fit=band,
    before computing xy={l=15pt},
  }
[project/
  [src/
    [main.py]
    [utils.py]
  ]
  [tests/
    [test\_main.py]
  ]
  [README.md]
]
\end{forest}
```

---

## 棒グラフ（pgfplots）

### 縦棒グラフ

```latex
\usepackage{pgfplots}
\pgfplotsset{compat=1.18}

\begin{tikzpicture}
  \begin{axis}[
    ybar,
    ylabel={売上（百万円）},
    symbolic x coords={Q1, Q2, Q3, Q4},
    xtick=data,
    nodes near coords,
    ymin=0
  ]
    \addplot coordinates {(Q1,45) (Q2,52) (Q3,61) (Q4,58)};
  \end{axis}
\end{tikzpicture}
```

### 横棒グラフ

```latex
\begin{tikzpicture}
  \begin{axis}[
    xbar,
    xlabel={回答数},
    symbolic y coords={選択肢A, 選択肢B, 選択肢C, 選択肢D},
    ytick=data,
    nodes near coords,
    xmin=0
  ]
    \addplot coordinates {(15,選択肢A) (28,選択肢B) (12,選択肢C) (45,選択肢D)};
  \end{axis}
\end{tikzpicture}
```

### グループ化棒グラフ

```latex
\begin{tikzpicture}
  \begin{axis}[
    ybar,
    ylabel={スコア},
    symbolic x coords={テストA, テストB, テストC},
    xtick=data,
    legend pos=north west,
    ymin=0
  ]
    \addplot coordinates {(テストA,75) (テストB,82) (テストC,68)};
    \addplot coordinates {(テストA,81) (テストB,78) (テストC,85)};
    \legend{グループ1, グループ2}
  \end{axis}
\end{tikzpicture}
```

### 積み上げ棒グラフ

```latex
\begin{tikzpicture}
  \begin{axis}[
    ybar stacked,
    ylabel={人数},
    symbolic x coords={部署A, 部署B, 部署C},
    xtick=data,
    legend pos=north west
  ]
    \addplot coordinates {(部署A,10) (部署B,15) (部署C,12)};
    \addplot coordinates {(部署A,8) (部署B,11) (部署C,9)};
    \addplot coordinates {(部署A,5) (部署B,7) (部署C,6)};
    \legend{20代, 30代, 40代}
  \end{axis}
\end{tikzpicture}
```

---

## 円グラフ

### pgf-pie パッケージ

```latex
\usepackage{pgf-pie}

\begin{tikzpicture}
  \pie{30/カテゴリA, 25/カテゴリB, 20/カテゴリC, 15/カテゴリD, 10/その他}
\end{tikzpicture}
```

### カスタマイズ

```latex
\begin{tikzpicture}
  \pie[
    radius=3,
    text=legend,
    color={blue!60, red!60, green!60, yellow!60, orange!60}
  ]{30/A, 25/B, 20/C, 15/D, 10/E}
\end{tikzpicture}

% 爆発効果（explode）
\begin{tikzpicture}
  \pie[explode=0.1]{40/項目1, 30/項目2, 20/項目3, 10/項目4}
\end{tikzpicture}

% 回転
\begin{tikzpicture}
  \pie[rotate=45]{50/A, 30/B, 20/C}
\end{tikzpicture}
```

---

## ベン図

```latex
\usepackage{tikz}

\begin{tikzpicture}
  % 円の定義
  \def\circleA{(0,0) circle (1.5cm)}
  \def\circleB{(2,0) circle (1.5cm)}
  \def\circleC{(1,1.5) circle (1.5cm)}

  % 透明度を使った重なり表現
  \begin{scope}[blend group=soft light]
    \fill[red!60] \circleA;
    \fill[blue!60] \circleB;
    \fill[green!60] \circleC;
  \end{scope}

  % ラベル
  \node at (-1,0) {A};
  \node at (3,0) {B};
  \node at (1,2.5) {C};

  % 境界線
  \draw \circleA;
  \draw \circleB;
  \draw \circleC;
\end{tikzpicture}
```

### 2つの円のベン図

```latex
\begin{tikzpicture}
  \begin{scope}[blend group=multiply]
    \fill[red!50] (0,0) circle (1.5);
    \fill[blue!50] (2,0) circle (1.5);
  \end{scope}
  \draw (0,0) circle (1.5) node[left=1cm] {集合A};
  \draw (2,0) circle (1.5) node[right=1cm] {集合B};
\end{tikzpicture}
```

---

## マインドマップ

```latex
\usetikzlibrary{mindmap}

\begin{tikzpicture}[mindmap, grow cyclic, every node/.style=concept,
                    concept color=blue!30]
  \node{中心テーマ}
    child { node {トピック1}
      child { node {詳細1-1} }
      child { node {詳細1-2} }
    }
    child { node {トピック2}
      child { node {詳細2-1} }
      child { node {詳細2-2} }
    }
    child { node {トピック3}
      child { node {詳細3-1} }
    }
    child { node {トピック4} };
\end{tikzpicture}
```

### カラー分けマインドマップ

```latex
\begin{tikzpicture}[
  mindmap,
  every node/.style={concept},
  concept color=orange!40,
  level 1/.append style={sibling angle=90, level distance=4cm}
]
  \node {メインアイデア}
    [clockwise from=0]
    child[concept color=red!40] { node {サブアイデア1} }
    child[concept color=blue!40] { node {サブアイデア2} }
    child[concept color=green!40] { node {サブアイデア3} }
    child[concept color=yellow!40] { node {サブアイデア4} };
\end{tikzpicture}
```

---

## タイムライン

### 水平タイムライン（TikZ）

```latex
\begin{tikzpicture}
  % タイムライン軸
  \draw[thick, ->] (0,0) -- (10,0) node[anchor=north west] {時間};

  % イベント
  \foreach \x/\year in {1/2020, 3/2021, 5/2022, 7/2023, 9/2024} {
    \draw (\x,0.1) -- (\x,-0.1) node[below] {\year};
  }

  % マイルストーン
  \node[circle, fill=red, inner sep=2pt] at (1,0) {};
  \node[above] at (1,0.2) {開始};

  \node[circle, fill=blue, inner sep=2pt] at (5,0) {};
  \node[above] at (5,0.2) {中間};

  \node[circle, fill=green, inner sep=2pt] at (9,0) {};
  \node[above] at (9,0.2) {完了};
\end{tikzpicture}
```

### 垂直タイムライン

```latex
\begin{tikzpicture}
  % 縦軸
  \draw[thick] (0,0) -- (0,10);

  % イベント（左右交互配置）
  \foreach \y/\event in {1/イベント1, 3/イベント2, 5/イベント3, 7/イベント4, 9/イベント5} {
    \pgfmathparse{int(mod(\y,2))}
    \ifnum\pgfmathresult=1
      \draw (0,\y) -- (1,\y) node[right] {\event};
      \node[circle, fill=blue, inner sep=2pt] at (0,\y) {};
    \else
      \draw (0,\y) -- (-1,\y) node[left] {\event};
      \node[circle, fill=red, inner sep=2pt] at (0,\y) {};
    \fi
  }
\end{tikzpicture}
```

### フェーズ別タイムライン

```latex
\usetikzlibrary{calendar}

\begin{tikzpicture}
  % フェーズ1
  \fill[blue!30] (0,0) rectangle (3,1);
  \node at (1.5,0.5) {フェーズ1};

  % フェーズ2
  \fill[green!30] (3,0) rectangle (6,1);
  \node at (4.5,0.5) {フェーズ2};

  % フェーズ3
  \fill[red!30] (6,0) rectangle (10,1);
  \node at (8,0.5) {フェーズ3};

  % 時間軸
  \draw[->] (0,-0.5) -- (10,-0.5) node[right] {時間};
  \foreach \x/\label in {0/開始, 3/3ヶ月, 6/6ヶ月, 10/完了} {
    \draw (\x,-0.4) -- (\x,-0.6) node[below] {\label};
  }
\end{tikzpicture}
```

---

## ガントチャート

```latex
\usepackage{pgfgantt}

\begin{ganttchart}[
  hgrid,
  vgrid,
  time slot format=isodate
]{2024-01-01}{2024-12-31}
  \gantttitlecalendar{year, month} \\
  \ganttbar{タスク1}{2024-01-01}{2024-03-31} \\
  \ganttbar{タスク2}{2024-02-01}{2024-05-31} \\
  \ganttbar{タスク3}{2024-04-01}{2024-08-31} \\
  \ganttbar{タスク4}{2024-07-01}{2024-12-31}
\end{ganttchart}
```

---

## 実践例：組織図

```latex
\begin{tikzpicture}[
  level 1/.style={sibling distance=5cm, level distance=1.5cm},
  level 2/.style={sibling distance=2.5cm},
  every node/.style={
    draw,
    rectangle,
    rounded corners,
    minimum width=3cm,
    minimum height=1cm,
    align=center
  }
]
  \node {CEO}
    child { node {CTO}
      child { node {開発部} }
      child { node {インフラ部} }
    }
    child { node {CFO}
      child { node {経理部} }
      child { node {財務部} }
    }
    child { node {COO}
      child { node {営業部} }
      child { node {CS部} }
    };
\end{tikzpicture}
```

---

## トラブルシューティング

### pgfplots バージョンエラー

```latex
% compat バージョン指定
\pgfplotsset{compat=1.18}
```

### ノードが重なる

```latex
% sibling distance を調整
\begin{tikzpicture}[sibling distance=4cm]
```

### 日本語フォントが乱れる

```latex
% LuaLaTeX または XeLaTeX を使用
% または明示的にフォント指定
\tikzset{every node/.append style={font=\sffamily}}
```
