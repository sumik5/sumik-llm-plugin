# プロンプトエンジニアリング リファレンス

Webアプリ開発者向けのプロンプト設計・管理・最適化実践ガイド。

---

## 1. プロンプトの基礎

**いつ使うか**: LLMとのインタラクション設計を始める際、まず基本概念を理解してから実装に入る。

### プロンプトとは

プロンプトとはLLMから特定の応答を引き出すために設計された**構造化コミュニケーションパターン**。自然言語の指示をモデルが処理できる数値形式（トークン）に変換する「トークン化」プロセスを経由する。

**トークン化パイプライン（7段階）**

| ステップ | 説明 |
|---------|------|
| 1. Human input | ユーザーが入力した生のテキスト |
| 2. Tokenization | テキストをトークンに分割し数値IDに変換 |
| 3. Token IDs | LLM処理用の数値表現 |
| 4. LLM processing | AIモデルが入力を解析しレスポンス生成 |
| 5. Output token IDs | LLMのレスポンスを数値形式で出力 |
| 6. Detokenization | 数値IDをテキストトークンに再変換 |
| 7. Human-readable output | トークンを結合して最終的なテキスト生成 |

### Max Tokensとコスト管理

- **max tokens**: 入力＋出力を含む1インタラクションで処理できるトークンの最大数
- 入力が200トークンなら、8,192トークン制限モデルでは残り7,992トークンが出力に利用可能
- コスト = 入力トークン数 × 単価 + 出力トークン数 × 単価（多くのプロバイダーの課金モデル）

**トークン数のカウント（TypeScript例）**

```typescript
import { encoding_for_model } from '@dqbd/tiktoken';

function countTokens(text: string, model: string = "gpt-3.5-turbo"): number {
  const enc = encoding_for_model(model);
  const tokens = enc.encode(text);
  enc.free();
  return tokens.length;
}

const prompt = "Translate the following English text to French: 'Hello, how are you?'";
const systemMessage = "You are a helpful assistant that translates English to French.";

const promptTokens = countTokens(prompt);
const systemTokens = countTokens(systemMessage);
const totalTokens = promptTokens + systemTokens;

console.log(`Prompt tokens: ${promptTokens}`);
console.log(`System message tokens: ${systemTokens}`);
console.log(`Total tokens: ${totalTokens}`);
```

> **注**: `tiktoken` はOpenAI系モデル用。Google Geminiではトークン数はAPIレスポンス経由で取得する。

### プロンプトタイプ一覧

Vercel AI SDKにおけるプロンプトタイプの階層：

| タイプ | 属性 | 説明 | ユースケース |
|--------|------|------|-------------|
| **Basic text** | `prompt` | 単純な文字列 | 一回限りのクエリ |
| **Simple message** | `messages` | role + content | マルチターン会話 |
| **Compound message** | `messages` | テキスト＋画像等の複合コンテンツ | 画像付きの質問・RAG |
| **Tool call message** | `messages` | `type: 'tool-call'` + パラメータ | API呼び出し・自動化エージェント |
| **System** | `system` | 会話全体のコンテキスト設定 | ペルソナ定義・制約設定 |

**Basic text promptの実装例**

```typescript
import { generateText } from 'ai';
import { createGoogleGenerativeAI } from '@ai-sdk/google';

const google = createGoogleGenerativeAI({ apiKey });

// シンプルなテキストプロンプト
await generateText({
  prompt: 'Hello, what is your name?',
  model: google("models/gemini-2.0-flash")
});
```

**Compound message（画像添付）の実装例**

```typescript
await generateText({
  messages: [
    {
      role: "user",
      content: [
        { type: "text", text: "Describe the following image" },
        { type: "image", image: "data:image/png;base64..." }
      ]
    }
  ],
  model: google("models/gemini-2.0-flash")
});
```

**System promptの実装例**

```typescript
await generateText({
  prompt: 'Hello, how are you?',
  model: google("models/gemini-2.0-flash"),
  system: "You are a helpful assistant specializing in technical support. Always provide step-by-step solutions."
});
```

---

## 2. プロンプト管理

**いつ使うか**: アプリが成長してプロンプトが複数存在するようになったとき、または動的な更新が必要になったとき。

### データベースベースのプロンプト管理が必要な理由

