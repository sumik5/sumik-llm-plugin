# 多言語対応と索引生成

LaTeX文書の多言語対応（babel/polyglossia）と、索引の作成・カスタマイズ（MakeIndex/upmendex/xindy）を扱う。

---

## 多言語対応の基本

### `babel` パッケージ

`babel` はLaTeXで複数言語を扱うための標準パッケージ。

#### 基本設定

```latex
\usepackage[japanese,english]{babel}  % 最後の言語がデフォルト

% 言語切り替え
\selectlanguage{japanese}  % ドキュメント全体の言語変更

\begin{otherlanguage}{english}
  This is in English.
\end{otherlanguage}

% 短いテキストの場合
\foreignlanguage{english}{Short English text}
```

#### 主要コマンド

| コマンド | 用途 |
|---------|------|
| `\selectlanguage{lang}` | 現在の言語を変更 |
| `\foreignlanguage{lang}{text}` | 短いテキストの言語指定 |
| `otherlanguage` 環境 | 長いテキストの言語指定 |
| `\languagename` | 現在の言語名を取得 |

#### ショートハンド（短縮記法）

言語固有の特殊文字入力を簡素化：

```latex
% ドイツ語の例
"a → ä
"s → ß
"- → discretionary hyphen（任意のハイフン位置）

% ショートハンドの無効化/有効化
\shorthandoff{"}
\shorthandon{"}

% 言語全体のショートハンド無効化
\usepackage[english,ngerman]{babel}
\useshorthands*{~}  % 別の文字に割り当て
```

#### 言語属性

言語の特殊な振る舞いを制御：

```latex
\usepackage[german]{babel}
\languageattribute{german}{swiss}  % スイスドイツ語

\usepackage[greek]{babel}
\languageattribute{greek}{ancient}  % 古代ギリシャ語
```

#### BCP 47 タグ（言語識別子）

```latex
\babeltags{en = english, ja = japanese}
\textja{日本語テキスト}
\texten{English text}
```

---

### 言語固有の固定テキスト

章や図の名前を各言語に合わせる：

```latex
% 自動的に言語に応じて変わる
\chaptername  % "Chapter" (英語), "Kapitel" (ドイツ語)
\figurename   % "Figure" (英語), "Abbildung" (ドイツ語)

% カスタマイズ
\addto\captionsenglish{%
  \renewcommand{\chaptername}{Section}%
  \renewcommand{\figurename}{Fig.}%
}
```

---

### キリル文字・ギリシャ文字

#### キリル文字（ロシア語など）

```latex
\usepackage[T2A,T1]{fontenc}  % T2A はキリル文字用
\usepackage[english,russian]{babel}

\begin{document}
\selectlanguage{russian}
Привет, мир!  % "Hello, world!"
\end{document}
```

#### ギリシャ文字

```latex
\usepackage[LGR,T1]{fontenc}  % LGR はギリシャ文字用
\usepackage[english,greek]{babel}

\begin{document}
\selectlanguage{greek}
Γεια σας κόσμε!  % "Hello, world!"
\end{document}
```

---

### `polyglossia` — Unicode エンジン向け

XeLaTeX/LuaLaTeX使用時の多言語サポート。

#### 基本設定

```latex
% XeLaTeX または LuaLaTeX で使用
\usepackage{polyglossia}

\setdefaultlanguage{english}
\setotherlanguage{japanese}
\setotherlanguage{german}

% フォント設定（Unicode エンジンでは必須）
\usepackage{fontspec}
\setmainfont{Noto Serif}
\newfontfamily\japanesefont{Noto Serif CJK JP}
```

#### 言語切り替え

```latex
\textjapanese{日本語}
\textgerman{Deutscher Text}

\begin{japanese}
日本語の段落
\end{japanese}
```

#### babel と polyglossia の選択基準

