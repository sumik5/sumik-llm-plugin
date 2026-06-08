# OCR変換ガイド（画像ベースPDF/EPUB → Markdown）

スキャン本（本文がページ画像のPDF/EPUB）をローカルOCRして Markdown 化する手順。Step 1 の変換フェーズで、テキスト抽出が本文を取れない場合に使う。OCRエンジンは2系統を同梱する。

## 0. エンジンの選択（🔴 第一選択は Apple Vision）

| エンジン | スクリプト | 速度 | 特性 | 使う場面 |
|---------|-----------|------|------|---------|
| **Apple Vision（既定）** | `${CLAUDE_SKILL_DIR}/scripts/ocr-apple-vision` | **約1〜2秒/ページ** | Neural Engine のネイティブOCR。LLMでないため思考ログ漏洩・反復崩壊が皆無。テキスト＋座標を返し列再構成で読み順回復。表・2D図は構造化されず生テキスト | **まずこれ**。Q&A中心・単段組・本文＋右サイドバー構成のスキャン本 |
| VLM（フォールバック） | `${CLAUDE_SKILL_DIR}/scripts/recognize-image-to-markdown` | 約22秒/ページ | ローカルVLM。低速だがMarkdownテーブル・見出しを文脈理解で再現 | 表・複雑レイアウトの**忠実な構造再現が品質に直結**するソースのみ |

> 実測比較（同一ページ・危険物テキスト）: Apple Vision 1.77秒 vs VLM 約22秒（**約12倍速**）。全2,380ページ規模ではVLM約15時間に対しVision約1〜1.5時間（OCR）＋ラスタライズ。Visionは脱字が軽微に出る・2D図は断片化するが、Q&A抽出に必要なテキストは取れる。

---

## Apple Vision OCR（既定・高速）

ツール: `${CLAUDE_SKILL_DIR}/scripts/ocr-apple-vision`（同梱・`ocrmac` 経由で `VNRecognizeTextRequest` を呼ぶ）。

```bash
# スキャンPDF（自動でpdftoppmラスタライズ→Vision OCR→列再構成→Markdown・resume内蔵）
${CLAUDE_SKILL_DIR}/scripts/ocr-apple-vision <input.pdf> -o /tmp/<name>.md
# 画像ディレクトリ / 単一画像も可
${CLAUDE_SKILL_DIR}/scripts/ocr-apple-vision ./scanned-pages/ -o /tmp/<name>.md
```

| オプション | 用途 |
|-----------|------|
| `--lang ja-JP,en-US` | 認識言語（ロケール完全形。`ja`/`en` 不可） |
| `--level accurate\|fast` | 精度（既定 accurate） |
| `--pdf-dpi N` | ラスタライズ解像度（既定200。下げると速いが小字が落ちやすい） |
| `--col-gap F` | 右サイドバー検出のxギャップ閾値（既定0.08）。`0` で単段組固定 |
| `--min-confidence F` | 信頼度未満ブロックを捨てる（既定0.0=全採用） |
| `--no-resume` | キャッシュ無視で最初から |

### 🔴 列再構成（多段組の読み順回復・Vision品質の鍵）

Vision は「テキスト＋バウンディングボックス(x,y,w,h・正規化・左下原点)」を返すだけでレイアウトを理解しない。素朴にy降順で並べると、本文と右サイドバー（用語/重要ボックス）が**行単位で交互混入して崩れる**。

スクリプトは **右サイドバー検出**で対処する: 右領域（x ≥ 0.5）で最大のxギャップを探し、閾値以上ならそこを本文／サイドバー境界として2列に分け、各列を上→下（y降順）に整列して左→右に連結する。右領域に独立塊が無ければ単段組（1列）として扱う。

> ⚠️ 汎用N列クラスタリング（x-startのギャップ分割）は**2D図が中間xを埋めると1列に collapse して破綻**する（実観測）。対象書籍は「単段組Q&A」か「本文＋右サイドバー」の二択がほぼ全てなので、右サイドバー検出に特化する方が堅牢。左サイドバーや3列以上の特殊レイアウトでVision出力が崩れたら、そのソースだけVLM(recognize-image-to-markdown)へ切り替える。

