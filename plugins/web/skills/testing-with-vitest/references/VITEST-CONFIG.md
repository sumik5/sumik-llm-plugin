# VITEST-CONFIG — 設定・環境・カバレッジ・レポーター

Vitest v4.x（v4.1.7 確認済み）の設定集約リファレンス。Node.js >= 20、Vite >= 6 が必須要件。

---

## defineConfig 基本構造

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,          // describe/it/expect のグローバル注入
    environment: 'node',    // デフォルト（後述）
    include: ['src/**/*.test.ts'],
    exclude: ['node_modules', '.git'], // v4: dist/cypress は手動追加が必要
    setupFiles: ['./src/test/setup.ts'],
  },
})
```

`vite.config.ts` に統合する場合は `/// <reference types="vitest" />` を先頭に追加し、同じ `defineConfig` に `test:` キーを追記する。

---

## テスト環境

### 組み込み環境

| 環境 | 特徴 | 用途 |
|------|------|------|
| `node` | デフォルト。Node.js ネイティブ | サーバーサイド・ユーティリティ |
| `jsdom` | DOM/BOM を jsdom でエミュレート | React/Vue コンポーネント（軽量） |
| `happy-dom` | jsdom より高速な DOM 実装 | コンポーネント、高速化が必要な場合 |
| `edge-runtime` | Vercel Edge Runtime 互換 | Edge Functions のテスト |

> 環境設定は **Node 実行時のみ有効**。ブラウザ実行には `test.projects` + Browser Mode を使う（`testing-with-vitest` スキルの VITEST-BROWSER-MODE.md 参照）。

### ファイル単位の環境切り替え

```typescript
// @vitest-environment jsdom
// ↑ ファイル先頭に記述するとこのファイルだけ jsdom で実行される

import { render } from '@testing-library/react'
```

### 設定ファイルでの指定

```typescript
export default defineConfig({
  test: {
    environment: 'happy-dom',
    server: {
      deps: {
        // CSS/静的アセットの import でクラッシュする場合にインライン化
        inline: ['problem-pkg', '@scope/ui-lib'],
      },
    },
  },
})
```

### test.projects（マルチ設定 / モノレポ）

```typescript
// v4: workspace は test.projects に統合（外部ファイル参照は不可・インライン定義のみ）
export default defineConfig({
  test: {
    projects: [
      {
        test: {
          name: 'unit',
          environment: 'node',
          include: ['src/**/*.test.ts'],
        },
      },
      {
        test: {
          name: 'browser',
          browser: {
            enabled: true,
            // provider は文字列ではなくオブジェクト（v4）
            // 詳細は VITEST-BROWSER-MODE.md 参照
          },
        },
      },
    ],
  },
})
```

---

## カバレッジ

### プロバイダー比較

| 項目 | `v8`（デフォルト） | `istanbul` |
|------|------------------|------------|
| 仕組み | Node.js V8 ネイティブ + AST ベース remapping | 計装（instrumentation）ベース |
| 精度 | v4 で大幅改善（AST remapping により Istanbul 同等） | 高精度・実績あり |
| 速度 | 速い | やや遅い |
| 対応ランタイム | Node.js（V8 ランタイム） | Node.js・Firefox・Bun・Cloudflare Workers 等 |
| インストール | `@vitest/coverage-v8` | `@vitest/coverage-istanbul` |

> v4 で削除されたオプション: `coverage.all`、`coverage.ignoreEmptyLines`、`coverage.experimentalAstAwareRemapping`、`coverage.extensions`

### 基本設定

```typescript
test: {
  coverage: {
    provider: 'v8',                   // または 'istanbul'
    include: ['src/**/*.{ts,tsx}'],   // 明示しないと import されたファイルのみ計上
    exclude: ['**/*.spec.ts', '**/*.test.ts', 'src/test/**'],
    reporter: ['text', 'html', 'json'],
    // thresholds: ビジネスロジックは 100% を目指す
    thresholds: {
      lines: 100,
      functions: 100,
      branches: 90,
      statements: 100,
    },
    // V8 プロバイダーのみ: 指定クラスメソッドをカバレッジから除外（v4 新規）
    ignoreClassMethods: ['toString', 'toJSON'],
  },
}
```

### スレッショルドのショートハンド

```typescript
thresholds: { 100: true }  // lines/functions/branches/statements すべて 100% に設定
```

`per-file: true` を追加するとファイル単位でしきい値を適用する。

### ignore ヒントコメント

TypeScript / esbuild 環境では `-- @preserve` が必須（コメントが除去されるのを防ぐ）。

```typescript
// V8: 次の1行を無視
/* v8 ignore next -- @preserve */
const unreachable = () => { throw new Error() }

// V8: ファイル全体を無視
/* v8 ignore file */

// Istanbul: 範囲指定（-- @preserve 必須）
/* istanbul ignore start -- @preserve */
function legacyFallback() { /* ... */ }
/* istanbul ignore stop -- @preserve */
```

### CLI でのカバレッジ実行

