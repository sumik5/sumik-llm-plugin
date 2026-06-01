#!/usr/bin/env python3
"""parser_scaffold.py — 1ソース1コピーで使う使い捨てパーサー雛形。

使い方: 本ファイルを /tmp/parse-<descriptive-name>.py にコピーし、
parse() の TODO だけ埋める。投入インフラ(anki_toolkit)は書き換えない。

🔴 ジェネリック化禁止: parse() は今回のソース1冊専用に書くこと。
   過去のコピーを再利用せず、必ずソースを目視してから書く
   （同一シリーズ・同一級でも pandoc 後構造は変異する）。

🔴 共通ヘルパ（clean_pandoc 等）は「parse の素材」。毎回ソースに合わせて
   呼ぶ/呼ばない/regex を差し替える。これらを一括で呼ぶ統合関数
   （clean_all() 等）は作らない（ジェネリック化の温床になるため）。
"""

import os
import re
import sys
import unicodedata
from dataclasses import dataclass

# anki_toolkit を import（スキルの scripts ディレクトリを sys.path に追加）。
#   優先: CLAUDE_PLUGIN_ROOT 環境変数（/tmp 実行でも解決できる）。
#   フォールバック: <CLAUDE_PLUGIN_ROOT> プレースホルダ（コピー時に実パス置換する）。
_plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT", "<CLAUDE_PLUGIN_ROOT>")
sys.path.insert(0, f"{_plugin_root}/skills/creating-flashcards/scripts")
from anki_toolkit import QAPair, RenderOptions, upload, sample_cards   # noqa: E402,F401


# ソース固有のコンテキスト（画像付き EPUB 等で parse / extract_images に渡す）
@dataclass
class SourceContext:
    md_path: str                 # 変換後 Markdown のパス
    epub_path: str = ""          # 画像取り出し元の EPUB（画像なしソースは空）
    media_prefix: str = ""       # 🔴 Anki メディア衝突回避の接頭辞（例 "<prefix>_"）。
    #   epub_path が非空（=画像取り込みする）なら必須。
    #   空のまま画像投入すると汎用名が別[書名]と衝突し
    #   既存画像を上書きする（静かなデータ破壊）。


# ─────────────────────────────────────────────
# 共通前処理ヘルパ（“素材”。毎回ソースに合わせて呼ぶ/差し替える）
#   ※ これらを一括で呼ぶ統合関数は作らない（ジェネリック化防止）
# ─────────────────────────────────────────────


def clean_pandoc(text: str) -> str:
    """pandocアーティファクト除去。<pre>退避→inline span→CSS class→
    エスケープ→bare bracket の順（共通処理リファレンス準拠）。
    ※ソースにより不要なステップ・追加すべき regex があるので確認のうえ使う。
    """
    # 1. <pre> ブロックを退避（クラス除去 regex が中身を破壊しないように）
    pre_blocks: dict[str, str] = {}
    counter = [0]

    def _save_pre(m: "re.Match[str]") -> str:
        key = f"\x00PRE{counter[0]}\x00"
        pre_blocks[key] = m.group(0)
        counter[0] += 1
        return key

    text = re.sub(r"<pre[^>]*>.*?</pre>", _save_pre, text, flags=re.DOTALL)

    # 2. ページマーカー除去（空ブラケット + アンカーID）
    text = re.sub(r"\[\]\{#[^}]*\}", "", text)
    # 3. inline spans 除去（テキスト抽出）★ CSS class markers より先
    text = re.sub(r"\[([^\]]*)\]\{\.class_s[^}]*\}", r"\1", text)
    text = re.sub(r'\[([^\]]*)\]\{style="[^"]*"\}', r"\1", text)
    # 4. CSS class / style マーカー除去（残りの単独マーカー）
    text = re.sub(r"\{[.#][^}]*\}", "", text)
    text = re.sub(r'\{style="[^"]*"\}', "", text)
    # 5. エスケープ文字除去（複合 → 単純の順）
    text = text.replace(r"\--\>", "-->")
    text = text.replace(r"\>", ">")
    text = text.replace(r"\<", "<")
    text = text.replace(r"\~", "~")
    text = text.replace(r"\#", "#")
    text = text.replace(r"\*", "*")
    text = text.replace("\\'", "'")
    # 6. 絵文字付き矢印の正規化
    text = re.sub(r"[➡]️?", "→", text)
    # 7. 残存 bare bracket 除去（最終クリーンアップ）
    text = re.sub(r"\[([^\]\[]*)\]", r"\1", text)

    # 8. <pre> 復元
    for key, value in pre_blocks.items():
        text = text.replace(key, value)
    return text


def normalize_nfkc(text: str) -> str:
    """全角英数字・全角記号を NFKC 正規化（Front 用。タグ/デッキ名には使わない）。"""
    return unicodedata.normalize("NFKC", text)


