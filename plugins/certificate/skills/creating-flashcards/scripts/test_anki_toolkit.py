#!/usr/bin/env python3
"""test_anki_toolkit.py — 罠の動作再現テスト（標準ライブラリ unittest のみ）。

fake AnkiConnect（anki_toolkit.anki_request を差し替え）で、references に
蓄積された致命罠が toolkit で実際に封じ込められているかを動作レベルで検証する。
Anki 起動不要・外部依存ゼロ。

実行: python3 -m unittest test_anki_toolkit -v
"""

import unittest

import anki_toolkit as tk
from anki_toolkit import (
    QAPair,
    RenderOptions,
    build_front_html,
    build_back_html,
    build_note,
    filter_new,
    store_media,
)


class FakeAnki:
    """anki_request を差し替えるための fake AnkiConnect。

    呼び出し履歴を記録し、findNotes / notesInfo は事前設定した状態を返す。
    addNotes は error_mode に応じて per-note errors（配列）/ result 配列を返す。
    """

    def __init__(self):
        self.calls: list[tuple[str, dict]] = []
        self.note_ids: list[int] = []
        self.notes_info: list[dict] = []
        self.add_notes_error_array: list | None = None  # 配列を返す → per_note_errors
        self.add_notes_result: list | None = None        # None で None 配列

    def request(self, action: str, params: dict | None = None) -> object:
        self.calls.append((action, params or {}))
        if action == "createDeck":
            return 1
        if action == "findNotes":
            return list(self.note_ids)
        if action == "notesInfo":
            wanted = set(params.get("notes", [])) if params else set()
            return [n for n in self.notes_info if n.get("noteId") in wanted]
        if action == "storeMediaFile":
            return params.get("filename") if params else None
        if action == "deleteNotes":
            return None
        if action == "addNotes":
            if self.add_notes_error_array is not None:
                # anki_request 本来の挙動を模倣（error が配列 → per_note_errors）
                return {"per_note_errors": self.add_notes_error_array}
            if self.add_notes_result is not None:
                return self.add_notes_result
            # デフォルト: すべて成功とみなし連番 noteId を返す
            notes = params.get("notes", []) if params else []
            return list(range(1000, 1000 + len(notes)))
        raise AssertionError(f"unexpected action: {action}")


class BaseToolkitTest(unittest.TestCase):
    def setUp(self):
        self.fake = FakeAnki()
        self._orig_request = tk.anki_request
        tk.anki_request = self.fake.request

    def tearDown(self):
        tk.anki_request = self._orig_request


# ─────────────────────────────────────────────
# AT-1: addNotes の per-note errors（配列）検出
# ─────────────────────────────────────────────


class TestPerNoteErrors(BaseToolkitTest):
    def test_per_note_errors_array_is_surfaced(self):
        """error が配列のとき upload が errors に集約し null 化しない。"""
        self.fake.add_notes_error_array = [
            "cannot create note because it is a duplicate",
        ]
        qas = [QAPair(front="Q1", back="A1", qtype="basic")]
        result = tk.upload(
            qas, deck_name="TestDeck", model_name="Basic",
            field_map={"front": "Front", "back": "Back"},
            skip_existing=False,
        )
        self.assertEqual(result["added"], 0)
        self.assertEqual(len(result["errors"]), 1)
        self.assertIn("duplicate", str(result["errors"][0]))

    def test_anki_request_wraps_error_array(self):
        """anki_request 単体: error 配列を per_note_errors で返す（urlopen をスタブ）。"""
        import io
        import json
        import urllib.request

        orig_request = tk.anki_request
        tk.anki_request = self._orig_request  # 本物の anki_request を使う
        try:
            payload = {"result": None, "error": ["dup error"]}

            class FakeResp:
                def __enter__(self_inner):
                    return self_inner

                def __exit__(self_inner, *a):
                    return False

                def read(self_inner):
                    return json.dumps(payload).encode("utf-8")

            orig_urlopen = urllib.request.urlopen
            urllib.request.urlopen = lambda req: FakeResp()
            try:
                out = tk.anki_request("addNotes", {"notes": []})
            finally:
                urllib.request.urlopen = orig_urlopen
            self.assertEqual(out, {"per_note_errors": ["dup error"]})
        finally:
            tk.anki_request = orig_request


# ─────────────────────────────────────────────
# AT-2: build_note の options に duplicateScope/allowDuplicate が必ず入る
# ─────────────────────────────────────────────


