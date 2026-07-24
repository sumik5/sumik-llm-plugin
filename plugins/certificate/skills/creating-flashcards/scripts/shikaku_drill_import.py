#!/usr/bin/env python3
"""shikaku_drill_import.py — shikaku-drill 収集済み JSON 専用の Anki 投入ブリッジ（恒久・常設）。

`collecting-shikaku-drill-exams` スキルが出力する固定スキーマ JSON
（トップレベル exam_title/slug/questions、questions[] は
number/category/question/choices/answer/explanation）を anki_toolkit の QAPair に
直接マッピングして投入する。

🔴 これは parser_scaffold.py のような使い捨てコピーではない。shikaku-drill JSON は
   collect スクリプト自身（DOM から確定取得済み）が管理する固定スキーマであり、書籍のような
   構造変異が起きないため、「ジェネリックパーサー禁止」ルールの明示的な例外として本ファイルを
   常設する（詳細: kentei_lab_import.py・whizlabs_import.py・studying_import.py と同格・
   INSTRUCTIONS.md の「shikaku-drill 収集済み JSON のファストパス」節）。将来「使い捨てルール
   違反」として削除・scaffold 化しないこと。

kentei-lab と異なり questions[] の各要素がカテゴリ（category）を持つため、デッキ名は
studying パターン（カテゴリをデッキ階層に含める）を踏襲する。ただし studying は
category が「1ファイル=1科目」という単位で固定なのに対し、shikaku-drill は「1ファイル=
1試験の全問題」でありカテゴリは問題ごとに異なりうるため、デッキ振り分けは question 単位で
行う（group_by_deck）。

anki_toolkit.py と同一ディレクトリに常設され、スクリプト自身のディレクトリが
sys.path[0] に入るため CLAUDE_PLUGIN_ROOT 環境変数は不要（parser_scaffold.py とは
import 方式が異なる）。
"""

from __future__ import annotations

import json
import re
import sys

from anki_toolkit import QAPair, RenderOptions, upload

# 先頭レターの許可集合。kentei_lab_import.py の _CORRECT_LETTER_RE と同一
# （shikaku-drill の answer 形式もレター+区切り+本文で同型のため流用する）。
_CORRECT_LETTER_RE = re.compile(
    r"^\s*([A-Za-zＡ-Ｚａ-ｚ0-9０-９①-⑳ア-ン])\s*[.．：:、)）]"
)

# 級（グレード）を表す末尾トークンの alternation。kentei_lab_import.py の _GRADE_ALT と同一。
_GRADE_ALT = (
    r"[准準]?[0-9０-９]+級"                     # 数字級・准/準+数字級（例: 1級, 2級, 3級, 准1級, 準2級）
    r"|[初中上]級"                              # 初級・中級・上級
    r"|[甲乙丙丁]種"                            # 甲種・乙種・丙種・丁種
    r"|第[0-9０-９一二三四五六七八九十百]+種"    # 第N種（算用/漢数字混在可・例: 第一種, 第1種, 第二種, 第4種）
    r"|[IVXivxⅠ-Ⅹ]+種"                         # ローマ数字+種（半角I/V/X・全角Ⅰ-Ⅹ・例: I種, II種, III種, Ⅱ種）
)

# shikaku-drill のサイト共通サフィックス（実機確認済み: document.title 由来の exam_title に
# 「無料問題集」が付与される。例: "メンタルヘルス・マネジメント検定Ⅰ種（マスター）無料問題集"）。
# 級検出の前に除去することで、級トークンなしの試験名でもサフィックスが検定名に残らないようにする。
_SITE_SUFFIX_RE = re.compile(r"無料問題集\s*$")

