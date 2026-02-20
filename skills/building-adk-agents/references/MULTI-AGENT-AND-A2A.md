# マルチAgent設計とA2Aプロトコル詳細リファレンス

複数のAI Agentが協調して複雑な問題を解決するマルチAgentシステム（MAS）の設計原則、Agent-to-Agent（A2A）プロトコルの詳細実装、ADKでの各種パターン実装について解説します。

---

## 1. マルチAgent設計原則

### 1.1 マルチAgentシステムを採用する理由

単体の強力なAgentではなく、複数のAgentを使う理由は以下の通りです。

| 理由 | 説明 |
|------|------|
| **モジュール性と専門化** | 各Agentが特定のドメイン・タスクの専門家になる（例: 調査Agent、データ分析Agent） |
| **スケーラビリティ** | 異なるAgentを独立実行でき、リソースの効率的利用が可能 |
| **堅牢性** | 1つのAgentが問題に遭遇しても、他の部分は動作を継続・適応可能 |
| **複雑さの管理** | 大きな問題を小さなサブ問題に分割し、個別Agentで対処 |
| **再利用性** | 専門化されたAgentを異なるマルチAgentアプリケーション間で再利用可能 |

### 1.2 設計時の重要考慮事項

| 考慮事項 | 説明 |
|---------|------|
| **Agent役割と責任** | 各Agentの担当範囲を明確に定義（単一責任原則） |
| **通信プロトコル** | Agent間での情報交換・タスク委譲の方法（ADKでは「Agent Transfer」、外部Agentでは「A2A」） |
| **調整戦略** | 全体ワークフローの管理方法（中央オーケストレーター、パイプライン、分散化等） |
| **知識共有** | Agent間でのコンテキスト・結果の共有方法（セッション状態、Artifact、メッセージ受け渡し） |
| **競合解決** | Agent間で目標や情報が競合した場合の解決方法 |
| **スキーマ一貫性** | 入出力形式の標準化（フィールド名の不一致はランタイムエラーの主要原因） |

---

## 2. ADKでのParent/Sub-Agent定義

### 2.1 階層的マルチAgentシステム

**特徴:**
- `LlmAgent` は `sub_agents` パラメータで子Agentを持てる
- 親Agentは子Agentにタスクを委譲可能
- 各子Agentは独自のモデル、指示、ツール、さらに子Agentを持てる（ネスト可能）

```python
from google.adk.agents import Agent

# 専門化された子Agent
research_agent = Agent(
    name="researcher",
    model="gemini-2.0-flash",
    instruction="調査専門家です。トピックについて検索ツールを使って関連情報を収集します。",
    description="トピックについて情報を検索します。"  # 親AgentのLLMが委譲判断する際に参照される
)

writer_agent = Agent(
    name="writer",
    model="gemini-2.0-flash",
    instruction="熟練したライターです。提供された情報を整合性のあるレポートにまとめます。",
    description="情報を基にサマリー・レポートを作成します。"
)

# 親/オーケストレーターAgent
report_orchestrator = Agent(
    name="report_orchestrator",
    model="gemini-2.5-flash-preview-05-20",
    instruction=(
        "調査レポートを作成するオーケストレーターです。"
        "まず 'researcher' Agentでユーザーのトピックについて情報収集し、"
        "次に 'writer' Agentに調査結果を渡して最終レポートを作成します。"
    ),
    description="調査とレポート作成を統括します。",
    sub_agents=[research_agent, writer_agent]
)
```

**description が重要な理由:**

> 親Agentが子Agentへのタスク委譲を決定する際、子Agentの `description` を参照します。明確で簡潔、かつ各子Agentの独自の能力と呼び出すべき状況を示す記述が必要です。

### 2.2 設計アンチパターン：汎用化しすぎたAgent

```python
# 悪い例: 責任範囲が広すぎる
def handle_request(inputs: dict, memory: dict) -> dict:
    if "problem" in inputs.get("query", ""):
        return {"action": "investigate_issue"}
    return {"action": "general_response"}

# 良い例: インテント駆動で明確に定義
def resolve_network_issue(inputs: dict, memory: dict) -> dict:
    previous_attempts = memory.get("network_diagnostics", 0)
    if previous_attempts >= 3:
        return {"action": "escalate_to_support"}
    memory["network_diagnostics"] = previous_attempts + 1
    return {"action": "run_diagnostics_check"}
```

ADKにおいて、Agentはインテント駆動で狭くスコープされた時に最も効果的に機能します。機能の拡張はAgentの合成（composition）を通じて行い、単一Agentのモノリス化は避けてください。

---

## 3. Agent Transfer（Agent間通信の基礎）

### 3.1 Agent Transferの仕組み

ADKにおけるAgent間の「通信」や委譲の主要メカニズムは **Agent Transfer**（制御の移譲）です。

**内部ツール `transfer_to_agent`:**
- ADKが内部的に提供する概念的ツール
- `sub_agents` を持つ `LlmAgent` のLLM Flowが自動的に利用可能にする
- 引数: `agent_name`（移譲先のAgent名）

**転送の実行フロー:**
1. オーケストレーターLLMが `transfer_to_agent(agent_name="target_agent")` を呼び出し
2. `AutoFlow` がこの呼び出しをインターセプト
3. `Runner` がターゲットAgentを特定
4. `Runner` がターゲットAgentの `run_async` を実行（現在の `InvocationContext` を渡す）
5. 会話がターゲットAgentでアクティブなまま継続

### 3.2 転送ループとデッドロック防止

**防止策:**
- 各Agentに明確で異なる責任を持たせる
- オーケストレーターの指示で転送条件を明確に定義
- 子Agentがタスク完了をシグナルする方法を明確化
- `RunConfig` の `max_llm_calls` をセーフティネットとして設定

---

## 4. 共通マルチAgentパターン

### 4.1 パターン選択基準テーブル

| パターン | 適用ケース | ADK実装 | 注意点 |
|---------|---------|---------|--------|
| **階層型（Coordinator-Worker）** | 明確な役割分担、専門化 | 親Agentに `sub_agents` を定義 | descriptionを明確に書く |
| **パイプライン型（Sequential）** | 順次処理、前ステップの出力を使用 | `SequentialAgent` または明示的委譲 | 状態共有のスキーマ統一 |
| **並列型（Ensemble）** | 複数視点、独立サブタスク | `ParallelAgent` または並列委譲 | リソース消費に注意 |
| **反復型（Loop）** | 反復的改善、リトライ、ポーリング | `LoopAgent` + `exit_loop` | 必ず `max_iterations` を設定 |
| **複雑な状態管理（LangGraph）** | 循環ロジック、長期実行 | `LangGraphAgent` | 実験的機能・互換性確認が必要 |

