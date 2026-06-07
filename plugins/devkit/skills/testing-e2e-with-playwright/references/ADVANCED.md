# 高度なテスト手法ガイド

ビジュアルリグレッション・アクセシビリティ・APIテストなど、Playwrightの高度な機能を解説します。

---

## ビジュアルリグレッションテスト

### 基本的なスクリーンショット比較

```typescript
test("ログイン画面の見た目が変わっていない", async ({ page }) => {
  await page.goto("/login");

  // スクリーンショットを撮影して比較
  await expect(page).toHaveScreenshot("login-page.png");
});
```

**動作**:
- 初回実行時: スクリーンショットを `login-page.png` として保存
- 2回目以降: 現在の画面と保存されたスクリーンショットを比較
- 差分があれば失敗

---

### 要素単位のスクリーンショット比較

```typescript
test("注文テーブルの見た目が変わっていない", async ({ page }) => {
  await page.goto("/order");

  // 特定の要素のみスクリーンショット比較
  await expect(page.locator("table")).toHaveScreenshot("order-table.png");
});
```

---

### ピクセル差分の許容

```typescript
test("わずかなピクセル差分を許容", async ({ page }) => {
  await page.goto("/order");

  await expect(page).toHaveScreenshot("order-page.png", {
    maxDiffPixels: 100,  // 100ピクセルまでの差分を許容
  });
});
```

---

### マスキング（動的要素の除外）

```typescript
test("タイムスタンプを除外して比較", async ({ page }) => {
  await page.goto("/order");

  await expect(page).toHaveScreenshot("order-page.png", {
    mask: [
      page.locator(".timestamp"),  // タイムスタンプを隠す
      page.locator(".user-avatar"),  // ユーザーアバターを隠す
    ],
  });
});
```

---

## アクセシビリティテスト

### axe-core統合

```bash
npm install --save-dev @axe-core/playwright
```

```typescript
import { test, expect } from "@playwright/test";
import { injectAxe, checkA11y } from "axe-playwright";

test("ログイン画面のアクセシビリティ", async ({ page }) => {
  await page.goto("/login");

  // axe-coreを注入
  await injectAxe(page);

  // アクセシビリティチェック実行
  await checkA11y(page);
});
```

**検出される問題**:
- `<img>` タグに `alt` 属性がない
- フォーム要素に `label` が関連付けられていない
- コントラスト比が不足している

---

### 特定要素のアクセシビリティチェック

```typescript
test("注文テーブルのアクセシビリティ", async ({ page }) => {
  await page.goto("/order");
  await injectAxe(page);

  // 特定要素のみチェック
  await checkA11y(page, "table");
});
```

---

### 重大度フィルタ

```typescript
test("重大なアクセシビリティ問題のみ検出", async ({ page }) => {
  await page.goto("/order");
  await injectAxe(page);

  await checkA11y(page, undefined, {
    includedImpacts: ["critical", "serious"],  // 重大度フィルタ
  });
});
```

---

## APIテスト（Playwright APIクライアント）

### 基本的なAPIテスト

```typescript
import { test, expect } from "@playwright/test";

test("注文一覧APIが正常に動作する", async ({ request }) => {
  const response = await request.get("http://localhost:8080/api/orders");

  expect(response.status()).toBe(200);
  const data = await response.json();
  expect(data.orders).toBeInstanceOf(Array);
});
```

---

### 認証付きAPIテスト

```typescript
test("認証付きで注文を作成", async ({ request }) => {
  const response = await request.post("http://localhost:8080/api/orders", {
    headers: {
      Authorization: "Bearer test-token",
    },
    data: {
      orderId: "1001",
      carrier: "yamato",
    },
  });

  expect(response.status()).toBe(201);
  const data = await response.json();
  expect(data.success).toBe(true);
});
```

---

### UI + APIの統合テスト

```typescript
test("UIで注文を作成してAPIで確認", async ({ page, request }) => {
  // UI操作
  await page.goto("/order/new");
  await page.getByLabel("注文番号").fill("1001");
  await page.getByRole("button", { name: "作成" }).click();

  // APIで確認
  const response = await request.get("http://localhost:8080/api/orders/1001");
  expect(response.status()).toBe(200);
  const data = await response.json();
  expect(data.orderId).toBe("1001");
});
```

---

## ブラウザコンテキストの分離

### 複数ユーザーのテスト

