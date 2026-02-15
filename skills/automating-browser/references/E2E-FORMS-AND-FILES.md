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

**動的コンテンツの待機**: フォームは非同期でエラーメッセージを表示することが多い。`toBeVisible()` は自動的に要素が表示されるまで待機します。

**CSSクラスの検証**（バリデーション状態の確認）:

```typescript
const emailInput = page.locator('input#email');
await expect(emailInput).toHaveClass(/is-invalid/);
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

### マルチステップフォーム（ウィザード）のテスト

複数ページにわたるフォームでは、各ステップのバリデーションと進行を確認:

```typescript
test('マルチステップフォームの完了', async ({ page }) => {
  await page.goto('https://example.com/signup');

  // ステップ1: 個人情報
  await page.fill('#first-name', 'John');
  await page.fill('#last-name', 'Doe');
  await page.click('button[type="submit"]');

  // ステップ2: 住所
  await expect(page.locator('h2')).toContainText('Address Information');
  await page.fill('#street', '123 Main St');
  await page.fill('#city', 'New York');
  await page.click('button[type="submit"]');

  // ステップ3: 確認
  await expect(page.locator('h2')).toContainText('Confirmation');
  await expect(page.locator('.summary')).toContainText('John Doe');
  await expect(page.locator('.summary')).toContainText('123 Main St');
});
```

---

## ファイルアップロード

### setInputFiles() を使った基本アップロード

**重要**: OS-levelのファイルピッカーダイアログは表示されず、直接ファイルを設定できます。

```typescript
import path from 'node:path';

const fileInput = page.locator('input[type="file"]');

// 絶対パスの構築（OS間の互換性を確保）
const filePath = path.join(__dirname, 'document.pdf');
await fileInput.setInputFiles(filePath);

// 検証
await expect(page.locator('#file-name-display')).toContainText('document.pdf');
```

### 複数ファイルアップロード

**前提条件**: `<input type="file" multiple>` 属性が必要。

```typescript
await fileInput.setInputFiles([
  'tests/sample1.jpg',
  'tests/sample2.jpg',
  'tests/sample3.jpg'
]);

// UIでファイル名が表示されることを確認
await expect(page.getByRole('link', { name: 'sample1.jpg' })).toBeVisible();
await expect(page.getByRole('link', { name: 'sample2.jpg' })).toBeVisible();
```

### ファイル選択のクリア

エッジケース（必須ファイルが未選択の場合のエラー）をテスト:

```typescript
await fileInput.setInputFiles([]);  // 選択を解除

// バリデーションエラーを確認
await page.click('button[type="submit"]');
await expect(page.locator('.error-message')).toContainText('File is required');
```

### メモリ上のファイルオブジェクトを使用

ディスクにファイルを保存せずにテスト可能:

```typescript
await fileInput.setInputFiles([
  {
    name: 'file1.txt',
    mimeType: 'text/plain',
    buffer: Buffer.from('Hey, this is the first file content!')
  },
  {
    name: 'data.csv',
    mimeType: 'text/csv',
    buffer: Buffer.from('id,name,value\n1,test,123')
  }
]);
```

**用途**: 動的なテストデータ生成、異なるファイルサイズ/形式のテスト。

### ファイルタイプバリデーションのテスト

```typescript
test('不正なファイル形式を拒否', async ({ page }) => {
  await page.goto('https://example.com/upload');

  // PDFのみ許可されているが、DOCXをアップロード
  await page.locator('input[type="file"]').setInputFiles('invalid.docx');
  await page.click('button[type="submit"]');

  await expect(page.locator('.error-message')).toContainText(
    'Only PDF files are allowed'
  );
});
```

### ドラッグ&ドロップアップロード

ドロップゾーンが `<input type="file">` をラップしている場合:

```typescript
const dropZone = page.locator('.drop-zone');
await dropZone.setInputFiles('file.pdf');  // 内部的に同じメカニズム

// カスタムドロップゾーン（input要素なし）の場合はドラッグイベントを発火
await page.dispatchEvent('.custom-drop-zone', 'drop', {
  dataTransfer: {
    files: [{ name: 'file.pdf', type: 'application/pdf' }]
  }
});
```

---

## ファイルダウンロード

### download イベントを使った検証

**基本フロー**:
1. `download` イベントをリッスン
2. ダウンロードをトリガー
3. ファイル名・内容を検証

```typescript
import fs from 'node:fs/promises';

