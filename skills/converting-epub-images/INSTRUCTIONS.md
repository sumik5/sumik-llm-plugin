# 画像ベースEPUB → テキスト変換

画像で構成されたEPUBファイルを、LM Studio のローカルVLM（OCR）を使って日本語テキスト（Markdown）に変換する。

## 前提条件

- **LM Studio** が起動し、VLMモデル（デフォルト: `qwen/qwen3.5-9b`）がロードされていること
- **pandoc** がインストールされていること（`brew install pandoc`）
- **Python 3** が利用可能であること

## 引数

```
/converting-epub-images <epub-file-path>
```

`$ARGUMENTS` にEPUBファイルのパスが渡される。

## 実行手順

**以下の手順を上から順に、すべてBashツールで実行すること。Readツールで画像ファイルを読み取ってはならない。**

### Step 1: 入力検証

```bash
EPUB_PATH="$ARGUMENTS"

# ファイル存在確認
if [ ! -f "$EPUB_PATH" ]; then
  echo "エラー: ファイルが見つかりません: $EPUB_PATH"
  exit 1
fi

# 拡張子確認
if [[ "$EPUB_PATH" != *.epub ]]; then
  echo "エラー: EPUBファイルではありません: $EPUB_PATH"
  exit 1
fi
```

### Step 2: pandocでEPUBをMarkdown変換（画像ベース判定用）

```bash
EPUB_BASENAME=$(basename "$EPUB_PATH" .epub)
WORK_DIR="/tmp/epub-convert-${EPUB_BASENAME}"
mkdir -p "$WORK_DIR"

pandoc -t markdown -o "$WORK_DIR/pandoc-output.md" "$EPUB_PATH"
```

### Step 3: 画像ベースEPUB判定

pandoc変換後のMarkdownを確認し、`![` による画像参照が大半でテキストが少ない場合は画像ベースEPUBと判定する。

```bash
# 画像参照の行数とテキスト行数を比較
IMG_LINES=$(grep -c '!\[' "$WORK_DIR/pandoc-output.md" 2>/dev/null || echo 0)
TOTAL_LINES=$(wc -l < "$WORK_DIR/pandoc-output.md")
TEXT_LINES=$((TOTAL_LINES - IMG_LINES))

echo "総行数: $TOTAL_LINES, 画像参照: $IMG_LINES, テキスト: $TEXT_LINES"
```

**判定基準**: 画像参照が全体の50%以上、またはテキスト行が50行未満なら画像ベース。

- **画像ベースの場合** → Step 4 に進む
- **テキストベースの場合** → pandoc変換結果をそのまま `~/Desktop/${EPUB_BASENAME}.md` にコピーして終了

### Step 4: EPUBから画像を抽出

EPUBはZIPアーカイブなので、unzipで画像を抽出する。

```bash
IMG_DIR="$WORK_DIR/images"
mkdir -p "$IMG_DIR"

# 画像ファイルを抽出（EPUBの内部構造に応じてパスが異なる）
unzip -j "$EPUB_PATH" "*.png" "*.jpg" "*.jpeg" "*.webp" -d "$IMG_DIR/" 2>/dev/null

# 抽出した画像の枚数を確認
IMG_COUNT=$(ls "$IMG_DIR"/*.{png,jpg,jpeg,webp} 2>/dev/null | wc -l)
echo "抽出画像枚数: $IMG_COUNT"
```

画像が0枚の場合はエラーとして終了する。

### Step 5: ページ順の決定

pandocの出力から画像参照順を抽出する。これがEPUBのページ順序に対応する（ファイル名のソートよりも確実）。

```bash
# pandoc出力から画像ファイル名を参照順に抽出（重複除去）
grep -o 'image_rsrc[A-Za-z0-9]*\.\(jpg\|png\|jpeg\|webp\)' "$WORK_DIR/pandoc-output.md" \
  | python3 -c "import sys; seen=set(); [print(l.strip()) for l in sys.stdin if l.strip() not in seen and not seen.add(l.strip())]" \
  > "$WORK_DIR/page-order.txt"

# ページ順ファイルが空の場合（パターン不一致時）はファイル名ソートにフォールバック
if [ ! -s "$WORK_DIR/page-order.txt" ]; then
  ls "$IMG_DIR"/*.jpg "$IMG_DIR"/*.png "$IMG_DIR"/*.jpeg "$IMG_DIR"/*.webp 2>/dev/null \
    | xargs -I{} basename {} | sort -V > "$WORK_DIR/page-order.txt"
fi

echo "ページ数: $(wc -l < "$WORK_DIR/page-order.txt")"
head -5 "$WORK_DIR/page-order.txt"
```

