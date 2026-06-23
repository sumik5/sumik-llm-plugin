# Vitest 4.x テスト開発ガイド

Vitest はフレームワーク非依存の Vite ネイティブテストランナーで、v4.x は **Node.js >= 20.0.0** および **Vite >= 6.0.0** を要件とする。汎用テスト方法論（TDD/AAA/モック戦略）は `testing-code` スキルを参照。React コンポーネントテスト（RTL）は `lang:developing-react` を参照。ブラウザ E2E は `testing-e2e-with-playwright` を参照。

---

## 使用タイミング

| 状況 | 本スキルを参照 |
|------|--------------|
| `vitest.config.ts` / `vitest.config.js` を作成・編集するとき | ✅ |
| v3 → v4 マイグレーションを実施するとき | ✅ |
| `test.projects`（旧 `workspace`）でモノレポを構成するとき | ✅ |
| Browser Mode / Visual Regression を設定するとき | ✅ |
| Vitest の CLI フラグ・デバッグ・シャーディングを使うとき | ✅ |
| AI 生成テストの Vitest 固有エラーを修正するとき | ✅ |
| フィクスチャ・ライフサイクルフック・カバレッジ設定をチューニングするとき | ✅ |

---

## リファレンス構成

| ファイル | 内容 |
|---------|------|
| [VITEST-V4-MIGRATION.md](./references/VITEST-V4-MIGRATION.md) | v3 → v4 破壊的変更の完全一覧（設定名リネーム・削除・env 変数変更） |
| [VITEST-CONFIG.md](./references/VITEST-CONFIG.md) | カバレッジ・環境・アノテーション・インソーステスト・型テストの設定リファレンス |
| [VITEST-CLI.md](./references/VITEST-CLI.md) | CLI フラグ・実行モード・デバッグ手順 |
| [VITEST-PROJECTS-PERFORMANCE.md](./references/VITEST-PROJECTS-PERFORMANCE.md) | `test.projects` モノレポ構成・プール・シャーディング・`maxWorkers` チューニング |
| [VITEST-BROWSER-MODE.md](./references/VITEST-BROWSER-MODE.md) | Browser Mode（v4 安定化）・ビジュアルリグレッション・ロケーター API |
| [VITEST-FIXTURES.md](./references/VITEST-FIXTURES.md) | `test.extend` ビルダー・フィクスチャスコープ・`test.override`・テストコンテキスト |
| [VITEST-APIS.md](./references/VITEST-APIS.md) | `expect` マッチャー一覧・非同期アサーション・スパイアサーション |
| [VITEST-LIFECYCLE.md](./references/VITEST-LIFECYCLE.md) | フック実行順・`aroundEach`/`aroundAll`・`globalSetup`・`project.provide/inject` |
| [MOCKING.md](./references/MOCKING.md) | `vi.mock`/`vi.fn`/`vi.spyOn`・タイマー・MSW HTTP モック（v4 セマンティクス対応） |

---

## Vitest 4 の必須規約（破壊的変更ハイライト）

### 1. `.resolves` / `.rejects` は必ず `await` する

v4 では await しないアサーションがハードエラーになる（v3 は警告のみだった）。

```typescript
// ✅ 正しい
await expect(fetchUser(1)).resolves.toEqual({ id: 1 })
await expect(fetchUser(-1)).rejects.toThrow('not found')

// ❌ v4 でテスト失敗（await 漏れ）
expect(fetchUser(1)).resolves.toEqual({ id: 1 })
```

### 2. `toThrow` を使う（`toThrowError` は非推奨）

```typescript
// ✅ v4 推奨
expect(() => validate(null)).toThrow('required')

// ❌ v4 非推奨（動作するが警告）
expect(() => validate(null)).toThrowError('required')
```

### 3. `vi.fn()` は `jest.fn()` ではない

```typescript
import { vi } from 'vitest'

// ✅ Vitest
const spy = vi.fn().mockReturnValue(42)
vi.mock('./service')

// ❌ Jest API — Vitest ではエラー
const spy = jest.fn()
jest.mock('./service')
```

### 4. プール設定は `maxWorkers`（旧 `maxThreads` / `maxForks` は廃止）

```typescript
// ✅ v4
export default defineConfig({
  test: {
    maxWorkers: 4,
    isolate: false,
  },
})

// ❌ v4 では認識されない
export default defineConfig({
  test: {
    maxThreads: 4,  // 廃止
    singleThread: true, // 廃止 → maxWorkers: 1 + isolate: false
  },
})
```

### 5. 複数設定は `test.projects`（旧 `workspace` は廃止）

