# App Router 実装リファレンス（フルスタック編）

> 本ファイルは認証・DB・Server Actions・キャッシュ等の実践パターンを収録。基礎は `NP-APP-ROUTER-FUNDAMENTALS.md` 参照。

---

## フルスタック構成

```
Web Application Server (Next.js)
  ↕ HTTP
Web API Server (Next.js / Express 等)
  ↕
DB Server (PostgreSQL) + Storage Server (S3 / minio)
```

| サーバー | 役割 | 例 |
|---------|------|-----|
| Web App Server | SSR・RSC・認証・UI | Next.js App Router |
| Web API Server | ビジネスロジック・外部公開API | Next.js API Routes / NestJS |
| DB Server | データ永続化 | PostgreSQL |
| Storage Server | バイナリ（画像・動画等） | S3 / minio（S3互換） |

---

## 環境変数

### ファイル優先度（高優先 → 低優先）

| ファイル | 用途 | git 管理 |
|---------|------|---------|
| `.env.$(NODE_ENV).local` | 環境別ローカル上書き | ❌ .gitignore 必須 |
| `.env.local` | ローカル上書き | ❌ .gitignore 必須 |
| `.env.$(NODE_ENV)` | 環境別設定 | ✅ |
| `.env` | 共通デフォルト | ✅ |

### プレフィックス

```bash
# ✅ サーバー専用（公開されない）
DATABASE_URL="postgresql://..."
API_SECRET_KEY="secret"

# ✅ ブラウザに公開（ビルド時に埋め込まれる）
NEXT_PUBLIC_API_URL="https://api.example.com"
NEXT_PUBLIC_GA_ID="G-XXXXXXXX"
```

> ⚠️ `NEXT_PUBLIC_` はビルド時に静的に埋め込まれる。ランタイムで変更しても反映されない。

---

## Prisma ORM

### 基本パターン

```tsx
// prisma/schema.prisma
model User {
  id    String  @id @default(cuid())
  email String  @unique
  name  String?
  posts Post[]
}
```

```tsx
// lib/prisma.ts（シングルトン）
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ||
  new PrismaClient({ log: ["query"] });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
```

### 型安全クエリ

```tsx
// findUnique + select で必要なフィールドのみ取得
const user = await prisma.user.findUnique({
  where: { id },
  select: { id: true, name: true, email: true },
});

// upsert: 存在すれば更新、なければ作成
const profile = await prisma.profile.upsert({
  where: { userId: id },
  update: { bio: newBio },
  create: { userId: id, bio: newBio },
});
```

### キャッシュとの統合

```tsx
import { cache } from "react";
import { unstable_cache } from "next/cache";

// Request Memoization（1リクエスト内の重複排除）
export const getUser = cache(async (id: string) => {
  return prisma.user.findUnique({ where: { id } });
});

// Data Cache（サーバー永続化・再検証可能）
export const getCachedPosts = unstable_cache(
  async (userId: string) => {
    return prisma.post.findMany({ where: { userId } });
  },
  ["posts"],
  { revalidate: 3600, tags: ["posts"] }
);
```

---

## NextAuth.js（Auth.js）認証

### Session 取得パターン

```tsx
// Server Component でのセッション取得
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { notFound } from "next/navigation";

export default async function ProfilePage() {
  const session = await getServerSession(authOptions);

  // notFound() で TypeScript の型も絞り込まれる
  if (!session) notFound();

  // session.user が確実に存在する状態でアクセス可能
  return <div>{session.user.name}</div>;
}
```

### Middleware でのアクセス制御

```tsx
// middleware.ts（ルートに配置）
import { withAuth } from "next-auth/middleware";

export default withAuth({
  pages: { signIn: "/login" },
});

export const config = {
  matcher: ["/dashboard/:path*", "/profile/:path*"],
};
```

### Session の型拡張

```tsx
// types/next-auth.d.ts
import { DefaultSession } from "next-auth";

declare module "next-auth" {
  interface Session {
    user: {
      id: string;
    } & DefaultSession["user"];
  }
}
```