### 4.2 コーディネーター / デレゲーター / ワーカーの役割分担

マルチAgentシステムのスケーリングでは、3つの役割を明確に分離することが重要です。

**コーディネーター（Coordinator）:**
- ワークフロー全体の脳となる
- グローバルなコンテキストとメモリを管理
- タスク分解と委譲戦略を担当
- サブタスクの出力を統合して整合性のある応答を生成

**デレゲーター（Delegator）:**
- コーディネーターとワーカーの中間層
- コンテキストに基づいてインテリジェントなルーティングを行う
- 文書タイプや状況に応じて最適なワーカーを選択
- ビジネスロジックの変化を吸収し、ワーカーをシンプルに保つ

**ワーカー（Worker）:**
- 単一の明確に定義されたタスクを実行
- 可能な限りステートレス
- スキーマに厳密に準拠
- 容易に置き換え可能・テスト可能

```python
# デレゲーターの例: 文書タイプに応じて最適なサマライザーを選択
class SummaryRouterNode(FunctionNode):
    def run(self, inputs: dict, memory: dict, context: dict) -> dict:
        doc_type = inputs["doc_type"]
        text = inputs["text"]

        if doc_type == "legal":
            agent_url = "https://legal-summarizer-agent/run"
            intent = "summarize_legal"
        elif doc_type == "science":
            agent_url = "https://science-summarizer-agent/run"
            intent = "summarize_scientific"
        else:
            agent_url = "https://general-summarizer-agent/run"
            intent = "summarize_generic"

        result = self.call_agent(
            url=agent_url,
            payload={
                "intent": intent,
                "inputs": {"text": text},
                "context": context
            }
        )
        return {"summary": result["summary"]}
```

---

## 5. Shell Agents（オーケストレーション構造）

### 5.1 SequentialAgent: パイプラインワークフロー

**特徴:**
- `sub_agents` を定義された順序で順次実行
- 全会話履歴と状態が次の子Agentに引き継がれる

**用途:**
- 固定された一連のステップに分解されるタスク
- あるAgentの出力が次のAgentの直接入力またはコンテキストになる場合

```python
from google.adk.agents import Agent, SequentialAgent
from google.adk.tools import FunctionTool, ToolContext

def gather_user_data(name: str, email: str, tool_context: ToolContext) -> dict:
    """ユーザー名とメールを収集してセッション状態に保存"""
    tool_context.state["user_name_collected"] = name
    tool_context.state["user_email_collected"] = email
    return {"status": "success", "message": f"{name}のデータを収集しました"}

def validate_email_format(email: str, tool_context: ToolContext) -> dict:
    """メールアドレス形式を検証"""
    import re
    is_valid = bool(re.match(r'[\w.-]+@[\w.-]+\.\w+', email))
    tool_context.state["email_validated"] = is_valid
    return {"is_valid": is_valid, "email": email}

data_collection_agent = Agent(
    name="data_collector",
    model="gemini-2.0-flash",
    instruction="ユーザーの名前とメールアドレスを収集します。gather_user_dataツールを使用してください。",
    description="ユーザー名とメールアドレスを収集します。",
    tools=[FunctionTool(func=gather_user_data)]
)

email_validation_agent = Agent(
    name="email_validator",
    model="gemini-2.0-flash",
    instruction="state['user_email_collected']からメールアドレスを取得し、validate_email_formatで検証してください。",
    description="メールアドレス形式を検証します。",
    tools=[FunctionTool(func=validate_email_format)]
)

# SequentialAgentの定義
user_onboarding_pipeline = SequentialAgent(
    name="user_onboarding_orchestrator",
    description="新規ユーザーオンボーディングパイプライン",
    sub_agents=[data_collection_agent, email_validation_agent]
)
```

**ベストプラクティス:**

> SequentialAgent使用時は、各子Agentが期待する入力（多くは前のAgentが設定したセッション状態から）と出力（次のAgentのためにセッション状態を更新）を明確に定義してください。

### 5.2 ParallelAgent: 並行タスク実行

**特徴:**
- 全 `sub_agents` を同時実行
- 各子Agentは同じ初期 `InvocationContext`（セッション状態・履歴）を共有
- `event.branch` 属性でどの子Agentが生成したかを識別

**用途:**
- 同じ問題に対する複数の視点が必要
- 独立したサブタスクを同時実行してスループットを向上

```python
from google.adk.agents import Agent, ParallelAgent

sentiment_analyzer = Agent(
    name="sentiment_analyzer",
    model="gemini-2.0-flash",
    instruction="提供されたテキストの感情を分析してください。",
    description="テキスト感情を分析します。"
)

keyword_extractor = Agent(
    name="keyword_extractor",
    model="gemini-2.0-flash",
    instruction="提供されたテキストから主要なキーワードを最大3つ抽出してください。",
    description="テキストからキーワードを抽出します。"
)

text_analysis_parallel = ParallelAgent(
    name="parallel_text_analyzer",
    description="感情分析とキーワード抽出を並列実行します。",
    sub_agents=[sentiment_analyzer, keyword_extractor]
)
```

**注意点:**

> 多数の複雑な子Agentを並列実行すると、リソース（CPU、メモリ、LLM APIクオータ）を大量消費します。`event.branch` 属性を使って並列タスクの結果を正確に処理してください。

### 5.3 LoopAgent: 反復タスク/リトライ

**特徴:**
- `sub_agents` のリストを最大反復回数に達するか、終了条件をシグナルするまで繰り返し実行
- `exit_loop` ツール呼び出しで `tool_context.actions.escalate = True` が設定される

**用途:**
- 反復的な改善（生成 → 批評 → 改善）
- 失敗しやすい操作のリトライメカニズム
- 条件が満たされるまでのポーリング/待機

