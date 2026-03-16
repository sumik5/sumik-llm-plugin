# RAG基礎パターン（P6–P8）

> RAG（Retrieval-Augmented Generation）の基本原理から大規模運用まで。「知識をいつ・どこで統合するか」の設計判断を扱う。実装詳細（チャンキング・ベクトルDB設定）は `building-rag-systems` スキルを参照。

---

## 目次

- [Pattern 6: Basic RAG](#pattern-6-basic-rag)
- [Pattern 7: Semantic Indexing](#pattern-7-semantic-indexing)
- [Pattern 8: Indexing at Scale](#pattern-8-indexing-at-scale)
- [パターン比較まとめ](#パターン比較まとめ)

---

## Pattern 6: Basic RAG

### 問題

基盤モデルは学習時のカットオフ日以降の情報を知らず、社内専有データや個人情報にアクセスできない。また、誤った情報を「自信満々に」生成する（幻覚）傾向がある。モデルを再学習するのはコストが非常に高く（数百万〜数億ドル）、頻繁なデータ更新には対応できない。

**RAGが解決する5つの問題**：
- 静的な知識カットオフ
- モデルのキャパシティ制限
- 非公開・専有データへのアクセス不能
- 幻覚による不正確な回答
- 引用・出典の欠如

### 解決策

**グラウンディング**：関連する外部知識をプロンプトのコンテキストに注入し、LLMがその情報を優先的に使って回答を生成するよう誘導する。LLMはプロンプト内の情報を学習済み知識より優先的に参照する（プライミング効果）。

RAGは2つのパイプラインで構成される：
1. **インデックスパイプライン**（事前実行）: 知識ソース → チャンク分割 → インデックス保存
2. **Q&Aパイプライン**（リアルタイム）: クエリ → 関連チャンク検索 → コンテキスト付きで生成

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| データが頻繁に更新される（日次・週次） | ✅ RAG（再学習不要） |
| 社内専有・機密データに基づく回答が必要 | ✅ RAG |
| 回答に出典・引用を付けたい | ✅ RAG |
| データ量が少なく変化しない | ⬜ Fine-tuningまたはプロンプトに直接埋め込みを検討 |
| プロトタイプ・小規模データ（〜10万件） | ✅ Basic RAG（シンプルなBM25検索で開始） |

### 実装のポイント

**インデックスパイプライン**（LlamaIndex使用）：

```python
from llama_index.core import Document
from llama_index.core.node_parser import SentenceSplitter
from llama_index.core.storage.docstore import SimpleDocumentStore
import re
import time

def build_index(text: str, source_url: str) -> SimpleDocumentStore:
    # 余分な空白を除去してDocument化
    content = re.sub(r'\n{3,}', '\n\n', text.strip())
    document = Document(
        text=content,
        metadata={
            "source": source_url,
            "date_loaded": time.strftime("%Y-%m-%d %H:%M:%S")
        }
    )

    # 文単位でチャンク分割（overlap=20でコンテキスト断絶を防ぐ）
    node_parser = SentenceSplitter(chunk_size=200, chunk_overlap=20)
    nodes = node_parser.get_nodes_from_documents([document])

    # ドキュメントストアに保存
    docstore = SimpleDocumentStore()
    docstore.add_documents(nodes)
    return docstore
```

**検索パイプライン**（BM25 + 生成）：

```python
from llama_index.retrievers.bm25 import BM25Retriever
from llama_index.core.llms import ChatMessage
import anthropic

def query_rag(query: str, docstore: SimpleDocumentStore) -> dict:
    # BM25による関連チャンク検索（上位5件）
    retriever = BM25Retriever.from_defaults(
        docstore=docstore,
        similarity_top_k=5
    )
    retrieved_nodes = retriever.retrieve(query)

    # 関連チャンクをコンテキストとしてプロンプトに注入
    messages = [
        ChatMessage(
            role="system",
            content="以下の信頼できる情報を使って質問に答えてください。"
        )
    ]
    # コンテキスト（検索結果）を追加
    for node in retrieved_nodes:
        messages.append(ChatMessage(role="system", content=node.text))
    # ユーザーの質問を追加
    messages.append(ChatMessage(role="user", content=query))

    # LLMで生成
    client = anthropic.Anthropic()
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[{"role": m.role, "content": m.content} for m in messages]
    )

    return {
        "answer": response.content[0].text,
        "sources": [node.metadata.get("source") for node in retrieved_nodes]
    }
```

**プライミング効果の確認**（コンテキスト注入の基本原理）：

```python
# プライミング：コンテキスト情報がLLMの回答を支配する
prompt_without_context = "ヨーロッパの小都市を3つ提案してください。"
# → ランダムな都市が返る

prompt_with_context = """フランスで最も美食の街はリヨンです。
ヨーロッパの小都市を3つ提案してください。"""
# → グルメ都市が返る（プライミング効果）
```

### 注意事項・トレードオフ

| 側面 | 内容 |
|------|------|
| **BM25の限界** | キーワード一致に依存するため、同義語・言い換えに弱い → P7 Semantic Indexingで解決 |
| **チャンクサイズ** | 小さすぎ（50文字以下）→文脈不足、大きすぎ（1000文字以上）→コンテキスト汚染 |
| **RAGは幻覚を減らすが除去しない** | 関連チャンクが見つからない場合、モデルは学習済み知識に戻る |
| **K値（検索件数）** | 多すぎるとコンテキスト長を消費し、ノイズが増える。5〜10件が一般的 |
| **プロダクション要件** | 大規模データ・データ鮮度・矛盾情報 → P8 Indexing at Scale |

---

## Pattern 7: Semantic Indexing

### 問題

BM25などのキーワードベース検索（P6）は、自然言語テキスト・画像・テーブルなど多様なコンテンツタイプに対して根本的な限界がある：

- **シノニム問題**: 「automobile」と「car」は意味が同じでも異なるキーワードとして扱われる
- **多義語問題**: 「fluid」は日常語（液体）と物理学用語（液体と気体の総称）で意味が異なる
- **マルチモーダル**: 画像・動画・表はキーワード検索の対象外
- **ドメイン横断**: 複数のドメインにまたがるクエリは単一キーワードで表現できない

### 解決策

テキストの「意味」をベクトル（embedding）として表現し、ベクトル間の類似度で検索する。Semantic Indexingは2つのアプローチで構成される：

1. **意味論的チャンキング**: 段落・節・テーマの区切りなど意味的な単位でチャンク分割
2. **Embeddingによるインデックス**: 各チャンクをベクトルDBに格納し、クエリとの意味的類似度で検索

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| 同義語・言い換えを含むクエリが多い | ✅ Semantic Indexing |
| 画像・表・動画などマルチモーダルデータを含む | ✅ Semantic Indexing（マルチモーダルembedding） |
| 専門用語が多い（ドメイン固有語彙） | ✅ Semantic Indexing（Fine-tuned embedding） |
| シンプルなキーワード検索で十分な検索精度 | ⬜ Basic RAG（P6）で十分 |
| 大規模データ（100万件超） | ✅ + P8 Indexing at Scale を組み合わせ |

### 実装のポイント

**意味論的チャンキング**：

```python
from llama_index.core.node_parser import SemanticSplitterNodeParser
from llama_index.embeddings.openai import OpenAIEmbedding

# 意味論的チャンキング：意味の変化点でチャンクを分割
embed_model = OpenAIEmbedding()
splitter = SemanticSplitterNodeParser(
    buffer_size=1,              # 前後の文を考慮するバッファ
    breakpoint_percentile_threshold=95,  # 意味変化の閾値（高いほど細かく分割）
    embed_model=embed_model
)
nodes = splitter.get_nodes_from_documents([document])
```

**Embeddingインデックスの構築**（ChromaDB使用）：

```python
import chromadb
from sentence_transformers import SentenceTransformer

# Embeddingモデル（MTEB leaderboardで評価して選択）
model = SentenceTransformer("all-MiniLM-L6-v2")  # 軽量版
# プロダクション向け: "Qwen2-7B" や Gemini Embeddings を検討

# ChromaDBにEmbeddingを保存
client = chromadb.Client()
collection = client.create_collection("knowledge_base")

def index_documents(chunks: list[dict]):
    """chunks: [{"id": str, "text": str, "metadata": dict}]"""
    texts = [c["text"] for c in chunks]
    embeddings = model.encode(texts).tolist()

    collection.add(
        ids=[c["id"] for c in chunks],
        embeddings=embeddings,
        documents=texts,
        metadatas=[c["metadata"] for c in chunks]
    )
```

**意味論的検索（Semantic Retrieval）**：

```python
def semantic_search(query: str, top_k: int = 5) -> list[dict]:
    """クエリとの意味的類似度で上位K件を検索"""
    query_embedding = model.encode([query]).tolist()
    results = collection.query(
        query_embeddings=query_embedding,
        n_results=top_k
    )

    return [
        {
            "text": doc,
            "metadata": meta,
            "distance": dist
        }
        for doc, meta, dist in zip(
            results["documents"][0],
            results["metadatas"][0],
            results["distances"][0]
        )
    ]
```

**ハイブリッド検索**（BM25 + Semantic の組み合わせ）：

```python
def hybrid_search(query: str, top_k: int = 5) -> list[dict]:
    """
    BM25（キーワード一致）とSemantic（意味）を組み合わせたハイブリッド検索
    RRF（Reciprocal Rank Fusion）でスコアを統合
    """
    bm25_results = bm25_retriever.retrieve(query)
    semantic_results = semantic_search(query, top_k=top_k * 2)

    # RRFでスコアを統合（k=60は一般的なデフォルト値）
    scores = {}
    k = 60
    for rank, result in enumerate(bm25_results):
        node_id = result.node.node_id
        scores[node_id] = scores.get(node_id, 0) + 1 / (k + rank + 1)

    for rank, result in enumerate(semantic_results):
        node_id = result["metadata"].get("id")
        scores[node_id] = scores.get(node_id, 0) + 1 / (k + rank + 1)

    # スコア降順でソートして上位K件を返す
    sorted_ids = sorted(scores.keys(), key=lambda x: scores[x], reverse=True)
    return sorted_ids[:top_k]
```

### 注意事項・トレードオフ

| 側面 | 内容 |
|------|------|
| **Embeddingモデルの選択** | MTEB leaderboardで評価。Gemini Embeddings（総合1位）、Qwen2（3位・OSSで制御可能） |
| **コスト** | BM25より計算コストが高い（インデックス構築時のembedding生成） |
| **ハイブリッド検索が最良** | BM25（精確なキーワード一致）+ Semantic（意味類似）の組み合わせが最も高精度 |
| **チャンクサイズの影響** | 意味論的チャンキングは段落・節単位で分割するため、BM25向けの固定サイズチャンクより長くなる傾向 |
| **大規模運用の課題** | モデルライフサイクル問題（Embeddingモデルの廃止）が生じる → P8 Indexing at Scale |

---

## Pattern 8: Indexing at Scale

### 問題

プロダクション環境でRAGを運用すると、PoC（概念実証）では現れない複数の課題が時間経過とともに現れる：

**1. 曖昧さ（Disambiguation）**
知識ベースが大きくなるほど、同一単語が複数の意味で使われるようになる（例：「fluid」は日常語では液体、物理学では液体と気体の総称）。ドメインを特定せずに検索すると、意図しないコンテキストの文書が返る。

**2. データ鮮度（Data Freshness）**
医療・法律・技術ドキュメントは頻繁に更新される。古い情報が新しい情報と混在し、時間によって矛盾する回答が返るようになる（例：CDCのCOVID隔離ガイドラインは2020〜2024年で3回変更された）。

**3. 矛盾情報（Contradictory Information）**
異なる時期・異なる権威機関からの相矛盾する情報が同一インデックスに蓄積される（例：高血圧の定義は2017年に140/90 mm Hgから130/80 mm Hgに変更された）。

**4. モデルライフサイクル（Model Lifecycle）**
Embeddingモデルが廃止されると、全ドキュメントの再インデックスが必要になる。日本の特許データだけで年間35万件以上（毎日約1000件）、数百万チャンクにもなる。

### 解決策

**メタデータ**が4つの課題すべての解決鍵となる。適切なメタデータを設計し、検索時のフィルタリング・ランキング・矛盾検出に活用する。

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| データが10万件を超える | ✅ Indexing at Scale |
| データが時間とともに更新される | ✅ Indexing at Scale（データ鮮度管理） |
| 複数の権威機関・ソースからデータを収集 | ✅ Indexing at Scale（矛盾情報検出） |
| プロプライエタリなEmbeddingモデルに依存 | ✅ Indexing at Scale（モデルライフサイクル管理） |
| PoC・小規模データ（〜10万件）で固定データ | ⬜ Basic RAG（P6）で十分 |

### 実装のポイント

**メタデータの設計**：

```python
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

@dataclass
class ChunkMetadata:
    # ドキュメントレベルメタデータ
    source_url: str           # 出典URL
    document_id: str          # ドキュメントID
    author: Optional[str]     # 著者
    domain: str               # ドメイン（"medical", "legal", "finance"等）
    created_at: datetime      # 作成日時
    updated_at: datetime      # 更新日時
    reading_level: Optional[str]  # 読解レベル

    # チャンクレベルメタデータ
    chunk_position: int       # ドキュメント内の位置
    semantic_role: str        # 役割（"definition", "example", "conclusion"）

    # 信頼性メタデータ
    authority_level: int      # 権威性スコア（1-5）
    version: Optional[str]    # バージョン

    # アクセス制御メタデータ
    access_roles: list[str]   # アクセス可能ロール
    is_confidential: bool     # 機密フラグ
```

**メタデータ付きインデックス構築**：

```python
import chromadb
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("all-MiniLM-L6-v2")
client = chromadb.Client()
collection = client.create_collection("knowledge_base_v2")

documents = [
    {
        "id": "doc_001",
        "text": "Medication A is recommended as first-line therapy...",
        "source": "National Health Guidelines",
        "created_at": "2023-03-01",
        "domain": "medical",
        "authority_level": 5
    },
    # ...
]

metadata_list = []
for doc in documents:
    meta = {
        "source": doc["source"],
        "created_at": doc["created_at"],
        "domain": doc["domain"],
        "authority_level": doc["authority_level"]
    }
    metadata_list.append(meta)

# Embeddingとメタデータを一緒にインデックス
embeddings = model.encode([d["text"] for d in documents]).tolist()
collection.add(
    ids=[d["id"] for d in documents],
    embeddings=embeddings,
    documents=[d["text"] for d in documents],
    metadatas=metadata_list
)
```

**メタデータフィルタリングによる検索**（矛盾情報・データ鮮度の解決）：

```python
def metadata_filtered_search(
    query: str,
    domain: Optional[str] = None,
    after_date: Optional[str] = None,
    min_authority: int = 1,
    top_k: int = 5
) -> list[dict]:
    """
    メタデータフィルタリングによる精度の高い検索
    """
    query_embedding = model.encode([query]).tolist()

    # WHERE条件の構築（ChromaDB構文）
    where_conditions = []
    if domain:
        where_conditions.append({"domain": {"$eq": domain}})
    if after_date:
        where_conditions.append({"created_at": {"$gte": after_date}})
    if min_authority > 1:
        where_conditions.append({"authority_level": {"$gte": min_authority}})

    if len(where_conditions) > 1:
        where = {"$and": where_conditions}
    elif len(where_conditions) == 1:
        where = where_conditions[0]
    else:
        where = None

    results = collection.query(
        query_embeddings=query_embedding,
        n_results=top_k,
        where=where  # メタデータフィルタ
    )

    return [
        {
            "text": doc,
            "metadata": meta,
            "distance": dist
        }
        for doc, meta, dist in zip(
            results["documents"][0],
            results["metadatas"][0],
            results["distances"][0]
        )
    ]

# 使用例：医療ドメインの2024年以降のコンテンツのみ検索
results = metadata_filtered_search(
    query="What is the recommended treatment for condition X?",
    domain="medical",
    after_date="2024-01-01",
    min_authority=4
)
```

**矛盾情報の検出と解決**：

```python
def detect_and_resolve_contradictions(
    retrieved_chunks: list[dict]
) -> tuple[list[dict], list[dict]]:
    """
    検索結果から矛盾するチャンクを検出し、最新・高権威のものを優先する
    Returns: (resolved_chunks, contradictions_log)
    """
    # ドメインとトピックでグループ化
    domain_groups = {}
    for chunk in retrieved_chunks:
        domain = chunk["metadata"].get("domain", "unknown")
        domain_groups.setdefault(domain, []).append(chunk)

    resolved = []
    contradictions = []

    for domain, chunks in domain_groups.items():
        if len(chunks) <= 1:
            resolved.extend(chunks)
            continue

        # 矛盾の記録
        dates = [c["metadata"].get("created_at") for c in chunks]
        if len(set(dates)) > 1:
            contradictions.append({
                "domain": domain,
                "chunks": chunks,
                "resolution_method": "temporal_preference"
            })

        # 解決策1: 最新の情報を優先
        most_recent = max(chunks, key=lambda c: c["metadata"].get("created_at", ""))

        # 解決策2: 権威性スコアが高い方を優先（同日の場合）
        # most_authoritative = max(chunks, key=lambda c: c["metadata"].get("authority_level", 0))

        resolved.append(most_recent)

    return resolved, contradictions
```

**モデルライフサイクル管理**：

```python
class EmbeddingModelManager:
    """
    Embeddingモデルのバージョン管理と段階的な再インデックス
    """
    def __init__(self, collection, current_model_name: str):
        self.collection = collection
        self.current_model_name = current_model_name
        self.model = SentenceTransformer(current_model_name)

    def incremental_reindex(
        self,
        new_model_name: str,
        batch_size: int = 100
    ):
        """
        モデル変更時の段階的再インデックス
        全件一括再インデックスを避け、バッチ処理で計算コストを分散
        """
        new_model = SentenceTransformer(new_model_name)

        # 既存のドキュメントを取得
        existing = self.collection.get()
        total = len(existing["ids"])

        for i in range(0, total, batch_size):
            batch_ids = existing["ids"][i:i+batch_size]
            batch_docs = existing["documents"][i:i+batch_size]
            batch_meta = existing["metadatas"][i:i+batch_size]

            # 新しいモデルでembedding再生成
            new_embeddings = new_model.encode(batch_docs).tolist()

            # 更新（削除→再追加）
            self.collection.delete(ids=batch_ids)
            self.collection.add(
                ids=batch_ids,
                embeddings=new_embeddings,
                documents=batch_docs,
                metadatas=batch_meta
            )

        self.current_model_name = new_model_name
        self.model = new_model
```

**古いコンテンツの管理（3戦略）**：

```python
class ContentLifecycleManager:
    """データ鮮度管理の3戦略"""

    def retrieval_filtering(self, query: str, days_limit: int = 365):
        """戦略1: 検索時にフィルタリング（古いコンテンツを無視）"""
        cutoff = (datetime.now() - timedelta(days=days_limit)).strftime("%Y-%m-%d")
        return metadata_filtered_search(query, after_date=cutoff)

    def document_store_pruning(self, days_limit: int = 730):
        """戦略2: ドキュメントストアから古いコンテンツを削除（最高のパフォーマンス）"""
        cutoff = (datetime.now() - timedelta(days=days_limit)).strftime("%Y-%m-%d")
        old_docs = collection.get(where={"created_at": {"$lt": cutoff}})
        if old_docs["ids"]:
            collection.delete(ids=old_docs["ids"])

    def result_reranking(self, retrieved_chunks: list[dict]) -> list[dict]:
        """戦略3: 検索後に新しい・権威あるコンテンツを上位に再ランキング"""
        def recency_score(chunk: dict) -> float:
            date_str = chunk["metadata"].get("created_at", "2000-01-01")
            date = datetime.strptime(date_str, "%Y-%m-%d")
            days_old = (datetime.now() - date).days
            return 1.0 / (1 + days_old / 365)  # 1年ごとにスコアが半減

        return sorted(
            retrieved_chunks,
            key=lambda c: recency_score(c) * c["metadata"].get("authority_level", 1),
            reverse=True
        )
```

### 注意事項・トレードオフ

| 側面 | 内容 |
|------|------|
| **メタデータ品質が全て** | 不正確・不完全なメタデータではフィルタリングが機能しない |
| **バイナリフィルタの限界** | 一部のベクトルDBはtag有無のみサポート（連続値フィルタは性能ペナルティあり） |
| **時間フィルタの罠** | 日付が新しいだけで内容が信頼できるとは限らない（2020年の論文が2025年より正確なこともある） |
| **ドメイン特化インデックス** | 超大規模データでは単一インデックスのフィルタより、ドメイン別インデックスへのルーティングが高速 |
| **インクリメンタルインデックス** | 全件再インデックスより差分更新（追加・修正のみ）で計算コストを削減 |
| **Embeddingモデル選定** | MTEB leaderboardを参照。オープンウェイトモデル（Qwen2等）はライフサイクル管理が容易 |

---

## パターン比較まとめ

| パターン | 主な課題 | 特徴 | 推奨スタート |
|---------|---------|------|-------------|
| P6 Basic RAG | 知識カットオフ・専有データ | BM25 + 生成の基本パイプライン | 全RAGプロジェクトの出発点 |
| P7 Semantic Indexing | キーワード一致の限界 | Embedding + 意味論的チャンキング | P6の品質が不十分な場合 |
| P8 Indexing at Scale | データ鮮度・矛盾・モデル廃止 | メタデータ駆動の運用管理 | 10万件超 or 更新頻度が高い場合 |

**RAG発展フロー**：

```
小規模データ・PoC
    ↓
Basic RAG（P6）: BM25検索 + 生成
    ↓ キーワード一致の限界に達したら
Semantic Indexing（P7）: Embedding + Hybrid Search
    ↓ 運用規模が大きくなったら
Indexing at Scale（P8）: メタデータ + ライフサイクル管理
    ↓ さらに高品質が必要な場合
Advanced RAG（P9-P12）: Index-Aware Retrieval, Node Postprocessing等
```

**検索精度向上の優先順位**：
1. チャンクサイズとオーバーラップの調整（最も影響大）
2. Semantic Indexingへの移行（BM25からembedding）
3. Hybrid Search（BM25 + Semantic の組み合わせ）
4. メタデータフィルタリングの導入
5. Result Reranking

> **`building-rag-systems`スキルとの差別化**: 本パターンは「どのRAGアーキテクチャを選ぶか」の設計判断に焦点。チャンキング戦略の詳細・ベクトルDB設定・embedding次元数の選択などの実装詳細は `building-rag-systems` を参照。
