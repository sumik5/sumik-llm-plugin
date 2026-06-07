# 生成に関するデザインパターン（Creational Patterns）

GoF（Gang of Four）分類における生成パターンは、オブジェクトの生成方法を抽象化し、コードの柔軟性と再利用性を高める。

---

## 1. Factory Method パターン

### 目的

オブジェクト生成のインタフェースを定義しつつ、どのクラスをインスタンス化するかはサブクラスに委譲する。

### 問題と解決策

**問題:** スーパークラスがオブジェクトの生成を制御すると、新しいバリエーションを追加するたびに既存のコードを変更しなければならない。`match`文や`if/elif`による分岐が肥大化し、Single Responsibility Principle に違反する。

**解決策:** 生成処理をサブクラスに委譲するファクトリメソッドを定義する。スーパークラスはファクトリメソッドの呼び出し方を定義し、具体的な生成ロジックはサブクラスが担う。

### Python実装

```python
from abc import ABC, abstractmethod
from typing import Protocol


class Product(Protocol):
    """生成されるオブジェクトのインタフェース"""
    def operation(self) -> str: ...


class ConcreteProductA:
    def operation(self) -> str:
        return "ConcreteProductA の処理"


class ConcreteProductB:
    def operation(self) -> str:
        return "ConcreteProductB の処理"


class Creator(ABC):
    """ファクトリメソッドを持つ抽象クラス"""

    @abstractmethod
    def factory_method(self) -> Product:
        """サブクラスがオブジェクト生成を担う"""
        ...

    def some_operation(self) -> str:
        # ファクトリメソッドを呼び出して生成 → 利用
        product = self.factory_method()
        return f"Creator: {product.operation()}"


class ConcreteCreatorA(Creator):
    def factory_method(self) -> Product:
        return ConcreteProductA()


class ConcreteCreatorB(Creator):
    def factory_method(self) -> Product:
        return ConcreteProductB()


# 利用例
creator: Creator = ConcreteCreatorA()
print(creator.some_operation())  # Creator: ConcreteProductA の処理
```

### `@classmethod` を活用した Pythonic な実装

Python では `@classmethod` を使った代替コンストラクタパターンが Factory Method の自然な表現になる。

```python
from __future__ import annotations
from dataclasses import dataclass
from enum import Enum, auto


class Format(Enum):
    JSON = auto()
    CSV = auto()
    XML = auto()


@dataclass
class DataParser:
    format: Format
    delimiter: str = ","

    @classmethod
    def from_json(cls) -> DataParser:
        return cls(format=Format.JSON)

    @classmethod
    def from_csv(cls, delimiter: str = ",") -> DataParser:
        return cls(format=Format.CSV, delimiter=delimiter)

    @classmethod
    def from_xml(cls) -> DataParser:
        return cls(format=Format.XML)

    def parse(self, data: str) -> dict[str, object]:
        match self.format:
            case Format.JSON:
                import json
                return json.loads(data)
            case Format.CSV:
                # CSV パース処理
                rows = [row.split(self.delimiter) for row in data.splitlines()]
                return {"rows": rows}
            case Format.XML:
                # XML パース処理（省略）
                return {}


# 利用例
parser = DataParser.from_csv(delimiter="\t")
```

---

## 2. Abstract Factory パターン

### 目的

関連するオブジェクト群（ファミリー）を、具体的なクラスを指定せずに生成するインタフェースを提供する。

### 問題と解決策

**問題:** 複数のオブジェクトが「同一ファミリーに属さなければならない」制約がある場合、Factory Method だけでは異なるファミリーのオブジェクトが混在するリスクを防げない。例えば、ライトテーマとダークテーマで UI コンポーネントを混在させてはならない場合。

**解決策:** ファミリーごとにファクトリクラスを設ける。各ファクトリは同一ファミリーのオブジェクトのみを生成するため、ファミリーの混在を構造的に防止できる。

### Python実装

```python
from abc import ABC, abstractmethod


# --- 抽象プロダクト群 ---

class Button(ABC):
    @abstractmethod
    def render(self) -> str: ...


class Checkbox(ABC):
    @abstractmethod
    def render(self) -> str: ...


# --- 具体的なプロダクト群（ライトテーマファミリー） ---

class LightButton(Button):
    def render(self) -> str:
        return "[Light Button]"


class LightCheckbox(Checkbox):
    def render(self) -> str:
        return "[Light Checkbox]"


# --- 具体的なプロダクト群（ダークテーマファミリー） ---

class DarkButton(Button):
    def render(self) -> str:
        return "[Dark Button]"


class DarkCheckbox(Checkbox):
    def render(self) -> str:
        return "[Dark Checkbox]"


# --- 抽象ファクトリ ---

class UIFactory(ABC):
    @abstractmethod
    def create_button(self) -> Button: ...

    @abstractmethod
    def create_checkbox(self) -> Checkbox: ...


# --- 具体的なファクトリ ---

class LightThemeFactory(UIFactory):
    def create_button(self) -> Button:
        return LightButton()

    def create_checkbox(self) -> Checkbox:
        return LightCheckbox()


class DarkThemeFactory(UIFactory):
    def create_button(self) -> Button:
        return DarkButton()

    def create_checkbox(self) -> Checkbox:
        return DarkCheckbox()


# --- クライアント ---

class Application:
    def __init__(self, factory: UIFactory) -> None:
        self._button = factory.create_button()
        self._checkbox = factory.create_checkbox()

    def render(self) -> None:
        print(self._button.render())
        print(self._checkbox.render())


# 利用例: ファクトリを切り替えるだけで UI テーマが変わる
app = Application(DarkThemeFactory())
app.render()
```

