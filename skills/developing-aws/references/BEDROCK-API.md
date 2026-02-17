# Amazon Bedrock API リファレンス

## Amazon Bedrock 概要

### サービスアーキテクチャ

Amazon Bedrockは、AWS上でFoundation Models（基盤モデル）を利用するためのフルマネージドサービス。以下の特徴を持つ:

- **マルチモデル対応**: 複数のモデルプロバイダー（Anthropic Claude、Meta Llama、Amazon Titan、Stability AI等）から選択可能
- **サーバーレスAPI**: インフラ管理不要でモデルを呼び出し
- **セキュアな実行環境**: データはAWSアカウント内で処理され、モデルのトレーニングには使用されない
- **統合されたツールセット**: Agents、Knowledge Bases、Guardrailsが統合

### Bedrock コンポーネント

| コンポーネント | 説明 | 用途 |
|------------|------|------|
| **Foundation Models** | 事前学習済みの大規模モデル | テキスト生成、画像生成、埋め込み |
| **Agents** | マルチステップ推論エージェント | 複雑なタスクの自動化 |
| **Knowledge Bases** | RAG用のベクトルストア統合 | 企業データとの統合 |
| **Guardrails** | コンテンツフィルタリング | 有害コンテンツの検出・ブロック |
| **Model Evaluation** | 自動評価フレームワーク | モデル性能の測定 |

---

## Foundation Models 選定

### 利用可能なモデルファミリー

#### 1. Anthropic Claude

| モデル | パラメータ | 用途 | コスト効率 | コンテキスト長 |
|--------|-----------|------|-----------|------------|
| **Claude 3.5 Sonnet** | - | 複雑な推論、コード生成 | 中 | 200K tokens |
| **Claude 3 Opus** | - | 最高品質の出力 | 低 | 200K tokens |
| **Claude 3 Haiku** | - | 高速応答、簡単なタスク | 高 | 200K tokens |
| **Claude 2.1** | - | 汎用テキスト生成 | 中 | 200K tokens |

**選定基準**:
- **Opus**: 最高品質が必要な場合（法務文書、医療記録分析）
- **Sonnet**: バランス重視（カスタマーサポート、コンテンツ生成）
- **Haiku**: レイテンシとコスト重視（チャットボット、要約）

#### 2. Meta Llama

| モデル | パラメータ | 用途 | コンテキスト長 |
|--------|-----------|------|------------|
| **Llama 3.3 70B** | 70B | 汎用テキスト生成 | 128K tokens |
| **Llama 3.1 405B** | 405B | 複雑な推論 | 128K tokens |
| **Llama 3.1 8B** | 8B | 軽量タスク | 128K tokens |

**特徴**: オープンソース由来、カスタマイズ性が高い

#### 3. Amazon Titan

| モデル | 用途 | 特徴 |
|--------|------|------|
| **Titan Text Premier** | 汎用テキスト | RAG最適化 |
| **Titan Text Express** | 高速応答 | コスト効率重視 |
| **Titan Text Lite** | 軽量タスク | 最小レイテンシ |
| **Titan Embeddings v2** | テキスト埋め込み | 8192次元ベクトル |
| **Titan Image Generator** | 画像生成 | テキストから画像 |
| **Titan Multimodal Embeddings** | マルチモーダル埋め込み | 画像+テキスト検索 |

#### 4. Stability AI

| モデル | 用途 | 解像度 |
|--------|------|-------|
| **Stable Diffusion XL** | 画像生成 | 最大1024x1024 |
| **Stable Diffusion Ultra** | 高品質画像 | 最大2048x2048 |

#### 5. Cohere

| モデル | 用途 |
|--------|------|
| **Command** | テキスト生成 |
| **Command Light** | 軽量タスク |
| **Embed** | テキスト埋め込み |

### モデル選定フローチャート

```
タスク分類
  ├─ テキスト生成
  │   ├─ 複雑な推論必要 → Claude Opus / Llama 405B
  │   ├─ バランス重視 → Claude Sonnet / Llama 70B
  │   └─ コスト・速度重視 → Claude Haiku / Titan Express
  │
  ├─ コード生成
  │   └─ Claude Sonnet (最適)
  │
  ├─ 埋め込み生成
  │   ├─ テキストのみ → Titan Embeddings v2 / Cohere Embed
  │   └─ マルチモーダル → Titan Multimodal Embeddings
  │
  └─ 画像生成
      └─ Stable Diffusion XL / Titan Image Generator
```

