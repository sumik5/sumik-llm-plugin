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

---

## Playwright Inspector の使用法

Playwright Inspectorは、テストをステップ実行しながらリアルタイムで要素を検査できるビジュアルデバッガです。ロケーター検証、ステップ実行、アクションログ分析に最適です。

### Inspector の起動方法

**方法1: --debug フラグ（最も一般的）**

```bash
# すべてのテストをデバッグ
npx playwright test --debug

# 特定ファイルをデバッグ
npx playwright test example.spec.ts --debug

# 特定行のテストをデバッグ
npx playwright test example.spec.ts:10 --debug
```

**方法2: PWDEBUG環境変数**

```bash
# Bash/Zsh (Linux/macOS)
PWDEBUG=1 npx playwright test

# PowerShell (Windows)
$env:PWDEBUG=1; npx playwright test

# Batch (Windows)
set PWDEBUG=1 && npx playwright test
```

`PWDEBUG=1` を設定すると:
- ブラウザが自動的にheadedモードで起動
- タイムアウトが無制限（`timeout: 0`）に設定
- Inspector が自動起動

**方法3: コード内でpage.pause()を使用**

```typescript
test('デバッグテスト', async ({ page }) => {
  await page.goto('/login')

  await page.pause()  // ここでInspectorが開く

  await page.fill('[name="email"]', 'user@example.com')
  await page.fill('[name="password"]', 'password')
  await page.click('button[type="submit"]')
})
```

`page.pause()` は `PWDEBUG` の有無に関わらず Inspector を起動します。デバッグ完了後は `page.pause()` を削除してテストを通常実行に戻します。

### Inspector の主要機能

| 機能 | 説明 | ショートカット |
|-----|------|--------------|
| **Play/Resume** | 次の `page.pause()` または終了まで実行 | F8 |
| **Step Over** | 次のPlaywrightアクションを実行して停止 | F10 |
| **Pick Locator** | 要素をクリックしてロケーターを取得 | - |
| **Actionability Logs** | 要素がインタラクト不可の理由を表示 | - |
| **Locator Tab** | ロケーターをライブ編集・検証 | - |
| **Source** | テストコードを表示 | - |

### ロケーターのテスト・検証

```typescript
// 1. Inspector の「Pick Locator」ボタンをクリック
// 2. ブラウザでターゲット要素をホバー → Playwrightが推奨ロケーターを提示
// 3. 要素をクリック → ロケーターが「Locator」タブに表示
// 4. ライブ編集: タイプすると該当要素がブラウザでハイライト
// 5. コピーボタンでテストコードにペースト
```

**実践例: 失敗するログインテストの修正**

```typescript
// ❌ 間違ったロケーター
await page.fill('#username-input', 'standard_user')  // 要素が見つからない

// 1. `npx playwright test login.spec.ts --debug` で起動
// 2. Pick Locator で username フィールドをクリック
// 3. Inspector が `locator('[data-test="username"]')` を提示
// 4. Copy してコードに反映

// ✅ 修正後
await page.locator('[data-test="username"]').fill('standard_user')
```

### 部分実行デバッグ

```typescript
test('ログインフロー', async ({ page }) => {
  await page.goto('/login')
  await page.fill('[name="email"]', 'user@example.com')

  await page.pause()  // ここまでの動作を確認

  await page.fill('[name="password"]', 'password')
  await page.click('button[type="submit"]')
})
```

---

## UI Mode でのデバッグ

UI Modeは、テストスイート全体を対話的に実行・デバッグできるGUIツールです。Playwright Inspector との最大の違いは**タイムトラベルデバッグ**と**Watch Mode**による高速イテレーションです。

### UI Mode の起動

```bash
# UI Modeでテストスイート実行
npx playwright test --ui

# 特定のテストのみ実行
npx playwright test --ui --grep "login"

# 失敗したテストのみ
npx playwright test --ui --last-failed
```

### UI Mode の特徴

