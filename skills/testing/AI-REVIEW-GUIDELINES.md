# AIテストコード レビューガイドライン

## 概要

AI（Claude等）が生成したテストコードをレビューする際の観点をまとめたガイドラインです。AIは網羅的なテストケースを生成しがちですが、保守性・可読性の観点から「適切な絞り込み」が必要です。

## 主要な観点

### 1. テストケースの適切な絞り込み

#### 問題
AIは「分岐網羅・境界値・異常系」を全部入りで網羅しようとし、テストケースが肥大化します。

#### 対策

##### (a) 責務の分離
**そのテスト対象の責務ではないケースは削除します。**

```typescript
// ❌ 悪い例: バリデーションの責務混在
describe('UserService.createUser', () => {
  // UserServiceの責務外（バリデーション層の責務）
  it('should throw error when email is empty', async () => {
    await expect(userService.createUser({ email: '' })).rejects.toThrow()
  })

  it('should throw error when email is invalid format', async () => {
    await expect(userService.createUser({ email: 'invalid' })).rejects.toThrow()
  })

  it('should throw error when name exceeds 100 characters', async () => {
    await expect(userService.createUser({ name: 'a'.repeat(101) })).rejects.toThrow()
  })

  // UserServiceの責務
  it('should save user to database', async () => {
    const user = await userService.createUser(validUserData)
    expect(user.id).toBeDefined()
  })
})

// ✅ 良い例: 責務を分離
describe('UserValidator.validate', () => {
  it('should reject empty email', () => {
    expect(() => validator.validate({ email: '' })).toThrow()
  })

  it('should reject invalid email format', () => {
    expect(() => validator.validate({ email: 'invalid' })).toThrow()
  })

  it('should reject name over 100 characters', () => {
    expect(() => validator.validate({ name: 'a'.repeat(101) })).toThrow()
  })
})

describe('UserService.createUser', () => {
  it('should save validated user to database', async () => {
    // バリデーション済みの前提で動作
    const user = await userService.createUser(validUserData)
    expect(user.id).toBeDefined()
  })

  it('should return created user with timestamp', async () => {
    const user = await userService.createUser(validUserData)
    expect(user.createdAt).toBeInstanceOf(Date)
  })
})
```

##### (b) 前提条件の活用
**DB制約やバリデーション層で保証される前提はテスト対象外とします。**

```typescript
// ❌ 悪い例: DB制約で保証される条件をテスト
describe('updateUserStatus', () => {
  it('should throw error when userId is null', async () => {
    // DB NOT NULL制約で保証される
    await expect(updateUserStatus(null, 'ACTIVE')).rejects.toThrow()
  })

  it('should throw error when status is empty string', async () => {
    // DB CHECK制約で保証される
    await expect(updateUserStatus('user1', '')).rejects.toThrow()
  })

  it('should update user status', async () => {
    const result = await updateUserStatus('user1', 'ACTIVE')
    expect(result.status).toBe('ACTIVE')
  })
})

// ✅ 良い例: 前提条件を明示し、ビジネスロジックに集中
describe('updateUserStatus', () => {
  // 前提: userIdはDB NOT NULL制約で保証
  // 前提: statusはDB CHECK制約で保証

  it('should update user status to specified value', async () => {
    const result = await updateUserStatus('user1', OrganizationStatus.Active)
    expect(result.status).toBe(OrganizationStatus.Active)
  })

  it('should update updatedAt timestamp', async () => {
    const before = new Date()
    const result = await updateUserStatus('user1', OrganizationStatus.Active)
    expect(result.updatedAt.getTime()).toBeGreaterThanOrEqual(before.getTime())
  })
})
```

##### (c) 優先度付け
**ビジネス上クリティカルでない異常系は削除します。**

