---
description: 指定フォルダ配下のEPUBを走査し、Kindle/Finderで表紙サムネイルが出ない固定レイアウト(pre-paginated)EPUBをreflowableに変換して表紙を正規化する。既に表紙が出る状態のEPUBはスキップする。
context: fork
agent: general-purpose
allowed-tools: Bash
argument-hint: "<folder> [--no-backup] [--dry-run]"
---

# EPUB 表紙修正 - Kindle/Finder で表紙サムネイルを出す

固定レイアウト(fixed-layout / pre-paginated / comic)の EPUB は、Kindle のカバー生成や macOS QuickLook がサムネイルを作れず、表紙が真っ黒(タイトルのみ)になることがある。このコマンドは Calibre の `ebook-convert` で reflowable に再生成し、表紙宣言を正規化してサムネイルが出るようにする。

## 使い方

```
/epub-fix-cover <フォルダ>              # フォルダ配下(再帰)の全epubを処理
/epub-fix-cover <フォルダ> --dry-run    # 変換せず対象/スキップ判定だけ表示
/epub-fix-cover <フォルダ> --no-backup  # 原本の .bak バックアップを作らない
```

## スキップ条件

「既に表紙が出る状態」= **固定レイアウトでない かつ cover 宣言あり** の EPUB は変換せずスキップする。固定レイアウトの EPUB は cover 宣言の有無に関わらず変換対象になる(固定レイアウトはサムネ生成自体が壊れるため)。破損して zip として開けない EPUB は警告を出してスキップする。

## 注意

- 原本は同じ場所に `<name>.epub.bak` として退避される(`--no-backup` で無効化)。
- reflowable 化により**見開き表示は1ページずつのスクロール表示に変わる**(全ページ・全画像は保全)。
- 依存: **Calibre (`ebook-convert`)**。未導入なら `brew install --cask calibre` 等で導入し、`ebook-convert` に PATH を通すこと(macOS 例: `/Applications/calibre.app/Contents/MacOS`)。

## 実行

引数 `$ARGUMENTS` をそのままスクリプトに渡して実行する。フォルダが未指定ならユーザーに確認すること。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/epub-fix-cover.sh" $ARGUMENTS
```

実行後、変換/スキップ/破損の件数サマリを報告する。破損 EPUB があれば「再取得が必要」と明示し、reflowable 化のトレードオフ(見開き→スクロール表示)を一言添える。
