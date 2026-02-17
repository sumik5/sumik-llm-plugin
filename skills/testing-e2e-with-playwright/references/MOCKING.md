# APIモッキングとネットワークエミュレーションガイド

PlaywrightはネットワークレベルでのAPIモッキング・エミュレーション機能を提供します。外部API依存を排除し、テストの安定性と速度を向上させます。

---

## APIモッキングの用途

### ユースケース

1. **外部API依存の排除**: 外部サービス（Stripe、AWS等）への依存をモックで置き換え
2. **エラーシナリオのテスト**: 意図的に404・500エラーを返してエラーハンドリングを検証
3. **レスポンス遅延のシミュレーション**: タイムアウト処理のテスト
4. **並列実行の安定化**: 外部APIのレート制限を回避

---

## 基本的なAPIモッキング

### パターン1: 特定APIをモック

```typescript
test("APIモックで注文一覧を表示", async ({ page }) => {
  // /api/orders へのリクエストをモック
  await page.route("**/api/orders", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        orders: [
          { id: "1", name: "#1001", status: "pending" },
          { id: "2", name: "#1002", status: "shipped" },
        ],
      }),
    });
  });

  await page.goto("/order");
  await expect(page.getByText("#1001")).toBeVisible();
});
```

---

### パターン2: 複数エンドポイントをモック

```typescript
test("複数APIをモック", async ({ page }) => {
  // ユーザー情報
  await page.route("**/api/user", async (route) => {
    await route.fulfill({
      status: 200,
      body: JSON.stringify({ name: "Test User", email: "test@example.com" }),
    });
  });

  // 注文一覧
  await page.route("**/api/orders", async (route) => {
    await route.fulfill({
      status: 200,
      body: JSON.stringify({ orders: [] }),
    });
  });

  await page.goto("/order");
});
```

---

## エラーシナリオのテスト

### パターン1: 404エラー

```typescript
test("注文が見つからない場合のエラーメッセージ", async ({ page }) => {
  await page.route("**/api/orders/123", async (route) => {
    await route.fulfill({
      status: 404,
      body: JSON.stringify({ error: "Order not found" }),
    });
  });

  await page.goto("/order/123");
  await expect(page.getByText(/見つかりません|not found/i)).toBeVisible();
});
```

---

### パターン2: 500エラー

```typescript
test("サーバーエラー時の表示", async ({ page }) => {
  await page.route("**/api/orders", async (route) => {
    await route.fulfill({
      status: 500,
      body: JSON.stringify({ error: "Internal Server Error" }),
    });
  });

  await page.goto("/order");
  await expect(page.getByText(/エラーが発生しました/)).toBeVisible();
});
```

---

## ネットワーク遅延のシミュレーション

### タイムアウト処理のテスト

```typescript
test("API遅延時のローディング表示", async ({ page }) => {
  await page.route("**/api/orders", async (route) => {
    // 5秒遅延してからレスポンス
    await new Promise((resolve) => setTimeout(resolve, 5000));
    await route.fulfill({
      status: 200,
      body: JSON.stringify({ orders: [] }),
    });
  });

  await page.goto("/order");

  // ローディングスピナーが表示されることを確認
  await expect(page.locator('[role="progressbar"]')).toBeVisible();

  // 5秒後にデータが表示される
  await expect(page.getByText("注文一覧")).toBeVisible({ timeout: 10_000 });
});
```

---

## リクエストの検証

### パターン1: リクエストボディの確認

```typescript
test("送り状購入リクエストが正しい", async ({ page }) => {
  let capturedRequest: any = null;

  await page.route("**/api/purchase", async (route, request) => {
    // リクエストボディをキャプチャ
    capturedRequest = JSON.parse(request.postData() || "{}");

    await route.fulfill({
      status: 200,
      body: JSON.stringify({ success: true }),
    });
  });

  await page.goto("/shipping/1");
  await page.getByRole("button", { name: "購入" }).click();

  // リクエスト内容を検証
  expect(capturedRequest).toMatchObject({
    orderId: "1",
    carrier: "yamato",
  });
});
```

---

### パターン2: リクエストヘッダーの確認

```typescript
test("認証トークンが送信される", async ({ page }) => {
  let authHeader: string | null = null;

  await page.route("**/api/orders", async (route, request) => {
    authHeader = request.headers()["authorization"];
    await route.fulfill({
      status: 200,
      body: JSON.stringify({ orders: [] }),
    });
  });

  await page.goto("/order");

  expect(authHeader).toBe("Bearer test-token");
});
```

---

## 外部ファイルからモックデータを読み込む

### JSON ファイル読み込み

