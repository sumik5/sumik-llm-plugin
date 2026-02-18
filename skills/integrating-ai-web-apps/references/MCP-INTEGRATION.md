# MCP-INTEGRATION.md — WebアプリへのMCP統合実装

WebアプリにMCPを統合する実装パターンを参照するときに使う。MCPプロトコル仕様の詳細は `developing-mcp` スキルを参照。本ファイルはWebアプリ（Next.js + Vercel AI SDK / LangChain.js）へのMCP統合実装に焦点を当てる。

---

## 1. MCPの重要性

**いつ使うか**: AIアプリにおいて外部ツール・データソースを統合する設計を始めるとき。

### Prompts / Tools / Resources の関係

| コンポーネント | 役割 | 例 |
|-------------|------|-----|
| **Prompts** | LLMへの構造化入力、モデルの推論をコントロール | チャットの指示文、タスク定義 |
| **Tools** | AIモデルが動的に呼び出せる外部機能 | APIコール、DBクエリ、ファイルアクセス |
| **Resources** | モデルがアクセスできる静的・プリロードコンテキスト | ドキュメント、JSON、参照データ |

### MCPが解決する課題

従来のツール統合では、フレームワークごとに実装が異なり再利用できなかった:

| 問題 | MCPによる解決 |
|------|-------------|
| LangChain用のツールはVercel AI SDKで使えない | MCPサーバーを定義すれば任意のMCP対応クライアントから利用可能 |
| 認証・権限管理がフレームワークごとにバラバラ | MCPサーバーが一元管理 |
| AIモデルが外部APIキーに直接アクセスする | AIはツール名しか知らず、実際の呼び出しはMCPサーバーが仲介 |
| ツール再利用に大量の「配線コード」が必要 | プラグアンドプレイで接続可能 |

---

## 2. MCPアーキテクチャ

**いつ使うか**: システム設計時にMCPの位置づけを整理するとき。

### Client / Server 構成

```
AIアプリケーション（Next.js等）
    ↓ リクエスト
MCPクライアント（エージェントまたはSDK）
    ↓ プロトコル通信（stdio / HTTP）
MCPサーバー（ツール・リソース・プロンプトを公開）
    ↓ HTTP/DB/FS アクセス
外部サービス（API、データベース、ファイルシステム）
```

### データフロー

| ステップ | 主体 | 内容 |
|---------|------|------|
| 1 | ユーザー | プロンプトを入力 |
| 2 | AIアプリ（React UI） | `useChat` hookでAPIルートにPOST送信 |
| 3 | Next.js APIルート | Vercel AI SDK / LangChain.js にメッセージ転送 |
| 4 | LLM | レスポンス生成。必要に応じてMCPツールを呼び出すと判断 |
| 5 | MCPクライアント | MCPサーバーにツール呼び出しリクエスト送信 |
| 6 | MCPサーバー | ツールロジックを実行（外部API呼び出し等） |
| 7 | MCPサーバー → クライアント | 構造化されたレスポンスを返却 |
| 8 | AIアプリ | ストリーミングレスポンスをUIに表示 |

### アーキテクチャの核心原則

> **AIモデルは外部APIに直接アクセスしない。** モデルが知っているのはMCPサーバーが公開するツール名のみ。実際の通信・APIキー管理はすべてMCPサーバーが担う。これによりセキュリティの分離、モジュール性の向上、APIキーの保護が実現される。

---

## 3. Next.js + Vercel AI SDK + MCP統合

**いつ使うか**: Vercel AI SDKを使ったNext.jsアプリにMCPを統合するとき。

### アーキテクチャ概要（5層構造）

| 層 | 役割 | 実装 |
|----|------|------|
| **Browser / Client** | チャットUI、会話状態管理 | React + `useChat` hook |
| **Next.js API Route** | フロントとAIバックエンドの仲介 | `app/api/chat/route.ts` |
| **Vercel AI SDK** | LLMとMCPクライアントの統合 | `experimental_createMCPClient` |
| **MCPサーバー** | ツールの実行、外部APIとの通信 | `@modelcontextprotocol/sdk` |
| **外部API / データソース** | 実際のデータ提供 | 任意のHTTP API / DB |

### フロントエンドの実装

