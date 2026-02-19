# FastAPI 依存性注入（DI）パターン

## DI概念

### IoC（制御の反転）と DIP（依存関係逆転の原則）

依存性注入（Dependency Injection）は、オブジェクトが依存するコンポーネントを自分で生成するのではなく、外部から受け取る設計パターン。

**密結合の問題点（アンチパターン）:**

```python
# ❌ 密結合：オブジェクトが依存を内部で生成
class ReportService:
    def __init__(self):
        self.db = PostgresDatabase()  # 実装に直接依存
        self.formatter = PDFFormatter()
```

| 問題 | 影響 |
|------|------|
| 硬直性 | DBを変更するにはクラス自体を修正が必要 |
| テスト困難 | 実DBなしではテスト不可 |
| 再利用性低下 | 特定の実装にロックイン |
| 関心の混在 | ビジネスロジックと依存生成が混在 |

**DI適用後（疎結合）:**

```python
# ✅ DI：外部から依存を注入
class EmailService:
    def __init__(self, smtp_client: SMTPClient):
        self.smtp_client = smtp_client

# 呼び出し元で生成と注入を担当
smtp = SMTPClient("smtp.example.com", 587)
email_service = EmailService(smtp)
```

SOLID の D（依存関係逆転の原則）: 高レベルモジュールは低レベルモジュールに依存しない。両者は抽象に依存すべき。

### DIコンテナとしての FastAPI `Depends`

FastAPI の `Depends` はDIコンテナとして機能し、以下を自動処理する:

| 機能 | 内容 |
|------|------|
| 自動依存解決 | 関数シグネチャを解析して依存を自動注入 |
| 階層的依存 | 依存が別の依存を持つ連鎖を自動解決 |
| リクエストスコープ | 同一リクエスト内でのキャッシュと再利用 |
| テスト用オーバーライド | テスト時に実装を差し替え可能 |

---

## 依存性パターン

### 関数依存性

**基本パターン:**

```python
from typing import Annotated
from fastapi import Depends, FastAPI, Query

app = FastAPI()

class PaginationParams:
    def __init__(self, page: int = 1, size: int = 10):
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
    pagination: Annotated[PaginationParams, Depends(get_pagination)]
) -> dict:
    return {
        "skip": pagination.skip,
        "limit": pagination.limit,
    }
```

**Annotated 型エイリアスによる簡潔化:**

```python
# 型エイリアスを定義してコードを簡潔に
PaginationDep = Annotated[PaginationParams, Depends(get_pagination)]

@app.get("/users/")
async def list_users(pagination: PaginationDep) -> dict:
    ...

@app.get("/products/")
async def list_products(pagination: PaginationDep) -> dict:
    ...
```

> `Annotated[Type, Depends(func)]` の書き方が推奨。`Type` は型チェッカー用、`Depends(func)` は FastAPI の注入制御用。

---

### クラス依存性

FastAPI はクラスも依存性として受け付ける。`__init__` パラメータを自動解決する。

```python
class PaginationParams:
    def __init__(self, page: int = 1, size: int = 10):
        self.page = max(1, page)
        self.size = min(100, max(1, size))
        self.skip = (self.page - 1) * self.size
        self.limit = self.size

@app.get("/items/")
async def list_items(
    pagination: Annotated[PaginationParams, Depends(PaginationParams)]
) -> dict:
    ...
```

**省略形（型と依存が同じ場合）:**

```python
# Depends() の引数省略 -- 型ヒントから推論
pagination: Annotated[PaginationParams, Depends()]
```

**クラス依存性でのサブ依存:**

```python
class ItemService:
    def __init__(
        self,
        db: Annotated[AsyncSession, Depends(get_db)],
        pagination: Annotated[PaginationHelper, Depends(get_pagination_helper)],
    ):
        self.db = db
        self.pagination = pagination

    def get_items(self, page: int, size: int) -> dict:
        ...

@app.get("/items/")
async def list_items(
    service: Annotated[ItemService, Depends()]
) -> dict:
    return service.get_items(page=1, size=20)
```

**Class vs Function 依存性の判断基準:**

| 使用場面 | 推奨 |
|---------|------|
| 状態とメソッドをカプセル化したい | クラス |
| 複雑な検証やビジネスロジックをまとめたい | クラス |
| 単純な値の変換・バリデーション | 関数 |
| シンプルなステートレス操作 | 関数 |
| 単一の値や単純なデータ構造 | 関数 |

---

### サブ依存性チェーン

