# AIエージェント構築ガイド

## 目次

1. [フレームワーク選択ガイド](#1-フレームワーク選択ガイド)
2. [LangChain/LangGraph](#2-langchainlanggraph)
3. [Google ADK](#3-google-adk)
4. [リアルタイムマルチモーダルAgent](#4-リアルタイムマルチモーダルagent)
5. [共通パターン](#5-共通パターン)
6. [サブファイルナビゲーション](#6-サブファイルナビゲーション)

---

## 1. フレームワーク選択ガイド

### ユースケース別フレームワーク比較

| ユースケース | 推奨フレームワーク | 理由 |
|------------|----------------|------|
| RAG・要約・分類パイプライン | LangChain/LCEL | シンプルな線形処理に最適 |
| 複雑な条件分岐ワークフロー | LangGraph StateGraph | グラフ構造で複雑なフローを表現 |
| Pythonファースト企業システム統合 | Google ADK | コードファースト・モジュラー設計 |
| Googleサービス統合（GCP/Vertex AI） | Google ADK | ネイティブCloud Run/Vertex AIデプロイ |
| リアルタイム音声対話 | RTM（Gemini Live API） | WebSocket双方向・VAD・割り込み対応 |
| リアルタイム映像理解 | RTM（Gemini Live API） | 1FPS動画キャプチャ + マルチモーダル推論 |
| マルチエージェント協調（汎用） | LangGraph / ADK | Router/Supervisorパターン vs A2Aプロトコル |
| MCP統合 | LangChain/LangGraph | `load_mcp_tools()` で簡単統合 |
| 評価・品質保証基盤 | Google ADK | EvalSet + `adk eval` で形式的評価 |

### フレームワーク特性比較

| 観点 | LangChain/LangGraph | Google ADK | RTM（Gemini Live API） |
|------|--------------------|-----------|-----------------------|
| **設計思想** | LCEL パイプライン + グラフ | コードファースト・モジュラー | WebSocket双方向ストリーミング |
| **言語** | Python / JavaScript | Python | Python + JavaScript |
| **Tool統合** | ToolNode + `@tool` | FunctionTool / OpenAPIToolset | function_declarations（JSON） |
| **マルチAgent** | Router/Supervisorパターン | 親子階層 + A2Aプロトコル | 単一Agentが主（Live Agentでは不要） |
| **状態管理** | Graph State + Checkpoint | Session State（4スコープ） | セッション内のインメモリ管理 |
| **デプロイ** | LangServe（FastAPI） | Cloud Run / Vertex AI Agent Engine | Cloud Run（wss:// 必須） |
| **可観測性** | LangSmith | ADK Dev UI + Trace | ブラウザDevTools WebSocket |
| **適用場面** | LangChainエコシステム活用 | Google Cloudネイティブ | リアルタイム音声/動画アプリ |

### 選択フローチャート

```
リアルタイム音声/動画が必要？
  YES → RTM（Gemini Live API）
  NO ↓

Google Cloud / Vertex AI 中心の構成？
  YES → Google ADK
  NO ↓

複雑な条件分岐・ループが必要？
  YES → LangGraph StateGraph
  NO → LangChain LCEL Chain
```

---

## 2. LangChain/LangGraph

### エコシステム概要

```
LangChain生態系
  LangChain Core  ── Document / Prompt / LLM / LCEL
  LangGraph       ── StateGraph / Node / Edge / Checkpoint
  LangSmith       ── トレーシング / 評価 / モニタリング
  LangServe       ── FastAPI統合（本番REST APIサービング）
```

### アーキテクチャ判断表

| ユースケース | 推奨アーキテクチャ |
|------------|------------------|
| 単純な要約・分類 | LCEL Chain |
| 大規模文書要約 | LCEL + MapReduce |
| Q&A チャットボット | LCEL + RAG |
| 分岐条件付きワークフロー | LangGraph StateGraph |
| ツール呼び出しエージェント | LangGraph + ToolNode |
| マルチエージェント | LangGraph + Router/Supervisor |
| MCP統合 | LangGraph + `load_mcp_tools` |

### クイックスタート

```python
# 最小LCEL Chain
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(model_name="gpt-4o-mini")
prompt = ChatPromptTemplate.from_messages([
    ("system", "あなたは親切なアシスタントです。"),
    ("human", "{question}")
])
chain = prompt | llm | StrOutputParser()
result = chain.invoke({"question": "LangChainとは？"})
```

```python
# 最小LangGraph StateGraph
from langgraph.graph import StateGraph, END
from typing import TypedDict

class MyState(TypedDict):
    question: str
    answer: str

def process(state: MyState) -> dict:
    response = llm.invoke(state["question"])
    return {"answer": response.content}

graph = StateGraph(MyState)
graph.add_node("process", process)
graph.set_entry_point("process")
graph.add_edge("process", END)
app = graph.compile()
```

### LangSmithトレーシング

```python
import os
os.environ["LANGCHAIN_TRACING_V2"] = "true"
os.environ["LANGCHAIN_API_KEY"] = "your-langsmith-api-key"
os.environ["LANGCHAIN_PROJECT"] = "my-project"
```

詳細: `references/LC-GUIDE.md` → `references/LC-LANGGRAPH-AGENTS.md`

---

## 3. Google ADK

### コアフィロソフィー

| 原則 | 説明 |
|------|------|
| **Code-first** | YAML/JSON設定ではなくPythonコードで直接定義 |
| **Modularity** | Agent・Tool・Runner・Serviceが疎結合で再利用可能 |
| **Flexibility** | ツール・LLM・プランナー・メモリ実装を自由に拡張可能 |

### アーキテクチャ概要

```
Runner
  ├─ root_agent（BaseAgent / LlmAgent）
  │    ├─ model（Gemini/LiteLLM/Anthropic）
  │    ├─ tools（FunctionTool / OpenAPIToolset / MCPToolset）
  │    ├─ planner（BuiltInPlanner / PlanReAct）
  │    └─ sub_agents（マルチAgentの子）
  ├─ SessionService（InMemory / Database / VertexAI）
  ├─ ArtifactService（InMemory / GCS）
  └─ MemoryService（InMemory / VertexAI RAG）
```

### Agent種類の選択

| Agent種類 | 使用タイミング |
|-----------|--------------|
| LlmAgent | 単一LLMベースの汎用Agent |
| SequentialAgent | サブAgentを順次実行（パイプライン） |
| ParallelAgent | サブAgentを並列実行（アンサンブル） |
| LoopAgent | サブAgentを繰り返し実行（再試行・反復） |
| BaseAgent | カスタムロジックが必要な独自Agent |

### クイックスタート

```python
from google.adk.agents import Agent
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part

agent = Agent(
    name="simple_assistant",
    model="gemini-2.0-flash",
    instruction="あなたは親切なアシスタントです。",
    description="基本的な質問応答Agent"
)

runner = InMemoryRunner(agent=agent, app_name="MyApp")
user_message = Content(parts=[Part(text="こんにちは")])
for event in runner.run(user_id="user1", session_id="session1", new_message=user_message):
    if event.content and event.content.parts:
        for part in event.content.parts:
            if part.text:
                print(part.text, end="")
```

### ADK CLIコマンド

| コマンド | 説明 |
|---------|------|
| `adk create <name>` | 新規Agentプロジェクト生成 |
| `adk web <agent_path>` | 開発UI起動（デバッグ・Trace機能） |
| `adk eval <agent_path> <evalset>` | Agent評価実行 |
| `adk deploy cloud_run <agent_path>` | Cloud Runデプロイ |

### Modular Agent Design（ファイル分離パターン）

```
agent/
  tools.py    ─ ツール関数群（docstringがFunction Declarationのソース）
  context.py  ─ 動的コンテキスト（DBから実行時取得）
  examples.py ─ ゴールデンパス例
  prompt.py   ─ 指示テンプレート（{プレースホルダー}活用）
  agent.py    ─ アセンブリポイント（上記をimportしてAgentを生成）
```

詳細: `references/ADK-GUIDE.md` → `references/ADK-AGENT-AND-TOOLS.md`

---

## 4. リアルタイムマルチモーダルAgent

### Two-Server Modelアーキテクチャ

```
ブラウザ (port 8000)
    ↕  WebSocket (ws://localhost:8081)   ← ブラウザAECを活用するため分離
Python Proxy (port 8081)
    ↕  WebSocket → Gemini Live API
```

**ブラウザAECの価値**: Google/Mozilla/Appleが実装済みのAcoustic Echo Cancellationにより、AIの音声をマイクが拾う問題を自動解決。ヘッドフォン不要。

### Gemini Live API接続

```python
async with client.aio.live.connect(
    model="gemini-2.0-flash-live-preview-04-09",
    config={
        "response_modalities": ["audio"],
        "system_instruction": system_instruction_text,
        "speech_config": {"voice_config": {"prebuilt_voice_config": {"voice_name": "Puck"}}},
        "tools": [{"function_declarations": [...]}]
    }
) as gemini_session:
    await asyncio.gather(
        forward_client_to_gemini(client_ws, gemini_session),
        forward_gemini_to_client(client_ws, gemini_session),
    )
```

`asyncio.gather()` が双方向の「電話回線」を実現する核心。

### マルチモーダル入力仕様

| 入力種別 | フォーマット | サンプルレート |
|---------|------------|-------------|
| Audio | `audio/pcm;rate=16000` | 16kHz（送信）/ 24kHz（受信） |
| Video | `image/jpeg`（Base64） | 1FPS推奨 |
| Text | テキストコマンド | フォールバック |

### VAD・割り込み処理

| 機能 | 説明 |
|------|------|
| API-Side VAD | 音声ストリームを常時解析、自然な間でターン検出 |
| Fluid Interruption | ユーザー発話時 `{ "interrupted": true }` 送信、即座に再生停止 |
| Turn Complete | `server_content.turn_complete` でターン完了通知 |

### クイックスタートチェックリスト

- [ ] `.env` 設定（Vertex AI ADC または Gemini API Key）
- [ ] `pip install -r requirements.txt`
- [ ] `python backend/server.py` → http://localhost:8000
- [ ] `python backend/proxy/proxy.py` → ws://localhost:8081
- [ ] マイクアクセス許可を確認

詳細: `references/RTM-GUIDE.md` → `references/RTM-ARCHITECTURE.md`

---

## 5. 共通パターン

### ツール定義

**LangChain:**
```python
from langchain_core.tools import tool

@tool
def get_weather(city: str) -> str:
    """Get current weather for a city."""
    return f"Weather in {city}: Sunny"

# LangGraphでの利用
graph = StateGraph(State)
graph.add_node("tools", ToolNode([get_weather]))
```

**Google ADK:**
```python
from google.adk.tools import FunctionTool

def get_weather(city: str) -> str:
    """Get current weather for a city."""  # docstringがそのままLLMに渡される
    return f"Weather in {city}: Sunny"

agent = Agent(tools=[FunctionTool(func=get_weather)])
```

**RTM（Gemini Live API）:**
```python
# function_declarations でJSON定義
tools = [{"function_declarations": [{
    "name": "get_weather",
    "description": "Get current weather for a city",
    "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}
}]}]
```

### メモリ管理

| フレームワーク | 短期メモリ | 長期メモリ |
|-------------|---------|---------|
| LangChain | `ConversationBufferMemory` | Checkpoint（SQLite/Redis） |
| Google ADK | Session State（4スコープ） | VertexAiRagMemoryService |
| RTM | WebSocketセッション内 | なし（セッション終了で消失） |

### マルチエージェントパターン

**LangGraph Router:**
```python
def route(state) -> str:
    return "specialist_a" if "keyword" in state["question"] else "specialist_b"

graph.add_conditional_edges("router", route, {"specialist_a": "specialist_a", "specialist_b": "specialist_b"})
```

**Google ADK A2Aプロトコル:**
```python
coordinator = LlmAgent(
    name="coordinator",
    sub_agents=[specialist_a, specialist_b],
    instruction="タスクを適切な専門Agentに委任してください。"
)
```

### デプロイ比較

| フレームワーク | 推奨デプロイ先 | プロトコル |
|-------------|-------------|---------|
| LangChain/LangGraph | LangServe（FastAPI） | REST |
| Google ADK | Cloud Run / Vertex AI Agent Engine | REST / SSE |
| RTM | Cloud Run（wss:// 必須） | WebSocket |

---

## 6. サブファイルナビゲーション

### やりたいこと別ファイルガイド

```
LangChain/LangGraph系
  LCEL・Chain基礎              → references/LC-LANGCHAIN-CORE.md
  要約（MapReduce/Refine）      → references/LC-SUMMARIZATION.md
  RAGパイプライン               → references/LC-RAG-PIPELINE.md
  エージェント・LangGraph       → references/LC-LANGGRAPH-AGENTS.md
  MCP統合                      → references/LC-MCP-INTEGRATION.md
  本番化・LangSmith            → references/LC-PRODUCTION.md
  詳細ガイド・全体像            → references/LC-GUIDE.md

Google ADK系
  Agent種類・Tool設計           → references/ADK-AGENT-AND-TOOLS.md
  マルチAgent・A2Aプロトコル    → references/ADK-MULTI-AGENT-AND-A2A.md
  Runner・State・Memory         → references/ADK-RUNTIME-AND-STATE.md
  RAG・Grounding                → references/ADK-RAG-AND-GROUNDING.md
  コード実行・LLMモデル         → references/ADK-CODE-EXECUTION-AND-MODELS.md
  Guardrails・ストリーミング    → references/ADK-GUARDRAILS-AND-STREAMING.md
  UI統合（CopilotKit等）        → references/ADK-UI-INTEGRATION.md
  デプロイ・CI/CD               → references/ADK-DEPLOYMENT-AND-OPERATIONS.md
  セキュリティ・ガバナンス      → references/ADK-SECURITY-AND-GOVERNANCE.md
  Live Agent（音声）            → references/ADK-LIVE-AGENT.md
  詳細ガイド・全体像            → references/ADK-GUIDE.md

リアルタイムマルチモーダル系
  Two-Serverアーキテクチャ      → references/RTM-ARCHITECTURE.md
  Web Audio API                 → references/RTM-WEB-AUDIO-API.md
  Gemini Live API               → references/RTM-GEMINI-LIVE-API.md
  映像統合                      → references/RTM-VIDEO-INTEGRATION.md
  Function Calling              → references/RTM-FUNCTION-CALLING.md
  デプロイ                      → references/RTM-DEPLOYMENT.md
  詳細ガイド・全体像            → references/RTM-GUIDE.md
```

### 関連スキル

| 内容 | 参照先スキル |
|------|------------|
| RAG設計理論・戦略 | `designing-genai-patterns` |
| JavaScript/Vercel AI SDK | `integrating-ai-web-apps` |
| MCPプロトコル仕様・サーバー設計 | `developing-mcp` |
| Python開発基礎 | `developing-python` |
| Google Cloud（Cloud Run/Vertex AI） | `developing-google-cloud` |
