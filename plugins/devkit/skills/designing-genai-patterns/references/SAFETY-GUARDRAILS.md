# 安全性・ガードレール パターン詳細リファレンス

P29〜P32（Template Generation / Assembled Reformat / Self-Check / Guardrails）の詳細実装ガイド。

---

## P29 - Template Generation（テンプレート生成）

### 問題

LLMに自由形式のテキスト生成を任せると、同じ意図でも出力内容・スタイル・品質がリクエストごとにばらつく。特にビジネス文書（顧客向けメール、規約文、製品説明など）では、品質の一貫性と事前レビューが不可欠であり、LLMへの毎回の依存はリスクが高い。

### 解決策

**オフラインでテンプレートを事前生成し、人間がレビューした後、推論時は変数の文字列置換のみを行う**。LLMは推論時ではなくバッチ処理フェーズで使用し、確定済みテンプレートに対してのみ実行時の変数埋め込みを行う。

```
[オフラインバッチ処理]
変数の組み合わせ → LLM生成 → 人間レビュー → テンプレートDB格納

[推論時（ランタイム）]
ユーザーリクエスト → 変数抽出 → テンプレート検索 → 文字列置換 → 出力
```

### 適用判断基準

| 条件 | Template Generation 適用 |
|------|--------------------------|
| 出力パターンが有限かつ列挙可能 | ✅ 強く推奨 |
| 高品質・一貫性のある出力が必須 | ✅ 推奨 |
| 出力内容を事前にレビューしたい | ✅ 推奨 |
| ユーザーごとに完全にユニークな出力が必要 | ❌ 不適合 |
| 変数の組み合わせ数が膨大（数百万以上） | ❌ 非現実的 |
| リアルタイムに動的なコンテンツが必要 | ❌ 不適合 |

### 実装のポイント

旅行代理店の感謝メール生成を例に実装する。`{destination}`×`{package_type}`×`{language}` の組み合わせをオフラインで事前生成する。

```python
from itertools import product
from string import Template
import json

# ---- オフラインバッチ処理 ----

DESTINATIONS = ["パリ", "ニューヨーク", "バリ島", "京都"]
PACKAGE_TYPES = ["豪華", "スタンダード", "エコノミー"]
LANGUAGES = ["ja", "en"]

def generate_template_key(destination: str, package_type: str, language: str) -> str:
    return f"{destination}_{package_type}_{language}"

def generate_all_templates(client, output_path: str) -> None:
    """全パターンのテンプレートをオフラインで生成してJSONに保存する"""
    templates: dict[str, str] = {}

    for dest, pkg, lang in product(DESTINATIONS, PACKAGE_TYPES, LANGUAGES):
        prompt = f"""
        以下の条件で旅行予約感謝メールのテンプレートを生成してください。
        目的地: {dest}、パッケージ: {pkg}、言語: {lang}

        変数プレースホルダーは ${{customer_name}}、${{travel_date}}、${{booking_id}} を使用してください。
        LLMへの依存を排除するため、定型文として品質高く作成してください。
        """

        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[{"role": "user", "content": prompt}]
        )

        key = generate_template_key(dest, pkg, lang)
        templates[key] = response.choices[0].message.content

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(templates, f, ensure_ascii=False, indent=2)

    print(f"{len(templates)} 件のテンプレートを生成しました")


# ---- ランタイム（推論時） ----

class TemplateEngine:
    def __init__(self, template_path: str) -> None:
        with open(template_path, encoding="utf-8") as f:
            self._templates: dict[str, str] = json.load(f)

    def render(
        self,
        destination: str,
        package_type: str,
        language: str,
        variables: dict[str, str],
    ) -> str:
        key = generate_template_key(destination, package_type, language)
        template_str = self._templates.get(key)

        if template_str is None:
            raise ValueError(f"テンプレートが見つかりません: {key}")

        # LLMを使わず、確定済みテンプレートへの純粋な文字列置換
        return Template(template_str).safe_substitute(variables)


# 使用例
engine = TemplateEngine("templates.json")
email = engine.render(
    destination="京都",
    package_type="豪華",
    language="ja",
    variables={
        "customer_name": "山田 太郎",
        "travel_date": "2025年5月3日",
        "booking_id": "KYT-2025-0042",
    },
)
```

