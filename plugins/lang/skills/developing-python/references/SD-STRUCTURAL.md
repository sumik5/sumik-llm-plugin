# 構造に関するデザインパターン（Structural Patterns）

GoF（Gang of Four）分類における構造パターンは、クラスやオブジェクトを組み合わせて大きな構造を形成する方法を提供し、システムの柔軟性と拡張性を高める。

---

## 1. Adapter パターン

### 目的

互換性のないインタフェースを持つクラス同士を、変更なしに協調動作させる変換レイヤーを提供する。

### 問題と解決策

**問題:** 既存のコードや外部ライブラリを利用したいが、インタフェースが一致しない。どちらのコードも変更できない（またはしたくない）。変換ロジックをクライアント側に埋め込むと、Single Responsibility Principle に違反し、新たなデータソースを追加するたびにクライアントを変更しなければならない。

**解決策:** Adapter クラスがターゲットインタフェースを実装しつつ、内部でアダプティ（変換対象）を保持する。変換ロジックを Adapter に集約することで、クライアントはターゲットインタフェースのみを意識すればよい。

### Python実装（オブジェクトアダプタ：コンポジション）

```python
from abc import ABC, abstractmethod


# --- ターゲットインタフェース（クライアントが期待する形） ---

class DataSource(ABC):
    @abstractmethod
    def get_data(self) -> dict[str, object]: ...


# --- アダプティ（変更できない既存クラス） ---

class LegacyCSVReader:
    """既存のCSVリーダー。インタフェースが DataSource と異なる"""

    def read_as_list(self, filepath: str) -> list[list[str]]:
        with open(filepath) as f:
            return [line.strip().split(",") for line in f]


class ExternalAPIClient:
    """外部APIクライアント。インタフェースが DataSource と異なる"""

    def fetch_json(self) -> str:
        return '{"key": "value"}'


# --- アダプタ（コンポジションで実装） ---

class CSVAdapter(DataSource):
    def __init__(self, reader: LegacyCSVReader, filepath: str) -> None:
        self._reader = reader
        self._filepath = filepath

    def get_data(self) -> dict[str, object]:
        rows = self._reader.read_as_list(self._filepath)
        headers = rows[0] if rows else []
        return {"headers": headers, "rows": rows[1:]}


class APIAdapter(DataSource):
    def __init__(self, client: ExternalAPIClient) -> None:
        self._client = client

    def get_data(self) -> dict[str, object]:
        import json
        return json.loads(self._client.fetch_json())


# --- クライアント（DataSource のみを知る） ---

class ReportGenerator:
    def generate(self, source: DataSource) -> None:
        data = source.get_data()
        print(f"レポート生成: {data}")
```

### Python実装（クラスアダプタ：多重継承）

多重継承を活用したクラスアダプタは、Python では継承でアダプティのメソッドを直接利用できる。

```python
class CSVClassAdapter(DataSource, LegacyCSVReader):
    """多重継承でアダプティのメソッドを直接継承"""

    def __init__(self, filepath: str) -> None:
        self._filepath = filepath

    def get_data(self) -> dict[str, object]:
        # LegacyCSVReader から継承したメソッドを直接呼び出す
        rows = self.read_as_list(self._filepath)
        headers = rows[0] if rows else []
        return {"headers": headers, "rows": rows[1:]}
```

---

## 2. Facade パターン

### 目的

サブシステムの複雑なインタフェース群を、単一のシンプルなインタフェースで覆い隠す。

### 問題と解決策

**問題:** 複数のサブシステムと直接やり取りすると、クライアントはそれぞれのサブシステムの詳細を知る必要がある。サブシステムの変更がクライアントに波及し、重複コードが発生する。また、呼び出し順序の管理が複雑になる。

**解決策:** Facade クラスがサブシステムとのすべてのやり取りをカプセル化する。クライアントは Facade の単純なメソッドを呼ぶだけでよく、サブシステムの詳細や呼び出し順序を意識しなくて済む。