| 機能 | 説明 |
|-----|------|
| **テスト一覧** | すべてのテストをツリー表示、個別・グループ実行可能 |
| **Watch Mode** | ファイル変更を検知して自動再実行（手動再実行不要） |
| **タイムトラベルデバッグ** | 各ステップの時点でのDOMスナップショット、過去の状態を遡って確認 |
| **タイムライン** | 各ステップの実行時間を可視化、ボトルネック特定 |
| **スクリーンショット** | 各ステップのスナップショット自動保存 |
| **ネットワークログ** | リクエスト/レスポンスを確認、APIエラー診断 |
| **コンソールログ** | ブラウザコンソール出力を表示 |
| **DOM Explorer** | 各ステップのDOM状態を検査 |
| **統合情報パネル** | DOM、コンソール、ネットワーク、エラー、ソースコードを一箇所で確認 |

### タイムトラベルデバッグ（Inspectorとの差別化ポイント）

UI Modeの最大の強みは、テスト実行後に**過去の任意の時点に戻って状態を確認できる**ことです。

**手順**:
1. テストを実行（成功・失敗問わず）
2. タイムラインで任意のステップをクリック
3. **その時点のページ状態がスナップショットから復元される**
4. DOM Explorer でセレクタを検証
5. ネットワークタブで該当ステップのAPIコールを確認
6. コンソールタブでJavaScriptエラーを診断

**具体例: Flakyテストの調査**

```typescript
test('ときどき失敗するテスト', async ({ page }) => {
  await page.goto('/checkout')
  await page.click('[data-test="submit-order"]')
  await expect(page.locator('.success-message')).toBeVisible()  // ここで失敗
})
```

UI Modeで実行:
1. 失敗したステップ（`toBeVisible()` アサーション）をクリック
2. その時点のDOMを確認 → `.success-message` は存在するがCSSで `display: none`
3. ネットワークタブを確認 → `/api/submit` リクエストが `pending` 状態
4. **原因判明**: APIレスポンス待機せずにアサーション実行

### Watch Mode による高速イテレーション

```bash
npx playwright test --ui  # Watch Modeは自動有効
```

コードを編集して保存すると:
- **自動的に該当テストを再実行**
- 手動で `npx playwright test` を叩く必要なし
- 結果を即座に UI Mode で確認

**開発ワークフロー**:
1. UI Mode 起動
2. コードを修正
3. ファイル保存 → 自動実行
4. 結果確認・タイムライン分析
5. さらに修正 → 自動実行（繰り返し）

### 依存関係エラーの可視化

ライブラリ更新時に動作が変わった場合:
- **ビジュアルタイムライン**: エラー発生箇所がハイライト
- **コンソールログ**: ライブラリの警告・エラーメッセージ
- **ネットワークトレース**: API仕様変更の影響を特定

**例**: React 19 へのアップグレード後、`useEffect` の挙動変更で特定コンポーネントがレンダリングされない問題を UI Mode で即座に発見・診断可能。

---

## 失敗テストのスクリーンショット自動キャプチャ

スクリーンショットは、スタックトレースだけでは分からない**視覚的証拠**を提供します。「なぜ失敗したのか」を一目で理解可能にします。

### グローバル設定（playwright.config.ts）

```typescript
export default defineConfig({
  use: {
    screenshot: 'only-on-failure',  // 失敗時のみ（推奨）
    // または
    // screenshot: 'on',               // 全テストで撮影（ビジュアルリグレッションテスト向け）
    // screenshot: 'off',              // 撮影しない（デフォルト）
    // screenshot: 'on-first-retry',   // 最初のリトライ時のみ（Playwright 1.49+）
  },
})
```

**オプション解説**:
| オプション | 説明 | 用途 |
|-----------|------|------|
| `'off'` | スクリーンショット無効（デフォルト） | 通常開発時 |
| `'on'` | 全テストで撮影（成功・失敗問わず） | ビジュアルリグレッションテスト、UI変更の記録 |
| `'only-on-failure'` | 失敗時のみ撮影 | **最も一般的**。デバッグ用途 |
| `'on-first-retry'` | 最初のリトライ時のみ撮影 | リトライ設定有効時、冗長なスクリーンショットを削減 |

### 保存先

デフォルトで `test-results/` ディレクトリに保存されます:

```
test-results/
  example-should-log-in-successfully-chromium/
    test-finished-1.png
```

### テスト内での手動スクリーンショット

