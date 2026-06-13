# Providers リファレンス

## プロバイダー指定形式

```yaml
providers:
  - openai:gpt-4o                             # 簡易文字列
  - id: openai:chat:gpt-4o                    # オブジェクト（設定付き）
    label: "My GPT-4o"
    config:
      temperature: 0.7
  - file://path/to/provider.yaml              # ファイル参照
  - file://my_provider.py                     # カスタム Python
  - file://my_provider.js                     # カスタム JavaScript
```

> `providers` と `targets` は設定内で互換的に使用可能。

---

## OpenAI

### フォーマット

| フォーマット | 用途 |
|------------|------|
| `openai:chat:<model>` | Chat Completions（主力） |
| `openai:responses:<model>` | Responses API |
| `openai:completion:<model>` | Legacy Completions |
| `openai:assistant:<id>` | Assistants API |
| `openai:embeddings:<model>` | 埋め込みベクトル生成 |
| `openai:image:<model>` | 画像生成 |
| `openai:realtime:<model>` | リアルタイム API |

### 設定例

```yaml
- id: openai:chat:gpt-4o
  label: "GPT-4o Production"
  config:
    temperature: 0.7
    max_tokens: 2048
    top_p: 0.9
    frequency_penalty: 0.5
    presence_penalty: 0.2
    response_format: { type: json_object }
    tools: [...]
    tool_choice: auto
    seed: 42
```

### 推論モデル（o3, o4-mini）

```yaml
- id: openai:chat:o3
  config:
    reasoning:
      effort: medium        # low | medium | high
      summary: auto         # none | auto | concise | detailed
```

### 環境変数

| 変数 | 説明 |
|------|------|
| `OPENAI_API_KEY` | API キー（必須） |
| `OPENAI_API_BASE_URL` | カスタムエンドポイント |
| `OPENAI_ORGANIZATION` | 組織 ID |

---

## Anthropic

### フォーマット

`anthropic:messages:<model>`

例: `anthropic:messages:claude-sonnet-4-5-20250929`

### 設定例

```yaml
- id: anthropic:messages:claude-sonnet-4-5-20250929
  config:
    temperature: 0.0
    max_tokens: 512
    # 拡張思考（Extended Thinking）
    thinking:
      type: 'enabled'
      budget_tokens: 16000
    showThinking: false       # 思考プロセスを出力に含めない
    tools: [...]
    # 構造化出力
    output_format:
      type: json_schema
      schema: { ... }
    # エフォートレベル
    effort: high              # low | medium | high | max
```

### クロスプラットフォーム

Anthropic モデルは以下経由でも利用可能:
- Azure AI Foundry
- AWS Bedrock（`bedrock:anthropic.claude-...`）
- Google Vertex AI（`vertex:anthropic.claude-...`）

### 環境変数

`ANTHROPIC_API_KEY`

---

## Google / Gemini

### フォーマット

`google:<model>`（例: `google:gemini-2.5-pro`）

### 設定例

```yaml
- id: google:gemini-2.5-pro
  config:
    temperature: 0.7
    maxOutputTokens: 2048
    topP: 0.9
    topK: 40
    systemInstruction: "You are a helpful assistant"
    generationConfig:
      thinkingConfig:
        thinkingBudget: 1024
    # ツール設定
    tools:
      function_declarations: [...]
      # または組み込みツール
      # googleSearch: {}
      # codeExecution: {}
```

### 環境変数

`GOOGLE_API_KEY`

---

## Ollama（ローカルモデル）

オフライン環境や自己ホスト型 LLM のテストに適する。

### フォーマット

| フォーマット | 用途 |
|------------|------|
| `ollama:chat:<model>` | チャット |
| `ollama:completion:<model>` | 補完 |
| `ollama:embeddings:<model>` | 埋め込み |

### 設定例

```yaml
- id: ollama:chat:llama3.3
  config:
    num_predict: 1024
    temperature: 0.7
    think: true             # 推論モデル（QwQ等）
```

### 環境変数

`OLLAMA_BASE_URL`（デフォルト: `http://localhost:11434`）

---

## HTTP / カスタム API プロバイダー

内製 API や外部サービスをプロバイダーとして定義する。

### 基本設定

```yaml
- id: https
  config:
    url: 'https://api.example.com/generate'
    method: POST
    headers:
      Content-Type: application/json
      Authorization: 'Bearer {{env.API_TOKEN}}'
    body:
      prompt: '{{prompt}}'
      model: 'my-model'
    transformResponse: 'json.choices[0].message.content'
```

### 認証方式

| 方式 | 設定例 |
|------|--------|
| Bearer トークン | `Authorization: 'Bearer {{env.TOKEN}}'` |
| API Key | `X-API-Key: '{{env.API_KEY}}'` |
| Basic 認証 | `Authorization: 'Basic {{base64(user:pass)}}'` |
| OAuth 2.0 | `tokenEndpoint` + `clientId` / `clientSecret` |
| デジタル署名 | PEM / JKS / PFX 証明書設定 |

