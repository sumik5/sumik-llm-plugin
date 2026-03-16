# RAG応用パターン（Advanced RAG）

> 単純なベクトル検索の限界を超えるための4パターン。検索品質・後処理・信頼性・深化探索の各課題に対応する。

## 目次

- [Pattern 9: Index-Aware Retrieval](#pattern-9-index-aware-retrieval)
- [Pattern 10: Node Postprocessing](#pattern-10-node-postprocessing)
- [Pattern 11: Trustworthy Generation](#pattern-11-trustworthy-generation)
- [Pattern 12: Deep Search](#pattern-12-deep-search)

---

## Pattern 9: Index-Aware Retrieval

### 問題

セマンティック検索（embedding類似度）はユーザーのクエリとチャンクの意味が一致する場合にのみ機能する。以下の4ケースで失敗する：

1. **質問がナレッジベースに存在しない**：ドキュメントは「トレドは高速鉄道でマドリードから1時間未満」と記述しているが、ユーザーは「マドリードから2時間圏内の観光地は？」と質問する
2. **専門用語の乖離**：ユーザーは「イスラム宮殿」と質問するが、ドキュメントは「ナスル朝の要塞」と記述している
3. **細部がチャンクに埋もれている**：長い段落の中の細部はチャンク全体のembeddingに反映されない
4. **全体的解釈が必要**：複数チャンクの論理的組み合わせが必要な質問

### 解決策

Index-Aware Retrieval は以下の4コンポーネントを組み合わせ、セマンティック検索の鶏・卵問題を解決する：

1. **仮想回答（HyDE）**：クエリではなく「もしも回答がこうなら」という仮想回答でチャンクを検索
2. **クエリ展開**：クエリをLLMで文脈補足・同義語追加してから検索
3. **ハイブリッド検索**：BM25（キーワード）とベクトル検索を組み合わせてスコアリング
4. **GraphRAG**：ドキュメントをグラフDBにノードとして格納し関連チャンクを辿る

### 適用判断基準

| 条件 | 推奨コンポーネント |
|------|------------------|
| ユーザークエリが専門外の言葉で書かれる | HyDE + クエリ展開 |
| ドキュメントが技術用語中心 | クエリ展開（同義語変換） |
| キーワード検索と意味検索を両立したい | ハイブリッド検索 |
| チャンク間の関係性が重要（組織図、法律体系など） | GraphRAG |
| シンプルなセマンティックRAGで十分 | P7 Semantic Indexing を先に試す |

### 実装のポイント

**HyDE（仮想ドキュメント埋め込み）**

```python
def create_hypothetical_answer(llm, question: str) -> str:
    """クエリに対する仮想回答を生成してembeddingに使用"""
    messages = [
        {"role": "system", "content": "以下の質問に2-3文で回答してください。不明な場合は推測してください。"},
        {"role": "user", "content": question}
    ]
    return llm.chat(messages)

def hyde_rag(llm, index, question: str) -> str:
    hypothetical = create_hypothetical_answer(llm, question)
    # 仮想回答でチャンクを検索し、実際の回答生成に使用
    return semantic_rag(index, hypothetical)
```

**クエリ展開**

```python
def expand_query(llm, question: str, domain_context: str) -> str:
    """ドメイン文脈に基づいてクエリを展開"""
    prompt = f"""
{domain_context}
以下の質問を、ドメイン固有の専門用語・同義語・文脈情報を補足して展開してください。
質問のみ返してください。

質問: {question}
"""
    return llm.chat([{"role": "user", "content": prompt}])
```

**ハイブリッド検索（LlamaIndex）**

```python
# alpha=0.0: 純粋BM25, alpha=1.0: 純粋ベクトル検索
query_engine = index.as_query_engine(
    vector_store_query_mode="hybrid",
    similarity_top_k=5,
    alpha=0.5  # BM25とベクトル検索を50%ずつ
)
```

**GraphRAG（LangChain + Neo4j）**

```python
from langchain_experimental.graph_transformers import LLMGraphTransformer

# テキストからエンティティグラフを自動構築
llm_transformer = LLMGraphTransformer(llm=llm)
graph_documents = llm_transformer.convert_to_graph_documents(documents)

graph_store = Neo4jGraphStore(url=..., username=..., password=...)
graph_store.write_graph(graph_documents)

# グラフ関係を使った検索
retriever = KnowledgeGraphRAGRetriever(storage_context=storage_context)
```

### 注意事項・トレードオフ

| 観点 | 内容 |
|------|------|
| **HyDEの限界** | LLMがドメインを知らない場合、仮想回答がハルシネーションを含み誤ったチャンクを引き込む |
| **クエリ展開の副作用** | ユーザーの意図を過剰解釈し、無関係なチャンクを引き込む可能性 |
| **GraphRAGコスト** | グラフDB構築に時間と費用がかかる。小規模データセットへの過剰投資に注意 |
| **複合利用** | HyDE + クエリ展開 + ハイブリッド検索を組み合わせることで効果が高まるが、レイテンシも増加 |
| **代替パターン** | P10 Node Postprocessingと組み合わせると検索後の精度もさらに向上 |

---

## Pattern 10: Node Postprocessing

### 問題

RAGシステムは「クエリに類似したチャンク」を検索するが、類似性と関連性は別物である。以下の問題が発生する：

- **類似 ≠ 関連**：地質学の教科書の目次がグランドキャニオンに関するクエリにマッチする
- **不要情報の混入**：正解を含むチャンクでも、質問に無関係な情報が多く含まれる
- **エンティティ曖昧性**：「Newcastle」に対しイギリスと米国ペンシルベニアの2つが混在
- **古い・矛盾する情報**：複数バージョンのドキュメントが混在
- **回答の汎用性**：すべてのユーザーに同じ回答を返し、パーソナライズができない

### 解決策

検索と生成の間に後処理ステップを挿入し、チャンクの品質を向上させる。

- **リランキング**：LLMで各チャンクの「関連性スコア」を計算し上位チャンクのみ使用
- **ハイブリッド検索統合**：BM25とベクトル検索の結果を統合してリランカーに渡す
- **コンテキスト圧縮**：チャンクから質問に関連する部分のみを抽出・圧縮
- **曖昧性検出**：同じエンティティ名の異なる実体を検出しユーザーに確認
- **陳腐情報フィルタリング**：メタデータ（日付・バージョン）で古い情報を除外
- **パーソナライズ**：ユーザー属性・過去の会話履歴をコンテキストに追加

### 適用判断基準

| 条件 | 推奨手法 |
|------|---------|
| 検索結果の精度が低い（無関係チャンクが多い） | リランキング |
| チャンクが長く生成LLMへの負荷が大きい | コンテキスト圧縮 |
| 多義的なクエリ（地名・人名の重複など） | 曖昧性検出 |
| 更新頻度の高いナレッジベース | 陳腐情報フィルタリング |
| ユーザーごとに異なる回答が必要 | パーソナライズ |
| コスト・レイテンシを最小化したい | 後処理なし（P6 Basic RAGを先に試す） |

### 実装のポイント

**リランキング + コンテキスト圧縮（一体化）**

```python
from pydantic import BaseModel
from pydantic_ai import Agent

class ProcessedChunk(BaseModel):
    relevant_text: str        # 関連部分のみ抽出
    relevance_score: float    # 0.0-1.0の関連性スコア

def process_node(llm, query: str, chunk_text: str) -> ProcessedChunk:
    """チャンクから関連部分を抽出しスコアリング（1回のLLM呼び出しで統合）"""
    system_prompt = """
クエリと本文を受け取り:
1. クエリへの回答に不要な情報を本文から除去してください
2. 関連性スコアを0.0-1.0で評価してください（1.0=質問への直接回答が含まれる）
"""
    agent = Agent(llm, result_type=ProcessedChunk, system_prompt=system_prompt)
    return agent.run_sync(f"**クエリ**: {query}\n**本文**: {chunk_text}").data

def postprocess_nodes(llm, query: str, nodes: list, top_k: int = 3) -> list:
    processed = [process_node(llm, query, node.text) for node in nodes]
    # スコアで降順ソート、top_k件のみ返す
    sorted_nodes = sorted(
        zip(nodes, processed),
        key=lambda x: x[1].relevance_score,
        reverse=True
    )
    return [(node, proc) for node, proc in sorted_nodes[:top_k] if proc.relevance_score > 0.3]
```

**曖昧性検出**

```python
from pydantic import BaseModel

class AmbiguityResult(BaseModel):
    is_ambiguous: bool
    ambiguous_term: str
    entity_1: str
    entity_2: str

def detect_ambiguity(llm, query: str, chunk1_text: str, chunk2_text: str) -> AmbiguityResult:
    """2チャンクが同一エンティティを指しているか判定"""
    agent = Agent(llm, result_type=AmbiguityResult)
    return agent.run_sync(
        f"クエリ: {query}\n本文1: {chunk1_text}\n本文2: {chunk2_text}"
    ).data

# N-1回の比較で十分（全ペアは不要）
def check_ambiguities(llm, query: str, nodes: list) -> list[AmbiguityResult]:
    ambiguities = []
    for node in nodes[1:]:
        result = detect_ambiguity(llm, query, nodes[0].text, node.text)
        if result.is_ambiguous:
            ambiguities.append(result)
    return ambiguities
```

**BGEリランカー（fine-tuned専用モデル）**

```python
# Pinecone経由でBGEリランカーを使用（ローカル実行不要）
reranked = pc.inference.rerank(
    model="bge-reranker-v2-m3",
    query=query,
    documents=[{"text": node.text} for node in nodes],
    top_n=3,
    return_documents=True,
)
```

### 注意事項・トレードオフ

| 観点 | 内容 |
|------|------|
| **コスト増加** | リランキングは各チャンクにLLM呼び出しが必要。N件のチャンクにN回のAPI呼び出し |
| **レイテンシ** | 埋め込みは事前計算だが、リランキングは推論時実行。RAGの応答時間が増加 |
| **複数処理の統合** | コンテキスト圧縮・曖昧性検出・リランキングを1回のLLM呼び出しにまとめることで削減可能 |
| **BGE vs 汎用LLM** | BGEは高速・安価だが単一タスク。複数後処理を同時に行うなら汎用LLMが適切 |
| **P9との連携** | HyDE/クエリ展開（P9）で取得したチャンクをさらにNode Postprocessingで精製すると高品質 |

---

## Pattern 11: Trustworthy Generation

### 問題

RAGシステムでも以下の信頼性問題は回避できない：

- **検索失敗**：ナレッジベースに情報がない、または無関係なドキュメントを取得
- **コンテキスト信頼性**：取得したドキュメント自体が古い・偏っている・不正確
- **推論エラー**：取得情報を誤解釈・組み合わせ、誤った回答を生成
- **ハルシネーション**：チャンクを超えた情報を生成したり、チャンクを誤って組み合わせる

医療・法律・金融などの高リスクドメインでは、これらの問題がユーザーの意思決定に直接影響する。

### 解決策

信頼性を構造的に高める複数の手法を組み合わせる：

1. **ドメイン外検出**：ナレッジベースの範囲外のクエリを事前に弾く
2. **引用（Citations）**：回答にソース情報を付与する（ソース追跡・分類ベース・トークンレベル）
3. **RAGパイプライン全体のガードレール**：前処理・検索・後処理・生成の各段階でチェック

### 適用判断基準

| 条件 | 推奨手法 |
|------|---------|
| 高リスクドメイン（医療・法律・金融） | フル実装（検出 + 引用 + ガードレール） |
| ナレッジベースのスコープが明確 | ドメイン外検出のみでも効果大 |
| ユーザーが情報の出典を確認したい | 引用付き回答（ソース追跡） |
| 精密な引用制御が必要 | 分類ベース引用（common知識は引用なし） |
| シンプルな内部ツール | Basic RAGで十分な場合も多い |

### 実装のポイント

**ドメイン外検出（3手法の組み合わせ）**

```python
from dataclasses import dataclass

@dataclass
class DomainCheckResult:
    is_in_domain: bool
    confidence: float
    method: str  # "embedding", "classifier", "keyword"

def check_domain_by_embedding(query: str, index, threshold: float = 0.5) -> DomainCheckResult:
    """ナレッジベース内チャンクとの類似度で判定"""
    query_embedding = embed(query)
    top_similarities = index.search(query_embedding, top_k=5)
    max_similarity = max(s.score for s in top_similarities)
    return DomainCheckResult(
        is_in_domain=max_similarity > threshold,
        confidence=max_similarity,
        method="embedding"
    )

def check_domain_by_classifier(llm, query: str, domain_categories: list[str]) -> DomainCheckResult:
    """ゼロショット分類でカテゴリ判定"""
    # domain_categories例: ["医療情報", "その他"]
    result = llm.classify(query, categories=domain_categories)
    return DomainCheckResult(
        is_in_domain=result.category != "その他",
        confidence=result.confidence,
        method="classifier"
    )
```

**引用付き回答（ソース追跡）**

```python
def generate_with_citations(llm, query: str, chunks_with_metadata: list) -> str:
    """チャンクのメタデータを使って引用付きで回答生成"""
    context = "\n\n".join([
        f"[出典{i+1}: {c['metadata']['source']}, {c['metadata']['date']}]\n{c['text']}"
        for i, c in enumerate(chunks_with_metadata)
    ])
    prompt = f"""以下の情報源を参考に質問に回答してください。
回答中で使用した情報には必ず[出典N]の形式で引用を付けてください。

{context}

質問: {query}"""
    return llm.chat([{"role": "user", "content": prompt}])
```

**RAGパイプライン全体のガードレール**

```python
class RAGPipeline:
    def query(self, user_query: str, user_context: dict) -> str:
        # 1. 前処理ガードレール
        if not self.is_in_domain(user_query):
            return "この質問はサポート範囲外です"
        sanitized_query = self.sanitize_input(user_query)  # インジェクション防止

        # 2. 検索とポスト処理
        chunks = self.retrieve(sanitized_query)
        fresh_chunks = self.filter_stale(chunks, max_age_days=180)  # 古いチャンク除外
        reranked = self.rerank(sanitized_query, fresh_chunks)

        # 3. 生成前ガードレール
        clean_chunks = self.check_privacy(reranked)  # PII除去
        diverse_chunks = self.ensure_source_diversity(clean_chunks, min_sources=2)

        # 4. 生成と後処理ガードレール
        response = self.generate(sanitized_query, diverse_chunks)
        if not self.fact_check(response, diverse_chunks):
            response = self.regenerate_conservative(sanitized_query, diverse_chunks)

        return response
```

### 注意事項・トレードオフ

| 観点 | 内容 |
|------|------|
| **過剰引用** | ソース追跡方式はすべての文に引用が付き読みにくくなる。分類ベースの方が自然 |
| **トークンレベル帰属** | 最も精密だが研究段階。現時点で本番利用可能な実装はまだない |
| **ガードレールのコスト** | 各チェックはLLM呼び出しを伴う。全段階に適用するとコスト・レイテンシが急増 |
| **偽陰性のリスク** | ドメイン外検出の閾値を厳しくすると、有効な質問まで弾く可能性 |
| **P12との連携** | Deep Search（P12）ではこのパターンの信頼性手法を各イテレーションに組み込む |

---

## Pattern 12: Deep Search

### 問題

単純なRAGシステムは以下の複雑なクエリに対応できない：

- **コンテキストウィンドウ制約**：「気候変動緩和策の経済的影響を先進国・途上国で比較せよ」のような多次元クエリは1回の検索で完結しない
- **クエリ曖昧性**：「Newcastle の石炭地層の特徴は？」— イングランドか米国ペンシルベニアか
- **情報の陳腐化・検証不足**：プレインデックス情報の鮮度チェック機構がない
- **浅い推論**：文書に明示的に書かれた情報のみを組み合わせ、推論チェーンを構築できない
- **マルチホップクエリ**：「MITの最新量子機械学習論文のアルゴリズムに適した言語は？」— 論文特定→アルゴリズム理解→言語判断の複数ステップが必要

### 解決策

検索・思考・生成のイテレーティブループを導入し、各反復で情報ギャップを特定しながら段階的に深化する：

1. **クエリ分解**：複雑なクエリをサブクエリに分解
2. **検索**：ハイブリッド検索 + 外部ツール（検索エンジン・企業API）を活用
3. **思考ステップ**：取得情報を評価し、情報ギャップがあれば次のサブクエリを生成
4. **状態管理**：各イテレーションの知見を蓄積し最終回答を合成
5. **評価**：品質スコアが閾値を超えるかコスト上限に達するまで繰り返す

Deep Research（長文レポート生成）はDeep Searchの出力形式を変えたバリアントとして扱う。

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| 複数ドキュメントにまたがる複雑な質問 | Deep Search を検討 |
| 段階的な情報収集が必要（マルチホップ） | Deep Search が有効 |
| リアルタイム情報が必要 | Deep Search + 外部検索ツール |
| シンプルな事実照会 | P6 Basic RAG または P9 Index-Aware Retrieval |
| レイテンシ制約が厳しい | Deep Search は不向き（複数回のLLM呼び出し） |
| コスト予算が限られている | Deep Search は最終手段として使用 |

### 実装のポイント

**反復的な情報ギャップ検出**

```python
from pydantic_ai import Agent

def get_next_queries(llm, original_query: str, sub_queries: list[str], synthesis: str) -> list[str]:
    """現在の回答の論理的・情報的ギャップを特定し次のサブクエリを返す"""
    prompt = f"""
元のクエリ、これまでのサブクエリ、現在の回答を基に情報ギャップを判定してください。
回答が完全なら空リストを返してください。ギャップがある場合は最大3つの検索クエリを返してください。

**元クエリ**: {original_query}
**サブクエリ履歴**: {sub_queries}
**現在の回答**: {synthesis}
"""
    agent = Agent(llm, result_type=list[str])
    return agent.run_sync(prompt).data

def deep_search(llm, retriever, query: str, max_iterations: int = 5, min_score: float = 0.8) -> str:
    """Deep Searchのメインループ"""
    state = {"context": "", "sub_queries": [], "current_answer": ""}

    for iteration in range(max_iterations):
        # 現在の状態から次のクエリを取得
        if iteration == 0:
            current_queries = [query]
        else:
            current_queries = get_next_queries(
                llm, query, state["sub_queries"], state["current_answer"]
            )
            if not current_queries:
                break  # ギャップなし、完成

        # 各サブクエリで検索・統合
        for sub_query in current_queries:
            chunks = retriever.retrieve(sub_query)
            state["context"] += f"\n[サブクエリ: {sub_query}]\n" + "\n".join(c.text for c in chunks)
            state["sub_queries"].append(sub_query)

        # 現時点の回答を合成
        state["current_answer"] = synthesize(llm, query, state["context"])

        # 品質評価
        score = evaluate_response(state["current_answer"], query)
        if score >= min_score:
            break

    return state["current_answer"]
```

**評価メトリクス（Ragasを活用）**

```python
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy, context_precision

def evaluate_response(response: str, query: str, contexts: list[str]) -> float:
    """複合スコアで回答品質を評価"""
    dataset = {
        "question": [query],
        "answer": [response],
        "contexts": [contexts],
    }
    results = evaluate(dataset, metrics=[faithfulness, answer_relevancy, context_precision])

    # 重み付き平均（用途に応じて調整）
    weights = {"faithfulness": 0.4, "answer_relevancy": 0.4, "context_precision": 0.2}
    return sum(results[m] * w for m, w in weights.items())
```

### 注意事項・トレードオフ

| 観点 | 内容 |
|------|------|
| **コスト爆発リスク** | イテレーション数・サブクエリ数に応じてLLM呼び出しが急増。必ずコスト上限を設定 |
| **レイテンシ** | 各イテレーションで複数のLLM呼び出しが必要。リアルタイムUIには不向き（非同期処理を検討） |
| **評価品質に依存** | 反復継続・終了の判断は評価スコアの精度に直結。不適切な評価メトリクスは無限ループを招く |
| **Deep Research変形** | 長文レポートが必要な場合は各イテレーションの回答を蓄積して最終的に編集する形に変更 |
| **P9・P10との統合** | Index-Aware Retrieval（P9）とNode Postprocessing（P10）をDSの各イテレーションに組み込むと品質向上 |
| **P11信頼性** | 各イテレーションにTrustworthy Generation（P11）のガードレールを適用して信頼性を確保 |
