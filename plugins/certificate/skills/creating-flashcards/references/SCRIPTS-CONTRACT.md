# scripts ディレクトリ（投入インフラの契約）

`${CLAUDE_PLUGIN_ROOT}/skills/creating-flashcards/scripts/` の2層構成（[INSTRUCTIONS.md](../INSTRUCTIONS.md) の「投入インフラの利用（毎回の作業の前提）」節の概説を参照）の**契約定義**をここに集約する。`anki_toolkit.py` の実コード・`parser_scaffold.py` の雛形・本ファイルの3者で、`QAPair` フィールド名と公開API名は**完全一致**させる（ズレると投入が壊れる）。

## `QAPair` 中間表現（IR）スキーマ

`parse()` が返す問題1件の中間表現。`anki_toolkit.py` に `@dataclass` で定義されている。

| フィールド | 型 | 既定 | 用途 |
|-----------|-----|------|------|
| `front` | `str` | （必須・非空） | 整形前の問題本文。問題番号ヘッダー（「問N」等）は含めない |
| `back` | `str` | `""` | 整形前の解答/解説本文。🔴 raw HTML 素通し（toolkit は escape しない。`<table>` 等は parse 側が注入） |
| `qtype` | `str` | `"basic"` | `"choice"` / `"truefalse"` / `"basic"` のいずれか（他は `ValueError`） |
| `choices` | `list[str]` | `[]` | 選択肢型用。`["A. テキスト", "B. テキスト", ...]`（レター付き） |
| `correct` | `list[str]` | `[]` | 正解レター（`["A"]` / 複数正解 `["A","C"]`） |
| `wrong_explanations` | `dict` | `{}` | `{"B": "不正解解説", ...}`（レター→解説） |
| `verdict` | `str` | `""` | ○×型用。`"○"` / `"✕"` / `""`（空=判定マーカー欠落。`×→✕` / `〇→○` は toolkit が正規化） |
| `tags` | `list[str]` | `[]` | Anki タグ（階層は `::`、空白は `-`） |
| `knowledge_area` | `str` | `""` | 補助フィールド（`field_map["extra"]` の投入先） |
| `source_book` | `str` | `""` | 出典書籍名（Step5c）。空なら出典div出力しない |
| `source_page` | `str` | `""` | 出典ページ番号（Step5c）。空可 |
| `important` | `bool` | `False` | 重要マーカー（⭐重要表示 + タグ「重要」） |
| `needs_fix` | `bool` | `False` | 不完全カード（`_要手修正` タグ + 警告div） |
| `original_front` | `str` | `""` | 多言語用・原文問題（`<details>` 折りたたみ） |
| `original_back` | `str` | `""` | 多言語用・原文解答（`<details>` 折りたたみ） |
| `media` | `list[dict]` | `[]` | `[{"filename","data_b64"}]`。本文に `<img src="<filename>">` を埋めた上で実体を載せる。空なら `storeMediaFile` を呼ばない |

`RenderOptions`（HTMLレンダリング方針。Step5b の `modelTemplates` 確認結果を反映）:

| フィールド | 型 | 既定 | 用途 |
|-----------|-----|------|------|
| `choice_list_style` | `str` | `"ol"` | メイン選択肢の出力。`"ol"`=`<ol style="list-style-type:none"><li>`（シャッフルJS活用） / `"br"`=`<br>`区切り（li倍増テンプレ向け） |
| `details_choice_style` | `str` | `"br"` | `<details>` 原文内の選択肢。常に `"br"`（`<ol><li>` 倍増回避の固定ガード） |
| `front_field_is_choice_shuffle` | `bool` | `True` | 選択肢頭にレター（「ア.」「A.」等）を付与し、シャッフル後も内容で正解判定可能にする |

## `anki_toolkit.py` 公開API（サマリ）

