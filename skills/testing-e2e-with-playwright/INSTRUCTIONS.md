# Playwright E2Eテスト開発ガイド

このスキルはPlaywright E2Eテストの設計・実装・運用における具体的なパターンとアンチパターンを提供します。

---

## 🚨 CRITICAL（絶対遵守）

以下のアンチパターンは**絶対に禁止**です。これらに違反するとテストの信頼性が損なわれます。

| トリガー（If X） | 行動（then Y） |
|----------------|--------------|
| 待機処理を書く時 | **`page.waitForTimeout()` は絶対禁止**。`await expect(locator).toBeVisible()` 等の条件ベース待機を使用 |
| hydration/レンダリング待ちが必要な時 | `networkidle` は原則禁止。`domcontentloaded` + 対象要素の `toBeVisible()` を使用。**例外**: 外部SDK読み込みが必要なセットアップファイル（Paygent SDK等）ではコメント付きで `networkidle` を許可 |
| ダイアログ内ボタンをクリックする時 | `force: true` は使用禁止。`await expect(button).toBeEnabled()` → `await button.click()` を使用 |
| 要素を検索する時 | `page.locator("text=XXX")` は使用禁止。`page.getByText("XXX")` を使用 |
| 値を取得してassertする時 | `const x = await ...; expect(x).toBe()` は禁止（自動リトライなし）。`await expect.poll()` または `await expect(locator).toHaveText()` 等のWeb-First Assertionsを使用 |
| エラーハンドリングする時 | `.catch(() => {})` でエラーを握りつぶさない。タイムアウト値を適切に設定するか、意図がある場合はコメントで理由を明記 |
| テストをスキップしたい時 | **`test.skip()` は絶対禁止**。テストはパスか失敗のみ。前提条件が満たせないならシードデータ・mock・テストコードを修正して動くようにする |
| 同じテストを複数回実行する時 | **同じテストを2度実行しない**。1回の実行でログ・動画を保存し、そこから調査する |
| CSSクラスやIDでロケーターを書く時 | `getByRole()` > `getByLabel()` > `getByTestId()` の優先順位でセマンティックロケーターを使用 |

---

## 推奨プロジェクト構成

```
e2e/
├── fixtures/          # テスト用フィクスチャ（Page Object注入、テストデータ）
│   ├── auth.fixture.ts
│   └── seed-data.fixture.ts
├── pages/             # Page Objectパターン実装
│   ├── base.page.ts
│   ├── login.page.ts
│   └── order-list.page.ts
├── tests/             # テストスイート
│   ├── auth.setup.ts    # セットアップスクリプト
│   └── *.spec.ts        # テストケース
├── helpers/           # ヘルパー関数・ユーティリティ
│   ├── test-data.ts
│   └── wait.ts
├── test-results/      # 実行結果（動画・スクリーンショット）
├── playwright.config.ts
└── package.json
```

**重要原則**:
- **テスト内で直接セレクタを使わない**: 必ずPage Objectを経由
- **テストデータは分離**: `helpers/test-data.ts` に定数として定義
- **フィクスチャでDI**: Page ObjectはfixtureでDI可能にする

---

## playwright.config.ts 推奨設定

```typescript
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,              // 並列実行
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 1,  // CI環境ではリトライ
  workers: process.env.CI ? 4 : 2,  // ワーカー数
  timeout: 60_000,                  // テストタイムアウト
  expect: {
    timeout: 5_000,                 // アサーションタイムアウト
  },
  use: {
    baseURL: process.env.BASE_URL || "http://localhost:3000",
    screenshot: "only-on-failure",
    trace: "on-first-retry",
    video: { mode: "on" },          // 常に動画記録
    locale: "ja-JP",
    timezoneId: "Asia/Tokyo",
  },
  projects: [
    {
      name: "setup",
      testMatch: /.*\.setup\.ts/,   // セットアップスクリプト
    },
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        storageState: ".auth/user.json", // 認証状態を共有
      },
      dependencies: ["setup"],      // セットアップ完了後に実行
    },
  ],
});
```

**ポイント**:
- `fullyParallel: true` でテスト並列実行（テストデータの分離が前提）
- `video: { mode: "on" }` で全テストの動画記録（失敗時の調査に必須）
- `dependencies` で認証セットアップの依存関係を定義

---

## ロケーター優先順位（セマンティックファースト）

1. **`getByRole()`**: ロール + アクセシブル名
   ```typescript
   page.getByRole("button", { name: "ログイン" })
   page.getByRole("tab", { name: "未発送" })
   ```

2. **`getByLabel()`**: フォーム要素のラベル
   ```typescript
   page.getByLabel("メールアドレス")
   page.getByLabel("パスワード")
   ```

3. **`getByText()`**: テキストコンテンツ
   ```typescript
   page.getByText("送り状の情報")
   page.getByText(/エラー|失敗/)  // 正規表現可
   ```

4. **`getByAltText()`**: 画像のalt属性
   ```typescript
   page.getByAltText("ゆうパック", { exact: true })
   ```

5. **`getByTestId()`**: data-testid属性（UI変更に強い）
   ```typescript
   page.getByTestId("submit-button")
   ```

