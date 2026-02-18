---
description: >-
  Comprehensive guide to integrating generative AI into web applications using Vercel AI SDK, LangChain.js, and MCP with React/Next.js.
  Use when building AI-powered web features (streaming chat, RAG, tool calling, structured data generation) in JavaScript/TypeScript projects.
  For RAG system internals, use building-rag-systems. For MCP protocol development, use developing-mcp. For Next.js framework specifics, use developing-nextjs.
---

# Generative AI Web App 統合スキル

## 概要

Generative AI web appとは、LLM（大規模言語モデル）をコアに据え、テキスト・画像・音声・動画などのコンテンツを動的に生成するWebアプリケーションのこと。静的ロジックに頼らず、ユーザー入力に応じてパーソナライズされたインタラクティブな体験を提供する。

**このスキルのスコープ:**
- React/Next.jsでのAI機能統合パターン
- Vercel AI SDKを使ったプロバイダー抽象化・ストリーミング・状態管理
- LangChain.jsを使ったチェーン・エージェント・RAG構築
- Tool calling / 構造化データ生成
- AIアプリのUX・セキュリティ・テスト考慮点

---

## 技術スタックアーキテクチャ

| 層 | 技術 | 役割 |
|---|---|---|
| ユーザーインターフェース | React.js | UIコンポーネント・インタラクション・JSX |
| フロントエンド/バックエンド統合 | Next.js (App Router) | SSR・API Routes・RSC・ファイルベースルーティング |
| AI統合レイヤー | Vercel AI SDK | プロバイダー抽象化・ストリーミング・React hooks・状態管理 |
| LLMアプリフレームワーク | LangChain.js | チェーン・エージェント・メモリ・RAG |
| AIモデル/プロバイダー | OpenAI / Google Gemini | LLM推論・埋め込み・画像生成 |
| 外部ツール連携 | MCP (Model Context Protocol) | 外部データソース・ツール呼び出し標準化 |

**情報フロー:**
```
ユーザー入力 → React UI → Next.js API Route → Vercel AI SDK
  → LangChain.js（必要時） → LLM Provider API
  → ストリーミングレスポンス → React UI更新
```

---

## Vercel AI SDK クイックスタート

詳細: → [VERCEL-AI-SDK.md](references/VERCEL-AI-SDK.md)

### コア概念

**プロバイダー抽象化（Provider Abstraction）**
ベンダーロックインを回避するための統一インターフェース。`model`パラメータ1つで切り替え可能:

```typescript
import { generateText } from 'ai';
import { google } from '@ai-sdk/google';
import { openai } from '@ai-sdk/openai';

// プロバイダーを差し替えても同一コード
const { text } = await generateText({
  model: google('gemini-1.5-pro'), // または openai('gpt-4o')
  messages: [
    { role: 'system', content: 'あなたはAIアシスタントです' },
    { role: 'user', content: userInput },
  ],
});
```

**ストリーミングレスポンス**
`streamText`でリアルタイム表示。LLMの全生成完了を待たずにUIを更新:

```typescript
import { streamText } from 'ai';

// Next.js Route Handler
export async function POST(req: Request) {
  const { messages } = await req.json();
  const result = streamText({
    model: google('gemini-1.5-pro'),
    messages,
  });
  return result.toDataStreamResponse();
}
```

**React Hooks**

| Hook | 用途 |
|------|------|
| `useChat` | チャットUI（履歴管理・送信・ストリーミング） |
| `useCompletion` | テキスト補完（単発生成） |
| `useObject` | 構造化データ生成のストリーミング |

```typescript
import { useChat } from 'ai/react';

export function ChatUI() {
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat({
    api: '/api/chat',
  });
  // messages: { role, content }[] で自動管理
}
```

**構造化データ生成**
```typescript
import { generateObject } from 'ai';
import { z } from 'zod';

const { object } = await generateObject({
  model: google('gemini-1.5-pro'),
  schema: z.object({
    title: z.string(),
    tags: z.array(z.string()),
    sentiment: z.enum(['positive', 'neutral', 'negative']),
  }),
  prompt: 'Analyze this article...',
});
// object は型安全・バリデーション済み
```

---

## LangChain.js クイックスタート

詳細: → [LANGCHAIN-JS.md](references/LANGCHAIN-JS.md)

### コア概念

| 概念 | 説明 | 使用場面 |
|------|------|---------|
| **Chain** | 複数処理の逐次/並列組み合わせ | 複数ステップが必要な生成処理 |
| **Agent** | ツールを自律的に選択・実行するLLM | 外部API呼び出し・計算・検索が必要な場合 |
| **Memory** | 会話履歴の保持・管理 | マルチターン会話・コンテキスト維持 |
| **Retriever** | ベクトルDB等からドキュメント取得 | RAG（検索拡張生成）構築時 |

**LLMChainの基本パターン:**
```typescript
import { ChatGoogleGenerativeAI } from '@langchain/google-genai';
import { PromptTemplate } from '@langchain/core/prompts';
import { StringOutputParser } from '@langchain/core/output_parsers';

const model = new ChatGoogleGenerativeAI({ model: 'gemini-1.5-pro' });
const prompt = PromptTemplate.fromTemplate('質問: {question}\n回答:');

const chain = prompt.pipe(model).pipe(new StringOutputParser());
const result = await chain.invoke({ question: userQuestion });
```

