# マルチAgent設計とオーケストレーション

複数のAI Agentが協調して複雑な問題を解決するマルチAgentシステム（MAS）の設計原則、ADKでの実装パターン、高度な連携手法について解説します。

---

## 1. マルチAgent設計原則

### 1.1 マルチAgentシステムを採用する理由

**単体の強力なAgentではなく、複数のAgentを使う理由:**

- **モジュール性と専門化**: 各Agentが特定のドメイン・タスクの専門家になる（例: 調査Agent、データ分析Agent、コミュニケーションAgent）
- **スケーラビリティ**: 異なるAgentを独立実行でき、リソースの効率的利用が可能
- **堅牢性**: 1つのAgentが問題に遭遇しても、他の部分は動作を継続・適応可能
- **複雑さの管理**: 大きな問題を小さなサブ問題に分割し、個別Agentで対処
- **再利用性**: 専門化されたAgentを異なるマルチAgentアプリケーション間で再利用可能

### 1.2 設計時の重要考慮事項

| 考慮事項 | 説明 |
|---------|------|
| **Agent役割と責任** | 各Agentの担当範囲を明確に定義 |
| **通信プロトコル** | Agent間での情報交換・タスク委譲の方法（ADKでは「Agent Transfer」） |
| **調整戦略** | 全体ワークフローの管理方法（中央オーケストレーター、パイプライン、分散化等） |
| **知識共有** | Agent間でのコンテキスト・結果の共有方法（セッション状態、Artifact、メッセージ受け渡し等） |
| **競合解決** | Agent間で目標や情報が競合した場合の解決方法（高度） |

---

## 2. ADKでのParent/Sub-Agent定義

### 2.1 階層的マルチAgentシステム

**特徴:**
- `LlmAgent` は `sub_agents` パラメータで子Agentを持てる
- 親Agentは子Agentにタスクを委譲可能
- 各子Agentは独自のモデル、指示、ツール、さらに子Agentを持てる（ネスト可能）

**コード例:**
```python
from google.adk.agents import Agent

# 専門化された子Agent
research_agent = Agent(
    name="researcher",
    model="gemini-2.0-flash",
    instruction="調査専門家です。トピックについて検索ツールを使って関連情報を収集します。",
    description="トピックについて情報を検索します。"
)

writer_agent = Agent(
    name="writer",
    model="gemini-2.0-flash",
    instruction="熟練したライターです。提供された情報を整合性のあるサマリー・レポートにまとめます。",
    description="情報を基にサマリー・レポートを作成します。"
)

# 親/オーケストレーターAgent
report_orchestrator = Agent(
    name="report_orchestrator",
    model="gemini-2.5-flash-preview-05-20",
    instruction="調査レポートを作成するオーケストレーターです。"
                "まず 'researcher' Agentでユーザーのトピックについて情報収集し、"
                "次に 'writer' Agentに調査結果を渡して最終レポートを作成します。"
                "フローを管理し、最終レポートをユーザーに提示してください。",
    description="調査とレポート作成を統括します。",
    sub_agents=[research_agent, writer_agent]
)

# Runnerのルートとなるのは report_orchestrator
# from google.adk.runners import InMemoryRunner
# runner = InMemoryRunner(agent=report_orchestrator, app_name="ReportMAS")
```

**重要ポイント:**
- 親Agent（`report_orchestrator`）が複数の子Agent（`research_agent`, `writer_agent`）を持つ
- 親Agentの指示で子Agentにタスクを委譲するよう明記
- 各子Agentの `description` が、親AgentのLLMが委譲を決定する際の重要な情報源となる

**description が重要な理由:**
> 親Agentが子Agentへのタスク委譲を決定する際、子Agentの `description` を参照します。明確で簡潔、かつ各子Agentの独自の能力と呼び出すべき状況を示す記述が必要です。

---

## 3. Agent Transfer（Agent間通信）

### 3.1 Agent Transferの仕組み

ADKにおけるAgent間の「通信」や委譲の主要メカニズムは **Agent Transfer**（制御の移譲）です。

**内部ツール `transfer_to_agent`:**
- ADKが内部的に提供する概念的ツール
- `sub_agents` を持つ `LlmAgent` のLLM Flowが自動的に利用可能にする
- 引数: `agent_name`（移譲先のAgent名）

**AutoFlowの役割:**
- `AutoFlow` は `LlmAgent` がAgent転送を行う可能性がある場合に自動使用される
- `agent_transfer.request_processor` が:
  1. 移譲可能なAgent（子Agent、親Agent、ピア）を特定
  2. 利用可能なAgentとその説明をLLMに通知する指示を `LlmRequest` に追加
  3. `transfer_to_agent` ツール宣言を `LlmRequest` に含める

**転送の実行フロー:**
1. オーケストレーターLLMが `transfer_to_agent(agent_name="target_agent")` を呼び出し
2. `AutoFlow` がこの呼び出しをインターセプト
3. `Runner` がターゲットAgentを特定
4. `Runner` がターゲットAgentの `run_async` を実行（現在の `InvocationContext` を渡す）
5. 会話がターゲットAgentでアクティブなまま継続

**LLMが転送を決定する例（概念的LLM出力）:**
```
/* LLM output for report_orchestrator_agent */
まず情報収集が必要です。'researcher' Agentが最適です。
<tool_code>
transfer_to_agent(agent_name="researcher")
</tool_code>
```

### 3.2 子Agentから親Agentへの復帰

