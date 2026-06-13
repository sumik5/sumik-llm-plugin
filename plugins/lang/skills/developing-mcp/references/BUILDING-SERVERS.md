# MCPサーバー構築ガイド

MCPサーバーは、AI AgentがアクセスできるTools・Resources・Promptsを提供する専門コンポーネントです。TypeScript SDK（@modelcontextprotocol/sdk）を使用して、型安全かつ保守性の高いサーバーを構築できます。

---

## 環境セットアップ

### 前提条件

- Node.js 18.x以上
- TypeScript環境

### プロジェクト初期化

```bash
mkdir my-mcp-server
cd my-mcp-server
npm init -y
npm install @modelcontextprotocol/sdk zod sqlite3
npm install --save-dev typescript ts-node @types/node @types/sqlite3
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
  }
}
```

---

## サーバー初期化とCapabilities宣言

### 基本的なサーバー作成

```typescript
import { McpServer } from '@modelcontextprotocol/sdk/server/index.js';

export const server = new McpServer({
  name: 'my-server',
  version: '1.0.0',
  capabilities: {
    tools: { listChanged: true },
    resources: { listChanged: true, subscribe: true },
    prompts: { listChanged: true },
    roots: {},
    elicitation: {}
  }
});
```

### Capabilities設計指針

各Capabilityは宣言的な契約として機能します：

| Capability | 意味 | 用途 |
|-----------|------|------|
| `tools` | Tool提供を宣言 | Agent実行可能な操作 |
| `resources` | Resource提供を宣言 | 読み取り専用データ |
| `prompts` | Prompt提供を宣言 | 会話テンプレート |
| `roots` | Clientからroot取得可能 | Client環境情報要求 |
| `elicitation` | ユーザー入力要求可能 | 対話的データ収集 |

**重要**: 実際に使用するCapabilityのみ宣言してください。未使用Capabilityの宣言は避けましょう。

---

## Tool登録

### 基本的なTool定義

```typescript
import { z } from 'zod';

server.registerTool(
  'listTables',
  {
    title: 'List Tables',
    description: 'Lists all tables in the database',
    inputSchema: {
      cursor: z.string().optional().describe('Pagination cursor')
    }
  },
  async ({ cursor }) => {
    try {
      const db = getDb();
      const tables = await db.all(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );

      const page = parseInt(cursor ?? '0', 10);
      const pageSize = 10;
      const paginatedTables = tables.slice(page * pageSize, (page + 1) * pageSize);

      return {
        content: [
          { type: 'text', text: `Found ${tables.length} tables` }
        ],
        nextCursor: (page + 1) * pageSize < tables.length ? String(page + 1) : undefined
      };
    } catch (err) {
      return {
        content: [{ type: 'text', text: `Error: ${(err as Error).message}` }],
        isError: true
      };
    }
  }
);
```

### Zodスキーマによる型安全性

```typescript
const CreateTableSchema = z.object({
  tableName: z.string().describe('新規テーブル名'),
  columns: z.string().describe('カラム定義（カンマ区切り）')
});

server.registerTool(
  'createTable',
  {
    title: 'Create Table',
    description: 'Creates a new database table',
    inputSchema: CreateTableSchema
  },
  async ({ tableName, columns }) => {
    const db = getDb(false); // 書き込みモード
    try {
      await db.run(`CREATE TABLE ${tableName} (${columns})`);
      server.server.sendResourceListChanged(); // Notification送信
      return {
        content: [{ type: 'text', text: `Table '${tableName}' created` }]
      };
    } catch (err) {
      return {
        content: [{ type: 'text', text: `Error: ${(err as Error).message}` }],
        isError: true
      };
    } finally {
      await db.close();
    }
  }
);
```

### エラーハンドリングパターン