### 注意事項・トレードオフ

| 項目 | 内容 |
|------|------|
| **コスト** | 事前生成時にAPIコストが集中する（組み合わせ数 × 生成コスト） |
| **柔軟性の制限** | 想定外の変数組み合わせには対応できない |
| **テンプレート管理** | テンプレートDB・バージョン管理・更新フローが必要 |
| **品質保証** | 人間レビューがボトルネックになる可能性がある |
| **推論時のLLM不使用** | ランタイムのレイテンシを大幅に削減できる |

---

## P30 - Assembled Reformat（アセンブルド・リフォーマット）

### 問題

LLMに「事実の収集」と「文章の生成」を同時に任せると、ハルシネーション（事実の捏造）が発生しやすい。特に商品スペック・在庫情報・価格などの正確性が求められるデータをLLMが生成すると、誤情報を含むリスクが高い。

### 解決策

**「データ収集フェーズ」と「文章整形フェーズ」を明確に分離する**。まず信頼できるソース（DB・API・OCR・RAGなど）からデータを確実に収集し、その検証済みデータをLLMに渡して整形・要約・言い換えのみを行わせる。

```
[Phase 1: アセンブル]
DB / API / OCR / RAG → データ収集 → 検証済み構造化データ

[Phase 2: リフォーマット]
検証済みデータ → LLM（整形・要約・言い換えのみ） → 最終出力
```

### 適用判断基準

| 条件 | Assembled Reformat 適用 |
|------|--------------------------|
| 出力に事実情報（価格・在庫・仕様）が含まれる | ✅ 強く推奨 |
| 信頼できるデータソース（DB・API）が存在する | ✅ 推奨 |
| ハルシネーションのリスクを最小化したい | ✅ 推奨 |
| 事実の収集と整形を同一LLMで行いたい | ❌ 非推奨 |
| 信頼できるデータソースが存在しない | ❌ 不適合 |

### 実装のポイント

商品カタログのマーケティング文章生成を例に実装する。商品スペックはDBから取得し、LLMは文章の整形のみを担当する。

```python
from dataclasses import dataclass
from openai import OpenAI

client = OpenAI()


@dataclass
class CatalogContent:
    """検証済み商品データ（Phase 1: アセンブル結果）"""
    product_name: str
    price: int           # 円
    stock_count: int
    features: list[str]
    category: str


def assemble_product_data(product_id: str) -> CatalogContent:
    """Phase 1: 信頼できるソース（DB・API）からデータを収集・検証する"""
    # 実際にはDBクエリやAPIコールを行う
    # ここでは例として固定データを返す
    db_result = {
        "name": "ワイヤレスノイズキャンセリングヘッドホン XZ-900",
        "price_yen": 45800,
        "stock": 127,
        "features": [
            "アクティブノイズキャンセリング（-40dB）",
            "バッテリー持続時間: 最大40時間",
            "マルチポイント接続（最大3デバイス）",
            "折りたたみ式デザイン",
        ],
        "category": "オーディオ機器",
    }

    return CatalogContent(
        product_name=db_result["name"],
        price=db_result["price_yen"],
        stock_count=db_result["stock"],
        features=db_result["features"],
        category=db_result["category"],
    )


def reformat_to_marketing_copy(content: CatalogContent) -> str:
    """Phase 2: 検証済みデータをLLMで整形する（事実生成は行わない）"""
    # LLMに渡すデータはすべて検証済み
    prompt = f"""
以下の確定済みデータを使って、商品のマーケティング文章を作成してください。
データ以外の情報を追加・推測・創作しないでください。

【確定済み商品データ】
商品名: {content.product_name}
価格: {content.price:,}円（税込）
在庫数: {content.stock_count}個
カテゴリ: {content.category}
機能一覧:
{chr(10).join(f"- {f}" for f in content.features)}

【指示】
上記データのみを使用して、顧客向けの魅力的な商品説明文（200字程度）を作成してください。
価格・在庫・機能は必ず上記の数値通りに記載してください。
"""

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.3,  # 創造性を抑え、データへの忠実性を優先
    )

    return response.choices[0].message.content


# 実行フロー
def generate_product_description(product_id: str) -> str:
    verified_data = assemble_product_data(product_id)      # Phase 1
    description = reformat_to_marketing_copy(verified_data)  # Phase 2
    return description
```

