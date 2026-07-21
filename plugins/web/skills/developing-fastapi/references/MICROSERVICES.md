# MICROSERVICES.md

マイクロサービス間で公開する Web API を FastAPI で実装する際の、**FastAPI 固有の実装パターン**。マイクロサービスの設計原則（サービス粒度・データ所有権・Saga・Event Sourcing 等）は `cloud:architecting-infrastructure`、REST の設計原則（リソース設計・HTTP セマンティクス・バージョニング）は `developing-web-apis`、REST/GraphQL/gRPC 等の API スタイル選定は `choosing-api-styles` を参照。本ファイルはこれらの一般原則を前提に、FastAPI での実装だけを扱う。

## AskUserQuestion Q8: API スタイルの選択

内容を適用する前に、以下を確認する（推測で進めない）。
> ツールが使えない環境では、同じ選択肢をテキスト質問として提示して確認すること。

**このサービスの API スタイルはどちらですか？**
1. **REST** — リソース指向。クライアントが単純、HTTP キャッシュ/監視ツールをそのまま活用できる（→「FastAPI での REST 実装」の節）
2. **GraphQL** — クエリ指向。クライアントごとに異なるデータ形状が必要、または複数バックエンドを統合したい場合（→「GraphQL（Strawberry）実装」の節）

詳細なトレードオフ比較（N+1 問題・キャッシュ戦略・セキュリティ考慮点等）は `choosing-api-styles` の判断軸を参照した上で選ぶ。

---

## FastAPI での REST 実装

### ルータによるリソース単位の分割

サービス内のリソースごとに `APIRouter` を分け、`main.py` で束ねる。マイクロサービス間の境界が明確な場合、この分割はそのままサービス分割の単位に対応する。

```python
# api/routers/orders.py
from typing import Annotated

from fastapi import APIRouter, Depends, status

router = APIRouter(prefix="/orders", tags=["orders"])

@router.post("/", response_model=OrderRead, status_code=status.HTTP_201_CREATED)
async def create_order(
    payload: OrderCreate,
    service: Annotated[OrderService, Depends(get_order_service)],
) -> OrderRead:
    return await service.create(payload)
```

```python
# main.py
from fastapi import FastAPI

from api.routers import kitchen, orders

app = FastAPI(title="Orders Service")
app.include_router(orders.router)
app.include_router(kitchen.router)
```

### 未知フィールドの拒否

外部サービスから受け取るペイロードに想定外のフィールドが混入しても気づけないと、契約違反が無言で通過してしまう。Pydantic v2 の `extra="forbid"` で未知フィールドをエラーにできる。

```python
from pydantic import BaseModel, ConfigDict

class OrderCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")  # 未知フィールドで ValidationError
    items: list[str]
    customer_id: str
```

`extra` は `"forbid"`（拒否）・`"ignore"`（無視して破棄）・`"allow"`（保持）の3択。サービス間契約を厳密に守らせたい境界では `"forbid"` を既定にする。

### 業務ロジックの分離

ルータに業務ロジックを直接書くと、サービス間で共有すべきルールがルータ層に埋もれる。ルータは入出力の変換のみを担当し、実処理は `Depends()` で注入するサービス層に委譲する（DI の詳細は `DEPENDENCIES.md`、レイヤ構成の設計原則は `devkit:applying-clean-architecture` を参照）。

## OpenAPI 仕様駆動開発

FastAPI はルート定義から OpenAPI 仕様を自動生成し `/docs`（Swagger UI）・`/openapi.json` で公開する。サービス間連携では、この自動生成仕様を**契約**として扱えるかどうかが重要になる。

### operationId・タグ・要約の明示

自動生成される `operationId` はデフォルトで関数名ベースになり、ルート名が変わると契約が意図せず変化する。クライアントコード生成を前提にするなら明示的に固定する。

```python
@router.post(
    "/",
    response_model=OrderRead,
    tags=["orders"],
    summary="注文を新規作成する",
    operation_id="createOrder",
)
async def create_order(...) -> OrderRead: ...
```

サービス全体で命名規則を統一したい場合は `generate_unique_id_function` で生成ロジック自体を上書きする。

```python
from fastapi import FastAPI
from fastapi.routing import APIRoute

def custom_generate_unique_id(route: APIRoute) -> str:
    return f"{route.tags[0]}_{route.name}"

app = FastAPI(generate_unique_id_function=custom_generate_unique_id)
```

### 自動生成スキーマの上書き

自動生成される仕様に手動で情報を追加/上書きしたい場合（ベンダー拡張フィールド・複数サービス共通のエラーレスポンス定義等）は `app.openapi` を差し替える。

```python
from fastapi.openapi.utils import get_openapi

def custom_openapi() -> dict:
    if app.openapi_schema:
        return app.openapi_schema
    schema = get_openapi(title=app.title, version=app.version, routes=app.routes)
    schema["components"]["schemas"]["Error"] = {
        "type": "object",
        "properties": {"detail": {"type": "string"}, "code": {"type": "string"}},
    }
    app.openapi_schema = schema
    return app.openapi_schema

app.openapi = custom_openapi
```

### スキーマ先行（Spec-First）で進める場合

