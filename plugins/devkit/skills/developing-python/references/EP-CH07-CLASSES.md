# 7章: クラスとインタフェース

## 概要
Pythonのクラスと継承を活用してオブジェクト指向設計を実現する方法。継承、ポリモーフィズム、カプセル化などの機能を使い、保守しやすいコードを書くための原則を学ぶ。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 48 | 単純なインタフェースにクラスではなく関数を使う | コンポーネント間の単純なインタフェースは関数で定義。`__call__()`でステートフルクロージャを実現 |
| 49 | isinstanceよりポリモーフィズムを優先 | `isinstance()`の代わりにポリモーフィズムで動作を変更し、読みやすく保守しやすいコードを実現 |
| 50 | OOPの代わりに関数型シングルディスパッチを検討 | `@singledispatch`で動作を凝縮し、独立したシステムを構築 |
| 51 | 軽量クラスにはdataclassesを優先 | `@dataclass`でボイラープレートを削減、型安全性・ヘルパー関数を自動生成 |
| 52 | @classmethodでジェネリックにオブジェクトを構築 | クラスメソッドのポリモーフィズムで代替コンストラクタを実現 |
| 53 | superで基底クラスを初期化 | `super()`でメソッド解決順序に従い、多重継承の問題を回避 |
| 54 | mix-inクラスで機能を追加 | 独自属性を持たないmix-inで再利用可能な機能を提供 |
| 55 | プライベート属性よりパブリック属性を優先 | プロテクト属性(`_`)で内部APIを示し、プライベート(`__`)は名前衝突回避のみに使用 |
| 56 | イミュータブルオブジェクトにdataclassesを優先 | `@dataclass(frozen=True)`で関数型スタイルの利点を享受 |
| 57 | カスタムコンテナはcollections.abcから継承 | 抽象基底クラスで必要なメソッドを自動提供し、正しいセマンティクスを保証 |

## 各項目の詳細

### 項目48: 単純なインタフェースにクラスではなく関数を使う

**核心ルール:**
- コンポーネント間の単純なインタフェースは関数で定義
- Pythonの関数は第一級オブジェクトで、引数として渡したり参照可能
- クラスに`__call__()`を定義すると呼び出し可能になり、ステートフルなクロージャを実現
- 関数に状態を持たせる場合は`__call__()`を持つクラスを定義

**推奨パターン:**
```python
from collections import defaultdict

# シンプルな関数フック
def log_missing():
    print("Key added")
    return 0

current = {"green": 12, "blue": 3}
result = defaultdict(log_missing, current)

# ステートフルなクロージャ（__call__使用）
class BetterCountMissing:
    def __init__(self):
        self.added = 0

    def __call__(self):
        self.added += 1
        return 0

counter = BetterCountMissing()
result = defaultdict(counter, current)  # __call__に依存
```

---

### 項目49: isinstanceよりポリモーフィズムを優先

**核心ルール:**
- `isinstance()`でオブジェクトの型に基づいて動作を変更できるが、コードが冗長化
- ポリモーフィズムを使えば、メソッド実行時に派生クラスの実装にディスパッチ
- オブジェクト指向設計で読みやすく、保守しやすく、拡張しやすく、テストしやすいコードを実現

**推奨パターン:**
```python
# OOPアプローチ（Good）
class Node:
    def evaluate(self):
        raise NotImplementedError

class IntegerNode(Node):
    def __init__(self, value):
        self.value = value

    def evaluate(self):
        return self.value

class AddNode(Node):
    def __init__(self, left, right):
        self.left = left
        self.right = right

    def evaluate(self):
        return self.left.evaluate() + self.right.evaluate()

tree = AddNode(IntegerNode(2), IntegerNode(9))
print(tree.evaluate())  # 11
```

**アンチパターン:**
```python
# isinstance使用（可読性・保守性低い）
def evaluate(node):
    if isinstance(node, Integer):
        return node.value
    elif isinstance(node, Add):
        return evaluate(node.left) + evaluate(node.right)
    elif isinstance(node, Multiply):
        return evaluate(node.left) * evaluate(node.right)
    else:
        raise NotImplementedError
```

