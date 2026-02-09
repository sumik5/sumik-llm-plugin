# Playwright Test マスターガイド

## 📖 概要

このスキルは、**Playwright Test を使用した E2E（End-to-End）テスト**の包括的実践ガイドです。Playwright Test は Microsoft が提供する最新の E2E テストフレームワークであり、信頼性の高い自動化テストを構築するための強力な機能を提供します。

### 既存スキルとの違い

このスキルは、以下の既存スキルとは明確に異なる目的を持ちます：

| スキル | 対象 | 用途 |
|--------|------|------|
| **`testing-code`** | TDD 全般（Vitest / RTL / Jest） | 単体テスト・統合テストの設計原則、AAA パターン、カバレッジ |
| **PLAYWRIGHT-MCP.md** | MCP ブラウザ自動化 | `playwright-cli` による単発のブラウザ操作（スクレイピング、スクリーンショット） |
| **E2E-TESTING.md**（本ファイル） | Playwright Test E2E テスト | E2E テストスイート設計、ロケーター戦略、CI/CD、Flakiness 対策 |

**適切な選択基準:**
- **TDD 原則・単体テスト・統合テスト** → `testing-code` スキル
- **ブラウザ自動化・単発スクリプト** → PLAYWRIGHT-MCP.md
- **E2E テストスイート設計・実装** → 本ファイル（E2E-TESTING.md）

---

## 📑 目次（ナビゲーション）

このスキルは以下のサブファイルで構成されています。必要に応じて参照してください：

| ファイル | 内容 |
|---------|------|
| **[E2E-FUNDAMENTALS.md](./E2E-FUNDAMENTALS.md)** | セットアップ、テスト記述基礎、Assertions、Actions、設定 |
| **[E2E-LOCATORS.md](./E2E-LOCATORS.md)** | ロケーター戦略、Tier List、`getByRole` マスタリー |
| **[E2E-FIXTURES-AND-POM.md](./E2E-FIXTURES-AND-POM.md)** | Fixture 深掘り、Page Object Model（POM）設計 |
| **[E2E-CI-AND-PERFORMANCE.md](./E2E-CI-AND-PERFORMANCE.md)** | CI/CD パイプライン、並列化、シャーディング |
| **[E2E-MOCKING-AND-EMULATION.md](./E2E-MOCKING-AND-EMULATION.md)** | デバイスエミュレーション、ネットワークモック |
| **[E2E-RELIABILITY.md](./E2E-RELIABILITY.md)** | Auto-waiting、Flakiness 対策、リトライ戦略 |
| **[E2E-EXTENDING.md](./E2E-EXTENDING.md)** | カスタム expect、レポーター、テストデータ管理 |
| **[E2E-BEYOND-E2E.md](./E2E-BEYOND-E2E.md)** | API テスト、コンポーネントテスト、テスト戦略 |

---

## 🎯 使用タイミング

以下の状況に応じて、適切なサブファイルを参照してください：

| 状況 | 参照先 |
|------|--------|
| **E2E テスト新規作成** | [E2E-FUNDAMENTALS.md](./E2E-FUNDAMENTALS.md) → [E2E-LOCATORS.md](./E2E-LOCATORS.md) |
| **Fixture / POM 設計** | [E2E-FIXTURES-AND-POM.md](./E2E-FIXTURES-AND-POM.md) |
| **CI/CD パイプライン構築** | [E2E-CI-AND-PERFORMANCE.md](./E2E-CI-AND-PERFORMANCE.md) |
| **テスト高速化** | [E2E-CI-AND-PERFORMANCE.md](./E2E-CI-AND-PERFORMANCE.md) |
| **Flaky テスト対策** | [E2E-RELIABILITY.md](./E2E-RELIABILITY.md) |
| **ネットワークモック** | [E2E-MOCKING-AND-EMULATION.md](./E2E-MOCKING-AND-EMULATION.md) |
| **カスタムマッチャー実装** | [E2E-EXTENDING.md](./E2E-EXTENDING.md) |
| **API テスト・コンポーネントテスト** | [E2E-BEYOND-E2E.md](./E2E-BEYOND-E2E.md) |

---

## 🔧 playwright.config.ts テンプレート

最も参照される基本設定テンプレートを以下に示します：

