# アサーションと信頼性ガイド

Playwrightの**Web-First Assertions**を活用することで、フレークネス（不安定なテスト）を最小化し、信頼性の高いE2Eテストを実現します。

---

## Web-First Assertionsとは

**自動リトライ機能**を持つアサーションです。条件が満たされるまで一定時間待機し、タイムアウトしたら失敗します。

### 従来のアサーション（❌ 使用禁止）

```typescript
// ❌ 自動リトライなし（即座に評価されて失敗する可能性）
const text = await page.locator("h1").textContent();
expect(text).toBe("Welcome");
```

**問題点**:
- 要素がまだレンダリングされていない場合、即座に失敗
- 手動で `waitFor()` を追加する必要がある

---

### Web-First Assertions（✅ 推奨）

```typescript
// ✅ 自動リトライあり（要素が表示されるまで待機）
await expect(page.locator("h1")).toHaveText("Welcome");
```

**メリット**:
- 要素の出現を自動的に待機
- 明示的な `waitFor()` が不要
- フレークネスを大幅に削減

---

## 主要なWeb-First Assertions

### 1. `toBeVisible()` - 要素が表示されている

```typescript
await expect(page.getByText("送り状の情報")).toBeVisible();
await expect(page.locator('[role="dialog"]')).toBeVisible({ timeout: 10_000 });
```

---

### 2. `toHaveText()` - テキストが一致

```typescript
await expect(page.locator("h1")).toHaveText("注文一覧");
await expect(page.locator(".error")).toHaveText(/エラー|失敗/);  // 正規表現可
```

---

### 3. `toBeEnabled()` / `toBeDisabled()` - 有効/無効状態

```typescript
const loginButton = page.getByRole("button", { name: "ログイン" });
await expect(loginButton).toBeEnabled();

const submitButton = page.getByRole("button", { name: "送信" });
await expect(submitButton).toBeDisabled();
```

---

### 4. `toHaveValue()` - フォーム値の確認

```typescript
await expect(page.locator("#email")).toHaveValue("test@example.com");
await expect(page.getByLabel("メールアドレス")).toHaveValue(/.*@example\.com/);
```

---

### 5. `toHaveURL()` - URL確認

```typescript
await expect(page).toHaveURL(/\/order/);
await expect(page).toHaveURL("http://localhost:3000/order");
```

---

### 6. `toContainText()` - 部分一致

```typescript
await expect(page.locator(".message")).toContainText("成功");
```

---

### 7. `not.toBeVisible()` - 要素が非表示

```typescript
await expect(page.getByText("エラー")).not.toBeVisible();
await expect(page.locator('[role="progressbar"]')).not.toBeVisible();
```

---

## `expect.poll()` - 非同期関数のポーリング

**関数の戻り値**が条件を満たすまでリトライします。

### 使用場面

- Page Objectのメソッドが非同期の場合
- 複雑なロジックで計算された値をアサートする場合

---

### 例1: カウント取得のリトライ

```typescript
// ❌ 自動リトライなし（0で失敗する可能性）
const count = await orderPage.getOrderCountWithRetry();
expect(count).toBeGreaterThan(0);

// ✅ expect.poll() でラップ（自動リトライ）
await expect.poll(() => orderPage.getOrderCountWithRetry(), {
  timeout: 30_000,
}).toBeGreaterThan(0);
```

---

### 例2: 動的な値の確認

```typescript
await expect.poll(async () => {
  const rows = await orderPage.getOrderCount();
  return rows;
}, {
  message: "注文が1件以上表示されること",
  timeout: 30_000,
}).toBeGreaterThan(0);
```

---

## フレークネス対策

### 対策1: `waitForTimeout()` を使わない

```typescript
// ❌ 固定待機（環境依存でフレーク）
await page.waitForTimeout(3000);

// ✅ 条件ベース待機
await expect(page.getByText("送り状の情報")).toBeVisible();
```

---

### 対策2: `networkidle` は原則禁止

```typescript
// ❌ networkidle（外部リクエストの完了を待つが不安定）
await page.goto("/order", { waitUntil: "networkidle" });

// ✅ domcontentloaded + 対象要素の待機
await page.goto("/order", { waitUntil: "domcontentloaded" });
await expect(page.locator("table tbody tr").first()).toBeVisible();
```

**例外**: 外部SDK読み込みが必要なセットアップファイル（例: `auth.setup.ts` のCognito SDK）ではコメント付きで `networkidle` を許可。

---

### 対策3: `force: true` を使わない

