# Clean Architecture × Pythonテスト戦略

レイヤー別テストパターン・テストダブル選択基準・テストピラミッドをPythonで実践するガイド。
DDDのレイヤー（Entity/UseCase/Adapter/Infrastructure）ごとに最適なテスト手法を解説。

> **棲み分け**: このファイルはClean Architecture文脈のテスト戦略に特化。
> 一般的なpytestパターンは `TESTING.md` を、EP-CH13-TESTINGも参照。

---

## テストピラミッド（CA版）

```
         ╔════════════╗
         ║  E2E Tests  ║   少数・遅い・DBあり
         ╠════════════╣
         ║ Integration ║   中程度・Fake実装使用
         ╠════════════╣
         ║  Unit Tests  ║  多数・高速・Mock/Stub
         ╚════════════╝
```

### レイヤー別テスト戦略

| レイヤー | テスト種別 | テストダブル | 実行速度 |
|---------|-----------|------------|---------|
| Entity（Value Object含む） | ユニット | なし | 最高速 |
| UseCase | ユニット | Mock/Stub | 高速 |
| Controller/Presenter | ユニット | Stub（UseCase） | 高速 |
| Repository（Adapter） | 統合 | Fake（in-memory） | 中速 |
| Infrastructure（DB/HTTP） | 統合 | 実際のサービス | 低速 |

---

## Entity・Value Object のユニットテスト

**方針**: テストダブル不要。ビジネスルールのみ検証。

```python
import pytest
from decimal import Decimal
from domain.models.money import Money
from domain.models.order import Order, OrderId, OrderLine
from uuid import uuid4


class TestMoney:
    """Value Objectは全バリデーションと演算を網羅する"""

    def test_有効な金額と通貨コードで生成できる(self) -> None:
        # Arrange
        amount = Decimal("1000")
        currency = "JPY"

        # Act
        money = Money(amount=amount, currency=currency)

        # Assert
        assert money.amount == amount
        assert money.currency == currency

    def test_負の金額はValueErrorを発生させる(self) -> None:
        # Arrange & Act & Assert
        with pytest.raises(ValueError, match="0以上"):
            Money(amount=Decimal("-1"), currency="JPY")

    def test_同一通貨の加算は正しく計算される(self) -> None:
        # Arrange
        a = Money(amount=Decimal("300"), currency="JPY")
        b = Money(amount=Decimal("700"), currency="JPY")

        # Act
        result = a.add(b)

        # Assert
        assert result == Money(amount=Decimal("1000"), currency="JPY")

    def test_異なる通貨の加算はValueErrorを発生させる(self) -> None:
        # Arrange
        jpy = Money(amount=Decimal("100"), currency="JPY")
        usd = Money(amount=Decimal("1"), currency="USD")

        # Act & Assert
        with pytest.raises(ValueError, match="異なる通貨"):
            jpy.add(usd)

    def test_frozen_dataclassは不変である(self) -> None:
        # Arrange
        money = Money(amount=Decimal("100"), currency="JPY")

        # Act & Assert
        with pytest.raises(Exception):  # FrozenInstanceError
            money.amount = Decimal("200")  # type: ignore


class TestOrder:
    """Aggregate Rootは一貫性制約を重点的にテストする"""

    def test_明細追加後に合計金額が正しく計算される(self) -> None:
        # Arrange
        order = Order(id=OrderId(), customer_id=uuid4())
        product_id = uuid4()

        # Act
        order.add_line(product_id, quantity=2, unit_price=Money(Decimal("500"), "JPY"))

        # Assert
        assert order.total == Money(Decimal("1000"), "JPY")

    def test_確定済み注文への明細追加はValueErrorを発生させる(self) -> None:
        # Arrange
        order = Order(id=OrderId(), customer_id=uuid4())
        order.add_line(uuid4(), quantity=1, unit_price=Money(Decimal("100"), "JPY"))
        order.confirm()

        # Act & Assert
        with pytest.raises(ValueError, match="確定済み"):
            order.add_line(uuid4(), quantity=1, unit_price=Money(Decimal("100"), "JPY"))

    def test_空の注文は確定できない(self) -> None:
        # Arrange
        order = Order(id=OrderId(), customer_id=uuid4())

        # Act & Assert
        with pytest.raises(ValueError, match="明細が空"):
            order.confirm()
```

---

## UseCase のユニットテスト（Mock戦略）

