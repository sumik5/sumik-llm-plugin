# モックとエミュレーション

Playwrightでは、デバイス、ネットワーク、時間、位置情報などを柔軟にエミュレーション・モック化できます。

---

## デバイスエミュレーション

### プリセットデバイスの使用

Playwrightは主要なモバイルデバイス・タブレットのプリセットを提供しています。

```typescript
import { devices } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'iPhone 15',
      use: { ...devices['iPhone 15 Pro'] },
    },
    {
      name: 'Pixel 7',
      use: { ...devices['Pixel 7'] },
    },
    {
      name: 'iPad Pro',
      use: { ...devices['iPad Pro'] },
    },
  ],
});
```

### カスタムデバイス設定

プリセットにないデバイス（スマートTV、カーナビ等）は手動で定義できます。

```typescript
export default defineConfig({
  projects: [
    {
      name: 'Custom TV',
      use: {
        ...devices['Desktop Chrome'],
        userAgent: 'Mozilla/5.0 (Web0S; Linux/SmartTV)',
        viewport: { width: 1920, height: 1080 },
        deviceScaleFactor: 1,
        isMobile: false,
        hasTouch: true,
      },
    },
  ],
});
```

### 主要プロパティ

| プロパティ | 説明 |
|-----------|------|
| `userAgent` | ブラウザのUser-Agent文字列 |
| `viewport` | 表示領域のサイズ（幅・高さ） |
| `screen` | デバイスのスクリーン解像度 |
| `deviceScaleFactor` | デバイスピクセル比（Retina等） |
| `isMobile` | モバイルデバイスとして動作するか |
| `hasTouch` | タッチイベントをサポートするか |

### テスト単位での設定変更

```typescript
test.use({
  ...devices['iPhone 15 Pro'],
  locale: 'ja-JP',
});

test('モバイル表示のテスト', async ({ page }) => {
  // このテストではiPhone 15 Pro設定が適用される
});
```

---

## 時空間エミュレーション

### ロケールとタイムゾーン

```typescript
// ロケール設定
test.use({ locale: 'en-US' });
test.use({ locale: 'ja-JP' });
test.use({ locale: 'fr-FR' });

// タイムゾーン設定
test.use({ timezoneId: 'Europe/Paris' });
test.use({ timezoneId: 'America/New_York' });
test.use({ timezoneId: 'Asia/Tokyo' });
```

### Clock API（時刻制御）

時刻に依存するロジックをテストする際に有用です。

```typescript
test('タイムセール表示テスト', async ({ page }) => {
  // 時刻を固定
  await page.clock.install();
  await page.clock.setFixedTime(new Date('2024-01-01T10:00:00'));

  await page.goto('/sale');
  await expect(page.locator('.sale-banner')).toBeVisible();

  // 時刻を5時間進める
  await page.clock.fastForward('05:00');
  await expect(page.locator('.sale-banner')).toBeHidden();
});

test('タイマーアニメーション', async ({ page }) => {
  await page.clock.install();
  await page.goto('/timer');

  // 時間を実際に進行させる（アニメーション実行）
  await page.clock.runFor('10:00');
  await expect(page.locator('.countdown')).toHaveText('完了');
});
```

### 位置情報とパーミッション

```typescript
test.use({
  // 位置情報パーミッション付与
  permissions: ['geolocation', 'notifications', 'camera'],

  // 位置座標設定
  geolocation: { longitude: 139.6917, latitude: 35.6895 }, // 東京
});

test('位置情報を使う機能', async ({ page }) => {
  await page.goto('/map');
  await page.locator('button:has-text("現在地を表示")').click();
  await expect(page.locator('.location-name')).toContainText('東京');
});
```

---

## ネットワークモック（Route）

### ルートパターン

| パターン | マッチ対象 |
|---------|-----------|
| `https://www.example.com/**` | 特定オリジンの全URL |
| `**/users` | オリジン無関係のパス（`/users`） |
| `**/users*` | パス + クエリパラメータ（`/users?id=1`） |
| `**/*.{png,jpeg}` | 特定拡張子のリソース |
| `/.*\\.(png\|jpeg)$/` | 正規表現パターン |

### レスポンス偽装

```typescript
test('API応答をモック', async ({ page }) => {
  // APIレスポンスを偽装
  await page.route('**/api/v1/fruits', async route => {
    await route.fulfill({
      json: [
        { name: 'Strawberry', id: 21 },
        { name: 'Banana', id: 42 },
      ],
    });
  });

  await page.goto('/fruits');
  await expect(page.locator('.fruit-item')).toHaveCount(2);
});
```

