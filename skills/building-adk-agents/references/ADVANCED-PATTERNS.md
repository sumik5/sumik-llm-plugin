# 高度なパターン

Google ADKの高度な開発パターン、意思決定フレームワーク、オブザーバビリティ、本番運用ベストプラクティス。

---

## 1. YAML設定ベースAgent定義

### 1.1 YAML構文とスキーマ

Agentの定義をコードではなくYAMLファイルで宣言的に記述できる。

**基本構文:**

```yaml
name: my_agent          # 必須: Agent識別子
model: gemini-2.0-flash # 必須: 使用モデル
description: "Agent purpose"
instruction: |
  Multi-line instructions
  for the agent behavior
generate_content_config:
  temperature: 0.7
  max_output_tokens: 2048
  top_p: 0.95
  top_k: 40
tools:
  - name: tool_name
    type: function
sub_agents:
  - name: specialized_agent
    model: gemini-2.0-flash
    description: "Specialized task handler"
    instruction: "Handle specific domain tasks"
```

**フィールド説明:**

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `name` | ✅ | Agent識別子（英数字とアンダースコア） |
| `model` | ✅ | 使用するGeminiモデルID |
| `description` | 推奨 | Agentの目的（デバッグ・ドキュメント用） |
| `instruction` | 推奨 | Agentの振る舞い指示（システムプロンプト相当） |
| `generate_content_config` | 任意 | モデル生成パラメータ |
| `tools` | 任意 | 利用可能なToolリスト |
| `sub_agents` | 任意 | 階層化Agentの子定義 |

### 1.2 Pythonからの読み込み

**基本読み込み:**

```python
from google.adk.agents import config_agent_utils

# YAMLファイルからAgent生成
agent = config_agent_utils.from_config('root_agent.yaml')

# Runner起動
from google.adk.runners import InMemoryRunner
runner = InMemoryRunner(agent=agent, app_name="YAMLApp")
```

**⚠️ 注意:** `AgentConfig.from_yaml_file()` というメソッドは存在しない。必ず `config_agent_utils.from_config()` を使用すること。

### 1.3 環境別設定管理

**ディレクトリ構成:**

```
config/
├── dev/
│   └── root_agent.yaml       # 開発環境設定
├── staging/
│   └── root_agent.yaml       # ステージング設定
└── prod/
    └── root_agent.yaml       # 本番設定
```

**環境変数による切り替え:**

```python
import os
from pathlib import Path

def load_agent_for_environment() -> Agent:
    env = os.getenv("ENV", "dev")
    config_path = Path(f"config/{env}/root_agent.yaml")

    if not config_path.exists():
        raise FileNotFoundError(f"Config not found: {config_path}")

    return config_agent_utils.from_config(str(config_path))
```

### 1.4 環境変数参照（セキュリティ必須）

**機密情報の参照:**

```yaml
name: secure_agent
model: gemini-2.0-flash
tools:
  - name: api_client
    type: function
    config:
      api_key: "${API_KEY}"        # 環境変数から注入
      endpoint: "${API_ENDPOINT}"
```

**環境変数設定:**

```bash
export API_KEY="sk-..."
export API_ENDPOINT="https://api.example.com"
```

**❌ ハードコード禁止例:**

```yaml
# 絶対にこれをしてはならない
tools:
  - name: api_client
    config:
      api_key: "sk-1234567890abcdef"  # セキュリティリスク
```

### 1.5 設定バリデーション

**バリデーション関数:**

```python
from google.adk.agents import config_agent_utils

def validate_config(yaml_path: str) -> tuple[bool, str]:
    """YAML設定の検証"""
    try:
        agent = config_agent_utils.from_config(yaml_path)

        # 基本検証
        assert agent.name, "Agent name is required"
        assert agent.model, "Model specification is required"

        # Tool検証
        if agent.tools:
            for tool in agent.tools:
                assert hasattr(tool, 'name'), "Tool must have name"

        return True, "Validation passed"

    except FileNotFoundError:
        return False, f"File not found: {yaml_path}"
    except yaml.YAMLError as e:
        return False, f"YAML syntax error: {e}"
    except AssertionError as e:
        return False, f"Validation failed: {e}"
    except Exception as e:
        return False, f"Unexpected error: {e}"

# 使用例
is_valid, message = validate_config("config/prod/root_agent.yaml")
if not is_valid:
    print(f"❌ {message}")
    exit(1)
```

### 1.6 ハイブリッドアーキテクチャ

YAML宣言的定義とPython動的カスタマイズの組み合わせ。

**パターン:**

