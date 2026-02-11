# E2Eテスト: 実践的なパターン設計

## 概要

実際のE-Commerceプロジェクト等、実践的なWebアプリケーションテストには、適切なプロジェクト構造、認証管理、データファクトリー、テスト分離戦略が必要です。このガイドでは、Playwrightを使った本番レベルのE2Eテストプロジェクトの設計方法を解説します。

---

## プロジェクトディレクトリ構成のベストプラクティス

### 推奨ディレクトリ構造

```
project-root/
├── tests/
│   ├── auth/
│   │   ├── login.spec.ts
│   │   └── logout.spec.ts
│   ├── cart/
│   │   ├── add-to-cart.spec.ts
│   │   └── checkout.spec.ts
│   └── product/
│       └── product-search.spec.ts
├── pages/
│   ├── LoginPage.ts
│   ├── ProductPage.ts
│   └── CartPage.ts
├── fixtures/
│   ├── test-data.json
│   └── users.json
├── helpers/
│   ├── auth.ts
│   ├── api.ts
│   └── data-factory.ts
├── setup/
│   └── auth.setup.ts
├── storage/
│   ├── admin.json
│   ├── user.json
│   └── guest.json
└── playwright.config.ts
```

---

## Page Object Model (POM) パターン

### 基本的なPageクラス

```typescript
// pages/LoginPage.ts
import { Page, Locator } from '@playwright/test';

export class LoginPage {
  readonly page: Page;
  readonly usernameInput: Locator;
  readonly passwordInput: Locator;
  readonly loginButton: Locator;
  readonly errorMessage: Locator;

  constructor(page: Page) {
    this.page = page;
    this.usernameInput = page.getByPlaceholder('Username');
    this.passwordInput = page.getByPlaceholder('Password');
    this.loginButton = page.getByRole('button', { name: 'Login' });
    this.errorMessage = page.locator('[data-test="error"]');
  }

  async goto() {
    await this.page.goto('https://www.saucedemo.com/');
  }

  async login(username: string, password: string) {
    await this.usernameInput.fill(username);
    await this.passwordInput.fill(password);
    await this.loginButton.click();
  }

  async expectError(message: string) {
    await this.errorMessage.toBeVisible();
    await this.errorMessage.toContainText(message);
  }
}
```

### テストでの使用

```typescript
// tests/auth/login.spec.ts
import { test, expect } from '@playwright/test';
import { LoginPage } from '../../pages/LoginPage';

test('無効な認証情報でログイン失敗', async ({ page }) => {
  const loginPage = new LoginPage(page);

  await loginPage.goto();
  await loginPage.login('invalid_user', 'wrong_password');
  await loginPage.expectError('Username and password do not match');
});
```

---

## storageState による認証管理

### セットアップファイル

```typescript
// setup/auth.setup.ts
import { test as setup } from '@playwright/test';
import { LoginPage } from '../pages/LoginPage';

setup('標準ユーザーで認証', async ({ page }) => {
  const loginPage = new LoginPage(page);
  await loginPage.goto();
  await loginPage.login('standard_user', 'secret_sauce');

  await page.waitForURL('**/inventory.html');
  await page.context().storageState({ path: 'storage/standard-user.json' });
});

setup('管理者で認証', async ({ page }) => {
  const loginPage = new LoginPage(page);
  await loginPage.goto();
  await loginPage.login('admin', 'admin_password');

  await page.waitForURL('**/dashboard');
  await page.context().storageState({ path: 'storage/admin.json' });
});
```

### playwright.config.ts 設定

```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },
    {
      name: 'authenticated',
      dependencies: ['setup'],
      use: { storageState: 'storage/standard-user.json' },
    },
    {
      name: 'admin',
      dependencies: ['setup'],
      use: { storageState: 'storage/admin.json' },
    },
  ],
});
```

---

## データファクトリーパターン

### ファクトリー関数

```typescript
// helpers/data-factory.ts
import { faker } from '@faker-js/faker';

export interface User {
  username: string;
  email: string;
  password: string;
  firstName: string;
  lastName: string;
}

export interface Product {
  name: string;
  price: number;
  category: string;
  sku: string;
}

export class DataFactory {
  static createUser(overrides?: Partial<User>): User {
    return {
      username: faker.internet.userName(),
      email: faker.internet.email(),
      password: faker.internet.password({ length: 12 }),
      firstName: faker.person.firstName(),
      lastName: faker.person.lastName(),
      ...overrides
    };
  }

  static createProduct(overrides?: Partial<Product>): Product {
    return {
      name: faker.commerce.productName(),
      price: parseFloat(faker.commerce.price()),
      category: faker.commerce.department(),
      sku: faker.string.alphanumeric(10).toUpperCase(),
      ...overrides
    };
  }

  static createUsers(count: number): User[] {
    return Array.from({ length: count }, () => this.createUser());
  }
}
```

### テストでの使用

```typescript
// tests/user-registration.spec.ts
import { test, expect } from '@playwright/test';
import { DataFactory } from '../helpers/data-factory';

test('新規ユーザー登録', async ({ page }) => {
  const user = DataFactory.createUser();

  await page.goto('https://example.com/register');
  await page.fill('[name="username"]', user.username);
  await page.fill('[name="email"]', user.email);
  await page.fill('[name="password"]', user.password);
  await page.click('button[type="submit"]');

  await expect(page).toHaveURL(/dashboard/);
});
```