| 関数 | シグネチャ（要点） | 役割 |
|------|------------------|------|
| `anki_request` | `(action, params=None) -> object` | AnkiConnect へ POST。error が配列なら `{"per_note_errors":[...]}`、文字列なら `RuntimeError` |
| `ensure_deck` | `(deck_name) -> None` | `createDeck`（冪等）。`addNotes` 前に必須 |
| `existing_fronts` | `(deck_name, front_field) -> set[str]` | 既存 Front 集合を実フィールド名で取得 |
| `filter_new` | `(notes, deck_name, front_field) -> (list, int)` | 既存と重複しない note のみ返す（実フィールド名で差分） |
| `dedup_deck` | `(deck_name, front_field) -> int` | 最古 noteId 残しで重複削除（事後 dedup の保険） |
| `build_note` | `(qa, deck_name, model_name, field_map, render=RenderOptions()) -> dict` | `QAPair` を addNotes 用 note に変換。`options` に `allowDuplicate:True`+`duplicateScope:"deck"` 自動付与 |
| `store_media` | `(qas) -> int` | `QAPair.media` を `storeMediaFile` で投入（同名上書き=冪等）。🔴 接頭辞なし filename は `ValueError` |
| `upload` | `(qas, deck_name, model_name, field_map, render=RenderOptions(), skip_existing=True) -> dict` | ensure_deck→store_media→build_note(全件)→filter_new→addNotes(50件ずつ)。戻り値 `{added, skipped_existing, media_stored, errors}` |
| `build_front_html` | `(qa, render=RenderOptions()) -> str` | Front HTML 生成（純関数） |
| `build_back_html` | `(qa, render=RenderOptions()) -> str` | Back HTML 生成（純関数・back は raw HTML 素通し） |
| `build_tags` | `(qa) -> list[str]` | `important→"重要"` / `needs_fix→"_要手修正"` を補完 |
| `is_code_like` | `(text) -> bool` | 翻訳スキップ判定 |
| `sample_cards` | `(deck_name, head=5, mid=5) -> list[dict]` | 先頭/中盤サンプル取得（Step7 用） |

モジュール定数: `BATCH_SIZE = 50`（投入バッチ件数）／ `MEDIA_PREFIX_RE = ^(?!image_rsrc)[A-Za-z0-9][A-Za-z0-9_-]*_`（メディア接頭辞の許可パターン。接頭辞なし汎用名 `image_rsrcXXX` を拒否し別ソースとのメディア衝突を防ぐ）。`field_map` のキーは `"front"`・`"back"` が必須、`"extra"`（`knowledge_area` の投入先）は任意。

## 🔴 機械可読 CONTRACT ブロック

以下のブロックは `QAPair` フィールド・`RenderOptions` フィールド・公開API名の**単一の真実**であり、`anki_toolkit.py` の実コードと完全一致する（検証コマンドがこのブロックを抽出して実コードと突き合わせる）。契約変更時はこのブロックと実コードを同時に更新する。

<!-- CONTRACT:BEGIN -->
QAPAIR_FIELDS: front,back,qtype,choices,correct,wrong_explanations,verdict,tags,knowledge_area,source_book,source_page,important,needs_fix,original_front,original_back,media
RENDEROPTIONS_FIELDS: choice_list_style,details_choice_style,front_field_is_choice_shuffle
PUBLIC_API: anki_request,ensure_deck,existing_fronts,filter_new,dedup_deck,build_note,store_media,upload,build_front_html,build_back_html,build_tags,is_code_like,sample_cards
<!-- CONTRACT:END -->

## 🔴 大量投入時のリクエスト間隔

`*_import.py` を100件超のファイルに対してシェルループで間隔なく連続投入すると、AnkiConnect 側の一時的な過負荷により `ConnectionResetError`・`Connection refused`（`urlopen error`）が一部発生しうる（実測: 264件中82件失敗。Anki本体プロセスは生存しており、AnkiConnect 側のキューあふれが原因と推測される）。失敗したファイルのみ抽出し、各リクエスト間に `sleep 0.5` を挟んで再実行したところ全件成功した（82/82）。100件超をループ投入する運用では、各呼び出し間に `sleep 0.5` 程度を挟むか、失敗したファイルのみ抽出して後段でリトライする前提で組むこと。

## 座標マッチング方式（`coordinate_marker_extract.py` / `coordinate_page_scaffold.py`）

見開き型レイアウト（本文列＝チェックボックス付き設問、マージン列＝座標分離された○×判定マーカー）向けの抽出エンジンと、そのページペアリング雛形。`anki_toolkit.py`/`parser_scaffold.py` と同じ「不変・育てる側」「雛形・コピーして使う側」の2層構成をこの方式にも適用したもの。

