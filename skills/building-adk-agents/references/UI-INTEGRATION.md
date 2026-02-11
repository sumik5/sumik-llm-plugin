# UI統合詳細ガイド

## 目次

1. [AG-UIプロトコル概要](#ag-uiプロトコル概要)
2. [UI統合アプローチの選択](#ui統合アプローチの選択)
3. [CopilotKit + Next.js統合](#copilotkit--nextjs統合)
4. [Streamlit統合](#streamlit統合)
5. [Slack統合](#slack統合)
6. [マルチモーダル画像処理](#マルチモーダル画像処理)
7. [アーキテクチャパターン](#アーキテクチャパターン)

---

## AG-UIプロトコル概要

### パートナーシップと背景

AG-UI（Agent UI）プロトコルは、**Google ADKとCopilotKitの公式パートナーシップ**により誕生した、AIエージェントとWebフロントエンドを統合するための標準プロトコルです。

#### プロトコルの特徴

- **イベントベース双方向通信**: WebSocketまたはServer-Sent Events経由でリアルタイム通信
- **宣言的統合**: フロントエンドはReactコンポーネントで状態・アクションを定義、バックエンドはPythonで実装
- **既製UIコンポーネント**: チャット、ストリーミング表示、承認フローを即座に利用可能

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

### 通信プロトコル詳細

#### WebSocket (双方向)

```python
# FastAPI + WebSocketエンドポイント
from fastapi import FastAPI, WebSocket
from ag_ui_adk import ADKAgent, add_adk_fastapi_endpoint

app = FastAPI()
agent = ADKAgent(adk_agent=your_agent)
add_adk_fastapi_endpoint(app, agent, path="/api/copilotkit")
```

#### Server-Sent Events (単方向ストリーミング)

```typescript
// フロントエンド: SSE接続
<CopilotKit
  runtimeUrl="/api/copilotkit"
  transcribeAudioUrl="/api/transcribe" // オプション: 音声
/>
```

---

## UI統合アプローチの選択

### 5つのアプローチ比較表

| アプローチ | 最適用途 | 複雑度 | スケーラビリティ | 開発速度 | 主なライブラリ |
|-----------|---------|--------|----------------|---------|--------------|
| **AG-UI Protocol** | モダンWebアプリ（React/Next.js） | 低 | 高 | 高速（数時間） | CopilotKit, ag_ui_adk |
| **Native ADK API** | カスタムフレームワーク | 中 | 高 | 中速（数日） | google-adk |
| **Direct Python** | Streamlit/内部ツール | 低 | 低 | 高速（数時間） | streamlit |
| **Messaging Platform** | Slack/Teams Bot | 中 | 中 | 中速（1-2週間） | slack-bolt, google-adk |
| **Event-Driven** | 大規模分散システム | 高 | 最高 | 低速（数週間） | Pub/Sub, Kafka |

### 選択基準の3要素

#### 1. フレームワーク要件

```python
# 質問1: 使用予定のフロントエンドフレームワークは？
if framework in ["React", "Next.js", "Vue"]:
    推奨 = "AG-UI Protocol"
elif framework == "Streamlit":
    推奨 = "Direct Python"
elif framework in ["Custom", "Mobile"]:
    推奨 = "Native ADK API"
elif framework == "Slack/Teams":
    推奨 = "Messaging Platform"
```

#### 2. スケール要件

```python
# 質問2: 想定ユーザー数は？
if concurrent_users < 100:
    推奨 = ["Direct Python", "AG-UI Protocol"]
elif concurrent_users < 10000:
    推奨 = ["AG-UI Protocol", "Native ADK API"]
else:
    推奨 = ["Event-Driven", "Native ADK API"]
```

#### 3. タイムライン要件

```python
# 質問3: プロトタイプまでの期限は？
if deadline_days <= 3:
    推奨 = ["AG-UI Protocol", "Direct Python"]
elif deadline_days <= 14:
    推奨 = ["Native ADK API", "Messaging Platform"]
else:
    推奨 = ["Event-Driven"]
```

### 実践例: アプローチ選択フローチャート

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
               独自プロトコル必要？
                 ├── Yes → Native ADK API
                 └── No → Event-Driven（大規模システム）
```

---

## CopilotKit + Next.js統合

### 基本統合パターン

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
    tools=[search_tool, calculate_tool]  # 任意のツール
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

#### デプロイ構成

```yaml
# docker-compose.yml
services:
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      NEXT_PUBLIC_API_URL: http://backend:8000

  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      GOOGLE_API_KEY: ${GOOGLE_API_KEY}
```

### 高度パターン1: Generative UI

**概念**: Agentがカスタムリアクトコンポーネントをチャット内に動的にレンダリング。

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
    available: "remote", // 🔥 リモートAgent呼び出しを許可
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
2. Agent: get_weather("Tokyo")を呼び出し
3. Agent: displayWeather(location="Tokyo", forecast={...})をフロントエンドに送信
4. Frontend: WeatherWidgetをチャット内にレンダリング
```

### 高度パターン2: Human-in-the-Loop

**概念**: Agentが実行前にユーザーの承認を求める対話的ワークフロー。

#### フロントエンド実装（承認モーダル付き）

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
      // 🔥 フロントエンドのみで処理（Agentは関与しない）
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
            // 実際のメール送信処理
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

**概念**: フロントエンドのアプリケーション状態をAgentに自動公開。

#### フロントエンド実装

```typescript
// app/page.tsx
import { useCopilotReadable } from "@copilotkit/react-core";
import { useState } from "react";

export default function Home() {
  const [cart, setCart] = useState([
    { id: 1, name: "Laptop", price: 1200 },
    { id: 2, name: "Mouse", price: 25 }
  ]);

  // 🔥 カート状態をAgentに公開
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

#### バックエンド側（自動アクセス）

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

#### 実行例

```
User: "合計いくら？"
Agent: （自動的にcart配列を参照）
       "現在のカートの合計は$1,225です。"
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
    streaming_buffer_size=1024  # デフォルトより大きく
)
```

#### セキュリティ考慮事項

```typescript
// 環境変数で秘密情報を管理
// .env.local
COPILOTKIT_SECRET_KEY=your-secret-key

// app/api/copilotkit/route.ts
export async function POST(req: Request) {
  const apiKey = req.headers.get("Authorization");
  if (apiKey !== process.env.COPILOTKIT_SECRET_KEY) {
    return new Response("Unauthorized", { status: 401 });
  }
  // プロキシ処理
}
```

---

## Streamlit統合

### Direct Python統合の利点

- **HTTP不要**: インプロセスでAgentを実行
- **高速プロトタイピング**: 数行のコードでUI作成
- **データサイエンス統合**: Pandas/Matplotlibとシームレスに連携

### 基本実装

```python
# app.py
import streamlit as st
from google.adk.agents import Agent
from google.adk.runners.in_memory import InMemoryRunner

# Agent初期化
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
    # ユーザーメッセージを表示
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    # Agent実行
    with st.chat_message("assistant"):
        with st.spinner("考え中..."):
            response = runner.run(prompt)
            st.markdown(response.messages[-1].content)
            st.session_state.messages.append({
                "role": "assistant",
                "content": response.messages[-1].content
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

### データビジュアライゼーション統合

```python
# app.py (データ分析Agent)
import streamlit as st
import pandas as pd
from google.adk.agents import Agent
from google.adk.tools import FunctionTool

def analyze_dataframe(query: str, df_csv: str) -> str:
    """Pandas DataFrameを分析"""
    import pandas as pd
    import io

    df = pd.read_csv(io.StringIO(df_csv))
    # クエリに基づいた分析ロジック
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

    # Agent実行
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

#### セッション管理

```python
# マルチユーザー対応
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

    # Agent実行
    response = runner.run(user_message)
    answer = response.messages[-1].content

    # Slackに返信
    say(text=answer, thread_ts=thread_ts)

# FastAPI統合
app = FastAPI()
handler = SlackRequestHandler(slack_app)

@app.post("/slack/events")
async def slack_events(req: Request):
    return await handler.handle(req)
```

### スレッド対応（コンテキスト保持）

```python
# app.py (スレッド対応版)
from collections import defaultdict

# スレッドごとにRunnerを管理
thread_runners = defaultdict(lambda: InMemoryRunner(agent=agent))

@slack_app.event("app_mention")
def handle_mention(event, say):
    user_message = event["text"]
    thread_ts = event.get("thread_ts", event["ts"])

    # スレッド固有のRunner使用
    runner = thread_runners[thread_ts]
    response = runner.run(user_message)

    say(text=response.messages[-1].content, thread_ts=thread_ts)
```

### リアクション処理

```python
# app.py (リアクション連携)
@slack_app.event("app_mention")
def handle_mention(event, say, client):
    channel = event["channel"]
    ts = event["ts"]

    # 🔄 処理中リアクション
    client.reactions_add(channel=channel, timestamp=ts, name="hourglass")

    try:
        response = runner.run(event["text"])
        say(text=response.messages[-1].content, thread_ts=ts)

        # ✅ 完了リアクション
        client.reactions_remove(channel=channel, timestamp=ts, name="hourglass")
        client.reactions_add(channel=channel, timestamp=ts, name="white_check_mark")
    except Exception as e:
        # ❌ エラーリアクション
        client.reactions_remove(channel=channel, timestamp=ts, name="hourglass")
        client.reactions_add(channel=channel, timestamp=ts, name="x")
        say(text=f"エラーが発生しました: {e}", thread_ts=ts)
```

### エンタープライズパターン（マルチワークスペース）

```python
# app.py (Enterprise Grid対応)
from slack_bolt import App
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
    agent = get_team_agent(team_id)  # カスタムロジック

    runner = InMemoryRunner(agent=agent)
    response = runner.run(event["text"])
    say(text=response.messages[-1].content)
```

---

## マルチモーダル画像処理

### 画像入力の3方式

#### 1. Inline Data（小さい画像用）

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

#### 2. File Data（大きい画像用・Cloud Storage）

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

# Cloud StorageのURIを使用
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

    # Content-Typeからmime_type推定
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

**選択基準:**
- **< 1MB**: `inline_data`（エンコード不要、低レイテンシ）
- **> 1MB**: `file_data`（Cloud Storageにアップロード）
- **外部URL**: HTTP取得→`inline_data`変換（キャッシング推奨）

### Vision Agentパターン

#### パターン1: 単一画像分析

```python
from google.adk.agents import Agent
from google.genai import types

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

# 実行例
image = load_image_inline("photo.jpg")
response = runner.run([
    types.Part(text="この写真を詳しく分析してください。"),
    image
])
print(response.messages[-1].content)
```

#### パターン2: 複数画像比較

```python
# 複数画像をインターリーブ
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

#### パターン3: Vision + Tool連携

```python
from google.adk.tools import FunctionTool
import json

def save_analysis_to_db(analysis: str, image_id: str) -> str:
    """分析結果をデータベースに保存"""
    # データベース保存ロジック
    return f"分析結果を保存しました（ID: {image_id}）"

vision_agent = Agent(
    model="gemini-2.0-flash-exp",
    instruction="""
    画像を分析し、save_analysis_to_db関数を使って
    結果をデータベースに保存してください。
    """,
    tools=[FunctionTool(save_analysis_to_db)]
)

image = load_image_inline("product.jpg")
response = runner.run([
    types.Part(text="この商品画像を分析して保存してください（ID: prod-123）"),
    image
])
```

### 画像生成（Gemini 2.5 Flash Image）

#### 基本生成

```python
from google.genai import types

# 画像生成用Agent
image_gen_agent = Agent(
    name="image_generator",
    model="gemini-2.5-flash-image",  # 画像生成モデル
    response_modalities=['Image'],  # 🔥 画像出力指定
    image_config=types.ImageConfig(
        aspect_ratio='1:1'  # アスペクト比指定
    )
)

runner = InMemoryRunner(agent=image_gen_agent)
response = runner.run("青い空と緑の草原の風景画を生成してください。")

# 生成画像の取得
for part in response.messages[-1].content:
    if part.inline_data:
        image_data = part.inline_data.data
        with open("generated.png", "wb") as f:
            f.write(image_data)
```

#### アスペクト比オプション

```python
# サポートされるアスペクト比
aspect_ratios = ['1:1', '16:9', '4:3', '3:2', '9:16']

image_config = types.ImageConfig(
    aspect_ratio='16:9',  # ワイドスクリーン
    # negative_prompt="blurry, low quality"  # ネガティブプロンプト（非推奨）
)

image_gen_agent = Agent(
    model="gemini-2.5-flash-image",
    response_modalities=['Image'],
    image_config=image_config
)
```

### 画像最適化ベストプラクティス

#### サイズ制限

```python
from PIL import Image
import io

def optimize_image(image_path: str, max_size_kb: int = 1024) -> bytes:
    """画像を最適化（サイズ制限・品質調整）"""
    img = Image.open(image_path)

    # サイズ調整（長辺1024px以下）
    max_dimension = 1024
    if max(img.size) > max_dimension:
        ratio = max_dimension / max(img.size)
        new_size = tuple(int(dim * ratio) for dim in img.size)
        img = img.resize(new_size, Image.Resampling.LANCZOS)

    # JPEG圧縮（品質調整）
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

# 使用例
optimized_data = optimize_image("large_photo.jpg", max_size_kb=1024)
image_part = types.Part(
    inline_data=types.Blob(data=optimized_data, mime_type='image/jpeg')
)
```

#### キャッシング戦略

```python
from functools import lru_cache
import hashlib

@lru_cache(maxsize=100)
def load_and_cache_image(image_url: str) -> types.Part:
    """画像をキャッシュして再利用"""
    response = requests.get(image_url)
    return types.Part(
        inline_data=types.Blob(
            data=response.content,
            mime_type=response.headers.get('Content-Type')
        )
    )

# 同じURLの画像は2回目以降キャッシュから取得
image = load_and_cache_image("https://example.com/logo.png")
```

---

## アーキテクチャパターン

### パターン1: モノリス（MVP向け）

**構成**: 単一Cloud Runインスタンスに全コンポーネント集約。

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

#### 実装例（Dockerfile）

```dockerfile
# Dockerfile
FROM python:3.11-slim

# フロントエンドビルド
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# バックエンド
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

# 静的ファイル配信設定
ENV STATIC_DIR=/app/frontend/out

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

```python
# main.py
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from google.adk.agents import Agent
from ag_ui_adk import ADKAgent, add_adk_fastapi_endpoint

app = FastAPI()

# Agent
agent = ADKAgent(adk_agent=Agent(model="gemini-2.0-flash-exp", ...))
add_adk_fastapi_endpoint(app, agent, path="/api/copilotkit")

# 静的ファイル配信
app.mount("/", StaticFiles(directory="frontend/out", html=True), name="static")
```

**利点**:
- デプロイ簡単（1コンテナ）
- コスト低（単一インスタンス）
- レイテンシ低（プロセス内通信）

**欠点**:
- スケーリング非効率（FE/BEが一緒）
- ビルド時間長い
- CDN非対応

### パターン2: 分離FE/BE（本番推奨）

**構成**: フロントエンドとバックエンドを独立デプロイ。

```
┌─────────────────┐      HTTPS      ┌──────────────────┐
│  Vercel/Netlify │ ←─────────────→ │  Cloud Run       │
│  (Frontend)     │  /api/* proxy   │  (Backend)       │
│  - Next.js      │                 │  - FastAPI       │
│  - CDN Cache    │                 │  - ADK Agent     │
└─────────────────┘                 └──────────────────┘
```

#### フロントエンド（Next.js + Vercel）

```typescript
// next.config.js
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

```typescript
// app/layout.tsx
<CopilotKit runtimeUrl="/api/copilotkit">
  {children}
</CopilotKit>
```

#### バックエンド（FastAPI + Cloud Run）

```yaml
# cloudbuild.yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/backend:$COMMIT_SHA', '.']
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/backend:$COMMIT_SHA']
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    args:
      - 'run'
      - 'deploy'
      - 'backend'
      - '--image=gcr.io/$PROJECT_ID/backend:$COMMIT_SHA'
      - '--region=us-central1'
      - '--allow-unauthenticated'
```

**利点**:
- 独立スケーリング（FE=CDN、BE=オートスケール）
- デプロイ高速（変更箇所のみ）
- セキュリティ向上（CORS制御）

**欠点**:
- 複雑度増加
- ネットワークレイテンシ

### パターン3: マイクロサービス（エンタープライズ）

**構成**: 複数Agent、API Gateway、非同期処理。

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

#### API Gateway（FastAPI）

```python
# gateway.py
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

#### Agent Service（Kubernetes Deployment）

```yaml
# agent-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sales-agent
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sales-agent
  template:
    metadata:
      labels:
        app: sales-agent
    spec:
      containers:
      - name: agent
        image: gcr.io/project/sales-agent:latest
        ports:
        - containerPort: 8080
        env:
        - name: GOOGLE_API_KEY
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: google-api-key
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: sales-agent-service
spec:
  selector:
    app: sales-agent
  ports:
  - port: 8080
    targetPort: 8080
```

#### 非同期処理（Pub/Sub）

```python
# agent_service.py
from google.cloud import pubsub_v1
from google.adk.agents import Agent
import json

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path('project-id', 'agent-tasks')

@app.post("/process")
async def process_task(payload: dict):
    # 長時間タスクはPub/Subにエンキュー
    if payload.get("async"):
        message_data = json.dumps(payload).encode("utf-8")
        publisher.publish(topic_path, message_data)
        return {"status": "queued", "task_id": payload["id"]}

    # 即時処理
    agent = Agent(model="gemini-2.0-flash-exp", ...)
    response = runner.run(payload["query"])
    return {"status": "completed", "result": response.messages[-1].content}
```

**利点**:
- 最高スケーラビリティ
- 障害分離（Agent単位）
- 水平スケーリング

**欠点**:
- 運用複雑度最高
- コスト高
- 開発・デバッグ困難

### アーキテクチャ選択ガイド

```python
if team_size <= 3 and users < 1000:
    推奨 = "モノリス（Cloud Run単一）"
elif team_size <= 10 and users < 100000:
    推奨 = "分離FE/BE（Vercel + Cloud Run）"
else:
    推奨 = "マイクロサービス（GKE + Pub/Sub）"
```

---

## AskUserQuestion統合

UI統合アプローチを選択する際、以下のAskUserQuestionを使用してユーザーの要件を明確化します。

```python
from google.adk.tools import AskUserQuestionTool

question_tool = AskUserQuestionTool(
    questions=[
        {
            "question": "使用予定のフロントエンドフレームワークを選択してください",
            "header": "フレームワーク選択",
            "options": [
                {
                    "label": "React/Next.js",
                    "description": "モダンWebアプリ → AG-UI Protocol推奨"
                },
                {
                    "label": "Streamlit",
                    "description": "データ分析/内部ツール → Direct Python推奨"
                },
                {
                    "label": "Slack/Teams",
                    "description": "チャットBot → Messaging Platform推奨"
                },
                {
                    "label": "カスタム/その他",
                    "description": "独自UI → Native ADK API推奨"
                }
            ],
            "multiSelect": False
        },
        {
            "question": "想定する同時接続ユーザー数は？",
            "header": "スケール要件",
            "options": [
                {"label": "< 100", "description": "小規模"},
                {"label": "100 - 10,000", "description": "中規模"},
                {"label": "> 10,000", "description": "大規模"}
            ],
            "multiSelect": False
        },
        {
            "question": "プロトタイプ完成までの期限は？",
            "header": "開発速度",
            "options": [
                {"label": "3日以内", "description": "高速プロトタイピング"},
                {"label": "1-2週間", "description": "標準開発"},
                {"label": "1ヶ月以上", "description": "エンタープライズ"}
            ],
            "multiSelect": False
        }
    ]
)
```

---

## まとめ

### UI統合の意思決定フロー

```
1. プロジェクト要件分析
   ├── フレームワーク選択
   ├── スケール要件
   └── 開発期限

2. アプローチ選択
   ├── React/Next.js → AG-UI Protocol
   ├── Streamlit → Direct Python
   ├── Slack/Teams → Messaging Platform
   └── カスタム → Native ADK API

3. アーキテクチャ設計
   ├── MVP → モノリス
   ├── 本番 → 分離FE/BE
   └── エンタープライズ → マイクロサービス

4. マルチモーダル対応
   ├── 画像入力 → inline_data / file_data
   └── 画像生成 → gemini-2.5-flash-image
```

### 次のステップ

1. **プロトタイプ作成**: CopilotKit + Next.js で基本動作確認
2. **ツール統合**: 必要な業務ツールをFunctionToolで実装
3. **パフォーマンス最適化**: ストリーミング、キャッシング導入
4. **本番デプロイ**: 分離FE/BEアーキテクチャに移行
5. **監視・ログ**: OpenTelemetry / Cloud Logging統合