```typescript
// fixtures/mock-data.ts
import { readFileSync } from "fs";
import { resolve } from "path";

export function loadMockOrders() {
  const filePath = resolve(__dirname, "../mock-data/orders.json");
  return JSON.parse(readFileSync(filePath, "utf8"));
}
```

```typescript
// tests/order.spec.ts
import { loadMockOrders } from "../fixtures/mock-data";

test("モックデータで注文一覧を表示", async ({ page }) => {
  const mockOrders = loadMockOrders();

  await page.route("**/api/orders", async (route) => {
    await route.fulfill({
      status: 200,
      body: JSON.stringify(mockOrders),
    });
  });

  await page.goto("/order");
  await expect(page.getByText("#1001")).toBeVisible();
});
```

---

## オフラインモードのテスト

### ネットワーク切断のシミュレーション

```typescript
test("オフライン時のエラーメッセージ", async ({ page, context }) => {
  // ネットワークをオフラインに設定
  await context.setOffline(true);

  await page.goto("/order");

  // オフライン時のエラーメッセージを確認
  await expect(page.getByText(/ネットワークエラー|オフライン/i)).toBeVisible();
});
```

---

## 条件付きモック

### 特定の条件下でのみモック

```typescript
test("管理者ユーザーのみ表示される機能", async ({ page }) => {
  await page.route("**/api/user", async (route) => {
    await route.fulfill({
      status: 200,
      body: JSON.stringify({ role: "admin" }),
    });
  });

  await page.goto("/order");

  // 管理者専用ボタンが表示される
  await expect(page.getByRole("button", { name: "一括削除" })).toBeVisible();
});
```

---

## ベストプラクティス

### ✅ Good: モックスコープを限定

```typescript
// ✅ テストごとにモックを設定（影響範囲を限定）
test("テスト1", async ({ page }) => {
  await page.route("**/api/orders", async (route) => {
    await route.fulfill({ status: 200, body: "[]" });
  });
  await page.goto("/order");
});

test("テスト2", async ({ page }) => {
  // このテストではモックなし（実際のAPIを使用）
  await page.goto("/order");
});
```

---

### ❌ Bad: グローバルにモック設定

```typescript
// ❌ 全テストに影響（意図しない動作を引き起こす可能性）
test.beforeAll(async ({ context }) => {
  await context.route("**/api/orders", async (route) => {
    await route.fulfill({ status: 200, body: "[]" });
  });
});
```

---

### ✅ Good: モックデータを外部ファイル化

```typescript
// ✅ モックデータを外部ファイルで管理（再利用可能）
const mockOrders = loadMockOrders();

await page.route("**/api/orders", async (route) => {
  await route.fulfill({
    status: 200,
    body: JSON.stringify(mockOrders),
  });
});
```

---

### ❌ Bad: テスト内にハードコード

```typescript
// ❌ テスト内にモックデータをハードコード（保守性が低い）
await page.route("**/api/orders", async (route) => {
  await route.fulfill({
    status: 200,
    body: JSON.stringify({ orders: [{ id: "1", name: "#1001" }] }),
  });
});
```

---

## よくある罠

### 罠1: モックが適用されない

```typescript
// ❌ page.goto() の前にモック設定がない
await page.goto("/order");  // この時点でAPIリクエストが発生
await page.route("**/api/orders", async (route) => {
  await route.fulfill({ status: 200, body: "[]" });
});

// ✅ page.goto() の前にモック設定
await page.route("**/api/orders", async (route) => {
  await route.fulfill({ status: 200, body: "[]" });
});
await page.goto("/order");
```

---

### 罠2: ワイルドカードの誤用

```typescript
// ❌ 意図しないAPIまでモック
await page.route("**", async (route) => {
  await route.fulfill({ status: 200, body: "[]" });
});

// ✅ 明示的にエンドポイントを指定
await page.route("**/api/orders", async (route) => {
  await route.fulfill({ status: 200, body: "[]" });
});
```

---

### 罠3: JSONのシリアライズ忘れ

```typescript
// ❌ オブジェクトをそのまま渡すとエラー
await page.route("**/api/orders", async (route) => {
  await route.fulfill({
    status: 200,
    body: { orders: [] },  // ❌ オブジェクト
  });
});

// ✅ JSON.stringify() でシリアライズ
await page.route("**/api/orders", async (route) => {
  await route.fulfill({
    status: 200,
    body: JSON.stringify({ orders: [] }),
  });
});
```

---

## まとめ

- **`page.route()` でAPIモック**: 外部API依存を排除
- **エラーシナリオをテスト**: 404・500エラーの表示を検証
- **ネットワーク遅延をシミュレーション**: タイムアウト処理のテスト
- **リクエストを検証**: リクエストボディ・ヘッダーの確認
- **モックスコープを限定**: テストごとにモック設定
- **外部ファイルでモックデータ管理**: 再利用性を向上
