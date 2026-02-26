# トラブルシューティング・デバッグ技法

LaTeX のエラー・警告の読み方、メモリ問題、トレーシング技法を扱う。

---

## エラーメッセージの読み方

### エラーメッセージの構造

```
! Undefined control sequence.
l.42 \mycommand
               {text}
?
```

| 要素 | 説明 |
|------|------|
| `!` | エラーの開始 |
| `Undefined control sequence.` | エラーメッセージ |
| `l.42` | 行番号 |
| `\mycommand` | 問題のあるコマンド |
| `?` | 対話プロンプト |

### 対話プロンプトでの操作

| キー | 動作 |
|------|------|
| `h` | ヘルプメッセージを表示 |
| `x` | 処理を中断して終了 |
| `q` | 以降のエラーを表示せずに処理続行 |
| `r` | run mode（以降のエラーを抑制） |
| `e` | エディタで該当行を開く |
| Enter | エラーを無視して続行 |

---

## 主要なLaTeXエラー

### 1. Undefined control sequence

**原因：** 未定義のコマンドを使用

```
! Undefined control sequence.
l.10 \mycommand
```

**対処法：**
- パッケージを読み込んだか確認
- コマンド名のスペルミスを確認
- `\newcommand` で定義したか確認

---

### 2. Missing \begin{document}

**原因：** `\begin{document}` の前にテキストがある

```
! LaTeX Error: Missing \begin{document}.
```

**対処法：**
- プリアンブルに本文を誤って書いていないか確認
- `%` でコメントアウトされていない行がないか確認

---

### 3. Missing $ inserted

**原因：** 数式モード外で数式コマンドを使用

```
! Missing $ inserted.
<inserted text>
                $
l.15 Text with \alpha
```

**対処法：**
- 数式コマンドを `$...$` または `\(...\)` で囲む
- `_` や `^` を使う場合は数式モードに入る

---

### 4. Missing } inserted / Extra }

**原因：** 括弧の不一致

```
! Missing } inserted.
```

**対処法：**
- `{` と `}` の数を確認
- エディタの括弧対応機能を使用
- 段階的にコメントアウトして問題箇所を特定

---

### 5. Runaway argument

**原因：** 引数の終了括弧がない

```
Runaway argument?
{text without closing brace
! Paragraph ended before \mycommand was complete.
```

**対処法：**
- 引数の `}` を確認
- 複数行にわたる引数の場合、空行（段落区切り）がないか確認

---

### 6. File not found

**原因：** ファイルやパッケージが見つからない

```
! LaTeX Error: File `mypackage.sty' not found.
```

**対処法：**
- パッケージ名のスペルを確認
- TeX Live/MiKTeXでパッケージをインストール
- `\graphicspath` の設定を確認（画像ファイルの場合）

---

### 7. Too many }'s

**原因：** 余分な `}`

```
! Too many }'s.
l.20 Text}
```

**対処法：**
- `{` と `}` の数を確認
- 前の行で `{` が欠けていないか確認

---

### 8. Illegal parameter number in definition

**原因：** `\newcommand` で引数番号が不正

```
! Illegal parameter number in definition of \mycommand.
```

**対処法：**
- 引数番号は `#1`, `#2`, ... `#9` まで
- 引数番号が連続しているか確認（`#1`, `#3` はNG）

---

### 9. Environment ... undefined

**原因：** 未定義の環境を使用

```
! LaTeX Error: Environment myenv undefined.
```

**対処法：**
- 環境名のスペルを確認
- 必要なパッケージを読み込む
- `\newenvironment` で定義したか確認

---

### 10. \begin{...} ended by \end{...}

**原因：** 環境の開始と終了が一致しない

```
! LaTeX Error: \begin{itemize} on input line 10 ended by \end{enumerate}.
```

**対処法：**
- `\begin{...}` と `\end{...}` の対応を確認
- 入れ子構造が正しいか確認

---

## 主要なエラーまとめ表

| エラー | 原因 | 対処法 |
|--------|------|--------|
| Undefined control sequence | 未定義コマンド | パッケージ読み込み、スペル確認 |
| Missing \begin{document} | プリアンブルに本文 | `\begin{document}` 前のテキスト削除 |
| Missing $ inserted | 数式モード外で数式 | `$...$` で囲む |
| Missing } inserted | 括弧不一致 | `{}` の対応確認 |
| Runaway argument | 引数の終了括弧なし | 引数の `}` 確認 |
| File not found | ファイル・パッケージなし | インストール、パス確認 |
| Too many }'s | 余分な `}` | `{}` の数確認 |
| Illegal parameter number | 引数番号不正 | `#1`...`#9` の範囲、連続性確認 |
| Environment undefined | 未定義環境 | パッケージ読み込み、定義確認 |
| \begin{...} ended by \end{...} | 環境不一致 | 対応確認 |

---

## メモリ超過の対処

### TeX capacity exceeded

```
! TeX capacity exceeded, sorry [main memory size=...].
```

**原因：**
- 無限ループ
- 巨大な画像
- 過度に複雑な構造

