# Domain Events, Message Bus, Commands & CQRS

Pythonにおけるイベント駆動アーキテクチャの実装ガイド。Domain Events、Message Bus、Commands、CQRS、Event-Driven Architectureを統合的に解説する。

---

## Domain Events（ドメインイベント）

### イベントとは何か

Domain Eventは「ドメイン内で起きた事実」を表すオブジェクト。過去形の名詞句で命名し、不変（immutable）に設計する。

**イベントの本質:**

| 観点 | 内容 |
|------|------|
| 意味 | 「すでに起きたこと」の記録 |
| 変更可能性 | 不変（過去は変えられない） |
| 命名規則 | 過去形（`OrderPlaced`, `StockDepleted`） |
| 起源 | Aggregate内部からのみ発行 |

### dataclassによるEvent定義

```python
from dataclasses import dataclass, field
from datetime import datetime
from uuid import UUID, uuid4

# ベースクラス: すべてのDomain EventはEventを継承
class Event:
    """Domain Eventのマーカーベースクラス"""
    pass

@dataclass(frozen=True)  # frozen=True: 不変性を保証
class OrderPlaced(Event):
    order_id: UUID
    customer_id: UUID
    total_amount: float
    occurred_at: datetime = field(default_factory=datetime.now)

@dataclass(frozen=True)
class StockDepleted(Event):
    product_sku: str
    warehouse_id: str
    occurred_at: datetime = field(default_factory=datetime.now)

@dataclass(frozen=True)
class AllocationConfirmed(Event):
    order_id: UUID
    product_sku: str
    quantity: int
    occurred_at: datetime = field(default_factory=datetime.now)
```

> `frozen=True` を使う理由: 発生した事実は変更不可。イミュータブルなオブジェクトはスレッドセーフかつデバッグしやすい。

### AggregateからのEvent発行

```python
from dataclasses import dataclass, field
from typing import List

@dataclass
class Order:
    order_id: UUID
    items: list
    status: str = "pending"
    events: List[Event] = field(default_factory=list, repr=False)

    def place(self, customer_id: UUID) -> None:
        """注文を確定する"""
        if self.status != "pending":
            raise ValueError(f"Cannot place order in status: {self.status}")

        self.status = "placed"
        total = sum(item.price * item.qty for item in self.items)

        # ドメインイベントをリストに追加（発行はAggregateの外側）
        self.events.append(
            OrderPlaced(
                order_id=self.order_id,
                customer_id=customer_id,
                total_amount=total,
            )
        )
```

**重要:** Aggregateはイベントを `self.events` に蓄積するが、直接ハンドラを呼び出さない。イベントの処理はMessage Busが担当する。

---

## Message Bus（メッセージバス）

### ディスパッチパターン

Message Busはイベントとハンドラのルーティングテーブル。イベント型に対応するハンドラ群を管理し、順次実行する。

```python
from typing import Callable, Type, Union
from collections import defaultdict

# ハンドラの型定義
EventHandler = Callable[[Event], None]
CommandHandler = Callable[["Command"], None]
Message = Union[Event, "Command"]

class MessageBus:
    def __init__(
        self,
        event_handlers: dict[Type[Event], list[EventHandler]],
        command_handlers: dict[Type["Command"], CommandHandler],
    ) -> None:
        self._event_handlers = event_handlers
        self._command_handlers = command_handlers
        self._queue: list[Message] = []

    def handle(self, message: Message) -> None:
        """メッセージをキューに追加して処理する"""
        self._queue.append(message)
        while self._queue:
            current = self._queue.pop(0)
            if isinstance(current, Event):
                self._handle_event(current)
            else:
                self._handle_command(current)

    def _handle_event(self, event: Event) -> None:
        """イベントを対応するすべてのハンドラで処理する"""
        handlers = self._event_handlers.get(type(event), [])
        for handler in handlers:
            try:
                handler(event)
                # ハンドラが新たなEventを生成した場合は再エンキュー
                # （UoWやAggregateから収集する場合はここで追加）
            except Exception as e:
                # イベントは複数ハンドラを持つため、1つの失敗で中断しない
                import logging
                logging.getLogger(__name__).error(
                    "Handler failed for event",
                    extra={"event": type(event).__name__, "error": str(e)},
                )
                raise

    def _handle_command(self, command: "Command") -> None:
        """コマンドを対応するハンドラで処理する（1:1）"""
        handler = self._command_handlers[type(command)]
        handler(command)
```

