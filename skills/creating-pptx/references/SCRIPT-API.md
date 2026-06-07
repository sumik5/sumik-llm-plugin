# SCRIPT-API — pptx_kit 公開 API リファレンス

`skills/creating-pptx/scripts/pptx_kit.py` が提供する DualSlide クラスと
モジュール定数の全仕様。

---

## モジュール定数（カラーパレット）

```python
BLUE   = (0x19, 0x76, 0xD2)   # #1976D2  タイトル/見出し帯/バッジ/強調系列
VERMIL = (0xD8, 0x43, 0x15)   # #D84315  強調キーワード専用（ベタ塗り面に使わない）
LIGHT  = (0xE8, 0xF4, 0xFB)   # #E8F4FB  淡い塗り（最も強調したい 1 ブロックのみ）
INK    = (0x22, 0x22, 0x22)   # #222222  本文（純黒禁止）
SUB    = (0x88, 0x88, 0x88)   # #888888  補助・脚注・出典
LINE   = (0xE0, 0xE0, 0xE0)   # #E0E0E0  枠線・ヘアライン・破線
WHITE  = (0xFF, 0xFF, 0xFF)   # #FFFFFF  背景
```

**この 6 色以外の色はモジュール全体で使用禁止。**
型エイリアス: `ColorTuple = tuple[int, int, int]`

---

## キャンバス仕様

| 項目 | 値 |
|------|-----|
| pptx サイズ | 13.333 × 7.5 in (16:9) |
| プレビュー解像度 | `preview_scale` px/inch（デフォルト 150） |
| プレビューピクセル | 2000 × 1125 px（150 dpi 時） |
| 座標系 | インチ、原点は左上 |
| フォント（pptx） | Noto Sans JP（latin + a:ea 両方に設定） |
| フォント（PNG） | fc-match → ヒラギノ角ゴシック → Noto Sans CJK の順で解決 |
| 推奨余白 | 0.55 in（四辺統一） |

---

## class DualSlide

```python
class DualSlide(preview_scale: int = 150)
```

1 回の呼び出しで python-pptx スライドと Pillow 画像の両方へ同時に描画するキャンバス。

全メソッドはインスタンスを返さない（戻り値なし）。
全図形に影・グラデーション・3D・ベベル・光彩を付与しない。

---

### head_message

```python
def head_message(text: str, emphasis: str | None = None) -> None
```

スライド上部（四辺余白内）に結論一文を配置する。

| 引数 | 型 | デフォルト | 説明 |
|------|----|-----------|------|
| `text` | `str` | 必須 | 表示するテキスト全文 |
| `emphasis` | `str \| None` | `None` | VERMIL + Bold にする部分文字列。`None` で強調なし |

- フォントサイズ: HEAD (19pt)、色: INK
- `emphasis` が `text` に含まれない場合は無視する

```python
ds.head_message("コスト削減余地は年間 3 億円と試算", emphasis="年間 3 億円")
```

---

### text

```python
def text(
    x: float, y: float, w: float, h: float,
    runs: str | list[tuple[str, dict]],
    size: float = 12.0,
    color: ColorTuple = INK,
    bold: bool = False,
    align: str = "left",
    valign: str = "top",
    line_spacing: float = 1.4,
) -> None
```

テキストボックスを描画する。

| 引数 | 型 | デフォルト | 説明 |
|------|----|-----------|------|
| `x, y` | `float` | 必須 | 左上座標（インチ） |
| `w, h` | `float` | 必須 | 幅・高さ（インチ） |
| `runs` | `str \| list` | 必須 | テキスト内容。`str` または `[(text, style), ...]` |
| `size` | `float` | `12.0` | デフォルトフォントサイズ（pt） |
| `color` | `ColorTuple` | `INK` | デフォルト文字色 |
| `bold` | `bool` | `False` | デフォルト太字 |
| `align` | `str` | `"left"` | 水平揃え: `"left"` / `"center"` / `"right"` |
| `valign` | `str` | `"top"` | 垂直揃え: `"top"` / `"middle"` / `"bottom"` |
| `line_spacing` | `float` | `1.4` | 行間倍率（1.0 = 詰め） |

