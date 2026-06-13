---
title: Practical Data Manipulation Patterns
description: >-
  Practical data manipulation patterns covering sorted() with key/operator module,
  Counter/most_common, dict accumulation (get/defaultdict), dict.keys() set operations,
  and set-based deduplication.
category: python-practical-patterns
---

# データ操作実践パターン

Python標準ライブラリを活用したデータ操作の実践パターン。`sorted()`の高度な使い方、
`Counter`、辞書蓄積パターン、集合演算を体系的にまとめる。

---

## 1. sorted()の高度な活用

### key引数の基本（lambda式）

```python
words = ["banana", "apple", "kiwi", "fig", "cherry"]

# 文字列の長さでソート
by_length = sorted(words, key=lambda w: len(w))
# ['fig', 'kiwi', 'apple', 'banana', 'cherry']

# 最後の文字でソート
by_last_char = sorted(words, key=lambda w: w[-1])
# ['banana', 'apple', 'kiwi', 'fig', 'cherry']

# 降順
by_length_desc = sorted(words, key=lambda w: len(w), reverse=True)
```

### operator.itemgetter（タプル/辞書のキー指定ソート）

`operator.itemgetter`はlambdaより高速で、複数キーの指定が簡潔になる。

```python
from operator import itemgetter

# タプルのリストをソート
countries = [
    ("Japan", "Asia", 125),
    ("Brazil", "Americas", 215),
    ("France", "Europe", 68),
    ("India", "Asia", 1400),
]

# 人口（インデックス2）でソート
by_population = sorted(countries, key=itemgetter(2))

# 地域（インデックス1）でソート
by_region = sorted(countries, key=itemgetter(1))

# 辞書のリストをソート
records = [
    {"name": "Alice", "score": 85, "grade": "B"},
    {"name": "Bob", "score": 92, "grade": "A"},
    {"name": "Carol", "score": 78, "grade": "C"},
]

by_score = sorted(records, key=itemgetter("score"))
by_grade = sorted(records, key=itemgetter("grade"))
```

**lambda vs itemgetter**:
- `lambda x: x[1]` と `itemgetter(1)` は等価だが、`itemgetter`はCで実装されているため高速
- 複数インデックスを同時に指定できる: `itemgetter(1, 2)` → `(row[1], row[2])`のタプルを返す

### operator.attrgetter（オブジェクト属性ソート）

```python
from operator import attrgetter
from dataclasses import dataclass

@dataclass
class Student:
    name: str
    gpa: float
    year: int

students = [
    Student("Alice", 3.8, 3),
    Student("Bob", 3.5, 4),
    Student("Carol", 3.8, 2),
]

# GPAでソート
by_gpa = sorted(students, key=attrgetter("gpa"), reverse=True)

# 複数属性: GPAで降順、同値の場合は学年で昇順
by_gpa_then_year = sorted(students, key=attrgetter("gpa", "year"))
```

### 複合キーソート（タプル返却）

タプルは要素を左から順に比較するため、複合条件のソートに使える。

```python
# 地域でソートし、同じ地域内では人口の降順
countries = [
    ("Japan", "Asia", 125),
    ("India", "Asia", 1400),
    ("France", "Europe", 68),
    ("Germany", "Europe", 84),
]

# (region, -population) のタプルをキーにする
sorted_countries = sorted(
    countries,
    key=lambda c: (c[1], -c[2])
)
# Asia地域: India(1400), Japan(125)
# Europe地域: Germany(84), France(68)
```

---

## 2. collections.Counter

### 頻度カウントの基本

```python
from collections import Counter

# 文字列の文字頻度
char_count = Counter("mississippi")
# Counter({'i': 4, 's': 4, 'p': 2, 'm': 1})

# リストの要素頻度
fruits = ["apple", "banana", "apple", "cherry", "banana", "apple"]
fruit_count = Counter(fruits)
# Counter({'apple': 3, 'banana': 2, 'cherry': 1})

# イテラブルから直接構築
words = "the quick brown fox the fox".split()
word_count = Counter(words)
# Counter({'the': 2, 'fox': 2, 'quick': 1, 'brown': 1})
```

### most_common(n)による上位n件取得

```python
# 最頻出3件を取得
top3 = word_count.most_common(3)
# [('the', 2), ('fox', 2), ('quick', 1)]

# 全件を頻度順で取得（引数なし）
all_sorted = word_count.most_common()

# 最も出現頻度の低い要素（末尾から取得）
least_common = word_count.most_common()[:-4:-1]
```

### Counter演算

```python
counter1 = Counter({"a": 3, "b": 2, "c": 1})
counter2 = Counter({"b": 1, "c": 2, "d": 1})

# 加算: 両方の出現回数を合算
print(counter1 + counter2)
# Counter({'a': 3, 'c': 3, 'b': 3, 'd': 1})

# 減算: 差を計算（0以下は除外）
print(counter1 - counter2)
# Counter({'a': 3, 'b': 1})

# 積集合: 各キーの最小値を取る
print(counter1 & counter2)
# Counter({'b': 1, 'c': 1})

# 和集合: 各キーの最大値を取る
print(counter1 | counter2)
# Counter({'a': 3, 'c': 2, 'b': 2, 'd': 1})
```