### ハンドラ登録パターン

```python
# ハンドラ実装例
def send_order_confirmation_email(event: OrderPlaced) -> None:
    """注文確定メールを送信する"""
    # メール送信ロジック（外部サービス呼び出し）
    print(f"Sending confirmation for order {event.order_id}")

def update_inventory_index(event: OrderPlaced) -> None:
    """在庫インデックスを更新する"""
    # 在庫管理システムへの通知
    print(f"Updating inventory for order {event.order_id}")

def notify_warehouse_manager(event: StockDepleted) -> None:
    """倉庫管理者に通知する"""
    print(f"Stock depleted: {event.product_sku} at {event.warehouse_id}")

# Event → Handlers のマッピング（1つのEventに複数Handlerを登録可能）
EVENT_HANDLERS: dict[Type[Event], list[EventHandler]] = {
    OrderPlaced: [
        send_order_confirmation_email,
        update_inventory_index,
    ],
    StockDepleted: [
        notify_warehouse_manager,
    ],
}
```

**設計原則:** 1つのEventに複数のHandlerを持てる（1:N）。Handlerは単一責任の小さな関数として設計する。

---

## Commands & Command Handlers

### Command vs Event の根本的な違い

```
Command: "これをやれ"（命令・意図・未来）
Event:   "これが起きた"（事実・記録・過去）
```

| 観点 | Command | Event |
|------|---------|-------|
| 語尾 | 命令形（`PlaceOrder`, `AllocateStock`） | 過去形（`OrderPlaced`, `StockDepleted`） |
| 送信先 | 1つのHandlerのみ | 複数のHandlerに配信可能 |
| 失敗時 | 例外をスローして処理中断 | ログに記録して継続 |
| 期待 | 処理の成功を期待 | 通知のみ（結果を問わない） |
| 変更可能性 | 却下・変更される可能性あり | 不変（発生した事実） |

### Commandの定義

```python
@dataclass
class PlaceOrder:
    """注文を確定するコマンド"""
    customer_id: UUID
    items: list[dict]  # [{"sku": "...", "qty": 1, "price": 9.99}]

@dataclass
class AllocateStock:
    """在庫を割り当てるコマンド"""
    order_id: UUID
    product_sku: str
    quantity: int

@dataclass
class AddBatch:
    """バッチ（在庫ロット）を追加するコマンド"""
    batch_id: str
    product_sku: str
    qty: int
    eta: datetime | None = None

# CommandもEventと同様にマーカークラスで区別
class Command:
    pass

# 実際の定義
@dataclass
class PlaceOrder(Command):
    customer_id: UUID
    items: list[dict]
```

### Command Handler の実装

```python
from typing import Protocol

class UnitOfWork(Protocol):
    """Unit of Work プロトコル（AP-UOW-AGGREGATES.md参照）"""
    def __enter__(self) -> "UnitOfWork": ...
    def __exit__(self, *args) -> None: ...
    def commit(self) -> None: ...
    orders: "OrderRepository"
    products: "ProductRepository"

def handle_place_order(
    command: PlaceOrder,
    uow: UnitOfWork,
) -> UUID:
    """PlaceOrderコマンドハンドラ"""
    with uow:
        # ビジネスロジックをAggregateに委譲
        order = Order(
            order_id=uuid4(),
            items=command.items,
        )
        order.place(customer_id=command.customer_id)

        uow.orders.add(order)
        uow.commit()

        # Aggregateが蓄積したイベントをMessageBusが後で処理
        return order.order_id

def handle_allocate_stock(
    command: AllocateStock,
    uow: UnitOfWork,
) -> None:
    """AllocateStockコマンドハンドラ"""
    with uow:
        product = uow.products.get(sku=command.product_sku)
        if product is None:
            raise ValueError(f"Product not found: {command.product_sku}")

        product.allocate(
            order_id=command.order_id,
            quantity=command.quantity,
        )
        uow.commit()
```