`runs` のスタイル辞書で指定できるキー:

| キー | 型 | 説明 |
|------|----|------|
| `"color"` | `ColorTuple` | 文字色（パレット内） |
| `"bold"` | `bool` | 太字 |
| `"size"` | `float` | フォントサイズ（pt） |

```python
# シンプルテキスト
ds.text(0.55, 1.2, 6.0, 0.4, "通常テキスト", size=11.0)

# インライン強調（VERMIL 部分のみ色変え）
ds.text(0.55, 1.8, 6.0, 0.4, [
    ("前期比 ", {}),
    ("+18%", {"color": VERMIL, "bold": True, "size": 14.0}),
    (" の増加", {}),
])
```

---

### rect

```python
def rect(
    x: float, y: float, w: float, h: float,
    fill: ColorTuple | None = None,
    line: ColorTuple | None = LINE,
    line_w: float = 1.0,
    radius: float = 0.0,
) -> None
```

矩形を描画する（フラット・影なし）。

| 引数 | 型 | デフォルト | 説明 |
|------|----|-----------|------|
| `x, y` | `float` | 必須 | 左上座標（インチ） |
| `w, h` | `float` | 必須 | 幅・高さ（インチ） |
| `fill` | `ColorTuple \| None` | `None` | 塗り色。`None` で透明 |
| `line` | `ColorTuple \| None` | `LINE` | 枠線色。`None` で枠線なし |
| `line_w` | `float` | `1.0` | 枠線幅（pt） |
| `radius` | `float` | `0.0` | 角丸半径（インチ）。使う場合は全図形で統一 |

```python
# LIGHT 塗り・枠線なし
ds.rect(0.55, 1.2, 5.5, 2.0, fill=LIGHT, line=None)
# 枠線のみ（塗りなし）
ds.rect(0.55, 1.2, 5.5, 2.0, fill=None, line=LINE, line_w=0.75)
# 角丸カード
ds.rect(0.55, 1.2, 5.5, 2.0, fill=WHITE, line=LINE, radius=0.08)
```

---

### hline

```python
def hline(
    x: float, y: float, w: float,
    color: ColorTuple = LINE,
    weight: float = 1.0,
    dash: bool = False,
) -> None
```

水平線を描画する。

| 引数 | 型 | デフォルト | 説明 |
|------|----|-----------|------|
| `x, y` | `float` | 必須 | 開始座標（インチ） |
| `w` | `float` | 必須 | 線の長さ（インチ） |
| `color` | `ColorTuple` | `LINE` | 線の色 |
| `weight` | `float` | `1.0` | 線の太さ（pt） |
| `dash` | `bool` | `False` | `True` でドット線 |

```python
ds.hline(0.55, 3.5, 12.2, color=LINE, weight=1.0)
ds.hline(0.55, 3.5, 12.2, color=LINE, dash=True)
```

---

### vline

```python
def vline(
    x: float, y: float, h: float,
    color: ColorTuple = LINE,
    weight: float = 1.0,
    dash: bool = False,
) -> None
```

垂直線を描画する。引数の意味は `hline` と対称。

```python
ds.vline(6.67, 1.0, 5.5, color=LINE, weight=0.75)
```

---

### arrow

```python
def arrow(
    x1: float, y1: float,
    x2: float, y2: float,
    color: ColorTuple = BLUE,
    weight: float = 1.5,
) -> None
```

直線矢印を描画する（`x2, y2` 側に矢じり・矢じりサイズ固定）。

| 引数 | 型 | デフォルト | 説明 |
|------|----|-----------|------|
| `x1, y1` | `float` | 必須 | 始点（インチ） |
| `x2, y2` | `float` | 必須 | 終点・矢じり側（インチ） |
| `color` | `ColorTuple` | `BLUE` | 線の色 |
| `weight` | `float` | `1.5` | 線の太さ（pt） |

