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
- Event永続化（`SessionService.append_event()`経由）

**入力blob処理詳細:**

`RunConfig(save_input_blobs_as_artifacts=True)`の場合:

1. `new_message`内の`Part`で`inline_data`を持つものを検出
2. `ArtifactService.save_artifact()`で保存（自動生成filename）
3. 元の`Part`を"Uploaded file: artifact_{filename}"というテキストPartに置換
4. Agent は artifact key を参照して`LoadArtifactsTool`で実データ取得可能

この仕組みにより、大きな画像・PDF等をLLMプロンプトに直接含めずに管理。

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
| `max_llm_calls` | 500 | LLM呼び出し上限（0以下で無制限） |
| `speech_config` | `None` | 音声設定（BIDI用） |
| `response_modalities` | `None` | 出力形式（BIDI用）例: `["AUDIO", "TEXT"]` |
| `output_audio_transcription` | `None` | エージェント音声の文字起こし（BIDI用） |
| `input_audio_transcription` | `None` | ユーザー音声の文字起こし（BIDI用） |
| `support_cfc` | `False` | 実験的: Compositional Function Calling（CFC）有効化 |

**StreamingMode詳細:**

| モード | 用途 | LLMエンドポイント |
|-------|------|-----------------|
| `NONE` | 標準リクエスト/レスポンス | `generate_content_async()` |
| `SSE` | 単方向ストリーミング（LLM→ユーザー） | `generate_content_async()` with streaming |
| `BIDI` | 双方向ストリーミング（音声対話等） | `connect()` LIVE API |

**LLM呼び出し制限詳細:**

`max_llm_calls`を超えると`LlmCallsLimitExceededError`が発生。ツールループの暴走防止に利用。

**使用例:**

```python
from google.adk.agents.run_config import RunConfig, StreamingMode

# SSEストリーミング
sse_config = RunConfig(streaming_mode=StreamingMode.SSE)
async for event in runner.run_async(..., run_config=sse_config):
    print(event.content.parts[0].text, end="", flush=True)

# LLM呼び出し制限
limit_config = RunConfig(max_llm_calls=10)

# CFC有効化（実験的）
cfc_config = RunConfig(support_cfc=True, streaming_mode=StreamingMode.SSE)
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

**DatabaseSessionService詳細:**

SQLAlchemyでSQLデータベースに永続化。以下のテーブルを自動生成:

| テーブル | 用途 | 主要カラム |
|---------|------|----------|
| `sessions` | セッション本体 | `id`, `app_name`, `user_id`, `last_update_time` |
| `events` | イベント履歴 | `id`, `session_id`, `author`, `timestamp`, `content`（JSON） |
| `app_states` | App横断状態 | `app_name`, `key`, `value` |
| `user_states` | User横断状態 | `app_name`, `user_id`, `key`, `value` |

**初期化例:**

```python
from google.adk.sessions import DatabaseSessionService

# SQLite
db_url = "sqlite:///./adk_sessions.db"
db_session_svc = DatabaseSessionService(db_url=db_url)

# PostgreSQL
db_url = "postgresql+psycopg2://user:pass@host:port/db"
db_session_svc = DatabaseSessionService(db_url=db_url)

# MySQL
db_url = "mysql+pymysql://user:pass@host:port/db"
db_session_svc = DatabaseSessionService(db_url=db_url)
```

**VertexAiSessionService詳細:**

Vertex AI管理のセッションストレージを利用。設定にはGCP Project IDとロケーションが必要。

```python
from google.adk.sessions import VertexAiSessionService

vertex_session_svc = VertexAiSessionService(
    project="my-gcp-project",
    location="us-central1"
)
```

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

**GCSオブジェクト命名規則:**

ADKは以下のパス構造でGCSにartifactを保存:

```
{app_name}/{user_id}/{session_id}/{filename}/{version}
```

例: `MyChatApp/user123/sessionABC/report.pdf/0`

**User横断Artifact:**

ファイル名が`user:`プレフィックスで始まる場合、User単位で共有:

```
{app_name}/{user_id}/user/{filename_without_prefix}/{version}
```

例: `MyChatApp/user123/user/profile_picture.png/0`

これにより複数セッション間でartifactを共有可能。

**バージョニング:**

- 同一filenameで`save_artifact()`を複数回実行すると、バージョン番号が自動インクリメント（0, 1, 2...）
- `load_artifact(version=None)`でデフォルト最新版を取得
- `list_versions(filename)`で全バージョンリストを取得

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

### 3.5 ユーザーアップロードファイルの自動Artifact保存

`RunConfig(save_input_blobs_as_artifacts=True)`を使用:

```python
from google.adk.runners import RunConfig
from google.genai.types import Content, Part, Blob

