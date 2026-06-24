# フィクスチャ・テストコンテキスト・アノテーション

テスト間で共有するリソース（DB接続・一時ファイル・設定値）を宣言的に管理する仕組み。
Node.js >= 20 / Vite >= 6 (Vitest v4.x) が前提。

---

## テストコンテキスト

各テスト関数の第1引数として渡されるオブジェクト。フィクスチャの受け取り口でもある。

| プロパティ | 型 | 説明 |
|---|---|---|
| `task` | `Task` | 現在のテストメタデータ（名前・状態） |
| `expect` | `ExpectStatic` | このテスト専用の `expect`（並列テストで安全） |
| `skip()` | `() => void` | テストを実行中にスキップ |
| `annotate()` | 後述 | テストケースにメタ情報を添付 |
| `signal` | `AbortSignal` | タイムアウト・キャンセル時に `aborted` となるシグナル |
| `onTestFailed()` | `(fn) => void` | テストが失敗した場合のみ実行するコールバックを登録 |
| `onTestFinished()` | `(fn) => void` | テストが完了した場合に実行するコールバックを登録（成否問わず） |

```typescript
test('タイムアウト検知', async ({ signal, skip, onTestFailed }) => {
  if (someCondition) skip()

  onTestFailed(() => console.error('失敗ログ送信'))

  const res = await fetchWithSignal(signal)
  expect(res.ok).toBe(true)
})
```

`signal` を fetch や外部 I/O に渡すと、テストがタイムアウトまたはキャンセルされた際にリクエストを自動中断できる。

---

## ビルダー形式フィクスチャ（v4.1 推奨）

### 基本構文

v4.1 から導入された `.extend()` チェーン形式。自動型推論が効くため、Playwright スタイルのオブジェクト構文より型安全。

```typescript
import { test as base } from 'vitest'

// フィクスチャを1つ追加
const test = base.extend('tmpFile', async ({}, { onCleanup }) => {
  const path = await makeTempFile()
  onCleanup(() => rmSync(path))
  return path
})

test('ファイル書き込み', ({ tmpFile }) => {
  writeFileSync(tmpFile, 'hello')
  expect(readFileSync(tmpFile, 'utf8')).toBe('hello')
})
```

### チェーンで複数フィクスチャを合成

```typescript
const test = base
  .extend('port', {}, () => 3000)
  .extend('baseUrl', ({ port }) => `http://localhost:${port}`)

test('URL確認', ({ baseUrl }) => {
  expect(baseUrl).toBe('http://localhost:3000')
})
```

後段フィクスチャは前段フィクスチャを引数に受け取れる。型は自動推論される。

### Playwright 互換のオブジェクト構文（引き続き利用可）

既存コードとの互換性維持やオプション指定が必要な場合に使用する。

```typescript
const test = base.extend<{ server: Server }>({
  server: async ({}, use) => {
    const s = startServer()
    await use(s)
    s.close()
  },
})
```

---

## フィクスチャスコープ

| スコープ | デフォルト | 初期化タイミング | アクセス制限 |
|---|---|---|---|
| `test` | ◎ | 各テスト実行前 | すべてのスコープにアクセス可 |
| `file` | — | ファイル内初回アクセス時 | `test` スコープへのアクセス不可 |
| `worker` | — | ワーカー起動時 | `test` / `file` スコープへのアクセス不可 |

```typescript
const test = base.extend({
  // file スコープ: ファイル内で1回だけ初期化
  dbConnection: [
    async ({}, use) => {
      const db = await connect()
      await use(db)
      await db.close()
    },
    { scope: 'file' },
  ],
})
```

**遅延初期化**: フィクスチャはコンテキストから**分割代入された場合のみ**初期化される。

```typescript
// db は初期化される
test('OK', ({ db }) => { /* ... */ })

// context だけ受け取っても db は初期化されない
test('スキップ', (context) => { /* db 未使用 */ })
```

---

## クリーンアップ

2 つの方法があり、どちらも同等。

### `onCleanup()` による登録

```typescript
const test = base.extend('resource', ({}, { onCleanup }) => {
  const r = acquire()
  onCleanup(() => r.release())
  return r
})
```

`onCleanup()` は1フィクスチャにつき1回のみ登録可能。

### `use()` コールバックによる前後処理

```typescript
const test = base.extend<{ app: App }>({
  app: async ({}, use) => {
    const a = await App.start()
    await use(a)          // ← テスト実行
    await a.stop()        // ← クリーンアップ
  },
})
```

`use()` の後に記述した処理がテスト終了後に実行される。

---

## `test.override()` — describe ブロック内での上書き（v4.1）

`describe` の中でフィクスチャの値を部分的に差し替えられる。チェーン可能。

```typescript
const test = base.extend('config', () => ({ port: 3000, debug: false }))

describe('デバッグ環境', () => {
  // このブロック内だけ debug: true で動作
  test.override('config', { port: 4000, debug: true })

  test('ポート確認', ({ config }) => {
    expect(config.port).toBe(4000)
  })
})
```

**制約事項**:

- `describe` ブロックの内側でのみ有効（トップレベル不可）
- フィクスチャの `scope` および `auto` オプションは変更不可
- `test.override()` で上書きできるのは値のみ

---

## アノテーション（context.annotate）

テストケースに診断情報・添付ファイルを紐付ける API。v4 で追加。

```typescript
test('外部 API 呼び出し', async ({ annotate }) => {
  const res = await fetch('https://example.com/api')
  await annotate(`ステータス: ${res.status}`, 'notice')

  // ファイル添付（本文付き）
  await annotate('レスポンスボディ', {
    body: JSON.stringify(await res.json(), null, 2),
    contentType: 'application/json',
  })

  expect(res.ok).toBe(true)
})
```

### `annotate` シグネチャ

```typescript
context.annotate(
  message: string,
  type?: 'notice' | 'warning' | 'error',
  attachment?: { body: string; contentType: string }
): Promise<void>
```

返り値は `Promise` だが、`await` を省略しても Vitest がテスト完了前に自動 await する。

### レポーター別の挙動

| レポーター | アノテーション表示 | 添付ファイル |
|---|---|---|
| `default` | 失敗したテストのみ表示 | 表示 |
| `verbose` | すべて表示 | 表示 |
| `html` | インライン表示 | 表示 |
| `junit` | `<properties>` タグ内に出力 | 無視 |
| `tap` | diagnostics として出力 | 無視 |
| `github-actions` | ワークフローメッセージ（notice/warning/error） | 無視 |

GitHub Actions では `type` に `notice` / `warning` / `error` 以外を指定すると `notice` 扱いになる。

---

## まとめ：フィクスチャ設計のポイント

- **スコープを最小に保つ**: 原則 `test` スコープ。I/O コストが高く全テストで共有可なら `file` / `worker` を検討
- **遅延初期化を活かす**: 使わないフィクスチャは分割代入しない
- **クリーンアップを必ず書く**: `onCleanup()` または `use()` の後続処理で必ずリソースを解放する
- **describe 内の差し替えは `test.override()`**: スコープ変更・auto オプション変更は不可であることを念頭に置く

---

## 関連ファイル

- [./VITEST-LIFECYCLE.md](./VITEST-LIFECYCLE.md) — フック順序（aroundEach / aroundAll / beforeEach / afterEach）とライフサイクル全体像
- [./VITEST-APIS.md](./VITEST-APIS.md) — expect / マッチャー / スパイ API リファレンス
