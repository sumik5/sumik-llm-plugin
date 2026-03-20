# Cosmic Python Part 1後半: UoW・Aggregates・TDD戦略

Unit of WorkでService LayerをDBから完全分離し、
Aggregateで一貫性境界を定義し、楽観的ロックで並行性を制御する。

---

## Ch5: TDD High Gear / Low Gear

サービス層が整ったら、**テストの重心をサービス層に移す**ことでテストを安定化できる。

### テストピラミッド戦略

```
          /\
         /E2E\      ← 機能ごと1本（最小限）
        /------\
       / Service \  ← ユースケースの主力テスト（エッジケース網羅）
      /  Layer   \
     /------------\
    / Domain Model \  ← ビジネスルールの核心だけ残す
   /----------------\
```

**High Gear（高速ギア）= サービス層テスト:**
- FakeRepositoryを使い、プリミティブ型だけで記述
- ドメインオブジェクトを直接触らない
- ユースケースの全パスを網羅する主力

**Low Gear（低速ギア）= ドメインモデルテスト:**
- 複雑なビジネスロジックの核心だけ残す
- サービス層でカバーできたテストは積極的に削除してよい

```python
# ✅ High Gear: サービス層テスト — プリミティブ型のみ
def test_reserve_stock_decrements_stock():
    repo, session = FakeProductRepository([]), FakeSession()
    services.add_product("WIDGET", "ウィジェット", 50, repo, session)

    services.reserve_stock("WIDGET", 10, repo, session)

    product = repo.get_by_sku("WIDGET")
    assert product.stock_qty == 40

# ✅ Low Gear: ドメインテスト — 複雑なビジネスルールのみ
def test_product_cannot_reserve_more_than_stock():
    product = Product(sku="WIDGET", name="ウィジェット", stock_qty=5)
    with pytest.raises(InsufficientStock):
        product.reserve(10)
```

### FakeRepository の改良: クラスメソッドで fixture を簡潔に

```python
class FakeProductRepository(AbstractProductRepository):
    def __init__(self, products: list[Product]) -> None:
        self._data: set[Product] = set(products)

    def add(self, product: Product) -> None:
        self._data.add(product)

    def get_by_sku(self, sku: str) -> Optional[Product]:
        return next((p for p in self._data if p.sku == sku), None)

    def get(self, product_id) -> Optional[Product]:
        return next((p for p in self._data if p.id == product_id), None)

    @classmethod
    def with_product(cls, sku: str, name: str, qty: int) -> "FakeProductRepository":
        return cls([Product(sku=sku, name=name, stock_qty=qty)])
```

---

## Ch6: Unit of Work Pattern

### 問題: Service LayerがDBセッションを直接知っている

```python
# ❌ サービスがセッション管理を知っている状態
def reserve_stock(sku, qty, repo, session):   # session が引数に必要
    product = repo.get_by_sku(sku)
    product.reserve(qty)
    session.commit()  # サービスがコミットの責任を持つ
```

**課題:** API層がセッション・リポジトリ・サービスという3つのレイヤーに直接依存する。

### 解決: Unit of Work — アトミック操作の抽象化

UoWはRepositoryとトランザクション管理を一体化したオブジェクト。
Pythonの**コンテキストマネージャ (`with` 文)** で自然に実装できる。

```python
# domain/unit_of_work.py — 抽象UoW
import abc
from domain.ports import AbstractProductRepository

class AbstractUnitOfWork(abc.ABC):
    products: AbstractProductRepository

    def __enter__(self) -> "AbstractUnitOfWork":
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        # with ブロックを例外で抜けた場合は自動ロールバック
        if exc_type is not None:
            self.rollback()

    @abc.abstractmethod
    def commit(self) -> None:
        raise NotImplementedError

    @abc.abstractmethod
    def rollback(self) -> None:
        raise NotImplementedError
```

```python
# infrastructure/unit_of_work.py — SQLAlchemy実装
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy import create_engine
from domain.unit_of_work import AbstractUnitOfWork
from infrastructure.repository import SqlAlchemyProductRepository
import config

DEFAULT_FACTORY = sessionmaker(bind=create_engine(config.get_db_uri()))

class SqlAlchemyUnitOfWork(AbstractUnitOfWork):
    def __init__(self, session_factory=DEFAULT_FACTORY) -> None:
        self._session_factory = session_factory

    def __enter__(self) -> "SqlAlchemyUnitOfWork":
        self._session: Session = self._session_factory()
        self.products = SqlAlchemyProductRepository(self._session)
        return super().__enter__()

    def __exit__(self, *args) -> None:
        super().__exit__(*args)
        self._session.close()  # セッションを確実に閉じる

    def commit(self) -> None:
        self._session.commit()

    def rollback(self) -> None:
        self._session.rollback()
```

### FakeUnitOfWork: UoWをフェイクにしてテストをさらに簡潔に

