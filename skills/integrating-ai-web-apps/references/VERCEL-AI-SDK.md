# Vercel AI SDK 詳細リファレンス

> Vercel AI SDK（`ai` パッケージ）を使ったAI統合の実践的なリファレンス。
> プロバイダー抽象化・ストリーミング・RSC・状態管理・構造化データ・ツール呼び出しを網羅する。

---

## 0. SDK導入判断

**いつ使うか**: Vercel AI SDKを使うべきか、プロバイダーAPIへの直接呼び出しで十分かを判断するとき。

### 直接API呼び出し vs SDK利用の判断テーブル

| 観点 | 直接API呼び出し（fetch/axios） | Vercel AI SDK |
|------|----------------------------|--------------|
| **プロバイダー** | 単一プロバイダーに固定 | 複数プロバイダーを統一インターフェースで管理 |
| **ストリーミング** | 自前実装が必要（SSE/WebSocket処理） | `streamText` / `toDataStreamResponse()` で即対応 |
| **React統合** | カスタムhookの実装が必要 | `useChat` / `useCompletion` で状態管理込み |
| **状態管理** | 会話履歴を手動で管理 | AI State / UI State の分離パターンが組み込み |
| **型安全性** | OpenAPI生成型など自前整備 | TypeScript型が提供済み |
| **学習コスト** | プロバイダーAPIの仕様把握が必要 | SDK APIを覚えるだけで複数対応 |
| **適した場面** | 単純な1回限りのAPI呼び出し、プロトタイプ | チャット・ストリーミング・マルチプロバイダー対応の本番アプリ |

> **判断の目安**: ストリーミング・マルチターン会話・プロバイダー切替えのいずれかが必要なら SDK を選択。シンプルな単発のテキスト生成であれば直接API呼び出しでも十分。

---

## 1. プロバイダー抽象化

**いつ使うか**: 特定AIプロバイダーへの依存を避けたいとき、または将来の切替えを見据えた設計をするとき。

Vercel AI SDKは、異なるAIプロバイダーを**統一インターフェース**で扱うための抽象化レイヤーを提供する。
アプリケーションのコアロジックを変えずにプロバイダーを切り替えられるのが最大の利点。

### 主要機能一覧

| 機能 | 説明 |
|------|------|
| **Provider abstraction** | 統一インターフェースで複数プロバイダーを切り替え可能 |
| **Streaming responses** | プロバイダー横断の一貫したストリーミングAPI |
| **State management** | 会話履歴の集中管理、UI/サーバー間同期 |
| **React Server Components** | サーバーでUIをレンダリングしクライアントへストリーミング |
| **Structured data generation** | スキーマ準拠の構造化データ生成 |
| **React hooks** | `useChat` / `useCompletion` / `useAssistant` による統合 |

### サポートプロバイダー一覧

| プロバイダー | パッケージ |
|-------------|-----------|
| OpenAI | `@ai-sdk/openai` |
| Anthropic | `@ai-sdk/anthropic` |
| Google Generative AI | `@ai-sdk/google` |
| Google Vertex | `@ai-sdk/google-vertex` |
| Mistral | `@ai-sdk/mistral` |
| LLaMA.cpp（コミュニティ） | `llamacpp-ai-provider` |
| Ollama（コミュニティ） | `ollama-ai-provider` |

> SDKはLanguage Model Specificationをオープンソースで公開しており、コミュニティによる追加プロバイダー実装が可能。

### インストール

```bash
# コアSDK
npm install ai

# プロバイダーパッケージ（必要なものを選択）
npm install @ai-sdk/google
npm install @ai-sdk/openai
npm install @ai-sdk/anthropic
```

### プロバイダー初期化パターン

```typescript
import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { createOpenAI } from '@ai-sdk/openai';

// Google Gemini
const google = createGoogleGenerativeAI({
  apiKey: process.env.GEMINI_API_KEY || '',
});

// OpenAI
const openai = createOpenAI({
  apiKey: process.env.OPENAI_API_KEY || '',
});

// 使用例：同じgenerateText関数で異なるプロバイダーを利用
const googleResponse = await generateText({
  model: google('gemini-2.0-flash'),
  prompt: 'Hello',
});

const openaiResponse = await generateText({
  model: openai('gpt-4'),
  prompt: 'Hello',
});
```

