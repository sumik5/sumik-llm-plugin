# E2Eテスト: フォーム操作とファイル処理

## 概要

フォーム操作とファイルアップロード/ダウンロードは、Webアプリケーションで最も重要なE2Eテスト対象の一つです。ユーザー入力の検証、ファイル処理の信頼性、バリデーションロジックの正確性を保証する必要があります。

---

## フォーム要素の操作パターン

### テキスト入力

**fill() - 高速一括入力**

```typescript
await page.getByLabel('Username').fill('my_user');
await page.getByPlaceholder('Enter password').fill('S3cr3tP@ssw0rd!');
```

- 既存の値を自動クリア
- input/change イベントを発火
- 最速の入力方法

**pressSequentially() - キーストローク再現**

```typescript
const searchBox = page.getByRole('searchbox');
await searchBox.clear();
await searchBox.pressSequentially('Playwright testing');
await searchBox.press('Enter');
```

- 1文字ずつキーイベントを発火
- オートコンプリート、リアルタイムバリデーションのテストに必須
- keydown/keypress/keyup イベントをすべてトリガー

**press() - 特殊キー操作**

```typescript
await page.press('input[name="search"]', 'Enter');
await page.press('textarea', 'Control+A');  // 全選択
await page.press('input', 'Tab');  // フォーカス移動
```

---

### ドロップダウン (<select>)

**標準セレクトの操作**

```typescript
const countryDropdown = page.getByLabel('Country');

// 値で選択（推奨: 最も安定）
await countryDropdown.selectOption('DE');

// ラベルで選択（ユーザー視点）
await countryDropdown.selectOption({ label: 'United Kingdom' });

// インデックスで選択（順序依存・非推奨）
await countryDropdown.selectOption({ index: 2 });
```

**マルチセレクト**

```typescript
const toppingsDropdown = page.getByLabel('Toppings');
await toppingsDropdown.selectOption([
  'pepperoni',
  'mushrooms',
  'onions'
]);
```

---

### カスタムドロップダウン (非<select>)

多くの現代的UIライブラリ（Material UI、Ant Design等）は `<div>` ベースのカスタムドロップダウンを使用します。

```typescript
const stateDropdown = page.locator('#state');
await stateDropdown.click();  // ドロップダウンを開く

const stateOption = page.getByText('Haryana');
await expect(stateOption).toBeVisible();
await stateOption.click();
```

**注意事項:**
- アニメーション待機が必要な場合あり
- `await page.toBeVisible()` で要素が表示されるまで待機
- 動的ロードの場合は `page.waitForResponse()` を併用

---

## チェックボックスとラジオボタン

### チェックボックス操作

```typescript
// チェック（冪等）
await page.getByLabel("I agree to the terms").check();

// チェック解除
await page.uncheck('#accept-terms');

// 状態検証
await expect(page.locator('#accept-terms')).toBeChecked();
await expect(page.locator('#accept-terms')).not.toBeChecked();
```

### ラジオボタン操作

```typescript
// ラジオボタンの選択（グループ内で排他的）
await page.check('input[value="red"]');

// 検証パターン
const maleRadio = page.locator('#gender-radio-1');
const femaleRadio = page.locator('#gender-radio-2');

await maleRadio.check({ force: true });
await expect(maleRadio).toBeChecked();
await expect(femaleRadio).not.toBeChecked();
```

**重要:** `{ force: true }` の使用は慎重に
- 通常の actionability チェックをバイパス
- UI問題（要素が隠れている等）を見逃すリスク
- 本当に必要な場合のみ使用

---

## 日付ピッカーとカスタムフィールド

### 標準HTML日付入力

```typescript
await page.fill('input[type="date"]', '2025-08-08');
```

### カスタムカレンダーウィジェット

```typescript
const datePickerInput = page.locator('#date-picker-input');
const calendar = page.locator('.calendar');

await datePickerInput.click();
await calendar.waitFor({ state: 'visible' });

await page.locator('.year-dropdown').selectOption('2025');
await page.locator('.month-selector[data-month="August"]').click();
await page.locator('.day-selector[data-day="8"]').click();
```

**ベストプラクティス:**
- ARIA属性（`aria-label`, `data-date`）を使用した安定したセレクタ
- `waitFor({ state: 'visible' })` でアニメーション完了を待機

### JavaScript経由の直接値設定

React等の複雑なフレームワークでは、UI操作より直接設定が確実な場合があります。

