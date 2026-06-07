# 信頼性向上パターン（P17–P20）

> LLMの確率的な性質に起因する不一致・幻覚・品質劣化を体系的に抑制するための4パターン。

## 目次

- [Pattern 17: LLM-as-Judge](#pattern-17-llm-as-judge)
- [Pattern 18: Reflection](#pattern-18-reflection)
- [Pattern 19: Dependency Injection](#pattern-19-dependency-injection)
- [Pattern 20: Prompt Optimization](#pattern-20-prompt-optimization)

---

## Pattern 17: LLM-as-Judge

### 問題

GenAIシステムの評価は本質的に難しい。タスクがオープンエンドであるため、従来の評価手法には以下の限界がある。

- **結果測定**: 実際のビジネス成果と出力品質の因果関係を切り離せない
- **人手評価**: スケールが困難でコストが高く、評価者のバイアスが入る
- **自動メトリクス（BLEU/ROUGE等）**: n-gram一致を測るだけで、意味的正確性や文脈適合性を捉えられない

スケーラブルかつカスタマイズ可能な評価手法が必要だ。

### 解決策

LLM自体を評価者として利用する。カスタムスコアリングルーブリックを作成し、LLMにそのルーブリックを適用させることで、人手評価に近い品質評価を自動的に大規模に実施する。

3つの適用形態がある。①**Promptingアプローチ**：LLMへ採点基準を与えて直接評価させる。②**MLアプローチ**：LLMの採点結果を入力としてMLモデルを訓練し、実際の成果と連動したスコアを生成する。③**Fine-tuningアプローチ**：人間専門家がアノテーションしたデータでAdapter Tuningし、人間の判断を模倣するモデルを作る。

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| 評価基準が明確に言語化できる | ✅ Promptingアプローチから開始 |
| 実際の成果データ（クリック・購買等）が蓄積されている | ✅ MLアプローチへ移行 |
| 評価が特定ドメインの専門知識を要する | ✅ Fine-tuningアプローチ |
| 単純な回答品質チェック（RAGのコンテキスト欠落検出等） | ✅ 閾値判定のみで十分 |
| リアルタイム性が最優先でレイテンシ予算がない | ⚠️ キャッシュ戦略を併用 |

### 実装のポイント

```python
from pydantic_ai import Agent

def evaluate_content(article: str, summary: str) -> dict:
    """LLM-as-Judgeによるコンテンツ評価"""
    judge_prompt = f"""
    Given an article and a summary, provide a score in the range of 1-5
    for each of the following criteria:
    - Factual accuracy: 1 if any information misrepresents the article, 5 if all statements are grounded
    - Completeness: 1 if multiple high-impact points are missing, 5 if all major points are present
    - Conciseness: 1 if redundant information exists, 5 if efficiently conveyed
    - Clarity: 1 if awkward phrasing, 5 if well structured and easy to understand

    **Article**: {article}
    **Summary**: {summary}
    **Scores**:
    """

    # temperature=0 で一貫性を確保（必須）
    agent = Agent("openai:gpt-4o", model_settings={"temperature": 0})
    result = agent.run_sync(judge_prompt)
    return result.data

# 複数LLMによる評価（LLM-as-Jury）でバイアスを軽減
def multi_judge_evaluate(content: str, judges: list) -> float:
    scores = [judge.evaluate(content) for judge in judges]
    return sum(scores) / len(scores)  # 平均でポジショナルバイアスを軽減
```

**一貫性を高める3つの手法**:
- **粗いスコア**: 1〜5スケール（1〜100は避ける。バイナリが最も安定）
- **複数基準**: 単一スコアではなく複数軸で評価（CoTの効果）
- **複数評価**: 異なるLLMが異なるステークホルダー視点で評価

### 注意事項・トレードオフ

**主な問題**:

| 問題 | 対処法 |
|------|--------|
| **不一致性**: LLMの確率的性質でスコアが変動する | `temperature=0`、キャッシュ、同一random seedを使用 |
| **寛大性バイアス**: LLMはスコアを高めにつけすぎる | 絶対スコアではなく参照回答との比較形式にする |
| **自己バイアス**: 自分が生成した内容に有利なスコアをつける | 生成LLMと評価LLMを別モデルにする |
| **長さバイアス**: 長い回答を不当に高評価する | スコアリング基準に長さペナルティを組み込む |

**代替パターンとの比較**:
- **P18 Reflection**: LLM-as-Judgeが評価スコアを返すのに対し、Reflectionは改善のための批評を返す。両者を組み合わせることが多い
- **P20 Prompt Optimization**: LLM-as-Judgeをevaluatorとして内包する

---

## Pattern 18: Reflection

### 問題

LLM APIは**ステートレス**な呼び出しである。チャットUIでは後続メッセージで誤りを修正できるが、APIを通じた自動化ワークフローでは「初回応答が不十分だった場合に自動的に改善する」仕組みがない。

どうすれば、APIコールの中でLLMが自身の出力を評価し反復的に精錬できるか？

### 解決策

単一のLLM呼び出しの代わりに、**生成→評価→修正**のサイクルを実装する。

1. ユーザープロンプトでLLMを呼び出し、初期応答を取得
2. その応答を評価器（LLM、外部ツール、またはルールベース）に送る
3. 評価器はスコアではなく「どこがどう不十分か」という**批評**を返す
4. 批評を元にプロンプトを修正し、LLMを再度呼び出す
5. 品質基準を満たすまで繰り返す（最大試行回数でループを防ぐ）

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| コード生成でコンパイルエラー・論理バグを事前に検知したい | ✅ Reflectionが非常に有効（ビルド失敗コストが高い） |
| コンテンツ品質を繰り返し改善したい（ロゴ・マーケティング文等） | ✅ 有効（1回の反復でも十分なことが多い） |
| 評価基準が明確に定義できる | ✅ LLM-as-Judge（P17）と組み合わせ |
| リアルタイムチャットボット（レイテンシ上限が厳しい） | ⚠️ 1回の反復のみ、またはバックグラウンド実行を検討 |

### 実装のポイント

```python
from pydantic_ai import Agent
from dataclasses import dataclass
from typing import Optional

@dataclass
class EvaluationResult:
    score: float
    critique: str  # スコアだけでなく改善点を含む批評が必須
    is_acceptable: bool

def reflection_loop(
    prompt: str,
    generator: Agent,
    evaluator: Agent,
    max_attempts: int = 3,
    quality_threshold: float = 0.8
) -> str:
    """Reflectionパターンの実装"""
    response = generator.run_sync(prompt).data

    for attempt in range(max_attempts):
        # 評価・批評ステップ
        eval_prompt = f"""
        Evaluate the following response. Provide:
        1. A score from 0-1
        2. Specific critique on what could be improved

        Original prompt: {prompt}
        Response: {response}
        """
        evaluation = evaluator.run_sync(eval_prompt)

        if evaluation.score >= quality_threshold:
            break

        # 批評を反映した改善プロンプト
        refined_prompt = f"""
        {prompt}

        Previous response: {response}

        Critique: {evaluation.critique}

        Please improve the response based on this critique.
        """
        response = generator.run_sync(refined_prompt).data

    return response

# 会話状態を利用した実装（AutoGenスタイル）
def build_reflection_messages(history: list) -> list:
    """会話履歴をReflectionサイクルのメッセージリストに構築"""
    messages = []
    for item in history:
        if item["type"] == "code_review":
            messages.append({"role": "user", "content": item["review"]})
        elif item["type"] == "code_write":
            messages.append({"role": "assistant", "content": item["code"]})
    return messages
```

### 注意事項・トレードオフ

**コストと品質のトレードオフ**:

| 観点 | 詳細 |
|------|------|
| **コスト増加** | 反復ごとに追加のLLM呼び出しが発生。反復数×推論コスト |
| **レイテンシ増加** | テールレイテンシが問題になりやすい（APIプロバイダの可用性に依存） |
| **品質向上** | 特にコード生成では構文エラー・論理バグの事前検知に大きな効果 |

**実装上の重要ポイント**:
- 評価器は生成LLMと**異なるLLM**を使う（自己バイアス回避）
- 最大試行回数（`max_attempts`）を必ず設定してループを防ぐ
- しきい値の設定が難しい場合は「ちょうど1回の反復」が実用的な妥協点
- **代替**: P17 LLM-as-Judgeをevaluatorとして使い、P18の評価・改善サイクルを回す構成が典型的な組み合わせ

---

## Pattern 19: Dependency Injection

### 問題

LLMチェーン（複数のLLM呼び出しを連結したパイプライン）の開発とテストは困難だ。

- **非決定性**: 同じ入力でも異なる出力が返る → アサーションベースのテストが難しい
- **モデルの急激な変化**: 新バージョンリリースごとに全テストを再実施する必要がある
- **ステップ間の依存**: ステップ2のテストにステップ1の実行が必要 → コストがかかり独立テストができない

特にエージェントアプリケーションでは、一つのLLM呼び出しの出力が次の入力コンテキストに埋め込まれるため、各ステップを独立して開発・テストする方法が必要だ。

### 解決策

LLMチェーンの各ステップを**差し替え可能な関数**として設計し、テスト時にはLLM呼び出しを軽量なモック実装に置き換える。

依存関係を関数の引数として「注入」することで、デフォルトはLLMを呼び出し、テスト時はモックを使えるようにする。

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| 2つ以上のLLM呼び出しを連結するパイプライン | ✅ 常に適用 |
| 各ステップの入出力型が明確に定義できる | ✅ 適用しやすい |
| 外部APIやデータベースへの呼び出しが含まれる | ✅ ネットワーク依存のモックにも有効 |
| 単一のLLM呼び出しのみ | ⚠️ 過剰設計になる場合がある |

### 実装のポイント

```python
from dataclasses import dataclass
from typing import Callable, List
from pydantic_ai import Agent

@dataclass
class Critique:
    target_audience: List[str]
    improvements: List[str]

@dataclass
class Improvement:
    change: str
    reason: str
    modified_text: str

def critique(in_text: str) -> Critique:
    """ステップ1: LLMによる批評生成"""
    agent = Agent("openai:gpt-4o", result_type=Critique)
    prompt = f"Identify target audience and suggest 5 improvements for: {in_text}"
    return agent.run_sync(prompt).data

def improve(text: str, c: Critique) -> Improvement:
    """ステップ2: LLMによる改善実施"""
    agent = Agent("openai:gpt-4o", result_type=Improvement)
    prompt = f"Apply one improvement from {c.improvements} to: {text}"
    return agent.run_sync(prompt).data

# ★ Dependency Injectionの核心：関数を引数として受け取る
def improvement_chain(
    in_text: str,
    critique_fn: Callable[[str], Critique] = critique,      # デフォルトはLLM呼び出し
    improve_fn: Callable[[str, Critique], Improvement] = improve  # デフォルトはLLM呼び出し
) -> Improvement:
    c = critique_fn(in_text)
    assert len(c.improvements) > 3, "Should have 4+ improvements"

    improved = improve_fn(in_text, c)
    return improved

# モック実装（テスト・開発時に使用）
def mock_critique(in_text: str) -> Critique:
    """テスト用ハードコード実装 - LLMを呼び出さない"""
    return Critique(
        target_audience=["AI Engineers", "ML Engineers"],
        improvements=[
            "Use more precise technical language",
            "Add concrete code examples",
            "Highlight performance benchmarks",
            "Emphasize production-readiness",
            "Include migration guides",
        ]
    )

# ステップ2をステップ1に依存せずテスト
improved = improvement_chain(text, critique_fn=mock_critique)
assert improved.change in mock_critique(text).improvements
```

**Pythonでの重要な実装Tips**:
- `assert`文は`-O`フラグで本番環境でオフにできる（開発中のみ有効）
- pytest環境では`assert`が失敗時に詳細なコールスタック情報を提供
- 抽象クラス・インターフェースを使った型安全なモック実装も可能

### 注意事項・トレードオフ

| 課題 | 詳細 |
|------|------|
| **ハードコード値の困難** | ステップ間の依存が複雑になると適切なモック値の設定自体が難しくなる |
| **モックとリアルの乖離リスク** | モックが実際のLLM出力と乖離すると、テストが実環境で機能しない |

**代替パターンとの比較**:
- P18 Reflection: 出力品質の向上が目的。Dependency Injectionはテスタビリティが目的
- 両パターンを組み合わせることで「テスト可能なReflectionパイプライン」を構築できる

---

## Pattern 20: Prompt Optimization

### 問題

GenAIアプリケーション開発では、プロンプトエンジニアリングは試行錯誤の繰り返しだ。基盤モデルのバージョンが変わるたびに、手動でプロンプトを再調整する必要があり、アプリケーション全体がLLMへの依存関係の変化に対して**非常に脆弱**になる。

モデルプロバイダがバージョンアップする、ツールチェーンが変わる、要件が変化するたびに、すべてのプロンプトを手動で再実験しなければならない。

### 解決策

プロンプトを手動で管理するのではなく、**フレームワークに自動最適化させる**。

4つのコンポーネントが必要:

1. **パイプライン**: LLM呼び出しのステップを定義（ただしプロンプト文字列は書かない）
2. **データセット**: 評価用の入力例（1件でも有効）
3. **評価器**: パイプライン出力の品質を自動評価（LLM-as-Judge等）
4. **オプティマイザ**: 複数のプロンプトバリアントを生成・評価し最良を返す

依存関係が変化するたびに、フレームワークを再実行するだけで最適化済みのプロンプトが得られる。

### 適用判断基準

| 条件 | 推奨 |
|------|------|
| LLMバージョンの変更が定期的に発生する | ✅ Prompt Optimizationが最も価値を発揮 |
| 明確な評価基準（参照回答またはスコアリングルーブリック）がある | ✅ 自動化が可能 |
| 多数のドキュメント・入力に対してパイプラインを汎化させたい | ✅ Few-shotオプティマイザが有効 |
| プロンプトを手動管理する時間リソースがない | ✅ メンテナンスコスト削減 |
| プロトタイプ段階で依存変更が少ない | ⚠️ 過剰設計。まず手動プロンプトエンジニアリングで十分 |

### 実装のポイント

```python
import dspy

# LLMの設定（プロンプトは書かない）
lm = dspy.LM("claude-sonnet-4-6", api_key="...")
dspy.configure(lm=lm)

# ステップ1: 入出力の「シグネチャ」のみを定義
class ContentExtraction(dspy.Signature):
    """コンテンツから構造化情報を抽出する"""
    text: str = dspy.InputField(desc="対象テキスト")
    summary: str = dspy.OutputField(desc="要約")
    key_points: list = dspy.OutputField(desc="重要ポイントのリスト")

class ContentImprovement(dspy.Signature):
    """コンテンツをターゲット読者向けに改善する"""
    original: str = dspy.InputField(desc="元のテキスト")
    target_audience: list = dspy.InputField(desc="対象読者の役職リスト")
    improved: str = dspy.OutputField(desc="改善されたテキスト")

# ステップ2: パイプラインを定義
class ContentPipeline(dspy.Module):
    def __init__(self):
        self.extract = dspy.ChainOfThought(ContentExtraction)
        self.improve = dspy.ChainOfThought(ContentImprovement)

    def forward(self, text: str):
        extracted = self.extract(text=text)
        improved = self.improve(
            original=text,
            target_audience=["ML Engineer", "AI Researcher"]
        )
        return extracted, improved

# ステップ3: 評価器（LLM-as-Judgeを活用）
def evaluate_improvement(args, pred) -> float:
    original, improved = pred
    # LLM-as-Judgeで品質スコアを計算（-1〜1）
    scorer = dspy.ChainOfThought("original, improved -> score: float")
    result = scorer(original=str(original), improved=str(improved))
    return float(result.score)

# ステップ4: 最適化の実行
program = ContentPipeline()

# 方法A: N回試行して最良のプロンプトを選択
optimized = dspy.BestOfN(
    module=program,
    N=10,
    reward_fn=evaluate_improvement,
    threshold=0.8
)

# 方法B: 複数サンプルでFew-shot最適化
trainset = [dspy.Example(text=t).with_inputs("text") for t in sample_texts]
optimizer = dspy.BootstrapFewShot(metric=evaluate_improvement)
optimized_pipeline = optimizer.compile(program, trainset=trainset)
optimized_pipeline.save("optimized_pipeline", save_program=True)

# 本番推論（最適化済みパイプラインを使用）
result = optimized_pipeline(text="...")
```

**DSPy以外の選択肢**: AdalFlow、PromptWizard（いずれもPrompt Optimizationをサポート）

### 注意事項・トレードオフ

| 観点 | 詳細 |
|------|------|
| **プロンプト管理との違い** | プロンプトを外部化するだけでは根本的な問題（依存変更時の再実験）は解決しない |
| **評価器の質が最重要** | 評価器が不適切だと最適化の方向が誤る。評価器設計に投資する価値がある |
| **データセットサイズ** | 1件でも動作するが、多様なサンプルがあるほど汎化性能が上がる |
| **計算コスト** | N回試行はN倍の推論コストが発生する。Few-shot最適化は一度だけ実行し保存 |

**代替パターンとの比較**:
- P17 LLM-as-Judge: Prompt Optimizationのevaluatorコンポーネントとして内包
- P19 Dependency Injection: パイプラインの各ステップをモック可能にしてテスト。両者は補完的
- P15 Adapter Tuning: プロンプト最適化では対応しきれない場合はファインチューニングへ移行

---

## パターン組み合わせ指針

| 組み合わせ | 効果 |
|-----------|------|
| P17 + P18 | LLM-as-JudgeをReflectionのevaluatorとして使用。最も一般的な組み合わせ |
| P18 + P19 | ReflectionパイプラインをDependency Injectionでテスタブルに設計 |
| P17 + P20 | LLM-as-JudgeをPrompt Optimizationの評価器として使用 |
| P17 + P18 + P19 + P20 | 完全な信頼性スタック（プロダクション品質のLLMアプリの理想形） |