```typescript
test('手動スクリーンショット', async ({ page }) => {
  await page.goto('/dashboard')

  // フルページスクリーンショット
  await page.screenshot({ path: 'dashboard-full.png', fullPage: true })

  // 特定要素のみ
  await page.locator('#user-profile').screenshot({ path: 'profile.png' })

  // クリップ（座標指定）
  await page.screenshot({
    path: 'header.png',
    clip: { x: 0, y: 0, width: 1920, height: 100 }
  })
})
```

**`page.screenshot()` パラメータ**:
| パラメータ | 説明 |
|-----------|------|
| `path` | ファイルパス |
| `fullPage` | フルスクロールページ撮影（デフォルト: `false`、ビューポートのみ） |
| `clip` | 撮影範囲を指定（例: `{ x: 0, y: 0, width: 1280, height: 720 }`） |
| `omitBackground` | 背景を透明化（デフォルト: 白背景） |
| `quality` | JPEG品質（0-100、PNG非適用） |
| `type` | 画像形式（`'jpeg'` or `'png'`） |

### カスタムエラーハンドリング付きスクリーンショット

```typescript
test('エラー時カスタムスクリーンショット', async ({ page }) => {
  await page.goto('https://playwright.dev/')

  try {
    await expect(page.locator('#undefined!')).toBeVisible()
  } catch (error) {
    // 失敗時にカスタムスクリーンショット
    await page.screenshot({ path: 'custom-error.png', fullPage: true })
    console.error('Test failed, custom screenshot taken!')
    throw error  // テストを失敗としてマーク
  }
})
```

### カスタムパス生成

```typescript
import { test } from '@playwright/test'

test('カスタムパス', async ({ page }, testInfo) => {
  await page.goto('/products')

  // テスト名とタイムスタンプでファイル名生成
  const screenshotPath = `screenshots/${testInfo.title}-${Date.now()}.png`
  await page.screenshot({ path: screenshotPath })
})
```

### HTMLレポートでのスクリーンショット表示

Playwrightの HTMLレポートは、失敗時のスクリーンショットを**自動埋め込み**します:

```bash
npx playwright show-report
```

ブラウザでレポートが開き、失敗テストをクリックすると**スクリーンショットが埋め込まれた詳細画面**が表示されます。

### CI環境でのアーティファクト保存

```typescript
export default defineConfig({
  use: {
    screenshot: 'only-on-failure',
  },
  reporter: [
    ['html'],
    ['junit', { outputFile: 'results.xml' }]
  ],
})
```

**GitHub Actions の場合**:

```yaml
- name: Run Playwright tests
  run: npx playwright test

- name: Upload screenshots
  if: failure()
  uses: actions/upload-artifact@v3
  with:
    name: playwright-screenshots
    path: test-results/
```

---

## テスト実行のビデオ録画

ビデオ録画は、スクリーンショットでは捉えられない**時系列の動きと遷移**を記録します。Flakyテストの調査やUIアニメーション確認に有効です。

### ビデオ録画設定

```typescript
export default defineConfig({
  use: {
    video: 'on-first-retry',  // 最初のリトライ時のみ（推奨）
    // オプション:
    // video: 'off',                // 録画なし（デフォルト）
    // video: 'on',                 // 全テストで録画
    // video: 'retain-on-failure',  // 失敗時のみ保持（成功したテストのビデオは自動削除）
    // video: 'on-first-retry',     // リトライ時のみ録画（Flakyテスト調査用）
  },
})
```

**オプション解説**:
| オプション | 説明 | 用途 |
|-----------|------|------|
| `'off'` | ビデオ録画無効（デフォルト） | 通常開発時 |
| `'on'` | 全テストで録画（成功・失敗問わず） | UI動作の全体記録、デモ用 |
| `'retain-on-failure'` | 全テストで録画するが、**成功したテストのビデオは削除** | **バランスの取れた選択** |
| `'on-first-retry'` | 最初のリトライ時のみ録画 | Flakyテスト調査用、ディスク容量節約 |

### ビデオサイズとフレームレート

```typescript
export default defineConfig({
  use: {
    video: {
      mode: 'on',
      size: { width: 1280, height: 720 },  // 解像度指定
    },
  },
})
```

指定しない場合、Playwrightはビューポートサイズを800x800に収まるようスケールダウンします。

### ディレクトリ指定（Node.js 直接実行）