```python
from google.adk.agents import Agent, LoopAgent
from google.adk.tools import FunctionTool, ToolContext, exit_loop

def check_draft_quality(draft: str, tool_context: ToolContext) -> dict:
    """ドラフト品質をチェック。'final'が含まれるか3回反復でループ終了"""
    iteration = tool_context.state.get("loop_iteration", 0) + 1
    tool_context.state["loop_iteration"] = iteration
    tool_context.state["current_draft"] = draft

    if "final" in draft.lower() or iteration >= 3:
        exit_loop(tool_context)  # escalate=Trueを設定
        return {"quality": "good", "feedback": "完了", "action": "exit"}
    else:
        return {"quality": "poor", "feedback": "詳細を追加してください", "action": "refine"}

drafting_agent = Agent(
    name="draft_refiner",
    model="gemini-2.0-flash",
    instruction=(
        "ドキュメントをドラフト・改善します。"
        "check_draft_qualityツールで評価し、フィードバックを使って改善してください。"
    ),
    description="ドキュメントを反復的にドラフト・改善します。",
    tools=[FunctionTool(func=check_draft_quality)]
)

iterative_refinement_loop = LoopAgent(
    name="document_refinement_loop",
    description="品質基準が満たされるまでドキュメントを反復的に改善します。",
    sub_agents=[drafting_agent],
    max_iterations=5  # 必ずmax_iterationsを設定
)
```

### 5.4 SequentialAgent vs ParallelAgent vs LoopAgent 判断テーブル

| 要素 | SequentialAgent | ParallelAgent | LoopAgent |
|-----|----------------|--------------|-----------|
| **実行順序** | 固定・順次 | 同時並行 | 反復（条件満たすまで） |
| **子Agent間依存** | あり | なし（独立実行） | あり（反復中に状態更新） |
| **結果統合** | 最後の子Agentの出力がメイン | オーケストレーターが明示的に統合 | 終了条件満たした時点の出力 |
| **典型的用途** | データ処理パイプライン | アンサンブル、独立タスク | 反復改善、リトライ、ポーリング |
| **終了条件** | 全子Agent完了 | 全子Agent完了 | `exit_loop` または `max_iterations` |
| **状態共有** | 順次蓄積 | 初期状態を共有（分岐後は独立） | 反復ごとに状態更新 |

---

## 6. A2Aプロトコル詳細

### 6.1 A2Aの概要と目的

**A2A（Agent-to-Agent Communication Protocol）:**
- Google主導のオープン標準
- 独立したAI Agentシステム間でのシームレスな通信・相互運用を実現
- 異なるフレームワーク、異なる企業、異なるサーバーで構築されたAgentも連携可能

A2Aは単なる通信プロトコルではなく、エージェントエコシステム設計の根幹を成す仕様です。**Message Contract Protocol（MCP）** に基づく構造化された通信スキーマ、**Agent Cards** による能力宣言、**JSON-RPC 2.0** による軽量な内部委譲、**REST over HTTP** による外部連携の4つのレイヤーから構成されます。

**ADKとの関係:**
- ADKの主要マルチAgent機能は単一 `Runner` プロセス内での「Agent Transfer」
- A2A対応により、ADK AgentシステムをA2Aサーバーとして公開、または外部Agentをクライアントとして呼び出すことが可能
- LangGraph、CrewAI、Semantic Kernel等、他フレームワークのAgentとも連携できる

### 6.2 A2Aプロトコルの2つのトランスポート

#### JSON-RPC vs REST の選択

| 使用ケース | 推奨プロトコル |
|-----------|--------------|
| **Agent間の内部委譲** | JSON-RPC |
| **クロスドメイン・外部API公開** | REST |
| **非同期呼び出しチェーン** | JSON-RPC |
| **エンタープライズシステムへの公開エンドポイント** | REST |

JSON-RPCは同一信頼境界内のAgentへの直接的・低オーバーヘッドな関数呼び出しに最適化されています。RESTはクライアントアプリケーション、サードパーティサービス、ADKをネイティブに話せないマイクロサービスとの広範な統合パターンをサポートします。

#### JSON-RPCによる内部Agent委譲

JSON-RPCでAgentを呼び出す際のリクエスト形式：

```json
{
  "jsonrpc": "2.0",
  "method": "summarize_text",
  "params": {
    "inputs": {
      "text": "ADKシステムはAgentが効率的にタスクを委譲できるようにします..."
    },
    "memory": {
      "summary.length": "short"
    },
    "context": {
      "caller": "agent:research_planner",
      "timestamp": "2025-07-04T11:00:00Z",
      "request_id": "request-982731",
      "trace_id": "trace-3fb2b1"
    }
  },
  "id": "request-982731"
}
```

正常レスポンス：

```json
{
  "jsonrpc": "2.0",
  "result": {
    "summary": "ADKは効率的なAgent間のタスク委譲をサポートします。"
  },
  "id": "request-982731"
}
```

エラーレスポンス（構造化エラーオブジェクト）：

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32602,
    "message": "Missing required field 'text' in inputs."
  },
  "id": "request-982731"
}
```

このフォーマットは相関追跡、エラー回復、呼び出しAgentでのリトライ処理を容易にします。

#### RESTによる外部公開

FastAPIを使用したAgent REST エンドポイントの例：

```python
from fastapi import FastAPI, Request
from agent import review_agent
from google_adk_core.runtime import run_agent

app = FastAPI()

@app.post("/run")
async def invoke_agent(request: Request):
    payload = await request.json()
    return run_agent(agent=review_agent, payload=payload)
```

RESTリクエスト形式：

```http
POST /run HTTP/1.1
Content-Type: application/json

