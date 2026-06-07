# AIアプリのテストとデバッグ

---

## 1. Next.js AIアプリのデバッグ

**いつ使うか**: Next.jsのレンダリング・状態管理・パフォーマンス問題を体系的に診断するとき。

### 問題の3大カテゴリと対応策

| カテゴリ | 主な症状 | 診断ツール |
|---|---|---|
| **レンダリング問題** | 空白画面・エラーオーバーレイ・スクロール不具合 | React DevTools・エラーバウンダリ |
| **クライアント/サーバー問題** | ストリーミング停止・デプロイ後の動作相違 | 構造化ログ（Pino）・Node.js Inspector |
| **パフォーマンス問題** | 応答遅延・メモリリーク・スラッグ感 | ネットワークモニター・ヒーププロファイラー |

### レンダリング問題のデバッグ

#### スクロール動作の問題

```tsx
// ❌ 問題: スクロールアンカーの配置が誤っている
<div ref={messageEndRef} />
<ChatList messages={conversation} />

// ✅ 正しい配置（リストの後に置く）
<ChatList messages={conversation} />
<div ref={messageEndRef} />
```

```tsx
// ❌ 問題: ストリーミング中にconversation参照が変わらない
setConversation([...conversation, newMessage]);  // 同一参照になる場合がある

// ✅ 関数型更新で新しい参照を保証
setConversation(prev => [...prev, newMessage]);
```

#### ストリーミング問題の対処

```typescript
// Next.js App Routerでストリーミングを有効化
export const dynamic = "force-dynamic";
export const maxDuration = 30;

// Vercelデプロイ時のキャッシュ無効化
import { unstable_noStore as noStore } from "next/cache";

export default async function Page() {
  noStore();
  // ...
}
```

### クライアント/サーバー問題のデバッグ

#### 構造化ログの実装（Pino）

```typescript
import pino from "pino";

export const logger = process.env.NODE_ENV === "production"
  ? pino({ level: "warn" })
  : pino({
      transport: {
        target: "pino-pretty",
        options: { colorize: true },
      },
      level: "debug",
    });
```

**ログを仕込む場所**:
- API呼び出しの前後
- 状態変更の前後
- AI応答の受信時

### 状態管理のデバッグ

- AIロジックとUIコンポーネントを分離する（テスタビリティ向上）
- Vercel AI SDKのUI State / AI Stateを明確に区分する
- `getMutableAIState()` / `getAIState()` の使い分けを確認する

### パフォーマンス監視

#### ネットワーク監視
- ブラウザのネットワークタブでAPIコールのタイミングとサイズを確認する
- HTTPプロキシでサーバー/クライアント間のデータ転送を捕捉する

#### メモリプロファイリング
- タイマーやコールバックの未解放（ダングリングリファレンス）を検出する
- 長い会話スレッドでのメモリ蓄積を確認する

```bash
# Node.js側のヒーププロファイル生成
node --heap-prof node_modules/next/dist/bin/next dev
# → .heapprofileファイルを Chrome DevTools Memory タブで分析
```

#### Performance.now() による計測

```typescript
import { AIPerformanceProfiler } from "@/lib/profiler";

const profiler = new AIPerformanceProfiler();
profiler.startOperation("initialAIRequest");

// API呼び出し

const metrics = profiler.endOperation("completeAIRequest");
console.log("パフォーマンス指標:", {
  totalDuration: metrics.duration,
  avgChunkLatency: metrics.streamMetrics.avgChunkLatency,
});
```

---

## 2. Vercel AI SDKのトラブルシューティング

**いつ使うか**: AIプロバイダーエラー・トークン制限・レート制限の問題を解決するとき。

### 問題の分類

```
Vercel AI問題
├─ エラーステート・応答問題
│   ├─ プロバイダー互換性問題（APIの予告なし変更）
│   ├─ モデル機能ミスマッチ（ドキュメントと実装の乖離）
│   └─ ランタイムエラー（空応答・コンテンツポリシー違反）
└─ トークン制限・APIエラー
    ├─ トークン超過
    ├─ レートリミット（HTTP 429）
    └─ モデル可用性問題
```

### よくあるエラーと対処

