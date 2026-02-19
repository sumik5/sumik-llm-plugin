---
title: Python Function Design Patterns
description: >-
  Practical patterns for advanced Python function design covering dispatch tables,
  closures, the operator module, LEGB scoping rules, and flexible interfaces with **kwargs.
  Use when designing higher-order functions, command routing, or flexible APIs.
category: python-practical-patterns
---

# Python 関数設計パターン

Pythonの関数はファーストクラスオブジェクトである。変数に代入でき、データ構造に格納でき、他の関数から返すことができる。この特性を活かした高度な設計パターンをまとめる。

---

## 1. ディスパッチテーブル

### 基本概念

**ディスパッチテーブル**とは、キーを関数にマッピングするdictである。`if/elif/else` チェーンの代替として使い、コマンドや操作を動的にルーティングする。

```python
def add(a, b): return a + b
def sub(a, b): return a - b
def mul(a, b): return a * b
def div(a, b): return a / b

operations = {
    '+': add,
    '-': sub,
    '*': mul,
    '/': div,
}

# 演算子文字列から関数を取り出して呼び出す
result = operations['+'](10, 5)  # → 15
```

### if/elif との比較

| アプローチ | 特徴 |
|-----------|------|
| `if/elif` | 逐次比較。新規ケース追加で本体を変更 |
| ディスパッチテーブル | O(1)ルックアップ。新規ケースはdict追加のみ |

```python
# 開放閉鎖原則に沿ったディスパッチテーブル
def route_command(command: str, payload: dict) -> str:
    handlers = {
        'create': handle_create,
        'read':   handle_read,
        'update': handle_update,
        'delete': handle_delete,
    }
    handler = handlers.get(command)
    if handler is None:
        raise ValueError(f"不明なコマンド: {command}")
    return handler(payload)
```

---

## 2. `operator` モジュール

### 概要

`operator` モジュールはPythonの組み込み演算子を関数として提供する。独自の演算関数を書く必要がなくなる。

```python
import operator

# 算術演算子
operator.add(3, 4)       # → 7
operator.sub(10, 3)      # → 7
operator.mul(2, 5)       # → 10
operator.truediv(7, 2)   # → 3.5（/ 演算子と同等）
operator.floordiv(7, 2)  # → 3（// 演算子と同等）
operator.mod(10, 3)      # → 1
operator.pow(2, 8)       # → 256
```

### operator を使ったディスパッチテーブル

独自の演算関数を定義する代わりに `operator` 関数を直接マッピングできる：

```python
import operator

# 前置記法計算器の例
def evaluate(expression: str) -> float:
    """前置記法式を評価する。例: '+ 10 5' → 15.0"""
    op_table = {
        '+':  operator.add,
        '-':  operator.sub,
        '*':  operator.mul,
        '/':  operator.truediv,
        '**': operator.pow,
        '%':  operator.mod,
    }
    op_str, a_str, b_str = expression.split()
    a, b = float(a_str), float(b_str)
    return op_table[op_str](a, b)

evaluate('* 3 4')   # → 12.0
evaluate('/ 10 4')  # → 2.5
```

### 高階関数との組み合わせ

```python
import operator

data = [{'name': 'Alice', 'score': 95}, {'name': 'Bob', 'score': 87}]

# operator.itemgetter: dictのキーでソート
sorted_data = sorted(data, key=operator.itemgetter('score'), reverse=True)

# operator.attrgetter: オブジェクトの属性でソート
from dataclasses import dataclass

@dataclass
class Student:
    name: str
    grade: float

students = [Student('Alice', 3.8), Student('Bob', 3.5)]
top = sorted(students, key=operator.attrgetter('grade'), reverse=True)
```

---

## 3. LEGBスコーピングルール

### スコープの4層

Pythonは識別子を以下の順で検索する（**LEGB**ルール）：

| 層 | 意味 | 例 |
|----|------|----|
| **L**ocal | 現在の関数内 | 関数内変数 |
| **E**nclosing | 外側の関数（クロージャ） | ネスト関数の外側スコープ |
| **G**lobal | モジュールレベル | モジュールのトップレベル変数 |
| **B**uilt-in | Python組み込み | `len`, `range`, `print` |

```python
x = 'global'  # Global

def outer():
    x = 'enclosing'  # Enclosing

    def inner():
        x = 'local'  # Local
        print(x)     # → 'local'

    inner()
    print(x)  # → 'enclosing'

outer()
print(x)  # → 'global'
```

### `global` 宣言

関数内からグローバル変数への書き込みには `global` が必要：

```python
config = {'debug': False}

def enable_debug():
    global config
    config = {'debug': True}  # グローバル変数を置き換える
```

> **注意**: ミュータブルオブジェクトの内容変更（`config['debug'] = True`）は `global` 不要。変数の再代入にのみ必要。

### `nonlocal` 宣言

ネスト関数から外側関数のローカル変数への書き込みには `nonlocal` が必要：

```python
def make_counter(start: int = 0):
    count = start

    def increment(step: int = 1) -> int:
        nonlocal count
        count += step
        return count

    return increment

counter = make_counter(10)
counter()    # → 11
counter(5)   # → 16
counter()    # → 17
```

