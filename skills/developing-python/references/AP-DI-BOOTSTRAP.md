# DI & Bootstrapping（フレームワーク非依存）

Pythonにおけるフレームワーク非依存のDependency Injection（DI）とBootstrapパターンのガイド。Composition RootとBootstrap関数による手動DIを解説する。

> **棲み分け**: このファイルはフレームワーク非依存のDIパターンを扱う。FastAPI固有の `Depends()` / `lifespan` については **[DI-FASTAPI.md](./DI-FASTAPI.md)** を参照。

---

## 手動DIのコアコンセプト

### なぜフレームワークなしのDIが重要か

DIフレームワーク（`injector`, `dependency-injector` 等）は便利だが、以下の問題を引き起こすことがある:

| 問題 | 内容 |
|------|------|
| 依存グラフの隠蔽 | フレームワークが自動解決するため、どこが何に依存しているか不明確になる |
| テスト時の複雑さ | フレームワーク独自のモッキング手法が必要になる |
| デバッグ困難 | 自動解決の失敗が難解なエラーとして現れる |
| フレームワーク結合 | アプリがDIフレームワークに依存する |

**手動DI（Pure DI）の利点:** Pythonコードだけで依存グラフが明示され、テストで差し替えが容易。

---

## Composition Root（コンポジションルート）

### Composition Rootとは

アプリケーション内で「すべての依存関係を組み立てる唯一の場所」。

```
❌ アンチパターン: 依存生成が各クラスに散在
  OrderService → 内部でEmailClient生成
  EmailClient → 内部でSMTPConnection生成

✅ Composition Root: 一箇所で全依存を組み立て
  bootstrap() → EmailClient(smtp) → OrderService(email_client, repo)
```

**Composition Rootの3原則:**

1. **唯一性**: アプリに1つだけ存在する
2. **最外層**: フレームワーク層（`main.py` や `app.py`）に配置する
3. **純粋な組み立て**: ビジネスロジックを含まず、オブジェクトグラフの構築のみ行う

---

## Bootstrap関数パターン

### 基本構造

```python
# bootstrap.py
from typing import Optional
from adapters.notifications import EmailNotificationService, AbstractNotifications
from adapters.repository import SqlAlchemyProductRepository
from services.message_bus import MessageBus
from services import handlers
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

def bootstrap(
    db_url: str = "sqlite:///prod.db",
    notifications: Optional[AbstractNotifications] = None,
    # テスト時にモックを注入できるよう引数として受け取る
) -> MessageBus:
    """
    アプリケーションの依存グラフを構築し、MessageBusを返す。
    これがComposition Root。
    """
    # 1. インフラ依存の構築
    engine = create_engine(db_url)
    get_session = sessionmaker(bind=engine)

    # 2. デフォルト実装の設定
    if notifications is None:
        notifications = EmailNotificationService()

    # 3. ハンドラに依存を注入（functools.partial で引数を束縛）
    import functools
    from services.unit_of_work import SqlAlchemyUnitOfWork

    dependencies = {
        "uow": SqlAlchemyUnitOfWork(get_session),
        "notifications": notifications,
    }

    injected_event_handlers = {
        event_type: [
            functools.partial(handler, **{
                k: v for k, v in dependencies.items()
                if k in handler.__code__.co_varnames
            })
            for handler in handler_list
        ]
        for event_type, handler_list in handlers.EVENT_HANDLERS.items()
    }

    injected_command_handlers = {
        command_type: functools.partial(handler, **{
            k: v for k, v in dependencies.items()
            if k in handler.__code__.co_varnames
        })
        for command_type, handler in handlers.COMMAND_HANDLERS.items()
    }

    # 4. MessageBus組み立てて返却
    return MessageBus(
        event_handlers=injected_event_handlers,
        command_handlers=injected_command_handlers,
    )
```

### シンプルなBootstrap関数（小規模アプリ向け）

```python
# 小規模アプリではより直接的な記述が読みやすい
def bootstrap_simple(
    db_url: str = "sqlite:///prod.db",
    email_host: str = "smtp.example.com",
) -> MessageBus:
    """シンプルなBootstrap（依存が少ない場合）"""
    from adapters.email import SmtpEmailClient
    from adapters.orm import create_db_session
    from services.unit_of_work import SqlAlchemyUnitOfWork

    session_factory = create_db_session(db_url)
    uow = SqlAlchemyUnitOfWork(session_factory)
    email_client = SmtpEmailClient(host=email_host)

    return MessageBus(
        event_handlers={
            OrderPlaced: [
                lambda event: handlers.send_confirmation_email(event, email_client),
            ],
            StockDepleted: [
                lambda event: handlers.notify_warehouse(event, uow),
            ],
        },
        command_handlers={
            PlaceOrder: lambda cmd: handlers.place_order(cmd, uow),
            AllocateStock: lambda cmd: handlers.allocate_stock(cmd, uow),
        },
    )
```

---

## 手動DIパターン集

### パターン1: コンストラクタインジェクション

最も一般的で推奨されるパターン。依存をコンストラクタ引数で受け取る。