### TLS / mTLS

```yaml
config:
  tls:
    cert: file://client.crt
    key: file://client.key
    ca: file://ca.crt
    rejectUnauthorized: true
```

### セッション管理

```yaml
config:
  # サーバーサイド（Cookie / セッション ID 抽出）
  sessionParser: 'json.sessionId'
  # クライアントサイド（UUID 生成）
  generateSession: true
```

### ツール呼び出し変換

```yaml
config:
  transformToolsFormat: openai    # openai | anthropic | bedrock | google
```

---

## カスタム JavaScript プロバイダー

```javascript
// myProvider.js
module.exports = class {
  id() {
    return 'my-custom-provider';
  }

  async callApi(prompt, context, options) {
    // context.vars でテスト変数にアクセス
    const temperature = options?.config?.temperature ?? 0.7;

    const response = await myApiCall(prompt, { temperature });

    return {
      output: response.text,
      tokenUsage: {
        total: response.usage.total_tokens,
        prompt: response.usage.prompt_tokens,
        completion: response.usage.completion_tokens,
      },
      cost: response.usage.total_tokens * 0.000002,
    };
  }
};
```

**設定での参照:**

```yaml
providers:
  - file://myProvider.js
  - file://myProvider.js:MyProviderClass  # 名前付きエクスポート
```

---

## カスタム Python プロバイダー

```python
# my_provider.py
def call_api(prompt: str, options: dict, context: dict) -> dict:
    """
    Args:
        prompt: 送信するプロンプト文字列
        options: プロバイダー設定（config フィールドを含む）
        context: テストコンテキスト（vars 等）
    Returns:
        output または error を含む辞書
    """
    config = options.get('config', {})
    temperature = config.get('temperature', 0.7)

    response = my_api_call(prompt, temperature=temperature)

    return {
        "output": response.text,
        "tokenUsage": {
            "total": response.usage.total,
            "prompt": response.usage.prompt,
            "completion": response.usage.completion,
        },
        "cost": response.usage.total * 0.000002,
    }
```

### Python 実行設定

```yaml
providers:
  - id: file://my_provider.py
    config:
      workers: 4               # 並列ワーカー数
      timeout: 300000          # タイムアウト(ms)
      pythonExecutable: /path/to/python
```

### 環境変数

`PROMPTFOO_PYTHON=/usr/bin/python3.11`

---

## マルチターン会話

複数ターンの対話をシミュレートする。

```yaml
tests:
  - vars:
      question1: "What is the capital of Japan?"
    assert:
      - type: contains
        value: Tokyo
    options:
      storeOutputAs: answer1   # 次のターンで参照可能

  - vars:
      question2: "Tell me more about {{answer1}}"
    assert:
      - type: llm-rubric
        value: "Provides detailed information about Tokyo"
```

**ベストプラクティス:**
- `_conversation` 変数で会話履歴を追跡
- `conversationId` in metadata でスレッド分離
- 会話テストは `concurrency: 1` で実行（順序保証）

---

## JSON 出力評価

```yaml
# 基本 JSON 検証
assert:
  - type: is-json

# スキーマ検証
assert:
  - type: is-json
    value:
      type: object
      required: ['name', 'age']

# フィールドレベル検証（transform 使用）
defaultTest:
  options:
    transform: JSON.parse(output)
tests:
  - assert:
      - type: javascript
        value: output.name === 'expected_name'
      - type: javascript
        value: output.age >= 18
```

---

## プロバイダー比較設定例

複数モデルを一度に評価する典型的な構成:

```yaml
providers:
  - id: openai:chat:gpt-4o
    label: "GPT-4o"
  - id: anthropic:messages:claude-sonnet-4-5-20250929
    label: "Claude Sonnet"
  - id: google:gemini-2.5-pro
    label: "Gemini 2.5 Pro"
  - id: ollama:chat:llama3.3
    label: "Llama 3.3 (Local)"

prompts:
  - "{{task}}"

tests:
  - vars:
      task: "Explain quantum computing in simple terms"
    assert:
      - type: answer-relevance
        threshold: 0.8
      - type: llm-rubric
        value: "Explanation is accurate and accessible to non-experts"
```

---

## プロバイダー設定のベストプラクティス

1. **`label` を必ず設定**: 複数プロバイダー比較時に結果テーブルが読みやすくなる
2. **`seed` で再現性確保**: ランダム性排除が必要なテストは `seed: 42` を設定
3. **コスト管理**: `cost` アサーションで予算を超えるテストを自動で NG に
4. **ローカルモデル活用**: CI 早期フェーズは Ollama でコスト無料評価 → 本番前のみクラウド API
5. **カスタムプロバイダーの型付け**: TypeScript で `ApiProvider` インターフェースを実装し型安全性を確保
