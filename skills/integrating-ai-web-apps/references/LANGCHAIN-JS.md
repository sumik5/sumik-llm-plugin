# LangChain.js リファレンス

LangChain.jsを使ったAIワークフロー構築とVercel AI SDK連携の実践ガイド。

---

## 1. LangChain.jsの概要

**いつ使うか**: 単純なプロンプト→レスポンスを超えた、複数ステップのAIワークフローやドキュメント検索・エージェント処理が必要なとき。

### LangChain.jsとは

LangChainは複数のステップを一貫したワークフローに**チェーン（連鎖）**するための抽象化フレームワーク。API連携・コンテンツのパース・各種DBとのやり取りなどの低レベル処理を内部で処理し、コンポーザブルなAPIを提供する。

### モジュール一覧

| モジュール | 説明 | 用途 |
|-----------|------|------|
| `langchain/prompts` | プロンプトテンプレートと入力変数を管理 | Few-shot・テンプレート管理 |
| `langchain/agents` | ツールを使用し意思決定できる自律エージェント | 複雑なマルチステップタスク |
| `langchain/chains` | 複数コンポーネントを再利用可能なパイプラインに統合 | データ処理・RAGパイプライン |
| `@langchain/core` | 共通ユーティリティと関数を提供するコアパッケージ | Runnables・出力パーサー等 |
| `@langchain/community` | コミュニティパッケージ | サードパーティ統合 |
| `langchain/vectorstores` | 各種ベクトルDBストア統合 | 埋め込み保存・類似検索 |
| `langchain/storage` | メモリやDBでのデータ保存抽象 | セッション管理 |
| `langchain/document_loaders` | 各種ソースからのドキュメント読み込み支援 | ファイル・API・DBからの取得 |
| `@langchain/openai`, `@langchain/anthropic` | 各プロバイダーのLLM統合クラス | マルチプロバイダー対応 |
| `langchain/output_parsers` | LLM出力を扱いやすいフォーマットに変換するクラス群 | 構造化出力・JSON変換 |

---

## 2. チェーン（Chains）

**いつ使うか**: 複数の処理を順番に実行するパイプラインを構築するとき。

### Runnablesの仕組み

**Runnable**は入力を受け取り、処理して出力を返す作業単位。出力は次のRunnableへの入力として渡せる。LangChain Expression Language (LCEL) という宣言的な方法でRunnablesを組み合わせる。

**2種類のチェーン構築スタイル**

```typescript
import { StringOutputParser } from "@langchain/core/output_parsers";
import { ChatPromptTemplate } from "@langchain/core/prompts";
import { RunnableLambda, RunnableSequence } from "@langchain/core/runnables";
import { ChatOpenAI } from "@langchain/openai";
import "dotenv/config";

const toUpperCase = (input: { text: string }) => ({
  uppercased: input.text.toUpperCase(),
});

const vowelCountFunction = (input: { uppercased: string }) => {
  const vowels = input.uppercased.match(/[AEIOU]/gi);
  return { vowelCount: vowels ? vowels.length : 0 };
};

const model = new ChatOpenAI({ openAIApiKey: process.env.OPENAI_API_KEY, model: "gpt-4o" });
const prompt = ChatPromptTemplate.fromTemplate("Show the number {vowelCount} two times.");

// スタイル1: .pipe()でチェーン
const chain = RunnableLambda.from(toUpperCase)
  .pipe(RunnableLambda.from(vowelCountFunction))
  .pipe(prompt)
  .pipe(model)
  .pipe(new StringOutputParser());

// スタイル2: RunnableSequence.fromで一括定義（同じ動作）
const sequence = RunnableSequence.from([
  RunnableLambda.from(toUpperCase),
  RunnableLambda.from(vowelCountFunction),
  prompt,
  model,
  new StringOutputParser(),
]);

const output = await chain.invoke({ text: "hello world" });
console.log(output); // "3 3"
```

> **スタイルの選択**: `.pipe()`は逐次的な読みやすさ重視、`RunnableSequence.from()`は全ステップを配列で一覧できるコードスタイル好みによる。