### 注意事項・トレードオフ

| 項目 | 内容 |
|------|------|
| **ハルシネーション抑制** | データ収集とLLMの役割分離により、事実誤認を大幅に低減 |
| **2段階のレイテンシ** | データ収集 + LLM呼び出しの合計時間が発生する |
| **プロンプト設計** | 「創作しないでください」という制約をプロンプトで明示する必要がある |
| **データソース依存** | Phase 1のデータ品質がそのまま最終出力品質に影響する |
| **低temperature推奨** | 整形フェーズは創造性より正確性を優先するためtemperatureを低く設定する |

---

## P31 - Self-Check（自己チェック）

### 問題

RAGやツール呼び出しを含む複雑なパイプラインでは、LLMが不確かな情報を高い確信度で出力するハルシネーションが発生する。ユーザーには出力の信頼度が見えず、誤情報をそのまま信じてしまうリスクがある。

### 解決策

**LLMのトークンlogprobsを利用して、出力の信頼度を定量的に評価する**。各トークンの確率（`e^logprob`）を計算し、低確率トークンが含まれる出力はハルシネーションの可能性が高いと判定して対処する。

主なアプローチ:
1. **Token Filtering**: 低確率トークンの置換・フラグ付け
2. **Sequence Sampling**: 複数サンプリングして多数決で一致率を検証
3. **Perplexity計算**: シーケンス全体の平均負対数尤度（低いほど自然）
4. **MLクラシファイア**: logprobsを特徴量としてハルシネーション分類器を訓練

### 適用判断基準

| 条件 | Self-Check 適用 |
|------|-----------------|
| 出力の信頼度を定量化したい | ✅ 強く推奨 |
| ハルシネーションの検出が重要 | ✅ 推奨 |
| 段階的な信頼度スコアが必要 | ✅ 推奨 |
| 使用するAPIがlogprobsをサポートする | ✅ 前提条件 |
| シンプルな分類タスクのみ | ❌ オーバーエンジニアリング |
| コストを最小化したい | ❌ 追加API呼び出しが必要 |

### 実装のポイント

飲食店レシートの解析を例に実装する。OCR結果から品名・数量・価格を抽出し、各フィールドにconfidence scoreを付与する。

```python
import math
from dataclasses import dataclass
from openai import OpenAI

client = OpenAI()


@dataclass
class ParsedItem:
    name: str
    quantity: int
    unit_price: int
    confidence: float  # 0.0〜1.0（logprobsから計算）


def calculate_token_probability(logprob: float) -> float:
    """logprobから確率に変換する（e^logprob）"""
    return math.e ** logprob


def parse_receipt_with_confidence(receipt_text: str) -> list[ParsedItem]:
    """レシートを解析し、各フィールドの信頼度スコアを返す"""
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {
                "role": "system",
                "content": "レシートから品名、数量、単価を抽出してJSON形式で返してください。",
            },
            {
                "role": "user",
                "content": f"以下のレシートを解析してください:\n{receipt_text}",
            },
        ],
        logprobs=True,          # logprobsを取得
        top_logprobs=3,         # 上位3候補のlogprobsも取得
        temperature=0.0,        # 決定的な出力
        response_format={"type": "json_object"},
    )

    choice = response.choices[0]
    logprob_content = choice.logprobs.content

    # 各トークンの確率を計算して最小確率をconfidenceとする
    token_probs = [
        calculate_token_probability(token_logprob.logprob)
        for token_logprob in logprob_content
        if token_logprob.logprob is not None
    ]

    # シーケンス全体の最小確率（最も不確かなトークン）
    min_confidence = min(token_probs) if token_probs else 0.0

    # 平均確率（全体的な信頼度）
    avg_confidence = sum(token_probs) / len(token_probs) if token_probs else 0.0

    # JSONを解析して結果を返す
    import json
    raw = json.loads(choice.message.content)

    items = []
    for item in raw.get("items", []):
        items.append(ParsedItem(
            name=item["name"],
            quantity=item["quantity"],
            unit_price=item["unit_price"],
            confidence=avg_confidence,
        ))

    return items


def check_and_flag_low_confidence(
    items: list[ParsedItem],
    threshold: float = 0.85,
) -> None:
    """信頼度が閾値を下回る項目をフラグ付けして報告する"""
    for item in items:
        status = "✅" if item.confidence >= threshold else "⚠️ 要確認"
        print(
            f"{status} {item.name} × {item.quantity} = "
            f"{item.unit_price:,}円 (confidence: {item.confidence:.2%})"
        )


# 実行例
receipt = """
アメリカーノ × 2  ¥660
カフェラテ × 1   ¥550
チーズケーキ × 1  ¥480
"""

items = parse_receipt_with_confidence(receipt)
check_and_flag_low_confidence(items, threshold=0.85)
```

