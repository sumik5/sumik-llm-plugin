# 進化するシステムの型安全性

> Contract drift検出・runtime validation・vendor abstraction・discriminated unionsによる長期型安全パターン

## 目次

1. [Contract Driftの検出と対処](#1-contract-driftの検出と対処)
2. [明示的な契約の定義](#2-明示的な契約の定義)
3. [Runtime Validation Gate](#3-runtime-validation-gate)
4. [Vendor Abstraction（Anti-Corruption Layer）](#4-vendor-abstractionanti-corruption-layer)
5. [Discriminated Unionsによるバリアント管理](#5-discriminated-unionsによるバリアント管理)
6. [型安全なAPIクライアント（複数エンドポイント）](#6-型安全なapiクライアント複数エンドポイント)
7. [契約駆動開発（OpenAPI → Orval）](#7-契約駆動開発openapi--orval)
8. [判断テーブル：型共有 vs 明示的契約](#8-判断テーブル型共有-vs-明示的契約)

---

## 1. Contract Driftの検出と対処

### 問題パターン：暗黙的な契約

PoC段階でよく見られる「開発者の頭の中にしか存在しない契約」。

```typescript
// ❌ PoC段階：型のない境界
// backend
app.post('/api/chat', (req, res) => {
  const messages = req.body.messages; // untyped JSON
  res.json({ reply: `You said: ${messages?.[messages.length - 1]?.content ?? ''}` });
});

// frontend
const [messages, setMessages] = useState<any[]>([]);
const data = await res.json(); // 型なし
setMessages([...updated, { role: 'assistant', content: data.reply }]);
```

### Contract Driftが発生する瞬間

バックエンドが `reply: string` → `reply: object` に変更しても、**フロントエンドのビルドは通る**。なぜなら `any` と型なし `res.json()` により、TypeScriptが検証できる情報がゼロだから。

**危険な誤解**：ビルドが通る ≠ TypeScriptが変更を承認した

### Contract Drift検出チェックリスト

- [ ] `useState<any[]>` や `useState<any>` が使われていないか
- [ ] `res.json()` の戻り値を型なしで使用していないか
- [ ] `req.body` を `unknown` にキャストせず直接使用していないか
- [ ] バックエンドとフロントエンドで型定義が**共有されず**それぞれ別に定義されていないか
- [ ] API契約がコードではなくドキュメント/口頭でしか存在しないか

---

## 2. 明示的な契約の定義

### パターン：共有型ライブラリ

型共有は「ツールよりマインドセット」。重要なのは**境界の両側が同じ定義を参照すること**。

```typescript
// libs/chat-contract/index.ts
// ✅ ドメイン（自社の概念）を表現する。ベンダーの構造をミラーしない
export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface ChatRequest {
  messages: ChatMessage[];
}

export interface ChatReference {
  title: string;
  url: string;
}

export interface FollowUpQuestion {
  question: string;
}

export interface ChatReply {
  message: ChatMessage;
  references: ChatReference[];
  followUps: FollowUpQuestion[];
}

export interface ChatResponse {
  reply: ChatReply;
}
```

### 重要な設計原則

> **共有型はドメインを表現する。ベンダーの構造をミラーしてはならない。**

OpenAIResponseやAnthropicResponseをそのまま共有型にすると、プロバイダー変更のたびにフロントエンド修正が必要になる。

### 共有型導入後の変化

```typescript
// ✅ 型安全なフロントエンド呼び出し
const [messages, setMessages] = useState<ChatMessage[]>([]);

async function postChat(request: ChatRequest): Promise<ChatResponse> {
  const res = await fetch('/api/chat', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(request),
  });
  const data = (await res.json()) as ChatResponse;
  return data;
}
```

この時点で `reply` を文字列として扱おうとすると、TypeScriptがビルドで止める。

---

## 3. Runtime Validation Gate

### 問題：型は実行時データを検証しない

共有型を導入しても、ネットワーク越しのデータは依然として `unknown`。

- プロキシによるレスポンス改変
- デプロイのバージョン混在
- バックエンドのバグによる不正なshape

**正しいメンタルモデル**：ネットワークを越えるすべてのデータは、検証されるまで `unknown`。

### パターン：型ガードによるバリデーション

```typescript
// libs/chat-contract/guards.ts

// ベースとなるrecordチェック
export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

// ドメイン型ガード
import type { ChatMessage, ChatRequest, ChatResponse } from './chat-contract';

export function isChatMessage(value: unknown): value is ChatMessage {
  if (!isRecord(value)) return false;
  const role = value.role;
  return (
    (role === 'user' || role === 'assistant') &&
    typeof value.content === 'string'
  );
}

export function isChatRequest(value: unknown): value is ChatRequest {
  if (!isRecord(value)) return false;
  if (!Array.isArray(value.messages)) return false;
  return value.messages.every(isChatMessage);
}

export function isChatResponse(value: unknown): value is ChatResponse {
  if (!isRecord(value)) return false;
  if (!isRecord(value.reply)) return false;
  const reply = value.reply;
  if (!isRecord(reply.message)) return false;
  if (!isChatMessage(reply.message)) return false;
  if (!Array.isArray(reply.references)) return false;
  if (!Array.isArray(reply.followUps)) return false;
  return true;
}
```

### Zodを使ったRuntimeValidation（実務パターン）

手書き型ガードの代わりにZodを使うと保守性が上がる。

```typescript
import { z } from 'zod';

const ChatMessageSchema = z.object({
  role: z.enum(['user', 'assistant']),
  content: z.string(),
});

const ChatReferenceSchema = z.object({
  title: z.string(),
  url: z.string().url(),
});

const ChatReplySchema = z.object({
  message: ChatMessageSchema,
  references: z.array(ChatReferenceSchema),
  followUps: z.array(z.object({ question: z.string() })),
});

const ChatResponseSchema = z.object({
  reply: ChatReplySchema,
});

// TypeScript型をスキーマから導出（型の二重定義を防ぐ）
export type ChatMessage = z.infer<typeof ChatMessageSchema>;
export type ChatResponse = z.infer<typeof ChatResponseSchema>;

// バックエンドの境界
app.post('/api/chat', (req, res) => {
  const body: unknown = req.body;
  const parsed = ChatRequestSchema.safeParse(body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.format() });
    return;
  }
  // ここから先は型安全
  const last = parsed.data.messages[parsed.data.messages.length - 1];
  // ...
});

// フロントエンドの境界
async function postChat(request: ChatRequest): Promise<ChatResponse> {
  const res = await fetch('/api/chat', { /* ... */ });
  const data: unknown = await res.json();
  const parsed = ChatResponseSchema.safeParse(data);
  if (!parsed.success) {
    throw new Error(`Invalid ChatResponse: ${parsed.error.message}`);
  }
  return parsed.data;
}
```

### Runtime Validation Gateチェックリスト

- [ ] バックエンドの `req.body` を `unknown` として扱い、使用前に検証しているか
- [ ] フロントエンドの `res.json()` を `unknown` として扱い、検証後に型付けしているか
- [ ] バリデーション失敗時に明確なエラーを返しているか（サイレント失敗でなく）
- [ ] 型ガード/Zodスキーマがドメイン型定義と同期しているか

---

## 4. Vendor Abstraction（Anti-Corruption Layer）

### 問題：ベンダー型の漏洩

複数LLMプロバイダー対応時に誤りやすいパターン：

```typescript
// ❌ ベンダー型を共有型にするとプロバイダー変更がフロントエンドに波及する
import { OpenAI } from 'openai';
export type SharedResponse = OpenAI.Chat.Completions.ChatCompletion;
```

### パターン：Strategyパターン + Adapterパターン

```typescript
// ✅ インターフェースはドメイン型のみを参照する
import type { ChatMessage, ChatReply } from '@acme/chat-contract';

// プロバイダーインターフェース（Strategy）
export interface LlmProvider {
  generateReply(messages: ChatMessage[]): Promise<ChatReply>;
}

// 各プロバイダーが内部でベンダーSDKをラップ（Adapter）
class ProviderA implements LlmProvider {
  async generateReply(messages: ChatMessage[]): Promise<ChatReply> {
    // ProviderA SDKを呼び出し、結果をChatReply形式に変換
    const vendorResult = await providerAClient.complete(/* ... */);
    return adaptVendorResultToChatReply(vendorResult);
  }
}

class ProviderB implements LlmProvider {
  async generateReply(messages: ChatMessage[]): Promise<ChatReply> {
    // ProviderB SDKを呼び出し、結果をChatReply形式に変換
    const vendorResult = await providerBClient.generate(/* ... */);
    return adaptVendorResultToChatReply(vendorResult);
  }
}

// Factoryがランタイムでプロバイダーを選択
export function createProvider(name: string): LlmProvider {
  switch (name) {
    case 'provider-a': return new ProviderA();
    case 'provider-b': return new ProviderB();
    default: throw new Error(`Unknown provider: ${name}`);
  }
}

// バックエンドハンドラはインターフェースのみに依存（プロバイダー非依存）
app.post('/api/chat', async (req, res) => {
  const provider = createProvider(process.env.LLM_PROVIDER ?? 'provider-a');
  const reply = await provider.generateReply(body.messages);
  res.json({ reply });
});
```

### 「安定した境界」の原則

> 揮発性（変わりやすいもの）をインターフェースの裏側に隔離する。
> コアアプリケーションはベンダー固有のJSONに依存しない。

---

## 5. Discriminated Unionsによるバリアント管理

### 問題：オプショナルフィールドの罠

```typescript
// ❌ オプショナルフィールドは「何でもある可能性」を表現してしまう
interface ChatResponse {
  reply: ChatReply;
  citations?: Citation[];      // あるかもしれない
  followUps?: FollowUpQuestion[]; // あるかもしれない
  error?: string;              // あるかもしれない
}
// → どの組み合わせが有効なのか不明
```

### パターン：Discriminated Union

```typescript
// ✅ 有効な状態のみを型として表現する
export interface Citation {
  sourceTitle: string;
  url: string;
}

export type ChatResponse =
  | { kind: 'answer'; reply: ChatReply }
  | { kind: 'answer-with-citations'; reply: ChatReply; citations: Citation[] }
  | { kind: 'rate-limited'; retryAfter: number };
```

### 網羅性チェック（Exhaustive Checking）

```typescript
// ✅ switch + never で将来のバリアント追加を漏れなく強制する
function renderResponse(response: ChatResponse): React.ReactNode {
  switch (response.kind) {
    case 'answer':
      return <div>{response.reply.message.content}</div>;

    case 'answer-with-citations':
      return (
        <>
          <div>{response.reply.message.content}</div>
          {response.citations.map(c => (
            <a key={c.url} href={c.url}>{c.sourceTitle}</a>
          ))}
        </>
      );

    case 'rate-limited':
      return <div>Rate limited. Retry after {response.retryAfter}s</div>;

    default: {
      // このnever代入が、見逃したバリアントをビルドエラーにする
      const _exhaustive: never = response;
      return _exhaustive;
    }
  }
}
```

**なぜneverチェックが機能するか**：新バリアントが追加されてswitchが更新されないと、未処理の型がdefaultブランチに流れ込み、`never` への代入がコンパイルエラーになる。これにより不完全なロジックがコンパイルを通過できなくなる。

### Discriminated Union設計チェックリスト

- [ ] オプショナルフィールドを多用している箇所で「有効な状態の組み合わせ」を見直す
- [ ] `kind` / `type` / `tag` などの文字列リテラル型でdiscriminatorを設ける
- [ ] switchのdefaultブランチで `never` による網羅性チェックを行う
- [ ] 新バリアント追加時にすべてのswitch文がコンパイルエラーで検出されることを確認

---

## 6. 型安全なAPIクライアント（複数エンドポイント）

### 問題：型キャストの拡散

```typescript
// ❌ as SomeType のキャストが各所に散らばる = サイレントな型の嘘
const data = (await res.json()) as ChatResponse;    // エンドポイントAで
const user = (await res.json()) as UserResponse;    // エンドポイントBで
// → キャストは型安全性を無効化する
```

### パターン：ルートマップ型

エンドポイントリテラルと型を対応付けるマッピング型を定義する。

```typescript
// エンドポイントとリクエスト/レスポンス型のマッピング
import type { ChatRequest, ChatResponse } from '@acme/chat-contract';

type ApiRoutes = {
  '/api/chat': {
    req: ChatRequest;
    res: ChatResponse;
  };
  '/api/health': {
    req: undefined;
    res: { ok: true };
  };
};

// ジェネリクスでエンドポイントリテラルから型を決定
async function postJson<K extends keyof ApiRoutes>(
  path: K,
  body: ApiRoutes[K]['req']
): Promise<ApiRoutes[K]['res']> {
  const res = await fetch(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  return (await res.json()) as ApiRoutes[K]['res'];
}

// 使用例：エンドポイントパスが型を決定する
const response = await postJson('/api/chat', { messages: [...] });
// response は ChatResponse 型として推論される
```

このパターンにより「間違ったエンドポイントを呼び出して正しい型を偽装する」ことがコンパイル時に不可能になる。

---

## 7. 契約駆動開発（OpenAPI → Orval）

### ワークフロー概要

```
OpenAPI仕様 (openapi.yml)
    ↓  npx orval
TypeScript型 + React Query hooks 自動生成
    ↓
バックエンド・フロントエンド両方が同一型を参照
```

### Step 1: OpenAPI仕様の定義

コードを書く前にAPI仕様を定義する（契約ファースト）。

```yaml
# apps/backend/src/openapi.yml
openapi: 3.0.3
info:
  title: MyApp API
  version: 1.0.0
paths:
  /users:
    post:
      tags: [users]
      summary: Register user
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateUser'
      responses:
        '201':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserResponse'
components:
  schemas:
    CreateUser:
      type: object
      required: [name, email, password]
      properties:
        name: { type: string }
        email: { type: string, format: email }
        password: { type: string }
    UserResponse:
      type: object
      properties:
        id: { type: string, format: uuid }
        name: { type: string }
        email: { type: string }
```

**契約ファーストの利点**：
- バックエンド/フロントエンドの**並行開発**が可能（フロントはモックデータで進められる）
- 型を手動で二重定義しない
- バックエンドのリファクタリングがフロントエンドの型に自動反映

### Step 2: Orval設定

```bash
npm install --save-dev orval
```

```typescript
// orval.config.ts（基本設定：型のみ生成）
export default {
  myapp: {
    input: './apps/backend/src/openapi.yml',
    output: {
      schemas: './libs/api-types/model',  // 型ファイルの出力先
      target: './libs/api-types',
    },
  },
};
```

```typescript
// orval.config.ts（React Query hooks生成設定）
export default {
  myapp: {
    input: './apps/backend/src/openapi.yml',
    output: {
      target: 'libs/api-client/src/generated',
      client: 'react-query',           // useQuery/useMutation hookを生成
      mode: 'tags',                    // OpenAPIタグごとにファイルを分割
      override: {
        mutator: {
          path: './libs/api-client/src/axios.ts',
          name: 'api',                 // カスタムAxiosインスタンスを使用
        },
      },
      prettier: true,
      index: true,   // index.tsを生成（@myapp/api-clientからまとめてimport可能）
      clean: true,   // 再生成前に古いファイルを削除
    },
  },
};
```

### Step 3: 型安全なAxiosインスタンス

```typescript
// libs/api-client/src/axios.ts
import axios, { AxiosRequestConfig } from 'axios';

const instance = axios.create({ baseURL: '/api' });

// JWTを自動付与するインターセプター
instance.interceptors.request.use((config) => {
  const token = localStorage.getItem('access_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Orvalのmutatorとして使用（res.dataを自動アンラップ）
export const api = <T>(config: AxiosRequestConfig): Promise<T> =>
  instance.request<T>(config).then((res) => res.data);
```

### Step 4: 型生成と使用

```bash
npx orval
# → libs/api-client/src/generated/ に型安全なhooksが生成される
```

```typescript
// 生成されたhookの使用例（型は自動推論される）
import { usePostUsersRegister, useGetJobs } from '@myapp/api-client';

function RegisterForm() {
  const { mutate: register, isPending } = usePostUsersRegister();

  const handleSubmit = (data: CreateUser) => {
    register({ data }, {
      onSuccess: (user) => console.log(user.id), // UserResponse型として推論
    });
  };
}
```

### 生成されるhookの構造

| OpenAPIエンドポイント | 生成されるhook | 型 |
|---------------------|---------------|-----|
| `GET /users` | `useGetUsers()` | `useQuery<UserResponse[]>` |
| `POST /users` | `usePostUsers()` | `useMutation<UserResponse, unknown, { data: CreateUser }>` |
| `GET /jobs/:id` | `useGetJobsId(id)` | `useQuery<JobResponse>` |

---

## 8. 判断テーブル：型共有 vs 明示的契約

| 状況 | 推奨アプローチ |
|------|--------------|
| 1人が両側を実装、短期プロジェクト | 型共有ライブラリ（手書き） |
| チーム規模が大きい、長期運用 | OpenAPI + Orval（契約ファースト） |
| 既存APIにフロントエンドを追加 | まずOpenAPIを後付けで定義 → Orval |
| 複数クライアント（Web/Mobile/CLI） | OpenAPI必須（クライアント間の型一貫性） |
| 外部ベンダーAPIを内部で使用 | Vendor Abstraction（LlmProviderパターン） |
| レスポンスに複数バリアント | Discriminated Union（オプショナル多用を避ける） |
| 複数エンドポイントのAPIクライアント | ルートマップ型（`as`キャスト禁止） |

### 型安全性の段階

```
レベル1: PoC
  → any[] + untyped res.json()
  → 失敗は本番ランタイムで発覚

レベル2: 共有型
  → 型ライブラリ / OpenAPI生成型
  → ビルドエラーで契約崩壊を検出

レベル3: Runtime Gate
  → 型ガード / Zodバリデーション
  → 実行時の不正データを境界で遮断

レベル4: Vendor Abstraction
  → LlmProviderインターフェース
  → プロバイダー変更を内部に隔離

レベル5: Expressive Modeling
  → Discriminated Unions + 網羅性チェック
  → 無効な状態を型レベルで表現不可能にする
```

**目標**：簡単に起こせるミスを、コンパイルを通過できないミスにすること。