### アーキテクチャ：Abstract Factory パターン

SDKは**Abstract Factory パターン**を採用している。

```
generateText / streamText（Abstract Factory）
        ↓
各プロバイダー（Concrete Factory）
  @ai-sdk/openai → OpenAIModel
  @ai-sdk/anthropic → AnthropicModel
        ↓
Language Model Specification（Abstract Product）
  generate(prompt) / stream(prompt)
```

プロバイダーを増やしても既存コードは変更不要。新しいプロバイダーパッケージを追加するだけで利用可能になる。

---

## 2. ストリーミングレスポンス

**いつ使うか**: ユーザー体験を向上させたいとき。LLMの応答速度（約21トークン/秒）を考慮すると、ほぼすべての会話型アプリで採用すべき。

### ストリーミングの仕組み

1. クライアントがリクエストを送信
2. サーバーが処理を開始し、生成しながらチャンクを逐次送信（Chunked Transfer Encoding）
3. クライアントがチャンクを受信し、UIをインクリメンタルに更新
4. 最終チャンクでストリーム終了を通知

### `generateText` vs `streamText` 使い分け

| 関数 | 用途 | 戻り値 |
|------|------|--------|
| `generateText` | 完全なレスポンスを一括取得（メール下書き、要約など非インタラクティブ） | `Promise<{ text: string }>` |
| `streamText` | インクリメンタルにレスポンスを受信（チャット、リアルタイム表示） | `AsyncIterable<TextStream>` |

### `generateText` の基本パターン

```typescript
import { generateText } from 'ai';
import { google } from '@ai-sdk/google';

const { text } = await generateText({
  model: google('gemini-2.0-flash'),
  messages: [
    {
      role: 'system',
      content: 'You are a helpful assistant.',
    },
    { role: 'user', content: userMessage },
  ],
  maxTokens: 512,
});
```

### `streamText` の基本パターン

```typescript
import { streamText } from 'ai';
import { createGoogleGenerativeAI } from '@ai-sdk/google';

const model = createGoogleGenerativeAI({
  apiKey: process.env.GEMINI_API_KEY || '',
});

const { textStream } = await streamText({
  model: model('gemini-2.0-flash'),
  prompt: 'Generate a story about a robot.',
});

// for await...of でインクリメンタルに処理
for await (const textPart of textStream) {
  process.stdout.write(textPart);
}
```

### API Route でのストリーミング実装

```typescript
import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { streamText } from 'ai';

export const dynamic = 'force-dynamic';

const model = createGoogleGenerativeAI({
  apiKey: process.env.GEMINI_API_KEY || '',
});

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = await streamText({
    model: model('gemini-2.0-flash'),
    maxTokens: 512,
    messages: [
      {
        role: 'system',
        content: 'You are a helpful assistant.',
      },
      ...messages,
    ],
  });

  // DataStream に変換してレスポンスとして返す
  const stream = result.toDataStream();
  return new Response(stream, {
    status: 200,
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}
```

### `streamText` の追加機能

| 機能 | 説明 |
|------|------|
| `onFinish` コールバック | モデルが生成完了・全ツール実行後に呼び出される。テキスト・ツール呼び出し結果・終了理由・使用量を受け取る |
| `result.toAIStream()` | AIストリームに変換 |
| `result.toDataStream()` | DataStreamに変換（useChat連携用） |
| `result.text` | 完全なテキストを解決するPromise |
| `result.toolCalls` | ツール呼び出し結果のPromise |
| `result.finishReason` | 終了理由のPromise |

---

## 3. React Hooks

**いつ使うか**: Reactコンポーネントにストリーミング対応のAI機能を組み込むとき。

### 3つのHook 使い分けテーブル

| Hook | 用途 | 入力 | 状態管理 |
|------|------|------|---------|
| `useChat` | 会話型チャット（コンテキスト付き） | メッセージ履歴 | 複数ターンの会話履歴を管理 |
| `useCompletion` | シングルプロンプト補完 | 単一テキスト | 1回の補完のみ、履歴なし |
| `useObject` | 構造化データのストリーミング生成 | プロンプト + Zodスキーマ | ストリーミングで部分的オブジェクトを逐次更新 |
| `useAssistant` | OpenAI Assistants API連携 | スレッドID | Assistants API固有の状態管理 |

