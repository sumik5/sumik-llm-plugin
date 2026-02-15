# E2E-VISUAL-REGRESSION.md

Playwrightのビジュアルリグレッションテストで、意図しないUI変更を検出する方法。スクリーンショット比較、許容差分管理、CI/CD統合のベストプラクティスを解説します。

---

## ビジュアルリグレッションテストとは

### 定義

従来のテストは「機能が動作するか」を確認しますが、**ビジュアルリグレッションテスト**は「UIが正しく表示されているか」を確認します。

- ボタンの位置ずれ
- アイコンの欠落
- 色の変化
- レイアウトの崩れ

これらを自動的に検出します。

### 基本的な仕組み

1. **スクリーンショット撮影**: 現在のUIを画像化
2. **ベースライン比較**: 承認済みの「正しい」画像と比較
3. **差分画像生成**: 違いがあれば視覚的に強調
4. **テスト失敗レポート**: 新規画像、ベースライン画像、差分画像を表示

---

## スクリーンショット撮影

### デバッグ用の単純撮影

```typescript
import { test, expect } from '@playwright/test';

test('take a simple screenshot for debugging', async ({ page }) => {
  await page.goto('https://playwright.dev/');

  // スクリーンショット保存
  await page.screenshot({
    path: 'test-results/playwright_homepage.png'
  });
});
```

### フルページスクリーンショット

```typescript
test('take full page screenshot', async ({ page }) => {
  await page.goto('https://playwright.dev/');

  await page.screenshot({
    path: 'test-results/playwright_full.png',
    fullPage: true  // スクロール範囲すべてを撮影
  });
});
```

### 要素単位のスクリーンショット

```typescript
test('take element screenshot', async ({ page }) => {
  await page.goto('https://playwright.dev/');

  // ヘッダー要素のみ撮影
  const element = page.locator('header');
  await element.screenshot({
    path: 'test-results/header.png'
  });
});
```

**推奨**: 要素単位のスクリーンショットは高速で、変更箇所を特定しやすいです。

---

## スクリーンショットのカスタマイズ

### コア引数

| オプション | 説明 |
|-----------|------|
| `path` | 保存先パス（拡張子でフォーマット決定） |
| `type` | `'png'` または `'jpeg'` |
| `fullPage` | `true`で全ページ撮影、デフォルトは `false`（ビューポートのみ） |
| `quality` | 0-100（JPEGのみ、高いほど高品質・大容量） |

### クリッピングとマスキング

#### クリップ（特定範囲のみ撮影）

```typescript
await page.screenshot({
  path: 'test-results/clip.png',
  clip: {
    x: 0,
    y: 0,
    width: 500,
    height: 100
  }
});
```

#### マスク（動的コンテンツを隠す）

```typescript
await page.screenshot({
  path: 'test-results/masked.png',
  mask: [
    page.locator('.ad'),        // 広告をマスク
    page.locator('.timestamp'), // タイムスタンプをマスク
  ]
});
```

マスクされた要素はピンク色のオーバーレイで隠されます。

### 高度なカスタマイズ

| オプション | 説明 |
|-----------|------|
| `omitBackground` | `true`で背景を透明化（PNGのみ） |
| `scale` | `'css'`（CSS基準）または `'device'`（デバイス基準、デフォルト） |
| `timeout` | 撮影のタイムアウト（デフォルト30秒） |
| `animations` | `'disabled'`でアニメーション停止（デフォルトは `'allow'`） |
| `caret` | `'hide'`でカーソルを非表示 |

#### 組み合わせ例

```typescript
await page.locator('#my-element').screenshot({
  omitBackground: true,   // 透明背景
  scale: 'css',           // ファイルサイズ削減
  animations: 'disabled', // アニメーション停止
  timeout: 5000           // 5秒でタイムアウト
});
```

