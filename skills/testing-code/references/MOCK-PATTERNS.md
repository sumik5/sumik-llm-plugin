# モックパターン集リファレンス

テストダブルの用語整理、モジュールモック、Web APIモック（MSW）、タイマーモック、
UIコンポーネントでのモック活用、アンチパターンを体系的にまとめる。
コード例はTypeScript/Vitest中心。

## 目次

- [テストダブルの用語整理](#テストダブルの用語整理)
- [モジュールモック](#モジュールモック)
- [Web APIモック（MSW）](#web-apiモックmsw)
- [タイマー・日時モック](#タイマー日時モック)
- [UIコンポーネントテストでのモック活用](#uiコンポーネントテストでのモック活用)
- [モックのアンチパターン](#モックのアンチパターン)

---

## テストダブルの用語整理

テストにおける代用オブジェクトを総称して「テストダブル」と呼ぶ。

| 種別 | 目的 | 具体例 |
|------|------|--------|
| **ダミー（Dummy）** | 引数を埋めるだけ。実際には使われない | 必須パラメータに渡す空オブジェクト |
| **スタブ（Stub）** | 固定値を返す。テスト対象への「入力」 | APIレスポンスの代用品 |
| **スパイ（Spy）** | 呼び出しを記録。テスト対象からの「出力」確認 | コールバック関数の呼び出し回数・引数を検証 |
| **モック（Mock）** | 期待する呼び出しパターンを事前定義・検証 | 「この関数がこの引数で1回呼ばれること」 |
| **フェイク（Fake）** | 簡易版の実装を持つ | インメモリDBをMapで実装 |

### Vitest/Jestでの対応

`vi.fn()` がスタブにもスパイにもなる汎用API。

```typescript
const mockFn = vi.fn()
mockFn.mockReturnValue(42)       // スタブ: 固定値を返す
expect(mockFn()).toBe(42)
mockFn('hello')
expect(mockFn).toHaveBeenCalledWith('hello') // スパイ: 呼び出しを検証
```

### フェイクの例

```typescript
class FakeUserRepository implements UserRepository {
  private users = new Map<string, User>()
  async save(user: User): Promise<void> { this.users.set(user.id, user) }
  async findById(id: string): Promise<User | null> { return this.users.get(id) ?? null }
}
```

---

## モジュールモック

### vi.mock の基本

```typescript
vi.mock('./emailService', () => ({
  sendEmail: vi.fn().mockResolvedValue(undefined),
}))
```

### 自動モック vs 手動モック vs 部分モック

```typescript
// 自動モック: 全関数が vi.fn() になる
vi.mock('./userService')

// 手動モック: 戻り値を制御
vi.mock('./userService', () => ({
  getUser: vi.fn().mockResolvedValue({ id: '1', name: 'Test User' }),
}))

// 部分モック: 一部だけ置換、残りは本来の実装
vi.mock('./utils', async () => {
  const actual = await vi.importActual<typeof import('./utils')>('./utils')
  return { ...actual, generateId: vi.fn().mockReturnValue('fixed-id') }
})
```

### テストごとにモックの挙動を変える

```typescript
vi.mock('./api')
const mockFetchUser = vi.mocked(fetchUser)

describe('UserProfile', () => {
  beforeEach(() => { vi.clearAllMocks() })

  it('成功時', async () => {
    mockFetchUser.mockResolvedValue({ id: '1', name: 'Taro' })
    // ...
  })
  it('失敗時', async () => {
    mockFetchUser.mockRejectedValue(new Error('Network Error'))
    // ...
  })
})
```

---

## Web APIモック（MSW）

ネットワークレベルでHTTPリクエストをインターセプト。`vi.mock` と比べ、アプリケーションコード無変更・HTTPクライアント非依存で動作する。

### ハンドラー定義

```typescript
import { http, HttpResponse } from 'msw'

export const handlers = [
  http.get('/api/users', () => {
    return HttpResponse.json([{ id: '1', name: 'Taro' }])
  }),
  http.post('/api/users', async ({ request }) => {
    const body = await request.json()
    return HttpResponse.json({ id: '2', ...body }, { status: 201 })
  }),
]
```

### セットアップ

```typescript
// mocks/server.ts
import { setupServer } from 'msw/node'
export const server = setupServer(...handlers)

// vitest.setup.ts
beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

### テストごとのオーバーライド

```typescript
it('APIエラー時にエラーメッセージを表示', async () => {
  server.use(
    http.get('/api/users', () => {
      return HttpResponse.json({ message: 'Server Error' }, { status: 500 })
    })
  )
  // afterEach の resetHandlers() で元に戻るため他テストに影響しない
})
```

---

## タイマー・日時モック

### 現在時刻の固定

```typescript
describe('日時に依存する処理', () => {
  beforeEach(() => { vi.useFakeTimers() })
  afterEach(() => { vi.useRealTimers() })

  it('朝の挨拶を返す', () => {
    vi.setSystemTime(new Date('2024-01-15T09:00:00'))
    expect(getGreeting()).toBe('おはようございます')
  })
})
```

### setTimeout / setInterval の制御

```typescript
it('3秒後にコールバックが呼ばれる', () => {
  vi.useFakeTimers()
  const callback = vi.fn()
  scheduleTask(callback, 3000)
  expect(callback).not.toHaveBeenCalled()
  vi.advanceTimersByTime(3000)
  expect(callback).toHaveBeenCalledTimes(1)
  vi.useRealTimers()
})
```

### 非同期処理のモック

```typescript
// 成功/失敗/順序制御
const mock = vi.fn()
  .mockResolvedValueOnce({ data: 'first' })
  .mockRejectedValueOnce(new Error('fail'))

// 非同期テスト
it('失敗時', async () => {
  const mockApi = vi.fn().mockRejectedValue(new Error('Failed'))
  await expect(fetchData(mockApi)).rejects.toThrow('Failed')
})
```

---

## UIコンポーネントテストでのモック活用

### Context Providerのモック

```typescript
function renderWithTheme(ui: React.ReactElement, theme = 'light') {
  return render(
    <ThemeContext.Provider value={{ theme, toggleTheme: vi.fn() }}>
      {ui}
    </ThemeContext.Provider>
  )
}

it('ダークテーマ', () => {
  renderWithTheme(<ThemedButton>Click</ThemedButton>, 'dark')
  expect(screen.getByRole('button', { name: 'Click' })).toHaveClass('dark-theme')
})
```

### Routerのモック

```typescript
it('パスに応じたアクティブリンク', () => {
  render(
    <MemoryRouter initialEntries={['/about']}>
      <Navigation />
    </MemoryRouter>
  )
  expect(screen.getByRole('link', { name: 'About' })).toHaveClass('active')
})
```

### 外部ライブラリのモック

```typescript
vi.mock('next/navigation', () => ({
  useRouter: vi.fn().mockReturnValue({ push: vi.fn(), pathname: '/' }),
  usePathname: vi.fn().mockReturnValue('/'),
}))
```

### モック生成関数パターン

```typescript
function mockUserApi(opts: { getUser?: User | null; error?: Error }) {
  if (opts.error) {
    server.use(http.get('/api/users/:id', () =>
      HttpResponse.json({ message: opts.error!.message }, { status: 500 })))
    return
  }
  if (opts.getUser !== undefined) {
    server.use(http.get('/api/users/:id', () =>
      opts.getUser === null
        ? HttpResponse.json(null, { status: 404 })
        : HttpResponse.json(opts.getUser)))
  }
}
```

---

## モックのアンチパターン

### 1. 過度なモック（実装詳細への依存）

```typescript
// ❌ 内部の呼び出し順序まで検証 → リファクタリングで壊れる
expect(mockValidator.validate).toHaveBeenCalledBefore(mockDb.insert)

// ✅ 振る舞い（入出力）に注目する
const user = await service.createUser({ name: 'Taro' })
expect(user.name).toBe('Taro')
expect(await repo.findById(user.id)).toEqual(user)
```

### 2. テスト対象そのもののモック

```typescript
// ❌ テスト対象をモック → 何も検証していない
vi.mock('./calculateTotal')
mockCalculateTotal.mockReturnValue(1000)
expect(calculateTotal([500, 500])).toBe(1000) // モックの戻り値を検証しているだけ
```

**対策**: モックするのは「テスト対象の外部依存」のみ。

### 3. モックのリセット忘れ

```typescript
// ❌ テスト間でモック状態が漏れる
// ✅ 各テスト前にリセット
beforeEach(() => { vi.clearAllMocks() })
```

### 4. グローバルモックの汚染

```typescript
// ❌ テストファイルトップレベルのモックが全テストに影響
// ✅ 必要なテストだけでsetup/teardown管理
describe('API呼び出し', () => {
  beforeEach(() => { vi.stubEnv('API_URL', 'http://test.example.com') })
  afterEach(() => { vi.unstubAllEnvs() })
})
```

### モックを使うべきかの判断基準

| 状況 | モックすべき? | 理由 |
|------|-------------|------|
| 外部API呼び出し | はい | ネットワーク依存を排除 |
| DB接続 | ユニットテスト: はい / E2E: いいえ | テストレベルによる |
| 現在時刻・ランダム値 | はい | 再現性の確保 |
| 隣接モジュール | できれば避ける | 結合テストで実際の連携を検証 |
| テスト対象そのもの | いいえ | テストの意味がなくなる |
| 純粋関数 | いいえ | そのまま呼べばよい |

---

## 関連ファイル

- **[INSTRUCTIONS.md](../INSTRUCTIONS.md)** - スキル概要
- **[TDD.md](./TDD.md)** - TDDサイクル詳細
- **[TESTABLE-DESIGN.md](./TESTABLE-DESIGN.md)** - テスタブルな設計（DI、純粋関数）
- **[DEVELOPER-TESTING.md](./DEVELOPER-TESTING.md)** - 開発者テスト技法
- **[TEST-AUTOMATION-STRATEGY.md](./TEST-AUTOMATION-STRATEGY.md)** - テスト自動化戦略
