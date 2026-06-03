# React Router によるルーティングとレンダリング戦略

> **対象**: React Router（非 Next.js）を使ったクライアントサイド React アプリ。  
> Next.js App Router のルーティング・RSC・SSR は `developing-nextjs` スキルを参照。

---

## 目次

1. [ルーティング設定](#ルーティング設定)
2. [ナビゲーション](#ナビゲーション)
3. [レンダリング戦略の選択](#レンダリング戦略の選択)
4. [SSR の実装](#ssr-の実装)
5. [CSR の実装](#csr-の実装)
6. [ハイブリッドレンダリングの実装](#ハイブリッドレンダリングの実装)
7. [静的プリレンダリングの実装](#静的プリレンダリングの実装)
8. [meta タグ管理](#meta-タグ管理)
9. [ネストレイアウト](#ネストレイアウト)
10. [実装チェックリスト](#実装チェックリスト)

---

## ルーティング設定

React Router は `src/app/routes.ts` というルート設定ファイルを中心に構成される。

### 基本的なルート定義

```typescript
// src/app/routes.ts
import {
  type RouteConfig,
  route,
  index,
  layout,
  prefix,
} from '@react-router/dev/routes';

export default [
  route('/about', './routes/about.tsx'),
] satisfies RouteConfig;
```

各ルートモジュールはデフォルトエクスポートとして UI コンポーネントを提供する:

```typescript
// src/app/routes/about.tsx
export default function AboutPage() {
  return <div>About ページ</div>;
}
```

### 動的ルートパラメータ

`:paramName` 形式のセグメントで動的ルートを定義する:

```typescript
// src/app/routes.ts
export default [
  route('/items/:id', './routes/items/item.tsx'),
] satisfies RouteConfig;
```

コンポーネント内では `props.params.id` でパラメータにアクセスする:

```typescript
// src/app/routes/items/item.tsx
export default function ItemDetailPage(props: Route.ComponentProps) {
  const itemId = props.params.id;
  return <div>Item {itemId}</div>;
}
```

### ルート設定の主要ヘルパー関数

| 関数 | 用途 | 使用例 |
|------|------|--------|
| `route(path, module)` | 通常のルート定義 | `route('/about', './routes/about.tsx')` |
| `index(module)` | パスのデフォルトルート（`/` など） | `index('routes/home.tsx')` |
| `layout(module, children)` | 共通レイアウト付きルート群 | `layout('./routes/layout.tsx', [...])` |
| `prefix(path, children)` | 共通パスプレフィックスのグルーピング | `prefix('dashboard', [...])` |

ルート数が増えた場合は設定を分割して合成できる:

```typescript
const dashboardRoutes = [...prefix('dashboard', [/* ... */])];
const itemRoutes = [/* ... */];

export default [
  layout('./routes/layout.tsx', [
    index('routes/home.tsx'),
    ...dashboardRoutes,
    ...itemRoutes,
    route('*', './routes/not-found.tsx'),  // 404 ハンドラ
  ]),
] satisfies RouteConfig;
```

---

## ナビゲーション

### Link コンポーネント（基本的なページ遷移）

`Link` コンポーネントはフルページリロードなしのクライアントサイドナビゲーションを提供する。伝統的な `<a>` タグとは異なり、JavaScript がナビゲーションをインターセプトして対応するコンポーネントに切り替える:

```typescript
import { Link } from 'react-router';

<Link to="/about" className="text-xl font-bold">
  About
</Link>
```

### NavLink コンポーネント（アクティブ状態付き）

`NavLink` は現在のルートに応じてスタイルを動的に切り替えられる。ナビゲーションメニューやサイドバーに適している:

```typescript
import { NavLink } from 'react-router';

<NavLink
  to="/dashboard"
  end
  className={({ isActive }) =>
    cn(
      'flex items-center gap-2 text-sm hover:text-primary px-3 py-2 rounded-md',
      isActive && 'font-semibold text-primary',
    )
  }
>
  Dashboard
</NavLink>
```

- `isActive`: 現在の URL が `to` パスと一致するとき `true`
- `end` プロパティ: 完全一致のみをアクティブとみなす（`/dashboard/items` にいるとき `/dashboard` がアクティブにならない）

### useNavigate フック（プログラマティック遷移）

フォーム送信後やボタンクリック後など、リンク以外の操作による遷移に使用する:

```typescript
import { useNavigate } from 'react-router';

function MyForm() {
  const navigate = useNavigate();

  const handleSubmit = async (data: FormData) => {
    await saveData(data);
    navigate('/success');  // 保存完了後にリダイレクト
  };

  return <form onSubmit={handleSubmit}>...</form>;
}
```

---

## レンダリング戦略の選択

### ⚠️ AskUserQuestion による確認が必要な判断

**レンダリング戦略（SSR / CSR / hybrid / static）はプロジェクト要件によって最適解が異なる。**  
新規ページを追加する際や既存ページの戦略を変更する際は、必ず以下を **AskUserQuestion** でユーザーに確認すること:

確認すべき場面:
- 新規ページ追加時（SEO が必要か、認証が必要か、データの更新頻度）
- パフォーマンスや SEO の問題が発生しているとき
- ページの性質が変わった（公開 → 認証必須、静的 → 動的）とき

確認不要な場面:
- 既存ページのスタイルやビジネスロジックの修正（レンダリング戦略は変更しない）
- 全ページ共通のレイアウト変更

### 戦略比較テーブル

| 戦略 | SEO | 初期表示速度 | サーバー負荷 | JS 無効時の挙動 | 主なユースケース |
|------|-----|------------|------------|--------------|----------------|
| **SSR** | ◎ | ◎ 即時 | △ 毎リクエスト | ◎ コンテンツ表示 | 動的コンテンツ・SEO必須ページ |
| **CSR** | △ | △ ローディングあり | ◎ 最小 | △ ローディングのみ | 認証済みページ・ダッシュボード |
| **Hybrid** | ◯ | ◯ 重要部分は即時 | △ 部分的 | ◯ 重要部分のみ表示 | 公開ページ＋個人化コンテンツ混在 |
| **Static** | ◎ | ◎ 最速 | ◎ なし（静的配信） | ◎ コンテンツ表示 | マーケティング・ブログ・静的情報 |

### 選択判断フロー

```
ページのコンテンツは変更が少ない（ビルド後に固定）?
  → YES → Static pre-rendering
  → NO ↓
  SEO が必要で、かつ認証不要の公開ページ?
    → YES, データが毎リクエスト変わる → SSR
    → YES, 重要データのみSSR＋個人化データはCSR → Hybrid
    → NO（認証済みページ・SEO不要） → CSR
```

---

## SSR の実装

**特徴**: リクエストごとにサーバーで HTML を生成。常に最新データを返す。

**利点**:
- 検索エンジンがレンダリング済み HTML を取得できる
- JavaScript なしでもコンテンツが表示される
- 初期表示が高速（データ取得待ちなし）

React Router では `loader` 関数をルートモジュールからエクスポートすることで SSR を実装する。`loader` はサーバー上でコンポーネントより前に実行され、データをフェッチして `loaderData` として渡す:

```typescript
// src/app/routes/items/item.tsx
import { data as routerData } from 'react-router';
import type { Route } from './+types/item';  // React Router が自動生成する型定義

export async function loader({ params }: Route.LoaderArgs) {
  const [item, reviews] = await Promise.all([
    getItemById(params.id),
    getReviewsByItem({ id: params.id }),
  ]);
  return routerData({ item, reviews });
}

export default function ItemDetailPage({ loaderData }: Route.ComponentProps) {
  const item = loaderData?.item;
  const reviews = loaderData?.reviews?.data;

  return (
    <div>
      <h1>{item?.title}</h1>
      <ReviewsList reviews={reviews} />
    </div>
  );
}
```

`loader` でエラーが発生した場合は `ErrorBoundary` でハンドリングする:

```typescript
export function ErrorBoundary({ error }: { error: Error }) {
  return (
    <div>
      <h2>エラーが発生しました</h2>
      <p>{error.message}</p>
    </div>
  );
}
```

ルートを `routes.ts` に登録する:

```typescript
export default [
  route('/items/:id', './routes/items/item.tsx'),
] satisfies RouteConfig;
```

> **型安全性**: `Route.LoaderArgs` と `Route.ComponentProps` は `./+types/item` として React Router が自動生成する型定義によって保証される。型推論が効くため、`loaderData` の構造は明示的に定義不要。

---

## CSR の実装

**特徴**: サーバーは最小限の HTML を送信し、JavaScript ロード後にクライアントでデータを取得・描画する。

**利点**:
- サーバー負荷が最小
- シンプルなインフラで動作可能（静的ファイルサーバーのみ）

**トレードオフ**:
- 初期表示時にローディング状態が発生する
- SEO に不向き（認証済みページは問題なし）

CSR では `loader` を使わず、クライアントサイドのカスタムフックでデータ取得する:

```typescript
// src/app/routes/dashboard/items.tsx
import { useCurrentUserItemsQuery } from '@/features/items/api/get-current-user-items';

export default function MyItemsPage() {
  const itemsQuery = useCurrentUserItemsQuery();
  const items = itemsQuery.data?.data;

  return (
    <div>
      <h1>My Items</h1>
      <ItemsList
        items={items}
        isLoading={itemsQuery.isLoading}
        emptyMessage="アイテムがまだありません"
        error={itemsQuery.error}
      />
    </div>
  );
}
```

---

## ハイブリッドレンダリングの実装

**特徴**: サーバーで重要なコンテンツを即時レンダリングし、追加データはクライアントで段階的に取得する。

**適用場面**:
- SEO が必要な公開ページ + 個人化されたコンテンツが混在するページ（例: ユーザープロフィールページ）
- クリティカルデータ（サーバー）と補助データ（クライアント）を組み合わせたいとき

```typescript
// src/app/routes/profile.tsx

// loader でプロフィール（クリティカルデータ）のみ取得
export async function loader({ params }: Route.LoaderArgs) {
  const profile = await getProfileByUsername(params.username);
  return routerData({ profile });
}

export default function ProfilePage({
  params,
  loaderData,
}: Route.ComponentProps) {
  const profile = loaderData?.profile;

  return (
    <div>
      {/* プロフィールは SSR で即時表示 */}
      <ProfileDetails profile={profile} />
      {/* 投稿・レビューはクライアントで段階的に取得 */}
      <UserPosts username={params.username} />
      <UserReviews username={params.username} />
    </div>
  );
}
```

`UserPosts` / `UserReviews` はカスタムフックで独立してデータ取得し、ローディング状態を自己管理する:

```typescript
// src/features/items/components/user-posts.tsx
export function UserPosts({ username }: { username: string }) {
  const postsQuery = usePostsByUserQuery({ username });
  const posts = postsQuery.data?.data;

  return (
    <div>
      <h2>Posts by {username}</h2>
      <PostsList
        posts={posts}
        isLoading={postsQuery.isLoading}
        error={postsQuery.error}
      />
    </div>
  );
}
```

JavaScript を無効にした場合、`loader` で取得したクリティカルデータ（プロフィール）のみ表示され、クライアント取得のデータはローディング状態のまま止まる。これは想定された動作。

---

## 静的プリレンダリングの実装

**特徴**: ビルド時に HTML を生成して静的ファイルとして配信する。

**適用場面**:
- マーケティングページ・ランディングページ
- ブログ記事・ドキュメントページ
- 全ユーザーに同一コンテンツを提供するページ

通常のルートコンポーネントと変わりなく実装し、`react-router.config.ts` で静的生成するパスを指定する:

```typescript
// react-router.config.ts
import type { Config } from '@react-router/dev/config';

export default {
  ssr: true,
  appDirectory: 'src/app',
  async prerender() {
    // ビルド時に静的 HTML を生成するパスの一覧
    return ['/', '/about'];
  },
} satisfies Config;
```

`npm run build` 実行時に指定パスの HTML が `build` ディレクトリ以下に生成される。サーバー処理が不要なため配信コストが最も低く、CDN から直接配信できる。

---

## meta タグ管理

### React 19 方式（推奨）

React 19 以降では、コンポーネント内で直接 `<title>` と `<meta>` タグを記述できる:

```typescript
export default function AboutPage() {
  return (
    <div>
      <title>About - サービス名</title>
      <meta name="description" content="このサービスについての説明" />
      {/* ページコンテンツ */}
    </div>
  );
}
```

### 再利用可能な Seo コンポーネント

複数ページで同じパターンを繰り返す場合は共通コンポーネントに切り出す:

```typescript
// src/components/seo.tsx
export function Seo({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <>
      <title>{title}</title>
      <meta name="description" content={description} />
    </>
  );
}
```

```typescript
// 各ページでの使用
export default function AboutPage() {
  return (
    <div>
      <Seo title="About - サービス名" description="このサービスについての説明" />
      {/* ページコンテンツ */}
    </div>
  );
}
```

### React Router の meta 関数（旧来の方式）

React Router のルートモジュールレベルで meta 情報を管理したい場合は `meta` 関数を使用できる:

```typescript
export function meta() {
  return [
    { title: 'ページタイトル' },
    { name: 'description', content: 'ページの説明' },
  ];
}
```

> **推奨**: React 19 以降は `<title>` / `<meta>` タグをコンポーネント内に直接記述する方式が推奨される。

---

## ネストレイアウト

### レイアウトコンポーネントの役割

レイアウトはページコンテンツをラップし、ナビゲーションなど共通 UI を提供する。`<Outlet />` が子ルートのレンダリング位置となる:

```typescript
// src/app/routes/layout.tsx
import { Outlet } from 'react-router';
import { Navigation } from '@/components/navigation';

export default function RootLayout() {
  return (
    <div>
      <Navigation />
      <main className="min-h-screen bg-background">
        <Outlet />  {/* 子ルートのコンポーネントがここに描画される */}
      </main>
    </div>
  );
}
```

**利点**: ナビゲーション間でレイアウトは再マウントされず `Outlet` の内容のみ切り替わるため、不要な再レンダリングを回避できる。

### ネストされたレイアウト構成

`layout()` 関数と `prefix()` 関数を組み合わせて多階層のレイアウトを構成できる:

```typescript
// src/app/routes.ts
import {
  type RouteConfig,
  index,
  layout,
  prefix,
  route,
} from '@react-router/dev/routes';

export default [
  layout('./routes/layout.tsx', [           // ルートレイアウト（全ページ共通ナビバー）
    index('routes/home.tsx'),               // /
    route('about', './routes/about.tsx'),   // /about
    ...prefix('dashboard', [               // /dashboard/*
      layout('./routes/dashboard/layout.tsx', [
        index('./routes/dashboard/dashboard.tsx'),       // /dashboard
        route('items', './routes/dashboard/items.tsx'),  // /dashboard/items
        route('reviews', './routes/dashboard/reviews.tsx'),
      ]),
    ]),
    route('profile/:username', './routes/profile.tsx'),  // /profile/:username
    route('items/:id', './routes/items/item.tsx'),        // /items/:id
    route('*', './routes/not-found.tsx'),                 // 404 ハンドラ
  ]),
] satisfies RouteConfig;
```

### ダッシュボードレイアウトの例

ダッシュボード専用のサイドナビゲーションを提供するネストされたレイアウト:

```typescript
// src/app/routes/dashboard/layout.tsx
import { NavLink, Outlet } from 'react-router';

export default function DashboardLayout() {
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="max-w-4xl mx-auto">
        <nav className="mb-6">
          <NavLink to="/dashboard/items" end>Items</NavLink>
          <NavLink to="/dashboard/reviews" end>Reviews</NavLink>
        </nav>
        <Outlet />
      </div>
    </div>
  );
}
```

ルートを `routes.ts` に登録すると、`/dashboard/items` にアクセスした際にルートレイアウト（グローバルナビ）→ ダッシュボードレイアウト（サイドナビ）→ `items.tsx` コンポーネントの順でレンダリングされる。

---

## 実装チェックリスト

### ルーティング

- [ ] `src/app/routes.ts` にすべてのルートが登録されている
- [ ] 各ルートモジュールがデフォルトエクスポートとしてコンポーネントを持つ
- [ ] 動的ルートは `:paramName` 形式で定義されている
- [ ] 404 ハンドラ（`route('*', ...)`）が設定されている

### レンダリング戦略

- [ ] AskUserQuestion でレンダリング戦略の要件（SEO / 認証 / 更新頻度）を確認した
- [ ] SSR ページでは `loader` 関数でデータを取得し `loaderData` で受け取っている
- [ ] SSR ページには `ErrorBoundary` が定義されている
- [ ] CSR ページはカスタムフック経由でクライアントサイドからデータ取得している
- [ ] Hybrid ページはクリティカルデータのみ `loader` で取得し、残りはクライアントで取得
- [ ] 静的ページは `react-router.config.ts` の `prerender` で列挙されている

### meta タグ・SEO

- [ ] SEO が必要な全ページに `<title>` と `<meta name="description">` が設定されている
- [ ] 共通の meta タグパターンは `Seo` コンポーネントに集約されている

### レイアウト

- [ ] 共通 UI（ナビゲーション等）はレイアウトコンポーネントに集約されている
- [ ] `<Outlet />` が各レイアウトコンポーネントに配置されている
- [ ] ネストされたレイアウトが `layout()` 関数で正しく定義されている
