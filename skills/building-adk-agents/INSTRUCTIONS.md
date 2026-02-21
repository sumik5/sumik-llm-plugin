# Google ADK (Agent Development Kit) 開発ガイド

## 概要

Google ADK (Agent Development Kit) は、インテリジェントなAIエージェントを構築するためのPython製コードファーストツールキットです。LangGraphなどの既存フレームワークと比較して、**モジュラー性**、**柔軟性**、**コードファースト設計**を重視し、ソフトウェアエンジニアリングの厳格さでエージェント開発に取り組みます。

### コアフィロソフィー

| 原則 | 説明 |
|------|------|
| **Code-first** | YAML/JSON設定ではなくPythonコードで直接定義 |
| **Modularity** | Agent、Tool、Runner、Serviceが疎結合で再利用可能 |
| **Flexibility** | ツール、LLM、プランナー、メモリ実装を自由に拡張可能 |

---

## ADK vs LangGraph

| 観点 | ADK | LangGraph |
|------|-----|-----------|
| **設計思想** | コードファースト、モジュラー | グラフベース、状態遷移重視 |
| **Agent定義** | Pythonクラス (BaseAgent/LlmAgent) | ノードとエッジのグラフ |
| **Tool統合** | BaseTool抽象化 + FunctionTool | ツールノード |
| **マルチAgent** | 親子階層 + Agent Transfer | サブグラフ |
| **LLM統合** | BaseLlm抽象化（Gemini/LiteLLM/Anthropic） | ChatModel抽象化（LangChain） |
| **状態管理** | Session + State (app/user/session/tempスコープ) | Graph State |
| **永続化** | SessionService/ArtifactService/MemoryService | Checkpointer |
| **実行環境** | Runner (InMemoryRunner/カスタム) | CompiledGraph.invoke() |
| **開発UI** | ADK Dev UI (adk web) | LangGraph Studio |
| **適用場面** | Pythonエンジニア向け、企業システム統合 | 複雑な状態遷移、研究プロトタイプ |

---

## ADKアーキテクチャ概要

### コンポーネント関係図

```
Runner
  ├─ root_agent (BaseAgent / LlmAgent)
  │    ├─ model (BaseLlm: Gemini/LiteLLM/Anthropic)
  │    ├─ instruction (str / InstructionProvider)
  │    ├─ tools (list[BaseTool / BaseToolset])
  │    ├─ planner (BasePlanner: BuiltInPlanner/PlanReAct)
  │    └─ sub_agents (list[BaseAgent])
  │
  ├─ SessionService (Session管理: InMemory/Database/VertexAI)
  ├─ ArtifactService (ファイル管理: InMemory/GCS)
  └─ MemoryService (長期記憶: InMemory/VertexAI RAG)

InvocationContext (1ターンのコンテキスト)
  ├─ Session (events, state)
  ├─ CallbackContext (コールバック用)
  └─ ToolContext (ツール実行用)
```

### 主要コンポーネント

| コンポーネント | 説明 | 実装例 |
|--------------|------|--------|
| **Agent** | エージェントの抽象化 | `BaseAgent`, `LlmAgent`, `SequentialAgent`, `ParallelAgent` |
| **Runner** | エージェント実行エンジン | `Runner`, `InMemoryRunner` |
| **Tool** | エージェントが使用する機能 | `BaseTool`, `FunctionTool`, `OpenAPIToolset` |
| **Model** | LLM抽象化 | `BaseLlm`, `Gemini`, `LiteLlm`, `AnthropicLlm` |
| **Session** | 会話セッション管理 | `Session`, `BaseSessionService` |
| **Event** | エージェント実行ログ | `Event`, `EventActions` |
| **Context** | 実行コンテキスト | `InvocationContext`, `CallbackContext`, `ToolContext` |
| **Artifact** | ファイル管理 | `BaseArtifactService`, `InMemoryArtifactService`, `GcsArtifactService` |
| **Memory** | 長期記憶 | `BaseMemoryService`, `InMemoryMemoryService`, `VertexAiRagMemoryService` |

---

## クイックスタート

### 最小構成のAgent

