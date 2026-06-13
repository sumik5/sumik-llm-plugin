# Amazon Bedrock Guardrails コード例・API仕様

CreateGuardrail APIの完全パラメータ仕様、ApplyGuardrail APIのパターン、Knowledge Base統合、バージョン管理、料金、チューニング手法を収録する。

---

## CreateGuardrail API 完全仕様

### トップレベルパラメータ

| パラメータ | 型 | 必須 | 説明 |
|----------|----|------|------|
| `name` | string | ✅ | ガードレール名 |
| `description` | string | ❌ | 説明 |
| `blockedInputMessaging` | string | ✅ | 入力ブロック時のメッセージ |
| `blockedOutputsMessaging` | string | ✅ | 出力ブロック時のメッセージ |
| `kmsKeyId` | string | ❌ | 暗号化用KMSキーARN |
| `tags` | list[dict] | ❌ | タグ（`[{"key": "env", "value": "prod"}]`） |
| `clientRequestToken` | string | ❌ | 冪等性トークン |

### contentPolicyConfig

```python
contentPolicyConfig={
    'filtersConfig': [
        {
            'type': 'SEXUAL',         # SEXUAL / VIOLENCE / HATE / INSULTS / MISCONDUCT / PROMPT_ATTACK
            'inputStrength': 'HIGH',  # NONE / LOW / MEDIUM / HIGH
            'outputStrength': 'HIGH',
            'inputModalities': ['TEXT', 'IMAGE'],   # TEXT / IMAGE（省略可）
            'outputModalities': ['TEXT'],
            'inputAction': 'BLOCK',   # BLOCK / NONE（省略可）
            'outputAction': 'BLOCK',
            'inputEnabled': True,     # True / False（省略可）
            'outputEnabled': True,
        }
    ]
}
```

**type 選択肢まとめ**:

| type | 対象 |
|------|------|
| `SEXUAL` | 性的コンテンツ |
| `VIOLENCE` | 暴力的コンテンツ |
| `HATE` | ヘイトスピーチ |
| `INSULTS` | 侮辱・ハラスメント |
| `MISCONDUCT` | 不正行為・違法行為 |
| `PROMPT_ATTACK` | プロンプトインジェクション・ジェイルブレイク |

### topicPolicyConfig

```python
topicPolicyConfig={
    'topicsConfig': [
        {
            'name': '投資アドバイス',           # 必須
            'definition': '特定銘柄の売買推奨',  # 必須（標準階層: 最大1,000文字 / クラシック: 最大200文字）
            'examples': [                        # オプション
                '〇〇株を買うべきですか',
                '今すぐ売却すべき銘柄は',
            ],
            'type': 'DENY',           # 必須（現在はDENYのみ）
            'inputAction': 'BLOCK',   # BLOCK / NONE
            'outputAction': 'BLOCK',
        }
    ],
    'tierConfig': {
        'tierName': 'STANDARD'  # STANDARD / CLASSIC（デフォルト: CLASSIC）
    }
}
```

### sensitiveInformationPolicyConfig（PII）

```python
sensitiveInformationPolicyConfig={
    'piiEntitiesConfig': [
        {'type': 'EMAIL',   'action': 'BLOCK'},      # BLOCK / ANONYMIZE / NONE
        {'type': 'NAME',    'action': 'ANONYMIZE'},
        {'type': 'US_SOCIAL_SECURITY_NUMBER', 'action': 'BLOCK'},
    ],
    'regexesConfig': [
        {
            'name': '社員ID',
            'pattern': r'EMP-\d{6}',
            'action': 'ANONYMIZE'
        }
    ]
}
```

**PIIエンティティ型 完全リスト**:

| カテゴリ | エンティティ |
|---------|------------|
| General | `ADDRESS`, `AGE`, `NAME`, `EMAIL`, `PHONE`, `USERNAME`, `PASSWORD`, `DRIVER_ID`, `LICENSE_PLATE`, `VEHICLE_IDENTIFICATION_NUMBER` |
| Finance | `CREDIT_DEBIT_CARD_CVV`, `CREDIT_DEBIT_CARD_EXPIRY`, `CREDIT_DEBIT_CARD_NUMBER`, `PIN`, `INTERNATIONAL_BANK_ACCOUNT_NUMBER`, `SWIFT_CODE` |
| IT | `IP_ADDRESS`, `MAC_ADDRESS`, `URL`, `AWS_ACCESS_KEY`, `AWS_SECRET_KEY` |
| USA | `US_BANK_ACCOUNT_NUMBER`, `US_BANK_ROUTING_NUMBER`, `US_INDIVIDUAL_TAX_IDENTIFICATION_NUMBER`, `US_PASSPORT_NUMBER`, `US_SOCIAL_SECURITY_NUMBER` |
| Canada | `CA_HEALTH_NUMBER`, `CA_SOCIAL_INSURANCE_NUMBER` |
| UK | `UK_NATIONAL_HEALTH_SERVICE_NUMBER`, `UK_NATIONAL_INSURANCE_NUMBER`, `UK_UNIQUE_TAXPAYER_REFERENCE_NUMBER` |

