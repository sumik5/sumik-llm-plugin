#!/usr/bin/env bash
# 指定フォルダ配下の EPUB を走査し、Kindle / Finder で表紙サムネイルが
# 生成されない「固定レイアウト(pre-paginated)」EPUB を reflowable に変換して
# 表紙を正規化するスクリプト。
#
# 背景: 固定レイアウト(fixed-layout / pre-paginated / comic)の EPUB は、
#       Kindle のカバー生成や macOS QuickLook がサムネイルを作れず、表紙が
#       真っ黒(タイトルのみ)になることがある。Calibre の ebook-convert で
#       reflowable に再生成すると、表紙宣言が正規化されサムネイルが出るようになる。
#
# 依存: Calibre (ebook-convert)。未導入時はエラー終了する。
set -euo pipefail

usage() {
  cat << 'EOF'
Usage: epub-fix-cover.sh [OPTIONS] <FOLDER>

<FOLDER> 配下(再帰)のすべての .epub を走査し、表紙サムネイルが生成されない
固定レイアウト EPUB を reflowable に変換して表紙を正規化します。

スキップ条件:
  既に「表紙が出る状態」(= 固定レイアウトでない かつ cover 宣言あり)の EPUB は
  変換せずスキップします。固定レイアウトの EPUB は cover 宣言の有無に関わらず
  変換対象になります(固定レイアウトはサムネ生成自体が壊れるため)。

Arguments:
  FOLDER          走査するフォルダ(必須)

Options:
  --no-backup     原本の .bak バックアップを作成しない
  --dry-run       変換せず、対象/スキップの判定だけ表示する
  -h, --help      このヘルプを表示

変換時の挙動:
  - 原本は同じ場所に "<name>.epub.bak" として退避(--no-backup で無効化)
  - reflowable 化により見開き表示は1ページずつのスクロール表示に変わります
    (全ページ・全画像は保全されます)
  - 破損 EPUB(zip として開けないもの)は警告を出してスキップします
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
if ! command -v ebook-convert >/dev/null 2>&1; then
  echo "エラー: Calibre の ebook-convert が見つかりません。" >&2
  echo "  Calibre をインストールしてください (例: brew install --cask calibre)" >&2
  echo "  インストール済みなら ebook-convert に PATH を通してください" >&2
  echo "  (macOS 例: /Applications/calibre.app/Contents/MacOS)" >&2
  exit 1
fi

# ---- OPF パス取得 ----
opf_path() {
  unzip -p "$1" META-INF/container.xml 2>/dev/null \
    | grep -o 'full-path="[^"]*"' | head -1 | sed 's/full-path="//;s/"//'
}

# ---- 判定: 固定レイアウトか ----
is_fixed_layout() {
  local opf; opf="$(opf_path "$1")"
  [ -z "$opf" ] && return 1
  unzip -p "$1" "$opf" 2>/dev/null | grep -qiE 'pre-paginated|fixed-layout'
}

# ---- 判定: cover 宣言があるか ----
has_cover() {
  local opf; opf="$(opf_path "$1")"
  [ -z "$opf" ] && return 1
  unzip -p "$1" "$opf" 2>/dev/null | grep -qiE 'name="cover"|cover-image'
}

# ---- 画像枚数 ----
image_count() {
  local n
  n="$(unzip -l "$1" 2>/dev/null | grep -ciE '\.(jpg|jpeg|png|gif)' || true)"
  echo "${n:-0}"
}

# ---- メイン処理 ----
converted=0; skipped=0; broken=0; failed=0; total=0

# null 区切りで安全に再帰列挙(スペース/日本語ファイル名対応)
while IFS= read -r -d '' f; do
  total=$((total+1))
  name="$(basename "$f")"

  # 破損チェック
  if ! unzip -t "$f" >/dev/null 2>&1; then
    echo "🔴 破損(スキップ): $name"
    broken=$((broken+1))
    continue
  fi

  # スキップ判定: 固定レイアウトでない かつ cover 宣言あり → 既に表紙が出る
  if ! is_fixed_layout "$f" && has_cover "$f"; then
    echo "⏭️  スキップ(表紙設定済): $name"
    skipped=$((skipped+1))
    continue
  fi

  if [ "$DRY_RUN" = "1" ]; then
    echo "🔧 変換対象(dry-run): $name"
    converted=$((converted+1))
    continue
  fi

  # 変換
  tmp="$(mktemp -d)"
  out="$tmp/out.epub"
  if ! ebook-convert "$f" "$out" >/dev/null 2>&1; then
    echo "⚠️  変換失敗(スキップ): $name"
    rm -rf "$tmp"; failed=$((failed+1)); continue
  fi

  # 検証: zip 健全 / 固定レイアウト除去 / 画像枚数の保全(誤差3枚まで許容)
  orig_imgs="$(image_count "$f")"
  new_imgs="$(image_count "$out")"
  if ! unzip -t "$out" >/dev/null 2>&1 \
     || is_fixed_layout "$out" \
     || [ "$new_imgs" -lt $((orig_imgs - 3)) ]; then
    echo "⚠️  検証失敗(原本保持): $name (img: ${orig_imgs}→${new_imgs})"
    rm -rf "$tmp"; failed=$((failed+1)); continue
  fi

  # バックアップ → 置換
  if [ "$NO_BACKUP" = "0" ] && [ ! -f "$f.bak" ]; then
    cp "$f" "$f.bak"
  fi
  mv "$out" "$f"
  rm -rf "$tmp"
  echo "✅ 変換完了: $name (img: ${new_imgs}枚, 固定レイアウト除去)"
  converted=$((converted+1))
done < <(find "$FOLDER" -type f -iname '*.epub' ! -iname '*.bak' -print0)

# ---- サマリ ----
echo ""
echo "===== 完了 ====="
echo "  走査: $total 冊"
if [ "$DRY_RUN" = "1" ]; then
  echo "  変換対象: $converted 冊 / スキップ: $skipped 冊 / 破損: $broken 冊"
  echo "  (dry-run のため実変換は行っていません)"
else
  echo "  変換: $converted 冊 / スキップ(表紙設定済): $skipped 冊"
  echo "  破損(要再取得): $broken 冊 / 失敗: $failed 冊"
  [ "$NO_BACKUP" = "0" ] && echo "  原本は各 .epub.bak に退避済み(不要なら削除可)"
fi
