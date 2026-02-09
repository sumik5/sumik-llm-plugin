# Vitest / React Testing Library コード規約

このファイルでは、Vitest および React Testing Library を使用したテストコードの具体的な規約を定義します。

## 📋 目次

- [import 規約](#import-規約)
- [describe / it の命名規約](#describe--it-の命名規約)
- [AAA パターンと変数命名](#aaa-パターンと変数命名)
- [構造規約（ネスト禁止）](#構造規約ネスト禁止)
- [1テスト1アサーション](#1テスト1アサーション)
- [スナップショットの使用制限](#スナップショットの使用制限)
- [React Testing Library 固有の規約](#react-testing-library-固有の規約)

---

## 📦 import 規約

### 必須: vitest からの明示的インポート

**グローバル定義に頼らず、必ず明示的にインポートする。**

```typescript
// ❌ 悪い例: グローバル定義に依存
describe('calculateTotal', () => {
  it('should calculate correctly', () => {
    expect(calculateTotal([100, 200])).toBe(300)
  })
})

// ✅ 良い例: 明示的インポート
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'

describe('calculateTotal', () => {
  it('should calculate correctly', () => {
    expect(calculateTotal([100, 200])).toBe(300)
  })
})
```

### React Testing Library のインポート

```typescript
// ✅ 推奨: 必要な関数のみインポート
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

// ✅ カスタムレンダラーがある場合
import { render, screen } from '@/test/utils'
```

---

## 📝 describe / it の命名規約

### 日本語での「〜の時、〜すべき」形式

**条件と期待結果を明確に記述する。**

```typescript
// ❌ 悪い例: 曖昧な命名
describe('calculateTotal', () => {
  it('test 1', () => { ... })
  it('正常系', () => { ... })
  it('should work', () => { ... })
})

// ✅ 良い例: 条件と結果を明示
describe('calculateTotal', () => {
  it('商品が複数ある時、合計金額を返すべき', () => { ... })
  it('割引率が指定された時、割引後の金額を返すべき', () => { ... })
  it('商品が空の時、0を返すべき', () => { ... })
})
```

### 英語の場合の形式

```typescript
// ✅ 英語の場合: "when [condition], should [result]"
describe('calculateTotal', () => {
  it('when items exist, should return sum of all prices', () => { ... })
  it('when discount is applied, should return discounted amount', () => { ... })
  it('when items are empty, should return 0', () => { ... })
})
```

### describe の命名

```typescript
// ✅ 良い例: テスト対象を明確に
describe('calculateTotal', () => { ... })
describe('UserService.createUser', () => { ... })
describe('Button コンポーネント', () => { ... })
describe('POST /api/users', () => { ... })
```

---

## 🔄 AAA パターンと変数命名

### actual / expected 変数での明示的な比較

```typescript
// ❌ 悪い例: 直接比較で意図が不明確
it('商品合計を計算する時、正しい金額を返すべき', () => {
  expect(calculateTotal([100, 200], 0.1)).toBe(270)
})

// ✅ 良い例: actual / expected で意図を明示
it('商品合計を計算する時、正しい金額を返すべき', () => {
  // Arrange
  const items = [100, 200]
  const discountRate = 0.1

  // Act
  const actual = calculateTotal(items, discountRate)

  // Assert
  const expected = 270 // (100 + 200) * 0.9
  expect(actual).toBe(expected)
})
```

### オブジェクトの比較

```typescript
// ✅ 良い例: オブジェクト比較で複数プロパティを検証
it('ユーザーを作成する時、IDとタイムスタンプが設定されるべき', () => {
  // Arrange
  const input = { name: 'John', email: 'john@example.com' }

  // Act
  const actual = createUser(input)

  // Assert
  const expected = {
    id: expect.any(String),
    name: 'John',
    email: 'john@example.com',
    createdAt: expect.any(Date),
  }
  expect(actual).toEqual(expect.objectContaining(expected))
})
```

---

## 🚫 構造規約（ネスト禁止）

### ネストした describe は禁止

**describe のネストは可読性を下げ、テストの意図を曖昧にする。**

```typescript
// ❌ 悪い例: ネストした describe
describe('UserService', () => {
  describe('createUser', () => {
    describe('正常系', () => {
      describe('管理者の場合', () => {
        it('should create admin user', () => { ... })
      })
    })
  })
})

// ✅ 良い例: フラットな構造
describe('UserService.createUser', () => {
  // 共有データは describe スコープに配置
  const validUserData = { name: 'John', email: 'john@example.com' }

  it('有効なデータの時、ユーザーを作成すべき', () => { ... })
  it('管理者ロールの時、管理者権限で作成すべき', () => { ... })
  it('メールが重複する時、エラーを投げるべき', () => { ... })
})
```

### 共有データの配置

```typescript
// ✅ 良い例: 共有データはトップレベル describe 内に配置
describe('OrderService.calculateTotal', () => {
  // 共有データ
  const baseOrder = {
    items: [{ price: 1000 }, { price: 2000 }],
    isMember: false,
  }

  it('通常会員の時、税込み金額を返すべき', () => {
    const actual = calculateTotal(baseOrder)
    expect(actual).toBe(3300) // 3000 * 1.1
  })

  it('プレミアム会員の時、割引後の税込み金額を返すべき', () => {
    const memberOrder = { ...baseOrder, isMember: true }
    const actual = calculateTotal(memberOrder)
    expect(actual).toBe(3135) // 3000 * 0.95 * 1.1
  })
})
```

---

## ☝️ 1テスト1アサーション

### 原則: 1つのテストで1つの振る舞いを検証

```typescript
// ❌ 悪い例: 複数の独立したアサーション
it('ユーザーを作成する', () => {
  const user = createUser(userData)
  expect(user.id).toBeDefined()
  expect(user.name).toBe('John')
  expect(user.email).toBe('john@example.com')
  expect(user.createdAt).toBeInstanceOf(Date)
})

// ✅ 良い例: オブジェクトとして1つのアサーション
it('ユーザーを作成する時、正しいプロパティで作成されるべき', () => {
  const actual = createUser(userData)

  const expected = {
    id: expect.any(String),
    name: 'John',
    email: 'john@example.com',
    createdAt: expect.any(Date),
  }
  expect(actual).toEqual(expect.objectContaining(expected))
})

// ✅ または: 振る舞いごとにテストを分割
describe('createUser', () => {
  it('作成時、一意のIDが生成されるべき', () => {
    const user = createUser(userData)
    expect(user.id).toBeDefined()
  })

  it('作成時、入力された名前が設定されるべき', () => {
    const user = createUser({ ...userData, name: 'John' })
    expect(user.name).toBe('John')
  })
})
```

---

## 📸 スナップショットの使用制限

### スナップショットは最小限に

**セマンティックなHTML構造とアクセシビリティ属性の検証にのみ使用する。**

```typescript
// ❌ 悪い例: スタイル変更で壊れるスナップショット
it('renders button', () => {
  const { container } = render(<Button>Click me</Button>)
  expect(container).toMatchSnapshot()
})

// ❌ 悪い例: 巨大なスナップショット
it('renders page', () => {
  const { container } = render(<DashboardPage />)
  expect(container).toMatchSnapshot() // 数百行のスナップショット
})

// ✅ 良い例: セマンティック構造のみ検証
it('アクセシブルなボタンとしてレンダリングされるべき', () => {
  render(<Button disabled>Submit</Button>)

  const button = screen.getByRole('button', { name: 'Submit' })
  expect(button).toBeDisabled()
  expect(button).toHaveAttribute('type', 'submit')
})

// ✅ 良い例: 限定的なスナップショット（構造のみ）
it('ナビゲーション構造が正しいべき', () => {
  render(<Navigation items={navItems} />)

  const nav = screen.getByRole('navigation')
  expect(nav).toMatchInlineSnapshot(`
    <nav aria-label="メインナビゲーション">
      <ul>
        <li><a href="/">ホーム</a></li>
        <li><a href="/about">会社概要</a></li>
      </ul>
    </nav>
  `)
})
```

### スナップショットを使用して良いケース

- アクセシビリティ属性（`aria-*`, `role`）の検証
- セマンティックHTML構造の検証
- 生成されるマークアップが仕様で決まっている場合

### スナップショットを使用すべきでないケース

- スタイル（CSS）の検証
- 動的なコンテンツ（日付、ID等）を含む場合
- 巨大なコンポーネントツリー

---

## ⚛️ React Testing Library 固有の規約

### クエリの優先順位

**アクセシビリティに基づいた優先順位を守る。**

```typescript
// 優先順位（高い順）
// 1. getByRole - 最も推奨
screen.getByRole('button', { name: '送信' })
screen.getByRole('textbox', { name: 'メールアドレス' })

// 2. getByLabelText - フォーム要素
screen.getByLabelText('メールアドレス')

// 3. getByPlaceholderText - ラベルがない場合のフォールバック
screen.getByPlaceholderText('example@example.com')

// 4. getByText - 非インタラクティブ要素
screen.getByText('ようこそ')

// 5. getByTestId - 最後の手段
screen.getByTestId('custom-element')
```

### userEvent の使用

```typescript
import userEvent from '@testing-library/user-event'

// ❌ 悪い例: fireEvent の直接使用
it('ボタンクリック時、送信されるべき', () => {
  render(<Form onSubmit={mockSubmit} />)
  fireEvent.click(screen.getByRole('button'))
  expect(mockSubmit).toHaveBeenCalled()
})

// ✅ 良い例: userEvent を使用
it('ボタンクリック時、送信されるべき', async () => {
  const user = userEvent.setup()
  render(<Form onSubmit={mockSubmit} />)

  await user.click(screen.getByRole('button', { name: '送信' }))

  expect(mockSubmit).toHaveBeenCalled()
})
```

### 非同期処理の待機

```typescript
// ✅ 良い例: waitFor / findBy を使用
it('データ取得後、ユーザー名が表示されるべき', async () => {
  render(<UserProfile userId="1" />)

  // findBy は自動的に待機する
  const userName = await screen.findByText('John Doe')
  expect(userName).toBeInTheDocument()
})

// ✅ 良い例: waitFor で条件待機
it('フォーム送信後、成功メッセージが表示されるべき', async () => {
  const user = userEvent.setup()
  render(<ContactForm />)

  await user.type(screen.getByLabelText('メッセージ'), 'Hello')
  await user.click(screen.getByRole('button', { name: '送信' }))

  await waitFor(() => {
    expect(screen.getByText('送信完了')).toBeInTheDocument()
  })
})
```

### モックの設定

```typescript
import { vi } from 'vitest'

// ✅ 良い例: vi.fn() でモック作成
describe('Button', () => {
  it('クリック時、onClick が呼ばれるべき', async () => {
    const user = userEvent.setup()
    const handleClick = vi.fn()

    render(<Button onClick={handleClick}>Click me</Button>)
    await user.click(screen.getByRole('button'))

    expect(handleClick).toHaveBeenCalledTimes(1)
  })
})

// ✅ 良い例: モジュールモック
vi.mock('@/services/api', () => ({
  fetchUser: vi.fn().mockResolvedValue({ id: '1', name: 'John' }),
}))
```

---

## 📋 クイックチェックリスト

テスト作成時に確認：

- [ ] vitest から明示的にインポートしているか
- [ ] テスト名は「〜の時、〜すべき」形式か
- [ ] AAA パターンで actual / expected を使用しているか
- [ ] describe がネストしていないか
- [ ] 1テスト1アサーション（またはオブジェクト比較）か
- [ ] スナップショットは構造検証のみか
- [ ] RTL のクエリ優先順位を守っているか
- [ ] userEvent を使用しているか（fireEvent でなく）

---

## 🔗 関連ファイル

- **[SKILL.md](./SKILL.md)** - 概要に戻る
- **[TDD.md](./TDD.md)** - TDDサイクル
- **[REFERENCE.md](./REFERENCE.md)** - ベストプラクティス
- **[AI-REVIEW-GUIDELINES.md](./AI-REVIEW-GUIDELINES.md)** - AIコードレビュー観点
