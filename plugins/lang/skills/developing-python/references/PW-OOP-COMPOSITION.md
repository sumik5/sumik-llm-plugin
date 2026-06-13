---
title: Python OOP Composition and Inheritance Patterns
description: >-
  Practical patterns for Python object-oriented design covering composition vs inheritance,
  multi-level object hierarchies, built-in type subclassing, ICPO attribute lookup,
  and dunder method implementation. Use when designing class hierarchies or modeling domain objects.
category: python-practical-patterns
---

# Python OOP：コンポジションと継承パターン

Pythonのオブジェクト指向は「全てはオブジェクト」という一貫した原則に基づく。クラス、属性、メソッドの仕組みを理解し、コンポジション（has-a）と継承（is-a）を適切に使い分けることが設計の核心である。

---

## 1. コンポジション vs 継承

### 判断フロー

```
2つのクラスの関係を設計するとき
│
├─ AはBの一種である（is-a）
│   └─ 継承: class A(B)
│       例: Wolf is-a Animal, Employee is-a Person
│
└─ AはBを持つ（has-a）
    └─ コンポジション: A の属性に B のインスタンスを格納
        例: Bowl has-a Scoop, Zoo has-a Cage
```

### 設計指針

| 観点 | コンポジション（has-a） | 継承（is-a） |
|------|----------------------|------------|
| 関係性 | 「含む」「所有する」 | 「一種である」 |
| 柔軟性 | 高い（実行時に差し替え可能） | 低い（コンパイル時に固定） |
| 誤用リスク | 低い | 高い（過剰な継承階層） |
| 推奨優先度 | 高い（GoF原則） | 適切な場合のみ |

---

## 2. 基本コンポジションパターン

### シンプルなhas-a設計

```python
class Ingredient:
    def __init__(self, name: str, quantity: float, unit: str) -> None:
        self.name = name
        self.quantity = quantity
        self.unit = unit

    def __repr__(self) -> str:
        return f'{self.quantity}{self.unit} {self.name}'


class Recipe:
    def __init__(self, title: str) -> None:
        self.title = title
        self.ingredients: list[Ingredient] = []  # has-a

    def add_ingredients(self, *items: Ingredient) -> None:
        for item in items:
            self.ingredients.append(item)

    def __repr__(self) -> str:
        lines = '\n'.join(f'  - {ing}' for ing in self.ingredients)
        return f'{self.title}:\n{lines}'
```

### `*args` でのコレクション管理

コンポジションオブジェクトを複数追加するメソッドには `*args` が自然：

```python
def add_ingredients(self, *items: Ingredient) -> None:
    """任意個数のIngredientを追加する"""
    for item in items:
        self.ingredients.append(item)

recipe = Recipe('カレー')
recipe.add_ingredients(
    Ingredient('玉ねぎ', 2, '個'),
    Ingredient('カレールー', 100, 'g'),
)
```

### クラス属性による上限設定

インスタンスごとではなく**クラス全体で共有する定数**はクラス属性として定義する：

```python
class LimitedCollection:
    max_items = 10  # クラス属性（全インスタンスで共有）

    def __init__(self) -> None:
        self.items: list = []  # インスタンス属性

    def add(self, *new_items) -> None:
        for item in new_items:
            if len(self.items) < self.max_items:  # self経由でアクセス
                self.items.append(item)
```

> `self.max_items` と記述すると、ICPOルールにより「インスタンス → クラス」の順で検索される。サブクラスでオーバーライドした場合も正しく動く。

---

## 3. 多段コンポジション（3層構造）

### 設計パターン

```
Zoo (3層目)
 └── [Cage, Cage, ...]    (2層目)
      └── [Animal, ...]  (1層目)
```

