# テスト信頼性とFlakiness対策

このドキュメントでは、Playwrightテストの信頼性を高め、Flaky（不安定）なテストを排除するための戦略と実践的な修正パターンを解説します。

---

## Auto-Waiting メカニズム

PlaywrightはアクションとAssertionの両方で自動待機を行います。これにより、明示的な `sleep()` や `waitFor()` が不要になります。

### アクション実行前の自動チェック

すべてのアクション（`click()`, `fill()`, `check()` など）は、以下の条件が満たされるまで自動的に待機します：

1. **Attached**: 要素がDOMに存在する
2. **Visible**: 要素が表示されている
3. **Stable**: 要素の位置が固定されている（アニメーション完了）
4. **Enabled**: 要素が無効化されていない
5. **Editable**: 入力要素の場合、編集可能である

```typescript
// 以下のコードは、ボタンがクリック可能になるまで自動的に待機
await page.getByRole('button', { name: 'Submit' }).click();
```

### actionTimeout 設定

```typescript
export default defineConfig({
  use: {
    actionTimeout: 10000, // アクション単位のタイムアウト（デフォルト: testTimeout）
  },
});
```

### force: true は避けるべき理由

```typescript
// ❌ 悪い例: 自動チェックをバイパス
await button.click({ force: true });

// ✅ 良い例: 自動チェックに任せる
await button.click();
```

`force: true` を使用すると：
- 要素が非表示でもクリック可能
- Disabled状態でもクリック可能
- **実際のユーザー操作と乖離**する

---

## Web-First Assertions（自動リトライ）

PlaywrightのAssertionは、条件が満たされるまで自動的にリトライします。

### Non-retrying Assertion（避けるべき）

```typescript
// ❌ 悪い例: 値を取得した瞬間の状態でしか判定しない
const text = await locator.textContent();
expect(text).toBe('Success');
```

### Auto-retrying Assertion（推奨）

```typescript
// ✅ 良い例: 'Success'が表示されるまで最大5秒間リトライ
await expect(locator).toHaveText('Success');
```

### Web-First Assertions 一覧

| Assertion | 説明 |
|-----------|------|
| `toBeAttached()` | DOM に存在する |
| `toBeChecked()` | チェックボックスがチェック済み |
| `toBeDisabled()` | 無効化されている |
| `toBeEditable()` | 編集可能 |
| `toBeEmpty()` | 空要素 |
| `toBeEnabled()` | 有効化されている |
| `toBeFocused()` | フォーカスされている |
| `toBeHidden()` | 非表示 |
| `toBeInViewport()` | ビューポート内に表示 |
| `toBeVisible()` | 表示されている |
| `toContainText()` | テキストを含む |
| `toHaveAccessibleDescription()` | アクセシブル説明を持つ |
| `toHaveAccessibleName()` | アクセシブル名を持つ |
| `toHaveAttribute()` | 属性を持つ |
| `toHaveClass()` | クラスを持つ |
| `toHaveCount()` | 要素数が一致 |
| `toHaveCSS()` | CSSプロパティを持つ |
| `toHaveId()` | IDを持つ |
| `toHaveJSProperty()` | JavaScriptプロパティを持つ |
| `toHaveRole()` | ARIAロールを持つ |
| `toHaveScreenshot()` | スクリーンショットが一致 |
| `toHaveText()` | テキストが一致 |
| `toHaveTitle()` | ページタイトルが一致 |
| `toHaveURL()` | URLが一致 |
| `toHaveValue()` | 入力値が一致 |
| `toHaveValues()` | 複数の値が一致 |

### 手動リトライ: expect.poll()

非Web要素（APIレスポンス等）に対して自動リトライを適用：

```typescript
// APIレスポンスが期待値になるまでリトライ
await expect.poll(async () => {
  const response = await page.request.get('/api/status');
  return (await response.json()).status;
}).toBe('ready');

// カスタムタイムアウトと間隔
await expect.poll(async () => {
  return await getCurrentTemperature();
}, {
  timeout: 60000,   // 最大60秒
  intervals: [1000, 2000, 5000], // 1秒、2秒、5秒間隔でリトライ
}).toBeGreaterThan(100);
```

---

## Timeout 設定体系

Playwrightは階層的なTimeout設定を持ちます。

### Timeout階層

