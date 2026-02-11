# 参考文献管理・引用システム

LaTeXの参考文献データベース（BibTeX/biber）と、引用システム（natbib/biblatex）の高度な活用法。

---

## 参考文献システムの概要

### `thebibliography` 環境の限界

最も基本的な方法だが、大規模文書には不向き：

```latex
\begin{thebibliography}{99}
\bibitem{knuth1984}
Donald E. Knuth.
\textit{The TeXbook}.
Addison-Wesley, 1984.

\bibitem{lamport1994}
Leslie Lamport.
\textit{LaTeX: A Document Preparation System}.
Addison-Wesley, 1994.
\end{thebibliography}

% 引用
\cite{knuth1984}
```

**問題点：**
- スタイル変更が困難
- 複数文書で再利用不可
- ソート・フォーマットを手動管理
- 引用スタイルの統一が手間

**解決策：** BibTeX/biber + データベースファイル（`.bib`）を使用

---

## BibTeX vs biber

| 項目 | BibTeX | biber |
|------|--------|-------|
| **Unicode対応** | 限定的（8bit拡張あり） | 完全対応 |
| **処理速度** | 高速 | やや遅い |
| **機能** | 基本的 | 高度（フィルタリング、ソート） |
| **biblatex対応** | 制限あり | 推奨バックエンド |
| **データモデル** | 固定 | 拡張可能 |
| **推奨用途** | 伝統的なスタイル | 現代的な引用管理 |

### bibtex8 — 8bit拡張版

Unicode非対応だが、Latin-1等の8bitエンコーディングに対応：

```bash
bibtex8 --csfile csfile.csf document.aux
```

---

## .bib データベースフォーマット

### 基本構造

```bibtex
@entrytype{citekey,
  field1 = {value1},
  field2 = {value2},
  field3 = value3
}
```

### 主要エントリタイプ

| エントリタイプ | 用途 | 必須フィールド |
|--------------|------|---------------|
| `@article` | 学術論文 | author, title, journal, year |
| `@book` | 書籍 | author/editor, title, publisher, year |
| `@inproceedings` | 会議論文集の論文 | author, title, booktitle, year |
| `@incollection` | 書籍中の章 | author, title, booktitle, publisher, year |
| `@phdthesis` | 博士論文 | author, title, school, year |
| `@mastersthesis` | 修士論文 | author, title, school, year |
| `@techreport` | 技術レポート | author, title, institution, year |
| `@manual` | マニュアル | title |
| `@misc` | その他 | なし（title推奨） |
| `@online` | Webリソース（biblatex） | author/editor, title, year/date, url |
| `@unpublished` | 未出版 | author, title, note |

### フィールドの種類

#### 名前フィールド（author, editor等）

```bibtex
author = {John Smith},                    % 1人
author = {John Smith and Jane Doe},       % 複数人（"and" で区切る）
author = {Smith, John and Doe, Jane},     % 姓, 名 形式
author = {Smith, Jr., John},              % Jr. 等の接尾辞
author = {{The LaTeX Project Team}},      % 団体名（二重ブレース）
```

#### タイトルフィールド

```bibtex
title = {The Art of Computer Programming},
title = {{LaTeX} in 24 Hours},             % "LaTeX" を保護
title = {An Introduction to $\alpha$-Calculus},  % 数式
```

#### 日付フィールド

```bibtex
year = {2024},
month = jan,                               % 月名（小文字、引用符なし）
date = {2024-01-15},                       % ISO 8601形式（biblatex）
```

#### その他のフィールド

```bibtex
journal = {Journal of Computer Science},
volume = {42},
number = {3},
pages = {123--145},                        % en-dash（--）
publisher = {Addison-Wesley},
address = {Reading, Massachusetts},
doi = {10.1234/example.doi},
url = {https://example.com},
note = {Accessed: 2024-01-15},
```

### テキストフィールドの書き方

#### 大文字の保護

BibTeXはタイトルを自動的に小文字化する場合がある。保護するには二重ブレース：

```bibtex
title = {Introduction to {LaTeX}},         % "LaTeX" は大文字のまま
title = {{NASA} Report},                   % "NASA" を保護
title = {The {M}oon and the {S}un},        % 文中の大文字を保護
```

