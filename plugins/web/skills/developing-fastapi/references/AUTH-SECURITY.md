# 認証・認可の実装（Auth & Security）

FastAPI での認証・認可の**実装**（OAuth2PasswordBearer・JWT・パスワードハッシュ・スコープ/ロール認可・CORS）を扱う。JWT の構造・claims 設計・OWASP API Top 10・FAPI 等の脅威対策・標準の深掘りは `securing-web-apis`（`AUTHN-AUTHZ.md` / `OWASP-API-TOP10.md`）を参照。

> **Q4: 認証方式をユーザーに確認する（推測で進めない）**
> 自前 JWT 実装 / OAuth2 外部プロバイダ（Google・Auth0 等）/ セッションベースのいずれかは要件によって大きく異なる。本ファイルは主に自前 JWT 実装を扱い、他2方式は「外部プロバイダ / セッションベースという選択肢」節で導線を示す。

`Annotated[Type, Depends(...)]` 記法・全パラメータへの型注釈は確認不要のベストプラクティスとして本ファイル全体で適用する。

## 秘密情報の管理

JWT 署名鍵やアルゴリズムをコードに直接書いてはならない。`lru_cache` によるシングルトン依存性（`DEPENDENCIES.md` 参照）として設定を注入する。

```python
from functools import lru_cache
from typing import Annotated

from fastapi import Depends
from pydantic_settings import BaseSettings, SettingsConfigDict

class AuthSettings(BaseSettings):
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    model_config = SettingsConfigDict(env_file=".env")

@lru_cache
def get_auth_settings() -> AuthSettings:
    return AuthSettings()

AuthSettingsDep = Annotated[AuthSettings, Depends(get_auth_settings)]
```

以降の例では `settings: AuthSettingsDep` を介して `settings.secret_key` 等を取得する前提で記述する（誌面短縮のため一部スニペットでは受け渡しを省略する）。

## OAuth2PasswordBearer とパスワードハッシュ

### スキーム定義とパスワードハッシュ

```python
from fastapi.security import OAuth2PasswordBearer
from passlib.context import CryptContext

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)
```

> **実務上の注意**: `passlib` は開発が停滞しており、新しい `bcrypt` パッケージ（4.1系以降）との組み合わせで警告が出ることがある。新規プロジェクトでは `bcrypt` パッケージを直接使う、または Argon2 に対応した `pwdlib` を採用する選択肢もある。既存コードとの互換性を優先するなら `passlib` を維持してよい。いずれを選ぶ場合も平文パスワードの保存・ログ出力は厳禁。

### ユーザー認証とログインエンドポイント

```python
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel

app = FastAPI()

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

def authenticate_user(username: str, password: str) -> User | None:
    user = get_user(username)
    if user is None or not verify_password(password, user.hashed_password):
        return None
    return user

@app.post("/token", response_model=Token)
async def login_for_access_token(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    settings: AuthSettingsDep,
) -> Token:
    user = authenticate_user(form_data.username, form_data.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="ユーザー名またはパスワードが正しくありません",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = create_access_token(data={"sub": user.username}, settings=settings)
    return Token(access_token=access_token)
```

`OAuth2PasswordRequestForm` は `application/x-www-form-urlencoded` の `username`/`password` フィールドを要求する。この形式は `/docs` の "Authorize" ボタンと連携するための仕様であり、JSON ボディでログインしたい場合は自前の Pydantic モデルで代替してよいが `/docs` の認証 UI とは連携しなくなる。

## JWT アクセストークンの発行と検証

### 発行

```python
from datetime import datetime, timedelta, timezone

from jose import jwt

def create_access_token(data: dict, settings: AuthSettings) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.access_token_expire_minutes
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)
```

`exp`（expiration）claim を必ず付与する。有効期間は数分〜1時間程度に短く保ち、長期セッションはリフレッシュトークンで実現する（後述）。ライブラリは `python-jose`（`jose`）を使用しているが、`PyJWT` も同等の API を持つ代替として広く使われる。

### 検証（`get_current_user` 依存性）

```python
from typing import Annotated

from jose import JWTError, jwt
from pydantic import BaseModel

class TokenData(BaseModel):
    username: str | None = None

async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    settings: AuthSettingsDep,
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="認証情報を検証できませんでした",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        username = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except JWTError as exc:
        raise credentials_exception from exc

    user = get_user(username=token_data.username)
    if user is None:
        raise credentials_exception
    return user

CurrentUserDep = Annotated[User, Depends(get_current_user)]

@app.get("/users/me", response_model=UserRead)
async def read_users_me(current_user: CurrentUserDep) -> User:
    return current_user
```

