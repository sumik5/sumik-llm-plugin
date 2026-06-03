# APIレイヤ設計：OpenAPI型生成とReact Queryレイヤ構成

APIクライアントの一元設計、OpenAPIスキーマからの型/検証スキーマ自動生成、React Queryレイヤ（query keys・queries・mutations）の組織化パターン。

> **📌 TanStack Queryの基礎**（`useQuery`/`useMutation`の基本的な使い方・`QueryClientProvider`の設置）は `RI-DATA-MANAGEMENT` を参照。本ドキュメントは **OpenAPI型生成パイプライン** と **APIレイヤの組織化設計** に特化する。

---

## ユーザー確認の原則（AskUserQuestion）

実プロジェクトで以下の判断が必要な場合は、推測せず **AskUserQuestion** でユーザーに確認する。

| 確認すべき場面 | 選択肢の例 |
|---|---|
| OpenAPI型生成ツールの選択 | `@hey-api/openapi-ts`・`openapi-typescript`・`orval`・手書き型定義 |
| データ取得ライブラリの選択 | TanStack Query（React Query）・SWR・Apollo Client・RTK Query |
| ランタイム検証スキーマの生成 | Zod・Valibot・自動生成なし |
| 型生成タイミング | CI/CD自動実行・手動コマンド・ローカルのみ |

**確認不要な場面**（ベストプラクティスが一義的に決まる）：
- APIクライアントの一元化（分散実装はアンチパターン）
- エラーハンドリングの実装（全リクエストに必須）
- query keyの型安全な一元管理

---

## APIクライアントの構築

### 設計原則

生の `fetch` を各コンポーネントやモジュールに分散させず、**中央集権的なAPIクライアント**を構築する。ベースURL・ヘッダー・エラーハンドリングを一箇所に集約することで、全リクエストで一貫した動作を保証する。

```typescript
// src/lib/api.ts

type RequestOptions<TBody = unknown> = {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  headers?: Record<string, string>;
  body?: TBody;
  // クエリパラメータ（例: ?page=1&limit=10）
  params?: Record<string, string | number | boolean | undefined | null>;
};
```

### fetchApi 内部実装

```typescript
// src/lib/api.ts

import { env } from '@/config/env';

async function fetchApi<T, TBody = unknown>(
  url: string,
  options: RequestOptions<TBody> = {},
): Promise<T> {
  const { method = 'GET', headers = {}, body, params } = options;

  // クエリパラメータを含む完全なURLを構築
  const fullUrl = new URL(url, env.API_URL);
  if (params) {
    Object.entries(params).forEach(([key, value]) => {
      if (value != null) {
        fullUrl.searchParams.set(key, String(value));
      }
    });
  }

  const makeRequest = async (): Promise<Response> => {
    try {
      return await fetch(fullUrl, {
        method,
        headers: {
          Accept: 'application/json',
          ...(body ? { 'Content-Type': 'application/json' } : {}),
          ...headers,
        },
        body: body ? JSON.stringify(body) : undefined,
      });
    } catch (error) {
      if (error instanceof TypeError) {
        throw new Error('Network error. Please check your connection.');
      }
      throw error;
    }
  };

  const response = await makeRequest();

  if (!response.ok) {
    let message = response.statusText;
    try {
      const errorData = await response.json();
      message = errorData.message || message;
    } catch {
      // レスポンスボディがJSONでない場合はstatusTextを使用
    }
    throw new Error(message);
  }

  try {
    return await response.json();
  } catch {
    throw new Error('Invalid response from server');
  }
}
```

### HTTPメソッド別インターフェース

```typescript
// src/lib/api.ts

export const api = {
  get<T>(url: string, options?: RequestOptions): Promise<T> {
    return fetchApi<T>(url, { ...options, method: 'GET' });
  },
  post<T, TBody = unknown>(
    url: string,
    body?: TBody,
    options?: RequestOptions,
  ): Promise<T> {
    return fetchApi<T, TBody>(url, { ...options, method: 'POST', body });
  },
  put<T, TBody = unknown>(
    url: string,
    body?: TBody,
    options?: RequestOptions,
  ): Promise<T> {
    return fetchApi<T, TBody>(url, { ...options, method: 'PUT', body });
  },
  patch<T, TBody = unknown>(
    url: string,
    body?: TBody,
    options?: RequestOptions,
  ): Promise<T> {
    return fetchApi<T, TBody>(url, { ...options, method: 'PATCH', body });
  },
  delete<T>(url: string, options?: RequestOptions): Promise<T> {
    return fetchApi<T>(url, { ...options, method: 'DELETE' });
  },
};
```