# ユーザーアップロードファイルを含むメッセージ
user_upload = Part(inline_data=Blob(mime_type="image/png", data=image_bytes))
user_message = Content(parts=[Part(text="画像を分析して"), user_upload])

config = RunConfig(save_input_blobs_as_artifacts=True)

async for event in runner.run_async(
    user_id=user_id,
    session_id=session_id,
    new_message=user_message,
    run_config=config
):
    ...
```

**Runnerの自動処理:**

1. `new_message`内の`inline_data`を持つ`Part`を検出
2. `artifact_service.save_artifact()`で保存（filename: `artifact_{invocation_id}_{part_index}`）
3. 元の`Part`を`Part(text="Uploaded file: artifact_... is saved into artifacts")`に置換
4. Agentは`load_artifacts`ツールで実データ取得可能

この仕組みでLLMプロンプトに大きなバイナリを直接含めずに管理。

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
    similarity_top_k=5,
    # vector_distance_threshold=0.7  # Optional: 類似度スコアでフィルタ
)
```

**前提:** Vertex AI、RAG Corpus、認証、`google-cloud-aiplatform[rag]`

**動作詳細:**

**add_session_to_memory:**
1. `session.events`をJSON lines形式に変換（各行が1イベントのJSON）
2. 一時ローカルファイルに保存
3. `vertexai.preview.rag.upload_file()`でRAG Corpusにアップロード
   - ファイルdisplay name: `{app_name}.{user_id}.{session_id}`
4. Vertex AI RAGが自動的にチャンク化・埋め込み・インデックス化

**search_memory:**
1. `vertexai.preview.rag.retrieval_query()`でセマンティック検索実行
2. 取得した`Contexts`（テキストチャンク）をパース
3. JSON lines構造を検出して`MemoryEntry`オブジェクトに変換（author、timestamp、content）
4. `SearchMemoryResponse.memories`として返却

**注意:**
- 現在、RAGクエリ内での`user_id`/`app_name`フィルタリングは制限的
- コーパス全体を検索し、必要に応じて後処理でフィルタ
- インデックス化は非同期なため、`add_session_to_memory`直後の検索では遅延がある可能性

**選択基準:**
- セマンティック検索必要→`VertexAiRag`
- キーワード検索で十分→`InMemory`

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
  "intermediate_data": {
    "tool_uses": [{"name": "tool", "args": {}}],
    "intermediate_responses": [("agent1", [{"text": "中間応答"}])]
  }
}
```

**EvalCase:** `eval_id`, `conversation: list[Invocation]`, `session_input`（optional）

**EvalSet:** `eval_set_id`, `name`, `description`, `eval_cases: list[EvalCase]`

### 5.3 評価メトリクス（7種のビルトインメトリクス）

| Evaluator | メトリクス | スコア範囲 | 用途 |
|----------|-----------|----------|------|
| `TrajectoryEvaluator` | `tool_trajectory` | 0-1 | ツール呼び出しシーケンスの正確性 |
| `ResponseEvaluator` | `response_match` | 0-1 | ROUGE-1ベース応答一致度 |
| `ResponseEvaluator` | `final_response_match_v2` | 0-1 | 最終応答一致度（v2） |
| `ResponseEvaluator` | `rubric_based_quality` | 0-5 | ルーブリックベース品質評価 |
| `ResponseEvaluator` | `rubric_based_tool_use` | 0-5 | ルーブリックベースツール使用評価 |
| `ResponseEvaluator` | `hallucinations` | 0-1 | ハルシネーション検出 |
| `ResponseEvaluator` | `safety` | 0-1 | 安全性チェック |

**メトリクス選択:**

```bash
# 特定メトリクスのみ実行
adk eval path/to/agent tests.evalset.json --metrics tool_trajectory,hallucinations
```

### 5.4 実行

```bash
# CLI
adk eval path/to/agent path/to/tests.evalset.json

# 特定ケース
adk eval path/to/agent tests.evalset.json:case1,case2

