# Plugins と Grounding 詳細ガイド

## 目次

1. [Plugin System](#plugin-system)
2. [Grounding](#grounding)

---

## Plugin System

### 概要

**Plugin**は、ADK Runnerにグローバルスコープで適用される拡張ポイント。`BasePlugin`を継承してカスタムPluginを作成することで、セキュリティガードレール、監視、ログ、監査などのクロスカッティング関心事をアプリケーション全体に統一的に適用できる。

### Plugin vs Callback の違い

| 観点 | Plugin | Callback |
|------|--------|----------|
| **スコープ** | Runner全体（グローバル） | 特定のAgent（ローカル） |
| **用途** | セキュリティガードレール、監視、ログ、監査 | Agent固有のカスタマイズ |
| **設定場所** | Runner初期化時 | Agent定義時（`before_agent_callback`等） |
| **ADK公式推奨** | アプリケーション全体のガードレール・横断的関心事 | Agent固有の前後処理 |
| **影響範囲** | すべてのAgentに適用 | 設定されたAgent内のみ有効 |

**Pluginの利点:**
- **一貫性**: 全Agentに同じガードレールを自動適用
- **保守性**: セキュリティルールを一箇所で管理
- **再利用**: 複数プロジェクトで共通Pluginを使用可能

**Callbackの利点:**
- **柔軟性**: Agent固有の振る舞いをカスタマイズ
- **軽量**: 特定Agentのみに処理を限定

### Plugin vs Callback 判断基準

| ユースケース | 最適な選択 | 理由 |
|------------|----------|------|
| 不適切入力のブロック（全Agent） | Plugin | 全Agentに統一的なガードレールを適用 |
| PII検出とフィルタリング（全Agent） | Plugin | セキュリティポリシーの一元管理 |
| API呼び出しメトリクスの収集 | Plugin | アプリケーション全体のオブザーバビリティ |
| 特定Agentの動的instruction注入 | Callback | Agent固有のコンテキスト依存ロジック |
| 特定Toolの引数カスタマイズ | Callback | Agent内部の振る舞い調整 |
| レート制限（全Tool） | Plugin | グローバルなクオータ管理 |

---

## 6つのライフサイクルフック

Pluginは、ADKの実行フローの6つのポイントで介入可能。

### 1. on_user_message

**タイミング**: ユーザーメッセージをAgentが受信する前
**用途**: 入力バリデーション、PII検出、不適切コンテンツブロック

```python
from google.adk.plugins import BasePlugin
from google.genai.types import Content, Part
from typing import Optional

class InputValidationPlugin(BasePlugin):
    """ユーザー入力の検証Plugin"""

    BLOCKED_PATTERNS = ["暴力的", "違法", "不適切"]

    async def on_user_message(self, context, message: Content) -> Optional[Content]:
        """
        ユーザーメッセージを検証。Contentを返すと以降の処理をスキップ。

        Args:
            context: 実行コンテキスト
            message: ユーザーが送信したContent

        Returns:
            - Content: ブロック応答（Agent実行をスキップ）
            - None: 正常な処理を継続
        """
        if message.parts:
            text = message.parts[0].text.lower()

            for pattern in self.BLOCKED_PATTERNS:
                if pattern in text:
                    return Content(parts=[Part.from_text(
                        f"不適切な内容が検出されました。ポリシーに違反しています。"
                    )])

        return None  # 通常処理を継続
```

### 2. before_run

**タイミング**: Agent実行の直前
**用途**: 認証チェック、コンテキスト注入、実行前ログ

```python
class AuthenticationPlugin(BasePlugin):
    """認証チェックPlugin"""

    async def before_run(self, context) -> None:
        """
        Agent実行前に認証状態を確認。例外を発生させるとAgent実行を中断。

        Raises:
            AuthenticationError: 認証が必要な場合
        """
        user_id = context.metadata.get("user_id")
        if not user_id:
            raise AuthenticationError("ユーザーIDが必要です")

        if not self._is_authenticated(user_id):
            raise AuthenticationError("認証されていません")

        # ログ記録
        self._log_execution_start(user_id, context.invocation_id)

    def _is_authenticated(self, user_id: str) -> bool:
        # 実際の認証ロジック
        return user_id in self.authenticated_users

    def _log_execution_start(self, user_id: str, invocation_id: str):
        print(f"[AUTH] User {user_id} started invocation {invocation_id}")
```

### 3. after_run

**タイミング**: Agent実行完了後
**用途**: メトリクス収集、結果ログ、監査記録

```python
from google.genai.types import Content

class MetricsPlugin(BasePlugin):
    """メトリクス収集Plugin"""

    async def after_run(self, context, result: Content) -> None:
        """
        Agent完了後にメトリクスを記録。

        Args:
            context: 実行コンテキスト
            result: Agentが生成したContent
        """
        user_id = context.metadata.get("user_id")
        agent_name = context.metadata.get("agent_name", "unknown")

        # レスポンス長を記録
        response_length = len(result.parts[0].text) if result.parts else 0

        # メトリクス送信
        self._emit_metric("agent_response_length", response_length, {
            "user_id": user_id,
            "agent_name": agent_name,
            "invocation_id": context.invocation_id
        })

        # 監査ログ
        self._audit_log({
            "timestamp": datetime.utcnow().isoformat(),
            "user_id": user_id,
            "agent": agent_name,
            "response_preview": result.parts[0].text[:100] if result.parts else ""
        })

    def _emit_metric(self, metric_name: str, value: float, tags: dict):
        # Prometheus/CloudWatch等に送信
        pass

    def _audit_log(self, data: dict):
        # 監査ログシステムに記録
        pass
```

### 4. on_event

**タイミング**: Eventが生成された時
**用途**: イベントフィルタリング、監査ログ、リアルタイム監視

```python
from google.adk.events import Event

class EventAuditPlugin(BasePlugin):
    """イベント監査Plugin"""

    async def on_event(self, context, event: Event) -> Optional[Event]:
        """
        イベント発生時に監査ログを記録。修正したEventを返すと置換可能。

        Args:
            context: 実行コンテキスト
            event: 発生したEvent

        Returns:
            - Event: 修正したEvent（置換）
            - None: 元のEventをそのまま使用
        """
        # 全イベントを監査ログに記録
        self._log_event({
            "event_id": event.id,
            "author": event.author,
            "invocation_id": event.invocation_id,
            "content_preview": self._preview_content(event.content)
        })

        # Function Call イベントの場合、引数をサニタイズ
        if event.get_function_calls():
            function_calls = event.get_function_calls()
            for fc in function_calls:
                if fc.name == "sensitive_api":
                    # 機密情報をマスク
                    if "api_key" in fc.args:
                        fc.args["api_key"] = "[REDACTED]"

            # 修正したEventを返す（オプション）
            return event

        return None  # 元のEventを使用

    def _log_event(self, data: dict):
        # イベント監査システムに送信
        pass

    def _preview_content(self, content):
        if content and content.parts:
            return content.parts[0].text[:50]
        return ""
```

### 5. on_model_error

**タイミング**: LLMモデル呼び出しでエラーが発生した時
**用途**: フォールバック処理、リトライ、エラー通知

```python
from google.genai.errors import GoogleAPIError
from google.genai.types import Content, Part

class FallbackPlugin(BasePlugin):
    """モデルエラー時のフォールバックPlugin"""

    async def on_model_error(self, context, error: Exception) -> Optional[Content]:
        """
        モデルエラー時にフォールバック処理。Contentを返すとエラーを回復。

        Args:
            context: 実行コンテキスト
            error: 発生した例外

        Returns:
            - Content: フォールバック応答（エラーを回復）
            - None: エラーを再度発生させる
        """
        # API制限エラーの場合
        if isinstance(error, GoogleAPIError) and "quota" in str(error).lower():
            # アラート送信
            self._send_alert(f"Quota exceeded: {error}")

            # フォールバック応答
            return Content(parts=[Part.from_text(
                "現在、リクエストが集中しています。しばらくしてから再度お試しください。"
            )])

        # その他のエラーはログのみ記録して再発生
        self._log_error(error, context.invocation_id)
        return None  # エラーを再発生

    def _send_alert(self, message: str):
        # Slack/PagerDuty等に通知
        pass

    def _log_error(self, error: Exception, invocation_id: str):
        print(f"[ERROR] Invocation {invocation_id}: {error}")
```

### 6. on_tool_error

**タイミング**: Tool実行でエラーが発生した時
**用途**: Tool固有のエラーハンドリング、リトライ、通知

```python
import asyncio

class ToolErrorHandlerPlugin(BasePlugin):
    """Toolエラーハンドリング・リトライPlugin"""

    MAX_RETRIES = 3

    async def on_tool_error(
        self,
        context,
        tool_name: str,
        error: Exception,
        retry_count: int = 0
    ) -> Optional[dict]:
        """
        Tool実行エラー時の処理。dictを返すとエラーから回復。

        Args:
            context: 実行コンテキスト
            tool_name: 実行されたTool名
            error: 発生した例外
            retry_count: 現在のリトライ回数

        Returns:
            - dict: リトライ結果またはエラーメッセージ
            - None: エラーを再発生
        """
        # 一時的なネットワークエラーの場合はリトライ
        if self._is_transient_error(error) and retry_count < self.MAX_RETRIES:
            wait_time = 2 ** retry_count  # 指数バックオフ
            print(f"[RETRY] Tool {tool_name} failed, retrying in {wait_time}s...")
            await asyncio.sleep(wait_time)

            # リトライロジックをここに実装（実際のTool呼び出しは別途必要）
            return {
                "status": "retried",
                "message": f"リトライ中（{retry_count + 1}/{self.MAX_RETRIES}）"
            }

        # リトライ上限到達または非一時的エラー
        self._notify_admin(tool_name, error)

        return {
            "error": f"Tool '{tool_name}' の実行に失敗しました: {str(error)}"
        }

    def _is_transient_error(self, error: Exception) -> bool:
        # TimeoutError, ConnectionError等を判定
        return isinstance(error, (TimeoutError, ConnectionError))

    def _notify_admin(self, tool_name: str, error: Exception):
        # 管理者に通知
        pass
```

---

## Pluginの作成と登録

### 基本的なPlugin実装パターン

```python
from google.adk.plugins import BasePlugin
from typing import Optional

class SecurityPlugin(BasePlugin):
    """セキュリティガードレールを統合したPlugin"""

    def __init__(self, config: dict):
        super().__init__()
        self.config = config
        self.blocked_patterns = config.get("blocked_patterns", [])

    async def on_user_message(self, context, message):
        # 入力バリデーション
        if self._contains_harmful_content(message):
            return self._block_response("不適切な内容が検出されました")
        return None

    async def before_run(self, context):
        # 認証チェック
        if not self._is_authenticated(context):
            raise AuthenticationError("認証が必要です")

    async def after_run(self, context, result):
        # メトリクス収集
        self._log_metrics(context, result)

    async def on_event(self, context, event):
        # 監査ログ
        self._audit_log(event)
        return None

    async def on_model_error(self, context, error):
        # フォールバック
        return self._fallback_response(error)

    async def on_tool_error(self, context, tool_name, error, retry_count=0):
        # エラーハンドリング
        self._notify_admin(tool_name, error)
        return None

    # ヘルパーメソッド
    def _contains_harmful_content(self, message) -> bool:
        if message.parts:
            text = message.parts[0].text.lower()
            return any(pattern in text for pattern in self.blocked_patterns)
        return False

    def _block_response(self, message: str):
        from google.genai.types import Content, Part
        return Content(parts=[Part.from_text(message)])

    def _is_authenticated(self, context) -> bool:
        # 認証ロジック
        return context.metadata.get("user_id") is not None

    def _log_metrics(self, context, result):
        # メトリクス送信
        pass

    def _audit_log(self, event):
        # 監査ログ記録
        pass

    def _fallback_response(self, error):
        from google.genai.types import Content, Part
        return Content(parts=[Part.from_text(
            "エラーが発生しました。しばらくしてから再度お試しください。"
        )])

    def _notify_admin(self, tool_name: str, error: Exception):
        # 管理者通知
        pass
```

### RunnerへのPlugin登録

```python
from google.adk import Runner
from google.adk.agents import Agent

# Plugin初期化
security_plugin = SecurityPlugin(config={
    "blocked_patterns": ["暴力的", "違法", "不適切"]
})

monitoring_plugin = MonitoringPlugin(config={
    "metrics_endpoint": "https://metrics.example.com"
})

# Agent定義
agent = Agent(
    name="assistant",
    model="gemini-2.0-flash",
    instruction="ユーザーの質問に答える親切なアシスタント"
)

# Runner初期化時にPluginを登録
runner = Runner(
    agent=agent,
    plugins=[
        security_plugin,
        monitoring_plugin
    ]
)

# 実行
response = runner.run("こんにちは")
```

**注意:**
- Pluginは**リスト順に実行**される
- セキュリティPluginは最初に配置を推奨（早期ブロックのため）
- 監視・ログPluginは最後に配置を推奨（全処理を観測するため）

---

## プリビルトPlugin

ADKが提供する既製Pluginを利用することで、一般的なユースケースを簡単に実装できる。

### RateLimitPlugin（例）

```python
from google.adk.plugins import RateLimitPlugin

# レート制限Plugin（架空の例）
rate_limit_plugin = RateLimitPlugin(
    max_requests_per_minute=10,
    max_requests_per_hour=100,
    user_id_extractor=lambda context: context.metadata.get("user_id")
)

runner = Runner(
    agent=agent,
    plugins=[rate_limit_plugin]
)
```

**注意**: ADK v1.xではプリビルトPluginは限定的。将来のバージョンで拡充予定。カスタムPluginの実装が一般的。

---

## Plugin vs Callback 実装パターン比較

### ユースケース: 入力バリデーション

#### Plugin実装（推奨: 全Agent共通）

```python
class InputValidationPlugin(BasePlugin):
    async def on_user_message(self, context, message):
        if self._is_invalid(message):
            return self._block_response()
        return None

runner = Runner(agent=agent, plugins=[InputValidationPlugin()])
```

#### Callback実装（特定Agent内のみ）

```python
def validate_input_callback(context, message):
    if is_invalid(message):
        return block_response()
    return None

agent = Agent(
    name="specific_agent",
    model="gemini-2.0-flash",
    before_agent_callback=validate_input_callback
)
```

### ユースケース: メトリクス収集

#### Plugin実装（推奨: 全Agent統一）

```python
class MetricsPlugin(BasePlugin):
    async def after_run(self, context, result):
        self._emit_metric("agent_invocations", 1)

runner = Runner(agent=agent, plugins=[MetricsPlugin()])
```

#### Callback実装（Agent個別）

```python
def metrics_callback(context, result):
    emit_metric("specific_agent_invocations", 1)

agent = Agent(
    name="specific_agent",
    model="gemini-2.0-flash",
    after_agent_callback=metrics_callback
)
```

---

## ベストプラクティス

### 1. Pluginは軽量に保つ

```python
class FastPlugin(BasePlugin):
    async def on_user_message(self, context, message):
        # ❌ 重い処理を同期的に実行
        result = heavy_synchronous_operation(message)

        # ✅ 非同期処理を使用
        result = await self._async_validation(message)

        return None

    async def _async_validation(self, message):
        # 非同期でバリデーション実行
        pass
```

### 2. エラーハンドリングを適切に

```python
class RobustPlugin(BasePlugin):
    async def on_event(self, context, event):
        try:
            self._audit_log(event)
        except Exception as e:
            # Pluginの失敗でAgent実行を中断しない
            print(f"[WARN] Audit log failed: {e}")

        return None
```

### 3. コンテキストからメタデータを活用

```python
class ContextAwarePlugin(BasePlugin):
    async def before_run(self, context):
        # ユーザー情報を取得
        user_id = context.metadata.get("user_id")
        session_id = context.metadata.get("session_id")

        # コンテキストに応じた処理
        if self._is_premium_user(user_id):
            # プレミアムユーザーはスキップ
            return

        # 通常ユーザーはレート制限チェック
        if self._exceed_rate_limit(user_id):
            raise RateLimitError("レート制限に達しました")
```

### 4. Plugin設定を外部化

```python
import os
from typing import Dict

class ConfigurablePlugin(BasePlugin):
    def __init__(self):
        super().__init__()
        self.config = self._load_config()

    def _load_config(self) -> Dict:
        return {
            "blocked_patterns": os.getenv("BLOCKED_PATTERNS", "").split(","),
            "max_requests": int(os.getenv("MAX_REQUESTS", "100")),
            "admin_email": os.getenv("ADMIN_EMAIL", "admin@example.com")
        }
```

---

## Grounding

### 概要

**Grounding**（グラウンディング）は、Agentの回答を外部データソースで根拠付ける仕組み。LLMのハルシネーション（事実と異なる生成）を抑制し、最新情報や企業固有データに基づく正確な回答を実現する。

ADKは以下の3つのGrounding方式をサポート:

1. **Google Search Grounding**: 最新のWeb検索結果で回答を根拠付け
2. **Vertex AI Search Grounding**: 企業データストア（ドキュメント、Webサイト、構造化データ）から検索
3. **Agentic RAG**: Agent的なRAG（Retrieval-Augmented Generation）パターン

---

## 3つのGrounding方式

### 1. Google Search Grounding

**概要**: 最新のWeb検索結果をLLMに提供し、回答の根拠とする。ニュース、一般情報、リアルタイムデータに最適。

#### 基本実装

```python
from google.adk.agents import Agent
from google.adk.tools import google_search

agent = Agent(
    name="search_agent",
    model="gemini-2.0-flash",  # Gemini 2.0以降が必須
    tools=[google_search],
    instruction="""
    ユーザーの質問に答える際、最新情報が必要な場合はgoogle_searchツールを使用してください。
    検索結果に基づいて、正確で最新の情報を提供してください。
    """
)

# 実行
response = agent.run("2024年のノーベル賞受賞者は誰ですか？")
print(response.text)

# Grounding Metadataにアクセス
if response.grounding_metadata:
    print("検索クエリ:", response.grounding_metadata.search_entry_point.query)
    print("出典:")
    for chunk in response.grounding_metadata.grounding_chunks:
        print(f"  - {chunk.web.title}: {chunk.web.uri}")
```

#### Grounding Metadata

```python
from google.genai.types import GroundingMetadata

# レスポンスからGrounding情報を取得
grounding = response.grounding_metadata

if grounding:
    # 検索クエリ
    query = grounding.search_entry_point.query
    print(f"検索に使用されたクエリ: {query}")

    # 引用された出典
    for chunk in grounding.grounding_chunks:
        print(f"タイトル: {chunk.web.title}")
        print(f"URL: {chunk.web.uri}")
        print(f"スニペット: {chunk.web.snippet}")
```

**特徴:**
- Gemini 2.0以降のモデルで自動統合
- LLMが検索クエリを自動生成
- 検索結果は`grounding_metadata`に含まれる
- 出典URLを自動的に引用可能

**ユースケース:**
- ニュース記事の要約
- 最新の製品情報取得
- リアルタイムデータ（株価、天気等）の検索

---

### 2. Vertex AI Search Grounding

**概要**: Google Cloud Vertex AI Searchを利用して、企業のプライベートデータストアから検索。社内文書、ナレッジベース、構造化データに対するGroundingに最適。

#### 事前準備

1. **Vertex AI Search データストア作成**
   - Google Cloud Consoleで Vertex AI Search データストアを作成
   - ドキュメント（PDF, HTML, TXT等）をアップロード
   - インデックス構築を待つ

2. **環境変数設定**

```bash
export GOOGLE_GENAI_USE_VERTEXAI=1
export GOOGLE_CLOUD_PROJECT=your-project-id
export VERTEX_AI_SEARCH_DATA_STORE_ID=your-data-store-id
```

#### 基本実装

```python
from google.adk.tools import VertexAiSearchTool
from google.adk.agents import Agent
import os

# データストアIDを取得
data_store_id = os.getenv("VERTEX_AI_SEARCH_DATA_STORE_ID")

# Vertex AI Search Tool作成
vertex_search = VertexAiSearchTool(
    data_store_id=data_store_id,
    max_results=5  # 最大検索結果数
)

agent = Agent(
    name="knowledge_base_agent",
    model="gemini-2.0-flash",
    tools=[vertex_search],
    instruction="""
    ユーザーの質問に答える際、社内データストアから関連情報を検索してください。
    検索結果に基づいて、正確な情報を提供してください。
    """
)

# 実行
response = agent.run("当社の返品ポリシーは何ですか？")
print(response.text)
```

#### 高度な検索設定

```python
from google.adk.tools import VertexAiSearchTool

vertex_search = VertexAiSearchTool(
    data_store_id=data_store_id,
    max_results=10,
    filter_expression="category = 'policy' AND status = 'active'",  # フィルタ
    boost_spec={  # ブースト設定
        "condition_boost_specs": [
            {
                "condition": "document_freshness > 30",
                "boost": 1.5
            }
        ]
    }
)
```

**特徴:**
- 企業固有のデータソースに対応
- アクセス制御（IAM）を適用可能
- 構造化データとドキュメントを統合検索
- フィルター、ブースト、ファセット検索をサポート

**ユースケース:**
- 社内FAQシステム
- 製品マニュアル検索
- カスタマーサポート自動化
- コンプライアンス文書の参照

**データソースの種類:**
- 非構造化データ: PDF, DOCX, HTML, TXT等
- 構造化データ: BigQuery, Cloud SQL
- Webサイト: クローリング

---

### 3. Agentic RAG

**概要**: 従来のRAG（Retrieval-Augmented Generation）をAgent的に拡張したパターン。LLMが検索クエリを動的に生成・最適化し、マルチステップ検索を実行する。

#### 従来のRAG vs Agentic RAG

| 特性 | 従来のRAG | Agentic RAG |
|------|---------|------------|
| **検索クエリ** | ユーザー入力をそのまま使用 | LLMが最適化されたクエリを生成 |
| **検索回数** | 1回（固定） | 複数回（必要に応じて動的） |
| **検索戦略** | 単一の検索手法 | 複数の検索手法を組み合わせ |
| **コンテキスト理解** | 静的 | 検索結果を解釈して次の検索に活用 |

#### 基本実装

```python
from google.adk.agents import Agent
from google.adk.tools import FunctionTool
from typing import List

# カスタム検索ツール
def search_knowledge_base(query: str, filters: dict = None) -> List[dict]:
    """
    ナレッジベースから情報を検索します。

    Args:
        query: 検索クエリ
        filters: フィルター条件 (例: {"category": "technical", "language": "ja"})

    Returns:
        検索結果のリスト
    """
    # 実際の検索ロジック（例: ベクトルDB検索）
    results = vector_db.search(query, filters=filters, top_k=5)
    return [{"title": r.title, "content": r.content, "score": r.score} for r in results]

search_tool = FunctionTool(func=search_knowledge_base)

# Agentic RAG Agent
agentic_rag_agent = Agent(
    name="agentic_rag",
    model="gemini-2.0-flash",
    tools=[search_tool],
    instruction="""
    ユーザーの質問に答えるために、search_knowledge_baseツールを使用してください。

    戦略:
    1. まず、ユーザーの質問から最も重要なキーワードを抽出し、初回検索を実行
    2. 検索結果を評価し、不十分な場合は別の角度から再検索
    3. 複数の検索結果を統合して、包括的な回答を生成
    4. 検索結果に基づく場合は、出典を明記

    注意: 検索クエリは簡潔かつ具体的にすること。
    """
)

# 実行
response = agentic_rag_agent.run("React Hooksのベストプラクティスは？")
print(response.text)
```

#### マルチステップ検索パターン

```python
agentic_rag_agent = Agent(
    name="multi_step_rag",
    model="gemini-2.0-flash",
    tools=[search_tool],
    instruction="""
    複雑な質問には、段階的な検索戦略を使用してください:

    ステップ1: 広範囲の検索
    - 質問の主要なトピックで初回検索

    ステップ2: 結果の評価
    - 初回検索で十分な情報が得られたか確認
    - 不足している情報を特定

    ステップ3: 深掘り検索
    - 不足情報に特化した追加検索
    - より具体的なフィルターを適用

    ステップ4: 統合
    - すべての検索結果を統合して回答を生成
    """
)
```

#### ハイブリッド検索（キーワード + ベクトル）

```python
def hybrid_search(query: str, alpha: float = 0.5) -> List[dict]:
    """
    キーワード検索とベクトル検索を組み合わせたハイブリッド検索。

    Args:
        query: 検索クエリ
        alpha: ベクトル検索の重み (0.0=完全キーワード, 1.0=完全ベクトル)

    Returns:
        検索結果
    """
    # キーワード検索
    keyword_results = keyword_index.search(query, top_k=10)

    # ベクトル検索
    vector_results = vector_db.search(query, top_k=10)

    # ハイブリッドスコア計算
    combined = combine_results(keyword_results, vector_results, alpha)
    return combined

hybrid_search_tool = FunctionTool(func=hybrid_search)

agent = Agent(
    name="hybrid_rag",
    model="gemini-2.0-flash",
    tools=[hybrid_search_tool],
    instruction="hybrid_searchツールを使って、キーワードと意味の両方から検索してください。"
)
```

**特徴:**
- LLMが検索戦略を自律的に決定
- 複数の検索を組み合わせて最適な結果を取得
- 検索結果の品質を評価してフィードバックループを形成

**ユースケース:**
- 複雑な技術質問への回答
- 研究論文の包括的な要約
- マルチソース情報の統合
- 探索的な情報検索

---

## Grounding方式の選択基準

| 方式 | データソース | ユースケース | コスト | 実装難易度 | レイテンシ |
|------|------------|------------|--------|----------|----------|
| **Google Search Grounding** | 公開Web | 最新ニュース、一般情報、リアルタイムデータ | API課金（低） | 低 | 低 |
| **Vertex AI Search Grounding** | 企業データストア | 社内文書、プライベートデータ、ナレッジベース | Vertex AI課金（中） | 中 | 中 |
| **Agentic RAG** | カスタムベクトルDB | 高度な検索ロジック、マルチステップ検索 | インフラ+推論（中〜高） | 高 | 中〜高 |

### 選択ガイドライン

#### Google Search Grounding を選択
- 最新の公開情報が必要
- シンプルな実装を希望
- 低コストで始めたい

#### Vertex AI Search Grounding を選択
- 企業固有のデータソースを使用
- アクセス制御が必要
- マネージドサービスを活用したい

#### Agentic RAG を選択
- 複雑な検索ロジックが必要
- マルチステップ検索を実装したい
- ベクトルDBのカスタマイズが必要

---

## Grounding + Plugin の組み合わせ

```python
from google.adk.plugins import BasePlugin
from google.adk.tools import google_search
from google.adk.agents import Agent

class GroundingMonitorPlugin(BasePlugin):
    """Grounding結果を監視するPlugin"""

    async def after_run(self, context, result):
        # Grounding Metadataを確認
        if hasattr(result, 'grounding_metadata') and result.grounding_metadata:
            grounding = result.grounding_metadata
            query = grounding.search_entry_point.query
            num_sources = len(grounding.grounding_chunks)

            # メトリクス記録
            self._emit_metric("grounding_used", 1, {
                "query": query,
                "num_sources": num_sources
            })

            # 出典品質チェック
            if num_sources == 0:
                print(f"⚠️ 検索結果なし: クエリ '{query}'")
        else:
            print("⚠️ Groundingが使用されていません")

# Agent + Grounding + Plugin
agent = Agent(
    name="grounded_agent",
    model="gemini-2.0-flash",
    tools=[google_search],
    instruction="最新情報を検索して回答してください。"
)

runner = Runner(
    agent=agent,
    plugins=[GroundingMonitorPlugin()]
)
```

---

## ベストプラクティス

### 1. Groundingの明示的指示

```python
agent = Agent(
    name="search_agent",
    model="gemini-2.0-flash",
    tools=[google_search],
    instruction="""
    ユーザーの質問に答える際:
    1. 最新情報が必要な場合は、必ずgoogle_searchを使用
    2. 検索結果に基づいて回答を生成
    3. 出典URLを明記
    4. 検索結果が不十分な場合は、別のクエリで再検索
    """
)
```

### 2. 検索クエリの最適化

```python
# ❌ 曖昧な指示
instruction = "検索して答えてください。"

# ✅ 明確な指示
instruction = """
検索クエリは以下のルールに従ってください:
- 簡潔で具体的なキーワードを使用
- 年号や固有名詞を含める
- 複数の検索を組み合わせる場合は、角度を変える
"""
```

### 3. 出典の明示

```python
agent = Agent(
    name="citation_agent",
    model="gemini-2.0-flash",
    tools=[google_search],
    instruction="""
    回答には必ず出典を含めてください。

    フォーマット:
    [回答内容]

    出典:
    - [タイトル](URL)
    - [タイトル](URL)
    """
)
```

### 4. Grounding結果の検証

```python
def validate_grounding(response):
    """Grounding結果の品質を検証"""
    if not response.grounding_metadata:
        print("❌ Groundingが使用されていません")
        return False

    grounding = response.grounding_metadata
    num_sources = len(grounding.grounding_chunks)

    if num_sources == 0:
        print("❌ 検索結果がありません")
        return False

    if num_sources < 2:
        print("⚠️ 出典が少ない（1件のみ）")

    print(f"✅ Grounding検証OK（{num_sources}件の出典）")
    return True

# 使用例
response = agent.run("量子コンピュータの最新動向は？")
validate_grounding(response)
```

---

## トラブルシューティング

### Google Search Groundingが動作しない

**原因と対策:**

1. **モデルバージョン**
   - Gemini 2.0以降が必須
   - `gemini-2.0-flash` または `gemini-2.0-pro` を使用

2. **ツール登録**
   - `google_search` を `tools` リストに含めているか確認

3. **Instruction**
   - LLMに検索を促す明示的な指示を含める

### Vertex AI Search Groundingのエラー

**原因と対策:**

1. **環境変数**
   - `GOOGLE_GENAI_USE_VERTEXAI=1`
   - `GOOGLE_CLOUD_PROJECT`
   - `VERTEX_AI_SEARCH_DATA_STORE_ID`

2. **IAM権限**
   - Vertex AI Search の読み取り権限が必要

3. **データストア状態**
   - データストアのインデックスが完了しているか確認

### Agentic RAG の検索が遅い

**原因と対策:**

1. **ベクトルDB最適化**
   - インデックスを適切に設定
   - キャッシュを活用

2. **検索結果数を制限**
   - `top_k` を 5-10 に制限

3. **並列検索**
   - 複数の検索を `asyncio.gather` で並列実行

```python
async def parallel_search(queries: List[str]) -> List[dict]:
    """複数クエリを並列検索"""
    results = await asyncio.gather(
        *[search_async(q) for q in queries]
    )
    return [r for sublist in results for r in sublist]  # flatten
```

---

## まとめ

### Plugin System

- **グローバルスコープ**: Runner全体に適用されるクロスカッティング関心事
- **6つのフック**: on_user_message, before/after_run, on_event, on_model/tool_error
- **ユースケース**: セキュリティガードレール、監視、ログ、監査

### Grounding

- **Google Search Grounding**: 最新公開情報の検索
- **Vertex AI Search Grounding**: 企業データストアの検索
- **Agentic RAG**: 動的でマルチステップな検索戦略

### 使い分け

| 要件 | 推奨方式 |
|------|---------|
| 全Agent共通のガードレール | Plugin |
| 特定Agentのカスタマイズ | Callback |
| 最新ニュース・一般情報 | Google Search Grounding |
| 社内文書・プライベートデータ | Vertex AI Search Grounding |
| 複雑な検索ロジック | Agentic RAG |
