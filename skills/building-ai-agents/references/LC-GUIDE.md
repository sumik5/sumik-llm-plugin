# LangChain/LangGraph エージェント開発ガイド

## 目次

1. [LangChainエコシステムマップ](#1-langchainエコシステムマップ)
2. [開発フロー判断表](#2-開発フロー判断表)
3. [クイックスタート](#3-クイックスタート)
4. [LangSmithトレーシング設定](#4-langsmithトレーシング設定)
5. [モデル選択ガイド](#5-モデル選択ガイド)
6. [相互参照マップ](#6-相互参照マップ)
7. [各サブファイルナビゲーション](#7-各サブファイルナビゲーション)

---

## 1. LangChainエコシステムマップ

LangChainエコシステムは4つの主要コンポーネントで構成される:

```
┌─────────────────────────────────────────────────────────┐
│                    LangChain生態系                        │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │ LangChain    │  │  LangGraph   │  │  LangSmith    │ │
│  │ Core         │  │              │  │               │ │
│  │ - Document   │  │ - StateGraph │  │ - トレーシング │ │
│  │ - Retriever  │  │ - Node/Edge  │  │ - 評価        │ │
│  │ - Prompt     │  │ - Checkpoint │  │ - モニタリング│ │
│  │ - LLM/Chat   │  │ - Multi-Agent│  │               │ │
│  │ - LCEL       │  │              │  │               │ │
│  └──────────────┘  └──────────────┘  └───────────────┘ │
│                                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │ LangServe（本番デプロイ: REST API化）               │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### コンポーネントの役割

| コンポーネント | 役割 | 主な用途 |
|--------------|------|---------|
| LangChain Core | 基本構成要素（Document, Prompt, LLM, LCEL） | Chain構築・RAGパイプライン |
| LangGraph | グラフ型ステートフルエージェント | 複雑なワークフロー・マルチエージェント |
| LangSmith | 可観測性・評価プラットフォーム | デバッグ・監視・品質評価 |
| LangServe | FastAPI統合によるデプロイ | 本番REST APIサービング |

---

## 2. 開発フロー判断表

### ユースケース別推奨アーキテクチャ

| ユースケース | 推奨アーキテクチャ | 理由 |
|------------|------------------|------|
| 単純な要約・分類 | LCEL Chain | 線形処理で十分。シンプルで保守しやすい |
| 大規模文書要約 | LCEL + MapReduce | 並列処理による効率化 |
| 複数ドキュメント要約 | LCEL + Refine | 文脈の連続性を保持 |
| Q&A チャットボット | LCEL + RAG | ベクトル検索 + 生成 |
| 高度RAG（精度改善） | LCEL + 高度インデキシング | クエリ変換・フィルタリング |
| 分岐条件付きワークフロー | LangGraph StateGraph | 条件分岐・ループが必要 |
| ツール呼び出しエージェント | LangGraph + ToolNode | 動的ツール選択 |
| マルチエージェント | LangGraph + Router/Supervisor | 複数専門エージェント協調 |
| MCP統合 | LangGraph + load_mcp_tools | MCPサーバーのツール消費 |
| 本番化 | + LangSmith + Checkpoint | 監視・メモリ・ガードレール |

### AskUserQuestion: アーキテクチャ選択

判断が必要な場合は以下を確認する:

```python
# ユースケースのパターンが不明確な場合
AskUserQuestion([
    {
        "question": "このユースケースの要件を確認します",
        "header": "アーキテクチャ選択",
        "options": [
            {"label": "LCEL Chain（決定的な処理フロー）",
             "description": "固定された処理ステップのシーケンス"},
            {"label": "LangGraph StateGraph（動的フロー）",
             "description": "条件分岐・ループ・ツール呼び出しが必要"},
            {"label": "マルチエージェント（複数専門エージェント）",
             "description": "複数のエージェントが協調して作業"}
        ]
    }
])
```

---

## 3. クイックスタート

### 環境構築

```python
# 必要なパッケージのインストール
# pip install langchain langchain-openai langchain-community langgraph langsmith

import os
from langchain_openai import ChatOpenAI

# APIキーの設定（環境変数推奨）
os.environ["OPENAI_API_KEY"] = "your-api-key"

# LLMクライアントの初期化
llm = ChatOpenAI(model_name="gpt-4o-mini")
```

### 最小LCEL Chain

```python
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

# プロンプトテンプレートの定義
prompt = ChatPromptTemplate.from_messages([
    ("system", "あなたは親切なアシスタントです。"),
    ("human", "{question}")
])

# Chain合成（pipe演算子で接続）
chain = prompt | llm | StrOutputParser()

# 実行
result = chain.invoke({"question": "LangChainとは何ですか？"})
```

### 最小LangGraph StateGraph

```python
from langgraph.graph import StateGraph, END
from typing import TypedDict

# 状態の定義
class MyState(TypedDict):
    question: str
    answer: str

# ノード関数
def process(state: MyState) -> dict:
    response = llm.invoke(state["question"])
    return {"answer": response.content}

# グラフの構築
graph = StateGraph(MyState)
graph.add_node("process", process)
graph.set_entry_point("process")
graph.add_edge("process", END)

# コンパイルと実行
app = graph.compile()
result = app.invoke({"question": "LangGraphとは？", "answer": ""})
```

### 最小RAG Pipeline

```python
from langchain_community.vectorstores import Chroma
from langchain_openai import OpenAIEmbeddings
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnablePassthrough

# ベクトルストアの作成
embeddings = OpenAIEmbeddings()
vectorstore = Chroma.from_texts(
    ["LangChainはLLMアプリ構築フレームワーク"],
    embeddings
)
retriever = vectorstore.as_retriever()

# RAG Chain
prompt = ChatPromptTemplate.from_template(
    "Context: {context}\n\nQuestion: {question}"
)
rag_chain = (
    {"context": retriever, "question": RunnablePassthrough()}
    | prompt
    | llm
    | StrOutputParser()
)
result = rag_chain.invoke("LangChainとは？")
```

---

## 4. LangSmithトレーシング設定

```python
import os

# LangSmithトレーシングの有効化
os.environ["LANGCHAIN_TRACING_V2"] = "true"
os.environ["LANGCHAIN_API_KEY"] = "your-langsmith-api-key"
os.environ["LANGCHAIN_PROJECT"] = "my-project"

# 上記設定後は、すべてのLangChain/LangGraph呼び出しが
# 自動的にLangSmithに記録される
```

### LangSmithでできること

| 機能 | 説明 |
|------|------|
| トレーシング | Chain/Agent実行の全ステップを可視化 |
| 評価 | LLM出力の品質を自動評価 |
| データセット管理 | テストケースの作成・管理 |
| プロンプトHub | プロンプトテンプレートの共有・バージョン管理 |
| モニタリング | 本番環境での実行統計・エラー検知 |

---

## 5. モデル選択ガイド

### ユースケース別モデル選択

| ユースケース | 推奨モデル | 理由 |
|------------|----------|------|
| 高速・低コスト処理 | gpt-4o-mini / claude-haiku | 速度とコストを優先 |
| 複雑な推論 | gpt-4o / claude-sonnet | 精度を優先 |
| コード生成 | gpt-4o / claude-opus | 高精度が必要 |
| 大量文書処理 | gpt-4o-mini（並列） | コスト効率を重視 |
| エージェント（ツール呼び出し） | gpt-4o / claude-sonnet | Function calling精度 |

### マルチモデル戦略

1つのワークフロー内で用途に応じてモデルを使い分けることが効果的:

```python
# 例: 用途別モデル使い分け
fast_llm = ChatOpenAI(model="gpt-4o-mini")   # 高速・低コスト処理
main_llm = ChatOpenAI(model="gpt-4o")         # 複雑な推論
code_llm = ChatAnthropic(model="claude-opus") # コード生成

# ルーターチェーンでモデルを切り替え
router_chain = classify_prompt | fast_llm   # まず分類
answer_chain = main_llm                     # 回答生成
```

### プロバイダー別統合

```python
# OpenAI
from langchain_openai import ChatOpenAI
llm = ChatOpenAI(model="gpt-4o")

# Anthropic Claude
from langchain_anthropic import ChatAnthropic
llm = ChatAnthropic(model="claude-sonnet-4-5")

# Google Gemini
from langchain_google_genai import ChatGoogleGenerativeAI
llm = ChatGoogleGenerativeAI(model="gemini-2.0-flash")

# ローカルLLM（Ollama）
from langchain_ollama import ChatOllama
llm = ChatOllama(model="llama3.1")
```

---

## 6. 相互参照マップ

### このスキルの範囲と関連スキル

| 内容 | このスキル（LangChain実装） | 参照先スキル |
|------|--------------------------|------------|
| RAG設計理論・戦略 | → `building-rag-systems` | 汎用RAGアーキテクチャ理論 |
| JavaScript/Vercel AI SDK | → `integrating-ai-web-apps` | JS実装はこちら |
| MCPプロトコル仕様 | → `developing-mcp` | プロトコル詳細・サーバー設計 |
| Google ADKエージェント | → `building-adk-agents` | ADK固有の実装 |

### LangChain実装の差別化

このスキルでは以下に特化する:
- **Python + LangChain/LangGraphの具体的実装コード**
- **LCELパイプラインの組み立てパターン**
- **StateGraphによるエージェントの設計と実装**
- **LangChain固有のRAGコンポーネント（ChromaDB, Retriever等）**

---

## 7. 各サブファイルナビゲーション

### どのファイルを読むか

```
やりたいこと → 読むべきファイル

プロンプト・Chain基礎を学ぶ
→ references/LANGCHAIN-CORE.md

文書要約を実装する
→ references/SUMMARIZATION.md

RAGシステムを構築する
→ references/RAG-PIPELINE.md

エージェントを構築する
→ references/LANGGRAPH-AGENTS.md

MCPサーバーと連携する
→ references/MCP-INTEGRATION.md

本番環境に対応する
→ references/PRODUCTION.md
```

### 学習パス

**初心者向け（順番に読む）:**
1. このINSTRUCTIONS.md → 全体像の把握
2. `LANGCHAIN-CORE.md` → LCEL/Chain/Promptの基礎
3. `SUMMARIZATION.md` → 実践的なChain実装
4. `RAG-PIPELINE.md` → RAGパイプライン構築
5. `LANGGRAPH-AGENTS.md` → エージェント開発

**経験者向け（用途別）:**
- RAGの精度改善 → `RAG-PIPELINE.md` の高度インデキシング・クエリ変換セクション
- エージェント設計 → `LANGGRAPH-AGENTS.md` のRouter/Supervisorパターン
- 本番化 → `PRODUCTION.md` のMemory・Guardrailsセクション
- MCP統合 → `MCP-INTEGRATION.md`