```typescript
await page.evaluate((date) => {
  const input = document.querySelector('#date-picker-input');
  input.value = date;

  // イベント発火（必須）
  input.dispatchEvent(new Event('input', { bubbles: true }));
  input.dispatchEvent(new Event('change', { bubbles: true }));
}, '2025-08-08');

// 値が設定されたことを検証
await expect(page.locator('#date-picker-input')).toHaveValue('2025-08-08');
```

**注意:**
- バリデーションがバイパスされる可能性
- 実際のユーザー操作と異なる
- テスト後に動作を検証

---

## フォームバリデーションのテスト

### 失敗ケースのテスト

```typescript
test('不正なログイン情報でエラーメッセージを表示', async ({ page }) => {
  await page.goto('https://www.saucedemo.com/');

  await page.getByPlaceholder('Username').fill('invalid_user');
  await page.getByPlaceholder('Password').fill('wrong_password');
  await page.getByRole('button', { name: 'Login' }).click();

  const errorContainer = page.locator('[data-test="error"]');
  await expect(errorContainer).toBeVisible();
  await expect(errorContainer).toContainText(
    'Username and password do not match'
  );
});
```

### 成功ケースのテスト

```typescript
test('有効なフォーム送信でリダイレクト', async ({ page }) => {
  await page.goto('https://www.saucedemo.com/');

  await page.getByPlaceholder('Username').fill('standard_user');
  await page.getByPlaceholder('Password').fill('secret_sauce');
  await page.getByRole('button', { name: 'Login' }).click();

  await expect(page).toHaveURL('https://www.saucedemo.com/inventory.html');
});
```

---

## ファイルアップロード

### setInputFiles() を使った基本アップロード

```typescript
const fileInput = page.locator('input[type="file"]');
await fileInput.setInputFiles('path/to/file.pdf');
```

### 複数ファイルアップロード

```typescript
await fileInput.setInputFiles([
  'document1.pdf',
  'document2.pdf',
  'document3.pdf'
]);
```

### ファイル選択のクリア

```typescript
await fileInput.setInputFiles([]);  // 選択を解除
```

### メモリ上のファイルオブジェクトを使用

```typescript
await fileInput.setInputFiles({
  name: 'test.txt',
  mimeType: 'text/plain',
  buffer: Buffer.from('file content here')
});
```

### ドラッグ&ドロップアップロード

```typescript
const dropZone = page.locator('.drop-zone');
await dropZone.setInputFiles('file.pdf');  // 内部的に同じメカニズム
```

---

## ファイルダウンロード

### download イベントを使った検証

```typescript
test('ファイルダウンロードを検証', async ({ page }) => {
  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Download Report' }).click();

  const download = await downloadPromise;

  // ファイル名検証
  expect(download.suggestedFilename()).toBe('report.pdf');

  // ファイルを保存
  await download.saveAs('downloads/report.pdf');

  // ファイル内容検証
  const path = await download.path();
  const content = fs.readFileSync(path, 'utf-8');
  expect(content).toContain('Expected data');
});
```

---

## テスト環境のクリーンアップ

### beforeEach/afterEach フック

```typescript
test.describe('フォームテストスイート', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('https://example.com/form');
  });

  test.afterEach(async ({ page }) => {
    // テスト間のデータ分離
    await page.evaluate(() => sessionStorage.clear());
  });

  test('test 1', async ({ page }) => { /* ... */ });
  test('test 2', async ({ page }) => { /* ... */ });
});
```

---

## メソッド比較表

| メソッド | 用途 | フィールドクリア | イベント発火 | 速度 |
|---------|------|----------------|-------------|------|
| `fill()` | 値の即座設定 | ✅ | input/change | 最速 |
| `pressSequentially()` | リアルタイプ再現 | ❌ | keydown/keypress/keyup/input | 遅い |
| `press()` | 特殊キー操作 | ❌ | keydown/keyup のみ | 即座 |

---

## チェックリスト: フォームとファイル処理テスト

- [ ] すべての入力タイプをカバー（text, email, password, date, select, checkbox, radio）
- [ ] バリデーションエラーメッセージを検証
- [ ] 成功時のリダイレクト/成功メッセージを確認
- [ ] ファイルアップロードの上限サイズをテスト
- [ ] 不正なファイル形式の拒否を確認
- [ ] ダウンロードファイルの内容検証
- [ ] アクセシビリティ（ARIA、スクリーンリーダー対応）を考慮
- [ ] 動的フォーム要素の待機処理を実装
