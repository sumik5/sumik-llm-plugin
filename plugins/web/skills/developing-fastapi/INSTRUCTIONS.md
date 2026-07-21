# developing-fastapi: FastAPI Web API 開発ガイド

FastAPI での Web API 開発全体を実装レベルでカバーするガイド。ルーティング・永続化・DI・認証・非同期・テスト・デプロイ・生成AIサービス・マイクロサービス連携までの実装判断を支援する。

---

## 使用タイミング

以下の場面で本スキルをロードする。

- `pyproject.toml`/`requirements.txt` に `fastapi` がある、または `.py` ファイルが `import fastapi` している既存プロジェクトを扱うとき
- 新規 FastAPI プロジェクトのアプリケーション構造を立ち上げるとき
- エンドポイント（ルーティング・バリデーション・レスポンス）を実装・レビューするとき
- DB 永続化層（SQL/NoSQL）を実装するとき
- 依存性注入・認証・認可を設計するとき
- WebSocket/SSE 等リアルタイム機能を実装するとき
- pytest/TestClient によるテストを実装するとき
- 本番デプロイ・スケーリング構成を設計するとき
- 生成AI サービス（モデルサービング・streaming 応答）を FastAPI 上に構築するとき
- マイクロサービス間連携・GraphQL/OpenAPI 仕様駆動開発を行うとき

**隣接スキルとの境界**（判断に迷ったらこちらを先に確認する）:

| 相談内容 | 参照すべきスキル |
|---------|-----------------|
| Python 言語/ツーリング全般（uv・ruff・mypy・非 FastAPI パターン） | `lang:developing-python` |
| REST/HTTP 仕様設計・バージョニング・API テスト戦略そのもの | `developing-web-apis` |
| API セキュリティの深掘り（OWASP API Top 10・FAPI） | `securing-web-apis` |
| Node.js/Fastify のバックエンドサービス | `building-nodejs-services` |

---

## コア原則（要約）

FastAPI 実装で外さない6原則。詳細な実装パターンは各 reference（下の「詳細ガイド」）を参照。

### 1. プロジェクト構造

エンドポイント・スキーマ・DB モデル・ビジネスロジック・依存性を単一ファイルに集約しない。ドメイン単位で `router.py`（HTTP に関する関心のみ）・`schemas.py`（Pydantic モデル）・`service.py`（ビジネスロジック）に分割し、共有依存性は `core/dependencies.py` に集約する（詳細は `references/FUNDAMENTALS.md`）。プロジェクトが小さいうちは省略しがちだが、後からの分割は依存関係の絡み合いにより手戻りが大きい。

### 2. 型安全ルーティング

すべての path/query/body パラメータに型注釈を付け、FastAPI の自動検証・自動ドキュメント生成に委ねる。

```python
@router.get("/items/{item_id}")
async def get_item(item_id: int, q: str | None = None) -> ItemRead:
    ...
```

暗黙の型変換に頼るコード（未注釈の引数、`dict` を素通しするレスポンス）は書かない。固定パスは可変パスより**先**に定義する（評価順序の落とし穴）。

### 3. Pydantic v2

リクエスト用モデルとレスポンス用モデルを分離し、`model_config = ConfigDict(...)` で ORM 変換（`from_attributes=True`）やエイリアス方針を明示する。`Field()` で制約（`min_length`・`ge`・`max_length` 等）をスキーマに組み込み、バリデーションロジックをハンドラ側に書かない。

### 4. DI ファースト

DB セッション・現在のユーザー・設定オブジェクトなど横断的関心事はすべて `Depends()` で注入する。`Annotated[Type, Depends(dep)]` 記法を標準形とし、ハンドラ内でグローバル変数や直接インスタンス化に頼らない。

```python
async def create_item(
    item: ItemCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ItemRead:
    ...
```

この一貫性が下の「テスト容易性」を直接支える。

### 5. async 一貫性

