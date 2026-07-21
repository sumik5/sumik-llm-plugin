# テスト戦略（pytest + カバレッジ80%以上）

## 🎯 テスト方針

### テストの分類
- **単体テスト（unit/）**: 外部依存なし、高速実行
- **統合テスト（integration/）**: データベース、外部API等を含む

### カバレッジ目標
- **最低80%以上**を維持
- 重要なビジネスロジックは100%を目指す

## ⚙️ pytest設定（pyproject.toml）

```toml
# pyproject.tomlからの抜粋（実際の設定例）
[tool.pytest.ini_options]
minversion = "8.0"
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = [
    "-v",                      # 詳細出力
    "--strict-markers",        # 未定義markerでエラー
    "--tb=short",              # トレースバックを簡潔に
    "--cov=src",               # カバレッジ対象
    "--cov-report=html",       # HTMLレポート生成
    "--cov-report=term-missing", # ターミナルで未カバー行表示
    "--cov-fail-under=80",     # カバレッジ80%未満で失敗
    "-p", "no:warnings",       # 警告を抑制（必要に応じて）
]
markers = [
    "unit: Unit tests",
    "integration: Integration tests",
    "slow: Slow running tests",
    "skip_ci: Skip in CI environment",
]
asyncio_mode = "auto"          # async/awaitを自動検出
asyncio_default_fixture_loop_scope = "function"
```

## 📊 カバレッジ設定

```toml
[tool.coverage.run]
source = ["src"]
omit = [
    "*/tests/*",
    "*/__pycache__/*",
    "*/venv/*",
    "*/.venv/*",
]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
    "if __name__ == .__main__.:",
    "if TYPE_CHECKING:",
    "@abstractmethod",
    "@abc.abstractmethod",
]
precision = 2
show_missing = true
```

**重要な設定：**
- `--cov-fail-under=80`: カバレッジ80%未満でCI失敗
- `show_missing = true`: カバーされていない行を表示
- `exclude_lines`: カバレッジから除外する行パターン

## 🧪 conftest.py - 共通設定

```python
# tests/conftest.py
"""
Pytest設定と共通fixture

Design Principles:
- DRY: 共通のセットアップを一元化
- Isolation: 各テストは独立した環境変数で実行
- Clarity: fixture名とdocstringで用途を明示
"""

import os
import pytest

# ==============================================================================
# 環境変数セットアップ（モジュールインポート前に実行）
# ==============================================================================

# IMPORTANT: 環境変数はテストモジュールのインポート前に設定
# src.config等が正常に読み込まれることを保証

os.environ["ENVIRONMENT"] = "development"
os.environ["LOG_LEVEL"] = "DEBUG"

# Google OAuth設定（テスト用）
os.environ["GOOGLE_CLIENT_ID"] = "test-client-id.apps.googleusercontent.com"
os.environ["GOOGLE_CLIENT_SECRET"] = "GOCSPX-test-secret"
os.environ["GOOGLE_REDIRECT_URI"] = "http://localhost:8080/auth/callback"
os.environ["ALLOWED_EMAIL_DOMAIN"] = "example.com"

# GCP設定（テスト用）
os.environ["GCP_PROJECT_ID"] = "test-project-id"
os.environ["BIGQUERY_DATASET"] = "test_dataset"

# セッション設定
os.environ["SESSION_SECRET_KEY"] = "test-secret-key-for-session-encryption-min-32-chars"

# サーバー設定
os.environ["PORT"] = "8080"
os.environ["HOST"] = "0.0.0.0"


@pytest.fixture(autouse=True)
def reset_config_cache():
    """設定キャッシュをリセットしてテストの独立性を保証

    Scope: function（各テストごとに実行）
    Autouse: True（全テストに自動適用）
    """
    from src.config import get_config

    # キャッシュされた設定をクリア
    if hasattr(get_config, "_instance"):
        delattr(get_config, "_instance")

    yield

    # テスト後もクリーンアップ
    if hasattr(get_config, "_instance"):
        delattr(get_config, "_instance")


def pytest_configure(config):
    """pytestマーカーを登録"""
    config.addinivalue_line("markers", "unit: Unit tests")
    config.addinivalue_line("markers", "integration: Integration tests")
    config.addinivalue_line("markers", "slow: Slow running tests")
    config.addinivalue_line("markers", "skip_ci: Skip in CI environment")

    # カバレッジ向上のため、main.pyを早期インポート
    from contextlib import suppress

    with suppress(Exception):
        import src.main  # noqa: F401
```

**重要な原則：**
- **環境変数は最初に設定**: モジュールインポート前に環境変数を設定
- **autouse fixture**: すべてのテストで自動的に設定をリセット
- **早期インポート**: カバレッジ向上のためmain.pyを事前インポート

## 🧩 Fixtureパターン

### 基本的なfixture

```python
@pytest.fixture
def sample_user():
    """テスト用ユーザーデータ"""
    return User(
        id=1,
        email="test@example.com",
        name="Test User",
    )

@pytest.fixture
async def db_session():
    """データベースセッション（トランザクション自動ロールバック）"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.rollback()  # テスト後は必ずロールバック
```

### モック用fixture

