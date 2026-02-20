# RAG・Grounding・Plugin 詳細ガイド

## 目次

1. [RAGの基礎](#ragの基礎)
2. [Corpus管理](#corpus管理)
3. [チャンキング戦略](#チャンキング戦略)
4. [エンベディングとVector Search](#エンベディングとvector-search)
5. [Retrieval Logicとクエリフロー](#retrieval-logicとクエリフロー)
6. [Citations（引用・出典管理）](#citations引用出典管理)
7. [Multi-Corpus Querying](#multi-corpus-querying)
8. [Grounding 3方式](#grounding-3方式)
9. [Agentic RAGパターン](#agentic-ragパターン)
10. [Pre-built Tools統合](#pre-built-tools統合)
11. [Plugin System](#plugin-system)
12. [RAG最適化と運用](#rag最適化と運用)

---

## RAGの基礎

### RAG（Retrieval-Augmented Generation）とは

RAGは、LLMの回答を外部ドキュメントで根拠付ける先進的なAIアーキテクチャ。モデルが「記憶」している知識と「検索」で取得した外部知識を組み合わせることで、ハルシネーションを抑制し、最新かつドメイン固有の情報を正確に回答できるようにする。

**従来のLLMの限界:**
- 学習データにない新しい・プライベートな情報にアクセスできない
- ハルシネーション（事実と異なる情報を生成）が発生する
- ソース参照がなく、回答の検証・監査が困難

### RAGパイプラインのステップ

```
1. ユーザークエリ入力
        ↓
2. クエリのエンベディング（ベクトル化）
        ↓
3. コーパスからセマンティック検索（Top-k チャンク取得）
        ↓
4. コンテキスト構築（クエリ + 検索結果を結合）
        ↓
5. LLM（Gemini）で回答生成
        ↓
6. 出典付き回答を返す（オプション: citations）
```

### RAGのコアコンポーネント

| コンポーネント | 役割 |
|-------------|------|
| **Retriever** | ベクトルDBや文書ストアを検索し、意味的に類似したテキスト断片を取得 |
| **Generator** | 取得したコンテキストと元のクエリを受け取り、流暢で人間らしい回答を生成するLLM |
| **Corpus** | エージェントの知識源となる文書コレクション（PDF、Webサイト、FAQ等） |
| **Embeddings** | クエリと文書の両方を高次元空間でベクトル表現し、類似度比較を可能にする数値表現 |

### RAGアーキテクチャの利点

| 利点 | 説明 |
|-----|------|
| **根拠付き回答** | 取得したコンテンツに基づくため、ハルシネーションを削減し信頼性を向上 |
| **常に最新** | コーパスを新しい文書で更新するだけでよく、モデルの再学習不要 |
| **ドメイン適応性** | ドメイン固有の文書でコーパスをカスタマイズすることで特定領域に特化 |
| **説明可能性** | 情報の出典を明示でき、検証と監査が容易 |
| **効率的な知識管理** | モデルチューニングと知識管理を分離。情報の追加・削除が文書更新で完結 |

### 従来のRAG vs Agentic RAG

| 特性 | 従来のRAG | Agentic RAG |
|------|---------|------------|
| **検索クエリ** | ユーザー入力をそのまま使用 | LLMが最適化されたクエリを動的生成 |
| **検索回数** | 1回（固定） | 複数回（必要に応じて動的） |
| **検索戦略** | 単一の検索手法 | 複数の検索手法を組み合わせ |
| **コンテキスト理解** | 静的 | 検索結果を解釈して次の検索に活用 |
| **ルーティング** | なし | クエリ分類に基づくコーパス選択 |

---

## Corpus管理

### Corpusとは

**Corpus**（コーパス、複数形: corpora）は、RAGエージェントが質問に答えるために検索するドキュメントやデータの構造化されたリポジトリ。エージェントの「記憶」であり、知識の源泉。

**Corpusに含めることができるデータ:**
- 文書ファイル: PDF、Word、HTML、Markdown、テキスト
- データベースレコード
- FAQ・マニュアル
- 社内ナレッジベース
- Webページ・スクレイピングコンテンツ
- 議事録、メール、チャットログ

### 優れたCorpusの特性

| 特性 | 説明 |
|-----|------|
| **関連性** | エージェントのドメインや想定クエリに関連する情報を含む |
| **組織化** | 効率的な検索を容易にする適切なフォーマットと構造 |
| **網羅性** | 多様な質問に答えられる十分な範囲のトピックをカバー |
| **最新性** | 情報を現在の状態に保つため定期的に更新 |
| **クリーンさ** | 検索プロセスを混乱させる無関係・ノイズのあるデータを排除 |

### Corpus CRUD操作

```bash
# コーパス作成
adk corpus create
# プロンプトで入力:
#   - Corpus Name: support-docs
#   - Description: 製品サポートドキュメント
#   - Chunking Strategy: sentence（センテンス分割）

# ドキュメント追加（ローカルファイル）
adk corpus upload --name support-docs --file path/to/yourfile.pdf

# GCSから追加
adk corpus upload --name support-docs --gcs-uri gs://rag-demo-corpus/yourfile.pdf

# Google Driveから追加
adk corpus upload --name support-docs --drive-id 1sK8Zexample123456

# コーパス一覧
adk corpus list

# コーパス内のドキュメント一覧
adk corpus list-documents --name support-docs

# ドキュメント削除
adk corpus delete-document --corpus support-docs --doc-id <document-id>

# コーパス全体の削除
adk corpus delete --name support-docs

# インデックス再構築（検索結果が古い・不整合の場合）
adk corpus reindex --name support-docs
```

### Pythonでの実装例（Vertex AI RAG API）

```python
import vertexai
from vertexai.preview import rag
from vertexai.preview.rag import RagCorpus

# 初期化
vertexai.init(project="your-project-id", location="us-central1")

# コーパス作成
corpus = rag.create_corpus(
    display_name="support-docs",
    description="製品サポートドキュメント"
)
print(f"Corpus name: {corpus.name}")

# ファイルをGCSからコーパスに取り込む
rag.import_files(
    corpus_name=corpus.name,
    paths=["gs://your-bucket/support_docs/"],
    chunk_size=512,
    chunk_overlap=100,
    max_embedding_requests_per_min=900,
)

# コーパス一覧取得
corpora = rag.list_corpora()
for c in corpora:
    print(f"  - {c.display_name}: {c.name}")

# コーパス内のファイル一覧
files = rag.list_files(corpus_name=corpus.name)
for f in files:
    print(f"  - {f.display_name}: {f.name}")

# ファイル削除
rag.delete_file(name=file.name)

# コーパス削除
rag.delete_corpus(name=corpus.name)
```

### GCS経由でのドキュメント管理

```bash
# GCSバケット作成
gsutil mb -p your-project-id -l us-central1 gs://your-agent-docs-bucket/

# 単一ファイルアップロード
gsutil cp path/to/yourfile.pdf gs://rag-demo-corpus/

# 複数ファイル一括アップロード
gsutil cp *.pdf gs://rag-demo-corpus/

# GCSバケット全体をコーパスにリンク
adk corpus upload --name support-docs --gcs-uri gs://rag-demo-corpus/
```

### Corpusの組織化ベストプラクティス

```python
# トピック・ドメイン別にコーパスを分離
CORPUS_DESIGN = {
    "support-docs": "製品トラブルシューティング・FAQ",
    "product-manuals": "技術仕様・操作マニュアル",
    "legal-policies": "利用規約・プライバシーポリシー",
    "internal-knowledge": "社内手順・組織情報",
}

# ドキュメントのベストプラクティス
DOCUMENT_BEST_PRACTICES = [
    "意味のあるファイル名を使用（例: support-policy-v2.pdf、doc1.pdfは避ける）",
    "ヘッダーと明確なセクション区切りを含む構造化ドキュメント",
    "内容が変わった場合は最新バージョンを再アップロード",
    "topic、date、departmentなどのメタデータタグを追加",
    "重複ドキュメントの排除（--forceフラグは必要時のみ）",
]
```

---

## チャンキング戦略

### チャンキングとは

**チャンキング**は、PDF、Markdown、Webページなどの大きなドキュメントを「チャンク」と呼ぶ小さなセグメントに分割するプロセス。LLMはコンテキスト長に制限があるため、全文を一度に処理できない。チャンキングにより、エージェントは文書全体ではなく最も関連性の高いチャンクのみを検索する。

### チャンキング方式の比較

| 方式 | 説明 | 最適なユースケース |
|-----|------|--------------|
| **センテンス分割**（デフォルト） | 文の区切りでテキストを分割 | 一般的な文書、FAQ |
| **段落分割** | 段落全体をチャンクとして使用 | 説明的なコンテンツ、物語文 |
| **スライディングウィンドウ** | 文書を小さなステップで移動しながら取得 | 細粒度の検索が必要な場合 |
| **コードアウェア** | コードブロックを不適切に分割しない | 技術ドキュメント、APIリファレンス |
| **セクションヘッダー分割** | ヘッダーでセクションを区切る | 構造化マニュアル、法的文書 |

### チャンクサイズの選択基準

| ドキュメントタイプ | 推奨chunk_size | 推奨chunk_overlap |
|----------------|-------------|----------------|
| FAQ・短い質問回答 | 100〜200トークン | 20〜30トークン |
| 一般的な文書 | 300〜512トークン | 50〜100トークン |
| 技術マニュアル | 512〜1000トークン | 100〜200トークン |
| 法律・コンプライアンス | 512〜800トークン | 150〜200トークン |
| コード・APIドキュメント | 400〜600トークン | 50トークン |

**チャンクサイズのトレードオフ:**
- **小さいチャンク**: 精密な検索が可能。ただし、チャンク間の文脈が失われる可能性
- **大きいチャンク**: 文脈保持が良い。ただし、無関係な情報が混入しやすい
- **オーバーラップ**: 隣接チャンク間に共通部分を持つことで文脈の連続性を確保

### チャンキング設定例

```yaml
# corpus.yaml での設定
chunking:
  method: sentence      # sentence / paragraph / sliding_window / code_aware
  chunk_size: 512       # 1チャンクのトークン数
  overlap: 100          # 隣接チャンク間のオーバーラップ（トークン数）
```

```python
# Pythonでのチャンキング設定
from vertexai.preview import rag

# インポート時にチャンキング設定
rag.import_files(
    corpus_name=corpus.name,
    paths=["gs://your-bucket/docs/"],
    chunk_size=512,        # トークン数
    chunk_overlap=100,     # オーバーラップトークン数
)
```

### チャンキング問題のデバッグ

エージェントが無関係な回答を返す、または重要な情報を見落とす場合:

```bash
# 詳細モードでクエリを実行し、類似度スコアと取得チャンクを確認
adk ask "パスワードをリセットするには？" --verbose

# コーパス内のチャンクとメタデータを検査
adk inspect --corpus support-docs

# 詳細モードで埋め込みを確認
adk embed --corpus my-docs --verbose
```

**トラブルシューティングチェックリスト:**
- [ ] 取得チャンクをWebUIまたはCLIで確認
- [ ] 類似度スコアを確認（低い場合はmin_scoreを調整）
- [ ] 異なるチャンキング設定で再チャンキングを検討
- [ ] 代替エンベディングモデルを試す

---

## エンベディングとVector Search

### エンベディングとは

**エンベディング**は、テキストの意味的意味を捉える高次元のベクトル表現（数値のリスト）。エンベディングにより、エージェントは異なる表現でも意味が似ている文を理解できる:

```
「パスワードをリセットしてください」
「ログイン認証情報を回復するには？」
```
→ 表現は異なるが、意味的に類似 → 同じチャンクが検索される

### エンベディングパイプライン

```
ドキュメント
    ↓ チャンキング
チャンク（テキスト断片）
    ↓ エンベディングモデル
ベクトル（例: 768次元 or 1536次元の数値配列）
    ↓ ベクトルDB/インデックスに保存
                    ↑
ユーザークエリ → エンベディング → ベクトル比較 → Top-kチャンク取得
```

### サポートされているエンベディングプロバイダー

| プロバイダー | モデル例 | 特徴 |
|----------|---------|-----|
| **Google Vertex AI** | `textembedding-gecko@001` | ネイティブ統合、高パフォーマンス。Vertex AI ADKとの最適な統合 |
| **OpenAI** | `text-embedding-3-small` | 高精度、多言語対応 |
| **Cohere** | Embed v3 | 高速、多言語対応、柔軟なライセンス |
| **ローカルモデル** | sentence-transformers | 完全オンプレミス、インフラ自前で管理 |

### エンベディング設定

```yaml
# corpus.yaml でのエンベディング設定
embedding:
  provider: google                      # google / openai / cohere / local
  model: textembedding-gecko@001        # 使用するモデル
```

```python
# Vertex AI でのエンベディング（Pythonコード例）
from vertexai.preview import rag
from vertexai.language_models import TextEmbeddingModel

# ドキュメントを埋め込む
adk_command = "adk embed --corpus my-support-docs"

# Vertex AI Matching Engine を使用する場合の設定
corpus_config = {
    "index": {
        "provider": "vertexai",
        "project": "my-gcp-project",
        "location": "us-central1",
        "index_name": "my-support-index"
    },
    "embedding": {
        "provider": "google",
        "model": "textembedding-gecko@001"
    }
}
```

### Vector Search パラメータ

```yaml
# vector_search設定
vector_search:
  distance_metric: cosine    # cosine / dot_product / euclidean
  top_k: 5                   # 取得する最近傍ベクトル数
  index_type: HNSW           # HNSW / brute_force / IVF
  min_score: 0.7             # 含めるための最小類似度スコア
```

### 距離メトリクスの選択

| メトリクス | 説明 | 推奨ユースケース |
|----------|------|--------------|
| **コサイン類似度**（推奨） | ベクトル間の角度を測定。正規化済みベクトルに有効 | テキストエンベディングの大多数 |
| **内積** | ベクトルの射影を測定。正規化済みの場合コサインと同等 | 正規化済みベクトル |
| **ユークリッド距離** | ベクトル間の直線距離を測定 | 密度ベースの検索 |

### インデックスタイプの選択

| インデックスタイプ | 速度 | 精度 | メモリ使用量 | 推奨規模 |
|--------------|------|------|------------|---------|
| **ブルートフォース** | 低 | 100% | 低 | 小規模（< 10万チャンク） |
| **HNSW** | 高 | 95%+ | 高 | 中〜大規模 |
| **IVF** | 中 | 90%+ | 中 | 大規模（> 100万チャンク） |

### Vector Search チューニングガイドライン

```python
# top_k と min_score のチューニング指針
RETRIEVAL_TUNING = {
    # 精密な検索が必要（FAQ、短い回答）
    "high_precision": {
        "top_k": 3,
        "min_score": 0.80,
        "distance_metric": "cosine"
    },
    # バランス型（一般的なユースケース）
    "balanced": {
        "top_k": 5,
        "min_score": 0.70,
        "distance_metric": "cosine"
    },
    # 高い再現率（広範な検索）
    "high_recall": {
        "top_k": 10,
        "min_score": 0.60,
        "distance_metric": "cosine"
    }
}
```

### エンベディングストレージオプション

| ストレージ | 説明 | 推奨用途 |
|---------|------|---------|
| **ローカルファイルベースインデックス** | 高速テスト | 開発・プロトタイピング |
| **Vertex AI Matching Engine** | GoogleのスケーラブルなベクトルDB | プロダクション環境 |
| **Pinecone** | カスタムベクトルDB | 高度なフィルタリングが必要な場合 |
| **Weaviate / Milvus** | OSSベクトルDB | オンプレミス要件がある場合 |

---

## Retrieval Logicとクエリフロー

### クエリから回答までの全体フロー

```
ユーザー: "パスワードをリセットするには？"
    ↓
1. クエリエンベディング
   クエリ → 同一エンベディングモデル → クエリベクトル

2. セマンティック類似度検索
   クエリベクトル vs 保存済みチャンクベクトル
   → コサイン類似度でスコアリング

3. Top-k チャンク取得
   最も類似度の高いチャンクを取得（例: Top 5）
   各チャンクには類似度スコアとメタデータが付随

4. プロンプト構築
   [システム命令] + [取得コンテキスト] + [ユーザークエリ]

5. LLM回答生成
   Geminiがコンテキストに根拠付けた回答を生成

6. 出典付き回答
   回答 + 参照チャンクのソース情報
```

### プロンプト構築の基本形式

```python
PROMPT_TEMPLATE = """
あなたは親切なアシスタントです。以下のコンテキスト情報のみを使用して、
ユーザーの質問に答えてください。コンテキストに情報がない場合は、
「提供された情報には該当する内容がありません」と回答してください。

コンテキスト:
{chunk_1}

{chunk_2}

{chunk_3}

ユーザーの質問:
{user_query}

回答:
"""
```

### ADK検索設定のYAML例

```yaml
# retrieval設定
retrieval:
  top_k: 5                      # 取得する上位チャンク数
  min_score: 0.70               # 最小類似度スコア（0.0〜1.0）
  similarity_metric: cosine     # 類似度メトリクス
  include_metadata: true        # メタデータを含める
```

### よくある検索の問題と対策

| 問題 | 考えられる原因 | 対策 |
|-----|------------|------|
| **無関係な結果** | チャンキングが不適切、またはエンベディングの品質が低い | チャンクサイズ/オーバーラップを見直し、エンベディングモデルをテスト |
| **結果が返らない** | `min_score`が高すぎる、またはエンベディング不一致 | スコア閾値を下げ、モデル互換性を確認 |
| **ハルシネーション** | 取得コンテキストが不十分 | `top_k`を増やすか、コーパスのカバレッジを改善 |
| **冗長・繰り返しの出力** | プロンプトが緩すぎる | プロンプトテンプレートを改善するか、コンテキストを短縮 |
| **検索が遅い** | インデックスが最適化されていない、またはtop_kが大きすぎる | インデックスタイプを調整、top_kを5〜10に制限 |

### ハイブリッド検索（セマンティック + キーワード）

```python
import asyncio
from typing import List

def hybrid_search(query: str, alpha: float = 0.5) -> List[dict]:
    """
    セマンティック検索とキーワード検索を組み合わせたハイブリッド検索。

    Args:
        query: 検索クエリ
        alpha: ベクトル検索の重み（0.0=完全キーワード、1.0=完全ベクトル）

    Returns:
        検索結果のリスト（タイトル、コンテンツ、スコアを含む）
    """
    # キーワード検索（BM25 or ElasticSearch）
    keyword_results = keyword_index.search(query, top_k=10)

    # セマンティック（ベクトル）検索
    vector_results = vector_db.search(query, top_k=10)

    # ハイブリッドスコアの計算（Reciprocal Rank Fusion）
    combined = {}
    for i, result in enumerate(keyword_results):
        doc_id = result["id"]
        combined[doc_id] = combined.get(doc_id, 0) + (1 - alpha) * (1 / (i + 1))

    for i, result in enumerate(vector_results):
        doc_id = result["id"]
        combined[doc_id] = combined.get(doc_id, 0) + alpha * (1 / (i + 1))

    # スコアでソートして返す
    sorted_results = sorted(combined.items(), key=lambda x: x[1], reverse=True)
    return [get_document(doc_id) for doc_id, _ in sorted_results[:5]]


# ハイブリッド検索ツールをADKエージェントに統合
from google.adk.tools import FunctionTool
from google.adk.agents import Agent

hybrid_search_tool = FunctionTool(func=hybrid_search)

agent = Agent(
    name="hybrid_rag_agent",
    model="gemini-2.0-flash",
    tools=[hybrid_search_tool],
    instruction="""
    ユーザーの質問に答えるには、hybrid_searchツールを使用してください。
    このツールはキーワードと意味の両面から検索するため、
    より正確な情報を取得できます。
    """
)
```

### 並列検索パターン

```python
async def parallel_multi_corpus_search(
    queries: List[str],
    corpus_names: List[str]
) -> List[dict]:
    """複数クエリ・複数コーパスを並列検索"""
    tasks = [
        search_corpus_async(query, corpus)
        for query in queries
        for corpus in corpus_names
    ]
    results = await asyncio.gather(*tasks)
    # 結果を統合してスコアでソート
    all_results = [r for sublist in results for r in sublist]
    return sorted(all_results, key=lambda x: x["score"], reverse=True)[:10]
```

---

## Citations（引用・出典管理）

### なぜCitationsが重要か

RAGシステムの際立った利点の一つが「トレーサビリティ」。回答がどこから来たかを明示できる。エンタープライズ、法律、医療、カスタマーサポートなど多くのユースケースで必須。

| 利点 | 説明 |
|-----|------|
| **信頼性** | 情報源を確認できるため、ユーザーが情報を信頼しやすい |
| **透明性** | 根拠付き事実とLLMの一般出力を区別できる |
| **監査** | ビジネスの意思決定や推奨事項を文書にトレースバックできる |
| **コンプライアンス** | 多くの規制産業で文書とソーストレーサビリティが必要 |

### ADKによるソーストラッキング

コーパスに取り込まれた各ドキュメントチャンクは、以下のメタデータとともに保存される:

```python
# チャンクメタデータの例
CHUNK_METADATA = {
    "source_document_name": "billing-guide.pdf",
    "original_upload_path": "gs://your-bucket/billing/",
    "page_number": 3,              # PDFの場合
    "section_title": "2. 請求設定",
    "document_id": "doc_abc123",
    "timestamp": "2024-01-15T10:00:00Z",
    "department": "finance",       # カスタムタグ
    "version": "v2.3",
}
```

### Citation設定例

```yaml
# エージェント設定でのcitation設定
response:
  show_citations: true             # citations表示を有効化
  citation_style: inline           # inline / endnote
  include_metadata_fields:
    - source                       # ソースドキュメント名
    - page                         # ページ番号
    - section                      # セクション名
```

### Citation出力の例

**エンドノート形式:**
```
お客様のご請求情報を更新するには、アカウントダッシュボードの
「請求設定」セクションに移動し、「支払方法を編集」をクリックしてください。

出典:
- billing-guide.pdf（3ページ）
- account-settings-manual.pdf（7ページ）
```

**インライン形式:**
```
請求情報を更新するには [billing-guide.pdf, p.3]、
ダッシュボードに移動してください...
```

### CitationをPythonで処理する実装

```python
from google.adk.agents import Agent
from google.adk.tools import FunctionTool
from typing import List, Dict

def search_with_citations(query: str) -> Dict:
    """
    引用情報付きでコーパスを検索する。

    Args:
        query: 検索クエリ

    Returns:
        検索結果とcitation情報を含むdict
    """
    # ベクトルDBから検索
    results = vector_db.search(query, top_k=5)

    # 結果とcitationをフォーマット
    chunks = []
    citations = []

    for result in results:
        chunks.append({
            "content": result.content,
            "score": result.score
        })
        citations.append({
            "source": result.metadata.get("source_document_name"),
            "page": result.metadata.get("page_number"),
            "section": result.metadata.get("section_title"),
            "score": result.score
        })

    return {
        "chunks": chunks,
        "citations": citations,
        "query": query
    }


# Citation対応エージェント
citation_agent = Agent(
    name="citation_agent",
    model="gemini-2.0-flash",
    tools=[FunctionTool(func=search_with_citations)],
    instruction="""
    ユーザーの質問に答える際:
    1. search_with_citationsツールで関連情報を検索する
    2. 取得した情報に基づいて回答を生成する
    3. 回答の末尾に必ず出典を以下の形式で記載する:

    出典:
    - [ファイル名]（ページ番号 / セクション名）
    - [ファイル名]（ページ番号 / セクション名）

    コンテキストに情報がない場合は、その旨を明示してください。
    """
)
```

### Citationのベストプラクティス

```python
CITATION_BEST_PRACTICES = {
    "ファイル名": "意味のある名前を使用（doc1.pdfではなくsupport-policy-v2.pdf）",
    "メタデータ": "topic、date、departmentなどのフィールドを追加してフィルタリングを容易に",
    "チャンキング": "セクションヘッダーやページ単位でチャンクを切ることで参照が明確に",
    "更新": "コンテンツが変わったら再エンベディングして古いcitationを防止",
    "スコア閾値": "低スコアのチャンクはcitationから除外して品質を保つ",
}
```

### CLI でのCitation検証

```bash
# citation表示付きでクエリ実行
adk ask "返金プロセスとは？" --show-citations

# 詳細な検索結果を表示（ドキュメントID、スコア、メタデータ）
adk ask "返金プロセスとは？" --verbose

# コーパス内のチャンクとメタデータを検査
adk inspect --corpus support-faqs
```

---

## Multi-Corpus Querying

### 単一 vs 複数コーパスの選択基準

| シナリオ | 推奨 |
|---------|------|
| 小〜中規模のナレッジベース（多様なトピック） | 単一コーパス |
| 大規模・多様なナレッジベース（複数ビジネスユニット） | 複数コーパス + ルーティング |
| モジュール更新や細かい制御が必要 | 複数コーパス |
| 迅速なプロトタイピング・実験 | 単一コーパス |
| アクセス制御をドメインごとに分離 | 複数コーパス |

### 単一コーパス

**利点:**
- シンプル: 1つのインデックスを管理するだけで設定とクエリが容易
- 幅広い検索: 複数のトピックにわたるクエリに対応
- 統合が速い: 1つのコーパスを取り込み・維持するだけ

**欠点:**
- スケーラビリティ: 非常に大きなコーパスは検索を遅くしてコストを増加
- 関連性の希薄化: 多様なトピックの大規模コーパスでは無関係なチャンクが取得される可能性
- コンテキスト制御の制限: 特定の知識ドメインへの検索の分離が困難

### 複数コーパスの構成例

```
corpora/
├── support-docs/          # 製品サポート・FAQ
├── product-manuals/       # 技術仕様・操作手順
└── legal-policies/        # 利用規約・コンプライアンス
```

**利点:**
- 関連性の向上: 対象を絞ったコーパスのクエリでより焦点を絞った関連結果
- モジュール更新: 他のコーパスに影響なく1つのコーパスを更新・更新
- コーパスごとの高速検索: 小さなインデックスでより速いセマンティック検索
- 細かい検索設定: コーパスごとにパラメータをカスタマイズ（例: 異なるtop_k値）

### 複数コーパスのクエリ方法

```bash
# CLIで複数コーパスを横断クエリ
adk ask "返金ポリシーとは？" --corpus support-docs,legal-policies
```

```python
import asyncio
from google.adk.agents import Agent
from google.adk.tools import FunctionTool
from typing import List, Dict

def route_and_search(query: str, intent: str = "auto") -> Dict:
    """
    クエリをインテントに基づいて適切なコーパスにルーティングして検索する。

    Args:
        query: 検索クエリ
        intent: クエリのインテント（auto/support/legal/product）

    Returns:
        統合された検索結果
    """
    # インテント分類（シンプルなルールベース）
    CORPUS_ROUTING = {
        "support": ["support-docs"],
        "legal": ["legal-policies"],
        "product": ["product-manuals"],
        "auto": ["support-docs", "product-manuals", "legal-policies"],
    }

    target_corpora = CORPUS_ROUTING.get(intent, CORPUS_ROUTING["auto"])

    # 各コーパスを並列検索
    all_results = []
    for corpus_name in target_corpora:
        results = search_corpus(query, corpus_name, top_k=3)
        for r in results:
            r["corpus"] = corpus_name  # どのコーパスからの結果かを追記
        all_results.extend(results)

    # スコアでソートして上位結果を返す
    all_results.sort(key=lambda x: x["score"], reverse=True)
    return {
        "results": all_results[:5],
        "queried_corpora": target_corpora
    }


# マルチコーパスRAGエージェント
multi_corpus_agent = Agent(
    name="multi_corpus_agent",
    model="gemini-2.0-flash",
    tools=[FunctionTool(func=route_and_search)],
    instruction="""
    ユーザーの質問に応じて適切なコーパスを選択して検索してください。

    ルーティングガイドライン:
    - サポート・トラブルシューティング → intent="support"
    - 法的・コンプライアンス → intent="legal"
    - 製品仕様・機能 → intent="product"
    - 複合的な質問 → intent="auto"（全コーパス検索）
    """
)
```

### マルチコーパスの結果統合

```python
from typing import List, Dict

def merge_and_rerank_results(
    results_from_corpora: Dict[str, List[dict]],
    strategy: str = "score"
) -> List[dict]:
    """
    複数コーパスからの検索結果を統合・再ランク付けする。

    Args:
        results_from_corpora: コーパス名をキー、検索結果リストを値とするdict
        strategy: 統合戦略（score / rrf / interleave）

    Returns:
        統合・ランク付けされた結果リスト
    """
    if strategy == "score":
        # スコアで単純にソート
        all_results = []
        for corpus_name, results in results_from_corpora.items():
            for r in results:
                r["corpus_source"] = corpus_name
            all_results.extend(results)
        return sorted(all_results, key=lambda x: x["score"], reverse=True)

    elif strategy == "rrf":
        # Reciprocal Rank Fusion（RRF）
        doc_scores = {}
        k = 60  # RRFパラメータ
        for corpus_name, results in results_from_corpora.items():
            for rank, result in enumerate(results):
                doc_id = result["id"]
                doc_scores[doc_id] = doc_scores.get(doc_id, 0) + 1 / (k + rank + 1)
        # スコアでソートして返す
        sorted_docs = sorted(doc_scores.items(), key=lambda x: x[1], reverse=True)
        return [get_document(doc_id) for doc_id, _ in sorted_docs[:10]]

    return []
```

---

## Grounding 3方式

### Groundingとは

**Grounding**（グラウンディング）は、エージェントの回答を外部データソースで根拠付ける仕組み。LLMのハルシネーション（事実と異なる生成）を抑制し、最新情報や企業固有データに基づく正確な回答を実現する。

### 3方式の選択基準

| 方式 | データソース | ユースケース | コスト | 実装難易度 | レイテンシ |
|------|------------|------------|--------|----------|----------|
| **Google Search Grounding** | 公開Web | 最新ニュース、一般情報、リアルタイムデータ | API課金（低） | 低 | 低 |
| **Vertex AI Search Grounding** | 企業データストア | 社内文書、プライベートデータ、ナレッジベース | Vertex AI課金（中） | 中 | 中 |
| **Agentic RAG** | カスタムベクトルDB | 高度な検索ロジック、マルチステップ検索 | インフラ+推論（中〜高） | 高 | 中〜高 |

### 選択ガイドライン

#### Google Search Grounding を選択
- 最新の公開情報が必要
- シンプルな実装を希望
- ニュース、リアルタイムデータを扱う

#### Vertex AI Search Grounding を選択
- 企業固有のデータソースを使用
- アクセス制御（IAM）が必要
- マネージドサービスを活用したい

#### Agentic RAG を選択
- 複雑な検索ロジックが必要
- マルチステップ・マルチコーパス検索を実装したい
- ベクトルDBのカスタマイズが必要

---

## Agentic RAGパターン

### 1. Google Search Grounding

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
    必ず出典URLを明記してください。
    """
)

# 実行
response = agent.run("2025年のAI分野の最新トレンドは？")
print(response.text)

# Grounding Metadataにアクセス
if response.grounding_metadata:
    print("検索クエリ:", response.grounding_metadata.search_entry_point.query)
    print("出典:")
    for chunk in response.grounding_metadata.grounding_chunks:
        print(f"  - {chunk.web.title}: {chunk.web.uri}")
```

### 2. Vertex AI Search Grounding

```bash
# 事前設定
export GOOGLE_GENAI_USE_VERTEXAI=1
export GOOGLE_CLOUD_PROJECT=your-project-id
export VERTEX_AI_SEARCH_DATA_STORE_ID=your-data-store-id
```

```python
from google.adk.tools import VertexAiSearchTool
from google.adk.agents import Agent
import os

# Vertex AI Search Tool作成
vertex_search = VertexAiSearchTool(
    data_store_id=os.getenv("VERTEX_AI_SEARCH_DATA_STORE_ID"),
    max_results=5
)

agent = Agent(
    name="knowledge_base_agent",
    model="gemini-2.0-flash",
    tools=[vertex_search],
    instruction="""
    ユーザーの質問に答える際、社内データストアから関連情報を検索してください。
    検索結果に基づいて、正確な情報を提供し、出典を明記してください。
    """
)

response = agent.run("当社の返品ポリシーは何ですか？")
print(response.text)
```

**高度なVertex AI Search設定:**

```python
vertex_search = VertexAiSearchTool(
    data_store_id=data_store_id,
    max_results=10,
    # フィルター: アクティブなポリシーカテゴリのみ検索
    filter_expression="category = 'policy' AND status = 'active'",
    # ブースト: 新しいドキュメントを優先
    boost_spec={
        "condition_boost_specs": [
            {
                "condition": "document_freshness > 30",
                "boost": 1.5
            }
        ]
    }
)
```

### 3. Agentic RAG（カスタムベクトルDB）

#### 基本実装

```python
from google.adk.agents import Agent
from google.adk.tools import FunctionTool
from typing import List

def search_knowledge_base(
    query: str,
    filters: dict = None,
    top_k: int = 5
) -> List[dict]:
    """
    ナレッジベースから情報を検索します。

    Args:
        query: 検索クエリ
        filters: フィルター条件 (例: {"category": "technical", "language": "ja"})
        top_k: 取得する上位チャンク数

    Returns:
        検索結果のリスト（title, content, score, source を含む）
    """
    results = vector_db.search(query, filters=filters, top_k=top_k)
    return [
        {
            "title": r.title,
            "content": r.content,
            "score": r.score,
            "source": r.metadata.get("source_document"),
            "page": r.metadata.get("page_number")
        }
        for r in results
    ]

search_tool = FunctionTool(func=search_knowledge_base)

agentic_rag_agent = Agent(
    name="agentic_rag",
    model="gemini-2.0-flash",
    tools=[search_tool],
    instruction="""
    ユーザーの質問に答えるために、search_knowledge_baseツールを使用してください。

    検索戦略:
    1. まず、ユーザーの質問から最も重要なキーワードを抽出し、初回検索を実行
    2. 検索結果を評価し、不十分な場合は別の角度から再検索
    3. 複数の検索結果を統合して、包括的な回答を生成
    4. 検索結果に基づく場合は、出典（ファイル名・ページ番号）を明記

    注意: 検索クエリは簡潔かつ具体的にすること。コンテキストに情報がない場合は、
    その旨を明示してください。
    """
)
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
    - 質問の主要なトピックで初回検索（top_k=5）

    ステップ2: 結果の評価
    - 初回検索で十分な情報が得られたか確認（スコア > 0.7が目安）
    - 不足している情報を特定

    ステップ3: 深掘り検索
    - 不足情報に特化した追加検索
    - より具体的なフィルターを適用
    - 別の言い回しでクエリを試す

    ステップ4: 統合と回答生成
    - すべての検索結果を統合して回答を生成
    - 各情報の出典を明記
    """
)
```

#### Vertex AI RAG APIを使ったAgentic RAG実装

```python
import vertexai
from vertexai.preview import rag
from google.adk.agents import Agent
from google.adk.tools import FunctionTool

vertexai.init(project="your-project-id", location="us-central1")

def retrieve_from_vertex_rag(query: str, corpus_name: str) -> dict:
    """
    Vertex AI RAG APIを使ってコーパスを検索する。

    Args:
        query: 検索クエリ
        corpus_name: 検索対象のコーパス名

    Returns:
        取得したコンテキストとソース情報
    """
    rag_resource = rag.RagResource(
        rag_corpus=corpus_name,
    )

    response = rag.retrieval_query(
        rag_resources=[rag_resource],
        text=query,
        similarity_top_k=5,
        vector_distance_threshold=0.3,  # 類似度閾値（低いほど多くの結果）
    )

    contexts = []
    for context in response.contexts.contexts:
        contexts.append({
            "text": context.text,
            "source_uri": context.source_uri,
            "score": context.score,
        })

    return {
        "contexts": contexts,
        "query": query,
        "corpus": corpus_name,
    }


vertex_rag_tool = FunctionTool(func=retrieve_from_vertex_rag)

vertex_rag_agent = Agent(
    name="vertex_rag_agent",
    model="gemini-2.0-flash",
    tools=[vertex_rag_tool],
    instruction="""
    ユーザーの質問に答えるために、retrieve_from_vertex_ragツールを使用してください。
    corpus_nameには "projects/YOUR_PROJECT/locations/us-central1/ragCorpora/CORPUS_ID" を使用。
    取得したコンテキストに基づいて回答し、source_uriを出典として明記してください。
    """
)
```

### Grounding + Pluginの組み合わせ

```python
from google.adk.plugins import BasePlugin
from google.adk.tools import google_search
from google.adk.agents import Agent
from google.adk import Runner

class GroundingMonitorPlugin(BasePlugin):
    """Grounding結果を監視するPlugin"""

    async def after_run(self, context, result):
        if hasattr(result, 'grounding_metadata') and result.grounding_metadata:
            grounding = result.grounding_metadata
            num_sources = len(grounding.grounding_chunks)

            # メトリクス記録
            self._emit_metric("grounding_used", 1, {
                "num_sources": num_sources
            })

            if num_sources == 0:
                print(f"警告: 検索結果なし")
        else:
            print("警告: Groundingが使用されていません")

    def _emit_metric(self, metric_name: str, value: float, tags: dict):
        # Prometheus/CloudWatch等に送信
        pass


agent = Agent(
    name="grounded_agent",
    model="gemini-2.0-flash",
    tools=[google_search],
    instruction="最新情報を検索して回答してください。必ず出典を明記してください。"
)

runner = Runner(
    agent=agent,
    plugins=[GroundingMonitorPlugin()]
)
```

---

## Pre-built Tools統合

### Pre-built Tools一覧

| Tool | 種類 | 用途 |
|------|------|------|
| **google_search** | GoogleSearchTool | Google検索によるGrounding |
| **VertexAiSearchTool** | VertexAiSearchTool | Vertex AI SearchデータストアによるGrounding |
| **load_web_page** | FunctionTool | WebページのHTMLテキスト取得 |
| **load_memory** | LoadMemoryTool | 長期記憶の明示的検索 |
| **preload_memory** | PreloadMemoryTool | 長期記憶の自動プリロード（RequestProcessor） |
| **load_artifacts** | LoadArtifactsTool | セッション内ファイル（Artifact）のロード |
| **get_user_choice** | GetUserChoiceTool（LongRunningFunctionTool） | ユーザーインタラクション（選択肢提示） |
| **exit_loop** | FunctionTool | LoopAgentのループ終了 |

### load_web_page（Webページ取得）

```python
from google.adk.agents import Agent
from google.adk.tools import FunctionTool
from google.adk.tools.load_web_page import load_web_page

web_page_loader_tool = FunctionTool(func=load_web_page)

browser_agent = Agent(
    name="web_browser_agent",
    model="gemini-2.0-flash",
    instruction="Webページの内容を取得して要約・質問に答えてください。",
    tools=[web_page_loader_tool]
)
```

**注意事項:**
- JavaScriptで動的生成されるコンテンツには非対応
- 大量コンテンツはトークン制限に注意
- **推奨2段階パターン**: `google_search` でURL取得 → `load_web_page` で詳細取得

### load_memory / preload_memory（記憶管理）

```python
from google.adk.agents import Agent
from google.adk.tools import load_memory, preload_memory

# 明示的検索Agent（LLMが必要と判断した時だけ検索）
reactive_memory_agent = Agent(
    name="reactive_memory_agent",
    model="gemini-2.0-flash",
    instruction="過去情報が必要な場合はload_memoryツールを使用してください。",
    tools=[load_memory]
)

# 自動プリロードAgent（常に過去のコンテキストを提供）
proactive_memory_agent = Agent(
    name="proactive_memory_agent",
    model="gemini-2.0-flash",
    instruction="過去の会話は自動的に提供されます。",
    tools=[preload_memory]
)
```

**使い分け:**
- **LoadMemoryTool**: 明示的な記憶検索が必要な場合（オンデマンド）
- **PreloadMemoryTool**: 常時関連コンテキストを提供したい場合（UX向上）

**注意**: PreloadMemoryToolは大量のメモリ検索結果でプロンプト長を増大させる可能性があるため、`similarity_top_k`で制御が推奨。

### load_artifacts（Artifact管理）

```python
from google.adk.agents import Agent
from google.adk.tools import load_artifacts, FunctionTool
from google.adk.tools.tool_context import ToolContext
from google.genai.types import Part

async def create_report_artifact(
    report_content: str,
    tool_context: ToolContext
) -> dict:
    """レポートをArtifactとして保存する"""
    filename = "summary_report.txt"
    artifact_part = Part(text=report_content)
    await tool_context.save_artifact(filename=filename, artifact=artifact_part)
    return {"status": "success", "filename": filename}

report_tool = FunctionTool(func=create_report_artifact)

artifact_agent = Agent(
    name="artifact_manager",
    model="gemini-2.0-flash",
    instruction="レポートを作成し、必要に応じてload_artifactsで参照してください。",
    tools=[report_tool, load_artifacts]
)
```

**ユースケース:**
- Agent生成ファイルへの後続参照
- 全ターンでのファイル内容送信を回避（必要時のみロード）

---

## Plugin System

### Plugin vs Callback の違い

| 観点 | Plugin | Callback |
|------|--------|----------|
| **スコープ** | Runner全体（グローバル） | 特定のAgent（ローカル） |
| **用途** | セキュリティガードレール、監視、ログ、監査 | Agent固有のカスタマイズ |
| **設定場所** | Runner初期化時 | Agent定義時 |
| **影響範囲** | すべてのAgentに適用 | 設定されたAgent内のみ有効 |

**Plugin vs Callback 判断基準:**

| ユースケース | 最適な選択 | 理由 |
|------------|----------|------|
| 不適切入力のブロック（全Agent） | Plugin | 全Agentに統一的なガードレールを適用 |
| PII検出とフィルタリング（全Agent） | Plugin | セキュリティポリシーの一元管理 |
| API呼び出しメトリクスの収集 | Plugin | アプリケーション全体のオブザーバビリティ |
| 特定Agentの動的instruction注入 | Callback | Agent固有のコンテキスト依存ロジック |
| 特定Toolの引数カスタマイズ | Callback | Agent内部の振る舞い調整 |
| レート制限（全Tool） | Plugin | グローバルなクオータ管理 |

### 6つのライフサイクルフック

```
on_user_message → before_run → [Agent実行] → on_event → after_run
                                    ↓
                            on_model_error / on_tool_error
```

#### 1. on_user_message（入力バリデーション）

```python
from google.adk.plugins import BasePlugin
from google.genai.types import Content, Part
from typing import Optional

class InputValidationPlugin(BasePlugin):
    """ユーザー入力の検証Plugin"""

    BLOCKED_PATTERNS = ["暴力的", "違法", "不適切"]

    async def on_user_message(
        self,
        context,
        message: Content
    ) -> Optional[Content]:
        """
        Contentを返すと以降の処理をスキップ（ブロック）。
        Noneを返すと正常な処理を継続。
        """
        if message.parts:
            text = message.parts[0].text.lower()
            for pattern in self.BLOCKED_PATTERNS:
                if pattern in text:
                    return Content(parts=[Part.from_text(
                        "不適切な内容が検出されました。ポリシーに違反しています。"
                    )])
        return None
```

#### 2. before_run（認証・前処理）

```python
class AuthenticationPlugin(BasePlugin):
    async def before_run(self, context) -> None:
        """例外を発生させるとAgent実行を中断。"""
        user_id = context.metadata.get("user_id")
        if not user_id:
            raise AuthenticationError("ユーザーIDが必要です")
        if not self._is_authenticated(user_id):
            raise AuthenticationError("認証されていません")
        self._log_execution_start(user_id, context.invocation_id)
```

#### 3. after_run（メトリクス収集・監査）

```python
from datetime import datetime

class MetricsPlugin(BasePlugin):
    async def after_run(self, context, result: Content) -> None:
        """Agent完了後にメトリクスを記録。"""
        response_length = len(result.parts[0].text) if result.parts else 0
        self._emit_metric("agent_response_length", response_length, {
            "user_id": context.metadata.get("user_id"),
            "agent_name": context.metadata.get("agent_name", "unknown"),
        })
        self._audit_log({
            "timestamp": datetime.utcnow().isoformat(),
            "user_id": context.metadata.get("user_id"),
            "response_preview": result.parts[0].text[:100] if result.parts else ""
        })
```

#### 4. on_event（イベント監査・変換）

```python
from google.adk.events import Event

class EventAuditPlugin(BasePlugin):
    async def on_event(
        self,
        context,
        event: Event
    ) -> Optional[Event]:
        """
        修正したEventを返すと置換。
        Noneを返すと元のEventをそのまま使用。
        """
        self._log_event({
            "event_id": event.id,
            "author": event.author,
            "invocation_id": event.invocation_id,
        })

        # Function Callの機密情報をサニタイズ
        if event.get_function_calls():
            for fc in event.get_function_calls():
                if "api_key" in fc.args:
                    fc.args["api_key"] = "[REDACTED]"
            return event

        return None
```

#### 5. on_model_error（フォールバック・リトライ）

```python
from google.genai.errors import GoogleAPIError

class FallbackPlugin(BasePlugin):
    async def on_model_error(
        self,
        context,
        error: Exception
    ) -> Optional[Content]:
        """
        Contentを返すとエラーを回復。
        Noneを返すとエラーを再発生。
        """
        if isinstance(error, GoogleAPIError) and "quota" in str(error).lower():
            self._send_alert(f"Quota exceeded: {error}")
            return Content(parts=[Part.from_text(
                "現在、リクエストが集中しています。しばらくしてから再度お試しください。"
            )])
        self._log_error(error, context.invocation_id)
        return None
```

#### 6. on_tool_error（Tool固有エラー処理）

```python
import asyncio

class ToolErrorHandlerPlugin(BasePlugin):
    MAX_RETRIES = 3

    async def on_tool_error(
        self,
        context,
        tool_name: str,
        error: Exception,
        retry_count: int = 0
    ) -> Optional[dict]:
        """
        dictを返すとエラーから回復。
        Noneを返すとエラーを再発生。
        """
        if self._is_transient_error(error) and retry_count < self.MAX_RETRIES:
            wait_time = 2 ** retry_count  # 指数バックオフ
            await asyncio.sleep(wait_time)
            return {
                "status": "retried",
                "message": f"リトライ中（{retry_count + 1}/{self.MAX_RETRIES}）"
            }

        self._notify_admin(tool_name, error)
        return {"error": f"Tool '{tool_name}' の実行に失敗しました: {str(error)}"}

    def _is_transient_error(self, error: Exception) -> bool:
        return isinstance(error, (TimeoutError, ConnectionError))
```

### RunnerへのPlugin登録

```python
from google.adk import Runner
from google.adk.agents import Agent

security_plugin = InputValidationPlugin()
monitoring_plugin = MetricsPlugin()
fallback_plugin = FallbackPlugin()

agent = Agent(
    name="assistant",
    model="gemini-2.0-flash",
    instruction="ユーザーの質問に答える親切なアシスタント"
)

# Plugin登録（リスト順に実行されるため順序が重要）
runner = Runner(
    agent=agent,
    plugins=[
        security_plugin,    # セキュリティ: 最初に配置（早期ブロック）
        monitoring_plugin,  # 監視: 最後に配置（全処理を観測）
        fallback_plugin,    # フォールバック
    ]
)
```

**Plugin配置の原則:**
- セキュリティPluginは**最初**に配置（早期ブロックのため）
- 監視・ログPluginは**最後**に配置（全処理を観測するため）

---

## RAG最適化と運用

### コスト最適化

| 最適化手法 | 説明 | 効果 |
|---------|------|------|
| **top_k削減** | 取得チャンク数を必要最小限に（推奨: 3〜5） | LLMへのトークン削減 |
| **min_score引き上げ** | 関連性の低いチャンクを除外 | 品質向上とコスト削減 |
| **キャッシュ活用** | 同一・類似クエリの結果をキャッシュ | 検索コスト大幅削減 |
| **チャンクサイズ最適化** | 適切なサイズでベクトルDB負荷削減 | インデックスコスト削減 |
| **ローカルインデックス（開発時）** | 開発中はVertex AI Matching Engine不使用 | 開発コスト削減 |
| **バッチ処理** | ドキュメントのエンベディングをバッチで処理 | API呼び出し削減 |

### パフォーマンスチューニング

```python
# チューニングパラメータの最適化例
RETRIEVAL_CONFIG = {
    # バランス型（推奨スタート）
    "balanced": {
        "top_k": 5,
        "min_score": 0.70,
        "chunk_size": 512,
        "chunk_overlap": 100,
        "distance_metric": "cosine",
        "index_type": "HNSW",
    },

    # 精密型（高精度が必要な場合）
    "high_precision": {
        "top_k": 3,
        "min_score": 0.80,
        "chunk_size": 300,
        "chunk_overlap": 50,
        "distance_metric": "cosine",
        "index_type": "HNSW",
    },

    # 広範囲型（網羅的な検索が必要な場合）
    "high_recall": {
        "top_k": 10,
        "min_score": 0.60,
        "chunk_size": 512,
        "chunk_overlap": 150,
        "distance_metric": "cosine",
        "index_type": "IVF",
    }
}
```

### RAGパイプライン評価

```python
from typing import List, Dict, Tuple

def evaluate_rag_quality(
    queries: List[str],
    expected_answers: List[str],
    agent
) -> Dict:
    """
    RAGパイプラインの品質を評価する。

    Returns:
        評価メトリクス（精度、再現率、F1スコア等）
    """
    metrics = {
        "total": len(queries),
        "grounding_used": 0,
        "avg_sources": 0,
        "hallucination_detected": 0,
        "correct_citations": 0,
    }

    for query, expected in zip(queries, expected_answers):
        response = agent.run(query)

        # Grounding使用確認
        if hasattr(response, 'grounding_metadata') and response.grounding_metadata:
            metrics["grounding_used"] += 1
            sources = len(response.grounding_metadata.grounding_chunks)
            metrics["avg_sources"] += sources

    metrics["avg_sources"] /= max(metrics["total"], 1)
    metrics["grounding_rate"] = metrics["grounding_used"] / metrics["total"]

    return metrics
```

### Grounding結果の検証

```python
def validate_grounding(response) -> bool:
    """Grounding結果の品質を検証"""
    if not hasattr(response, 'grounding_metadata') or not response.grounding_metadata:
        print("Groundingが使用されていません")
        return False

    grounding = response.grounding_metadata
    num_sources = len(grounding.grounding_chunks)

    if num_sources == 0:
        print("検索結果がありません")
        return False

    if num_sources < 2:
        print("出典が少ない（1件のみ）")

    print(f"Grounding検証OK（{num_sources}件の出典）")
    return True
```

### トラブルシューティングガイド

#### Google Search Groundingが動作しない

```python
# 確認事項:
# 1. Gemini 2.0以降のモデルを使用しているか
agent = Agent(
    model="gemini-2.0-flash",  # gemini-1.5-proではなく2.0以降が必須
    tools=[google_search],     # tools リストにgoogle_searchを含める
    instruction="最新情報を検索して回答してください。"  # 明示的な指示
)
```

#### Vertex AI Search Groundingのエラー

```bash
# 必須の環境変数を確認
echo $GOOGLE_GENAI_USE_VERTEXAI  # "1"である必要あり
echo $GOOGLE_CLOUD_PROJECT        # プロジェクトID
echo $VERTEX_AI_SEARCH_DATA_STORE_ID  # データストアID

# IAM権限の確認
gcloud projects get-iam-policy $GOOGLE_CLOUD_PROJECT \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/discoveryengine.viewer"
```

#### Agentic RAGの検索が遅い

```python
# 改善策:
# 1. top_k を 5〜10 に制限
# 2. 並列検索を活用
import asyncio

async def fast_multi_search(queries: List[str]) -> List[dict]:
    """複数クエリを並列で検索（レイテンシ削減）"""
    results = await asyncio.gather(
        *[search_async(q) for q in queries]
    )
    return [r for sublist in results for r in sublist]
```

### RAGパイプライン設計のベストプラクティス

```python
BEST_PRACTICES = {
    "コーパス設計": [
        "ドメインごとにコーパスを分離する",
        "意味のあるファイル名とメタデータを使用",
        "定期的にコンテンツを更新・再エンベディング",
        "重複ドキュメントを排除",
    ],
    "チャンキング": [
        "ドキュメントタイプに応じてチャンクサイズを調整",
        "文脈保持のためオーバーラップを20%程度確保",
        "コード・法的文書は専用のチャンキング戦略を使用",
        "チャンキング品質を実際のクエリでテスト",
    ],
    "検索品質": [
        "top_kは3〜5からスタートして調整",
        "min_scoreで品質フィルタリングを適用",
        "ハイブリッド検索（セマンティック + キーワード）を検討",
        "verbose modeで実際の検索結果を確認",
    ],
    "出典管理": [
        "citationsを常に有効化して透明性を確保",
        "ファイル名・ページ番号・セクションをメタデータに含める",
        "引用スタイルをユースケースに合わせてカスタマイズ",
        "内容更新時は必ず再エンベディング",
    ],
    "セキュリティ": [
        "プライベートデータには Vertex AI Search（IAM制御付き）を使用",
        "ユーザー入力をPluginでバリデーション",
        "プロンプトインジェクション対策（入力サニタイズ）",
        "機密データのコーパスへのアクセスを制限",
    ],
}
```

---

## まとめ

### 選択ガイド

| 要件 | 推奨アプローチ |
|-----|-------------|
| 最新のWeb情報が必要 | Google Search Grounding |
| 社内文書・プライベートデータ | Vertex AI Search Grounding |
| 複雑な検索ロジック・マルチステップ | Agentic RAG（カスタムベクトルDB） |
| 小〜中規模のナレッジベース | 単一コーパス |
| 大規模・複数ドメイン | 複数コーパス + 動的ルーティング |
| 精密な出典管理が必要 | Citation設定 + メタデータ充実 |
| 全Agentに共通ガードレール | Plugin |
| 特定Agentのカスタマイズ | Callback |
| Webページ取得 | load_web_page |
| 記憶の明示的検索 | LoadMemoryTool |
| 記憶の自動提供 | PreloadMemoryTool |
| Artifact参照 | LoadArtifactsTool |
| ユーザー選択肢提示 | GetUserChoiceTool |
| ループ終了制御 | ExitLoopTool |
