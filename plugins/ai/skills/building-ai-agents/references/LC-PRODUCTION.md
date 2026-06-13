# 本番化ガイド: メモリ・ガードレール・デプロイ

LangGraphエージェントを本番環境で動作させるための実装ガイド。
メモリ（会話状態の永続化）・ガードレール（スコープ制限）・Human-in-the-loop・評価・デプロイを網羅する。

---

## 目次

1. [メモリ: Checkpointによる会話状態管理](#1-メモリ-checkpointによる会話状態管理)
2. [ガードレール: 入力フィルタリングとスコープ制限](#2-ガードレール-入力フィルタリングとスコープ制限)
3. [Human-in-the-loop](#3-human-in-the-loop)
4. [評価: LangSmithによるAgent評価](#4-評価-langsmithによるagent評価)
5. [デプロイ: LangGraph PlatformとOAP](#5-デプロイ-langgraph-platformとoap)
6. [ローカルLLM推論エンジン](#6-ローカルllm推論エンジン)

---

## 1. メモリ: Checkpointによる会話状態管理

### メモリの種類

| タイプ | スコープ | 永続性 | 例 | 課題 |
|--------|---------|--------|-----|-----|
| **短期メモリ** | 単一ユーザーセッション | セッション終了まで | 「同じ町」を覚える | セッション終了で消える |
| **長期メモリ（ユーザー）** | 複数セッション・1ユーザー | 週・月・年単位 | ユーザーの好みを記憶 | プライバシー・コンプライアンス |
| **長期メモリ（アプリ）** | 全ユーザー・全セッション | 継続的に更新 | 汎用知識ベース | データ鮮度の維持 |

本セクションでは最も実装頻度の高い**短期メモリ**（チェックポイント方式）に焦点を当てる。

### LangGraphチェックポイントの仕組み

**チェックポイント**: グラフの各ノード実行後に会話状態のスナップショットを保存する機構。

利点:
- **会話の継続性**: 「あの町」→ 前回言及した町を解決
- **障害復旧**: 実行途中で失敗しても最後のチェックポイントから再開
- **Human-in-the-loop**: 人間レビューのために一時停止し、後で再開

### InMemorySaverの実装

```python
from langgraph.checkpoint.memory import InMemorySaver
from langgraph.graph import StateGraph, END
import uuid

# チェックポイント作成
checkpointer = InMemorySaver()

# グラフのコンパイル時にチェックポイントを渡す
graph = StateGraph(AgentState)
graph.add_node("router", router_node)
graph.add_node("travel_agent", travel_info_agent)
graph.add_edge("travel_agent", END)
graph.set_entry_point("router")

# checkpointer を渡すことでグラフが状態を永続化
travel_assistant = graph.compile(checkpointer=checkpointer)
```

### Thread IDによるセッション管理

```python
def chat_loop():
    # セッション開始時に一意のthread_idを生成
    thread_id = uuid.uuid1()
    config = {"configurable": {"thread_id": thread_id}}
    print(f"Thread ID: {thread_id}")

    while True:
        user_input = input("You: ").strip()
        if user_input.lower() in {"exit", "quit"}:
            break

        state = {"messages": [HumanMessage(content=user_input)]}
        # config を毎回渡すことで同一スレッドのチェックポイントを参照
        result = travel_assistant.invoke(state, config=config)
        response = result["messages"][-1]
        print(f"Assistant: {response.content}\n")
```

### 本番環境向けチェックポイントバックエンド

| バックエンド | パッケージ | 用途 |
|------------|---------|------|
| `InMemorySaver` | langgraph（組み込み） | 開発・テスト・PoC |
| `SqliteSaver` | langgraph-checkpoint-sqlite | 単一サーバー・軽量本番 |
| `PostgresSaver` | langgraph-checkpoint-postgres | スケーラブルな本番環境（推奨） |

```python
# 本番: SqliteSaverの使用
from langgraph.checkpoint.sqlite import SqliteSaver

with SqliteSaver.from_conn_string(":memory:") as checkpointer:
    travel_assistant = graph.compile(checkpointer=checkpointer)
```

### 過去チェックポイントへの巻き戻し

```python
# 状態履歴の取得
state_history = travel_assistant.get_state_history(config)
snapshots = list(state_history)

# 最新スナップショットからcheckpoint_idを取得
last_snapshot = snapshots[0]
checkpoint_id = last_snapshot.config["configurable"]["checkpoint_id"]
new_config = {
    "configurable": {
        "thread_id": thread_id,
        "checkpoint_id": checkpoint_id
    }
}

# 特定チェックポイントへの巻き戻しと続行
travel_assistant.invoke(None, config=new_config)
result = travel_assistant.invoke(
    {"messages": [HumanMessage(content="同じ町の天気は?")]},
    config=new_config
)
```

---

## 2. ガードレール: 入力フィルタリングとスコープ制限

### ガードレールの種類

| タイプ | 実装方法 | 例 |
|-------|---------|-----|
| **ルールベース** | 正規表現・キーワードフィルタ | 禁止ワードの検出 |
| **検索ベース** | 承認済みデータソースとの照合 | 対応地域リストとの比較 |
| **モデルベース** | LLM分類器による意図判定 | 関連性チェック（本セクションで解説） |

### 配置ポイント

```
ユーザー入力
    ↓
【ルーターレベルガードレール】← 明らかな非関連クエリを早期除外
    ↓
ルーターエージェント
    ↓
【エージェントレベルガードレール】← 各エージェント固有のスコープ制限
    ↓
LLM呼び出し
    ↓
【ポストモデルガードレール】← 出力内容の検証（PII除去等）
```

### ルーターレベルガードレールの実装

```python
from langchain_core.messages import SystemMessage, HumanMessage, AIMessage
from langgraph.graph import Command
from pydantic import BaseModel

# 判定用の構造化出力モデル
class GuardrailDecision(BaseModel):
    is_relevant: bool  # 関連性フラグ

GUARDRAIL_SYSTEM_PROMPT = """あなたは厳格な分類器です。
ユーザーのメッセージが旅行関連かどうかを判定してください。
旅行関連とは: 目的地・観光スポット・宿泊施設・天気・交通手段に関する質問。"""

# ガードレール用の高速・小さなLLM
llm_guardrail = ChatOpenAI(model="gpt-4o-mini").with_structured_output(GuardrailDecision)

def router_agent_node(state: AgentState) -> Command[AgentType]:
    """ガードレール付きルーターノード"""
    messages = state["messages"]
    last_msg = messages[-1] if messages else None

    if isinstance(last_msg, HumanMessage):
        user_input = last_msg.content

        # ガードレールチェック実行
        decision = llm_guardrail.invoke([
            SystemMessage(content=GUARDRAIL_SYSTEM_PROMPT),
            HumanMessage(content=user_input),
        ])

        if not decision.is_relevant:
            # 非関連: 丁寧に拒否してENDへ
            refusal = "申し訳ございませんが、旅行に関するご質問のみ対応しております。"
            return Command(
                update={"messages": [AIMessage(content=refusal)]},
                goto="guardrail_refusal",
            )

        # 関連: 通常のルーティングへ
        router_response = llm_router.invoke([...])
        return Command(update=state, goto=router_response.agent.value)
```

### エージェントレベルガードレール: pre_model_hook

LangGraphのReActエージェントは `pre_model_hook`（LLM呼び出し前フック）をサポートする。

```python
AGENT_GUARDRAIL_PROMPT = """厳格な分類器として、クエリが対象地域（例: 特定地域）
に関する旅行質問かどうかを判定してください。"""

def pre_model_guardrail(state: dict):
    """エージェントレベルの入力フィルタリング"""
    messages = state.get("messages", [])
    last_msg = messages[-1] if messages else None

    if not isinstance(last_msg, HumanMessage):
        return {}  # ユーザーメッセージ以外はスキップ

    decision = llm_guardrail.invoke([
        SystemMessage(content=AGENT_GUARDRAIL_PROMPT),
        HumanMessage(content=last_msg.content),
    ])

    if decision.is_relevant:
        return {}  # 適切: 変更なし

    # 非適切: 拒否指示をLLM入力の先頭に挿入
    REFUSAL_INSTRUCTION = SystemMessage(
        content="このリクエストは対象外です。丁寧に断り、対応範囲を説明してください。"
    )
    return {"llm_input_messages": [REFUSAL_INSTRUCTION, *messages]}

# エージェント作成時にhookを登録
agent = create_react_agent(
    model=llm,
    tools=TOOLS,
    state_schema=AgentState,
    prompt="旅行情報エージェントです。ツールのみで情報を提供します。",
    pre_model_hook=pre_model_guardrail,  # ガードレール登録
)
```

### ポストモデルガードレールの考慮事項

- 個人情報（PII）の除去（プライベート連絡先等）
- 期限切れ情報のフィルタリング
- ブランドトーン・スタイルの統一
- 構造化出力の形式検証（他システムへのAPI連携時）

---

## 3. Human-in-the-loop

### 適用場面

- 曖昧なクエリでの人間判断が必要な場合
- データ不完全・不確実性が高い場合
- リアルタイム情報（災害・ストライキ等）
- 高額・リスクの高いアクション前の承認

### LangGraphでの実装

`interrupt_before` または `interrupt_after` でグラフの特定ノードで一時停止できる。

```python
from langgraph.types import interrupt

def booking_confirmation_node(state: AgentState):
    """予約前に人間の承認を要求するノード"""
    booking_details = state.get("proposed_booking")

    # Human-in-the-loop: 承認待ち
    human_approval = interrupt({
        "message": "以下の予約を確定しますか?",
        "details": booking_details,
    })

    if human_approval["approved"]:
        # 承認された場合: 実際の予約処理
        return {"booking_status": "confirmed", "messages": [...]}
    else:
        # 拒否された場合: キャンセル処理
        return {"booking_status": "cancelled", "messages": [...]}

# グラフコンパイル（interrupt_before でも可）
travel_assistant = graph.compile(
    checkpointer=checkpointer,
    interrupt_before=["booking_confirmation"]  # このノード前で一時停止
)
```

**本番運用の利点:**
- 人間レビューで精度を担保（初期デプロイ時に特に有効）
- 承認/拒否データが後のガードレール改善・プロンプト改善に活用可能

---

## 4. 評価: LangSmithによるAgent評価

### 評価の4次元

| 評価タイプ | 内容 | 例 |
|----------|------|-----|
| **機能テスト** | 正確・関連性の高い回答を提供するか | 「Cornwall最高のビーチ」への正確な回答 |
| **行動テスト** | ポリシー・安全ルールを遵守するか | 非関連質問への適切な拒否 |
| **パフォーマンステスト** | レイテンシ・APIコストの測定 | ピーク時のP95レイテンシ |
| **リグレッションテスト** | プロンプト変更・LLM更新後の信頼性確認 | 既存テストセットへの評価 |

### LangSmithでの評価セットアップ

```bash
# .envに追加
LANGSMITH_TRACING=true
LANGSMITH_ENDPOINT="https://api.smith.langchain.com"
LANGSMITH_API_KEY="<your-api-key>"
LANGSMITH_PROJECT="my-agent-evaluation"
```

```python
from langsmith import Client

client = Client()

# 評価データセットの作成
dataset = client.create_dataset("travel-assistant-eval")
client.create_examples(
    inputs=[
        {"question": "Cornwallの最高のビーチタウンは?"},
        {"question": "Penzanceの天気は?"},
    ],
    outputs=[
        {"answer": "St Ives, Newquay等が人気"},
        {"answer": "現在の気象条件を提供"},
    ],
    dataset_id=dataset.id
)
```

**評価メトリクス:**
- 忠実度（Faithfulness）: ツールからの事実に基づく回答か
- 関連性（Relevance）: ユーザーの質問に答えているか
- 接地性（Groundedness）: ハルシネーションがないか

---

## 5. デプロイ: LangGraph PlatformとOAP

### LangGraph Platform

LangChainが提供するマネージドホスティングサービス。

**主な機能:**
- 水平スケーリング（自動）
- 永続的状態管理
- LangSmithダッシュボードとの統合
- End-to-endモニタリング

```bash
# LangGraph CLIでのデプロイ
pip install langgraph-cli
langgraph deploy --config langgraph.json
```

### Open Agent Platform (OAP)

エンタープライズ向けの柔軟なランタイム・オーケストレーション層。

**適用場面:**
- MCP・ローカルベクトルDB・企業データソースへの接続が必要
- 複数エージェントを組み合わせたエンタープライズユースケース
- データレジデンシー・コンプライアンス要件がある環境

### デプロイオプション比較

| オプション | 特徴 | 適用場面 |
|-----------|------|---------|
| **LangGraph Platform（SaaS）** | フルマネージド・最小運用コスト | 迅速なPoC→本番移行 |
| **LangGraph Platform（プライベート）** | 自社クラウドにデプロイ | 規制要件・データ主権 |
| **OAP（SaaS）** | 複数エージェント統合に強い | エンタープライズエコシステム |
| **OAP（プライベート）** | 最大制御 | 最厳格なコンプライアンス要件 |

**本番準備チェックリスト:**
- [ ] `InMemorySaver` → `PostgresSaver` に変更
- [ ] エラー率・P95レイテンシのモニタリング設定
- [ ] LangSmithへの評価データセットのアップロード
- [ ] ガードレールの動作テスト（境界ケース含む）
- [ ] Staged Rollout（カナリアリリース）の計画

---

## 6. ローカルLLM推論エンジン

クラウドLLM（OpenAI等）の代替として、オープンソースLLMをローカルで実行できる。

### 適用場面

| 理由 | 詳細 |
|-----|-----|
| **コスト削減** | PoC後の本番コスト最適化 |
| **プライバシー** | センシティブデータをクラウドに送りたくない |
| **オフライン** | インターネット接続が不安定な環境 |
| **カスタマイズ** | Fine-tuningが必要なドメイン特化タスク |

### 量子化: 消費者向けハードウェアでの実行

大規模モデルは量子化により小型化できる:

| 精度 | バイト/パラメータ | Llama 7Bサイズ |
|-----|---------------|-------------|
| 16-bit (float16) | 2 bytes | ~14 GB |
| 8-bit quantization | 1 byte | ~7 GB |
| 4-bit quantization | 0.5 bytes | ~3.5 GB |

4-bit量子化なら16-32GB RAMの一般的なPCでも動作可能。

### 推論エンジン比較

| エンジン | バックエンド | 対象ユーザー | OpenAI互換API | GUIあり |
|---------|-----------|------------|-------------|--------|
| **llama.cpp** | 自身 | 上級者・高度カスタマイズ | ✅ | なし |
| **Ollama** | llama.cpp | 開発者向け（簡単） | △（独自API） | なし |
| **vLLM** | 自身 | 本番GPU環境 | ✅ | なし |
| **LM Studio** | llama.cpp | 一般ユーザー | ✅ (port 8080) | ✅ |
| **GPT4All** | llama.cpp | 一般ユーザー・RAG | ✅ (port 4891) | ✅ |
| **LocalAI** | llama.cpp/vLLM | Dockerベース環境 | ✅ (port 8080) | なし |

### LangChainからのローカルLLM接続

OpenAI互換エンドポイントを持つエンジンなら、`base_url` を変えるだけで接続できる:

```python
from langchain_openai import ChatOpenAI

# LM Studio（port 8080）への接続例
llm = ChatOpenAI(
    model="mistral",  # エンジン固有のモデル名
    openai_api_base="http://localhost:8080/v1",
    openai_api_key="NO_KEY_NEEDED",  # ローカルなのでキー不要
    temperature=0
)

# 同じAPIで呼び出し可能
response = llm.invoke("Cornwallの有名な観光地は?")
```

### 主要エンジン別クイックスタート

**Ollama（開発・実験向け）:**
```bash
# インストール後
ollama run mistral

# REST API（注: OpenAI互換ではない独自API）
curl http://localhost:11434/api/generate -d '{
  "model": "mistral",
  "prompt": "What is the capital of France?"
}'
```

**vLLM（本番GPU環境向け）:**
```bash
pip install vllm
# OpenAI互換サーバー起動（Linux + GPU必須）
python -m vllm.entrypoints.openai.api_server \
  --model mistralai/Mistral-7B-v0.1
# → port 8000 でOpenAI互換APIが起動
```

**LM Studio（GUIで手軽に試す場合）:**
1. lmstudio.aiからインストール
2. GUIでモデル検索・ダウンロード（Hugging Face統合）
3. Server → Port 8080 → Start Server
4. LangChainから `http://localhost:8080/v1` に接続

### エンジン選択ガイドライン

```
新規利用者 → llamafile（最も簡単）
   ↓
モデル切り替えが多い / 開発効率重視 → Ollama
   ↓
GUIが欲しい / 非エンジニア → LM Studio / GPT4All
   ↓
本番・高スループット / Linux + GPU → vLLM
   ↓
最大制御が必要 → llama.cpp直接
```

---

## 本番化チェックリスト

### メモリ
- [ ] `InMemorySaver` を本番向けバックエンド（`SqliteSaver`/`PostgresSaver`）に置き換え
- [ ] `thread_id` を用いたセッション管理が正しく動作している
- [ ] 複数ターンの会話で文脈が正しく保持される

### ガードレール
- [ ] ルーターレベルのドメイン関連性チェックを実装
- [ ] エージェントレベルの `pre_model_hook` でスコープ制限
- [ ] 境界ケース（グレーゾーンのクエリ）でのテスト実施

### 評価
- [ ] 100+件のクエリ・回答ペアの評価データセット作成
- [ ] LangSmithで自動評価パイプラインを構築
- [ ] エラー率・レイテンシ・トークン使用量のモニタリング設定

### デプロイ
- [ ] LangGraph PlatformまたはOAPへのデプロイ計画策定
- [ ] データレジデンシー要件の確認（SaaS vs プライベート）
- [ ] Staged Rollout（カナリアリリース）の実施
