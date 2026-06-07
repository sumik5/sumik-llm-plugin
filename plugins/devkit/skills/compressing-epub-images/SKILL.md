---
name: compressing-epub-images
description: |
  EPUB ファイル内の画像（主にスキャン本の JPEG）を再エンコード・リサイズしてファイルサイズを削減するスキル。AskUserQuestion で圧縮レベル選択フローを提供し、実測サンプリングから予測サイズを提示してからユーザーに選ばせる。
  Use when: EPUB ファイルが大きく画像圧縮で削減したい時、スキャン本（画像ベース EPUB）の容量を減らしたい時、Kindle などの電子書籍リーダーに転送する前にサイズ最適化したい時。
  画像ベース EPUB（スキャン本）と通常 EPUB の両方に対応。書誌情報・xhtml・css は触らず画像のみ再エンコード。For OCR text conversion use converting-content; for Anki flashcards use creating-flashcards.
---

## 目的

EPUB ファイルの容量の 95% 以上は画像（JPEG）が占めるケースが多い。特にスキャン本（資格試験対策本・学術書・技術書）は 1 ページ 1 JPEG で構成されているため、JPEG 品質値（quality）を下げるだけで劇的にサイズが削減できる。

代表的な効果の例:
- 203 MB の EPUB が quality 70・解像度維持で約 145 MB（約 29% 削減）に
- quality 60 + 1080px リサイズで約 90 MB（約 55% 削減）まで圧縮可能

ただし JPEG の再エンコードは不可逆処理。元ファイルは必ず保持すること。

---

## ワークフロー（5 ステップ）

### Step 1: EPUB を一時ディレクトリに展開

EPUB は ZIP 形式のアーカイブ。`unzip` で展開する。

```bash
EPUB_PATH="/path/to/book.epub"
WORK_DIR=$(mktemp -d)
unzip -q "$EPUB_PATH" -d "$WORK_DIR"
echo "展開先: $WORK_DIR"
```

### Step 2: 画像構成の分析

画像ファイルの枚数・代表解像度・現在の quality を確認する。

```bash
# JPEG・PNG の一覧と枚数
find "$WORK_DIR" -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' | wc -l

# 代表的な 3 枚の解像度と現在の quality を確認
find "$WORK_DIR" -iname '*.jpg' -o -iname '*.jpeg' | head -3 | while read f; do
  magick identify -verbose "$f" | grep -E "Image:|Geometry:|Quality:"
done

# ファイルサイズの合計（MB）
find "$WORK_DIR" -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
  -exec du -k {} + | awk '{sum+=$1} END {printf "画像合計: %.1f MB\n", sum/1024}'
```

### Step 3: サンプリングによる圧縮予測

10 枚程度の代表サンプルを複数の圧縮設定で実測し、全体のサイズを予測する。

