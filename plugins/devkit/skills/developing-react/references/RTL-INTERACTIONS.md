# React Testing Library ユーザーインタラクション

RTL でのユーザーインタラクションテストパターン。`userEvent` を中心に、各イベントの実装方法と `waitFor` による非同期テストをカバーする。

> **関連ファイル:** クエリメソッドの選び方は [RTL-QUERIES.md](./RTL-QUERIES.md)、高度テスト（within/props/rerender/snapshot/renderHook）は [RTL-ADVANCED.md](./RTL-ADVANCED.md) を参照。

---

## userEvent vs fireEvent

| 特性 | `userEvent` | `fireEvent` |
|------|-------------|-------------|
| **動作** | 実際のユーザー操作をシミュレート | DOM イベントを直接ディスパッチ |
| **忠実度** | 高（複数イベントを連鎖発火） | 低（単一イベントのみ） |
| **async** | Yes（`await` 必須） | No |
| **推奨度** | ✅ 常にこちらを使用 | ⚠️ 特殊なケースのみ |

### userEvent.setup() パターン（必須）

**`userEvent.setup()` でインスタンスを作成してから操作する。** これは [VITEST-RTL-GUIDELINES.md](./VITEST-RTL-GUIDELINES.md) および [REACT-TDD-PATTERNS.md](./REACT-TDD-PATTERNS.md) と共通の規約。

```tsx
import userEvent from '@testing-library/user-event'

it('ボタンクリック時、処理が実行されるべき', async () => {
  const user = userEvent.setup()
  render(<MyComponent />)

  await user.click(button)    // focus → pointerdown → mousedown → pointerup → mouseup → click
})
```

**必須ルール:**
- `userEvent.setup()` でインスタンス作成
- すべてのイベントに `await` 必須
- テスト関数は `async` 宣言

---

## Click テスト

最も基本的なインタラクション。ボタンクリック後の状態変化を検証する。

```tsx
it('カウンターボタンクリック時、カウントが増加すべき', async () => {
  const user = userEvent.setup()
  render(<App />)

  // Arrange: ボタンを取得
  const counter = screen.getByRole('button', { name: 'count is 0' })

  // Act: クリック
  await user.click(counter)

  // Assert: テキスト変化を検証
  expect(
    screen.getByRole('button', { name: 'count is 1' })
  ).toBeInTheDocument()
})
```

**ポイント:**
- クリック後の状態変化は `getByRole` + `name` で検証（テキスト変化の追跡）
- 正規表現も使用可能: `screen.getByRole('button', { name: /count/i })`

---

## Type（入力）テスト

テキスト入力フィールドへのタイピングをシミュレートする。

```tsx
it('ユーザー名入力時、入力値が反映されるべき', async () => {
  const user = userEvent.setup()
  render(<App />)

  // Arrange: 入力フィールドを取得（label テキストで検索）
  const usernameInput = screen.getByRole('textbox', { name: 'Username' })

  // Act: タイピング
  await user.type(usernameInput, 'Akos')

  // Assert: 入力値を検証
  expect(usernameInput).toHaveDisplayValue('Akos')
})
```

**`userEvent.type` の引数:**
1. 対象要素
2. 入力テキスト

**`toHaveDisplayValue`**: フォーム要素の表示値を検証する jest-dom マッチャー。`<input>`, `<select>`, `<textarea>` に使用可能。`checkbox` / `radio` には `toBeChecked()` を使用する。

**重要**: `getByRole('textbox', { name: '...' })` の `name` は `<input>` の `name` 属性ではなく、ラッピング `<label>` のテキストを参照する。

---

## Hover テスト

マウスホバーによる状態変化をテストする。

```tsx
it('ホバー時、テキストが変化すべき', async () => {
  const user = userEvent.setup()
  render(<App />)

  // Arrange: ホバー対象を取得
  const hoverDiv = screen.getByText('Hover over me!')

  // Act: ホバー
  await user.hover(hoverDiv)

  // Assert: テキスト変化
  expect(screen.getByText("I'm being hovered!")).toBeInTheDocument()

  // Act: ホバー解除
  await user.unhover(hoverDiv)

  // Assert: テキスト復帰
  expect(screen.getByText('Hover over me!')).toBeInTheDocument()
})
```

