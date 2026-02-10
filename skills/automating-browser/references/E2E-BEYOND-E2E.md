# E2Eを超えたPlaywright活用

Playwrightは、E2Eテスト以外にも、APIテスト、コンポーネントテスト、BDD、Webスクレイピング等の幅広いユースケースに対応します。

---

## REST APIテスト

### CRUD操作マッピング

| CRUD | HTTPメソッド | Playwright |
|------|-------------|-----------|
| Create | POST, PUT | `request.post()`, `request.put()` |
| Read | GET | `request.get()` |
| Update | PATCH, PUT | `request.patch()`, `request.put()` |
| Delete | DELETE | `request.delete()` |

### 基本的なAPIテスト

```typescript
import { test, expect } from '@playwright/test';

test('GET /quotes/1', async ({ request }) => {
  const response = await request.get('https://api.example.com/quotes/1');

  expect(response.status()).toBe(200);

  const data = await response.json();
  expect(data).toMatchObject({
    id: expect.any(Number),
    quote: expect.any(String),
    author: expect.any(String),
  });
});

test('POST /quotes', async ({ request }) => {
  const response = await request.post('https://api.example.com/quotes', {
    data: {
      quote: 'To be or not to be',
      author: 'Shakespeare',
    },
  });

  expect(response.status()).toBe(201);

  const created = await response.json();
  expect(created.id).toBeDefined();
  expect(created.quote).toBe('To be or not to be');
});

test('DELETE /quotes/42', async ({ request }) => {
  const response = await request.delete('https://api.example.com/quotes/42');
  expect(response.status()).toBe(204);
});
```

### 認証ヘッダー付きリクエスト

```typescript
test('認証APIテスト', async ({ request }) => {
  const response = await request.get('https://api.example.com/profile', {
    headers: {
      'Authorization': 'Bearer token_here',
    },
  });

  expect(response.status()).toBe(200);
});
```

### API + UI統合テスト

`page.request`を使うことで、ブラウザのCookieやセッションを共有できます。

```typescript
test('ログイン後のAPIアクセス', async ({ page }) => {
  // UIからログイン
  await page.goto('/login');
  await page.fill('#username', 'user@example.com');
  await page.fill('#password', 'password');
  await page.click('button[type="submit"]');

  // ログイン後のCookieを使ってAPI呼び出し
  const response = await page.request.get('https://api.example.com/profile');

  expect(response.status()).toBe(200);
  const profile = await response.json();
  expect(profile.email).toBe('user@example.com');
});
```

---

## コンポーネントテスト

### Playwright Component Testing

Playwrightはコンポーネント単体のテストもサポートします。

```bash
npm init playwright@latest -- --ct
```

### Reactコンポーネントのテスト

```typescript
import { test, expect } from '@playwright/experimental-ct-react';
import GreetingComponent from './greeting';

test('ロード時に挨拶を表示', async ({ mount }) => {
  const component = await mount(<GreetingComponent url="/greeting" />);

  await expect(component.getByRole('heading')).toHaveText('Loading...');

  await component.getByRole('button').click();

  await expect(component.getByRole('heading')).toHaveText('hello');
});
```

### Propsのテスト

```typescript
test('Propsによる表示切り替え', async ({ mount }) => {
  const component = await mount(
    <UserCard name="Alice" role="Admin" />
  );

  await expect(component.getByText('Alice')).toBeVisible();
  await expect(component.getByText('Admin')).toBeVisible();
});
```

### イベントハンドラのテスト

```typescript
test('クリックイベント', async ({ mount }) => {
  let clicked = false;

  const component = await mount(
    <Button onClick={() => { clicked = true; }}>
      Click me
    </Button>
  );

  await component.click();

  expect(clicked).toBe(true);
});
```

### Storybook連携パターン

```typescript
import { test, expect } from '@playwright/experimental-ct-react';
import * as stories from './Button.stories';

test('Primary Buttonストーリー', async ({ mount }) => {
  const component = await mount(<stories.Primary />);
  await expect(component).toHaveText('Primary Button');
});
```

---

## BDD (Behavior-Driven Development)

### playwright-bdd

Gherkin記法でシナリオを記述し、Playwright Testで実行できます。

```bash
npm install -D playwright-bdd
```

### Feature file

```gherkin
# features/login.feature
Feature: ユーザーログイン

  Scenario: 正常なログイン
    Given ユーザーが "/login" にアクセスする
    When ユーザー名 "alice@example.com" を入力する
    And パスワード "password123" を入力する
    And ログインボタンをクリックする
    Then ダッシュボードページに遷移する
```

### Step definitions

```typescript
// steps/login.steps.ts
import { createBdd } from 'playwright-bdd';
import { expect } from '@playwright/test';

const { Given, When, Then } = createBdd();

Given('ユーザーが {string} にアクセスする', async ({ page }, url: string) => {
  await page.goto(url);
});

When('ユーザー名 {string} を入力する', async ({ page }, username: string) => {
  await page.fill('#username', username);
});

When('パスワード {string} を入力する', async ({ page }, password: string) => {
  await page.fill('#password', password);
});

When('ログインボタンをクリックする', async ({ page }) => {
  await page.click('button[type="submit"]');
});

Then('ダッシュボードページに遷移する', async ({ page }) => {
  await expect(page).toHaveURL('/dashboard');
});
```

