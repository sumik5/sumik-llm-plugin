# Function Calling リファレンス

## 概要

Function Callingはプロキシ経由でリアルタイムに実行される。LLMがtext generatorからdynamic problem-solving engineへ変貌する仕組み。

**Function Callingなし**: 「リアルタイム情報は提供できません。」
**Function Callingあり**: ツールを呼び出してリアルタイムデータを取得し、応答に組み込む。

---

## Function Callingの完全ループ

```
ユーザー: 「ロンドンの今の天気は？」
    ↓ 1. 意図認識
モデル: リアルタイムデータが必要と判断
    ↓ 2. ツール選択
モデル: 利用可能ツールリストから get_weather を選択
    ↓ 3. パラメータ抽出
モデル: city = "London" を特定
    ↓ 4. tool_call エミット（音声応答を一時停止）
{ "tool_call": { "name": "get_weather", "args": { "city": "London" } } }
    ↓ 5. プロキシが検出・実行
get_weather("London") → {"temperature": 15, "description": "cloudy"}
    ↓ 6. LiveClientToolResponse 返送
{ "tool_response": { "result": {...} } }
    ↓ 7. 合成
モデル: リアルタイムデータを組み込んで音声応答生成
ユーザー: 「ロンドンの現在の天気は15度で曇りです。」
```

---

## function_declaration の定義

### プロキシでのツール登録

```python
# proxy.pyのsession configに追加
TOOL_DECLARATIONS = [
    {
        "name": "get_weather",
        "description": "Get current weather information for a specified city. Use this when the user asks about weather conditions.",
        "parameters": {
            "type": "object",
            "properties": {
                "city": {
                    "type": "string",
                    "description": "The name of the city to get weather for, e.g. 'Tokyo', 'London'"
                }
            },
            "required": ["city"]
        }
    }
]

# セッション設定
config = {
    "tools": [{ "function_declarations": TOOL_DECLARATIONS }],
    "system_instruction": system_instruction,
    ...
}
```

**description の重要性**: モデルはdescriptionを読んでツールをいつ使うか判断する。曖昧なdescriptionはツール選択ミスを招く。

---

## ツール実装（tool_handler.py）

### ローカルアーキテクチャの原則

開発・プロトタイプ段階ではツールをプロキシサーバー内に実装するのが最適。

```python
# backend/tool_handler.py
import os
import requests

def get_weather(city: str) -> dict:
    """
    OpenWeatherMap APIから現在の天気を取得。
    Returns: {"city": str, "temperature": float, "description": str}
    """
    api_key = os.environ.get("OPENWEATHER_API_KEY")
    url = f"https://api.openweathermap.org/data/2.5/weather?q={city}&appid={api_key}&units=metric"

    response = requests.get(url)
    response.raise_for_status()
    data = response.json()

    return {
        "city": data["name"],
        "temperature": data["main"]["temp"],
        "description": data["weather"][0]["description"]
    }

# ツール名 → 関数のマッピング（動的ルーティング向け）
TOOL_MAP = {
    "get_weather": get_weather,
}
```

---

## プロキシでのtool_call処理

### forward_gemini_to_client の更新

```python
from tool_handler import TOOL_MAP
from google.genai.types import LiveClientToolResponse, FunctionResponse

async def forward_gemini_to_client(client_ws, gemini_session):
    while True:
        async for response in gemini_session.receive():

            # tool_call の検出
            if response.tool_call:
                for function_call in response.tool_call.function_calls:
                    tool_name = function_call.name
                    tool_args = dict(function_call.args)
                    call_id = function_call.id

                    print(f"Tool call: {tool_name}({tool_args})")

                    # ツールを実行
                    if tool_name in TOOL_MAP:
                        try:
                            result = TOOL_MAP[tool_name](**tool_args)
                        except Exception as e:
                            result = {"error": str(e)}
                    else:
                        result = {"error": f"Unknown tool: {tool_name}"}

                    # LiveClientToolResponse でGeminiに結果を返送
                    tool_response = LiveClientToolResponse(
                        function_responses=[
                            FunctionResponse(
                                id=call_id,
                                name=tool_name,
                                response={"result": result}
                            )
                        ]
                    )
                    await gemini_session.send_tool_response(tool_response)

            else:
                # 通常のレスポンス（音声・テキスト）をブラウザへ転送
                if hasattr(response, 'model_dump'):
                    json_message = json.dumps(response.model_dump(), cls=BytesJSONEncoder)
                    await client_ws.send(json_message)
```

---

## System Instructionsとの統合

ツールの存在をモデルに知らせるだけでなく、**いつ使うかのルール**もSystem Instructionsで明記する。

```
# system-instructions.txt
You are a helpful and friendly assistant.

## Tool Usage Rules
- When the user asks about weather, temperature, or climate in any location,
  you MUST use the get_weather tool. Do not answer from internal knowledge.
- Always report temperature in both Celsius and Fahrenheit.
```

ツール定義（what）+ System Instructions（when/how）の組み合わせで信頼性の高いツール呼び出しを実現。

---

## ツール設計のベストプラクティス

### 明確なdescription

```python
# ❌ 不明確
"description": "Weather tool"

# ✅ 明確（モデルが使用タイミングを正確に判断できる）
"description": "Get real-time weather information for any city. Use when user asks about current weather, temperature, or atmospheric conditions."
```

### 適切なパラメータ設計

```python
# ❌ 曖昧
"parameters": {
    "type": "object",
    "properties": {
        "input": { "type": "string" }
    }
}

# ✅ 明確（モデルがパラメータを正確に抽出できる）
"parameters": {
    "type": "object",
    "properties": {
        "city": {
            "type": "string",
            "description": "City name in English, e.g. 'Tokyo', 'New York', 'London'"
        }
    },
    "required": ["city"]
}
```

### エラーハンドリング

```python
try:
    result = TOOL_MAP[tool_name](**tool_args)
except requests.HTTPError as e:
    result = {"error": f"API error: {e.response.status_code}"}
except KeyError as e:
    result = {"error": f"Missing required parameter: {e}"}
except Exception as e:
    result = {"error": f"Unexpected error: {str(e)}"}

# エラーもFunctionResponseとして返す
# モデルがエラーを踏まえた応答を生成できる
```

---

## ローカル vs 本番アーキテクチャ

| ステージ | ツール実装場所 | メリット | デメリット |
|---------|-------------|---------|----------|
| **開発・プロトタイプ** | proxy.py内（tool_handler.py） | シンプル・デバッグ容易 | スケールしない |
| **本番** | Cloud Functions / Lambda 等 | スケーラブル・独立デプロイ | 複雑さ増加 |

開発段階ではローカルアーキテクチャに徹し、ツール呼び出しループを完全に理解してから本番アーキテクチャへ移行するのが推奨。

---

## デバッグ方法

```python
# proxy.pyにログを追加
if response.tool_call:
    print(f"[TOOL CALL] {response.tool_call}")
    # ターミナルで確認: Tool call: get_weather({'city': 'London'})

# ブラウザのDevToolsコンソールでも確認可能
# tool_callとtool_responseのJSONがコンソールに表示される
```

**テスト方法**: 「ロンドンの天気は？」「東京の今の気温は？」など明確な天気質問で確認。バックエンドターミナルに `[TOOL CALL] get_weather({'city': 'London'})` が表示されれば成功。
