# デバッグとトラブルシューティングガイド

Playwright E2Eテストのデバッグ手法・失敗原因の特定・トラブルシューティング手順を解説します。

---

## デバッグ優先順位

テスト失敗時は以下の順序で調査します:

1. **動画確認**: `test-results/*/video.webm` で実際の動作を確認
2. **スクリーンショット**: `test-results/*/test-failed-*.png` で失敗時の状態を確認
3. **トレース**: `npx playwright show-trace trace.zip` で詳細なタイムラインを確認
4. **バックエンドログ**: `docker logs <container>` でAPIエラーを確認
5. **ブラウザコンソール**: ページ上のJavaScriptエラーを確認

---

## 動画確認

### 設定

```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    video: { mode: "on" },  // 常に動画記録
  },
});
```

### 確認方法

```bash
# 動画ファイルの場所
test-results/<test-name>/video.webm

# ブラウザで再生
open test-results/<test-name>/video.webm
```

**確認ポイント**:
- ボタンがクリックされているか
- ページ遷移が発生しているか
- ローディングスピナーが表示されているか
- エラーメッセージが表示されているか

---

## スクリーンショット

### 自動スクリーンショット

```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    screenshot: "only-on-failure",  // 失敗時のみ
  },
});
```

### 手動スクリーンショット

```typescript
test("デバッグ用スクリーンショット", async ({ page }) => {
  await page.goto("/order");
  await page.screenshot({ path: "debug-screenshot.png", fullPage: true });
});
```

---

## トレース（詳細なタイムライン）

### 設定

```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    trace: "on-first-retry",  // リトライ時にトレース記録
  },
});
```

### 表示

```bash
# トレースファイルを表示
npx playwright show-trace test-results/<test-name>/trace.zip
```

**トレースで確認できる情報**:
- ネットワークリクエスト・レスポンス
- DOM操作のタイムライン
- コンソールログ
- スクリーンショット（各ステップ）

---

## デバッグモード

### UI Mode（推奨）

```bash
# UI Modeで対話的にデバッグ
npx playwright test --ui
```

**機能**:
- ステップ実行
- 要素のインスペクト
- タイムトラベル（各ステップの状態を確認）

---

### デバッグモード（ブレークポイント）

```typescript
test("デバッグモード", async ({ page }) => {
  await page.goto("/order");

  // ここでブレークポイント（デバッガが起動）
  await page.pause();

  await page.getByRole("button", { name: "送信" }).click();
});
```

```bash
# デバッグモードで実行
npx playwright test --debug
```

---

## ログ出力

### コンソールログのキャプチャ

```typescript
test("コンソールログを確認", async ({ page }) => {
  page.on("console", (msg) => {
    console.log(`[Browser Console] ${msg.type()}: ${msg.text()}`);
  });

  await page.goto("/order");
});
```

---

### Playwright Inspector

```bash
# Inspectorを起動
PWDEBUG=1 npx playwright test
```

**機能**:
- ステップ実行
- ロケーターのテスト
- セレクタの検証

---

## バックエンドログの確認

### Dockerコンテナのログ

```bash
# コンテナログ確認
docker logs <container-name>

# リアルタイムでログ表示
docker logs -f <container-name>

# 最新100行のみ表示
docker logs --tail 100 <container-name>
```

**確認ポイント**:
- APIエラー（404、500等）
- データベースエラー
- 認証エラー

---

### 例: エラーメッセージの検索

```bash
# エラーログを検索
docker logs e2e-backend 2>&1 | grep -i "error"

# 特定のエンドポイントのログを検索
docker logs e2e-backend 2>&1 | grep "/api/purchase"
```

---

## よくあるエラーと対処法

### エラー1: `TimeoutError: Timeout 30000ms exceeded`

**原因**: 要素が表示されない

**対処**:
1. **動画確認**: 要素が本当に表示されていないか確認
2. **待機条件の見直し**: `waitForLoadState("domcontentloaded")` の後に対象要素の `toBeVisible()` を追加
3. **タイムアウト延長**: `{ timeout: 60_000 }` で時間を延長

```typescript
// ❌ 不十分
await page.waitForLoadState("domcontentloaded");
await page.getByRole("button", { name: "送信" }).click();  // タイムアウト

// ✅ 対象要素の出現を待機
await page.waitForLoadState("domcontentloaded");
await expect(page.getByRole("button", { name: "送信" })).toBeVisible();
await page.getByRole("button", { name: "送信" }).click();
```

---

### エラー2: `Error: locator.click: Element is not visible`

**原因**: 要素が非表示または他の要素に隠れている