# 複数実行（LLM変動性考慮）
adk eval path/to/agent tests.evalset.json -num_runs 3
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
      "session_input": {
        "app_name": "MyApp",
        "user_id": "eval_user",
        "state": {"user:location": "US"}
      },
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
  ],
  "creation_timestamp": 1678886400.0
}
```

**YAML形式も対応:**
```yaml
eval_set_id: test-001
name: Basic Tests
description: 基本動作テスト
eval_cases:
  - eval_id: case1
    session_input:
      app_name: MyApp
      user_id: eval_user
      state:
        user:location: US
    conversation:
      - user_content:
          role: user
          parts:
            - text: "質問"
        final_response:
          role: model
          parts:
            - text: "期待応答"
        intermediate_data:
          tool_uses:
            - name: tool1
              args:
                key: value
```

**ファイル拡張子:**
- 推奨: `.evalset.json` または `.evalset.yaml`
- 旧形式: `.test.json`（マイグレーション推奨）

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

### 12.4 EvaluationGenerator詳細

`EvaluationGenerator.generate_responses()`がAgent実行と応答収集を自動化:

1. 各`EvalCase`に対して`InMemoryRunner`初期化
2. `session_input`が指定されていれば初期stateを設定
3. `conversation`の各`Invocation`の`user_content`をAgentに送信
4. 実際の`final_response`と`tool_uses`を収集
5. `repeat_num`回繰り返し（LLM変動性考慮）
6. `EvalCaseResponses`リストを返却（期待値vs実測値の比較用）

**プログラマティック評価:**

```python
from google.adk.evaluation import AgentEvaluator

# 評価基準
criteria = {
    "tool_trajectory_avg_score": 0.9,
    "response_match_score": 0.75
}

# 評価実行
results = AgentEvaluator.evaluate_eval_set(
    agent_module="path/to/agent",
    eval_set=my_eval_set,
    criteria=criteria,
    num_runs=3
)
```

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

---

## 13. テレメトリ・ロギング・デバッグ

### 13.1 OpenTelemetry統合

ADKは**OpenTelemetry（OTel）**で計装済み。

**トレース対象:**
- **Overall Invocation**: `runner.run_async()`全体
- **Agent Run**: 各`BaseAgent.run_async()`
- **LLM Call**: `LlmRequest`と`LlmResponse`
- **Tool Call**: Tool呼び出し
- **Tool Response**: Tool応答
- **Live LLM Data**: `run_live`データ送信

**トレースビュー方法:**

| 方法 | 環境 | 推奨度 |
|-----|------|--------|
| **ADK Dev UI** | ローカル開発 | ⭐⭐⭐（最優先） |
| **Cloud Trace** | デプロイ時 | ⭐⭐（`--trace_to_cloud`フラグで有効化） |
| **カスタムOTelエクスポーター** | 本番監視 | ⭐（高度な分析用） |

**ADK Dev UI（推奨）:**
- `adk web .`→トレースタブ
- 階層的スパン表示（InvocationContext、LLM prompt、Tool引数・応答、state delta）
- Dev UIはADK内部OTel計装の可視化インターフェース

**Cloud Trace:**

```bash
# デプロイ時にフラグ追加
adk deploy cloud_run --trace_to_cloud
adk deploy agent_engine --trace_to_cloud
adk api_server --trace_to_cloud
```

GCP Console → Operations > Trace > Trace list で確認可能。

### 13.2 ロギング戦略

**ロギング箇所:**
- Agent初期化
- `InstructionProvider`
- Callbacks（`before/after_agent_callback`, `before/after_model_callback`, `before/after_tool_callback`）
- Tool `run_async`メソッド
- カスタムService実装

**ベストプラクティス:**

```python
import logging
logger = logging.getLogger(__name__)  # モジュール別ロガー

def my_tool(param: str, tool_context: ToolContext) -> dict:
    logger.info(f"Tool called: {param}")
    result = process(param)
    logger.debug(f"Result: {result}")
    return {"output": result}