### 実レスポンス改変

```typescript
test('レスポンスを改変', async ({ page }) => {
  await page.route('**/api/v1/features*', async route => {
    // 実際のAPIを呼び出す
    const response = await route.fetch();
    const json = await response.json();

    // レスポンスを改変
    const feature = json.features.find(f => f.name === 'Pro Plan');
    if (feature) {
      feature.status = 'ACTIVE';
    }

    // 改変したレスポンスを返す
    await route.fulfill({ json });
  });

  await page.goto('/features');
  await expect(page.locator('[data-feature="Pro Plan"]')).toHaveClass(/active/);
});
```

### ネットワーク遅延シミュレーション

```typescript
test('遅いネットワークをシミュレート', async ({ page }) => {
  await page.route('**/api/v1/*', async route => {
    // 1秒遅延
    await new Promise(resolve => setTimeout(resolve, 1_000));
    await route.continue();
  });

  await page.goto('/dashboard');
  // ローディング表示を確認
  await expect(page.locator('.spinner')).toBeVisible();
});
```

### リソースブロック

不要なリソース（画像、広告等）をブロックしてテスト実行を高速化します。

```typescript
test('画像をブロック', async ({ page }) => {
  await page.route('**/*', route => {
    return route.request().resourceType() === 'image'
      ? route.abort()
      : route.continue();
  });

  await page.goto('/gallery');
  // 画像がロードされないことを確認
});
```

---

## HAR（HTTP Archive）記録＆再生

HARファイルを使って、ネットワーク通信を記録・再生できます。

### HAR再生

```typescript
test('HAR再生', async ({ page }) => {
  // HARファイルからレスポンスを再生
  await page.routeFromHAR('./hars/fruit.har', {
    url: '**/api/v1/fruits',
    update: false, // trueにすると実リクエストを記録
  });

  await page.goto('/fruits');
  await expect(page.locator('.fruit-item')).toHaveCount(2);
});
```

### HAR記録

```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    recordHar: {
      path: './hars/recorded.har',
      urlFilter: '**/api/**',
    },
  },
});
```

コマンドラインでの記録:

```bash
npx playwright test --update-har ./hars/fruit.har
```

---

## JavaScript注入

### ページ内でJavaScript実行

```typescript
test('ブラウザ内でJS実行', async ({ page }) => {
  await page.goto('/calculator');

  // ブラウザコンテキストで計算
  const result = await page.evaluate(() => {
    return 1 + 2;
  });

  expect(result).toBe(3);
});
```

### ページロード前にモック注入

```typescript
test('Math.randomをモック', async ({ page }) => {
  // ページロード前に実行されるスクリプトを追加
  await page.addInitScript(() => {
    Math.random = () => 0.42;
  });

  await page.goto('/random-demo');
  const value = await page.locator('#random-value').textContent();
  expect(value).toBe('0.42');
});

test('Date.nowをモック', async ({ page }) => {
  await page.addInitScript(() => {
    Date.now = () => 1609459200000; // 2021-01-01 00:00:00 UTC
  });

  await page.goto('/clock');
  await expect(page.locator('.date')).toContainText('2021-01-01');
});
```

---

## Chrome DevTools Protocol (CDP)

**注意**: CDPはChromiumブラウザ限定の機能です。

### CPU throttling

```typescript
test('CPUスロットリング', async ({ page, browserName }) => {
  if (browserName !== 'chromium') {
    test.skip();
  }

  const client = await page.context().newCDPSession(page);

  // CPUを4倍遅くする
  await client.send('Emulation.setCPUThrottlingRate', { rate: 4 });

  await page.goto('/heavy-computation');
  // 低速CPU環境での動作を確認
});
```

### ネットワーク条件設定

```typescript
test('3G回線をエミュレート', async ({ page, browserName }) => {
  if (browserName !== 'chromium') {
    test.skip();
  }

  const client = await page.context().newCDPSession(page);

  await client.send('Network.emulateNetworkConditions', {
    offline: false,
    downloadThroughput: (1.6 * 1024 * 1024) / 8, // 1.6 Mbps
    uploadThroughput: (750 * 1024) / 8,          // 750 Kbps
    latency: 150,                                 // 150ms
  });

  await page.goto('/streaming');
  // 低速回線での動作を確認
});
```

### その他のCDP機能

- Performance監視
- メモリプロファイリング
- カバレッジ計測
- セキュリティヘッダー設定

詳細は[Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)を参照してください。
