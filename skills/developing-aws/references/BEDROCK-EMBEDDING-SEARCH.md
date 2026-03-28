# Amazon Bedrock Embedding・セマンティック検索 リファレンス

Knowledge Basesを使わない**自前Embedding実装**のリファレンス。
テキスト・イメージのベクトル化からコサイン類似度計算、セマンティック検索の組み立て方までを扱う。

> RAG/Knowledge Bases → `RAG-AGENTS.md` / Bedrock API全般 → `BEDROCK-API.md`

---

## Embeddingモデル概要

### Bedrockで利用できるEmbeddingモデル

| モデル名 | モデルID | ベクトル次元数 | 対応入力 | 特徴 |
|---------|---------|------------|---------|------|
| **Titan Embeddings G1-Text** | `amazon.titan-embed-text-v1` | 1536 | テキストのみ | 英語テキスト向け基本モデル |
| **Titan Text Embeddings v2** | `amazon.titan-embed-text-v2:0` | 1024 / 512 / 256 | テキストのみ | 正規化対応、次元数選択可 |
| **Titan Multimodal Embeddings G1** | `amazon.titan-embed-image-v1` | 1024 | テキスト / イメージ / 両方 | クロスモーダル検索に対応 |
| **Cohere Embed English** | `cohere.embed-english-v3` | 1024 | テキストのみ | 英語特化、分類・検索向け |
| **Cohere Embed Multilingual** | `cohere.embed-multilingual-v3` | 1024 | テキストのみ | 多言語対応 |

> **重要**: 異なるモデルで生成したベクトルデータは互換性がない。比較は同一モデル内で行う。

### テキスト生成モデルとの違い

| 観点 | テキスト生成モデル | Embeddingモデル |
|-----|---------------|--------------|
| 出力 | テキスト（自然言語） | ベクトルデータ（実数の配列） |
| 使用API | `invoke_model` | `invoke_model`（同じ） |
| 活用方法 | 応答をそのまま利用 | ベクトルを元に自前で処理 |
| 主な用途 | 生成・要約・翻訳 | 類似検索・分類・クラスタリング |

---

## Titan Embeddings G1-Text

### テキストのEmbedding取得

```python
import boto3
import json

bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')

def get_embedding(text: str) -> list[float]:
    """テキストをEmbeddingしてベクトルデータを返す"""
    body = json.dumps({"inputText": text})

    response = bedrock.invoke_model(
        modelId='amazon.titan-embed-text-v1',
        body=body
    )

    response_body = json.loads(response['body'].read())
    return response_body['embedding']  # list[float] (1536次元)

# 使用例
vector = get_embedding("Hello, world!")
print(f"次元数: {len(vector)}")  # → 1536
```

### レスポンス構造

```json
{
  "embedding": [-0.746, -0.201, 0.149, ...],
  "inputTextTokenCount": 42
}
```

### 注意事項

- **言語制限**: Titan Embeddings G1-Textは英語テキスト向け。日本語は非推奨
- **トークン上限**: 8K トークン（`amazon.titan-embed-text-v1:2:8k`）
- **次元数**: 1536固定（Cohere Embed Englishは1024）

---

## コサイン類似度

### 計算原理

2つのベクトルA・Bの意味的な近さを0〜1で表す指標。

```
コサイン類似度 = (A・B) / (||A|| × ||B||)

A・B  : AとBの内積（各要素の積の合計）
||A|| : Aのノルム（各要素の2乗和の平方根）
```

- **1に近い**: 意味的に非常に似ている
- **0に近い**: 意味的に無関係
- **−1に近い**: 意味的に対立している（Embeddingでは稀）

### numpy実装

```python
import numpy as np

def cosine_similarity(vector1: list[float], vector2: list[float]) -> float:
    """2つのベクトルのコサイン類似度を計算する"""
    v1 = np.array(vector1)
    v2 = np.array(vector2)

    dot = np.dot(v1, v2)          # 内積
    norm1 = np.linalg.norm(v1)    # v1のノルム
    norm2 = np.linalg.norm(v2)    # v2のノルム

    return dot / (norm1 * norm2)
```

### scikit-learn実装（バッチ処理向け）

```python
from sklearn.metrics.pairwise import cosine_similarity as sklearn_cosine

# 複数ベクトルと1つのクエリの類似度を一括計算
import numpy as np

query_vec = np.array(get_embedding("search query")).reshape(1, -1)
doc_vecs  = np.array([item['embedding'] for item in docs])  # (N, 1536)

scores = sklearn_cosine(query_vec, doc_vecs)[0]  # shape: (N,)
```

---

## セマンティック類似性（テキスト間）

### 2テキストの類似度測定

```python
def check_similarity(text1: str, text2: str) -> float:
    """2つのテキストの意味的な類似度を返す（0〜1）"""
    vec1 = get_embedding(text1)
    vec2 = get_embedding(text2)
    return cosine_similarity(vec1, vec2)

# 使用例
score = check_similarity(
    "I feel great today.",
    "It is a good weather today."
)
print(f"類似度: {score:.4f}")  # → 0.55前後（高い類似）
```

### 類似度の解釈目安