### Vercel AI SDKとの統合（チェーンストリーミング）

LangChainの `chain.stream()` 出力を Vercel AI SDKの `createStreamableUI` に繋げる方法：

```typescript
import { createStreamableUI, getMutableAIState } from "ai/rsc";
import { generateId } from "ai";
import { RunnableLambda } from "@langchain/core/runnables";
import { StringOutputParser } from "@langchain/core/output_parsers";
import { ChatGoogleGenerativeAI } from "@langchain/google-genai";

const llm = new ChatGoogleGenerativeAI({ apiKey: process.env.GEMINI_API_KEY });

export async function getChainStream(city: string) {
  const chain = RunnableLambda.from(fetchWeatherData)
    .pipe(promptTemplate)
    .pipe(llm)
    .pipe(new StringOutputParser());

  const stream = await chain.stream({ city });
  return stream;
}

export async function continueConversation(input: string) {
  const aiState = getMutableAIState();
  const stream = createStreamableUI();

  stream.update(<div>Processing your request...</div>);

  const aiResponseStream = await getChainStream(input);
  let textContent = '';

  for await (const item of aiResponseStream) {
    textContent += item;
    stream.update(<ChatBubble role="assistant" text={textContent} className="mr-auto border-none" />);
  }

  stream.done();
  aiState.done({
    ...aiState.get(),
    messages: [
      ...aiState.get().messages,
      { id: generateId(), role: 'assistant', content: textContent },
    ],
  });

  return { id: generateId(), display: stream.value, role: 'assistant' };
}
```

**ストリーム統合時の注意点**

| 注意点 | 内容 |
|--------|------|
| **ストリームのクローズ** | `stream.done()` と `aiState.done()` で必ず閉じる |
| **レスポンスの累積** | `textContent` のようなアキュムレーターで全チャンクを結合 |
| **引数の順序** | チェーンの入力変数とパイプの順序を正確に合わせる |

---

## 3. プロンプトテンプレート

**いつ使うか**: 動的な変数を含むプロンプトを再利用可能な形で管理したいとき。

### PromptTemplateの基本

```typescript
import { ChatPromptTemplate, PromptTemplate } from "@langchain/core/prompts";

// シンプルなテンプレート
const simplePrompt = ChatPromptTemplate.fromTemplate(
  "Show the number {vowelCount} two times."
);

// 複数変数のテンプレート
const translationPrompt = PromptTemplate.fromTemplate(
  "Translate '{text}' from {source_lang} to {target_lang}."
);

const formatted = await translationPrompt.format({
  text: "Hello, world!",
  source_lang: "English",
  target_lang: "Japanese",
});
```

### FewShotPromptTemplate統合

**パラメータの説明**

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| `examples` | `Array<Record<string, string>>` | question/answerオブジェクトの配列 |
| `examplePrompt` | `PromptTemplate` | 各例のフォーマット方法を定義 |
| `prefix` | `string` | 例の前に配置するコンテキストテキスト |
| `suffix` | `string` | 例の後の実際の質問（通常は入力変数含む） |
| `inputVariables` | `string[]` | 使用時に提供が必要な変数名 |

**実装例**

```typescript
import { FewShotPromptTemplate, PromptTemplate } from "@langchain/core/prompts";

const examples = [
  { question: "What is 2 + 2?", answer: "4" },
  { question: "What is the capital of France?", answer: "Paris" },
];

const examplePrompt = PromptTemplate.fromTemplate(
  "Question: {question}\nAnswer: {answer}"
);

const prefix = `You are an intelligent assistant designed to answer questions accurately and concisely.
Below are some examples of how to approach different types of questions.
Pay attention to whether follow-up questions are needed and how the final answer is presented.

Remember:
1. Determine if follow-up questions are needed.
2. If yes, ask the follow-up and provide an intermediate answer.
3. Always conclude with a final answer.

Here are some examples:`;

const prompt = new FewShotPromptTemplate({
  examples,
  examplePrompt,
  prefix,
  suffix: "Question: {input}",
  inputVariables: ["input"],
});

const formatted = await prompt.format({
  input: "What is the capital of Canada?",
});
```

