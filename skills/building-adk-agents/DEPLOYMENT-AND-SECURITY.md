# デプロイとセキュリティ

Google ADK Agentのデプロイ、テレメトリ、セキュリティのリファレンス。

---

## 1. デプロイ

### 1.1 パッケージング

**必須ファイル:**

| ファイル | 説明 |
|---------|------|
| `agent.py` | `root_agent`定義 |
| `requirements.txt` | 依存関係（`google-adk`含む） |
| `Dockerfile` | コンテナ化デプロイ用 |

**プロジェクト構造例:**

```
my_adk_app/
├── agent.py
├── requirements.txt
├── Dockerfile
└── tools/
    └── custom_tool.py
```

### 1.2 デプロイオプション選択基準

| オプション | 用途 | 推奨環境 |
|----------|------|---------|
| **Vertex AI Agent Engine** | エンタープライズ | プロダクション（GCP） |
| **Google Cloud Run** | サーバーレス | サーバーレス（GCP） |
| **AWS Lambda / Azure Functions** | マルチクラウド | 他クラウド |
| **Kubernetes** | 大規模分散 | 複雑なマイクロサービス |

**AskUserQuestion:** デプロイ先選択時、ユーザー確認（GCP/AWS/Azure/オンプレミス）

### 1.3 Vertex AI Agent Engineへのデプロイ

**重要:** 実験的/プレビュー段階、予期しない動作の可能性あり

**前提:**
- GCPプロジェクト、Vertex AI API
- `gcloud` CLI認証
- GCSステージングバケット

**コマンド:**

```bash
adk deploy agent_engine \
  --project="project-id" \
  --region="us-central1" \
  --staging_bucket="gs://staging-bucket" \
  --adk_app="agent_engine_app" \
  my_agent_dir
```

### 1.4 Google Cloud Runへのデプロイ

**前提:**
- GCPプロジェクト、Cloud Run API有効
- `gcloud` CLI認証

**コマンド:**

```bash
adk deploy cloud_run \
  --project=$PROJECT_ID \
  --region=$REGION \
  --service_name=$SERVICE_NAME \
  --app_name=$APP_NAME \
  my_agent_dir
```

**オプション:**
- `--with_ui`: Web UI同時デプロイ（**開発・テスト専用**）
- `--session_db_url`: Session DB URL
- `--artifact_storage_uri`: Artifact保存先

**curlでAPI呼び出し:**

```bash
export TOKEN=$(gcloud auth print-identity-token)
export APP_URL="https://service-name.run.app"

# メッセージ送信
curl -X POST -H "Authorization: Bearer $TOKEN" \
  $APP_URL/run_sse \
  -H "Content-Type: application/json" \
  -d '{
    "app_name": "app",
    "user_id": "user1",
    "session_id": "session1",
    "new_message": {"role": "user", "parts": [{"text": "質問"}]}
  }'
```

**Secret Manager使用（推奨）:**
- GCP Secret Managerにシークレット保存
- Cloud RunサービスアカウントにSecret Accessor権限付与
- コード内でSecret Managerクライアントで取得

### 1.5 他のデプロイ先（`adk api_server`）

`adk api_server`はAPI専用バックエンド。

**コマンド:**

```bash
adk api_server ./my_agents \
  --host 0.0.0.0 \
  --port 8000 \
  --allow_origins "http://localhost:3000" \
  --session_db_url "sqlite:///./sessions.db"
```

**重要オプション:**
- `--allow_origins`: CORS許可オリジン（**必須、フロントエンド分離時**）

**CORS:** フロントエンド（例: `localhost:3000`）→バックエンド（`localhost:8000`）リクエスト時、`--allow_origins`で許可必要

---

## 2. テレメトリ・ロギング・デバッグ

### 2.1 OpenTelemetry統合

ADKは**OpenTelemetry**で計装。

**トレース対象:**
- Invocation、Agent Run、LLM Call、Tool Call/Response

**トレースビュー:**
1. **ADK Dev UI（推奨）**: `adk web .`→トレースタブ
2. **Cloud Trace**: デプロイ時`--trace_to_cloud`→GCP Console

### 2.2 ロギング戦略

**ロギング箇所:**
- Agent初期化、InstructionProvider、Callbacks、Tool `run_async`

**例:**

```python
import logging
logger = logging.getLogger(__name__)

def my_tool(param: str, tool_context: ToolContext) -> dict:
    logger.info(f"Tool called: {param}")
    result = process(param)
    logger.debug(f"Result: {result}")
    return {"output": result}
```

