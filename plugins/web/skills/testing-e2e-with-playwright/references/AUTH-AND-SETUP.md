# 認証セットアップとセッション管理ガイド

E2Eテストでは認証状態の管理が重要です。PlaywrightのstorageState機能を使用することで、効率的なテスト実行が可能になります。

---

## storageState とは

**ブラウザのストレージ状態（Cookie、LocalStorage）をファイルに保存し、他のテストで再利用する機能**です。

### メリット

- **高速化**: 全テストでログイン処理を実行する必要がない
- **安定性**: ログイン処理のフレークネスを最小化
- **並列実行**: 各テストが独立した認証状態を持てる

---

## 基本的なセットアップパターン

### Step 1: セットアップスクリプト作成

```typescript
// tests/auth.setup.ts
import { test as setup, expect } from "@playwright/test";
import { mkdirSync } from "fs";
import { dirname } from "path";

const authFile = ".auth/user.json";

setup("テストユーザーでログイン", async ({ page }) => {
  // ディレクトリ作成
  mkdirSync(dirname(authFile), { recursive: true });

  const email = process.env.TEST_USER_EMAIL || "test-user@example.com";
  const password = process.env.TEST_USER_PASSWORD || "Test1234!@";

  // ログインページに移動
  await page.goto("/login");
  await page.waitForLoadState("domcontentloaded");

  // ログインボタンが有効になるまで待機（Cognito等の初期化待ち）
  const loginButton = page.getByRole("button", { name: "ログイン" });
  await expect(loginButton).toBeEnabled({ timeout: 30_000 });

  // ログイン
  await page.locator("#email").fill(email);
  await page.locator("#password").fill(password);
  await loginButton.click();

  // ログイン成功を確認
  await page.waitForURL("**/order");
  await expect(page).toHaveURL(/\/order/);

  // 認証状態を保存
  await page.context().storageState({ path: authFile });
});
```

---

### Step 2: playwright.config.ts で設定

```typescript
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  projects: [
    // セットアップスクリプト
    {
      name: "setup",
      testMatch: /auth\.setup\.ts/,
    },
    // メインテスト
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        storageState: ".auth/user.json",  // 認証状態を読み込む
      },
      dependencies: ["setup"],            // セットアップ完了後に実行
    },
  ],
});
```

---

### Step 3: テストで認証済み状態を使用

```typescript
import { test, expect } from "@playwright/test";

test("注文一覧が表示される", async ({ page }) => {
  // すでにログイン済み（storageStateで復元）
  await page.goto("/order");
  await expect(page.getByText("注文一覧")).toBeVisible();
});
```

**ポイント**:
- `page.goto()` の時点ですでにログイン済み
- 毎回ログイン処理を実行する必要がない

---

## 複数ユーザーの認証状態管理

### パターン1: ユーザーごとにstorageStateを作成

```typescript
// tests/setup/admin.setup.ts
setup("管理者ユーザーでログイン", async ({ page }) => {
  mkdirSync(".auth", { recursive: true });

  await page.goto("/login");
  await page.locator("#email").fill("admin@example.com");
  await page.locator("#password").fill("Admin1234!@");
  await page.getByRole("button", { name: "ログイン" }).click();

  await page.waitForURL("**/admin");
  await page.context().storageState({ path: ".auth/admin.json" });
});

// tests/setup/user.setup.ts
setup("一般ユーザーでログイン", async ({ page }) => {
  mkdirSync(".auth", { recursive: true });

  await page.goto("/login");
  await page.locator("#email").fill("test-user@example.com");
  await page.locator("#password").fill("Test1234!@");
  await page.getByRole("button", { name: "ログイン" }).click();

  await page.waitForURL("**/order");
  await page.context().storageState({ path: ".auth/user.json" });
});
```

---

### パターン2: playwright.config.ts で複数プロジェクト定義

```typescript
export default defineConfig({
  projects: [
    // セットアップ
    { name: "setup-admin", testMatch: /admin\.setup\.ts/ },
    { name: "setup-user", testMatch: /auth\.setup\.ts/ },

    // 管理者テスト
    {
      name: "admin-tests",
      testMatch: /admin\.spec\.ts/,
      use: { storageState: ".auth/admin.json" },
      dependencies: ["setup-admin"],
    },

    // 一般ユーザーテスト
    {
      name: "user-tests",
      testMatch: /.*\.spec\.ts/,
      testIgnore: /admin\.spec\.ts/,
      use: { storageState: ".auth/user.json" },
      dependencies: ["setup-user"],
    },
  ],
});
```

---

## 未認証テストの実装

### storageState を無効化

```typescript
test.use({ storageState: { cookies: [], origins: [] } });

test("未ログイン時はログインページにリダイレクト", async ({ page }) => {
  await page.goto("/order");

  // ログインページにリダイレクトされることを確認
  await expect(page).toHaveURL(/\/login/);
});
```

**注意**: `storageState: undefined` だけでは不完全。明示的に空のstorageStateを設定すること。

---

## セットアップスクリプトのリトライ戦略

### パターン: ログインボタン有効化のリトライ