### Vercel AI SDKへのプロンプトテンプレート統合

```typescript
import { prompt } from '../../lib/fewShotPrompt';
import { streamUI, getMutableAIState, generateId } from "ai/rsc";

export async function continueConversation(input: string, provider: string, model: string) {
  'use server';

  const supportedModel = getSupportedModel(provider, model);
  const history = getMutableAIState();

  // ユーザー入力をテンプレートにフォーマット
  const formattedPrompt = await prompt.format({ input });

  const result = await streamUI({
    model: supportedModel,
    messages: [...history.get(), { role: 'user', content: formattedPrompt }],
    text: ({ content, done }) => {
      if (done) {
        history.done([...history.get(), { role: 'assistant', content }]);
      }
      return <ChatBubble role="assistant" text={content} className="mr-auto border-none" />;
    },
  });

  return { id: generateId(), role: 'assistant', display: result.value };
}
```

---

## 4. ドキュメント取得（RAG）

**いつ使うか**: 社内ドキュメント・知識ベース・大量テキストに基づいた質問応答システムを構築するとき。

### ドキュメント処理パイプライン

```
Document ingestion（収集）
    ↓
Embedding generation（embedding生成）
    ↓
Vector storage（ベクトルストア保存）
    ↓
Retrieval（クエリ→検索→返答）
```

### テキストスプリッター一覧

| 名前 | 分割基準 | メタデータ付与 | 説明/ユースケース |
|------|---------|--------------|-----------------|
| **Recursive** | 特定文字（再帰） | Yes | テキストを意味的に結合したまま分割。**初回分割に推奨** |
| **HTML** | HTMLタグ | Yes | HTML構造に基づいて分割 |
| **Markdown** | Markdown記法 | Yes | Markdown記法に沿って分割 |
| **Code** | 言語固有の文字 | Yes | 各種プログラミング言語のシンタックスに基づく分割 |
| **Token** | トークン | No | トークン単位の分割（複数の計測方法あり） |
| **Character** | ユーザー定義文字 | No | 単純な文字指定による分割 |

**RecursiveCharacterTextSplitterの使用例**

```typescript
import { RecursiveCharacterTextSplitter } from "langchain/text_splitter";

const splitter = new RecursiveCharacterTextSplitter({
  chunkSize: 100,    // 各チャンクの最大文字数
  chunkOverlap: 20,  // チャンク間のオーバーラップ（コンテキスト維持）
});

const output = await splitter.createDocuments([text]);

/*
出力例:
[
  Document {
    pageContent: "Artificial Intelligence (AI) is intelligence",
    metadata: { id: 2 }
  },
  ...
]
*/
```

### ベクトルストア

```typescript
import { MemoryVectorStore } from "langchain/vectorstores/memory";
import { OpenAIEmbeddings } from "@langchain/openai";

// ベクトルストアへのドキュメント格納と類似検索
const vectorStore = await MemoryVectorStore.fromTexts(
  ["Hello world", "Bye bye", "hello nice world"],
  [{ id: 2 }, { id: 1 }, { id: 3 }],
  new OpenAIEmbeddings({ apiKey })
);

const results = await vectorStore.similaritySearch("hello world", 1);
/*
[
  Document {
    pageContent: "Hello world",
    metadata: { id: 2 }
  }
]
*/
```

**ベクトルストアの種類と選択基準**

| タイプ | 製品例 | 適用場面 |
|--------|--------|---------|
| 専用ベクトルDB | Pinecone, Milvus, Chroma | 本番環境・高パフォーマンス要件 |
| 汎用DB拡張 | PostgreSQL + pgvector | 既存DB資産活用 |
| インメモリ | MemoryVectorStore | 開発・プロトタイプ |

### ドキュメント検索（Retriever）

