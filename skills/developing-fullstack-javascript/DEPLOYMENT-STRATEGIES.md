# デプロイメント戦略ガイド

O'Reilly書籍「Full Stack JavaScript Strategies」に基づく、フルスタックJavaScriptアプリケーションのデプロイ・CI/CD・統合テスト戦略の完全ガイド。

## 目次

1. [テスト戦略](#1-テスト戦略)
2. [CI/CDパイプライン](#2-cicdパイプライン)
3. [デプロイ戦略](#3-デプロイ戦略)
4. [ロールバック戦略](#4-ロールバック戦略)
5. [コンテナ化](#5-コンテナ化)
6. [統合テスト](#6-統合テスト)
7. [モニタリングとインシデント対応](#7-モニタリングとインシデント対応)

---

## 1. テスト戦略

### 1.1 テストピラミッド

テストピラミッドは、効果的なテスト戦略の基本原則を視覚化したものです。

```
        /  E2E  \        ← 少数（高コスト、高信頼性、実行時間長い）
       / Integration \    ← 中程度（中コスト、中信頼性）
      /    Unit Tests   \  ← 多数（低コスト、高速、低信頼性）
```

**基本原則:**
- **ユニットテスト（基盤）**: 最も多く、最も高速。個別の関数やコンポーネントをテスト
- **統合テスト（中層）**: 複数のモジュールやAPIとの統合をテスト
- **E2Eテスト（頂点）**: 最も少なく、実際のユーザーフローをブラウザでテスト

**なぜピラミッド型か？**
- コストと実行時間が上に行くほど増加
- E2Eテストは貴重だが、すべてをE2Eでカバーするのは非現実的
- ユニットテストで大部分をカバーし、E2Eで重要なフローのみを確認

---

### 1.2 ユニットテスト

#### 1.2.1 推奨ツール

**Vitest（最優先推奨）**
- Viteベースのプロジェクトに最適
- Jest互換のAPI
- 高速な実行速度
- ESMネイティブサポート
- HMR（Hot Module Replacement）対応

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'src/test/',
      ],
    },
  },
})
```

**Jest + React Testing Library（従来型プロジェクト）**
- Create React Appプロジェクト
- レガシーコードベース
- 大規模なテストスイートが既存

```typescript
// jest.config.js
module.exports = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/src/test/setup.ts'],
  moduleNameMapper: {
    '\\.(css|less|scss|sass)$': 'identity-obj-proxy',
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  collectCoverageFrom: [
    'src/**/*.{js,jsx,ts,tsx}',
    '!src/**/*.d.ts',
    '!src/test/**',
  ],
}
```

#### 1.2.2 モック設計パターン

**基本的なモックパターン:**

```typescript
// src/test/mocks/queryClient.ts
import { vi } from 'vitest'

export const createMockUseQuery = () => {
  const mockFn = vi.fn()

  return {
    mockFn,
    mockSuccess: (data: any) => {
      mockFn.mockReturnValue({
        data,
        isLoading: false,
        isError: false,
        error: null,
      })
    },
    mockLoading: () => {
      mockFn.mockReturnValue({
        data: undefined,
        isLoading: true,
        isError: false,
        error: null,
      })
    },
    mockError: (error: Error) => {
      mockFn.mockReturnValue({
        data: undefined,
        isLoading: false,
        isError: true,
        error,
      })
    },
  }
}

// テストファイルでの使用
import { createMockUseQuery } from '@/test/mocks/queryClient'

const mockUseQuery = createMockUseQuery()

vi.mock('@tanstack/react-query', () => ({
  useQuery: () => mockUseQuery.mockFn(),
}))

describe('OrderList', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('displays loading state', () => {
    mockUseQuery.mockLoading()
    render(<OrderList />)
    expect(screen.getByText('Loading...')).toBeInTheDocument()
  })

  it('displays orders on success', () => {
    mockUseQuery.mockSuccess([
      { id: 1, name: 'Order 1' },
      { id: 2, name: 'Order 2' },
    ])
    render(<OrderList />)
    expect(screen.getByText('Order 1')).toBeInTheDocument()
    expect(screen.getByText('Order 2')).toBeInTheDocument()
  })

  it('displays error message on failure', () => {
    mockUseQuery.mockError(new Error('Failed to fetch'))
    render(<OrderList />)
    expect(screen.getByText(/error/i)).toBeInTheDocument()
  })
})
```

**モジュールモックの高度なパターン:**

```typescript
// src/test/mocks/api.ts
import { vi } from 'vitest'

export const mockApiHandlers = {
  getOrders: vi.fn(),
  createOrder: vi.fn(),
  updateOrder: vi.fn(),
  deleteOrder: vi.fn(),
}

export const resetApiMocks = () => {
  Object.values(mockApiHandlers).forEach(mock => mock.mockReset())
}

// テストでの使用
vi.mock('@/api/orders', () => ({
  getOrders: () => mockApiHandlers.getOrders(),
  createOrder: (data: any) => mockApiHandlers.createOrder(data),
}))

describe('OrderService', () => {
  beforeEach(() => {
    resetApiMocks()
  })

  it('creates an order successfully', async () => {
    const mockOrder = { id: 1, status: 'pending' }
    mockApiHandlers.createOrder.mockResolvedValue(mockOrder)

    const result = await createOrder({ item: 'Coffee' })

    expect(mockApiHandlers.createOrder).toHaveBeenCalledWith({ item: 'Coffee' })
    expect(result).toEqual(mockOrder)
  })
})
```

#### 1.2.3 モックデータの外部ファイル管理

**ベストプラクティス: モックデータの一元管理**

```typescript
// src/test/fixtures/orders.ts
export const mockOrders = [
  {
    id: 1,
    customerName: 'John Doe',
    items: ['Coffee', 'Croissant'],
    total: 8.50,
    status: 'pending',
    createdAt: '2024-01-15T10:30:00Z',
  },
  {
    id: 2,
    customerName: 'Jane Smith',
    items: ['Tea', 'Muffin'],
    total: 6.75,
    status: 'completed',
    createdAt: '2024-01-15T11:00:00Z',
  },
]

export const mockOrdersPending = mockOrders.filter(o => o.status === 'pending')
export const mockOrdersCompleted = mockOrders.filter(o => o.status === 'completed')

export const createMockOrder = (overrides = {}) => ({
  id: 999,
  customerName: 'Test User',
  items: ['Test Item'],
  total: 10.00,
  status: 'pending',
  createdAt: new Date().toISOString(),
  ...overrides,
})
```

```typescript
// src/test/fixtures/users.ts
export const mockUsers = {
  admin: {
    id: 1,
    email: 'admin@test.com',
    role: 'admin',
    permissions: ['read', 'write', 'delete'],
  },
  customer: {
    id: 2,
    email: 'customer@test.com',
    role: 'customer',
    permissions: ['read'],
  },
}

export const mockAuthTokens = {
  validToken: 'valid-jwt-token-abc123',
  expiredToken: 'expired-jwt-token-xyz789',
  invalidToken: 'invalid-token',
}
```

**使用例:**

```typescript
import { mockOrders, createMockOrder } from '@/test/fixtures/orders'
import { mockUsers } from '@/test/fixtures/users'

describe('OrderList Component', () => {
  it('renders all orders', () => {
    mockUseQuery.mockSuccess(mockOrders)
    render(<OrderList />)
    expect(screen.getAllByRole('listitem')).toHaveLength(mockOrders.length)
  })

  it('renders custom order', () => {
    const customOrder = createMockOrder({ customerName: 'Special Customer' })
    mockUseQuery.mockSuccess([customOrder])
    render(<OrderList />)
    expect(screen.getByText('Special Customer')).toBeInTheDocument()
  })
})
```

#### 1.2.4 beforeEach/afterEachパターン

**セットアップとクリーンアップの標準化:**

```typescript
describe('OrderForm', () => {
  let mockSubmit: ReturnType<typeof vi.fn>
  let mockValidate: ReturnType<typeof vi.fn>

  beforeEach(() => {
    // 各テスト前に新しいモックを作成
    mockSubmit = vi.fn()
    mockValidate = vi.fn()

    // グローバルモックのリセット
    vi.clearAllMocks()

    // ローカルストレージのクリア
    localStorage.clear()

    // 日付モックの設定
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-01-15'))
  })

  afterEach(() => {
    // タイマーのクリーンアップ
    vi.useRealTimers()

    // DOMのクリーンアップ
    cleanup()
  })

  it('submits form with valid data', async () => {
    mockValidate.mockReturnValue(true)
    render(<OrderForm onSubmit={mockSubmit} onValidate={mockValidate} />)

    await userEvent.type(screen.getByLabelText('Name'), 'John Doe')
    await userEvent.click(screen.getByRole('button', { name: /submit/i }))

    expect(mockValidate).toHaveBeenCalledTimes(1)
    expect(mockSubmit).toHaveBeenCalledWith({ name: 'John Doe' })
  })

  it('does not submit form with invalid data', async () => {
    mockValidate.mockReturnValue(false)
    render(<OrderForm onSubmit={mockSubmit} onValidate={mockValidate} />)

    await userEvent.click(screen.getByRole('button', { name: /submit/i }))

    expect(mockValidate).toHaveBeenCalledTimes(1)
    expect(mockSubmit).not.toHaveBeenCalled()
  })
})
```

**非同期処理のクリーンアップ:**

```typescript
describe('AsyncDataFetcher', () => {
  let abortController: AbortController

  beforeEach(() => {
    abortController = new AbortController()
  })

  afterEach(() => {
    // 未完了のリクエストをキャンセル
    abortController.abort()
  })

  it('fetches data successfully', async () => {
    const { result } = renderHook(() => useFetchData(abortController.signal))

    await waitFor(() => {
      expect(result.current.data).toBeDefined()
    })
  })
})
```

#### 1.2.5 テストすべき項目

**優先度A: 必ずテストすべき項目**

1. **条件付きレンダリング**

```typescript
describe('ConditionalComponent', () => {
  it('renders login form when not authenticated', () => {
    render(<ConditionalComponent isAuthenticated={false} />)
    expect(screen.getByRole('form', { name: /login/i })).toBeInTheDocument()
  })

  it('renders dashboard when authenticated', () => {
    render(<ConditionalComponent isAuthenticated={true} />)
    expect(screen.getByRole('main', { name: /dashboard/i })).toBeInTheDocument()
  })

  it('renders error message when error prop is provided', () => {
    render(<ConditionalComponent error="Something went wrong" />)
    expect(screen.getByRole('alert')).toHaveTextContent('Something went wrong')
  })
})
```

2. **APIリクエスト**

```typescript
describe('OrderAPI', () => {
  it('sends correct request payload', async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ id: 1, status: 'success' }),
    })
    global.fetch = mockFetch

    await createOrder({ item: 'Coffee', quantity: 2 })

    expect(mockFetch).toHaveBeenCalledWith(
      '/api/orders',
      expect.objectContaining({
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ item: 'Coffee', quantity: 2 }),
      })
    )
  })

  it('handles network errors', async () => {
    global.fetch = vi.fn().mockRejectedValue(new Error('Network error'))

    await expect(createOrder({ item: 'Coffee' })).rejects.toThrow('Network error')
  })

  it('handles HTTP error responses', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 400,
      json: async () => ({ error: 'Invalid request' }),
    })

    await expect(createOrder({ item: '' })).rejects.toThrow('Invalid request')
  })
})
```

3. **エラー状態**

```typescript
describe('ErrorBoundary', () => {
  it('renders error UI when child throws', () => {
    const ThrowError = () => {
      throw new Error('Test error')
    }

    render(
      <ErrorBoundary fallback={<div>Error occurred</div>}>
        <ThrowError />
      </ErrorBoundary>
    )

    expect(screen.getByText('Error occurred')).toBeInTheDocument()
  })

  it('logs error to monitoring service', () => {
    const mockLogger = vi.spyOn(console, 'error').mockImplementation()
    const ThrowError = () => {
      throw new Error('Test error')
    }

    render(
      <ErrorBoundary>
        <ThrowError />
      </ErrorBoundary>
    )

    expect(mockLogger).toHaveBeenCalledWith(
      expect.stringContaining('Test error')
    )
    mockLogger.mockRestore()
  })
})
```

4. **データ操作（CRUD）**

```typescript
describe('OrderService', () => {
  it('creates order with correct data transformation', () => {
    const input = { item: 'coffee', price: 5.00 }
    const expected = {
      id: expect.any(Number),
      item: 'coffee',
      price: 5.00,
      createdAt: expect.any(String),
      status: 'pending',
    }

    const result = OrderService.create(input)

    expect(result).toEqual(expected)
  })

  it('updates existing order', () => {
    const existing = { id: 1, item: 'coffee', status: 'pending' }
    const updates = { status: 'completed' }

    const result = OrderService.update(existing, updates)

    expect(result).toEqual({
      ...existing,
      ...updates,
      updatedAt: expect.any(String),
    })
  })

  it('deletes order and returns confirmation', () => {
    const order = { id: 1, item: 'coffee' }

    const result = OrderService.delete(order.id)

    expect(result).toEqual({ success: true, deletedId: 1 })
  })
})
```

5. **コンポーネントの状態変更**

```typescript
describe('Counter', () => {
  it('increments count on button click', async () => {
    render(<Counter initialCount={0} />)
    const button = screen.getByRole('button', { name: /increment/i })

    await userEvent.click(button)

    expect(screen.getByText('Count: 1')).toBeInTheDocument()
  })

  it('decrements count on button click', async () => {
    render(<Counter initialCount={5} />)
    const button = screen.getByRole('button', { name: /decrement/i })

    await userEvent.click(button)

    expect(screen.getByText('Count: 4')).toBeInTheDocument()
  })

  it('resets count to initial value', async () => {
    render(<Counter initialCount={0} />)
    const incrementBtn = screen.getByRole('button', { name: /increment/i })
    const resetBtn = screen.getByRole('button', { name: /reset/i })

    await userEvent.click(incrementBtn)
    await userEvent.click(incrementBtn)
    await userEvent.click(resetBtn)

    expect(screen.getByText('Count: 0')).toBeInTheDocument()
  })
})
```

**優先度B: 推奨するテスト項目**

6. **フォームバリデーション**

```typescript
describe('LoginForm', () => {
  it('shows validation error for invalid email', async () => {
    render(<LoginForm />)

    await userEvent.type(screen.getByLabelText(/email/i), 'invalid-email')
    await userEvent.click(screen.getByRole('button', { name: /submit/i }))

    expect(await screen.findByText(/valid email/i)).toBeInTheDocument()
  })

  it('shows validation error for short password', async () => {
    render(<LoginForm />)

    await userEvent.type(screen.getByLabelText(/password/i), '123')
    await userEvent.click(screen.getByRole('button', { name: /submit/i }))

    expect(await screen.findByText(/at least 8 characters/i)).toBeInTheDocument()
  })
})
```

7. **ユーザーインタラクション**

```typescript
describe('Dropdown', () => {
  it('opens menu on button click', async () => {
    render(<Dropdown items={['Option 1', 'Option 2']} />)

    await userEvent.click(screen.getByRole('button'))

    expect(screen.getByRole('menu')).toBeVisible()
  })

  it('selects item and closes menu', async () => {
    const onSelect = vi.fn()
    render(<Dropdown items={['Option 1', 'Option 2']} onSelect={onSelect} />)

    await userEvent.click(screen.getByRole('button'))
    await userEvent.click(screen.getByText('Option 1'))

    expect(onSelect).toHaveBeenCalledWith('Option 1')
    expect(screen.queryByRole('menu')).not.toBeInTheDocument()
  })
})
```

#### 1.2.6 スナップショットテスト

**適切な使用例:**

```typescript
describe('OrderSummary Snapshot', () => {
  it('matches snapshot for pending order', () => {
    const order = createMockOrder({ status: 'pending' })
    const { container } = render(<OrderSummary order={order} />)

    expect(container).toMatchSnapshot()
  })

  it('matches snapshot for completed order', () => {
    const order = createMockOrder({ status: 'completed' })
    const { container } = render(<OrderSummary order={order} />)

    expect(container).toMatchSnapshot()
  })
})
```

**スナップショットテストの注意点:**
- ✅ **良い使用例**: 静的なUI、複雑なマークアップ構造の変更検出
- ❌ **悪い使用例**: 動的なコンテンツ、日付やIDなどの可変データ
- スナップショットが大きすぎる場合は分割を検討
- スナップショット更新時は必ず差分を確認

**インラインスナップショット（推奨）:**

```typescript
it('renders order status badge', () => {
  render(<StatusBadge status="pending" />)

  expect(screen.getByRole('status')).toMatchInlineSnapshot(`
    <div
      class="badge badge-pending"
      role="status"
    >
      Pending
    </div>
  `)
})
```

#### 1.2.7 テスタビリティのためのリファクタリング

**Before: テストしにくいコード**

```typescript
// ❌ テストしにくい: 副作用が多く、依存関係が隠蔽されている
function OrderProcessor() {
  const handleSubmit = async (data: OrderData) => {
    // 直接fetchを呼び出し
    const response = await fetch('/api/orders', {
      method: 'POST',
      body: JSON.stringify(data),
    })

    // 直接localStorageにアクセス
    localStorage.setItem('lastOrder', JSON.stringify(data))

    // 直接DOMを操作
    document.getElementById('status')!.textContent = 'Success'

    // 直接外部サービスを呼び出し
    analytics.track('order_created', data)
  }

  return <form onSubmit={handleSubmit}>...</form>
}
```

**After: テストしやすいコード**

```typescript
// ✅ テストしやすい: 依存関係が明示的、関数が純粋
interface OrderProcessorProps {
  onSubmit: (data: OrderData) => Promise<void>
  onSuccess?: (data: OrderData) => void
  storage?: Storage
  analytics?: AnalyticsService
}

