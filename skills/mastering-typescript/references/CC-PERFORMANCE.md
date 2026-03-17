# TypeScriptパフォーマンス最適化

## 1. パフォーマンス最適化の全体像

### なぜ最適化が重要か

| 観点 | 影響 | 目安値 |
|------|------|--------|
| ユーザー体験 | ページロード時間が1秒→3秒で直帰率が32%増加 | INP < 200ms を目標 |
| コンバージョン | 100msの追加レイテンシで転換率が2〜7%低下 | LCP < 2.5秒 |
| SEO | Googleはページ速度をランキング要因に採用 | CLS < 0.1 |
| スケーラビリティ | 10ユーザーで問題ないクエリが10,000ユーザーで破綻 | 早期から計測習慣を |
| リソースコスト | 非効率な処理がCPU・メモリ・帯域を消費 | プロファイル→最適化サイクル |

### 主要なパフォーマンス劣化原因

| 原因 | 典型症状 | 対策カテゴリ |
|------|---------|------------|
| 過剰な再レンダリング | Reactアプリの描画が重い | React.memo / useMemo |
| 非効率なループ・再帰 | CPU使用率が高い | アルゴリズム改善 |
| 大きなバンドルサイズ | 初期ロードが遅い | Tree shaking / Code splitting |
| 最適化されていないAPIコール | ネットワーク待機が多い | キャッシュ / デバウンス |
| メモリリーク | 時間とともにアプリが遅くなる | イベントリスナー管理 |
| 重複した計算 | 同じ処理が繰り返し実行される | メモ化 |

---

## 2. プロファイリングツール

### ツール選択の判断基準

| 状況 | 推奨ツール | 主な用途 |
|------|----------|---------|
| フロントエンド（ブラウザ） | Chrome DevTools Performance Profiler | JS実行時間・レンダリング・メモリの総合分析 |
| バンドルサイズ調査 | Webpack Bundle Analyzer | 依存関係の可視化・肥大化した依存の特定 |
| Node.jsバックエンド | Node.js `perf_hooks` | 関数実行時間の計測 |
| React再レンダリング | React Developer Tools Profiler | コンポーネント単位の再レンダリング検出 |

### Chrome DevTools Performance Profilerの読み方

| 表示要素 | 意味 | 注意すべき閾値 |
|---------|------|-------------|
| **INP (Interaction to Next Paint)** | ユーザー入力への視覚応答時間 | > 200ms = Bad |
| **赤いバー** | Long Task（メインスレッドブロック）を示す | 即座に調査 |
| **黄色バー** | JavaScript実行中（Summary: Scripting） | 長時間は問題 |
| **紫のバー（スタック内）** | 実際にCPUを消費した関数 | 最も長い関数を最適化 |
| **Bottom-Up ビュー** | 実行時間の多い関数をボトムアップで表示 | ホットパスの特定に使用 |

```typescript
// Node.js バックエンドでの計測例
import { performance } from "perf_hooks";

const start = performance.now();
heavyFunction();
const end = performance.now();
console.log(`実行時間: ${end - start}ms`);
```

### Webpack Bundle Analyzerのセットアップ

```bash
npm install --save-dev webpack-bundle-analyzer
```

```javascript
// webpack.config.js
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
module.exports = {
  mode: 'production',
  plugins: [new BundleAnalyzerPlugin()]
};
```

**読み方のポイント：**
- 最大の矩形 = 最も重い依存ライブラリ
- `moment`（~280KB）や`lodash`（~70KB）のような肥大化した依存を`dayjs`や個別インポートに置き換える
- 自分のコードが小さく外部依存が大きい場合 → 依存置換が最優先

---

## 3. ボトルネック検出パターン

### 遅い関数の検出

**主な原因：** ホットパスでの重複計算（毎回ソートするなど）

```typescript
// ❌ 毎回ソートする（ホットパスで呼ばれると問題）
function processData(data: number[]): number[] {
  const sorted = data.sort((a, b) => a - b);
  return sorted.map(value => value * 2);
}

// ✅ ソートを一度だけ実行して渡す
function processDataOptimized(sortedData: number[]): number[] {
  return sortedData.map(value => value * 2);
}
const sortedData = [...data].sort((a, b) => a - b);
processDataOptimized(sortedData); // 再利用
```

