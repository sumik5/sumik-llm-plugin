# LaTeXリソースガイド

本ドキュメントは、LaTeX利用時に活用できるオンラインリソース、サポートフォーラム、デバッグ手法、MWE作成方法をまとめたものです。

---

## ソフトウェアアーカイブとカタログ

### CTAN (Comprehensive TeX Archive Network)

**URL**: https://ctan.org

- 6,500以上のTeX/LaTeXパッケージとツールを提供する最大のアーカイブ
- パッケージ名またはトピック別に検索可能
- サイト全体検索機能あり
- TeX Live、MiKTeX等のディストリビューションの配布拠点
- 世界中にミラーサーバーが存在

**パッケージドキュメント参照 (texdoc)**:

```bash
# ターミナルからパッケージドキュメントを開く
texdoc amsmath
texdoc tikz
texdoc hyperref
```

### LaTeX Font Catalogue

**URL**: https://tug.org/FontCatalogue

- LaTeX対応フォントの一覧と実例を提供
- インデックス付きで検索しやすい

---

## TeX ユーザーグループ (TUG)

### 国際TeX Users Group (TUG)

**URL**: https://tug.org

- TeX開発、CTAN維持に貢献
- 豊富なコンテンツとリンク集

### DANTE (ドイツ語圏TeXユーザーグループ)

**URL**: https://www.dante.de

- ドイツ語の情報、会員誌、イベント情報

### GUTenberg (フランス語圏TeXユーザーグループ)

**URL**: https://www.gutenberg-asso.fr

- ニュースレター、定期刊行物

### LaTeX プロジェクトウェブサイト

**URL**: https://www.latex-project.org

- LaTeX開発者向けハブ
- 次期バージョンの情報

---

## Webフォーラムとディスカッショングループ

### LaTeX.org (国際コミュニティサポートフォーラム)

**URL**: https://latex.org

- 2008年以降、100,000件以上の投稿
- カテゴリ分類・タグ付け・検索可能
- 回答が迅速
- 記事アーカイブとニュースポータル（https://latex.net）

**LaTeX専用機能**:

- **Codeボタン**: LaTeXシンタックスハイライト、オンラインエディタで即コンパイル可能
- **LaTeXインラインコードボタン**: テキスト中にLaTeXコードを埋め込み
- **CTANボタン**: パッケージ名→CTAN該当ページへの自動リンク
- **Documentationボタン**: キーワード→texdoc.orgマニュアルへのリンク
- **Solvedステータス**: 未解決質問のフィルタリング

### TeX Stack Exchange

**URL**: https://tex.stackexchange.com

- 商用Q&Aプラットフォーム
- 質問と回答のみ（記事・ニュース無し）

### TeXwelt (ドイツ語)

**URL**: https://texwelt.de

### goLaTeX (ドイツ語)

**URL**: https://golatex.de

### Texnique (フランス語)

**URL**: https://texnique.fr

### Usenet ディスカッショングループ

- **comp.text.tex** (国際)
- **de.comp.text.tex** (ドイツ語)

---

## FAQ (よくある質問)

### TeX FAQ (英語)

**URL**: https://texfaq.org

- UK TeX Users Groupが収集、現在は複数の貢献者が保守
- ほとんどのトピックをカバー、推奨パッケージへのリンク付き

### Visual LaTeX FAQ

**URL**: https://ctan.net/info/visualfaq

- 100以上のテキストサンプルを含むドキュメント
- 気になる部分をクリックするとTeX FAQの該当ページへ

### LaTeX Pictures How-To

**URL**: https://ctan.net/info/l2picfaq

- 画像とフロートに関するQ&A集

### MacTeX FAQ

**URL**: https://tug.org/mactex/faq.html

### ドイツ語FAQ

- https://texfragen.de
- https://wiki.dante.de

### フランス語FAQ

**URL**: https://faq.gutenberg-asso.fr

---

## TeX ディストリビューション

### TeX Live

**URL**: https://tug.org/texlive

- クロスプラットフォーム（Windows, Linux, macOS, Unix）
- TeX Users Groupが支援