`get_current_user` は「サブ依存性を持つ関数依存性」の一例であり、DI としての位置付けは `DEPENDENCIES.md` の「サブ依存性チェーン」節と同じ規則に従う。

### リフレッシュトークン

アクセストークンを短命に保ちつつユーザー体験を損なわないため、長命なリフレッシュトークンを併用する。

```python
def create_refresh_token(data: dict, settings: AuthSettings) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)

@app.post("/refresh", response_model=Token)
async def refresh_access_token(
    refresh_token: str,
    settings: AuthSettingsDep,
) -> Token:
    try:
        payload = jwt.decode(refresh_token, settings.secret_key, algorithms=[settings.algorithm])
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="無効なリフレッシュトークンです")
        username = payload.get("sub")
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="無効なリフレッシュトークンです"
        ) from exc

    access_token = create_access_token(data={"sub": username}, settings=settings)
    return Token(access_token=access_token)
```

ログアウトや漏洩時に即時無効化したい場合は、失効済みトークンの `jti`（JWT ID）claim を Redis 等の**ブロックリスト**に記録し、検証時に照合する。JWT は署名が有効な限り検証を通過してしまうため、失効管理には署名検証とは別のストアが必要になる。

## スコープベースの認可（OAuth2 Scopes）

OAuth2 の正式な仕組みとして、`OAuth2PasswordBearer` にスコープを宣言し `SecurityScopes` で検証する。スコープは `/docs` の Swagger UI にも表示され、クライアントが要求する権限をトークン発行時に明示できる。

```python
from fastapi import Security
from fastapi.security import SecurityScopes
from pydantic import ValidationError

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="token",
    scopes={"me": "自分の情報を読み取る", "items": "アイテムを読み取る"},
)

class TokenDataWithScopes(BaseModel):
    username: str | None = None
    scopes: list[str] = []

async def get_current_user_with_scopes(
    security_scopes: SecurityScopes,
    token: Annotated[str, Depends(oauth2_scheme)],
    settings: AuthSettingsDep,
) -> User:
    authenticate_value = (
        f'Bearer scope="{security_scopes.scope_str}"' if security_scopes.scopes else "Bearer"
    )
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="認証情報を検証できませんでした",
        headers={"WWW-Authenticate": authenticate_value},
    )
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        username = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenDataWithScopes(username=username, scopes=payload.get("scopes", []))
    except (JWTError, ValidationError) as exc:
        raise credentials_exception from exc

    user = get_user(username=token_data.username)
    if user is None:
        raise credentials_exception

    for scope in security_scopes.scopes:
        if scope not in token_data.scopes:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="権限が不足しています",
                headers={"WWW-Authenticate": authenticate_value},
            )
    return user

@app.get("/users/me/items/")
async def read_own_items(
    current_user: Annotated[User, Security(get_current_user_with_scopes, scopes=["items"])],
) -> list[dict]:
    return [{"item_id": "example", "owner": current_user.username}]
```

`Security(dep, scopes=[...])` は `Depends` と同じ解決規則で動くが、エンドポイントごとに要求スコープを宣言でき OpenAPI スキーマにも反映される点が異なる。ログイン時に発行するトークンの `scopes` claim には、そのユーザーが実際に許可された範囲だけを含めること。

## ロール/パーミッションベースの認可（依存性ファクトリ）

スコープほど厳密な標準化が不要な社内システムでは、ロール文字列をトークンに含め、依存性ファクトリで判定する実装も広く使われる。

```python
from collections.abc import Callable

def require_role(required_role: str) -> Callable[[User], User]:
    def role_checker(current_user: CurrentUserDep) -> User:
        if current_user.role != required_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="権限が不足しています",
            )
        return current_user

    return role_checker

@app.get("/admin")
async def read_admin_data(
    current_user: Annotated[User, Depends(require_role("admin"))],
) -> dict:
    return {"message": "管理者専用データ", "username": current_user.username}
```

戻り値を使わず「アクセス可否だけ」を確認したい場合は、エンドポイントのシグネチャに載せず `dependencies=[]` へ渡す。

```python
@app.delete(
    "/items/{item_id}",
    dependencies=[Depends(require_role("admin"))],
)
async def delete_item(item_id: int) -> dict:
    return {"item_id": item_id, "deleted": True}
```