**対処**:
1. **スクリーンショット確認**: 要素の状態を確認
2. **スクロール**: `scrollIntoViewIfNeeded()` で要素を表示領域に移動
3. **待機条件追加**: `toBeVisible()` で表示を待機

```typescript
// ✅ スクロールしてからクリック
const button = page.getByRole("button", { name: "送信" });
await button.scrollIntoViewIfNeeded();
await button.click();
```

---

### エラー3: `Error: locator.click: Element is outside of the viewport`

**原因**: 要素がビューポート外にある

**対処**:
```typescript
// ✅ スクロールしてからクリック
await page.getByRole("button", { name: "送信" }).scrollIntoViewIfNeeded();
await page.getByRole("button", { name: "送信" }).click();
```

---

### エラー4: `Error: page.waitForURL: Timeout 30000ms exceeded`

**原因**: ページ遷移が発生しない

**対処**:
1. **動画確認**: クリックが実行されているか確認
2. **hydration待機**: クリックハンドラが有効になるまで待機
3. **バックエンドログ確認**: APIエラーでリダイレクトが失敗していないか確認

```typescript
// ✅ 要素がenabledになってからクリック
await expect(page.getByRole("button", { name: "購入" })).toBeEnabled();
await page.getByRole("button", { name: "購入" }).click();
await page.waitForURL(/\/print\//);
```

---

### エラー5: `TypeError: Cannot read property 'XXX' of null`

**原因**: Page Objectのメソッドで要素が取得できない

**対処**:
```typescript
// ❌ 要素が存在しない可能性
const text = await page.locator("h1").textContent();
console.log(text.toUpperCase());  // null.toUpperCase() でエラー

// ✅ null チェック
const text = await page.locator("h1").textContent();
if (text) {
  console.log(text.toUpperCase());
}
```

---

## テストが「パス」しても動画がおかしい場合

**原因**: テストコードが正しい状態を検証していない（「嘘のグリーン」）

**対処**:
1. **動画確認**: 実際の動作を確認
2. **アサーション追加**: 重要な状態を明示的に検証

```typescript
// ❌ 購入ボタンをクリックしただけ（購入が成功したか検証していない）
await page.getByRole("button", { name: "購入" }).click();

// ✅ 購入成功を検証
await page.getByRole("button", { name: "購入" }).click();
await expect(page).toHaveURL(/\/print\//);  // リダイレクトを確認
await expect(page.getByText("送り状の情報")).toBeVisible();  // 成功画面を確認
```

---

## デバッグ用ヘルパー

### ページの状態をファイルに保存

```typescript
test("デバッグ用: ページ状態を保存", async ({ page }) => {
  await page.goto("/order");

  // HTML全体を保存
  const html = await page.content();
  await require("fs").promises.writeFile("debug-page.html", html);

  // ページ情報を保存
  const debugInfo = {
    url: page.url(),
    title: await page.title(),
    cookies: await page.context().cookies(),
  };
  await require("fs").promises.writeFile(
    "debug-info.json",
    JSON.stringify(debugInfo, null, 2)
  );
});
```

---

### ロケーターのデバッグ

```typescript
// ロケーターの存在確認
const locator = page.getByRole("button", { name: "送信" });
console.log("Count:", await locator.count());  // 存在する要素数
console.log("Visible:", await locator.isVisible());  // 表示状態
console.log("Enabled:", await locator.isEnabled());  // 有効状態
```

---

## トラブルシューティング手順

### Step 1: 動画確認

```bash
open test-results/<test-name>/video.webm
```

**確認事項**:
- クリックは実行されたか
- ページ遷移は発生したか
- エラーメッセージは表示されたか

---

### Step 2: バックエンドログ確認

```bash
docker logs e2e-backend 2>&1 | grep -i "error"
```

**確認事項**:
- APIエラー（404、500）
- データベースエラー
- 認証エラー

---

### Step 3: ブラウザコンソール確認

```typescript
page.on("console", (msg) => console.log(msg.text()));
page.on("pageerror", (err) => console.error(err.message));
```

**確認事項**:
- JavaScriptエラー
- 未定義のオブジェクト参照

---

### Step 4: トレース確認

```bash
npx playwright show-trace test-results/<test-name>/trace.zip
```

**確認事項**:
- ネットワークリクエスト・レスポンス
- DOM操作のタイムライン

---

## まとめ

- **デバッグ優先順位**: 動画 → スクリーンショット → トレース → バックエンドログ
- **UI Mode**: 対話的なデバッグに最適
- **トレース**: ネットワーク・DOM操作の詳細確認
- **バックエンドログ**: APIエラーの特定
- **動画確認**: テストが「パス」しても動作を確認