---

## テスト間のデータ分離

### test.use() でストレージをリセット

```typescript
test.use({
  storageState: { cookies: [], origins: [] },  // 各テストで新規セッション
});

test('独立したカートテスト', async ({ page }) => {
  // 前のテストのカート状態に影響されない
  await page.goto('https://example.com/cart');
  await expect(page.locator('.cart-item')).toHaveCount(0);
});
```

### beforeEach でクリーンアップ

```typescript
test.describe('カート操作', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('https://example.com/');
    await page.evaluate(() => {
      localStorage.clear();
      sessionStorage.clear();
    });
  });

  test('カートに商品追加', async ({ page }) => {
    // クリーンな状態から開始
  });
});
```

---

## 負荷テスト用のバルクデータ生成

### ユーザー一括登録スクリプト

```typescript
// scripts/bulk-user-registration.ts
import { chromium } from '@playwright/test';
import { DataFactory } from '../helpers/data-factory';

async function bulkRegister(count: number) {
  const browser = await chromium.launch();
  const users = DataFactory.createUsers(count);

  for (const user of users) {
    const context = await browser.newContext();
    const page = await context.newPage();

    await page.goto('https://example.com/register');
    await page.fill('[name="username"]', user.username);
    await page.fill('[name="email"]', user.email);
    await page.fill('[name="password"]', user.password);
    await page.click('button[type="submit"]');

    await page.waitForURL(/dashboard/);
    console.log(`✅ Registered: ${user.username}`);

    await context.close();
  }

  await browser.close();
}

bulkRegister(100);  // 100ユーザーを登録
```

### 並列実行での高速化

```typescript
async function bulkRegisterParallel(count: number, concurrency: number = 5) {
  const browser = await chromium.launch();
  const users = DataFactory.createUsers(count);

  const chunks = [];
  for (let i = 0; i < users.length; i += concurrency) {
    chunks.push(users.slice(i, i + concurrency));
  }

  for (const chunk of chunks) {
    await Promise.all(chunk.map(async (user) => {
      const context = await browser.newContext();
      const page = await context.newPage();

      await page.goto('https://example.com/register');
      await page.fill('[name="username"]', user.username);
      await page.fill('[name="email"]', user.email);
      await page.fill('[name="password"]', user.password);
      await page.click('button[type="submit"]');

      await page.waitForURL(/dashboard/);
      console.log(`✅ ${user.username}`);

      await context.close();
    }));
  }

  await browser.close();
}

bulkRegisterParallel(100, 10);  // 10並列で100ユーザー登録
```

---

## E-Commerce プロジェクトのテストパターン

### カート操作の統合テスト

```typescript
// tests/cart/full-checkout.spec.ts
test('商品追加からチェックアウトまでの完全フロー', async ({ page }) => {
  const product = DataFactory.createProduct();

  // 1. 商品ページへ遷移
  await page.goto('https://example.com/products');

  // 2. 商品をカートに追加
  await page.click(`[data-product="${product.sku}"]`);
  await page.click('button:has-text("Add to Cart")');
  await expect(page.locator('.cart-badge')).toHaveText('1');

  // 3. カートページで確認
  await page.goto('https://example.com/cart');
  await expect(page.locator('.cart-item')).toHaveCount(1);

  // 4. チェックアウト
  await page.click('button:has-text("Checkout")');
  await page.fill('[name="address"]', '123 Test St');
  await page.fill('[name="city"]', 'Test City');
  await page.fill('[name="zip"]', '12345');
  await page.click('button:has-text("Place Order")');

  // 5. 注文確認
  await expect(page).toHaveURL(/order-confirmation/);
  await expect(page.locator('.order-success')).toBeVisible();
});
```

---

## チェックリスト: 実践的テストパターン

- [ ] Page Object Model (POM) でコード再利用性を確保
- [ ] storageState で認証状態を効率的に管理
- [ ] データファクトリーでテストデータを自動生成
- [ ] beforeEach/afterEach でテスト間のデータ分離を実装
- [ ] test.describe でテストを論理的にグループ化
- [ ] 並列実行を考慮したテスト設計
- [ ] 負荷テスト用のバルクデータ生成スクリプトを用意
- [ ] 環境ごとの設定ファイルを分離（dev/staging/prod）
- [ ] CI/CD パイプラインとの統合を考慮
- [ ] テストレポート自動生成（HTML/JSON形式）

---

## ベストプラクティス

1. **ディレクトリ構造の一貫性:** `tests/`, `pages/`, `helpers/`, `fixtures/` を明確に分離
2. **POM の適切な粒度:** ページごとに1クラス、複雑なコンポーネントは別クラス化
3. **データファクトリーの活用:** ハードコードされたテストデータを避ける
4. **storageState の再利用:** 毎回ログインせず、保存済みセッションを活用
5. **並列実行の最適化:** 依存関係のないテストは並列化、共有リソースは直列化
6. **環境変数の活用:** `.env` ファイルで環境ごとの設定を管理
7. **CI/CD統合:** GitHub Actions/Jenkins等でテスト自動実行
