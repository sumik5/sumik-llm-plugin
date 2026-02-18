---
name: developing-mcp
description: >-
  Comprehensive MCP (Model Context Protocol) development guide covering
  architecture (Host/Client/Server roles, Tools/Resources/Prompts, Control Segregation),
  server and client implementation with TypeScript SDK, protocol specification
  (JSON-RPC 2.0, stdio/Streamable HTTP), and security threats
  (Tool Poisoning, Shadowing, Rug Pull, Prompt Injection).
  MUST load when building MCP servers or clients.
  For Claude Code plugin MCP configuration, use plugin-dev:mcp-integration instead.
  For MCP integration with Vercel AI SDK in web apps, see integrating-ai-web-apps.
---

# MCP (Model Context Protocol) 開発ガイド

## 概要

**Model Context Protocol (MCP)** は、AI駆動アプリケーションが外部システム（データベース、API、ファイルシステム等）と連携するための**オープンスタンダード**です。

### MCPが解決する問題: M×N統合地獄

従来、M個のAIモデルとN個のツールを統合するには、**M×N個の個別実装**が必要でした:

- **OpenAI GPT**: JSON Schema形式の独自ツール定義
- **Anthropic Claude**: XML風タグでの記述
- **Google Gemini**: FunctionDeclaration専用SDK

この状況は、開発者に次の負担を強いていました:

- **プラットフォーム固有の知識の学習**: 各モデルプロバイダーの独自仕様を習得
- **重複実装**: 同じツールを複数形式で実装・保守
- **技術的負債**: API変更のたびに全統合箇所を修正
- **イノベーションの阻害**: ツールの共有・再利用が困難

**MCPは、この複雑性を指数関数から線形に削減します:**

- **M+N統合**: 各AIアプリがMCP Client実装を1回、各ツールプロバイダーがMCP Server実装を1回行うだけで、全ての組み合わせが動作
- **標準化による相互運用性**: 1つのMCP Serverを構築すれば、全てのMCP対応クライアント（Cursor、Claude Desktop、カスタムアプリ）で即座に利用可能

### AI-Native時代の基盤プロトコル

MCPは、Kubernetesがcloud-nativeエコシステムの標準となったように、**AI-nativeシステムの共通基盤**として機能します:

- **Composability**: 複数の専門化されたサーバーを組み合わせた複雑なAIシステムの構築
- **Decoupling**: モデルの入れ替えが可能（LLMベンダーロックイン回避）
- **Specialization**: データエンジニアリングチームはMCP Server、AIチームはAgent開発に専念

---

## アーキテクチャ: 3つの役割

MCPは、明確な責務分離に基づく3つの役割で構成されます:

| 役割 | 責務 | 例 |
|-----|------|---|
| **Host** | ユーザー体験の管理、セッション状態の保持、サーバー接続の設定、**Capabilityへのアクセス制御** | Cursor IDE、Claude Desktop、カスタムWebアプリ |
| **Client** | Host内部の専門コンポーネント。**1つのServerとの通信を担当**。プロトコルメッセージの送受信、Capability Discovery | HostがN個のServerに接続する場合、N個のClientを内部的に生成 |
| **Server** | 外部Capabilityの提供者。Tools/Resources/Promptsを標準インターフェースで公開 | mcp-server-sqlite、mcp-server-github、カスタムサーバー |

### 責務の詳細

#### Host（指揮者）

1. **ユーザー体験管理**: チャットUI、会話履歴の表示
2. **セッション状態保持**: 全ての会話ターン、ツール呼び出し履歴を記録（LLMが文脈を保持するために必須）
3. **接続設定**: `.mcp.json`等でサーバー一覧を管理し、Client生成を制御
4. **Capability制御（最重要）**:
   - **Resource提供**: 現在のIDE状態に応じて、AIがアクセス可能なファイルを動的に制限
   - **Human-in-the-Loop承認**: AIが危険なツール（削除、メール送信等）を呼び出す前に、ユーザーに確認ダイアログを表示

#### Client（外交官）

1. **接続ライフサイクル管理**: Transport選択（stdio/Streamable HTTP）、接続確立、エラーリカバリー
2. **メッセージシリアライズ**: Host側のネイティブオブジェクト ↔ JSON-RPC 2.0メッセージの変換
3. **Dynamic Capability Discovery**: Server接続時に`mcp/discover`リクエストを送信し、利用可能なTools/Resources/Promptsのリストを取得・パース

#### Server（専門家）

1. **Capability広告**: Discovery応答で、自身が提供するTools/Resources/Promptsを詳細に記述（LLMが読む説明文が重要）
2. **リクエスト処理**: `tools/call`等のメッセージを受信 → 内部ロジック実行 → 標準フォーマットで結果を返却
3. **デプロイの柔軟性**: ローカルスクリプト（stdio）から、Kubernetes上のマイクロサービス（Streamable HTTP）まで対応

---

## コアCapability: Control Segregation原則

MCPの設計哲学の核心は、**誰が/何が制御するか**を明確に分離することです:

### 1. Tools: Model Control（モデルが制御）

