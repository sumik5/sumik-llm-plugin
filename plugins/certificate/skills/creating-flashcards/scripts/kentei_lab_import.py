#!/usr/bin/env python3
"""kentei_lab_import.py — kentei-lab 収集済み JSON 専用の Anki 投入ブリッジ（恒久・常設）。

`collecting-kentei-lab-exams` スキルが出力する固定スキーマ JSON
（トップレベル exam_title/slug/questions、questions[] は
number/question/choices/answer/explanation）を anki_toolkit の QAPair に
直接マッピングして投入する。

🔴 これは parser_scaffold.py のような使い捨てコピーではない。kentei-lab JSON は
   collect スクリプト自身が管理する固定スキーマであり、書籍のような構造変異が
   起きないため、「ジェネリックパーサー禁止」ルールの明示的な例外として本ファイルを
   常設する（詳細: INSTRUCTIONS.md の「kentei-lab 収集済み JSON のファストパス」節）。
   将来「使い捨てルール違反」として削除・scaffold 化しないこと。

anki_toolkit.py と同一ディレクトリに常設され、スクリプト自身のディレクトリが
sys.path[0] に入るため CLAUDE_PLUGIN_ROOT 環境変数は不要（parser_scaffold.py とは
import 方式が異なる）。
"""

from __future__ import annotations

import json
import re
import sys

from anki_toolkit import QAPair, RenderOptions, upload

# 先頭レターの許可集合。anki_toolkit._choices_by_letter の許容文字種と整合させつつ、
# 区切り文字を必須にすることで平叙文の先頭文字を誤って正解レターと判定しない
# （_choices_by_letter 側は区切り任意=`?`だが、こちらは判定基準のため必須にする）。
_CORRECT_LETTER_RE = re.compile(
    r"^\s*([A-Za-zＡ-Ｚａ-ｚ0-9０-９①-⑳ア-ン])\s*[.．：:、)）]"
)


def is_kentei_lab_json(data: object) -> bool:
    """トップレベルが dict で exam_title / slug / questions(list) を持てば True。

    creating-flashcards のファストパス検出および CLI の入力ガードに使う。
    """
    if not isinstance(data, dict):
        return False
    return (
        isinstance(data.get("exam_title"), str)
        and isinstance(data.get("slug"), str)
        and isinstance(data.get("questions"), list)
    )


def default_deck_name(exam_title: str) -> str:
    """既定デッキ名 f"kentei-lab::{exam_title}" を返す（出典で名前空間分離）。"""
    return f"kentei-lab::{exam_title}"


def extract_correct_letters(answer: str) -> list[str]:
    """answer 先頭のレターを1件抽出する。抽出不可なら []（呼び出し側で needs_fix）。"""
    match = _CORRECT_LETTER_RE.match(answer or "")
    if not match:
        return []
    return [match.group(1)]


def question_to_qapair(q: dict) -> QAPair:
    """questions[] の1要素を QAPair(qtype="choice") にマッピングする。"""
    answer = q.get("answer", "")
    correct = extract_correct_letters(answer)
    explanation = q.get("explanation", "")
    back = explanation.replace("\n", "<br>")
    return QAPair(
        front=q.get("question", ""),
        back=back,
        qtype="choice",
        choices=list(q.get("choices", [])),
        correct=correct,
        wrong_explanations={},
        tags=["kentei-lab"],
        knowledge_area="",
        needs_fix=not correct,
    )


def load_and_convert(path: str) -> tuple[dict, list[QAPair], int]:
    """JSON を読み、スキーマ検証し、(data, qapairs, needs_fix件数) を返す。"""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not is_kentei_lab_json(data):
        raise ValueError(
            f"{path} is not a kentei-lab schema JSON "
            "(top-level dict must have exam_title/slug/questions[list])"
        )
    qas = [question_to_qapair(q) for q in data["questions"]]
    needs_fix = sum(1 for qa in qas if qa.needs_fix)
    return data, qas, needs_fix


def main() -> None:
    import argparse

    ap = argparse.ArgumentParser(
        description="kentei-lab 収集 JSON を Anki に投入する"
    )
    ap.add_argument("json_path")
    ap.add_argument("--deck", default=None)
    ap.add_argument("--model", required=True)
    ap.add_argument("--front-field", default="Front")
    ap.add_argument("--back-field", default="Back")
    ap.add_argument("--extra-field", default=None)
    ap.add_argument("--choice-list-style", choices=["ol", "br"], default="ol")
    ap.add_argument("--no-skip-existing", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    data, qas, needs_fix = load_and_convert(args.json_path)
    deck = args.deck or default_deck_name(data["exam_title"])
    field_map = {"front": args.front_field, "back": args.back_field}
    if args.extra_field:
        field_map["extra"] = args.extra_field
    render = RenderOptions(choice_list_style=args.choice_list_style)

    print(
        f"exam_title={data['exam_title']} deck={deck} "
        f"cards={len(qas)} needs_fix={needs_fix}",
        file=sys.stderr,
    )
    if args.dry_run:
        if qas:
            s = qas[0]
            print(
                f"[sample] front={s.front!r} choices={s.choices!r} "
                f"correct={s.correct!r}",
                file=sys.stderr,
            )
        return

    result = upload(
        qas,
        deck_name=deck,
        model_name=args.model,
        field_map=field_map,
        render=render,
        skip_existing=not args.no_skip_existing,
    )
    print(result, file=sys.stderr)


if __name__ == "__main__":
    main()
