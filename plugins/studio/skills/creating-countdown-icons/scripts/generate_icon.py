"""
カウントダウンアプリ用アイコン画像ジェネレーター（512×512 PNG）

使用例:
  # 最終アイコン生成
  python3 generate_icon.py --text "知財検定" --palette I --emoji "💡" --out /tmp/icon.png

  # 絵文字候補グリッド生成
  python3 generate_icon.py --text "知財検定" --palette I --mode candidates \
      --candidates "💡,⚖️,📚,🎓" --out /tmp/candidates.png
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Optional

import numpy as np
from PIL import Image, ImageDraw, ImageFont

# ============================================================
# 定数・パレット定義
# ============================================================

ICON_SIZE = 512

PALETTES: dict[str, dict[str, str]] = {
    "I": {"bg": "#1B2A4A", "accent": "#E8B53C", "name": "濃紺×ゴールド"},
    "J": {"bg": "#2B2F33", "accent": "#36C5D6", "name": "チャコール×シアン"},
    "K": {"bg": "#10403B", "accent": "#EAD27A", "name": "深緑×淡ゴールド"},
    "L": {"bg": "#2E2A55", "accent": "#F0865A", "name": "インディゴ×コーラル"},
}

EMOJI_FONT_PATH = "/System/Library/Fonts/Apple Color Emoji.ttc"
EMOJI_FONT_SIZE = 160  # Apple Color Emoji はこのサイズのみ有効

CJK_FONT_CANDIDATES = [
    "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
    "/Library/Fonts/Arial Unicode.ttf",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
]

# アイコン配置パラメータ
ICON_TARGET_HEIGHT = 210   # リサイズ後の絵文字高さ [px]
ICON_TOP_Y = 120           # 絵文字の上端 Y 座標
TEXT_BASELINE_Y = 430      # テキストのベースライン Y 座標
TEXT_MAX_WIDTH = 430       # テキスト最大幅 [px]
TEXT_FONT_SIZE_MAX = 80    # テキストフォント最大サイズ
TEXT_FONT_SIZE_MIN = 28    # テキストフォント最小サイズ

# プレビュー用数字パラメータ
PREVIEW_NUMBER_FONT_SIZE = 190  # プレビュー数字のフォントサイズ（近似）


# ============================================================
# ユーティリティ
# ============================================================

def hex_to_rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    """#RRGGBB 形式の文字列を RGBA タプルに変換する。"""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return r, g, b, alpha


def lighten_color(hex_color: str, factor: float = 0.10) -> tuple[int, int, int]:
    """hex カラーを指定割合だけ明るくした RGB タプルを返す。"""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    r = min(255, int(r + (255 - r) * factor))
    g = min(255, int(g + (255 - g) * factor))
    b = min(255, int(b + (255 - b) * factor))
    return r, g, b


def load_cjk_font(size: int) -> ImageFont.FreeTypeFont:
    """CJK フォントを候補リストから順番にロードして返す。全て失敗したら SystemExit。"""
    for path in CJK_FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    print(
        "エラー: CJK フォントが見つかりません。\n"
        f"試行パス: {CJK_FONT_CANDIDATES}",
        file=sys.stderr,
    )
    sys.exit(1)


# ============================================================
# 背景生成
# ============================================================

