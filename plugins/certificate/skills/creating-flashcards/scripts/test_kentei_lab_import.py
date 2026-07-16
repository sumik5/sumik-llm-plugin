#!/usr/bin/env python3
"""test_kentei_lab_import.py — kentei_lab_import.py の単体テスト（標準ライブラリ unittest のみ）。

extract_correct_letters / question_to_qapair / is_kentei_lab_json /
default_deck_name / load_and_convert の変換ロジックを検証する。
AnkiConnect・Anki起動は不要（anki_toolkit への実通信は行わない）。

実行: python3 -m unittest test_kentei_lab_import -v
"""

import json
import os
import tempfile
import unittest

from kentei_lab_import import (
    default_deck_name,
    extract_correct_letters,
    is_kentei_lab_json,
    load_and_convert,
    question_to_qapair,
    split_exam_title,
)


class TestExtractCorrectLetters(unittest.TestCase):
    def test_letter_with_period(self):
        self.assertEqual(extract_correct_letters("C. 1972年"), ["C"])

    def test_letter_with_fullwidth_period(self):
        self.assertEqual(extract_correct_letters("Ａ．1945年"), ["Ａ"])

    def test_leading_whitespace_allowed(self):
        self.assertEqual(extract_correct_letters("  D) 1992年"), ["D"])

    def test_no_separator_returns_empty(self):
        # 区切り文字がない平叙文の先頭文字を誤って正解レターと判定しない
        self.assertEqual(extract_correct_letters("1972年に採択された"), [])

    def test_empty_string_returns_empty(self):
        self.assertEqual(extract_correct_letters(""), [])

    def test_numeric_label(self):
        self.assertEqual(extract_correct_letters("1. 世界遺産条約"), ["1"])


class TestQuestionToQAPair(unittest.TestCase):
    def test_basic_mapping(self):
        q = {
            "number": 1,
            "question": "世界遺産条約が採択されたのは何年か。",
            "choices": ["A. 1945年", "B. 1964年", "C. 1972年", "D. 1992年"],
            "answer": "C. 1972年",
            "explanation": "1972年の第17回ユネスコ総会で採択された。",
        }
        qa = question_to_qapair(q)
        self.assertEqual(qa.front, q["question"])
        self.assertEqual(qa.qtype, "choice")
        self.assertEqual(qa.choices, q["choices"])
        self.assertEqual(qa.correct, ["C"])
        self.assertEqual(qa.wrong_explanations, {})
        self.assertEqual(qa.tags, ["kentei-lab"])
        self.assertEqual(qa.knowledge_area, "")
        self.assertFalse(qa.needs_fix)

    def test_explanation_newline_converted_to_br(self):
        q = {
            "number": 2,
            "question": "Q",
            "choices": ["A. x", "B. y"],
            "answer": "A. x",
            "explanation": "1行目\n2行目",
        }
        qa = question_to_qapair(q)
        self.assertEqual(qa.back, "1行目<br>2行目")

    def test_needs_fix_when_answer_unparseable(self):
        q = {
            "number": 3,
            "question": "Q",
            "choices": ["A. x", "B. y"],
            "answer": "正解不明",
            "explanation": "解説",
        }
        qa = question_to_qapair(q)
        self.assertEqual(qa.correct, [])
        self.assertTrue(qa.needs_fix)


class TestIsKenteiLabJson(unittest.TestCase):
    def test_valid_schema(self):
        data = {"exam_title": "世界遺産検定2級", "slug": "sekai2kyu", "questions": []}
        self.assertTrue(is_kentei_lab_json(data))

    def test_missing_questions_key(self):
        data = {"exam_title": "世界遺産検定2級", "slug": "sekai2kyu"}
        self.assertFalse(is_kentei_lab_json(data))

    def test_questions_not_a_list(self):
        data = {"exam_title": "t", "slug": "s", "questions": {}}
        self.assertFalse(is_kentei_lab_json(data))

    def test_non_dict_input(self):
        self.assertFalse(is_kentei_lab_json(["not", "a", "dict"]))


