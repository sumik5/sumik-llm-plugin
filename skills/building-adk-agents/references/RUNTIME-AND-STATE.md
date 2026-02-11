# ランタイムとステート管理

Google ADKの実行環境とステート管理のリファレンス。

---

## 1. Runner

### 1.1 Runnerの役割

`google.adk.runners.Runner`は、ADK Agentシステムの実行エンジン。

**主要責務:**
- Session管理（`BaseSessionService`連携）
- Agent起動（`run_async()`呼び出し）
- `InvocationContext`作成
- `Event`ストリーミング配信
- 入力処理（blob→artifact変換）

**初期化例:**

```python
from google.adk.runners import Runner
from google.adk.sessions import DatabaseSessionService
from google.adk.artifacts import GcsArtifactService

runner = Runner(
    app_name="MyApp",
    agent=my_root_agent,
    session_service=DatabaseSessionService(db_url="sqlite:///./sessions.db"),
    artifact_service=GcsArtifactService(bucket_name="my-artifacts")
)
```

### 1.2 InMemoryRunner

`InMemoryRunner`は全サービスをインメモリで実行。

**特徴:**
- 外部依存なし、高速
- ローカル開発・テスト最適
- プロセス終了でデータ消失（プロダクション不適）

```python
from google.adk.runners import InMemoryRunner
runner = InMemoryRunner(agent=my_agent, app_name="TestApp")
```

### 1.3 InvocationContext

`InvocationContext`は単一ターン実行中の全情報保持。

| 属性 | 説明 |
|-----|------|
| `invocation_id` | ターン固有ID |
| `session` | 現在のSession |
| `agent` | 実行中のAgent |
| `user_content` | ユーザー入力 |
| `run_config` | ランタイム設定 |

### 1.4 RunConfig

`RunConfig`で実行動作カスタマイズ。

| パラメータ | デフォルト | 説明 |
|----------|----------|------|
| `streaming_mode` | `NONE` | `SSE`/`BIDI`選択 |
| `save_input_blobs_as_artifacts` | `False` | 入力blob自動保存 |
| `max_llm_calls` | 500 | LLM呼び出し上限 |
| `speech_config` | `None` | 音声設定（BIDI用） |

**使用例:**

```python
from google.adk.agents.run_config import RunConfig, StreamingMode

sse_config = RunConfig(streaming_mode=StreamingMode.SSE)
async for event in runner.run_async(..., run_config=sse_config):
    print(event.content.parts[0].text, end="", flush=True)
```

---

## 2. Session管理

### 2.1 BaseSessionService

| メソッド | 説明 |
|---------|------|
| `create_session()` | 新規セッション作成 |
| `get_session()` | セッション取得 |
| `append_event()` | イベント追加（state更新） |

### 2.2 Sessionオブジェクト

| 属性 | 説明 |
|-----|------|
| `id` | セッションID |
| `app_name` | アプリケーション名 |
| `user_id` | ユーザーID |
| `events` | イベント時系列リスト |
| `state` | key-valueペア |

### 2.3 Stateスコープ

| プレフィックス | スコープ | 永続化 |
|-------------|---------|--------|
| なし | Session | Session単位 |
| `user:` | User横断 | User単位 |
| `app:` | App全体 | App単位 |
| `temp:` | Invocation内 | されない |

**使用例:**

```python
context.state["current_task"] = "search"  # Session
context.state["user:theme"] = "dark"       # User
context.state["app:announcement"] = "メンテナンス"  # App
context.state["temp:retry"] = 1            # Temporary
```

### 2.4 SessionService実装

| 実装 | 特徴 | 用途 |
|-----|------|------|
| `InMemorySessionService` | Pythonディクショナリ | ローカル開発 |
| `DatabaseSessionService` | SQLAlchemy経由でSQL | セルフホスト |
| `VertexAiSessionService` | Vertex AI管理 | GCPマネージド |

**選択基準:**