```typescript
import { StringOutputParser } from "@langchain/core/output_parsers";
import { formatDocumentsAsString } from "langchain/util/document";
import { RunnablePassthrough, RunnableSequence } from "@langchain/core/runnables";

const retriever = vectorStore.asRetriever();

const chain = RunnableSequence.from([
  {
    context: retriever.pipe(formatDocumentsAsString),
    question: new RunnablePassthrough(),
  },
  prompt,
  model,
  new StringOutputParser(),
]);

const answer = await chain.invoke({ question: "What is artificial intelligence?" });
```

**Retrieverチェーン使用時の注意点**

| 注意点 | 内容 |
|--------|------|
| **チェーンイベントの順序** | 各コンポーネントは前のステップの出力を期待する入力として受け取る |
| **引数のマッチング** | コンポーネント間の入出力の型・名前が一致している必要がある |
| **embeddingジェネレーターの一致** | 保存時と検索時で同じembeddingモデルを使用すること |

---

## 5. メモリ（会話履歴管理）

**いつ使うか**: 複数のメッセージにわたって文脈を保持したチャットアプリを構築するとき。

### ConversationChainの実装

```typescript
import { SystemMessage, HumanMessage, AIMessage } from "@langchain/core/messages";
import { ChatMessageHistory } from "langchain/stores/message/in_memory";
import { BufferMemory } from "langchain/memory";
import { ConversationChain } from "langchain/chains";
import { ChatGoogleGenerativeAI } from "@langchain/google-genai";

const llm = new ChatGoogleGenerativeAI({ apiKey });

// 過去のメッセージを初期化
const pastMessages = [
  new SystemMessage("You are a helpful assistant. Answer all questions to the best of your ability."),
  new HumanMessage("Hi! I'm Jim."),
];

const memory = new BufferMemory({
  chatHistory: new ChatMessageHistory(pastMessages),
});

const chain = new ConversationChain({ llm, memory });

const res1 = await chain.invoke({ input: "Can you give me an example of AI?" });
console.log(res1);
// { text: "Sure! An example of AI is a virtual assistant like Google Assistant." }

const res2 = await chain.invoke({ input: "What did I just ask you?" });
console.log(res2);
// { text: "You just asked for an example of artificial intelligence." }
```

**会話メモリ実装時の注意点**

| 注意点 | 内容 |
|--------|------|
| **プロンプト設定** | カスタムプロンプトには `{history}` と `{input}` 変数を含める必要がある |
| **メッセージ変換** | `SystemMessage`・`HumanMessage`・`AIMessage` の適切なクラスを使用 |
| **インスタンスの分離** | 異なるチェーン間でhistoryインスタンスを共有しない（混乱の原因） |

---

## 6. エージェント

**いつ使うか**: LLMが自律的に判断しながら複数のツールを組み合わせてタスクを達成する必要があるとき。

### LangChainエージェントの仕組み

エージェントはLLMを推論エンジンとして使用し、設定されたツールを判断して実行する自律的なソフトウェア。

**エージェントの意思決定サイクル**

```
ユーザー入力
    ↓
エージェントが状況を分析・意思決定
    ↓
ツール実行（Wikipedia検索・DB照会・API呼び出し等）
    ↓
実行結果を観察
    ↓
目標達成まで繰り返し
    ↓
最終的な応答をユーザーに返す
```

### エージェントの3つの構成要素

| 構成要素 | 説明 |
|---------|------|
| **ツールリスト** | エージェントが使用できるツールの一覧 |
| **AIモデル** | 推論と意思決定に使うLLM |
| **システムプロンプト** | エージェントの動作・目標・制約を定義 |

### ReActエージェントの実装