---

## Server Actions

### 基本パターン（"use server" 宣言）

```tsx
// actions/posts.ts
"use server";

import { revalidatePath, revalidateTag } from "next/cache";
import { prisma } from "@/lib/prisma";

export async function createPost(formData: FormData) {
  const title = formData.get("title") as string;

  await prisma.post.create({ data: { title } });

  revalidatePath("/posts"); // キャッシュ無効化
}
```

### useActionState での状態管理

```tsx
// Client Component
"use client";

import { useActionState } from "react";
import { createPost } from "@/actions/posts";

type State = { message: string; errors?: { title?: string[] } };
const initialState: State = { message: "" };

export function PostForm() {
  const [state, formAction, isPending] = useActionState(
    createPost,
    initialState
  );

  return (
    <form action={formAction}>
      <input name="title" />
      {state.errors?.title && <p>{state.errors.title[0]}</p>}
      <button disabled={isPending}>
        {isPending ? "送信中..." : "投稿"}
      </button>
      <p>{state.message}</p>
    </form>
  );
}
```

### useFormStatus（子コンポーネントで状態参照）

```tsx
"use client";
import { useFormStatus } from "react-dom";

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button type="submit" disabled={pending}>
      {pending ? "送信中..." : "送信"}
    </button>
  );
}
```

### エラーハンドリングパターン

```tsx
// Server Action でエラーは return で返す（throw は避ける）
export async function updateProfile(
  prevState: State,
  formData: FormData
): Promise<State> {
  const name = formData.get("name") as string;

  if (!name.trim()) {
    return { message: "エラー", errors: { name: ["名前は必須です"] } };
  }

  await prisma.user.update({ where: { id: "..." }, data: { name } });

  return { message: "更新完了" };
}
```

---

## Zod バリデーション

### Server Action + Client 共有スキーマ

```tsx
// lib/validations/post.ts（Server・Client 両方から import 可）
import { z } from "zod";

export const postSchema = z.object({
  title: z.string().min(1, "タイトルは必須です").max(100, "100文字以内"),
  content: z.string().min(1, "本文は必須です"),
});

export type PostInput = z.infer<typeof postSchema>;
```

```tsx
// actions/posts.ts
"use server";
import { postSchema } from "@/lib/validations/post";

export async function createPost(
  prevState: State,
  formData: FormData
): Promise<State> {
  const result = postSchema.safeParse({
    title: formData.get("title"),
    content: formData.get("content"),
  });

  if (!result.success) {
    const fieldErrors = result.error.flatten().fieldErrors;
    return { message: "バリデーションエラー", fieldErrors };
  }

  await prisma.post.create({ data: result.data });
  revalidatePath("/posts");
  return { message: "投稿完了", fieldErrors: {} };
}
```

### Client でのプリバリデーション

```tsx
"use client";
import { postSchema } from "@/lib/validations/post";

function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
  const formData = new FormData(e.currentTarget);
  const result = postSchema.safeParse(Object.fromEntries(formData));

  if (!result.success) {
    e.preventDefault(); // サーバー送信をキャンセル
    // エラー表示
  }
}
```

---

## useOptimistic（楽観的 UI 更新）

```tsx
"use client";
import { useOptimistic, useState } from "react";
import { addLike } from "@/actions/likes";

type Like = { id: string; userId: string };

export function LikeButton({ postId, initialLikes }: Props) {
  const [likes, setLikes] = useState<Like[]>(initialLikes);
  const [optimisticLikes, addOptimisticLike] = useOptimistic(
    likes,
    (current, newLike: Like) => [...current, newLike]
  );

  async function handleLike() {
    const optimisticEntry = { id: "temp", userId: "me" };

    // 1. 楽観的に即時反映（Server Action 完了前）
    addOptimisticLike(optimisticEntry);

    // 2. Server Action 実行
    const newLike = await addLike(postId);

    // 3. 実際のデータで更新
    setLikes((prev) => [...prev, newLike]);
  }

  return (
    <button onClick={handleLike}>
      {optimisticLikes.length} Likes
    </button>
  );
}
```