{
  "intent": "analyze_sentiment",
  "inputs": {
    "review": "I absolutely loved the performance and story arc!"
  },
  "memory": {},
  "context": {
    "user_id": "user_456",
    "timestamp": "2025-07-04T10:02:00Z"
  }
}
```

### 6.3 Agent Cards（能力宣言メタデータ）

**Agent Card** はAgentの「デジタル名刺」です。`/.well-known/agent.json` エンドポイントで公開されるJSONメタデータドキュメントであり、他のAgentやクライアントが能力を発見・解釈するための標準インターフェースです。

#### Agent Card JSONスキーマ例（完全版）

```json
{
  "name": "InvoiceProcessingAgent",
  "description": "請求書の解析、バリデーション、データ抽出を専門とするAgent",
  "version": "2.1.0",
  "url": "https://finance.example.com/agents/invoice",
  "capabilities": {
    "streaming": true,
    "pushNotifications": true,
    "stateTransitionHistory": false
  },
  "securitySchemes": {
    "oauth2": {
      "type": "oauth2",
      "flows": {
        "clientCredentials": {
          "tokenUrl": "https://auth.example.com/token",
          "scopes": {
            "agent.invoke": "Agentの呼び出し権限",
            "agent.read": "Agentの状態読み取り権限"
          }
        }
      }
    }
  },
  "defaultInputModes": ["text/plain", "application/json"],
  "defaultOutputModes": ["application/json"],
  "skills": [
    {
      "id": "extract_invoice_data",
      "name": "請求書データ抽出",
      "description": "PDFまたはJSONの請求書から構造化データを抽出します",
      "tags": ["finance", "extraction", "invoice"],
      "inputModes": ["application/pdf", "application/json"],
      "outputModes": ["application/json"],
      "examples": [
        "この請求書のベンダー情報と金額を抽出してください",
        "PDFから品目リストをJSON形式で取得してください"
      ]
    },
    {
      "id": "validate_invoice",
      "name": "請求書バリデーション",
      "description": "請求書の必須フィールドと金額整合性を検証します",
      "tags": ["finance", "validation"],
      "inputModes": ["application/json"],
      "outputModes": ["application/json"]
    }
  ],
  "supportsAuthenticatedExtendedCard": true
}
```

**Agent Card の各フィールドの意味:**

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `name` | 必須 | Agent識別名（一意であるべき） |
| `description` | 必須 | Agentの目的・能力の概要 |
| `url` | 必須 | AgentのメインエンドポイントURL |
| `capabilities.streaming` | 推奨 | SSEストリーミングのサポート有無 |
| `capabilities.pushNotifications` | 推奨 | Webhookプッシュ通知のサポート有無 |
| `securitySchemes` | 推奨 | 認証スキームの宣言（OAuth2, APIキー等） |
| `defaultInputModes` | 推奨 | サポートするMIMEタイプ |
| `skills` | 推奨 | 具体的な能力・スキルの詳細リスト |
| `supportsAuthenticatedExtendedCard` | 任意 | 認証後に詳細CardをGETで取得可能か |

### 6.4 A2Aコア概念

| 概念 | 説明 |
|-----|------|
| **Task** | 作業単位。一意の `id` と `contextId`（関連タスクをグループ化）を持つ。`TaskStatus` と `TaskState` を管理。 |
| **Message** | クライアント・サーバー間の通信ターン。`role`（"user" または "agent"）と `parts`（コンテンツ）を持つ。 |
| **Part** | Messageの最小コンテンツ単位。`TextPart`（テキスト）、`FilePart`（ファイル）、`DataPart`（構造化JSON）のいずれか。 |
| **Artifact** | Agentがタスクで生成した具体的な出力（レポート、画像、データ結果等）。`artifactId`, `name`, `description`, `parts` を含む。 |

### 6.5 主要A2A RPCメソッド

| メソッド | 説明 | 用途 |
|---------|------|------|
| **`message/send`** | クライアントがMessageを送信してタスクを開始・継続。サーバーはTaskオブジェクトまたはMessageで応答。 | 同期・短時間処理 |
| **`message/stream`** | クライアントがMessageを送信し、SSEでリアルタイム更新を受信。`capabilities.streaming: true` が必要。 | リアルタイムフィードバック |
| **`tasks/get`** | 特定TaskのID指定で現在状態を取得。 | ポーリングによるステータス確認 |
| **`tasks/cancel`** | 実行中タスクのキャンセル要求。更新されたTaskオブジェクトを返す。 | 長期タスクの中断 |
| **`tasks/pushNotificationConfig/set`** | Webhookプッシュ通知設定。`capabilities.pushNotifications: true` が必要。 | 非常に長期タスク、モバイルアプリ |
| **`tasks/resubscribe`** | 中断されたSSEストリームへの再接続。 | ネットワーク中断後のストリーム再開 |
| **`agent/authenticatedExtendedCard`** | 認証後により詳細なAgent CardをGETで取得（JSON-RPCではなくHTTP GET）。 | ユーザー固有の能力情報の提供 |

### 6.6 インタラクションパターン

| パターン | 説明 | 適用シナリオ |
|---------|------|------------|
| **同期リクエスト/レスポンス** | `message/send` で即座に最終Taskを返却 | シンプルなタスク、短時間処理 |
| **非同期ポーリング** | `message/send` → `submitted`/`working` 状態 → `tasks/get` で定期ポーリング | 中程度の長さのタスク |
| **SSEストリーミング** | `message/stream` でHTTP接続を保持、リアルタイムにイベントをプッシュ | ユーザー向けリアルタイムフィードバック |
| **プッシュ通知** | Webhook URL提供→クライアント切断→完了時にサーバーがPOST→`tasks/get`で取得 | 長時間タスク（分/時間/日単位）、モバイルアプリ |

### 6.7 TaskStateのライフサイクル

```
ユーザーリクエスト
    ↓
submitted（受理済み・処理待ち）
    ↓
working（処理中）
    ↓
┌─────────────────────────────────────┐
│ input-required（追加情報を要求）        │
│ auth-required（セカンダリ認証要求）      │
└─────────────────────────────────────┘
    ↓ 解決後
┌─────────────────────────────────────┐
│ completed（正常完了）                  │
│ failed（タスク失敗）                    │
│ canceled（キャンセル済み）               │
│ rejected（サーバーが拒否）              │
│ unknown（不明な状態）                  │
└─────────────────────────────────────┘
```

### 6.8 Scope Negotiation（スコープ交渉）

A2Aにおける「Scope Negotiation」は、Agent間でアクセス権限・メモリ範囲・能力スコープを交渉する重要なパターンです。

**認可スコープの設計:**
```python
# メモリスコープの定義例
def filter_memory(memory: dict, caller: str) -> dict:
    """呼び出し元Agentに応じてメモリをフィルタリング"""
    if caller == "agent://fraud_detection_agent":
        # 支払いカード情報は除外
        return {k: v for k, v in memory.items()
                if not k.startswith("payment.card_")}
    elif caller == "agent://audit_agent":
        # 読み取り専用の集計データのみ提供
        return {k: v for k, v in memory.items()
                if k.startswith("summary.") or k.startswith("metrics.")}
    return memory

# インテントレベルの認可
class PaymentAgent(BaseAgent):
    def authorize_call(self, intent: str, caller: str) -> bool:
        """呼び出し元Agentがインテントにアクセスできるかチェック"""
        if intent == "process_transaction" and caller != "agent://checkout_agent":
            return False  # 403 Forbidden
        if intent == "query_transaction_metadata":
            return True   # すべてのAgentに許可
        return True