function OrderProcessor({
  onSubmit,
  onSuccess,
  storage = localStorage,
  analytics = defaultAnalytics,
}: OrderProcessorProps) {
  const handleSubmit = async (data: OrderData) => {
    await onSubmit(data)
    storage.setItem('lastOrder', JSON.stringify(data))
    analytics.track('order_created', data)
    onSuccess?.(data)
  }

  return <form onSubmit={handleSubmit}>...</form>
}

// テストコード
describe('OrderProcessor', () => {
  it('calls all dependencies correctly', async () => {
    const mockSubmit = vi.fn().mockResolvedValue(undefined)
    const mockSuccess = vi.fn()
    const mockStorage = { setItem: vi.fn() }
    const mockAnalytics = { track: vi.fn() }

    render(
      <OrderProcessor
        onSubmit={mockSubmit}
        onSuccess={mockSuccess}
        storage={mockStorage as any}
        analytics={mockAnalytics}
      />
    )

    const data = { item: 'Coffee' }
    await userEvent.click(screen.getByRole('button'))

    expect(mockSubmit).toHaveBeenCalledWith(data)
    expect(mockStorage.setItem).toHaveBeenCalledWith('lastOrder', JSON.stringify(data))
    expect(mockAnalytics.track).toHaveBeenCalledWith('order_created', data)
    expect(mockSuccess).toHaveBeenCalledWith(data)
  })
})
```

**リファクタリング原則:**
1. **依存性注入**: 外部依存をpropsやパラメータとして渡す
2. **純粋関数**: 副作用を最小限に、入力に対して予測可能な出力
3. **単一責任**: 1つの関数/コンポーネントは1つの責務のみ
4. **明示的な依存関係**: グローバル変数や隠れた依存を避ける

---

### 1.3 バックエンドテスト

#### 1.3.1 NestJS統合テスト

**Jest設定（NestJS組み込み）:**

```typescript
// test/jest-e2e.json
{
  "moduleFileExtensions": ["js", "json", "ts"],
  "rootDir": ".",
  "testEnvironment": "node",
  "testRegex": ".e2e-spec.ts$",
  "transform": {
    "^.+\\.(t|j)s$": "ts-jest"
  }
}
```

**コントローラーテスト:**

```typescript
// src/orders/orders.controller.spec.ts
import { Test, TestingModule } from '@nestjs/testing'
import { OrdersController } from './orders.controller'
import { OrdersService } from './orders.service'
import { CreateOrderDto } from './dto/create-order.dto'

describe('OrdersController', () => {
  let controller: OrdersController
  let service: OrdersService

  const mockOrdersService = {
    create: jest.fn(),
    findAll: jest.fn(),
    findOne: jest.fn(),
    update: jest.fn(),
    remove: jest.fn(),
  }

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [OrdersController],
      providers: [
        {
          provide: OrdersService,
          useValue: mockOrdersService,
        },
      ],
    }).compile()

    controller = module.get<OrdersController>(OrdersController)
    service = module.get<OrdersService>(OrdersService)
  })

  afterEach(() => {
    jest.clearAllMocks()
  })

  describe('create', () => {
    it('should create an order', async () => {
      const dto: CreateOrderDto = {
        customerName: 'John Doe',
        items: ['Coffee'],
        total: 5.00,
      }
      const expectedResult = { id: 1, ...dto, status: 'pending' }

      mockOrdersService.create.mockResolvedValue(expectedResult)

      const result = await controller.create(dto)

      expect(service.create).toHaveBeenCalledWith(dto)
      expect(result).toEqual(expectedResult)
    })

    it('should throw error for invalid data', async () => {
      const dto: CreateOrderDto = {
        customerName: '',
        items: [],
        total: -5.00,
      }

      mockOrdersService.create.mockRejectedValue(new Error('Invalid order data'))

      await expect(controller.create(dto)).rejects.toThrow('Invalid order data')
    })
  })

  describe('findAll', () => {
    it('should return an array of orders', async () => {
      const expectedOrders = [
        { id: 1, customerName: 'John', status: 'pending' },
        { id: 2, customerName: 'Jane', status: 'completed' },
      ]

      mockOrdersService.findAll.mockResolvedValue(expectedOrders)

      const result = await controller.findAll()

      expect(result).toEqual(expectedOrders)
      expect(service.findAll).toHaveBeenCalled()
    })
  })
})
```

#### 1.3.2 サービス層テスト

```typescript
// src/orders/orders.service.spec.ts
import { Test, TestingModule } from '@nestjs/testing'
import { getRepositoryToken } from '@nestjs/typeorm'
import { Repository } from 'typeorm'
import { OrdersService } from './orders.service'
import { Order } from './entities/order.entity'
import { CreateOrderDto } from './dto/create-order.dto'

describe('OrdersService', () => {
  let service: OrdersService
  let repository: Repository<Order>

  const mockRepository = {
    create: jest.fn(),
    save: jest.fn(),
    find: jest.fn(),
    findOne: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  }

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        {
          provide: getRepositoryToken(Order),
          useValue: mockRepository,
        },
      ],
    }).compile()

    service = module.get<OrdersService>(OrdersService)
    repository = module.get<Repository<Order>>(getRepositoryToken(Order))
  })

  describe('create', () => {
    it('should successfully create an order', async () => {
      const dto: CreateOrderDto = {
        customerName: 'John Doe',
        items: ['Coffee', 'Croissant'],
        total: 8.50,
      }

      const orderEntity = {
        id: 1,
        ...dto,
        status: 'pending',
        createdAt: new Date(),
      }

      mockRepository.create.mockReturnValue(orderEntity)
      mockRepository.save.mockResolvedValue(orderEntity)

      const result = await service.create(dto)

      expect(repository.create).toHaveBeenCalledWith(dto)
      expect(repository.save).toHaveBeenCalledWith(orderEntity)
      expect(result).toEqual(orderEntity)
    })

    it('should calculate correct total', async () => {
      const dto: CreateOrderDto = {
        customerName: 'John Doe',
        items: ['Coffee', 'Croissant'],
        total: 8.50,
      }

      await service.create(dto)

      expect(mockRepository.save).toHaveBeenCalledWith(
        expect.objectContaining({
          total: 8.50,
        })
      )
    })
  })

  describe('findAll', () => {
    it('should return all orders', async () => {
      const orders = [
        { id: 1, customerName: 'John', status: 'pending' },
        { id: 2, customerName: 'Jane', status: 'completed' },
      ]

      mockRepository.find.mockResolvedValue(orders)

      const result = await service.findAll()

      expect(result).toEqual(orders)
      expect(repository.find).toHaveBeenCalled()
    })

    it('should filter orders by status', async () => {
      const pendingOrders = [
        { id: 1, customerName: 'John', status: 'pending' },
      ]

      mockRepository.find.mockResolvedValue(pendingOrders)

      const result = await service.findAll({ status: 'pending' })

      expect(repository.find).toHaveBeenCalledWith({
        where: { status: 'pending' },
      })
      expect(result).toEqual(pendingOrders)
    })
  })
})
```

#### 1.3.3 モックデータファクトリー

```typescript
// test/factories/order.factory.ts
import { Order } from '@/orders/entities/order.entity'

export class OrderFactory {
  static create(overrides: Partial<Order> = {}): Order {
    const defaultOrder: Order = {
      id: Math.floor(Math.random() * 1000),
      customerName: 'Test Customer',
      items: ['Test Item'],
      total: 10.00,
      status: 'pending',
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    }

    return defaultOrder
  }

  static createMany(count: number, overrides: Partial<Order> = {}): Order[] {
    return Array.from({ length: count }, (_, i) =>
      this.create({ id: i + 1, ...overrides })
    )
  }

  static createPending(): Order {
    return this.create({ status: 'pending' })
  }

  static createCompleted(): Order {
    return this.create({ status: 'completed' })
  }

  static createWithItems(items: string[]): Order {
    const total = items.length * 5.00 // 仮の計算
    return this.create({ items, total })
  }
}

// 使用例
describe('OrdersService', () => {
  it('processes pending orders', async () => {
    const pendingOrders = OrderFactory.createMany(5, { status: 'pending' })
    mockRepository.find.mockResolvedValue(pendingOrders)

    const result = await service.getPendingOrders()

    expect(result).toHaveLength(5)
    expect(result.every(o => o.status === 'pending')).toBe(true)
  })

  it('calculates total for multi-item order', () => {
    const order = OrderFactory.createWithItems(['Coffee', 'Tea', 'Muffin'])

    expect(order.items).toHaveLength(3)
    expect(order.total).toBe(15.00)
  })
})
```

#### 1.3.4 実際の関数テスト vs モックのバランス

**原則:**
- **ビジネスロジック**: 実際の関数をテスト（モック最小限）
- **外部依存**: モックを使用（DB、API、ファイルシステム）
- **統合テスト**: 実際の依存関係を使用（テストDB等）

**良いバランスの例:**

```typescript
// ビジネスロジック: 実際の関数をテスト
describe('OrderCalculator', () => {
  // モックなし、純粋なロジックテスト
  it('calculates order total correctly', () => {
    const items = [
      { name: 'Coffee', price: 5.00, quantity: 2 },
      { name: 'Muffin', price: 3.50, quantity: 1 },
    ]

    const total = calculateOrderTotal(items)

    expect(total).toBe(13.50)
  })

  it('applies discount correctly', () => {
    const items = [{ name: 'Coffee', price: 10.00, quantity: 1 }]
    const discount = 0.1 // 10% off

    const total = calculateOrderTotal(items, discount)

    expect(total).toBe(9.00)
  })
})

