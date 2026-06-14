# RENDERING: 実バイナリレンダリング経路（opt-in）

このファイルは `answering-genai-exam` スキルの **opt-in 拡張**。提出物が画像系（`.png`/`.jpg` 等）や PDF の小問について、既定の「指示文のみ（`_画像生成指示.md`）」を超えて **実際のバイナリ（実PNG / 実PDF）を生成** する手順・ツールチェーン・既知の罠・検証をまとめる。

> **位置づけ（重要）**: 既定は常に「指示文のみ」。実バイナリ生成は **Step 2 の AskUserQuestion でユーザーが「実画像もレンダリング」を選んだ場合のみ** 行う。試験の提出物名が `q1_2.png` のように実ファイルを要求する場合、実PNGの提出が要件に最も忠実になるため、この経路を用意する。
>
> **実行主体**: レンダリングは **Bash が使える呼び出し側（本体）または exam-solver** が、求解（Step 4）の後の **Step 4.5（後段パス）** として行う。Workflow の標準 agent はツールチェーンの有無が不定なため、**並列 worker 内ではレンダリングしない**（worker は指示文/原稿md を出すだけ）。

---

## 0. 前提ツールチェーンの検出（レンダリング前に必ず）

レンダリングは外部 CLI に依存する。実行前に在庫を確認し、無ければ「指示文のみ」へフォールバックして報告に明記する。

```bash
for t in pandoc xelatex lualatex rsvg-convert magick dot pdftotext fc-list; do
  command -v "$t" >/dev/null 2>&1 && echo "OK  $t" || echo "NO  $t"
done
```

| 用途 | 必要ツール | 代替/備考 |
|------|-----------|----------|
| md → PDF | `pandoc` + `xelatex`（または `lualatex`） | CJK 対応エンジン必須 |
| 図 SVG → PNG | `rsvg-convert` | `magick`/`convert` でも可 |
| グラフ構造図 | `dot`（Graphviz） | ノード/エッジ主体の図に |
| グリフ脱落検証 | `pdftotext`（`-enc UTF-8`） | PDF 検証の要 |
| 利用可能 CJK フォント列挙 | `fc-list :lang=ja` | フォント名特定に |

> `mermaid-cli`（`mmdc`）は入っていない環境が多い。**`mmdc` に依存しない**（図は手書き SVG → `rsvg-convert` が最も確実）。

---

## 1. md → 実PDF（日本語対応）

`.md` 提出物（回答本文）や原稿を PDF 化する。

```bash
# 画像を含む md は、画像と同じディレクトリで実行（相対パス解決のため）
pandoc <src>.md -o <basename>.pdf \
  --pdf-engine=xelatex \
  -V CJKmainfont="<CJKフォント名>" \
  -V mainfont="<CJKフォント名>" \
  -V geometry:margin=18mm \
  -V fontsize=10pt
```

- **CJK フォント名** は環境で選ぶ。`fc-list :lang=ja family` で候補を確認し、ゴシック系（本文）を指定する。明朝系もあれば見出し等に使える。
- `markdown` の `![](img.png){width=98%}` は xelatex の includegraphics に変換される。**画像とソースを同じディレクトリに置き、そのディレクトリ内で `pandoc` を実行**する（相対パス解決）。
- 生成後は §3 のグリフ検証を必ず通す。

---

## 2. 図 → 実PNG（手書き SVG 経由）

比較図・構造図・概念図は、`_画像生成指示.md` の設計（描画要素・配置・矢印・ラベル）を **SVG として実体化** し、PNG へ変換するのが最も確実。

```bash
rsvg-convert -z 1.25 -b white -f png -o <basename>.png <basename>_src.svg
```

- `-z 1.25`（拡大率）・`-b white`（背景白）・`-f png`（出力形式）。
- SVG 内のテキストは **fontconfig 経由で CJK フォントが効く**（OS にインストール済みのものが使われる）。
- ノード/エッジ主体（依存グラフ・フロー）は Graphviz `dot` でも生成できる: `dot -Tpng in.dot -o out.png`。

---

## 3. 🔴 グリフ脱落の罠と検証（必ず実施）

CJK レンダリングでは、フォントに字形が無い文字が **「Missing character」警告すら出さずに静かに脱落**することがある（豆腐化・抽出不能）。

- **既知の脱落例**:
  - `✕`（U+2715）は多くの CJK フォントに字形が無い → **`×`（U+00D7）を使う**。
  - 一部の漢字も静かに脱落しうる（実例: `鍵` U+9375）。曖昧な漢字は **確実に出る語へ置換** するのが堅牢。
- **PDF の検証手順**（生成後に必ず）:

```bash
# 抽出テキストに、ソースの文字がすべて含まれているかを照合
pdftotext -enc UTF-8 <basename>.pdf - > /tmp/extracted.txt
# ソース md との CJK 文字集合差を取り、抽出側に無い文字＝脱落を炙り出す
python3 - <<'PY'
src = open("<src>.md", encoding="utf-8").read()
ext = open("/tmp/extracted.txt", encoding="utf-8").read()
def cjk(s): return {c for c in s if '぀' <= c <= '鿿' or '＀' <= c <= '￯'}
missing = sorted(cjk(src) - cjk(ext))
print("脱落候補:", missing if missing else "なし")
PY
```

- 「脱落候補」が出たら、その文字を含む語を確実な語へ置換し、再レンダリング → 再検証する。
- SVG→PNG では `pdftotext` が使えないため、**SVG ソース段階で危険なグリフ（U+2715 等）を排除**し、目視で豆腐がないか確認する。

---

## 4. ソース併置（再レンダリング可能に）

実バイナリは原稿を捨てると再生成できない。**原稿を併置**する。

- md → PDF: 原稿を `<basename>_src.md` として保存（PDF と同じ `answers/<問番号>/`）。`.md` 提出物本体と同一なら省略可。
- 図 → PNG: SVG を `<basename>_src.svg` として保存。
- これにより、後でフォント変更・誤字修正・グリフ置換をしても 1 コマンドで再生成できる。

---

## 5. ブランド名漏洩の全走査（成果物全体）

レンダリング有無に関わらず、**全成果物**（md・PDF から抽出したテキスト・SVG）に、試験を特定するブランド名・主催団体名・回次表記・書籍名・著者名・出版社名が**漏れていないか** grep で走査する。漏れていれば汎用表現へ置換し、PDF は再レンダリングする。

```bash
# 実行時にユーザーが把握している試験固有トークンを当てて全走査（トークンは各自のものに置換）
grep -rnE "<試験固有トークン1>|<試験固有トークン2>|主催|出版|著者" <answers dir> || echo "漏洩なし"
```

> 🔴 このスキル本文・成果物に **具体的なブランド名を書き込まない**こと自体が掟。grep の対象トークンは実行時にユーザーが把握している固有名を当てる。

---

## 6. レンダリング後の DoD 追加

- [ ] ツールチェーンを検出し、不足時は「指示文のみ」へフォールバックして報告した。
- [ ] md→PDF / 図→PNG を生成し、原稿（`_src.md` / `_src.svg`）を併置した。
- [ ] PDF は `pdftotext` でグリフ脱落を検証し、脱落ゼロを確認した（`✕`→`×` 等の置換済み）。
- [ ] 全成果物にブランド名・主催団体名・回次表記の漏洩がないことを grep で確認した。