```

**Agent Cardでのスコープ宣言:**
- `securitySchemes` でOAuth2スコープを宣言
- スキル単位で入出力モードを制限可能
- `supportsAuthenticatedExtendedCard: true` でユーザー固有の追加情報を提供

### 6.9 HTTP/2 vs WebSocket：通信方式の選択

A2Aプロトコルは **HTTP(S)必須** ですが、リアルタイム通信の実装方式には選択肢があります。

| 比較軸 | Server-Sent Events（SSE/HTTP/2） | WebSocket |
|--------|----------------------------------|-----------|
| **通信方向** | サーバー→クライアント（単方向） | 双方向 |
| **A2A標準対応** | 公式仕様（`message/stream`） | 非標準（カスタム実装） |
| **接続の永続性** | HTTPリクエスト単位 | 接続維持 |
| **インフラ互換性** | HTTP/HTTPSプロキシと高い互換性 | 専用ポートが必要な場合がある |
| **再接続** | `tasks/resubscribe` で再接続 | 自動再接続が多い |
| **適用ケース** | タスク進捗通知、ストリーミング応答 | リアルタイム対話型チャット |

**A2A公式仕様では SSE（Server-Sent Events）を採用** しており、`message/stream` エンドポイントで使用します。既存のHTTPインフラと高い互換性を持ちます。

---

## 7. A2Aメッセージスキーマ設計（Message Contract Protocol）

### 7.1 MCPスキーマ定義の重要性

Agent間通信において、明確に定義された期待値がなければメッセージはスキーマドリフト、誤解、サイレント失敗に弱くなります。

**MCPスキーマが定義するもの:**
- インテント名（例: `"generate_summary"`）
- 入力スキーマ（必須・任意フィールド、型、制約）
- 出力スキーマ（呼び出し元が期待する応答形式）
- コンテキストとメモリの使用方法

### 7.2 スキーマを使ったToolNode定義

```python
from google_adk_core.tool import ToolNode
from google_adk_core.schema import ToolSchema, Field

class SummarizeTextSchema(ToolSchema):
    name = "summarize_text"
    description = "入力テキストのサマリーを生成します。"

    inputs = {
        "text": Field(type=str, required=True, description="要約対象テキスト"),
        "length": Field(
            type=str,
            required=False,
            default="medium",
            description="サマリー長: short, medium, long"
        )
    }

    outputs = {
        "summary": Field(type=str, description="生成されたサマリーテキスト")
    }

class SummarizeTextNode(ToolNode):
    schema_class = SummarizeTextSchema

    def run(self, inputs: dict, memory: dict, context: dict) -> dict:
        text = inputs["text"]
        target_length = inputs.get("length", "medium")

        if target_length == "short":
            summary = text[:50] + "..."
        elif target_length == "long":
            summary = text[:200]
        else:
            summary = text[:100] + "..."

        return {"summary": summary}
```

### 7.3 スキーマバリデーションによる早期エラー検出

MCPなしでは、フィールド欠落はランタイムまで検出されません。MCPにより「予測的拒否（Predictive Rejection）」が実現します：

```json
// リクエスト（必須フィールド "text" が欠落）
{
  "intent": "summarize_text",
  "inputs": { "length": "short" }
}

// バリデーションエラー（実行前に返却）
{
  "error": {
    "code": 400,
    "message": "Missing required field: 'text'"
  }
}
```

### 7.4 A2A委譲パケットの設計原則

```json
// 悪い例（脆弱なコントラクト）
{
  "intent": "do_something",
  "data": "handle it"
}

// 良い例（構造化コントラクト）
{
  "delegated_intent": "fetch_invoice",
  "context": {
    "invoice_id": "INV-7789",
    "user_id": "U-103"
  },
  "success_conditions": ["invoice_retrieved"],
  "fallback": "notify_accounting_failure"
}
```

明確なコントラクトにより、曖昧さを防ぎ、トレース可能な実行を実現し、オーケストレーターが自信を持ってAgentを調整できます。

---

## 8. ADKとA2A統合実装

### 8.1 ADK AgentをA2Aサーバーとして公開

1. ADK Agent システムの `AgentCard` を定義（`/.well-known/agent.json`）
2. `a2a-sdk` の `AgentExecutor` を実装し、A2Aリクエストを `runner.run_async()` 呼び出しに変換
3. ADK `Event` ストリームをA2Aイベントに変換してSSE送信またはJSON-RPC応答
4. FastAPI/Starletteでエンドポイントを公開

```python
from fastapi import FastAPI, Request
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part

app = FastAPI()
runner = InMemoryRunner(agent=my_adk_agent, app_name="MyAgentService")

@app.post("/")  # A2A エンドポイント
async def a2a_handler(request: Request):
    body = await request.json()
    method = body.get("method")

    if method == "message/send":
        message_content = body["params"]["message"]
        user_text = message_content["parts"][0]["text"]

        # ADK Runner を呼び出し
        user_message = Content(parts=[Part(text=user_text)], role="user")
        task_id = body.get("id", "default-task")
        response_text = ""

        async for event in runner.run_async(
            user_id="a2a-user",
            session_id=task_id,
            new_message=user_message
        ):
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if part.text:
                        response_text += part.text

        return {
            "jsonrpc": "2.0",
            "id": task_id,
            "result": {
                "id": task_id,
                "status": {"state": "completed"},
                "artifacts": [
                    {
                        "artifactId": "response",
                        "parts": [{"kind": "text", "text": response_text}]
                    }
                ]
            }
        }

@app.get("/.well-known/agent.json")
async def get_agent_card():
    return {
        "name": "MyADKAgent",
        "description": "ADKで構築されたマルチAgent対応サービス",
        "url": "https://my-agent.example.com/",
        "capabilities": {"streaming": False, "pushNotifications": False},
        "skills": [
            {
                "id": "general_qa",
                "name": "一般的なQA",
                "description": "様々な質問に回答します"
            }
        ]
    }
```

### 8.2 ADK AgentをA2Aクライアントとして使用

```python
from google.adk.tools import BaseTool, ToolContext
from google.genai.types import FunctionDeclaration, Schema, Type
import httpx

class RemoteA2AAgentTool(BaseTool):
    """リモートA2A AgentをADKツールとして使用するクラス"""

    def __init__(self, name: str, description: str, target_agent_url: str):
        super().__init__(name=name, description=description)
        self.target_agent_url = target_agent_url

    def _get_declaration(self) -> FunctionDeclaration:
        return FunctionDeclaration(
            name=self.name,
            description=self.description,
            parameters=Schema(
                type=Type.OBJECT,
                properties={
                    "user_prompt": Schema(
                        type=Type.STRING,
                        description="リモートA2A Agentに送信するプロンプト"
                    )
                },
                required=["user_prompt"]
            )
        )

    async def run_async(self, args: dict, tool_context: ToolContext) -> dict:
        user_prompt = args.get("user_prompt")
        if not user_prompt:
            return {"error": "user_promptが必要です"}

        # A2A message/send リクエスト
        a2a_request_payload = {
            "jsonrpc": "2.0",
            "id": tool_context.function_call_id or "adk_a2a_call",
            "method": "message/send",
            "params": {
                "message": {
                    "role": "user",
                    "parts": [{"kind": "text", "text": user_prompt}],
                    "messageId": f"adk-msg-{tool_context.invocation_id}"
                }
            }
        }

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.target_agent_url,
                    json=a2a_request_payload,
                    timeout=30.0
                )
                response.raise_for_status()
                a2a_response = response.json()
                return {
                    "status": "success",
                    "remote_agent_response": a2a_response.get("result", {})
                }
        except httpx.HTTPStatusError as e:
            return {"error": f"A2A HTTP error: {e.response.status_code} - {e.response.text}"}
        except Exception as e:
            return {"error": f"A2A request failed: {str(e)}"}