**対処法：**

1. **無限ループの確認**
   - 再帰的な定義がないか確認
   - 段階的にコメントアウトして問題箇所を特定

2. **画像の最適化**
   - 画像ファイルサイズを削減
   - 解像度を適切に調整（印刷なら300dpi、画面なら72-96dpi）

3. **メモリ設定の増加**（最終手段）

   ```bash
   # TeX Live の場合
   # texmf.cnf を編集
   main_memory = 12000000
   extra_mem_bot = 12000000
   ```

---

## 警告メッセージ

### Overfull \hbox

テキストが行幅をはみ出している。

```
Overfull \hbox (10.5pt too wide) in paragraph at lines 15--20
```

**対処法：**
- `\sloppy` で許容範囲を緩める（非推奨）
- `\hyphenation{word}` でハイフネーション位置を指定
- `microtype` パッケージで微調整
- 手動で改行位置を調整

---

### Underfull \hbox

行の単語間が広すぎる。

```
Underfull \hbox (badness 1000) in paragraph at lines 15--20
```

**対処法：**
- 文章を書き直して単語数を調整
- `\raggedright` で右側を不揃いに
- `microtype` パッケージ

---

### Overfull \vbox / Underfull \vbox

ページの垂直方向の問題。

```
Overfull \vbox (10.0pt too high) has occurred while \output is active
```

**対処法：**
- `\enlargethispage{1\baselineskip}` でページを拡大
- フロート配置を調整
- `\raggedbottom` でページ下部を不揃いに

---

### LaTeX Warning: Reference `...` undefined

相互参照が未定義。

```
LaTeX Warning: Reference `fig:example' on page 1 undefined on input line 42.
```

**対処法：**
- もう一度コンパイル（2回必要）
- `\label` が定義されているか確認
- `\label` の位置を確認（キャプションの後）

---

### LaTeX Warning: Citation `...` undefined

引用が未定義。

```
LaTeX Warning: Citation `knuth1984' on page 1 undefined on input line 42.
```

**対処法：**
- BibTeX/biber を実行
- `.bib` ファイルに該当エントリがあるか確認
- citekey のスペルを確認

---

### Package hyperref Warning: Token not allowed

hyperref とのコンフリクト。

```
Package hyperref Warning: Token not allowed in a PDF string
```

**対処法：**
- `\texorpdfstring{LaTeX版}{PDF版}` を使用

```latex
\section{\texorpdfstring{$\alpha$-Calculus}{Alpha-Calculus}}
```

---

### Font shape ... undefined

フォントの組み合わせが存在しない。

```
LaTeX Font Warning: Font shape `T1/cmr/m/it' undefined
```

**対処法：**
- 代替フォントが自動使用される（通常は問題なし）
- 明示的にフォントを設定
- `lmodern` パッケージを使用

---

## トレーシングコマンド

### `\tracingall` — 全トレース有効化

```latex
\tracingall
% 問題のあるコード
\tracingnone  % 無効化（要 trace パッケージ）
```

**出力：**
- すべてのマクロ展開
- ボックス構築
- グルー挿入
- ページ分割

**注意：** ログファイルが膨大になる。問題箇所の直前のみ使用推奨。

---

### `\showthe` — レジスタ値表示

```latex
\showthe\textwidth
\showthe\baselineskip
```

**出力：**
```
> 345.0pt.
l.10 \showthe\textwidth
```

---

### `\showbox` — ボックス内容表示

```latex
\setbox0=\hbox{text}
\showbox0
```

**出力：**
```
> \box0=
\hbox(6.94444+1.94444)x19.99168
.\OT1/cmr/m/n/10 t
.\OT1/cmr/m/n/10 e
.\OT1/cmr/m/n/10 x
.\OT1/cmr/m/n/10 t
```

---

### ページ分割のトレーシング

```latex
\tracingpages=1
\tracingoutput=1
```

**出力：** ページ分割の計算過程

---

### 段落分割のトレーシング

```latex
\tracingparagraphs=1
```

**出力：** 行分割の計算過程

---

### マクロ展開のトレーシング

```latex
\tracingmacros=2
% 問題のあるマクロ
\tracingmacros=0
```

**出力：** マクロ展開の詳細

---

### `trace` パッケージ — 選択的トレーシング

```latex
\usepackage{trace}

