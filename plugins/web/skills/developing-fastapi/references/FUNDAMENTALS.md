# FastAPI 基礎: プロジェクト構造・ルーティング・データモデル

FastAPI アプリケーションの土台となる部分——ディレクトリ構成、ルーティング、リクエストパラメータの受け取り方、Pydantic v2 によるデータ検証、レスポンスの型定義、エラーハンドリング——をまとめる。依存性注入・認証・永続化・非同期処理・テスト・デプロイ・生成AI連携・マイクロサービスは対象外（索引は `INSTRUCTIONS.md` を参照）。

Pydantic v2 モデルの使用・`response_model` の指定・全パラメータへの型注釈・`Annotated` 記法は確認不要のベストプラクティスとして本ファイル全体で適用する。

## プロジェクト構造

小規模な API は単一の `main.py` で十分だが、エンドポイントが増えるとルーター・スキーマ・ビジネスロジックをモジュールに分割する。

### 最小構成

```python
# main.py
from fastapi import FastAPI

app = FastAPI(title="My API", version="1.0.0")
```

### モジュール分割構成

機能（ドメイン）単位でディレクトリを切り、各機能が `router.py` / `schemas.py` / `service.py` を持つ構成が拡張に強い。

```
app/
├── main.py               # FastAPI() 生成・ルーター登録・ミドルウェア
├── core/
│   └── exceptions.py     # アプリ共通例外
├── users/
│   ├── router.py         # APIRouter・パスオペレーション
│   ├── schemas.py        # Pydantic モデル（Request/Response）
│   └── service.py        # ビジネスロジック
└── items/
    ├── router.py
    ├── schemas.py
    └── service.py
```

- **router.py**: HTTP に関する関心（パス・パラメータ・ステータスコード）のみを持ち、ビジネスロジックは `service.py` に委譲する。
- **schemas.py**: リクエスト/レスポンス用の Pydantic モデル。永続化層のモデル（SQLAlchemy 等）とは分離する（[DATA-PERSISTENCE.md](./DATA-PERSISTENCE.md)）。認証・DB セッション等の共有依存性は `core/dependencies.py` に集約する（[DEPENDENCIES.md](./DEPENDENCIES.md)）。

## ルーティングとパスオペレーション

### APIRouter によるエンドポイント分割

`APIRouter` はミニチュア版の `FastAPI` インスタンスで、`prefix` と `tags` を指定して `main.py` に取り込む。

```python
# users/router.py
from fastapi import APIRouter

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/{user_id}")
async def get_user(user_id: int) -> dict[str, int]:
    return {"user_id": user_id}
```

```python
# main.py
from fastapi import FastAPI

from app.users.router import router as users_router

app = FastAPI()
app.include_router(users_router)
```

### HTTP メソッドとステータスコード

パスオペレーションデコレータ（`@router.get` / `.post` / `.put` / `.patch` / `.delete`）は操作の意味に対応する HTTP メソッドを選ぶ。作成には `201 Created`、削除の成功には `204 No Content` を明示する。

```python
from fastapi import APIRouter, status

router = APIRouter(prefix="/items", tags=["items"])


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_item(item: ItemCreate) -> ItemRead: ...


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(item_id: int) -> None: ...
```

### パスオペレーションの評価順序

FastAPI はパスオペレーションを**登録順に評価**する。固定パスを可変パスより後に定義すると、可変パス（`/users/{user_id}`）が先に一致してしまい固定パス（`/users/me`）へ到達できない。

```python
# ✅ 固定パスを先に定義する
@router.get("/me")
async def get_current_user() -> UserRead: ...


@router.get("/{user_id}")
async def get_user(user_id: int) -> UserRead: ...
```

## リクエストパラメータ: path・query・body

FastAPI は関数シグネチャの型注釈からパラメータの取得元（パス・クエリ・ボディ）を推論する。パラメータの型と検証メタデータを分離できる **`Annotated` 記法を推奨**する。

### パスパラメータ

URL パスの一部を値として受け取る。型注釈だけで自動的に型変換・検証され、`Annotated[int, Path(ge=1)]` のように制約も付けられる。

```python
from fastapi import APIRouter

router = APIRouter(prefix="/items", tags=["items"])


@router.get("/{item_id}")
async def read_item(item_id: int) -> dict[str, int]:
    """item_id は URL 上の文字列を int にパース・検証してから渡される"""
    return {"item_id": item_id}
```

### クエリパラメータ

パスに含まれない関数パラメータはクエリパラメータとして扱われる。デフォルト値を持てば任意、`Annotated[T, Query(...)]` で境界値やバリデーションを付けられる。