### Python実装

```python
# --- サブシステム群（変更しない・変更できない） ---

class AuthService:
    def authenticate(self, user: str, password: str) -> str:
        # 認証処理
        return f"token_{user}"

    def authorize(self, token: str, resource: str) -> bool:
        return token.startswith("token_")


class DatabaseService:
    def connect(self, url: str) -> None:
        print(f"DB接続: {url}")

    def query(self, sql: str) -> list[dict[str, object]]:
        return [{"id": 1, "name": "Alice"}]

    def disconnect(self) -> None:
        print("DB切断")


class CacheService:
    def __init__(self) -> None:
        self._cache: dict[str, object] = {}

    def get(self, key: str) -> object | None:
        return self._cache.get(key)

    def set(self, key: str, value: object, ttl: int = 300) -> None:
        self._cache[key] = value

    def invalidate(self, key: str) -> None:
        self._cache.pop(key, None)


# --- Facade（統一インタフェース） ---

class DataAccessFacade:
    """DB・キャッシュ・認証の複雑な連携を隠蔽する Facade"""

    def __init__(self, db_url: str) -> None:
        self._auth = AuthService()
        self._db = DatabaseService()
        self._cache = CacheService()
        self._db.connect(db_url)

    def get_user_data(
        self, user: str, password: str, user_id: int
    ) -> list[dict[str, object]] | None:
        # 1. 認証
        token = self._auth.authenticate(user, password)
        if not self._auth.authorize(token, "user_data"):
            return None

        # 2. キャッシュ確認
        cache_key = f"user_{user_id}"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached  # type: ignore[return-value]

        # 3. DB から取得
        result = self._db.query(f"SELECT * FROM users WHERE id = {user_id}")

        # 4. キャッシュに保存
        self._cache.set(cache_key, result)
        return result

    def close(self) -> None:
        self._db.disconnect()


# --- クライアント（Facade のみを知る） ---

facade = DataAccessFacade("sqlite:///app.db")
data = facade.get_user_data("alice", "secret", user_id=1)
facade.close()
```

---

## 3. Composite パターン

### 目的

オブジェクトをツリー構造に組み合わせて、個別オブジェクトと複合オブジェクトを同一のインタフェースで扱えるようにする。

### 問題と解決策

**問題:** ツリー構造（ファイルシステム、UI コンポーネント、組織図など）を扱う際に、「葉」と「枝」に対して別々のコードを書く必要がある。コードが構造に依存するため、ツリーの変更や入れ子の深さへの対応が困難になる。

**解決策:** 個別オブジェクト（Leaf）と複合オブジェクト（Composite）が同じ抽象クラス（Component）を継承する。クライアントは Component インタフェースを通じて操作するため、個別か複合かを意識せずにツリー全体を再帰的に処理できる。

### Python実装

