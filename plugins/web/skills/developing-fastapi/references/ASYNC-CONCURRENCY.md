# 非同期処理と並行性（async/await・Starlette・WebSocket・SSE）

> FastAPI の性能特性を支える非同期I/Oの基礎、`async def`/`def` 混在時に陥りやすい落とし穴、土台となる Starlette の役割、BackgroundTasks・WebSocket・SSE/StreamingResponse によるリアルタイム/非同期通信の実装パターンをまとめる。

---

## ユーザー確認事項（推測で進めない）

**判断分岐がある場合、推測で進めず必ず AskUserQuestion ツールでユーザーに確認する。**

| # | 分岐 | 選択肢 |
|---|------|--------|
| Q5 | リアルタイム方式 | WebSocket / SSE（Server-Sent Events） / ポーリング |

```python
AskUserQuestion(
    questions=[
        {
            "question": "サーバーからクライアントへのリアルタイム更新は、どの方式で実装しますか？",
            "header": "リアルタイム方式",
            "options": [
                {"label": "WebSocket", "description": "クライアント→サーバーの送信も必要な双方向通信（チャット・共同編集・ゲーム等）"},
                {"label": "SSE（Server-Sent Events）", "description": "サーバー→クライアントの一方向通知で十分（通知・進捗・ライブ更新等）。ブラウザ標準のEventSourceで自動再接続"},
                {"label": "ポーリング", "description": "更新頻度が低い・インフラ制約でWebSocket/SSEが使えない場合の簡易代替"},
            ],
            "multiSelect": False,
        },
    ]
)
```

確認**不要**（ベストプラクティスが明確）な場面: パス関数を `async def` で書くか同期 `def` で書くかの判断は「2. 同期と非同期の基礎」の基準表で決定できる。`await` の付け忘れ・同期ブロッキング呼び出しの混在は常に修正すべき欠陥であり、確認せず修正する。

---

## 同期と非同期の基礎

FastAPI のパスオペレーションは `def`（同期）と `async def`（非同期）のどちらでも定義できる。両者の違いは「どこで実行されるか」にある。

- **`async def`**: FastAPI が管理する ASGI イベントループ上で直接実行される。I/O待ち（DB問い合わせ・外部API呼び出し・ファイルI/O）の間、`await` によって制御をイベントループへ返し、他のリクエストの処理を進められる。
- **`def`**: FastAPI が内部の**スレッドプール**へ自動的にオフロードして実行する。開発者が意識しなくても、同期関数がイベントループを止めることはない。

この「`def` は自動でスレッドプール実行される」という仕組みこそが、FastAPI が同期コードと非同期コードを違和感なく混在させられる理由であり、同時に「3. sync/async混在の落とし穴」で説明する問題の背景でもある。

### イベントループとコルーチン

`async def` で定義した関数はコルーチン関数であり、呼び出しただけではコード本体は実行されず、コルーチンオブジェクトが返るだけ。実行するには `await` するか、`asyncio.gather()` 等でスケジュールする必要がある。

```python
import asyncio
import time


def sync_task() -> None:
    time.sleep(3)


async def async_task() -> None:
    await asyncio.sleep(3)


# 同期: 3タスクを直列実行 → 約9秒
start = time.time()
for _ in range(3):
    sync_task()
print(f"sync: {time.time() - start:.1f}s")


# 非同期: 3タスクを並行実行 → 約3秒
async def main() -> None:
    await asyncio.gather(async_task(), async_task(), async_task())


start = time.time()
asyncio.run(main())
print(f"async: {time.time() - start:.1f}s")
```

`time.sleep()` はブロッキングI/Oの、`asyncio.sleep()` はノンブロッキングI/Oのシミュレーションとして使われる典型例。イベントループは `await` を目印に「今どのコルーチンが実行可能か」を切り替えるスケジューラであり、FastAPI 自身がこのスケジューリングを行うため、開発者が `asyncio.run()` や `asyncio.gather()` を呼び出す必要は通常ない（パス関数は FastAPI が呼び出す）。

