# Test Projects・Monorepo と並列パフォーマンス

Vitest v4.x（v4.1.7）での複数設定実行（`test.projects`）と、並列処理・パフォーマンスチューニングのリファレンス。
Node.js >= 20、Vite >= 6 が必須。

---

## test.projects — 複数設定を一括実行

### v4 での変更点

v4 で `workspace` オプションが廃止され、`test.projects` に統一された。
**外部ファイル参照は不可**（インライン定義のみ）。

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import { playwright } from '@vitest/browser-playwright'

export default defineConfig({
  test: {
    projects: [
      // Node 環境でのユニットテスト
      {
        test: {
          name: 'unit',
          environment: 'node',
          include: ['src/**/*.test.ts'],
          exclude: ['src/**/*.browser.test.ts'],
        },
      },
      // jsdom 環境でのコンポーネントテスト
      {
        test: {
          name: 'component',
          environment: 'jsdom',
          include: ['src/**/*.component.test.ts'],
        },
      },
      // 実ブラウザでのインタラクションテスト
      {
        test: {
          name: 'browser',
          browser: {
            enabled: true,
            provider: playwright(),
            instances: [{ browser: 'chromium' }],
            headless: true,
          },
          include: ['src/**/*.browser.test.ts'],
        },
      },
    ],
  },
})
```

### プロジェクトごとの設定項目

| 設定キー | 用途 | 例 |
|---------|------|-----|
| `name` | レポート・フィルタ時の識別子 | `'unit'` / `'browser'` |
| `include` | 対象ファイル glob | `['src/**/*.test.ts']` |
| `exclude` | 除外ファイル glob | `['**/*.e2e.ts']` |
| `environment` | Node 実行時の DOM 環境 | `'node'` / `'jsdom'` / `'happy-dom'` |
| `browser` | ブラウザ実行設定（ブラウザモード） | `{ enabled: true, provider: playwright() }` |
| `pool` / `maxWorkers` | ワーカー設定をプロジェクト別に上書き | `{ pool: 'threads' }` |

### glob 定義とインライン定義

プロジェクトは glob 文字列とオブジェクトの混在が可能。

```typescript
test: {
  projects: [
    'packages/*/vitest.config.ts',   // モノレポ：各パッケージの設定ファイル
    { test: { name: 'shared', include: ['shared/**/*.test.ts'] } },
  ],
}
```

### --project でのフィルタ

```bash
# 特定プロジェクトのみ実行
vitest run --project=unit
vitest run --project=browser --project=component
```

---

## 並列処理の 2 レベル

### レベル 1 — ファイル単位並列（最大の速度レバー）

デフォルトで有効。ワーカープールにファイルを分散配置し、複数ファイルを同時実行する。
`fileParallelism: false` で無効化（デバッグ時・競合リソース使用時）。

```typescript
test: {
  fileParallelism: true,  // デフォルト: true
  maxWorkers: 4,          // ワーカー数を明示指定
}
```

### レベル 2 — テスト単位並列（I/O バウンドに限定）

`test.concurrent` / `describe.concurrent` で同一ファイル内のテストを並列実行。
CPU バウンドのテストには効果が薄く、共有状態があると競合するため I/O 待ちのテストに限定する。

**concurrent テストでは `expect` を引数から分割代入すること。**
グローバルの `expect` はどのテストに属するかを判別できず、誤ったテストに結果が紐づく。

```typescript
import { describe, test } from 'vitest'

