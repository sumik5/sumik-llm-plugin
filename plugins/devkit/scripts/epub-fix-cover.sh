#!/usr/bin/env bash
# 指定フォルダ配下の EPUB / PDF を走査し、Kindle / Finder で表紙サムネイルが
# 出ない原因を是正するスクリプト。
#
# EPUB: 固定レイアウト(fixed-layout / pre-paginated / comic)の EPUB は Kindle の
#       カバー生成や macOS QuickLook がサムネイルを作れず表紙が真っ黒になる。
#       Calibre の ebook-convert で reflowable に再生成し表紙宣言を正規化する。
# PDF : PDF には EPUB のような「表紙メタの枠」が無く、Kindle はサムネを 1 ページ目の
#       描画から生成する。Title メタが空だとカタログ登録/サムネ生成が不安定なため、
#       既定では Calibre の ebook-meta で Title をファイル名から付与する(lossless・本文不変)。
#
#       --pdf-to-epub 指定時は、PDF を「1ページ=1画像=1画面」の reflowable EPUB へ
#       再構成する(OCR は行わず、pdftoppm で各ページを画像化するだけ。大判スキャンや
#       低速な外部ボリュームでの遅さは OCR ではなく画像化の I/O による)。Kindle の PDF
#       ビューアは PDF を固定サイズで描画するため、E-Ink の小画面ではページが収まらず
#       「見開きにならない/下にスクロールしないと全体が見えない」状態になる。各ページを
#       画像化し画面フィット(max-width/height:100%)の XHTML 1 枚ずつに収めた EPUB に
#       すると、各ページが画面にフィットしページ送りで読める。表紙は Kindle/KFX が確実に
#       認識できるよう4機構を併用して宣言する: (1)metadata の <meta name="cover">、
#       (2)カバー画像の properties="cover-image"、(3)専用 cover.xhtml(SVG 全画面ラップ・
#       epub:type="cover")、(4)EPUB2 <guide><reference type="cover">。スキャン画像書籍の
#       Kindle 最適化に有効。
#
# 注意(PDF): Send to Kindle で送った個人ドキュメント(PDOC)は、E-Ink 端末では仕様上
#       "ダウンロード前" のライブラリ一覧に表紙を出さない(ロック画面/スマホアプリでは出る)。
#       これは Kindle 側の制約で、ファイル側では解消できない。--pdf-to-epub で生成した
#       EPUB は PDOC ではなく電子書籍として扱われるため、この制約を回避できる。
#
# 依存: Calibre (ebook-convert / ebook-meta)。PDF のスキップ判定に pdfinfo(poppler)
#       があれば使用する(無くても動作)。--pdf-to-epub には pdftoppm(poppler) と
#       python3 が必須(画像フィット判定に Pillow があれば使用、無くても動作)。
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: epub-fix-cover.sh [OPTIONS] <FOLDER>

<FOLDER> 配下(再帰)のすべての .epub / .pdf を走査し、Kindle/Finder で表紙
サムネイルが出ない原因を是正します。

EPUB:
  固定レイアウト(pre-paginated)EPUB を reflowable に変換し表紙宣言を正規化。
  スキップ条件: 固定レイアウトでない かつ cover 宣言あり(= 既に表紙が出る状態)。
PDF (既定):
  Title メタが空の PDF にファイル名由来の Title を付与(lossless・本文不変)。
  スキップ条件: 既に Title メタが設定済み。
PDF (--pdf-to-epub 指定時):
  PDF を「1ページ=1画像=1画面」の reflowable EPUB(同名 .epub)へ再構成。
  Kindle で各ページが画面にフィット(スクロール不要)・ページ送り可・表紙が出る。
  元 PDF は残し(--replace-pdf 指定時のみ .bak へ退避し PDF を削除)、.epub を併置。
  スキャン画像書籍(画像 PDF・OCR 付きスキャン PDF)の Kindle 最適化に有効。

Arguments:
  FOLDER          走査するフォルダ(必須)。単一の .epub / .pdf ファイル指定も可。

Options:
  --no-backup     原本の .bak バックアップを作成しない
  --dry-run       変換/付与せず、対象/スキップの判定だけ表示する
  --pdf-to-epub   PDF を Title 付与でなく画像ページ EPUB へ変換する(上記参照)
  --pdf-epub-dpi N  --pdf-to-epub のページ画像解像度(既定 200)
  --replace-pdf   --pdf-to-epub 成功時に元 PDF を .bak 退避して削除する
  -h, --help      このヘルプを表示