> `optimisticLikes` は Server Action 完了後に自動で実際の `likes` state に切り替わる。

---

## 4種類のキャッシュ

| キャッシュ | 場所 | ライフサイクル | 対象 |
|-----------|------|-------------|------|
| Request Memoization | サーバーメモリ | 1ブラウザリクエスト | 同一 URL の `fetch()` |
| Data Cache | サーバー永続 | デプロイ後も継続 | `fetch()` レスポンス |
| Full Route Cache | サーバー永続 | デプロイ後も継続 | HTML + RSC Payload |
| Router Cache | ブラウザ | セッション / 時間制限 | RSC Payload |

### 各キャッシュの再検証方法

| キャッシュ | 再検証方法 |
|-----------|----------|
| Request Memoization | 自動（リクエストごと） |
| Data Cache | `revalidatePath()`, `revalidateTag()`, `revalidate` オプション |
| Full Route Cache | Data Cache 再検証と連動 |
| Router Cache | `router.refresh()`, 期限切れ（static: 5min, dynamic: 30s） |

### 再検証戦略の選択

| シナリオ | 推奨戦略 |
|---------|---------|
| ブログ記事（更新頻度低） | `revalidate = 3600`（時間ベース） |
| 商品在庫（更新頻度高） | `cache: "no-store"`（毎回取得） |
| SNS投稿（書込時更新） | `revalidateTag("posts")`（On-demand） |
| ダッシュボード（個人データ） | `cache: "no-store"` + `cookies()` |

```tsx
// タグベース再検証
// データ取得時にタグ付け
const posts = await fetch("https://api/posts", {
  next: { tags: ["posts"] },
});

// Server Action 内で無効化
await prisma.post.create({ data });
revalidateTag("posts"); // "posts" タグの全キャッシュを無効化
```

---

## generateStaticParams（SSG）

```tsx
// app/posts/[id]/page.tsx
export async function generateStaticParams() {
  const posts = await prisma.post.findMany({
    select: { id: true },
  });
  return posts.map((post) => ({ id: post.id }));
}

// ISR: 1時間ごとに再検証
export const revalidate = 3600;

// ビルド時に生成されなかったパスへのアクセス挙動
export const dynamicParams = true; // デフォルト: 動的に生成
// export const dynamicParams = false; // 404 を返す
```

---

## アセット最適化

### next/image

```tsx
import Image from "next/image";

// ✅ LCP 対象画像には priority 指定
<Image
  src="/hero.jpg"
  alt="ヒーロー画像"
  width={1200}
  height={600}
  priority // LCP改善: プリロードされる
/>

// ✅ 外部画像は next.config.ts で許可が必要
// next.config.ts
const config = {
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "example.com" },
    ],
  },
};
```

### next/font（Google Fonts をセルフホスト）

```tsx
// app/layout.tsx
import { Noto_Sans_JP } from "next/font/google";

const notoSansJP = Noto_Sans_JP({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-noto-sans-jp",
});

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja" className={notoSansJP.variable}>
      <body>{children}</body>
    </html>
  );
}
```

### next/script（サードパーティスクリプト）

```tsx
import Script from "next/script";

// strategy オプション
// beforeInteractive: ページ操作前に実行（必須スクリプト）
// afterInteractive:  ハイドレーション後（デフォルト）
// lazyOnload:        アイドル時（分析・広告タグ等）

<Script
  src="https://analytics.example.com/script.js"
  strategy="lazyOnload"
/>
```

---

## fetchCache ルートセグメント設定

```tsx
// レイアウトやページ全体の fetch デフォルトを上書き
export const fetchCache = "force-no-store"; // 全 fetch を動的に

// 個別の fetch オプションと組み合わせ
// fetchCache のデフォルトを設定しつつ、
// 特定の fetch だけ { cache: "force-cache" } で上書き可能
```