```python
from abc import ABC, abstractmethod
from typing import Iterator


class Component(ABC):
    """個別・複合オブジェクト共通の抽象インタフェース"""

    def __init__(self, name: str) -> None:
        self._name = name

    @property
    def name(self) -> str:
        return self._name

    @property
    @abstractmethod
    def size(self) -> int:
        """ファイルサイズ（バイト）または配下の合計"""
        ...

    @abstractmethod
    def display(self, indent: int = 0) -> None: ...

    # Composite 操作（Leaf ではデフォルトでエラー）
    def add(self, component: "Component") -> None:
        raise NotImplementedError("葉ノードには子要素を追加できません")

    def remove(self, component: "Component") -> None:
        raise NotImplementedError("葉ノードには子要素がありません")

    def __iter__(self) -> Iterator["Component"]:
        return iter([])


class File(Component):
    """葉ノード: 個別ファイル"""

    def __init__(self, name: str, size: int) -> None:
        super().__init__(name)
        self._size = size

    @property
    def size(self) -> int:
        return self._size

    def display(self, indent: int = 0) -> None:
        print(f"{'  ' * indent}📄 {self._name} ({self._size} bytes)")


class Directory(Component):
    """複合ノード: ディレクトリ"""

    def __init__(self, name: str) -> None:
        super().__init__(name)
        self._children: list[Component] = []

    @property
    def size(self) -> int:
        # 再帰的に合計サイズを計算
        return sum(child.size for child in self._children)

    def add(self, component: Component) -> None:
        self._children.append(component)

    def remove(self, component: Component) -> None:
        self._children.remove(component)

    def display(self, indent: int = 0) -> None:
        print(f"{'  ' * indent}📁 {self._name}/ ({self.size} bytes)")
        for child in self._children:
            child.display(indent + 1)

    def __iter__(self) -> Iterator[Component]:
        return iter(self._children)


# 利用例: ツリーの構築と操作
root = Directory("project")
src = Directory("src")
src.add(File("main.py", 1024))
src.add(File("utils.py", 512))

tests = Directory("tests")
tests.add(File("test_main.py", 2048))

root.add(src)
root.add(tests)
root.add(File("README.md", 256))

root.display()
# 📁 project/ (3840 bytes)
#   📁 src/ (1536 bytes)
#     📄 main.py (1024 bytes)
#     📄 utils.py (512 bytes)
#   📁 tests/ (2048 bytes)
#     📄 test_main.py (2048 bytes)
#   📄 README.md (256 bytes)

# クライアントは File も Directory も同じ Component として扱える
for component in root:
    print(f"{component.name}: {component.size} bytes")
```

---

## 4. Decorator パターン

### 目的

オブジェクトに対して、サブクラス化なしに動的に責務（属性・振る舞い）を追加する。

### 問題と解決策

**問題:** 機能の組み合わせをすべてサブクラスで表現すると、クラス爆発が起きる。例えば「ログ付き」「キャッシュ付き」「認証付き」の組み合わせ3通りだけで7つのサブクラスが必要になる。また、実行時に責務の組み合わせを変更できない。

**解決策:** ラッパーオブジェクト（Decorator）が元のオブジェクトを包み込み、追加の処理を担う。Decorator は元のオブジェクトと同じインタフェースを実装するため、クライアントは Decorator を透過的に使える。複数の Decorator を連鎖させることで、任意の組み合わせを実現できる。

### Python実装

```python
from abc import ABC, abstractmethod
from functools import wraps
from typing import Callable, TypeVar

F = TypeVar("F", bound=Callable[..., object])


# --- Component ---

class DataProcessor(ABC):
    @abstractmethod
    def process(self, data: str) -> str: ...


class PlainDataProcessor(DataProcessor):
    def process(self, data: str) -> str:
        return data.strip()


# --- Decorator 基底クラス ---

class DataProcessorDecorator(DataProcessor):
    def __init__(self, processor: DataProcessor) -> None:
        self._processor = processor

    def process(self, data: str) -> str:
        return self._processor.process(data)


# --- 具体的な Decorator ---

class EncryptionDecorator(DataProcessorDecorator):
    def process(self, data: str) -> str:
        base = super().process(data)
        return f"[ENC]{base}[/ENC]"  # 簡略化した暗号化


class LoggingDecorator(DataProcessorDecorator):
    def process(self, data: str) -> str:
        print(f"[LOG] 処理開始: {len(data)} chars")
        result = super().process(data)
        print(f"[LOG] 処理完了: {len(result)} chars")
        return result


class CompressionDecorator(DataProcessorDecorator):
    def process(self, data: str) -> str:
        base = super().process(data)
        return f"[COMP]{base}"


# 利用例: 任意の順序・組み合わせで Decorator を連鎖
processor: DataProcessor = PlainDataProcessor()
processor = EncryptionDecorator(processor)
processor = LoggingDecorator(processor)
processor = CompressionDecorator(processor)

result = processor.process("  Hello, World!  ")
```

### `@functools.wraps` を使った Python 組み込みデコレータ

