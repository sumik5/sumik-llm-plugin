# MCPクライアント構築ガイド

MCPクライアントは、MCPサーバーに接続してTools・Resources・Promptsを発見・呼び出し、LLMの推論結果と統合してユーザーに提供するアプリケーションです。このガイドでは、TypeScript SDK（@modelcontextprotocol/sdk）を使用したクライアント実装方法を解説します。

---

## Client SDK セットアップ

### 前提条件

- Node.js 18.x以上
- TypeScript環境
- LLM API（例: Google Gemini API）

### プロジェクト初期化

```bash
mkdir my-mcp-client
cd my-mcp-client
npm init -y
npm install @modelcontextprotocol/sdk @google/genai zod dotenv
npm install --save-dev typescript ts-node @types/node
npx tsc --init
```

### tsconfig.json設定

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": true
  },
  "ts-node": {
    "esm": true
  }
}
```

### 環境変数設定

```.env
GEMINI_API_KEY="your-api-key-here"
```

---

## Client初期化とCapability宣言

### 基本的なClient作成

```typescript
import 'dotenv/config';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { GoogleGenAI } from '@google/genai';

const mcpClient = new Client(
  {
    name: 'my-client',
    version: '1.0.0'
  },
  {
    capabilities: {
      sampling: {},      // LLM呼び出し対応
      elicitation: {},   // ユーザー入力要求対応
      roots: {
        listChanged: true  // root一覧変更通知送信可能
      },
      tools: {
        listChanged: true  // Tool一覧変更受信可能
      }
    }
  }
);

const genAI = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY! });
```

### Capability設計指針

Clientが**宣言するCapability**は、Serverから受信する要求・通知への対応能力を示します：

| Capability | 意味 | 実装例 |
|-----------|------|--------|
| `sampling` | Server→LLM呼び出し要求受信可能 | Server-Side Samplingハンドラー |
| `elicitation` | Server→ユーザー入力要求受信可能 | Elicitationハンドラー |
| `roots` | Server→roots/list要求受信可能 | ファイルシステムroot提供 |
| `tools.listChanged` | Tool一覧変更通知受信可能 | Notificationハンドラー |

---

## サーバー接続

### 接続ライフサイクル

```typescript
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

async function connectToServer() {
  // Transport作成
  const transport = new StreamableHTTPClientTransport({
    baseURL: 'http://localhost:3000/mcp'
  });

  // 接続＆Initialize handshake
  await mcpClient.connect(transport);
  console.log('Connected to MCP server');

  return transport;
}
```

### Transport選択

| Transport | 用途 | 接続先 |
|----------|------|--------|
| **StdioClientTransport** | ローカルプロセス | 子プロセスとしてサーバー起動 |
| **StreamableHTTPClientTransport** | リモート接続 | HTTP/HTTPS経由でサーバー接続 |

### stdio接続例

```typescript
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { spawn } from 'node:child_process';

const serverProcess = spawn('npx', ['ts-node', 'src/server.ts']);
const transport = new StdioClientTransport({
  stdin: serverProcess.stdin,
  stdout: serverProcess.stdout
});

await mcpClient.connect(transport);
```

---

## Capability Discovery

### Tools/Resources/Prompts一覧取得

```typescript
async function discoverCapabilities() {
  // Tool一覧
  const tools = await mcpClient.listTools();
  console.log('Available tools:', tools.tools.map(t => t.name));

  // Resource一覧
  const resources = await mcpClient.listResources();
  console.log('Available resources:', resources.resources.map(r => r.uri));

  // Prompt一覧
  const prompts = await mcpClient.listPrompts();
  console.log('Available prompts:', prompts.prompts.map(p => p.name));
}
```

### LLMへのTool提供（Gemini SDK）

```typescript
import { mcpToTool, Chat } from '@google/genai';

// MCP Toolを自動的にGemini形式に変換
let callableTool = mcpToTool(mcpClient);

let chat: Chat = genAI.chats.create({
  model: 'gemini-2.5-flash',
  config: {
    tools: [callableTool]
  },
  history: [
    {
      role: 'user',
      parts: [{ text: 'SYSTEM: You are a helpful assistant.' }]
    },
    {
      role: 'model',
      parts: [{ text: 'Understood.' }]
    }
  ]
});
```

---

## Tool呼び出しフロー

### 基本的なTool呼び出し

```typescript
import { CallToolResultSchema } from '@modelcontextprotocol/sdk/types.js';

