# Playwright Test 基礎

このドキュメントでは、Playwright Test の基本的なテスト記述方法、Actions（操作）、Assertions（アサーション）、および設定について解説します。

---

## 📑 目次

1. [テスト記述の基本](#テスト記述の基本)
2. [Actions（操作）](#actions操作)
3. [Assertions（アサーション）](#assertionsアサーション)
4. [async/await パターン](#asyncawait-パターン)
5. [テストランナーの理解](#テストランナーの理解)
6. [設定（playwright.config.ts）](#設定playwrightconfigts)
7. [❌ 典型的なミス（アンチパターン）](#-典型的なミスアンチパターン)

---

## テスト記述の基本

### Arrange-Act-Assert パターン

すべての Playwright Test は **AAA パターン**に従って記述することを推奨します：

```typescript
import { test, expect } from '@playwright/test'

test('ログインフォームが正しく動作する', async ({ page }) => {
  // Arrange（準備）: 初期状態をセットアップ
  await page.goto('/login')

  // Act（実行）: ユーザー操作を実行
  await page.getByLabel('Email').fill('user@example.com')
  await page.getByLabel('Password').fill('password123')
  await page.getByRole('button', { name: 'Login' }).click()

  // Assert（検証）: 結果を検証
  await expect(page).toHaveURL('/dashboard')
  await expect(page.getByRole('heading', { name: 'Welcome' })).toBeVisible()
})
```

### test.step() でテストを論理的に分割

複雑なテストは `test.step()` を使って論理的なステップに分割できます：

```typescript
test('商品購入フロー', async ({ page }) => {
  await test.step('ホーム画面に移動', async () => {
    await page.goto('/')
    await expect(page).toHaveTitle('My Shop')
  })

  await test.step('商品を検索', async () => {
    await page.getByPlaceholder('Search products').fill('laptop')
    await page.getByRole('button', { name: 'Search' }).click()
    await expect(page.getByText('Search results for "laptop"')).toBeVisible()
  })

  await test.step('商品をカートに追加', async () => {
    await page.getByRole('button', { name: 'Add to cart' }).first().click()
    await expect(page.getByText('Added to cart')).toBeVisible()
  })

  await test.step('チェックアウト', async () => {
    await page.getByRole('link', { name: 'Cart' }).click()
    await page.getByRole('button', { name: 'Checkout' }).click()
    await expect(page).toHaveURL('/checkout')
  })
})
```

**メリット:**
- レポートで各ステップの成功/失敗が明確に表示される
- 失敗したステップを特定しやすい
- テストの可読性が向上

### describe / beforeEach / afterEach

関連するテストをグループ化する場合は `describe` を使用します：

```typescript
import { test, expect } from '@playwright/test'

test.describe('ユーザー認証', () => {
  test.beforeEach(async ({ page }) => {
    // 各テストの前に実行される
    await page.goto('/login')
  })

  test.afterEach(async ({ page }) => {
    // 各テストの後に実行される
    await page.context().clearCookies()
  })

  test('有効な認証情報でログイン成功', async ({ page }) => {
    await page.getByLabel('Email').fill('user@example.com')
    await page.getByLabel('Password').fill('password')
    await page.getByRole('button', { name: 'Login' }).click()

    await expect(page).toHaveURL('/dashboard')
  })

  test('無効な認証情報でログイン失敗', async ({ page }) => {
    await page.getByLabel('Email').fill('invalid@example.com')
    await page.getByLabel('Password').fill('wrong')
    await page.getByRole('button', { name: 'Login' }).click()

    await expect(page.getByText('Invalid credentials')).toBeVisible()
  })
})
```

### Tags（タグ）によるフィルタリング

テストにタグを付けて、特定のテストグループのみ実行できます：

```typescript
test('重要な機能のテスト @smoke @critical', async ({ page }) => {
  // テスト内容
})

test('API統合テスト @integration', async ({ page }) => {
  // テスト内容
})

test('モバイル表示テスト @mobile', async ({ page }) => {
  // テスト内容
})
```

**実行例:**

```bash
# @smoke タグを持つテストのみ実行
npx playwright test --grep @smoke

# @mobile タグを除外して実行
npx playwright test --grep-invert @mobile

# @smoke かつ @critical のテストを実行
npx playwright test --grep "(?=.*@smoke)(?=.*@critical)"
```

### Projects によるテストグループ化

`playwright.config.ts` で複数のプロジェクトを定義し、異なる設定でテストを実行できます：

```typescript
// playwright.config.ts
export default defineConfig({
  projects: [
    // デスクトップブラウザ
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },

    // モバイルブラウザ
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
    },

    // 認証が必要なテスト
    {
      name: 'authenticated',
      use: { storageState: '.auth/user.json' },
      dependencies: ['setup'],  // setup プロジェクト完了後に実行
    },

    // 認証セットアップ
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },
  ],
})
```

**特定のプロジェクトのみ実行:**

```bash
# chromium プロジェクトのみ実行
npx playwright test --project=chromium

# authenticated プロジェクトのみ実行
npx playwright test --project=authenticated
```

---

## Actions（操作）

### ナビゲーション

```typescript
// ページに移動
await page.goto('https://example.com')
await page.goto('/relative-path')  // baseURL が設定されている場合

// URL検証
await expect(page).toHaveURL('https://example.com/dashboard')
await expect(page).toHaveURL(/\/dashboard/)  // 正規表現
```

### フォーム操作

```typescript
// テキスト入力
await page.getByLabel('Email').fill('user@example.com')

// 入力内容をクリア
await page.getByLabel('Email').clear()

// チェックボックス
await page.getByLabel('Remember me').check()
await page.getByLabel('Remember me').uncheck()

// ラジオボタン
await page.getByLabel('Male').check()

// セレクトボックス
await page.getByLabel('Country').selectOption('Japan')
await page.getByLabel('Country').selectOption({ label: 'Japan' })
await page.getByLabel('Country').selectOption({ value: 'jp' })

// 複数選択
await page.getByLabel('Languages').selectOption(['en', 'ja', 'fr'])
```

### クリックパターン

```typescript
// 通常のクリック
await page.getByRole('button', { name: 'Submit' }).click()

// ダブルクリック
await page.getByRole('button', { name: 'Edit' }).dblclick()

// 右クリック
await page.getByRole('button', { name: 'Item' }).click({ button: 'right' })

// Shift + クリック（複数選択）
await page.getByText('Item 1').click()
await page.getByText('Item 2').click({ modifiers: ['Shift'] })

// Ctrl + クリック（新しいタブで開く）
await page.getByRole('link', { name: 'Open in new tab' }).click({ modifiers: ['Control'] })

// カスタムイベントをディスパッチ
await page.getByRole('button', { name: 'Custom' }).dispatchEvent('click')
```

### ドラッグ＆ドロップ

```typescript
// 要素を別の要素にドラッグ
await page.getByText('Draggable item').dragTo(page.getByText('Drop zone'))

// 相対的な位置にドラッグ
await page.getByText('Draggable item').dragTo(page.getByText('Drop zone'), {
  targetPosition: { x: 10, y: 10 },
})
```

### ファイルアップロード

```typescript
// 単一ファイル
await page.getByLabel('Upload file').setInputFiles('path/to/file.pdf')

// 複数ファイル
await page.getByLabel('Upload files').setInputFiles([
  'path/to/file1.pdf',
  'path/to/file2.pdf',
])

// ファイル選択を解除
await page.getByLabel('Upload file').setInputFiles([])

// Buffer からアップロード
await page.getByLabel('Upload file').setInputFiles({
  name: 'file.txt',
  mimeType: 'text/plain',
  buffer: Buffer.from('file content'),
})
```

### オーバーレイ対策

Cookie 同意バナーなど、繰り返し表示されるオーバーレイを自動的に処理する：

```typescript
// Cookie バナーを自動的に閉じる
await page.addLocatorHandler(
  page.getByRole('button', { name: 'Accept cookies' }),
  async (locator) => {
    await locator.click()
  }
)

// その後の操作は Cookie バナーが自動的に処理される
await page.getByRole('link', { name: 'Products' }).click()
await page.getByRole('button', { name: 'Add to cart' }).click()
```

---

## Assertions（アサーション）

### 判断基準テーブル

Playwright には 3 種類のアサーションがあります。適切なものを選択してください：

| 種類 | 特徴 | 用途 | 例 |
|------|------|------|-----|
| **Generic Assertions** | 同期、リトライなし | 値の比較 | `expect(val).toBe(x)` |
| **Web-First Assertions** | 非同期、自動リトライ | DOM 検証 | `await expect(loc).toBeVisible()` |
| **ARIA Snapshot** | 構造検証 | アクセシビリティ | `toMatchAriaSnapshot()` |

**原則:**
- **DOM 要素の検証には必ず Web-First Assertions を使用**
- Generic Assertions は変数の比較のみに使用

### Web-First Assertions 一覧

Web-First Assertions は **自動リトライ**機能を持ち、要素が条件を満たすまで待機します（デフォルト 5 秒）。

#### 可視性

```typescript
// 要素が表示されている
await expect(page.getByText('Success')).toBeVisible()

// 要素が非表示
await expect(page.getByText('Loading')).toBeHidden()
```

#### テキスト内容

```typescript
// 完全一致
await expect(page.getByRole('heading')).toHaveText('Welcome')

// 部分一致
await expect(page.getByRole('heading')).toContainText('Welc')

// 正規表現
await expect(page.getByRole('heading')).toHaveText(/welcome/i)

// 複数要素のテキスト検証
await expect(page.getByRole('listitem')).toHaveText(['Item 1', 'Item 2', 'Item 3'])
```

#### 属性

```typescript
// 属性の値を検証
await expect(page.getByRole('link', { name: 'Home' })).toHaveAttribute('href', '/')

// 属性の存在を検証
await expect(page.getByRole('button')).toHaveAttribute('disabled')

// CSS クラスを検証
await expect(page.getByRole('button')).toHaveClass('btn btn-primary')
await expect(page.getByRole('button')).toHaveClass(/btn-primary/)
```

#### フォーム要素

```typescript
// チェックボックス・ラジオボタン
await expect(page.getByLabel('Remember me')).toBeChecked()
await expect(page.getByLabel('Remember me')).not.toBeChecked()

// 入力値
await expect(page.getByLabel('Email')).toHaveValue('user@example.com')
await expect(page.getByLabel('Email')).toHaveValue(/user@/)

// 有効/無効
await expect(page.getByRole('button', { name: 'Submit' })).toBeEnabled()
await expect(page.getByRole('button', { name: 'Submit' })).toBeDisabled()
```

#### 要素数

```typescript
// 要素数を検証
await expect(page.getByRole('listitem')).toHaveCount(3)

// 空でないことを検証
await expect(page.getByRole('listitem')).toHaveCount(0)
```

#### ページレベル

```typescript
// タイトル
await expect(page).toHaveTitle('My App')
await expect(page).toHaveTitle(/My App/)

// URL
await expect(page).toHaveURL('https://example.com/dashboard')
await expect(page).toHaveURL(/\/dashboard/)
```

### ARIA Snapshot

ARIA Snapshot は、アクセシビリティツリーの構造を検証するための強力な機能です。

```typescript
// 基本的な使い方
await expect(page.locator('nav')).toMatchAriaSnapshot(`
- navigation
  - link "Home"
  - link "About"
  - link "Contact"
`)

// 複雑な構造の検証
await expect(page.locator('main')).toMatchAriaSnapshot(`
- main
  - heading "Product List" [level=1]
  - list
    - listitem
      - heading "Product 1" [level=2]
      - button "Add to cart"
    - listitem
      - heading "Product 2" [level=2]
      - button "Add to cart"
`)

// フォームの構造検証
await expect(page.locator('form')).toMatchAriaSnapshot(`
- form
  - textbox "Email" [required]
  - textbox "Password" [required]
  - checkbox "Remember me"
  - button "Login"
`)
```

**メリット:**
- セマンティック HTML とアクセシビリティを同時に検証
- 構造の変更を検出
- スクリーンリーダーユーザーの体験を保証

### Generic Assertions（変数の比較のみ）

Generic Assertions は**リトライしない**ため、DOM 要素の検証には使用しないでください。

```typescript
// ✅ 良い例（変数の比較）
const count = await page.getByRole('listitem').count()
expect(count).toBe(3)

const title = await page.title()
expect(title).toBe('My App')

// ❌ 悪い例（DOM 要素の検証に Generic Assertions を使用）
const text = await page.getByText('Loading').textContent()
expect(text).toBe('Loading')  // リトライしないため、タイミングによって失敗する

// ✅ 良い例（Web-First Assertions を使用）
await expect(page.getByText('Loading')).toHaveText('Loading')
```

---

## async/await パターン

### Promise.all でのレースコンディション回避

複数の非同期操作を並列実行する場合、`Promise.all` を使用します：

```typescript
// ❌ 悪い例（レースコンディション発生の可能性）
await page.getByRole('button', { name: 'Click me' }).click()
await page.waitForURL('/next-page')  // クリックのイベントがまだ発火していない可能性

// ✅ 良い例（Promise.all で並列実行）
await Promise.all([
  page.waitForURL('/next-page'),  // 先に待機を開始
  page.getByRole('button', { name: 'Click me' }).click(),  // その後クリック
])
```

### Delayed await パターン（popup 待機）

新しいタブやポップアップを開く操作では、**Delayed await パターン**を使用します：

```typescript
// ✅ 正しいパターン
const popupPromise = page.waitForEvent('popup')  // 先に Promise を作成
await page.getByRole('button', { name: 'Open popup' }).click()  // その後クリック
const popup = await popupPromise  // Promise を await

await expect(popup).toHaveTitle('Popup title')
await popup.close()
```

**理由:**
- `page.waitForEvent('popup')` を先に呼び出すことで、イベントリスナーが確実に登録される
- クリック後にイベントが発火しても、リスナーがすでに待機しているため見逃さない

---

## テストランナーの理解

### Playwright Test と Playwright Library の違い

**用途区別:**
- **Playwright Test** (`@playwright/test`): テストランナー内蔵、オールインワンソリューション
- **Playwright Library** (`playwright`): ブラウザ自動化API、Jest/Mocha等と組み合わせ可能

**選択基準:**
| 用途 | 推奨 |
|------|------|
| E2Eテストスイート構築 | Playwright Test |
| Web スクレイピング・データ抽出 | Playwright Library |
| 既存テストフレームワーク統合 | Playwright Library |
| CI/CD パイプライン組み込み | Playwright Test |

**Playwright Test の主要機能:**
- 自動テストファイル認識（`*.spec.ts`, `*.test.ts`）
- 並列実行（複数ワーカー）
- ビジュアルレポート生成
- CLI オプション（デバッグ、ビデオ録画等）
- Web-First Assertions（自動リトライ機能付き）

### テストランナー CLI オプション

**基本実行:**
```bash
npx playwright test                    # 全テスト実行
npx playwright test tests/login.spec.ts  # 特定ファイル実行
npx playwright test --headed             # ブラウザUI表示
npx playwright test --debug              # デバッグモード
```

**並列実行制御:**
```bash
npx playwright test --workers=4          # ワーカー数指定
npx playwright test --workers=50%        # CPU コア数の50%
```

**ブラウザ・プロジェクト指定:**
```bash
npx playwright test --project=chromium   # 特定プロジェクトのみ
npx playwright test --project=firefox
```

**フィルタリング:**
```bash
npx playwright test --grep @smoke       # @smoke タグを含むテスト
npx playwright test --grep-invert @slow # @slow タグを除外
```

**レポート:**
```bash
npx playwright test --reporter=html     # HTML レポート生成
npx playwright test --reporter=list     # リスト形式
npx playwright test --reporter=json     # JSON 出力
npx playwright show-report              # レポート表示
```

### 並列実行とテスト分離

**並列実行の仕組み:**
- Playwright Test はデフォルトで複数ワーカープロセスで並列実行
- 各ワーカーは独立したブラウザコンテキストを持つ
- CPU コア数に応じて自動調整（`workers: undefined`）

**テスト分離の保証:**
- 各テストは新しい `BrowserContext` で実行
- Cookie、LocalStorage、SessionStorage は完全分離
- テスト間の状態共有を防ぎ、flaky test を回避

**設定例:**
```typescript
export default defineConfig({
  workers: process.env.CI ? 1 : undefined, // CI では逐次、ローカルでは並列
  fullyParallel: true, // 1ファイル内のテストも並列化
})
```

### Hooks と Fixtures

**Hooks（ライフサイクル制御）:**
- `test.beforeAll`: 全テスト前に1回実行（高コストなセットアップ）
- `test.beforeEach`: 各テスト前に実行（初期状態準備）
- `test.afterEach`: 各テスト後に実行（クリーンアップ）
- `test.afterAll`: 全テスト後に1回実行（最終クリーンアップ）

**Fixtures（リソース管理）:**
- `{ page }`: ブラウザページインスタンス（自動作成・破棄）
- `{ browser }`: ブラウザインスタンス
- `{ context }`: ブラウザコンテキスト
- `{ request }`: API リクエストクライアント（HTTP 通信用）

**requestフィクスチャの活用例:**
```typescript
test('API経由で認証後、UIで検証', async ({ request, page }) => {
  // API でログイン（高速）
  const response = await request.post('/api/auth/login', {
    data: { username: 'user', password: 'pass' }
  })
  expect(response.status()).toBe(200)

  // UI でログイン状態を確認
  await page.goto('/dashboard')
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
})
```

---

## 設定（playwright.config.ts）

### 基本設定

```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  // テストディレクトリ
  testDir: './e2e',

  // テストファイルのパターン
  testMatch: '**/*.spec.ts',

  // 無視するファイル
  testIgnore: '**/drafts/**',

  // 並列実行
  fullyParallel: true,

  // CI では .only を禁止
  forbidOnly: !!process.env.CI,

  // リトライ設定
  retries: process.env.CI ? 2 : 0,

  // ワーカー数
  workers: process.env.CI ? 1 : undefined,

  // タイムアウト設定
  timeout: 30 * 1000,  // 各テストのタイムアウト（30秒）

  // expect のタイムアウト
  expect: {
    timeout: 5000,  // Web-First Assertions のタイムアウト（5秒）
  },

  // レポーター
  reporter: process.env.CI
    ? [['html'], ['github']]
    : 'html',

  // 共通設定
  use: {
    // ベース URL
    baseURL: 'http://localhost:3000',

    // トレース記録
    trace: 'on-first-retry',

    // スクリーンショット
    screenshot: 'only-on-failure',

    // ビデオ録画
    video: 'retain-on-failure',
  },

  // 開発サーバー起動
  webServer: {
    command: 'npm run start',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },

  // プロジェクト設定
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
})
```

### 主要設定項目詳細

**テストディレクトリ・ファイルマッチング:**
```typescript
export default defineConfig({
  testDir: './tests',               // テストファイル配置ディレクトリ
  testMatch: '**/*.spec.ts',        // テストファイルパターン
  testIgnore: '**/drafts/**',       // 除外するファイル・ディレクトリ
})
```

**タイムアウト設定:**
```typescript
export default defineConfig({
  timeout: 30000,                   // 各テストのタイムアウト（30秒）
  globalTimeout: 1800000,           // テストスイート全体のタイムアウト（30分）
  expect: {
    timeout: 5000,                  // Web-First Assertions のタイムアウト（5秒）
  },
  use: {
    actionTimeout: 10000,           // 個別アクション（click, fill等）のタイムアウト（10秒）
  },
})
```

**並列実行とワーカー設定:**
```typescript
export default defineConfig({
  workers: process.env.CI ? 1 : undefined, // ワーカー数（undefined = CPUコア数）
  fullyParallel: true,              // 1ファイル内のテストも並列化
})
```

**リトライと失敗処理:**
```typescript
export default defineConfig({
  retries: process.env.CI ? 2 : 0,  // 失敗時のリトライ回数（CI環境のみ）
  maxFailures: 10,                  // 指定数の失敗でテスト実行停止
})
```

**レポーター設定:**
```typescript
export default defineConfig({
  reporter: process.env.CI
    ? [
        ['list'],
        ['html', { outputFolder: 'playwright-report', open: 'never' }], // CI では自動オープン無効
        ['github'], // GitHub Actions 用レポーター
      ]
    : [['html']], // ローカルでは HTML レポートのみ
})
```

**ブラウザ・コンテキストオプション:**
```typescript
export default defineConfig({
  use: {
    browserName: 'chromium',        // デフォルトブラウザ
    headless: true,                 // ヘッドレスモード
    viewport: { width: 1280, height: 720 }, // ビューポートサイズ
    locale: 'ja-JP',                // ロケール
    timezoneId: 'Asia/Tokyo',       // タイムゾーン
    trace: 'on-first-retry',        // トレース記録タイミング
    screenshot: 'only-on-failure',  // スクリーンショット取得タイミング
    video: 'retain-on-failure',     // ビデオ録画保持条件
  },
})
```

**Projects（複数ブラウザ・環境テスト）:**
```typescript
export default defineConfig({
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'authenticated',
      use: { storageState: '.auth/user.json' }, // 認証済み状態
      dependencies: ['setup'],  // setup プロジェクト完了後に実行
    },
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },
  ],
})
```

**webServer（開発サーバー自動起動）:**
```typescript
export default defineConfig({
  webServer: {
    command: 'npm run start',       // 起動コマンド
    url: 'http://localhost:3000',   // 起動確認URL
    reuseExistingServer: !process.env.CI, // ローカルでは既存サーバー利用
    timeout: 120000,                // 起動タイムアウト（120秒）
  },
})
```

**globalSetup / globalTeardown:**
```typescript
export default defineConfig({
  globalSetup: require.resolve('./global-setup'), // 全テスト前に1回実行
  globalTeardown: require.resolve('./global-teardown'), // 全テスト後に1回実行
})
```

### 環境変数の活用

```typescript
// .env ファイル（.gitignore に追加）
// BASE_URL=http://localhost:3000
// CI=true

// playwright.config.ts
export default defineConfig({
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
  },
  retries: process.env.CI ? 2 : 0,
})
```

---

## ❌ 典型的なミス（アンチパターン）

### 1. `await` の忘れ

```typescript
// ❌ 悪い例（await を忘れる）
page.goto('/')  // Promise が返されるが await していない
expect(page).toHaveURL('/')  // 前の操作が完了していない可能性

// ✅ 良い例
await page.goto('/')
await expect(page).toHaveURL('/')
```

**ESLint で検出:**
```json
{
  "extends": ["plugin:@typescript-eslint/recommended"],
  "rules": {
    "@typescript-eslint/no-floating-promises": "error"
  }
}
```

### 2. Generic Assertions で DOM を検証

```typescript
// ❌ 悪い例（リトライしない）
const text = await page.getByText('Loading').textContent()
expect(text).toBe('Loading')

// ✅ 良い例（自動リトライ）
await expect(page.getByText('Loading')).toHaveText('Loading')
```

### 3. `page.waitForTimeout()` の使用

```typescript
// ❌ 悪い例（環境依存で不安定）
await page.waitForTimeout(3000)  // 3秒待つ
await page.getByText('Success').click()

// ✅ 良い例（条件ベースの待機）
await expect(page.getByText('Success')).toBeVisible()
await page.getByText('Success').click()
```

### 4. CSS セレクタの乱用

```typescript
// ❌ 悪い例（壊れやすい）
await page.locator('.btn.btn-primary.bg-blue-500').click()

// ✅ 良い例（セマンティック）
await page.getByRole('button', { name: 'Submit' }).click()
```

---

**次のステップ**: [LOCATORS.md](./LOCATORS.md) でロケーター戦略を学習してください。