### 前提

- macOS 12+（日本語Vision対応）／Apple Silicon推奨
- `poppler`（`pdftoppm`）: PDFラスタライズ時
- `ocrmac` Pythonパッケージ（無ければスクリプトが自動pip導入）

---

## VLM OCR（フォールバック・高忠実）

以下は表・複雑レイアウトの忠実再現が要る場合のVLM方式。ツールは `${CLAUDE_SKILL_DIR}/scripts/recognize-image-to-markdown`（同梱）。

---

## 1. 画像ベースかの判定（最初に必ず実施）

スキャン本はテキスト層を持たず、`pdf-to-markdown`・`pandoc` では**目次・奥付しか取れない**。

| シグナル | 判定 |
|---------|------|
| ページ数の割に抽出が極端に小さい（例: 529ページで 4KB・目次のみ） | 画像ベース → OCR必須 |
| `pdftotext <pdf> -` の総文字数 ÷ ページ数 が 50字未満 | 画像ベース |
| 抽出結果に本文（問題・解説）が無く見出し列だけ | 画像ベース |

```bash
# ページ数（macOS）
mdls -name kMDItemNumberOfPages "<input.pdf>"
# 抽出サイズの目安（小さすぎたら画像ベース）
${CLAUDE_PLUGIN_ROOT}/scripts/pdf-to-markdown "<input.pdf>" /tmp/probe.md && wc -lc /tmp/probe.md
```

> `recognize-image-to-markdown` は PDF を渡すと**自動で判定**し、テキストPDFは `pdftotext` で直接変換、スキャンPDFは `pdftoppm`＋VLM-OCR にフォールバックする。確実にOCRさせたいときは `--pdf-force-ocr`。

---

## 2. 前提（OCR実行に必要なもの）

- **LM Studio** が起動していること（ローカルサーバ）
- **vision 対応モデル**がダウンロード済みであること（`vision=True`）
- `poppler`（`pdftotext`・`pdftoppm`）・`Pillow`・`lmstudio` Pythonパッケージ（無ければスクリプトが pip 導入を試みる）

---

## 3. モデル選択（🔴 非対話実行では `--model` 必須）

バックグラウンド／非TTY実行では `--model <key>` を**必ず**渡す（未指定だと対話メニューを出せずエラー終了する）。`<key>` は **vision=True** のモデルキー。

```bash
# ダウンロード済み vision モデルのキーを列挙
python3 - <<'PY'
import lmstudio as lms
def info(m,a):
    i=getattr(m,"info",None)
    return (getattr(i,a,None) if i is not None else None) or getattr(m,a,None)
for m in lms.list_downloaded_models():
    if info(m,"type")=="llm" and info(m,"vision") is True:
        print(info(m,"model_key"), "| params=", info(m,"params_string"))
PY
```

### 🔴 reasoning モデルの「思考ログ漏洩」罠（モデル選択の最重要ポイント）

一部の reasoning 系 vision モデルは、思考プロセスを**本文と分離できず OCR 出力に丸ごと漏洩**させる。

| 観測 | 内容 |
|------|------|
| 症状 | 出力先頭に英語の思考ログ（`Task:` `Constraint 1:` `Header:` …）が混入。`<\|channel>thought … <channel\|>` 形式のマーカーで囲まれることがある |
| 原因 | ツールの `strip_think_tags` は `<think>…</think>` 専用。`<\|channel>…<channel\|>` 等の別形式は剥がせず、汚染検出アンカーにも非一致のため再OCRも発動しない |
| 副作用 | 本文の数倍のトークンを毎ページ生成 → **OCRが3〜6倍遅くなる**。実測で1ページ16分（健全モデルは20〜25秒）に達したケースあり |