### `def` と `async def` の判断基準

| 状況 | 推奨 | 理由 |
|------|------|------|
| DB問い合わせ・外部API呼び出し等のI/Oを行う | `async def` + 非同期ドライバ | イベントループを解放し高い並行性を得る |
| CPUバウンドな計算処理 | `def`（スレッドプール）または別プロセス | asyncはI/O待ちの解消が目的で、CPU計算自体は速くならない（GILの制約は残る） |
| 同期専用ライブラリしか存在しない | `def` | FastAPI が自動でスレッドプール実行するため安全 |
| 高速に返るだけの単純な処理 | どちらでも良い | I/O待ちが無ければasyncのオーバーヘッドに実利は薄い |

---

## sync/async混在の落とし穴

### `await` を忘れる

`async def` の中で非同期呼び出しに `await` を付け忘れると、コルーチンオブジェクトが生成されるだけで実行されず、処理は素通りする。

```python
@app.get("/bad-sleep")
async def bad_sleep_example() -> dict[str, str]:
    asyncio.sleep(1)  # ❌ awaitし忘れ: 実際には1秒待たずに即座に返る
    return {"message": "これは即座に返る"}
```

`RuntimeWarning: coroutine ... was never awaited` が出た場合はほぼ確実にこのミス。

### `async def` の中で同期のブロッキング呼び出しをする（最重要の罠）

FastAPI が自動スレッドプール実行してくれるのは **`def` で定義したパス関数そのもの** に限られる。`async def` のパス関数の中で同期のブロッキング処理（`time.sleep()`・同期版 `requests.get()`・同期DBドライバのクエリ）を直接呼び出すと、その呼び出しは保護されない。

```python
@app.get("/blocks-everyone")
async def blocks_everyone() -> dict[str, str]:
    time.sleep(5)  # ❌ イベントループそのものを5秒間停止させる
    return {"message": "done"}
```

これが危険なのは「このリクエストだけ遅くなる」のではなく、**同一ワーカープロセスが処理中の全リクエストが同時に停止する**点にある。同期 `def` エンドポイントの遅延は他のリクエストに影響しないが、`async def` 内のブロッキング呼び出しは全体を止める。

対策は次のいずれか。

| 対策 | 使う場面 |
|------|---------|
| 非同期対応ライブラリへ置き換える | `httpx.AsyncClient`（HTTP）・`asyncpg`/`aiosqlite`/`motor`（DB）等、非同期版が存在する場合 |
| `asyncio.to_thread()`（Python 3.9+）でスレッドへ逃がす | 非同期版が存在しない同期専用ライブラリを使わざるを得ない場合 |
| エンドポイント自体を `def` にする | そのエンドポイントが常に同期処理のみで完結する場合。FastAPI が自動的にスレッドプールへ回す |

```python
import asyncio


def cpu_or_legacy_sync_call() -> str:
    time.sleep(5)  # 非async対応ライブラリの呼び出しを想定
    return "done"


@app.get("/safe-mixed")
async def safe_mixed() -> dict[str, str]:
    result = await asyncio.to_thread(cpu_or_legacy_sync_call)
    return {"message": result}
```

### 非同期DBドライバの選択ミス

同期の SQLAlchemy `Session` を `async def` の中でそのまま使うのも同じ問題を引き起こす。非同期で永続化を行うなら `create_async_engine` と非同期ドライバ（`asyncpg` / `aiosqlite`）で最後まで統一する（詳細は [DATA-PERSISTENCE.md](./DATA-PERSISTENCE.md)）。

```python
# ✅ 非同期ドライバで統一
from sqlalchemy.ext.asyncio import AsyncSession


async def get_users(db: AsyncSession) -> list[User]:
    result = await db.execute(select(User))
    return list(result.scalars().all())
```

---

## Starlette基盤とASGI

