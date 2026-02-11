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

---

## クロスブラウザテスト設定

Playwrightは単一のAPIで複数ブラウザエンジンをサポートします。

### プロジェクト設定による並列実行

```typescript
// playwright.config.ts
export default defineConfig({
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
  ],
})
```

すべてのブラウザで並列実行:

```bash
npx playwright test
```

特定のブラウザのみ:

```bash
npx playwright test --project=webkit
```

### ブラウザ固有の動作の違い

| 機能 | Chromium | Firefox | WebKit |
|-----|---------|---------|--------|
| CDP | ✅ | ❌ | ❌ |
| User Agent | Chrome | Firefox | Safari |
| Date/Time API | 一致 | 一致 | 微妙な差異あり |
| CSS Grid | 完全対応 | 完全対応 | 一部制限あり |
| Web Components | 完全対応 | 完全対応 | Shadow DOM制限 |

### ブラウザ固有のスキップ

```typescript
test('CDP機能テスト', async ({ page, browserName }) => {
  // WebKitとFirefoxではスキップ
  test.skip(browserName !== 'chromium', 'CDP is Chromium-only')

  const client = await page.context().newCDPSession(page)
  await client.send('Emulation.setCPUThrottlingRate', { rate: 4 })
  // ... テスト続行
})
```

### ブラウザ固有の条件分岐

```typescript
test('ファイルアップロード', async ({ page, browserName }) => {
  await page.goto('/upload')

  if (browserName === 'webkit') {
    // WebKit固有の処理
    await page.setInputFiles('input[type="file"]', 'file.txt')
  } else {
    // Chromium/Firefox共通
    await page.locator('input[type="file"]').setInputFiles('file.txt')
  }
})
```

---

## モバイルテスト深掘り

### ビルトインデバイスプリセット

```typescript
import { devices } from '@playwright/test'

// 人気デバイス
const iPhone15 = devices['iPhone 15 Pro']
const pixel7 = devices['Pixel 7']
const iPadPro = devices['iPad Pro']
const galaxyS9 = devices['Galaxy S9+']

test.use(iPhone15)

test('モバイル表示確認', async ({ page }) => {
  await page.goto('/home')
  // iPhone 15 Pro の設定で実行される
})
```

利用可能なデバイス一覧:

```typescript
import { devices } from 'playwright'
console.log(Object.keys(devices))
```

### カスタムモバイルデバイス設定

```typescript
export default defineConfig({
  projects: [
    {
      name: 'Custom Mobile',
      use: {
        viewport: { width: 390, height: 844 },
        deviceScaleFactor: 3,
        isMobile: true,
        hasTouch: true,
        userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) ...',
      },
    },
  ],
})
```

### タッチ操作のエミュレーション

```typescript
test('スワイプジェスチャー', async ({ page }) => {
  await page.goto('/gallery')

  // タップ
  await page.locator('.image').tap()

  // スワイプ（drag）
  await page.locator('.carousel').dragTo(page.locator('.carousel'), {
    targetPosition: { x: -300, y: 0 }
  })

  // 長押し
  await page.locator('.context-menu-trigger').tap({ delay: 1000 })
})
```

### ピンチズーム

```typescript
test('ピンチズーム', async ({ page }) => {
  await page.goto('/map')

  // タッチポイント1
  await page.touchscreen.tap(100, 100)

  // 2点タッチでピンチ（低レベルAPI）
  await page.evaluate(() => {
    const event = new TouchEvent('touchstart', {
      touches: [
        { clientX: 100, clientY: 100 } as Touch,
        { clientX: 200, clientY: 200 } as Touch,
      ],
    })
    document.dispatchEvent(event)
  })
})
```

### 画面回転

```typescript
test('横向き表示', async ({ page, context }) => {
  // 縦向き → 横向き
  await context.addInitScript(() => {
    Object.defineProperty(window.screen.orientation, 'type', {
      get: () => 'landscape-primary'
    })
  })

  await page.goto('/video-player')
  // 横向きレイアウトを確認
})
```

---

## ジオロケーション（位置情報）のエミュレーション

```typescript
test.use({
  permissions: ['geolocation'],
  geolocation: { longitude: 139.6917, latitude: 35.6895 }, // 東京
})

test('現在地検索', async ({ page }) => {
  await page.goto('/map')
  await page.getByRole('button', { name: 'Use My Location' }).click()
  await expect(page.locator('.location-name')).toContainText('東京')
})
```

### 位置情報の動的変更

```typescript
test('位置情報の更新', async ({ page, context }) => {
  await context.grantPermissions(['geolocation'])

  // 初期位置
  await context.setGeolocation({ longitude: 139.6917, latitude: 35.6895 })
  await page.goto('/map')

  // 位置を変更
  await context.setGeolocation({ longitude: -0.1278, latitude: 51.5074 }) // ロンドン
  await page.getByRole('button', { name: 'Refresh' }).click()
  await expect(page.locator('.location-name')).toContainText('London')
})
```

---

## ネットワーク速度エミュレーション

### 3G 回線のシミュレーション（CDP）

```typescript
test('3G環境でのロード', async ({ page, browserName }) => {
  test.skip(browserName !== 'chromium', 'CDP is Chromium-only')

  const client = await page.context().newCDPSession(page)

  // 3G Fast相当
  await client.send('Network.emulateNetworkConditions', {
    offline: false,
    downloadThroughput: (1.6 * 1024 * 1024) / 8, // 1.6 Mbps
    uploadThroughput: (750 * 1024) / 8,          // 750 Kbps
    latency: 150,                                 // 150ms
  })

  await page.goto('/dashboard')
  // ローディング表示の確認
  await expect(page.locator('.spinner')).toBeVisible()
})
```