```typescript
import { WikipediaQueryRun } from "@langchain/community/tools/wikipedia_query_run";
import { createReactAgent } from "langchain/agents";
import { ChatPromptTemplate, MessagesPlaceholder } from "@langchain/core/prompts";
import { HumanMessage } from "@langchain/core/messages";
import { ChatOpenAI } from "@langchain/openai";

const tools = [new WikipediaQueryRun({
  topKResults: 3,
  maxDocContentLength: 4000,
  handleValidationError: (error) => console.error('Search validation error:', error)
})];

const AGENT_SYSTEM_TEMPLATE = `You are a helpful AI assistant specializing in technical queries and web technologies.
When using WikipediaQueryRun for searches:
Prioritize technical documentation and standards
Cross-reference information from multiple sources
Format code examples using markdown`;

const prompt = ChatPromptTemplate.fromMessages([
  ['system', AGENT_SYSTEM_TEMPLATE],
  ['human', '{input}'],
  new MessagesPlaceholder('agent_scratchpad'),
]);

const model = new ChatOpenAI({ openAIApiKey: process.env.OPENAI_API_KEY });

const agent = createReactAgent({ llm: model, tools, prompt });

const output = await agent.invoke({
  messages: [new HumanMessage("Explain what Mount Everest is")],
});
```

### エージェント使用時の注意点

| 注意点 | 内容 |
|--------|------|
| **コンテキスト長の制限** | ツールの名前・説明・引数が全てトークン数にカウントされる |
| **遅延と伝播効果** | 複数レイヤー経由でデータが流れるため各ステップが遅延を追加する |
| **ツールの説明品質** | 説明が不明確だとエージェントがツールを誤用する可能性がある |

### Vercel AI SDK連携（エージェントストリーミング）

```typescript
import { createStreamableUI, getMutableAIState, generateId } from "ai/rsc";

export async function continueConversation(input: string) {
  const aiState = getMutableAIState();
  const stream = createStreamableUI();

  // エージェントのストリームを取得
  const agentStream = await agent.stream({
    messages: [new HumanMessage(input)],
  });

  let textContent = '';

  for await (const chunk of agentStream) {
    if (chunk.messages && chunk.messages.length > 0) {
      const lastMessage = chunk.messages[chunk.messages.length - 1];
      if (typeof lastMessage.content === 'string') {
        textContent = lastMessage.content;
        stream.update(
          <ChatBubble role="assistant" text={textContent} className="mr-auto border-none" />
        );
      }
    }
  }

  stream.done();
  aiState.done({
    ...aiState.get(),
    messages: [
      ...aiState.get().messages,
      { id: generateId(), role: 'assistant', content: textContent },
    ],
  });

  return { id: generateId(), display: stream.value, role: 'assistant' };
}
```

---

## 7. 高度な機能

**いつ使うか**: より複雑なワークフローや条件分岐・ループを持つAIシステムを構築するとき。

### LCEL（LangChain Expression Language）

LCELはRunnablesから既存のチェーンを構築するための**宣言的アプローチ**。

#### コンポジションプリミティブ

| プリミティブ | 説明 | コード例 |
|------------|------|---------|
| **RunnableSequence** | Runnablesを逐次チェーン（前の出力が次の入力） | `new RunnableSequence({ first, last })` |
| **RunnableParallel** | 複数のRunnablesを同じ入力で並行実行 | `new RunnableParallel({ key1: r1, key2: r2 })` |
| **RunnableLambda** | 汎用JS関数をRunnable化するプリミティブ | `RunnableLambda.from((input) => input)` |

```typescript
import { RunnableSequence, RunnableParallel, RunnableLambda } from "@langchain/core/runnables";

// 逐次実行
const sequential = new RunnableSequence({
  first: runnable1,
  last: runnable2,
});

// 並行実行
const parallel = new RunnableParallel({
  summary: summaryRunnable,
  keywords: keywordRunnable,
});

// カスタム関数のRunnable化
const customStep = RunnableLambda.from((input: { text: string }) => ({
  processed: input.text.toUpperCase(),
}));
const chain = customStep.pipe(sequential);
```

### LangGraph

LangGraphはLangChain上に構築された**グラフベースの状態管理フレームワーク**。ループや条件分岐を持つ複雑なマルチエージェントシステムに最適。

#### LCELとLangGraphの使い分け

| 比較軸 | LCEL | LangGraph |
|--------|------|-----------|
| **適用タスク** | DAG（有向非巡回グラフ）・線形ワークフロー | サイクル・条件分岐・ループを持つワークフロー |
| **状態管理** | 基本的な入出力フロー | 複雑な状態を持つアプリケーション |
| **ユースケース例** | RAGパイプライン・固定ステップ処理 | チャットボット・ネガティブフィードバック後の再試行 |
| **複雑度** | 低〜中 | 高 |
| **コスト** | 低 | 高（オーバーヘッドあり） |

