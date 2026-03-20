# Cosmic Python Part 1: ドメインモデリングとRepository/Service Layer

ドメインモデルを「インフラから守る」一連のパターン。
- ORM逆転（Classical Mapping）でドメインをDBから分離
- Repository PatternでDBアクセスを抽象化
- Service LayerでユースケースをAPI/CLIから切り離す
- FakeRepositoryでサービス層を高速に単体テスト

---

## Ch1: ドメインモデリング基礎

### Value Object vs Entity の判断

| 観点 | Value Object | Entity |
|------|-------------|--------|
| 同一性の定義 | 属性の値がすべて同じなら等値 | 一意の識別子で同一性を判断 |
| 変更の意味 | 変更 = 別オブジェクトへの置き換え | 変更後も同じエンティティ |
| Pythonの実装 | `@dataclass(frozen=True)` | `__eq__` / `__hash__` を識別子ベースで定義 |
| 例 | 住所、金額、注文明細 | 顧客、商品バッチ、注文 |

**Value Object（不変）:**

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class Money:
    amount: int
    currency: str

    def __add__(self, other: "Money") -> "Money":
        if self.currency != other.currency:
            raise ValueError("通貨が異なります")
        return Money(self.amount + other.amount, self.currency)

# 使い方: 同値比較が自然に動く
price = Money(1000, "JPY")
tax = Money(100, "JPY")
total = price + tax  # Money(1100, "JPY")
assert price == Money(1000, "JPY")  # True
```

**Entity（同一性あり）:**

```python
import uuid
from dataclasses import dataclass, field
from typing import Optional

@dataclass
class Product:
    name: str
    sku: str
    stock_qty: int = 0
    id: uuid.UUID = field(default_factory=uuid.uuid4)

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Product):
            return False
        return self.id == other.id

    def __hash__(self) -> int:
        return hash(self.id)

    def reserve(self, qty: int) -> None:
        if qty > self.stock_qty:
            raise InsufficientStock(f"{self.sku}: 在庫不足")
        self.stock_qty -= qty
```

### Domain Service: オブジェクトに属さない操作

ビジネス操作が特定のエンティティに自然に属さない場合、**関数**として定義する。
Pythonはマルチパラダイム言語なので、`FooManager` クラスを作る必要はない。

```python
from typing import Sequence

class InsufficientStock(Exception):
    pass

# 複数の Product にまたがる操作 → Domain Service 関数
def transfer_stock(
    source: Product,
    destination: Product,
    qty: int,
) -> None:
    """在庫をsourceからdestinationに移す Domain Service"""
    source.reserve(qty)        # source の在庫を減らす
    destination.stock_qty += qty  # destination の在庫を増やす

def find_cheapest_supplier(
    products: Sequence[Product],
    target_sku: str,
) -> Optional[Product]:
    """指定SKUを持つ商品の中で最安値を返す"""
    candidates = [p for p in products if p.sku == target_sku and p.stock_qty > 0]
    return min(candidates, key=lambda p: p.stock_qty, default=None)
```

**ドメイン例外もユビキタス言語で命名する:**

```python
class InsufficientStock(Exception):
    """在庫不足 — ドメインの概念をそのまま例外に"""
    pass

class InvalidSku(Exception):
    """存在しないSKU参照"""
    pass
```

---

## Ch2: Repository Pattern — ORM依存の逆転

### 問題: 通常のORM利用ではドメインがDBに依存する

```python
# ❌ 通常のSQLAlchemy Declarative — モデルがORMを継承する
from sqlalchemy import Column, String, Integer
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class Product(Base):  # ドメインクラスがSQLAlchemyに依存 ← 問題
    __tablename__ = "products"
    id = Column(Integer, primary_key=True)
    sku = Column(String(100))
    name = Column(String(255))
```

### 解決: Classical Mapping — ORM がモデルを知る（逆転）

```python
# ✅ ORM逆転パターン
# domain/model.py — 純粋なPythonクラス（SQLAlchemy知識ゼロ）
from dataclasses import dataclass, field
import uuid

@dataclass
class Product:
    sku: str
    name: str
    stock_qty: int = 0
    id: uuid.UUID = field(default_factory=uuid.uuid4)

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Product):
            return False
        return self.id == other.id

    def __hash__(self) -> int:
        return hash(self.id)
