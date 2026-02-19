---
title: Iterator Protocol Practical Patterns
description: >-
  Practical patterns for implementing Python's iterator protocol via class-based
  iterators, helper class separation, and generator functions.
  Use when designing custom iterables, implementing lazy data pipelines, or
  reimplementing standard library iterators for learning purposes.
category: python-practical-patterns
---

# イテレータプロトコル実践パターン

Pythonのイテレータプロトコルを使ってカスタムイテラブルを実装するための実践パターン集。クラスベース・ヘルパークラス分離・ジェネレータ関数の3方式を、選択基準とともに解説する。

---

## 1. イテレータプロトコルの基礎

### プロトコルの構成要素

Pythonの`for`ループは内部で以下の3要素を使用する：

| 要素 | 役割 |
|------|------|
| `__iter__(self)` | イテレータオブジェクトを返す |
| `__next__(self)` | 次の値を返す、終端で`StopIteration`を送出 |
| `StopIteration` | ループ終了を通知する例外 |

### for ループの動作展開

```python
# for ループの等価な手動実装
items = [10, 20, 30]
it = iter(items)       # __iter__ を呼ぶ

while True:
    try:
        value = next(it)   # __next__ を呼ぶ
        print(value)
    except StopIteration:
        break
```

`for x in obj:` は Python が自動的に上記シーケンスを実行するシンタックスシュガーである。

---

## 2. self 返却パターン（基本形）

### 実装構造

```python
class NumberRange:
    def __init__(self, start: int, stop: int) -> None:
        self.start = start
        self.stop = stop
        self.current = start

    def __iter__(self) -> "NumberRange":
        return self  # 自分自身がイテレータ

    def __next__(self) -> int:
        if self.current >= self.stop:
            raise StopIteration
        value = self.current
        self.current += 1
        return value
```

### self 返却の制約

```python
r = NumberRange(1, 4)

for n in r:
    print(n)  # 1 2 3

for n in r:
    print(n)  # 何も出力されない（currentがすでに終端）
```

**問題点**: `__iter__` が `self` を返すため、同一オブジェクトを2回ループすると2回目は空になる。

### いつ self 返却を使うか

- オブジェクトが「1回しか消費されない」ことが保証されている場合
- ファイルオブジェクトのような「消耗品」的なイテレータ

---

## 3. ヘルパークラスパターン（イテラブル/イテレータ分離）

### 設計原則

- **イテラブル**: データを保持し、`__iter__` でヘルパーの新規インスタンスを返す
- **ヘルパーイテレータ**: 現在位置などの走査状態のみを持つ

```python
class Countdown:
    def __init__(self, start: int) -> None:
        self.start = start

    def __iter__(self) -> "CountdownIterator":
        return CountdownIterator(self.start)  # 毎回新規作成


class CountdownIterator:
    def __init__(self, start: int) -> None:
        self.current = start

    def __next__(self) -> int:
        if self.current <= 0:
            raise StopIteration
        value = self.current
        self.current -= 1
        return value
```

### 複数回ループが可能になる

```python
cd = Countdown(3)

for n in cd:
    print(n)  # 3 2 1

for n in cd:
    print(n)  # 3 2 1（再び最初から）
```

ヘルパーの利点は**組織化**にもある。走査ロジックを分離することで各クラスの責務が明確になる。

---

## 4. 循環イテレータとモジュラス演算

### 循環（wrap-around）パターン

シーケンスを指定回数だけ、必要に応じて繰り返しながら返すイテレータ：

```python
class CyclicIterator:
    def __init__(self, data: list, count: int) -> None:
        self.data = data
        self.count = count
        self.index = 0

    def __next__(self) -> object:
        if self.index >= self.count:
            raise StopIteration
        value = self.data[self.index % len(self.data)]  # モジュラスで循環
        self.index += 1
        return value


class Cycle:
    def __init__(self, data: list, count: int) -> None:
        self.data = data
        self.count = count

    def __iter__(self) -> CyclicIterator:
        return CyclicIterator(self.data, self.count)
```

```python
for item in Cycle(['R', 'G', 'B'], 7):
    print(item)  # R G B R G B R
```

---

## 5. __iter__ の返却値の3択

```python
class FlexibleIterable:
    def __init__(self, data: list, max_items: int) -> None:
        self.data = data
        self.max_items = max_items

    # 選択肢1: self を返す（再利用不可）
    def __iter_v1__(self):
        self.index = 0
        return self

    # 選択肢2: ヘルパーインスタンスを返す（再利用可能）
    def __iter_v2__(self):
        return CyclicIterator(self.data, self.max_items)

    # 選択肢3: ジェネレータ式を返す（最簡潔）
    def __iter__(self):
        n = len(self.data)
        return (self.data[i % n] for i in range(self.max_items))
```

| 返却値 | 再利用性 | コード量 | 適用場面 |
|--------|---------|---------|---------|
| `self` | ×（1回のみ） | 少 | 消耗品的ストリーム |
| ヘルパークラス | ○ | 中 | 再利用が必要なコレクション |
| ジェネレータ式 | ○（毎回新規生成） | 最少 | シンプルな変換・フィルタ |

---

## 6. ジェネレータ関数パターン

### 基本構造