---

## プロンプトエンジニアリング

### 基本手法

#### 1. Zero-shot Prompting

```python
prompt = """
以下のテキストを要約してください:

{text}
"""
```

#### 2. Few-shot Prompting

```python
prompt = """
以下の例に従って、カテゴリ分類を行ってください:

例1:
入力: "商品が届きません"
出力: カテゴリ=配送問題

例2:
入力: "返金してください"
出力: カテゴリ=返金リクエスト

入力: {user_query}
出力:
"""
```

#### 3. Chain-of-Thought (CoT)

```python
prompt = """
問題: {problem}

ステップバイステップで考えてください:
1. まず...
2. 次に...
3. 最後に...

答え:
"""
```

### Bedrock固有のパラメータ

| パラメータ | 範囲 | 説明 | 推奨値 |
|----------|------|------|--------|
| **temperature** | 0.0-1.0 | ランダム性の制御 | 創造的: 0.7-1.0<br/>決定論的: 0.0-0.3 |
| **top_p** | 0.0-1.0 | Nucleus sampling | 0.9 (デフォルト) |
| **top_k** | 1-500 | 候補トークン数 | 50-100 |
| **max_tokens** | 1-4096 | 最大出力長 | タスクに応じて |
| **stop_sequences** | - | 生成停止シーケンス | `["\n\n", "###"]` |

### プロンプト設計のベストプラクティス

```python
# 良いプロンプトの構造
prompt_template = """
<role>
あなたは経験豊富な技術ライターです。
</role>

<task>
以下のAPIドキュメントをエンドユーザー向けに書き直してください。
</task>

<context>
対象読者: プログラミング初心者
文体: フレンドリーで分かりやすい
</context>

<input>
{api_documentation}
</input>

<output_format>
- 概要（2-3文）
- 主要な機能（箇条書き）
- コード例（Pythonで記述）
</output_format>
"""
```

---

## Bedrock API

### API エンドポイント

| API | 用途 | 同期/非同期 |
|-----|------|-----------|
| **InvokeModel** | 単一リクエスト・レスポンス | 同期 |
| **InvokeModelWithResponseStream** | ストリーミング応答 | 同期（ストリーム） |
| **Converse** | 会話履歴を保持 | 同期 |
| **ConverseStream** | 会話 + ストリーミング | 同期（ストリーム） |

### 1. InvokeModel API

#### Python (boto3)

```python
import boto3
import json

bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')

# リクエストボディ
request_body = {
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 1024,
    "temperature": 0.7,
    "messages": [
        {
            "role": "user",
            "content": "Amazon Bedrockとは何ですか？"
        }
    ]
}

# API呼び出し
response = bedrock.invoke_model(
    modelId='anthropic.claude-3-sonnet-20240229-v1:0',
    body=json.dumps(request_body)
)

# レスポンス解析
response_body = json.loads(response['body'].read())
output_text = response_body['content'][0]['text']
print(output_text)
```

#### TypeScript SDK

```typescript
import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";

const client = new BedrockRuntimeClient({ region: "us-east-1" });

const requestBody = {
  anthropic_version: "bedrock-2023-05-31",
  max_tokens: 1024,
  temperature: 0.7,
  messages: [
    {
      role: "user",
      content: "Amazon Bedrockとは何ですか？"
    }
  ]
};

const command = new InvokeModelCommand({
  modelId: "anthropic.claude-3-sonnet-20240229-v1:0",
  body: JSON.stringify(requestBody)
});

const response = await client.send(command);
const responseBody = JSON.parse(new TextDecoder().decode(response.body));
console.log(responseBody.content[0].text);
```

### 2. InvokeModelWithResponseStream API

```python
import boto3
import json

bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')

request_body = {
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 1024,
    "messages": [
        {"role": "user", "content": "AIの歴史を説明してください"}
    ]
}

response = bedrock.invoke_model_with_response_stream(
    modelId='anthropic.claude-3-sonnet-20240229-v1:0',
    body=json.dumps(request_body)
)

# ストリームを処理
for event in response['body']:
    chunk = json.loads(event['chunk']['bytes'])
    if chunk['type'] == 'content_block_delta':
        print(chunk['delta']['text'], end='', flush=True)
```

