# コード構成と機能標準

Pythonプロジェクトにおけるコード構成・認知負荷管理・データ契約・可観測性の実践基準。
チームが意識的に選択すべき標準を網羅する。

---

## コード構成戦略

### マルチドメインパッケージ設計

組織が複数の機能ドメインを持つ場合、トップレベル名前空間でコードの所有者を明確にする。

```
myco/                    # 組織固有の名前空間（第三者コードと区別）
  customers/             # ドメインごとのサブパッケージ
    __init__.py
    models.py
  employees/
    __init__.py
  orders/
    __init__.py
  products/
    __init__.py
  core_data/             # 共有データ型・基底クラス
    __init__.py
    base.py
```

**利点:**
- `from myco.customers import Customer` のように明示的にインポート可能
- 組織のコードと第三者パッケージを明確に区別できる
- ドメイン単位でのインポート（`from myco import customers`）も可能

### `__init__.py` による公開APIの制御

`__init__.py` でパッケージの公開インターフェースを明示的に定義する。

```python
# myco/customers/__init__.py
from .models import Customer, Address
from .services import CustomerService

__all__ = ["Customer", "Address", "CustomerService"]
```

| 設計要素 | 効果 |
|---------|------|
| `__all__` 定義 | `from package import *` で公開される名前を制御 |
| 実装の隠蔽 | モジュール内部の詳細を外部に露出させない |
| インターフェースの安定性 | 内部リファクタリング時に呼び出し元への影響を最小化 |

### 共有コードの管理判断基準

| 状況 | 推奨アプローチ |
|------|--------------|
| 2つ以上のドメインで同じロジックが必要 | `core_data` など共通パッケージに移動 |
| 1ドメインのみで使用 | そのドメイン内に留める（早すぎる抽象化を避ける） |
| 外部公開予定のユーティリティ | 独立パッケージとして管理 |

### namespace package の活用

`__init__.py` なしでも名前空間パッケージとして機能する（Python 3.3+）。
大規模組織でリポジトリ分割しながら統一名前空間を維持する際に有効。

```python
# __init__.py が不要（PEP 420 namespace packages）
# 複数リポジトリにまたがる myco.* のインポートが可能
```

---

## 認知負荷の管理

### 属性 vs プロパティの使い分け基準

| 使い分け基準 | 単純属性 (`self.x = value`) | 正式プロパティ (`@property`) |
|------------|--------------------------|---------------------------|
| 型・値の検証が必要 | ❌ | ✅ |
| 設定時に副作用がある | ❌ | ✅ |
| インターフェース契約を強制したい | ❌ | ✅ |
| 削除制御が必要 | ❌ | ✅ |
| シンプルなデータ保持のみ | ✅ | ❌（コストが高い） |

```python
class Person:
    def __init__(self, family_name: str, given_name: str):
        # プロパティを通じた型安全な初期化
        self.family_name = family_name  # setterが呼ばれる
        self.given_name = given_name

    @property
    def family_name(self) -> str:
        return self._family_name

    @family_name.setter
    def family_name(self, value: str) -> None:
        if not isinstance(value, str):
            raise TypeError(
                f"{self.__class__.__name__}.family_name expects str, "
                f"got {type(value).__name__}"
            )
        self._family_name = value

    @family_name.deleter
    def family_name(self) -> None:
        if hasattr(self, "_family_name"):
            del self._family_name
```

**コスト試算:** プロパティは単純属性に比べて1プロパティあたり約15〜20行の追加コード。
7プロパティのクラスで130行程度の増加。型安全性・テスト容易性との兼ね合いで判断する。

### 関数・メソッドサイズの最適化

**考慮すべき要素:**

| 要素 | 影響 |
|------|------|
| 小さい関数に分割 | テストが容易になるが、関数数が増加する |
| 大きな関数を維持 | 読み進めるコンテキスト量が増加する |
| サブ関数への委譲 | 行数は減るが、呼び出しスタックが深くなる |

**判断指標:**
- 人間の短期記憶の限界は **7±2 項目**。1関数内で追跡すべき状態がこれを超えたら分割を検討
- 1つの関数が1つの責任のみを持つ（SRP）
- 一連の処理をサブ処理に委譲する場合、委譲された関数名で「何をしているか」が明確になること

### 命名規則が生む認知負荷削減効果

```python
# ❌ 認知負荷が高い（名前から意図が読めない）
def colss(c_id):
    c = gc(c_id)
    ods = gc_o(c)
    ss = {}
    for o in ods:
        if o.shipper == 'USPS':
            ss[o.oid] = check_usps(o)
    return ss

# ✅ 認知負荷が低い（コード自体が仕様を語る）
def collect_shipping_statuses(customer_id: str) -> dict[str, dict]:
    customer = get_customer(customer_id)
    orders = get_customer_orders(customer)
    shipping_statuses: dict[str, dict] = {}
    for order in orders:
        order_id = order.order_id
        if order.shipper == "USPS":
            shipping_statuses[order_id] = check_usps(order)
    return shipping_statuses
```

