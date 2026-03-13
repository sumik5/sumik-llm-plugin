# 要約パターン: MapReduce・Refine・LangGraph移行

## 目次

1. [要約戦略の選択](#1-要約戦略の選択)
2. [MapReduce要約パターン](#2-mapreduce要約パターン)
3. [Refine要約パターン](#3-refine要約パターン)
4. [Web検索＋要約エンジン](#4-web検索要約エンジン)
5. [LangGraphへの移行パターン](#5-langgraphへの移行パターン)

---

## 1. 要約戦略の選択

### フローチャート

```
                 複数ドキュメント？
                 /              \
               はい              いいえ
               /                  \
 コンテキスト窓に収まる？         コンテキスト窓に収まる？
    /          \                   /          \
  はい         いいえ             はい         いいえ
Stuffプロンプト MapReduce/   Stuffプロンプト  MapReduce
              Refine
```

### 戦略比較表

| 戦略 | 処理方式 | 速度 | 品質 | 適した場面 |
|------|---------|-----|------|-----------|
| Stuff（直接） | 一括処理 | 高速 | 高 | コンテキスト窓内の短文書 |
| MapReduce | 並列→集約 | 高速 | 中（文脈分断あり） | 大規模文書・スループット優先 |
| Refine | 逐次精錬 | 低速 | 高（文脈保持） | 文脈連続性が重要な複数文書 |

---

## 2. MapReduce要約パターン

「分割→並列要約→集約」の2段階処理。並列実行でスループットを確保。

```python
from langchain_openai import ChatOpenAI
from langchain_text_splitters import TokenTextSplitter
from langchain_core.prompts import PromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnableLambda, RunnableParallel

llm = ChatOpenAI(model="gpt-4o-mini")

# Step 1: Splitチェーン
text_chunks_chain = RunnableLambda(
    lambda x: [
        {"chunk": chunk}
        for chunk in TokenTextSplitter(
            chunk_size=3000, chunk_overlap=100
        ).split_text(x)
    ]
)

# Step 2: Mapチェーン（各チャンクを並列要約）
map_prompt = PromptTemplate.from_template(
    "以下のテキストの主要点を含む簡潔な要約を作成してください。\n\nテキスト: {chunk}"
)
summarize_map_chain = RunnableParallel(
    {"summary": map_prompt | llm | StrOutputParser()}
)

# Step 3: Reduceチェーン（集約）
reduce_prompt = PromptTemplate.from_template(
    "複数の要約を結合したものを、主要点を含めて簡潔に要約してください。\n\nテキスト: {summaries}"
)
summarize_reduce_chain = (
    RunnableLambda(
        lambda x: {"summaries": "\n".join([i["summary"] for i in x])}
    )
    | reduce_prompt | llm | StrOutputParser()
)

# 統合Chain
map_reduce_chain = (
    text_chunks_chain           # 分割
    | summarize_map_chain.map() # 並列Map（各チャンクを並列処理）
    | summarize_reduce_chain    # Reduce集約
)

# 実行
with open("large_document.txt") as f:
    summary = map_reduce_chain.invoke(f.read())
```

---

## 3. Refine要約パターン

現在の要約に新しいドキュメントを逐次的に組み込む「精錬」方式。

```python
from langchain_core.prompts import PromptTemplate
from langchain_core.output_parsers import StrOutputParser

# 精錬チェーン定義
refine_template = """現在の要約と追加ドキュメントから最終的な要約を作成してください。

現在の要約:
{current_refined_summary}

追加ドキュメント:
{text}

追加情報が有用な場合のみ統合してください。"""

refine_chain = (
    PromptTemplate.from_template(refine_template)
    | llm | StrOutputParser()
)

def refine_summary(docs: list) -> dict:
    """複数ドキュメントを逐次精錬して最終要約を生成"""
    current_summary = ""
    for doc in docs:
        current_summary = refine_chain.invoke({
            "current_refined_summary": current_summary,
            "text": doc.page_content
        })
    return {"final_summary": current_summary}

# 複数ソースからドキュメント読み込み
from langchain.document_loaders import WikipediaLoader, PyPDFLoader, TextLoader

all_docs = (
    WikipediaLoader(query="LangChain", load_max_docs=2).load()
    + PyPDFLoader("reference.pdf").load()
    + TextLoader("notes.txt").load()
)
result = refine_summary(all_docs)
```

---

## 4. Web検索＋要約エンジン

複数のLCEL Chainを組み合わせた実践的なアーキテクチャ例。

### チェーン構成

```
Assistant Instructions chain  # 質問から適切なアシスタントを選択
        ↓
Web Searches chain             # 複数の検索クエリを生成
        ↓ .map()（並列）
Search and Summarization chain # 各クエリで検索→スクレイピング→要約
        ↓ .map()（並列）
Research Report chain          # 全要約を統合してレポート生成
```

### 実装の核心部分

```python
from langchain_core.runnables import RunnableLambda, RunnablePassthrough

# Web Searches Chain: アシスタント情報 → 検索クエリ生成
web_searches_chain = (
    RunnableLambda(lambda x: {
        "assistant_instructions": x["assistant_instructions"],
        "user_question": x["user_question"],
        "num_queries": 3,
    })
    | web_search_prompt | llm | StrOutputParser() | json_parser
)

# Search and Summarization Chain: クエリ → URL取得 → 並列スクレイピング → 集約
search_and_summarize_chain = (
    search_urls_chain                  # URLリスト取得
    | per_url_summarize_chain.map()    # 各URLを並列処理
    | RunnableLambda(lambda x: {
        "summary": "\n".join([i["summary"] for i in x]),
        "user_question": x[0]["user_question"] if x else "",
    })
)

# 統合 Web Research Chain
web_research_chain = (
    {"user_question": RunnablePassthrough()}
    | assistant_instructions_chain        # アシスタント選択
    | web_searches_chain                  # クエリ生成
    | search_and_summarize_chain.map()    # 各クエリを並列処理
    | aggregate_chain                     # 全要約を統合
    | report_prompt | llm | StrOutputParser()
)

report = web_research_chain.invoke("LangGraphの最新機能は何ですか？")
```

---

## 5. LangGraphへの移行パターン

LCEL Chainは線形処理向け。以下の場合はLangGraphへ移行する。

### 移行判断基準

| 限界 | 症状 | LangGraphの解決策 |
|------|------|-----------------|
| 状態管理なし | 中間データの受け渡しが複雑 | TypedDict State |
| 条件分岐困難 | 中間結果でフローを変えたい | add_conditional_edges |
| ループ処理 | 条件を満たすまで繰り返す | StateGraphのサイクル |
| デバッグ困難 | 失敗箇所が特定しにくい | ノード単位の分離 |

### Chain → StateGraphへの変換

```python
from langgraph.graph import StateGraph, END
from typing import TypedDict, Optional, List

# 状態定義（暗黙的なdict受け渡しを明示的TypedDictに変換）
class ResearchState(TypedDict):
    user_question: str
    assistant_info: Optional[dict]
    search_queries: Optional[List[dict]]
    search_summaries: Optional[List[dict]]
    final_report: Optional[str]
    should_regenerate: Optional[bool]
    iteration_count: Optional[int]

# 各Chainをノード関数に変換（単一責任）
def select_assistant(state: ResearchState) -> dict:
    result = assistant_instructions_chain.invoke(state["user_question"])
    return {"assistant_info": result}

def generate_queries(state: ResearchState) -> dict:
    queries = web_searches_chain.invoke(state["assistant_info"])
    return {"search_queries": queries}

def evaluate_relevance(state: ResearchState) -> dict:
    summaries = state.get("search_summaries", [])
    relevant = sum(1 for s in summaries if s.get("is_relevant"))
    should_regen = (relevant / len(summaries)) < 0.5 if summaries else True
    return {
        "should_regenerate": should_regen,
        "iteration_count": (state.get("iteration_count") or 0) + 1,
    }

# 条件ルーター（中間結果に基づく動的ルーティング）
def route_by_relevance(state: ResearchState) -> str:
    if state.get("should_regenerate") and (state.get("iteration_count") or 0) < 3:
        return "generate_queries"  # ループバック
    return "write_report"

# グラフ構築
graph = StateGraph(ResearchState)
graph.add_node("select_assistant", select_assistant)
graph.add_node("generate_queries", generate_queries)
graph.add_node("perform_searches", perform_searches_node)
graph.add_node("evaluate_relevance", evaluate_relevance)
graph.add_node("write_report", write_report_node)

graph.set_entry_point("select_assistant")
graph.add_edge("select_assistant", "generate_queries")
graph.add_edge("generate_queries", "perform_searches")
graph.add_edge("perform_searches", "evaluate_relevance")
graph.add_edge("write_report", END)
graph.add_conditional_edges(
    "evaluate_relevance",
    route_by_relevance,
    {"generate_queries": "generate_queries", "write_report": "write_report"}
)

app = graph.compile()
result = app.invoke({"user_question": "LangGraphとは？", "iteration_count": 0})
```

→ 高度なエージェント実装は `LANGGRAPH-AGENTS.md` を参照
