# コンテンツ変換ガイド

## 目次

1. [コンテンツ変換種別選択ガイド](#1-コンテンツ変換種別選択ガイド)
2. [画像ベースEPUB → テキスト変換](#2-画像ベースepub--テキスト変換)
3. [LM Studio 英日翻訳](#3-lm-studio-英日翻訳)

---

## 1. コンテンツ変換種別選択ガイド

| 変換種別 | 入力 | 出力 | 使用セクション |
|---------|------|------|--------------|
| EPUB→テキスト（テキストベース） | .epub（テキスト埋め込み） | Markdown | pandocで直接変換 |
| EPUB→テキスト（画像ベース） | .epub（スキャン/画像ページ） | Markdown（OCR結果） | セクション2 |
| 英語→日本語翻訳 | 英語テキスト/ファイル | 日本語テキスト | セクション3 |

**判定方法（EPUBの種別確認）**:

```bash
pandoc -t markdown -o /tmp/check.md <epub-file>
grep -c '!\[' /tmp/check.md  # 画像参照行数
wc -l < /tmp/check.md        # 総行数
```

画像参照が全体の50%以上、またはテキスト行が50行未満 → 画像ベース（OCR必要）

---

## 2. 画像ベースEPUB → テキスト変換

画像で構成されたEPUBファイルを、LM StudioのローカルVLM（OCR）を使って日本語テキスト（Markdown）に変換する。

### 前提条件

- **LM Studio** が起動し、VLMモデル（デフォルト: `qwen/qwen3.5-9b`）がロードされていること
- **pandoc** がインストールされていること（`brew install pandoc`）
- **Python 3** が利用可能であること

### 引数

```
/converting-content <epub-file-path>
```

`$ARGUMENTS` にEPUBファイルのパスが渡される。

### 実行手順

**以下の手順を上から順に、すべてBashツールで実行すること。Readツールで画像ファイルを読み取ってはならない。**

#### Step 1: 入力検証

```bash
EPUB_PATH="$ARGUMENTS"

if [ ! -f "$EPUB_PATH" ]; then
  echo "エラー: ファイルが見つかりません: $EPUB_PATH"
  exit 1
fi

if [[ "$EPUB_PATH" != *.epub ]]; then
  echo "エラー: EPUBファイルではありません: $EPUB_PATH"
  exit 1
fi
```

#### Step 2: pandocでEPUBをMarkdown変換（画像ベース判定用）

```bash
EPUB_BASENAME=$(basename "$EPUB_PATH" .epub)
WORK_DIR="/tmp/epub-convert-${EPUB_BASENAME}"
mkdir -p "$WORK_DIR"

pandoc -t markdown -o "$WORK_DIR/pandoc-output.md" "$EPUB_PATH"
```

#### Step 3: 画像ベースEPUB判定

```bash
IMG_LINES=$(grep -c '!\[' "$WORK_DIR/pandoc-output.md" 2>/dev/null || echo 0)
TOTAL_LINES=$(wc -l < "$WORK_DIR/pandoc-output.md")
TEXT_LINES=$((TOTAL_LINES - IMG_LINES))

echo "総行数: $TOTAL_LINES, 画像参照: $IMG_LINES, テキスト: $TEXT_LINES"
```

**判定基準**: 画像参照が全体の50%以上、またはテキスト行が50行未満なら画像ベース。

- **画像ベースの場合** → Step 4 に進む
- **テキストベースの場合** → pandoc変換結果をそのまま `~/Desktop/${EPUB_BASENAME}.md` にコピーして終了

#### Step 4: EPUBから画像を抽出

```bash
IMG_DIR="$WORK_DIR/images"
mkdir -p "$IMG_DIR"

unzip -j "$EPUB_PATH" "*.png" "*.jpg" "*.jpeg" "*.webp" -d "$IMG_DIR/" 2>/dev/null

IMG_COUNT=$(ls "$IMG_DIR"/*.{png,jpg,jpeg,webp} 2>/dev/null | wc -l)
echo "抽出画像枚数: $IMG_COUNT"
```

画像が0枚の場合はエラーとして終了する。

#### Step 5: ページ順の決定

```bash
grep -o 'image_rsrc[A-Za-z0-9]*\.\(jpg\|png\|jpeg\|webp\)' "$WORK_DIR/pandoc-output.md" \
  | python3 -c "import sys; seen=set(); [print(l.strip()) for l in sys.stdin if l.strip() not in seen and not seen.add(l.strip())]" \
  > "$WORK_DIR/page-order.txt"

# ページ順ファイルが空の場合はファイル名ソートにフォールバック
if [ ! -s "$WORK_DIR/page-order.txt" ]; then
  ls "$IMG_DIR"/*.jpg "$IMG_DIR"/*.png "$IMG_DIR"/*.jpeg "$IMG_DIR"/*.webp 2>/dev/null \
    | xargs -I{} basename {} | sort -V > "$WORK_DIR/page-order.txt"
fi

echo "ページ数: $(wc -l < "$WORK_DIR/page-order.txt")"
```

#### Step 5.1: 空白ページのフィルタリング（推奨）

```bash
while IFS= read -r img; do
  filepath="$IMG_DIR/$img"
  if [ -f "$filepath" ]; then
    size=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null)
    if [ "$size" -le 15360 ]; then
      echo "スキップ候補（空白ページ）: $img (${size}B)"
    fi
  fi
done < "$WORK_DIR/page-order.txt"
```

15KB以下の画像が検出された場合、スキップするかをAskUserQuestionで確認する。

#### Step 6: AskUserQuestionで変換確認

```
AskUserQuestion:
  question: "画像ベースEPUBを検出しました。LM StudioでOCR変換を開始しますか？
    - ファイル: {EPUB_BASENAME}.epub
    - 画像枚数: {IMG_COUNT}枚
    - 出力先: ~/Desktop/{EPUB_BASENAME}.md
    ※ LM Studioが起動しモデルがロードされている必要があります"
  header: "OCR変換確認"
  options:
    - label: "変換開始"
    - label: "キャンセル"
```

#### Step 7: recognize-image.py でOCR変換

スキル内の `scripts/recognize-image.py` を使用して各画像をOCR変換する。

```bash
SCRIPT_DIR="skills/converting-content/scripts"

OUTPUT_FILE="$HOME/Desktop/${EPUB_BASENAME}.md"
> "$OUTPUT_FILE"

TOTAL=$(wc -l < "$WORK_DIR/page-order.txt")
PAGE_NUM=0
WRITTEN=0

while IFS= read -r img; do
  PAGE_NUM=$((PAGE_NUM + 1))
  filepath="$IMG_DIR/$img"

  if [ ! -f "$filepath" ]; then
    echo "[$PAGE_NUM/$TOTAL] $img をスキップ（ファイルなし）" >&2
    continue
  fi

  size=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null)
  if [ "$size" -le 15360 ]; then
    echo "[$PAGE_NUM/$TOTAL] $img をスキップ（空白ページ: ${size}B）" >&2
    continue
  fi

  echo "[$PAGE_NUM/$TOTAL] $img を処理中..." >&2
  RESULT=$(python3 "$SCRIPT_DIR/recognize-image.py" --path "$filepath" 2>/dev/null)

  if [ $WRITTEN -gt 0 ]; then
    printf "\n\n---\n\n" >> "$OUTPUT_FILE"
  fi
  echo "$RESULT" >> "$OUTPUT_FILE"
  WRITTEN=$((WRITTEN + 1))
done < "$WORK_DIR/page-order.txt"

echo "完了: $OUTPUT_FILE ($WRITTEN ページ処理)" >&2
```

#### Step 8: 結果報告

- 出力ファイルパス: `~/Desktop/{EPUB_BASENAME}.md`
- 処理画像枚数
- 変換にかかった概算時間

### エラーハンドリング

| エラー | 原因 | 対処 |
|-------|------|------|
| LM Studio API エラー | LM Studioが未起動/モデル未ロード | LM Studioを起動しモデルをロード |
| pandoc not found | pandoc未インストール | `brew install pandoc` |
| 画像0枚 | EPUB内に画像がない/抽出パス不一致 | `unzip -l` でEPUB内部構造を確認 |
| タイムアウト | 画像枚数が多すぎる | 画像を分割して処理 |

### 注意事項

- OCR精度はLM Studioのモデルに依存する。日本語テキストの場合、VLMモデルの日本語対応状況を確認すること
- 大量の画像（100枚超）の場合、処理に時間がかかる。進捗は標準エラー出力に表示される
- 出力はMarkdown形式。ページ間は `---`（水平線）で区切られる

---

## 3. LM Studio 英日翻訳

LM StudioのローカルLLMを使って英語テキストを自然な日本語に翻訳するワークフロー。

### 前提条件

- LM Studio が起動中であること
- 翻訳に使用するモデルがロード済みであること
- デフォルトの API エンドポイント: `http://localhost:1234`

### ワークフロー

#### Step 1: 依存関係チェック

```bash
python3 -c "import openai" 2>/dev/null || pip install openai -q
```

#### Step 2: LM Studio 接続確認 + モデル選択（セッション初回のみ）

**モデル一覧取得:**

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/converting-content/scripts/lmstudio-translate.py list-models
```

出力例:
```json
["lmstudio-community/gemma-3-12b-it-GGUF", "lmstudio-community/qwen2.5-7b-instruct-GGUF"]
```

取得したモデル一覧をAskUserQuestionでユーザーに選択してもらう。セッション内で一度選択したモデルはそのまま使い続ける。

#### Step 3: 翻訳実行

**短文（コマンドライン引数）:**

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/converting-content/scripts/lmstudio-translate.py translate \
  --model <選択したモデル名> \
  --text "Text to translate"
```

**長文（stdin から渡す）:**

```bash
echo "Long text to translate..." | \
  python3 ${CLAUDE_PLUGIN_ROOT}/skills/converting-content/scripts/lmstudio-translate.py translate \
    --model <選択したモデル名>
```

#### Step 4: エラーハンドリング

API が失敗した場合、**フォールバックは行わない**。ユーザーに以下を通知する:

> LM Studio の API がエラーを返しています。
> LM Studio が起動中でモデルがロードされていることを確認してください。
> 準備ができたらお知らせください。

準備完了の連絡を受けてから翻訳を再試行する。

### 翻訳時の注意事項

- **技術用語はそのまま英語で保持する**: サービス名・プロダクト名・コマンド名・ライブラリ名など
- **直訳ではなく自然な日本語にする**: 文脈に応じて意訳を選ぶ
- **原文の意味を変えない**: ニュアンスや強調・構造を保持する