```typescript
// app/page.tsx
'use client';
import { useChat } from 'ai/react';
import { DefaultChatTransport } from 'ai';

export default function ChatPage() {
  const { messages, sendMessage, status } = useChat({
    transport: new DefaultChatTransport({ api: '/api/chat' }),
  });

  return (
    <div>
      {messages.map(m => (
        <div key={m.id}>{m.role}: {m.content as string}</div>
      ))}
      <input
        onKeyDown={e => {
          if (e.key === 'Enter') {
            sendMessage({ text: e.currentTarget.value });
            e.currentTarget.value = '';
          }
        }}
      />
    </div>
  );
}
```

### APIルート（MCPクライアント統合）の実装

```typescript
// app/api/chat/route.ts
import { createGoogleGenerativeAI } from '@ai-sdk/google';
import {
  streamText,
  convertToModelMessages,
  experimental_createMCPClient,
} from 'ai';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio';

export const maxDuration = 30;

const gemini = createGoogleGenerativeAI({
  apiKey: process.env.GEMINI_API_KEY ?? '',
});

export async function POST(req: Request) {
  const { messages } = await req.json();

  // stdioトランスポートでローカルMCPサーバーに接続
  const transport = new StdioClientTransport({
    command: 'node',
    args: ['src/stdio/server.js'],
  });

  const mcpClient = await experimental_createMCPClient({ transport });
  const tools = await mcpClient.tools(); // MCPサーバーが公開するツールを取得

  const result = streamText({
    model: gemini('gemini-2.5-flash'),
    messages: convertToModelMessages(messages),
    tools,
    system: 'You are a helpful assistant that can call tools when needed.',
    onFinish: async () => { await mcpClient.close(); },
    onError: async () => { await mcpClient.close(); },
  });

  return result.toUIMessageStreamResponse();
}
```

---

## 4. MCPサーバー構築

**いつ使うか**: AIアプリに外部機能を提供するMCPサーバーを自分で実装するとき。

### サーバー初期化

```typescript
// src/mcp-server.ts
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';

const server = new McpServer({
  name: 'my-mcp-server',
  version: '1.0.0',
});
```

### ツール定義

AIモデルが動的に呼び出せる外部機能を定義する。

```typescript
server.tool(
  "fetch-data",                          // ツール名（ユニーク）
  "Fetch data from external API",         // 説明（LLMが呼び出しタイミングを判断するために使用）
  {
    query: z.string().describe("Search query"), // 入力スキーマ（Zod）
  },
  async ({ query }) => {
    try {
      const response = await fetch(`https://api.example.com/search?q=${query}`);
      if (!response.ok) {
        return { content: [{ type: "text", text: "Data not available." }] };
      }
      const data = await response.json();
      return { content: [{ type: "text", text: JSON.stringify(data) }] };
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown error";
      return { content: [{ type: "text", text: `Error: ${message}` }] };
    }
  }
);
```

### プロンプト定義

再利用可能な指示テンプレートを定義する。

```typescript
server.prompt(
  "summarize-result",
  "Summarize a result into a short sentence",
  {
    result: z.string().describe("The result text to summarize"),
  },
  async ({ result }) => ({
    messages: [{
      role: 'user',
      content: {
        type: 'text',
        text: `以下のテキストを一文で要約してください:\n"${result}"`,
      },
    }],
  })
);
```

### リソース定義

静的コンテキストや参照ドキュメントを提供する。

```typescript
server.resource(
  'api-docs',
  'api-docs://my-service',   // URI（ユニーク）
  async (uri) => ({
    contents: [{
      uri: uri.href,
      text: `# My Service API Documentation\n\n利用可能なツール:\n- fetch-data: データを取得する\n`,
    }],
  })
);
```

### サーバー起動

```typescript
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('MCP Server running on stdio');
}

main();
```

### MCPサーバー設計の考慮事項

| 観点 | 推奨事項 |
|------|---------|
| エラーハンドリング | 外部APIの失敗時にフォールバックレスポンスを返す |
| セキュリティ | 通常のサーバーと同様：APIキー管理、アクセス制御、パフォーマンス監視 |
| メッセージ形式 | リソースURI・ツール名はユニークかつ予測可能にする |
| ツール説明 | LLMがいつ呼び出すかを判断するため、明確で具体的な説明を書く |

---

## 5. LangChain.js + MCP統合

**いつ使うか**: LangChainのエージェント機能（推論ループ、複数ツールの組み合わせ）を使いたいとき。

### Vercel AI SDK統合との主な違い

| 観点 | Vercel AI SDK | LangChain.js |
|------|-------------|-------------|
| ツール呼び出し | SDKが自動でルーティング | `createReactAgent` でエージェントが推論して判断 |
| レスポンス形式 | ストリーミング（トークン単位） | 構造化UIメッセージ |
| 適合シーン | シンプルなツール統合 | 複数ツールの組み合わせ・複雑な推論 |

### APIルート（LangChain + MCP）の実装

```typescript
// app/api/chat/route.ts
import { ChatGoogleGenerativeAI } from "@langchain/google-genai";
import { createUIMessageStreamResponse } from "ai";
import { MultiServerMCPClient } from "@langchain/mcp-adapters";
import { createReactAgent } from "@langchain/langgraph/prebuilt";
import { HumanMessage } from "@langchain/core/messages";