| 項目 | babel | polyglossia |
|------|-------|-------------|
| 対応エンジン | pdfLaTeX, XeLaTeX, LuaLaTeX | XeLaTeX, LuaLaTeX |
| Unicode対応 | 限定的 | 完全 |
| 複雑な文字体系 | 制限あり | 優れている |
| パッケージ互換性 | 高い | やや低い |
| 推奨用途 | pdfLaTeX, 伝統的な文書 | XeLaTeX/LuaLaTeX, 多言語文書 |

---

## 索引生成

### 索引構文の基本

#### `\index` コマンド

```latex
\usepackage{makeidx}
\makeindex

\begin{document}
% 基本的な索引エントリ
LaTeX\index{LaTeX} is a document preparation system.

% サブエントリ（階層構造）
\index{LaTeX!commands}
\index{LaTeX!environments}

% 表示形式の指定（@ で区切る）
\index{alpha@$\alpha$}      % "α" と表示されるが "alpha" でソート
\index{TeX@\TeX}            % "TeX" と表示されるが "TeX" でソート

% ページ修飾（| で指定）
\index{important|textbf}    % ページ番号を太字に
\index{main entry|textit}   % ページ番号をイタリックに

% 範囲指定
\index{chapter|(}           % 開始
... 複数ページにわたる内容 ...
\index{chapter|)}           % 終了

% 相互参照
\index{LaTeX|see{TeX}}
\index{document class|seealso{packages}}

\printindex
\end{document}
```

#### 構文要素まとめ

| 記号 | 意味 | 例 |
|------|------|-----|
| `!` | サブエントリ | `\index{A!B!C}` → A > B > C |
| `@` | 表示形式とソートキーを分離 | `\index{alpha@$\alpha$}` |
| `\|` | ページ番号修飾 | `\index{term\|textbf}` |
| `\|(` | 範囲開始 | `\index{term\|(}` |
| `\|)` | 範囲終了 | `\index{term\|)}` |
| `\|see{...}` | "see" 相互参照 | `\index{A\|see{B}}` |
| `\|seealso{...}` | "see also" 相互参照 | `\index{A\|seealso{B}}` |

---

### MakeIndex — 標準索引処理

#### 基本使用法

```latex
% プリアンブル
\usepackage{makeidx}
\makeindex

% 本文中
text\index{entry}

% 索引の出力
\printindex
```

#### コンパイル手順

```bash
pdflatex document.tex   # 1回目: .idx ファイル生成
makeindex document.idx  # 索引のソート・整形 → .ind ファイル生成
pdflatex document.tex   # 2回目: .ind を読み込んで索引を出力
```

#### MakeIndex のオプション

```bash
makeindex -s style.ist document.idx   # スタイルファイル指定
makeindex -o output.ind document.idx  # 出力ファイル名指定
makeindex -g document.idx              # ドイツ語ソート
makeindex -l document.idx              # 文字ソート（スペースを無視しない）
```

#### スタイルファイル（.ist）でのカスタマイズ

`.ist` ファイルで索引の見た目をカスタマイズ：

```latex
% mystyle.ist の例
heading_prefix "{\\bfseries "
heading_suffix "\\hfil}\\nopagebreak\n"
headings_flag 1

delim_0 ", "
delim_1 ", "
delim_2 ", "

% 日本語用の設定例
icu_locale "ja_JP"
```

主要な設定項目：

| パラメータ | 説明 | デフォルト |
|-----------|------|-----------|
| `preamble` | 索引の前置き | `"\\begin{theindex}\n"` |
| `postamble` | 索引の後置き | `"\n\n\\end{theindex}\n"` |
| `group_skip` | グループ間のスキップ | `"\n\n  \\indexspace\n"` |
| `heading_prefix` | 見出しの前置き | `""` |
| `heading_suffix` | 見出しの後置き | `""` |
| `headings_flag` | 見出しを表示（1 = yes） | `0` |
| `delim_0` | レベル0の区切り | `", "` |
| `delim_1` | レベル1の区切り | `", "` |
| `delim_2` | レベル2の区切り | `", "` |
| `item_0` | レベル0のエントリ前置き | `"\n  \\item "` |
| `item_1` | レベル1のエントリ前置き | `"\n    \\subitem "` |
| `item_2` | レベル2のエントリ前置き | `"\n      \\subsubitem "` |

