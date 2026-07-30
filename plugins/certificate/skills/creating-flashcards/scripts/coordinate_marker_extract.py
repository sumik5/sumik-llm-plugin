#!/usr/bin/env python3
"""coordinate_marker_extract.py — 座標マッチング方式のOCR抽出エンジン（不変・育てる側）。

見開き型レイアウト（本文列＝チェックボックス付き設問、マージン列＝座標分離された
○×判定マーカー）を持つ資格試験対策書籍向けの、Apple Vision (ocrmac) 生出力を
用いた座標マッチング抽出エンジン。

pandoc/OCR→フラット化Markdown→テキストパース方式では、判定マーカーが本文と
別カラム・別領域に配置されているためテキストの並び順だけでは本文に紐付け
不能になるケースがある。本エンジンはページ画像を直接 ocrmac で座標付きOCR
し、x座標で本文列（question column）とマージン列（margin column）に分割した
上で、y座標最近傍マッチングにより判定マーカーを対応する設問に紐付ける。

🔴 本ファイルは特定書籍に依らず再利用可能な「不変・育てる側」インフラである
   （`parser_scaffold.py` のような「雛形・コピーして使う側」ではない）。
   ページペアリング・書籍固有の見出しキーワード判定・出典表記の正規化等、
   ソース固有のロジックは `coordinate_page_scaffold.py` 側に置く。

`col_split_x`（本文列/マージン列のx境界。既定0.72）・`y_tol`（y座標マッチング
の許容誤差。既定0.025）は書籍のレイアウトに応じて呼び出し側が調整する引数。

🔴 契約: 各 `questions` 要素の `statement` は、新設問境界の判定に使った
   チェックボックス記号（口/□/■/ロ/コ/0/◎/o）を**先頭に残したまま**返す
   （境界シグナルとして使うだけで意味的な内容ではない）。呼び出し側
   （`coordinate_page_scaffold.py` 等）が投入前に必ず1文字除去すること。

外部依存: `ocrmac`, `Pillow`（PIL）。標準ライブラリ以外に依存するため、
`anki_toolkit.py`（外部依存ゼロ）とは前提が異なる。Python 3.10+ 想定。

以下のコード中の🔴コメントは、この座標マッチング方式をプロトタイプする過程で
発見した非自明なOCR特性・罠を記録した一次情報である。要約・削除せず維持する
こと（同種のレイアウトを持つ別書籍で再度踏む可能性が高い）。
"""
import re
import sys
from ocrmac import ocrmac
from PIL import Image

_CIRCLED = "①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳"
_CIRCLED_MAP = {ch: i + 1 for i, ch in enumerate(_CIRCLED)}
# 🔴 A THIRD reference-number tier exists: a circled-LETTER sub-index (e.g.
# "（4）③Ⓒ答×", confirmed on a real page) used alongside the "（N）" group
# index and circled-digit sub-index. Apple Vision never actually returns the
# true Unicode circled-letter glyph (Ⓐ Ⓑ Ⓒ...) though — it substitutes a
# VISUALLY similar symbol instead, and which one is itself inconsistent
# across upscale passes for the SAME source glyph: "◎"(U+25CE) at 1x/2x,
# "©"(U+00A9 copyright sign) at 3x. Both are self-delimiting like the circled
# digits (no brackets). _to_int() has no mapping for either so they resolve
# to None same as any unmapped token — fine, since this tier is never used
# for explanation lookup here, only for NOT breaking the regex chain before
# the real ○/×.
_CIRCLED_LETTER_SUBS = "◎©"
_NUM_TOKEN = r'(?:\d+|[' + _CIRCLED + _CIRCLED_LETTER_SUBS + '])'
# 🔴 OCR drops brackets around a reference number unpredictably: the OPENING
# paren on 2nd+ refs ("（2）3）答〇"), the CLOSING paren right before 答 in
# compound markers ("（2）（3答〇"), or the token appears with NO brackets at
# all when it's a self-delimiting circled digit ("①"). But circled digits
# ALSO show up WRAPPED in full parens elsewhere ("（⑧）" — confirmed on a
# real page), so bracket presence and token type (plain digit / circled
# digit / circled-letter-substitute) vary independently — treat brackets as
# fully optional around ANY token type rather than modeling them as two
# separate shapes.
_NUM_GROUP = r'(?:[（(]?\s*' + _NUM_TOKEN + r'\s*[）)]?)'