```bash
# 均等サンプリング（10 枚）
TOTAL=$(find "$WORK_DIR" -iname '*.jpg' -o -iname '*.jpeg' | wc -l)
STEP=$(( TOTAL / 10 ))
SAMPLES=$(find "$WORK_DIR" -iname '*.jpg' -o -iname '*.jpeg' | sort | awk "NR % $STEP == 0")

# 各圧縮レベルで実測（サンプル 10 枚の合計サイズ → 全体予測）
SAMPLE_ORIG=0
SAMPLE_Q70=0
SAMPLE_Q60=0
SAMPLE_R1080Q70=0
SAMPLE_R1080Q60=0

SAMPLE_TMP=$(mktemp -d)
for f in $SAMPLES; do
  orig=$(du -k "$f" | cut -f1)
  SAMPLE_ORIG=$((SAMPLE_ORIG + orig))

  base=$(basename "$f")

  magick "$f" -quality 70 "$SAMPLE_TMP/q70_${base}.new" && mv "$SAMPLE_TMP/q70_${base}.new" "$SAMPLE_TMP/q70_${base}"
  magick "$f" -quality 60 "$SAMPLE_TMP/q60_${base}.new" && mv "$SAMPLE_TMP/q60_${base}.new" "$SAMPLE_TMP/q60_${base}"
  magick "$f" -resize '1080x1530>' -quality 70 "$SAMPLE_TMP/r70_${base}.new" && mv "$SAMPLE_TMP/r70_${base}.new" "$SAMPLE_TMP/r70_${base}"
  magick "$f" -resize '1080x1530>' -quality 60 "$SAMPLE_TMP/r60_${base}.new" && mv "$SAMPLE_TMP/r60_${base}.new" "$SAMPLE_TMP/r60_${base}"

  SAMPLE_Q70=$((SAMPLE_Q70 + $(du -k "$SAMPLE_TMP/q70_${base}" | cut -f1)))
  SAMPLE_Q60=$((SAMPLE_Q60 + $(du -k "$SAMPLE_TMP/q60_${base}" | cut -f1)))
  SAMPLE_R1080Q70=$((SAMPLE_R1080Q70 + $(du -k "$SAMPLE_TMP/r70_${base}" | cut -f1)))
  SAMPLE_R1080Q60=$((SAMPLE_R1080Q60 + $(du -k "$SAMPLE_TMP/r60_${base}" | cut -f1)))
done

# 全体サイズ（JPEG 合計）から予測
EPUB_SIZE=$(du -m "$EPUB_PATH" | cut -f1)
RATIO_Q70=$(awk "BEGIN {printf \"%.2f\", $SAMPLE_Q70 / $SAMPLE_ORIG}")
RATIO_Q60=$(awk "BEGIN {printf \"%.2f\", $SAMPLE_Q60 / $SAMPLE_ORIG}")
RATIO_R70=$(awk "BEGIN {printf \"%.2f\", $SAMPLE_R1080Q70 / $SAMPLE_ORIG}")
RATIO_R60=$(awk "BEGIN {printf \"%.2f\", $SAMPLE_R1080Q60 / $SAMPLE_ORIG}")

echo "軽圧縮(q70)    予測: $(awk "BEGIN {printf \"%.0f\", $EPUB_SIZE * $RATIO_Q70}") MB"
echo "標準圧縮(q60)  予測: $(awk "BEGIN {printf \"%.0f\", $EPUB_SIZE * $RATIO_Q60}") MB"
echo "強圧縮+リサイズ(1080p+q70) 予測: $(awk "BEGIN {printf \"%.0f\", $EPUB_SIZE * $RATIO_R70}") MB"
echo "最大圧縮(1080p+q60) 予測: $(awk "BEGIN {printf \"%.0f\", $EPUB_SIZE * $RATIO_R60}") MB"

rm -rf "$SAMPLE_TMP"
```

### Step 4: AskUserQuestion で圧縮レベルを選択させる

サンプリング結果をもとに AskUserQuestion を呼び出す。

**AskUserQuestion 第 1 問: 圧縮レベル**

```
question: |
  EPUB の圧縮レベルを選択してください。

  現在のサイズ: 203 MB（例）

options:
  - value: "light"
    label: "軽圧縮"
    preview: |
      解像度  : 維持（元のまま）
      品質    : quality 70
      予測    : 145 MB（29% 削減）
      削減量  : 58 MB
      用途    : 印刷・PC 閲覧・画質優先

  - value: "standard"
    label: "標準圧縮"
    preview: |
      解像度  : 維持（元のまま）
      品質    : quality 60
      予測    : 130 MB（36% 削減）
      削減量  : 73 MB
      用途    : タブレット閲覧・バランス重視

  - value: "strong"
    label: "強圧縮 + リサイズ"
    preview: |
      解像度  : 1080px に縮小（大きい画像のみ）
      品質    : quality 70
      予測    : 104 MB（49% 削減）
      削減量  : 99 MB
      用途    : スマートフォン・Kindle・容量節約

  - value: "max"
    label: "最大圧縮"
    preview: |
      解像度  : 1080px に縮小（大きい画像のみ）
      品質    : quality 60
      予測    :  91 MB（55% 削減）
      削減量  : 112 MB
      用途    : ストレージ最優先・転送用途
```

**AskUserQuestion 第 2 問: 出力方式**

```
question: 出力方式を選択してください。

options:
  - value: "new_file"
    label: "別ファイルに保存（推奨）"
    preview: |
      元ファイルを保持したまま
      book_compressed.epub を新規作成
      元に戻せる（安全）

  - value: "overwrite"
    label: "上書き"
    preview: |
      元ファイルを置き換える
      元に戻せない
      ストレージを節約したい場合に

  - value: "backup_overwrite"
    label: "バックアップ後に上書き"
    preview: |
      book.epub.bak を作成してから上書き
      中間的な安全策
      ストレージに余裕がある場合に推奨
```