```python
# YAMLで基本構造を定義
base_agent = config_agent_utils.from_config('base_agent.yaml')

# Pythonで動的にToolを追加
from google.adk.tools import FunctionTool

def runtime_tool(query: str) -> str:
    """Runtime-added tool"""
    return f"Processed: {query}"

dynamic_tool = FunctionTool(
    name="runtime_tool",
    function=runtime_tool
)

# Toolを結合
base_agent.tools = [*base_agent.tools, dynamic_tool]
```

**ユースケース:**
- 開発環境ではモックToolを追加
- 本番環境では実際のAPIクライアントを注入
- A/Bテスト用の実験的Tool差し替え

---

## 2. 意思決定フレームワーク

### 2.1 Agent種類選択

| Agent種類 | 最適用途 | 例 | 複雑度 |
|-----------|---------|-----|--------|
| `LlmAgent` | 単一ステップタスク、純粋推論 | Q&A、文章要約、分類、分析 | ⭐ |
| `SequentialAgent` | 依存関係のある順序付きワークフロー | データ取得→処理→分析→レポート | ⭐⭐ |
| `ParallelAgent` | 独立した並行タスク | マルチソース情報収集、並列分析 | ⭐⭐ |
| `LoopAgent` | 反復的改善サイクル | コードレビュー、コンテンツ編集、品質チェック | ⭐⭐⭐ |

**選択基準:**

```python
def recommend_agent_type(task_description: str) -> str:
    """タスク特性から推奨Agent種類を返す"""

    # 依存関係チェック
    has_dependencies = any([
        "then" in task_description,
        "after" in task_description,
        "based on" in task_description
    ])

    # 並行性チェック
    is_parallel = any([
        "simultaneously" in task_description,
        "at the same time" in task_description,
        "multiple sources" in task_description
    ])

    # 反復性チェック
    is_iterative = any([
        "improve" in task_description,
        "refine" in task_description,
        "until" in task_description
    ])

    if is_iterative:
        return "LoopAgent"
    elif is_parallel:
        return "ParallelAgent"
    elif has_dependencies:
        return "SequentialAgent"
    else:
        return "LlmAgent"
```

### 2.2 Tool種類選択

| 判断要素 | FunctionTool | OpenAPITool | MCPTool |
|---------|-------------|-------------|---------|
| **開発速度** | 最速（数分） | 中速（数時間） | 最遅（1日以上） |
| **メンテナンス負担** | 最高（手動更新） | 中（スキーマ同期） | 最低（サーバー側管理） |
| **柔軟性** | 最大（任意のPython処理） | 限定的（REST APIのみ） | 中（プロトコル制約内） |
| **相互運用性** | なし（プロジェクト固有） | 限定的（OpenAPI標準） | 最大（MCP標準） |
| **セキュリティモデル** | カスタム実装必須 | APIキーベース | 組み込みサンドボックス |
| **デバッグ難易度** | 低（直接実行） | 中（ネットワーク考慮） | 高（サーバープロセス分離） |

**選択決定木:**

```
プロトタイプ開発？
├─ Yes → FunctionTool
└─ No
    ↓
外部API連携？
├─ Yes → OpenAPI仕様あり？
│         ├─ Yes → OpenAPITool
│         └─ No → FunctionTool（ラッパー実装）
└─ No
    ↓
複数プロジェクト共有？
├─ Yes → MCPTool
└─ No → FunctionTool
```

### 2.3 モデル選択ガイド

| 用途 | 推奨モデル | 主な利点 | レイテンシ | コスト |
|------|----------|---------|----------|--------|
| 高速レスポンス | `gemini-2.0-flash` | 速度最適化、低コスト | 最低 | 最安 |
| 複雑な推論 | `gemini-2.0-flash-thinking` | 組み込みChain-of-Thought | 中 | 中 |
| コード生成 | `gemini-2.0-flash` | 強力なコーディング能力 | 低 | 安 |
| マルチモーダル | `gemini-2.0-flash` | Vision、Audio、Video対応 | 低 | 安 |
| ライブ対話 | `gemini-2.0-flash-live` | リアルタイムストリーミング | 最低 | 中 |

**選択基準（SLA要件ベース）:**

```python
from dataclasses import dataclass

@dataclass
class ModelRequirement:
    max_latency_ms: int
    multimodal: bool
    reasoning_complexity: str  # "simple" | "complex"
    budget_tier: str  # "low" | "medium" | "high"

def select_model(req: ModelRequirement) -> str:
    """要件からモデルを選択"""

    if req.max_latency_ms < 500:
        if req.multimodal:
            return "gemini-2.0-flash"  # 高速＋マルチモーダル
        elif req.reasoning_complexity == "complex":
            return "gemini-2.0-flash-thinking"  # 高速＋推論
        else:
            return "gemini-2.0-flash"  # 最高速

    elif req.reasoning_complexity == "complex":
        return "gemini-2.0-flash-thinking"

    else:
        return "gemini-2.0-flash"
```

