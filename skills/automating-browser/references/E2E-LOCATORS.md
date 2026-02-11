# Playwright Test ロケーター戦略

このドキュメントでは、Playwright Test における**ロケーター（要素の特定方法）**のベストプラクティスを解説します。適切なロケーター戦略は、テストの**信頼性**と**メンテナンス性**を大きく向上させます。

---

## 📑 目次

1. [ロケーター Tier List（最重要）](#ロケーター-tier-list最重要)
2. [getByRole マスタリー](#getbyrole-マスタリー)
3. [高度なパターン](#高度なパターン)
4. [セマンティック HTML = テスタブルなアプリ](#セマンティック-html--テスタブルなアプリ)
5. [Do's & Don'ts](#dos--donts)

---

## ロケーター Tier List（最重要）

以下の優先順位に従ってロケーターを選択してください：

| Tier | ロケーター | 用途 | 例 |
|------|-----------|------|-----|
| **🔴 常に使う** | `getByRole()` | インタラクティブ要素（ボタン、リンク、入力等） | `getByRole('button', { name: 'Submit' })` |
| **🔴 常に使う** | `getByLabel()` | フォーム入力（label 要素と関連付け） | `getByLabel('Email')` |
| **🟢 良い** | `getByPlaceholder()` | ラベルがない場合の入力欄 | `getByPlaceholder('name@example.com')` |
| **🟢 良い** | `getByTestId()` | セマンティック代替手段がない場合 | `getByTestId('user-card')` |
| **🟡 控えめに** | `getByText()` | テキスト検索（変更されやすい） | `getByText('Login')` |
| **🟡 控えめに** | `getByAltText()` | 画像のみ | `getByAltText('logo')` |
| **🔴 避ける** | CSS ユーティリティ | リファクタリングで壊れる | ❌ `.flex.bg-blue-500` |
| **🔴 避ける** | XPath | 複雑、Shadow DOM 不可 | ❌ `//div[@id="x"]` |

---

## getByRole マスタリー

`getByRole()` は**最も推奨されるロケーター**です。アクセシビリティを保証しながら、堅牢なテストを記述できます。

### 暗黙的ロール

HTML 要素は暗黙的に ARIA ロールを持ちます：

| HTML 要素 | 暗黙的ロール | 例 |
|-----------|-------------|-----|
| `<button>` | `'button'` | `getByRole('button', { name: 'Submit' })` |
| `<a href="...">` | `'link'` | `getByRole('link', { name: 'Home' })` |
| `<input type="text">` | `'textbox'` | `getByRole('textbox', { name: 'Email' })` |
| `<input type="checkbox">` | `'checkbox'` | `getByRole('checkbox', { name: 'Remember me' })` |
| `<input type="radio">` | `'radio'` | `getByRole('radio', { name: 'Male' })` |
| `<h1>` ~ `<h6>` | `'heading'` | `getByRole('heading', { name: 'Welcome', level: 1 })` |
| `<img>` | `'img'` | `getByRole('img', { name: 'Logo' })` |
| `<nav>` | `'navigation'` | `getByRole('navigation')` |
| `<ul>` / `<ol>` | `'list'` | `getByRole('list')` |
| `<li>` | `'listitem'` | `getByRole('listitem')` |
| `<table>` | `'table'` | `getByRole('table')` |
| `<form>` | `'form'` | `getByRole('form')` |

### オプション

`getByRole()` は強力なフィルタリングオプションを提供します：

```typescript
// name: アクセシブル名（テキスト、aria-label、alt 等）
await page.getByRole('button', { name: 'Submit' }).click()

// level: 見出しのレベル（1〜6）
await page.getByRole('heading', { name: 'Welcome', level: 1 })

// checked: チェックボックス・ラジオボタンの状態
await page.getByRole('checkbox', { name: 'Remember me', checked: true })

// pressed: トグルボタンの状態
await page.getByRole('button', { name: 'Bold', pressed: true })

// expanded: アコーディオン等の展開状態
await page.getByRole('button', { name: 'Menu', expanded: true })

// selected: 選択状態（タブ等）
await page.getByRole('tab', { name: 'Profile', selected: true })

// disabled: 無効状態
await page.getByRole('button', { name: 'Submit', disabled: false })
```

### 正規表現による柔軟なマッチング

```typescript
// "Sign in" / "Sign In" / "signin" 等に対応
await page.getByRole('button', { name: /sign.{0,5}in/i }).click()

// "Log out" / "Logout" / "Sign out" 等に対応
await page.getByRole('button', { name: /log|sign.{0,5}out/i }).click()

// 数値を含むテキスト（例: "Item 1", "Item 2"）
await page.getByRole('listitem', { name: /Item \d+/ })
```

### アクセシブル名の優先順位

`getByRole()` の `name` オプションは、以下の優先順位でアクセシブル名を解決します：

1. **aria-labelledby** / **aria-label**
2. **テキスト内容**（ボタン、リンク等）
3. **alt 属性**（画像）
4. **title 属性**
5. **placeholder 属性**（入力欄）

```html
<!-- 例 1: テキスト内容 -->
<button>Submit</button>
<!-- getByRole('button', { name: 'Submit' }) -->

<!-- 例 2: aria-label -->
<button aria-label="Close dialog">×</button>
<!-- getByRole('button', { name: 'Close dialog' }) -->

<!-- 例 3: aria-labelledby -->
<h2 id="dialog-title">Confirmation</h2>
<div role="dialog" aria-labelledby="dialog-title">
  <!-- getByRole('dialog', { name: 'Confirmation' }) -->
</div>

<!-- 例 4: alt 属性 -->
<img src="logo.png" alt="Company Logo" />
<!-- getByRole('img', { name: 'Company Logo' }) -->
```

### 実践例

```typescript
// ナビゲーション
await page.getByRole('link', { name: 'Home' }).click()
await page.getByRole('link', { name: /about/i }).click()

// フォーム
await page.getByRole('textbox', { name: 'Email' }).fill('user@example.com')
await page.getByRole('textbox', { name: 'Password' }).fill('password')
await page.getByRole('checkbox', { name: 'Remember me' }).check()
await page.getByRole('button', { name: 'Login' }).click()

// 見出し
await expect(page.getByRole('heading', { name: 'Dashboard', level: 1 })).toBeVisible()

// リスト
const items = page.getByRole('listitem')
await expect(items).toHaveCount(3)

// テーブル
const table = page.getByRole('table')
await expect(table.getByRole('row')).toHaveCount(10)
```

---

## 高度なパターン

### フィルタリング

ロケーターを絞り込むための強力なフィルタリング機能：

```typescript
// hasText: 特定のテキストを含む要素
await page
  .getByRole('listitem')
  .filter({ hasText: 'Product 1' })
  .getByRole('button', { name: 'Add to cart' })
  .click()

// has: 特定の子要素を持つ要素
await page
  .getByRole('listitem')
  .filter({ has: page.getByText('In stock') })
  .getByRole('button', { name: 'Buy now' })
  .click()

// hasNot: 特定の子要素を持たない要素
await page
  .getByRole('listitem')
  .filter({ hasNot: page.getByText('Out of stock') })
  .getByRole('button', { name: 'Add to cart' })
  .click()

// 複数のフィルター
await page
  .getByRole('row')
  .filter({ hasText: 'Active' })
  .filter({ has: page.getByRole('button', { name: 'Edit' }) })
  .click()
```

### チェーニング（スコープの絞り込み）

ロケーターをチェーンすることで、特定の親要素内の子要素を検索できます：

```typescript
// 特定のカード内のボタンをクリック
const card = page.getByTestId('user-card-123')
await card.getByRole('button', { name: 'Edit' }).click()

// 特定のフォーム内の入力欄
const loginForm = page.getByRole('form', { name: 'Login' })
await loginForm.getByLabel('Email').fill('user@example.com')
await loginForm.getByLabel('Password').fill('password')
await loginForm.getByRole('button', { name: 'Submit' }).click()

// 特定のテーブル行内の操作
const row = page.getByRole('row').filter({ hasText: 'John Doe' })
await row.getByRole('button', { name: 'Delete' }).click()
```

### iframe 操作

iframe 内の要素にアクセスする：

```typescript
// iframe を取得
const frame = page.frameLocator('#iframe-id')

// iframe 内の要素を操作
await frame.getByRole('button', { name: 'Click me' }).click()

// 入れ子の iframe
const nestedFrame = page
  .frameLocator('#outer-iframe')
  .frameLocator('#inner-iframe')
await nestedFrame.getByText('Nested content').click()
```

### 組み合わせ例

```typescript
// 実践的な例: 商品リストから特定の商品をカートに追加
test('特定の商品をカートに追加', async ({ page }) => {
  await page.goto('/products')

  // 1. "In stock" の商品のみを対象
  // 2. その中から "Product 1" という名前の商品を検索
  // 3. その商品の "Add to cart" ボタンをクリック
  await page
    .getByRole('listitem')
    .filter({ has: page.getByText('In stock') })
    .filter({ hasText: 'Product 1' })
    .getByRole('button', { name: 'Add to cart' })
    .click()

  // カートに追加されたことを確認
  await expect(page.getByText('Added to cart')).toBeVisible()
})
```

---

## セマンティック HTML = テスタブルなアプリ

**テストしやすいアプリケーション = セマンティックで アクセシブルなアプリケーション**

### 悪い例（非セマンティック）

```html
<!-- ❌ 悪い例 -->
<div class="button" onclick="submit()">Submit</div>
<div class="input-container">
  <div>Email</div>
  <div contenteditable="true"></div>
</div>
```

```typescript
// テストが壊れやすい
await page.locator('.button').click()
await page.locator('[contenteditable]').fill('user@example.com')
```

### 良い例（セマンティック）

```html
<!-- ✅ 良い例 -->
<button type="submit">Submit</button>
<label for="email">Email</label>
<input id="email" type="email" />
```

```typescript
// テストが堅牢
await page.getByRole('button', { name: 'Submit' }).click()
await page.getByLabel('Email').fill('user@example.com')
```

### セマンティック HTML の原則

1. **適切な HTML 要素を使用**
   - ボタン → `<button>` （`<div role="button">` ではない）
   - リンク → `<a href>` （`<div onclick>` ではない）
   - 入力 → `<input>` / `<textarea>` （`<div contenteditable>` ではない）

2. **フォームコントロールにラベルを付与**
   ```html
   <!-- ✅ 良い例 -->
   <label for="email">Email</label>
   <input id="email" type="email" />

   <!-- または -->
   <label>
     Email
     <input type="email" />
   </label>
   ```

3. **ARIA はセマンティック HTML 不足時のみ**
   ```html
   <!-- ❌ 悪い例（不要な ARIA） -->
   <button role="button">Click me</button>

   <!-- ✅ 良い例（ARIA なし） -->
   <button>Click me</button>

   <!-- ✅ 良い例（ARIA が必要な場合） -->
   <div role="dialog" aria-labelledby="dialog-title">
     <h2 id="dialog-title">Confirmation</h2>
     <!-- ... -->
   </div>
   ```

---

## Do's & Don'ts

### ✅ Do's（推奨）

#### 1. ESLint で品質を保証

```json
{
  "extends": [
    "plugin:playwright/recommended",
    "plugin:@typescript-eslint/recommended"
  ],
  "rules": {
    // Promise の await 忘れを検出
    "@typescript-eslint/no-floating-promises": "error",

    // expect の await 忘れを検出
    "playwright/missing-playwright-await": "error",

    // getByTestId の過剰使用を警告
    "playwright/no-get-by-selector": "warn"
  }
}
```

#### 2. 複雑なロケーターは定数に抽出

```typescript
// ❌ 悪い例（ロケーターが重複）
test('test 1', async ({ page }) => {
  await page.getByRole('button', { name: 'Submit' }).click()
})

test('test 2', async ({ page }) => {
  await page.getByRole('button', { name: 'Submit' }).click()
})

// ✅ 良い例（定数に抽出）
const SUBMIT_BUTTON = page.getByRole('button', { name: 'Submit' })

test('test 1', async ({ page }) => {
  await SUBMIT_BUTTON.click()
})

test('test 2', async ({ page }) => {
  await SUBMIT_BUTTON.click()
})
```

#### 3. フィルタリング＋チェーニングを活用

```typescript
// ✅ 良い例（可読性が高い）
await page
  .getByRole('row')
  .filter({ hasText: 'John Doe' })
  .getByRole('button', { name: 'Edit' })
  .click()

// ❌ 悪い例（CSS セレクタで同じことをしようとする）
await page.locator('tr:has-text("John Doe") button:has-text("Edit")').click()
```

### ❌ Don'ts（非推奨）

#### 1. `page.waitForTimeout()` を使用しない

```typescript
// ❌ 悪い例（環境依存で不安定）
await page.waitForTimeout(1000)
await page.getByText('Success').click()

// ✅ 良い例（条件ベースの待機）
await expect(page.getByText('Success')).toBeVisible()
await page.getByText('Success').click()
```

#### 2. `data-testid` を全要素に付けない

```typescript
// ❌ 悪い例（セマンティックなロケーターを無視）
<button data-testid="submit-button">Submit</button>
await page.getByTestId('submit-button').click()

// ✅ 良い例（セマンティックなロケーターを優先）
<button>Submit</button>
await page.getByRole('button', { name: 'Submit' }).click()

// ✅ 許容される例（セマンティックな代替手段がない場合のみ）
<div data-testid="custom-widget">...</div>
await page.getByTestId('custom-widget').click()
```

#### 3. CSS 擬似クラス `:has-text()` を使用しない

```typescript
// ❌ 悪い例（非推奨の CSS 擬似クラス）
await page.locator('button:has-text("Submit")').click()

// ✅ 良い例（filter を使用）
await page.getByRole('button').filter({ hasText: 'Submit' }).click()

// ✅ さらに良い例（name オプションを使用）
await page.getByRole('button', { name: 'Submit' }).click()
```

#### 4. XPath を使用しない

```typescript
// ❌ 悪い例（XPath は複雑で Shadow DOM に対応していない）
await page.locator('//div[@id="container"]//button[text()="Submit"]').click()

// ✅ 良い例（getByRole + チェーニング）
await page.locator('#container').getByRole('button', { name: 'Submit' }).click()
```

#### 5. CSS ユーティリティクラスに依存しない

```typescript
// ❌ 悪い例（Tailwind CSS 等のクラスは変更されやすい）
await page.locator('.flex.items-center.bg-blue-500.text-white').click()

// ✅ 良い例（セマンティックなロケーター）
await page.getByRole('button', { name: 'Submit' }).click()

// ✅ 許容される例（data-testid を使用）
await page.getByTestId('submit-button').click()
```

---

## まとめ

### ロケーター選択のフローチャート

```
インタラクティブ要素？
├─ Yes → getByRole() を使用
│   └─ 複数の同じロールがある？
│       ├─ Yes → name オプションで絞り込み
│       └─ No → そのまま使用
│
├─ フォーム入力？
│   └─ getByLabel() を使用
│
├─ 画像？
│   └─ getByAltText() を使用
│
├─ セマンティックな代替手段がない？
│   └─ getByTestId() を使用
│
└─ テキストのみ？
    └─ getByText() を使用（最終手段）
```

### 重要なポイント

1. **`getByRole()` を最優先**
2. **セマンティック HTML を維持**
3. **CSS セレクタ・XPath は避ける**
4. **ESLint でコード品質を保証**
5. **フィルタリング＋チェーニングで可読性を向上**

---

---

## Shadow DOM コンポーネントのロケーティング

Shadow DOM内の要素にアクセスするには、ホスト要素を特定してからその内部を探索します。

### ホスト要素からのアクセス

```typescript
// Shadow DOMを持つカスタムコンポーネント
const host = page.locator('custom-button')

// Shadow DOM内のボタンを直接操作
await host.getByRole('button', { name: 'Click me' }).click()

// より複雑な例
const shadowHost = page.locator('user-card')
await shadowHost.getByText('John Doe').click()
await expect(shadowHost.getByRole('heading', { name: 'Profile' })).toBeVisible()
```

### locatorとgetByRoleの組み合わせ

Playwrightは自動的にShadow DOM境界を越えて要素を検索します：

```typescript
// Shadow DOM内のネストされた要素
await page
  .locator('app-root')
  .locator('user-profile')
  .getByRole('button', { name: 'Edit' })
  .click()
```

### 注意点

- PlaywrightのgetBy\*ロケーターは自動的にShadow DOMを貫通します
- XPathはShadow DOM内では機能しません
- CSSセレクタは`:shadow`疑似セレクタでアクセス可能ですが、非推奨です

---

## iframe / ネストされたフレームの操作

### frameLocator() を使った基本操作

```typescript
// iframeを特定
const frame = page.frameLocator('#payment-frame')

// iframe内の要素を操作
await frame.getByLabel('Card Number').fill('4242 4242 4242 4242')
await frame.getByLabel('Expiry Date').fill('12/25')
await frame.getByRole('button', { name: 'Pay' }).click()
```

### ネストされたフレームの扱い

```typescript
// 外側のフレーム → 内側のフレーム
const outer = page.frameLocator('frame[name="frame-top"]')
const inner = outer.frameLocator('frame[name="frame-left"]')

// ネストされたフレーム内の要素をアサート
await expect(inner.locator('body')).toContainText('Content')
```

### contentFrame() による代替アプローチ

```typescript
// locator → Frame オブジェクト取得
const frameElement = page.locator('#my-iframe')
const frame = await frameElement.contentFrame()

if (frame) {
  await frame.getByRole('button', { name: 'Submit' }).click()
}
```

**推奨**: `frameLocator()` を使用する方がシンプルで、チェーニングが可能です。

---

## アラート・確認ダイアログのハンドリング

JavaScriptダイアログ（alert、confirm、prompt）はブラウザネイティブのモーダルウィンドウです。

### ダイアログイベントのリスニング

```typescript
// 全種類のダイアログを処理
page.on('dialog', async dialog => {
  console.log(`Dialog: ${dialog.type()} - ${dialog.message()}`)

  if (dialog.type() === 'alert') {
    await dialog.accept()
  } else if (dialog.type() === 'confirm') {
    await dialog.accept()  // OK をクリック
    // または
    // await dialog.dismiss()  // Cancel をクリック
  } else if (dialog.type() === 'prompt') {
    await dialog.accept('My Answer')  // テキスト入力 + OK
  }
})

// ダイアログをトリガーするアクション
await page.getByRole('button', { name: 'Show Alert' }).click()
```

### page.once() で単発のダイアログに対応

```typescript
// 1回だけ実行されるハンドラー
page.once('dialog', dialog => dialog.accept())
await page.getByRole('button', { name: 'Confirm Action' }).click()
```

### メッセージ内容のアサーション

```typescript
page.on('dialog', async dialog => {
  expect(dialog.message()).toBe('Are you sure you want to delete this item?')
  await dialog.accept()
})

await page.getByRole('button', { name: 'Delete' }).click()
```

**重要**: ダイアログをacceptまたはdismissしないと、テストが停止します。

---

## フォールバックセレクターの使い分け

セマンティックなロケーター（getByRole等）が使えない場合の選択肢。

### CSS セレクター

```typescript
// ID属性
await page.locator('#login-form').fill('user@example.com')

// クラス名
await page.locator('.submit-button').click()

// 属性セレクタ
await page.locator('[data-automation-id="checkout-btn"]').click()

// 複合セレクタ（可能な限り避ける）
await page.locator('div.container > form#login input[type="email"]').fill('test@example.com')
```

### XPath（最終手段）

```typescript
// テキスト内容で検索
await page.locator('//button[contains(text(), "Submit")]').click()

// 親要素からの相対検索
await page.locator('//form[@id="login"]//input[@type="password"]').fill('secret')

// 属性ベース
await page.locator('//div[@data-testid="user-card"]//button').click()
```

**XPathの制限**:
- Shadow DOMに対応していない
- パフォーマンスがCSS/getByRoleより劣る
- 可読性が低い

### テキストベースセレクタ

```typescript
// 部分一致（デフォルト）
await page.getByText('Welcome').click()

// 完全一致
await page.getByText('Login', { exact: true }).click()

// 正規表現
await page.getByText(/sign in/i).click()

// フィルタリングと組み合わせ
await page.getByRole('button').filter({ hasText: 'Submit' }).click()
```

### data-testid の戦略的使用

```typescript
// HTML: <button data-testid="checkout-button">Checkout</button>
await page.getByTestId('checkout-button').click()

// カスタム属性名の設定（playwright.config.ts）
export default defineConfig({
  use: {
    testIdAttribute: 'data-automation-id'
  }
})
```

**data-testidを使うべき場合**:
- セマンティックな代替手段がない
- サードパーティコンポーネント
- 動的に生成されるUI

---

## 動的要素のカスタムwait戦略

### waitForSelector() の活用

```typescript
// 要素が表示されるまで待機（状態指定）
await page.waitForSelector('.loading-spinner', { state: 'visible' })
await page.waitForSelector('.loading-spinner', { state: 'hidden' })

// タイムアウトカスタマイズ
await page.waitForSelector('#submit-button', {
  state: 'visible',
  timeout: 10000
})
```

### カスタム条件での待機

```typescript
// ページ内のJavaScript変数が特定の値になるまで待機
await page.waitForFunction(() => window.appReady === true)

// DOM要素の特定の状態を待機
await page.waitForFunction(selector => {
  const el = document.querySelector(selector)
  return el && el.classList.contains('loaded')
}, '#data-table')
```

### ネットワーク完了を待つ

```typescript
// 特定のAPIレスポンスを待機
await Promise.all([
  page.waitForResponse(resp => resp.url().includes('/api/user') && resp.status() === 200),
  page.getByRole('button', { name: 'Load Profile' }).click()
])
```

---

**次のステップ**: [FIXTURES-AND-POM.md](./FIXTURES-AND-POM.md) で Fixture と Page Object Model を学習してください。