| スコープ | 設定方法 | デフォルト | 説明 |
|---------|---------|-----------|------|
| **テスト全体** | `timeout` | 30秒 | 1テストの最大実行時間 |
| **スイート全体** | `globalTimeout` | 無制限 | すべてのテストの合計時間 |
| **アサーション** | `expect.timeout` | 5秒 | Web-First Assertionのリトライ時間 |
| **アクション** | `use.actionTimeout` | testTimeout | `click()`, `fill()` 等の最大待機時間 |
| **ナビゲーション** | `use.navigationTimeout` | testTimeout | `goto()`, `waitForURL()` の最大待機時間 |

### playwright.config.ts での設定

```typescript
export default defineConfig({
  timeout: 60000,            // テスト全体: 60秒
  globalTimeout: 3600000,    // 全体で1時間まで

  expect: {
    timeout: 10000,          // アサーション: 10秒
  },

  use: {
    actionTimeout: 15000,        // アクション: 15秒
    navigationTimeout: 20000,    // ナビゲーション: 20秒
  },
});
```

### 個別テストでのオーバーライド

```typescript
test('重い処理', async ({ page }) => {
  test.setTimeout(120000); // このテストのみ120秒

  await page.goto('/heavy-operation');
  await page.getByRole('button', { name: 'Process' }).click();

  // このアサーションのみ30秒待機
  await expect(page.getByText('Complete')).toBeVisible({ timeout: 30000 });
});
```

### test.slow() による倍率指定

```typescript
test('遅いテスト', async ({ page }) => {
  test.slow(); // タイムアウトを3倍に延長
  // timeout: 30秒 → 90秒
  await page.goto('/slow-page');
});

test.describe('遅いテスト群', () => {
  test.slow(); // このdescribe内すべてのテストが3倍

  test('テスト1', async ({ page }) => { /* ... */ });
  test('テスト2', async ({ page }) => { /* ... */ });
});
```

---

## 3段階リトライ戦略

Playwrightは、エラーハンドリングのために3つのリトライレベルを提供します。

### Level 1: アサーション内部リトライ

最も細かいレベル。Web-First Assertionが自動的に行います。

```typescript
// 'Success'が表示されるまで最大5秒間リトライ
await expect(page.getByText('Success')).toBeVisible();
```

- **タイムアウト**: `expect.timeout`（デフォルト5秒）
- **用途**: ほとんどの待機処理
- **設定**: `expect: { timeout: 10000 }`

### Level 2: toPass() によるリトライブロック

複数のアサーションをまとめてリトライします。

```typescript
// このブロック全体が成功するまで最大30秒間リトライ
await expect(async () => {
  const response = await page.request.get('/api/status');
  expect(response.status()).toBe(200);
  const data = await response.json();
  expect(data.status).toBe('ready');
  expect(data.users).toBeGreaterThan(0);
}).toPass({
  timeout: 30000,
  intervals: [1000, 2000, 5000],
});
```

- **用途**: APIレスポンスの複合チェック、複雑な状態遷移
- **利点**: 途中でエラーが起きても全体をリトライ

### Level 3: テストリトライ（retries 設定）

テスト全体を再実行します。

```typescript
export default defineConfig({
  retries: process.env.CI ? 2 : 0, // CI環境でのみ最大3回実行
});
```

個別テストでのオーバーライド：

```typescript
test('不安定なテスト', async ({ page }) => {
  test.describe.configure({ retries: 3 });
  // このテストは最大4回実行（初回 + 3回リトライ）
});
```

- **用途**: Flaky テストの緩和（最終手段）
- **注意**: 根本原因を修正することが優先

---

## Flakiness 検出・予防

Flakyテストを早期発見するための戦略。

### 1. テストBurn-In（繰り返し実行）

```bash
# 同じテストを100回実行
npx playwright test --repeat-each=100

# 特定のテストのみ
npx playwright test auth.spec.ts --repeat-each=100
```

**目的**: 低頻度で発生する不具合を検出

### 2. カオスエンジニアリング（負荷テスト）

```typescript
export default defineConfig({
  use: {
    launchOptions: {
      // CPU を50%に制限
      args: ['--disable-gpu', '--disable-dev-shm-usage'],
    },
    // ネットワーク遅延をシミュレート
    offline: false,
    // 3G 回線をエミュレート
    // slow3G: true, // カスタム設定が必要
  },
});
```

```typescript
test('遅い環境でも動作する', async ({ page, context }) => {
  // ネットワーク遅延を注入
  await context.route('**/*', async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 500));
    await route.continue();
  });

  await page.goto('/');
  await expect(page.getByRole('button', { name: 'Load' })).toBeVisible();
});
```

### 3. 高並列ストレステスト

