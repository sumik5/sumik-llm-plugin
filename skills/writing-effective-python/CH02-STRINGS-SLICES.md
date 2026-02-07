# 2章: 文字列とスライス

## 概要
Pythonは文字列とシーケンス処理に優れた構文・メソッド・標準ライブラリを提供します。`bytes`と`str`の違いを理解し、f-stringやスライスを効果的に使うことで、テキスト処理が簡潔になります。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 10 | bytes/str区別 | 明確に区別、Unicodeサンドイッチパターン |
| 11 | f-string優先 | `%`演算子、`str.format()`より優れる |
| 12 | repr/str使い分け | デバッグは`repr()`、UI表示は`str()` |
| 13 | 明示的結合優先 | 暗黙的結合は混乱招く、`+`演算子使用 |
| 14 | スライス理解 | `start:end`で効率的分割 |
| 15 | ストライド分離 | `start:end:stride`同時指定避ける |
| 16 | catch-allアンパック | `*rest`でスライス不要 |

## 各項目の詳細

### 項目10: bytesとstrの違い

**核心ルール:**
- `bytes`は8ビット値、`str`はUnicodeコードポイント
- インタフェース境界でUnicodeサンドイッチ
- ファイルI/Oはモード明示（`rb`/`wb`、`r`/`w`）

**推奨パターン:**
```python
# bytes → str
def to_str(bytes_or_str):
    if isinstance(bytes_or_str, bytes):
        value = bytes_or_str.decode("utf-8")
    else:
        value = bytes_or_str
    return value

# str → bytes
def to_bytes(bytes_or_str):
    if isinstance(bytes_or_str, str):
        value = bytes_or_str.encode("utf-8")
    else:
        value = bytes_or_str
    return value

# バイナリファイルI/O
with open("data.bin", "rb") as f:
    data = f.read()
```

**アンチパターン:**
```python
# bytes と str を混在
b"one" + "two"  # TypeError

# モード指定忘れ
with open("data.bin", "r") as f:  # テキストモード（誤り）
    data = f.read()  # UnicodeDecodeError
```

### 項目11: f-string優先

**核心ルール:**
- f-stringが最優先（簡潔、強力、任意Python式）
- `%`演算子、`str.format()`は避ける
- プレースホルダに完全なPython式記述可能

**推奨パターン:**
```python
# f-string
key = "my_var"
value = 1.234
formatted = f"{key} = {value}"

# 書式指定
formatted = f"{key:<10} = {value:.2f}"

# Python式埋め込み
for i, item in enumerate(items):
    print(f"#{i+1}: {item.title():<10s} = {round(count)}")

# 複数行
print(f"{i+1}: "
      f"{item.title():<10s} = "
      f"{round(count)}")
```

**アンチパターン:**
```python
# %演算子（冗長）
formatted = "%-10s = %.2f" % (key, value)

# str.format()（やや冗長）
formatted = "{:<10} = {:.2f}".format(key, value)
```

### 項目12: repr/str使い分け

**核心ルール:**
- デバッグは`repr()`（型明確）
- UI表示は`str()`（人間可読）
- クラスは`__repr__()`定義

**推奨パターン:**
```python
# デバッグ
int_value = 5
str_value = "5"
print(f"{int_value!r} == {str_value!r}?")
# 5 == '5'?

# クラス定義
class BetterClass:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def __repr__(self):
        return f"BetterClass({self.x!r}, {self.y!r})"
```

### 項目13: 明示的結合優先

**核心ルール:**
- リスト・タプル・関数引数では`+`演算子使用
- 暗黙的結合は単一位置引数のみ
- カンマ欠損バグ防止

**推奨パターン:**
```python
# リスト内で明示的結合
my_list = [
    "first line\n",
    "second line\n"
    + "third line\n",  # 明示的
]

# 異なるエスケープ処理の結合
x = 1
my_str = (
    r"first \\ part is here with escapes\n, "
    f"string interpolation {x} in here, "
    'this has "double quotes" inside'
)
```

**アンチパターン:**
```python
# 暗黙的結合（曖昧）
my_list = [
    "first line\n",
    "second line\n"
    "third line\n",  # カンマ欠損
]
```

### 項目14: スライス理解

**核心ルール:**
- `somelist[start:end]`（`end`不含）
- `start`/`end`省略可能
- 範囲外インデックス許容

**推奨パターン:**
```python
a = ["a", "b", "c", "d", "e", "f", "g", "h"]

# 基本
a[:5]     # ["a", "b", "c", "d", "e"]
a[5:]     # ["e", "f", "g", "h"]
a[2:5]    # ["c", "d", "e"]
a[:-1]    # ["a", "b", "c", "d", "e", "f", "g"]

# 代入
a[2:7] = [99, 22, 14]  # 長さ変更可能

# 複製
b = a[:]
```

### 項目15: ストライド分離

**核心ルール:**
- `start`、`end`、`stride`同時指定避ける
- ストライドは正数のみ、負数は混乱
- 分離または`itertools.islice()`使用

**推奨パターン:**
```python
# ストライドのみ
x = ["red", "orange", "yellow", "green", "blue", "purple"]
odds = x[::2]    # ["red", "yellow", "blue"]
evens = x[1::2]  # ["orange", "green", "purple"]

# 分離
y = x[::2]   # ["red", "yellow", "blue"]
z = y[1:-1]  # ["yellow"]

# itertools.islice()
from itertools import islice
result = list(islice(x, 2, 7, 2))
```

**アンチパターン:**
```python
# 複雑すぎる
x[2::2]     # 読みにくい
x[-2:2:-2]  # 何が起こる？
x[2:2:-2]   # []（予想困難）
```

### 項目16: catch-allアンパック

**核心ルール:**
- `*rest`でスライス不要
- 任意位置配置可能
- イテレータ対応

**推奨パターン:**
```python
# 基本
car_ages = [20, 19, 15, 9, 8, 7, 6, 4, 1, 0]
oldest, second_oldest, *others = car_ages

# 任意位置
oldest, *others, youngest = car_ages
*others, second_youngest, youngest = car_ages

# イテレータ
def generate_csv():
    yield ("Date", "Make", "Model", "Year", "Price")
    # ...

it = generate_csv()
header, *rows = it
```

**アンチパターン:**
```python
# インデックス/スライス（冗長）
oldest = car_ages[0]
second_oldest = car_ages[1]
others = car_ages[2:]
```

## まとめ

文字列処理では`bytes`/`str`を明確に区別し、f-stringで簡潔に記述します。スライスとcatch-allアンパックでシーケンス操作が効率化されます。
