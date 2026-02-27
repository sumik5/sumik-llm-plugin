# App Router 実装リファレンス（基礎編）

> 本ファイルは実装パターンと判断基準に特化。概念説明は `NEXTJS-GUIDE.md` を参照。

---

## Route Segment 用語

| 用語 | 意味 | 例 |
|------|------|-----|
| Tree | アプリ全体の階層構造 | app/ 全体 |
| Subtree | 特定 Root から始まる部分 Tree | app/dashboard/ 以下 |
| Root Segment | Tree の最上位 Segment | app/ |
| Leaf Segment | 子を持たない末端 Segment | app/dashboard/settings/ |
| Segment | `/` で区切られた URL の各部分 | `dashboard`, `settings` |
| Path | ドメイン後の全 URL 文字列 | `/dashboard/settings` |
| Route Segment | Segment に対応する app/ 内フォルダ | `app/dashboard/settings/` |
| Dynamic Segment | `[param]` 形式の可変 Segment | `app/posts/[id]/` |

### Dynamic Segment パターン

| 記法 | マッチする URL | 例 |
|------|-------------|-----|
| `[slug]` | `/a`, `/b` | `app/posts/[slug]/` |
| `[...slug]` | `/a/b/c` (必須) | `app/catch/[...slug]/` |
| `[[...slug]]` | `/`, `/a/b/c` (任意) | `app/opt/[[...slug]]/` |

---

## Segment 構成ファイル

| ファイル | 用途 | 特記事項 |
|---------|------|---------|
| `page.tsx` | ページ UI | なし |
| `layout.tsx` | 共有 UI（ネスト可） | 子 Segment 間で状態保持 |
| `loading.tsx` | Suspense フォールバック | 自動的に Suspense でラップ |
| `error.tsx` | ErrorBoundary フォールバック | **"use client" 必須** |
| `not-found.tsx` | 404 UI | `notFound()` で発火 |
| `route.ts` | Route Handler (API) | `page.tsx` と共存不可 |
| `template.tsx` | layout に似るが再レンダリングする | 毎ナビでマウント |
| `global-error.tsx` | root layout のエラー | **"use client" 必須** |
| `default.tsx` | Parallel Route のフォールバック | Slot が一致しない時 |

### 自動生成されるコンポーネントツリー

```tsx
// Next.js が内部的に生成する構造
<Layout>
  <Template>
    <ErrorBoundary fallback={<Error />}>
      <Suspense fallback={<Loading />}>
        <ErrorBoundary fallback={<NotFound />}>
          <Page />
        </ErrorBoundary>
      </Suspense>
    </ErrorBoundary>
  </Template>
</Layout>
```

---

## フォルダ構成パターン

| 記法 | 用途 | URL への影響 |
|------|------|------------|
| `app/(group)/` | Route Group: 論理的なグループ化 | なし |
| `app/_folder/` | Private Folder: ルーティング除外 | なし |
| `app/@slot/` | Parallel Route の Slot | なし |
| `app/(.)intercept/` | Intercepting Route (同一階層) | なし |
| `app/(..)/intercept/` | Intercepting Route (1階層上) | なし |
| `app/(...)/intercept/` | Intercepting Route (root から) | なし |

---

## Server vs Client Component 判断

| 要件 | Server | Client |
|------|--------|--------|
| データ取得 / DB アクセス | ✅ | ❌ |
| 機密情報（API Key 等） | ✅ | ❌ |
| 大きな依存ライブラリ | ✅ | ❌ |
| `onClick`, `onChange` | ❌ | ✅ |
| `useState`, `useReducer` | ❌ | ✅ |
| `useEffect`, `useRef` | ❌ | ✅ |
| `usePathname`, `useSearchParams` | ❌ | ✅ |
| ブラウザ API | ❌ | ✅ |

### "use client" 境界の伝播

```tsx
// ClientComponent.tsx
"use client";

// この境界より import されたコンポーネントも
// すべて Client Component になる
import { AnotherComponent } from "./Another"; // → Client になる

// ✅ Server Component を Client の子にする場合は props で渡す
export function ClientWrapper({ children }: { children: React.ReactNode }) {
  return <div onClick={() => {}}>{children}</div>;
}
```

```tsx
// page.tsx (Server Component)
import { ClientWrapper } from "./ClientWrapper";
import { ServerChild } from "./ServerChild"; // Server Component のまま

export default function Page() {
  return (
    <ClientWrapper>
      <ServerChild /> {/* props経由なのでServerのまま */}
    </ClientWrapper>
  );
}
```

---

## データ取得パターン

### 直列 vs 並行

```tsx
// ❌ 直列（非推奨）: A完了後にBが開始
const user = await fetchUser(id);
const posts = await fetchPosts(user.id);

// ✅ 並行: A・B を同時開始
const [user, posts] = await Promise.all([
  fetchUser(id),
  fetchPosts(id),
]);
```

### Request Memoization（同一リクエスト内の重複排除）

```tsx
// 複数コンポーネントが同じ fetch を呼んでも
// 1リクエスト中は1回しか実行されない
async function getData() {
  const res = await fetch("https://api.example.com/data");
  return res.json();
}

// ComponentA と ComponentB の両方で getData() を呼んでも OK
// → 自動的にメモ化される（fetch のみ。Prisma は cache() が必要）
```

