# Amazon Bedrock Guardrails リファレンス

生成AIアプリケーションに設定可能な保護メカニズム。ユーザー入力とモデルレスポンスの両方を評価する二段階評価で、FM全体に包括的な安全とプライバシー制御を提供する。

---

## 評価フロー

```
ユーザー入力
    ↓
[1] 入力評価フェーズ（ポリシーごとに並列処理）
    ├─ ブロック判定 → 推論中止（コスト節約）+ ブロックメッセージ返却
    └─ 合格
        ↓
[2] モデル推論フェーズ
        ↓
[3] 出力評価フェーズ
    ├─ ブロック → ブロックメッセージ返却
    ├─ マスク → 機密情報を置換して返却
    └─ 合格 → レスポンス返却
```

---

## 6つのフィルタータイプ

| フィルター | 機能 | 設定ポイント |
|-----------|------|------------|
| **コンテンツフィルター** | 有害テキスト・画像を検出（ヘイト/侮辱/性的/暴力/不正行為/プロンプト攻撃） | カテゴリごとに強度（NONE/LOW/MEDIUM/HIGH）を設定 |
| **拒否トピック** | アプリケーション文脈で不適切なトピックをブロック | 最大1,000文字/定義（標準階層）、最大200文字（クラシック階層） |
| **単語フィルター** | カスタム単語・フレーズを完全一致でブロック | 冒涜的言葉のデフォルトセット + カスタム単語（競合他社名等） |
| **機密情報フィルター（PII）** | SSN、生年月日、住所等を検出・マスク | BLOCK（返却停止）/ ANONYMIZE（マスク）+ カスタム正規表現 |
| **コンテキストグラウンディング** | RAGでモデルレスポンスがソースから逸脱した場合をフラグ付け・ブロック | グラウンディングスコア閾値を設定 |
| **自動推論チェック** | FMレスポンスの精度を論理ルールで検証 | ハルシネーション検出・修正提案・仮定の強調 |

---

## 保護階層（Tiers）

| 機能 | 標準階層 | クラシック階層 |
|------|---------|-------------|
| コンテンツフィルター・プロンプト攻撃 | より堅牢 | 確立されたパフォーマンス |
| 拒否トピック定義文字数 | 最大1,000文字 | 最大200文字 |
| 言語サポート | 広範（多言語） | 英語・フランス語・スペイン語 |
| クロスリージョン推論 | 対応 | 非対応 |
| プロンプト漏洩検出 | 対応 | 非対応 |
| コード要素内検出 | コメント・変数名・関数名・文字列リテラル | 非対応 |

---

## Guardrail作成（CreateGuardrail API）

```python
import boto3

bedrock = boto3.client('bedrock')

guardrail = bedrock.create_guardrail(
    name='content-moderation',
    description='コンテンツモデレーション用Guardrail',
    # 拒否トピック
    topicPolicyConfig={
        'topicsConfig': [
            {
                'name': '暴力的コンテンツ',
                'definition': '暴力、危害、違法行為に関する内容',
                'examples': ['武器の作り方', '犯罪の実行方法'],
                'type': 'DENY'
            }
        ]
    },
    # コンテンツフィルター
    contentPolicyConfig={
        'filtersConfig': [
            {'type': 'SEXUAL',      'inputStrength': 'HIGH',   'outputStrength': 'HIGH'},
            {'type': 'VIOLENCE',    'inputStrength': 'HIGH',   'outputStrength': 'HIGH'},
            {'type': 'HATE',        'inputStrength': 'MEDIUM', 'outputStrength': 'MEDIUM'},
            {'type': 'INSULTS',     'inputStrength': 'MEDIUM', 'outputStrength': 'MEDIUM'},
            {'type': 'MISCONDUCT',  'inputStrength': 'MEDIUM', 'outputStrength': 'MEDIUM'},
            {'type': 'PROMPT_ATTACK', 'inputStrength': 'HIGH', 'outputStrength': 'NONE'},
        ]
    },
    # PII検出・マスク
    sensitiveInformationPolicyConfig={
        'piiEntitiesConfig': [
            {'type': 'EMAIL',                    'action': 'BLOCK'},
            {'type': 'PHONE',                    'action': 'BLOCK'},
            {'type': 'NAME',                     'action': 'ANONYMIZE'},
            {'type': 'SSN',                      'action': 'BLOCK'},
            {'type': 'CREDIT_DEBIT_CARD_NUMBER', 'action': 'BLOCK'},
        ],
        # カスタム正規表現パターン
        'regexesConfig': [
            {
                'name': '社員ID',
                'pattern': r'EMP-\d{6}',
                'action': 'ANONYMIZE'
            }
        ]
    },
    # 単語フィルター
    wordPolicyConfig={
        'wordsConfig': [
            {'text': '競合他社名A'},
            {'text': '競合他社名B'},
        ],
        'managedWordListsConfig': [
            {'type': 'PROFANITY'}  # 冒涜的言葉のデフォルトセット
        ]
    },
    blockedInputMessaging='このコンテンツは処理できません。',
    blockedOutputsMessaging='回答を生成できませんでした。'
)

guardrail_id = guardrail['guardrailId']
guardrail_version = guardrail['version']
```