async ライブラリ（非同期 DB ドライバ・httpx 等）を使う層は `async def` で貫き、`async def` ハンドラの中で同期ブロッキング呼び出し（同期 DB ドライバ・`time.sleep`・CPU バウンド処理）を行わない。同期処理が必要な場合は `run_in_threadpool` や `def`（FastAPI が自動的にスレッドプールで実行する）に切り出す。アプリ全体で同期/非同期を場当たり的に混在させない。

### 6. テスト容易性

DI で外部依存を注入する設計は、`dependency_overrides` によるテスト時の差し替えを可能にする。実装の初期段階から「このハンドラは何を注入されているか」を意識すると、後付けでモック不能なコードを避けられる。

---

## ユーザー確認の原則

**判断分岐がある場合、推測で進めず必ず AskUserQuestion ツールでユーザーに確認する**（AskUserQuestion が使えない環境では、同じ選択肢を通常のテキスト質問として提示して確認する）。

以下は各 reference 冒頭でも再掲される分岐の一覧。

| # | 分岐 | 選択肢 | 詳細 reference |
|---|------|--------|----------------|
| Q1 | DB 種別 | RDB(SQL) / NoSQL(MongoDB) | `references/DATA-PERSISTENCE.md` |
| Q2 | ORM/レイヤ | SQLAlchemy ORM / SQLModel / SQLAlchemy Core | `references/DATA-PERSISTENCE.md` |
| Q3 | DB ドライバ | 同期 / 非同期(asyncpg・motor) | `references/DATA-PERSISTENCE.md` |
| Q4 | 認証方式 | 自前 JWT / OAuth2 外部プロバイダ / セッション | `references/AUTH-SECURITY.md` |
| Q5 | リアルタイム方式 | WebSocket / SSE / polling | `references/ASYNC-CONCURRENCY.md` |
| Q6 | デプロイ形態 | uvicorn 単体 / gunicorn+uvicorn workers / コンテナ+K8s | `references/DEPLOYMENT-SCALING.md` |
| Q7 | AI サービング | プロセス内推論 / streaming / 外部モデルサーバ | `references/AI-SERVICES.md` |
| Q8 | API スタイル | REST / GraphQL（詳細比較は `choosing-api-styles` へ） | `references/MICROSERVICES.md` |

### 確認不要な場面

以下はベストプラクティスが明確なため、確認せず適用する。

- Pydantic v2 モデルを使うか → 使う（v1 混在は避ける）
- `response_model`/戻り値型注釈を指定するか → 指定する
- 全パラメータに型注釈を付けるか → 付ける
- `Annotated[T, Depends()]` 記法を使うか → 使う
- `TestClient`/`AsyncClient` をコンテキストマネージャで使うか → 使う（lifespan イベントを確実に発火させるため）

### AskUserQuestion 使用例

```python
AskUserQuestion(
    questions=[
        {
            "question": "永続化するデータストアの種別を選んでください。",
            "header": "DB 種別",
            "options": [
                {"label": "RDB (SQL)", "description": "スキーマが明確・トランザクション/JOINが必要な場合"},
                {"label": "NoSQL (MongoDB)", "description": "スキーマが可変・ドキュメント指向データの場合"}
            ],
            "multiSelect": False
        },
        {
            "question": "本番デプロイの形態を選んでください。",
            "header": "デプロイ形態",
            "options": [
                {"label": "uvicorn 単体", "description": "開発/小規模・単一プロセスで十分な場合"},
                {"label": "gunicorn+uvicorn workers", "description": "VM/ベアメタルで複数ワーカーを1プロセス群として管理する場合"},
                {"label": "コンテナ+K8s", "description": "水平スケーリング・オーケストレータでレプリカ管理する場合"}
            ],
            "multiSelect": False
        }
    ]
)
```

---

## クイックリファレンス

### DB 選択（Q1-Q3）

| 判断軸 | 選択肢 | 推奨判断基準 |
|--------|--------|-------------|
| DB 種別 | RDB / NoSQL | 関係性・トランザクション整合性が要る→RDB／スキーマ可変・ドキュメント指向→NoSQL |
| ORM/レイヤ（RDB時） | SQLAlchemy ORM / SQLModel / Core | 型注釈と Pydantic 連携を重視→SQLModel／既存資産・柔軟性重視→SQLAlchemy ORM／生SQL寄り→Core |
| ドライバ | 同期 / 非同期 | 新規プロジェクトかつ I/O 待ちが多い→非同期(asyncpg/motor)／既存同期コード資産が大きい→同期 |

