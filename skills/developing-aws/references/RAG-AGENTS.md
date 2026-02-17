# RAG & Agents リファレンス

## Knowledge Bases 概要

### アーキテクチャ

Amazon Bedrock Knowledge Basesは、企業データをFoundation Modelsと統合するためのマネージドRAG（Retrieval-Augmented Generation）ソリューション。

**基本フロー**:
```
1. データ取り込み → 2. チャンク化 → 3. 埋め込み生成 → 4. ベクトルストアへ保存
↓
5. ユーザークエリ → 6. ベクトル検索 → 7. 関連文書取得 → 8. LLMへコンテキスト注入
```

---

## データソース統合

### サポートされるデータソース

| データソース | 形式 | 用途 |
|------------|------|------|
| **Amazon S3** | PDF, TXT, MD, HTML, DOCX, CSV | ドキュメント、マニュアル |
| **Confluence** | Wiki | 社内ナレッジベース |
| **Salesforce** | CRM | 顧客情報 |
| **SharePoint** | ドキュメント | 社内ファイル |
| **Web Crawler** | Webページ | 公開ドキュメント |

### S3データソースの設定

```python
import boto3

bedrock_agent = boto3.client('bedrock-agent')

# Knowledge Base作成
knowledge_base_response = bedrock_agent.create_knowledge_base(
    name='enterprise-docs',
    description='企業ドキュメントのナレッジベース',
    roleArn='arn:aws:iam::123456789012:role/BedrockKBRole',
    knowledgeBaseConfiguration={
        'type': 'VECTOR',
        'vectorKnowledgeBaseConfiguration': {
            'embeddingModelArn': 'arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0'
        }
    },
    storageConfiguration={
        'type': 'OPENSEARCH_SERVERLESS',
        'opensearchServerlessConfiguration': {
            'collectionArn': 'arn:aws:aoss:us-east-1:123456789012:collection/kb-collection',
            'vectorIndexName': 'bedrock-knowledge-base-index',
            'fieldMapping': {
                'vectorField': 'embedding',
                'textField': 'text',
                'metadataField': 'metadata'
            }
        }
    }
)

kb_id = knowledge_base_response['knowledgeBase']['knowledgeBaseId']

# データソース追加（S3）
bedrock_agent.create_data_source(
    knowledgeBaseId=kb_id,
    name='s3-documents',
    dataSourceConfiguration={
        'type': 'S3',
        's3Configuration': {
            'bucketArn': 'arn:aws:s3:::my-knowledge-base-bucket',
            'inclusionPrefixes': ['documents/']
        }
    }
)
```

---

## ベクトルストア

### サポートされるベクトルデータベース

| データベース | 特徴 | 推奨用途 |
|------------|------|---------|
| **OpenSearch Serverless** | マネージド、スケーラブル | 本番環境、大規模データ |
| **Amazon Aurora PostgreSQL** | RDS統合、pgvector | 既存RDS環境 |
| **Pinecone** | サードパーティ、高性能 | 専用ベクトルDB |
| **Redis Enterprise Cloud** | インメモリ、高速 | リアルタイム検索 |

### ベクトルストア比較

| 項目 | OpenSearch Serverless | Aurora PostgreSQL | Pinecone |
|------|---------------------|-------------------|----------|
| **管理** | フルマネージド | フルマネージド | フルマネージド |
| **スケーラビリティ** | 自動スケール | 手動/自動 | 自動スケール |
| **コスト** | 中 | 低 | 高 |
| **検索速度** | 高速 | 中速 | 最速 |
| **統合** | AWS統合 | RDS統合 | API統合 |

---

## チャンク戦略

### チャンクパラメータ

```python
# データソース設定でチャンク戦略を指定
chunking_configuration = {
    'chunkingStrategy': 'FIXED_SIZE',  # または 'SEMANTIC', 'NONE'
    'fixedSizeChunkingConfiguration': {
        'maxTokens': 300,  # チャンクサイズ
        'overlapPercentage': 20  # オーバーラップ率
    }
}
```

### チャンク戦略の選択

| 戦略 | 説明 | 用途 |
|------|------|------|
| **FIXED_SIZE** | 固定トークン数で分割 | 汎用（デフォルト） |
| **SEMANTIC** | 意味的な境界で分割 | 文脈を保持したい場合 |
| **NONE** | 分割なし | 短いドキュメント |

### 推奨設定

| ドキュメントタイプ | チャンクサイズ | オーバーラップ |
|-----------------|--------------|-------------|
| 技術ドキュメント | 300-500トークン | 10-20% |
| FAQ | 100-200トークン | 0-10% |
| 長文記事 | 500-800トークン | 20-30% |
| コードドキュメント | 200-400トークン | 10-20% |

