# DDD Tactical Patterns × Python Clean Architecture

DDDの戦術的パターン（Value Object・Entity・Aggregate Root）をPythonで実装する際の判断基準とパターン集。
Application Layer（Result pattern・UseCase）とInterface Adapters（Controller/Presenter）の構成も網羅。

> **棲み分け**: このファイルはBuczyński流の戦術的DDD実装に焦点を当てる。
> CA-PYTHON.mdのABC/Protocol基盤と組み合わせて使用すること。

---

## DDD Tactical Patterns 概要

```
[Domain Layer]
  ├── Value Object   ← 値で等価性を判断（不変）
  ├── Entity         ← IDで等価性を判断（可変な状態）
  └── Aggregate Root ← 一貫性境界のゲートキーパー

[Application Layer]
  ├── UseCase        ← ユースケースのオーケストレーター
  └── Result Pattern ← 成功/失敗の型安全な表現

[Interface Adapters]
  ├── Controller     ← 外部入力 → ドメイン形式変換
  └── Presenter      ← ドメイン結果 → 外部形式変換
```

---

## Value Object

### 判断基準

| 特徴 | Value Object | Entity |
|------|-------------|--------|
| 等価性 | 値（全フィールド） | ID（UUID等） |
| 可変性 | 不変（immutable） | 可変（stateあり） |
| 例 | Money, Email, Address | User, Order, Product |
| Pythonの実装 | `@dataclass(frozen=True)` | 通常dataclass + UUID |

### frozen dataclass による実装

```python
from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class Money:
    amount: Decimal
    currency: str

    def __post_init__(self) -> None:
        if self.amount < Decimal("0"):
            raise ValueError(f"金額は0以上でなければなりません: {self.amount}")
        if len(self.currency) != 3:
            raise ValueError(f"通貨コードは3文字でなければなりません: {self.currency}")

    def add(self, other: "Money") -> "Money":
        if self.currency != other.currency:
            raise ValueError(f"異なる通貨は加算できません: {self.currency} vs {other.currency}")
        return Money(amount=self.amount + other.amount, currency=self.currency)

    def multiply(self, factor: Decimal) -> "Money":
        return Money(amount=self.amount * factor, currency=self.currency)


@dataclass(frozen=True)
class EmailAddress:
    value: str

    def __post_init__(self) -> None:
        if "@" not in self.value or "." not in self.value.split("@")[-1]:
            raise ValueError(f"無効なメールアドレス: {self.value}")

    @property
    def domain(self) -> str:
        return self.value.split("@")[1]
```

**ポイント:**
- `frozen=True` でハッシュ可能・辞書のキーとして使用可能
- `__post_init__` でバリデーションを行う（コンストラクタ後に自動実行）
- 変換メソッドは新しいインスタンスを返す（不変性を維持）

---

## Entity

### UUID によるアイデンティティ

```python
from __future__ import annotations
from dataclasses import dataclass, field
from uuid import UUID, uuid4


@dataclass
class ProductId:
    value: UUID = field(default_factory=uuid4)

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, ProductId):
            return NotImplemented
        return self.value == other.value

    def __hash__(self) -> int:
        return hash(self.value)


@dataclass
class Product:
    id: ProductId
    name: str
    price: Money
    _stock: int = field(default=0, repr=False)

    def __eq__(self, other: object) -> bool:
        # Entityの等価性はIDのみで判断（値は無関係）
        if not isinstance(other, Product):
            return NotImplemented
        return self.id == other.id

    def __hash__(self) -> int:
        return hash(self.id)

    def restock(self, quantity: int) -> None:
        if quantity <= 0:
            raise ValueError("在庫追加数は正でなければなりません")
        self._stock += quantity

    def can_fulfill(self, quantity: int) -> bool:
        return self._stock >= quantity
```

**Value Object vs Entity の判断フロー:**

```
「同じ値を持つ2つのオブジェクトは同一か？」
   YES → Value Object（frozen dataclass）
   NO  → Entity（UUID + 通常dataclass）
```

---

## Aggregate Root

### 一貫性境界の設計

Aggregate Rootはトランザクション境界を定義する。**外部からはAggregate Rootのみを操作する**。

