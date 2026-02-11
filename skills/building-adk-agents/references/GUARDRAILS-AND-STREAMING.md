# Guardrails と Streaming 詳細ガイド

> **📌 Plugin System推奨（ADK最新）**: セキュリティガードレールやグローバルな前後処理にはPlugin Systemの使用が推奨されています。PluginはRunner全体にグローバルスコープで適用され、Agent-localなCallbacksより広範な制御が可能です。詳細は [PLUGINS-AND-GROUNDING.md](PLUGINS-AND-GROUNDING.md) を参照してください。Callbacksは引き続き有効で、Agent固有のカスタマイズには最適です。

## 目次

1. [Callback完全リファレンス](#callback完全リファレンス)
2. [ガードレールパターン](#ガードレールパターン)
3. [PIIフィルタリング](#piiフィルタリング)
4. [SSEストリーミング](#sseストリーミング)
5. [Live API 音声処理](#live-api-音声処理)

---

## Callback完全リファレンス

### 6種類のCallback

ADKは6つのCallbackポイントを提供し、Agent実行の各フェーズで介入可能。

#### Agent Lifecycle Callbacks

##### before_agent_callback

```python
from typing import Optional
from google.adk.agents.callback_context import CallbackContext
from google.genai.types import Content

def before_agent_callback(context: CallbackContext) -> Optional[Content]:
    """
    Agent実行前に呼ばれる。Contentを返すとAgent全体をスキップする。

    戻り値:
        - Content: このContentがAgentの最終結果として返される
        - None: Agent実行を継続
    """
    user_id = context.metadata.get("user_id")
    if not has_permission(user_id):
        return Content(parts=[Part.from_text("権限がありません")])
    return None
```

##### after_agent_callback

```python
def after_agent_callback(
    context: CallbackContext,
    content: Content
) -> Optional[Content]:
    """
    Agent完了後に呼ばれる。修正したContentで出力を置換できる。

    引数:
        content: Agentが生成した元のContent
    戻り値:
        - Content: このContentでAgentの出力を置換
        - None: 元のcontentをそのまま使用
    """
    # 最終出力の検証
    if contains_sensitive_data(content):
        return Content(parts=[Part.from_text("センシティブデータを含むため出力できません")])
    return None
```

#### LLM Interaction Callbacks

##### before_model_callback

```python
from google.genai import GenerateContentRequest, GenerateContentResponse

def before_model_callback(
    context: CallbackContext,
    request: GenerateContentRequest
) -> Optional[GenerateContentResponse]:
    """
    LLM API呼び出し前に呼ばれる。Responseを返すとLLM呼び出しをスキップ。

    引数:
        request: LLMに送信予定のリクエスト
    戻り値:
        - GenerateContentResponse: LLM呼び出しをスキップしこのResponseを使用
        - None: LLM呼び出しを継続
    """
    # キャッシュチェック
    cache_key = hash_request(request)
    if cached := get_from_cache(cache_key):
        return cached

    # 不適切な入力をブロック
    user_message = request.contents[-1].parts[0].text
    if contains_blocked_words(user_message):
        return GenerateContentResponse(
            candidates=[Candidate(
                content=Content(parts=[Part.from_text("不適切な入力が含まれています")])
            )]
        )
    return None
```

##### after_model_callback

```python
def after_model_callback(
    context: CallbackContext,
    response: GenerateContentResponse
) -> Optional[GenerateContentResponse]:
    """
    LLMレスポンス受信後に呼ばれる。修正したResponseで置換できる。

    引数:
        response: LLMから返された元のレスポンス
    戻り値:
        - GenerateContentResponse: 修正したレスポンスで置換
        - None: 元のresponseをそのまま使用
    """
    # PIIフィルタリング
    original_text = response.candidates[0].content.parts[0].text
    filtered_text = redact_pii(original_text)

    if filtered_text != original_text:
        return GenerateContentResponse(
            candidates=[Candidate(
                content=Content(parts=[Part.from_text(filtered_text)])
            )]
        )
    return None
```

#### Tool Execution Callbacks

##### before_tool_callback

```python
from typing import Dict, Any

def before_tool_callback(
    context: CallbackContext,
    tool_name: str,
    tool_args: Dict[str, Any]
) -> Optional[Dict[str, Any]]:
    """
    Tool実行前に呼ばれる。dictを返すとTool実行をスキップ。

    引数:
        tool_name: 実行予定のTool名
        tool_args: Toolに渡される引数
    戻り値:
        - Dict: Tool実行をスキップしこの結果を使用
        - None: Tool実行を継続
    """
    # 引数バリデーション
    if tool_name == "get_user_data":
        user_id = tool_args.get("user_id")
        if not is_valid_user_id(user_id):
            return {"error": "無効なユーザーIDです"}

    # レート制限
    if exceed_rate_limit(tool_name, context.metadata.get("user_id")):
        return {"error": "レート制限に達しました"}

    return None
```

##### after_tool_callback

```python
def after_tool_callback(
    context: CallbackContext,
    tool_name: str,
    tool_result: Dict[str, Any]
) -> Optional[Dict[str, Any]]:
    """
    Tool完了後に呼ばれる。修正した結果で置換できる。

    引数:
        tool_name: 実行されたTool名
        tool_result: Toolが返した元の結果
    戻り値:
        - Dict: 修正した結果で置換
        - None: 元のtool_resultをそのまま使用
    """
    # ログ記録
    log_tool_execution(tool_name, tool_result)

    # 結果のフィルタリング
    if "internal_data" in tool_result:
        filtered_result = {k: v for k, v in tool_result.items() if k != "internal_data"}
        return filtered_result

    return None
```

### Callback選択基準テーブル

| 目的 | 最適Callback | 理由 |
|------|------------|------|
| ユーザー権限チェック | `before_agent` | 最も早い時点でAgent全体をスキップ可能 |
| 不適切入力ブロック | `before_model` | LLMに不適切内容を送信しない、APIコスト削減 |
| 引数バリデーション | `before_tool` | 無効なTool実行を防止 |
| API呼び出し追跡 | `before/after_model` | リクエスト/レスポンス全体にアクセス |
| PIIフィルタリング | `after_model` | LLM出力の後処理 |
| Tool結果ログ | `after_tool` | 完全な実行詳細をキャプチャ |
| レート制限 | `before_tool` | Tool単位のクオータ強制 |
| 最終出力検証 | `after_agent` | ユーザーに届く前の最終チェック |

### 制御フロールール

- **オブジェクトを返す**: その操作をスキップし、返された値を結果として使用
- **Noneを返す**: デフォルト動作を継続

---

## ガードレールパターン

### 1. 不適切入力ブロック

```python
BLOCKED_WORDS = ["暴力的", "不適切", "違法"]

def input_guard_callback(
    context: CallbackContext,
    request: GenerateContentRequest
) -> Optional[GenerateContentResponse]:
    user_message = request.contents[-1].parts[0].text.lower()

    for word in BLOCKED_WORDS:
        if word in user_message:
            return GenerateContentResponse(
                candidates=[Candidate(
                    content=Content(parts=[Part.from_text(
                        "不適切な内容が含まれているため、処理できません。"
                    )])
                )]
            )
    return None

agent = Agent(
    name="safe_agent",
    model="gemini-2.0-flash",
    instruction="安全なアシスタント",
    before_model_callback=input_guard_callback
)
```

### 2. Tool引数バリデーション

```python
def validate_tool_args_callback(
    context: CallbackContext,
    tool_name: str,
    tool_args: Dict[str, Any]
) -> Optional[Dict[str, Any]]:
    if tool_name == "process_order":
        quantity = tool_args.get("quantity", 0)
        if not (1 <= quantity <= 100):
            return {
                "success": False,
                "error": "数量は1から100の間である必要があります"
            }

    if tool_name == "access_database":
        user_id = context.metadata.get("user_id")
        if not has_database_permission(user_id):
            return {
                "success": False,
                "error": "データベースへのアクセス権限がありません"
            }

    return None

agent = Agent(
    name="validated_agent",
    model="gemini-2.0-flash",
    tools=[process_order_tool, access_database_tool],
    before_tool_callback=validate_tool_args_callback
)
```

### 3. 安全指示注入

```python
from google.adk.agents import InstructionProvider

class SafetyInstructionProvider(InstructionProvider):
    def get_instruction(self, context: ReadonlyContext) -> str:
        base_instruction = "ユーザーの質問に答えてください。"
        safety_rules = """

        安全ガイドライン:
        - 個人情報を要求しない
        - 違法行為を助長しない
        - 医療・法律・金融に関する専門的アドバイスは提供しない
        - 不確実な情報は「わかりません」と答える
        """
        return base_instruction + safety_rules

agent = Agent(
    name="safe_agent",
    model="gemini-2.0-flash",
    instruction=SafetyInstructionProvider()
)
```

### 4. 出力フィルタリング

```python
import re

SENSITIVE_PATTERNS = [
    r'\b\d{3}-\d{2}-\d{4}\b',  # SSN
    r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b',  # クレジットカード
]

def output_filter_callback(
    context: CallbackContext,
    response: GenerateContentResponse
) -> Optional[GenerateContentResponse]:
    original_text = response.candidates[0].content.parts[0].text

    for pattern in SENSITIVE_PATTERNS:
        if re.search(pattern, original_text):
            return GenerateContentResponse(
                candidates=[Candidate(
                    content=Content(parts=[Part.from_text(
                        "センシティブデータが検出されたため、出力を表示できません。"
                    )])
                )]
            )

    return None

agent = Agent(
    name="filtered_agent",
    model="gemini-2.0-flash",
    after_model_callback=output_filter_callback
)
```

---

## PIIフィルタリング

### 検出パターン

```python
import re
from typing import Dict, Pattern

PII_PATTERNS: Dict[str, Pattern] = {
    "email": re.compile(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
    "phone": re.compile(r'\b(?:\+?1[-.]?)?\(?\d{3}\)?[-.]?\d{3}[-.]?\d{4}\b'),
    "ssn": re.compile(r'\b\d{3}-\d{2}-\d{4}\b'),
    "credit_card": re.compile(r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b'),
    "ip_address": re.compile(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'),
}

def redact_pii(text: str) -> str:
    """PIIを検出してマスキングする"""
    redacted = text

    for pii_type, pattern in PII_PATTERNS.items():
        matches = pattern.finditer(redacted)
        for match in matches:
            original = match.group()
            # タイプごとに異なるマスキング形式
            if pii_type == "email":
                masked = f"[EMAIL-REDACTED]"
            elif pii_type == "phone":
                masked = f"[PHONE-REDACTED]"
            elif pii_type == "ssn":
                masked = f"[SSN-REDACTED]"
            elif pii_type == "credit_card":
                masked = f"[CC-REDACTED]"
            elif pii_type == "ip_address":
                masked = f"[IP-REDACTED]"
            else:
                masked = f"[REDACTED]"

            redacted = redacted.replace(original, masked)

    return redacted
```

### after_model_callbackでの実装

```python
def pii_filter_callback(
    context: CallbackContext,
    response: GenerateContentResponse
) -> Optional[GenerateContentResponse]:
    """LLM出力からPIIを削除"""
    original_text = response.candidates[0].content.parts[0].text
    filtered_text = redact_pii(original_text)

    # PIIが検出された場合のみレスポンスを置換
    if filtered_text != original_text:
        # ログ記録
        log_pii_detection(context.metadata.get("session_id"), original_text)

        return GenerateContentResponse(
            candidates=[Candidate(
                content=Content(parts=[Part.from_text(filtered_text)])
            )]
        )

    return None

agent = Agent(
    name="pii_safe_agent",
    model="gemini-2.0-flash",
    instruction="ユーザー情報を扱うアシスタント",
    after_model_callback=pii_filter_callback
)
```

### 検証とテスト

```python
def test_pii_redaction():
    test_cases = [
        ("私のメールはjohn@example.comです", "私のメールは[EMAIL-REDACTED]です"),
        ("電話番号は555-123-4567です", "電話番号は[PHONE-REDACTED]です"),
        ("SSNは123-45-6789です", "SSNは[SSN-REDACTED]です"),
        ("カード番号: 1234 5678 9012 3456", "カード番号: [CC-REDACTED]"),
    ]

    for original, expected in test_cases:
        result = redact_pii(original)
        assert result == expected, f"Failed: {original} -> {result} (expected {expected})"

    print("✅ すべてのPIIテストが成功")

test_pii_redaction()
```

---

## SSEストリーミング

### RunConfig設定

```python
from google.adk.agents import RunConfig
from google.adk.agents.streaming_mode import StreamingMode

# SSEストリーミングモードを有効化
run_config = RunConfig(streaming_mode=StreamingMode.SSE)

# ストリーミング実行
for event in runner.run(query="東京の天気は？", run_config=run_config):
    if event.content and event.content.parts:
        chunk = event.content.parts[0].text
        print(chunk, end="", flush=True)
```

### Pythonストリーミングパターン

#### 1. レスポンス集約しながら表示

```python
def stream_with_aggregation(query: str, agent: Agent):
    """チャンクを集約しながらストリーミング"""
    run_config = RunConfig(streaming_mode=StreamingMode.SSE)

    full_response = ""
    for event in runner.run(query, agent=agent, run_config=run_config):
        if event.content and event.content.parts:
            chunk = event.content.parts[0].text
            full_response += chunk
            print(chunk, end="", flush=True)

    print()  # 改行
    return full_response
```

#### 2. マルチ出力先ルーティング

```python
from typing import Callable, List

def stream_to_multiple_outputs(
    query: str,
    agent: Agent,
    outputs: List[Callable[[str], None]]
):
    """複数の出力先に同時配信"""
    run_config = RunConfig(streaming_mode=StreamingMode.SSE)

    for event in runner.run(query, agent=agent, run_config=run_config):
        if event.content and event.content.parts:
            chunk = event.content.parts[0].text
            for output_fn in outputs:
                output_fn(chunk)

# 使用例
def console_output(chunk: str):
    print(chunk, end="", flush=True)

def file_output(chunk: str):
    with open("stream_log.txt", "a") as f:
        f.write(chunk)

stream_to_multiple_outputs(
    "AIの未来について説明してください",
    agent,
    [console_output, file_output]
)
```

#### 3. プログレスインジケーター

```python
import sys

def stream_with_progress(query: str, agent: Agent):
    """プログレス表示付きストリーミング"""
    run_config = RunConfig(streaming_mode=StreamingMode.SSE)

    spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
    idx = 0

    print("生成中: ", end="")
    for event in runner.run(query, agent=agent, run_config=run_config):
        if event.content and event.content.parts:
            chunk = event.content.parts[0].text
            sys.stdout.write(f"\r生成中: {spinner[idx % len(spinner)]} ")
            sys.stdout.flush()
            idx += 1
            # 実際のチャンクはバッファリング

    print("\r✅ 生成完了")
```

### FastAPI SSEエンドポイント

```python
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
import json
import asyncio

app = FastAPI()

async def generate_stream(query: str, agent: Agent):
    """非同期ストリーミングジェネレーター"""
    run_config = RunConfig(streaming_mode=StreamingMode.SSE)

    try:
        async for event in runner.run_async(query, agent=agent, run_config=run_config):
            if event.content and event.content.parts:
                chunk = event.content.parts[0].text
                # SSE形式で送信
                yield f"data: {json.dumps({'text': chunk})}\n\n"
                await asyncio.sleep(0)  # イベントループに制御を返す

        # ストリーム終了マーカー
        yield "data: [DONE]\n\n"

    except Exception as e:
        yield f"data: {json.dumps({'error': str(e)})}\n\n"

@app.post("/stream")
async def stream_endpoint(query: str):
    return StreamingResponse(
        generate_stream(query, agent),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no"  # Nginx用
        }
    )
```

### JavaScript EventSource フロントエンド

```javascript
// SSEストリーミング消費
function streamQuery(query) {
    const eventSource = new EventSource(`/stream?query=${encodeURIComponent(query)}`);

    eventSource.onmessage = (event) => {
        if (event.data === '[DONE]') {
            eventSource.close();
            console.log('✅ ストリーム完了');
            return;
        }

        const data = JSON.parse(event.data);
        if (data.error) {
            console.error('エラー:', data.error);
            eventSource.close();
            return;
        }

        // チャンクを表示
        document.getElementById('response').textContent += data.text;
    };

    eventSource.onerror = (error) => {
        console.error('SSEエラー:', error);
        eventSource.close();
    };
}

// 使用例
document.getElementById('submit').addEventListener('click', () => {
    const query = document.getElementById('query').value;
    document.getElementById('response').textContent = '';
    streamQuery(query);
});
```

### エラーハンドリング

```python
import asyncio
from datetime import datetime, timedelta

async def resilient_stream(query: str, agent: Agent, timeout: int = 30):
    """タイムアウトとリトライ機能付きストリーミング"""
    run_config = RunConfig(streaming_mode=StreamingMode.SSE)

    start_time = datetime.now()
    retry_count = 0
    max_retries = 3

    while retry_count < max_retries:
        try:
            async for event in runner.run_async(query, agent=agent, run_config=run_config):
                # タイムアウトチェック
                if (datetime.now() - start_time).seconds > timeout:
                    raise TimeoutError("ストリーミングがタイムアウトしました")

                if event.content and event.content.parts:
                    chunk = event.content.parts[0].text
                    yield chunk

            break  # 成功

        except Exception as e:
            retry_count += 1
            if retry_count >= max_retries:
                yield f"\n❌ エラー: {str(e)}"
                break

            # 指数バックオフ
            wait_time = 2 ** retry_count
            yield f"\n⚠️ エラー発生、{wait_time}秒後にリトライ...\n"
            await asyncio.sleep(wait_time)
```

### セッションベースリカバリ

```python
from typing import Dict
import uuid

class StreamSession:
    def __init__(self, query: str, agent: Agent):
        self.session_id = str(uuid.uuid4())
        self.query = query
        self.agent = agent
        self.chunks: List[str] = []
        self.completed = False

    async def resume(self, from_chunk: int = 0):
        """中断したストリームを再開"""
        run_config = RunConfig(streaming_mode=StreamingMode.SSE)

        # 既に取得済みのチャンクを送信
        for chunk in self.chunks[from_chunk:]:
            yield chunk

        # 続きを取得
        if not self.completed:
            async for event in runner.run_async(
                self.query,
                agent=self.agent,
                run_config=run_config
            ):
                if event.content and event.content.parts:
                    chunk = event.content.parts[0].text
                    self.chunks.append(chunk)
                    yield chunk

            self.completed = True

# セッション管理
sessions: Dict[str, StreamSession] = {}

@app.post("/stream/start")
async def start_stream(query: str):
    session = StreamSession(query, agent)
    sessions[session.session_id] = session

    return StreamingResponse(
        session.resume(),
        media_type="text/event-stream"
    )

@app.post("/stream/resume/{session_id}")
async def resume_stream(session_id: str, from_chunk: int = 0):
    if session_id not in sessions:
        return {"error": "セッションが見つかりません"}

    session = sessions[session_id]
    return StreamingResponse(
        session.resume(from_chunk),
        media_type="text/event-stream"
    )
```

---

## Live API 音声処理

### LiveRequestQueue

```python
from google.adk.agents import LiveRequestQueue
import pyaudio
import wave

# PCM音声キューを作成
queue = LiveRequestQueue()

# 音声ストリーム設定
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000

p = pyaudio.PyAudio()
stream = p.open(
    format=FORMAT,
    channels=CHANNELS,
    rate=RATE,
    input=True,
    frames_per_buffer=CHUNK
)

print("🎤 録音開始...")

# PCM音声をキューに送信
for _ in range(0, int(RATE / CHUNK * 5)):  # 5秒間
    data = stream.read(CHUNK)
    queue.put(data)

queue.close()
stream.stop_stream()
stream.close()
p.terminate()
```

### 双方向ストリーミング vs ターンベース

| 特性 | 双方向ストリーミング | ターンベース |
|------|---------------------|-------------|
| **通信** | 継続的な双方向接続 | リクエスト/レスポンス |
| **レイテンシ** | 低（リアルタイム） | 高（バッチ処理） |
| **ユースケース** | 音声通話、リアルタイム字幕 | 音声ファイル文字起こし、一括処理 |
| **接続** | WebSocket | HTTP |
| **複雑性** | 高（状態管理必要） | 低（ステートレス） |

```python
# 双方向ストリーミング例
async def bidirectional_stream(agent: Agent):
    """リアルタイム音声対話"""
    queue = LiveRequestQueue()

    # 送信タスク
    async def send_audio():
        stream = pyaudio.PyAudio().open(format=pyaudio.paInt16,
                                        channels=1, rate=16000, input=True)
        while True:
            data = stream.read(1024)
            queue.put(data)

    # 受信タスク
    async def receive_response():
        async for response in runner.live_async(queue, agent=agent):
            if response.audio:
                play_audio(response.audio)

    # 並行実行
    await asyncio.gather(send_audio(), receive_response())

# ターンベース例
def turn_based_transcription(audio_file: str, agent: Agent):
    """録音済み音声ファイルの処理"""
    with open(audio_file, 'rb') as f:
        audio_data = f.read()

    response = runner.run(audio_data, agent=agent)
    return response.text
```

### 5つのプリビルトボイス

```python
from google.genai import SpeechConfig

# 利用可能なボイス
VOICES = {
    "Puck": "明るく元気な声",
    "Charon": "落ち着いた低音",
    "Kore": "中性的でプロフェッショナル",
    "Fenrir": "力強く権威的",
    "Aoede": "柔らかく温かい"
}

# 音声設定
speech_config = SpeechConfig(
    voice_config={"voice_name": "Puck"}  # または Charon, Kore, Fenrir, Aoede
)

agent = Agent(
    name="voice_agent",
    model="gemini-2.0-flash-live-preview-04-09",
    instruction="音声で対話するアシスタント",
    speech_config=speech_config
)
```

### モデル要件

| プラットフォーム | モデル | 説明 |
|----------------|--------|------|
| **Vertex AI** | `gemini-2.0-flash-live-preview-04-09` | プレビュー版 |
| **AI Studio** | `gemini-live-2.5-flash-preview` | プレビュー版 |

```python
# Vertex AI
agent = Agent(
    name="live_vertex",
    model="gemini-2.0-flash-live-preview-04-09",
    instruction="Vertex AIでライブ対話"
)

# AI Studio
agent = Agent(
    name="live_ai_studio",
    model="gemini-live-2.5-flash-preview",
    instruction="AI Studioでライブ対話"
)
```

### 単一モダリティ制約

**重要**: Live APIは単一モダリティのみサポート（textかaudioの一方のみ）。

```python
# ❌ 不正: テキストと音声を混在
agent = Agent(
    model="gemini-2.0-flash-live-preview-04-09",
    instruction="テキストと音声",
    response_modalities=["text", "audio"]  # エラー
)

# ✅ 正: 音声のみ
audio_agent = Agent(
    model="gemini-2.0-flash-live-preview-04-09",
    instruction="音声のみ",
    response_modalities=["audio"]
)

# ✅ 正: テキストのみ
text_agent = Agent(
    model="gemini-2.0-flash-live-preview-04-09",
    instruction="テキストのみ",
    response_modalities=["text"]
)
```

### max_output_tokensの推奨設定

```python
from google.genai import GenerateContentConfig

# 音声出力の場合は150-200トークン推奨
generate_config = GenerateContentConfig(
    max_output_tokens=150,  # 音声出力には短めに設定
    temperature=0.7
)

agent = Agent(
    model="gemini-2.0-flash-live-preview-04-09",
    instruction="簡潔に答える音声アシスタント",
    response_modalities=["audio"],
    generate_content_config=generate_config
)
```

### 完全な音声対話例

```python
import asyncio
import pyaudio
from google.adk.agents import Agent, LiveRequestQueue, Runner

async def voice_conversation():
    """フルデュプレックス音声対話"""

    # Agent設定
    agent = Agent(
        name="voice_assistant",
        model="gemini-2.0-flash-live-preview-04-09",
        instruction="ユーザーと音声で自然に対話するアシスタント",
        response_modalities=["audio"],
        speech_config=SpeechConfig(
            voice_config={"voice_name": "Kore"}
        ),
        generate_content_config=GenerateContentConfig(
            max_output_tokens=180,
            temperature=0.8
        )
    )

    queue = LiveRequestQueue()
    runner = Runner()

    # 音声入力設定
    p = pyaudio.PyAudio()
    input_stream = p.open(
        format=pyaudio.paInt16,
        channels=1,
        rate=16000,
        input=True,
        frames_per_buffer=1024
    )

    # 音声出力設定
    output_stream = p.open(
        format=pyaudio.paInt16,
        channels=1,
        rate=24000,  # 出力は24kHz
        output=True
    )

    print("🎤 音声対話開始（Ctrl+Cで終了）")

    async def send_audio():
        """マイクからPCM音声を送信"""
        try:
            while True:
                data = input_stream.read(1024, exception_on_overflow=False)
                queue.put(data)
                await asyncio.sleep(0)
        except KeyboardInterrupt:
            queue.close()

    async def receive_audio():
        """音声レスポンスを受信して再生"""
        try:
            async for response in runner.live_async(queue, agent=agent):
                if response.audio_data:
                    output_stream.write(response.audio_data)
        except Exception as e:
            print(f"❌ エラー: {e}")

    # 送受信を並行実行
    try:
        await asyncio.gather(send_audio(), receive_audio())
    finally:
        input_stream.stop_stream()
        input_stream.close()
        output_stream.stop_stream()
        output_stream.close()
        p.terminate()
        print("\n✅ 音声対話終了")

# 実行
if __name__ == "__main__":
    asyncio.run(voice_conversation())
```

### ベストプラクティス

1. **音声品質**
   - 入力: PCM 16kHz モノラル
   - ノイズリダクション推奨
   - マイク品質が重要

2. **レイテンシ最適化**
   - 小さなチャンクサイズ（512-1024バイト）
   - バッファリングを最小化
   - `max_output_tokens`を150-200に制限

3. **エラーハンドリング**
   - 接続切断時の再接続ロジック
   - 音声デバイスエラーのキャッチ
   - タイムアウト設定（30-60秒）

4. **ユーザー体験**
   - プログレスインジケーター表示
   - 話しているときの視覚フィードバック
   - 音声ミュート/アンミュート機能