**復帰方法:**
- **暗黙的**: 子AgentがSingleFlowを使用している場合、最終テキスト応答を生成すると `run_async` が完了し、待機していた `Runner` が次のAgentを決定
- **明示的転送**: 子Agentが `transfer_to_agent(agent_name="report_orchestrator")` を呼び出し
- **オーケストレーターの計画**: オーケストレーターが「1. researcherを呼ぶ。2. 次にその出力を使ってwriterを呼ぶ」と明示的に計画している場合、researcher完了後、オーケストレーターのLLMが再度プロンプトされて次のステップを実行

### 3.3 転送ループとデッドロック防止

**防止策:**
- 各Agentに明確で異なる責任を持たせる
- オーケストレーターの指示で転送条件を明確に定義
- 子Agentがタスク完了をシグナルする方法を明確化（最終回答提供または明示的な転送返し）
- `RunConfig` の `max_llm_calls` をセーフティネットとして設定

---

## 4. 共通マルチAgentパターン

### 4.1 階層型（Coordinator-Worker / Orchestrator-Specialist）

**構造:**
- 親「コーディネーター」または「オーケストレーター」Agentが複雑なタスクを分割
- 専門化された「ワーカー」または「スペシャリスト」子Agentにサブタスクを委譲

**ADK実装:**
- 親 `LlmAgent` が `sub_agents` リストを持つ
- 親の指示は委譲ロジックに焦点
- 子Agentは特定タスクに焦点

**例: 調査レポートシステム**
- `report_orchestrator`（コーディネーター）
- `research_agent`（ワーカー）
- `writer_agent`（ワーカー）

### 4.2 パイプライン型（Sequential）

**構造:**
- データやタスクが一連のAgentを順次通過
- 各Agentが特定の変換やステップを実行
- あるAgentの出力が次のAgentの入力になる

**ADK実装:**
- マスターオーケストレーターAgentが子Agentを順次呼び出す
- または `SequentialAgent` を使用（次章で詳述）

**例: データ処理パイプライン**
1. `DataIngestionAgent`: 生データ取得
2. `DataCleaningAgent`: データクリーニング・前処理
3. `AnalysisAgent`: クリーンデータを分析
4. `ReportGenerationAgent`: 分析結果をレポート形式化

### 4.3 並列型（Ensemble / Competing Experts）

**構造:**
- 複数のAgentが同じタスクまたはサブ問題に同時に取り組む
- 結果を以下のように処理:
  - 別のAgentが統合・合成
  - 投票
  - 基準に基づいて「最良」の結果を選択

**ADK実装:**
- オーケストレーターが複数の子Agentを概念的に並列呼び出し（`asyncio` のスケジューリング依存）
- または `ParallelAgent` を使用（次章で詳述）

**例: サマリーアンサンブル**
- 3つの異なる `SummarizationAgent` が異なる指示/モデルで同じドキュメントを処理
- `EvaluationAgent` が最良のサマリーを選択

### 4.4 パターン選択基準テーブル

| パターン | 適用ケース | ADK実装 |
|---------|---------|---------|
| **階層型** | 明確な役割分担、専門化 | 親Agentに `sub_agents` を定義 |
| **パイプライン型** | 順次処理、各ステップが前ステップの出力を使用 | `SequentialAgent` または明示的な順次委譲 |
| **並列型** | 複数視点が必要、独立サブタスク、アンサンブル手法 | `ParallelAgent` または並列委譲 |

**ベストプラクティス:**
> 初めてのMAS設計では、シンプルなパターン（明確な階層または短いパイプライン）から始めてください。経験を積むことで、より複雑な調整戦略を探求できます。

---

## 5. Shell Agents（オーケストレーション構造）

### 5.1 SequentialAgent: パイプラインワークフロー

**特徴:**
- `sub_agents` を定義された順序で順次実行
- 1つの子Agentの実行が完了すると次へ進む
- 全会話履歴と状態が次の子Agentに引き継がれる

**用途:**
- 固定された一連のステップに分解されるタスク
- あるAgentの出力が次のAgentの直接入力またはコンテキストになる場合