**方針**: 外部依存をMock/Stubで差し替え。ユースケースの分岐を全て網羅。

```python
from unittest.mock import MagicMock, create_autospec
from application.usecases.confirm_order import (
    ConfirmOrderCommand,
    ConfirmOrderUseCase,
)
from domain.repositories.order_repo import OrderRepository
from domain.services.inventory import InventoryService
import pytest
from uuid import uuid4


@pytest.fixture
def order_repo() -> OrderRepository:
    return create_autospec(OrderRepository, instance=True)


@pytest.fixture
def inventory_service() -> InventoryService:
    return create_autospec(InventoryService, instance=True)


@pytest.fixture
def use_case(order_repo: OrderRepository, inventory_service: InventoryService) -> ConfirmOrderUseCase:
    return ConfirmOrderUseCase(order_repo=order_repo, inventory=inventory_service)


class TestConfirmOrderUseCase:

    def test_正常な注文確定でSuccessを返す(
        self,
        use_case: ConfirmOrderUseCase,
        order_repo: MagicMock,
        inventory_service: MagicMock,
    ) -> None:
        # Arrange
        order = _make_draft_order_with_line()
        order_repo.find_by_id.return_value = order
        inventory_service.reserve.return_value = True
        command = ConfirmOrderCommand(
            order_id=order.id.value,
            confirmed_by=uuid4(),
        )

        # Act
        result = use_case.execute(command)

        # Assert
        assert result.is_success()
        order_repo.save.assert_called_once_with(order)

    def test_注文が存在しない場合Failureを返す(
        self,
        use_case: ConfirmOrderUseCase,
        order_repo: MagicMock,
    ) -> None:
        # Arrange
        order_repo.find_by_id.return_value = None
        command = ConfirmOrderCommand(order_id=uuid4(), confirmed_by=uuid4())

        # Act
        result = use_case.execute(command)

        # Assert
        assert result.is_failure()
        assert "見つかりません" in result.error

    def test_在庫不足の場合Failureを返し保存しない(
        self,
        use_case: ConfirmOrderUseCase,
        order_repo: MagicMock,
        inventory_service: MagicMock,
    ) -> None:
        # Arrange
        order = _make_draft_order_with_line()
        order_repo.find_by_id.return_value = order
        inventory_service.reserve.return_value = False  # 在庫不足
        command = ConfirmOrderCommand(order_id=order.id.value, confirmed_by=uuid4())

        # Act
        result = use_case.execute(command)

        # Assert
        assert result.is_failure()
        order_repo.save.assert_not_called()  # 保存されていないことを確認
```

---

## Adapter のテスト（Fake戦略）

**方針**: Fakeは本物に近い動作をするin-memory実装。Mockより信頼性が高い。

```python
from typing import dict as Dict
from uuid import UUID
from domain.models.order import Order, OrderId
from domain.repositories.order_repo import OrderRepository


class FakeOrderRepository(OrderRepository):
    """テスト専用のin-memory Repository実装"""

    def __init__(self) -> None:
        self._store: Dict[UUID, Order] = {}

    def find_by_id(self, order_id: UUID) -> Order | None:
        return self._store.get(order_id)

    def save(self, order: Order) -> None:
        self._store[order.id.value] = order

    def count(self) -> int:
        """テスト検証用ヘルパー"""
        return len(self._store)


class TestConfirmOrderUseCaseWithFake:
    """Fakeを使った統合的なUseCaseテスト"""

    def test_注文確定後にRepositoryに保存される(self) -> None:
        # Arrange
        repo = FakeOrderRepository()
        order = _make_draft_order_with_line()
        repo.save(order)

        inventory = FakeInventoryService(available=True)
        use_case = ConfirmOrderUseCase(order_repo=repo, inventory=inventory)
        command = ConfirmOrderCommand(order_id=order.id.value, confirmed_by=uuid4())

        # Act
        result = use_case.execute(command)

        # Assert
        assert result.is_success()
        saved = repo.find_by_id(order.id.value)
        assert saved is not None
```

---

## テストダブル選択基準

### Mock vs Fake vs Stub

| 種別 | 使用場面 | メリット | デメリット |
|------|---------|---------|----------|
| **Mock** | 「呼ばれたか」を検証したい | 設定簡単・呼び出し検証可 | 本物の動作と乖離しやすい |
| **Stub** | 特定の値を返させたい | シンプル | 状態変化を検証できない |
| **Fake** | 本物に近い動作が必要 | 信頼性高・再利用可能 | 実装コストあり |
| **Spy** | 呼び出し記録＋本物の動作 | 非破壊的検証 | 複雑になりやすい |