# 使用例
remote_invoice_tool = RemoteA2AAgentTool(
    name="query_remote_invoice_agent",
    description="リモートのA2A準拠請求書Agentにクエリを送信",
    target_agent_url="https://finance.example.com/agents/invoice"
)

my_adk_agent = Agent(
    name="orchestrator",
    model="gemini-2.5-flash-preview-05-20",
    instruction="必要に応じてリモートの請求書Agentに問い合わせてください。",
    tools=[remote_invoice_tool]
)
```

---

## 9. Human-in-the-Loop（Action Confirmations統合）

### 9.1 Human-in-the-Loopとは

Agent自律性と人間による監視のバランスを取るパターンです。A2Aの `input-required` 状態と組み合わせて実装します。

**実装パターン:**

```python
from google.adk.tools import FunctionTool, ToolContext

def request_human_approval(
    action: str,
    details: str,
    tool_context: ToolContext
) -> dict:
    """
    重要なアクションの前に人間の確認を要求する
    A2Aでは tasks/get で input-required 状態を確認後、
    message/send で承認メッセージを送信して処理を継続する
    """
    pending_approval = {
        "action": action,
        "details": details,
        "status": "pending"
    }
    tool_context.state["pending_approval"] = pending_approval

    # escalation を設定して処理を一時停止
    # オーケストレーターが input-required 状態に移行
    return {
        "status": "awaiting_approval",
        "message": f"アクション '{action}' の承認が必要です: {details}",
        "approval_required": True
    }

def check_approval_status(tool_context: ToolContext) -> dict:
    """承認状態をチェック"""
    pending = tool_context.state.get("pending_approval", {})
    if pending.get("status") == "approved":
        return {"approved": True, "action": pending.get("action")}
    return {"approved": False, "message": "承認待ち"}

# Human-in-the-Loop を組み込んだAgent
payment_agent = Agent(
    name="payment_processor",
    model="gemini-2.0-flash",
    instruction=(
        "支払い処理を担当します。"
        "金額が10,000円以上の場合は request_human_approval を呼び出してください。"
        "承認後にのみ処理を実行してください。"
    ),
    tools=[
        FunctionTool(func=request_human_approval),
        FunctionTool(func=check_approval_status)
    ]
)
```

### 9.2 A2A TaskStateとの統合

```
Agent処理中 (working)
    ↓
高額支払いを検出
    ↓
input-required 状態に移行
    ↓ ← クライアントが tasks/get でポーリング
承認 message/send (role: "user")
    ↓
working 状態に戻り処理継続
    ↓
completed
```

```python
# A2Aクライアント側での承認フロー
async def approve_pending_task(task_id: str, approval_message: str):
    """保留中タスクを承認する"""
    a2a_request = {
        "jsonrpc": "2.0",
        "id": f"approve-{task_id}",
        "method": "message/send",
        "params": {
            "message": {
                "role": "user",
                "parts": [{"kind": "text", "text": approval_message}],
                "messageId": f"approval-msg-{task_id}",
                "taskId": task_id
            }
        }
    }
    async with httpx.AsyncClient() as client:
        response = await client.post(AGENT_URL, json=a2a_request)
        return response.json()

# 使用例
await approve_pending_task("task-123", "承認します。処理を続けてください。")
```

---

## 10. Agent間通信パターン

### 10.1 状態共有パターン

**セッション状態（Session State）:**
- 同一 `Runner` プロセス内のADK Agent間で共有
- `tool_context.state["key"] = value` で設定
- 次のAgentが `state.get("key")` で取得

```python
# Agent 1: データを状態に保存
def extract_data(text: str, tool_context: ToolContext) -> dict:
    result = parse(text)
    tool_context.state["extracted_entities"] = result["entities"]
    tool_context.state["confidence_score"] = result["confidence"]
    return {"status": "extracted", "entity_count": len(result["entities"])}

# Agent 2: 前のAgentが保存した状態を読み込み
def analyze_entities(tool_context: ToolContext) -> dict:
    entities = tool_context.state.get("extracted_entities", [])
    confidence = tool_context.state.get("confidence_score", 0.0)
    # entities を分析して結果を返す...
```

### 10.2 Artifact共有パターン

```python
from google.adk.tools import ToolContext
from google.genai.types import Part

def save_report_artifact(report_content: str, tool_context: ToolContext) -> dict:
    """生成したレポートをArtifactとして保存"""
    # Artifactとして保存（他のAgentが参照可能）
    tool_context.save_artifact(
        filename="analysis_report.md",
        artifact=Part.from_text(report_content)
    )
    return {"status": "saved", "filename": "analysis_report.md"}
```

### 10.3 コンテキスト伝播パターン

マルチAgentパイプラインでは、コンテキストオブジェクトを第一級データキャリアとして扱います。

```python
# コンテキストオブジェクトの基本構造
context = {
    "caller": "agent://report_orchestrator",
    "request_id": "req-cbe13a",
    "trace_id": "trace-7739a",
    "user_id": "user-12081",
    "permissions": ["read:docs", "write:summary"],
    "memory": {
        "pipeline_stage": "extracted",
        "current_doc": "document_003"
    }
}

# スコープ付きコンテキスト投影
def prepare_worker_payload(memory: dict, context: dict) -> dict:
    """ワーカーAgentに必要最小限のコンテキストのみ渡す"""
    return {
        "inputs": {"text": memory["document_text"]},
        "context": {
            "caller": context["caller"],
            "trace_id": context["trace_id"],
            "permissions": context["permissions"]
            # user_idやpipeline固有情報は除外
        }
    }
```

### 10.4 イベントベース通信パターン

Cloud Pub/SubやEventarcを使った疎結合なAgent間通信：

```python
from google.cloud import pubsub_v1

