# Vitest ライフサイクルフック リファレンス（v4.x）

Vitest v4.x（Node.js >= 20・Vite >= 6 必須）のライフサイクルフック全体像を解説する。
v4.1 で導入された `aroundEach` / `aroundAll` を中心に、フック実行順序・7フェーズ run-lifecycle・
globalSetup の扱いを体系的にまとめる。

---

## フック実行順序（ファイル単位）

各テストファイル内での実行順序を示す。

```
ファイルコード（import/describe 登録）
  └─ aroundAll の外側コード（1回）
       └─ beforeAll（1回）
            └─ [テスト毎の繰り返し]
                 aroundEach の外側コード
                   └─ beforeEach
                        └─ test 本体
                   └─ afterEach
                   └─ onTestFinished / onTestFailed
                 aroundEach の後続コード
       └─ afterAll（1回）
  └─ aroundAll の後続コード（1回）
```

| フェーズ | フック | 呼び出し回数 |
|---------|--------|------------|
| ファイル読み込み | describe コールバック（同期） | 1回 |
| スイート前 | `aroundAll` 外側コード | 1回 |
| スイート前 | `beforeAll` | 1回 |
| テスト前 | `aroundEach` 外側コード | テスト毎 |
| テスト前 | `beforeEach` | テスト毎 |
| 実行 | `test` 本体 | テスト毎 |
| テスト後 | `afterEach` | テスト毎 |
| テスト後 | `onTestFinished` / `onTestFailed` | テスト毎 |
| テスト後 | `aroundEach` 後続コード | テスト毎 |
| スイート後 | `afterAll` | 1回 |
| スイート後 | `aroundAll` 後続コード | 1回 |

> **重要**: `aroundAll` / `aroundEach` は `runSuite()` / `runTest()` を呼び出さないとテストが実行されない。
> 呼び出し忘れによってテストが静かにスキップされるため注意が必要。

---

## 7フェーズ run-lifecycle

Vitest プロセス全体の起動から終了までの7フェーズ。

| フェーズ | 内容 |
|---------|------|
| 1. init | Vitest インスタンス初期化・設定解決・プロジェクト検出 |
| 2. globalSetup | メインプロセスで1回のみ実行。`setup()` → テスト群 → `teardown()` |
| 3. worker 生成 | テストファイルを担当するワーカープロセス/スレッドを起動 |
| 4. per-file setupFiles | 各テストファイル実行前に `setupFiles` で指定したファイルを読み込む |
| 5. collection / execution | describe 登録 → フック実行 → テスト実行 |
| 6. reporting | 結果レポート生成・カバレッジ集計 |
| 7. globalTeardown | globalSetup の `teardown()` 実行（フェーズ2の逆順） |

### setupFiles のコスト注意

`isolate: true`（デフォルト）の場合、`setupFiles` は各テストファイルごとに再実行される。
重い初期化処理（DB接続・サーバー起動など）は **globalSetup または beforeAll** に移すこと。

---

## globalSetup

### 特性

- メインプロセスで実行される（ワーカーとは別プロセス）
- テストコンテキスト（`expect` / `vi` 等）は使用不可
- watch モード変更時に**再実行されない**（`project.onTestsRerun` を使う）

### 値の受け渡し（provide / inject）

globalSetup からテストコードへ値を渡すには `project.provide` と `inject` を組み合わせる。

```typescript
// vitest.globalSetup.ts
import type { GlobalSetupContext } from 'vitest/node'

export async function setup({ provide }: GlobalSetupContext) {
  const baseUrl = await startTestServer()
  provide('baseUrl', baseUrl)
}

export async function teardown() {
  await stopTestServer()
}
```

```typescript
// テストファイル
import { inject } from 'vitest'

const baseUrl = inject('baseUrl')

test('API エンドポイントへリクエストできる', async () => {
  const res = await fetch(`${baseUrl}/health`)
  expect(res.status).toBe(200)
})
```

```typescript
// vite.config.ts
export default defineConfig({
  test: {
    globalSetup: './vitest.globalSetup.ts',
  },
})
```

### TypeScript 型補完

```typescript
// vitest.d.ts（型補完用）
declare module 'vitest' {
  export interface ProvidedContext {
    baseUrl: string
  }
}
```

### watch 時の再実行

watch モードでテストが再実行される際に処理を挟みたい場合は `project.onTestsRerun` を使う。

