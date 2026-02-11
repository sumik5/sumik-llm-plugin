# E2Eテスト: 認証とセキュリティ

## 概要

認証フローのテストは、Webアプリケーションのセキュリティと信頼性を保証するために不可欠です。ログイン/ログアウト、セッション管理、複数ユーザーロールのテスト、OAuth等の複雑な認証メカニズムに対応する必要があります。

---

## ログイン/ログアウトフローのテスト

### 基本的なログインテスト

```typescript
test('有効な認証情報でログイン', async ({ page }) => {
  await page.goto('https://www.saucedemo.com/');

  await page.getByPlaceholder('Username').fill('standard_user');
  await page.getByPlaceholder('Password').fill('secret_sauce');
  await page.getByRole('button', { name: 'Login' }).click();

  // ログイン成功を検証
  await expect(page).toHaveURL('https://www.saucedemo.com/inventory.html');
  await expect(page.getByText('Products')).toBeVisible();
});
```

### ログアウトフローのテスト

```typescript
test('ログアウトでセッションをクリア', async ({ page }) => {
  // ログイン状態を前提
  await page.goto('https://www.saucedemo.com/inventory.html', {
    storageState: 'auth/user.json'  // 事前保存したセッション
  });

  // ログアウト実行
  await page.getByRole('button', { name: 'Open Menu' }).click();
  await page.getByRole('link', { name: 'Logout' }).click();

  // ログアウト後の検証
  await expect(page).toHaveURL('https://www.saucedemo.com/');
  await expect(page.getByPlaceholder('Username')).toBeVisible();

  // セッション無効化の確認
  await page.goto('https://www.saucedemo.com/inventory.html');
  await expect(page).toHaveURL('https://www.saucedemo.com/');  // リダイレクト
});
```

---

## セッション永続化（storageState）

### ログイン状態の保存

```typescript
// setup/auth.setup.ts
import { test as setup } from '@playwright/test';

setup('authenticate as standard user', async ({ page }) => {
  await page.goto('https://www.saucedemo.com/');
  await page.getByPlaceholder('Username').fill('standard_user');
  await page.getByPlaceholder('Password').fill('secret_sauce');
  await page.getByRole('button', { name: 'Login' }).click();

  // ログイン成功を確認
  await expect(page).toHaveURL(/inventory/);

  // セッション状態を保存
  await page.context().storageState({ path: 'auth/standard-user.json' });
});
```

### playwright.config.ts で設定

```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'setup',
      testMatch: /auth\.setup\.ts/,
    },
    {
      name: 'authenticated tests',
      dependencies: ['setup'],
      use: {
        storageState: 'auth/standard-user.json',
      },
    },
  ],
});
```

### テストでの利用

```typescript
test('ログイン済み状態でカート操作', async ({ page }) => {
  // storageState が自動的に適用される
  await page.goto('https://www.saucedemo.com/inventory.html');

  await page.getByRole('button', { name: 'Add to cart' }).first().click();
  await expect(page.locator('.shopping_cart_badge')).toHaveText('1');
});
```

---

## 複数ユーザーロールのテスト

### ロールごとのセットアップ

```typescript
// setup/auth.setup.ts
setup('authenticate as admin', async ({ page }) => {
  await page.goto('https://example.com/login');
  await page.fill('[name="username"]', 'admin@example.com');
  await page.fill('[name="password"]', 'admin_password');
  await page.click('button[type="submit"]');
  await page.waitForURL('/dashboard');

  await page.context().storageState({ path: 'auth/admin.json' });
});

setup('authenticate as user', async ({ page }) => {
  await page.goto('https://example.com/login');
  await page.fill('[name="username"]', 'user@example.com');
  await page.fill('[name="password"]', 'user_password');
  await page.click('button[type="submit"]');
  await page.waitForURL('/dashboard');

  await page.context().storageState({ path: 'auth/user.json' });
});
```

### プロジェクトごとの分離

```typescript
export default defineConfig({
  projects: [
    {
      name: 'setup',
      testMatch: /auth\.setup\.ts/,
    },
    {
      name: 'admin tests',
      dependencies: ['setup'],
      use: { storageState: 'auth/admin.json' },
      testMatch: /admin\.spec\.ts/,
    },
    {
      name: 'user tests',
      dependencies: ['setup'],
      use: { storageState: 'auth/user.json' },
      testMatch: /user\.spec\.ts/,
    },
  ],
});
```

---

## 複雑な認証メソッドのハンドリング

### OAuth 2.0 フロー

OAuth認証は通常、サードパーティプロバイダー（Google、GitHub等）を経由するため、テスト環境では以下の戦略を使用します。

**1. トークン直接設定（推奨）**

```typescript
test.beforeEach(async ({ page }) => {
  // ローカルストレージにトークンを直接設定
  await page.goto('https://example.com');
  await page.evaluate((token) => {
    localStorage.setItem('access_token', token);
    localStorage.setItem('refresh_token', 'test_refresh_token');
  }, process.env.TEST_ACCESS_TOKEN);

  await page.reload();
});
```

**2. モックプロバイダー使用**