### Command vs Event の例外処理の違い

```python
# CommandHandler: 例外をそのまま伝播（処理失敗を明示）
def _handle_command(self, command: Command) -> None:
    handler = self._command_handlers[type(command)]
    handler(command)  # 例外はキャッチしない → 呼び出し元に伝播

# EventHandler: 例外をログに記録して継続（通知失敗でビジネス処理を止めない）
def _handle_event(self, event: Event) -> None:
    for handler in self._event_handlers.get(type(event), []):
        try:
            handler(event)
        except Exception:
            logger.exception("Event handler failed", extra={"event": type(event).__name__})
            # 継続（次のHandlerを実行）
```

---

## CQRS（Command Query Responsibility Segregation）

### 読み書きモデルの分離

CQRSは読み取り（Query）と書き込み（Command）の責務を分離するパターン。複雑なドメインモデルで、読み取りの柔軟性を高めるために使用する。

```
Write Side: Command → Handler → Aggregate → Event → Repository → DB
Read Side:  Query → Read Model → DB（Raw SQLで直接取得）
```

**分離のメリット:**

| 観点 | Write Side | Read Side |
|------|-----------|-----------|
| 最適化対象 | 整合性・ビジネスルール適用 | クエリ性能・柔軟なプロジェクション |
| 使用技術 | ORM + Aggregate | Raw SQL or 軽量クエリ |
| 複雑さ | ドメインモデルを守る | シンプルなdictやdataclassで返す |

### ReadモデルはRaw SQLで実装する

ORMの透明なクエリでは、N+1問題や不要なJoinが発生しやすい。ReadモデルはRaw SQLで直接最適化する。

```python
from typing import Any
import sqlite3  # 実際はSQLAlchemy Core / asyncpgも可

def get_order_summary(
    order_id: UUID,
    connection: sqlite3.Connection,
) -> dict[str, Any] | None:
    """注文サマリーをReadモデルで取得（Raw SQL）"""
    cursor = connection.execute(
        """
        SELECT
            o.id          AS order_id,
            o.status      AS status,
            c.name        AS customer_name,
            c.email       AS customer_email,
            COUNT(oi.id)  AS item_count,
            SUM(oi.price * oi.quantity) AS total_amount
        FROM orders o
        JOIN customers c ON c.id = o.customer_id
        JOIN order_items oi ON oi.order_id = o.id
        WHERE o.id = ?
        GROUP BY o.id, c.name, c.email
        """,
        [str(order_id)],
    )
    row = cursor.fetchone()
    if row is None:
        return None

    return {
        "order_id": row[0],
        "status": row[1],
        "customer_name": row[2],
        "customer_email": row[3],
        "item_count": row[4],
        "total_amount": row[5],
    }

```

### 結果整合性の設計

CQRSではWriteモデルへの反映直後にReadモデルが最新でない場合がある（結果整合性）。

```python
# Write Side: コマンド処理後にイベントを発行
def handle_place_order(command: PlaceOrder, uow: UnitOfWork) -> UUID:
    with uow:
        order = Order(order_id=uuid4(), items=command.items)
        order.place(customer_id=command.customer_id)
        uow.orders.add(order)
        uow.commit()
        return order.order_id
    # → OrderPlaced イベントが非同期に処理され、Readモデル更新

# Read Side: Readモデル更新ハンドラ（イベント駆動）
def update_order_read_model(event: OrderPlaced, connection) -> None:
    """OrderPlacedイベントでReadモデルを更新する"""
    connection.execute(
        "INSERT INTO order_summaries (order_id, status, total_amount) VALUES (?, ?, ?)",
        [str(event.order_id), "placed", event.total_amount],
    )
```