async function callTool(toolName: string, args: any) {
  const result = await mcpClient.callTool({
    name: toolName,
    arguments: args
  }, CallToolResultSchema);

  if (result.isError) {
    console.error('Tool error:', result.content);
    return null;
  }

  return result.content;
}

// 使用例
const tableList = await callTool('listTables', { cursor: '0' });
```

### LLM統合：手動Tool呼び出しループ

```typescript
async function processUserQuery(userInput: string) {
  const response = await chat.sendMessage(userInput);

  // Tool呼び出しが必要か判定
  if (response.functionCalls && response.functionCalls.length > 0) {
    for (const functionCall of response.functionCalls) {
      console.log(`Calling tool: ${functionCall.name}`);

      // MCPサーバーにTool実行要求
      const toolResult = await mcpClient.callTool({
        name: functionCall.name,
        arguments: functionCall.args
      }, CallToolResultSchema);

      // Tool結果をLLMに返す
      const followUpResponse = await chat.sendMessage([
        {
          functionResponse: {
            name: functionCall.name,
            response: toolResult.content
          }
        }
      ]);

      console.log('Assistant:', followUpResponse.text);
    }
  } else {
    console.log('Assistant:', response.text);
  }
}
```

### エラーハンドリング

```typescript
async function safeTool Call(toolName: string, args: any) {
  try {
    const result = await mcpClient.callTool({
      name: toolName,
      arguments: args
    }, CallToolResultSchema);

    if (result.isError) {
      return {
        success: false,
        error: result.content[0]?.text || 'Unknown error'
      };
    }

    return {
      success: true,
      data: result.content
    };
  } catch (err) {
    return {
      success: false,
      error: (err as Error).message
    };
  }
}
```

---

## Resource読み取り

### Resource読み取りパターン

```typescript
async function readResource(uri: string) {
  const result = await mcpClient.readResource({ uri });

  return result.contents.map(content => {
    if ('text' in content) {
      return content.text;
    } else if ('blob' in content) {
      return Buffer.from(content.blob, 'base64');
    }
  });
}

// 使用例
const schemaText = await readResource('schema://table/users');
console.log('Users table schema:', schemaText);
```

### Resource Subscription

```typescript
async function subscribeToResource(uri: string) {
  // Subscriptionリクエスト
  await mcpClient.subscribe({ uri });

  console.log(`Subscribed to ${uri}`);

  // Unsubscribe例
  // await mcpClient.unsubscribe({ uri });
}
```

---

## 複数サーバー管理

### 1 Client = 1 Server の原則

MCPの設計原則：**1つのClientインスタンスは1つのServerに接続**します。複数サーバー利用時は、それぞれ独立したClient instanceを作成します。

```typescript
class MultiServerClient {
  private clients: Map<string, Client> = new Map();

  async addServer(name: string, baseURL: string) {
    const client = new Client(
      { name: `client-${name}`, version: '1.0.0' },
      { capabilities: { /* ... */ } }
    );

    const transport = new StreamableHTTPClientTransport({ baseURL });
    await client.connect(transport);

    this.clients.set(name, client);
    console.log(`Connected to server: ${name}`);
  }

  async callTool(serverName: string, toolName: string, args: any) {
    const client = this.clients.get(serverName);
    if (!client) {
      throw new Error(`Server ${serverName} not connected`);
    }

    return await client.callTool({ name: toolName, arguments: args }, CallToolResultSchema);
  }

  async disconnectAll() {
    for (const [name, client] of this.clients.entries()) {
      await client.close();
      console.log(`Disconnected from ${name}`);
    }
    this.clients.clear();
  }
}

// 使用例
const multiClient = new MultiServerClient();
await multiClient.addServer('db', 'http://localhost:3000/mcp');
await multiClient.addServer('web', 'http://localhost:3001/mcp');

const dbResult = await multiClient.callTool('db', 'listTables', {});
const webResult = await multiClient.callTool('web', 'scrapeUrl', { url: 'https://example.com' });
```

---

## エラーハンドリング

### タイムアウト設定

```typescript
async function callToolWithTimeout(toolName: string, args: any, timeoutMs: number = 30000) {
  const timeoutPromise = new Promise((_, reject) =>
    setTimeout(() => reject(new Error('Tool call timeout')), timeoutMs)
  );

  const callPromise = mcpClient.callTool({ name: toolName, arguments: args }, CallToolResultSchema);

  try {
    return await Promise.race([callPromise, timeoutPromise]);
  } catch (err) {
    console.error('Tool call failed:', err);
    throw err;
  }
}
```

### 再接続ロジック

```typescript
async function connectWithRetry(maxRetries: number = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const transport = new StreamableHTTPClientTransport({
        baseURL: 'http://localhost:3000/mcp'
      });
      await mcpClient.connect(transport);
      console.log('Connected successfully');
      return;
    } catch (err) {
      console.error(`Connection attempt ${attempt} failed:`, err);
      if (attempt < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
      } else {
        throw new Error('Max retries reached');
      }
    }
  }
}
```

---

## Notification/Requestハンドリング

### Notificationハンドラー（Server→Client通知）

```typescript
import { z } from 'zod';