**スコープの境界意識:** 同名変数は異なる関数内で独立したスコープを持つ。
comprehension内変数は外部スコープを汚染しない（Python 3以降）。

---

## データ契約

### Design by Contract の原則

**データ契約**とは、データ構造のフォーマット・要件・制約を強制的に定義したもの。
以下3要素でコードの信頼性を高める:

| 要素 | 定義 | Python実装 |
|------|------|-----------|
| 前条件（Precondition） | 関数呼び出し前に満たすべき条件 | 引数の型・値チェック |
| 後条件（Postcondition） | 関数実行後に保証される条件 | 戻り値の検証 |
| 不変条件（Invariant） | オブジェクトの状態として常に真であるべき条件 | プロパティsetter内での検証 |

### Python実装パターン

#### パターン1: `typeguard` デコレータ（アノテーションと連携）

```python
from __future__ import annotations
from typeguard import typechecked

@typechecked
class Customer:
    def __init__(
        self,
        customer_id: str,
        given_name: str,
        family_name: str,
        email: str | None = None,
    ) -> None:
        self.customer_id = customer_id
        self.given_name = given_name
        self.family_name = family_name
        self.email = email
```

```python
# 無効な型は即座にエラー（早期失敗）
Customer(customer_id=123, given_name="Havelock", family_name="Vetinari")
# TypeCheckError: argument "customer_id" (int) is not an instance of str
```

#### パターン2: `dataclasses` による軽量データ契約

```python
from dataclasses import dataclass, field
from typing import ClassVar

@dataclass
class OrderItem:
    product_id: str
    quantity: int
    unit_price: float
    max_quantity: ClassVar[int] = 999

    def __post_init__(self) -> None:
        if self.quantity <= 0:
            raise ValueError(f"quantity must be positive, got {self.quantity}")
        if self.quantity > self.max_quantity:
            raise ValueError(f"quantity exceeds max ({self.max_quantity})")
        if self.unit_price < 0:
            raise ValueError(f"unit_price cannot be negative")
```

#### パターン3: `Pydantic` による外部データ検証（API境界など）

```python
from pydantic import BaseModel, EmailStr, field_validator

class CustomerRequest(BaseModel):
    customer_id: str
    given_name: str
    family_name: str
    email: EmailStr | None = None

    @field_validator("given_name", "family_name")
    @classmethod
    def must_not_be_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("名前は空にできません")
        return v.strip()
```

### ランタイム型チェック vs 静的型チェックの判断基準

| 状況 | 推奨アプローチ |
|------|--------------|
| 外部入力（APIリクエスト、ファイル読み込み等） | ランタイム検証必須（Pydantic推奨） |
| オブジェクト指向の公開インターフェース | プロパティsetter + typeguard |
| 内部ヘルパー関数（信頼できる呼び出し元） | 静的型チェックのみ（mypy/pyright） |
| コスト重視の実行環境（大量リクエスト） | 早期失敗でリソース浪費を防ぐためランタイム検証 |
| duck-typingが適切な汎用ユーティリティ | 型チェックなし、try/exceptで対応 |

---

## 可観測性

### ロギング設計の基本方針

```python
import logging
import os
import pprint

# モジュールレベルのlogger取得（階層的設定が可能）
logger = logging.getLogger(__name__)
```

**ログレベルの使い分け基準:**

| レベル | 用途 | 例 |
|--------|------|-----|
| `CRITICAL` | コード継続不能の致命的エラー | DBへの接続が完全に失敗 |
| `ERROR` | 重大だが回復可能なエラー | 特定リクエストの処理失敗 |
| `WARNING` | 予期しない状態、将来的な問題の予兆 | キャッシュミス率の上昇 |
| `INFO` | 正常動作のチェックポイント | 関数呼び出し開始・完了 |
| `DEBUG` | 開発者向けの詳細情報 | 中間データ構造の内容 |

### ロギングポリシーのテンプレート

```python
def process_order(order_id: str) -> dict:
    # エントリポイントはINFOでログ
    logger.info(f"{__name__}::process_order called")
    logger.debug(f"order_id={order_id!r}")

    try:
        # 処理チェックポイント
        logger.info("Fetching order data")
        order = fetch_order(order_id)

        logger.debug(pprint.pformat({"order": order}))

        result = _execute_order_logic(order)

    except ValueError as error:
        # 回復可能なエラー
        logger.error(
            f"{__name__}::process_order encountered "
            f"{error.__class__.__name__}: {error}",
            exc_info=error,
        )
        raise
    except Exception as error:
        # 致命的エラー（スタックトレース付き）
        logger.critical(
            f"{__name__}::process_order raised "
            f"{error.__class__.__name__}: {error}",
            exc_info=error,
        )
        raise
    else:
        logger.debug(f"result={pprint.pformat(result)}")
        logger.info(f"{__name__}::process_order completed successfully")
        return result
```