```python
from google.adk.agents import Agent
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part

# Agent定義
agent = Agent(
    name="simple_assistant",
    model="gemini-2.0-flash",
    instruction="あなたは親切なアシスタントです。",
    description="基本的な質問応答Agent"
)

# Runner初期化
runner = InMemoryRunner(agent=agent, app_name="MyApp")

# 実行
user_message = Content(parts=[Part(text="こんにちは")])
for event in runner.run(
    user_id="user1",
    session_id="session1",
    new_message=user_message
):
    if event.content and event.content.parts:
        for part in event.content.parts:
            if part.text:
                print(part.text, end="")
```

---

## コア概念の判断基準

### 1. Agent種類の選択

| Agent種類 | 使用タイミング | 特徴 |
|-----------|--------------|------|
| **LlmAgent** | 単一LLMベースのAgent | instruction + tools + planner |
| **SequentialAgent** | サブAgentを順次実行 | パイプライン処理 |
| **ParallelAgent** | サブAgentを並列実行 | アンサンブル、並行タスク |
| **LoopAgent** | サブAgentを繰り返し実行 | 再試行、反復タスク |
| **BaseAgent** | カスタムAgent実装 | 独自ロジック |

**判断基準:**
- 単一タスク → `LlmAgent`
- 複数タスクを順番に → `SequentialAgent`
- 複数タスクを同時に → `ParallelAgent`
- 条件付き繰り返し → `LoopAgent`
- 独自制御フロー → `BaseAgent`のサブクラス

### 2. Tool種類の選択

| Tool種類 | 使用タイミング | 実装方法 |
|----------|--------------|---------|
| **FunctionTool** | カスタムPython関数 | `FunctionTool(func=my_function)` |
| **OpenAPIToolset** | REST API (OpenAPI仕様) | `OpenAPIToolset(spec_str=spec)` |
| **MCPToolset** | MCP (Model Context Protocol) | `MCPToolset(...)` |
| **Pre-built Tools** | Google Search、Memory、Artifact | `google_search`, `load_memory` |

**判断基準:**
- Python関数を公開 → `FunctionTool`
- 外部REST API → `OpenAPIToolset` (OpenAPI仕様がある場合)
- 企業システム統合 → `ApplicationIntegrationToolset`
- Google検索 → `google_search`
- セッション間の記憶 → `LoadMemoryTool` / `PreloadMemoryTool`

### 3. SessionService選択

| SessionService | 使用タイミング | 永続化 |
|----------------|--------------|--------|
| **InMemorySessionService** | ローカル開発、テスト | ❌ (プロセス終了で消失) |
| **DatabaseSessionService** | 本番環境、永続化必要 | ✅ (MySQL/PostgreSQL) |
| **VertexAiSessionService** | Google Cloud環境 | ✅ (Vertex AI管理) |

**判断基準:**
- プロトタイプ/テスト → `InMemorySessionService` (InMemoryRunner)
- 本番環境 → `DatabaseSessionService` または `VertexAiSessionService`

### 4. MemoryService選択

| MemoryService | 使用タイミング | 検索方式 |
|---------------|--------------|---------|
| **InMemoryMemoryService** | 開発/テスト | キーワード検索 |
| **VertexAiRagMemoryService** | 本番環境、セマンティック検索 | Vertex AI RAG |

**判断基準:**
- 簡易テスト → `InMemoryMemoryService`
- 本番環境、大量データ → `VertexAiRagMemoryService`

### 5. CodeExecutor選択

| CodeExecutor | 使用タイミング | セキュリティ |
|--------------|--------------|------------|
| **BuiltInCodeExecutor** | LLMネイティブ機能 | ✅ モデル管理 |
| **UnsafeLocalCodeExecutor** | 開発環境、信頼できるコード | ❌ サンドボックスなし |
| **ContainerCodeExecutor** | 本番環境、隔離実行 | ✅ Docker隔離 |
| **VertexAiCodeExecutor** | Google Cloud、マネージド実行 | ✅ クラウドネイティブ |

**判断基準:**
- 開発専用 → `UnsafeLocalCodeExecutor`
- 本番環境 → `ContainerCodeExecutor` または `VertexAiCodeExecutor`
- モデルに任せる → `BuiltInCodeExecutor`

---

## 環境構築

### インストール

```bash
# 安定版 (推奨)
pip install google-adk

# 開発版 (最新機能)
pip install git+https://github.com/google/adk-python.git@main
```

### ADK CLI概要

