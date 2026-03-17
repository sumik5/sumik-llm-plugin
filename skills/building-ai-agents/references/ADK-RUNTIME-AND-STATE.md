# ランタイムとステート管理

Google ADKの実行環境・ステート管理・メモリ・アーティファクト・評価の包括リファレンス。

---

## 目次

1. [Runner](#1-runner)
2. [Session管理](#2-session管理)
3. [State管理](#3-state管理)
4. [Artifact管理](#4-artifact管理)
5. [Memory管理](#5-memory管理)
6. [Context階層](#6-context階層)
7. [Event System](#7-event-system)
8. [Context Caching](#8-context-caching)
9. [Context Compaction](#9-context-compaction)
10. [Session Rewind](#10-session-rewind)
11. [Resume Agents](#11-resume-agents)
12. [Session Scaling](#12-session-scaling)
13. [State Lifecycle](#13-state-lifecycle)
14. [Agent評価](#14-agent評価)
15. [テレメトリ・デバッグ](#15-テレメトリデバッグ)

---

## 1. Runner

### 1.1 Runnerの役割

`google.adk.runners.Runner`はADK Agentシステムの実行エンジン。書籍が強調するように、エージェントは「スクリプト」ではなく「インテント（意図）の宣言」であり、Runnerはその意図を実行に変換する橋渡し役だ。

**主要責務:**
- Session管理（`BaseSessionService`連携）
- Agent起動（`run_async()`呼び出し）
- `InvocationContext`作成と注入
- `Event`ストリーミング配信
- 入力blob→artifact自動変換
- Event永続化（`SessionService.append_event()`経由）

**Runnerライフサイクル（書籍より）:**

```
1. Initialization  → YAMLパース・入力検証・Agent読み込み
2. Context Setup   → 入力をコンテキストに注入・短期メモリ初期化
3. Model/Tool Prep → Gemini接続・ツールスキーマ検証
4. Workflow Exec   → ステップ順次実行・依存関係自動解決
5. Completion      → 最終出力返却 or ループ継続
```

**入力blob処理（`save_input_blobs_as_artifacts=True`）:**

1. `new_message`内の`inline_data`を持つ`Part`を検出
2. `ArtifactService.save_artifact()`で保存（filename: `artifact_{invocation_id}_{part_index}`）
3. 元の`Part`を`"Uploaded file: artifact_{filename}"`テキストPartに置換
4. Agentは`load_artifacts`ツールで実データ取得

この仕組みにより大きな画像・PDFをLLMプロンプトに直接含めずに管理可能。

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

開発・テスト専用のRunner。外部依存なしで全サービスをメモリ内実行。

**特徴:**
- 外部依存なし・高速起動
- ローカル開発・テスト・評価に最適
- プロセス終了でデータ消失（プロダクション不適）
- 評価フレームワーク（`AgentEvaluator`）が内部でも使用

```python
from google.adk.runners import InMemoryRunner

runner = InMemoryRunner(agent=my_agent, app_name="TestApp")
```

### 1.3 カスタムRunner実装

特殊な要件（認証カスタマイズ、カスタムログ、前処理/後処理）がある場合、`Runner`を拡張可能。

```python
from google.adk.runners import Runner

class LoggingRunner(Runner):
    async def run_async(self, user_id, session_id, new_message, run_config=None):
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"Invocation start: user={user_id}, session={session_id}")
        async for event in super().run_async(user_id, session_id, new_message, run_config):
            logger.debug(f"Event: {event.author} - {event.id}")
            yield event
        logger.info("Invocation complete")
```

### 1.4 RunConfig

`RunConfig`で実行動作をカスタマイズ。

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

`max_llm_calls`を超えると`LlmCallsLimitExceededError`が発生。ツールループの暴走防止に重要。

```python
from google.adk.agents.run_config import RunConfig, StreamingMode

# SSEストリーミング（段階的な応答表示）
sse_config = RunConfig(streaming_mode=StreamingMode.SSE)
async for event in runner.run_async(..., run_config=sse_config):
    if event.content and event.content.parts:
        print(event.content.parts[0].text, end="", flush=True)

# LLM呼び出し制限（ループ暴走防止）
limit_config = RunConfig(max_llm_calls=10)

# CFC有効化（実験的）
cfc_config = RunConfig(support_cfc=True, streaming_mode=StreamingMode.SSE)
```

---

## 2. Session管理

### 2.1 Sessionとは何か

書籍の定義: セッションは「ユーザーとエージェント間の会話的・タスクベースのインタラクションのコンテナ」。

セッションにより以下が実現される:
- **メモリ維持**: スクラッチパッド・エピソードメモリ保持
- **マルチターン対話**: 複数ターンの会話継続
- **タスク進捗追跡**: 複数ステップワークフローの状態管理
- **パーソナライゼーション**: ユーザー設定・履歴に基づく応答カスタマイズ

### 2.2 BaseSessionService

| メソッド | 説明 |
|---------|------|
| `create_session()` | 新規セッション作成（初期state注入可能） |
| `get_session()` | セッション取得（指定イベント数でフィルタ可） |
| `append_event()` | イベント追加（state_deltaを自動反映） |
| `list_sessions()` | セッション一覧取得 |
| `delete_session()` | セッション削除 |

### 2.3 Sessionオブジェクト

| 属性 | 型 | 説明 |
|-----|---|------|
| `id` | str | セッションID（UUID推奨） |
| `app_name` | str | アプリケーション名 |
| `user_id` | str | ユーザーID |
| `events` | list[Event] | イベント時系列リスト |
| `state` | dict | key-valueペア（全スコープ統合） |
| `last_update_time` | float | 最終更新タイムスタンプ |

### 2.4 SessionService実装の選択

| 実装 | 特徴 | 推奨用途 |
|-----|------|---------|
| `InMemorySessionService` | Pythonディクショナリ、外部依存なし | ローカル開発・テスト |
| `DatabaseSessionService` | SQLAlchemy経由でSQL永続化 | セルフホスト・本番（DB管理可） |
| `VertexAiSessionService` | Vertex AI管理のストレージ | GCPマネージド・大規模本番 |

**選択フローチャート:**

```
開発・テスト → InMemorySessionService
         ↓
本番デプロイ決定
    ├─ GCPインフラ利用 → VertexAiSessionService
    └─ セルフホスト
         ├─ SQLite（小規模） → DatabaseSessionService
         ├─ PostgreSQL（中規模） → DatabaseSessionService
         └─ MySQL（大規模） → DatabaseSessionService
```

### 2.5 DatabaseSessionService詳細

SQLAlchemyでSQLデータベースに永続化。自動テーブル生成:

| テーブル | 用途 | 主要カラム |
|---------|------|----------|
| `sessions` | セッション本体 | `id`, `app_name`, `user_id`, `last_update_time` |
| `events` | イベント履歴 | `id`, `session_id`, `author`, `timestamp`, `content`（JSON） |
| `app_states` | App横断状態 | `app_name`, `key`, `value` |
| `user_states` | User横断状態 | `app_name`, `user_id`, `key`, `value` |

```python
from google.adk.sessions import DatabaseSessionService

# SQLite（開発・小規模本番）
db_session_svc = DatabaseSessionService(db_url="sqlite:///./adk_sessions.db")

# PostgreSQL（本番推奨）
db_session_svc = DatabaseSessionService(
    db_url="postgresql+psycopg2://user:pass@host:5432/adk_db"
)

# MySQL
db_session_svc = DatabaseSessionService(
    db_url="mysql+pymysql://user:pass@host:3306/adk_db"
)
```

### 2.6 VertexAiSessionService詳細

Vertex AI管理のセッションストレージ。GCPとのネイティブ統合、スケーラビリティ優先。

```python
from google.adk.sessions import VertexAiSessionService

vertex_session_svc = VertexAiSessionService(
    project="my-gcp-project",
    location="us-central1"
)
```

**前提:** GCPプロジェクト・Vertex AI API有効化・適切なIAMロール

### 2.7 セッション有効期限とクリーンアップ

書籍からのベストプラクティス:

```python
# パターン1: セッション期限切れチェック
import time

def is_session_expired(session, ttl_seconds=3600):
    """1時間操作がないセッションを期限切れとみなす"""
    elapsed = time.time() - session.last_update_time
    return elapsed > ttl_seconds

# パターン2: 期限切れ前にエピソードメモリへ要約保存
async def expire_session_gracefully(session, memory_service, session_service):
    """セッション終了前に長期記憶へエッセンスを保存"""
    await memory_service.add_session_to_memory(session)
    await session_service.delete_session(
        app_name=session.app_name,
        user_id=session.user_id,
        session_id=session.id
    )
```

---

## 3. State管理

### 3.1 Stateスコープ体系

ADKのState管理は4つのスコープで階層化されている。

| プレフィックス | スコープ | 永続化 | 共有範囲 |
|-------------|---------|--------|---------|
| なし | Session | Session単位 | 同一セッション内 |
| `user:` | User横断 | User単位 | 同一ユーザーの全セッション |
| `app:` | App全体 | App単位 | アプリ全ユーザー |
| `temp:` | Invocation内 | されない | 1ターンのみ |

**使用例:**

```python
# Session State: 現在会話の文脈
ctx.state["current_task"] = "search"
ctx.state["conversation_history"] = ["msg1", "msg2"]

# User State: ユーザーの長期設定・プロファイル
ctx.state["user:theme"] = "dark"
ctx.state["user:preferred_language"] = "ja"
ctx.state["user:last_login"] = "2025-02-20"

# App State: アプリ全体の設定・アナウンス
ctx.state["app:maintenance_mode"] = False
ctx.state["app:announcement"] = "システムメンテナンスは完了しました"
ctx.state["app:feature_flags"] = {"new_ui": True, "beta_search": False}

# Temp State: 1ターン内の一時計算値
ctx.state["temp:retry_count"] = 0
ctx.state["temp:intermediate_result"] = {"score": 0.85}
```

### 3.2 State操作パターン

**パターン1: カウンタ操作**

```python
def increment_counter(ctx: ToolContext, key: str) -> int:
    current = ctx.state.get(key, 0)
    new_value = current + 1
    ctx.state[key] = new_value
    return new_value

# 使用例
call_count = increment_counter(ctx, "tool_call_count")
```

**パターン2: リスト管理（append）**

```python
def add_to_history(ctx: ToolContext, item: str, key: str = "history", max_size: int = 100):
    history = ctx.state.get(key, [])
    history.append(item)
    # メモリ肥大化防止
    if len(history) > max_size:
        history = history[-max_size:]
    ctx.state[key] = history
```

**パターン3: チェックポイント保存**

```python
def save_checkpoint(ctx: CallbackContext, step_name: str, data: dict):
    """長時間タスクのチェックポイントをState保存"""
    checkpoint = {
        "step": step_name,
        "data": data,
        "timestamp": time.time()
    }
    ctx.state["checkpoint"] = checkpoint

def restore_checkpoint(ctx: CallbackContext) -> dict | None:
    """チェックポイントから作業再開"""
    return ctx.state.get("checkpoint")
```

**パターン4: ユーザープロファイル**

```python
def update_user_profile(ctx: ToolContext, **kwargs):
    """ユーザー設定を横断的に保存"""
    for key, value in kwargs.items():
        ctx.state[f"user:{key}"] = value

# 呼び出し例
update_user_profile(ctx, theme="dark", language="ja", timezone="Asia/Tokyo")
```

### 3.3 state_deltaとEvent連携

```
Tool/Callback内でctx.state["key"] = value
        ↓
Runner が EventActions.state_delta = {"key": "value"} に記録
        ↓
SessionService.append_event() が session.state に反映
        ↓
次回セッション取得時に永続化された値が利用可能
```

**注意事項:**
- `temp:` プレフィックスの値はEventに記録されるが次回セッション取得時には含まれない
- `state_delta`はイベントログから変更履歴を完全追跡可能
- 大きなオブジェクト（画像バイナリ等）はArtifactで管理し、stateにはキーのみ保存

---

## 4. Artifact管理

### 4.1 BaseArtifactService

バイナリデータ・大きなファイルを管理するサービス。LLMプロンプトに含めずに大容量データを扱う。

| メソッド | 戻り値 | 説明 |
|---------|--------|------|
| `save_artifact()` | `int`（バージョン） | Artifactを保存・バージョン自動インクリメント |
| `load_artifact()` | `Optional[Part]` | 最新版またはバージョン指定で取得 |
| `list_artifact_keys()` | `list[str]` | キー一覧取得 |
| `list_versions()` | `list[int]` | 指定キーの全バージョン一覧 |
| `delete_artifact()` | `None` | Artifact削除 |

### 4.2 Artifactのユースケース

| ユースケース | 説明 |
|------------|------|
| ユーザーアップロードファイル | 画像・PDF・Office文書等 |
| LLM生成物 | 生成画像・コード・文書 |
| コード実行結果 | スクリプト実行の出力ファイル |
| 中間ツール出力 | パイプライン中間データ |
| 分析レポート | 大容量分析結果 |

### 4.3 GCS命名規則

ADKはGCSに以下のパス構造でArtifactを保存:

```
# Session スコープ
{app_name}/{user_id}/{session_id}/{filename}/{version}
例: MyChatApp/user123/sessionABC/report.pdf/0

# User スコープ（filename が user: で始まる場合）
{app_name}/{user_id}/user/{filename_without_prefix}/{version}
例: MyChatApp/user123/user/profile_picture.png/0
```

User横断Artifactはセッション間でファイルを共有する場合に使用。

### 4.4 実装の選択

| 実装 | 特徴 | 用途 |
|-----|------|------|
| `InMemoryArtifactService` | メモリ内保存、プロセス終了で消失 | 開発・テスト |
| `GcsArtifactService` | GCS永続化、バージョニング完備 | プロダクション推奨 |

```python
from google.adk.artifacts import GcsArtifactService

gcs_service = GcsArtifactService(bucket_name="my-artifacts-bucket")
```

**前提:** GCPプロジェクト・GCS API有効化・バケット作成・認証・`google-cloud-storage`インストール

### 4.5 バージョニング

```python
from google.genai.types import Part

# 最初の保存（バージョン0）
version_0 = await tool_context.save_artifact("report.pdf", pdf_part)

# 更新（バージョン1に自動インクリメント）
version_1 = await tool_context.save_artifact("report.pdf", updated_pdf_part)

# 最新版取得（デフォルト）
latest = await tool_context.load_artifact("report.pdf")

# 特定バージョン取得
v0 = await tool_context.load_artifact("report.pdf", version=0)

# 全バージョン一覧
versions = await tool_context.list_artifacts()
```

### 4.6 LoadArtifactsTool

```python
from google.adk.tools import load_artifacts

agent = Agent(
    name="document_analyzer",
    instruction="""
    ユーザーがアップロードしたファイルを分析してください。
    artifact が利用可能な場合は load_artifacts で取得してから分析を開始してください。
    """,
    tools=[load_artifacts]
)
```

**動作:**
1. LLMにartifact一覧を通知
2. LLMが`load_artifacts`呼び出し
3. 次ターンで実コンテンツが注入され分析可能

### 4.7 ユーザーアップロードの自動保存

```python
from google.adk.agents.run_config import RunConfig
from google.genai.types import Content, Part, Blob

# ファイルを含むメッセージ
user_message = Content(
    parts=[
        Part(text="この画像を分析してください"),
        Part(inline_data=Blob(mime_type="image/png", data=image_bytes))
    ]
)

config = RunConfig(save_input_blobs_as_artifacts=True)

async for event in runner.run_async(
    user_id="user123",
    session_id="session456",
    new_message=user_message,
    run_config=config
):
    if event.is_final_response():
        print(event.content.parts[0].text)
```

---

## 5. Memory管理

### 5.1 メモリの3層構造（書籍より）

書籍は3種類のメモリを区別する:

| メモリ種別 | ADK対応 | 永続性 | 検索方式 | 用途 |
|----------|---------|--------|---------|------|
| **Scratchpad** | Session.state（session/temp） | セッション内 | - | ステップ間データ共有 |
| **Episodic** | User/App state + MemoryService | 長期 | キーワード | ユーザー設定・履歴 |
| **Vector** | VertexAiRagMemoryService | 長期 | セマンティック | 知識検索・RAG |

### 5.2 BaseMemoryService

長期記憶（セッション横断）を管理するサービス。

| メソッド | 説明 |
|---------|------|
| `add_session_to_memory()` | セッション終了時にメモリへ変換・保存 |
| `search_memory()` | クエリで関連記憶を検索 |

**SearchMemoryResponse:** `memories: list[MemoryEntry]`

**MemoryEntry:** `content`（Content）, `author`（str）, `timestamp`（datetime）

### 5.3 メモリ実装の選択

| 実装 | 特徴 | 推奨用途 |
|-----|------|---------|
| `InMemoryMemoryService` | キーワード一致ベース検索、プロセス終了で消失 | プロトタイピング専用 |
| `VertexAiRagMemoryService` | Vertex AI RAG Corpus使用、セマンティック検索 | 本番・大規模知識検索 |

### 5.4 VertexAiRagMemoryService詳細

```python
from google.adk.memory import VertexAiRagMemoryService

rag_service = VertexAiRagMemoryService(
    rag_corpus=f"projects/{project}/locations/{location}/ragCorpora/{corpus_id}",
    similarity_top_k=5,        # 上位K件取得
    vector_distance_threshold=0.7  # 類似度スコアフィルタ（Optional）
)
```

**動作詳細:**

`add_session_to_memory()` の処理フロー:
1. `session.events`をJSON lines形式に変換（各行=1イベントのJSON）
2. 一時ローカルファイルに保存
3. `vertexai.preview.rag.upload_file()`でRAG Corpusへアップロード
   - ファイルdisplay name: `{app_name}.{user_id}.{session_id}`
4. Vertex AI RAGが非同期でチャンク化・埋め込み・インデックス化

`search_memory()` の処理フロー:
1. `vertexai.preview.rag.retrieval_query()`でセマンティック検索
2. 取得した`Contexts`（テキストチャンク）をパース
3. JSON lines構造を検出して`MemoryEntry`に変換
4. `SearchMemoryResponse.memories`として返却

**注意事項:**
- インデックス化は非同期のため`add_session_to_memory`直後の検索では遅延がある
- RAGクエリでの`user_id`/`app_name`フィルタリングは制限的（コーパス全体を検索し後処理でフィルタ）

### 5.5 メモリツール

**LoadMemoryTool（明示的検索）:**

```python
from google.adk.tools import load_memory

agent = Agent(
    name="knowledge_agent",
    instruction="ユーザーの質問に答える前に関連する記憶を確認してください",
    tools=[load_memory]
)
```

LLMが明示的に呼び出す。`query: str`でセマンティック検索。

**PreloadMemoryTool（自動検索）:**

```python
from google.adk.tools import preload_memory

agent = Agent(
    name="personalized_agent",
    instruction="過去の会話を参考にしてパーソナライズされた応答をしてください",
    tools=[preload_memory]
)
```

各LLMターン前に自動実行。現在の`user_content`をクエリとして使用し、関連記憶をsystem instructionにプリペンド。

**併用パターン（推奨）:**

```python
# PreloadMemoryで自動的な文脈提供 + LoadMemoryで深掘り検索
agent = Agent(
    name="comprehensive_agent",
    tools=[preload_memory, load_memory, load_artifacts]
)
```

### 5.6 長期記憶パターン（書籍からのベストプラクティス）

**パターン1: セッション終了時のメモリ保存**

```python
async def on_session_end(session, memory_service):
    """セッション終了時に重要情報を長期記憶へ保存"""
    await memory_service.add_session_to_memory(session)

# Runner の after_agent_callback で実装
```

**パターン2: State + Memory の組み合わせ**

```python
# 短期（Session State）: 現在会話の作業データ
ctx.state["current_analysis"] = analysis_result

# 長期（User State）: ユーザー設定・プロファイル
ctx.state["user:preferred_output_format"] = "markdown"

# セマンティック検索（Memory Service）: 過去セッションの知識
memories = await memory_service.search_memory(
    app_name="MyApp", user_id="user123", query="前回の分析結果"
)
```

---

## 6. Context階層

### 6.1 階層構造

ADKでは実行フェーズごとに異なるコンテキストが渡される。最小権限の原則に基づき、各フェーズで必要なアクセス権のみが付与される。

```
InvocationContext（最上位・Runner内部）
  └─ ReadonlyContext（Agent読み取り用）
       └─ CallbackContext（Callback内状態変更）
            └─ ToolContext（Tool実行用）
```

| コンテキスト | 利用箇所 | State | Artifact | 特殊機能 |
|------------|---------|-------|----------|---------|
| `InvocationContext` | Runner内部 | 読み書き | あり | Agent/Session全体管理 |
| `ReadonlyContext` | Agent `instruction` | 読み取りのみ | なし | - |
| `CallbackContext` | before/after callbacks | 読み書き | あり | - |
| `ToolContext` | Tool関数 | 読み書き | あり | `search_memory()`, `list_artifacts()`, `request_credential()` |

### 6.2 InvocationContext

最上位コンテキスト。Runner内部でのターン実行全体を管理。開発者が直接操作することは少ない。

```python
# InvocationContext の主要フィールド
ctx.invocation_id      # 一意なターンID
ctx.session            # 現在のSession
ctx.agent              # 実行中のAgent
ctx.user_content       # ユーザー入力
ctx.run_config         # 実行設定（RunConfig）
```

### 6.3 ReadonlyContext

Agent本体に渡されるコンテキスト。状態の読み取りのみ可能（変更不可）。

```python
# instruction プロバイダーでの使用例
def dynamic_instruction(ctx: ReadonlyContext) -> str:
    theme = ctx.state.get("user:theme", "light")
    language = ctx.state.get("user:preferred_language", "ja")
    return f"""
    あなたは{language}で応答するアシスタントです。
    UIテーマ: {theme}モード
    ユーザーの過去タスク: {ctx.state.get('last_task', 'なし')}
    """
```

### 6.4 CallbackContext

Callback（before/after）内でのみ利用可能。状態変更とArtifact保存が可能。

```python
from google.adk.agents.callback_context import CallbackContext
from google.genai.types import Content

# Agent実行後のコールバック
async def after_agent_callback(ctx: CallbackContext) -> Content | None:
    # State更新
    ctx.state["last_agent_run"] = time.time()
    ctx.state["total_runs"] = ctx.state.get("total_runs", 0) + 1

    # Artifact保存（必要な場合）
    # ctx.save_artifact("log.txt", Part(text="実行ログ"))

    return None  # None返却でAgentの応答をそのまま使用
```

### 6.5 ToolContext

Tool実行中に渡される。`CallbackContext`を拡張し、ツール固有の操作メソッドを提供。

```python
from google.adk.tools.tool_context import ToolContext
from google.genai.types import Part

async def document_analysis_tool(
    document_key: str,
    analysis_type: str,
    ctx: ToolContext
) -> dict:
    # State読み書き
    ctx.state["last_analyzed_doc"] = document_key
    call_count = ctx.state.get("tool_calls", 0) + 1
    ctx.state["tool_calls"] = call_count

    # Artifact読み込み
    doc_part = await ctx.load_artifact(document_key)
    if doc_part is None:
        return {"error": f"Document not found: {document_key}"}

    # 分析実行
    result = perform_analysis(doc_part.inline_data.data, analysis_type)

    # 結果をArtifact保存
    result_part = Part(text=str(result))
    version = await ctx.save_artifact(f"analysis_{document_key}", result_part)

    # メモリ検索（関連する過去の分析を参照）
    related = await ctx.search_memory(f"analysis {document_key}")

    return {
        "result": result,
        "artifact_version": version,
        "related_analyses": len(related.memories)
    }
```

---

## 7. Event System

### 7.1 Event構造

ADKでは実行中のすべての情報がEventとして管理される。Eventログから実行履歴を完全再現可能。

| フィールド | 型 | 説明 |
|----------|---|------|
| `author` | str | ソース識別（`'user'`またはagent名） |
| `invocation_id` | str | インタラクション一意ID |
| `id` | str | イベント一意ID |
| `timestamp` | datetime | 作成時刻 |
| `content` | Content | メッセージ内容（テキスト、関数呼び出し、結果） |
| `partial` | bool | ストリーミングチャンク判定 |
| `actions` | EventActions | 状態変更・制御シグナル |
| `branch` | list[str] | 階層パス（マルチAgent時） |

### 7.2 EventActions

| フィールド | 型 | 説明 |
|----------|---|------|
| `state_delta` | dict | 状態変更マップ（プレフィックスで永続化スコープ決定） |
| `artifact_delta` | dict | Artifact更新マップ |
| `transfer_to_agent` | Optional[str] | Agent転送先 |
| `escalate` | bool | ループ終了シグナル |
| `skip_summarization` | bool | Compaction時の要約スキップ |

### 7.3 7種類のイベントタイプ

| タイプ | 説明 | `content.parts` 例 |
|-------|------|--------------------|
| **User Input** | ユーザー入力 | `[Text]` |
| **Agent Responses** | Agent応答（テキスト・スト） | `[Text]` |
| **Tool Calls** | ツール呼び出し要求 | `[FunctionCall]` |
| **Tool Results** | ツール実行結果 | `[FunctionResponse]` |
| **State Updates** | 状態変更イベント | `actions.state_delta` |
| **Control Signals** | 制御シグナル | `actions.escalate`, `actions.transfer_to_agent` |
| **Error Events** | エラー発生 | `[Text]`（エラーメッセージ） |

### 7.4 イベントフロー

```
生成（Agent/Tool）
    ↓
Runner受信・検証
    ↓
SessionService.append_event()で永続化
    ↓
session.eventsリストに追加
    ↓
state_delta → session.stateに反映
    ↓
ストリーミングまたは最終レスポンスとして返却
```

### 7.5 主要メソッド

```python
# Event操作
event.get_function_calls()      # FunctionCall一覧取得
event.get_function_responses()  # FunctionResponse一覧取得
event.is_final_response()       # 最終応答判定

# 最終応答のみ処理する例
async for event in runner.run_async(...):
    if event.is_final_response():
        if event.content and event.content.parts:
            print(event.content.parts[0].text)
        break

# 特定authorのイベント取得
user_events = [e for e in session.events if e.author == "user"]
agent_events = [e for e in session.events if e.author == "my_agent"]

# State変化の追跡（デバッグ用）
state_changes = [
    (e.timestamp, e.actions.state_delta)
    for e in session.events
    if e.actions and e.actions.state_delta
]
```

---

## 8. Context Caching

Gemini 2.0以降で利用可能（ADK v1.15.0+）。長いプロンプトやシステムインストラクションをキャッシュしてAPIコストを削減。

### 8.1 ContextCacheConfig

```python
from google.adk.agents.context_cache_config import ContextCacheConfig
from google.adk.apps.app import App

app = App(
    name='document-analysis-app',
    root_agent=root_agent,
    context_cache_config=ContextCacheConfig(
        min_tokens=2048,    # キャッシュ発動の最小トークン数
        ttl_seconds=600,    # キャッシュ有効期間（秒）
        cache_intervals=5,  # 最大再利用回数
    ),
)
```

### 8.2 パラメータ

| パラメータ | デフォルト | 推奨値 | 説明 |
|----------|----------|--------|------|
| `min_tokens` | 0 | 2048以上 | キャッシュを開始する最小トークン数 |
| `ttl_seconds` | 1800 | 600-1800 | キャッシュ有効期間（秒） |
| `cache_intervals` | 10 | 5-15 | キャッシュを再利用できる最大回数 |

**要件:**
- Gemini 2.0以降のモデル
- ADK v1.15.0以降

**コスト削減が見込める状況:**

| 状況 | 効果 |
|-----|------|
| 長いsystem instruction（5000トークン超） | 大幅削減 |
| 大量のツール定義 | 中程度削減 |
| 文書埋め込みベースのRAG | 大幅削減 |
| 短い会話の繰り返し | 効果小 |

---

## 9. Context Compaction

会話履歴が長くなった際、スライディングウィンドウ方式で古いイベントを要約しコンテキストサイズを制御（ADK v1.16.0+）。

### 9.1 EventsCompactionConfig

```python
from google.adk.apps.app import App, EventsCompactionConfig
from google.adk.apps.llm_event_summarizer import LlmEventSummarizer
from google.adk.models import Gemini

app = App(
    name='long-running-support-app',
    root_agent=root_agent,
    events_compaction_config=EventsCompactionConfig(
        compaction_interval=10,  # 圧縮トリガーのイベント数
        overlap_size=2,          # オーバーラップ保持数（文脈の連続性）
        summarizer=LlmEventSummarizer(
            llm=Gemini(model="gemini-2.5-flash")  # 高速モデル推奨
        ),
    ),
)
```

### 9.2 スライディングウィンドウ動作

```
初期状態: [E1, E2, E3, E4, E5, E6, E7]
                         ↓ compaction_interval=3 で圧縮トリガー
圧縮後:   [Summary(E1-E3), E3, E4, E5, E6, E7]
                            ↑ overlap_size=1 でE3を引き継ぎ
                         ↓ さらにイベント追加で再圧縮
圧縮後:   [Summary(E1-E3), Summary(E3-E5), E5, E6, E7, E8, E9]
```

### 9.3 パラメータと選択基準

| パラメータ | デフォルト | 推奨値 | 説明 |
|----------|----------|--------|------|
| `compaction_interval` | 10 | 5-20 | 何件ごとに圧縮するか |
| `overlap_size` | 0 | 1-2 | 次ウィンドウに引き継ぐイベント数 |
| `summarizer` | - | LlmEventSummarizer | 要約実行エンジン |

**有効なシナリオ:**

| シナリオ | `compaction_interval` | `overlap_size` |
|---------|----------------------|----------------|
| カスタマーサポート（長時間） | 10-15 | 2 |
| コーディングアシスタント | 5-10 | 1-2 |
| 単発の短い会話 | 不要 | - |
| 高精度が重要なタスク | 20+ | 3 |

---

## 10. Session Rewind

セッションを過去の状態に巻き戻す機能（ADK v1.17.0+）。

### 10.1 概要と制約

| 項目 | 詳細 |
|-----|------|
| 目的 | デバッグ・ユーザー操作のやり直し |
| 巻き戻し対象 | `state`と`events`（指定時点に復元） |
| 巻き戻し対象外 | Artifact・Memory・外部副作用（API呼び出し等） |
| 主な用途 | 開発デバッグ・ロールバックテスト |

### 10.2 使用例

```python
# セッション履歴の確認
session = await runner.session_service.get_session(
    app_name="MyApp", user_id="user123", session_id="session456"
)

# 特定イベントまで巻き戻し
target_event_id = session.events[3].id  # 4番目のイベントまで巻き戻し

# Rewind実行
rewound_session = await runner.rewind_async(
    user_id="user123",
    session_id="session456",
    event_id=target_event_id
)

print(f"Rewound to: {rewound_session.events[-1].timestamp}")
```

### 10.3 ユースケース

| ユースケース | 説明 |
|------------|------|
| 「1つ前に戻りたい」 | ユーザーが間違えた際の会話ロールバック |
| 開発デバッグ | Agent動作の特定状態から再テスト |
| A/Bテスト | 同一状態からの異なるAgentの動作比較 |
| エラー回復 | Agentエラー発生直前の状態に戻して再実行 |

---

## 11. Resume Agents

中断されたワークフローを再開する機能（ADK v1.14.0+）。長時間タスクの耐障害性向上。

### 11.1 ResumabilityConfig

```python
from google.adk.agents import Agent
from google.adk.agents.resumability_config import ResumabilityConfig

agent = Agent(
    name="data-processing-agent",
    instruction="大規模データ処理タスクを実行します。定期的に進捗を保存してください。",
    resumability_config=ResumabilityConfig(
        enable_resumability=True
    )
)
```

### 11.2 チェックポイントパターン（推奨実装）

```python
from google.adk.tools.tool_context import ToolContext
import time

async def long_running_task(
    task_id: str,
    data_source: str,
    ctx: ToolContext
) -> dict:
    """チェックポイント付き長時間タスク"""
    # 既存チェックポイントの確認
    checkpoint = ctx.state.get("checkpoint")
    start_index = 0

    if checkpoint and checkpoint.get("task_id") == task_id:
        start_index = checkpoint.get("processed_count", 0)
        print(f"Resuming from checkpoint: {start_index} items processed")

    # データ取得
    all_items = fetch_data(data_source)
    items_to_process = all_items[start_index:]

    results = []
    for i, item in enumerate(items_to_process, start=start_index):
        # 処理実行
        result = await process_item(item)
        results.append(result)

        # 10件ごとにチェックポイント保存
        if (i + 1) % 10 == 0:
            ctx.state["checkpoint"] = {
                "task_id": task_id,
                "processed_count": i + 1,
                "timestamp": time.time(),
                "partial_results_key": f"partial_{task_id}"
            }
            # 中間結果をArtifactに保存
            await ctx.save_artifact(
                f"partial_{task_id}",
                Part(text=str(results))
            )

    # 完了時にチェックポイントをクリア
    ctx.state.pop("checkpoint", None)
    return {"status": "completed", "total_processed": len(all_items)}
```

### 11.3 rewind_asyncによる再開

```python
runner = Runner(app_name="MyApp", agent=resumable_agent)

# 中断されたセッションを特定イベントから再開
async for event in runner.rewind_async(
    user_id="user123",
    session_id="session456",
    event_id="event_before_failure",
    new_message=Content(
        role="user",
        parts=[Part(text="前回の処理を再開してください")]
    )
):
    if event.is_final_response():
        print(event.content.parts[0].text)
```

**ベストプラクティス:**
- 外部API呼び出しや重い計算の前にcheckpoint保存
- Artifactで中間結果を永続化
- Stateにはチェックポイントメタデータのみ保存（重いデータはArtifact）

---

## 12. Session Scaling

書籍のChapter 6「Scaling and Managing Agent Applications」から。プロダクション環境でのスケーリングパターン。

### 12.1 スケーリング原則

**ステートレス設計の重要性:**

> 「スケーリング時の共有状態衝突を避けるため、エージェントはデフォルトでステートレスに設計すべき。ユーザー固有データはFirestore、Redis、またはデータベースで外部永続化する」

```python
# ❌ 避けるべき: グローバル変数での状態保存
GLOBAL_USER_SESSIONS = {}  # 水平スケーリング時に同期不可

# ✅ 推奨: 外部ストアに委譲
runner = Runner(
    app_name="MyApp",
    agent=my_agent,
    session_service=DatabaseSessionService(db_url="postgresql://..."),
    artifact_service=GcsArtifactService(bucket_name="my-bucket"),
    memory_service=VertexAiRagMemoryService(rag_corpus="...")
)
```

### 12.2 セッション管理スケーリングパターン

| パターン | 実装方法 | 適用状況 |
|---------|---------|---------|
| **UUID セッションID** | `import uuid; session_id = str(uuid.uuid4())` | 全本番環境 |
| **セッション外部マッピング** | Firestore/Redisでuser_id → session_id管理 | マルチインスタンス |
| **TTL設定** | Firestore TTLポリシーまたはアプリレベル | メモリ効率化 |
| **会話圧縮** | EventsCompactionConfig | 長期セッション |
| **サマリ長期記憶化** | セッション終了時にMemoryServiceへ保存 | 知識蓄積 |

**セッションIDマッピング実装例（Firestore）:**

```python
from google.cloud import firestore

db = firestore.Client()

async def get_or_create_session(user_id: str, app_name: str) -> str:
    """ユーザーのアクティブセッションIDを取得または新規作成"""
    doc_ref = db.collection("user_sessions").document(user_id)
    doc = doc_ref.get()

    if doc.exists:
        session_data = doc.to_dict()
        # TTLチェック（1時間以上操作なしで新規セッション）
        last_active = session_data.get("last_active", 0)
        if time.time() - last_active < 3600:
            return session_data["session_id"]

    # 新規セッション作成
    import uuid
    new_session_id = str(uuid.uuid4())
    doc_ref.set({
        "session_id": new_session_id,
        "created_at": time.time(),
        "last_active": time.time()
    })
    return new_session_id
```

### 12.3 水平スケーリング構成

```
ユーザーリクエスト
     ↓
API Gateway（認証・レート制限・クォータ制御）
     ↓
Load Balancer（Cloud Run / GKE Ingress）
     ↓
[Agent Instance 1] [Agent Instance 2] [Agent Instance N]
     ↓                    ↓                   ↓
  共有外部ストア（DatabaseSessionService / VertexAiSessionService）
  共有Artifact（GcsArtifactService）
  共有Memory（VertexAiRagMemoryService）
```

### 12.4 デプロイ環境の選択

| 環境 | 推奨SessionService | 推奨ArtifactService | 特徴 |
|-----|-------------------|--------------------|----|
| ローカル開発 | InMemory | InMemory | 依存なし・高速 |
| Cloud Functions | Database（SQLite不可） | GCS | シンプル・サーバーレス |
| Cloud Run | Database または VertexAi | GCS | カスタムアプリ・認証制御 |
| Vertex AI Agent Engine | VertexAi | GCS | 完全マネージド・大規模 |

### 12.5 コスト最適化

書籍のコスト管理ガイドラインより:

| 施策 | 効果 | 実装 |
|-----|------|------|
| Context Caching | LLMコスト削減（長いプロンプト） | `ContextCacheConfig` |
| Context Compaction | 長期セッションのトークン数削減 | `EventsCompactionConfig` |
| Artifact GCS移動 | メモリ使用量削減 | `GcsArtifactService` |
| セッションTTL | ストレージコスト削減 | TTL設定 + `delete_session()` |
| Memory圧縮 | RAGインデックスサイズ削減 | セッション要約 → Memory保存 |

---

## 13. State Lifecycle

書籍の「State Management and Context Inheritance」を基にした状態ライフサイクル管理。

### 13.1 状態の誕生から消滅まで

```
Session作成
    ↓ create_session(state={"初期値": "optional"})
セッション開始
    ↓
Tool/Callback内でctx.state["key"] = value
    ↓
EventActions.state_delta に記録
    ↓
append_event() でDB/Vertex AI に永続化
    ↓
get_session() で復元（次回リクエスト時）
    ↓
... 複数ターン繰り返し ...
    ↓
セッション終了（TTL or 明示的削除）
    ↓ MemoryServiceへ重要情報を転写
delete_session()
    ↓
Session State消滅（User/App stateは残存）
```

### 13.2 コンテキスト継承パターン

書籍の「Context Inheritance」パターン:

```python
# パターン1: 同一セッション内の継承
async def stateful_workflow():
    """前のツール実行結果を次のツールに引き継ぐ"""
    runner = InMemoryRunner(agent=my_agent, app_name="TestApp")
    session = await runner.session_service.create_session(
        app_name="TestApp",
        user_id="user123",
        state={"user:name": "Alice", "task": "data_analysis"}  # 初期State
    )

    # ターン1: 分析実行
    async for event in runner.run_async(
        user_id="user123",
        session_id=session.id,
        new_message=Content(role="user", parts=[Part(text="データを分析して")])
    ):
        pass

    # ターン2: 前回の結果（State）を引き継ぎ
    async for event in runner.run_async(
        user_id="user123",
        session_id=session.id,  # 同一セッション
        new_message=Content(role="user", parts=[Part(text="結果をグラフ化して")])
    ):
        if event.is_final_response():
            print(event.content.parts[0].text)
```

```python
# パターン2: セッション間の状態継承（User/App State経由）
# セッション1終了
old_state = old_session.state

# セッション2開始（User/App stateは自動的に引き継がれる）
new_session = await session_service.create_session(
    app_name="MyApp",
    user_id="user123",
    # User/App stateはユーザーID/アプリ名で自動紐付け
)
# user:theme, user:name等のUser stateは自動で利用可能
```

### 13.3 StateとMemoryの使い分け

| 観点 | State | Memory |
|-----|-------|--------|
| 検索 | キー直接参照 | セマンティック検索 |
| スコープ | session/user/app | ユーザー横断 |
| データ型 | JSON互換型 | テキストコンテンツ |
| 向き | 構造化データ | 非構造化記憶 |
| 容量 | 小（数KB推奨） | 大（文書レベル） |
| 用途例 | 設定・プロファイル・タスク状態 | 会話履歴・知識ベース |

---

## 14. Agent評価

### 14.1 評価エコシステム

| コンポーネント | 説明 |
|-------------|------|
| `adk eval` | CLI評価実行 |
| `AgentEvaluator` | プログラマティック評価 |
| `EvalSet` | テストケース集合 |
| `EvalCase` | 単一テストケース |
| `SimulatedUser` | 動的ユーザーシミュレーション |

### 14.2 7種のビルトインメトリクス

| Evaluator | メトリクス | スコア範囲 | 用途 |
|----------|-----------|----------|------|
| `TrajectoryEvaluator` | `tool_trajectory` | 0-1 | ツール呼び出しシーケンスの正確性 |
| `ResponseEvaluator` | `response_match` | 0-1 | ROUGE-1ベース応答一致度 |
| `ResponseEvaluator` | `final_response_match_v2` | 0-1 | 最終応答一致度（v2） |
| `ResponseEvaluator` | `rubric_based_quality` | 0-5 | ルーブリックベース品質評価 |
| `ResponseEvaluator` | `rubric_based_tool_use` | 0-5 | ルーブリックベースツール使用評価 |
| `ResponseEvaluator` | `hallucinations` | 0-1 | ハルシネーション検出 |
| `ResponseEvaluator` | `safety` | 0-1 | 安全性チェック |

### 14.3 evalsetファイル形式

**JSON形式:**

```json
{
  "eval_set_id": "customer-support-tests",
  "name": "カスタマーサポートAgentテスト",
  "description": "基本応答・ツール使用・ハルシネーション検出",
  "eval_cases": [
    {
      "eval_id": "case_001",
      "session_input": {
        "app_name": "SupportApp",
        "user_id": "eval_user",
        "state": {"user:language": "ja", "user:tier": "premium"}
      },
      "conversation": [
        {
          "user_content": {"role": "user", "parts": [{"text": "注文状況を教えてください"}]},
          "final_response": {"role": "model", "parts": [{"text": "注文番号をお聞かせください"}]},
          "intermediate_data": {
            "tool_uses": [{"name": "check_order_status", "args": {"order_id": "12345"}}]
          }
        }
      ]
    }
  ]
}
```

**YAML形式も対応:**

```yaml
eval_set_id: customer-support-tests
name: カスタマーサポートAgentテスト
eval_cases:
  - eval_id: case_001
    session_input:
      app_name: SupportApp
      user_id: eval_user
      state:
        user:language: ja
    conversation:
      - user_content:
          role: user
          parts:
            - text: 注文状況を教えてください
        final_response:
          role: model
          parts:
            - text: 注文番号をお聞かせください
```

### 14.4 実行方法

```bash
# CLI実行（全メトリクス）
adk eval path/to/agent tests.evalset.json

# 特定メトリクスのみ実行
adk eval path/to/agent tests.evalset.json \
    --metrics tool_trajectory,hallucinations,safety

# 特定ケースのみ実行
adk eval path/to/agent tests.evalset.json:case_001,case_002

# 複数実行（LLM変動性考慮）
adk eval path/to/agent tests.evalset.json --num_runs 3
```

### 14.5 プログラマティック評価

```python
from google.adk.evaluation import AgentEvaluator

# 評価基準（合格ライン）
criteria = {
    "tool_trajectory_avg_score": 0.9,      # ツール精度90%以上
    "response_match_score": 0.75,           # 応答一致75%以上
    "hallucinations": 0.1,                  # ハルシネーション10%以下
    "safety": 0.95                          # 安全性95%以上
}

# 評価実行
results = AgentEvaluator.evaluate_eval_set(
    agent_module="path/to/agent",
    eval_set=my_eval_set,
    criteria=criteria,
    num_runs=3  # 3回実行の平均
)

print(f"評価結果: {results}")
```

### 14.6 SimulatedUser（動的テスト）

```python
from google.adk.evaluation import AgentEvaluator, SimulatedUser

simulated_user = SimulatedUser(
    persona="配送状況を確認したいオンラインショッピングユーザー",
    goal="先週注文した商品の届く日を確認する",
    communication_style="friendly"
)

evaluator = AgentEvaluator(
    agent=support_agent,
    eval_set=eval_set,
    simulated_user=simulated_user
)

results = await evaluator.evaluate_async()
```

**使い分け:**

| 状況 | 推奨方式 |
|-----|---------|
| 短い単純な会話 | 固定evalset（JSON/YAML） |
| 長いマルチターン会話 | SimulatedUser |
| LLM変動性考慮 | `num_runs=3` |
| CI/CDパイプライン | プログラマティック評価 |

### 14.7 Dev UI可視化

`adk web`の**Evalタブ**:
- EvalSetロード・評価トリガー
- 結果表示（全体スコア・ケース別・トレースリンク）
- 評価失敗時: Evalタブ → トレースビューでデバッグ

---

## 15. テレメトリ・デバッグ

### 15.1 OpenTelemetry統合

ADKはOpenTelemetry（OTel）で計装済み。

**トレース対象:**
- `runner.run_async()` 全体（Overall Invocation）
- 各`BaseAgent.run_async()`（Agent Run）
- `LlmRequest`と`LlmResponse`（LLM Call）
- Tool呼び出しと応答（Tool Call / Tool Response）
- `run_live`データ送信（Live LLM Data）

**トレース確認方法:**

| 方法 | 環境 | 推奨度 |
|-----|------|--------|
| **ADK Dev UI** | ローカル開発 | ⭐⭐⭐ 最優先 |
| **Cloud Trace** | デプロイ時（`--trace_to_cloud`） | ⭐⭐ |
| **カスタムOTelエクスポーター** | 本番高度分析 | ⭐ |

```bash
# Cloud Traceへの転送
adk deploy cloud_run --trace_to_cloud
adk api_server --trace_to_cloud
```

### 15.2 ロギング

```python
import logging

logger = logging.getLogger(__name__)  # モジュール別ロガー

def my_tool(param: str, tool_context: ToolContext) -> dict:
    logger.info(f"Tool called: {param}")
    result = process(param)
    logger.debug(f"Result: {result}")
    return {"output": result}

# ADK内部ログ制御
logging.getLogger('google_adk').setLevel(logging.INFO)  # or DEBUG
```

**⚠️ 機密情報ログ出力禁止:** PII・APIキー・機密プロンプト/応答は絶対にログ出力しない。

### 15.3 よくある問題と解決法

| 問題 | Dev UI確認箇所 | 解決策 |
|-----|-------------|--------|
| **Agentがtoolを使わない** | tool宣言の有無 | tool description・instructionを改善 |
| **Tool引数が誤り** | LLMが渡した引数 | 型ヒント・docstringのパラメータ説明を明確化 |
| **Toolエラー** | tool_responseのエラー | Tool単独テスト・ブレークポイント設置 |
| **認証エラー** | tool_responseの認証エラー | `auth_credential`設定・スコープ確認 |
| **予期しないAgent応答** | 完全プロンプト確認 | Instruction精緻化・temperature調整 |
| **State変更が反映されない** | state_deltaイベント | プレフィックス確認・append_event確認 |
| **Memoryが検索されない** | インデックス化の遅延 | `add_session_to_memory`後に待機時間設定 |

### 15.4 デバッグチェックリスト

**Agent Not Using a Tool:**
- [ ] Trace: `LlmRequest`にtool宣言が含まれているか
- [ ] Tool Description: LLMに明確で魅力的な説明か
- [ ] Agent Instruction: tool使用を推奨しているか

**State Not Persisted:**
- [ ] プレフィックスが正しいか（`user:`, `app:`, `temp:`）
- [ ] `ctx.state`への代入が実行されているか
- [ ] `append_event()`でEventが記録されているか

**Unexpected Memory Results:**
- [ ] RAGインデックス化の遅延（`add_session_to_memory`直後は検索に遅延あり）
- [ ] `similarity_top_k`と`vector_distance_threshold`の設定確認
- [ ] セッションデータが`add_session_to_memory`で正しく保存されているか

---

## まとめ

ADKランタイム主要コンポーネントの選択基準:

| コンポーネント | 開発/テスト | 本番（セルフホスト） | 本番（GCP） |
|-------------|-----------|------------------|------------|
| **SessionService** | InMemory | Database | VertexAi |
| **ArtifactService** | InMemory | GCS | GCS |
| **MemoryService** | InMemory | なし | VertexAiRag |
| **Runner** | InMemoryRunner | Runner | Runner |

**機能別バージョン要件:**

| 機能 | 最低バージョン |
|-----|------------|
| Resume Agents（ResumabilityConfig） | v1.14.0+ |
| Context Caching（ContextCacheConfig） | v1.15.0+ |
| Context Compaction（EventsCompactionConfig） | v1.16.0+ |
| Session Rewind | v1.17.0+ |

**設計の基本原則:**
1. **ステートレス設計**: Agentロジックはステートレス、状態は外部サービスに委譲
2. **スコープ最小化**: Stateのスコープは必要最小限（session → user → app）
3. **大容量はArtifact**: バイナリデータ・大ファイルはArtifactで管理
4. **長期記憶はMemory**: セッション横断の知識はMemoryServiceに保存
5. **Event追跡**: イベントログから実行履歴の完全再現が可能
6. **抽象基底クラス**: `BaseSessionService`等の抽象クラスで疎結合を実現

---

*このリファレンスは書籍「Agentic AI with Google ADK」（Kenneth W. Moe）・「Mastering Google ADK」（Nathan Steele）・ADK公式ドキュメントを統合した包括ガイドです。*
