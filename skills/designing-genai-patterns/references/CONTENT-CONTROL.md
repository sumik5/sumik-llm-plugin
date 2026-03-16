# コンテンツ制御パターン（P1–P5）

> LLMの出力スタイル・形式・品質を制御する5つのパターン。「制御の強度」と「実装の複雑さ」のトレードオフが設計判断の核心となる。

---

## 目次

- [Pattern 1: Logits Masking](#pattern-1-logits-masking)
- [Pattern 2: Grammar](#pattern-2-grammar)
- [Pattern 3: Style Transfer](#pattern-3-style-transfer)
- [Pattern 4: Reverse Neutralization](#pattern-4-reverse-neutralization)
- [Pattern 5: Content Optimization](#pattern-5-content-optimization)
- [パターン比較まとめ](#パターン比較まとめ)

---

## Pattern 1: Logits Masking

### 問題

LLMがテキスト生成する際、ブランドルール・法規制・SEOキーワード要件など「使ってよい語彙」「使ってはいけない語彙」の制約を守らせたい場合がある。Zero-shotプロンプトでは指示を無視することがあり、生成後にフィルタリングしても「再試行」のコストがかかる。特定の語を必ず含む・含まないといったルールは、プロンプトだけでは確実に強制できない。

### 解決策

生成プロセスの「サンプリング段階」に割り込み、ルールを満たさない候補トークンの確率をゼロ（logit値を-∞）にすることで、出力が必ずルールに適合するよう強制する。これが Logits Masking パターンの核心だ。

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| 特定語彙の禁止・必須化が必要（法規制・ブランドガイドライン） | ✅ Logits Masking |
| 構造化フォーマット（JSON/XML）の保証が必要 | ⬜ Pattern 2: Grammar を検討 |
| スタイルニュアンスの制御（Hard ruleで表現困難） | ⬜ Pattern 3: Style Transfer を検討 |
| API提供のクローズドモデルのみ使用可能 | ❌ 利用困難（モデル内部アクセス不可） |
| 成功率が低い（70%以上の失敗率）場合の再試行アプローチ | ❌ 避ける（平均3.3回の生成が必要） |

### 実装のポイント

Hugging Face Transformers の `LogitsProcessor` を継承して実装する：

```python
from transformers import LogitsProcessor, pipeline
import numpy as np
import torch

class BrandLogitsProcessor(LogitsProcessor):
    def __init__(self, tokenizer, positives: list[str], negatives: list[str]):
        self.tokenizer = tokenizer
        self.positives = positives
        self.negatives = negatives

    def __call__(
        self, input_ids: torch.LongTensor, input_logits: torch.FloatTensor
    ) -> torch.FloatTensor:
        output_logits = input_logits.clone()

        # 各候補シーケンスをスコアリング
        scores = []
        for idx, seq in enumerate(input_ids):
            decoded = self.tokenizer.decode(seq)
            decoded_lower = decoded.lower()
            score = (
                sum(1 for p in self.positives if p in decoded_lower) -
                sum(1 for n in self.negatives if n in decoded_lower)
            )
            scores.append(score)

        # 最高スコア以外のシーケンスをマスク（-10000 ≈ -∞）
        max_score = max(scores)
        for idx, score in enumerate(scores):
            if score != max_score:
                output_logits[idx] = -10000

        return output_logits

# 使用例
MODEL_ID = "meta-llama/Llama-3.2-3B-Instruct"
pipe = pipeline(task="text-generation", model=MODEL_ID)

processor = BrandLogitsProcessor(
    tokenizer=pipe.tokenizer,
    positives=["whey", "nutrients", "protein"],
    negatives=["quality", "perfect", "award winning"]
)

result = pipe(
    "Write a product description for a protein drink.",
    max_new_tokens=256,
    do_sample=True,
    temperature=0.8,
    num_beams=10,
    logits_processor=[processor]
)
```

**バックトラッキングが必要な場合**（アクロスティック詩など複雑なルール）：

```python
# pipeline() ではなく model.generate() を直接呼ぶ
results = pipe.model.generate(
    **input_ids,
    max_new_tokens=16,      # 短いチャンクずつ生成
    num_beams=10,
    num_return_sequences=10,
    output_scores=True,
    renormalize_logits=True,
    return_dict_in_generate=True,
)
# 各チャンクのルール適合確認 → 失敗なら input_ids を巻き戻して再生成
```

### 注意事項・トレードオフ

| 側面 | 内容 |
|------|------|
| **メリット** | ルールへの確実な適合（理論上100%）、最良の適合シーケンスを自動選択 |
| **デメリット** | Hugging Face Transformers が必要（APIモデル不可）、実装が複雑 |
| **パラメータ** | `num_beams` を増やすと品質向上だが計算コスト増大 |
| **バックトラッキング** | 複雑なルールでは必要。`max_iter` で最大試行回数を制限し、超えたらrefusalを返す |
| **代替パターン** | ルールが構造的（JSONスキーマ等）なら Pattern 2: Grammar の方が適切 |

---

## Pattern 2: Grammar

### 問題

LLMの生成テキストを特定のデータスキーマや構造フォーマット（JSON・XML・SQLなど）に適合させたい。ダウンストリームアプリケーションへの受け渡しが前提であるため、バリデーションエラーを起こすような「ほぼ正しい」JSON出力は許容できない。プロンプトで「JSONで出力せよ」と指示しても、コードブロックマークダウンが混入したり、フィールド名が変動したりする問題が起きる。

### 解決策

出力を context-free metasyntax（文脈自由メタ構文）、典型的にはPydanticの `dataclass` や JSON Schema で定義し、モデルがそのスキーマに厳密に従った出力のみを生成するよう強制する。これにより生成結果をそのままパースできる。

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| ダウンストリームアプリがJSONを直接パースする | ✅ Grammar |
| フィールド名・型・必須項目が固定されている | ✅ Grammar |
| スタイルニュアンス（tone・vocabulary）の制御が必要 | ⬜ Pattern 3: Style Transfer |
| レスポンスが非構造化テキストで十分 | ❌ 過剰設計 |

### 実装のポイント

PydanticのデータクラスをLLMに渡すことで構造化出力を強制する：

```python
from pydantic import BaseModel
from typing import Optional
from enum import Enum

class Sentiment(str, Enum):
    POSITIVE = "positive"
    NEGATIVE = "negative"
    NEUTRAL = "neutral"

class ProductReview(BaseModel):
    product_name: str
    rating: int  # 1-5
    sentiment: Sentiment
    summary: str
    pros: list[str]
    cons: list[str]
    recommended: bool

# OpenAI Structured Outputs（Pydantic モデルをスキーマとして渡す）
from openai import OpenAI
client = OpenAI()

response = client.beta.chat.completions.parse(
    model="gpt-4o-mini",
    messages=[
        {"role": "system", "content": "Analyze the product review."},
        {"role": "user", "content": "I bought this laptop... [review text]"}
    ],
    response_format=ProductReview,  # Pydantic モデルを直接指定
)
review: ProductReview = response.choices[0].message.parsed
```

LlamaIndex で Grammar を使う場合（Hugging Face モデル）：

```python
from llama_index.program.openai import OpenAIPydanticProgram

program = OpenAIPydanticProgram.from_defaults(
    output_cls=ProductReview,
    prompt_template_str="Analyze: {review_text}",
    verbose=True,
)
result = program(review_text="I bought this laptop...")
# result は ProductReview インスタンスとして型安全に利用可能
```

### 注意事項・トレードオフ

| 側面 | 内容 |
|------|------|
| **メリット** | 型安全なパース、ダウンストリームとの統合が容易、スキーマ変更に追従しやすい |
| **デメリット** | 自由記述テキストは表現困難、スキーマ設計コストがかかる |
| **制約の硬さ** | Logits Masking > Grammar > Style Transfer の順で強制力が強い |
| **代替パターン** | 語彙レベルの細粒度制御は Logits Masking (P1) を検討 |

---

## Pattern 3: Style Transfer

### 問題

LLMに特定のトーン・スタイルのコンテンツを生成させたい。しかし、そのスタイルの特徴は直感的にはわかるが（「ブランドらしい」「マーケティング向け」など）、ルールとして明文化するのが難しい。Zero-shotでスタイル指定しても、モデルは自社のブランドスタイルを知らないため汎用的な文体で返答してしまう。

**適用条件（3つを満たす場合）**：
1. 素材コンテンツは入手できるが望みのスタイルではない
2. スタイルのニュアンスを直接ルール化するのが困難
3. 変換例（入力→出力ペア）が手元にある

### 解決策

2つのアプローチがある：

**Option 1: Few-shot学習**（例が数個の場合）: プロンプトに入出力例を埋め込み、その例からスタイルを推論させる。

**Option 2: Fine-tuning**（例が数百〜数千個の場合）: モデルをスタイル変換タスクに特化して微調整し、推論時のプロンプトを短縮する。

### 適用判断基準

| 条件 | 推奨アプローチ |
|------|-------------|
| 例が1〜10個しかない | Few-shot学習 |
| 例が100〜数千個ある | Fine-tuning |
| プロトタイプ・検証フェーズ | Few-shot学習（シンプル） |
| プロダクション・レイテンシ・コストが重要 | Fine-tuning（短いプロンプト） |
| スタイル適合の完全な保証が必要 | Pattern 1 or 2（Style Transferは「ソフト」な強制） |

### 実装のポイント

**Few-shot学習の実装**：

```python
def style_transfer_few_shot(input_text: str, examples: list[dict]) -> str:
    """
    examples: [{"input": "...", "output": "..."}, ...]
    """
    prompt = "次のスタイルで変換してください：\n\n"

    for example in examples:
        prompt += f"入力: {example['input']}\n"
        prompt += f"出力: {example['output']}\n\n"

    prompt += f"入力: {input_text}\n出力:"
    return prompt

# 使用例：学術論文 → マーケティングブログへの変換
examples = [
    {
        "input": "The study demonstrates statistically significant improvements...",
        "output": "我々のデータが証明する：劇的な改善効果！..."
    },
    # さらに数例追加
]
result = style_transfer_few_shot(new_paper, examples)
```

**Fine-tuningの実装**（OpenAI）：

```python
from openai import OpenAI
client = OpenAI()

# Fine-tuningジョブ作成
training_file = client.files.create(
    file=open("fine_tuning_dataset.jsonl", "rb"),
    purpose="fine-tune"
)
job = client.fine_tuning.jobs.create(
    training_file=training_file.id,
    model="gpt-4o-mini"
)

# ジョブ完了待ち
import time
while True:
    status = client.fine_tuning.jobs.retrieve(job.id)
    if status.status in ["succeeded", "failed"]:
        break
    time.sleep(30)

# Fine-tuningモデルを通常モデルと同様に使用
response = client.chat.completions.create(
    model=status.fine_tuned_model,
    messages=[{"role": "user", "content": new_text}]
)
```

**Fine-tuningデータセットの形式**（JSONL）：

```jsonl
{"messages": [
    {"role": "system", "content": "Convert to brand style."},
    {"role": "user", "content": "[neutral text]"},
    {"role": "assistant", "content": "[brand-style text]"}
]}
```

### 注意事項・トレードオフ

| 側面 | 内容 |
|------|------|
| **Few-shot メリット** | 実装シンプル、即座に試せる、例を追加するだけ |
| **Few-shot デメリット** | コンテキスト長を消費、例が多いと混乱・矛盾が生じる |
| **Fine-tuning メリット** | 高精度なスタイル適合、推論コスト・レイテンシ削減 |
| **Fine-tuning デメリット** | 訓練コスト・データキュレーションコスト、MLOps専門知識が必要 |
| **共通の限界** | スタイル適合の保証はソフト（Hard ruleではない） |
| **代替パターン** | 保証が必要 → P1/P2、例がない場合 → Pattern 4: Reverse Neutralization |

---

## Pattern 4: Reverse Neutralization

### 問題

特定スタイルのコンテンツを生成したいが、Style Transfer（P3）に必要な「入出力の変換例ペア」が手元にない。**スタイル付きコンテンツ（出力側）は豊富にある**が、それに対応する「中立な入力」がない状況だ。例：個人のメールスタイルで新しいトピックのメールを書く、法律事務所の文書スタイルで新しい案件の通知を作る。

### 解決策

**「逆変換」**を活用する：

1. **中立化（Neutralization）**: 既存のスタイル付きコンテンツ（例：個人スタイルのメール）をLLMで中立形式に変換
2. **データセット作成**: 中立形式↔スタイル付きの対応ペアを作成（入出力を逆転）
3. **Fine-tuning**: 「中立→スタイル付き」に変換するモデルを学習
4. **推論**: 新しいトピックを基盤モデルで中立生成 → Fine-tunedモデルでスタイル変換

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| スタイル付きコンテンツは豊富だが変換例ペアがない | ✅ Reverse Neutralization |
| Style Transferの変換例ペアがある | ⬜ Pattern 3: Style Transfer の方がシンプル |
| プライバシー配慮でスタイルを除去したい | ✅ 中立化のみで利用可能 |
| 複数著者の文書を統一スタイルにしたい | ✅ Reverse Neutralization |

### 実装のポイント

**Step 1: 中立化（既存スタイル付きコンテンツから中立形式を生成）**：

```python
from openai import OpenAI
client = OpenAI()

def neutralize_text(styled_text: str) -> str:
    """スタイル付きテキストを中立な専門文書スタイルに変換"""
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {
                "role": "system",
                "content": "指定されたテキストから個人的なスタイルを除去し、"
                           "ビジネス上の役員間のコミュニケーションに適した"
                           "中立的なプロフェッショナルな文章に変換してください。"
            },
            {"role": "user", "content": styled_text}
        ]
    )
    return response.choices[0].message.content

# 例：個人スタイルメール → 中立形式
original = "やったー！Emilyさん、チームへようこそ！🎉超嬉しい！"
neutral = neutralize_text(original)
# → "Subject: Welcome to the Team\n\nDear Emily, ..."
```

**Step 2: Fine-tuning用データセット作成（入出力を逆転）**：

```python
import json

def create_fine_tuning_dataset(
    styled_texts: list[str],
    neutral_texts: list[str]
) -> list[dict]:
    """中立→スタイル付きの学習データを作成"""
    dataset = []
    for neutral, styled in zip(neutral_texts, styled_texts):
        dataset.append({
            "messages": [
                {
                    "role": "system",
                    "content": "プロフェッショナルなメールを個人スタイルに変換してください。"
                },
                {"role": "user", "content": neutral},
                {"role": "assistant", "content": styled}  # 逆転：出力が元のスタイル
            ]
        })
    return dataset

# 200件程度のペアがあれば十分
dataset = create_fine_tuning_dataset(personal_emails, neutralized_emails)
with open("reverse_neutralization_dataset.jsonl", "w") as f:
    for item in dataset:
        f.write(json.dumps(item, ensure_ascii=False) + "\n")
```

**Step 4: 推論（2ステップパイプライン）**：

```python
def generate_styled_content(topic_prompt: str, fine_tuned_model_id: str) -> str:
    # Step A: 基盤モデルで中立形式のコンテンツを生成
    neutral_response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "役員間の標準的なビジネスメールを書いてください。"},
            {"role": "user", "content": topic_prompt}
        ]
    )
    neutral_text = neutral_response.choices[0].message.content

    # Step B: Fine-tunedモデルで個人スタイルに変換
    styled_response = client.chat.completions.create(
        model=fine_tuned_model_id,
        messages=[
            {"role": "system", "content": "プロフェッショナルなメールを個人スタイルに変換してください。"},
            {"role": "user", "content": neutral_text}
        ]
    )
    return styled_response.choices[0].message.content
```

### 注意事項・トレードオフ

| 側面 | 内容 |
|------|------|
| **メリット** | 変換例ペアなしでFine-tuningデータを自動生成できる |
| **重要な注意** | 中立化の品質がすべてを左右する（「過度な中立化」でコンテンツが失われる） |
| **中立形式の選択** | 「大学生向け」「役員間コミュニケーション」など具体的な定義が必要。LLMによって「中立」の解釈が異なる |
| **品質検証** | オリジナルと中立化テキストのembedding類似度でコンテンツ保持を確認 |
| **データ多様性** | トピック多様性をトピックモデリングで確認（Fine-tuningはデータ分布に依存） |
| **代替パターン** | 変換例ペアがある → P3 Style Transfer |

---

## Pattern 5: Content Optimization

### 問題

最良のコンテンツスタイルで生成したいが、「最良のスタイル」が何かを事前に知らない。従来のA/Bテストは「何が違うか」を仮説として定義する必要があり、仮説がなければテスト設計もできない。さらに、A/Bテストで「どちらが良いか」がわかっても、その理由がわからなければ次回の生成に活かせない。

### 解決策

**Direct Preference Optimization（DPO）** による選好学習。「なぜ良いか」ではなく「どちらが良いか」だけを知って、それを生成するよう直接モデルの重みを調整する。

4ステップ：
1. 同じプロンプトから2つのコンテンツバリアントを生成
2. 比較して「勝者」を選ぶ（人間・LLM-as-Judge・実際の成果指標）
3. `{prompt, chosen, rejected}` の学習データセットを作成
4. DPOでモデルを選好チューニング

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| 最適スタイルの仮説がない（A/Bテストの設計が困難） | ✅ Content Optimization |
| コンテンツ品質の客観的評価指標がある | ✅ Content Optimization |
| スタイル要件が明確で変換例もある | ⬜ Pattern 3: Style Transfer の方がシンプル |
| モデルの重み変更が許可されない環境 | ❌ 利用困難 |

### 実装のポイント

**Step 1: コンテンツペア生成**：

```python
from transformers import pipeline
import random

MODEL_ID = "Qwen/Qwen2-0.5B-Instruct"
pipe = pipeline("text-generation", model=MODEL_ID)

def generate_content_pair(prompt: str) -> tuple[str, str]:
    """同一プロンプトから異なるtemperatureで2つのバリアントを生成"""
    results = []
    for _ in range(2):
        response = pipe(
            prompt,
            temperature=random.uniform(0.2, 0.9),
            max_new_tokens=200
        )
        results.append(response[0]["generated_text"])
    return results[0], results[1]
```

**Step 2: LLM-as-Judgeによる比較**：

```python
from pydantic import BaseModel
from openai import OpenAI

class ContentComparison(BaseModel):
    a_is_better_than_b: bool
    reasoning: str

def judge_content(content_a: str, content_b: str, criteria: str) -> ContentComparison:
    client = OpenAI()
    response = client.beta.chat.completions.parse(
        model="gpt-4o",
        messages=[
            {
                "role": "system",
                "content": f"""あなたは広告の専門家です。
以下の評価基準で2つのコンテンツを比較し、content_aがcontent_bより優れているかを判定してください。
評価基準: {criteria}"""
            },
            {
                "role": "user",
                "content": f"content_a:\n{content_a}\n\ncontent_b:\n{content_b}"
            }
        ],
        response_format=ContentComparison,
    )
    return response.choices[0].message.parsed
```

**Step 4: DPOによるFine-tuning**：

```python
from trl import DPOConfig, DPOTrainer
from transformers import AutoModelForCausalLM, AutoTokenizer

MODEL_ID = "Qwen/Qwen2-0.5B-Instruct"
model = AutoModelForCausalLM.from_pretrained(MODEL_ID)
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

# train_dataset: {"prompt": str, "chosen": str, "rejected": str} のリスト
training_args = DPOConfig(output_dir="content-optimized-model")
trainer = DPOTrainer(
    model=model,
    args=training_args,
    processing_class=tokenizer,
    train_dataset=train_dataset
)
trainer.train()
trainer.save_model(training_args.output_dir)
```

### 注意事項・トレードオフ

| 側面 | 内容 |
|------|------|
| **最重要ポイント** | Step 2（評価ステップ）がパターン全体の品質を決定する |
| **評価の罠** | 指標と真の目的の乖離に注意（エンゲージメント時間を最適化すると読みにくいコンテンツを生成する可能性） |
| **メリット** | スタイル仮説不要、継続的な改善サイクルが構築できる |
| **デメリット** | モデルの重み変更が必要、Fine-tuning環境が必要 |
| **代替パターン** | 評価指標がある → LLM-as-Judge (P17) との組み合わせが有効 |

---

## パターン比較まとめ

| パターン | 制御強度 | 実装複雑さ | 必要リソース | 適したユースケース |
|---------|---------|----------|------------|----------------|
| P1 Logits Masking | 最強（ハード） | 高 | OSS モデル（HF Transformers） | 語彙禁止・必須化 |
| P2 Grammar | 強（スキーマ） | 中 | 任意のモデル | 構造化出力（JSON/XML） |
| P3 Style Transfer | 中（ソフト） | 低〜中 | 変換例ペア | トーン・語調の変換 |
| P4 Reverse Neutralization | 中（ソフト） | 高 | スタイル付きコンテンツのみ | 例ペアがない場合のスタイル転換 |
| P5 Content Optimization | 動的（選好学習） | 高 | 評価機構 + Fine-tuning環境 | 最良スタイルが不明な場合 |

**選択フロー**：
```
スタイル制御が必要？
├── ハードルール（語彙禁止・必須） → P1 Logits Masking
├── 構造化フォーマット（JSON/XML） → P2 Grammar
├── 変換例ペアがある → P3 Style Transfer
├── スタイル付きコンテンツのみある → P4 Reverse Neutralization
└── 最良スタイルが未知 → P5 Content Optimization
```
