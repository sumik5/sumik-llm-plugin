# モデル能力拡張パターン（Model Capabilities）

> 事前学習済みモデルが苦手とするタスクを克服する4パターン。推論強化・探索推論・ファインチューニング・学習データ生成の各アプローチを提供する。

## 目次

- [Pattern 13: Chain of Thought](#pattern-13-chain-of-thought)
- [Pattern 14: Tree of Thoughts](#pattern-14-tree-of-thoughts)
- [Pattern 15: Adapter Tuning](#pattern-15-adapter-tuning)
- [Pattern 16: Evol-Instruct](#pattern-16-evol-instruct)

---

## Pattern 13: Chain of Thought

### 問題

LLMは以下の推論タスクで直接回答を試みると失敗しやすい：

- **学習データカバレッジ不足**：業界固有の計算・手順（石油ガス産業の流量計算、投資委員会メモの作成など）は訓練データに存在しない
- **マルチステップ推論の失敗**：「SIN-DFW-YYZ の手荷物規則は？」— 最終目的地（YYZ=カナダ）の判定に複数ステップが必要なのに、中間地点（DFW=米国）で誤答する
- **ブラックボックス回答**：推論プロセスを示さず直接回答するため、エラーの特定・バイアスの検出が困難

### 解決策

プロンプトを修正して段階的推論を明示的に要求する（Chain of Thought: CoT）。3つのバリアントがある：

1. **Zero-shot CoT**：「ステップバイステップで考えてください」を追加するだけ
2. **Few-shot CoT**：同様の問題を例題（Q&A形式）として提示してから質問
3. **Auto-CoT**：Few-shot の例題をベクトルDBから動的に選択

### 適用判断基準

| 条件 | 推奨バリアント |
|------|--------------|
| モデルが「怠け者」（持っている知識を使わない） | Zero-shot CoT |
| ドメイン固有の複雑な推論が必要 | Few-shot CoT |
| 多様な問題タイプを自動処理したい | Auto-CoT |
| 知識そのものが欠けている（データギャップ） | RAG（P6-P12）との組み合わせが必要 |
| 線形に解けない探索的な問題 | P14 Tree of Thoughts |

### 実装のポイント

**Zero-shot CoT（最もシンプル）**

```python
def zero_shot_cot(llm, question: str) -> str:
    """「ステップバイステップ」を追加するだけで推論能力が引き出される"""
    prompt = f"{question}\n\nステップバイステップで考えてください。"
    return llm.chat([{"role": "user", "content": prompt}])

# 使用例：業界固有の計算
answer = zero_shot_cot(llm, "直径25cmのパイプで100m、7barの圧力差でTexas Sweet原油の流量は？")
# → モデルが粘度・流体力学方程式を自動的に使用して回答
```

**Few-shot CoT（複雑な業務ロジック向け）**

```python
def few_shot_cot(llm, examples: list[dict], question: str) -> str:
    """例題で解法パターンをデモンストレーションしてから質問"""
    example_text = "\n\n".join([
        f"例題{i+1}:\nQ: {ex['question']}\nA: {ex['answer']}"
        for i, ex in enumerate(examples)
    ])
    prompt = f"""{example_text}

Q: {question}
A:"""
    return llm.chat([{"role": "user", "content": prompt}])

# 手荷物ルールの例題定義
baggage_examples = [
    {
        "question": "CDG-ATL-SEA の手荷物許容量は？（米国最終地または特別ニーズで50kg、それ以外40kg）",
        "answer": "最終目的地はSEA（米国）のため、手荷物許容量は50kgです。"
    },
    {
        "question": "CDG-LHR-NBO の手荷物許容量は？",
        "answer": "最終目的地はNBO（ケニア）のため、手荷物許容量は40kgです。"
    }
]
```

**Auto-CoT（例題を動的選択）**

```python
from pydantic_ai import Agent

def build_example_store(llm, questions: list[str]) -> list[dict]:
    """質問バンクからZero-shot CoTで例題を自動生成してDBに格納"""
    examples = []
    for q in questions:
        answer = zero_shot_cot(llm, q)
        # 正確性・一貫性をチェックして合格したものをストアに追加
        if passes_quality_check(q, answer):
            examples.append({"question": q, "answer": answer, "embedding": embed(q)})
    return examples

def auto_cot(llm, example_store: list[dict], question: str, top_k: int = 3) -> str:
    """質問に最も近い例題を動的に選択してFew-shot CoTを実行"""
    query_embedding = embed(question)
    # コサイン類似度で上位k件の例題を取得
    closest = sorted(
        example_store,
        key=lambda ex: cosine_similarity(query_embedding, ex["embedding"]),
        reverse=True
    )[:top_k]
    return few_shot_cot(llm, [{"question": ex["question"], "answer": ex["answer"]} for ex in closest], question)
```

### 注意事項・トレードオフ

| 観点 | 内容 |
|------|------|
| **データギャップには効かない** | CoTは知識を使うプロセスを改善するが、知識自体が欠如している場合は解決できない（地図やRAGとの組み合わせが必要） |
| **逐次推論の限界** | 正解が一本道でない（探索・バックトラックが必要な）問題にはP14 ToTが適切 |
| **トークンコスト増加** | ステップバイステップの推論は出力トークンが増える。Few-shotはさらに入力トークンも増加 |
| **例題の品質依存** | Few-shot CoTは例題の質が全て。悪い例題は誤った推論パターンを誘発 |
| **RAGとの違い** | RAGは知識（データ）を追加、CoTは推論方法（論理）を示す。RAGは魚を与え、CoTは釣り方を教える |

---

## Pattern 14: Tree of Thoughts

### 問題

Chain of Thought（P13）は線形な推論ステップしか処理できない。以下の問題は対応不可：

- **初期パスへの固着**：CoTは最初に選んだアプローチを貫き通すため、初期判断が誤っていると全体が崩れる
- **バックトラック不可**：一本道の推論では行き詰まりを認識できない
- **中間評価なし**：各ステップの質を評価して方向転換する仕組みがない

例：4つのランダムな文で終わる4段落エッセイの作成、サプライチェーン最適化、複数選択肢が存在する戦略判断。

### 解決策

問題解決をツリー探索として扱う。各ステップで複数の「思考」を生成・評価し、最も有望なパスのみを継続する（Beam Search）：

1. **思考生成（Thought Generation）**：現在の状態から複数の次ステップを生成
2. **パス評価（Path Evaluation）**：各パスを0-100でスコアリング
3. **ビームサーチ（Beam Search）**：上位K個のパスのみ継続
4. **解答生成（Summary Generation）**：最良パスに基づき最終回答を生成

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| 複数の解法候補が存在し比較が必要 | ToT が有効 |
| 戦略的計画・最適化問題 | ToT が有効（サプライチェーン、リソース配分など） |
| バックトラックが必要な創造的作業 | ToT が有効（複雑な文章構成など） |
| 線形な手順で解ける問題 | P13 CoT で十分（ToT はオーバーエンジニアリング） |
| レイテンシ・コスト制約が厳しい | ToT は不向き（多数のLLM呼び出しが必要） |

### 実装のポイント

**ToT コア実装**

```python
import heapq
import json
from typing import Any

class TreeOfThoughts:
    def __init__(self, llm, num_thoughts: int = 3, beam_width: int = 2, max_steps: int = 4):
        self.llm = llm
        self.num_thoughts = num_thoughts
        self.beam_width = beam_width
        self.max_steps = max_steps

    def generate_thoughts(self, state: str, step: int) -> list[str]:
        """現在の状態から多様な次ステップを生成"""
        prompt = f"""{state}

Tree of Thoughts 法でこの問題を解いています（ステップ {step}/{self.max_steps}）。
{self.num_thoughts}つの異なるアプローチを JSON リストで生成してください。
各アプローチは互いに実質的に異なるものにしてください。"""
        response = self.llm.chat([{"role": "user", "content": prompt}])
        return json.loads(response)

    def evaluate_state(self, state: str, problem: str) -> float:
        """推論パスの有望度を0-100でスコアリング"""
        prompt = f"""
問題: {problem}
推論パス: {state}

このパスの有望度を0-100で評価してください。
- 論理的正確性 (30%)
- 進捗度 (30%)
- 問題理解の深さ (20%)
- 完全解への可能性 (20%)
スコアのみ（整数）を返してください。"""
        score_str = self.llm.chat([{"role": "user", "content": prompt}]).strip()
        return int(score_str) / 100.0

    def solve(self, problem: str) -> str:
        """ToT メインループ"""
        beam = [(0.0, problem, [])]  # (負スコア, 状態, パス)
        best_final_states = []

        for step in range(1, self.max_steps + 1):
            candidates = []
            for _, current_state, reasoning_path in beam:
                thoughts = self.generate_thoughts(current_state, step)
                for thought in thoughts:
                    new_state = f"{current_state}\nステップ{step}: {thought}"
                    new_path = reasoning_path + [f"ステップ{step}: {thought}"]
                    score = self.evaluate_state(new_state, problem)

                    # スコア0.9以上は早期終了候補
                    if score > 0.9:
                        best_final_states.append((score, new_state, new_path))

                    candidates.append((-score, new_state, new_path))

            # 上位 beam_width 個のパスを選択
            beam = [
                (-score, state, path)
                for score, state, path in heapq.nsmallest(self.beam_width, candidates)
            ]

        # 最良パスで最終回答を生成
        if best_final_states:
            _, best_state, best_path = max(best_final_states, key=lambda x: x[0])
        else:
            _, best_state, best_path = max(beam, key=lambda x: x[0])

        return self.generate_final_answer(problem, best_state)

    def generate_final_answer(self, problem: str, final_state: str) -> str:
        prompt = f"""問題: {problem}
推論パス: {final_state}

上記の推論に基づき、問題への簡潔な回答を提供してください。"""
        return self.llm.chat([{"role": "user", "content": prompt}])
```

**使用例（サプライチェーン最適化）**

```python
tot = TreeOfThoughts(llm, num_thoughts=3, beam_width=2, max_steps=4)
problem = """
サプライチェーンを最適化してください:
- 製造拠点候補: メキシコ、ベトナム、ポーランド
- 配送センター: アトランタ、シカゴ、ダラス、シアトル
- 輸送手段: 航空、海上
- 需要変動: ±20%
- アジア航路の最近の混乱

コスト・納期信頼性・リスク分散を考慮した最適構成を提示してください。
"""
result = tot.solve(problem)
```

### 注意事項・トレードオフ

| 観点 | 内容 |
|------|------|
| **コスト** | `num_thoughts × beam_width × max_steps` 回の LLM 呼び出し。例: 3×2×4 = 24回 |
| **レイテンシ** | 直列実行が前提。並列化でも数十秒のレイテンシが発生 |
| **評価スコアの信頼性** | LLMが自身の推論を評価するのは循環的。外部評価基準があるとより安定 |
| **P13との使い分け** | シンプルな多段階推論はCoT、探索が必要なら ToT。まずCoTを試してから検討 |
| **P23 Multiagentとの類似** | マルチエージェント（P23）では異なるエージェントが協調するが、ToTは単一モデルが内部で探索 |

---

## Pattern 15: Adapter Tuning

### 問題

プロンプトエンジニアリングやFew-shotでは対応できないケースがある：

- **プロンプトの限界**：数百件の例題を毎回コンテキストに含めるのはコスト・レイテンシ的に非現実的
- **ブランドアライメント**：企業固有のトーン・スタイル・形式を安定して再現したい
- **タスク特化の品質**：分類・要約・構造化抽出など特定タスクで一貫した高品質出力が必要
- **Full Fine-tuningは過剰**：数百万パラメータ全体を再訓練するのは時間・GPU費用が大きすぎる

### 解決策

基盤モデルの重みをフリーズし、少数のアダプター層（LoRA）のみを訓練する Parameter-Efficient Fine-Tuning（PeFT）：

- 訓練パラメータ数: 基盤モデルの1-3%程度
- 必要データ量: 100〜数千件の入出力ペア
- 訓練時間: シングルGPUで数十分〜1時間
- 推論時: アダプター層を基盤モデルに挿入して使用

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| 特定タスク（分類・要約・抽出）の品質を向上したい | Adapter Tuning が有効 |
| ブランド固有のレスポンス形式が必要 | Adapter Tuning が有効 |
| 数百〜数千の例題がある | Adapter Tuning が有効 |
| 業界ジャーゴン・新用語を覚えさせたい | ❌ 適切でない。Continued Pretraining が必要 |
| 新しい事実・知識を追加したい | ❌ 適切でない。RAG（P6-P12）を使用 |
| タスクが基盤モデルと大きく異なる | P16 Evol-Instruct + SFT を検討 |

### 実装のポイント

**QLoRA（4bit量子化 + LoRA）訓練**

```python
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model
from trl import SFTTrainer, SFTConfig
import torch

# 1. 4bit量子化でモデルをロード（VRAM削減）
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
)
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3-8b-hf",
    quantization_config=bnb_config,
    device_map="auto",
)
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3-8b-hf")

# 2. LoRAアダプター設定（r=16で入力を16次元に圧縮）
peft_config = LoraConfig(
    r=16,               # ランク: 大きいほど表現力↑、訓練コスト↑
    lora_alpha=16,      # スケーリング値（通常rと同じか2倍）
    lora_dropout=0.05,
    bias="none",
    target_modules="all-linear",
    task_type="CAUSAL_LM",
)

# 3. 訓練データ形式（チャット形式で統一）
training_data = [
    {
        "messages": [
            {"role": "system", "content": "あなたはフードインフルエンサーです。"},
            {"role": "user", "content": "アイスクリームの風味を改善する方法を3つ提案してください。"},
            {"role": "assistant", "content": "1. ミントや柑橘の皮でベースを風味付けする\n2. ローストナッツやクッキーをミックスインする\n3. 仕上げにフレーク塩を振りかけて風味を強化する"}
        ]
    }
    # ... 数百件のサンプル
]

# 4. 訓練実行
sft_config = SFTConfig(
    output_dir="./my-adapter",
    num_train_epochs=3,
    learning_rate=2e-4,
    per_device_train_batch_size=4,
)
trainer = SFTTrainer(
    model=model,
    args=sft_config,
    train_dataset=training_data,
    peft_config=peft_config,
    processing_class=tokenizer,
)
trainer.train()
trainer.save_model()  # アダプター重みのみ保存
```

**推論（アダプター適用）**

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

# アダプターを含むモデルをロード
model = AutoModelForCausalLM.from_pretrained(
    "./my-adapter",
    device_map="auto",
    torch_dtype=torch.bfloat16,
)
tokenizer = AutoTokenizer.from_pretrained("./my-adapter")

# 通常の推論と同じ使い方
text = tokenizer.apply_chat_template(messages, return_tensors="pt")
output = model.generate(**text, max_new_tokens=200)
```

### 注意事項・トレードオフ

| 観点 | 内容 |
|------|------|
| **用途の明確な限界** | 新知識の注入・専門用語の学習には使えない。RAGや継続事前訓練（CPT）を使う |
| **壊滅的忘却リスク** | 過剰な学習率・エポック数は元のモデル能力を劣化させる。低LR（1e-5〜2e-4）・早期停止を使用 |
| **データ品質** | 少ないデータで訓練するため品質が品質に直結。ノイズの多いデータは性能を損なう |
| **クローズドモデルの制約** | GPT-4・Claude等は重みが非公開。マネージドファインチューニングAPIを使用するか、オープン重みモデルを選択 |
| **P16との違い** | Adapter Tuning（P15）は既存タスクの性能向上。全く新しいタスク教示にはEvol-Instruct（P16）+SFT |

---

## Pattern 16: Evol-Instruct

### 問題

基盤モデルは公開データでよく見られるタスクには対応できるが、企業固有タスクには対応できない：

- **エンタープライズタスクは訓練データに存在しない**：倉庫適性評価レポート、投資委員会メモ、社内調査裁定など、企業内部の業務は公開データにほぼ存在しない
- **プロバイダーは企業データにアクセスできない**：エンタープライズ契約でモデルプロバイダーはユーザーデータを訓練に使用しないため、モデルは自動的に改善しない
- **Few-shotでは不十分**：数百件のデモが必要だが、コンテキストウィンドウには入り切らない
- **人手でデータ作成するとコストが高い**：数百件の高品質な入出力ペアを人間が作るのは時間・費用がかかる

### 解決策

LLMを使って訓練データを自動生成し、そのデータで Instruction Tuning を行う（Evol-Instruct）：

1. **少数の初期例題から開始**（数件〜数十件）
2. **命令を進化させる**：LLMが既存の命令を複雑化・多様化・具体化
3. **回答を生成**：LLMが各命令への回答を生成
4. **品質評価・フィルタリング**：不適切・重複・低品質なペアを除去
5. **Instruction Tuning（SFT）**：フィルタリング済みデータセットでファインチューニング

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| 企業固有タスクをモデルに教えたい | Evol-Instruct + SFT が有効 |
| 初期例題が少数（数十件以下）しかない | Evol-Instructでデータを増幅 |
| 全く新しいタスク形式への対応が必要 | Evol-Instruct が有効 |
| 既存タスクの性能向上が目的 | P15 Adapter Tuning の方がシンプル |
| 新知識の追加が目的 | RAG（P6-P12）を使う |
| 高品質な既存データが豊富にある | 通常のSFTで十分（Evol-Instruct不要） |

### 実装のポイント

**命令の進化（Evolution）**

```python
import random
from pydantic_ai import Agent

EVOLUTION_STRATEGIES = [
    "元の命令をより具体的・詳細にしてください。追加の制約や要件を加えてください。",
    "元の命令を別の観点・アプローチから書き直してください。",
    "元の命令に現実的な文脈・シナリオを追加してください。",
    "元の命令をより複雑・難解にしてください。専門性を高めてください。",
]

def evolve_instruction(llm, instruction: str) -> str:
    """既存命令から新しい命令バリアントを生成"""
    strategy = random.choice(EVOLUTION_STRATEGIES)
    prompt = f"""以下の命令を変換してください。
変換方針: {strategy}

元の命令: {instruction}

変換後の命令のみ返してください（説明不要）:"""
    return llm.chat([{"role": "user", "content": prompt}])

def build_evolved_dataset(llm, seed_examples: list[dict], target_size: int = 500) -> list[dict]:
    """シード例題からEvol-Instructでデータセットを構築"""
    dataset = seed_examples.copy()
    while len(dataset) < target_size:
        # 既存から1件ランダム選択して進化
        seed = random.choice(dataset)
        evolved_instruction = evolve_instruction(llm, seed["instruction"])
        evolved_response = llm.chat([
            {"role": "system", "content": "あなたは専門的なアシスタントです。"},
            {"role": "user", "content": evolved_instruction}
        ])
        candidate = {"instruction": evolved_instruction, "response": evolved_response}
        if passes_quality_filter(candidate, dataset):
            dataset.append(candidate)
    return dataset
```

**品質フィルタリング**

```python
def passes_quality_filter(candidate: dict, existing_dataset: list[dict]) -> bool:
    """品質チェック: 重複・低品質・不適切なペアを除去"""
    instruction = candidate["instruction"]
    response = candidate["response"]

    # 1. 最低長チェック
    if len(instruction) < 20 or len(response) < 50:
        return False

    # 2. 重複チェック（ベクトル類似度で既存ペアと比較）
    instruction_embedding = embed(instruction)
    for existing in existing_dataset:
        similarity = cosine_similarity(instruction_embedding, embed(existing["instruction"]))
        if similarity > 0.95:  # 95%以上類似なら重複扱い
            return False

    # 3. 有害コンテンツチェック（オプション）
    if contains_harmful_content(instruction) or contains_harmful_content(response):
        return False

    return True
```

**Instruction Tuning（SFT）**

```python
from transformers import AutoModelForCausalLM, AutoTokenizer, Trainer, TrainingArguments

def format_for_sft(example: dict, tokenizer) -> dict:
    """入出力ペアをSFT用のフォーマットに変換"""
    formatted = tokenizer(
        f"### 命令:\n{example['instruction']}\n\n### 回答:\n{example['response']}" +
        tokenizer.eos_token
    )
    return formatted

# モデル・トークナイザーのロード
model_name = "meta-llama/Llama-3-8b-hf"
model = AutoModelForCausalLM.from_pretrained(model_name, torch_dtype=torch.bfloat16)
tokenizer = AutoTokenizer.from_pretrained(model_name)

# データセットの変換
tokenized_dataset = evolved_dataset.map(lambda ex: format_for_sft(ex, tokenizer))

# 訓練（低LRで壊滅的忘却を防ぐ）
training_args = TrainingArguments(
    output_dir="./instruction-tuned",
    learning_rate=1e-5,       # 低いLRで元の能力を保護
    num_train_epochs=3,
    per_device_train_batch_size=4,
    warmup_steps=100,
)
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=tokenized_dataset["train"],
    eval_dataset=tokenized_dataset["valid"],
)
trainer.train()
trainer.save_model()
```

**PeFT版（Unsloth + RSLoRA）— より少ないGPUメモリで実行可能**

```python
from unsloth import FastLanguageModel, UnslothTrainingArguments

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Meta-Llama-3.1-8B-bnb-4bit",
    max_seq_length=2048,
    load_in_4bit=True,
    full_finetuning=False,
)

# 命令チューニングに必要な追加モジュール（gate_proj, embed_tokens, lm_head）
model = FastLanguageModel.get_peft_model(
    model,
    r=16,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj",
                    "embed_tokens", "lm_head"],
    lora_alpha=32,
    use_rslora=True,  # ランク安定化LoRA
)

# 埋め込み層と線形層で異なる学習率を設定
training_args = UnslothTrainingArguments(
    output_dir="./instruction-tuned-peft",
    learning_rate=5e-5 * 2,            # 線形層の学習率
    embedding_learning_rate=5e-5 / 2,  # 埋め込み層は低めに
    num_train_epochs=10,
    gradient_accumulation_steps=64,
    per_device_train_batch_size=2,
)
```

### 注意事項・トレードオフ

| 観点 | 内容 |
|------|------|
| **壊滅的忘却** | 過剰な訓練は元の能力を損なう。低LR・早期停止・バリデーションセットによる監視が必須 |
| **生成データの品質** | 自動生成データには微妙な誤りが含まれる可能性。品質フィルタリングとサンプリングが重要 |
| **P15との使い分け** | Adapter Tuning（P15）は性能向上、Evol-Instruct（P16）はタスク教示。目的に応じて選択 |
| **RAGとの組み合わせ** | 新知識はRAGで提供、タスク実行能力はEvol-Instructで教示する2段構成が実用的 |
| **クローズドモデル制約** | GPT-4等は公式のファインチューニングAPIを使用（内部重みへのアクセス不可） |
| **データ多様性** | Evol-Instructの命令進化が多様でない場合、データセットに偏りが生じる。複数の進化戦略を併用する |
