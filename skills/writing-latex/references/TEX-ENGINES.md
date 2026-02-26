# TeXエンジンとフォーマット

LaTeXの実行基盤となるTeXエンジン（pdfTeX・XeTeX・LuaTeX等）とTeXフォーマット（LaTeX・ConTeXt等）の解説・選択ガイド。

---

## TeXエンジンとは

**TeXエンジン**は実際の組版処理を行うプログラム。ソースファイルを読み込み、コマンドを解釈・展開し、行分割・ページ分割を行い、最終出力を生成する。「Typeset」「Compile」を実行するとエンジンが起動する。

エンジンが異なる理由は、組版要件の変化への対応にある。元来のTeXはUnicodeとOpenTypeフォントが普及する以前に設計されたため、現代的な文字体系・フォントへの対応を目的として新しいエンジンが開発された。

---

## エンジン比較

| エンジン | 出力 | Unicode | OpenType/System Font | Lua組み込み | 日本語 | 備考 |
|---------|------|---------|---------------------|------------|-------|------|
| **classic TeX** | DVI | ✗ | ✗ | ✗ | ✗ | 歴史的。eTeX拡張が現代エンジンに統合済み |
| **pdfTeX** | PDF | ✗（8bitのみ） | ✗（PostScriptフォントのみ） | ✗ | △ | 現在最も広く使われる「主力」エンジン |
| **XeTeX** | PDF | ✓ | ✓ | ✗ | ○ | Unicode・システムフォント対応。RTL（アラビア語・ヘブライ語）にも対応 |
| **LuaTeX** | PDF | ✓ | ✓ | ✓ | ○ | 最も拡張性が高い。LuaHBTeX（HarfBuzz統合）が現在の標準 |
| **LuaMetaTeX** | PDF | ✓ | ✓ | ✓ | ○ | LuaTeXの後継。ConTeXtのデフォルトエンジン |
| **pTeX** | DVI | ✗ | ✗ | ✗ | ✓ | 日本語組版専用 |
| **upTeX** | DVI/PDF | ✓（限定的） | ✗ | ✗ | ✓ | pTeXのUnicode拡張。日本語LaTeX（upLaTeX）の標準 |

### classic TeX / DVI ワークフロー

```
.tex → [TeX engine] → .dvi → [dvips] → .ps → [ps2pdf] → .pdf
                           → [dvipdfmx] → .pdf  （直接変換）
```

DVI（Device Independent）は特定のプリンター・画面に依存しない中間形式。現在は `dvipdfmx` による直接PDF変換が主流。画像はEPS形式のみサポート。

---

## pdfTeX

**pdfTeX** は多くのLaTeXユーザーが最初に使うエンジン。PDFを直接生成し、PNG・JPEG等の一般的な画像形式をサポートする。

**特徴**:
- `microtype` パッケージによるマイクロタイポグラフィ（文字幅調整・プロトルーディング）に最も対応
- PostScriptフォントのみ（システムフォント・OpenTypeフォントは直接使用不可）
- 信頼性が高く、ほとんどの文書で十分

---

## XeTeX

**XeTeX** はUnicodeとシステムフォントへのネイティブ対応が主な特徴。`fontspec` パッケージと組み合わせて使う。

**特徴**:
- OS上にインストールされたフォントを直接使用可能
- 多言語文書・非ラテン文字（アラビア語・ヘブライ語・中日韓）に強い
- 名前は「eXtended eTeX」の意味。RTL（右から左）を含む読み方で対称になるよう命名

```latex
% XeLaTeX での日本語・欧文フォント指定例
\usepackage{fontspec}
\setmainfont{Times New Roman}
\usepackage{xeCJK}
\setCJKmainfont{Hiragino Mincho ProN}
```

---

## LuaTeX / LuaHBTeX

**LuaTeX** はLuaプログラミング言語をエンジンに組み込み、組版処理へのプログラム的介入を可能にする。XeTeXと同様にUnicodeとOpenTypeフォントをサポート。

**LuaHBTeX** はLuaTeXにHarfBuzz（テキストシェーピングエンジン）を統合したバリアント。現在の `lualatex` コマンドはLuaHBTeXを使用している場合が多い。

### luacode環境によるLua活用

```latex
\documentclass{article}
\usepackage{luacode}

% Luaコードの定義（プリアンブル）
\begin{luacode}
  function GCD(a, b)
    if b ~= 0 then
      return GCD(b, a % b)
    else
      return a
    end
  end
\end{luacode}

\begin{document}
% LaTeX文書内でLua関数を呼び出す
96と36の最大公約数は \directlua{tex.sprint(GCD(96, 36))} です。
\end{document}
```

**出力**: `96と36の最大公約数は 12 です。`