**検出方法：** Chrome DevTools または `performance.now()` で実行時間を計測し、ホットパスの重複処理を洗い出す。

### 過剰な再レンダリングの検出（React）

```typescript
// ❌ 親のstate更新のたびに子もre-render
function MyComponent({ count }: { count: number }) {
  return <div>Count: {count}</div>;
}

// ✅ propsが変わらない限りre-renderをスキップ
const MyComponent = React.memo(({ count }: { count: number }) => {
  return <div>Count: {count}</div>;
});
```

**検出手順：**
1. React Developer Tools を開く
2. Profiler タブ → "Highlight updates when components render" を有効化
3. 操作中に不要なre-renderが発生していないか確認

### メモリリークの検出と修正

```typescript
// ❌ クリーンアップしないとリークが蓄積
useEffect(() => {
  window.addEventListener("resize", () => console.log("Resized!"));
}, []);

// ✅ アンマウント時にリスナーを解除
useEffect(() => {
  const handleResize = () => console.log("Resized!");
  window.addEventListener("resize", handleResize);
  return () => {
    window.removeEventListener("resize", handleResize); // クリーンアップ
  };
}, []);
```

**検出手順：** Chrome DevTools → Memory タブ → Heap Snapshotを時間をおいて比較し、増え続けるオブジェクトを特定

---

## 4. 最適化テクニック

### 4.1 Lazy Loading & Code Splitting

| 手法 | 目的 | 効果 |
|------|------|------|
| Lazy Loading | コンポーネントを必要時のみロード | 初期バンドルサイズ削減 |
| Code Splitting | バンドルを複数チャンクに分割 | FCP / TTI の改善 |

```typescript
// React での Lazy Loading
import React, { Suspense, lazy } from "react";

const Dashboard = lazy(() => import("./Dashboard"));
const Settings = lazy(() => import("./Settings"));

function App() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Dashboard />
    </Suspense>
  );
}
```

```javascript
// Webpack での Code Splitting 有効化
module.exports = {
  optimization: {
    splitChunks: { chunks: "all" },
  },
};
```

> **注意:** Code Splitting は個々の関数を速くするものではない。起動パフォーマンスを改善することが目的。

### 4.2 Tree Shaking（未使用コードの除去）

**前提条件：** ES Modules（`import`/`export`）を使用していること

```json
// package.json — サイドエフェクトなしを宣言
{
  "sideEffects": false
}
```

```bash
# Webpack production モードで自動的に未使用コードを除去
webpack --mode production
```

**適用判断：**
- `require()` を使用している → まず ES Modules に移行
- ライブラリを全体インポート (`import _ from 'lodash'`) → 個別インポート (`import { debounce } from 'lodash-es'`) に変更

### 4.3 キャッシュ戦略

| キャッシュ種別 | 適用場面 | 実装方法 |
|------------|---------|---------|
| メモ化 | 同じ引数で繰り返し呼ばれる純粋関数 | カスタム `memoize` / `useMemo` |
| APIレスポンスキャッシュ | 同一データの重複フェッチ防止 | SWR / React Query / カスタムキャッシュ |
| ブラウザキャッシュ | 静的ファイルの再取得防止 | Cache-Control ヘッダー設定 |

```typescript
// 汎用メモ化関数
function memoize<T extends string | number>(fn: (arg: T) => number) {
  const cache: Record<string, number> = {};
  return (arg: T) => {
    const key = String(arg);
    if (key in cache) return cache[key];
    const result = fn(arg);
    cache[key] = result;
    return result;
  };
}

const square = memoize((n: number) => n * n);
square(4); // 計算して保存
square(4); // キャッシュから返却
```

### 4.4 ループ・再帰の最適化

#### ループ選択の判断基準

| 状況 | 推奨 | 理由 |
|------|------|------|
| ホットパス・パフォーマンス重視 | `for` ループ | コールバックオーバーヘッドがない、予測可能な実行 |
| 可読性・宣言的スタイル重視 | `reduce()` / `map()` | 意図が明確、関数型スタイルと一致 |
| 汎用的なユースケース | どちらでも可 | 現代のJSエンジンでは差はほぼ無視できる |

