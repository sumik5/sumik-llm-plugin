# Amazon Bedrock SDK 開発実践ガイド

Boto3・LangChain・ベンダーパッケージ・curl・JavaScript SDK を使った実装パターン集。
API仕様詳細は `BEDROCK-API.md`、RAG/Knowledge Bases は `RAG-AGENTS.md` を参照。

---

## SageMaker ノートブック環境のセットアップ

Bedrock を Jupyter 環境から使う場合の IAM 設定と起動手順。

### IAM ロールへのポリシー追加

SageMaker 実行ロールに Bedrock フルアクセスを付与するインラインポリシー:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "bedrock:*",
      "Resource": "*"
    }
  ]
}
```

### 信頼ポリシー（SageMaker + Bedrock 両方を信頼）

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "bedrock.amazonaws.com" },
      "Action": "sts:AssumeRole"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": { "Service": "sagemaker.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### ノートブックインスタンス設定値

| 項目 | 推奨値 | 補足 |
|------|--------|------|
| インスタンスタイプ | `ml.t3.medium` | モデル呼び出しのみなら最低スペックで十分 |
| プラットフォーム | Amazon Linux 2, Jupyter Lab 3 | - |
| ルートアクセス | 有効化 | - |
| IAMロール | 上記ロール名 | SageMaker- プレフィックスが付く |

起動後にステータスが `In Service` に変わったら `Jupyter Lab を開く` で利用可能。

---

## Boto3 クライアント: `bedrock` vs `bedrock-runtime`

| クライアント | service_name | 用途 |
|-------------|--------------|------|
| **Bedrock** | `bedrock` | モデル管理（一覧取得・メタ情報）|
| **Bedrock Runtime** | `bedrock-runtime` | モデルへのプロンプト送受信 |

> モデルに問いかける処理は必ず `bedrock-runtime` を使う。`bedrock` だけではモデル呼び出し不可。

### Bedrock クライアント（管理系）

```python
import boto3

bedrock_client = boto3.client(
    service_name='bedrock',
    region_name='us-east-1',
)

# 利用可能なモデル一覧
model_data = bedrock_client.list_foundation_models()
for item in model_data.get('modelSummaries', []):
    print(item.get('modelId'))

# 出力モダリティでフィルタ（"TEXT" / "IMAGE" / "EMBEDDING"）
text_models = bedrock_client.list_foundation_models(byOutputModality="TEXT")

# 特定モデルの詳細
info = bedrock_client.get_foundation_model(
    modelIdentifier='amazon.titan-text-express-v1'
)
```

### Bedrock Runtime クライアント（実行系）

```python
import boto3
import json