// Tool一覧変更通知
const ToolListChangedSchema = z.object({
  method: z.literal('notifications/tools/list_changed'),
  params: z.object({}).passthrough().optional()
});

mcpClient.setNotificationHandler(
  ToolListChangedSchema,
  async () => {
    console.log('Tool list updated. Refreshing...');

    // Toolを再取得してLLMに提供
    callableTool = mcpToTool(mcpClient);
    chat = genAI.chats.create({
      model: 'gemini-2.5-flash',
      config: { tools: [callableTool] },
      history: chat.history // 会話履歴保持
    });
  }
);

// Resource更新通知
const ResourceUpdatedSchema = z.object({
  method: z.literal('notifications/resources/updated'),
  params: z.object({
    uri: z.string(),
    title: z.string().optional()
  })
});

mcpClient.setNotificationHandler(
  ResourceUpdatedSchema,
  async (notification) => {
    console.log(`Resource updated: ${notification.params.uri}`);
    // 必要に応じてResource再読み込み
  }
);
```

### Requestハンドラー（Server→Client要求）

```typescript
// Sampling要求（Server-Side Sampling）
const SamplingRequestSchema = z.object({
  method: z.literal('sampling/createMessage'),
  params: z.object({
    messages: z.array(z.object({
      role: z.string(),
      content: z.object({
        type: z.literal('text'),
        text: z.string()
      })
    }))
  })
});

mcpClient.setRequestHandler(
  SamplingRequestSchema,
  async (request) => {
    // ServerからのLLM呼び出し要求に応答
    const response = await genAI.models.generateContent({
      model: 'gemini-2.0-flash',
      contents: request.params.messages[0].content.text
    });

    return {
      role: 'assistant',
      content: {
        type: 'text',
        text: response.text
      }
    };
  }
);

// Elicitation要求（ユーザー入力要求）
const ElicitationRequestSchema = z.object({
  method: z.literal('elicitation/create'),
  params: z.object({
    message: z.string(),
    requestedSchema: z.any()
  })
});

mcpClient.setRequestHandler(
  ElicitationRequestSchema,
  async (request) => {
    console.log(`Server requests input: ${request.params.message}`);

    // ユーザーから入力取得（例: readline）
    const userInput = await getUserInput(request.params.requestedSchema);

    return {
      action: 'accept',
      content: userInput
    };
  }
);

// Roots要求（Client環境情報提供）
const RootsListRequestSchema = z.object({
  method: z.literal('roots/list'),
  params: z.object({}).passthrough().optional()
});

mcpClient.setRequestHandler(
  RootsListRequestSchema,
  async () => {
    return {
      roots: [
        {
          uri: 'file:///home/user/project',
          name: 'Project Root'
        }
      ]
    };
  }
);
```

---

## LLM統合パターン

### システムプロンプト設計

```typescript
const systemPrompt = `
You are a helpful assistant for a SQL database.

**Your Operating Procedure:**
1. **Prioritize Internal Documentation:** For any question about how to use the database, use the 'query_docs' tool first.
2. **Use Multiple Tools:** You may need to call multiple tools sequentially to accomplish a task.
3. **Be Transparent:** If you use external tools, inform the user.
4. **Synthesize, Don't Just Recite:** Provide clear, concise answers based on tool outputs.

**Available Tools:**
- listTables: Lists all database tables
- queryTable: Queries a specific table
- getSchema: Retrieves table schema

**Do NOT:**
- Assume tools exist that are not listed above
- Make up data or schemas
`;

