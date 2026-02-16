# モデルドメイン適応

## 概要

**ドメイン適応（Domain Adaptation）**: 事前トレーニング済みモデルを特定タスクや独自コンテキストに対応させるため、精緻化するアプローチ。一般用途データで事前トレーニングされたLLMを、専門分野（法律・医療・科学等）に適用する際に有用。

### ドメイン適応のメリット

1. **性能向上**: 過小表現ドメイン（医療テキスト、法的文書等）でのLLM性能改善
2. **データ収集・ラベリングコスト削減**: 各ドメインで大量データ収集・ラベリング不要（特にデータが希少・高価な分野で有用）
3. **アクセシビリティ向上**: ドメイン専門知識なしでもLLMを幅広いユーザーが利用可能

---

## スクラッチからのトレーニング vs ファインチューニング vs プロンプトエンジニアリング

### 判断基準テーブル

| 要素 | スクラッチトレーニング | ファインチューニング | プロンプトエンジニアリング |
|------|---------------------|------------------|----------------------|
| **データ要件** | 大規模データセット必須 | 中規模ドメイン特化データ | 少量の例またはゼロ |
| **計算コスト** | 非常に高い（分散GPU/TPU必須） | 中程度 | 非常に低い |
| **モデル重み** | 完全に新規作成 | 既存重みを調整 | 変更なし |
| **専門知識** | モデルアーキテクチャ設計 | ファインチューニング技術 | プロンプト設計 |
| **適用ケース** | 独自アーキテクチャ必要時 | ドメイン特化・行動変更 | 知識追加・コンテキスト提供 |
| **重み変更** | すべて新規 | 一部調整 | なし |
| **費用対効果** | 低い（初期コスト膨大） | 中程度 | 高い（ランニングコストのみ） |

### スクラッチトレーニング vs ファインチューニング

**スクラッチトレーニング推奨**:
- 既存モデルでは要件を満たせない場合
- 独自アーキテクチャが必要な場合
- 学習目的でLLMの仕組みを理解したい場合

**ファインチューニング推奨**:
- 既存モデルが存在し、モデル重みへのアクセスがある場合
- ドメイン特化またはモデル行動変更が必要な場合
- リソースが限られている場合

---

## スクラッチからのLLMトレーニング（5ステップ）

### ステップ1: タスク選定

- モデル構築の目的決定
- 対象ドメイン・実行タスク（テキスト生成、要約、コード生成等）の決定
- 成功基準（パープレキシティ、精度、ドメイン特化評価メトリクス）の決定

### ステップ2: データ準備

**データ収集**:
- 高品質ソース: 書籍、記事、Webサイト、研究論文、コードリポジトリ
- ドメイン特化テキスト（法律・医療分野等）

**データクリーニング**:
- 広告・フォーマットアーティファクト等の不要要素除去
- スペルミス対応
- Hugging Faceライブラリ活用

**トークン化**:
- サブワードトークン化手法（BPE、SentencePiece）使用
- Hugging Faceの`AutoTokenizer`活用
- 大規模語彙対応、過剰なパラメータ回避

### ステップ3: モデルアーキテクチャ決定

**モデルサイズ選択**:
- データ、リソース、目標に応じてモデルサイズ選択
- 数億〜数兆パラメータまで幅広い構成

**アーキテクチャタイプ（3種類）**:

| タイプ | 説明 | 用途 |
|--------|------|------|
| **Encoder-Only（AutoEncoding）** | 入力テキストをコンテキストに基づき双方向エンコード | テキスト分類、NER |
| **Decoder-Only（AutoRegressive）** | 左から右へ順次生成 | テキスト生成、対話 |
| **Encoder-Decoder（Sequence-to-Sequence）** | エンコーダーで入力理解、デコーダーで出力生成 | 翻訳、要約 |

**カスタマイズ**:
- レイヤー数変更
- アテンションメカニズム変更
- 検索拡張メカニズム等の特殊コンポーネント追加

### ステップ4: トレーニングインフラ設定

**ハードウェア要件**:
- 複数GPU/TPU（16GB+メモリ推奨）
- 高速インターコネクト（NVLink等）

**分散トレーニングフレームワーク**:
- **PyTorch DDP（Distributed Data Parallel）**
- **TensorFlow `MultiWorkerMirroredStrategy`**
- **DeepSpeed**: 大規模モデル向けメモリ・計算最適化
- **Megatron-LM**: 大規模モデルトレーニング特化