```python
from abc import ABC, abstractmethod

class AbstractEmailClient(ABC):
    @abstractmethod
    def send(self, to: str, subject: str, body: str) -> None: ...

class OrderService:
    """注文サービス — 外部依存をコンストラクタで受け取る"""

    def __init__(
        self,
        repo: "AbstractOrderRepository",
        email_client: AbstractEmailClient,
    ) -> None:
        self._repo = repo
        self._email_client = email_client

    def place_order(self, customer_id: str, items: list) -> str:
        order = Order(customer_id=customer_id, items=items)
        self._repo.save(order)
        self._email_client.send(
            to=f"{customer_id}@example.com",
            subject="Order Confirmed",
            body=f"Your order {order.id} has been placed.",
        )
        return order.id
```

### パターン2: partial によるハンドラへの注入

ハンドラ関数に依存を部分適用することで、Message Busが引数なしで呼び出せるようにする。

```python
import functools

# ハンドラ定義（依存を引数で受け取る）
def send_order_email(
    event: OrderPlaced,
    email_client: AbstractEmailClient,  # DIされる依存
) -> None:
    email_client.send(
        to=event.customer_email,
        subject="Order Confirmed",
        body=f"Order {event.order_id} confirmed!",
    )

# Bootstrap時: partial で依存を束縛
email_client = SmtpEmailClient(host="smtp.example.com")
bound_handler = functools.partial(send_order_email, email_client=email_client)

# MessageBusには引数束縛済みのhandlerを登録
event_handlers = {
    OrderPlaced: [bound_handler],
}
```

### パターン3: 環境変数からの設定読み込み

```python
import os
from dataclasses import dataclass

@dataclass(frozen=True)
class AppConfig:
    """アプリケーション設定（環境変数から読み込む）"""
    db_url: str
    smtp_host: str
    smtp_port: int
    redis_url: str

    @classmethod
    def from_env(cls) -> "AppConfig":
        return cls(
            db_url=os.environ.get("DATABASE_URL", "sqlite:///dev.db"),
            smtp_host=os.environ.get("SMTP_HOST", "localhost"),
            smtp_port=int(os.environ.get("SMTP_PORT", "25")),
            redis_url=os.environ.get("REDIS_URL", "redis://localhost:6379"),
        )

# Bootstrap で使用
def bootstrap(config: AppConfig | None = None) -> MessageBus:
    if config is None:
        config = AppConfig.from_env()
    # ... 依存グラフ構築
```

---

## テスト時のDI差し替え

### テスト用Bootstrap関数

本番用Bootstrapとは別に、テスト用のBootstrapを定義する。

```python
# tests/conftest.py
import pytest
from bootstrap import bootstrap
from adapters.notifications import FakeNotificationService
from adapters.repository import FakeUnitOfWork

@pytest.fixture
def fake_uow():
    return FakeUnitOfWork()

@pytest.fixture
def fake_notifications():
    return FakeNotificationService()

@pytest.fixture
def message_bus(fake_uow, fake_notifications):
    """テスト用MessageBus（インメモリ実装を注入）"""
    return bootstrap(
        db_url="sqlite:///:memory:",
        notifications=fake_notifications,
        uow_factory=lambda: fake_uow,
    )
```

### Fake実装パターン

```python
class FakeNotificationService:
    """テスト用の通知サービス（送信内容を記録するだけ）"""

    def __init__(self) -> None:
        self.sent: list[dict] = []

    def send_email(self, to: str, subject: str, body: str) -> None:
        self.sent.append({"type": "email", "to": to, "subject": subject})

    def send_sms(self, to: str, message: str) -> None:
        self.sent.append({"type": "sms", "to": to, "message": message})

# テストでの使用
def test_order_confirmation_email_sent(message_bus, fake_notifications):
    # Arrange & Act
    message_bus.handle(PlaceOrder(customer_id=uuid4(), items=[...]))

    # Assert
    assert len(fake_notifications.sent) == 1
    assert fake_notifications.sent[0]["type"] == "email"
    assert "confirmed" in fake_notifications.sent[0]["subject"].lower()
```

---

## DIパターン選択テーブル

| 状況 | 推奨アプローチ |
|------|--------------|
| 小〜中規模アプリ | 手動DI + Bootstrap関数（このファイルのパターン） |
| FastAPIアプリ | `Depends()` によるDI（[DI-FASTAPI.md](./DI-FASTAPI.md)） |
| Message Bus + Handlers | `functools.partial` による引数束縛 |
| テスト時の差し替え | Bootstrap引数でFake実装を渡す |
| 設定管理 | `AppConfig.from_env()` で環境変数から読み込み |
| DIフレームワーク使用 | 依存グラフが複雑になった場合のみ検討（`dependency-injector` 等） |

---

## 相互参照

- **[DI-FASTAPI.md](./DI-FASTAPI.md)**: FastAPI固有のDI（Depends・lifespan・dependency_overrides）
- **[AP-EVENTS-CQRS.md](./AP-EVENTS-CQRS.md)**: Message Bus（Bootstrap対象のMessageBus実装）
- **[AP-UOW-AGGREGATES.md](./AP-UOW-AGGREGATES.md)**: Unit of Work（Bootstrapで組み立てる対象）
- **[CA-PYTHON.md](./CA-PYTHON.md)**: Clean Architecture全般（フレームワーク層とのDI統合）

---

## 参考文献

- "Architecture Patterns with Python" — Harry Percival, Bob Gregory（O'Reilly Media, 2020）
  - Chapter 13: Dependency Injection (and Bootstrapping)