def make_background(bg_hex: str) -> Image.Image:
    """
    512×512 RGBA 画像を生成する。
    bg_hex 色で塗りつぶした後、45°の斜めストライプ（bg を 10% 明るくした色）を重ねる。
    """
    size = ICON_SIZE
    # 背景色で初期化
    bg_rgba = hex_to_rgba(bg_hex)
    img_arr = np.full((size, size, 4), bg_rgba, dtype=np.uint8)

    # ストライプ色（bg を 10% 明るく）
    stripe_rgb = lighten_color(bg_hex, factor=0.10)
    stripe_rgba = (*stripe_rgb, 255)

    stripe_width = size // 14  # 約36px 幅

    # 各ピクセルの (x + y) で 45° 縞を決定（numpy ベクトル演算）
    y_idx, x_idx = np.mgrid[0:size, 0:size]
    stripe_mask = ((x_idx + y_idx) // stripe_width) % 2 == 0
    img_arr[stripe_mask] = stripe_rgba

    return Image.fromarray(img_arr, mode="RGBA")


# ============================================================
# 絵文字アイコン生成
# ============================================================

def render_emoji(emoji: str, accent_hex: str, style: str) -> Image.Image:
    """
    絵文字を ICON_TARGET_HEIGHT px の高さになるようレンダリングして返す。

    style:
      "silhouette" — アクセント色の単色シルエット
      "color"      — カラー絵文字そのまま
    """
    if not os.path.exists(EMOJI_FONT_PATH):
        print(
            f"エラー: Apple Color Emoji フォントが見つかりません: {EMOJI_FONT_PATH}\n"
            "macOS 環境が必要です。",
            file=sys.stderr,
        )
        sys.exit(1)

    font = ImageFont.truetype(EMOJI_FONT_PATH, EMOJI_FONT_SIZE, index=0)

    # 一時キャンバスに描画して bbox を確認
    tmp_size = EMOJI_FONT_SIZE * 2
    tmp = Image.new("RGBA", (tmp_size, tmp_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(tmp)
    draw.text((tmp_size // 4, tmp_size // 4), emoji, font=font, embedded_color=True)

    # α チャンネルから実際の描画領域を取得
    alpha = tmp.split()[3]
    bbox = alpha.getbbox()
    if bbox is None:
        print(
            f"エラー: 絵文字 '{emoji}' のグリフが描画されませんでした。\n"
            "フォントがこの絵文字をサポートしていない可能性があります。",
            file=sys.stderr,
        )
        sys.exit(1)

    # 実描画領域でクロップ
    emoji_img = tmp.crop(bbox)

    # ICON_TARGET_HEIGHT に比例リサイズ
    orig_w, orig_h = emoji_img.size
    scale = ICON_TARGET_HEIGHT / orig_h
    new_w = int(orig_w * scale)
    new_h = ICON_TARGET_HEIGHT
    emoji_img = emoji_img.resize((new_w, new_h), Image.LANCZOS)

    # スタイル適用
    if style == "silhouette":
        accent_rgb = hex_to_rgba(accent_hex)[:3]
        silhouette = Image.new("RGBA", emoji_img.size, (0, 0, 0, 0))
        # α をマスクとしてアクセント色で塗りつぶし
        color_layer = Image.new("RGBA", emoji_img.size, (*accent_rgb, 255))
        silhouette = Image.composite(color_layer, silhouette, emoji_img.split()[3])
        return silhouette
    else:
        # color: そのまま返す
        return emoji_img


def _render_emoji_label(emoji: str, label_size: int = 52) -> Image.Image:
    """
    candidates グリッドのセルラベル用にカラー絵文字を小さくレンダリングして返す。

    CJK / デフォルトフォントは絵文字グリフを持たず豆腐化するため、
    Apple Color Emoji（size=160 固定）で描画後に label_size px へリサイズする。
    bbox が取得できない場合は透明な正方形を返す（フォールバック）。
    """
    if not os.path.exists(EMOJI_FONT_PATH):
        # フォント不在時は透明フォールバック
        return Image.new("RGBA", (label_size, label_size), (0, 0, 0, 0))

    font = ImageFont.truetype(EMOJI_FONT_PATH, EMOJI_FONT_SIZE, index=0)
    tmp_size = EMOJI_FONT_SIZE * 2
    tmp = Image.new("RGBA", (tmp_size, tmp_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(tmp)
    draw.text((tmp_size // 4, tmp_size // 4), emoji, font=font, embedded_color=True)

    alpha = tmp.split()[3]
    bbox = alpha.getbbox()
    if bbox is None:
        return Image.new("RGBA", (label_size, label_size), (0, 0, 0, 0))

    cropped = tmp.crop(bbox)
    # 正方形に収まるよう比例リサイズ
    orig_w, orig_h = cropped.size
    scale = label_size / max(orig_w, orig_h)
    new_w = int(orig_w * scale)
    new_h = int(orig_h * scale)
    return cropped.resize((new_w, new_h), Image.LANCZOS)


# ============================================================
# テキスト描画
# ============================================================

def draw_text_centered(
    canvas: Image.Image,
    text: str,
    accent_hex: str,
    baseline_y: int,
    max_width: int,
) -> None:
    """
    canvas にアクセント色でテキストを水平中央・ベースライン y 位置に描画する。
    max_width に収まるようフォントサイズを自動調整する。
    """
    accent_rgba = hex_to_rgba(accent_hex)
    draw = ImageDraw.Draw(canvas)

    font_size = TEXT_FONT_SIZE_MAX
    font: Optional[ImageFont.FreeTypeFont] = None
    text_bbox: tuple[int, int, int, int] = (0, 0, 0, 0)

    while font_size >= TEXT_FONT_SIZE_MIN:
        font = load_cjk_font(font_size)
        text_bbox = draw.textbbox((0, 0), text, font=font)
        text_width = text_bbox[2] - text_bbox[0]
        if text_width <= max_width:
            break
        font_size -= 2

    if font is None:
        font = load_cjk_font(TEXT_FONT_SIZE_MIN)
        text_bbox = draw.textbbox((0, 0), text, font=font)

    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]

    x = (ICON_SIZE - text_width) // 2 - text_bbox[0]
    y = baseline_y - text_height - text_bbox[1]

    draw.text((x, y), text, font=font, fill=accent_rgba)


# ============================================================
# アイコン合成
# ============================================================

def compose_icon(
    text: str,
    palette_key: str,
    emoji: str,
    icon_style: str,
) -> Image.Image:
    """
    背景 + 絵文字アイコン + テキストを合成した 512×512 RGBA 画像を返す。
    """
    palette = PALETTES[palette_key]
    bg_hex = palette["bg"]
    accent_hex = palette["accent"]

    # 背景生成
    canvas = make_background(bg_hex)

    # 絵文字アイコン生成・配置
    emoji_img = render_emoji(emoji, accent_hex, icon_style)
    icon_w = emoji_img.size[0]
    icon_x = (ICON_SIZE - icon_w) // 2
    icon_y = ICON_TOP_Y
    canvas.paste(emoji_img, (icon_x, icon_y), emoji_img.split()[3])

    # テキスト描画
    draw_text_centered(canvas, text, accent_hex, TEXT_BASELINE_Y, TEXT_MAX_WIDTH)

    return canvas


# ============================================================
# プレビュー生成
# ============================================================

def make_preview(icon: Image.Image, number: int, out_path: str) -> None:
    """
    アイコンのコピーに白い数字を重ねたプレビュー画像を保存する。
    保存先は out_path のステムに '_preview.png' を付与したパス。
    """
    preview = icon.copy()
    draw = ImageDraw.Draw(preview)

    number_str = str(number)

    # Helvetica Bold 相当のフォントを試みる（macOS のシステムフォントから）
    helvetica_candidates = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
    ]
    num_font: Optional[ImageFont.FreeTypeFont] = None
    for path in helvetica_candidates:
        if os.path.exists(path):
            num_font = ImageFont.truetype(path, PREVIEW_NUMBER_FONT_SIZE)
            break

    if num_font is None:
        # フォールバック: PIL デフォルトフォント（サイズ指定不可）
        num_font = ImageFont.load_default()

    # 中央に白い数字を配置
    text_bbox = draw.textbbox((0, 0), number_str, font=num_font)
    text_w = text_bbox[2] - text_bbox[0]
    text_h = text_bbox[3] - text_bbox[1]
    x = (ICON_SIZE - text_w) // 2 - text_bbox[0]
    y = (ICON_SIZE - text_h) // 2 - text_bbox[1]
    draw.text((x, y), number_str, font=num_font, fill=(255, 255, 255, 255))

    # 保存先パスの組み立て
    stem, _ = os.path.splitext(out_path)
    preview_path = f"{stem}_preview.png"
    preview.save(preview_path, format="PNG")
    print(f"プレビュー保存: {preview_path}")


# ============================================================
# candidates モード（2×2 グリッド）
# ============================================================

def make_candidates_grid(
    text: str,
    palette_key: str,
    candidates: list[str],
    out_path: str,
) -> None:
    """
    4つの絵文字候補を 2×2 グリッドに並べた画像を生成・保存する。
    各セルはシルエットスタイルで構成し、絵文字ラベルを下部に付与する。
    """
    if len(candidates) != 4:
        print(
            f"エラー: --candidates には正確に4つの絵文字をカンマ区切りで指定してください。"
            f"(受け取った数: {len(candidates)})",
            file=sys.stderr,
        )
        sys.exit(1)

    palette = PALETTES[palette_key]
    accent_hex = palette["accent"]
    cell_size = ICON_SIZE  # 各セルは 512×512

    # 2×2 グリッド用キャンバス（1024×1024）
    grid = Image.new("RGBA", (cell_size * 2, cell_size * 2), (0, 0, 0, 255))

    for idx, emoji in enumerate(candidates):
        col = idx % 2
        row = idx // 2
        cell_img = compose_icon(text, palette_key, emoji.strip(), "silhouette")

        # セル左上隅にカラー絵文字ラベルを貼り付ける。
        # CJK フォントは絵文字グリフを持たないため豆腐化する。
        # Apple Color Emoji（size=160 固定）でレンダリング後、小さくリサイズして配置する。
        label_emoji_img = _render_emoji_label(emoji.strip(), label_size=52)
        cell_img.paste(label_emoji_img, (10, 10), label_emoji_img.split()[3])

        grid.paste(cell_img, (col * cell_size, row * cell_size))

    grid.save(out_path, format="PNG")
    print(f"候補グリッド保存: {out_path}  ({grid.size[0]}×{grid.size[1]} px)")


# ============================================================
# CLI エントリポイント
# ============================================================

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="カウントダウンアプリ用アイコン（512×512 PNG）を生成する",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--text", required=True, help="アイコンに表示する日本語/英数字テキスト")
    parser.add_argument(
        "--palette",
        required=True,
        choices=list(PALETTES.keys()),
        help="カラーパレット: I=濃紺×ゴールド / J=チャコール×シアン / K=深緑×淡ゴールド / L=インディゴ×コーラル",
    )
    parser.add_argument("--out", required=True, help="出力先 PNG ファイルパス")
    parser.add_argument("--emoji", default=None, help="絵文字 (--mode final 時必須)")
    parser.add_argument(
        "--mode",
        default="final",
        choices=["final", "candidates"],
        help="final: 単一アイコン生成 / candidates: 4絵文字の候補グリッド生成",
    )
    parser.add_argument(
        "--candidates",
        default=None,
        help="カンマ区切りの4絵文字 (--mode candidates 時必須)",
    )
    parser.add_argument(
        "--icon-style",
        default="silhouette",
        choices=["silhouette", "color"],
        help="silhouette: アクセント色シルエット / color: カラー絵文字そのまま",
    )
    parser.add_argument(
        "--preview-number",
        type=int,
        default=30,
        help="プレビュー画像に重ねる数字 (--mode final 時のみ有効, デフォルト: 30)",
    )
    return parser.parse_args()


def validate_args(args: argparse.Namespace) -> None:
    """引数の相関バリデーション。問題があれば sys.exit(1)。"""
    if args.mode == "final" and args.emoji is None:
        print(
            "エラー: --mode final のときは --emoji が必須です。",
            file=sys.stderr,
        )
        sys.exit(1)

    if args.mode == "candidates" and args.candidates is None:
        print(
            "エラー: --mode candidates のときは --candidates が必須です。",
            file=sys.stderr,
        )
        sys.exit(1)

    if args.mode == "candidates" and args.candidates is not None:
        items = [e.strip() for e in args.candidates.split(",") if e.strip()]
        if len(items) != 4:
            print(
                f"エラー: --candidates にはカンマ区切りで正確に4つの絵文字を指定してください。"
                f"(受け取った数: {len(items)})",
                file=sys.stderr,
            )
            sys.exit(1)

    # 出力先ディレクトリの存在確認
    out_dir = os.path.dirname(os.path.abspath(args.out))
    if not os.path.isdir(out_dir):
        print(
            f"エラー: 出力先ディレクトリが存在しません: {out_dir}",
            file=sys.stderr,
        )
        sys.exit(1)


def main() -> None:
    args = parse_args()
    validate_args(args)

    print(
        f"パレット: {args.palette} ({PALETTES[args.palette]['name']})  "
        f"モード: {args.mode}  テキスト: {args.text}"
    )

    if args.mode == "candidates":
        candidates = [e.strip() for e in args.candidates.split(",") if e.strip()]
        make_candidates_grid(args.text, args.palette, candidates, args.out)
        return

    # final モード
    icon = compose_icon(args.text, args.palette, args.emoji, args.icon_style)
    icon.save(args.out, format="PNG")
    w, h = icon.size
    file_size = os.path.getsize(args.out)
    print(f"アイコン保存: {args.out}  ({w}×{h} px, {file_size:,} bytes)")

    make_preview(icon, args.preview_number, args.out)


if __name__ == "__main__":
    main()
