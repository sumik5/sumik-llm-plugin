# OOP設計原則リファレンス（Pythonにおける実践）

PythonにおけるOOP設計の核心原則。情報隠蔽、驚き最小化、サブクラス設計の3領域を扱う。

---

## 1. 情報隠蔽とカプセル化

### 1.1 最小知識の原則（Principle of Least Knowledge）

クラスAがクラスBの実装について知る情報を最小限に抑え、クラス間の依存を減らす原則。「一度publicにしたら、ずっとpublic」。

**Pythonでの実装**

```python
class Item:
    def __init__(self, name: str, price: float) -> None:
        self._name = name    # アンダースコア規約でプライベート
        self._price = price

    @property
    def name(self) -> str:
        return self._name

    @property
    def price(self) -> float:
        return self._price

    @price.setter
    def price(self, new_price: float) -> None:
        if new_price <= 0:
            raise ValueError(f"価格は正の値でなければなりません: {new_price}")
        self._price = new_price
```

**判断基準テーブル**

| 要素 | 判断 |
|------|------|
| 外部から変更が必要か | No → `@property`のみ（read-only）|
| バリデーションが必要か | Yes → `@<prop>.setter` にロジックを実装 |
| 実装の詳細か | Yes → アンダースコア `_` でプライベート化 |

---

### 1.2 Lazy Evaluation（遅延評価）

計算コストの高い処理を、結果が必要になるまで遅らせる。複数の表現形式を持つオブジェクト（例: julian日数と年月日）で特に有効。

```python
class Date:
    def __init__(self, *args: int) -> None:
        if len(args) == 1:           # Julian日数で初期化
            self._julian = args[0]
            self._ymd_valid = False
            self._julian_valid = True
        else:                        # 年月日で初期化
            self._year, self._month, self._day = args
            self._ymd_valid = True
            self._julian_valid = False

    def _validate_ymd(self) -> None:
        if not self._ymd_valid:      # 必要な時だけ変換
            self._year, self._month, self._day = Date._to_ymd(self._julian)
            self._ymd_valid = True

    @property
    def year(self) -> int:
        self._validate_ymd()         # アクセス時に遅延計算
        return self._year

    def add_days(self, n: int) -> "Date":
        self._validate_julian()      # 演算時に遅延計算
        return Date(self._julian + n)
```

**判断基準テーブル**

| 状況 | Lazy Evaluation適用 |
|------|---------------------|
| 計算コストが高い + 常に必要とは限らない | Yes |
| 複数の表現形式がある | Yes |
| 計算が軽量で常に必要 | No（積極的計算の方が単純） |

---

### 1.3 危険なsetterの回避

複数の変数が協調して1つの概念を表す場合、個々のsetterは不整合な状態を生む危険がある。

```python
# Before: 個別setterで存在しない日付が作れてしまう
date.month = 2    # 2月にセット（dayが31のまま → 2/31という不正状態）

# After: 一括setterで整合性を保証
def set_date(self, year: int, month: int, day: int) -> None:
    if not self._is_valid_date(year, month, day):
        raise ValueError(f"無効な日付: {year}/{month}/{day}")
    self._year, self._month, self._day = year, month, day
    self._julian_valid = False
```

**イミュータブルオブジェクトにmutableオブジェクトを内包する場合**

```python
from copy import copy

class Employee:
    def __init__(self, name: str, birthdate: Date) -> None:
        self._birthdate = copy(birthdate)    # コピーして格納（参照を保持しない）

    @property
    def birthdate(self) -> Date:
        return copy(self._birthdate)         # コピーして返す（変更を防ぐ）
```

---

### 1.4 Law of Demeter（デメテルの法則）

| ルール | 内容 | 可否 |
|--------|------|------|
| 1 | クラスが集約するオブジェクトのメソッド | 可 |
| 2 | 引数として渡されたオブジェクトのメソッド | 可 |
| 3 | 自分でインスタンス化したオブジェクトのメソッド | 可 |
| 4 | 他オブジェクトのメソッドが返したオブジェクトのメソッド | **不可** |

```python
class DemeterAuto:
    def maintain_auto(self, plug: Sparkplug) -> None:
        plug.replace()                       # OK: 引数（ルール2）
        self._engine.replace_sparkplug()     # OK: 集約（ルール1）
        Sparkplug("plug2").replace()         # OK: 自身で生成（ルール3）
        # self._engine.sparkplug.replace()  # NG: engineが返したオブジェクト（ルール4違反）
```

---

### 1.5 Open-Closed Principle（開放閉鎖原則）