### `useChat` の基本パターン

```typescript
import { useChat } from 'ai/react';

export default function Chat() {
  const {
    messages,        // メッセージ履歴
    input,           // 現在の入力値
    handleInputChange, // input変更ハンドラー
    handleSubmit,    // フォーム送信ハンドラー
    isLoading,       // ローディング状態
  } = useChat({ api: '/api/chat' });

  return (
    <div>
      {messages.map((message) => (
        <div key={message.id}>
          <strong>{message.role}:</strong> {message.content}
        </div>
      ))}
      <form onSubmit={handleSubmit}>
        <input
          value={input}
          placeholder="メッセージを入力..."
          onChange={handleInputChange}
        />
        <button type="submit" disabled={isLoading}>送信</button>
      </form>
    </div>
  );
}
```

### `useChat` に追加データを渡すパターン

```typescript
const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat({
  api: '/api/chat',
  body: {
    provider: selectedProvider,  // 追加パラメーター
    model: selectedModel,
  },
});
```

### `useCompletion` の基本パターン

```typescript
import { useCompletion } from 'ai/react';

export default function Completion() {
  const { completion, input, handleInputChange, handleSubmit } = useCompletion({
    api: '/api/completion',
  });

  return (
    <form onSubmit={handleSubmit}>
      <input value={input} onChange={handleInputChange} />
      <p>補完結果: {completion}</p>
    </form>
  );
}
```

---

## 4. マルチプロバイダー対応

**いつ使うか**: 複数のAIプロバイダーを選択的に切り替えたいとき、またはコスト・パフォーマンス最適化のためにプロバイダーを動的に選択したいとき。

### プロバイダー切替え戦略

| 戦略 | 説明 | 適用場面 |
|------|------|---------|
| **設定ベース** | コード内でサポートプロバイダーを定義 | 限定的なプロバイダーセット |
| **外部設定ファイル** | YAML/JSONで設定を外部化 | 柔軟な管理が必要な場合 |
| **UIセレクター** | ユーザーがUIでプロバイダーを選択 | エンドユーザーに選択肢を与える場合 |
| **動的ルーティング** | コスト・レイテンシーに基づいて自動選択 | 高可用性・コスト最適化 |

### プロバイダー選択ロジックの実装例

```typescript
import { createOpenAI } from '@ai-sdk/openai';
import { createGoogleGenerativeAI } from '@ai-sdk/google';

const supportedProviders = {
  openai: {
    constructor: createOpenAI,
    models: ['gpt-3.5-turbo', 'gpt-4'],
  },
  gemini: {
    constructor: createGoogleGenerativeAI,
    models: ['models/gemini-2.0-flash'],
  },
};

export function getSupportedModel(provider: string, model: string) {
  const providerConfig = supportedProviders[provider as keyof typeof supportedProviders];

  if (!providerConfig) {
    throw new Error(`Unsupported provider: ${provider}`);
  }

  if (!providerConfig.models.includes(model)) {
    throw new Error(`Unsupported model: ${model} for provider: ${provider}`);
  }

  const apiKey = process.env[`${provider.toUpperCase()}_API_KEY`];
  if (!apiKey) {
    throw new Error(`Missing API key for provider: ${provider}`);
  }

  const providerInstance = providerConfig.constructor({ apiKey });
  return providerInstance(model);
}
```

### API Routeでの使用例

```typescript
import { streamText } from 'ai';
import { getSupportedModel } from './utils';

export async function POST(req: Request) {
  const { messages, provider, model } = await req.json();

  const result = await streamText({
    model: getSupportedModel(provider, model),
    maxTokens: 512,
    messages,
  });

  return new Response(result.toDataStream());
}
```

---

## 5. マルチメディアコンテンツ（Vision）

**いつ使うか**: テキストだけでなく画像も含むマルチモーダルな入力を処理するとき（画像説明、視覚的Q&A、画像解析など）。

### Vision対応モデル

| プロバイダー | モデル | Vision対応 |
|-------------|--------|-----------|
| OpenAI | GPT-4o, GPT-4 Turbo | ✅ |
| Google | Gemini 2.0 Flash, Gemini Pro Vision | ✅ |
| Anthropic | Claude 3系 | ✅ |

### 画像入力フロー

