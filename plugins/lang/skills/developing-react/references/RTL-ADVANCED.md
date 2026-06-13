# React Testing Library 高度テストパターン

セットアップ、複雑な DOM 構造、props テスト、rerender、スナップショット、カスタムフックのテストパターンをカバーする。

> **関連ファイル:** クエリメソッドの選び方は [RTL-QUERIES.md](./RTL-QUERIES.md)、ユーザーインタラクションは [RTL-INTERACTIONS.md](./RTL-INTERACTIONS.md)、コード規約は [VITEST-RTL-GUIDELINES.md](./VITEST-RTL-GUIDELINES.md)、TDDパターンは [REACT-TDD-PATTERNS.md](./REACT-TDD-PATTERNS.md) を参照。

---

## Vitest + RTL セットアップ

### 依存関係のインストール

```bash
# Vitest（テストランナー）
npm install -D vitest

# React Testing Library + jsdom
npm install -D @testing-library/jest-dom @testing-library/react @testing-library/user-event jsdom
```

### Vite 設定（vite.config.ts）

```typescript
/// <reference types="vitest" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,           // describe/it をグローバルに使用可能
    environment: 'jsdom',    // ブラウザ風 DOM 環境
    setupFiles: './src/test/setup.ts',  // テスト前のセットアップ
    css: true,               // CSS をテスト中に処理
  },
})
```

| 設定キー | 役割 |
|---------|------|
| `globals: true` | `describe`, `it`, `expect` を import 不要にする |
| `environment: 'jsdom'` | DOM シミュレーション環境を提供 |
| `setupFiles` | テスト実行前に読み込むファイル（jest-dom の import 等） |
| `css: true` | テスト中に CSS を適用 |

### セットアップファイル（src/test/setup.ts）

```typescript
import '@testing-library/jest-dom'
```

### TypeScript 型設定（tsconfig.app.json）

```json
{
  "compilerOptions": {
    "types": ["vitest/globals"]
  },
  "include": ["src"]
}
```

`vitest/globals` を追加することで、`describe`・`it`・`expect` が TypeScript で型エラーなく使用可能になる。

---

## 複雑な DOM 構造のテスト

### within ヘルパー

`within` は特定の要素内にスコープを限定してクエリを実行する。テーブル等のネスト構造に必須。

```tsx
import { render, screen, within } from '@testing-library/react'

it('テーブルの最初の行が正しい内容を持つべき', () => {
  render(<Table />)

  // テーブル要素を取得
  const table = screen.getByRole('table')

  // tbody を取得（rowgroup: thead が最初、tbody が2番目）
  const [, tbody] = within(table).getAllByRole('rowgroup')

  // tbody 内の行を取得
  const rows = within(tbody).getAllByRole('row')
  const [firstRow] = rows

  // 行内のセルを検証
  const [name, role, action] = within(firstRow).getAllByRole('cell')
  expect(name).toHaveTextContent('John Doe')
  expect(role).toHaveTextContent('admin')
  expect(action).toHaveTextContent('Edit')
})
```

**within の利点:**
- スコープ限定による誤マッチ防止
- ネスト構造の可読性向上
- 複雑なセレクタの回避

### 見出しレベルの指定

同じテキストが複数箇所に出現する場合、`level` オプションで見出しレベルを絞り込む:

```tsx
it('Dashboard ページに h3 見出しを表示すべき', () => {
  render(<Dashboard />)

  expect(
    screen.getByRole('heading', { level: 3, name: 'Dashboard' })
  ).toBeInTheDocument()
})
```

### リンクの href 検証

```tsx
it('Sign up リンクが正しい href を持つべき', () => {
  render(
    <Router>
      <MyComponent />
    </Router>
  )

  const linkElement = screen.getByRole('link', { name: 'Sign up' })
  expect(linkElement).toHaveAttribute('href', '/signup')
})
```

---

## Props テスト

### コンポーネントのモック（vi.mock）

子コンポーネントの実行を防ぎ、渡された props を検証する:

```tsx
// 子コンポーネントをモックに差し替え
vi.mock('./PermissionsContainer', () => ({
  default: (props: { profileId: string }) =>
    `PermissionsContainer profileId:${props.profileId}`
}))

it('PermissionsContainer に正しい profileId を渡すべき', () => {
  render(
    <Profile
      firstName="John"
      lastName="Doe"
      age={35}
      profileId="1234-fake-5678-uuid"
    />
  )

  expect(
    screen.getByText('PermissionsContainer profileId:1234-fake-5678-uuid')
  ).toBeInTheDocument()
})
```

### 複雑な Props の検証（vi.fn + importOriginal）

オブジェクト型の props を検証しつつ、元のコンポーネントも実行する場合:

```tsx
const permissionContainerPropsMock = vi.fn()

vi.mock('./PermissionsContainer', async (importOriginal) => {
  const PermissionsContainer = await importOriginal<
    typeof import('./PermissionsContainer.tsx')
  >()

  return {
    default: (props: { user: Immutable.Map<string, string | number> }) => {
      permissionContainerPropsMock(props)
      return <PermissionsContainer.default user={props.user} />
    }
  }
})

describe('Profile', () => {
  const user = Immutable.Map({
    firstName: 'John',
    lastName: 'Doe',
    age: 35,
    profileId: '1234-fake-5678-uuid',
    username: 'johnd'
  })

  it('PermissionsContainer に正しい user オブジェクトを渡すべき', () => {
    render(<Profile user={user} />)

    expect(permissionContainerPropsMock).toHaveBeenCalledWith({ user })
  })
})
```

**パターンの使い分け:**