action: `BLOCK`（返却停止）/ `ANONYMIZE`（マスク）/ `NONE`（検出のみ）

### contextualGroundingPolicyConfig

RAGアプリケーション向けのハルシネーション検出フィルター。ソース資料への接地度（GROUNDING）とプロンプトへの関連性（RELEVANCE）を評価する。

```python
contextualGroundingPolicyConfig={
    'filtersConfig': [
        {
            'type': 'GROUNDING',   # ソース資料への接地度
            'threshold': 0.7,      # 0.0-1.0（高いほど厳格、推奨: 0.5-0.8）
            'action': 'BLOCK',     # BLOCK / NONE
            'enabled': True        # True / False
        },
        {
            'type': 'RELEVANCE',   # プロンプトへの関連性
            'threshold': 0.7,
            'action': 'BLOCK',
            'enabled': True
        }
    ]
}
```

**注意**: contextualGroundingPolicyConfig は InvokeModel / ConverseAPI で `grounding_source`（ソース文書）を渡した場合にのみ動作する。

### automatedReasoningPolicyConfig

FMレスポンスの論理的整合性をルールベースで検証する。

```python
automatedReasoningPolicyConfig={
    'policies': [
        'arn:aws:bedrock:us-east-1:ACCOUNT_ID:automated-reasoning-policy/POLICY_ID'
    ],
    'confidenceThreshold': 0.75  # 推奨: 0.5-0.95
}
```

### wordPolicyConfig

```python
wordPolicyConfig={
    'wordsConfig': [
        {
            'text': '競合他社名A',
            'inputAction': 'BLOCK',   # BLOCK / NONE（省略可）
            'outputAction': 'BLOCK',
        }
    ],
    'managedWordListsConfig': [
        {
            'type': 'PROFANITY',       # 現在はPROFANITYのみ
            'inputAction': 'BLOCK',
            'outputAction': 'BLOCK',
        }
    ]
}
```

### crossRegionConfig（標準階層のみ）

```python
crossRegionConfig={
    'guardrailProfileIdentifier': 'arn:aws:bedrock:us-east-1::guardrail-profile/cross-region'
}
```

### 戻り値・例外

**戻り値**:

| フィールド | 型 | 説明 |
|----------|----|------|
| `guardrailId` | string | ガードレールID |
| `guardrailArn` | string | ARN |
| `version` | string | 常に `'DRAFT'` |
| `createdAt` | datetime | 作成日時 |

**例外**:

| 例外 | 原因 |
|------|------|
| `ResourceNotFoundException` | 参照リソース（KMSキー等）が存在しない |
| `AccessDeniedException` | IAM権限不足 |
| `ValidationException` | パラメータ不正 |
| `ConflictException` | 同名のガードレールが既に存在 |
| `ServiceQuotaExceededException` | クォータ上限超過 |
| `ThrottlingException` | リクエスト過多 |

---

## ApplyGuardrail API（非LLMアプリ向け独立評価）

FM推論なしでコンテンツを評価する。SNS投稿フィルタリング・ブログ検証・コールセンターログ分析等に活用。

```python
client = boto3.client('bedrock-runtime')

response = client.apply_guardrail(
    guardrailIdentifier='guardrail-id',
    guardrailVersion='DRAFT',  # DRAFT または番号（'1', '2', ...）
    source='OUTPUT',           # INPUT | OUTPUT
    content=[
        {'text': {'text': user_content}}
    ]
)

# 違反なし: outputs は空リスト
if len(response['outputs']) == 0:
    print(user_content)  # 元のコンテンツをそのまま使用
else:
    # 違反あり: マスク済みまたはブロックメッセージ
    print(response['outputs'][0]['text'])

# 介入確認
if response['action'] == 'GUARDRAIL_INTERVENED':
    for assessment in response.get('assessments', []):
        print(assessment)
```

---

## Knowledge Base統合