1. ユーザーが画像をアップロード（`FileReader` API等でBase64エンコード）
2. フロントエンドで画像URLをリクエストデータに含めて送信
3. バックエンドでメッセージに画像パートを追加
4. `streamText` でマルチモーダルメッセージを送信

### バックエンド：画像付きメッセージの処理

```typescript
async function processRequestMessages(req: Request) {
  const { messages, data } = await req.json();

  // 画像URLがなければそのまま返す
  if (!data?.imageUrl) return messages;

  const initialMessages = messages.slice(0, -1);
  const lastMessage = messages[messages.length - 1];

  // 最後のメッセージに画像パートを追加
  return [
    ...initialMessages,
    {
      ...lastMessage,
      content: [
        { type: 'text', text: lastMessage.content },
        { type: 'image', image: data.imageUrl },
      ],
    },
  ];
}

export async function POST(req: Request) {
  const messages = await processRequestMessages(req);

  const result = await streamText({
    model: google('gemini-2.0-flash'),
    maxTokens: 512,
    messages: [
      { role: 'system', content: 'You are a helpful assistant.' },
      ...messages,
    ],
  });

  return new Response(result.toDataStream());
}
```

### フロントエンド：画像と一緒に送信

```typescript
const [imageUrl, setImageUrl] = React.useState<string | null>(null);

const handleOnSubmit = (e: React.FormEvent) => {
  e.preventDefault();

  const data: Record<string, string> = { message: input };
  if (imageUrl) {
    data.imageUrl = imageUrl;
    setImageUrl(null);
  }

  handleSubmit(e, { data });
};
```

### 注意事項

| 項目 | 内容 |
|------|------|
| ファイルサイズ | OpenAIは最大20MB。プロバイダーによって異なる |
| 推奨送信枚数 | 1プロンプトにつき1枚が基本。複数枚は複雑さが増加 |
| 画質 | 低コントラスト・低照度の画像は認識精度が下がる |
| エンコード形式 | Base64文字列またはURL（プロバイダー仕様に従う） |

---

## 6. React Server Components (RSC)

**いつ使うか**: クライアントバンドルサイズを削減したい、APIキーをサーバーに閉じたい、または複雑なデータフェッチをサーバー側で完結させたいとき。

### RSC + AI の利点

| 利点 | 説明 |
|------|------|
| **リアルタイムAI生成UI** | サーバーからAI生成コンテンツをストリーミング。フルページリロード不要 |
| **クライアントバンドル削減** | AI処理はサーバーで完結。クライアントに送るJSを最小化 |
| **セキュリティ向上** | APIキーや機密ロジックがサーバー外に出ない |
| **Server Actions** | 明示的なAPIエンドポイントなしでサーバー処理を呼び出せる |

### Server Action の基本実装

```typescript
'use server';

import { streamText } from 'ai';
import { createStreamableValue } from 'ai/rsc';

export async function continueConversation(
  history: Array<{ role: string; content: string }>,
  provider: string,
  model: string
) {
  'use server';

  const supportedModel = getSupportedModel(provider, model);
  const stream = createStreamableValue();

  (async () => {
    const { textStream } = await streamText({
      model: supportedModel,
      system: 'You are a helpful assistant.',
      messages: history,
    });

    for await (const text of textStream) {
      stream.update(text);
    }

    stream.done();
  })();

  return {
    messages: history,
    newMessage: stream.value,  // クライアントでストリームを読み込める値
  };
}
```

### クライアントコンポーネントからServer Actionを呼び出す

```typescript
'use client';

import { readStreamableValue } from 'ai/rsc';
import { continueConversation } from './actions';

export const dynamic = 'force-dynamic';
export const maxDuration = 30;

export default function Chat() {
  const [conversationMessages, setMessages] = useState([]);

  const handleOnSubmit = async (event: React.FormEvent) => {
    event.preventDefault();

    setMessages([...conversationMessages, { role: 'user', content: input }]);

    const { messages, newMessage } = await continueConversation(
      [...conversationMessages, { role: 'user', content: input }],
      provider,
      model
    );

    let textContent = '';
    for await (const delta of readStreamableValue(newMessage)) {
      textContent = `${textContent}${delta}`;
      setMessages([...messages, { role: 'assistant', content: textContent }]);
    }
  };
}
```

### `streamUI` vs `createStreamableUI` 使い分け