test('ファイルダウンロードを検証', async ({ page }) => {
  // ダウンロードイベントをリッスン（タイムアウト30秒）
  const downloadPromise = page.waitForEvent('download', { timeout: 30000 });

  // ダウンロードボタンをクリック
  await page.getByRole('link', { name: 'Download', exact: true }).click();

  // ダウンロード完了を待機
  const download = await downloadPromise;

  // ファイル名検証（正規表現も可）
  const fileName = download.suggestedFilename();
  expect(fileName).toMatch(/report-\d{4}-\d{2}-\d{2}\.pdf/);

  // ファイルを保存（ディレクトリは事前に存在する必要あり）
  await download.saveAs(`./downloads/${fileName}`);

  // ファイルパス取得
  const downloadPath = await download.path();
  expect(downloadPath).not.toBeNull();

  // ファイルサイズ検証
  const stats = await fs.stat(downloadPath);
  const fileSizeInMB = stats.size / (1024 * 1024);
  expect(fileSizeInMB).toBeGreaterThan(0.1);    // 100KB以上
  expect(fileSizeInMB).toBeLessThan(100);        // 100MB未満

  // テキストファイルの内容検証
  const content = await fs.readFile(downloadPath, 'utf-8');
  expect(content).toContain('Expected data');
});
```

### バイナリファイル（PDF/画像）の検証

```typescript
test('PDFダウンロードの検証', async ({ page }) => {
  const downloadPromise = page.waitForEvent('download');
  await page.click('a#download-pdf');
  const download = await downloadPromise;

  const downloadPath = await download.path();

  // ファイルサイズのみ検証（内容の詳細検証は pdf-parse 等のライブラリが必要）
  const stats = await fs.stat(downloadPath);
  expect(stats.size).toBeGreaterThan(1000); // 1KB以上のPDF
});
```

### ダウンロード失敗の処理

サーバーエラー（404/403等）の場合:

```typescript
test('ダウンロード失敗を検知', async ({ page }) => {
  const downloadPromise = page.waitForEvent('download');
  await page.click('a#broken-download-link');
  const download = await downloadPromise;

  // 失敗を検証
  const error = await download.failure();
  expect(error).toContain('404'); // エラーメッセージ確認
});
```

### 新規タブ/ウィンドウでのダウンロード

```typescript
test('新規タブでのダウンロード', async ({ page, context }) => {
  const [newPage] = await Promise.all([
    context.waitForEvent('page'),
    page.click('a[target="_blank"]')
  ]);

  const downloadPromise = newPage.waitForEvent('download');
  await newPage.click('button#download');
  const download = await downloadPromise;

  expect(download.suggestedFilename()).toBe('file.pdf');
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
    await page.evaluate(() => {
      sessionStorage.clear();
      localStorage.clear();
    });
  });

  test('test 1', async ({ page }) => { /* ... */ });
  test('test 2', async ({ page }) => { /* ... */ });
});
```

### ダウンロードファイルのクリーンアップ

**CI環境での注意**: ダウンロードディレクトリをクリーンアップしないとストレージを圧迫。

```typescript
import fs from 'node:fs/promises';
import path from 'node:path';

test.describe('ファイルダウンロードテスト', () => {
  const downloadDir = path.join(__dirname, 'downloads');

  test.beforeAll(async () => {
    // ダウンロードディレクトリを作成
    await fs.mkdir(downloadDir, { recursive: true });
  });

  test.afterEach(async () => {
    // テスト後にダウンロードファイルを削除
    const files = await fs.readdir(downloadDir);
    for (const file of files) {
      await fs.unlink(path.join(downloadDir, file));
    }
  });

  test.afterAll(async () => {
    // テストスイート終了後にディレクトリを削除
    await fs.rm(downloadDir, { recursive: true, force: true });
  });

  test('download test', async ({ page }) => {
    const downloadPromise = page.waitForEvent('download');
    await page.click('a#download-link');
    const download = await downloadPromise;
    await download.saveAs(path.join(downloadDir, download.suggestedFilename()));
  });
});
```

### アップロードテストファイルの準備とクリーンアップ

```typescript
test.describe('ファイルアップロードテスト', () => {
  const testFilePath = path.join(__dirname, 'temp-test-file.txt');

  test.beforeEach(async () => {
    // テストファイルを動的生成
    await fs.writeFile(testFilePath, 'Test file content', 'utf-8');
  });

  test.afterEach(async () => {
    // テストファイルを削除
    await fs.unlink(testFilePath).catch(() => {});
  });

  test('upload test', async ({ page }) => {
    await page.locator('input[type="file"]').setInputFiles(testFilePath);
    // ... アップロード検証
  });
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

### フォーム操作
- [ ] すべての入力タイプをカバー（text, email, password, date, select, checkbox, radio）
- [ ] バリデーションエラーメッセージを検証
- [ ] 成功時のリダイレクト/成功メッセージを確認
- [ ] マルチステップフォーム（ウィザード）の各ステップを検証
- [ ] カスタムウィジェット（日付ピッカー、ドロップダウン）の操作確認
- [ ] アクセシビリティ（ARIA、スクリーンリーダー対応）を考慮
- [ ] 動的フォーム要素の待機処理を実装

### ファイルアップロード
- [ ] 単一ファイルアップロードの成功ケース
- [ ] 複数ファイルアップロード（`multiple` 属性）
- [ ] ファイル選択のクリア（バリデーションエラー）
- [ ] ファイルタイプバリデーション（許可されていない形式の拒否）
- [ ] ファイルサイズ上限のテスト
- [ ] ドラッグ&ドロップアップロード
- [ ] アップロード後のUI反映確認

### ファイルダウンロード
- [ ] ダウンロードイベントの捕捉
- [ ] ファイル名の検証
- [ ] ファイルサイズの検証
- [ ] ファイル内容の検証（テキストファイル）
- [ ] ダウンロード失敗時のエラーハンドリング
- [ ] 新規タブ/ウィンドウでのダウンロード対応

### テスト環境
- [ ] テスト前のセットアップ（`beforeEach`）
- [ ] テスト後のクリーンアップ（`afterEach`）
- [ ] ダウンロードファイルの削除
- [ ] 一時ファイルの削除
