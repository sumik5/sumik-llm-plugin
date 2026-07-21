# 依存性注入（Dependency Injection）パターン

FastAPI の `Depends` は単なる「関数の再利用」ではなく DI コンテナとして機能する。本ファイルでは DI の概念的基盤（IoC/DIP）から、関数/クラス依存性・サブ依存性チェーン・スコープ管理・実運用パターン・テスト時の差し替えまでを扱う。認証・認可の実装詳細は `AUTH-SECURITY.md`、DB エンジン初期化の詳細は `DATA-PERSISTENCE.md` を参照。

`Annotated[Type, Depends(func)]` 記法・全パラメータへの型注釈は確認不要のベストプラクティスとして本ファイル全体で適用する（`param: Type = Depends(func)` という旧記法は使わない）。

## DI概念

### IoC（制御の反転）と DIP（依存関係逆転の原則）

依存性注入（Dependency Injection）は、オブジェクトが依存するコンポーネントを自分で生成するのではなく、外部から受け取る設計パターンである。

**密結合の問題点（アンチパターン）:**

```python
# NG: 密結合。オブジェクトが依存を内部で生成している
class ReportService:
    def __init__(self) -> None:
        self.db = PostgresDatabase()  # 実装に直接依存
        self.formatter = PDFFormatter()
```

| 問題 | 影響 |
|------|------|
| 硬直性 | DB を変更するにはクラス自体の修正が必要 |
| テスト困難 | 実 DB なしではテスト不可 |
| 再利用性低下 | 特定の実装にロックイン |
| 関心の混在 | ビジネスロジックと依存生成が混在 |

**DI 適用後（疎結合）:**

```python
# OK: DI。外部から依存を注入する
class EmailService:
    def __init__(self, smtp_client: SMTPClient) -> None:
        self.smtp_client = smtp_client

# 呼び出し元が生成と注入を担当する
smtp = SMTPClient("smtp.example.com", 587)
email_service = EmailService(smtp)
```

SOLID の D（依存関係逆転の原則）: 高レベルモジュールは低レベルモジュールに依存せず、両者は抽象に依存すべきである。

### DI コンテナとしての `Depends`

FastAPI の `Depends` は以下を自動処理する DI コンテナとして機能する。

| 機能 | 内容 |
|------|------|
| 自動依存解決 | 関数シグネチャを解析して依存を自動注入 |
| 階層的依存 | 依存が別の依存を持つ連鎖を自動解決 |
| リクエストスコープ | 同一リクエスト内でのキャッシュと再利用 |
| テスト用オーバーライド | テスト時に実装を差し替え可能 |

## 依存性パターン

### 関数依存性

```python
from typing import Annotated

from fastapi import Depends, FastAPI, Query

app = FastAPI()

class PaginationParams:
    def __init__(self, page: int, size: int) -> None:
        self.page = max(1, page)
        self.size = min(100, max(1, size))
        self.skip = (self.page - 1) * self.size
        self.limit = self.size

async def get_pagination(
    page: int = Query(1, ge=1),
    size: int = Query(10, ge=1, le=100),
) -> PaginationParams:
    """ページネーションパラメータを提供する依存性"""
    return PaginationParams(page, size)

@app.get("/items/")
async def list_items(
    pagination: Annotated[PaginationParams, Depends(get_pagination)],
) -> dict:
    return {"skip": pagination.skip, "limit": pagination.limit}
```

**型エイリアスによる簡潔化:**

```python
PaginationDep = Annotated[PaginationParams, Depends(get_pagination)]

@app.get("/users/")
async def list_users(pagination: PaginationDep) -> dict:
    ...

@app.get("/products/")
async def list_products(pagination: PaginationDep) -> dict:
    ...
```

> `Type` は型チェッカー用、`Depends(func)` は FastAPI の注入制御用。型エイリアス化するとエンドポイント間でシグネチャが重複しない。

### クラス依存性

FastAPI はクラスも依存性として受け付け、`__init__` パラメータを自動解決する。