GoF の Decorator パターンと Python の `@decorator` 構文は概念的に近いが別物。Python のデコレータは関数・クラスを修飾する構文糖衣。`@functools.wraps` でメタデータを保持する。

```python
import functools
import time
import logging
from typing import Callable, ParamSpec, TypeVar

P = ParamSpec("P")
R = TypeVar("R")

logger = logging.getLogger(__name__)


def retry(max_attempts: int = 3, delay: float = 1.0) -> Callable[[Callable[P, R]], Callable[P, R]]:
    """失敗時にリトライするデコレータ（パラメータ付き）"""
    def decorator(func: Callable[P, R]) -> Callable[P, R]:
        @functools.wraps(func)  # __name__, __doc__ 等を引き継ぐ
        def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
            for attempt in range(1, max_attempts + 1):
                try:
                    return func(*args, **kwargs)
                except Exception as exc:
                    if attempt == max_attempts:
                        raise
                    logger.warning(
                        "試行 %d/%d 失敗: %s. %.1f秒後にリトライ",
                        attempt, max_attempts, exc, delay
                    )
                    time.sleep(delay)
            raise RuntimeError("到達不能")
        return wrapper
    return decorator


def log_calls(func: Callable[P, R]) -> Callable[P, R]:
    """関数呼び出しをログに記録するデコレータ"""
    @functools.wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        logger.info("呼び出し: %s", func.__name__)
        result = func(*args, **kwargs)
        logger.info("完了: %s", func.__name__)
        return result
    return wrapper


# 利用例: デコレータの連鎖
@retry(max_attempts=3, delay=0.5)
@log_calls
def fetch_data(url: str) -> str:
    # 外部 API 呼び出し（失敗する可能性あり）
    import urllib.request
    with urllib.request.urlopen(url) as resp:
        return resp.read().decode()
```

---

## 使い分け判断テーブル

### Adapter vs Facade

| 観点 | Adapter | Facade |
|------|---------|--------|
| 目的 | 既存インタフェースを別のインタフェースに変換 | 複雑なサブシステムをシンプルなインタフェースで覆う |
| 対象 | 単一クラス（または少数）のインタフェース変換 | 複数クラスから成るサブシステム全体 |
| 既存コードの変更 | 不要（アダプティをラップするだけ） | 不要（サブシステムを呼び出すだけ） |
| クライアントへの影響 | インタフェースの不一致を解消 | 複雑さを隠蔽し操作を簡略化 |
| 典型的な用途 | 外部ライブラリ統合、レガシーコード統合 | API Gateway、サービスレイヤー、設定管理 |

**Adapter を選ぶ場面:**
- 使いたいクラスのインタフェースが期待するものと異なる
- 変更できない既存クラスをシステムに組み込みたい

**Facade を選ぶ場面:**
- 複雑なサブシステムをシンプルに使いたい
- サブシステムへの依存を1箇所に集約したい
- DRY 原則のため、繰り返し使う操作をまとめたい

### Composite vs Decorator

| 観点 | Composite | Decorator |
|------|-----------|-----------|
| 目的 | ツリー構造の構築、個別/複合の統一的扱い | オブジェクトへの動的な責務追加 |
| 構造 | 子要素を持つ階層（ツリー）構造 | 1つのオブジェクトをラップする連鎖構造 |
| 関係性 | 葉と複合が同じインタフェースを実装 | ラッパーと元オブジェクトが同じインタフェースを実装 |
| 典型的な用途 | ファイルシステム、UI コンポーネントツリー、組織図 | ログ、キャッシュ、認証、バリデーションの追加 |

**Composite を選ぶ場面:**
- データが部分-全体の階層（ツリー）を持つ
- 個別要素と複合要素を同じように処理したい

**Decorator を選ぶ場面:**
- クラスを変更せずに責務を追加したい
- 実行時に責務の組み合わせを変えたい
- 継承によるクラス爆発を避けたい