依存性は階層的に連鎖できる。FastAPI が自動的に順序解決する。

```python
class PaginationSettings:
    def __init__(self):
        self.include_total_count = True
        self.include_page_info = True

def get_pagination_settings() -> PaginationSettings:
    return PaginationSettings()

class PaginationHelper:
    def __init__(
        self,
        settings: Annotated[PaginationSettings, Depends(get_pagination_settings)]
    ):
        self.settings = settings

    def paginate(self, items: list, page: int, size: int) -> dict:
        skip = (page - 1) * size
        page_items = items[skip:skip + size]
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
    settings: Annotated[PaginationSettings, Depends(get_pagination_settings)]
) -> PaginationHelper:
    return PaginationHelper(settings)

PaginationDep = Annotated[PaginationHelper, Depends(get_pagination_helper)]
```

**解決順序（FastAPI が自動処理）:**

```
get_pagination_settings()
    ↓ result
get_pagination_helper(settings)
    ↓ result
endpoint(pagination)
```

---

### エラーハンドリングと検証依存性

依存性内で `HTTPException` を発生させると、エンドポイント実行前に処理が停止する。

```python
from fastapi import HTTPException

async def validate_pagination(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
) -> PaginationParams:
    """バリデーション付きページネーション依存性"""
    if page > 10000:
        raise HTTPException(
            status_code=400,
            detail="ページ番号が大きすぎます（最大: 10000）"
        )
    return PaginationParams(page, size)
```

**バリデーション依存性のパターン:**

```python
async def require_admin(
    current_user: Annotated[User, Depends(get_current_user)]
) -> User:
    """管理者権限を要求する依存性"""
    if not current_user.is_admin:
        raise HTTPException(
            status_code=403,
            detail="管理者権限が必要です"
        )
    return current_user

AdminDep = Annotated[User, Depends(require_admin)]

@app.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    admin: AdminDep,  # 管理者でない場合は 403 が返る
) -> dict:
    ...
```

---

## スコープとライフサイクル管理

### リクエストスコープ（デフォルト）

FastAPI は同一リクエスト内で同じ依存性関数（引数も同じ）を複数回呼ばれた場合、最初の結果を自動キャッシュして再利用する。

```python
async def get_current_user(
    token: str,
    auth_service: AuthServiceDep,
) -> User:
    # 高コスト処理（DBクエリ等）
    return await auth_service.get_user_from_token(token)

CurrentUserDep = Annotated[User, Depends(get_current_user)]

# 複数サービスが同じ依存性を持っても、1リクエストで1回だけ実行される
def get_permission_service(user: CurrentUserDep) -> PermissionService:
    return PermissionService(user)

def get_audit_service(user: CurrentUserDep) -> AuditService:
    return AuditService(user)

@app.get("/protected")
async def protected_endpoint(
    user: CurrentUserDep,
    permissions: Annotated[PermissionService, Depends(get_permission_service)],
    audit: Annotated[AuditService, Depends(get_audit_service)],
) -> dict:
    # get_current_user は1回だけ呼ばれる（キャッシュ効果）
    ...
```

**`use_cache` パラメータ:**

```python
# キャッシュを無効化（毎回新しいインスタンスを生成）
Depends(get_db, use_cache=False)
```

---

### Singleton（`@lru_cache`）

アプリケーション起動から終了まで同一インスタンスを再利用する。

```python
from functools import lru_cache
import httpx

class ExternalAPIClient:
    def __init__(self):
        self.client = httpx.AsyncClient(
            base_url="https://api.example.com",
            timeout=30.0,
        )

    async def fetch_data(self, resource_id: str) -> dict:
        response = await self.client.get(f"/{resource_id}")
        return response.json()

@lru_cache()
def get_api_client() -> ExternalAPIClient:
    return ExternalAPIClient()

APIClientDep = Annotated[ExternalAPIClient, Depends(get_api_client)]
```

**`@lru_cache` 適用の判断マトリクス:**

| 適用すべき | 適用してはいけない |
|-----------|------------------|
| HTTP クライアント | ユーザーセッション |
| 設定オブジェクト（Config） | リクエストヘッダ |
| ML モデル | 認証トークン |
| コネクションプール | ショッピングカート等の可変状態 |
| ステートレスなユーティリティサービス | リクエスト固有データ |

**`@lru_cache` の注意点:**

| 注意点 | 内容 |
|-------|------|
| テスト分離 | キャッシュがテスト間で持続するため、`get_api_client.cache_clear()` が必要 |
| async 非互換 | async 関数に直接適用すると問題が起きる（同期関数でラップする） |
| メモリ | `maxsize` なしだと無制限にキャッシュされる |

