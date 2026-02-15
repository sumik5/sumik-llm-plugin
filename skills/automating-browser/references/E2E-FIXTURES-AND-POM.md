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

### Fixtureスコープの選択

Fixtureには**test**と**worker**、**session**の3つのスコープがあり、リソースの生存期間と共有範囲を決定します。

| スコープ | 生存期間 | 用途 | 例 |
|---------|---------|------|-----|
| `test` | テストごとに新規作成（デフォルト） | 完全な独立性が必要な場合 | `page` Fixture |
| `worker` | Workerプロセス内で共有 | 高コストなリソースの再利用 | `browser` Fixture |
| `session` | 全Worker間で共有 | グローバルな設定や認証トークン | セッション設定 |

**Worker Scopeの例:**

```typescript
import { test as base } from '@playwright/test';

type WorkerFixtures = {
  sharedBrowserContext: BrowserContext;
};

export const test = base.extend<{}, WorkerFixtures>({
  sharedBrowserContext: [
    async ({ browser }, use) => {
      const context = await browser.newContext();
      await use(context);
      await context.close();
    },
    { scope: 'worker' } // Workerプロセス内で1回のみ作成
  ],
});

// 同じWorker内の複数テストで同じcontextを共有
test('test 1', async ({ sharedBrowserContext }) => {
  const page = await sharedBrowserContext.newPage();
  // ...
});

test('test 2', async ({ sharedBrowserContext }) => {
  const page = await sharedBrowserContext.newPage();
  // 同じcontextが再利用される
});
```

**注意点:**
- Worker scopeは状態の共有を許容するため、テスト間の干渉に注意
- Test scopeは毎回新規作成されるため遅いが、完全な独立性を保証
- Session scopeは全Worker間で共有されるため、グローバル設定に使用

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

**自動Fixtureの実用例: コンソールエラー検出**

```typescript
type MyFixtures = {
  noConsoleErrors: void;
};

export const test = base.extend<MyFixtures>({
  noConsoleErrors: [
    async ({ page }, use) => {
      const consoleErrors: string[] = [];

      page.on('console', msg => {
        if (msg.type() === 'error') {
          consoleErrors.push(msg.text());
        }
      });

      await use();

      // テスト完了後に自動チェック
      expect(consoleErrors, `Unexpected console errors: ${consoleErrors.join()}`).toHaveLength(0);
    },
    { auto: true } // 全テストで自動実行
  ],
});

// テストコード側は変更不要
test('page loads without console errors', async ({ page }) => {
  await page.goto('https://example.com/');
  // コンソールエラーは自動検出される
});
```

**自動Fixtureのユースケース:**
- コンソールエラー/警告の監視
- アナリティクストラッキングのモック
- ページロード時間の計測
- スクリーンショット自動保存（失敗時）

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

### Fixtureのオーバーライドとパラメタライズ

既存のFixtureを上書きして振る舞いをカスタマイズできます。

**組み込みFixtureのオーバーライド例:**

```typescript
// pageFixtureを拡張して、すべてのページでデフォルトでログイン済みにする
export const test = base.extend({
  page: async ({ page }, use) => {
    await page.goto('/login');
    await page.fill('[name="username"]', 'standard_user');
    await page.fill('[name="password"]', 'secret_sauce');
    await page.getByRole('button', { name: 'Login' }).click();
    await page.waitForURL('/dashboard');

    await use(page); // ログイン済みページをテストに渡す
  },
});

// すべてのテストで自動的にログイン済み状態
test('access dashboard', async ({ page }) => {
  // pageは既にログイン済み
  await expect(page.getByText('Dashboard')).toBeVisible();
});
```

**Parametrized Fixtures（パラメータ付きFixture）:**

```typescript
type MyFixtures = {
  userRole: 'admin' | 'user' | 'guest';
  authenticatedPage: Page;
};

export const test = base.extend<MyFixtures>({
  userRole: ['user', { option: true }], // デフォルト値

  authenticatedPage: async ({ page, userRole }, use) => {
    const credentials = {
      admin: { username: 'admin', password: 'admin123' },
      user: { username: 'user', password: 'user123' },
      guest: { username: 'guest', password: 'guest123' },
    };

    const { username, password } = credentials[userRole];

    await page.goto('/login');
    await page.fill('[name="username"]', username);
    await page.fill('[name="password"]', password);
    await page.getByRole('button', { name: 'Login' }).click();

    await use(page);
  },
});

// テストごとにロールを変更可能
test.use({ userRole: 'admin' });
test('admin can access settings', async ({ authenticatedPage }) => {
  await authenticatedPage.goto('/settings');
  await expect(authenticatedPage.getByText('Admin Settings')).toBeVisible();
});

test.use({ userRole: 'guest' });
test('guest cannot access settings', async ({ authenticatedPage }) => {
  await authenticatedPage.goto('/settings');
  await expect(authenticatedPage.getByText('Access Denied')).toBeVisible();
});
```

