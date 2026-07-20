#!/usr/bin/env python3
"""studying_import.py — studying 収集済み JSON 専用の Anki 投入ブリッジ（恒久・常設）。

`collecting-studying-exams` スキルが出力する固定スキーマ JSON
（トップレベル course_title/course_url/category/subject_title/practice_id/questions、
questions[] は number/question/choice_type/choices/correct/explanation）を anki_toolkit の
QAPair に直接マッピングして投入する。

🔴 これは parser_scaffold.py のような使い捨てコピーではない。studying JSON は
   collect スクリプト自身（DOM から確定取得済み）が管理する固定スキーマであり、書籍のような
   構造変異が起きないため、「ジェネリックパーサー禁止」ルールの明示的な例外として本ファイルを
   常設する（詳細: whizlabs_import.py・kentei_lab_import.py と同格・INSTRUCTIONS.md の「studying
   収集済み JSON のファストパス」節）。将来「使い捨てルール違反」として削除・scaffold 化しないこと。

anki_toolkit.py と同一ディレクトリに常設され、スクリプト自身のディレクトリが
sys.path[0] に入るため CLAUDE_PLUGIN_ROOT 環境変数は不要（parser_scaffold.py とは
import 方式が異なる）。
"""

from __future__ import annotations

import json
import re
import sys

from anki_toolkit import QAPair, RenderOptions, upload

# 級（グレード）を表すトークンの alternation。kentei_lab_import.py の _GRADE_ALT と同一
# （studying のコース名にも「2級」等の級表記が現れるため同じ判定基準を再利用する）。
_GRADE_ALT = (
    r"[准準]?[0-9０-９]+級"                     # 数字級・准/準+数字級（例: 1級, 2級, 3級, 准1級, 準2級）
    r"|[初中上]級"                              # 初級・中級・上級
    r"|[甲乙丙丁]種"                            # 甲種・乙種・丙種・丁種
    r"|第[0-9０-９一二三四五六七八九十百]+種"    # 第N種（算用/漢数字混在可・例: 第一種, 第1種, 第二種, 第4種）
    r"|[IVXivxⅠ-Ⅹ]+種"                         # ローマ数字+種（半角I/V/X・全角Ⅰ-Ⅹ・例: I種, II種, III種, Ⅱ種）
)

# 末尾の全角/半角角括弧ブロック（例:「［2026年11月～2027年7月試験対応］」等の試験対応期間の
# 注記）を除去する。studying のコースタイトルはこの角括弧サフィックスが付くことが多い。
_BRACKET_SUFFIX_RE = re.compile(r"[［\[][^］\]]*[］\]]\s*$")

# 「検定名＋（空白?）＋級トークン＋任意のコース種別文言（合格コース 等）」を捉える。
# kentei_lab_import.py の _GRADE_SUFFIX_RE と異なり、級トークンの後ろに任意の文言
# （studying の "合格コース" 等）が続くことを許容するため末尾アンカーにしない。
_STUDYING_GRADE_RE = re.compile(rf"^(?P<name>.*?)\s*(?P<grade>{_GRADE_ALT})(?P<suffix>.*)$")

# ®/™/© 等の商標記号除去（studying のコースタイトルに検定名直後で付与されることがある）。
_TRADEMARK_RE = re.compile(r"[®™©]")


def split_course_title(course_title: str) -> tuple[str, str]:
    """course_title を (検定名, 級) に分割する。

    studying の course_title は「検定名＋商標記号＋級＋"合格コース"等＋試験対応期間の
    角括弧書き」という形式を取ることがある（例:
    "知的財産管理技能検定® 2級合格コース［2026年11月～2027年7月試験対応］"）。
    末尾の角括弧サフィックスを除去したうえで級トークンを検出し、(検定名, 級) を返す。
    級を検出できなければ (検定名, "") を返す（studying_import.py 側の default_deck_name
    で級なしフォールバックに使う）。
    """
    title = (course_title or "").strip()
    title = _BRACKET_SUFFIX_RE.sub("", title).strip()
    m = _STUDYING_GRADE_RE.match(title)
    if not m:
        name = _TRADEMARK_RE.sub("", title).strip()
        return (name, "")
    name = _TRADEMARK_RE.sub("", m.group("name")).strip()
    grade = m.group("grade").strip()
    # 級トークンだけで検定名が空になる異常入力（例: "2級" 単独）は
    # 検定名として（角括弧除去後の）全体を使うフォールバックにする。
    if not name:
        return (title, "")
    return (name, grade)


def is_studying_json(data: object) -> bool:
    """トップレベルが dict で course_title / category / subject_title / practice_id / questions(list) を持てば True。

    creating-flashcards のファストパス検出および CLI の入力ガードに使う。
    """
    if not isinstance(data, dict):
        return False
    return (
        isinstance(data.get("course_title"), str)
        and isinstance(data.get("category"), str)
        and isinstance(data.get("subject_title"), str)
        and isinstance(data.get("practice_id"), str)
        and isinstance(data.get("questions"), list)
    )


