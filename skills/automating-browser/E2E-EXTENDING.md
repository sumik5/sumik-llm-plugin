# Playwright Testの拡張

Playwright Testは、カスタムアサーション、レポーター、Attachment等の拡張機能を提供します。

---

## カスタムAssertion（Matcher）

### jest-extendedとの統合

```typescript
import { expect as baseExpect } from '@playwright/test';
import { toBeFinite, toBeValidDate } from 'jest-extended';

export const expect = baseExpect.extend({
  toBeFinite,
  toBeValidDate,
});
```

### 独自Matcher作成

```typescript
import { expect as baseExpect, type Locator } from '@playwright/test';

interface MatcherReturnType {
  pass: boolean;
  message: () => string;
}

export const expect = baseExpect.extend({
  async toBeRightOf(
    locator: Locator,
    reference: Locator,
  ): Promise<MatcherReturnType> {
    const candidateBox = await locator.boundingBox();
    const refBox = await reference.boundingBox();

    if (!candidateBox || !refBox) {
      return {
        pass: false,
        message: () => 'Element not found',
      };
    }

    const pass = candidateBox.x >= refBox.x + refBox.width;

    return {
      pass,
      message: () =>
        pass
          ? 'Element is to the right'
          : `Element (x=${candidateBox.x}) is not to the right of reference (x=${refBox.x + refBox.width})`,
    };
  },
});
```

### this.isNotの対応

`.not`修飾子に対応するには`this.isNot`を確認します。

```typescript
export const expect = baseExpect.extend({
  async toBeAbove(
    locator: Locator,
    reference: Locator,
  ): Promise<MatcherReturnType> {
    const candidateBox = await locator.boundingBox();
    const refBox = await reference.boundingBox();

    if (!candidateBox || !refBox) {
      return { pass: false, message: () => 'Element not found' };
    }

    const pass = candidateBox.y + candidateBox.height <= refBox.y;

    return {
      pass,
      message: () => {
        // this.isNot === true の場合は .not.toBeAbove()
        const verb = this.isNot ? 'not be' : 'be';
        return `Expected element to ${verb} above reference`;
      },
    };
  },
});
```

### Matcher Collectionの合成

複数のプロジェクトでMatcherを共有する場合は、Collectionとして管理します。

```typescript
// matchers/layout.ts
export const layoutMatchers = {
  async toBeRightOf(locator: Locator, reference: Locator) { /* ... */ },
  async toBeAbove(locator: Locator, reference: Locator) { /* ... */ },
};

// matchers/data.ts
export const dataMatchers = {
  async toMatchSchema(data: unknown, schema: object) { /* ... */ },
};

// tests/fixtures.ts
import { layoutMatchers } from './matchers/layout';
import { dataMatchers } from './matchers/data';

export const expect = baseExpect.extend({
  ...layoutMatchers,
  ...dataMatchers,
});
```

---

## カスタムexpectメッセージ

アサーションの第2引数にカスタムエラーメッセージを指定できます。

```typescript
test('カスタムメッセージ', async ({ page }) => {
  await page.goto('/login');

  await expect(
    page.locator('#username'),
    'ユーザー名入力欄が表示されていません',
  ).toBeVisible();

  await expect(
    page.locator('#password'),
    'パスワード入力欄が表示されていません',
  ).toBeVisible();
});
```

テスト失敗時には指定したメッセージが表示されます。

---

## レポーター

### 組み込みレポーター

```typescript
// playwright.config.ts
export default defineConfig({
  reporter: [
    ['html'],                          // HTMLレポート（デフォルト）
    ['github'],                        // GitHub Actions用
    ['json', { outputFile: 'results.json' }],
    ['junit', { outputFile: 'results.xml' }],
    ['list'],                          // コンソール出力
    ['dot'],                           // 進捗ドット表示
    ['line'],                          // 1行表示
  ],
});
```

### サードパーティレポーター

| レポーター | 用途 |
|-----------|------|
| **Allure** | 詳細なテストレポート |
| **Slack** | Slack通知 |
| **Monocart** | カバレッジレポート |
| **ReportPortal** | テスト管理プラットフォーム連携 |

```bash
npm install -D allure-playwright
```

```typescript
export default defineConfig({
  reporter: [['allure-playwright']],
});
```

### カスタムReporter実装

```typescript
import type {
  Reporter,
  FullConfig,
  Suite,
  TestCase,
  TestResult,
  FullResult,
} from '@playwright/test/reporter';

class MyReporter implements Reporter {
  onBegin(config: FullConfig, suite: Suite) {
    console.log(`テスト開始: ${suite.allTests().length}件のテスト`);
  }

  onTestEnd(test: TestCase, result: TestResult) {
    const status = result.status === 'passed' ? '✅' : '❌';
    console.log(`${status} ${test.title} (${result.duration}ms)`);
  }

  onEnd(result: FullResult) {
    console.log(`テスト完了: ${result.status}`);
  }
}

export default MyReporter;
```