```python
ds.arrow(2.0, 3.5, 4.5, 3.5)                      # 横向き
ds.arrow(3.0, 2.0, 3.0, 4.5, color=BLUE)          # 縦向き
```

---

### badge

```python
def badge(
    x: float, y: float,
    n: int,
    d: float = 0.32,
) -> None
```

丸数字バッジを描画する（BLUE 地・白数字・中央寄せ）。

| 引数 | 型 | デフォルト | 説明 |
|------|----|-----------|------|
| `x, y` | `float` | 必須 | バッジ**中心**座標（インチ） |
| `n` | `int` | 必須 | 表示する数字 |
| `d` | `float` | `0.32` | バッジの直径（インチ） |

```python
ds.badge(0.71, 1.35, 1)   # ① をバッジとして描画
ds.badge(0.71, 3.60, 2)   # ②
```

---

### table

```python
def table(
    x: float, y: float, w: float,
    rows: list[list[str]],
    col_widths: list[float],
    header: bool = True,
    aligns: list[str] | None = None,
    right_cols: set[int] | None = None,
) -> None
```

表を描画する（横罫線のみ・縦罫線なし）。

| 引数 | 型 | デフォルト | 説明 |
|------|----|-----------|------|
| `x, y` | `float` | 必須 | 左上座標（インチ） |
| `w` | `float` | 必須 | 表全体の幅（インチ） |
| `rows` | `list[list[str]]` | 必須 | 行データ（先頭行がヘッダーになる場合あり） |
| `col_widths` | `list[float]` | 必須 | 列の相対幅（合計比率。例: `[3, 1, 1]`） |
| `header` | `bool` | `True` | `True` で先頭行を LIGHT 塗り + Bold |
| `aligns` | `list[str] \| None` | `None` | 列ごとの揃え（`"left"` / `"center"` / `"right"`） |
| `right_cols` | `set[int] \| None` | `None` | 右揃えにする列インデックスの集合（数値列向け） |

```python
ds.table(
    x=0.55, y=1.6, w=8.0,
    rows=[
        ["区分",     "金額（百万円）", "前年比"],
        ["売上高",   "15,870",       "+11.5%"],
        ["売上原価", "10,230",        "+9.2%"],
    ],
    col_widths=[4, 2.5, 1.5],
    header=True,
    right_cols={1, 2},
)
```

---

### bar

```python
def bar(
    x: float, y: float, w: float, h: float,
    data: list[tuple[str, float]],
    highlight: int | None = None,
    unit: str = "",
    orient: str = "h",
) -> None
```

横棒グラフを描画する。

| 引数 | 型 | デフォルト | 説明 |
|------|----|-----------|------|
| `x, y` | `float` | 必須 | 左上座標（インチ） |
| `w, h` | `float` | 必須 | 描画領域の幅・高さ（インチ） |
| `data` | `list[tuple[str, float]]` | 必須 | `[(ラベル, 値), ...]` |
| `highlight` | `int \| None` | `None` | BLUE で強調する行インデックス（0 始まり） |
| `unit` | `str` | `""` | 値ラベルに付加する単位文字列 |
| `orient` | `str` | `"h"` | 向き（現在 `"h"` のみ対応） |

棒の原点は 0 固定。データラベルは棒の右に直接表示。

```python
ds.bar(
    x=0.55, y=2.0, w=6.0, h=3.0,
    data=[
        ("A 事業部", 58.2),
        ("B 事業部", 44.5),
        ("C 事業部", 31.0),
    ],
    highlight=0,
    unit="億円",
)
```

---

### stack100

```python
def stack100(
    x: float, y: float, w: float, h: float,
    segments: list[tuple[str, float]],
) -> None
```

100% 積み上げ横棒グラフを描画する。

| 引数 | 型 | デフォルト | 説明 |
|------|----|-----------|------|
| `x, y` | `float` | 必須 | 左上座標（インチ） |
| `w, h` | `float` | 必須 | 描画領域の幅・高さ（インチ） |
| `segments` | `list[tuple[str, float]]` | 必須 | `[(ラベル, 値), ...]` |

