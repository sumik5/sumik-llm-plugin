#!/usr/bin/env python3
"""test_studying_import.py — studying_import.py の単体テスト（標準ライブラリ unittest のみ）。

question_to_qapair / is_studying_json / default_deck_name / load_and_convert の
変換ロジックを検証する。AnkiConnect・Anki起動は不要（anki_toolkit への実通信は行わない）。

実行: python3 -m unittest test_studying_import -v
"""

import json
import os
import tempfile
import unittest

from studying_import import (
    default_deck_name,
    is_studying_json,
    load_and_convert,
    question_to_qapair,
    split_course_title,
)


class TestQuestionToQAPair(unittest.TestCase):
    def test_boolean_choice_type_maps_to_truefalse(self):
        q = {
            "number": 1,
            "question": "サンプル○×問題です。",
            "choice_type": "boolean",
            "correct": ["○"],
            "explanation": "サンプル解説。",
        }
        qa = question_to_qapair(q, "サンプル科目A")
        self.assertEqual(qa.front, q["question"])
        self.assertEqual(qa.back, q["explanation"])
        self.assertEqual(qa.qtype, "truefalse")
        self.assertEqual(qa.verdict, "○")
        self.assertEqual(qa.tags, ["studying"])
        self.assertEqual(qa.knowledge_area, "サンプル科目A")
        self.assertFalse(qa.needs_fix)

    def test_boolean_choice_type_empty_correct_sets_needs_fix(self):
        q = {
            "number": 2,
            "question": "サンプル○×問題2。",
            "choice_type": "boolean",
            "correct": [],
            "explanation": "解説2。",
        }
        qa = question_to_qapair(q, "サンプル科目A")
        self.assertEqual(qa.verdict, "")
        self.assertTrue(qa.needs_fix)

    def test_single_choice_type_maps_to_choice(self):
        q = {
            "number": 3,
            "question": "サンプル4択問題です。",
            "choice_type": "single",
            "choices": ["A. 選択肢A", "B. 選択肢B", "C. 選択肢C", "D. 選択肢D"],
            "correct": ["B"],
            "explanation": "サンプル解説3。",
        }
        qa = question_to_qapair(q, "サンプル科目B")
        self.assertEqual(qa.front, q["question"])
        self.assertEqual(qa.qtype, "choice")
        self.assertEqual(qa.choices, q["choices"])
        self.assertEqual(qa.correct, ["B"])
        self.assertEqual(qa.tags, ["studying"])
        self.assertEqual(qa.knowledge_area, "サンプル科目B")
        self.assertFalse(qa.needs_fix)

    def test_single_choice_type_empty_correct_sets_needs_fix(self):
        q = {
            "number": 4,
            "question": "サンプル4択問題4。",
            "choice_type": "single",
            "choices": ["A. 選択肢A", "B. 選択肢B"],
            "correct": [],
            "explanation": "解説4。",
        }
        qa = question_to_qapair(q, "サンプル科目B")
        self.assertEqual(qa.correct, [])
        self.assertTrue(qa.needs_fix)

    def test_unknown_choice_type_maps_to_basic_and_always_needs_fix(self):
        q = {
            "number": 5,
            "question": "サンプル未分類問題です。",
            "choice_type": "unknown",
            "correct": ["A"],
            "explanation": "サンプル解説5。",
        }
        qa = question_to_qapair(q, "サンプル科目C")
        self.assertEqual(qa.front, q["question"])
        self.assertEqual(qa.qtype, "basic")
        self.assertTrue(qa.needs_fix)
        self.assertEqual(qa.tags, ["studying"])
        self.assertEqual(qa.knowledge_area, "サンプル科目C")

    def test_missing_choice_type_also_falls_back_to_basic(self):
        q = {
            "number": 6,
            "question": "サンプル未分類問題2。",
            "explanation": "解説6。",
        }
        qa = question_to_qapair(q, "サンプル科目C")
        self.assertEqual(qa.qtype, "basic")
        self.assertTrue(qa.needs_fix)