class TestDefaultDeckName(unittest.TestCase):
    def test_grade_numeric(self):
        self.assertEqual(
            default_deck_name("世界遺産検定2級"),
            "検定試験::世界遺産検定::2級::kentei-lab",
        )

    def test_grade_jun_number(self):
        self.assertEqual(
            default_deck_name("サンプル検定准1級"),
            "検定試験::サンプル検定::准1級::kentei-lab",
        )

    def test_grade_jun_alt_kanji(self):
        self.assertEqual(
            default_deck_name("サンプル検定準2級"),
            "検定試験::サンプル検定::準2級::kentei-lab",
        )

    def test_grade_roman_type(self):
        self.assertEqual(
            default_deck_name("サンプル試験II種"),
            "検定試験::サンプル試験::II種::kentei-lab",
        )

    def test_grade_kanji_type_ko(self):
        self.assertEqual(
            default_deck_name("サンプル試験甲種"),
            "検定試験::サンプル試験::甲種::kentei-lab",
        )

    def test_grade_kanji_type_otsu(self):
        self.assertEqual(
            default_deck_name("サンプル試験乙種"),
            "検定試験::サンプル試験::乙種::kentei-lab",
        )

    def test_grade_dai_n_type_kanji_number(self):
        self.assertEqual(
            default_deck_name("サンプル試験第一種"),
            "検定試験::サンプル試験::第一種::kentei-lab",
        )

    def test_grade_dai_n_type_arabic_number(self):
        self.assertEqual(
            default_deck_name("サンプル試験第2種"),
            "検定試験::サンプル試験::第2種::kentei-lab",
        )

    def test_grade_level_words_beginner(self):
        self.assertEqual(
            default_deck_name("サンプル検定初級"),
            "検定試験::サンプル検定::初級::kentei-lab",
        )

    def test_grade_level_words_advanced(self):
        self.assertEqual(
            default_deck_name("サンプル検定上級"),
            "検定試験::サンプル検定::上級::kentei-lab",
        )

    def test_no_grade_three_levels(self):
        self.assertEqual(
            default_deck_name("TOEIC"),
            "検定試験::TOEIC::kentei-lab",
        )

    def test_whitespace_separated_halfwidth(self):
        self.assertEqual(
            default_deck_name("世界遺産検定 2級"),
            "検定試験::世界遺産検定::2級::kentei-lab",
        )

    def test_whitespace_separated_fullwidth(self):
        self.assertEqual(
            default_deck_name("世界遺産検定　2級"),
            "検定試験::世界遺産検定::2級::kentei-lab",
        )


class TestSplitExamTitle(unittest.TestCase):
    def test_name_and_grade_split(self):
        self.assertEqual(split_exam_title("世界遺産検定2級"), ("世界遺産検定", "2級"))

    def test_whitespace_not_left_in_name(self):
        self.assertEqual(split_exam_title("世界遺産検定 2級"), ("世界遺産検定", "2級"))

    def test_no_grade_returns_empty_grade(self):
        self.assertEqual(split_exam_title("TOEIC"), ("TOEIC", ""))

    def test_dai_n_type_split(self):
        self.assertEqual(split_exam_title("サンプル試験第一種"), ("サンプル試験", "第一種"))

    def test_grade_only_input_falls_back(self):
        self.assertEqual(split_exam_title("2級"), ("2級", ""))


class TestLoadAndConvert(unittest.TestCase):
    def test_valid_file_roundtrip(self):
        data = {
            "exam_title": "世界遺産検定2級",
            "slug": "sekai2kyu",
            "source_url": "https://kentei-lab.com/exams/sekai2kyu",
            "collected_at": "2026-07-16T05:12:34Z",
            "total_questions": 1,
            "questions": [
                {
                    "number": 1,
                    "question": "世界遺産条約が採択されたのは何年か。",
                    "choices": ["A. 1945年", "B. 1964年", "C. 1972年", "D. 1992年"],
                    "answer": "C. 1972年",
                    "explanation": "1972年に採択された。",
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
            self.assertEqual(loaded["exam_title"], "世界遺産検定2級")
            self.assertEqual(len(qas), 1)
            self.assertEqual(needs_fix, 0)
            self.assertEqual(qas[0].correct, ["C"])
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
