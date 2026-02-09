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

## まとめ

ADKランタイム主要コンポーネント:

1. **Runner**: 実行エンジン（`InMemoryRunner`推奨スタート）
2. **Session**: 会話履歴・state（app/user/session/tempスコープ）
3. **Artifact**: ファイル管理（`GcsArtifactService`推奨）
4. **Memory**: 長期記憶（`VertexAiRagMemoryService`推奨）
5. **評価**: `adk eval`とDev UI

環境に応じて実装を選択し、抽象基底クラスで疎結合を実現。