FastAPI はふたつの土台の上に構築されている。**Pydantic** がデータ検証を、**Starlette** がWeb/ASGIの実行機構を担う。Starlette は単体でも動く軽量なASGIフレームワークであり、FastAPI はその上にルーティングのシンタックスシュガー・依存性注入・自動ドキュメント生成(OpenAPI)・型検証を積み重ねている。

FastAPI が意識させずに使っている、Starlette 由来の機能:

| 機能 | 由来 |
|------|------|
| ルーティング基盤・ミドルウェア | Starlette |
| `BackgroundTasks` クラス自体 | Starlette |
| `WebSocket` / `StreamingResponse` の実行プリミティブ | Starlette |
| リクエスト/レスポンスのASGIレベル処理 | Starlette |
| Pydanticによる型検証・OpenAPIドキュメント生成・`Depends()` | FastAPI 独自 |

**ASGI（Asynchronous Server Gateway Interface）** は、Flask/Django が使う従来の同期的な **WSGI** を非同期対応に拡張した標準。WSGIは1リクエストあたりブロッキングI/Oを前提としており、DB・ファイル・ネットワークアクセスの待ち時間をそのまま浪費する。ASGIはこの待ち時間を非同期I/Oで埋められるため、Starlette（とその上のFastAPI）は最速級のPython Webフレームワークの一角を占める。

Starlette は直接アプリケーションを書くためにも使える。

```python
from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route


async def greeting(request):
    return JSONResponse({"message": "Hello? World?"})


app = Starlette(debug=True, routes=[Route("/hi", greeting)])
```

FastAPI がこの上に加える価値（型検証・自動ドキュメント・依存性注入）を実感するには、この最小限のStarletteコードと見比べるとよい。実務でStarletteを直接操作する必要はほとんどないが、「FastAPIの機能のどこまでがStarletteの機能か」を把握しておくと、ミドルウェアやWebSocket/StreamingResponseのドキュメントを読む際にStarletteのAPIリファレンスへ橋渡しできる。

> **参考**: `async`/`await` はPythonの言語機能であり、FastAPI/Starlette固有ではない。OS単位の並列処理（`multiprocessing`）・OSスレッド・green threads（`gevent`等）といった他の並行性手段も存在するが、FastAPI開発では基本的に `asyncio` 一本で十分であり、これらを直接扱う必要は生じにくい。

---

## BackgroundTasks

レスポンスをクライアントへ送信した**後**に実行してよい処理（通知メール送信・キャッシュ更新・ログ記録・アップロードされたファイルの後処理等）には `BackgroundTasks` を使う。

```python
from fastapi import BackgroundTasks, FastAPI

app = FastAPI()


def write_notification(email: str, message: str) -> None:
    with open("log.txt", mode="a") as f:
        f.write(f"notification for {email}: {message}\n")


@app.post("/send-notification/{email}")
async def send_notification(email: str, background_tasks: BackgroundTasks) -> dict[str, str]:
    background_tasks.add_task(write_notification, email, message="Hello World")
    return {"message": "Notification sent in the background"}
```

依存性として注入したサービスのメソッドも `add_task` に渡せる。

```python
from typing import Annotated

from fastapi import Depends


class NotificationService:
    def send_email(self, email: str, message: str) -> None: ...


def get_notification_service() -> NotificationService:
    return NotificationService()


@app.post("/send-email/{email}")
async def send_email(
    email: str,
    background_tasks: BackgroundTasks,
    service: Annotated[NotificationService, Depends(get_notification_service)],
) -> dict[str, str]:
    background_tasks.add_task(service.send_email, email, message="Welcome!")
    return {"message": "Email sending has been scheduled"}
```

### 注意点と限界

- **例外はクライアントに伝わらない**。`BackgroundTasks` 内で発生した例外はレスポンス送信後に発生するため、HTTPレスポンスへ反映できない。`try`/`except` で確実に捕捉し、ログへ記録すること。
- **プロセスと寿命を共にする**。ワーカープロセスが再起動・クラッシュすれば、実行中/未実行のタスクは失われる。リトライ・進捗の永続化・監視が必要なら `BackgroundTasks` では不十分。