```typescript
// ❌ force click（要素が無効でも強制クリック）
await page.getByRole("button", { name: "送信" }).click({ force: true });

// ✅ 有効になるまで待機
await expect(page.getByRole("button", { name: "送信" })).toBeEnabled();
await page.getByRole("button", { name: "送信" }).click();
```

---

### 対策4: エラーを握りつぶさない

```typescript
// ❌ エラー握りつぶし
const count = await page.locator("table tbody tr").count().catch(() => 0);

// ✅ タイムアウトを適切に設定
await page.locator("table tbody tr").first().waitFor({ state: "visible", timeout: 10_000 });
const count = await page.locator("table tbody tr").count();
```

---

## リトライ戦略

### パターン1: ページリロードのリトライ

データが表示されない場合、ページをリロードしてリトライします。

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

**使用例**:
```typescript
await expect.poll(() => orderPage.getOrderCountWithRetry(), {
  timeout: 30_000,
}).toBeGreaterThan(0);
```

---

### パターン2: クリック後の遷移リトライ

```typescript
async clickOrderByName(orderName: string): Promise<void> {
  const maxRetries = 2;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    const row = this.orderTable.locator("tbody tr").filter({ hasText: orderName });
    await row.first().waitFor({ state: "visible" });
    await row.locator("td").first().click();

    try {
      await this.page.waitForURL(/\/(shippings|print)\//, { timeout: 20_000 });
      return;  // 成功
    } catch {
      if (attempt < maxRetries) {
        await this.page.reload({ timeout: 15_000 });
        await this.page.waitForLoadState("domcontentloaded");
      } else {
        throw new Error(`注文 ${orderName} のクリック後に遷移失敗`);
      }
    }
  }
}
```

---

### パターン3: 404エラーのリトライ

```typescript
// 404ページを検出してリロード
for (let reload = 0; reload < 3; reload++) {
  const is404 = await this.page.getByText(/404|見つかりません/i)
    .first()
    .isVisible({ timeout: 3_000 })
    .catch(() => false);

  if (!is404) return;  // 正常ページ

  await this.page.reload({ timeout: 15_000 });
  await this.page.waitForLoadState("domcontentloaded");
}
```

---

## 並列実行時の注意点

### 問題: テストデータの競合

複数テストが同じデータを使用すると、並列実行時に競合します。

```typescript
// ❌ 全テストで同じ注文を使用（競合）
test("購入テスト1", async () => {
  await orderPage.clickOrderByName("#1001");
  await shippingPage.purchase();
});

test("購入テスト2", async () => {
  await orderPage.clickOrderByName("#1001");  // 競合！
  await shippingPage.purchase();
});
```

---

### 解決策: テストデータの分離

各テストに専用のデータを割り当てます。

```typescript
// ✅ 各テストが専用データを使用
test("購入テスト1", async () => {
  await orderPage.clickOrderByName("#1001");
  await shippingPage.purchase();
});

test("購入テスト2", async () => {
  await orderPage.clickOrderByName("#1002");  // 別のデータ
  await shippingPage.purchase();
});
```

---

## よくある罠

### 罠1: `hasOrder()` の結果を直接アサート

```typescript
// ❌ 同期assert（自動リトライなし）
const hasOrder = await orderPage.hasOrder("#1001");
expect(hasOrder).toBe(true);

// ✅ ロケーターを直接アサート
await expect(
  page.locator("table tbody tr").filter({ hasText: "#1001" })
).toBeVisible();
```

---

### 罠2: `getOrderCount()` を直接アサート

```typescript
// ❌ 同期assert（自動リトライなし）
const count = await orderPage.getOrderCount();
expect(count).toBeGreaterThan(0);

// ✅ expect.poll() でラップ
await expect.poll(() => orderPage.getOrderCountWithRetry()).toBeGreaterThan(0);
```

---

### 罠3: `domcontentloaded` だけで操作開始

```typescript
// ❌ データ行が表示される前に操作
await page.waitForLoadState("domcontentloaded");
await page.locator("table tbody tr").first().click();  // 失敗する可能性

// ✅ 対象要素の表示を待機
await page.waitForLoadState("domcontentloaded");
await page.locator("table tbody tr").first().waitFor({ state: "visible" });
await page.locator("table tbody tr").first().click();
```

---

## まとめ

- **Web-First Assertions必須**: `await expect(locator).toBeVisible()` 等を使用
- **`expect.poll()` でラップ**: 非同期関数の戻り値をアサートする場合
- **`waitForTimeout()` 禁止**: 条件ベース待機に置き換え
- **`networkidle` 原則禁止**: `domcontentloaded` + 対象要素の待機
- **`force: true` 禁止**: 有効になるまで待機
- **テストデータ分離**: 並列実行時の競合を防ぐ