# 🔴 「答」(kanji "answer", immediately before the ○/× mark) is itself
# sometimes misread as the visually similar 「容」 (confirmed on a real
# page: "は（9）容✕"). Accept either so the optional-答 slot doesn't leave a
# stray 容 sitting between the number and the mark, breaking the match.
MARKER_RE = re.compile(r'(?:' + _NUM_GROUP + r'\s*)+\s*(?:[答容]\s*)?([○×✕〇◯])')
NUMS_RE = re.compile(r'[（(]?\s*(?:(?P<digit>\d+)|(?P<circ>[' + _CIRCLED + _CIRCLED_LETTER_SUBS + r']))\s*[）)]?')
CITATION_RE = re.compile(r'[［\[「]([^］\]」]{1,20})[］\]」]')


def _extract_nums(s):
    return [m.group('digit') or m.group('circ') for m in NUMS_RE.finditer(s)]


def _to_int(tok):
    return _CIRCLED_MAP.get(tok, None) or (int(tok) if tok.isdigit() else None)


def smart_join(strs):
    out = ""
    for s in strs:
        s = s.strip()
        if not s:
            continue
        if out and re.match(r"[A-Za-z0-9]", out[-1]) and re.match(r"[A-Za-z0-9]", s[0]):
            out += " "
        out += s
    return out


def _ocr_main_column_at_scale(image_path, col_split_x, scale):
    """Re-OCR just the main (question-text) column, cropped and upscaled by
    `scale`, as ONE self-consistent pass (do not mix with other passes: line
    segmentation differs across resolutions, so merging line lists from
    different scales corrupts question boundaries — confirmed by an earlier,
    reverted attempt that produced duplicated/fragmented questions). Each
    scale's result must be parsed independently via `_build_questions` and the
    least-truncated candidate picked, never concatenated.
    """
    im = Image.open(str(image_path))
    w, h = im.size
    base = im.crop((0, 0, int((col_split_x + 0.02) * w), h))
    crop = base.resize((base.width * scale, base.height * scale), Image.LANCZOS)
    return ocrmac.OCR(crop, language_preference=["ja-JP", "en-US"],
                       recognition_level="accurate").recognize()


def _ocr_margin_column(image_path, col_split_x):
    """Re-OCR just the margin column as its own cropped+upscaled image(s).

    🔴 Apple Vision's single full-page pass silently DROPS some margin marker
    text blocks entirely (not misread — just never returned as a region at
    all), even though the text is legible in the source image at normal zoom.
    Cropping the margin strip alone and upscaling before OCR recovers most of
    these, but which upscale factor recovers which specific miss is itself
    inconsistent (empirically: one page's missing marker only appeared at 3x,
    not 2x or 4x — and another compound "（2）（3答〇"-style marker was read
    CORRECTLY only at 1x/no-upscale, while both 2x and 3x garbled it worse).
    Running 1x (crop only), 2x, and 3x and taking the union catches more
    misses than any single one; duplicates near the same y are harmless (each
    question only consumes its single nearest unused marker downstream).
    Only x is cropped (height untouched), so returned y fractions stay
    directly comparable to the full-page main_col y values.
    """
    im = Image.open(str(image_path))
    w, h = im.size
    base = im.crop((int((col_split_x - 0.04) * w), 0, w, h))
    results = []
    for scale in (1, 2, 3):
        crop = base if scale == 1 else base.resize(
            (base.width * scale, base.height * scale), Image.LANCZOS)
        results.extend(
            ocrmac.OCR(crop, language_preference=["ja-JP", "en-US"],
                       recognition_level="accurate").recognize()
        )
    return results


FOOTER_RE = re.compile(r'^[・･.]?\s*\d{1,4}\s*[・･.]?$')
HEADER_JUNK_RE = re.compile(r'^(?:月\s*日|学習日|正答数|/\s*\d+|DATE\s*&\s*RECORD)$')


def _is_citation_like(inner):
    inner = inner.strip()
    return bool(re.match(r'^[HSRT]\s*\d', inner)) or inner.startswith("予想")