| エラー | 原因 | 対処 |
|---|---|---|
| 空のレスポンス | モデルがサイレントに失敗 | エラーハンドリング強化・ログ追加 |
| HTTP 429 | レートリミット超過 | maxRetries設定・指数バックオフ |
| ストリーミング停止 | Vercelタイムアウト・キャッシュ | dynamic/noStore設定確認 |
| リージョンロック | 機能が地域で利用不可 | プロバイダーのドキュメント確認 |

### エラーハンドリングの実装

```typescript
import { AIErrorTracker } from "@/lib/error-tracking";

export async function continueConversation(
  input: string,
  provider: string,
  model: string
) {
  try {
    // ...
  } catch (error) {
    const errorData = await AIErrorTracker.trackError(error, {
      provider,
      model,
      input,
    });

    const userError = AIErrorTracker.createUserFacingError(errorData);

    return {
      id: userError.requestId,
      role: "assistant",
      display: (
        <ChatBubble
          role="error"
          text={`${userError.message} (Request ID: ${userError.requestId})`}
        >
          <button onClick={retryAction}>再試行</button>
        </ChatBubble>
      ),
    };
  }
}
```

### トークン管理戦略

| 戦略 | 実装 | 効果 |
|---|---|---|
| **maxTokens制限** | `streamText({ maxTokens: 100 })` | 応答サイズ上限を設定 |
| **ローリングコンテキスト** | 直近10メッセージのみ保持 | コンテキストウィンドウ内に収める |
| **トークンカウント監視** | `js-tiktoken`ライブラリ | トークン使用量を事前計算（OpenAIモデルのみ対応） |

```typescript
// ローリングコンテキストの実装
while (messageHistory.length > 10) {
  messageHistory.shift(); // 最古メッセージを削除
}

const response = await streamText({
  model: supportedModel,
  messages: messageHistory,
  maxTokens: 512,
  maxRetries: 3, // 一時的エラー（429等）のリトライ
});
```

### モデルフォールバック

`ai-fallback` ライブラリはAIプロバイダーが利用不可になった場合に自動的にリクエストを代替プロバイダーへ切り替えるフォールバック機能を提供する。まずパッケージをインストールする:

```bash
npm install ai-fallback
```

```typescript
import { createFallback } from "ai-fallback";
import { createGoogleGenerativeAI } from "@ai-sdk/google";
import { createOpenAI } from "@ai-sdk/openai";

const supportedModel = createFallback({
  models: [
    createGoogleGenerativeAI({ apiKey: googleAPIKey })("gemini-2.0-flash"),
    createOpenAI({ apiKey: openAPIKey })("gpt-3.5-turbo"),
  ],
  onError: (error, modelId) => {
    console.error(`Model ${modelId} failed:`, error);
  },
  modelResetInterval: 60000, // 60秒後にプライマリモデルへ復帰
  shouldRetryThisError: (error) =>
    [429, 500].includes(error.statusCode),
});
```

### 公式バグトラッカーの確認

解決できない問題が発生した場合は `https://github.com/vercel/ai/labels/bug` を確認する。

---

## 3. LangChain.jsのトラブルシューティング

**いつ使うか**: LangChain.jsのチェーン実行エラー・モデル統合問題を診断するとき。

### 問題の分類と解決ステップ

```
LangChain.js問題
├─ チェーン実行エラー
│   ├─ try/catch + ロバストエラーハンドリング
│   ├─ verbose: true + デバッグチェーン追加
│   └─ コールバックハンドラーの活用
└─ 統合エラー
    ├─ ベクトル次元ミスマッチ確認
    └─ 未対応機能の代替手段を確認
```

### チェーン実行エラーのデバッグ

```typescript
// try/catchでチェーン実行をラップ
const executeChain = async (input: string) => {
  try {
    const result = await chainGoogle.invoke({ question: input });
    console.log("Result:", result);
  } catch (error) {
    console.error("Chain execution failed:", error);
  }
};

// verbose: trueで詳細ログを有効化
const googleModel = new ChatGoogleGenerativeAI({
  apiKey,
  verbose: true, // すべての入出力をログ出力
});
```

### デバッグチェーンの追加

```typescript
import { RunnableSequence } from "@langchain/core/runnables";

const debugChain = (input: unknown) => {
  console.log("Execution Context:", input);
  return input;
};

const finalChain = RunnableSequence.from([
  debugChain,  // 各ステップの入力を確認
  mainChain,
]);
```