| 条件 | 手法 |
|------|------|
| 単純な props（string, number） | モック内で props を文字列表示 → getByText で検証 |
| 複雑な props（オブジェクト） | `vi.fn()` で props をキャプチャ → `toHaveBeenCalledWith` で検証 |
| 元のコンポーネントも実行したい | `importOriginal` で元コンポーネントを取得 |

---

## rerender パターン

コンポーネントの props 変更後の振る舞いをテストする。**同一コンポーネントインスタンス**を保持したままpropsを更新できる。

### render 2回 vs rerender

```tsx
// ❌ render を2回呼ぶと、DOMに2つのコンポーネントが生成される
render(<MessageBoard error="Error A" />)
render(<MessageBoard error="Error B" />)
// → "Found multiple elements" エラー

// ✅ rerender で同一インスタンスのpropsを更新
const { rerender } = render(<MessageBoard error="Error A" />)
rerender(<MessageBoard error="Error B" />)
// → 1つのコンポーネントのpropsが更新される
```

### 完全なテスト例

```tsx
describe('MessageBoard', () => {
  it('props 変更時、エラーメッセージが更新されるべき', async () => {
    const submitMessageMock = vi.fn()

    // 初期レンダリング
    const { rerender } = render(
      <MessageBoard submitMessage={submitMessageMock} error="Add a score" />
    )

    // 入力操作
    await userEvent.type(screen.getByLabelText('Message:'), 'Hello from test!')
    expect(screen.getByText('Add a score')).toBeInTheDocument()

    // props を更新して再レンダリング
    rerender(
      <MessageBoard submitMessage={submitMessageMock} error="Invalid score" />
    )

    // 追加入力（前の入力は保持されている）
    await userEvent.type(screen.getByLabelText('Message:'), 'Hello again!')
    expect(screen.getByText('Invalid score')).toBeInTheDocument()
  })
})
```

**rerender の用途:**
- props 変更に対するコンポーネントの応答テスト
- 内部状態（入力値等）を保持しつつ外部 props のみ変更
- コンポーネントのライフサイクル検証

**注意**: rerender は**エスケープハッチ**として使用する。可能であれば、props を更新する親コンポーネントをテストするほうが望ましい。

---

## スナップショットテスト

### 基本的なスナップショット

```tsx
import { render } from '@testing-library/react'

describe('Alert', () => {
  it('スナップショットと一致すべき', () => {
    const { container } = render(<Alert />)
    expect(container).toMatchSnapshot()
  })
})
```

テスト実行時に `__snapshots__` ディレクトリに `.snap` ファイルが生成される。

### スナップショットの更新

コンポーネント変更後にスナップショットが不一致になった場合:

```bash
# スナップショットを更新
npx vitest run -u

# watch モードなら `u` キーを押す
```

### インラインスナップショット

別ファイルではなく、テストファイル内にスナップショットを埋め込む:

```tsx
expect(container).toMatchInlineSnapshot()
// 実行後、自動的にスナップショット内容が引数に挿入される
```

### カスタムスナップショットパス

```typescript
// vite.config.ts
export default defineConfig({
  test: {
    // ... 他の設定
    resolveSnapshotPath: (testPath: string, snapshotExtension: string) => {
      const basePath = 'custom_snapshots'
      return `src/${basePath}/${testPath
        .split('/')
        .pop()
        ?.replace(/\.test\.[jt]sx?$/, snapshotExtension)}`
    },
  },
})
```

### スナップショットの使用判断

| 適切なケース | 不適切なケース |
|-------------|-------------|
| UI の一貫性保証 | 大規模 DOM ツリー（複数チームが変更） |
| 安定した出力のコンポーネント | 動的データ・ランダム値を含む |
| セマンティック HTML の検証 | 頻繁に変更されるコンポーネント |

---

## カスタムフックテスト（renderHook）

コンポーネントから独立してフックをテストする。

### renderHook の基本

```tsx
import { renderHook, waitFor } from '@testing-library/react'

describe('usePermissionsHook', () => {
  it('ローディング後にパーミッション一覧を返すべき', async () => {
    // Arrange: フックをレンダリング
    const { result } = renderHook(() =>
      usePermissionsHook('1234-fake-4567-uuid')
    )

    // Assert: 初期状態
    expect(result.current.isLoading).toEqual(true)
    expect(result.current.permissions).toEqual([])

    // Act: 非同期処理の完了を待機
    await waitFor(() =>
      expect(result.current.isLoading).toEqual(false)
    )

    // Assert: 最終状態
    expect(result.current.isLoading).toEqual(false)
    expect(result.current.permissions).toEqual(['read', 'write', 'create'])
  })
})
```

### renderHook のシグネチャ

| パターン | 構文 |
|---------|------|
| 引数なし | `renderHook(useMyHook)` |
| 引数あり | `renderHook(() => useMyHook('arg1'))` |

### result オブジェクト

`result.current` でフックの現在の戻り値にアクセスする。フック内の状態が変化すると `result.current` も更新される。

### renderHook の使用判断

| 使うべき場合 | 避けるべき場合 |
|-------------|-------------|
| フックのロジックを個別検証したい | コンポーネント内でテスト可能 |
| フックが複雑な状態管理を持つ | 単純な useState ラッパー |
| フックを複数コンポーネントで再利用 | 1つのコンポーネント専用フック |

---

## screen.debug() によるデバッグ

テスト中の DOM 状態をコンソールに出力する:

```tsx
it('デバッグ用: DOM 状態を確認', () => {
  render(<MyComponent />)

  screen.debug()        // DOM 全体を出力
  screen.debug(element) // 特定要素のみ出力
})
```

**使用場面:**
- テスト失敗時の原因調査
- モック後の DOM 状態確認
- クエリが正しい要素をマッチしているか検証
