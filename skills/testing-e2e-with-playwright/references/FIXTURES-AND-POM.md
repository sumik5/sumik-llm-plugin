# フィクスチャとPage Object Modelガイド

Playwrightのフィクスチャ機能とPage Object Model（POM）を組み合わせることで、保守性の高いE2Eテストを実現します。

---

## フィクスチャの役割

フィクスチャは**テストの依存関係を注入（DI）**する仕組みです。

### メリット

- **再利用性**: 同じPage Objectを複数のテストで使用
- **依存性管理**: Page Objectの初期化をフィクスチャで一元管理
- **型安全**: TypeScriptの型推論でIDE補完が効く

---

## 基本的なフィクスチャ定義

### 例: Page Object注入

```typescript
// fixtures/auth.fixture.ts
import { test as base } from "@playwright/test";
import { LoginPage } from "../pages/login.page";
import { OrderListPage } from "../pages/order-list.page";

type AuthFixtures = {
  authenticatedPage: Page;
  loginPage: LoginPage;
  orderPage: OrderListPage;
};

export const test = base.extend<AuthFixtures>({
  authenticatedPage: async ({ page }, use) => {
    // storageStateで認証済み状態が復元される
    await use(page);
  },
  loginPage: async ({ page }, use) => {
    await use(new LoginPage(page));
  },
  orderPage: async ({ page }, use) => {
    await use(new OrderListPage(page));
  },
});

export { expect } from "@playwright/test";
```

### テストでの使用

```typescript
import { test, expect } from "../fixtures/auth.fixture";

test("注文一覧を表示できる", async ({ orderPage }) => {
  await orderPage.goto();
  await expect.poll(() => orderPage.getOrderCount()).toBeGreaterThan(0);
});
```

**ポイント**:
- `{ orderPage }` で自動的に `OrderListPage` のインスタンスが注入される
- `new OrderListPage(page)` を毎回書く必要がない

---

## Page Object Model（POM）の設計原則

### 原則1: 基底クラスで共通処理を実装

```typescript
// pages/base.page.ts
import { type Page } from "@playwright/test";

export abstract class BasePage {
  constructor(protected readonly page: Page) {}

  /** ページ遷移して読み込み完了まで待機 */
  async navigate(path: string): Promise<void> {
    await this.page.goto(path);
    await this.page.waitForLoadState("domcontentloaded");
  }

  /** トースト通知のテキストを取得 */
  async getToastMessage(): Promise<string | null> {
    const toast = this.page.locator('[role="status"]').first();
    if (await toast.isVisible({ timeout: 5_000 }).catch(() => false)) {
      return toast.textContent();
    }
    return null;
  }

  /** ローディングスピナーが消えるまで待機 */
  async waitForLoading(): Promise<void> {
    const spinner = this.page.locator('[role="progressbar"]').first();
    if (await spinner.isVisible({ timeout: 2_000 }).catch(() => false)) {
      await spinner.waitFor({ state: "hidden", timeout: 30_000 });
    }
  }
}
```

**メリット**:
- 共通処理を一箇所で管理
- すべてのPage Objectで利用可能

---

### 原則2: ロケーターはプロパティで定義

```typescript
// pages/order-list.page.ts
import { BasePage } from "./base.page";

export class OrderListPage extends BasePage {
  // ロケーターはプロパティで定義（private readonly推奨）
  private readonly orderTable = this.page.locator("table");
  private readonly syncButton = this.page.getByRole("button", { name: "最新注文取得" });

  async goto(): Promise<void> {
    await this.navigate("/order");
  }

  async clickTab(tabName: string): Promise<void> {
    await this.page.getByRole("tab", { name: tabName }).click();
    await this.waitForLoading();
  }

  async getOrderCount(): Promise<number> {
    await this.page.locator("table tbody tr")
      .first()
      .waitFor({ state: "visible", timeout: 10_000 });
    const rows = this.orderTable.locator("tbody tr");
    return rows.count();
  }
}
```

**ポイント**:
- ロケーターを変数に格納することで、変更時の修正箇所が1箇所になる
- `private readonly` で外部からの変更を防ぐ

---

### 原則3: ビジネスロジックをメソッド化

```typescript
export class ShippingPurchasePage extends BasePage {
  async selectCarrierService(serviceName: string): Promise<void> {
    // 画像のalt属性で選択（キャリアサービス）
    const carrierImg = this.page.getByAltText(serviceName, { exact: true });
    await expect(carrierImg).toBeVisible({ timeout: 10_000 });
    await carrierImg.scrollIntoViewIfNeeded();
    await carrierImg.click();
  }

  async purchase(): Promise<void> {
    // ダイアログハンドラを先に設定
    this.page.once("dialog", (dialog) => dialog.accept());

    const purchaseBtn = this.page.getByRole("button", {
      name: /配送料を支払う|購入|送り状の支払いへ進む/,
    });
    await expect(purchaseBtn).toBeEnabled({ timeout: 15_000 });
    await purchaseBtn.click();

    // ダイアログ内の確認ボタンをクリック（ダイアログ表示を待機）
    const confirmBtn = this.page.getByRole("button", {
      name: "配送料を支払う",
    });
    await expect(confirmBtn).toBeVisible({ timeout: 10_000 });
    await expect(confirmBtn).toBeEnabled();
    await confirmBtn.click();
  }
}
```

**メリット**:
- テストコードが簡潔になる
- ビジネスロジックの変更に強い（メソッド内を修正すれば全テストに反映）

---

## 高度なフィクスチャパターン

### パターン1: テストデータフィクスチャ

