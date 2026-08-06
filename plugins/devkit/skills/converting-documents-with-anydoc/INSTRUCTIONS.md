# anydoc によるドキュメント変換

## (1) 概要

[firecrawl/anydoc](https://github.com/firecrawl/anydoc)（MIT・Rust製・APIキー不要・ローカル完結）を使い、Word・PowerPoint・Excel・OpenDocument・RTF・CSV・PDFファイルを GitHub Flavored Markdown へ変換する。既存の `pandoc` / `pdf-to-markdown` が対応しない旧Office形式（`.doc` / `.ppt` / `.xls` / `.ods` 等）で**唯一の選択肢**になる点、および Office 全般・PDF・EPUB・CSV を単一ツールで統一的に Markdown 化できる点に価値がある。

## (2) クイックスタート

```bash
# CLI単発実行（エージェントからの主用途・Node.js 20+必須）
npx -y @firecrawl/anydoc@0.1.6 <input-file> -o <output>.md

# Node.js コードへの組み込み
npm install @firecrawl/anydoc

# Python コードへの組み込み
pip install firecrawl-anydoc

# Rust コードへの組み込み
cargo add anydoc
```

## (3) 対応形式・既存ツールとの使い分け（実機確認済み）

| ソース種別 | pandoc/pdf-to-markdownの対応状況 | anydocの位置づけ |
|-----------|----------------------------------|-------------------|
| Word（.doc/.docx/.docm） | pandoc: `.docx`のみ対応 | `.doc`/`.docm`はanydocが**唯一の選択肢**。`.docx`は比較対象 |
| PowerPoint（.ppt/.pps/.pot/.pptx/.pptm/.ppsx/.ppsm） | pandoc: `.pptx`対応（3.8.3以降） | `.ppt`/`.pps`/`.pot`/`.pptm`/`.ppsx`/`.ppsm`はanydocが**唯一の選択肢**。`.pptx`は比較対象 |
| Excel（.xls/.xlsx/.xlsm/.xlsb） | pandoc: `.xlsx`対応（3.8.3以降）。`.xls`/`.xlsm`/`.xlsb`は非対応 | `.xls`/`.xlsm`/`.xlsb`はanydocが**唯一の選択肢**。`.xlsx`は比較対象 |
| OpenDocument（.odt/.ods/.odp） | pandoc: `.odt`のみ対応 | `.ods`/`.odp`はanydocが**唯一の選択肢** |
| RTF/CSV/EPUB（テキストベース）/PDF（テキストベース） | 既存ツール対応済み | 既存ツールとの比較対象。機械的置換はしない（表構造・レイアウト再現に懸念がある場合のみanydocでも変換し目視比較） |
| 画像ベース（スキャン）PDF/EPUB/画像 | — | 🔴 anydocはOCR非対応のためスコープ外。Apple Vision（第一選択）→ローカルVLM（フォールバック） |

**anydocが唯一の選択肢となる形式（Node未達時にフォールバック先が存在しない・13形式）:**
`.doc` / `.docm` / `.ppt` / `.pps` / `.pot` / `.pptm` / `.ppsx` / `.ppsm` / `.xls` / `.xlsm` / `.xlsb` / `.ods` / `.odp`

## (4) 🔴 OCR非対応（重要）

anydocはOCRを行わない。画像ベース（スキャン）のPDF・EPUB・画像はスコープ外で、変換は失敗する（終了コード非0）。実機確認済みのエラー例（`fixtures/scanned.pdf` を入力した場合）:

```
anydoc: unsupported input: PDF has no extractable text (Scanned, 1 pages): OCR is required
```

スキャン教材の変換には、既存のApple Vision（第一選択）→ローカルVLM（フォールバック）ワークフローを使う（詳細は `certificate:creating-flashcards` を参照）。

## (5) CLIとライブラリの区別・バージョン固定・Node preflight

| 用途 | 手段 | コマンド/呼出例 |
|------|------|-----------------|
| **エージェントからの単発ファイル変換**（主用途） | `npx`によるCLI実行（Node.js 20+必須） | `npx -y @firecrawl/anydoc@0.1.6 <input> -o <output>.md` |
| Node.js/Python/Rustコードへの組み込み | npm `@firecrawl/anydoc` / PyPI `firecrawl-anydoc` / crates.io `anydoc` | 各言語の`to_markdown`/`toMarkdown` API |

- 🔴 **バージョン固定**: `@firecrawl/anydoc@0.1.6`（2026-08-06時点の公式最新リリース。anydocのメジャーバージョンアップ時はこの値とupstream skillとの差分を確認する）
- 🔴 `npx -y`は初回実行時にネットワーク接続とパッケージダウンロードを要する（2回目以降キャッシュ済みならオフライン動作）
- 入力形式はファイル内容から自動検出される。検出が働かない場合（stdin経由のCSV、拡張子欠落・誤り）のみ `-f/--format` で明示指定する
- **終了コード契約**（upstream CLI契約）: `0`=成功／`1`=変換不可（読み込み不可・OCR要・暗号化等）／`2`=usage error

### `convert_with_anydoc` シェル関数（Node preflight＋終了コード分岐）

```bash
convert_with_anydoc() {
  local input_file="$1" output_path="$2"
  local node_major
  node_major="$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)"
  if [ -z "$node_major" ] || [ "$node_major" -lt 20 ]; then
    echo "SKIP: Node.js 20+ not found (anydoc-only format, no fallback) for $input_file" >&2
    return 10   # Node未達を表す専用の戻り値。呼び出し側がこれを見て失敗記録する
  fi
  npx -y "@firecrawl/anydoc@0.1.6" "$input_file" -o "$output_path"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "SKIP: anydoc exited $rc for $input_file" >&2
    return "$rc"
  fi
  return 0
}
```

呼び出し側は `convert_with_anydoc "<file>" "<out>.md" || record_conversion_failure "<file>" "$?"` のように**戻り値を必ず捕捉**する。

**関数戻り値の契約**: `0`=成功／`10`=Node未達（anydoc専用形式でフォールバック不可）／その他非0=anydoc自体の失敗（画像のみPDF・暗号化ファイル等は非0で失敗）。

## (6) 受入テスト結果（`fixtures/` で実機検証済み）

| fixture | 実行コマンド | 実測結果 | 判定 |
|---------|-------------|----------|------|
| `fixtures/sample.doc` | `convert_with_anydoc fixtures/sample.doc out.md` | rc=0。出力Markdownは`# Sample Heading`見出しと本文段落を含む | ✅ 期待通り |
| `fixtures/sample.xls` | 同上 | rc=0。出力MarkdownはGFMテーブルで`Name`/`Value`/`Widget`/`42`を含む | ✅ 期待通り |
| `fixtures/sample.ods` | 同上 | rc=0。sample.xlsと同一のGFMテーブル出力 | ✅ 期待通り |
| `fixtures/scanned.pdf`（画像のみPDF） | 同上 | rc=1。`anydoc: unsupported input: PDF has no extractable text (Scanned, 1 pages): OCR is required` | ✅ 期待通り（非0で失敗・OCR要求メッセージ） |
| `fixtures/embedded-image.docx`（図表1点） | 同上 | rc=0。画像はalt text（`Sample chart`）のみで、画像自体の視覚情報は出力Markdownに含まれない | ✅ 期待通り（視覚情報欠落を確認） |
| `fixtures/encrypted.docx`（パスワード保護） | 同上 | rc=1。`anydoc: document is encrypted` | ✅ 期待通り（非0で失敗・暗号化検知メッセージ） |
| `fixtures/mixed/a/b/report.doc`・`fixtures/mixed/a_b/report.doc`・`fixtures/mixed/a/report.xls`（単一root内の衝突ケース） | `input-<index>`＋相対ディレクトリ構造保持＋元拡張子維持方式でシミュレーション変換 | それぞれ `input-0/a/b/report.doc.md`・`input-0/a_b/report.doc.md`・`input-0/a/report.xls.md` に分離され、3ファイルとも異なる出力パスになることを確認 | ✅ 期待通り（衝突なし） |
| `fixtures/mixed/a/report.doc` と `fixtures/mixed2/a/report.doc`（複数入力root間の同一相対パス） | 同上（`fixtures/mixed`=input-0、`fixtures/mixed2`=input-1） | `input-0/a/report.doc.md` と `input-1/a/report.doc.md` に分離され、複数root間でも衝突しないことを確認 | ✅ 期待通り（衝突なし） |

フォルダ入力の一括変換ワークフロー（`<input-index>`namespace方式の実運用）は `authoring-plugins` の Phase 0/A.1/A.2 を参照。

## (7) upstream出典

| 項目 | 値 |
|------|-----|
| upstream repository | <https://github.com/firecrawl/anydoc> |
| 翻案元ファイル | `skills/convert-documents-to-markdown/SKILL.md` |
| 出典URL | <https://github.com/firecrawl/anydoc/blob/main/skills/convert-documents-to-markdown/SKILL.md> |
| anydocバージョン | v0.1.6（2026-08-06時点の公式最新リリースであることを確認済み） |
| 翻案元ファイルのcommit SHA | `2fc6c7ac5a4e60403eb7e2967dd631cd6c2ee95c`（v0.1.6タグが指すcommitと一致確認済み） |
| 取得日 | 2026-08-06 |
| ライセンス | MIT（`LICENSE.anydoc` に全文同梱） |

**upstream更新の追従**: anydocのメジャーバージョンアップ時はupstream skillとの差分を確認すること。

**改変・再構成した範囲**: 命名規則準拠のリネーム、日本語化、既存ツールとの使い分け表の追加、クロスプラグイン参照の追加。upstream本文の対応形式表・CLI仕様・OCR非対応警告（終了コード契約含む）は忠実に引き継いだ。

## (8) 関連スキル

- スキャン教材からフラッシュカードを作る場合は `certificate:creating-flashcards` を使う（Apple Vision/ローカルVLM OCRワークフロー）
- フォルダ・複数ファイル入力の一括変換ワークフローは `authoring-plugins`（Phase 0以降）を参照