### 構造化ロギングパターン（JSON出力対応）

```python
import json
import logging

class StructuredLogger:
    def __init__(self, name: str) -> None:
        self._logger = logging.getLogger(name)

    def info(self, message: str, **context) -> None:
        self._logger.info(json.dumps({
            "message": message,
            "level": "INFO",
            **context,
        }))

    def error(self, message: str, error: Exception, **context) -> None:
        self._logger.error(json.dumps({
            "message": message,
            "level": "ERROR",
            "error_type": type(error).__name__,
            "error_detail": str(error),
            **context,
        }))

# 使用例
slogger = StructuredLogger(__name__)
slogger.info("Order processed", order_id="ORD-001", customer_id="CUST-42")
```

### デバッグ容易性を高める設計

| 設計要素 | 実装 |
|---------|------|
| 関数へのエントリ記録 | `logger.info(f"{__name__}::{func_name} called")` |
| 状態スナップショット | `logger.debug(pprint.pformat(locals()))` |
| エラー詳細の保持 | `exc_info=error` でスタックトレースを含める |
| 意味のあるエラーメッセージ | 何が、どこで、なぜ失敗したかを明記する |

---

## コードとドキュメントの関係

### 「良いコードは自己文書化すべきか」という問い

**自己文書化コードが成立する条件:**

1. すべての識別子（変数・引数・関数・クラス名）が、そのコンテキスト内で明確な意味を持つ
2. チームが問題ドメインの知識を共有している
3. 「なぜ」その実装になったかが、コードを読むだけで理解できる

**自己文書化コードの限界:**
- コードへのアクセスを持たないコード利用者（外部API利用者等）には機能しない
- 「なぜ」（Why）の説明はコードだけでは表現困難な場合がある

### ドキュメント・コメントの何を残すか判断基準

| 内容 | 残すべきか | 理由 |
|------|-----------|------|
| 関数が**何を**するか（Whatコメント） | ❌（原則不要） | コードが語るべき。語れないならコードを改善 |
| **なぜ**その実装か（Whyコメント） | ✅ | 意図はコードで表現困難 |
| 非慣用的コードの理由 | ✅ | パフォーマンス最適化など特殊な理由を説明 |
| バグ修正の背景 | ✅（簡潔に） | 同じミスの再発防止 |
| 古くなったコメント | ❌（削除） | 不正確な情報は無いより悪い |
| TODO・将来のタスク | 条件付き✅ | チケット管理ができないならコメント可、リンク推奨 |

### コードとドキュメントの同期維持戦略

**問題:** コードは変更されてもドキュメントが追いつかない。

```python
# ❌ 悪い例: コードの変更後にコメントが陳腐化
# この関数は USPS, UPS, FedEx の3社に対応する
def check_shipping_status(order):
    # 実際は後でDHLが追加されたが、コメントは更新されていない
    if order.shipper == "DHL":
        return check_dhl(order)
    ...
```

**解決策:**
1. コメントは「Why」のみに絞り、「What」はコード自体を改善する
2. コードレビュー時にドキュメント・コメントの陳腐化チェックを含める
3. docstringは公開APIのみに適用し、実装の詳細には書かない

### 公開APIにおけるdocstringの最小基準

```python
def get_customer_orders(
    customer: Customer,
    *,
    status_filter: str | None = None,
) -> list[Order]:
    """
    指定した顧客の注文一覧を返す。

    Args:
        customer: 注文を取得する顧客オブジェクト。
        status_filter: 指定した場合、このステータスの注文のみ返す。
            None の場合はすべての注文を返す。

    Returns:
        Order オブジェクトのリスト。該当する注文がない場合は空リスト。

    Raises:
        CustomerNotFoundError: customer が存在しない場合。
    """
    ...
```

**最小限記述すべき内容:**
- 関数の目的（1行）
- 非自明なパラメータの説明
- 戻り値の型と意味（空コレクションの扱い含む）
- 発生しうる例外

---

## 関連リファレンス

| ファイル | 内容 |
|---------|------|
| `SD-PRINCIPLES.md` | SOLID原則・OOP設計基礎 |
| `EP-CH07-CLASSES.md` | クラス設計のPythonic実践 |
| `EP-CH10-ROBUSTNESS.md` | エラーハンドリング・例外設計 |
| `TOOLING.md` | linter（flake8, ruff）・型チェッカー設定 |