- ローカル→`InMemory`
- DB使用→`Database`
- GCPデプロイ→`VertexAi`

**AskUserQuestion:** プロダクション環境でSessionService選択時、ユーザー確認

---

## 3. Artifact管理

### 3.1 BaseArtifactService

| メソッド | 戻り値 |
|---------|--------|
| `save_artifact()` | int（バージョン） |
| `load_artifact()` | Optional[Part] |
| `list_artifact_keys()` | list[str] |

### 3.2 ユースケース

- LLM出力（画像、コード、文書）
- コード実行結果
- ユーザーアップロード
- 中間ツール出力

### 3.3 実装

**InMemoryArtifactService:**
- メモリ内保存、プロセス終了で消失

**GcsArtifactService:**

```python
from google.adk.artifacts import GcsArtifactService
gcs_service = GcsArtifactService(bucket_name="my-bucket")
```

**前提:** GCPプロジェクト、GCS API、バケット、認証、`google-cloud-storage`

### 3.4 LoadArtifactsTool

```python
from google.adk.tools import load_artifacts

agent = Agent(
    name="viewer",
    instruction="artifactが利用可能な場合、load_artifactsで取得",
    tools=[load_artifacts]
)
```

**動作:** LLMにartifact一覧を通知→LLMが`load_artifacts`呼び出し→次ターンで実コンテンツ注入

---

## 4. Memory

### 4.1 BaseMemoryService

| メソッド | 説明 |
|---------|------|
| `add_session_to_memory()` | セッションを記憶に追加 |
| `search_memory()` | queryで検索 |

**SearchMemoryResponse:** `memories: list[MemoryEntry]`

**MemoryEntry:** `content`, `author`, `timestamp`

### 4.2 実装

**InMemoryMemoryService:**
- キーワードベース検索
- プロトタイピング専用

**VertexAiRagMemoryService:**

```python
from google.adk.memory import VertexAiRagMemoryService

rag_service = VertexAiRagMemoryService(
    rag_corpus=f"projects/{project}/locations/{loc}/ragCorpora/{corpus}",
    similarity_top_k=5
)
```

**前提:** Vertex AI、RAG Corpus、認証、`google-cloud-aiplatform[rag]`

**動作:**
- `add_session_to_memory`: JSON lines変換→GCSアップロード→自動インデックス化
- `search_memory`: セマンティック検索→`MemoryEntry`変換

**選択基準:**
- セマンティック検索必要→`VertexAiRag`

**AskUserQuestion:** プロダクション環境でMemoryService選択時、ユーザー確認

### 4.3 ツール

**LoadMemoryTool:**

```python
from google.adk.tools import load_memory
agent = Agent(tools=[load_memory])
```

- LLMが明示的に呼び出し
- `query: str`で検索

**PreloadMemoryTool:**

```python
from google.adk.tools import preload_memory
agent = Agent(tools=[preload_memory])
```

- 各LLMターン前に自動実行
- 現在の`user_content`をクエリに使用
- system instructionに関連記憶をプリペンド

**併用パターン:** `Preload`で自動提供、`Load`で深掘り

---

## 5. Agent評価

### 5.1 評価エコシステム

| コンポーネント | 説明 |
|-------------|------|
| `adk eval` | CLI評価実行 |
| `AgentEvaluator` | プログラマティック評価 |
| `EvalSet` | テストケース集合 |
| `EvalCase` | 単一テストケース |

### 5.2 データ構造

**Invocation:**

```python
{
  "user_content": {"role": "user", "parts": [{"text": "質問"}]},
  "final_response": {"role": "model", "parts": [{"text": "応答"}]},
  "intermediate_data": {"tool_uses": [{"name": "tool", "args": {}}]}
}
```

**EvalCase:** `eval_id`, `conversation: list[Invocation]`, `session_input`（optional）

**EvalSet:** `eval_set_id`, `name`, `description`, `eval_cases: list[EvalCase]`

