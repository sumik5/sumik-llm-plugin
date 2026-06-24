# VITEST-APIS — マッチャー・型テスト・インソース・スナップショット

Vitest v4.x (v4.1.7) の記述 API リファレンス。Node.js >= 20 / Vite >= 6 が必要。

---

## マッチャー概観 (expect API)

### 等価・数値・型

| マッチャー | 用途 |
|-----------|------|
| `toBe(v)` | 参照等価 (`Object.is`) |
| `toEqual(v)` | 深い値比較（`undefined` プロパティ無視） |
| `toStrictEqual(v)` | 厳格な深い値比較（`undefined` プロパティ・クラスも区別） |
| `toBeCloseTo(n, numDigits?)` | 浮動小数点の近似比較 |
| `toBeGreaterThan(n)` / `toBeLessThan(n)` | 数値大小比較 |
| `toBeTypeOf(type)` | `typeof` 比較 |
| `toBeInstanceOf(Class)` | `instanceof` 比較 |

### コレクション・パターン

| マッチャー | 用途 |
|-----------|------|
| `toContain(item)` | 配列/文字列に含む |
| `toHaveLength(n)` | `.length` 確認 |
| `toMatch(re\|str)` | 文字列パターンマッチ |
| `toMatchObject(obj)` | オブジェクトの部分一致 |
| `toHaveProperty(path, val?)` | ネストパスの存在・値確認 |
| `toSatisfy(fn)` | カスタム述語関数 |
| `toBeOneOf(arr)` | 配列内いずれかと一致 |

### エラー

```typescript
// toThrow を使う — toThrowError は v4 で非推奨
expect(() => parse('')).toThrow(SyntaxError)
expect(() => divide(1, 0)).toThrow('Division by zero')
```

### 非同期 — v4 では await 必須

v4.0 以降、`.resolves` / `.rejects` を `await` しないとテストが **失敗**（v3 の警告から破壊的変更）。

```typescript
// OK
await expect(fetchUser(1)).resolves.toMatchObject({ id: 1 })
await expect(fetchUser(-1)).rejects.toThrow('Not found')

// NG — await 漏れで失敗
expect(fetchUser(1)).resolves.toMatchObject({ id: 1 }) // v4: FAIL
```

### モックアサーション

```typescript
expect(fn).toHaveBeenCalled()
expect(fn).toHaveBeenCalledWith('arg1', 42)
expect(fn).toHaveBeenNthCalledWith(2, 'second-call-arg')
expect(fn).toHaveReturnedWith('result')
```

**Chai スタイルのスパイアサーション（v4.1 新機能）**

`expect(spy).to.have.been.calledOnce` のようなプロパティ構文（括弧なし）が利用可能。

```typescript
expect(spy).to.have.been.called
expect(spy).to.have.been.calledOnce
expect(spy).to.have.been.callCount(3)
expect(spy).to.have.been.calledWith('foo', 42)
```

### 非対称マッチャー

```typescript
expect(user).toMatchObject({
  id: expect.any(Number),
  name: expect.stringContaining('Alice'),
  meta: expect.objectContaining({ role: 'admin' }),
  tags: expect.arrayContaining(['a', 'b']),
})

// Standard Schema v1 対応スキーマ検証
expect(payload).toMatchObject(expect.schemaMatching(mySchema))
```

### 制御系マッチャー

#### expect.soft — 非終了アサーション

すべてのソフトアサーション失敗を収集し、テスト終了後にまとめて報告する。非同期テストでは `await` が必要。

```typescript
test('複数フィールドを一括検証', () => {
  expect.soft(res.status).toBe(200)
  expect.soft(res.body.id).toBeDefined()
  expect.soft(res.body.name).toBe('Alice')
  // いずれかが失敗しても全行評価される
})
```

#### expect.poll — ポーリング

非同期に変化する値を定期的に再評価する。

```typescript
await expect.poll(() => store.value, { interval: 50, timeout: 1000 }).toBe(2)
```

#### expect.assertions / hasAssertions

非同期テストで期待するアサーション数を宣言する。0 件のまま通過するテストを防ぐ。

```typescript
test('コールバックが呼ばれることを保証', async () => {
  expect.assertions(2)
  await fetchWithCallback((err, data) => {
    expect(err).toBeNull()
    expect(data).toBeDefined()
  })
})
```

#### expect.extend — カスタムマッチャー

```typescript
expect.extend({
  toBeValidEmail(received: string) {
    const pass = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(received)
    return {
      pass,
      message: () => `expected ${received} ${pass ? 'not ' : ''}to be a valid email`,
    }
  },
})

expect('user@example.com').toBeValidEmail()
```

---

## v4 重要変更まとめ

| 変更点 | v3 以前 | v4 以降 |
|--------|---------|---------|
| `.resolves`/`.rejects` の await 漏れ | 警告のみ | **テスト失敗** |
| `toThrowError()` | 利用可（警告なし） | 非推奨 → `toThrow()` を使う |
| Chai スタイルスパイアサーション | なし | v4.1 で追加 |
| ARIA スナップショット | なし | v4.1.4 で実験的追加 |

---

## 型テスト (Type Testing)

`*.test-d.ts` ファイルで TypeScript の型を静的解析する。**ファイルは実行されない**ため `test.each` や動的な名前は使えない。