| コマンド | 説明 |
|---------|------|
| `adk create <name>` | 新規Agentプロジェクト生成 |
| `adk run <agent_path>` | CLIでAgent実行 |
| `adk web <agent_path>` | 開発UI起動 (http://127.0.0.1:8000) |
| `adk eval <agent_path> <evalset>` | Agent評価実行 |
| `adk deploy cloud_run <agent_path>` | Cloud Runデプロイ |
| `adk api_server [agents_dir]` | FastAPIサーバー起動 |

**推奨ワークフロー:**

1. `adk create my_agent` でプロジェクト作成
2. `agent.py` を編集
3. `adk web .` で開発UI起動
4. 動作確認後、`adk deploy` でデプロイ

---

## AskUserQuestion使用指示

以下の判断が必要な場合、**必ずAskUserQuestionツールでユーザーに確認**すること:

### モデル選択

```python
AskUserQuestion(
    questions=[{
        "question": "使用するLLMモデルを選択してください",
        "header": "モデル選択",
        "options": [
            {"label": "Gemini 2.0 Flash", "description": "高速、低コスト（推奨）"},
            {"label": "Gemini 1.5 Pro", "description": "高精度、長文対応"},
            {"label": "OpenAI GPT-4", "description": "LiteLLM経由"},
            {"label": "その他", "description": "カスタムモデル"}
        ],
        "multiSelect": False
    }]
)
```

### デプロイ先選択

```python
AskUserQuestion(
    questions=[{
        "question": "デプロイ先を選択してください",
        "header": "デプロイ先",
        "options": [
            {"label": "Cloud Run", "description": "サーバーレス、自動スケール"},
            {"label": "Vertex AI Agent Engine", "description": "マネージド実行環境"},
            {"label": "ローカル環境", "description": "開発/テスト用"}
        ],
        "multiSelect": False
    }]
)
```

### SessionService選択

```python
AskUserQuestion(
    questions=[{
        "question": "セッション管理方式を選択してください",
        "header": "SessionService",
        "options": [
            {"label": "InMemory", "description": "開発/テスト用（永続化なし）"},
            {"label": "Database", "description": "MySQL/PostgreSQL永続化"},
            {"label": "Vertex AI", "description": "Google Cloud管理"}
        ],
        "multiSelect": False
    }]
)
```

---

## サブファイルへのリンク

### 詳細リファレンス

- **[AGENT-AND-TOOLS.md](references/AGENT-AND-TOOLS.md)**: Agent分類体系（Reactive/Deliberative/Goal-Oriented）、Agent種類詳細、Tool設計（FunctionTool/LongRunningFunctionTool/OpenAPI/MCP/Pre-built）、YAML Config、Action Confirmations、Tool Performance、ベストプラクティス
- **[MULTI-AGENT-AND-A2A.md](references/MULTI-AGENT-AND-A2A.md)**: マルチAgent設計パターン、A2Aプロトコル詳細（JSON-RPC/REST/Agent Cards/Scope Negotiation/HTTP/2 vs WebSocket）、Agent協調戦略、Human-in-the-Loop、スケーリングパターン
- **[RUNTIME-AND-STATE.md](references/RUNTIME-AND-STATE.md)**: Runner（ライフサイクル5段階）、Session管理、State管理（4スコープ）、Artifact、Memory（3層構造）、Context階層、Context Caching/Compaction、Session Rewind/Resume、Event System、Session Scaling、State Lifecycle
- **[RAG-AND-GROUNDING.md](references/RAG-AND-GROUNDING.md)**: RAGパイプライン、Corpus管理（CRUD/GCS/Drive連携）、チャンキング戦略（4方式）、Vector Search（パラメータ/チューニング）、Citations（引用管理）、Multi-Corpus Querying、Grounding 3方式、Agentic RAGパターン、Pre-built Tools、Plugin System（6ライフサイクルフック）、RAG最適化
- **[CODE-EXECUTION-AND-MODELS.md](references/CODE-EXECUTION-AND-MODELS.md)**: コード実行（4種Executor）、LLMモデル（Gemini 1.5/2.0/2.5/LiteLLM/Anthropic）、Vision capabilities、Flows & Planners、Output Schema、InstructionProvider、モデル切り替えパターン
- **[GUARDRAILS-AND-STREAMING.md](references/GUARDRAILS-AND-STREAMING.md)**: Callback 6種（before/after agent/model/tool）、CallbackContext、ガードレールパターン（多層防御/セマンティックフィルタリング）、PIIフィルタリング（日本語対応）、Plugin System統合（Callbacks vs Plugins判断基準）、SSEストリーミング（FastAPI統合）、Live API音声処理
- **[UI-INTEGRATION.md](references/UI-INTEGRATION.md)**: AG-UIプロトコル、CopilotKit+Next.js、Streamlit/Slack統合、Dialogflow CX統合、マルチモーダル画像、ADK Dev UI詳細、FastAPI統合、カスタムフロントエンド構築
- **[DEPLOYMENT-AND-OPERATIONS.md](references/DEPLOYMENT-AND-OPERATIONS.md)**: Cloud Run/Vertex AI Agent Engine/GKEデプロイ、CI/CDパイプライン（GitHub Actions/Cloud Build）、パフォーマンス最適化、コスト管理、テレメトリ/オブザーバビリティ、Cloud統合、本番運用パターン
- **[SECURITY-AND-GOVERNANCE.md](references/SECURITY-AND-GOVERNANCE.md)**: 脅威モデル（10種）、認証・認可（OAuth2/RBAC/A2A ID伝播）、認証ライフサイクル、Workload Identity、シークレット管理、プロンプトインジェクション対策、データプライバシー/PII、倫理的AI、Human-in-the-Loop、監査・コンプライアンス、セキュリティチェックリスト（40項目）

---

## 主要機能

### Agent & Tools
- **Agent分類体系**: Reactive/Deliberative/Goal-Oriented/Hybrid（詳細: [AGENT-AND-TOOLS.md](references/AGENT-AND-TOOLS.md)）
- **YAML Config**: agents.yamlによる宣言的Agent定義
- **Tool Performance**: async定義ツールの自動並列実行
- **Action Confirmations**: `require_confirmation=True`でツール実行前にユーザー確認

### Multi-Agent & A2A
- **A2Aプロトコル**: JSON-RPC/REST、Agent Cards、Scope Negotiation（詳細: [MULTI-AGENT-AND-A2A.md](references/MULTI-AGENT-AND-A2A.md)）
- **Agent協調戦略**: コーディネーター/デレゲーター/ワーカーパターン

### Runtime & State
- **Context Caching** (v1.15.0+): コスト削減のための大規模指示キャッシュ
- **Context Compaction** (v1.16.0+): イベント履歴の自動要約圧縮
- **Session Rewind** (v1.17.0+) / **Resume Agents** (v1.14.0+)
- **Event System**: 7種のイベントタイプ、EventActions

### RAG & Grounding
- **Agentic RAG**: Corpus管理、Vector Search、Citations、Multi-Corpus Querying
- **Grounding 3方式**: Google Search / Vertex AI Search / Agentic RAG
- **Plugin System**: BasePlugin + 6ライフサイクルフック（詳細: [GUARDRAILS-AND-STREAMING.md](references/GUARDRAILS-AND-STREAMING.md)）

### Deployment & Security
- **Vertex AI Agent Engine**: マネージド実行環境、バージョン管理
- **CI/CD**: GitHub Actions / Cloud Build統合
- **パフォーマンス/コスト最適化**: モデルティアリング、キャッシング戦略
- **セキュリティ**: Workload Identity、認証ライフサイクル、40項目チェックリスト（詳細: [SECURITY-AND-GOVERNANCE.md](references/SECURITY-AND-GOVERNANCE.md)）

---

## ベストプラクティス

### Agent設計

1. **明確な責務分離**: 1 Agent = 1タスク
2. **descriptionを詳細に**: マルチAgent時の選択精度向上
3. **環境変数で認証情報管理**: ハードコード禁止

### Tool設計

1. **明確なdocstring**: FunctionToolの記述がそのままLLMに渡される
2. **型ヒント必須**: `str`, `int`, `float`, `Literal`, Pydantic Model
3. **ToolContextで状態管理**: `tool_context.state`, `tool_context.save_artifact()`

### 開発フロー

1. **InMemoryRunnerで開発**: 高速イテレーション
2. **Dev UIでデバッグ**: Trace機能で詳細確認
3. **EvalSetで品質保証**: `adk eval` で自動評価
4. **本番前にSessionService変更**: DatabaseまたはVertexAI

---

## 関連リソース

- 公式ドキュメント: https://google.github.io/adk-docs/
- GitHub: https://github.com/google/adk-python
- サンプル: https://github.com/google/adk-samples