// 外部依存: モックを使用
describe('OrderService with external dependencies', () => {
  it('saves order to database', async () => {
    // DBはモック
    const mockRepo = { save: jest.fn().mockResolvedValue({ id: 1 }) }
    const service = new OrdersService(mockRepo)

    // ビジネスロジックは実際の関数
    const order = await service.create({ items: [...] })

    expect(mockRepo.save).toHaveBeenCalled()
    expect(order.id).toBe(1)
  })

  it('sends confirmation email', async () => {
    // メールサービスはモック
    const mockEmailService = { send: jest.fn().mockResolvedValue(true) }
    const service = new OrdersService(mockRepo, mockEmailService)

    await service.confirmOrder(1)

    expect(mockEmailService.send).toHaveBeenCalledWith(
      expect.objectContaining({
        to: expect.any(String),
        subject: 'Order Confirmation',
      })
    )
  })
})
```

#### 1.3.5 テストカバレッジ目標

**推奨カバレッジ:**

```json
// jest.config.js
{
  "coverageThreshold": {
    "global": {
      "branches": 80,
      "functions": 80,
      "lines": 80,
      "statements": 80
    },
    "./src/orders/": {
      "branches": 90,
      "functions": 95,
      "lines": 95,
      "statements": 95
    },
    "./src/utils/": {
      "branches": 100,
      "functions": 100,
      "lines": 100,
      "statements": 100
    }
  }
}
```

**カバレッジレポートの確認:**

```bash
# カバレッジレポート生成
npm run test:cov

# HTMLレポートを開く
open coverage/index.html
```

**カバレッジが低い場合の対応:**
1. 未テストのブランチを特定
2. エッジケースのテスト追加
3. エラーハンドリングのテスト追加
4. テスト不可能なコードのリファクタリング

---

### 1.4 Mock Service Worker (MSW)

Mock Service Worker（MSW）は、ネットワークレベルでAPIリクエストをインターセプトし、モックレスポンスを返すライブラリです。開発環境とテスト環境の両方で使用できます。

#### 1.4.1 MSWのセットアップ

**インストール:**

```bash
npm install msw --save-dev
```

**ハンドラー定義:**

```typescript
// src/mocks/handlers.ts
import { http, HttpResponse } from 'msw'

export const handlers = [
  // GET リクエスト
  http.get('/api/orders', () => {
    return HttpResponse.json([
      { id: 1, customerName: 'John Doe', status: 'pending' },
      { id: 2, customerName: 'Jane Smith', status: 'completed' },
    ])
  }),

  // POST リクエスト
  http.post('/api/orders', async ({ request }) => {
    const body = await request.json()
    return HttpResponse.json(
      {
        id: Math.floor(Math.random() * 1000),
        ...body,
        status: 'pending',
        createdAt: new Date().toISOString(),
      },
      { status: 201 }
    )
  }),

  // エラーレスポンス
  http.get('/api/orders/:id', ({ params }) => {
    const { id } = params
    if (id === '999') {
      return HttpResponse.json(
        { error: 'Order not found' },
        { status: 404 }
      )
    }
    return HttpResponse.json({
      id,
      customerName: 'Test User',
      status: 'pending',
    })
  }),

  // ネットワークエラーのシミュレーション
  http.get('/api/unstable', () => {
    return HttpResponse.error()
  }),
]
```

**ブラウザでのセットアップ（開発環境）:**

```typescript
// src/mocks/browser.ts
import { setupWorker } from 'msw/browser'
import { handlers } from './handlers'

export const worker = setupWorker(...handlers)
```

```typescript
// src/main.tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'

// 開発環境でのみMSWを起動
if (import.meta.env.DEV) {
  const { worker } = await import('./mocks/browser')
  await worker.start({
    onUnhandledRequest: 'warn', // 未定義のリクエストを警告
  })
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
```

**Node.jsでのセットアップ（テスト環境）:**

```typescript
// src/mocks/server.ts
import { setupServer } from 'msw/node'
import { handlers } from './handlers'

export const server = setupServer(...handlers)
```

```typescript
// src/test/setup.ts
import { beforeAll, afterEach, afterAll } from 'vitest'
import { server } from '../mocks/server'

// テスト開始前にサーバーを起動
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))

// 各テスト後にハンドラーをリセット
afterEach(() => server.resetHandlers())

// すべてのテスト終了後にサーバーを停止
afterAll(() => server.close())
```

#### 1.4.2 MSWを使ったテスト

```typescript
// src/components/OrderList.test.tsx
import { render, screen, waitFor } from '@testing-library/react'
import { server } from '@/mocks/server'
import { http, HttpResponse } from 'msw'
import OrderList from './OrderList'

describe('OrderList with MSW', () => {
  it('displays orders from API', async () => {
    render(<OrderList />)

    // MSWが自動的にリクエストをインターセプト
    await waitFor(() => {
      expect(screen.getByText('John Doe')).toBeInTheDocument()
      expect(screen.getByText('Jane Smith')).toBeInTheDocument()
    })
  })

  it('displays error message on API failure', async () => {
    // このテストだけエラーレスポンスを返す
    server.use(
      http.get('/api/orders', () => {
        return HttpResponse.json(
          { error: 'Internal Server Error' },
          { status: 500 }
        )
      })
    )

    render(<OrderList />)

    await waitFor(() => {
      expect(screen.getByText(/error/i)).toBeInTheDocument()
    })
  })

  it('displays loading state', () => {
    // レスポンスを遅延させる
    server.use(
      http.get('/api/orders', async () => {
        await new Promise(resolve => setTimeout(resolve, 1000))
        return HttpResponse.json([])
      })
    )

    render(<OrderList />)

    expect(screen.getByText(/loading/i)).toBeInTheDocument()
  })
})
```

#### 1.4.3 動的なモックレスポンス

```typescript
// src/mocks/handlers.ts
import { http, HttpResponse, delay } from 'msw'

let orderIdCounter = 1
const ordersDatabase: Order[] = []

export const handlers = [
  // 動的なPOST処理
  http.post('/api/orders', async ({ request }) => {
    await delay(500) // リアルな遅延をシミュレート

    const body = await request.json() as CreateOrderDto
    const newOrder = {
      id: orderIdCounter++,
      ...body,
      status: 'pending',
      createdAt: new Date().toISOString(),
    }

    ordersDatabase.push(newOrder)

    return HttpResponse.json(newOrder, { status: 201 })
  }),

  // 動的なGET処理
  http.get('/api/orders', () => {
    return HttpResponse.json(ordersDatabase)
  }),

  // 動的なDELETE処理
  http.delete('/api/orders/:id', ({ params }) => {
    const { id } = params
    const index = ordersDatabase.findIndex(o => o.id === Number(id))

    if (index === -1) {
      return HttpResponse.json(
        { error: 'Order not found' },
        { status: 404 }
      )
    }

    ordersDatabase.splice(index, 1)
    return HttpResponse.json({ success: true })
  }),
]

// データベースをリセットする関数（テストで使用）
export function resetOrdersDatabase() {
  ordersDatabase.length = 0
  orderIdCounter = 1
}
```

```typescript
// テストでの使用
import { resetOrdersDatabase } from '@/mocks/handlers'

describe('OrderManagement', () => {
  beforeEach(() => {
    resetOrdersDatabase()
  })

  it('creates and retrieves order', async () => {
    const { getByRole, findByText } = render(<OrderManagement />)

    // 注文作成
    await userEvent.type(getByRole('textbox', { name: /customer/i }), 'John')
    await userEvent.click(getByRole('button', { name: /submit/i }))

    // 作成された注文が表示される
    expect(await findByText('John')).toBeInTheDocument()
  })
})
```

#### 1.4.4 MSWの注意点とベストプラクティス

**注意点:**

1. **フロントエンド先行開発のリスク**
   - MSWに依存しすぎると、実際のAPIとの統合時に問題が発覚
   - API仕様が変更されてもMSWは更新されない可能性
   - レスポンス形式の微妙な違いを見逃しやすい

2. **過度なモック依存**
   - すべてのテストをMSWで行うと、実際のAPIとの統合テストが不足
   - E2Eテストでは実際のAPIを使用することを推奨

**ベストプラクティス:**

```typescript
// ❌ 悪い例: MSWのレスポンスを実際のAPIと同期しない
http.get('/api/orders', () => {
  return HttpResponse.json([{ id: 1, name: 'John' }]) // 実際のAPIと構造が異なる
})

// ✅ 良い例: 実際のAPIレスポンス型を使用
import { Order } from '@/types'

http.get('/api/orders', (): HttpResponse<Order[]> => {
  return HttpResponse.json([
    {
      id: 1,
      customerName: 'John Doe', // 実際のAPIと同じフィールド名
      items: ['Coffee'],
      total: 5.00,
      status: 'pending',
      createdAt: '2024-01-15T10:00:00Z',
    },
  ])
})
```

**API仕様との同期:**

```typescript
// src/mocks/fixtures.ts
// OpenAPI仕様やAPIドキュメントから生成されたFixtureを使用
import { mockOrders } from '@/api/__generated__/fixtures'

export const handlers = [
  http.get('/api/orders', () => {
    return HttpResponse.json(mockOrders) // 自動生成されたFixture
  }),
]
```

---

### 1.5 E2Eテスト

E2E（End-to-End）テストは、実際のユーザーの操作をシミュレートし、アプリケーション全体の動作を検証します。

#### 1.5.1 E2Eテストツールの比較

| ツール | 特徴 | メリット | デメリット |
|--------|------|----------|------------|
| **Playwright** | マイクロソフト製、マルチブラウザ | 高速、並列実行、自動待機、強力なセレクタ | 学習コスト中 |
| **Cypress** | 最も人気、大規模コミュニティ | 優れたDX、タイムトラベルデバッグ、豊富なプラグイン | クロスブラウザ制限あり |
| **Nightwatch** | Seleniumベース | Selenium互換、SauceLabs統合 | 遅い、複雑な設定 |

**推奨: Playwright**（2024年時点での最新トレンド）

#### 1.5.2 Playwrightのセットアップ

**インストール:**

```bash
npm init playwright@latest
```

**設定ファイル:**

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',

  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
  },
})
```

#### 1.5.3 E2Eテストの例

**基本的なユーザーフロー:**

```typescript
// e2e/order-submission.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Order Submission Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
  })

  test('submits a successful order', async ({ page }) => {
    // フォーム入力
    await page.getByLabel('First Name').fill('Ernest')
    await page.getByLabel('Last Name').fill('Hemingway')
    await page.getByLabel('Email').fill('ernest@example.com')

    // 商品選択
    await page.getByRole('button', { name: 'Add Coffee' }).click()
    await page.getByRole('button', { name: 'Add Croissant' }).click()

    // 合計金額の確認
    await expect(page.getByText('Total: $8.50')).toBeVisible()

    // 送信
    const submitButton = page.getByRole('button', { name: 'Submit Order' })
    await submitButton.click()

    // 成功メッセージの確認
    await expect(page.getByText('Order submitted successfully')).toBeVisible()

    // URLの変更確認
    await expect(page).toHaveURL(/.*\/orders\/\d+/)

    // 注文詳細ページの表示確認
    await expect(page.getByText('Ernest Hemingway')).toBeVisible()
    await expect(page.getByText('Coffee')).toBeVisible()
  })

  test('shows validation errors for empty form', async ({ page }) => {
    const submitButton = page.getByRole('button', { name: 'Submit Order' })
    await submitButton.click()

    // バリデーションエラーの確認
    await expect(page.getByText('First name is required')).toBeVisible()
    await expect(page.getByText('Email is required')).toBeVisible()

    // 送信されていないことを確認
    await expect(page).toHaveURL('/')
  })

  test('handles server errors gracefully', async ({ page }) => {
    // APIエラーをモック
    await page.route('/api/orders', route => {
      route.fulfill({
        status: 500,
        body: JSON.stringify({ error: 'Internal Server Error' }),
      })
    })

    await page.getByLabel('First Name').fill('Ernest')
    await page.getByLabel('Email').fill('ernest@example.com')
    await page.getByRole('button', { name: 'Submit Order' }).click()

    // エラーメッセージの表示確認
    await expect(page.getByText(/error.*occurred/i)).toBeVisible()
  })
})
```

**認証フロー:**

```typescript
// e2e/authentication.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Authentication', () => {
  test('logs in successfully', async ({ page }) => {
    await page.goto('/login')

    await page.getByLabel('Email').fill('user@example.com')
    await page.getByLabel('Password').fill('password123')
    await page.getByRole('button', { name: 'Log In' }).click()

    // ダッシュボードにリダイレクトされる
    await expect(page).toHaveURL('/dashboard')
    await expect(page.getByText('Welcome back')).toBeVisible()
  })

  test('shows error for invalid credentials', async ({ page }) => {
    await page.goto('/login')

    await page.getByLabel('Email').fill('wrong@example.com')
    await page.getByLabel('Password').fill('wrongpassword')
    await page.getByRole('button', { name: 'Log In' }).click()

    await expect(page.getByText('Invalid credentials')).toBeVisible()
    await expect(page).toHaveURL('/login')
  })

  test('redirects unauthenticated user to login', async ({ page }) => {
    await page.goto('/dashboard')

    // 自動的にログインページにリダイレクトされる
    await expect(page).toHaveURL('/login')
  })
})

// 認証状態を保存して再利用
test.describe('Authenticated tests', () => {
  test.use({ storageState: 'e2e/.auth/user.json' })

  test.beforeAll(async ({ browser }) => {
    const page = await browser.newPage()
    await page.goto('/login')
    await page.getByLabel('Email').fill('user@example.com')
    await page.getByLabel('Password').fill('password123')
    await page.getByRole('button', { name: 'Log In' }).click()
    await page.context().storageState({ path: 'e2e/.auth/user.json' })
    await page.close()
  })

  test('accesses protected route', async ({ page }) => {
    await page.goto('/dashboard')
    await expect(page.getByText('Welcome back')).toBeVisible()
  })
})
```