値の合計を 100% として各セグメントの構成比を描画する。
セグメント色はパレット内の `_SEG_COLORS = [BLUE, SUB, LINE, LIGHT]` で循環。
幅が 0.45 in 以上のセグメントには直接パーセントラベルを描画する。

```python
ds.stack100(
    x=7.0, y=2.0, w=5.8, h=1.0,
    segments=[
        ("自社製品", 48.0),
        ("OEM",     32.0),
        ("その他",  20.0),
    ],
)
```

---

### waterfall

```python
def waterfall(
    x: float, y: float, w: float, h: float,
    steps: list[tuple[str, float, str]],
) -> None
```

ウォーターフォールチャートを描画する。

| 引数 | 型 | デフォルト | 説明 |
|------|----|-----------|------|
| `x, y` | `float` | 必須 | 左上座標（インチ） |
| `w, h` | `float` | 必須 | 描画領域の幅・高さ（インチ） |
| `steps` | `list[tuple[str, float, str]]` | 必須 | `[(ラベル, 値, kind), ...]` |

`kind` の値と挙動:

| kind | 色 | 説明 |
|------|-----|------|
| `"start"` | BLUE | 開始棒（原点から積み上げ） |
| `"inc"` | BLUE | 増加分（直前の累計の上に積む） |
| `"dec"` | VERMIL | 減少分（直前の累計から差し引く） |
| `"total"` | BLUE | 合計棒（原点から積み上げ） |

```python
ds.waterfall(
    x=7.0, y=2.5, w=5.8, h=3.0,
    steps=[
        ("前期",   18.1, "start"),
        ("価格改定", 3.2, "inc"),
        ("原価増",  -1.8, "dec"),
        ("今期",   19.5, "total"),
    ],
)
```

---

### source

```python
def source(text: str) -> None
```

スライド下部（左余白付き）に出典テキストを配置する（SUB 8pt）。

```python
ds.source("出所: 社内管理会計データ（2024年3月期）")
```

---

### save

```python
def save(pptx_path: str, png_path: str) -> None
```

pptx と png の両方を書き出す。
出力先ディレクトリが存在しない場合は自動作成する。

| 引数 | 型 | 説明 |
|------|----|------|
| `pptx_path` | `str` | 出力する .pptx ファイルのパス |
| `png_path` | `str` | 出力する .png ファイルのパス |

```python
ds.save("output/slide.pptx", "output/slide.png")
```

---

## 完全な使用例

```python
from pptx_kit import DualSlide, BLUE, VERMIL, LINE, INK, SUB

ds = DualSlide(preview_scale=150)

# 結論一文
ds.head_message("施策実施により利益率を 2pp 改善できる", emphasis="2pp 改善")

# 背景カード
ds.rect(0.55, 1.25, 12.2, 5.5, fill=None, line=LINE, line_w=0.75)

# セクション見出しバッジ付き
ds.badge(0.71, 1.6, 1)
ds.text(0.95, 1.46, 5.0, 0.35, "現状分析", size=13.0, bold=True, color=BLUE)

# 表
ds.table(
    x=0.55, y=1.9, w=5.8,
    rows=[
        ["指標",   "現状",   "目標"],
        ["利益率", "11.5%", "13.5%"],
        ["在庫回転", "4.2",  "5.0"],
    ],
    col_widths=[3, 1.5, 1.5],
    header=True,
    right_cols={1, 2},
)

# 矢印
ds.arrow(6.6, 3.8, 7.5, 3.8, color=BLUE)

# 出典
ds.source("出所: 内部資料（2024年）")

ds.save("/tmp/result.pptx", "/tmp/result.png")
```

---

## フォント解決の優先順位（PNG プレビュー）

1. `fc-match "Noto Sans CJK JP"` の結果パス
2. `/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc`（macOS、Regular）
3. `/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc`（macOS、Bold）
4. `/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc`（Linux）
5. その他既知パス
6. `ImageFont.load_default()`（最終フォールバック、警告付き）

フォント未解決時は `warnings.warn` を発行してデフォルトフォントで継続する（例外は送出しない）。