### 5.3 評価メトリクス

| Evaluator | メトリクス | スコア範囲 | 用途 |
|----------|-----------|----------|------|
| `TrajectoryEvaluator` | `tool_trajectory_avg_score` | 0-1 | ツール使用正確性 |
| `ResponseEvaluator` | `response_match_score` | 0-1 | ROUGE-1オーバーラップ |
| `ResponseEvaluator` | `response_evaluation_score` | 0-5 | LLMベース品質評価 |

### 5.4 実行

```bash
# CLI
adk eval path/to/agent path/to/tests.evalset.json

# 特定ケース
adk eval path/to/agent tests.evalset.json:case1,case2
```

### 5.5 Dev UI可視化

`adk web`の**Evalタブ**:
- EvalSetロード
- 評価トリガー
- 結果表示（全体スコア、ケース別、トレースリンク）

**ベストプラクティス:** 評価失敗時はDev UI Evalタブ→トレースビューでデバッグ

---

## 6. Context階層

ADKでは複数のコンテキストクラスが階層構造を形成し、実行フェーズごとに異なるアクセス権を提供する。

### 6.1 階層構造

```
InvocationContext（最上位）
  └─ ReadonlyContext（Agent読み取り用）
       └─ CallbackContext（Callback内状態変更）
            └─ ToolContext（Tool実行用）
```

| コンテキスト | 用途 | 主なアクセス可能フィールド |
|------------|------|--------------------------|
| `InvocationContext` | Runner内部実行管理 | `agent_name`, `session`, `invocation_id` |
| `ReadonlyContext` | Agent読み取り専用 | `session`, `state`（読み取りのみ） |
| `CallbackContext` | Callback内状態変更 | `state`（読み書き）、`artifact_service` |
| `ToolContext` | Tool実行コンテキスト | `CallbackContext`のすべて + ツール操作メソッド |

### 6.2 InvocationContext

最上位コンテキスト。Runner内部でのターン実行全体を管理。

**主要フィールド:**
- `invocation_id: str` - 一意なターンID
- `session: Session` - 現在のセッション
- `agent: Agent` - 実行中のAgent
- `user_content: Content` - ユーザー入力
- `run_config: RunConfig` - 実行設定

### 6.3 ReadonlyContext

Agent本体に渡されるコンテキスト。状態を読み取るが変更はできない。

**使用例:**
```python
@Agent.callback("before")
def read_state(ctx: ReadonlyContext):
    theme = ctx.state.get("user:theme", "light")
    print(f"Current theme: {theme}")
```

### 6.4 CallbackContext

Callback（before/after）内でのみ利用可能。状態変更とArtifact保存が可能。

**使用例:**
```python
@Agent.callback("after")
def save_result(ctx: CallbackContext):
    ctx.state["last_run"] = datetime.now().isoformat()
    # Artifactを保存
    artifact_part = Part(text="result data")
    ctx.artifact_service.save_artifact(
        session_id=ctx.session.id,
        key="result_artifact",
        part=artifact_part
    )
```

### 6.5 ToolContext

Tool実行中に渡される。`CallbackContext`を拡張し、追加のツール操作メソッドを提供。

**使用例:**
```python
from google.adk.tools import FunctionTool, ToolContext

def advanced_tool(query: str, ctx: ToolContext):
    # 状態読み書き
    ctx.state["tool_calls"] = ctx.state.get("tool_calls", 0) + 1
    # Artifact保存
    result = f"Processed: {query}"
    ctx.artifact_service.save_artifact(
        session_id=ctx.session.id,
        key="tool_output",
        part=Part(text=result)
    )
    return result

tool = FunctionTool(advanced_tool)
```

---

## 7. Context Caching

Gemini 2.0以降で利用可能な機能（ADK v1.15.0+）。長いプロンプトやシステムインストラクションをキャッシュしてAPIコストを削減。

### 7.1 ContextCacheConfig

