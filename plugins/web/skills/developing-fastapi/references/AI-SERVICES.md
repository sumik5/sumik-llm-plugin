# AI-SERVICES.md

生成 AI（LLM・画像/音声モデル等）を FastAPI でサービス化する際の設計判断とコード骨格。REST/GraphQL の一般的な実装は `FUNDAMENTALS.md` / `MICROSERVICES.md`、JS/Vercel AI SDK 側の実装は `ai:integrating-ai-web-apps`、RAG・LLMOps・ガードレール等のフレームワーク非依存パターンは `ai:designing-genai-patterns` を参照。本ファイルは **FastAPI で AI サービスを構築する際に固有の判断**に絞る。

## AskUserQuestion Q7: AI サービングの実装方式

内容を適用する前に、以下を確認する（推測で進めない）。
> ツールが使えない環境では、同じ選択肢をテキスト質問として提示して確認すること。

**モデルの推論をどこで・どう実行しますか？**
1. **プロセス内推論** — FastAPI プロセス自身がモデルをロードして直接推論する。軽量モデル・低同時実行数・レイテンシ最優先の場面に向く（→「モデルサービング戦略」の節）
2. **streaming 応答** — 推論の実行場所（プロセス内/外部）を問わず、応答をトークン単位で段階的に配信する。チャット UI 等、生成中の出力を見せたい場面で選ぶ（→「リアルタイムストリーミング応答」の節）
3. **外部モデルサーバー** — 推論そのものは BentoML 等の専用サービングフレームワークや GPU サーバーへ委譲し、FastAPI は API ゲートウェイ/オーケストレーション層に専念する。重量級モデル・高スループットが必要な場面で選ぶ（→「モデルサービング戦略」の節）

3つは排他ではなく組み合わせて使う（例: 外部モデルサーバーへ委譲しつつ、応答は streaming で返す）。

---

## なぜ FastAPI で AI サービスを構築するのか

生成 AI サービスのリクエストの多くは **I/O 待ち**（外部モデル API 呼び出し・ベクトル DB 検索・トークン生成のストリーム受信）が支配的である。FastAPI は ASGI を基盤に非同期 I/O をファーストクラスで扱えるため、1 リクエストがモデルの応答を待っている間も他のリクエストを処理できる。加えて Pydantic による型安全な入出力検証は、LLM が返す非決定的な出力を構造化して扱う際に特に有効になる（「型安全な AI サービス」の節を参照）。

## アーキテクチャ: Onion/Layered 設計

AI サービスは「API 層」「業務ロジック」「モデル呼び出し」「永続化」が絡み合いやすく、ルータ関数へ全部書くと肥大化・テスト困難になる。**依存性が外側から内側へのみ向く**層構造で分離する（Clean Architecture の依存関係逆転と同じ発想。DDD 的な戦略設計は `devkit:applying-clean-architecture` を参照）。

```
app/
├── main.py                          # FastAPI インスタンス生成・lifespan登録
├── api/routers/chat.py              # 【プレゼンテーション層】ルーティング・入出力スキーマ
├── services/chat_service.py         # 【アプリケーション層】プロンプト構築・業務ロジック
├── domain/entities.py               # 【ドメイン層】Conversation/Message 等のコアモデル
└── infrastructure/
    ├── model_clients/llm_client.py  # 【インフラ層】外部モデルプロバイダとの通信
    └── repositories/conversation_repository.py
```

- ルータは `services/` の関数を `Depends()` で呼ぶだけにし、モデル呼び出しの詳細を知らない
- `domain/` は外部 SDK（モデルプロバイダのクライアント等）に依存しない、テスト容易性の要
- モデルプロバイダを切り替える際は `infrastructure/model_clients/` の実装を差し替えるだけで済む（DI パターンの詳細は `DEPENDENCIES.md`）

```python
# api/routers/chat.py
from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.schemas import ChatRequest, ChatResponse
from app.services.chat_service import ChatService, get_chat_service

router = APIRouter(prefix="/chat", tags=["chat"])

@router.post("/", response_model=ChatResponse)
async def create_chat(
    request: ChatRequest,
    service: Annotated[ChatService, Depends(get_chat_service)],
) -> ChatResponse:
    return await service.generate_reply(request.message, request.conversation_id)
```

## ASGI: 非同期処理の基盤

FastAPI は ASGI（Asynchronous Server Gateway Interface、WSGI の非同期版後継）上に構築された Starlette を土台にする。ASGI は1接続あたり1スレッドを固定しないため、WebSocket やストリーミング応答のような長時間接続、および多数の同時実行中 I/O 待ちを少ないスレッドで扱える。Uvicorn が代表的な ASGI サーバー実装。AI サービスにとっての実務上の意味は次の2点。