```bash
# 通常の3倍のworkerで実行（リソース競合を誘発）
npx playwright test --workers=150%
```

**目的**: 並列実行時のレースコンディションを検出

---

## ESLint ルール（信頼性強化）

### playwright ESLint plugin

```bash
npm install -D eslint-plugin-playwright
```

```javascript
// .eslintrc.js
module.exports = {
  extends: ['plugin:playwright/recommended'],
  rules: {
    'playwright/missing-playwright-await': 'error',
    'playwright/prefer-web-first-assertions': 'error',
    'playwright/no-useless-await': 'warn',
    'playwright/no-wait-for-timeout': 'error',
  },
};
```

### 推奨ルール

| ルール | 説明 |
|--------|------|
| `missing-playwright-await` | `await` 忘れを検出 |
| `prefer-web-first-assertions` | `toBeVisible()` 等の使用を推奨 |
| `no-wait-for-timeout` | `page.waitForTimeout()` を禁止 |
| `no-useless-await` | 不要な `await` を警告 |

### TypeScript 推奨設定

```json
{
  "compilerOptions": {
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  }
}
```

---

## Flakyテストの隔離＆修正

### @flaky タグによる隔離

```typescript
test('@flaky ログインが時々失敗する', async ({ page }) => {
  test.fixme(true, 'Issue #123: ハイドレーション問題');
  // テストコード
});
```

CI での実行時に除外：

```bash
npx playwright test --grep-invert @flaky
```

### annotationでissueリンク

```typescript
test('不安定なテスト', async ({ page }) => {
  test.info().annotations.push({
    type: 'issue',
    description: 'https://github.com/org/repo/issues/123',
  });
});
```

---

## Flaky テスト修正パターン

### パターン1: レースコンディション

**症状**: ボタンをクリックしてもバックエンドが準備できていない

```typescript
// ❌ 悪い例: レースコンディションが発生
await page.getByRole('button', { name: 'Load Data' }).click();
await expect(page.getByText('Data loaded')).toBeVisible();
```

**修正**: APIレスポンスを明示的に待機

```typescript
// ✅ 良い例: APIレスポンスとクリックを同期
await Promise.all([
  page.waitForResponse((response) => response.url().includes('/api/data')),
  page.getByRole('button', { name: 'Load Data' }).click(),
]);

await expect(page.getByText('Data loaded')).toBeVisible();
```

### パターン2: ハイドレーション問題

**症状**: React/Vue等のSPAで、UI描画済みだがJSイベントハンドラ未バインド

```typescript
// ❌ 悪い例: ハイドレーション中にクリック
await page.goto('/');
await page.getByRole('button', { name: 'Submit' }).click(); // 反応しない
```

**修正1**: Disabled状態を利用

```typescript
// ✅ 良い例: ハイドレーション完了まで待機
await page.goto('/');
await expect(page.getByRole('button', { name: 'Submit' })).toBeEnabled();
await page.getByRole('button', { name: 'Submit' }).click();
```

**修正2**: `toPass()` でリトライ

```typescript
await page.goto('/');
await expect(async () => {
  await page.getByRole('button', { name: 'Submit' }).click();
  await expect(page.getByText('Form submitted')).toBeVisible();
}).toPass();
```

### パターン3: 並列テスト衝突

**症状**: 共有データベースや共有状態で衝突

```typescript
// ❌ 悪い例: 固定ユーザー名で衝突
test('ユーザー作成', async ({ page }) => {
  await page.goto('/signup');
  await page.fill('[name="username"]', 'testuser'); // 他のテストと衝突
  await page.fill('[name="password"]', 'password');
  await page.click('button[type="submit"]');
});
```

**修正**: スコープドデータを使用

```typescript
// ✅ 良い例: ユニークなユーザー名
import { test } from '@playwright/test';

test('ユーザー作成', async ({ page }) => {
  const uniqueUsername = `testuser-${Date.now()}-${Math.random()}`;

  await page.goto('/signup');
  await page.fill('[name="username"]', uniqueUsername);
  await page.fill('[name="password"]', 'password');
  await page.click('button[type="submit"]');

  // テスト後にクリーンアップ
  await page.request.delete(`/api/users/${uniqueUsername}`);
});
```

### パターン4: ネットワークタイムアウト

**症状**: CI環境でのみタイムアウト

```typescript
// ❌ 悪い例: CI環境の遅延を考慮していない
test('データロード', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page.getByText('Data loaded')).toBeVisible();
});
```

**修正**: タイムアウトを延長

