#!/usr/bin/env python3
"""coordinate_page_scaffold.py — 座標マッチング方式の1ソース1コピー用ページペアリング雛形。

使い方: 本ファイルを `/tmp/coordinate-page-<descriptive-name>.py` にコピーし、
ソース固有の部分（`PAGE_OFFSET`・ページファイル名パターン・基礎知識ページの
見出しキーワード・出典表記の正規化ルール等）を対象書籍のMarkdown/画像を
目視確認したうえで埋める。投入インフラ(`anki_toolkit`)・座標マッチング
エンジン(`coordinate_marker_extract`)は書き換えない。

🔴 ジェネリック化禁止: 見出しキーワードや年度表記形式は書籍によって変異する
   ため、共通ヘルパーへ一括吸収しない。過去のコピーを再利用せず、必ず
   ソースを目視してから書く（`parser_scaffold.py` と同じ鉄則）。

対象レイアウト: 「テーマ単位ページ分離型」（[INSTRUCTIONS.md](../INSTRUCTIONS.md)
の Step 3 参照）のうち、実践ページ側が見開き型（本文列＋マージン列の座標分離
判定マーカー）になっている資格試験対策書籍。基礎知識ページ（左ページ相当）
と実践ページ（右ページ相当。`coordinate_marker_extract.extract_practice_page`
で抽出）を、印刷ページ番号（フッター「・NNN・」）をキーに対応付ける。
"""
import json
import os
import re
import sys

# coordinate_marker_extract / anki_toolkit を import（スキルの scripts ディレクトリを sys.path に追加）。
#   優先: CLAUDE_PLUGIN_ROOT 環境変数（/tmp 実行でも解決できる）。
#   フォールバック: <CLAUDE_PLUGIN_ROOT> プレースホルダ（コピー時に実パス置換する）。
_plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT", "<CLAUDE_PLUGIN_ROOT>")
sys.path.insert(0, f"{_plugin_root}/skills/creating-flashcards/scripts")
from anki_toolkit import QAPair, RenderOptions, upload   # noqa: E402,F401
from coordinate_marker_extract import extract_practice_page   # noqa: E402


# ─────────────────────────────────────────────
# 基礎知識ページ（左ページ相当）の解析
#   ※ 本体の構造解析はこのソース1冊専用（ジェネリック化禁止）。ただし
#     見出しキーワード判定は「参考実装」として残す（下記docstring参照）。
# ─────────────────────────────────────────────

PAGE_SEP = "\n\n---\n\n"  # ページ区切り（ocr-apple-vision 出力の慣習）。ソースにより異なりうる


def smart_join(lines):
    """ソフトラップ結合。結合境界の左右が両方 ASCII 英数字のときだけ半角空白挿入。"""
    out = ""
    for s in (x.strip() for x in lines):
        if not s:
            continue
        if out and re.match(r"[A-Za-z0-9]", out[-1]) and re.match(r"[A-Za-z0-9]", s[0]):
            out += " "
        out += s
    return out