```python
from google.adk.agents.context_cache_config import ContextCacheConfig
from google.adk.apps.app import App

app = App(
    name='my-caching-agent-app',
    root_agent=root_agent,
    context_cache_config=ContextCacheConfig(
        min_tokens=2048,    # キャッシュ発動の最小トークン数
        ttl_seconds=600,    # キャッシュ有効期間（秒）
        cache_intervals=5,  # 最大再利用回数
    ),
)
```

### 7.2 パラメータ

| パラメータ | デフォルト | 説明 |
|----------|----------|------|
| `min_tokens` | 0 | キャッシュを開始する最小トークン数 |
| `ttl_seconds` | 1800 | キャッシュ有効期間（秒） |
| `cache_intervals` | 10 | キャッシュを再利用できる最大回数 |

**要件:**
- Gemini 2.0以降のモデル
- ADK v1.15.0以降

**ベストプラクティス:**
- `min_tokens=2048`以上を推奨（短すぎるとキャッシュのオーバーヘッドが無駄）
- `ttl_seconds=600`～`1800`が一般的
- 長いsystem instructionやツール定義を持つAgentで効果大

---

## 8. Context Compaction

会話履歴が長くなった際、スライディングウィンドウ方式で古いイベントを要約し、コンテキストサイズを制御（ADK v1.16.0+）。

### 8.1 EventsCompactionConfig

```python
from google.adk.apps.app import App, EventsCompactionConfig
from google.adk.apps.llm_event_summarizer import LlmEventSummarizer
from google.adk.models import Gemini

app = App(
    name='my-agent',
    root_agent=root_agent,
    events_compaction_config=EventsCompactionConfig(
        compaction_interval=3,  # 圧縮トリガーのイベント数
        overlap_size=1,         # オーバーラップ保持数
        summarizer=LlmEventSummarizer(llm=Gemini(model="gemini-2.5-flash")),
    ),
)
```

### 8.2 スライディングウィンドウ方式

**動作イメージ（`compaction_interval=3`, `overlap_size=1`）:**

```
初期: [E1, E2, E3, E4, E5]
↓
圧縮: [Summary(E1, E2, E3), E3, E4, E5]
         ↑要約            ↑オーバーラップ
↓ さらにイベント追加
圧縮: [Summary(E1-E3), Summary(E3, E4, E5), E5, E6, E7]
```

- `compaction_interval`件ごとに古いイベントを要約
- `overlap_size`件のイベントを次ウィンドウに引き継ぎ（文脈の連続性確保）

### 8.3 パラメータ

| パラメータ | デフォルト | 説明 |
|----------|----------|------|
| `compaction_interval` | 10 | 何件ごとに圧縮するか |
| `overlap_size` | 0 | 次ウィンドウに引き継ぐイベント数 |
| `summarizer` | - | `LlmEventSummarizer`インスタンス |

**要件:**
- ADK v1.16.0以降

**ベストプラクティス:**
- 長時間セッション（カスタマーサポート、マルチターンタスク）で有効
- `overlap_size=1`～`2`で文脈の連続性を維持
- 高速モデル（`gemini-2.5-flash`）をsummarizerに推奨

---

## 9. Session Rewind

セッションを過去の状態に巻き戻す機能（ADK v1.17.0+）。デバッグやユーザー操作のやり直しに利用。

### 9.1 概要

- セッション履歴の特定イベントまで巻き戻し
- `state`と`events`が指定時点に復元される
- Artifact・Memory等の外部リソースは巻き戻されない

### 9.2 ユースケース

- ユーザーが「1つ前に戻りたい」と要求
- Agent開発中の実行状態デバッグ
- ロールバックテスト

**要件:**
- ADK v1.17.0以降

**注意:**
- 外部副作用（API呼び出し、DB書き込み）は巻き戻されない
- 開発・デバッグ用途が主

---

## 10. Resume Agents

中断されたワークフローを再開する機能（ADK v1.14.0+）。