```python
class PaginationParams:
    def __init__(self, page: int = 1, size: int = 10) -> None:
        self.page = max(1, page)
        self.size = min(100, max(1, size))
        self.skip = (self.page - 1) * self.size
        self.limit = self.size

@app.get("/items/")
async def list_items(
    pagination: Annotated[PaginationParams, Depends(PaginationParams)],
) -> dict:
    ...
```

**省略形（型と依存が同じ場合）:**

```python
pagination: Annotated[PaginationParams, Depends()]
```

**クラス依存性でのサブ依存:**

```python
class ItemService:
    def __init__(
        self,
        db: Annotated[AsyncSession, Depends(get_db)],
        pagination: Annotated[PaginationHelper, Depends(get_pagination_helper)],
    ) -> None:
        self.db = db
        self.pagination = pagination

    def get_items(self, page: int, size: int) -> dict:
        ...

@app.get("/items/")
async def list_items(service: Annotated[ItemService, Depends()]) -> dict:
    return service.get_items(page=1, size=20)
```

**Class vs Function 依存性の判断基準:**

| 使用場面 | 推奨 |
|---------|------|
| 状態とメソッドのカプセル化・複雑な検証やビジネスロジックの集約 | クラス |
| 単純な値の変換・バリデーション・ステートレスな操作 | 関数 |

### サブ依存性チェーン

依存性は階層的に連鎖でき、FastAPI が解決順序を自動処理する。

```python
class PaginationSettings:
    def __init__(self) -> None:
        self.include_total_count = True
        self.include_page_info = True

def get_pagination_settings() -> PaginationSettings:
    return PaginationSettings()

class PaginationHelper:
    def __init__(
        self,
        settings: Annotated[PaginationSettings, Depends(get_pagination_settings)],
    ) -> None:
        self.settings = settings

    def paginate(self, items: list, page: int, size: int) -> dict:
        skip = (page - 1) * size
        page_items = items[skip : skip + size]
        result: dict = {"data": page_items}
        if self.settings.include_page_info:
            result["current_page"] = page
            result["page_size"] = len(page_items)
        if self.settings.include_total_count:
            total = len(items)
            result["total_items"] = total
            result["total_pages"] = (total + size - 1) // size
        return result

def get_pagination_helper(
    settings: Annotated[PaginationSettings, Depends(get_pagination_settings)],
) -> PaginationHelper:
    return PaginationHelper(settings)

PaginationDep = Annotated[PaginationHelper, Depends(get_pagination_helper)]
```

**解決順序（FastAPI が自動処理）**: `get_pagination_settings()` → `get_pagination_helper(settings)` → `endpoint(pagination)`。

### エラーハンドリングと検証依存性

依存性内で `HTTPException` を発生させると、エンドポイント本体の実行前に処理が停止する。

```python
from fastapi import HTTPException, status

async def validate_pagination(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
) -> PaginationParams:
    """バリデーション付きページネーション依存性"""
    if page > 10000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="ページ番号が大きすぎます（最大: 10000）",
        )
    return PaginationParams(page, size)

async def require_admin(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    """管理者権限を要求する依存性（get_current_user は AUTH-SECURITY.md 参照）"""
    if not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="管理者権限が必要です",
        )
    return current_user

AdminDep = Annotated[User, Depends(require_admin)]

@app.delete("/users/{user_id}")
async def delete_user(user_id: int, admin: AdminDep) -> dict:
    ...  # 管理者でない場合は 403 が返る
```

## スコープとライフサイクル管理

### リクエストスコープ（デフォルト）

FastAPI は同一リクエスト内で同じ依存性関数（引数も同じ）が複数回呼ばれた場合、最初の結果を自動キャッシュして再利用する。

```python
async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],  # oauth2_scheme は AUTH-SECURITY.md 参照
    auth_service: AuthServiceDep,
) -> User:
    # 高コスト処理（DB クエリ等）
    return await auth_service.get_user_from_token(token)

CurrentUserDep = Annotated[User, Depends(get_current_user)]

# 複数サービスが同じ依存性を持っても、1リクエストで1回だけ実行される
def get_permission_service(user: CurrentUserDep) -> PermissionService:
    return PermissionService(user)

@app.get("/protected")
async def protected_endpoint(
    user: CurrentUserDep,
    permissions: Annotated[PermissionService, Depends(get_permission_service)],
) -> dict:
    # get_current_user は1回だけ呼ばれる（キャッシュ効果）
    ...
```

