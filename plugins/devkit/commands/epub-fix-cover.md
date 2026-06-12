---
description: 指定フォルダ配下のEPUB/PDFを走査し、Kindle/Finderで表紙サムネイルが出ない原因を是正する。EPUBは固定レイアウト(pre-paginated)をreflowableに変換し表紙を正規化、PDFはTitleメタをファイル名から付与(lossless)。既に是正済みのものはスキップする。
context: fork
agent: general-purpose
allowed-tools: Bash
argument-hint: "<folder> [--no-backup] [--dry-run]"
---

# EPUB/PDF 表紙修正 - Kindle/Finder で表紙サムネイルを出す

フォルダ配下の EPUB / PDF を走査し、表紙サムネイルが出ない原因を是正する(Calibre 使用)。

- **EPUB**: 固定レイアウト(fixed-layout / pre-paginated / comic)の EPUB は Kindle のカバー生成や macOS QuickLook がサムネイルを作れず表紙が真っ黒になる。`ebook-convert` で reflowable に再生成し表紙宣言を正規化する。
- **PDF**: PDF には EPUB のような「表紙メタの枠」が無く、Kindle はサムネを 1 ページ目の描画から生成する。Title メタが空だとカタログ登録/サムネ生成が不安定なため、`ebook-meta` で Title をファイル名から付与する(lossless・本文不変)。

## 使い方

```
/epub-fix-cover <フォルダ>              # 配下(再帰)の全epub/pdfを処理
/epub-fix-cover <フォルダ> --dry-run    # 処理せず対象/スキップ判定だけ表示
/epub-fix-cover <フォルダ> --no-backup  # 原本の .bak バックアップを作らない
```

## スキップ条件

- **EPUB**: 固定レイアウトでない かつ cover 宣言あり(= 既に表紙が出る状態)。固定レイアウトは cover 宣言の有無に関わらず変換対象(固定レイアウトはサムネ生成自体が壊れるため)。
- **PDF**: 既に Title メタが設定済み。
- 破損して開けないファイルは警告を出してスキップ。

## 注意

- 原本は同じ場所に `<name>.bak` として退避(`--no-backup` で無効化)。
- EPUB の reflowable 化により**見開き表示は1ページずつのスクロール表示に変わる**(全ページ・全画像は保全)。
- **PDF の制約**: Send to Kindle で送った個人ドキュメント(PDOC)は、E-Ink 端末では仕様上「ダウンロード前」のライブラリ一覧に表紙を出さない(ロック画面/スマホアプリでは出る)。これは Kindle 側の制約でファイル側では解消できない。Title メタ付与はダウンロード後/アプリでの表紙表示とカタログ登録を改善する。
- 依存: **Calibre (`ebook-convert` / `ebook-meta`)**。PDF のスキップ判定に `pdfinfo`(poppler) があれば使用(無くても動作)。未導入なら `brew install --cask calibre` 等で導入し PATH を通すこと(macOS 例: `/Applications/calibre.app/Contents/MacOS`)。

## 実行

引数 `$ARGUMENTS` をそのままスクリプトに渡して実行する。フォルダが未指定ならユーザーに確認すること。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/epub-fix-cover.sh" $ARGUMENTS
```

実行後、処理/スキップ/破損の件数サマリを報告する。破損ファイルがあれば「再取得が必要」と明示し、EPUB の reflowable 化トレードオフ(見開き→スクロール)と、PDF の Send-to-Kindle 制約(E-Ink はダウンロード前に表紙が出ない)を一言添える。