| 理由 | 説明 |
|------|------|
| **Dynamic updates** | 再デプロイなしでプロンプトを更新可能 |
| **Version control** | 複数バージョンを保持してA/Bテスト・ロールバックが可能 |
| **Scalability** | 数百〜数千のプロンプトをDBで効率管理 |
| **Access control** | RBACでプロンプトエンジニアとアプリ開発者の権限分離 |

### バージョニング戦略

**ファイル名セマンティックバージョニング**

```typescript
// prompts/translation_openai_v1.0.1.ts
export const translationPrompt_openai_v1_0_1 =
  "Translate the following text from {source_lang} to {target_lang}: {text}";

// prompts/translation_openai_v1.1.0.ts
export const translationPrompt_openai_v1_1_0 =
  "You are a professional translator. Translate the following text from {source_lang} to {target_lang}, maintaining the original tone and style: {text}";

// prompts/translation_anthropic_v1.0.0.ts
export const translationPrompt_anthropic_v1_0_0 =
  "As an AI language model, please translate the given text from {source_lang} to {target_lang}. Ensure that the translation is accurate and natural-sounding. Text to translate: {text}";
```

**バージョン番号の意味（SemVer準拠）**

| コンポーネント | 使用タイミング |
|---------------|--------------|
| **MAJOR (X)** | AIモデルのメジャーアップデートやプロンプト構造の大幅な変更 |
| **MINOR (Y)** | プロンプトの改善（既存動作を壊さない範囲） |
| **PATCH (Z)** | タイポ修正・指示の明確化・出力フォーマットの微調整 |

### テスト戦略

**テスト手法の選択基準**

| 手法 | 適用場面 | メリット | デメリット |
|------|---------|---------|-----------|
| **Mockingテスト** | ロジック層の単体テスト | 高速・決定論的 | 実際のLLM動作を検証できない |
| **Semantic similarity** | 意味の一貫性確認 | 柔軟・意味ベース評価 | 閾値設定が主観的 |
| **Constrained validation** | ルール遵守確認 | 厳格な制約検証 | 事前設定が煩雑 |

**Mockingテスト（Vitest）**

```typescript
import { vi, expect, test } from "vitest";

vi.mock("ai", () => ({
  generateText: vi.fn(),
}));

import { generateText } from "ai";
import { continueConversation } from "./actions";

test('summary generation contains key points', async () => {
  (generateText as ReturnType<typeof vi.fn>).mockResolvedValue(
    "A concise summary of the input text."
  );

  const result = await continueConversation([
    { role: "user", content: "Long input text..." },
  ]);

  expect(result).toContain("concise summary");
});
```

**Semantic similarityテスト**

```typescript
import { generateText } from "ai";
import stringComparison from 'string-comparison';

function semanticSimilarity(text1: string, text2: string): number {
  const cos = stringComparison.cosine;
  return cos.similarity(text1, text2);
}

test("generated text is semantically similar to expected output", async () => {
  (generateText as ReturnType<typeof vi.fn>).mockResolvedValue(
    "AI greatly influences modern life in many ways."
  );

  const expected = "AI has a significant impact on modern society.";
  const generated = await generateText("Describe the role of AI in today's world.");

  const similarity = semanticSimilarity(expected, generated as unknown as string);
  expect(similarity).toBeGreaterThan(0.7); // 閾値は用途に応じて調整
});
```

**Constrained validationテスト**

```typescript
function validateConstraints(
  text: string,
  minWords: number,
  maxWords: number,
  requiredWords: string[]
): boolean {
  const words = text.split(/\s+/);
  return (
    words.length >= minWords &&
    words.length <= maxWords &&
    requiredWords.every((word) => text.toLowerCase().includes(word.toLowerCase()))
  );
}

test("generated text meets constraints", async () => {
  (generateText as ReturnType<typeof vi.fn>).mockResolvedValue({
    text: "Regular exercise significantly improves health and fitness by boosting energy."
  });

  const { text } = await generateText({
    model: "fakeModel",
    prompt: "Summarize the benefits of exercise in 20-30 words. Include 'health' and 'fitness'.",
  });

  expect(validateConstraints(text as unknown as string, 20, 30, ["health", "fitness"])).toBe(true);
});
```

---

## 3. Few-shot Learning