### Box Fixtures（値なしFixture）

値を返さないFixtureは、セットアップとティアダウンのみを実行するために使用されます。

```typescript
type MyFixtures = {
  setupMockServer: void;
};

export const test = base.extend<MyFixtures>({
  setupMockServer: async ({}, use) => {
    // セットアップ: モックサーバー起動
    const mockServer = startMockServer();

    await use(); // 値は渡さない

    // ティアダウン: モックサーバー停止
    await mockServer.stop();
  },
});

// Fixtureを使うだけでモックサーバーが起動・停止される
test('API calls are mocked', async ({ page, setupMockServer }) => {
  await page.goto('/');
  // モックサーバーが自動的に動作中
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

---

## テストの保守性ベストプラクティス

### describe() ブロックによるテスト整理

テストスイートを明確な構造で整理することで、デバッグやナビゲーションが容易になります。`describe()` ブロックを使用して関連するテストをグループ化し、物語のような読みやすい構造を作成します。

```typescript
import { test, expect } from '@playwright/test';

test.describe('Login Functionality', () => {
  test('should allow valid user to log in', async ({ page }) => {
    await page.goto('https://www.saucedemo.com/');
    await page.getByPlaceholder('Username').fill('standard_user');
    await page.getByPlaceholder('Password').fill('secret_sauce');
    await page.getByRole('button', { name: 'Login' }).click();
    await expect(page).toHaveURL('https://www.saucedemo.com/inventory.html');
  });

  test('should show error for invalid credentials', async ({ page }) => {
    await page.goto('https://www.saucedemo.com/');
    await page.getByPlaceholder('Username').fill('locked_out_user');
    await page.getByPlaceholder('Password').fill('secret_sauce');
    await page.getByRole('button', { name: 'Login' }).click();
    await expect(page.getByText('Epic sadface: Sorry, this user has been locked out.')).toBeVisible();
  });
});
```

**命名のベストプラクティス:**
- テスト名は「should ...」形式で会話的に記述する
- 曖昧な名前（`test1`、`loginTest`）は避ける
- 意図が一目で分かるようにする

### テスト命名とメタデータ戦略

テスト名とdescribeブロックのネスティングにより、テストの分類と実行制御が可能になります。

**構造化命名規約:**

```typescript
test.describe('Feature: User Authentication', () => {
  test.describe('Scenario: Successful login', () => {
    test('Given valid credentials, When user logs in, Then dashboard is displayed', async ({ page }) => {
      // Given
      await page.goto('/login');

      // When
      await page.fill('[name="username"]', 'user');
      await page.fill('[name="password"]', 'pass');
      await page.click('button[type="submit"]');

      // Then
      await expect(page).toHaveURL('/dashboard');
    });
  });

  test.describe('Scenario: Failed login', () => {
    test('Given invalid credentials, When user logs in, Then error message is shown', async ({ page }) => {
      // ...
    });
  });
});
```

**タグによるテスト分類:**

```typescript
test.describe('@smoke @critical', () => {
  test('user can login', async ({ page }) => {
    // ...
  });
});

test.describe('@regression @api', () => {
  test('user profile is updated', async ({ page }) => {
    // ...
  });
});
```

```bash
# タグでフィルタ実行
npx playwright test --grep "@smoke"
npx playwright test --grep "@critical"
npx playwright test --grep-invert "@slow"  # @slowを除外
```

**Arrange-Act-Assertパターンの明示:**

```typescript
test('should add item to cart', async ({ page }) => {
  // Arrange (準備)
  await page.goto('/products');
  const productName = 'Sauce Labs Backpack';

  // Act (実行)
  await page.getByText(productName).click();
  await page.getByRole('button', { name: 'Add to cart' }).click();

  // Assert (検証)
  const cartBadge = page.locator('.shopping_cart_badge');
  await expect(cartBadge).toHaveText('1');
});
```

### Fixtureによるセットアップとテアダウン

Fixtureはセットアップとテアダウンの管理を簡素化します。Playwrightは`page`、`browser`、`context`などの組み込みFixtureを提供し、カスタムFixtureも定義できます。

**ログインFixtureの例:**

```typescript
import { test as base } from '@playwright/test';