**ベストプラクティス:**
- モジュール別ロガー: `logging.getLogger(__name__)`
- 適切なログレベル: `DEBUG`, `INFO`, `WARNING`, `ERROR`
- ADK内部ログ制御: `logging.getLogger('google_adk').setLevel(logging.INFO)`
- **機密情報ログ出力禁止**（PII、APIキー）

### 2.3 デバッグ技法

#### 1. ADK Dev UI Trace View（最優先）

- `adk web .`→トレースタブ
- 階層的スパン表示（InvocationContext、LLM prompt、Tool引数・応答、state delta）

**デバッグ対象:**
- LLMがtoolを呼ばない理由→tool説明・instruction確認
- Tool呼び出し引数誤り→型ヒント・スキーマ確認
- Tool実行エラー→tool_response確認

#### 2. Pythonデバッガ（`pdb`）

```python
def my_tool(param: str, tool_context: ToolContext):
    import pdb; pdb.set_trace()  # ブレークポイント
    result = process(param)
    return {"output": result}
```

### 2.4 よくある問題と解決法

| 問題 | Trace確認 | 解決策 |
|-----|----------|--------|
| Agentがtool不使用 | tool宣言の有無 | tool description・instruction改善 |
| Tool引数誤り | LLM渡し引数 | 型ヒント・パラメータ説明明確化 |
| Toolエラー | tool_responseエラー | Tool単独テスト、ブレークポイント |
| 認証エラー | tool_response認証エラー | auth_credential設定・スコープ確認 |

---

## 3. セキュリティベストプラクティス

### 3.1 Agent攻撃サーフェス

| 箇所 | リスク |
|-----|--------|
| ユーザー入力 | プロンプトインジェクション |
| Tool入出力 | インジェクション攻撃 |
| 外部API | API脆弱性 |
| コード実行環境 | サンドボックス脱出 |
| 認証情報管理 | キー漏洩 |

### 3.2 セキュアなTool設計

#### 最小権限の原則

- Tool認証情報は最小権限のみ
- 例: カレンダー読み取り→`calendar.readonly`スコープのみ

#### 入力検証とサニタイゼーション

**Pydantic活用:**

```python
from pydantic import BaseModel, constr, validator

class FileParams(BaseModel):
    filename: constr(pattern=r"^[a-zA-Z0-9_.-]{1,50}$")
    content: str = Field(max_length=1024)

    @validator('filename')
    def no_traversal(cls, v):
        if '..' in v or v.startswith('/'):
            raise ValueError("不正なパス")
        return v

def secure_write(params: FileParams, tool_context: ToolContext) -> dict:
    safe_dir = "./agent_files/"
    target = os.path.join(safe_dir, params.filename)
    if not os.path.abspath(target).startswith(os.path.abspath(safe_dir)):
        return {"error": "不正"}
    with open(target, "w") as f:
        f.write(params.content)
    return {"status": "success"}
```

**ベストプラクティス:** LLMに生SQLクエリや生コマンド構築させない。パラメータ化。

#### Tool機能制限

- 特定・狭い機能のToolを設計
- 例: 汎用`execute_sql`ではなく`get_order_details(order_id)`

### 3.3 シークレット管理

**絶対禁止:** コード内ハードコーディング

**プロダクション:**
- **Google Cloud Secret Manager**推奨
- Cloud RunサービスアカウントにSecret Accessor権限
- コード内でSecret Managerクライアントで取得

**ADK認証:** OpenAPI/GoogleAPI Tool用に`AuthCredential`活用

**ベストプラクティス:** 認証情報を定期ローテーション

### 3.4 コード実行環境セキュリティ

| Executor | セキュリティ | 推奨 |
|---------|-----------|------|
| `BuiltInCodeExecutor` | 高 | モデルサポート時 |
| `UnsafeLocalCodeExecutor` | 極低 | **プロダクション禁止** |
| `ContainerCodeExecutor` | 良 | 適切設定で安全 |
| `VertexAiCodeExecutor` | 高 | クラウド推奨 |

**ContainerCodeExecutor推奨設定:**
- 最小ベースイメージ（`python:3.1x-slim`）
- 非rootユーザー実行
- ネットワーク制限
- リソース制限（CPU、メモリ）

### 3.5 プロンプトインジェクション対策

**緩和策（完全対策困難）:**