**いつ使うか**: モデルが特定のフォーマット・トーン・スタイルで応答してほしいが、fine-tuningコストをかけたくない場合。

### 手法の比較

| 手法 | 説明 | コスト | 精度 | 適用場面 |
|------|------|--------|------|---------|
| **Zero-shot** | 例なしでタスク実行 | 低 | 中 | 汎用的なタスク |
| **Few-shot** | 少数の例を提供 | 中 | 高 | 特定スタイルが必要な場合 |
| **Fine-tuning** | 追加学習でモデル調整 | 高 | 最高 | 専門ドメイン・大量データあり |

### Few-shot学習のステップ

1. **コンテキスト設定** — AIの役割と全体タスクを明確に定義
2. **例の収集** — 出力の形式・トーン・構造を示す代表例を準備
3. **プロンプト設計** — 例を組み込んだプロンプトを作成
4. **モデル実行** — LLMがプロンプトを処理して出力生成
5. **レビューと調整** — 出力を確認し、必要に応じてプロンプトを改良

### 実装例 1: プログラミング言語リスト生成

```typescript
const prompt = `
List 5 popular programming languages along with a brief description of each:
1. JavaScript: A versatile language primarily used for web development.
2. Python: Known for its readability and used in data science and web development.
3. Java: A widely-used language for building enterprise-level applications.
4.`;
// 「5.」まで続けるよう例示で誘導する
```

> **重要**: 「some」のような曖昧な表現を避け、数量を明示する（「5 popular」など）。

### 実装例 2: カスタマーサポートボット

```typescript
const system = `
You are a customer support chatbot. Adapt your tone and sentiment based on the following example interactions for each supported use case:

**Use Case 1: Technical Support**
**User:** My internet connection is really slow. Can you help me?
**Chatbot:** I'm sorry to hear that you're experiencing slow internet speeds. Let's troubleshoot this together. Can you please provide me with your current speed test results?

**Use Case 2: Billing Inquiry**
**User:** I was charged twice for my subscription this month. What happened?
**Chatbot:** I understand how concerning double charges can be. Let me check your account details and resolve this issue for you right away.

**Use Case 3: General Inquiry**
**User:** What are your customer support hours?
**Chatbot:** Our customer support team is available 24/7 to assist you with any questions you may have.

Now, respond to the following user inquiries using the appropriate tone and sentiment:
`;
```

### 一般的なFew-shotプロンプト作成方法

| ステップ | 内容 | 例 |
|---------|------|-----|
| 1. コンテキスト設定 | AIの役割を明確に定義 | 「You are a customer support chatbot.」 |
| 2. ユースケース特定 | 異なるシナリオをリスト化 | 「Use Case 1: Technical Support」 |
| 3. 例示のインタラクション | ユーザー質問と理想的な応答のペアを提供 | User/Chatboxのやり取り |
| 4. 多様性の確保 | 技術・請求・一般問い合わせ等の多様な例 | 3種類以上のユースケース |
| 5. 締めの指示 | 例を参考に新しいクエリに応答するよう指示 | 「Now, respond to...」 |

---

## 4. Chain-of-Thought (CoT) プロンプティング

**いつ使うか**: 複雑な推論・数学計算・段階的な問題解決が必要なとき。

### CoTの基本アプローチ

明示的に「ステップバイステップで解いてください」と指示することで、モデルに推論プロセスを公開させる。

**実装例**

```typescript
const prompt = `
Solve the following problem step-by-step:
What is 25 percent of 80?

Answer:
1. Understand the question:
   We need to find 25% of 80.
2. Convert the percentage to a decimal number:
   25% = 25/100 = 0.25
3. Multiply the decimal by 80:
   0.25 × 80 = 20
Therefore, 25% of 80 is 20 percent.
`;
```

### CoTの限界と注意点

| 問題 | 説明 |
|------|------|
| **問題の誤解** | モデルが質問のニュアンスを正確に把握できない場合がある |
| **曖昧なプロンプト** | 句読点や語順の誤りが解釈に影響 |
| **モデルの限界** | ハルシネーション（幻覚）が生じることがある |
| **オーバーフィット** | 特定パターンの例に過適合するリスク |

### CoTプロンプト作成の一般手順