```

**ログレベル:**
- `DEBUG`: 詳細診断情報
- `INFO`: 一般的な操作メッセージ
- `WARNING`: 潜在的な問題
- `ERROR`: 失敗
- `CRITICAL`: 深刻なエラー

**ADK内部ログ制御:**

```python
logging.getLogger('google_adk').setLevel(logging.INFO)  # or DEBUG
```

**⚠️ 機密情報ログ出力禁止:** PII、APIキー、機密プロンプト/応答は絶対にログ出力しない。

### 13.3 デバッグ技法

#### 1. ADK Dev UI Trace View（最優先）

**デバッグ対象:**
- LLMがtoolを呼ばない理由 → tool説明・instruction確認
- Tool呼び出し引数誤り → 型ヒント・スキーマ確認
- Tool実行エラー → `tool_response`確認
- 認証エラー → `auth_credential`設定・スコープ確認

**確認項目:**
- 完全な`InvocationContext`（各ステージ）
- 正確な`LlmRequest`（system prompt、history、tool declarations）
- 生の`LlmResponse`（text、function calls、usage metadata）
- Tool invocations（tool名、LLMが渡した引数）
- Tool responses（tool返却データ）
- State deltas（各ステップの状態変更）

#### 2. Pythonデバッガ（pdb）

**`adk web`でのデバッグ:**

```python
def my_buggy_tool(param1: str, tool_context: ToolContext):
    logger.info("Tool entered")
    import pdb; pdb.set_trace()  # ブレークポイント
    result = f"Processed: {param1.upper()}"
    logger.info("Tool finishing")
    return {"output": result}
```

`adk web .`実行中のターミナルでインタラクションするとpdbが起動。

**IDEデバッガ:**
- Uvicornプロセスに直接アタッチ
- または`adk web`とは別にFastAPIアプリを起動してIDE経由デバッグ

#### 3. Sessionオブジェクト分析

**DatabaseSessionService:**
- 直接DBを開いてsession、events、stateを確認

**InMemorySessionService:**

```python
# デバッグ専用（内部構造アクセス）
if isinstance(runner.session_service, InMemorySessionService):
    session_obj = runner.session_service.sessions.get(app_name, {}).get(user_id, {}).get(session_id)
    if session_obj:
        print(session_obj.model_dump_json(indent=2))
```

### 13.4 よくある問題と解決法

| 問題 | Trace確認 | 解決策 |
|-----|----------|--------|
| **Agentがtool不使用** | tool宣言の有無 | tool description・instruction改善 |
| **Tool引数誤り** | LLM渡し引数 | 型ヒント・パラメータ説明明確化 |
| **Toolエラー** | tool_responseエラー | Tool単独テスト、ブレークポイント |
| **認証エラー** | tool_response認証エラー | `auth_credential`設定・スコープ確認 |
| **予期しないAgent応答** | 完全プロンプト（system + history） | Instruction精緻化、temperature調整 |

### 13.5 デバッグチェックリスト

**Agent Not Using a Tool:**
- [ ] Trace Check: Tool宣言が`LlmRequest`に含まれているか
- [ ] Tool Description: LLMに明確で魅力的な説明か
- [ ] Agent Instruction: tool使用を許可・推奨しているか

**Agent Calling Tool with Wrong Arguments:**
- [ ] Trace Check: LLMが実際に渡した引数を確認
- [ ] Schema Clarity: 型ヒント・Pydanticモデルが明確か
- [ ] Parameter Descriptions: docstringパラメータ説明が正確か

**Tool Errors:**
- [ ] Trace Check: `tool_response`のエラーメッセージ確認
- [ ] Local Tool Test: Tool関数を直接呼び出してエラー再現
- [ ] Debugger: `run_async`内にブレークポイント設定

**Unexpected Agent Behavior/Response:**
- [ ] Trace Check: フルプロンプト（system instruction + history）確認
- [ ] Temperature: 高すぎる場合は下げる（`GenerateContentConfig`）
- [ ] Instruction Refinement: イテレーティブに指示を改善

**Authentication Issues with Tools:**
- [ ] Trace Check: `tool_response`の認証エラー確認
- [ ] Credential Configuration: `auth_credential`が正しく設定されているか
- [ ] Scopes/Permissions: 認証情報が必要な権限/スコープを持っているか
- [ ] OAuth Flow: Dev UIでOAuth同意フローを完了しているか

---

## まとめ（更新版）

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
13. **テレメトリ**: OpenTelemetry統合、Cloud Trace、Dev UI Trace View
14. **ロギング**: モジュール別ロガー、適切なログレベル、機密情報除外
15. **デバッグ**: Dev UI最優先、pdb、Session分析、よくある問題パターン

環境に応じて実装を選択し、抽象基底クラスで疎結合を実現。
