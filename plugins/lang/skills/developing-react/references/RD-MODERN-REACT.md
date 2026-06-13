# RD-MODERN-REACT.md — モダンReact 2025 実践ガイド

React Compilerから2025年の状態管理推奨まで、最新プラクティスを網羅する。
useState〜TanStack Queryの詳細は [RI-DATA-MANAGEMENT.md](./RI-DATA-MANAGEMENT.md) を参照。
React 19 Actions/useActionState/use() は [REACT-GUIDE.md](./REACT-GUIDE.md) を参照。

---

## 目次

1. [React Compiler（opt-in自動メモ化）](#1-react-compiler)
2. [Concurrent Features実践](#2-concurrent-features実践)
3. [リスト仮想化](#3-リスト仮想化)
4. [パフォーマンス目標値](#4-パフォーマンス目標値)
5. [2025年状態管理推奨](#5-2025年状態管理推奨)
6. [nuqs — URL状態管理](#6-nuqs--url状態管理)
7. [Jotai — アトミック状態管理](#7-jotai--アトミック状態管理)
8. [Recoil廃止とJotai移行](#8-recoil廃止とjotai移行)
9. [SWR vs TanStack Query](#9-swr-vs-tanstack-query)
10. [状態管理アンチパターン](#10-状態管理アンチパターン)
11. [Web Workers — 重い計算のオフロード](#11-web-workers--重い計算のオフロード)

---

## 1. React Compiler

### 概要

React Compiler（旧: React Forget）はReact 19.2で安定版となった**ビルド時自動メモ化**ツール。
`useMemo` / `useCallback` / `React.memo` を手動で書かずとも、コンパイラがReactのルールを静的解析して自動適用する。
React 17 / 18 / 19 すべてに対応。

### インストール

```bash
# コアパッケージ
npm install babel-plugin-react-compiler

# ESLintルール（必須: コンパイラが苦手なコードを事前検出）
npm install eslint-plugin-react-compiler
```

### 設定パターン

#### Babel（Create React App / 汎用）

```js
// babel.config.js
module.exports = {
  plugins: [
    ['babel-plugin-react-compiler', {
      // opt-in: 特定ディレクトリのみ有効化
      compilationMode: 'annotation', // または 'infer'（デフォルト）
      sources: (filename) => filename.includes('/src/features/'),
      // React 17/18向け: react-compiler-runtime が必要
      runtimeModule: 'react-compiler-runtime',
    }],
  ],
};
```

#### Vite

```ts
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import ReactCompilerPlugin from 'babel-plugin-react-compiler';

export default defineConfig({
  plugins: [
    react({
      babel: {
        plugins: [
          [ReactCompilerPlugin, {
            compilationMode: 'infer',
          }],
        ],
      },
    }),
  ],
});
```

#### Next.js（15.x以降で組み込みサポート）

```ts
// next.config.ts
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  experimental: {
    reactCompiler: {
      compilationMode: 'annotation', // 段階的導入に推奨
    },
  },
};

export default nextConfig;
```

### 自動メモ化が機能する条件と制約

| 条件 | 詳細 |
|------|------|
| ✅ 純粋なコンポーネント | 同じprops → 同じJSXを返す |
| ✅ Reactのルール準拠 | Hooks呼び出し順固定、副作用はuseEffect内 |
| ❌ プロパティの直接ミューテーション | `props.items.push(...)` 等 |
| ❌ 外部可変変数への依存 | クロージャで外部変数を捕捉して書き換え |
| ❌ `'use no memo'` ディレクティブ | 明示的にオプトアウトしたファイル |

### React 17/18向け: react-compiler-runtime

```bash
npm install react-compiler-runtime
```

React 19未満では `useMemoCache` がないため、このポリフィルが必要。

### まだ手動メモ化が必要なケース

```tsx
// ❌ React Compilerでは最適化不可: 参照等価性の比較が必要な外部ライブラリ
const chartData = useMemo(() => transformData(rawData), [rawData]);
// react-chartjs-2 等は参照が変わると全再描画するため手動useMemoが有効

// ✅ React Compilerで自動最適化: 純粋な計算
// コンパイラが自動的にメモ化するため useMemo 不要
const filtered = data.filter(item => item.active);
```

---

## 2. Concurrent Features実践

> **概念説明**: Concurrent Mode・Fiberスケジューリングの仕組みは [RI-PERFORMANCE.md](./RI-PERFORMANCE.md) を参照。

### useTransition — UI応答性の維持

重い状態更新を「非緊急」としてマークし、UIのブロッキングを防ぐ。

```tsx
import { useTransition, useState } from 'react';

function SearchPage() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Result[]>([]);
  const [isPending, startTransition] = useTransition();

  const handleSearch = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    // 入力フィールドは即座に更新（緊急）
    setQuery(value);

    // 検索結果更新は非緊急としてマーク
    startTransition(() => {
      setResults(expensiveSearch(value));
    });
  };

  return (
    <>
      <input value={query} onChange={handleSearch} />
      {isPending ? (
        <Spinner />
      ) : (
        <ResultList items={results} />
      )}
    </>
  );
}
```

**適用パターン**: 検索・フィルタリング・ページネーション・タブ切り替え

### useDeferredValue — 外部コンポーネント制御時の代替

`startTransition` を呼べない（外部コンポーネントへの値渡しのみ）場面で使用。

```tsx
import { useDeferredValue, memo } from 'react';

function ProductList({ query }: { query: string }) {
  // 外部の重いコンポーネントには遅延値を渡す
  const deferredQuery = useDeferredValue(query);
  const isStale = query !== deferredQuery;

  return (
    <div style={{ opacity: isStale ? 0.7 : 1 }}>
      {/* HeavyList は deferredQuery が変わったときのみ再レンダリング */}
      <HeavyList query={deferredQuery} />
    </div>
  );
}

// memo必須: deferredQueryが変わらない限り再レンダリングしない
const HeavyList = memo(({ query }: { query: string }) => {
  // 重い計算...
});
```

**useTransition vs useDeferredValue の選択**:
- `startTransition` を自分で呼べる → `useTransition`
- 子コンポーネントへの props 渡しのみ → `useDeferredValue`

---

## 3. リスト仮想化

1万件以上のリストを全DOMに展開するとメモリとレンダリング時間が爆発する。
仮想化は「ビューポート内の可視アイテムのみ」をDOMにレンダリングする。

### react-window（軽量・安定）

```bash
npm install react-window
npm install -D @types/react-window
```

```tsx
import { FixedSizeList } from 'react-window';

interface Item { id: number; name: string }

const Row = ({ index, style, data }: {
  index: number;
  style: React.CSSProperties;
  data: Item[];
}) => (
  <div style={style}>
    {data[index].name}
  </div>
);

function VirtualizedList({ items }: { items: Item[] }) {
  return (
    <FixedSizeList
      height={600}
      width="100%"
      itemCount={items.length}
      itemSize={50}        // 各行の高さ（px）
      itemData={items}
    >
      {Row}
    </FixedSizeList>
  );
}
```

### @tanstack/virtual（柔軟・可変高さ対応）

```bash
npm install @tanstack/react-virtual
```

```tsx
import { useVirtualizer } from '@tanstack/react-virtual';
import { useRef } from 'react';

function DynamicList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 60,   // 初期推定値
    overscan: 5,              // ビューポート外に先読みする件数
  });

  return (
    <div ref={parentRef} style={{ height: '600px', overflow: 'auto' }}>
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: 'relative' }}>
        {virtualizer.getVirtualItems().map(virtualItem => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            {items[virtualItem.index].name}
          </div>
        ))}
      </div>
    </div>
  );
}
```

**選択基準**:
- 固定高さのシンプルなリスト → `react-window`
- 可変高さ・グリッド・水平スクロール・無限スクロール → `@tanstack/virtual`

---

## 4. パフォーマンス目標値

| 指標 | 目標値 | 説明 |
|------|--------|------|
| Lighthouse Performance | **90+** | 総合スコア |
| LCP（Largest Contentful Paint） | **< 2.5s** | 最大コンテンツ描画 |
| FCP（First Contentful Paint） | **< 1.8s** | 初回コンテンツ描画 |
| CLS（Cumulative Layout Shift） | **< 0.1** | レイアウトシフト累積 |
| INP（Interaction to Next Paint） | **< 200ms** | インタラクション応答性 |
| TTI（Time to Interactive） | **< 3.8s** | インタラクティブ化まで |

測定ツール: `web-vitals` ライブラリ + Lighthouse CI + Chrome DevTools Performance panel

---

## 5. 2025年状態管理推奨

### 状態分類フレームワーク

「この状態はどこに住むべきか？」という設計判断の軸。

| 種別 | 説明 | 推奨ソリューション |
|------|------|------------------|
| **ローカル状態** | 単一コンポーネント内 | `useState` / `useReducer` |
| **グローバル状態** | 複数コンポーネント間の共有UI状態 | Zustand / Jotai |
| **サーバー状態** | APIから取得・キャッシュ・同期 | TanStack Query / SWR |
| **URL状態** | URLに永続化すべきフィルタ・ページ等 | nuqs |
| **フォーム状態** | バリデーション付きフォーム入力 | React Hook Form + Zod |

> Zustand/TanStack Queryの詳細実装は [RI-DATA-MANAGEMENT.md](./RI-DATA-MANAGEMENT.md) を参照。

### State of React 2024 トレンド

- **Zustand**: 満足度1位（28% → 41%に急増）
- **Jotai**: アトミック状態管理の新標準
- **Redux Toolkit**: エンタープライズでは引き続き有力
- **Recoil**: 2024年に**Meta公式アーカイブ** → 使用禁止

---

## 6. nuqs — URL状態管理

URLクエリパラメータを型安全に管理するライブラリ。検索フィルタ・ページネーション・ソート順など、**URLに永続化すべき状態**に最適。

```bash
npm install nuqs
```

### 基本使用法

```tsx
import { useQueryState, parseAsInteger, parseAsString } from 'nuqs';

function ProductSearchPage() {
  // /products?page=2&q=react&sort=price
  const [page, setPage] = useQueryState('page', parseAsInteger.withDefault(1));
  const [query, setQuery] = useQueryState('q', parseAsString.withDefault(''));
  const [sort, setSort] = useQueryState('sort',
    parseAsString.withDefault('relevance')
  );

  return (
    <>
      <input
        value={query}
        onChange={e => setQuery(e.target.value || null)} // nullでパラメータ削除
      />
      <button onClick={() => setPage(p => p + 1)}>次ページ</button>
    </>
  );
}
```

### Next.js統合（App Router）

```tsx
// app/layout.tsx
import { NuqsAdapter } from 'nuqs/adapters/next/app';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        <NuqsAdapter>{children}</NuqsAdapter>
      </body>
    </html>
  );
}
```

### useQueryStates — 複数パラメータの一括管理

```tsx
import { useQueryStates, parseAsInteger, parseAsString } from 'nuqs';

const searchParams = {
  page: parseAsInteger.withDefault(1),
  q: parseAsString.withDefault(''),
  category: parseAsString,
};

function SearchFilters() {
  const [params, setParams] = useQueryStates(searchParams);

  const resetFilters = () => setParams({
    page: 1,
    q: '',
    category: null,
  });

  return <button onClick={resetFilters}>リセット</button>;
}
```

---

## 7. Jotai — アトミック状態管理

Recoilの後継として推奨されるアトミック状態管理ライブラリ。
**最小単位（atom）** で状態を定義し、コンポーネントはその一部だけをサブスクライブする。

```bash
npm install jotai
```

### 基本パターン

```tsx
import { atom, useAtom, useAtomValue, useSetAtom } from 'jotai';

// アトムの定義
const countAtom = atom(0);
const userAtom = atom<User | null>(null);

// 読み書き両方
function Counter() {
  const [count, setCount] = useAtom(countAtom);
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}

// 読み取り専用（再レンダリング最小化）
function Display() {
  const count = useAtomValue(countAtom);
  return <span>{count}</span>;
}

// 書き込み専用（読み取り不要なアクション）
function ResetButton() {
  const setCount = useSetAtom(countAtom);
  return <button onClick={() => setCount(0)}>リセット</button>;
}
```

### 派生アトム（computed atom）

```tsx
// 読み取り専用派生アトム
const doubleCountAtom = atom(get => get(countAtom) * 2);

// 非同期アトム（Suspenseと組み合わせ）
const userDataAtom = atom(async (get) => {
  const userId = get(userIdAtom);
  const response = await fetch(`/api/users/${userId}`);
  return response.json() as Promise<User>;
});
```

### atomFamily — 動的アトム生成

```tsx
import { atomFamily } from 'jotai/utils';

// IDごとに独立したアトムを生成
const todoAtomFamily = atomFamily((id: number) =>
  atom<Todo | null>(null)
);

function TodoItem({ id }: { id: number }) {
  const [todo, setTodo] = useAtom(todoAtomFamily(id));
  // ...
}
```

### Zustand vs Jotai の選択基準

| 観点 | Zustand | Jotai |
|------|---------|-------|
| 状態の粒度 | ストア単位（オブジェクト） | アトム単位（最小値） |
| 再レンダリング制御 | セレクター関数 | アトムの購読自動制御 |
| DevTools | Zustand DevTools | Jotai DevTools |
| 適合シーン | 関連する状態をまとめて管理 | 独立した細粒度の状態 |

---

## 8. Recoil廃止とJotai移行

**2024年、MetaがRecoilを公式アーカイブ。新規プロジェクトでの使用は禁止。**

### 移行対応表

| Recoil | Jotai |
|--------|-------|
| `atom({ key: 'x', default: 0 })` | `atom(0)` |
| `selector({ get: ({ get }) => ... })` | `atom(get => ...)` |
| `useRecoilState(xAtom)` | `useAtom(xAtom)` |
| `useRecoilValue(xAtom)` | `useAtomValue(xAtom)` |
| `useSetRecoilState(xAtom)` | `useSetAtom(xAtom)` |
| `atomFamily(params => ...)` | `atomFamily(id => atom(...))` |
| `RecoilRoot` | `Provider`（省略可: デフォルトストアを使用） |

### 移行手順

1. `jotai` をインストール
2. `atom()` 定義をキー不要の形式に変換
3. `selector` → 読み取り専用 `atom(get => ...)` に変換
4. `RecoilRoot` → `Provider`（または省略）に変換
5. `recoil` をアンインストール

---

## 9. SWR vs TanStack Query

| 観点 | SWR | TanStack Query |
|------|-----|----------------|
| バンドルサイズ | ~4KB（軽量） | ~40KB（高機能） |
| Mutation | 基本的なmutate | `useMutation`（楽観的更新・ロールバック） |
| DevTools | なし | 専用DevTools（必須級） |
| キャッシュ制御 | シンプル | 細粒度（staleTime/gcTime） |
| 無限スクロール | `useSWRInfinite` | `useInfiniteQuery` |
| Optimistic Updates | 手動 | 組み込みサポート |
| 適合シーン | シンプルなデータフェッチ | 複雑なサーバー状態管理 |

**推奨**: **TanStack Query**（旧: React Query）を標準採用。
理由: DevTools・mutation・楽観的更新・prefetchingの完成度が高く、チームの生産性が向上する。
詳細実装は [RI-DATA-MANAGEMENT.md](./RI-DATA-MANAGEMENT.md) を参照。

---

## 10. 状態管理アンチパターン

### アンチパターン1: Provider Hell（5層以上のネスト）

```tsx
// ❌ Before: 深すぎるProviderネスト
function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <CartProvider>
          <NotificationProvider>
            <ModalProvider>
              <Router />
            </ModalProvider>
          </NotificationProvider>
        </CartProvider>
      </AuthProvider>
    </ThemeProvider>
  );
}

// ✅ After: Zustand/Jotaiでグローバル状態を管理し、Providerを削減
// authStore, cartStore → Zustand atoms
// notificationAtom, modalAtom → Jotai atoms
function App() {
  return (
    <ThemeProvider>  {/* テーマはCSS変数でも代替可 */}
      <Router />
    </ThemeProvider>
  );
}
```

### アンチパターン2: Monolithic Context（無関係な状態の集約）

```tsx
// ❌ Before: 無関係な状態を1つのContextに詰め込む
const AppContext = createContext<{
  user: User | null;
  cart: CartItem[];
  theme: Theme;
  notifications: Notification[];
  modalOpen: boolean;
}>({ ... });

// 問題: userが変わるとcartを使っているコンポーネントも全再レンダリング

// ✅ After: 関心ごとに分割（またはZustandで分割ストア）
const userAtom = atom<User | null>(null);
const cartAtom = atom<CartItem[]>([]);
// それぞれ独立してサブスクライブ → 不要な再レンダリングなし
```

### アンチパターン3: 過剰なProp Drilling（3階層超）

```tsx
// ❌ Before: 3階層以上にわたるprops受け渡し
function Page({ userId }: { userId: string }) {
  return <Section userId={userId} />;
}
function Section({ userId }: { userId: string }) {
  return <Widget userId={userId} />;
}
function Widget({ userId }: { userId: string }) {
  // やっとここで使う
  const user = useUser(userId);
}

// ✅ After: カスタムフックで直接取得
function Widget() {
  // useUserIdAtomでIDを取得 or Context/Jotaiアトムを直接参照
  const userId = useAtomValue(currentUserIdAtom);
  const user = useUser(userId);
}
```

### アンチパターン4: コンポーネント内ビジネスロジック

```tsx
// ❌ Before: コンポーネントにビジネスロジックが混在
function CheckoutButton({ items }: { items: CartItem[] }) {
  const handleCheckout = async () => {
    // ロジックが直接コンポーネントに書かれている
    const total = items.reduce((sum, item) => sum + item.price * item.qty, 0);
    const discount = total > 10000 ? total * 0.1 : 0;
    const tax = (total - discount) * 0.1;
    await fetch('/api/orders', {
      method: 'POST',
      body: JSON.stringify({ items, total, discount, tax }),
    });
  };
  return <button onClick={handleCheckout}>購入</button>;
}

// ✅ After: カスタムフックにビジネスロジックを抽出
function useCheckout(items: CartItem[]) {
  const { mutateAsync, isPending } = useMutation({
    mutationFn: (orderData: OrderData) =>
      fetch('/api/orders', { method: 'POST', body: JSON.stringify(orderData) }),
  });

  const checkout = async () => {
    const total = calculateTotal(items);   // 純粋関数に抽出
    const discount = calculateDiscount(total);
    const tax = calculateTax(total, discount);
    await mutateAsync({ items, total, discount, tax });
  };

  return { checkout, isPending };
}

function CheckoutButton({ items }: { items: CartItem[] }) {
  const { checkout, isPending } = useCheckout(items);
  return <button onClick={checkout} disabled={isPending}>購入</button>;
}
```

---

## 11. Web Workers — 重い計算のオフロード

JavaScriptはシングルスレッドのため、重い計算がメインスレッドをブロックするとUIが固まる。
Web WorkersでCPU負荷の高い処理をオフロードする。

### Comlink — PostMessage RPC化

```bash
npm install comlink
```

```ts
// worker.ts
import { expose } from 'comlink';

const api = {
  // 重い計算（素数探索・画像処理・大規模ソート等）
  findPrimes(limit: number): number[] {
    const primes: number[] = [];
    for (let n = 2; n <= limit; n++) {
      const isPrime = !primes.some(p => n % p === 0 && p * p <= n);
      if (isPrime) primes.push(n);
    }
    return primes;
  },

  processLargeDataset(data: number[]): { sum: number; avg: number } {
    const sum = data.reduce((a, b) => a + b, 0);
    return { sum, avg: sum / data.length };
  },
};

expose(api);

export type WorkerApi = typeof api;
```

```tsx
// useWorker.ts
import { wrap } from 'comlink';
import type { WorkerApi } from './worker';

let workerInstance: ReturnType<typeof wrap<WorkerApi>> | null = null;

function getWorker() {
  if (!workerInstance) {
    const worker = new Worker(new URL('./worker.ts', import.meta.url), {
      type: 'module',
    });
    workerInstance = wrap<WorkerApi>(worker);
  }
  return workerInstance;
}

// Reactコンポーネントから使用
function PrimeCalculator() {
  const [primes, setPrimes] = useState<number[]>([]);
  const [isPending, startTransition] = useTransition();

  const calculate = async () => {
    const worker = getWorker();
    // Workerの呼び出しが通常の非同期関数と同じ見た目に！
    const result = await worker.findPrimes(100_000);
    startTransition(() => setPrimes(result));
  };

  return (
    <>
      <button onClick={calculate} disabled={isPending}>
        {isPending ? '計算中...' : '素数を計算'}
      </button>
      <p>{primes.length}件の素数が見つかりました</p>
    </>
  );
}
```

### Web Workerの適用判断基準

| 処理 | 目安 | 推奨 |
|------|------|------|
| JSONパース（大規模） | > 5MB | Worker推奨 |
| 画像処理・フィルタ | 常に | Worker推奨 |
| 暗号化・ハッシュ計算 | 常に | Worker推奨 |
| ソート・フィルタ | < 10,000件 | メインスレッドで可 |
| ソート・フィルタ | > 100,000件 | Worker推奨 |

> **注意**: Workers間でのDOM操作は不可。`document` / `window` にアクセスできない。
> SharedArrayBuffer（高速データ共有）はCross-Origin Isolation設定が必要（COOP/COEP ヘッダー）。