runtime_client = boto3.client(
    service_name='bedrock-runtime',
    region_name='us-east-1',
    # SageMaker ノートブック以外では明示的にキーを渡す場合
    # aws_access_key_id=ACCESS_KEY_ID,
    # aws_secret_access_key=SECRET_ACCESS_KEY,
)
```

---

## invoke_model: モデル別 body 構造

`invoke_model` への `body` はモデルごとに異なる。共通インターフェースは **body を JSON テキスト化して渡す** のみ。

### レスポンス読み取りの共通パターン

```python
response = runtime_client.invoke_model(body=body, modelId=model_id)
# body は StreamingBody → read() → JSON デコードが必要
response_body = json.loads(response.get('body').read())
```

---

### Amazon Titan Text (amazon.titan-text-express-v1)

**body 構造:**

```python
body = json.dumps({
    "inputText": "プロンプト",
    "textGenerationConfig": {
        "maxTokenCount": 1000,  # 最大 8192
        "temperature": 0.5,     # 0〜1
        "topP": 0.2,            # 0〜1
        "stopSequences": []
    }
})
```

**レスポンスから応答テキストを取得:**

```python
response_body = json.loads(response.get('body').read())
output_text = response_body["results"][0]["outputText"]
```

**Titan レスポンス構造:**

```json
{
  "inputTextTokenCount": 6,
  "results": [
    {
      "tokenCount": 18,
      "outputText": "...応答...",
      "completionReason": "FINISH"
    }
  ]
}
```

---

### AI21 Jurassic-2 (ai21.j2-mid-v1 / ai21.j2-ultra-v1)

**body 構造:**

```python
body = json.dumps({
    "prompt": "プロンプト",
    "maxTokens": 1000,            # 最大 8091
    "temperature": 0.5,           # 0〜1
    "topP": 0.7,                  # 0〜1
    "stopSequences": [],
    "countPenalty": {"scale": 0},
    "presencePenalty": {"scale": 0},
    "frequencyPenalty": {"scale": 0}
})
```

**レスポンスから応答テキストを取得:**

```python
response_body = json.loads(response.get('body').read())
prompt_text = response_body["prompt"]["text"]
answer_text = response_body["completions"][0]["data"]["text"]
```

**Jurassic-2 レスポンス構造:**

```json
{
  "id": 123,
  "prompt": { "text": "送信プロンプト", "tokens": [] },
  "completions": [
    {
      "data": { "text": "...応答...", "tokens": [] },
      "finishReason": { "reason": "length" }
    }
  ]
}
```

> `completions` がリスト構造なのは複数応答（numResults）に対応するため。

---

### Anthropic Claude v2 (anthropic.claude-v2:1)

**⚠️ Legacy API**: 現行モデル（Claude 3+）は Messages API 形式（`BEDROCK-API.md` 参照）を使う。

**body 構造（Claude v2 以前）:**

```python
body = json.dumps({
    "prompt": f"\n\nHuman:{user_prompt}\n\nAssistant: ",
    "max_tokens_to_sample": 1000,  # 必須。1〜2048
    "temperature": 0.5,            # 0〜1
    "top_k": 250,                  # 0〜500
    "top_p": 0.7,                  # 0〜1
    "stop_sequences": ["\n\nHuman:"],
    "anthropic_version": "bedrock-2023-05-31"
})
```

> **プロンプトの形式**: `\n\nHuman:...メッセージ...\n\nAssistant: ` が必須。
> この形式が崩れると `ValidationException` が発生する。

**レスポンスから応答テキストを取得:**

```python
response_body = json.loads(response.get('body').read())
completion = response_body.get('completion')  # 応答テキスト
```

**Claude v2 レスポンス構造:**

```json
{
  "completion": " ...応答...",
  "stop_reason": "stop_sequences",
  "stop": "\n\nHuman:"
}
```

---

### モデル別 body パラメータ比較

| パラメータ | Titan | Jurassic-2 | Claude v2 |
|-----------|-------|------------|-----------|
| プロンプトキー | `inputText` | `prompt` | `prompt` |
| パラメータ格納 | `textGenerationConfig` 配下 | トップレベル | トップレベル |
| 最大トークン数 | `maxTokenCount` | `maxTokens` | `max_tokens_to_sample` |
| 温度 | `temperature` | `temperature` | `temperature` |
| Top-P | `topP` (camelCase) | `topP` (camelCase) | `top_p` (snake_case) |
| Top-K | なし | なし | `top_k` |
| 停止シーケンス | `stopSequences` | `stopSequences` | `stop_sequences` |

---

## invoke_model_with_response_stream: ストリーム受信

長い応答をリアルタイムに受け取る場合に使用。呼び出し方は `invoke_model` と同じ。

```python
response = runtime_client.invoke_model_with_response_stream(
    body=body,
    modelId='amazon.titan-text-express-v1'
)
```

**返り値の `body` は EventStream（ジェネレーター的オブジェクト）:**

```python
response_body = response.get("body")  # EventStream

if response_body:
    for event in response_body:
        chunk = event.get('chunk')
        if chunk:
            chunk_bytes = chunk.get('bytes').decode()
            result = json.loads(chunk_bytes)
            print(result["outputText"], end='', flush=True)
```

**EventStream のデータ構造:**

```
EventStream → event → chunk → bytes (バイナリ)
                                ↓ decode() + json.loads()
                             { "outputText": "...", "index": 0, ... }
