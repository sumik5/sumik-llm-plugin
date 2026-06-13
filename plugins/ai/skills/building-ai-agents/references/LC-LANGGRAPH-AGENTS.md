# LangGraph エージェント実装ガイド

LangGraph による Tool-based エージェント・マルチエージェントシステムの実装ガイド。
StateGraph の基礎から ReAct エージェント、Router/Supervisor パターンまでを網羅する。

---

## 目次

1. [エージェント vs アジェンティックワークフロー](#1-エージェント-vs-アジェンティックワークフロー)
2. [StateGraph の基礎](#2-stategraph-の基礎)
3. [Tool Calling の仕組み](#3-tool-calling-の仕組み)
4. [エージェントグラフの組み立て](#4-エージェントグラフの組み立て)
5. [ReAct エージェント（プリビルドコンポーネント）](#5-react-エージェントプリビルドコンポーネント)
6. [マルチエージェント: Router パターン](#6-マルチエージェント-router-パターン)
7. [マルチエージェント: Supervisor パターン](#7-マルチエージェント-supervisor-パターン)
8. [LangSmith によるトレーシング](#8-langsmith-によるトレーシング)
9. [アーキテクチャ判断テーブル](#9-アーキテクチャ判断テーブル)

---

## 1. エージェント vs アジェンティックワークフロー

| 特徴 | アジェンティックワークフロー | エージェント |
|------|--------------------------|------------|
| 実行フロー | 決定論的（事前定義された分岐） | 動的（LLMが実行時に判断） |
| ツール選択 | ハードコード | LLMが自律的に選択 |
| 適用場面 | 処理手順が明確な場合 | 未知のシナリオに対応が必要な場合 |
| 実装 | `StateGraph` + 条件付きエッジ | `create_react_agent` or 自作グラフ |

**使い分けの原則:**
- どのツールをいつ呼ぶか事前に決められない → エージェント
- 処理の順序と分岐が決まっている → アジェンティックワークフロー

---

## 2. StateGraph の基礎

### 状態定義（TypedDict）

```python
from typing import Annotated, Sequence
from typing_extensions import TypedDict
from langchain_core.messages import BaseMessage
import operator

# シンプルなエージェント状態（メッセージのみ）
class AgentState(TypedDict):
    messages: Annotated[Sequence[BaseMessage], operator.add]
```

`Annotated[Sequence[BaseMessage], operator.add]` の意味:
- 各ノードが返す `messages` は既存のリストに**追加**される（置換ではない）

### グラフ構造の基本

```python
from langgraph.graph import StateGraph, END, START

# グラフ構築
builder = StateGraph(AgentState)

# ノード追加
builder.add_node("node_a", node_a_function)
builder.add_node("node_b", node_b_function)

# エッジ追加
builder.add_edge("node_a", "node_b")
builder.add_edge("node_b", END)

# エントリーポイント設定
builder.set_entry_point("node_a")
# または: builder.add_edge(START, "node_a")

# グラフをコンパイル
app = builder.compile()

# 実行
result = app.invoke({"messages": [HumanMessage(content="質問")]})
```

### 条件付きエッジ

```python
def router_function(state: AgentState) -> str:
    """次のノードを決定する関数"""
    last_msg = state["messages"][-1]
    if hasattr(last_msg, "tool_calls") and last_msg.tool_calls:
        return "tools"  # ツール呼び出しがある場合
    return "end"  # ない場合は終了

# 条件付きエッジ: ルーター関数の返り値でルーティング
builder.add_conditional_edges(
    "llm_node",
    router_function,
    {
        "tools": "tools_node",
        "end": END
    }
)
```

---

## 3. Tool Calling の仕組み

### Function Calling から Tool Calling へ

LLMの進化により、ツール呼び出しプロトコルが標準化された。
LangChainは `bind_tools()` でOpenAI等のプロトコルを抽象化する。

### @tool デコレーター による Tool 定義

```python
from langchain_core.tools import tool

@tool
def search_travel_info(query: str) -> str:
    """旅行先に関する情報をWikivoyageコンテンツから検索する。"""
    docs = retriever.invoke(query)
    top = docs[:4] if isinstance(docs, list) else docs
    return "\n---\n".join(d.page_content for d in top)

@tool(description="指定した都市の天気予報を返す。")
def weather_forecast(town: str) -> dict:
    """Get weather forecast for a town."""
    forecast = WeatherForecastService.get_forecast(town)
    if forecast is None:
        return {"error": f"'{town}'の天気データがありません。"}
    return forecast
```

**効果的なツール説明の要件:**
- いつ使うべきかを明確に記述
- 入力パラメーターと期待される出力を説明
- 類似ツールとの区別を明示

### LLM へのツール登録

```python
from langchain_openai import ChatOpenAI

llm_model = ChatOpenAI(
    model="gpt-4o",
    use_responses_api=True  # Responses API を使用（推奨）
)

TOOLS = [search_travel_info, weather_forecast]

# ツールをLLMにバインド
llm_with_tools = llm_model.bind_tools(TOOLS)
```

### ToolNode（プリビルドのツール実行ノード）

```python
from langgraph.prebuilt import ToolNode

# プリビルドのToolNode（手動実装不要）
tools_execution_node = ToolNode(TOOLS)
```

内部では:
1. LLMの最新メッセージから `tool_calls` を抽出
2. ツール名と引数でツールを呼び出し
3. 結果を `ToolMessage` としてメッセージリストに追加

---

## 4. エージェントグラフの組み立て

### LLM ノードの実装

```python
from langchain_core.messages import SystemMessage

def llm_node(state: AgentState):
    """LLMがツール呼び出しか回答かを判断するノード"""
    current_messages = state["messages"]

    # システムメッセージでLLMの行動を制御（重要）
    system_message = SystemMessage(content="""
あなたは旅行情報と天気予報を提供するアシスタントです。
情報取得には必ず提供されたツールを使用してください
（町名の特定を含む）。
    """)

    messages_with_system = list(current_messages) + [system_message]
    response = llm_with_tools.invoke(messages_with_system)
    return {"messages": [response]}
```

### 単一ツールエージェントのグラフ

```python
from langgraph.prebuilt import tools_condition

# グラフ構築
builder = StateGraph(AgentState)
builder.add_node("llm_node", llm_node)
builder.add_node("tools", ToolNode(TOOLS))

# 条件付きエッジ（ツール呼び出しがあれば tools ノードへ、なければ終了）
builder.add_conditional_edges("llm_node", tools_condition)

# ツール実行後は LLM ノードに戻る
builder.add_edge("tools", "llm_node")

# エントリーポイント
builder.set_entry_point("llm_node")

# コンパイル
travel_agent = builder.compile()
```

### エージェントグラフの実行フロー

```
ユーザー質問
    ↓
[llm_node]: LLMが質問を分析
    │
    ├─ ツール呼び出しあり → [tools]: ToolNodeがツールを実行
    │                            ↓
    │                       [llm_node]: 結果を受け取り再推論
    │                            │
    └─ ツール呼び出しなし → [END]: 最終回答を返す
```

### チャットループ（REPL）の実装

```python
from langchain_core.messages import HumanMessage

def chat_loop():
    print("アシスタント（'exit'で終了）")
    while True:
        user_input = input("You: ").strip()
        if user_input.lower() in {"exit", "quit"}:
            break

        state = {"messages": [HumanMessage(content=user_input)]}
        result = travel_agent.invoke(state)
        last_msg = result["messages"][-1]
        print(f"Assistant: {last_msg.content}\n")

if __name__ == "__main__":
    chat_loop()
```

---

## 5. ReAct エージェント（プリビルドコンポーネント）

### create_react_agent による簡易実装

グラフの手動構築を省略し、ReAct パターンを簡単に実装できる。

```python
from langgraph.prebuilt import create_react_agent
from langgraph.managed.is_last_step import RemainingSteps

# AgentState に RemainingSteps を追加（prebuilt 使用時に推奨）
class AgentState(TypedDict):
    messages: Annotated[Sequence[BaseMessage], operator.add]
    remaining_steps: RemainingSteps

# ReAct エージェントを作成（グラフ構築・ツールバインドが不要）
travel_agent = create_react_agent(
    model=llm_model,
    tools=TOOLS,
    state_schema=AgentState,
    prompt="""
あなたは旅行情報と天気予報を提供するアシスタントです。
情報取得には必ず提供されたツールを使用してください（町名の特定を含む）。
    """
)
```

**手動実装 vs prebuilt の比較:**

| 項目 | 手動実装 | create_react_agent |
|------|---------|-------------------|
| コード量 | 多い（グラフ構築必要） | 少ない |
| 可視性 | 高い（デバッグしやすい） | LangSmithで補完 |
| カスタマイズ性 | 高い | 制限あり |
| 推奨用途 | 独自ロジックが必要な場合 | 標準的なReActパターン |

---

## 6. マルチエージェント: Router パターン

### 概要

複数の専門エージェントを1つのルーターで管理する「シングルパスルーティング」。
各クエリは1つの専門エージェントにのみ転送される（「片道切符」）。

```
ユーザー質問 → Router Agent → 旅行情報エージェント OR 宿泊予約エージェント → 終了
```

### Router Agent の実装

```python
from enum import Enum
from pydantic import BaseModel, Field
from langgraph.graph import StateGraph, END
from langgraph.types import Command

class AgentType(str, Enum):
    travel_info = "travel_info_agent"
    accommodation = "accommodation_booking_agent"

class AgentTypeOutput(BaseModel):
    agent: AgentType = Field(description="どのエージェントが処理すべきか？")

# 構造化出力でルーティング判断を強制（文字列パース不要）
llm_router = llm_model.with_structured_output(AgentTypeOutput)

ROUTER_PROMPT = """
あなたはルーターです。ユーザーのメッセージを以下のいずれかに分類してください:
- travel_info_agent: 旅行先、観光スポット、一般旅行情報に関する質問
- accommodation_booking_agent: ホテル、B&B、空室確認、価格に関する質問

ユーザーのメッセージに基づいて適切なエージェントを返してください。
"""

def router_agent_node(state: AgentState) -> Command[AgentType]:
    """ルーターノード: クエリをどのエージェントに転送するか決定"""
    messages = state["messages"]
    last_msg = messages[-1] if messages else None

    if isinstance(last_msg, HumanMessage):
        router_messages = [
            SystemMessage(content=ROUTER_PROMPT),
            HumanMessage(content=last_msg.content)
        ]
        response = llm_router.invoke(router_messages)
        agent_name = response.agent.value
        return Command(update=state, goto=agent_name)

    # デフォルト: 旅行情報エージェントへ
    return Command(update=state, goto=AgentType.travel_info.value)
```

### Router 多エージェントグラフの組み立て

```python
from langgraph.graph import StateGraph, END

# グラフ構築
graph = StateGraph(AgentState)
graph.add_node("router_agent", router_agent_node)
graph.add_node("travel_info_agent", travel_info_agent)
graph.add_node("accommodation_booking_agent", accommodation_booking_agent)

# 専門エージェントから終了へのエッジ
graph.add_edge("travel_info_agent", END)
graph.add_edge("accommodation_booking_agent", END)

# エントリーポイントをルーターに設定
graph.set_entry_point("router_agent")

# コンパイル
travel_assistant = graph.compile()
```

**注意:** ルーター → 専門エージェントのエッジは `Command` オブジェクトで動的に決定されるため、明示的なエッジ定義は不要。

---

## 7. マルチエージェント: Supervisor パターン

### 概要

Supervisor が複数の専門エージェントを「ツール」として管理するパターン（「往復切符」）。
複数エージェントを組み合わせた複雑なリクエストを処理できる。

```
ユーザー複合質問
    ↓
Supervisor Agent
    ├─ → 旅行情報エージェント（検索）→ Supervisor（結果受け取り）
    └─ → 宿泊予約エージェント（検索）→ Supervisor（統合） → 終了
```

**Router vs Supervisor の違い:**

| 観点 | Router | Supervisor |
|------|--------|-----------|
| 呼び出し | 1回のみ（片道切符） | 複数回可能（往復切符） |
| 複合質問 | 対応不可 | 対応可能 |
| 実装複雑度 | 低 | 高 |
| 使用LLM | 軽量で可 | 高性能モデル推奨 |

### Supervisor の実装

```python
from langgraph_supervisor.supervisor import create_supervisor
from langchain_openai import ChatOpenAI

# 専門エージェント定義（必ず名前を付ける）
travel_info_agent = create_react_agent(
    model=llm_model,
    tools=TRAVEL_TOOLS,
    state_schema=AgentState,
    name="travel_info_agent",
    prompt="旅行情報を検索して提供するアシスタントです。"
)

accommodation_agent = create_react_agent(
    model=llm_model,
    tools=BOOKING_TOOLS,
    state_schema=AgentState,
    name="accommodation_booking_agent",
    prompt="ホテルとB&Bの空室情報を確認するアシスタントです。"
)

# Supervisor の作成（より高性能なモデルを使用）
travel_assistant = create_supervisor(
    agents=[travel_info_agent, accommodation_agent],
    model=ChatOpenAI(model="gpt-4o", use_responses_api=True),
    supervisor_name="travel_assistant",
    prompt="""
あなたは旅行情報エージェントと宿泊予約エージェントを管理するスーパーバイザーです。
複雑なリクエストには複数のエージェントを組み合わせて回答してください。
    """
).compile()
```

### Supervisor の実行フロー例

複合質問:「天気の良い海辺の町を探して、その町のダブルルームの空室と価格も教えて」

```
Supervisor
  └→ transfer_to_travel_info_agent（天気確認）
       travel_info_agent
         └→ search_travel_info（海辺の町を検索）
         └→ weather_forecast（各町の天気確認）
  └→ transfer_to_accommodation_booking_agent（空室確認）
       accommodation_booking_agent
         └→ check_bnb_availability（B&B空室確認）
         └→ sql_db_query（ホテル空室確認）
  └→ 最終回答統合
```

---

## 8. LangSmith によるトレーシング

### 設定

`.env` ファイルに追加:

```bash
LANGSMITH_TRACING=true
LANGSMITH_ENDPOINT="https://api.smith.langchain.com"
LANGSMITH_API_KEY="<your-api-key>"
LANGSMITH_PROJECT="my-agent-project"
```

`load_dotenv()` で読み込み後、自動でトレーシングが有効化される。

### トレースで確認できる情報

- LLMノードの入出力メッセージ
- どのツールを選択したか（ツール名・引数）
- ツールの実行結果
- 各ステップのレイテンシ・トークン数
- エージェント間のハンドオフ（Supervisorパターン）

### デバッグのベストプラクティス

1. **ブレークポイントデバッグ**: ツール関数・LLMノード・ToolsExecutionNodeにブレークポイントを設定して状態を確認
2. **messages の検査**: 各ノードで `state["messages"]` を確認し、LLMの推論過程を追う
3. **tool_calls フィールド**: LLMが返す `AIMessage.tool_calls` でツール選択意図を確認
4. **LangSmith トレース**: 複雑なマルチエージェントの実行フローはLangSmithで可視化

---

## 9. アーキテクチャ判断テーブル

### エージェントアーキテクチャの選択

| 要件 | 推奨アーキテクチャ | 理由 |
|-----|-----------------|------|
| 単純な質問、1種類のツール | 単一エージェント（手動グラフ） | 実装が簡単、フロー把握しやすい |
| 複数ツール、ツール連鎖あり | ReAct エージェント（prebuilt） | LLMが自動でツール選択・連鎖 |
| 明確に分離できる2種類のドメイン | Router パターン | 各クエリを専門エージェントに転送 |
| 複合クエリ（複数ドメイン跨ぎ） | Supervisor パターン | 複数エージェントの協調が必要 |
| カスタムロジック・複雑な状態管理 | 手動 StateGraph | 最大の制御性・カスタマイズ性 |

### ツール定義のベストプラクティス

| チェック項目 | 悪い例 | 良い例 |
|-----------|--------|--------|
| ツール名 | `func1` | `search_hotel_availability` |
| description | なし | 「指定した都市のホテル空室と価格を検索する。」 |
| 戻り値の型 | `str` | `dict` or `List[Dict]` |
| エラーハンドリング | なし | `{"error": "理由"}` を返す |

### ルーティングプロンプト設計

ルーターとSupervisorのプロンプトには以下を含める:

```python
ROUTER_PROMPT = """
エージェント分類基準:
- travel_info_agent:
  - 旅行先、観光スポット、アクティビティの質問
  - 「〜について教えて」「〜でおすすめは？」
  - 天気情報（旅行コンテキスト）
- accommodation_booking_agent:
  - ホテル・B&Bの空室確認
  - 宿泊料金の確認
  - 「〜に泊まれますか？」「〜の値段は？」

エッジケース（分類が曖昧な場合）:
- デフォルトは travel_info_agent
- 宿泊関連のキーワード（hotel, B&B, room, availability, price）があれば accommodation
"""
```

### エージェント間のデータ受け渡し

```python
# 悪い例: 自然言語でエージェント間通信
"ニューキーの天気は晴れで気温26度です。次にそこのホテルを探してください。"

# 良い例: 構造化データ（JSON）で受け渡し
{
    "town": "Newquay",
    "weather": "sunny",
    "temperature": 26,
    "action": "search_accommodation"
}
```

---

## 環境セットアップ

```bash
# 基本パッケージ
pip install langchain langgraph langchain-openai langchain-chroma

# Supervisor パターン使用時
pip install langgraph-supervisor

# トレーシング
pip install langsmith

# .env ファイル設定
OPENAI_API_KEY=<your-key>
LANGSMITH_API_KEY=<your-key>
LANGSMITH_TRACING=true
```

---

**関連ファイル:**
- → RAGパイプライン実装は `RAG-PIPELINE.md` 参照
- → MCPサーバー統合は `MCP-INTEGRATION.md` 参照
- → メモリ・ガードレール・本番化は `PRODUCTION.md` 参照
- → LangChain LCEL・チェーン基礎は `LANGCHAIN-CORE.md` 参照