スーパークラスは修正に対して閉じ、サブクラスによる拡張に対して開いている。共通実装を持つスーパークラスを安定化させ、変更リスクを最小化する。

```python
from abc import ABC, abstractmethod

class Mammal(ABC):
    def __init__(self, weight: float, height: float) -> None:
        self.__weight = weight    # ダブルアンダースコアで完全隠蔽

    @property
    def weight(self) -> float:
        return self.__weight

    @abstractmethod
    def eat(self) -> None: ...    # サブクラスが独自実装

    def sleep(self) -> None:      # 共通実装（変更しない）
        print("close eyes")
        self._snore()

class Human(Mammal):
    def __init__(self, weight: float, height: float, needs_glasses: bool) -> None:
        super().__init__(weight, height)
        self._needs_glasses = needs_glasses    # 拡張された状態

    def eat(self) -> None:
        print("eat with knife and fork")
```

---

## 2. 最小驚嘆の原則（Principle of Least Astonishment）

コードの動作がユーザーの期待を裏切らないようにする原則。

**驚きの原因と対策**

| 原因 | 対策 |
|------|------|
| オフバイワンエラー | 0始まりと1始まりのインデックスを統一する |
| 誤った関数名 | 副作用・戻り値・処理内容を正確に名前に反映 |
| 予期しないパフォーマンス | O(n²)アルゴリズムを避け、適切なデータ構造を選択 |

**オフバイワン修正例**

```python
# Before: month=2でインデックスすると MAR を返してしまう
MONTH_NAMES = ('JAN', 'FEB', 'MAR', ...)  # 0始まり
# After: ダミー要素で1始まりに統一
MONTH_NAMES = ('', 'JAN', 'FEB', 'MAR', ...)  # インデックス0はダミー
```

---

### 2.1 パフォーマンスの驚きを回避

**データ構造選択**

| データ構造 | 用途 | 相対速度 |
|-----------|------|---------|
| `list` + forループ | 一般的な可変シーケンス | 遅い |
| `list` + 内包表記/スライス | 同上（最適化） | 中（~28%改善） |
| `tuple` + スライス | 不変シーケンス | 速い（~45%改善） |
| `numpy.ndarray` + `mean()` | 数値計算 | 最速（~99%改善） |

**アルゴリズム選択**

```python
# Before: O(n²)の重複排除（ネストループ）
# After: O(n)のインライン重複排除
def merge_and_deduplicate(list1: list, list2: list) -> list:
    merged: list = []
    i1 = i2 = 0
    while (i1 < len(list1)) or (i2 < len(list2)):
        if (i1 < len(list1)) and ((i2 == len(list2)) or list1[i1] <= list2[i2]):
            if not merged or list1[i1] != merged[-1]:
                merged.append(list1[i1])
            i1 += 1
        else:
            if not merged or list2[i2] != merged[-1]:
                merged.append(list2[i2])
            i2 += 1
    return merged
```

---

### 2.2 契約による設計（Design by Contract）

| 概念 | 責任者 | 内容 |
|------|--------|------|
| Precondition（事前条件） | 呼び出し側 | メソッド呼び出し前に真でなければならない条件 |
| Postcondition（事後条件） | メソッド側 | メソッド返却前に真でなければならない条件 |
| Class Invariant（不変条件） | クラス側 | オブジェクトが常に満たすべき条件 |

```python
class CircularBuffer:
    def __init__(self, capacity: int) -> None:
        self._capacity = capacity
        self._head = self._tail = self._count = 0
        self._buffer: list = [None] * capacity
        assert self._class_invariant()

    def _class_invariant(self) -> bool:
        return (0 <= self._head < self._capacity) and \
               (0 <= self._tail < self._capacity)

    def add_precondition(self) -> bool:
        return self._count < self._capacity

    def add(self, value: object) -> None:
        assert self.add_precondition(), "バッファ満杯"
        self._buffer[self._tail] = value
        self._tail = (self._tail + 1) % self._capacity
        self._count += 1
        assert self._class_invariant()

    def remove_precondition(self) -> bool:
        return self._count > 0

    def remove(self) -> object:
        assert self.remove_precondition(), "バッファ空"
        value = self._buffer[self._head]
        self._head = (self._head + 1) % self._capacity
        self._count -= 1
        assert self._class_invariant()
        return value
```

---

## 3. サブクラス設計

### 3.1 オーバーライドとオーバーロードの使い分け

| 状況 | 選択 |
|------|------|
| サブクラスで異なる動作を実現 | オーバーライド |
| 同じ操作を異なる引数型・数で提供 | オーバーロード |
| 全く異なる動作 | 別メソッド名 |

