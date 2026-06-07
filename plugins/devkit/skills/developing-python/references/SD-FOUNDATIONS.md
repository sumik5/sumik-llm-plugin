# ソフトウェア設計の基礎

Pythonアプリケーション開発における設計原則の基礎。良い設計の目標・反復開発プロセス・OOPの核心概念を体系化する。

## ソフトウェア設計とは何か

設計とは、問題に対する解を生み出すための規律あるエンジニアリングアプローチ。ソフトウェア設計では「要件を満たす持続可能なアプリケーション」が解となる。

**持続可能なアプリケーション**の条件:

| 特性 | 説明 |
|------|------|
| 要件を満たす | 期待通りの動作をする |
| 信頼性 | テストを通過し、バグが少ない |
| 驚きがない | メソッド呼び出し・オブジェクト生成で予期しない結果が出ない |
| 効率的 | 隠れたパフォーマンス問題がない |
| 柔軟性・拡張性 | 要件変更時に複雑度を増やさず機能追加できる |
| 協働を促進 | チームでの作業・悪い設計判断からの回復が容易 |
| 保守性 | 将来の開発者にとって理解しやすい |
| 時間・コストの節約 | 開発中のミスや大規模な作り直しが減る |

設計原則はコード数行〜クラス単位の改善を助け、設計パターンはアーキテクチャレベルの共通問題を解決する。

## 変更と複雑性への対処

**変更**と**複雑性**は良い設計の2大障害。

### 変更が発生する主な原因

- 要件の変化（開発中・リリース後ともに発生）
- 開発中の設計方針の変更
- 完成後の機能追加・削除

### 変更が漏れる（leak）問題

あるクラスへの変更が他クラスの変更を強制するパターン。

```python
# 悪い例: Driver が Car の実装詳細に依存している
class Car:
    def insert_key(self): ...
    def turn_key(self): ...

class Driver:
    def start_car(self):
        self._car.insert_key()
        self._car.turn_key()

# Car を press_start_button() に変更すると Driver も変更が必要になる
```

```python
# 良い例: Car が内部で起動処理をカプセル化
class Car:
    def start(self):
        # 内部実装の詳細を隠蔽
        self._ignition_system.activate()

class Driver:
    def start_car(self):
        self._car.start()  # Car の内部変更が Driver に波及しない
```

### 複雑性を招く設計パターン

| アンチパターン | 問題 |
|--------------|------|
| 1クラスが過剰な責務を持つ | バグ発見が困難、変更影響が広範囲 |
| サブクラスの過剰増殖 | 依存関係が増え、理解・デバッグが困難 |
| ハードコーディング | 実行時の柔軟性がなく、変更コストが高い |

## 反復設計プロセス（Iterative Design）

良い設計は一発で完成しない。設計→コード→テストの反復が必要。

### 反復の構造

```
Iteration 1: 初期設計 → 実装 → テスト
    ↓ （要件変更・設計判断の見直し）
Iteration 2: 改良設計 → 実装 → テスト
    ↓ （問題発見 → バックトラック）
Iteration 3: 別アプローチ → 実装 → テスト
    ↓ （良い設計に到達）
完成
```

**バックトラック**（行き詰まった設計から引き返すこと）は失敗ではなく、設計プロセスの正常な一部。

### 反復ごとの判断基準

| チェックポイント | 良い設計の指標 |
|----------------|--------------|
| 変更の波及範囲 | 変更が1クラスに閉じている |
| コードの重複 | 同じロジックのコピーがない |
| クラスの責務 | 各クラスが単一の主要責務を持つ |
| 依存関係 | クラス間の依存が最小限 |

### 反復の実例（書籍カタログアプリケーション）

```python
# Iteration 1: 基本クラス設計（単純だが拡張性がない）
class Book:
    def __init__(self, title, last, first):
        self._title = title
        self._last = last
        self._first = first

    @property
    def title(self): return self._title

    @property
    def last(self): return self._last

    @property
    def first(self): return self._first

class Catalogue:
    def __init__(self):
        self._booklist = []

    def add(self, title, last, first):
        self._booklist.append(Book(title, last, first))

    def find(self, target):
        return [b for b in self._booklist if self._is_match(b, target)]
```

```python
# Iteration 2: 属性をカプセル化（変更が漏れない設計へ）
from enum import Enum

class Genre(Enum):
    UNSPECIFIED = 0
    ADVENTURE = 1
    HORROR = 2
    # ...

class Attributes:
    def __init__(self, title, last, first, year, genre):
        self._title = title
        self._last = last
        self._first = first
        self._year = year
        self._genre = genre

    def is_match(self, target: 'Attributes') -> bool:
        # マッチング処理を Attributes クラスに委譲
        return (
            self._equal_ignore_case(target._title, self._title)
            and self._equal_ignore_case(target._last, self._last)
            and (target._year == 0 or target._year == self._year)
            and (target._genre == Genre.UNSPECIFIED or target._genre == self._genre)
        )

    @staticmethod
    def _equal_ignore_case(target: str, other: str) -> bool:
        return len(target) == 0 or target.casefold() == other.casefold()

class Catalogue:
    def __init__(self):
        self._booklist: list['Book'] = []

    def add(self, attrs: Attributes) -> None:
        self._booklist.append(Book(attrs))

    def find(self, target_attrs: Attributes) -> list['Book']:
        # Attributes クラスに委譲するだけ。属性追加の影響を受けない
        return [b for b in self._booklist if b.attributes.is_match(target_attrs)]
```