**最適化**:
- **オプティマイザ**: Adam、AdamW推奨
- **混合精度トレーニング**: FP16でメモリ削減・高速化

### ステップ5: トレーニング実装

**ハイパーパラメータ設定**:
- バッチサイズ、ブロックサイズ、学習率、イテレーション数等
- シード値の設定

**実装例**: Andrej Karpathy氏の1時間ビデオチュートリアル（最もシンプルな実装）

---

## モデルアンサンブル手法

### 概要

**アンサンブル**: 複数モデルを組み合わせて単一モデルより良い結果を得る手法。各モデルが独自の強みを持ち、互いの弱点を補完。

### トレードオフ

**メリット**:
- 性能向上
- ロバストネス強化
- 解釈性向上

**デメリット**:
- 計算コスト増加（複数モデル並列実行）
- メモリ使用量・推論時間増加
- デプロイの複雑性増加

**最適化手法**:
- 量子化モデル使用
- 予測キャッシング
- 特定条件下でのみアンサンブル実行（モデル信頼度低い場合等）

---

## アンサンブル手法一覧

### 1. モデル平均化・ブレンディング（Model Averaging and Blending）

**説明**: 複数モデルの予測を平均化。事実ベース生成モデルと創造的生成モデルを組み合わせてバランスの取れた応答生成。

**実装**:
```python
def average_ensemble(models, input_text):
    avg_output = None
    for model in models:
        outputs = model(input_text)
        avg_output = outputs if avg_output is None else avg_output + outputs
    avg_output /= len(models)
    return avg_output
```

### 2. 重み付きアンサンブル（Weighted Ensembling）

**説明**: タスクごとのモデル性能に基づき異なる重みを付与。

**実装**:
```python
def weighted_ensemble(models, weights, input_text):
    weighted_output = torch.zeros_like(models[0](input_text))
    for model, weight in zip(models, weights):
        output = model(input_text)
        weighted_output += output * weight
    return weighted_output
```

### 3. スタッキングアンサンブル（Stacked Ensembling / Two-Stage Model）

**説明**: 複数モデルの出力をメタモデル（二次モデル）に入力。メタモデルがLLM出力パターンを学習し、効果的に組み合わせる。

**実装**:
```python
from sklearn.linear_model import LogisticRegression

def stacked_ensemble(models, meta_model, input_texts):
    model_outputs = []
    for model in models:
        outputs = [model(text).numpy() for text in input_texts]
        model_outputs.append(outputs)
    stacked_features = np.hstack(model_outputs)
    meta_model.fit(stacked_features, labels)
    return meta_model.predict(stacked_features)
```

### 4. 多様なアンサンブル（Diverse Ensembles for Robustness）

**説明**: Encoder-Decoderアーキテクチャ、Transformerベースモデル等の多様なモデル組み合わせ。エッジケース対応、包括的回答生成。

**効果**: 幻覚（Hallucination）をバランス調整、事実性と創造性の両立。

### 5. マルチステップデコーディング・投票メカニズム（Multi-Step Decoding and Voting Mechanisms）

**説明**: 次のトークン・フレーズについてモデルが投票。多数決、重み付き投票、ランク投票等。

**実装**:
```python
from collections import Counter

def voting_ensemble(models, input_text):
    all_predictions = []
    for model in models:
        output = model.generate(input_text)
        all_predictions.append(output)
    majority_vote = Counter(all_predictions).most_common(1)[0][0]
    return majority_vote
```

### 6. コンポーザビリティ（Composability）

**説明**: モデルまたはモデル部品を柔軟に組み合わせる能力。モデルをパイプラインで連鎖させ、前のモデルの出力を次のモデルの入力にする。

**実装**:
```python
def compose_pipeline(input_text, models):
    for model in models:
        input_text = model(input_text)
    return input_text

# 例: 翻訳 → 要約 → 感情分析
translated_text = translate_model("Translate this text to French.")
summarized_text = summarize_model(translated_text)
sentiment_result = sentiment_model(summarized_text)
```

**メリット**:
- **モジュール性**: 必要に応じてモデルをプラグイン・アウト
- **拡張性**: 個別モデル追加・交換容易
- **効率性**: 個別コンポーネント最適化可能