---

## AI状態管理の基礎

詳細: → [VERCEL-AI-SDK.md](references/VERCEL-AI-SDK.md)（State Management セクション）

### UI State vs AI State の分離

| 種別 | 保存場所 | 内容 | セキュリティ |
|------|---------|------|------------|
| **UI State** | クライアント（useState） | 表示用メッセージ・ローディング・入力値 | 低（ユーザー閲覧可能） |
| **AI State** | サーバー（セッション/DB） | 完全な会話履歴・システムプロンプト・コンテキスト | 高（サーバー管理必須） |

**なぜ分離が必要か:**
- クライアント保存データは改ざん可能 → サーバー側で必ず検証
- LLMへの全コンテキスト送信はサーバーで管理 → APIキー露出防止
- UIは表示最適化（最新N件）、AI処理は全履歴でコンテキスト維持

**React Server Components（RSC）との統合:**
```typescript
// Server Component でAI処理 → HTML生成 → クライアントに送信
// Bundle sizeを削減しSEOを改善

// createAI でサーバーサイドの状態管理を定義
import { createAI, getMutableAIState } from 'ai/rsc';

export const AI = createAI({
  actions: { submitMessage },
  initialAIState: [] as Message[],
  initialUIState: [] as UIMessage[],
});
```

### Tool Calling パターン

```typescript
import { streamText, tool } from 'ai';
import { z } from 'zod';

const result = streamText({
  model: google('gemini-1.5-pro'),
  messages,
  tools: {
    getWeather: tool({
      description: '指定地点の天気を取得',
      parameters: z.object({ location: z.string() }),
      execute: async ({ location }) => {
        return await fetchWeatherAPI(location);
      },
    }),
  },
});
```

---

## ユーザー確認の原則（AskUserQuestion）

実装開始前に以下の判断分岐でユーザーに確認すること:

| 判断事項 | 選択肢 | 影響 |
|---------|--------|------|
| **AIプロバイダー** | Google Gemini（無料枠あり） / OpenAI（有料） / Anthropic | コスト・モデル性能・API制限 |
| **ストリーミング方式** | `streamText` + `useChat` / RSC `streamUI` / カスタム実装 | UIの複雑さ・リアルタイム性 |
| **状態管理パターン** | `useChat`（シンプル）/ RSC AI State（フル制御）/ カスタム | 複雑さ・セキュリティ要件 |
| **LangChain.js使用** | 使用する（RAG・エージェント）/ Vercel AI SDKのみ | 複雑さ・機能性 |
| **Tool calling** | 必要 / 不要 | 外部API統合の有無 |
| **会話履歴保存** | インメモリのみ / DB永続化 | ユーザー体験・インフラコスト |

---

## リファレンスナビゲーション

| ファイル | 内容 | 参照タイミング |
|---------|------|--------------|
| [VERCEL-AI-SDK.md](references/VERCEL-AI-SDK.md) | SDK詳細（全API・hooks・ストリーミング・状態管理・RSC統合） | SDK実装時 |
| [LANGCHAIN-JS.md](references/LANGCHAIN-JS.md) | LangChain詳細（チェーン・エージェント・メモリ・LangSmith） | RAG・エージェント構築時 |
| [PROMPT-ENGINEERING.md](references/PROMPT-ENGINEERING.md) | プロンプト設計（system prompt・few-shot・chain-of-thought） | LLM出力品質改善時 |
| [RAG-AND-SUMMARIZATION.md](references/RAG-AND-SUMMARIZATION.md) | RAGパイプライン・要約・埋め込み実装 | ドキュメント検索機能実装時 |
| [TESTING-AI-APPS.md](references/TESTING-AI-APPS.md) | AIアプリのテスト戦略（モック・E2E・評価） | テスト実装時 |
| [DEPLOYMENT-SECURITY.md](references/DEPLOYMENT-SECURITY.md) | デプロイ・セキュリティ（APIキー管理・CORS・レート制限） | 本番デプロイ前 |
| [MCP-INTEGRATION.md](references/MCP-INTEGRATION.md) | MCP統合（外部ツール・データソース接続） | MCP経由の外部連携時 |

---

## 関連スキル

| スキル | 相互参照理由 |
|--------|------------|
| `developing-nextjs` | App Router・RSC・API Routes・Server Actions詳細 |
| `building-rag-systems` | ベクトルDB・埋め込み・チャンキング・検索パイプライン内部仕様 |
| `developing-mcp` | MCPサーバー開発・プロトコル実装・ツール定義 |
| `building-nextjs-saas` | 認証・課金・マルチテナントを含むSaaSアーキテクチャ全体 |
| `practicing-llmops` | 本番LLMOps（データパイプライン・評価・モニタリング・コスト管理） |
| `securing-code` | AIアプリのセキュリティチェック（入力バリデーション・プロンプトインジェクション対策） |