### 3. Converse API

会話履歴を管理するための簡易API:

```python
import boto3

bedrock = boto3.client('bedrock-runtime')

# 会話履歴
conversation_history = [
    {
        "role": "user",
        "content": [{"text": "Pythonで Hello World を書いてください"}]
    },
    {
        "role": "assistant",
        "content": [{"text": "print('Hello, World!')"}]
    },
    {
        "role": "user",
        "content": [{"text": "これを関数にしてください"}]
    }
]

response = bedrock.converse(
    modelId='anthropic.claude-3-sonnet-20240229-v1:0',
    messages=conversation_history,
    inferenceConfig={
        "maxTokens": 512,
        "temperature": 0.7
    }
)

print(response['output']['message']['content'][0]['text'])
```

### エラーハンドリング

```python
from botocore.exceptions import ClientError

try:
    response = bedrock.invoke_model(
        modelId='anthropic.claude-3-sonnet-20240229-v1:0',
        body=json.dumps(request_body)
    )
except ClientError as e:
    error_code = e.response['Error']['Code']

    if error_code == 'ThrottlingException':
        # レート制限に達した場合の再試行ロジック
        print("Rate limit exceeded. Retrying with exponential backoff...")
    elif error_code == 'ModelNotReadyException':
        # モデルがまだ準備できていない
        print("Model is not ready. Please try again later.")
    elif error_code == 'ValidationException':
        # リクエストが無効
        print(f"Invalid request: {e.response['Error']['Message']}")
    else:
        raise
```

---

## マルチモーダル

### マルチモーダル対応モデル

| モデル | テキスト | 画像 | ドキュメント | 動画 |
|--------|---------|------|------------|------|
| **Claude 3.5 Sonnet** | ✓ | ✓ | ✓ | - |
| **Claude 3 Opus** | ✓ | ✓ | ✓ | - |
| **Claude 3 Haiku** | ✓ | ✓ | ✓ | - |

### 画像理解

```python
import boto3
import json
import base64

bedrock = boto3.client('bedrock-runtime')

# 画像を読み込み
with open('image.jpg', 'rb') as f:
    image_bytes = f.read()
    image_base64 = base64.b64encode(image_bytes).decode('utf-8')

request_body = {
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 1024,
    "messages": [
        {
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": image_base64
                    }
                },
                {
                    "type": "text",
                    "text": "この画像に何が写っていますか？"
                }
            ]
        }
    ]
}

response = bedrock.invoke_model(
    modelId='anthropic.claude-3-sonnet-20240229-v1:0',
    body=json.dumps(request_body)
)

response_body = json.loads(response['body'].read())
print(response_body['content'][0]['text'])
```

### ドキュメント解析

```python
# PDFドキュメントの解析
request_body = {
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 2048,
    "messages": [
        {
            "role": "user",
            "content": [
                {
                    "type": "document",
                    "source": {
                        "type": "base64",
                        "media_type": "application/pdf",
                        "data": pdf_base64
                    }
                },
                {
                    "type": "text",
                    "text": "このPDFの要点を箇条書きでまとめてください"
                }
            ]
        }
    ]
}
```

### 画像生成（Stable Diffusion）

```python
request_body = {
    "text_prompts": [
        {"text": "A futuristic city with flying cars, high detail, 4K", "weight": 1.0}
    ],
    "cfg_scale": 10,
    "seed": 42,
    "steps": 50,
    "width": 1024,
    "height": 1024
}

response = bedrock.invoke_model(
    modelId='stability.stable-diffusion-xl-v1',
    body=json.dumps(request_body)
)

response_body = json.loads(response['body'].read())
image_base64 = response_body['artifacts'][0]['base64']

# 画像を保存
with open('generated_image.png', 'wb') as f:
    f.write(base64.b64decode(image_base64))
```

---

## Bedrock Playground

### テキストプレイグラウンド

コンソールからブラウザで直接モデルをテスト:

1. AWS Console → Bedrock → Playgrounds → Text
2. モデル選択（Claude 3.5 Sonnet等）
3. パラメータ調整（temperature、max_tokens等）
4. プロンプト入力 → Run