### `coordinate_marker_extract.py`（不変・育てる側）

外部依存: `ocrmac`, `Pillow`（`anki_toolkit.py` の外部依存ゼロとは異なる）。

| 関数 | シグネチャ（要点） | 役割 |
|------|------------------|------|
| `extract_practice_page` | `(image_path, col_split_x=0.72, y_tol=0.025) -> (questions, margin_markers)` | ページ画像を ocrmac で座標付きOCRし、設問と○×判定マーカーをy座標最近傍マッチングで紐付ける公開エントリポイント |
| `_build_questions` | `(main_col) -> list[dict]`（内部） | 本文列OCR結果からチェックボックス区切りの設問ブロックを構築 |
| `_ocr_main_column_at_scale` | `(image_path, col_split_x, scale) -> list`（内部） | 本文列のみを再OCR（截断された設問の救済リトライ用） |
| `_ocr_margin_column` | `(image_path, col_split_x) -> list`（内部） | マージン列のみを1x/2x/3xで再OCRし結果を統合（Visionの検出漏れ対策） |

`questions` の各要素（dict）が持つキー:

| キー | 型 | 内容 |
|------|-----|------|
| `statement` | `str` | 判定マーカー・出典を除去した設問本文。🔴 境界判定に使ったチェックボックス記号（口/□/■/ロ/コ/0/◎/o）は先頭に残ったまま返る——呼び出し側が投入前に1文字除去する契約（`coordinate_page_scaffold.py`参照） |
| `citation` | `str` | 抽出した出典表記（無ければ空文字） |
| `end_y` | `float` | 設問ブロックの最終行のy座標（0〜1正規化。マージン判定マーカーとのy近傍マッチングに使用） |
| `raw_text` | `str` | 出典除去前の結合済み本文 |
| `marker` | `dict \| None` | 対応する判定マーカー。`None` は判定マーカー欠落（`QAPair.needs_fix=True` 相当） |
| `inline_marker` | `dict`（存在する場合のみ） | 本文列に同居していた判定マーカー（`marker` と同一形状） |

`marker`（および `margin_markers` の各要素）が持つキー: `nums`（`list[int \| None]`。参照番号。丸数字・丸囲み文字代替は `_to_int` で整数化、非対応トークンは `None`）/ `mark`（`str`。生の○×記号。`anki_toolkit._normalize_verdict` 相当の正規化は呼び出し側=scaffold の責務）/ `y`（`float`）/ `raw`（`str`。マッチした生テキスト）/ `inline`（`bool`）。

### `coordinate_page_scaffold.py`（雛形・コピーして使う側）

`parser_scaffold.py` と同様、**使い捨てコピー前提**。`coordinate_marker_extract.extract_practice_page` と `anki_toolkit` の両方を import し、ページペアリング（基礎知識ページ×実践ページ）と `QAPair`（`qtype="truefalse"` 固定）への変換を行う。`PAGE_OFFSET`・ページファイル名パターン・基礎知識ページ変換済みMarkdownパスは `TODO` プレースホルダとして明示されており、コピー先で対象書籍の値に置き換える。見出しキーワード判定（`"基礎知識"`/`"必ず出る"`）と `era_year_tag()` の元号表記正規化（H/S/R/T）は「多くの日本語資格試験書籍で流用できる可能性が高いが確認してから使う」参考実装として残されている（削除・TODO化はしない）。

### `parser_scaffold.py` と `coordinate_marker_extract.py` の使い分け

OCR後のMarkdownをテキストとしてそのままパースできる場合（判定マーカー・正解が本文と同一の読み順で出現し、pandoc/フラット化OCRの時点で分離しない場合）は `parser_scaffold.py`（テキストフロー方式）を使う。一方、判定マーカーが本文と別カラム・別領域（見開きページのマージン等）に配置されており、フラット化Markdownの時点で本文との位置関係（列・座標）情報が失われて紐付け不能になる場合は、`coordinate_marker_extract.py`（座標マッチング方式）を検討する。座標マッチング方式はスキャン画像を直接 `ocrmac` 等で座標付きOCRできることが前提であり、画像そのものにアクセスできない（既に生成済みのフラット化Markdownしか無い）場合は採用できない。