**`use_cache` パラメータ**: `Depends(get_db, use_cache=False)` と指定すると、キャッシュを無効化し毎回新しいインスタンスを生成する。

### Singleton（`@lru_cache`）

アプリケーション起動から終了まで同一インスタンスを再利用する。

```python
from functools import lru_cache

import httpx

class ExternalAPIClient:
    def __init__(self) -> None:
        self.client = httpx.AsyncClient(
            base_url="https://api.example.com",
            timeout=30.0,
        )

    async def fetch_data(self, resource_id: str) -> dict:
        response = await self.client.get(f"/{resource_id}")
        return response.json()

@lru_cache
def get_api_client() -> ExternalAPIClient:
    return ExternalAPIClient()

APIClientDep = Annotated[ExternalAPIClient, Depends(get_api_client)]
```

**`@lru_cache` 適用の判断マトリクス:**

| 適用すべき | 適用してはいけない |
|-----------|------------------|
| HTTP クライアント・ML モデル・コネクションプール | ユーザーセッション・認証トークン |
| 設定オブジェクト（Settings）・ステートレスなユーティリティサービス | リクエストヘッダ・ショッピングカート等の可変状態 |

**`@lru_cache` の注意点:**

| 注意点 | 内容 |
|-------|------|
| テスト分離 | キャッシュがテスト間で持続するため `get_api_client.cache_clear()` が必要 |
| async 非互換 | async 関数に直接適用すると問題が起きる（同期関数でラップする） |
| メモリ | `maxsize` なしだと無制限にキャッシュされる |

### Application State（`lifespan` コンテキストマネージャ）

async 初期化・明示的なクリーンアップが必要なリソースには `lifespan` を使う。

```python
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import TypedDict

from fastapi import FastAPI, Request

class AppState(TypedDict):
    http_client: httpx.AsyncClient
    # 他のシングルトンを追加可能

@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[AppState]:
    # 起動処理
    http_client = httpx.AsyncClient(base_url="https://api.example.com", timeout=30.0)

    yield {"http_client": http_client}

    # 終了処理（クリーンアップ）
    await http_client.aclose()

app = FastAPI(lifespan=lifespan)

def get_http_client(request: Request) -> httpx.AsyncClient:
    return request.state.http_client

HTTPClientDep = Annotated[httpx.AsyncClient, Depends(get_http_client)]
```

**`@lru_cache` vs `lifespan` の使い分け:**

| 条件 | 選択 |
|------|------|
| 単純な自動シングルトン | `@lru_cache` |
| async 初期化が必要 | `lifespan` |
| 終了時のクリーンアップが必要 | `lifespan` |
| 起動前に確実に初期化したい | `lifespan` |
| 複雑な初期化シーケンスが必要 | `lifespan` |

## 実運用パターン

DI の型を理解しても、実際のアプリでは「DB セッションをどう依存性化するか」「認証結果をどう他の依存性へ伝えるか」が最初につまずく箇所になる。

### DB セッション依存性（yield 依存性によるクリーンアップ）

DB セッションは典型的なリクエストスコープ依存性であり、`yield` を使うことでエンドポイント実行後に確実にクリーンアップできる。

```python
from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncSession

async def get_db() -> AsyncIterator[AsyncSession]:
    """リクエストごとに DB セッションを提供し、例外時は自動ロールバックする依存性"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise

DBSessionDep = Annotated[AsyncSession, Depends(get_db)]

@app.post("/items/", response_model=ItemRead)
async def create_item(item: ItemCreate, db: DBSessionDep) -> ItemRead:
    ...
```

`yield` の前がリクエスト前処理、`yield` の後（`try`/`except`）がレスポンス確定後の後処理として実行される。エンジン初期化・セッションファクトリの構成やトランザクション戦略の詳細は `DATA-PERSISTENCE.md` を参照。

### 認証依存性の DI への組み込み

認証済みユーザーの取得も「関数依存性の1つ」として同じ DI チェーンに乗る。JWT の発行・検証・スコープ/ロール判定の実装詳細は `AUTH-SECURITY.md` に集約し、ここでは DI としての形だけを示す。