**複雑なインタラクション:**

```typescript
// e2e/shopping-cart.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Shopping Cart', () => {
  test('adds and removes items', async ({ page }) => {
    await page.goto('/menu')

    // 商品を追加
    await page.getByRole('button', { name: 'Add Coffee' }).click()
    await page.getByRole('button', { name: 'Add Croissant' }).click()

    // カートアイコンのバッジ確認
    await expect(page.getByTestId('cart-count')).toHaveText('2')

    // カートを開く
    await page.getByRole('button', { name: 'Cart' }).click()

    // カート内の商品確認
    await expect(page.getByText('Coffee')).toBeVisible()
    await expect(page.getByText('Croissant')).toBeVisible()

    // 商品を削除
    await page.getByRole('button', { name: 'Remove Coffee' }).click()

    // カート更新確認
    await expect(page.getByTestId('cart-count')).toHaveText('1')
    await expect(page.getByText('Coffee')).not.toBeVisible()
  })

  test('persists cart on page reload', async ({ page }) => {
    await page.goto('/menu')
    await page.getByRole('button', { name: 'Add Coffee' }).click()

    // ページリロード
    await page.reload()

    // カートが保持されている
    await expect(page.getByTestId('cart-count')).toHaveText('1')
  })
})
```

#### 1.5.4 Playwrightのベストプラクティス

**1. Page Object Model (POM) パターン:**

```typescript
// e2e/pages/login.page.ts
import { Page } from '@playwright/test'

export class LoginPage {
  constructor(private page: Page) {}

  async goto() {
    await this.page.goto('/login')
  }

  async login(email: string, password: string) {
    await this.page.getByLabel('Email').fill(email)
    await this.page.getByLabel('Password').fill(password)
    await this.page.getByRole('button', { name: 'Log In' }).click()
  }

  async getErrorMessage() {
    return this.page.getByRole('alert').textContent()
  }
}

// テストでの使用
import { LoginPage } from './pages/login.page'

test('logs in successfully', async ({ page }) => {
  const loginPage = new LoginPage(page)
  await loginPage.goto()
  await loginPage.login('user@example.com', 'password123')

  await expect(page).toHaveURL('/dashboard')
})
```

**2. 自動待機を活用:**

```typescript
// ❌ 悪い例: 手動で待機
await page.click('button')
await page.waitForTimeout(1000) // 固定の待機時間

// ✅ 良い例: 自動待機を信頼
await page.click('button')
await expect(page.getByText('Success')).toBeVisible() // 自動的に待機
```

**3. テストの独立性:**

```typescript
// ❌ 悪い例: テストが依存している
test('creates order', async ({ page }) => {
  // ...注文作成
})

test('edits order', async ({ page }) => {
  // 前のテストで作成した注文に依存 ← 危険
})

// ✅ 良い例: 各テストが独立
test('edits order', async ({ page }) => {
  // テストデータを事前に作成
  await setupTestOrder()
  // ...注文編集
})
```

---

### 1.6 テスト判断基準

どのレベルのテストを書くべきか判断するためのガイドライン。

#### 1.6.1 テストレベルの選択フローチャート

```
質問1: 単一のコンポーネント/関数のみをテストするか？
 ├─ YES → ユニットテスト
 └─ NO  → 質問2へ

質問2: 複数のモジュールやAPIとの統合をテストするか？
 ├─ YES → 統合テスト
 └─ NO  → 質問3へ

質問3: 実際のユーザーフロー全体をテストするか？
 ├─ YES → E2Eテスト
 └─ NO  → 再検討が必要
```

#### 1.6.2 具体的な判断基準

| シナリオ | 推奨テストレベル | 理由 |
|---------|-----------------|------|
| ボタンクリックで状態が変わる | ユニットテスト | 単一コンポーネントの動作 |
| APIからデータを取得して表示 | 統合テスト | フロントエンド + バックエンド |
| ログイン → 注文 → 支払い | E2Eテスト | 複数ページにまたがるフロー |
| 日付フォーマット関数 | ユニットテスト | 純粋関数、外部依存なし |
| フォームバリデーション | ユニットテスト + 統合テスト | ロジック + UI確認 |
| 404エラーページ表示 | E2Eテスト | ルーティング含む全体動作 |

#### 1.6.3 フロントエンドカバレッジの現実的な目標

**バックエンドとの違い:**
- **バックエンド**: ビジネスロジック中心 → 100%カバレッジ可能
- **フロントエンド**: UI/UX、ユーザーインタラクション中心 → 100%カバレッジは非現実的

**現実的な目標:**

```
コアビジネスロジック（utils, services）: 100%
コンポーネントロジック（hooks, stores）: 80-90%
UIコンポーネント（表示のみ）: 60-70%
E2Eカバレッジ: 主要ユーザーフロー（5-10シナリオ）
```

**カバレッジよりも重要なこと:**
1. **重要な機能が動作すること**
2. **エッジケースの処理**
3. **エラーハンドリング**
4. **ユーザー体験の品質**

#### 1.6.4 テスト作成時間 vs 価値のトレードオフ

**高価値・低コスト（優先度: 最高）:**
- ビジネスロジックのユニットテスト
- クリティカルなユーザーフローのE2Eテスト
- APIエンドポイントの統合テスト

**高価値・高コスト（優先度: 高）:**
- 複雑なフォームのE2Eテスト
- 認証フローのE2Eテスト
- 支払い処理の統合テスト

**低価値・低コスト（優先度: 中）:**
- シンプルな表示コンポーネントのスナップショットテスト
- ヘルパー関数のユニットテスト

**低価値・高コスト（優先度: 最低）:**
- 頻繁に変更されるUIの詳細なテスト
- すべてのエッジケースを網羅するE2Eテスト

**判断の例:**

```typescript
// ❌ 低価値: 静的な表示のみのコンポーネント
test('renders header with correct text', () => {
  render(<Header />)
  expect(screen.getByText('My App')).toBeInTheDocument()
})

// ✅ 高価値: ビジネスロジックを含むコンポーネント
test('calculates discount correctly', () => {
  render(<PricingCalculator basePrice={100} discount={0.2} />)
  expect(screen.getByText('$80.00')).toBeInTheDocument()
})

// ✅ 高価値: クリティカルなユーザーフロー
test('completes checkout process', async ({ page }) => {
  await page.goto('/cart')
  await page.getByRole('button', { name: 'Checkout' }).click()
  await page.getByLabel('Card Number').fill('4242424242424242')
  await page.getByRole('button', { name: 'Pay' }).click()
  await expect(page.getByText('Payment successful')).toBeVisible()
})
```

---

## 2. CI/CDパイプライン

継続的インテグレーション（CI）と継続的デリバリー（CD）は、コードの変更を自動的にテスト・ビルド・デプロイするプロセスです。

### 2.1 基本構成

**CI/CDパイプラインの標準フロー:**

```
1. コードプッシュ（Git push）
   ↓
2. リント・フォーマットチェック
   ├─ ESLint
   ├─ Prettier
   └─ TypeScript型チェック
   ↓
3. ユニットテスト実行
   ├─ Vitest/Jest
   └─ カバレッジレポート
   ↓
4. ビルド
   ├─ フロントエンド（Vite/Next.js）
   └─ バックエンド（NestJS）
   ↓
5. E2Eテスト実行
   └─ Playwright
   ↓
6. セキュリティスキャン
   ├─ npm audit
   ├─ Snyk
   └─ OWASP Dependency Check
   ↓
7. ステージングデプロイ
   └─ 自動デプロイ（mainブランチ）
   ↓
8. 本番デプロイ
   └─ 手動承認 or 自動デプロイ（タグ付き）
```

---

### 2.2 GitHub Actionsの設定例

#### 2.2.1 基本的なCI設定

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Run Prettier check
        run: npm run format:check

      - name: TypeScript type check
        run: npm run type-check

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run unit tests
        run: npm run test:coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./coverage/coverage-final.json

  build:
    runs-on: ubuntu-latest
    needs: [lint, test]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build application
        run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/

  e2e:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright browsers
        run: npx playwright install --with-deps

      - name: Run E2E tests
        run: npm run test:e2e

      - name: Upload Playwright report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: playwright-report/

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run npm audit
        run: npm audit --audit-level=moderate

      - name: Run Snyk security scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

#### 2.2.2 CD設定（ステージング自動デプロイ）

```yaml
# .github/workflows/deploy-staging.yml
name: Deploy to Staging

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build application
        run: npm run build
        env:
          VITE_API_URL: ${{ secrets.STAGING_API_URL }}

      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'

      - name: Notify Slack
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Staging deployment completed'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

#### 2.2.3 CD設定（本番デプロイ - 手動承認）

```yaml
# .github/workflows/deploy-production.yml
name: Deploy to Production

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://app.example.com

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm run test

      - name: Build application
        run: npm run build
        env:
          VITE_API_URL: ${{ secrets.PRODUCTION_API_URL }}

      - name: Deploy to production
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'

      - name: Create GitHub Release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ github.ref }}
          release_name: Release ${{ github.ref }}
          draft: false
          prerelease: false

      - name: Notify team
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Production deployment completed: ${{ github.ref }}'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

### 2.3 環境変数管理

#### 2.3.1 環境変数の原則

**重要な原則:**
1. **機密情報はコミットしない**: `.env`ファイルは`.gitignore`に追加
2. **環境ごとに分離**: `.env.development`, `.env.staging`, `.env.production`
3. **CI/CDでの管理**: GitHub Secrets等のシークレット管理サービスを使用
4. **バリデーション**: 起動時に必須環境変数をチェック

**ディレクトリ構造:**

```
project/
├── .env.example         # テンプレート（コミット可）
├── .env.development     # ローカル開発用（gitignore）
├── .env.staging         # ステージング用（gitignore）
├── .env.production      # 本番用（gitignore）
└── .gitignore
```

**`.env.example`:**

```bash
# API Configuration
VITE_API_URL=https://api.example.com
VITE_API_KEY=your_api_key_here

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/dbname

# Authentication
JWT_SECRET=your_jwt_secret
JWT_EXPIRES_IN=7d

# External Services
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_PUBLISHABLE_KEY=pk_test_xxx
SENDGRID_API_KEY=SG.xxx

# Feature Flags
VITE_ENABLE_ANALYTICS=true
VITE_ENABLE_DEBUG=false
```

#### 2.3.2 環境変数のバリデーション

**Zod を使った型安全なバリデーション:**

```typescript
// src/config/env.ts
import { z } from 'zod'

const envSchema = z.object({
  // API
  VITE_API_URL: z.string().url(),
  VITE_API_KEY: z.string().min(1),

  // Database (サーバーサイドのみ)
  DATABASE_URL: z.string().url().optional(),

  // Authentication
  JWT_SECRET: z.string().min(32).optional(),
  JWT_EXPIRES_IN: z.string().default('7d'),

  // External Services
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  SENDGRID_API_KEY: z.string().startsWith('SG.'),

  // Feature Flags
  VITE_ENABLE_ANALYTICS: z.string().transform(val => val === 'true'),
  VITE_ENABLE_DEBUG: z.string().transform(val => val === 'true'),

  // Node Environment
  NODE_ENV: z.enum(['development', 'staging', 'production']).default('development'),
})

export type Env = z.infer<typeof envSchema>

function validateEnv(): Env {
  try {
    return envSchema.parse(import.meta.env)
  } catch (error) {
    if (error instanceof z.ZodError) {
      console.error('❌ Invalid environment variables:')
      error.errors.forEach(err => {
        console.error(`  - ${err.path.join('.')}: ${err.message}`)
      })
    }
    process.exit(1)
  }
}

export const env = validateEnv()
```

**使用例:**

```typescript
// src/api/client.ts
import { env } from '@/config/env'

const apiClient = axios.create({
  baseURL: env.VITE_API_URL,
  headers: {
    'X-API-Key': env.VITE_API_KEY,
  },
})

if (env.VITE_ENABLE_DEBUG) {
  apiClient.interceptors.request.use(request => {
    console.log('API Request:', request)
    return request
  })
}
```

#### 2.3.3 GitHub Secretsの管理

**GitHub Secretsの設定:**

1. リポジトリの Settings → Secrets and variables → Actions
2. New repository secret をクリック
3. シークレット名と値を入力

**環境別のSecrets:**

```yaml
# .github/workflows/deploy-staging.yml
environment: staging
env:
  VITE_API_URL: ${{ secrets.STAGING_API_URL }}
  DATABASE_URL: ${{ secrets.STAGING_DATABASE_URL }}

# .github/workflows/deploy-production.yml
environment: production
env:
  VITE_API_URL: ${{ secrets.PRODUCTION_API_URL }}
  DATABASE_URL: ${{ secrets.PRODUCTION_DATABASE_URL }}
```

---

### 2.4 パイプラインの最適化

#### 2.4.1 テスト並列実行

**マトリックス戦略:**

```yaml
# .github/workflows/test.yml
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18, 20, 21]
        shard: [1, 2, 3, 4]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - name: Install dependencies
        run: npm ci

      - name: Run tests (shard ${{ matrix.shard }}/4)
        run: npm run test -- --shard=${{ matrix.shard }}/4
```

**Playwright並列実行:**

```yaml
jobs:
  e2e:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        shardIndex: [1, 2, 3, 4]
        shardTotal: [4]

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npx playwright install --with-deps

      - name: Run Playwright tests
        run: npx playwright test --shard=${{ matrix.shardIndex }}/${{ matrix.shardTotal }}

      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report-${{ matrix.shardIndex }}
          path: playwright-report/
```

#### 2.4.2 キャッシュ活用

**npm キャッシュ:**

```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'  # 自動的にnode_modulesをキャッシュ

- name: Install dependencies
  run: npm ci  # package-lock.jsonから正確にインストール
```