export const test = base.extend({
  login: async ({ page }, use) => {
    await page.goto('https://www.saucedemo.com/');
    const login = async (username: string, password: string) => {
      await page.getByPlaceholder('Username').fill(username);
      await page.getByPlaceholder('Password').fill(password);
      await page.getByRole('button', { name: 'Login' }).click();
    };
    await use(login);
  },
});
```

**テストでの使用:**

```typescript
import { test, expect } from './loginFixture';

test.describe('Login Functionality', () => {
  test('should allow valid user to log in', async ({ login, page }) => {
    await login('standard_user', 'secret_sauce');
    await expect(page).toHaveURL('https://www.saucedemo.com/inventory.html');
  });

  test('should show error for invalid credentials', async ({ login, page }) => {
    await login('locked_out_user', 'secret_sauce');
    await expect(page.getByText('Epic sadface: Sorry, this user has been locked out.')).toBeVisible();
  });
});
```

これによりテストがDRY（Don't Repeat Yourself）原則に従い、繰り返しコードが削減されます。

**クリーンアップ:**
- Playwrightは自動的にクリーンアップを処理します
- 必要に応じて`afterEach()`や`afterAll()`フックを使用できます
- 再ログインを避けるには`storageState`を使用します（詳細は後述）

### POMの重複削減効果

Page Object Modelは、セレクターや操作の重複コードを排除し、UI変更に対する保守性を向上させます。

**課題:**
- 同じログイン手順が複数のテストに重複
- UIが変更されると複数箇所の修正が必要
- テストコードが低レベルの実装詳細で肥大化

**解決策:**
- 各ページのセレクターとメソッドをクラスにカプセル化
- テストコードはページオブジェクトのメソッドを呼び出すだけ
- UI変更時はページオブジェクトクラスのみを更新

### 高度なPOM実装パターン

#### readonly vs private プロパティ

```typescript
// readonly パターン（イミュータビリティ重視）
import { type Page, type Locator } from '@playwright/test';

export class TodoPage {
  readonly page: Page;
  readonly newTodoInput: Locator;
  readonly todoItems: Locator;

  constructor(page: Page) {
    this.page = page;
    this.newTodoInput = page.locator('input.new-todo');
    this.todoItems = page.locator('ul.todo-list li');
  }

  async goto() {
    await this.page.goto('https://demo.playwright.dev/todomvc');
  }

  async addTodo(text: string) {
    await this.newTodoInput.fill(text);
    await this.newTodoInput.press('Enter');
  }
}

// private パターン（カプセル化重視）
export class LoginPage {
  private page: Page;
  private usernameInput: Locator;
  private passwordInput: Locator;

  constructor(page: Page) {
    this.page = page;
    this.usernameInput = page.getByPlaceholder('Username');
    this.passwordInput = page.getByPlaceholder('Password');
  }

  async login(username: string, password: string) {
    await this.usernameInput.fill(username);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }
}
```

**選択基準:**
- `readonly`: プロパティの不変性を保証したい場合
- `private`: 外部からのアクセスを防ぎたい場合
- どちらもPOMパターンとして有効

#### JSDocによるドキュメント化

```typescript
/**
 * ログイン処理を実行する
 * @param {string} username - ログインに使用するユーザー名
 * @param {string} password - ログインに使用するパスワード
 */
async login(username: string, password: string) {
  await this.usernameInput.fill(username);
  await this.passwordInput.fill(password);
  await this.submitButton.click();
}
```

**重要な原則:**
- ページオブジェクト内にアサーションを含めない
- アサーションはテストファイル内で実行する
- ページオブジェクトは操作とセレクターのみを管理

---

## テストデータ管理による保守性向上

テストデータの管理方法は、テストスイートの脆弱性に直結します。適切なデータ管理により、環境変化や要件変更に対する耐性が向上します。

### ハードコーディングのリスク

**問題点:**
- 同じデータが複数のテストに重複
- 環境ごとに異なる値が必要
- データ変更時に多数のファイルを修正
- 動的データ（タイムスタンプ、ID）の扱いが困難

**解決策: 設定ファイルによるデータ集約**

```json
// config.json
{
  "baseUrl": "https://www.saucedemo.com/",
  "users": {
    "standard": {
      "username": "standard_user",
      "password": "secret_sauce"
    },
    "admin": {
      "username": "problem_user",
      "password": "secret_sauce"
    }
  }
}
```

```typescript
import { test, expect } from '@playwright/test';
import config from '../config.json';