```typescript
// playwright.config.ts
export default defineConfig({
  reporter: [['./my-reporter.ts']],
});
```

### HTMLレポーターのカスタマイズ

```typescript
export default defineConfig({
  reporter: [
    [
      'html',
      {
        open: 'never',                 // 自動オープンしない
        outputFolder: 'test-results',  // 出力先
        attachmentsBaseURL: 'https://cdn.example.com/', // Attachment URL
      },
    ],
  ],
});
```

---

## テストAttachment（エビデンス収集）

### Attachmentの追加

```typescript
test('アクセシビリティスキャン', async ({ page }, testInfo) => {
  await page.goto('/home');

  const results = await scanAccessibility(page);

  // JSON形式でAttachment追加
  await testInfo.attach('accessibility-scan', {
    body: JSON.stringify(results, null, 2),
    contentType: 'application/json',
  });

  expect(results.violations).toHaveLength(0);
});
```

### スクリーンショットのAttachment

```typescript
test('エラー画面キャプチャ', async ({ page }, testInfo) => {
  await page.goto('/error');

  const screenshot = await page.screenshot();

  await testInfo.attach('error-screenshot', {
    body: screenshot,
    contentType: 'image/png',
  });
});
```

### ファイルからのAttachment

```typescript
test('ログファイル保存', async ({ page }, testInfo) => {
  await page.goto('/logs');

  const logContent = await page.locator('#log-output').textContent();

  await testInfo.attach('app-logs', {
    path: './logs/test.log',
  });
});
```

### Annotation（メタデータ付与）

```typescript
test('重要なテスト', async ({ page }, testInfo) => {
  testInfo.annotations.push({
    type: 'priority',
    description: 'high',
  });

  testInfo.annotations.push({
    type: 'issue',
    description: 'https://github.com/org/repo/issues/123',
  });

  // テスト処理
});
```

---

## テストデータ管理

### Fakerによるランダムデータ生成

```typescript
import { faker } from '@faker-js/faker';

test('ユーザー登録', async ({ page }) => {
  const email = faker.internet.email();
  const password = faker.internet.password();
  const firstName = faker.person.firstName();
  const lastName = faker.person.lastName();

  await page.goto('/signup');
  await page.fill('#email', email);
  await page.fill('#password', password);
  await page.fill('#first-name', firstName);
  await page.fill('#last-name', lastName);
  await page.click('button[type="submit"]');

  await expect(page).toHaveURL('/dashboard');
});
```

### 再現性のあるランダムデータ

```typescript
test('シード固定でデータ生成', async ({ page }) => {
  // シード固定で同じデータを生成
  faker.seed(123);

  const email = faker.internet.email(); // 常に同じメールアドレス

  await page.goto('/signup');
  await page.fill('#email', email);
  // ...
});
```

### JSON/CSVからのデータインポート

```typescript
import userData from './fixtures/users.json';

for (const user of userData) {
  test(`ユーザーログイン: ${user.name}`, async ({ page }) => {
    await page.goto('/login');
    await page.fill('#username', user.username);
    await page.fill('#password', user.password);
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL('/dashboard');
  });
}
```

### テストのパラメタライズ

```typescript
const browsers = ['chromium', 'firefox', 'webkit'];
const viewports = [
  { width: 1920, height: 1080 },
  { width: 1366, height: 768 },
  { width: 375, height: 667 },
];

for (const browser of browsers) {
  for (const viewport of viewports) {
    test(`レスポンシブデザイン: ${browser} ${viewport.width}x${viewport.height}`, async ({
      page,
    }) => {
      await page.setViewportSize(viewport);
      await page.goto('/responsive');
      await expect(page.locator('.header')).toBeVisible();
    });
  }
}
```

### Projects Test Optionsによるパラメタライズ

```typescript
// playwright.config.ts
export default defineConfig({
  projects: [
    {
      name: 'staging',
      use: { baseURL: 'https://staging.example.com' },
    },
    {
      name: 'production',
      use: { baseURL: 'https://example.com' },
    },
  ],
});
```

```bash
# 環境別実行
npx playwright test --project=staging
npx playwright test --project=production
```

---

## ベストプラクティス

### カスタムMatcherの命名

- `toBe*`形式で統一（例: `toBeRightOf`, `toBeValidEmail`）
- 肯定形で命名（`.not`修飾子で否定形に対応）

### Reporterの選定

- **開発時**: `list`または`line`（高速フィードバック）
- **CI**: `github` + `html`（詳細レポート + GitHub統合）
- **本番監視**: カスタムReporter（Slack通知等）

### Attachmentの使い分け

- **スクリーンショット**: 視覚的な検証
- **JSON**: API応答、アクセシビリティスキャン結果
- **ログ**: デバッグ情報、ネットワークログ

### テストデータの管理方針

- **小規模**: Faker + シード固定
- **中規模**: JSON/CSVファイル
- **大規模**: データベースFixture、API連携