### 実行

```bash
npx bddgen && npx playwright test
```

---

## 自動化ユースケース（テスト以外）

### Playwright Library（テストランナーなし）

```typescript
import { chromium } from 'playwright';

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('https://example.com');

  const title = await page.title();
  console.log(`Page title: ${title}`);

  await browser.close();
})();
```

### Webスクレイピング

```typescript
import { chromium } from 'playwright';

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  await page.goto('https://news.example.com');

  // 記事タイトルをすべて取得
  const titles = await page.locator('.article-title').allInnerTexts();
  console.log(titles);

  // 特定要素のテキストを取得
  const headline = await page.locator('h1').textContent();
  console.log(headline);

  await browser.close();
})();
```

### スクリーンショット生成

```typescript
import { chromium } from 'playwright';

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('https://example.com');

  // ページ全体のスクリーンショット
  await page.screenshot({ path: 'screenshot.png', fullPage: true });

  // 特定要素のスクリーンショット
  await page.locator('.hero-section').screenshot({ path: 'hero.png' });

  await browser.close();
})();
```

### 動画録画

```typescript
import { chromium } from 'playwright';

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({
    recordVideo: {
      dir: 'videos/',
      size: { width: 1280, height: 720 },
    },
  });

  const page = await context.newPage();
  await page.goto('https://example.com');
  await page.click('button.start-demo');

  await context.close();
  await browser.close();
})();
```

### PDF生成

```typescript
import { chromium } from 'playwright';

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('https://example.com/report');

  await page.pdf({
    path: 'report.pdf',
    format: 'A4',
    printBackground: true,
  });

  await browser.close();
})();
```

### Checklyによるプロダクション監視

[Checkly](https://www.checklyhq.com/)は、Playwrightスクリプトを本番環境で定期実行するサービスです。

```typescript
// checkly.config.ts
import { defineConfig } from '@checkly/cli';

export default defineConfig({
  checks: {
    frequency: 5, // 5分ごと
    locations: ['us-east-1', 'eu-west-1'],
    checkMatch: '**/__checks__/*.check.ts',
  },
});
```

```typescript
// __checks__/homepage.check.ts
import { test } from '@playwright/test';

test('ホームページが正常に表示される', async ({ page }) => {
  await page.goto('https://example.com');
  await page.waitForSelector('.hero-section');
});
```

```bash
# デプロイ
npx checkly deploy
```

---

## テストフレームワーク選定ガイド

### 推奨テストスタック

| レイヤー | ツール | アサーション |
|---------|--------|-------------|
| **Static** | Prettier, ESLint, TypeScript | N/A |
| **Unit** | Vitest | Jest expect |
| **Integration** | Vitest + Testing Library | Jest expect + DOM |
| **E2E** | Playwright Test | Jest expect + Playwright |

### 共通点

- **アサーション**: すべてJest `expect()`互換
- **Fixture**: Vitest & Playwright Test両方がサポート
- **セレクター**: Testing Library & Playwrightで`getByRole()`, `getByLabel()`が共通
- **CLI**: 同一パターン（`npx vitest`, `npx playwright test`）

### フレームワーク移行の容易性

```typescript
// Vitestでのテスト
import { test, expect } from 'vitest';

test('足し算', () => {
  expect(1 + 1).toBe(2);
});

// Playwright Testでのテスト（アサーション構文が同じ）
import { test, expect } from '@playwright/test';

test('足し算', () => {
  expect(1 + 1).toBe(2);
});
```

---

## Playwright Testの制約

### 非対応ブラウザ

- Internet Explorer
- Safari（iOS実機）
- 古いバージョンのブラウザ

### 非対応フレームワーク

- Angular Component Testing（現在未サポート）

### Selenium WebDriverが適する場面

- レガシーブラウザサポートが必須
- 既存のSelenium Gridインフラを利用
- Seleniumエコシステムへの依存が大きい

---

## ベストプラクティス

### テスト戦略

- **Unit**: ビジネスロジック、ユーティリティ関数
- **Integration**: コンポーネント連携、API呼び出し
- **E2E**: ユーザーフロー、クリティカルパス

### APIテストの活用

- E2Eテストの前提条件設定（データ準備）
- CI/CDパイプラインでの迅速なフィードバック
- UI + API統合でリアルな状態を再現

### コンポーネントテストの活用

- デザインシステムの検証
- Storybookとの統合
- 視覚的リグレッションテスト

### BDDの活用

- ビジネスサイドとの共通言語
- ドキュメントとしてのテスト
- 受け入れテストの自動化

### 自動化の適用範囲

- 定期的なスクリーンショット生成（デザインレビュー）
- 定期的なWebスクレイピング（競合調査）
- 本番環境の継続的監視（Checkly）
