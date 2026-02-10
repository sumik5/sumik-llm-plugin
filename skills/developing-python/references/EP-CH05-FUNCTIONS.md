# 5章: 関数

## 概要
Pythonの関数は強力な機能を持ち、意図を明確にし、再利用性を高め、バグを減少させます。デフォルト引数、キーワード引数、デコレータ、クロージャを理解して効果的に活用しましょう。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 30 | Noneと動的デフォルト | ミュータブルなデフォルト引数禁止 |
| 31 | 複数返り値 | タプルアンパックで明確化 |
| 32 | 大量引数回避 | リストより個別引数 |
| 33 | クロージャスコープ | nonlocal活用 |
| 34 | 可変長位置引数 | `*args`で柔軟性 |
| 35 | キーワード引数 | 明確性と柔軟性 |
| 36 | イテレータより複数回実行 | ジェネレータ関数活用 |
| 37 | キーワード専用引数 | `*`で強制 |
| 38 | 位置専用引数 | `/`で強制 |
| 39 | デコレータ | 関数拡張と再利用 |

## 各項目の詳細

### 項目30: Noneと動的デフォルト

**核心ルール:**
- ミュータブルなデフォルト引数禁止
- Noneでデフォルト値を動的生成
- ドキュメントに動的デフォルトを明記

**推奨パターン:**
```python
def decode(data, default=None):
    """データをデコード

    Args:
        data: デコード対象
        default: デコード失敗時の値（動的生成）
    """
    if default is None:
        default = {}
    # ...
```

**アンチパターン:**
```python
# ミュータブルなデフォルト（危険）
def decode(data, default={}):
    # すべての呼び出しで同じ辞書を共有
    pass
```

### 項目31: 複数返り値

**核心ルール:**
- タプルで複数値返却
- アンパックで明確化
- 3つ以上なら軽量クラスまたはnamedtuple

**推奨パターン:**
```python
def get_stats(numbers):
    minimum = min(numbers)
    maximum = max(numbers)
    return minimum, maximum

minimum, maximum = get_stats([1, 2, 3])

# 多数の返り値はnamedtuple
from typing import NamedTuple

class Stats(NamedTuple):
    minimum: int
    maximum: int
    average: float

def get_full_stats(numbers):
    return Stats(min(numbers), max(numbers), sum(numbers)/len(numbers))
```

### 項目32: 大量引数回避

**核心ルール:**
- リストより個別引数
- `*args`で可変長対応
- 過度な引数は設計見直し

**推奨パターン:**
```python
def log(message, *values):
    if not values:
        print(message)
    else:
        values_str = ", ".join(str(x) for x in values)
        print(f"{message}: {values_str}")

log("My numbers are", 1, 2)
log("Hi there")
```

### 項目33: クロージャスコープ

**核心ルール:**
- nonlocalで外側スコープ変更
- クロージャで状態管理
- 複雑ならクラス化

**推奨パターン:**
```python
def sort_priority(values, group):
    found = False
    def helper(x):
        nonlocal found  # 外側スコープ変更
        if x in group:
            found = True
            return (0, x)
        return (1, x)
    values.sort(key=helper)
    return found
```

### 項目34: 可変長位置引数

**核心ルール:**
- `*args`で柔軟性
- ジェネレータよりリスト展開
- 引数リストは短く

**推奨パターン:**
```python
def log(message, *values):
    print(message, *values)

log("Numbers:", 1, 2, 3)

# リスト展開
favorites = [7, 33, 99]
log("Favorite colors:", *favorites)
```

### 項目35: キーワード引数

**核心ルール:**
- 位置引数より明確
- デフォルト値で後方互換性
- 引数名変更注意

**推奨パターン:**
```python
def flow_rate(weight_diff, time_diff, period=1, units_per_kg=1):
    return ((weight_diff * units_per_kg) / time_diff) * period

# 明確
flow_rate(5, 2, period=3)
flow_rate(5, 2, period=3, units_per_kg=2.2)
```

### 項目36: イテレータより複数回実行

**核心ルール:**
- イテレータは一度のみ消費
- 複数回イテレートならジェネレータ関数
- コンテナクラスで`__iter__()`実装

**推奨パターン:**
```python
def normalize(get_iter):
    total = sum(get_iter())
    result = []
    for value in get_iter():
        percent = 100 * value / total
        result.append(percent)
    return result

# ジェネレータ関数渡し
percentages = normalize(lambda: read_visits(path))
```

### 項目37: キーワード専用引数

**核心ルール:**
- `*`でキーワード専用引数強制
- API明確化
- 誤用防止

**推奨パターン:**
```python
def safe_division(number, divisor, *,
                  ignore_overflow=False,
                  ignore_zero_division=False):
    # ...

# 必ずキーワード指定
result = safe_division(1.0, 10**500, ignore_overflow=True)
```

### 項目38: 位置専用引数

**核心ルール:**
- `/`で位置専用引数強制
- 引数名変更可能
- API安定化

**推奨パターン:**
```python
def safe_division_c(numerator, denominator, /,
                    ndigits=10):
    # numerator, denominatorは位置のみ
    # ...

# 位置指定
result = safe_division_c(22, 7)
result = safe_division_c(22, 7, ndigits=2)
```

### 項目39: デコレータ

**核心ルール:**
- 関数拡張と再利用
- functools.wrapsでメタデータ保持
- 複雑ならクラスベースデコレータ

**推奨パターン:**
```python
from functools import wraps

def trace(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        result = func(*args, **kwargs)
        print(f"{func.__name__}({args!r}, {kwargs!r}) "
              f"-> {result!r}")
        return result
    return wrapper

@trace
def fibonacci(n):
    # ...
```

## 関数設計のベストプラクティス

### 引数設計原則

| 種類 | 用途 | 記法 |
|------|------|------|
| 位置引数 | 必須、順序重要 | `func(a, b)` |
| キーワード引数 | オプション、名前重要 | `func(a, b, option=True)` |
| 可変長位置 | 任意個数 | `func(*args)` |
| キーワード専用 | 明示的指定必須 | `func(a, *, b)` |
| 位置専用 | 名前変更可能 | `func(a, /, b)` |

### 設計指針

```python
# 良い設計
def process_data(data, /,  # 位置専用
                 *,  # 以降キーワード専用
                 validate=True,
                 timeout=None):
    pass

# 呼び出し
process_data(my_data, validate=False, timeout=10)
```

## まとめ

関数設計では、ミュータブルなデフォルト引数を避け、キーワード専用・位置専用引数で明確なAPIを提供します。デコレータとクロージャで再利用性を高めましょう。