**対策**:
- **思考分離がクリーンなモデルを選ぶ**（LM Studio が reasoning を別チャネルに分離でき、`result.content` に本文のみ返すもの）。MoE系の中規模 vision モデルは速度・品質のバランスが良い。
- 本実行前に**必ず1ページのスモークテスト**（§5）で「思考ログが混入していないか」を目視確認する。
- どうしても reasoning モデルしか使えない場合は、`parse()` 側で `re.sub(r'<\|channel>.*?<channel\|>', '', text, flags=re.DOTALL)` 等の channel ストリップを追加し、かつ低速を許容する。

### モデルの事前ロード（reload churn 回避）

OCR実行中に別モデルがロードされると稼働中モデルが追い出され、`reload N/5` を繰り返して大幅に遅延する。実行前に対象モデルを明示ロードし、**実行中は LM Studio に触れない**（他モデルのスモークテスト等で追い出さない）。

```bash
lms unload --all
lms load "<vision-model-key>" --yes   # ttl は継続OCR中はアイドルにならないため失効しない
```

---

## 4. 実行（バックグラウンド＋resume）

```bash
# 単一PDF（スキャン本）
${CLAUDE_SKILL_DIR}/scripts/recognize-image-to-markdown \
  "<input.pdf>" -o /tmp/<descriptive-name>.md \
  --model "<vision-model-key>" --pdf-force-ocr
```

長時間（数百ページ＝数時間）になるため **`run_in_background: true`** で投入し、完了通知を待つ。

### resume（中断再開）の仕組み

| 仕組み | 説明 |
|--------|------|
| `.complete` マーカー | 変換完了の印。存在すれば再実行時にスキップ |
| `.progress.d/` | ページ単位のキャッシュ（アトミック書き込み）。再実行で OCR 済みページを再処理しない |
| 再開方法 | **同じ `-o` 出力パスで再実行するだけ**。セッションが切れて background ジョブが死んでも、再起動すれば続きから |
| `--no-resume` | キャッシュを捨てて最初からやり直す |

> 🔴 **1冊の途中でモデルを切り替えない**: resume は既存ページ（旧モデルOCR）を保持し残りを新モデルでOCRするため、**1冊にOCRモデルが混在**する。モデルを変えるなら `--no-resume` でその冊子を最初からやり直す。
>
> ⚠️ **ラスタライズはキャッシュされない**: スキャンPDFは再起動のたびに全ページを `pdftoppm` で再描画する（OCRページキャッシュとは別）。中断・再開のコストに織り込む。

### 主なオプション

| オプション | 用途 |
|-----------|------|
| `--pdf-force-ocr` | テキスト埋め込みでもOCRを強制（スキャン確定時） |
| `--pdf-dpi N` | ラスタライズ解像度（既定200） |
| `--max-image-size N` | VLM送信前の長辺リサイズpx（既定1280・0で無効） |
| `--no-ocr-cleanup` | 思考ログ除去・反復崩壊検出・自動再OCRを無効化（通常はON推奨） |
| `--no-skip-blank` | 空白ページスキップを無効化 |

---

## 5. スモークテスト（本実行前の品質ゲート・必須）

数百ページに賭ける前に、**1ページだけ OCR して品質と速度を実測**する。

```bash
# 進行中の本実行があれば、その中間PNG（pdftoppm出力）を退避して単体OCR、
# もしくは pdftoppm で数ページだけ描画して1枚OCRする
pdftoppm -png -r 200 -f 45 -l 45 "<input.pdf>" /tmp/smoke/page
${CLAUDE_SKILL_DIR}/scripts/recognize-image-to-markdown /tmp/smoke/page-45.png --model "<vision-model-key>"
cat /tmp/smoke/page-45.md
```

確認項目:
- [ ] 日本語（漢字・カタカナ・記号 ○×）が正確に転写されているか
- [ ] **思考ログ（`Task:`/`Constraint`/`<\|channel>` 等）が混入していないか** ← reasoning モデルの罠
- [ ] 表が Markdown テーブル化されているか
- [ ] 1ページの所要時間（健全なら20〜30秒程度）

> 本文ページ（テキスト主体）と問題ページ（○×・選択肢）の両方をサンプリングすると、記号・選択肢の崩れも検出できる。

---

## 6. 速度・規模の目安