### MacTeX

**URL**: https://tug.org/mactex

- TeX LiveベースのmacOS特化版

### MiKTeX

**URL**: https://miktex.org

- 元々Windows専用、現在はUnix系にも移植
- ダウンロードとドキュメント完備

---

## MWE (Minimal Working Example) の作成

### MWEとは

**定義**: 問題を再現する最小限の完全なLaTeXコード例

**目的**:

- フォーラムで他のユーザーが即座にコピー・コンパイル・デバッグ可能
- 問題の原因を特定しやすくする
- 回答を得やすくなる

### MWE作成手順 (Top-Down アプローチ)

1. **ドキュメントをコピー**
   - 複数ファイルの場合はすべてコピー
   - **元ファイルは保持し、コピーを編集**

2. **不要部分を削除**
   - `\end{document}`を上に移動
   - 行を削除またはコメントアウト（`%`）
   - `\include`/`\input`をコメントアウト
   - 含まれるファイルに`\endinput`を挿入し、上に移動

3. **再コンパイルして確認**
   - 問題が残っていれば → ステップ2に戻る
   - 問題が消えたら → 削除部分に原因あり（undo して再挑戦）

4. **さらに簡略化**
   - 不要なパッケージを削除（`\usepackage`行をコメントアウト）
   - マクロ・環境定義を削除
   - 画像を`\rule{...}{...}`または`\usepackage[demo]{graphicx}`で置換
   - 長文をダミーテキスト（`blindtext`, `lipsum`, `kantlipsum`）に置換
   - 複雑な数式を簡略化
   - 参考文献ファイルを`filecontents*`環境に埋め込み

5. **完了判定**
   - 十分に簡略化されたか確認
   - 問題解決済みか、またはフォーラム投稿可能な状態か

### MWEの要件

- **完全性**: `\documentclass`から`\end{document}`まで含む
- **問題再現性**: コンパイル時に問題が発生する
- **最小性**: 不要なコードを含まない
- **汎用性**: 標準クラス（article, book, report）を使用
- **互換性**: システム依存の設定を避ける（エンコーディング、特殊フォント）
- **一般的なパッケージのみ**: 読者がインストール不要なもの

**推奨パッケージ**:

- `mwe`: `blindtext`と`graphicx`を自動ロード、ダミー画像を提供
- `standalone`: PDFを実際のコンテンツに合わせてクロップ（小さな図の例示に最適）

### MWE作成 (Bottom-Up アプローチ)

小さなテストドキュメントから始め、問題を再現するまで段階的に拡張する手法。

**利点**: 問題の起源を把握している場合に有効

**欠点**: 問題を正確に再現できない場合、MWEが無意味になる

---

## デバッグ手法

### `\listfiles` コマンド

プリアンブルに追加すると、読み込まれたすべてのファイルとバージョンを`.log`ファイルに記録。

```latex
\listfiles
\documentclass{article}
\usepackage{amsmath}
\begin{document}
Content
\end{document}
```

**用途**:

- パッケージバージョン確認
- 読み込まれているファイルの一覧取得

### `\show` と `\meaning` コマンド

マクロ・コマンド・環境の定義を確認する。

```latex
\show\maketitle
\meaning\section
```

**出力**: コンパイル時にターミナルまたは`.log`に定義が表示される。

**用途**:

- コマンドが定義されているか確認
- マクロの内部構造を調査

### コンフリクト解決

LaTeXはコンフリクトが発生してもコンパイルを続行し、ファイル内にマーカー（`<<<<<<<`, `=======`, `>>>>>>>`）を挿入する。

**解決手順**:

1. `jj status`（またはVCSコマンド）でコンフリクトファイルを確認
2. エディタでマーカーを含む箇所を直接編集
3. ファイル保存（LaTeXが自動検知）
4. `jj status`でコンフリクト解消確認

---

## オンライン LaTeX エディタ

### Overleaf

**URL**: https://www.overleaf.com

- リアルタイム共同編集
- コード不要モード
- 基本機能無料、プレミアム機能は有料
- 多数の大学・研究機関と提携（学生向けプレミアムアクセス提供）