- 外部モデル API 呼び出し中も同一 worker が他のリクエストを処理できる（「AI ワークロードの並行処理」の節を参照）
- トークンストリーミングや WebSocket による双方向通信を自然に実装できる（「リアルタイムストリーミング応答」の節を参照）

## 型安全な AI サービス

LLM の出力は本質的に非決定的かつ非構造化（自由テキスト）であり、そのまま下流へ渡すと型崩れ・欠損フィールドに気づけない。**LLM 出力もシステム境界の一種として Pydantic で検証する**。

```python
# api/schemas.py
from pydantic import BaseModel, Field

class ChatResponse(BaseModel):
    answer: str = Field(..., description="生成された回答本文")
    model: str = Field(..., description="使用したモデル識別子")
    tokens_used: int = Field(..., ge=0, description="消費トークン数")
    finish_reason: str = Field(..., description="stop / length / content_filter 等")
```

LLM プロバイダの JSON モード/構造化出力機能を使う場合も、受け取った JSON を素の `dict` で扱わず Pydantic モデルへパースしてから業務ロジックへ渡す。パース失敗（`ValidationError`）はハルシネーションや形式崩れの検知ポイントになる。

```python
from pydantic import ValidationError

async def parse_structured_output(raw_json: str) -> ChatResponse:
    try:
        return ChatResponse.model_validate_json(raw_json)
    except ValidationError:
        # リトライ / フォールバック応答 / エラーログ等の対応をここで行う
        raise
```

**`dataclass` と `BaseModel` の使い分け**: 外部境界（ユーザー入力・LLM 応答・DB 行）を跨ぐデータは検証コストを払って `BaseModel` を使う。サービス内部だけで受け渡すすでに検証済みの DTO は、検証オーバーヘッドのない `dataclass`（または `@dataclass(frozen=True)`）で十分な場合が多い。

## AI ワークロードの並行処理

モデルプロバイダ API 呼び出しはネットワーク I/O であり、`async def` + `await` で非同期化することで event loop を占有せず他のリクエストを処理できる。

```python
# infrastructure/model_clients/llm_client.py
import httpx

class LLMClient:
    def __init__(self, base_url: str, api_key: str) -> None:
        self._client = httpx.AsyncClient(base_url=base_url, timeout=30.0)
        self._api_key = api_key

    async def complete(self, prompt: str) -> str:
        response = await self._client.post(
            "/v1/completions",
            headers={"Authorization": f"Bearer {self._api_key}"},
            json={"prompt": prompt},
        )
        response.raise_for_status()
        return response.json()["choices"][0]["text"]
```

### 🔴 落とし穴: 同期呼び出しによる event loop のブロック

`async def` 内で**同期版**の SDK メソッドを呼ぶと、そのリクエストだけでなく worker 全体の event loop が呼び出し完了までブロックされ、他の全リクエストが停止する。同期 SDK しか提供されないプロバイダを使う場合は、スレッドプールへオフロードする。

```python
from anyio import to_thread

async def complete_with_sync_sdk(prompt: str) -> str:
    # 同期クライアントの呼び出しを別スレッドで実行し、event loop を解放する
    return await to_thread.run_sync(sync_llm_client.complete, prompt)
```

同じ理由で、ローカルでのトークナイズや埋め込み計算のような **CPU-bound** な処理も、重い場合は event loop 上で直接実行せずスレッドプール/別プロセスへ切り出す。

### レートリミットの制御

モデルプロバイダ側の RPM/TPM 制限に達しないよう、同時に送信するリクエスト数を `asyncio.Semaphore` で上限管理する。

```python
import asyncio

_rate_limiter = asyncio.Semaphore(10)  # 同時実行数の上限

async def rate_limited_complete(prompt: str) -> str:
    async with _rate_limiter:
        return await llm_client.complete(prompt)
```

## リアルタイムストリーミング応答

生成中のトークンを逐次返すことで、ユーザーは応答完了を待たずに結果を読み始められる（知覚レイテンシの改善）。FastAPI では SSE と WebSocket のいずれでも実装できる。

| 観点 | SSE（`StreamingResponse`） | WebSocket |
|------|---------------------------|-----------|
| 通信方向 | サーバー→クライアントの一方向 | 双方向 |
| 実装の単純さ | 通常の HTTP レスポンスの延長で単純 | 接続のライフサイクル管理が必要 |
| プロキシ/インフラ互換性 | 一般的な HTTP として通りやすい | WebSocket 対応の中継設定が必要な場合がある |
| 向く場面 | 生成結果を流すだけ（チャット応答の表示等） | クライアントからの中断・追加入力等、生成中に双方向でやり取りしたい場合 |

> API スタイル選定の一般的なトレードオフ（他の通信方式との比較）は `choosing-api-styles` を参照。ここでは LLM トークンストリーミングに限定した実装のみを示す。

