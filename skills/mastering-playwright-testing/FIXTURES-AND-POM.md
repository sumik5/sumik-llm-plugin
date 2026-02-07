# Fixtures と Page Object Model

このドキュメントでは、Playwrightのテスト構造化の要となるFixtureシステムと、Page Object Model（POM）パターンの実装方法を詳しく解説します。

---

## Fixtureの基本概念

Fixtureは、テストのセットアップとテアダウンを宣言的に管理する仕組みです。テストコードから初期化処理を分離し、再利用可能なコンポーネントとして管理できます。

### 依存性注入パターン

Fixtureは依存性注入（Dependency Injection）パターンに基づいています：

```typescript
import { test as base } from '@playwright/test';

type MyFixtures = {
  loggedInPage: Page;
};

export const test = base.extend<MyFixtures>({
  loggedInPage: async ({ page }, use) => {
    // セットアップフェーズ
    await page.goto('/login');
    await page.fill('[name="username"]', 'testuser');
    await page.fill('[name="password"]', 'password123');
    await page.getByRole('button', { name: 'Login' }).click();
    await page.waitForURL('/dashboard');

    // テスト本体に制御を渡す
    await use(page);

    // テアダウンフェーズ
    await page.getByRole('button', { name: 'Logout' }).click();
  },
});
```

### Fixtureのライフサイクル

1. **セットアップ**: `use()` 呼び出し前のコード
2. **テスト実行**: `await use(value)` で制御をテストに渡す
3. **テアダウン**: `use()` 呼び出し後のコード（テスト完了後に実行）

---

## カスタムFixture作成

### 基本的なFixture定義

```typescript
import { test as base, Page } from '@playwright/test';

type MyFixtures = {
  loggedInPage: Page;
  userData: { firstName: string; lastName: string };
  apiToken: string;
};

export const test = base.extend<MyFixtures>({
  // ページ関連のFixture
  loggedInPage: async ({ page }, use) => {
    await page.goto('/login');
    await page.fill('[name="user"]', 'user123');
    await page.getByRole('button', { name: 'Login' }).click();
    await use(page);
    await page.getByRole('button', { name: 'Logout' }).click();
  },

  // データFixture
  userData: async ({}, use) => {
    await use({
      firstName: 'Jane',
      lastName: 'Doe',
    });
  },

  // API認証トークン
  apiToken: async ({ request }, use) => {
    const response = await request.post('/api/auth', {
      data: { username: 'admin', password: 'admin' },
    });
    const { token } = await response.json();
    await use(token);
  },
});

export { expect } from '@playwright/test';
```

### テストでの使用

```typescript
import { test, expect } from './fixtures';

test('ユーザー情報を更新できる', async ({ loggedInPage, userData }) => {
  await loggedInPage.goto('/profile');
  await expect(loggedInPage.getByText(`Hello, ${userData.firstName}`)).toBeVisible();
});
```

---

## Fixtureの合成（Composition）

Fixture間で依存関係を持たせることができます。

### 依存チェーンの構築

```typescript
type MyFixtures = {
  apiContext: APIRequestContext;
  adminToken: string;
  adminUser: User;
};

export const test = base.extend<MyFixtures>({
  // 基本的なAPIコンテキスト
  apiContext: async ({ playwright }, use) => {
    const context = await playwright.request.newContext({
      baseURL: 'https://api.example.com',
    });
    await use(context);
    await context.dispose();
  },

  // adminTokenはapiContextに依存
  adminToken: async ({ apiContext }, use) => {
    const response = await apiContext.post('/auth/login', {
      data: { username: 'admin', password: 'admin' },
    });
    const { token } = await response.json();
    await use(token);
  },

  // adminUserはadminTokenに依存
  adminUser: async ({ apiContext, adminToken }, use) => {
    const response = await apiContext.get('/users/me', {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const user = await response.json();
    await use(user);
    // クリーンアップ
    await apiContext.delete(`/users/${user.id}`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
  },
});
```

### 使用例

```typescript
test('管理者として操作できる', async ({ page, adminUser }) => {
  // adminUserを使う時点で、apiContext → adminToken → adminUser の順に実行済み
  await page.goto('/admin/dashboard');
  await expect(page.getByText(`Welcome, ${adminUser.name}`)).toBeVisible();
});
```

---

## Page Object Model (POM)

POMは、ページ固有のロジックをクラスにカプセル化するデザインパターンです。

### POMクラスの基本構造