# 「（検定名）（空白?）（級トークン）（任意の後続文言）」を捉える。studying_import.py の
# _STUDYING_GRADE_RE と同じ非アンカー方式（級トークンの後ろに任意の文言が続くことを許容する）。
# 実例: "メンタルヘルス・マネジメント検定Ⅰ種（マスター）" → name="メンタルヘルス・マネジメント検定"、
# grade="Ⅰ種"、suffix="（マスター）"（suffix は使わず捨てる）。
_GRADE_SUFFIX_RE = re.compile(rf"^(?P<name>.*?)\s*(?P<grade>{_GRADE_ALT})(?P<suffix>.*)$")


def is_shikaku_drill_json(data: object) -> bool:
    """トップレベルが dict で exam_title/slug/questions(list) を持ち、questions[0] が
    category キー（str）を持てば True。

    exam_title/slug/questions の3キーは kentei-lab JSON と共通のため、questions[0] の
    category キーの有無で両者を区別する（creating-flashcards のファストパス検出・CLI の
    入力ガードに使う）。questions が空リストの場合は判別材料がないため False とする。
    """
    if not isinstance(data, dict):
        return False
    if not (
        isinstance(data.get("exam_title"), str)
        and isinstance(data.get("slug"), str)
        and isinstance(data.get("questions"), list)
    ):
        return False
    questions = data["questions"]
    if not questions:
        return False
    first = questions[0]
    return isinstance(first, dict) and isinstance(first.get("category"), str)


def split_exam_title(exam_title: str) -> tuple[str, str]:
    """exam_title を (検定名, 級) に分割する。

    サイト共通サフィックス「無料問題集」を除去してから級トークンを検出する。
    級が検出できなければ (サフィックス除去後の全体, "") を返す（級レベルを省略し、
    検定名として全体を使うフォールバック）。
    """
    title = (exam_title or "").strip()
    title = _SITE_SUFFIX_RE.sub("", title).strip()
    m = _GRADE_SUFFIX_RE.match(title)
    if not m:
        return (title, "")
    name = m.group("name").strip()
    grade = m.group("grade").strip()
    # 級トークンだけで検定名が空になる異常入力（例: "2級" 単独）は
    # 検定名として全体を使うフォールバックにする。
    if not name:
        return (title, "")
    return (name, grade)


def default_deck_name(exam_title: str, category: str) -> str:
    """既定デッキ名を返す（カテゴリ単位のサブデッキ）。

    級を検出できれば5階層 "検定試験::<検定名>::<級>::shikaku-drill::<category>"、
    検出できなければ4階層 "検定試験::<検定名>::shikaku-drill::<category>" を返す
    （kentei_lab_import.py と同じ "検定試験" トップカテゴリに統一し、出典="shikaku-drill" の
    直後にカテゴリを配置する構成。studying と異なりカテゴリは問題単位のため、呼び出し側は
    問題ごとにこの関数を呼んで振り分ける＝group_by_deck 参照）。
    """
    name, grade = split_exam_title(exam_title)
    cat = (category or "その他").strip() or "その他"
    if grade:
        return f"検定試験::{name}::{grade}::shikaku-drill::{cat}"
    return f"検定試験::{name}::shikaku-drill::{cat}"


def group_by_deck(exam_title: str, qas: list[QAPair]) -> dict[str, list[QAPair]]:
    """qas を各 QAPair.knowledge_area（=category）ごとにデッキ別へ振り分ける。

    shikaku-drill は1ファイル=1試験の全問題であり、studying（1ファイル=1科目）と異なり
    カテゴリが問題ごとに変わりうるため、ファイル単位ではなく問題単位でデッキを決定する。
    戻り値の順序は最初に出現した順（dict の挿入順）を保つ。
    """
    groups: dict[str, list[QAPair]] = {}
    for qa in qas:
        deck = default_deck_name(exam_title, qa.knowledge_area)
        groups.setdefault(deck, []).append(qa)
    return groups


def extract_correct_letters(answer: str) -> list[str]:
    """answer 先頭のレターを1件抽出する。抽出不可なら []（呼び出し側で needs_fix）。"""
    match = _CORRECT_LETTER_RE.match(answer or "")
    if not match:
        return []
    return [match.group(1)]