```python
from typing import Annotated

from fastapi import APIRouter, Query

router = APIRouter(prefix="/items", tags=["items"])


@router.get("/")
async def list_items(
    q: Annotated[str | None, Query(min_length=3, max_length=50)] = None,
    tags: Annotated[list[str] | None, Query()] = None,
    skip: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=100)] = 10,
) -> dict[str, object]: ...
```

`str | None` は Python 3.10+ の union 記法。ページネーションのように複数エンドポイントで共有するクエリパラメータ群は、依存性関数にまとめると重複を避けられる（詳細は [DEPENDENCIES.md](./DEPENDENCIES.md)）。

### リクエストボディ

`POST` / `PUT` / `PATCH` で JSON ボディを受け取る場合は、Pydantic モデルを引数の型として宣言する。FastAPI が JSON をパースし、モデルに対して検証したうえで渡す。

```python
from fastapi import APIRouter
from pydantic import BaseModel


class ItemCreate(BaseModel):
    name: str
    price: float
    tags: list[str] = []


router = APIRouter(prefix="/items", tags=["items"])


@router.post("/")
async def create_item(item: ItemCreate) -> ItemCreate:
    return item
```

### パス・クエリ・ボディの併用

3種類のパラメータは1つの関数シグネチャに混在できる。FastAPI は型注釈だけでどこから値を取るかを判別する。

```python
@router.put("/{item_id}")
async def update_item(
    item_id: int,
    item: ItemCreate,
    q: Annotated[str | None, Query()] = None,
) -> ItemCreate: ...
```

単一の Pydantic モデルをボディの中でキー付きのネスト（`{"item": {...}}`）として受け取りたい場合は `Body(embed=True)` を使う（付けないと `ItemCreate` のフィールドがトップレベルに展開される）。

```python
from fastapi import Body


@router.put("/{item_id}")
async def update_item_embedded(
    item_id: int,
    item: Annotated[ItemCreate, Body(embed=True)],
) -> ItemCreate: ...
```

## Pydantic v2 モデルと検証

### BaseModel とフィールド制約

`Field()` で制約・デフォルト値・OpenAPI 用の説明を付与する。

```python
from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    email: EmailStr = Field(..., description="メールアドレス")
    name: str = Field(..., min_length=1, max_length=100)
    password: str = Field(..., min_length=8)
```

### リクエスト/レスポンスモデルの分離

共通フィールドを基底クラスに抽出し、継承で差分（パスワードの有無等）を表現する。レスポンスにパスワードのようなセンシティブな値を含めないことが目的。

```python
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserBase(BaseModel):
    email: EmailStr
    name: str = Field(..., min_length=1, max_length=100)


class UserCreate(UserBase):
    """リクエスト: パスワードを含む"""
    password: str = Field(..., min_length=8)


class UserRead(UserBase):
    """レスポンス: パスワードを含めない"""
    id: int
    created_at: datetime
```

### `model_config` によるモデル挙動の制御

Pydantic v2 では旧 `class Config` の代わりに `model_config = ConfigDict(...)` を使う。ORM オブジェクトから直接生成したいときは `from_attributes=True` を指定する。

```python
from pydantic import BaseModel, ConfigDict


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    name: str


# ORM インスタンス（例: SQLAlchemy の User）から直接生成できる
user_read = UserRead.model_validate(orm_user)
```

ORM 統合の詳細（SQLAlchemy/SQLModel との対応）は [DATA-PERSISTENCE.md](./DATA-PERSISTENCE.md) を参照。

### カスタムバリデータ

単一フィールドの検証は `field_validator`、複数フィールドをまたぐ検証は `model_validator` を使う。Pydantic v2 では両方とも `@classmethod`（`model_validator(mode="after")` はインスタンスメソッド）として書く。

```python
from datetime import date

from pydantic import BaseModel, field_validator, model_validator


class EventCreate(BaseModel):
    name: str
    start_date: date
    end_date: date

    @field_validator("name")
    @classmethod
    def name_must_not_be_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("name must not be blank")
        return v

    @model_validator(mode="after")
    def check_date_order(self) -> "EventCreate":
        if self.end_date <= self.start_date:
            raise ValueError("end_date must be after start_date")
        return self
```

バリデータが `ValueError` を投げると、FastAPI はそれを自動的に `422 Unprocessable Entity` の `RequestValidationError` へ変換する（次節を参照）。

### 部分更新モデル

`PATCH` のように「送られたフィールドだけ更新する」場合は、全フィールドを任意にした更新用モデルを別に定義し、`model_dump(exclude_unset=True)` で実際に送信されたフィールドだけを取り出す。

```python
from pydantic import BaseModel


class ItemUpdate(BaseModel):
    name: str | None = None
    price: float | None = None


@router.patch("/{item_id}")
async def patch_item(item_id: int, item: ItemUpdate) -> ItemRead:
    update_data = item.model_dump(exclude_unset=True)
    ...
```

## response_model とレスポンス制御

