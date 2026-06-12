#!/usr/bin/env bash
# 指定フォルダ配下の EPUB / PDF を走査し、Kindle / Finder で表紙サムネイルが
# 出ない原因を是正するスクリプト。
#
# EPUB: 固定レイアウト(fixed-layout / pre-paginated / comic)の EPUB は Kindle の
#       カバー生成や macOS QuickLook がサムネイルを作れず表紙が真っ黒になる。
#       Calibre の ebook-convert で reflowable に再生成し表紙宣言を正規化する。
# PDF : PDF には EPUB のような「表紙メタの枠」が無く、Kindle はサムネを 1 ページ目の
#       描画から生成する。Title メタが空だとカタログ登録/サムネ生成が不安定なため、
#       Calibre の ebook-meta で Title をファイル名から付与する(lossless・本文不変)。
#
# 注意(PDF): Send to Kindle で送った個人ドキュメント(PDOC)は、E-Ink 端末では仕様上
#       "ダウンロード前" のライブラリ一覧に表紙を出さない(ロック画面/スマホアプリでは出る)。
#       これは Kindle 側の制約で、ファイル側では解消できない。
#
# 依存: Calibre (ebook-convert / ebook-meta)。PDF のスキップ判定に pdfinfo(poppler)
#       があれば使用する(無くても動作)。
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: epub-fix-cover.sh [OPTIONS] <FOLDER>

<FOLDER> 配下(再帰)のすべての .epub / .pdf を走査し、Kindle/Finder で表紙
サムネイルが出ない原因を是正します。

EPUB:
  固定レイアウト(pre-paginated)EPUB を reflowable に変換し表紙宣言を正規化。
  スキップ条件: 固定レイアウトでない かつ cover 宣言あり(= 既に表紙が出る状態)。
PDF:
  Title メタが空の PDF にファイル名由来の Title を付与(lossless・本文不変)。
  スキップ条件: 既に Title メタが設定済み。

Arguments:
  FOLDER          走査するフォルダ(必須)

Options:
  --no-backup     原本の .bak バックアップを作成しない
  --dry-run       変換/付与せず、対象/スキップの判定だけ表示する
  -h, --help      このヘルプを表示

挙動:
  - 原本は同じ場所に "<name>.bak" として退避(--no-backup で無効化)
  - EPUB の reflowable 化により見開き表示は1ページずつになります(全ページ・画像は保全)
  - 破損して開けないファイルは警告を出してスキップします
EOF
}

# ---- 引数解析 ----
NO_BACKUP=0
DRY_RUN=0
FOLDER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-backup) NO_BACKUP=1; shift ;;
    --dry-run)   DRY_RUN=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    -*)          echo "不明なオプション: $1" >&2; usage; exit 1 ;;
    *)           FOLDER="$1"; shift ;;
  esac
done

if [ -z "$FOLDER" ]; then
  echo "エラー: フォルダを指定してください" >&2
  usage
  exit 1
fi
if [ ! -d "$FOLDER" ]; then
  echo "エラー: フォルダが存在しません: $FOLDER" >&2
  exit 1
fi

# ---- 依存チェック ----
if ! command -v ebook-convert >/dev/null 2>&1 || ! command -v ebook-meta >/dev/null 2>&1; then
  echo "エラー: Calibre の ebook-convert / ebook-meta が見つかりません。" >&2
  echo "  Calibre をインストールしてください (例: brew install --cask calibre)" >&2
  echo "  インストール済みなら PATH を通してください" >&2
  echo "  (macOS 例: /Applications/calibre.app/Contents/MacOS)" >&2
  exit 1
fi

# ---- EPUB 用ヘルパ ----
opf_path() {
  unzip -p "$1" META-INF/container.xml 2>/dev/null \
    | grep -o 'full-path="[^"]*"' | head -1 | sed 's/full-path="//;s/"//'
}
is_fixed_layout() {
  local opf; opf="$(opf_path "$1")"
  [ -z "$opf" ] && return 1
  unzip -p "$1" "$opf" 2>/dev/null | grep -qiE 'pre-paginated|fixed-layout'
}
has_cover() {
  local opf; opf="$(opf_path "$1")"
  [ -z "$opf" ] && return 1
  unzip -p "$1" "$opf" 2>/dev/null | grep -qiE 'name="cover"|cover-image'
}
image_count() {
  local n
  n="$(unzip -l "$1" 2>/dev/null | grep -ciE '\.(jpg|jpeg|png|gif)' || true)"
  echo "${n:-0}"
}

# ---- PDF 用ヘルパ ----
# pdfinfo があれば /Title を返す(無ければ空)。pdfinfo 非導入時は空扱い。
pdf_title() {
  command -v pdfinfo >/dev/null 2>&1 || { echo ""; return; }
  pdfinfo "$1" 2>/dev/null | sed -n 's/^Title:[[:space:]]*//p'
}
pdf_pages() {
  command -v pdfinfo >/dev/null 2>&1 || { echo ""; return; }
  pdfinfo "$1" 2>/dev/null | awk '/^Pages:/{print $2}'
}