def _tag_safe(text: str) -> str:
    """Anki タグとして安全な文字列に整形する（空白をアンダースコアへ置換）。"""
    return re.sub(r"\s+", "_", text.strip())


def question_to_qapair(q: dict) -> QAPair:
    """questions[] の1要素を QAPair(qtype="choice") にマッピングする。

    category は knowledge_area（デッキ振り分けの根拠・[[extra-field]] 表示にも利用可）と
    tags（["shikaku-drill", <category>]）の両方に反映する。
    """
    answer = q.get("answer", "")
    correct = extract_correct_letters(answer)
    explanation = q.get("explanation", "")
    back = explanation.replace("\n", "<br>")
    category = q.get("category", "")
    tags = ["shikaku-drill"]
    if category:
        tags.append(_tag_safe(category))
    return QAPair(
        front=q.get("question", ""),
        back=back,
        qtype="choice",
        choices=list(q.get("choices", [])),
        correct=correct,
        wrong_explanations={},
        tags=tags,
        knowledge_area=category,
        needs_fix=not correct,
    )


def load_and_convert(path: str) -> tuple[dict, list[QAPair], int]:
    """JSON を読み、スキーマ検証し、(data, qapairs, needs_fix件数) を返す。"""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not is_shikaku_drill_json(data):
        raise ValueError(
            f"{path} is not a shikaku-drill schema JSON "
            "(top-level dict must have exam_title/slug/questions[list] with "
            "questions[0].category)"
        )
    qas = [question_to_qapair(q) for q in data["questions"]]
    needs_fix = sum(1 for qa in qas if qa.needs_fix)
    return data, qas, needs_fix


def main() -> None:
    import argparse

    ap = argparse.ArgumentParser(
        description="shikaku-drill 収集 JSON を Anki に投入する"
    )
    ap.add_argument("json_path")
    ap.add_argument(
        "--deck",
        default=None,
        help="全カードをこのデッキ1つに投入する（省略時はカテゴリ別デッキへ自動振り分け）",
    )
    ap.add_argument("--model", required=True)
    ap.add_argument("--front-field", default="Front")
    ap.add_argument("--back-field", default="Back")
    ap.add_argument("--extra-field", default=None)
    ap.add_argument("--choice-list-style", choices=["ol", "br"], default="ol")
    ap.add_argument("--no-skip-existing", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    data, qas, needs_fix = load_and_convert(args.json_path)
    field_map = {"front": args.front_field, "back": args.back_field}
    if args.extra_field:
        field_map["extra"] = args.extra_field
    render = RenderOptions(choice_list_style=args.choice_list_style)

    if args.deck:
        groups = {args.deck: qas}
    else:
        groups = group_by_deck(data["exam_title"], qas)

    print(
        f"exam_title={data['exam_title']} decks={len(groups)} "
        f"cards={len(qas)} needs_fix={needs_fix}",
        file=sys.stderr,
    )
    for deck, group_qas in groups.items():
        print(f"[deck] {deck} cards={len(group_qas)}", file=sys.stderr)

    if args.dry_run:
        if qas:
            s = qas[0]
            print(
                f"[sample] front={s.front!r} choices={s.choices!r} "
                f"correct={s.correct!r} knowledge_area={s.knowledge_area!r}",
                file=sys.stderr,
            )
        return

    total_added = 0
    total_skipped = 0
    total_media = 0
    all_errors: list = []
    for deck, group_qas in groups.items():
        result = upload(
            group_qas,
            deck_name=deck,
            model_name=args.model,
            field_map=field_map,
            render=render,
            skip_existing=not args.no_skip_existing,
        )
        total_added += result["added"]
        total_skipped += result["skipped_existing"]
        total_media += result["media_stored"]
        all_errors.extend(result["errors"])
        print(f"[deck] {deck} -> {result}", file=sys.stderr)

    print(
        {
            "added": total_added,
            "skipped_existing": total_skipped,
            "media_stored": total_media,
            "errors": all_errors,
        },
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