### 2.4 デプロイ環境選択

| 要素 | ローカル | Cloud Run | Agent Engine | GKE |
|------|---------|----------|-------------|-----|
| **セットアップ時間** | 最速（数分） | 速い（数時間） | 中（半日） | 最遅（数日） |
| **自動スケーリング** | 手動（プロセス起動） | 自動（0→N） | 自動（サーバーレス） | 自動（K8s HPA） |
| **コストモデル** | 無料（開発マシン） | 従量課金（リクエスト） | 従量課金（リクエスト） | インフラ課金（常時） |
| **カスタマイズ** | 最大（任意の設定） | 限定（Dockerコンテナ） | 限定（ADKプロトコル） | 最大（K8sマニフェスト） |
| **ネットワーク制御** | なし（localhost） | VPC Connector | マネージドVPC | 完全制御 |
| **最大同時実行数** | CPUコア数依存 | 1000（デフォルト） | 自動最適化 | クラスタサイズ依存 |

**選択フローチャート:**

```
開発フェーズ？
├─ Yes → ローカル
└─ No
    ↓
トラフィック予測可能？
├─ No（スパイキー） → Cloud Run
└─ Yes
    ↓
VPC統合必須？
├─ Yes → GKE
└─ No → Agent Engine
```

### 2.5 データスコープ選択

| データカテゴリ | スコープ | 保持期間 | 暗号化 | 例 |
|-------------|---------|---------|--------|-----|
| **ユーザー設定** | `user:` | 永続 | 必須 | プロフィール、言語設定 |
| **セッションコンテキスト** | `session:` | セッション期間 | 推奨 | 会話履歴、一時的状態 |
| **一時データ** | `temp:` | リクエストのみ | 任意 | 中間計算結果 |
| **アプリ設定** | `app:` | 永続 | 必須 | API keys、設定フラグ |
| **PII（個人識別情報）** | `user:` | 永続 | 必須 | 氏名、メールアドレス |

**スコープ選択ルール:**

```python
def determine_scope(data_type: str, retention_needed: bool, is_pii: bool) -> str:
    """データ特性からスコープを決定"""

    if is_pii:
        # PII は必ず user: スコープ
        return "user:"

    elif retention_needed:
        # 永続化が必要
        if data_type in ["config", "settings", "preferences"]:
            return "app:"
        else:
            return "user:"

    elif data_type in ["conversation", "context"]:
        # セッション期間のみ保持
        return "session:"

    else:
        # 一時的計算結果
        return "temp:"

# 使用例
scope = determine_scope("email_address", retention_needed=True, is_pii=True)
# → "user:"

scope = determine_scope("intermediate_result", retention_needed=False, is_pii=False)
# → "temp:"
```

---

## 3. 高度なオブザーバビリティ

### 3.1 MetricsCollectorPlugin

リクエストライフサイクル全体のメトリクス収集。

**実装例:**

```python
from google.adk.plugins import Plugin
from collections import defaultdict
import time

class MetricsCollectorPlugin(Plugin):
    def __init__(self):
        self.request_count = 0
        self.success_count = 0
        self.failure_count = 0
        self.latencies = []
        self.token_usage = defaultdict(int)
        self.tool_calls = defaultdict(int)

    def before_agent_callback(self, context):
        """リクエスト開始時刻を記録"""
        context.custom_data["start_time"] = time.time()
        self.request_count += 1

    def after_agent_callback(self, context):
        """リクエスト完了時のメトリクス集約"""
        elapsed = time.time() - context.custom_data["start_time"]
        self.latencies.append(elapsed)

        if context.error:
            self.failure_count += 1
        else:
            self.success_count += 1

    def after_model_callback(self, context):
        """トークン使用量を記録"""
        if hasattr(context, 'usage_metadata'):
            self.token_usage['input'] += context.usage_metadata.prompt_token_count
            self.token_usage['output'] += context.usage_metadata.candidates_token_count

    def after_tool_callback(self, context):
        """Tool呼び出し回数を記録"""
        tool_name = context.tool_call.name
        self.tool_calls[tool_name] += 1

    def get_summary(self) -> dict:
        """集約メトリクスを返す"""
        import statistics

        return {
            "total_requests": self.request_count,
            "success_count": self.success_count,
            "failure_count": self.failure_count,
            "success_rate": self.success_count / self.request_count if self.request_count > 0 else 0,
            "latency": {
                "mean": statistics.mean(self.latencies) if self.latencies else 0,
                "p50": statistics.median(self.latencies) if self.latencies else 0,
                "p95": statistics.quantiles(self.latencies, n=20)[18] if len(self.latencies) > 20 else 0,
                "p99": statistics.quantiles(self.latencies, n=100)[98] if len(self.latencies) > 100 else 0,
            },
            "tokens": dict(self.token_usage),
            "tool_calls": dict(self.tool_calls),
        }

# 使用例
metrics = MetricsCollectorPlugin()
agent = LlmAgent(
    model="gemini-2.0-flash",
    plugins=[metrics]
)

# リクエスト処理後
print(metrics.get_summary())
# {
#   "total_requests": 100,
#   "success_count": 98,
#   "failure_count": 2,
#   "success_rate": 0.98,
#   "latency": {
#     "mean": 1.234,
#     "p50": 1.100,
#     "p95": 2.300,
#     "p99": 3.450
#   },
#   "tokens": {"input": 12000, "output": 8000},
#   "tool_calls": {"search": 45, "calculate": 23}
# }
```

