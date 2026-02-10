# コード実行とLLMモデル統合

ADK Agentは、LLMが生成したPythonコードを実行し、さまざまなLLMプロバイダーと統合することができます。

---

## コード実行

### BaseCodeExecutor概要

`BaseCodeExecutor`は、LLMが生成したコードを実行するための抽象基底クラスです。

**主要な責務:**
- `execute_code(invocation_context, code_execution_input) -> CodeExecutionResult`: コード実行の中核メソッド
- **環境定義**: コードが実行される環境(ローカル、Docker、クラウド等)を決定
- **ステートフル性** (`stateful: bool`): 実行間で変数・状態を保持するかどうか
- **ファイル処理** (`optimize_data_file: bool`): データファイルの自動管理
- **エラー処理とリトライ** (`error_retry_attempts: int`): 失敗時の再試行回数
- **デリミタ設定**:
  - `code_block_delimiters`: LLMがコードブロックを出力する際のフォーマット(例: `python\ncode\n`)
  - `execution_result_delimiters`: ADKがコード実行結果をLLMにフィードバックする際のフォーマット

---

### 1. BuiltInCodeExecutor（モデルネイティブ実行）

LLMが内部サンドボックスでコード実行機能を持つ場合に使用します。

**特徴:**
- モデル自身がコード生成・実行・結果解釈を行う
- ADKは実行環境を用意する必要がない
- 高いセキュリティ(モデル管理のサンドボックス)

**動作フロー:**
1. `BuiltInCodeExecutor`が`LlmRequest`を修正してモデルのコードインタープリターを有効化
2. LLMがコードを生成(`executable_code` Part)
3. モデルが内部で実行
4. LLMが実行結果を含む`code_execution_result` Partを生成
5. ADKがこれらのPartを含む`Event`をyield

**コード例:**
```python
from google.adk.agents import Agent
from google.adk.code_executors import BuiltInCodeExecutor
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part

# 環境変数を読み込み

code_savvy_agent_builtin = Agent(
    name="code_savvy_agent_builtin",
    model="gemini-2.0-flash",  # BuiltInコード実行をサポートするモデル
    instruction="あなたは計算やデータ分析のためにPythonコードを書いて実行できるアシスタントです。",
    code_executor=BuiltInCodeExecutor()
)

runner = InMemoryRunner(agent=code_savvy_agent_builtin, app_name="BuiltInCodeApp")
session_id = "s_builtin_code_test"
user_id = "builtin_user"
# セッション作成

prompts = [
    "7の階乗は？",
    "12345の平方根を計算してください。",
    "最初の10個の素数を生成してください。"
]

async def main():
    for prompt_text in prompts:
        print(f"\nYOU: {prompt_text}")
        user_message = Content(parts=[Part(text=prompt_text)], role="user")
        print("ASSISTANT: ", end="", flush=True)
        async for event in runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if part.text:
                        print(part.text, end="", flush=True)
                    elif part.executable_code:
                        print(f"\n  CODE BLOCK:\n{part.executable_code.code.strip()}\n  END CODE BLOCK", end="")
                    elif part.code_execution_result:
                        print(f"\n  EXECUTION RESULT: {part.code_execution_result.outcome}\n  OUTPUT:\n{part.code_execution_result.output.strip()}\n  END EXECUTION RESULT", end="")
        print()

import asyncio
asyncio.run(main())
```

**推奨される使用場面:**
- 使用するLLMがネイティブにコード実行をサポートしている場合
- 最も簡単で安全なコード実行方法

---

### 2. UnsafeLocalCodeExecutor（開発用・信頼された環境のみ）

Pythonの`exec()`を使用して、ADKアプリケーションと同じプロセス内でコードを実行します。

**⚠️ 重大なセキュリティリスク:**
- LLM生成コードが直接ローカル環境で実行される
- ファイルアクセス、ネットワーク呼び出し、リソース消費など、すべて可能
- **本番環境や信頼できないモデル/ユーザーとの使用は厳禁**

**動作フロー:**
1. LLMがコードを生成(デリミタで囲まれた形式)
2. ADKのLLM Flow(`_code_execution.response_processor`)がコードを抽出
3. `CodeExecutionInput`を作成
4. `UnsafeLocalCodeExecutor.execute_code()`を呼び出し
5. `exec(code, globals_dict, locals_dict)`で実行(標準出力キャプチャ)
6. `CodeExecutionResult`(stdout/stderr)を返却
7. フォーマットされた結果をLLMにフィードバック

**コード例:**
```python
from google.adk.agents import Agent
from google.adk.code_executors import UnsafeLocalCodeExecutor
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part

# 環境変数を読み込み

print("⚠️ WARNING: UnsafeLocalCodeExecutorを使用します。本番環境では推奨されません。⚠️")

unsafe_code_agent = Agent(
    name="unsafe_code_agent",
    model="gemini-2.0-flash",
    instruction="問題を解決するためにPythonコードを書けるアシスタントです。標準Python以外の外部ライブラリは使用しないでください。",
    code_executor=UnsafeLocalCodeExecutor()
)

runner = InMemoryRunner(agent=unsafe_code_agent, app_name="UnsafeCodeApp")
session_id = "s_unsafe_code_test"
user_id = "unsafe_user"
# セッション作成

prompts = [
    "変数xを10、yを20と定義して、その合計を出力してください。",
    "2の10乗はいくつですか？",
]

async def main():
    for prompt_text in prompts:
        print(f"\nYOU: {prompt_text}")
        user_message = Content(parts=[Part(text=prompt_text)], role="user")
        print("ASSISTANT (via UnsafeLocalCodeExecutor): ", end="", flush=True)
        async for event in runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if part.text:
                        print(part.text, end="", flush=True)
        print()

import asyncio
asyncio.run(main())
```