```bash
# V8 でカバレッジを計測
vitest run --coverage

# プロバイダーを上書き
vitest run --coverage --coverage.provider=istanbul
```

---

## レポーター

### 組み込みレポーター一覧

| 名前 | 説明 |
|------|------|
| `default` | ターミナル出力（失敗のみ詳細） |
| `verbose` | 全テスト名と結果を展開、アノテーションもパス時に表示 |
| `tree` | ファイルツリー形式（`slowTestThreshold` 超えをハイライト） |
| `json` | JSON 形式・`coverageMap` を含む（v3 以降） |
| `junit` | JUnit XML 形式（CI 統合向け） |
| `html` | @vitest/ui を要するインタラクティブ HTML レポート |
| `tap` | TAP（Test Anything Protocol） |
| `github-actions` | GitHub Actions ワークフローアノテーション |
| `blob` | シャーディング用中間バイナリ出力 |
| `minimal` / `agent` | AI エージェント環境でのトークン削減向け（自動有効化） |

> v4 で削除: `basic` レポーター、`onCollected` / `onTaskUpdate` / `onFinished` 等のコールバック API

### 自動有効化

| 条件 | 自動有効化されるレポーター |
|------|--------------------------|
| `GITHUB_ACTIONS === 'true'` | `github-actions` |
| AI コーディングエージェント環境 | `minimal` / `agent`（トークン節約）・テキストカバレッジの `skipFull: true` |

### 複数レポーターの設定

```typescript
test: {
  reporters: [
    'default',
    ['junit', { suiteName: 'Unit Tests' }],  // オプション付きはタプル形式
    'github-actions',
  ],
  outputFile: {
    junit: './reports/junit.xml',
    json:  './reports/report.json',
  },
}
```

### シャーディング + blob レポーター

```bash
# CI で分割実行
vitest run --shard=1/3 --reporter=blob --outputFile=.vitest-reports/blob-1.json
vitest run --shard=2/3 --reporter=blob --outputFile=.vitest-reports/blob-2.json
vitest run --shard=3/3 --reporter=blob --outputFile=.vitest-reports/blob-3.json

# 結果を統合
vitest run --merge-reports
```

---

## よくあるエラーと対処

### CSS / 静的アセットの import が失敗する

```
Error: Failed to transform ... [vite]
```

jsdom や happy-dom 環境では CSS / 画像の import がエラーになる場合がある。  
`server.deps.inline` に該当パッケージを追加してインライン変換する。

```typescript
test: {
  server: { deps: { inline: ['@mui/material', 'problem-css-lib'] } },
}
```

### tsconfig の `baseUrl` / `paths` が解決されない

```
Cannot find module '@/components/Button'
```

`vite-tsconfig-paths` プラグインをインストールして Vitest 設定に追加する。

```bash
npm install -D vite-tsconfig-paths
```

```typescript
import tsconfigPaths from 'vite-tsconfig-paths'

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: { /* ... */ },
})
```

### NodeJS `fetch` 使用時にワーカーが終了する

```
Worker terminated unexpectedly
```

Node.js のネイティブ `fetch` は `pool: 'threads'` で動作しない。`'forks'` に切り替える。

```typescript
test: { pool: 'forks' }
```

ネイティブモジュール（`.node` バイナリ）でセグメンテーションフォルトが発生する場合も同様に `'forks'` を使う。

### カスタム export conditions が効かない

```
Package subpath './edge' is not defined
```

`resolve.conditions` ではなく `ssr.resolve.conditions` を使う。

```typescript
export default defineConfig({
  ssr: {
    resolve: {
      conditions: ['custom-condition', 'edge'],
    },
  },
})
```

### カスタム環境で `transformMode` エラー（v4 移行）

v4 でモジュールランナーが vite-node から置き換えられた。カスタム環境で `transformMode` を設定していた場合は削除し、`viteEnvironment` を使う。

```typescript
// カスタム環境の export
export default {
  name: 'my-env',
  viteEnvironment: 'ssr',   // 'ssr' | 'client' | カスタム文字列
  // transformMode は不要（v4 で削除）
}
```

### `.resolves` / `.rejects` を await し忘れる（v4 でハードエラー）

v4 からは `await` なしの `.resolves` / `.rejects` がテスト失敗になる（v3 では警告のみ）。

```typescript
// NG: v4 でテスト失敗
expect(promise).resolves.toBe('value')

// OK
await expect(promise).resolves.toBe('value')
await expect(rejectingFn()).rejects.toThrow('error message')
```

---

## 関連ファイル

- [./VITEST-V4-MIGRATION.md](./VITEST-V4-MIGRATION.md) — v3→v4 破壊的変更の全一覧
- [./VITEST-CLI.md](./VITEST-CLI.md) — CLI フラグ・デバッグ・watch モード
- [./VITEST-PROJECTS-PERFORMANCE.md](./VITEST-PROJECTS-PERFORMANCE.md) — test.projects・プール・並列化・シャーディング