**カスタムキャッシュ:**

```yaml
- name: Cache Playwright browsers
  uses: actions/cache@v4
  with:
    path: ~/.cache/ms-playwright
    key: ${{ runner.os }}-playwright-${{ hashFiles('**/package-lock.json') }}

- name: Cache build output
  uses: actions/cache@v4
  with:
    path: |
      dist/
      .next/cache
    key: ${{ runner.os }}-build-${{ hashFiles('**/package-lock.json') }}-${{ hashFiles('**/*.ts', '**/*.tsx') }}
```

#### 2.4.3 ビルドアーティファクトの管理

**アーティファクトのアップロード:**

```yaml
- name: Build application
  run: npm run build

- name: Upload build artifacts
  uses: actions/upload-artifact@v4
  with:
    name: build-${{ github.sha }}
    path: dist/
    retention-days: 7  # 7日間保持
```

**アーティファクトのダウンロード:**

```yaml
jobs:
  build:
    # ... ビルドジョブ

  deploy:
    needs: build
    steps:
      - name: Download build artifacts
        uses: actions/download-artifact@v4
        with:
          name: build-${{ github.sha }}
          path: dist/

      - name: Deploy to server
        run: |
          scp -r dist/* user@server:/var/www/app
```

#### 2.4.4 devDependenciesを本番バンドルに含めない

**Viteの設定:**

```typescript
// vite.config.ts
import { defineConfig } from 'vite'

export default defineConfig({
  build: {
    // 本番ビルドから開発依存を除外
    rollupOptions: {
      external: [
        // 開発専用パッケージを明示的に除外
        'vitest',
        '@testing-library/react',
      ],
    },
  },
})
```

**package.json の適切な分離:**

```json
{
  "dependencies": {
    "react": "^18.2.0",
    "axios": "^1.6.0"
  },
  "devDependencies": {
    "vite": "^5.0.0",
    "vitest": "^1.0.0",
    "@testing-library/react": "^14.0.0",
    "eslint": "^8.0.0"
  }
}
```

**本番インストール（devDependencies除外）:**

```bash
# CI/CDで本番ビルド時
npm ci --production

# または
npm ci --omit=dev
```

**Dockerでの最適化:**

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# 本番イメージ（devDependencies不要）
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production  # devDependenciesをインストールしない
COPY --from=builder /app/dist ./dist
CMD ["npm", "run", "serve"]
```

---

## 3. デプロイ戦略

### 3.1 フロントエンドのみ / バックエンドのみ更新

#### 3.1.1 デプロイ順序の原則

**基本原則: バックエンド先行デプロイ**

```
推奨順序:
1. バックエンド更新をデプロイ
2. テスト・検証
3. フロントエンド更新をデプロイ
```

**理由:**
- フロントエンドは通常、バックエンドのAPI変更に依存
- バックエンド先行なら、旧フロントエンドも動作可能（後方互換性）
- 逆順だと、新フロントエンドが新APIを期待してエラー

#### 3.1.2 APIブレーキングチェンジの場合

**例外: 段階的移行が必要**

```
Phase 1: バックエンドに新旧両方のエンドポイントを追加
  - GET /v1/orders (旧)
  - GET /v2/orders (新)

Phase 2: フロントエンドを新エンドポイントに切り替え
  - 新フロントエンド: GET /v2/orders を使用

Phase 3: 旧エンドポイントの削除（一定期間後）
  - GET /v1/orders を削除
```

**バージョニング戦略:**

```typescript
// backend/src/app.module.ts
import { Module } from '@nestjs/common'
import { OrdersV1Controller } from './orders/v1/orders.controller'
import { OrdersV2Controller } from './orders/v2/orders.controller'

@Module({
  controllers: [
    OrdersV1Controller,  // /v1/orders
    OrdersV2Controller,  // /v2/orders
  ],
})
export class AppModule {}
```

```typescript
// backend/src/orders/v1/orders.controller.ts
@Controller('v1/orders')
export class OrdersV1Controller {
  // 旧API実装（後方互換性維持）
}

// backend/src/orders/v2/orders.controller.ts
@Controller('v2/orders')
export class OrdersV2Controller {
  // 新API実装
}
```

#### 3.1.3 フロントエンド変更がバックエンドに依存するか確認

**チェックリスト:**

- [ ] 新しいAPIエンドポイントを使用するか？
- [ ] APIリクエスト/レスポンス形式が変更されたか？
- [ ] 認証・認可ロジックが変更されたか？
- [ ] バックエンドの新機能に依存するか？

**依存しない場合（フロントエンドのみデプロイ可）:**
- UIデザインの変更のみ
- クライアントサイドのロジック変更
- スタイリングの調整
- 既存APIを使った機能追加

**依存する場合（バックエンド先行デプロイ必須）:**
- 新しいAPIエンドポイントの使用
- データモデルの変更
- 新しいバックエンド機能の利用

#### 3.1.4 共有コンポーネント変更時の影響範囲確認

**モノレポ構成の例:**

```
monorepo/
├── packages/
│   ├── frontend/
│   ├── backend/
│   └── shared/       ← 共有コンポーネント・型定義
│       ├── types/
│       ├── utils/
│       └── constants/
```

**影響範囲の確認:**

```bash
# 共有コンポーネントに依存するパッケージを確認
npx nx graph --affected

# 影響を受けるテストを実行
npx nx affected:test
```

**バージョニング（フロントエンド・バックエンド別管理）:**

```json
// packages/frontend/package.json
{
  "name": "@myapp/frontend",
  "version": "1.2.3"
}

// packages/backend/package.json
{
  "name": "@myapp/backend",
  "version": "2.0.1"
}

// packages/shared/package.json
{
  "name": "@myapp/shared",
  "version": "1.5.0"
}
```

**デプロイ戦略:**

```bash
# 共有コンポーネント更新時
1. @myapp/shared をバージョンアップ（1.5.0 → 1.6.0）
2. backend を更新してテスト
3. backend をデプロイ（2.0.1 → 2.0.2）
4. frontend を更新してテスト
5. frontend をデプロイ（1.2.3 → 1.2.4）
```

---

### 3.2 Blue-Green デプロイ

#### 3.2.1 Blue-Greenデプロイの概要

**概念:**

```
Blue環境（旧バージョン）   Green環境（新バージョン）
┌─────────────┐           ┌─────────────┐
│  App v1.0   │           │  App v2.0   │
│  100% traffic│           │  0% traffic │
└─────────────┘           └─────────────┘
       ↓                          ↓
   ユーザー                   テスト中

       ↓ トラフィック切り替え ↓

┌─────────────┐           ┌─────────────┐
│  App v1.0   │           │  App v2.0   │
│  0% traffic │           │  100% traffic│
└─────────────┘           └─────────────┘
    スタンバイ                ユーザー
```

#### 3.2.2 段階的トラフィック移行

**フェーズ1: 10% カナリアテスト**

```nginx
# nginx.conf
upstream blue {
  server blue.example.com:3000;
}

upstream green {
  server green.example.com:3000;
}

split_clients "${remote_addr}${http_user_agent}" $backend {
  10% green;   # 10%のトラフィックを新バージョンへ
  *   blue;    # 90%のトラフィックを旧バージョンへ
}

server {
  location / {
    proxy_pass http://$backend;
  }
}
```

**フェーズ2: 50% 分散**

```nginx
split_clients "${remote_addr}${http_user_agent}" $backend {
  50% green;
  *   blue;
}
```

**フェーズ3: 100% 移行**

```nginx
split_clients "${remote_addr}${http_user_agent}" $backend {
  100% green;  # 全トラフィックを新バージョンへ
}
```

#### 3.2.3 A/Bテストへの活用

```typescript
// Feature flag ベースのA/Bテスト
import { useFeatureFlag } from '@/hooks/useFeatureFlag'

function ProductPage() {
  const newCheckoutFlow = useFeatureFlag('new-checkout-flow')

  return (
    <div>
      {newCheckoutFlow ? (
        <NewCheckoutButton />  // 新バージョン
      ) : (
        <OldCheckoutButton />  // 旧バージョン
      )}
    </div>
  )
}
```

**LaunchDarkly を使った A/B テスト:**

```typescript
// src/featureFlags.ts
import * as LDClient from 'launchdarkly-js-client-sdk'

const client = LDClient.initialize('YOUR_CLIENT_SIDE_ID', {
  key: 'user-key',
  email: 'user@example.com',
})

export async function getFeatureFlag(flagKey: string): Promise<boolean> {
  await client.waitForInitialization()
  return client.variation(flagKey, false)
}

// 使用例
const showNewUI = await getFeatureFlag('new-ui-rollout')
```

#### 3.2.4 メリット・デメリット

**メリット:**
- ✅ **ゼロダウンタイム**: トラフィック切り替えのみ
- ✅ **即座のロールバック**: トラフィックをBlue環境に戻すだけ
- ✅ **本番環境でのテスト**: Green環境で本番データを使ったテスト可能
- ✅ **段階的移行**: 10% → 50% → 100% でリスク軽減

**デメリット:**
- ❌ **コスト大**: 2つの本番環境を同時稼働
- ❌ **データ同期の複雑さ**: データベースの移行が複雑
- ❌ **リソース消費**: 2倍のインフラコスト

**コスト軽減策:**

```yaml
# Kubernetes でのBlue-Green
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: app
    version: blue  # または green
  ports:
    - port: 80
      targetPort: 3000

---
# Blue環境のスケールダウン（トラフィック0%時）
kubectl scale deployment app-blue --replicas=1  # 最小限のインスタンス
```

---

### 3.3 Canary デプロイ

#### 3.3.1 Feature Flagを使った段階的リリース

**PostHog を使った Feature Flag:**

```typescript
// src/lib/posthog.ts
import posthog from 'posthog-js'

posthog.init('YOUR_API_KEY', {
  api_host: 'https://app.posthog.com',
})

export function useFeatureFlag(flagKey: string): boolean {
  const [isEnabled, setIsEnabled] = useState(false)

  useEffect(() => {
    posthog.onFeatureFlags(() => {
      setIsEnabled(posthog.isFeatureEnabled(flagKey))
    })
  }, [flagKey])

  return isEnabled
}
```

**使用例:**

```typescript
function CheckoutPage() {
  const newPaymentFlow = useFeatureFlag('new-payment-flow')

  if (newPaymentFlow) {
    return <NewPaymentFlow />
  }

  return <OldPaymentFlow />
}
```

**段階的ロールアウト:**

```
Week 1: 5% のユーザーに新機能を公開
Week 2: 25% のユーザーに拡大
Week 3: 50% のユーザーに拡大
Week 4: 100% のユーザーに完全展開
```

#### 3.3.2 1つの環境で新旧機能を共存

**Feature Flag 管理:**

```typescript
// src/config/featureFlags.ts
export const featureFlags = {
  newCheckoutFlow: {
    key: 'new-checkout-flow',
    defaultValue: false,
    rollout: 0.1,  // 10% rollout
  },
  enhancedSearch: {
    key: 'enhanced-search',
    defaultValue: false,
    rollout: 0.5,  // 50% rollout
  },
}

// 使用例
if (isFeatureEnabled('new-checkout-flow')) {
  // 新機能のコード
} else {
  // 旧機能のコード
}
```

#### 3.3.3 Feature Flag管理ツール

**ツール比較:**

| ツール | 特徴 | 料金 |
|--------|------|------|
| **LaunchDarkly** | 最も高機能、エンタープライズ向け | 有料（高価） |
| **Unleash** | オープンソース、セルフホスト可 | 無料/有料 |
| **PostHog** | アナリティクス統合、A/Bテスト | 無料/有料 |

**Unleash の例:**

```typescript
// src/lib/unleash.ts
import { UnleashClient } from 'unleash-proxy-client'

const unleash = new UnleashClient({
  url: 'https://unleash.example.com/api/frontend',
  clientKey: 'YOUR_CLIENT_KEY',
  appName: 'my-app',
})

unleash.start()

export function isFeatureEnabled(flagName: string): boolean {
  return unleash.isEnabled(flagName)
}
```

#### 3.3.4 Feature Flagのクリーンアップ

**重要: 古いFeature Flagは削除する**

```typescript
// ❌ 悪い例: Feature Flagが永久に残る
if (isFeatureEnabled('new-checkout-flow')) {
  // 新機能
} else {
  // 旧機能（永久に残ってしまう）
}

// ✅ 良い例: Feature Flagを完全に削除
// 新機能が100%展開されたら、Feature Flagを削除
// 旧機能のコードも削除
<NewCheckoutFlow />
```

**クリーンアップのタイミング:**
1. 新機能が100%展開された後、1-2週間様子を見る
2. 問題がなければFeature Flagを削除
3. 旧コードを削除
4. Feature Flag管理サービスからも削除

---

### 3.4 リリース管理

#### 3.4.1 セマンティックバージョニング

**MAJOR.MINOR.PATCH 形式:**

- **MAJOR (1.0.0 → 2.0.0)**: 後方互換性のない変更
- **MINOR (1.0.0 → 1.1.0)**: 後方互換性のある機能追加
- **PATCH (1.0.0 → 1.0.1)**: 後方互換性のあるバグ修正

**例:**

```
1.0.0: 初回リリース
1.0.1: バグ修正
1.1.0: 新機能追加（後方互換性あり）
2.0.0: APIブレーキングチェンジ
```

**package.json:**

```json
{
  "name": "@myapp/frontend",
  "version": "1.2.3",
  "scripts": {
    "version:patch": "npm version patch",
    "version:minor": "npm version minor",
    "version:major": "npm version major"
  }
}
```

#### 3.4.2 CHANGELOG必須

**CHANGELOG.md の形式:**

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2024-01-15

### Added
- New payment gateway integration
- Dark mode support

### Changed
- Improved checkout flow UX
- Updated dependencies

### Fixed
- Fixed order confirmation email not sending
- Resolved memory leak in product list

### Deprecated
- Old payment API (will be removed in 2.0.0)

## [1.1.0] - 2024-01-01

### Added
- User profile page
- Order history

## [1.0.0] - 2023-12-15

### Added
- Initial release
- Basic ordering functionality
```