### 3.2 PerformanceProfilerPlugin

Tool実行時間の詳細プロファイリング。

**実装例:**

```python
from google.adk.plugins import Plugin
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Dict, List
import time

@dataclass
class ToolStats:
    call_count: int = 0
    total_time: float = 0.0
    min_time: float = float('inf')
    max_time: float = 0.0
    times: List[float] = field(default_factory=list)

    def add_call(self, duration: float):
        self.call_count += 1
        self.total_time += duration
        self.min_time = min(self.min_time, duration)
        self.max_time = max(self.max_time, duration)
        self.times.append(duration)

    @property
    def avg_time(self) -> float:
        return self.total_time / self.call_count if self.call_count > 0 else 0

class PerformanceProfilerPlugin(Plugin):
    def __init__(self):
        self.tool_stats: Dict[str, ToolStats] = defaultdict(ToolStats)
        self.active_calls: Dict[str, float] = {}

    def before_tool_callback(self, context):
        """Tool呼び出し開始時刻を記録"""
        call_id = f"{context.tool_call.name}_{id(context)}"
        self.active_calls[call_id] = time.time()

    def after_tool_callback(self, context):
        """Tool実行時間を集計"""
        call_id = f"{context.tool_call.name}_{id(context)}"
        start_time = self.active_calls.pop(call_id, None)

        if start_time:
            duration = time.time() - start_time
            self.tool_stats[context.tool_call.name].add_call(duration)

    def get_profile(self) -> Dict[str, dict]:
        """Tool別パフォーマンスサマリ"""
        return {
            tool_name: {
                "call_count": stats.call_count,
                "total_time": round(stats.total_time, 3),
                "avg_time": round(stats.avg_time, 3),
                "min_time": round(stats.min_time, 3),
                "max_time": round(stats.max_time, 3),
            }
            for tool_name, stats in self.tool_stats.items()
        }

    def print_report(self):
        """見やすいレポート出力"""
        print("\n=== Performance Profile ===")
        for tool_name, stats in sorted(
            self.tool_stats.items(),
            key=lambda x: x[1].total_time,
            reverse=True
        ):
            print(f"\n{tool_name}:")
            print(f"  Calls:     {stats.call_count}")
            print(f"  Total:     {stats.total_time:.3f}s")
            print(f"  Avg:       {stats.avg_time:.3f}s")
            print(f"  Min/Max:   {stats.min_time:.3f}s / {stats.max_time:.3f}s")

# 使用例
profiler = PerformanceProfilerPlugin()
agent = LlmAgent(
    model="gemini-2.0-flash",
    plugins=[profiler]
)

# リクエスト処理後
profiler.print_report()
# === Performance Profile ===
#
# search_web:
#   Calls:     45
#   Total:     12.345s
#   Avg:       0.274s
#   Min/Max:   0.120s / 1.230s
#
# calculate:
#   Calls:     23
#   Total:     3.456s
#   Avg:       0.150s
#   Min/Max:   0.080s / 0.450s
```

### 3.3 AlertingPlugin

閾値ベースのアラート監視。

**実装例:**