# ---- カウンタ ----
processed=0; skipped=0; broken=0; failed=0; total=0

# ---- EPUB 1冊処理 ----
process_epub() {
  local f="$1" name="$2"
  if ! unzip -t "$f" >/dev/null 2>&1; then
    echo "🔴 破損(スキップ): $name"; broken=$((broken+1)); return
  fi
  # スキップ: 固定レイアウトでない かつ cover 宣言あり
  if ! is_fixed_layout "$f" && has_cover "$f"; then
    echo "⏭️  スキップ(表紙設定済): $name"; skipped=$((skipped+1)); return
  fi
  if [ "$DRY_RUN" = "1" ]; then
    echo "🔧 変換対象(dry-run): $name"; processed=$((processed+1)); return
  fi
  local tmp out; tmp="$(mktemp -d)"; out="$tmp/out.epub"
  if ! ebook-convert "$f" "$out" >/dev/null 2>&1; then
    echo "⚠️  変換失敗(スキップ): $name"; rm -rf "$tmp"; failed=$((failed+1)); return
  fi
  local orig_imgs new_imgs; orig_imgs="$(image_count "$f")"; new_imgs="$(image_count "$out")"
  if ! unzip -t "$out" >/dev/null 2>&1 \
     || is_fixed_layout "$out" \
     || [ "$new_imgs" -lt $((orig_imgs - 3)) ]; then
    echo "⚠️  検証失敗(原本保持): $name (img: ${orig_imgs}→${new_imgs})"
    rm -rf "$tmp"; failed=$((failed+1)); return
  fi
  if [ "$NO_BACKUP" = "0" ] && [ ! -f "$f.bak" ]; then cp "$f" "$f.bak"; fi
  mv "$out" "$f"; rm -rf "$tmp"
  echo "✅ EPUB変換: $name (img: ${new_imgs}枚, 固定レイアウト除去)"
  processed=$((processed+1))
}

# ---- PDF 1冊処理 ----
process_pdf() {
  local f="$1" name="$2"
  # スキップ: 既に Title メタ設定済み
  local cur_title; cur_title="$(pdf_title "$f")"
  if [ -n "$cur_title" ]; then
    echo "⏭️  スキップ(メタ設定済): $name"; skipped=$((skipped+1)); return
  fi
  if [ "$DRY_RUN" = "1" ]; then
    echo "🔧 メタ付与対象(dry-run): $name"; processed=$((processed+1)); return
  fi
  local pages_before; pages_before="$(pdf_pages "$f")"
  if [ "$NO_BACKUP" = "0" ] && [ ! -f "$f.bak" ]; then cp "$f" "$f.bak"; fi
  local title="${name%.*}"
  if ! ebook-meta "$f" --title "$title" >/dev/null 2>&1; then
    echo "⚠️  メタ付与失敗: $name"; failed=$((failed+1)); return
  fi
  # 検証: ページ数が保たれているか(pdfinfo がある場合のみ)
  local pages_after; pages_after="$(pdf_pages "$f")"
  if [ -n "$pages_before" ] && [ -n "$pages_after" ] && [ "$pages_before" != "$pages_after" ]; then
    echo "⚠️  ページ数変化 検証失敗(原本復元): $name (${pages_before}→${pages_after})"
    [ -f "$f.bak" ] && cp "$f.bak" "$f"
    failed=$((failed+1)); return
  fi
  echo "✅ PDFメタ付与: $name (Title設定${pages_after:+, ${pages_after}ページ})"
  processed=$((processed+1))
}

# ---- メイン: null 区切りで再帰列挙(スペース/日本語ファイル名対応) ----
while IFS= read -r -d '' f; do
  total=$((total+1))
  name="$(basename "$f")"
  case "$(printf '%s' "$f" | tr 'A-Z' 'a-z')" in
    *.epub) process_epub "$f" "$name" ;;
    *.pdf)  process_pdf  "$f" "$name" ;;
  esac
done < <(find "$FOLDER" -type f \( -iname '*.epub' -o -iname '*.pdf' \) ! -iname '*.bak' -print0)

# ---- サマリ ----
echo ""
echo "===== 完了 ====="
echo "  走査: $total 冊"
if [ "$DRY_RUN" = "1" ]; then
  echo "  対象: $processed 冊 / スキップ: $skipped 冊 / 破損: $broken 冊"
  echo "  (dry-run のため実処理は行っていません)"
else
  echo "  処理: $processed 冊 / スキップ(設定済): $skipped 冊"
  echo "  破損(要再取得): $broken 冊 / 失敗: $failed 冊"
  [ "$NO_BACKUP" = "0" ] && echo "  原本は各 .bak に退避済み(不要なら削除可)"
fi
