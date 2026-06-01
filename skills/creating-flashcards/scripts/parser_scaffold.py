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