**使用すべき場面:**
- 分離された開発環境でのみ
- 信頼されたLLMと信頼されたユーザーとの実験

---

### 3. ContainerCodeExecutor（Docker分離実行）

Dockerコンテナ内でコードを実行し、ホストシステムから強力に分離します。

**前提条件:**
- Dockerがインストールされ、実行中
- `docker` Pythonライブラリ(`pip install docker`)

**動作フロー:**
1. LLMがコードを生成
2. ADKがコードを抽出し`CodeExecutionInput`を作成
3. `ContainerCodeExecutor.execute_code()`を呼び出し
4. Dockerコンテナを起動(指定されたイメージを使用)
5. `docker exec`でコンテナ内でPythonコードを実行
6. stdoutとstderrをキャプチャして返却
7. 結果をLLMにフィードバック

**コード例:**
```python
from google.adk.agents import Agent
from google.adk.code_executors import ContainerCodeExecutor
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import os

# 環境変数を読み込み

# オプション1: 既存のPythonイメージを使用
# container_executor_instance = ContainerCodeExecutor(image="python:3.10-slim")

# オプション2: カスタムDockerfileからビルド
dockerfile_dir = "my_python_env"
os.makedirs(dockerfile_dir, exist_ok=True)
with open(os.path.join(dockerfile_dir, "Dockerfile"), "w") as df:
    df.write("FROM python:3.10-slim\n")
    df.write("RUN pip install numpy pandas\n")
    df.write("WORKDIR /app\n")
    df.write("COPY . /app\n")

print("ContainerCodeExecutorを初期化中(イメージのビルド/プルに時間がかかる場合があります)...")
container_executor_instance = ContainerCodeExecutor(
    docker_path=dockerfile_dir
)
print("ContainerCodeExecutor初期化完了。")

container_agent = Agent(
    name="container_code_agent",
    model="gemini-2.0-flash",
    instruction="Pythonコードを書くアシスタントです。コードはサンドボックス化されたDockerコンテナで実行されます。numpyとpandasが使用できます。",
    code_executor=container_executor_instance
)

runner = InMemoryRunner(agent=container_agent, app_name="ContainerCodeApp")
session_id = "s_container_code_test"
user_id = "container_user"
# セッション作成

prompts = [
    "numpyをインポートして3x3のゼロ行列を作成し、出力してください。",
    "pandasを使用して'Name'と'Age'の2列を持つDataFrameを作成し、1行データを追加して出力してください。"
]

async def main():
    for prompt_text in prompts:
        print(f"\nYOU: {prompt_text}")
        user_message = Content(parts=[Part(text=prompt_text)], role="user")
        print("ASSISTANT (via ContainerCodeExecutor): ", end="", flush=True)
        async for event in runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if part.text:
                        print(part.text, end="", flush=True)
        print()

import asyncio
asyncio.run(main())
```

**推奨される使用場面:**
- LLM生成コードを実行する大半のユースケース
- `UnsafeLocalCodeExecutor`よりはるかに高いセキュリティ
- 最小限のDockerイメージを定義し、必要なライブラリのみを含める

**注意点:**
- Dockerオーバーヘッド(イメージプル/ビルド、コンテナ起動時間)
- ホストマシンにDockerが必要

---

### 4. VertexAiCodeExecutor（クラウドマネージドコード実行）

Google Cloudの**Vertex AI Code Interpreter Extension**を使用したフルマネージド・スケーラブルな実行環境です。

**前提条件:**
- Google CloudプロジェクトでVertex AI APIが有効
- 認証設定済み(`gcloud auth application-default login`またはサービスアカウント)
- `google-cloud-aiplatform` ライブラリ(`pip install "google-cloud-aiplatform>=1.47.0"`)

**特徴:**
- **マネージド環境**: DockerやPython環境の管理不要
- **セキュリティ**: Google管理のサンドボックスで実行
- **事前インストールライブラリ**: pandas、numpy、matplotlib、scipyなど
- **ファイルI/O**: プロット、データファイルの生成と返却が可能(ADKがArtifactとして処理)
- **ステートフル実行**: デフォルトでステートフル(同一セッション内で変数とインポートを保持)

**動作フロー:**
1. LLMがコードを生成
2. ADKがコードを抽出し`CodeExecutionInput`を作成
3. `VertexAiCodeExecutor.execute_code()`を呼び出し
4. Vertex AI Code Interpreterサービスにリクエスト送信
5. Vertex AIがクラウド環境でコード実行
6. `CodeExecutionResult`(stdout、stderr、出力ファイル)を返却
7. 出力ファイルはADKがArtifactとして保存
8. 結果をLLMにフィードバック