---

### 項目50: OOPの代わりに関数型シングルディスパッチを検討

**核心ルール:**
- OOPはクラス中心で動作が分散し、大規模プログラムで保守困難になる場合あり
- シングルディスパッチは関数で引数の型に基づいてディスパッチし、関連機能を凝縮
- `functools.singledispatch`デコレータで実装
- 同じデータ上で動作する独立システムには関数型スタイルが優れる

**推奨パターン:**
```python
import functools

@functools.singledispatch
def my_evaluate(node):
    raise NotImplementedError

@my_evaluate.register(Integer)
def _(node):
    return node.value

@my_evaluate.register(Add)
def _(node):
    return my_evaluate(node.left) + my_evaluate(node.right)

# 別の機能を追加（同じファイルに凝縮可能）
@functools.singledispatch
def my_pretty(node):
    raise NotImplementedError

@my_pretty.register(Integer)
def _(node):
    return repr(node.value)
```

---

### 項目51: 軽量クラスにはdataclassesを優先

**核心ルール:**
- `@dataclass`デコレータでボイラープレートを削減
- 型アノテーションで静的型チェックが可能
- `kw_only=True`でキーワード専用引数、`field(default_factory=...)`でミュータブルなデフォルト値を安全に設定
- `__repr__()`, `__eq__()`, `__hash__()`などの特殊メソッドを自動生成

**推奨パターン:**
```python
from dataclasses import dataclass, field

@dataclass(kw_only=True)
class DataclassRGB:
    red: int
    green: int
    blue: int
    alpha: float = 1.0

color = DataclassRGB(red=1, green=2, blue=3)
print(color)  # DataclassRGB(red=1, green=2, blue=3, alpha=1.0)

# ミュータブルなデフォルト値
@dataclass
class Container:
    value: list = field(default_factory=list)
```

---

### 項目52: @classmethodでジェネリックにオブジェクトを構築

**核心ルール:**
- Pythonは`__init__()`のみをコンストラクタとしてサポート
- クラスメソッドで代替コンストラクタを定義可能
- クラスメソッドのポリモーフィズムで具象クラスのジェネリックな生成・組み合わせを実現

**推奨パターン:**
```python
class GenericInputData:
    @classmethod
    def generate_inputs(cls, config):
        raise NotImplementedError

class PathInputData(GenericInputData):
    @classmethod
    def generate_inputs(cls, config):
        data_dir = config["data_dir"]
        for name in os.listdir(data_dir):
            yield cls(os.path.join(data_dir, name))

class GenericWorker:
    @classmethod
    def create_workers(cls, input_class, config):
        workers = []
        for input_data in input_class.generate_inputs(config):
            workers.append(cls(input_data))
        return workers

# ジェネリックな使用
def mapreduce(worker_class, input_class, config):
    workers = worker_class.create_workers(input_class, config)
    return execute(workers)
```

---

### 項目53: superで基底クラスを初期化

**核心ルール:**
- Pythonのメソッド解決順序（MRO）で基底クラスの初期化順序と菱形継承の問題を解決
- `super()`を引数なしで使って基底クラスを初期化・メソッド呼び出し
- 多重継承時に共通基底クラスの`__init__()`が一度だけ実行されることを保証

**推奨パターン:**
```python
class MyBaseClass:
    def __init__(self, value):
        self.value = value

class TimesSevenCorrect(MyBaseClass):
    def __init__(self, value):
        super().__init__(value)
        self.value *= 7

class PlusNineCorrect(MyBaseClass):
    def __init__(self, value):
        super().__init__(value)
        self.value += 9

class GoodWay(TimesSevenCorrect, PlusNineCorrect):
    def __init__(self, value):
        super().__init__(value)

foo = GoodWay(5)
print(foo.value)  # 98 = 7 * (5 + 9)
```

---

### 項目54: mix-inクラスで機能を追加