```typescript
async (args) => {
  const db = getDb();
  try {
    // メイン処理
    const result = await db.all('SELECT * FROM users');
    return {
      content: [{ type: 'text', text: JSON.stringify(result) }]
    };
  } catch (err) {
    return {
      content: [{ type: 'text', text: `Error: ${(err as Error).message}` }],
      isError: true // エラーフラグ必須
    };
  } finally {
    await db.close(); // リソース解放
  }
}
```

---

## Resource登録

### ResourceTemplateパターン

```typescript
import { ResourceTemplate } from '@modelcontextprotocol/sdk/server/index.js';

server.registerResource(
  'table-schema',
  new ResourceTemplate('schema://table/{tableName}', {
    list: async () => {
      const db = getDb();
      try {
        const tables = await db.all(
          "SELECT name FROM sqlite_master WHERE type='table'"
        );
        return {
          resources: tables.map((t: { name: string }) => ({
            uri: `schema://table/${t.name}`,
            name: t.name,
            title: `Schema for ${t.name}`,
            description: `SQL CREATE statement for '${t.name}'`,
            mimeType: 'application/sql'
          }))
        };
      } finally {
        await db.close();
      }
    },
    complete: {
      tableName: async (value) => {
        const db = getDb();
        try {
          const tables = await db.all(
            "SELECT name FROM sqlite_master WHERE type='table'"
          );
          return tables
            .map((t: { name: string }) => t.name)
            .filter((name) => name.startsWith(value));
        } finally {
          await db.close();
        }
      }
    }
  }),
  {
    title: 'Table Schema',
    description: 'Returns SQL CREATE statement for a table',
    annotations: {
      audience: ['user', 'assistant'],
      priority: 0.8
    }
  },
  async (uri, { tableName }) => {
    const db = getDb();
    try {
      const result = await db.all(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name = ?",
        [tableName]
      );
      if (result.length === 0) {
        throw new Error(`Table '${tableName}' not found`);
      }
      return {
        contents: [{ uri: uri.href, text: result[0].sql }]
      };
    } finally {
      await db.close();
    }
  }
);
```

### 重要ポイント

- **list関数は必須**: resources/listリクエストに応答するため
- **completeでオートコンプリート**: IDEでの入力支援
- **annotationsでメタデータ**: audience、priorityで優先順位制御

---

## Prompt登録

### 引数付きPromptテンプレート

```typescript
server.registerPrompt(
  'query-table',
  {
    title: 'Query Table',
    description: 'Constructs SQL query for data retrieval',
    argsSchema: {
      tableName: z.string().describe('テーブル名'),
      columns: z.string().optional().describe('カンマ区切りカラムリスト'),
      filter: z.string().optional().describe('WHERE句'),
      limit: z.string().optional().describe('最大行数')
    }
  },
  async ({ tableName, columns, filter, limit }) => {
    const db = getDb();
    try {
      const columnList = columns || '*';
      let query = `SELECT ${columnList} FROM ${tableName}`;

      if (filter) {
        query += ` WHERE ${filter}`;
      }
      if (limit) {
        const limitNum = parseInt(limit, 10);
        if (isNaN(limitNum) || limitNum <= 0) {
          throw new Error('Limit must be a positive number');
        }
        query += ` LIMIT ${limitNum}`;
      }

      const rows = await db.all(query);
      const tableInfo = await db.all(`PRAGMA table_info(${tableName})`);

      return {
        messages: [
          {
            role: 'user',
            content: {
              type: 'text',
              text: `Query ${tableName} table:\n\nTable Structure:\n${JSON.stringify(tableInfo, null, 2)}\n\nSQL Query: ${query}\n\nResults:\n${JSON.stringify(rows, null, 2)}`
            }
          }
        ]
      };
    } catch (err) {
      return {
        messages: [
          {
            role: 'user',
            content: {
              type: 'text',
              text: `Error querying table ${tableName}: ${(err as Error).message}`
            }
          }
        ]
      };
    } finally {
      await db.close();
    }
  }
);
```

### Prompt引数の制約

MCP仕様上、**すべてのPrompt引数は文字列型**である必要があります。数値も`z.string()`で定義し、ハンドラー内でparseします。

---

## 高度な機能

### Dynamic Capabilities

```typescript
// Tool動的有効化/無効化
const dangerousTool = server.registerTool(
  'executeModification',
  {
    title: 'Execute Modification',
    description: 'Executes UPDATE operations (admin only)',
    inputSchema: {
      operation: z.enum(['UPDATE']),
      tableName: z.string(),
      set: z.string().optional(),
      where: z.string().optional()
    }
  },
  async ({ operation, tableName, set, where }) => {
    const db = getDb(false);
    try {
      if (operation === 'UPDATE') {
        if (!set || !where) {
          throw new Error('UPDATE requires SET and WHERE');
        }
        await db.run(`UPDATE ${tableName} SET ${set} WHERE ${where}`);
        server.server.sendResourceUpdated({
          uri: `schema://table/${tableName}`,
          title: `Schema for ${tableName} (updated)`
        });
      }
      return {
        content: [{ type: 'text', text: `Successfully executed ${operation}` }]
      };
    } catch (err) {
      return {
        content: [{ type: 'text', text: `Error: ${(err as Error).message}` }],
        isError: true
      };
    } finally {
      await db.close();
    }
  }
);