| ステップ | 内容 | 例 |
|---------|------|-----|
| 1. 構造定義 | プロンプトのフォーマットと期待する応答形式を確立 | 「Calculate the area: Area = π * R²」 |
| 2. 例の提供 | 類似問題の解き方を例示（Few-shotと組み合わせ） | 「If r = 3, then Area = π * 3² = 28.27」 |
| 3. ステップ指示追加 | 明示的に段階的説明を要求 | 「Explain your answer step-by-step.」 |
| 4. 一貫性テスト | 様々な入力で動作確認 | 「What is the area if r = 5?」 |
| 5. 反復・改善 | 不整合が見つかれば明確な言葉に改訂 | 「Calculate the area of a circle with r = 5.」 |

---

## 5. Embeddings

**いつ使うか**: セマンティック検索・コンテンツ推薦・類似性ベースの情報検索を実装するとき。

### Embeddingsの概念

Embeddingsはテキスト・画像・音声などのデータを**高次元ベクトル空間の浮動小数点数の配列**として表現したもの。意味的な関係性やパターンを数値でエンコードする。

**データの種類と用途**

| タイプ | 用途 |
|--------|------|
| **Word embeddings** | 単語間の意味的関係を捉える（類義語クラスタリング等） |
| **Image embeddings** | 類似画像の検索・分類 |
| **Graph embeddings** | ソーシャルネットワーク・知識グラフの関係性表現 |

### Embeddingsの重要な特性

| 特性 | 説明 |
|------|------|
| **モデル固有** | 異なるモデルのembeddingは互換性なし（OpenAI ≠ Google等） |
| **決定論的** | 同じモデルバージョン・同じ入力→同じ出力 |
| **人間には非可読** | 大量の浮動小数点数の配列（意味は機械にのみ理解可能） |
| **機械語ではない** | 命令実行用でなく、データ表現のための数値 |

### Vercel AI SDKでの実装

**単一テキストのembedding生成 (`embed`)**

```typescript
import { embed } from "ai";
import { createGoogleGenerativeAI } from "@ai-sdk/google";

const google = createGoogleGenerativeAI({ apiKey });

const { embedding } = await embed({
  model: google.textEmbeddingModel("text-embedding-004"),
  value: "The quick brown fox jumps over the lazy dog",
});

console.log(embedding);
// [-0.0450604, -0.014942412, -0.037350334, ...]
```

**複数テキストのbatch embedding生成 (`embedMany`)**

```typescript
import { embedMany } from "ai";
import { createGoogleGenerativeAI } from "@ai-sdk/google";

const google = createGoogleGenerativeAI({ apiKey });

const { embeddings } = await embedMany({
  model: google.textEmbeddingModel("text-embedding-004"),
  values: [
    'The quick brown fox jumps over the lazy dog',
    'A journey of a thousand miles begins with a single step',
    'To be or not to be, that is the question',
  ],
});

console.log(embeddings); // 各入力に対応するembedding配列
```

### Embeddingsをデータベースに保存する理由

| 理由 | 説明 |
|------|------|
| **効率性** | 大規模データセットの都度生成は計算コストが高い |
| **スケーラビリティ** | 大量の並行リクエストに対応可能 |
| **コスト削減** | APIコール数を最小化し運用コストを削減 |

**対応ベクトルデータベース（主要なもの）**

| タイプ | 製品例 |
|--------|--------|
| 専用ベクトルDB | Pinecone, Milvus, Chroma |
| 汎用DB+ベクトル拡張 | PostgreSQL + pgvector, MongoDB, Neo4j |
| インメモリ（開発用） | 配列/オブジェクト（本番非推奨） |

### ユースケース: ITサポート知識ベース

4ステップのembedding活用パイプライン：

**Step 1: Embeddingの生成と保存**

```typescript
const embeddingDB: Record<string, number[]> = {};
const questions = [
  "How do I reset my password?",
  "What should I do if my computer won't start?",
];
const answers = [
  "To reset your password, go to the login page and click 'Forgot Password'. Follow the instructions to reset your password.",
  "If your computer won't start, check the power cable, try restarting it, and if the issue persists, contact support.",
];

for (let i = 0; i < questions.length; i++) {
  const { embedding } = await embed({
    model: google.textEmbeddingModel("text-embedding-004"),
    value: questions[i],
  });
  embeddingDB[questions[i]] = embedding;
}
```

