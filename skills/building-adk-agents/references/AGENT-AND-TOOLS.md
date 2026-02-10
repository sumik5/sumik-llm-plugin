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

**注意:**
- InstructionProviderは`ReadonlyContext`を受け取り`str`を返す関数
- `context.state`から状態を読み取り可能
- 自動状態注入 (`{変数名}`) はInstructionProvider使用時は**無効**

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
        ]
    )
)
```

**重要:**
- `system_instruction`は設定しない（`LlmAgent.instruction`を使用）
- `tools`は設定しない（`LlmAgent.tools`を使用）
- `thinking_config`は設定しない（`LlmAgent.planner`を使用）

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

### Google Search

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
- Gemini 2.0以降で統合検索
- `grounding_metadata`にクエリと出典情報

### Vertex AI Search

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

### Web Page Loading

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

---

## OpenAPI統合

### OpenAPIToolsetの基本

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
    tool_filter=is_valid_tool
)

agent = Agent(
    name="apihub_agent",
    model="gemini-2.0-flash",
    instruction="社内API Hubに登録されたAPIを使用してください。",
    tools=[apihub_toolset]
)
```

---

## MCP統合

### MCPToolset

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

### ApplicationIntegrationToolset

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

### LangGraphAgent統合

```python
# ADKとLangGraphのブリッジ
from google.adk.agents.langgraph_agent import LangGraphAgent

# LangGraphのグラフをADK Agentとして実行
langgraph_agent = LangGraphAgent(
    name="langgraph_bridge",
    graph=your_compiled_langgraph  # LangGraph CompiledGraph
)
```

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