### チャットプレイグラウンド

会話形式でテスト:

1. Playgrounds → Chat
2. モデル選択
3. System prompt設定（オプション）
4. 会話を開始

### 画像プレイグラウンド

画像生成をテスト:

1. Playgrounds → Image
2. Stable Diffusion XL等を選択
3. プロンプト入力（"A sunset over mountains"）
4. パラメータ調整（cfg_scale、steps等）
5. Generate

---

## SDK統合パターン

### LangChain統合

```python
from langchain_aws import ChatBedrock

llm = ChatBedrock(
    model_id="anthropic.claude-3-sonnet-20240229-v1:0",
    model_kwargs={
        "temperature": 0.7,
        "max_tokens": 1024
    },
    region_name="us-east-1"
)

response = llm.invoke("Amazon Bedrockの利点は？")
print(response.content)
```

### LlamaIndex統合

```python
from llama_index.llms.bedrock import Bedrock

llm = Bedrock(
    model="anthropic.claude-3-sonnet-20240229-v1:0",
    temperature=0.7,
    max_tokens=1024
)

response = llm.complete("AIとMLの違いは？")
print(response.text)
```

### エンタープライズパターン

```python
import boto3
from typing import Dict, Optional
from dataclasses import dataclass

@dataclass
class BedrockConfig:
    model_id: str
    region: str
    temperature: float = 0.7
    max_tokens: int = 1024

class BedrockClient:
    def __init__(self, config: BedrockConfig):
        self.config = config
        self.client = boto3.client('bedrock-runtime', region_name=config.region)

    def invoke(self, prompt: str, system_prompt: Optional[str] = None) -> str:
        messages = [{"role": "user", "content": prompt}]

        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": self.config.max_tokens,
            "temperature": self.config.temperature,
            "messages": messages
        }

        if system_prompt:
            request_body["system"] = system_prompt

        try:
            response = self.client.invoke_model(
                modelId=self.config.model_id,
                body=json.dumps(request_body)
            )

            response_body = json.loads(response['body'].read())
            return response_body['content'][0]['text']

        except ClientError as e:
            # エラーハンドリング
            raise

# 使用例
config = BedrockConfig(
    model_id="anthropic.claude-3-sonnet-20240229-v1:0",
    region="us-east-1"
)

client = BedrockClient(config)
result = client.invoke("AWS Lambda関数の作成手順を教えてください")
print(result)
```

---

## コスト最適化

### モデル別料金比較（参考）

| モデル | 入力（1000トークン） | 出力（1000トークン） | 用途 |
|--------|-------------------|-------------------|------|
| Claude 3 Haiku | 低 | 低 | コスト重視 |
| Claude 3.5 Sonnet | 中 | 中 | バランス |
| Claude 3 Opus | 高 | 高 | 品質重視 |
| Llama 3.1 8B | 低 | 低 | 軽量タスク |
| Titan Text Express | 低 | 低 | AWS最適化 |

### コスト最適化戦略

```python
# 1. 適切なモデル選択
def select_model(complexity: str) -> str:
    if complexity == "simple":
        return "anthropic.claude-3-haiku-20240307-v1:0"
    elif complexity == "medium":
        return "anthropic.claude-3-sonnet-20240229-v1:0"
    else:
        return "anthropic.claude-3-opus-20240229-v1:0"

# 2. トークン数の制限
request_body = {
    "max_tokens": 512,  # 必要最小限に設定
    # ...
}

# 3. バッチ処理
def process_batch(texts: list[str]) -> list[str]:
    results = []
    for text in texts:
        # バッチ処理で複数リクエストを効率化
        results.append(invoke_model(text))
    return results
```

---

## まとめ

このリファレンスでは、Amazon Bedrock APIの基本的な使用方法、モデル選定、プロンプトエンジニアリング、マルチモーダル機能、SDK統合について解説した。実装時は以下の点に注意:

- **適切なモデル選定**: タスクの複雑さとコストのバランスを考慮
- **プロンプト設計**: Few-shot、CoTを活用して精度向上
- **エラーハンドリング**: レート制限、タイムアウトに対応
- **コスト最適化**: トークン数の制限、適切なモデル選択
- **セキュリティ**: IAMポリシー、Guardrailsの活用
