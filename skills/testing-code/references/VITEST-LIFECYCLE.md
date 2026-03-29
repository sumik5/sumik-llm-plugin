# Vitest ライフサイクルフック リファレンス

Vitest 4.1 で導入された `aroundEach` / `aroundAll` を中心に、
テストのライフサイクルフックを体系的にまとめる。
コンテキスト管理が必要なシナリオで `beforeEach/afterEach` の補完的な選択肢として活用する。

## 目次

- [aroundEach / aroundAll とは](#aroundeach--aroundall-とは)
- [aroundEach の仕様](#aroundeach-の仕様)
- [aroundAll の仕様](#aroundall-の仕様)
- [beforeEach/afterEach との比較](#beforeeachaftereach-との比較)
- [主要ユースケース](#主要ユースケース)
- [重要な特性](#重要な特性)

---

## aroundEach / aroundAll とは

Vitest 4.1 で導入されたライフサイクルフック。テストを**前後から包む（wrap）**構造を実現する。

- `aroundEach`: 各テストを個別に包む
- `aroundAll`: スイート全体を1つのコンテキストで包む

`runTest()` / `runSuite()` の呼び出しを自分のコードで囲むことで、
`beforeEach/afterEach` を2関数に分断せずに済む。

---

## aroundEach の仕様

各テストを個別に包むフック。引数として `runTest()` 関数を受け取り、
呼び出すと `beforeEach`・テスト本体・`afterEach`・フィクスチャを含む1テスト分の全処理が実行される。

**実行順序:**
```
aroundEach:before → beforeEach → テスト本体 → afterEach → aroundEach:after
```

**コード例（トランザクション管理）:**

```javascript
aroundEach(async (runTest) => {
  const tx = db.beginTransaction()
  await runTest()
  tx.rollback()
})

it('INSERT してもロールバックされる', () => {
  expect(db.committed).toHaveLength(0)
})
```

---

## aroundAll の仕様

スイート全体を1つのコンテキストで包むフック。`runSuite()` を呼び出すと全テストが実行される。

**実行順序:**
```
aroundAll:start（1回）
  → [各テストで aroundEach → beforeEach → test → afterEach]
aroundAll:end（1回）
```

**コード例（トレーシングスパン）:**

```javascript
aroundAll(async (runSuite) => {
  await tracer.trace('test-suite-name', runSuite)
})
```

---

## beforeEach/afterEach との比較

| 課題 | beforeEach/afterEach | aroundEach/aroundAll |
|------|---------------------|---------------------|
| コールバック形式API（Sequelize等） | 分割できないため組み合わせ不可 | `runTest()` をコールバックに渡せる |
| 変数スコープ | 外側に `let` で宣言が必要 | クロージャ内のローカル変数で完結 |
| 処理の連続性 | 2関数に分断される | 1関数内に並べて記述可能 |
| スイート全体を包む | コンテキスト持ち越し不可 | 1つのコンテキストに収められる |

---

## 主要ユースケース

### 1. トランザクション管理（コールバック形式API）

Sequelize など、`commit/rollback` がコールバック形式のAPIに自然に統合できる。

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
```

### 2. トレーシングスパン

スパンオブジェクトをスコープ外に持ち出さずに、クロージャ内で管理できる。

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

`AsyncLocalStorage.run()` のようなコールバック形式APIを自然に統合できる。

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

## 重要な特性

- **補完的な選択肢**: `beforeEach/afterEach` の**置き換えではなく補完**。コンテキスト管理が必要な処理向け
- **グローバルスコープ汚染を防止**: 変数がクロージャ内に収まる
- **コード可読性の向上**: 関連処理が1箇所に集約される
- **適用判断基準**: コールバック形式のAPIを使う場合、または変数スコープを最小化したい場合に選択する
