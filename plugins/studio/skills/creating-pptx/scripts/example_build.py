"""
example_build.py
pptx_kit.DualSlide の動作確認用サンプルスクリプト。

実行方法:
    uv run --with python-pptx --with pillow python skills/creating-pptx/scripts/example_build.py

出力先: /tmp/creating-pptx-sample/
    sample.pptx  — 編集可能な PowerPoint ファイル
    sample.png   — 確認用プレビュー画像（2000×1125 px）

生成されるスライドのレイアウト:
    - ヘッドメッセージ（結論一文・強調あり）
    - 上半分: 業績サマリー表（4列、ヘッダー + 3行）
    - 下半分: 部門別売上横棒グラフ（5系列、ハイライト 1本）
    - セクション区切りの水平線
    - 丸数字バッジ × 2
    - 出典脚注
"""
import sys
from pathlib import Path

# scripts ディレクトリをモジュール検索パスに追加
sys.path.insert(0, str(Path(__file__).parent))

from pptx_kit import (
    DualSlide,
    BLUE, VERMIL, INK, SUB, LINE, WHITE,
    SLIDE_W_IN,
)

OUT_DIR  = Path("/tmp/creating-pptx-sample")
PPTX_OUT = str(OUT_DIR / "sample.pptx")
PNG_OUT  = str(OUT_DIR / "sample.png")


def build_sample() -> None:
    ds = DualSlide(preview_scale=150)

    # ヘッドメッセージ（結論一文。「コスト削減」を強調）
    ds.head_message(
        "オペレーションの見直しによりコスト削減余地は年間 3 億円と試算",
        emphasis="コスト削減余地は年間 3 億円",
    )

    # ---- 上半分: 業績サマリー表 ----
    m = 0.55
    section_y = 1.25

    # セクション見出し（バッジ中心 x≈0.71、テキスト開始 x=1.05 でクリアランス確保）
    ds.badge(m + 0.16, section_y + 0.17, 1)   # バッジ ①
    ds.text(
        1.05, section_y, 5.05, 0.35,
        [("業績サマリー", {"size": 13.0, "bold": True, "color": BLUE})],
        size=13.0,
    )

    table_y = section_y + 0.42
    ds.table(
        x=m, y=table_y, w=5.8,
        rows=[
            ["項目",          "前期",    "今期",    "増減"],
            ["売上高（億円）",  "142.3",  "158.7",  "+16.4"],
            ["営業利益（億円）", "18.1",   "21.4",   "+3.3"],
            ["営業利益率",      "12.7%",  "13.5%",  "+0.8pp"],
        ],
        col_widths=[3.2, 1.5, 1.5, 1.5],
        header=True,
        right_cols={1, 2, 3},
    )

    # ---- 下半分: 部門別横棒グラフ ----
    bar_section_y = table_y + 0.36 * 4 + 0.35
    ds.badge(m + 0.16, bar_section_y + 0.17, 2)   # バッジ ②
    ds.text(
        1.05, bar_section_y, 5.05, 0.35,
        [("部門別売上（今期・億円）", {"size": 13.0, "bold": True, "color": BLUE})],
        size=13.0,
    )

    ds.bar(
        x=m, y=bar_section_y + 0.42, w=5.8, h=2.5,
        data=[
            ("プロダクト事業",  72.3),
            ("サービス事業",    44.1),
            ("コンサルティング", 28.6),
            ("海外",           11.2),
            ("その他",          2.5),
        ],
        highlight=0,
        unit="億",
    )

    # ---- 右側: 100% 積み上げ & コメント ----
    right_x = m + 6.3
    right_w = SLIDE_W_IN - right_x - m

    ds.text(
        right_x, section_y, right_w, 0.35,
        [("売上構成比の推移", {"size": 13.0, "bold": True, "color": BLUE})],
    )

    ds.stack100(
        x=right_x, y=section_y + 0.42, w=right_w, h=1.1,
        segments=[
            ("プロダクト", 45.6),
            ("サービス",   27.8),
            ("コンサル",   18.0),
            ("その他",      8.6),
        ],
    )

    # 区切り線
    sep_y = section_y + 1.75
    ds.hline(right_x, sep_y, right_w, color=LINE, weight=1.0)

    # ウォーターフォール：コスト増減分解
    ds.text(
        right_x, sep_y + 0.1, right_w, 0.35,
        [("営業利益増減要因（億円）", {"size": 13.0, "bold": True, "color": BLUE})],
    )

    ds.waterfall(
        x=right_x, y=sep_y + 0.5, w=right_w, h=2.5,
        steps=[
            ("前期",     18.1, "start"),
            ("売上増",    4.8, "inc"),
            ("原価増",   -2.3, "dec"),
            ("販管費減",  0.8, "inc"),
            ("今期",     21.4, "total"),
        ],
    )

    # 出典
    ds.source("出所: 社内管理会計データ（2024年3月期）")

    # 保存
    ds.save(PPTX_OUT, PNG_OUT)
    print(f"[OK] pptx: {PPTX_OUT}")
    print(f"[OK] png : {PNG_OUT}")


if __name__ == "__main__":
    build_sample()
