# 実装例とパターン

## 🎯 FastMCP基本実装

### シンプルなMCPサーバー

```python
# src/server/app.py
from fastmcp import FastMCP
from pydantic import Field

mcp = FastMCP("Example MCP Server")

@mcp.tool()
async def greet(name: str = Field(..., description="挨拶する相手の名前")) -> str:
    """シンプルな挨拶ツール

    Args:
        name: 挨拶する相手の名前

    Returns:
        挨拶メッセージ

    Examples:
        >>> await greet("Alice")
        "Hello, Alice!"
    """
    return f"Hello, {name}!"

@mcp.resource("info://server")
async def server_info() -> str:
    """サーバー情報を返す"""
    return "Example MCP Server v1.0.0"
```

### 複雑な入出力を持つツール

```python
from typing import Literal
from pydantic import BaseModel, Field

class QueryRequest(BaseModel):
    """クエリリクエスト"""
    query: str = Field(..., description="検索クエリ")
    limit: int = Field(default=10, ge=1, le=100, description="結果数")
    order: Literal["asc", "desc"] = Field(default="desc", description="並び順")

class QueryResult(BaseModel):
    """クエリ結果"""
    items: list[dict[str, str]] = Field(..., description="結果アイテム")
    total: int = Field(..., description="総件数")

@mcp.tool()
async def search(request: QueryRequest) -> QueryResult:
    """データ検索ツール

    複雑な入出力を持つツールの例。
    Pydanticモデルで型安全性を確保。
    """
    # 検索ロジック
    items = [
        {"id": "1", "title": f"Result for {request.query}"}
    ]
    return QueryResult(items=items, total=len(items))
```

## 🔐 認証/認可パターン

### Google OAuth実装（完全版）

```python
# src/auth/oauth.py
from typing import Any
from urllib.parse import urlencode

import structlog
from google.auth.transport import requests
from google.oauth2 import id_token
from itsdangerous import URLSafeTimedSerializer

from src.config import get_config
from src.utils.exceptions import AuthenticationError

logger = structlog.get_logger()

class GoogleOAuthManager:
    """Google OAuth管理クラス"""

    def __init__(self) -> None:
        self.config = get_config()
        self._serializer = URLSafeTimedSerializer(
            self.config.session_secret_key
        )

    def get_authorization_url(self, state: str) -> str:
        """認証URLを生成

        Args:
            state: CSRF保護用の状態トークン

        Returns:
            Google認証ページURL
        """
        params = {
            "client_id": self.config.google_client_id,
            "redirect_uri": self.config.google_redirect_uri,
            "response_type": "code",
            "scope": "openid email profile",
            "state": state,
        }
        return f"https://accounts.google.com/o/oauth2/v2/auth?{urlencode(params)}"

    async def verify_token(self, token: str) -> dict[str, Any]:
        """IDトークンを検証

        Args:
            token: GoogleのIDトークン

        Returns:
            トークン情報

        Raises:
            AuthenticationError: トークン検証失敗
        """
        try:
            # トークン検証
            idinfo = id_token.verify_oauth2_token(
                token,
                requests.Request(),
                self.config.google_client_id,
            )

            # メールドメイン検証
            email = idinfo.get("email", "")
            if not email.endswith(f"@{self.config.allowed_email_domain}"):
                logger.warning(
                    "unauthorized_email_domain",
                    email=email,
                    allowed_domain=self.config.allowed_email_domain,
                )
                raise AuthenticationError(
                    f"Email domain not allowed: {email}"
                )

            logger.info("token_verified", email=email)
            return idinfo

        except ValueError as e:
            logger.error("token_verification_failed", error=str(e))
            raise AuthenticationError(f"Invalid token: {e}") from e

    def create_session_token(self, user_info: dict[str, Any]) -> str:
        """セッショントークンを生成

        Args:
            user_info: ユーザー情報

        Returns:
            署名付きセッショントークン
        """
        return self._serializer.dumps(user_info)

    def verify_session_token(
        self,
        token: str,
        max_age: int = 3600 * 24 * 7,  # 7日間
    ) -> dict[str, Any]:
        """セッショントークンを検証

        Args:
            token: セッショントークン
            max_age: 有効期限（秒）

        Returns:
            ユーザー情報

        Raises:
            AuthenticationError: トークン検証失敗
        """
        try:
            return self._serializer.loads(token, max_age=max_age)
        except Exception as e:
            logger.error("session_token_invalid", error=str(e))
            raise AuthenticationError("Invalid session token") from e
```

