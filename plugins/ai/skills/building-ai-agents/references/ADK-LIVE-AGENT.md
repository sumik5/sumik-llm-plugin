# ADK Live Agent 詳細リファレンス

## 概要

ADK Live Agentは、テキストベースAgentをリアルタイム音声対話Agentへ昇格させる仕組みです。
`LiveRunner` + `LiveRequestQueue` + `RunConfig` の3コンポーネントが連携して、
Gemini Live Streaming APIとの複雑な双方向通信を完全に抽象化します。

---

## カスタムプロキシ（Ch2-3）vs ADK Live Agent（Ch4）比較

| 観点 | Ch2-3: カスタムプロキシ | Ch4: ADK Live Agent |
|------|----------------------|---------------------|
| **WebSocket管理** | 2つのWebSocketを手動管理（Frontend↔Proxy, Proxy↔Gemini） | RunnerがGemini側のWebSocketを完全に抽象化 |
| **ツール統合** | tool_call検出・実行・レスポンス返送を手動実装 | FunctionToolがそのまま動作（自動処理） |
| **セッション/メモリ** | 独自実装が必要 | ADK SessionService/MemoryServiceと統合済み |
| **コード量** | バックエンドが複雑（数百行規模） | `start_agent_session()`の定型パターンで完結 |
| **拡張性** | 機能追加のたびに手動連携が必要 | ADKの全機能（RAG/Callbacks/Multi-Agent等）をそのまま利用可能 |
| **適用場面** | 極低レイテンシが必要、ADK非依存が必要 | 通常のLive Agent開発（推奨） |

**移行の動機**: カスタムプロキシはアーキテクチャが複雑で、Agentらしい機能（ツール、メモリ、コンテキスト管理）の統合が困難。
ADK Live AgentはRunnerがその複雑さを吸収し、開発者はAgent設計に集中できる。

---

## コアコンポーネント

### LiveRunner

`InMemoryRunner` と同じ初期化方法。`run_live()` メソッドでLiveセッションを開始。

```python
from google.adk.runners import InMemoryRunner

runner = InMemoryRunner(app_name="my_app", agent=root_agent)

# Liveセッション開始
live_events = runner.run_live(
    session=session_obj,
    live_request_queue=live_request_queue,
    run_config=run_config,
)
```

**返り値**: `live_events` は非同期イテレータ。`async for event in live_events:` でイベントを逐次処理する。

---

### LiveRequestQueue

フロントエンドからの音声データをバッファリングするキュー。スレッドセーフな非同期データ転送を実現する。

```python
from google.adk.agents.live_request_queue import LiveRequestQueue

live_request_queue = LiveRequestQueue()

# 音声データ送信（フロントエンドメッセージハンドラーから呼び出す）
audio_blob = types.Blob(
    data=pcm_bytes,           # PCM 16kHz のバイト列
    mime_type="audio/pcm;rate=16000"
)
live_request_queue.send_realtime(audio_blob)
```

**音声フォーマット**: フロントエンドから受け取った Base64 PCM データをデコードして `Blob` に変換する。

---

### RunConfig

Liveセッションの音声設定を定義する。

```python
from google.adk.agents.run_config import RunConfig
from google.genai import types

run_config = RunConfig(
    response_modalities=["AUDIO"],   # "TEXT" も指定可能
    speech_config=types.SpeechConfig(
        voice_config=types.VoiceConfigDict({
            "prebuilt_voice_config": {
                "voice_name": "Aoede"  # 利用可能な音声名はGemini APIドキュメントを参照
            }
        }),
        language_code="en-GB"        # 言語コード（BCP-47形式）
    )
)
```

**response_modalities**:
- `["AUDIO"]`: 音声のみ出力
- `["TEXT"]`: テキストのみ出力
- `["AUDIO", "TEXT"]`: 両方出力

---

## live_events ストリームのイベント型

`runner.run_live()` が返す非同期イテレータから取り出せるイベント。