class TestIsStudyingJson(unittest.TestCase):
    def _valid_data(self):
        return {
            "course_title": "サンプルコース",
            "course_url": "https://example.invalid/course/sample",
            "category": "サンプルカテゴリ",
            "subject_title": "サンプル科目1",
            "practice_id": "p-001",
            "questions": [],
        }

    def test_valid_schema(self):
        self.assertTrue(is_studying_json(self._valid_data()))

    def test_missing_course_title(self):
        data = self._valid_data()
        del data["course_title"]
        self.assertFalse(is_studying_json(data))

    def test_missing_category(self):
        data = self._valid_data()
        del data["category"]
        self.assertFalse(is_studying_json(data))

    def test_missing_subject_title(self):
        data = self._valid_data()
        del data["subject_title"]
        self.assertFalse(is_studying_json(data))

    def test_missing_practice_id(self):
        data = self._valid_data()
        del data["practice_id"]
        self.assertFalse(is_studying_json(data))

    def test_missing_questions_key(self):
        data = self._valid_data()
        del data["questions"]
        self.assertFalse(is_studying_json(data))

    def test_questions_not_a_list(self):
        data = self._valid_data()
        data["questions"] = {}
        self.assertFalse(is_studying_json(data))

    def test_practice_id_wrong_type(self):
        data = self._valid_data()
        data["practice_id"] = 1
        self.assertFalse(is_studying_json(data))

    def test_non_dict_input(self):
        self.assertFalse(is_studying_json(["not", "a", "dict"]))


class TestSplitCourseTitle(unittest.TestCase):
    def test_grade_and_trademark_and_bracket_suffix(self):
        # 実機データでの検証済み実例（本体確認済み）。
        self.assertEqual(
            split_course_title(
                "サンプル検定® 2級合格コース［2026年11月～2027年7月試験対応］"
            ),
            ("サンプル検定", "2級"),
        )

    def test_no_grade_returns_course_title_as_name(self):
        self.assertEqual(
            split_course_title("サンプル対策コース"),
            ("サンプル対策コース", ""),
        )

    def test_trademark_removed_without_grade(self):
        self.assertEqual(
            split_course_title("サンプル講座®"),
            ("サンプル講座", ""),
        )

    def test_bracket_suffix_removed_without_grade(self):
        self.assertEqual(
            split_course_title("サンプル対策コース［2026年対応］"),
            ("サンプル対策コース", ""),
        )

    def test_whitespace_between_name_and_grade(self):
        self.assertEqual(
            split_course_title("サンプル検定 2級"),
            ("サンプル検定", "2級"),
        )

    def test_dai_n_type_grade(self):
        self.assertEqual(
            split_course_title("サンプル試験第一種講座"),
            ("サンプル試験", "第一種"),
        )

    def test_grade_only_input_falls_back(self):
        self.assertEqual(split_course_title("2級"), ("2級", ""))

    def test_empty_input(self):
        self.assertEqual(split_course_title(""), ("", ""))


class TestDefaultDeckName(unittest.TestCase):
    def test_format_with_grade(self):
        # 実機データでの検証済み実例（本体確認済み）:
        # "検定試験::知的財産管理技能検定::2級::studying::スマート問題集::商標法"
        self.assertEqual(
            default_deck_name(
                "サンプル検定® 2級合格コース［2026年11月～2027年7月試験対応］",
                "サンプルカテゴリ",
                "サンプル科目1",
            ),
            "検定試験::サンプル検定::2級::studying::サンプルカテゴリ::サンプル科目1",
        )

    def test_format_without_grade_falls_back_to_5_layers(self):
        self.assertEqual(
            default_deck_name("サンプル対策コース", "サンプルカテゴリ", "サンプル科目1"),
            "検定試験::サンプル対策コース::studying::サンプルカテゴリ::サンプル科目1",
        )

    def test_strips_surrounding_whitespace(self):
        self.assertEqual(
            default_deck_name(
                "  サンプル検定 2級  ", "  サンプルカテゴリ  ", "  サンプル科目1  "
            ),
            "検定試験::サンプル検定::2級::studying::サンプルカテゴリ::サンプル科目1",
        )


class TestLoadAndConvert(unittest.TestCase):
    def test_valid_file_roundtrip(self):
        data = {
            "course_title": "サンプルコース",
            "course_url": "https://example.invalid/course/sample",
            "category": "サンプルカテゴリ",
            "subject_title": "サンプル科目1",
            "practice_id": "p-001",
            "collected_at": "2026-07-16T05:12:34Z",
            "total_questions": 2,
            "questions": [
                {
                    "number": 1,
                    "question": "サンプル問題文1。",
                    "choice_type": "single",
                    "choices": ["A. 選択肢A", "B. 選択肢B"],
                    "correct": ["A"],
                    "explanation": "解説1。",
                },
                {
                    "number": 2,
                    "question": "サンプル○×問題2。",
                    "choice_type": "boolean",
                    "correct": [],
                    "explanation": "解説2。",
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
            self.assertEqual(loaded["subject_title"], "サンプル科目1")
            self.assertEqual(len(qas), 2)
            self.assertEqual(needs_fix, 1)
            self.assertEqual(qas[0].knowledge_area, "サンプル科目1")
            self.assertEqual(qas[1].knowledge_area, "サンプル科目1")
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