```typescript
// ✅ v4
export default defineConfig({
  test: {
    projects: [
      { test: { name: 'unit', environment: 'node', include: ['src/**/*.test.ts'] } },
      { test: { name: 'dom', environment: 'jsdom', include: ['src/**/*.dom.test.ts'] } },
    ],
  },
})

// ❌ v4 では認識されない
export default defineConfig({
  test: {
    workspace: ['packages/*'],  // 廃止
  },
})
```

### 6. テストオプションは第 2 引数

```typescript
// ✅ v4（options は第 2 引数）
test('slow operation', { timeout: 10000, retry: 2 }, async () => {
  // ...
})

// ❌ v4 では無効（旧: 第 3 引数 options）
test('slow operation', async () => {}, { timeout: 10000 })
```

詳細はすべて [./references/VITEST-V4-MIGRATION.md](./references/VITEST-V4-MIGRATION.md) を参照。

---

## クイック設定例

`vitest.config.ts` の最小構成（KB `apiSnippets` 準拠）:

```typescript
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    // 実行環境（jsdom / happy-dom / node）
    environment: 'jsdom',

    // カバレッジ設定
    coverage: {
      provider: 'v8',
      include: ['src/**/*.{ts,tsx}'],
      exclude: ['**/*.spec.ts', '**/*.test.ts'],
      reporter: ['text', 'html', 'json'],
      thresholds: {
        lines: 100,
        branches: 90,
      },
      ignoreClassMethods: ['toString'],
    },

    // モノレポ: 複数プロジェクト構成
    projects: [
      {
        test: {
          name: 'unit',
          environment: 'node',
          include: ['src/**/*.test.ts'],
        },
      },
    ],

    // モック自動復元（AI 生成テストの汚染防止に必須）
    restoreMocks: true,
  },
})
```

---

## AI 生成テストの Vitest 固有の注意

### Jest API 誤生成の検証

AI は学習データの影響で Jest API を出力しやすい。生成されたテストコードを必ずチェックする。

| AI が誤生成しやすいパターン | 正しい Vitest API |
|--------------------------|-----------------|
| `jest.fn()` | `vi.fn()` |
| `jest.mock('./module')` | `vi.mock('./module')` |
| `jest.spyOn(obj, 'method')` | `vi.spyOn(obj, 'method')` |
| `jest.clearAllMocks()` | `vi.clearAllMocks()` |
| `jest.useFakeTimers()` | `vi.useFakeTimers()` |
| `import { describe } from '@jest/globals'` | `import { describe } from 'vitest'` |

```typescript
// ❌ AI が出力しがちな誤った import
import { describe, it, expect } from '@jest/globals'

// ✅ Vitest の正しい import
import { describe, it, expect, vi } from 'vitest'
```

### 過剰モック・弱いアサーションの是正

```typescript
// ❌ AI が書きがちなパターン: toBeDefined は振る舞いを検証しない
expect(result).toBeDefined()
expect(result).not.toBeNull()

// ✅ 具体的な期待値で振る舞いを検証する
const actual = result
const expected = { id: 1, name: 'Alice' }
expect(actual).toEqual(expected)
```

### 設定: `restoreMocks: true`（必須）

AI 生成テストはモックの後始末が不完全なことが多い。`restoreMocks: true` を設定するとテスト間のモック汚染を自動防止できる。

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    restoreMocks: true,  // vi.spyOn で作成したスパイを自動復元
    clearMocks: true,    // 呼び出し履歴を自動クリア
  },
})
```

### AI エージェントは `vitest run` / `--no-watch` を使う

```bash
# ✅ AI エージェント・CI での実行（プロセスが確実に終了する）
vitest run
vitest run --no-watch

# ❌ ウォッチモードではプロセスが終了せず、エージェントがハングする
vitest           # TTY では watch モード
vitest watch
```

### v4 の `minimal`/`agent` リポーター

AI エージェント環境では `minimal`/`agent` リポーターが自動有効化され、トークン消費が削減される。カバレッジの `text` リポーターも `skipFull: true` が自動設定される。

### エッジケースを明示的に要求する

AI に生成を依頼するときは、以下を明示的にプロンプトに含める:

- 空配列・null・undefined 入力のケース
- 境界値（最大値・最小値・0）
- エラーパス（例外・rejects）
- 非同期タイムアウト

---

## 関連スキル

- **testing-code** — TDD・AAA パターン・モック戦略・カバレッジ目標など汎用テスト方法論
- **lang:developing-react** — React Testing Library（RTL）・コンポーネントテスト・`renderHook`
- **testing-e2e-with-playwright** — Playwright を使ったブラウザ E2E テスト