```

**モデル別ストリームの `bytes` 内容:**

| モデル | 応答テキストのキー |
|--------|----------------|
| Titan | `outputText` |
| Claude v2 | `completion` |
| Jurassic-2 | `completions[0].data.text` |

> `invoke_model` をそのまま `invoke_model_with_response_stream` に置き換えるだけで使えるが、モデルごとのレスポンス構造は通常呼び出しと同じ。

---

## ベンダー提供パッケージ

### AI21 パッケージ (`ai21[AWS]`)

boto3 の invoke_model と同等のアクセスを AI21 独自 API 経由で実行する。`numResults` による**複数応答同時取得**が最大の差別化機能。

```bash
pip install "ai21[AWS]==1.3.4"
```

```python
import ai21
import boto3

# boto3 Session を用意して AI21 に渡す
ai21.aws_region = 'us-east-1'
boto_session = boto3.Session(
    region_name="us-east-1",
    aws_access_key_id=ACCESS_KEY_ID,
    aws_secret_access_key=SECRET_ACCESS_KEY,
)

# アクセス先（Destination）の作成
destination = ai21.BedrockDestination(
    model_id=ai21.BedrockModelID.J2_MID_V1,  # J2_ULTRA_V1 も可
    boto_session=boto_session,
)

# プロンプト送信（execute）
response = ai21.Completion.execute(
    destination=destination,
    prompt="プロンプトテキスト",
    numResults=3,       # 同時に複数応答を取得（boto3 にはない機能）
    maxTokens=100,
    temperature=0.7,
)

# 応答の取得（Jurassic-2 の構造と同じ）
for completion in response["completions"]:
    print(completion["data"]["text"].strip())
```

---

### Anthropic パッケージ (`anthropic-bedrock`)

Claude v2 以前の Legacy Completions API ラッパー。現行の Messages API は `anthropic` パッケージの `client.messages.create()` を使う。

```bash
pip install anthropic-bedrock
```

```python
import anthropic_bedrock
from anthropic_bedrock import AnthropicBedrock, HUMAN_PROMPT, AI_PROMPT

# クライアント作成
anthropic_client = AnthropicBedrock(
    aws_access_key=ACCESS_KEY_ID,
    aws_secret_key=SECRET_ACCESS_KEY,
    aws_region="us-east-1",
)

# プロンプト送信（completions.create）
response = anthropic_client.completions.create(
    model="anthropic.claude-v2:1",
    max_tokens_to_sample=300,  # 必須
    prompt=f"{HUMAN_PROMPT}{user_prompt}{AI_PROMPT}",
    temperature=0.7,
)

print(response.completion)  # 応答テキスト
```

**プロンプト用定数:**

| 定数 | 値 |
|------|-----|
| `HUMAN_PROMPT` | `"\n\nHuman:"` |
| `AI_PROMPT` | `"\n\nAssistant:"` |

---

## LangChain による Bedrock 統合

どのモデルでも統一インターフェースで扱える抽象化ライブラリ。

```bash
pip install langchain langchain-aws
```

### AWS 認証設定

LangChain は環境変数でクレデンシャルを読み込む:

```python
import os
os.environ['AWS_CONFIG_FILE'] = "./.aws/config"
os.environ['AWS_SHARED_CREDENTIALS_FILE'] = "./.aws/credentials"
```

`~/.aws/config` の記述例:
```ini
[default]
region = us-east-1
output = json
```

---

### Bedrock LLM クラス（テキスト生成）

```python
from langchain.llms import Bedrock

llm = Bedrock(
    credentials_profile_name="default",
    model_id="amazon.titan-text-express-v1"
)

# generate はリストで渡す（単一でも []）
result = llm.generate(["プロンプト"])
text = result.generations[0][0].text.strip()

# パラメータ指定
result = llm.generate(
    ["プロンプト"],
    {"temperature": 0.7, "maxTokens": 300, "topP": 1}
)
```

**`generate` の戻り値構造:**

```python
LLMResult(
    generations=[[Generation(text='...応答...')]],
    llm_output=None,
    run=[RunInfo(run_id=UUID('...'))]
)
# → result.generations[0][0].text で取得
```

---

### ChatBedrock（チャット用）

```python
from langchain.chat_models import BedrockChat
from langchain.schema import HumanMessage, SystemMessage, AIMessage