**課題**:
- エラー伝播（1コンポーネントのエラーが下流に波及）
- 各ステージで処理時間追加（リアルタイムアプリに影響）
- 複数モデル間での一貫性確保に調整・チューニング必要

### 7. ソフトアクター・クリティック（Soft Actor-Critic / SAC）

**説明**: 強化学習手法。探索と活用のバランス調整。エントロピー正則化により探索的行動を促進、多様な応答生成。

**コンポーネント**:
- **アクターネットワーク**: 行動（LLMでは応答・対話行動）を提案
- **クリティックネットワーク**: 提案行動の価値を評価（即時・将来報酬考慮）

**実装**:
```python
import torch
import torch.nn as nn
import torch.optim as optim

class Actor(nn.Module):
    def __init__(self):
        super(Actor, self).__init__()
        self.layer = nn.Linear(768, 768)
        self.output = nn.Softmax(dim=-1)

    def forward(self, x):
        return self.output(self.layer(x))

class Critic(nn.Module):
    def __init__(self):
        super(Critic, self).__init__()
        self.layer = nn.Linear(768, 1)

    def forward(self, x):
        return self.layer(x)

actor = Actor()
critic = Critic()
actor_optimizer = optim.Adam(actor.parameters(), lr=1e-4)
critic_optimizer = optim.Adam(critic.parameters(), lr=1e-3)

for episode in range(num_episodes):
    text_output = language_model(input_text)
    reward = compute_reward(text_output)

    critic_value = critic(text_output)
    critic_loss = torch.mean((critic_value - reward) ** 2)
    critic_optimizer.zero_grad()
    critic_loss.backward()
    critic_optimizer.step()

    actor_loss = -critic_value + entropy_coefficient * torch.mean(actor(text_output))
    actor_optimizer.zero_grad()
    actor_loss.backward()
    actor_optimizer.step()
```

**メリット**:
- エントロピーベース探索により応答多様性確保（創造的言語タスクに理想的）
- ライブフィードバックに基づき応答を時間とともに適応（チャットボット等）
- カスタム報酬関数で行動チューニング可能（多目的タスクに適合）

**課題**:
- 報酬関数の慎重な設計必要（複数目標のバランス調整困難）
- ハイパーパラメータに敏感（大幅なチューニング必要）
- 計算集約的（特に大規模モデル）

---

## プロンプトエンジニアリング

### 概要

**プロンプトエンジニアリング**: プロンプト・質問をカスタマイズして、より正確・洞察に富んだ応答を得る手法。プロンプト構造がモデルのタスク理解と性能に大きく影響。

---

## プロンプトエンジニアリング技術

### 1. ワンショットプロンプティング（One-Shot Prompting）

**説明**: 1つの例とその出力を提供。シンプルで明確な例により期待する回答・行動を示す。

**適用ケース**: シンプルで明確なタスク

**例**:
```
Prompt: Translate the following English sentence to French: 'Hello, how are you?'
French translation: 'Bonjour, comment ça va ?'

Prompt: Translate the following English sentence to French: 'Good morning, I hope you're doing well.'
```

### 2. フューショットプロンプティング（Few-Shot Prompting）

**説明**: 複数例を提供。モデルが望ましい出力のパターンを理解。

**適用ケース**: パターン識別、特定スタイル・フォーマットでの応答生成

**例**:
```
Prompt: Here's how to create a word problem based on the following math equation:
1. 3 + 5 = 8
   'If you have 3 apples and pick 5 more, how many apples do you have in total?'
2. 10 – 4 = 6
   'A store had 10 apples, but 4 were sold. How many apples are left in the store?'

Prompt: Create a word problem based on the following math equation: 7 + 2 = 9.
```

### 3. チェーン・オブ・ソート プロンプティング（Chain-of-Thought Prompting）

**説明**: モデルに推論プロセスを段階的に分解させる。論理的推論、複数ステップ、問題解決タスクに有効。

**適用ケース**: 複雑な論理的推論、意思決定、数学的推論

**例**:
```
Prompt: Let's solve this step-by-step:
What is 8 × 6?
Step 1: First, break it into smaller numbers: 8 × (5 + 1).
Step 2: Now calculate: 8 × 5 = 40.
Step 3: Then calculate 8 × 1 = 8.
Step 4: Add the results: 40 + 8 = 48.
So, 8 × 6 = 48.

Prompt: Let's solve this step-by-step: What is 12 × 7?
```