### 基本

`response_model` はエンドポイントが返す値の**外部向けの型**を宣言する。関数の戻り値の型注釈と一致させるのが基本だが、内部で ORM オブジェクト等を返しつつ外部形式を絞りたい場合は明示的に指定する。

```python
@router.get("/{user_id}", response_model=UserRead)
async def get_user(user_id: int) -> UserRead: ...


@router.get("/", response_model=list[UserRead])
async def list_users() -> list[UserRead]: ...
```

`response_model` を指定すると FastAPI は戻り値をそのモデルに対して検証・シリアライズし、モデルに存在しないフィールドは自動的に除外する。レスポンスにパスワード等を誤って含めてしまう事故を防ぐ効果がある。

### 主な追加オプション

- `response_model_exclude_unset=True`: デフォルト値のまま変更されなかったフィールドをレスポンスから省く（部分更新結果を返す用途で有用）。
- `responses={404: {"description": "Item not found"}}`: 正常系以外のレスポンス形式をエンドポイントごとに OpenAPI ドキュメントへ明示する。
- `response_model` を省略すると、関数の戻り値の型注釈がそのままレスポンスモデルとして使われる。両者が一致するなら省略してよいが、内部処理でモデル外の付加情報を返しつつ公開形式を絞りたい場合は明示する。

## エラーハンドリング

### HTTPException

想定内のエラー（リソースが見つからない・入力が不正等）は `HTTPException` を `raise` する。FastAPI が自動的に適切な JSON レスポンスへ変換する。

```python
from fastapi import APIRouter, HTTPException, status

router = APIRouter(prefix="/items", tags=["items"])


@router.get("/{item_id}")
async def read_item(item_id: int) -> ItemRead:
    item = await find_item(item_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Item {item_id} not found",
        )
    return item
```

### アプリケーション共通のカスタム例外

ドメイン固有のエラーは `HTTPException` を直接使うより、意味のある例外クラスの階層を用意して `raise` する側を読みやすくする。

```python
# core/exceptions.py
class AppError(Exception):
    """アプリケーション共通例外の基底クラス"""

    def __init__(self, message: str, status_code: int = 500) -> None:
        self.message = message
        self.status_code = status_code
        super().__init__(message)


class ItemNotFoundError(AppError):
    def __init__(self, item_id: int) -> None:
        super().__init__(f"Item not found: {item_id}", status_code=404)
```

### カスタム例外ハンドラ

`@app.exception_handler()` で例外クラスとレスポンス生成ロジックを結び付けると、各エンドポイントから `try/except` を排除できる。

```python
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from core.exceptions import AppError

app = FastAPI()


@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": exc.__class__.__name__, "message": exc.message},
    )
```

エンドポイント側は `raise ItemNotFoundError(item_id)` のみで済み、レスポンス形式の組み立てはハンドラに一元化される。

### バリデーションエラーのカスタマイズ

リクエストの検証に失敗すると FastAPI は既定で `422` と Pydantic のエラー詳細を返す。レスポンス形式を統一したい場合は `RequestValidationError` 用のハンドラを上書きする。

```python
from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


@app.exception_handler(RequestValidationError)
async def validation_error_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={"error": "ValidationError", "details": exc.errors()},
    )
```

認可エラー（401/403）やレート制限等の詳細な設計は [AUTH-SECURITY.md](./AUTH-SECURITY.md) を、例外ハンドラのテストは [TESTING.md](./TESTING.md) を参照。

## 品質チェックリスト

| チェック項目 | 内容 |
|---|---|
| 型注釈 | 全パラメータ・戻り値に型注釈があるか |
| response_model | 公開したくない内部フィールドが漏れていないか |
| Pydantic v2 記法 | `model_config = ConfigDict(...)` / `Annotated` を使っているか（`class Config` や裸の `Query()` デフォルト値は旧記法） |
| パラメータ制約 | `Field()` / `Query()` / `Path()` で境界値を宣言しているか |
| エラー応答 | 想定エラーを `HTTPException` かカスタム例外で明示しているか |
| パスの順序 | 固定パスが可変パスより先に定義されているか |

## 関連ドキュメント

- **[DEPENDENCIES.md](./DEPENDENCIES.md)**: 依存性注入の詳細パターン（スコープ・オーバーライド）
- **[AUTH-SECURITY.md](./AUTH-SECURITY.md)**: OAuth2/JWT による認証認可
- **[DATA-PERSISTENCE.md](./DATA-PERSISTENCE.md)**: SQLAlchemy/SQLModel/MongoDB との統合
- **[ASYNC-CONCURRENCY.md](./ASYNC-CONCURRENCY.md)**: 非同期処理・WebSocket・ストリーミング
- **[TESTING.md](./TESTING.md)**: TestClient・pytest によるテスト戦略