```python
client = boto3.client('bedrock-agent-runtime')

response = client.retrieve_and_generate(
    input={'text': 'ユーザーの質問'},
    retrieveAndGenerateConfiguration={
        'type': 'KNOWLEDGE_BASE',
        'knowledgeBaseConfiguration': {
            'knowledgeBaseId': 'kb-xxxxxxxxxx',
            'modelArn': 'arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0',
            'generationConfiguration': {
                'guardrailConfiguration': {
                    'guardrailId': 'guardrail-id',
                    'guardrailVersion': '1'
                }
            }
        }
    }
)
```

---

## バージョン管理フロー

```python
# 1. DRAFTバージョンで内容確認
draft = bedrock.get_guardrail(
    guardrailIdentifier=guardrail_id,
    guardrailVersion='DRAFT'
)

# 2. スナップショットバージョン作成（DRAFT → 番号付きバージョン）
version = bedrock.create_guardrail_version(
    guardrailIdentifier=guardrail_id,
    description='v1.0 - 本番リリース'
)
print(version['version'])  # '1'

# 3. DRAFTを更新（本番バージョンには影響しない）
bedrock.update_guardrail(
    guardrailIdentifier=guardrail_id,
    name='updated-guardrail',
    contentPolicyConfig={...},
    blockedInputMessaging='...',
    blockedOutputsMessaging='...'
)

# 4. バージョン一覧取得
versions = bedrock.list_guardrails(
    guardrailIdentifier=guardrail_arn
)
for v in versions['guardrails']:
    print(v['version'], v['status'])
```

---

## ストリーミングモード

```python
# 同期モード（デフォルト）: 各チャンクをGuardrail評価してから返却
# → 安全性重視（違反を確実にブロック）、遅延あり
request_body = {
    'amazon-bedrock-guardrailConfig': {
        'tagSuffix': tag_suffix,
        'streamProcessingMode': 'SYNCHRONOUS'
    }
}

# 非同期モード: ストリーミングと並列でGuardrail評価
# → 低遅延、ただし違反検出時に後からブロックされる可能性がある
request_body = {
    'amazon-bedrock-guardrailConfig': {
        'tagSuffix': tag_suffix,
        'streamProcessingMode': 'ASYNCHRONOUS'
    }
}
```

| モード | 速度 | 安全性 | 適用場面 |
|--------|------|--------|---------|
| SYNCHRONOUS | 遅い | 高い | 金融・医療等リスクの高い用途 |
| ASYNCHRONOUS | 速い | やや低い | 一般チャット・UX重視の用途 |

---

## ポリシー別料金（US East 1、参考値）

| ポリシー | 課金単位 | 料金目安 |
|---------|---------|---------|
| コンテンツフィルター | 1,000テキスト単位 | $0.75 |
| 拒否トピック | 1,000テキスト単位 | $1.00 |
| 単語フィルター | — | 無料 |
| PII検出・マスク | 1,000テキスト単位 | $0.10 |
| 正規表現パターン | — | 無料 |
| コンテキストグラウンディング | 別途設定 | — |

**1テキスト単位 = 1,000トークン相当**（入力・出力それぞれカウント）。

---

## トピック検出チューニング

| 項目 | 推奨 |
|------|------|
| 閾値 | 0.5-0.8（デフォルト: 0.7）。厳しくしすぎると誤検知増加 |
| 定義の明確化 | トピック間の区別が曖昧だと精度低下。否定形も含めて記述する |
| サンプルフレーズ | 異なる文体・表現を含める（例: 質問形・命令形・婉曲表現） |
| 処理速度の目安 | 約0.357秒/サンプル（約10,000サンプル/時間） |
| 多言語対応 | 標準階層を使用すると広範な言語に対応 |

---

## ロールベース構成管理パターン

ユーザーロールごとに安全ポリシーをJSON設定ファイルで管理し、動的にGuardrailを切り替えるパターン。

```json
{
  "admin": {
    "content_filters": {
      "SEXUAL": "HIGH",
      "VIOLENCE": "HIGH",
      "HATE": "MEDIUM"
    },
    "blocked_topics": ["投資アドバイス"],
    "denied_words": ["競合他社名A"],
    "profanity_filter": true
  },
  "user": {
    "content_filters": {
      "SEXUAL": "MEDIUM",
      "VIOLENCE": "MEDIUM",
      "HATE": "LOW"
    },
    "blocked_topics": ["投資アドバイス", "医療診断"],
    "denied_words": [],
    "profanity_filter": true
  }
}
```