// 初期状態で無効化
dangerousTool.disable();

// ログイン時に有効化
server.registerTool(
  'adminLogin',
  {
    title: 'Admin Login',
    description: 'Enables admin tools',
    inputSchema: { password: z.string() }
  },
  async ({ password }) => {
    if (password === process.env.ADMIN_PASSWORD) {
      await dangerousTool.enable();
      server.server.sendToolListChanged();
      return {
        content: [{ type: 'text', text: 'Admin access granted' }]
      };
    }
    return {
      content: [{ type: 'text', text: 'Invalid password' }],
      isError: true
    };
  }
);
```

### Notifications

```typescript
// Resource一覧変更通知
server.server.sendResourceListChanged();

// 特定Resource更新通知
server.server.sendResourceUpdated({
  uri: 'schema://table/users',
  title: 'Users table (updated)'
});

// Tool一覧変更通知
server.server.sendToolListChanged();
```

### Server-Side Sampling（LLM呼び出し）

```typescript
import { GoogleGenAI } from '@google/genai';

const genAI = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY! });

server.registerTool(
  'generateSummary',
  {
    title: 'Generate Summary',
    description: 'Uses LLM to summarize query results',
    inputSchema: { tableName: z.string() }
  },
  async ({ tableName }) => {
    const db = getDb();
    try {
      const rows = await db.all(`SELECT * FROM ${tableName} LIMIT 10`);

      // LLMで要約生成
      const result = await genAI.models.generateContent({
        model: 'gemini-2.0-flash',
        contents: `Summarize this data: ${JSON.stringify(rows)}`
      });

      return {
        content: [{ type: 'text', text: result.text }]
      };
    } finally {
      await db.close();
    }
  }
);
```

### Elicitation（ユーザー入力要求）

```typescript
import { ElicitResultSchema } from '@modelcontextprotocol/sdk/types.js';

server.registerTool(
  'addUser',
  {
    title: 'Add User',
    description: 'Adds user by asking for name and email',
    inputSchema: {}
  },
  async () => {
    // Clientにユーザー入力を要求
    const userInfo = await server.server.request(
      {
        method: 'elicitation/create',
        params: {
          message: "Please provide new user's information",
          requestedSchema: {
            type: 'object',
            properties: {
              name: { type: 'string', description: "User's full name" },
              email: { type: 'string', description: "User's email" }
            },
            required: ['name', 'email']
          }
        }
      },
      ElicitResultSchema
    );

    if (userInfo.action !== 'accept') {
      return { content: [{ type: 'text', text: 'Cancelled' }] };
    }

    const { name, email } = userInfo.content as { name: string; email: string };

    const db = getDb(false);
    try {
      await db.run('INSERT INTO users (name, email) VALUES (?, ?)', [name, email]);
      server.server.sendResourceListChanged();
      return {
        content: [{ type: 'text', text: `User '${name}' created` }]
      };
    } catch (err) {
      return {
        content: [{ type: 'text', text: `Error: ${(err as Error).message}` }],
        isError: true
      };
    } finally {
      await db.close();
    }
  }
);
```

---

## Transport設定

### stdio Transport（ローカル通信）

```typescript
// src/run-stdio.ts
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { server } from './server.js';

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('MCP server running on stdio');
}