```python
from dataclasses import dataclass, field
from typing import Iterator
from uuid import UUID, uuid4


@dataclass
class OrderId:
    value: UUID = field(default_factory=uuid4)


@dataclass
class OrderLine:
    product_id: UUID
    quantity: int
    unit_price: Money

    @property
    def subtotal(self) -> Money:
        from decimal import Decimal
        return self.unit_price.multiply(Decimal(str(self.quantity)))


@dataclass
class Order:  # ← Aggregate Root
    id: OrderId
    customer_id: UUID
    _lines: list[OrderLine] = field(default_factory=list, repr=False)
    _status: str = field(default="draft", repr=False)

    # --- Aggregate境界の強制 ---
    def add_line(self, product_id: UUID, quantity: int, unit_price: Money) -> None:
        """外部からOrderLineを直接作成させない"""
        if self._status != "draft":
            raise ValueError("確定済み注文には明細を追加できません")
        if quantity <= 0:
            raise ValueError("数量は正でなければなりません")
        self._lines.append(OrderLine(product_id, quantity, unit_price))

    def confirm(self) -> None:
        if not self._lines:
            raise ValueError("明細が空の注文は確定できません")
        self._status = "confirmed"

    @property
    def total(self) -> Money:
        if not self._lines:
            return Money(amount=Decimal("0"), currency="JPY")
        result = self._lines[0].subtotal
        for line in self._lines[1:]:
            result = result.add(line.subtotal)
        return result

    @property
    def lines(self) -> Iterator[OrderLine]:
        return iter(self._lines)  # コピーを返してカプセル化を維持
```

### Aggregate 設計の判断テーブル

| 問い | 推奨 |
|------|------|
| 複数Entityを1トランザクションで変更する必要があるか | YES → 同一Aggregateに含める |
| 別のトランザクションで変更可能か | YES → 別Aggregateに分離 |
| IDを通じた参照で十分か | YES → 別Aggregateに分離 |
| Aggregateが大きくなりすぎていないか | Rootを分割して小さく保つ |

---

## Application Layer

### Result Pattern

例外をビジネスロジックのフローに使わない。`Result[T, E]`で成功/失敗を型として表現する。

```python
from dataclasses import dataclass
from typing import Generic, TypeVar

T = TypeVar("T")
E = TypeVar("E")


@dataclass(frozen=True)
class Success(Generic[T]):
    value: T

    def is_success(self) -> bool:
        return True

    def is_failure(self) -> bool:
        return False


@dataclass(frozen=True)
class Failure(Generic[E]):
    error: E

    def is_success(self) -> bool:
        return False

    def is_failure(self) -> bool:
        return True


type Result[T, E] = Success[T] | Failure[E]
```

### UseCase の実装

```python
from typing import Protocol
from uuid import UUID


class OrderRepository(Protocol):
    def find_by_id(self, order_id: UUID) -> Order | None: ...
    def save(self, order: Order) -> None: ...


class InventoryService(Protocol):
    def reserve(self, product_id: UUID, quantity: int) -> bool: ...


@dataclass(frozen=True)
class ConfirmOrderCommand:
    order_id: UUID
    confirmed_by: UUID


@dataclass(frozen=True)
class OrderConfirmedResult:
    order_id: UUID
    total: Money


class ConfirmOrderUseCase:
    """注文確定ユースケース: Controller → UseCase → Presenter フロー"""

    def __init__(
        self,
        order_repo: OrderRepository,
        inventory: InventoryService,
    ) -> None:
        self._order_repo = order_repo
        self._inventory = inventory

    def execute(
        self,
        command: ConfirmOrderCommand,
    ) -> Result[OrderConfirmedResult, str]:
        order = self._order_repo.find_by_id(command.order_id)
        if order is None:
            return Failure(f"注文が見つかりません: {command.order_id}")

        # 在庫予約
        for line in order.lines:
            if not self._inventory.reserve(line.product_id, line.quantity):
                return Failure(f"在庫不足: {line.product_id}")

        try:
            order.confirm()
        except ValueError as e:
            return Failure(str(e))

        self._order_repo.save(order)
        return Success(OrderConfirmedResult(order_id=order.id.value, total=order.total))
```