### 文字頻度の実践例

```python
def most_common_char(text: str) -> str:
    """テキスト中で最も多く登場する文字を返す（空白除く）。"""
    cleaned = text.replace(" ", "").lower()
    counts = Counter(cleaned)
    char, _ = counts.most_common(1)[0]
    return char

def char_frequency_report(text: str, top_n: int = 5) -> list[tuple[str, int]]:
    """文字の出現頻度レポートを返す。"""
    counts = Counter(c for c in text.lower() if c.isalpha())
    return counts.most_common(top_n)
```

---

## 3. 辞書蓄積パターン

複数の値を辞書に集約する際のイディオム。

### dict.get(key, default)による安全なアクセス

```python
# 危険: KeyErrorが発生する可能性
data = {}
data["key"] += 1  # KeyError!

# 安全: デフォルト値を使って安全に取得
data = {}
data["key"] = data.get("key", 0) + 1  # OK

# 月別降雨量の集計例
def accumulate_by_month(records: list[tuple[str, float]]) -> dict[str, float]:
    """(月名, 降雨量)のリストを月別に集計する。"""
    rainfall: dict[str, float] = {}
    for month, amount in records:
        rainfall[month] = rainfall.get(month, 0.0) + amount
    return rainfall
```

### collections.defaultdict

```python
from collections import defaultdict

# defaultdict(int): 存在しないキーのデフォルトは0
word_counts: defaultdict[str, int] = defaultdict(int)
for word in "the quick brown fox".split():
    word_counts[word] += 1  # KeyError不要

# defaultdict(list): 存在しないキーのデフォルトは[]
groups: defaultdict[str, list[str]] = defaultdict(list)
students = [("Math", "Alice"), ("Math", "Bob"), ("Science", "Carol")]
for subject, student in students:
    groups[subject].append(student)
# defaultdict({'Math': ['Alice', 'Bob'], 'Science': ['Carol']})

# defaultdict(set): 存在しないキーのデフォルトはset()
tag_index: defaultdict[str, set[str]] = defaultdict(set)
articles = [("Python", "article1"), ("Python", "article2"), ("Go", "article1")]
for tag, article in articles:
    tag_index[tag].add(article)
```

### setdefaultとの使い分け

```python
# setdefault: キーが存在しない場合のみデフォルト値をセット
data: dict[str, list[int]] = {}

# setdefaultを使う場合
data.setdefault("scores", []).append(85)
data.setdefault("scores", []).append(92)

# defaultdictを使う場合（より簡潔）
from collections import defaultdict
data2: defaultdict[str, list[int]] = defaultdict(list)
data2["scores"].append(85)
data2["scores"].append(92)
```

**使い分けの指針**:
- `dict.get(k, default)`: 読み取り専用。辞書を更新しない
- `setdefault(k, default)`: キーが存在しない場合に書き込み。既存値は変更しない
- `defaultdict(factory)`: 常にファクトリ関数を使う。大量の蓄積処理に最適

---

## 4. 辞書の集合演算

### dict.keys()が返す集合ライクビュー

`dict.keys()`は`KeysView`オブジェクトを返す。これは集合演算をサポートする。

```python
config_a = {"host": "localhost", "port": 8080, "debug": True}
config_b = {"host": "prod.example.com", "port": 443, "ssl": True}

keys_a = config_a.keys()
keys_b = config_b.keys()

# 和集合: どちらかに存在するキー
union_keys = keys_a | keys_b
# {'host', 'port', 'debug', 'ssl'}

# 積集合: 両方に存在するキー
common_keys = keys_a & keys_b
# {'host', 'port'}

# 差集合: aにあってbにないキー
only_in_a = keys_a - keys_b
# {'debug'}

# 対称差: どちらか一方にしか存在しないキー
unique_keys = keys_a ^ keys_b
# {'debug', 'ssl'}
```

### 辞書差分検出パターン

```python
def dict_diff(
    old: dict[str, object],
    new: dict[str, object],
) -> dict[str, object]:
    """2つの辞書の差分を返す（追加・削除・変更）。"""
    old_keys = old.keys()
    new_keys = new.keys()

    added = {k: new[k] for k in new_keys - old_keys}
    removed = {k: old[k] for k in old_keys - new_keys}
    changed = {
        k: {"before": old[k], "after": new[k]}
        for k in old_keys & new_keys
        if old[k] != new[k]
    }

    return {"added": added, "removed": removed, "changed": changed}

# 使用例
old_config = {"host": "localhost", "port": 8080, "debug": True}
new_config = {"host": "prod.example.com", "port": 443, "ssl": True}

diff = dict_diff(old_config, new_config)
# {'added': {'ssl': True},
#  'removed': {'debug': True},
#  'changed': {'host': {...}, 'port': {...}}}
```

---

## 5. 集合（set）の実践活用

### 重複除去イディオム