**結果整合性の判断基準:**

| 状況 | 設計 |
|------|------|
| ユーザーが即座に更新結果を確認する必要がある | 同期Readモデル更新 |
| 大量書き込みでReadモデル更新が遅延可能 | 非同期（イベント駆動）更新 |
| マイクロサービス間のRead/Write分離 | 非同期 + イベントストリーム |

---

## Event-Driven Architecture（EDA）

### マイクロサービス間のイベント連携

内部のMessage Busを外部サービスに拡張することで、マイクロサービス間の疎結合な連携を実現する。

```
[Order Service] ──→ OrderPlaced Event ──→ [Message Broker]
                                               │
                    ┌──────────────────────────┘
                    ▼
          [Inventory Service] → 在庫確認・更新
          [Email Service]     → 確認メール送信
          [Analytics Service] → 売上集計
```

### 外部イベントパブリッシャーのパターン

```python
from abc import ABC, abstractmethod
import json

class EventPublisher(ABC):
    """外部イベント発行の抽象インターフェース"""

    @abstractmethod
    def publish(self, channel: str, event: Event) -> None:
        ...

class RedisEventPublisher(EventPublisher):
    """Redisを使った外部イベント発行"""

    def __init__(self, redis_client) -> None:
        self._redis = redis_client

    def publish(self, channel: str, event: Event) -> None:
        payload = {
            "event_type": type(event).__name__,
            "data": {
                k: str(getattr(event, k))
                for k in event.__dataclass_fields__
            },
        }
        self._redis.publish(channel, json.dumps(payload))
```

### 内部 vs 外部 イベントの使い分け

| 観点 | 内部イベント | 外部イベント |
|------|------------|------------|
| 使用場所 | Message Bus内のみ | マイクロサービス間 |
| スキーマ変更 | 自由に変更可能 | 後方互換性が必要 |
| 型定義 | Python dataclass | JSON Schema or Protobuf |
| 処理保証 | 同期・インメモリ | Broker（Redis/Kafka等）でAt-least-once |

---

## パターン選択テーブル

| 状況 | 推奨パターン |
|------|------------|
| 副作用を関心事の外に出したい | Domain Events + Message Bus |
| 処理の意図を明確にしたい | Commands（Eventとの使い分け） |
| 読み取り性能を最適化したい | CQRS（Raw SQL Read Model） |
| 複数サービスに変更を通知したい | Event-Driven Architecture |
| 外部サービスの概念を内部に持ち込みたくない | Anti-Corruption Layer |
| 1:Nのハンドラ連鎖が必要 | Message Bus（Event） |
| 1:1の処理が必要、失敗を明示したい | Message Bus（Command） |

---

## 相互参照

- **[AP-DOMAIN-SERVICE.md](./AP-DOMAIN-SERVICE.md)**: Domain Service、Value Object、ドメインモデル設計
- **[AP-UOW-AGGREGATES.md](./AP-UOW-AGGREGATES.md)**: Unit of Work、Aggregate、整合性境界
- **[AP-DI-BOOTSTRAP.md](./AP-DI-BOOTSTRAP.md)**: DI & Bootstrapping（Message Busの組み立て方法）
- **[CA-PYTHON.md](./CA-PYTHON.md)**: Clean Architecture全般（レイヤー構造・テスト戦略）
- **[DI-FASTAPI.md](./DI-FASTAPI.md)**: FastAPI固有のDI（Depends・lifespan）
- **[applying-clean-architecture](../../applying-clean-architecture/SKILL.md)**: Clean Architecture原則

---

## 参考文献

- "Architecture Patterns with Python" — Harry Percival, Bob Gregory（O'Reilly Media, 2020）
  - Chapter 8: Events and the Message Bus
  - Chapter 9: Going to Town on the Message Bus
  - Chapter 10: Commands and Command Handler
  - Chapter 11: Event-Driven Architecture: Using Events to Integrate Microservices
  - Chapter 12: Command-Query Responsibility Segregation (CQRS)
