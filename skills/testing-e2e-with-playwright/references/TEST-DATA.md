# テストデータ管理ガイド

E2Eテストの信頼性は**テストデータの管理**に大きく依存します。このドキュメントではデータ分離・シードデータ・データ駆動テストの実践パターンを解説します。

---

## テストデータ分離の原則

### 原則1: 各テストケースは専用データを使用

**並列実行時の競合を防ぐため、各テストに専用のデータを割り当てます。**

```typescript
// ❌ 全テストで同じ注文を使用（競合）
test("購入テスト1", async () => {
  await orderPage.clickOrderByName("#1001");
  await shippingPage.purchase();  // 状態変更
});

test("購入テスト2", async () => {
  await orderPage.clickOrderByName("#1001");  // 競合！（前のテストで購入済み）
  await shippingPage.purchase();
});
```

---

```typescript
// ✅ 各テストが専用データを使用
test("購入テスト1", async () => {
  await orderPage.clickOrderByName("#1001");  // 専用
  await shippingPage.purchase();
});

test("購入テスト2", async () => {
  await orderPage.clickOrderByName("#1002");  // 専用
  await shippingPage.purchase();
});
```

---

### 原則2: 読み取り専用データは共有可能

**データを変更しないテストは、同じデータを複数のテストで使用できます。**

```typescript
// ✅ 送料確認テスト（データ変更なし）
test("送料確認1", async () => {
  await orderPage.clickOrderByName("#1004");
  const fee = await shippingPage.getShippingFee();
  expect(fee).toMatch(/¥|円/);
  // 購入しない → データ変更なし
});

test("送料確認2", async () => {
  await orderPage.clickOrderByName("#1004");  // 共有可能
  const fee = await shippingPage.getShippingFee();
  expect(fee).toBeDefined();
});
```

---

### 原則3: 自己完結型テスト（推奨）

**テスト内でデータ作成・変更・削除を完結**させると、他のテストへの影響がありません。

```typescript
test("送り状キャンセル後に再購入できる", async () => {
  // Step 1: 購入
  await orderPage.clickOrderByName("#2004");
  await shippingPage.purchase();

  // Step 2: キャンセル
  await shippingPage.cancel();

  // Step 3: 再購入
  await orderPage.clickOrderByName("#2004");
  await shippingPage.purchase();

  // ✅ 自己完結（他のテストに影響なし）
});
```

---

## シードデータ駆動テスト

### パターン1: JSON定数ファイル

```typescript
// helpers/test-data.ts
export const TEST_USERS = {
  testUser: {
    email: "test-user@example.com",
    password: "Test1234!@",
  },
  adminUser: {
    email: "admin@example.com",
    password: "Admin1234!@",
  },
} as const;

export const CARRIER_SERVICES = {
  japanpost: {
    yuupack: "ゆうパック",
    yuupacket: "ゆうパケット",
  },
  yamato: {
    takkyubin: "宅急便",
    eazy: "EAZY",
  },
} as const;

export const TEST_CREDIT_CARD = {
  number: "4111111111111111",
  expiry: "12/30",
  cvc: "123",
  name: "TEST USER",
} as const;
```

**使用例**:
```typescript
import { TEST_USERS, CARRIER_SERVICES } from "../helpers/test-data";

test("ログインできる", async ({ page }) => {
  await page.goto("/login");
  await page.locator("#email").fill(TEST_USERS.testUser.email);
  await page.locator("#password").fill(TEST_USERS.testUser.password);
  await page.getByRole("button", { name: "ログイン" }).click();
});

test("ゆうパックを選択できる", async ({ shippingPage }) => {
  await shippingPage.selectCarrierService(CARRIER_SERVICES.japanpost.yuupack);
});
```

---

### パターン2: 外部JSONファイル読み込み

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

## データ駆動テスト（パラメトライズ）

### パターン1: テストケースを配列で定義

```typescript
const testCases = [
  { carrier: "ゆうパック", order: "#1001", size: "80サイズ" },
  { carrier: "飛脚宅配便", order: "#1002", size: "100サイズ" },
  { carrier: "宅急便", order: "#1003", size: "80サイズ" },
];

testCases.forEach(({ carrier, order, size }) => {
  test(`${carrier}の送り状を購入できる`, async ({ orderPage, shippingPage }) => {
    await orderPage.goto();
    await orderPage.clickTab("未発送");
    await orderPage.clickOrderByName(order);
    await shippingPage.selectCarrierService(carrier);
    await shippingPage.selectPackageSize(size);
    await shippingPage.purchase();
    await expect(page).toHaveURL(/\/print\//);
  });
});
```