def _build_questions(main_col):
    """Parse a sorted (descending-y) list of (text, conf, (x,y,w,h)) main-column
    OCR regions into question blocks (checkbox-glyph-delimited, with inline
    marker detection, citation extraction, and trailing-debris cleanup).
    Factored out of extract_practice_page so it can be re-run against an
    enriched main_col after a truncation-triggered re-OCR retry.
    """
    # 🔴 checkbox glyph (□) before each question is misread inconsistently by
    # Apple Vision: 口(kanji U+53E3, dominant)/■(U+25A0)/ロ(katakana U+30ED)/
    # コ(katakana U+30B3) all observed on this book. But イ/ロ/ハ (and similarly
    # コ) are ALSO a standard generic-label idiom in Japanese legal statements
    # ("発明イに関連する発明ロ" = "invention A related to invention B"), so a
    # wrapped continuation line can legitimately start with "ロ"/"コ" as real
    # content, not a checkbox. Text alone can't disambiguate — but checkbox
    # lines sit at a distinctly shallower left-margin x than any continuation
    # line (~0.127 vs ~0.16+ on this book), so require x to be near the
    # page's own minimum checkbox-candidate x (self-calibrating: works for
    # both the full-page pass and a rescaled cropped-column retry pass, since
    # each has its own coordinate system).
    # 🔴 Rarer checkbox misreads (0/◎/o) were originally left out for fear of
    # false-positiving on ordinary body text, but the x-position guard below
    # already rejects any match that isn't at the page's own calibrated left
    # margin — so widening this class no longer risks false splits, only
    # helps recover genuine checkbox lines (confirmed: "0 日本国内に住所..."
    # was a real question whose checkbox OCR'd as digit zero, silently
    # merging it into the previous question and truncating BOTH — the
    # previous statement's real citation got buried mid-string too).
    glyph_re = re.compile(r'^[口□■ロコ0◎o]')
    candidate_xs = [x for text, conf, (x, y, w, h) in main_col
                     if glyph_re.match(text.strip())]
    margin_x = min(candidate_xs) if candidate_xs else None

    questions = []
    current = None
    for text, conf, (x, y, w, h) in main_col:
        stripped = text.strip()
        if not stripped:
            continue
        if FOOTER_RE.match(stripped) or HEADER_JUNK_RE.match(stripped):
            continue  # page-number footer / date-record header table debris
        # 🔴 FOOTER_RE assumes the page-number footer OCRs as actual digits
        # ("・111・"), but it sometimes reads as pure noise instead
        # ("・_-_・") that doesn't match any digit pattern. Undetected, this
        # gets appended as a stray "continuation line" onto whatever question
        # is current, dragging its end_y down to the footer's y (~0.045) and
        # breaking every y-proximity marker match for that question. No real
        # question content ever sits this close to the bottom edge (confirmed
        # across this book's page layout), so any SHORT line down there is
        # footer debris regardless of what it OCRs as.
        if y < 0.055 and len(stripped) <= 6:
            continue
        is_new_q = bool(glyph_re.match(stripped)) and (
            margin_x is None or x <= margin_x + 0.02
        )
        # check trailing inline marker (merged by Vision's own line grouping)
        inline_marker = None
        m = MARKER_RE.search(stripped)
        if m and m.end() >= len(stripped) - 2:  # marker near end of the line
            inline_marker = {
                "nums": [_to_int(n) for n in _extract_nums(stripped[m.start():m.end()])],
                "mark": m.group(1),
                "y": y,
                "raw": stripped[m.start():m.end()],
                "inline": True,
            }
            stripped = stripped[:m.start()].rstrip()

        if is_new_q:
            if current:
                questions.append(current)
            current = {"lines": [stripped], "ys": [y]}
        elif current is not None:
            current["lines"].append(stripped)
            current["ys"].append(y)
        else:
            # text before first checkbox (header noise) - ignore
            pass

        if inline_marker and current is not None:
            current["inline_marker"] = inline_marker

    if current:
        questions.append(current)

    for q in questions:
        q["end_y"] = min(q["ys"])
        q["raw_text"] = smart_join(q["lines"])
        # Pick the LAST citation-shaped bracket (real citation sits at the very
        # end of the statement); other brackets in the body (e.g. product-name
        # examples like ［菓子］ in trademark hypotheticals) are left in place.
        citation, span = "", None
        for mm in reversed(list(CITATION_RE.finditer(q["raw_text"]))):
            if _is_citation_like(mm.group(1)):
                citation, span = mm.group(1).strip(), mm.span()
                break
        # 🔴 Fallback for a citation bracket whose CLOSING ］ itself got
        # OCR-mangled (confirmed: "［H26-49］" read as "［H26-491", the ］
        # misread as "1") — CITATION_RE requires a real closing bracket so it
        # never matches at all in that case. If nothing matched above, check
        # for a bare opening bracket + citation-like content running to the
        # very end of the text (no closing bracket anywhere after it).
        if span is None:
            mm = re.search(r'[［\[「]([^］\]」]{1,20})$', q["raw_text"])
            if mm and _is_citation_like(mm.group(1)):
                citation, span = mm.group(1).strip(), (mm.start(), len(q["raw_text"]))
        if span:
            q["statement"] = (q["raw_text"][:span[0]] + q["raw_text"][span[1]:]).strip()
        else:
            q["statement"] = q["raw_text"]
        # trailing glyph debris from a misread ☞ pointer icon that wasn't
        # captured by the inline-marker split (e.g. a stray "は"/"5" after the
        # final 。). Statements are declarative sentences that should end
        # right at the closing 。, so a short (<=3 char) remainder after the
        # last 。 is very likely OCR debris, not real content.
        stm = q["statement"]
        last_period = stm.rfind("。")
        if last_period != -1 and 0 < len(stm) - (last_period + 1) <= 3:
            stm = stm[: last_period + 1]
        q["statement"] = stm
        q["citation"] = citation.replace("予想間", "予想問")

    return questions


