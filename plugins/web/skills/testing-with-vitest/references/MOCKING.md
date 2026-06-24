# Mocking — Vitest 4.x

Vitest のモック API (`vi`) を使って外部依存・タイマー・HTTP リクエストを制御し、テストを高速かつ決定論的に保つ方法をまとめる。

> テストダブルの概念分類（スタブ / スパイ / モック / フェイク）の汎用解説は
> testing-code スキルの `MOCK-PATTERNS.md` を参照。本ファイルは Vitest 4.x 固有の
> API と挙動に絞って記述する。

---

## v4 のモック挙動変更（重要）

v4 で以下の意味論が変わった。**既存コードを移行する前に必ず確認する。**

| 変更点 | v3 以前の挙動 | v4 以降の挙動 |
|--------|-------------|-------------|
| `vi.fn()` の性質 | デフォルトでスパイとして扱われた | **プレーンな MockFunction**（スパイではない） |
| `vi.restoreAllMocks()` の対象 | すべてのモックを復元 | **`vi.spyOn()` 由来のスパイのみ**復元（`vi.mock()` の自動モックは戻さない） |
| 自動モックの getter | 元の実装に準じた値を返す場合があった | **`undefined` を返す** |
| `mock.invocationCallOrder` | 0 始まりの実装もあった | **1 始まり**（Jest 互換） |

---

## vi.mock() — モジュール全体の差し替え

```typescript
// vi.mock はファイル先頭へ"巻き上げ"られ、import 文より先に実行される
vi.mock('./api/client.js', async (importOriginal) => {
  // 元の実装を取り込んで部分的に上書きする（部分モック）
  const original = await importOriginal<typeof import('./api/client.js')>()
  return {
    ...original,
    fetchUser: vi.fn().mockResolvedValue({ id: 1, name: 'Alice' }),
  }
})

// importOriginal は async — 必ず await すること
```

### 重要な制約

- **外部アクセスのみ置換される。** モジュール内部でのメソッド間呼び出し（`this.helper()` 等）はモックされない。内部依存を差し替えたい場合は DI（依存性注入）を使う。
- `vi.mock()` はファイル先頭に巻き上げられるため、モックファクトリ内でスコープ外の変数を参照すると実行時エラーになる（`vi.hoisted()` で宣言したものは参照可）。

---

## vi.spyOn() — 既存実装へのスパイ

```typescript
import * as fs from 'node:fs'
import { vi, beforeEach, afterEach } from 'vitest'

beforeEach(() => {
  vi.spyOn(fs, 'readFileSync').mockReturnValue('mocked content')
})

afterEach(() => {
  vi.restoreAllMocks() // vi.spyOn 由来のスパイのみ復元
})
```

### 制約

- `vi.spyOn()` は**名前空間 import**（`import * as obj`）が必要。デフォルト import や分割代入では機能しない。
- スパイ生成**後**の呼び出しのみ追跡される。生成前の呼び出し履歴は記録されない。

---

## ESM 封印と Browser Mode — `{ spy: true }`

ESM 仕様ではモジュールの名前空間は封印（sealed）されており、`vi.spyOn()` でプロパティを書き換えられない。Browser Mode ではこの制約が顕在化するため、代わりに次を使う。

```typescript
// Browser Mode で封印された ESM 名前空間をスパイする
vi.mock('./analytics.js', { spy: true })

// モジュールの実装はそのまま保ちつつ、呼び出し記録だけ取得できる
import { trackEvent } from './analytics.js'
// trackEvent は vi.fn() でラップされた状態になる
```

---

## 設定衛生 — テスト間のモック漏れ防止

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    restoreMocks: true,   // 各テスト後に vi.spyOn スパイを自動復元
    clearMocks: true,     // 各テスト後に呼び出し履歴をクリア
    // mockReset: true,   // さらに戻り値設定もリセットしたい場合
  },
})
```

`restoreMocks: true` は `vi.spyOn()` 由来のスパイのみ復元する（v4 の挙動）。`vi.mock()` で登録した自動モックはリセットされないため、ファクトリの中で `vi.fn()` を使って各テストから制御する。

---

## フェイクタイマー

```typescript
import { vi, beforeEach, afterEach, it, expect } from 'vitest'

