# Agent と Tools 詳細ガイド（書籍統合版）

## 目次

1. [Agent概念と分類体系](#agent概念と分類体系)
2. [LlmAgent（Agent）詳細](#llmagentAgent詳細)
3. [ワークフローAgents](#ワークフローagents)
4. [マルチAgent設計パターン](#マルチagent設計パターン)
5. [YAML設定による宣言的Agent定義](#yaml設定による宣言的agent定義)
6. [FunctionTool](#functiontool)
7. [Pre-built Tools](#pre-built-tools)
8. [OpenAPI統合](#openapi統合)
9. [MCP統合](#mcp統合)
10. [Action Confirmations](#action-confirmations)
11. [Tool Performance（並列実行最適化）](#tool-performance並列実行最適化)
12. [Agent設計ベストプラクティス](#agent設計ベストプラクティス)

---

## Agent概念と分類体系

### Agentとは何か

AIエージェントは、チャットボットとは根本的に異なる存在である。

| 観点 | チャットボット | AIエージェント |
|------|--------------|--------------|
| 「フライトを予約して」 | 「いくつかの航空会社を..」（情報提供） | JAL便を予約、確認番号#JL4829（実行） |
| 「APIが落ちていますか？」 | 「確認するには...」（手順説明） | /usersエンドポイントが503返却。チームに通知済み |
| 「競合調査してレポートを」 | 「私の知識では...」（知識提示） | レポート完成。12社分析、PDF生成 |

**Agentの四つのコア能力（Perceive-Think-Act-Learn ループ）:**
1. **Perceive（知覚）**: 環境を観察（メッセージ、API応答、ファイル）
2. **Think（思考）**: LLMが次の行動を決定（ツール呼び出し、委譲、質問）
3. **Act（行動）**: ツール実行、DB照会、メッセージ送信
4. **Learn（学習）**: 結果を観察し、次のイテレーションに反映

### Agentの構成要素

| 構成要素 | 人間での例え | 役割 |
|---------|------------|------|
| LLM（モデル） | 脳 | 推論・計画・意思決定 |
| Instructions | 個性・研修 | AgentのペルソナとルールをLLMに伝える |
| Tools | 手足 | 実世界との相互作用手段 |
| Memory | ノート・ファイル | 文脈と過去のやり取りを記憶 |
| Sub-Agents | チームメンバー | 専門領域を持つ委譲先Agent |

### Agent分類体系

書籍の観点からADKで実装できるAgentを分類する。

#### 機能特性による分類

| Agent種類 | ADKクラス | 特性 |
|----------|---------|------|
| **Reactive Agent** | `LlmAgent (Agent)` | 入力に対してリアクティブに応答。ツールを使って即座に行動 |
| **Deliberative Agent** | `LlmAgent` + planner | 計画を立ててから行動。複数ステップのタスクを熟考 |
| **Goal-Oriented Agent** | `LoopAgent` + quality_check | 品質目標が達成されるまで反復改善 |
| **Orchestrator Agent** | `LlmAgent` + sub_agents | 複数の専門Agentを調整・委譲するルーター |

#### ワークフロー実行パターンによる分類

| Agent種類 | ADKクラス | 実行パターン |
|----------|---------|------------|
| **LlmAgent** | `Agent` | LLMが思考・ツール選択・応答を担う汎用Agent |
| **SequentialAgent** | `SequentialAgent` | 複数AgentをA→B→Cの順で直列実行 |
| **ParallelAgent** | `ParallelAgent` | 複数Agentを同時並列実行 |
| **LoopAgent** | `LoopAgent` | 条件達成まで反復実行 |
| **CustomAgent** | `BaseAgent`継承 | 独自制御フローを実装したカスタムAgent |

---

## LlmAgent（Agent）詳細

### Agent定義の基本

```python
from google.adk.agents import Agent  # LlmAgentのエイリアス

agent = Agent(
    name="example_agent",         # 必須: Agent識別子（snake_case推奨）
    model="gemini-2.0-flash",     # 必須: LLMモデル
    instruction="あなたは...",     # 推奨: システムプロンプト
    description="このAgentは...",  # マルチAgent時に重要（ルーターが参照）
    tools=[...],                  # オプション: ツールリスト
    sub_agents=[...],             # オプション: サブAgentリスト（ルーター用）
    planner=...,                  # オプション: プランナー（Deliberative Agent用）
    generate_content_config=...,  # オプション: LLM設定
    before_agent_callback=...,    # オプション: Agent実行前コールバック
    after_agent_callback=...,
    before_model_callback=...,    # オプション: LLM呼び出し前コールバック
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
- 固定文字列をLLMに送信
- 全リクエストで同じ指示が適用される
- 単純で予測可能なAgent動作に適切

#### Dynamic Instructions（InstructionProvider）

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

**InstructionProvider の要件:**
- `ReadonlyContext` を受け取り `str` を返す関数（または `async def`）
- `context.state` から状態を読み取り可能
- 自動状態注入（`{変数名}`）はInstructionProvider使用時は**無効**（`context.state.get()` で明示的に取得する）

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
        top_p=0.95,
        top_k=40,
        max_output_tokens=1024,
        stop_sequences=["END"],
        safety_settings=[
            SafetySetting(
                category=HarmCategory.HARM_CATEGORY_HARASSMENT,
                threshold=HarmBlockThreshold.BLOCK_NONE
            )
        ],
        response_mime_type="application/json",  # 構造化出力
        response_schema=...         # Pydantic Modelから生成したスキーマ
    )
)
```

**主要パラメータ:**

| パラメータ | 説明 | 推奨値 |
|----------|------|--------|
| `temperature` | ランダム性制御（0.0〜1.0） | 事実: 0.0-0.3, 創造: 0.7-1.0 |
| `top_p` | 累積確率サンプリング | 0.95（デフォルト） |
| `max_output_tokens` | 生成トークン数上限 | タスクに応じて調整 |
| `safety_settings` | コンテンツ安全フィルタ | HarmCategory別に設定 |
| `response_mime_type` | レスポンス形式 | `application/json`（構造化出力） |

**ADK固有の制約（設定しない項目）:**
- `system_instruction` → `LlmAgent.instruction` を使用
- `tools` → `LlmAgent.tools` を使用
- `thinking_config` → `LlmAgent.planner` を使用

### Callbacks（コールバック）

```python
from google.adk.agents.callback_context import CallbackContext
from google.adk.models.llm_request import LlmRequest
from google.adk.models.llm_response import LlmResponse
from google.genai.types import Content, Part
from typing import Optional

# before_agent_callback: ユーザー入力前に実行
def validate_user(context: CallbackContext) -> Optional[Content]:
    if "blocked" in context.state.get("user:flags", []):
        return Content(parts=[Part(text="申し訳ありません、リクエストを処理できません。")])
    return None  # Noneで通常実行継続

# before_model_callback: LLM呼び出し前に実行
async def modify_prompt(
    context: CallbackContext, llm_request: LlmRequest
) -> Optional[LlmResponse]:
    # プロンプト修正
    if llm_request.contents and llm_request.contents[-1].role == "user":
        llm_request.contents[-1].parts[0].text = (
            f"重要: {llm_request.contents[-1].parts[0].text}"
        )
    return None  # Noneで通常のLLM呼び出し続行

# after_model_callback: LLM応答後に実行
def log_usage(context: CallbackContext, llm_response: LlmResponse) -> Optional[LlmResponse]:
    if llm_response.usage_metadata:
        print(f"トークン使用量: {llm_response.usage_metadata.total_token_count}")
    return None

agent = Agent(
    name="secure_agent",
    model="gemini-2.0-flash",
    instruction="...",
    before_agent_callback=validate_user,
    before_model_callback=modify_prompt,
    after_model_callback=log_usage
)
```

---

## ワークフローAgents

### 3種類のワークフローパターン

実世界のタスクは多くの場合、複数のステップと協調を必要とする。ADKはその構造をコードで表現するための三つのワークフローパターンを提供する。

| パターン | Agent種類 | 使用タイミング | 特徴 |
|---------|---------|------------|------|
| **Assembly Line** | `SequentialAgent` | 各ステップが前の結果に依存する | バトンリレー式。順序が重要 |
| **Parallel** | `ParallelAgent` | タスクが独立している | 同時実行で大幅に高速化 |
| **Refinement Loop** | `LoopAgent` | 品質が反復で向上する | 閾値達成まで繰り返し |

### SequentialAgent（直列実行）

「ブログ記事自動生成」のような複数ステップのワークフロー。各Agentは前のAgentの出力を入力として受け取る。

```python
from google.adk.agents import Agent, SequentialAgent

# ステップ1: リサーチAgent
researcher = Agent(
    name="researcher",
    model="gemini-2.0-flash",
    instruction="""
あなたはリサーチスペシャリストです。
与えられたトピックに関する最新の事実・統計・トレンドを収集してください。
出典を明記し、信頼性の高い情報を優先してください。
""",
    tools=[google_search]
)

# ステップ2: ライターAgent
writer = Agent(
    name="writer",
    model="gemini-2.0-flash",
    instruction="""
あなたはコンテンツライターです。
提供されたリサーチノートをもとに、魅力的なブログ記事を作成してください。
導入・本文・結論の三部構成で書いてください。
"""
)

# ステップ3: エディターAgent
editor = Agent(
    name="editor",
    model="gemini-2.0-flash",
    instruction="""
あなたはプロのエディターです。
提供された記事を以下の観点で改善してください:
- 文法・スペルの修正
- 読みやすさの向上
- 論理的な流れの確認
"""
)

# SequentialAgentで連結
blog_pipeline = SequentialAgent(
    name="blog_pipeline",
    sub_agents=[researcher, writer, editor]
)
```

**特徴:**
- 各サブAgentは独立している（互いを知らない）
- ADKが自動的に出力を次のAgentに渡す
- 関心の分離によりメンテナンスとテストが容易

### ParallelAgent（並列実行）

複数の競合他社を同時に調査するような、独立したタスクの並列処理。

```python
from google.adk.agents import Agent, ParallelAgent

# 同時並列で実行される3つのリサーチAgent
research_company_a = Agent(
    name="researcher_a",
    model="gemini-2.0-flash",
    instruction="Company Aを調査してください。特徴・価格・顧客評価・市場ポジションを収集。",
    tools=[google_search]
)

research_company_b = Agent(
    name="researcher_b",
    model="gemini-2.0-flash",
    instruction="Company Bを調査してください。特徴・価格・顧客評価・市場ポジションを収集。",
    tools=[google_search]
)

research_company_c = Agent(
    name="researcher_c",
    model="gemini-2.0-flash",
    instruction="Company Cを調査してください。特徴・価格・顧客評価・市場ポジションを収集。",
    tools=[google_search]
)

# ParallelAgentで同時実行
competitive_analysis = ParallelAgent(
    name="competitive_analysis",
    sub_agents=[research_company_a, research_company_b, research_company_c]
)
```

**パフォーマンス優位性:**
- 各調査が5秒かかる場合: SequentialAgent = 15秒 vs ParallelAgent = 約5秒
- タスクが独立している場合に最大の効果

### LoopAgent（反復実行）

ドラフト作成→レビュー→改善を品質基準達成まで繰り返す。

```python
from google.adk.agents import Agent, LoopAgent
from google.adk.tools import FunctionTool, exit_loop
from google.adk.tools.tool_context import ToolContext

# ループを終了するかどうかを判断するツール
def check_quality_and_exit(score: int, tool_context: ToolContext) -> str:
    """
    品質スコアを評価し、基準を超えた場合はループを終了する。

    Args:
        score: 品質スコア（1-10）
        tool_context: ToolContext（ADKが自動注入）
    """
    if score >= 8:
        exit_loop(tool_context)  # LoopAgentにループ終了を通知
        return f"品質基準達成（スコア: {score}）。処理を終了します。"
    return f"まだ改善が必要です（スコア: {score}）。次のイテレーションに進みます。"

quality_exit_tool = FunctionTool(func=check_quality_and_exit)

# 反復改善Agent
draft_reviewer = Agent(
    name="draft_reviewer",
    model="gemini-2.0-flash",
    instruction="""
あなたはコンテンツレビュアーです。
提供されたドラフトを改善し、1〜10のスコアで品質を評価してください。
スコアが8以上になったらcheck_quality_and_exitを呼び出してください。
""",
    tools=[quality_exit_tool]
)

# LoopAgentで品質達成まで反復
refinement_loop = LoopAgent(
    name="refinement_loop",
    sub_agents=[draft_reviewer],
    max_iterations=5  # 安全ガード: 無限ループ防止
)
```

**注意事項:**
- `max_iterations` は必ず設定する（無限ループ・コスト超過防止）
- 各イテレーションでLLMが呼び出されるため、コスト監視が重要
- `ExitLoopTool`（`exit_loop`関数）でAgent自身がループ終了を制御

### ワークフローパターンの組み合わせ

実際のシステムでは複数のパターンを組み合わせる。

```python
# コンテンツ制作パイプラインの例
# Sequential: リサーチ → [Parallel: 執筆・校正] → ループ: 最終調整

# ステップ1: リサーチ（単独）
research_agent = Agent(name="researcher", ...)

# ステップ2: 執筆と校正を並列実行
parallel_polish = ParallelAgent(
    sub_agents=[writer_agent, style_checker_agent],
    name="parallel_polish"
)

# ステップ3: 最終品質ループ
final_polish = LoopAgent(
    sub_agents=[final_editor_agent],
    max_iterations=3,
    name="final_polish"
)

# SequentialAgentで3ステップを連結
content_pipeline = SequentialAgent(
    name="content_pipeline",
    sub_agents=[research_agent, parallel_polish, final_polish]
)
```

### ワークフロー選択の判断基準

```
後のステップが前の結果に依存する？ → SequentialAgent
すべてのステップが独立して並列実行できる？ → ParallelAgent
品質が反復により向上する？ → LoopAgent
上記の組み合わせ？ → ネスト化する
```

---

## マルチAgent設計パターン

### なぜマルチAgentか

一つの大きなAgentより専門化した複数Agentが優れている理由:

| 比較軸 | 単一Agent | マルチAgent |
|-------|---------|----------|
| 専門性 | 幅広い指示が必要 | 各Agentが一つのドメインをマスター |
| プロンプトサイズ | すべてのケースをカバーする巨大な指示 | 小さく焦点を絞った指示 |
| コンテキスト効率 | 無関係な情報でトークンを浪費 | 集中したコンテキスト |
| メンテナンス | 請求ルール変更 → 巨大なプロンプト全体を更新 | 請求ルール変更 → 一つのAgentを更新 |
| デバッグ | 問題の原因特定が困難 | どのAgentが問題か即座に判明 |

**専門化の原則**: 専門化は汎化に勝る。請求ポリシーと請求ロジックに特化した請求Agentは、10の異なるドメインに注意を分散させた汎用Agentより優れた意思決定をする。

### パターン1: ルーターパターン

最も一般的なパターン。中央ルーターがすべてのリクエストを受け取り専門Agentへ委譲する。

```python
from google.adk.agents import Agent

# 専門Agentたち
billing_agent = Agent(
    name="billing_specialist",
    description="""
請求関連のすべての問題を処理する専門Agent:
- 返金・払い戻し処理
- 請求書の確認と再発行
- 支払い方法の変更
- サブスクリプションの変更
金銭的な質問にはこのAgentを使用してください。
""",
    instruction="""
あなたは経験豊富な請求スペシャリストです。
返金リクエストには共感的に対応してください。
金額を処理する前に必ず二重確認してください。
""",
    tools=[check_payment_history, process_refund, update_subscription]
)

tech_agent = Agent(
    name="technical_specialist",
    description="""
技術的な問題を処理する専門Agent:
- APIエラーのデバッグ
- 統合サポート
- システムヘルスチェック
「どう使う？」や「なぜ動かない？」の質問に使用してください。
""",
    instruction="あなたは忍耐強い技術専門家です。解決策に飛びつく前に質問を明確にしてください。",
    tools=[check_api_status, debug_integration, search_docs]
)

# ルーターAgent
router = Agent(
    name="customer_support_router",
    description="顧客の問い合わせを適切な専門家にルーティングする",
    instruction="""
あなたはカスタマーサポートのルーターです。
顧客の意図を理解し、最適な専門Agentに委譲してください。
不明な場合は明確にするための質問をしてください。
""",
    sub_agents=[billing_agent, tech_agent]  # LLMが自動的にどちらかを選ぶ
)
```

**ルーティングの仕組み:**
ルーターのLLMは全サブAgentのdescriptionを読み、顧客メッセージに最も適合するAgentを選択する。良いdescriptionがルーティング精度を決定する。

### パターン2: AgentToolパターン（Agent-as-Tool）

サブAgentをツールとしてラップする。親AgentのLLMが条件に応じて呼び出しを決定する。

```python
from google.adk.agents import Agent, AgentTool

# 専門Agentをツールとしてラップ
fact_checker = Agent(
    name="fact_checker",
    description="主張を信頼できるソースと照合して検証する",
    tools=[search_web, check_database]
)

fact_checker_tool = AgentTool(fact_checker)

# AgentToolをツールとして使用
writer_agent = Agent(
    name="content_writer",
    description="記事やブログ記事を執筆する",
    instruction="""
魅力的なコンテンツを作成してください。
不確かな事実については、必ずfact_checkerツールで検証してください。
""",
    tools=[fact_checker_tool, create_document]  # 通常ツールと混在可能
)
```

**sub_agents vs AgentTool の使い分け:**

| 観点 | sub_agents | AgentTool |
|-----|----------|---------|
| 委譲のタイミング | ルーターが必ずどれかを選択 | LLMが条件次第で選択（任意） |
| 適した用途 | 固定カテゴリへのルーティング | 条件付き処理、オプションのステップ |
| 制御フロー | 明示的で強制的 | 柔軟でLLM主導 |
| 例 | 請求/技術/販売の振り分け | 必要なときだけファクトチェック |

**sub_agentsを使う場面:**
- 固定した離散的なカテゴリがある（「請求か技術か」）
- 必ず一つに委譲しなければならない
- ルーター・ヘルプデスク・リクエスト分類システム

**AgentToolを使う場面:**
- 専門Agentの使用が条件付き
- 親AgentのLLMが使うかどうかを決める
- ファクトチェッカー・コードレビュアー・バリデーター

### パターン3: コーディネーターパターン

コーディネーターAgentが複雑なマルチステップ処理を管理する。誰が次に動くかを決定し、ハンドオフを処理する。

```python
# データ分析パイプラインの例
coordinator = Agent(
    name="data_coordinator",
    description="データ分析ワークフロー全体を管理・調整する",
    instruction="""
あなたはデータ分析プロジェクトのコーディネーターです。
以下のステップでタスクを管理してください:
1. データ収集エージェントにデータ取得を依頼
2. 取得したデータを分析エージェントに渡して分析
3. 分析結果をレポートエージェントに渡してレポート作成
4. 完成したレポートをユーザーに提供
""",
    sub_agents=[data_collector, data_analyzer, report_generator]
)
```

### マルチAgentパターン比較

| パターン | 最適な用途 | 長所 | 短所 |
|---------|----------|-----|------|
| ルーター | カスタマーサポート、ヘルプデスク | シンプル・明確・単一エントリーポイント | ルーターがボトルネック |
| スペシャリストネットワーク | リサーチチーム・複雑な分析 | 柔軟・ボトルネックなし | デバッグ困難 |
| コーディネーター | データパイプライン・ETL | 整理された・予測可能 | 柔軟性低い |

---

## YAML設定による宣言的Agent定義

### 設定ファイルアプローチのメリット

Agentが複雑になるにつれ、設定ファイルで宣言的に定義することで、コードと設定を分離できる。

**メリット:**
- 非エンジニアがAgentの振る舞いを変更可能（コードを変えずに）
- コード変更なしのA/Bテスト
- バージョン管理によるAgent定義の管理
- 環境別設定（dev・staging・prod）

### agents.yamlの基本構造

```yaml
# agents.yaml
agents:
  research_agent:
    model: "gemini-2.5-flash"
    name: "ResearchBot"
    description: "情報を検索・分析する専門Agent"
    instructions: |
      あなたはリサーチスペシャリストです。
      常にソースを引用してください。
      複数のソースをクロスリファレンスしてください。
    tools:
      - google_search
      - load_web_page
    max_iterations: 10
    streaming: true

  analyst_agent:
    model: "gemini-2.5-pro"  # 分析にはより強力なモデルを使用
    name: "AnalystBot"
    description: "リサーチ結果を分析しエグゼクティブサマリーを作成する"
    instructions: |
      あなたはデータアナリストです。
      リサーチを統合し、エグゼクティブサマリーを提供してください。
    tools:
      - create_document
      - send_email

  # ルーターAgent（上記をサブAgentとして使用）
  coordinator:
    model: "gemini-2.5-flash"
    name: "Coordinator"
    description: "タスクを適切なAgentに委譲するコーディネーター"
    sub_agents:
      - research_agent
      - analyst_agent
```

### YAMLからAgentを読み込む

```python
import yaml
from google.adk.agents import Agent

def load_agent_from_config(config_path: str, agent_name: str) -> Agent:
    """YAMLファイルからAgent設定を読み込んで生成する"""
    with open(config_path, "r") as f:
        config = yaml.safe_load(f)

    agent_config = config["agents"][agent_name]
    return Agent(
        name=agent_config["name"],
        model=agent_config["model"],
        description=agent_config.get("description", ""),
        instruction=agent_config.get("instructions", ""),
        # toolsはレジストリから解決する
    )

# 使用例
research_agent = load_agent_from_config("agents.yaml", "research_agent")
```

### 環境別設定のベストプラクティス

```yaml
# config/dev.yaml
environment: development
agents:
  support_agent:
    model: "gemini-2.0-flash"  # 開発時は安いモデル
    max_tokens: 500

# config/prod.yaml
environment: production
agents:
  support_agent:
    model: "gemini-2.5-pro"    # 本番は高性能モデル
    max_tokens: 2000
```

---

## FunctionTool

### FunctionToolの動作原理

```
Python関数のシグネチャ（型ヒント）を解析
↓
docstringからツール説明とパラメータ説明を抽出
↓
LLM用のFunctionDeclaration（スキーマ）を自動生成
↓
LLMからの呼び出しをPython関数実行にマッピング
```

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

    Raises:
        ValueError: 無効な演算子が指定された場合
        ZeroDivisionError: divideでoperand2が0の場合

    Example:
        calculate(10, 5, 'divide') returns 2.0
    """
    if operation == 'add':
        return operand1 + operand2
    elif operation == 'subtract':
        return operand1 - operand2
    elif operation == 'multiply':
        return operand1 * operand2
    elif operation == 'divide':
        if operand2 == 0:
            raise ZeroDivisionError("ゼロ除算はできません")
        return operand1 / operand2
    else:
        raise ValueError(f"無効な演算子: '{operation}'")

calculator_tool = FunctionTool(func=calculate)

agent = Agent(
    name="calculator",
    model="gemini-2.0-flash",
    instruction="計算ツールを使って算術演算を実行してください。",
    tools=[calculator_tool]
)
```

### docstringがLLMに与える影響

LLMはdocstringを読む。これは開発者向けではなく、**AIへの指示**である。

**悪いdocstring（LLMが困惑する）:**
```python
def calculate(a, b, operation):
    """計算する。"""  # 型・有効値・エラー状況が不明
    ...
```

**良いdocstring（LLMが正確に使用できる）:**
```python
def calculate(a: float, b: float, operation: str) -> float:
    """
    二つの数値に対して数学的演算を実行します。

    Args:
        a: 最初の数値（intまたはfloat）
        b: 二番目の数値（intまたはfloat）
        operation: 実行する演算 - 'add', 'subtract', 'multiply', 'divide'

    Returns:
        計算結果（float型）

    Raises:
        ValueError: operationが認識できない場合
        ZeroDivisionError: operation='divide'でb=0の場合

    Example:
        calculate(10, 5, 'divide') returns 2.0
    """
```

**良いdocstringの要素:**
- 関数名: ひと目で何をするかわかる
- 型ヒント: ADKが何を期待するか伝える
- Args: 各パラメータの意味と有効値を説明
- Returns: 返却値の構造を説明
- Raises: エラー条件を明記（LLMが適応可能になる）
- Example: LLMに期待するデータ構造を示す

### 型ヒントとPydanticモデル

#### Literal型（列挙値の制限）

```python
from typing import Literal

def set_status(status: Literal["pending", "active", "completed"]) -> str:
    """
    タスクのステータスを設定します。

    Args:
        status: 新しいステータス（'pending', 'active', 'completed'のいずれか）
    """
    return f"ステータスを{status}に設定しました"
```

#### Enum型（より安全な制約）

```python
from enum import Enum

class Operation(str, Enum):
    ADD = "add"
    SUBTRACT = "subtract"
    MULTIPLY = "multiply"
    DIVIDE = "divide"

def calculate_safe(a: float, b: float, operation: Operation) -> float:
    """
    安全な算術演算を実行します。

    Args:
        a: 最初の数値
        b: 二番目の数値
        operation: 実行する演算（add/subtract/multiply/divide）
    """
    ...  # Enumで有効値が保証される
```

### ToolContext（状態・Artifact・Memoryアクセス）

```python
from google.adk.tools import ToolContext
from google.genai.types import Part

async def save_report_and_count(
    content: str,
    tool_context: ToolContext  # ADKが自動注入（型ヒント必須）
) -> dict:
    """
    レポートを作成してArtifactとして保存し、カウンターを更新する。

    Args:
        content: レポートのコンテンツ
        tool_context: ToolContext（ADKが自動注入）
    """
    # 状態の読み取りと更新
    counter = tool_context.state.get("session_counter", 0)
    counter += 1
    tool_context.state["session_counter"] = counter

    # Artifactとして保存
    filename = f"report_{counter}.txt"
    await tool_context.save_artifact(filename, Part(text=content))

    # 長期記憶検索
    # memories = await tool_context.search_memory("過去のレポート")

    return {
        "status": "success",
        "filename": filename,
        "count": counter
    }
```

**ToolContextで利用可能な機能:**

| 機能 | メソッド | 説明 |
|-----|---------|------|
| 状態読み書き | `tool_context.state` | app/user/session/tempスコープ |
| ファイル保存 | `await tool_context.save_artifact(filename, artifact)` | Artifactサービスに保存 |
| ファイル読込 | `await tool_context.load_artifact(filename)` | Artifactから読み込み |
| 記憶検索 | `await tool_context.search_memory(query)` | 長期記憶を検索 |
| 呼び出しID | `tool_context.invocation_id` | 現在のターンID |

### LongRunningFunctionTool

長時間かかる処理（数秒〜数分）に対応したToolタイプ。

```python
from google.adk.tools import LongRunningFunctionTool

async def generate_large_document(
    topic: str,
    word_count: int,
    tool_context: ToolContext
) -> str:
    """
    大規模なドキュメントを生成する長時間処理ツール。
    処理完了まで複数のポーリングが発生します。

    Args:
        topic: ドキュメントのトピック
        word_count: 目標ワード数
        tool_context: ToolContext（ADKが自動注入）
    """
    # 進捗状況を状態に保存
    tool_context.state["generation_progress"] = 0

    # 実際の長時間処理
    result = await heavy_document_generation(topic, word_count)

    tool_context.state["generation_progress"] = 100
    return result

# LongRunningFunctionToolで長時間処理をラップ
long_doc_tool = LongRunningFunctionTool(func=generate_large_document)

agent = Agent(
    name="document_generator",
    model="gemini-2.0-flash",
    instruction="長いドキュメントを生成できます。処理に時間がかかる場合があります。",
    tools=[long_doc_tool]
)
```

**FunctionTool vs LongRunningFunctionTool の使い分け:**

| 項目 | FunctionTool | LongRunningFunctionTool |
|-----|------------|----------------------|
| 処理時間 | 数ミリ秒〜数秒 | 数秒〜数分 |
| ポーリング | なし | ADKが自動ポーリング |
| 用途 | API呼び出し・計算 | レポート生成・大規模処理 |

### Tool Callbacks（ツール横断的な関心事）

```python
from google.adk.tools import BaseTool

async def before_tool_cb(
    tool: BaseTool, args: dict, tool_context: ToolContext
) -> Optional[dict]:
    print(f"ツール '{tool.name}' 実行前: {args}")

    # 認証チェック
    if tool.name == "sensitive_tool" and not tool_context.state.get("user:is_admin"):
        return {"error": "権限がありません"}

    return None  # Noneで通常実行

async def after_tool_cb(
    tool: BaseTool, args: dict, tool_context: ToolContext, tool_response: dict
) -> Optional[dict]:
    # 機密情報マスク
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

### BaseToolによるカスタムTool実装

`EmailStr` などの特殊型や、完全なスキーマ制御が必要な場合に使用する。

```python
from google.adk.tools import BaseTool
from google.genai.types import FunctionDeclaration, Schema, Type as GeminiType
from typing import override, Dict, Any, Optional

class EmailNotificationTool(BaseTool):
    def __init__(self):
        super().__init__(
            name="send_email_notification",
            description="メール通知を送信します"
        )

    @override
    def _get_declaration(self) -> FunctionDeclaration:
        return FunctionDeclaration(
            name=self.name,
            description=self.description,
            parameters=Schema(
                type=GeminiType.OBJECT,
                properties={
                    "to_email": Schema(
                        type=GeminiType.STRING,
                        format="email",         # 明示的なemail形式指定
                        description="送信先メールアドレス"
                    ),
                    "subject": Schema(
                        type=GeminiType.STRING,
                        description="件名（200文字以内）"
                    ),
                    "body": Schema(
                        type=GeminiType.STRING,
                        description="メール本文"
                    )
                },
                required=["to_email", "subject", "body"]
            )
        )

    @override
    async def run_async(
        self, *, args: Dict[str, Any], tool_context: Optional[Any] = None
    ) -> Any:
        to_email = args.get("to_email")
        subject = args.get("subject")
        body = args.get("body")

        # バリデーション
        if "@" not in to_email:
            return {"error": f"無効なメールアドレス: {to_email}"}

        # 実装
        result = await send_email(to_email, subject, body)
        return {"status": "success", "message_id": result.id}
```

---

## Pre-built Tools

### Internet Access Tools

#### google_search

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
- `grounding_metadata.web_search_queries` にクエリ情報
- `grounding_metadata` に出典URLが含まれる

**使用タイミング:** リアルタイム情報・最新ニュース・事実確認が必要な場合

#### VertexAiSearchTool

```python
from google.adk.tools import VertexAiSearchTool
import os

# 必須環境変数:
# GOOGLE_GENAI_USE_VERTEXAI=1
# GOOGLE_CLOUD_PROJECT=your-project
# VERTEX_AI_SEARCH_DATA_STORE_ID=your-data-store-id

vertex_search = VertexAiSearchTool(
    data_store_id=os.getenv("VERTEX_AI_SEARCH_DATA_STORE_ID")
)

agent = Agent(
    name="knowledge_base_agent",
    model="gemini-2.0-flash",
    instruction="社内データストアから情報を検索してください。",
    tools=[vertex_search]
)
```

**使用タイミング:** 社内ドキュメント・プライベートナレッジベース・カスタムデータソースが必要な場合

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

**組み合わせパターン:**
1. `google_search` でURL取得
2. `load_web_page` で詳細コンテンツ取得
3. LLMが内容を要約・分析

**制限:** JavaScript動的生成コンテンツは取得不可（Playwright等が必要）

### Memory Tools

```python
from google.adk.tools import load_memory, preload_memory

# LoadMemoryTool: LLMが明示的にメモリ検索するとき呼び出す
reactive_agent = Agent(
    name="reactive_memory",
    model="gemini-2.0-flash",
    instruction="必要に応じてload_memoryツールで過去の情報を検索してください。",
    tools=[load_memory]
)

# PreloadMemoryTool: ターン開始時に自動的に関連メモリを注入
proactive_agent = Agent(
    name="proactive_memory",
    model="gemini-2.0-flash",
    instruction="過去の会話が自動的に提供されます。それを活用してください。",
    tools=[preload_memory]
)
```

### LoadArtifactsTool

```python
from google.adk.tools import load_artifacts, FunctionTool
from google.adk.tools.tool_context import ToolContext
from google.genai.types import Part

async def create_and_save_report(content: str, tool_context: ToolContext) -> dict:
    """レポートを作成してArtifactとして保存する"""
    filename = "analysis_report.txt"
    await tool_context.save_artifact(filename, Part(text=content))
    return {"status": "success", "filename": filename}

report_tool = FunctionTool(func=create_and_save_report)

agent = Agent(
    name="artifact_manager",
    model="gemini-2.0-flash",
    instruction="レポートを作成し、後で参照できます。load_artifactsで過去のレポートを読み込めます。",
    tools=[report_tool, load_artifacts]  # 保存も読込もできる
)
```

### GetUserChoiceTool

インタラクティブな選択肢をユーザーに提示する。

```python
from google.adk.tools import get_user_choice

agent = Agent(
    name="choice_assistant",
    model="gemini-2.0-flash",
    instruction="""
ユーザーに選択肢を提示する必要があるときは、get_user_choiceツールを使用してください。
選択肢は明確で、選びやすいものにしてください。
""",
    tools=[get_user_choice]
)
```

**UI側での実装が必要:**
1. `get_user_choice` 呼び出しを検出
2. LLMが生成したoptionsを表示
3. ユーザー選択を取得
4. FunctionResponseとして返却

### ExitLoopTool

LoopAgent内でAgentが自律的にループを終了する。

```python
from google.adk.tools import FunctionTool, exit_loop
from google.adk.agents import LoopAgent
from google.adk.tools.tool_context import ToolContext

def evaluate_and_exit_if_done(
    quality_score: int,
    analysis_complete: bool,
    tool_context: ToolContext
) -> str:
    """
    品質を評価し、完了条件を満たした場合はループを終了する。

    Args:
        quality_score: 品質スコア（1-10）
        analysis_complete: 分析が完了したか
        tool_context: ToolContext（ADKが自動注入）
    """
    if quality_score >= 8 and analysis_complete:
        exit_loop(tool_context)  # LoopAgentにループ終了を通知
        return "分析完了。品質基準を達成しました。"
    return f"継続中（スコア: {quality_score}）。改善が必要です。"

exit_tool = FunctionTool(func=evaluate_and_exit_if_done)

loop_child = Agent(
    name="quality_analyst",
    model="gemini-2.0-flash",
    instruction="""
分析を実行し、品質を評価してください。
品質スコアが8以上で分析が完了したら、evaluate_and_exit_if_doneを呼び出してください。
""",
    tools=[analysis_tool, exit_tool]
)

quality_loop = LoopAgent(
    name="quality_loop",
    sub_agents=[loop_child],
    max_iterations=10
)
```

**動作原理:**
- `exit_loop` 呼び出し時に `tool_context.actions.escalate = True` を設定
- `LoopAgent` がこのフラグを検出してループを終了
- Agent自身が「もう十分」と判断してループを制御できる

---

## OpenAPI統合

### OpenAPIToolsetの基本

OpenAPI仕様から自動的にToolを生成する。

**動作原理:**
1. OpenAPI仕様（JSON/YAML）を解析
2. 各`operationId`に対して`RestApiTool`を自動生成
3. パラメータ・リクエストボディ・レスポンススキーマをLLM用に変換

```python
from google.adk.tools.openapi_tool import OpenAPIToolset

spec_str = """
{
  "openapi": "3.0.0",
  "info": {"title": "Pet Store API", "version": "1.0.0"},
  "servers": [{"url": "https://api.example.com/v1"}],
  "paths": {
    "/pets": {
      "get": {
        "summary": "ペット一覧を取得する",
        "operationId": "listPets",
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
    spec_str_type="json"
)

agent = Agent(
    name="petstore_agent",
    model="gemini-2.0-flash",
    instruction="Pet Store APIを使ってペットを管理してください。",
    tools=[toolset]
)
```

**自動生成されるツール:**
- ツール名: `operationId` をsnake_caseに変換（例: `listPets` → `list_pets`）
- 説明: OpenAPI仕様の `summary` と `description`

### 認証ハンドリング

#### APIキー認証

```python
from google.adk.auth import AuthCredential, AuthCredentialTypes
from fastapi.openapi.models import APIKey, APIKeyIn

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

#### Bearer Token

```python
from google.adk.tools.openapi_tool.auth.auth_helpers import token_to_scheme_credential

bearer_token = "Bearer YOUR_ACCESS_TOKEN"

auth_scheme, auth_credential = token_to_scheme_credential(
    token_type="apikey",
    location="header",
    name="Authorization",
    credential_value=bearer_token
)

toolset = OpenAPIToolset(
    spec_str=api_spec,
    spec_str_type="yaml",
    auth_scheme=auth_scheme,
    auth_credential=auth_credential
)
```

### APIHubToolset

Google API HubからスペックをダウンロードしてToolを生成する。

```python
from google.adk.tools.apihub_tool import APIHubToolset
import os

def is_valid_tool(tool, ctx=None) -> bool:
    """ADKパーサーが対応できないツールを除外するフィルター"""
    operation = tool._operation_parser._operation
    if not operation.requestBody or not operation.requestBody.content:
        return True
    for media_type in operation.requestBody.content.values():
        if media_type.schema_ and media_type.schema_.type != 'object':
            return False
    return True

apihub_toolset = APIHubToolset(
    apihub_resource_name=os.getenv("MY_APIHUB_API_RESOURCE_NAME"),
    tool_filter=is_valid_tool,
    auth_scheme=...,
    auth_credential=...
)
```

---

## MCP統合

### MCPToolset

Model Context Protocol（MCP）はAnthropicが2024年に公開したオープン標準。LLMベースのシステムがツール・データソース・サービスと相互作用する方法を定義する。

```
MCP Client（ADKエージェント） ←→ MCP Server（外部サービス）

1. Initialize: Agent「こんにちは、バージョンは？」
2. Discover Tools: Server「利用可能なツールリスト」を返す
3. Call Tool: Agent「このツールを呼び出して」
4. Get Result: Server「結果」を返す
5. Loop: Agentはタスク完了まで繰り返す
```

**直接API呼び出しとの違い:**

| 観点 | 直接APIコール | MCP |
|-----|------------|-----|
| ツール発見 | 手動でAPIドキュメントを記述 | 自動的にツールを発見 |
| フォーマット変更 | プロンプトの更新が必要 | サーバーが自動的に処理 |
| 認証 | LLMがAPIキーを見る可能性 | サーバーが認証を管理 |
| 標準化 | API毎に異なる | 一貫したフォーマット |

```python
from google.adk.tools.mcp_toolset import MCPToolset

# 単一MCPサーバー
mcp_toolset = MCPToolset(
    server_url="http://localhost:8080/mcp",
    timeout=30,
    headers={"Authorization": "Bearer YOUR_TOKEN"},
    tool_filter=lambda tool: tool.name.startswith("allowed_")
)

agent = Agent(
    name="mcp_agent",
    model="gemini-2.0-flash",
    instruction="MCPツールを使って外部システムと連携してください。",
    tools=[mcp_toolset]
)
```

```python
# 複数のMCPサーバーと独自ツールの組み合わせ
weather_mcp = MCPToolset(
    server_name="weather",
    server_params={"command": "python", "args": ["-m", "mcp_weather"]}
)

database_mcp = MCPToolset(
    server_name="database",
    server_params={"command": "node", "args": ["mcp-db-server"]}
)

async def send_alert(message: str) -> None:
    """Slackにアラートを送信する"""
    await slack_client.post(message)

agent = Agent(
    name="multi_source_agent",
    model="gemini-2.0-flash",
    tools=[
        weather_mcp,                    # MCPサーバーのツール群
        database_mcp,                   # 別MCPサーバーのツール群
        FunctionTool(func=send_alert)   # カスタムPython関数
    ]
)
```

**使用タイミング:**
- 外部システム（DB・API・ファイルシステム）との統合
- 既存MCPサーバーの再利用
- Claude Desktop等の他MCPクライアントとの互換性確保

### ApplicationIntegrationToolset

Google Cloud Application Integrationと連携してワークフローを実行する。

```python
from google.adk.tools.application_integration_toolset import ApplicationIntegrationToolset

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

---

## Action Confirmations

### require_confirmationによる実行確認

危険な操作（削除・課金アクション等）に対して、Tool実行前にユーザー確認を要求する。

```python
from google.adk.tools import FunctionTool

def delete_record(record_id: str) -> str:
    """
    レコードを削除する。この操作は取り消せません。

    Args:
        record_id: 削除対象のレコードID
    """
    db.delete(record_id)
    return f"Record {record_id} を削除しました"

delete_tool = FunctionTool(
    func=delete_record,
    require_confirmation=True,  # 実行前にユーザー確認を要求
)
```

**動作フロー:**
1. LLMがToolの実行を決定
2. ADKがユーザーに確認プロンプトを表示
3. ユーザーが承認した場合のみ実行（拒否すると実行しない）

### 動的確認ロジック

条件に基づいて確認要求を切り替える。

```python
from google.adk.tools.tool_context import ToolContext

async def process_payment(
    amount: float,
    tool_context: ToolContext
) -> dict:
    """
    支払いを処理する。高額な場合は事前確認が発生します。

    Args:
        amount: 処理金額（円）
        tool_context: ToolContext（ADKが自動注入）
    """
    threshold = tool_context.state.get("app:payment_threshold", 10000.0)

    if amount > threshold:
        # 閾値を超える場合: 確認情報を返す
        return {
            "status": "confirmation_required",
            "message": f"{amount:,.0f}円の支払いを実行しますか？",
            "amount": amount,
            "risk_level": "high",
            "reversible": False
        }

    # 通常の処理
    result = await payment_service.process(amount)
    return {
        "status": "success",
        "transaction_id": result.id,
        "amount": amount
    }
```

### AgentToolでの確認パターン

```python
from google.adk.agents import Agent, AgentTool

risky_agent = Agent(
    name="deletion_specialist",
    model="gemini-2.0-flash",
    instruction="削除操作を実行します。",
    tools=[delete_tool]
)

agent_tool = AgentTool(
    agent=risky_agent,
    require_confirmation=True  # AgentTool全体に確認を要求
)
```

**確認実装のベストプラクティス:**
- 破壊的操作（削除・上書き）には常に確認を要求
- 課金が発生する操作には金額・内容を明示
- 閾値ベースの動的確認で柔軟性を確保
- 確認メッセージにはアクション内容・対象・影響範囲（特に「取り消せない」）を明記

---

## Tool Performance（並列実行最適化）

### 非同期ツールによる自動並列実行

ADK v1.10.0以降、`async def` で定義されたToolは自動的に並列実行される。

```python
import aiohttp

# ✅ 非同期ツール: 他のツールと並列実行可能
async def fetch_weather(city: str) -> str:
    """
    非同期で天気情報を取得する。

    Args:
        city: 都市名（例: 'Tokyo', 'New York'）
    """
    async with aiohttp.ClientSession() as session:
        async with session.get(f"https://api.weather.com/{city}") as resp:
            return await resp.text()

weather_tool = FunctionTool(func=fetch_weather)
```

**LLMが複数ツールを同時呼び出すと判断した場合、ADKは自動的に並列実行する。**

### パフォーマンス最適化パターン

| シナリオ | テクニック | コード例 |
|---------|----------|--------|
| **HTTP通信** | aiohttp + セッション管理 | `async with aiohttp.ClientSession() as session` |
| **DB操作** | asyncpg等の非同期ドライバ | `async with asyncpg.create_pool(...)` |
| **長時間ループ** | `await asyncio.sleep(0)` でイールド | `for item in items: await asyncio.sleep(0)` |
| **CPU集約処理** | ThreadPoolExecutor + run_in_executor | `await loop.run_in_executor(pool, heavy_fn)` |
| **複数API並列取得** | asyncio.gather | `await asyncio.gather(*tasks)` |

### 複数API並列取得

```python
import aiohttp
import asyncio
from typing import List

async def fetch_multiple_sources(urls: List[str]) -> dict:
    """
    複数のURLから並列にデータを取得する。

    Args:
        urls: 取得対象URLのリスト
    """
    async with aiohttp.ClientSession() as session:
        tasks = [session.get(url) for url in urls]
        responses = await asyncio.gather(*tasks, return_exceptions=True)

        results = {}
        for url, response in zip(urls, responses):
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
from typing import List

def heavy_computation(data: List[float]) -> float:
    """重いCPU処理（同期関数）"""
    return sum(x ** 2 for x in data)

async def compute_async(data: List[float]) -> float:
    """
    CPU集約処理をスレッドプールに委譲する（イベントループをブロックしない）。

    Args:
        data: 計算対象データ
    """
    loop = asyncio.get_event_loop()
    with ThreadPoolExecutor() as pool:
        result = await loop.run_in_executor(pool, heavy_computation, data)
        return result

compute_tool = FunctionTool(func=compute_async)
```

### 同期ツールの制約

```python
import time

# ❌ 悪い例: 同期ツールがパイプライン全体をブロック
def blocking_api_call(endpoint: str) -> str:
    time.sleep(5)  # 全体が5秒停止。他のツールも待機させる
    return "result"

# ✅ 良い例: 非同期で実装（他のツールと並列実行可能）
async def non_blocking_api_call(endpoint: str) -> str:
    await asyncio.sleep(0)  # イベントループに制御を返す
    async with aiohttp.ClientSession() as session:
        async with session.get(endpoint) as resp:
            return await resp.text()
```

**重要:** 同期ツール（`def` 定義）が一つでもあると、そのToolはパイプライン全体をブロックする。

### プロンプトで並列実行を明示的に指示

```python
agent = Agent(
    name="efficient_agent",
    model="gemini-2.0-flash",
    instruction="""
あなたは効率的にツールを使用するアシスタントです。

重要な原則:
- 複数の独立したツール呼び出しは必ず並列に実行してください
- 例: 複数都市の天気を取得する場合、すべてのfetch_weatherを同時に呼び出す
- 前の結果が必要な場合のみ順次実行してください
- 並列実行は処理時間を大幅に短縮します
""",
    tools=[weather_tool, news_tool, stock_tool]
)
```

---

## Agent設計ベストプラクティス

### 命名規則

| 項目 | 規則 | 例 |
|-----|------|---|
| Agent名 | snake_case | `billing_specialist`, `research_agent` |
| Tool関数名 | snake_case、動詞+名詞 | `get_weather`, `process_payment` |
| LoopAgent | `_loop` サフィックス | `quality_refinement_loop` |
| ルーターAgent | `_router` サフィックス | `customer_support_router` |

### descriptionの設計（ルーティング精度の鍵）

マルチAgentシステムでは、ルーターのLLMがdescriptionを読んで委譲先を決定する。

**悪いdescription（曖昧すぎる）:**
```python
agent = Agent(
    name="helper",
    description="ヘルプする",  # LLMがどのケースに使えば良いか判断できない
)
```

**良いdescription（具体的・例示豊富・アクション指向）:**
```python
agent = Agent(
    name="billing_specialist",
    description="""
請求関連のすべての問題を処理する専門Agent:
- 返金・払い戻し処理
- 請求書の確認と再発行
- 支払い方法の変更（クレジットカード・銀行振込）
- サブスクリプションのアップグレード・ダウングレード・キャンセル
金銭的な質問や課金に関するすべての問い合わせにこのAgentを使用してください。
""",
)
```

**良いdescriptionの要素:**
1. **具体的**: 「ヘルプする」ではなく「返金・請求書・支払い変更を処理する」
2. **例示豊富**: カバーするケースを具体的に列挙
3. **アクション指向**: 「いつこのAgentを使うか」を明示
4. **現実的**: 実際にAgentができないことを約束しない

### instructionの設計

```python
# ✅ 良いinstruction: 明確・具体的・ペルソナが明確
instruction = """
あなたは経験豊富な請求スペシャリストです。以下の原則に従ってください:

1. 返金リクエストには必ず共感的に対応する
2. 金額を処理する前に必ず確認する（「〇〇円の返金を処理しますか？」）
3. 処理後は確認番号を必ず提供する
4. 不明な場合は推測せず、確認を求める

利用可能なツール:
- check_payment_history: 支払い履歴を確認
- process_refund: 返金を処理
- send_invoice: 請求書を再送信
"""
```

### コスト最適化戦略

#### ツール統合による削減

```python
# ❌ 非効率: 5つの個別ツール（5つのFunctionDeclarationをコンテキストに追加）
def search_google(query: str): ...
def search_docs(query: str): ...
def search_github(query: str): ...
def search_forum(query: str): ...
def search_internal(query: str): ...

# ✅ 効率的: 1つの統合ツール（コンテキストトークン削減）
def unified_search(
    query: str,
    source: str = "auto"  # 'google', 'docs', 'github', 'forum', 'internal', 'auto'
) -> dict:
    """
    複数のソースを横断して検索する。

    Args:
        query: 検索クエリ
        source: 検索対象 ('google', 'docs', 'github', 'forum', 'internal', 'auto')
    """
    ...
```

#### 構造化出力でトークン削減

```python
agent = Agent(
    name="classifier",
    model="gemini-2.0-flash",
    instruction="""
常に以下のJSON形式で応答してください:
{
  "category": "billing" | "technical" | "sales" | "general",
  "confidence": 0.0-1.0,
  "summary": "最大50文字で要約"
}
他のテキストは追加しないでください。
"""
)
```

### セキュリティチェックリスト

- [ ] 機密情報（APIキー・パスワード）をToolの返り値に含めない
- [ ] Tool Callbackで権限チェックを実装
- [ ] 危険な操作（削除・決済）に `require_confirmation=True` を設定
- [ ] ユーザー入力のバリデーション（Toolの先頭で実装）
- [ ] `after_tool_callback` でレスポンスの機密情報をマスク

### Agent設計チェックリスト

新しいAgentを設計するとき:

```
□ Agentの責務は一つか（単一責任原則）
□ descriptionは具体的で例示が豊富か
□ instructionは明確でペルソナが確立しているか
□ Toolのdocstringは完全か（Args, Returns, Raises, Example）
□ すべてのToolはasync defで定義されているか
□ エラーハンドリングはToolの先頭で実装されているか
□ 危険な操作にrequire_confirmation=Trueを設定したか
□ LoopAgentにmax_iterationsを設定したか
□ マルチAgentのルーティングは正しく機能するか
□ コスト最適化（ツール数・トークン）は検討済みか
```

---

## トラブルシューティング

### ツールが正しく呼び出されない

1. **Trace機能で確認**: Dev UIのTrace viewでLLMに送られたFunctionDeclarationを確認
2. **docstringを改善**: LLMが理解しやすい説明に変更（特にArgsセクション）
3. **パラメータ簡素化**: 複雑なネストスキーマを分割
4. **instructionに使用タイミングを明記**: 「〇〇の場合はXXXツールを使用してください」

### ルーティングが間違ったAgentを選ぶ

1. **descriptionを見直す**: 対象ケースをより具体的に記述
2. **曖昧なケース**: ルーターのinstructionに「不明な場合のデフォルト」を設定
3. **A/Bテスト**: descriptionを変えてルーティング精度を測定

### 認証エラー

1. **環境変数確認**: `GOOGLE_API_KEY`, `GOOGLE_CLOUD_PROJECT`, `GOOGLE_GENAI_USE_VERTEXAI`
2. **IAM権限確認**: Vertex AI・Secret Manager等のアクセス権
3. **トークン有効期限確認**: OAuth2トークンの更新

### パフォーマンス問題

1. **同期ツールを特定**: 全Toolを`async def`に変換
2. **並列実行の確認**: instructionで「独立したツールは並列実行」と指示
3. **CPU処理の委譲**: `run_in_executor`でスレッドプールに移動
4. **ツール数の削減**: 関連するToolを統合してコンテキストトークンを節約