def publish_agent_event(
    topic_id: str,
    event_type: str,
    payload: dict,
    tool_context: ToolContext
) -> dict:
    """Agent完了イベントをPub/Subに発行"""
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path("your-project-id", topic_id)

    import json
    message = {
        "event_type": event_type,
        "payload": payload,
        "trace_id": tool_context.state.get("trace_id", ""),
        "agent_name": "my_agent"
    }
    data = json.dumps(message).encode("utf-8")
    future = publisher.publish(topic_path, data)
    message_id = future.result()

    return {"status": "published", "message_id": message_id}
```

---

## 11. マルチAgentデバッグ・テスト

### 11.1 分散トレーシング

すべてのA2A通信には `trace_id` を付与し、異なるAgentのログを関連付けます。

```python
# ノードレベルでのトレース付きログ
def run(self, inputs: dict, memory: dict, context: dict) -> dict:
    self.logger.info({
        "trace_id": context["trace_id"],
        "intent": self.schema.name,
        "caller": context["caller"],
        "node": self.__class__.__name__,
        "status": "started"
    })
    # 処理...
    self.logger.info({
        "trace_id": context["trace_id"],
        "node": self.__class__.__name__,
        "status": "completed",
        "output_keys": list(result.keys())
    })
    return result
```

### 11.2 メモリスナップショットによるデバッグ

```python
def run(self, inputs: dict, memory: dict, context: dict) -> dict:
    # 実行前スナップショット
    self.logger.debug({
        "trace_id": context.get("trace_id"),
        "inputs": inputs,
        "memory_snapshot": dict(memory),
        "event": "before_execution"
    })
    # 処理...
    return result
```

### 11.3 デバッグモードでの委譲シミュレーション

```python
class ReportSummaryNode(ToolNode):
    def run(self, inputs: dict, memory: dict, context: dict) -> dict:
        if context.get("debug_mode"):
            # デバッグ時はモックレスポンスを返す
            return {"summary": "[DEBUG] Summary would go here."}

        # 本番: リモートAgentを呼び出し
        response = self.call_agent(
            url="https://summary-agent/run",
            payload={
                "intent": "summarize_text",
                "inputs": {"text": inputs["section"]},
                "context": context
            }
        )
        return {"summary": response["summary"]}
```

### 11.4 ユニットテストパターン

```python
from my_project.agents import SummarizeTextNode

def test_summary_short_text():
    """単一ノードをモックを使ってユニットテスト"""
    node = SummarizeTextNode()
    inputs = {"text": "Google ADKは構造化された委譲をAgent間で実現します。"}
    memory = {}
    context = {"trace_id": "test-1234", "caller": "test"}

    result = node.run(inputs, memory, context)

    assert "summary" in result
    assert len(result["summary"]) > 0

def test_summary_missing_required_field():
    """必須フィールド欠落のバリデーションテスト"""
    node = SummarizeTextNode()

    try:
        node.run({}, {}, {"trace_id": "test-1235"})
        assert False, "ValueError が発生すべき"
    except ValueError as e:
        assert "text" in str(e)
```

### 11.5 よくあるデバッグ問題と対処法

| 症状 | 原因 | 対処法 |
|------|------|--------|
| 委譲が曖昧なエラーで失敗 | 認証失敗またはスコープ不足 | callerの認証とcontextにsignatureがあるか確認 |
| 予期しないメモリ上書き | メモリキーの衝突 | ノード固有のプレフィックスをキーに付与 |
| Agentからの部分的な出力 | MCPスキーマ定義の不整合 | 出力フィールドがスキーマに定義されているか確認 |
| スキーマバリデーション失敗 | 送信ペイロードとスキーマの不一致 | MCPイントロスペクションで期待値を比較 |
| 転送ループ | 明確な終了条件の欠如 | 各Agentの終了条件とmax_llm_callsを設定 |

---

## 12. A2Aセキュリティ

### 12.1 認証・認可

```python
from google.oauth2 import id_token
from google.auth.transport import requests

def verify_request_token(token: str) -> dict:
    """JWT トークンを検証してAgent IDを確認"""
    request = requests.Request()
    return id_token.verify_oauth2_token(
        token,
        request,
        audience="https://your-agent-service"
    )

# FastAPIミドルウェアでの認証
from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer

security = HTTPBearer()

async def get_current_agent(credentials = Security(security)):
    try:
        payload = verify_request_token(credentials.credentials)
        return payload
    except Exception:
        raise HTTPException(status_code=403, detail="Invalid or expired token")
```

**認証スキームの選択:**
- **OAuth2 + サービスアカウント**: Google Cloud内のAgent間（推奨）
- **JWT署名付きトークン**: Agent IDとタイムスタンプを含む（中間層での検証が可能）
- **APIキー**: 単純な内部システム向け（本番環境では非推奨）

### 12.2 冪等性とリプレイ保護

```python
class PublishLogNode(FunctionNode):
    def run(self, inputs: dict, memory: dict, context: dict) -> dict:
        """冪等性を保証するノード"""
        log_id = inputs.get("request_id")
        trace_id = context.get("trace_id")

        # 既処理チェック（リプレイ攻撃防止）
        if memory.get(f"log_sent:{log_id}"):
            return {"status": "skipped", "reason": "already_processed"}

        # ログ送信
        send_to_log_service(inputs["message"])
        memory[f"log_sent:{log_id}"] = True

        return {"status": "success", "log_id": log_id}
```

### 12.3 レート制限とサーキットブレーカー

```python
import redis

class EmbeddingNode(FunctionNode):
    def run(self, inputs: dict, memory: dict, context: dict) -> dict:
        # レート制限（Redis使用）
        caller = context.get("caller")
        key = f"rate:{caller}"
        current = redis.incr(key)
        redis.expire(key, 60)  # 60秒でリセット

        if current > 100:
            raise Exception(f"Rate limit exceeded for {caller}")

        return compute_embeddings(inputs["text"])

# サーキットブレーカーパターン
def call_with_circuit_breaker(memory: dict, agent_url: str, payload: dict):
    failure_key = f"failures:{agent_url}"
    failure_count = memory.get(failure_key, 0)

    if failure_count > 5:
        return {"error": "Agent temporarily disabled due to repeated failures"}

    try:
        result = self.call_agent(url=agent_url, payload=payload)
        memory[failure_key] = 0  # 成功時はリセット
        return result
    except Exception as e:
        memory[failure_key] = failure_count + 1
        raise
```

### 12.4 プッシュ通知セキュリティ

Webhookを使ったプッシュ通知には、SSRF攻撃防止とWebhookの認証が必要です：

```python
import hmac
import hashlib