def smart_join(lines: list[str]) -> str:
    """ソフトラップ結合。結合境界の左右が両方 ASCII 英数字のときだけ半角空白挿入。"""
    out = ""
    for ln in (line.strip() for line in lines):
        if not ln:
            continue
        if out and re.match(r"[A-Za-z0-9]", out[-1]) and re.match(r"[A-Za-z0-9]", ln[0]):
            out += " "   # 英単語境界のみスペース
        out += ln        # 日本語境界は区切りなし
    return out


def extract_page_number(block: str) -> str:
    r"""問題ブロック前後の ^\d{1,4}$ 行からページ番号を抽出（無ければ空文字）。"""
    for line in block.splitlines():
        m = re.match(r"^\s*(\d{1,4})\s*$", line)
        if m:
            return m.group(1)
    return ""


def find_section_markers(text: str, pattern: str) -> list[int]:
    """指定 regex でセクション境界の行番号リストを返す（grep 相当の補助）。"""
    rx = re.compile(pattern)
    return [i for i, line in enumerate(text.splitlines()) if rx.search(line)]


# ── OCR残存フォールバック用ヘルパ（“素材”。一括統合関数にはしない）──
#   位置づけ: recognize-image-to-markdown 経由のOCRなら、思考ログ除去・
#   反復崩壊検出・自動再OCRはコマンド側で一次対処済み。以下2関数は
#   ①コマンドをすり抜けた残存ケース ②コマンド未経由の他ツールOCR出力
#   向けの最終防衛線（フォールバック）。parse() が必要なときだけ呼ぶ。
#   閾値は消費側=3（コマンド=4）と意図的に非対称（最終防衛線なので厳しめ）。
#   🔴 CJK/カタカナ字形混同（エ↔工 等）の機械置換はここに入れない
#      （誤爆リスク。CONTENT-DETECTION.md L104 の機械置換フォールバックに残す）。

# OCRメタ専用行のアンカー（“思考ログ”行のみにマッチさせる）。
#   本文を巻き込まないよう、行頭定型句に限定する。
_THINK_ANCHORS = [
    r"^\s*\d*\.?\s*\*{0,2}(?:Analyze the Request|Scan the Image|Transcribe Section|"
    r"Final Formatting|Self-Correction|Mental Draft)",
    r"^The user wants the text",
    r"^\s*\*{0,2}Hypothesis\s*\d*\s*[:：]",
    r"^Let'?s look at (?:the|this) character",
    r"^Testing the hypothesis",
    r"^Confirming the reading",
    r"^(?:画像の(?:分析|文字)|いや、待て|よし、「.+?」|もう一度)",
    r"^(?:ユーザーは.+画像|これは.+問題だと|実際には.+(?:右から|左から)|画像を拡大して)",
]
_THINK_RE = [re.compile(p) for p in _THINK_ANCHORS]

# ○×単独行は判定マーカーの可能性が高いので保護する（思考ログ除去より先に判定）。
_OXMARK_ONLY_RE = re.compile(r"^\s*[○×✕〇◯❌☓OXＯＸ]\s*$")


def collapse_repeated_lines(text: str, max_repeat: int = 3) -> tuple[str, bool]:
    """同一行の連続反復（OCR無限ループ崩壊）を1回に畳む。

    位置づけ: コマンドが反復圧縮＋自動再OCRで一次対処済み。これはコマンド
    未経由ソース／残存崩壊ページ向けのフォールバック（最終防衛線）。

    正規化（``" ".join(line.split())`` で strip + 連続空白を単一空白化）した
    行が ``max_repeat`` 回以上連続したら 1 回に畳む。
    - デフォルト閾値 3（消費側は最終防衛線なので厳しめ。コマンド側=4 と非対称）。
    - 空行はカウント対象外（反復判定に含めず、そのまま保持）。
    - 検出した反復は破棄せず必ず 1 回残す（過剰除去を避ける）。

    戻り値: ``(畳んだ後のテキスト, 1箇所でも畳んだか)``。
    """
    lines = text.split("\n")
    out: list[str] = []
    collapsed = False
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        norm = " ".join(line.split())
        if norm == "":
            # 空行は反復判定の対象外。そのまま保持して次へ。
            out.append(line)
            i += 1
            continue
        # 同一正規化行の連続数を数える
        j = i + 1
        while j < n and " ".join(lines[j].split()) == norm:
            j += 1
        run_len = j - i
        if run_len >= max_repeat:
            out.append(line)   # 反復は破棄せず 1 回だけ残す
            collapsed = True
        else:
            out.extend(lines[i:j])
        i = j
    return "\n".join(out), collapsed