test('successful login with standard user', async ({ page }) => {
  await page.goto(config.baseUrl);
  await page.getByPlaceholder('Username').fill(config.users.standard.username);
  await page.getByPlaceholder('Password').fill(config.users.standard.password);
  await page.getByRole('button', { name: 'Login' }).click();
  await expect(page).toHaveURL('https://www.saucedemo.com/inventory.html');
});
```

**環境別設定:**
- `config.dev.json` / `config.prod.json` を用意
- `process.env.NODE_ENV` で切り替え
- 変更は1ファイルのみで完結

**TypeScript連携:**
`tsconfig.json` で `resolveJsonModule: true` を有効化すると、JSONファイルのimportで型推論と補完が利用可能。

### Fixtureによるデータ管理

ログイン状態を共有するFixtureを作成し、テストデータと認証処理を統合します。

```typescript
import { expect, test as baseTest, Page } from '@playwright/test';
import config from '../config.json';

type MyFixtures = {
  loggedInPage: Page;
};

export const test = baseTest.extend<MyFixtures>({
  loggedInPage: async ({ page }, use) => {
    await page.goto(config.baseUrl);
    await page.getByPlaceholder('Username').fill(config.users.standard.username);
    await page.getByPlaceholder('Password').fill(config.users.standard.password);
    await page.getByRole('button', { name: 'Login' }).click();
    await use(page);
  },
});
```

**テストでの使用:**

```typescript
import { test } from '../fixtures/test-setup';
import { expect } from '@playwright/test';

test('access cart after login', async ({ loggedInPage }) => {
  await loggedInPage.goto('https://www.saucedemo.com/cart.html');
  await expect(loggedInPage.getByRole('button', { name: 'Checkout' })).toBeVisible();
});
```

**メリット:**
- テストコードからデータ管理ロジックを分離
- ログイン処理の変更時はFixtureのみ更新
- テストは本質的な検証に集中できる

### Faker.jsによる動的データ生成

一意性が必要な入力（ユーザー登録、フォーム送信など）では、ハードコーディングはデータ衝突を引き起こします。Faker.jsでランダムな実データを生成できます。

```bash
npm install @faker-js/faker --save-dev
```

```typescript
import { test, expect } from '@playwright/test';
import { faker } from '@faker-js/faker';

test('register new user', async ({ page }) => {
  const username = faker.internet.userName();
  const email = faker.internet.email();
  const password = faker.internet.password();

  await page.goto('/login');
  await page.getByPlaceholder('Username').fill(username);
  await page.getByPlaceholder('Email').fill(email);
  await page.getByPlaceholder('Password').fill(password);
  await page.getByRole('button', { name: 'Submit' }).click();

  await expect(page.locator('#success-message')).toHaveText(`Account created for ${username}`);
});
```

**利点:**
- 実行ごとに新しいデータ生成
- データ衝突の回避
- 要件変更時はFaker呼び出しのみ更新

### Factory PatternとBuilder Patternによるテストデータ管理

複雑なテストデータは、Factory PatternやBuilder Patternでカプセル化すると保守性が向上します。

**Factory Pattern:**

```typescript
// test/factories/user-factory.ts
import { faker } from '@faker-js/faker';

export class UserFactory {
  static create(overrides?: Partial<User>): User {
    return {
      id: faker.string.uuid(),
      username: faker.internet.userName(),
      email: faker.internet.email(),
      firstName: faker.person.firstName(),
      lastName: faker.person.lastName(),
      createdAt: new Date(),
      ...overrides, // 必要なフィールドのみ上書き
    };
  }

  static createAdmin(overrides?: Partial<User>): User {
    return this.create({
      role: 'admin',
      permissions: ['read', 'write', 'delete'],
      ...overrides,
    });
  }

  static createGuest(overrides?: Partial<User>): User {
    return this.create({
      role: 'guest',
      permissions: ['read'],
      ...overrides,
    });
  }
}