**ポイント:**
- `user.hover` でマウスエンター、`user.unhover` でマウスリーブをシミュレート
- ホバー前後の状態変化を両方テストする

---

## Blur テスト

フォーカス喪失（blur）イベントをテストする。バリデーションメッセージの表示等に使用する。

```tsx
it('blur 時にバリデーションが短い場合、エラーメッセージを表示すべき', async () => {
  const user = userEvent.setup()
  render(<App />)

  // Arrange
  const usernameInput = screen.getByRole('textbox', { name: 'Username' })

  // Act: 短いテキストを入力後、別の場所をクリック（blur 発火）
  await user.type(usernameInput, 'ab')
  await user.click(document.body)

  // Assert: バリデーションメッセージ表示
  expect(
    screen.getByText('Username must be at least 3 characters long')
  ).toBeInTheDocument()
})

it('blur 時にバリデーションが有効な場合、エラーメッセージを表示しないべき', async () => {
  const user = userEvent.setup()
  render(<App />)

  const usernameInput = screen.getByRole('textbox', { name: 'Username' })

  await user.type(usernameInput, 'valid')
  await user.click(document.body)

  // queryByText: 不在検証に使用（getByText はエラーをスローする）
  expect(
    screen.queryByText('Username must be at least 3 characters long')
  ).not.toBeInTheDocument()
})
```

**ポイント:**
- blur は `await user.click(document.body)` で発火（フォーカスを外す）
- 要素の**不在**を検証する場合は `queryByText` + `.not.toBeInTheDocument()` を使用
- `getByText` は要素が見つからないとエラーをスローするため、不在検証には不適

---

## waitFor パターン

非同期操作のテストに使用する。**基本的には `findBy` を優先**し、`waitFor` は複雑なケースに使う。

### findBy vs waitFor の使い分け

| ケース | 推奨 |
|--------|------|
| 要素の出現を待つ（単純） | `findBy` |
| 長時間のタイマー・アニメーション | `waitFor` + timeout |
| 要素の状態が複数回変化する | `waitFor` |
| API レスポンス後の表示 | `findBy`（シンプルな場合） |

### findBy の基本使用

```tsx
// findBy は内部で waitFor を使用。シンプルなケースではこちらを優先
const element = await screen.findByText('Welcome to the App!')
expect(element).toBeInTheDocument()
```

### waitFor の使用

```tsx
import { waitFor } from '@testing-library/react'

await waitFor(
  () => screen.getByText('Welcome to the App!'),
  {
    timeout: 2000,   // 最大待機時間（ms）
    interval: 500,   // チェック間隔（ms）
  }
)
```

### waitFor ベストプラクティス

**❌ 複数アサーションを waitFor 内にまとめない:**

```tsx
// ❌ 悪い例: 複数アサーションの混在
await waitFor(() => {
  expect(screen.getByText('Welcome!')).toBeInTheDocument()
  expect(screen.queryByText('loading...')).not.toBeInTheDocument()
})
```

**✅ ブロッキングアサーションのみ waitFor 内に、残りは外に:**

```tsx
// ✅ 良い例: 1つのブロッキングアサーション + 外部アサーション
await waitFor(() => screen.getByText('Welcome!'))

expect(screen.getByText('Welcome!')).toBeInTheDocument()
expect(screen.queryByText('loading...')).not.toBeInTheDocument()
```

### waitFor の適用場面

| 場面 | 例 |
|------|-----|
| アニメーション完了待ち | フェードイン完了後の要素検証 |
| API コール後のレンダリング | データ取得→表示の検証 |
| タイマー起動の変化 | `setTimeout` / `setInterval` 後の状態変化 |

---

## テスト構成のベストプラクティス

### 振る舞いごとにテストブロックを分離

```tsx
describe('App', () => {
  it('初期レンダリング時、タイトルを表示すべき', async () => {
    // 初期表示のテスト
  })

  it('カウンターボタンクリック時、カウントが増加すべき', async () => {
    // クリックインタラクションのテスト
  })

  it('ユーザー名入力時、入力値が反映されるべき', async () => {
    // 入力インタラクションのテスト
  })

  it('blur 時に短いユーザー名の場合、バリデーションエラーを表示すべき', async () => {
    // バリデーションのテスト
  })
})
```

**理由:**
- テストの読みやすさ向上
- 失敗時のデバッグが容易
- 機能カバレッジの可視化