| 判断基準 | 選択 |
|---------|------|
| 数秒〜数十秒で終わり、失敗しても致命的でない | `BackgroundTasks` |
| リトライ・スケジューリング・分散ワーカーへの分散が必要 | Celery / RQ / arq 等の本格的なタスクキュー |
| 進捗をクライアントがポーリング/購読する必要がある | タスクIDを発行しステータスを別エンドポイントで返す、または WebSocket/SSE で進捗配信 |

---

## WebSocket

WebSocket は**双方向**の永続接続で、チャット・共同編集・ライブダッシュボード・ゲーム等クライアントからの送信も必要な用途に向く（Q5参照）。

### ライフサイクルと基本パターン

```python
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI()


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            await websocket.send_text(f"Message received: {data}")
    except WebSocketDisconnect:
        print("Client disconnected")
```

接続は `accept()` で確立し、`receive_text()`/`receive_json()` と `send_text()`/`send_json()` で送受信を繰り返す。クライアントが切断すると `WebSocketDisconnect` が発生するので、`try`/`except` で切断時の後処理（下記の接続管理からの除去等）を行う。

### 複数クライアントの管理: ConnectionManagerパターン

```python
class ConnectionManager:
    def __init__(self) -> None:
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str) -> None:
        for connection in self.active_connections:
            await connection.send_text(message)


manager = ConnectionManager()


@app.websocket("/ws/{client_id}")
async def chat_endpoint(websocket: WebSocket, client_id: int) -> None:
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            await manager.broadcast(f"Client #{client_id} says: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        await manager.broadcast(f"Client #{client_id} left the chat")
```

接続を辞書（`dict[str, WebSocket]`）で管理すればユーザー単位の個別送信（プライベートメッセージ）も実装できる。メッセージをJSON化してPydanticモデルで検証すれば、構造化されたメッセージのやり取りも型安全に行える。

```python
class ChatMessage(BaseModel):
    sender: str
    message: str


data = await websocket.receive_json()
chat_message = ChatMessage(**data)  # 受信データもPydanticで検証する
```

### 認証の実務上の制約

ブラウザ標準の `WebSocket` API はカスタムHTTPヘッダを設定できないため、`Authorization: Bearer` ヘッダ方式の認証をそのまま持ち込めない。実務では以下のいずれかを使う。

| 方式 | 特徴 |
|------|------|
| クエリパラメータでトークンを渡す（`/ws?token=...`） | 実装が簡単。トークンがURL/アクセスログに残る点に注意 |
| 接続確立後、最初のメッセージで認証情報を送る | ログへの露出を避けられるが実装がやや複雑 |
| Cookie（httpOnly）による認証 | ブラウザが自動送信するため追加実装が少ない。CSRF対策は別途必要 |

`Depends()` はWebSocketエンドポイントの引数としても使えるため、`OAuth2PasswordBearer` 等の既存の認証依存性を再利用できる場合もある（詳細は [AUTH-SECURITY.md](./AUTH-SECURITY.md)）。

### 大規模化への配慮

単一プロセスの `ConnectionManager`（メモリ上のリスト/辞書）は複数ワーカープロセス・複数サーバーインスタンスに跨る接続を認識できない。ブロードキャストを全インスタンスに届けるには Redis Pub/Sub 等のメッセージブローカーを介する設計が必要になる（詳細な選定は `web:choosing-api-styles` を参照）。

テストは `TestClient` の `websocket_connect()` で同期的に書ける（詳細は [TESTING.md](./TESTING.md)）。

---

## SSE・StreamingResponse

### StreamingResponse: 汎用の逐次レスポンス

`StreamingResponse` はジェネレータ（同期/非同期どちらも可）が生成する値を順次クライアントへ送る。大きなファイルやCSVを**メモリに全部載せずチャンク単位で**返す用途に向く。

```python
from fastapi.responses import StreamingResponse


def iterfile(path: str):
    with open(path, mode="rb") as file_like:
        yield from file_like


@app.get("/download/{filename}")
async def download_file(filename: str) -> StreamingResponse:
    return StreamingResponse(
        iterfile(f"/data/{filename}"),
        media_type="application/octet-stream",
    )
```