#### 特殊文字

```bibtex
author = {M{\"u}ller, Hans},               % ü
author = {M{\"{u}}ller, Hans},             % 別の書き方
title = {Caf\'{e} Culture},                % é
title = {Na\"{\i}ve Approach},             % ï
```

Unicode対応の場合（biber + biblatex）：

```bibtex
author = {Müller, Hans},                   % 直接Unicode
title = {Café Culture},
```

### 相互参照（crossref）

複数のエントリで共通情報を共有：

```bibtex
@inproceedings{smith2024,
  author = {Smith, John},
  title = {A New Algorithm},
  crossref = {icml2024}
}

@proceedings{icml2024,
  title = {Proceedings of ICML 2024},
  year = {2024},
  publisher = {PMLR},
  booktitle = {Proceedings of ICML 2024}
}
```

### 略語（@string）

```bibtex
@string{jcp = "Journal of Computational Physics"}
@string{aw = "Addison-Wesley"}

@article{example,
  author = {Doe, John},
  title = {Example},
  journal = jcp,
  publisher = aw,
  year = {2024}
}
```

### xdata エントリタイプ（biber専用）

データの継承：

```bibtex
@xdata{commondata,
  publisher = {Springer},
  address = {Berlin}
}

@book{book1,
  author = {Smith, John},
  title = {Book One},
  xdata = {commondata},
  year = {2023}
}

@book{book2,
  author = {Doe, Jane},
  title = {Book Two},
  xdata = {commondata},
  year = {2024}
}
```

---

## 引用システムの分類

### 1. 番号方式（Number-only system）

引用を番号で表示：

```latex
% 出力例: [1], [2,3]
Text [1] and more text [2,3].
```

| パッケージ | 特徴 |
|----------|------|
| 標準LaTeX | 基本的な番号引用 |
| `cite` | 番号の圧縮・ソート |
| `natbib` | 番号方式にも対応 |
| `biblatex` | 高度な番号方式 |

**推奨用途：** 理工系論文（特に物理、工学）

---

### 2. 著者-年方式（Author-year system）

著者名と出版年で引用：

```latex
% 出力例: (Smith, 2024), Smith (2024)
According to Smith (2024), ...
This is well-known (Smith, 2024; Doe, 2023).
```

| パッケージ | 特徴 |
|----------|------|
| `natbib` | 柔軟な著者-年引用 |
| `biblatex` | 高度な著者-年引用 |

**推奨用途：** 社会科学、生物学、心理学

---

### 3. 著者-番号方式（Author-number system）

著者名と番号を組み合わせ：

```latex
% 出力例: Smith [1], Doe [2]
According to Smith [1], ...
```

| パッケージ | 特徴 |
|----------|------|
| `natbib` | 対応 |
| `biblatex` | 対応 |

**推奨用途：** 一部の理工系分野

---

### 4. 著者-タイトル方式（Author-title system）

著者名と短縮タイトルで引用（主に人文科学）：

```latex
% 出力例: Smith, "Introduction", pp. 12-13
See Smith, "Introduction", pp. 12-13.
```

| パッケージ | 特徴 |
|----------|------|
| `jurabib` | ドイツ法学向け |
| `biblatex` | 柔軟な著者-タイトル引用 |

**推奨用途：** 法学、人文科学（特にドイツ語圏）

---

### 5. 冗長方式（Verbose system）

本文中に完全な書誌情報を表示：

```latex
% 出力例: John Smith, The Art of LaTeX, Addison-Wesley, 2024, pp. 12-13.
```

| パッケージ | 特徴 |
|----------|------|
| `bibentry` | 本文中に完全なエントリ |
| `biblatex` | verbose スタイル |

**推奨用途：** 特殊な学術分野、法律文書

---

## natbib パッケージ

著者-年方式と番号方式の両方に対応。

### 基本設定

```latex
\usepackage{natbib}
\bibliographystyle{plainnat}  % 番号方式
% \bibliographystyle{abbrvnat}  % 略語付き番号方式
% \bibliographystyle{unsrtnat}  % 引用順番号方式

\begin{document}
\cite{key}          % (著者, 年) or [番号]
\citep{key}         % (著者, 年)
\citet{key}         % 著者 (年)
\citeauthor{key}    % 著者のみ
\citeyear{key}      % 年のみ

\bibliography{database}
\end{document}
```