| イベント条件 | 属性 | 意味 | フロントエンドへの送信 |
|------------|------|------|---------------------|
| `event.interrupted == True` | `interrupted` | ユーザーが発話して応答を中断 | `{"type": "interrupted"}` を送信してオーディオ再生を停止 |
| `event.turn_complete == True` | `turn_complete` | エージェントの1ターン応答が完了 | `{"type": "turn_complete"}` を送信 |
| `event.content.parts[0].inline_data` が存在 | `content.parts[0].inline_data` | 音声データチャンク | `{"type": "audio", "data": <base64>}` を送信 |
| 上記以外 | - | 中間ステータス（ツール呼び出し中等） | スキップ |

```python
async def handle_agent_responses(client_ws, live_events):
    async for event in live_events:
        # 優先度順に判定
        if event.interrupted:
            await client_ws.send(json.dumps({
                "type": "interrupted",
                "data": {"message": "Response interrupted by user input"}
            }))
            continue

        if event.content is None:
            if event.turn_complete:
                await client_ws.send(json.dumps({
                    "type": "backend",
                    "data": "turn_complete"
                }))
            continue

        # 音声データチャンク
        inline_data = (
            event.content and
            event.content.parts and
            event.content.parts[0].inline_data
        )
        if inline_data and inline_data.mime_type.startswith("audio/pcm"):
            audio_base64 = base64.b64encode(inline_data.data).decode("utf-8")
            await client_ws.send(json.dumps({
                "type": "audio",
                "data": audio_base64
            }))

        await asyncio.sleep(0)  # イベントループに制御を返す
```

---

## セッション状態注入パターン（state=context）

`create_session()` の `state` パラメータは、ADKにおける最重要概念のひとつ。

```python
session_obj = await runner.session_service.create_session(
    app_name=app_name,
    user_id=user_id,
    state=context,   # ← ここが肝！
)
```

**`state` の役割**:
- セッションの共有ワーキングメモリとして機能
- Agent・Tool・Callbackがすべて `session.state` 経由でアクセス可能
- `prompt.py` の `{student_profile}` プレースホルダーは、`state["student_profile"]` の値で自動展開される

**プレースホルダー展開の仕組み**:
```python
# context.py
context = {
    "student_profile": {"name": "Alex", "grade": "Year 5", ...}
}

# prompt.py
instruction_prompt = """
    Your target audience is {student_profile}.  # ← state["student_profile"] が展開される
    {examples}                                  # ← state["examples"] が展開される
"""

# agent.py
context["examples"] = examples  # examples を context に追加
root_agent, context = create_math_agent()

# backend.py
session_obj = await runner.session_service.create_session(
    state=context,  # ← promtのプレースホルダーに自動展開
)
```

---

## 実装チェックリスト

### Live Agent構築時の必須確認事項

- [ ] `agent.py` に `root_agent` 変数を定義（ADK Web/CLI向けエントリーポイント）
- [ ] `RunConfig` で `response_modalities` を明示的に設定
- [ ] `start_agent_session()` で `state=context` を渡している
- [ ] `handle_frontend_messages()` で `mime_type` チェックを実施（未知のチャンク型をスキップ）
- [ ] `handle_agent_responses()` で `interrupted` → `turn_complete` → `audio` の優先度順に処理
- [ ] `asyncio.sleep(0)` でイベントループに制御を返している（CPU占有防止）
- [ ] Live streamingに対応したモデルバージョンを使用している（全バージョン非対応）

### 音声フォーマット仕様

| 方向 | フォーマット | レート |
|------|-----------|-------|
| フロントエンド→Agent | PCM Base64エンコード | 16kHz |
| Agent→フロントエンド | PCM Base64エンコード | モデル依存（通常24kHz） |

---

## 関連ファイル

- **[GUARDRAILS-AND-STREAMING.md](GUARDRAILS-AND-STREAMING.md)**: SSEストリーミング・Live API音声処理の詳細
- **[RUNTIME-AND-STATE.md](RUNTIME-AND-STATE.md)**: Session/State管理の詳細（state=contextの仕組み）
- **[UI-INTEGRATION.md](UI-INTEGRATION.md)**: ADK Dev UI詳細、FastAPI統合