1. **強力なSystem Prompt**: コア指示を無視する試みを拒否するよう明示
2. **入力サニタイゼーション**: 疑わしいフレーズフィルタ（限定的）
3. **出力検証**: LLM出力の厳密検証
4. **Human-in-the-Loop**: 重要アクション前に人間確認
5. **アクションサンドボックス化**: 最小権限環境で実行

**多層防御:** 複数の防御層を組み合わせる

### 3.6 Session State / Artifactセキュリティ

- 平文シークレットをstate/artifactに保存禁止
- 永続ストレージのアクセス制御:
  - **DatabaseSessionService**: 強力パスワード、暗号化
  - **GcsArtifactService**: IAM権限制御

### 3.7 セキュリティチェックリスト

- [ ] Tool入力検証実装
- [ ] 最小権限適用
- [ ] シークレットをSecret Manager保管
- [ ] コード実行環境適切隔離
- [ ] プロンプトインジェクション対策
- [ ] 重要アクションに人間確認
- [ ] 機密情報を平文保存していない
- [ ] IAM権限適切設定
- [ ] 依存関係脆弱性スキャン実施

---

## 4. ADK拡張

### 4.1 カスタムBaseAgent

**使用ケース:**
- ルールベースAgent
- レガシーシステム統合
- 特殊オーケストレーター

**実装例:**

```python
from google.adk.agents import BaseAgent, InvocationContext
from google.adk.events.event import Event, EventActions
from google.genai.types import Content, Part
from typing import AsyncGenerator

class RuleBasedAgent(BaseAgent):
    async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]:
        # ルールベースロジック
        current = ctx.state.get("state", "init")
        next_state = transition_logic(current)
        actions = EventActions(state_delta={"state": next_state})
        yield Event(
            invocation_id=ctx.invocation_id,
            author=self.name,
            branch=ctx.branch,
            content=Content(parts=[Part(text=f"状態: {next_state}")]),
            actions=actions
        )
```

### 4.2 カスタムService

**カスタムArtifactService例:**

```python
from google.adk.artifacts import BaseArtifactService
from google.genai.types import Part

class FileSystemArtifactService(BaseArtifactService):
    def __init__(self, base_path: str = "./adk_artifacts"):
        self.base_path = base_path
        os.makedirs(base_path, exist_ok=True)

    async def save_artifact(self, *, app_name, user_id, session_id, filename, artifact: Part) -> int:
        # バージョン管理・ファイル保存実装
        ...
```

**ベストプラクティス:**
- カスタムServiceメソッドは`async def`
- I/O操作は非同期ライブラリ使用（`aiohttp`, `asyncpg`, `aiofiles`）

### 4.3 カスタムTool / Toolset

再利用可能Tool/Toolset開発時、ADKコミュニティへの貢献を検討。

**ガイドライン:**
- `BaseTool`/`BaseToolset`継承
- 明確なネーミング・説明
- 正確な`FunctionDeclaration`
- 堅牢なエラーハンドリング
- セキュリティ遵守
- ドキュメント・ユニットテスト

---

## 5. ADK CLIリファレンス

### 5.1 主要コマンド

| コマンド | 説明 |
|---------|------|
| `adk create APP` | 新規Agent作成 |
| `adk run AGENT` | 対話型CLI実行 |
| `adk eval AGENT EVAL_SET` | Agent評価 |
| `adk web [DIR]` | Dev UI起動 |
| `adk api_server [DIR]` | API専用サーバー |
| `adk deploy cloud_run` | Cloud Runデプロイ |
| `adk deploy agent_engine` | Agent Engineデプロイ |

### 5.2 重要オプション

**`adk web` / `adk api_server`:**
- `--session_db_url`: Session DB URL
- `--artifact_storage_uri`: Artifact保存先
- `--allow_origins`: CORS許可（`api_server`重要）
- `--trace_to_cloud`: Cloud Trace有効化

**`adk deploy cloud_run`:**
- `--with_ui`: Web UI同時デプロイ（開発専用）
- `--session_db_url`, `--artifact_storage_uri`: 永続化

---

## まとめ

ADKデプロイとセキュリティの主要領域:

1. **デプロイ**: Vertex AI、Cloud Run、`adk api_server`で柔軟展開
2. **テレメトリ**: OpenTelemetry、Cloud Trace、Dev UI
3. **デバッグ**: Dev UI最優先、pdb、ログ
4. **セキュリティ**: Tool入力検証、最小権限、Secret Manager、多層防御
5. **拡張**: カスタムAgent、Service、Tool

ベストプラクティス遵守でセキュアで堅牢なAgentシステムを構築。