def parse_basic_pages(md_text):
    """基礎知識ページを 印刷ページ番号 -> {編/テーマ/項目} の辞書に変換する。

    🔵 「参考実装」: `"基礎知識"` / `"必ず出る"` の見出しキーワード判定は、
       多くの日本語資格試験書籍で流用できる可能性が高いが、書籍によって
       見出し表記が変わりうる（例: 「要点整理」「POINT」等）ため、コピー先で
       必ず対象書籍のMarkdownを目視確認してから使うこと。表記が異なる場合は
       このキーワードを差し替える。
    """
    pages = md_text.split(PAGE_SEP)
    topics = {}
    current_bian_num = None
    current_bian_title = None
    bian_pages = []

    for page in pages:
        lines = [l.strip() for l in page.split("\n") if l.strip()]
        if not lines:
            continue

        bian_match = None
        for i, l in enumerate(lines):
            m = re.match(r'^第\s*(\d+)\s*編\s*$', l)
            if m:
                bian_match = (i, m)
                break
        if bian_match and len(lines) <= 8:
            idx, m = bian_match
            current_bian_num = int(m.group(1))
            title_lines = [l for j, l in enumerate(lines) if j != idx]
            current_bian_title = "".join(title_lines)
            bian_pages.append((current_bian_num, current_bian_title))
            continue

        if "基礎知識" not in lines:
            continue

        try:
            idx_hitsu = next(i for i, l in enumerate(lines) if "必ず出る" in l)
        except StopIteration:
            idx_hitsu = min(6, len(lines))

        search_range = lines[:idx_hitsu]
        topic_num, topic_title = None, None
        num_idx = None
        for i, l in enumerate(search_range):
            if re.match(r'^\d{1,3}$', l):
                num_idx = i
                topic_num = int(l)
                break
        if num_idx is not None:
            topic_title = "".join(search_range[:num_idx])
            if not topic_title:
                # some pages OCR the number line BEFORE the title line instead
                # of after (column-reconstruction order is not fully stable)
                topic_title = "".join(search_range[num_idx + 1:])

        footer_num = None
        for l in reversed(lines):
            m = re.match(r'^[・･.]\s*(\d{1,4})\s*[・･.]$', l)
            if m:
                footer_num = int(m.group(1))
                break

        items = {}
        cur_num, cur_lines = None, []
        item_start_re = re.compile(r'^[（(](\d{1,3})[）)]')
        footer_line_re = re.compile(r'^[・･.]\s*\d{1,4}\s*[・･.]$')
        for l in lines:
            m = item_start_re.match(l)
            if m:
                if cur_num is not None:
                    items[cur_num] = smart_join(cur_lines)
                cur_num = int(m.group(1))
                cur_lines = [item_start_re.sub("", l)]
            elif cur_num is not None:
                if footer_line_re.match(l):
                    continue
                cur_lines.append(l)
        if cur_num is not None:
            items[cur_num] = smart_join(cur_lines)

        if footer_num is not None:
            topics[footer_num] = {
                "bian_num": current_bian_num,
                "bian_title": current_bian_title,
                "topic_num": topic_num,
                "topic_title": topic_title,
                "items": items,
            }

    return topics, bian_pages


# ─────────────────────────────────────────────
# 出典表記の正規化ルール（元号表記正規化）
# ─────────────────────────────────────────────


def era_year_tag(citation):
    """H18-33 -> 平成18年 / S60-26 -> 昭和60年 / R6-... -> 令和6年 / T.. -> 大正

    🔵 「参考実装」: H/S/R/T の元号プレフィックス正規化は日本語資格試験
       過去問の出典表記でよく見る形式だが、書籍によって表記が異なりうる
       （例: 西暦表記のみ・年度なし等）。コピー先で確認してから使うこと。
    """
    m = re.match(r'^([HSRT])\s*(\d+)', citation)
    if not m:
        return None
    era_map = {"H": "平成", "S": "昭和", "R": "令和", "T": "大正"}
    return f"{era_map[m.group(1)]}{m.group(2)}年"


# ─────────────────────────────────────────────
# 🔴 ここから下がソース固有。毎回手書きで確認・置換する
# ─────────────────────────────────────────────

# TODO: このソース固有の値に置き換える（実践ページの物理ファイル連番 =
#   印刷ページ番号 + PAGE_OFFSET。対象書籍のページを実測して確定する値）
PAGE_OFFSET = 20

# TODO: このソース固有の値に置き換える（ページ画像格納ディレクトリ名）
PAGES_DIR = "<pages-dir>"

# TODO: このソース固有の値に置き換える（基礎知識ページの変換済みMarkdownパス）
BASIC_KNOWLEDGE_MD_PATH = "<basic-knowledge>.md"


