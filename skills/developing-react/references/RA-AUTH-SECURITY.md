# React 認証・認可・セキュリティ実装ガイド

## 目次

1. [認証（Authentication）](#認証)
   - [APIクライアント拡張](#apiクライアント拡張)
   - [登録・ログイン・ログアウト](#登録ログインログアウト)
   - [ユーザー情報の共有](#ユーザー情報の共有)
   - [ルート保護](#ルート保護)
2. [認可（Authorization / RBAC）](#認可)
3. [コンテンツサニタイズ（XSS対策）](#コンテンツサニタイズ)
4. [セキュリティヘッダ](#セキュリティヘッダ)
5. [判断分岐と AskUserQuestion](#判断分岐と-askuserquestion)

---

## 認証

認証はユーザーの身元を確認するプロセス。実装方式は **セッションベース** と **トークンベース（JWT + Cookie）** が主流で、プロジェクト構成により選択が異なる。

> **⚠️ AskUserQuestion（認証方式）**: 実装前にユーザーに確認すること（[判断分岐](#判断分岐と-askuserquestion) 参照）。

以下では **httpOnly Cookie + トークンベース**（アクセストークン15分 + リフレッシュトークン7日）の実装パターンを示す。

| トークン種別 | 有効期間 | 役割 |
|-------------|---------|------|
| アクセストークン | 短期（例: 15分） | 各APIリクエストでユーザー識別 |
| リフレッシュトークン | 長期（例: 7日） | アクセストークン再発行 |

httpOnly Cookie はJavaScriptからアクセスできないため、XSSによるトークン窃取を防ぐ。ただしCSRF対策として Cookie の `SameSite` 属性を `Lax` または `Strict` に設定すること。

### APIクライアント拡張

クロスオリジンAPIへ Cookie を自動送信するために `credentials: 'include'` を設定する。
401レスポンス時はリフレッシュトークンで自動再認証する。

```typescript
// src/lib/api.ts
async function fetchApi<T, TBody = unknown>(
  url: string,
  options: RequestOptions<TBody> = {},
): Promise<T> {
  const makeRequest = async (): Promise<Response> => {
    return await fetch(fullUrl, {
      ...fetchOptions,
      // クライアントサイドのみ Cookie を自動送信
      credentials: typeof window !== 'undefined' ? 'include' : undefined,
    });
  };

  let response = await makeRequest();

  // 401 時に自動トークンリフレッシュ（ログイン・登録エンドポイントを除く）
  const isAuthError =
    !response.ok &&
    response.status === 401 &&
    !url.endsWith('/auth/login') &&
    !url.endsWith('/auth/register');

  if (isAuthError) {
    try {
      const { accessToken } = await refreshToken(headers.Cookie);
      response = await makeRequest();
    } catch (refreshError) {
      console.warn('Token refresh failed:', refreshError);
    }
  }
  // ...
}
```

**サーバーサイドでの Cookie 送信**: SSR環境ではブラウザが自動送信しないため、ヘッダーに明示的に渡す。

```typescript
const response = await api.get<GetCurrentUserResponse>('/auth/me', {
  headers: { Cookie: cookieHeader ?? '' },
});
```

### 登録・ログイン・ログアウト

各フローは共通パターン（mutation → API呼び出し → Zodバリデーション）で実装する。

```typescript
// 登録: src/features/auth/api/register.ts
export async function registerUser(data: RegisterUserData['body']) {
  const response = await api.post<RegisterUserResponse>('/auth/register', { body: data });
  return zRegisterUserResponse.parse(response);
}
// 成功時: API が httpOnly Cookie にトークンをセット → 即時ログイン状態

// ログイン: src/features/auth/api/login.ts
export async function loginUser(data: LoginUserData['body']) {
  const response = await api.post<LoginUserResponse>('/auth/login', { body: data });
  return zLoginUserResponse.parse(response);
}

// ログアウト: src/features/auth/api/logout.ts
export async function logoutUser() {
  const response = await api.post<LogoutUserResponse>('/auth/logout', { body: {} });
  return zLogoutUserResponse.parse(response);
}
// サーバーサイドで Cookie からトークンをクリア。クライアントのクエリキャッシュも無効化すること
```

各 mutation は `useMutation({ mutationFn: <上記関数> })` でラップして呼び出す。

### ユーザー情報の共有

アプリ全体でユーザー情報を一元管理するために React Router の Middleware を活用する。

#### Middleware（全リクエストでユーザーを取得）

```typescript
// src/app/middleware/user.ts
export const userContext = createContext<CurrentUser | null>();

function hasAuthCookies(request: Request): boolean {
  const cookieHeader = request.headers.get('Cookie');
  if (!cookieHeader) return false;
  return (
    cookieHeader.includes('accessToken=') ||
    cookieHeader.includes('refreshToken=')
  );
}

export const userMiddleware: MiddlewareFunction = async (
  { request, context },
  next,
) => {
  // 既にセットされていればスキップ（重複フェッチ防止）
  try {
    const existingUser = context.get(userContext);
    if (existingUser !== undefined) return next();
  } catch {}

  // Cookie がなければ未認証として続行
  if (!hasAuthCookies(request)) {
    context.set(userContext, null);
    return next();
  }

  try {
    const cookieHeader = request.headers.get('Cookie') || '';
    const user = await getMe(cookieHeader);
    context.set(userContext, user);
  } catch {
    context.set(userContext, null); // エラー時はクラッシュさせず null をセット
  }
  return next();
};
```

#### Root Loader と useUser hook

```typescript
// src/app/root.tsx
export const middleware = [nonceMiddleware, userMiddleware];
export async function loader({ context }: Route.LoaderArgs) {
  return data({ user: context.get(userContext) });
}

// src/features/auth/hooks/use-user.ts
export function useUser() {
  const rootData = useRouteLoaderData<RootLoaderData>('root');
  return rootData?.user ?? null;  // 未認証時は null
}
```

どのコンポーネントからも `useUser()` を呼び出すだけで現在のユーザーを取得できる。

### ルート保護

認証が必要なルートへの未認証アクセスをリダイレクトするミドルウェア。

```typescript
// src/app/middleware/protected.ts
export const protectedMiddleware: MiddlewareFunction = async (
  { context },
  next,
) => {
  const user = context.get(userContext);
  if (!user) throw redirect('/auth/login');
  return next();
};
```

```typescript
// 保護したいレイアウトに適用
// src/app/routes/dashboard/layout.tsx
export const middleware = [protectedMiddleware];

export default function DashboardLayout() { /* ... */ }
```

> **実行順序**: `userMiddleware` → `protectedMiddleware` の順に定義すること。protected は user が取得済みであることを前提とする。

---

## 認可

認可はユーザーが「何をしてよいか」を制御する仕組み。認証（誰であるか）とは別の概念。

> **⚠️ AskUserQuestion（認可モデル）**: 認可モデルはビジネスロジックの権限構造に依存するため、実装前にユーザーに確認すること（[判断分岐](#判断分岐と-askuserquestion) 参照）。

| モデル | 向いている場面 | 複雑度 |
|-------|-------------|--------|
| RBAC（ロールベース） | admin/editor/viewer など固定ロールで権限を管理 | 低〜中 |
| ABAC（属性ベース） | リソース所有者・タグ・時刻など複合条件で権限を制御 | 中〜高 |

以下では **ポリシーベース RBAC**（リソースごとに `can*` 関数を定義）の実装パターンを示す。

### ポリシー定義

```typescript
// src/features/auth/lib/authorization-policies.ts
export const ResourcePolicies = {
  canCreate: (user: CurrentUser | null) => !!user,
  canEdit:   (user: CurrentUser | null, res: { authorId: string }) => user?.id === res.authorId,
  canDelete: (user: CurrentUser | null, res: { authorId: string }) => user?.id === res.authorId,
};

export const ReviewPolicies = {
  canCreate: (
    user: CurrentUser | null,
    res: { authorId: string },
    existing?: Array<{ authorId: string }>,
  ) => {
    if (!user || user.id === res.authorId) return false; // 未認証 or 自分のリソースは不可
    return !existing?.some(r => r.authorId === user.id);  // 重複レビュー不可
  },
  canEdit: (user: CurrentUser | null, review: { authorId: string }) =>
    user?.id === review.authorId,
};
```

### useAuthorization hook

```typescript
// src/features/auth/hooks/use-authorization.ts
export function useAuthorization() {
  const currentUser = useUser();

  return {
    canCreate: () => ResourcePolicies.canCreate(currentUser),
    canEdit: (resource: Resource) =>
      ResourcePolicies.canEdit(currentUser, resource),
    canDelete: (resource: Resource) =>
      ResourcePolicies.canDelete(currentUser, resource),
    canReview: (resource: Resource, reviews?: Review[]) =>
      ReviewPolicies.canCreate(currentUser, resource, reviews),
    canEditReview: (review: Review) =>
      ReviewPolicies.canEdit(currentUser, review),
  };
}
```

### コンポーネントでの使用例

```typescript
const { canCreate, canEdit } = useAuthorization();

return (
  <>
    {canCreate() && <CreateButton />}
    {canEdit(resource) && <EditButton resource={resource} />}
  </>
);
```

> **⚠️ 重要**: クライアントサイドの認可チェックは **UX最適化**（不要なボタンの非表示など）が目的。セキュリティの担保は必ずサーバーサイドでも実施すること。フロントエンドのチェックはバイパス可能。

---

## コンテンツサニタイズ（XSS対策）

**Cross-Site Scripting（XSS）** は、攻撃者がアプリに悪意あるJavaScriptを注入し、他ユーザーのブラウザで実行させる攻撃。ユーザー入力をHTMLとしてレンダリングする際は必ずサニタイズすること。

**この対策は必須のベストプラクティス。AskUserQuestion 不要。**

### DOMPurify による2段階サニタイズ

Markdown → HTML 変換を含むコンテンツレンダリングの実装パターン：

```typescript
// src/components/markdown-renderer.tsx
import DOMPurify from 'isomorphic-dompurify';
import { useMemo } from 'react';
import { remark } from 'remark';
import remarkGfm from 'remark-gfm';
import remarkHtml from 'remark-html';

export function MarkdownRenderer({
  content,
  className = '',
}: {
  content: string;
  className?: string;
}) {
  const htmlContent = useMemo(() => {
    try {
      // Step 1: Markdown → HTML（remark の組み込みサニタイズは無効化し DOMPurify に委譲）
      const result = remark()
        .use(remarkGfm)
        .use(remarkHtml, { sanitize: false })
        .processSync(content);

      // Step 2: DOMPurify でホワイトリストベースのサニタイズ
      return DOMPurify.sanitize(result.toString(), {
        ALLOWED_TAGS: [
          'p', 'br', 'strong', 'em', 'u', 's',
          'code', 'pre',
          'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
          'ul', 'ol', 'li', 'blockquote',
          'a', 'table', 'thead', 'tbody', 'tr', 'th', 'td', 'hr',
        ],
        ALLOWED_ATTR: ['href', 'title', 'class'],
        ALLOW_DATA_ATTR: false,
        ALLOWED_URI_REGEXP:
          /^(?:(?:(?:f|ht)tps?|mailto):|[^a-z]|[a-z+.-]+(?:[^a-z+.-:]|$))/i,
      });
    } catch (error) {
      console.error('Error processing markdown:', error);
      return '<p>Error rendering content</p>';
    }
  }, [content]);

  return (
    <div
      className={`prose prose-sm max-w-none dark:prose-invert ${className}`}
      dangerouslySetInnerHTML={{ __html: htmlContent }}
    />
  );
}
```

### サニタイズ設定の解説

| 設定項目 | 値 | 目的 |
|---------|-----|------|
| `ALLOWED_TAGS` | テキスト表示に必要なタグのみ | `<script>`, `<iframe>`, `<object>` 等をブロック |
| `ALLOWED_ATTR` | `href`, `title`, `class` のみ | `onclick` 等のイベントハンドラをブロック |
| `ALLOW_DATA_ATTR` | `false` | `data-*` 属性によるデータ埋め込みを防止 |
| `ALLOWED_URI_REGEXP` | http/https/mailto のみ | `javascript:` URL によるコード実行を防止 |

---

## セキュリティヘッダ

セキュリティヘッダはブラウザの挙動を制御し、クリックジャッキング・MIMEスニッフィング・XSS等の攻撃から保護する。全レスポンスに適用すること。

**この対策は必須のベストプラクティス。AskUserQuestion 不要。**

### ヘッダー一覧と役割

| ヘッダー | 推奨値 | 目的 |
|---------|-------|------|
| `X-Frame-Options` | `DENY` | クリックジャッキング防止（iframe埋め込み禁止） |
| `X-Content-Type-Options` | `nosniff` | MIMEスニッフィングによる不正ファイル実行防止 |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Refererヘッダーによるプライバシー漏洩を制限 |
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains` | HTTPダウングレード攻撃防止（本番環境のみ） |
| `Content-Security-Policy` | allowlistベース（下記参照） | リソース読み込み元を制限しXSSを多層防御 |

### 実装例

```typescript
// src/lib/security-headers.ts
export function applySecurityHeaders(
  responseHeaders: Headers,
  nonce: string,
): void {
  const isProd = process.env.NODE_ENV === 'production';
  const apiUrl = process.env.VITE_API_URL;

  const headers: Record<string, string> = {
    'X-Frame-Options': 'DENY',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    ...(isProd
      ? { 'Strict-Transport-Security': 'max-age=63072000; includeSubDomains' }
      : {}),
    'Content-Security-Policy': [
      "default-src 'self'",
      `script-src 'self' 'nonce-${nonce}'`,
      `style-src 'self' 'unsafe-inline' https://fonts.googleapis.com`,
      "font-src 'self' https://fonts.gstatic.com",
      "img-src 'self' data: https:",
      `connect-src 'self' ${apiUrl ?? ''}`,
    ].join('; '),
  };

  Object.entries(headers).forEach(([key, value]) => {
    responseHeaders.set(key, value);
  });
}
```

**CSP の `nonce` について**: `unsafe-inline` を使わず、リクエストごとに一意のランダム値を生成してスクリプトタグに付与することで、注入されたスクリプトの実行をブロックする。

### nonce 生成・伝播

```typescript
// src/app/middleware/nonce.ts
import { randomBytes } from 'node:crypto';
import { createContext, type MiddlewareFunction } from 'react-router';

export const nonceContext = createContext<string>();
export const nonceMiddleware: MiddlewareFunction = async ({ context }, next) => {
  context.set(nonceContext, randomBytes(16).toString('base64'));
  return next();
};
```

```typescript
// src/app/entry.server.tsx — 全レスポンスにセキュリティヘッダを付与
export default function handleRequest(/* ... */) {
  return new Promise((resolve, reject) => {
    const nonce = loadContext.get(nonceContext);
    applySecurityHeaders(responseHeaders, nonce);
    const { pipe } = renderToPipeableStream(
      <ServerRouter context={routerContext} url={request.url} nonce={nonce} />,
      { nonce },
    );
    // ...
  });
}
```

```typescript
// src/app/root.tsx — nonce を Script/ScrollRestoration コンポーネントへ伝播
export const middleware = [nonceMiddleware, userMiddleware]; // 順序重要

export async function loader({ context }: Route.LoaderArgs) {
  return data({ user: context.get(userContext), nonce: context.get(nonceContext) });
}

export function Layout({ children }: { children: React.ReactNode }) {
  const { nonce } = useLoaderData<typeof loader>();
  return (
    <html lang="en">
      <head><Meta /><Links /></head>
      <body>
        {children}
        <ScrollRestoration nonce={nonce} />
        <Scripts nonce={nonce} />
      </body>
    </html>
  );
}
```

`nonceMiddleware` → `userMiddleware` の順に定義すること。

---

## 判断分岐と AskUserQuestion

| トピック | AskUserQuestion | 理由 |
|---------|:--------------:|------|
| 認証方式（セッション vs トークン） | **必要** | API構成・オリジン構成・インフラに依存 |
| 認可モデル（RBAC vs ABAC） | **必要** | ビジネスロジックの権限構造に依存 |
| コンテンツサニタイズ | 不要 | HTMLレンダリング時の必須セキュリティ対策 |
| セキュリティヘッダ | 不要 | 全Webアプリで推奨される必須ベストプラクティス |
| CSP nonce | 不要 | `unsafe-inline` より安全で一義的に推奨 |

### AskUserQuestion 実装例

```python
AskUserQuestion(
    questions=[
        {
            "question": "認証方式を選択してください",
            "header": "認証方式の選択",
            "options": [
                {"label": "トークンベース（httpOnly Cookie + JWT）",
                 "description": "SPAやAPIが別オリジンの場合に適合。2トークン構成（アクセス＋リフレッシュ）"},
                {"label": "セッションベース",
                 "description": "同一オリジンのSSRアプリに適合。サーバーでセッション状態を管理"},
            ],
            "multiSelect": False
        },
        {
            "question": "認可モデルを選択してください",
            "header": "認可モデルの選択",
            "options": [
                {"label": "RBAC（ロールベース）",
                 "description": "admin/editor/viewer などの固定ロール。シンプルな権限構造に適合"},
                {"label": "ABAC（属性ベース）",
                 "description": "リソース属性・ユーザー属性の複合条件。細かい条件分岐が必要な場合に適合"},
            ],
            "multiSelect": False
        },
    ]
)
```