```typescript
// ✅ 良い例: CI環境に配慮
test('データロード', async ({ page }) => {
  test.slow(); // タイムアウトを3倍に

  await page.goto('/dashboard', { timeout: 60000 });
  await expect(page.getByText('Data loaded')).toBeVisible({ timeout: 30000 });
});
```

### パターン5: 不安定なロケーター

**症状**: 動的に生成される要素で失敗

```typescript
// ❌ 悪い例: 動的classに依存
await page.locator('.MuiButton-root-123').click();
```

**修正**: 安定したセレクターを使用

```typescript
// ✅ 良い例: Role-based locator
await page.getByRole('button', { name: 'Submit' }).click();

// ✅ 良い例: test-id
await page.getByTestId('submit-button').click();
```

### パターン6: アニメーション干渉

**症状**: アニメーション中にクリックして失敗

```typescript
// ❌ 悪い例: アニメーション中にクリック
await page.getByRole('button', { name: 'Open Menu' }).click();
await page.getByRole('menuitem', { name: 'Settings' }).click(); // アニメーション中で失敗
```

**修正**: Stable状態を待つ（自動）+ アニメーション無効化

```typescript
// ✅ 良い例: Playwrightが自動的にStable状態を待つ
await page.getByRole('button', { name: 'Open Menu' }).click();
await page.getByRole('menuitem', { name: 'Settings' }).click();

// または、アニメーションを完全無効化
export default defineConfig({
  use: {
    // すべてのアニメーションを無効化
    page: {
      reducedMotion: 'reduce',
    },
  },
});
```

---

## 修正パターン一覧表

| パターン | 原因 | 症状 | 修正方法 |
|---------|------|------|---------|
| **レースコンディション** | バックエンド未準備 | クリック後に何も起きない | `waitForResponse()` + `Promise.all()` |
| **ハイドレーション問題** | JSイベント未バインド | クリックしても反応なし | `toBeEnabled()` 待機 or `toPass()` |
| **並列テスト衝突** | 共有DB/状態 | ランダムに失敗 | ユニークデータ生成 + クリーンアップ |
| **ネットワークタイムアウト** | CI環境遅延 | CI でのみ失敗 | `test.slow()` + timeout延長 |
| **不安定ロケーター** | 動的class/ID | 要素が見つからない | Role-based locator or test-id |
| **アニメーション干渉** | 要素移動中 | クリック失敗 | 自動待機 or `reducedMotion: 'reduce'` |
| **ポップアップ干渉** | モーダル重なり | 要素がクリック不可 | ポップアップを明示的に閉じる |
| **非同期状態更新** | React setState遅延 | 古い状態でアサート | `toPass()` or `expect.poll()` |

---

## 最終手段: 削除＆書き直し

### いつ書き直すべきか

以下の条件が揃った場合、修正より書き直しが効率的です：

- ✅ テストが複雑すぎて理解困難
- ✅ 複数の修正パターンを試しても安定しない
- ✅ テストの目的が不明瞭
- ✅ 書き直しに30分以下で完了できる

### 書き直しのステップ

1. **テストの目的を明確化**: 何をテストしたいのか？
2. **最小限のステップで再実装**: 不要な操作を削除
3. **Web-First Assertionを使用**: 自動リトライに任せる
4. **Burn-In テスト**: `--repeat-each=100` で安定性確認

---

## まとめ

### 信頼性の高いテストを書くための原則

1. **Auto-Waitingに任せる**: 明示的な `sleep()` は禁止
2. **Web-First Assertions を使う**: `toBeVisible()`, `toHaveText()` 等
3. **適切なTimeout設定**: テストの性質に応じて調整
4. **3段階リトライを理解**: Assertion → toPass() → テストリトライ
5. **Flakyテストは隔離 → 修正 → 削除**: 放置しない

### Flakiness検出・予防のチェックリスト

- [ ] `--repeat-each=100` で繰り返しテスト
- [ ] `--workers=150%` で高並列テスト
- [ ] ESLint ルール適用（`missing-playwright-await` 等）
- [ ] CI環境でのタイムアウト調整
- [ ] ユニークなテストデータを使用

### 修正パターンの適用順序

1. **ロケーター改善**: Role-based or test-id
2. **明示的待機追加**: `waitForResponse()`, `toBeEnabled()`
3. **toPass() でリトライブロック**: 複合条件
4. **タイムアウト延長**: CI環境対応
5. **最終手段**: 書き直し

適切な戦略により、Flakyテストを95%以上削減可能です。