// テストでの使用
test('admin can delete users', async ({ page }) => {
  const admin = UserFactory.createAdmin();
  const targetUser = UserFactory.create({ username: 'target-user' });

  // APIでユーザー作成
  await page.request.post('/api/users', { data: admin });
  await page.request.post('/api/users', { data: targetUser });

  // UIでテスト実行
  await page.goto('/admin/users');
  await page.getByText(targetUser.username).click();
  await page.getByRole('button', { name: 'Delete' }).click();

  await expect(page.getByText('User deleted')).toBeVisible();
});
```

**Builder Pattern:**

```typescript
// test/builders/product-builder.ts
export class ProductBuilder {
  private product: Partial<Product> = {};

  withName(name: string): this {
    this.product.name = name;
    return this;
  }

  withPrice(price: number): this {
    this.product.price = price;
    return this;
  }

  withCategory(category: string): this {
    this.product.category = category;
    return this;
  }

  inStock(quantity: number): this {
    this.product.stock = quantity;
    this.product.available = true;
    return this;
  }

  outOfStock(): this {
    this.product.stock = 0;
    this.product.available = false;
    return this;
  }

  build(): Product {
    return {
      id: faker.string.uuid(),
      name: this.product.name || faker.commerce.productName(),
      price: this.product.price || parseFloat(faker.commerce.price()),
      category: this.product.category || 'General',
      stock: this.product.stock ?? 100,
      available: this.product.available ?? true,
      createdAt: new Date(),
    };
  }
}

// テストでの使用
test('out of stock product cannot be purchased', async ({ page }) => {
  const outOfStockProduct = new ProductBuilder()
    .withName('Limited Edition Item')
    .withPrice(99.99)
    .outOfStock()
    .build();

  await page.request.post('/api/products', { data: outOfStockProduct });

  await page.goto(`/products/${outOfStockProduct.id}`);
  const addToCartButton = page.getByRole('button', { name: 'Add to cart' });

  await expect(addToCartButton).toBeDisabled();
  await expect(page.getByText('Out of stock')).toBeVisible();
});
```

**Fixtureとの統合:**

```typescript
type TestDataFixtures = {
  userFactory: typeof UserFactory;
  productBuilder: typeof ProductBuilder;
};

export const test = base.extend<TestDataFixtures>({
  userFactory: async ({}, use) => await use(UserFactory),
  productBuilder: async ({}, use) => await use(ProductBuilder),
});

test('user can purchase in-stock products', async ({ page, userFactory, productBuilder }) => {
  const user = userFactory.create();
  const product = productBuilder.inStock(5).build();

  // テストデータのセットアップはファクトリに委譲
  await setupTestData({ user, product });

  // UIテストに集中
  await page.goto('/products');
  await page.getByText(product.name).click();
  await page.getByRole('button', { name: 'Add to cart' }).click();

  await expect(page.locator('.cart-count')).toHaveText('1');
});
```

**メリット:**
- テストデータの生成ロジックを一元管理
- デフォルト値とカスタム値を柔軟に切り替え
- テストコードの可読性向上
- データモデル変更時の修正箇所を局所化

### APIモッキングによる外部依存排除

外部APIへの依存はテストの不安定性を引き起こします。Playwrightの`page.route()`でAPIレスポンスをモックできます。

```typescript
import { test, expect } from '@playwright/test';

test('displays mocked blog posts from JSONPlaceholder API', async ({ page }) => {
  await page.route('https://jsonplaceholder.typicode.com/posts', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([
        {
          userId: 1,
          id: 1,
          title: 'Mocked Post Title One',
          body: 'This is the body of the first mocked post.'
        },
        {
          userId: 1,
          id: 2,
          title: 'Mocked Post Title Two',
          body: 'Here\'s the second post body.'
        }
      ])
    });
  });

  const data = await page.evaluate(() =>
    fetch('https://jsonplaceholder.typicode.com/posts').then(r => r.json())
  );

  await expect(data[0].title).toBe('Mocked Post Title One');
  await expect(data[1].title).toBe('Mocked Post Title Two');
});
```

**仕組み:**
1. `page.route()` でAPIエンドポイントを傍受
2. `route.fulfill()` でモックレスポンスを返す
3. `page.evaluate()` でブラウザ内からfetch実行
4. モックデータがテストに供給される

**利点:**
- ネットワーク遅延の排除
- API障害やレート制限の影響を受けない
- テストの高速化と安定化
- エラー状態（404、500など）のテストが容易

**拡張パターン:**
- `mocks/profile.json` として外部ファイル化
- 複数のテストケース用に異なるモックを用意
- エラー状態や空データのエッジケーステスト

### テストの独立性とクリーンアップ戦略

テストの独立性を確保するには、共有状態の排除と適切なクリーンアップが不可欠です。

**アンチパターン: 共有状態による汚染**

```typescript
// ❌ 悪い例: グローバル変数による共有状態
let currentUser: User;