`yield` キーワードを含む関数はジェネレータ関数になる。呼び出すとジェネレータオブジェクト（イテレータ）が返される。

```python
def fibonacci(limit: int):
    a, b = 0, 1
    while a < limit:
        yield a        # 値を返して一時停止
        a, b = b, a + b

for n in fibonacci(100):
    print(n)  # 0 1 1 2 3 5 8 13 21 34 55 89
```

### ジェネレータ関数の特性

- 呼び出し時点では関数本体は実行されない
- `next()` が呼ばれるたびに次の `yield` まで実行
- 関数終端に到達すると自動的に `StopIteration` を発生させる
- ローカル変数はすべてのイテレーション間で状態を保持する

### ファイル横断パターン

複数ファイルの全行をフラットに返すジェネレータ：

```python
import os

def lines_from_directory(directory: str):
    """指定ディレクトリ内の全ファイルの全行を順に返す"""
    for filename in os.listdir(directory):
        full_path = os.path.join(directory, filename)
        try:
            for line in open(full_path):
                yield line.rstrip('\n')
        except OSError:
            pass  # ディレクトリや権限エラーはスキップ
```

```python
for line in lines_from_directory('/etc/'):
    if 'root' in line:
        print(line)
```

**ポイント**: `yield` を含むジェネレータ関数内では、明示的に `StopIteration` を `raise` しないこと。途中終了には `return` を使う。

### 時間ベースの状態保持パターン

ジェネレータはイテレーション間で状態を保持するため、時刻差分の計算に適している：

```python
import time

def with_elapsed(data):
    """各要素に前回イテレーションからの経過秒数を付加する"""
    last_time = None
    for item in data:
        now = time.perf_counter()
        delta = now - (last_time if last_time is not None else now)
        last_time = now
        yield delta, item
```

```python
for elapsed, word in with_elapsed(['start', 'middle', 'end']):
    print(f'{elapsed:.3f}s: {word}')
    time.sleep(0.5)
```

---

## 7. 標準ライブラリ再実装（学習用）

標準ライブラリの動作を理解するため、代表的な関数をジェネレータで再実装する。

### enumerate の再実装

```python
def my_enumerate(iterable, start: int = 0):
    index = start
    for item in iterable:
        yield index, item
        index += 1

for i, ch in my_enumerate('abc', start=1):
    print(f'{i}: {ch}')  # 1: a  2: b  3: c
```

### itertools.chain の再実装

```python
def my_chain(*iterables):
    """複数のイテラブルを連結して1つのシーケンスとして返す"""
    for iterable in iterables:
        for item in iterable:
            yield item

for x in my_chain('abc', [1, 2, 3], {'x': 10, 'y': 20}):
    print(x)  # a b c 1 2 3 x y
```

### zip の再実装

```python
def my_zip(*iterables):
    """最短のイテラブルが尽きた時点で終了する"""
    iterators = [iter(it) for it in iterables]
    while True:
        results = []
        for it in iterators:
            try:
                results.append(next(it))
            except StopIteration:
                return
        yield tuple(results)

for pair in my_zip('abc', [10, 20, 30]):
    print(pair)  # ('a', 10) ('b', 20) ('c', 30)
```

---

## 8. クラスイテレータ vs ジェネレータ関数

### 比較

| 観点 | クラスイテレータ | ジェネレータ関数 |
|------|----------------|----------------|
| コード量 | 多い | 少ない |
| 状態管理 | 属性で明示管理 | ローカル変数で自動管理 |
| 再利用性 | ヘルパー分離で対応可能 | 呼び出すたびに新規生成 |
| 追加メソッド | 自由に定義可能 | 不可（ジェネレータのみ） |
| 読みやすさ | 構造が明確 | シンプル |

### 選択基準

**クラスイテレータを選ぶ場合:**
- イテレータに追加メソッドやプロパティが必要
- 複雑な内部状態を複数の属性で管理する必要がある
- 既存クラスにイテレーション機能を後付けする場合

**ジェネレータ関数を選ぶ場合:**
- 純粋にデータを順に生成するだけでよい
- ファイル読み込み・フィルタリング・変換など一方向処理
- `itertools` 的な「ストリームのつなぎ目」として機能させる場合

---

## 9. よくある落とし穴

### 落とし穴1: self 返却で再利用できない

```python
# NG: 同一オブジェクトを2ループしても2回目は空
r = NumberRange(1, 4)
list(r)   # [1, 2, 3]
list(r)   # []  ← 意図しない挙動
```

解決策: ヘルパークラスを使うか、ジェネレータ関数にする。

### 落とし穴2: ジェネレータ内で StopIteration を raise しない

```python
# NG: Python 3.7以降では RuntimeError になる
def bad_generator():
    for i in range(3):
        raise StopIteration  # NG

# OK: return で抜ける
def good_generator():
    for i in range(3):
        if i == 2:
            return  # OK
        yield i
```

### 落とし穴3: ジェネレータを複数回消費しようとする

```python
gen = fibonacci(50)
list(gen)   # [0, 1, 1, 2, 3, 5, ...]
list(gen)   # []  ← ジェネレータは一度消費したら空
```

解決策: ジェネレータを再生成するか、`list()` で先に具体化する。