**Step 2: ユーザークエリのembedding生成**

```typescript
const userQuery = "I forgot my password";
const { embedding: queryEmbedding } = await embed({
  model: google.textEmbeddingModel("text-embedding-004"),
  value: userQuery,
});
```

**Step 3: 類似性検索**

```typescript
let maxSimilarity = -1;
let mostRelevantQuestion = "";

for (const [question, storedEmbedding] of Object.entries(embeddingDB)) {
  const similarity = cosineSimilarity(queryEmbedding, storedEmbedding);
  if (similarity > maxSimilarity) {
    maxSimilarity = similarity;
    mostRelevantQuestion = question;
  }
}
```

**Step 4: 結果返却**

```typescript
const relevantAnswer = answers[questions.indexOf(mostRelevantQuestion)];
console.log(`Most relevant question: ${mostRelevantQuestion}`);
console.log(`Relevant answer: ${relevantAnswer}`);
```

---

## 6. 高度なLLM技法

**いつ使うか**: 複雑な推論・品質改善・評価の自動化が必要な場合に参考として活用。

### Tree of Thoughts (ToT)

単一の線形推論パス（CoT）を超えて、**木構造で複数の推論パスを並行探索**する手法。

| 比較 | Chain-of-Thought | Tree of Thoughts |
|------|-----------------|-----------------|
| 推論パス | 1本の線形パス | 複数の分岐パスを探索 |
| 適用タスク | 逐次推論問題 | 戦略的計画・多段階先読みが必要な問題 |
| コスト | 低 | 高 |

### Self-Refine

LLM自身がフィードバックループで出力を**反復改善**する手法：

1. 初期出力を生成
2. LLM自身が出力に対してフィードバックを提供
3. フィードバックに基づいて出力を改善
4. 品質基準を満たすまでサイクルを繰り返す

**適用場面**: レビュー改善・コード最適化など、目標が複雑または定義しにくいタスク。

### LLM-as-a-Judge

**LLMを使って別のLLMが生成したテキストの品質を評価**する手法。人手評価の代替として機能する。

| 評価できる観点 | 例 |
|--------------|-----|
| 正確性 | 事実の正誤 |
| トーン | フォーマル/カジュアル |
| 簡潔性 | 冗長さの排除 |

> **注意**: ジャッジLLM自身のバイアスが入る可能性があるため、慎重なプロンプト設計が必要。

---

## 7. Webアプリでの実践パターン

**いつ使うか**: プロダクションレベルのWebアプリにプロンプト管理を組み込むとき。

### プロンプトテンプレート管理アーキテクチャ

PromptLibraryクラスを通じてLLMへのAPIコールとプロンプト管理を分離する例：

```typescript
class PromptLibrary {
  private prompts: Record<string, string> = {};

  registerPrompt(name: string, template: string): void {
    this.prompts[name] = template;
  }

  getPrompt(name: string, variables: Record<string, string>): string {
    const template = this.prompts[name];
    if (!template) throw new Error(`Prompt '${name}' not found`);
    return Object.entries(variables).reduce(
      (result, [key, value]) => result.replace(`{${key}}`, value),
      template
    );
  }

  async generateDiagram(type: 'class' | 'activity', description: string): Promise<string> {
    const promptName = type === 'class' ? 'generateClassDiagram' : 'generateActivityDiagram';
    const prompt = this.getPrompt(promptName, { description });
    const { text } = await generateText({ prompt, model: /* ... */ });
    return text;
  }
}
```

### テスト戦略の選択フロー

```
新しいプロンプトを実装
        ↓
  ロジック層のテストが必要？
  → Yes: Mockingテストを使用
        ↓
  意味的一貫性の確認が必要？
  → Yes: Semantic similarityテスト（閾値0.7前後）
        ↓
  出力ルール遵守の確認が必要？
  → Yes: Constrained validationテスト
```

### プロンプトのバージョン管理フロー

| フェーズ | アクション |
|---------|-----------|
| 開発初期 | Gitでファイルとして管理（コードと一緒にバージョン管理） |
| プロダクション移行 | DBに移行し動的更新を可能に |
| A/Bテスト | 複数バージョンを並行運用し効果測定 |
| モデル移行 | プロバイダー名をファイル名に含めて互換性管理 |
