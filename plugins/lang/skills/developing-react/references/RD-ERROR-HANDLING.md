# Reactエラーハンドリング戦略

Reactアプリケーションにおけるエラーハンドリングの包括的ガイド。ErrorBoundaryの実装から非同期エラー、エラー報告統合まで網羅する。

---

## 1. ErrorBoundaryの基本

ErrorBoundaryはReactのレンダリングツリー内でエラーを「捕捉し、フォールバックUIを表示する」クラスコンポーネント。

### 必須ライフサイクルメソッド

| メソッド | 役割 | タイミング |
|---------|------|----------|
| `getDerivedStateFromError` | エラーをstateに反映（フォールバックUI表示） | レンダリングフェーズ（副作用禁止） |
| `componentDidCatch` | エラーロギング・副作用処理 | コミットフェーズ（副作用OK） |

### 基本実装

```tsx
import React, { Component, ReactNode } from 'react'

interface ErrorBoundaryState {
  hasError: boolean
  error: Error | null
}

interface ErrorBoundaryProps {
  children: ReactNode
  fallback?: ReactNode
  onError?: (error: Error, errorInfo: React.ErrorInfo) => void
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props)
    this.state = { hasError: false, error: null }
  }

  // エラー発生時にstateを更新（純粋関数 = 副作用禁止）
  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error }
  }

  // エラーロギング用（副作用OK）
  componentDidCatch(error: Error, errorInfo: React.ErrorInfo): void {
    console.error('Uncaught error:', error, errorInfo.componentStack)
    this.props.onError?.(error, errorInfo)
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? <DefaultFallback error={this.state.error} />
    }
    return this.props.children
  }
}

function DefaultFallback({ error }: { error: Error | null }) {
  return (
    <div role="alert">
      <h2>エラーが発生しました</h2>
      <p>{error?.message ?? '不明なエラー'}</p>
    </div>
  )
}
```

---

## 2. react-error-boundary ライブラリ

関数コンポーネント向けの公式推奨ライブラリ。クラスコンポーネントを書かずにErrorBoundaryを利用できる。

```bash
npm install react-error-boundary
```

### ErrorBoundary コンポーネント

```tsx
import { ErrorBoundary } from 'react-error-boundary'

// fallbackRender: エラー情報とリセット関数を受け取るrender prop
function FallbackComponent({
  error,
  resetErrorBoundary,
}: {
  error: Error
  resetErrorBoundary: () => void
}) {
  return (
    <div role="alert">
      <p>エラー: {error.message}</p>
      <button onClick={resetErrorBoundary}>再試行</button>
    </div>
  )
}

function App() {
  return (
    <ErrorBoundary
      FallbackComponent={FallbackComponent}
      onError={(error, info) => reportToSentry(error, info)}
      onReset={() => {
        // リセット時の副作用（ステート初期化等）
      }}
    >
      <MyComponent />
    </ErrorBoundary>
  )
}
```

### useErrorBoundary フック

関数コンポーネント内から手動でErrorBoundaryをトリガーする。非同期エラーをErrorBoundaryに伝播させる唯一の公式手段。

```tsx
import { useErrorBoundary } from 'react-error-boundary'

function DataFetcher() {
  const { showBoundary } = useErrorBoundary()

  const fetchData = async () => {
    try {
      const data = await api.fetchUser()
      setUser(data)
    } catch (error) {
      // 非同期エラーをErrorBoundaryに委譲
      showBoundary(error)
    }
  }

  return <button onClick={fetchData}>データ取得</button>
}
```

### withErrorBoundary HOC（後方互換）

```tsx
import { withErrorBoundary } from 'react-error-boundary'

const SafeComponent = withErrorBoundary(MyComponent, {
  FallbackComponent: FallbackComponent,
  onError: reportToSentry,
})
```

---

## 3. React 19 エラーAPI

React 19では`createRoot`に新しいエラーコールバックオプションが追加。ルートレベルで全エラーを集中監視できる。

