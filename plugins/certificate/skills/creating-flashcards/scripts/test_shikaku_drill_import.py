#!/usr/bin/env python3
"""test_shikaku_drill_import.py — shikaku_drill_import.py の単体テスト（標準ライブラリ unittest のみ）。

extract_correct_letters / question_to_qapair / is_shikaku_drill_json /
split_exam_title / default_deck_name / group_by_deck / load_and_convert の
変換ロジックを検証する。AnkiConnect・Anki起動は不要（anki_toolkit への実通信は行わない）。

実行: python3 -m unittest test_shikaku_drill_import -v
"""

import json
import os
import tempfile
import unittest

from shikaku_drill_import import (
    default_deck_name,
    extract_correct_letters,
    group_by_deck,
    is_shikaku_drill_json,
    load_and_convert,
    question_to_qapair,
    split_exam_title,
)


class TestExtractCorrectLetters(unittest.TestCase):
    def test_letter_with_period(self):
        self.assertEqual(extract_correct_letters("A. 活力・熱意・没頭の3つの要素"), ["A"])

    def test_letter_with_fullwidth_period(self):
        self.assertEqual(extract_correct_letters("Ａ．説明文"), ["Ａ"])

    def test_leading_whitespace_allowed(self):
        self.assertEqual(extract_correct_letters("  C) 説明文"), ["C"])

    def test_no_separator_returns_empty(self):
        self.assertEqual(extract_correct_letters("説明文のみで区切り文字がない"), [])

    def test_empty_string_returns_empty(self):
        self.assertEqual(extract_correct_letters(""), [])


class TestQuestionToQAPair(unittest.TestCase):
    def test_basic_mapping(self):
        q = {
            "number": 1,
            "category": "企業経営におけるメンタルヘルス対策の意義と重要性",
            "question": "ワーク・エンゲイジメントに関する記述として正しいものはどれか。",
            "choices": ["A. 選択肢A", "B. 選択肢B", "C. 選択肢C", "D. 選択肢D"],
            "answer": "A. 選択肢A",
            "explanation": "解説文",
        }
        qa = question_to_qapair(q)
        self.assertEqual(qa.front, q["question"])
        self.assertEqual(qa.qtype, "choice")
        self.assertEqual(qa.choices, q["choices"])
        self.assertEqual(qa.correct, ["A"])
        self.assertEqual(qa.wrong_explanations, {})
        self.assertEqual(qa.tags, ["shikaku-drill", "企業経営におけるメンタルヘルス対策の意義と重要性"])
        self.assertEqual(qa.knowledge_area, q["category"])
        self.assertFalse(qa.needs_fix)

    def test_category_with_whitespace_sanitized_in_tag(self):
        q = {
            "number": 2,
            "category": "職場 復帰支援",
            "question": "Q",
            "choices": ["A. x", "B. y"],
            "answer": "A. x",
            "explanation": "解説",
        }
        qa = question_to_qapair(q)
        self.assertEqual(qa.tags, ["shikaku-drill", "職場_復帰支援"])
        # knowledge_area は元のカテゴリ文字列のまま（タグとは独立）
        self.assertEqual(qa.knowledge_area, "職場 復帰支援")

    def test_explanation_newline_converted_to_br(self):
        q = {
            "number": 3,
            "category": "教育研修",
            "question": "Q",
            "choices": ["A. x", "B. y"],
            "answer": "A. x",
            "explanation": "1行目\n2行目",
        }
        qa = question_to_qapair(q)
        self.assertEqual(qa.back, "1行目<br>2行目")

    def test_needs_fix_when_answer_unparseable(self):
        q = {
            "number": 4,
            "category": "職場復帰支援",
            "question": "Q",
            "choices": ["A. x", "B. y"],
            "answer": "正解不明",
            "explanation": "解説",
        }
        qa = question_to_qapair(q)
        self.assertEqual(qa.correct, [])
        self.assertTrue(qa.needs_fix)


class TestIsShikakuDrillJson(unittest.TestCase):
    def test_valid_schema(self):
        data = {
            "exam_title": "メンタルヘルス・マネジメント検定Ⅰ種（マスター）無料問題集",
            "slug": "mental1",
            "questions": [{"number": 1, "category": "教育研修"}],
        }
        self.assertTrue(is_shikaku_drill_json(data))

    def test_missing_category_key_is_not_shikaku_drill(self):
        # exam_title/slug/questions の3キーは kentei-lab と共通のため、
        # questions[0] に category が無ければ False（kentei-lab JSON として扱われるべき）
        data = {
            "exam_title": "世界遺産検定2級",
            "slug": "sekai2kyu",
            "questions": [{"number": 1, "question": "Q", "answer": "A. x"}],
        }
        self.assertFalse(is_shikaku_drill_json(data))

    def test_empty_questions_returns_false(self):
        data = {"exam_title": "t", "slug": "s", "questions": []}
        self.assertFalse(is_shikaku_drill_json(data))

    def test_missing_questions_key(self):
        data = {"exam_title": "t", "slug": "s"}
        self.assertFalse(is_shikaku_drill_json(data))

    def test_questions_not_a_list(self):
        data = {"exam_title": "t", "slug": "s", "questions": {}}
        self.assertFalse(is_shikaku_drill_json(data))

    def test_non_dict_input(self):
        self.assertFalse(is_shikaku_drill_json(["not", "a", "dict"]))


