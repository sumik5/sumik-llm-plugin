# デプロイ最適化パターン（P24–P28）

> フロンティアLLMの高コスト・高レイテンシ問題に対処する5つのパターン。SLMへの縮小、キャッシュ戦略、推論高速化、劣化監視、セッション横断記憶をカバーする。

## 目次

- [Pattern 24: Small Language Model](#pattern-24-small-language-model)
- [Pattern 25: Prompt Caching](#pattern-25-prompt-caching)
- [Pattern 26: Inference Optimization](#pattern-26-inference-optimization)
- [Pattern 27: Degradation Testing](#pattern-27-degradation-testing)
- [Pattern 28: Long-Term Memory](#pattern-28-long-term-memory)

---

## Pattern 24: Small Language Model

### 問題

フロンティアLLMを自前ハードウェアで稼働させるには、最先端のGPUと大容量メモリが必要となり、クラウドコスト・調達難易度・レイテンシのすべてで課題が生じる。APIを経由する場合でも、コスト問題は解消されない。一方、単純に小さいモデルに切り替えると品質が大幅に低下する。

### 解決策

大型モデルから小型モデルへの移行手段として、以下3つのアプローチを組み合わせる。品質を犠牲にせずコストとレイテンシを改善することが目標となる。

1. **蒸留（Distillation）**: 大型「教師」モデルの知識を小型「生徒」モデルに転移
2. **量子化（Quantization）**: モデルパラメータの精度を落とし、メモリ消費を削減
3. **投機的デコード（Speculative Decoding）**: 小型モデルがトークン候補を生成し、大型モデルが検証

### 適用判断基準

| 条件 | 推奨アプローチ |
|------|-------------|
| アプリケーションのスコープが狭い（特定ドメイン限定） | 蒸留（Distillation） |
| 既存モデルをそのまま使いたいが精度低下を最小限に | 量子化（4ビットまたは8ビット整数） |
| 品質を維持しながらレイテンシだけ削減したい | 投機的デコード |
| コストより精度優先 | 完全精度のフロンティアモデルを継続使用 |
| コストとレイテンシ両方を削減したい | 蒸留 + 量子化を組み合わせる |

### 実装のポイント

#### 蒸留：教師-生徒学習

```python
import torch
import torch.nn.functional as F

class DistillationTrainer:
    def __init__(self, teacher_model, student_model, temperature=4.0, alpha=0.5):
        self.teacher_model = teacher_model
        self.student_model = student_model
        self.temperature = temperature
        self.alpha = alpha  # 0=タスク損失のみ、1=蒸留損失のみ

    def compute_loss(self, inputs):
        # 教師モデルは推論のみ（重み更新不要）
        with torch.no_grad():
            teacher_logits = self.teacher_model(**inputs).logits

        student_outputs = self.student_model(**inputs)
        student_logits = student_outputs.logits
        task_loss = student_outputs.loss

        # 温度スケーリングで確率分布を平準化（ダーク知識の保持）
        student_scaled = student_logits / self.temperature
        teacher_scaled = teacher_logits / self.temperature

        # KLダイバージェンスで生徒を教師に近づける
        distillation_loss = F.kl_div(
            torch.log_softmax(student_scaled, dim=-1),
            torch.softmax(teacher_scaled, dim=-1),
            reduction='batchmean'
        ) * (self.temperature ** 2)

        # タスク損失と蒸留損失のブレンド
        return (1 - self.alpha) * task_loss + self.alpha * distillation_loss
```

#### 量子化：4ビット量子化

```python
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
import torch

quantization_config = BitsAndBytesConfig(
    load_in_4bit=True,                          # FP32から4ビット整数へ（8分の1のメモリ）
    bnb_4bit_compute_dtype=torch.float16,       # 計算はFP16（精度と速度のバランス）
    bnb_4bit_quant_type="nf4",                  # NF4形式：LLMに最適化
    bnb_4bit_use_double_quant=True,             # 二重量子化でさらにメモリ削減
)

model = AutoModelForCausalLM.from_pretrained(
    "google/gemma-3-27b-it",
    quantization_config=quantization_config,
    device_map="auto",
    torch_dtype=torch.float16,
)
```

#### 投機的デコード（vLLMを使用）

```python
from vllm import LLM, SamplingParams

# 小型モデルがトークン候補を生成し、大型モデルが検証
llm = LLM(
    model="google/gemma-2-9b-it",           # ターゲット（大型・高精度）
    speculative_model="google/gemma-2-2b-it",  # ドラフト（小型・高速）
    num_speculative_tokens=5,               # 一度に投機するトークン数
    tensor_parallel_size=1,
)

sampling_params = SamplingParams(temperature=0.8, top_p=0.95)
outputs = llm.generate(["生成したいプロンプト"], sampling_params)
```

### 注意事項・トレードオフ

| 側面 | 蒸留 | 量子化 | 投機的デコード |
|------|------|--------|--------------|
| **メリット** | ドメイン精度を維持しながら大幅な縮小が可能 | 既存モデルをそのまま活用、導入容易 | 品質劣化なしでレイテンシを15-30%削減 |
| **デメリット** | 訓練データとGPUが必要、汎化性を失う | アーキテクチャによって量子化感度が異なる | 2モデルの管理コスト、SLMが間違えると効果が薄い |
| **代替パターン** | Adapter Tuning（P15）でファインチューニング | Prompt Caching（P25）でコスト削減 | Continuous Batching（P26）でスループット向上 |

---

## Pattern 25: Prompt Caching

### 問題

本番LLMアプリケーションでは、全リクエストの大部分が同じ質問の繰り返しになる傾向がある（問い合わせの30〜40%が共通パターン）。同一プロンプトを毎回再計算するのは、GPU利用効率・ユーザー待ち時間・インフラコストのすべてで非効率となる。

### 解決策

LLMレスポンスをキャッシュし、同一または類似リクエストに対して再利用する。キャッシュの配置場所（クライアント側/サーバー側）と類似度の定義（完全一致/意味的類似）で複数の実装オプションが存在する。

### 適用判断基準

| 条件 | 推奨アプローチ |
|------|-------------|
| 同一プロンプトの繰り返しが多い（FAQ等） | クライアント側レスポンスキャッシュ |
| 類似プロンプト（表現違い）が多い | 意味的キャッシュ（Semantic Cache） |
| システムプロンプトが長く共通 | サーバー側プレフィックスキャッシュ（プロバイダー任せ） |
| 動画・文書を繰り返し参照 | コンテキストキャッシュ（Gemini等） |
| マルチテナント環境 | ユーザーIDをキャッシュキーに含める |

### 実装のポイント

#### クライアント側キャッシュ（完全一致）

```python
import hashlib
import json
from pathlib import Path
from typing import Optional, Dict, Any

class PromptCache:
    def __init__(self, cache_dir: str = ".prompt_cache"):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(exist_ok=True)

    def _cache_key(self, prompt: str) -> str:
        return hashlib.md5(prompt.encode()).hexdigest()

    def get(self, prompt: str) -> Optional[str]:
        path = self.cache_dir / f"{self._cache_key(prompt)}.json"
        if path.exists():
            return json.loads(path.read_text())["content"]
        return None

    def set(self, prompt: str, response: str) -> None:
        path = self.cache_dir / f"{self._cache_key(prompt)}.json"
        path.write_text(json.dumps({"content": response}))

    def get_or_generate(self, prompt: str, llm_fn) -> str:
        cached = self.get(prompt)
        if cached:
            return cached
        response = llm_fn(prompt)
        self.set(prompt, response)
        return response
```

#### 意味的キャッシュ（類似バリアントを生成して登録）

```python
def build_semantic_cache(prompt: str, response: str, llm, cache: PromptCache):
    """元プロンプトに加え、意味的に同等なバリアントも一緒にキャッシュ登録する"""
    variants_prompt = f"""
    以下のプロンプトと意味的に同等なバリアントを5個生成してください。
    JSON配列で返してください。

    プロンプト: {prompt}
    """
    variants = json.loads(llm(variants_prompt))

    # 元プロンプトとすべてのバリアントに同じレスポンスを登録
    for p in [prompt] + variants:
        cache.set(p, response)
```

### 注意事項・トレードオフ

- **クライアント側**: 完全なレイテンシ削減とコスト削減が可能だが、完全一致のみ有効（意味的キャッシュで補完可）
- **サーバー側プレフィックス**: TTFT（最初のトークン生成時間）を大幅改善するがフルレスポンスは生成される
- **意味的キャッシュ**: ヒット率は向上するが、類似クエリに同一レスポンスを返すリスク（ニュアンスの損失）
- **マルチテナント注意**: ユーザーIDをキャッシュキーに含めないと情報漏洩の可能性

---

## Pattern 26: Inference Optimization

### 問題

機密性の高い医療・金融・法務データを扱うアプリケーションでは、サードパーティAPIを避けてLLMを自前ホスティングすることが多い。しかし自前ホスティングでは、変動長プロンプトへの対応・GPU利用率の最大化・レイテンシ要件の充足という3つの課題が生じる。

### 解決策

自前ホスティングのLLM推論を最適化する3つの相補的な手法を組み合わせる。

1. **継続的バッチ処理（Continuous Batching）**: 完了したリクエストの空きスロットに即座に新リクエストを挿入
2. **投機的デコード（Speculative Decoding）**: ドラフトモデルが候補トークンを先行生成し、大型モデルが検証
3. **プロンプト圧縮（Prompt Compression）**: 送信前にプロンプトを短縮して計算量を削減

### 適用判断基準

| 条件 | 推奨手法 |
|------|---------|
| リクエスト量が多く変動長プロンプトが多い | 継続的バッチ処理 |
| レイテンシを削減したいが品質は維持したい | 投機的デコード |
| コンテキストウィンドウが大きくGPUメモリが逼迫 | プロンプト圧縮 |
| マネージドAPIを使用中 | これらの最適化は不要（プロバイダー側で対応） |

### 実装のポイント

#### 継続的バッチ処理（vLLM）

```python
from vllm import LLM, SamplingParams

llm = LLM(model="meta-llama/Llama-3.1-8B-Instruct")
sampling_params = SamplingParams(temperature=0.7, max_tokens=512)

# ❌ 非効率：個別リクエスト（継続的バッチが効かない）
for prompt in prompts:
    output = llm.generate([prompt], sampling_params)

# ✅ 効率的：一括投入（サーバーが最適スロット割り当て）
outputs = llm.generate(prompts, sampling_params)
# → 約20倍のスループット改善例あり
```

#### ハードプロンプト圧縮

```python
def compress_prompt_hard(context: str, llm) -> str:
    """
    可読性を維持しながらプロンプトを圧縮する。
    冗長な表現の除去・略語化・キーワード化を行う。
    """
    compression_prompt = f"""
    以下のテキストを情報損失最小で圧縮してください。
    冗長な表現を省き、キーワード形式に変換してください。

    テキスト:
    {context}

    圧縮テキスト:
    """
    compressed = llm(compression_prompt)

    # 圧縮前後の情報保持率を検証
    verification_prompt = f"""
    以下の圧縮テキストから元のテキストを復元してください:
    {compressed}
    """
    reconstructed = llm(verification_prompt)
    # 元テキストとの意味的類似度を評価して品質を確認
    return compressed
```

### 注意事項・トレードオフ

- **継続的バッチ処理**: vLLM・SGLangでデフォルト有効。コンテキスト長の上限とGPUメモリの制約は残る
- **投機的デコード**: `num_speculative_tokens`の設定が重要。多すぎると大型モデルの再計算が増えて逆効果
- **ハード圧縮**: 一般に情報損失が軽微で人間可読性を維持。ソフト圧縮はモデル固有で移植性がない

---

## Pattern 27: Degradation Testing

### 問題

LLMアプリケーションでは、従来のサーバー監視（エラー率・レスポンスコード）では不十分となる。「サービスが止まるポイント」だけでなく「どのように品質が劣化し始めるか」を把握することが、運用上の重大な課題となる。

### 解決策

LLM推論サービス特有の4つのコアメトリクスを継続的に監視し、スケーラビリティ・ストレス・負荷テストで劣化ポイントを特定する。

### 適用判断基準

| 状況 | 注目すべきメトリクス |
|------|-------------------|
| ストリーミングチャットアプリで体感が悪い | TTFT（最初のトークン生成時間）を最優先 |
| バッチ処理・非インタラクティブ用途 | EERL（エンドツーエンドレイテンシ）とTPS |
| トラフィックが増加傾向 | RPS（秒あたりリクエスト数）の飽和点を特定 |
| ピーク時のパフォーマンス計画 | 負荷テスト（Load Testing） |
| 障害復旧計画が必要 | ストレステスト（Stress Analysis） |

### 実装のポイント

#### 4つのコアメトリクス

```python
import time
from dataclasses import dataclass
from typing import Iterator

@dataclass
class LLMPerformanceMetrics:
    """LLM推論の主要パフォーマンス指標"""
    ttft_ms: float        # Time to First Token: 最初のトークンまでの時間
    eerl_ms: float        # End-to-End Request Latency: 完全なレスポンスまでの時間
    output_tokens: int    # 生成されたトークン数

    @property
    def tps(self) -> float:
        """Tokens Per Second: トークン生成スループット"""
        return self.output_tokens / (self.eerl_ms / 1000)

def measure_streaming_request(prompt: str, llm_stream_fn) -> LLMPerformanceMetrics:
    """ストリーミングレスポンスでメトリクスを計測する"""
    start = time.time()
    ttft = None
    token_count = 0

    for token in llm_stream_fn(prompt):  # type: Iterator[str]
        if ttft is None:
            ttft = (time.time() - start) * 1000  # TTFTをミリ秒で記録
        token_count += 1

    eerl = (time.time() - start) * 1000
    return LLMPerformanceMetrics(
        ttft_ms=ttft or eerl,
        eerl_ms=eerl,
        output_tokens=token_count,
    )
```

#### TTFTが高い場合の対処法

```python
# TTFT改善の4つのアプローチ
# 1. プロンプト圧縮（P26）でプロンプト長を削減
# 2. Prompt Caching（P25）でシステムプロンプトのプレフィックスをキャッシュ
# 3. コンテキストウィンドウの上限を小さくする
# 4. 静的テキスト（システムプロンプト）をプロンプトの先頭に、動的テキスト（RAG結果）を末尾に配置

# プロンプト構造の最適例（KVキャッシュ効率化）
def build_optimized_prompt(system_prompt: str, rag_results: list[str], user_query: str) -> str:
    # 静的部分を先頭に置くことでKVキャッシュの再利用率を最大化
    return f"{system_prompt}\n\n{''.join(rag_results)}\n\nユーザー: {user_query}"
```

#### EERLが長い場合の対処法

```python
import asyncio

# 独立したサブタスクを並列化してEERLを削減
async def parallel_llm_calls(task1_prompt: str, task2_prompt: str, llm_async_fn) -> tuple:
    """依存関係のないLLM呼び出しを並列実行する"""
    result1, result2 = await asyncio.gather(
        llm_async_fn(task1_prompt),
        llm_async_fn(task2_prompt),
    )
    return result1, result2
```

### 注意事項・トレードオフ

| メトリクス | 主な制約要因 | 改善アクション |
|-----------|------------|-------------|
| TTFT | プロンプト長・KVキャッシュ速度 | P25/P26（キャッシュ・圧縮）、GPU増設 |
| EERL | レスポンス長・並列処理 | 出力トークン削減、タスク並列化 |
| TPS | GPU性能・モデルサイズ | P24（SLM）、スロットリング |
| RPS | 飽和点を超えると急落 | スケールアウト、小型モデルへのルーティング |

---

## Pattern 28: Long-Term Memory

### 問題

LLMは各プロンプトを独立したステートレスな処理として扱う。チャットボット・コーディングアシスタント・ワークフローエージェントはすべて、セッションをまたいだコンテキストの維持が必要となるが、全履歴をプロンプトに追加するとトランスフォーマーアーキテクチャの二次コストが爆発する。

### 解決策

4種類のメモリを用途に応じて実装し、コンテキストウィンドウをあふれさせずに過去の情報を活用できるようにする。

### 適用判断基準

| 必要なメモリ種別 | 用途 | 実装方式 |
|----------------|------|---------|
| Working Memory | 現在のセッション内の会話文脈 | トークン上限付きメッセージリスト |
| Episodic Memory | 過去セッションの関連メッセージ | 永続DB + 意味検索 |
| Procedural Memory | ユーザー設定・システム指示 | システムプロンプトへの動的注入 |
| Semantic Memory | コンテンツベースの事実・知識 | ベクトルDB + メタデータフィルタ |

### 実装のポイント

#### Working Memory（現在セッション）

```python
from langchain_core.messages import trim_messages
from langchain_openai import ChatOpenAI

def get_trimmed_working_memory(messages: list, max_tokens: int = 1000) -> list:
    """
    トークン上限を超えないようにメッセージ履歴を刈り込む。
    システムプロンプト・会話の完全なペアを維持する。
    """
    return trim_messages(
        messages,
        strategy="last",                    # 最新のメッセージを優先
        token_counter=ChatOpenAI(model="gpt-4o-mini"),
        max_tokens=max_tokens,
        start_on="human",                   # 人間のメッセージで開始
        end_on=("human", "tool"),           # ツール呼び出しで終了可能
        include_system=True,                # システムプロンプトは必ず保持
    )
```

#### Episodic Memory（過去セッション）

```python
# 全メッセージを永続DBに保存し、関連メッセージを検索
async def retrieve_episodic_memory(
    user_id: str,
    current_query: str,
    vector_store,
    days_back: int = 7
) -> list[str]:
    """
    ユーザーの過去会話から現在のクエリに関連するメッセージを取得する。
    コサイン類似度・キーワード・ハイブリッドで検索する。
    """
    relevant_messages = await vector_store.search(
        query=current_query,
        filter={"user_id": user_id, "days_back": days_back},
        limit=5,
    )
    return [msg.content for msg in relevant_messages]
```

#### Mem0を使った統合的な長期記憶

```python
from mem0 import Memory

# 設定：ベクトルストア + LLM + エンベッダーを指定
config = {
    "vector_store": {
        "provider": "chroma",
        "config": {"collection_name": "user_memories", "path": "/tmp/mem0"},
    },
    "llm": {
        "provider": "openai",
        "config": {"model": "gpt-4o-mini", "temperature": 0.1},
    },
    "embedder": {
        "provider": "openai",
        "config": {"model": "text-embedding-3-small"},
    },
}
memory = Memory.from_config(config)

# メッセージから自動で記憶を抽出・保存
conversation = [
    {"role": "user", "content": "シアトルからレイキャビクへの旅行を計画しています"},
    {"role": "assistant", "content": "フライトは約10時間です"},
]
memory.add(conversation, user_id="alice")

# 後のセッションで関連記憶を取得してコンテキストに注入
query = "アイスランドで何ができますか？"
relevant_memories = memory.search(query=query, user_id="alice", limit=3)
```

### 注意事項・トレードオフ

- **Working Memory**: トークン上限の設定が重要。単純なN件刈り込みでは大きなメッセージが問題になる
- **Episodic Memory**: RAGパターン（P6）の応用。適切な類似度閾値の設定が必要
- **Semantic Memory**: コンテンツ優先の検索なのでEpisodicとは補完関係にある
- **セキュリティ**: マルチテナント環境では`user_id`による厳格な分離が必須。記憶の意図しない漏洩を防ぐ
- **代替**: 全履歴をコンテキストに入れる手法はGemini（100万トークンウィンドウ）では可能だが、二次コストが問題
