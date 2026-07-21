# FastAPI テスト: TestClient・pytest・依存性モック

FastAPI アプリケーションを検証するためのテスト実装——`TestClient` によるHTTPリクエストのシミュレーション、pytest fixtures によるテストコードの整理、`httpx.AsyncClient` による非同期テスト、`dependency_overrides` を使った依存性のモック、テスト用データベースの分離、`lifespan`（起動/終了処理）のテスト——をまとめる。テストの方法論（TDD・AAAパターン・4本柱）は `devkit:testing-code` を、E2Eテストは `web:testing-e2e-with-playwright` を参照（本ファイルの対象外）。

`TestClient` を `with` 文のコンテキストマネージャとして使うこと・テスト後は必ず `dependency_overrides` をクリアすることは、確認不要のベストプラクティスとして本ファイル全体で適用する。

## TestClient の基本

`fastapi.testclient.TestClient` は Starlette の `TestClient`（内部的に `httpx` で実装）をそのまま公開したもので、実サーバーを起動せずにASGIアプリへ直接リクエストを送れる。

```python
from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_read_main() -> None:
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Hello World"}


def test_create_item() -> None:
    response = client.post("/items/", json={"name": "Test Item", "price": 10.5})
    assert response.status_code == 201
    assert response.json()["name"] == "Test Item"
```

### コンテキストマネージャで使う理由（lifespanのテスト）

`with TestClient(app) as client:` の形で使うと、`lifespan` の起動/終了処理（DB接続プールの初期化・MLモデルのロード等）が実際に実行される。単に `client = TestClient(app)` と書いて `with` を使わない場合、`lifespan` イベントは発火しない。

```python
def test_with_lifespan() -> None:
    with TestClient(app) as client:
        response = client.get("/items/")
        assert response.status_code == 200
    # withブロックを抜けると終了処理（lifespanのyield以降）が実行される
```

`lifespan` でロードしたリソース（DB接続プール・MLモデル等）に依存するエンドポイントをテストする場合は、このコンテキストマネージャ形式が必須になる。`lifespan` の仕組みそのものは [DEPENDENCIES.md](./DEPENDENCIES.md) を参照。

## pytest fixtures によるテストの整理

`tests/conftest.py` に共有フィクスチャを定義すると、複数のテストファイルから使い回せる。

```python
# tests/conftest.py
import pytest
from fastapi.testclient import TestClient

from main import app


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c
```

`scope="function"`（デフォルト）はテストごとに再生成、`scope="module"`/`"session"` はファイル/セッション全体で共有する。DB接続を含むフィクスチャは基本的に `function` スコープにし、テスト間で状態を持ち込まないようにする。

認証が必要なエンドポイントには、ログイン処理を内包したフィクスチャを組み合わせる。

```python
@pytest.fixture
def authenticated_client(client: TestClient) -> TestClient:
    response = client.post("/token", data={"username": "testuser", "password": "testpass"})
    token = response.json()["access_token"]
    client.headers["Authorization"] = f"Bearer {token}"
    return client


def test_protected_route(authenticated_client: TestClient) -> None:
    response = authenticated_client.get("/protected")
    assert response.status_code == 200
```

## dependency_overrides によるモック

`Depends` の仕組みそのもの（スコープ・サブ依存性チェーン）は [DEPENDENCIES.md](./DEPENDENCIES.md) を参照。ここではテストのワークフローとしての使い方を扱う。

`app.dependency_overrides` は辞書で、キーに元の依存性関数、値に差し替え用の関数を指定する。

```python
from main import app, get_current_user


def override_get_current_user() -> dict[str, str]:
    return {"username": "testuser"}


def test_protected_route() -> None:
    app.dependency_overrides[get_current_user] = override_get_current_user
    try:
        with TestClient(app) as client:
            response = client.get("/protected")
        assert response.status_code == 200
    finally:
        app.dependency_overrides.clear()  # 他のテストへ影響しないよう必ずクリアする
```

`clear()` を忘れると、後続のテストが意図せず前のオーバーライドを引き継ぎ、原因が分かりにくい失敗を招く。オーバーライドの登録とクリアをフィクスチャ側にカプセル化すると、この手動クリア漏れを構造的に防げる。

```python
@pytest.fixture
def client() -> TestClient:
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()  # テストの成否に関わらずフィクスチャのteardownで必ず実行される
```

### 非同期の依存性をモックする際の注意

差し替え先の依存性が `async def` で定義されている場合、オーバーライド関数も呼び出し可能な形を揃える必要がある。単純な `unittest.mock.Mock` を非同期依存性の代わりに割り当てると、FastAPI が結果を `await` した際に「コルーチンではない」というエラーになる。非同期依存性のモックには `unittest.mock.AsyncMock`、または `async def` で書いた素朴な差し替え関数を使う。

```python
from unittest.mock import AsyncMock


async def get_external_data() -> dict[str, str]: ...


def test_process_data() -> None:
    mock_dependency = AsyncMock(return_value={"mock": "data"})
    app.dependency_overrides[get_external_data] = mock_dependency
    try:
        with TestClient(app) as client:
            response = client.get("/process")
        assert response.json() == {"processed": {"mock": "data"}}
    finally:
        app.dependency_overrides.clear()
```

