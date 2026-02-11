# 画像操作

LaTeX文書における画像の高度な操作・加工テクニック集。

## 必須パッケージ

```latex
\usepackage{graphicx}      % 基本的な画像挿入
\usepackage{adjustbox}     % 高度な画像調整・フレーム
\usepackage{tikz}          % 画像のクリッピング・描画
\usepackage{onimage}       % 画像上への描画
\usepackage{collcell}      % グリッド配置
\usepackage{stackengine}   % 画像の積み重ね
```

---

## 画像品質の最適化

### ベクター形式 vs ビットマップ形式

**ベクター形式（推奨）**：
- PDF、PS、SVG（要PDF変換）
- 拡大しても劣化しない
- 図表・ダイアグラムに最適

**ビットマップ形式**：
- PNG（可逆圧縮、透明度対応）
- JPG（非可逆圧縮、写真向け）
- 解像度に依存（最低300 DPI推奨）

### pdfLaTeXでの対応形式

```latex
% pdfLaTeX が直接対応
\includegraphics{diagram.pdf}
\includegraphics{photo.png}
\includegraphics{photo.jpg}

% EPS は変換が必要
% epstopdf パッケージで自動変換
\usepackage{epstopdf}
\includegraphics{legacy.eps}  % 自動的に .pdf に変換
```

---

## 画像のカスタマイズ

### 基本的な変形（graphicx）

```latex
% 幅指定
\includegraphics[width=0.5\textwidth]{image.png}

% 高さ指定
\includegraphics[height=4cm]{image.png}

% 拡大率指定
\includegraphics[scale=0.8]{image.png}

% 回転
\includegraphics[angle=90]{image.png}

% トリミング（左下から時計回りに left, bottom, right, top）
\includegraphics[trim=10mm 5mm 10mm 5mm, clip]{image.png}
```

### adjustbox による高度な調整

```latex
\usepackage{adjustbox}

% 複数オプションの組み合わせ
\includegraphics[width=5cm, trim=0 0 5cm 0, clip, angle=90]{image.png}

% adjustbox 環境での適用
\begin{adjustbox}{width=\textwidth, center}
  \includegraphics{wide-image.png}
\end{adjustbox}

% max size（縦横のいずれかが収まるまで縮小）
\includegraphics[max width=\textwidth, max height=8cm]{image.png}
```

---

## 画像フレームの追加

### adjustbox の cframe オプション

```latex
\usepackage{adjustbox}

% 単純なフレーム
\includegraphics[width=5cm, cframe=black 1pt]{image.png}

% カラーフレーム（colorパッケージが必要）
\usepackage{xcolor}
\includegraphics[width=5cm, cframe=blue 2pt]{image.png}

% 角丸フレーム（roundedcorners は adjustbox v1.2 以降）
\includegraphics[width=5cm, cframe=black 1pt 3pt]{image.png}
```

### tcolorbox による装飾フレーム

```latex
\usepackage{tcolorbox}

\begin{tcolorbox}[colback=white, colframe=blue!50!black,
                  width=0.5\textwidth, arc=3mm]
  \includegraphics[width=\linewidth]{image.png}
\end{tcolorbox}
```

---

## 角丸クリッピング（TikZ）

```latex
\usepackage{tikz}

\begin{tikzpicture}
  \node[rounded corners=10pt, inner sep=0pt] {
    \includegraphics[width=5cm]{image.png}
  };
\end{tikzpicture}

% または path picture を使用
\begin{tikzpicture}
  \draw[rounded corners=15pt, path picture={
    \node at (path picture bounding box.center) {
      \includegraphics[width=5cm]{image.png}
    };
  }] (0,0) rectangle (5,4);
\end{tikzpicture}
```

---

## 円形クリッピング

```latex
\usepackage{tikz}

\begin{tikzpicture}
  \clip (0,0) circle (2cm);
  \node at (0,0) {\includegraphics[width=4cm]{portrait.jpg}};
\end{tikzpicture}

% 境界線付き
\begin{tikzpicture}
  \begin{scope}
    \clip (0,0) circle (2cm);
    \node at (0,0) {\includegraphics[width=4cm]{portrait.jpg}};
  \end{scope}
  \draw[line width=2pt, blue] (0,0) circle (2cm);
\end{tikzpicture}
```

---

## 画像上への描画

### onimage パッケージ

```latex
\usepackage{onimage}

\begin{tikzonimage}[width=0.8\textwidth]{photo.jpg}
  % 座標は画像の左下が (0,0)、右上が (1,1)
  \draw[->, red, line width=2pt] (0.2,0.3) -- (0.7,0.8);
  \node[fill=white, opacity=0.8] at (0.5,0.5) {注目点};
\end{tikzonimage}
```

### TikZ overlay（直接描画）