**自動生成:**

```bash
# conventional-changelog を使用
npm install --save-dev conventional-changelog-cli

# package.json
{
  "scripts": {
    "changelog": "conventional-changelog -p angular -i CHANGELOG.md -s"
  }
}

# 実行
npm run changelog
```

#### 3.4.3 フリーズ期間の考慮

**業界別フリーズ期間:**

| 業界 | フリーズ期間 | 理由 |
|------|-------------|------|
| **Eコマース** | 11月〜12月 | ブラックフライデー、年末商戦 |
| **金融** | 四半期末、年末 | 決算処理、監査対応 |
| **教育** | 新学期前 | 登録ピーク |
| **エンタメ** | イベント期間 | 大型イベント開催時 |

**フリーズ期間中の対応:**

```
許可される変更:
- ✅ 緊急バグ修正（ホットフィックス）
- ✅ セキュリティパッチ
- ✅ パフォーマンス改善（クリティカルな場合）

禁止される変更:
- ❌ 新機能のリリース
- ❌ UIの大幅な変更
- ❌ データベーススキーマ変更
```

#### 3.4.4 リリース日から逆算して計画

**リリース計画の例（4週間前から）:**

```
Week 1 (4週間前):
- 要件定義完了
- 設計ドキュメント作成
- テスト計画策定

Week 2 (3週間前):
- 開発開始
- ユニットテスト作成
- デイリーレビュー

Week 3 (2週間前):
- 開発完了（開発チームのデッドライン）
- E2Eテスト実行
- ステージング環境デプロイ

Week 4 (1週間前):
- QA完了（Productチームのデッドライン）
- ドキュメント更新
- リリースノート作成
- 本番デプロイ準備

Release Day:
- 本番デプロイ
- モニタリング強化
- ロールバック準備
```

#### 3.4.5 開発チーム内のデッドラインとProductチームのデッドラインを分ける

**デッドラインの分離:**

```
開発チームのデッドライン:  リリース日の2週間前
  ↓
Productチームのデッドライン: リリース日の1週間前
  ↓
実際のリリース日
```

**理由:**
- 開発完了後にバグが見つかる可能性
- QA時間の確保
- ドキュメント作成・レビュー
- 予期せぬ問題への対応バッファ

**コミュニケーション例:**

```
開発チーム:  「1月15日に開発完了します」
Productチーム: 「1月22日にQA完了、1月29日にリリースします」
```

---

## 4. ロールバック戦略

デプロイ後に問題が発生した場合、迅速にロールバックする必要があります。

### 4.1 旧アーティファクトの再デプロイ

**最も安全で高速な方法**

#### 4.1.1 Gitタグから再デプロイ

```bash
# 現在のタグを確認
git tag -l

# 旧バージョンにチェックアウト
git checkout v1.2.3

# 再ビルド・再デプロイ
npm ci
npm run build
npm run deploy
```

**GitHub Actions での自動化:**

```yaml
# .github/workflows/rollback.yml
name: Rollback to Previous Version

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version tag to rollback to'
        required: true
        default: 'v1.0.0'

jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout version ${{ github.event.inputs.version }}
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.inputs.version }}

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build application
        run: npm run build

      - name: Deploy to production
        run: npm run deploy
        env:
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}

      - name: Notify team
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Rolled back to ${{ github.event.inputs.version }}'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

#### 4.1.2 ビルドストレージから再デプロイ

**ビルドアーティファクトの保存:**

```yaml
# .github/workflows/build.yml
- name: Upload build to S3
  run: |
    aws s3 cp dist/ s3://my-builds/${{ github.sha }}/ --recursive
    aws s3 cp dist/ s3://my-builds/latest/ --recursive

- name: Tag build with version
  run: |
    aws s3 cp dist/ s3://my-builds/${{ github.ref_name }}/ --recursive
```

**ロールバック:**

```bash
# 旧ビルドをダウンロード
aws s3 sync s3://my-builds/v1.2.3/ ./dist/

# 再デプロイ
npm run deploy
```

---

### 4.2 git revert

特定のコミットの変更を打ち消す方法。

#### 4.2.1 単一コミットのrevert

```bash
# 問題のあるコミットを特定
git log --oneline

# 特定のコミットをrevert
git revert abc123

# revertコミットを作成
git commit -m "Revert 'Add new feature'"

# デプロイ
git push origin main
```

**メリット:**
- ✅ 履歴が残る（トレーサビリティ）
- ✅ 安全（既存のコミットは変更されない）
- ✅ 共有ブランチで使用可能

**デメリット:**
- ❌ マージコミットのrevertは複雑
- ❌ 複数コミットのrevertは競合しやすい

#### 4.2.2 複数コミットのrevert（注意）

```bash
# 範囲指定でrevert（古い順に適用）
git revert abc123..xyz789

# または個別にrevert
git revert xyz789  # 最新のコミットから
git revert abc456
git revert abc123
```

**注意点:**
- 複数コミットをrevertすると競合が発生しやすい
- revertの順序が重要（最新から古い順）
- 手動での競合解決が必要な場合が多い

---

### 4.3 git reset

コミット履歴を巻き戻す方法（危険性あり）。

#### 4.3.1 resetの種類

**--soft: アンコミット、ステージ維持**

```bash
git reset --soft HEAD~1

# 効果:
# - 最新のコミットを取り消す
# - 変更はステージに残る
# - 再度コミット可能
```

**--mixed: アンコミット、アンステージ（デフォルト）**

```bash
git reset --mixed HEAD~1
# または
git reset HEAD~1

# 効果:
# - 最新のコミットを取り消す
# - 変更はワーキングツリーに残る（アンステージ）
# - 再度 git add が必要
```

**--hard: アンコミット、変更削除（危険）**

```bash
git reset --hard HEAD~1

# 効果:
# - 最新のコミットを取り消す
# - 変更は完全に削除される
# - ⚠️ 復元不可能（危険）
```

#### 4.3.2 注意事項

**⚠️ git reset の危険性:**

```bash
# ❌ 絶対にやってはいけない
git push --force origin main

# 理由:
# - 他の開発者の履歴が破壊される
# - CI/CDパイプラインが混乱
# - デプロイ履歴が失われる
```

**安全な使用方法:**

```bash
# ローカルブランチでのみ使用
git checkout feature-branch
git reset --hard HEAD~1

# 共有ブランチでは git revert を使用
git checkout main
git revert abc123
```

#### 4.3.3 複数コミットへの影響

```bash
# 3つ前のコミットまで戻す
git reset --hard HEAD~3

# 効果:
# - 最新3つのコミットが削除される
# - 変更も完全に削除
# - ⚠️ 非常に危険
```

---

### 4.4 ホットフィックス

ロールフォワード戦略（前進して修正）。

#### 4.4.1 ホットフィックスプロセス

```
1. インシデント発生
   ↓
2. 根本原因の特定
   ↓
3. ホットフィックスブランチ作成
   ↓
4. パッチ作成
   ↓
5. 簡易テスト
   ↓
6. PR作成（簡略化されたレビュー）
   ↓
7. 緊急デプロイ
   ↓
8. 事後レビュー（詳細レビューを後で実施）
```

**ホットフィックスブランチの作成:**

```bash
# 本番タグから分岐
git checkout v1.2.3
git checkout -b hotfix/critical-bug

# 修正を実施
# ... コード修正 ...

# コミット
git add .
git commit -m "hotfix: Fix critical payment bug"

# 緊急デプロイ
git tag v1.2.4
git push origin v1.2.4
```

#### 4.4.2 ホットフィックスプロトコル

**通常時のレビュー要件:**
- 2人以上のレビュー承認必須
- 全テストスイート実行
- QA承認

**ホットフィックス時のレビュー要件緩和:**
- 1人のレビュー承認で可（事後に追加レビュー）
- 最小限のテスト実行
- QA承認スキップ可（事後確認）

**GitHub Actions でのホットフィックスワークフロー:**

```yaml
# .github/workflows/hotfix.yml
name: Hotfix Deployment

on:
  push:
    branches:
      - 'hotfix/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run critical tests only
        run: npm run test:critical

      - name: Build
        run: npm run build

      - name: Deploy to production
        run: npm run deploy
        env:
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}

      - name: Notify incident channel
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Hotfix deployed: ${{ github.ref }}'
          webhook_url: ${{ secrets.INCIDENT_SLACK_WEBHOOK }}
```

#### 4.4.3 複数人でのグループコール検証

**ホットフィックス検証プロセス:**

```
1. Zoom/Teams でインシデントコール開始
   ↓
2. スクリーンシェアで修正内容を共有
   ↓
3. 複数人でコードレビュー
   ↓
4. ステージング環境で動作確認
   ↓
5. 本番デプロイ実行
   ↓
6. 全員で本番環境の動作を監視
```

**検証チェックリスト:**

- [ ] バグの再現確認
- [ ] 修正内容のレビュー
- [ ] 影響範囲の確認
- [ ] ステージング環境での動作確認
- [ ] ロールバックプランの準備
- [ ] 本番デプロイ実行
- [ ] 本番環境での動作確認
- [ ] モニタリング（エラーレート、レスポンスタイム）
- [ ] 事後レポート作成

---

## 5. コンテナ化

### 5.1 Dockerの基礎

#### 5.1.1 Dockerfileの基本構成

**Viteアプリケーションの例:**

```dockerfile
# ベースイメージ（Alpine Linuxで軽量化）
FROM node:20-alpine AS builder

# 作業ディレクトリ設定
WORKDIR /app

# package.json と package-lock.json をコピー
COPY package*.json ./

# 依存関係のインストール
RUN npm ci

# ソースコードをコピー
COPY . .

# ビルド
RUN npm run build

# 本番用イメージ
FROM node:20-alpine

WORKDIR /app

# 本番依存関係のみインストール
COPY package*.json ./
RUN npm ci --production

# ビルド成果物をコピー
COPY --from=builder /app/dist ./dist

# ポート公開
EXPOSE 8080

# 起動コマンド
CMD ["npm", "run", "preview"]
```

**NestJS バックエンドの例:**

```dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --production

COPY --from=builder /app/dist ./dist

EXPOSE 3000

CMD ["node", "dist/main.js"]
```

#### 5.1.2 マルチステージビルド

**マルチステージビルドのメリット:**
- ✅ イメージサイズの削減（ビルドツールを含めない）
- ✅ セキュリティ向上（本番に開発ツール不要）
- ✅ ビルド時間の短縮（キャッシュ活用）

**最適化の例:**

```dockerfile
# ステージ1: 依存関係のインストール
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

# ステージ2: ビルド
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# ステージ3: 本番実行
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV production

# 本番依存のみコピー
COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package*.json ./

EXPOSE 3000
CMD ["node", "dist/main.js"]
```

#### 5.1.3 .dockerignore

```.dockerignore
node_modules
npm-debug.log
dist
.git
.gitignore
.env
.env.local
.vscode
.idea
*.md
coverage
.cache
```

---

### 5.2 開発環境の統一

#### 5.2.1 docker-compose.yml

**フルスタックアプリケーションの例:**

```yaml
version: '3.8'

services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
    ports:
      - "5173:5173"
    volumes:
      - ./frontend:/app
      - /app/node_modules
    environment:
      - VITE_API_URL=http://localhost:3000
    depends_on:
      - backend

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    volumes:
      - ./backend:/app
      - /app/node_modules
    environment:
      - DATABASE_URL=postgresql://user:password@db:5432/myapp
      - JWT_SECRET=dev-secret
    depends_on:
      - db

  db:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=myapp
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

**開発環境起動:**

```bash
# すべてのサービスを起動
docker-compose up

# バックグラウンドで起動
docker-compose up -d

# ログ確認
docker-compose logs -f backend

# 停止
docker-compose down

# ボリュームも削除
docker-compose down -v
```

#### 5.2.2 「自分のマシンでは動く」問題の解消

**Before: ローカル環境依存**

```
開発者A: Node.js 18, macOS
開発者B: Node.js 20, Windows
開発者C: Node.js 21, Linux

結果: 動作が異なる、環境構築に時間がかかる
```

**After: Docker で統一**

```
全員: Docker + docker-compose
結果: 同一環境、即座にセットアップ完了
```

**新規メンバーのオンボーディング:**

```bash
# リポジトリクローン
git clone https://github.com/company/app.git
cd app

# Docker コンテナ起動（環境構築完了）
docker-compose up

# すぐに開発開始可能
```

---

### 5.3 本番環境との一貫性

#### 5.3.1 開発環境と本番環境の設定分離

**Dockerfile.dev（開発用）:**

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install  # devDependencies も含む

COPY . .

EXPOSE 5173

# ホットリロード有効
CMD ["npm", "run", "dev", "--", "--host"]
```

**Dockerfile（本番用）:**

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci  # 厳密な依存関係
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production  # devDependencies除外
COPY --from=builder /app/dist ./dist
EXPOSE 8080
CMD ["npm", "run", "preview"]
```

#### 5.3.2 Vite設定のポート・ホスト設定

**vite.config.ts:**

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',  // Docker内で外部アクセス許可
    port: 5173,
    watch: {
      usePolling: true,  // Docker on Windows/Mac での HMR 有効化
    },
  },
  preview: {
    host: '0.0.0.0',
    port: 8080,
  },
})
```

---

## 6. 統合テスト

### 6.1 フルスタック接続チェック（バックエンド）

本番デプロイ前に確認すべき項目のチェックリスト。

#### 1. データベース接続確認

```bash
# pgAdmin / MySQL Workbench / MongoDB Compass で確認
# - 接続成功するか
# - テーブル・スキーマが正しいか
# - インデックスが設定されているか