**コード例:**
```python
from google.adk.agents import Agent
from google.adk.code_executors import VertexAiCodeExecutor
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import os

# 環境変数を読み込み

if not os.getenv("GOOGLE_CLOUD_PROJECT"):
    print("Error: GOOGLE_CLOUD_PROJECT環境変数が必要です。")
    exit(1)

print("VertexAiCodeExecutorを初期化中...")
vertex_executor = VertexAiCodeExecutor()
print(f"VertexAiCodeExecutor初期化完了。使用中のExtension: {vertex_executor._code_interpreter_extension.gca_resource.name}")

vertex_agent = Agent(
    name="vertex_code_agent",
    model="gemini-2.0-flash",
    instruction="高度なAIアシスタントです。計算やデータタスクのためにPythonコードを書いてください。安全なVertex AI環境で実行されます。pandas、numpy、matplotlibなどが利用可能です。",
    code_executor=vertex_executor
)

runner = InMemoryRunner(agent=vertex_agent, app_name="VertexCodeApp")
session_id = "s_vertex"
user_id = "vertex_user"
# セッション作成

prompts = [
    "matplotlibを使用してシンプルなサイン波をプロットし、'sine_wave.png'として保存してください。プロットについて説明してください。",
    "'City'と'Population'列を持つpandas DataFrameを3都市分作成し、平均人口を出力してください。"
]

async def main():
    for prompt_text in prompts:
        print(f"\nYOU: {prompt_text}")
        user_message = Content(parts=[Part(text=prompt_text)], role="user")
        print("ASSISTANT (via VertexAiCodeExecutor): ", end="", flush=True)
        async for event in runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if part.text:
                        print(part.text, end="", flush=True)
        print()
        # Artifactを確認
        if runner.artifact_service:
            artifacts = await runner.artifact_service.list_artifact_keys(
                app_name="VertexCodeApp", user_id="vertex_user", session_id="s_vertex"
            )
            if artifacts:
                print(f"  (作成されたArtifacts: {artifacts})")

import asyncio
asyncio.run(main())
```

**推奨される使用場面:**
- 本番環境のクラウドデプロイメント
- 環境管理不要でスケーラブルな実行が必要な場合

---

### コード実行サイクル

(`BuiltInCodeExecutor`以外のExecutorの場合)

1. **LLMがコード生成**: `LlmAgent`の指示に基づき、LLMがコードスニペットを生成(デリミタで囲まれた形式)
2. **ADKがコード抽出**: LLM Flow内の`_code_execution.response_processor`がコードブロックを検出・抽出
3. **ADKがExecutor起動**: `CodeExecutionInput`を作成し`agent.code_executor.execute_code()`を呼び出し
4. **Executorがコード実行**: 選択された実装に応じた環境でコード実行
5. **Executorが結果返却**: `CodeExecutionResult`(stdout、stderr、出力ファイル)を返却
6. **ADKが結果フォーマット**: 結果を文字列にフォーマット(例: `tool_output ...`)し、`user`ロールの`Content`として`Event`にパッケージ
7. **結果をLLMにフィードバック**: この`Event`(実行結果を含む)を会話履歴に追加し、再度LLMを呼び出し
8. **LLMが結果解釈**: LLMは実行結果を使用して最終応答を生成、追加コード生成、または次のアクション決定

---

### CodeExecutorContext

ステートフルなExecutorやデータファイル入力を最適化する際に使用される内部オブジェクトです。

**役割:**
- `execution_id`: ステートフルセッション用(例: `VertexAiCodeExecutor`)
- 処理済み入力ファイルのリスト(冗長処理を避ける`optimize_data_file`)
- エラーカウント(リトライロジック用)

通常、カスタムCodeExecutorを構築する場合や、コード実行フローを深くカスタマイズする場合以外は直接操作しません。

---

### CodeExecutor選択基準

| Executor | 使用場面 | セキュリティ | 環境管理 | パフォーマンス |
|---------|---------|------------|---------|--------------|
| **BuiltInCodeExecutor** | LLMがネイティブサポート | 高(モデル管理) | 不要 | 高速 |
| **UnsafeLocalCodeExecutor** | 開発・信頼された環境のみ | ❌ 低 | 不要 | 高速 |
| **ContainerCodeExecutor** | 大半のユースケース | 高(Docker分離) | Dockerイメージ管理 | 中(コンテナ起動オーバーヘッド) |
| **VertexAiCodeExecutor** | 本番環境・クラウド | 高(Google管理) | 不要 | 高(クラウドスケール) |

**AskUserQuestion配置:**
不明な場合、以下の質問をユーザーに提示してください:

```python
from google.adk.agents.callback_context import AskUserQuestion

AskUserQuestion(
    questions=[{
        "question": "どのコード実行環境を使用しますか？",
        "header": "CodeExecutor選択",
        "options": [
            {
                "label": "BuiltInCodeExecutor",
                "description": "LLMがネイティブにサポート(Geminiなど)。最も簡単で安全。"
            },
            {
                "label": "ContainerCodeExecutor",
                "description": "Dockerコンテナで実行。高いセキュリティ。本番環境推奨。"
            },
            {
                "label": "VertexAiCodeExecutor",
                "description": "Google Cloudマネージド。スケーラブル。クラウド環境推奨。"
            },
            {
                "label": "UnsafeLocalCodeExecutor",
                "description": "ローカル実行。開発のみ。本番環境厳禁。"
            }
        ],
        "multiSelect": False
    }]
)
```

---

## LLMモデル統合

### BaseLlmインターフェースとLLM Registry

ADKは複数のLLMをサポートするため、共通インターフェース`BaseLlm`を定義しています。

**BaseLlmの主要メソッド:**
- `model: str`: モデル識別子(例: `"gemini-2.0-flash"`)
- `supported_models() -> list[str]` (classmethod): サポートするモデル名の正規表現リスト(LLM Registryが使用)
- `generate_content_async(llm_request: LlmRequest, stream: bool = False) -> AsyncGenerator[LlmResponse, None]`: LLMへのリクエスト送信とレスポンス受信(ストリーミング対応)
- `connect(llm_request: LlmRequest) -> BaseLlmConnection`: 双方向ストリーミング接続(実験的機能)

**LLM Registry:**
ADKは`LLMRegistry`でモデル名パターンと`BaseLlm`サブクラスをマッピングしています。

```python
# モデル名文字列を渡すと、ADKがRegistryから適切なクラスを解決
agent = Agent(model="gemini-2.0-flash", ...)

# 内部的に: LLMRegistry → Gemini("gemini-2.0-flash")を自動インスタンス化
```