---

### Application State（lifespan コンテキストマネージャ）

async 初期化・明示的なクリーンアップが必要なリソースには `lifespan` を使用する。

```python
from contextlib import asynccontextmanager
from typing import AsyncIterator, TypedDict
from fastapi import FastAPI, Request

class AppState(TypedDict):
    http_client: httpx.AsyncClient
    # 他のシングルトンを追加可能

@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[AppState]:
    # 起動処理
    http_client = httpx.AsyncClient(
        base_url="https://api.example.com",
        timeout=30.0,
    )

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
| 単純な自動シングルトン | `@lru_cache()` |
| async 初期化が必要 | `lifespan` |
| 終了時のクリーンアップが必要 | `lifespan` |
| 起動前に確実に初期化したい | `lifespan` |
| 複雑な初期化シーケンスが必要 | `lifespan` |

---

## テストパターン

### `dependency_overrides` による差し替え

```python
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock

class MockAuthService:
    def __init__(self):
        self.call_count = 0

    async def authenticate(self, username: str, password: str) -> dict | None:
        self.call_count += 1
        if username == "testuser" and password == "secret":
            return {"id": 1, "username": "testuser"}
        return None

def test_login_success():
    mock_service = MockAuthService()

    # 依存性を差し替え
    app.dependency_overrides[get_auth_service] = lambda: mock_service

    with TestClient(app) as client:
        response = client.post("/login", data={
            "username": "testuser",
            "password": "secret",
        })

        assert response.status_code == 200
        assert mock_service.call_count == 1

    # クリーンアップ（忘れずに）
    app.dependency_overrides.clear()
```

---

### pytest fixtures によるクリーンな管理

手動で `dependency_overrides.clear()` を呼ぶのは漏れやすい。fixture でカプセル化する。

```python
import pytest
from fastapi.testclient import TestClient

@pytest.fixture
def client():
    """自動クリーンアップ付きテストクライアント"""
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()  # テスト後に自動クリア

@pytest.fixture
def mock_auth_service():
    """モック認証サービス"""
    return MockAuthService()

@pytest.fixture
def mock_db_session():
    """モック DB セッション"""
    return AsyncMock(spec=AsyncSession)

# テストがシンプルになる
def test_login_success(client, mock_auth_service):
    app.dependency_overrides[get_auth_service] = lambda: mock_auth_service

    response = client.post("/login", data={
        "username": "testuser",
        "password": "secret",
    })

    assert response.status_code == 200
    assert "access_token" in response.json()

def test_login_failure(client, mock_auth_service):
    app.dependency_overrides[get_auth_service] = lambda: mock_auth_service

    response = client.post("/login", data={
        "username": "wrong",
        "password": "wrong",
    })

    assert response.status_code == 401
```

**TestClient をコンテキストマネージャで使う理由:**

```python
# ✅ 推奨: lifespan イベント（起動・終了）が正しく実行される
with TestClient(app) as client:
    response = client.get("/items/")

# ⚠️ 非推奨: lifespan が実行されない可能性がある
client = TestClient(app)
response = client.get("/items/")
```

---

### lru_cache のテスト分離

```python
@pytest.fixture(autouse=True)
def clear_lru_cache():
    """各テスト前後に lru_cache をクリア"""
    get_api_client.cache_clear()
    yield
    get_api_client.cache_clear()
```

---

## 設計チェックリスト

| チェック項目 | 内容 |
|------------|------|
| 型エイリアス定義 | `XxxDep = Annotated[Xxx, Depends(get_xxx)]` でコード重複を削減 |
| キャッシュ判断 | Singleton にすべきか Request スコープかを意識する |
| lifespan 利用 | async 初期化・クリーンアップが必要なリソースは lifespan を使う |
| テスト設計 | 依存性は fixture で管理し、`dependency_overrides.clear()` を忘れない |
| エラー早期返却 | バリデーション依存性で `HTTPException` を使い、エンドポイントを単純化 |

---

## 関連ドキュメント

- **[FASTAPI-GUIDE.md](./FASTAPI-GUIDE.md)**: FastAPI 基本パターン（アプリ構成・設定管理・Pydantic等）
- **[TESTING.md](./TESTING.md)**: pytest テスト戦略・fixture パターン
- **[EXAMPLES.md](./EXAMPLES.md)**: 具体的なコード例（認証・DB接続等）