### `abc.ABC` と `Protocol` の使い分け

```python
from abc import ABC, abstractmethod
from typing import Protocol, runtime_checkable


# abc.ABC: 実装の一部を共有したい場合、isinstance チェックが必要な場合
class AbstractFactory(ABC):
    @abstractmethod
    def create_product(self) -> object: ...

    def log(self, msg: str) -> None:
        print(f"[Factory] {msg}")


# Protocol: 既存クラスを変更せずに型チェックしたい場合（構造的部分型）
@runtime_checkable
class FactoryProtocol(Protocol):
    def create_product(self) -> object: ...
```

---

## 3. Singleton パターン

### 目的

クラスのインスタンスが常に1つだけ存在することを保証し、そのインスタンスへのグローバルアクセスポイントを提供する。

### 問題と解決策

**問題:** グローバル変数でオブジェクトを共有すると、複数のインスタンスが生成されたり、コピーが作られたりするリスクがある。グローバル変数は初期化順序が保証されず、不要なタイミングでオブジェクトが作成される問題もある。

**解決策:** クラス自身がインスタンスの存在を管理し、生成・コピー・直接インスタンス化を制御する。

### Python実装（`__new__` オーバーライド）

```python
import random
from typing import ClassVar


class Singleton:
    _instance: ClassVar[Singleton | None] = None

    @classmethod
    def get_instance(cls) -> "Singleton":
        if cls._instance is None:
            # super().__new__ で正規に生成
            cls._instance = super().__new__(cls)
            cls._instance._initialize()
        return cls._instance

    def _initialize(self) -> None:
        self._key = random.randint(1000, 9999)

    def __new__(cls) -> "Singleton":
        raise RuntimeError(
            "Singleton() で直接インスタンスを生成できません。"
            "get_instance() を使用してください。"
        )

    def __copy__(self) -> "Singleton":
        raise RuntimeError("Singleton のコピーは禁止されています。")

    def __deepcopy__(self, memo: dict[int, object]) -> "Singleton":
        raise RuntimeError("Singleton の deepcopy は禁止されています。")

    def __repr__(self) -> str:
        return f"Singleton(key={self._key})"


# 利用例
s1 = Singleton.get_instance()
s2 = Singleton.get_instance()
assert s1 is s2  # 常に同一インスタンス
```

### Python固有の代替手法

**モジュールレベル変数（最も Pythonic）:**

Python のモジュールは import 時に一度だけ実行され、以後はキャッシュされる。モジュールスコープのオブジェクトは自然な Singleton として機能する。

```python
# config.py
from dataclasses import dataclass, field


@dataclass
class AppConfig:
    debug: bool = False
    db_url: str = "sqlite:///app.db"
    max_connections: int = 10


# モジュールレベルで生成 → import 後は同一オブジェクト
config = AppConfig()
```

```python
# 利用側
from config import config  # 常に同一 config オブジェクトを参照

config.debug = True
```

**`__init_subclass__` で Singleton 基底クラスを定義:**

```python
from typing import ClassVar, Any


class SingletonMeta(type):
    _instances: ClassVar[dict[type, Any]] = {}

    def __call__(cls, *args: object, **kwargs: object) -> object:
        if cls not in cls._instances:
            cls._instances[cls] = super().__call__(*args, **kwargs)
        return cls._instances[cls]


class DatabaseConnection(metaclass=SingletonMeta):
    def __init__(self, url: str) -> None:
        self.url = url
        self._connected = False

    def connect(self) -> None:
        self._connected = True
```

---

## Factory Method vs Abstract Factory の使い分け

| 観点 | Factory Method | Abstract Factory |
|------|---------------|-----------------|
| 生成するオブジェクト数 | 1種類（バリエーションあり） | 複数種類（ファミリーをセットで生成） |
| ファミリーの混在防止 | できない | 構造的に防止できる |
| 拡張の単位 | サブクラスを追加してバリエーション追加 | 新しいファクトリクラスを追加してファミリー追加 |
| 典型的な用途 | テンプレートメソッドと組み合わせた生成 | テーマ切り替え、プラットフォーム対応、テスト用 stub 注入 |
| Python での実装 | `@classmethod` の代替コンストラクタ | `ABC` または `Protocol` を使ったファクトリ抽象 |

**Factory Method を選ぶ場面:**
- 1種類のオブジェクトについて、生成ロジックをサブクラスに任せたい
- 既存クラスを変更せずにオブジェクト生成方法を拡張したい

**Abstract Factory を選ぶ場面:**
- 複数のオブジェクトが「一緒に使われるべき」という制約がある
- ファミリーを丸ごと切り替えたい（テーマ変更、環境別設定など）
- 異なるファミリーのオブジェクトが混在することをコンパイル時・型チェック時に防ぎたい

---

## Singleton の適用判断

| 状況 | 推奨アプローチ |
|------|-------------|
| 設定値・定数の共有 | モジュールレベル変数（最も Pythonic） |
| 状態を持つリソース管理（DB接続等） | `metaclass=SingletonMeta` または `__new__` オーバーライド |
| テスト時に差し替えたい | Singleton より依存性注入（DI）を検討 |
| マルチスレッド環境 | `threading.Lock` でアクセス保護が必要 |

マルチスレッド環境での注意点: 複数スレッドが同時に `_instance is None` を評価すると複数インスタンスが生成される可能性がある。`threading.Lock` を使用して排他制御を行うこと。