### 有効化

```bash
# CLI で有効化
vitest --typecheck

# または設定ファイル
```

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    typecheck: {
      enabled: true,
      include: ['**/*.test-d.ts'],
    },
  },
})
```

### 基本 API

```typescript
import { assertType, expectTypeOf } from 'vitest'

// 型の等価確認
expectTypeOf({ a: 1 }).toEqualTypeOf<{ a: number }>()

// 型引数を渡すと Expected/Actual が明確になる（推奨）
expectTypeOf<ReturnType<typeof fetchUser>>().toEqualTypeOf<Promise<User>>()

// パラメータの型確認
expectTypeOf(mount).parameter(0).toExtend<{ name: string }>()

// assertType: 型が一致しなければコンパイルエラー
assertType<string>('hello')
```

> **型引数を渡す理由**: 具体的なオブジェクトより型引数で比較するほうが、不一致時のエラーメッセージで期待型と実際型が明確に表示される。

### 注意点

- `*.test-d.ts` は `--typecheck` か `typecheck.enabled` なしでは実行されない
- `@ts-expect-error` の typo を検出するため、`test.include` に型テストファイルを含めることを推奨
- 手動の `tsc --noEmit` / `vue-tsc --noEmit` を置き換える用途に最適
- 公開 API の境界確認・ライブラリ開発での型保証に特に有効

---

## インソーステスト (In-Source Testing)

ソースファイル内に直接テストを記述する。`import.meta.vitest` ガードで本番ビルドから除去される。

### 基本パターン

```typescript
// src/math.ts
export function add(a: number, b: number): number {
  return a + b
}

// ガードブロック内に記述 — 本番ビルドでは除去される
if (import.meta.vitest) {
  const { it, expect } = import.meta.vitest
  it('adds two numbers', () => {
    expect(add(1, 2)).toBe(3)
  })
}
```

### 設定

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    includeSource: ['src/**/*.{js,ts}'],
  },
  define: {
    // 本番ビルドで import.meta.vitest を除去
    'import.meta.vitest': 'undefined',
  },
})
```

### TypeScript の型補完

`tsconfig.json` の `types` に `vitest/importMeta` を追加すると `import.meta.vitest` の型エラーが解消される。

```json
{
  "compilerOptions": {
    "types": ["vitest/importMeta"]
  }
}
```

### 使用指針

| 適する場面 | 避ける場面 |
|-----------|-----------|
| 小規模なユーティリティ関数の動作確認 | コンポーネント・E2E テスト |
| プロトタイピング段階の実験的テスト | 他ファイルとの連携テスト |
| プライベート関数をエクスポートせずにテスト | カバレッジ要件が厳格なビジネスロジック |

---

## スナップショット (Snapshot)

### 3種類のスナップショット API

```typescript
// 1. ファイル保存（初回に .snap ファイル生成）
expect(html).toMatchSnapshot()
expect(html).toMatchSnapshot('named-snapshot')

// 2. インライン（テストファイル内に埋め込み）
expect(tree).toMatchInlineSnapshot(`
  "<div>
    <p>hello</p>
  </div>"
`)

// 3. カスタムファイルパス（非同期）
await expect(output).toMatchFileSnapshot('./fixtures/expected.html')
```

### CI での運用

```bash
# CI 環境 (process.env.CI が truthy) ではスナップショット書き込みを拒否
# 更新するには明示的に -u / --update を指定
vitest run --update
vitest run -u
```

`.snap` ファイルはバージョン管理に含めること。

### Jest との非互換性

Vitest と Jest のスナップショットファイルは **互換性がない**。主な違い:

| 項目 | Vitest | Jest |
|------|--------|------|
| `printBasicPrototype` | `false`（デフォルト）| `true` |
| メッセージ区切り文字 | `>` | `:` |
| エラー形式 | `[Error: message]`（完全形式）| 異なる形式 |

既存の Jest スナップショットを Vitest に移行する場合は、`vitest run -u` で全スナップショットを再生成する。

### カスタムシリアライザー

```typescript
expect.addSnapshotSerializer({
  serialize(val) {
    return `Custom: ${val}`
  },
  test(val) {
    return typeof val === 'object' && val !== null && '__custom__' in val
  },
})
```

またはグローバル設定:

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    snapshotSerializers: ['./custom-serializer.ts'],
  },
})
```

### ARIA スナップショット（v4.1.4 実験的）

アクセシビリティツリーのスナップショット。Browser Mode で `expect.element(locator)` を介して使用する。

```typescript
// Browser Mode が必要
await expect.element(page.getByRole('navigation')).toMatchAriaSnapshot()
await expect.element(page.getByRole('main')).toMatchAriaInlineSnapshot(`
  - heading "Welcome" [level=1]
  - paragraph: "Hello, Alice"
`)
```

> ARIA スナップショットは v4.1.4 時点で実験的機能。アクセシビリティ回帰テストに活用できる。Browser Mode の設定については `./VITEST-BROWSER-MODE.md` を参照。

---

## 関連ファイル

- [./VITEST-FIXTURES.md](./VITEST-FIXTURES.md) — test.extend Builder パターン・フィクスチャスコープ・test.override
- [./VITEST-CONFIG.md](./VITEST-CONFIG.md) — カバレッジ設定・test.projects・環境設定・レポーター