**定義**: AIが自律的に呼び出す**実行可能な関数**。副作用を持つアクションを表現。

**制御者**: **AIモデル自身**が推論に基づいて選択・実行

**使用例**:
- `search_npm(package_name)`: npmレジストリからパッケージ情報を取得
- `run_on_replicate(model_id, input)`: 機械学習モデルを実行
- `query_github_repo(repo_url, question)`: GitHubリポジトリに対してクエリ

**実装パターン（TypeScript SDK）**:
```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from 'zod';

server.registerTool(
  "getNpmPackageInfo",
  {
    title: "NPM Package Info",
    description: "Fetches primary information for a given public package from the npm registry.",
    inputSchema: {
      packageName: z.string().describe("The name of the package on npm (e.g., 'react').")
    }
  },
  async ({ packageName }) => {
    try {
      const response = await axios.get(`https://registry.npmjs.org/${packageName}`);
      return {
        content: [{
          type: "text",
          text: `Package: ${response.data.name}\nVersion: ${response.data['dist-tags']?.latest}`
        }]
      };
    } catch (error) {
      return { content: [{ type: "text", text: `Error: ${error.message}` }], isError: true };
    }
  }
);
```

**高度な機能**:
- **ResourceLink**: 大量データを参照で返す（全コンテンツを返さない）
- **Server-Side Sampling**: サーバー側でクライアントのLLMを呼び出し（`server.createMessage`）

### 2. Resources: Application Control（アプリケーションが制御）

**定義**: **読み取り専用**のデータソース。AIに事実情報を安全に提供。

**制御者**: **Hostアプリケーション**が、ユーザーの状況に応じて提供範囲を決定

**使用例**:
- ファイルシステム（安全なディレクトリ内のみ）
- SQLiteデータベースレコード
- Webページコンテンツ

**実装パターン（動的リソース + パストラバーサル対策）**:
```typescript
import { ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import path from 'path';

server.registerResource(
  "project-file",
  new ResourceTemplate("file://{filePath}", {
    complete: {
      filePath: async (value) => {
        const safeBasePath = path.resolve('/var/data/project');
        const entries = await fs.readdir(safeBasePath);
        return entries.filter(entry => entry.startsWith(value));
      }
    }
  }),
  {
    title: "Project File",
    description: "Reads the content of a file from the project directory."
  },
  async (uri, { filePath }) => {
    const safeBasePath = path.resolve('/var/data/project');
    const resolvedPath = path.resolve(path.join(safeBasePath, filePath));

    // セキュリティチェック（必須）
    if (!resolvedPath.startsWith(safeBasePath)) {
      throw new Error("Access denied. Path is outside the allowed directory.");
    }

    const text = await fs.readFile(resolvedPath, 'utf-8');
    return { contents: [{ uri: uri.href, text }] };
  }
);
```

### 3. Prompts: User Control（ユーザーが制御）

**定義**: 会話のテンプレート。AIの振る舞い・ペルソナを設定。

**制御者**: **ユーザー**（またはユーザーの意図を代行するHostアプリ）が、UIから明示的に選択

**使用例**:
- "Code Reviewer Persona": AIをシニアエンジニアとして振る舞わせる
- "Technical Writer Mode": ドキュメント作成スタイルを適用

**実装パターン（引数付きテンプレート）**:
```typescript
import { completable } from "@modelcontextprotocol/sdk/server/completable.js";

server.registerPrompt(
  "codeReviewerPersona",
  {
    title: "Code Reviewer Persona",
    description: "Sets up the AI to act as a meticulous code reviewer.",
    argsSchema: {
      language: z.string().describe("The programming language for the persona."),
      expertise: completable(
        z.enum(['junior', 'senior', 'principal']).default('senior'),
        (value) => ['junior', 'senior', 'principal'].filter(level => level.startsWith(value))
      )
    }
  },
  ({ language, expertise }) => ({
    messages: [{
      role: "system",
      content: {
        type: "text",
        text: `You are a ${expertise}-level software engineer specializing in ${language}. Your task is to provide a rigorous and constructive review of the code you are about to see.`
      }
    }]
  })
);
```

---

## Tools vs Resources vs Prompts 選択基準

| 判断基準 | Tools | Resources | Prompts |
|---------|-------|----------|---------|
| **目的** | アクション実行・副作用 | 読み取り専用データ提供 | 振る舞い・ペルソナ設定 |
| **制御者** | Model（AI自律判断） | Application（Hostが決定） | User（明示的選択） |
| **呼び出しタイミング** | 推論による自発的呼び出し | Hostがproactive/on-demandで提供 | ユーザーがUIから選択 |
| **SDKメソッド** | `registerTool()` | `registerResource()` | `registerPrompt()` |
| **Handler戻り値** | `{ content: ContentPart[], isError?: boolean }` | `{ contents: ResourceContent[] }` | `{ messages: Message[] }` |
| **設計原則** | AIにAgencyを付与 | 安全なコンテキスト提供 | 会話構造化 |

**選択例**:
- データベースクエリ実行 → **Tool**（AIが必要に応じて呼び出す）
- プロジェクトファイル内容 → **Resource**（Hostが安全な範囲で提供）
- コードレビューモード → **Prompt**（ユーザーが「レビュー開始」ボタンから選択）

---

## Quick Start

### 最小限のMCP Server（TypeScript）

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from 'zod';

const server = new McpServer({
  name: "hello-mcp",
  version: "1.0.0"
});

server.registerTool(
  "greet",
  {
    description: "Greets a user by name.",
    inputSchema: { name: z.string() }
  },
  async ({ name }) => ({
    content: [{ type: "text", text: `Hello, ${name}!` }]
  })
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

**実行方法**:
```bash
# package.json で "type": "module" 設定必須
node server.js
```

### HostからServerへの接続設定（`.mcp.json`例）

```json
{
  "mcpServers": {
    "hello-mcp": {
      "command": "node",
      "args": ["/path/to/server.js"]
    }
  }
}
```

---

## 詳細ガイド

| ファイル | 内容 |
|---------|------|
| [BUILDING-SERVERS.md](./references/BUILDING-SERVERS.md) | MCPサーバー構築（Tool/Resource/Prompt登録、Transport設定、テスト） |
| [BUILDING-CLIENTS.md](./references/BUILDING-CLIENTS.md) | MCPクライアント構築（接続管理、Capability Discovery、マルチサーバー） |
| [PROTOCOL-SPEC.md](./references/PROTOCOL-SPEC.md) | プロトコル仕様（JSON-RPC 2.0、Transport層、メッセージフォーマット） |
| [SECURITY.md](./references/SECURITY.md) | セキュリティ（脅威モデル、Tool Poisoning/Shadowing/Rug Pull、対策） |
| [ECOSYSTEM.md](./references/ECOSYSTEM.md) | エコシステム（レジストリ、ホスト/クライアント一覧、今後の展望） |

---

## ユーザー確認の原則（AskUserQuestion）

MCP開発で判断が必要な場合、**必ずAskUserQuestionで確認**してください:

### 確認すべき典型的シナリオ

1. **Transport選択**: stdio（ローカル）vs Streamable HTTP（リモート）
2. **セキュリティポリシー**: ファイルアクセス範囲、API認証方式
3. **Tool設計**: 特定の操作をToolにするか、Resourceにするか
4. **Server粒度**: 単一の大規模サーバー vs 複数の小規模サーバー

### 質問例テンプレート

```python
AskUserQuestion(
    questions=[{
        "question": "MCPサーバーのデプロイ方法を選択してください",
        "header": "Transport選択",
        "options": [
            {
                "label": "stdio (ローカルプロセス)",
                "description": "開発環境向け。Hostがサーバープロセスを起動・管理"
            },
            {
                "label": "Streamable HTTP (リモートサービス)",
                "description": "本番環境向け。Kubernetes等で独立デプロイ"
            }
        ],
        "multiSelect": False
    }]
)
```

---

## ベストプラクティス

### 1. スキーマ定義

- **Zod必須**: TypeScript開発では必ずZodでスキーマ定義（型安全性 + JSON Schema自動生成）
- **description充実**: LLMが読むため、各フィールドに詳細な説明を付与

### 2. エラーハンドリング

- **isError: trueフラグ**: ツール実行失敗時は必ず設定
- **構造化エラーメッセージ**: エラー内容を明確にテキストで返す（サーバークラッシュ禁止）

### 3. セキュリティ

- **パストラバーサル対策**: ファイルアクセス時は`resolvedPath.startsWith(safeBasePath)`チェック必須
- **入力検証**: 全ての外部入力をZodスキーマで検証
- **最小権限**: Resourceは必要最小限の範囲のみ公開

### 4. パフォーマンス

- **ResourceLink活用**: 大量データはリストでなく参照を返す
- **ページネーション**: リソース一覧は適切にページ分割
- **キャッシング**: 頻繁にアクセスされるデータはサーバー側でキャッシュ

---

## 相互運用性: A2Aプロトコルとの関係

**MCP**: Agent ↔ 外部システム（データ、API）の統合

**A2A (Agent-to-Agent)**: Agent ↔ Agent間の協調作業、タスク委譲、状態同期

**補完的関係**:
```
[研究Agent]
   ├─ A2A → 他のAgentに調査タスク委譲
   └─ MCP → Web検索API、学術データベースに接続
```

---

## まとめ

MCPは、AIシステムと外部世界を接続する**標準化された共通言語**です:

- **M+N統合**: 指数関数的複雑性を線形に削減
- **Control Segregation**: Tools（Model）、Resources（Application）、Prompts（User）の明確な分離
- **AI-Native基盤**: KubernetesがCloud-Nativeの標準となったように、MCPはAI-Nativeの基盤を形成

**実装の第一歩**:
1. TypeScript + Zod + `@modelcontextprotocol/sdk` を選択
2. 単一Toolの最小限サーバーを構築（stdio transport）
3. `.mcp.json`でHostから接続
4. 段階的にResources/Promptsを追加、本番環境ではStreamable HTTPへ移行

詳細は各サブファイル（BUILDING-SERVERS.md等）を参照してください。