```python
import json
import boto3

def get_guardrail_id_for_role(role: str, config_path: str) -> str:
    """ロールに対応するGuardrailを取得または作成する"""
    with open(config_path) as f:
        config = json.load(f)

    role_config = config.get(role, config['user'])
    bedrock = boto3.client('bedrock')

    guardrail = bedrock.create_guardrail(
        name=f'guardrail-{role}',
        contentPolicyConfig={
            'filtersConfig': [
                {
                    'type': filter_type,
                    'inputStrength': strength,
                    'outputStrength': strength
                }
                for filter_type, strength in role_config['content_filters'].items()
            ]
        },
        blockedInputMessaging='このコンテンツは処理できません。',
        blockedOutputsMessaging='回答を生成できませんでした。'
    )
    return guardrail['guardrailId']
```

---

## Google ADK統合（Callback / Plugin パターン）

Google ADK（Agent Development Kit）のCallback/PluginシステムとBedrock ApplyGuardrail APIを組み合わせ、ADKエージェントの入出力にGuardrailを適用するパターン。

### ADK Callback パターン（シンプル）

`before_model_callback`（入力評価）と`after_model_callback`（出力評価）でBedrock Guardrailを適用する最小構成。

```python
import boto3
from google.adk.agents import LlmAgent
from google.adk.agents.callback_context import CallbackContext
from google.adk.models import LlmRequest, LlmResponse
from google.genai import types
from typing import Optional

bedrock_runtime = boto3.client('bedrock-runtime', region_name='us-east-1')
GUARDRAIL_ID = 'your-guardrail-id'
GUARDRAIL_VERSION = '1'

def bedrock_guardrail_before_model(
    callback_context: CallbackContext,
    llm_request: LlmRequest
) -> Optional[LlmResponse]:
    """入力をBedrock Guardrailで評価し、違反時はLLM呼び出しをスキップ"""
    # 最新のユーザーメッセージを抽出
    last_user_message = ""
    if llm_request.contents and llm_request.contents[-1].role == 'user':
        if llm_request.contents[-1].parts:
            last_user_message = llm_request.contents[-1].parts[0].text

    if not last_user_message:
        return None  # メッセージなし → LLM呼び出しを許可

    # Bedrock ApplyGuardrail で入力を評価
    response = bedrock_runtime.apply_guardrail(
        guardrailIdentifier=GUARDRAIL_ID,
        guardrailVersion=GUARDRAIL_VERSION,
        source='INPUT',
        content=[{'text': {'text': last_user_message}}]
    )

    if response['action'] == 'GUARDRAIL_INTERVENED':
        # 違反 → LLM呼び出しをスキップしてブロックメッセージを返却
        blocked_message = response['outputs'][0]['text'] if response['outputs'] else 'このコンテンツは処理できません。'
        return LlmResponse(
            content=types.Content(
                role='model',
                parts=[types.Part(text=blocked_message)]
            )
        )

    return None  # 合格 → LLM呼び出しを続行


def bedrock_guardrail_after_model(
    callback_context: CallbackContext,
    llm_response: LlmResponse
) -> Optional[LlmResponse]:
    """LLM出力をBedrock Guardrailで評価し、違反時は安全なレスポンスに置換"""
    model_text = ""
    if llm_response.content and llm_response.content.parts:
        model_text = llm_response.content.parts[0].text

    if not model_text:
        return None

    response = bedrock_runtime.apply_guardrail(
        guardrailIdentifier=GUARDRAIL_ID,
        guardrailVersion=GUARDRAIL_VERSION,
        source='OUTPUT',
        content=[{'text': {'text': model_text}}]
    )

    if response['action'] == 'GUARDRAIL_INTERVENED':
        # マスク済みまたはブロックメッセージに置換
        filtered_text = response['outputs'][0]['text'] if response['outputs'] else '回答を生成できませんでした。'
        return LlmResponse(
            content=types.Content(
                role='model',
                parts=[types.Part(text=filtered_text)]
            )
        )

    return None  # 合格 → 元のレスポンスを返却


# エージェント定義
guardrailed_agent = LlmAgent(
    name='GuardrailedAgent',
    model='gemini-2.0-flash',
    instruction='あなたは親切なアシスタントです。',
    before_model_callback=bedrock_guardrail_before_model,
    after_model_callback=bedrock_guardrail_after_model,
)
```

### ADK Plugin パターン（推奨・再利用可能）

ADK公式推奨のPluginパターン。`BasePlugin`を継承し、複数エージェントに一括適用可能。