各メソッドは受け付けるパラメータを型で制限している（例：`get` はボディを受け付けない）。使用例：

```typescript
import { api } from '@/lib/api';

const item = await api.get<Item>('/items/1');
const newItem = await api.post<Item>('/items', { title: 'New Item' });
```

---

## OpenAPIスキーマからの型・検証スキーマ自動生成

> **⚠️ AskUserQuestion**：型生成ツール（`@hey-api/openapi-ts`・`openapi-typescript`・`orval`等）はプロジェクト要件によって最適解が異なる。実プロジェクトでは選択前にユーザーに確認すること。

### なぜ型を自動生成するか

| 比較軸 | 手書き型定義 | OpenAPI型生成 |
|---|---|---|
| 型の信頼性 | API変更に気づけない | APIスペックと常に同期 |
| メンテナンスコスト | 高（毎回手動更新） | 低（コマンド一発で再生成） |
| 型破壊の検出 | TypeScriptが検出できない | 再生成後のtypecheckで即検出 |
| ランタイム検証 | 別途手実装が必要 | Zodスキーマも自動生成可能 |

バックエンドがOpenAPI仕様を公開している場合、**型を手書きせず自動生成**することが推奨される。これによりバックエンドとフロントエンドの間に型レベルの「コントラクト」が確立される。

### ツール設定例

```typescript
// openapi-ts.config.ts

export default {
  input: `${process.env.VITE_API_URL}/doc`,  // OpenAPI仕様のエンドポイント
  output: {
    format: 'prettier',                        // 生成後にPrettierでフォーマット
    path: './src/types/generated',             // 出力先ディレクトリ
  },
  plugins: [
    {
      name: '@hey-api/typescript',             // TypeScript型を生成
      exportFromIndex: false,
    },
    'zod',                                     // Zodスキーマも同時生成
  ],
};
```

```json
// package.json
{
  "scripts": {
    "generate:openapi": "dotenv -e .env -- openapi-ts"
  }
}
```

実行：

```bash
npm run generate:openapi
```

### 生成される型（TypeScript）

```typescript
// src/types/generated/types.gen.ts（自動生成ファイル・手動編集禁止）

export type User = {
  id: string;
  email: string;
  username: string;
  bio: string;
  createdAt: string;
  updatedAt: string;
};

export type Item = {
  id: string;
  title: string;
  description: string;
  tags: Array<string>;
  authorId: string;
  author: UserSummary;
  createdAt: string;
  updatedAt: string;
};
```

### 生成されるZodスキーマ（ランタイム検証）

```typescript
// src/types/generated/zod.gen.ts（自動生成ファイル・手動編集禁止）

export const zUser = z.object({
  id: z.string(),
  email: z.string(),
  username: z.string(),
  bio: z.string(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export const zItem = z.object({
  id: z.string(),
  title: z.string(),
  description: z.string(),
  tags: z.array(z.string()),
  authorId: z.string(),
  author: zUserSummary,
  createdAt: z.string(),
  updatedAt: z.string(),
});
```

TypeScript型はコンパイル時の型安全性を、Zodスキーマはランタイムの検証を担う。両者を組み合わせることでAPIデータの整合性を二重に保証できる。

```typescript
// ランタイム検証の使用例
const item = zItem.parse(rawApiResponse); // 不正データは例外をスロー
```

### 型の同期維持（CI/CD連携）

生成した型はAPIスペックが変わると陳腐化する。CI/CDとの連携で自動同期を確立する：

| 構成 | 自動化方法 |
|---|---|
| フロント・バック同一リポジトリ | APIスペック変更時にCI/CDが型を自動再生成 → typecheckで破壊的変更を検出 |
| 別リポジトリ | バック側のCI/CDがフロント側にPRトリガー → フロントのCI/CDでtypecheck実行 |
| 手動管理 | `npm run generate:openapi` を明示的に実行（変更を忘れるリスクがある） |

同一リポジトリの場合、APIスペック変更 → 型再生成 → typecheck失敗 → 修正要請、という自動ループが確立できる。別リポジトリの場合はPR経由でフロントエンド側に変更を通知し、レビュー後にマージする流れになる。

---

## React Query APIレイヤの組織化

> **⚠️ AskUserQuestion**：TanStack Query以外のデータ取得ライブラリ（SWR・Apollo・RTK Query等）を検討している場合はユーザーに確認すること。

### query keysの設計

React Queryのキャッシュはquery keyで識別される。インライン定義ではなく**feature単位で一元管理**することで、キャッシュの無効化が容易になる。