```typescript
export async function setup({ provide, onTestsRerun }: GlobalSetupContext) {
  provide('token', 'initial-value')

  onTestsRerun(async () => {
    // watch の変更検出時に呼ばれる（setup 自体は再実行されない）
  })
}
```

---

## aroundEach / aroundAll（v4.1）

### aroundEach

各テストを前後から包む。引数の `runTest()` を呼び出すと
`beforeEach`・テスト本体・`afterEach`・フィクスチャを含む1テスト分が実行される。

```typescript
import { aroundEach } from 'vitest'

aroundEach(async (runTest) => {
  const tx = db.beginTransaction()
  await runTest()            // ← 必須。呼ばないとテストが実行されない
  tx.rollback()
})
```

### aroundAll

スイート全体を1つのコンテキストで包む。`runSuite()` を呼び出すと全テストが実行される。

```typescript
import { aroundAll } from 'vitest'

aroundAll(async (runSuite) => {
  await runSuite()           // ← 必須。呼ばないと全テストがスキップされる
})
```

### beforeEach/afterEach との比較

| 観点 | beforeEach / afterEach | aroundEach / aroundAll |
|------|----------------------|----------------------|
| コールバック形式API（Sequelize 等） | 分割できないため統合不可 | `runTest()` をコールバックに渡せる |
| 変数スコープ | `let` を外側に宣言する必要あり | クロージャ内のローカル変数で完結 |
| 処理の連続性 | 2関数に分断される | 1関数内に前後を並べて記述可能 |
| スイート全体包括 | コンテキスト持ち越し不可 | 1コンテキストで包める |

---

## 主要ユースケース

### 1. トランザクション管理（コールバック形式API）

```typescript
import { aroundEach } from 'vitest'
import { sequelize } from './db'

aroundEach(async (runTest) => {
  await sequelize.transaction(async (tx) => {
    await runTest()
    // トランザクション終了 → 自動ロールバック
    throw new Error('rollback')
  }).catch(() => {})
})

it('INSERT してもロールバックされる', () => {
  expect(db.committed).toHaveLength(0)
})
```

### 2. トレーシングスパン

```typescript
import { aroundAll } from 'vitest'
import { tracer } from './tracing'

aroundAll(async (runSuite) => {
  await tracer.startActiveSpan('test-suite', async (span) => {
    await runSuite()
    span.end()
  })
})
```

### 3. AsyncLocalStorage

```typescript
import { aroundEach } from 'vitest'
import { AsyncLocalStorage } from 'async_hooks'

const requestContext = new AsyncLocalStorage<{ traceId: string }>()

aroundEach(async (runTest) => {
  await requestContext.run({ traceId: 'test-trace-001' }, async () => {
    await runTest()
  })
})
```

---

## スイートレベルフックとフィクスチャ（v4.1）

v4.1 以降、`beforeAll` / `afterAll` / `aroundAll` などのスイートレベルフックが
`file` スコープ・`worker` スコープのフィクスチャにアクセス可能になった。

```typescript
const test = baseTest.extend<{}, { db: Database }>({
  db: [async ({}, use) => {
    const connection = await Database.connect()
    await use(connection)
    await connection.close()
  }, { scope: 'worker' }],
})

test.beforeAll(async ({ db }) => {
  // worker スコープのフィクスチャを beforeAll 内で使用可（v4.1）
  await db.seed()
})
```

### test.suite()（v4.1）

`test.suite()` は `describe()` の別名として v4.1 で追加された。
`test.extend` で拡張したカスタムテストオブジェクトに `suite()` が生えるため、
フィクスチャ付きの describe グループを型安全に定義できる。

```typescript
test.suite('ユーザー管理', () => {
  test('作成できる', ({ db }) => { /* ... */ })
})
```

---

## 設計指針

- **重い初期化は globalSetup / beforeAll へ**: `setupFiles` は分離時に毎ファイル再実行されるためコスト大
- **aroundEach はコールバック形式 API のみ**: 通常の前後処理は `beforeEach/afterEach` を使う方が読みやすい
- **aroundAll の runSuite() 呼び出し忘れに注意**: テストが静かに全スキップになる
- **globalSetup の副作用は provide で明示**: 環境変数書き換えは隠れた依存関係を生むため避ける

---

## 関連ファイル

- [./VITEST-FIXTURES.md](./VITEST-FIXTURES.md) — test.extend フィクスチャ・スコープ・test.override
