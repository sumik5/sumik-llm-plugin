# 4章: 辞書

## 概要
Pythonの辞書は多用途なデータ構造で、リストより効率的です。Python 3.7+で挿入順序が保証され、`get()`、`setdefault()`、`defaultdict`、`__missing__()`で高度な操作が可能です。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 25 | 挿入順序活用 | Python 3.7+で順序保証 |
| 26 | get()優先 | KeyErrorよりデフォルト値 |
| 27 | setdefault避ける | 可読性低い、defaultdict優先 |
| 28 | defaultdict活用 | 内部状態管理 |
| 29 | __missing__カスタマイズ | キー不在時の振る舞い定義 |

## 各項目の詳細

### 項目25: 挿入順序活用

**核心ルール:**
- Python 3.7+で挿入順序保証
- イテレート順序が予測可能
- 順序依存ロジック安全に実装

**推奨パターン:**
```python
# 挿入順序でイテレート
votes = {
    "baguette": 4,
    "ciabatta": 2,
    "泡芙": 1,
}

# 順序保証
for rank, (name, count) in enumerate(votes.items(), 1):
    print(f"{rank}: {name} has {count} votes")

# popitem()は最後の要素
last_key, last_value = votes.popitem()
```

**注意点:**
```python
# 古いPythonとの互換性
# Python 3.6以前は順序保証なし
# collections.OrderedDict使用
from collections import OrderedDict
ordered = OrderedDict()
```

### 項目26: get()優先

**核心ルール:**
- `KeyError`よりget()でデフォルト値
- `in`チェック不要
- 簡潔で安全

**推奨パターン:**
```python
counters = {"pumpernickel": 2, "sourdough": 1}

# get()
key = "wheat"
count = counters.get(key, 0)
counters[key] = count + 1

# setdefault()より明確
if key in counters:
    count = counters[key]
else:
    count = 0
    counters[key] = count
counters[key] = count + 1
```

**アンチパターン:**
```python
# KeyError処理（冗長）
try:
    count = counters[key]
except KeyError:
    count = 0
```

### 項目27: setdefault避ける

**核心ルール:**
- setdefault()は可読性低い
- defaultdict優先
- 単純なケースはget()

**推奨パターン:**
```python
# defaultdict
from collections import defaultdict

visits = defaultdict(set)
visits["Mexico"].add("Tulum")
visits["Japan"].add("Kyoto")
```

**アンチパターン:**
```python
# setdefault（読みにくい）
visits = {}
visits.setdefault("Mexico", set()).add("Tulum")
```

### 項目28: defaultdict活用

**核心ルール:**
- 自動デフォルト値生成
- 内部状態管理に最適
- ファクトリ関数指定

**推奨パターン:**
```python
from collections import defaultdict

# リスト
names = defaultdict(list)
names["cats"].append("Meowmer")

# int（カウンタ）
votes = defaultdict(int)
votes["baguette"] += 1

# カスタムファクトリ
def log_missing():
    print("Key added")
    return 0

current = defaultdict(log_missing)
```

### 項目29: __missing__カスタマイズ

**核心ルール:**
- キー不在時の振る舞い定義
- dictサブクラスで実装
- 複雑なロジックに対応

**推奨パターン:**
```python
class Pictures(dict):
    def __missing__(self, key):
        value = open_picture(key)
        self[key] = value
        return value

pictures = Pictures()
handle = pictures[path]  # 自動ロード
```

**defaultdictとの違い:**
```python
# defaultdict: ファクトリ関数のみ
# __missing__: キー情報利用可能、複雑なロジック
```

## 辞書の効率的な使い方

### パターン別推奨

| 用途 | 推奨手法 |
|------|---------|
| 単純な存在チェック | `get()` |
| 自動初期化 | `defaultdict` |
| 複雑なデフォルト値 | `__missing__` |
| 順序依存 | Python 3.7+辞書 |
| カウンタ | `collections.Counter` |

### パフォーマンス考慮

```python
# 高速なキー検索（O(1)）
if key in my_dict:
    value = my_dict[key]

# イテレート効率化
for key, value in my_dict.items():
    process(key, value)
```

## まとめ

辞書は挿入順序が保証され、get()やdefaultdictで安全かつ簡潔に操作できます。複雑なケースでは__missing__()でカスタマイズしましょう。
