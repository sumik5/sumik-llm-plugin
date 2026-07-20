#!/usr/bin/env python3
"""test_whizlabs_import.py — whizlabs_import.py の単体テスト（標準ライブラリ unittest のみ）。

question_to_qapair / is_whizlabs_json / default_deck_name / load_and_convert の
変換ロジックを検証する。AnkiConnect・Anki起動は不要（anki_toolkit への実通信は行わない）。

実行: python3 -m unittest test_whizlabs_import -v
"""

import json
import os
import tempfile
import unittest

from whizlabs_import import (
    default_deck_name,
    is_whizlabs_json,
    load_and_convert,
    question_to_qapair,
)


class TestQuestionToQAPair(unittest.TestCase):
    def test_basic_mapping(self):
        q = {
            "number": 1,
            "domain": "サンプル領域A",
            "question": "サンプル問題文です。",
            "choices": ["A. 選択肢A", "B. 選択肢B", "C. 選択肢C", "D. 選択肢D"],
            "choice_type": "single",
            "correct": ["B"],
            "explanation_html": "<p>サンプル解説。</p>",
        }
        qa = question_to_qapair(q)
        self.assertEqual(qa.front, q["question"])
        self.assertEqual(qa.back, q["explanation_html"])
        self.assertEqual(qa.qtype, "choice")
        self.assertEqual(qa.choices, q["choices"])
        self.assertEqual(qa.correct, ["B"])
        self.assertEqual(qa.wrong_explanations, {})
        self.assertEqual(qa.tags, ["whizlabs"])
        self.assertEqual(qa.knowledge_area, "サンプル領域A")
        self.assertFalse(qa.needs_fix)

    def test_needs_fix_when_correct_empty(self):
        q = {
            "number": 2,
            "domain": "サンプル領域B",
            "question": "サンプル問題文2。",
            "choices": ["A. 選択肢A", "B. 選択肢B"],
            "choice_type": "single",
            "correct": [],
            "explanation_html": "<p>解説2。</p>",
        }
        qa = question_to_qapair(q)
        self.assertEqual(qa.correct, [])
        self.assertTrue(qa.needs_fix)

    def test_multiple_correct_answers_preserved(self):
        q = {
            "number": 3,
            "domain": "サンプル領域C",
            "question": "サンプル問題文3（複数選択）。",
            "choices": ["A. 選択肢A", "B. 選択肢B", "C. 選択肢C", "D. 選択肢D"],
            "choice_type": "multiple",
            "correct": ["A", "C"],
            "explanation_html": "<p>解説3。</p>",
        }
        qa = question_to_qapair(q)
        self.assertEqual(qa.correct, ["A", "C"])
        self.assertFalse(qa.needs_fix)

    def test_missing_domain_defaults_to_empty_knowledge_area(self):
        q = {
            "number": 4,
            "question": "サンプル問題文4。",
            "choices": ["A. 選択肢A", "B. 選択肢B"],
            "choice_type": "single",
            "correct": ["A"],
            "explanation_html": "<p>解説4。</p>",
        }
        qa = question_to_qapair(q)
        self.assertEqual(qa.knowledge_area, "")


class TestIsWhizlabsJson(unittest.TestCase):
    def _valid_data(self):
        return {
            "course_title": "サンプルコース",
            "course_url": "https://example.invalid/course/sample",
            "quiz_title": "サンプルクイズ1",
            "quiz_id": "q-001",
            "questions": [],
        }

    def test_valid_schema(self):
        self.assertTrue(is_whizlabs_json(self._valid_data()))

    def test_missing_course_title(self):
        data = self._valid_data()
        del data["course_title"]
        self.assertFalse(is_whizlabs_json(data))

    def test_missing_quiz_title(self):
        data = self._valid_data()
        del data["quiz_title"]
        self.assertFalse(is_whizlabs_json(data))

    def test_missing_quiz_id(self):
        data = self._valid_data()
        del data["quiz_id"]
        self.assertFalse(is_whizlabs_json(data))

    def test_missing_questions_key(self):
        data = self._valid_data()
        del data["questions"]
        self.assertFalse(is_whizlabs_json(data))

    def test_questions_not_a_list(self):
        data = self._valid_data()
        data["questions"] = {}
        self.assertFalse(is_whizlabs_json(data))

    def test_quiz_id_wrong_type(self):
        data = self._valid_data()
        data["quiz_id"] = 123
        self.assertFalse(is_whizlabs_json(data))

    def test_non_dict_input(self):
        self.assertFalse(is_whizlabs_json(["not", "a", "dict"]))


class TestDefaultDeckName(unittest.TestCase):
    def test_basic_format(self):
        self.assertEqual(
            default_deck_name("サンプルコース", "サンプルクイズ1"),
            "資格試験::サンプルコース::サンプルクイズ1::whizlabs",
        )

    def test_strips_surrounding_whitespace(self):
        self.assertEqual(
            default_deck_name("  サンプルコース  ", "  サンプルクイズ1  "),
            "資格試験::サンプルコース::サンプルクイズ1::whizlabs",
        )

    def test_empty_strings_still_produce_deck_name(self):
        self.assertEqual(
            default_deck_name("", ""),
            "資格試験::::::whizlabs",
        )


class TestLoadAndConvert(unittest.TestCase):
    def test_valid_file_roundtrip(self):
        data = {
            "course_title": "サンプルコース",
            "course_url": "https://example.invalid/course/sample",
            "quiz_title": "サンプルクイズ1",
            "quiz_id": "q-001",
            "collected_at": "2026-07-16T05:12:34Z",
            "total_questions": 2,
            "questions": [
                {
                    "number": 1,
                    "domain": "サンプル領域A",
                    "question": "サンプル問題文1。",
                    "choices": ["A. 選択肢A", "B. 選択肢B"],
                    "choice_type": "single",
                    "correct": ["A"],
                    "explanation_html": "<p>解説1。</p>",
                },
                {
                    "number": 2,
                    "domain": "サンプル領域B",
                    "question": "サンプル問題文2。",
                    "choices": ["A. 選択肢A", "B. 選択肢B"],
                    "choice_type": "single",
                    "correct": [],
                    "explanation_html": "<p>解説2。</p>",
                },
            ],
        }
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False, encoding="utf-8"
        ) as f:
            json.dump(data, f, ensure_ascii=False)
            path = f.name
        try:
            loaded, qas, needs_fix = load_and_convert(path)
            self.assertEqual(loaded["course_title"], "サンプルコース")
            self.assertEqual(len(qas), 2)
            self.assertEqual(needs_fix, 1)
            self.assertEqual(qas[0].correct, ["A"])
        finally:
            os.unlink(path)

    def test_invalid_schema_raises(self):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False, encoding="utf-8"
        ) as f:
            json.dump({"foo": "bar"}, f)
            path = f.name
        try:
            with self.assertRaises(ValueError):
                load_and_convert(path)
        finally:
            os.unlink(path)


if __name__ == "__main__":
    unittest.main()