def default_deck_name(course_title: str, category: str, subject_title: str) -> str:
    """既定デッキ名を返す。

    course_title を split_course_title() で (検定名, 級) に分割し、
    級を検出できれば 6 階層 "検定試験::<検定名>::<級>::studying::<category>::<subject_title>"、
    検出できなければ 5 階層 "検定試験::<検定名>::studying::<category>::<subject_title>" を返す
    （kentei_lab_import.py と同じ "検定試験" トップカテゴリに統一し、出典="studying" を
    カテゴリ・科目名の前＝級の直後に配置する構成）。コース単位でまとめたい場合や既存デッキ階層
    との整合が必要な場合は、呼び出し側（creating-flashcards のブリッジ手順）で AskUserQuestion
    により --deck を明示指定することを推奨する。
    """
    name, grade = split_course_title(course_title)
    cat = (category or "").strip()
    subject = (subject_title or "").strip()
    if grade:
        return f"検定試験::{name}::{grade}::studying::{cat}::{subject}"
    return f"検定試験::{name}::studying::{cat}::{subject}"


def question_to_qapair(q: dict, subject_title: str) -> QAPair:
    """questions[] の1要素を QAPair にマッピングする。

    choice_type によって QAPair.qtype への振り分けを変える:
    - "boolean"（○×形式）: qtype="truefalse"、correct[0]（"○"/"×"）を verdict に渡す
      （anki_toolkit が "×"→"✕"/"〇"→"○" を正規化する）。
    - "single"（4択等）: qtype="choice"、choices/correct をそのまま渡す
      （correct は DOM の「適切。」/「不適切。」表記から確定取得済みのレター配列）。
    - それ以外（"unknown" 等・選択肢マーカー未検出のフォールバック）: qtype="basic" とし
      needs_fix=True（"_要手修正" タグ付与）で投入し、後で手動確認できるようにする。

    knowledge_area には科目名（subject_title）を設定する（studying JSON は1ファイル=1科目の
    ため、questions[] 内に科目名を持たない。呼び出し側から渡す）。
    """
    choice_type = q.get("choice_type", "")
    correct = list(q.get("correct", []))
    explanation = q.get("explanation", "")

    if choice_type == "boolean":
        return QAPair(
            front=q.get("question", ""),
            back=explanation,
            qtype="truefalse",
            verdict=correct[0] if correct else "",
            tags=["studying"],
            knowledge_area=subject_title,
            needs_fix=not correct,
        )

    if choice_type == "single":
        return QAPair(
            front=q.get("question", ""),
            back=explanation,
            qtype="choice",
            choices=list(q.get("choices", [])),
            correct=correct,
            tags=["studying"],
            knowledge_area=subject_title,
            needs_fix=not correct,
        )

    # choice_type が "unknown" 等の未知値: 選択肢マーカーを検出できなかったフォールバック。
    # 生テキストのまま basic として保持し、要手動確認としてマークする。
    return QAPair(
        front=q.get("question", ""),
        back=explanation,
        qtype="basic",
        tags=["studying"],
        knowledge_area=subject_title,
        needs_fix=True,
    )


def load_and_convert(path: str) -> tuple[dict, list[QAPair], int]:
    """JSON を読み、スキーマ検証し、(data, qapairs, needs_fix件数) を返す。"""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not is_studying_json(data):
        raise ValueError(
            f"{path} is not a studying schema JSON "
            "(top-level dict must have course_title/category/subject_title/practice_id/questions[list])"
        )
    subject_title = data["subject_title"]
    qas = [question_to_qapair(q, subject_title) for q in data["questions"]]
    needs_fix = sum(1 for qa in qas if qa.needs_fix)
    return data, qas, needs_fix


def main() -> None:
    import argparse

    ap = argparse.ArgumentParser(
        description="studying 収集 JSON を Anki に投入する"
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
    deck = args.deck or default_deck_name(
        data["course_title"], data["category"], data["subject_title"]
    )
    field_map = {"front": args.front_field, "back": args.back_field}
    if args.extra_field:
        field_map["extra"] = args.extra_field
    render = RenderOptions(choice_list_style=args.choice_list_style)

    print(
        f"course_title={data['course_title']} category={data['category']} "
        f"subject_title={data['subject_title']} deck={deck} cards={len(qas)} "
        f"needs_fix={needs_fix}",
        file=sys.stderr,
    )
    if args.dry_run:
        if qas:
            s = qas[0]
            print(
                f"[sample] front={s.front!r} qtype={s.qtype!r} choices={s.choices!r} "
                f"correct={s.correct!r} verdict={s.verdict!r}",
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