async function createMCPClient() {
  const client = new MultiServerMCPClient({
    useStandardContentBlocks: true,
    mcpServers: {
      myServer: {
        transport: "stdio",
        command: "node",
        args: ["app/stdio/server.js"],
        restart: { enabled: true, maxAttempts: 3, delayMs: 1000 },
      },
      // 複数のMCPサーバーを同時に接続できる
    },
  });
  const tools = await client.getTools();
  return { client, tools };
}

export async function POST(req: Request) {
  const body = await req.json();
  const input: string = body.input ?? "";

  // 1. MCPクライアントとツールを初期化
  const { client, tools } = await createMCPClient();

  // 2. LLMを初期化
  const model = new ChatGoogleGenerativeAI({
    model: "gemini-2.5-flash",
    apiKey: process.env.GEMINI_API_KEY,
  });

  // 3. LangChain Reactエージェントを構成（LLM + MCPツール）
  const agent = createReactAgent({ llm: model, tools });

  // 4. エージェントを実行し、MCPクライアントをクローズ
  const result = await agent.invoke({
    messages: [new HumanMessage(input)],
  });
  await client.close();

  // 5. UIメッセージ形式でフロントエンドにストリーミング
  return createUIMessageStreamResponse({ stream: result });
}
```

### LangChainエージェントのフロントエンド処理

`useChat` hookからバックエンドが返す構造化UIメッセージを受け取り、ツール出力を専用コンポーネントでレンダリングできる:

```tsx
// ツールの出力を専用カードでレンダリングする例
{messages.map(m => {
  if (m.type === 'tool-result') {
    return <ToolResultCard key={m.id} data={m} />;
  }
  return <ChatBubble key={m.id} message={m} />;
})}
```

---

## 6. MCPの将来の方向性

**いつ使うか**: MCPを使った長期的なアーキテクチャ設計を行うとき。

### MCPゲートウェイ

複数のMCPサーバーへの接続を一元管理するプロキシ層。

| 問題 | MCPゲートウェイによる解決 |
|------|------------------------|
| 各MCPサーバーへの個別認証ロジック | ゲートウェイが一元管理 |
| サーバー間での状態の不整合 | 共有コンテキストをゲートウェイが維持 |
| 複数サーバー連携の複雑な調整 | AIエージェントは単一のゲートウェイと通信するだけでよい |

```
AIエージェント
    ↓ 単一接続
MCPゲートウェイ（ルーティング・セキュリティ・ポリシー管理）
    ├── カレンダーMCPサーバー
    ├── メールMCPサーバー
    └── コマースMCPサーバー
```

### MCP-as-a-Service

ビジネスが自社サービスをMCPエンドポイントとして公開するモデル:

```
mybookstore.com/mcp → 在庫確認・予約・注文ツールを公開
```

ユーザーはAIアシスタントに「この書店を追加」するだけで、在庫確認や注文がチャットUIから可能になる。サイトへのRSSフィードやモバイルアプリインストールに代わる「AIへの接続メカニズム」として普及が見込まれる。

### MCPディレクトリとレジストリ

| リソース | 説明 |
|---------|------|
| 公式MCPレジストリ | `modelcontextprotocol/registry`（GitHub）。利用可能なサーバーの集中リスト |
| コミュニティカタログ | Glama・Pulse MCP等。信頼性の高いサーバーを厳選して掲載 |
| CLIツール | `mcp-registry-cli` でコマンドラインからMCPサーバーを検索・インストール可能 |

> **現状**: MCPディレクトリのエコシステムは、検索エンジン登場前のインターネット初期に近い状態。今後、評価・カテゴリ・レビュー機能を持つ成熟したディレクトリが整備される見込み。

---

## 相互参照

- **MCPプロトコル仕様の詳細**（Host/Client/Server ロール、Transport、セキュリティモデル等）→ `developing-mcp` スキルを参照
- **デプロイ・セキュリティ全般**（MCPサーバーの本番運用を含む）→ `DEPLOYMENT-SECURITY.md` を参照
