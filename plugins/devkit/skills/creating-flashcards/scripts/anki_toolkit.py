#!/usr/bin/env python3
"""anki_toolkit.py — フラッシュカード投入インフラの常設ライブラリ（不変・育てる側）。

このモジュールは「ソースに依らず毎回同じ」部分だけを格納する:
  - AnkiConnect クライアント（per-note errors 対応）
  - addNotes バッチ投入（createDeck 必須 / duplicateScope:"deck" / allowDuplicate）
  - 冪等性（既存 front 事前フィルタ / front 重複 dedup）
  - HTML 整形（選択肢型 / ○×型 / 出典div / タグ / details原文）
  - QAPair 中間表現（IR）スキーマ = 全層が共有する契約
  - 翻訳スキップ判定・品質検証ヘルパ

🔴 ジェネリックパーサーはここに置かない。parse() 本体・共通クリーニングヘルパは
   parser_scaffold.py 側（ソース固有・使い捨て）に置く。

外部依存ゼロ（標準ライブラリのみ）。Python 3.10+ 想定。
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
import urllib.request
from dataclasses import dataclass, field

# ─────────────────────────────────────────────
# モジュール定数（上書き可）
# ─────────────────────────────────────────────

ANKI_CONNECT_URL = "http://127.0.0.1:8765"
BATCH_SIZE = 50

# 🔴 接頭辞付き filename のみ許可。pandoc 由来の汎用名 image_rsrcXXX は除外する
#   （image_rsrc001.jpg のような名前を別[書名]と衝突させない）。
#   OK: "<prefix>_image_rsrc001.jpg" / NG: "image_rsrc001.jpg", "abc.png"
MEDIA_PREFIX_RE = r"^(?!image_rsrc)[A-Za-z0-9][A-Za-z0-9_-]*_"

# qtype の許可集合（契約上の不変条件）
_VALID_QTYPES = {"choice", "truefalse", "basic"}

# verdict 正規化マップ（QAPair 投入時に正規化）
#   ✕ = U+2715 / ○ = U+25CB に正規化する
_VERDICT_NORMALIZE = {
    "×": "✕",   # U+00D7 MULTIPLICATION SIGN → U+2715
    "☓": "✕",   # U+2613 SALTIRE → U+2715
    "Ｘ": "✕",   # U+FF38 FULLWIDTH LATIN X → U+2715
    "X": "✕",   # ASCII X → U+2715
    "x": "✕",   # ASCII x → U+2715
    "〇": "○",   # U+3007 IDEOGRAPHIC NUMBER ZERO → U+25CB
    "◯": "○",   # U+25EF LARGE CIRCLE → U+25CB
    "O": "○",   # ASCII O → U+25CB
    "0": "○",   # ASCII DIGIT ZERO → U+25CB（OCRが ○ を 0 と誤読する頻出アーティファクト）
}


# ─────────────────────────────────────────────
# QAPair 中間表現（IR）スキーマ — 確定契約
#   フィールド名・型・デフォルトはこの定義が唯一の真実。
# ─────────────────────────────────────────────


@dataclass
class QAPair:
    # --- 必須コア ---
    front: str                          # 整形前の問題本文（HTML化前のプレーン）。問題番号ヘッダーは含めない
    back: str = ""                      # 整形前の解答/解説本文（raw HTML 素通し）

    # --- 問題種別 ---
    qtype: str = "basic"                # "choice" | "truefalse" | "basic" のいずれか
    #   choice    = 選択肢型（Multiple Choice）
    #   truefalse = ○×型（True/False）
    #   basic     = その他（Front/Back の2フィールド汎用）

    # --- 選択肢型（qtype=="choice"）用 ---
    choices: list[str] = field(default_factory=list)
    #   ["A. テキスト", "B. テキスト", ...] レター付きで格納
    correct: list[str] = field(default_factory=list)
    #   正解レター ["A"] / 複数正解 ["A","C"]
    wrong_explanations: dict = field(default_factory=dict)
    #   {"B": "不正解解説", "C": "..."} レター→解説

    # --- ○×型（qtype=="truefalse"）用 ---
    verdict: str = ""                   # "○" | "✕" | "" (空=判定マーカー欠落)

    # --- メタ情報（HTML/タグ/補助フィールドに展開） ---
    tags: list[str] = field(default_factory=list)
    #   Ankiタグ。階層は "::" 区切り、空白は "-"
    knowledge_area: str = ""            # 補助フィールド（例 "第3章 タイトル"）。空なら未設定
    source_book: str = ""               # 出典[書名]（Step5c）。空なら出典div出力しない
    source_page: str = ""               # 出典ページ番号（Step5c）。空可
    important: bool = False             # 重要マーカー（⭐ 重要 表示 + タグ"重要"）
    needs_fix: bool = False             # 不完全カード（_要手修正 タグ + 警告div）

    # --- 多言語（英語ソース）用 ---
    original_front: str = ""            # 原文問題（<details>折りたたみ用）。空なら原文ブロック出力しない
    original_back: str = ""             # 原文解答（<details>折りたたみ用）

    # --- メディア（EPUB埋め込み画像）用 ---
    media: list[dict] = field(default_factory=list)
    #   [{"filename": "<prefix>image_rsrcXXX.jpg",
    #     "data_b64": "<base64>"}] の投入予定画像。
    #   front/back 本文中に <img src="<filename>"> を埋め込んだ上で実体を載せる。
    #   空なら storeMediaFile を呼ばない。


@dataclass
class RenderOptions:
    """HTML レンダリング方針。

    ノートタイプのカスタムJS（`$('.question ol').find("li")` でシャッフル/全 `<li>`
    取得）との干渉を避けるため、HTML整形に方針を渡す。
    """

    choice_list_style: str = "ol"       # "ol" | "br"
    #   "ol" = メイン選択肢を <ol style="list-style-type:none"><li>… で出力（既定・シャッフルJS活用）
    #   "br" = <br> 区切りプレーンテキストで出力（JSが <li> を倍増させるテンプレ向け）
    details_choice_style: str = "br"    # <details>原文内の選択肢。常に "br"（<ol><li> 禁止 = 倍増回避）
    front_field_is_choice_shuffle: bool = True
    #   True: 選択肢頭に「ア.」「A.」等のレターを必ず付与（シャッフル後も内容で正解判定可能にする）


# ─────────────────────────────────────────────
# (a) AnkiConnect クライアント層
# ─────────────────────────────────────────────


def anki_request(action: str, params: dict | None = None) -> object:
    """AnkiConnect へ POST。

    error が文字列なら RuntimeError、
    error が配列(per-note errors)なら {"per_note_errors": [...]} を返す。
    """
    payload: dict = {"action": action, "version": 6}
    if params:
        payload["params"] = params
    req = urllib.request.Request(
        ANKI_CONNECT_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    error = data.get("error")
    # addNotes: エラーが配列形式（per-note errors）の場合がある
    if isinstance(error, list):
        return {"per_note_errors": error}
    if error:
        raise RuntimeError(f"AnkiConnect error: {error}")
    return data["result"]


# ─────────────────────────────────────────────
# (b) デッキ層
# ─────────────────────────────────────────────


def ensure_deck(deck_name: str) -> None:
    """createDeck を呼び、デッキ存在を保証（冪等）。addNotes 前に必須。"""
    anki_request("createDeck", {"deck": deck_name})


# ─────────────────────────────────────────────
# (c) 冪等性層
#   🔴 実フィールド名 front_field で差分判定する（Front 固定にしない）
# ─────────────────────────────────────────────


def _deck_query(deck_name: str) -> str:
    """deck 名を findNotes 用クエリにクォート（サブデッキ "親::子" 対応）。"""
    return f'deck:"{deck_name}"'


def _fetch_notes_info(deck_name: str) -> list[dict]:
    """対象デッキの全ノートの notesInfo を返す。"""
    note_ids = anki_request("findNotes", {"query": _deck_query(deck_name)})
    if not note_ids:
        return []
    info = anki_request("notesInfo", {"notes": note_ids})
    return list(info) if info else []


def _note_field_value(note_info: dict, field_name: str) -> str:
    """notesInfo の note dict から指定フィールドの value を取り出す。"""
    fields = note_info.get("fields", {})
    entry = fields.get(field_name)
    if isinstance(entry, dict):
        return str(entry.get("value", ""))
    return ""


def existing_fronts(deck_name: str, front_field: str) -> set[str]:
    """findNotes + notesInfo で対象デッキの既存「Frontフィールド」集合を返す。

    front_field は AnkiConnect 上の実フィールド名（例 "Question"）。
    サブデッキは内部で deck:"親::子" 形式にクォートする。
    """
    fronts: set[str] = set()
    for info in _fetch_notes_info(deck_name):
        value = _note_field_value(info, front_field)
        if value:
            fronts.add(value)
    return fronts


def filter_new(notes: list[dict], deck_name: str,
               front_field: str) -> tuple[list[dict], int]:
    """build_note 済みの notes のうち、既存と重複しないものだけ返す。

    各 note の note["fields"][front_field] を既存集合と突き合わせる。
    front_field は実フィールド名。戻り値: (新規notes, スキップ重複件数)。
    """
    existing = existing_fronts(deck_name, front_field)
    new_notes: list[dict] = []
    skipped = 0
    for note in notes:
        front_value = note.get("fields", {}).get(front_field, "")
        if front_value in existing:
            skipped += 1
            continue
        new_notes.append(note)
        # 同一バッチ内の重複も既存集合に加えて二重投入を防ぐ
        existing.add(front_value)
    return new_notes, skipped


def dedup_deck(deck_name: str, front_field: str) -> int:
    """deck 内の front_field 重複を最古 noteId 残しで deleteNotes。削除件数を返す。

    allowDuplicate 投入後の事後 dedup 用（filter_new を使えない場合の保険）。
    front_field は実フィールド名。
    """
    seen: dict[str, int] = {}        # front value → 残す最古 noteId
    to_delete: list[int] = []
    for info in _fetch_notes_info(deck_name):
        note_id = info.get("noteId")
        if note_id is None:
            continue
        value = _note_field_value(info, front_field)
        if value in seen:
            # noteId が小さい方（より古い）を残す
            if note_id < seen[value]:
                to_delete.append(seen[value])
                seen[value] = note_id
            else:
                to_delete.append(note_id)
        else:
            seen[value] = note_id
    if to_delete:
        anki_request("deleteNotes", {"notes": to_delete})
    return len(to_delete)


# ─────────────────────────────────────────────
# (e) HTML整形層（純関数・副作用なし）
#   🔴 back は raw HTML を素通し（HTML-escape しない・比較テーブル変換なし）。
#      scaffold の parse() が <table> 等を組んで QAPair.back に注入できるようにするため。
# ─────────────────────────────────────────────


def _normalize_verdict(verdict: str) -> str:
    """verdict の ×/〇 等を ✕(U+2715) / ○(U+25CB) に正規化する。"""
    if not verdict:
        return ""
    v = verdict.strip()
    return _VERDICT_NORMALIZE.get(v, v)


def _render_choices_ol(choices: list[str]) -> str:
    """選択肢を1つの <ol style="list-style-type:none"> にまとめて出力する。"""
    items = "".join(f"<li>{c}</li>" for c in choices)
    return f'<ol style="list-style-type: none; padding-left: 0;">{items}</ol>'


def _render_choices_br(choices: list[str]) -> str:
    """選択肢を <br> 区切りのプレーンテキストで出力する（<ol><li> を使わない）。"""
    return "<br>".join(choices)


def _render_details(summary: str, body: str, choices: list[str]) -> str:
    """<details> 折りたたみブロックを生成。

    🔴 内部の選択肢は常に <br> 区切り（details_choice_style 固定）。
       <ol><li> を置くと JS が選択肢を倍増・再シャッフルする既知の致命罠を回避する。
    """
    parts = [f"<details>\n<summary>{summary}</summary>\n<br>"]
    if body:
        parts.append(body)
    if choices:
        if body:
            parts.append("<br><br>")
        parts.append(_render_choices_br(choices))
    parts.append("\n</details>")
    return "".join(parts)


def build_front_html(qa: "QAPair", render: "RenderOptions" = RenderOptions()) -> str:
    """qtype に応じて Front HTML を生成。

    qtype=="choice": render.choice_list_style が "ol" なら
      <ol style="list-style-type:none"><li>、"br" なら <br>区切りで選択肢出力。
    qtype=="truefalse": 判定指示 <i>（○か✕で答えよ）</i> を付加。
    original_front があれば <details>原文を付加（内部の選択肢は常に <br> 区切り
      = details_choice_style 固定。<ol><li> は使わない）。
    問題番号ヘッダーは付けない。important なら ⭐重要 を付加。
    """
    _validate_qtype(qa.qtype)
    parts: list[str] = []
    parts.append(qa.front.strip())

    if qa.important:
        parts.append("<br><br>")
        parts.append('<span style="color:#c00;font-weight:bold;">⭐ 重要</span>')

    if qa.qtype == "choice" and qa.choices:
        parts.append("<br><br>")
        if render.choice_list_style == "br":
            parts.append(_render_choices_br(qa.choices))
        else:
            parts.append(_render_choices_ol(qa.choices))
    elif qa.qtype == "truefalse":
        parts.append("<br><br>")
        parts.append("<i>（○か✕で答えよ）</i>")

    if qa.original_front:
        parts.append("<br><br>")
        parts.append(_render_details("📄 原文", qa.original_front.strip(), []))

    return "".join(parts)


def build_back_html(qa: "QAPair", render: "RenderOptions" = RenderOptions()) -> str:
    """qtype に応じて Back HTML を生成（正解+解説 / ○×大表示+解説）。

    🔴 解説/back 本文（qa.back / wrong_explanations の値）は raw HTML として
       素通しする（HTML-escape しない）。scaffold の parse() がソース固有に
       <table> 等を組んで back に注入できるようにするため。比較テーブル等の
       プレーンテキスト→HTML 変換は toolkit では行わない（parse 側の責務）。
    source_book/source_page があれば出典divを末尾付加。
    needs_fix なら警告divを先頭付加。
    original_back があれば <details>原文付加（同じく <br> 区切り固定）。
    """
    _validate_qtype(qa.qtype)
    parts: list[str] = []

    if qa.needs_fix:
        parts.append(
            '<div style="background:#fff8e1;border:1px solid #ffb300;'
            'padding:0.5em;border-radius:4px;">'
            "⚠️ 要手修正: ソース原本で解答省略 or パーサー未対応の特殊形式"
            "</div><br>"
        )

    if qa.qtype == "truefalse":
        verdict = _normalize_verdict(qa.verdict)
        if verdict:
            parts.append(
                '<div style="font-size:2em;font-weight:bold;'
                f'text-align:center;">{verdict}</div><br>'
            )
        else:
            parts.append(
                '<div style="font-size:1.2em;color:#888;text-align:center;">'
                "（原本に○×マーカー欠落 — 解説で判定）</div><br>"
            )
        if qa.back:
            parts.append("<b>解説:</b><br>")
            parts.append(qa.back)
    elif qa.qtype == "choice":
        if qa.correct:
            parts.append("<b>正解:</b><br>")
            parts.append(_format_correct_choices(qa))
        if qa.back:
            if parts:
                parts.append("<br><br>")
            parts.append("<b>解説:</b><br>")
            parts.append(qa.back)
        wrong = _format_wrong_explanations(qa)
        if wrong:
            parts.append("<br><br>")
            parts.append(wrong)
    else:  # basic
        if qa.back:
            parts.append(qa.back)

    if qa.original_back:
        parts.append("<br><br>")
        parts.append(_render_details("📄 原文", qa.original_back.strip(), []))

    if qa.source_book or qa.source_page:
        parts.append(_build_source_div(qa))

    return "".join(parts)


def _format_correct_choices(qa: "QAPair") -> str:
    """正解レターに対応する選択肢本文を改行区切りで返す。"""
    by_letter = _choices_by_letter(qa.choices)
    lines: list[str] = []
    for letter in qa.correct:
        text = by_letter.get(letter)
        if text is not None:
            lines.append(f"{letter}. {text}")
        else:
            lines.append(letter)
    return "<br>".join(lines)


def _format_wrong_explanations(qa: "QAPair") -> str:
    """不正解の選択肢解説を太字ラベル付きで返す（raw HTML 素通し）。"""
    if not qa.wrong_explanations:
        return ""
    parts = ["<b>不正解の選択肢の解説:</b><br>"]
    items: list[str] = []
    for letter, text in qa.wrong_explanations.items():
        items.append(f"<b>{letter}:</b> {text}")
    parts.append("<br>".join(items))
    return "".join(parts)


def _choices_by_letter(choices: list[str]) -> dict[str, str]:
    """["A. テキスト", ...] を {"A": "テキスト", ...} に分解する。"""
    result: dict[str, str] = {}
    for c in choices:
        m = re.match(r"^\s*([A-Ia-iア-ン])[.．：:、]\s*(.*)$", c, re.DOTALL)
        if m:
            result[m.group(1)] = m.group(2).strip()
    return result


def _build_source_div(qa: "QAPair") -> str:
    """出典 div を生成する。source_book/source_page が両方空なら空文字。"""
    if not qa.source_book and not qa.source_page:
        return ""
    label = qa.source_book
    if qa.source_page:
        label = f"{label} p.{qa.source_page}" if label else f"p.{qa.source_page}"
    return (
        '<br><br><div style="font-size:0.85em;color:#888;border-top:1px solid #ddd;'
        f'padding-top:0.3em;">出典: {label}</div>'
    )


def build_tags(qa: "QAPair") -> list[str]:
    """qa.tags をベースに important→"重要"、needs_fix→"_要手修正" を補完して返す。"""
    tags: list[str] = list(qa.tags)
    if qa.important and "重要" not in tags:
        tags.append("重要")
    if qa.needs_fix and "_要手修正" not in tags:
        tags.append("_要手修正")
    return tags


# ─────────────────────────────────────────────
# (d) 投入層
# ─────────────────────────────────────────────


def _validate_qtype(qtype: str) -> None:
    """qtype が許可集合に含まれることを検証する。"""
    if qtype not in _VALID_QTYPES:
        raise ValueError(
            f"invalid qtype: {qtype!r} (must be one of {sorted(_VALID_QTYPES)})"
        )


def _validate_qa(qa: "QAPair") -> None:
    """QAPair の契約上の不変条件を検証する。"""
    _validate_qtype(qa.qtype)
    if not qa.front or not qa.front.strip():
        raise ValueError("QAPair.front must be non-empty")


def build_note(qa: "QAPair", deck_name: str, model_name: str,
               field_map: dict[str, str],
               render: "RenderOptions" = RenderOptions()) -> dict:
    """QAPair を AnkiConnect addNotes 用の note dict に変換。

    field_map = 論理フィールド→実フィールド名のマッピング。
      必須: "front"（例 "Question"）, "back"（例 "Answer"）
      任意: "extra"（knowledge_area の投入先。例 "Knowledge Area"）
    options に allowDuplicate=True, duplicateScope="deck" を自動付与。
    fields は build_front_html(qa, render) / build_back_html(qa, render) を
    内部で呼んで生成し、field_map の実フィールド名キーに格納する。
    """
    _validate_qa(qa)
    if "front" not in field_map or "back" not in field_map:
        raise ValueError('field_map must contain "front" and "back" keys')

    fields: dict[str, str] = {
        field_map["front"]: build_front_html(qa, render),
        field_map["back"]: build_back_html(qa, render),
    }
    extra_field = field_map.get("extra")
    if extra_field and qa.knowledge_area:
        fields[extra_field] = qa.knowledge_area

    return {
        "deckName": deck_name,
        "modelName": model_name,
        "fields": fields,
        "tags": build_tags(qa),
        "options": {"allowDuplicate": True, "duplicateScope": "deck"},
    }


def store_media(qas: list["QAPair"]) -> int:
    """qas の media に載った画像を AnkiConnect storeMediaFile で投入。

    各要素 {"filename","data_b64"} を登録（同名は上書き=冪等）。投入件数を返す。
    front/back 本文には事前に <img src="<filename>"> が埋め込まれている前提。
    media が空なら何もしない。upload() 内で addNotes 前に自動実行される。
    🔴 各 filename は MEDIA_PREFIX_RE（接頭辞付き）でなければ ValueError。
       接頭辞なしの汎用名（image_rsrc001.jpg 等）は Anki メディア全体で
       別[書名]と衝突し既存画像を静かに上書きするため、契約レベルで拒否する。
    """
    prefix_re = re.compile(MEDIA_PREFIX_RE)
    stored = 0
    for qa in qas:
        for item in qa.media:
            filename = item.get("filename", "")
            data_b64 = item.get("data_b64", "")
            if not prefix_re.match(filename):
                raise ValueError(
                    f"media filename must match MEDIA_PREFIX_RE "
                    f"(prefixed, not generic): {filename!r}"
                )
            anki_request(
                "storeMediaFile",
                {"filename": filename, "data": data_b64},
            )
            stored += 1
    return stored


def upload(qas: list["QAPair"], deck_name: str, model_name: str,
           field_map: dict[str, str],
           render: "RenderOptions" = RenderOptions(),
           skip_existing: bool = True) -> dict:
    """ensure_deck → store_media → build_note(全件) →
    (skip_existing なら filter_new で note[fields][field_map['front']] 差分) →
    addNotes を BATCH_SIZE 件ずつ実行。

    戻り値: {"added": int, "skipped_existing": int,
             "media_stored": int, "errors": list}。
    50件ごとに進捗を stderr に出力。
    🔴 filter_new は build_note の後・addNotes の前に走らせる
       （論理名→実フィールド名の解決後に差分判定するため）。
    """
    if "front" not in field_map or "back" not in field_map:
        raise ValueError('field_map must contain "front" and "back" keys')
    front_field = field_map["front"]

    # 1. デッキ存在保証（冪等）
    ensure_deck(deck_name)

    # 2. メディア投入（addNotes 前に必須）
    media_stored = store_media(qas)

    # 3. 全件を note dict に変換（実フィールド名解決後に差分判定するため先に build）
    notes = [build_note(qa, deck_name, model_name, field_map, render) for qa in qas]

    # 4. 冪等性フィルタ（実フィールド名で差分判定）
    skipped_existing = 0
    if skip_existing:
        notes, skipped_existing = filter_new(notes, deck_name, front_field)

    # 5. バッチ投入
    added = 0
    errors: list = []
    total = len(notes)
    for start in range(0, total, BATCH_SIZE):
        batch = notes[start:start + BATCH_SIZE]
        result = anki_request("addNotes", {"notes": batch})
        if isinstance(result, dict) and "per_note_errors" in result:
            errors.extend(result["per_note_errors"])
        elif isinstance(result, list):
            added += sum(1 for r in result if r is not None)
            errors.extend(
                {"index": start + i, "error": "note skipped (duplicate or error)"}
                for i, r in enumerate(result) if r is None
            )
        print(
            f"[upload] {min(start + BATCH_SIZE, total)}/{total} processed",
            file=sys.stderr,
        )

    return {
        "added": added,
        "skipped_existing": skipped_existing,
        "media_stored": media_stored,
        "errors": errors,
    }


# ─────────────────────────────────────────────
# (f) 翻訳補助層
# ─────────────────────────────────────────────


def is_code_like(text: str) -> bool:
    """翻訳スキップ判定。

    $プレフィックス / ドット区切り識別子 / バッククォート囲み /
    2つ以上のコード文字を含む60字未満、を True。
    """
    if not text:
        return False
    stripped = text.strip()
    if len(stripped) >= 60:
        return False
    # $ プレフィックス（シェル変数・jQuery 等）
    if stripped.startswith("$"):
        return True
    # バッククォート囲み
    if stripped.startswith("`") and stripped.endswith("`"):
        return True
    # ドット区切り識別子（例: obj.method.value）
    if re.fullmatch(r"[A-Za-z_][\w]*(?:\.[A-Za-z_][\w]*)+", stripped):
        return True
    # 2つ以上のコード文字を含む
    code_chars = set("{}[]()<>=;|&/\\`$_")
    if sum(1 for ch in stripped if ch in code_chars) >= 2:
        return True
    return False


# ─────────────────────────────────────────────
# (g) 品質検証層
# ─────────────────────────────────────────────


def sample_cards(deck_name: str, head: int = 5, mid: int = 5) -> list[dict]:
    """findNotes + notesInfo で先頭 head 件・中盤 mid 件のカードを返す
    （Step7 のサンプルチェック用）。
    """
    note_ids = anki_request("findNotes", {"query": _deck_query(deck_name)})
    if not note_ids:
        return []
    ids = list(note_ids)
    selected: list = list(ids[:head])
    total = len(ids)
    if mid > 0 and total > head:
        mid_start = max(head, total // 2 - mid // 2)
        selected.extend(ids[mid_start:mid_start + mid])
    # 重複 noteId を順序保持で除去
    seen: set = set()
    unique_ids: list = []
    for nid in selected:
        if nid not in seen:
            seen.add(nid)
            unique_ids.append(nid)
    info = anki_request("notesInfo", {"notes": unique_ids})
    return list(info) if info else []


# NFKC 正規化ヘルパ（front 用。タグ・デッキ名には使わない）。
# 公開 API には含めない内部ユーティリティ。
def _normalize_nfkc(text: str) -> str:
    return unicodedata.normalize("NFKC", text)