### fetch() キャッシュオプション

| オプション | 挙動 | レンダリング |
|-----------|------|------------|
| デフォルト（省略） | キャッシュあり | 静的 |
| `{ cache: "no-store" }` | 毎回取得 | 動的 |
| `{ next: { revalidate: N } }` | N秒ごとに再検証 | 静的 + ISR |
| `{ next: { tags: ["tag"] } }` | タグベース再検証 | 静的 + On-demand ISR |

---

## 静的 vs 動的レンダリング

動的レンダリングに切り替わる3要因:

| 要因 | 具体例 |
|------|-------|
| ① 動的データ取得 | `fetch("...", { cache: "no-store" })` |
| ② 動的関数の使用 | `cookies()`, `headers()`, `searchParams` prop |
| ③ Dynamic Segment | `[id]` を使用（`generateStaticParams` なしの場合） |

```tsx
// ビルド出力の見方
// ○ /about        → 静的
// λ /dashboard    → 動的（サーバーサイドレンダリング）
// ● /posts/[id]   → generateStaticParams で静的生成済み
```

```tsx
// Dynamic Segment を静的にする（SSG + ISR）
export async function generateStaticParams() {
  const posts = await fetchPosts();
  return posts.map((post) => ({ id: post.id }));
}

export const revalidate = 3600; // 1時間ごとに再検証
```

---

## Route Handler 実装

```tsx
// app/api/users/route.ts
import { NextRequest, NextResponse } from "next/server";

// GET: 静的（デフォルト）
export async function GET() {
  const data = await fetchData();
  return NextResponse.json(data);
}

// POST: 動的（自動）
export async function POST(request: NextRequest) {
  const body = await request.json();
  const result = await createData(body);
  return NextResponse.json(result, { status: 201 });
}
```

### 静的 Route Handler が動的になる5要因

| 要因 | コード例 |
|------|---------|
| ① GET 以外のメソッド | `POST`, `PUT`, `DELETE` |
| ② `cookies()` 使用 | `cookies().get("token")` |
| ③ `headers()` 使用 | `headers().get("Authorization")` |
| ④ `dynamic` 強制設定 | `export const dynamic = "force-dynamic"` |
| ⑤ Dynamic Segment | `app/api/users/[id]/route.ts` |

### Dynamic Segment の Route Handler

```tsx
// app/api/posts/[id]/route.ts
export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params; // Next.js 15以降は Promise
  const post = await fetchPost(id);
  if (!post) return NextResponse.json({ error: "Not found" }, { status: 404 });
  return NextResponse.json(post);
}
```

---

## Metadata API

### 静的 vs 動的

```tsx
// 静的 Metadata
export const metadata: Metadata = {
  title: "ページタイトル",
  description: "説明文",
  openGraph: { images: ["/og.png"] },
};

// 動的 Metadata（APIから取得）
export async function generateMetadata(
  { params }: { params: Promise<{ id: string }> },
  parent: ResolvingMetadata
): Promise<Metadata> {
  const { id } = await params;
  const post = await fetchPost(id);
  const parentImages = (await parent).openGraph?.images ?? [];

  return {
    title: post.title,
    openGraph: { images: [post.image, ...parentImages] },
  };
}
```

### Metadata 継承ルール

- 子 Segment の metadata は親の metadata を**マージ**（上書き）する
- `title.template`: `"%s | サイト名"` パターンで親がテンプレート定義可能
- `openGraph.images` 等の配列は親から引き継ぐには `ResolvingMetadata` が必要

---

## Parallel Routes + Intercepting Routes（モーダルパターン）

```
app/
├── layout.tsx        ← @modal slot を受け取る
├── @modal/
│   └── (.)photos/[id]/
│       └── page.tsx  ← モーダルUI
└── photos/
    └── [id]/
        └── page.tsx  ← フルページUI
```

```tsx
// app/layout.tsx
export default function Layout({
  children,
  modal,
}: {
  children: React.ReactNode;
  modal: React.ReactNode;
}) {
  return (
    <>
      {children}
      {modal} {/* ソフトナビではモーダル、ハードナビでは null */}
    </>
  );
}
```

```tsx
// app/@modal/default.tsx（フォールバック: 何も表示しない）
export default function Default() {
  return null;
}
```

| ナビゲーション種別 | @modal の表示 | photos/[id] の表示 |
|-----------------|-------------|-----------------|
| ソフトナビ（Link） | モーダルUI | 背景ページそのまま |
| ハードナビ（直接URL） | null（default.tsx） | フルページUI |

---

## Navigation

```tsx
// ソフトナビゲーション（クライアントサイド遷移）
import Link from "next/link";
<Link href="/dashboard">Dashboard</Link>
<Link href={`/posts/${id}`}>Post</Link>
<Link href={{ pathname: "/search", query: { q: "hello" } }}>Search</Link>

// プログラマティックナビゲーション
"use client";
import { useRouter } from "next/navigation";
const router = useRouter();
router.push("/dashboard");
router.back();
router.replace("/login"); // 履歴を置換（戻れなくなる）
```

| Link vs router | 使い分け |
|--------------|---------|
| `Link` | UI から宣言的に遷移 |
| `router.push()` | イベントハンドラ内で命令的に遷移 |
| `router.replace()` | 認証後リダイレクト等（履歴を残さない） |