```

```python
# infrastructure/orm.py — ORMがドメインを参照（依存方向が逆）
from sqlalchemy import Table, Column, String, Integer, MetaData
from sqlalchemy.orm import registry
import domain.model as model

mapper_registry = registry()
metadata = mapper_registry.metadata

products_table = Table(
    "products",
    metadata,
    Column("id", String(36), primary_key=True),
    Column("sku", String(100), nullable=False, unique=True),
    Column("name", String(255), nullable=False),
    Column("stock_qty", Integer, nullable=False, default=0),
)

def start_mappers() -> None:
    """アプリ起動時に1回呼ぶ。ドメインクラスとテーブルを紐付ける。"""
    if not mapper_registry.mappers:
        mapper_registry.map_imperatively(model.Product, products_table)
```

**依存の方向:**
```
domain/model.py  ← (知らない)
infrastructure/orm.py → domain/model.py  ← ORMがモデルをimport
```

### AbstractRepository: テスト可能な抽象レイヤー

```python
# domain/ports.py — リポジトリのインターフェース定義
import abc
from typing import Optional
import uuid

class AbstractProductRepository(abc.ABC):
    @abc.abstractmethod
    def add(self, product: "Product") -> None: ...

    @abc.abstractmethod
    def get_by_sku(self, sku: str) -> Optional["Product"]: ...

    @abc.abstractmethod
    def get(self, product_id: uuid.UUID) -> Optional["Product"]: ...
```

```python
# infrastructure/repository.py — SQLAlchemy実装
from sqlalchemy.orm import Session
from domain.model import Product
from domain.ports import AbstractProductRepository
import uuid

class SqlAlchemyProductRepository(AbstractProductRepository):
    def __init__(self, session: Session) -> None:
        self._session = session

    def add(self, product: Product) -> None:
        self._session.add(product)

    def get_by_sku(self, sku: str) -> Optional[Product]:
        return self._session.query(Product).filter_by(sku=sku).first()

    def get(self, product_id: uuid.UUID) -> Optional[Product]:
        return self._session.query(Product).filter_by(id=str(product_id)).first()
```

### FakeRepository: インメモリ実装でテストを高速化

```python
# tests/fakes.py
from domain.ports import AbstractProductRepository
from domain.model import Product
import uuid

class FakeProductRepository(AbstractProductRepository):
    """テスト専用のインメモリRepository。DBなしで単体テスト可能。"""

    def __init__(self, initial: list[Product] | None = None) -> None:
        self._storage: set[Product] = set(initial or [])

    def add(self, product: Product) -> None:
        self._storage.add(product)

    def get_by_sku(self, sku: str) -> Optional[Product]:
        return next((p for p in self._storage if p.sku == sku), None)

    def get(self, product_id: uuid.UUID) -> Optional[Product]:
        return next((p for p in self._storage if p.id == product_id), None)

    def list_all(self) -> list[Product]:
        return list(self._storage)
```

**Repository選択基準:**

| 用途 | 実装 |
|------|------|
| 本番環境 | `SqlAlchemyProductRepository` |
| 単体テスト | `FakeProductRepository` |
| 統合テスト | `SqlAlchemyProductRepository` + テスト用DBセッション |

---

## Ch3: 抽象化の選択 — 何を隠すか

Repository patternの導入後、**何をフェイクにするか**の判断基準：

| 判断軸 | 指針 |
|--------|------|
| 自分が所有するコードか？ | ✅ 所有するなら抽象化 → フェイク可能に |
| 外部ライブラリか？ | ⚠️ 直接フェイクしない — ラッパーを作る |
| テスト速度の関係 | 遅いものをフェイクする（DB・外部API） |

**「自分が所有しないものをモックするな (Don't mock what you don't own)」**

```python
# ❌ SQLAlchemy sessionを直接モックする — 危険
mock_session = Mock(spec=Session)
mock_session.query.return_value.filter_by.return_value.first.return_value = product