**コード例:**
```python
from google.adk.agents import Agent, SequentialAgent
from google.adk.tools import FunctionTool, ToolContext
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import asyncio

# 環境変数を読み込み
# ... load_environment_variables() ...

def gather_user_data(name: str, email: str, tool_context: ToolContext) -> dict:
    """ユーザー名とメールを収集してセッション状態に保存"""
    tool_context.state["user_name_collected"] = name
    tool_context.state["user_email_collected"] = email
    return {"status": "success", "message": f"{name}のデータを収集しました"}

gather_data_tool = FunctionTool(func=gather_user_data)

data_collection_agent = Agent(
    name="data_collector",
    model="gemini-2.0-flash",
    instruction="ユーザーの名前とメールアドレスを収集します。gather_user_dataツールを使用してください。",
    description="ユーザー名とメールアドレスを収集します。",
    tools=[gather_data_tool]
)

def validate_email_format(email: str, tool_context: ToolContext) -> dict:
    """メールアドレス形式を検証"""
    import re
    if re.match(r'[\w.-]+@[\w.-]+\.\w+', email):
        tool_context.state["email_validated"] = True
        return {"is_valid": True, "email": email}
    else:
        tool_context.state["email_validated"] = False
        return {"is_valid": False, "email": email, "error": "無効なメール形式"}

validate_email_tool = FunctionTool(func=validate_email_format)

email_validation_agent = Agent(
    name="email_validator",
    model="gemini-2.0-flash",
    instruction="メールアドレスを検証します。`state['user_email_collected']`からメールアドレスを取得し、"
                "validate_email_formatツールで形式を確認してください。結果を報告してください。",
    description="メールアドレス形式を検証します。",
    tools=[validate_email_tool]
)

def send_welcome_email(tool_context: ToolContext) -> str:
    """検証通過後にウェルカムメール送信（シミュレーション）"""
    if tool_context.state.get("email_validated") and tool_context.state.get("user_name_collected"):
        name = tool_context.state["user_name_collected"]
        email = tool_context.state["user_email_collected"]
        return f"ウェルカムメールを{name}（{email}）に送信しました。"
    return "ウェルカムメールを送信できませんでした: メール未検証または名前欠落"

send_email_tool = FunctionTool(func=send_welcome_email)

welcome_email_agent = Agent(
    name="welcome_emailer",
    model="gemini-2.0-flash",
    instruction="メールが検証済み（`state['email_validated']`をチェック）であれば、"
                "send_welcome_emailツールを使用してウェルカムメッセージを送信してください。アクションを確認してください。",
    description="ウェルカムメールを送信します。",
    tools=[send_email_tool]
)

# SequentialAgentの定義
user_onboarding_pipeline = SequentialAgent(
    name="user_onboarding_orchestrator",
    description="新規ユーザーオンボーディングパイプライン: データ収集、メール検証、ウェルカム送信",
    sub_agents=[
        data_collection_agent,
        email_validation_agent,
        welcome_email_agent
    ]
)

runner = InMemoryRunner(agent=user_onboarding_pipeline, app_name="OnboardingApp")
session_id = "s_onboard_seq"
user_id = "new_user_seq"

async def main():
    initial_prompt = "ユーザーAliceをメール alice@example.com でオンボード"
    user_message = Content(parts=[Part(text=initial_prompt)], role="user")
    print(f"YOU: {initial_prompt}")

    async for event in runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
        print(f"EVENT from [{event.author}]:")
        if event.content and event.content.parts:
            for part in event.content.parts:
                if part.text:
                    print(f"  テキスト: {part.text.strip()}")
                elif part.function_call:
                    print(f"  ツール呼び出し: {part.function_call.name}({part.function_call.args})")
                elif part.function_response:
                    print(f"  ツール応答({part.function_response.name}): {part.function_response.response}")
    print()

asyncio.run(main())
```

**実行フロー:**
1. `user_onboarding_pipeline` がユーザーメッセージを受信
2. `data_collection_agent.run_async()` を実行 → データ収集ツール呼び出し、状態更新
3. `data_collection_agent` 完了後、`email_validation_agent.run_async()` を実行 → 状態からメール取得、検証ツール呼び出し
4. `email_validation_agent` 完了後、`welcome_email_agent.run_async()` を実行 → 状態確認、メール送信ツール呼び出し
5. 全子Agentのイベントが順番に yield される

**ベストプラクティス:**
> SequentialAgent使用時は、各子Agentが期待する入力（多くは前のAgentが設定したセッション状態から）と出力（次のAgentのためにセッション状態を更新）を明確に定義してください。

### 5.2 ParallelAgent: 並行タスク実行

**特徴:**
- 全 `sub_agents` を同時実行
- 全Agent完了を待機し、出力を統合または利用可能にする
- 各子Agentは同じ初期 `InvocationContext`（セッション状態・履歴）を共有

**用途:**
- 同じ問題に対する複数の視点が必要
- 独立したサブタスクを同時実行
- 複数Agentの結果を後で集約・投票するアンサンブル手法

**コード例:**
```python
from google.adk.agents import Agent, ParallelAgent
from google.adk.events import Event
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import asyncio

# 環境変数を読み込み
# ... load_environment_variables() ...

sentiment_analyzer = Agent(
    name="sentiment_analyzer",
    model="gemini-2.0-flash",
    instruction="提供されたテキストの感情を分析してください。'positive', 'negative', 'neutral'のいずれかを出力してください。",
    description="テキスト感情を分析します。"
)

keyword_extractor = Agent(
    name="keyword_extractor",
    model="gemini-2.0-flash",
    instruction="提供されたテキストから主要なキーワードを最大3つ抽出してください。カンマ区切りで出力してください。",
    description="テキストからキーワードを抽出します。"
)

# ParallelAgentの定義
text_analysis_parallel = ParallelAgent(
    name="parallel_text_analyzer",
    description="感情分析とキーワード抽出を並列実行します。",
    sub_agents=[
        sentiment_analyzer,
        keyword_extractor
    ]
)

# オーケストレーターで並列結果を統合
class AnalysisOrchestrator(Agent):
    async def _run_async_impl(self, ctx):
        print("  オーケストレーター: 並列分析開始...")
        all_parallel_events = []
        async for event in text_analysis_parallel.run_async(ctx):
            all_parallel_events.append(event)

        sentiment_result = "感情: 見つかりません"
        keywords_result = "キーワード: 見つかりません"

        for event in all_parallel_events:
            if event.author == sentiment_analyzer.name and event.content:
                if not event.get_function_calls() and not event.get_function_responses():
                    sentiment_result = f"感情分析('{event.author}', branch '{event.branch}'): {event.content.parts[0].text.strip()}"
            elif event.author == keyword_extractor.name and event.content:
                if not event.get_function_calls() and not event.get_function_responses():
                    keywords_result = f"キーワード抽出('{event.author}', branch '{event.branch}'): {event.content.parts[0].text.strip()}"

        combined_text = f"統合分析結果:\n{sentiment_result}\n{keywords_result}"
        yield Event(
            invocation_id=ctx.invocation_id,
            author=self.name,
            content=Content(parts=[Part(text=combined_text)])
        )

analysis_orchestrator = AnalysisOrchestrator(
    name="analysis_orchestrator",
    description="並列テキスト分析を統括し、統合結果を提示します。",
    sub_agents=[text_analysis_parallel]
)

runner = InMemoryRunner(agent=analysis_orchestrator, app_name="ParallelAnalysisApp")
session_id = "s_parallel_an"
user_id = "parallel_user"

async def main():
    review_text = "このADKフレームワークは非常に強力で柔軟、Agent開発が簡単です！強くお勧めします。"
    user_message = Content(parts=[Part(text=review_text)], role="user")
    print(f"YOU: このテキストを分析: {review_text}")

    async for event in runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
        if event.author == analysis_orchestrator.name and event.content:
            print(f"ORCHESTRATOR: {event.content.parts[0].text.strip()}")

asyncio.run(main())
```