describe.concurrent('並列グループ', () => {
  test('API 呼び出し A', async ({ expect }) => {
    const actual = await fetchEndpointA()
    expect(actual.status).toBe(200)
  })

  test('API 呼び出し B', async ({ expect }) => {
    const actual = await fetchEndpointB()
    expect(actual.status).toBe(200)
  })
})
```

---

## プール種別

| プール | 特徴 | 推奨シナリオ |
|--------|------|------------|
| `'forks'` | **デフォルト**。子プロセス（fork）でワーカーを起動。セグフォルト・ハング回避に最適 | ほとんどのプロジェクト。native modules・Node.js fetch を使う場合は必須 |
| `'threads'` | Worker Threads で起動。forks より高速 | ピュアな JS/TS テストで速度優先 |
| `'vmThreads'` | Worker Threads ＋ VM コンテキストで強い隔離 | 隔離が必要だが高コスト（`isolate:false` 不可） |
| `'vmForks'` | fork ＋ VM コンテキスト。最も強い隔離 | 同上。native modules とも組み合わせ可 |

```typescript
// threads プール使用例
test: {
  pool: 'threads',
  maxWorkers: 4,
  fileParallelism: true,
  maxConcurrency: 5,      // 1 ワーカー内の最大同時実行テスト数（デフォルト: 5）
}
```

---

## maxWorkers / isolate / fileParallelism / maxConcurrency

### maxWorkers

v4 で `maxThreads` / `maxForks` が廃止され `maxWorkers` に一本化された。
環境変数も `VITEST_MAX_THREADS` / `VITEST_MAX_FORKS` から `VITEST_MAX_WORKERS` に変更。

```bash
VITEST_MAX_WORKERS=4 vitest run
```

### isolate（デフォルト: true）

`isolate: false` にするとファイル間でモジュールキャッシュを共有し高速化できる。
ただし副作用が残るため、テスト側で手動クリーンアップが必要。

```typescript
// vmThreads は isolate:false 非対応
test: {
  pool: 'forks',
  isolate: false,         // 高速化。モジュールキャッシュ共有
  maxWorkers: 1,          // isolate:false + maxWorkers:1 は旧 singleFork/singleThread の代替
}
```

### maxConcurrency

1 ワーカー内で同時に実行する `test.concurrent` テストの上限（デフォルト: 5）。

```typescript
test: {
  maxConcurrency: 10,    // I/O 多重度を上げたい場合
}
```

---

## シャーディング — CI での分散実行

大量テストスイートを複数 CI ジョブに分割し、最後に結果をマージする。

```bash
# Job 1 of 3
vitest run --shard=1/3 --reporter=blob --outputFile=.vitest-reports/blob-1.json

# Job 2 of 3
vitest run --shard=2/3 --reporter=blob --outputFile=.vitest-reports/blob-2.json

# Job 3 of 3
vitest run --shard=3/3 --reporter=blob --outputFile=.vitest-reports/blob-3.json

# 全ジョブ完了後にマージ（別ジョブまたはローカルで実行）
vitest run --merge-reports
```

- `--reporter=blob` は `--shard` と組み合わせて使用する（watch モード不可）
- マージ後のレポートは `--reporter=html` / `--reporter=junit` 等で出力可能

---

## その他のパフォーマンス設定

### experimental.fsModuleCache

変換済みファイルのキャッシュをディスクに永続化し、再実行時の変換コストを削減する（実験的）。

```typescript
test: {
  experimental: {
    fsModuleCache: true,
  },
}
```

### test.dir — 探索範囲の限定

モノレポで `test.dir` を指定すると、指定ディレクトリ配下のみをテストファイル探索対象にする。
不要なディレクトリを走査しないため大規模リポジトリで効果的。

```typescript
test: {
  dir: 'src',   // src/ 配下のみ探索
}
```

### sequence.hooks

フック（`beforeEach` 等）の実行順を制御する。デフォルトは `'parallel'`（`maxConcurrency` で上限）。

```typescript
test: {
  sequence: {
    hooks: 'list',     // 'parallel'（デフォルト）| 'list'（直列）| 'stack'
  },
}
```

---

## 設定早見表

| 設定 | デフォルト | チューニング用途 |
|------|-----------|----------------|
| `pool` | `'forks'` | `'threads'` で速度優先、`'vmForks'` で隔離強化 |
| `maxWorkers` | CPU 数依存 | CI 並列度に合わせて指定 |
| `fileParallelism` | `true` | `false` でシリアル実行（デバッグ時） |
| `maxConcurrency` | `5` | I/O 多重度に応じて調整 |
| `isolate` | `true` | `false` で高速化（副作用管理が前提） |
| `test.dir` | プロジェクトルート | モノレポで探索範囲を限定 |

---

## 関連ファイル

- [./VITEST-CONFIG.md](./VITEST-CONFIG.md) — coverage・environments・reporters 等の設定リファレンス
- [./VITEST-BROWSER-MODE.md](./VITEST-BROWSER-MODE.md) — test.projects を使ったブラウザモードの詳細
- [./VITEST-V4-MIGRATION.md](./VITEST-V4-MIGRATION.md) — v3→v4 破壊的変更（maxWorkers 統合・workspace廃止等）