挙動:
  - 原本は同じ場所に "<name>.bak" として退避(--no-backup で無効化)
  - EPUB の reflowable 化により見開き表示は1ページずつになります(全ページ・画像は保全)
  - --pdf-to-epub も同様に各ページが1画面ずつ(見開き→ページ送り)になります
  - 破損して開けないファイルは警告を出してスキップします
EOF
}

# ---- 引数解析 ----
NO_BACKUP=0
DRY_RUN=0
PDF_TO_EPUB=0
REPLACE_PDF=0
PDF_EPUB_DPI=200
FOLDER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-backup)    NO_BACKUP=1; shift ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --pdf-to-epub)  PDF_TO_EPUB=1; shift ;;
    --replace-pdf)  REPLACE_PDF=1; shift ;;
    --pdf-epub-dpi) PDF_EPUB_DPI="${2:-200}"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    -*)             echo "不明なオプション: $1" >&2; usage; exit 1 ;;
    *)              FOLDER="$1"; shift ;;
  esac
done

if [ -z "$FOLDER" ]; then
  echo "エラー: フォルダまたはファイルを指定してください" >&2
  usage
  exit 1
fi
# フォルダでもファイル(.epub/.pdf)でも受け付ける
if [ ! -d "$FOLDER" ] && [ ! -f "$FOLDER" ]; then
  echo "エラー: 指定パスが存在しません: $FOLDER" >&2
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
if [ "$PDF_TO_EPUB" = "1" ]; then
  if ! command -v pdftoppm >/dev/null 2>&1; then
    echo "エラー: --pdf-to-epub には pdftoppm(poppler) が必要です。" >&2
    echo "  例: brew install poppler" >&2
    exit 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "エラー: --pdf-to-epub には python3 が必要です。" >&2
    exit 1
  fi
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
pdf_author() {
  command -v pdfinfo >/dev/null 2>&1 || { echo ""; return; }
  pdfinfo "$1" 2>/dev/null | sed -n 's/^Author:[[:space:]]*//p'
}

# ---- 画像ページ EPUB ビルダ(python3 へ heredoc で渡す) ----
# 連番ページ画像(page-*.jpg)から「1ページ=1画像=1画面」の reflowable EPUB を生成。
# 各ページは max-width/height:100% で画面にフィット(スクロール不要)、1ページ目を
# 表紙(cover-image)として宣言する。
BUILD_IMAGE_EPUB_PY="$(cat << 'PYEOF'
import sys, os, glob, zipfile, html, uuid
from datetime import datetime, timezone
img_dir, out_epub, title = sys.argv[1], sys.argv[2], sys.argv[3]
author = sys.argv[4] if len(sys.argv) > 4 else ""
imgs = sorted(glob.glob(os.path.join(img_dir, "page-*.jpg")))
if not imgs:
    print("ERROR: no page images", file=sys.stderr); sys.exit(2)
book_id = "urn:uuid:" + str(uuid.uuid4())
mod = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
try:
    from PIL import Image
    w, h = Image.open(imgs[0]).size
except Exception:
    w, h = 1200, 1700
z = zipfile.ZipFile(out_epub, "w", zipfile.ZIP_DEFLATED)
z.writestr(zipfile.ZipInfo("mimetype"), "application/epub+zip", compress_type=zipfile.ZIP_STORED)
z.writestr("META-INF/container.xml",
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
    '  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>\n'
    '</container>\n')
z.writestr("OEBPS/style.css",
    "@page { margin: 0; padding: 0; }\n"
    "html, body { margin: 0; padding: 0; height: 100%; text-align: center; background: #fff; }\n"
    "div.page { margin: 0; padding: 0; page-break-after: always; text-align: center; }\n"
    "img.full { display: block; margin: 0 auto; max-width: 100%; max-height: 100%; "
    "width: auto; height: auto; object-fit: contain; }\n")