**LangGraphの典型的ユースケース**

```typescript
// 例: 検索に失敗したときクエリを言い換えて再試行するエージェント
// → LCELでは表現困難な条件分岐ループ → LangGraphが最適

import { StateGraph, END } from "@langchain/langgraph";

const workflow = new StateGraph({
  channels: {
    messages: { value: (a, b) => a.concat(b), default: () => [] },
    retryCount: { value: (a, b) => b ?? a, default: () => 0 },
  }
});

// ノードの追加（各ステップ）
workflow.addNode("search", searchNode);
workflow.addNode("refine_query", refineQueryNode);

// 条件分岐の追加
workflow.addConditionalEdges("search", (state) =>
  state.searchFailed && state.retryCount < 3 ? "refine_query" : END
);
```

---

## 8. Vercel AI SDK連携パターン

**いつ使うか**: LangChainの高度なチェーン機能とVercel AI SDKのUI統合を組み合わせた本番アプリを構築するとき。

### 統合アーキテクチャの判断基準

| シナリオ | 推奨アプローチ |
|---------|--------------|
| シンプルなプロンプト→レスポンス | Vercel AI SDKのみ（`generateText`・`streamText`） |
| ドキュメント検索・RAG | LangChain（retriever）+ Vercel AI SDK（UI） |
| 複数API連鎖・複雑なチェーン | LangChain（chains）+ Vercel AI SDK（streaming UI） |
| 自律エージェント | LangChain（agents）+ Vercel AI SDK（createStreamableUI） |
| ループ・条件分岐ワークフロー | LangGraph + Vercel AI SDK |

### 統合パターン1: PromptTemplateの統合

LangChainのFewShotPromptTemplateでフォーマットし、Vercel AI SDKのstreamUIで描画：

```typescript
// lib/fewShotPrompt.ts
import { FewShotPromptTemplate, PromptTemplate } from "@langchain/core/prompts";

export const prompt = new FewShotPromptTemplate({
  examples: [/* ... */],
  examplePrompt: PromptTemplate.fromTemplate("Question: {question}\nAnswer: {answer}"),
  prefix: "You are an intelligent assistant...",
  suffix: "Question: {input}",
  inputVariables: ["input"],
});
```

```typescript
// app/actions.tsx
import { prompt } from '../../lib/fewShotPrompt';
import { streamUI } from "ai/rsc";

export async function continueConversation(input: string) {
  'use server';
  const formattedPrompt = await prompt.format({ input });
  const result = await streamUI({
    model: supportedModel,
    messages: [{ role: 'user', content: formattedPrompt }],
    text: ({ content }) => <ChatBubble text={content} />,
  });
  return { display: result.value };
}
```

### 統合パターン2: チェーンコールの統合

LangChainのchain.stream()をcreateStreamableUIに繋ぐ：

```
ユーザー入力
    ↓
chain.stream({ city }) → LangChainストリームオブジェクト
    ↓
createStreamableUI → リアルタイムにUIを更新
    ↓
stream.done() → 処理完了
```

**注意**: LangChainはVercel AI SDKの言語モデル仕様のアダプターを提供していないため、`streamUI`と`chain.stream()`は直接組み合わせられない。`createStreamableUI`を経由することで対応できる。

### 統合時に使用するVercel AI SDKの関数

| 関数 | 説明 | LangChain統合での使用場面 |
|------|------|------------------------|
| `createStreamableUI()` | リアルタイムUI更新ストリームを生成 | チェーン/エージェントの出力をUIに流す |
| `getMutableAIState()` | サーバー側の会話状態を管理 | 会話履歴の保持 |
| `generateId()` | ユニークIDを生成 | メッセージIDの付与 |
| `streamUI()` | UIコンポーネントをストリーム | PromptTemplateと組み合わせる場合 |
