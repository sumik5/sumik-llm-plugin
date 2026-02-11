# CI/CD パイプラインとパフォーマンス最適化

このドキュメントでは、PlaywrightテストをCI/CD環境で効率的に実行するための設定と、テスト実行速度を最大化する戦略を解説します。

---

## GitHub Actions 基本パイプライン

### 最小構成

```yaml
name: Playwright Tests
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: lts/*

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright Browsers
        run: npx playwright install --with-deps

      - name: Run Playwright tests
        run: npm run test:e2e

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 30
```

---

## Docker環境（推奨）

Docker環境を使用すると、ブラウザインストール時間を大幅に短縮できます（~30秒の高速化）。

### Docker ベースワークフロー

```yaml
name: Playwright Tests (Docker)
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:v1.55.0-noble
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: lts/*

      - name: Install dependencies
        run: npm ci

      - name: Run Playwright tests
        run: npm run test:e2e
        env:
          HOME: /root

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 30
```

### Docker環境の利点

- **ブラウザプリインストール**: `npx playwright install` 不要
- **依存関係完備**: システムライブラリがすべて含まれる
- **一貫性**: ローカルとCI環境の差異を最小化

---

## CI設定の最適化

`playwright.config.ts` をCI環境に最適化します：

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',

  // CI環境での厳格化
  forbidOnly: !!process.env.CI,

  // CI環境では並列度を制限
  workers: process.env.CI ? 1 : undefined,

  // CI環境ではリトライを有効化
  retries: process.env.CI ? 2 : 0,

  // CI環境での複数レポーター
  reporter: process.env.CI
    ? [
        ['html'],
        ['github'], // GitHub Actionsのアノテーション
        ['json', { outputFile: 'test-results.json' }],
      ]
    : 'html',

  use: {
    // 失敗時のみトレース保存
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
```

### 設定項目の解説

| 設定 | 説明 |
|------|------|
| `forbidOnly` | `.only()` の使用を禁止（CIでの誤実行防止） |
| `workers: 1` | アプリケーションと同一VM上でのリソース競合回避 |
| `retries: 2` | Flaky テストへの対応（最大3回実行） |
| `trace: 'retain-on-failure'` | 失敗時のみトレース保存（ストレージ節約） |
| `github` reporter | GitHub UI にテスト結果を表示 |

---

## レポート＆アーティファクト

### HTML Reportの永続化

```yaml
- name: Run Playwright tests
  run: npm run test:e2e

- uses: actions/upload-artifact@v4
  if: always()
  with:
    name: playwright-report
    path: playwright-report/
    retention-days: 30
```

### アーティファクトのダウンロードと閲覧

1. GitHub Actions の "Artifacts" セクションから `playwright-report.zip` をダウンロード
2. 解凍して `npx playwright show-report <path>` で閲覧

### Trace Viewer のオンライン利用

```yaml
- name: Upload trace files
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: traces
    path: test-results/**/trace.zip
```

`trace.zip` を https://trace.playwright.dev にドラッグ&ドロップで解析可能。

---

## ビジュアルリグレッションテスト in CI

### Docker環境での一貫性確保

ビジュアルリグレッションテストは、レンダリング環境の差異に敏感です。Docker環境を使用することで、ローカルとCIの差異を最小化できます：

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:v1.55.0-noble
    steps:
      # ... (前述の手順)
      - name: Run visual regression tests
        run: npm run test:visual
```

### 許容誤差の調整

```typescript
test('ホームページのスクリーンショット', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveScreenshot('homepage.png', {
    maxDiffPixels: 100,          // 最大100ピクセルの差異を許容
    maxDiffPixelRatio: 0.01,     // 1%の差異を許容
  });
});
```

### 実験的comparator（高精度）

```typescript
export default defineConfig({
  expect: {
    toHaveScreenshot: {
      stylePath: './screenshot.css', // 不要要素を非表示
      animations: 'disabled',
      comparator: 'ssim-cie94', // 実験的：人間の視覚に近い比較
    },
  },
});
```

### スクリーンショット更新ワークフロー

```yaml
name: Update Screenshots
on:
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:v1.55.0-noble
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npx playwright test --update-snapshots
      - uses: stefanzweifel/git-auto-commit-action@v5
        with:
          commit_message: "chore: update screenshots"
```

---

## 並列化戦略（Make It Fast）

### Worker数の判断基準

| 環境 | 推奨worker数 | 理由 |
|------|-------------|------|
| ローカル開発 | `undefined`（50%） | デフォルトで十分なリソース |
| CI（アプリ同梱） | `1` | アプリとテストでリソース競合回避 |
| CI（テスト専用） | `2-4` | リソースに余裕があれば並列化 |

### 並列化モード

| モード | 特徴 | 用途 |
|--------|------|------|
| `parallel` | テスト間完全独立 | 大半のテスト（推奨） |
| `default` | ファイル内順次実行 | 順序依存のテスト |
| `serial` | ブロック全体をリトライ | 避けるべき（遅い） |

### fullyParallel の活用

```typescript
export default defineConfig({
  // すべてのテストを並列実行（デフォルト: ファイル内は順次）
  fullyParallel: true,

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
```

個別テストでの制御：

```typescript
test.describe.configure({ mode: 'parallel' }); // このdescribe内は並列

test.describe('順序依存テスト', () => {
  test.describe.configure({ mode: 'default' }); // 順次実行

  test('ステップ1', async ({ page }) => { /* ... */ });
  test('ステップ2', async ({ page }) => { /* ... */ });
});
```

---

## シャーディング（水平スケーリング）

複数のマシンでテストを分散実行します。

### GitHub Actions matrix設定

```yaml
name: Playwright Tests (Sharded)
on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        shard: [1, 2, 3, 4]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
      - run: npm ci
      - run: npx playwright install --with-deps

      - name: Run tests (shard ${{ matrix.shard }}/4)
        run: npx playwright test --shard=${{ matrix.shard }}/4

      - name: Upload blob report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: blob-report-${{ matrix.shard }}
          path: blob-report/
          retention-days: 1

  merge-reports:
    needs: test
    if: always()
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
      - run: npm ci

      - name: Download all blob reports
        uses: actions/download-artifact@v4
        with:
          path: all-blob-reports
          pattern: blob-report-*
          merge-multiple: true

      - name: Merge reports
        run: npx playwright merge-reports --reporter=html ./all-blob-reports

      - name: Upload HTML report
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 30
```

### playwright.config.ts でのblob reporter設定

```typescript
export default defineConfig({
  reporter: process.env.CI ? 'blob' : 'html',
});
```

### シャーディングの効果

- **4シャード**: テスト時間を約1/4に短縮
- **コスト**: GitHub Actionsの並列ジョブ数に依存

---

## 認証セットアップ（One-Time Auth）

すべてのテストで認証状態を共有することで、ログイン時間を大幅に削減します。

### セットアッププロジェクト

```typescript
// tests/auth.setup.ts
import { test as setup } from '@playwright/test';

const authFile = './.auth/user.json';

setup('signin', async ({ page, context }) => {
  await page.goto('/login');
  await page.fill('[name="username"]', 'testuser');
  await page.fill('[name="password"]', 'password');
  await page.getByRole('button', { name: 'Login' }).click();

  await page.waitForURL('/dashboard');

  // 認証状態を保存
  await context.storageState({ path: authFile });
});
```

### playwright.config.ts での設定

```typescript
export default defineConfig({
  projects: [
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: './.auth/user.json',
      },
      dependencies: ['setup'], // setupプロジェクトを先に実行
    },
  ],
});
```

### .gitignore への追加

```gitignore
.auth/
```

### 効果

- **従来**: 各テストで5秒のログイン × 100テスト = 500秒
- **One-Time Auth**: 1回のログイン（5秒）+ 100テスト = 5秒削減

---

## さらなる最適化テクニック

### 1. Fail Fast（早期失敗）

```typescript
export default defineConfig({
  maxFailures: 10, // 10個失敗したら即座に停止
});
```

**リスク**: なし
**効果**: 大量失敗時のCI時間短縮

### 2. ロード最適化（waitUntil: 'commit'）

```typescript
test('高速ナビゲーション', async ({ page }) => {
  await page.goto('/', { waitUntil: 'commit' });
  // DOMContentLoaded を待たずにすぐ次の操作へ
  await page.getByRole('button', { name: 'Start' }).click();
});
```

**リスク**: 中（要素が未ロードの可能性）
**効果**: ページロード時間削減

### 3. 画像・CSS・フォントのブロック

```typescript
test.beforeEach(async ({ page }) => {
  await page.route('**/*.{png,jpg,jpeg,svg,woff,woff2}', (route) => route.abort());
  await page.route('**/*.css', (route) => route.abort());
});
```

**リスク**: 高（ビジュアルテストには不適）
**効果**: ネットワーク時間削減

### 4. --only-changed フラグ

```bash
npx playwright test --only-changed
```

**リスク**: なし
**効果**: 変更されたテストファイルのみ実行（PR時に有用）

### 最適化効果の比較

| テクニック | 時間削減 | リスク | 推奨度 |
|-----------|---------|--------|--------|
| Docker環境 | ~30秒 | なし | ★★★★★ |
| One-Time Auth | ~5秒/テスト | なし | ★★★★★ |
| シャーディング | 75% | なし | ★★★★☆ |
| Fail Fast | 大量失敗時大 | なし | ★★★★☆ |
| fullyParallel | 50% | なし | ★★★★☆ |
| --only-changed | PR時大 | なし | ★★★★☆ |
| waitUntil: 'commit' | ~1秒/ページ | 中 | ★★☆☆☆ |
| リソースブロック | ~2秒/ページ | 高 | ★☆☆☆☆ |

---

## GitLab CI 対応

### .gitlab-ci.yml 例

```yaml
stages:
  - test

playwright-tests:
  stage: test
  image: mcr.microsoft.com/playwright:v1.55.0-noble
  script:
    - npm ci
    - npx playwright test
  artifacts:
    when: always
    paths:
      - playwright-report/
    expire_in: 1 week
  only:
    - merge_requests
    - main
```

---

## まとめ

### CI/CD 環境構築のベストプラクティス

1. **Docker環境を使用**: ブラウザインストール時間を削減
2. **CI固有設定を分離**: `process.env.CI` での条件分岐
3. **アーティファクト保存**: レポートとトレースを必ず保存
4. **リトライ設定**: Flaky テスト対策に `retries: 2`

### パフォーマンス最適化の優先順位

1. **並列化**: `fullyParallel: true` + 適切なworker数
2. **シャーディング**: 大規模テストスイートで効果大
3. **One-Time Auth**: 認証を1回のみ実行
4. **Fail Fast**: 早期失敗で無駄な実行を削減
5. **--only-changed**: PR時に変更テストのみ実行

### 避けるべき最適化

- ❌ 画像・CSSブロック（リスク高）
- ❌ `waitUntil: 'commit'`（要素未ロードのリスク）
- ❌ タイムアウトの過度な短縮（Flaky テスト増加）

適切な最適化により、テスト実行時間を50-75%削減可能です。

---

## モダン開発ワークフローとの統合

### クラウドテストサービスの活用

ローカル環境では、ハードウェア制限とブラウザ/OS/デバイスの組み合わせ管理が課題となります。クラウドテストプラットフォームは、仮想マシンと実デバイスのグリッドへのオンデマンドアクセスを提供し、インフラ管理なしで大規模並列実行とクロス環境カバレッジを実現します。

#### 主要クラウドプラットフォーム

**Microsoft Playwright Testing (Azure App Testing)**
- Chromium、Firefox、WebKitのWindows/Linux/macOS対応
- シャーディングによる分散テスト実行
- Azure Pipelinesとの統合
- 数千のテストを数分で実行可能

**BrowserStack**
- Playwright APIと連携し、実デバイスとブラウザにアクセス
- モバイルWebテストに最適
- https://www.browserstack.com/docs/automate/playwright

**Sauce Labs**
- `saucectl` CLIでクラウド実行
- エミュレータと実デバイスの両対応
- https://docs.saucelabs.com/web-apps/automated-testing/playwright/

**LambdaTest**
- WebSocket接続によるライブテスト
- AI駆動のテストオーケストレーション
- https://www.lambdatest.com/playwright-testing

**統合方法:**
- `playwright.config.ts`で環境変数を使用して認証情報を設定
- CI/CDパイプラインに直接統合
- 大規模テストスイートの並列実行でスケール

---

### Agileワークフローへの組み込み

Agile開発では迅速なイテレーションと頻繁なリリースが求められます。Playwrightの高速なクロスブラウザテスト機能は、このニーズに適合します。

#### スプリントベースワークフロー

**スプリント終了時:**
- E2Eテストでユーザーストーリーを検証
- 新機能が既存機能と適切に統合されているか確認

**CI/CD統合:**
- コミットやプルリクエストごとにテストを自動実行
- スプリント内で即座にフィードバック

**タイミング別活用:**

| フェーズ | 用途 |
|---------|------|
| **スプリント初期** | スモークテストで初期ビルドの基本ナビゲーションとレンダリングを確認 |
| **スプリント中期** | APIモッキングやルート傍受でバックエンド完成前にフロントエンド動作を検証 |
| **スプリント終了** | 包括的なリグレッションテストでデモ/リリース準備完了を確認 |

#### TDD/BDDとの連携

**テスト駆動開発 (TDD):**
- Playwrightは単体テストレベルより高レベルのテストに適している
- **UI TDD**: 主要ユーザーフローのE2Eテストを先に書き、機能を実装してテストをパスさせる

**振る舞い駆動開発 (BDD):**
- CucumberなどのツールとPlaywrightを連携
- Gherkinシナリオを自動化

**ベストプラクティス:**
- E2Eテストは遅いため、すべての細かい変更には使用しない
- 統合ポイントではPlaywright、TDDサイクルでは高速なユニットテストを使用
- 成熟したAgileチームでは、並列実行やシャーディングで日次テスト実行を実用的に

---

### DevOps原則との整合

PlaywrightはDevOpsの継続的テストアプローチと相性が良く、早期フィードバックと迅速なリリースを支援します。

#### 継続的テスト (Continuous Testing)

**CI/CDパイプラインへの統合:**
- GitHub Actions、Jenkinsなどで依存関係インストール → `npx playwright test` → レポート共有
- 早期に問題を検出
- シャーディングによる並列実行で大規模スイートも数分で完了
- AlllureなどのツールでCI内のレポート強化

#### シフトレフトテスト (Shift-Left Testing)

DevOpsのシフトレフト原則は、開発サイクルの早期段階でテストを実施し、欠陥を早期に検出します。

**Playwrightのサポート:**
- コンポーネントテスト（例: `@playwright/experimental-ct-react`）でフルアプリなしでUI要素を分離テスト
- ローカル開発中にテスト実行可能

**実践方法:**
- CIチェックでコードレビューにテストを含める
- モックとFixtureで外部サービスに依存せずテスト
- シフトライト監視と連携して本番環境の問題も検出

**効果:**
- より迅速なリリース
- コスト削減
- 信頼性向上

---

### 効果的なフィードバックループ構築

テスト失敗時に、チームへの迅速な通知と明確なデバッグ手順が重要です。PlaywrightはレポートツールとCI/CD統合でこれを実現します。

#### CI/CDでの失敗通知

**GitHub Actions:**
- プルリクエストに失敗を直接表示
- 失敗した行やテストを明示

**Azure Pipelines:**
- JUnitレポーターで結果を公開
- Microsoft TeamsやSlackで通知

**Webhooks:**
- 失敗サマリーをコラボレーションプラットフォームに送信
- 開発者がCIダッシュボードを掘る必要なし

#### レポートツールによる詳細診断

**JSON / JUnit レポーター:**
- CIツールがパース可能な構造化ファイル生成
- カスタムダッシュボードやJira連携が可能
- Jenkins、CircleCIで詳細な失敗情報を提供

**HTML レポーター:**
- `playwright-report` フォルダに保存
- テスト結果、スクリーンショット、ビデオ、トレースを含む
- 失敗時に自動オープンまたはCIアーティファクトとしてアップロード
- `npx playwright show-report` で閲覧

**Trace Viewer:**
- テストをステップバイステップでリプレイ
- ネットワークリクエスト、DOMスナップショット、コンソールログを表示
- HTMLレポート内またはスタンドアロンで利用可能
- ネットワーク遅延やUIグリッチの特定に有効

**設定例 (playwright.config.ts):**

```typescript
export default defineConfig({
  reporter: [['dot'], ['html'], ['json']],
});
```

これにより、CI用の簡潔な出力とローカルデバッグ用の詳細診断の両方を提供できます。

**大規模並列実行時:**
- Blobレポーター（https://playwright.dev/docs/test-reporters）でシャード結果を単一レポートに統合
- フィードバックループを短縮: 失敗でCIマージをブロック、適切なチームメンバーに通知、詳細診断で迅速解決

---

## まとめ: CI/CDとパフォーマンス最適化の要点

### CI/CD環境構築のベストプラクティス

1. **Docker環境を使用**: ブラウザインストール時間を削減
2. **CI固有設定を分離**: `process.env.CI` での条件分岐
3. **アーティファクト保存**: レポートとトレースを必ず保存
4. **リトライ設定**: Flaky テスト対策に `retries: 2`
5. **クラウドサービス活用**: スケーラビリティと環境カバレッジ向上

### パフォーマンス最適化の優先順位

1. **並列化**: `fullyParallel: true` + 適切なworker数
2. **シャーディング**: 大規模テストスイートで効果大
3. **One-Time Auth**: 認証を1回のみ実行
4. **Fail Fast**: 早期失敗で無駄な実行を削減
5. **--only-changed**: PR時に変更テストのみ実行

### 開発ワークフローとの統合

1. **Agileスプリント**: 初期スモークテスト → 中期APIモック → 終了時リグレッション
2. **DevOpsパイプライン**: 継続的テスト、シフトレフト、シフトライト監視
3. **フィードバックループ**: 迅速な通知、詳細レポート、Trace Viewerによるデバッグ

### 避けるべき最適化

- ❌ 画像・CSSブロック（リスク高）
- ❌ `waitUntil: 'commit'`（要素未ロードのリスク）
- ❌ タイムアウトの過度な短縮（Flaky テスト増加）

適切な戦略とツールにより、Playwrightテストは開発ワークフローの中心的な資産となり、品質とスピードの両立を実現します。
