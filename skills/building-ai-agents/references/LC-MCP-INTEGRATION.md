# MCP統合ガイド: LangGraphエージェントとMCPサーバー

LangGraphエージェントからMCPサーバーを構築・消費するための実装ガイド。
MCPプロトコル自体の詳細は `developing-mcp` を参照。本ドキュメントはLangGraph統合に特化。

---

## 目次

1. [MCPの概要と課題解決](#1-mcpの概要と課題解決)
2. [MCPサーバーの構築](#2-mcpサーバーの構築)
3. [MCP Inspectorによるテスト](#3-mcp-inspectorによるテスト)
4. [LangGraphエージェントからのMCPツール消費](#4-langgraphエージェントからのmcpツール消費)
5. [ローカルとリモートツールの併用](#5-ローカルとリモートツールの併用)
6. [差別化: developing-mcpとの使い分け](#6-差別化-developing-mcpとの使い分け)

---

## 1. MCPの概要と課題解決

### 課題: コンテキスト統合のスケール問題

従来のエージェント開発では、外部データソース（天気API・DBサービス・検索API等）ごとに独自のラッパーツールを作成する必要があった。その結果:

- 各チームが同じラッパーコードを重複実装
- プロトコルや規約がサービスごとに異なる
- 新しいデータソースの追加コストが高い

### 解決策: Model Context Protocol (MCP)

MCPはAnthropicが設計した標準化プロトコル。サービス提供者がMCPサーバーとしてツールを公開し、エージェント（MCPホスト）はMCPクライアント経由で消費できる。

```
MCPホストプロセス（LangGraphエージェント）
├── MCPクライアント1 → ローカルMCPサーバー1（ファイルシステムツール）
├── MCPクライアント2 → リモートMCPサーバー2（外部APIツール）
└── MCPクライアント3 → リモートMCPサーバー3（DBツール）
```

**主要な特徴:**
- MCPサーバーは `stdio`（ローカル開発）または `Streamable HTTP`（本番）で通信
- 一度設定すれば、MCPツールはローカルツールとまったく同じように動作
- 2024年末以降、OpenAI・GoogleもMCPをAPI/SDKに採用

### MCPエコシステム

公開MCPサーバーポータル:

| ポータル | 概要 |
|---------|------|
| github.com/modelcontextprotocol/servers | Anthropic公式（公式＋コミュニティ） |
| mcp.so | コミュニティ主導（16,000+サーバー） |
| smithery.ai | 5,000+ツール |
| mcpservers.org | 約1,500サーバー |

---

## 2. MCPサーバーの構築

### FastMCP 2の使用（Python SDK）

MCPサーバーのゼロからの実装は非推奨。代わりに公式SDKを使用する。

**Pythonの場合: FastMCP 2**

```bash
pip install fastmcp
```

### @mcp.toolデコレータによるツール定義

```python
import os
import json
from typing import Dict
from fastmcp import FastMCP
from dotenv import load_dotenv
from aiohttp import ClientSession

load_dotenv()

# MCPサーバーの初期化
mcp = FastMCP("mcp-weather-server")

# ツール定義: @mcp.toolデコレータで自動スキーマ生成
@mcp.tool(description="Get weather conditions for a location.")
async def get_weather_conditions(location: str) -> Dict:
    """指定地点の現在の気象状況を取得する"""
    api_key = os.getenv("WEATHER_API_KEY")
    base_url = "https://api.weather-service.com"

    async with ClientSession() as session:
        # ロケーション解決
        location_url = f"{base_url}/locations/search"
        async with session.get(location_url, params={"q": location, "apikey": api_key}) as resp:
            locations = await resp.json()
            location_key = locations[0]["Key"]

        # 気象データ取得
        conditions_url = f"{base_url}/conditions/{location_key}"
        async with session.get(conditions_url, params={"apikey": api_key}) as resp:
            conditions = await resp.json()
            return {
                "location": locations[0]["LocalizedName"],
                "temperature": conditions[0]["Temperature"]["Metric"]["Value"],
                "weather_text": conditions[0]["WeatherText"],
                "humidity": conditions[0].get("RelativeHumidity"),
            }

# サーバー起動
if __name__ == "__main__":
    mcp.run(
        transport="streamable-http",
        host="127.0.0.1",
        port=8020,
        path="/weather-mcp-server"
    )
```

**FastMCP 2のポイント:**
- `@mcp.tool` デコレータが型ヒントからJSONスキーマを自動生成
- `async def` により非同期ツール実装が可能
- `mcp.run()` で即座にHTTPサーバーが起動

### MCPサーバーの起動

```bash
# 仮想環境のアクティベート後
python weather_mcp_server.py
# → INFO: Uvicorn running on http://0.0.0.0:8020
```

---

## 3. MCP Inspectorによるテスト

プログラマティックな統合前に、MCP Inspectorで動作確認を行う。

### インストールと起動

```bash
# Node.jsが必要
npx @modelcontextprotocol/inspector
# → MCP Inspector is up and running at: http://localhost:6274/
```

### 接続設定

| 項目 | 値 |
|-----|-----|
| Transport Type | Streamable HTTP |
| URL | http://127.0.0.1:8020/weather-mcp-server |
| Connection Type | Via Proxy |
| Authentication | 無効化（開発時） |

接続後、**Tools** タブ → **List Tools** でツール一覧を確認できる。

### テストMCPホストによる確認

```python
from fastmcp import Client
from fastmcp.client.transports import StreamableHttpTransport
import asyncio

transport = StreamableHttpTransport(url="http://localhost:8020/weather-mcp-server")
client = Client(transport)

async def main():
    async with client:
        # ツール一覧の取得
        tools = await client.list_tools()
        print(f"Available tools: {tools}")

        # ツールの呼び出し
        if any(t.name == "get_weather_conditions" for t in tools):
            result = await client.call_tool(
                "get_weather_conditions",
                {"location": "Tokyo, Japan"}
            )
            print(f"Result: {result}")

asyncio.run(main())
```

---

## 4. LangGraphエージェントからのMCPツール消費

### MultiServerMCPClientの使用

LangChainが提供する `MultiServerMCPClient` を使うと、複数のMCPサーバーのツールを一元管理できる。

```python
from langchain_mcp_adapters.client import MultiServerMCPClient
from langgraph.prebuilt import create_react_agent
from langchain_openai import ChatOpenAI

async def get_weather_mcp_tools():
    """MCPサーバーからツールを非同期で取得"""
    mcp_client = MultiServerMCPClient({
        "weather": {
            "url": "http://127.0.0.1:8020/weather-mcp-server",
            "transport": "streamable_http"
        }
        # 複数サーバーも同様に登録可能
    })
    return await mcp_client.get_tools()
```

### MCPツールとローカルツールの統合

```python
from typing import Annotated, Sequence
from typing_extensions import TypedDict
from langchain_core.messages import BaseMessage
import operator
from langgraph.managed.is_last_step import RemainingSteps

class AgentState(TypedDict):
    messages: Annotated[Sequence[BaseMessage], operator.add]
    remaining_steps: RemainingSteps

async def main():
    # MCPツール取得
    weather_tools = await get_weather_mcp_tools()

    # ローカルツールとの統合
    from mytools import search_local_data  # ローカルツール
    all_tools = [search_local_data, *weather_tools]

    llm = ChatOpenAI(model="gpt-4o-mini")

    # create_react_agentにツールを渡す（MCPツールもローカルツールも同じIF）
    agent = create_react_agent(
        model=llm,
        tools=all_tools,
        state_schema=AgentState,
        prompt="あなたは旅行情報と天気予報を提供するアシスタントです。"
               "ツールのみを使用して情報を検索してください。"
    )

    await chat_loop(agent)

if __name__ == "__main__":
    asyncio.run(main())
```

### 非同期チャットループ

MCPツールを使う場合、チャットループは非同期にする必要がある。

```python
async def chat_loop(agent):
    """非同期チャットループ"""
    print("アシスタント (終了は 'exit')")
    while True:
        user_input = input("You: ").strip()
        if user_input.lower() in {"exit", "quit"}:
            break

        state = {"messages": [HumanMessage(content=user_input)]}
        result = await agent.ainvoke(state)  # await が必要
        response = result["messages"][-1]
        print(f"Assistant: {response.content}\n")
```

---

## 5. ローカルとリモートツールの併用パターン

### ツール混在パターンの判断基準

| ツールタイプ | 適用場面 | 例 |
|------------|---------|-----|
| **ローカルツール** | プライベートデータ・社内システム・低レイテンシが必要な場合 | ベクトルDB検索・SQLクエリ |
| **MCPツール** | 外部API・第三者サービス・標準化されたインターフェース | 天気API・地図API・決済サービス |
| **混在** | 両方が必要な場合（最も一般的） | 社内RAG + 外部API |

### 混在時のデバッグ: LangSmith活用

```python
# .envに追加
LANGSMITH_TRACING=true
LANGSMITH_ENDPOINT="https://api.smith.langchain.com"
LANGSMITH_API_KEY="<your-key>"
LANGSMITH_PROJECT="my-mcp-agent"
```

LangSmithトレースで各ツール呼び出し（ローカル・MCP問わず）の実行フローを確認できる。

### 複数MCPサーバーの統合例

```python
mcp_client = MultiServerMCPClient({
    "weather": {
        "url": "http://127.0.0.1:8020/weather-mcp-server",
        "transport": "streamable_http"
    },
    "maps": {
        "url": "http://127.0.0.1:8021/maps-mcp-server",
        "transport": "streamable_http"
    },
    "booking": {
        "url": "http://127.0.0.1:8022/booking-mcp-server",
        "transport": "streamable_http"
    }
})
all_mcp_tools = await mcp_client.get_tools()
```

---

## 6. 差別化: developing-mcpとの使い分け

| 観点 | 本スキル（building-langchain-agents） | developing-mcp |
|-----|--------------------------------------|----------------|
| **対象** | LangGraphエージェントからMCPを消費する実装 | MCPプロトコル・サーバー/クライアントの詳細設計 |
| **SDK** | FastMCP 2（Python）・MultiServerMCPClient | TypeScript SDK・Python SDK（全般） |
| **焦点** | LangGraph統合・ツール混在パターン | JSON-RPC仕様・セキュリティ脅威（Tool Poisoning等） |
| **対象読者** | LangGraphエージェント開発者 | MCPサーバープロバイダー・プロトコル実装者 |

**使い分けガイド:**
- LangGraphエージェントからMCPツールを使いたい → 本スキル（MCP-INTEGRATION.md）
- MCPサーバー/クライアントのプロトコル詳細・セキュリティ設計 → `developing-mcp`
- Vercel AI SDK (JS/TS) でのMCP統合 → `integrating-ai-web-apps`

---

## チェックリスト

### MCPサーバー構築時
- [ ] FastMCP 2を使用（`pip install fastmcp`）
- [ ] `@mcp.tool` デコレータで型ヒントを明示（自動スキーマ生成）
- [ ] MCP Inspectorで動作確認
- [ ] テストMCPホストでツール呼び出しを検証

### LangGraphへの統合時
- [ ] `MultiServerMCPClient` でMCPサーバーを登録
- [ ] ツール取得は `async` 関数内で実施
- [ ] `create_react_agent` にローカルツールと `*mcp_tools` を混在渡し
- [ ] チャットループを `async def` に変更（`ainvoke` 使用）
- [ ] LangSmithトレーシングでツール呼び出しを確認