---

## RAG実装パターン

### 基本RAGパイプライン

```python
import boto3
import json

bedrock_runtime = boto3.client('bedrock-runtime')
bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')

def rag_query(question: str, kb_id: str) -> str:
    """
    RAGクエリの実行: 検索 → 拡張 → 生成
    """
    # 1. ベクトル検索
    retrieve_response = bedrock_agent_runtime.retrieve(
        knowledgeBaseId=kb_id,
        retrievalQuery={
            'text': question
        },
        retrievalConfiguration={
            'vectorSearchConfiguration': {
                'numberOfResults': 5  # 取得する文書数
            }
        }
    )

    # 2. 関連文書を取得
    documents = retrieve_response['retrievalResults']

    # 3. コンテキストを構築
    context = "\n\n".join([doc['content']['text'] for doc in documents])

    # 4. LLMにコンテキストを注入して生成
    prompt = f"""
以下のコンテキストを参照して質問に答えてください。

<context>
{context}
</context>

<question>
{question}
</question>

回答:
"""

    request_body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "messages": [
            {"role": "user", "content": prompt}
        ]
    }

    response = bedrock_runtime.invoke_model(
        modelId='anthropic.claude-3-sonnet-20240229-v1:0',
        body=json.dumps(request_body)
    )

    response_body = json.loads(response['body'].read())
    return response_body['content'][0]['text']

# 使用例
answer = rag_query(
    question="AWS Lambdaの料金体系は？",
    kb_id='ABCDEFGHIJ'
)
print(answer)
```

### Retrieve and Generate API

Knowledge BaseとLLMを自動統合するAPI:

```python
def rag_query_simple(question: str, kb_id: str) -> str:
    """
    Retrieve and Generate APIで簡単にRAG実行
    """
    response = bedrock_agent_runtime.retrieve_and_generate(
        input={
            'text': question
        },
        retrieveAndGenerateConfiguration={
            'type': 'KNOWLEDGE_BASE',
            'knowledgeBaseConfiguration': {
                'knowledgeBaseId': kb_id,
                'modelArn': 'arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0',
                'retrievalConfiguration': {
                    'vectorSearchConfiguration': {
                        'numberOfResults': 5
                    }
                }
            }
        }
    )

    return response['output']['text']
```

### Hybrid Search

ベクトル検索 + キーワード検索の組み合わせ:

```python
retrieve_response = bedrock_agent_runtime.retrieve(
    knowledgeBaseId=kb_id,
    retrievalQuery={'text': question},
    retrievalConfiguration={
        'vectorSearchConfiguration': {
            'numberOfResults': 10,
            'overrideSearchType': 'HYBRID'  # ベクトル + キーワード
        }
    }
)
```

### ReRanking

検索結果の再ランキング:

```python
# Retrieve with ReRanking
retrieve_response = bedrock_agent_runtime.retrieve(
    knowledgeBaseId=kb_id,
    retrievalQuery={'text': question},
    retrievalConfiguration={
        'vectorSearchConfiguration': {
            'numberOfResults': 20,
            'overrideSearchType': 'HYBRID'
        }
    }
)

# Cohere ReRankを使用して再ランキング
from cohere import Client

cohere_client = Client(api_key='...')

documents = [doc['content']['text'] for doc in retrieve_response['retrievalResults']]

rerank_response = cohere_client.rerank(
    query=question,
    documents=documents,
    top_n=5,
    model='rerank-english-v2.0'
)

# 上位5件を取得
top_docs = [documents[result.index] for result in rerank_response.results]
```

---

## Bedrock Agents

### Agent概要

Bedrock Agentsは、マルチステップ推論と外部システム統合を可能にするエージェントフレームワーク。

**主要機能**:
- **マルチステップ推論**: 複雑なタスクを分解して実行
- **Action Groups**: Lambda関数を呼び出して外部システムと連携
- **Knowledge Base統合**: RAGを自動実行
- **Return of Control**: 人間の承認を要求

### Agentアーキテクチャ

```
ユーザー入力
    ↓
Agent（LLM）
    ↓ 推論
    ├─ Knowledge Base検索
    ├─ Action Group実行（Lambda呼び出し）
    └─ 次のステップを計画
    ↓
最終回答
```

### Agent作成