### 認証方式（Q4）

| 選択肢 | 向いている場面 |
|--------|---------------|
| 自前 JWT (`OAuth2PasswordBearer`) | 認証基盤を自チームで完全に制御したい・外部依存を避けたい |
| OAuth2 外部プロバイダ | 既存 IdP（社内SSO等）に委譲したい・自前で認証ロジックを持ちたくない |
| セッション（Cookie） | サーバーサイドで状態管理する Web アプリ（SPA/モバイル API では非推奨） |

深掘り（OWASP API Top 10・FAPI 等の脅威対策）は `securing-web-apis` を参照。

### リアルタイム方式（Q5）

| 選択肢 | 向いている場面 |
|--------|---------------|
| WebSocket | 双方向・低レイテンシ通信が要る（チャット・協調編集） |
| SSE (`StreamingResponse`) | サーバー→クライアントの一方向 push で十分（通知・LLM streaming 応答） |
| polling | クライアント実装を単純化したい・リアルタイム性の要求が緩い |

### デプロイ形態（Q6）

| 選択肢 | 向いている場面 |
|--------|---------------|
| uvicorn 単体 | 開発環境・低トラフィックの検証環境 |
| gunicorn + uvicorn workers | VM/ベアメタルで単一ホスト上に複数ワーカーを配置したい |
| コンテナ + K8s | 水平スケーリング・自動復旧・ゼロダウンタイムデプロイが必要 |

詳細は `references/DEPLOYMENT-SCALING.md` を参照。

### API スタイル（Q8）

| 選択肢 | 向いている場面 |
|--------|---------------|
| REST | リソース指向・キャッシュ活用・広く枯れたエコシステムが欲しい |
| GraphQL (Strawberry) | クライアント側でレスポンス形状を柔軟に選びたい・複数リソースの一括取得が多い |

詳細なトレードオフ比較は `choosing-api-styles` を参照。

### 最小コード骨格

```python
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import Depends, FastAPI, Request, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict
from sqlalchemy.ext.asyncio import AsyncSession


class ItemCreate(BaseModel):
    name: str
    price: float


class ItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    price: float


async def get_db() -> AsyncIterator[AsyncSession]:
    """DB セッションを提供する依存性（詳細は references/DATA-PERSISTENCE.md）"""
    async with AsyncSessionLocal() as session:
        yield session


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    # 起動時処理（接続プール初期化・モデルロード等）
    yield
    # 終了時処理（接続クローズ等）


app = FastAPI(lifespan=lifespan)


@app.exception_handler(ValueError)
async def value_error_handler(request: Request, exc: ValueError) -> JSONResponse:
    return JSONResponse(status_code=status.HTTP_400_BAD_REQUEST, content={"detail": str(exc)})


@app.post("/items/", response_model=ItemRead, status_code=status.HTTP_201_CREATED)
async def create_item(
    item: ItemCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ItemRead:
    ...


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
```

---

## 詳細ガイド（references 索引）