### 10.1 ResumabilityConfig

```python
from google.adk.agents import Agent
from google.adk.agents.resumability_config import ResumabilityConfig

agent = Agent(
    name="resumable-agent",
    instruction="長時間タスクを実行",
    resumability_config=ResumabilityConfig(
        enable_resumability=True
    )
)
```

### 10.2 rewind_async

```python
from google.adk.runners import Runner

runner = Runner(app_name="MyApp", agent=resumable_agent)

# セッションを特定イベントまで巻き戻して再開
await runner.rewind_async(
    session_id="session123",
    event_id="event456",
    user_content={"role": "user", "parts": [{"text": "やり直し"}]}
)
```

### 10.3 カスタムAgent再開パターン

- Callback内で`ctx.state["checkpoint"]`を保存
- 再開時に`ctx.state["checkpoint"]`から復元
- 中間結果をArtifactに保存しておく

**要件:**
- ADK v1.14.0以降

**ベストプラクティス:**
- 長時間タスク（データ処理、マルチステップワークフロー）で有効
- 外部API呼び出しや重い計算の前にcheckpoint保存

---

## 11. Event System

ADKでは実行中のすべての情報がEventとして管理される。

### 11.1 Event構造

| フィールド | 型 | 説明 |
|----------|---|------|
| `author` | str | ソース識別（`'user'`またはagent名） |
| `invocation_id` | str | インタラクション一意ID |
| `id` | str | イベント一意ID |
| `timestamp` | datetime | 作成時刻 |
| `content` | Content | メッセージ内容（テキスト、関数呼び出し、結果） |
| `partial` | bool | ストリーミングチャンク判定 |
| `actions` | EventActions | 状態変更・制御シグナル |
| `branch` | list[str] | 階層パス |

### 11.2 EventActions

| フィールド | 型 | 説明 |
|----------|---|------|
| `state_delta` | dict | 状態変更マップ |
| `artifact_delta` | dict | Artifact更新マップ |
| `transfer_to_agent` | Optional[str] | Agent転送先 |
| `escalate` | bool | ループ終了シグナル |
| `skip_summarization` | bool | 要約スキップ |

**state_deltaのプレフィックス:**
- なし: Session
- `user:`: User横断
- `app:`: App全体
- `temp:`: Invocation内（永続化されない）

### 11.3 イベントフロー

```
生成（Agent/Tool）→ Runner受信 → SessionService永続化 → session.events追加 → アプリに返却
```

1. AgentやToolがEventを生成
2. Runnerが受信・検証
3. `SessionService.append_event()`で永続化
4. `session.events`リストに追加
5. ストリーミングまたは最終レスポンスとしてアプリに返却

### 11.4 7種類のイベントタイプ

| タイプ | 説明 | `content.parts` 例 |
|-------|------|--------------------|
| User Input | ユーザー入力 | `[Text]` |
| Agent Responses | Agent応答 | `[Text]` |
| Tool Calls | ツール呼び出し | `[FunctionCall]` |
| Tool Results | ツール実行結果 | `[FunctionResponse]` |
| State Updates | 状態変更 | `actions.state_delta` |
| Control Signals | 制御シグナル | `actions.escalate`, `actions.transfer_to_agent` |
| Error Events | エラー | `[Text]`（エラーメッセージ） |

### 11.5 主要メソッド

```python
# Event操作
event.get_function_calls()      # FunctionCall一覧
event.get_function_responses()  # FunctionResponse一覧
event.is_final_response()       # 最終応答判定

# Session操作
session.get_events_by_author("agent1")  # 特定authorのイベント
```

### 11.6 State管理とEvent

**state更新の流れ:**

```python
# Callback内でstate変更
ctx.state["key"] = "value"

# Runnerが自動的にEventActions.state_deltaに記録
event.actions.state_delta = {"key": "value"}

# SessionServiceがsession.stateに反映
session.state["key"] = "value"
```