```typescript
import { Page, Locator } from '@playwright/test';

export class CheckoutPage {
  readonly page: Page;
  readonly firstNameInput: Locator;
  readonly lastNameInput: Locator;
  readonly postalCodeInput: Locator;
  readonly continueButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.firstNameInput = page.getByPlaceholder('First Name');
    this.lastNameInput = page.getByPlaceholder('Last Name');
    this.postalCodeInput = page.getByPlaceholder('Zip/Postal Code');
    this.continueButton = page.getByRole('button', { name: 'Continue' });
  }

  async goto() {
    await this.page.goto('/checkout');
  }

  async fillShippingInfo(firstName: string, lastName: string, postalCode: string) {
    await this.firstNameInput.fill(firstName);
    await this.lastNameInput.fill(lastName);
    await this.postalCodeInput.fill(postalCode);
  }

  async submit() {
    await this.continueButton.click();
    await this.page.waitForURL('/checkout/review');
  }
}
```

### POM + Fixture統合パターン

POMをFixtureとして注入すると、テストコードがさらに簡潔になります：

```typescript
import { test as base } from '@playwright/test';
import { CheckoutPage } from './pages/checkout-page';
import { ProductPage } from './pages/product-page';

type PageFixtures = {
  checkoutPage: CheckoutPage;
  productPage: ProductPage;
};

export const test = base.extend<PageFixtures>({
  checkoutPage: async ({ page }, use) => {
    await use(new CheckoutPage(page));
  },
  productPage: async ({ page }, use) => {
    await use(new ProductPage(page));
  },
});

export { expect } from '@playwright/test';
```

### テストでの使用

```typescript
import { test, expect } from './fixtures';

test('商品を購入できる', async ({ productPage, checkoutPage }) => {
  await productPage.goto();
  await productPage.addToCart('Sauce Labs Backpack');
  await productPage.goToCheckout();

  await checkoutPage.fillShippingInfo('John', 'Doe', '12345');
  await checkoutPage.submit();

  await expect(checkoutPage.page.getByText('Thank you for your order')).toBeVisible();
});
```

---

## 高度なFixtureパターン

### 自動Fixture（auto: true）

すべてのテストで自動実行されるFixtureを作成できます：

```typescript
type MyFixtures = {
  analytics: void;
};

export const test = base.extend<MyFixtures>({
  analytics: [
    async ({ page }, use) => {
      // すべてのテスト開始前に実行
      await page.addInitScript(() => {
        window.analytics = { track: () => {} }; // モックアナリティクス
      });
      await use();
    },
    { auto: true }, // 自動実行フラグ
  ],
});
```

### Test Options（プロジェクト単位のパラメタライズ）

```typescript
type TestOptions = {
  defaultUser: { username: string; password: string };
};

export const test = base.extend<{}, TestOptions>({
  defaultUser: [{ username: 'user', password: 'pass' }, { option: true }],

  page: async ({ page, defaultUser }, use) => {
    await page.goto('/login');
    await page.fill('[name="username"]', defaultUser.username);
    await page.fill('[name="password"]', defaultUser.password);
    await page.getByRole('button', { name: 'Login' }).click();
    await use(page);
  },
});
```

`playwright.config.ts` でオプションをオーバーライド：

```typescript
export default defineConfig({
  projects: [
    {
      name: 'admin tests',
      use: {
        defaultUser: { username: 'admin', password: 'admin123' },
      },
    },
  ],
});
```

### スクリーンショット on failure パターン

```typescript
type MyFixtures = {
  captureScreenshotOnFailure: void;
};

export const test = base.extend<MyFixtures>({
  captureScreenshotOnFailure: [
    async ({ page }, use, testInfo) => {
      await use();
      // テスト失敗時のみスクリーンショット保存
      if (testInfo.status !== testInfo.expectedStatus) {
        const screenshot = await page.screenshot();
        await testInfo.attach('failure-screenshot', {
          body: screenshot,
          contentType: 'image/png',
        });
      }
    },
    { auto: true },
  ],
});
```

### テストデータ注入パターン

```typescript
type MyFixtures = {
  testData: { products: Product[]; users: User[] };
};

export const test = base.extend<MyFixtures>({
  testData: async ({ request }, use) => {
    // テスト開始前にデータをセットアップ
    const productsResponse = await request.post('/api/test-data/products', {
      data: [
        { name: 'Product A', price: 100 },
        { name: 'Product B', price: 200 },
      ],
    });
    const products = await productsResponse.json();

    const usersResponse = await request.post('/api/test-data/users', {
      data: [{ username: 'test1' }, { username: 'test2' }],
    });
    const users = await usersResponse.json();

    await use({ products, users });

    // テスト終了後にデータをクリーンアップ
    await request.delete('/api/test-data/cleanup');
  },
});
```

---

## Fixture Collection管理

### 単一カスタムtestファイルに集約

プロジェクト全体でFixtureを統一管理：