```tsx
import { createRoot } from 'react-dom/client'

const root = createRoot(document.getElementById('root')!, {
  // ErrorBoundaryでキャッチされたエラー（ユーザーは通知済み）
  onCaughtError(error: Error, errorInfo: React.ErrorInfo) {
    // フォールバックUIが表示されているのでユーザー影響は局所化済み
    reportToSentry(error, { tags: { caught: true }, extra: errorInfo })
  },

  // ErrorBoundaryでキャッチされなかったエラー（アプリがクラッシュ）
  onUncaughtError(error: Error, errorInfo: React.ErrorInfo) {
    // クリティカル: ページリロードやモーダル表示を検討
    reportToSentry(error, { level: 'fatal', extra: errorInfo })
    showGlobalErrorModal()
  },

  // ハイドレーションエラー（SSRとCSRの不一致）
  onRecoverableError(error: Error, errorInfo: React.ErrorInfo) {
    console.warn('Recoverable error:', error)
  },
})

root.render(<App />)
```

---

## 4. 配置戦略（3層構造）

ErrorBoundaryは「どこに配置するか」でエラーの影響範囲が変わる。

```
App
├── [Layer 1] AppErrorBoundary      ← アプリ全体（最終防衛ライン）
│   └── Router
│       ├── [Layer 2] PageErrorBoundary  ← ページレベル（汎用エラー）
│       │   └── DashboardPage
│       │       ├── [Layer 3] ComponentErrorBoundary  ← 障害局所化
│       │       │   └── ExpensiveWidget
│       │       └── StatsPanel
```

### Layer 1: アプリ全体（最終防衛ライン）

```tsx
// app/layout.tsx または main.tsx
function RootLayout({ children }: { children: ReactNode }) {
  return (
    <ErrorBoundary
      FallbackComponent={GlobalErrorFallback}
      onError={(error) => {
        reportToSentry(error, { level: 'fatal' })
      }}
    >
      {children}
    </ErrorBoundary>
  )
}
```

### Layer 2: ページレベル（汎用エラー）

```tsx
// ルーターレベルでページごとに配置
function DashboardRoute() {
  return (
    <ErrorBoundary
      FallbackComponent={PageErrorFallback}
      // ページ遷移時に自動リセット
      resetKeys={[location.pathname]}
    >
      <DashboardPage />
    </ErrorBoundary>
  )
}
```

### Layer 3: コンポーネントレベル（障害局所化）

```tsx
// 独立したウィジェットや重要でないUIパーツに適用
function Dashboard() {
  return (
    <div>
      <ErrorBoundary FallbackComponent={WidgetError}>
        <RealtimeChart />       {/* エラーが他のウィジェットに影響しない */}
      </ErrorBoundary>
      <ErrorBoundary FallbackComponent={WidgetError}>
        <UserActivityFeed />
      </ErrorBoundary>
    </div>
  )
}
```

---

## 5. ErrorBoundaryの制限と対策

ErrorBoundaryはReactのレンダリングサイクル外のエラーをキャッチできない。

| エラー種別 | キャッチ可否 | 対策 |
|----------|------------|------|
| レンダリング中のエラー | ✅ | ErrorBoundaryで自動キャッチ |
| コンポーネントの初期化エラー | ✅ | ErrorBoundaryで自動キャッチ |
| 非同期エラー（async/await） | ❌ | try/catch + `useErrorBoundary().showBoundary` |
| イベントハンドラ内エラー | ❌ | try/catch + ローカルエラーstate |
| SSR（サーバーサイド）エラー | ❌ | Next.js `error.tsx` / `global-error.tsx` |
| Promise rejection（未捕捉） | ❌ | `window.onunhandledrejection` |

### グローバル補完（ErrorBoundaryでカバーできない範囲）