# CLI での確認
psql postgresql://user:password@hostname:5432/dbname

# NestJS での接続テスト
npm run test:e2e -- --grep "Database connection"
```

#### 2. 本番DB接続文字列・認証情報確認

```typescript
// src/config/database.ts
import { TypeOrmModuleOptions } from '@nestjs/typeorm'

export const databaseConfig: TypeOrmModuleOptions = {
  type: 'postgres',
  url: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  synchronize: false,  // 本番では絶対にfalse
  logging: process.env.NODE_ENV === 'development',
}

// 起動時の検証
if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL is not set')
}
```

#### 3. シードデータ投入・クエリテスト

```bash
# シードデータ投入
npm run seed:prod

# クエリテスト
npm run db:test-queries
```

```typescript
// scripts/test-queries.ts
import { DataSource } from 'typeorm'
import { databaseConfig } from '../src/config/database'

async function testQueries() {
  const dataSource = new DataSource(databaseConfig)
  await dataSource.initialize()

  // テストクエリ
  const orders = await dataSource.query('SELECT * FROM orders LIMIT 10')
  console.log('Orders:', orders.length)

  const users = await dataSource.query('SELECT COUNT(*) FROM users')
  console.log('Users count:', users[0].count)

  await dataSource.destroy()
}

testQueries()
```

#### 4. 環境変数の正しい値設定

```bash
# 環境変数チェックスクリプト
npm run check:env
```

```typescript
// scripts/check-env.ts
import { z } from 'zod'

const requiredEnvVars = z.object({
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  API_URL: z.string().url(),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  SENDGRID_API_KEY: z.string().startsWith('SG.'),
})

try {
  requiredEnvVars.parse(process.env)
  console.log('✅ All environment variables are valid')
} catch (error) {
  console.error('❌ Invalid environment variables:', error)
  process.exit(1)
}
```

#### 5. SSL証明書・セキュリティ設定

```typescript
// src/main.ts
import { NestFactory } from '@nestjs/core'
import { AppModule } from './app.module'
import helmet from 'helmet'

async function bootstrap() {
  const app = await NestFactory.create(AppModule)

  // セキュリティヘッダー
  app.use(helmet())

  // CORS設定
  app.enableCors({
    origin: process.env.FRONTEND_URL,
    credentials: true,
  })

  // HTTPS リダイレクト（本番のみ）
  if (process.env.NODE_ENV === 'production') {
    app.use((req, res, next) => {
      if (req.header('x-forwarded-proto') !== 'https') {
        res.redirect(`https://${req.header('host')}${req.url}`)
      } else {
        next()
      }
    })
  }

  await app.listen(3000)
}
bootstrap()
```

#### 6. ロギング・モニタリング・アラート設定

```typescript
// src/logging/logger.ts
import { createLogger, format, transports } from 'winston'
import DailyRotateFile from 'winston-daily-rotate-file'

export const logger = createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: format.combine(
    format.timestamp(),
    format.errors({ stack: true }),
    format.json()
  ),
  transports: [
    // コンソール出力
    new transports.Console({
      format: format.combine(format.colorize(), format.simple()),
    }),

    // ファイル出力（日次ローテーション）
    new DailyRotateFile({
      filename: 'logs/app-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxSize: '20m',
      maxFiles: '14d',
    }),

    // エラーログ専用
    new DailyRotateFile({
      filename: 'logs/error-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      level: 'error',
      maxSize: '20m',
      maxFiles: '30d',
    }),
  ],
})
```

#### 7. Postmanでのエンドポイント動作確認

```json
// postman-collection.json
{
  "info": {
    "name": "Production API Tests",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Health Check",
      "request": {
        "method": "GET",
        "url": "{{baseUrl}}/health"
      },
      "event": [
        {
          "listen": "test",
          "script": {
            "exec": [
              "pm.test('Status code is 200', function () {",
              "  pm.response.to.have.status(200);",
              "});",
              "pm.test('Response has status OK', function () {",
              "  var jsonData = pm.response.json();",
              "  pm.expect(jsonData.status).to.eql('ok');",
              "});"
            ]
          }
        }
      ]
    },
    {
      "name": "Create Order",
      "request": {
        "method": "POST",
        "url": "{{baseUrl}}/orders",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          },
          {
            "key": "Authorization",
            "value": "Bearer {{authToken}}"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\"items\": [\"Coffee\"], \"total\": 5.00}"
        }
      }
    }
  ]
}
```

```bash
# Newman（CLI）で実行
npx newman run postman-collection.json \
  --environment production-env.json \
  --reporters cli,json
```

#### 8. サードパーティサービスの本番クレデンシャル確認

```typescript
// scripts/test-integrations.ts
import Stripe from 'stripe'
import sgMail from '@sendgrid/mail'

async function testIntegrations() {
  // Stripe 接続テスト
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY)
  try {
    const balance = await stripe.balance.retrieve()
    console.log('✅ Stripe connected:', balance)
  } catch (error) {
    console.error('❌ Stripe connection failed:', error)
  }

  // SendGrid 接続テスト
  sgMail.setApiKey(process.env.SENDGRID_API_KEY)
  try {
    await sgMail.send({
      to: 'test@example.com',
      from: 'noreply@example.com',
      subject: 'Test Email',
      text: 'Connection test',
    })
    console.log('✅ SendGrid connected')
  } catch (error) {
    console.error('❌ SendGrid connection failed:', error)
  }
}

testIntegrations()
```

#### 9. バックグラウンドジョブ・Cronジョブの動作確認

```typescript
// src/tasks/tasks.service.ts
import { Injectable } from '@nestjs/common'
import { Cron, CronExpression } from '@nestjs/schedule'

@Injectable()
export class TasksService {
  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async handleDailyCleanup() {
    console.log('Running daily cleanup...')
    // クリーンアップロジック
  }

  @Cron('0 */6 * * *')  // 6時間ごと
  async handleDataSync() {
    console.log('Running data sync...')
    // 同期ロジック
  }
}
```

**手動テスト:**

```bash
# Cronジョブの手動実行
npm run cron:test-daily-cleanup
npm run cron:test-data-sync
```

#### 10. インシデント・ロールバック計画の策定

**インシデントプレイブックの作成:**

```markdown
# Incident Playbook

## 緊急連絡先
- オンコールエンジニア: +81-xxx-xxxx
- DevOpsリード: @john-doe
- インシデントSlackチャネル: #incident-response

## ロールバック手順
1. GitHub Actions から "Rollback" ワークフローを実行
2. バージョンタグを選択（例: v1.2.3）
3. 実行完了を確認（約5分）
4. 本番環境の動作確認

## エスカレーションフロー
Severity 1 (Critical): すぐにCTOに報告
Severity 2 (High): 30分以内にDevOpsリードに報告
Severity 3 (Medium): 次の営業日に報告
```

---

### 6.2 フルスタック接続チェック（フロントエンド）

#### 1. CDN設定・キャッシュバスティング

```typescript
// vite.config.ts
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        // ファイル名にハッシュを含める（キャッシュバスティング）
        entryFileNames: 'assets/[name].[hash].js',
        chunkFileNames: 'assets/[name].[hash].js',
        assetFileNames: 'assets/[name].[hash].[ext]',
      },
    },
  },
})
```

**Vercel/Netlifyでの自動CDN設定:**

```json
// vercel.json
{
  "headers": [
    {
      "source": "/assets/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    },
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        }
      ]
    }
  ]
}
```

#### 2. バンドル最適化（ミニファイ・圧縮）

```typescript
// vite.config.ts
export default defineConfig({
  build: {
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,  // console.log削除
        drop_debugger: true,
      },
    },
    cssCodeSplit: true,
    sourcemap: false,  // 本番ではsourcemap無効
  },
})
```

**バンドルサイズ分析:**

```bash
# rollup-plugin-visualizer でバンドル分析
npm install --save-dev rollup-plugin-visualizer
```

```typescript
import { visualizer } from 'rollup-plugin-visualizer'

export default defineConfig({
  plugins: [
    visualizer({
      open: true,
      gzipSize: true,
      brotliSize: true,
    }),
  ],
})
```

#### 3. ロギング・モニタリング・アラート確認

```typescript
// src/monitoring/sentry.ts
import * as Sentry from '@sentry/react'

Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.MODE,
  tracesSampleRate: 1.0,
  integrations: [
    new Sentry.BrowserTracing(),
    new Sentry.Replay(),
  ],
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
})
```

#### 4. 全対象ブラウザでの動作確認

**BrowserStack / Sauce Labs でのクロスブラウザテスト:**

```typescript
// playwright.config.ts
export default defineConfig({
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
    { name: 'Mobile Chrome', use: { ...devices['Pixel 5'] } },
    { name: 'Mobile Safari', use: { ...devices['iPhone 13'] } },
    { name: 'IE 11', use: { ...devices['Desktop Edge'] } },  // レガシーサポート
  ],
})
```

#### 5. フォーム動作確認

```typescript
// e2e/forms.spec.ts
test('submits contact form', async ({ page }) => {
  await page.goto('/contact')

  await page.getByLabel('Name').fill('John Doe')
  await page.getByLabel('Email').fill('john@example.com')
  await page.getByLabel('Message').fill('Test message')

  await page.getByRole('button', { name: 'Send' }).click()

  await expect(page.getByText('Message sent successfully')).toBeVisible()
})

test('shows validation errors', async ({ page }) => {
  await page.goto('/contact')
  await page.getByRole('button', { name: 'Send' }).click()

  await expect(page.getByText('Name is required')).toBeVisible()
  await expect(page.getByText('Email is required')).toBeVisible()
})
```

#### 6. フロントエンド→DB変更の確認

```typescript
// e2e/data-persistence.spec.ts
test('order is saved to database', async ({ page }) => {
  await page.goto('/orders/new')

  await page.getByLabel('Item').fill('Coffee')
  await page.getByRole('button', { name: 'Create Order' }).click()

  await expect(page.getByText('Order created')).toBeVisible()

  // データベース確認（バックエンドAPIを通じて）
  const response = await page.request.get('/api/orders/latest')
  const order = await response.json()

  expect(order.items).toContain('Coffee')
})
```

#### 7. ドキュメント・アーキテクチャ図更新

```markdown
# Architecture Documentation

## System Architecture

```mermaid
graph TD
    A[Client Browser] -->|HTTPS| B[CDN/Vercel]
    B -->|API Requests| C[Backend/NestJS]
    C -->|Query| D[PostgreSQL]
    C -->|Auth| E[Auth0]
    C -->|Payment| F[Stripe]
    C -->|Email| G[SendGrid]
```

## Deployment Flow

```mermaid
graph LR
    A[Git Push] --> B[GitHub Actions]
    B --> C{Tests Pass?}
    C -->|Yes| D[Build]
    C -->|No| E[Notify Slack]
    D --> F[Deploy to Staging]
    F --> G{Manual Approval}
    G -->|Approved| H[Deploy to Production]
    G -->|Rejected| E
```
```

---

### 6.3 本番環境での確認

#### 1. テストアカウントでの確認

```typescript
// scripts/create-test-account.ts
import { PrismaClient } from '@prisma/client'
import * as bcrypt from 'bcrypt'

const prisma = new PrismaClient()

async function createTestAccount() {
  const testUser = await prisma.user.create({
    data: {
      email: 'test-production@example.com',
      password: await bcrypt.hash('test-password-123', 10),
      role: 'customer',
      isTestAccount: true,  // テストアカウントフラグ
    },
  })

  console.log('Test account created:', testUser.email)
}

createTestAccount()
```

**⚠️ 実ユーザーアカウント使用禁止の理由:**
- データ汚染（テストデータと実データの混在）
- プライバシー侵害
- 予期せぬ副作用（決済、通知送信）

#### 2. タイムゾーン処理の確認

```typescript
// src/utils/timezone.ts
import { format, utcToZonedTime, zonedTimeToUtc } from 'date-fns-tz'

// サーバー: すべてUTCで保存
export function saveTimestamp(localTime: Date, userTimezone: string): Date {
  return zonedTimeToUtc(localTime, userTimezone)
}

// クライアント: ユーザーのタイムゾーンで表示
export function displayTimestamp(utcTime: Date, userTimezone: string): string {
  const zonedTime = utcToZonedTime(utcTime, userTimezone)
  return format(zonedTime, 'yyyy-MM-dd HH:mm:ss zzz', { timeZone: userTimezone })
}
```

**UTC推奨の理由:**
- グローバル展開時の混乱回避
- サマータイム対応が容易
- データの一貫性確保

#### 3. セキュリティテスト

**SQLインジェクションテスト:**

```bash
# 悪意のある入力を試す
curl -X POST https://api.example.com/orders \
  -H "Content-Type: application/json" \
  -d '{"item": "Coffee\"; DROP TABLE orders; --"}'

# 期待される結果: エラーメッセージ、SQL実行されない
```

**トークン操作テスト:**

```bash
# 不正なトークンでアクセス
curl -X GET https://api.example.com/orders \
  -H "Authorization: Bearer invalid-token-12345"

# 期待される結果: 401 Unauthorized
```

**CSRF対策確認:**

```typescript
// src/main.ts
import * as csurf from 'csurf'

app.use(csurf({ cookie: true }))
```

#### 4. Feature Flagの状態確認

```typescript
// src/featureFlags/check.ts
import { unleash } from '@/lib/unleash'