## httpx AsyncClient による非同期テスト

同期の `TestClient` は多くのテストで十分だが、非同期コードそのものの並行動作（複数リクエストの同時実行・タイムアウト挙動）を検証したい場合は `httpx.AsyncClient` を使う。

```python
from httpx import ASGITransport, AsyncClient

from main import app


async def test_async_endpoint() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/async-endpoint")
    assert response.status_code == 200
```

> **注意**: `AsyncClient(app=app, ...)` という書き方は httpx の旧APIで現在は削除されている。`transport=ASGITransport(app=app)` を明示する形に置き換える。

非同期のテスト関数を実行するには `pytest-asyncio` が必要。`pyproject.toml`（`[tool.pytest.ini_options]`）か `pytest.ini` に以下を設定すれば、`async def` のテスト関数を `@pytest.mark.asyncio` なしで自動検出・実行できる。

```ini
[pytest]
asyncio_mode = auto
```

`ASGITransport` はHTTPリクエストのASGI呼び出しをシミュレートするだけで、**`lifespan` イベントは発火させない**。`lifespan` に依存するリソースを非同期クライアントと組み合わせてテストしたい場合は、`asgi-lifespan` パッケージの `LifespanManager` でアプリをラップするか、`lifespan` も含めてテストできる同期の `TestClient` に切り替える方が簡単なことが多い。

## DBテスト分離

テスト用DBは本番DBから完全に分離し、テストの実行順に依存しないようにする。

### テーブルの作成・破棄を各テストで完結させる

```python
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from main import app, get_db
from models import Base

TEST_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture
def test_db():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client(test_db):
    app.dependency_overrides[get_db] = lambda: test_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
```

SQLiteは既定でコネクション生成時のスレッドしかアクセスを許可しないため、`connect_args={"check_same_thread": False}` が必要になる。

`create_all`/`drop_all` を毎テストで実行する方式は単純で分かりやすいが、テーブル数が多いスイートでは遅くなる。実行速度を優先する場合は、テストごとにトランザクションを開始し、テスト終了時に**ロールバックして変更を捨てる**方式に切り替えると、テーブル再作成のコストを避けられる。

### 非同期DB + インメモリSQLiteの罠

非同期ドライバ（`aiosqlite`）とインメモリSQLite（`sqlite+aiosqlite:///:memory:`）を組み合わせる際、コネクションプールが既定のままだと**接続ごとに別のインメモリDBが生成され、直前に作成したはずのテーブルが見えなくなる**。`poolclass=StaticPool` を指定して単一コネクションを共有させることで回避する。

```python
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import StaticPool

engine = create_async_engine(
    "sqlite+aiosqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
```

より本番に近い挙動（PostgreSQL固有の制約・型）まで検証したい場合は、Testcontainersで実DBコンテナを起動する方法もある（詳細は `devkit:testing-strategies` / `lang:developing-databases` を参照）。DBモデル定義自体は [DATA-PERSISTENCE.md](./DATA-PERSISTENCE.md) を参照。

## WebSocket・非同期エンドポイントのテスト

`TestClient` は `websocket_connect()` により、WebSocketエンドポイントも同期的なコードでテストできる。

```python
def test_websocket() -> None:
    with TestClient(app) as client:
        with client.websocket_connect("/ws") as websocket:
            websocket.send_text("hello")
            data = websocket.receive_text()
            assert data == "Message received: hello"
```

WebSocket・BackgroundTasks・SSEの実装パターン自体は [ASYNC-CONCURRENCY.md](./ASYNC-CONCURRENCY.md) を参照。

## 品質チェックリスト

| チェック項目 | 内容 |
|---|---|
| lifespanの発火 | 起動/終了処理に依存するテストは `TestClient` を `with` 文で使っているか |
| オーバーライドのクリア | `dependency_overrides` をテスト後（`finally` またはfixtureのteardown）で確実にクリアしているか |
| 非同期モックの型 | 非同期依存性のモックに `AsyncMock` を使っているか（同期の`Mock`はawait時にエラーになる） |
| DBの分離 | テスト用DBが本番から分離され、テスト間で状態が持ち込まれていないか |
| 非同期テストの検出 | `asyncio_mode` 等の設定が有効になっているか |

## 関連ドキュメント

- **[FUNDAMENTALS.md](./FUNDAMENTALS.md)**: プロジェクト構造・エラーハンドリングの基礎
- **[DEPENDENCIES.md](./DEPENDENCIES.md)**: `Depends`/`dependency_overrides`/`lifespan` の仕組みそのもの
- **[DATA-PERSISTENCE.md](./DATA-PERSISTENCE.md)**: 本番用のDB接続・ORMモデル定義
- **[ASYNC-CONCURRENCY.md](./ASYNC-CONCURRENCY.md)**: WebSocket・BackgroundTasks・SSEの実装パターン
- `devkit:testing-code`: テストの方法論（TDD・AAAパターン・4本柱・モックの原則）
- `devkit:testing-strategies`: Testcontainersによるデータテスト・全体のテスト戦略
- `web:testing-e2e-with-playwright`: ブラウザ経由のE2Eテスト