複数ロールの許可や `read`/`write`/`delete` のような粒度の細かいパーミッションが必要な場合も、`require_role` と同じ「依存性ファクトリ」の形を保ったまま判定条件を拡張する。ロール・パーミッションの一覧はハードコードせず、DB や設定から取得できる構造にしておくと運用時の変更に強い。

## 外部プロバイダ / セッションベースという選択肢（Q4）

自前 JWT 実装以外の2択も要件次第で有効である。

| 方式 | 向いている場面 | 実装の要点 |
|------|--------------|-----------|
| OAuth2 外部プロバイダ | ユーザー管理を外部に委譲したい・SSO が必要 | `authlib` 等で `authorize_redirect` → `authorize_access_token` のコードフローを実装し、自プロジェクトはトークン検証のみを担う |
| セッションベース | サーバサイドで状態を持つ Web アプリ（SPA 以外） | `SessionMiddleware` を追加しセッションに認証状態を保存。CSRF 対策とセッション固定化対策が別途必要 |

```python
from starlette.middleware.sessions import SessionMiddleware
from starlette.requests import Request
from starlette.responses import RedirectResponse

app.add_middleware(SessionMiddleware, secret_key=settings.secret_key)

@app.get("/login")
async def login(request: Request) -> RedirectResponse:
    redirect_uri = request.url_for("auth_callback")
    return await oauth_client.provider.authorize_redirect(request, redirect_uri)

@app.get("/auth/callback")
async def auth_callback(request: Request) -> dict:
    token = await oauth_client.provider.authorize_access_token(request)
    request.session["user"] = dict(token["userinfo"])
    return {"message": "ログインしました"}
```

外部 IdP（Firebase Auth・Keycloak 等）を使う場合の具体的な統合手順は `cloud:developing-firebase` / `cloud:managing-keycloak` を参照。いずれの方式でも、`get_current_user` 相当の依存性を用意して DI チェーンへ接続すれば、本ファイルのエンドポイント保護パターン（スコープ/ロール判定）はそのまま再利用できる。

## CORSMiddleware

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.example.com"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
```

| 設定 | 注意点 |
|------|--------|
| `allow_origins=["*"]` | `allow_credentials=True` と併用禁止（ブラウザ仕様上ワイルドカードと認証情報送信は組み合わせられない） |
| `allow_origins` | ワイルドカードではなく許可するオリジンを明示的に列挙する |
| `allow_methods` / `allow_headers` | 必要なものだけを列挙し、`["*"]` は開発時のみに留める |

## セキュリティヘッダの付与

CORS はブラウザの送信元制御であり、レスポンス自体を保護するにはセキュリティヘッダを別途付与する。

```python
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains"
        return response

app.add_middleware(SecurityHeadersMiddleware)
```

各ヘッダの意味・CSP の設計・レートリミットとの組み合わせは `developing-web-apis`（`DESIGN-SECURITY.md`）を参照。OWASP API Top 10 や FAPI 準拠等の脅威対策の全体像は `securing-web-apis` を参照。

## 品質チェックリスト

| チェック項目 | 内容 |
|------------|------|
| 秘密鍵の管理 | `secret_key` をコードに直書きせず環境変数/Settings から注入 |
| `exp` claim | 全アクセストークンに有効期限を必ず設定（数分〜1時間） |
| パスワード保存 | 平文保存禁止。`bcrypt`/Argon2 等でハッシュ化 |
| `Annotated` 記法 | `Depends`/`Security` は `Annotated[Type, Depends(...)]` で統一 |
| スコープ/ロールの最小権限 | 発行するトークンには必要最小限のスコープ・ロールのみ含める |
| CORS 設定 | `allow_origins=["*"]` と `allow_credentials=True` の併用を避ける |
| HTTPS | 本番環境では常時 HTTPS。平文 HTTP でトークンを送受信しない |

## 関連ドキュメント

- `DEPENDENCIES.md`: DI の基礎（`get_current_user` が従う DI チェーンの規則）
- `FUNDAMENTALS.md`: エラーハンドリング・`response_model` の基本
- JWT の構造・claims 設計・OWASP API Top 10・FAPI 準拠は `securing-web-apis`（`AUTHN-AUTHZ.md` / `OWASP-API-TOP10.md`）を参照
- 全レスポンス共通のセキュリティヘッダ設計は `developing-web-apis`（`DESIGN-SECURITY.md`）を参照