---

### upmendex — Unicode 対応索引処理

日本語を含むUnicode文書の索引に対応。

#### 基本使用法

```bash
uplatex document.tex     # 1回目
upmendex document.idx    # Unicode対応のソート
uplatex document.tex     # 2回目
```

#### upmendex の特徴

| 項目 | MakeIndex | upmendex |
|------|-----------|----------|
| Unicode対応 | 非対応 | 完全対応 |
| 日本語ソート | 不可 | 可能 |
| ICU locale | 非対応 | 対応 |
| .ist互換性 | - | 高い |

#### upmendex オプション

```bash
upmendex -s style.ist document.idx   # スタイルファイル
upmendex -d dict.dic document.idx     # 辞書ファイル
upmendex -g document.idx              # ドイツ語ソート
upmendex -L ja document.idx           # ロケール指定
```

#### 日本語索引の例

```latex
\documentclass{ltjsarticle}  % LuaLaTeX-ja 文書クラス
\usepackage{makeidx}
\makeindex

\begin{document}
漢字\index{かんじ@漢字}の例です。
ひらがな\index{ひらがな}も索引に入れます。

\printindex
\end{document}
```

```bash
lualatex document.tex
upmendex -s gind.ist document.idx  # 日本語ソート対応
lualatex document.tex
```

---

### xindy — 国際化対応索引

複数言語のソート規則に完全対応。

#### 基本使用法

```bash
xindy -L japanese -C utf8 -M lang/japanese/utf8 document.idx
```

#### 主要オプション

| オプション | 説明 |
|-----------|------|
| `-L language` | 言語指定（japanese, german, english等） |
| `-C encoding` | 文字エンコーディング（utf8, latin1等） |
| `-M module` | モジュール読み込み |
| `-o output` | 出力ファイル指定 |

#### xindy の利点

- 多言語ソート規則の完全サポート
- 複雑な文字の正しいソート（ウムラウト、アクセント等）
- 高度なカスタマイズ性

#### 欠点

- MakeIndexよりも複雑
- 設定ファイルがXindy独自形式
- `.ist` ファイルと互換性なし

---

### 索引レイアウトのカスタマイズ

#### `showidx` — 索引キーの表示

デバッグ用。索引エントリをマージンに表示：

```latex
\usepackage{showidx}
% \index{...} の箇所にマーカーが表示される
```

#### `imakeidx` — 複数索引の簡易作成

```latex
\usepackage{imakeidx}
\makeindex[name=general, title=General Index]
\makeindex[name=names, title=Index of Names]

\begin{document}
General term\index[general]{term}
Einstein\index[names]{Einstein, Albert}

\printindex[general]
\printindex[names]
\end{document}
```

#### `index` パッケージ — 高度な複数索引

```latex
\usepackage{index}
\newindex{default}{idx}{ind}{General Index}
\newindex{author}{adx}{and}{Author Index}

\begin{document}
text\index{term}
author\index[author]{Smith, John}

\printindex
\printindex[author]
\end{document}
```

---

## 索引とエラーメッセージ

### MakeIndex 警告・エラー

| メッセージ | 原因 | 対処法 |
|-----------|------|--------|
| `## Warning (input = ...): -- Conflicting entries` | 同じキーに異なる表示形式 | `@` で表示形式を統一 |
| `## Warning (input = ...): -- Missing \end{theindex}` | .ind ファイルが不完全 | 再コンパイル |
| `## Warning: ...` | 一般的な警告 | ログを確認 |

### トラブルシューティング

1. **索引が表示されない**
   - `\makeindex` がプリアンブルにあるか確認
   - `makeindex` または `upmendex` を実行したか確認
   - `.ind` ファイルが生成されているか確認

2. **日本語のソートが正しくない**
   - `upmendex` を使用
   - ロケール設定を確認（`-L ja`）

