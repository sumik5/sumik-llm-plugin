# RAG パイプライン実装ガイド

LangChain + ChromaDB による RAG システムの実装（インジェスト → 検索 → 生成）を網羅する。
汎用RAG理論の詳細は `building-rag-systems` を参照。ここではLangChain固有の実装パターンに特化する。

---

## 目次

1. [RAGの基本概念](#1-ragの基本概念)
2. [コンテンツインジェスト（インデキシング）](#2-コンテンツインジェスト（インデキシング）)
3. [基礎RAGパイプライン](#3-基礎ragパイプライン)
4. [チャットメモリ統合](#4-チャットメモリ統合)
5. [高度インデキシング戦略](#5-高度インデキシング戦略)
6. [クエリ変換5パターン](#6-クエリ変換5パターン)
7. [クエリルーティング](#7-クエリルーティング)
8. [検索後処理（リランキング）](#8-検索後処理（リランキング）)
9. [ユースケース別判断テーブル](#9-ユースケース別判断テーブル)

---

## 1. RAGの基本概念

### セマンティック検索とRAGの関係

RAG（Retrieval-Augmented Generation）は、Q&Aチャットボットを構築するための定番設計パターン。
キーワードマッチではなく**意味的類似性**でドキュメントを検索し、LLMが回答を生成する。

**RAGの2ステージ:**

```
Stage 1: インジェスト（インデキシング）
  ドキュメント → テキスト抽出 → チャンク分割 → エンベディング生成 → ベクトルDB格納

Stage 2: Q&A（検索と生成）
  ユーザー質問 → エンベディング変換 → 類似検索 → チャンク取得 → プロンプト作成 → LLM → 回答
```

### ChromaDBの基本操作

```python
import chromadb

# インメモリクライアント（セッション終了でデータ消失）
chroma_client = chromadb.Client()

# 永続化クライアント
client = chromadb.PersistentClient(path="./chroma_db")

# HTTPクライアント（別ホスト）
client = chromadb.HttpClient(host="http://localhost", port=8010)

# コレクション作成・操作
collection = chroma_client.create_collection("my_collection")

# ドキュメント追加（Chromaがエンベディングを自動生成）
collection.add(
    documents=["テキスト1", "テキスト2"],
    metadatas=[{"source": "url1"}, {"source": "url2"}],
    ids=["id-01", "id-02"]
)

# セマンティック検索
results = collection.query(
    query_texts=["検索クエリ"],
    n_results=3
)
```

---

## 2. コンテンツインジェスト（インデキシング）

### LangChainのドキュメントローダー

```python
from langchain_community.document_loaders import AsyncHtmlLoader
from langchain_community.document_transformers import Html2TextTransformer
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_chroma import Chroma
from langchain_openai import OpenAIEmbeddings

# Webページ読み込み
loader = AsyncHtmlLoader(["https://example.com/page1", "https://example.com/page2"])
docs = loader.load()

# HTML → テキスト変換
transformer = Html2TextTransformer()
text_docs = transformer.transform_documents(docs)

# テキスト分割（チャンク化）
splitter = RecursiveCharacterTextSplitter(
    chunk_size=1024,
    chunk_overlap=128
)
chunks = splitter.split_documents(text_docs)

# Chromaベクトルストアに格納
vectorstore = Chroma.from_documents(
    chunks,
    embedding=OpenAIEmbeddings()
)

# リトリーバーとして使用
retriever = vectorstore.as_retriever()
```

### 主要なドキュメントローダー

| ローダー | 用途 | パッケージ |
|---------|------|----------|
| `AsyncHtmlLoader` | Webページ（非同期） | `langchain_community` |
| `PyPDFLoader` | PDFファイル | `langchain_community` |
| `TextLoader` | テキストファイル | `langchain_community` |
| `WikipediaLoader` | Wikipedia記事 | `langchain_community` |
| `DirectoryLoader` | ディレクトリ一括読み込み | `langchain_community` |

---

## 3. 基礎RAGパイプライン

### LangChainを使ったRAGチェーン

```python
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough

llm = ChatOpenAI(model="gpt-4o-mini")

# RAGプロンプトテンプレート
rag_prompt = ChatPromptTemplate.from_template("""
質問と文脈が与えられます。文脈のみを使用して質問に答えてください。
答えがわからない場合は「わかりません」と答えてください。

文脈: {context}
質問: {question}
""")

# RAGチェーン（LCEL）
rag_chain = (
    {
        "context": retriever,
        "question": RunnablePassthrough()
    }
    | rag_prompt
    | llm
    | StrOutputParser()
)

# 実行
answer = rag_chain.invoke("コーンウォールでおすすめの活動は？")
```

### Q&Aワークフローの流れ

```
1. ユーザー質問 → Retriever へ送信
2. Retriever → Embeddings でクエリをベクトル化
3. ベクトルストアで類似チャンク検索
4. 取得チャンク + 質問 → PromptTemplate でプロンプト構築
5. プロンプト → LLM → 回答生成
```

---

## 4. チャットメモリ統合

会話履歴を保持するチャットボットの構築。

```python
from langchain_community.chat_message_histories import ChatMessageHistory
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder

# チャット履歴管理
chat_history = ChatMessageHistory()

# 会話対応プロンプト
chat_rag_prompt = ChatPromptTemplate.from_messages([
    ("system", "あなたは親切なアシスタントです。文脈のみを使用して回答してください。\n\n文脈: {context}"),
    MessagesPlaceholder(variable_name="chat_history"),
    ("human", "{question}")
])

# 会話対応RAGチェーン
def execute_chat_chain(chain, question):
    chat_history.add_user_message(question)
    answer = chain.invoke({
        "question": question,
        "chat_history": chat_history.messages
    })
    chat_history.add_ai_message(answer)
    return answer
```

### ChatMessageHistoryの主要メソッド

| メソッド | 用途 |
|---------|------|
| `add_user_message(msg)` | ユーザーメッセージ追加 |
| `add_ai_message(msg)` | AI回答追加 |
| `messages` | 全メッセージ取得 |
| `clear()` | 履歴クリア |

---

## 5. 高度インデキシング戦略

### 5.1 チャンク分割戦略

#### HTMLヘッダー分割

```python
from langchain_text_splitters import HTMLSectionSplitter

headers_to_split_on = [("h1", "Header 1"), ("h2", "Header 2")]
splitter = HTMLSectionSplitter(headers_to_split_on=headers_to_split_on)

# HTML文字列を直接分割
chunks = splitter.split_text(html_string)

# H2セクションのみ保持（フィルタリング）
h2_chunks = [c for c in chunks if "Header 2" in c.metadata]
```

#### セマンティック分割

```python
from langchain_experimental.text_splitter import SemanticChunker
from langchain_openai import OpenAIEmbeddings

# 意味的境界で分割（エンベディングAPIコールが必要）
semantic_splitter = SemanticChunker(
    embeddings=OpenAIEmbeddings(),
    breakpoint_threshold_type="percentile"
)
chunks = semantic_splitter.split_documents(docs)
```

### 5.2 ParentDocumentRetriever（親子インデキシング）

小さなチャンクで検索し、大きなコンテキストを返す戦略。

```python
from langchain.retrievers import ParentDocumentRetriever
from langchain.storage import InMemoryByteStore
from langchain_chroma import Chroma
from langchain_openai import OpenAIEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter

# 細粒度チャンク（検索用）
child_splitter = RecursiveCharacterTextSplitter(chunk_size=200)

# 粗粒度チャンク（コンテキスト用）
parent_splitter = RecursiveCharacterTextSplitter(chunk_size=2000)

# 子チャンクを格納するベクトルストア
child_vectorstore = Chroma(
    collection_name="child_chunks",
    embedding_function=OpenAIEmbeddings()
)

# 親チャンクを格納するドキュメントストア
doc_store = InMemoryByteStore()

# ParentDocumentRetriever設定
retriever = ParentDocumentRetriever(
    vectorstore=child_vectorstore,
    docstore=doc_store,
    child_splitter=child_splitter,
    parent_splitter=parent_splitter
)

# ドキュメントをインジェスト
retriever.add_documents(docs)
```

**動作原理:** 子チャンク（200文字）のエンベディングで検索 → 親チャンク（2000文字）を返す

### 5.3 MultiVectorRetriever（複数エンベディング戦略）

#### 要約エンベディング

```python
from langchain.retrievers.multi_vector import MultiVectorRetriever
from langchain.storage import InMemoryByteStore
import uuid

# 要約生成チェーン
summarize_chain = (
    {"doc": lambda x: x.page_content}
    | ChatPromptTemplate.from_template("以下のドキュメントを100文字で要約してください:\n\n{doc}")
    | llm
    | StrOutputParser()
)

# MultiVectorRetriever設定
retriever = MultiVectorRetriever(
    vectorstore=Chroma(embedding_function=OpenAIEmbeddings()),
    byte_store=InMemoryByteStore()
)
doc_key = "doc_id"

# 要約とIDを生成
doc_ids = [str(uuid.uuid4()) for _ in docs]
summaries = summarize_chain.batch(docs)

# 要約をベクトルストアに格納
summary_docs = [
    Document(page_content=s, metadata={doc_key: doc_ids[i]})
    for i, s in enumerate(summaries)
]
retriever.vectorstore.add_documents(summary_docs)

# 元ドキュメントをドキュメントストアに格納
retriever.docstore.mset(list(zip(doc_ids, docs)))
```

#### 仮説的質問エンベディング（HyDE）

```python
# 仮説的質問生成チェーン（コンテンツごとに想定される質問を生成）
hypothetical_q_chain = (
    {"doc": lambda x: x.page_content}
    | ChatPromptTemplate.from_template(
        "以下のドキュメントに対する可能性のある質問を3つ生成してください:\n\n{doc}"
    )
    | llm
    | StrOutputParser()
    | (lambda x: x.strip().split("\n"))
)
```

**各戦略の比較:**

| 戦略 | インデキシング対象 | 特徴 |
|------|----------------|------|
| 直接検索 | チャンクそのまま | シンプル、基本的なユースケース向け |
| ParentDocument | 子チャンク → 親チャンク返却 | 詳細検索 + リッチなコンテキスト |
| 要約エンベディング | 要約 → 原文返却 | 広いトピックカバレッジ |
| 仮説的質問 | 想定Q → 原文返却 | クエリ意図との高いアライメント |
| チャンク展開 | 隣接チャンクを含めて返却 | 連続性・文脈の保持 |

---

## 6. クエリ変換5パターン

### ユーザー確認の原則（AskUserQuestion）

クエリ変換戦略の選択は、ユースケースによって異なる。
実装前にユーザーに確認すること:

- 検索精度の問題がクエリの質によるものか、インデキシングによるものか
- どのクエリ変換パターンが要件に最も合致するか
- クエリ変換のコスト（追加LLM呼び出し）が許容可能か

### 6.1 Rewrite-Retrieve-Read（クエリ書き換え）

ユーザーの質問をベクトルストア検索に最適な形に書き換える。

```python
from langchain_core.runnables import RunnablePassthrough

# クエリ書き換えプロンプト
rewriter_prompt = ChatPromptTemplate.from_template("""
ChromaDBベクトルストアへのセマンティック検索を改善するため、
ユーザーの質問をより正確なクエリに書き換えてください。
書き換えたクエリのみを引用符付きで返してください。

ユーザーの質問: {user_question}
書き換えたクエリ:
""")

rewriter_chain = rewriter_prompt | llm | StrOutputParser()

# Rewrite-Retrieve-Read RAGチェーン
rag_chain = (
    {
        # コンテキスト: 書き換えたクエリでRetriever検索
        "context": {"user_question": RunnablePassthrough()}
                   | rewriter_chain | retriever,
        # 質問: 元のユーザー質問（回答生成に使用）
        "question": RunnablePassthrough(),
    }
    | rag_prompt
    | llm
    | StrOutputParser()
)
```

**使用場面:** ユーザーが自然言語で質問するが、ベクトルストアのコンテンツと表現が異なる場合

### 6.2 Multi-Query（複数クエリ生成）

異なる観点から複数のクエリを生成し、検索範囲を広げる。

```python
from langchain.retrievers.multi_query import MultiQueryRetriever

# 複数クエリ用リトリーバー（LLMが自動でクエリを複数生成）
multi_query_retriever = MultiQueryRetriever.from_llm(
    retriever=base_retriever,
    llm=llm
)

# または独自プロンプトで制御
from langchain.output_parsers import LineListOutputParser

multi_query_prompt = ChatPromptTemplate.from_template("""
ユーザーの質問に対して、異なる観点から3つの類似した質問を生成してください。

ユーザーの質問: {question}
改良された質問（1行ずつ):
""")

generate_queries = multi_query_prompt | llm | LineListOutputParser()

# 全クエリで検索し、ユニークなドキュメントを取得
def retrieve_unique(question):
    queries = generate_queries.invoke({"question": question})
    all_docs = []
    for q in queries:
        all_docs.extend(retriever.invoke(q))
    return list({doc.page_content: doc for doc in all_docs}.values())
```

**使用場面:** 複雑な質問や、単一クエリでは関連コンテンツを見落とす可能性がある場合

### 6.3 Step-back Question（抽象化クエリ）

詳細な質問から抽象的な質問を生成し、より広いコンテキストを取得する。

```python
# ステップバック質問生成プロンプト
step_back_prompt = ChatPromptTemplate.from_template("""
あなたは与えられた質問をより広い視点から捉え直すエキスパートです。
以下の詳細な質問を、より一般的・抽象的な質問に変換してください。

例:
質問: コーンウォールのニューキーにある特定のサーフビーチは？
抽象的な質問: コーンウォールのサーフィン環境の全般的な状況は？

元の質問: {question}
抽象的な質問:
""")

step_back_chain = step_back_prompt | llm | StrOutputParser()

# ステップバック + 元質問の組み合わせRAG
rag_chain = (
    {
        "context": {"question": RunnablePassthrough()}
                   | step_back_chain | retriever,
        "question": RunnablePassthrough(),
    }
    | rag_prompt | llm | StrOutputParser()
)
```

**使用場面:** 非常に具体的な質問で、小さなチャンクでは答えが見つからない場合

### 6.4 HyDE（Hypothetical Document Embedding）

ユーザーの質問に対する仮想的な回答を生成し、それをエンベディングして検索する。

```python
# 仮想的ドキュメント生成プロンプト
hyde_prompt = ChatPromptTemplate.from_template("""
以下の質問に対する典型的な回答を、ドキュメントの一節として生成してください。
実際の情報でなくても構いません。

質問: {question}
仮想的なドキュメント:
""")

hyde_chain = hyde_prompt | llm | StrOutputParser()

# HyDE RAGチェーン（仮想ドキュメントで検索）
rag_chain = (
    {
        "context": {"question": RunnablePassthrough()}
                   | hyde_chain | retriever,
        "question": RunnablePassthrough(),
    }
    | rag_prompt | llm | StrOutputParser()
)
```

**使用場面:** 質問とドキュメントコンテンツの表現に大きな差がある場合

### 6.5 Query Decomposition（クエリ分解）

複雑な質問を複数の単純な質問に分解して段階的に答える。

```python
from langchain.output_parsers import NumberedListOutputParser

# 質問分解プロンプト
decompose_prompt = ChatPromptTemplate.from_template("""
以下の複雑な質問を、独立して回答できる単純な質問に分解してください。

複雑な質問: {question}
単純な質問のリスト:
""")

decompose_chain = decompose_prompt | llm | NumberedListOutputParser()

# 各サブ質問を検索・回答し、最終的に統合
def decompose_and_answer(question):
    sub_questions = decompose_chain.invoke({"question": question})
    sub_answers = []
    for sub_q in sub_questions:
        docs = retriever.invoke(sub_q)
        context = "\n---\n".join([d.page_content for d in docs])
        answer = llm.invoke(f"質問: {sub_q}\n文脈: {context}")
        sub_answers.append(f"Q: {sub_q}\nA: {answer.content}")

    # 最終統合
    return llm.invoke(f"元の質問: {question}\n\nサブ回答:\n" + "\n\n".join(sub_answers))
```

**使用場面:** 複数のステップや情報源を要する複合的な質問

---

## 7. クエリルーティング

### 7.1 Self-querying（メタデータフィルタリング）

LLMがクエリからメタデータフィルターを自動生成する。

```python
from langchain.retrievers.self_query.base import SelfQueryRetriever
from langchain.chains.query_constructor.base import AttributeInfo

# メタデータ属性の定義
metadata_field_info = [
    AttributeInfo(name="source", description="ドキュメントのURL", type="string"),
    AttributeInfo(name="date", description="公開日（YYYY-MM-DD形式）", type="string"),
    AttributeInfo(name="category", description="カテゴリ（travel/accommodation/weather）", type="string"),
]

# Self-queryingリトリーバー
self_query_retriever = SelfQueryRetriever.from_llm(
    llm=llm,
    vectorstore=vectorstore,
    document_contents="旅行ガイドのコンテンツ",
    metadata_field_info=metadata_field_info,
)

# 使用例: LLMが自動でフィルターを生成
# "2024年以降のコーンウォール旅行情報" → category=travel, date >= "2024-01-01"
docs = self_query_retriever.invoke("2024年以降のコーンウォール旅行情報")
```

### 7.2 Semantic Router（LLMによるルーティング）

クエリの内容によって異なるリトリーバーや処理ルートに振り分ける。

```python
from pydantic import BaseModel, Field
from langchain_core.output_parsers import PydanticOutputParser
from enum import Enum

class DataSource(str, Enum):
    vector_store = "vector_store"
    sql_database = "sql_database"
    graph_database = "graph_database"

class RouterOutput(BaseModel):
    source: DataSource = Field(description="クエリに最適なデータソース")

# LLMによるルーティング
router_llm = llm.with_structured_output(RouterOutput)

router_prompt = ChatPromptTemplate.from_template("""
以下のクエリを分類し、最適なデータソースを選択してください:
- vector_store: 旅行先の説明、観光スポット、一般情報
- sql_database: 宿泊施設の空室状況、価格、予約情報
- graph_database: 場所間の関係、ルート、連結性

クエリ: {query}
""")

router_chain = router_prompt | router_llm

def route_query(query):
    result = router_chain.invoke({"query": query})
    if result.source == DataSource.vector_store:
        return vector_retriever.invoke(query)
    elif result.source == DataSource.sql_database:
        return sql_chain.invoke(query)
    else:
        return graph_chain.invoke(query)
```

---

## 8. 検索後処理（リランキング）

### 8.1 RAG Fusion（複数クエリ + RRF）

複数クエリで検索した結果を Reciprocal Rank Fusion でマージする。

```python
def reciprocal_rank_fusion(results_list: list[list], k: int = 60):
    """複数の検索結果リストをRRFでマージ"""
    scores: dict[str, float] = {}
    doc_map: dict[str, Document] = {}

    for results in results_list:
        for rank, doc in enumerate(results):
            doc_id = doc.page_content
            if doc_id not in scores:
                scores[doc_id] = 0
                doc_map[doc_id] = doc
            scores[doc_id] += 1 / (rank + k)

    # スコア降順でソート
    reranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return [doc_map[doc_id] for doc_id, _ in reranked]

# RAG Fusionリトリーバー
def rag_fusion_retrieve(question: str) -> list[Document]:
    queries = generate_queries.invoke({"question": question})
    all_results = [retriever.invoke(q) for q in queries]
    return reciprocal_rank_fusion(all_results)

# RAG Fusionチェーンへの統合
rag_fusion_chain = (
    {
        "context": {"question": RunnablePassthrough()} | rag_fusion_retrieve,
        "question": RunnablePassthrough(),
    }
    | rag_prompt | llm | StrOutputParser()
)
```

### 8.2 BM25ハイブリッド検索

セマンティック検索（Dense）とキーワード検索（Sparse/BM25）を組み合わせる。

```python
from langchain.retrievers import BM25Retriever, EnsembleRetriever

# BM25リトリーバー（キーワード検索）
bm25_retriever = BM25Retriever.from_documents(docs)
bm25_retriever.k = 5

# セマンティックリトリーバー
semantic_retriever = vectorstore.as_retriever(search_kwargs={"k": 5})

# ハイブリッドリトリーバー（RRFで自動マージ）
hybrid_retriever = EnsembleRetriever(
    retrievers=[bm25_retriever, semantic_retriever],
    weights=[0.5, 0.5]
)
```

---

## 9. ユースケース別判断テーブル

### インデキシング戦略の選択

| ユースケース | 推奨戦略 | 理由 |
|-----------|---------|------|
| 単純なFAQシステム | 基礎RAG | シンプルで十分 |
| 長文ドキュメント検索 | ParentDocumentRetriever | 詳細検索 + 豊富なコンテキスト |
| 多様なコンテンツ（テーブル含む） | MultiVector + 要約 | 構造化・非構造化を統一的に扱う |
| 意図ベースの検索 | 仮説的質問エンベディング | ユーザー意図との高いアライメント |
| 構造化データ + テキスト混在 | Self-querying + メタデータ | フィルタリングによる精度向上 |

### クエリ変換戦略の選択

| 問題 | 推奨変換 | 効果 |
|-----|---------|------|
| 質問が曖昧または口語的 | Rewrite-Retrieve-Read | 検索クエリを最適化 |
| 単一検索で見落としが多い | Multi-Query | カバレッジ拡大 |
| 詳細すぎてコンテキスト不足 | Step-back | 抽象化による関連コンテンツ取得 |
| 質問とドキュメント表現のギャップ | HyDE | エンベディング空間での整合性向上 |
| 複合的・多ステップな質問 | Decomposition | 段階的な回答積み上げ |

### コスト vs 精度トレードオフ

| 戦略 | 追加LLM呼び出し | 精度向上 | 推奨用途 |
|------|--------------|---------|---------|
| 基礎RAG | 0回 | ベースライン | プロトタイプ、シンプルなユースケース |
| Rewrite | 1回 | 中 | 口語的な質問が多い場合 |
| Multi-Query | 1回 | 中〜高 | カバレッジが重要な場合 |
| Step-back | 1回 | 中 | 詳細な質問が多い場合 |
| HyDE | 1回 | 中〜高 | ドメイン特化コンテンツ |
| RAG Fusion | 複数回 | 高 | 最高精度が求められる本番環境 |

---

**関連ファイル:**
- → 汎用RAG理論・データローディング・チャンキング戦略は `building-rag-systems` 参照
- → LangGraphエージェント統合は `LANGGRAPH-AGENTS.md` 参照
- → 本番化・メモリ・ガードレールは `PRODUCTION.md` 参照