def verify_webhook_signature(payload: bytes, signature: str, secret: str) -> bool:
    """Webhookの署名を検証（HMAC-SHA256）"""
    expected = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)

@app.post("/webhook/agent-notifications")
async def receive_push_notification(request: Request):
    body = await request.body()
    signature = request.headers.get("X-Agent-Signature", "")

    if not verify_webhook_signature(body, signature, WEBHOOK_SECRET):
        raise HTTPException(status_code=401, detail="Invalid signature")

    # 通知を処理
    notification = json.loads(body)
    task_id = notification.get("taskId")
    # tasks/get でタスク状態を確認...
```

---

## 13. スケーリングパターン

### 13.1 セッション分離

複数のユーザーセッションを独立して管理することで、状態汚染を防ぎます：

```python
from google.adk.runners import InMemoryRunner
from google.adk.sessions import DatabaseSessionService

# 本番: データベースベースのセッション管理
session_service = DatabaseSessionService(db_url="postgresql://...")

runner = InMemoryRunner(
    agent=my_agent,
    app_name="ProductionService",
    session_service=session_service  # セッションを永続化
)

# ユーザーごとに独立したセッション
async def handle_user_request(user_id: str, session_id: str, message: str):
    user_message = Content(parts=[Part(text=message)], role="user")
    async for event in runner.run_async(
        user_id=user_id,           # ユーザー固有
        session_id=session_id,     # セッション固有
        new_message=user_message
    ):
        yield event
```

### 13.2 負荷分散とAutoscaling

```
                              ┌─────────────────────────────────┐
                              │     A2A Load Balancer (HTTPS)   │
                              └───────────────┬─────────────────┘
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    ▼                         ▼                         ▼
           ┌────────────────┐      ┌────────────────┐       ┌────────────────┐
           │  Agent Pod 1   │      │  Agent Pod 2   │       │  Agent Pod N   │
           │  (Cloud Run)   │      │  (Cloud Run)   │       │  (Cloud Run)   │
           └───────┬────────┘      └───────┬────────┘       └───────┬────────┘
                   │                       │                         │
                   └───────────────────────┼─────────────────────────┘
                                           │
                              ┌────────────▼────────────┐
                              │  Shared Session Store   │
                              │   (Firestore/Spanner)   │
                              └─────────────────────────┘
```

**Cloud Run でのAgentデプロイ設定例:**

```yaml
# cloud-run-service.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: my-adk-agent
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"
        autoscaling.knative.dev/maxScale: "10"
    spec:
      containerConcurrency: 80  # 同時リクエスト数
      containers:
      - image: gcr.io/my-project/adk-agent:latest
        resources:
          limits:
            cpu: "2"
            memory: "2Gi"
        env:
        - name: GOOGLE_CLOUD_PROJECT
          value: my-project
```

### 13.3 指数バックオフによるリトライ

```python
import time

class RetriableCallNode(FunctionNode):
    def run(self, inputs: dict, memory: dict, context: dict) -> dict:
        retries = 3
        delay = 1

        for attempt in range(retries):
            try:
                result = self.call_agent(
                    url="https://qa-agent/run",
                    payload={
                        "intent": "question_answering",
                        "inputs": {"query": inputs["query"]},
                        "context": context
                    }
                )
                return {"answer": result["answer"]}

            except Exception as e:
                self.logger.warning({
                    "attempt": attempt + 1,
                    "trace_id": context["trace_id"],
                    "error": str(e)
                })

                if attempt == retries - 1:
                    return {"error": f"Failed after {retries} retries"}

                time.sleep(delay)
                delay *= 2  # 指数バックオフ

        return {"error": "Unexpected failure"}
```

---

## 14. A2A vs MCPの関係

A2AとMCPは補完的な役割を持ち、組み合わせることで最大の効果を発揮します。

| 比較軸 | A2A（Agent-to-Agent） | MCP（Model Context Protocol） |
|--------|----------------------|-------------------------------|
| **フォーカス** | 独立したAI Agent同士のピア通信・協調 | AIモデル/AgentがツールやAPIをどう使用するか |
| **ユースケース** | Agentの能力発見、タスク委譲、マルチAgent協調 | 関数呼び出し、ツール統合、外部API接続 |
| **通信モデル** | Agent間のメッセージパッシング（RPC/REST） | Agent-Tool間の関数呼び出し |
| **能力宣言** | Agent Cards（JSON） | Tool Schemas（JSON Schema） |
| **セキュリティ** | OAuth2、JWT、IAMサービスアカウント | アクセストークン、スコープ |

**組み合わせのアーキテクチャ:**
- A2AサーバーAgentは内部でMCPを使用して独自のツールセットにアクセス
- A2AクライアントはAgent Cardを読んで能力を発見し、MCPスキーマでリクエストを構成
- 外部Agent（LangGraph、CrewAI等）はA2Aインターフェースを通じてADK Agentと連携

---

## 15. ベストプラクティスまとめ

### 設計原則

- **インテント駆動**: 各AgentとノードはIntent（何を達成するか）に基づいて設計
- **スキーマファースト**: 実装前にMCPスキーマを定義し、コントラクトを確立
- **最小権限**: Agentには必要最小限の権限のみ付与（IAMの原則）
- **コンテキスト透過性**: trace_id、caller、timestampを常にコンテキストに含める
- **べき等性の保証**: リトライを考慮し、同一リクエストの多重実行を安全に処理

### A2A実装チェックリスト

- [ ] Agent Card（`/.well-known/agent.json`）を定義
- [ ] MCPスキーマで入出力を明示的に定義
- [ ] すべての通信にHTTPS使用
- [ ] 認証スキーム（OAuth2/JWT）を実装
- [ ] trace_idによる分散トレーシングを設定
- [ ] リトライ（指数バックオフ）を実装
- [ ] サーキットブレーカーパターンを適用
- [ ] 冪等性保証（request_idによる重複チェック）
- [ ] Webhookには署名検証を実装
- [ ] メモリスコープを適切にフィルタリング

### マルチAgent設計チェックリスト

- [ ] 各Agentに単一責任を持たせる
- [ ] sub_agentsの `description` を明確に記述
- [ ] LoopAgentには必ず `max_iterations` を設定
- [ ] ParallelAgentで `event.branch` を正しく使用
- [ ] セッション状態のキー名を統一（プレフィックス規則）
- [ ] Agent間のスキーマ互換性を確認
- [ ] 転送ループ防止のための明確な終了条件を定義
- [ ] Human-in-the-Loopが必要な高権限アクションを特定