# ✅ AbstractRepositoryの背後にFakeを用意する
repo = FakeProductRepository([product])
result = repo.get_by_sku("SKU-001")
```

---

## Ch4: Service Layer — ユースケースの入口

Service LayerはHTTP/CLI/イベントハンドラーなど**複数の入口から呼ばれる共通ロジック**を集約する。

```
[HTTP API]   →  ┐
[CLI]        →  ├── Service Layer → Repository → Domain Model
[テスト]     →  ┘
```

### サービス関数の設計原則

1. **プリミティブ型を引数に取る** — ドメインオブジェクトではなく `str`, `int`, `date` を受け取る
2. **リポジトリをDIで受け取る** — テスト時にFakeRepositoryを差し込める
3. **自身でコミットしない**（後でUoWに委譲）か、Session/UoWをDIで受け取る

```python
# service_layer/services.py
from typing import Optional
from datetime import date
from domain.model import Product, InsufficientStock, InvalidSku
from domain.ports import AbstractProductRepository

def add_product(
    sku: str,
    name: str,
    initial_stock: int,
    repo: AbstractProductRepository,
    session,  # Ch6でUoWに置き換える
) -> str:
    product = Product(sku=sku, name=name, stock_qty=initial_stock)
    repo.add(product)
    session.commit()
    return str(product.id)

def reserve_stock(
    sku: str,
    qty: int,
    repo: AbstractProductRepository,
    session,
) -> None:
    product = repo.get_by_sku(sku)
    if product is None:
        raise InvalidSku(f"SKU '{sku}' が見つかりません")
    product.reserve(qty)  # ドメインロジックに委譲
    session.commit()
```

### FakeRepositoryを使ったサービス層テスト

```python
# tests/unit/test_services.py
import pytest
from service_layer import services
from tests.fakes import FakeProductRepository
from unittest.mock import MagicMock

def make_fake_repo(*products):
    return FakeProductRepository(list(products))

class FakeSession:
    committed = False
    def commit(self):
        self.committed = True

def test_add_product_persists_to_repo():
    # Arrange
    repo = FakeProductRepository([])
    session = FakeSession()

    # Act
    product_id = services.add_product("SKU-001", "テスト商品", 100, repo, session)

    # Assert
    assert repo.get_by_sku("SKU-001") is not None
    assert session.committed is True

def test_reserve_stock_raises_for_unknown_sku():
    # Arrange
    repo = FakeProductRepository([])
    session = FakeSession()

    # Act / Assert
    with pytest.raises(services.InvalidSku, match="SKU-999"):
        services.reserve_stock("SKU-999", 5, repo, session)

def test_reserve_stock_raises_when_insufficient():
    # Arrange
    from domain.model import Product
    product = Product(sku="SKU-001", name="テスト商品", stock_qty=3)
    repo = FakeProductRepository([product])
    session = FakeSession()

    # Act / Assert
    with pytest.raises(services.InsufficientStock):
        services.reserve_stock("SKU-001", 10, repo, session)
```

**なぜサービス層テストにFakeRepositoryを使うのか？**

| テスト対象 | 速度 | 分離度 | 使用場面 |
|-----------|------|--------|---------|
| ドメインモデル単独 | 最速 | 最高 | ビジネスルールの検証 |
| **サービス層 + Fake** | **高速** | **高い** | **ユースケース全体の検証（主力）** |
| 統合テスト (実DB) | 遅い | 低い | Repository実装の正確性検証 |
| E2Eテスト | 最遅 | なし | フィーチャーの動作確認（機能ごと1本） |

---

## パターン適用判断テーブル

| 状況 | 選択するパターン | 理由 |
|------|-----------------|------|
| ドメインに外部依存がある | Repository Pattern | DBをドメインから隔離 |
| 複数の入口（API/CLI）がある | Service Layer | ロジックの重複排除 |
| サービス層テストが遅い | FakeRepository | DB通信を排除 |
| ドメインクラスにORMコードが混入 | Classical Mapping | DIP適用でORM依存を逆転 |
| 操作がエンティティに属さない | Domain Service関数 | "Not everything has to be an object" |

---

## 相互参照

- **[CA-PYTHON.md](./CA-PYTHON.md)**: Giordani流Clean Architecture全体像（4レイヤー・ABC/Protocol・FastAPI統合）
- **[AP-UOW-AGGREGATES.md](./AP-UOW-AGGREGATES.md)**: Ch5-7 Unit of Work・Aggregates・楽観的並行制御
- **[applying-clean-architecture](../../applying-clean-architecture/SKILL.md)**: DDD戦略パターン・ヘキサゴナルアーキテクチャの全体像

---

## 参考文献

Harry Percival, Bob Gregory. *Architecture Patterns with Python*. O'Reilly Media, 2020.
（別名: Cosmic Python — https://www.cosmicpython.com/ で無料公開）