```typescript
// src/features/items/config/query-keys.ts

import type { GetAllItemsData } from '@/types/generated/types.gen';

export const itemsQueryKeys = {
  all: ['items'] as const,
  lists: () => [...itemsQueryKeys.all, 'list'] as const,
  list: (params?: GetAllItemsData['query']) =>
    [...itemsQueryKeys.lists(), params] as const,
  details: () => [...itemsQueryKeys.all, 'detail'] as const,
  detail: (id: string) => [...itemsQueryKeys.details(), id] as const,
  byUser: (username: string) =>
    [...itemsQueryKeys.all, 'user', username] as const,
} as const;
```

階層構造の効果：

| 無効化対象 | 影響範囲 |
|---|---|
| `itemsQueryKeys.all` | items関連の全クエリ |
| `itemsQueryKeys.lists()` | 一覧系クエリのみ |
| `itemsQueryKeys.detail(id)` | 特定IDの詳細クエリのみ |

### queriesの定義パターン

各クエリは **fetcher + queryOptions factory + custom hook** の3層構造で定義する：

```typescript
// src/features/items/api/get-item-by-id.ts

import { queryOptions, useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import type { GetItemByIdResponse } from '@/types/generated/types.gen';
import {
  zGetItemByIdData,
  zGetItemByIdResponse,
} from '@/types/generated/zod.gen';
import { itemsQueryKeys } from '../config/query-keys';

// 1. Fetcher: APIコールとZodバリデーションを担当
export async function getItemById(id: string): Promise<GetItemByIdResponse> {
  // リクエストパラメータをZodスキーマで検証
  const validatedData = zGetItemByIdData.parse({ path: { id } });

  const response = await api.get<GetItemByIdResponse>(
    `/items/${validatedData.path.id}`,
  );

  // レスポンスをZodスキーマで検証
  return zGetItemByIdResponse.parse(response);
}

// 2. queryOptions factory: クエリ設定を返す純粋関数（SSR統合で再利用できる）
export function getItemByIdQueryOptions(id: string) {
  return queryOptions({
    queryKey: itemsQueryKeys.detail(id),
    queryFn: () => getItemById(id),
  });
}

// 3. Custom hook: コンポーネントから使いやすいインターフェース
export function useItemByIdQuery({
  id,
  options,
}: {
  id: string;
  options?: Omit<
    ReturnType<typeof getItemByIdQueryOptions>,
    'queryKey' | 'queryFn'
  >;
}) {
  return useQuery({
    ...getItemByIdQueryOptions(id),
    ...options, // initialDataなどのオーバーライドを許可
  });
}
```

### mutationsの定義パターン

```typescript
// src/features/items/api/create-item.ts

import {
  mutationOptions,
  useMutation,
  type UseMutationOptions,
} from '@tanstack/react-query';
import { api } from '@/lib/api';
import type {
  CreateItemData,
  CreateItemResponse,
} from '@/types/generated/types.gen';
import { zCreateItemData, zCreateItemResponse } from '@/types/generated/zod.gen';

// 1. Fetcher: バリデーション付きAPIコール
export async function createItem(
  data: CreateItemData['body'],
): Promise<CreateItemResponse> {
  const validatedData = zCreateItemData.parse({ body: data });
  const response = await api.post<CreateItemResponse>('/items', validatedData.body);
  return zCreateItemResponse.parse(response);
}

// 2. mutationOptions factory
export function getCreateItemMutationOptions() {
  return mutationOptions({
    mutationFn: createItem,
  });
}

// 3. Custom hook
export function useCreateItemMutation({
  options,
}: {
  options?: Omit<
    UseMutationOptions<CreateItemResponse, Error, CreateItemData['body']>,
    'mutationFn'
  >;
}) {
  return useMutation({
    ...getCreateItemMutationOptions(),
    ...options,
  });
}
```

| 比較軸 | query | mutation |
|---|---|---|
| 用途 | データ取得（読み取り） | データ変更（作成・更新・削除） |
| 実行タイミング | 自動（マウント時・stale時） | 手動（`mutate` 呼び出し時） |
| キャッシュ | 結果をキャッシュ・再利用 | 成功後に関連クエリを無効化 |

---

## アプリケーションへの統合

### クライアントサイド（基本）

```typescript
// src/routes/dashboard/items/items.tsx

import { useCurrentUserItemsQuery } from '@/features/items/api/get-current-user-items';

export default function MyItemsPage() {
  const itemsQuery = useCurrentUserItemsQuery();
  const items = itemsQuery.data?.data;

  return (
    <ItemsList
      items={items}
      isLoading={itemsQuery.isLoading}
      error={itemsQuery.error}
      emptyMessage="No items yet."
    />
  );
}
```