**実行フロー:**
1. `analysis_orchestrator` が呼び出される
2. `_run_async_impl` が `text_analysis_parallel.run_async()` を呼び出し
3. `ParallelAgent` が `sentiment_analyzer.run_async()` と `keyword_extractor.run_async()` を並行実行
4. 各子AgentからのイベントにはユニークなAgentを示す `branch` 属性が設定される（例: `"parallel_text_analyzer.sentiment_analyzer"`）
5. オーケストレーターがイベントを収集し、手動で統合結果を構築

**event.branch の重要性:**
> ParallelAgentからyieldされるイベントには、どの子Agentが生成したかを示す `event.branch` 属性が自動設定されます。後続ロジックやAgentが並列タスクの結果を正確に処理・統合するために不可欠です。

**注意点:**
> 多数の複雑な子Agentを並列実行すると、リソース（CPU、メモリ、LLM APIクオータ）を大量消費します。並列起動するAgentの数と複雑さに注意してください。

**SequentialAgent vs ParallelAgent vs LoopAgent 判断テーブル:**

| 要素 | SequentialAgent | ParallelAgent | LoopAgent |
|-----|----------------|--------------|-----------|
| **実行順序** | 固定・順次 | 同時並行 | 反復（条件満たすまで） |
| **子Agent間依存** | あり（前Agentの出力が次Agentの入力） | なし（独立実行） | あり（反復中に状態更新） |
| **結果統合** | 最後の子Agentの出力がメイン | オーケストレーターが明示的に統合 | 終了条件満たした時点の出力 |
| **典型的用途** | データ処理パイプライン、段階的タスク | アンサンブル、複数視点、独立タスク | 反復改善、リトライ、ポーリング |
| **終了条件** | 全子Agent完了 | 全子Agent完了 | `exit_loop` 呼び出し または `max_iterations` |
| **状態共有** | 順次蓄積（次Agentが前Agentの状態を引き継ぐ） | 初期状態を全Agentで共有（分岐後は独立） | 反復ごとに状態更新 |

### 5.3 LoopAgent: 反復タスク/リトライ

**特徴:**
- `sub_agents` のリスト（多くは1つ）を最大反復回数に達するか、子Agentが「escalation」（終了条件）をシグナルするまで繰り返し実行

**用途:**
- 反復的な改善が必要なタスク（Agentが何かを生成 → 別のAgentが批評 → 最初のAgentが改善、を繰り返す）
- 失敗しやすい操作のリトライメカニズム実装
- 条件が満たされるまでのポーリング/待機

**exit_loopツール:**
- `google.adk.tools.exit_loop` ツールを呼び出すことでループ終了をシグナル
- ツール内で `exit_loop(tool_context)` を呼び出すと `tool_context.actions.escalate = True` が設定される