### 4. ハイブリッドアプローチ

**説明**: 複数プロンプティング技術を組み合わせ。Few-Shotでコンテキスト提供 → Chain-of-Thoughtで推論ガイド。

**例**:
```
Prompt: Here are some examples of how to generate creative descriptions for objects:
1. 'A tall oak tree with thick branches reaching out, casting a large shadow on the grass.'
2. 'A small, round pebble with smooth edges and a soft, pale color.'
Now, describe this object: 'A rusty old bicycle.' Let's break it down step-by-step.
```

---

## RAG（Retrieval-Augmented Generation）

### 概要

**RAG**: 事前トレーニング済み言語モデルと外部知識ソースを組み合わせる最も強力な技術の1つ。情報検索ベースの手法により生成モデルの複雑なクエリ対応能力や正確性・事実性向上。

### RAGの動作（2ステージ）

**ステージ1: 検索（Retrieval）**
- 検索システムが知識ベース・検索エンジン・データベースから関連ドキュメント・テキストスニペットを取得

**ステージ2: 生成（Generation）**
- LLMが入力クエリと取得したテキストスニペットに基づき出力生成

### RAGの利点

- 複雑な質問対応
- 応答の事実確認
- 幅広い外部情報への動的参照

### 実装例

```python
from transformers import RagTokenizer, RagRetriever, RagSequenceForGeneration

tokenizer = RagTokenizer.from_pretrained("facebook/rag-token-nq")
retriever = RagRetriever.from_pretrained("facebook/rag-token-nq")
model = RagSequenceForGeneration.from_pretrained("facebook/rag-token-nq")

question = "What is the capital of France?"
inputs = tokenizer(question, return_tensors="pt")
retrieved_docs = retriever.retrieve(question, return_tensors="pt")

outputs = model.generate(
    input_ids=inputs['input_ids'],
    context_input_ids=retrieved_docs['context_input_ids'],
    context_attention_mask=retrieved_docs['context_attention_mask']
)

answer = tokenizer.decode(outputs[0], skip_special_tokens=True)
print(answer)
```

---

## Semantic Kernel

### 概要

**Semantic Kernel**: LLMを動的知識・推論・状態追跡が必要なアプリケーションに統合するためのフレームワーク。複雑でモジュラーなAIシステム構築に有用。

### 主な機能

- **モジュール性**: 埋め込み・プロンプトテンプレート・カスタム関数を容易に組み合わせ
- **非同期処理**: 長時間実行タスク・外部サービス連携に対応
- **セマンティックメモリ**: 過去のやり取り・取得情報を記憶・検索し、一貫性向上
- **外部関数・API統合**: モデル推論とリアルワールドデータを容易に結合

### 実装例

```python
from semantic_kernel import Kernel
from semantic_kernel.ai.openai import OpenAITextCompletion
from semantic_kernel.memory import MemoryStore
from semantic_kernel.plugins import AzureTextPlugin

kernel = Kernel()
kernel.add_ai("openai", OpenAITextCompletion(api_key="your-openai-api-key"))

memory = MemoryStore()
kernel.add_memory("semantic_memory", memory)

def chain_of_thought(input_text: str) -> str:
    response = kernel.run_ai("openai", "text-davinci-003", input_text)
    return f"Thought Process: {response}"

kernel.add_function("chain_of_thought", chain_of_thought)

user_input = "How does quantum computing work?"
reasoned_output = kernel.invoke("chain_of_thought", user_input)
print("Reasoning Output:", reasoned_output)

kernel.add_plugin("external_api", AzureTextPlugin(api_key="your-azure-api-key"))
external_output = kernel.invoke("external_api", "fetch_knowledge", user_input)
print("External Output:", external_output)
```

---

## ファインチューニング

### 概要

**ファインチューニング**: 既にトレーニング済みのモデルを新しいタスクに少ないリソースで適応させる手法。モデルの重みにアクセス必要（モデルチェックポイント経由、またはOpenAIのファインチューニングAPI経由）。

### ファインチューニング vs プロンプトエンジニアリングの選択

**コスト比較:**

| 項目 | ファインチューニング | プロンプトエンジニアリング |
|------|------------------|----------------------|
| 初期コスト | 高額（例: GPT-4o $25,000/100万トークン） | 低い |
| ランニングコスト | 変わらず | プロンプトサイズに比例増加 |
| 費用形態 | 前払い | 従量課金 |
| 投資回収期間 | 長期（ただしLLMライフサイクル短い場合、回収困難） | 短期 |

