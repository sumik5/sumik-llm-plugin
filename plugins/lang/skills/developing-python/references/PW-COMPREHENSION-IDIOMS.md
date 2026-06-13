---
title: Comprehension Idioms Practical Patterns
description: >-
  Practical idioms for list, dict, and set comprehensions in Python, covering
  nested comprehensions, set subset operators, and generator expression memory efficiency.
  Use when transforming iterables, building dicts from sequences, or optimizing
  comprehension-heavy code for memory usage.
category: python-practical-patterns
---

# 内包表記イディオム実践パターン

リスト・辞書・集合内包表記の実践的なイディオムと、ジェネレータ式との使い分けを解説する。

---

## 1. 内包表記の基本判断軸

### 「いつ内包表記を使うか」の基準

```
内包表記 → イテラブルを新しいコレクションに変換したいとき
for ループ → 副作用（ファイル書き込み・DB挿入など）のために反復するとき
```

```python
words = ['hello', 'world', 'python']

# ✅ 内包表記: 新しいリストを生成する変換
lengths = [len(w) for w in words]

# ✅ for ループ: 副作用が目的
for w in words:
    log(w)  # ログに記録する（戻り値は不要）
```

### 内包表記の3行フォーマット

可読性のため、式・反復・条件を行分けすることを推奨する：

```python
# 1行形式（読みにくい）
result = [w.upper() for w in words if len(w) > 4]

# 3行形式（推奨）
result = [
    w.upper()
    for w in words
    if len(w) > 4
]
```

---

## 2. ジェネレータ式 vs リスト内包表記

### メモリ効率の違い

```python
# リスト内包表記: 全要素を一度にメモリへ
squares_list = [x * x for x in range(1_000_000)]
# → 約8MB以上のリストがメモリ上に存在する

# ジェネレータ式: 1要素ずつ遅延生成
squares_gen = (x * x for x in range(1_000_000))
# → メモリ消費はほぼゼロ
```

### 使い分けの基準

```python
numbers = range(100_000)

# ✅ ジェネレータ式: sum/max/min など1回消費する関数に渡す
total = sum(x * x for x in numbers)
maximum = max(x for x in numbers if x % 7 == 0)

# ✅ リスト内包表記: 複数回アクセスや要素数が少ない場合
small_squares = [x * x for x in range(10)]
print(small_squares[3])  # ランダムアクセスが必要

# ✅ 関数引数の場合は内側の括弧を省略できる
result = ','.join(str(n) for n in range(5))  # '0,1,2,3,4'
```

---

## 3. リスト内包表記の実践パターン

### 変換 + フィルタリング

```python
# 文字列から数値のみを抽出して整数に変換
raw = '10 abc 20 xyz 30 99'.split()
numbers = [
    int(token)
    for token in raw
    if token.isdigit()
]
# → [10, 20, 30, 99]
```

### ネスト内包表記: 平坦化

```python
matrix = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

# 2次元リストを1次元に平坦化
flat = [
    cell
    for row in matrix
    for cell in row
]
# → [1, 2, 3, 4, 5, 6, 7, 8, 9]
```

**注意**: ネスト内包表記は2重ループまでが可読性の限界。3重以上は通常の `for` ループに書き直すこと。

### ネスト内包表記: 条件付き

```python
# ペアのうち合計が10以上のものだけ取得
pairs = [
    (x, y)
    for x in range(5)
    for y in range(5)
    if x + y >= 8
]
# → [(4, 4), (3, 5) ...] ※ range(5) なので 0-4
```

---

## 4. 辞書内包表記の実践パターン

### 基本構文

```python
{ KEY_EXPR : VALUE_EXPR for ITEM in ITERABLE if CONDITION }
```

### パターン1: シーケンスから辞書を構築

```python
fruits = ['apple', 'banana', 'cherry']

# 単語 → 文字数の辞書
word_lengths = {word: len(word) for word in fruits}
# → {'apple': 5, 'banana': 6, 'cherry': 6}
```

### パターン2: enumerate 連携（アルファベット番号付け）

```python
import string

# アルファベット → 順番の辞書（a=1, b=2, ..., z=26）
letter_values = {
    char: index
    for index, char in enumerate(string.ascii_lowercase, start=1)
}
# → {'a': 1, 'b': 2, ..., 'z': 26}
```

`enumerate(iterable, start=N)` で開始番号を指定できる点がポイント。

### パターン3: zip 連携

```python
keys = ['name', 'age', 'city']
values = ['Alice', 30, 'Tokyo']

record = {k: v for k, v in zip(keys, values)}
# → {'name': 'Alice', 'age': 30, 'city': 'Tokyo'}
```

### パターン4: キーと値の反転（flip）

```python
original = {'a': 1, 'b': 2, 'c': 3}

flipped = {v: k for k, v in original.items()}
# → {1: 'a', 2: 'b', 3: 'c'}
```

値が重複する場合は後勝ちになるため注意。

### パターン5: 値変換（transform_values）

```python
# 全値に関数を適用した新しい辞書を返す
def transform_values(func, d: dict) -> dict:
    return {
        key: func(value)
        for key, value in d.items()
    }

prices = {'apple': 1.2, 'banana': 0.5, 'cherry': 2.0}
discounted = transform_values(lambda p: round(p * 0.9, 2), prices)
# → {'apple': 1.08, 'banana': 0.45, 'cherry': 1.8}
```

### パターン6: フィルタリング付き辞書構築

```python
scores = {'Alice': 85, 'Bob': 42, 'Carol': 91, 'Dave': 55}

# 合格者（60点以上）のみ抽出
passed = {
    name: score
    for name, score in scores.items()
    if score >= 60
}
# → {'Alice': 85, 'Carol': 91}
```