```typescript
// test/fixtures.ts
import { test as base } from '@playwright/test';
import { LoginPage } from './pages/login-page';
import { DashboardPage } from './pages/dashboard-page';

type PageFixtures = {
  loginPage: LoginPage;
  dashboardPage: DashboardPage;
};

type AuthFixtures = {
  authenticatedPage: Page;
};

export const test = base
  .extend<PageFixtures>({
    loginPage: async ({ page }, use) => await use(new LoginPage(page)),
    dashboardPage: async ({ page }, use) => await use(new DashboardPage(page)),
  })
  .extend<AuthFixtures>({
    authenticatedPage: async ({ loginPage, page }, use) => {
      await loginPage.goto();
      await loginPage.login('user', 'password');
      await use(page);
    },
  });

export { expect } from '@playwright/test';
```

### mergeTests() でサードパーティFixtureと統合

```typescript
import { test as base, mergeTests } from '@playwright/test';
import { test as dbTest } from '@playwright/test/db'; // 仮想的なDBプラグイン

const test = mergeTests(base, dbTest);

// 両方のFixtureが使用可能
test('データベースと連携', async ({ page, dbConnection }) => {
  const users = await dbConnection.query('SELECT * FROM users');
  await page.goto('/admin/users');
  // ...
});
```

### ファイル構成パターン

```
test/
├── fixtures/
│   ├── index.ts          # メインのFixture定義
│   ├── auth.fixture.ts   # 認証関連
│   ├── db.fixture.ts     # データベース関連
│   └── api.fixture.ts    # API関連
├── pages/
│   ├── login-page.ts
│   └── dashboard-page.ts
└── specs/
    ├── auth.spec.ts
    └── dashboard.spec.ts
```

---

## DRY vs WET（テストコード設計哲学）

### WET原則（Write Everything Twice）

テストコードでは、**3回目の繰り返しが現れるまで抽象化を遅らせる**ことが推奨されます。

#### なぜWETか？

- **テストコードの目的**: 実装の正しさを検証すること
- **可読性優先**: テストが何をテストしているか一目で分かることが重要
- **早期抽象化の弊害**: 間違った抽象化は理解を困難にする

#### 悪い例（過度なDRY）

```typescript
// 共通関数に抽出しすぎ
async function createUser(page: Page, role: 'admin' | 'user') {
  await page.goto('/signup');
  if (role === 'admin') {
    await page.check('#admin-checkbox');
  }
  await page.fill('[name="username"]', `${role}-user`);
  await page.fill('[name="password"]', 'password');
  await page.click('button[type="submit"]');
}

test('管理者を作成', async ({ page }) => {
  await createUser(page, 'admin'); // 何が起きているか不明瞭
  // ...
});
```

#### 良い例（適度なWET）

```typescript
test('管理者を作成', async ({ page }) => {
  // テスト内に手順を明示
  await page.goto('/signup');
  await page.check('#admin-checkbox');
  await page.fill('[name="username"]', 'admin-user');
  await page.fill('[name="password"]', 'password');
  await page.click('button[type="submit"]');

  await expect(page.getByText('Admin user created')).toBeVisible();
});

test('一般ユーザーを作成', async ({ page }) => {
  await page.goto('/signup');
  await page.fill('[name="username"]', 'regular-user');
  await page.fill('[name="password"]', 'password');
  await page.click('button[type="submit"]');

  await expect(page.getByText('User created')).toBeVisible();
});
```

### 抽象化の判断基準

| 繰り返し回数 | 行動 |
|-------------|------|
| 1-2回 | そのまま記述（WET） |
| 3回 | Fixtureまたはヘルパー関数への抽出を検討 |
| 4回以上 | 抽象化を実施 |

### Fixtureによる適切な抽象化

```typescript
// 3回以上使われるセットアップはFixtureに
type MyFixtures = {
  signupPage: Page;
};

export const test = base.extend<MyFixtures>({
  signupPage: async ({ page }, use) => {
    await page.goto('/signup');
    await use(page);
  },
});

// テストはシンプルに
test('管理者を作成', async ({ signupPage }) => {
  await signupPage.check('#admin-checkbox');
  await signupPage.fill('[name="username"]', 'admin-user');
  await signupPage.fill('[name="password"]', 'password');
  await signupPage.click('button[type="submit"]');

  await expect(signupPage.getByText('Admin user created')).toBeVisible();
});
```

---

## まとめ

- **Fixture**: セットアップ/テアダウンの宣言的管理、依存性注入
- **POM**: ページ固有ロジックのカプセル化、再利用性向上
- **Fixture Composition**: 複雑な依存関係を段階的に構築
- **WET原則**: テストの可読性を優先、3回目の繰り返しで抽象化
- **自動Fixture**: すべてのテストで共通の初期化処理
- **Test Options**: プロジェクト単位のパラメタライズ

適切なFixture設計により、テストコードの保守性と可読性が大幅に向上します。