manifest, spine = [], []
for i, src in enumerate(imgs, 1):
    img_name, xhtml_name = "images/p%04d.jpg" % i, "p%04d.xhtml" % i
    z.write(src, "OEBPS/" + img_name)
    props = ' properties="cover-image"' if i == 1 else ""
    manifest.append('<item id="img%04d" href="%s" media-type="image/jpeg"%s/>' % (i, img_name, props))
    manifest.append('<item id="pg%04d" href="%s" media-type="application/xhtml+xml"/>' % (i, xhtml_name))
    spine.append('<itemref idref="pg%04d"/>' % i)
    z.writestr("OEBPS/" + xhtml_name,
        '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja">\n'
        '<head><meta charset="utf-8"/><title>%d</title>\n'
        '<meta name="viewport" content="width=%d, height=%d"/>\n'
        '<link rel="stylesheet" type="text/css" href="style.css"/></head>\n'
        '<body><div class="page"><img class="full" src="%s" alt="page %d"/></div></body>\n'
        '</html>\n' % (i, w, h, img_name, i))
z.writestr("OEBPS/cover.xhtml",
    '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n'
    '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja">\n'
    '<head><meta charset="utf-8"/><title>Cover</title>\n'
    '<meta name="viewport" content="width=%d, height=%d"/>\n'
    '<style type="text/css">html,body{margin:0;padding:0;height:100%%;}svg{display:block;width:100%%;height:100%%;}</style></head>\n'
    '<body epub:type="cover"><svg xmlns="http://www.w3.org/2000/svg" '
    'xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" '
    'width="100%%" height="100%%" viewBox="0 0 %d %d" preserveAspectRatio="xMidYMid meet">\n'
    '<image width="%d" height="%d" xlink:href="images/p0001.jpg"/>\n'
    '</svg></body></html>\n' % (w, h, w, h, w, h))
z.writestr("OEBPS/nav.xhtml",
    '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n'
    '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja">\n'
    '<head><meta charset="utf-8"/><title>目次</title></head>\n<body>\n'
    '<nav epub:type="toc" id="toc"><h1>目次</h1><ol><li><a href="p0001.xhtml">先頭</a></li></ol></nav>\n'
    '</body></html>\n')
manifest.append('<item id="coverpage" href="cover.xhtml" media-type="application/xhtml+xml" properties="svg"/>')
manifest.append('<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>')
manifest.append('<item id="css" href="style.css" media-type="text/css"/>')
spine_xml = '<itemref idref="coverpage" linear="no"/>\n' + "\n".join(spine)
z.writestr("OEBPS/content.opf",
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">\n'
    '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
    '<dc:identifier id="bookid">%s</dc:identifier>\n<dc:title>%s</dc:title>\n<dc:language>ja</dc:language>\n%s'
    '<meta property="dcterms:modified">%s</meta>\n<meta name="cover" content="img0001"/>\n</metadata>\n'
    '<manifest>\n%s\n</manifest>\n<spine>\n%s\n</spine>\n<guide>\n<reference type="cover" title="Cover" href="cover.xhtml"/>\n</guide>\n</package>\n'
    % (book_id, html.escape(title),
       ('<dc:creator>%s</dc:creator>\n' % html.escape(author)) if author else "",
       mod, "\n".join(manifest), spine_xml))
z.close()
print("OK pages=%d" % len(imgs))
PYEOF
)"

# ---- カウンタ ----
processed=0; skipped=0; broken=0; failed=0; total=0; backups=0

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
  if [ "$NO_BACKUP" = "0" ] && [ ! -f "$f.bak" ]; then cp "$f" "$f.bak"; backups=$((backups+1)); fi
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
  if [ "$NO_BACKUP" = "0" ] && [ ! -f "$f.bak" ]; then cp "$f" "$f.bak"; backups=$((backups+1)); fi
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