```python
from google.adk.plugins import Plugin
from dataclasses import dataclass
from typing import Callable
import time

@dataclass
class AlertConfig:
    latency_threshold_ms: int = 3000
    error_threshold: int = 5
    critical_error_threshold: int = 10
    on_alert: Callable[[str], None] = lambda msg: print(f"🚨 ALERT: {msg}")

class AlertingPlugin(Plugin):
    def __init__(self, config: AlertConfig = AlertConfig()):
        self.config = config
        self.consecutive_errors = 0

    def before_agent_callback(self, context):
        context.custom_data["request_start"] = time.time()

    def after_agent_callback(self, context):
        """レイテンシとエラー閾値チェック"""
        elapsed_ms = (time.time() - context.custom_data["request_start"]) * 1000

        # レイテンシアラート
        if elapsed_ms > self.config.latency_threshold_ms:
            self.config.on_alert(
                f"High latency: {elapsed_ms:.0f}ms (threshold: {self.config.latency_threshold_ms}ms)"
            )

        # エラーアラート
        if context.error:
            self.consecutive_errors += 1

            if self.consecutive_errors >= self.config.critical_error_threshold:
                self.config.on_alert(
                    f"🔴 CRITICAL: {self.consecutive_errors} consecutive errors"
                )
            elif self.consecutive_errors >= self.config.error_threshold:
                self.config.on_alert(
                    f"⚠️  WARNING: {self.consecutive_errors} consecutive errors"
                )
        else:
            self.consecutive_errors = 0  # 成功時はリセット

# 使用例
def send_to_pagerduty(message: str):
    """本番環境ではPagerDuty等に送信"""
    print(f"📟 Sending to PagerDuty: {message}")
    # requests.post("https://events.pagerduty.com/v2/enqueue", ...)

alert_config = AlertConfig(
    latency_threshold_ms=2000,
    error_threshold=3,
    critical_error_threshold=5,
    on_alert=send_to_pagerduty
)

alerting = AlertingPlugin(config=alert_config)
agent = LlmAgent(
    model="gemini-2.0-flash",
    plugins=[alerting]
)
```

### 3.4 Cloud Traceデプロイ統合

ADK CLIのデプロイコマンドに `--trace_to_cloud` フラグを追加することで、Google Cloud Traceに自動的にトレースを送信。

**Cloud Runデプロイ:**

```bash
adk deploy cloud_run \
  --agent_file agent.py \
  --trace_to_cloud
```

**Agent Engineデプロイ:**

```bash
adk deploy agent_engine \
  --agent_file agent.py \
  --trace_to_cloud
```

**ローカルWebサーバー:**

```bash
adk web \
  --agent_file agent.py \
  --trace_to_cloud
```

**Cloud Traceでの確認:**

1. Google Cloud Console → Trace → Trace List
2. リクエストごとのスパン詳細を確認
3. Tool呼び出し、モデル呼び出しの時間分布を可視化

---

## 4. 本番ベストプラクティス

### 4.1 コード構成

#### モジュラーTool設計

**単一責任原則:**

```python
# ❌ 悪い例: 1つのToolが複数責務を持つ
@google.genai.function_declaration
def do_everything(query: str) -> str:
    """Search, process, and format"""
    data = search_api(query)
    processed = process_data(data)
    return format_output(processed)

# ✅ 良い例: Tool を分離
@google.genai.function_declaration
def search(query: str) -> str:
    """Search for information"""
    return search_api(query)

@google.genai.function_declaration
def process_data(data: str) -> str:
    """Process raw data"""
    return process_logic(data)

@google.genai.function_declaration
def format_output(data: str) -> str:
    """Format data for presentation"""
    return format_logic(data)
```

**ドメイン別整理:**

```
tools/
├── search/
│   ├── web_search.py
│   └── document_search.py
├── processing/
│   ├── text_processor.py
│   └── data_transformer.py
└── formatting/
    ├── json_formatter.py
    └── markdown_formatter.py
```

#### Agentインスタンスキャッシュ

```python
from functools import lru_cache
from google.adk.agents import LlmAgent

@lru_cache(maxsize=1)
def get_agent() -> LlmAgent:
    """Agentシングルトン（初期化コスト削減）"""
    return LlmAgent(
        model="gemini-2.0-flash",
        instruction="..."
    )

# FastAPI例
from fastapi import FastAPI
app = FastAPI()

@app.post("/chat")
async def chat(query: str):
    agent = get_agent()  # 初回のみ初期化
    return await agent.run_async(query)
```

#### セッション履歴管理

```python
from google.adk.agents import LlmAgent

class SessionManager:
    def __init__(self, max_history: int = 10):
        self.max_history = max_history

    def prune_history(self, agent: LlmAgent):
        """履歴を最新N件に制限"""
        if len(agent.state.history) > self.max_history:
            # 古い履歴を削除
            agent.state.history = agent.state.history[-self.max_history:]

    def summarize_and_prune(self, agent: LlmAgent):
        """古い履歴を要約してから削除（コンテキスト保持）"""
        if len(agent.state.history) > self.max_history:
            old_history = agent.state.history[:-self.max_history]
            summary = self._summarize(old_history)

            # 要約を新しい履歴の先頭に配置
            agent.state.history = [
                {"role": "system", "content": f"Previous context: {summary}"},
                *agent.state.history[-self.max_history:]
            ]

    def _summarize(self, history: list) -> str:
        """履歴の要約生成（別のLLM呼び出しで実装）"""
        # 実装省略
        return "Summary of previous conversation..."

# 使用例
manager = SessionManager(max_history=10)

async def handle_request(query: str, agent: LlmAgent):
    manager.summarize_and_prune(agent)  # 履歴管理
    response = await agent.run_async(query)
    return response
```