**UseCase設計の原則:**
- 1 UseCase = 1 ユースケース（SRP）
- 依存はProtocolで注入（DIP）
- ビジネスロジックはEntityに移譲（UseCaseはオーケストレーター）
- 副作用（DB保存等）は最後に実行

---

## Interface Adapters

### Controller → UseCase → Presenter フロー

```
HTTP Request
    ↓
[Controller]     外部入力（dict/JSON）→ Commandオブジェクト変換
    ↓
[UseCase]        ビジネスロジック実行 → Result返却
    ↓
[Presenter]      Result → HTTPレスポンス形式変換
    ↓
HTTP Response
```

### Controller 実装

```python
from dataclasses import dataclass
from uuid import UUID


@dataclass(frozen=True)
class ConfirmOrderRequest:
    """外部入力のスキーマ（Pydantic等でバリデーション）"""
    order_id: str
    confirmed_by: str


class ConfirmOrderController:
    def __init__(self, use_case: ConfirmOrderUseCase) -> None:
        self._use_case = use_case

    def handle(self, request: ConfirmOrderRequest) -> dict:
        # 1. 入力バリデーション & 変換
        try:
            command = ConfirmOrderCommand(
                order_id=UUID(request.order_id),
                confirmed_by=UUID(request.confirmed_by),
            )
        except ValueError:
            return {"status": 400, "error": "無効なUUID形式です"}

        # 2. UseCase実行
        result = self._use_case.execute(command)

        # 3. Presenterに委譲
        presenter = ConfirmOrderPresenter()
        return presenter.present(result)
```

### Presenter & ViewModel 実装

```python
@dataclass(frozen=True)
class ConfirmOrderViewModel:
    """UIが必要とする形式に整形済みのデータ"""
    order_id: str
    total_amount: str
    total_currency: str
    message: str


class ConfirmOrderPresenter:
    def present(
        self,
        result: Result[OrderConfirmedResult, str],
    ) -> dict:
        if isinstance(result, Success):
            vm = ConfirmOrderViewModel(
                order_id=str(result.value.order_id),
                total_amount=str(result.value.total.amount),
                total_currency=result.value.total.currency,
                message="注文を確定しました",
            )
            return {"status": 200, "data": vm.__dict__}
        else:
            return {"status": 422, "error": result.error}
```

### Controller/Presenter 設計の判断テーブル

| 責務 | 置き場所 | 注意 |
|------|---------|------|
| 入力バリデーション（形式） | Controller | ビジネスバリデーションはEntityで |
| 認証・認可チェック | Controller/Middleware | UseCaseに漏らさない |
| エラーメッセージの国際化 | Presenter | ドメインはエラーコードのみ返す |
| ページネーション計算 | Presenter | クエリ条件はControllerで |

---

## ディレクトリ構成例

```
src/
├── domain/
│   ├── models/
│   │   ├── order.py         # Aggregate Root + Entity
│   │   ├── money.py         # Value Object
│   │   └── email_address.py # Value Object
│   └── repositories/
│       └── order_repo.py    # Repository Protocol
├── application/
│   ├── result.py            # Result pattern
│   └── usecases/
│       └── confirm_order.py # UseCase + Command
└── adapters/
    ├── controllers/
    │   └── order_controller.py
    └── presenters/
        └── order_presenter.py
```

---

## 相互参照

- **CA-PYTHON.md** ← CA基盤（ABC/Protocol・4レイヤー構造の全体像）
- **AP-DOMAIN-SERVICE.md** ← Domain Service（複数Aggregateを跨ぐドメインロジック）
- **AP-UOW-AGGREGATES.md** ← Unit of Work（Aggregateトランザクション管理）
- **AP-EVENTS-CQRS.md** ← Domain Events・CQRS（Aggregate変更後のイベント発行）
- **CB-TESTING-CA.md** ← DDD・CA各レイヤーのテスト戦略

---

## 参考文献

- Buczyński, Piotr. *"Clean Architecture in Python"*. Packt Publishing.
  - Ch.4: Value Objects & Entities
  - Ch.5: Aggregates & Application Layer
  - Ch.6: Interface Adapters