**ベストプラクティス:**
- Eventログから実行履歴を完全再現可能
- デバッグ時は`session.events`を時系列で確認
- `state_delta`を監視してstate変化を追跡

---

## 12. Evaluation拡張

### 12.1 7つのビルトインメトリクス

ADKは以下のビルトインメトリクスを提供（詳細は公式ドキュメント参照）:

| メトリクス | 用途 | スコア範囲 |
|-----------|------|----------|
| `tool_trajectory` | ツール呼び出しシーケンスの正確性 | 0-1 |
| `response_match` | 応答の一致度（ROUGE-1ベース） | 0-1 |
| `final_response_match_v2` | 最終応答の一致度（v2） | 0-1 |
| `rubric_based_quality` | ルーブリックベース品質評価 | 0-5 |
| `rubric_based_tool_use` | ルーブリックベースツール使用評価 | 0-5 |
| `hallucinations` | ハルシネーション検出 | 0-1 |
| `safety` | 安全性チェック | 0-1 |

**使用例:**
```bash
# 特定メトリクスのみ実行
adk eval path/to/agent tests.evalset.json --metrics tool_trajectory,hallucinations
```

### 12.2 evalsetファイル形式

**JSON形式:**
```json
{
  "eval_set_id": "test-001",
  "name": "Basic Tests",
  "description": "基本動作テスト",
  "eval_cases": [
    {
      "eval_id": "case1",
      "conversation": [
        {
          "user_content": {"role": "user", "parts": [{"text": "質問"}]},
          "final_response": {"role": "model", "parts": [{"text": "期待応答"}]},
          "intermediate_data": {
            "tool_uses": [{"name": "tool1", "args": {"key": "value"}}]
          }
        }
      ]
    }
  ]
}
```

**YAML形式も対応:**
```yaml
eval_set_id: test-001
name: Basic Tests
description: 基本動作テスト
eval_cases:
  - eval_id: case1
    conversation:
      - user_content:
          role: user
          parts:
            - text: "質問"
        final_response:
          role: model
          parts:
            - text: "期待応答"
```

### 12.3 ユーザーシミュレーション

長時間マルチターン会話をテストする際、ユーザー応答を動的に生成。

**使用例:**
```python
from google.adk.evaluation import AgentEvaluator, SimulatedUser

simulated_user = SimulatedUser(
    persona="カスタマーサポートを利用する一般ユーザー",
    goal="配送状況を確認する"
)

evaluator = AgentEvaluator(
    agent=my_agent,
    eval_set=eval_set,
    simulated_user=simulated_user
)

results = await evaluator.evaluate_async()
```

**ベストプラクティス:**
- 短い会話→固定evalset
- 長い会話・動的な会話→SimulatedUser
- `adk web`のEvalタブで結果可視化

---

## まとめ

ADKランタイム主要コンポーネント:

1. **Runner**: 実行エンジン（`InMemoryRunner`推奨スタート）
2. **Session**: 会話履歴・state（app/user/session/tempスコープ）
3. **Artifact**: ファイル管理（`GcsArtifactService`推奨）
4. **Memory**: 長期記憶（`VertexAiRagMemoryService`推奨）
5. **評価**: `adk eval`とDev UI
6. **Context階層**: InvocationContext → ReadonlyContext → CallbackContext → ToolContext
7. **Context Caching**: Gemini 2.0+でプロンプトキャッシュ（v1.15.0+）
8. **Context Compaction**: スライディングウィンドウ要約（v1.16.0+）
9. **Session Rewind**: 過去の状態に巻き戻し（v1.17.0+）
10. **Resume Agents**: 中断ワークフロー再開（v1.14.0+）
11. **Event System**: 実行履歴の完全管理と状態追跡
12. **Evaluation拡張**: 7メトリクス、evalsetファイル、ユーザーシミュレーション

環境に応じて実装を選択し、抽象基底クラスで疎結合を実現。
