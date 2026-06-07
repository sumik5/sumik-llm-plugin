# エージェントシステムパターン（P21–P23）

> LLMをパッシブなコンテンツ生成器から、世界に働きかけ・コードを実行し・協調するアクティブなエージェントへと変換する3パターン。

## 目次

- [Pattern 21: Tool Calling](#pattern-21-tool-calling)
- [Pattern 22: Code Execution](#pattern-22-code-execution)
- [Pattern 23: Multiagent Collaboration](#pattern-23-multiagent-collaboration)

---

## Pattern 21: Tool Calling

### 問題

LLMはテキスト・画像・音声などのコンテンツ生成に優れているが、それだけでは多くのビジネスタスクを実行できない。

- フライト予約やAPIトランザクションなど、実際に「何かを実行する」ことができない
- リアルタイムの情報（天気・株価・最新ニュース）を持っていない
- カレンダー・メール・企業内データベースなどのパーソナルデータにアクセスできない
- 数値計算、GIS分析、最適化ソルバーなど専門計算ツールを使えない

LLMと外部ソフトウェアAPIの間に橋を架けるにはどうすればよいか？

### 解決策

LLMが**特殊トークンを出力**することで関数呼び出しの意図を表明し、クライアント側のコードが実際のAPIを呼び出してその結果をLLMに返す。LLMは結果を最終レスポンスに統合する。

3つの実装レイヤーがある:
1. **低レベルAPI**（OpenAI Responses API等）: 関数定義を渡してトークン出力を処理
2. **フレームワーク**（LangGraph等）: クライアント側処理を抽象化
3. **MCP（Model Context Protocol）**: ツール定義を標準化し、異なるLLM・言語間でポータブルに

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| リアルタイム情報が必要（天気・株価・ニュース） | ✅ Tool Callingが最適 |
| 企業トランザクション（予約・発注・支払い） | ✅ Tool Callingが最適 |
| 関数が短いパラメータリストで呼び出せる | ✅ Tool Callingが適切 |
| 関数の入力がSQLや長いDSL文字列 | ⚠️ P22 Code Executionを検討 |
| セキュリティ要件が厳しい外部データを処理する | ⚠️ Prompt Injection対策必須（後述） |
| ツール数が10〜20以上 | ⚠️ LLMの精度が落ちる。ツールを絞るか動的選択を検討 |

### 実装のポイント

```python
# ── MCP サーバー側（ツール定義） ──
from mcp import FastMCP

mcp = FastMCP("flight-booking")

@mcp.tool()
async def book_flight(
    flight_code: str,
    departure_date: str,
    cabin_class: str,
    passenger_name: str
) -> dict:
    """
    Books a flight using the airline API.

    Args:
        flight_code: IATA flight code (e.g., 'TK 161')
        departure_date: Date in YYYY-MM-DD format (e.g., '2025-06-12')
        cabin_class: One of 'economy', 'premium_economy', 'business', 'first'
        passenger_name: Full name of the passenger

    Returns:
        Booking confirmation with reference number and flight details
    """
    # 外部航空会社APIを呼び出す
    response = requests.post("https://api.airline.example.com/book", json={
        "flight_code": flight_code,
        "date": departure_date,
        "class": cabin_class,
        "passenger": passenger_name
    })
    return response.json()

if __name__ == "__main__":
    mcp.run(transport="streamable-http")  # リモートクライアント用
    # mcp.run(transport="stdio")          # ローカルPythonクライアント用


# ── MCP クライアント側（ReActエージェント） ──
from langchain_mcp_adapters.client import MultiServerMCPClient
import langgraph.prebuilt

async def run_booking_agent(user_request: str) -> str:
    async with MultiServerMCPClient({
        "flight_booking": {
            "url": "http://localhost:8000/mcp",
            "transport": "streamable_http",
        }
    }) as client:
        # ReActエージェントが自動的にツール呼び出しタイミングを判断
        agent = langgraph.prebuilt.create_react_agent(
            "anthropic:claude-sonnet-4-6",
            client.get_tools()
        )
        result = await agent.ainvoke({
            "messages": [{"role": "user", "content": user_request}]
        })
        return result["messages"][-1].content

# 使用例
# response = asyncio.run(run_booking_agent(
#     "Book me economy class from Tokyo to New York on March 20"
# ))
```

**信頼性を高める設計原則**:
- 関数名・パラメータ・docstringを**自己説明的**に書く（LLMはdocstringを読んでいる）
- システムプロンプトに「どの関数をいつ使うか」のポリシーを記述
- Enumパラメータを活用してP2 Grammarパターンとの相乗効果を得る
- ツール数は**3〜10個**が精度のスイートスポット（多いほど精度低下）

### 注意事項・トレードオフ

**Prompt Injection リスク**:

Tool Callingを持つエージェントはコンテンツ生成だけのエージェントより攻撃面が広い。悪意のあるテキストがLLMのコンテキストに混入し、意図しないツール呼び出しを引き起こす可能性がある。

| 防御パターン | 詳細 |
|-------------|------|
| **Action-Selector** | 事前定義済みのアクションのみ許可し、ツール結果をエージェントに戻さない |
| **Plan-Then-Execute** | エージェントが固定プランを先に立て、ツール結果があっても計画を逸脱しない |
| **Map-Reduce** | 分離されたサブエージェントが個別のデータを処理（Mapフェーズ）。信頼できるReduceで集約 |
| **Dual-LLM** | 権限を持つLLMと、非信頼データを処理するサンドボックスLLMを分離 |
| **Code-Then-Execute** | エージェントが信頼できるコードを生成し、非信頼データはコードで処理 |
| **Context-Minimization** | 後続ステップから不要なコンテキスト（元のユーザープロンプト等）を削除 |

**MCPの現状の制限**（2025年時点）:
- セキュリティ（認証・認可）はプロトコルが保証しない（Cloudflare等で補完）
- 双方向コミュニケーション（A2A/ACP等の新プロトコルで補完中）
- MCPコールはデフォルト30〜60秒でタイムアウト

**代替パターンとの比較**:
- P22 Code Execution: 入力がDSLや長い文字列の場合はこちらが適切
- P21 + P18 Reflection: ツール失敗時にエラーメッセージをLLMに戻して再試行（ReAct）

---

## Pattern 22: Code Execution

### 問題

グラフ作成・画像のテキストアノテーション・データベース更新など、特定のタスクはAPIの短いパラメータ呼び出しでは対応できない。

- グラフ生成にはMatplotlib等のプログラミングコードが必要
- データベース操作にはSQL文（DSL）が必要
- これらは「短いパラメータを渡してAPIを呼び出す」形式ではなく「長いDSLコードを書いて実行する」形式だ

Tool Callingは**DSL入力を要求する関数**には不向きだ。

### 解決策

LLMに**DSLコードを生成させ**、外部システム（通常はサンドボックス環境）でそのコードを実行する。

プロセス:
1. ユーザーの自然言語リクエストをLLMに送る
2. LLMがDSLコード（SQL・Matplotlib・Mermaid・GraphViz等）を生成する
3. サンドボックス環境でコードを実行
4. 実行結果（グラフ・テーブル・データ等）をレスポンスとして返す

ReActフレームワーク内に組み込んで、推論ステップとコード実行ステップを交互に行うことも可能。

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| グラフ・チャートの生成（Matplotlib・Mermaid等） | ✅ Code Executionが最適 |
| 自然言語からのデータベースクエリ（Text-to-SQL） | ✅ Code Executionが最適 |
| 画像への注釈・テキストオーバーレイ（ImageMagick等） | ✅ Code Executionが最適 |
| 関数入力がDSLや長い文字列 | ✅ Tool Callingより適切 |
| 生成コードの精度が不安定 | ⚠️ 入力を狭いDSLに限定するか、P18 Reflectionと組み合わせる |
| セキュリティ要件が厳しい環境 | ⚠️ サンドボックス設計に十分な投資が必要 |

### 実装のポイント

```python
from pydantic_ai import Agent
import subprocess
import os

# ── ステップ1: LLMにDSLコードを生成させる ──
def generate_graphviz_code(tournament_data: str) -> str:
    """LLMがGraphviz DOTコードを生成"""
    agent = Agent("anthropic:claude-sonnet-4-6")

    prompt = f"""
    Convert the following tournament results into Graphviz DOT format.
    Use subgraphs named cluster_xxx for each round.

    Example format:
    "TeamA" -> "TeamB" [label="85-65"]
    subgraph cluster_elite_eight {{
        label = "Elite Eight"
        {{rank = same; "TeamB"; "TeamC";}}
    }}

    Tournament data:
    {tournament_data}

    Output only the Graphviz edges and subgraphs (no digraph wrapper needed):
    """

    return agent.run_sync(prompt).data

# ── ステップ2: サンドボックスでコードを実行 ──
def execute_graphviz(dot_code: str, output_file: str = "output.png") -> str:
    """サンドボックス内でGraphvizを実行してグラフを生成"""
    # DOTコードをファイルに保存
    dot_file = "tournament.dot"
    with open(dot_file, "w") as f:
        f.write(f"digraph G {{\n{dot_code}\n}}")

    # サンドボックス実行（タイムアウト・リソース制限付き）
    result = subprocess.run(
        ["dot", "-Grankdir=LR", "-Tpng", dot_file, "-o", output_file],
        capture_output=True,
        text=True,
        timeout=30  # タイムアウト必須
    )

    if result.returncode != 0:
        # エラーをLLMに戻してReflection（P18）で修正可能
        raise ValueError(f"Graphviz error: {result.stderr}")

    return output_file

# ── Text-to-SQL の例 ──
def natural_language_query(nl_query: str, schema: str) -> list:
    """自然言語クエリをSQLに変換して実行"""
    agent = Agent("anthropic:claude-sonnet-4-6")

    # LLMがSQLを生成
    sql_prompt = f"""
    Generate a SQL query for the following request.
    Return only the SQL query, no explanation.

    Database schema:
    {schema}

    Request: {nl_query}
    """
    sql = agent.run_sync(sql_prompt).data

    # サンドボックスDBでSQL実行（本番DBとは分離）
    import sqlite3
    conn = sqlite3.connect(":memory:")  # 本番では読み取り専用レプリカを使用
    cursor = conn.execute(sql)
    return cursor.fetchall()
```

**サンドボックス要件（必須）**:

```
必須制約:
- CPU使用率の上限（無限ループ防止）
- メモリ使用量の上限
- ネットワークアクセスの制限（必要最小限）
- 実行時間タイムアウト（通常30秒）
- ファイルシステムアクセスの制限

実装手段:
- Docker/Kubernetes コンテナ
- VM（仮想マシン）
- WebAssembly サンドボックス
- 専用サンドボックスサービス（E2B、Modal等）
```

### 注意事項・トレードオフ

| 観点 | 詳細 |
|------|------|
| **セキュリティ最優先** | LLM生成コードはサンドボックスなしで絶対に実行しない。悪意ある入力からのコードインジェクションリスクあり |
| **DSLに特化させる** | 汎用プログラミング言語よりも、Mermaid・GraphViz等の狭いDSLに限定するほうが精度・安全性ともに高い |
| **Reflectionとの組み合わせ** | 構文エラーや実行エラーをLLMに戻して修正させることで信頼性が大幅に向上（P18参照） |
| **バリデーション** | コードを実行する前に構文チェック、静的解析、形式検証を実施 |
| **現状の限界** | 2025年時点では、入力が厳密に制御されるかReflectionが使える場合を除き信頼性は不安定 |

**代替パターンとの比較**:
- P21 Tool Calling: 短いパラメータで呼び出せる場合はこちらが適切
- P18 Reflection: コード実行エラーのフィードバックループに活用
- 組み合わせ: ReActフレームワーク内で推論→コード生成→実行→反映を繰り返す

---

## Pattern 23: Multiagent Collaboration

### 問題

単一エージェントアーキテクチャには根本的な限界がある。

| 限界 | 詳細 |
|------|------|
| **認知ボトルネック** | コンテキストウィンドウと計算容量の有限性。複数の知識ドメインにまたがるタスクで一貫性が崩れる |
| **パラメータ効率の低下** | モデルサイズを大きくすることは逓減するリターンをもたらす。専門化された複数の小モデルのほうが効率的な場合がある |
| **推論深度の限界** | トランスフォーマーの逐次推論では並列思考経路の探索が困難 |
| **ドメイン適応の問題** | 汎用訓練データでは特定ドメインの深い専門知識を得にくい |

これらを超えるために、複数の専門エージェントを組織的に協調させるにはどうすればよいか？

### 解決策

人間の組織構造を模倣した**認知労働の分業**を実装する。

3つのアーキテクチャパターンがある:

**① 階層型（Hierarchical）**: 高レベルのエグゼクティブエージェントがタスクを分解・委譲し、専門ワーカーエージェントが実行。最もシンプルな形は**プロンプトチェーン**（逐次ワークフロー）。

**② ピアツーピア（Peer-to-Peer）**: エージェントが対等な立場で情報共有・合意形成。投票・コンセンサスメカニズムを使って意思決定。

**③ マーケット型（Market-based）**: オークション・効用最大化でタスクやリソースを割り当て。エージェントが能力と空きリソースに基づいてビッドする。

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| 独立した並列処理が可能なサブタスクに分解できる | ✅ 最も一般的で効果的な利用ケース |
| 異なる専門知識ドメインが必要なタスク | ✅ 専門エージェントへの分業 |
| 品質検証に多角的な視点が必要（レビューパネル等） | ✅ ピアツーピアが有効 |
| 単一エージェントで処理できる範囲のタスク | ❌ 過剰設計。オーバーヘッドが品質向上を上回る |
| レイテンシに極めて厳しい制約がある | ⚠️ エージェント間通信のオーバーヘッドを考慮 |

### 実装のポイント

```python
# ── 階層型: プロンプトチェーン（逐次ワークフロー） ──
from langchain.chains import LLMChain, SequentialChain
from langchain_core.prompts import PromptTemplate
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(model="gpt-4o")

paragraph_chain = LLMChain(
    llm=llm,
    prompt=PromptTemplate(
        input_variables=["topic"],
        template="Write a concise and informative paragraph on {topic}."
    ),
    output_key="paragraph"
)

title_chain = LLMChain(
    llm=llm,
    prompt=PromptTemplate(
        input_variables=["paragraph"],
        template="Write a catchy title for this paragraph: {paragraph}"
    ),
    output_key="title"
)

# 各エージェントがバトンを渡す逐次チェーン
pipeline = SequentialChain(
    chains=[paragraph_chain, title_chain],
    input_variables=["topic"],
    output_variables=["paragraph", "title"]
)


# ── ピアツーピア: レビューパネルによる合意形成 ──
from crewai import Agent, Task, Crew

senior_editor = Agent(
    role="Senior Editor",
    goal="Ensure accuracy and quality of educational content",
    backstory="Expert in curriculum development with 20+ years of experience"
)

content_editor = Agent(
    role="Content Editor",
    goal="Ensure age-appropriate language and clarity",
    backstory="Specialist in writing for young students"
)

research_editor = Agent(
    role="Research Editor",
    goal="Verify historical accuracy and factual correctness",
    backstory="Academic historian with expertise in primary sources"
)

# 全エージェントが参加する合意形成タスク
review_task = Task(
    description="""Review article '{article_id}'. Engage in up to 3 rounds
    of discussion to reach consensus on ACCEPT/REJECT/REVISE.
    If no consensus after 3 rounds, majority vote decides.""",
    expected_output="Final decision with summary of reviews",
    agent=[senior_editor, content_editor, research_editor]
)

crew = Crew(agents=[senior_editor, content_editor, research_editor])


# ── A2Aプロトコルによるクロスフレームワーク通信 ──
from pydantic_ai import Agent as PydanticAgent

# PythonエージェントをA2Aで公開
agent = PydanticAgent("openai:gpt-4.1", ...)
app = agent.to_a2a()
# uvicorn agent_to_a2a:app --host 0.0.0.0 --port 8093

# TypeScript（Mastra）からPythonエージェントを呼び出す
# const a2a = new A2A({ serverUrl: "https://...server.com:8093" });
# const task = await a2a.sendTask({ ... });
```

**並列実行による壁時計時間削減**:

```python
import asyncio
from pydantic_ai import Agent

async def parallel_document_analysis(documents: list[str]) -> list[dict]:
    """複数ドキュメントを並列処理（直列の1/N時間）"""
    agent = Agent("anthropic:claude-sonnet-4-6")

    tasks = [
        agent.run(f"Analyze this document: {doc}")
        for doc in documents
    ]

    results = await asyncio.gather(*tasks)
    return [r.data for r in results]
```

### 注意事項・トレードオフ

**失敗モードの統計（2025年時点）**:

マルチエージェントシステムは40〜80%のタスクで失敗することが報告されている。主な原因:

| カテゴリ | 失敗パターン |
|---------|------------|
| **仕様の問題** | 曖昧なプロンプト、エージェントロールの不明確な定義、LLMの基本的制限 |
| **エージェント間の不整合** | 会話のリセット、重要情報の非共有、推論と行動の不一致 |
| **タスク検証の失敗** | エラーの未検出、早期終了、最終出力の品質不足 |

**設計原則**:

| 原則 | 詳細 |
|------|------|
| **シンプルさを優先** | 単一エージェントで対応可能なら、マルチエージェントにしない |
| **並列を優先** | エージェントをピア関係にして並列実行することでレイテンシを削減 |
| **ヒューマン・イン・ザ・ループ** | 複雑なコンフリクト解決にはヒューマンエージェントをプロキシとして組み込む |
| **エラー伝播に注意** | エージェントチェーンが長いほど、確率的に失敗率が上昇する |
| **非同期通信** | エージェント間の通信を非同期にしてオーバーヘッドを削減 |

**代替パターンとの比較**:
- P21 Tool Calling + P18 Reflection: 単一エージェントで十分なら複雑なマルチエージェントより安定
- P22 Code Execution: コード生成・実行のサブタスクをエージェントとして切り出す場合に組み合わせ
- P23 は P21・P22・P13・P18 のすべてを組み合わせた上位概念として位置づける

---

## パターン組み合わせ指針

| 組み合わせ | 効果 |
|-----------|------|
| P21 + P18 | ツール失敗時にエラーをLLMに戻して再試行（ReAct の基本形） |
| P22 + P18 | コード実行エラーをLLMに返して修正させる（最も実用的な組み合わせ） |
| P21 + P22 | ツール呼び出しでデータ取得し、コード生成でビジュアライズ |
| P23 + P21/P22 | マルチエージェントシステムの各エージェントがP21/P22を活用 |
| P21 + P13（CoT） | ReActパターン：推論→ツール呼び出し→推論→...の連鎖 |