### 組み込み名のシャドーイングに注意

```python
# ❌ 危険: 組み込みの sum をシャドーイング
sum = 0
for i in range(5):
    sum += i
# sum([1,2,3]) はここで TypeError になる

# ✅ 正しい: 別名を使う
total = 0
for i in range(5):
    total += i
```

---

## 4. クロージャと関数ファクトリ

### クロージャとは

クロージャは、**外側の関数のスコープ内の変数を参照し続ける内部関数**である。外側の関数が返った後も、その変数（自由変数）は生き続ける。

```python
def make_multiplier(factor: int):
    def multiply(x: float) -> float:
        return x * factor  # factor は自由変数（外側スコープを参照）
    return multiply

double = make_multiplier(2)
triple = make_multiplier(3)

double(5)   # → 10
triple(5)   # → 15
```

### 関数ファクトリパターン

異なるパラメータを持つ類似した関数を動的に生成する：

```python
import random

def make_sampler(population: str):
    """指定文字セットからランダムサンプリングする関数を返す"""
    def sample(length: int) -> str:
        return ''.join(random.choice(population) for _ in range(length))
    return sample

# 異なる文字セットから専用サンプラーを生成
digit_sampler  = make_sampler('0123456789')
alpha_sampler  = make_sampler('abcdefghijklmnopqrstuvwxyz')
hex_sampler    = make_sampler('0123456789abcdef')

digit_sampler(4)   # → '3821' のようなもの
hex_sampler(8)     # → 'a3f0b2c1' のようなもの
```

### 状態を持つクロージャ

`nonlocal` を使うと、クロージャ内で外側スコープの変数を更新できる：

```python
def make_accumulator(initial: float = 0.0):
    """呼ばれるたびに合計を積算する関数を返す"""
    total = initial

    def accumulate(value: float) -> float:
        nonlocal total
        total += value
        return total

    return accumulate

acc = make_accumulator()
acc(10)   # → 10.0
acc(5)    # → 15.0
acc(3)    # → 18.0
```

### クロージャ vs クラス

| 用途 | 推奨 |
|------|------|
| 単一メソッドの状態管理 | クロージャ |
| 複数メソッドの状態管理 | クラス |
| イミュータブルな設定のカプセル化 | クロージャ |
| ライフサイクル管理が必要 | クラス |

---

## 5. `**kwargs` による柔軟なインターフェース

### 基本構文

`**kwargs` は任意のキーワード引数を `dict` として受け取る：

```python
def describe(**kwargs) -> None:
    for key, value in kwargs.items():
        print(f'{key}: {value}')

describe(name='Alice', age=30, city='Tokyo')
# → name: Alice
# → age: 30
# → city: Tokyo
```

### パラメータの優先順位

```python
def func(positional, /, normal, *, keyword_only, **kwargs):
    ...
# 位置専用 → 通常 → キーワード専用 → **kwargs の順
```

### XML/HTML属性生成パターン

`**kwargs` は属性名=属性値の対をHTMLやXMLに変換するのに最適：

```python
def build_tag(tag: str, content: str = '', **attrs) -> str:
    """HTML/XMLタグを生成する"""
    attr_str = ''.join(
        f' {key}="{value}"'
        for key, value in attrs.items()
    )
    return f'<{tag}{attr_str}>{content}</{tag}>'

build_tag('p')                           # → <p></p>
build_tag('a', 'Click', href='/top')     # → <a href="/top">Click</a>
build_tag('div', 'Hello', id='main', class_='container')
# → <div id="main" class_="container">Hello</div>
```

### 設定オブジェクト構築パターン

```python
from typing import Any

def create_config(base: dict[str, Any], **overrides: Any) -> dict[str, Any]:
    """ベース設定にオーバーライドを適用した新しい設定を返す"""
    return {**base, **overrides}

default = {'timeout': 30, 'retries': 3, 'debug': False}
prod   = create_config(default, timeout=10, debug=False)
dev    = create_config(default, debug=True, retries=1)
```

### `*args` との使い分け

| 引数形式 | 用途 | 内部型 |
|---------|------|-------|
| `*args` | 可変長位置引数（同種の値を複数受け取る） | `tuple` |
| `**kwargs` | 可変長キーワード引数（名前付きオプション） | `dict` |

```python
# *args: 同種の複数値をforループで処理する想定
def sum_all(*numbers: float) -> float:
    return sum(numbers)

# **kwargs: 名前付きオプション設定
def connect(host: str, **options: Any) -> None:
    port    = options.get('port', 5432)
    timeout = options.get('timeout', 30)
    ...
```

---

## まとめ：関数設計の判断フロー

```
新しい関数を設計するとき
│
├─ 複数の操作を動的に選択したい
│   └─ ディスパッチテーブル（dict + 関数参照）
│
├─ 設定を固定した専用関数を複数作りたい
│   └─ 関数ファクトリ（クロージャ）
│
├─ 標準演算子を関数として扱いたい
│   └─ operator モジュール
│
├─ 呼び出し元が任意の名前付き引数を渡せるようにしたい
│   └─ **kwargs パターン
│
└─ 変数のスコープが予期しない動作をする
    └─ LEGBルールを確認 → global/nonlocal の使用を検討
```