main().catch((error) => {
  console.error('Server failed:', error);
  process.exit(1);
});
```

実行方法:

```bash
npx ts-node src/run-stdio.ts
```

### Streamable HTTP Transport（リモート通信）

```typescript
// src/run-http.ts
import express from 'express';
import { randomUUID } from 'node:crypto';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { isInitializeRequest } from '@modelcontextprotocol/sdk/types.js';
import { server } from './server.js';

const app = express();
app.use(express.json());

const transports: { [sessionId: string]: StreamableHTTPServerTransport } = {};

app.all('/mcp', async (req, res) => {
  const sessionId = req.headers['mcp-session-id'] as string | undefined;
  let transport: StreamableHTTPServerTransport;

  if (sessionId && transports[sessionId]) {
    transport = transports[sessionId];
  } else if (!sessionId && isInitializeRequest(req.body)) {
    transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => randomUUID(),
      onsessioninitialized: (newSessionId) => {
        transports[newSessionId] = transport;
        console.error(`New session: ${newSessionId}`);
      }
    });

    transport.onclose = () => {
      if (transport.sessionId) {
        console.error(`Session closed: ${transport.sessionId}`);
        delete transports[transport.sessionId];
      }
    };

    await server.connect(transport);
  } else {
    res.status(400).json({ error: { message: 'Bad Request' } });
    return;
  }

  await transport.handleRequest(req, res, req.body);
});

const PORT = 3000;
app.listen(PORT, () => {
  console.error(`MCP Server listening on http://localhost:${PORT}/mcp`);
});
```

実行方法:

```bash
npx ts-node src/run-http.ts
```

---

## テストとデバッグ

### MCP Inspectorを使用したテスト

```bash
# Inspector起動
npx @modelcontextprotocol/inspector

# stdio接続設定
Command: ts-node
Arguments: /path/to/src/run-stdio.ts

# HTTP接続設定
Transport: Streamable HTTP
URL: http://localhost:3000/mcp
```

### デバッグパターン

```typescript
// エラーログをstderrに出力（stdoutはMCPプロトコル用）
console.error('Debug info:', someVariable);

// JSON-RPC形式のエラー
return {
  content: [{ type: 'text', text: `Debug: ${JSON.stringify(debugInfo)}` }],
  isError: true
};
```

---

## ベストプラクティス

| 原則 | 説明 |
|------|------|
| **最小権限の原則** | 読み取り専用操作はreadOnlyフラグで強制 |
| **エラーハンドリング** | try-catch-finally必須、isError: true設定 |
| **リソース解放** | finally句でDB接続等を確実にclose |
| **型安全性** | Zodスキーマで入力検証 |
| **Notification活用** | 状態変更時はlistChanged/updatedを送信 |
| **セキュリティ** | パスワード等は環境変数管理 |
| **Transport独立性** | stdio/HTTP両対応の設計 |
| **テスト駆動** | MCP Inspectorで動作確認 |

---

## 参考リンク

- [@modelcontextprotocol/sdk Documentation](https://modelcontextprotocol.io/docs)
- [MCP Specification](https://spec.modelcontextprotocol.io)
- [Zod Schema Validation](https://zod.dev)
- [MCP Inspector](https://github.com/modelcontextprotocol/inspector)