### 4.2 パフォーマンス最適化

#### 簡潔で構造化されたInstruction

```python
# ❌ 悪い例: 冗長で構造化されていない
instruction = """
You are a helpful assistant. You should always be polite and respectful.
When users ask questions, you should try your best to answer them accurately.
If you don't know something, you should say so. Also, remember to be concise.
You have access to various tools that you can use to help answer questions.
Make sure to use them when appropriate. Don't forget to format your responses nicely.
Always double-check your work before responding. Be friendly and professional.
"""

# ✅ 良い例: 簡潔で構造化
instruction = """
Role: Technical support assistant

Rules:
1. Answer accurately; admit unknowns
2. Use tools when needed
3. Be concise and professional

Format: Markdown
"""
```

**効果:** トークン数を約70%削減（237 tokens → 71 tokens）

#### バッチ処理

```python
import asyncio
from google.adk.agents import LlmAgent

async def process_batch(queries: list[str], agent: LlmAgent) -> list[str]:
    """複数クエリを並行処理"""
    tasks = [agent.run_async(q) for q in queries]
    results = await asyncio.gather(*tasks)
    return results

# 使用例
queries = [
    "Summarize document 1",
    "Summarize document 2",
    "Summarize document 3",
]

agent = LlmAgent(model="gemini-2.0-flash")
results = await process_batch(queries, agent)

# パフォーマンス:
# - 逐次処理: 3 × 1.5s = 4.5s
# - 並行処理: max(1.5s, 1.5s, 1.5s) = 1.5s
# → 3倍高速化
```

#### コンテキストウィンドウ管理

```python
from google.adk.agents import LlmAgent

def manage_context_window(agent: LlmAgent, max_messages: int = 20):
    """コンテキストウィンドウの自動プルーニング"""
    history = agent.state.history

    if len(history) > max_messages:
        # システムメッセージを保持
        system_messages = [m for m in history if m.get("role") == "system"]
        recent_messages = history[-max_messages:]

        # 結合
        agent.state.history = system_messages + recent_messages

        print(f"Pruned {len(history) - len(agent.state.history)} messages")

# 使用例
agent = LlmAgent(model="gemini-2.0-flash")

for i in range(50):
    await agent.run_async(f"Query {i}")
    manage_context_window(agent, max_messages=20)
```

#### モデルティアリング

```python
from google.adk.agents import LlmAgent

class TieredAgentRouter:
    def __init__(self):
        self.lite_agent = LlmAgent(model="gemini-2.0-flash-lite")
        self.standard_agent = LlmAgent(model="gemini-2.0-flash")
        self.pro_agent = LlmAgent(model="gemini-2.0-flash-thinking")

    async def route(self, query: str) -> str:
        """クエリ複雑度に応じてモデルを選択"""
        complexity = self._analyze_complexity(query)

        if complexity == "simple":
            return await self.lite_agent.run_async(query)
        elif complexity == "complex":
            return await self.pro_agent.run_async(query)
        else:
            return await self.standard_agent.run_async(query)

    def _analyze_complexity(self, query: str) -> str:
        """クエリの複雑度を判定"""
        # 簡易ヒューリスティック
        word_count = len(query.split())

        if word_count < 10:
            return "simple"
        elif word_count > 50 or "analyze" in query or "compare" in query:
            return "complex"
        else:
            return "standard"

# 使用例
router = TieredAgentRouter()

# シンプルな分類 → lite
result1 = await router.route("Is this positive or negative?")

# 標準QA → flash
result2 = await router.route("What is the capital of France?")

# 複雑な分析 → thinking
result3 = await router.route("Analyze the trade-offs between microservices and monolithic architecture")
```

**コスト削減効果:**
- Lite使用率40% → コスト30%削減
- Pro使用率10%（必要時のみ） → 過剰スペック回避

### 4.3 テスト戦略

#### テストピラミッド構造

```
     /\
    /  \  Evaluation (5-10%)
   /____\
  /      \  Integration (20-30%)
 /________\
/__________\  Unit (70-80%)
```

**Unit Test（Tool単体テスト）:**

```python
import pytest
from tools.search import web_search

def test_web_search_basic():
    result = web_search("Python ADK")
    assert "ADK" in result
    assert len(result) > 0

def test_web_search_empty_query():
    with pytest.raises(ValueError):
        web_search("")
```

**Integration Test（Agent + Tool統合テスト）:**

