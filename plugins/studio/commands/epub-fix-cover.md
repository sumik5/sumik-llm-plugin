---
description: 指定フォルダ/ファイルのEPUB/PDFを走査し、Kindle/Finderで表紙サムネイルが出ない原因を是正する。EPUBは固定レイアウト(pre-paginated)をreflowableに変換し表紙を正規化、PDFはTitleメタをファイル名から付与(lossless)。--pdf-to-epubでスキャン画像PDFを「1ページ=1画面」のEPUBへ再構成し、Kindleで画面にフィット・ページ送り・表紙表示を実現する。--pdf-spreadでスキャンPDFをEPUB3 fixed-layout見開きEPUBへ再構成し、ノンブル左右判定・綴じ方向自動推定・各ページ画像を無加工のまま格納(トリミング/余白付与なし)・original-resolution付与(E999回避)でKindle/KFXの横画面で見開き表示を実現する。既に是正済みのものはスキップする。
context: fork
agent: general-purpose
allowed-tools: Bash
argument-hint: "<folder|file> [--pdf-to-epub] [--pdf-spread] [--replace-pdf] [--pdf-epub-dpi N] [--page-direction ltr|rtl|auto] [--spread-mode landscape|both] [--no-backup] [--dry-run]"
---

# EPUB/PDF 表紙修正 - Kindle/Finder で表紙サムネイルを出す

フォルダ/ファイル配下の EPUB / PDF を走査し、表紙サムネイルが出ない原因と、PDF の「画面にページが収まらずスクロールが必要」問題を是正する(Calibre 使用)。

- **EPUB**: 固定レイアウト(fixed-layout / pre-paginated / comic)の EPUB は Kindle のカバー生成や macOS QuickLook がサムネイルを作れず表紙が真っ黒になる。`ebook-convert` で reflowable に再生成し表紙宣言を正規化する。
- **PDF(既定)**: PDF には EPUB のような「表紙メタの枠」が無く、Kindle はサムネを 1 ページ目の描画から生成する。Title メタが空だとカタログ登録/サムネ生成が不安定なため、`ebook-meta` で Title をファイル名から付与する(lossless・本文不変)。
- **PDF(`--pdf-to-epub`)**: Kindle の PDF ビューアは PDF を固定サイズで描画するため、E-Ink の小画面では**ページが画面に収まらず「見開きにならない/下にスクロールしないと全体が見えない」**状態になる。各ページを画像化し、画面フィット(`max-width/height:100%`)の XHTML 1 枚ずつに収めた**「1ページ=1画像=1画面」の reflowable EPUB(同名 .epub)**へ再構成すると、各ページが画面にフィットしページ送りで読める。表紙は Kindle/KFX が確実に認識できるよう**4機構を併用**して宣言する: (1)metadata の `<meta name="cover">`、(2)カバー画像の `properties="cover-image"`、(3)専用 `cover.xhtml`(SVG 全画面ラップ・`epub:type="cover"`)、(4)EPUB2 `<guide><reference type="cover">`。なお **OCR は行わず** `pdftoppm` でページを画像化するだけで、大判スキャンや低速ボリュームでの遅さは画像化の I/O による(OCR ではない)。**スキャン画像書籍の Kindle 最適化に有効**。
- **PDF(`--pdf-spread`)**: スキャン画像 PDF を **EPUB3 fixed-layout(pre-paginated)の見開き EPUB** へ再構成する。ページ画像の下部帯インク密度を左右比較する**ノンブル左右判定**(OCR不使用・Pillow使用)でページの物理的な左右を判定し、**綴じ方向(LTR/RTL)を自動推定**して各ページを正しい側(`rendition:page-spread-left` / `right` / `center`)に配置する。**表紙(スキャン1ページ目)は cover-image 専用として宣言**(metadata の `<meta name="cover">` と画像の `properties="cover-image"` の2機構)し、**本文 spine から除外して表紙を1回だけ単独表示**する(専用 cover.xhtml や guide reference は使わない・二重表示を回避)。**本文は2ページ目以降を見開きペアで配置**する(LTR なら 2ページ目=左・3ページ目=右)。**各ページ画像は pdftoppm 出力を無加工のまま格納**し(トリミング・リサイズ・余白付与を行わない)、各ページの viewport をその画像のネイティブ寸法に一致させて `object-fit:fill` で隙間なく充填する。これによりスクリプトが画像の前後左右に余計なマージンを足さず、元 PDF が同寸なら左右ページも同寸で並ぶ。Kindle の Send to Kindle 配信に必要な **`original-resolution` メタを付与**する(最頻ネイティブ寸法で代表)(欠落時は E999 / E34002 で配信失敗する)。Kindle/KFX の**横画面で見開き表示**・**縦画面で単ページ表示**(端末/アプリ/OS依存)。`--pdf-to-epub` と同名 `.epub` 既存時スキップの冪等性スキップを共有する。