```typescript
test('OAuth経由でログイン', async ({ page, context }) => {
  // OAuth プロバイダーをモック
  await context.route('**/oauth/authorize', route => {
    route.fulfill({
      status: 302,
      headers: {
        'Location': 'https://example.com/callback?code=test_auth_code'
      }
    });
  });

  await page.goto('https://example.com/login');
  await page.click('button:has-text("Login with OAuth")');

  await expect(page).toHaveURL(/dashboard/);
});
```

### SAML認証

```typescript
test('SAML認証フロー', async ({ page, context }) => {
  // SAML レスポンスをモック
  await context.route('**/saml/acs', route => {
    route.fulfill({
      status: 200,
      body: '<samlp:Response>...</samlp:Response>',
      headers: { 'Content-Type': 'application/xml' }
    });
  });

  await page.goto('https://example.com/login');
  await page.click('button:has-text("SSO Login")');

  await expect(page).toHaveURL(/dashboard/);
});
```

### 多要素認証（MFA）

```typescript
test('MFAコード入力', async ({ page }) => {
  await page.goto('https://example.com/login');
  await page.fill('[name="email"]', 'user@example.com');
  await page.fill('[name="password"]', 'password123');
  await page.click('button[type="submit"]');

  // MFAページへの遷移を待機
  await expect(page).toHaveURL(/mfa/);

  // テスト用固定MFAコードを使用
  await page.fill('[name="mfa_code"]', '123456');
  await page.click('button:has-text("Verify")');

  await expect(page).toHaveURL(/dashboard/);
});
```

**本番環境でのMFAテスト:**
- TOTP（Time-based OTP）ライブラリを使用してコード生成
- テスト専用のMFAシークレットを環境変数で管理

```typescript
import { authenticator } from 'otplib';

const mfaCode = authenticator.generate(process.env.MFA_SECRET);
await page.fill('[name="mfa_code"]', mfaCode);
```

---

## トークン管理とセキュリティテストパターン

### トークンリフレッシュのテスト

```typescript
test('トークン期限切れ時に自動更新', async ({ page, context }) => {
  let refreshCount = 0;

  await context.route('**/api/refresh', route => {
    refreshCount++;
    route.fulfill({
      status: 200,
      body: JSON.stringify({ access_token: 'new_token_' + refreshCount })
    });
  });

  // 期限切れトークンを設定
  await page.goto('https://example.com');
  await page.evaluate(() => {
    localStorage.setItem('access_token', 'expired_token');
  });

  await page.reload();

  // API呼び出しでトークンリフレッシュがトリガーされることを確認
  await page.waitForResponse('**/api/refresh');
  expect(refreshCount).toBe(1);
});
```

### セッションタイムアウトのテスト

```typescript
test('セッションタイムアウトでログアウト', async ({ page }) => {
  await page.goto('https://example.com/dashboard', {
    storageState: 'auth/user.json'
  });

  // セッションタイムアウトをシミュレート
  await page.evaluate(() => {
    const expiredDate = new Date(Date.now() - 1000).toISOString();
    localStorage.setItem('session_expires', expiredDate);
  });

  await page.reload();

  // ログインページへのリダイレクトを確認
  await expect(page).toHaveURL(/login/);
  await expect(page.getByText('Session expired')).toBeVisible();
});
```

### CSRFトークン検証のテスト

```typescript
test('CSRFトークンなしでPOSTリクエスト拒否', async ({ page, context }) => {
  await page.goto('https://example.com/dashboard', {
    storageState: 'auth/user.json'
  });

  // CSRFトークンを削除
  await page.evaluate(() => {
    document.querySelector('meta[name="csrf-token"]')?.remove();
  });

  const response = await page.request.post('https://example.com/api/update', {
    data: { key: 'value' }
  });

  expect(response.status()).toBe(403);
});
```

---

## チェックリスト: 認証とセキュリティテスト

- [ ] ログイン/ログアウトフローをカバー
- [ ] 無効な認証情報でエラーメッセージを検証
- [ ] セッション永続化（storageState）を活用してテスト高速化
- [ ] 複数ユーザーロールを個別にテスト
- [ ] OAuth/SAML等の複雑な認証フローをモック化
- [ ] MFA（多要素認証）コード入力をテスト
- [ ] トークンリフレッシュのロジックを検証
- [ ] セッションタイムアウトのハンドリングを確認
- [ ] CSRFトークン検証等のセキュリティ機構をテスト
- [ ] 認証情報を環境変数で管理（ハードコード禁止）
- [ ] パスワード等の機密情報をGit履歴に含めない

---

## ベストプラクティス

1. **認証セットアップの分離:** `auth.setup.ts` で全ロールの認証を一元管理
2. **storageState の再利用:** 全テストで毎回ログインせず、保存済みセッションを利用
3. **環境変数の活用:** テスト用のアカウント情報は `.env` で管理
4. **トークン管理の抽象化:** ヘルパー関数でトークン設定/クリアを簡潔に
5. **セキュリティテストの自動化:** CSRF、XSS、SQLインジェクション等の基本的な攻撃パターンを自動テスト