3. **特殊文字がうまく表示されない**
   - `@` を使って表示形式を明示
   - エスケープが必要な文字（`@`, `!`, `|`, `"` 等）は `"` でエスケープ

```latex
% 例: @ をエントリに含める
\index{"@}  % @ を索引に入れる
```

---

## 実践例

### 多言語文書の例

```latex
\documentclass{article}
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage[english,japanese]{babel}
\usepackage{makeidx}
\makeindex

\begin{document}
\selectlanguage{english}
This is English text\index{English}.

\begin{otherlanguage}{japanese}
これは日本語です\index{にほんご@日本語}。
\end{otherlanguage}

\printindex
\end{document}
```

### 高度な索引の例

```latex
\documentclass{article}
\usepackage{makeidx}
\makeindex

\begin{document}
% 階層構造
\index{Mathematics!Algebra}
\index{Mathematics!Calculus}

% 範囲指定
\index{Introduction|(}
... 複数ページ ...
\index{Introduction|)}

% 相互参照
\index{LaTeX|see{TeX}}

% 修飾
\index{Important|textbf}

\printindex
\end{document}
```

---

## まとめ

### 多言語対応の選択

| 条件 | 推奨パッケージ |
|------|--------------|
| pdfLaTeX + 基本的な多言語 | babel |
| XeLaTeX/LuaLaTeX + 複雑な文字体系 | polyglossia |
| 日本語文書 | babel (pLaTeX) または polyglossia (LuaLaTeX) |

### 索引処理の選択

| 条件 | 推奨ツール |
|------|----------|
| 英語のみ | MakeIndex |
| 日本語を含む | upmendex |
| 複数言語の複雑なソート | xindy |
| 複数索引 | imakeidx または index パッケージ |

---

## glossaries パッケージ - 用語集と略語管理

### 基本設定

```latex
\usepackage[toc, acronym]{glossaries}
% toc:     用語集を目次に追加
% acronym: 略語リストを通常の用語集から分離

\makeglossaries  % プリアンブルで必須（.gls/.glo ファイルを生成）
```

### 用語の定義

```latex
% 通常の用語（\newglossaryentry）
\newglossaryentry{latex}{
  name        = {LaTeX},
  description = {文書整形システム。数式や複雑なレイアウトに優れる}
}

% 略語・頭字語（\newacronym）
\newacronym{pdf}{PDF}{Portable Document Format}
\newacronym{gui}{GUI}{Graphical User Interface}
\newacronym{api}{API}{Application Programming Interface}
```

### 用語の引用コマンド

```latex
% 通常用語の引用
\gls{latex}        % LaTeX（初回以降も同じ表示）

% 略語の引用（\gls を使用）
\gls{pdf}          % 初回: "Portable Document Format (PDF)"
                   % 以降: "PDF"

% 表示形式を明示的に指定
\acrfull{pdf}      % Portable Document Format (PDF)（常に完全形）
\acrshort{pdf}     % PDF（常に略称のみ）
\acrlong{pdf}      % Portable Document Format（常に完全名のみ）

% 大文字化
\Gls{latex}        % LaTeX（文頭での使用、最初の文字を大文字化）
\GLS{pdf}          % PDF（すべて大文字）
```

### 用語集の出力

```latex
\begin{document}
本文...

% 用語集・略語リストを出力
\printglossaries

% または個別に出力
\printglossary[type=main]
\printglossary[type=\acronymtype, title={略語一覧}]

\end{document}
```

### コンパイル手順

```bash
# 方法1: makeglossaries コマンドを使用
pdflatex document
makeglossaries document   # .gls / .glo ファイルを処理
pdflatex document

# 方法2: latexmk で自動化
latexmk -pdf document
```

### hyperref との連携

```latex
% ロード順序に注意：hyperref の後に glossaries をロード
\usepackage{hyperref}
\usepackage[toc, acronym]{glossaries}
% → 用語集エントリに自動的にハイパーリンクが追加される
```