class TestSplitExamTitle(unittest.TestCase):
    def test_site_suffix_and_grade_split(self):
        self.assertEqual(
            split_exam_title("メンタルヘルス・マネジメント検定Ⅰ種（マスター）無料問題集"),
            ("メンタルヘルス・マネジメント検定", "Ⅰ種"),
        )

    def test_site_suffix_only_no_grade(self):
        self.assertEqual(
            split_exam_title("ITパスポート試験無料問題集"),
            ("ITパスポート試験", ""),
        )

    def test_no_suffix_no_grade(self):
        self.assertEqual(split_exam_title("TOEIC"), ("TOEIC", ""))

    def test_numeric_grade(self):
        self.assertEqual(
            split_exam_title("世界遺産検定2級無料問題集"),
            ("世界遺産検定", "2級"),
        )

    def test_grade_only_input_falls_back(self):
        self.assertEqual(split_exam_title("2級"), ("2級", ""))


class TestDefaultDeckName(unittest.TestCase):
    def test_with_grade(self):
        self.assertEqual(
            default_deck_name(
                "メンタルヘルス・マネジメント検定Ⅰ種（マスター）無料問題集",
                "教育研修",
            ),
            "検定試験::メンタルヘルス・マネジメント検定::Ⅰ種::shikaku-drill::教育研修",
        )

    def test_without_grade(self):
        self.assertEqual(
            default_deck_name("ITパスポート試験無料問題集", "ネットワーク"),
            "検定試験::ITパスポート試験::shikaku-drill::ネットワーク",
        )

    def test_empty_category_falls_back_to_sonota(self):
        self.assertEqual(
            default_deck_name("ITパスポート試験無料問題集", ""),
            "検定試験::ITパスポート試験::shikaku-drill::その他",
        )


class TestGroupByDeck(unittest.TestCase):
    def test_groups_by_category_preserving_first_seen_order(self):
        qas = [
            question_to_qapair(
                {"number": 1, "category": "カテゴリA", "question": "Q1",
                 "choices": ["A. x", "B. y"], "answer": "A. x", "explanation": ""}
            ),
            question_to_qapair(
                {"number": 2, "category": "カテゴリB", "question": "Q2",
                 "choices": ["A. x", "B. y"], "answer": "A. x", "explanation": ""}
            ),
            question_to_qapair(
                {"number": 3, "category": "カテゴリA", "question": "Q3",
                 "choices": ["A. x", "B. y"], "answer": "A. x", "explanation": ""}
            ),
        ]
        groups = group_by_deck("サンプル試験無料問題集", qas)
        self.assertEqual(
            list(groups.keys()),
            [
                "検定試験::サンプル試験::shikaku-drill::カテゴリA",
                "検定試験::サンプル試験::shikaku-drill::カテゴリB",
            ],
        )
        self.assertEqual(len(groups["検定試験::サンプル試験::shikaku-drill::カテゴリA"]), 2)
        self.assertEqual(len(groups["検定試験::サンプル試験::shikaku-drill::カテゴリB"]), 1)


class TestLoadAndConvert(unittest.TestCase):
    def test_valid_file_roundtrip(self):
        data = {
            "exam_title": "メンタルヘルス・マネジメント検定Ⅰ種（マスター）無料問題集",
            "slug": "mental1",
            "source_url": "https://shikaku-drill.com/mental1.html",
            "collected_at": "2026-07-24T04:12:29Z",
            "total_questions": 1,
            "questions": [
                {
                    "number": 1,
                    "category": "教育研修",
                    "question": "Q",
                    "choices": ["A. x", "B. y"],
                    "answer": "A. x",
                    "explanation": "解説",
                }
            ],
        }
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False, encoding="utf-8"
        ) as f:
            json.dump(data, f, ensure_ascii=False)
            path = f.name
        try:
            loaded, qas, needs_fix = load_and_convert(path)
            self.assertEqual(loaded["exam_title"], data["exam_title"])
            self.assertEqual(len(qas), 1)
            self.assertEqual(needs_fix, 0)
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