### SSE での実装

```python
# api/routers/chat.py
from fastapi.responses import StreamingResponse

async def _token_stream(prompt: str):
    async for token in llm_client.stream_complete(prompt):
        yield f"data: {token}\n\n"
    yield "data: [DONE]\n\n"

@router.post("/stream")
async def stream_chat(request: ChatRequest) -> StreamingResponse:
    return StreamingResponse(
        _token_stream(request.message),
        media_type="text/event-stream",
    )
```

### WebSocket での実装

```python
from fastapi import WebSocket, WebSocketDisconnect

@router.websocket("/ws")
async def websocket_chat(websocket: WebSocket) -> None:
    await websocket.accept()
    try:
        while True:
            prompt = await websocket.receive_text()
            async for token in llm_client.stream_complete(prompt):
                await websocket.send_text(token)
            await websocket.send_text("[DONE]")
    except WebSocketDisconnect:
        pass  # クライアント切断時のクリーンアップはここで行う
```

## モデルサービング戦略（AskUserQuestion Q7 の詳細）

### プロセス内推論: `lifespan` によるモデルの事前ロード

リクエストごとにモデルをロードするのは（モデルサイズにより数秒〜数十秒かかるため）現実的でない。`lifespan` でアプリケーション起動時に一度だけロードし、`app.state` に保持する。

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.model = load_model()  # 起動時に1回だけロード
    yield
    app.state.model = None          # シャットダウン時に解放

app = FastAPI(lifespan=lifespan)
```

### 外部モデルサーバーへの委譲

FastAPI（+ Uvicorn の複数 worker 構成）は汎用 Web API には適するが、重量級モデルの推論には以下の制約がある。

- 各 worker プロセスが同じモデルを個別にメモリへロードするため、多 worker 構成ではメモリ効率が悪化する
- Python の GIL により、CPU-bound な推論をマルチスレッドで並列化できない
- 複数リクエストの入力をまとめて1回の推論にする**マイクロバッチ処理**をネイティブサポートしない
- CPU/GPU 間でのワークロード分割を管理する機構を持たない

これらが問題になる規模では、推論部分を BentoML のような AI モデルサービング専用フレームワークへ切り出す。BentoML は推論を担う「Runner」と API を受け付ける層を分離し、複数リクエストを自動でバッチ化する adaptive batching 等を備える。FastAPI 側は業務ロジック・認証・オーケストレーションに専念し、モデル呼び出しは HTTP/gRPC で外部サービス化した推論エンドポイントへ委譲する構成になる。

```python
# infrastructure/model_clients/external_model_client.py
class ExternalModelClient:
    """BentoML 等でホストされた外部推論サービスを呼ぶクライアント"""

    def __init__(self, endpoint: str) -> None:
        self._client = httpx.AsyncClient(base_url=endpoint, timeout=60.0)

    async def infer(self, payload: dict) -> dict:
        response = await self._client.post("/predict", json=payload)
        response.raise_for_status()
        return response.json()
```

## 最適化とデプロイ

- **キャッシュ**: 同一/類似プロンプトへの応答をキャッシュする。完全一致キャッシュに加え、埋め込みベースの類似度検索によるセマンティックキャッシュも有効（実装パターンは `ai:designing-genai-patterns` の Prompt Caching 等を参照）
- **バッチ処理**: 自前でモデルをホストする場合、同時に届いた複数リクエストを1回の推論にまとめることでスループットを向上できる（「モデルサービング戦略」の節で触れる BentoML 委譲がこれを標準機能として提供する）
- **量子化**: 自前ホストするモデルは INT8/4bit 等への量子化でメモリ使用量とレイテンシを削減できる。精度とのトレードオフがあるため評価が必要
- **コンテナデプロイ**: GPU を使う推論コンテナは GPU をコンテナへ露出する設定が必須。Docker 化・スケーリングの一般手順は `DEPLOYMENT-SCALING.md`、GPU/CUDA チューニングの深掘りは `ai:designing-genai-patterns` を参照

## まとめ・関連リファレンス

| 目的 | 参照先 |
|------|--------|
| REST/GraphQL の一般的な FastAPI 実装 | `MICROSERVICES.md` |
| DI・スコープ管理の詳細 | `DEPENDENCIES.md` |
| 本番デプロイ・スケーリング全般 | `DEPLOYMENT-SCALING.md` |
| JS/Vercel AI SDK でのウェブ AI 統合 | `ai:integrating-ai-web-apps` |
| RAG・LLMOps・ガードレール等フレームワーク非依存パターン | `ai:designing-genai-patterns` |
| LangChain/LangGraph 等でのエージェント構築 | `ai:building-ai-agents` |