```typescript
import { defineConfig, devices } from '@playwright/test'

/**
 * Playwright Test 設定
 * @see https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
  // テストディレクトリ
  testDir: './e2e',

  // 並列実行を有効化
  fullyParallel: true,

  // CI では .only を禁止
  forbidOnly: !!process.env.CI,

  // CI ではリトライ、ローカルではリトライなし
  retries: process.env.CI ? 2 : 0,

  // ワーカー数（CI では 1、ローカルでは自動）
  workers: process.env.CI ? 1 : undefined,

  // レポーター設定
  reporter: process.env.CI
    ? [['html'], ['github']]  // CI: HTML + GitHub Actions
    : 'html',                 // ローカル: HTML のみ

  // テスト実行時の共通設定
  use: {
    // ベース URL（相対パスで記述可能になる）
    baseURL: 'http://localhost:3000',

    // トレース記録（最初のリトライ時のみ）
    trace: 'on-first-retry',

    // スクリーンショット（失敗時のみ）
    screenshot: 'only-on-failure',
  },

  // 開発サーバー起動設定
  webServer: {
    command: 'npm run start',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,  // CI では必ず新規起動
  },

  // ブラウザごとのプロジェクト設定
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
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },

    // モバイルブラウザ（必要に応じて有効化）
    // {
    //   name: 'Mobile Chrome',
    //   use: { ...devices['Pixel 5'] },
    // },
    // {
    //   name: 'Mobile Safari',
    //   use: { ...devices['iPhone 12'] },
    // },
  ],
})
```

**設定の詳細は [E2E-FUNDAMENTALS.md](./E2E-FUNDAMENTALS.md) を参照してください。**

---

## 📋 ユーザー確認の原則（AskUserQuestion）

以下の判断分岐がある場面では、**AskUserQuestion ツールで必ずユーザーに確認**してください：

| 確認が必要な場面 | 選択肢例 |
|----------------|---------|
| **テスト戦略** | E2E のみ / E2E + 統合テスト / E2E + API テスト |
| **ロケーター選択** | `getByRole` 優先 / `getByTestId` 優先 / 混在 |
| **CI 環境** | GitHub Actions / GitLab CI / CircleCI / その他 |
| **並列化戦略** | workers 数（1 / 2 / 4 / 自動） / シャーディング数 |
| **認証パターン** | `storageState` 再利用 / 毎テストログイン / API 認証 |

**確認不要な事項（ベストプラクティスとして自動適用）:**
- Web-First Assertions の使用 → 常に使用
- ESLint ルール適用 → 常に適用
- Auto-waiting の活用 → 常に活用
- `page.waitForTimeout()` の回避 → 常に回避

---

## 🏗️ テスト構成の推奨パターン

Playwright Test プロジェクトの推奨ディレクトリ構成：

```
e2e/
├── tests/
│   ├── auth.setup.ts         # 認証セットアップ（storageState 生成）
│   ├── home.spec.ts          # ホーム画面テスト
│   ├── checkout.spec.ts      # チェックアウトフローテスト
│   └── admin.spec.ts         # 管理画面テスト
├── fixtures/
│   ├── test.ts               # カスタム test 拡張（Fixture 定義）
│   └── pages/                # Page Object Model（POM）クラス
│       ├── HomePage.ts
│       └── CheckoutPage.ts
├── helpers/
│   ├── auth-helpers.ts       # 認証ヘルパー
│   └── test-data.ts          # テストデータ生成
├── playwright.config.ts      # Playwright 設定
└── .auth/                    # 認証状態保存ディレクトリ（.gitignore に追加）
    └── user.json
```

**構成の詳細は [E2E-FIXTURES-AND-POM.md](./E2E-FIXTURES-AND-POM.md) を参照してください。**

---

## 🚀 クイックスタート

### 1. インストール

```bash
npm init playwright@latest
```

対話形式で以下を選択：
- テストディレクトリ: `e2e`
- GitHub Actions ワークフロー追加: `Yes`
- ブラウザインストール: `Yes`

### 2. 最初のテスト作成

```typescript
// e2e/tests/example.spec.ts
import { test, expect } from '@playwright/test'

test('ホーム画面が正しく表示される', async ({ page }) => {
  // Arrange: ページに移動
  await page.goto('/')

  // Act: タイトルを取得
  const title = await page.title()

  // Assert: タイトルが期待通りか検証
  expect(title).toBe('My App')
})
```

### 3. テスト実行

```bash
# すべてのテストを実行
npx playwright test

# 特定のテストファイルを実行
npx playwright test e2e/tests/example.spec.ts

# ヘッドフルモードで実行（ブラウザを表示）
npx playwright test --headed

# UI モードで実行（インタラクティブ）
npx playwright test --ui
```

### 4. レポート確認

```bash
# HTML レポートを開く
npx playwright show-report
```

---

## 📚 学習パス

Playwright Test を習得するための推奨学習順序：