これにより、Agent開発者が常にLLMクライアントクラスを明示的にインスタンス化する必要がなくなります。

---

### LiteLlm（幅広いモデルサポート）

`LiteLlm`は[LiteLLMライブラリ](https://litellm.ai/)のラッパーで、100以上のLLM APIに統一インターフェースを提供します。

**サポート対象:**
- クラウドプロバイダー: OpenAI、Azure OpenAI、Anthropic、Cohere、Hugging Faceなど
- ローカルモデル: Ollama経由
- セルフホストエンドポイント: TGI、vLLMなど

**前提条件:**
- `litellm`ライブラリ(`pip install litellm`)
- 各プロバイダーのAPIキーを環境変数に設定(例: `OPENAI_API_KEY`)
- Ollama使用時: Ollamaインストール+モデルpull
- セルフホスト: モデルサービング環境が稼働中

**OpenAI例:**
```python
from google.adk.agents import Agent
from google.adk.models.lite_llm import LiteLlm
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import os

# 環境変数を読み込み

if not os.getenv("OPENAI_API_KEY"):
    print("Warning: OPENAI_API_KEYが未設定です。")
    exit(1)

openai_llm_instance = LiteLlm(model="openai/gpt-4o")

openai_agent = Agent(
    name="openai_gpt_assistant",
    model=openai_llm_instance,
    instruction="LiteLLM経由でOpenAIモデルを使用する便利なアシスタントです。"
)
print("OpenAI GPTエージェント(via LiteLLM)初期化完了。")

runner = InMemoryRunner(agent=openai_agent, app_name="LiteLLM_OpenAI_App")
session_id = "s_openai"
user_id = "openai_user"
# セッション作成

user_message = Content(parts=[Part(text="Pythonプログラミングについての短い詩を書いてください。")], role="user")
print("\nOpenAI GPT Agent (via LiteLLM):")
for event in runner.run(user_id=user_id, session_id=session_id, new_message=user_message):
    if event.content and event.content.parts:
        for part in event.content.parts:
            if part.text:
                print(part.text, end="")
print()
```

**Ollama経由のローカルモデル:**
```python
from google.adk.agents import Agent
from google.adk.models.lite_llm import LiteLlm
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import requests

# Ollamaサーバーが稼働しているか確認
ollama_running = False
try:
    response = requests.get("http://localhost:11434")
    if response.status_code == 200 and "Ollama is running" in response.text:
        ollama_running = True
        print("Ollamaサーバー検出。")
except requests.exceptions.ConnectionError:
    print("Ollamaサーバーが見つかりません。Ollamaがインストール・起動されているか確認してください。")
    exit(1)

if ollama_running:
    # モデル名の前に"ollama/"を付ける
    # 事前に`ollama pull llama3`でモデルをpull済み想定
    ollama_llm_instance = LiteLlm(model="ollama/llama3")

    ollama_agent = Agent(
        name="local_llama3_assistant",
        model=ollama_llm_instance,
        instruction="OllamaとLlama 3経由でローカル実行される便利なアシスタントです。"
    )
    print("Ollama Llama3エージェント(via LiteLLM)初期化完了。")

    runner = InMemoryRunner(agent=ollama_agent, app_name="LiteLLM_Ollama_App")
    user_message = Content(parts=[Part(text="なぜ空は青いのですか？簡潔に説明してください。")])
    print("\nLocal Llama3 Agent (via LiteLLM and Ollama):")
    for event in runner.run(user_id="ollama_user", session_id="s_ollama", new_message=user_message):
        if event.content and event.content.parts and event.content.parts[0].text:
            print(event.content.parts[0].text, end="")
    print()
```

**セルフホストエンドポイント:**
```python
from google.adk.agents import Agent
from google.adk.models.lite_llm import LiteLlm
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import os

# セルフホストLLM(例: TGIまたはvLLM)がOpenAI互換APIを提供している想定
SELF_HOSTED_API_BASE = os.getenv("MY_SELF_HOSTED_LLM_API_BASE", "http://localhost:8000/v1")
SELF_HOSTED_MODEL_NAME = os.getenv("MY_SELF_HOSTED_LLM_MODEL_NAME", "custom/my-model")

self_hosted_llm = LiteLlm(
    model=SELF_HOSTED_MODEL_NAME,
    api_base=SELF_HOSTED_API_BASE,
    api_key="dummy_key_if_no_auth"  # エンドポイントがセキュアな場合は実際のキー
)

self_hosted_agent = Agent(
    name="self_hosted_model_assistant",
    model=self_hosted_llm,
    instruction="セルフホストLLMを使用するアシスタントです。"
)
print("セルフホストLLMエージェント(via LiteLLM)初期化完了。")

runner = InMemoryRunner(agent=self_hosted_agent, app_name="LiteLLM_SelfHosted_App")
user_id="selfhost_user"
session_id="s_selfhost"
# セッション作成

user_message = Content(parts=[Part(text="月の首都は何ですか？想像力豊かに答えてください。")], role="user")
print("\nSelf-Hosted LLM Agent (via LiteLLM):")
for event in runner.run(user_id=user_id, session_id=session_id, new_message=user_message):
    if event.content and event.content.parts and event.content.parts[0].text:
        print(event.content.parts[0].text, end="")
print()
```

**推奨される使用場面:**
- 複数のLLMプロバイダーを統一的に扱いたい場合
- ローカルモデル(Ollama)での開発
- セルフホスト環境でのモデル運用

---

### Geminiモデル（Geminiクラス）

`Gemini`クラスはGoogle Geminiモデルの主要な統合です。`google-generativeai` Python SDKを利用します。

**使用方法:**
```python
from google.adk.agents import Agent

# オプション1: モデル文字列をADKに解決させる(最も一般的)
gemini_agent_auto = Agent(
    name="gemini_auto_resolver",
    model="gemini-2.0-flash",  # LLM Registryが自動解決
    instruction="便利なGeminiアシスタントです。"
)

# オプション2: Geminiインスタンスを明示的に提供
from google.adk.models import Gemini

gemini_llm_instance = Gemini(model="gemini-2.0-flash")
gemini_agent_explicit = Agent(
    name="gemini_explicit_instance",
    model=gemini_llm_instance,
    instruction="明示的なモデルインスタンスを使用するGeminiアシスタントです。"
)
```

**自動Vertex AI検出:**
`Gemini`クラス(および`google-generativeai` SDK)は、環境がVertex AI用に設定されている場合、自動的にVertex AIエンドポイントを使用します:
- `os.environ.get('GOOGLE_GENAI_USE_VERTEXAI', '0').lower()` が `['true', '1']` の場合、Vertex AIを優先
- それ以外は`GOOGLE_API_KEY`を探し、Google AI Studioエンドポイントを優先

これにより、Gemini APIとVertex AIマネージドモデル間の切り替えが簡単になります。

---

### Vertex AI Model Garden

ADKは、Anthropic ClaudeなどのVertex AI Model Gardenのモデルをサポートします。

**前提条件:**
- Vertex AIでClaudeモデルへのアクセス
- `anthropic`ライブラリ(`pip install anthropic`)
- 環境変数`GOOGLE_CLOUD_PROJECT`と`GOOGLE_CLOUD_LOCATION`(例: "us-central1")が設定済み

**コード例:**
```python
from google.adk.agents import Agent
from google.adk.models.anthropic_llm import Claude
from google.adk.models.registry import LLMRegistry
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import os

# 環境変数を読み込み

# ClaudeモデルをLLM Registryに登録
LLMRegistry.register(Claude)

GCP_PROJECT = os.getenv("GOOGLE_CLOUD_PROJECT")
GCP_LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION")  # 例: "us-central1"
CLAUDE_MODEL_NAME = "claude-sonnet-4@20250514"

if not GCP_PROJECT or not GCP_LOCATION:
    print("GOOGLE_CLOUD_PROJECTまたはGOOGLE_CLOUD_LOCATIONが未設定です。")
    exit(1)

claude_agent = Agent(
    name="claude_assistant",
    model=CLAUDE_MODEL_NAME,
    instruction="Claudeを使用する便利で思慮深いアシスタントです。包括的な回答を提供します。"
)
print(f"Claudeエージェント初期化完了(モデル: {CLAUDE_MODEL_NAME}, Vertex AI)。")

runner = InMemoryRunner(agent=claude_agent, app_name="ClaudeApp")
session_id = "s_claude"
user_id = "claude_user"
# セッション作成

user_message = Content(parts=[Part(text="複雑なシステムにおける創発特性の概念を説明してください。")], role="user")
print("\nClaude Agent:")
for event in runner.run(user_id=user_id, session_id=session_id, new_message=user_message):
    if event.content and event.content.parts:
        for part in event.content.parts:
            if part.text:
                print(part.text, end="")
print()
```

**Vertex AI上のClaudeモデル名:**
Vertex AI経由でClaudeモデルを使用する場合、Vertex AIが使用する特定の識別子(例: `"claude-sonnet-4@20250514"`)を使用する必要があります。Vertex AIドキュメントで正しいモデルIDを確認してください。

---

### LlmRequestの構造

`LlmRequest`は、LLMに送信されるデータのADK標準フォーマットです。LLM Flow(例: `SingleFlow`)が構築します。

**主要コンポーネント:**
- `model: Optional[str]`: モデル文字列
- `contents: list[types.Content]`: 会話履歴
  - `Content`オブジェクトのリスト
  - 各`Content`は`role`(`"user"`または`"model"`)と`parts`(Part のリスト)を持つ
  - Partはテキスト、関数呼び出し、関数レスポンス、インラインデータのいずれか
- `config: Optional[types.GenerateContentConfig]`: 生成設定
  - `system_instruction: Optional[str]`: コンパイル済みシステムプロンプト(Agent instruction + global instruction + ツール提供の追加指示)
  - `tools: Optional[list[types.Tool]]`: LLMが利用可能なツールの`FunctionDeclaration`リスト
  - 生成パラメータ: `temperature`、`max_output_tokens`、`safety_settings`
  - `response_schema`: 構造化JSONレスポンスを期待する場合
- `live_connect_config: types.LiveConnectConfig`: ライブ双方向ストリーミング設定
- `tools_dict: dict[str, BaseTool]`: (ADK内部用)ツール名から`BaseTool`インスタンスへのマッピング

LLM Flowと各種リクエストプロセッサー(`instructions.py`、`contents.py`、`functions.py`など)が連携してこれらのフィールドを設定します。

---

### LlmResponseの構造

`LlmResponse`は、LLMから受信されるデータのADK標準フォーマットです。

**主要コンポーネント:**
- `content: Optional[types.Content]`: LLMからのメインペイロード
  - テキスト: `content.parts[0].text`
  - ツール呼び出し: `content.parts[0].function_call`
  - `content.role`は通常`"model"`
- `partial: Optional[bool]`: `True`の場合、ストリーミングテキストレスポンスのチャンク
- `usage_metadata: Optional[types.GenerateContentResponseUsageMetadata]`:
  - `prompt_token_count: int`
  - `candidates_token_count: int`
  - `total_token_count: int`
- `grounding_metadata: Optional[types.GroundingMetadata]`: LLMがグラウンディング(例: `GoogleSearchTool`)を使用した場合の情報
- `error_code: Optional[str]`, `error_message: Optional[str]`: LLM呼び出しが失敗した場合
- `turn_complete: Optional[bool]`: ライブストリーミング時、モデルがターンを終了したかを示す
- `interrupted: Optional[bool]`: ライブストリーミング時、ユーザーがモデルを中断したかを示す
- `custom_metadata: Optional[dict[str, Any]]`: カスタムメタデータを添付可能(例: `after_model_callback`で使用)

LLM Flowはこれらの`LlmResponse`オブジェクトをADK `Event`オブジェクトに変換し、`Runner`がyieldします。

**LlmResponseの検査:**
- `after_model_callback`では生の`LlmResponse`を受信できる(ログ、メタデータ検査、レスポンス修正に最適)
- Dev UIのTraceビューで各LLM相互作用の詳細(`LlmRequest`と`LlmResponse`)を確認可能

---

### ストリーミングレスポンス

ADKはストリーミングレスポンスをサポートします。`RunConfig`でストリーミングを有効化すると、`BaseLlm`の`generate_content_async`が`stream=True`で呼び出されます。

**動作:**
- 単一の`LlmResponse`ではなく、`AsyncGenerator[LlmResponse, None]`をyield
- 各yielded `LlmResponse`はテキストのチャンクを含み、`partial`属性が`True`
- ストリームの最後の`LlmResponse`は`partial=False`(または関数呼び出しのみ含む、または`finish_reason`が完了を示す)
- ADK `Runner`はこれらの部分的な`Event`をyieldし、生成中にテキストをユーザーに表示可能

**コード例:**
```python
from google.adk.agents import Agent
from google.adk.runners import InMemoryRunner, RunConfig
from google.adk.agents.run_config import StreamingMode
from google.genai.types import Content, Part
import asyncio

# 環境変数を読み込み

streaming_demo_agent = Agent(
    name="streaming_writer",
    model="gemini-2.0-flash",
    instruction="好奇心旺盛な猫についての非常に短い物語(10-15文)を書いてください。"
)

runner = InMemoryRunner(agent=streaming_demo_agent, app_name="StreamingApp")
session_id = "s_streaming"
user_id = "streaming_user"
# セッション作成

user_message = Content(parts=[Part(text="物語を聞かせてください。")], role="user")

async def run_with_streaming():
    print("ストリーミングAgentレスポンス:")
    run_config = RunConfig(streaming_mode=StreamingMode.SSE)

    async for event in runner.run_async(
        user_id=user_id,
        session_id=session_id,
        new_message=user_message,
        run_config=run_config
    ):
        if event.content and event.content.parts:
            for part in event.content.parts:
                if part.text:
                    print(part.text, end="", flush=True)
    print("\n--- ストリーム終了 ---")

asyncio.run(run_with_streaming())
```

**推奨される使用場面:**
会話型Agentでは、ストリーミングレスポンスによりユーザー体験が大幅に向上します(全レスポンス生成を待つのではなく、即座のフィードバック)。`runner.run_async`呼び出し時に`RunConfig`で有効化してください。

---

## Flows & Planners

### BaseLlmFlow概念とSingleFlow

**LLM Flow** (`BaseLlmFlow`)は、`LlmAgent`が1ターン(または1ステップ)の相互作用中に実行する操作シーケンスを決定するADKの内部コンポーネントです。

**主要な責務:**
1. `LlmRequest`の準備(履歴、指示、ツールの収集)
2. LLMの呼び出し
3. `LlmResponse`の処理(テキスト、ツール呼び出し、エラー処理)
4. 更なるLLM相互作用が必要か(例: ツール呼び出し後)、または最終レスポンスに達したかを決定

**デフォルトFlow:**
- **`SingleFlow`**: 複雑なマルチAgent転送用に設定されていない`LlmAgent`のデフォルトFlow
  - LLM呼び出しとツール実行の基本ループを最終テキストレスポンス生成まで処理
- **`AutoFlow`**: `SingleFlow`を継承し、**Agent間転送**機能を追加
  - 他の登録済みサブAgentまたは親Agentにタスクを委譲するロジック・内部ツール(`transfer_to_agent`)を含む
  - `LlmAgent`に`sub_agents`が定義されている場合に通常使用される

**使用するFlowの決定:**
ADKはAgent設定(サブAgentの有無、転送disallowフラグ等)に基づいて自動的にFlowを決定します。通常、開発者が直接`BaseLmFlow`をインスタンス化することはありません。

---

### LLM Flow Processors（リクエスト前処理・レスポンス後処理）

LLM FlowはLLM Flow Processorsにより拡張性が高まります。これらは、`LlmRequest`送信前や`LlmResponse`受信後にインターセプト・修正できる小規模で焦点を絞ったクラスです。

**主要な組み込みリクエストプロセッサー(実行順):**
1. `basic.request_processor`: 基本的な`LlmRequest`フィールド(モデル名、生成設定)を設定
2. `auth_preprocessor.request_processor`: 認証関連情報処理(ツール呼び出しの再開時に特に重要)
3. `instructions.request_processor`: Agentの`instruction`と`global_instruction`から`system_instruction`を設定(状態インジェクション実行)
4. `identity.request_processor`: LLMに名前と説明を伝えるデフォルト指示を追加
5. `contents.request_processor`: セッションからイベントをフィルタリング・フォーマットして`contents`(会話履歴)を構築
6. `_nl_planning.request_processor` (Planners用): Plannerがアクティブな場合、計画特有の指示を追加
7. `_code_execution.request_processor` (Code Executors用): Code Executorがアクティブ(かつ`BuiltInCodeExecutor`以外)の場合、データファイル前処理や過去のコード実行Partのテキスト変換を実行
8. `agent_transfer.request_processor` (`AutoFlow`用): Agent間転送に関する指示とツール宣言を追加

**主要な組み込みレスポンスプロセッサー:**
1. `_nl_planning.response_processor`: Plannerがアクティブな場合、LLMレスポンスから計画関連アーティファクト(例: 思考抽出、計画状態更新)を処理
2. `_code_execution.response_processor`: Code Executorがアクティブな場合、LLMレスポンスからコードを抽出し、Executorを起動し、実行結果をLLMに返す準備をする

これらのProcessorを直接記述することは通常ありませんが、その存在と順序を理解することはAgent動作のデバッグと予測に役立ちます。

---

### BuiltInPlanner（モデルネイティブの計画機能）

一部の高度なLLM(特に新しいGeminiモデル)は、特定の設定で有効化できる組み込みの「思考」または「計画」機能を持っています。

`BuiltInPlanner`はこのようなネイティブモデル計画機能を有効化・設定するために使用します。

**動作:**
- `thinking_config: types.ThinkingConfig`を初期化時に引数として受け取る
- `build_planning_instruction`は何もしない(テキスト指示を追加せず、`thinking_config`が処理)
- `apply_thinking_config(llm_request)`メソッド(` _nl_planning.request_processor`によって呼び出される)が`self.thinking_config`を`LlmRequest.config`に追加
- `process_planning_response`も通常は何もしない(モデルの組み込み計画は通常、ADKが既に処理できる形式で出力を構造化)

**コード例:**
```python
from google.adk.agents import Agent
from google.adk.planners import BuiltInPlanner
from google.genai.types import ThinkingConfig
from google.adk.tools import FunctionTool
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part

# 環境変数を読み込み

def get_product_price(product_id: str) -> dict:
    """指定された商品IDの価格を取得します。"""
    prices = {"prod123": 29.99, "prod456": 49.50}
    if product_id in prices:
        return {"product_id": product_id, "price": prices[product_id]}
    return {"error": "商品が見つかりません"}

price_tool = FunctionTool(func=get_product_price)

product_thinking_config = ThinkingConfig(include_thoughts=True)
builtin_item_planner = BuiltInPlanner(thinking_config=product_thinking_config)

agent_with_builtin_planner = Agent(
    name="smart_shopper_builtin",
    model="gemini-2.0-flash-thinking-exp-01-21",  # ThinkingConfigサポート必須
    instruction="商品価格を見つけるためのアシスタントです。段階的に考え、ツールを使用してください。",
    tools=[price_tool],
    planner=builtin_item_planner
)

runner = InMemoryRunner(agent=agent_with_builtin_planner, app_name="BuiltInPlanApp")
session_id = "s_builtinplan"
user_id = "plan_user"
# セッション作成

prompt = "prod123とprod456の価格は何ですか？"

print(f"YOU: {prompt}")
user_message = Content(parts=[Part(text=prompt)], role="user")
print("ASSISTANT: ", end="", flush=True)

async def main():
    async for event in runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
        if event.content and event.content.parts:
            for part in event.content.parts:
                if part.text:
                    print(part.text, end="", flush=True)
                elif hasattr(part, 'thought') and part.thought:
                    print(f"\n  [THOUGHT]: {part.text.strip() if part.text else 'No text in thought'}\n  ", end="")
                elif part.function_call:
                    print(f"\n  [TOOL CALL]: {part.function_call.name}({part.function_call.args})\n  ", end="")
                elif part.function_response:
                    print(f"\n  [TOOL RESPONSE to {part.function_response.name}]: {part.function_response.response}\n  ", end="")
    print()

import asyncio
asyncio.run(main())
```

**推奨される使用場面:**
- 対象LLMが強力な組み込み計画または「思考」機能を提供している場合
- 最も簡単な方法(適切な`ThinkingConfig`を設定するだけ)

**モデルサポート:**
すべてのモデルが`ThinkingConfig`をサポートするわけではなく、サポートするモードやオプションも異なります。必ず特定のモデルバージョンのドキュメントを確認し、適切な`ThinkingConfig`パラメータを理解してください。

---

### PlanReActPlanner（Plan-Reason-Act-Observeサイクル）

ReAct(Reason + Act)パラダイムは、LLMが複雑なタスクを解決するための人気のあるプロンプト戦略で、反復的に以下を実行します:

1. **推論(Reasoning)**: 現在の状態と全体目標について推論
2. **アクション(Action)**: 次に取るアクション(多くの場合ツール呼び出し)を決定
3. **観察(Observation)**: アクションの結果を取得
4. 新しい推論に観察を組み込み、プロセスを繰り返す

`PlanReActPlanner`は、LLMに出力を計画、推論、アクションタグで明示的に構造化するよう指示することで、この変形を実装します。

**動作:**
- **`build_planning_instruction(...)`**: `LlmRequest`に詳細なプロンプトを注入:
  - 最初に`/*PLANNING*/`タグの下に全体計画を生成
  - 各ステップで、`/*REASONING*/`の下に推論を提供し、`/*ACTION*/`の下にアクション(ツール呼び出し)を実行
  - 観察に基づいて計画を修正する必要がある場合は`/*REPLANNING*/`を使用
  - 最後に`/*FINAL_ANSWER*/`の下に回答を提供
- **`process_planning_response(...)`**:
  - LLMレスポンスをこれらのタグでパース
  - `/*PLANNING*/`、`/*REASONING*/`、`/*ACTION*/`(ツール呼び出し前のテキストの場合)、`/*REPLANNING*/`でタグ付けされたPartを「思考」としてマーク(`part.thought = True`)
    - これらは通常Traceにログ記録されるが、エンドユーザーへの会話レスポンスには直接表示されない
  - ツール呼び出し(LLMが`/*ACTION*/`タグまたは推論の後に配置すべき)を抽出・実行
  - `/*FINAL_ANSWER*/`の下のコンテンツをユーザーへの直接レスポンスとして扱う
  - セッションの状態(`state['current_plan']`、`state['last_observation']`)を`callback_context`経由で更新可能

**コード例:**
```python
from google.adk.agents import Agent
from google.adk.planners import PlanReActPlanner
from google.adk.tools import FunctionTool
from google.adk.runners import InMemoryRunner
from google.adk.sessions.state import State
from google.adk.agents.callback_context import CallbackContext
from google.genai.types import Content, Part

# 環境変数を読み込み

# デモ用ダミーツール
def search_knowledge_base(query: str, tool_context: CallbackContext) -> str:
    """社内ナレッジベースを検索します。"""
    tool_context.state[State.TEMP_PREFIX + "last_search_query"] = query
    if "policy" in query.lower():
        return "見つかったドキュメント: 'HR001: 在宅勤務ポリシー - 従業員は週2回、上司の承認を得てリモートワーク可能。'"
    if "onboarding" in query.lower():
        return "見つかったドキュメント: 'IT005: 新入社員オンボーディングチェックリスト - アカウント設定と必須研修が含まれます。'"
    return "クエリに関連するドキュメントが見つかりませんでした。"

def request_manager_approval(employee_id: str, reason: str) -> str:
    """従業員の上司に承認リクエストを送信します。"""
    return f"従業員{employee_id}の承認リクエストが送信されました。理由: {reason}。ステータス: 保留中。"

search_tool = FunctionTool(func=search_knowledge_base)
approval_tool = FunctionTool(func=request_manager_approval)

react_planner = PlanReActPlanner()

hr_assistant_react = Agent(
    name="hr_assistant_react",
    model="gemini-2.0-flash-thinking-exp-01-21",  # 強力な推論モデルが必要
    instruction="あなたはHRアシスタントです。Plan-Reason-Act-Observeサイクルに従ってください。最初に計画を作成し、各ステップで推論を提供し、アクション(必要に応じてツールを使用)を実行し、観察について推論して続行または再計画します。最終回答で締めくくります。",
    tools=[search_tool, approval_tool],
    planner=react_planner
)

runner = InMemoryRunner(agent=hr_assistant_react, app_name="ReActHrApp")
session_id = "s_react"
user_id = "hr_user"
# セッション作成

prompt = "従業員emp456がフルタイムで在宅勤務したいと考えています。プロセスは何ですか？"

print(f"YOU: {prompt}")
user_message = Content(parts=[Part(text=prompt)], role="user")
print("HR_ASSISTANT_REACT (完全なReActフローはDev UIのTraceで確認):\n")

full_response_parts = []
async def main():
    async for event in runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
        if event.content and event.content.parts:
            for part in event.content.parts:
                is_thought = hasattr(part, 'thought') and part.thought
                if part.text and not is_thought:
                    print(part.text, end="")
                    full_response_parts.append(part.text)
                elif part.text and is_thought:
                    print(f"\n  [THOUGHT/PLAN]:\n  {part.text.strip()}\n  ", end="")
                elif part.function_call:
                    print(f"\n  [TOOL CALL]: {part.function_call.name}({part.function_call.args})\n  ", end="")
                elif part.function_response:
                    print(f"\n  [TOOL RESPONSE to {part.function_response.name}]: {part.function_response.response}\n  ", end="")
    print("\n--- 統合されたAgentレスポンス ---")
    print("".join(full_response_parts))

import asyncio
asyncio.run(main())
```

**推奨される使用場面:**
- LLMに作業を明示的に表示させ、構造化された問題解決アプローチに従わせたい場合
- Agentの推論プロセスをTraceで検査して透明性とデバッグ性を高める
- ツール使用と観察を伴う順次ステップに自然に分解できるタスク

**注意点:**
- `PlanReActPlanner`が注入する指示は詳細でプロンプト長を増加させる
- 効果はLLMがタグフォーマットを一貫して守れるかに大きく依存する(強力な推論モデルほど良好)
- LLMがフォーマットから逸脱したりステップをスキップしたりする場合、Agentのメイン指示を調整してReActパターンを強化する必要がある

---

### Planner選択基準

| Planner | 使用場面 | LLM要件 | 推論の透明性 |
|---------|---------|---------|-------------|
| **BuiltInPlanner** | LLMがネイティブ思考機能をサポート | 高(モデルサポート必須) | モデル依存 |
| **PlanReActPlanner** | 明示的なステップバイステップ推論が必要 | 中〜高(タグ付けフォーマットを守れること) | 高(思考・計画がTraceに明示) |
| **カスタムPlanner** | 特殊な計画ロジックが必要 | - | カスタマイズ可能 |

**AskUserQuestion配置:**
不明な場合、以下の質問をユーザーに提示してください:

```python
from google.adk.agents.callback_context import AskUserQuestion

AskUserQuestion(
    questions=[{
        "question": "どのPlannerを使用しますか？",
        "header": "Planner選択",
        "options": [
            {
                "label": "BuiltInPlanner",
                "description": "LLMがネイティブ思考機能をサポート。最も簡単。"
            },
            {
                "label": "PlanReActPlanner",
                "description": "明示的なPlan-Reason-Act-Observeサイクル。推論が透明。"
            },
            {
                "label": "Plannerなし",
                "description": "シンプルなタスクの場合、Plannerは不要。"
            }
        ],
        "multiSelect": False
    }]
)
```