```typescript
// fixtures/seed-data.fixture.ts
import { readFileSync } from "fs";
import { resolve } from "path";

interface SeedUser {
  username: string;
  email: string;
  password: string;
}

const SEED_USERS_PATH = resolve(__dirname, "../../scripts/seed-users.json");
let cachedUsers: SeedUser[] | null = null;

export function getSeedUsers(): SeedUser[] {
  if (!cachedUsers) {
    const json = readFileSync(SEED_USERS_PATH, "utf8");
    cachedUsers = JSON.parse(json);
  }
  return cachedUsers;
}

export function getTestUser(): SeedUser {
  const users = getSeedUsers();
  const user = users.find((u) => u.username === "test-user@example.com");
  if (!user) throw new Error("テストユーザーが見つかりません");
  return user;
}
```

**使用例**:
```typescript
import { getTestUser } from "../fixtures/seed-data.fixture";

test("ログインできる", async ({ page }) => {
  const user = getTestUser();
  await page.goto("/login");
  await page.locator("#email").fill(user.email);
  await page.locator("#password").fill(user.password);
  await page.getByRole("button", { name: "ログイン" }).click();
});
```

---

### パターン2: セットアップフィクスチャ

認証状態を事前に作成し、全テストで再利用します。

```typescript
// tests/auth.setup.ts
import { test as setup, expect } from "@playwright/test";
import { mkdirSync } from "fs";
import { dirname } from "path";

const authFile = ".auth/user.json";

setup("テストユーザーでログイン", async ({ page }) => {
  mkdirSync(dirname(authFile), { recursive: true });

  await page.goto("/login");
  await page.waitForLoadState("domcontentloaded");

  // ログインボタンが有効になるまで待機
  const loginButton = page.getByRole("button", { name: "ログイン" });
  await expect(loginButton).toBeEnabled({ timeout: 30_000 });

  await page.locator("#email").fill("test-user@example.com");
  await page.locator("#password").fill("Test1234!@");
  await loginButton.click();

  await page.waitForURL("**/order");

  // 認証状態を保存
  await page.context().storageState({ path: authFile });
});
```

**playwright.config.ts での設定**:
```typescript
export default defineConfig({
  projects: [
    {
      name: "setup",
      testMatch: /.*\.setup\.ts/,
    },
    {
      name: "chromium",
      use: {
        storageState: ".auth/user.json",  // セットアップで作成した認証状態を読み込む
      },
      dependencies: ["setup"],           // セットアップ完了後に実行
    },
  ],
});
```

---

## Page Object設計のベストプラクティス

### ✅ Good: メソッドは再利用可能に設計

```typescript
// ✅ 汎用的なメソッド
async clickTab(tabName: string): Promise<void> {
  await this.page.getByRole("tab", { name: tabName }).click();
  await this.waitForLoading();
}

// テストで使用
await orderPage.clickTab("未発送");
await orderPage.clickTab("送り状購入済み");
```

---

### ✅ Good: アサーションはテスト側に書く

```typescript
// ✅ Page Objectは値を返すだけ
async getOrderCount(): Promise<number> {
  const rows = this.orderTable.locator("tbody tr");
  return rows.count();
}

// テスト側でアサーション
test("注文が1件以上ある", async ({ orderPage }) => {
  await orderPage.goto();
  const count = await orderPage.getOrderCount();
  expect(count).toBeGreaterThan(0);
});
```

---

### ❌ Bad: Page Objectにアサーションを含める

```typescript
// ❌ Page Object内でアサーション（柔軟性が低い）
async assertOrderExists(): Promise<void> {
  const count = await this.orderTable.locator("tbody tr").count();
  expect(count).toBeGreaterThan(0);  // ここでアサーション
}
```

**理由**: テストによってアサーション内容が異なる場合に対応できない。

---

### ✅ Good: 複雑な待機処理はメソッドに隠蔽

```typescript
async getOrderCountWithRetry(maxRetries = 2): Promise<number> {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    const count = await this.getOrderCount();
    if (count > 0) return count;

    if (attempt < maxRetries) {
      await this.page.reload({ timeout: 15_000 });
      await this.page.waitForLoadState("domcontentloaded");
      await this.page.locator("table tbody tr")
        .first()
        .waitFor({ state: "visible", timeout: 10_000 })
        .catch(() => {});
    }
  }
  return 0;
}
```

**メリット**:
- テストコードから複雑なリトライロジックを隠蔽
- 再利用性が高い

---

## よくある罠

### 罠1: Page Objectでページ遷移を待たない

```typescript
// ❌ 遷移後の待機がない
async clickOrderByName(orderName: string): Promise<void> {
  const row = this.orderTable.locator("tbody tr").filter({ hasText: orderName });
  await row.locator("td").first().click();
  // ここで遷移待機がない
}

// ✅ 遷移を待機
async clickOrderByName(orderName: string): Promise<void> {
  const row = this.orderTable.locator("tbody tr").filter({ hasText: orderName });
  await row.locator("td").first().click();
  await this.page.waitForURL(/\/(shippings|print)\//);  // 遷移を待つ
}
```

---

### 罠2: フィクスチャのスコープ漏れ

```typescript
// ❌ テストケース外でPage Objectを初期化（フィクスチャの意味がない)
const orderPage = new OrderListPage(page);

test("注文を表示", async () => {
  await orderPage.goto();
});

// ✅ フィクスチャで注入
test("注文を表示", async ({ orderPage }) => {
  await orderPage.goto();
});
```

---

## まとめ

- **フィクスチャ**: Page Objectの注入・認証状態の管理に使用
- **Base Page**: 共通処理を基底クラスで実装
- **ロケーターはプロパティ**: 変更時の修正箇所を最小化
- **ビジネスロジックをメソッド化**: テストコードを簡潔に
- **アサーションはテスト側**: Page Objectは値を返すだけ