# ---- PDF → 画像ページ EPUB 変換(--pdf-to-epub) ----
# PDF を「1ページ=1画像=1画面」の reflowable EPUB(同名 .epub)へ再構成する。
# Kindle で各ページが画面にフィットしページ送りで読めるようにする。
process_pdf_to_epub() {
  local f="$1" name="$2"
  local base="${f%.*}" dst="${f%.*}.epub"
  # スキップ: 同名 .epub が既に存在
  if [ -f "$dst" ]; then
    echo "⏭️  スキップ(EPUB既存): $name"; skipped=$((skipped+1)); return
  fi
  if [ "$DRY_RUN" = "1" ]; then
    echo "🔧 PDF→EPUB変換対象(dry-run): $name"; processed=$((processed+1)); return
  fi
  local pages_before; pages_before="$(pdf_pages "$f")"
  local tmp; tmp="$(mktemp -d)"
  # 各ページを連番 JPEG に描画(日本語/スペースのパスに対応)
  if ! pdftoppm -jpeg -r "$PDF_EPUB_DPI" "$f" "$tmp/page" >/dev/null 2>&1; then
    echo "🔴 破損/描画失敗(スキップ): $name"; rm -rf "$tmp"; broken=$((broken+1)); return
  fi
  local n; n="$(find "$tmp" -name 'page-*.jpg' | wc -l | tr -d ' ')"
  if [ "${n:-0}" -lt 1 ]; then
    echo "🔴 ページ画像0(スキップ): $name"; rm -rf "$tmp"; broken=$((broken+1)); return
  fi
  local title author; title="$(pdf_title "$f")"; [ -z "$title" ] && title="${name%.*}"
  author="$(pdf_author "$f")"
  if ! python3 -c "$BUILD_IMAGE_EPUB_PY" "$tmp" "$tmp/out.epub" "$title" "$author" >/dev/null 2>&1; then
    echo "⚠️  EPUB生成失敗(スキップ): $name"; rm -rf "$tmp"; failed=$((failed+1)); return
  fi
  # 検証: zip 健全性・ページ数一致(pdfinfo がある場合)
  local epub_pages; epub_pages="$(unzip -l "$tmp/out.epub" 2>/dev/null | grep -c 'p[0-9]*\.xhtml' || true)"
  if ! unzip -t "$tmp/out.epub" >/dev/null 2>&1; then
    echo "⚠️  生成EPUB検証失敗(スキップ): $name"; rm -rf "$tmp"; failed=$((failed+1)); return
  fi
  if [ -n "$pages_before" ] && [ "$pages_before" != "$epub_pages" ]; then
    echo "⚠️  ページ数不一致 検証失敗(スキップ): $name (PDF ${pages_before} → EPUB ${epub_pages})"
    rm -rf "$tmp"; failed=$((failed+1)); return
  fi
  mv "$tmp/out.epub" "$dst"; rm -rf "$tmp"
  if [ "$REPLACE_PDF" = "1" ]; then
    if [ "$NO_BACKUP" = "0" ] && [ ! -f "$f.bak" ]; then cp "$f" "$f.bak"; backups=$((backups+1)); fi
    rm -f "$f"
    echo "✅ PDF→EPUB変換: $name (${epub_pages}ページ, 元PDF削除${NO_BACKUP:+/}$([ "$NO_BACKUP" = "0" ] && echo ".bak退避済"))"
  else
    echo "✅ PDF→EPUB変換: $name (${epub_pages}ページ, .epub併置・元PDF保持)"
  fi
  processed=$((processed+1))
}

# ---- 1ファイル処理ディスパッチ ----
process_one() {
  local f="$1" name; name="$(basename "$f")"
  total=$((total+1))
  case "$(printf '%s' "$f" | tr 'A-Z' 'a-z')" in
    *.epub) process_epub "$f" "$name" ;;
    *.pdf)
      if [ "$PDF_TO_EPUB" = "1" ]; then process_pdf_to_epub "$f" "$name"
      else process_pdf "$f" "$name"; fi ;;
  esac
}

# ---- メイン: 単一ファイル指定 or フォルダ再帰列挙(スペース/日本語ファイル名対応) ----
if [ -f "$FOLDER" ]; then
  case "$(printf '%s' "$FOLDER" | tr 'A-Z' 'a-z')" in
    *.epub|*.pdf) process_one "$FOLDER" ;;
    *) echo "エラー: .epub / .pdf ファイルを指定してください: $FOLDER" >&2; exit 1 ;;
  esac
else
  while IFS= read -r -d '' f; do
    process_one "$f"
  done < <(find "$FOLDER" -type f \( -iname '*.epub' -o -iname '*.pdf' \) ! -iname '*.bak' -print0)
fi

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
  [ "$backups" -gt 0 ] && echo "  原本 $backups 件を .bak に退避済み(不要なら削除可)"
fi