```typescript
export default defineConfig({
  use: {
    video: {
      mode: 'on',
      size: { width: 1280, height: 720 },
    },
    contextOptions: {
      recordVideo: {
        dir: 'test-results/my-videos/',  // 保存先ディレクトリ
      },
    },
  },
})
```

### テスト内でのビデオパス取得

```typescript
test('ビデオパス確認', async ({ page }, testInfo) => {
  await page.goto('/checkout')
  await page.fill('#card-number', '4242424242424242')

  // テスト終了後にビデオパスを取得
  const videoPath = await page.video()?.path()
  console.log('Video saved:', videoPath)
})
```

**注意**: `playwright.config.ts` で `video` 設定を有効化する必要があります。

### Node.js での直接録画

```typescript
import { chromium } from 'playwright'

(async () => {
  const browser = await chromium.launch()
  const context = await browser.newContext({
    recordVideo: {
      dir: 'test-results/my-videos/',
      size: { width: 1280, height: 720 },
    },
  })
  const page = await context.newPage()

  await page.goto('https://playwright.dev/')
  await page.getByText('Get started').click()

  // ビデオを保存するため context.close() 必須
  await context.close()
  await browser.close()
})()
```

**重要**: `context.close()` を呼ばないとビデオファイルが保存されません。ランタイムエラーでスクリプトが途中終了すると、ビデオは保存されません。

**トラブルシューティング**:
- ビデオが保存されない → コンソールエラーを確認、`context.close()` が呼ばれているか確認
- ディレクトリが存在しない → 保存先ディレクトリの権限・存在を確認

### 保存場所とファイル形式

- **保存先**: `test-results/videos/` または指定ディレクトリ
- **ファイル形式**: WebM（現代のブラウザ・メディアプレーヤーでサポート）
- **ファイル名**: ランダムなID（例: `128d168173888fb.webm`）

### パフォーマンス・ストレージ考慮事項

- **ファイルサイズ**: ビデオは大容量（特に長時間テスト）
- **推奨設定**: `retain-on-failure` または `on-first-retry` でディスク節約
- **定期クリーンアップ**: `test-results/videos/` を定期削除

```bash
# 古いビデオを削除（例: 7日以上前）
find test-results/videos -name "*.webm" -mtime +7 -delete
```

### CI環境でのビデオ保存

**GitHub Actions の場合**:

```yaml
- name: Run Playwright tests
  run: npx playwright test

- name: Upload videos
  if: failure()
  uses: actions/upload-artifact@v3
  with:
    name: playwright-videos
    path: test-results/**/video.webm
```

**GitLab CI の場合**:

```yaml
test:
  script:
    - npx playwright test
  artifacts:
    when: on_failure
    paths:
      - test-results/**/video.webm
```

---

## Headless vs Headful モードの使い分け

Playwrightは、ブラウザをGUIあり（Headful）またはGUIなし（Headless）で実行できます。

### Headless Mode（デフォルト）

ブラウザウィンドウを表示せず、バックグラウンドで実行します。

```typescript
export default defineConfig({
  use: {
    headless: true,  // ブラウザUIを表示しない（デフォルト）
  },
})
```

または:

```bash
npx playwright test --headless
```

**利点**:
- **高速実行**: UI描画のオーバーヘッドなし
- **低リソース消費**: CPU・メモリ使用量削減
- **CI/CD環境に最適**: 多くのCI環境はGUIなし
- **並列実行に有利**: 複数ブラウザを同時起動しやすい

**欠点**:
- **デバッグが困難**: 画面が見えないため、スクリーンショット・ビデオ・トレースに依存
- **視覚的確認不可**: UIのアニメーション・レイアウト崩れを直接確認できない
- **Bot検出リスク**: 一部のサイトはHeadlessブラウザを検出（Playwrightは対策済み）

**使用すべきケース**:
- CI/CDパイプライン
- 大規模テストスイート（高速実行重視）
- Webスクレイピング（視覚的確認不要）

### Headful Mode

ブラウザウィンドウを表示します。

```typescript
export default defineConfig({
  use: {
    headless: false,  // ブラウザUIを表示
  },
})
```

または:

```bash
npx playwright test --headed
```

