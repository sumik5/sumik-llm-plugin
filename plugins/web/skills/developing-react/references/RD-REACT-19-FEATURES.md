# RD-REACT-19-FEATURES.md — React 19.2 新機能ガイド

React 19.2 で**新しく追加・安定化した機能**に限定した解説。
React Compiler・concurrent features（useTransition / useDeferredValue）の基礎は [RD-MODERN-REACT.md](./RD-MODERN-REACT.md) を参照。
RSC・Server Actions の基礎は [RI-FRAMEWORKS.md](./RI-FRAMEWORKS.md) を参照。

---

## 目次

1. [`<Activity />` コンポーネント](#1-activity-コンポーネント)
2. [`useEffectEvent`](#2-useeffectevent)
3. [`cacheSignal`（RSC 専用）](#3-cachesignalrsc-専用)
4. [Performance Tracks（DevTools プロファイリング）](#4-performance-tracksdevtools-プロファイリング)
5. [Partial Pre-rendering (PPR)](#5-partial-pre-rendering-ppr)
6. [SSR: Suspense バッチング](#6-ssr-suspense-バッチング)
7. [SSR: Web Streams（Node.js / Edge）](#7-ssr-web-streams)
8. [eslint-plugin-react-hooks v6](#8-eslint-plugin-react-hooks-v6)
9. [`useId` プレフィックス変更](#9-useid-プレフィックス変更)
10. [機能選択ガイド](#10-機能選択ガイド)

---

## 1. `<Activity />` コンポーネント

### 何が変わったか

`<Activity />` は **UI をアンマウントせずに非表示状態で保持する**新しいコンポーネント。

- `mode="hidden"` のとき: 子ツリーを DOM から削除し、Effects をクリーンアップするが、state はメモリに保持
- `mode="visible"` に戻したとき: 以前の state がそのまま復元される（ユーザーの入力・スクロール位置が維持）

**`<Activity />` と `useTransition` の違い（混同注意）**:

| 機能 | 目的 |
|------|------|
| `useTransition` | 重い更新を「非緊急」にマーク。保留中フィードバックを表示するための優先度制御 |
| `<Activity />` | UI を非表示にしつつ state を保持。スケジューリングとは無関係 |

### コード例

```tsx
import { Activity, useState } from 'react'

function AppLayout() {
  const [showPanel, setShowPanel] = useState(true)

  return (
    <div className="layout">
      <button onClick={() => setShowPanel((v) => !v)}>
        パネルを切り替え
      </button>

      <Activity mode={showPanel ? 'visible' : 'hidden'}>
        <aside className="panel">
          <h2>フィルター</h2>
          {/* ここに入力した値は非表示中も保持される */}
          <input type="text" placeholder="検索..." />
        </aside>
      </Activity>

      <main>
        <p>メインコンテンツ</p>
      </main>
    </div>
  )
}
```

### いつ使うか

- タブ切り替え・サイドバー・ドロワー・設定パネルなど、**一時的に非表示にするが state を失いたくない UI**
- `key` を変えてアンマウント/マウントを繰り返してきた場面の代替
- 入力フィールド・フィルター条件・スクロール位置を保持したい場合

---

## 2. `useEffectEvent`

### 何が変わったか

Effect の依存配列から「最新の props/state を読みたいが、それが変わっても Effect を再実行させたくない」ロジックを分離するフック。

**従来の回避策とその問題**:

| 回避策 | 問題 |
|--------|------|
| `useCallback` チェーン | 依存配列が連鎖して肥大化 |
| `useRef` latest-ref パターン | ボイラープレートが増加 |
| `eslint-disable-next-line exhaustive-deps` | 静的な安全性の保証を失う |

`useEffectEvent` はこれらをファーストクラスの解決策として公式化する。

### コード例

```tsx
import { useEffect, useEffectEvent, useState } from 'react'

interface TrackerProps {
  userId: string
  pageName: string
}

export function PageViewTracker({ userId, pageName }: TrackerProps) {
  const [sessionDuration, setSessionDuration] = useState(0)

  // userId / pageName の最新値を常に参照できるが、
  // これらが変化しても Effect は再実行されない
  const logEvent = useEffectEvent((eventName: string, data: object) => {
    analytics.track(eventName, {
      userId,
      pageName,
      timestamp: Date.now(),
      ...data,
    })
  })

  // 依存配列は空 — マウント時に1回だけ実行される
  useEffect(() => {
    const startTime = Date.now()
    logEvent('page_view', { startTime })

    const interval = setInterval(() => {
      const duration = Math.floor((Date.now() - startTime) / 1000)
      setSessionDuration(duration)
      logEvent('heartbeat', { duration })
    }, 30000)

    return () => {
      const totalDuration = Math.floor((Date.now() - startTime) / 1000)
      logEvent('page_exit', { totalDuration })
      clearInterval(interval)
    }
  }, []) // 空の deps が正当。logEvent を deps に含める必要はない

  return <div>セッション: {sessionDuration}s</div>
}
```

### いつ使うか

- 分析・ログ送信など、**常に最新の props を参照したいが props が変わるたびに Effect を再起動させたくない**ケース
- イベントハンドラに近い性質を持つ「副作用の一部」を Effect から切り出したい場合
- `useCallback` + `useRef` の組み合わせで管理していたロジックのリファクタリング

> **制約**: `useEffectEvent` で作成した関数は他のコンポーネントへ渡したり、Effect の外で呼び出してはいけない。Effect のコールバック内でのみ使用する。

---

## 3. `cacheSignal`（RSC 専用）

### 何が変わったか

`cacheSignal` は **React Server Components 専用**のフックで、`cache()` のライフタイムが尽きたとき（= キャッシュされた結果がもう使われなくなったとき）に発火する `AbortSignal` を返す。
この signal を使えば、キャッシュ寿命の終了に合わせて進行中の処理を**クリーンアップ／中断**できる。

- `cache()` でメモ化された関数の結果が破棄されるタイミングで `AbortSignal` が abort される
- すでに不要になったネットワークリクエストや重い計算を、無駄に走らせ続けずに中断できる
- 利用できるのは RSC（サーバー）の文脈のみ。クライアントコンポーネントでは使えない

### コード例

```tsx
import { cache, cacheSignal } from 'react'

// cache() でデータ取得をメモ化する
const dedupedFetch = cache(async (url: string, options: { signal: AbortSignal }) => {
  const response = await fetch(url, options)
  return response.json()
})

// サーバーコンポーネント
async function UserProfile({ userId }: { userId: string }) {
  // cacheSignal() が返す AbortSignal を渡しておくと、
  // このキャッシュ結果が使われなくなったときに fetch が中断される
  const data = await dedupedFetch(`/api/users/${userId}`, {
    signal: cacheSignal(),
  })

  return <h1>{data.name}</h1>
}
```

### いつ使うか

- RSC で `cache()` を使ってデータ取得をメモ化しており、**使われなくなった処理を中断**したい場合
- レンダリングが破棄されたあとも走り続けるネットワークリクエスト・重い計算を確実に止めたい場合
- `AbortSignal` を受け取る既存の API（`fetch` など）とキャッシュ寿命を連動させたい場合

> **制約**: `cacheSignal` は RSC（サーバー）の文脈でのみ動作する。クライアントコンポーネントでは利用できない。`cache()` と組み合わせて使うことを前提とする。

---

## 4. Performance Tracks（DevTools プロファイリング）

### 何が変わったか

React 19.2 は Chrome DevTools のパフォーマンスプロファイルに **React 専用のカスタムトラック**を表示する。
通常のパフォーマンス計測（`performance.measure` 等）と並べて、React 内部の挙動をそのままプロファイルできる。

**追加されるトラック**:

| トラック | 内容 |
|---------|------|
| Scheduler | React が処理した作業の**優先度**（緊急更新 / トランジション等）と、そのスケジューリング状況 |
| Components | コンポーネントの**レンダー／エフェクトのタイミング**（どのコンポーネントがいつ実行されたか） |

特別な設定は不要。React 19.2 を使っていれば、Chrome DevTools のパフォーマンスパネルでプロファイルを記録するだけでトラックが表示される。

### 使い方

```
1. Chrome DevTools を開く（F12）
2. 「Performance」パネルを選択
3. 記録ボタン（●）を押して操作を記録 → 停止
4. タイムライン上に「Scheduler」「Components」トラックが表示される
   - Scheduler: 更新の優先度とスケジューリングを確認
   - Components: レンダー／エフェクトの実行タイミングを確認
```

### いつ使うか

- レンダーが多すぎる・更新の優先度が想定と違うなど、**React の挙動そのものをプロファイル**したい場合
- トランジション（`useTransition` / `useDeferredValue`）がどう優先度付けされているか可視化したい場合
- `react-doctor` やメモ化の効果を計測する前段として、実際のレンダー／エフェクトのタイミングを確認したい場合

---

## 5. Partial Pre-rendering (PPR)

### 何が変わったか

ページの「静的シェル」をビルド時に事前レンダリングし、動的コンテンツだけをリクエスト時にストリーミングで補完する仕組み。
Next.js App Router との統合で利用できる。

**各レンダリング方式との比較**:

| 方式 | TTFB | 動的コンテンツ | 個人化 |
|------|------|----------------|--------|
| 静的生成（SSG） | 最速（CDN） | ❌ | ❌ |
| サーバーサイドレンダリング（SSR） | データ取得待ちで遅延 | ✅ | ✅ |
| **PPR** | **最速（CDN で静的シェルを即時配信）** | **✅** | **✅** |

### コード例

```tsx
// app/dashboard/page.tsx
import { Suspense } from 'react'

// ビルド時に事前レンダリングされる静的シェル
function PageShell() {
  return (
    <div className="page">
      <header>
        <h1>ダッシュボード</h1>
      </header>
      <main>
        {/* Suspense で囲まれた動的コンポーネントはリクエスト時にストリーミング */}
        <Suspense fallback={<MetricsSkeleton />}>
          <UserMetrics />
        </Suspense>

        <Suspense fallback={<FeedSkeleton />}>
          <PersonalizedFeed />
        </Suspense>
      </main>
    </div>
  )
}

// リクエスト時に実行されるサーバーコンポーネント
async function UserMetrics() {
  const metrics = await fetchUserMetrics()
  return (
    <div>
      <p>スコア: {metrics.score}</p>
      <p>今週の変化: +{metrics.improvement}%</p>
    </div>
  )
}

export default PageShell
```

Next.js での有効化:

```ts
// next.config.ts
const nextConfig = {
  experimental: {
    ppr: true,
  },
}
export default nextConfig
```

### いつ使うか

- ヘッダー・ナビゲーションなど静的な枠組みと、ユーザー固有データが混在するページ
- TTFB を犠牲にせず個人化コンテンツを提供したい場合
- Next.js App Router を使用しているプロジェクト

---

## 6. SSR: Suspense バッチング

### 何が変わったか

React 19.2 の SSR で、**視覚的に関連する Suspense 境界をまとめてフラッシュ**するインテリジェントバッチングが導入された。

**効果**:
- ネットワークラウンドトリップの削減
- レイアウトシフトの抑制
- 体感ローディングのなめらかさ向上

特別な設定は不要。React 19.2 の SSR で**自動的に適用される**。

### コード例

```tsx
// app/article/[id]/page.tsx
import { Suspense } from 'react'

async function ContentPage({ params }: { params: { id: string } }) {
  return (
    <article>
      {/* ヘッダーとコンテンツ本文は視覚的に関連 → まとめてフラッシュ */}
      <Suspense fallback={<HeaderSkeleton />}>
        <ContentHeader id={params.id} />
      </Suspense>

      <div className="body">
        <Suspense fallback={<BodySkeleton />}>
          <ContentBody id={params.id} />
        </Suspense>
      </div>

      {/* コメント欄は独立したセクション → 別タイミングでフラッシュされる場合あり */}
      <aside>
        <Suspense fallback={<CommentsSkeleton />}>
          <CommentsList id={params.id} />
        </Suspense>
      </aside>
    </article>
  )
}
```

### いつ使うか

- SSR ページで複数の Suspense 境界を使用している場合（設定不要、自動適用）
- レイアウトシフトやちらつきが気になる SSR ページの改善時
- React のバージョンを 18 → 19.2 にアップグレードするだけで恩恵を受けられる

---

## 7. SSR: Web Streams（Node.js / Edge）

### 何が変わったか

React 19 では 2 つのストリーミング SSR API が提供されており、デプロイ環境に応じて選択する。
React 19.2 で `renderToReadableStream` が正式安定化し、Edge 環境での推奨 API に昇格した。

**API 選択基準**:

| API | 対象環境 | 圧縮サポート | Web Streams 準拠 |
|-----|---------|------------|----------------|
| `renderToPipeableStream` | Node.js | ✅ gzip / brotli | ❌（Node Stream） |
| `renderToReadableStream` | Edge Runtime | ❌ | ✅ |

### コード例: Node.js（renderToPipeableStream）

```ts
// server.ts（Node.js）
import { renderToPipeableStream } from 'react-dom/server'
import App from './App'

export function handler(req: Request, res: Response) {
  const { pipe } = renderToPipeableStream(<App />, {
    bootstrapScripts: ['/client.js'],
    onShellReady() {
      res.setHeader('Content-Type', 'text/html')
      pipe(res)
    },
    onError(error) {
      console.error('SSR Error:', error)
    },
  })
}
```

### コード例: Edge Runtime（renderToReadableStream）

```ts
// server.ts（Edge Runtime）
import { renderToReadableStream } from 'react-dom/server'
import App from './App'

export async function handler(request: Request) {
  const stream = await renderToReadableStream(<App />, {
    bootstrapScripts: ['/client.js'],
    onError(error) {
      console.error('SSR Error:', error)
    },
  })

  return new Response(stream, {
    headers: { 'Content-Type': 'text/html' },
  })
}
```

### デプロイ先別の選択まとめ

| デプロイ先 | 採用 API |
|-----------|---------|
| Node.js サーバー（Express / NestJS / Hono 等） | `renderToPipeableStream` |
| Cloudflare Workers | `renderToReadableStream` |
| Deno Deploy | `renderToReadableStream` |
| Vercel Edge Functions | `renderToReadableStream` |

> **注意**: Node.js 環境で `renderToReadableStream` に切り替えると、圧縮サポートを失う。Node.js から Edge に移行する場合を除き、`renderToPipeableStream` から変更する理由はない。

---

## 8. eslint-plugin-react-hooks v6

### 何が変わったか

v6 は React 19.2 の新しいフック（`useEffectEvent`、`cacheSignal`）を理解し、**誤検知なしで正確な依存配列チェック**を行う。

**v5 との主な違い**:

| 検査対象 | v5 の挙動 | v6 の挙動 |
|---------|----------|----------|
| `useEffectEvent` の戻り値 | deps に含めるよう誤警告 | 自動除外（正しく無視） |
| `cacheSignal` | 未知の値として警告 | 自動除外 |
| 一般的な deps チェック | 過検知が多い | 意図を理解してより精確 |

### コード例

```tsx
import { useEffect, useEffectEvent } from 'react'

interface IntervalCounterProps {
  onTick: (count: number) => void
  interval: number
}

export function IntervalCounter({ onTick, interval }: IntervalCounterProps) {
  // v6: handleTick を deps に含めなくてよいことを正しく理解する
  const handleTick = useEffectEvent((currentCount: number) => {
    onTick(currentCount)
  })

  useEffect(() => {
    let count = 0
    const timer = setInterval(() => {
      count++
      handleTick(count)
    }, interval)

    return () => clearInterval(timer)
  }, [interval]) // v6: interval のみで lint エラーなし ✅

  return null
}
```

### セットアップ

```bash
npm install --save-dev eslint-plugin-react-hooks@^6
```

```json
// .eslintrc.json
{
  "plugins": ["react-hooks"],
  "rules": {
    "react-hooks/rules-of-hooks": "error",
    "react-hooks/exhaustive-deps": "warn"
  }
}
```

### いつ使うか

- `useEffectEvent` を使い始めるタイミングで v6 に**同時アップグレード**する（v5 では誤警告が大量発生する）
- `exhaustive-deps` の誤検知が多く、lint エラーを無効化していた箇所がある場合

---

## 9. `useId` プレフィックス変更

### 何が変わったか

React 19 で `useId` が生成する ID のフォーマットが変更された。

| バージョン | 生成例 | CSS セレクターとの相性 |
|-----------|--------|----------------------|
| React 18 | `:r1:` | ❌ コロン（`:`）はCSS擬似クラス記号。`querySelector` でエスケープ必須 |
| React 19 | `r1` 等の CSS 安全な形式 | ✅ そのまま CSS セレクターで使用可能 |

**変更理由**: View Transitions API は CSS セレクターで要素を照合する。旧フォーマットの `:r1:` は `document.querySelector(':r1:')` がエラーになり、View Transitions API との連携が困難だった。

### コード例

```tsx
import { useId } from 'react'

function FormField({ label, type = 'text' }: { label: string; type?: string }) {
  // React 18: ':r1:'（CSS セレクターで問題あり）
  // React 19: 'r1' または類似の CSS 安全フォーマット
  const id = useId()

  return (
    <div>
      <label htmlFor={id}>{label}</label>
      <input id={id} type={type} />
    </div>
  )
}
```

API の使い方は React 18 と全く同じ。生成される値のフォーマットのみが変更される。

### 影響を受けるケース

| ケース | 影響 | 対応 |
|--------|------|------|
| `label htmlFor` + `input id` の連携 | なし（自動で整合） | 不要 |
| View Transitions API との統合 | 旧→新で**改善**（問題解消） | 不要 |
| テスト・スナップショットで ID 文字列を比較 | **破壊的変更** | フォーマット変更を反映してテストを更新 |
| `document.querySelector` + `useId` の値 | 旧→新で**改善** | 不要 |

### いつ対応が必要か

スナップショットテストに `useId` の出力値（`:r1:` 形式）が含まれている場合のみ更新が必要。
アプリケーションコード（JSX）は変更不要。

---

## 10. 機能選択ガイド

### やりたいことから機能を選ぶ

| やりたいこと | 使う機能 |
|-------------|---------|
| タブ / ドロワーを切り替えても入力状態を保持したい | `<Activity />` |
| Effect 内で常に最新の props を参照したいが再実行させたくない | `useEffectEvent` |
| RSC で `cache()` の寿命終了に合わせて処理を中断したい | `cacheSignal`（RSC 専用） |
| React のレンダー／エフェクトの優先度・タイミングをプロファイルしたい | Performance Tracks（Chrome DevTools） |
| 静的ページの速度を維持しつつ個人化コンテンツを提供したい | PPR（Next.js App Router） |
| SSR で複数 Suspense 境界のちらつきを減らしたい | Suspense バッチング（自動適用） |
| Node.js でストリーミング SSR を実装する | `renderToPipeableStream` |
| Edge Runtime でストリーミング SSR を実装する | `renderToReadableStream` |
| `useEffectEvent` 使用時に lint エラーが大量発生する | `eslint-plugin-react-hooks` v6 にアップグレード |
| View Transitions API と `useId` を組み合わせる | React 19（フォーマット変更により自動対応） |

### `<Activity />` 使用判断フロー

```
非表示にする UI がある？
├── YES → その UI に入力状態やスクロール位置があるか？
│         ├── YES → <Activity mode={visible | hidden}> で包む ✅
│         └── NO  → 通常の条件分岐（{show && <Component />}）で十分
└── NO  → <Activity /> 不要
```

### `useEffectEvent` vs `useCallback` の選択

```
Effect 内でコールバックを使いたい
├── 常に最新の外部値を参照し、かつ deps に含めたくない
│   → useEffectEvent ✅
├── Effect 外（JSX イベントハンドラ等）でも渡したい
│   → useCallback（useEffectEvent は Effect 内専用）
└── 純粋な計算のメモ化
    → useMemo または React Compiler に任せる
```