**コスト以外の判断基準:**

| 目的 | 推奨手法 |
|------|---------|
| **知識追加** | プロンプトエンジニアリング / RAG |
| **行動変更** | ファインチューニング |

**例: 出力フォーマット変更**
- 必要な知識は既にある
- XML形式での出力が必要（通常のチャット出力ではない）
- **推奨**: ファインチューニング（プロンプトエンジニアリングより遥かに高性能）

**注意: ファインチューニングの副作用**
- モデル行動変更により、以前できたことができなくなる可能性
- **例**: 技術的な製品チャットデータでファインチューニング → 「500語のブログ記事生成」依頼に「忙しい」と回答
- **代替案**: RAGソリューション（製品チャットデータを検索し、旧モデルにfeature X説明プロンプト作成）

---

## ファインチューニング手法一覧

### 1. アダプティブファインチューニング（Adaptive Fine-Tuning）

**説明**: モデルのパラメータを更新し、特定データセット・タスクをより適切に処理できるようにする。

**適用ケース**: 医療テキスト、法律用語、カスタマーサービス対話等のドメイン特化

**例**:
```
Question: What are the symptoms of a heart attack?
Answer: Symptoms of a heart attack include chest pain, shortness of breath, nausea, and cold sweats.
```

### 2. アダプター（Adapters）

**説明**: モデル全体を再トレーニングせず、小さなタスク特化モジュールを導入・トレーニング。元のモデルパラメータは凍結。

**タイプ**:
- **シングルアダプター**: 1つのタスク特化アダプター
- **パラレルアダプター**: 複数タスク用に複数アダプターを並列トレーニング
- **スケールドパラレルアダプター**: より複雑なタスク向けに異なるスケールで複数アダプタートレーニング

**例**: テキスト要約と感情分析用に2つのパラレルアダプター

### 3. ビヘイビアルファインチューニング（Behavioral Fine-Tuning）

**説明**: モデルの行動を特定の期待に合わせて調整（倫理的・丁寧・ユーザーフレンドリーな出力生成）。

**適用ケース**: カスタマーサービスチャットボット、ヘルスケアアシスタント等の直接的ユーザー対話

**例**:
```
User: I'm feeling really down today.
Model (after behavioral fine-tuning): I'm so sorry to hear that. It's important to talk to someone when you're feeling this way. Would you like to share more?
```

### 4. プレフィックスチューニング（Prefix Tuning）

**説明**: モデル構造・コア重みを大幅に変更せず、小さなチューニング可能部分（プレフィックス）のみ調整。プレフィックスは入力データの前に付加される小さな入力シーケンス。

**例**:
```
Prefix: Write a romantic poem in the style of Shakespeare.
Input: 'The evening sky is painted in hues of orange.'
```

### 5. パラメータ効率的ファインチューニング（PEFT）

**説明**: 最小リソースで大規模モデルをファインチューニング。モデル全体ではなく、低ランク部分のみ重み変更。

**技術**:
- **LoRA（Low-Rank Adaptation）**: 重み更新の低ランク近似導入、ファインチューニングパラメータ数削減
- **qLoRA（Quantized LoRA）**: LoRAに量子化を組み込み、ストレージ要件さらに削減

**適用ケース**: リソース制約環境での大規模LLMデプロイ

### 6. 指示チューニング・RLHF（Instruction Tuning and Reinforcement Learning from Human Feedback）

**指示チューニング**:
- モデルが明示的指示をより正確・信頼性高く従うようにファインチューニング
- 例:
  ```
  Answer the following question directly: What is the capital of France?
  The capital of France is Paris.
  ```

**RLHF（Reinforcement Learning from Human Feedback）**:
- モデルが出力に対して人間からフィードバックを受け、時間とともに改善
- 例:
  ```
  How do I change the oil in my car?
  Changing the oil in your car involves draining the old oil, replacing the oil filter, and refilling with fresh oil. Would you like a step-by-step guide?
  ```

**適用ケース**: 仮想アシスタント、対話型システム、ユーザー期待との整合性確保

---

## Mixture of Experts（MoE）

### 概要

