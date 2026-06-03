# RD-ADVANCED-PERFORMANCE — Hydration 戦略・計測・Bundle 最適化

> **スコープ（差分）**: hydration コスト / selective hydration / islands architecture / PPR / Web Vitals 計測 / bundle 分析・tree shaking
> **除外（既存リファレンス参照）**: memo/useMemo/useCallback → `RI-PERFORMANCE.md` ／ concurrent/startTransition/仮想化 → `RD-MODERN-REACT.md`

---

## 目次

1. [Web Vitals・Lighthouse 計測](#1-web-vitalslighthouse-計測)
2. [React Profiler API（プログラマティック計測）](#2-react-profiler-api)
3. [Bundle 分析・Tree Shaking](#3-bundle-分析tree-shaking)
4. [Hydration コスト](#4-hydration-コスト)
5. [Selective Hydration（Suspense + lazy）](#5-selective-hydration)
6. [Hydration ミスマッチの回避](#6-hydration-ミスマッチの回避)
7. [Islands Architecture](#7-islands-architecture)
8. [Partial Pre-rendering（PPR）](#8-partial-pre-rendering)

---

## 1. Web Vitals・Lighthouse 計測

### Core Web Vitals 指標

| 指標 | 正式名称 | 計測対象 | 目標値 | 備考 |
|---|---|---|---|---|
| **LCP** | Largest Contentful Paint | 最大コンテンツ要素の表示時間 | < 2.5 秒 | ローディングパフォーマンス |
| **INP** | Interaction to Next Paint | セッション中の全操作レイテンシ（98パーセンタイル） | < 200 ms | 2024年3月に FID を置換 |
| **CLS** | Cumulative Layout Shift | 読み込み中のレイアウトシフト累積値 | < 0.1 | 視覚的安定性 |

CLS の主な原因: 寸法未指定の画像・動的注入コンテンツ・Web フォントによるテキスト再フロー。

### web-vitals ライブラリによる実装

```bash
npm install web-vitals
```

```ts
// webVitals.ts — アプリ初期化時に1回呼ぶ（コンポーネント外）
import { onLCP, onINP, onCLS, type Metric } from 'web-vitals'

function sendToAnalytics(metric: Metric) {
  fetch('/api/analytics', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: metric.name,
      value: metric.value,
      rating: metric.rating, // 'good' | 'needs-improvement' | 'poor'
    }),
  })
}

export function initWebVitals() {
  onLCP(sendToAnalytics)   // Largest Contentful Paint
  onINP(sendToAnalytics)   // Interaction to Next Paint
  onCLS(sendToAnalytics)   // Cumulative Layout Shift
}
```

```ts
// SPA でルート変化ごとに再計測する場合
export function useWebVitals() {
  useEffect(() => {
    onLCP(sendToAnalytics, { reportAllChanges: true })
    onINP(sendToAnalytics, { reportAllChanges: true })
    onCLS(sendToAnalytics, { reportAllChanges: true })
  }, [])
}
```

**Next.js の組み込み対応**:

```ts
// app/layout.tsx — Next.js 専用エクスポート
export function reportWebVitals(metric: Metric) {
  sendToAnalytics(metric)
}
```

---

## 2. React Profiler API

`RI-PERFORMANCE.md` の React DevTools Profiler（UI操作）に対し、こちらは**プログラマティック計測・本番アナリティクス送信**に使う。

```ts
import { Profiler, type ProfilerOnRenderCallback } from 'react'

// 目標: React レンダー < 10ms
// （60 FPS フレームバジェット 16.67ms のうちブラウザのレイアウト・ペイント分を除く）
const onRender: ProfilerOnRenderCallback = (
  id,              // Profiler の id prop
  phase,           // 'mount' | 'update'
  actualDuration,  // このコミットの実際のレンダー時間（ms）
  baseDuration,    // メモ化なしの推定レンダー時間（ms）
) => {
  if (actualDuration > 10) {
    console.warn(`[Profiler] ${id} (${phase}): ${actualDuration.toFixed(2)}ms`)
    // 本番では sendToAnalytics({ id, phase, actualDuration, baseDuration })
  }
}

// 視覚的出力なし—計測のみ
<Profiler id="ProductList" onRender={onRender}>
  <ProductList />
</Profiler>
```

**actualDuration vs baseDuration**:

| 値 | 意味 |
|---|---|
| `actualDuration` | 今回のコミットに実際に費やした時間 |
| `baseDuration` | メモ化が一切ない場合の推定レンダー時間 |
| 差（baseDuration − actualDuration） | メモ化による節約時間 → 大きければメモ化が効いている |

---

## 3. Bundle 分析・Tree Shaking

### アナライザーで中身を可視化

送信する JS はすべてパース・コンパイル・実行のコストを持つ。まず**何が含まれているか**を把握する。

```ts
// next.config.ts — Next.js 組み込みアナライザー
import bundleAnalyzer from '@next/bundle-analyzer'

export default bundleAnalyzer({
  enabled: process.env.ANALYZE === 'true',
})({ /* 既存設定 */ } satisfies NextConfig)

// 実行: ANALYZE=true npm run build
```

```ts
// vite.config.ts — Vite 系プロジェクト
import { visualizer } from 'rollup-plugin-visualizer'

export default defineConfig({
  plugins: [visualizer({ open: true, gzipSize: true })],
})
```

### Tree Shaking — Named Import で差分取り込み

```ts
// ❌ ライブラリ全体を取り込む（例: lodash 全体 ~70KB）
import _ from 'lodash'
const sorted = _.sortBy(users, 'name')

// ✅ 必要な関数だけ取り込む（~2KB）
import sortBy from 'lodash/sortBy'
const sorted = sortBy(users, 'name')

// ✅ ネイティブ代替（0KB 追加）
const sorted = [...users].sort((a, b) => a.name.localeCompare(b.name))
```

**Tree Shaking が有効な条件**:

| 条件 | 説明 |
|---|---|
| ESM 形式 | `import`/`export` 構文必須（CommonJS 非対応） |
| named export | デフォルトエクスポートより解析しやすい |
| `"sideEffects": false` | `package.json` で副作用なしを宣言 |

---

## 4. Hydration コスト

**Hydration** とはサーバーレンダリング済み HTML を React がインタラクティブにする処理。React はコンポーネントツリー全体をウォーク・再実行し、既存 DOM と照合してイベントリスナーを付与する。**この間ユーザーはコンテンツを見えるがボタン操作・フォーム入力ができない**。

```
SSR HTML 配信  →  JS ダウンロード  →  [Hydration 開始 → 完了]  →  インタラクティブ化
                                           ↑ この時間を最小化する
```

### Hydration 時間の計測

```ts
'use client'
import { useEffect } from 'react'

export const HydrationMonitor = ({ children }: { children: React.ReactNode }) => {
  useEffect(() => {
    // useEffect は Hydration 完了後に実行される
    const hydrationEnd = performance.now()
    const nav = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming
    const hydrationStart = nav?.domContentLoadedEventStart ?? 0
    const duration = Math.round(hydrationEnd - hydrationStart)

    if (process.env.NODE_ENV === 'development') {
      console.log(`Hydration: ${duration}ms`)
    }
    // 本番: sendToAnalytics('hydration', { duration })
  }, [])

  return <>{children}</>
}
```

**Hydration 遅延の主な原因**:

| 原因 | 改善策 |
|---|---|
| コンポーネントツリーが深い・広い | Selective Hydration / Islands Architecture |
| 大きなバンドル | Code Splitting / Tree Shaking |
| 高コストなコンポーネント初期化 | 処理を `useEffect` に移す |
| JS ダウンロード遅延 | CDN・HTTP/2 Push・preload |

---

## 5. Selective Hydration

`Suspense` + `lazy()` でコンポーネントを独立した Hydration チャンクに分割する。React はユーザーが操作しようとしているコンポーネントを優先的に Hydrate する。

```tsx
// app/page.tsx — Selective Hydration
import { Suspense, lazy } from 'react'

// Server Components —— Hydration 不要
import { Header } from './Header'
import { HeroSection } from './HeroSection'

// lazy() —— 個別バンドル・個別 Hydrate
const SearchBar       = lazy(() => import('./SearchBar'))
const ProductCarousel = lazy(() => import('./ProductCarousel'))
const NewsletterForm  = lazy(() => import('./NewsletterForm'))

export default function HomePage() {
  return (
    <>
      <Header />
      <HeroSection />

      {/* 最初のインタラクション —— ユーザー操作時に優先 Hydrate */}
      <Suspense fallback={<div className="h-12 bg-gray-200 animate-pulse rounded" />}>
        <SearchBar />
      </Suspense>

      {/* フォールドより下 —— アイドル時または可視時に Hydrate */}
      <Suspense fallback={<div className="h-64 bg-gray-200 animate-pulse rounded" />}>
        <ProductCarousel />
      </Suspense>

      {/* 最低優先度 */}
      <Suspense fallback={<div className="h-32 bg-gray-200 animate-pulse rounded" />}>
        <NewsletterForm />
      </Suspense>
    </>
  )
}
```

> **lazy() なしとの違い**: `lazy()` なしでは全コンポーネントが一括バンドルされ同時 Hydrate。`lazy()` により独立チャンクに分割され、React が優先度を制御できる。

---

## 6. Hydration ミスマッチの回避

サーバーHTML とクライアントの出力が異なると React はサーバー HTML を破棄して再レンダーする（SSR メリット喪失・ちらつき発生）。

```tsx
// ❌ NG: サーバーとクライアントで値が異なる
const BadTimestamp = () => <span>{new Date().toLocaleTimeString()}</span>

// ✅ OK: useEffect でクライアント側のみ更新
const GoodTimestamp = () => {
  const [time, setTime] = useState<string | null>(null)

  useEffect(() => {
    setTime(new Date().toLocaleTimeString())
    const id = setInterval(() => setTime(new Date().toLocaleTimeString()), 1000)
    return () => clearInterval(id)
  }, [])

  // SSR / Hydration 中はプレースホルダーを返す
  if (!time) return <span className="text-gray-400">--:--:--</span>
  return <span>{time}</span>
}

// ✅ OK: 意図的な差異には suppressHydrationWarning
const CurrentYear = () => (
  <span suppressHydrationWarning>© {new Date().getFullYear()}</span>
)
```

**よくある原因と対策**:

| 原因 | 対策 |
|---|---|
| `new Date()` / ランダム値 | `useEffect` で後から設定（初期値 `null`） |
| `window` / `document` 参照 | `useEffect` 内のみ使用 |
| CSS-in-JS クラス名不一致 | ライブラリの SSR 設定を確認 |
| ブラウザ拡張機能の DOM 操作 | `suppressHydrationWarning`（最終手段） |

---

## 7. Islands Architecture

**Islands Architecture** は Selective Hydration を極限まで推し進めたパターン: **インタラクティブなコンポーネントだけ Hydrate し、静的コンテンツはプレーン HTML のまま**にする。静的コンテンツが多いページ（ブログ・ドキュメントサイト等）で JS 実行量を劇的に削減できる。

```
ページを海とすると、インタラクティブ要素だけが「島（island）」として浮かぶイメージ:

[静的: Header HTML] [島: SearchBar] [静的: 記事本文] [島: LikeButton] [島: CommentSection]
     JS 不要              JS 必要          JS 不要           JS 必要           JS 必要
```

### Island ラッパーの実装

```tsx
// components/Island.tsx
'use client'
import { useState, useEffect, type ReactNode } from 'react'

type LoadStrategy = 'eager' | 'lazy' | 'visible'

export const Island = ({ children, load }: { children: ReactNode; load: LoadStrategy }) => {
  const [isActive, setIsActive] = useState(load === 'eager')

  useEffect(() => {
    if (load === 'lazy') {
      // ブラウザのアイドル時間に Hydrate
      const id = requestIdleCallback(() => setIsActive(true))
      return () => cancelIdleCallback(id)
    }
    if (load === 'visible') {
      // ビューポートに入ったときに Hydrate
      const el = document.querySelector('[data-island]')
      if (!el) return
      const obs = new IntersectionObserver(([e]) => {
        if (e.isIntersecting) { setIsActive(true); obs.disconnect() }
      })
      obs.observe(el)
      return () => obs.disconnect()
    }
  }, [load])

  // 非アクティブ時はサーバー HTML と一致するプレースホルダー
  if (!isActive) return <div data-island-placeholder>{children}</div>
  return <>{children}</>
}
```

### 使用例

```tsx
export default function BlogPost() {
  return (
    <article>
      {/* 静的コンテンツ —— JS 不要 */}
      <h1>ブログタイトル</h1>
      <div className="prose">{/* 本文 */}</div>

      {/* Island: 即座に Hydrate */}
      <Island load="eager"><LikeButton postId="123" /></Island>

      {/* Island: アイドル時に Hydrate */}
      <Island load="lazy"><ShareButtons url="..." /></Island>

      {/* Island: 表示時に Hydrate */}
      <Island load="visible"><CommentSection postId="123" /></Island>
    </article>
  )
}
```

**Load Strategy 比較**:

| Strategy | Hydration タイミング | 用途 |
|---|---|---|
| `eager` | 即座 | クリティカルなインタラクション（検索バー等） |
| `lazy` | ブラウザのアイドル時 | 初期表示不要なウィジェット |
| `visible` | ビューポートに入った時 | フォールド以下のコンテンツ |

---

## 8. Partial Pre-rendering（PPR）

Next.js 15 が導入した PPR は、**1リクエスト内で静的レンダリングと動的レンダリングを組み合わせる**。

> ⚠️ **Experimental 機能**（`experimental.ppr: true`）。大規模コードベースでは DX 上の問題が発生する可能性があり、現時点では本番環境への使用は非推奨。

### 動作モデル

```
ビルド時:     [静的シェル（Header / レイアウト）] → CDN にキャッシュ
リクエスト時: CDN から静的シェルを即座に配信
ストリーミング:[動的部分（ユーザー固有・リアルタイム）] → Suspense で後から流し込み
```

**SSR との違い**: 従来の SSR ではページ全体が1ユニットとして Hydrate される。PPR では静的部分は Hydrate 不要（プレーン HTML）で、動的部分のみ個別に Hydrate する。

### 実装例

```tsx
// app/page.tsx
import { Suspense } from 'react'
import { Header }     from './Header'           // 静的 —— ビルド時事前レンダリング
import { ProductGrid } from './ProductGrid'     // 静的 —— ビルド時事前レンダリング
import { UserGreeting }        from './UserGreeting'        // 動的 —— 認証後ストリーミング
import { RecommendedProducts } from './RecommendedProducts' // 動的 —— ユーザー履歴

export default function HomePage() {
  return (
    <>
      <Header />          {/* CDN キャッシュから即座に配信 */}

      <Suspense fallback={<div className="h-8 bg-gray-200 animate-pulse" />}>
        <UserGreeting />  {/* 認証チェック後にストリーム */}
      </Suspense>

      <ProductGrid />     {/* CDN キャッシュから即座に配信 */}

      <Suspense fallback={<RecommendationsSkeleton />}>
        <RecommendedProducts /> {/* ユーザー履歴に基づきストリーム */}
      </Suspense>
    </>
  )
}
```

```ts
// next.config.ts —— PPR 有効化
const config: NextConfig = {
  experimental: { ppr: true },
}
export default config
```

### レンダリング戦略比較

| 戦略 | 初期表示 | パーソナライズ | Hydration 範囲 | 代表的な用途 |
|---|---|---|---|---|
| CSR | 遅い | 全対応 | 全体 | 管理画面・認証後アプリ |
| SSR | 速い | 全対応 | 全体 | EC・ニュースサイト |
| Static (SSG) | 最速 | 不可 | 全体または不要 | ブログ・ドキュメント |
| **PPR** | **最速（静的部分）** | **対応（動的部分）** | **動的部分のみ** | **ハイブリッドページ** |