### SSE（Server-Sent Events）: サーバー→クライアントの一方向配信

SSEは `StreamingResponse` の特殊なメディアタイプ（`text/event-stream`）で、`data: <本文>\n\n` という行フォーマットに従う。ブラウザ標準の `EventSource` API が自動的にパースし、接続が切れても**自動的に再接続**する点がWebSocketに対する利点。

```python
import asyncio

from fastapi.responses import StreamingResponse


async def event_generator():
    count = 0
    while True:
        count += 1
        yield f"data: Event {count}\n\n"
        await asyncio.sleep(1)


@app.get("/sse")
async def sse() -> StreamingResponse:
    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "Connection": "keep-alive"},
    )
```

手組みの代わりに `sse-starlette` ライブラリの `EventSourceResponse` を使うと、SSEフォーマットの組み立てや接続断の検知が簡潔に書ける。

長時間接続するSSE/StreamingResponseは、接続数の上限管理（同時接続をカウントし超過したら `503` を返す等）とクライアント切断時のクリーンアップ（`asyncio.CancelledError` の捕捉）を組み込むと安定する。

### WebSocket / SSE / ポーリングの判断基準

| 観点 | WebSocket | SSE | ポーリング |
|------|-----------|-----|-----------|
| 通信方向 | 双方向 | サーバー→クライアントのみ | クライアント主導の繰り返しリクエスト |
| ブラウザの自動再接続 | 自前実装が必要 | `EventSource` が自動対応 | 該当なし（毎回新規リクエスト） |
| プロキシ/ファイアウォール透過性 | 一部の中間装置で問題が出ることがある | 通常のHTTPなので透過しやすい | 最も高い |
| 実装コスト | 中〜高（接続管理が必要） | 低〜中 | 低 |
| 向いている用途 | チャット・共同編集・ゲーム | 通知・進捗表示・ライブフィード | 更新頻度が低い・要件が緩い場合 |

---

## まとめ

**実装の優先順位:**

1. **パス関数は「I/Oを待つか」で `async def`/`def` を決める**。CPUバウンドな処理をasyncにしても速くはならない。
2. **`async def` の中では同期のブロッキング呼び出しを絶対に行わない**。避けられない場合は `asyncio.to_thread()` でスレッドへ逃がす。
3. **非同期ドライバを選んだら永続化層まで一貫して非同期にする**（詳細は [DATA-PERSISTENCE.md](./DATA-PERSISTENCE.md)）。
4. **BackgroundTasksは「レスポンス後に少し実行するだけの軽い処理」に限定**し、リトライや永続化が要るならタスクキューへ移行する。
5. **リアルタイム方式（WebSocket/SSE/ポーリング）はQ5で必ず確認**し、双方向性の要否で判断する。
6. **WebSocket/非同期処理のテストはTestClient/httpxで書ける**（詳細は [TESTING.md](./TESTING.md)）。

## 関連ドキュメント

- **[FUNDAMENTALS.md](./FUNDAMENTALS.md)**: プロジェクト構造・ルーティング・エラーハンドリングの基礎
- **[DEPENDENCIES.md](./DEPENDENCIES.md)**: 依存性のスコープ・`lifespan` による起動/終了処理
- **[DATA-PERSISTENCE.md](./DATA-PERSISTENCE.md)**: 非同期DBドライバとの統合
- **[TESTING.md](./TESTING.md)**: WebSocket・非同期エンドポイントのテスト方法
- **[AI-SERVICES.md](./AI-SERVICES.md)**: 生成AIのstreaming応答・AIワークロードの並行処理
- `devkit:testing-code`: テスト方法論（TDD/AAA/4本柱）
- `web:choosing-api-styles`: WebSocket/SSE/メッセージングの詳細なトレードオフ比較
- `ai:integrating-ai-web-apps`: JavaScript/Vercel AI SDK側のstreaming実装