beforeEach(() => {
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
})

it('debounce を検証する', () => {
  const callback = vi.fn()
  const debounced = debounce(callback, 300)

  debounced()
  expect(callback).not.toHaveBeenCalled()

  vi.advanceTimersByTime(300)
  expect(callback).toHaveBeenCalledOnce()
})
```

### vi.setTimerTickMode（v4.1 追加）

```typescript
// v4.1 以降: タイマーの自動進行モードを制御する
vi.useFakeTimers()
vi.setTimerTickMode('interval', 20)   // 20ms ごとにタイマーを自動進行
vi.setTimerTickMode('manual')         // 手動進行に戻す
vi.setTimerTickMode('nextTimerAsync') // 非同期タイマーを順番に実行
```

### process.nextTick の注意

`process.nextTick` のモックは pool `forks`（デフォルト）では**サポートされない**。使用するには設定で pool を `threads` に変更する。

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    pool: 'threads', // process.nextTick モックを有効にする
  },
})
```

---

## リクエストモック — MSW 推奨

HTTP / GraphQL / WebSocket のモックには [MSW (Mock Service Worker)](https://mswjs.io/) を推奨する。インターセプト層が実装詳細から独立しており、Node 環境とブラウザ環境の両方で動作する。

```typescript
import { setupServer } from 'msw/node'
import { http, HttpResponse } from 'msw'

const server = setupServer(
  http.get('/api/users/:id', ({ params }) => {
    return HttpResponse.json({ id: params.id, name: 'Alice' })
  }),
)

// 未ハンドルのリクエストをエラーにして意図しないネットワーク漏洩を検出する
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers()) // テスト間のハンドラー汚染を防ぐ
afterAll(() => server.close())
```

### エラーケースのテスト

```typescript
it('サーバーエラー時はエラーメッセージを表示する', async () => {
  // このテストだけハンドラーを上書き
  server.use(
    http.get('/api/users/:id', () => {
      return HttpResponse.json({ message: 'Internal error' }, { status: 500 })
    }),
  )

  const actual = await fetchUser('1')
  const expected = 'Internal error'
  expect(actual.error).toBe(expected)
})
```

---

## Chai スタイルのスパイアサーション（v4.1）

v4.1 からプロパティ構文でスパイを検証できる。

```typescript
const spy = vi.fn()
spy('hello')

// Chai スタイル（v4.1+）
expect(spy).to.have.been.called         // 呼ばれた（boolean プロパティ、括弧なし）
expect(spy).to.have.been.calledOnce     // 1 回だけ呼ばれた
expect(spy).to.have.been.callCount(2)   // 2 回呼ばれた
expect(spy).to.have.been.calledWith('hello')

// 従来の Vitest スタイル（引き続き使用可能）
expect(spy).toHaveBeenCalledWith('hello')
expect(spy).toHaveBeenCalledOnce()
```

---

## よくある失敗パターン

| 失敗 | 原因 | 対処 |
|------|------|------|
| `vi.spyOn` が動かない | デフォルト import を使っている | `import * as mod from '...'` に変更する |
| モック後も元の実装が呼ばれる | 内部メソッド間呼び出しをモックしようとしている | DI パターンでモック対象を外から注入する |
| Browser Mode で `vi.spyOn` がエラー | ESM 名前空間が封印されている | `vi.mock('./m', { spy: true })` を使う |
| `vi.restoreAllMocks()` 後もモックが残る | `vi.mock()` で登録した自動モックは復元されない | `vi.fn()` を個別にリセットするか `mockReset` を使う |
| `process.nextTick` モックが効かない | pool が `forks`（デフォルト）になっている | `pool: 'threads'` に変更する |
| テスト間でモック状態が汚染する | `restoreMocks` / `clearMocks` が未設定 | `vitest.config.ts` で両方を `true` に設定する |

---

## 関連ファイル

- [./VITEST-V4-MIGRATION.md](./VITEST-V4-MIGRATION.md) — v3 → v4 の全破壊的変更一覧