```python
import pytest
from google.adk.agents import LlmAgent
from tools.search import web_search_tool

@pytest.mark.asyncio
async def test_agent_with_search_tool():
    agent = LlmAgent(
        model="gemini-2.0-flash",
        tools=[web_search_tool]
    )

    response = await agent.run_async("Search for Python ADK")

    # Tool が呼ばれたことを確認
    assert any(
        call.name == "web_search"
        for call in agent.state.tool_calls
    )

    # レスポンスにキーワードが含まれることを確認
    assert "ADK" in response
```

**Evaluation Test（品質評価テスト）:**

```python
from google.adk.agents import LlmAgent

async def evaluate_accuracy(test_cases: list[dict]) -> float:
    """正解率評価"""
    agent = LlmAgent(model="gemini-2.0-flash")
    correct = 0

    for case in test_cases:
        response = await agent.run_async(case["query"])
        if case["expected_keyword"] in response:
            correct += 1

    return correct / len(test_cases)

# 使用例
test_cases = [
    {"query": "What is 2+2?", "expected_keyword": "4"},
    {"query": "Capital of France?", "expected_keyword": "Paris"},
]

accuracy = await evaluate_accuracy(test_cases)
print(f"Accuracy: {accuracy * 100:.1f}%")
```

#### モックTool検証

```python
from unittest.mock import AsyncMock
from google.adk.agents import LlmAgent
from google.adk.tools import FunctionTool

@pytest.mark.asyncio
async def test_agent_with_mock_tool():
    # モックTool作成
    mock_search = AsyncMock(return_value="Mocked result")
    search_tool = FunctionTool(
        name="search",
        function=mock_search
    )

    agent = LlmAgent(
        model="gemini-2.0-flash",
        tools=[search_tool]
    )

    response = await agent.run_async("Search for something")

    # Tool が呼ばれたことを検証
    mock_search.assert_called_once()

    # 引数を検証
    args = mock_search.call_args[0]
    assert "something" in args[0].lower()
```

### 4.4 運用パターン

#### SLI監視

```python
from dataclasses import dataclass
from typing import List

@dataclass
class SLI:
    """Service Level Indicator"""
    name: str
    current_value: float
    target: float
    unit: str

    @property
    def is_meeting_target(self) -> bool:
        return self.current_value <= self.target

class SLIMonitor:
    def __init__(self):
        self.slis: List[SLI] = []

    def track(self, name: str, value: float, target: float, unit: str):
        sli = SLI(name, value, target, unit)
        self.slis.append(sli)

        if not sli.is_meeting_target:
            print(f"⚠️  SLI breach: {name} = {value}{unit} (target: {target}{unit})")

    def report(self):
        print("\n=== SLI Report ===")
        for sli in self.slis:
            status = "✅" if sli.is_meeting_target else "❌"
            print(f"{status} {sli.name}: {sli.current_value}{sli.unit} (target: {sli.target}{sli.unit})")

# 使用例
monitor = SLIMonitor()

# メトリクス収集後
monitor.track("p50_latency", 850, 1000, "ms")
monitor.track("p95_latency", 2100, 2000, "ms")  # 閾値超過
monitor.track("p99_latency", 3200, 3000, "ms")  # 閾値超過
monitor.track("error_rate", 0.02, 0.05, "%")
monitor.track("tool_success_rate", 0.98, 0.95, "%")

monitor.report()
# === SLI Report ===
# ✅ p50_latency: 850ms (target: 1000ms)
# ❌ p95_latency: 2100ms (target: 2000ms)
# ❌ p99_latency: 3200ms (target: 3000ms)
# ✅ error_rate: 0.02% (target: 0.05%)
# ✅ tool_success_rate: 0.98% (target: 0.95%)
```

#### エラー分類

```python
from enum import Enum

class ErrorCategory(Enum):
    RETRYABLE = "retryable"
    PERMANENT = "permanent"
    RATE_LIMIT = "rate_limit"

def classify_error(error: Exception) -> ErrorCategory:
    """エラーをカテゴリ分類"""
    error_msg = str(error).lower()

    # レート制限エラー
    if "rate limit" in error_msg or "quota" in error_msg:
        return ErrorCategory.RATE_LIMIT

    # 一時的エラー（リトライ可能）
    if any(keyword in error_msg for keyword in [
        "timeout", "connection", "temporary", "503", "429"
    ]):
        return ErrorCategory.RETRYABLE

    # 永続的エラー
    return ErrorCategory.PERMANENT

async def retry_with_backoff(func, max_retries: int = 3):
    """エラーカテゴリに応じたリトライ"""
    import asyncio

    for attempt in range(max_retries):
        try:
            return await func()
        except Exception as e:
            category = classify_error(e)

            if category == ErrorCategory.PERMANENT:
                raise  # リトライしない

            elif category == ErrorCategory.RATE_LIMIT:
                wait_time = 60 * (2 ** attempt)  # 指数バックオフ（60秒, 120秒, 240秒）
                print(f"Rate limit hit, waiting {wait_time}s...")
                await asyncio.sleep(wait_time)

            elif category == ErrorCategory.RETRYABLE:
                wait_time = 2 ** attempt  # 1秒, 2秒, 4秒
                print(f"Retryable error, waiting {wait_time}s...")
                await asyncio.sleep(wait_time)

    raise Exception(f"Failed after {max_retries} retries")
```