```python
# リストから重複を除去（順序不保持）
items = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3]
unique = list(set(items))

# 順序を保持しながら重複除去
def deduplicate_ordered(items: list[object]) -> list[object]:
    seen: set[object] = set()
    result: list[object] = []
    for item in items:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result

# 辞書リストの重複除去（特定フィールドで）
users = [
    {"id": 1, "name": "Alice"},
    {"id": 2, "name": "Bob"},
    {"id": 1, "name": "Alice"},  # 重複
]
seen_ids: set[int] = set()
unique_users = []
for user in users:
    if user["id"] not in seen_ids:
        seen_ids.add(user["id"])
        unique_users.append(user)
```

### メンバシップテスト（O(1)の検索）

```python
# リストでの検索: O(n)
valid_statuses_list = ["active", "inactive", "pending", "suspended"]
if "active" in valid_statuses_list:  # 全件スキャン
    pass

# 集合での検索: O(1)ハッシュ検索
valid_statuses: set[str] = {"active", "inactive", "pending", "suspended"}
if "active" in valid_statuses:  # ハッシュで即座に判定
    pass

# 大量のIDフィルタリング
def filter_valid_users(
    user_ids: list[int],
    valid_ids: list[int],
) -> list[int]:
    valid_set = set(valid_ids)  # 一度だけ変換
    return [uid for uid in user_ids if uid in valid_set]
```

**パフォーマンス**: 要素数が増えるとリストとの差が顕著になる。
10万要素のリスト検索がO(n)なのに対し、集合は常にO(1)。

### 部分集合判定

```python
required_permissions = {"read", "write"}
user_permissions = {"read", "write", "delete", "admin"}

# 部分集合判定（<=または issubset）
has_all_required = required_permissions <= user_permissions
# True: required_permissionsがuser_permissionsの部分集合

# 真部分集合（required_permissions ≠ user_permissions）
is_proper_subset = required_permissions < user_permissions
# True

# 上位集合判定
is_superset = user_permissions >= required_permissions
# True

# 素集合（共通要素なし）
set_a = {"a", "b", "c"}
set_b = {"x", "y", "z"}
are_disjoint = set_a.isdisjoint(set_b)  # True
```

### 集合内包表記

```python
# 基本的な集合内包表記
vowels = {"a", "e", "i", "o", "u"}

def get_vowel_words(words: list[str]) -> set[str]:
    """母音のみからなる単語の集合を返す。"""
    return {
        word for word in words
        if set(word.lower()) <= vowels
    }

# 使用例
sample = ["aeiou", "hello", "iou", "ai", "python", "ea"]
result = get_vowel_words(sample)
# {'aeiou', 'iou', 'ai', 'ea'}

# 条件付き集合構築
texts = ["Hello World", "PYTHON", "data Science", "ai"]
# 全文字が母音からなる単語を抽出
vowel_only = {
    word.lower()
    for text in texts
    for word in text.split()
    if set(word.lower()) <= vowels
}
```

**集合内包表記の特徴**:
- `{...}` を使う（リスト内包表記の`[...]`とは異なる）
- 自動的に重複を除去する
- 部分集合演算子`<=`と組み合わせると強力なフィルタリングが可能

---

## クイックリファレンス

### sorted()のkey引数チートシート

| 目的 | コード |
|------|--------|
| 長さでソート | `sorted(lst, key=len)` |
| 数値文字列をソート | `sorted(lst, key=int)` |
| タプルの2番目でソート | `sorted(lst, key=itemgetter(1))` |
| 辞書のキーでソート | `sorted(dicts, key=itemgetter("age"))` |
| オブジェクト属性でソート | `sorted(objs, key=attrgetter("name"))` |
| 複合ソート | `sorted(lst, key=lambda x: (x[1], -x[2]))` |

### Counter操作チートシート

| 操作 | コード |
|------|--------|
| 頻度カウント | `Counter(iterable)` |
| 上位N件 | `c.most_common(n)` |
| 合算 | `c1 + c2` |
| 差分 | `c1 - c2` |
| 積（最小値） | `c1 & c2` |
| 和（最大値） | `c1 | c2` |

### 辞書蓄積パターンチートシート

| 状況 | 使うパターン |
|------|------------|
| カウント | `d[k] = d.get(k, 0) + 1` または `defaultdict(int)` |
| リスト蓄積 | `d.setdefault(k, []).append(v)` または `defaultdict(list)` |
| 集合蓄積 | `defaultdict(set)` + `d[k].add(v)` |

### 集合演算チートシート

| 演算 | 記号 | メソッド |
|------|------|---------|
| 和集合 | `a | b` | `a.union(b)` |
| 積集合 | `a & b` | `a.intersection(b)` |
| 差集合 | `a - b` | `a.difference(b)` |
| 対称差 | `a ^ b` | `a.symmetric_difference(b)` |
| 部分集合 | `a <= b` | `a.issubset(b)` |
| 上位集合 | `a >= b` | `a.issuperset(b)` |
| 素集合確認 | — | `a.isdisjoint(b)` |