### FastAPI認証ミドルウェア

```python
# src/auth/middleware.py
from typing import Annotated

from fastapi import Depends, Header, HTTPException, status

from src.auth.oauth import GoogleOAuthManager

oauth_manager = GoogleOAuthManager()

async def get_current_user(
    authorization: Annotated[str, Header()],
) -> dict[str, Any]:
    """認証済みユーザーを取得

    依存性注入で使用。リクエストヘッダーからユーザーを取得。

    Args:
        authorization: Authorizationヘッダー

    Returns:
        ユーザー情報

    Raises:
        HTTPException: 認証失敗
    """
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header",
        )

    token = authorization.removeprefix("Bearer ")

    try:
        return oauth_manager.verify_session_token(token)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        ) from e

# 使用例
from fastapi import APIRouter

router = APIRouter()

@router.get("/me")
async def get_me(
    user: Annotated[dict[str, Any], Depends(get_current_user)],
) -> dict[str, Any]:
    """現在のユーザー情報を取得"""
    return user
```

## 🗄️ データベースパターン

### SQLAlchemy 2.0 非同期実装

```python
# src/repositories/user_repository.py
from typing import Protocol

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.models.user import User

class UserRepository(Protocol):
    """ユーザーリポジトリのインターフェース"""

    async def find_by_id(self, user_id: int) -> User | None:
        """IDでユーザーを検索"""
        ...

    async def find_by_email(self, email: str) -> User | None:
        """メールでユーザーを検索"""
        ...

    async def create(self, user: User) -> User:
        """ユーザーを作成"""
        ...

class SQLAlchemyUserRepository:
    """SQLAlchemyユーザーリポジトリ実装"""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def find_by_id(self, user_id: int) -> User | None:
        """IDでユーザーを検索"""
        stmt = select(User).where(User.id == user_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def find_by_email(self, email: str) -> User | None:
        """メールでユーザーを検索"""
        stmt = select(User).where(User.email == email)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def create(self, user: User) -> User:
        """ユーザーを作成"""
        self._session.add(user)
        await self._session.flush()  # IDを取得
        await self._session.refresh(user)  # リレーションを更新
        return user
```

### データベース接続管理

```python
# src/database.py
from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    create_async_engine,
)
from sqlalchemy.orm import sessionmaker

from src.config import get_config

config = get_config()

# 非同期エンジン作成
async_engine: AsyncEngine = create_async_engine(
    config.database_url,
    echo=config.environment == "development",  # 開発時のみSQLログ出力
    pool_size=5,
    max_overflow=10,
)

# セッションファクトリー
AsyncSessionLocal = sessionmaker(
    async_engine,
    class_=AsyncSession,
    expire_on_commit=False,  # コミット後もオブジェクト使用可能
)

async def get_db() -> AsyncIterator[AsyncSession]:
    """データベースセッションを提供

    FastAPIの依存性として使用。
    トランザクション管理を自動化。

    Yields:
        AsyncSession: データベースセッション

    Examples:
        @app.get("/users/{user_id}")
        async def get_user(
            user_id: int,
            db: AsyncSession = Depends(get_db),
        ):
            ...
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

## 📝 構造化ロギング

### structlog完全設定

```python
# src/utils/logger.py
import logging
import sys

import structlog

from src.config import get_config

def setup_logging() -> None:
    """構造化ロギングを設定

    環境に応じてログフォーマットを切り替え:
    - 開発環境: 人間が読みやすいConsole形式
    - 本番環境: JSON形式（Cloud Logging対応）
    """
    config = get_config()

    # 標準ログレベル設定
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, config.log_level),
    )

    # プロセッサチェーン
    processors = [
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
    ]

    # 環境別レンダラー
    if config.environment == "development":
        processors.append(structlog.dev.ConsoleRenderer())
    else:
        processors.append(structlog.processors.JSONRenderer())

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

# 使用例
import structlog

logger = structlog.get_logger()

# 構造化ログ
logger.info(
    "user_registered",
    user_id=user.id,
    email=user.email,
    registration_method="oauth",
)

# エラーログ（スタックトレース付き）
try:
    risky_operation()
except Exception as e:
    logger.error(
        "operation_failed",
        operation="risky_operation",
        error=str(e),
        exc_info=True,  # スタックトレースを含む
    )