| スコア範囲 | 解釈 | 例 |
|----------|------|-----|
| 0.8〜1.0 | 非常に高い類似 | 言い換え・同義表現 |
| 0.5〜0.8 | 高い類似 | 関連するトピック |
| 0.3〜0.5 | 中程度の類似 | 同ジャンル |
| 0.0〜0.3 | 低い類似 | 異なるトピック |

### 複数テキストの一括比較

```python
texts = ["I feel great today.", "Good weather!", "Overtime again..."]

# 全組み合わせの類似度を計算
for i in range(len(texts)):
    for j in range(i + 1, len(texts)):
        score = check_similarity(texts[i], texts[j])
        print(f"[{i}]-[{j}]: {score:.4f}")
```

---

## セマンティック検索（テキスト）

### アーキテクチャ

```
【インデックス作成フェーズ】
ドキュメント集合 → Embeddingモデル → ベクトルデータ配列 → JSON保存

【検索フェーズ】
クエリテキスト → Embeddingモデル → クエリベクトル
                                     ↓
                        コサイン類似度計算（全ドキュメントと）
                                     ↓
                             スコア降順ソート → Top-K返却
```

### インデックス作成

```python
import json

def build_index(documents: list[str]) -> list[dict]:
    """ドキュメントリストをEmbeddingしてインデックスを作成"""
    index = []
    for doc in documents:
        vector = get_embedding(doc)
        index.append({"content": doc, "embedding": vector})
    return index

# 保存
def save_index(index: list[dict], path: str) -> None:
    with open(path, 'w') as f:
        json.dump(index, f)

# 読み込み
def load_index(path: str) -> list[dict]:
    with open(path) as f:
        return json.load(f)

# 使用例
documents = [
    "Macintosh. Beautiful design. Suitable for creative work.",
    "Windows machine. Huge software ecosystem. Business standard.",
    "Linux machine. Open source. Used in development and research.",
    "Chromebook. Low cost. Cloud-first design. Educational use.",
]

index = build_index(documents)
save_index(index, 'embedding_index.json')
```

### 検索実行

```python
def semantic_search(query: str, index: list[dict], top_k: int = 1) -> list[dict]:
    """クエリに最も類似するドキュメントをTop-K件返す"""
    query_vec = get_embedding(query)

    scored = []
    for item in index:
        score = cosine_similarity(query_vec, item['embedding'])
        scored.append({"score": score, "content": item['content']})

    # スコア降順でソート
    scored.sort(key=lambda x: x['score'], reverse=True)
    return scored[:top_k]

# 使用例
index = load_index('embedding_index.json')
results = semantic_search("I want a computer for coding and servers.", index, top_k=3)

for r in results:
    print(f"score={r['score']:.4f}: {r['content'][:60]}...")
```

### セマンティック検索の適用ユースケース

| ユースケース | データ例 | クエリ例 |
|------------|---------|---------|
| 製品推薦 | 製品説明文 | 「軽くて持ち運べるPCが欲しい」 |
| Q&A検索 | FAQの回答文 | 「返金するにはどうすればいい？」 |
| 書類案内 | 申請書の説明文 | 「引っ越しの住所変更をしたい」 |
| コンテンツ分類 | カテゴリ説明文 | 分類したいコンテンツ |

---

## Titan Multimodal Embeddings G1

### 概要

| 項目 | 仕様 |
|-----|------|
| モデルID | `amazon.titan-embed-image-v1` |
| ベクトル次元数 | 1024 |
| 対応入力 | `inputText`（テキスト）/ `inputImage`（Base64画像）/ 両方 |
| 対応画像形式 | PNG, JPEG |
| 互換性 | Titan Embeddings G1-Text（1536次元）とは**非互換** |

### リクエストボディ構造

```json
{
  "inputText": "テキスト（省略可）",
  "inputImage": "Base64エンコード画像データ（省略可）"
}
```

- `inputText`のみ → テキストEmbedding（1024次元）
- `inputImage`のみ → 画像Embedding（1024次元）
- 両方 → マルチモーダルEmbedding（1024次元）

### 画像+テキストのEmbedding取得

```python
import base64
import json
import boto3

bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
MODEL_ID = 'amazon.titan-embed-image-v1'

def image_to_base64(file_path: str) -> str:
    with open(file_path, 'rb') as f:
        return base64.b64encode(f.read()).decode('utf-8')

def get_multimodal_embedding(
    text: str | None = None,
    image_path: str | None = None
) -> list[float]:
    """テキスト・画像・両方からEmbeddingを取得（1024次元）"""
    payload: dict = {}

    if text:
        payload['inputText'] = text
    if image_path:
        payload['inputImage'] = image_to_base64(image_path)

    if not payload:
        raise ValueError("text または image_path のいずれかを指定してください")

    response = bedrock.invoke_model(
        modelId=MODEL_ID,
        body=json.dumps(payload)
    )
    body = json.loads(response['body'].read())
    return body['embedding']  # list[float] (1024次元)
```

---

## イメージ間セマンティック検索

### インデックス作成（画像フォルダ → ベクトルDB）