#### サーキットブレーカー

```python
from enum import Enum
from dataclasses import dataclass
import time

class CircuitState(Enum):
    CLOSED = "closed"      # 正常動作
    OPEN = "open"          # 遮断（リクエスト拒否）
    HALF_OPEN = "half_open"  # 回復テスト中

@dataclass
class CircuitBreakerConfig:
    failure_threshold: int = 5
    timeout_seconds: int = 60
    success_threshold: int = 2

class CircuitBreaker:
    def __init__(self, config: CircuitBreakerConfig = CircuitBreakerConfig()):
        self.config = config
        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.success_count = 0
        self.last_failure_time = None

    async def call(self, func):
        """サーキットブレーカー経由でファンクション実行"""

        # OPEN状態（遮断中）
        if self.state == CircuitState.OPEN:
            if self._should_attempt_reset():
                self.state = CircuitState.HALF_OPEN
                print("🔄 Circuit HALF_OPEN: Testing recovery")
            else:
                raise Exception("Circuit breaker is OPEN")

        try:
            result = await func()
            self._on_success()
            return result

        except Exception as e:
            self._on_failure()
            raise

    def _on_success(self):
        """成功時の処理"""
        self.failure_count = 0

        if self.state == CircuitState.HALF_OPEN:
            self.success_count += 1
            if self.success_count >= self.config.success_threshold:
                self.state = CircuitState.CLOSED
                self.success_count = 0
                print("✅ Circuit CLOSED: Recovered")

    def _on_failure(self):
        """失敗時の処理"""
        self.failure_count += 1
        self.last_failure_time = time.time()

        if self.failure_count >= self.config.failure_threshold:
            self.state = CircuitState.OPEN
            print(f"🔴 Circuit OPEN: {self.failure_count} consecutive failures")

        if self.state == CircuitState.HALF_OPEN:
            self.state = CircuitState.OPEN
            self.success_count = 0
            print("🔴 Circuit OPEN: Recovery failed")

    def _should_attempt_reset(self) -> bool:
        """タイムアウト経過後にリセット試行"""
        if self.last_failure_time is None:
            return False

        elapsed = time.time() - self.last_failure_time
        return elapsed >= self.config.timeout_seconds

# 使用例
breaker = CircuitBreaker(
    CircuitBreakerConfig(
        failure_threshold=5,
        timeout_seconds=60,
        success_threshold=2
    )
)

async def unreliable_service():
    """不安定な外部サービス"""
    import random
    if random.random() < 0.3:
        raise Exception("Service unavailable")
    return "Success"

async def protected_call():
    try:
        result = await breaker.call(unreliable_service)
        print(f"Result: {result}")
    except Exception as e:
        print(f"Error: {e}")

# 連続実行
for _ in range(20):
    await protected_call()
    await asyncio.sleep(1)
```

---

## まとめ

### 主要パターン選択ガイド

| シナリオ | 推奨パターン |
|---------|------------|
| プロトタイプ開発 | FunctionTool + InMemoryRunner + ローカル実行 |
| 小規模本番（<100 req/day） | YAML設定 + Cloud Run + MetricsCollector |
| 中規模本番（100-10k req/day） | YAML設定 + Agent Engine + PerformanceProfiler + Alerting |
| 大規模本番（>10k req/day） | Python構成 + GKE + Cloud Trace + サーキットブレーカー |
| マルチ環境管理 | YAML環境別設定 + 環境変数参照 |

### 開発フェーズ別チェックリスト

**プロトタイプ:**
- [ ] FunctionToolで高速実装
- [ ] InMemoryRunnerで動作確認
- [ ] 基本的なエラーハンドリング

**ステージング:**
- [ ] YAML設定に移行
- [ ] MetricsCollectorPlugin追加
- [ ] Integration Test実装
- [ ] Cloud Run/Agent Engineにデプロイ

**本番:**
- [ ] PerformanceProfilerPlugin追加
- [ ] AlertingPlugin設定
- [ ] Cloud Trace有効化
- [ ] サーキットブレーカー実装
- [ ] SLI監視ダッシュボード構築
- [ ] Evaluation Test（品質評価）実装