```latex
\begin{tikzpicture}
  \node[anchor=south west, inner sep=0] (image) at (0,0) {
    \includegraphics[width=0.8\textwidth]{diagram.png}
  };
  \begin{scope}[x={(image.south east)}, y={(image.north west)}]
    \draw[red, ultra thick, rounded corners]
          (0.3,0.4) rectangle (0.7,0.8);
    \node[fill=yellow, opacity=0.7] at (0.5,0.2) {重要部分};
  \end{scope}
\end{tikzpicture}
```

---

## 画像の位置揃え

### 垂直方向の揃え

```latex
% ベースライン揃え（\raisebox）
テキスト
\raisebox{-0.5\height}{\includegraphics[width=1cm]{icon.png}}
と画像を揃える

% 上揃え
\raisebox{-\height}{\includegraphics[width=1cm]{icon.png}}

% 中央揃え
\raisebox{-0.5\height}{\includegraphics[width=1cm]{icon.png}}

% adjustbox による指定
\includegraphics[width=1cm, valign=c]{icon.png}
```

### 水平方向の揃え

```latex
% 中央揃え
\begin{center}
  \includegraphics[width=0.5\textwidth]{image.png}
\end{center}

% 左寄せ
\noindent
\includegraphics[width=0.5\textwidth]{image.png}

% 右寄せ
\begin{flushright}
  \includegraphics[width=0.5\textwidth]{image.png}
\end{flushright}
```

---

## グリッド配置

### collcell パッケージによる自動調整

```latex
\usepackage{collcell}
\usepackage{array}

% カスタムカラム型定義
\newcolumntype{I}{>{\collectcell\includegraphics[width=3cm]}c<{\endcollectcell}}

\begin{tabular}{III}
  image1.png & image2.png & image3.png \\
  image4.png & image5.png & image6.png \\
\end{tabular}
```

### 手動配置

```latex
\begin{tabular}{@{}c@{\hspace{5mm}}c@{\hspace{5mm}}c@{}}
  \includegraphics[width=3cm]{img1.png} &
  \includegraphics[width=3cm]{img2.png} &
  \includegraphics[width=3cm]{img3.png} \\[5mm]
  \includegraphics[width=3cm]{img4.png} &
  \includegraphics[width=3cm]{img5.png} &
  \includegraphics[width=3cm]{img6.png}
\end{tabular}
```

---

## 画像の積み重ね

### stackengine パッケージ

```latex
\usepackage{stackengine}

% 垂直方向の積み重ね
\stackinset{c}{}{c}{}{\includegraphics[width=3cm]{base.png}}{%
  \includegraphics[width=1cm]{overlay.png}%
}

% 位置指定（左上に配置）
\stackinset{l}{5mm}{t}{5mm}{%
  \includegraphics[width=1cm]{logo.png}%
}{%
  \includegraphics[width=8cm]{background.png}%
}

% 複数レイヤー
\stackinset{c}{}{c}{}{%
  \includegraphics[width=1cm]{icon.png}%
}{%
  \stackinset{l}{5mm}{b}{5mm}{%
    \includegraphics[width=0.5cm]{badge.png}%
  }{%
    \includegraphics[width=8cm]{photo.png}%
  }%
}
```

---

## 実践例：カード型レイアウト

```latex
\usepackage{tcolorbox}
\usepackage{adjustbox}
\usepackage{tikz}

\begin{tcolorbox}[
  colback=white,
  colframe=gray!30,
  width=0.3\textwidth,
  arc=5mm,
  boxrule=0.5pt
]
  % 角丸画像
  \begin{tikzpicture}
    \clip[rounded corners=5mm] (0,0) rectangle (4,3);
    \node[anchor=south west, inner sep=0] at (0,0) {
      \includegraphics[width=4cm, height=3cm]{product.jpg}
    };
  \end{tikzpicture}

  \vspace{5mm}
  \textbf{製品名}

  製品の説明文がここに入ります。
\end{tcolorbox}
```

---

## パフォーマンス最適化

### 画像の外部化（draft モード）

```latex
% プリアンブルで draft オプション
\usepackage[draft]{graphicx}

% 画像がプレースホルダーに置き換わる（コンパイル高速化）
```

### 画像のキャッシュ

```latex
% サブファイル内で画像を何度も使う場合
\newsavebox{\myimage}
\savebox{\myimage}{\includegraphics[width=3cm]{heavy.png}}

% 使用時
\usebox{\myimage}
```

---

## トラブルシューティング

### 画像が表示されない

- ファイルパスを確認（相対パス推奨）
- 対応形式を確認（pdfLaTeX: PDF/PNG/JPG のみ）
- `\graphicspath{{images/}}` でディレクトリ指定

### 画像が大きすぎる

```latex
% 自動縮小
\includegraphics[max width=\textwidth, max height=0.9\textheight]{large.png}
```

### 画像の位置がずれる

```latex
% figure 環境で [H] オプション（float パッケージ）
\usepackage{float}
\begin{figure}[H]
  \centering
  \includegraphics[width=0.5\textwidth]{image.png}
  \caption{キャプション}
\end{figure}
```