### 主要コマンド

| コマンド | 出力例（著者-年） | 出力例（番号） |
|---------|-----------------|--------------|
| `\cite{key}` | (Smith, 2024) | [1] |
| `\citep{key}` | (Smith, 2024) | [1] |
| `\citet{key}` | Smith (2024) | Smith [1] |
| `\citealt{key}` | Smith, 2024 | Smith 1 |
| `\citealp{key}` | Smith, 2024 | 1 |
| `\citeauthor{key}` | Smith | Smith |
| `\citeyear{key}` | 2024 | 2024 |

### カスタマイズオプション

```latex
\usepackage[
  round,          % (著者, 年) ← 丸括弧
  % square,       % [著者, 年] ← 角括弧
  % curly,        % {著者, 年} ← 波括弧
  % angle,        % <著者, 年> ← 山括弧
  comma,          % (著者, 年) ← カンマ区切り
  % semicolon,    % (著者; 年) ← セミコロン区切り
  authoryear,     % 著者-年方式
  % numbers,      % 番号方式
  % super,        % 上付き番号
  sort,           % 複数引用をソート
  compress        % [1,2,3] → [1-3]
]{natbib}
```

---

## biblatex パッケージ

最も強力で柔軟な引用管理システム。biber を推奨バックエンドとする。

### 基本設定

```latex
\usepackage[backend=biber, style=authoryear]{biblatex}
\addbibresource{database.bib}  % .bib ファイルを登録

\begin{document}
\cite{key}
\parencite{key}
\textcite{key}

\printbibliography
\end{document}
```

#### コンパイル手順

```bash
pdflatex document.tex    # 1回目
biber document           # biber実行（.bcf → .bbl生成）
pdflatex document.tex    # 2回目
pdflatex document.tex    # 3回目（相互参照の解決）
```

### 主要引用コマンド

| コマンド | 出力例（authoryear） | 出力例（numeric） |
|---------|---------------------|------------------|
| `\cite{key}` | Smith 2024 | [1] |
| `\parencite{key}` | (Smith 2024) | [1] |
| `\textcite{key}` | Smith (2024) | Smith [1] |
| `\autocite{key}` | (Smith 2024) | [1] |
| `\footcite{key}` | 脚注に引用 | 脚注に引用 |
| `\citeauthor{key}` | Smith | Smith |
| `\citetitle{key}` | タイトル | タイトル |
| `\citeyear{key}` | 2024 | 2024 |

### 主要スタイル

| スタイル | 説明 | 用途 |
|---------|------|------|
| `numeric` | 番号方式 | 理工系 |
| `numeric-comp` | 番号方式（圧縮） | 理工系 |
| `alphabetic` | アルファベット方式（[Smi24]） | 一部理工系 |
| `authoryear` | 著者-年方式 | 社会科学 |
| `authoryear-comp` | 著者-年方式（圧縮） | 社会科学 |
| `authortitle` | 著者-タイトル方式 | 人文科学 |
| `verbose` | 冗長方式 | 法学 |
| `apa` | APA 第7版 | 心理学 |
| `ieee` | IEEE スタイル | 工学 |
| `chicago` | Chicago Manual of Style | 人文・社会科学 |
| `mla` | MLA スタイル | 文学 |

### パッケージオプション

```latex
\usepackage[
  backend=biber,        % biber（推奨）or bibtex
  style=authoryear,     % 引用スタイル
  sorting=nyt,          % ソート順（name-year-title）
  maxcitenames=2,       % 引用時の最大著者数
  maxbibnames=99,       % 参考文献リストの最大著者数
  giveninits=true,      % 名前をイニシャルに
  uniquename=init,      % 曖昧さ回避
  uniquelist=true,      % リストの曖昧さ回避
  hyperref=true,        % hyperref連携
  backref=true,         % 逆参照（どこで引用されたか）
  doi=true,             % DOI表示
  isbn=false,           % ISBN非表示
  url=true              % URL表示
]{biblatex}
```

### ソート設定

