# UI統合詳細ガイド

## 目次

1. [UI統合アプローチ選択](#ui統合アプローチ選択)
2. [AG-UIプロトコル](#ag-uiプロトコル)
3. [CopilotKit + Next.js統合](#copilotkit--nextjs統合)
4. [Streamlit統合](#streamlit統合)
5. [Slack統合](#slack統合)
6. [Dialogflow CX統合](#dialogflow-cx統合)
7. [マルチモーダル画像処理](#マルチモーダル画像処理)
8. [ADK Dev UI](#adk-dev-ui)
9. [FastAPI統合](#fastapi統合)
10. [カスタムフロントエンド構築](#カスタムフロントエンド構築)
11. [アーキテクチャパターン選択](#アーキテクチャパターン選択)

---

## UI統合アプローチ選択

### 6方式の包括比較表

| アプローチ | 最適用途 | 複雑度 | スケーラビリティ | 開発速度 | 主なライブラリ |
|-----------|---------|--------|----------------|---------|--------------|
| **AG-UI Protocol** | モダンWebアプリ（React/Next.js） | 低 | 高 | 高速（数時間） | CopilotKit, ag_ui_adk |
| **Native ADK API** | カスタムフレームワーク | 中 | 高 | 中速（数日） | google-adk |
| **Direct Python** | Streamlit/内部ツール | 低 | 低 | 高速（数時間） | streamlit |
| **Messaging Platform** | Slack/Teams Bot | 中 | 中 | 中速（1-2週間） | slack-bolt |
| **Dialogflow CX** | エンタープライズ対話UI | 高 | 高 | 中速（1-2週間） | Dialogflow CX + Webhook |
| **Event-Driven** | 大規模分散システム | 高 | 最高 | 低速（数週間） | Pub/Sub, Kafka |

### 選択フローチャート

```
開始
  ↓
フロントエンドはReact/Next.js？
  ├── Yes → AG-UI Protocol（推奨）
  └── No
       ↓
     内部ツール・データサイエンス用途？
       ├── Yes → Direct Python (Streamlit)
       └── No
            ↓
          Slack/Teams連携必須？
            ├── Yes → Messaging Platform
            └── No
                 ↓
               エンタープライズ会話UI（マルチチャネル）？
                 ├── Yes → Dialogflow CX統合
                 └── No
                      ↓
                    独自プロトコル必要？
                      ├── Yes → Native ADK API
                      └── No → Event-Driven（大規模システム）
```

### 選択基準の判断テーブル

| 条件 | 推奨アプローチ |
|------|--------------|
| Next.js/React + AIチャット機能 | AG-UI Protocol (CopilotKit) |
| データ分析・社内ツール・Jupyter環境 | Direct Python (Streamlit) |
| Slack Botでチームに統合 | Messaging Platform (Slack Bolt) |
| 複数チャネル（Web/音声/WhatsApp） | Dialogflow CX |
| 100万ユーザー規模、非同期処理 | Event-Driven (Pub/Sub) |
| 独自モバイルアプリ・カスタムUI | Native ADK API |

---

## AG-UIプロトコル

### パートナーシップと背景

AG-UI（Agent UI）プロトコルは、**Google ADKとCopilotKitの公式パートナーシップ**により誕生した、AIエージェントとWebフロントエンドを統合するための標準プロトコルです。ADKが2025年4月9日に公開されたと同時に、UIフレームワーク側との相互運用性を確保するために設計されました。

### プロトコルスタック

```
┌─────────────────────────────────────┐
│  React/Next.js Frontend             │
│  ├── CopilotKit SDK                 │
│  ├── <CopilotChat />                │
│  ├── useCopilotAction()             │
│  └── useCopilotReadable()           │
└─────────────────────────────────────┘
              ↕ WebSocket/SSE
┌─────────────────────────────────────┐
│  Python Backend (FastAPI)           │
│  ├── ag_ui_adk Adapter              │
│  ├── ADKAgent Wrapper               │
│  └── Google ADK Agent               │
└─────────────────────────────────────┘
```

### AG-UIイベントストリーム

AG-UIプロトコルはServer-Sent Events（SSE）を通じてイベントを送受信します。

#### イベント種別

| イベント | 方向 | 説明 |
|---------|------|------|
| `RUN_STARTED` | Backend → Frontend | Agentの実行開始を通知 |
| `TEXT_MESSAGE_CONTENT` | Backend → Frontend | テキストのストリーミング |
| `TOOL_CALL_START` | Backend → Frontend | ツール呼び出し開始 |
| `TOOL_CALL_END` | Backend → Frontend | ツール呼び出し完了（結果付き） |
| `STATE_SNAPSHOT` | Backend → Frontend | 共有状態の更新 |
| `RUN_FINISHED` | Backend → Frontend | 実行完了 |
| `USER_MESSAGE` | Frontend → Backend | ユーザー入力 |
| `ACTION_RESULT` | Frontend → Backend | Human-in-the-Loopの承認結果 |

#### SSEエンドポイント実装

```python
# FastAPI + SSEエンドポイント
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from google.adk.agents import Agent
from ag_ui_adk import ADKAgent, add_adk_fastapi_endpoint

app = FastAPI()
agent = ADKAgent(adk_agent=your_agent)

# AG-UIエンドポイントを追加（SSEストリーミング対応）
add_adk_fastapi_endpoint(app, agent, path="/api/copilotkit")
```

```typescript
// フロントエンド: SSE接続
<CopilotKit
  runtimeUrl="/api/copilotkit"
  transcribeAudioUrl="/api/transcribe"  // オプション: 音声入力
/>
```

### WebSocket vs SSEの選択

| 特性 | WebSocket | SSE |
|------|-----------|-----|
| 通信方向 | 双方向 | サーバー→クライアント単方向 |
| HTTP/2対応 | 限定的 | 完全対応 |
| ファイアウォール | 通過困難な場合がある | HTTP経由で通過 |
| 再接続 | 手動実装 | ブラウザが自動 |
| 用途 | リアルタイム双方向対話 | ストリーミング表示 |

---

## CopilotKit + Next.js統合

### 基本セットアップ

#### インストール

```bash
# フロントエンド
npm install @copilotkit/react-core @copilotkit/react-ui

# バックエンド
pip install ag_ui_adk fastapi uvicorn
```

#### フロントエンド（Next.js 15 + App Router）

```typescript
// app/layout.tsx
import { CopilotKit } from "@copilotkit/react-core";
import "@copilotkit/react-ui/styles.css";

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <CopilotKit runtimeUrl="/api/copilotkit">
          {children}
        </CopilotKit>
      </body>
    </html>
  );
}
```

```typescript
// app/page.tsx
import { CopilotChat } from "@copilotkit/react-ui";

export default function Home() {
  return (
    <div>
      <h1>AI Assistant</h1>
      <CopilotChat
        instructions="簡潔に回答してください。必要に応じてツールを使用してください。"
        labels={{
          initial: "何かお手伝いできることはありますか？"
        }}
      />
    </div>
  );
}
```

#### バックエンド（FastAPI + Python）

```python
# main.py
from fastapi import FastAPI
from google.adk.agents import Agent
from ag_ui_adk import ADKAgent, add_adk_fastapi_endpoint

app = FastAPI()

# 1. ADKエージェントを作成
agent = Agent(
    name="assistant",
    model="gemini-2.0-flash-exp",
    instruction="あなたは親切なアシスタントです。",
    tools=[search_tool, calculate_tool]
)

# 2. AG-UIアダプタでラップ
copilot_agent = ADKAgent(adk_agent=agent)

# 3. FastAPIエンドポイントを追加
add_adk_fastapi_endpoint(
    app,
    copilot_agent,
    path="/api/copilotkit"
)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### 高度パターン1: Generative UI

**概念**: Agentがカスタムリアクトコンポーネントをチャット内に動的にレンダリングします。

#### フロントエンド実装

```typescript
// app/page.tsx
import { useCopilotAction } from "@copilotkit/react-core";
import { WeatherWidget } from "@/components/WeatherWidget";

export default function Home() {
  useCopilotAction({
    name: "displayWeather",
    description: "天気情報を表示するウィジェットを生成",
    parameters: [
      {
        name: "location",
        type: "string",
        description: "地名（例: Tokyo）",
        required: true
      },
      {
        name: "forecast",
        type: "object",
        description: "天気予報データ"
      }
    ],
    available: "remote",  // リモートAgent呼び出しを許可
    render: ({ args, status }) => {
      if (status === "executing") {
        return <div>天気情報を取得中...</div>;
      }
      return <WeatherWidget location={args.location} data={args.forecast} />;
    }
  });

  return <CopilotChat />;
}
```

#### バックエンド実装

```python
# tools.py
from google.adk.tools import FunctionTool
import requests

def get_weather(location: str) -> dict:
    """指定された地名の天気情報を取得"""
    response = requests.get(f"https://api.weather.com/v1/{location}")
    return response.json()

weather_tool = FunctionTool(get_weather)

# main.py
agent = Agent(
    model="gemini-2.0-flash-exp",
    instruction="""
    ユーザーが天気を尋ねたら、get_weather関数で情報を取得し、
    displayWeatherアクションを呼び出してUIに表示してください。
    """,
    tools=[weather_tool]
)
```

#### 実行フロー

```
1. User: "東京の天気は？"
2. Agent: get_weather("Tokyo") を呼び出し
3. Agent: displayWeather(location="Tokyo", forecast={...}) をフロントエンドに送信
4. Frontend: WeatherWidget をチャット内にレンダリング
```

### 高度パターン2: Human-in-the-Loop

**概念**: Agentが実行前にユーザーの承認を求める対話的ワークフロー。

```typescript
// app/page.tsx
import { useCopilotAction } from "@copilotkit/react-core";
import { useState } from "react";

export default function Home() {
  const [pendingAction, setPendingAction] = useState(null);

  useCopilotAction({
    name: "sendEmail",
    description: "メールを送信（要ユーザー承認）",
    parameters: [
      { name: "to", type: "string", required: true },
      { name: "subject", type: "string", required: true },
      { name: "body", type: "string", required: true }
    ],
    handler: async ({ to, subject, body }) => {
      return new Promise((resolve) => {
        setPendingAction({ to, subject, body, resolve });
      });
    }
  });

  return (
    <>
      <CopilotChat />
      {pendingAction && (
        <div className="modal">
          <h2>メール送信の確認</h2>
          <p>宛先: {pendingAction.to}</p>
          <p>件名: {pendingAction.subject}</p>
          <button onClick={() => {
            fetch("/api/send-email", { method: "POST", body: JSON.stringify(pendingAction) });
            pendingAction.resolve("送信しました");
            setPendingAction(null);
          }}>
            承認
          </button>
          <button onClick={() => {
            pendingAction.resolve("キャンセルされました");
            setPendingAction(null);
          }}>
            拒否
          </button>
        </div>
      )}
    </>
  );
}
```

### 高度パターン3: Shared State

**概念**: フロントエンドのアプリケーション状態をAgentに自動公開します。

```typescript
// app/page.tsx
import { useCopilotReadable } from "@copilotkit/react-core";
import { useState } from "react";

export default function Home() {
  const [cart, setCart] = useState([
    { id: 1, name: "Laptop", price: 1200 },
    { id: 2, name: "Mouse", price: 25 }
  ]);

  // カート状態をAgentに公開
  useCopilotReadable({
    description: "現在のショッピングカートの内容",
    value: cart
  });

  return (
    <div>
      <div>カート: {cart.length}点</div>
      <CopilotChat
        instructions="ユーザーのカートの内容を確認し、合計金額を計算できます。"
      />
    </div>
  );
}
```

```python
# Agentは自動的にカート情報にアクセス可能
agent = Agent(
    model="gemini-2.0-flash-exp",
    instruction="""
    ユーザーが「合計は？」と聞いたら、カートの内容から
    合計金額を計算して回答してください。
    """
)
```

### ベストプラクティス

#### エラーハンドリング

```typescript
<CopilotKit
  runtimeUrl="/api/copilotkit"
  onError={(error) => {
    console.error("Agent error:", error);
    // ユーザー通知・リトライロジック
  }}
/>
```

#### ストリーミング最適化

```python
# バックエンド: バッファサイズ調整
copilot_agent = ADKAgent(
    adk_agent=agent,
    streaming_buffer_size=1024
)
```

#### セキュリティ設定

```typescript
// app/api/copilotkit/route.ts
export async function POST(req: Request) {
  const apiKey = req.headers.get("Authorization");
  if (apiKey !== process.env.COPILOTKIT_SECRET_KEY) {
    return new Response("Unauthorized", { status: 401 });
  }
}
```

---

## Streamlit統合

### Direct Python統合の利点

- **HTTP不要**: インプロセスでAgentを実行
- **高速プロトタイピング**: 数行のコードでUI作成
- **データサイエンス統合**: Pandas/Matplotlibとシームレスに連携
- **ADK InMemoryRunner**: `@st.cache_resource` でAgentをキャッシュ

### 基本実装

```python
# app.py
import streamlit as st
from google.adk.agents import Agent
from google.adk.runners.in_memory import InMemoryRunner

# Agent初期化（キャッシュ）
@st.cache_resource
def get_agent():
    return Agent(
        name="streamlit_agent",
        model="gemini-2.0-flash-exp",
        instruction="ユーザーの質問に親切に回答してください。",
        tools=[search_tool, calculate_tool]
    )

agent = get_agent()
runner = InMemoryRunner(agent=agent)

# UIレンダリング
st.title("AI Assistant")

# セッション状態管理
if "messages" not in st.session_state:
    st.session_state.messages = []

# チャット履歴表示
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

# ユーザー入力処理
if prompt := st.chat_input("何かお尋ねください"):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        with st.spinner("考え中..."):
            response = runner.run(prompt)
            answer = response.messages[-1].content
            st.markdown(answer)
            st.session_state.messages.append({
                "role": "assistant",
                "content": answer
            })
```

### ストリーミングレスポンス実装

```python
# app.py (ストリーミング版)
import streamlit as st
from google.adk.agents import Agent
from google.adk.runners.in_memory import InMemoryRunner

agent = Agent(
    name="streaming_agent",
    model="gemini-2.0-flash-exp",
    instruction="簡潔に回答してください。"
)
runner = InMemoryRunner(agent=agent)

if prompt := st.chat_input("質問を入力"):
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        message_placeholder = st.empty()
        full_response = ""

        # ストリーミング処理
        for chunk in runner.stream(prompt):
            if chunk.content:
                full_response += chunk.content
                message_placeholder.markdown(full_response + "▌")

        message_placeholder.markdown(full_response)
```

### ファイルアップロードとデータ分析統合

```python
# app.py (データ分析Agent)
import streamlit as st
import pandas as pd
from google.adk.agents import Agent
from google.adk.tools import FunctionTool

def analyze_dataframe(query: str, df_csv: str) -> str:
    """Pandas DataFrameを分析"""
    import io
    df = pd.read_csv(io.StringIO(df_csv))
    result = df.describe().to_string()
    return result

agent = Agent(
    model="gemini-2.0-flash-exp",
    instruction="データフレームを分析して洞察を提供してください。",
    tools=[FunctionTool(analyze_dataframe)]
)

# ファイルアップロード
uploaded_file = st.file_uploader("CSVファイルをアップロード", type="csv")
if uploaded_file:
    df = pd.read_csv(uploaded_file)
    st.dataframe(df)

    if prompt := st.chat_input("データについて質問"):
        response = runner.run(
            prompt,
            context={"df_csv": df.to_csv()}
        )
        st.markdown(response.messages[-1].content)
```

### ベストプラクティス

#### キャッシング戦略

```python
# Agent初期化をキャッシュ（重い処理）
@st.cache_resource
def get_agent():
    return Agent(model="gemini-2.0-flash-exp", tools=[...])

# データ処理をキャッシュ（計算結果）
@st.cache_data
def process_data(df):
    return df.groupby("category").sum()
```

#### マルチユーザーセッション管理

```python
import uuid

if "session_id" not in st.session_state:
    st.session_state.session_id = str(uuid.uuid4())

runner = InMemoryRunner(
    agent=agent,
    session_id=st.session_state.session_id
)
```

---

## Slack統合

### Slack App構成

```
Slack App
  ├── Event Subscriptions（メンション検知）
  ├── Bot Token Scopes（権限）
  │   ├── chat:write（メッセージ送信）
  │   ├── app_mentions:read（メンション読取）
  │   └── files:write（ファイルアップロード）
  └── Slash Commands（オプション）
```

### 基本実装（Slack Bolt + FastAPI）

```python
# app.py
import os
from fastapi import FastAPI, Request
from slack_bolt import App
from slack_bolt.adapter.fastapi import SlackRequestHandler
from google.adk.agents import Agent
from google.adk.runners.in_memory import InMemoryRunner

# Slack App初期化
slack_app = App(
    token=os.environ["SLACK_BOT_TOKEN"],
    signing_secret=os.environ["SLACK_SIGNING_SECRET"]
)

# ADK Agent初期化
agent = Agent(
    name="slack_agent",
    model="gemini-2.0-flash-exp",
    instruction="Slackユーザーの質問に簡潔に回答してください。",
    tools=[search_tool]
)
runner = InMemoryRunner(agent=agent)

# メンションイベント処理
@slack_app.event("app_mention")
def handle_mention(event, say, client):
    user_message = event["text"]
    thread_ts = event.get("thread_ts", event["ts"])
    channel = event["channel"]
    ts = event["ts"]

    # 処理中リアクション
    client.reactions_add(channel=channel, timestamp=ts, name="hourglass")

    try:
        response = runner.run(user_message)
        answer = response.messages[-1].content

        # Slackに返信
        say(text=answer, thread_ts=thread_ts)

        # 完了リアクション
        client.reactions_remove(channel=channel, timestamp=ts, name="hourglass")
        client.reactions_add(channel=channel, timestamp=ts, name="white_check_mark")
    except Exception as e:
        client.reactions_remove(channel=channel, timestamp=ts, name="hourglass")
        client.reactions_add(channel=channel, timestamp=ts, name="x")
        say(text=f"エラーが発生しました: {e}", thread_ts=thread_ts)

# FastAPI統合
app = FastAPI()
handler = SlackRequestHandler(slack_app)

@app.post("/slack/events")
async def slack_events(req: Request):
    return await handler.handle(req)
```

### スレッド対応（コンテキスト保持）

```python
from collections import defaultdict

# スレッドごとにRunnerを管理
thread_runners = defaultdict(lambda: InMemoryRunner(agent=agent))

@slack_app.event("app_mention")
def handle_mention(event, say):
    user_message = event["text"]
    thread_ts = event.get("thread_ts", event["ts"])

    # スレッド固有のRunner使用（会話コンテキスト保持）
    runner = thread_runners[thread_ts]
    response = runner.run(user_message)

    say(text=response.messages[-1].content, thread_ts=thread_ts)
```

### エンタープライズパターン（マルチワークスペース）

```python
# Enterprise Grid対応
from slack_bolt.oauth.oauth_settings import OAuthSettings

oauth_settings = OAuthSettings(
    client_id=os.environ["SLACK_CLIENT_ID"],
    client_secret=os.environ["SLACK_CLIENT_SECRET"],
    scopes=["chat:write", "app_mentions:read"],
    installation_store=SQLAlchemyInstallationStore(engine)
)

slack_app = App(
    signing_secret=os.environ["SLACK_SIGNING_SECRET"],
    oauth_settings=oauth_settings
)

@slack_app.event("app_mention")
def handle_mention(event, say, context):
    # チームごとに異なるAgent構成
    team_id = context["team_id"]
    agent = get_team_agent(team_id)

    runner = InMemoryRunner(agent=agent)
    response = runner.run(event["text"])
    say(text=response.messages[-1].content)
```

---

## Dialogflow CX統合

### 概要と適用場面

Dialogflow CXは、エンタープライズ向けの**構造化会話マネージャー**です。ADKエージェントのバックエンド知性とDialogflow CXのフロントエンド制御を組み合わせることで、マルチチャネル（Web、音声IVR、WhatsApp、Google Chat）に対応した本格的な会話UIを構築できます。

### 2つのアーキテクチャパターン

| パターン | 説明 | 最適用途 |
|---------|------|---------|
| **CX-First** | CXがインテントを分類し、ADKプランナーをWebhook経由で呼び出す | 構造化タスク多数、一部に自由対話 |
| **Planner-First** | ADKプランナーが全テキストを処理し、CXがチャネル制御・状態管理 | 自由対話中心、UIフォーマット重視 |
| **ハイブリッド** | 高確信度フローはCX直接処理、曖昧クエリはプランナーへ委譲 | 本番推奨（最も柔軟） |

### ハイブリッドアーキテクチャ実装

#### CX Webhook設定

```python
# webhook.py
from fastapi import FastAPI, Request
from google.adk.agents import Agent
from google.adk.runners.in_memory import InMemoryRunner

app = FastAPI()
agent = Agent(
    name="cx_agent",
    model="gemini-2.0-flash-exp",
    instruction="ユーザーの質問に回答し、必要なツールを使用してください。"
)
runner = InMemoryRunner(agent=agent)

@app.post("/webhook")
async def handle_cx_webhook(request: Request):
    body = await request.json()

    # Dialogflow CXからのセッション情報取得
    session_id = body["sessionInfo"]["session"]
    user_input = body["text"]
    agent_persona = body["sessionInfo"]["parameters"].get("agent_persona", "default")

    # ADKプランナーに委譲
    response = runner.run(
        user_input,
        session_id=session_id
    )

    answer = response.messages[-1].content

    # CX応答フォーマット
    return {
        "fulfillmentResponse": {
            "messages": [
                {"text": {"text": [answer]}}
            ]
        }
    }
```

#### CX側のWebhook設定（JSON）

```json
{
  "webhook": "PlannerHandler",
  "tag": "freeform_query",
  "parameterMapping": {
    "user_input": "$session.params.query",
    "agent_persona": "support"
  }
}
```

### 動的スロットフィリングとADK統合

CXの強力なスロットフィリング機能を使い、構造化データを収集してからADKツールを呼び出すパターン。

```python
# 全スロット収集完了後にADKツールを呼び出す
@app.post("/webhook/book-meeting")
async def book_meeting(request: Request):
    body = await request.json()
    params = body["sessionInfo"]["parameters"]

    # CXが収集した構造化パラメータ
    topic = params["topic"]
    date = params["date"]
    time = params["time"]
    attendees = params["attendees"]

    # ADKツール呼び出し
    result = meeting_tool.call(
        topic=topic,
        date=date,
        time=time,
        attendees=attendees
    )

    return {
        "fulfillmentResponse": {
            "messages": [{"text": {"text": [f"会議を予約しました: {result}"]}}]
        }
    }
```

### マルチターン記憶の同期

Dialogflow CXのセッションパラメータとADKの長期記憶を橋渡しするメモリブリッジパターン。

```python
# memory_bridge.py
from google.cloud import firestore

db = firestore.Client()

def sync_cx_memory_to_agent(session_id: str, cx_params: dict):
    """CXセッション状態をADKの作業記憶に転送"""
    # セッション情報をFirestoreに保存
    doc_ref = db.collection("agent_memory").document(session_id)
    doc_ref.set({
        "cx_params": cx_params,
        "last_updated": firestore.SERVER_TIMESTAMP
    }, merge=True)
    return "メモリ同期完了"

def load_agent_memory(session_id: str) -> dict:
    """ADKセッション開始時に前回のコンテキストを復元"""
    doc = db.collection("agent_memory").document(session_id).get()
    if doc.exists:
        return doc.to_dict()
    return {}
```

### フォールバック処理（インテント不一致時）

```python
@app.post("/webhook/fallback")
async def handle_fallback(request: Request):
    body = await request.json()
    user_input = body["text"]

    # フォールバックをプランナーで推論的に処理
    response = runner.run(user_input)

    # 明確化の提案を含む構造化応答
    suggestions = extract_suggestions(response.messages[-1].content)

    return {
        "fulfillmentResponse": {
            "messages": [
                {
                    "text": {"text": [response.messages[-1].content]},
                    "quickReplies": {
                        "title": "次のアクションを選択",
                        "quickReplies": suggestions
                    }
                }
            ]
        }
    }
```

### リッチレスポンスフォーマット

ADKプランナーの出力をCXが解釈できるリッチUIコンポーネントに変換する。

```python
def format_as_cx_card(title: str, text: str, url: str) -> dict:
    """カード形式のCX応答を生成"""
    return {
        "fulfillmentResponse": {
            "messages": [
                {
                    "card": {
                        "title": title,
                        "text": text,
                        "buttons": [
                            {
                                "text": "詳細を見る",
                                "link": url
                            }
                        ]
                    }
                }
            ]
        }
    }
```

### 本番実装例: ITヘルプデスクエージェント

書籍に記載された実際の大学キャンパス向けITヘルプデスクAgent実装パターン。

```
実装構成:
  ├── Dialogflow CX
  │   ├── インテント分類（パスワードリセット、VPN問題等）
  │   ├── スロット収集（チケット番号、部署等）
  │   └── チャネル配信（Webチャット、モバイルアプリ）
  ├── ADKプランナー（Cloud Run）
  │   ├── check_vpn_status ツール
  │   ├── verify_active_directory_login ツール
  │   └── report_incident ツール
  └── エスカレーション
      └── planner_response.meta.requires_handoff = True で人間オペレーターへ
```

### Dialogflow CX設計原則

| 原則 | 説明 |
|------|------|
| 役割分担 | CX: 構造処理、ADK: セマンティクス処理 |
| フォールバック委譲 | CXのエラー/不一致時はプランナーに委譲 |
| 記憶の一貫性 | CXセッション状態とプランナーコンテキストを同期 |
| リッチ出力 | マルチチャネル対応の構造化応答を設計 |

---

## マルチモーダル画像処理

### 画像入力の3方式

#### 1. Inline Data（1MB未満の画像）

```python
from google.genai import types
import base64

def load_image_inline(image_path: str) -> types.Part:
    """ローカル画像をインラインデータとして読み込み"""
    with open(image_path, "rb") as f:
        image_bytes = f.read()

    return types.Part(
        inline_data=types.Blob(
            data=image_bytes,
            mime_type='image/png'
        )
    )

# Agent実行
agent = Agent(model="gemini-2.0-flash-exp")
runner = InMemoryRunner(agent=agent)

image_part = load_image_inline("screenshot.png")
response = runner.run([
    types.Part(text="この画像に何が写っていますか？"),
    image_part
])
```

#### 2. File Data（1MB超・Cloud Storage使用）

```python
from google.genai import types
from google.cloud import storage

def upload_to_gcs(local_path: str, bucket_name: str, blob_name: str) -> str:
    """画像をCloud Storageにアップロード"""
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(blob_name)
    blob.upload_from_filename(local_path)
    return f"gs://{bucket_name}/{blob_name}"

image_uri = upload_to_gcs("large_image.jpg", "my-bucket", "images/large.jpg")

image_part = types.Part(
    file_data=types.FileData(
        file_uri=image_uri,
        mime_type='image/jpeg'
    )
)

response = runner.run([
    types.Part(text="この画像を分析してください。"),
    image_part
])
```

#### 3. URL（HTTP取得後Inline変換）

```python
import requests
from google.genai import types

def load_image_from_url(url: str) -> types.Part:
    """URL経由で画像を取得してインラインデータ化"""
    response = requests.get(url)
    response.raise_for_status()
    content_type = response.headers.get('Content-Type', 'image/jpeg')

    return types.Part(
        inline_data=types.Blob(
            data=response.content,
            mime_type=content_type
        )
    )

image_part = load_image_from_url("https://example.com/image.png")
response = runner.run([types.Part(text="説明してください。"), image_part])
```

### サポート形式と選択基準

| 形式 | MIME Type | 最大サイズ | 推奨入力方式 |
|------|-----------|-----------|------------|
| PNG | image/png | 20MB | < 1MB: inline_data / > 1MB: file_data |
| JPEG | image/jpeg | 20MB | < 1MB: inline_data / > 1MB: file_data |
| WEBP | image/webp | 20MB | inline_data |
| HEIC | image/heic | 20MB | file_data |
| HEIF | image/heif | 20MB | file_data |

### マルチモーダルストリーミング（書籍6の知見）

書籍6が紹介するリアルタイムマルチモーダルストリーミングパターン。

#### 音声ストリーミング（Speech-to-Text）

```python
# tools/stream_stt.py
from google.adk import tool
import asyncio
import httpx

@tool
async def stream_transcribe(audio_chunks: list[bytes]) -> list[str]:
    """
    音声チャンクを音声認識APIにストリーミングし、部分文字起こしを返す
    """
    url = "https://speech.googleapis.com/v1/speech:recognize"
    transcripts = []

    async with httpx.AsyncClient(http2=True, timeout=None) as client:
        async with client.stream("POST", url,
                                 headers={"Transfer-Encoding": "chunked"}) as resp:
            async for line in resp.aiter_lines():
                if not line.strip():
                    continue
                import json
                data = json.loads(line)
                transcript = data["results"][0]["alternatives"][0]["transcript"]
                transcripts.append(transcript)

    return transcripts
```

#### 画像フレームストリーミング（Video分析）

```python
@tool
async def stream_image_caption(frames: list[bytes]) -> list[str]:
    """
    動画フレームをVision APIに送信してキャプションリストを返す
    """
    url = "https://vision.googleapis.com/v1/images:annotate"
    captions = []

    async with httpx.AsyncClient(timeout=None) as client:
        for frame in frames:
            resp = await client.post(
                url,
                content=frame,
                headers={"Content-Type": "image/jpeg"}
            )
            captions.append(resp.json()["caption"])

    return captions
```

### Vision Agentパターン

#### パターン1: 単一画像分析

```python
vision_agent = Agent(
    name="vision_agent",
    model="gemini-2.0-flash-exp",
    instruction="""
    あなたは画像分析の専門家です。
    ユーザーが画像を提供したら、以下を分析してください:
    1. 主要な被写体
    2. 色彩とコンポジション
    3. 文字情報（OCR）
    4. 感情的印象
    """
)
```

#### パターン2: 複数画像比較

```python
image1 = load_image_inline("before.jpg")
image2 = load_image_inline("after.jpg")

response = runner.run([
    types.Part(text="Before画像:"),
    image1,
    types.Part(text="After画像:"),
    image2,
    types.Part(text="2枚の画像の違いを詳しく説明してください。")
])
```

#### パターン3: 画像生成（Gemini Image）

```python
from google.genai import types

image_gen_agent = Agent(
    name="image_generator",
    model="gemini-2.5-flash-image",
    response_modalities=['Image'],
    image_config=types.ImageConfig(
        aspect_ratio='16:9'
    )
)

runner = InMemoryRunner(agent=image_gen_agent)
response = runner.run("青い空と緑の草原の風景画を生成してください。")

# 生成画像の取得
for part in response.messages[-1].content:
    if part.inline_data:
        with open("generated.png", "wb") as f:
            f.write(part.inline_data.data)
```

### 画像最適化ベストプラクティス

```python
from PIL import Image
import io

def optimize_image(image_path: str, max_size_kb: int = 1024) -> bytes:
    """画像を最適化（サイズ制限・品質調整）"""
    img = Image.open(image_path)

    # 長辺1024px以下にリサイズ
    max_dimension = 1024
    if max(img.size) > max_dimension:
        ratio = max_dimension / max(img.size)
        new_size = tuple(int(dim * ratio) for dim in img.size)
        img = img.resize(new_size, Image.Resampling.LANCZOS)

    # JPEG圧縮（品質自動調整）
    output = io.BytesIO()
    quality = 85
    while True:
        output.seek(0)
        output.truncate()
        img.save(output, format='JPEG', quality=quality, optimize=True)
        if output.tell() <= max_size_kb * 1024 or quality <= 50:
            break
        quality -= 5

    return output.getvalue()
```

---

## ADK Dev UI

### 概要

ADK Dev UIは、`adk web`コマンドで起動するブラウザベースの開発・監視ツールです。Google ADKは「Blind Spots（盲点）」問題（デバッグにprint()を散在させるしかなかった問題）を解決するため、第一級機能としてDev UIを組み込んでいます。

### 起動方法

#### Python

```bash
# インストール
pip install google-adk

# プロジェクト初期化
adk init my_agent

# Dev UI起動（http://localhost:8000）
cd my_agent
adk web

# ライブリロード付き起動
adk web --reload --port 8000
```

#### Java（Maven）

```bash
# pom.xmlにgoogle-adk-devを追加後
mvn adk:web    # Pythonと同一のDev UIがhttp://localhost:8000で起動
```

### Dev UI画面構成

```
┌─────────────────────────────────────────────────────────┐
│  ADK Dev UI  -  http://localhost:8000                   │
├─────────────────┬───────────────┬───────────────────────┤
│  Timeline Pane  │  Chat Console │  Context Pane         │
│  (左)           │  (中央)       │  (右)                 │
│                 │               │                       │
│  ▶ Planner     │  "質問を入力" │  Session State        │
│  ├─ Tool: xxx  │               │  Memory Hits          │
│  ├─ Memory     │  [User]       │  Artifact URIs        │
│  └─ Safety     │  質問です     │  Token Usage          │
│                 │               │                       │
│  Filter:        │  [Agent]      │  Diff View            │
│  ○ Error only  │  回答です     │  （変更前後比較）     │
│  ○ Safety hits │               │                       │
│  ○ High-latency│               │                       │
└─────────────────┴───────────────┴───────────────────────┘
```

### トレースノードの構造

```
▶ [Planner] "マーケティングメールを作成"
├─► [Tool: fetch_data] (23ms • 15 tokens)
├─► [Memory: RAG lookup] (7ms • 3 hits)
├─► [Tool: summarize] (180ms • 220 tokens)
└─► [Safety: RegexGuard] (0ms • clean)
```

| ノードカラー | 意味 |
|------------|------|
| 赤枠 | セーフティブロックまたはエラー |
| 黄色 | 高レイテンシノード |
| 緑 | 正常完了 |

### インタラクティブトレースビューアの機能

| 機能 | 操作方法 | 用途 |
|------|---------|------|
| フィルタリング | ファネルアイコンをクリック | エラーや高レイテンシノードに絞り込む |
| Diff View | ノード選択後「Diff」をクリック | プロンプト変更前後の比較 |
| コンテキスト検査 | ノード選択後「Context」タブ | セッション状態・記憶ヒット・Artifact URIを確認 |
| テキスト検索 | 検索バーに入力 | すべてのノードのプロンプト・応答を全文検索 |

### カスタムトレースの追加

```python
from adk.callbacks import Callback
from opentelemetry import metrics

meter = metrics.get_meter("agent_metrics")
error_counter = meter.create_counter("tool_errors")

class TagWithUser(Callback):
    """ユーザーIDをすべてのスパンにタグ付け"""
    def on_request_start(self, event, **_):
        event.span.set_attribute("user.id", event.request.user_id)

class ErrorCounter(Callback):
    """ツールエラーをメトリクスとして記録"""
    def on_tool_error(self, event, **_):
        error_counter.add(1, {"tool": event.tool_id})

agent = SequentialAgent(
    ...,
    callbacks=[TagWithUser(), ErrorCounter()]
)
```

### 本番環境でのDev UI活用

Dev UIはコンテナ内に含まれているため、本番環境でも安全にアクセス可能です。

#### アクセス方法（セキュアなトンネル）

```bash
# Kubernetes port-forward
kubectl port-forward svc/agent-service 8000:8000
# → http://localhost:8000 でアクセス

# Cloud Run プライベートサービス
gcloud run services proxy my-agent --region=us-central1
# → http://localhost:8000 でアクセス
```

#### Ingress設定（IPホワイトリスト）

```yaml
# kubernetes ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: agent-ui
  annotations:
    nginx.ingress.kubernetes.io/whitelist-source-range: "203.0.113.0/24"
spec:
  rules:
  - host: ui.example.com
    http:
      paths:
      - path: /ui
        backend:
          service:
            name: agent-service
            port: { number: 8000 }
```

### Dev UI活用ベストプラクティス

| プラクティス | 内容 |
|------------|------|
| セキュアアクセス | Dev UIを公開設定にしない。IAM、VPN、IPホワイトリストを使用 |
| フィルタ活用 | まず「errors」または「high-latency」で絞り込む |
| スパンアノテーション | ユーザーID、キャンペーンID等をCallbackで付与 |
| ログ相関 | Dev UIのtrace IDをCloud Loggingと突合して全体像を把握 |
| ホットリロード | `--reload`フラグで保存時に自動更新 |

### デバッグワークフロー

```
1. chat consoleで問題を再現
   ↓
2. timelineをerrorまたは高レイテンシでフィルタ
   ↓
3. 問題ノードをクリック → Diff/Contextを確認
   ↓
4. バグの原因を特定
   （入力不良 / ツール設定ミス / セーフティフィルタ）
   ↓
5. コード/プロンプトを修正して保存
   ↓
6. ホットリロードでトレースが即座に更新
```

---

## FastAPI統合

### REST APIエンドポイント設計

ADKエージェントをRESTful APIとして公開する基本パターン。

```python
# main.py
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from google.adk.agents import Agent
from google.adk.runners.in_memory import InMemoryRunner
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="ADK Agent API", version="1.0.0")

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)

# Agent初期化
agent = Agent(
    name="api_agent",
    model="gemini-2.0-flash-exp",
    instruction="APIリクエストを処理するエージェントです。",
    tools=[search_tool, calculate_tool]
)
runner = InMemoryRunner(agent=agent)

class RunRequest(BaseModel):
    message: str
    session_id: str = "default"

class RunResponse(BaseModel):
    response: str
    session_id: str

@app.post("/run", response_model=RunResponse)
async def run_agent(request: RunRequest):
    """エージェントを実行してレスポンスを返す"""
    try:
        result = runner.run(
            request.message,
            session_id=request.session_id
        )
        return RunResponse(
            response=result.messages[-1].content,
            session_id=request.session_id
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### WebSocketエンドポイント（ストリーミング対話）

```python
from fastapi import WebSocket, WebSocketDisconnect
from google.adk.runners.in_memory import InMemoryRunner
import asyncio
import json

@app.websocket("/ws/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    """WebSocketでストリーミング対話を実現"""
    await websocket.accept()

    runner = InMemoryRunner(agent=agent)

    try:
        while True:
            # ユーザーメッセージを受信
            data = await websocket.receive_json()
            user_message = data.get("message", "")

            # エージェントのストリーミングレスポンス
            full_response = ""
            for chunk in runner.stream(user_message, session_id=session_id):
                if chunk.content:
                    full_response += chunk.content
                    await websocket.send_json({
                        "type": "chunk",
                        "content": chunk.content
                    })

            # 完了通知
            await websocket.send_json({
                "type": "complete",
                "content": full_response
            })

    except WebSocketDisconnect:
        pass
```

### SSE（Server-Sent Events）エンドポイント

```python
from fastapi.responses import StreamingResponse
import asyncio
import json

@app.post("/stream")
async def stream_agent(request: RunRequest):
    """SSEでエージェントのストリーミング出力を返す"""

    async def generate():
        try:
            for chunk in runner.stream(
                request.message,
                session_id=request.session_id
            ):
                if chunk.content:
                    data = json.dumps({"type": "chunk", "content": chunk.content})
                    yield f"data: {data}\n\n"

            # 完了イベント
            yield f"data: {json.dumps({'type': 'complete'})}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no"  # Nginxバッファリング無効化
        }
    )
```

### セッション管理エンドポイント

```python
from google.adk.sessions import SessionService

session_service = SessionService()

@app.post("/sessions")
async def create_session():
    """新規セッションを作成"""
    session_id = session_service.create()
    return {"session_id": session_id}

@app.get("/sessions/{session_id}/history")
async def get_history(session_id: str):
    """セッション履歴を取得"""
    history = session_service.get_messages(session_id)
    return {"session_id": session_id, "history": history}

@app.delete("/sessions/{session_id}")
async def delete_session(session_id: str):
    """セッションを削除"""
    session_service.delete(session_id)
    return {"status": "deleted"}
```

### HTTP/2 vs WebSocket 選択ガイド（書籍6の知見）

| 基準 | HTTP/2 | WebSocket |
|------|--------|-----------|
| 同時接続数 | 高い（多重化ストリーム） | 中程度（接続1本=1セッション） |
| レイテンシ | 低い（リクエストごとのハンドシェイク） | 極低（ハンドシェイク後） |
| コード複雑度 | シンプル | ライフサイクル管理が必要 |
| ファイアウォール/CDN | ポート443で広くサポート | 特別なルーティングが必要な場合がある |
| 用途 | バッチ・高スループット呼び出し | インタラクティブ・ストリーミングセッション |

```python
# HTTP/2クライアント例（高スループット向け）
import httpx

def call_agent_http2(endpoint: str, token: str, message: str):
    with httpx.Client(http2=True, timeout=30.0) as client:
        headers = {"Authorization": f"Bearer {token}"}
        response = client.post(
            endpoint,
            headers=headers,
            json={"message": message}
        )
        return response.json()

# WebSocketクライアント例（インタラクティブ向け）
import asyncio
import websockets
import json

async def interactive_chat(uri: str, token: str):
    headers = [("Authorization", f"Bearer {token}")]
    async with websockets.connect(uri, extra_headers=headers) as ws:
        await ws.send(json.dumps({"message": "こんにちは"}))
        async for msg in ws:
            data = json.loads(msg)
            print(data["content"], end="")
```

---

## カスタムフロントエンド構築

### React統合パターン

#### カスタムチャットコンポーネント

```tsx
// components/AgentChat.tsx
import { useState, useRef, useEffect } from "react";

interface Message {
  role: "user" | "assistant";
  content: string;
}

export function AgentChat({ apiUrl }: { apiUrl: string }) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const sendMessage = async () => {
    if (!input.trim() || isStreaming) return;

    const userMessage = input;
    setInput("");
    setMessages(prev => [...prev, { role: "user", content: userMessage }]);
    setIsStreaming(true);

    // SSEストリーミング
    const response = await fetch(`${apiUrl}/stream`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: userMessage, session_id: "user-1" })
    });

    const reader = response.body!.getReader();
    const decoder = new TextDecoder();
    let agentMessage = "";

    // アシスタントメッセージのプレースホルダー追加
    setMessages(prev => [...prev, { role: "assistant", content: "" }]);

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value);
      const lines = chunk.split("\n");

      for (const line of lines) {
        if (line.startsWith("data: ")) {
          const data = JSON.parse(line.slice(6));
          if (data.type === "chunk") {
            agentMessage += data.content;
            // 最後のメッセージを更新
            setMessages(prev => [
              ...prev.slice(0, -1),
              { role: "assistant", content: agentMessage }
            ]);
          }
        }
      }
    }

    setIsStreaming(false);
  };

  return (
    <div className="chat-container">
      <div className="messages">
        {messages.map((msg, i) => (
          <div key={i} className={`message ${msg.role}`}>
            {msg.content}
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>
      <div className="input-area">
        <input
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyPress={e => e.key === "Enter" && sendMessage()}
          placeholder="メッセージを入力..."
          disabled={isStreaming}
        />
        <button onClick={sendMessage} disabled={isStreaming}>
          {isStreaming ? "送信中..." : "送信"}
        </button>
      </div>
    </div>
  );
}
```

#### WebSocket接続フック

```tsx
// hooks/useAgentWebSocket.ts
import { useState, useEffect, useCallback, useRef } from "react";

interface Message {
  role: "user" | "assistant";
  content: string;
}

export function useAgentWebSocket(wsUrl: string) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isConnected, setIsConnected] = useState(false);
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    const ws = new WebSocket(wsUrl);

    ws.onopen = () => setIsConnected(true);

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.type === "chunk") {
        setMessages(prev => [
          ...prev.slice(0, -1),
          { role: "assistant", content: prev[prev.length - 1].content + data.content }
        ]);
      }
    };

    ws.onclose = () => setIsConnected(false);
    wsRef.current = ws;

    return () => ws.close();
  }, [wsUrl]);

  const sendMessage = useCallback((message: string) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      setMessages(prev => [...prev, { role: "user", content: message }]);
      setMessages(prev => [...prev, { role: "assistant", content: "" }]);
      wsRef.current.send(JSON.stringify({ message }));
    }
  }, []);

  return { messages, isConnected, sendMessage };
}
```

### Vue.js統合パターン

```vue
<!-- components/AgentChat.vue -->
<template>
  <div class="chat-container">
    <div class="messages">
      <div
        v-for="(msg, index) in messages"
        :key="index"
        :class="['message', msg.role]"
      >
        {{ msg.content }}
      </div>
    </div>
    <div class="input-area">
      <input
        v-model="input"
        @keypress.enter="sendMessage"
        placeholder="メッセージを入力..."
        :disabled="isLoading"
      />
      <button @click="sendMessage" :disabled="isLoading">
        {{ isLoading ? '送信中...' : '送信' }}
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue";

interface Message {
  role: "user" | "assistant";
  content: string;
}

const props = defineProps<{ apiUrl: string }>();
const messages = ref<Message[]>([]);
const input = ref("");
const isLoading = ref(false);

async function sendMessage() {
  if (!input.value.trim() || isLoading.value) return;

  const userMessage = input.value;
  input.value = "";
  messages.value.push({ role: "user", content: userMessage });
  messages.value.push({ role: "assistant", content: "" });
  isLoading.value = true;

  const response = await fetch(`${props.apiUrl}/stream`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message: userMessage })
  });

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const chunk = decoder.decode(value);
    const lines = chunk.split("\n");

    for (const line of lines) {
      if (line.startsWith("data: ")) {
        const data = JSON.parse(line.slice(6));
        if (data.type === "chunk") {
          messages.value[messages.value.length - 1].content += data.content;
        }
      }
    }
  }

  isLoading.value = false;
}
</script>
```

### フロントエンド設計ベストプラクティス

#### 状態管理パターン

```typescript
// store/agentStore.ts（Pinia/Zustand等）
interface AgentState {
  sessions: Record<string, Message[]>;
  currentSessionId: string;
  isLoading: boolean;
  error: string | null;
}

// セッションIDをローカルストレージで永続化
const SESSION_KEY = "agent_session_id";

function getOrCreateSessionId(): string {
  const stored = localStorage.getItem(SESSION_KEY);
  if (stored) return stored;
  const newId = crypto.randomUUID();
  localStorage.setItem(SESSION_KEY, newId);
  return newId;
}
```

#### エラーハンドリングとリトライ

```typescript
async function sendWithRetry(
  message: string,
  sessionId: string,
  maxRetries = 3
): Promise<string> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const response = await fetch("/api/run", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message, session_id: sessionId }),
        signal: AbortSignal.timeout(30000)  // 30秒タイムアウト
      });

      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      return data.response;
    } catch (error) {
      if (attempt === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, 1000 * (attempt + 1)));
    }
  }
  throw new Error("最大リトライ回数を超えました");
}
```

---

## アーキテクチャパターン選択

### 3つのアーキテクチャ比較

| 特性 | モノリス | 分離FE/BE | マイクロサービス |
|------|---------|-----------|----------------|
| デプロイ複雑度 | 低 | 中 | 高 |
| スケーラビリティ | 低 | 中 | 最高 |
| 開発速度 | 最速 | 中 | 遅い |
| コスト | 最低 | 中 | 高い |
| 推奨チーム規模 | 1-3名 | 3-10名 | 10名以上 |
| 推奨ユーザー規模 | <1,000 | <100,000 | 100,000以上 |

### パターン1: モノリス（MVP向け）

```
┌─────────────────────────────────────┐
│  Cloud Run Instance                 │
│  ├── FastAPI (Backend)              │
│  ├── AG-UI Endpoint                 │
│  ├── Static Files (Frontend Build)  │
│  └── ADK Agent                      │
└─────────────────────────────────────┘
         ↕ HTTPS
     User Browsers
```

```python
# main.py - モノリス構成
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from google.adk.agents import Agent
from ag_ui_adk import ADKAgent, add_adk_fastapi_endpoint

app = FastAPI()

agent = ADKAgent(adk_agent=Agent(model="gemini-2.0-flash-exp", ...))
add_adk_fastapi_endpoint(app, agent, path="/api/copilotkit")

# 静的ファイル配信（Next.jsビルド成果物）
app.mount("/", StaticFiles(directory="frontend/out", html=True), name="static")
```

```dockerfile
FROM python:3.11-slim
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
ENV STATIC_DIR=/app/frontend/out
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

### パターン2: 分離FE/BE（本番推奨）

```
┌─────────────────┐      HTTPS      ┌──────────────────┐
│  Vercel/Netlify │ ←─────────────→ │  Cloud Run       │
│  (Frontend)     │  /api/* proxy   │  (Backend)       │
│  - Next.js      │                 │  - FastAPI       │
│  - CDN Cache    │                 │  - ADK Agent     │
└─────────────────┘                 └──────────────────┘
```

```typescript
// next.config.js - APIプロキシ設定
module.exports = {
  async rewrites() {
    return [
      {
        source: '/api/copilotkit/:path*',
        destination: 'https://backend.run.app/api/copilotkit/:path*'
      }
    ];
  }
};
```

### パターン3: マイクロサービス（エンタープライズ）

```
┌────────────┐       ┌─────────────────┐
│  Frontend  │──────→│  API Gateway    │
│  (Next.js) │       │  (Cloud Armor)  │
└────────────┘       └─────────────────┘
                            ↓
              ┌─────────────┼─────────────┐
              ↓             ↓             ↓
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │ Agent 1  │  │ Agent 2  │  │ Agent 3  │
        │ (GKE)    │  │ (GKE)    │  │ (GKE)    │
        └──────────┘  └──────────┘  └──────────┘
              ↓             ↓             ↓
        ┌─────────────────────────────────────┐
        │  Pub/Sub (非同期タスクキュー)        │
        └─────────────────────────────────────┘
```

```python
# gateway.py - APIゲートウェイ
from fastapi import FastAPI, HTTPException
import httpx

app = FastAPI()

AGENT_SERVICES = {
    "sales": "http://sales-agent-service:8080",
    "support": "http://support-agent-service:8080",
    "analytics": "http://analytics-agent-service:8080"
}

@app.post("/api/agent/{agent_name}")
async def route_to_agent(agent_name: str, payload: dict):
    if agent_name not in AGENT_SERVICES:
        raise HTTPException(status_code=404, detail="Agent not found")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{AGENT_SERVICES[agent_name]}/process",
            json=payload,
            timeout=30.0
        )
        return response.json()
```

### アーキテクチャ選択ガイド

```python
def recommend_architecture(
    team_size: int,
    concurrent_users: int,
    deadline_days: int
) -> str:
    if team_size <= 3 and concurrent_users < 1000:
        return "モノリス（Cloud Run単一インスタンス）"
    elif team_size <= 10 and concurrent_users < 100000:
        return "分離FE/BE（Vercel + Cloud Run）"
    else:
        return "マイクロサービス（GKE + Pub/Sub）"

# 開発期限による制約
if deadline_days <= 3:
    推奨 = ["AG-UI Protocol", "Direct Python (Streamlit)"]
elif deadline_days <= 14:
    推奨 = ["Native ADK API", "Dialogflow CX"]
else:
    推奨 = ["Event-Driven（フルマイクロサービス）"]
```

---

## まとめ

### UI統合の意思決定フロー

```
1. 要件分析
   ├── フレームワーク選択（React/Streamlit/Slack/CX/カスタム）
   ├── スケール要件（ユーザー数・同時接続数）
   └── 開発期限・チーム規模

2. アプローチ選択
   ├── React/Next.js → AG-UI Protocol (CopilotKit)
   ├── データ分析/内部ツール → Direct Python (Streamlit)
   ├── Slack/Teams → Messaging Platform
   ├── エンタープライズ多チャネル → Dialogflow CX
   └── カスタム → Native ADK API / FastAPI

3. アーキテクチャ設計
   ├── MVP → モノリス（Cloud Run）
   ├── 本番 → 分離FE/BE（Vercel + Cloud Run）
   └── エンタープライズ → マイクロサービス（GKE）

4. UI開発ツール選択
   ├── 開発・デバッグ → ADK Dev UI（adk web）
   ├── 通信プロトコル → HTTP/2（高スループット）または WebSocket（インタラクティブ）
   └── 監視・可観測性 → OpenTelemetry + Dev UI

5. マルチモーダル対応
   ├── 画像入力 → inline_data（<1MB）/ file_data（>1MB）
   ├── 動画/音声ストリーミング → stream_transcribe / stream_image_caption
   └── 画像生成 → gemini-2.5-flash-image
```

### 次のステップ

1. **プロトタイプ作成**: `adk web`でDev UIを起動してAgentの動作を確認
2. **フロントエンド選択**: ユースケースに応じてCopilotKit/Streamlit/Slackを選択
3. **API設計**: FastAPIでREST/WebSocket/SSEエンドポイントを実装
4. **本番デプロイ**: 分離FE/BEアーキテクチャに移行
5. **監視・ログ**: OpenTelemetry + Cloud Loggingを統合