```tsx
// main.tsx でグローバルエラー監視を設定
window.onerror = (message, source, lineno, colno, error) => {
  reportToSentry(error ?? new Error(String(message)))
}

window.onunhandledrejection = (event: PromiseRejectionEvent) => {
  reportToSentry(event.reason)
  // デフォルトの警告を抑制（報告済みの場合）
  event.preventDefault()
}
```

---

## 6. 非同期エラーハンドリング

### パターン1: try/catch + ローカルstate

```tsx
function UserProfile({ userId }: { userId: string }) {
  const [error, setError] = useState<Error | null>(null)
  const [user, setUser] = useState<User | null>(null)

  const loadUser = async () => {
    try {
      setError(null)
      const data = await fetchUser(userId)
      setUser(data)
    } catch (e) {
      setError(e instanceof Error ? e : new Error('取得に失敗しました'))
    }
  }

  if (error) {
    return (
      <div role="alert">
        <p>{error.message}</p>
        <button onClick={loadUser}>再試行</button>
      </div>
    )
  }

  return user ? <Profile user={user} /> : <Skeleton />
}
```

### パターン2: TanStack Query の error state

```tsx
import { useQuery } from '@tanstack/react-query'

function UserProfile({ userId }: { userId: string }) {
  const { data, error, isLoading, refetch } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
    retry: 2,           // 自動リトライ回数
    retryDelay: 1000,   // リトライ間隔(ms)
  })

  if (isLoading) return <Skeleton />

  if (error) {
    return (
      <div role="alert">
        <p>エラー: {error.message}</p>
        <button onClick={() => refetch()}>再試行</button>
      </div>
    )
  }

  return <Profile user={data} />
}
```

### パターン3: Suspense + ErrorBoundary（React 19推奨）

```tsx
// use()フックでPromiseを直接消費
import { use, Suspense } from 'react'
import { ErrorBoundary } from 'react-error-boundary'

function UserCard({ userPromise }: { userPromise: Promise<User> }) {
  // Promiseがrejectされると最近接のErrorBoundaryに伝播
  const user = use(userPromise)
  return <Profile user={user} />
}

function App() {
  return (
    <ErrorBoundary FallbackComponent={FallbackComponent}>
      <Suspense fallback={<Skeleton />}>
        <UserCard userPromise={fetchUser('123')} />
      </Suspense>
    </ErrorBoundary>
  )
}
```

---

## 7. フォールバックUI設計

### リトライボタン付きフォールバック

```tsx
function RetryableFallback({
  error,
  resetErrorBoundary,
}: {
  error: Error
  resetErrorBoundary: () => void
}) {
  return (
    <div
      role="alert"
      style={{
        padding: '2rem',
        textAlign: 'center',
        border: '1px solid #fee2e2',
        borderRadius: '8px',
        background: '#fef2f2',
      }}
    >
      <h3>読み込みに失敗しました</h3>
      <p style={{ color: '#6b7280', fontSize: '0.875rem' }}>
        {error.message}
      </p>
      <button
        onClick={resetErrorBoundary}
        style={{
          marginTop: '1rem',
          padding: '0.5rem 1rem',
          background: '#3b82f6',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
      >
        再試行
      </button>
    </div>
  )
}
```

### 部分的グレースフルデグラデーション

```tsx
// 重要でないUIは静かに非表示（ユーザー体験を守る）
function OptionalWidget({ children }: { children: ReactNode }) {
  return (
    <ErrorBoundary
      fallback={null}  // エラー時は何も表示しない
      onError={(error) => {
        // ユーザーには見せないが、開発者には報告
        console.warn('Widget failed silently:', error)
      }}
    >
      {children}
    </ErrorBoundary>
  )
}

// ページを守りながら重要でないコンテンツをラップ
function Dashboard() {
  return (
    <main>
      <CriticalContent />      {/* エラーはページレベルのBoundaryへ */}
      <OptionalWidget>
        <RecommendationPanel /> {/* 失敗しても他に影響なし */}
      </OptionalWidget>
    </main>
  )
}
```