test('create user', async ({ page }) => {
  currentUser = await createUser('john');
  // 次のテストがcurrentUserに依存してしまう
});

test('delete user', async ({ page }) => {
  // 前のテストの実行順序に依存
  await deleteUser(currentUser.id);
});
```

**ベストプラクティス: 各テストで独立したデータ作成**

```typescript
// ✅ 良い例: 各テストで独立したデータを作成
test('create user', async ({ page }) => {
  const user = await createUser('john');
  // このテストのみで使用
  await expect(page.getByText(user.name)).toBeVisible();
});

test('delete user', async ({ page }) => {
  // 独自のデータを作成
  const user = await createUser('jane');
  await deleteUser(user.id);
  await expect(page.getByText('User deleted')).toBeVisible();
});
```

**Fixtureによる自動クリーンアップ**

```typescript
type MyFixtures = {
  testUser: User;
};

export const test = base.extend<MyFixtures>({
  testUser: async ({ request }, use) => {
    // セットアップ: テスト用ユーザー作成
    const response = await request.post('/api/users', {
      data: UserFactory.create(),
    });
    const user = await response.json();

    await use(user); // テストに渡す

    // ティアダウン: 自動クリーンアップ
    await request.delete(`/api/users/${user.id}`);
  },
});

// テストは自動的にクリーンアップされる
test('user can update profile', async ({ page, testUser }) => {
  await page.goto(`/profile/${testUser.id}`);
  await page.fill('[name="bio"]', 'New bio');
  await page.click('button[type="submit"]');

  await expect(page.getByText('Profile updated')).toBeVisible();
  // testUserは自動的に削除される
});
```

**並列実行時の分離戦略**

```typescript
// データに一意性を持たせる
test('user registration', async ({ page }) => {
  const uniqueEmail = `test-${Date.now()}@example.com`;
  const user = UserFactory.create({ email: uniqueEmail });

  await page.goto('/signup');
  await page.fill('[name="email"]', user.email);
  await page.fill('[name="password"]', user.password);
  await page.click('button[type="submit"]');

  await expect(page.getByText('Registration successful')).toBeVisible();
});

// または、テストごとに専用のデータベーススキーマを使用
test.use({ dbSchema: `test_${Date.now()}` });
```

**共有リソースの適切な管理**

```typescript
// Worker scopeで共有しても安全なリソース
export const test = base.extend({
  sharedApiClient: [
    async ({}, use) => {
      const client = new ApiClient({ baseURL: 'https://api.example.com' });
      await use(client);
      await client.close();
    },
    { scope: 'worker' } // 状態を持たないクライアントは共有可能
  ],
});

// Test scopeで毎回新規作成すべきリソース
export const test = base.extend({
  isolatedDbConnection: async ({}, use) => {
    const db = await createTestDatabase();
    await use(db);
    await db.drop(); // 必ずクリーンアップ
  },
});
```

**原則:**
- 各テストは独立して実行可能であるべき
- テスト順序に依存してはならない
- グローバル変数や共有状態を避ける
- リソースは必ずクリーンアップする
- 並列実行を考慮してデータに一意性を持たせる

---

## まとめ: 保守性の高いテストスイート構築

- **describe()ブロック**: テストを論理的にグループ化し、可読性を向上
- **Fixture**: セットアップとテアダウンを宣言的に管理、DRY原則を実現
- **POM**: ページ固有のロジックをカプセル化、UI変更への耐性を向上
- **設定ファイル**: テストデータを集約し、環境別管理を容易化
- **Faker.js**: 動的データ生成で一意性を保証し、データ衝突を回避
- **Factory/Builder Pattern**: テストデータ生成ロジックを一元管理
- **APIモッキング**: 外部依存を排除し、テストの安定性と速度を向上
- **テストの独立性**: 共有状態を排除し、並列実行可能な設計を実現

これらのベストプラクティスにより、テストスイートは保守性が高く、変更に強く、長期的に信頼できる資産となります。