### TeXLive.net

**URL**: https://texlive.net

- Webフォーラムに統合されたオンラインコンパイラ

---

## ブログとニュース

### TeXample.net Community Aggregator

**URL**: https://texample.net

- 最新のブログ投稿を集約
- 投稿抜粋とブログアーカイブ

### メーリングリスト

**一覧**: https://texblog.net/latex-link-archive/mailinglists

---

## エディタとPDFビューア

**リンク集**: https://texblog.net/latex-link-archive/distribution-editor-viewer/

---

## まとめ

- **CTAN**: パッケージの検索と入手
- **TeX.SE / LaTeX.org**: 質問と回答
- **FAQ**: 既知の問題解決
- **MWE作成**: デバッグとフォーラム投稿の鍵
- **デバッグツール**: `\listfiles`, `\show`, `\meaning`

---

## 実践的なTips

### コミュニティ（追加リソース）

**Reddit**:
- r/LaTeX: https://www.reddit.com/r/LaTeX — 気軽な質問と活発な議論。投票システムで良回答が上位に表示される

**メーリングリスト**（TUG管理、https://tug.org/mailman/listinfo で全一覧）:

| リスト | 用途 |
|-------|------|
| **texhax** | TeX全般の議論（1980年代から続く老舗） |
| **tex-live** | TeX Liveディストリビューションの情報 |
| **texworks** | TeXworksエディタのサポート |

**AMS-Math FAQ**: https://www.ams.org/faq — `amsmath`パッケージに特化したQ&A

### グラフィックスギャラリー

LaTeXで作成したグラフィックスのサンプルコードを閲覧できるサイト:

| サイト | 内容 |
|-------|------|
| https://texample.net | TikZギャラリー（数百例、トピック別） |
| https://tikz.net | 別TikZギャラリー（ソースコード付き） |
| https://tikz.org | TikZ専門書のサンプル集 |
| https://pgfplots.net | pgfplotsによる2D/3Dプロット例 |
| https://asymp.net | Asymptote言語による図形例 |
| https://feynm.net | ファインマン図のLaTeX例 |

### LaTeXブログ

| サイト | 内容 |
|-------|------|
| https://texblog.net | ニュース・Tips・リンク集（カテゴリ別） |
| https://www.texdev.net | LaTeXプロジェクトメンバーによる技術ブログ |
| https://tex-talk.net | インタビュー記事が充実 |
| https://tex.social | 30以上のLaTeX関連ブログのRSSアグリゲーター |

### エディタ一覧

クロスプラットフォーム（Windows / macOS / Linux）:

| エディタ | 特徴 |
|---------|------|
| **TeXworks** | 軽量・シンプル（TeXShop由来） |
| **Texmaker** | 多機能 |
| **TeXstudio** | Texmaker派生、さらに高機能 |
| **VS Code** + LaTeX Workshop拡張 | 補完・プレビュー・前後方検索対応 |
| **Emacs** + AUCTeX | 高度にカスタマイズ可能 |
| **LyX** | Word風GUIでLaTeX文書を作成（WYSIWYMエディタ） |

プラットフォーム別:
- **macOS**: TeXShop（Mac LaTeXの定番）
- **Windows**: WinEdt（有料シェアウェア、高機能）
- **Linux**: Kile（KDE向け）、GNOME-LaTeX

### X（旧Twitter）でLaTeX最新情報

| アカウント | 内容 |
|----------|------|
| `@TeXUsersGroup` | TUG公式（ニュース・CTANアップデート） |
| `@overleaf` | Overleaf公式 |
| `@tex_tips` | 毎日LaTeXのTipsを配信 |

ハッシュタグ `#TeXLaTeX` で最新情報を検索可能。

### AI Chatbotの活用

ChatGPT・Claude・Gemini等のAI ChatbotにLaTeXの質問をすることも有効。ただし:
- AIが誤ったLaTeXコードを生成することがある
- 複雑な問題はTeX.SEやLaTeX.orgに投稿する方が確実
- AIの回答は必ずコンパイルして検証する