カスタムフックが `data`・`isLoading`・`error` を返す。React Queryがキャッシュ管理・再取得・エラーハンドリングをすべて処理する。

### サーバーサイド：`initialData`パターン

ローダーでサーバー側取得したデータを、クエリの `initialData` として渡す。ページコンポーネント直下のクエリに適している。

```typescript
// src/routes/items/item.tsx

export async function loader({ params }: Route.LoaderArgs) {
  const item = await getItemById(params.id);
  return routerData({ item });
}

export default function ItemDetailPage({ params, loaderData }: Route.ComponentProps) {
  const itemQuery = useItemByIdQuery({
    id: params.id,
    options: {
      // サーバーデータをinitialDataとして設定（即時表示）
      ...(loaderData?.item && { initialData: loaderData.item }),
    },
  });
  // ...
}

export function ErrorBoundary({ error }: { error: Error }) {
  // ...
}
```

### サーバーサイド：`HydrationBoundary`パターン

ツリー深部のコンポーネントがSSRデータを必要とする場合。prop drilllingを回避できる。

```typescript
// src/routes/items/items.tsx

import { dehydrate, HydrationBoundary } from '@tanstack/react-query';
import { getItemsQueryOptions } from '@/features/items/api/get-items';
import { createQueryClient } from '@/lib/react-query';

export async function loader() {
  const queryClient = createQueryClient();
  // queryOptions factoryを再利用してサーバー側でプリフェッチ
  await queryClient.prefetchQuery(getItemsQueryOptions());
  return routerData({
    dehydratedState: dehydrate(queryClient),  // キャッシュをシリアライズ
  });
}

export default function ItemsPage({ loaderData }: Route.ComponentProps) {
  return (
    // クライアントでキャッシュを復元
    <HydrationBoundary state={loaderData.dehydratedState}>
      <Items />  {/* propなしでSSRデータにアクセス可能 */}
    </HydrationBoundary>
  );
}

function Items() {
  const itemsQuery = useItemsQuery({});  // SSRデータが即座に利用可能
  const allItems = itemsQuery.data?.data || [];
  // ...
}

export function ErrorBoundary({ error }: { error: Error }) {
  // ...
}
```

動作原理：
1. ローダーがサーバーで `prefetchQuery` を実行 → React Queryキャッシュに格納
2. `dehydrate()` でキャッシュをシリアライズしてクライアントに送信
3. `HydrationBoundary` がクライアント側でキャッシュを復元
4. ツリー内の任意のコンポーネントが同じクエリを使えばサーバーデータを即時取得

### MutationとキャッシュをInvalidate

```typescript
// src/routes/dashboard/items/new.tsx

export default function NewItemPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const createItemMutation = useCreateItemMutation({
    options: {
      onSuccess: () => {
        // 関連クエリのキャッシュを無効化 → 自動再取得をトリガー
        queryClient.invalidateQueries({ queryKey: itemsQueryKeys.lists() });
        navigate('/dashboard/items');
      },
    },
  });

  return (
    <div>
      {createItemMutation.error && (
        <ErrorMessage error={createItemMutation.error} />
      )}
      <ItemForm
        onSubmit={createItemMutation.mutate}        // mutateをフォームに渡す
        isSubmitting={createItemMutation.isPending}  // ローディング状態
        onCancel={() => navigate('/dashboard/items')}
      />
    </div>
  );
}
```

mutation成功後に `invalidateQueries` を呼ぶことで、関連するキャッシュが無効化され自動再取得が走る。UIは常に最新データを表示する。

---

## ファイル構成まとめ

```
openapi-ts.config.ts               # OpenAPI型生成設定（プロジェクトルート）

src/
├── lib/
│   ├── api.ts                     # APIクライアント（fetchApiラッパー + api object）
│   └── react-query.ts             # QueryClient設定（createQueryClient）
├── types/
│   └── generated/                 # 自動生成ファイル（手動編集禁止）
│       ├── types.gen.ts           # TypeScript型定義
│       └── zod.gen.ts             # Zodバリデーションスキーマ
└── features/
    └── {feature}/
        ├── api/
        │   ├── get-{resource}.ts      # fetcher + queryOptions factory + hook
        │   └── create-{resource}.ts   # fetcher + mutationOptions factory + hook
        └── config/
            └── query-keys.ts          # query key階層定義（一元管理）
```