### Step 5: 並列圧縮 → 再 zip → 出力

```bash
# ---- 圧縮レベルに応じた MAGICK_ARGS を設定 ----
case "$COMPRESS_LEVEL" in
  light)    MAGICK_ARGS="-quality 70" ;;
  standard) MAGICK_ARGS="-quality 60" ;;
  strong)   MAGICK_ARGS="-resize 1080x1530> -quality 70" ;;
  max)      MAGICK_ARGS="-resize 1080x1530> -quality 60" ;;
esac

# ---- 全 JPEG を並列圧縮（8 並列）----
find "$WORK_DIR" -iname '*.jpg' -o -iname '*.jpeg' | \
  xargs -P 8 -I{} bash -c \
    'magick "$1" '"$MAGICK_ARGS"' "$1.new" && mv "$1.new" "$1"' _ {}

# ---- mimetype を先頭・無圧縮格納で再 zip ----
# !! EPUB 規格: mimetype は必ず先頭・無圧縮でなければならない !!
OUTPUT_EPUB="/path/to/book_compressed.epub"
cd "$WORK_DIR"
zip -X0 "$OUTPUT_EPUB" mimetype          # 先頭・無圧縮（-X: extra field 除去, -0: 圧縮なし）
zip -r  "$OUTPUT_EPUB" . --exclude mimetype  # 残りのファイルを追加

echo "完了: $OUTPUT_EPUB"
du -mh "$OUTPUT_EPUB"
```

---

## AskUserQuestion 設計の解説

preview 文字列はモノスペース的な整形で 5〜8 行に収めること。長すぎると UI で表示が崩れる。

各オプションの preview に必ず含めるべき 5 要素:
1. **解像度** — 維持か縮小か、縮小幅
2. **品質** — quality 値
3. **予測サイズ** — 実測サンプリングから算出した数値と削減率
4. **削減量** — MB 単位
5. **用途** — どんなシナリオに向いているか

実測ベースの予測値を提示することで、ユーザーが期待値を持って選択できる。

---

## 重要な落とし穴

### 1. EPUB 再 zip 時は mimetype を必ず先頭・無圧縮格納

```bash
# 正しい手順
zip -X0 output.epub mimetype          # mimetype を先頭・無圧縮で追加
zip -rq output.epub . --exclude mimetype  # 残りのファイルを圧縮で追加

# NG: 通常の zip は mimetype を圧縮してしまう（EPUB リーダーが拒否）
zip -r output.epub .
```

EPUB 規格（OPS 2.0 / EPUB 3）では `mimetype` ファイルを ZIP 内の最初のエントリとして非圧縮で格納することが必須。これを破ると Kindle・楽天 kobo・iBooks 等の主要リーダーがファイルを開けなくなる。

### 2. JPEG の再エンコードは不可逆

既に quality=76 で保存された JPEG を quality=76 で再エンコードしても画質は元通りにならない（劣化は蓄積する）。必ずオリジナルファイルを保持した上で圧縮すること。

### 3. 出力先を入力と同じパスにしない

`magick input.jpg -quality 70 input.jpg` のように同じパスを指定すると、処理途中にファイルが壊れることがある。必ず `.new` サフィックスを経由して `mv` する。

```bash
# 正しいパターン
magick "$f" -quality 70 "$f.new" && mv "$f.new" "$f"

# 危険なパターン（破損リスクあり）
magick "$f" -quality 70 "$f"
```

### 4. PNG が含まれる場合は別処理

JPEG 圧縮とは別に `pngquant` で処理する。

```bash
# PNG は pngquant で圧縮
find "$WORK_DIR" -iname '*.png' | \
  xargs -P 4 -I{} pngquant --force --quality=65-80 --output {} {}
```

### 5. リサイズ時は `>` 修飾子で「大きい画像のみ縮小」を保証

`-resize 1080x1530` は画像を必ず指定サイズに変更する。元画像が既に小さい場合に拡大されてしまう。`>` を付けることで「それより大きい場合のみ縮小」という挙動になる。

```bash
# 正しい: 大きい画像のみ縮小
magick "$f" -resize '1080x1530>' -quality 70 "$f.new"

# NG: 小さい画像も拡大してしまう
magick "$f" -resize '1080x1530' -quality 70 "$f.new"
```

---

## コマンドリファレンス

### EPUB 展開