```

## 🔄 エラーハンドリング

### カスタム例外階層

```python
# src/utils/exceptions.py
class AppException(Exception):
    """アプリケーション基底例外

    すべてのカスタム例外はこれを継承。
    HTTPステータスコードを持つ。
    """

    def __init__(
        self,
        message: str,
        status_code: int = 500,
        details: dict[str, Any] | None = None,
    ) -> None:
        self.message = message
        self.status_code = status_code
        self.details = details or {}
        super().__init__(self.message)

class NotFoundError(AppException):
    """リソースが見つからない"""

    def __init__(self, resource: str, resource_id: str | int) -> None:
        super().__init__(
            message=f"{resource} not found: {resource_id}",
            status_code=404,
            details={"resource": resource, "id": str(resource_id)},
        )

class AuthenticationError(AppException):
    """認証エラー"""

    def __init__(self, message: str = "Authentication failed") -> None:
        super().__init__(message=message, status_code=401)

class AuthorizationError(AppException):
    """認可エラー"""

    def __init__(self, message: str = "Permission denied") -> None:
        super().__init__(message=message, status_code=403)

class ValidationError(AppException):
    """バリデーションエラー"""

    def __init__(self, field: str, message: str) -> None:
        super().__init__(
            message=f"Validation error: {field}",
            status_code=422,
            details={"field": field, "error": message},
        )
```

### FastAPIエラーハンドラ

```python
# src/main.py
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import structlog

from src.utils.exceptions import AppException

logger = structlog.get_logger()
app = FastAPI()

@app.exception_handler(AppException)
async def app_exception_handler(
    request: Request,
    exc: AppException,
) -> JSONResponse:
    """アプリケーション例外のグローバルハンドラ

    すべてのAppException派生クラスをキャッチ。
    一貫したエラーレスポンスを返す。
    """
    logger.error(
        "app_exception",
        exception=exc.__class__.__name__,
        message=exc.message,
        status_code=exc.status_code,
        details=exc.details,
        path=request.url.path,
        method=request.method,
    )

    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.__class__.__name__,
            "message": exc.message,
            "details": exc.details,
        },
    )

@app.exception_handler(Exception)
async def generic_exception_handler(
    request: Request,
    exc: Exception,
) -> JSONResponse:
    """予期しない例外のハンドラ

    すべての未処理例外をキャッチ。
    500エラーを返す。
    """
    logger.exception(
        "unhandled_exception",
        exception=exc.__class__.__name__,
        path=request.url.path,
        method=request.method,
    )

    return JSONResponse(
        status_code=500,
        content={
            "error": "InternalServerError",
            "message": "An unexpected error occurred",
        },
    )
```

## 🧪 テストパターン

### テストファクトリー

```python
# tests/utils/factories.py
from datetime import datetime, timezone

from src.models.user import User

class UserFactory:
    """ユーザーテストデータファクトリー"""

    @staticmethod
    def create(
        id: int = 1,
        email: str = "test@example.com",
        name: str = "Test User",
        **kwargs,
    ) -> User:
        """ユーザーオブジェクトを生成

        デフォルト値を提供し、必要な値のみオーバーライド可能。
        """
        return User(
            id=id,
            email=email,
            name=name,
            created_at=kwargs.get("created_at", datetime.now(timezone.utc)),
            **kwargs,
        )

    @staticmethod
    def batch(count: int = 3, **kwargs) -> list[User]:
        """複数ユーザーを生成"""
        return [
            UserFactory.create(id=i, email=f"user{i}@example.com", **kwargs)
            for i in range(1, count + 1)
        ]
```

### パラメータ化テスト

```python
# tests/unit/test_validation.py
import pytest
from pydantic import ValidationError

from src.models.user import CreateUserRequest

@pytest.mark.unit
@pytest.mark.parametrize(
    "email,expected_valid",
    [
        ("valid@example.com", True),
        ("invalid-email", False),
        ("missing@", False),
        ("@missinglocal.com", False),
    ],
)
def test_email_validation(email: str, expected_valid: bool):
    """メールアドレスバリデーションのテスト"""
    if expected_valid:
        user = CreateUserRequest(
            email=email,
            name="Test User",
            password="password123",
        )
        assert user.email == email
    else:
        with pytest.raises(ValidationError):
            CreateUserRequest(
                email=email,
                name="Test User",
                password="password123",
            )
```

## 🔗 関連ドキュメント

- **web:developing-fastapi**: FastAPI設計原則
- **[TESTING.md](./TESTING.md)**: テスト戦略
- **[PROJECT-STRUCTURE.md](./PROJECT-STRUCTURE.md)**: コード配置