**メリット**:
- テストコードの重複を削減
- データだけを変えて同じロジックをテスト

---

### パターン2: CSVデータ駆動（外部ファイル）

```typescript
// fixtures/csv-loader.ts
import { readFileSync } from "fs";
import { parse } from "csv-parse/sync";

export function loadCSVTestData(filePath: string): Record<string, string>[] {
  const csv = readFileSync(filePath, "utf8");
  return parse(csv, { columns: true });
}
```

```typescript
// tests/csv-driven.spec.ts
import { loadCSVTestData } from "../fixtures/csv-loader";

const testData = loadCSVTestData("./test-data.csv");

testData.forEach((row) => {
  test(`${row.carrier} - ${row.testCase}`, async ({ orderPage, shippingPage }) => {
    await orderPage.clickOrderByName(row.orderName);
    await shippingPage.selectCarrierService(row.carrier);
    await shippingPage.purchase();
  });
});
```

---

## テストデータ管理のベストプラクティス

### ✅ Good: 定数で管理

```typescript
// ✅ 定数ファイルで一元管理
export const CARRIER_SERVICES = {
  japanpost: { yuupack: "ゆうパック" },
} as const;

// テストで使用
await shippingPage.selectCarrierService(CARRIER_SERVICES.japanpost.yuupack);
```

---

### ❌ Bad: テスト内にハードコード

```typescript
// ❌ テスト内にハードコード（変更時に全テスト修正が必要）
await shippingPage.selectCarrierService("ゆうパック");
```

---

### ✅ Good: 環境変数で切り替え

```typescript
// ✅ 環境変数でURLやユーザーを切り替え
const baseURL = process.env.BASE_URL || "http://localhost:3000";
const testUserEmail = process.env.TEST_USER_EMAIL || "test-user@example.com";
```

---

### ❌ Bad: 本番データを直接使用

```typescript
// ❌ 本番データを使用（テスト実行で本番データが変更される危険）
const prodUserEmail = "real-user@production.com";
```

---

## テストデータのライフサイクル

### セットアップフェーズ（Before）

```typescript
test.beforeEach(async ({ page }) => {
  // テスト前に初期データをセット
  await page.goto("/order");
  await page.getByRole("button", { name: "最新注文取得" }).click();
});
```

---

### クリーンアップフェーズ（After）

```typescript
test.afterEach(async ({ page }) => {
  // テスト後にクリーンアップ（不要なデータ削除）
  // 注意: E2Eでは通常、環境ごとリセットする方が確実
});
```

---

## よくある罠

### 罠1: テストデータの使い回し

```typescript
// ❌ 全テストで同じ注文を使用（並列実行で失敗）
test("購入1", async () => {
  await orderPage.clickOrderByName("#1001");
  await shippingPage.purchase();
});

test("購入2", async () => {
  await orderPage.clickOrderByName("#1001");  // 購入済みで失敗
});

// ✅ 専用データを使用
test("購入1", async () => {
  await orderPage.clickOrderByName("#1001");
});

test("購入2", async () => {
  await orderPage.clickOrderByName("#1002");
});
```

---

### 罠2: テスト順序への依存

```typescript
// ❌ テスト1の結果に依存（並列実行で失敗）
test("購入テスト", async () => {
  await shippingPage.purchase();  // #1001を購入
});

test("キャンセルテスト", async () => {
  await shippingPage.cancel();  // 前のテストで購入した注文をキャンセル
});

// ✅ 自己完結型
test("購入→キャンセル", async () => {
  await shippingPage.purchase();  // 購入
  await shippingPage.cancel();    // キャンセル（同じテスト内で完結）
});
```

---

### 罠3: 環境変数の未設定

```typescript
// ❌ 環境変数がないとテスト失敗
const apiKey = process.env.API_KEY;  // undefinedの可能性

// ✅ デフォルト値を設定
const apiKey = process.env.API_KEY || "test-api-key";
```

---

## まとめ

- **テストデータは専用化**: 各テストに専用データを割り当て
- **読み取り専用は共有可能**: データ変更しないテストは共有OK
- **自己完結型推奨**: テスト内でデータ作成・変更・削除を完結
- **定数ファイルで管理**: `helpers/test-data.ts` に一元管理
- **データ駆動テスト**: 同じロジックを異なるデータでテスト
- **環境変数活用**: URL・ユーザー等を環境ごとに切り替え