chat = BedrockChat(
    credentials_profile_name="default",
    model_id="anthropic.claude-v2:1"
)

# メッセージ作成と送信
messages = [
    SystemMessage(content="あなたは親切なアシスタントです。"),
    HumanMessage(content="Pythonで Hello World を書いて")
]
response = chat(messages)     # → AIMessage(content='...')
print(response.content)

# パラメータ付き
response = chat(
    messages,
    temperature=0.7,
    max_tokens_to_sample=200,
    top_p=1
)
```

**メッセージ種別:**

| クラス | 用途 |
|--------|------|
| `HumanMessage` | ユーザーから AI へのメッセージ |
| `AIMessage` | AI から返ってきた応答（戻り値として受け取る）|
| `SystemMessage` | 全会話に適用されるシステムプロンプト |

---

### ConversationChain（会話履歴自動管理）

メッセージリストを手動管理せず、バッファが自動でやり取りを保持する。

```python
from langchain.chains import ConversationChain
from langchain.memory import ConversationBufferMemory

conversation = ConversationChain(
    llm=llm,                             # Bedrock インスタンス
    verbose=False,
    memory=ConversationBufferMemory()    # 会話履歴バッファ
)

# predict でプロンプト送信（戻り値は応答テキストそのまま）
response = conversation.predict(input="こんにちは！")
print(response)
```

---

### PromptTemplate + RunnableSequence (LCEL)

テンプレートを定義してモデルと組み合わせ、一括実行するパターン。

```python
from langchain.prompts import PromptTemplate

# {topic} がプレースホルダー
template = PromptTemplate.from_template(
    "{topic} をテーマにした俳句を作ってください。"
)

# | 演算子でチェーン化（LCEL: LangChain Expression Language）
chain = template | llm   # → RunnableSequence

# invoke で一括実行（辞書でプレースホルダーに値を渡す）
result = chain.invoke({"topic": "春の桜"})
print(result)
```

**処理フロー:**

```
invoke({"topic": "..."})
  → PromptTemplate: テキスト埋め込み
  → Bedrock: モデル呼び出し
  → 戻り値
```

---

## curl による HTTP アクセス（AWS Signature V4）

Python 以外の環境や、プログラムなしでのテストに使用。

### 基本形

```bash
curl \
  --aws-sigv4 aws:amz:{REGION}:bedrock \
  -H "Content-Type: application/json" \
  -H "Accept: */*" \
  -u {ACCESS_KEY}:{SECRET_KEY} \
  -d '{BODY_JSON}' \
  https://bedrock-runtime.{REGION}.amazonaws.com/model/{MODEL_ID}/invoke
```

**オプション説明:**

| オプション | 説明 |
|-----------|------|
| `--aws-sigv4 aws:amz:REGION:bedrock` | AWS Signature V4 認証。`aws:amz:リージョン:サービス` の形式 |
| `-H "Content-Type: application/json"` | リクエストボディの形式指定 |
| `-H "Accept: */*"` | レスポンスの形式制限なし |
| `-u KEY:SECRET` | アクセスキー:シークレットキー |
| `-d '...'` | JSON ボディコンテンツ（シングルクォートで囲む）|

---

### モデル別 curl 実行例

**Jurassic-2:**

```bash
curl --aws-sigv4 aws:amz:us-east-1:bedrock \
  -H "Content-Type: application/json" -H "Accept: */*" \
  -u ACCESS_KEY:SECRET_KEY \
  -d '{"prompt":"Hello!"}' \
  https://bedrock-runtime.us-east-1.amazonaws.com/model/ai21.j2-mid-v1/invoke
```

**Titan:**

```bash
curl --aws-sigv4 aws:amz:us-east-1:bedrock \
  -H "Content-Type: application/json" -H "Accept: */*" \
  -u ACCESS_KEY:SECRET_KEY \
  -d '{"inputText":"What is AI?", "textGenerationConfig":{"maxTokenCount":200,"temperature":0.2}}' \
  https://bedrock-runtime.us-east-1.amazonaws.com/model/amazon.titan-text-express-v1/invoke