class TestBuildNoteOptions(BaseToolkitTest):
    def test_options_always_present(self):
        qa = QAPair(front="設問", back="解説", qtype="basic")
        note = build_note(
            qa, deck_name="D", model_name="M",
            field_map={"front": "Question", "back": "Answer"},
        )
        self.assertEqual(note["options"]["duplicateScope"], "deck")
        self.assertTrue(note["options"]["allowDuplicate"])

    def test_extra_field_maps_knowledge_area(self):
        qa = QAPair(front="設問", back="解説", qtype="basic",
                    knowledge_area="第3章 タイトル")
        note = build_note(
            qa, deck_name="D", model_name="M",
            field_map={"front": "Question", "back": "Answer",
                       "extra": "Knowledge Area"},
        )
        self.assertEqual(note["fields"]["Knowledge Area"], "第3章 タイトル")


# ─────────────────────────────────────────────
# AT-3: 実フィールド名での冪等性（filter_new）
# ─────────────────────────────────────────────


class TestRealFieldIdempotency(BaseToolkitTest):
    def test_filter_new_with_question_field(self):
        """field_map={"front":"Question"} 再実行時に実フィールド名で重複スキップ。"""
        # 既存カードに front HTML と完全一致する Question フィールドを持たせる
        qa = QAPair(front="既存問題", back="解説", qtype="basic")
        existing_front_html = build_front_html(qa)
        self.fake.note_ids = [42]
        self.fake.notes_info = [
            {"noteId": 42, "fields": {"Question": {"value": existing_front_html},
                                      "Answer": {"value": "解説"}}},
        ]
        # build_note で生成した note を filter_new に通す
        note_new = build_note(
            QAPair(front="新規問題", back="x", qtype="basic"),
            deck_name="D", model_name="M",
            field_map={"front": "Question", "back": "Answer"},
        )
        note_dup = build_note(
            qa, deck_name="D", model_name="M",
            field_map={"front": "Question", "back": "Answer"},
        )
        new_notes, skipped = filter_new(
            [note_new, note_dup], deck_name="D", front_field="Question",
        )
        self.assertEqual(skipped, 1)
        self.assertEqual(len(new_notes), 1)
        self.assertEqual(new_notes[0]["fields"]["Question"],
                         build_front_html(QAPair(front="新規問題", back="x",
                                                 qtype="basic")))

    def test_upload_skips_existing_real_field(self):
        """upload(skip_existing=True) が実フィールド名で既存をスキップする。"""
        qa_existing = QAPair(front="重複設問", back="a", qtype="basic")
        existing_html = build_front_html(qa_existing)
        self.fake.note_ids = [7]
        self.fake.notes_info = [
            {"noteId": 7, "fields": {"Question": {"value": existing_html},
                                     "Answer": {"value": "a"}}},
        ]
        qas = [qa_existing, QAPair(front="新規設問", back="b", qtype="basic")]
        result = tk.upload(
            qas, deck_name="D", model_name="M",
            field_map={"front": "Question", "back": "Answer"},
            skip_existing=True,
        )
        self.assertEqual(result["skipped_existing"], 1)
        self.assertEqual(result["added"], 1)


# ─────────────────────────────────────────────
# AT-4: HTML golden 検証
# ─────────────────────────────────────────────


class TestHtmlGolden(BaseToolkitTest):
    def test_choice_ol_style(self):
        qa = QAPair(front="問題文", qtype="choice",
                    choices=["A. 選択肢1", "B. 選択肢2"], correct=["A"])
        html = build_front_html(qa, RenderOptions(choice_list_style="ol"))
        self.assertIn('<ol style="list-style-type: none; padding-left: 0;">', html)
        self.assertIn("<li>A. 選択肢1</li>", html)

    def test_choice_br_style(self):
        qa = QAPair(front="問題文", qtype="choice",
                    choices=["A. 選択肢1", "B. 選択肢2"], correct=["A"])
        html = build_front_html(qa, RenderOptions(choice_list_style="br"))
        self.assertNotIn("<ol", html)
        self.assertNotIn("<li>", html)
        self.assertIn("A. 選択肢1<br>B. 選択肢2", html)

    def test_choice_numeric_label_correct_mapping(self):
        # 数字ラベル選択肢（1. 〜）でも correct=["1"] で正解本文がマップされる
        qa = QAPair(front="問題文", qtype="choice",
                    choices=["1. 選択肢1", "2. 選択肢2", "3. 選択肢3"], correct=["2"])
        html = build_back_html(qa)
        self.assertIn("2. 選択肢2", html)   # ラベルだけでなく本文も表示

    def test_choice_circled_label_correct_mapping(self):
        # 丸数字ラベル（① 〜）でも correct=["①"] でマップされる
        qa = QAPair(front="問題文", qtype="choice",
                    choices=["① 選択肢1", "② 選択肢2"], correct=["①"])
        html = build_back_html(qa)
        self.assertIn("①", html)
        self.assertIn("選択肢1", html)   # ラベルに紐づく本文がマップされる

    def test_truefalse_judgement_instruction(self):
        qa = QAPair(front="この記述は正しい", qtype="truefalse", verdict="○")
        html = build_front_html(qa)
        self.assertIn("<i>（○か✕で答えよ）</i>", html)

    def test_details_no_ol_li(self):
        """<details> 原文内に <ol><li> が含まれない（JS倍増回避）。"""
        qa = QAPair(front="問題", qtype="choice",
                    choices=["A. a", "B. b"], correct=["A"],
                    original_front="Original question\nA. opt a\nB. opt b")
        html = build_front_html(qa, RenderOptions(choice_list_style="ol"))
        # メイン選択肢には <ol> があるが、details 内には無いことを検証
        self.assertIn("<details>", html)
        details_part = html[html.index("<details>"):]
        self.assertNotIn("<ol", details_part)
        self.assertNotIn("<li>", details_part)

    def test_back_raw_html_passthrough(self):
        """back の raw HTML（<table> 等）が escape されず素通しされる。"""
        qa = QAPair(front="Q", qtype="basic",
                    back='<table><tr><td>セル</td></tr></table>')
        html = build_back_html(qa)
        self.assertIn("<table><tr><td>セル</td></tr></table>", html)
        self.assertNotIn("&lt;table&gt;", html)


