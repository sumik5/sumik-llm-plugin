#!/usr/bin/env python3
"""whizlabs_import.py — Whizlabs 収集済み JSON 専用の Anki 投入ブリッジ（恒久・常設）。

`collecting-whizlabs-exams` スキルが出力する固定スキーマ JSON
（トップレベル course_title/course_url/quiz_title/quiz_id/questions、questions[] は
number/domain/question/choices/choice_type/correct/explanation_html）を anki_toolkit の
QAPair に直接マッピングして投入する。

🔴 これは parser_scaffold.py のような使い捨てコピーではない。whizlabs JSON は
   collect スクリプト自身（DOM から確定取得済み）が管理する固定スキーマであり、書籍のような
   構造変異が起きないため、「ジェネリックパーサー禁止」ルールの明示的な例外として本ファイルを
   常設する（詳細: kentei_lab_import.py と同格・INSTRUCTIONS.md の「whizlabs 収集済み JSON の
   ファストパス」節）。将来「使い捨てルール違反」として削除・scaffold 化しないこと。

anki_toolkit.py と同一ディレクトリに常設され、スクリプト自身のディレクトリが
sys.path[0] に入るため CLAUDE_PLUGIN_ROOT 環境変数は不要（parser_scaffold.py とは
import 方式が異なる）。
"""

from __future__ import annotations

import json
import sys

from anki_toolkit import QAPair, RenderOptions, upload


def is_whizlabs_json(data: object) -> bool:
    """トップレベルが dict で course_title / quiz_title / quiz_id / questions(list) を持てば True。

    creating-flashcards のファストパス検出および CLI の入力ガードに使う。
    """
    if not isinstance(data, dict):
        return False
    return (
        isinstance(data.get("course_title"), str)
        and isinstance(data.get("quiz_title"), str)
        and isinstance(data.get("quiz_id"), str)
        and isinstance(data.get("questions"), list)
    )


def default_deck_name(course_title: str, quiz_title: str) -> str:
    """既定デッキ名を返す。

    "資格試験::<course_title>::<quiz_title>::whizlabs" 形式（コース単位ではなく
    クイズ単位でサブデッキを分ける）。コース単位でまとめたい場合や既存デッキ階層との
    整合が必要な場合は、呼び出し側（creating-flashcards のブリッジ手順）で
    AskUserQuestion により --deck を明示指定することを推奨する。
    """
    course = (course_title or "").strip()
    quiz = (quiz_title or "").strip()
    return f"資格試験::{course}::{quiz}::whizlabs"


def question_to_qapair(q: dict) -> QAPair:
    """questions[] の1要素を QAPair(qtype="choice") にマッピングする。

    correct は DOM から確定取得済みのレター配列（MCMR なら複数要素）をそのまま渡す
    （kentei-lab 版と異なり、answer 文字列からの抽出は不要）。
    explanation_html は Reference を含む生HTMLのため、back へそのまま渡す
    （anki_toolkit は back を raw HTML 素通しする仕様）。
    """
    correct = list(q.get("correct", []))
    return QAPair(
        front=q.get("question", ""),
        back=q.get("explanation_html", ""),
        qtype="choice",
        choices=list(q.get("choices", [])),
        correct=correct,
        wrong_explanations={},
        tags=["whizlabs"],
        knowledge_area=q.get("domain", ""),
        needs_fix=not correct,
    )


def load_and_convert(path: str) -> tuple[dict, list[QAPair], int]:
    """JSON を読み、スキーマ検証し、(data, qapairs, needs_fix件数) を返す。"""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not is_whizlabs_json(data):
        raise ValueError(
            f"{path} is not a whizlabs schema JSON "
            "(top-level dict must have course_title/quiz_title/quiz_id/questions[list])"
        )
    qas = [question_to_qapair(q) for q in data["questions"]]
    needs_fix = sum(1 for qa in qas if qa.needs_fix)
    return data, qas, needs_fix


def main() -> None:
    import argparse

    ap = argparse.ArgumentParser(
        description="whizlabs 収集 JSON を Anki に投入する"
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
    deck = args.deck or default_deck_name(data["course_title"], data["quiz_title"])
    field_map = {"front": args.front_field, "back": args.back_field}
    if args.extra_field:
        field_map["extra"] = args.extra_field
    render = RenderOptions(choice_list_style=args.choice_list_style)

    print(
        f"course_title={data['course_title']} quiz_title={data['quiz_title']} "
        f"deck={deck} cards={len(qas)} needs_fix={needs_fix}",
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