### コールバックハンドラー

```typescript
import { ConsoleCallbackHandler } from "@langchain/core/tracers/console";

const handler = new ConsoleCallbackHandler();
const model = new ChatGoogleGenerativeAI({
  apiKey,
  callbacks: [handler],
});
```

**利用可能なコールバックイベント**:

| イベント | トリガー | メソッド名 |
|---|---|---|
| Chain start | チェーン開始時 | handleChainStart |
| Chain end | チェーン完了時 | handleChainEnd |
| Chain error | チェーンエラー時 | handleChainError |
| LLM start | LLM呼び出し開始時 | handleLlmStart |
| LLM new token | 新トークン生成時 | handleLlmNewToken |
| LLM end | LLM完了時 | handleLlmEnd |

### モデル統合エラーの対処

#### ベクトル次元ミスマッチ

```typescript
// ❌ 問題: インデックス作成と検索で異なるモデルを使用
// インデックス作成時
const embeddings = new GoogleGenerativeAIEmbeddings({
  model: "gemini-embedding-exp-03-07"
});

// 検索時（次元が違う → エラー）
const differentEmbeddings = new GoogleGenerativeAIEmbeddings({
  model: "models/embedding-001"
});
```

**ルール**: インデックス作成と検索は**必ず同じ埋め込みモデル**を使用する。

#### 非対応機能の検出

```typescript
// エラー例: ChatGoogleGenerativeAIはjsonModeをサポートしない
const modelWithParser = model.withStructuredOutput(format, {
  method: "jsonMode", // → Error: only "functionCalling" supported
});

// ✅ 修正: methodオプションを削除
const modelWithParser = model.withStructuredOutput(format);
```

---

## 4. AIアプリのテスト戦略

**いつ使うか**: Next.js + Vercel AI SDK + LangChain.jsを使ったAIアプリのテスト設計をするとき。

### テストタイプの使い分け

| テスト種別 | 対象 | コスト | 信頼度 |
|---|---|---|---|
| **ユニットテスト** | 個別関数・コンポーネントロジック | 低い | モック依存で限定的 |
| **統合テスト** | APIルート・コンポーネント間連携 | 中程度 | より現実的 |
| **E2Eテスト** | 実際のAI応答を含む完全フロー | 高い | 最も現実的 |

### モッキングの判断基準

**モックすべき対象**:
- 入力サニタイゼーション
- レスポンス処理ロジック
- エラーハンドリング
- 基本的なフロー制御

**モックしてはいけない対象**:
- 複雑なセンチメント分析（実モデルが必要）
- パフォーマンス特性の検証
- モデルの信頼性テスト

### LLMモッキングの注意点

```typescript
// ❌ 過度に詳細なモック（内部実装への依存）
const mockLLMResponse = {
  choices: [{ text: "Hello", finish_reason: "stop", logprobs: {...} }],
};

// ✅ 本質的な情報のみのモック（保守性が高い）
const simplifiedMockResponse = {
  text: "Hello world",
  isComplete: true,
};
```

---

## 5. Vercel AI SDKのテストパターン

**いつ使うか**: Vercel AI SDKの関数を実際のAPIコストなしにテストするとき。

### MockLanguageModelV1

```typescript
import { generateText } from "ai";
import { MockLanguageModelV1 } from "ai/test";

describe("テキスト生成テスト", () => {
  test("モックモデルから事前定義テキストを返す", async () => {
    const result = await generateText({
      model: new MockLanguageModelV1({
        doGenerate: async () => ({
          rawCall: { rawPrompt: null, rawSettings: {} },
          finishReason: "stop",
          usage: { promptTokens: 10, completionTokens: 20 },
          text: "Hello, world!",
        }),
      }),
      prompt: "Hello, test!",
    });

    expect(result.text).toBe("Hello, world!");
  });
});
```

### simulateReadableStream（ストリーミングテスト）

```typescript
import { streamText } from "ai";
import { MockLanguageModelV1, simulateReadableStream } from "ai/test";

const result = streamText({
  model: new MockLanguageModelV1({
    doStream: async () => ({
      stream: simulateReadableStream({
        chunks: [
          { type: "text-delta", textDelta: "This is " },
          { type: "text-delta", textDelta: "a test " },
          { type: "text-delta", textDelta: "of streaming." },
          {
            type: "finish",
            finishReason: "stop",
            usage: { completionTokens: 15, promptTokens: 5 },
          },
        ],
      }),
      rawCall: { rawPrompt: null, rawSettings: {} },
    }),
  }),
  prompt: "Start streaming!",
});
```