外部認証サービス（Cognito等）の初期化が遅い場合、リトライが必要です。

```typescript
setup("テストユーザーでログイン", async ({ page }) => {
  setup.setTimeout(180_000);  // タイムアウト延長
  mkdirSync(".auth", { recursive: true });

  await page.goto("/login", { timeout: 60_000 });
  // networkidle: 外部SDK（Cognito等）の読み込み完了を待つため例外的に使用
  await page.waitForLoadState("networkidle");

  // ログインボタンが有効になるまでリトライ
  const loginButton = page.getByRole("button", { name: "ログイン" });
  const MAX_RETRIES = 3;

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      await expect(loginButton).toBeEnabled({ timeout: 30_000 });
      break;
    } catch {
      if (attempt < MAX_RETRIES) {
        console.log(`ログインボタンdisabled、リトライ ${attempt}/${MAX_RETRIES}`);
        await page.reload({ timeout: 60_000 });
        await page.waitForLoadState("networkidle");
      }
    }
  }

  await page.locator("#email").fill("test-user@example.com");
  await page.locator("#password").fill("Test1234!@");
  await loginButton.click();

  await page.waitForURL("**/order");
  await page.context().storageState({ path: ".auth/user.json" });
});
```

**ポイント**:
- `networkidle` は例外的に使用（外部SDK読み込みのため）
- ログインボタンの有効化をリトライ
- タイムアウトを延長

---

## セットアップ後の追加処理

### パターン: データ同期

```typescript
setup("テストユーザーでログイン", async ({ page }) => {
  // ... ログイン処理 ...

  // 注文同期（E2E環境のデータ準備）
  const syncButton = page.getByRole("button", { name: "最新注文取得" });
  if (await syncButton.isVisible({ timeout: 10_000 }).catch(() => false)) {
    await syncButton.click();

    // 同期完了を待機（ローディングスピナーが消えるまで）
    await page.locator('[role="progressbar"]')
      .first()
      .waitFor({ state: "hidden", timeout: 30_000 })
      .catch(() => {});

    // データが表示されるのを待つ
    await page.locator("table tbody tr")
      .first()
      .waitFor({ state: "visible", timeout: 15_000 })
      .catch(() => {});
  }

  await page.context().storageState({ path: ".auth/user.json" });
});
```

---

## 認証トークンの動的更新

### パターン: APIトークンをstorageStateに追加

```typescript
setup("APIトークン付きでセットアップ", async ({ page }) => {
  // ログイン
  await page.goto("/login");
  await page.locator("#email").fill("test-user@example.com");
  await page.locator("#password").fill("Test1234!@");
  await page.getByRole("button", { name: "ログイン" }).click();

  await page.waitForURL("**/order");

  // LocalStorageにトークンを追加
  await page.evaluate(() => {
    localStorage.setItem("authToken", "test-bearer-token");
  });

  // storageStateに保存
  await page.context().storageState({ path: ".auth/user.json" });
});
```

---

## よくある罠

### 罠1: セットアップの依存関係未定義

```typescript
// ❌ dependencies が未定義（セットアップ完了前にテスト実行）
export default defineConfig({
  projects: [
    { name: "setup", testMatch: /auth\.setup\.ts/ },
    {
      name: "chromium",
      use: { storageState: ".auth/user.json" },
      // dependencies: ["setup"],  // ← 未定義
    },
  ],
});

// ✅ dependencies を定義
export default defineConfig({
  projects: [
    { name: "setup", testMatch: /auth\.setup\.ts/ },
    {
      name: "chromium",
      use: { storageState: ".auth/user.json" },
      dependencies: ["setup"],  // セットアップ完了後に実行
    },
  ],
});
```

---

### 罠2: `storageState: undefined` が不完全

```typescript
// ❌ セッションが残る可能性
test.use({ storageState: undefined });

// ✅ 明示的に空にする
test.use({ storageState: { cookies: [], origins: [] } });
```

---

### 罠3: セットアップファイルがテストとして実行される

```typescript
// ❌ auth.setup.ts が通常のテストとして実行される
export default defineConfig({
  testDir: "./tests",  // tests/ 配下すべてが実行される
  projects: [
    {
      name: "chromium",
      use: { storageState: ".auth/user.json" },
    },
  ],
});

// ✅ testMatch でセットアップファイルを分離
export default defineConfig({
  projects: [
    {
      name: "setup",
      testMatch: /.*\.setup\.ts/,  // セットアップファイルのみ
    },
    {
      name: "chromium",
      testMatch: /.*\.spec\.ts/,   // テストファイルのみ
      use: { storageState: ".auth/user.json" },
      dependencies: ["setup"],
    },
  ],
});
```

---

## まとめ

- **storageState**: 認証状態をファイルに保存・再利用
- **セットアップスクリプト**: 事前にログイン処理を実行
- **複数ユーザー**: ユーザーごとにstorageStateを作成
- **未認証テスト**: `storageState: { cookies: [], origins: [] }` で無効化
- **リトライ戦略**: 外部認証サービスの初期化待ち
- **依存関係定義**: `dependencies` でセットアップ完了後にテスト実行