#### コンテキストグラウンディング設定

```python
# RAGアプリケーション向け: ハルシネーション検出
contextual_grounding = {
    'filtersConfig': [
        {
            'type': 'GROUNDING',   # ソース資料への接地度
            'threshold': 0.7       # 0.0-1.0（高いほど厳格）
        },
        {
            'type': 'RELEVANCE',   # プロンプトへの関連性
            'threshold': 0.7
        }
    ]
}
```

```typescript
import { BedrockClient, CreateGuardrailCommand } from "@aws-sdk/client-bedrock";

const client = new BedrockClient({ region: "us-east-1" });

const response = await client.send(new CreateGuardrailCommand({
  name: "content-moderation",
  contentPolicyConfig: {
    filtersConfig: [
      { type: "SEXUAL",   inputStrength: "HIGH",   outputStrength: "HIGH" },
      { type: "VIOLENCE", inputStrength: "HIGH",   outputStrength: "HIGH" },
      { type: "HATE",     inputStrength: "MEDIUM", outputStrength: "MEDIUM" },
    ],
  },
  blockedInputMessaging: "このコンテンツは処理できません。",
  blockedOutputsMessaging: "回答を生成できませんでした。",
}));
```

---

## API統合パターン

### 推論API統合（InvokeModel / Converse）

```python
bedrock_runtime = boto3.client('bedrock-runtime')

# InvokeModel に Guardrail を付与
response = bedrock_runtime.invoke_model(
    modelId='anthropic.claude-3-sonnet-20240229-v1:0',
    body=json.dumps(request_body),
    guardrailIdentifier=guardrail_id,
    guardrailVersion='1'
)

# ブロック確認
response_body = json.loads(response['body'].read())
if response_body.get('amazon-bedrock-guardrailAction') == 'BLOCKED':
    print("Guardrailによりブロックされました")
```

```typescript
import { BedrockRuntimeClient, ConverseCommand } from "@aws-sdk/client-bedrock-runtime";

const runtime = new BedrockRuntimeClient({ region: "us-east-1" });

const result = await runtime.send(new ConverseCommand({
  modelId: "anthropic.claude-3-sonnet-20240229-v1:0",
  messages: [{ role: "user", content: [{ text: userInput }] }],
  guardrailConfig: {
    guardrailIdentifier: guardrailId,
    guardrailVersion: "1",
    trace: "enabled",
  },
}));

if (result.stopReason === "guardrail_intervened") {
  console.log("Guardrailが介入しました");
}
```

### ApplyGuardrail API（FM呼び出し不要・独立評価）

FM推論を実行せずにコンテンツを評価する。外部モデルや事前検証に活用。

```python
response = bedrock_runtime.apply_guardrail(
    guardrailIdentifier=guardrail_id,
    guardrailVersion='1',
    source='INPUT',   # INPUT | OUTPUT
    content=[
        {'text': {'text': user_input}}
    ]
)

if response['action'] == 'GUARDRAIL_INTERVENED':
    for assessment in response.get('assessments', []):
        print(assessment)
```

### 入力タグ付け（選択的評価）

特定コンテンツのみGuardrailを適用し、システムプロンプトや検索結果をスキップする。

```python
import secrets

# tagSuffix はリクエストごとに動的生成（プロンプトインジェクション対策）
tag_suffix = secrets.token_hex(8)
tag = f"amazon-bedrock-guardrails-guardContent_{tag_suffix}"

# ユーザー入力のみタグ付け（システムプロンプト・RAG結果はタグなし）
tagged_input = f"<{tag}>{user_query}</{tag}>"

request_body = {
    "anthropic_version": "bedrock-2023-05-31",
    "messages": [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": rag_context},      # タグなし: スキップ
                {"type": "text", "text": tagged_input},      # タグあり: 評価対象
            ]
        }
    ],
    "amazon-bedrock-guardrailConfig": {
        "tagSuffix": tag_suffix,
        "streamProcessingMode": "SYNCHRONOUS"   # SYNCHRONOUS | ASYNCHRONOUS
    }
}
```

**注意**: tagSuffix は必ずリクエストごとにランダム生成する。固定値を使うとプロンプトインジェクションでタグを偽装される可能性がある。

---

## バージョン管理・テスト