```python
# tests/fakes.py
from domain.unit_of_work import AbstractUnitOfWork
from tests.fakes import FakeProductRepository

class FakeUnitOfWork(AbstractUnitOfWork):
    def __init__(self) -> None:
        self.products = FakeProductRepository([])
        self.committed = False

    def commit(self) -> None:
        self.committed = True

    def rollback(self) -> None:
        pass  # フェイクなので何もしない
```

**UoW導入後のサービス層:**

```python
# service_layer/services.py（UoW版）
from domain.unit_of_work import AbstractUnitOfWork
from domain.model import Product, InsufficientStock, InvalidSku

def add_product(
    sku: str, name: str, initial_stock: int,
    uow: AbstractUnitOfWork,
) -> str:
    with uow:
        product = Product(sku=sku, name=name, stock_qty=initial_stock)
        uow.products.add(product)
        uow.commit()
        return str(product.id)

def reserve_stock(
    sku: str, qty: int,
    uow: AbstractUnitOfWork,
) -> None:
    with uow:
        product = uow.products.get_by_sku(sku)
        if product is None:
            raise InvalidSku(f"SKU '{sku}' が見つかりません")
        product.reserve(qty)
        uow.commit()
```

**UoW版テスト — セッションもリポジトリも引数不要:**

```python
def test_add_product_commits_uow():
    # Arrange
    uow = FakeUnitOfWork()

    # Act
    services.add_product("GADGET", "ガジェット", 30, uow)

    # Assert
    assert uow.products.get_by_sku("GADGET") is not None
    assert uow.committed is True  # コミットが呼ばれたことも検証できる

def test_reserve_stock_rollbacks_on_error():
    # Arrange
    uow = FakeUnitOfWork()
    services.add_product("GADGET", "ガジェット", 5, uow)
    uow.committed = False  # リセット

    # Act / Assert — 在庫不足は例外、コミットされない
    with pytest.raises(InsufficientStock):
        services.reserve_stock("GADGET", 100, uow)

    assert uow.committed is False
```

### UoWとFakeRepositoryの関係

```
FakeUnitOfWork
  └── FakeProductRepository  ← 内部で保持。密結合でOK（協調者関係）

SqlAlchemyUnitOfWork
  └── SqlAlchemyProductRepository  ← 同一セッションを共有
```

**「自分が所有しないものをモックしない」原則:**
- ❌ SQLAlchemy `Session` を直接モック → Sessionの複雑な内部に依存
- ✅ 自作の `AbstractUnitOfWork` をフェイク → シンプルで変更に強い

---

## Ch7: Aggregates と一貫性境界

### 問題: 複数エンティティへの並行アクセスで整合性が壊れる

複雑なドメインモデルでは、誰が何を変更できるか不明確になる。
特にコレクションを扱う場合、複数のリクエストが同時に同じデータを変更するリスクがある。

### Aggregate: 一貫性境界を持つエンティティのクラスター

```
Aggregate = ルートエンティティ + 管理下のエンティティ/値オブジェクトの集合

規則:
1. 外部からはルートエンティティ経由でのみアクセス
2. Aggregateの内部は1つのトランザクションで変更される
3. Aggregate間の参照はIDのみ（オブジェクト参照禁止）
```

**Aggregateルートの例:**

```python
# domain/model.py
from dataclasses import dataclass, field
from typing import List
import uuid

@dataclass(frozen=True)
class OrderLine:
    order_id: str
    sku: str
    qty: int

@dataclass
class StockBatch:
    reference: str
    sku: str
    available_qty: int

    def can_fulfill(self, line: OrderLine) -> bool:
        return self.sku == line.sku and self.available_qty >= line.qty

    def allocate(self, line: OrderLine) -> None:
        if not self.can_fulfill(line):
            raise InsufficientStock(f"{self.sku} の在庫不足")
        self.available_qty -= line.qty


class SkuProduct:
    """Aggregate Root — SKU単位の在庫管理。BatchはこのAggregate経由でのみ変更可能。"""

    def __init__(self, sku: str, batches: List[StockBatch]) -> None:
        self.sku = sku
        self.batches = batches
        self.version_number: int = 0  # 楽観的ロック用（後述）

    def allocate(self, line: OrderLine) -> str:
        """注文明細を割り当て可能なバッチに振り向ける"""
        if line.sku != self.sku:
            raise InvalidSku(f"SKU不一致: {line.sku} vs {self.sku}")

        available = [b for b in self.batches if b.can_fulfill(line)]
        if not available:
            raise InsufficientStock(f"SKU {self.sku} の在庫不足")

        # 在庫が多い順に割り当て（シンプルな戦略）
        chosen = max(available, key=lambda b: b.available_qty)
        chosen.allocate(line)
        self.version_number += 1  # バージョンをインクリメント
        return chosen.reference

    def add_batch(self, batch: StockBatch) -> None:
        self.batches.append(batch)
```

### Aggregate選択の判断テーブル