| ファイル | 扱う内容 |
|---------|---------|
| [`references/FUNDAMENTALS.md`](references/FUNDAMENTALS.md) | プロジェクト構造・ルーティング・path/query/body params・Pydantic v2 モデルと検証・`response_model`・エラーハンドリング（`HTTPException`/カスタムハンドラ） |
| [`references/DATA-PERSISTENCE.md`](references/DATA-PERSISTENCE.md) | SQLAlchemy(Core/ORM)・SQLModel・非同期 DB(asyncpg/databases)・MongoDB(motor)・CRUD リポジトリ・Alembic マイグレーション |
| [`references/DEPENDENCIES.md`](references/DEPENDENCIES.md) | DI 概念(IoC/DIP)・関数/クラス依存性・サブ依存チェーン・スコープ(request/lru_cache/lifespan)・`dependency_overrides`・pytest fixtures |
| [`references/AUTH-SECURITY.md`](references/AUTH-SECURITY.md) | `OAuth2PasswordBearer`・JWT 発行/検証・パスワードハッシュ・スコープ/ロール認可・`CORSMiddleware`・セキュリティヘッダ |
| [`references/ASYNC-CONCURRENCY.md`](references/ASYNC-CONCURRENCY.md) | async/await・sync/async 混在の落とし穴・Starlette 基盤・`BackgroundTasks`・WebSocket・SSE/`StreamingResponse` |
| [`references/TESTING.md`](references/TESTING.md) | `TestClient`・pytest fixtures・httpx `AsyncClient`・`dependency_overrides` モック・DB テスト分離・lifespan テスト |
| [`references/DEPLOYMENT-SCALING.md`](references/DEPLOYMENT-SCALING.md) | uvicorn/gunicorn worker 構成・Docker 化・環境変数/Settings・スケーリング・パフォーマンス最適化・K8s デプロイ概要 |
| [`references/AI-SERVICES.md`](references/AI-SERVICES.md) | 生成AI×FastAPI・Onion/Layered アーキテクチャ・ASGI・モデルサービング・型安全 AI サービス・AI ワークロード並行処理・streaming 応答 |
| [`references/MICROSERVICES.md`](references/MICROSERVICES.md) | FastAPI での REST 実装・GraphQL(Strawberry) 実装・OpenAPI 仕様駆動開発・サービス間連携の FastAPI 固有部分 |

テスト方法論（TDD/AAA/4本柱）は `devkit:testing-code`、DevOps 全般（CI/CD/IaC）は `cloud:practicing-devops`、AI 統合の設計パターン全般は `ai:designing-genai-patterns` を併読すると理解が深まる。

---

## 品質チェックリスト

- [ ] すべての path/query/body パラメータに型注釈があるか
- [ ] すべてのエンドポイントに `response_model` または戻り値型注釈があるか
- [ ] リクエストモデルとレスポンスモデルを分離しているか（パスワード等の機密情報が応答に漏れていないか）
- [ ] 横断的関心事（DB セッション・現在のユーザー・設定）を `Depends()` で注入しているか
- [ ] `Annotated[T, Depends()]` 記法を統一して使っているか
- [ ] カスタム例外を `HTTPException` または `exception_handler` で一貫した形式に変換しているか
- [ ] `async def` ハンドラ内で同期ブロッキング呼び出しをしていないか
- [ ] テストで `dependency_overrides` により外部依存（DB・外部API）をモックしているか
- [ ] lifespan イベント（起動時/終了時処理）をテストでも発火させているか
- [ ] 本番用 Settings で `.env` の秘密情報がリポジトリに含まれていないか
- [ ] CORS 設定が本番用に絞られているか（開発用のワイルドカードを残していないか）
- [ ] ヘルスチェック用エンドポイントがあり、K8s の readiness/liveness probe から到達可能か

---

## まとめ（実装順の推奨）

判断に迷ったら以下の順で実装すると手戻りが少ない。

1. **プロジェクト構造 + FUNDAMENTALS**: ルーティングと Pydantic モデルの型安全性を最初に固める
2. **DATA-PERSISTENCE**: Q1-Q3 を確認し永続化層を実装する（DI 経由でハンドラに注入できる形にする）
3. **DEPENDENCIES**: DB セッション・設定等の DI パターンを整理し、テスト時の差し替え口を用意する
4. **AUTH-SECURITY**: Q4 を確認し認証・認可を実装する
5. **TESTING**: 実装と並行してテストを書く（後回しにするほど `dependency_overrides` の設計負債が増える）
6. **ASYNC-CONCURRENCY**: リアルタイム機能が必要なら Q5 を確認して実装する
7. **DEPLOYMENT-SCALING**: Q6 を確認し本番デプロイ構成を決定する
8. **AI-SERVICES / MICROSERVICES**: 要件に応じて Q7/Q8 を確認し追加実装する