## 使い方

```
/epub-fix-cover <フォルダ>                       # 配下(再帰)の全epub/pdfを処理(PDFはTitleメタ付与)
/epub-fix-cover <ファイル.pdf>                   # 単一ファイル指定も可
/epub-fix-cover <フォルダ> --dry-run             # 処理せず対象/スキップ判定だけ表示
/epub-fix-cover <フォルダ> --no-backup           # 原本の .bak バックアップを作らない
/epub-fix-cover <フォルダ> --pdf-to-epub         # PDFを画像ページEPUBへ変換(.epub併置・元PDF保持)
/epub-fix-cover <フォルダ> --pdf-to-epub --replace-pdf   # 変換後に元PDFを.bak退避して削除
/epub-fix-cover <フォルダ> --pdf-to-epub --pdf-epub-dpi 300  # ページ画像解像度を指定(既定200)
/epub-fix-cover <フォルダ> --pdf-spread          # スキャンPDFを見開きEPUBへ変換(画像無加工・綴じ方向自動)
/epub-fix-cover <フォルダ> --pdf-spread --page-direction rtl # 綴じ方向を手動指定(右→左綴じ=和書)
/epub-fix-cover <フォルダ> --pdf-spread --page-direction ltr # 綴じ方向を手動指定(左→右綴じ=洋書)
/epub-fix-cover <フォルダ> --pdf-spread --spread-mode both   # 縦横両方で見開きを試みる(端末依存)
/epub-fix-cover <フォルダ> --pdf-spread --replace-pdf        # 見開きEPUB生成後に元PDFを.bak退避して削除
/epub-fix-cover <フォルダ> --pdf-spread --pdf-epub-dpi 300   # ページ画像解像度を指定(既定200)
```

## スキップ条件

- **EPUB**: 固定レイアウトでない かつ cover 宣言あり(= 既に表紙が出る状態)。固定レイアウトは cover 宣言の有無に関わらず変換対象(固定レイアウトはサムネ生成自体が壊れるため)。
- **PDF(既定)**: 既に Title メタが設定済み。
- **PDF(`--pdf-to-epub`)**: 同名 `.epub` が既に存在(再実行で上書きしない=冪等)。
- **PDF(`--pdf-spread`)**: 同名 `.epub` が既に存在(冪等スキップ。`--pdf-to-epub` と同一条件)。
- 破損して開けないファイルは警告を出してスキップ。

## 注意

