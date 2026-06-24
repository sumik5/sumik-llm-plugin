# Vitest v3 → v4 移行ガイド

v4 は pool アーキテクチャの再設計・module runner 導入・設定 API の整理を含むメジャーリリースである。
このファイルは v3 からの破壊的変更をすべて網羅した単一情報源として機能する。

---

## ランタイム要件の引き上げ

| 項目 | v3 | v4 |
|------|----|----|
| Node.js | >= 18 | **>= 20.0.0** |
| Vite | >= 5 | **>= 6.0.0** |

プロジェクトの `package.json` の `engines` フィールドと CI の Node バージョンを確認してからアップグレードする。

---

## プール構成の刷新

v4 では Tinypool への依存が廃止され、プール設定 API が整理された。

### オプション名の統合

| v3 | v4 |
|----|----|
| `maxThreads` / `maxForks` | `maxWorkers`（単一オプションに統合） |
| `minWorkers` | **廃止**（削除） |
| `singleThread: true` | `maxWorkers: 1` + `isolate: false` |
| `singleFork: true` | `maxWorkers: 1` + `isolate: false` |

```typescript
// v3（廃止）
export default defineConfig({
  test: {
    maxThreads: 4,
    minWorkers: 1,
    singleFork: true,
  },
})

// v4
export default defineConfig({
  test: {
    maxWorkers: 4,
    // singleFork 相当
    // maxWorkers: 1,
    // isolate: false,
  },
})
```

### デフォルトプールの変更

v4 のデフォルトプールは `'forks'`（child_process）に変更された。
`poolMatchGlobs` オプションは廃止されたため削除する。

```typescript
// v3（廃止）
test: { poolMatchGlobs: [['**/*.test.ts', 'threads']] }

// v4（明示指定が必要な場合）
test: { pool: 'threads' }
```

---

## 設定リネーム一覧

| v3 オプション | v4 オプション | 備考 |
|--------------|--------------|------|
| `workspace` | `test.projects` | 外部ファイル参照不可（後述） |
| `deps.optimizer.web` | `deps.optimizer.client` | |
| `browser.testerScripts` | `browser.testerHtmlPath` | |
| `environmentMatchGlobs` | **廃止** | `test.projects` で代替 |

### `workspace` → `test.projects`

`workspace` は削除された。`test.projects` に移行する。
**v4 では `test.projects` からの外部ファイル参照はできない（インライン定義のみ）。**

```typescript
// v3（廃止）
// vitest.workspace.ts
export default ['packages/*']

// v4
export default defineConfig({
  test: {
    projects: [
      { test: { name: 'unit', environment: 'node', include: ['src/**/*.test.ts'] } },
      { test: { name: 'browser', browser: { enabled: true } } },
    ],
  },
})
```

---

## 廃止されたオプション一覧

以下のオプションは v4 で**完全に削除**された。設定ファイルから取り除く。

| 廃止オプション | 移行方針 |
|--------------|---------|
| `poolMatchGlobs` | `pool` を明示指定、または `test.projects` で分割 |
| `environmentMatchGlobs` | `test.projects` + 各プロジェクトに `environment` 設定 |
| `deps.external` | 不要（削除） |
| `deps.inline` | `server.deps.inline` に移行済みであれば継続可 |
| `deps.fallbackCJS` | 不要（削除） |
| `minWorkers` | 削除（`maxWorkers` のみ） |
| `coverage.all` | 不要（削除） |
| `coverage.ignoreEmptyLines` | 不要（削除） |
| `coverage.experimentalAstAwareRemapping` | AST マッピングが V8 で標準化されたため削除 |
| `coverage.extensions` | 不要（削除） |

---

## 環境変数のリネーム

| v3 環境変数 | v4 環境変数 |
|------------|------------|
| `VITEST_MAX_THREADS` | `VITEST_MAX_WORKERS` |
| `VITEST_MAX_FORKS` | `VITEST_MAX_WORKERS` |
| `VITE_NODE_DEPS_MODULE_DIRECTORIES` | `VITEST_MODULE_DIRECTORIES` |

```bash
# v3（廃止）
VITEST_MAX_THREADS=4 vitest run

# v4
VITEST_MAX_WORKERS=4 vitest run
```

---

## Module Runner が vite-node を置換

v4 では `vite-node` が Module Runner に置き換えられた。

### エントリポイントの削除

`vitest/execute` エントリは削除された。直接インポートしている場合は除去する。

### カスタム環境の変更

カスタム環境で使用していた `transformMode` は廃止された。代わりに `viteEnvironment` を設定する。

```typescript
// v3（廃止）
export default {
  name: 'my-env',
  transformMode: 'web',
  // ...
}

// v4
export default {
  name: 'my-env',
  viteEnvironment: { name: 'client' }, // 'ssr' | 'client' | カスタム
  // ...
}
```

### deps.optimizer のリネーム