### オフライン状態のテスト

```typescript
test('オフライン時の動作', async ({ page, context }) => {
  await page.goto('/app')

  // オフラインに設定
  await context.setOffline(true)

  await page.getByRole('button', { name: 'Sync' }).click()
  await expect(page.getByText('No internet connection')).toBeVisible()

  // オンラインに復帰
  await context.setOffline(false)
})
```

---

## モバイル固有のデバッグ手法

### モバイルビューポートでのInspector

```bash
# モバイルデバイスでInspectorを起動
npx playwright test --debug --project="iPhone 15"
```

### スクリーンショット比較（異なるデバイス）

```typescript
const devices = ['iPhone 15 Pro', 'Pixel 7', 'iPad Pro']

for (const deviceName of devices) {
  test(`${deviceName} レイアウト`, async ({ playwright }) => {
    const device = playwright.devices[deviceName]
    const browser = await playwright.chromium.launch()
    const context = await browser.newContext(device)
    const page = await context.newPage()

    await page.goto('/home')
    await expect(page).toHaveScreenshot(`${deviceName}.png`)

    await browser.close()
  })
}
```

### タッチイベントのログ

```typescript
test('タッチイベント検証', async ({ page }) => {
  await page.goto('/gesture-test')

  // タッチイベントを監視
  await page.evaluate(() => {
    document.addEventListener('touchstart', (e) => {
      console.log('Touch Start:', e.touches[0].clientX, e.touches[0].clientY)
    })
    document.addEventListener('touchmove', (e) => {
      console.log('Touch Move:', e.touches[0].clientX, e.touches[0].clientY)
    })
    document.addEventListener('touchend', () => {
      console.log('Touch End')
    })
  })

  await page.locator('.swipeable').tap()
})
```

---

## 一般的なモバイル固有の問題と解決策

### 問題1: タッチターゲットが小さすぎる

**症状**: ボタンがクリックできない、または誤タップが発生

```typescript
// 解決策: CSSでタッチターゲットを拡大
test('タッチターゲットサイズ確認', async ({ page }) => {
  await page.goto('/buttons')

  const button = page.getByRole('button', { name: 'Submit' })
  const box = await button.boundingBox()

  // 最小44x44pxを推奨（Apple HIG）
  expect(box?.width).toBeGreaterThanOrEqual(44)
  expect(box?.height).toBeGreaterThanOrEqual(44)
})
```

### 問題2: ビューポート外の要素

**症状**: 要素が画面外にあるため操作できない

```typescript
// 解決策: スクロールしてから操作
test('画面外要素へのアクセス', async ({ page }) => {
  await page.goto('/long-page')

  // 自動スクロール（Playwrightのデフォルト動作）
  await page.getByRole('button', { name: 'Footer Button' }).click()

  // 手動スクロール
  await page.locator('#footer-section').scrollIntoViewIfNeeded()
  await page.getByRole('button', { name: 'Subscribe' }).click()
})
```

### 問題3: 固定ヘッダーによる要素の隠蔽

**症状**: 固定ヘッダーの下に要素が隠れてクリック不可

```typescript
// 解決策: スクロールオフセットを設定
test('固定ヘッダー回避', async ({ page }) => {
  await page.goto('/products')

  // ヘッダー高さ分オフセット
  await page.evaluate(() => {
    window.scrollBy(0, -80) // ヘッダー高さ80px分戻す
  })

  await page.getByRole('button', { name: 'Add to Cart' }).click()
})
```

### 問題4: モバイルメニューの表示切替

**症状**: ハンバーガーメニューが正しく開かない

```typescript
// 解決策: 状態遷移を待機
test('モバイルメニュー操作', async ({ page }) => {
  await page.goto('/home')

  const menuButton = page.getByRole('button', { name: 'Toggle Menu' })
  await menuButton.click()

  // メニューが開くまで待機
  const menu = page.locator('.mobile-menu')
  await expect(menu).toBeVisible()
  await expect(menu).toHaveClass(/open/)

  await menu.getByRole('link', { name: 'Settings' }).click()
})
```

### 問題5: 仮想キーボードによるレイアウトシフト

**症状**: 入力欄フォーカス時にレイアウトが崩れる

```typescript
// 解決策: ビューポート変化を監視
test('仮想キーボード対応', async ({ page }) => {
  await page.goto('/form')

  const input = page.getByLabel('Email')
  await input.focus()

  // visualViewport変化を確認
  const viewportHeight = await page.evaluate(() => window.visualViewport?.height)
  console.log('Viewport height:', viewportHeight)

  // 入力後に送信ボタンが見えるか確認
  await input.fill('user@example.com')
  await expect(page.getByRole('button', { name: 'Submit' })).toBeInViewport()
})
```

---

## まとめ

### クロスブラウザテストのベストプラクティス

1. **全ブラウザで並列実行**: CI/CDで `npx playwright test` を実行
2. **ブラウザ固有機能はスキップ**: `test.skip()` で分岐
3. **User Agent検証**: サーバーサイドのブラウザ判定をテスト

### モバイルテストのベストプラクティス

1. **主要デバイスでテスト**: iPhone、Android、iPad
2. **タッチ操作を明示的にテスト**: `tap()`, `dragTo()`
3. **ネットワーク速度を考慮**: 3G/4Gエミュレーションで遅延をテスト
4. **画面回転をテスト**: portrait/landscapeの両方を確認
5. **固定ヘッダー/フッターの影響を検証**: スクロール位置に注意