```typescript
// ❌ 悪い例: 低優先度の異常系まで網羅
describe('calculateDiscount', () => {
  it('should calculate 10% discount', () => {
    expect(calculateDiscount(1000, 0.1)).toBe(900)
  })

  it('should handle negative amount', () => {
    // 低優先度: 前段のバリデーションで防止済み
    expect(() => calculateDiscount(-1000, 0.1)).toThrow()
  })

  it('should handle discount over 100%', () => {
    // 低優先度: 業務上発生しない
    expect(() => calculateDiscount(1000, 1.5)).toThrow()
  })

  it('should handle floating point precision', () => {
    // 低優先度: 実務上問題にならない
    expect(calculateDiscount(100.123, 0.1)).toBeCloseTo(90.111)
  })
})

// ✅ 良い例: ビジネスクリティカルな仕様のみテスト
describe('calculateDiscount', () => {
  // 仕様: 割引率を適用して金額を計算する
  it('should calculate discount correctly', () => {
    expect(calculateDiscount(1000, 0.1)).toBe(900)
    expect(calculateDiscount(5000, 0.2)).toBe(4000)
  })

  // 仕様: 割引後の金額は小数点以下切り捨て
  it('should round down decimal places', () => {
    expect(calculateDiscount(1000, 0.33)).toBe(670) // 670.0
  })
})
```

##### (d) 仕様の明示
**各テストケースに「何の仕様を守るためか」を1行コメントで記述します。**

```typescript
// ✅ 良い例: 仕様を明示
describe('OrderService.calculateTotal', () => {
  // 仕様: 商品合計金額に消費税10%を加算する
  it('should add 10% tax to subtotal', () => {
    const order = { items: [{ price: 1000 }, { price: 2000 }] }
    expect(calculateTotal(order)).toBe(3300)
  })

  // 仕様: 会員は5%割引が適用される
  it('should apply 5% member discount before tax', () => {
    const order = { items: [{ price: 1000 }], isMember: true }
    expect(calculateTotal(order)).toBe(1045) // (1000 * 0.95) * 1.1
  })

  // 仕様: 送料無料ライン(3000円)未満は送料500円追加
  it('should add 500 yen shipping fee when subtotal under 3000', () => {
    const order = { items: [{ price: 2000 }] }
    expect(calculateTotal(order)).toBe(2750) // (2000 + 500) * 1.1
  })
})
```

#### AIへの指示例

```
【AIへのプロンプト例】
- 網羅率を上げる目的での境界値テストは禁止
- 各テストケースに「何の仕様を守るためか」を1行コメントで記述
- テスト対象の責務外のケースは削除
- DB制約で保証される条件はテスト対象外
- ビジネスクリティカルな仕様のみテストする
```

---

### 2. マジックナンバー・マジックストリングの排除

#### 問題
AIは事前定義のEnum/定数を無視して値を直書きしがちです。リファクタリング時の修正漏れの原因になります。

#### 対策

```typescript
// ❌ 悪い例: マジックストリング直書き
describe('OrganizationService', () => {
  it('should create active organization', async () => {
    const org = await service.create({ name: 'Test', status: 'ACTIVE' })
    expect(org.status).toBe('ACTIVE')
  })

  it('should update to inactive', async () => {
    await service.updateStatus('org1', 'INACTIVE')
    const org = await service.findById('org1')
    expect(org.status).toBe('INACTIVE')
  })
})

// ✅ 良い例: Enum/定数を使用
import { OrganizationStatus } from '@/types/organization'

describe('OrganizationService', () => {
  it('should create active organization', async () => {
    const org = await service.create({
      name: 'Test',
      status: OrganizationStatus.Active
    })
    expect(org.status).toBe(OrganizationStatus.Active)
  })

  it('should update to inactive', async () => {
    await service.updateStatus('org1', OrganizationStatus.Inactive)
    const org = await service.findById('org1')
    expect(org.status).toBe(OrganizationStatus.Inactive)
  })
})
```

```typescript
// ❌ 悪い例: マジックナンバー直書き
describe('PricingService', () => {
  it('should apply standard discount', () => {
    expect(calculateDiscount(1000, 'STANDARD')).toBe(900) // 0.1の直書き
  })

  it('should apply premium discount', () => {
    expect(calculateDiscount(1000, 'PREMIUM')).toBe(800) // 0.2の直書き
  })
})

// ✅ 良い例: 定数化
const DISCOUNT_RATES = {
  STANDARD: 0.1,
  PREMIUM: 0.2,
} as const

describe('PricingService', () => {
  it('should apply standard discount', () => {
    const amount = 1000
    const expected = amount * (1 - DISCOUNT_RATES.STANDARD)
    expect(calculateDiscount(amount, 'STANDARD')).toBe(expected)
  })

  it('should apply premium discount', () => {
    const amount = 1000
    const expected = amount * (1 - DISCOUNT_RATES.PREMIUM)
    expect(calculateDiscount(amount, 'PREMIUM')).toBe(expected)
  })
})
```