#### 再帰 vs イテレーション

```typescript
// ❌ 深い再帰はスタックオーバーフローのリスク
function factorial(n: number): number {
  if (n <= 1) return 1;
  return n * factorial(n - 1);
}

// ✅ 大きな入力にはイテレーションが安全
function factorialIterative(n: number): number {
  let acc = 1;
  for (let i = 2; i <= n; i++) acc *= i;
  return acc;
}
```

> **注意:** TypeScript/JavaScriptは末尾呼び出し最適化（TCO）を一貫してサポートしていない。「テールリカージョン」は明確性のテクニックと捉え、メモリ最適化としては信頼しないこと。

| 選択基準 | 推奨 |
|---------|------|
| 入力サイズが大きい・予測不可能 | イテレーション |
| リアルタイム処理・最悪実行時間が重要 | イテレーション |
| 再帰深度が小さく明確に制限されている | 再帰（コード明確性優先） |

### 4.5 非同期操作の最適化

| 問題パターン | 症状 | 対策 |
|------------|------|------|
| キーストローク毎のAPIコール | サーバー過負荷、無駄なリクエスト | デバウンス |
| 同一データの重複フェッチ | 同じAPIを何度も呼ぶ | 結果キャッシュ |
| 無制限の並列Promise | リソース枯渇、競合状態 | 同時実行数の制限（Promiseプール） |
| 古いリクエストのレースコンディション | 古い結果が新しい結果を上書き | AbortController でキャンセル |

```typescript
// デバウンス実装例（APIコール最適化）
function debounce<T extends (...args: any[]) => void>(fn: T, delay: number) {
  let timer: ReturnType<typeof setTimeout>;
  return (...args: Parameters<T>) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}

const fetchResults = debounce((query: string) => {
  console.log("Fetching:", query);
}, 500);

// 500ms間に続けて呼んでも、最後の呼び出しから500ms後に1回だけ実行
fetchResults("T");
fetchResults("Ty");
fetchResults("Typ"); // これだけが実行される
```

---

## 5. パフォーマンス vs 可読性トレードオフ

| 選択肢 | パフォーマンス | 可読性 | 採用タイミング |
|--------|-------------|--------|--------------|
| `for` ループ | 高（オーバーヘッドなし） | 低（命令的） | ホットパス・大規模データ |
| `reduce()` / `map()` | 中（コールバック呼び出しあり） | 高（宣言的） | 通常のユースケース |
| イテレーション | 高（スタック不使用） | 中 | 大きな再帰深度が想定される場合 |
| 再帰 | 低（スタック消費） | 高（数学的に自然） | 再帰深度が少なく明確な場合 |
| `async/await` 逐次 | 低（シリアル実行） | 高 | 順序依存がある処理 |
| `Promise.all()` | 高（並列実行） | 中 | 独立した非同期処理の並列化 |

**基本原則：** 現代のJSエンジンは高度に最適化されており、**マイクロ最適化より冗長な計算の除去の方が大きな効果**をもたらすことが多い。計測で問題が確認された場合のみ最適化を適用する。

---

## 6. 優先度付けフレームワーク

```
最適化の優先順位:
1. ユーザー体験に最も大きな影響 → 最初に修正
2. 少ない労力で大きな改善 → クイックウィン
3. 高頻度実行・複数箇所に影響 → 高インパクト領域
4. バンドルサイズ削減 → Tree shaking / Lazy loading
5. 継続的なモニタリング → 定期的なプロファイリング
```

**ツールチェーン早見表：**

| フェーズ | ツール | 目的 |
|---------|-------|------|
| 計測 | Chrome DevTools Performance | メインスレッドブロックの特定 |
| 計測 | Node.js `perf_hooks` | バックエンド関数の実行時間 |
| 分析 | Webpack Bundle Analyzer | バンドル肥大化の原因特定 |
| 検出 | React Developer Tools Profiler | 不要な再レンダリングの発見 |
| 検出 | Chrome DevTools Memory タブ | メモリリーク調査 |
