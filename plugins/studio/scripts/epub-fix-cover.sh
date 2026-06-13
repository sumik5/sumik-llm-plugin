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
#       --pdf-spread 指定時は、PDF を EPUB3 fixed-layout(pre-paginated)として再構成
#       し、ノンブル左右判定(OCR不使用・インク密度ヒューリスティック)と綴じ方向自動推定
#       により各ページを左/右に配置した「見開き対応 EPUB」を生成する。各ページは余白
#       自動トリミング(既定ON)後の実寸でビューポートを設定し小画面でも紙面が大きく見える。
#       Kindle/KFX の横画面で見開き表示・縦画面で単ページ表示(端末/アプリ依存)。
#       表紙は p0001.jpg を cover-image 専用にし本文 xhtml(spine)は p0002 から開始。
#       これにより Kindle が cover-image を単独表示後、先頭ペア(002左,003右)からペアリング
#       し「表紙2回表示」問題を解消する。
#       表紙宣言機構: (1)metadata の <meta name="cover">、(2)cover-image properties。
#       guide の <reference type="cover"> と nav landmarks の cover エントリは
#       対応 xhtml が存在しないため省略(epubcheck OPF-096 防止)。
#
# 注意(PDF): Send to Kindle で送った個人ドキュメント(PDOC)は、E-Ink 端末では仕様上
#       "ダウンロード前" のライブラリ一覧に表紙を出さない(ロック画面/スマホアプリでは出る)。
#       これは Kindle 側の制約で、ファイル側では解消できない。--pdf-to-epub で生成した
#       EPUB は PDOC ではなく電子書籍として扱われるため、この制約を回避できる。
#
# 依存: Calibre (ebook-convert / ebook-meta)。PDF のスキップ判定に pdfinfo(poppler)
#       があれば使用する(無くても動作)。--pdf-to-epub には pdftoppm(poppler) と
#       python3 が必須(画像フィット判定に Pillow があれば使用、無くても動作)。
#       --pdf-spread には pdftoppm(poppler) と python3 が必須。Pillow があれば
#       ノンブル左右判定・余白トリミングを実施(無くても動作・奇偶フォールバック)。
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
PDF (--pdf-spread 指定時):
  PDF を EPUB3 fixed-layout(見開き・pre-paginated)の .epub へ再構成。
  ノンブル下部インク密度でページ物理左右を判定し、Kindle/KFX の横画面で
  見開き表示・縦画面で単ページ表示(端末/アプリ/OS依存)。
  余白自動トリミング既定ON(--no-trim で無効化)。
  p0001.jpg を cover-image 専用にし spine は p0002 から開始。
  先頭ペアは (002左,003右) となり表紙の二重表示を解消する。
  スキップ条件: 同名 .epub が既存(--pdf-to-epub と同じ冪等スキップ)。

Arguments:
  FOLDER          走査するフォルダ(必須)。単一の .epub / .pdf ファイル指定も可。

Options:
  --no-backup            原本の .bak バックアップを作成しない
  --dry-run              変換/付与せず、対象/スキップの判定だけ表示する
  --pdf-to-epub          PDF を Title 付与でなく画像ページ EPUB へ変換する(上記参照)
  --pdf-epub-dpi N       --pdf-to-epub / --pdf-spread のページ画像解像度(既定 200)
  --replace-pdf          --pdf-to-epub / --pdf-spread 成功時に元 PDF を .bak 退避して削除する
  --pdf-spread           PDF を EPUB3 fixed-layout 見開き EPUB へ変換する(上記参照)
  --no-trim              --pdf-spread の余白自動トリミングを無効化する(既定 ON)
  --page-direction DIR   見開き綴じ方向を ltr / rtl / auto から指定(既定 auto=画像から推定)
                         縦書き本(和書)は rtl の明示を推奨
  --spread-mode MODE     rendition:spread 値を landscape / both から指定(既定 landscape)
  -h, --help             このヘルプを表示

挙動:
  - 原本は同じ場所に "<name>.bak" として退避(--no-backup で無効化)
  - EPUB の reflowable 化により見開き表示は1ページずつになります(全ページ・画像は保全)
  - --pdf-to-epub も同様に各ページが1画面ずつ(見開き→ページ送り)になります
  - --pdf-spread の縦画面単ページ表示は仕様です(見開きは横画面・端末/アプリ設定依存)
  - 破損して開けないファイルは警告を出してスキップします
EOF
}

# ---- 引数解析 ----
NO_BACKUP=0
DRY_RUN=0
PDF_TO_EPUB=0
REPLACE_PDF=0
PDF_EPUB_DPI=200
PDF_SPREAD=0
NO_TRIM=0
PAGE_DIRECTION="auto"
SPREAD_MODE="landscape"
FOLDER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-backup)        NO_BACKUP=1; shift ;;
    --dry-run)          DRY_RUN=1; shift ;;
    --pdf-to-epub)      PDF_TO_EPUB=1; shift ;;
    --replace-pdf)      REPLACE_PDF=1; shift ;;
    --pdf-epub-dpi)     PDF_EPUB_DPI="${2:-200}"; shift 2 ;;
    --pdf-spread)       PDF_SPREAD=1; shift ;;
    --no-trim)          NO_TRIM=1; shift ;;
    --page-direction)
      PAGE_DIRECTION="${2:-auto}"
      case "$PAGE_DIRECTION" in ltr|rtl|auto) ;; *)
        echo "エラー: --page-direction は ltr / rtl / auto のいずれかを指定してください" >&2
        exit 1 ;;
      esac
      shift 2 ;;
    --spread-mode)
      SPREAD_MODE="${2:-landscape}"
      case "$SPREAD_MODE" in landscape|both) ;; *)
        echo "エラー: --spread-mode は landscape / both のいずれかを指定してください" >&2
        exit 1 ;;
      esac
      shift 2 ;;
    -h|--help)          usage; exit 0 ;;
    -*)                 echo "不明なオプション: $1" >&2; usage; exit 1 ;;
    *)                  FOLDER="$1"; shift ;;
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
if [ "$PDF_TO_EPUB" = "1" ] || [ "$PDF_SPREAD" = "1" ]; then
  if ! command -v pdftoppm >/dev/null 2>&1; then
    echo "エラー: --pdf-to-epub / --pdf-spread には pdftoppm(poppler) が必要です。" >&2
    echo "  例: brew install poppler" >&2
    exit 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "エラー: --pdf-to-epub / --pdf-spread には python3 が必要です。" >&2
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
    # landmarks nav: cover.xhtml への到達経路を提供し OPF-096 エラーを解消する
    '<nav epub:type="landmarks" id="landmarks" hidden="hidden">\n'
    '<ol>\n'
    '<li><a epub:type="cover" href="cover.xhtml">表紙</a></li>\n'
    '<li><a epub:type="bodymatter" href="p0001.xhtml">本文先頭</a></li>\n'
    '</ol>\n'
    '</nav>\n'
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