---

## 5. 集合内包表記の実践パターン

### 基本構文

```python
{ EXPR for ITEM in ITERABLE if CONDITION }
```

リスト内包表記との違いは`[]` → `{}`のみ。結果は重複なしの集合（`set`）。

### パターン1: ユニーク値の抽出

```python
text = 'the quick brown fox jumps over the lazy dog'

# テキスト中に登場するユニークな単語長の集合
unique_lengths = {len(word) for word in text.split()}
# → {2, 3, 4, 5} （順序は不定）
```

### パターン2: 部分集合演算子を使った文字集合チェック

`<` 演算子は集合の**真部分集合**を判定する：

```python
vowels = {'a', 'e', 'i', 'o', 'u'}

word = 'education'
is_supervocalic = vowels < set(word)
# → True（全母音を含む）

word2 = 'python'
is_supervocalic2 = vowels < set(word2)
# → False（'a', 'e', 'i', 'u' が不足）
```

| 演算子 | 意味 |
|--------|------|
| `a < b` | a は b の**真**部分集合（a != b かつ a ⊆ b） |
| `a <= b` | a は b の部分集合（a == b も含む） |
| `a & b` | 積集合（共通要素） |
| `a - b` | 差集合（a にあって b にないもの） |

### パターン3: 条件付き文字集合抽出

```python
sentence = 'Hello World Python'

# アルファベットのみをユニーク集合として抽出
unique_chars = {
    ch.lower()
    for ch in sentence
    if ch.isalpha()
}
# → {'h', 'e', 'l', 'o', 'w', 'r', 'd', 'p', 'y', 't', 'n'}
```

### パターン4: 集合内包表記でファイル検索

```python
def get_supervocalic_words(filename: str) -> set:
    """ファイル内の全母音を含む単語を集合で返す"""
    vowels = set('aeiou')
    return {
        word.strip()
        for word in open(filename)
        if vowels < set(word.lower())
    }
```

集合内包表記は重複を自動除去するため、辞書ファイルの重複エントリ対策として有効。

---

## 6. map/filter vs 内包表記

### 等価な記述の比較

```python
numbers = range(10)

# map: 関数を各要素に適用
squares_map = list(map(lambda x: x * x, numbers))

# リスト内包表記（推奨）
squares_comp = [x * x for x in numbers]
```

```python
words = ['apple', 'hi', 'banana', 'ok', 'cherry']

# filter: 条件に合う要素を残す
long_words_filter = list(filter(lambda w: len(w) > 3, words))

# リスト内包表記（推奨）
long_words_comp = [w for w in words if len(w) > 3]
```

### map が有利な場面

```python
import operator

# map は複数のイテラブルを同時に処理できる
letters = 'abcd'
counts = [3, 1, 2, 4]

# map: 2引数関数に2つのイテラブルを渡す
result_map = list(map(operator.mul, letters, counts))
# → ['aaa', 'b', 'cc', 'dddd']

# 内包表記で書く場合は zip が必要
result_comp = [
    letter * count
    for letter, count in zip(letters, counts)
]
```

### 現代 Python での推奨方針

- **可読性優先**: リスト内包表記を基本に使う
- **関数合成が連鎖する場合**: `map` + `filter` の方がシンプルなことがある
- **パフォーマンスが重要でメモリ節約が必要**: ジェネレータ式

---

## 7. 内包表記を使ったテーブル駆動パターン

### 辞書をルックアップテーブルとして活用

```python
import string

# 文字 → 数値のマッピングテーブルを動的生成
letter_values = {
    ch: i
    for i, ch in enumerate(string.ascii_lowercase, 1)
}

def word_score(word: str) -> int:
    """単語の各文字の数値の合計を返す"""
    return sum(
        letter_values.get(ch, 0)
        for ch in word.lower()
    )

# 単語リストから同スコアの単語を検索
def find_words_with_same_score(target: str, word_list: list) -> list:
    target_score = word_score(target)
    return [
        word
        for word in word_list
        if word_score(word) == target_score and word != target
    ]
```

このパターンの要点：
1. テーブル（辞書）を内包表記で動的構築する
2. ルックアップ処理を `dict.get(key, default)` で安全に行う
3. フィルタリング条件の複雑なロジックは別関数に切り出す

---

## 8. よくある落とし穴

### 落とし穴1: 内包表記内の副作用

```python
# NG: 内包表記で副作用を実行する
[print(x) for x in range(5)]  # リストが生成されるが無駄

# OK: 副作用は for ループで
for x in range(5):
    print(x)
```

### 落とし穴2: ネスト内包表記の順序

```python
# 外側ループ → 内側ループの順に書く（for ループと同じ順序）
flat = [item for sublist in matrix for item in sublist]
#             ↑外側                 ↑内側
```

### 落とし穴3: 辞書内包表記でキーが重複する場合

```python
pairs = [('a', 1), ('b', 2), ('a', 3)]  # 'a' が重複

d = {k: v for k, v in pairs}
# → {'a': 3, 'b': 2}  ← 後の値で上書き

# 重複を検出したい場合は Counter を使う
from collections import Counter
key_counts = Counter(k for k, _ in pairs)
```

### 落とし穴4: 集合内包表記と辞書内包表記の区別

```python
# {} は空の辞書（空の集合ではない）
empty_dict = {}          # dict
empty_set = set()        # set

# 集合内包表記: コロンなし
char_set = {ch for ch in 'hello'}   # {'h', 'e', 'l', 'o'}

# 辞書内包表記: コロンあり
char_dict = {ch: ord(ch) for ch in 'hello'}  # {'h': 104, ...}
```