**利点**:
- **視覚的デバッグ**: テストの動きをリアルタイムで確認
- **UIアニメーション確認**: アニメーション・トランジションの検証
- **インタラクティブ開発**: テスト作成時の動作確認

**欠点**:
- **実行速度が遅い**: UI描画のオーバーヘッド
- **高リソース消費**: CPU・メモリ使用量増加
- **CI環境で使用不可**: GUIなし環境では起動失敗

**使用すべきケース**:
- ローカル開発・デバッグ
- インタラクティブ機能のテスト
- UIビジュアルの確認

### 環境に応じた切り替え

```typescript
export default defineConfig({
  use: {
    headless: !!process.env.CI,  // CI環境では自動的にheadless
  },
})
```

GitHub Actions では `CI` 環境変数が自動的に `true` に設定されるため、この設定でローカルはheadful、CI環境はheadlessに自動切り替わります。

### SlowMo（スロー再生）

Headfulモードで各アクションを意図的に遅延させ、視覚的に追いやすくします。

```typescript
export default defineConfig({
  use: {
    headless: false,
    launchOptions: {
      slowMo: 500,  // 各アクションを500ms遅延
    },
  },
})
```

**用途**: デバッグ時にテストの動きを目で追いやすくする

### Node.js 直接実行での設定

```typescript
import { chromium } from 'playwright'

(async () => {
  const browser = await chromium.launch({
    headless: false,  // Headful
    devtools: true,   // DevToolsを自動起動
    slowMo: 50,       // 各アクション50ms遅延
  })
  const page = await browser.newPage()
  await page.goto('https://playwright.dev/')
  await page.screenshot({ path: 'example.png' })
  await browser.close()
})()
```

### プロジェクト別設定

```typescript
export default defineConfig({
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        headless: false,  // Chromiumのみheadful
      },
    },
    {
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        headless: true,   // Firefoxはheadless
      },
    },
  ],
})
```

---

## まとめ

### デバッグツールの選択基準

| ツール | 最適用途 | 主な機能 |
|--------|---------|---------|
| **Inspector** | ロケーター検証、ステップ実行 | Pick Locator、Actionability Logs、ステップ実行 |
| **UI Mode** | 複数テストの対話的デバッグ、Watch Mode | タイムトラベルデバッグ、自動再実行、タイムライン |
| **Screenshot** | 失敗時の視覚的証拠、CI/CDレポート | 失敗時スナップショット、HTMLレポート統合 |
| **Video** | 再現困難なバグの記録、UIアニメーション検証 | 時系列の動作記録、Flakyテスト調査 |
| **Headful Mode** | ローカル開発、UIアニメーション確認 | リアルタイム視覚的デバッグ、SlowMo |
| **Headless Mode** | CI/CD、高速実行 | 高速・低リソース、並列実行に有利 |

### ベストプラクティス

| シチュエーション | 推奨設定 |
|---------------|---------|
| **開発時** | Headful + Inspector + SlowMo + Watch Mode (UI Mode) |
| **CI/CD** | Headless + `screenshot: 'only-on-failure'` + `video: 'on-first-retry'` |
| **Flaky調査** | Headful + Video recording + UI Mode でタイムライン分析 |
| **ロケーター修正** | Inspector の Pick Locator機能 |
| **複数テストの並行デバッグ** | UI Mode + Watch Mode |
| **過去の状態を遡って調査** | UI Mode のタイムトラベルデバッグ |

### 設定例（推奨）

```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    headless: !!process.env.CI,         // CI環境では自動headless
    screenshot: 'only-on-failure',      // 失敗時のみスクリーンショット
    video: 'on-first-retry',            // リトライ時のみビデオ録画
    trace: 'on-first-retry',            // トレース記録（リトライ時のみ）
  },
  retries: process.env.CI ? 2 : 0,      // CI環境でのみリトライ
})
```

### デバッグフロー

1. **テスト失敗** → HTMLレポート確認（スクリーンショット・ログ）
2. **原因不明** → UI Mode で実行、タイムライン分析
3. **ロケーター問題** → Inspector の Pick Locator で検証
4. **Flaky** → Video録画 + タイムトラベルで過去の状態を確認
5. **修正** → Watch Mode で自動再実行、即座にフィードバック