```python
# Iteration 4: 辞書ベース設計（最も柔軟・DRY）
from enum import Enum

class Key(Enum):
    KIND = 0; TITLE = 1; LAST = 2; FIRST = 3
    YEAR = 4; GENRE = 5; REGION = 6; SUBJECT = 7

class Attributes:
    def __init__(self, dictionary: dict):
        # 防御的プログラミング: 不正な値を拒否
        for key, value in dictionary.items():
            if key == Key.YEAR:
                assert isinstance(value, int)
            elif key in [Key.TITLE, Key.LAST, Key.FIRST]:
                assert isinstance(value, str)
        self._dictionary = dictionary

    def is_match(self, target_attrs: 'Attributes') -> bool:
        for key, value in target_attrs._dictionary.items():
            if not self._is_matching_key_value(key, value):
                return False
        return True

    def _is_matching_key_value(self, key: Key, value) -> bool:
        if key not in self._dictionary:
            return False
        stored = self._dictionary[key]
        if stored == value:
            return True
        if isinstance(value, str):
            return value.casefold() == stored.casefold()
        return False
```

## 主要な設計原則

各反復で適用される原則の概要:

| 原則 | 概要 | Pythonでの適用 |
|------|------|----------------|
| **Single Responsibility** | 1クラス = 1責務 | クラスを小さく保ち、各クラスが何をするか明確にする |
| **Encapsulate What Varies** | 変化する部分を分離 | 変わりやすいロジックを独立クラスに切り出す |
| **Delegation** | 適切なクラスに処理を委譲 | `book.attributes.is_match()` のように責務を持つクラスに任せる |
| **Principle of Least Knowledge** | クラス間の依存を最小化 | `_`プレフィックスでプライベート属性を隠蔽 |
| **Open-Closed** | 修正に閉じ、拡張に開く | スーパークラスを安定させ、サブクラスで拡張 |
| **Code to Interface** | 具体的なサブクラスでなくインターフェースに依存 | ポリモーフィズムを活用して柔軟性を確保 |
| **DRY** | コードの重複をなくす | 共通ロジックを1つのクラス・メソッドに集約 |

## OOP基本概念

### カプセル化（Encapsulation）

オブジェクトの状態（instance variables）と振る舞い（methods）を1つのクラスに包含する。Pythonでは `_` プレフィックスでプライベートを示す（言語強制ではなく慣例）。

```python
class Date:
    _MONTH_NAMES = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC']

    def __init__(self, year: int, month: int, day: int):
        # month は 0-based（注意: これが驚きの原因になることも）
        self._year = year
        self._month = month
        self._day = day

    def __str__(self) -> str:
        return f"{Date._MONTH_NAMES[self._month - 1]} {self._day}, {self._year}"
```

**設計拡張として**: 変化する部分をカプセル化することで、変更が他のクラスに波及することを防ぐ。

### 抽象化（Abstraction）

無関係な詳細を無視し、重要なことに集中する。複雑性を低減する重要な手段。

```python
from math import pi

class Circle:
    def __init__(self, radius: float):
        self._radius = radius

    @property
    def circumference(self) -> float:
        return 2 * pi * self._radius

    @property
    def area(self) -> float:
        return pi * self._radius ** 2
    # 利用者は計算式の詳細を意識しなくてよい
```

### 継承（Inheritance）

スーパークラスから状態・振る舞いを引き継ぎ、サブクラスが独自の拡張や上書きを行う。

```python
from abc import ABC, abstractmethod

class MotorVehicle(ABC):
    def __init__(self):
        self._speed = 0

    @abstractmethod
    def start_engine(self) -> None: pass

    @abstractmethod
    def stop_engine(self) -> None: pass

    def accelerate(self) -> None:
        print("vehicle accelerates")

class Car(MotorVehicle):
    def start_engine(self) -> None:
        print("car starts engine")

    def stop_engine(self) -> None:
        print("car stops engine")
    # accelerate() は継承
```

### ポリモーフィズム（Polymorphism）

同じ変数・パラメータが実行時に異なるサブクラスのオブジェクトを保持し、対応するメソッドが動的に呼び出される。設計を柔軟にする根幹的な仕組み。

```python
class Pet(ABC):
    @abstractmethod
    def speak(self) -> str: pass

class Cat(Pet):
    def speak(self) -> str: return "Meow"

class Dog(Pet):
    def speak(self) -> str: return "Woof"

# ポリモーフィズム: 実行時に適切なメソッドが選択される
pets: list[Pet] = [Cat(), Dog(), Cat()]
for pet in pets:
    print(pet.speak())  # Cat / Dog のメソッドが自動的に決まる
```

## AI生成コードの評価

AIツールが生成したコードは以下を確認する:

| チェック項目 | 確認内容 |
|------------|--------|
| 動作の正確性 | 正しい結果を返すか |
| 設計原則の適用 | Single Responsibility・Encapsulation等を守っているか |
| アーキテクチャ | 複数クラスの場合、設計パターンが適切か |
| 持続可能性 | 変更・拡張に強い設計か |

良い設計原則を自分で書けるようになってから、AIに適切なプロンプトで良い設計のコードを生成させる技術につながる。