\traceon
% トレースしたいコード
\traceoff
```

**利点：**
- `\tracingall` より軽量
- 必要な部分のみトレース
- `\tracingnone` で無効化可能

---

## デバッグの実践例

### 例1: 括弧不一致の特定

```latex
% 段階的にコメントアウト
\section{Introduction}
% Text 1
% Text 2
% Text 3
```

問題が消えるまでコメントアウトを進める。

---

### 例2: 無限ループの特定

```latex
\newcommand{\myloop}[1]{%
  \myloop{#1}%  % 無限ループ!
}
```

**対処：** 再帰呼び出しを削除または条件付きに。

---

### 例3: Overfull hbox の解決

```latex
% 問題
This is a very long word: supercalifragilisticexpialidocious.

% 解決1: ハイフネーション
\hyphenation{super-cali-fragi-listic-expi-ali-docious}

% 解決2: microtype
\usepackage{microtype}

% 解決3: 手動改行
This is a very long word: super\-cali\-fragi\-listic\-expi\-ali\-docious.
```

---

## ログファイルの読み方

### .log ファイルの構造

```
This is pdfTeX, Version 3.141592653-2.6-1.40.25 (TeX Live 2024)
...
LaTeX2e <2023-11-01> patch level 1
...
(./document.tex
LaTeX Font Info: ...
...
[1] [2]
...
Output written on document.pdf (2 pages, 12345 bytes).
Transcript written on document.log.
```

### 重要な情報

- **パッケージ読み込み**
  ```
  (/path/to/package.sty
  Package: package 2024/01/01 v1.0 Package description
  )
  ```

- **警告・エラー**
  ```
  LaTeX Warning: ...
  ! LaTeX Error: ...
  ```

- **ページ出力**
  ```
  [1] [2] [3]
  ```

- **出力統計**
  ```
  Output written on document.pdf (10 pages, 123456 bytes).
  ```

---

## トラブルシューティングのチェックリスト

1. **コンパイルを複数回実行**
   - 相互参照・目次・索引は2-3回必要

2. **補助ファイルを削除**
   ```bash
   rm *.aux *.toc *.lot *.lof *.idx *.ind *.bbl *.blg
   ```

3. **最小限の例（MWE）を作成**
   ```latex
   \documentclass{article}
   \begin{document}
   % 問題を再現する最小限のコード
   \end{document}
   ```

4. **パッケージを段階的に読み込む**
   - 一つずつコメントアウト解除

5. **ログファイルを確認**
   - 警告メッセージを見逃さない

6. **オンラインリソースを活用**
   - TeX Stack Exchange
   - LaTeX Wikibook

---

## まとめ

### エラー対処の基本

1. **エラーメッセージを丁寧に読む**
2. **行番号を確認**
3. **最小限の例で再現**
4. **段階的にコメントアウト**
5. **ログファイルを確認**

### デバッグツール

| ツール | 用途 |
|--------|------|
| `\tracingall` | 全トレース |
| `\showthe` | 値表示 |
| `\showbox` | ボックス内容 |
| `\tracingpages` | ページ分割 |
| `\tracingparagraphs` | 段落分割 |
| `trace` パッケージ | 選択的トレース |

### 警告への対処

- **Overfull/Underfull hbox**: `microtype`, 手動調整
- **Reference undefined**: 複数回コンパイル
- **Citation undefined**: BibTeX/biber実行
- **Font warning**: 通常は無視可能

### ベストプラクティス

- 頻繁にコンパイルして問題を早期発見
- バージョン管理（Git）で変更を追跡
- 最小限の例（MWE）を作成する習慣

---

## 実践的なTips

### フロート配置の警告

図・表が正しく配置できない場合に発生する警告:

| 警告 | 原因 | 対処法 |
|------|------|--------|
| `Float too large for page` | 図・表がページに収まらない | 画像サイズを縮小、`scale=0.8`等で調整 |
| `h float specifier changed to ht` | `h`指定で配置できず次ページ先頭に | `[!htbp]`を使い配置の自由度を上げる |

推奨配置オプション:
```latex
\begin{figure}[!htbp]   % 最大限の配置自由度
\begin{table}[!htbp]
```

### 未使用のグローバルオプション

```
LaTeX Warning: Unused global option(s): [unknown-option]
```

`\documentclass`に渡したオプションが、クラスにもパッケージにも認識されていない。`\documentclass`のオプションを確認する。

### パッケージのロード順序

一部のパッケージはロード順に依存する:

- **`hyperref`は最後にロードする**: 多くのパッケージとの競合を防ぐ
- **パッケージ順序の変更でエラーが解決することがある**: 問題が発生したら順序を入れ替えてテスト

```latex
% 推奨: hyperref は最後
\usepackage{amsmath}
\usepackage{graphicx}
\usepackage{hyperref}   % 最後
```

### 廃止パッケージの回避

LaTeXには数十年の歴史があり、古いチュートリアルや例には廃止されたパッケージが含まれることがある。問題が発生したら後継パッケージを確認する:

**確認方法**: `https://ctan.org/pkg/<パッケージ名>` でCTANのパッケージページを確認。説明文に「obsolete」や推奨後継パッケージが記載されている。

**代表的な廃止→後継の例**:

| 廃止パッケージ | 推奨後継 |
|--------------|---------|
| `epsfig` | `graphicx` |
| `subfigure` | `subcaption` |
| `natbib` + 古いスタイル | `biblatex` |
| `psfrag` | (直接PDFグラフィックスを使用) |
| `times` | `mathptmx` または `newtxtext` |

**網羅的なリスト**: `texdoc l2tabu` または https://latexguide.org/obsolete を参照。

**texfaq.orgのエラー参照**: https://texfaq.org/#errors で多くのエラーパターンの解説を確認できる。