#### 定数定義の場所

**推奨: プロダクションコードと同じ定数を使用**
```typescript
// src/constants/pricing.ts
export const DISCOUNT_RATES = {
  STANDARD: 0.1,
  PREMIUM: 0.2,
} as const

// src/services/pricing.test.ts
import { DISCOUNT_RATES } from '@/constants/pricing'

describe('PricingService', () => {
  it('should apply standard discount', () => {
    const expected = 1000 * (1 - DISCOUNT_RATES.STANDARD)
    expect(calculateDiscount(1000, 'STANDARD')).toBe(expected)
  })
})
```

---

### 3. Fixture化とファクトリー関数

#### 問題
各テストでセットアップ処理を愚直に組み立てると、大量の重複コードが発生します。

#### 対策: ファクトリー関数パターン

##### 基本パターン

```typescript
// ❌ 悪い例: 各テストでセットアップを重複記述
describe('UserService', () => {
  it('should create user', async () => {
    const userData = {
      id: '1',
      email: 'john@example.com',
      name: 'John Doe',
      role: 'USER',
      createdAt: new Date(),
      updatedAt: new Date(),
    }
    const user = await service.create(userData)
    expect(user.id).toBe('1')
  })

  it('should update user', async () => {
    const userData = {
      id: '1',
      email: 'john@example.com',
      name: 'John Doe',
      role: 'USER',
      createdAt: new Date(),
      updatedAt: new Date(),
    }
    const updated = await service.update('1', { name: 'Jane Doe' })
    expect(updated.name).toBe('Jane Doe')
  })
})

// ✅ 良い例: ファクトリー関数で共通化
function createUserFixture(overrides?: Partial<User>): User {
  return {
    id: '1',
    email: 'john@example.com',
    name: 'John Doe',
    role: UserRole.User,
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date('2024-01-01'),
    ...overrides,
  }
}

describe('UserService', () => {
  it('should create user', async () => {
    const userData = createUserFixture()
    const user = await service.create(userData)
    expect(user.id).toBe('1')
  })

  it('should update user', async () => {
    const userData = createUserFixture({ name: 'Jane Doe' })
    const updated = await service.update('1', { name: 'Jane Doe' })
    expect(updated.name).toBe('Jane Doe')
  })

  it('should handle admin role', async () => {
    const adminUser = createUserFixture({ role: UserRole.Admin })
    const user = await service.create(adminUser)
    expect(user.role).toBe(UserRole.Admin)
  })
})
```

##### ネストしたオブジェクトのFixture

```typescript
// ✅ 良い例: ネストした構造のファクトリー関数
function createAddressFixture(overrides?: Partial<Address>): Address {
  return {
    street: '123 Main St',
    city: 'Tokyo',
    postalCode: '100-0001',
    country: 'Japan',
    ...overrides,
  }
}

function createUserWithAddressFixture(
  userOverrides?: Partial<User>,
  addressOverrides?: Partial<Address>
): User {
  return {
    ...createUserFixture(userOverrides),
    address: createAddressFixture(addressOverrides),
  }
}

describe('UserService', () => {
  it('should save user with address', async () => {
    const user = createUserWithAddressFixture(
      { name: 'John' },
      { city: 'Osaka' }
    )
    const saved = await service.create(user)
    expect(saved.address.city).toBe('Osaka')
  })
})
```

##### リレーションを持つエンティティのFixture

```typescript
// ✅ 良い例: リレーションを持つエンティティのファクトリー関数
function createOrganizationFixture(overrides?: Partial<Organization>): Organization {
  return {
    id: 'org1',
    name: 'ACME Corp',
    status: OrganizationStatus.Active,
    createdAt: new Date('2024-01-01'),
    ...overrides,
  }
}

function createProjectFixture(
  overrides?: Partial<Project>,
  organization?: Organization
): Project {
  return {
    id: 'proj1',
    name: 'Project Alpha',
    organizationId: organization?.id ?? 'org1',
    organization: organization ?? createOrganizationFixture(),
    status: ProjectStatus.Active,
    createdAt: new Date('2024-01-01'),
    ...overrides,
  }
}

describe('ProjectService', () => {
  it('should create project with organization', async () => {
    const org = createOrganizationFixture({ name: 'Custom Org' })
    const project = createProjectFixture({ name: 'Custom Project' }, org)

    const saved = await service.create(project)
    expect(saved.organization.name).toBe('Custom Org')
  })
})
```