```python
import boto3

bedrock_agent = boto3.client('bedrock-agent')

# Agent作成
agent_response = bedrock_agent.create_agent(
    agentName='customer-support-agent',
    description='カスタマーサポート用エージェント',
    foundationModel='anthropic.claude-3-sonnet-20240229-v1:0',
    instruction="""
あなたは親切なカスタマーサポートエージェントです。
以下のタスクを実行できます:
1. 注文状況の確認
2. 返品処理
3. FAQ検索
4. エスカレーション
""",
    idleSessionTTLInSeconds=1800,
    agentResourceRoleArn='arn:aws:iam::123456789012:role/BedrockAgentRole'
)

agent_id = agent_response['agent']['agentId']
```

### Action Group設定

```python
# Lambda関数をAction Groupとして登録
bedrock_agent.create_agent_action_group(
    agentId=agent_id,
    agentVersion='DRAFT',
    actionGroupName='order-management',
    description='注文管理アクション',
    actionGroupExecutor={
        'lambda': 'arn:aws:lambda:us-east-1:123456789012:function:OrderManagementFunction'
    },
    apiSchema={
        'payload': json.dumps({
            "openapi": "3.0.0",
            "info": {"title": "Order Management API", "version": "1.0.0"},
            "paths": {
                "/getOrderStatus": {
                    "post": {
                        "summary": "注文状況を取得",
                        "operationId": "getOrderStatus",
                        "requestBody": {
                            "content": {
                                "application/json": {
                                    "schema": {
                                        "type": "object",
                                        "properties": {
                                            "orderId": {"type": "string"}
                                        },
                                        "required": ["orderId"]
                                    }
                                }
                            }
                        },
                        "responses": {
                            "200": {
                                "description": "成功",
                                "content": {
                                    "application/json": {
                                        "schema": {
                                            "type": "object",
                                            "properties": {
                                                "status": {"type": "string"},
                                                "estimatedDelivery": {"type": "string"}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        })
    }
)
```

### Lambda関数（Action Group）

```python
import json

def lambda_handler(event, context):
    """
    Bedrock Agent Action Group用Lambda関数
    """
    api_path = event['apiPath']
    parameters = event.get('parameters', [])

    if api_path == '/getOrderStatus':
        order_id = next(
            (param['value'] for param in parameters if param['name'] == 'orderId'),
            None
        )

        # 注文状況を取得（実際のDB検索等）
        order_status = {
            'orderId': order_id,
            'status': '配送中',
            'estimatedDelivery': '2025-03-15'
        }

        return {
            'messageVersion': '1.0',
            'response': {
                'actionGroup': event['actionGroup'],
                'apiPath': api_path,
                'httpMethod': event['httpMethod'],
                'httpStatusCode': 200,
                'responseBody': {
                    'application/json': {
                        'body': json.dumps(order_status)
                    }
                }
            }
        }
```

### Knowledge Base統合

```python
# AgentにKnowledge Baseを関連付け
bedrock_agent.associate_agent_knowledge_base(
    agentId=agent_id,
    agentVersion='DRAFT',
    description='FAQナレッジベース',
    knowledgeBaseId='KBID123456',
    knowledgeBaseState='ENABLED'
)
```

### Agent実行

```python
bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')

# Agentを準備
bedrock_agent.prepare_agent(agentId=agent_id)

# Agentを呼び出し
response = bedrock_agent_runtime.invoke_agent(
    agentId=agent_id,
    agentAliasId='TSTALIASID',
    sessionId='session-123',
    inputText='注文番号ABC123の配送状況を教えてください'
)

# レスポンスを処理
for event in response['completion']:
    if 'chunk' in event:
        chunk = event['chunk']
        print(chunk.get('bytes', b'').decode('utf-8'), end='', flush=True)
```

---

## オープンソースフレームワーク統合

### LangChain統合

```python
from langchain_aws import BedrockEmbeddings, ChatBedrock
from langchain.vectorstores import FAISS
from langchain.chains import RetrievalQA
from langchain.document_loaders import S3DirectoryLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter

# 1. ドキュメント読み込み
loader = S3DirectoryLoader('my-bucket', prefix='documents/')
documents = loader.load()

# 2. チャンク化
text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,
    chunk_overlap=50
)
chunks = text_splitter.split_documents(documents)

# 3. 埋め込み生成
embeddings = BedrockEmbeddings(
    model_id="amazon.titan-embed-text-v2:0",
    region_name="us-east-1"
)

# 4. ベクトルストア作成
vectorstore = FAISS.from_documents(chunks, embeddings)

# 5. LLM設定
llm = ChatBedrock(
    model_id="anthropic.claude-3-sonnet-20240229-v1:0",
    model_kwargs={"temperature": 0.7}
)

# 6. RAGチェーン構築
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    chain_type="stuff",
    retriever=vectorstore.as_retriever(search_kwargs={"k": 5})
)

# 7. 質問実行
answer = qa_chain.invoke("AWS Lambdaの料金体系は？")
print(answer['result'])
```