1. **基礎** → [E2E-FUNDAMENTALS.md](./E2E-FUNDAMENTALS.md)
   - セットアップ、テスト記述、Assertions、Actions

2. **ロケーター** → [E2E-LOCATORS.md](./E2E-LOCATORS.md)
   - `getByRole` マスタリー、Tier List、セマンティック HTML

3. **再利用性** → [E2E-FIXTURES-AND-POM.md](./E2E-FIXTURES-AND-POM.md)
   - Fixture、POM、カスタム test 拡張

4. **信頼性** → [E2E-RELIABILITY.md](./E2E-RELIABILITY.md)
   - Auto-waiting、Flakiness 対策、リトライ戦略

5. **CI/CD** → [E2E-CI-AND-PERFORMANCE.md](./E2E-CI-AND-PERFORMANCE.md)
   - GitHub Actions、並列化、シャーディング

6. **高度なテクニック** → [E2E-MOCKING-AND-EMULATION.md](./E2E-MOCKING-AND-EMULATION.md) / [E2E-EXTENDING.md](./E2E-EXTENDING.md)
   - ネットワークモック、カスタムマッチャー、デバイスエミュレーション

7. **戦略** → [E2E-BEYOND-E2E.md](./E2E-BEYOND-E2E.md)
   - テストピラミッド、API テスト、コンポーネントテスト

---

## 🔑 重要な原則

### 1. **Web-First Assertions を必ず使用**
```typescript
// ❌ 悪い例（同期、リトライなし）
expect(await page.locator('button').textContent()).toBe('Submit')

// ✅ 良い例（非同期、自動リトライ）
await expect(page.locator('button')).toHaveText('Submit')
```

### 2. **`page.waitForTimeout()` を使用しない**
```typescript
// ❌ 悪い例（環境依存で不安定）
await page.waitForTimeout(1000)

// ✅ 良い例（条件ベースの待機）
await expect(page.locator('.success-message')).toBeVisible()
```

### 3. **セマンティックなロケーターを優先**
```typescript
// ❌ 悪い例（CSS セレクタ、壊れやすい）
await page.locator('button.btn-primary.bg-blue-500').click()

// ✅ 良い例（getByRole、アクセシブル）
await page.getByRole('button', { name: 'Submit' }).click()
```

### 4. **認証状態を再利用**
```typescript
// ❌ 悪い例（毎テストログイン、遅い）
test.beforeEach(async ({ page }) => {
  await page.goto('/login')
  await page.fill('[name="email"]', 'user@example.com')
  await page.fill('[name="password"]', 'password')
  await page.click('button[type="submit"]')
})

// ✅ 良い例（storageState 再利用、高速）
test.use({ storageState: '.auth/user.json' })
```

**詳細は各サブファイルを参照してください。**

---

## ❓ よくある質問

### Q1. Playwright と Puppeteer の違いは？
**A:** Playwright は Puppeteer の後継として開発され、複数ブラウザ（Chromium / Firefox / WebKit）対応、自動待機、強力なロケーター、テストフレームワーク統合などの機能が追加されています。新規プロジェクトでは Playwright を推奨します。

### Q2. E2E テストと統合テストの使い分けは？
**A:** 詳細は [E2E-BEYOND-E2E.md](./E2E-BEYOND-E2E.md) の「テスト戦略」セクションを参照してください。基本的には：
- **E2E**: ユーザーフロー全体（ログイン → 商品追加 → チェックアウト）
- **統合**: 複数コンポーネント間の連携（API → DB、フォーム送信 → バリデーション）

### Q3. Flaky テストを減らすには？
**A:** [E2E-RELIABILITY.md](./E2E-RELIABILITY.md) を参照してください。主な対策：
- Web-First Assertions を使用
- `page.waitForTimeout()` を避ける
- ネットワークの待機を明示
- ダイナミックコンテンツの完全な読み込みを確認

### Q4. CI で E2E テストが遅い場合は？
**A:** [E2E-CI-AND-PERFORMANCE.md](./E2E-CI-AND-PERFORMANCE.md) を参照してください。主な対策：
- 並列化（workers 数を増やす）
- シャーディング（テストを複数マシンに分散）
- 認証状態の再利用（storageState）
- 不要なテストの削除（テストピラミッドの見直し）

---

## 📖 参考リソース

- **公式ドキュメント**: https://playwright.dev
- **GitHub リポジトリ**: https://github.com/microsoft/playwright
- **Discord コミュニティ**: https://aka.ms/playwright/discord

---

**次のステップ**: [E2E-FUNDAMENTALS.md](./E2E-FUNDAMENTALS.md) から始めて、Playwright Test の基礎を学習してください。
