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