### LlamaIndex統合

```python
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader, Settings
from llama_index.llms.bedrock import Bedrock
from llama_index.embeddings.bedrock import BedrockEmbedding

# 1. LLMと埋め込みモデル設定
Settings.llm = Bedrock(
    model="anthropic.claude-3-sonnet-20240229-v1:0",
    temperature=0.7
)
Settings.embed_model = BedrockEmbedding(
    model="amazon.titan-embed-text-v2:0"
)

# 2. ドキュメント読み込み
documents = SimpleDirectoryReader('data/').load_data()

# 3. インデックス作成
index = VectorStoreIndex.from_documents(documents)

# 4. クエリエンジン作成
query_engine = index.as_query_engine(similarity_top_k=5)

# 5. 質問実行
response = query_engine.query("AWS Lambdaの料金体系は？")
print(response)
```

---

## Amazon Q

### Amazon Q Business

エンタープライズ向けAIアシスタント。企業データを統合してビジネスユーザーが活用可能。

**主要機能**:
- 自然言語でのデータ検索
- 複数データソース統合（S3、Confluence、Salesforce等）
- ファイルアップロード＆質問
- ビジネス分析支援

### Amazon Q Developer

開発者向けコーディングアシスタント。

**主要機能**:
- コード生成・補完
- バグ修正提案
- AWSリソース操作支援
- セキュリティスキャン

---

## モデル評価

### Bedrock Model Evaluation

```python
bedrock = boto3.client('bedrock')

# 評価ジョブ作成
evaluation_job = bedrock.create_evaluation_job(
    jobName='text-generation-eval',
    jobDescription='テキスト生成モデルの評価',
    roleArn='arn:aws:iam::123456789012:role/BedrockEvalRole',
    evaluationConfig={
        'automated': {
            'datasetMetricConfigs': [
                {
                    'taskType': 'Summarization',
                    'dataset': {
                        'name': 'summarization-dataset',
                        'datasetLocation': {
                            's3Uri': 's3://my-bucket/eval-data/summarization.jsonl'
                        }
                    },
                    'metricNames': ['ROUGE', 'BERTScore']
                }
            ]
        }
    },
    inferenceConfig={
        'models': [
            {
                'bedrockModel': {
                    'modelIdentifier': 'anthropic.claude-3-sonnet-20240229-v1:0',
                    'inferenceParams': json.dumps({
                        'temperature': 0.7,
                        'max_tokens': 512
                    })
                }
            }
        ]
    },
    outputDataConfig={
        's3Uri': 's3://my-bucket/eval-results/'
    }
)
```

### 自動評価メトリクス

| メトリクス | 説明 | 用途 |
|----------|------|------|
| **ROUGE** | n-gramの重複度 | 要約、翻訳 |
| **BERTScore** | 意味的類似度 | テキスト生成全般 |
| **BLEU** | 翻訳品質 | 機械翻訳 |
| **Perplexity** | モデルの不確実性 | 言語モデル評価 |

### 人間評価

```python
# 人間評価用のワークフローを設定
evaluation_job = bedrock.create_evaluation_job(
    jobName='human-eval',
    evaluationConfig={
        'human': {
            'datasetMetricConfigs': [
                {
                    'taskType': 'General',
                    'dataset': {
                        'name': 'qa-dataset',
                        'datasetLocation': {
                            's3Uri': 's3://my-bucket/human-eval/qa.jsonl'
                        }
                    },
                    'humanWorkflowConfig': {
                        'flowDefinitionArn': 'arn:aws:sagemaker:us-east-1:123456789012:flow-definition/human-eval',
                        'instructions': '回答の正確性を1-5で評価してください'
                    }
                }
            ]
        }
    }
    # ...
)
```

---

## まとめ

このリファレンスでは、RAG実装、Bedrock Agents、オープンソースフレームワーク統合、Amazon Q、モデル評価について解説した。実装時は以下の点に注意:

- **Knowledge Bases**: 適切なチャンク戦略とベクトルストアを選択
- **RAG最適化**: Hybrid Search、ReRankingを活用
- **Agents**: Action Groupsで外部システムと統合
- **フレームワーク**: LangChain/LlamaIndexで開発効率向上
- **評価**: 自動評価と人間評価を組み合わせて品質保証