```python
class Animal:
    def __init__(self, color: str, number_of_legs: int) -> None:
        self.species = self.__class__.__name__  # クラス名を自動取得
        self.color = color
        self.number_of_legs = number_of_legs

    def __repr__(self) -> str:
        return f'{self.color} {self.species}, {self.number_of_legs}本足'


class Cage:
    def __init__(self, cage_id: int) -> None:
        self.cage_id = cage_id
        self.animals: list[Animal] = []

    def add_animals(self, *animals: Animal) -> None:
        for animal in animals:
            self.animals.append(animal)

    def __repr__(self) -> str:
        header = f'ケージ {self.cage_id}'
        body = '\n'.join(f'\t{a}' for a in self.animals)
        return f'{header}\n{body}'


class Zoo:
    def __init__(self) -> None:
        self.cages: list[Cage] = []

    def add_cages(self, *cages: Cage) -> None:
        for cage in cages:
            self.cages.append(cage)

    def __repr__(self) -> str:
        return '\n'.join(str(cage) for cage in self.cages)
```

### ネスト内包表記による集約クエリ

3層コンポジションを横断するクエリはネストした内包表記で表現できる：

```python
class Zoo:
    def animals_by_color(self, color: str) -> list[Animal]:
        return [
            animal
            for cage in self.cages
            for animal in cage.animals
            if animal.color == color
        ]

    def animals_by_legs(self, count: int) -> list[Animal]:
        return [
            animal
            for cage in self.cages
            for animal in cage.animals
            if animal.number_of_legs == count
        ]

    def total_legs(self) -> int:
        return sum(
            animal.number_of_legs
            for cage in self.cages
            for animal in cage.animals
        )
```

---

## 4. 組み込み型のサブクラス化

### `dict` のサブクラス化

`__getitem__` をオーバーライドして取得時の動作をカスタマイズできる：

```python
class TypeFlexibleDict(dict):
    """int/str のキーを相互に変換して検索するdict"""

    def __getitem__(self, key):
        if key in self:
            return super().__getitem__(key)
        # str → int 変換を試みる
        try:
            if str(key) in self:
                return super().__getitem__(str(key))
            if int(key) in self:
                return super().__getitem__(int(key))
        except (ValueError, TypeError):
            pass
        return super().__getitem__(key)  # KeyError を発生させる
```

> **重要**: `__getitem__` 内で `self[key]` を使うと無限再帰になる。必ず `super().__getitem__(key)` で親クラスのメソッドを直接呼ぶ。

### `__setitem__` での代入時の型変換

```python
class StringKeyDict(dict):
    """すべてのキーを文字列に変換して格納するdict"""

    def __setitem__(self, key, value):
        super().__setitem__(str(key), value)

skd = StringKeyDict()
skd[1] = 'one'
skd['1']  # → 'one' (intキーで代入、strキーで取得できる)
```

### `__missing__` フックの活用

存在しないキーへのアクセス時に `__missing__` が呼ばれる（`defaultdict` と同じ仕組み）：

```python
class AutoInitDict(dict):
    """存在しないキーに初期値を自動設定するdict"""

    def __missing__(self, key):
        self[key] = []  # 空リストを自動作成
        return self[key]

aid = AutoInitDict()
aid['fruits'].append('apple')
aid['fruits'].append('banana')
aid['fruits']  # → ['apple', 'banana']
```

---

## 5. 属性探索順序（ICPOルール）

### ICPO: Instance → Class → Parent → Object

Pythonが `a.b` を評価するとき、以下の順で検索する：

```
1. Instance (インスタンス辞書 a.__dict__)
2. Class    (type(a).__dict__)
3. Parent   (親クラスの __dict__, MROに従う)
4. Object   (最終祖先 object の __dict__)
```

```python
class Base:
    value = 'クラス属性'

    def show(self):
        return self.value  # ICPOで検索

b = Base()
b.show()        # → 'クラス属性' (Instance にないので Class を参照)

b.value = 'インスタンス属性'
b.show()        # → 'インスタンス属性' (Instance が優先される)
```

### `super()` による親メソッドの呼び出し