```python
CurrentUserDep = Annotated[User, Depends(get_current_user)]

@app.get("/users/me")
async def read_users_me(current_user: CurrentUserDep) -> User:
    return current_user
```

`get_current_user` 自身も内部で `Annotated[str, Depends(oauth2_scheme)]` を要求するサブ依存性であり、「サブ依存性チェーン」節と同じ解決規則に従う。

## テストパターン

### `dependency_overrides` による差し替え

```python
from fastapi.testclient import TestClient

class MockAuthService:
    def __init__(self) -> None:
        self.call_count = 0

    async def authenticate(self, username: str, password: str) -> dict | None:
        self.call_count += 1
        if username == "testuser" and password == "secret":
            return {"id": 1, "username": "testuser"}
        return None

def test_login_success() -> None:
    mock_service = MockAuthService()
    app.dependency_overrides[get_auth_service] = lambda: mock_service  # 依存性を差し替える

    with TestClient(app) as client:
        response = client.post("/login", data={"username": "testuser", "password": "secret"})
        assert response.status_code == 200
        assert mock_service.call_count == 1

    app.dependency_overrides.clear()  # クリーンアップ（忘れずに）
```

### pytest fixtures によるクリーンな管理

手動で `dependency_overrides.clear()` を呼ぶのは漏れやすい。fixture でカプセル化する。

```python
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

@pytest.fixture
def client() -> Iterator[TestClient]:
    """自動クリーンアップ付きテストクライアント"""
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()  # テスト後に自動クリア

@pytest.fixture
def mock_auth_service() -> MockAuthService:
    return MockAuthService()

def test_login_success(client: TestClient, mock_auth_service: MockAuthService) -> None:
    app.dependency_overrides[get_auth_service] = lambda: mock_auth_service
    response = client.post("/login", data={"username": "testuser", "password": "secret"})
    assert response.status_code == 200
    assert "access_token" in response.json()
```

**`TestClient` をコンテキストマネージャで使う理由:**

```python
# 推奨: lifespan イベント（起動・終了）が正しく実行される
with TestClient(app) as client:
    response = client.get("/items/")

# 非推奨: lifespan が実行されない可能性がある
client = TestClient(app)
response = client.get("/items/")
```

テストの方法論（AAA パターン・4本柱・モック戦略）は `devkit:testing-code` を参照。FastAPI 固有のテスト実装（`TestClient`・`httpx.AsyncClient`・DB テスト分離）は `TESTING.md` に集約する。

### `lru_cache` のテスト分離

```python
@pytest.fixture(autouse=True)
def clear_lru_cache() -> Iterator[None]:
    """各テスト前後に lru_cache をクリアする"""
    get_api_client.cache_clear()
    yield
    get_api_client.cache_clear()
```

## 設計チェックリスト

| チェック項目 | 内容 |
|------------|------|
| 型エイリアス定義 | `XxxDep = Annotated[Xxx, Depends(get_xxx)]` でコード重複を削減 |
| `Annotated` 記法の徹底 | `param: Type = Depends(func)` という旧記法を使わない |
| キャッシュ判断 | Singleton にすべきか Request スコープかを意識する |
| lifespan 利用 | async 初期化・クリーンアップが必要なリソースは lifespan を使う |
| yield 依存性 | DB セッション等は `yield` + `try`/`except` でクリーンアップを保証する |
| テスト設計 | 依存性は fixture で管理し、`dependency_overrides.clear()` を忘れない |
| エラー早期返却 | バリデーション依存性で `HTTPException` を使い、エンドポイントを単純化 |

## 関連ドキュメント

- `FUNDAMENTALS.md`: プロジェクト構造・ルーティング・Pydantic v2 モデル
- `DATA-PERSISTENCE.md`: DB エンジン初期化・セッションファクトリ・CRUD リポジトリ
- `AUTH-SECURITY.md`: OAuth2PasswordBearer・JWT・スコープ/ロール認可の実装
- `TESTING.md`: TestClient・pytest fixture による FastAPI 固有のテスト実装
- 汎用のテスト方法論（TDD・AAA パターン）は `devkit:testing-code` を参照