サービス間の契約を先に固めたい場合は、OAS（`oas.yaml`）を先に書き、FastAPI の自動生成スキーマがそれに一致するかを CI で検証する運用も可能。仕様記述の方法論・契約テスト（Pact 等）は `developing-web-apis` を参照。

## GraphQL（Strawberry）実装

FastAPI 自体は GraphQL をネイティブサポートしないため、Strawberry（型ヒントから直接スキーマを組み立てる code-first ライブラリ）等の追加ライブラリで実装する。

```bash
pip install "strawberry-graphql[fastapi]"
```

### 型・Query・Mutation の定義

```python
# graphql/types.py
import strawberry

@strawberry.type
class Item:
    id: strawberry.ID
    name: str
    price: float

@strawberry.type
class Query:
    @strawberry.field
    async def item(self, info: strawberry.types.Info, id: strawberry.ID) -> Item | None:
        repo: ItemRepository = info.context["item_repo"]
        return await repo.get(id)

    @strawberry.field
    async def items(self, info: strawberry.types.Info) -> list[Item]:
        repo: ItemRepository = info.context["item_repo"]
        return await repo.list_all()

@strawberry.type
class Mutation:
    @strawberry.mutation
    async def create_item(
        self, info: strawberry.types.Info, name: str, price: float,
    ) -> Item:
        repo: ItemRepository = info.context["item_repo"]
        return await repo.create(name=name, price=price)
```

### FastAPI へのマウントと DI の橋渡し

`GraphQLRouter` は通常の `APIRouter` と同様に `include_router` でマウントできる。FastAPI の `Depends()` による DI 結果を GraphQL リゾルバへ渡すには `context_getter` を使う。

```python
# main.py
from typing import Annotated

import strawberry
from fastapi import Depends, FastAPI
from strawberry.fastapi import GraphQLRouter

from graphql.types import Mutation, Query

async def get_context(
    item_repo: Annotated[ItemRepository, Depends(get_item_repository)],
) -> dict:
    return {"item_repo": item_repo}

schema = strawberry.Schema(query=Query, mutation=Mutation)
graphql_app = GraphQLRouter(schema, context_getter=get_context)

app = FastAPI()
app.include_router(graphql_app, prefix="/graphql")
```

これにより REST エンドポイントと GraphQL エンドポイントで同一のリポジトリ/サービス層を共有でき、Onion/Layered な業務ロジックを重複させない（`AI-SERVICES.md` の「アーキテクチャ: Onion/Layered 設計」の節と同じ発想）。

### N+1 問題への対処

リレーションを持つ型をネストして取得すると N+1 クエリが発生しやすい点は GraphQL 一般の課題であり、`strawberry.dataloader.DataLoader` でバッチ化して解決する。概念的な N+1 問題の説明は `choosing-api-styles` を参照。

```python
from strawberry.dataloader import DataLoader

async def batch_load_items(ids: list[str]) -> list[Item]:
    rows = await item_repo.get_many(ids)  # 1回のクエリでまとめて取得
    by_id = {row.id: row for row in rows}
    return [by_id[i] for i in ids]

item_loader = DataLoader(load_fn=batch_load_items)
```

## サービス間連携の FastAPI 固有部分

マイクロサービス間の呼び出し自体の設計（同期/非同期連携・Saga・イベント駆動）は `cloud:architecting-infrastructure` の対象。ここでは FastAPI サービスが**他の FastAPI サービスを HTTP で呼ぶ実装**に限定する。

```python
# infrastructure/clients/kitchen_client.py
import httpx

class KitchenServiceClient:
    def __init__(self, base_url: str) -> None:
        self._client = httpx.AsyncClient(base_url=base_url, timeout=5.0)

    async def schedule_order(self, order_id: str, items: list[str]) -> dict:
        response = await self._client.post(
            "/schedules", json={"order_id": order_id, "items": items},
        )
        response.raise_for_status()
        return response.json()
```

- タイムアウトは呼び出し先サービスごとに明示指定する（デフォルト無制限は避ける）
- リトライ・サーキットブレーカー等の耐障害性パターンは `cloud:architecting-infrastructure` の該当パターンを参照して組み込む
- 呼び出し先の OpenAPI 仕様からクライアントを自動生成すると、手書きクライアントとサービス側の契約のズレを防げる
- オーケストレーション層（API Gateway・BFF）から死活監視できるよう、各サービスに軽量な `/healthz` を公開する

```python
@app.get("/healthz", include_in_schema=False)
async def healthz() -> dict[str, str]:
    return {"status": "ok"}
```

## まとめ・関連リファレンス

| 目的 | 参照先 |
|------|--------|
| REST の設計原則（リソース設計・HTTP セマンティクス） | `developing-web-apis` |
| API スタイル選定のトレードオフ比較 | `choosing-api-styles` |
| マイクロサービス設計（粒度・Saga・Event Sourcing） | `cloud:architecting-infrastructure` |
| DI・依存性のスコープ管理 | `DEPENDENCIES.md` |
| 生成 AI サービス特有の実装 | `AI-SERVICES.md` |
| 本番デプロイ・スケーリング | `DEPLOYMENT-SCALING.md` |