const chat = genAI.chats.create({
  model: 'gemini-2.5-flash',
  config: { tools: [callableTool] },
  history: [
    { role: 'user', parts: [{ text: systemPrompt }] },
    { role: 'model', parts: [{ text: 'Understood. I will use the available tools.' }] }
  ]
});
```

### Tool提供とResult合成

```typescript
async function processWith MCPTools(userInput: string) {
  // Step 1: LLMに質問送信
  const response = await chat.sendMessage(userInput);

  // Step 2: Tool呼び出しループ
  while (response.functionCalls && response.functionCalls.length > 0) {
    const toolResults = await Promise.all(
      response.functionCalls.map(async (fc) => {
        const result = await mcpClient.callTool({
          name: fc.name,
          arguments: fc.args
        }, CallToolResultSchema);

        return {
          functionResponse: {
            name: fc.name,
            response: result.content
          }
        };
      })
    );

    // Step 3: Tool結果をLLMに返す
    const followUp = await chat.sendMessage(toolResults);

    if (!followUp.functionCalls || followUp.functionCalls.length === 0) {
      return followUp.text;
    }
  }

  return response.text;
}
```

---

## Agentic RAGパターン

Agentic RAGシステムでは、ClientがLLMの推論に基づいて複数のMCP Toolを動的に選択・実行し、情報を統合します。

### マルチツール連携（検索→取得→合成）

```typescript
async function agenticRAG(query: string) {
  // Step 1: LLMがクエリ分析＆Tool選択
  const response = await chat.sendMessage(query);

  // Step 2: 検索Tool呼び出し
  const searchResult = await mcpClient.callTool({
    name: 'search_docs',
    arguments: { query }
  }, CallToolResultSchema);

  const searchContent = searchResult.content[0]?.text || '';

  // Step 3: 検索結果が不十分ならWeb検索にフォールバック
  if (searchContent.includes('No relevant information')) {
    console.log('Falling back to web search...');
    const webResult = await mcpClient.callTool({
      name: 'search_web',
      arguments: { query }
    }, CallToolResultSchema);

    searchContent = webResult.content[0]?.text || '';
  }

  // Step 4: 結果をLLMに返して合成
  const synthesized = await chat.sendMessage([
    {
      functionResponse: {
        name: 'search_docs',
        response: searchContent
      }
    }
  ]);

  return synthesized.text;
}
```

### ツール優先順位制御

```typescript
const systemPrompt = `
**Your Operating Procedure:**
1. **Prioritize Internal Documentation:** For any question, MUST use 'query_react_docs' tool first.
2. **Use the Web as a Targeted Fallback:** ONLY use 'search_web_for_updates' if 'query_react_docs' returns no relevant information.
3. **Be Transparent:** If you use the web search tool, inform the user.
`;

async function smartToolSelection(userInput: string) {
  // 1. まず内部ドキュメント検索
  const docResult = await mcpClient.callTool({
    name: 'query_react_docs',
    arguments: { query: userInput }
  }, CallToolResultSchema);

  const docContent = docResult.content[0]?.text || '';

  // 2. 結果が不十分なら判定
  const insufficientInfo = docContent.includes('No relevant information found');

  if (insufficientInfo) {
    // 3. Web検索にフォールバック
    const webResult = await mcpClient.callTool({
      name: 'search_web_for_updates',
      arguments: { query: userInput }
    }, CallToolResultSchema);

    docContent = `[Internal docs had no info. Searched the web]\n\n${webResult.content[0]?.text}`;
  }

  // 4. LLMで合成
  const response = await genAI.models.generateContent({
    model: 'gemini-2.0-flash',
    contents: `Based on this information: ${docContent}\n\nAnswer: ${userInput}`
  });

  return response.text;
}
```

---

## ベストプラクティス

| 原則 | 説明 |
|------|------|
| **Capability宣言の正確性** | 実装したハンドラーに対応するCapabilityのみ宣言 |
| **1 Client = 1 Server** | 複数サーバー利用時は独立したClientインスタンス作成 |
| **エラーハンドリング** | タイムアウト、再接続、isErrorフラグの確認 |
| **Notification対応** | listChanged通知を受信してLLM再初期化 |
| **システムプロンプト設計** | Tool一覧、優先順位、制約を明示 |
| **Agentic思考** | LLMにTool選択ロジックを委譲（ReActパターン） |
| **Resource効率化** | ResourceLink活用で大容量コンテンツ遅延読み込み |
| **セキュリティ** | API Keyは環境変数管理 |

---

## 参考リンク

- [@modelcontextprotocol/sdk Client API](https://modelcontextprotocol.io/docs/client)
- [Google Gemini SDK](https://ai.google.dev/gemini-api/docs)
- [MCP Specification](https://spec.modelcontextprotocol.io)
- [Agentic RAG Patterns](https://arxiv.org/abs/2005.11401)
