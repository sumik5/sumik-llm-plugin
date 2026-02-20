# コード実行とLLMモデル統合

ADK Agentがコードを実行し、様々なLLMプロバイダーと連携するための包括的なリファレンスです。
書籍「Google ADK for Agentic AI」「Mastering Google ADK」の知識を統合した実践ガイドです。

---

## 目次

1. [コード実行（Code Executors）](#1-コード実行code-executors)
2. [LLMモデル統合](#2-llmモデル統合)
3. [Geminiモデルの特性と選択](#3-geminiモデルの特性と選択)
4. [Gemini固有機能](#4-gemini固有機能)
5. [Flows & Planners](#5-flows--planners)
6. [Output Schema（構造化出力）](#6-output-schema構造化出力)
7. [InstructionProvider（動的instruction生成）](#7-instructionprovider動的instruction生成)
8. [モデル切り替えパターン](#8-モデル切り替えパターン)

---

## 1. コード実行（Code Executors）

### BaseCodeExecutor概要

`BaseCodeExecutor`は、LLMが生成したPythonコードを実行するための抽象基底クラスです。
Agentがコード実行機能を持つとき、LLMは単なる推論エンジンに留まらず、
計算、データ分析、ファイル操作などを実際に「実行」できるエージェントになります。

**設定可能なパラメータ:**

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| `stateful` | bool | 実行間で変数・状態を保持するか |
| `optimize_data_file` | bool | データファイルの自動管理 |
| `error_retry_attempts` | int | 失敗時の再試行回数 |
| `code_block_delimiters` | list | コードブロックのフォーマット定義 |
| `execution_result_delimiters` | list | 実行結果のフォーマット定義 |

---

### CodeExecutor選択基準テーブル

| Executor | セキュリティ | 環境管理 | 速度 | 主な用途 |
|---------|------------|---------|------|---------|
| **BuiltInCodeExecutor** | 高（モデル管理サンドボックス） | 不要 | 最高速 | Gemini等ネイティブ対応モデル |
| **UnsafeLocalCodeExecutor** | 極低（本番厳禁） | 不要 | 高速 | 開発・実験専用 |
| **ContainerCodeExecutor** | 高（Docker分離） | Dockerイメージ管理 | 中（起動オーバーヘッド有） | 大半の本番ユースケース |
| **VertexAiCodeExecutor** | 最高（Google管理） | 不要 | 高（クラウドスケール） | クラウドネイティブ本番環境 |

---

### 1-1. BuiltInCodeExecutor（モデルネイティブ実行）

LLMが内部サンドボックスでコード実行機能を持つ場合に使用します。
Geminiモデルの「コードインタープリター」機能を直接活用します。

**動作フロー:**
1. `BuiltInCodeExecutor`がLLMリクエストを修正してコードインタープリターを有効化
2. LLMがコードを生成（`executable_code` Part）
3. モデルが内部サンドボックスで実行
4. LLMが実行結果を含む`code_execution_result` Partを生成
5. ADKがこれらのPartを含むEventをyield

```python
from google.adk.agents import Agent
from google.adk.code_executors import BuiltInCodeExecutor
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part

code_agent = Agent(
    name="code_agent_builtin",
    model="gemini-2.0-flash",
    instruction=(
        "あなたは計算やデータ分析のためにPythonコードを書いて実行できるアシスタントです。"
        "コードを実行して正確な結果を提供してください。"
    ),
    code_executor=BuiltInCodeExecutor()
)

runner = InMemoryRunner(agent=code_agent, app_name="BuiltInCodeApp")

async def main():
    user_message = Content(
        parts=[Part(text="最初の10個の素数を生成してください")],
        role="user"
    )
    async for event in runner.run_async(
        user_id="user1", session_id="session1", new_message=user_message
    ):
        if event.content and event.content.parts:
            for part in event.content.parts:
                if part.text:
                    print(part.text, end="", flush=True)
                elif part.executable_code:
                    print(f"\n[CODE]\n{part.executable_code.code}\n[/CODE]")
                elif part.code_execution_result:
                    print(f"\n[RESULT]\n{part.code_execution_result.output}\n[/RESULT]")

import asyncio
asyncio.run(main())
```

**推奨場面:**
- Gemini 2.0 Flash / Gemini 2.0 Pro など対応モデルを使用する場合
- ADK側での環境設定不要で最も簡単かつ安全な実行方式
- インタラクティブな計算・データ分析タスク

---

### 1-2. UnsafeLocalCodeExecutor（開発用・信頼環境限定）

Pythonの`exec()`を使用して、ADKアプリケーションと同じプロセス内でコードを実行します。

**重大なセキュリティリスク（本番環境絶対禁止）:**
- LLM生成コードがローカル環境に直接アクセス可能
- ファイルシステム、ネットワーク、システムリソースへの無制限アクセス
- 悪意ある入力によるシステム破壊のリスク

```python
from google.adk.agents import Agent
from google.adk.code_executors import UnsafeLocalCodeExecutor

# 開発・実験環境のみ使用
unsafe_agent = Agent(
    name="unsafe_code_agent",
    model="gemini-2.0-flash",
    instruction=(
        "問題解決のためにPythonコードを書くアシスタントです。"
        "標準Pythonのみ使用してください（外部ライブラリ禁止）。"
    ),
    code_executor=UnsafeLocalCodeExecutor(
        stateful=True,
        error_retry_attempts=2
    )
)
```

**使用可能な場面（厳格に限定）:**
- 完全に隔離された開発環境
- 信頼された開発者のみがアクセスする実験用環境
- 信頼されたモデルと入力のみの場合

---

### 1-3. ContainerCodeExecutor（Docker分離実行）

Dockerコンテナ内でコードを実行し、ホストシステムから強力に分離します。
セキュリティと柔軟性を兼ね備えた、大半の本番ユースケースに推奨される方式です。

**前提条件:**
```bash
# Dockerのインストールと起動が必要
pip install docker
```

```python
from google.adk.agents import Agent
from google.adk.code_executors import ContainerCodeExecutor
import os

# カスタムDockerfileからビルド（pandas/numpyを含む環境）
dockerfile_dir = "/tmp/python_env"
os.makedirs(dockerfile_dir, exist_ok=True)

with open(os.path.join(dockerfile_dir, "Dockerfile"), "w") as f:
    f.write("FROM python:3.11-slim\n")
    f.write("RUN pip install numpy pandas matplotlib scipy\n")
    f.write("WORKDIR /app\n")

container_executor = ContainerCodeExecutor(
    docker_path=dockerfile_dir,
    stateful=True,
    error_retry_attempts=3
)

container_agent = Agent(
    name="data_analysis_agent",
    model="gemini-2.0-flash",
    instruction=(
        "Pythonデータ分析アシスタントです。"
        "コードはDockerコンテナで安全に実行されます。"
        "numpy、pandas、matplotlib、scipyが使用できます。"
    ),
    code_executor=container_executor
)
```

**ベストプラクティス:**
- 必要なライブラリのみを含む最小限のDockerイメージを使用
- `python:3.11-slim`など軽量ベースイメージを選択
- 非rootユーザーでのコンテナ実行を検討
- コンテナのリソース制限（CPU/メモリ）を設定

---

### 1-4. VertexAiCodeExecutor（クラウドマネージドコード実行）

Google CloudのVertex AI Code Interpreter Extensionを使用したフルマネージド実行環境です。
インフラ管理不要で、Google管理のセキュアなサンドボックスでコードを実行します。

**前提条件:**
```bash
gcloud auth application-default login
pip install "google-cloud-aiplatform>=1.47.0"
```

**事前インストール済みライブラリ（Vertex AI Code Interpreter）:**
- pandas, numpy, matplotlib, scipy, scikit-learn, PIL (Pillow)

```python
from google.adk.agents import Agent
from google.adk.code_executors import VertexAiCodeExecutor
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import os

assert os.getenv("GOOGLE_CLOUD_PROJECT"), "GOOGLE_CLOUD_PROJECT must be set"

vertex_executor = VertexAiCodeExecutor()

vertex_agent = Agent(
    name="vertex_analytics_agent",
    model="gemini-2.0-flash",
    instruction=(
        "高度なデータ分析アシスタントです。"
        "計算・可視化・統計分析のためにPythonコードを書いてください。"
        "安全なVertex AI環境で実行されます。"
        "matplotlibでグラフを生成した場合、Artifactとして保存されます。"
    ),
    code_executor=vertex_executor
)

runner = InMemoryRunner(agent=vertex_agent, app_name="VertexApp")

async def run_with_artifact():
    user_message = Content(
        parts=[Part(text="正弦波と余弦波を同一グラフにプロットし、waves.pngとして保存してください")],
        role="user"
    )
    async for event in runner.run_async(
        user_id="user1", session_id="s1", new_message=user_message
    ):
        if event.content and event.content.parts:
            for part in event.content.parts:
                if part.text:
                    print(part.text, end="", flush=True)

    if runner.artifact_service:
        artifacts = await runner.artifact_service.list_artifact_keys(
            app_name="VertexApp", user_id="user1", session_id="s1"
        )
        print(f"\n生成Artifacts: {artifacts}")

import asyncio
asyncio.run(run_with_artifact())
```

**推奨場面:**
- 本番環境のクラウドデプロイメント
- データビジュアライゼーションやファイル生成が必要なタスク
- インフラ管理を最小化したい場合

---

### コード実行サイクル（BuiltIn以外）

`UnsafeLocalCodeExecutor`、`ContainerCodeExecutor`、`VertexAiCodeExecutor`の共通フロー:

```
1. LLMがコードを生成（デリミタで囲まれた形式）
   ↓
2. ADK LLM Flow内の response_processor がコードブロックを抽出
   ↓
3. CodeExecutionInput を作成し agent.code_executor.execute_code() を呼び出し
   ↓
4. Executorが選択された環境でコードを実行
   ↓
5. CodeExecutionResult（stdout/stderr/出力ファイル）を返却
   ↓
6. ADKが結果をフォーマットしてEventにパッケージ
   ↓
7. 結果をLLMにフィードバック（会話履歴に追加）
   ↓
8. LLMが結果を解釈して最終応答を生成（または追加コード生成）
```

---

## 2. LLMモデル統合

### BaseLlmインターフェースとLLM Registry

ADKは`BaseLlm`抽象クラスを介して複数のLLMプロバイダーを統一的に扱います。
LLM Registryにより、モデル名文字列から適切な実装クラスへの自動解決が行われます。

**BaseLlmの主要メソッド:**

| メソッド | 説明 |
|---------|------|
| `model: str` | モデル識別子（例: `"gemini-2.0-flash"`） |
| `supported_models()` | サポートするモデル名の正規表現リスト（Registry用） |
| `generate_content_async(llm_request, stream)` | LLMへのリクエスト送信・レスポンス受信 |
| `connect(llm_request)` | 双方向ストリーミング接続（実験的） |

**LLM Registryの動作:**
```python
from google.adk.agents import Agent

# モデル文字列を渡すと、LLM Registryが自動解決
agent = Agent(
    model="gemini-2.0-flash",  # 自動的に Gemini("gemini-2.0-flash") にマッピング
    instruction="..."
)

# 明示的なインスタンス化も可能
from google.adk.models import Gemini
gemini_llm = Gemini(model="gemini-2.0-flash")
agent2 = Agent(model=gemini_llm, instruction="...")
```

---

### LiteLlm（100以上のモデルに統一インターフェース）

`LiteLlm`は[LiteLLMライブラリ](https://litellm.ai/)のラッパーで、
OpenAI、Anthropic、Azure、Cohere、Ollamaなど100以上のLLM APIに統一インターフェースを提供します。

**インストール:**
```bash
pip install litellm
```

#### OpenAI / Azure OpenAI

```python
from google.adk.agents import Agent
from google.adk.models.lite_llm import LiteLlm
import os

# OpenAI GPT-4o
openai_agent = Agent(
    name="gpt4o_assistant",
    model=LiteLlm(model="openai/gpt-4o"),
    instruction="GPT-4o を使用する多機能アシスタントです。"
)

# Azure OpenAI
azure_agent = Agent(
    name="azure_assistant",
    model=LiteLlm(
        model="azure/gpt-4o",
        api_base=os.getenv("AZURE_OPENAI_ENDPOINT"),
        api_key=os.getenv("AZURE_OPENAI_API_KEY"),
        api_version="2024-02-01"
    ),
    instruction="Azure OpenAI を使用するアシスタントです。"
)
```

#### Ollama経由のローカルモデル

```python
from google.adk.agents import Agent
from google.adk.models.lite_llm import LiteLlm
import requests

def check_ollama_running() -> bool:
    try:
        resp = requests.get("http://localhost:11434")
        return resp.status_code == 200
    except requests.exceptions.ConnectionError:
        return False

if not check_ollama_running():
    raise RuntimeError("Ollamaが起動していません。ollama serveで起動してください。")

local_agent = Agent(
    name="local_llama3",
    model=LiteLlm(model="ollama/llama3"),  # "ollama/"プレフィックスが必要
    instruction="ローカルLlama3モデルを使用するアシスタントです。"
)
```

#### セルフホストエンドポイント（TGI/vLLM）

```python
from google.adk.agents import Agent
from google.adk.models.lite_llm import LiteLlm
import os

selfhosted_agent = Agent(
    name="custom_model",
    model=LiteLlm(
        model=os.getenv("SELF_HOSTED_MODEL_NAME", "custom/my-model"),
        api_base=os.getenv("SELF_HOSTED_API_BASE", "http://localhost:8000/v1"),
        api_key=os.getenv("SELF_HOSTED_API_KEY", "dummy")
    ),
    instruction="セルフホストLLMを使用するアシスタントです。"
)
```

**LiteLlmの推奨場面:**
- 複数のLLMプロバイダーを統一的に扱いたい場合
- プロバイダーに依存しないポータブルなAgent設計
- ローカル開発でのOllama活用
- コスト比較のためのA/Bテスト

---

### Anthropic Claude（Vertex AI Model Garden経由）

ADKはVertex AI Model GardenのClaude等のモデルをサポートします。

**前提条件:**
```bash
pip install anthropic
export GOOGLE_CLOUD_PROJECT="your-project"
export GOOGLE_CLOUD_LOCATION="us-central1"
```

```python
from google.adk.agents import Agent
from google.adk.models.anthropic_llm import Claude
from google.adk.models.registry import LLMRegistry
import os

# ClaudeをLLM Registryに登録（初回のみ）
LLMRegistry.register(Claude)

claude_agent = Agent(
    name="claude_assistant",
    model="claude-sonnet-4@20250514",  # Vertex AI上のモデルID
    instruction=(
        "Claudeを使用する高度なアシスタントです。"
        "複雑な推論と長文生成に優れています。"
    )
)
```

**Vertex AI上のClaudeモデルID形式:**
- `claude-sonnet-4@20250514`
- `claude-3-opus@20240229`
- 最新IDはVertex AIドキュメントで確認すること

---

### LlmRequestとLlmResponseの構造

**LlmRequest（LLMへの入力）:**

| フィールド | 説明 |
|-----------|------|
| `model` | モデル識別子 |
| `contents` | 会話履歴（Contentオブジェクトのリスト） |
| `config.system_instruction` | コンパイル済みシステムプロンプト |
| `config.tools` | 利用可能なツールのFunctionDeclarationリスト |
| `config.temperature` | 生成の確率的多様性（0.0-1.0） |
| `config.max_output_tokens` | 最大出力トークン数 |
| `config.response_schema` | 構造化JSONレスポンスのスキーマ |

**LlmResponse（LLMからの出力）:**

| フィールド | 説明 |
|-----------|------|
| `content` | メインペイロード（テキスト/ツール呼び出し） |
| `partial` | trueの場合、ストリーミングチャンク |
| `usage_metadata` | トークン使用量（prompt/candidates/total） |
| `grounding_metadata` | グラウンディング情報 |
| `error_code` / `error_message` | エラー情報 |

---

## 3. Geminiモデルの特性と選択

書籍「Mastering Google ADK」（Chapter 5）の知識を統合した詳細比較です。

### Geminiモデルファミリー比較テーブル

| モデル | コンテキスト長 | 速度 | コスト | ビジョン | 主な用途 |
|--------|-------------|------|--------|---------|---------|
| **gemini-1.5-flash** | 約1M tokens | 最高速 | 最低 | 対応 | 軽量タスク、チャットボット、高頻度推論 |
| **gemini-1.5-pro** | 約1M tokens | 速い | 中 | 対応 | 汎用、ドキュメント分析、中規模ワークフロー |
| **gemini-2.0-flash** | 長大 | 高速 | 低〜中 | 強化対応 | BuiltInコード実行、ツール呼び出し精度向上 |
| **gemini-2.0-pro** | 長大 | 中 | 高 | 強化対応 | 高精度タスク、複雑推論 |
| **gemini-2.5-pro** | 約1M tokens | 中 | 最高 | 強化対応+改良パーシング | 文書集約型エージェント、長期プランニング |
| **gemini-2.5-flash** | 長大 | 高速 | 中 | 対応 | 思考機能付き効率実行 |

**選択の指針（コスト/速度/精度トレードオフ）:**

```
シンプルなQ&A / チャット
    → gemini-1.5-flash（最低コスト、最高速）

汎用Agent / 標準ワークフロー
    → gemini-1.5-pro / gemini-2.0-flash

大規模文書処理 / 高精度ツール呼び出し
    → gemini-2.5-pro

コード実行を伴うAgent
    → gemini-2.0-flash（BuiltInCodeExecutor対応）

思考・計画が必要な複雑タスク
    → gemini-2.5-flash（thinking_config対応）
    → gemini-2.0-flash-thinking-exp（PlanReActPlanner用）
```

---

### モデルバージョン別特性詳細

#### Gemini 1.5シリーズ
- **長大なコンテキスト（1M tokens）**: 大量の文書や会話履歴を一度に処理可能
- **マルチモーダル**: テキスト、画像、音声、動画入力に対応
- **ツール呼び出し**: Function Callingで構造化ツール実行
- **開発推奨**: 1.5-proでプロトタイプ開発、完成後に最適化

#### Gemini 2.0シリーズ
- **コード実行強化**: `BuiltInCodeExecutor`との親和性が高い
- **ツール呼び出し精度向上**: より正確なFunction Call判断
- **マルチモーダル強化**: Vision処理の改良
- **生産性**: Flash系はコスト効率が大幅に改善

#### Gemini 2.5シリーズ（最新世代）
- **超長コンテキスト**: 複数の大規模文書を同時処理
- **高度な推論**: 複雑なマルチステップ問題解決
- **思考機能**: `ThinkingConfig`での内部推論の可視化
- **Vision改良パーシング**: 文書・図表の高精度解析
- **高コスト注意**: 本番では適切なユースケースに限定使用

---

### 生成パラメータ最適化

書籍「Mastering Google ADK」（Chapter 11.5）の知識より:

```python
from google.adk.agents import Agent
from google.genai.types import GenerateContentConfig

# タスク別の推奨パラメータ
TOOL_AND_RAG_CONFIG = GenerateContentConfig(
    temperature=0.2,    # 決定論的（ツール選択・RAG）
    top_p=0.9,
    max_output_tokens=2048
)

CREATIVE_CONFIG = GenerateContentConfig(
    temperature=0.7,    # 探索的（要約・アイデア生成）
    top_p=0.95,
    max_output_tokens=4096
)

ANALYTICAL_CONFIG = GenerateContentConfig(
    temperature=0.3,    # バランス型（分析・レポート）
    top_p=0.9,
    max_output_tokens=8192
)

analytical_agent = Agent(
    name="analyst",
    model="gemini-2.0-flash",
    instruction="詳細なデータ分析を行うアシスタントです。",
    generate_content_config=ANALYTICAL_CONFIG
)
```

**パラメータガイドライン:**

| パラメータ | 低値（0.2-0.4） | 高値（0.6-0.8） |
|-----------|--------------|--------------|
| temperature | 決定論的、一貫性高 | 創造的、多様性高 |
| top_p | 安全な選択肢に集中 | より広い語彙から選択 |

---

## 4. Gemini固有機能

### 4-1. マルチモーダル入力（Vision Capabilities）

書籍「Mastering Google ADK」（Chapter 5.2, 5.5）の知識を統合:

Geminiモデルはテキスト・画像・PDFを統合して処理できます。
ADKでは`Content.parts`に複数のモダリティを混在させることが可能です。

**ADK標準API経由の画像入力:**
```python
from google.adk.agents import Agent
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
from pathlib import Path

def load_image_as_part(image_path: str) -> Part:
    image_bytes = Path(image_path).read_bytes()
    return Part.from_bytes(
        data=image_bytes,
        mime_type="image/png"
    )

vision_agent = Agent(
    name="vision_analyst",
    model="gemini-2.0-flash",
    instruction=(
        "画像・図表・ドキュメントを分析するアシスタントです。"
        "視覚的な情報を正確に解析し、構造化された洞察を提供します。"
    )
)

runner = InMemoryRunner(agent=vision_agent, app_name="VisionApp")

async def analyze_image(image_path: str, question: str):
    image_part = load_image_as_part(image_path)
    text_part = Part(text=question)

    user_message = Content(parts=[image_part, text_part], role="user")

    async for event in runner.run_async(
        user_id="user1", session_id="s1", new_message=user_message
    ):
        if event.content and event.content.parts:
            for part in event.content.parts:
                if part.text:
                    print(part.text, end="", flush=True)

import asyncio
asyncio.run(analyze_image("architecture_diagram.png", "このアーキテクチャ図を説明してください"))
```

**PDF・構造化データの埋め込み:**
```python
import fitz  # PyMuPDF: pip install pymupdf
import pandas as pd
from google.genai.types import Content, Part

def extract_pdf_text(pdf_path: str, max_chars: int = 50000) -> str:
    """PDFからテキストを抽出（トークン制限に注意）"""
    doc = fitz.open(pdf_path)
    text = "\n".join([page.get_text() for page in doc])
    return text[:max_chars]

def csv_to_markdown(csv_path: str, max_rows: int = 20) -> str:
    """CSVをMarkdownテーブル形式に変換"""
    df = pd.read_csv(csv_path)
    return df.head(max_rows).to_markdown(index=False)

pdf_content = extract_pdf_text("annual_report.pdf")
csv_content = csv_to_markdown("financial_data.csv")

combined_context = f"""
## 年次報告書（抜粋）
{pdf_content}

## 財務データ
{csv_content}
"""

user_message = Content(
    parts=[Part(text=f"{combined_context}\n\nこのデータから主要な財務トレンドを分析してください")],
    role="user"
)
```

**マルチモーダルのベストプラクティス:**

| ベストプラクティス | 理由 |
|----------------|------|
| 関連する画像部分のみを渡す（クロップ） | モデルの注意を集中させる |
| 解像度を適切に調整する | 過大なトークン消費を防ぐ |
| PDFは関連ページのみ抽出する | コンテキスト長の効率化 |
| 構造化データはMarkdownテーブルで渡す | LLMの理解精度が向上 |
| PDFの表・グラフは画像+テキストを組み合わせる | 読み取り精度向上 |

---

### 4-2. ストリーミング出力

会話型Agentではストリーミングが不可欠です。ストリーミングにより、
LLMが生成中にトークンを順次ユーザーに配信でき、体感レスポンス速度が大幅に向上します。

```python
from google.adk.agents import Agent
from google.adk.runners import InMemoryRunner, RunConfig
from google.adk.agents.run_config import StreamingMode
from google.genai.types import Content, Part
import asyncio

streaming_agent = Agent(
    name="streaming_writer",
    model="gemini-2.0-flash",
    instruction="ユーザーの質問に詳細かつ丁寧に回答するアシスタントです。"
)

runner = InMemoryRunner(agent=streaming_agent, app_name="StreamApp")

async def run_with_streaming(question: str):
    user_message = Content(parts=[Part(text=question)], role="user")

    run_config = RunConfig(streaming_mode=StreamingMode.SSE)

    print("Agent: ", end="", flush=True)
    async for event in runner.run_async(
        user_id="user1", session_id="s1",
        new_message=user_message, run_config=run_config
    ):
        if event.content and event.content.parts:
            for part in event.content.parts:
                if part.text:
                    print(part.text, end="", flush=True)
    print()

asyncio.run(run_with_streaming("日本のAI産業の現状と展望を詳しく教えてください"))
```

**StreamingModeオプション:**
- `StreamingMode.NONE`: ストリーミング無効（デフォルト）
- `StreamingMode.SSE`: Server-Sent Events形式でストリーミング
- `StreamingMode.BIDI`: 双方向ストリーミング（実験的）

**ストリーミングが特に有効な場面:**
- 長文生成（レポート、文章作成）
- チャットUI、CLIインターフェース
- リアルタイム翻訳・要約
- ユーザー待ち時間の短縮が重要な場面

---

## 5. Flows & Planners

### BaseLlmFlow概念

LLM Flow（`BaseLlmFlow`）はLlmAgentが1ターンの相互作用中に実行する操作シーケンスを定義します。

**組み込みFlowの種類:**
- **`SingleFlow`**: サブAgentなしのシンプルなAgent用デフォルト
- **`AutoFlow`**: `SingleFlow`を継承し、Agent間転送機能を追加

**主要なリクエストプロセッサー（実行順）:**
1. `basic.request_processor` - 基本フィールド設定
2. `instructions.request_processor` - システムプロンプト設定
3. `identity.request_processor` - Agent名・説明をLLMに伝える
4. `contents.request_processor` - 会話履歴構築
5. `_nl_planning.request_processor` - Planner使用時の追加指示
6. `_code_execution.request_processor` - Code Executor使用時の処理
7. `agent_transfer.request_processor` - AutoFlow用転送ロジック

---

### 5-1. BuiltInPlanner（モデルネイティブ計画機能）

Gemini 2.0/2.5の「思考（Thinking）」機能を活用するPlannerです。
LLM自身が内部的に思考プロセスを持ち、より質の高い推論を行います。

```python
from google.adk.agents import Agent
from google.adk.planners import BuiltInPlanner
from google.genai.types import ThinkingConfig
from google.adk.tools import FunctionTool

def get_stock_price(ticker: str) -> dict:
    """株価情報を取得します。"""
    mock_prices = {"GOOG": 175.40, "MSFT": 420.50, "AAPL": 185.30}
    return {
        "ticker": ticker,
        "price": mock_prices.get(ticker, 0),
        "currency": "USD"
    }

stock_tool = FunctionTool(func=get_stock_price)

thinking_agent = Agent(
    name="investment_analyst",
    model="gemini-2.5-flash",  # ThinkingConfigをサポートするモデル
    instruction=(
        "投資分析アシスタントです。株価情報を取得し、"
        "多角的な観点から投資判断の参考情報を提供します。"
        "段階的に考え、根拠を明示してください。"
    ),
    tools=[stock_tool],
    planner=BuiltInPlanner(
        thinking_config=ThinkingConfig(
            include_thoughts=True
        )
    )
)
```

**ThinkingConfigのパラメータ:**
- `include_thoughts=True`: 思考プロセスをEventのPartとして返す
- モデルが内部で推論ステップを実行し、より質の高い最終回答を生成

**推奨場面:**
- 対象モデルがネイティブ思考機能をサポートしている場合
- 最も簡単な方法（ThinkingConfigを設定するだけ）
- 内部推論をトレースで確認したい場合

---

### 5-2. PlanReActPlanner（明示的推論サイクル）

ReAct（Reason + Act）パラダイムを実装するPlannerです。
LLMに思考・行動・観察を明示的なタグで構造化させます。

**PlanReActのサイクル（書籍「Google ADK for Agentic AI」Chapter 6.1 CoT推論より）:**
```
PLANNING    → 全体計画の立案（ChainOfThought）
    ↓
REASONING   → 現在ステップの推論
    ↓
ACTION      → ツール呼び出し
    ↓
Observation → ツール結果の観察
    ↓
REPLANNING  → 必要に応じて再計画
    ↓
FINAL_ANSWER → ユーザーへの最終回答
```

```python
from google.adk.agents import Agent
from google.adk.planners import PlanReActPlanner
from google.adk.tools import FunctionTool
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part

def search_knowledge_base(query: str) -> str:
    """社内ナレッジベースを検索します。"""
    if "policy" in query.lower():
        return "HR001: 在宅勤務ポリシー - 週2回まで、上司承認が必要"
    if "budget" in query.lower():
        return "FIN003: 予算承認フロー - 50万円以上は部門長承認、200万円以上は役員承認"
    return "該当するドキュメントは見つかりませんでした。"

def create_approval_request(employee_id: str, request_type: str, details: str) -> str:
    """承認リクエストを作成します。"""
    return f"承認リクエスト作成完了 (ID: REQ-{employee_id}-001, タイプ: {request_type})"

knowledge_tool = FunctionTool(func=search_knowledge_base)
approval_tool = FunctionTool(func=create_approval_request)

react_agent = Agent(
    name="hr_support_agent",
    model="gemini-2.0-flash",
    instruction=(
        "HR支援アシスタントです。"
        "複雑なリクエストには必ず計画を立て、段階的に解決してください。"
        "各ステップで推論を明示し、ツールを活用して正確な情報を提供します。"
    ),
    tools=[knowledge_tool, approval_tool],
    planner=PlanReActPlanner()
)

runner = InMemoryRunner(agent=react_agent, app_name="HRApp")

async def main():
    user_message = Content(
        parts=[Part(text="在宅勤務を週3回に増やしたい。どのような手続きが必要ですか？")],
        role="user"
    )

    async for event in runner.run_async(
        user_id="emp001", session_id="hr_session", new_message=user_message
    ):
        if event.content and event.content.parts:
            for part in event.content.parts:
                is_thought = hasattr(part, 'thought') and part.thought
                if part.text and not is_thought:
                    print(part.text, end="")
                elif part.text and is_thought:
                    print(f"\n[思考]: {part.text.strip()}\n")
                elif part.function_call:
                    print(f"\n[ツール呼び出し]: {part.function_call.name}")

import asyncio
asyncio.run(main())
```

**PlanReActの適切な使用場面:**
- LLMの推論プロセスをTraceで可視化・検査したい場合
- ツール使用と観察を伴う順次的なステップに分解可能なタスク
- デバッグ時に推論の各ステップを追いたい場合

**注意点:**
- 詳細なプロンプト注入によりトークン消費が増加
- LLMがタグフォーマットを守れる程度の推論能力が必要
- 強力なモデル（Gemini 2.0以降）ほど安定動作

---

### 5-3. カスタムPlanner（特殊な計画ロジック）

`BasePlanner`を継承して、ドメイン固有の計画ロジックを実装できます。

```python
from google.adk.planners import BasePlanner
from google.adk.agents.callback_context import CallbackContext
from google.adk.models.llm_request import LlmRequest

class DomainSpecificPlanner(BasePlanner):
    """特定ドメイン向けカスタムPlanner"""

    def build_planning_instruction(
        self,
        callback_context: CallbackContext,
        llm_request: LlmRequest
    ) -> str | None:
        """計画用システムプロンプトを生成"""
        domain = callback_context.state.get("domain", "general")

        if domain == "finance":
            return (
                "金融分析エージェントとして行動します。\n"
                "1. まずデータソースを特定してください\n"
                "2. リスク評価を実施してください\n"
                "3. 規制コンプライアンスを確認してください\n"
                "4. 結論を提示してください"
            )
        return None  # Noneを返すとデフォルト動作

    def process_planning_response(
        self,
        callback_context: CallbackContext,
        response_parts: list
    ) -> list | None:
        """LLMレスポンスから計画関連部分を処理"""
        return response_parts
```

---

### Planner選択基準テーブル

| Planner | 使用場面 | LLM要件 | 推論の透明性 | 実装コスト |
|---------|---------|---------|-------------|-----------|
| **なし** | シンプルなQ&A、単発タスク | 低 | なし | ゼロ |
| **BuiltInPlanner** | 対象LLMがネイティブ思考機能対応 | 高（ThinkingConfig対応必須） | モデル依存 | 低 |
| **PlanReActPlanner** | 明示的ステップバイステップ推論 | 中〜高（タグ追従能力） | 高（Traceで可視化） | 中 |
| **カスタムPlanner** | ドメイン固有の計画ロジック | - | カスタマイズ可能 | 高 |

---

## 6. Output Schema（構造化出力）

LLMの出力を特定のJSONスキーマに従わせることで、
後処理や他システムとの連携を確実にします。

### Pydanticモデルによる出力スキーマ定義

```python
from google.adk.agents import Agent
from pydantic import BaseModel, Field
from typing import Optional

class SentimentAnalysisResult(BaseModel):
    """感情分析の構造化出力"""
    sentiment: str = Field(
        description="感情ラベル: positive / negative / neutral"
    )
    confidence: float = Field(
        description="確信度（0.0から1.0）",
        ge=0.0,
        le=1.0
    )
    key_phrases: list[str] = Field(
        description="感情を示す主要フレーズのリスト"
    )
    summary: str = Field(
        description="感情分析の簡潔な説明"
    )
    suggestions: Optional[list[str]] = Field(
        default=None,
        description="改善提案（negativeの場合のみ）"
    )

sentiment_agent = Agent(
    name="sentiment_analyzer",
    model="gemini-2.0-flash",
    instruction=(
        "テキストの感情分析を行うアシスタントです。"
        "必ず指定されたJSONスキーマ形式で回答してください。"
    ),
    output_schema=SentimentAnalysisResult
)
```

### 複雑なネストされたスキーマ

```python
from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum

class Priority(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"

class TaskItem(BaseModel):
    title: str
    priority: Priority
    estimated_hours: float
    dependencies: list[str] = Field(default_factory=list)

class ProjectPlan(BaseModel):
    """プロジェクト計画の構造化出力"""
    project_name: str
    total_estimated_hours: float
    tasks: list[TaskItem]
    risks: list[str]
    success_metrics: list[str]
    recommended_team_size: int

planner_agent = Agent(
    name="project_planner",
    model="gemini-2.5-pro",  # 複雑な構造化出力には高精度モデルを推奨
    instruction=(
        "プロジェクト計画を作成するアシスタントです。"
        "詳細で実行可能な計画を指定のJSON形式で提供してください。"
    ),
    output_schema=ProjectPlan
)
```

**Output Schemaのベストプラクティス:**

| ベストプラクティス | 詳細 |
|----------------|------|
| Fieldに明確なdescriptionを付ける | モデルが各フィールドの意図を正確に理解できる |
| Enumで選択肢を制限する | 有効な値のみ出力されることを保証 |
| 必須/オプションを明確に | Optional型で柔軟なスキーマを設計 |
| 過度に複雑なネストを避ける | 深いネストはモデルの追従精度を下げる |
| 高精度モデルを使用する | 構造化出力の遵守能力は上位モデルほど高い |

---

## 7. InstructionProvider（動的instruction生成）

セッション状態やユーザー情報に基づいて、実行時に動的にinstructionを生成するパターンです。

### 関数ベースのInstructionProvider

```python
from google.adk.agents import Agent
from google.adk.agents.callback_context import CallbackContext

def dynamic_instruction(callback_context: CallbackContext) -> str:
    """セッション状態に基づいて動的にinstructionを生成"""
    state = callback_context.state

    user_role = state.get("user_role", "general")
    user_name = state.get("user_name", "ユーザー")
    language = state.get("preferred_language", "ja")

    base_instruction = f"あなたは{user_name}さんをサポートするアシスタントです。"

    role_specific = {
        "developer": (
            "技術的な詳細、コード例、APIドキュメントを優先して提供してください。"
            "エラーメッセージの診断や最適化の提案も積極的に行ってください。"
        ),
        "manager": (
            "ビジネス上の影響と意思決定に焦点を当てた要約を提供してください。"
            "技術的な詳細は必要に応じて簡潔に説明してください。"
        ),
        "general": "専門用語を避け、わかりやすい言葉で回答してください。"
    }.get(user_role, "")

    language_instruction = {
        "en": "Please respond in English.",
        "ja": "日本語で回答してください。",
        "zh": "请用中文回答。"
    }.get(language, "日本語で回答してください。")

    return f"{base_instruction} {role_specific} {language_instruction}"

adaptive_agent = Agent(
    name="adaptive_assistant",
    model="gemini-2.0-flash",
    instruction=dynamic_instruction  # 文字列の代わりに関数を渡す
)
```

### コンテキスト依存型の高度な動的instruction

```python
from datetime import datetime
from google.adk.agents import Agent
from google.adk.agents.callback_context import CallbackContext

def context_aware_instruction(callback_context: CallbackContext) -> str:
    """実行時のコンテキストに完全適応したinstruction"""
    state = callback_context.state

    turn_count = state.get("turn_count", 0)
    conversation_topic = state.get("detected_topic", "general")
    urgent_flag = state.get("is_urgent", False)

    current_hour = datetime.now().hour
    time_context = (
        "朝の業務開始時間帯です。簡潔で要点を抑えた回答を優先してください。"
        if 8 <= current_hour <= 10
        else "業務時間内です。詳細な説明を提供してください。"
    )

    depth_context = (
        "初めての質問です。基本的な説明から始めてください。"
        if turn_count == 0
        else f"会話{turn_count}ターン目です。前の会話を踏まえて回答してください。"
    )

    urgent_context = (
        "緊急対応が必要です。最重要情報を最初に提示してください。"
        if urgent_flag
        else ""
    )

    return f"""あなたは高度な業務支援アシスタントです。
{time_context}
{depth_context}
{urgent_context}
トピック「{conversation_topic}」に関連する専門知識を積極的に活用してください。""".strip()

intelligent_agent = Agent(
    name="context_adaptive_agent",
    model="gemini-2.0-flash",
    instruction=context_aware_instruction
)
```

**InstructionProviderのユースケース:**

| ユースケース | 動的要素 | 効果 |
|------------|---------|------|
| 多言語サポート | ユーザーの言語設定 | 言語切り替えが自動化 |
| 役割ベース動作 | ユーザーロール・権限 | 情報の開示範囲を制御 |
| タスク特化 | 検出されたタスクタイプ | 適切な専門知識を提供 |
| 会話状態適応 | 会話ターン数・トピック | 段階的に詳細化 |
| 時間帯・コンテキスト | 現在時刻・緊急度 | 状況に応じた応答スタイル |

---

## 8. モデル切り替えパターン

### パターン1: タスク複雑度によるモデル選択

書籍「Google ADK for Agentic AI」の Worker/Coordinator パターンを応用:

```python
from google.adk.agents import Agent

# 軽量・高速Agentはシンプルタスク担当
lightweight_agent = Agent(
    name="fast_agent",
    model="gemini-1.5-flash",  # 高速・低コスト
    instruction="シンプルなタスクを素早く処理します。簡潔に回答してください。"
)

# 高精度Agentは複雑タスク担当
powerful_agent = Agent(
    name="precise_agent",
    model="gemini-2.5-pro",  # 高精度・高コスト
    instruction="複雑な分析・計画タスクを詳細に処理します。根拠を明示してください。"
)

# ルーティングAgentがタスクを振り分ける（Worker/Coordinatorパターン）
routing_agent = Agent(
    name="task_router",
    model="gemini-2.0-flash",
    instruction=(
        "タスクを分析し、適切なサブエージェントに委譲します。\n"
        "- シンプルな質問・変換・説明 → fast_agent\n"
        "- 複雑な分析・計画・比較検討 → precise_agent"
    ),
    sub_agents=[lightweight_agent, powerful_agent]
)
```

### パターン2: 環境別モデル切り替え

```python
import os
from google.adk.agents import Agent

def get_model_for_environment() -> str:
    """環境変数に基づいてモデルを選択"""
    env = os.getenv("APP_ENV", "development")
    model_override = os.getenv("LLM_MODEL_OVERRIDE")

    if model_override:
        return model_override  # 明示的な上書き

    MODEL_MAP = {
        "development": "gemini-1.5-flash",    # 開発：低コスト高速
        "staging": "gemini-2.0-flash",         # ステージング：本番相当
        "production": "gemini-2.0-flash",      # 本番：バランス型
        "production-premium": "gemini-2.5-pro" # 本番プレミアム：最高精度
    }

    return MODEL_MAP.get(env, "gemini-2.0-flash")

env_adaptive_agent = Agent(
    name="env_adaptive_agent",
    model=get_model_for_environment(),
    instruction="環境に応じたモデルを使用するアシスタントです。"
)
```

### パターン3: フォールバック戦略

```python
from google.adk.agents import Agent
from google.adk.models.lite_llm import LiteLlm
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import asyncio
import logging

logger = logging.getLogger(__name__)

async def run_with_fallback(question: str) -> str:
    """プライマリモデル失敗時にフォールバックするAgent実行"""
    user_message = Content(parts=[Part(text=question)], role="user")

    # フォールバックチェーン: Gemini 2.5 Pro → Gemini 2.0 Flash → GPT-4o
    fallback_configs = [
        ("primary", "gemini-2.5-pro"),
        ("fallback", "gemini-2.0-flash"),
        ("emergency", LiteLlm(model="openai/gpt-4o")),
    ]

    for agent_name, model in fallback_configs:
        try:
            agent = Agent(
                name=f"agent_{agent_name}",
                model=model,
                instruction="質問に回答してください。"
            )
            runner = InMemoryRunner(agent=agent, app_name=f"App_{agent_name}")
            result = []
            async for event in runner.run_async(
                user_id="u", session_id="s", new_message=user_message
            ):
                if event.content and event.content.parts:
                    for part in event.content.parts:
                        if part.text:
                            result.append(part.text)
            return "".join(result)
        except Exception as e:
            logger.warning(f"{agent_name}モデルでエラー: {e}。フォールバックします...")

    raise RuntimeError("すべてのモデルで失敗しました")

async def main():
    response = await run_with_fallback("機械学習の主要アルゴリズムを比較してください")
    print(response)

asyncio.run(main())
```

### パターン4: マルチモデル並列実行

```python
from google.adk.agents import Agent
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import asyncio

async def parallel_model_query(question: str) -> dict[str, str]:
    """複数モデルに並列でクエリし、結果を比較"""
    models = {
        "gemini-flash": "gemini-2.0-flash",
        "gemini-pro": "gemini-2.0-pro",
    }

    async def query_model(model_name: str, model_id: str) -> tuple[str, str]:
        agent = Agent(
            name=f"agent_{model_name}",
            model=model_id,
            instruction="与えられた質問に回答してください。"
        )
        runner = InMemoryRunner(agent=agent, app_name=f"App_{model_name}")
        user_message = Content(parts=[Part(text=question)], role="user")
        result = []
        async for event in runner.run_async(
            user_id="u", session_id="s", new_message=user_message
        ):
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if part.text:
                        result.append(part.text)
        return model_name, "".join(result)

    results = await asyncio.gather(
        *[query_model(name, model_id) for name, model_id in models.items()],
        return_exceptions=True
    )

    return {name: result for name, result in results if isinstance(result, tuple)}

async def main():
    responses = await parallel_model_query("量子コンピューターの現在の課題を説明してください")
    for model, response in responses.items():
        print(f"\n=== {model} ===")
        print(response[:200])

asyncio.run(main())
```

---

## ベストプラクティスまとめ

### コード実行選択

| 状況 | 推奨Executor | 理由 |
|-----|------------|------|
| Gemini + コード計算タスク | `BuiltInCodeExecutor` | 最も簡単・安全 |
| 本番環境 + カスタムライブラリ | `ContainerCodeExecutor` | 高セキュリティ + 柔軟性 |
| クラウド本番 + 管理不要 | `VertexAiCodeExecutor` | フルマネージド |
| 開発・デバッグのみ | `UnsafeLocalCodeExecutor` | 高速・シンプル（本番禁止） |

### モデル選択

| 優先事項 | 推奨モデル |
|---------|-----------|
| 最低コスト | `gemini-1.5-flash` |
| 最高精度 | `gemini-2.5-pro` |
| バランス（本番標準） | `gemini-2.0-flash` |
| 長文書処理 | `gemini-2.5-pro` |
| 思考機能 | `gemini-2.5-flash` |
| マルチプロバイダー | `LiteLlm` |

### Planner選択

| 状況 | 推奨Planner |
|-----|-----------|
| シンプルなタスク | なし |
| 思考対応モデル使用 | `BuiltInPlanner` |
| 推論の透明性が必要 | `PlanReActPlanner` |
| ドメイン固有ロジック | カスタムPlanner |

---

## 関連リファレンス

- [MULTI-AGENT-PATTERNS.md](./MULTI-AGENT-PATTERNS.md) - マルチエージェントアーキテクチャ
- [SESSION-AND-STATE.md](./SESSION-AND-STATE.md) - セッション管理
- [TOOLS-AND-CALLBACKS.md](./TOOLS-AND-CALLBACKS.md) - ツールとコールバック