`tex.sprint()` でLuaからLaTeXへテキストを送信する。`\directlua{}` コマンドでLuaコードを直接実行できる。

### LuaTeXの代表的な活用シーン

| 用途 | 説明 |
|-----|------|
| 動的コンテンツ生成 | データファイルを読み込んで表を自動生成 |
| 複雑な計算 | フラクタル・カオス系などの数値計算をLaTeX内で実行 |
| フォント高度制御 | `fontspec` + Luaによるカーニング・グリフ制御 |
| 組版ルール変更 | ハイフネーション・行分割アルゴリズムのカスタマイズ |

---

## TeXフォーマット

**TeXフォーマット**はTeXエンジンの上に構築されたマクロセット。エンジンが低レベルの組版処理を担当し、フォーマットが著者向けのコマンドを定義する。

エンジンが「機械」、フォーマットが「ユーザーインターフェース」に相当する。

### フォーマット一覧

| フォーマット | デフォルトエンジン | 特徴 |
|-----------|--------------|------|
| **Plain TeX** | classic TeX | 最小限のマクロ。完全制御だが便利さはない。現在は歴史的関心のみ |
| **LaTeX** | pdfTeX（デフォルト） | 高レベルコマンドで文書構造を記述。膨大なパッケージエコシステム |
| **ConTeXt** | LuaMetaTeX | 一貫したオールインワン設計。多くの機能がビルトイン |

### エンジン × フォーマットの組み合わせ名

| 名称 | エンジン | フォーマット |
|-----|---------|------------|
| **pdfLaTeX** | pdfTeX | LaTeX |
| **XeLaTeX** | XeTeX | LaTeX |
| **LuaLaTeX** | LuaTeX/LuaHBTeX | LaTeX |
| **upLaTeX** | upTeX | LaTeX |
| **ConTeXt** | LuaMetaTeX | ConTeXt |

### ConTeXtの文法（LaTeXとの比較）

```latex
% LaTeX の書き方
\begin{document}
  \chapter{方程式}
  \section{二次方程式}
  $ax^2 + bx + c = 0$
\end{document}
```

```tex
% ConTeXt の書き方（start/stop パターン）
\setuppapersize[A4]
\starttext
\startchapter[title={方程式}]
\startsection[title={二次方程式}]
$ax^2 + bx + c = 0$
\stopsection
\stopchapter
\stoptext
```

---

## エンジン選択の判断基準

### ユースケース別推奨

| 状況 | 推奨エンジン | 理由 |
|-----|------------|------|
| 標準的な欧文文書 | **pdfLaTeX** | 信頼性が高く、既存パッケージとの互換性が最良 |
| システムフォントを使いたい | **LuaLaTeX** | OpenType対応、`fontspec` が使える |
| Luaプログラミングを活用したい | **LuaLaTeX** | 動的コンテンツ生成・複雑な処理が可能 |
| RTL言語（アラビア語・ヘブライ語） | **XeLaTeX** または **LuaLaTeX** | Unicode・RTLテキストシェーピング対応 |
| テンプレートが指定している場合 | テンプレートに従う | 互換性を最優先 |
| 日本語文書（和文組版） | **upLaTeX + dvipdfmx** | 日本語組版の標準 |
| Lua統合レイアウト制御 | **ConTeXt** | 独自構文だがオールインワン |

### LuaLaTeX vs XeLaTeX

| 観点 | LuaLaTeX | XeLaTeX |
|-----|---------|---------|
| 現在の開発状況 | 活発 | 保守中心 |
| Luaプログラミング | ✓ | ✗ |
| OpenTypeフォント | ✓ | ✓ |
| コンパイル速度 | やや遅い | 速い |
| 推奨度（新規プロジェクト） | **推奨** | テンプレート要件時のみ |

---

## コマンドライン / エディタでのエンジン選択

### コマンドラインでの指定

```bash
pdflatex filename.tex     # pdfLaTeX
xelatex  filename.tex     # XeLaTeX
lualatex filename.tex     # LuaLaTeX
context  filename.tex     # ConTeXt
```

### エディタでの設定

| エディタ | 設定箇所 |
|---------|---------|
| **TeXworks** | Typesetボタン横のドロップダウン |
| **TeXstudio** | Options → Configure TeXstudio → Build → Default Compiler |
| **Overleaf** | Menu → Settings → Compiler |
| **VS Code** (LaTeX Workshop) | `settings.json` の `latex-workshop.latex.recipes` |

---

## AI活用について

LaTeX作業でのAI活用の詳細（プロンプト設計・コード生成・デバッグ支援等）は `AI-LATEX.md` を参照。

エンジン選択に関するAIへの質問例:

```
"What is the difference between LuaLaTeX and pdfLaTeX?
Provide decision guidance for a user writing a multilingual
scientific thesis with custom fonts."
```