```python
import boto3
import logging
from google.adk.plugins.base_plugin import BasePlugin
from google.adk.agents.callback_context import CallbackContext
from google.adk.models import LlmRequest, LlmResponse
from google.genai import types
from typing import Optional

logger = logging.getLogger(__name__)


class BedrockGuardrailPlugin(BasePlugin):
    """Bedrock Guardrailを適用するADKプラグイン。

    before_model_callback で入力評価、after_model_callback で出力評価を行い、
    Bedrock ApplyGuardrail APIによる二段階フィルタリングを実現する。
    """

    def __init__(
        self,
        guardrail_id: str,
        guardrail_version: str = 'DRAFT',
        region_name: str = 'us-east-1',
        blocked_input_message: str = 'このコンテンツは処理できません。',
        blocked_output_message: str = '回答を生成できませんでした。',
        name: str = 'bedrock_guardrail_plugin',
    ):
        super().__init__(name)
        self._client = boto3.client('bedrock-runtime', region_name=region_name)
        self._guardrail_id = guardrail_id
        self._guardrail_version = guardrail_version
        self._blocked_input_message = blocked_input_message
        self._blocked_output_message = blocked_output_message

    def _evaluate(self, text: str, source: str) -> dict:
        """ApplyGuardrail APIでコンテンツを評価"""
        return self._client.apply_guardrail(
            guardrailIdentifier=self._guardrail_id,
            guardrailVersion=self._guardrail_version,
            source=source,
            content=[{'text': {'text': text}}]
        )

    async def before_model_callback(
        self, *, callback_context: CallbackContext, llm_request: LlmRequest
    ) -> Optional[LlmResponse]:
        """入力評価: 違反時はLLM呼び出しをスキップ（コスト節約）"""
        last_user_message = ""
        if llm_request.contents and llm_request.contents[-1].role == 'user':
            if llm_request.contents[-1].parts:
                last_user_message = llm_request.contents[-1].parts[0].text

        if not last_user_message:
            return None

        try:
            response = self._evaluate(last_user_message, 'INPUT')
            if response['action'] == 'GUARDRAIL_INTERVENED':
                logger.warning(
                    'Guardrail blocked input',
                    extra={'assessments': response.get('assessments', [])}
                )
                blocked_text = (
                    response['outputs'][0]['text']
                    if response['outputs']
                    else self._blocked_input_message
                )
                return LlmResponse(
                    content=types.Content(
                        role='model',
                        parts=[types.Part(text=blocked_text)]
                    )
                )
        except Exception:
            logger.exception('Bedrock Guardrail input evaluation failed')

        return None

    async def after_model_callback(
        self, *, callback_context: CallbackContext, llm_response: LlmResponse
    ) -> Optional[LlmResponse]:
        """出力評価: 違反時はマスク済みまたはブロックメッセージに置換"""
        model_text = ""
        if llm_response.content and llm_response.content.parts:
            model_text = llm_response.content.parts[0].text

        if not model_text:
            return None

        try:
            response = self._evaluate(model_text, 'OUTPUT')
            if response['action'] == 'GUARDRAIL_INTERVENED':
                logger.warning(
                    'Guardrail filtered output',
                    extra={'assessments': response.get('assessments', [])}
                )
                filtered_text = (
                    response['outputs'][0]['text']
                    if response['outputs']
                    else self._blocked_output_message
                )
                return LlmResponse(
                    content=types.Content(
                        role='model',
                        parts=[types.Part(text=filtered_text)]
                    )
                )
        except Exception:
            logger.exception('Bedrock Guardrail output evaluation failed')

        return None


# 使用例
from google.adk.agents import LlmAgent

guardrail_plugin = BedrockGuardrailPlugin(
    guardrail_id='your-guardrail-id',
    guardrail_version='1',
    region_name='us-east-1',
)

agent = LlmAgent(
    name='SecureAgent',
    model='gemini-2.0-flash',
    instruction='あなたは親切なアシスタントです。',
    plugins=[guardrail_plugin],  # プラグインとして登録
)
```

### 評価フロー

```
ユーザー入力
    ↓
[ADK before_model_callback]
    → Bedrock ApplyGuardrail(source='INPUT')
    ├─ GUARDRAIL_INTERVENED → ブロックメッセージ返却（LLM呼び出しスキップ）
    └─ NONE → 続行
        ↓
[LLM推論（Gemini等）]
        ↓
[ADK after_model_callback]
    → Bedrock ApplyGuardrail(source='OUTPUT')
    ├─ GUARDRAIL_INTERVENED → フィルタ済みレスポンスに置換
    └─ NONE → 元のレスポンスを返却
```

**ポイント**:
- ADK Plugin パターンは複数エージェントに一括適用できるため推奨
- `before_model_callback` で入力ブロック時はLLM呼び出しをスキップ（コスト節約）
- Callback関数は同期、Plugin メソッドは `async` であることに注意
- エラー時はフェイルオープン（Guardrail障害でサービス停止しない）