```typescript
test("複数ユーザーの同時操作", async ({ browser }) => {
  // ユーザー1のコンテキスト
  const context1 = await browser.newContext({
    storageState: ".auth/user1.json",
  });
  const page1 = await context1.newPage();

  // ユーザー2のコンテキスト
  const context2 = await browser.newContext({
    storageState: ".auth/user2.json",
  });
  const page2 = await context2.newPage();

  // 両方のユーザーが同時に操作
  await Promise.all([
    page1.goto("/order"),
    page2.goto("/order"),
  ]);

  // クリーンアップ
  await context1.close();
  await context2.close();
});
```

---

## パフォーマンステスト

### ページロード時間の計測

```typescript
test("ページロード時間が3秒以内", async ({ page }) => {
  const startTime = Date.now();
  await page.goto("/order");
  await page.waitForLoadState("networkidle");
  const loadTime = Date.now() - startTime;

  expect(loadTime).toBeLessThan(3000);  // 3秒以内
});
```

---

### Performance API

```typescript
test("ナビゲーションタイミングを計測", async ({ page }) => {
  await page.goto("/order");

  const timing = await page.evaluate(() => {
    const perf = performance.getEntriesByType("navigation")[0] as PerformanceNavigationTiming;
    return {
      dns: perf.domainLookupEnd - perf.domainLookupStart,
      tcp: perf.connectEnd - perf.connectStart,
      ttfb: perf.responseStart - perf.requestStart,
      load: perf.loadEventEnd - perf.loadEventStart,
    };
  });

  console.log("DNS:", timing.dns, "ms");
  console.log("TCP:", timing.tcp, "ms");
  console.log("TTFB:", timing.ttfb, "ms");
  console.log("Load:", timing.load, "ms");

  expect(timing.ttfb).toBeLessThan(500);  // TTFB < 500ms
});
```

---

## モバイルエミュレーション

### デバイスエミュレーション

```typescript
import { devices } from "@playwright/test";

test("iPhone 13でテスト", async ({ browser }) => {
  const context = await browser.newContext({
    ...devices["iPhone 13"],
  });
  const page = await context.newPage();

  await page.goto("/order");
  await expect(page.getByText("注文一覧")).toBeVisible();

  await context.close();
});
```

---

### カスタムビューポート

```typescript
test("タブレットサイズでテスト", async ({ page }) => {
  await page.setViewportSize({ width: 768, height: 1024 });
  await page.goto("/order");
  await expect(page.getByText("注文一覧")).toBeVisible();
});
```

---

## Geolocation（位置情報）のテスト

```typescript
test("位置情報を東京に設定", async ({ browser }) => {
  const context = await browser.newContext({
    geolocation: { latitude: 35.6762, longitude: 139.6503 },  // 東京
    permissions: ["geolocation"],
  });
  const page = await context.newPage();

  await page.goto("/map");

  // 位置情報が東京になっていることを確認
  const location = await page.evaluate(() => {
    return new Promise((resolve) => {
      navigator.geolocation.getCurrentPosition((pos) => {
        resolve({
          lat: pos.coords.latitude,
          lon: pos.coords.longitude,
        });
      });
    });
  });

  expect(location).toMatchObject({
    lat: 35.6762,
    lon: 139.6503,
  });

  await context.close();
});
```

---

## WebSocket通信のテスト

```typescript
test("WebSocketでリアルタイム通知を受信", async ({ page }) => {
  let wsMessage: string | null = null;

  // WebSocketメッセージをキャプチャ
  page.on("websocket", (ws) => {
    ws.on("framereceived", (event) => {
      wsMessage = event.payload;
    });
  });

  await page.goto("/order");

  // サーバーからWebSocketメッセージを受信するまで待機
  await page.waitForTimeout(3000);

  expect(wsMessage).toContain("new_order");
});
```

---

## カスタムレポーター

### シンプルなカスタムレポーター

```typescript
// my-reporter.ts
import { Reporter } from "@playwright/test/reporter";

class MyReporter implements Reporter {
  onTestEnd(test, result) {
    console.log(`✅ ${test.title}: ${result.status}`);
  }

  onEnd(result) {
    console.log(`Total tests: ${result.suites.length}`);
  }
}

export default MyReporter;
```

```typescript
// playwright.config.ts
export default defineConfig({
  reporter: [["./my-reporter.ts"]],
});
```

---

## まとめ

- **ビジュアルリグレッション**: `toHaveScreenshot()` でUI変更を検出
- **アクセシビリティ**: `axe-core` でWCAG準拠を検証
- **APIテスト**: `request` フィクスチャでUI + APIを統合テスト
- **パフォーマンス**: ページロード時間・Navigation Timingを計測
- **モバイルエミュレーション**: デバイスプリセットで複数画面サイズをテスト
- **Geolocation**: 位置情報ベースの機能をテスト
- **WebSocket**: リアルタイム通信をテスト