**オーバーライド例**

```python
class Item:
    def _cost(self, price: float, weight: float) -> float:
        return price * weight

class OrganicItem(Item):
    def _cost(self, price: float, weight: float) -> float:
        return super()._cost(price, weight) * (1 + self._markup / 100)
```

**オーバーロード例（`@multimethod` 使用）**

```python
from multimethod import multimethod

class Line:
    @multimethod
    def length(self, x1: float, y1: float, x2: float, y2: float) -> float:
        return ((x1 - x2)**2 + (y1 - y2)**2) ** 0.5

    @multimethod
    def length(self, p1: tuple, p2: tuple) -> float:
        return self.length(p1[0], p1[1], p2[0], p2[1])

    @multimethod
    def length(self, p1: dict, p2: dict) -> float:
        return self.length(p1['x'], p1['y'], p2['x'], p2['y'])
```

---

### 3.2 Liskov Substitution Principle（リスコフ置換原則）

スーパークラスのオブジェクトが現れる箇所はどこでも、サブクラスのオブジェクトで置換できなければならない。

```python
# Before: CircularBuffer が list を継承（LSP違反）
class CircularBuffer(list):
    pass
# list.pop() や list[i] = x などで内部状態が破壊される

# After: list を集約（has-a関係）
class CircularBuffer:
    def __init__(self, capacity: int) -> None:
        self._buffer: list = [None] * capacity    # 内部に隠す

    def add(self, value: object) -> None:
        self._buffer[self._tail] = value           # 制御されたアクセスのみ
```

**判断基準テーブル**

| 問い | 判断 |
|------|------|
| サブクラスをスーパークラスの全操作で安全に使えるか | is-a（継承）OK |
| スーパークラスの操作の一部がサブクラスに無意味か | has-a（集約）に変更 |
| サブクラスにスーパークラスを壊す操作がないか | is-a（継承）検討OK |

---

### 3.3 is-a と has-a の選択基準

**Favor Composition over Inheritance Principle**: 挙動を継承（is-a）でなく集約（has-a）にすることでランタイム時に柔軟に変更できる。

| 観点 | is-a（継承） | has-a（集約） |
|------|------------|-------------|
| 挙動の変更タイミング | コンパイル時（固定） | ランタイム時（動的） |
| コード重複 | 多重継承で複雑化 | インターフェースで共有 |
| 結合度 | 強結合 | 疎結合 |
| LSPの適用 | 慎重な設計が必要 | 自然に満たされやすい |

**has-a によるランタイム柔軟性**

```python
class Toy(ABC):
    def __init__(self, play: PlayAction, sound: Sound) -> None:
        self.__play = play
        self.__sound = sound

    @play.setter
    def play(self, play: PlayAction) -> None:
        self.__play = play    # ランタイムで挙動を変更可能

# ランタイムで挙動を決定
train = TrainSet(RollPlay(), ChooChooSound())
train.play = FlyPlay()        # 動的に変更
```

---

### 3.4 Factory関数と Code to the Interface

Factory関数で具体クラスの生成をカプセル化し、呼び出し側がインターフェース（抽象クラス）のみに依存するようにする。

```python
class ToyFactory:
    toy_classes = [ToyCar, ModelAirplane, TrainSet]

    @staticmethod
    def make(toy_type: type, play: PlayAction, sound: Sound) -> Toy:
        return toy_type(play, sound)    # 具体クラスへの依存をここに集約

# 呼び出し側は Toy インターフェースのみに依存
for toy_class, play, sound in zip(ToyFactory.toy_classes, plays, sounds):
    toy: Toy = ToyFactory.make(toy_class, play, sound)
    print(toy)
```

---

### 3.5 サブクラスでの契約の注意点

| 条件 | サブクラスでの制約 |
|------|-----------------|
| Precondition（事前条件） | スーパークラスより **緩い**（or 同等）にすること |
| Postcondition（事後条件） | スーパークラスより **厳しい**（or 同等）にすること |

```python
# 問題: スーパークラスの precondition が cost >= 1
#       サブクラス Expedited の precondition が cost >= 5
# → cost = 4 はスーパークラスを満たすが、サブクラスでは失敗

# 解決策: ポリモーフィズムでサブクラス固有の条件を使用
def ship(shipment: Shipment, *, cost: float) -> None:
    if cost >= shipment._min_cost:    # サブクラス固有の _min_cost が使われる
        shipment.cost = cost
    shipment.calculate_days()
```