| 候補 | 評価 | 結果 |
|------|------|------|
| `Warehouse`（倉庫） | 全在庫を1トランザクション → 粒度が大きすぎる | ❌ |
| `StockBatch`（バッチ） | 同SKUを同時変更できない → 粒度が小さすぎる | ❌ |
| `SkuProduct`（SKU単位） | SKUごとに独立したロック → 適切な粒度 | ✅ |

**原則:** Aggregateは**できるだけ小さく**。小さいほどロック競合が少ない。

---

## 楽観的並行制御 (Optimistic Concurrency)

### 問題: 2つのリクエストが同時に同じAggregate を更新する

```
リクエストA: 在庫100を読み込み → 10予約 → 90で保存
リクエストB: 在庫100を読み込み → 15予約 → 85で保存（Aの更新を上書き！）

結果: 在庫85（正しくは75）
```

### 解決: バージョン番号による楽観的ロック

悲観的ロック（SELECT FOR UPDATE）は並行性を大幅に下げる。
楽観的ロックは「競合はめったに起きない」という前提で、**競合を検知してリトライ**する。

```python
# Aggregateにバージョン番号を持たせる
class SkuProduct:
    def __init__(self, sku: str, batches: list, version_number: int = 0) -> None:
        self.sku = sku
        self.batches = batches
        self.version_number = version_number  # DBから読み込み時のバージョン

    def allocate(self, line: OrderLine) -> str:
        ...
        self.version_number += 1  # 変更のたびにインクリメント
        return chosen.reference
```

**SQLAlchemyの `version_id_col` で自動化:**

```python
# Classical Mappingで version_id_col を指定するだけ
mapper_registry.map_imperatively(
    model.SkuProduct,
    sku_products_table,
    version_id_col=sku_products_table.c.version_number,
    # UPDATEに WHERE version_number=:old_version が自動付与される
)
```

**競合時:** `WHERE version_number=1` が一致しない → `StaleDataError` 発生 → リトライ or エラーレスポンス

**楽観的 vs 悲観的ロック:**

| 観点 | 楽観的 | 悲観的 |
|------|--------|--------|
| 競合が少ない | ✅ 高スループット | ❌ 不要な待機 |
| 競合が多い | ❌ 多数リトライ | ✅ 整然と待機 |
| デッドロック | なし | あり |
| 推奨 | 一般的なWebアプリ | 金融・厳密な在庫管理 |

---

## UoW + Repository + Aggregate の連携

```python
# 全パターンが連携する最終形
def allocate_order(
    order_id: str,
    sku: str,
    qty: int,
    uow: AbstractUnitOfWork,
) -> str:
    with uow:
        # Repository経由でAggregateを取得
        product = uow.products.get_by_sku(sku)
        if product is None:
            raise InvalidSku(f"SKU '{sku}' が存在しません")

        # Aggregateのメソッドで変更（内部BatchへのアクセスはAggregate経由）
        line = OrderLine(order_id=order_id, sku=sku, qty=qty)
        batch_ref = product.allocate(line)

        # UoWでトランザクションをコミット（version_numberも自動更新）
        uow.commit()
        return batch_ref
```

---

## パターン選択フローチャート

```
複数のエンティティが協調する？
  YES → Aggregateを設計する
    ↓
  粒度はどれくらいか？
    小さすぎる（1エンティティ）→ ユースケースを見直す
    大きすぎる（全エンティティ）→ 一貫性要件を見直す
    適切 ✅ → Aggregate Root を定義

  NO → ドメインサービス関数 or 単独エンティティ

並行リクエストがある？
  YES + 競合が少ない → 楽観的ロック（version_number）
  YES + 競合が多い  → 悲観的ロック（SELECT FOR UPDATE）
  NO              → ロック不要
```

---

## まとめ: 3パターンの協調

| パターン | 解決する問題 | Pythonの実装技法 |
|---------|-------------|----------------|
| **Unit of Work** | サービス層をDBから分離 | `__enter__`/`__exit__` コンテキストマネージャ |
| **Aggregate** | 一貫性境界の明確化 | Rootエンティティがメソッドを公開 |
| **楽観的ロック** | 並行更新の競合検知 | `version_number` + SQLAlchemy `version_id_col` |

---

## 相互参照

- **[AP-DOMAIN-SERVICE.md](./AP-DOMAIN-SERVICE.md)**: Ch1-4 ドメインモデリング・Repository・Service Layer・FakeRepository
- **[CA-PYTHON.md](./CA-PYTHON.md)**: Giordani流Clean Architecture（依存性ルール・4レイヤー実装）
- **[applying-clean-architecture](../../applying-clean-architecture/SKILL.md)**: DDD戦略パターン・境界コンテキスト

---

## 参考文献

Harry Percival, Bob Gregory. *Architecture Patterns with Python*. O'Reilly Media, 2020.
（別名: Cosmic Python — https://www.cosmicpython.com/ で無料公開）