### perplexity を使ったシーケンス全体の評価

```python
def calculate_perplexity(logprobs: list[float]) -> float:
    """シーケンスのperplexityを計算する（低いほど自然な出力）"""
    n = len(logprobs)
    if n == 0:
        return float("inf")
    avg_neg_log_prob = -sum(logprobs) / n
    return math.e ** avg_neg_log_prob
```

### 注意事項・トレードオフ

| 項目 | 内容 |
|------|------|
| **API制限** | logprobsをサポートするモデル（GPT-4o等）のみ適用可能 |
| **確率の解釈** | logprobは必ずしも「事実の正確性」ではなく「言語モデルの確信度」を表す |
| **コスト** | Sequence Samplingは複数回の推論が必要でコスト増大 |
| **閾値調整** | confidenceの閾値はユースケースによって最適値が異なる |
| **MLクラシファイア** | logprobsを特徴量にした分類器はハルシネーション検出精度が高い |

---

## P32 - Guardrails（ガードレール）

### 問題

LLMを本番環境で運用する際、有害なコンテンツ・プロンプトインジェクション・機密情報の漏洩・規約違反など、様々なリスクに対処する必要がある。単一のLLMへの依存だけではこれらを防ぎきれない。

### 解決策

**LLMの入力（前処理）と出力（後処理）の両方にガードレール層を設ける**。既製のガードレールライブラリ（NVIDIA NeMo Guardrails / LLM Guard / Guardrails AI）またはカスタムのLLM-as-Judgeを組み合わせて、多層防御を実現する。

```
ユーザー入力
    ↓
[前処理ガードレール]
  - トピック制限チェック
  - プロンプトインジェクション検出
  - 機密情報フィルタリング
    ↓
LLM（本体）
    ↓
[後処理ガードレール]
  - 有害コンテンツ検出
  - 規約違反チェック
  - ハルシネーション検出
    ↓
安全な出力
```

### 適用判断基準

| 条件 | Guardrails 適用 |
|------|-----------------|
| 本番環境でのLLMサービス提供 | ✅ 必須 |
| 有害コンテンツのリスクがある | ✅ 強く推奨 |
| プロンプトインジェクション対策が必要 | ✅ 推奨 |
| コンプライアンス要件がある | ✅ 推奨 |
| 内部ツール・実験環境 | 🟡 任意 |
| 厳格なレイテンシ要件がある | ⚠️ 非同期実装を検討 |

### 実装のポイント

#### 既製ライブラリ: LLM Guard

```python
from llm_guard import scan_output, scan_prompt
from llm_guard.input_scanners import BanTopics, PromptInjection, Toxicity
from llm_guard.output_scanners import BanTopics as OutputBanTopics, Relevance

# 入力スキャナーの設定
input_scanners = [
    Toxicity(threshold=0.7),           # 毒性コンテンツ検出
    PromptInjection(threshold=0.8),    # プロンプトインジェクション
    BanTopics(topics=["競合他社"], threshold=0.6),  # 禁止トピック
]

# 出力スキャナーの設定
output_scanners = [
    OutputBanTopics(topics=["競合他社"], threshold=0.6),
    Relevance(threshold=0.5),          # 入力との関連性チェック
]


def safe_llm_call(user_input: str, model_response: str) -> tuple[str, bool]:
    """
    ガードレール付きLLM呼び出しラッパー。
    returns: (処理済みレスポンス, 安全かどうか)
    """
    # 入力スキャン
    sanitized_prompt, results_valid, results_score = scan_prompt(
        input_scanners, user_input
    )

    if not all(results_valid.values()):
        blocked_scanners = [k for k, v in results_valid.items() if not v]
        return f"⚠️ 入力が制限されています: {blocked_scanners}", False

    # 出力スキャン
    sanitized_response, out_valid, out_score = scan_output(
        output_scanners, sanitized_prompt, model_response
    )

    if not all(out_valid.values()):
        return "⚠️ 安全性チェックのため応答を表示できません。", False

    return sanitized_response, True
```

