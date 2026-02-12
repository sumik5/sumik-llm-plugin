# Agent と Tools 詳細ガイド

## 目次

1. [LlmAgent詳細](#llmagent詳細)
2. [FunctionTool](#functiontool)
3. [Pre-built Tools](#pre-built-tools)
4. [OpenAPI統合](#openapi統合)
5. [MCP統合](#mcp統合)

---

## LlmAgent詳細

### Agent定義の基本

```python
from google.adk.agents import Agent  # LlmAgentのエイリアス

agent = Agent(
    name="example_agent",         # 必須: Agent識別子
    model="gemini-2.0-flash",     # 必須: LLMモデル
    instruction="あなたは...",     # 推奨: システムプロンプト
    description="このAgentは...",  # マルチAgent時重要
    tools=[...],                  # オプション: ツールリスト
    planner=...,                  # オプション: プランナー
    generate_content_config=...,  # オプション: LLM設定
    before_agent_callback=...,    # オプション: コールバック
    after_agent_callback=...,
    before_model_callback=...,
    after_model_callback=...
)
```

### Static vs Dynamic Instructions

#### Static Instructions

```python
agent = Agent(
    name="translator",
    model="gemini-2.0-flash",
    instruction="ユーザーの入力を英語からフランス語に翻訳してください。"
)
```

**特徴:**
- 固定の文字列をLLMに送信
- 全リクエストで同じ指示が適用される
- 単純で予測可能なAgent動作に適用

#### Dynamic Instructions (InstructionProvider)

```python
from google.adk.agents.readonly_context import ReadonlyContext
from datetime import datetime

def time_based_greeting(context: ReadonlyContext) -> str:
    hour = datetime.now().hour
    user_name = context.state.get("user:user_name", "ユーザー")

    if 5 <= hour < 12:
        time_of_day = "朝"
    elif 12 <= hour < 18:
        time_of_day = "午後"
    else:
        time_of_day = "夜"

    return f"あなたは親切なアシスタントです。{user_name}さんに{time_of_day}の挨拶をしてください。"

agent = Agent(
    name="dynamic_greeter",
    model="gemini-2.0-flash",
    instruction=time_based_greeting  # 関数を渡す
)
```

**InstructionProviderの要件:**
- `ReadonlyContext`を受け取り`str`を返す関数（または`async def`）
- `context.state`から状態を読み取り可能
- 自動状態注入 (`{変数名}`) はInstructionProvider使用時は**無効**（関数内で明示的に`context.state.get()`を使用）

**使用タイミング:**
- ユーザーロール・時間・セッション状態に応じた動的指示が必要な場合
- 外部要因に基づきAgentの振る舞いを変更する場合

### generate_content_configの活用

```python
from google.genai.types import GenerateContentConfig, SafetySetting, HarmCategory, HarmBlockThreshold

agent = Agent(
    name="creative_writer",
    model="gemini-2.0-flash",
    instruction="創造的なストーリーを書いてください。",
    generate_content_config=GenerateContentConfig(
        temperature=0.9,           # 創造性高（0.0-1.0）
        top_p=0.95,                # トークンサンプリング
        top_k=40,
        max_output_tokens=1024,    # 最大トークン数
        stop_sequences=["END"],    # 停止文字列
        safety_settings=[
            SafetySetting(
                category=HarmCategory.HARM_CATEGORY_HARASSMENT,
                threshold=HarmBlockThreshold.BLOCK_NONE
            )
        ],
        response_mime_type="application/json",  # JSON出力を期待（構造化出力用）
        response_schema=...         # Pydantic Modelから生成したスキーマ
    )
)
```

**主要パラメータ:**

| パラメータ | 説明 | 推奨値 |
|----------|------|--------|
| `temperature` | ランダム性制御（0.0～1.0） | 事実: 0.0-0.3, 創造: 0.7-1.0 |
| `top_p` | 累積確率サンプリング | 0.95（デフォルト） |
| `top_k` | トークンサンプリング数 | 40（デフォルト） |
| `max_output_tokens` | 生成トークン数上限 | タスクに応じて調整 |
| `stop_sequences` | 生成停止トリガー文字列 | 特定パターンで停止したい場合 |
| `safety_settings` | コンテンツ安全フィルタ | HarmCategory別に設定 |
| `response_mime_type` | レスポンス形式 | `application/json`（構造化出力） |
| `response_schema` | JSON出力スキーマ | Pydanticモデルから生成 |

**重要（ADK固有制約）:**
- `system_instruction`は設定しない → `LlmAgent.instruction`を使用
- `tools`は設定しない → `LlmAgent.tools`を使用
- `thinking_config`は設定しない → `LlmAgent.planner`を使用

**構造化出力の例:**
```python
from pydantic import BaseModel

class WeatherResponse(BaseModel):
    temperature: float
    condition: str

agent = Agent(
    name="weather_bot",
    model="gemini-2.0-flash",
    instruction="天気情報をJSON形式で返してください。",
    generate_content_config=GenerateContentConfig(
        response_mime_type="application/json",
        response_schema=WeatherResponse.model_json_schema()
    )
)
```

### Callbacks（コールバック）

#### before_agent_callback

```python
from google.adk.agents.callback_context import CallbackContext
from google.genai.types import Content, Part
from typing import Optional

def validate_user(context: CallbackContext) -> Optional[Content]:
    if "blocked" in context.state.get("user:flags", []):
        return Content(parts=[Part(text="申し訳ありません、リクエストを処理できません。")])
    return None  # 通常実行

agent = Agent(
    name="validated_agent",
    model="gemini-2.0-flash",
    instruction="...",
    before_agent_callback=validate_user
)
```

#### before_model_callback

```python
from google.adk.models.llm_request import LlmRequest
from google.adk.models.llm_response import LlmResponse

async def modify_prompt(context: CallbackContext, llm_request: LlmRequest) -> Optional[LlmResponse]:
    # プロンプト修正
    if llm_request.contents and llm_request.contents[-1].role == "user":
        llm_request.contents[-1].parts[0].text = (
            f"重要: {llm_request.contents[-1].parts[0].text}"
        )
    return None  # 通常のLLM呼び出し続行

agent = Agent(
    name="prompt_modifier",
    model="gemini-2.0-flash",
    instruction="...",
    before_model_callback=modify_prompt
)
```

#### after_model_callback

```python
def log_usage(context: CallbackContext, llm_response: LlmResponse) -> Optional[LlmResponse]:
    if llm_response.usage_metadata:
        print(f"トークン使用量: {llm_response.usage_metadata.total_token_count}")

    # レスポンス修正
    if llm_response.content and llm_response.content.parts[0].text:
        llm_response.content.parts[0].text += " (検証済み)"

    return llm_response

agent = Agent(
    name="usage_logger",
    model="gemini-2.0-flash",
    instruction="...",
    after_model_callback=log_usage
)
```

---

## FunctionTool

### 基本的なFunctionTool

`FunctionTool`は任意のPython関数をADKツールに変換する。

**動作原理:**
1. Python関数のシグネチャ（型ヒント）を解析
2. docstringからツール説明とパラメータ説明を抽出
3. LLM用の`FunctionDeclaration`（スキーマ）を自動生成
4. LLMからの呼び出しをPython関数実行にマッピング

```python
from google.adk.tools import FunctionTool

def calculate(operand1: float, operand2: float, operation: str) -> float:
    """
    基本的な算術演算を実行します。

    Args:
        operand1: 最初の数値
        operand2: 2番目の数値
        operation: 演算子 ('add', 'subtract', 'multiply', 'divide')

    Returns:
        計算結果
    """
    if operation == 'add':
        return operand1 + operand2
    elif operation == 'subtract':
        return operand1 - operand2
    elif operation == 'multiply':
        return operand1 * operand2
    elif operation == 'divide':
        if operand2 == 0:
            return "エラー: ゼロ除算"
        return operand1 / operand2
    else:
        return f"エラー: 無効な演算子 '{operation}'"

calculator_tool = FunctionTool(func=calculate)

agent = Agent(
    name="calculator",
    model="gemini-2.0-flash",
    instruction="計算ツールを使って算術演算を実行してください。",
    tools=[calculator_tool]
)
```

**自動スキーマ生成結果（概念図）:**
```json
{
  "name": "calculate",
  "description": "基本的な算術演算を実行します。",
  "parameters": {
    "type": "OBJECT",
    "properties": {
      "operand1": {"type": "NUMBER", "description": "最初の数値"},
      "operand2": {"type": "NUMBER", "description": "2番目の数値"},
      "operation": {"type": "STRING", "description": "演算子 ('add', 'subtract', 'multiply', 'divide')"}
    },
    "required": ["operand1", "operand2", "operation"]
  }
}
```

### 型ヒントとPydanticモデル

#### Literal型（列挙値）

```python
from typing import Literal

def set_status(status: Literal["pending", "active", "completed"]) -> str:
    """ステータスを設定します。"""
    return f"ステータスを{status}に設定しました"

status_tool = FunctionTool(func=set_status)
```

#### Pydanticモデル

```python
from pydantic import BaseModel, Field

class UserProfile(BaseModel):
    username: str = Field(description="ユーザー名")
    email: str = Field(description="メールアドレス")
    age: int = Field(description="年齢")

def update_profile(profile: dict) -> dict:
    """
    ユーザープロファイルを更新します。

    Args:
        profile: UserProfileオブジェクト
    """
    try:
        validated = UserProfile.model_validate(profile)
        print(f"{validated.username}のプロファイルを更新")
        return {"status": "success", "username": validated.username}
    except Exception as e:
        return {"status": "error", "message": str(e)}

profile_tool = FunctionTool(func=update_profile)
```

**注意:** `EmailStr`などの特殊型を使う場合、カスタムTool実装が必要:

```python
from google.adk.tools import BaseTool
from google.genai.types import FunctionDeclaration, Schema, Type as GeminiType
from typing import override, Dict, Any, Optional

class CustomProfileTool(BaseTool):
    def __init__(self):
        super().__init__(
            name="update_user_profile",
            description="ユーザープロファイルを更新します"
        )

    @override
    def _get_declaration(self) -> FunctionDeclaration:
        return FunctionDeclaration(
            name=self.name,
            description=self.description,
            parameters=Schema(
                type=GeminiType.OBJECT,
                properties={
                    "profile": Schema(
                        type=GeminiType.OBJECT,
                        properties={
                            "username": Schema(type=GeminiType.STRING),
                            "email": Schema(
                                type=GeminiType.STRING,
                                format="email",  # 明示的にemail形式指定
                                description="有効なメールアドレス"
                            ),
                            "age": Schema(type=GeminiType.INTEGER, nullable=True)
                        },
                        required=["username", "email"]
                    )
                },
                required=["profile"]
            )
        )

    @override
    async def run_async(self, *, args: Dict[str, Any], tool_context: Optional[Any] = None) -> Any:
        profile_data = args.get("profile", {})
        # 実装ロジック
        return {"status": "success"}
```

### ToolContext（状態・Artifact・Memoryアクセス）

```python
from google.adk.tools import ToolContext

def increment_counter(tool_context: ToolContext) -> str:
    """
    セッション状態のカウンターを取得・インクリメントします。

    Args:
        tool_context: ToolContextオブジェクト（ADKが自動注入）
    """
    # 状態読み込み
    counter = tool_context.state.get("session_counter", 0)
    counter += 1

    # 状態更新
    tool_context.state["session_counter"] = counter

    # Artifact保存例
    # await tool_context.save_artifact("report.txt", Part(text=f"Count: {counter}"))

    # Memory検索例
    # memories = await tool_context.search_memory("過去のカウント")

    return f"カウンター: {counter}"

counter_tool = FunctionTool(func=increment_counter)
```

**ToolContextで利用可能な機能:**
- `tool_context.state`: 状態読み書き (app/user/session/tempスコープ)
- `tool_context.save_artifact(filename, artifact)`: ファイル保存
- `tool_context.load_artifact(filename)`: ファイル読み込み
- `tool_context.search_memory(query)`: 長期記憶検索
- `tool_context.invocation_id`: 現在のターンID
- `tool_context.function_call_id`: ツール呼び出しID

### Tool Callbacks

```python
from google.adk.tools import BaseTool

async def before_tool_cb(tool: BaseTool, args: dict, tool_context: ToolContext) -> Optional[dict]:
    print(f"ツール '{tool.name}' 実行前: {args}")

    # 認証チェック例
    if tool.name == "sensitive_tool" and not tool_context.state.get("user:is_admin"):
        return {"error": "権限がありません"}

    return None  # 通常実行

async def after_tool_cb(tool: BaseTool, args: dict, tool_context: ToolContext, tool_response: dict) -> Optional[dict]:
    print(f"ツール '{tool.name}' 実行後: {tool_response}")

    # 機密情報マスク例
    if "api_key" in tool_response:
        tool_response["api_key"] = "[REDACTED]"

    return tool_response

agent = Agent(
    name="secure_agent",
    model="gemini-2.0-flash",
    instruction="...",
    tools=[some_tool],
    before_tool_callback=before_tool_cb,
    after_tool_callback=after_tool_cb
)
```

---

## Pre-built Tools

### Internet Access Tools

#### GoogleSearchTool

```python
from google.adk.tools import google_search

search_agent = Agent(
    name="researcher",
    model="gemini-2.0-flash",
    instruction="最新情報を検索して回答してください。",
    tools=[google_search]
)
```

**特徴:**
- Gemini 2.0以降で統合検索（モデルが自動的に検索を実行）
- `grounding_metadata.web_search_queries`にクエリ情報
- `grounding_metadata`に出典URLが含まれる
- LLMが検索・結果解釈・引用を暗黙的に処理

**使用タイミング:** リアルタイム情報、最新ニュース、事実確認が必要な場合

#### VertexAiSearchTool

```python
from google.adk.tools import VertexAiSearchTool
import os

# 環境変数設定必須
# GOOGLE_GENAI_USE_VERTEXAI=1
# GOOGLE_CLOUD_PROJECT=your-project
# VERTEX_AI_SEARCH_DATA_STORE_ID=your-data-store-id

data_store_id = os.getenv("VERTEX_AI_SEARCH_DATA_STORE_ID")
vertex_search = VertexAiSearchTool(data_store_id=data_store_id)

agent = Agent(
    name="knowledge_base_agent",
    model="gemini-2.0-flash",
    instruction="社内データストアから情報を検索してください。",
    tools=[vertex_search]
)
```

**特徴:**
- 独自のVertex AI Searchデータストアから検索
- `grounding_metadata.retrieval_queries`に検索クエリ
- 企業固有のナレッジベース・ドキュメントに対応
- IAM権限とデータストア設定が必要

**使用タイミング:** 社内ドキュメント、プライベートナレッジベース、カスタムデータソースが必要な場合

#### load_web_page

```python
from google.adk.tools import FunctionTool
from google.adk.tools.load_web_page import load_web_page

# 依存: pip install requests beautifulsoup4 lxml
web_loader = FunctionTool(func=load_web_page)

agent = Agent(
    name="web_scraper",
    model="gemini-2.0-flash",
    instruction="指定されたURLの内容を取得して要約してください。",
    tools=[web_loader]
)
```

**特徴:**
- `requests` + `BeautifulSoup4`でHTMLからテキスト抽出
- 静的HTMLページに対応（JavaScript実行不可）
- 大量のテキストを返す可能性があるためトークン制限に注意

**組み合わせパターン:**
1. `google_search`でURL取得
2. `load_web_page`で詳細コンテンツ取得
3. LLMが内容を要約・分析

**制限:**
- JavaScript動的生成コンテンツは取得不可（Playwright等が必要）
- 長大なページはトークン制限超過の可能性

### LoadMemoryTool / PreloadMemoryTool

```python
from google.adk.tools import load_memory, preload_memory

# LoadMemoryTool: LLMが明示的にメモリ検索
reactive_agent = Agent(
    name="reactive_memory",
    model="gemini-2.0-flash",
    instruction="必要に応じてload_memoryツールで過去の情報を検索してください。",
    tools=[load_memory]
)

# PreloadMemoryTool: 自動的に関連メモリを注入
proactive_agent = Agent(
    name="proactive_memory",
    model="gemini-2.0-flash",
    instruction="過去の会話が自動的に提供されます。",
    tools=[preload_memory]
)
```

### LoadArtifactsTool

```python
from google.adk.tools import load_artifacts, FunctionTool
from google.adk.tools.tool_context import ToolContext
from google.genai.types import Part

async def create_report(content: str, tool_context: ToolContext) -> dict:
    """レポートを作成してArtifactとして保存"""
    filename = "report.txt"
    await tool_context.save_artifact(filename, Part(text=content))
    return {"status": "success", "filename": filename}

report_tool = FunctionTool(func=create_report)

agent = Agent(
    name="artifact_manager",
    model="gemini-2.0-flash",
    instruction="レポートを作成し、後で参照できます。",
    tools=[report_tool, load_artifacts]
)
```

### GetUserChoiceTool

```python
from google.adk.tools import get_user_choice

agent = Agent(
    name="choice_assistant",
    model="gemini-2.0-flash",
    instruction="ユーザーに選択肢を提示し、選択を待ちます。",
    tools=[get_user_choice]
)

# UI側で実装が必要:
# 1. get_user_choice呼び出しを検出
# 2. LLMが生成したoptionsを表示
# 3. ユーザー選択を取得
# 4. FunctionResponseとして返却
```

### ExitLoopTool

```python
from google.adk.tools import FunctionTool, exit_loop
from google.adk.agents import LoopAgent

exit_tool = FunctionTool(func=exit_loop)

loop_child = Agent(
    name="loop_worker",
    model="gemini-2.0-flash",
    instruction="タスク完了時はexit_loopを呼び出してください。",
    tools=[exit_tool]
)

# LoopAgent内で使用
# loop_agent = LoopAgent(
#     name="looper",
#     sub_agents=[loop_child],
#     max_iterations=10
# )
```

**動作原理:**
- `exit_loop`呼び出し時に`tool_context.actions.escalate = True`を設定
- `LoopAgent`がこのフラグを検出してループを終了
- マルチAgentシステムでのループ制御に使用

---

## Tool Performance（並列実行とパフォーマンス最適化）

### 非同期ツールによる並列実行

ADK v1.10.0以降、`async def`定義のToolは自動的に並列実行される。

```python
import aiohttp

async def fetch_weather(city: str) -> str:
    """
    非同期で天気情報を取得する。

    Args:
        city: 都市名
    """
    async with aiohttp.ClientSession() as session:
        async with session.get(f"https://api.weather.com/{city}") as resp:
            data = await resp.text()
            return data

weather_tool = FunctionTool(func=fetch_weather)
```

**重要:** LLMが複数ツールを同時呼び出すと判断した場合、ADKは自動的に並列実行。

### パフォーマンス最適化パターン

| シナリオ | テクニック | 実装例 |
|---------|----------|--------|
| **HTTP通信** | aiohttp + セッション管理 | `async with aiohttp.ClientSession() as session: ...` |
| **DB操作** | asyncpg等の非同期ドライバ | `async with asyncpg.create_pool(...) as pool: ...` |
| **長時間ループ** | `await asyncio.sleep(0)`でイールド | `for item in items: await asyncio.sleep(0)` |
| **CPU集約処理** | ThreadPoolExecutor + run_in_executor | `await loop.run_in_executor(pool, heavy_compute)` |
| **大量データ** | チャンク処理 + スレッドプール | ページネーション + 並列取得 |

### HTTP通信の最適化例

```python
import aiohttp
import asyncio
from typing import List

async def fetch_multiple_apis(endpoints: List[str]) -> dict:
    """
    複数のAPIエンドポイントから並列にデータを取得。

    Args:
        endpoints: APIエンドポイントのリスト
    """
    async with aiohttp.ClientSession() as session:
        tasks = [session.get(url) for url in endpoints]
        responses = await asyncio.gather(*tasks, return_exceptions=True)

        results = {}
        for url, response in zip(endpoints, responses):
            if isinstance(response, Exception):
                results[url] = {"error": str(response)}
            else:
                results[url] = await response.text()

        return results
```

### CPU集約処理の委譲

```python
from concurrent.futures import ThreadPoolExecutor
import asyncio

def heavy_computation(data: List[float]) -> float:
    """重いCPU処理（同期）"""
    result = sum(x ** 2 for x in data)
    return result

async def compute_async(data: List[float]) -> float:
    """
    CPU集約処理をスレッドプールに委譲。

    Args:
        data: 計算対象データ
    """
    loop = asyncio.get_event_loop()
    with ThreadPoolExecutor() as pool:
        result = await loop.run_in_executor(pool, heavy_computation, data)
        return result

compute_tool = FunctionTool(func=compute_async)
```

### プロンプトでの並列呼び出しガイド

LLMに並列実行を明示的に指示することでパフォーマンスを最大化。

```python
agent = Agent(
    name="parallel_agent",
    model="gemini-2.0-flash",
    instruction="""
あなたは効率的にツールを使用するアシスタントです。

重要:
- 複数の独立したツール呼び出しは並列に実行してください。
- 例: 複数の都市の天気を取得する場合、各都市のfetch_weatherを同時に呼び出す。
- 依存関係がある場合のみ順次実行してください。
""",
    tools=[weather_tool, api_tool, db_tool]
)
```

### 同期ツールの制約

**重要:** 同期ツール（`def`定義）が1つでも含まれると、そのToolはパイプライン全体をブロック。

```python
import time

# ❌ 悪い例: 同期ツールがブロッキング
def blocking_tool(param: str) -> str:
    time.sleep(5)  # 全体が5秒停止
    return "result"

# ✅ 良い例: 非同期で実装
async def non_blocking_tool(param: str) -> str:
    await asyncio.sleep(5)  # 他のツールは並列実行可能
    return "result"
```

**ベストプラクティス:**
- すべてのToolを`async def`で実装（ADK v1.10.0+）
- HTTP通信は`aiohttp`、DB操作は`asyncpg`等の非同期ライブラリ使用
- CPU集約処理は`run_in_executor`でスレッドプールに委譲
- 長時間ループでは`await asyncio.sleep(0)`を挿入
- プロンプトで並列実行を明示的に指示

---

## OpenAPI統合

### OpenAPIToolsetの基本

OpenAPI仕様から自動的にToolを生成する。

**動作原理:**
1. OpenAPI仕様（JSON/YAML）を解析
2. 各`operationId`に対して`RestApiTool`を自動生成
3. パラメータ・リクエストボディ・レスポンススキーマをLLM用に変換
4. 認証スキームを処理

```python
from google.adk.tools.openapi_tool import OpenAPIToolset

# OpenAPI仕様 (JSON/YAML)
spec_str = """
{
  "openapi": "3.0.0",
  "info": {"title": "Pet Store", "version": "1.0.0"},
  "servers": [{"url": "https://petstore.swagger.io/v2"}],
  "paths": {
    "/pet/findByStatus": {
      "get": {
        "summary": "ステータスでペットを検索",
        "operationId": "findPetsByStatus",
        "parameters": [{
          "name": "status",
          "in": "query",
          "required": true,
          "schema": {"type": "string", "enum": ["available", "pending", "sold"]}
        }],
        "responses": {"200": {"description": "成功"}}
      }
    }
  }
}
"""

toolset = OpenAPIToolset(
    spec_str=spec_str,
    spec_str_type="json"  # または "yaml"
)

agent = Agent(
    name="petstore_agent",
    model="gemini-2.0-flash",
    instruction="Pet Store APIを使ってペットを管理してください。",
    tools=[toolset]
)
```

**生成されるツール:**
- ツール名: `operationId`をsnake_caseに変換（例: `findPetsByStatus` → `find_pets_by_status`）
- 説明: OpenAPI仕様の`summary`と`description`
- パラメータ: `parameters`配列から自動抽出（path/query/header/body）

### 認証ハンドリング

#### APIキー認証

```python
from google.adk.auth import AuthCredential, AuthCredentialTypes
from fastapi.openapi.models import APIKey, APIKeyIn

# OpenAPI spec内のsecuritySchemes定義例:
# "securitySchemes": {
#   "ApiKeyAuth": {
#     "type": "apiKey",
#     "in": "header",
#     "name": "X-API-KEY"
#   }
# }

auth_scheme = APIKey(
    type="apiKey",
    name="X-API-KEY",
    **{"in": APIKeyIn.header}
)

auth_credential = AuthCredential(
    auth_type=AuthCredentialTypes.API_KEY,
    api_key="your-api-key-here"
)

toolset = OpenAPIToolset(
    spec_str=spec_str,
    spec_str_type="json",
    auth_scheme=auth_scheme,
    auth_credential=auth_credential
)
```

#### Bearer Token (Spotify例)

```python
from google.adk.tools.openapi_tool.auth.auth_helpers import token_to_scheme_credential

# Spotify Access Token取得 (Client Credentials Flow)
# curl -X POST -H "Authorization: Basic <BASE64>" \
#   -d grant_type=client_credentials https://accounts.spotify.com/api/token

bearer_token = "Bearer YOUR_ACCESS_TOKEN"

auth_scheme, auth_credential = token_to_scheme_credential(
    token_type="apikey",
    location="header",
    name="Authorization",
    credential_value=bearer_token
)

spotify_toolset = OpenAPIToolset(
    spec_str=spotify_spec,
    spec_str_type="yaml",
    auth_scheme=auth_scheme,
    auth_credential=auth_credential
)
```

### APIHubToolset

Google API Hubからスペックを取得してToolを生成する。

**動作フロー:**
1. API Hubサービスに認証（Application Default Credentials等）
2. 指定されたAPI リソースを取得
3. 最新バージョン・スペックを解決
4. OpenAPI仕様をダウンロード
5. `OpenAPIToolset`でツール生成

```python
from google.adk.tools.apihub_tool import APIHubToolset
import os

# 環境変数設定:
# GOOGLE_CLOUD_PROJECT=your-project
# MY_APIHUB_API_RESOURCE_NAME=projects/.../locations/.../apis/...

resource_name = os.getenv("MY_APIHUB_API_RESOURCE_NAME")

# カスタムフィルター（ADKパーサーが対応できないツールを除外）
def is_valid_tool(tool, ctx=None) -> bool:
    operation = tool._operation_parser._operation
    if not operation.requestBody or not operation.requestBody.content:
        return True

    for media_type in operation.requestBody.content.values():
        if media_type.schema_ and media_type.schema_.type != 'object':
            return False  # non-object requestBodyは除外
    return True

apihub_toolset = APIHubToolset(
    apihub_resource_name=resource_name,
    tool_filter=is_valid_tool,
    auth_scheme=...,      # 認証スキーム
    auth_credential=...   # 認証クレデンシャル
)

agent = Agent(
    name="apihub_agent",
    model="gemini-2.0-flash",
    instruction="社内API Hubに登録されたAPIを使用してください。",
    tools=[apihub_toolset]
)
```

**必要な権限:**
- API Hubへのアクセス権限（IAM）
- 対象APIのスペック読み取り権限
- 認証情報（gcloud auth application-default login等）

**リソース名形式:**
- `projects/{project}/locations/{location}/apis/{api}`
- `projects/{project}/locations/{location}/apis/{api}/versions/{version}`
- `projects/{project}/locations/{location}/apis/{api}/versions/{version}/specs/{spec}`

**トラブルシューティング:**
- `tool_filter`でADKパーサーが対応できないスキーマを除外
- `override_base_url`で相対URLの問題を修正（カスタムサブクラス化が必要）

---

## MCP統合

### MCPToolset

Model Context Protocol (MCP) サーバーと統合してToolを提供する。

```python
from google.adk.tools.mcp_toolset import MCPToolset

# MCP (Model Context Protocol) サーバー統合
mcp_toolset = MCPToolset(
    server_url="http://localhost:8080/mcp"
)

agent = Agent(
    name="mcp_agent",
    model="gemini-2.0-flash",
    instruction="MCPツールを使って外部システムと連携してください。",
    tools=[mcp_toolset]
)
```

**動作原理:**
1. MCPサーバーに接続
2. サーバーが提供するツール・リソース・プロンプトを取得
3. ADK Toolに変換してAgentに提供
4. Tool呼び出し時にMCPサーバーにリクエスト送信

**設定オプション:**
```python
mcp_toolset = MCPToolset(
    server_url="http://localhost:8080/mcp",
    timeout=30,                    # タイムアウト（秒）
    headers={"Authorization": ...},  # カスタムヘッダー
    tool_filter=lambda tool: ...   # ツールフィルター関数
)
```

**使用タイミング:**
- 外部システム（データベース、API、ファイルシステム）との統合
- 既存MCPサーバーの再利用
- Claude Desktop等の他MCPクライアントとの互換性確保

### ApplicationIntegrationToolset

Google Cloud Application Integration と連携してワークフローを実行する。

```python
from google.adk.tools.application_integration_toolset import ApplicationIntegrationToolset

# Google Cloud Application Integration統合
app_integration = ApplicationIntegrationToolset(
    project_id="your-project",
    location="us-central1",
    integration_name="your-integration"
)

agent = Agent(
    name="integration_agent",
    model="gemini-2.0-flash",
    instruction="Application Integrationを使って企業システムと連携してください。",
    tools=[app_integration]
)
```

**特徴:**
- Google Cloud上のエンタープライズ統合ワークフローを実行
- SaaS・オンプレミスシステムとの接続
- イベント駆動型ワークフロー実行

**必要な設定:**
- GCP認証（Application Default Credentials）
- IAM権限（Integration Invoker等）
- Integration名とロケーション

### LangGraphAgent統合（フレームワーク間ブリッジ）

LangGraphのグラフをADK Agentとして実行する。

```python
from google.adk.agents.langgraph_agent import LangGraphAgent

# LangGraphのグラフをADK Agentとして実行
langgraph_agent = LangGraphAgent(
    name="langgraph_bridge",
    graph=your_compiled_langgraph  # LangGraph CompiledGraph
)

# ADKのマルチAgentシステムで使用可能
parent_agent = Agent(
    name="orchestrator",
    model="gemini-2.0-flash",
    instruction="LangGraphエージェントと連携してください。",
    tools=[AgentTool(agent=langgraph_agent)]
)
```

**使用タイミング:**
- 既存のLangGraphワークフローをADKで再利用
- LangGraphとADKの混合システム構築
- LangGraphの複雑なステートマシンをサブAgentとして利用

**注意事項:**
- LangGraphとADKのイベントモデルの差異に注意
- ステート管理は各フレームワークで独立

---

## ベストプラクティス

### Agent設計

1. **明確なinstruction**: LLMがツール使用タイミングを判断できる指示
2. **descriptionを詳細に**: マルチAgent時の選択精度向上
3. **Callbackで横断的関心事**: ログ、認証、検証

### Tool設計

1. **明確なdocstring**: FunctionToolの記述がそのままLLMに渡される
2. **型ヒント必須**: `str`, `int`, `float`, `Literal`, Pydantic Model
3. **エラーハンドリング**: ツール内で例外を処理し、明確なエラーメッセージを返す

### OpenAPI統合

1. **operationIdを明確に**: ツール名として使用される（snake_case変換）
2. **summary/descriptionを詳細に**: LLMがツール選択に使用
3. **securitySchemesを定義**: 認証情報を宣言的に管理

---

## トラブルシューティング

### ツールが正しく呼び出されない

1. **Trace機能で確認**: Dev UIのTrace viewでLLMに送られたFunctionDeclarationを確認
2. **descriptionを改善**: LLMが理解しやすい説明に変更
3. **パラメータ簡素化**: 複雑なスキーマを分割

### 認証エラー

1. **環境変数確認**: `GOOGLE_API_KEY`, `GOOGLE_CLOUD_PROJECT`等
2. **IAM権限確認**: Vertex AI、Secret Manager等のアクセス権
3. **トークン期限確認**: OAuth2トークンの有効期限

### Pydanticモデル問題

1. **EmailStr等の特殊型**: カスタムTool実装で明示的なスキーマ定義
2. **バリデーションエラー**: `try-except`でPydanticValidationErrorをキャッチ

---

## Action Confirmations

### require_confirmationによる実行確認

危険性のある操作（削除、課金アクション等）に対して、Tool実行前にユーザー確認を要求できます。

```python
from google.adk.tools import FunctionTool

def delete_record(record_id: str) -> str:
    """
    レコードを削除する。

    Args:
        record_id: 削除対象のレコードID
    """
    # 削除処理実装
    print(f"Record {record_id} を削除しました")
    return f"Record {record_id} deleted"

delete_tool = FunctionTool(
    func=delete_record,
    require_confirmation=True,  # 実行前にユーザー確認を要求
)
```

**動作:**
1. LLMがToolの実行を決定
2. ADKがユーザーに確認プロンプトを表示
3. ユーザーが承認した場合のみ実行

### 動的確認ロジック

条件に基づいて確認要求を切り替えることも可能です。

```python
def conditional_action(amount: float, tool_context: ToolContext) -> dict:
    """
    金額に応じて動的に確認を要求する。

    Args:
        amount: 処理金額
        tool_context: ToolContext（ADKが自動注入）
    """
    # 閾値を超える場合のみ確認要求
    threshold = 1000.0

    if amount > threshold:
        # 高額な操作: 確認要求
        # （実装詳細はADK APIドキュメント参照）
        return {
            "status": "pending_confirmation",
            "message": f"{amount}円の処理を実行しますか？"
        }

    # 通常の操作: 確認なしで実行
    result = process_payment(amount)
    return {"status": "success", "result": result}
```

### AgentToolでの確認パターン

AgentToolを使用する場合も、サブAgentの重要なアクションに確認を追加できます。

```python
from google.adk.agents import Agent, AgentTool

# 確認を要求するサブAgent
sub_agent = Agent(
    name="risky_agent",
    model="gemini-2.0-flash",
    instruction="削除操作を実行します。",
    tools=[delete_tool]  # require_confirmation=Trueのツール
)

agent_tool = AgentTool(
    agent=sub_agent,
    require_confirmation=True  # AgentTool全体に確認を要求
)
```

### 構造化された確認データ

確認プロンプトに追加情報を含めることで、ユーザーが適切に判断できるようにします。

```python
from datetime import datetime

def structured_confirmation(
    action: str,
    target: str,
    tool_context: ToolContext
) -> dict:
    """
    構造化された確認データを返す。

    Args:
        action: 実行するアクション
        target: 対象リソース
        tool_context: ToolContext
    """
    confirmation_data = {
        "action": action,
        "target": target,
        "timestamp": datetime.now().isoformat(),
        "user_id": tool_context.state.get("user:user_id"),
        "confirmation_required": True,
        "details": {
            "risk_level": "high",
            "reversible": False
        }
    }

    # この情報がユーザーに提示される
    return confirmation_data
```

**ベストプラクティス:**
- 破壊的操作（削除、上書き）には常に確認を要求
- 課金が発生する操作には明示的な確認
- 閾値ベースの動的確認で柔軟性を確保
- 確認メッセージにはアクション内容・対象・影響範囲を明記

---

## Tool Performance

### 非同期ツールによる並列実行

ADK v1.10.0以降、`async def`で定義されたToolは自動的に並列実行されます。

```python
import aiohttp

async def fetch_weather(city: str) -> str:
    """
    非同期で天気情報を取得する。

    Args:
        city: 都市名
    """
    async with aiohttp.ClientSession() as session:
        async with session.get(f"https://api.weather.com/{city}") as resp:
            data = await resp.text()
            return data

weather_tool = FunctionTool(func=fetch_weather)
```

**重要:** LLMが複数のToolを同時に呼び出すと判断した場合、ADKは自動的に並列実行します。

### パフォーマンス最適化テクニック

| シナリオ | テクニック | 実装例 |
|---------|----------|--------|
| **HTTP通信** | aiohttp + セッション管理 | `async with aiohttp.ClientSession() as session: ...` |
| **DB操作** | asyncpg等の非同期ドライバ | `async with asyncpg.create_pool(...) as pool: ...` |
| **長時間ループ** | await asyncio.sleep(0)でイールド | `for item in items: await asyncio.sleep(0)` |
| **CPU集約処理** | ThreadPoolExecutor + run_in_executor | `await loop.run_in_executor(pool, heavy_compute)` |
| **大量データ** | チャンク処理 + スレッドプール | ページネーション + 並列取得 |

### HTTP通信の最適化例

```python
import aiohttp
import asyncio
from typing import List

async def fetch_multiple_apis(endpoints: List[str]) -> dict:
    """
    複数のAPIエンドポイントから並列にデータを取得。

    Args:
        endpoints: APIエンドポイントのリスト
    """
    async with aiohttp.ClientSession() as session:
        tasks = []
        for url in endpoints:
            tasks.append(session.get(url))

        responses = await asyncio.gather(*tasks, return_exceptions=True)

        results = {}
        for url, response in zip(endpoints, responses):
            if isinstance(response, Exception):
                results[url] = {"error": str(response)}
            else:
                results[url] = await response.text()

        return results
```

### DB操作の最適化例

```python
import asyncpg
from typing import List

async def query_users(user_ids: List[int], tool_context: ToolContext) -> List[dict]:
    """
    複数ユーザーのデータを非同期で取得。

    Args:
        user_ids: ユーザーIDリスト
        tool_context: ToolContext
    """
    pool = await asyncpg.create_pool(
        host="localhost",
        user="app",
        database="mydb"
    )

    try:
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                "SELECT * FROM users WHERE id = ANY($1::int[])",
                user_ids
            )
            return [dict(row) for row in rows]
    finally:
        await pool.close()
```

### CPU集約処理の委譲

```python
from concurrent.futures import ThreadPoolExecutor
import asyncio
from typing import List

def heavy_computation(data: List[float]) -> float:
    """重いCPU処理（同期）"""
    result = 0
    for x in data:
        result += x ** 2
    return result

async def compute_async(data: List[float]) -> float:
    """
    CPU集約処理をスレッドプールに委譲。

    Args:
        data: 計算対象データ
    """
    loop = asyncio.get_event_loop()
    with ThreadPoolExecutor() as pool:
        result = await loop.run_in_executor(pool, heavy_computation, data)
        return result

compute_tool = FunctionTool(func=compute_async)
```

### 長時間ループのイールド

```python
from typing import List

async def process_large_dataset(items: List[dict]) -> dict:
    """
    大量データを処理しつつイベントループに制御を返す。

    Args:
        items: 処理対象アイテム
    """
    results = []
    for item in items:
        processed = process_item(item)
        results.append(processed)

        # イベントループに制御を返す（他のタスクが実行可能に）
        await asyncio.sleep(0)

    return {"processed_count": len(results), "results": results}
```

### プロンプトでの並列呼び出しガイド

LLMに並列実行を明示的に指示することで、パフォーマンスを最大化できます。

```python
agent = Agent(
    name="parallel_agent",
    model="gemini-2.0-flash",
    instruction="""
あなたは効率的にツールを使用するアシスタントです。

重要:
- 複数の独立したツール呼び出しは並列に実行してください。
- 例: 複数の都市の天気を取得する場合、各都市のfetch_weatherを同時に呼び出す。
- 依存関係がある場合のみ順次実行してください。
""",
    tools=[weather_tool, api_tool, db_tool]
)
```

### 同期ツールの制約

**重要:** 同期ツール（`def`で定義）が1つでも含まれていると、そのToolはパイプライン全体をブロックします。

```python
import time

# ❌ 悪い例: 同期ツールがブロッキング
def blocking_tool(param: str) -> str:
    time.sleep(5)  # 全体が5秒停止
    return "result"

# ✅ 良い例: 非同期で実装
async def non_blocking_tool(param: str) -> str:
    await asyncio.sleep(5)  # 他のツールは並列実行可能
    return "result"
```

**ベストプラクティス:**
- すべてのToolを`async def`で実装（ADK v1.10.0+）
- HTTP通信は`aiohttp`、DB操作は`asyncpg`等の非同期ライブラリ使用
- CPU集約処理は`run_in_executor`でスレッドプールに委譲
- 長時間ループでは`await asyncio.sleep(0)`を挿入
- プロンプトで並列実行を明示的に指示