最新のオプションは[Playwright公式ドキュメント](https://playwright.dev/docs/api/class-page#page-screenshot)を参照してください。

---

## スクリーンショット比較（ビジュアルリグレッションテスト）

### `toHaveScreenshot()` の使用

**注意**: `page.screenshot()` だけではテストカバレッジになりません。自動比較には `toHaveScreenshot()` が必要です。

```typescript
import { test, expect } from '@playwright/test';

test('Homepage should look the same', async ({ page }) => {
  await page.goto('https://practicesoftwaretesting.com/contact');

  // ビジュアルリグレッションテスト
  await expect(page).toHaveScreenshot('homepage.png');
});
```

### 初回実行（ゴールデンスナップショット作成）

初回実行時:

1. スクリーンショットを撮影
2. `tests/example.spec.ts-snapshots/` フォルダに保存
3. テストは失敗（比較対象がないため）

```bash
npx playwright test

# 出力例
> Error: A snapshot doesn't exist at tests\example.spec.ts-snapshots\homepage-chromium-win32.png, writing actual.
```

**ファイル名の規則**:
- `homepage-chromium-win32.png`
  - `chromium`: ブラウザ
  - `win32`: OS（Windows、`darwin`はmacOS、`linux`はLinux）

### 2回目以降（比較実行）

```bash
npx playwright test
```

毎回以下を実行:

1. メモリ上で新しいスクリーンショットを撮影
2. ディスク上のゴールデンスナップショットとピクセル単位で比較
3. 一致すればパス、差分があれば（許容範囲外なら）失敗

### 失敗時の確認

テストが失敗すると、差分がレポートに表示されます:

```bash
npx playwright show-report
```

HTMLレポートには3つの画像が並びます:

- **Expected**: ゴールデンスナップショット
- **Actual**: 新しいスクリーンショット
- **Diff**: 差分を強調表示

ビジュアルスライダーで「Expected」と「Actual」を比較できます。

**スナップショットはバージョン管理に含める**:
- チーム全体で同じベースラインを共有
- 意図的なUI変更をコードレビューで確認

---

## 許容差分の管理

### 差分の許容設定

完全一致は現実的でない場合があります（ブラウザのレンダリング差異、OS差異等）。

```typescript
await expect(page).toHaveScreenshot('homepage.png', {
  threshold: 0.2,       // 20%までの差分を許容
  maxDiffPixels: 100,   // 最大100ピクセルの差分を許容
});
```

### グローバル設定

```typescript
// playwright.config.ts
export default defineConfig({
  expect: {
    toHaveScreenshot: {
      threshold: 0.1,        // 10%の差分を許容
      maxDiffPixels: 50,     // 最大50ピクセル
      animations: 'disabled', // アニメーション停止
    },
  },
});
```

### 比較モード

```typescript
await expect(page).toHaveScreenshot('homepage.png', {
  // ピクセルごとの比較（デフォルト）
  comparator: 'pixelmatch',

  // SSIMアルゴリズム（知覚的類似度）
  // comparator: 'ssim',
});
```

---

## ゴールデンスナップショットの更新

### 意図的なUI変更時

```bash
# すべてのスナップショットを更新
npx playwright test --update-snapshots

# 特定のテストのみ更新
npx playwright test homepage.spec.ts --update-snapshots
```

### 差分レビュー後の承認

1. `npx playwright show-report` で差分を確認
2. 変更が意図的なら `--update-snapshots` で更新
3. 更新されたスナップショットをコミット

---

## CI/CDでのビジュアルリグレッション

### GitHub Actions での実装

```yaml
name: Playwright Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm ci
      - run: npx playwright install --with-deps

      # ビジュアルリグレッションテスト
      - run: npx playwright test

      # 失敗時にレポートをアップロード
      - uses: actions/upload-artifact@v3
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
```

### OSごとのスナップショット管理

**問題**: OSによってフォントやレンダリングが異なる。

**解決策**:

#### 1. OS固有のスナップショット

Playwrightは自動的にOS別にスナップショットを保存:

```
tests/example.spec.ts-snapshots/
  homepage-chromium-darwin.png   # macOS
  homepage-chromium-linux.png    # Linux
  homepage-chromium-win32.png    # Windows
```

#### 2. Dockerコンテナで統一

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:latest
    steps:
      - uses: actions/checkout@v3
      - run: npm ci
      - run: npx playwright test
```

すべての開発者・CIが同じLinux環境でテストを実行。

---

## テストの安定化テクニック

### 1. フォントのロード待機

**問題**: Webフォントのロードタイミングにより、スクリーンショットが不安定になる。

**解決策**: `document.fonts.ready` を使用してフォントロード完了を待機。

```typescript
test('stable screenshot with font loading', async ({ page }) => {
  await page.goto('https://example.com');

  // Webフォントのロード待機（必須）
  await page.evaluate(() => document.fonts.ready);

  await expect(page).toHaveScreenshot('stable.png');
});
```

### 2. アニメーションの無効化

**問題**: CSS animations、transitions、Web animations がスクリーンショットを不安定にする。

**グローバル設定**:

```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    // すべてのアニメーションを無効化
    launchOptions: {
      args: ['--force-prefers-reduced-motion']
    }
  }
});
```

**個別設定**:

```typescript
await expect(page).toHaveScreenshot('homepage.png', {
  animations: 'disabled',  // CSS animations/transitions/Web animations を停止
});
```

**CSSによる完全停止**（最も確実）:

```typescript
test('stable screenshot with animations disabled', async ({ page }) => {
  await page.goto('https://example.com');

  // すべてのアニメーションを完全停止
  await page.addStyleTag({
    content: `
      * {
        transition: none !important;
        animation: none !important;
      }
    `
  });

  await expect(page).toHaveScreenshot('stable.png');
});
```

### 3. 動的コンテンツのマスク

```typescript
await expect(page).toHaveScreenshot('homepage.png', {
  mask: [
    page.locator('.date'),      // 日付
    page.locator('.clock'),     // 時刻
    page.locator('.ad-banner'), // 広告
  ]
});
```

### 4. ビューポートの固定

```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    viewport: { width: 1280, height: 720 },
  }
});
```

### 5. ネットワークアイドルの待機

```typescript
await page.goto('https://example.com', {
  waitUntil: 'networkidle'
});