**MoE**: アーキテクチャモジュール性と条件付き計算による最適化。多数の「エキスパート」（小さな専門サブネットワーク）を1つの大規模モデル内に配置し、ゲーティングシステムが入力に基づき少数のエキスパートのみを選択・活性化。

### MoEの動作原理

**ゲーティングネットワーク**:
- 各トークンの隠れ状態を使用して、すべてのエキスパートのスコア生成
- **GShard**: Softmax関数でスコアを確率分布に変換、トップ2エキスパート選択、重み付け
- **Switch Transformer**: ハードルーティング（単一エキスパート選択）により通信オーバーヘッド削減

### MoEの課題と対策

**ロードバランシング（Load Balancing）**:
- **問題**: 制約なしでは、ゲーティングが少数の人気エキスパートにトークンを集中させる → エキスパートコラプス
- **対策**: ロードバランシング損失項をトレーニング目標に追加、ゲーティングネットワークにトークンを均等に分散させる

**エキスパート容量（Expert Capacity）**:
- 各エキスパートはメモリ制約内でバッチごとに限られた数のトークンのみ処理可能
- 過剰ルーティングされたトークンは削除または再ルーティング

**トレーニング安定性**:
- ゲーティング重みの慎重な初期化
- ゲーティング出力へのドロップアウト適用
- 勾配クリッピング

### MoE vs ファインチューニング

- **MoE**: 構造変更によるスケーラビリティ・適応性向上
- **ファインチューニング**: パラメータ更新による性能向上
- **関係**: 相互補完（どちらか一方の代替ではない）

---

## リソース制約デバイス向けモデル最適化

### 圧縮技術

**1. プロンプトキャッシング（Prompt Caching）**:
- 頻繁に発生するプロンプトの計算済み応答を保存
- 冗長計算回避、推論高速化、高トラフィックシステムのコスト削減

**2. Key-Valueキャッシング（KV Caching）**:
- TransformerベースLLMのアテンション関連計算をキャッシュ
- Key（K）・Value（V）テンソルを保存し、後続トークンで再利用
- 自己回帰生成（GPTスタイルモデル）の高速化、長文生成のレイテンシ改善

**3. 量子化（Quantization）**:
- モデル重みの精度削減（32bit浮動小数点 → 8bit / 4bit）
- メモリ要件削減、推論高速化、精度大幅低下なし

**量子化タイプ**:
- **静的量子化**: 実行前に重み・アクティベーション量子化
- **動的量子化**: 実行時にアクティベーション量子化
- **QAT（Quantization-Aware Training）**: 量子化効果を考慮してモデルトレーニング、量子化後の精度向上

**4. プルーニング（Pruning）**:
- 重要度の低い重み・ニューロン・レイヤー全体を削除
- **構造化プルーニング**: 体系的にコンポーネント削除（レイヤー内のニューロン等）
- **非構造化プルーニング**: 重要度に基づき個別重み削除

**5. 蒸留（Distillation）**:
- 小さな「学生」モデルが大きな「教師」モデルの振る舞いを模倣するようトレーニング
- 学生モデルは教師の出力（ロジット・中間層表現）を模倣

---

## 効果的なLLM開発のレッスン

### 1. スケーリング則（Scaling Law）

**説明**: データ・モデルサイズ・計算量の増加に伴いモデル性能がどう改善するかを記述。

**重要ポイント**:
- モデルサイズとトレーニングデータを両方倍増 → 片方のみ倍増より良い性能
- データを適切にスケールしないと、モデルがアンダートレーニング・過パラメータ化

**実装例**:
```python
import matplotlib.pyplot as plt
import numpy as np

model_sizes = np.logspace(1, 4, 100)
performance = np.log(model_sizes) / np.log(10)

plt.plot(model_sizes, performance, label="Scaling Law")
plt.xscale("log")
plt.xlabel("Model Size (log scale)")
plt.ylabel("Performance")
plt.title("Scaling Law for LLMs")
plt.legend()
plt.show()
```

### 2. Chinchillaモデル（Chinchilla Models）

**説明**: より大規模なモデル構築より、モデルサイズを固定してより多くのデータでトレーニングすることを優先。固定計算バジェットで、より多くデータでトレーニングされた小規模モデルが、限定データでトレーニングされた大規模モデルを上回る。

**実装例**:
```python
model_size = "medium"
data_multiplier = 4

model = load_model(size=model_size)
dataset = augment_dataset(original_dataset, multiplier=data_multiplier)

train_model(model, dataset)
evaluate_model(model)
```