##### Fixtureファイルの配置

```typescript
// src/test/fixtures/user.fixture.ts
import { User, UserRole } from '@/types/user'

export function createUserFixture(overrides?: Partial<User>): User {
  return {
    id: '1',
    email: 'john@example.com',
    name: 'John Doe',
    role: UserRole.User,
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date('2024-01-01'),
    ...overrides,
  }
}

// src/services/user.test.ts
import { createUserFixture } from '@/test/fixtures/user.fixture'

describe('UserService', () => {
  it('should create user', async () => {
    const user = createUserFixture({ email: 'test@example.com' })
    // ...
  })
})
```

#### Fixtureのメリット

1. **型変更による修正漏れ削減**: 型定義が変わっても修正箇所はファクトリー関数のみ
2. **テストの意図が明確**: `createUserFixture({ role: UserRole.Admin })` で「管理者ユーザー」が明示的
3. **DRY原則**: 重複コード削減
4. **メンテナンス性向上**: ダミーデータの変更が容易

---

### 4. テストの意図明示（仕様コメント）

#### 問題
テスト名だけでは「なぜこのテストが必要か」が分からない場合があります。

#### 対策

```typescript
// ❌ 悪い例: テスト名のみで仕様不明
describe('calculateShippingFee', () => {
  it('should return 0', () => {
    expect(calculateShippingFee(5000)).toBe(0)
  })

  it('should return 500', () => {
    expect(calculateShippingFee(2000)).toBe(500)
  })
})

// ✅ 良い例: 仕様を1行コメントで明示
describe('calculateShippingFee', () => {
  // 仕様: 3000円以上は送料無料
  it('should return 0 when amount is 3000 or more', () => {
    expect(calculateShippingFee(3000)).toBe(0)
    expect(calculateShippingFee(5000)).toBe(0)
  })

  // 仕様: 3000円未満は送料500円
  it('should return 500 when amount is under 3000', () => {
    expect(calculateShippingFee(2999)).toBe(500)
    expect(calculateShippingFee(1000)).toBe(500)
  })
})
```

---

### 5. レイヤー間の重複排除

#### 問題
同じ仕様が別レイヤー（単体/統合/E2E）で既に担保されている場合、重複テストが発生します。

#### 対策

##### テストレイヤーの責務分離

```typescript
// 単体テスト: バリデーションロジック
describe('UserValidator (Unit)', () => {
  // 仕様: メールアドレス形式チェック
  it('should reject invalid email format', () => {
    expect(() => validator.validate({ email: 'invalid' })).toThrow()
  })
})

// 統合テスト: API層（バリデーションは既にテスト済みのため省略）
describe('POST /api/users (Integration)', () => {
  // 仕様: ユーザー登録APIが正常に動作する
  it('should create user and return 201', async () => {
    const response = await request(app)
      .post('/api/users')
      .send(createUserFixture())

    expect(response.status).toBe(201)
    expect(response.body.id).toBeDefined()
  })

  // バリデーションエラーは単体テストで担保済みのため省略
})

// E2Eテスト: ユーザー登録フロー全体
describe('User Registration Flow (E2E)', () => {
  // 仕様: ユーザーが画面から登録できる
  it('should allow user to register from UI', async () => {
    await page.goto('/register')
    await page.fill('#email', 'test@example.com')
    await page.fill('#name', 'Test User')
    await page.click('button[type="submit"]')

    await expect(page.locator('.success-message')).toBeVisible()
  })

  // バリデーションエラー表示は省略（単体テストで担保済み）
})
```

#### レイヤー別テスト方針

| レイヤー | テスト内容 | 網羅度 |
|---------|-----------|--------|
| **単体テスト** | ロジック、バリデーション、エッジケース | 100% |
| **統合テスト** | API動作、DB連携、主要フロー | 主要パス |
| **E2Eテスト** | ユーザーシナリオ、クリティカルパス | 最小限 |

---

## AIが見落としがちなポイント

### 1. Fixture化の未実施
- ダミーデータを各テストで重複生成
- 型変更時の修正漏れリスク

### 2. 定数未使用
- マジックナンバー/ストリングの直書き
- リファクタリング時の保守性低下

### 3. テスト膨張
- 不要な境界値テスト
- 責務外の異常系テスト

### 4. 責務混在
- テスタビリティが低いコードを複雑なモックでカバー
- 設計改善が先決