```python
import os

def build_image_index(folder: str) -> list[dict]:
    """フォルダ内の全画像をEmbeddingしてインデックスを作成"""
    index = []
    for filename in os.listdir(folder):
        file_path = os.path.join(folder, filename)
        vector = get_multimodal_embedding(image_path=file_path)
        index.append({"file": file_path, "vector": vector})
        print(f"  Embedded: {filename}")
    return index

# 保存・読み込みはテキストと同様（JSON）
image_index = build_image_index('./data')
save_index(image_index, 'image_embedding.json')
```

### 類似画像の検索

```python
def search_similar_image(
    query_image_path: str,
    index: list[dict],
    top_k: int = 1
) -> list[dict]:
    """クエリ画像に最も似た画像をTop-K件返す"""
    query_vec = get_multimodal_embedding(image_path=query_image_path)

    scored = []
    for item in index:
        score = cosine_similarity(query_vec, item['vector'])
        scored.append({"score": score, "file": item['file']})

    scored.sort(key=lambda x: x['score'], reverse=True)
    return scored[:top_k]

# 使用例
image_index = load_index('image_embedding.json')
results = search_similar_image('query.png', image_index, top_k=3)

for r in results:
    print(f"score={r['score']:.4f}: {r['file']}")
```

---

## テキストによるイメージ検索（クロスモーダル）

### 重要: 同一モデルの使用

テキストと画像のEmbeddingを比較するには、**同じモデル**（`amazon.titan-embed-image-v1`）でテキストのベクトルも生成する。

```python
def get_text_embedding_for_image_search(text: str) -> list[float]:
    """
    画像インデックスと比較するためのテキストEmbedding。
    必ず titan-embed-image-v1 を使う（1024次元で統一）。
    """
    return get_multimodal_embedding(text=text)  # inputTextのみ指定

# NG: Titan Embeddings G1-Text（1536次元）は画像インデックスと非互換
# NG: get_embedding(text)  → 1536次元なのでコサイン計算できない
```

### テキストでイメージを検索

```python
def search_image_by_text(
    query_text: str,
    image_index: list[dict],
    top_k: int = 1
) -> list[dict]:
    """テキストクエリで最も類似する画像をTop-K件返す"""
    query_vec = get_text_embedding_for_image_search(query_text)

    scored = []
    for item in image_index:
        score = cosine_similarity(query_vec, item['vector'])
        scored.append({"score": score, "file": item['file']})

    scored.sort(key=lambda x: x['score'], reverse=True)
    return scored[:top_k]

# 使用例
image_index = load_index('image_embedding.json')

results = search_image_by_text("ukiyo-e painting", image_index, top_k=1)
print(f"最適な画像: {results[0]['file']}")

results = search_image_by_text("watercolor landscape", image_index, top_k=3)
for r in results:
    print(f"score={r['score']:.4f}: {r['file']}")
```

---

## モデル比較・選定

### テキスト検索 vs マルチモーダル検索

| 観点 | Titan Embeddings G1-Text | Titan Multimodal G1 |
|-----|------------------------|-------------------|
| テキスト検索 | ✅ 向き（1536次元で高精度） | ✅ 使用可（1024次元） |
| 画像検索 | ❌ 不可 | ✅ 使用可 |
| テキスト→画像検索 | ❌ 不可 | ✅ 使用可（同モデルで統一） |
| ベクトル次元 | 1536 | 1024 |
| 言語 | 英語向け | 英語向け |

### 選定フローチャート

```
Embeddingモデル選定
  ├─ 画像を含む検索が必要？
  │   └─ YES → Titan Multimodal Embeddings G1 (titan-embed-image-v1)
  │
  └─ テキストのみ
      ├─ 多言語対応が必要？ → Cohere Embed Multilingual
      ├─ 高次元で精度重視？ → Titan Embeddings G1-Text (1536次元)
      └─ 次元数を柔軟に選びたい → Titan Text Embeddings v2
```

---

## セキュリティ・コスト考慮

### IAMポリシー（最小権限）

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["bedrock:InvokeModel"],
      "Resource": [
        "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1",
        "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-image-v1"
      ]
    }
  ]
}
```

### コスト最適化

| 戦略 | 内容 |
|-----|------|
| **インデックスキャッシュ** | ドキュメント変更時のみ再Embedding。結果をJSON/DynamoDBに保存 |
| **バッチEmbedding** | ドキュメント追加時にまとめて処理してAPI呼び出し回数を削減 |
| **次元数削減** | Titan Text v2は256/512次元も選択可。精度と費用のトレードオフ |
| **モデル選択** | テキストのみなら Titan Embeddings G1-Text（画像モデルより安価） |

### エラーハンドリング

```python
from botocore.exceptions import ClientError
import time

def get_embedding_with_retry(text: str, max_retries: int = 3) -> list[float]:
    for attempt in range(max_retries):
        try:
            return get_embedding(text)
        except ClientError as e:
            if e.response['Error']['Code'] == 'ThrottlingException':
                wait = 2 ** attempt  # exponential backoff
                time.sleep(wait)
            else:
                raise
    raise RuntimeError(f"Failed after {max_retries} retries")
```