```typescript
// v3
test: { deps: { optimizer: { web: { include: ['pkg'] } } } }

// v4
test: { deps: { optimizer: { client: { include: ['pkg'] } } } }
```

---

## デフォルト `exclude` の簡素化

v3 では `dist`・`cypress`・設定ファイルパターンがデフォルトで除外されていた。
v4 のデフォルト除外は **`node_modules` と `.git` のみ** に変更された。

以下のパターンは必要に応じて手動で `test.exclude` に追加する。

```typescript
export default defineConfig({
  test: {
    exclude: [
      '**/node_modules/**',
      '**/.git/**',
      // v4 で手動追加が必要になったパターン
      '**/dist/**',
      '**/cypress/**',
      '**/*.config.ts',
      '**/*.config.js',
    ],
  },
})
```

---

## 非同期アサーションの強制

v3 では `.resolves` / `.rejects` を `await` しなくても警告のみだった。
v4 では **`await` なしの場合はテストが失敗**する。

```typescript
// v3（サイレントパス・危険）
expect(promise).resolves.toBe('value') // await なし → v3 は通過してしまう

// v4（正しい書き方）
await expect(promise).resolves.toBe('value')
await expect(asyncFn()).rejects.toThrow('error')
```

### `toThrowError` の非推奨化

`toThrowError()` は非推奨となった。`toThrow()` を使用する。

```typescript
// 非推奨
expect(() => fn()).toThrowError('message')

// 推奨
expect(() => fn()).toThrow('message')
```

---

## テストオプションの引数位置変更

`test()` の追加オプション（`timeout`・`retry`・`tags` など）は
**第3引数から第2引数**に移動した。

```typescript
// v3（第3引数）
test('name', async () => { /* ... */ }, { timeout: 5000, retry: 2 })

// v4（第2引数）
test('name', { timeout: 5000, retry: 2 }, async () => { /* ... */ })
```

---

## Reporter の破壊的変更

### コールバックの削除

以下のレポーターコールバックは v4 で**削除**された。

| 削除されたコールバック |
|-----------------------|
| `onCollected` |
| `onSpecsCollected` |
| `onPathsCollected` |
| `onTaskUpdate` |
| `onFinished` |

カスタムレポーターでこれらを実装している場合は、代替の Reporter API に移行する。

### `basic` レポーターの削除

`basic` レポーターは廃止・削除された。代わりに `minimal` または `default` を使用する。

```typescript
// v3（廃止）
test: { reporters: ['basic'] }

// v4
test: { reporters: ['minimal'] }
// または AI エージェント環境では自動で 'agent' レポーターが有効化される
```

---

## その他の変更

### カスタム要素のシャドウルート表示

カスタム要素のシャドウルートがデフォルトで出力されるようになった。
抑制する場合は `printShadowRoot: false` を設定する。

```typescript
test: { printShadowRoot: false }
```

---

## 移行チェックリスト

v3 → v4 アップグレード時に確認すべき項目:

- [ ] Node.js >= 20 / Vite >= 6 にアップグレード済み
- [ ] `maxThreads` / `maxForks` → `maxWorkers` に変更
- [ ] `minWorkers` / `singleThread` / `singleFork` を削除または代替に変更
- [ ] `workspace` → `test.projects`（インライン定義）に移行
- [ ] `deps.optimizer.web` → `deps.optimizer.client` に変更
- [ ] `browser.testerScripts` → `browser.testerHtmlPath` に変更
- [ ] `poolMatchGlobs` / `environmentMatchGlobs` を削除
- [ ] `deps.external` / `deps.inline` / `deps.fallbackCJS` を削除
- [ ] `coverage.all` / `coverage.ignoreEmptyLines` / `coverage.experimentalAstAwareRemapping` / `coverage.extensions` を削除
- [ ] 環境変数 `VITEST_MAX_THREADS` / `VITEST_MAX_FORKS` → `VITEST_MAX_WORKERS` に変更
- [ ] `VITE_NODE_DEPS_MODULE_DIRECTORIES` → `VITEST_MODULE_DIRECTORIES` に変更
- [ ] カスタム環境の `transformMode` → `viteEnvironment` に変更
- [ ] `vitest/execute` の直接インポートを削除
- [ ] `.resolves` / `.rejects` がすべて `await` されているか確認
- [ ] `toThrowError()` → `toThrow()` に変更
- [ ] `test()` の追加オプションを第3引数から第2引数に移動
- [ ] `basic` レポーターを `minimal` または `default` に変更
- [ ] カスタムレポーターの削除されたコールバックを除去
- [ ] `test.exclude` に `dist` / `cypress` / 設定ファイルパターンを追加

---

## 関連ファイル

- [./VITEST-CONFIG.md](./VITEST-CONFIG.md) — 設定リファレンス全般（coverage・environments・reporters）
- [./VITEST-PROJECTS-PERFORMANCE.md](./VITEST-PROJECTS-PERFORMANCE.md) — test.projects・プール・並列性能チューニング