| ソートキー | 意味 |
|-----------|------|
| `nty` | name, title, year |
| `nyt` | name, year, title |
| `nyvt` | name, year, volume, title |
| `anyt` | alphabetic label, name, year, title |
| `none` | ソートしない（引用順） |

### `\printbibliography` オプション

```latex
% 基本
\printbibliography

% タイトル変更
\printbibliography[title={参考文献}]

% フィルタリング
\printbibliography[type=article, title={学術論文のみ}]
\printbibliography[keyword=primary, title={主要文献}]

% セクション別
\printbibliography[heading=subbibliography, segment=1, title={第1章の参考文献}]
```

---

## 複数参考文献リスト

### `chapterbib` — 章ごとの参考文献

各章に独立した参考文献リスト：

```latex
% main.tex
\usepackage{chapterbib}
\include{chapter1}
\include{chapter2}

% chapter1.tex
\chapter{Chapter 1}
Text \cite{ref1}.
\bibliographystyle{plain}
\bibliography{database}

% chapter2.tex
\chapter{Chapter 2}
Text \cite{ref2}.
\bibliographystyle{plain}
\bibliography{database}
```

### `bibunits` — 任意単位の参考文献

```latex
\usepackage{bibunits}

\begin{document}
\begin{bibunit}
Text \cite{ref1}.
\putbib[database]
\end{bibunit}

\begin{bibunit}
Text \cite{ref2}.
\putbib[database]
\end{bibunit}
\end{document}
```

### `multibib` — 複数独立参考文献

```latex
\usepackage{multibib}
\newcites{books}{Books}
\newcites{articles}{Articles}

\begin{document}
Text \cite{ref1} and \citebooks{book1}.

\bibliographystyle{plain}
\bibliography{database}
\bibliographystylebooks{plain}
\bibliographybooks{database}
\end{document}
```

---

## 実践例

### 基本的な使用例（natbib）

```latex
\documentclass{article}
\usepackage[authoryear, round]{natbib}

\begin{document}
According to \citet{knuth1984}, \TeX\ is powerful.
This is well known \citep{lamport1994, knuth1984}.

\bibliographystyle{plainnat}
\bibliography{mybib}
\end{document}
```

### 基本的な使用例（biblatex）

```latex
\documentclass{article}
\usepackage[backend=biber, style=authoryear]{biblatex}
\addbibresource{mybib.bib}

\begin{document}
According to \textcite{knuth1984}, \TeX\ is powerful.
This is well known \parencite{lamport1994, knuth1984}.

\printbibliography
\end{document}
```

### .bib ファイルの例

```bibtex
@book{knuth1984,
  author = {Knuth, Donald E.},
  title = {The {{\TeX}}book},
  publisher = {Addison-Wesley},
  year = {1984},
  address = {Reading, Massachusetts}
}

@book{lamport1994,
  author = {Lamport, Leslie},
  title = {{{\LaTeX}}: A Document Preparation System},
  publisher = {Addison-Wesley},
  year = {1994},
  edition = {2nd},
  address = {Reading, Massachusetts}
}

@online{latex-project,
  author = {{The LaTeX Project}},
  title = {The {{\LaTeX}} Project},
  year = {2024},
  url = {https://www.latex-project.org/},
  urldate = {2024-01-15}
}
```

---

## まとめ

### 引用システムの選択

| 用途 | 推奨システム |
|------|------------|
| 理工系論文（番号） | biblatex（numeric）または natbib |
| 社会科学（著者-年） | biblatex（authoryear）または natbib |
| 人文科学 | biblatex（authortitle）または jurabib |
| APA準拠 | biblatex-apa |
| IEEE準拠 | biblatex（ieee） |

### biber vs BibTeX

| 条件 | 推奨 |
|------|------|
| Unicode必須 | biber |
| 複雑な引用管理 | biber |
| 伝統的なスタイル | BibTeX |
| 高速処理 | BibTeX |

### ベストプラクティス

1. **.bib ファイルを一元管理**（複数文書で共有）
2. **citekey は一貫性を持つ**（例: `author2024keyword`）
3. **特殊文字は二重ブレースで保護**
4. **DOI/URLを含める**（オンラインリソース）
5. **biber使用時は `\addbibresource` に拡張子（`.bib`）を含める**