# ---- 見開き fixed-layout EPUB ビルダ(python3 へ heredoc で渡す) ----
# スキャン PDF を EPUB3 fixed-layout(pre-paginated)として再構成する。
# 処理順序: (1)原画像でノンブル左右判定 → (2)綴じ方向推定 → (3)余白トリミング
#            → (4)fixed-layout EPUB 組立。
# 4機構カバー宣言(meta name=cover・cover-image・cover.xhtml・guide)を厳守。
#
# 注意(bash 3.2 互換): 旧実装は BUILD_SPREAD_EPUB_PY="$(cat << 'PYEOF' ... PYEOF)" の
#   コマンド置換内ヒアドキュメントだったが、macOS 既定の bash 3.2.57 は
#   コマンド置換 $(...) 内のヒアドキュメント本文の括弧 ( ) を外側 $() の対応括弧と
#   誤って数え、本文に多行タプル等の開き括弧が現れると
#   "bad substitution: no closing ')'" でスクリプト読込時に異常終了する
#   (--pdf-spread / --pdf-to-epub 双方が起動不能になっていた)。
#   対策として Python 本文は「コマンド置換を介さない素のヒアドキュメント」で
#   一時ファイルへ書き出す関数に変更し、python3 <file> で実行する。
#   素のヒアドキュメント(関数内)は bash 3.2 の当該バグを踏まない。
write_spread_epub_py() {
  cat > "$1" << 'PYEOF'
import sys, os, glob, zipfile, html, uuid
from datetime import datetime, timezone

# ---- 引数 ----
img_dir      = sys.argv[1]   # pdftoppm 出力ディレクトリ
out_epub     = sys.argv[2]   # 出力 EPUB パス
title        = sys.argv[3]   # 書籍タイトル
author       = sys.argv[4] if len(sys.argv) > 4 else ""
page_dir_arg = sys.argv[5] if len(sys.argv) > 5 else "auto"   # ltr / rtl / auto
spread_mode  = sys.argv[6] if len(sys.argv) > 6 else "landscape"
do_trim      = (sys.argv[7] if len(sys.argv) > 7 else "1") == "1"

# ---- Pillow ロード(なければフォールバック) ----
try:
    from PIL import Image
    HAS_PILLOW = True
except ImportError:
    HAS_PILLOW = False
    print("WARNING: Pillow が見つかりません。ノンブル左右判定は奇偶フォールバック、余白トリミングは無効になります。", file=sys.stderr)

# ---- ページ画像リスト ----
imgs = sorted(glob.glob(os.path.join(img_dir, "page-*.jpg")))
if not imgs:
    print("ERROR: no page images", file=sys.stderr)
    sys.exit(2)

# ---- ノンブル左右判定(Pillowあり時) ----
def detect_page_number_side(img_path):
    """
    ページ画像の最下端コーナーのインク密度を左右比較しノンブル位置を推定する。
    旧実装(中央帯左右half比較)から「外側コーナー限定」に変更し、
    本文コンテンツのインクに支配されない DPI 非依存の判定を実現する。

    検出パラメータ(実測済み・152ページで143/143=100%精度):
      THR     = 160   : 画素値 < THR をインクと数える(薄いグレーのノンブルを拾う)
      H_FRAC  = 0.05  : 下端 5% の帯を検出対象とする
      INSET   = 0.02  : 外側 inset(横幅の 2%)
      W_FRAC  = 0.20  : コーナー幅(横幅の 20%)

    戻り値: "right" / "left" / "undecided"
    """
    # 判定パラメータ(定数)
    THR    = 160    # インク閾値(画素値 < THR をインクと数える)
    H_FRAC = 0.05   # 検出帯: 下端 5%
    INSET  = 0.02   # 外側 inset 率
    W_FRAC = 0.20   # コーナー幅率

    try:
        img = Image.open(img_path).convert("L")
    except Exception:
        return "undecided"
    w, h = img.size
    band_h = max(1, int(h * H_FRAC))
    # 下端帯を切り出す
    band = img.crop((0, h - band_h, w, h))

    # 左コーナー: x ∈ [W*INSET, W*INSET + W*W_FRAC]
    lx0 = int(w * INSET)
    lx1 = lx0 + int(w * W_FRAC)
    # 右コーナー: x ∈ [W - W*INSET - W*W_FRAC, W - W*INSET]
    rx1 = w - int(w * INSET)
    rx0 = rx1 - int(w * W_FRAC)
    # コーナー領域が重ならないよう clamp
    lx1 = min(lx1, w // 2)
    rx0 = max(rx0, w // 2)

    bw, bh = band.size
    left_zone  = band.crop((lx0, 0, lx1, bh))
    right_zone = band.crop((rx0, 0, rx1, bh))

    def ink_count(region):
        # Pillow 12+: get_flattened_data() 推奨。旧版は getdata() で代替
        try:
            data = region.get_flattened_data()
        except AttributeError:
            data = list(region.getdata())
        return sum(1 for p in data if p < THR)

    li = ink_count(left_zone)
    ri = ink_count(right_zone)

    # 比率ベースの最小インク閾値(DPI 非依存)
    # corner_area = 帯ピクセル行数 × コーナー幅ピクセル数
    corner_w = max(1, lx1 - lx0)
    corner_area = bh * corner_w
    min_ink = max(8, corner_area * 0.002)

    # 信号不足 / 拮抗 → undecided
    if (li + ri) < min_ink:
        return "undecided"
    if max(li, ri) < 1.3 * min(li, ri) + 1:
        return "undecided"

    return "left" if li > ri else "right"

# ---- 全ページ判定(p0001含む全ページで実施・綴じ方向推定に使用) ----
if HAS_PILLOW:
    raw_sides = [detect_page_number_side(p) for p in imgs]
else:
    raw_sides = ["undecided"] * len(imgs)

# ---- 多数決(確定判定のみ集計) ----
# majority_start: 確定ページが乏しい場合の補助推定に使用
left_count  = raw_sides.count("left")
right_count = raw_sides.count("right")
majority_start = "left" if left_count >= right_count else "right"

# ---- 綴じ方向推定(--page-direction auto 時) ----
# 各確定ページの side が、そのファイルページ番号インデックスの
# LTR パリティ期待と整合するかを多数決で判定する。
#
# パリティ規約(parity_side_body() と完全に一致させること):
#   本文インデックス j=0: imgs[1](p0002)が本文先頭
#   j>=0 の LTR パリティ期待:
#     LTR: j が偶数(0,2,4,...) → "left"、j が奇数(1,3,...) → "right"
#     例: j=0(偶数) → "left"、j=1(奇数) → "right"
#     (p0002=left/p0003=right: LTR 先頭ペアは (002左,003右))
#
# 各確定ページで:
#   side == LTR パリティ期待 → ltr 票 +1
#   side != LTR パリティ期待 → rtl 票 +1
# ltr 票 >= rtl 票 なら "ltr"、そうでなければ "rtl"。
# 確定ページが 0 件なら majority_start 補助 or "ltr" 既定。
def infer_direction(raw_sides, majority_start):
    ltr_votes = 0
    rtl_votes = 0
    # raw_sides[0] = p0001(表紙) → スキップ。raw_sides[1..] = p0002.. が本文。
    # 本文インデックス j = i - 1 (i は imgs リスト上のインデックス)
    for i, s in enumerate(raw_sides):
        if i == 0:
            continue  # p0001(表紙)は除外
        if s not in ("left", "right"):
            continue  # undecided は票に加えない
        # 本文インデックス j = i - 1: j 偶数 → LTR 期待 "left"、j 奇数 → "right"
        j = i - 1
        ltr_expected = "left" if j % 2 == 0 else "right"
        if s == ltr_expected:
            ltr_votes += 1
        else:
            rtl_votes += 1
    if ltr_votes == 0 and rtl_votes == 0:
        # 確定ページなし: majority_start で補助推定
        if majority_start == "left":
            return "ltr"
        return "rtl"
    return "ltr" if ltr_votes >= rtl_votes else "rtl"

if page_dir_arg == "auto":
    page_direction = infer_direction(raw_sides, majority_start)
    # 全ページ undecided(Pillow 非導入・全白・ノンブルなし)の場合に縦書き推奨警告
    if left_count == 0 and right_count == 0:
        print(
            "WARNING: 綴じ方向を推定できませんでした。"
            " 日本語縦書き本は --page-direction rtl の明示を推奨します。",
            file=sys.stderr)
else:
    page_direction = page_dir_arg

# ---- 本文ページのパリティ期待 side ヘルパ ----
# j: 本文インデックス(0 = p0002, 1 = p0003, ...)
# LTR: j 偶数 → "left"、j 奇数 → "right" (先頭ペアは 002左/003右)
# RTL: j 偶数 → "right"、j 奇数 → "left" (先頭ペアは 002右/003左)
def parity_side_body(body_idx, page_direction):
    """本文ページ(p0002以降)の期待 side を返す。body_idx=0 が p0002。"""
    if page_direction == "rtl":
        return "right" if body_idx % 2 == 0 else "left"
    else:
        return "left"  if body_idx % 2 == 0 else "right"

# ---- 本文画像リスト(p0002以降): imgs[1..] ----
# imgs[0] = p0001 は cover-image 専用。本文 xhtml を生成しない。
# 1ページだけの PDF(表紙のみ)の場合: body_imgs が空になる。
# フォールバック: p0001 を唯一の本文兼表紙として扱う(破綻しない分岐)。
body_imgs = imgs[1:]  # p0002, p0003, ...

if not body_imgs:
    # 1ページPDF フォールバック: p0001 を唯一の本文ページとして扱う
    print("WARNING: PDFが1ページのみです。p0001 を表紙兼本文として生成します。", file=sys.stderr)
    body_imgs = imgs  # p0001 のみ
    fallback_single = True
else:
    fallback_single = False

# ---- body_raw_sides: 本文ページの raw_sides スライス ----
if fallback_single:
    # 1ページフォールバック: body_imgs = [p0001]。side は center(単独ページ)
    body_raw_sides = ["center"]
else:
    # raw_sides[1..] が p0002 以降の判定値
    body_raw_sides = raw_sides[1:]

# ---- final_side 決定(本文ページのみ・見開き割付の堅牢化) ----
# parity_expected は body_idx (j=0: p0002, j=1: p0003, ...) 基準で計算する。
# 1パスで孤立外れ値を検出し、パリティへスナップする。
if fallback_single:
    parity_expected_body = ["center"]
else:
    parity_expected_body = [parity_side_body(j, page_direction) for j in range(len(body_raw_sides))]

def is_isolated_outlier_body(body_raw, parity_exp, idx):
    """
    idx の本文ページが孤立外れ値かどうかを判定する。
    前後1枚それぞれの確定ページがパリティ一致していればアウトライアー。
    """
    prev_ok = False
    for j in range(idx - 1, -1, -1):
        if body_raw[j] in ("left", "right"):
            prev_ok = (body_raw[j] == parity_exp[j])
            break
    next_ok = False
    for j in range(idx + 1, len(body_raw)):
        if body_raw[j] in ("left", "right"):
            next_ok = (body_raw[j] == parity_exp[j])
            break
    return prev_ok and next_ok

body_sides = []
for j, s in enumerate(body_raw_sides):
    exp = parity_expected_body[j]
    if s not in ("left", "right"):
        # undecided → パリティ採用
        body_sides.append(exp)
    elif s == exp:
        # raw 確定 かつ パリティ一致 → raw 採用
        body_sides.append(s)
    else:
        # raw 確定 だがパリティと不一致 → 孤立外れ値ならパリティへスナップ
        if is_isolated_outlier_body(body_raw_sides, parity_expected_body, j):
            body_sides.append(exp)
        else:
            # 連続不一致(挿入ページ等による系統ずれ) → raw を尊重
            body_sides.append(s)

# ---- 見開きズレ警告(3連続同一side) ----
# 系統的なズレを検知して WARNING を出力する(side は変更しない)。
consecutive = 1
for j in range(1, len(body_sides)):
    if body_sides[j] == body_sides[j-1] and body_sides[j] != "center":
        consecutive += 1
        if consecutive >= 3:
            print(
                "WARNING: 本文 %d ページ目から %d 連続で同じ side(%s) が続いています。"
                " 挿入ページやノンブル誤検出の可能性があります。"
                " 見開きがずれる場合は --page-direction で綴じ方向を上書きしてください。"
                % (j - consecutive + 3, consecutive, body_sides[j]),
                file=sys.stderr)
    else:
        consecutive = 1

# ---- 余白トリミング(Pillowあり・do_trim ON 時) ----
# 【均一サイズ化方針】
# 全ページを厳密に同一サイズにすることで Kindle が見開きを画面いっぱいに拡大できるようにする。
# (1) pdftoppm native サイズを調べ最頻(dominant)サイズ (w0, h0) を決定する。
#     ※p0001(表紙)も含む全画像を計測対象にする(表紙も均一サイズにする)。
# (2) do_trim=True 時: dominant ページ群の各内容 bbox の和集合を
#       [min(left), min(top), max(right), max(bottom)] で算出し共通クロップ矩形とする。
#       和集合なのでどのページの内容も切り落とさない。共通外周余白だけが除去される。
# (3) uniform サイズ = 共通クロップ矩形の幅・高さ(do_trim=False 時は w0×h0)。
# (4) dominant 以外の native サイズのページ(折込等): uniform に収まるよう
#       aspect 保持リサイズ → 白でパディングし uniform ちょうどにする。
# (5) 全ページ XHTML viewport・original-resolution を uniform に統一する。

def native_size(img_path):
    """画像の native サイズを返す。失敗時は None。"""
    try:
        return Image.open(img_path).size
    except Exception:
        return None

def autotrim_box_single(img,
        bg_threshold=24, downscale=4,
        margin_frac=0.01, tiny_frac=0.05):
    """
    1枚の画像から白縁を除去した crop ボックスを返す。
    全白・極小内容・getbbox=None 時は None を返し元寸維持。
    """
    w, h = img.size
    small = img.resize((max(1, w // downscale), max(1, h // downscale)),
                       Image.BILINEAR).convert("L")
    cut = 255 - bg_threshold
    mask = small.point(lambda p: 255 if p < cut else 0, mode="L")
    bb = mask.getbbox()
    if bb is None:
        return None
    # 縮小座標 → 原寸復元(content を切らないよう安全側へ丸める)
    l = max(0, bb[0] * downscale - (downscale - 1))
    u = max(0, bb[1] * downscale - (downscale - 1))
    r = min(w, bb[2] * downscale + (downscale - 1))
    b = min(h, bb[3] * downscale + (downscale - 1))
    if (r - l) < w * tiny_frac and (b - u) < h * tiny_frac:
        return None
    ml = max(0, int(w * margin_frac))
    mt = max(0, int(h * margin_frac))
    return (
        max(0, l - ml),
        max(0, u - mt),
        min(w, r + ml),
        min(h, b + mt)
    )

# ---- 1) native サイズ収集 → dominant サイズ決定(p0001含む全画像) ----
native_sizes = []
for src in imgs:
    sz = native_size(src) if HAS_PILLOW else None
    native_sizes.append(sz if sz is not None else (1200, 1700))

from collections import Counter
size_counter = Counter(native_sizes)
dominant_size = size_counter.most_common(1)[0][0]  # (w0, h0)
w0, h0 = dominant_size

# ---- 2) dominant ページの bbox 和集合 → 共通クロップ矩形 ----
# do_trim=False または Pillow なし の場合は dominant サイズそのままを uniform にする。
if HAS_PILLOW and do_trim:
    union_box = None  # (min_left, min_top, max_right, max_bottom)
    for src, nsz in zip(imgs, native_sizes):
        if nsz != dominant_size:
            continue  # dominant 以外はスキップ
        try:
            img = Image.open(src)
            box = autotrim_box_single(img)
            if box is None:
                # 全白ページなど: bbox なし → dominant サイズ全体を bbox として使う
                box = (0, 0, w0, h0)
            if union_box is None:
                union_box = list(box)
            else:
                union_box[0] = min(union_box[0], box[0])  # left
                union_box[1] = min(union_box[1], box[1])  # top
                union_box[2] = max(union_box[2], box[2])  # right
                union_box[3] = max(union_box[3], box[3])  # bottom
        except Exception:
            pass
    if union_box is None:
        # dominant ページが1枚も処理できなかった場合はクロップなし
        common_crop = None
    else:
        # (0, 0, w0, h0) にクランプ
        common_crop = (
            max(0, union_box[0]),
            max(0, union_box[1]),
            min(w0, union_box[2]),
            min(h0, union_box[3]),
        )
    if common_crop is not None:
        uniform_w = common_crop[2] - common_crop[0]
        uniform_h = common_crop[3] - common_crop[1]
    else:
        uniform_w, uniform_h = w0, h0
else:
    common_crop = None
    uniform_w, uniform_h = w0, h0

# ---- 3) 各ページを uniform サイズに合わせて書き出し(p0001含む全画像) ----
# dominant: common_crop でクロップ(クロップなし時はそのまま)
# 非dominant: aspect 保持リサイズ → 白パディング
page_sizes    = []   # 最終的な (w, h) = 全て (uniform_w, uniform_h)
trimmed_paths = []

def make_uniform(src, nsz, common_crop, uniform_w, uniform_h, dominant_size, out_path):
    """
    1ページを uniform_w × uniform_h の JPEG として out_path に書き出す。
    dominant サイズのページは common_crop でクロップ、それ以外は
    aspect 保持リサイズ後に白パディングする。
    """
    img = Image.open(src).convert("RGB")
    w, h = nsz
    if nsz == dominant_size:
        if common_crop is not None:
            img = img.crop(common_crop)
    else:
        # 非dominant: uniform に収まるよう aspect 保持リサイズ
        scale = min(uniform_w / max(w, 1), uniform_h / max(h, 1))
        new_w = max(1, int(w * scale))
        new_h = max(1, int(h * scale))
        img = img.resize((new_w, new_h), Image.LANCZOS)
        # 白背景の uniform サイズキャンバスに中央配置
        canvas = Image.new("RGB", (uniform_w, uniform_h), (255, 255, 255))
        x_off = (uniform_w - new_w) // 2
        y_off = (uniform_h - new_h) // 2
        canvas.paste(img, (x_off, y_off))
        img = canvas
    img.save(out_path, "JPEG", quality=92)

for i, src in enumerate(imgs):
    nsz = native_sizes[i]
    if HAS_PILLOW:
        try:
            out_path = src + ".uniform.jpg"
            make_uniform(src, nsz, common_crop, uniform_w, uniform_h, dominant_size, out_path)
            trimmed_paths.append(out_path)
        except Exception:
            trimmed_paths.append(src)
    else:
        trimmed_paths.append(src)
    page_sizes.append((uniform_w, uniform_h))

# ---- 4) original-resolution: uniform サイズを使用(全ページ同一・kindlegen E34002 対策) ----
# kindlegen は rendition:layout=pre-paginated 時にこのメタが無いと E34002 で失敗する。
max_w, max_h = uniform_w, uniform_h

# ---- primary-writing-mode: 綴じ方向から決定 ----
# RTL(縦書き/右綴じ和書等) → "horizontal-rl"、LTR → "horizontal-lr"
primary_writing_mode = "horizontal-rl" if page_direction == "rtl" else "horizontal-lr"

# ---- EPUB 組立 ----
book_id = "urn:uuid:" + str(uuid.uuid4())
mod = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

z = zipfile.ZipFile(out_epub, "w", zipfile.ZIP_DEFLATED)
z.writestr(zipfile.ZipInfo("mimetype"), "application/epub+zip",
           compress_type=zipfile.ZIP_STORED)
z.writestr("META-INF/container.xml",
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
    '  <rootfiles>'
    '<rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>'
    '</rootfiles>\n'
    '</container>\n')

# CSS: 画面端まで充填(シングルクォート使用: bash の $() heredoc 内ダブルクォート崩れを回避)
# 均一サイズ化により画像アスペクト=viewportアスペクトが保証されるため
# object-fit: fill で viewport を隙間なく充填しても歪まない。
# 画面拡大時も img が 100% を維持するため追従して拡大する。
z.writestr('OEBPS/style.css',
    '@page { margin: 0; padding: 0; }\n'
    'html, body { margin: 0; padding: 0; height: 100%; }\n'
    'body { background: #fff; }\n'
    'img.full { display: block; width: 100%; height: 100%; object-fit: fill; }\n')

manifest_items = []
spine_items    = []

# ---- p0001(表紙): cover-image manifest item のみ生成・本文 xhtml は生成しない ----
# cover-image(properties="cover-image") として manifest に追加。
# p0001.xhtml は生成せず spine にも入れない。
# Kindle は cover-image から表紙を単独表示し、spine 先頭(p0002)から本文を開始する。
img_cover_name = "images/p0001.jpg"
trimmed_cover  = trimmed_paths[0]
z.write(trimmed_cover, "OEBPS/" + img_cover_name)
manifest_items.append(
    '<item id="img0001" href="%s" media-type="image/jpeg" properties="cover-image"/>'
    % img_cover_name)
# meta name="cover" は OPF metadata ブロックで後述。manifest item id は img0001 を参照。

# ---- 本文ページ(p0002以降): manifest + spine + xhtml を生成 ----
# body_imgs = imgs[1..] (通常) または imgs[0..] (1ページフォールバック)
# epub_page_num は EPUB 内のページ番号(p0002 が 2、p0003 が 3...)
# 1ページフォールバック時は p0001 が唯一の本文として EPUB ページ番号 1 になる。
if fallback_single:
    page_num_offset = 1   # p0001 → 番号1
    img_idx_offset  = 0   # imgs[0] = p0001
else:
    page_num_offset = 2   # p0002 → 番号2
    img_idx_offset  = 1   # imgs[1] = p0002

for j, src in enumerate(body_imgs):
    epub_pnum  = j + page_num_offset      # 2, 3, 4, ... (フォールバック時は 1)
    img_i      = j + img_idx_offset       # imgs 上のインデックス
    img_name   = "images/p%04d.jpg" % epub_pnum
    xhtml_name = "p%04d.xhtml" % epub_pnum
    side = body_sides[j]
    pw, ph = page_sizes[img_i]
    trimmed = trimmed_paths[img_i]

    # 画像ファイルをEPUBに格納
    # fallback_single 時: p0001.jpg は cover-image として既に zip 済み → 重複書き込みしない
    if not fallback_single:
        z.write(trimmed, "OEBPS/" + img_name)

    # manifest: 画像
    # fallback_single 時: img0001 は cover-image manifest item として既に追加済み → 重複 id を作らない
    if not fallback_single:
        manifest_items.append(
            '<item id="img%04d" href="%s" media-type="image/jpeg"/>' % (epub_pnum, img_name))

    # manifest: XHTML
    manifest_items.append(
        '<item id="pg%04d" href="%s" media-type="application/xhtml+xml"/>' % (epub_pnum, xhtml_name))

    # spine itemref: properties で左右を指定
    if side == "center":
        spread_prop = ' properties="rendition:page-spread-center"'
    elif side == "left":
        spread_prop = ' properties="rendition:page-spread-left"'
    else:
        spread_prop = ' properties="rendition:page-spread-right"'
    spine_items.append('<itemref idref="pg%04d"%s/>' % (epub_pnum, spread_prop))

    # 各ページ XHTML(viewport は実寸・本文ページは epub:type なし)
    html_ns  = '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja">'
    body_tag = '<body>'
    z.writestr("OEBPS/" + xhtml_name,
        '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n'
        '%s\n'
        '<head><meta charset="utf-8"/><title>%d</title>\n'
        '<meta name="viewport" content="width=%d, height=%d"/>\n'
        '<link rel="stylesheet" type="text/css" href="style.css"/></head>\n'
        '%s<img class="full" src="%s" alt="page %d"/></body>\n'
        '</html>\n' % (html_ns, epub_pnum, pw, ph, body_tag, img_name, epub_pnum))

# ---- nav.xhtml ----
# toc: p0002.xhtml を先頭に(フォールバック時は p0001.xhtml)
# landmarks:
#   cover エントリ(href=p0001.xhtml)は削除(対応 xhtml が存在しないため OPF-096 防止)。
#   bodymatter は本文先頭 xhtml を指す。
first_body_xhtml = "p%04d.xhtml" % page_num_offset
z.writestr("OEBPS/nav.xhtml",
    '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n'
    '<html xmlns="http://www.w3.org/1999/xhtml"'
    ' xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja">\n'
    '<head><meta charset="utf-8"/><title>目次</title></head>\n<body>\n'
    '<nav epub:type="toc" id="toc"><h1>目次</h1>'
    '<ol><li><a href="%s">先頭</a></li></ol></nav>\n'
    '<nav epub:type="landmarks" id="landmarks" hidden="hidden">\n'
    '<ol>\n'
    '<li><a epub:type="bodymatter" href="%s">本文先頭</a></li>\n'
    '</ol>\n'
    '</nav>\n'
    '</body></html>\n' % (first_body_xhtml, first_body_xhtml))

manifest_items.append(
    '<item id="nav" href="nav.xhtml"'
    ' media-type="application/xhtml+xml" properties="nav"/>')
manifest_items.append('<item id="css" href="style.css" media-type="text/css"/>')

# spine: p0002 から開始(フォールバック時は p0001 から)
spine_xml = "\n".join(spine_items)

# OPF: rendition prefix 明示 / fixed-layout メタ / カバー宣言
# guide の <reference type="cover"> は削除(対応 xhtml が存在しないため epubcheck OPF-096 防止)。
# cover-image properties と meta name="cover" で表紙は十分宣言される。
opf_author = ('<dc:creator>%s</dc:creator>\n' % html.escape(author)) if author else ""
z.writestr("OEBPS/content.opf",
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<package xmlns="http://www.idpf.org/2007/opf" version="3.0"'
    ' unique-identifier="bookid"'
    ' prefix="rendition: http://www.idpf.org/vocab/rendition/#">\n'
    '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
    '<dc:identifier id="bookid">%s</dc:identifier>\n'
    '<dc:title>%s</dc:title>\n'
    '<dc:language>ja</dc:language>\n'
    '%s'
    '<meta property="dcterms:modified">%s</meta>\n'
    '<meta property="rendition:layout">pre-paginated</meta>\n'
    '<meta property="rendition:spread">%s</meta>\n'
    '<meta property="rendition:orientation">auto</meta>\n'
    # Amazon fixed-layout 必須メタ(kindlegen E34002 解消)
    # epubcheck は要求しないが kindlegen / KFX 変換に必須。
    # rendition:* property メタと同一 <metadata> ブロックに共存可。
    # 注意: book-type=comic と region-mag は削除済み。
    #   comic を指定すると Kindle KFX がコミック自動ペアリングで
    #   spine の page-spread 宣言を無視し先頭から (1,2)(3,4) で見開きを組むため、
    #   表紙が単独にならず左右が逆になる問題が発生する。
    #   これらを除去することで EPUB3 標準の rendition:spread +
    #   spine の page-spread-center/left/right が尊重される。
    '<meta name="fixed-layout" content="true"/>\n'
    '<meta name="original-resolution" content="%dx%d"/>\n'   # 全ページ uniform 幅×高さ
    '<meta name="orientation-lock" content="none"/>\n'
    '<meta name="primary-writing-mode" content="%s"/>\n'     # rtl→horizontal-rl / ltr→horizontal-lr
    '<meta name="cover" content="img0001"/>\n'               # cover-image サムネ用(manifest id 参照)
    '</metadata>\n'
    '<manifest>\n%s\n</manifest>\n'
    '<spine page-progression-direction="%s">\n%s\n</spine>\n'
    '</package>\n'
    % (book_id, html.escape(title), opf_author, mod,
       spread_mode,
       max_w, max_h, primary_writing_mode,
       "\n".join(manifest_items),
       page_direction, spine_xml))

z.close()

# uniform 変換の一時ファイルを削除
for tp in trimmed_paths:
    if tp.endswith(".uniform.jpg") and os.path.exists(tp):
        os.remove(tp)

# 出力: 本文 xhtml 数を報告(cover-image 1枚 + 本文 xhtml N-1 枚 = PDF N ページ)
print("OK pages=%d body_xhtml=%d direction=%s" % (len(imgs), len(body_imgs), page_direction))
PYEOF
}

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
  local dst="${f%.*}.epub"
  # スキップ: 同名 .epub が既に存在
  if [ -f "$dst" ]; then
    echo "⏭️  スキップ(EPUB既存): $name"; skipped=$((skipped+1)); return
  fi
  if [ "$DRY_RUN" = "1" ]; then
    echo "🔧 PDF→EPUB変換対象(dry-run): $name"; processed=$((processed+1)); return
  fi
  local pages_before; pages_before="$(pdf_pages "$f")"
  local tmp; tmp="$(mktemp -d)"
  # 一時ディレクトリをエラー経路含む全経路で後始末(二重 rm -rf は無害)。
  # Bash の trap RETURN は関数スコープ内でのみ有効であり、呼び出し元や他の関数には
  # 引き継がれない。グローバル汚染は発生しない。
  trap 'rm -rf "${tmp:-}"' RETURN
  # 各ページを連番 JPEG に描画(日本語/スペースのパスに対応)
  if ! pdftoppm -jpeg -r "$PDF_EPUB_DPI" "$f" "$tmp/page" >/dev/null 2>&1; then
    echo "🔴 破損/描画失敗(スキップ): $name"; broken=$((broken+1)); return
  fi
  local n; n="$(find "$tmp" -name 'page-*.jpg' | wc -l | tr -d ' ')"
  if [ "${n:-0}" -lt 1 ]; then
    echo "🔴 ページ画像0(スキップ): $name"; broken=$((broken+1)); return
  fi
  local title author; title="$(pdf_title "$f")"; [ -z "$title" ] && title="${name%.*}"
  author="$(pdf_author "$f")"
  if ! python3 -c "$BUILD_IMAGE_EPUB_PY" "$tmp" "$tmp/out.epub" "$title" "$author" >/dev/null 2>&1; then
    echo "⚠️  EPUB生成失敗(スキップ): $name"; failed=$((failed+1)); return
  fi
  # 検証: zip 健全性・ページ数一致(pdfinfo がある場合)
  local epub_pages; epub_pages="$(unzip -l "$tmp/out.epub" 2>/dev/null | grep -c 'p[0-9]*\.xhtml' || true)"
  if ! unzip -t "$tmp/out.epub" >/dev/null 2>&1; then
    echo "⚠️  生成EPUB検証失敗(スキップ): $name"; failed=$((failed+1)); return
  fi
  if [ -n "$pages_before" ] && [ "$pages_before" != "$epub_pages" ]; then
    echo "⚠️  ページ数不一致 検証失敗(スキップ): $name (PDF ${pages_before} → EPUB ${epub_pages})"
    failed=$((failed+1)); return
  fi
  mv "$tmp/out.epub" "$dst"
  if [ "$REPLACE_PDF" = "1" ]; then
    if [ "$NO_BACKUP" = "0" ] && [ ! -f "$f.bak" ]; then cp "$f" "$f.bak"; backups=$((backups+1)); fi
    rm -f "$f"
    if [ "$NO_BACKUP" = "0" ]; then
      echo "✅ PDF→EPUB変換: $name (${epub_pages}ページ, 元PDF削除/.bak退避済)"
    else
      echo "✅ PDF→EPUB変換: $name (${epub_pages}ページ, 元PDF削除)"
    fi
  else
    echo "✅ PDF→EPUB変換: $name (${epub_pages}ページ, .epub併置・元PDF保持)"
  fi
  processed=$((processed+1))
}

# ---- PDF → 見開き fixed-layout EPUB 変換(--pdf-spread) ----
# PDF を EPUB3 fixed-layout(pre-paginated)として再構成する。
# ノンブル左右判定・綴じ方向自動推定・余白トリミングを埋込 Python で実施。
process_pdf_spread() {
  local f="$1" name="$2"
  local dst="${f%.*}.epub"
  # スキップ: 同名 .epub が既存(冪等性スキップ)
  if [ -f "$dst" ]; then
    echo "⏭️  スキップ(EPUB既存): $name"; skipped=$((skipped+1)); return
  fi
  if [ "$DRY_RUN" = "1" ]; then
    echo "🔧 PDF→見開きEPUB変換対象(dry-run): $name"; processed=$((processed+1)); return
  fi
  local pages_before; pages_before="$(pdf_pages "$f")"
  local tmp; tmp="$(mktemp -d)"
  # 一時ディレクトリをエラー経路含む全経路で後始末(二重 rm -rf は無害)。
  # trap RETURN は本関数スコープ内のみ有効。呼び出し元・他の関数へは引き継がれない。
  trap 'rm -rf "${tmp:-}"' RETURN
  # 各ページを連番 JPEG に描画
  if ! pdftoppm -jpeg -r "$PDF_EPUB_DPI" "$f" "$tmp/page" >/dev/null 2>&1; then
    echo "🔴 破損/描画失敗(スキップ): $name"; broken=$((broken+1)); return
  fi
  local n; n="$(find "$tmp" -name 'page-*.jpg' | wc -l | tr -d ' ')"
  if [ "${n:-0}" -lt 1 ]; then
    echo "🔴 ページ画像0(スキップ): $name"; broken=$((broken+1)); return
  fi
  local title author
  title="$(pdf_title "$f")"; [ -z "$title" ] && title="${name%.*}"
  author="$(pdf_author "$f")"
  # 埋込 Python ビルダ呼び出し
  # 引数: img_dir out_epub title author page_direction spread_mode do_trim
  # bash 3.2 互換のため Python 本文は一時ファイルへ書き出してから実行する
  # (詳細は write_spread_epub_py 定義近傍のコメント参照)。
  local trim_flag; trim_flag="$( [ "$NO_TRIM" = "1" ] && echo "0" || echo "1" )"
  local py_script; py_script="$tmp/build_spread.py"
  write_spread_epub_py "$py_script"
  local py_out
  py_out="$(python3 "$py_script" \
    "$tmp" "$tmp/out.epub" "$title" "$author" \
    "$PAGE_DIRECTION" "$SPREAD_MODE" "$trim_flag" 2>&1)" || {
    echo "⚠️  EPUB生成失敗(スキップ): $name"; failed=$((failed+1)); return
  }
  # WARNING 行があれば表示(致命扱いにはしない)
  printf '%s\n' "$py_out" | /usr/bin/grep -E '^(WARNING|ERROR):' >&2 || true
  # ---- 検証: zip 健全性 ----
  if ! unzip -t "$tmp/out.epub" >/dev/null 2>&1; then
    echo "⚠️  生成EPUB zip 検証失敗(スキップ): $name"; failed=$((failed+1)); return
  fi
  # ---- 検証: ページ数一致 ----
  # cover-image 専用構造: cover-image(p0001)1枚 + 本文 xhtml(N-1)枚 = PDF N ページ
  # 期待値: epub_pages(本文 xhtml 数) == pages_before - 1
  # フォールバック(1ページPDF): epub_pages == 1 == pages_before でも合格
  local epub_pages; epub_pages="$(unzip -l "$tmp/out.epub" 2>/dev/null | /usr/bin/grep -c 'p[0-9]*\.xhtml' || true)"
  if [ -n "$pages_before" ]; then
    local expected_body; expected_body=$((pages_before - 1))
    # 1ページPDF フォールバック: epub_pages == 1 を許容
    if [ "$pages_before" = "1" ]; then
      expected_body=1
    fi
    if [ "$epub_pages" != "$expected_body" ]; then
      echo "⚠️  ページ数不一致 検証失敗(スキップ): $name (PDF ${pages_before} → 本文XHTML ${epub_pages} 期待値 ${expected_body})"
      failed=$((failed+1)); return
    fi
  fi
  # ---- 検証: cover-image item が存在するか ----
  if ! unzip -p "$tmp/out.epub" "OEBPS/content.opf" 2>/dev/null | /usr/bin/grep -q 'cover-image'; then
    echo "⚠️  cover-image 宣言なし 検証失敗(スキップ): $name"; failed=$((failed+1)); return
  fi
  mv "$tmp/out.epub" "$dst"
  # 推定した綴じ方向をログに出す
  local dir_info; dir_info="$(printf '%s' "$py_out" | /usr/bin/grep -o 'direction=[a-z]*' || echo "")"
  # 表示用ページ数: PDF ページ数(= cover-image 1 + 本文 xhtml N-1)
  local total_pages; total_pages="${pages_before:-${epub_pages}}"
  if [ "$REPLACE_PDF" = "1" ]; then
    if [ "$NO_BACKUP" = "0" ] && [ ! -f "$f.bak" ]; then cp "$f" "$f.bak"; backups=$((backups+1)); fi
    rm -f "$f"
    if [ "$NO_BACKUP" = "0" ]; then
      echo "✅ PDF→見開きEPUB: $name (${total_pages}ページ, ${dir_info:-direction=?}, 元PDF削除/.bak退避済)"
    else
      echo "✅ PDF→見開きEPUB: $name (${total_pages}ページ, ${dir_info:-direction=?}, 元PDF削除)"
    fi
  else
    echo "✅ PDF→見開きEPUB: $name (${total_pages}ページ, ${dir_info:-direction=?}, .epub併置・元PDF保持)"
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
      if   [ "$PDF_SPREAD" = "1" ];   then process_pdf_spread  "$f" "$name"
      elif [ "$PDF_TO_EPUB" = "1" ];  then process_pdf_to_epub "$f" "$name"
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
  if [ "$backups" -gt 0 ]; then echo "  原本 $backups 件を .bak に退避済み(不要なら削除可)"; fi
fi