6. **CSSセレクタ（最終手段）**: 他に方法がない場合のみ
   ```typescript
   page.locator("#email")
   page.locator('[role="progressbar"]')
   ```

**アンチパターン**:
- ❌ `page.locator("text=ログイン")` → ✅ `page.getByText("ログイン")`
- ❌ `page.locator(".btn-primary")` → ✅ `page.getByRole("button", { name: "送信" })`

---

## Page Object Model（POM）基本パターン

### 基底クラス: `BasePage`

```typescript
import { type Page } from "@playwright/test";

export abstract class BasePage {
  constructor(protected readonly page: Page) {}

  async navigate(path: string): Promise<void> {
    await this.page.goto(path);
    await this.page.waitForLoadState("domcontentloaded");
  }

  async getToastMessage(): Promise<string | null> {
    const toast = this.page.locator('[role="status"]').first();
    if (await toast.isVisible({ timeout: 5_000 }).catch(() => false)) {
      return toast.textContent();
    }
    return null;
  }

  async waitForLoading(): Promise<void> {
    const spinner = this.page.locator('[role="progressbar"]').first();
    if (await spinner.isVisible({ timeout: 2_000 }).catch(() => false)) {
      await spinner.waitFor({ state: "hidden", timeout: 30_000 });
    }
  }
}
```

### 具体的なPage Object

```typescript
import { type Locator } from "@playwright/test";
import { BasePage } from "./base.page";

export class OrderListPage extends BasePage {
  private readonly orderTable = this.page.locator("table");
  private readonly syncButton = this.page.getByRole("button", { name: "最新注文取得" });

  async goto(): Promise<void> {
    await this.navigate("/order");
  }

  async clickTab(tabName: string): Promise<void> {
    await this.page.getByRole("tab", { name: tabName }).click();
    await this.waitForLoading();
  }

  async getOrderCount(): Promise<number> {
    await this.page.locator("table tbody tr")
      .first()
      .waitFor({ state: "visible", timeout: 10_000 });
    const rows = this.orderTable.locator("tbody tr");
    return rows.count();
  }

  async clickOrderByName(orderName: string): Promise<void> {
    const row = this.orderTable.locator("tbody tr").filter({ hasText: orderName });
    await row.first().waitFor({ state: "visible" });
    await row.locator("td").first().click();
    await this.page.waitForURL(/\/(shippings|print)\//);
  }
}
```

---

## テストデータ原則

### 1. テストデータの完全分離

**各テストケースは独自のデータを使用する**。共有データは並列実行で競合を引き起こします。

```typescript
// helpers/test-data.ts
export const CARRIER_SERVICES = {
  japanpost: {
    yuupack: "ゆうパック",
  },
  yamato: {
    takkyubin: "宅急便",
  },
} as const;

export const TEST_CREDIT_CARD = {
  number: "4111111111111111",
  expiry: "12/30",
  cvc: "123",
  name: "TEST USER",
} as const;
```

### 2. シードデータ駆動

**テストの前提条件はシードデータで定義**。テスト内でデータ作成しない。

```typescript
// fixtures/seed-data.fixture.ts
export function getTestUser() {
  return {
    email: "test-user@example.com",
    password: "Test1234!@",
  };
}
```

---

## 詳細ガイドへの誘導

より詳細な情報は以下のreferencesファイルを参照してください:

| ファイル | 内容 |
|---------|------|
| `GOOD-TEST-PRACTICES.md` | テスト設計原則・テスト技法・ツール選定・フレークテスト対策・プロジェクト導入戦略 |
| `LOCATORS.md` | ロケーター戦略の詳細・優先順位・アンチパターン |
| `FIXTURES-AND-POM.md` | フィクスチャとPage Object Modelの実装パターン |
| `ASSERTIONS-AND-RELIABILITY.md` | Web-First Assertions・フレークネス対策・リトライ戦略 |
| `TEST-DATA.md` | テストデータ管理・分離・データ駆動テスト |
| `MOCKING.md` | APIモッキング・ネットワークエミュレーション |
| `AUTH-AND-SETUP.md` | 認証セットアップ・storageState・セッション管理 |
| `CI-AND-DOCKER.md` | CI/CD統合・Docker環境・並列実行 |
| `DEBUGGING.md` | デバッグ手法・トラブルシューティング・ログ分析 |
| `ADVANCED.md` | ビジュアルリグレッション・アクセシビリティ・APIテスト |

---

## クイックリファレンス

### テスト実行

```bash
# 全テスト実行
npx playwright test

# 個別ファイル実行
npx playwright test tests/order.spec.ts

# 特定テストのみ実行（--grep）
npx playwright test --grep "ship-01"

# デバッグモード
npx playwright test --debug

# UI Mode（対話的テスト実行）
npx playwright test --ui
```

### デバッグ優先順位

1. **動画確認**: `test-results/*/video.webm`
2. **スクリーンショット**: `test-results/*/test-failed-*.png`
3. **トレース**: `npx playwright show-trace trace.zip`
4. **バックエンドログ**: `docker logs <container-name>`

---

## 参考資料

- **Playwright公式ドキュメント**: https://playwright.dev/
- **Best Practices**: https://playwright.dev/docs/best-practices
- **Playwright Testing Library**: https://testing-library.com/docs/pptr-testing-library/intro/