| 関数 | 役割 | LLM呼び出し | 適用場面 |
|------|------|------------|---------|
| `streamUI` | LLMレスポンスを基にUIコンポーネントをストリーミング生成 | ✅ 内部で呼び出す | チャットバブル・動的UI生成 |
| `createStreamableUI` | 任意のタイミングでUIを段階的に更新 | ❌ 自分で呼び出す | 多段階プロセスの進捗表示 |

### `streamUI` の使用例

```typescript
'use server';

import { streamUI } from 'ai/rsc';

export async function streamComponent(input: string, history: Message[]) {
  'use server';

  const result = await streamUI({
    model: openai('gpt-3.5-turbo'),
    messages: [...history, { role: 'user', content: input }],
    text: ({ content, done }) => {
      // AIのレスポンスをReactコンポーネントとしてラップ
      return <ChatBubble role="assistant" text={content} />;
    },
  });

  return {
    id: generateId(),
    role: 'assistant',
    display: result.value,  // StreamableUI値
  };
}
```

### `createStreamableUI` の使用例（多段階プロセス）

```typescript
'use server';

import { createStreamableUI } from 'ai/rsc';

export async function runProcess(history: Message[]) {
  const ui = createStreamableUI();

  ui.update(<p>処理を開始...</p>);

  try {
    await step1();
    ui.append(<p>ステップ1完了</p>);

    await step2();
    ui.append(<p>ステップ2完了</p>);

    ui.update(<p>全処理完了！</p>);
    ui.done();
  } catch (error) {
    ui.error(error);
  }

  return ui;
}
```

---

## 7. AI/UI 状態分離

**いつ使うか**: 会話履歴の管理が複雑になってきた、サーバー/クライアント間での状態同期が必要になったとき。

### AIState と UIState の概念

| 種別 | 内容 | 保存場所 | シリアライズ可能 |
|------|------|---------|----------------|
| **AIState** | 会話履歴・メタデータ・コンポーネントのJSON表現 | サーバー（DB保存可） | ✅ |
| **UIState** | Reactエレメント・UIコンポーネント・クライアント状態変数 | クライアントのみ | ❌（サーバーに戻せない） |

### 状態管理APIの使い分け

| API | 種別 | 用途 |
|-----|------|------|
| `createAI` | 関数 | AIコンテキストプロバイダーを作成。初期状態とサーバーアクションを定義 |
| `getMutableAIState` | 関数（サーバー） | サーバーアクション内でAI状態を取得・更新 |
| `useActions` | Hook（クライアント） | `createAI` で定義したサーバーアクションにアクセス |
| `useUIState` | Hook（クライアント） | UI状態の取得と更新（Reactの`useState`に相当） |
| `useAIState` | Hook（クライアント） | AI状態への読み取り専用アクセス |

### `createAI` による状態管理の設定

```typescript
// actions.ts
import { createAI, getMutableAIState, streamUI } from 'ai/rsc';

export async function continueConversation(
  input: string,
  provider: string,
  model: string
) {
  'use server';

  const supportedModel = getSupportedModel(provider, model);
  const history = getMutableAIState();  // AI状態を取得

  const result = await streamUI({
    model: supportedModel,
    messages: [...history.get(), { role: 'user', content: input }],
    text: ({ content, done }) => {
      if (done) {
        // レスポンス完了時にAI状態を更新
        history.done([
          ...history.get(),
          { role: 'assistant', content: input },
        ]);
      }
      return <ChatBubble role="assistant" text={content} />;
    },
  });

  return {
    id: generateId(),
    role: 'assistant',
    display: result.value,
  };
}

// AI コンテキストを作成してエクスポート
export const AI = createAI({
  actions: {
    continueConversation,
  },
  initialAIState: [],
  initialUIState: { messages: [] },
});
```

### レイアウトに AI プロバイダーを設定

```typescript
// layout.tsx
import { AI } from './actions';

const AppLayout = ({ children }: { children: React.ReactNode }) => {
  return (
    <AI>
      <div>
        <Header />
        <main>{children}</main>
        <Footer />
      </div>
    </AI>
  );
};
```

### クライアントコンポーネントでの使用