### ページレベルフォールバック（Next.js）

```tsx
// app/dashboard/error.tsx
'use client'

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div>
      <h2>ダッシュボードの読み込みに失敗しました</h2>
      <p>問題が続く場合はサポートにお問い合わせください</p>
      <p style={{ fontSize: '0.75rem', color: '#9ca3af' }}>
        エラーID: {error.digest}
      </p>
      <button onClick={reset}>再試行</button>
    </div>
  )
}
```

---

## 8. エラー報告（Sentry / Datadog連携）

### Sentry統合パターン

```tsx
import * as Sentry from '@sentry/react'

// Sentryの初期化（main.tsx）
Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 1.0,
})

// componentDidCatch内でのレポート
class ErrorBoundaryWithSentry extends Component<Props, State> {
  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    Sentry.withScope((scope) => {
      // コンポーネントスタックをSentryに付与
      scope.setExtra('componentStack', errorInfo.componentStack)
      scope.setTag('errorBoundary', this.props.name ?? 'unknown')
      Sentry.captureException(error)
    })
  }
}

// Sentry提供のErrorBoundary（推奨）
function App() {
  return (
    <Sentry.ErrorBoundary
      fallback={({ error, resetError }) => (
        <FallbackComponent error={error} resetErrorBoundary={resetError} />
      )}
      showDialog  // Sentryのユーザーフィードバックダイアログを表示
    >
      <MyApp />
    </Sentry.ErrorBoundary>
  )
}
```

### React 19 + Sentryの統合

```tsx
// createRootのコールバックとSentryを組み合わせ
const root = createRoot(document.getElementById('root')!, {
  onCaughtError(error, errorInfo) {
    Sentry.withScope((scope) => {
      scope.setTag('caught', true)
      scope.setExtra('componentStack', errorInfo.componentStack)
      Sentry.captureException(error)
    })
  },
  onUncaughtError(error, errorInfo) {
    Sentry.withScope((scope) => {
      scope.setLevel('fatal')
      scope.setExtra('componentStack', errorInfo.componentStack)
      Sentry.captureException(error)
    })
  },
})
```

### ユーザーコンテキストの付与

```tsx
// 認証情報をエラーレポートに含める
function AuthenticatedApp({ user }: { user: User }) {
  useEffect(() => {
    Sentry.setUser({
      id: user.id,
      email: user.email,
    })
    return () => Sentry.setUser(null)
  }, [user])

  return (
    <ErrorBoundary
      FallbackComponent={FallbackComponent}
      onError={(error, info) => {
        // ユーザー情報はSentryが自動付与するため追加不要
        Sentry.captureException(error)
      }}
    >
      <Dashboard />
    </ErrorBoundary>
  )
}
```

---

## クイックリファレンス

### エラー種別と推奨対策

```
レンダリングエラー
  └─ ErrorBoundary（react-error-boundary推奨）

非同期エラー（fetch等）
  ├─ useQuery（TanStack Query）→ error state
  ├─ use() + Suspense + ErrorBoundary（React 19）
  └─ try/catch + useErrorBoundary().showBoundary

イベントハンドラエラー
  └─ try/catch + ローカルerror state

グローバル補完
  ├─ window.onerror
  └─ window.onunhandledrejection

エラー報告
  └─ componentDidCatch / onCaughtError / onUncaughtError → Sentry
```

### 配置戦略チェックリスト

- [ ] ルートレベルに最終防衛ラインのErrorBoundaryを配置
- [ ] ページ/ルートレベルにPageErrorBoundaryを配置
- [ ] 独立したウィジェット・重要でないUIをコンポーネントレベルでラップ
- [ ] グローバルエラー監視（`window.onerror`, `onunhandledrejection`）を設定
- [ ] エラー報告サービス（Sentry等）をcomponentDidCatch/onCaughtErrorに統合
- [ ] フォールバックUIにリトライ機能を実装