### continueConversation Server Actionのテスト

```typescript
import { continueConversation } from "../src/actions";
import { getSupportedModel } from "../src/utils";
import { MockLanguageModelV1 } from "ai/test";

jest.mock("../src/utils", () => ({
  getSupportedModel: jest.fn(),
}));

describe("continueConversation", () => {
  it("モデルが生成したメッセージと履歴を返す", async () => {
    const mockText = "Hello, world!";
    (getSupportedModel as jest.Mock).mockReturnValue(
      new MockLanguageModelV1({
        doGenerate: async () => ({
          rawCall: { rawPrompt: null, rawSettings: {} },
          finishReason: "stop",
          usage: { promptTokens: 10, completionTokens: 20 },
          text: mockText,
        }),
      })
    );

    const response = await continueConversation(
      "Hello",
      [],
      "someProvider",
      "someModel"
    );

    expect(getSupportedModel).toHaveBeenCalledWith("someProvider", "someModel");
    expect(response.newMessage).toEqual(mockText);
  });
});
```

---

## 6. LangChain.jsのテストパターン

**いつ使うか**: LangChain.jsのチェーン・RAGシステム・エージェントをコストなしにテストするとき。

### LangChain.js テストヘルパー一覧

| ヘルパークラス | 説明 |
|---|---|
| **FakeLLM** | 事前定義応答を返す言語モデルモック |
| **FakeStreamingLLM** | ストリーミング応答をシミュレート |
| **FakeChatModel** | チャット形式のモック |
| **FakeStreamingChatModel** | チャットストリーミングのモック |
| **FakeRetriever** | 固定ドキュメントを返すRetrieverモック |
| **FakeEmbeddings** | 固定値を返す埋め込みモック |
| **FakeTool** | ツール動作をシミュレート |
| **FakeTracer** | トレースデータを収集するモックトレーサー |
| **FakeSplitIntoListParser** | カンマ区切り値をパースするテスト用パーサー |

### RAGシステムのユニットテスト

```typescript
import { FakeLLM, FakeRetriever } from "@langchain/core/utils/testing";
import { RAGSystem } from "../lib/RAGSystem";

describe("RAGSystem", () => {
  let ragSystem: RAGSystem;

  beforeEach(() => {
    ragSystem = new RAGSystem("test_api_key");

    // FakeRetrieverで文書取得をシミュレート
    ragSystem.retriever = new FakeRetriever({
      output: [
        { pageContent: "AIに関するコンテキスト情報。" },
        { pageContent: "機械学習に関するコンテキスト情報。" },
      ],
    });

    // FakeLLMで応答生成をシミュレート
    ragSystem.llm = new FakeLLM({
      response: "提供されたコンテキストに基づく回答。",
    });
  });

  it("Retrieverが未初期化の場合エラーをスローする", async () => {
    ragSystem.retriever = null;
    await expect(ragSystem.performRAG("AIとは？")).rejects.toThrow(
      "Retriever not initialized."
    );
  });

  it("回答とソースドキュメントを返す", async () => {
    const result = await ragSystem.performRAG("AIとは？");
    expect(result.answer).toEqual("提供されたコンテキストに基づく回答。");
    expect(result.sourceDocuments).toHaveLength(2);
  });
});
```

### 依存性注入によるテスタビリティ向上

```typescript
// ❌ テストしにくい設計（内部でインスタンス化）
class RAGSystem {
  private retriever = new HNSWRetriever(...);
  private llm = new ChatGoogleGenerativeAI(...);
}

// ✅ 依存性注入（モックに差し替えやすい）
class RAGSystem {
  constructor(
    private apiKey: string,
    private retriever?: BaseRetriever,
    private llm?: BaseLanguageModel
  ) {}
}

// テスト時
const ragSystem = new RAGSystem("test_key", fakeRetriever, fakeLLM);
```

### テストコマンド

```bash
# Vercel AI SDKテスト
cd ch08/chat-testing
npm run test:vercel:ai

# LangChain.jsテスト
npm run test

# 全テスト
npm run test -w ch08/chat-testing
```
