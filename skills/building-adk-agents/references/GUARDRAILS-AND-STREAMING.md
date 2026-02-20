# Guardrails、Callbacks、Plugin System、Streaming 詳細ガイド

このガイドでは、ADKのセキュリティ・制御機能（Callbacks、Plugin System、ガードレール）と
リアルタイム通信機能（SSEストリーミング、Live API音声処理）を包括的に解説する。

## 目次

1. [Callback 完全リファレンス](#callback-完全リファレンス)
2. [CallbackContext と ToolContext](#callbackcontext-と-toolcontext)
3. [ガードレールパターン](#ガードレールパターン)
4. [PIIフィルタリング](#piiフィルタリング)
5. [Plugin System](#plugin-system)
6. [Callbacks vs Plugins 判断基準](#callbacks-vs-plugins-判断基準)
7. [SSEストリーミング](#sseストリーミング)
8. [Live API 音声処理](#live-api-音声処理)

---

## Callback 完全リファレンス

### ADKのセキュリティ設計哲学

書籍が強調する通り、「セキュリティはボルトオンではなく、設計制約」である。ADKは以下の多層防御（Defense-in-Depth）アーキテクチャでこれを実現する。

```
User Input
    │
    ▼
Input Sanitisation ──► SafetyCallback / Plugin ──► Agent Planner
                        (unsafe? block/redact)
    │
    ▼
Tool Invocation
    │
In-tool Guard-Rails ──► before_tool_callback
    ▼
Agent Response
    │
Model Safety Filters (Vertex / Gemini)
    ▼
Output（ユーザーに届く）
```

各ホップはOTELスパンを出力し、ブロックされた呼び出しはDev UIで即座に可視化される。

### 6種類のCallback概観

ADKは6つのCallbackポイントを提供し、Agent実行の各フェーズで介入可能。

```
User Input
    → [before_agent] → Agent Logic → [after_agent] → Response
           ↓                                ↓
    [before_model] → LLM → [after_model]
           ↓                      ↓
    [before_tool] → Tool → [after_tool]
```

**制御フロールール（全Callback共通）**

| 戻り値 | 効果 |
|--------|------|
| 特定のオブジェクトを返す | その操作をスキップし、返された値を結果として使用 |
| `None` を返す | デフォルト動作を継続 |

---

### Agent ライフサイクル Callbacks

#### before_agent_callback

```python
from typing import Optional
from google.adk.agents.callback_context import CallbackContext
from google.genai import types

def before_agent_callback(callback_context: CallbackContext) -> Optional[types.Content]:
    """
    Agent実行前に呼ばれる。Contentを返すとAgent全体をスキップする。

    ユースケース:
        - ユーザー権限チェック（最も早い時点でAgent全体をスキップ可能）
        - レート制限（Invocation単位）
        - セッション状態の初期化

    戻り値:
        - Content: このContentがAgentの最終結果として返される（Agent実行スキップ）
        - None: Agent実行を継続
    """
    # セッション状態からユーザー情報を取得
    user_id = callback_context.state.get("user_id")
    user_tier = callback_context.state.get("user_tier", "basic")

    # 権限チェック
    if not user_id:
        return types.Content(
            role="model",
            parts=[types.Part(text="認証が必要です。ログインしてからご利用ください。")]
        )

    # 招待制機能の場合
    if not has_permission(user_id):
        return types.Content(
            role="model",
            parts=[types.Part(text="この機能へのアクセス権限がありません。")]
        )

    # 実行開始時刻を記録（after_agent_callbackで利用）
    import time
    callback_context.state["execution_start"] = time.time()

    return None  # Agent実行を継続
```

#### after_agent_callback

```python
def after_agent_callback(
    callback_context: CallbackContext,
    content: types.Content
) -> Optional[types.Content]:
    """
    Agent完了後に呼ばれる。修正したContentで出力を置換できる。

    ユースケース:
        - 最終出力の検証・フィルタリング
        - メトリクス記録
        - レスポンス形式の統一

    引数:
        content: Agentが生成した元のContent
    戻り値:
        - Content: このContentでAgentの出力を置換
        - None: 元のcontentをそのまま使用
    """
    import time

    # 実行時間を計測
    start_time = callback_context.state.get("execution_start", time.time())
    duration = time.time() - start_time

    # メトリクス記録
    agent_name = callback_context.agent_name
    invocation_id = callback_context.invocation_id
    print(f"[METRICS] Agent={agent_name}, Duration={duration:.2f}s, ID={invocation_id}")

    # センシティブデータの最終チェック
    if content.parts and content.parts[0].text:
        original_text = content.parts[0].text
        if contains_sensitive_data(original_text):
            return types.Content(
                role="model",
                parts=[types.Part(text="センシティブデータが検出されたため出力できません。")]
            )

    return None  # 元のcontentを使用
```

---

### LLM インタラクション Callbacks

#### before_model_callback

```python
from google.adk.models.lite_llm import LiteModel
from google.adk.agents.callback_context import CallbackContext

def before_model_callback(
    callback_context: CallbackContext,
    llm_request,
) -> Optional[types.LlmResponse]:
    """
    LLM API呼び出し前に呼ばれる。LlmResponseを返すとLLM呼び出しをスキップ。

    ユースケース:
        - 不適切な入力のブロック（APIコスト削減）
        - キャッシュチェック
        - プロンプトの修正・強化
        - トークン数の事前確認

    引数:
        llm_request: LLMに送信予定のリクエスト
    戻り値:
        - LlmResponse: LLM呼び出しをスキップしこのResponseを使用
        - None: LLM呼び出しを継続
    """
    # ブロックされたキーワードのチェック
    blocked_patterns = [
        r'\b(weapon|bomb|explosive)\b',
        r'\b(violence|harm|attack|murder)\b',
        r'\b(illegal|fraud|scam|hack)\b',
    ]

    if llm_request.contents:
        for content in llm_request.contents:
            if content.parts:
                for part in content.parts:
                    if part.text:
                        text_lower = part.text.lower()
                        for pattern in blocked_patterns:
                            if re.search(pattern, text_lower):
                                # セッション状態に違反を記録
                                callback_context.state["security_violation"] = {
                                    "type": "content_filter",
                                    "pattern": pattern,
                                }
                                # LLM呼び出しをスキップして安全な応答を返す
                                return types.LlmResponse(
                                    candidates=[
                                        types.Candidate(
                                            content=types.Content(
                                                role="model",
                                                parts=[types.Part(
                                                    text="そのリクエストにはお応えできません。別の質問をしてください。"
                                                )]
                                            )
                                        )
                                    ]
                                )

    # キャッシュチェック（オプション）
    cache_key = _hash_request(llm_request)
    if cached := get_from_cache(cache_key):
        return cached

    return None  # LLM呼び出しを継続
```

#### after_model_callback

```python
def after_model_callback(
    callback_context: CallbackContext,
    llm_response: types.LlmResponse,
) -> Optional[types.LlmResponse]:
    """
    LLMレスポンス受信後に呼ばれる。修正したResponseで置換できる。

    ユースケース:
        - PIIフィルタリング（LLM出力の後処理）
        - レスポンスの品質チェック
        - ログ記録・監査
        - トークン使用量の記録

    引数:
        llm_response: LLMから返された元のレスポンス
    戻り値:
        - LlmResponse: 修正したレスポンスで置換
        - None: 元のllm_responseをそのまま使用
    """
    import logging
    logger = logging.getLogger(__name__)

    if llm_response.content and llm_response.content.parts:
        for i, part in enumerate(llm_response.content.parts):
            if part.text:
                logger.info(f"[{callback_context.invocation_id}] LLM Text: {part.text[:100]}...")
            elif part.function_call:
                logger.info(f"[{callback_context.invocation_id}] Function call: {part.function_call.name}")

    # PIIフィルタリング
    if llm_response.content and llm_response.content.parts:
        original_text = llm_response.content.parts[0].text
        if original_text:
            filtered_text = redact_pii(original_text)
            if filtered_text != original_text:
                # PII検出をログに記録
                logger.warning(f"PII detected in LLM response, redacting...")
                callback_context.state["pii_detected"] = True

                return types.LlmResponse(
                    candidates=[
                        types.Candidate(
                            content=types.Content(
                                role="model",
                                parts=[types.Part(text=filtered_text)]
                            )
                        )
                    ]
                )

    return None
```

---

### Tool 実行 Callbacks

#### before_tool_callback

```python
from google.adk.tools.tool_context import ToolContext

def before_tool_callback(
    tool_context: ToolContext,
    tool,
    args: dict,
) -> Optional[dict]:
    """
    Tool実行前に呼ばれる。dictを返すとTool実行をスキップ。

    ユースケース:
        - 引数バリデーション（無効なTool実行を防止）
        - ロールベースアクセス制御（RBAC）
        - レート制限（Tool単位のクオータ強制）
        - 引数のサニタイズ

    引数:
        tool_context: ToolContextオブジェクト（セッション状態へのアクセス含む）
        tool: 実行予定のToolオブジェクト
        args: Toolに渡される引数
    戻り値:
        - Dict: Tool実行をスキップしこの結果を使用
        - None: Tool実行を継続
    """
    import logging
    logger = logging.getLogger(__name__)

    tool_name = getattr(tool, 'name', str(tool))
    user_role = tool_context.state.get("user_role", "guest")

    logger.info(f"[{tool_context.invocation_id}] Tool execution: {tool_name}, args: {args}")

    # ロールベースアクセス制御
    tool_permissions = {
        "send_email": ["admin", "authorized_user"],
        "delete_file": ["admin"],
        "read_data": ["guest", "user", "admin", "authorized_user"],
        "process_payment": ["authorized_user", "admin"],
    }

    allowed_roles = tool_permissions.get(tool_name, [])
    if allowed_roles and user_role not in allowed_roles:
        # アクセス違反をセッション状態に記録
        tool_context.state["access_violation"] = {
            "tool": tool_name,
            "user_role": user_role,
            "required_roles": allowed_roles,
        }
        return {
            "status": "access_denied",
            "message": f"ツール '{tool_name}' の実行には {allowed_roles} のロールが必要です。現在のロール: '{user_role}'",
        }

    # APIクオータ管理
    api_quota = tool_context.state.get("api_calls_remaining", 100)
    if api_quota <= 0:
        # エスカレーション（LoopAgentのループを終了させる場合など）
        tool_context.actions.escalate = True
        return {"error": "APIクオータを超過しました。しばらくしてから再試行してください。"}

    # クオータを消費
    tool_context.state["api_calls_remaining"] = api_quota - 1

    # 引数バリデーション例
    if tool_name == "process_order":
        quantity = args.get("quantity", 0)
        if not (1 <= quantity <= 100):
            return {
                "success": False,
                "error": f"数量は1から100の間である必要があります。指定値: {quantity}",
            }

    return None  # Tool実行を継続
```

#### after_tool_callback

```python
def after_tool_callback(
    tool_context: ToolContext,
    tool,
    tool_response,
) -> Optional[dict]:
    """
    Tool完了後に呼ばれる。修正した結果で置換できる。

    ユースケース:
        - ログ記録（完全な実行詳細をキャプチャ）
        - 結果のフィルタリング（内部データの除去）
        - 結果の変換・正規化
        - ツール使用統計の更新

    引数:
        tool_context: ToolContextオブジェクト
        tool: 実行されたToolオブジェクト
        tool_response: Toolが返した元の結果
    戻り値:
        - Dict: 修正した結果で置換
        - None: 元のtool_responseをそのまま使用
    """
    import logging
    logger = logging.getLogger(__name__)

    tool_name = getattr(tool, 'name', str(tool))

    # ツール使用統計の更新
    tool_usage = tool_context.state.get("tool_usage", {})
    tool_usage[tool_name] = tool_usage.get(tool_name, 0) + 1
    tool_context.state["tool_usage"] = tool_usage

    logger.info(f"[{tool_context.invocation_id}] Tool result: {tool_name} (total calls: {tool_usage[tool_name]})")

    if isinstance(tool_response, dict):
        logger.info(f"Response keys: {list(tool_response.keys())}")

        # 内部データのフィルタリング
        if "internal_data" in tool_response or "secret_token" in tool_response:
            filtered = {k: v for k, v in tool_response.items()
                       if k not in ("internal_data", "secret_token")}
            return filtered

    return None  # 元のtool_responseをそのまま使用
```

---

### Callback 選択基準テーブル

| 目的 | 最適Callback | 理由 |
|------|------------|------|
| ユーザー権限チェック | `before_agent` | 最も早い時点でAgent全体をスキップ可能 |
| 不適切入力ブロック | `before_model` | LLMに不適切内容を送信しない、APIコスト削減 |
| キャッシュ利用 | `before_model` | LLM呼び出し前にキャッシュヒット確認 |
| Tool引数バリデーション | `before_tool` | 無効なTool実行を防止 |
| ロールベースアクセス制御 | `before_tool` | Tool単位の権限管理 |
| API呼び出し追跡 | `before_model` / `after_model` | リクエスト/レスポンス全体にアクセス |
| PIIフィルタリング | `after_model` | LLM出力の後処理 |
| Tool結果ログ | `after_tool` | 完全な実行詳細をキャプチャ |
| レート制限 | `before_tool` | Tool単位のクオータ強制 |
| 最終出力検証 | `after_agent` | ユーザーに届く前の最終チェック |
| 実行時間計測 | `before_agent` + `after_agent` | 開始/終了時刻をセッション状態で共有 |

---

## CallbackContext と ToolContext

### CallbackContext（Agent/Model Callbacks用）

`CallbackContext`はAgent・Model Callbackに渡されるコンテキストオブジェクト。

```python
from google.adk.agents.callback_context import CallbackContext

def my_callback(callback_context: CallbackContext) -> Optional[types.Content]:
    # --- セッション状態アクセス ---
    # 読み取り（デフォルト値付き）
    user_tier = callback_context.state.get("user_tier", "basic")
    user_id = callback_context.state.get("user_id")

    # 書き込み
    callback_context.state["last_callback"] = "my_callback"
    callback_context.state["execution_count"] = callback_context.state.get("execution_count", 0) + 1

    # スコープ別の状態管理（プレフィックス規約を使うと整理しやすい）
    callback_context.state["user:preference"] = "value"      # ユーザーレベル
    callback_context.state["app:config"] = "setting"          # アプリレベル
    callback_context.state["temp:cache_key"] = "data"         # 一時データ

    # --- 呼び出し詳細 ---
    invocation_id = callback_context.invocation_id    # 一意の実行ID
    agent_name = callback_context.agent_name          # Agentの名前

    # --- アーティファクト保存 ---
    # (非同期コンテキストでのみ利用可能)
    # await callback_context.save_artifact("log.txt", log_part)

    # --- LLMリクエストへのアクセス（before_model_callbackのみ） ---
    # llm_request = callback_context.llm_request  # LLMに送信予定のリクエスト

    return None
```

### ToolContext（Tool Callbacks用）

`ToolContext`はTool CallbackとTool関数自体に渡されるコンテキストオブジェクト。

```python
from google.adk.tools.tool_context import ToolContext

def my_tool_callback(tool_context: ToolContext, tool, args: dict) -> Optional[dict]:
    # --- セッション状態アクセス（CallbackContextと同様） ---
    api_quota = tool_context.state.get("api_calls_remaining", 100)
    user_role = tool_context.state.get("user_role", "guest")

    # --- フロー制御 ---
    # escalate=True でLoopAgentのループを終了させる
    if api_quota <= 0:
        tool_context.actions.escalate = True
        return {"error": "クオータ超過"}

    # --- 呼び出し詳細 ---
    invocation_id = tool_context.invocation_id

    # --- 状態の更新 ---
    tool_context.state["api_calls_remaining"] = api_quota - 1

    return None
```

### 状態スコープのプレフィックス規約

| プレフィックス | スコープ | 例 |
|--------------|---------|-----|
| `user:` | ユーザーレベル（ユーザー固有の設定） | `user:preference` |
| `app:` | アプリレベル（アプリ全体の設定） | `app:config` |
| `temp:` | 一時データ（単一Invocation内） | `temp:cache_key` |
| プレフィックスなし | セッションスコープ（一般的なセッション状態） | `execution_count` |

---

## ガードレールパターン

### パターン1: 多層防御の実装

書籍が推奨する「Layered defense beats single filters」の原則に基づき、複数の防衛線を組み合わせる。

```python
import re
from typing import Optional, List
from google.adk.agents import Agent
from google.adk.agents.callback_context import CallbackContext
from google.adk.tools.tool_context import ToolContext
from google.genai import types

# 層1: 入力フィルタリング（before_model_callback）
BLOCKED_PATTERNS = [
    r'\b(weapon|bomb|explosive|gun)\b',
    r'\b(violence|harm|attack|kill|murder)\b',
    r'\b(illegal|fraud|scam|steal|hack)\b',
    r'\b(drug|narcotic|cocaine|heroin)\b',
]

def input_guard_callback(
    callback_context: CallbackContext,
    llm_request,
) -> Optional[types.LlmResponse]:
    """層1: LLMへの不適切な入力をブロック"""
    if not llm_request or not llm_request.contents:
        return None

    for content in llm_request.contents:
        if content.parts:
            for part in content.parts:
                if part.text:
                    text_lower = part.text.lower()
                    for pattern in BLOCKED_PATTERNS:
                        if re.search(pattern, text_lower):
                            callback_context.state["security_violation"] = {
                                "type": "input_filter",
                                "pattern": pattern,
                            }
                            return types.LlmResponse(
                                candidates=[types.Candidate(
                                    content=types.Content(
                                        role="model",
                                        parts=[types.Part(
                                            text="そのリクエストにはお応えできません。別の質問をお試しください。"
                                        )]
                                    )
                                )]
                            )
    return None

# 層2: Tool引数バリデーション（before_tool_callback）
def validate_tool_args_callback(
    tool_context: ToolContext,
    tool,
    args: dict,
) -> Optional[dict]:
    """層2: Tool実行前の引数バリデーションとアクセス制御"""
    tool_name = getattr(tool, 'name', str(tool))

    # 数値範囲チェック
    if tool_name == "process_order":
        quantity = args.get("quantity", 0)
        if not (1 <= quantity <= 100):
            return {
                "success": False,
                "error": f"数量は1〜100の範囲で指定してください（指定値: {quantity}）",
            }

    # SQLインジェクション防止（クエリツールの場合）
    if tool_name == "query_database":
        query = args.get("query", "")
        dangerous_keywords = ["DROP", "DELETE", "TRUNCATE", "ALTER"]
        if any(kw in query.upper() for kw in dangerous_keywords):
            return {
                "success": False,
                "error": "危険なSQL操作はサポートされていません",
            }

    # 金額上限チェック
    if tool_name == "process_payment":
        amount = args.get("amount", 0)
        if amount > 10000:
            return {
                "error": f"1回あたりの決済上限（10,000円）を超えています（指定額: {amount}円）"
            }

    return None

# 層3: 出力フィルタリング（after_agent_callback）
SENSITIVE_OUTPUT_PATTERNS = [
    r'\b\d{3}-\d{2}-\d{4}\b',              # SSN (US)
    r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b',  # クレジットカード番号
    r'(?:password|passwd|secret|api_key)\s*[:=]\s*\S+',  # パスワード/秘密情報
]

def output_filter_callback(
    callback_context: CallbackContext,
    content: types.Content,
) -> Optional[types.Content]:
    """層3: 最終出力に含まれるセンシティブデータを検出"""
    if not content.parts:
        return None

    for part in content.parts:
        if part.text:
            for pattern in SENSITIVE_OUTPUT_PATTERNS:
                if re.search(pattern, part.text, re.IGNORECASE):
                    return types.Content(
                        role="model",
                        parts=[types.Part(
                            text="センシティブデータが検出されたため、出力を表示できません。"
                        )]
                    )
    return None

# 多層防御Agentの構成
secure_agent = Agent(
    name="secure_agent",
    model="gemini-2.0-flash",
    instruction="セキュアなアシスタント",
    before_model_callback=input_guard_callback,    # 層1
    before_tool_callback=validate_tool_args_callback,  # 層2
    after_agent_callback=output_filter_callback,   # 層3
)
```

### パターン2: LLMベースのセマンティックフィルタリング

正規表現では難しい「意味的に有害な入力」には、軽量なLLMを使ったフィルタリングが効果的（書籍引用: 約120msのオーバーヘッドで98%の有害コンテンツをブロック）。

```python
import google.generativeai as genai

class LlmContentFilter:
    """Gemini Flash Liteを使ったセマンティックフィルタリング"""

    def __init__(self, threshold: str = "unsafe"):
        self.threshold = threshold
        self.filter_model = genai.GenerativeModel("gemini-2.0-flash-lite")

    def is_safe(self, text: str) -> bool:
        """テキストが安全かどうかを判定"""
        response = self.filter_model.generate_content(
            f"""あなたは安全性を評価するフィルターです。
            以下のテキストが「safe」か「unsafe」かを1単語で答えてください。
            判断基準: 暴力、違法行為、個人情報漏洩リスク、悪意ある使用があれば「unsafe」。

            テキスト: {text}

            回答（safe/unsafe のみ）:""",
            generation_config=genai.GenerationConfig(
                max_output_tokens=10,
                temperature=0.0,
            )
        )
        result = response.text.strip().lower()
        return "unsafe" not in result

    def create_callback(self):
        """LLMフィルタリングのbefore_model_callbackを返す"""
        filter_instance = self

        def llm_filter_callback(callback_context, llm_request):
            if llm_request.contents and llm_request.contents[-1].parts:
                user_text = llm_request.contents[-1].parts[0].text or ""
                if not filter_instance.is_safe(user_text):
                    return types.LlmResponse(
                        candidates=[types.Candidate(
                            content=types.Content(
                                role="model",
                                parts=[types.Part(
                                    text="申し訳ございませんが、そのリクエストにはお応えできません。"
                                )]
                            )
                        )]
                    )
            return None

        return llm_filter_callback


# 使用例
llm_filter = LlmContentFilter(threshold="unsafe")

agent = Agent(
    name="semantically_safe_agent",
    model="gemini-2.0-flash",
    instruction="ユーザーの質問に親切に答えるアシスタント",
    before_model_callback=llm_filter.create_callback(),
)
```

### パターン3: 動的安全指示注入

```python
from google.adk.agents import Agent

class DynamicSafetyInstruction:
    """ユーザー属性に応じて安全指示を動的に注入"""

    BASE_INSTRUCTION = "ユーザーの質問に丁寧に答えてください。"

    SAFETY_RULES_BY_TIER = {
        "basic": """
        安全ガイドライン（基本ユーザー向け）:
        - 個人情報（メール、電話番号等）を要求しない
        - 医療・法律・金融の専門的アドバイスは提供しない（「専門家にご相談ください」と案内）
        - 不確かな情報は「確認が取れていません」と明示
        """,
        "premium": """
        安全ガイドライン（プレミアムユーザー向け）:
        - 個人情報の取り扱いには最大限注意
        - 専門的なアドバイスは「参考情報」として提供（免責事項を添える）
        - 機密情報を含むクエリには追加確認を求める
        """,
        "admin": """
        管理者向けガイドライン:
        - すべての操作をログに記録
        - 破壊的操作（削除・変更）は確認後に実行
        """,
    }

    def get_instruction(self, callback_context) -> str:
        user_tier = callback_context.state.get("user_tier", "basic")
        safety_rules = self.SAFETY_RULES_BY_TIER.get(user_tier, self.SAFETY_RULES_BY_TIER["basic"])
        return self.BASE_INSTRUCTION + safety_rules


# InstructionProviderとして登録（dynamic instructionパターン）
safety_provider = DynamicSafetyInstruction()

def get_dynamic_instruction(callback_context) -> str:
    return safety_provider.get_instruction(callback_context)

# Agentの instruction は文字列ではなく Callable でも渡せる
agent = Agent(
    name="dynamic_safe_agent",
    model="gemini-2.0-flash",
    instruction=get_dynamic_instruction,  # Callableを渡す
)
```

---

## PIIフィルタリング

### PIIパターン定義

```python
import re
from typing import Dict
import logging

logger = logging.getLogger(__name__)

PII_PATTERNS: Dict[str, re.Pattern] = {
    "email": re.compile(
        r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
    ),
    "phone_jp": re.compile(
        r'\b0\d{1,4}[-\s]?\d{1,4}[-\s]?\d{4}\b'  # 日本の電話番号
    ),
    "phone_us": re.compile(
        r'\b(?:\+?1[-.]?)?\(?\d{3}\)?[-.]?\d{3}[-.]?\d{4}\b'
    ),
    "ssn": re.compile(
        r'\b\d{3}-\d{2}-\d{4}\b'
    ),
    "credit_card": re.compile(
        r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b'
    ),
    "ip_address": re.compile(
        r'\b(?:\d{1,3}\.){3}\d{1,3}\b'
    ),
    "my_number_jp": re.compile(
        r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'  # 日本のマイナンバー
    ),
}

MASKING_TEMPLATES: Dict[str, str] = {
    "email": "[EMAIL-REDACTED]",
    "phone_jp": "[PHONE-REDACTED]",
    "phone_us": "[PHONE-REDACTED]",
    "ssn": "[SSN-REDACTED]",
    "credit_card": "[CC-REDACTED]",
    "ip_address": "[IP-REDACTED]",
    "my_number_jp": "[MY-NUMBER-REDACTED]",
}


def redact_pii(text: str, audit_mode: bool = False) -> tuple[str, list[str]]:
    """
    PIIを検出してマスキングする。

    Args:
        text: 処理対象のテキスト
        audit_mode: Trueの場合、検出のみ行い実際のマスキングも行う
                    （本番では常にマスキングを実施）
    Returns:
        (redacted_text, detected_types): マスキング後テキストと検出されたPIIタイプのリスト
    """
    redacted = text
    detected_types: list[str] = []

    for pii_type, pattern in PII_PATTERNS.items():
        matches = list(pattern.finditer(redacted))
        if matches:
            detected_types.append(pii_type)
            if audit_mode:
                logger.warning(f"[AUDIT] PII detected: type={pii_type}, count={len(matches)}")
            mask = MASKING_TEMPLATES.get(pii_type, "[REDACTED]")
            redacted = pattern.sub(mask, redacted)

    return redacted, detected_types
```

### after_model_callback での PII フィルタリング実装

```python
from google.adk.agents.callback_context import CallbackContext

def pii_filter_callback(
    callback_context: CallbackContext,
    llm_response: types.LlmResponse,
) -> Optional[types.LlmResponse]:
    """LLM出力からPIIを自動検出・マスキングするCallback"""

    if not llm_response.content or not llm_response.content.parts:
        return None

    # テキストパーツのみ処理
    original_text = ""
    for part in llm_response.content.parts:
        if part.text:
            original_text = part.text
            break

    if not original_text:
        return None

    filtered_text, detected_types = redact_pii(original_text, audit_mode=False)

    if filtered_text != original_text:
        # セッション状態にPII検出を記録
        pii_log = callback_context.state.get("pii_detections", [])
        pii_log.append({
            "invocation_id": callback_context.invocation_id,
            "detected_types": detected_types,
        })
        callback_context.state["pii_detections"] = pii_log

        logger.warning(
            f"[PII] Detected and redacted: types={detected_types}, "
            f"invocation_id={callback_context.invocation_id}"
        )

        return types.LlmResponse(
            candidates=[types.Candidate(
                content=types.Content(
                    role="model",
                    parts=[types.Part(text=filtered_text)]
                )
            )]
        )

    return None  # PIIなし、元のレスポンスを使用


# PII安全なAgentの構成
pii_safe_agent = Agent(
    name="pii_safe_agent",
    model="gemini-2.0-flash",
    instruction="ユーザー情報を扱うアシスタント。個人情報の保護を最優先にします。",
    after_model_callback=pii_filter_callback,
)
```

### 監査モード（段階的デプロイ）

```python
class AuditModeFilter:
    """
    段階的デプロイのための監査モードPIIフィルター。
    audit_only=True: ログのみ（フィルタリングしない） → パターンチューニング
    audit_only=False: 実際にフィルタリング → 本番運用
    """

    def __init__(self, audit_only: bool = True):
        self.audit_only = audit_only

    def create_callback(self):
        audit_mode = self.audit_only

        def audit_pii_callback(callback_context, llm_response):
            if not llm_response.content or not llm_response.content.parts:
                return None

            text = ""
            for part in llm_response.content.parts:
                if part.text:
                    text = part.text
                    break

            if not text:
                return None

            filtered, detected = redact_pii(text, audit_mode=True)

            if filtered != text:
                if audit_mode:
                    # 監査モード: ログのみ、実際のレスポンスは変更しない
                    logger.warning(
                        f"[AUDIT-ONLY] PII would be redacted: {detected}. "
                        "Set audit_only=False to enable actual redaction."
                    )
                    return None  # 元のレスポンスを返す
                else:
                    # 本番モード: 実際にフィルタリング
                    return types.LlmResponse(
                        candidates=[types.Candidate(
                            content=types.Content(
                                role="model",
                                parts=[types.Part(text=filtered)]
                            )
                        )]
                    )

            return None

        return audit_pii_callback


# 段階的デプロイ: まず監査モードで様子を見る
audit_filter = AuditModeFilter(audit_only=True)   # ステージング
# audit_filter = AuditModeFilter(audit_only=False)  # 本番

agent = Agent(
    name="audited_agent",
    model="gemini-2.0-flash",
    instruction="アシスタント",
    after_model_callback=audit_filter.create_callback(),
)
```

### PIIフィルタリングのテスト

```python
def test_pii_redaction():
    """PIIフィルタリングの単体テスト"""
    test_cases = [
        (
            "私のメールはjohn.doe@example.com です",
            "[EMAIL-REDACTED]",
            ["email"]
        ),
        (
            "電話番号は090-1234-5678です",
            "[PHONE-REDACTED]",
            ["phone_jp"]
        ),
        (
            "SSNは123-45-6789です",
            "[SSN-REDACTED]",
            ["ssn"]
        ),
        (
            "カード番号: 1234 5678 9012 3456",
            "[CC-REDACTED]",
            ["credit_card"]
        ),
        (
            "普通のテキスト",
            "普通のテキスト",
            []
        ),
    ]

    all_passed = True
    for original, expected_mask, expected_types in test_cases:
        filtered, detected = redact_pii(original)
        passed = expected_mask in filtered and set(detected) == set(expected_types)
        status = "PASS" if passed else "FAIL"
        print(f"[{status}] Input: {original!r}")
        if not passed:
            print(f"  Expected mask: {expected_mask!r}, Got: {filtered!r}")
            print(f"  Expected types: {expected_types}, Got: {detected}")
            all_passed = False

    print(f"\n{'すべてのテストが成功' if all_passed else 'テストが失敗'}")
    return all_passed

# 実行
test_pii_redaction()
```

---

## Plugin System

### Plugin概要と設計思想

**Plugin**は、ADK Runnerにグローバルスコープで適用される拡張ポイント。
`BasePlugin`を継承することで、セキュリティガードレール、監視、ログ、監査などの
**クロスカッティング関心事**をアプリケーション全体に統一的に適用できる。

書籍が強調する利点:
- **一貫性**: 全Agentに同じガードレールを自動適用
- **保守性**: セキュリティルールを一箇所で管理
- **再利用**: 複数プロジェクトで共通Pluginを使用可能
- **チーム自律性**: セキュリティPluginを独立してデプロイ可能

### 6つのライフサイクルフック

Pluginは以下の6つのポイントでADK実行フローに介入できる。

```
on_user_message → before_run → [Agent実行] → after_run
                                   │
                              on_event（各Eventで）
                                   │
                     on_model_error（LLMエラー時）
                     on_tool_error（Toolエラー時）
```

#### on_user_message

```python
from google.adk.plugins import BasePlugin
from google.genai import types
from typing import Optional

class InputValidationPlugin(BasePlugin):
    """ユーザー入力の検証Plugin"""

    BLOCKED_PATTERNS = ["暴力的", "違法", "不適切"]

    async def on_user_message(
        self,
        context,
        message: types.Content,
    ) -> Optional[types.Content]:
        """
        ユーザーメッセージをAgentが受信する前に処理。

        タイミング: ユーザーメッセージ受信直後、Agent実行前
        用途: 入力バリデーション、PII検出、不適切コンテンツブロック

        Returns:
            - Content: ブロック応答（Agent実行をスキップ）
            - None: 正常な処理を継続
        """
        if message.parts:
            text = message.parts[0].text or ""
            text_lower = text.lower()

            for pattern in self.BLOCKED_PATTERNS:
                if pattern in text_lower:
                    return types.Content(
                        role="model",
                        parts=[types.Part(
                            text=f"不適切な内容が検出されました。ポリシーに違反しています。"
                        )]
                    )

        return None  # 通常処理を継続
```

#### before_run / after_run

```python
class AuthAndMetricsPlugin(BasePlugin):
    """認証チェックとメトリクス収集を統合したPlugin"""

    async def before_run(self, context) -> None:
        """
        Agent実行の直前に呼ばれる。

        タイミング: Agent実行直前
        用途: 認証チェック、コンテキスト注入、実行前ログ

        Raises:
            AuthenticationError: 認証が必要な場合（Agent実行を中断）
        """
        user_id = context.metadata.get("user_id")
        if not user_id:
            raise ValueError("ユーザーIDが必要です。認証してください。")

        # 認証チェック
        if not self._is_authenticated(user_id):
            raise PermissionError("認証されていません。ログインしてください。")

        # 実行ログ
        print(f"[AUTH] User {user_id} started invocation {context.invocation_id}")

    async def after_run(self, context, result: types.Content) -> None:
        """
        Agent実行完了後に呼ばれる。

        タイミング: Agent実行完了後
        用途: メトリクス収集、結果ログ、監査記録
        """
        user_id = context.metadata.get("user_id", "unknown")
        agent_name = context.metadata.get("agent_name", "unknown")

        # レスポンス長を記録
        response_length = 0
        if result.parts:
            for part in result.parts:
                if part.text:
                    response_length += len(part.text)

        # メトリクス送信
        print(f"[METRICS] user={user_id}, agent={agent_name}, "
              f"response_length={response_length}, "
              f"invocation_id={context.invocation_id}")

    def _is_authenticated(self, user_id: str) -> bool:
        # 実際の認証ロジック（DBチェック等）
        return user_id not in ("", "anonymous")
```

#### on_event

```python
from google.adk.events import Event

class EventAuditPlugin(BasePlugin):
    """イベント監査Plugin"""

    async def on_event(
        self,
        context,
        event: Event,
    ) -> Optional[Event]:
        """
        Eventが生成された時に呼ばれる。

        タイミング: Eventが生成されるたびに（ストリーミング各チャンクを含む）
        用途: イベントフィルタリング、監査ログ、リアルタイム監視

        Returns:
            - Event: 修正したEvent（置換）
            - None: 元のEventをそのまま使用
        """
        # 全イベントを監査ログに記録
        self._log_event({
            "event_id": getattr(event, 'id', 'unknown'),
            "author": getattr(event, 'author', 'unknown'),
            "invocation_id": getattr(event, 'invocation_id', 'unknown'),
        })

        # Function Call イベントの場合、機密引数をサニタイズ
        if hasattr(event, 'get_function_calls') and event.get_function_calls():
            for fc in event.get_function_calls():
                if fc.name == "sensitive_api":
                    # 機密情報をマスク（Eventを修正）
                    if fc.args and "api_key" in fc.args:
                        fc.args["api_key"] = "[REDACTED]"
            return event  # 修正したEventを返す

        return None  # 元のEventを使用

    def _log_event(self, data: dict) -> None:
        # 実際のシステムでは監査DBやログサービスに送信
        print(f"[AUDIT-EVENT] {data}")
```

#### on_model_error / on_tool_error

```python
import asyncio
from google.genai import errors

class ErrorHandlingPlugin(BasePlugin):
    """エラーハンドリングとフォールバックPlugin"""

    async def on_model_error(
        self,
        context,
        error: Exception,
    ) -> Optional[types.Content]:
        """
        LLMモデル呼び出しでエラーが発生した時。

        タイミング: LLM API呼び出しでエラー発生時
        用途: フォールバック処理、リトライ、エラー通知

        Returns:
            - Content: フォールバック応答（エラーを回復）
            - None: エラーを再度発生させる
        """
        error_str = str(error).lower()

        # APIクオータ超過のフォールバック
        if "quota" in error_str or "rate limit" in error_str:
            self._send_alert(f"Quota exceeded: {error}")
            return types.Content(
                role="model",
                parts=[types.Part(
                    text="現在アクセスが集中しています。しばらくしてから再度お試しください。"
                )]
            )

        # タイムアウトエラーのフォールバック
        if "timeout" in error_str or "deadline" in error_str:
            return types.Content(
                role="model",
                parts=[types.Part(
                    text="処理に時間がかかりすぎました。もう一度お試しください。"
                )]
            )

        # その他のエラーはログのみ記録して再発生
        self._log_error(error, context.invocation_id)
        return None  # エラーを再発生

    async def on_tool_error(
        self,
        context,
        tool_name: str,
        error: Exception,
        retry_count: int = 0,
    ) -> Optional[dict]:
        """
        Tool実行でエラーが発生した時。

        タイミング: Tool実行でエラー発生時
        用途: Tool固有のエラーハンドリング、指数バックオフリトライ、通知

        Returns:
            - dict: リトライ結果またはエラーメッセージ
            - None: エラーを再発生させる
        """
        MAX_RETRIES = 3

        # 一時的なネットワークエラーはリトライ
        if isinstance(error, (TimeoutError, ConnectionError)) and retry_count < MAX_RETRIES:
            wait_time = 2 ** retry_count  # 指数バックオフ: 1s, 2s, 4s
            print(f"[RETRY] Tool '{tool_name}' failed (attempt {retry_count+1}/{MAX_RETRIES}), "
                  f"retrying in {wait_time}s...")
            await asyncio.sleep(wait_time)

            return {
                "status": "retrying",
                "message": f"リトライ中 ({retry_count + 1}/{MAX_RETRIES})",
                "retry_count": retry_count + 1,
            }

        # リトライ上限到達 / 非一時的エラー
        self._notify_admin(tool_name, error)
        return {
            "error": f"ツール '{tool_name}' の実行に失敗しました: {str(error)}",
            "recoverable": False,
        }

    def _send_alert(self, message: str) -> None:
        print(f"[ALERT] {message}")  # 実際はSlack/PagerDuty等に送信

    def _log_error(self, error: Exception, invocation_id: str) -> None:
        print(f"[ERROR] Invocation {invocation_id}: {error}")

    def _notify_admin(self, tool_name: str, error: Exception) -> None:
        print(f"[ADMIN-NOTIFY] Tool '{tool_name}' failed: {error}")
```

### Pluginの作成と登録

```python
from google.adk import Runner
from google.adk.agents import Agent
from google.adk.plugins import BasePlugin

class SecurityPlugin(BasePlugin):
    """セキュリティガードレールを統合した完全なPlugin"""

    def __init__(self, blocked_patterns: list[str] | None = None):
        super().__init__()
        self.blocked_patterns = blocked_patterns or ["暴力的", "違法", "不適切"]

    async def on_user_message(self, context, message):
        """入力バリデーション"""
        if message.parts and message.parts[0].text:
            text = message.parts[0].text.lower()
            if any(p in text for p in self.blocked_patterns):
                return types.Content(
                    role="model",
                    parts=[types.Part(text="不適切な内容が検出されました。")]
                )
        return None

    async def before_run(self, context):
        """認証チェック"""
        if not context.metadata.get("user_id"):
            raise PermissionError("認証が必要です")

    async def after_run(self, context, result):
        """メトリクス収集（例外を抑制して堅牢に）"""
        try:
            self._log_metrics(context, result)
        except Exception as e:
            print(f"[WARN] Metrics logging failed: {e}")

    async def on_event(self, context, event):
        """監査ログ（例外を抑制して堅牢に）"""
        try:
            self._audit_log(event)
        except Exception as e:
            print(f"[WARN] Audit log failed: {e}")
        return None

    async def on_model_error(self, context, error):
        """モデルエラーのフォールバック"""
        if "quota" in str(error).lower():
            return types.Content(
                role="model",
                parts=[types.Part(text="しばらくしてから再度お試しください。")]
            )
        return None

    async def on_tool_error(self, context, tool_name, error, retry_count=0):
        """Toolエラーの通知"""
        print(f"[TOOL-ERROR] Tool='{tool_name}', Error={error}")
        return None

    def _log_metrics(self, context, result):
        pass  # 実際のメトリクス送信ロジック

    def _audit_log(self, event):
        pass  # 実際の監査ログロジック


class MonitoringPlugin(BasePlugin):
    """モニタリング専用Plugin"""

    async def before_run(self, context):
        import time
        context.metadata["start_time"] = time.time()

    async def after_run(self, context, result):
        import time
        start = context.metadata.get("start_time", time.time())
        duration = time.time() - start
        print(f"[MONITOR] Duration: {duration:.2f}s, invocation_id: {context.invocation_id}")


# Agentの定義
agent = Agent(
    name="production_agent",
    model="gemini-2.0-flash",
    instruction="ユーザーの質問に親切に答えるアシスタント",
)

# Pluginの登録（リスト順に実行される）
runner = Runner(
    agent=agent,
    plugins=[
        SecurityPlugin(blocked_patterns=["暴力的", "違法", "詐欺"]),  # 最初: セキュリティ優先
        MonitoringPlugin(),   # 後: 全処理を観測
    ]
)

# 実行
response = runner.run("こんにちは！")
```

**Pluginリストの順序ルール**:
- セキュリティPluginは最初に配置（早期ブロックのため）
- 監視・ログPluginは最後に配置（全処理を観測するため）

---

## Callbacks vs Plugins 判断基準

### 機能比較テーブル

| 観点 | Callback | Plugin |
|------|---------|--------|
| **スコープ** | 特定のAgent（ローカル） | Runner全体（グローバル） |
| **設定場所** | Agent定義時（`before_model_callback`等） | Runner初期化時（`plugins=[...]`） |
| **影響範囲** | 設定されたAgent内のみ有効 | すべてのAgentに適用 |
| **ADK公式推奨** | Agent固有のカスタマイズ・前後処理 | アプリケーション全体のガードレール・横断的関心事 |
| **実装難易度** | 低（関数を渡すだけ） | 中（クラスを継承） |
| **再利用性** | 低（Agent定義に紐付く） | 高（複数プロジェクトで共有可能） |

### ユースケース別判断テーブル

| ユースケース | 最適な選択 | 理由 |
|------------|----------|------|
| 不適切入力のブロック（**全Agent共通**） | Plugin | 全Agentに統一的なガードレールを適用 |
| PII検出とフィルタリング（**全Agent共通**） | Plugin | セキュリティポリシーの一元管理 |
| API呼び出しメトリクスの収集（**全Agent**） | Plugin | アプリケーション全体のオブザーバビリティ |
| モデルエラー時のフォールバック（**全Agent**） | Plugin | 統一されたエラーハンドリング |
| **特定Agentのみ**の動的instruction注入 | Callback | Agent固有のコンテキスト依存ロジック |
| **特定Agentのみ**のTool引数カスタマイズ | Callback | Agent内部の振る舞い調整 |
| **特定Agentのみ**のキャッシュ実装 | Callback | Agent固有のキャッシュ戦略 |
| レート制限（**全Tool共通**） | Plugin | グローバルなクオータ管理 |
| 権限チェック（**ユーザーの最初の入口**） | Plugin（`on_user_message`） | 最も早い時点でブロック可能 |
| Agent実行統計（**特定Agentのみ**） | Callback（`after_agent`） | そのAgentに限定した統計 |

### 判断フローチャート

```
新しいガードレール / 横断的関心事を実装したい
          │
          ▼
    複数のAgentに適用する？
         ├── Yes → Plugin を使用
         │           └── BasePlugin を継承
         │               適切なフックを実装
         │               Runner の plugins=[] に登録
         │
         └── No（特定Agentのみ）
              │
              ▼
         実装したい処理の種類は？
              ├── Agent全体の入出力 → before/after_agent_callback
              ├── LLM呼び出し前後  → before/after_model_callback
              └── Tool実行前後     → before/after_tool_callback
```

### 実装パターン比較

```python
# --- 全Agent共通の入力バリデーション（Plugin推奨） ---

class InputValidationPlugin(BasePlugin):
    async def on_user_message(self, context, message):
        if self._is_invalid(message):
            return self._block_response()
        return None

runner = Runner(
    agent=agent,
    plugins=[InputValidationPlugin()]
)

# --- 特定Agentのみのキャッシュ（Callback推奨） ---

def cache_callback(callback_context, llm_request):
    cache_key = hash(str(llm_request.contents))
    if cached := cache.get(cache_key):
        return cached
    return None

specialized_agent = Agent(
    name="cached_agent",
    model="gemini-2.0-flash",
    instruction="キャッシュ付きアシスタント",
    before_model_callback=cache_callback,  # このAgentのみに適用
)
```

---

## SSEストリーミング

### RunConfig の設定

```python
from google.adk.runners import Runner
from google.adk.agents import Agent, RunConfig
from google.adk.agents.run_config import StreamingMode

# ストリーミングモードを有効化
run_config = RunConfig(streaming_mode=StreamingMode.SSE)

# 同期ストリーミング実行
for event in runner.run(
    user_id="user_1",
    session_id="session_1",
    query="東京の天気について詳しく教えてください",
    run_config=run_config,
):
    if event.content and event.content.parts:
        chunk = event.content.parts[0].text
        if chunk:
            print(chunk, end="", flush=True)
```

### ストリーミングイベントの処理

```python
from google.adk.agents import Agent, RunConfig
from google.adk.runners import Runner
from google.adk.agents.run_config import StreamingMode

def stream_with_aggregation(
    runner: Runner,
    query: str,
    user_id: str = "user_1",
    session_id: str = "session_1",
) -> str:
    """チャンクを集約しながらストリーミング表示"""
    run_config = RunConfig(streaming_mode=StreamingMode.SSE)

    full_response = ""
    for event in runner.run(
        user_id=user_id,
        session_id=session_id,
        query=query,
        run_config=run_config,
    ):
        if event.content and event.content.parts:
            for part in event.content.parts:
                if part.text:
                    full_response += part.text
                    print(part.text, end="", flush=True)

    print()  # 最後に改行
    return full_response
```

### FastAPI SSEエンドポイント

```python
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
import json
import asyncio
from google.adk.agents import Agent, RunConfig
from google.adk.runners import InMemoryRunner
from google.adk.agents.run_config import StreamingMode

app = FastAPI()


async def generate_sse_stream(
    runner: InMemoryRunner,
    query: str,
    user_id: str,
    session_id: str,
):
    """
    非同期SSEストリームジェネレーター。

    ADKのrun_asyncを使い、チャンクをSSE形式で配信する。
    エラーハンドリングと完了マーカーを含む。
    """
    run_config = RunConfig(streaming_mode=StreamingMode.SSE)

    try:
        async for event in runner.run_async(
            user_id=user_id,
            session_id=session_id,
            query=query,
            run_config=run_config,
        ):
            if event.content and event.content.parts:
                for part in event.content.parts:
                    if part.text:
                        # SSE形式: "data: <JSON>\n\n"
                        data = json.dumps({"text": part.text, "done": False})
                        yield f"data: {data}\n\n"
                        await asyncio.sleep(0)  # イベントループに制御を返す

        # ストリーム完了マーカー
        yield f"data: {json.dumps({'text': '', 'done': True})}\n\n"

    except asyncio.CancelledError:
        # クライアントが切断した場合
        yield f"data: {json.dumps({'error': 'Stream cancelled', 'done': True})}\n\n"

    except Exception as e:
        error_data = json.dumps({"error": str(e), "done": True})
        yield f"data: {error_data}\n\n"


@app.post("/api/chat/stream")
async def stream_chat(request: Request):
    """SSEストリーミングエンドポイント"""
    body = await request.json()
    query = body.get("query", "")
    user_id = body.get("user_id", "default_user")
    session_id = body.get("session_id", "default_session")

    # Runnerの初期化（実際のアプリでは起動時に初期化してDI）
    runner = get_runner()  # アプリケーションのDIコンテナから取得

    return StreamingResponse(
        generate_sse_stream(runner, query, user_id, session_id),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Nginx バッファリング無効化
        }
    )
```

### JavaScript EventSource フロントエンド

```javascript
class ADKStreamClient {
    constructor(endpoint) {
        this.endpoint = endpoint;
        this.eventSource = null;
    }

    /**
     * SSEストリームを開始する
     * @param {string} query - ユーザーの質問
     * @param {function} onChunk - チャンク受信時のコールバック
     * @param {function} onComplete - 完了時のコールバック
     * @param {function} onError - エラー時のコールバック
     */
    async stream(query, { onChunk, onComplete, onError } = {}) {
        // POSTリクエストでSSE接続（fetchを使用）
        const response = await fetch(this.endpoint, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ query }),
        });

        if (!response.ok) {
            onError?.(`HTTP error: ${response.status}`);
            return;
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();

        try {
            while (true) {
                const { value, done } = await reader.read();
                if (done) break;

                const chunk = decoder.decode(value);
                const lines = chunk.split("\n");

                for (const line of lines) {
                    if (line.startsWith("data: ")) {
                        const jsonStr = line.slice(6);
                        try {
                            const data = JSON.parse(jsonStr);
                            if (data.done) {
                                onComplete?.();
                                return;
                            }
                            if (data.error) {
                                onError?.(data.error);
                                return;
                            }
                            onChunk?.(data.text);
                        } catch (parseError) {
                            console.error("JSON parse error:", parseError);
                        }
                    }
                }
            }
        } finally {
            reader.cancel();
        }
    }
}

// 使用例
const client = new ADKStreamClient("/api/chat/stream");
const responseDiv = document.getElementById("response");

document.getElementById("submit").addEventListener("click", async () => {
    const query = document.getElementById("query").value;
    responseDiv.textContent = "";

    await client.stream(query, {
        onChunk: (text) => {
            responseDiv.textContent += text;
        },
        onComplete: () => {
            console.log("Stream completed");
        },
        onError: (error) => {
            console.error("Stream error:", error);
            responseDiv.textContent += `\n[エラー: ${error}]`;
        },
    });
});
```

### エラーハンドリングとリカバリ

```python
import asyncio
from datetime import datetime
from typing import AsyncGenerator

async def resilient_stream(
    runner,
    query: str,
    user_id: str,
    session_id: str,
    timeout: int = 30,
    max_retries: int = 3,
) -> AsyncGenerator[str, None]:
    """
    タイムアウト・リトライ・指数バックオフ付きのストリーミング。

    書籍推奨のパターン:
    - チャンクサイズを小さく保つ（512-1024バイト）
    - バッファリングを最小化
    - 指数バックオフでリトライ
    """
    run_config = RunConfig(streaming_mode=StreamingMode.SSE)
    retry_count = 0

    while retry_count <= max_retries:
        try:
            async with asyncio.timeout(timeout):
                async for event in runner.run_async(
                    user_id=user_id,
                    session_id=session_id,
                    query=query,
                    run_config=run_config,
                ):
                    if event.content and event.content.parts:
                        for part in event.content.parts:
                            if part.text:
                                yield part.text

            return  # 成功

        except asyncio.TimeoutError:
            retry_count += 1
            if retry_count > max_retries:
                yield f"\n[タイムアウト: {timeout}秒を超えました]"
                return
            wait = 2 ** retry_count
            yield f"\n[タイムアウト。{wait}秒後にリトライ... ({retry_count}/{max_retries})]"
            await asyncio.sleep(wait)

        except Exception as e:
            retry_count += 1
            if retry_count > max_retries:
                yield f"\n[エラー: {str(e)}]"
                return
            wait = 2 ** retry_count
            yield f"\n[エラー発生。{wait}秒後にリトライ... ({retry_count}/{max_retries})]"
            await asyncio.sleep(wait)
```

### セッションベースリカバリ

```python
import uuid
from dataclasses import dataclass, field

@dataclass
class StreamSession:
    """中断したストリームの再開をサポートするセッション管理クラス"""
    session_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    query: str = ""
    chunks: list[str] = field(default_factory=list)
    completed: bool = False

    async def stream(self, runner, user_id: str, from_chunk: int = 0):
        """
        ストリームを（必要であれば再開して）取得する。

        Args:
            runner: ADK Runnerインスタンス
            user_id: ユーザーID
            from_chunk: 再開するチャンクインデックス（0=最初から）
        """
        run_config = RunConfig(streaming_mode=StreamingMode.SSE)

        # 既取得済みのチャンクを先に返す
        for chunk in self.chunks[from_chunk:]:
            yield chunk

        # 未完了の場合は続きを取得
        if not self.completed:
            async for event in runner.run_async(
                user_id=user_id,
                session_id=self.session_id,
                query=self.query,
                run_config=run_config,
            ):
                if event.content and event.content.parts:
                    for part in event.content.parts:
                        if part.text:
                            self.chunks.append(part.text)
                            yield part.text

            self.completed = True


# FastAPIでのセッション管理
stream_sessions: dict[str, StreamSession] = {}

@app.post("/api/stream/start")
async def start_stream(body: dict):
    session = StreamSession(query=body["query"])
    stream_sessions[session.session_id] = session

    return StreamingResponse(
        session.stream(runner, body["user_id"]),
        media_type="text/event-stream",
        headers={"X-Session-ID": session.session_id},
    )

@app.post("/api/stream/resume/{session_id}")
async def resume_stream(session_id: str, body: dict):
    session = stream_sessions.get(session_id)
    if not session:
        return {"error": "セッションが見つかりません"}

    from_chunk = body.get("from_chunk", 0)
    return StreamingResponse(
        session.stream(runner, body["user_id"], from_chunk=from_chunk),
        media_type="text/event-stream",
    )
```

---

## Live API 音声処理

### Live APIの概要

Live APIは、Gemini 2.0以降のモデルを使ったリアルタイム双方向音声処理を可能にする。
SSEストリーミングとは異なり、WebSocket相当の継続的な接続を維持する。

**重要な制約（書籍より）**: Live APIは**単一モダリティのみ**サポート。
テキストと音声を同時に有効化することはできない。

```python
# ❌ 不正: テキストと音声の混在
agent = Agent(
    model="gemini-2.0-flash-live-preview-04-09",
    response_modalities=["text", "audio"]  # エラーになる
)

# ✅ 正: 音声のみ
audio_agent = Agent(
    model="gemini-2.0-flash-live-preview-04-09",
    response_modalities=["audio"]
)

# ✅ 正: テキストのみ
text_agent = Agent(
    model="gemini-2.0-flash-live-preview-04-09",
    response_modalities=["text"]
)
```

### プリビルトボイス

```python
from google.genai.types import SpeechConfig

# ADKが提供する5つのプリビルトボイス
PREBUILT_VOICES = {
    "Puck":   "明るく元気な声（汎用）",
    "Charon": "落ち着いた低音（ナレーション向き）",
    "Kore":   "中性的でプロフェッショナル（ビジネス向き）",
    "Fenrir": "力強く権威的（アナウンス向き）",
    "Aoede":  "柔らかく温かい（サポート向き）",
}

# ボイスの設定
speech_config = SpeechConfig(
    voice_config={"voice_name": "Kore"}  # 上記5種から選択
)

agent = Agent(
    name="voice_agent",
    model="gemini-2.0-flash-live-preview-04-09",  # Live APIモデルが必須
    instruction="音声で対話するアシスタント",
    speech_config=speech_config,
    response_modalities=["audio"],
)
```

### モデル要件

| プラットフォーム | モデル | 特徴 |
|----------------|--------|------|
| Vertex AI | `gemini-2.0-flash-live-preview-04-09` | プレビュー版、低レイテンシ |
| AI Studio | `gemini-live-2.5-flash-preview` | より新しいバージョン |

### LiveRequestQueue

```python
from google.adk.agents.live_request_queue import LiveRequestQueue

# PCM音声キューの作成
queue = LiveRequestQueue()

# テキストメッセージの送信
queue.put(types.Content(
    role="user",
    parts=[types.Part(text="こんにちは")]
))

# PCM音声バイトの送信（16kHz、モノラル、16bit）
audio_chunk = b'\x00' * 1024  # 実際はマイクからのPCMデータ
queue.put(audio_chunk)

# キューのクローズ（ストリームの終了を通知）
queue.close()
```

### 双方向ストリーミング vs ターンベース

| 特性 | 双方向ストリーミング（Live API） | ターンベース（通常のSSE） |
|------|---------------------|-------------|
| **通信方式** | 継続的な双方向接続 | リクエスト/レスポンス |
| **レイテンシ** | 低（リアルタイム） | 高（バッチ処理） |
| **主なユースケース** | 音声通話、リアルタイム字幕、音声対話 | 音声ファイル文字起こし、一括処理 |
| **接続プロトコル** | WebSocket | HTTP SSE |
| **状態管理** | 必要（継続接続のため） | 不要（ステートレス） |
| **コスト** | 接続時間に比例 | トークンに比例 |

### 完全な音声対話実装

```python
import asyncio
import pyaudio
from google.adk.agents import Agent
from google.adk.agents.live_request_queue import LiveRequestQueue
from google.adk.runners import InMemoryRunner
from google.genai.types import SpeechConfig, GenerateContentConfig

async def voice_conversation():
    """フルデュプレックス音声対話の完全実装"""

    # Agent設定
    agent = Agent(
        name="voice_assistant",
        model="gemini-2.0-flash-live-preview-04-09",
        instruction="""
        ユーザーと音声で自然に対話するアシスタント。
        簡潔で明確な回答を心がけ、会話のテンポを保つ。
        """,
        response_modalities=["audio"],
        speech_config=SpeechConfig(
            voice_config={"voice_name": "Kore"}
        ),
        generate_content_config=GenerateContentConfig(
            max_output_tokens=180,   # 音声出力には150-200トークンが推奨
            temperature=0.8,
        )
    )

    runner = InMemoryRunner(agent=agent, app_name="voice_demo")
    session = await runner.session_service.create_session(
        app_name="voice_demo",
        user_id="voice_user",
    )

    queue = LiveRequestQueue()

    # 音声入力設定: 16kHz、モノラル、16bit PCM（Live API要件）
    INPUT_RATE = 16000
    # 音声出力設定: 24kHz（Live APIが24kHzで出力）
    OUTPUT_RATE = 24000
    CHUNK_SIZE = 1024  # 小さいチャンクサイズでレイテンシを最小化
    FORMAT = pyaudio.paInt16
    CHANNELS = 1

    p = pyaudio.PyAudio()

    input_stream = p.open(
        format=FORMAT,
        channels=CHANNELS,
        rate=INPUT_RATE,
        input=True,
        frames_per_buffer=CHUNK_SIZE,
    )

    output_stream = p.open(
        format=FORMAT,
        channels=CHANNELS,
        rate=OUTPUT_RATE,
        output=True,
    )

    print("[INFO] 音声対話を開始しました。Ctrl+Cで終了します。")

    async def send_audio():
        """マイクからPCM音声をリアルタイムでキューに送信"""
        try:
            while True:
                data = input_stream.read(CHUNK_SIZE, exception_on_overflow=False)
                queue.put(data)
                await asyncio.sleep(0)  # 他のコルーチンに制御を渡す
        except KeyboardInterrupt:
            queue.close()

    async def receive_audio():
        """Live APIからの音声レスポンスを受信して再生"""
        try:
            async for response in runner.run_live(
                user_id="voice_user",
                session_id=session.id,
                live_request_queue=queue,
            ):
                # 音声データの再生
                if hasattr(response, 'audio_data') and response.audio_data:
                    output_stream.write(response.audio_data)

                # テキストが含まれる場合（デバッグ用）
                if response.content and response.content.parts:
                    for part in response.content.parts:
                        if part.text:
                            print(f"[TRANSCRIPT] {part.text}")

        except Exception as e:
            print(f"[ERROR] 音声受信エラー: {e}")

    try:
        # 送信と受信を並行実行
        await asyncio.gather(
            send_audio(),
            receive_audio(),
        )
    finally:
        input_stream.stop_stream()
        input_stream.close()
        output_stream.stop_stream()
        output_stream.close()
        p.terminate()
        print("[INFO] 音声対話を終了しました。")


# エントリーポイント
if __name__ == "__main__":
    asyncio.run(voice_conversation())
```

### max_output_tokens の推奨設定

音声出力では `max_output_tokens` を制限することで、レイテンシを大幅に削減できる。

```python
from google.genai.types import GenerateContentConfig

# 音声出力用（短めに設定してレイテンシを最小化）
audio_config = GenerateContentConfig(
    max_output_tokens=150,   # 音声: 150-200トークン推奨
    temperature=0.7,
)

# テキスト出力用（より長い応答が可能）
text_config = GenerateContentConfig(
    max_output_tokens=1024,  # テキスト: 用途に応じて設定
    temperature=0.7,
)

audio_agent = Agent(
    name="responsive_voice",
    model="gemini-2.0-flash-live-preview-04-09",
    instruction="簡潔に答える音声アシスタント",
    response_modalities=["audio"],
    generate_content_config=audio_config,
)
```

### ベストプラクティスまとめ

#### 音声品質

| 設定項目 | 推奨値 | 理由 |
|---------|-------|------|
| 入力サンプリングレート | 16kHz | Live API要件 |
| 出力サンプリングレート | 24kHz | Live API出力形式 |
| チャンネル数 | モノラル（1ch） | ステレオ不要、帯域節約 |
| 入力フォーマット | 16bit PCM | 最も互換性が高い |
| チャンクサイズ | 512〜1024バイト | レイテンシとスループットのバランス |

#### レイテンシ最適化

```python
# ✅ レイテンシ最適化のチェックリスト

# 1. max_output_tokensを音声用に制限
generate_content_config = GenerateContentConfig(max_output_tokens=150)

# 2. 小さなチャンクサイズで送信
CHUNK_SIZE = 512  # 大きすぎると遅延が増す

# 3. asyncio.sleep(0)で他のコルーチンに制御を渡す
async def send_audio():
    while True:
        data = stream.read(CHUNK_SIZE)
        queue.put(data)
        await asyncio.sleep(0)  # 重要: イベントループをブロックしない

# 4. バッファリングを最小化（out_stream.write は即座に再生）
```

#### エラーハンドリング

```python
async def resilient_live_session(runner, agent, max_reconnects: int = 3):
    """接続切断時に自動再接続するLive APIセッション"""
    reconnect_count = 0

    while reconnect_count <= max_reconnects:
        queue = LiveRequestQueue()
        session = await runner.session_service.create_session(
            app_name="voice_demo",
            user_id="voice_user",
        )

        try:
            await asyncio.gather(
                send_audio_task(queue),
                receive_audio_task(runner, session.id, queue),
            )
            break  # 正常終了

        except ConnectionError:
            reconnect_count += 1
            if reconnect_count > max_reconnects:
                print("[ERROR] 接続を再確立できませんでした")
                raise

            wait = 2 ** reconnect_count
            print(f"[WARN] 接続が切断されました。{wait}秒後に再接続... ({reconnect_count}/{max_reconnects})")
            await asyncio.sleep(wait)

        except Exception as e:
            print(f"[ERROR] 予期しないエラー: {e}")
            raise
```

---

## トラブルシューティング

### Callback が呼ばれない

**原因と対策**:

1. Callbackの関数シグネチャを確認
   - `before_agent_callback(callback_context)` — `CallbackContext` のみ
   - `before_model_callback(callback_context, llm_request)` — `CallbackContext` + `llm_request`
   - `before_tool_callback(tool_context, tool, args)` — `ToolContext` + `tool` + `args`

2. Agent定義でCallbackが正しく登録されているか確認
   ```python
   agent = Agent(
       before_model_callback=my_callback,  # 関数オブジェクトを渡す（呼び出しではない）
   )
   ```

3. 戻り値の型が正しいか確認（`None` または正しい型のオブジェクト）

### Plugin が適用されない

**原因と対策**:

1. `Runner` の `plugins` パラメータにインスタンスを渡しているか確認
   ```python
   runner = Runner(agent=agent, plugins=[MyPlugin()])  # インスタンスを渡す
   ```

2. プラグインメソッドが `async def` で定義されているか確認

### SSE ストリームが途中で切れる

**原因と対策**:

1. Nginx/プロキシのバッファリングを無効化
   ```python
   headers={"X-Accel-Buffering": "no"}  # Nginx用
   ```

2. `asyncio.sleep(0)` を追加してイベントループをブロックしない

3. タイムアウト設定を確認（デフォルト値が短い場合がある）

### Live API が接続できない

**原因と対策**:

1. **モデルバージョン**: Live APIサポートモデルを使用しているか
   - `gemini-2.0-flash-live-preview-04-09`（Vertex AI）
   - `gemini-live-2.5-flash-preview`（AI Studio）

2. **response_modalities**: `["text", "audio"]` の混在はエラーになる

3. **音声フォーマット**: 入力は16kHz PCM、出力は24kHz PCMである必要がある