# ─────────────────────────────────────────────
# AT-5: store_media — 接頭辞検証
# ─────────────────────────────────────────────


class TestStoreMedia(BaseToolkitTest):
    def test_prefixed_filename_stored(self):
        qas = [QAPair(front="Q", qtype="basic", media=[
            {"filename": "joho2026_image_rsrc001.jpg", "data_b64": "AAAA"},
        ])]
        count = store_media(qas)
        self.assertEqual(count, 1)
        store_calls = [c for c in self.fake.calls if c[0] == "storeMediaFile"]
        self.assertEqual(len(store_calls), 1)
        self.assertEqual(store_calls[0][1]["filename"], "joho2026_image_rsrc001.jpg")
        self.assertEqual(store_calls[0][1]["data"], "AAAA")

    def test_generic_filename_raises(self):
        """接頭辞なしの汎用名は ValueError（別書名との衝突防止）。"""
        qas = [QAPair(front="Q", qtype="basic", media=[
            {"filename": "image_rsrc001.jpg", "data_b64": "AAAA"},
        ])]
        with self.assertRaises(ValueError):
            store_media(qas)

    def test_non_prefixed_plain_name_raises(self):
        qas = [QAPair(front="Q", qtype="basic", media=[
            {"filename": "abc.png", "data_b64": "AAAA"},
        ])]
        with self.assertRaises(ValueError):
            store_media(qas)

    def test_empty_media_no_call(self):
        qas = [QAPair(front="Q", qtype="basic")]
        count = store_media(qas)
        self.assertEqual(count, 0)
        self.assertEqual(
            [c for c in self.fake.calls if c[0] == "storeMediaFile"], [])


# ─────────────────────────────────────────────
# AT-6: verdict 正規化 / qtype 不正値 ValueError
# ─────────────────────────────────────────────


class TestVerdictAndQtype(BaseToolkitTest):
    def test_verdict_x_normalized(self):
        qa = QAPair(front="記述", qtype="truefalse", verdict="×", back="解説")
        html = build_back_html(qa)
        self.assertIn("✕", html)            # U+2715
        self.assertNotIn("×", html)         # U+00D7 は残らない

    def test_verdict_maru_normalized(self):
        qa = QAPair(front="記述", qtype="truefalse", verdict="〇", back="解説")
        html = build_back_html(qa)
        self.assertIn("○", html)            # U+25CB
        self.assertNotIn("〇", html)         # U+3007 は残らない

    def test_verdict_zero_normalized(self):
        # OCRが ○ を数字 0 と誤読するケース（解答キー "1.0 2.✕" 等）
        qa = QAPair(front="記述", qtype="truefalse", verdict="0", back="解説")
        html = build_back_html(qa)
        self.assertIn("○", html)            # U+25CB
        self.assertNotIn(">0<", html)       # 生の数字0は判定表示に残らない

    def test_invalid_qtype_raises_in_build_front(self):
        qa = QAPair(front="Q", qtype="multiple")
        with self.assertRaises(ValueError):
            build_front_html(qa)

    def test_invalid_qtype_raises_in_build_note(self):
        qa = QAPair(front="Q", qtype="unknown")
        with self.assertRaises(ValueError):
            build_note(qa, deck_name="D", model_name="M",
                       field_map={"front": "Front", "back": "Back"})

    def test_empty_front_raises_in_build_note(self):
        qa = QAPair(front="   ", qtype="basic")
        with self.assertRaises(ValueError):
            build_note(qa, deck_name="D", model_name="M",
                       field_map={"front": "Front", "back": "Back"})


if __name__ == "__main__":
    unittest.main()