```python
# バージョン作成（ドラフトを昇格）
version = bedrock.create_guardrail_version(
    guardrailIdentifier=guardrail_id,
    description='本番リリース v1'
)

# テスト用トレース有効化（APIヘッダー）
# X-Amzn-Bedrock-GuardrailIdentifier: {guardrailId}
# X-Amzn-Bedrock-GuardrailVersion: {version}
# X-Amzn-Bedrock-Trace: ENABLED

# トレース情報の確認
response = bedrock_runtime.invoke_model(
    modelId='anthropic.claude-3-sonnet-20240229-v1:0',
    body=json.dumps(request_body),
    guardrailIdentifier=guardrail_id,
    guardrailVersion='1',
    trace='ENABLED'
)
# レスポンスの amazon-bedrock-trace にフィルター別判定結果が含まれる
```

---

## クロスリージョン推論

標準階層のみ対応。追加料金なし。データは初期リージョン内に保持される。

```python
# Guardrail作成時にクロスリージョン推論を有効化
guardrail = bedrock.create_guardrail(
    name='cross-region-guardrail',
    # ... 他の設定 ...
    crossRegionConfig={
        'guardrailProfileIdentifier': 'arn:aws:bedrock:us-east-1::guardrail-profile/cross-region'
    }
)
```

---

## クロスアカウント保護

### 組織レベル（AWS Organizations）

AWS Organizationsを使って全メンバーアカウントに強制適用する。

```json
{
  "bedrock": {
    "guardrail_inference": {
      "us-east-1": {
        "config_1": {
          "identifier": {
            "@@assign": "arn:aws:bedrock:us-east-1:ACCOUNT_ID:guardrail/GUARDRAIL_ID:1"
          },
          "input_tags": {
            "@@assign": "honor"
          }
        }
      }
    }
  }
}
```

```python
# Organizations ポリシー設定（BEDROCK_POLICYタイプ）
org = boto3.client('organizations')
org.create_policy(
    Name='bedrock-guardrail-policy',
    Type='BEDROCK_POLICY',
    Content=json.dumps(policy_document)
)
```

### アカウントレベル

```python
# 単一アカウントへの強制適用
bedrock.put_enforced_guardrail_configuration(
    guardrailIdentifier=guardrail_id,
    guardrailVersion='1'
)
```

**レイヤード保護**: 複数のGuardrailが存在する場合、最も制限の厳しいコントロールが優先される。

### リソースベースポリシーで共有

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::TARGET_ACCOUNT_ID:root"
      },
      "Action": "bedrock:ApplyGuardrail",
      "Resource": "arn:aws:bedrock:us-east-1:OWNER_ACCOUNT_ID:guardrail/GUARDRAIL_ID"
    }
  ]
}
```

---

## IAMポリシー

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GuardrailManagement",
      "Effect": "Allow",
      "Action": [
        "bedrock:CreateGuardrail",
        "bedrock:CreateGuardrailVersion",
        "bedrock:DeleteGuardrail",
        "bedrock:GetGuardrail",
        "bedrock:ListGuardrails",
        "bedrock:UpdateGuardrail"
      ],
      "Resource": "*"
    },
    {
      "Sid": "GuardrailApply",
      "Effect": "Allow",
      "Action": "bedrock:ApplyGuardrail",
      "Resource": "arn:aws:bedrock:us-east-1:ACCOUNT_ID:guardrail/GUARDRAIL_ID"
    },
    {
      "Sid": "ModelInvocation",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 料金体系

| 課金タイミング | 対象 |
|-------------|------|
| 入力ブロック時 | ガードレール評価料金のみ（モデル推論料金は発生しない） |
| 出力ブロック時 | ガードレール評価料金 + モデル推論料金 |
| 通過時 | ガードレール評価料金 + モデル推論料金 |

ポリシータイプ別（コンテンツフィルター、PIIフィルター等）に課金される。

---

## ベストプラクティス

| 項目 | 推奨 |
|------|------|
| tagSuffix | リクエストごとにランダム生成（`secrets.token_hex(8)`）。固定値は禁止 |
| バージョン管理 | ドラフトでテスト → `create_guardrail_version` で昇格 → 本番に適用 |
| トレース | 開発中は `trace='ENABLED'` で各フィルターの判定理由を確認 |
| RAG統合 | システムプロンプト・検索結果はタグなし、ユーザー入力のみタグ付けでコスト最適化 |
| 階層選択 | 多言語対応・プロンプト漏洩検出が必要な場合は標準階層を選択 |
| クロスアカウント | 組織内の統一ポリシーはOrganizationsのBEDROCK_POLICYタイプで管理 |
| 多層防御 | コンテンツフィルター + 拒否トピック + PIIフィルターを組み合わせる |

---

## 詳細リファレンス

- [GUARDRAILS-EXAMPLES.md](GUARDRAILS-EXAMPLES.md) — CreateGuardrail API完全仕様、PIIエンティティ一覧、ApplyGuardrail API、Knowledge Base統合、バージョン管理、料金