**コード例:**
```python
from google.adk.agents import Agent, LoopAgent
from google.adk.tools import FunctionTool, ToolContext, exit_loop
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import asyncio

# 環境変数を読み込み
# ... load_environment_variables() ...

def check_draft_quality(draft: str, tool_context: ToolContext) -> dict:
    """ドラフト品質をチェック。'final'が含まれるか3回反復でループ終了"""
    iteration = tool_context.state.get("loop_iteration", 0) + 1
    tool_context.state["loop_iteration"] = iteration
    tool_context.state["current_draft"] = draft

    if "final" in draft.lower() or iteration >= 3:
        print(f"    [QualityCheckTool] ドラフトが基準を満たしたか最大反復({iteration})に到達。終了シグナル。")
        exit_loop(tool_context)
        return {"quality": "good", "feedback": "良好です！" if "final" in draft.lower() else "最大反復到達", "action": "exit"}
    else:
        print(f"    [QualityCheckTool] ドラフトはまだ改善が必要（反復{iteration}）")
        return {"quality": "poor", "feedback": "ADKのメリットについてもっと詳細を追加してください", "action": "refine"}

quality_check_tool = FunctionTool(func=check_draft_quality)

drafting_agent = Agent(
    name="draft_refiner",
    model="gemini-2.0-flash",
    instruction="ドキュメントのドラフトを作成します。トピックと前回のドラフト（`state['current_draft']`にあれば）を受け取り、"
                "ドラフトを生成または改善してください。次に check_draft_quality ツールで評価します。"
                "ツールが終了をシグナルしたら、この反復の作業は完了です。"
                "改善をシグナルされたら、フィードバックを使って次の思考プロセスでドラフトを改善してください。",
    description="ドキュメントを反復的にドラフト・改善します。",
    tools=[quality_check_tool]
)

# LoopAgentの定義
iterative_refinement_loop = LoopAgent(
    name="document_refinement_loop",
    description="品質基準が満たされるまでドキュメントを反復的に改善します。",
    sub_agents=[drafting_agent],
    max_iterations=5
)

runner = InMemoryRunner(agent=iterative_refinement_loop, app_name="LoopRefineApp")
session_id = "s_loop_refine"
user_id = "loop_user"

async def main():
    initial_prompt = "ADKのメリットについて短い段落をドラフト。初期ドラフト: 'ADKはツールキットです。'"
    user_message = Content(parts=[Part(text=initial_prompt)], role="user")
    print(f"YOU: {initial_prompt}")

    initial_state = {"current_draft": "ADKはツールキットです。"}
    # セッション作成時に初期状態を設定（本来はcreate_session実装に含めるべき）
    # ここではSimplified

    async for event in runner.run_async(
        user_id=user_id,
        session_id=session_id,
        new_message=user_message
    ):
        current_session = await runner.session_service.get_session(
            app_name="LoopRefineApp", user_id=user_id, session_id=session_id
        )
        print(f"  EVENT from [{event.author}] (ループ反復 {current_session.state.get('loop_iteration', 0)}):")
        if event.actions and event.actions.escalate:
            print("    ESCALATEシグナル受信。ループ終了。")

        if event.content and event.content.parts:
            for part in event.content.parts:
                if part.function_call:
                    print(f"    ツール呼び出し: {part.function_call.name}({part.function_call.args})")
                elif part.function_response:
                    print(f"    ツール応答({part.function_response.name}): {part.function_response.response}")

    print(f"\n最終セッション状態: {current_session.state}")

asyncio.run(main())
```

**実行フロー:**
1. `iterative_refinement_loop`（LoopAgent）開始
2. `drafting_agent.run_async()` 呼び出し
3. `drafting_agent` がドラフト生成/改善し、`check_draft_quality(draft=..., tool_context=...)` 呼び出し
4. `check_draft_quality` ロジック:
   - 終了条件満たす → `exit_loop(tool_context)` 呼び出し → `tool_context.actions.escalate = True`
   - イベント内に `escalate` フラグが含まれる
5. `LoopAgent` がイベント検査: `event.actions.escalate` が `True` ならループ終了
6. `escalate` が `False`（または未設定）かつ `max_iterations` 未到達なら、ステップ2に戻る

**ベストプラクティス:**
> LoopAgent内の子Agentには、`exit_loop` を呼び出す明確なロジックと指示を持たせてください。また、無限ループを防ぐため、LoopAgent自体に妥当な `max_iterations` を常に設定してください。

---

## 6. LangGraph統合（高度な状態管理・循環ロジック）

### 6.1 LangGraphAgentの概要