```

**SDXL（画像生成）:**

```bash
curl --aws-sigv4 aws:amz:us-east-1:bedrock \
  -H "Content-Type: application/json" -H "Accept: */*" \
  -u ACCESS_KEY:SECRET_KEY \
  -d '{"text_prompts":[{"text":"A futuristic city"}],"cfg_scale":7,"steps":30}' \
  https://bedrock-runtime.us-east-1.amazonaws.com/model/stability.stable-diffusion-xl-v1/invoke
```

---

### Jupyter/Colab からの curl 実行と結果取得

```python
import json

# ! prefix でシェルコマンドを実行、変数に代入可能
response = !curl \
  --aws-sigv4 aws:amz:us-east-1:bedrock \
  -H "Content-Type: application/json" -H "Accept: */*" \
  -u ACCESS_KEY:SECRET_KEY \
  -d '{"prompt":"Hi!"}' \
  https://bedrock-runtime.us-east-1.amazonaws.com/model/ai21.j2-mid-v1/invoke

# response はリスト（[0] が本文テキスト）
response_json = json.loads(response[0])
text = response_json['completions'][0]['data']['text'].strip()
```

> `\` で改行継続できるため、Jupyter 上では読みやすく書ける。結果を変数に代入することで Python で後処理可能。

---

## JavaScript SDK による Bedrock 利用

### セットアップ

```bash
npm init
npm install @aws-sdk/client-bedrock-runtime
```

### BedrockRuntimeClient によるモデル呼び出し（TypeScript/JavaScript）

```javascript
const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');

const client = new BedrockRuntimeClient({
  region: 'us-east-1',
  credentials: {
    accessKeyId: ACCESS_KEY_ID,
    secretAccessKey: SECRET_ACCESS_KEY,
  },
});

const main = async () => {
  // body は JSON.stringify してから渡す
  const command = new InvokeModelCommand({
    modelId: 'amazon.titan-text-express-v1',
    body: JSON.stringify({ inputText: 'Hello!' }),
    accept: 'application/json',
    contentType: 'application/json',
  });

  const res = await client.send(command);

  // body は Uint8ArrayBlobAdapter → Buffer で変換
  const buffer = Buffer.from(res.body);
  const body = JSON.parse(buffer.toString('utf-8'));
  console.log(body.results[0].outputText);
};

main();
```

**レスポンスの `body` 変換パターン:**

```javascript
// Uint8ArrayBlobAdapter → Buffer → String → JSON
const buffer = Buffer.from(res.body);
const text = buffer.toString('utf-8');
const obj = JSON.parse(text);
```

### then チェーン形式（非 async/await）

```javascript
client.send(command).then(res => {
  const buffer = Buffer.from(res.body);
  const body = JSON.parse(buffer.toString('utf-8'));
  console.log(body.results[0].outputText);
});
```

### モデル別 body JSON

| モデル | body の JSON 構造 |
|--------|-----------------|
| Titan | `{ "inputText": "...", "textGenerationConfig": {...} }` |
| Jurassic-2 | `{ "prompt": "..." }` |
| Claude v2 | `{ "prompt": "\n\nHuman:...\n\nAssistant: ", "max_tokens_to_sample": 300 }` |
| Claude 3+ | `{ "anthropic_version": "bedrock-2023-05-31", "messages": [...], "max_tokens": 1024 }` |

---

## まとめ: SDK 選択ガイド

| シナリオ | 推奨 SDK/方法 |
|---------|--------------|
| Python シンプル呼び出し | boto3 `invoke_model` |
| Python ストリーミング応答 | boto3 `invoke_model_with_response_stream` |
| Python 複数モデルの統一利用 | LangChain `Bedrock` / `ChatBedrock` |
| Python 会話アプリ | LangChain `ConversationChain` |
| Python テンプレート駆動 | LangChain `PromptTemplate` + LCEL |
| AI21 複数応答同時取得 | `ai21[AWS]` パッケージ |
| Claude ベンダー機能（Legacy） | `anthropic-bedrock` パッケージ |
| 任意の言語・ノーコード連携 | curl + AWS Signature V4 |
| JavaScript/Node.js | `@aws-sdk/client-bedrock-runtime` |