### 3. 学習率最適化（Learning-Rate Optimization）

**重要性**: 最適な学習率により、より高速な収束、勾配消失・振動回避。

**戦略**:
- **ウォームアップ**: トレーニング開始時に学習率を徐々に増加、収束安定化
- **コサインアニーリング**: 時間とともに学習率を滑らかに減少、最終収束改善

**実装例**:
```python
from torch.optim.lr_scheduler import CosineAnnealingLR
import torch

model = torch.nn.Linear(10, 2)
optimizer = torch.optim.Adam(model.parameters(), lr=0.1)
scheduler = CosineAnnealingLR(optimizer, T_max=50)

for epoch in range(100):
    optimizer.step()
    scheduler.step()
    print(f"Epoch {epoch}, Learning Rate: {scheduler.get_last_lr()}")
```

### 4. オーバートレーニング回避（Avoiding Overtraining）

**オーバートレーニングの兆候**:
- 検証損失増加、トレーニング損失減少
- テストデータでの予測が過剰に自信満々だが不正確

**対策**:

**早期停止（Early Stopping）**:
```python
from pytorch_lightning.callbacks import EarlyStopping

early_stopping = EarlyStopping(monitor="val_loss", patience=3, verbose=True)
trainer = Trainer(callbacks=[early_stopping])
trainer.fit(model, train_dataloader, val_dataloader)
```

**正則化（Regularization）**:
- モデル損失関数にペナルティ項を追加し、トレーニングデータとの過度に複雑な関係学習を抑制

### 5. 投機的サンプリング（Speculative Sampling）

**説明**: 自己回帰デコーディングの推論高速化手法。小さく高速なモデルで複数トークン候補を予測 → 大規模モデルで検証。

**適用ケース**: 低レイテンシ生成が必要なアプリケーション（リアルタイム対話エージェント等）

---

## AskUserQuestion指針

### ファインチューニング vs プロンプトエンジニアリング選択時

**質問例:**
```markdown
モデル適応手法を選択するため、以下を確認します：

1. モデル重みへのアクセス:
   - [ ] あり（ファインチューニング可能）
   - [ ] なし（プロンプトエンジニアリングのみ）

2. 目的:
   - [ ] 知識追加・コンテキスト提供
   - [ ] 行動変更・出力フォーマット変更

3. 予算制約:
   - 初期費用: ___
   - ランニング費用許容範囲: ___
   - モデル使用期間: ___年

4. 性能要件:
   - 必要な精度: ___
   - レイテンシ要件: ___ms
```

### ファインチューニング手法選択時

**質問例:**
```markdown
ファインチューニング手法を選定するため、以下を教えてください：

1. データ量:
   - ドメイン特化データ: ___（トークン数・例数）
   - データ品質: [ ] 高品質  [ ] 中品質  [ ] 低品質

2. 計算リソース:
   - 利用可能GPU/TPU: ___
   - メモリ: ___GB
   - 予算制約: ___

3. 目的:
   - [ ] ドメイン知識追加（Adaptive Fine-Tuning）
   - [ ] 行動調整（Behavioral Fine-Tuning）
   - [ ] 特定タスク対応（Adapters）
   - [ ] リソース効率重視（PEFT / LoRA）
   - [ ] 指示追従改善（Instruction Tuning / RLHF）

4. 複数タスク対応:
   - [ ] 単一タスク
   - [ ] 複数タスク（Parallel Adapters検討）
```

### リソース制約デバイス向け最適化時

**質問例:**
```markdown
リソース制約デバイス向けにモデルを最適化するため、以下を確認します：

1. ターゲットデバイス:
   - デバイスタイプ: ___（モバイル、エッジデバイス等）
   - メモリ制約: ___MB/GB
   - 計算能力: ___

2. 許容可能なトレードオフ:
   - 精度低下許容範囲: ___%
   - レイテンシ要件: ___ms
   - モデルサイズ上限: ___MB

3. 最適化手法:
   - [ ] 量子化（Quantization）
   - [ ] プルーニング（Pruning）
   - [ ] 蒸留（Distillation）
   - [ ] KVキャッシング
   - [ ] プロンプトキャッシング

4. デプロイ環境:
   - [ ] オフライン推論
   - [ ] オンライン推論（リアルタイム要件）
```