### 選択フローチャート

```
「外部サービス（DB・API・メール）を依存に持つか？」
    NO  → テストダブル不要（Entity/Value Object）
    YES ↓
「状態の変化（保存・更新）を検証するか？」
    NO  → Stub（return_value設定のみ）
    YES ↓
「本物に近い動作が必要か？」
    NO  → Mock（assert_called_once_with等）
    YES → Fake（in-memory実装）
```

---

## 統合テスト戦略

### Repository の統合テスト（PostgreSQL/SQLite）

```python
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker


@pytest.fixture(scope="session")
def engine():
    """セッション単位でDBエンジンを共有（高速化）"""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    return engine


@pytest.fixture
def session(engine):
    """テストごとにロールバックして分離"""
    connection = engine.connect()
    transaction = connection.begin()
    session = sessionmaker(bind=connection)()
    yield session
    session.close()
    transaction.rollback()
    connection.close()


class TestSQLOrderRepository:

    def test_保存した注文をIDで取得できる(self, session) -> None:
        # Arrange
        repo = SQLOrderRepository(session)
        order = _make_draft_order_with_line()

        # Act
        repo.save(order)
        found = repo.find_by_id(order.id.value)

        # Assert
        assert found is not None
        assert found.id == order.id
```

### 統合テストの分離戦略

| 戦略 | 仕組み | 適用場面 |
|------|-------|---------|
| **Rollback** | 各テスト後にトランザクションをロールバック | 最も高速・DB内部状態のテスト |
| **Truncate** | 各テスト後にテーブルを空にする | 複数トランザクションが必要 |
| **Schema再作成** | 各テストで新しいスキーマを作成 | スキーマ変更のテスト |

---

## pytest fixture 設計パターン

```python
import pytest
from decimal import Decimal
from uuid import uuid4
from domain.models.order import Order, OrderId
from domain.models.money import Money


@pytest.fixture
def sample_money() -> Money:
    return Money(amount=Decimal("1000"), currency="JPY")


@pytest.fixture
def draft_order() -> Order:
    order = Order(id=OrderId(), customer_id=uuid4())
    order.add_line(
        product_id=uuid4(),
        quantity=2,
        unit_price=Money(Decimal("500"), "JPY"),
    )
    return order


@pytest.fixture
def fake_order_repo() -> FakeOrderRepository:
    return FakeOrderRepository()


# conftest.py に配置して複数テストファイルで共有
```

**fixture スコープ選択基準:**

| スコープ | 再利用 | 適用場面 |
|---------|-------|---------|
| `function`（デフォルト） | テストごとに新規 | 状態変化するオブジェクト |
| `class` | クラス内で共有 | セットアップコスト小 |
| `module` | モジュール内で共有 | 読み取り専用データ |
| `session` | セッション全体で共有 | DBエンジン・HTTPクライアント |

---

## CI でのテスト実行設定

```toml
# pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
markers = [
    "unit: ユニットテスト（高速・外部依存なし）",
    "integration: 統合テスト（DB・外部サービスあり）",
    "e2e: E2Eテスト（遅い）",
]

[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*", "*/migrations/*"]

[tool.coverage.report]
fail_under = 80  # ビジネスロジックは100%を目指す
```

```bash
# CI パイプライン例
uv run pytest -m unit          # 高速フィードバック（PR時）
uv run pytest -m integration   # 統合テスト（マージ前）
uv run pytest -m "not e2e"     # E2E除外（日常）
uv run pytest --cov=src        # カバレッジ計測
```

---

## 相互参照

- **CA-PYTHON.md** ← CA基盤（レイヤー構造・依存性ルール全体像）
- **CB-DDD-TACTICAL.md** ← テスト対象のDDD Tactical Patterns
- **AP-UOW-AGGREGATES.md** ← Unit of Work パターンのテスト方法
- **AP-EVENTS-CQRS.md** ← Domain Events のテスト（イベント発行検証）
- **TESTING.md** ← pytest一般テクニック（parametrize・fixture詳細）
- **EP-CH13-TESTING.md** ← Effective Python観点のテストイディオム

---

## 参考文献

- Buczyński, Piotr. *"Clean Architecture in Python"*. Packt Publishing.
  - Ch.8: Testing Clean Architecture