def strip_thinking_logs(text: str) -> str:
    """OCRメタ思考ログ専用行を除去する（除去のみ・スコア機構は持たない）。

    位置づけ: コマンドは思考ログ除去・自動再OCRで一次対処済み。これは
    コマンド未経由ソース／すり抜けた残存行向けのフォールバック（最終防衛線）。
    消費側は再OCRできないため、コマンド側 detect_thinking_contamination の
    「除去」部分だけを抜き出した版（再OCR判断用スコアは返さない）。

    - ``_THINK_ANCHORS`` にマッチするメタ専用行のみ除去する。
    - ``_OXMARK_ONLY_RE`` の○×単独行は保護する（先にチェックして必ず残す）。
    - 簡体字の機械削除はしない（本文巻き込み＝誤爆を避けるため）。

    本文（問題文・選択肢・解説）は触らない。除去対象は行頭定型句のみ。
    """
    out: list[str] = []
    for line in text.split("\n"):
        if _OXMARK_ONLY_RE.match(line):
            out.append(line)   # ○×単独行は判定マーカーとして保護
            continue
        if any(rx.search(line) for rx in _THINK_RE):
            continue            # メタ専用行は除去
        out.append(line)
    return "\n".join(out)


def extract_images(text: str, ctx: "SourceContext") -> tuple[str, list[dict]]:
    """本文中の画像参照を <img src="<ctx.media_prefix>..."> に置換し、
    ctx.epub_path から実体を base64 で取り出して [{"filename","data_b64"}] を返す。

    ※ 画像参照 regex・prefix 命名はソース固有。
      escape順序の罠（プレースホルダ退避）に注意。
    ctx.epub_path が空（画像なしソース）なら (text, []) をそのまま返す。
    🔴 ctx.epub_path が非空なのに ctx.media_prefix が空なら ValueError
       （汎用名衝突による既存画像の上書き＝静かなデータ破壊を防ぐ）。
    生成する filename は必ず ctx.media_prefix を前置する。
    戻り値の dict 群を QAPair.media に載せる。
    """
    if not ctx.epub_path:
        return text, []
    if not ctx.media_prefix:
        raise ValueError(
            "media_prefix is required when epub_path is set "
            "(generic filenames collide with other sources' Anki media)"
        )
    # TODO: ソース固有の実装
    #   1. !\[...\]\((image_rsrc\w+\.(?:jpg|png|gif))\) を検出し
    #      <img src="<ctx.media_prefix>\1" style="max-width:100%;"> に置換
    #      （escape する場合は ASCII プレースホルダに退避 → escape → 復元の3段階）
    #   2. unzip -o "<epub>" "*.jpg" 等で EPUB から画像を展開し base64 化
    #   3. [{"filename": "<ctx.media_prefix>image_rsrcXXX.jpg",
    #       "data_b64": "<base64>"}] を構築して返す
    media: list[dict] = []
    return text, media


# ─────────────────────────────────────────────
# 🔴 ここから下がソース固有。毎回手書きする
# ─────────────────────────────────────────────


def parse(markdown_text: str, ctx: "SourceContext") -> list[QAPair]:
    """このソース1冊専用の抽出ロジック。

    ctx は画像取り込み等で extract_images(text, ctx) に渡す。

    🔴 ジェネリック化禁止: 過去のコピーを再利用せず、必ずソースを目視してから書く。

    TODO:
      1. ソース構造（Step3で判定したパターン）に応じて問題ブロックを切り出す
      2. 画像付きソースは extract_images(block, ctx) で <img>化 + media 収集
      3. 各ブロックから front / choices / correct / verdict / 解説 を抽出
      4. QAPair（media 含む）を生成して返す
    """
    qas: list[QAPair] = []
    # TODO: 実装
    return qas


def main() -> None:
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("md_path")
    ap.add_argument("deck")
    ap.add_argument("model")
    ap.add_argument("--epub", default="", help="画像取り出し元 EPUB（画像付きソースのみ）")
    ap.add_argument("--media-prefix", default="", help="Anki メディア衝突回避の接頭辞")
    args = ap.parse_args()

    ctx = SourceContext(md_path=args.md_path, epub_path=args.epub,
                        media_prefix=args.media_prefix)
    with open(ctx.md_path, encoding="utf-8") as f:
        md = f.read()
    qas = parse(md, ctx)
    print(f"parsed: {len(qas)} cards", file=sys.stderr)
    # field_map はノートタイプに合わせる（Step5b で modelFieldNames 確認後に設定）
    #   例: 資格試験ノートタイプ → {"front":"Question","back":"Answer","extra":"Knowledge Area"}
    field_map = {"front": "Front", "back": "Back"}
    # render はノートタイプのJSテンプレに合わせる（Step5b で modelTemplates 確認後）
    #   <ol><li> シャッフルJSがあるなら choice_list_style="ol"、
    #   JSが <li> を倍増させるなら "br"。原文 details は常に <br>。
    render = RenderOptions()
    result = upload(qas, deck_name=args.deck, model_name=args.model,
                    field_map=field_map, render=render, skip_existing=True)
    print(result, file=sys.stderr)


if __name__ == "__main__":
    main()