#### カスタム: LLM-as-Judge ガードレール

```python
from openai import OpenAI

client = OpenAI()

JUDGE_SYSTEM_PROMPT = """
あなたはAIアシスタントの回答品質を評価するジャッジです。
以下の基準で回答を評価し、JSON形式で返してください:

{
  "safe": true/false,
  "reason": "判定理由",
  "severity": "low/medium/high"
}

評価基準:
- 有害・暴力的・差別的なコンテンツを含まないか
- プライバシーを侵害する情報を含まないか
- 事実として誤った重要情報を含まないか
- 法的に問題のある内容を含まないか
"""


def llm_as_judge_guardrail(user_input: str, llm_response: str) -> dict:
    """LLMを使ったカスタムガードレール判定"""
    judge_response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": JUDGE_SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"ユーザー入力: {user_input}\n\nAI回答: {llm_response}",
            },
        ],
        response_format={"type": "json_object"},
        temperature=0.0,
    )

    import json
    return json.loads(judge_response.choices[0].message.content)


class GuardedQueryEngine:
    """ガードレールを組み込んだクエリエンジン"""

    def __init__(self, base_llm_client: OpenAI) -> None:
        self._client = base_llm_client

    def query(self, user_input: str) -> str:
        # Step 1: 入力ガードレール
        input_check = llm_as_judge_guardrail(user_input, "")
        if not input_check.get("safe", True) and input_check.get("severity") == "high":
            return "申し訳ありませんが、このリクエストにはお応えできません。"

        # Step 2: LLM本体の呼び出し
        response = self._client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": user_input}],
        )
        raw_output = response.choices[0].message.content

        # Step 3: 出力ガードレール
        output_check = llm_as_judge_guardrail(user_input, raw_output)
        if not output_check.get("safe", True):
            severity = output_check.get("severity", "medium")
            if severity == "high":
                return "安全性チェックのため、この回答を提供できません。"
            # 中程度の場合は警告付きで返す
            return f"⚠️ 注意: この回答には確認が必要な内容が含まれている可能性があります。\n\n{raw_output}"

        return raw_output
```

### 注意事項・トレードオフ

| 項目 | 内容 |
|------|------|
| **レイテンシ増加** | ガードレール処理（特にLLM-as-Judge）がレスポンスタイムを増加させる |
| **False Positive** | 過剰な制限により正当なリクエストが拒否されるリスク |
| **False Negative** | ガードレールをすり抜ける悪意あるプロンプトが存在する可能性 |
| **コスト** | LLM-as-Judgeは追加のAPI呼び出し費用が発生する |
| **非同期処理** | 重要度の低いチェックは非同期で実行してレイテンシを削減可能 |
| **多層防御** | 単一ガードレールへの依存を避け、複数の検出手法を組み合わせる |
| **継続的更新** | 新たな攻撃手法への対応のため、ルールを定期的に更新する |

---

## パターン選択フローチャート

```
本番LLMサービスを構築する
         ↓
  ──────────────────
  ハルシネーション・安全性リスクはあるか？
  ──────────────────
       ↓ Yes
  ────────────────────────────
  出力パターンが有限で列挙可能か？
  ────────────────────────────
    ↓ Yes              ↓ No
  P29                信頼できるデータソースがあるか？
  Template            ↓ Yes          ↓ No
  Generation         P30            LLM出力の
                  Assembled       信頼度を測りたいか？
                  Reformat        ↓ Yes      ↓ No
                                P31         P32
                              Self-Check  Guardrails
```

## 関連パターン

| パターン | 関係 |
|---------|------|
| P29 Template Generation | 事前生成によりP32ガードレールの負荷を軽減できる |
| P30 Assembled Reformat | データ検証済みのためP31 Self-Checkと組み合わせると高精度 |
| P31 Self-Check | P32ガードレールの一部としてlogprobs信頼度チェックを組み込める |
| P24 Small Language Model | 軽量モデルをP32ガードレールの判定器として使用できる |