**特徴:**
- [LangGraph](https://langchain-ai.github.io/langgraph/) はLangchainチームによる、堅牢でステートフルなマルチAgentアプリケーションを循環グラフとして構築するライブラリ
- ADKは `LangGraphAgent` で LangGraph `CompiledGraph` をラップ可能
- ADKの `Runner` が `LangGraphAgent` を呼び出し、LangGraphが定義されたフローを実行

**LangGraphのコア概念:**
- **State Graph**: 状態スキーマとノード・エッジのグラフ定義
- **Nodes**: Pythonの関数またはLangchain Runnableで、状態を操作
- **Edges**: ノード間の遷移を定義（条件分岐可能）
- **Checkpointer**: グラフの状態を永続化し、再開可能な長期実行Agent処理を実現

**用途:**
- 階層的でも順次的でもない、循環・複雑な条件ロジックを持つAgent処理
- 長期実行の再開可能なAgentプロセス
- 強固な状態永続化が必要な場合

**コード例（概念的）:**
```python
from google.adk.agents import Agent as AdkAgent
from google.adk.agents.langgraph_agent import LangGraphAgent
from google.adk.runners import InMemoryRunner
from google.genai.types import Content, Part
import asyncio

# 環境変数を読み込み
# ... load_environment_variables() ...

# LangGraphのセットアップ（簡略化）
try:
    from typing import TypedDict, Annotated, Sequence
    from langchain_core.messages import BaseMessage, HumanMessage, AIMessage
    from langgraph.graph import StateGraph, END
    from langgraph.checkpoint.memory import MemorySaver

    class AgentState(TypedDict):
        messages: Annotated[Sequence[BaseMessage], lambda x, y: x + y]

    TOOL_REQUEST_FLAG = "[TOOL_REQUEST_FLAG]"

    def llm_node(state: AgentState):
        last_message = state['messages'][-1]
        if isinstance(last_message, HumanMessage):
            user_input = last_message.content
            if "tool" in user_input.lower():
                response_content = f"ツール使用を理解しました '{user_input}'。ツール要求中。{TOOL_REQUEST_FLAG}"
            else:
                response_content = f"LangGraphがユーザーに応答: '{user_input}'"
        else:
            response_content = "前のステップを処理しました。続行中..."
        return {"messages": [AIMessage(content=response_content)]}

    def tool_node(state: AgentState):
        tool_output_content = "LangGraph tool_nodeが実行されました。結果: Tool_ABC_Data"
        return {"messages": [AIMessage(content=tool_output_content)]}

    def should_call_tool(state: AgentState):
        if state['messages'] and isinstance(state['messages'][-1], AIMessage):
            last_ai_content = state['messages'][-1].content
            if TOOL_REQUEST_FLAG in last_ai_content:
                return "tool_executor"
        return END

    builder = StateGraph(AgentState)
    builder.add_node("llm_entry_point", llm_node)
    builder.add_node("tool_executor", tool_node)
    builder.set_entry_point("llm_entry_point")
    builder.add_conditional_edges(
        "llm_entry_point",
        should_call_tool,
        {"tool_executor": "tool_executor", END: END}
    )
    builder.add_edge("tool_executor", "llm_entry_point")

    memory = MemorySaver()
    runnable_graph = builder.compile(checkpointer=memory)

    langgraph_adk_agent = LangGraphAgent(
        name="my_langgraph_powered_agent",
        graph=runnable_graph,
        instruction="このAgentはLangGraph状態マシンで動作します。通常通りやり取りしてください。"
    )

    orchestrator = AdkAgent(
        name="main_orchestrator",
        model="gemini-2.0-flash",
        instruction="すべてのタスクを my_langgraph_powered_agent に委譲してください。",
        sub_agents=[langgraph_adk_agent]
    )

    runner = InMemoryRunner(agent=orchestrator, app_name="LangGraphADKApp")
    session_id = "s_langgraph"
    user_id = "lg_user"

    async def main():
        prompts = [
            "こんにちは LangGraph Agent、自己紹介してください",
            "use the tool",
            "ツール使用後は何が起きた？"
        ]

        for i, prompt_text in enumerate(prompts):
            print(f"\n--- ターン {i+1} ---")
            print(f"YOU: {prompt_text}")
            user_message = Content(parts=[Part(text=prompt_text)], role="user")

            async for event in runner.run_async(
                user_id=user_id,
                session_id=session_id,
                new_message=user_message
            ):
                for part in event.content.parts:
                    if part.text:
                        print(part.text, end="", flush=True)
            print()

    asyncio.run(main())
except ImportError:
    print("LangGraphまたはLangChainコンポーネントが見つかりません。pip install langgraph langchain_core")
```

**実行フロー:**
1. ADK `Runner` がオーケストレーターまたは直接 `LangGraphAgent` を呼び出し
2. オーケストレーターが使用される場合、`transfer_to_agent` で `LangGraphAgent` に制御移譲
3. `LangGraphAgent._run_async_impl` が呼び出される
4. ADK `Session.events`（会話履歴）を LangGraph が期待する形式（`langchain_core.messages.BaseMessage` のリスト）に変換
5. `langgraph_compiled_graph.invoke()` を実行（`thread_id` として ADK の `session_id` を使用）
6. LangGraphグラフが定義されたノード・エッジのフローを実行
7. LangGraphの最終状態（通常は最後のメッセージ）を ADK `Event`（テキストコンテンツ）に変換してyield

**ベストプラクティス:**
> LangGraphAgentは、Agent処理の特に複雑な部分をカプセル化するのに適しています。ADKオーケストレーターAgentが、LangGraphの循環グラフ機能の恩恵を受けるサブタスクを LangGraphAgent に委譲し、全体のマルチAgentシステムはADKの階層パターンで管理するという使い方が有効です。

**LangGraphAgent利用判断:**

| 要素 | 値 |
|-----|-----|
| **循環ロジック** | タスクが本質的に循環的（ループ、条件分岐、human-in-the-loopが必要） |
| **複雑な状態管理** | LLM間で複雑な状態遷移が必要で、ADKの線形フローでは表現困難 |
| **チェックポイント** | 長期実行タスクで中断・再開が必要（LangGraphのCheckpointer機能） |
| **既存LangGraph資産** | 既にLangGraphで構築したグラフ資産をADKに統合したい |
| **注意点** | 実験的機能。LangGraphとADKの状態・メッセージ形式の互換性確保が必要 |

**LangGraphAgentのキーコンセプト:**
- **State Graph**: 状態スキーマ（PydanticまたはTypedDict）を定義し、ノード間で状態を受け渡す
- **Nodes**: 状態を操作するPython関数またはLangchain Runnables
- **Edges**: ノード間の遷移を定義（多くは状態や出力に基づく条件付き）
- **Checkpointer**: 状態を永続化（LangChainRedis等）し、再開可能なAgent相互作用を実現

---

## 7. A2Aプロトコル（Agent-to-Agent通信）

### 7.1 A2Aの概要と目的

**A2A（Agent-to-Agent Communication Protocol）:**
- Google主導のオープン標準
- 独立したAI Agentシステム間でのシームレスな通信・相互運用を実現
- 異なるフレームワーク、異なる企業、異なるサーバーで構築されたAgentも連携可能

**目的:**
- **サイロの打破**: 多様なエコシステム・技術スタック間のAgent接続
- **複雑な協調**: 専門化されたAgentがタスクを委譲し、コンテキストを共有し、単独では達成できない目標に協力
- **オープン標準の推進**: コミュニティ主導でAgent通信を発展させ、イノベーションと広範な採用を促進
- **透明性の保持**: 内部状態やツール実装を公開せず、宣言された能力に基づいてAgent連携。セキュリティと知的財産保護

**ADKとの関係:**
- ADKの主要マルチAgent機能は単一 `Runner` プロセス内での「Agent Transfer」
- A2A対応により、ADK AgentシステムをA2Aサーバーとして公開したり、ADK AgentからA2Aクライアントとして外部Agentを呼び出すことが可能

### 7.2 A2Aコア概念

**主要コンポーネント:**

| 概念 | 説明 |
|-----|------|
| **AgentCard** | Agent の「デジタル名刺」。JSON メタデータドキュメント（`/.well-known/agent.json` で公開）。名前、説明、能力（ストリーミング、プッシュ通知等）、セキュリティスキーム、入出力モード、スキル（特定能力の詳細）を含む。 |
| **Task** | 作業単位。A2Aサーバーがメッセージ受信時にタスクを作成。一意の `id` と `contextId`（関連タスクをグループ化）を持つ。`TaskStatus` と `TaskState`（`submitted`, `working`, `completed` 等）を管理。 |
| **Message** | クライアント・サーバー間の通信ターン。`role`（"user" または "agent"）と `parts`（実際のコンテンツ）を持つ。 |
| **Part** | Message/Artifact内の最小コンテンツ単位。`TextPart`（テキスト）、`FilePart`（ファイル、bytes または uri 参照）、`DataPart`（構造化JSONデータ）のいずれか。 |
| **Artifact** | Agentがタスクで生成した具体的な出力（レポート、画像、データ結果等）。`artifactId`, `name`, `description`, `parts` を含む。 |

**通信:**
- **HTTP(S)必須**
- **JSON-RPC 2.0** フォーマット
- `Content-Type: application/json`

### 7.3 主要A2A RPCメソッド

| メソッド | 説明 | 用途 |
|---------|------|------|
| **`message/send`** | クライアントが `Message` を送信してタスクを開始・継続。サーバーは `Task` オブジェクトまたは直接 `Message` で応答。 | 同期・短時間処理 |
| **`message/stream`** | クライアントが `Message` を送信し、Server-Sent Events (SSE) でリアルタイム更新を受信。サーバーは `capabilities.streaming: true` が必要。`TaskStatusUpdateEvent`, `TaskArtifactUpdateEvent`, 新しい `Message` を配信。最終イベントは `final: true` でマーク。 | リアルタイムフィードバック、インタラクティブ体験 |
| **`tasks/get`** | 特定 `Task` の現在状態を `id` で取得。 | ポーリングによるステータス確認 |
| **`tasks/cancel`** | 実行中タスクのキャンセル要求。更新された `Task` オブジェクトを返す（状態は `canceled` に）。 | 長期タスクの中断 |
| **`tasks/pushNotificationConfig/set/get`** | プッシュ通知設定管理。クライアントがwebhook URLを提供し、A2Aサーバーが長期タスクの更新をPOST。サーバーは `capabilities.pushNotifications: true` が必要。 | 非常に長期タスク、モバイルアプリ、サーバーレス |
| **`tasks/resubscribe`** | 中断されたSSEストリームへの再接続。接続が切断された場合の復旧。 | ネットワーク中断後のストリーム再開 |
| **`agent/authenticatedExtendedCard`** | 認証後により詳細な AgentCard を取得（HTTP GET、JSON-RPCではない）。`AgentCard.supportsAuthenticatedExtendedCard: true` の場合に使用可能。 | ユーザー固有の能力・スキル情報の提供 |

### 7.4 インタラクションパターン

| パターン | 説明 | 用途 |
|---------|------|------|
| **同期リクエスト/レスポンス** | `message/send` でリクエスト、サーバーが即座に最終 `Task` または `Message` を返却 | シンプルだが長期タスクには不向き |
| **非同期ポーリング** | `message/send` でタスク開始 → サーバーが `submitted`/`working` 状態のタスクを返却 → クライアントが `tasks/get` で定期的にステータスをポーリング | 長期タスクに対応可能 |
| **SSEストリーミング** | `message/stream` でリクエスト → サーバーがHTTP接続を保持し、SSEイベント（ステータス、メッセージ、Artifactチャンク）をプッシュ | リアルタイムフィードバック |
| **プッシュ通知** | タスク開始時にwebhook URL提供 → クライアント切断可能 → タスク状態変化時にサーバーがwebhookにPOST → クライアントwebhookが通知受信後 `tasks/get` 実行 | 非常に長期タスク（分/時間/日単位）やモバイルアプリ |

### 7.5 ADKとA2A統合

**ADK AgentをA2Aサーバーとして公開:**
1. ADK Agent システムの `AgentCard` を定義
2. `a2a-sdk` の `AgentExecutor` を実装し、A2A `message/send` または `message/stream` リクエストをADK `runner.run_async()` 呼び出しに変換
3. ADK `Event` ストリームをA2A `TaskStatusUpdateEvent`, `TaskArtifactUpdateEvent`, 最終 `Task` オブジェクトに変換してSSE送信またはJSON-RPC応答
4. Webサーバー（FastAPI/Starlette等）でA2Aエンドポイントを公開

**ADK AgentをA2Aクライアントとして使用:**
- カスタム ADK `BaseTool`（または `FunctionTool`）を作成
- ツールがターゲットA2A AgentのURL（またはAgentCard取得方法）とユーザーリクエストを受け取る
- HTTPクライアント（`aiohttp`）や `a2a-sdk` クライアントライブラリを使用してA2Aリクエストを送信
- A2Aレスポンス（`Task` IDやSSEストリーム）を処理し、結果サマリーを呼び出し元ADK Agentに返却

**コード例（概念的 - ADK Tool as A2A Client）:**
```python
from google.adk.tools import BaseTool, ToolContext
from google.genai.types import FunctionDeclaration, Schema, Type
import httpx

class RemoteA2AAgentTool(BaseTool):
    def __init__(self, name: str, description: str, target_agent_card_url: str):
        super().__init__(name=name, description=description)
        self.target_agent_card_url = target_agent_card_url
        # 実際のツールではここでAgentCardを取得・解析して
        # target_agent_url と capabilities を把握する
        self.target_agent_api_endpoint = "extracted_or_known_from_card"

    def _get_declaration(self) -> FunctionDeclaration:
        return FunctionDeclaration(
            name=self.name,
            description=self.description,
            parameters=Schema(type=Type.OBJECT, properties={
                "user_prompt": Schema(type=Type.STRING, description="リモートA2A Agentに送信するプロンプト")
            }, required=["user_prompt"])
        )

    async def run_async(self, args: dict[str, any], tool_context: ToolContext) -> dict:
        user_prompt = args.get("user_prompt")
        if not user_prompt:
            return {"error": "user_promptが必要です"}

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
                response = await client.post(self.target_agent_api_endpoint, json=a2a_request_payload, timeout=30.0)
                response.raise_for_status()
                a2a_response = response.json()
                return {"status": "success", "remote_agent_response": a2a_response.get("result", {})}
        except httpx.HTTPStatusError as e:
            return {"error": f"A2A HTTP error: {e.response.status_code} - {e.response.text}"}
        except Exception as e:
            return {"error": f"A2A request failed: {str(e)}"}

# 使用例:
# remote_invoice_tool = RemoteA2AAgentTool(
#     name="query_remote_invoice_agent",
#     description="リモートのA2A準拠請求書Agentにクエリを送信",
#     target_agent_card_url="https://finance.example.com/.well-known/agent.json"
# )
# my_adk_agent = Agent(..., tools=[remote_invoice_tool])
```

**A2Aで真のフレームワーク間協調を実現:**
> LangGraph、CrewAI、Semantic Kernel等、他のフレームワークで構築されたAgentとADK Agentを連携させる場合、A2Aインターフェース（サーバーラッパーまたはクライアントツール）を実装・使用することで実現できます。

### 7.6 A2Aセキュリティとベストプラクティス

**認証・認可:**
- **HTTPS必須**: 本番環境ではすべての通信をHTTPS経由で行う
- **認証スキーム**: `AgentCard.securitySchemes` で宣言（OAuth2、OIDC、APIキー等）
- **リクエストごと認証**: A2Aサーバーは全リクエストを認証必須（クレデンシャルはHTTPヘッダーで渡す）
- **認可**: サーバー側で認証されたクライアントIDとポリシーに基づいて実施

**プッシュ通知セキュリティ:**
- **Webhook URL検証**: サーバーはSSRF攻撃防止のためwebhook URLを慎重に検証
- **通知認証**: クライアントのwebhook受信側はサーバーからの通知を強力に認証
- **推奨メカニズム**: サーバーからクライアントwebhookへの認証（HMAC署名等）

**入力検証:**
- サーバーは全RPCパラメータとメッセージ/アーティファクトコンテンツを検証

**メディアタイプの活用:**
- `defaultInputModes` / `defaultOutputModes`: Agentがサポートするメディアタイプ（MIME types）を明示
  - 例: `"text/plain"`, `"application/json"`, `"image/png"`
- スキル単位で入出力モードを上書き可能
- クライアントはAgentCardから対応フォーマットを確認し、適切なデータ形式で送信

**TaskStateのライフサイクル:**

| State | 説明 |
|-------|------|
| `submitted` | タスクが受理され、処理待ち |
| `working` | タスク処理中 |
| `input-required` | Agentがクライアントから追加情報を要求 |
| `auth-required` | Agentがユーザーからのセカンダリ認証を要求 |
| `completed` | タスク正常完了 |
| `failed` | タスク失敗 |
| `canceled` | タスクがキャンセル |
| `rejected` | サーバーがタスクを拒否 |
| `unknown` | 不明な状態 |

**A2A vs MCPの関係:**
- **MCP (Model Context Protocol)**: AIモデル/AgentがツールやAPIをどう使用するかにフォーカス（関数呼び出し）
- **A2A**: 独立したAI Agent同士がピアとしてどう通信・協調するかにフォーカス
- **組み合わせ**: A2AサーバーAgentは内部でMCPを使用して独自のツールセットにアクセス可能

---

## AskUserQuestionの配置指示

**MASアーキテクチャ選択時:**
```python
AskUserQuestion(
    questions=[{
        "question": "マルチAgentアーキテクチャパターンを選択してください",
        "header": "MASパターン選択",
        "options": [
            {
                "label": "階層型（Orchestrator-Specialist）",
                "description": "親Agentが子Agentにタスクを委譲。明確な役割分担。"
            },
            {
                "label": "パイプライン型（Sequential）",
                "description": "固定された順次処理。各Agentが前Agentの出力を使用。"
            },
            {
                "label": "並列型（Ensemble）",
                "description": "複数Agentが同時実行。結果を統合・投票・選択。"
            },
            {
                "label": "反復型（Loop）",
                "description": "反復的改善・リトライ・条件待機が必要な場合。"
            },
            {
                "label": "複雑な状態管理（LangGraph）",
                "description": "循環ロジック、複雑な条件分岐、長期実行・再開可能なAgent処理。"
            }
        ],
        "multiSelect": False
    }]
)
```