```bash
EPUB_PATH="/path/to/book.epub"
WORK_DIR=$(mktemp -d)
unzip -q "$EPUB_PATH" -d "$WORK_DIR"
ls "$WORK_DIR"
```

### サンプリング予測（10 枚 × 4 レベル）

```bash
SAMPLE_TMP=$(mktemp -d)
find "$WORK_DIR" -iname '*.jpg' | sort | awk 'NR%10==0' | head -10 > /tmp/samples.txt

while IFS= read -r f; do
  base=$(basename "$f")
  for cfg in "q70:-quality 70" "q60:-quality 60" \
             "r70:-resize 1080x1530> -quality 70" \
             "r60:-resize 1080x1530> -quality 60"; do
    label="${cfg%%:*}"
    args="${cfg#*:}"
    magick "$f" $args "$SAMPLE_TMP/${label}_${base}.new" \
      && mv "$SAMPLE_TMP/${label}_${base}.new" "$SAMPLE_TMP/${label}_${base}"
  done
done < /tmp/samples.txt

# 各レベルの合計サイズ（KB）
for label in q70 q60 r70 r60; do
  total=$(find "$SAMPLE_TMP" -name "${label}_*" -exec du -k {} + | awk '{s+=$1} END{print s}')
  echo "$label: ${total} KB（サンプル 10 枚合計）"
done
rm -rf "$SAMPLE_TMP"
```

### 全画像並列圧縮（xargs -P 8）

```bash
# JPEG のみ quality 70 で圧縮
find "$WORK_DIR" -iname '*.jpg' -o -iname '*.jpeg' | \
  xargs -P 8 -I{} bash -c \
    'magick "$1" -quality 70 "$1.new" && mv "$1.new" "$1"' _ {}
```

### リサイズ + 圧縮の組み合わせ

```bash
# 1080px に縮小（大きい画像のみ）+ quality 60
find "$WORK_DIR" -iname '*.jpg' -o -iname '*.jpeg' | \
  xargs -P 8 -I{} bash -c \
    'magick "$1" -resize '"'"'1080x1530>'"'"' -quality 60 "$1.new" && mv "$1.new" "$1"' _ {}
```

### mimetype 先頭の安全な再 zip 手順

```bash
OUTPUT_EPUB="book_compressed.epub"
cd "$WORK_DIR"

# 1. mimetype を先頭・無圧縮（-X0）で追加
zip -X0 "$OUTPUT_EPUB" mimetype

# 2. mimetype 以外をすべて追加
zip -rq "$OUTPUT_EPUB" . --exclude mimetype

# 3. 検証: mimetype が先頭にあることを確認
unzip -l "$OUTPUT_EPUB" | head -5

cd -
```

### PNG の圧縮（pngquant）

```bash
find "$WORK_DIR" -iname '*.png' | \
  xargs -P 4 -I{} pngquant --force --quality=65-80 --output {} {}
```

---

## 品質判定の目安

| 用途 | 推奨 quality | 備考 |
|------|-------------|------|
| スキャン本（資格試験・学術書） | 65〜70 | quality 65 以下で文字判読性が低下し始める |
| マンガ・イラスト本 | 70〜75 | 線や色の再現性が重要 |
| 写真集・ビジュアル本 | 80 | 劣化が視覚的に目立ちやすい |
| Kindle 転送用（最小化優先） | 60 | 文字主体なら実用上問題ない範囲 |

---

## 前提ツール

| ツール | 用途 | インストール |
|-------|------|------------|
| `unzip` / `zip` | EPUB 展開・再 zip | OS 標準または `brew install zip` |
| `magick`（ImageMagick） | JPEG 再エンコード・リサイズ | `brew install imagemagick` |
| `pngquant` | PNG 圧縮 | `brew install pngquant` |
| `xargs` | 並列実行 | OS 標準 |

macOS の場合、`magick` は `brew install imagemagick` でインストールできる。`convert` コマンドは ImageMagick v7 以降では `magick` に統合されている。

---

## 出力方式の処理例

```bash
case "$OUTPUT_MODE" in
  new_file)
    OUTPUT_EPUB="${EPUB_PATH%.epub}_compressed.epub"
    ;;
  overwrite)
    OUTPUT_EPUB="$EPUB_PATH"
    ;;
  backup_overwrite)
    cp "$EPUB_PATH" "${EPUB_PATH}.bak"
    OUTPUT_EPUB="$EPUB_PATH"
    ;;
esac
```