def build():
    """基礎知識ページ解析 + 座標マッチング実践ページ抽出を結合し、QAPair相当の
    dict リストを構築するドライバ。

    結合キー: 印刷ページのフッター番号。基礎知識ページ N は対向する実践
    ページ N+1 とペアになる（見開き設計）。物理jpgインデックス =
    印刷ページ番号 + PAGE_OFFSET（TODO: この対応関係自体もソース固有。
    見開き構成が異なる書籍ではオフセット式そのものを見直すこと）。
    """
    with open(BASIC_KNOWLEDGE_MD_PATH, encoding="utf-8") as f:
        md = f.read()
    topics, bian_pages = parse_basic_pages(md)
    print(f"[info] basic-knowledge pages parsed: {len(topics)}", file=sys.stderr)

    qas = []
    stats = {
        "topics_total": len(topics),
        "practice_pages_attempted": 0,
        "practice_pages_extract_failed": 0,
        "questions_total": 0,
        "questions_matched": 0,
        "questions_needs_fix": 0,
    }

    for printed_bk in sorted(topics):
        topic = topics[printed_bk]
        printed_practice = printed_bk + 1
        img_path = f"{PAGES_DIR}/page-{printed_practice + PAGE_OFFSET:04d}.jpg"
        stats["practice_pages_attempted"] += 1
        try:
            questions, _ = extract_practice_page(img_path)
        except Exception as exc:  # noqa: BLE001
            stats["practice_pages_extract_failed"] += 1
            print(f"[warn] extract failed for {img_path}: {exc}", file=sys.stderr)
            continue

        for q in questions:
            stats["questions_total"] += 1
            marker = q.get("marker")
            needs_fix = marker is None
            verdict = ""
            explanation_parts = []
            if marker:
                stats["questions_matched"] += 1
                mark = marker["mark"]
                verdict = "✕" if mark in ("×", "✕", "☓") else "○"
                for n in marker["nums"]:
                    if n in topic["items"]:
                        explanation_parts.append(f"({n}) {topic['items'][n]}")
            else:
                stats["questions_needs_fix"] += 1

            # 🔴 extract_practice_page() は境界判定に使ったチェックボックス
            # 記号（口/□/■/ロ/コ/0/◎/o）を statement の先頭に残したまま返す
            # （境界シグナルとして使っただけで内容としては無意味なノイズ）。
            # 投入前に必ず除去する（除去し忘れると全カードの先頭に無意味な
            # 1文字が残る）。
            statement = q["statement"]
            if statement and statement[0] in "口□■ロコ0◎o":
                statement = statement[1:].lstrip()

            citation = q["citation"]
            tags = []
            if topic["bian_title"]:
                tags.append(f"編::{topic['bian_title']}")
            if topic["topic_title"]:
                tags.append(f"テーマ::{topic['topic_title']}")
            if citation:
                tags.append(f"出典:{citation}")
                ey = era_year_tag(citation)
                if ey:
                    tags.append(f"年度:{ey}")
            if needs_fix:
                tags.append("判定マーカー欠落")
                tags.append("_要手修正")

            knowledge_area = " / ".join(
                x for x in [
                    f"第{topic['bian_num']}編 {topic['bian_title']}" if topic["bian_num"] else "",
                    f"{topic['topic_num']}.{topic['topic_title']}" if topic["topic_num"] else "",
                ] if x
            )

            qas.append({
                "printed_bk_page": printed_bk,
                "printed_practice_page": printed_practice,
                "statement": statement,
                "citation": citation,
                "verdict": verdict,
                "needs_fix": needs_fix,
                "explanation": "<br><br>".join(explanation_parts),
                "knowledge_area": knowledge_area,
                "tags": tags,
            })

    return qas, stats, topics


def _to_qapairs(raw_qas: list[dict]) -> list[QAPair]:
    """build() の dict リストを QAPair に変換する。

    🔴 座標マッチング方式は○×型（見開き実践ページ）専用のため qtype="truefalse"
       固定。verdict は build() が既に "○"/"✕"/"" に正規化済み（toolkit 側の
       _normalize_verdict でも再度正規化されるため二重チェックは不要）。
    TODO: フィールド対応がソース固有の QAPair 構成に合わない場合はここを書き換える。
    """
    result: list[QAPair] = []
    for item in raw_qas:
        result.append(QAPair(
            front=item["statement"],
            back=item["explanation"],
            qtype="truefalse",
            verdict=item["verdict"],
            tags=item["tags"],
            knowledge_area=item["knowledge_area"],
            needs_fix=item["needs_fix"],
        ))
    return result


def main() -> None:
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("deck")
    ap.add_argument("model")
    args = ap.parse_args()

    raw_qas, stats, _topics = build()
    print(json.dumps(stats, ensure_ascii=False, indent=2), file=sys.stderr)
    qas = _to_qapairs(raw_qas)
    print(f"parsed: {len(qas)} cards", file=sys.stderr)

    # field_map はノートタイプに合わせる（Step5b で modelFieldNames 確認後に設定）
    #   例: 資格試験ノートタイプ → {"front":"Question","back":"Answer","extra":"Knowledge Area"}
    field_map = {"front": "Front", "back": "Back"}
    # render はノートタイプのJSテンプレに合わせる（Step5b で modelTemplates 確認後）
    render = RenderOptions()
    result = upload(qas, deck_name=args.deck, model_name=args.model,
                    field_map=field_map, render=render, skip_existing=True)
    print(result, file=sys.stderr)


if __name__ == "__main__":
    main()