```python
class Animal:
    def __init__(self, color: str, legs: int) -> None:
        self.species = self.__class__.__name__
        self.color = color
        self.number_of_legs = legs

class Wolf(Animal):
    def __init__(self, color: str) -> None:
        super().__init__(color, 4)  # 親の__init__に委譲

class Snake(Animal):
    def __init__(self, color: str) -> None:
        super().__init__(color, 0)
```

> `super()` は親クラスを**名前でハードコードしない**ため、多重継承やリファクタリングに強い。

### クラス属性とICPOの相互作用

```python
class Bowl:
    max_scoops = 3  # クラス属性

    def add(self, scoop):
        if len(self.scoops) < self.max_scoops:  # ← self経由
            self.scoops.append(scoop)

class BigBowl(Bowl):
    max_scoops = 5  # 親のクラス属性をオーバーライド

# BigBowlインスタンスでadd()を呼ぶと:
# self.max_scoops → インスタンスにない → BigBowlにある(5) → 正しく動く
```

---

## 6. `__init__` / `__repr__` / `__str__` 実装

### `__init__` の設計原則

```python
class DataPoint:
    def __init__(
        self,
        x: float,
        y: float,
        label: str = '',
        weight: float = 1.0,
    ) -> None:
        # すべての属性をここで初期化する（後から追加しない）
        self.x = x
        self.y = y
        self.label = label
        self.weight = weight
```

| 原則 | 説明 |
|------|------|
| 全属性を `__init__` で定義 | どの属性があるか一箇所で把握できる |
| 後からの属性追加は避ける | 可読性と予測可能性が低下する |
| `return` しない | `__init__` の戻り値は無視される |

### `__repr__` の実装指針

```python
class Vector:
    def __init__(self, x: float, y: float) -> None:
        self.x = x
        self.y = y

    def __repr__(self) -> str:
        # 開発者向け: オブジェクトの状態を明確に表す文字列
        return f'Vector({self.x!r}, {self.y!r})'

    def __str__(self) -> str:
        # エンドユーザー向けの読みやすい表示
        return f'({self.x}, {self.y})'
```

| メソッド | 対象 | 呼ばれるタイミング |
|---------|------|------------------|
| `__repr__` | 開発者 | `repr(obj)`, デバッガ, REPLでの表示 |
| `__str__` | エンドユーザー | `str(obj)`, `print(obj)` |

> `__str__` が未定義の場合、`__repr__` がフォールバックとして使われる。最低限 `__repr__` だけ実装すれば両方をカバーできる。

### `self.__class__.__name__` パターン

親クラスの `__init__` でクラス名を自動取得するテクニック：

```python
class Shape:
    def __init__(self, color: str) -> None:
        self.kind = self.__class__.__name__  # サブクラス名が入る
        self.color = color

    def __repr__(self) -> str:
        return f'{self.color} {self.kind}'

class Circle(Shape):
    pass

class Rectangle(Shape):
    pass

Circle('red')      # → red Circle
Rectangle('blue')  # → blue Rectangle
```

---

## まとめ：クラス設計チェックリスト

```
新しいクラスを設計するとき
│
├─ 別クラスとの関係
│   ├─ is-a → 継承（class Child(Parent)）
│   └─ has-a → コンポジション（属性にインスタンスを格納）
│
├─ 属性の種類
│   ├─ 全インスタンスで共有 → クラス属性
│   └─ インスタンスごとに異なる → インスタンス属性（__init__で定義）
│
├─ Dunderメソッド
│   ├─ 必須: __init__（属性初期化）
│   ├─ 推奨: __repr__（デバッグ表示）
│   └─ 必要時: __str__, __getitem__, __setitem__, __missing__
│
├─ 継承時の __init__
│   └─ 親の __init__ を super().__init__() で呼ぶ
│
└─ 組み込み型のサブクラス化
    └─ 親メソッドはsuper().__getitem__()等で明示的に呼ぶ
       （self[key] は無限再帰になる）
```