### 5. 一度に大量生成
- レビュー負荷が高い
- 段階的な生成とレビューを推奨

---

## レビューチェックリスト

### 必須確認項目

- [ ] 各テストに「仕様コメント」が記述されているか
- [ ] マジックナンバー/ストリングが排除されているか（Enum/定数使用）
- [ ] Fixture/ファクトリー関数が活用されているか
- [ ] テスト対象の責務外のケースが削除されているか
- [ ] DB制約/バリデーション層で保証される前提がテスト対象外になっているか
- [ ] ビジネスクリティカルでない異常系が削除されているか
- [ ] レイヤー間で重複したテストが削除されているか

### 推奨確認項目

- [ ] テスト名が仕様を説明しているか
- [ ] AAAパターンに従っているか
- [ ] テストが独立しているか（順序依存なし）
- [ ] テストデータが意味のある値か（`foo`, `bar`を避ける）

---

## 改善例: Before/After

### Before（AIが生成したコード）

```typescript
describe('UserService', () => {
  it('should create user', async () => {
    const user = await service.create({
      email: 'test@example.com',
      name: 'Test User',
      status: 'ACTIVE',
    })
    expect(user.status).toBe('ACTIVE')
  })

  it('should throw error when email is empty', async () => {
    await expect(service.create({ email: '', name: 'Test' })).rejects.toThrow()
  })

  it('should throw error when email is invalid', async () => {
    await expect(service.create({ email: 'invalid', name: 'Test' })).rejects.toThrow()
  })

  it('should throw error when name is over 100 chars', async () => {
    await expect(service.create({ email: 'test@example.com', name: 'a'.repeat(101) })).rejects.toThrow()
  })

  it('should update user status', async () => {
    const user = await service.create({ email: 'test@example.com', name: 'Test', status: 'ACTIVE' })
    await service.updateStatus(user.id, 'INACTIVE')
    const updated = await service.findById(user.id)
    expect(updated.status).toBe('INACTIVE')
  })
})
```

### After（レビュー後のコード）

```typescript
// test/fixtures/user.fixture.ts
import { UserStatus } from '@/types/user'

export function createUserFixture(overrides?: Partial<User>): User {
  return {
    id: '1',
    email: 'john@example.com',
    name: 'John Doe',
    status: UserStatus.Active,
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date('2024-01-01'),
    ...overrides,
  }
}

// services/user.test.ts
import { UserStatus } from '@/types/user'
import { createUserFixture } from '@/test/fixtures/user.fixture'

describe('UserService', () => {
  // 前提: メールアドレス・名前のバリデーションはバリデーション層で実施済み

  // 仕様: ユーザーを作成しDBに保存する
  it('should save user to database', async () => {
    const userData = createUserFixture()
    const user = await service.create(userData)
    expect(user.id).toBeDefined()
  })

  // 仕様: ユーザー作成時のステータスは指定値を使用
  it('should set user status to specified value', async () => {
    const userData = createUserFixture({ status: UserStatus.Active })
    const user = await service.create(userData)
    expect(user.status).toBe(UserStatus.Active)
  })

  // 仕様: ユーザーステータスを更新する
  it('should update user status', async () => {
    const user = await service.create(createUserFixture())
    await service.updateStatus(user.id, UserStatus.Inactive)
    const updated = await service.findById(user.id)
    expect(updated.status).toBe(UserStatus.Inactive)
  })
})

// バリデーションは別ファイルでテスト
describe('UserValidator', () => {
  it('should reject empty email', () => {
    expect(() => validator.validate({ email: '' })).toThrow()
  })

  it('should reject invalid email format', () => {
    expect(() => validator.validate({ email: 'invalid' })).toThrow()
  })

  it('should reject name over 100 characters', () => {
    expect(() => validator.validate({ name: 'a'.repeat(101) })).toThrow()
  })
})
```

---

## まとめ

AIが生成したテストコードは「網羅的」ですが、「適切な絞り込み」と「保守性の向上」が必要です。

**レビュー時の重点項目:**
1. テストケースの適切な絞り込み（責務分離、前提条件、優先度）
2. マジックナンバー・ストリングの排除（Enum/定数使用）
3. Fixture化とファクトリー関数の活用
4. テストの意図明示（仕様コメント）
5. レイヤー間の重複排除

これらの観点でレビューすることで、保守性の高いテストコードを維持できます。