**核心ルール:**
- インスタンス属性や`__init__()`を持つ多重継承はmix-inで代替
- インスタンスレベルでプラグイン可能な動作を提供し、必要に応じてクラスごとに修正
- mix-inはインスタンスメソッドまたはクラスメソッドを追加可能
- mix-inを組み合わせて単純な動作から複雑な機能を実装

**推奨パターン:**
```python
class ToDictMixin:
    def to_dict(self):
        return self._traverse_dict(self.__dict__)

    def _traverse_dict(self, instance_dict):
        output = {}
        for key, value in instance_dict.items():
            output[key] = self._traverse(key, value)
        return output

    def _traverse(self, key, value):
        if isinstance(value, ToDictMixin):
            return value.to_dict()
        elif isinstance(value, dict):
            return self._traverse_dict(value)
        elif isinstance(value, list):
            return [self._traverse(key, i) for i in value]
        else:
            return value

class BinaryTree(ToDictMixin):
    def __init__(self, value, left=None, right=None):
        self.value = value
        self.left = left
        self.right = right

tree = BinaryTree(10, left=BinaryTree(7), right=BinaryTree(13))
print(tree.to_dict())
```

---

### 項目55: プライベート属性よりパブリック属性を優先

**核心ルール:**
- プライベート属性(`__`)はPythonで厳密に強制されない（名前マングリングで回避可能）
- 派生クラスで使える内部APIを最初から設計し、プロテクト属性(`_`)を使用
- プロテクト属性の使い方をドキュメント化
- プライベート属性は制御できない派生クラスとの名前衝突回避のみに使用

**推奨パターン:**
```python
class MyStringClass:
    def __init__(self, value):
        # プロテクト属性（派生クラスで利用可能）
        self._value = value

# 名前衝突回避のためにプライベート使用
class ApiClass:
    def __init__(self):
        self.__value = 5  # プライベート

    def get(self):
        return self.__value

class Child(ApiClass):
    def __init__(self):
        super().__init__()
        self._value = "hello"  # 衝突なし
```

---

### 項目56: イミュータブルオブジェクトにdataclassesを優先

**核心ルール:**
- イミュータブルオブジェクトで関数型スタイルの利点を享受（テストが簡単、副作用なし）
- `@dataclass(frozen=True)`でイミュータブルクラスを簡単に定義
- `dataclasses.replace()`で一部属性が変更されたコピーを生成
- イミュータブルオブジェクトは値による等価性比較・安定したハッシュ値を持ち、辞書のキーや集合の要素として使用可能

**推奨パターン:**
```python
from dataclasses import dataclass, replace

@dataclass(frozen=True)
class DataclassImmutablePoint:
    name: str
    x: float
    y: float

origin = DataclassImmutablePoint("origin", 0, 0)
# origin.x = -3  # FrozenInstanceError

# replaceで一部変更したコピー
def translate(point, delta_x, delta_y):
    return replace(
        point,
        x=point.x + delta_x,
        y=point.y + delta_y,
    )

# 辞書のキーとして使用
point1 = DataclassImmutablePoint("A", 5, 10)
point2 = DataclassImmutablePoint("A", 5, 10)
charges = {point1: 1.5}
assert charges[point2] == 1.5  # 等価性で比較
```

---

### 項目57: カスタムコンテナはcollections.abcから継承

**核心ルール:**
- 単純なユースケースでは組み込み型を直接継承して基本動作を利用
- 組み込み型を継承しない場合、カスタムコンテナに必要な多くのメソッドが存在
- `collections.abc`の抽象基底クラスで必要なセマンティクスを満たす

**推奨パターン:**
```python
from collections.abc import Sequence

class BetterNode(SequenceNode, Sequence):
    pass

tree = BetterNode(
    10,
    left=BetterNode(5, left=BetterNode(2)),
    right=BetterNode(15),
)

# Sequenceが提供するメソッドが自動利用可能
print(tree.index(7))   # 自動実装
print(tree.count(10))  # 自動実装
```

**アンチパターン:**
```python
# __getitem__と__len__だけでは不十分
class IndexableNode(BinaryNode):
    def __getitem__(self, index):
        ...
    def __len__(self):
        ...

# index()やcount()がない
# tree.index(7)  # AttributeError
```