def extract_practice_page(image_path, col_split_x=0.72, y_tol=0.025):
    res = ocrmac.OCR(str(image_path), language_preference=["ja-JP", "en-US"],
                      recognition_level="accurate").recognize()

    main_col = sorted([r for r in res if r[2][0] < col_split_x], key=lambda r: -r[2][1])
    margin_col = sorted(_ocr_margin_column(image_path, col_split_x), key=lambda r: -r[2][1])

    questions = _build_questions(main_col)

    # 🔴 Vision's single full-page pass can drop an entire mid-question
    # continuation line (not just margin markers) — a statement that never
    # reaches its closing 。 is the tell. Retry ONLY affected pages with a
    # cropped+upscaled re-OCR of the main column, add any genuinely-new lines
    # (exact-text dedup against the original pass) and re-parse.
    def _n_truncated(qs):
        return sum(1 for q in qs if not q["statement"].rstrip().endswith("。"))

    best, best_trunc = questions, _n_truncated(questions)
    if best_trunc:
        for scale in (2, 3):
            alt_col = sorted(_ocr_main_column_at_scale(image_path, col_split_x, scale),
                              key=lambda r: -r[2][1])
            alt_col = [r for r in alt_col if r[2][0] < col_split_x]
            alt_questions = _build_questions(alt_col)
            alt_trunc = _n_truncated(alt_questions)
            if alt_trunc < best_trunc:
                best, best_trunc = alt_questions, alt_trunc
            if best_trunc == 0:
                break
    questions = best

    # margin markers (separate blocks)
    margin_markers = []
    for text, conf, (x, y, w, h) in margin_col:
        stripped = text.strip()
        m = MARKER_RE.search(stripped)
        if m:
            margin_markers.append({
                "nums": [_to_int(n) for n in _extract_nums(stripped)],
                "mark": m.group(1),
                "y": y,
                "raw": stripped,
                "inline": False,
            })

    used = set()
    for q in questions:
        if q.get("inline_marker"):
            q["marker"] = q["inline_marker"]
            continue
        best_i, best_dist = None, None
        for i, mk in enumerate(margin_markers):
            if i in used:
                continue
            dist = abs(mk["y"] - q["end_y"])
            if best_dist is None or dist < best_dist:
                best_dist, best_i = dist, i
        if best_i is not None and best_dist <= y_tol:
            q["marker"] = margin_markers[best_i]
            used.add(best_i)
        else:
            q["marker"] = None

    return questions, margin_markers


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser(
        description="座標マッチング方式で見開き型ページ画像から設問と○×判定マーカーを抽出する（動作確認用CLI）。"
    )
    ap.add_argument("image_path", help="OCR対象のページ画像ファイルパス（例: /path/to/page-0059.jpg）")
    ap.add_argument("--col-split-x", type=float, default=0.72,
                     help="本文列/マージン列のx境界（既定0.72）")
    ap.add_argument("--y-tol", type=float, default=0.025,
                     help="y座標マッチングの許容誤差（既定0.025）")
    args = ap.parse_args()

    qs, markers = extract_practice_page(
        args.image_path, col_split_x=args.col_split_x, y_tol=args.y_tol
    )
    print(f"=== {args.image_path} ===")
    print(f"questions found: {len(qs)}, margin markers found: {len(markers)}")
    for i, q in enumerate(qs, 1):
        mk = q["marker"]
        mk_str = f"nums={mk['nums']} mark={mk['mark']} inline={mk.get('inline')}" if mk else "MISSING"
        print(f"--- Q{i} ---")
        print("statement:", q["statement"][:80])
        print("citation:", q["citation"])
        print("marker:", mk_str)