await expect(page).toHaveScreenshot('loaded.png');
```

---

## ベストプラクティス

### スナップショット命名

**悪い例**:
```typescript
await expect(page).toHaveScreenshot('test1.png');
```

**良い例**:
```typescript
await expect(page).toHaveScreenshot('checkout-summary-error.png');
```

説明的な名前で、後からレビューしやすくなります。

### 要素単位のスナップショット優先

**フルページは避ける**:
- 遅い
- 脆弱（小さな変更で失敗しやすい）
- デバッグが困難

**要素単位を推奨**:
```typescript
await expect(page.locator('header')).toHaveScreenshot('header.png');
await expect(page.locator('.cart')).toHaveScreenshot('cart.png');
```

### CI/CD専用スナップショット

開発環境とCI環境で差異が出る場合、CI専用の設定を作成:

```typescript
// playwright.config.ts
export default defineConfig({
  projects: [
    {
      name: 'visual-regression-ci',
      testMatch: '**/visual.spec.ts',
      use: {
        viewport: { width: 1280, height: 720 },
        deviceScaleFactor: 1,
      }
    }
  ]
});
```

### スナップショット数を最小限に

**すべてのページを撮影しない**:
- メンテナンスコストが高い
- 実行時間が長い

**重要な画面のみ**:
- ランディングページ
- チェックアウトフロー
- ダッシュボード

---

## よくある問題と対処法

### 問題: 毎回失敗する

**原因**:
- フォントロードのタイミング
- アニメーション
- 動的コンテンツ（日付、時刻）

**対処**:
- `animations: 'disabled'`
- `mask` で動的要素を隠す
- `await page.evaluate(() => document.fonts.ready)`

### 問題: OS間で差分が出る

**原因**:
- OS固有のフォントレンダリング
- アンチエイリアシング差異
- ブラウザバージョン差異

**対処法1: Dockerコンテナで環境統一**

ローカル開発・CI環境で同じLinuxコンテナを使用:

```bash
# ローカルでDockerコンテナ内でスナップショット更新
docker run --rm --ipc=host --shm-size=1gb \
  -v $(pwd):/work/ -w /work/ \
  mcr.microsoft.com/playwright:v1.56.1-noble \
  /bin/bash -c "npm ci && npx playwright install --with-deps && npx playwright test --update-snapshots"
```

**対処法2: OS固有のスナップショットを許容**

Playwrightは自動的にOS別にスナップショットを保存:

```
tests/example.spec.ts-snapshots/
  homepage-chromium-darwin.png   # macOS
  homepage-chromium-linux.png    # Linux
  homepage-chromium-win32.png    # Windows
```

### 問題: CI/CDで失敗するがローカルでは成功

**対処**:
- CI環境でスナップショット更新: `--update-snapshots`
- ビューポートとデバイススケールを固定
- `waitUntil: 'networkidle'` で完全ロードを待機

---

## まとめ

Playwrightのビジュアルリグレッションテストで:

- **自動検出**: 意図しないUI変更を早期発見
- **高速比較**: `toHaveScreenshot()` でピクセル単位の比較
- **CI/CD統合**: 継続的なUI品質チェック
- **柔軟な設定**: 許容差分、マスク、アニメーション制御

**ベストプラクティス**:
1. 要素単位のスクリーンショットを優先
2. 動的コンテンツをマスク
3. アニメーションを無効化
4. 明確な命名規則
5. 重要な画面のみテスト

ビジュアルリグレッションテストは、従来のE2Eテストを補完し、UIの品質を保証します。