```typescript
'use client';

import { useActions, useUIState, useAIState } from 'ai/rsc';

export default function Home() {
  const [conversation, setConversation] = useUIState();
  const [aiState] = useAIState();  // 読み取り専用
  const { continueConversation } = useActions();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    // UIStateを即座に更新
    setConversation((prev) => ({
      ...prev,
      messages: [...prev.messages, { role: 'user', content: input }],
    }));

    // サーバーアクションを呼び出し
    const response = await continueConversation(input, provider, model);

    setConversation((prev) => ({
      ...prev,
      messages: [...prev.messages, response],
    }));
  };
}
```

### AI状態の永続化パターン

```typescript
const AI = createAI({
  actions: { continueConversation },
  initialAIState: savedState,  // DBから復元した状態を注入可能

  // 状態変更時にDBへ保存
  onSetAIState: async ({ state, done }) => {
    if (done) {
      await saveToDatabase(state);
    }
  },
});
```

---

## 8. 構造化データ生成

**いつ使うか**: AIのレスポンスをJSON等の構造化フォーマットで受け取りたいとき。テキストのパースが不要になり、型安全なデータ処理が可能になる。

### 構造化データ生成の主な手法

| 手法 | 説明 | 信頼性 |
|------|------|--------|
| **Prompt Engineering** | 出力形式を詳細に指示するプロンプトを設計 | 中 |
| **Function Calling** | AIプロバイダーの関数呼び出し機能を利用 | 高 |
| **Zodスキーマ検証** | Zodでスキーマを定義しSDKに渡す | 非常に高い |
| **出力パース** | レスポンスからJSON等を正規表現で抽出 | 低（回避推奨） |
| **反復リファイン** | 複数回のAI呼び出しで品質を向上 | 高（コスト増） |

### `generateObject` vs `streamObject` 使い分け

| 関数 | 用途 | 適用場面 |
|------|------|---------|
| `generateObject` | 一括で構造化データを生成 | バッチ処理、静的なデータ取得 |
| `streamObject` | 構造化データをストリーミングで生成 | リアルタイム更新が必要な場合 |

### `generateObject` の基本実装

```typescript
import { z } from 'zod';
import { google } from '@ai-sdk/google';
import { generateObject } from 'ai';

// Zodスキーマ定義
const ProductSchema = z.object({
  name: z.string(),
  description: z.string(),
  price: z.number(),
  category: z.string(),
});

const ProductListSchema = z.array(ProductSchema);

async function generateProductList(prompt: string) {
  'use server';

  const {
    object: { products },
  } = await generateObject({
    model: google('gemini-2.0-flash'),
    schema: z.object({
      products: ProductListSchema,
    }),
    prompt: `Generate a list of 5 products related to: ${prompt}.
             Provide name, description, price, and category for each product.`,
  });

  return products;
}

// 使用例
const products = await generateProductList('A list of cereal types');
console.table(products);
```

### エラーハンドリングパターン

```typescript
const handleOnSubmit = async (event: React.FormEvent) => {
  event.preventDefault();
  const value = input.trim();

  try {
    const products = await actions.generateProductList(value);
    const message = { role: 'assistant', products };
    setConversation((prev) => [...prev, message]);
  } catch (error) {
    console.error('Error generating product list:', error);

    // エラー用フォールバックデータ
    const errorMessage = {
      role: 'assistant',
      products: [{
        name: 'エラー',
        description: '製品リストの生成中にエラーが発生しました。',
        price: 0,
        category: 'Error',
      }],
    };
    setConversation((prev) => [...prev, errorMessage]);
  } finally {
    setIsLoading(false);
  }
};
```

### createAI との組み合わせ

```typescript
// server actions に generateProductList を登録
export const AI = createAI({
  actions: {
    generateProductList,  // useActions で利用可能になる
  },
  initialAIState: [],
  initialUIState: [],
});
```

---

## 9. Tool / Function Calling

**いつ使うか**: AIモデルが外部APIやデータベース、関数を呼び出してリアルタイム情報を取得する必要があるとき（天気情報、在庫確認、計算処理など）。

### Tool Calling のフロー

```
ユーザー → プロンプト送信
          ↓
Vercel AI SDK → LLMプロバイダーへ送信
          ↓
LLMがツール呼び出しを要求
          ↓
SDK がツールを実行（APIコール等）
          ↓
ツール結果をLLMへフィードバック
          ↓
LLMが最終レスポンスを生成
          ↓
UIを更新
```

### シンプルな代替アプローチ（限定的な用途に）