### Step 5.1: 空白ページのフィルタリング（推奨）

ファイルサイズが極端に小さい画像（15KB以下）は空白ページの可能性が高い。フィルタリングして除外する。

```bash
# 15KB以下の画像を検出
while IFS= read -r img; do
  filepath="$IMG_DIR/$img"
  if [ -f "$filepath" ]; then
    size=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null)
    if [ "$size" -le 15360 ]; then
      echo "スキップ（空白ページ候補）: $img (${size}B)"
    fi
  fi
done < "$WORK_DIR/page-order.txt"
```

空白ページ候補が検出された場合、スキップするかどうかをユーザーに確認する。

### Step 6: AskUserQuestionで変換確認

OCR変換開始前に、以下を確認する:

```
AskUserQuestion:
  question: "画像ベースEPUBを検出しました。LM StudioでOCR変換を開始しますか？\n\n- ファイル: {EPUB_BASENAME}.epub\n- 画像枚数: {IMG_COUNT}枚\n- 出力先: ~/Desktop/{EPUB_BASENAME}.md\n- ※ LM Studioが起動しモデルがロードされている必要があります"
  header: "OCR変換確認"
  options:
    - label: "変換開始"
      description: "全画像をOCR変換してMarkdownファイルを生成"
    - label: "キャンセル"
      description: "変換せず終了"
```

「キャンセル」の場合は終了する。

### Step 7: recognize-image.py でOCR変換

スキル内の `scripts/recognize-image.py` を使用して、各画像をOCR変換する。

**SCRIPT_PATH の解決**: このスキルの `scripts/recognize-image.py` のフルパスを使用する。

```bash
SCRIPT_DIR="skills/converting-epub-images/scripts"
# プラグインキャッシュ内の場合
# SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/skills/converting-epub-images/scripts"
```

**変換実行**:

`page-order.txt` のページ順に従い、1ファイルずつ処理して結合する（大量画像時のメモリ・タイムアウト対策）。空白ページ（15KB以下）はスキップする:

```bash
OUTPUT_FILE="$HOME/Desktop/${EPUB_BASENAME}.md"
> "$OUTPUT_FILE"  # 出力ファイル初期化

TOTAL=$(wc -l < "$WORK_DIR/page-order.txt")
PAGE_NUM=0
WRITTEN=0

while IFS= read -r img; do
  PAGE_NUM=$((PAGE_NUM + 1))
  filepath="$IMG_DIR/$img"

  # ファイル存在確認
  if [ ! -f "$filepath" ]; then
    echo "[$PAGE_NUM/$TOTAL] $img をスキップ（ファイルなし）" >&2
    continue
  fi

  # 空白ページスキップ（15KB以下）
  size=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null)
  if [ "$size" -le 15360 ]; then
    echo "[$PAGE_NUM/$TOTAL] $img をスキップ（空白ページ: ${size}B）" >&2
    continue
  fi

  echo "[$PAGE_NUM/$TOTAL] $img を処理中..." >&2

  # OCR実行
  RESULT=$(python3 "$SCRIPT_DIR/recognize-image.py" --path "$filepath" 2>/dev/null)

  # ページ区切り付きで結合
  if [ $WRITTEN -gt 0 ]; then
    printf "\n\n---\n\n" >> "$OUTPUT_FILE"
  fi
  echo "$RESULT" >> "$OUTPUT_FILE"
  WRITTEN=$((WRITTEN + 1))
done < "$WORK_DIR/page-order.txt"

echo "完了: $OUTPUT_FILE ($WRITTEN ページ処理)" >&2
```

### Step 8: 結果報告

変換完了後、以下を報告する:

- 出力ファイルパス: `~/Desktop/{EPUB_BASENAME}.md`
- 処理画像枚数
- 変換にかかった概算時間

## エラーハンドリング

| エラー | 原因 | 対処 |
|-------|------|------|
| LM Studio API エラー | LM Studioが未起動/モデル未ロード | LM Studioを起動しモデルをロード |
| pandoc not found | pandoc未インストール | `brew install pandoc` |
| 画像0枚 | EPUB内に画像がない/抽出パス不一致 | `unzip -l` でEPUB内部構造を確認 |
| タイムアウト | 画像枚数が多すぎる | 画像を分割して処理 |

## 注意事項

- OCR精度はLM Studioのモデルに依存する。日本語テキストの場合、VLMモデルの日本語対応状況を確認すること
- 大量の画像（100枚超）の場合、処理に時間がかかる。進捗は標準エラー出力に表示される
- 出力はMarkdown形式。ページ間は `---`（水平線）で区切られる
