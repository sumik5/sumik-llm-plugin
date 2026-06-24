# Pages Router → App Router 段階移行プレイブック

> 既存 Pages Router プロジェクトを App Router へ**段階的**に移行する手順。両ルーターは同一アプリ内で共存でき、新 React 機能が必要になった部分から移すのが基本方針。概念背景は `NEXTJS-GUIDE.md`、App Router の実装パターンは `NP-APP-ROUTER-FUNDAMENTALS.md` を参照。

---

## 移行の原則

| 原則 | 内容 |
|------|------|
| 一括書き換え禁止 | 破壊的リライトではなく、明確に境界づけられた1機能/1セクションから移す（blast radius を最小化） |
| 移行は必要になってから | 両ルーターは共存可能。App Router 専用機能（Server Components 等）が必要になった部分のみ移す |
| 葉から移す | プレゼンテーション層・末端コンポーネントほど移行が容易。複雑なクライアント依存は後回し |
| ファイルを小さく保つ | 1ファイル500行程度を上限（ESLint ルール等）にすると人もツールも責務を追いやすく、AI 補助の局所リファクタが効く |

---

## (a) ルート単位の移行

### ディレクトリ構成の対応

ファイルベースのページ → segment ベースのフォルダ（フォルダ=route segment、`page.tsx`=そのページ本体）。

```
# Before (Pages Router)
/pages
  blog/[slug].tsx
  docs/[...slug].tsx

# After (App Router)
/app
  blog/
    [slug]/
      page.tsx
  docs/
    [...slug]/
      page.tsx
```

### データ取得 API の対応関係

| Pages Router | App Router | 備考 |
|-------------|-----------|------|
| `getStaticProps` | async Server Component 内で `fetch` を直接 `await` | ビルド時 props 注入 → inline async 取得に置換 |
| `getStaticPaths` | `generateStaticParams` | 事前生成する slug/ID の列挙。役割は同一 |
| `getServerSideProps` | リクエスト時 `fetch`（`{ cache: "no-store" }` 等） | 毎リクエスト実行を no-store / 動的関数で表現 |

### `getStaticProps` → inline async（静的ページ）

```tsx
// Before (Pages Router)
export default async function BlogPost({ post }) {
  return <Article post={post} />;
}

export async function getStaticProps({ params }) {
  const post = await getPost(params.slug);
  return { props: { post } };
}
```

```tsx
// After (App Router): getStaticProps を削除し props を直接 await
// Next.js 16: params は非同期。await してから分割代入する
export default async function BlogPost({ params }) {
  const { slug } = await params;
  const post = await getPost(slug);
  return <Article post={post} />;
}

// getStaticPaths の対応物: 既知 slug をビルド時に事前生成
export async function generateStaticParams() {
  const posts = await getPosts();
  return posts.map((post) => ({ slug: post.slug }));
}
```

> 構成コンポーネントに interactivity やクライアント依存がなければ（ブログ/ドキュメント等で典型）、移行は実質「`getStaticProps` を消して inline async fetch にする」だけ。Server Components はクライアント JS を送出しないため、`getStaticProps` 版で発生していたハイドレーション時の再実行コストも消える。

### `getServerSideProps` → リクエスト時 fetch

毎リクエスト実行は、no-store の `fetch` や `cookies()`/`headers()` 等の動的関数で表現する（動的レンダリングへ切り替わる条件は `NP-APP-ROUTER-FUNDAMENTALS.md`「静的 vs 動的レンダリング」参照）。

```tsx
// After (App Router): リクエスト時に毎回取得
async function getData() {
  const res = await fetch("https://api.example.com/data", {
    cache: "no-store", // = getServerSideProps の「毎リクエスト実行」
  });
  return res.json();
}
```

---

## (b) `"use client"` 境界の置き場

移行時はツリーをできるだけ Server Component のまま保ち、クライアント機能が必要な部分だけ葉に近い位置で `"use client"` を切る。境界の伝播ルールは `NP-APP-ROUTER-FUNDAMENTALS.md`「"use client" 境界の伝播」を参照。

| そのまま Server のままにする | `"use client"` を切る |
|---------------------------|----------------------|
| プレゼンテーション層（純表示） | `useState` / `useReducer` / `useEffect` 等の hooks |
| サーバーサイドのデータ取得 | `onClick` / `onChange` 等のイベントハンドラ |
| 機密情報を扱う処理 | ブラウザ専用 API（`window` / `document` / `localStorage`） |
| | チャート・アニメーション等のクライアント専用ライブラリ |

判断のコツ:

- 移行が容易なのは「ブラウザ依存のないプレゼンテーション層」。これは Server Component へほぼそのまま移せる。
- ほどけにくいクライアント依存が絡む部分は、無理に Server 化せず `"use client"` でクライアント境界を作る。
- `"use client"` を付けたコンポーネントの**子もすべてクライアント化**されるため、境界はツリーの葉に近づけて影響範囲を最小化する。

---

## (c) page 単位 revalidate → per-fetch の粒度別 revalidate

Pages Router の `getStaticProps` では `revalidate` を1つしか返せず、間隔は**ページ全体**に一律適用される。App Router では inline な各 `fetch` 呼び出しごとに再検証間隔を設定でき、データの性質に合わせて粒度を分けられる。

```tsx
// Before (Pages Router): revalidate はページ全体に1つだけ
export async function getStaticProps({ params }) {
  const post = await getPost(params.slug);
  if (!post) return { notFound: true };
  const author = await getAuthor(post.authorId);
  return { props: { post, author }, revalidate: 60 };
}
```

```tsx
// After (App Router): fetch ごとに別々の revalidate
async function getPost(slug) {
  return fetch(`/posts/${slug}`, {
    next: { revalidate: 60 * 60 * 24 }, // 本文は24時間ごと
  }).then((res) => res.json());
}

async function getAuthor(authorId) {
  return fetch(`/authors/${authorId}`, {
    next: { revalidate: 60 * 60 }, // フォロワー数は60分ごと
  }).then((res) => res.json());
}

export default async function BlogPostPage({ params }) {
  const { slug } = await params; // Next.js 16: params は非同期
  const post = await getPost(slug);
  const author = await getAuthor(post.authorId);
  return <Article post={post} author={author} />;
}
```

> 更新頻度が異なるデータ（更新の速いフォロワー数 vs 安定したブログ本文）を別間隔で再検証することで、古い情報の配信を防ぎつつ無駄な再生成も抑えられる。

---

## (d) 両ルーター共存規則

| 規則 | 内容 |
|------|------|
| 共存可能 | App Router と Pages Router は同一アプリ内で並走できる |
| 同一パス競合は App Router 優先 | 両者が同じパスを定義した場合は App Router が優先。**競合は Next.js がエラーにする** |
| 段階移行の起点 | App Router 専用機能（新 React 機能）が必要になった部分から移行を始める |

移行の進め方:

1. 1つの境界づけられた機能（例: マーケティング/CMS 由来のブログ・ドキュメント）を選び最初に移す。
2. ファイルベースのページ → segment ベースのフォルダへ移す。
3. データ取得を inline async + `generateStaticParams` に置換する。
4. クライアント依存がある部分のみ `"use client"` 境界を切る。
5. revalidate を per-fetch の粒度へ分割する。
6. 次の機能へ進む。

> 移行の機械的作業（データ取得の inline 化・クライアント境界の導入・ルータ API の書き換え）は局所的で、codemod / 型安全 / AI 補助が効きやすい。ただしスコープを広げすぎないこと。