- 原本は同じ場所に `<name>.bak` として退避(`--no-backup` で無効化)。`--pdf-to-epub` / `--pdf-spread` は既定で元 PDF を残し(`.bak` は作らず)、`--replace-pdf` 指定時のみ `.bak` 退避＋PDF 削除。
- EPUB の reflowable 化、および `--pdf-to-epub` 変換により**見開き表示は1ページずつのページ送りに変わる**(全ページ・全画像は保全)。
- **`--pdf-spread` の縦画面単ページ表示は仕様**: `rendition:spread=landscape`(既定)では縦持ちスマホ/E-Ink は1ページ表示になる。これはバグではなく仕様。見開きは**横画面・端末/アプリ設定依存**であり、実機での動作確認を推奨する。縦でも見開きを試みたい場合は `--spread-mode both` を指定(縦画面で表示が潰れるリスクは利用者判断)。
- **「画面いっぱいに表示したい」なら `--pdf-spread` ではなく `--pdf-to-epub` を使う**: `--pdf-spread`(fixed-layout 見開き)は Kindle が各ページを半画面へ**アスペクト保持で収める**ため、縦長スキャンページでは端末依存のレターボックス(見開き中央の継ぎ目＋外周余白)が出て画面いっぱいにならない(端末側のスケーリング挙動で EPUB 側 CSS では除去不能)。中央の継ぎ目と余白を消す `book-type=comic`＋`zero-gutter`＋`zero-margin`(KCC 等が使うコミックメタ)を付けるとローカル `kindlegen` は通るが、**Send to Kindle のクラウド変換が「互換性のない要素」(E013)として配信を拒否する**ため使えない。各ページを端末サイズに合わせて最大表示したい場合は **reflowable の `--pdf-to-epub`**(1ページ=1画面・`max-width/height:100%` でフィット)を使う。見開きは諦める代わりに、全端末で各ページが収まる最大サイズで表示され Send to Kindle 互換性も最も高い。
- **`--pdf-spread` は画像を無加工で格納**: スキャン画像(pdftoppm 出力)をトリミング・リサイズ・余白付与なしでそのまま EPUB に入れ、各ページ viewport をその画像のネイティブ寸法に合わせて隙間なく充填する。スクリプトが画像の前後左右に余計なマージンを足さない。元 PDF のページが同寸なら左右ページも同寸で並ぶ(元が異寸ならそのまま反映)。スキャンに含まれる紙面自体の余白・ノド影は元画像のまま残る(無加工方針のため)。`--no-trim` は廃止され受理のみ(無視)で後方互換のため残置。
- **`--pdf-spread` の綴じ方向**: 既定は `auto`(ページ下部のノンブル位置から左右を推定し LTR/RTL を自動判定)。日本語縦書き本など `auto` が取り違える場合は `--page-direction rtl` を明示することを推奨する。誤検出時は `--page-direction ltr|rtl|auto` で手動上書きできる。
- **`--pdf-spread` の見開きズレ**: 白ページ・章扉・折込・ノンブル判定誤りで以降のペアが1枚ずれることがある。ずれが生じた場合は `--page-direction ltr` または `--page-direction rtl` で綴じ方向を手動指定して再実行すること。スクリプトは判定崩れを検知した際に WARNING を出力する。
- **`--pdf-spread` のノンブル左右判定**: Pillow がインストールされている場合のみ有効(OCR不使用・下部帯インク密度ヒューリスティック)。Pillow 不在時は奇偶パリティのみで代替し WARNING を表示する。品質上 **Pillow のインストールを強く推奨**(例: `pip3 install Pillow`)。
- **PDF の制約**: Send to Kindle で送った個人ドキュメント(PDOC)は、E-Ink 端末では仕様上「ダウンロード前」のライブラリ一覧に表紙を出さない(ロック画面/スマホアプリでは出る)。これは Kindle 側の制約でファイル側では解消できない。**`--pdf-to-epub` / `--pdf-spread` で生成した EPUB は PDOC ではなく電子書籍として扱われるため、この制約と「ページが画面に収まらない」問題の両方を回避できる**。
- **`--pdf-to-epub` / `--pdf-spread` は OCR を行わない**(pdftoppm でページを画像化するのみ)。大判スキャンや低速な外部ボリュームでの変換の遅さは、OCR ではなく画像化の I/O によるもの。裏で別の OCR タスクが同じボリュームを使っていると競合してさらに遅くなる点に注意。
- **カバーがそれでも出ない時は Kindle 側キャッシュを疑う**: `--pdf-to-epub` / `--pdf-spread` で生成した EPUB はカバー宣言済みのため、Send to Kindle してもライブラリに表紙が出ない場合はファイル側ではなく Kindle がカバーをキャッシュしている可能性が高い。端末/アプリから一旦そのタイトルを削除し、再送信すれば反映される。
- 依存: **Calibre (`ebook-convert` / `ebook-meta`)**。PDF のスキップ判定に `pdfinfo`(poppler) があれば使用(無くても動作)。`--pdf-to-epub` / `--pdf-spread` には **`pdftoppm`(poppler) と `python3`** が必須。**`--pdf-spread` では Pillow を強く推奨**(不在時はノンブル判定が奇偶フォールバックになる。画像は無加工で格納するため余白には影響しない)。未導入なら `brew install --cask calibre` / `brew install poppler` / `pip3 install Pillow` 等で導入し PATH を通すこと(macOS 例: `/Applications/calibre.app/Contents/MacOS`)。

## 実行

引数 `$ARGUMENTS` をそのままスクリプトに渡して実行する。**第1引数はフォルダまたは単一の .epub/.pdf ファイル**で、オプション以外の余計な文字列(自由記述・説明文)を引数に含めないこと(パスとして解釈され失敗する)。対象が未指定ならユーザーに確認する。スキャン画像 PDF で「Kindle でページが画面に収まらない/見開きにならない/スクロールが必要」と相談された場合は `--pdf-to-epub` を付けて実行する。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/epub-fix-cover.sh" $ARGUMENTS
```

実行後、処理/スキップ/破損の件数サマリを報告する。破損ファイルがあれば「再取得が必要」と明示し、各変換経路のトレードオフを一言添える: reflowable 化/`--pdf-to-epub` のトレードオフ(見開き→ページ送り)、`--pdf-spread` のトレードオフ(見開き対応だが横画面・端末依存／縦画面は単ページが仕様)、PDF の Send-to-Kindle 制約(既定の Title メタ付与では E-Ink はダウンロード前に表紙が出ない/`--pdf-to-epub` または `--pdf-spread` なら回避)。スキャン画像 PDF で「Kindle で見開き表示にしたい」と相談された場合は `--pdf-spread` を付けて実行する。`--pdf-spread` の WARNING 行(見開きズレ・Pillow 不在)があれば内容を説明し、必要に応じて `--page-direction` 明示の再実行を案内する。