async function checkFeatureFlags() {
  const flags = [
    'new-checkout-flow',
    'enhanced-search',
    'dark-mode',
  ]

  for (const flag of flags) {
    const isEnabled = unleash.isEnabled(flag)
    const variant = unleash.getVariant(flag)

    console.log(`${flag}: ${isEnabled ? 'ON' : 'OFF'}`)
    if (variant) {
      console.log(`  Variant: ${variant.name}`)
    }
  }
}

checkFeatureFlags()
```

---

## 7. モニタリングとインシデント対応

### 7.1 モニタリングツール設定

#### 7.1.1 Winston ロガー統合

```typescript
// src/logging/winston.config.ts
import { createLogger, format, transports } from 'winston'
import DailyRotateFile from 'winston-daily-rotate-file'

export const logger = createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: format.combine(
    format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    format.errors({ stack: true }),
    format.splat(),
    format.json()
  ),
  defaultMeta: {
    service: 'backend-api',
    environment: process.env.NODE_ENV,
  },
  transports: [
    // Console
    new transports.Console({
      format: format.combine(format.colorize(), format.simple()),
    }),

    // Daily rotate files
    new DailyRotateFile({
      filename: 'logs/app-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      zippedArchive: true,
      maxSize: '20m',
      maxFiles: '14d',
    }),

    new DailyRotateFile({
      filename: 'logs/error-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      level: 'error',
      zippedArchive: true,
      maxSize: '20m',
      maxFiles: '30d',
    }),
  ],
})

// NestJS統合
export class WinstonLogger implements LoggerService {
  log(message: string, context?: string) {
    logger.info(message, { context })
  }

  error(message: string, trace?: string, context?: string) {
    logger.error(message, { trace, context })
  }

  warn(message: string, context?: string) {
    logger.warn(message, { context })
  }

  debug(message: string, context?: string) {
    logger.debug(message, { context })
  }
}
```

**使用例:**

```typescript
// src/orders/orders.service.ts
import { logger } from '@/logging/winston.config'

@Injectable()
export class OrdersService {
  async createOrder(dto: CreateOrderDto) {
    logger.info('Creating order', { dto })

    try {
      const order = await this.repository.save(dto)
      logger.info('Order created successfully', { orderId: order.id })
      return order
    } catch (error) {
      logger.error('Failed to create order', { error: error.message, stack: error.stack, dto })
      throw error
    }
  }
}
```

#### 7.1.2 Datadog / Sentry統合

**Sentry（フロントエンド）:**

```typescript
// src/monitoring/sentry.ts
import * as Sentry from '@sentry/react'
import { BrowserTracing } from '@sentry/tracing'

Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.MODE,
  integrations: [
    new BrowserTracing(),
    new Sentry.Replay({
      maskAllText: false,
      blockAllMedia: false,
    }),
  ],
  tracesSampleRate: 1.0,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,

  beforeSend(event, hint) {
    // テストアカウントのエラーをフィルタ
    if (event.user?.email?.includes('test-production')) {
      return null
    }
    return event
  },
})

// カスタムコンテキスト
export function setSentryUser(user: User) {
  Sentry.setUser({
    id: user.id,
    email: user.email,
    username: user.name,
  })
}

export function setSentryContext(key: string, data: any) {
  Sentry.setContext(key, data)
}
```

**Datadog（バックエンド）:**

```typescript
// src/monitoring/datadog.ts
import * as tracer from 'dd-trace'

tracer.init({
  service: 'backend-api',
  env: process.env.NODE_ENV,
  logInjection: true,
  analytics: true,
})

// カスタムメトリクス
export function recordMetric(name: string, value: number, tags?: Record<string, string>) {
  tracer.dogstatsd.gauge(name, value, tags)
}

// 使用例
recordMetric('orders.created', 1, { region: 'us-east-1' })
recordMetric('orders.total_amount', order.total, { currency: 'USD' })
```

---

### 7.2 アラート設定

#### 7.2.1 エラー率閾値

```yaml
# datadog-monitors.yml
monitors:
  - name: "High Error Rate"
    type: metric alert
    query: "avg(last_5m):sum:trace.express.request.errors{env:production} / sum:trace.express.request.hits{env:production} > 0.05"
    message: |
      Error rate is above 5% for the last 5 minutes.
      @slack-#alerts @pagerduty
    tags:
      - "team:backend"
      - "severity:critical"
```

#### 7.2.2 レスポンスタイム閾値

```yaml
- name: "Slow API Response"
  type: metric alert
  query: "avg(last_5m):avg:trace.express.request.duration{env:production} > 2000"
  message: |
    Average API response time is above 2 seconds.
    @slack-#alerts
  tags:
    - "team:backend"
    - "severity:warning"
```

#### 7.2.3 DDoS検出

```typescript
// src/middleware/rate-limit.ts
import rateLimit from 'express-rate-limit'
import RedisStore from 'rate-limit-redis'
import { createClient } from 'redis'

const redisClient = createClient({
  url: process.env.REDIS_URL,
})

export const apiLimiter = rateLimit({
  store: new RedisStore({
    client: redisClient,
  }),
  windowMs: 15 * 60 * 1000,  // 15分
  max: 100,  // 最大100リクエスト
  message: 'Too many requests from this IP',
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn('Rate limit exceeded', {
      ip: req.ip,
      path: req.path,
    })
    res.status(429).json({ error: 'Too many requests' })
  },
})

// 使用例
app.use('/api/', apiLimiter)
```

#### 7.2.4 リソース使用率

```yaml
- name: "High CPU Usage"
  type: metric alert
  query: "avg(last_10m):avg:system.cpu.user{env:production} > 80"
  message: |
    CPU usage is above 80% for the last 10 minutes.
    @slack-#alerts @pagerduty
  tags:
    - "team:devops"
    - "severity:critical"

- name: "High Memory Usage"
  type: metric alert
  query: "avg(last_10m):avg:system.mem.used{env:production} / avg:system.mem.total{env:production} > 0.90"
  message: |
    Memory usage is above 90%.
    @slack-#alerts
  tags:
    - "team:devops"
    - "severity:warning"
```

---

### 7.3 インシデントプレイブック7段階

#### 段階1: 検出

**モニタリング・アラートで認識:**
- Datadog/Sentryアラート
- ユーザーからの報告
- 自動ヘルスチェック失敗

```typescript
// src/health/health.controller.ts
import { Controller, Get } from '@nestjs/common'
import { HealthCheck, HealthCheckService, TypeOrmHealthIndicator } from '@nestjs/terminus'

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
    ])
  }
}
```

#### 段階2: コミュニケーション設定

**専用Slack/Teamsチャネル:**

```
#incident-2024-01-15-payment-failure

参加者:
- @john-doe (Incident Commander)
- @jane-smith (Backend Lead)
- @bob-wilson (DevOps)
- @alice-brown (Product Manager)

初期メッセージ:
「決済処理に問題が発生しています。影響範囲を調査中です。」
```

#### 段階3: 影響・重大度判定

**Severity定義:**

| Severity | 定義 | 例 |
|----------|------|-----|
| **S1 (Critical)** | サービス全体停止 | 全ユーザーがアクセス不可 |
| **S2 (High)** | 主要機能停止 | 決済処理が失敗 |
| **S3 (Medium)** | 一部機能に問題 | 検索が遅い |
| **S4 (Low)** | 軽微な問題 | UIの表示崩れ |

**影響範囲の特定:**
- 影響を受けているユーザー数
- ダウンしているサービス
- データ損失の有無

#### 段階4: ユーザー通知

**サポートチーム経由:**

```
件名: [障害通知] 決済処理の一時的な問題について

お客様各位

現在、決済処理において一時的な問題が発生しております。
現在、復旧作業を進めており、15:00頃の復旧を見込んでおります。

ご不便をおかけし、誠に申し訳ございません。

株式会社Example カスタマーサポート
```

#### 段階5: チーム通知

**関連エンジニアリングチーム:**

```
@channel 緊急インシデント発生

Severity: S2 (High)
影響: 決済処理が失敗（過去30分で50件の失敗）
原因: Stripe APIのタイムアウト（調査中）
担当: @jane-smith (Backend Lead)
インシデントチャネル: #incident-2024-01-15-payment-failure

関係者は即座にチャネルに参加してください。
```

#### 段階6: 責任分担

**インシデントコール:**
- **Incident Commander**: 全体調整、意思決定
- **Tech Lead**: 技術調査、修正実装
- **DevOps**: インフラ確認、ロールバック準備
- **Product Manager**: ユーザー影響評価、コミュニケーション
- **スクリーンシェアリング**: 全員で状況を共有

#### 段階7: 解決

**解決フロー:**

```
1. 修正コード作成
   ↓
2. ステージング環境でテスト
   ↓
3. 本番デプロイ
   ↓
4. 検証（エラーレート、レスポンスタイム）
   ↓
5. ユーザー通知（復旧完了）
   ↓
6. ポストモーテム作成
```

---

### 7.4 ステークホルダーコミュニケーション

#### 7.4.1 10-15分ごとの進捗報告

**報告テンプレート:**

```
【進捗報告 #3】 14:45

現在の状況:
- 根本原因を特定しました（Stripe APIのレート制限）
- 修正を実装中（リトライロジック追加）

次のステップ:
- 15:00 ステージング環境でテスト
- 15:15 本番デプロイ予定

影響:
- 過去1時間で約80件の決済失敗
- 現在も新規決済は失敗中
```

#### 7.4.2 技術詳細ではなく影響とタイムラインを伝える

**❌ 悪い例（技術詳細すぎ）:**
```
「Stripe APIのrate_limit_errorが発生し、exponential backoffのリトライロジックを実装しています。」
```

**✅ 良い例（影響とタイムライン）:**
```
「決済処理が一時的に失敗しています。15:00までに復旧予定です。」
```

#### 7.4.3 解決前に「修正済み」と言わない

**❌ 悪い例:**
```
「修正しました！」（デプロイ直後、検証前）
```

**✅ 良い例:**
```
「修正をデプロイしました。現在、動作を確認中です。」
→ 5分後 →
「検証完了しました。決済処理が正常に動作しています。」
```

---

### 7.5 ブレームレスポストモーテム

#### 7.5.1 個人を責めない

**❌ 悪い例:**
```
「John が間違ったコードをデプロイしたため、障害が発生しました。」
```

**✅ 良い例:**
```
「デプロイ前のテストプロセスに不足があり、本番環境で問題が発生しました。」
```

#### 7.5.2 プロセスの失敗に焦点

**根本原因の例:**
- テストカバレッジ不足
- コードレビュープロセスの欠陥
- モニタリング設定の不備
- デプロイ手順の不明確さ

#### 7.5.3 タイムラインの記録

```markdown
# Postmortem: Payment Processing Failure (2024-01-15)

## Timeline (UTC)

- **13:00** - ユーザーから決済失敗の報告
- **13:05** - Datadogアラート発火（エラーレート5%超過）
- **13:10** - インシデントチャネル作成、チーム招集
- **13:15** - Stripeログ確認、レート制限が原因と判明
- **13:30** - リトライロジック実装開始
- **14:00** - ステージング環境でテスト完了
- **14:15** - 本番デプロイ
- **14:20** - 動作確認完了、インシデント解決
- **14:30** - ユーザー通知（復旧完了）
```

#### 7.5.4 改善点の洗い出し

```markdown
## Root Cause
Stripe APIのレート制限に到達したが、リトライロジックが実装されていなかった。

## What Went Well
- 迅速な検出（5分以内）
- チームの協力体制
- 1時間以内の復旧

## What Went Wrong
- レート制限の監視がなかった
- リトライロジックの欠如
- ステージング環境での負荷テスト不足

## Action Items
- [ ] Stripe APIレート制限の監視追加（担当: @jane, 期限: 1/20）
- [ ] Exponential backoffリトライロジック追加（担当: @john, 期限: 1/18）
- [ ] 負荷テストをCI/CDに組み込み（担当: @bob, 期限: 1/25）
- [ ] ポストモーテムレビュー会議（全員, 1/17 14:00）
```

#### 7.5.5 ミスを認めた人を称賛する

**ポジティブなカルチャー構築:**

```
「John、問題を早期に報告してくれてありがとう。
おかげで迅速に対応できました。」

「エラーを隠さずに共有する文化が、チームの信頼を高めます。」
```

#### 7.5.6 数日後にレビュー

**ポストモーテムレビュー会議:**

```
日時: 2024-01-17 14:00
参加者: 全エンジニアリングチーム

アジェンダ:
1. インシデントタイムラインの振り返り
2. 改善アクションの確認
3. 学びの共有
4. 再発防止策の議論

目的:
- 同じ問題を二度と起こさない
- チーム全体の学習
- プロセス改善
```

---

## まとめ

フルスタックJavaScriptアプリケーションのデプロイ・CI/CD・統合テスト戦略をまとめました。

### 重要なポイント

1. **テスト戦略**: ユニット → 統合 → E2E のピラミッド構造
2. **CI/CDパイプライン**: 自動化による品質保証と迅速なデプロイ
3. **デプロイ戦略**: Blue-Green、Canary、Feature Flagを使った安全なリリース
4. **ロールバック**: 複数の戦略を準備（アーティファクト再デプロイ、git revert、ホットフィックス）
5. **コンテナ化**: 環境の一貫性と「自分のマシンでは動く」問題の解消
6. **統合テスト**: フロントエンド・バックエンド両方の本番接続確認
7. **モニタリング**: 問題の早期検出とインシデント対応の標準化

### 次のステップ

- **プロジェクトに適用**: 現在のプロジェクトにこれらの戦略を導入
- **継続的改善**: ポストモーテムから学び、プロセスを改善
- **チーム文化**: ブレームレス文化を構築し、心理的安全性を高める

---

**参考文献:**
- O'Reilly「Full Stack JavaScript Strategies」
- Playwright公式ドキュメント
- NestJS公式ドキュメント
- Vite公式ドキュメント