| 項目 | 目安 |
|------|------|
| 健全な vision モデル | 約20〜25秒/ページ |
| ラスタライズ（200 DPI） | 約15〜20ページ/分（CPU・PDFサイズ依存） |
| 数百ページの冊子 | ラスタライズ＋OCRで数時間 |

複数冊を順次処理する場合、OCR（VLM・GPU）とパース＆投入（Python・Anki・CPU）は競合しないため、**Book N の投入中に Book N+1 のOCRをバックグラウンド起動**するパイプラインが有効。ただしVLMは単一モデルで逐次処理のため、OCR自体は並列化しない。

---

## 7. 変換後（Step 3 へ渡す前）

- 🔴 **巨大OCR Markdown を `Read` で全文読みしない**（[INSTRUCTIONS.md](../INSTRUCTIONS.md) Step 1 のトークン予算注意参照）。`wc`/`grep -n`/`sed -n` で構造把握 → 抽出は `parse()` に委譲。
- OCR残存汚染（思考ログ・反復崩壊）のサルベージは `parser_scaffold.py` の `strip_thinking_logs` / `collapse_repeated_lines`、高度サルベージは [CONTENT-BY-TYPE.md](CONTENT-BY-TYPE.md) の「OCR汚染対策」。

---

## 8. Apple Vision の弱点と VLM 併用（実観測）

Apple Vision は高速だがレイアウトを理解しない純OCR。以下の弱点はパーサー側の対処か、該当ページだけ VLM 併用で補う。

### サイドバートピック名の本文混入

段組ページの欄外トピック名（「物質の三態」等の短い名詞句）や用語/重要ボックスが、列再構成後も本文行間に注入されることがある（右サイドバー検出が拾えない左欄・狭い欄）。パーサーの設問クリーニングで「7字以下・句読点/括弧/。なし・かな漢字のみの独立行」を除去する（[CONTENT-BY-TYPE.md](CONTENT-BY-TYPE.md) の〇✕テスト型 手順5）。

### 🔴 表・2D図の崩壊 → 該当ページのみ VLM 再OCR（ハイブリッド）

表（比較表・データ表）や樹形図など2D構造は、Vision では行・列が分解されて意味が崩れる。**全書を遅い VLM で再OCRするのは非効率**。表を含むページ（多くは章末まとめ問題・巻末模擬試験のMCQ）だけを VLM で再OCRし、表をテキスト化する:

1. **対象PDFページの逆算**: Vision出力Markdownはページ境界 `---` で区切られる。対象セクション先頭行までの `^---$` 個数 ≒ markdownページindex。Vision は空白ページをスキップする（例: 529→524）ため、**PDFページ ≈ markdownページindex + 先行スキップ分**。前後にマージンを取って範囲を決める。印刷ページ番号アンカー（本文中の `^\d{3}$` 行）も併用して範囲を裏取りする。
2. **範囲をラスタライズして VLM 再OCR**: `pdftoppm -png -r 200 -f <開始> -l <終了> <pdf> <dir>/page` で画像化 → `recognize-image-to-markdown <dir> -o <out>.md --model "<vision-model-key>"`（ディレクトリ入力モード）。例: 模擬試験 問題編28ページのみVLM再OCR＝約10分。
3. **解答編は Vision のままでよい**: 解答・解説はテキスト主体（`問題N 解答（X）` ＋〔解説〕）で Vision でもクリーンなことが多い。問題編（表入り）だけ VLM 再OCRし、解答は Vision 出力と番号照合する（問題編VLM＋解答編Visionのハイブリッド）。
4. **VLM と Vision の併走**: VLM(LM Studio/Metal GPU) と Apple Vision(Neural Engine/CPU) は実行ユニットが異なり、メモリに余裕があれば並行実行できる（Vision連鎖で他冊をOCRしながら特定冊のMCQページをVLM再OCR、等）。

> 代替: 表を含む設問を `needs_fix` タグ付きで投入し（toolkitが⚠️要手修正div＋`_要手修正`タグを自動付与）、後でまとめて VLM 補完する運用も可。