```python
@pytest.fixture
def mock_bigquery_client(mocker):
    """BigQueryクライアントのモック"""
    mock_client = mocker.MagicMock()
    mock_client.query.return_value.result.return_value = []
    return mock_client
```

## 🧪 単体テストの例

### Pydanticモデルのテスト

```python
# tests/unit/test_models.py
import pytest
from pydantic import ValidationError

from src.models.user import User, CreateUserRequest

@pytest.mark.unit
def test_user_model_valid():
    """正常なユーザーモデル作成"""
    user = User(
        id=1,
        email="test@example.com",
        name="Test User",
    )
    assert user.id == 1
    assert user.email == "test@example.com"

@pytest.mark.unit
def test_user_model_invalid_email():
    """不正なメールアドレスでバリデーションエラー"""
    with pytest.raises(ValidationError) as exc_info:
        User(id=1, email="invalid-email", name="Test")

    errors = exc_info.value.errors()
    assert any(e["type"] == "value_error" for e in errors)
```

### サービス層のテスト（モック使用）

```python
# tests/unit/test_services.py
import pytest
from unittest.mock import AsyncMock

from src.services.user_service import UserService
from src.models.user import User

@pytest.mark.unit
@pytest.mark.asyncio
async def test_register_user(mocker):
    """ユーザー登録が成功する"""
    # Arrange: モックリポジトリを作成
    mock_repo = mocker.MagicMock()
    mock_repo.create = AsyncMock(return_value=User(
        id=1,
        email="new@example.com",
        name="New User",
    ))

    service = UserService(repository=mock_repo)

    # Act: ユーザー登録
    result = await service.register_user(
        email="new@example.com",
        name="New User",
    )

    # Assert: 結果を検証
    assert result.email == "new@example.com"
    mock_repo.create.assert_called_once()
```

## 🔗 統合テストの例

### FastAPI APIテスト

```python
# tests/integration/test_api.py
import pytest
from httpx import AsyncClient, ASGITransport

from src.main import app

@pytest.mark.integration
@pytest.mark.asyncio
async def test_health_check():
    """ヘルスチェックエンドポイントが正常に応答する"""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}

@pytest.mark.integration
@pytest.mark.asyncio
async def test_create_user_endpoint(db_session):
    """ユーザー作成エンドポイントが正常に動作する"""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/users/",
            json={
                "email": "test@example.com",
                "name": "Test User",
                "password": "securepassword",
            },
        )

    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "test@example.com"
    assert "password" not in data  # パスワードは返さない
```

## 🚀 テスト実行コマンド

### 基本的な実行

```bash
# すべてのテスト実行
uv run pytest

# 単体テストのみ実行
uv run pytest -m unit

# 統合テストのみ実行
uv run pytest -m integration

# 特定のファイルのみ実行
uv run pytest tests/unit/test_models.py

# 特定のテスト関数のみ実行
uv run pytest tests/unit/test_models.py::test_user_model_valid
```

### カバレッジレポート

```bash
# HTMLレポート生成（htmlcov/index.html）
uv run pytest --cov=src --cov-report=html

# ターミナルで詳細表示
uv run pytest --cov=src --cov-report=term-missing

# カバレッジ確認のみ（テストは実行しない）
uv run coverage report
```

### 並列実行（高速化）

```bash
# pytest-xdistを使用（要インストール）
uv add --dev pytest-xdist
uv run pytest -n auto  # CPU数に応じて並列実行
```

## 📈 カバレッジ80%を達成するコツ

### 1. 重要な部分を優先
- ビジネスロジック（services/）
- データバリデーション（models/）
- 認証/認可（auth/）

### 2. カバレッジ除外を適切に設定
```python
# カバレッジから除外（本当に不要な場合のみ）
def debug_function():  # pragma: no cover
    """デバッグ用関数"""
    print("Debug info")
```

### 3. エッジケースをテスト
- 正常系だけでなく異常系も
- バリデーションエラー
- 境界値テスト

### 4. モックを活用
- 外部API呼び出しはモック
- データベースアクセスはトランザクション管理

## ⚠️ よくある間違いと対処法

### 問題: 環境変数が読み込まれない
**原因**: テストモジュールのインポート前に環境変数が設定されていない

**解決**: conftest.pyで最初に環境変数を設定
```python
# conftest.pyの最初に配置
import os
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
```

### 問題: asyncテストが実行されない
**原因**: `@pytest.mark.asyncio`が不足

**解決**: 非同期テストには必ずマーカーを付ける
```python
@pytest.mark.asyncio
async def test_async_function():
    result = await async_function()
    assert result is not None
```

### 問題: テスト間で状態が共有される
**原因**: fixtureのscopeが不適切、またはキャッシュのクリア不足

**解決**: `autouse=True` fixtureでリセット
```python
@pytest.fixture(autouse=True)
def reset_state():
    # 状態をクリア
    yield
    # 後処理
```

## 🔗 関連ドキュメント

- **web:developing-fastapi** / **lang:developing-mcp**: FastAPI/FastMCPのテスト対象
- **[TOOLING.md](./TOOLING.md)**: pytest設定の詳細
- **[EXAMPLES.md](./EXAMPLES.md)**: より複雑なテストパターン