```typescript
// ツール呼び出しを使わず、API結果をプロンプトに直接埋め込む方法
const { city, temperature, weatherDescription, humidity } = await getWeatherInfo(city);

const weatherInfo = `The current temperature in ${city} is ${temperature}°C
with ${weatherDescription}. The humidity level is ${humidity}%.`;

const prompt = `Here is the latest weather update: ${weatherInfo}. How can I help you today?`;
```

> ただしこの方法は固定フォーマットのプロンプトにしか使えず、柔軟性に欠ける。

### `streamUI` + `tools` によるカスタムツール実装

```typescript
'use server';

import { z } from 'zod';
import { streamUI } from 'ai/rsc';

export async function chatWithWeather(
  input: string,
  provider: string,
  model: string
) {
  const supportedModel = getSupportedModel(provider, model);

  const result = await streamUI({
    model: supportedModel,
    system: `You are a helpful weather assistant.
             You can provide weather information for cities.
             If a user asks about the weather in a specific city,
             use the 'getWeather' function to fetch the data.
             Always interpret temperatures in Celsius.`,
    messages: [{ role: 'user', content: input }],

    // ツール定義
    tools: {
      getWeather: {
        description: 'Get the current weather for a specific city',
        parameters: z.object({
          city: z.string().describe('The name of the city'),
        }),
        // async generator でローディング → 結果の順に返す
        generate: async function* ({ city }) {
          yield <LoadingSpinner />;  // 処理中はローディングUIを表示

          const weatherData = await fetchWeatherData(city);

          return (
            <WeatherCard
              city={city}
              temperature={weatherData.temperature}
              condition={weatherData.condition}
            />
          );
        },
      },
    },
  });

  return {
    id: generateId(),
    role: 'assistant',
    display: result.value,
  };
}
```

### ツール設計の判断基準

| 項目 | 推奨 |
|------|------|
| **ツール名** | 動詞で始めるわかりやすい名前（`getWeather`, `searchProducts`） |
| **`description`** | モデルがいつ使うかを判断するための詳細な説明 |
| **`parameters`** | Zodスキーマで型安全に定義。`describe()` でフィールドの意味も明記 |
| **`generate`** | async generatorで途中経過（ローディング）も表示可能 |
| **エラー処理** | ツール内でtry/catchを実装し、エラー用UIを`yield`で返す |

### 複数ツールの登録パターン

```typescript
tools: {
  getWeather: {
    description: '特定の都市の現在の天気を取得',
    parameters: z.object({ city: z.string() }),
    generate: async function* ({ city }) { /* ... */ },
  },
  searchProducts: {
    description: 'データベースから製品を検索',
    parameters: z.object({
      query: z.string().describe('検索クエリ'),
      category: z.string().optional().describe('カテゴリフィルター'),
    }),
    generate: async function* ({ query, category }) { /* ... */ },
  },
  // 必要に応じてツールを追加
}
```

---

## クイックリファレンス：関数・Hook 一覧

| API | カテゴリ | 説明 |
|-----|---------|------|
| `generateText` | Core | テキストを一括生成 |
| `streamText` | Core | テキストをストリーミング生成 |
| `generateObject` | Core | Zodスキーマ準拠のオブジェクトを生成 |
| `streamObject` | Core | Zodスキーマ準拠のオブジェクトをストリーミング生成 |
| `useChat` | React Hook | チャット機能（会話履歴付き） |
| `useCompletion` | React Hook | テキスト補完 |
| `useAssistant` | React Hook | OpenAI Assistants API連携 |
| `createStreamableValue` | RSC | サーバーからクライアントへ値をストリーミング |
| `readStreamableValue` | RSC（クライアント） | ストリーミング値を読み込む |
| `streamUI` | RSC | LLMレスポンスをReactコンポーネントとしてストリーミング |
| `createStreamableUI` | RSC | 段階的にUIを更新するストリーミング値 |
| `createAI` | State | AIコンテキストプロバイダーを作成 |
| `getMutableAIState` | State（サーバー） | サーバーでAI状態を取得・更新 |
| `useActions` | State（クライアント） | サーバーアクションにアクセス |
| `useUIState` | State（クライアント） | UI状態の取得・更新 |
| `useAIState` | State（クライアント） | AI状態への読み取り専用アクセス |
