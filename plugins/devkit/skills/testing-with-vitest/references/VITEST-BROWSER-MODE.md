# Browser Mode（v4 安定版）とビジュアル回帰テスト

Vitest v4 で Browser Mode が安定版になり、jsdom/happy-dom では再現困難なブラウザ固有の挙動（フォーム送信・フォーカス管理・CSS カスケード・IntersectionObserver 等）を実ブラウザ上で検証できるようになった。Node.js >= 20 / Vite >= 6 が必須。

---

## 概要と選択基準

| 観点 | jsdom / happy-dom | Browser Mode |
|------|------------------|--------------|
| 実行速度 | 高速（Node プロセス内） | 中速（ブラウザ起動コスト） |
| DOM 忠実度 | 低〜中（ポリフィルあり） | 高（実ブラウザ） |
| CSS / レイアウト | ほぼ未対応 | 完全対応 |
| ビジュアル回帰 | 不可 | `toMatchScreenshot()` 対応 |
| 推奨用途 | ユニット・ビジネスロジック | コンポーネント統合・視覚的検証 |

Browser Mode は `environment` オプション（`jsdom` 等を指定するキー）では**なく**、`test.projects` 経由で配線する。

---

## セットアップ

### インストール

```bash
# Playwright プロバイダー（推奨）
npm install -D @vitest/browser-playwright

# WebdriverIO プロバイダーを使う場合
npm install -D @vitest/browser-webdriverio
```

> 注意: v3 以前に使用されていた `@vitest/browser` パッケージは v4 で**廃止**。`@vitest/browser-playwright` に移行する。

### vitest.config.ts の設定（test.projects 経由）

```typescript
import { defineConfig } from 'vitest/config'
import { playwright } from '@vitest/browser-playwright'

export default defineConfig({
  test: {
    projects: [
      // ユニットテスト（Node 環境）
      {
        test: {
          name: 'unit',
          environment: 'node',
          include: ['src/**/*.test.ts'],
        },
      },
      // ブラウザテスト
      {
        test: {
          name: 'browser',
          include: ['src/**/*.browser.test.ts'],
          browser: {
            enabled: true,
            provider: playwright(),          // オブジェクト形式で指定
            instances: [{ browser: 'chromium' }],
            headless: true,
          },
        },
      },
    ],
  },
})
```

`browser.provider` はオブジェクト（`playwright()` または `webdriverio()`）で指定する。v3 の文字列形式（`'playwright'`）は廃止。`/// <reference>` コメントは不要。

### 複数ブラウザの同時実行

```typescript
browser: {
  enabled: true,
  provider: playwright(),
  instances: [
    { browser: 'chromium' },
    { browser: 'firefox' },
    { browser: 'webkit' },
  ],
},
```

---

## 操作 API

```typescript
import { page, userEvent } from 'vitest/browser'
```

### ロケーター（要素取得）

| メソッド | 用途 |
|---------|------|
| `page.getByRole(role, opts?)` | ARIA ロール検索（推奨） |
| `page.getByLabelText(label)` | `<label>` に関連付けられた要素 |
| `page.getByText(text)` | テキスト内容で検索 |
| `page.getByTestId(id)` | `data-testid` 属性（最終手段） |
| `page.getByPlaceholder(text)` | プレースホルダー属性 |

### ユーザーインタラクション

```typescript
// フォーム入力
await userEvent.fill(page.getByLabelText('Email'), 'user@example.com')

// クリック
await userEvent.click(page.getByRole('button', { name: '送信' }))

// キーボード
await userEvent.type(page.getByRole('textbox'), 'Hello{Enter}')
```

### アサーション

ブラウザ向けアサーションは `expect.element(locator)` を使用する（通常の `expect` との混在可）。

```typescript
// 要素の存在・状態
await expect.element(page.getByRole('button')).toBeInTheDocument()
await expect.element(page.getByRole('status')).toHaveText('完了')
await expect.element(page.getByRole('textbox')).toBeDisabled()

// ビューポート内の表示確認（ratio: 表示率の最小値 0.0〜1.0）
await expect.element(page.getByTestId('banner')).toBeInViewport({ ratio: 0.5 })
```

---

## ダイアログの自動モック

`alert` / `confirm` / `prompt` はテストをブロック（ハング）させる可能性があるため、Browser Mode では自動的にモックされる。`confirm` は `true` を返し、`alert` は即時解除される。

```typescript
it('確認ダイアログを表示する', async () => {
  // ダイアログは自動的にハンドリングされる（手動インターセプト不要）
  await userEvent.click(page.getByRole('button', { name: '削除' }))
  await expect.element(page.getByRole('status')).toHaveText('削除完了')
})
```

---

## ビジュアル回帰テスト

### 基本的な使い方

```typescript
it('カードコンポーネントの外観', async () => {
  // 初回実行でベースラインスクリーンショットを生成
  // 2 回目以降は pixelmatch で差分比較
  await expect(page.getByTestId('card')).toMatchScreenshot('card-default')
})

// 比較閾値のカスタマイズ（0.0〜1.0、デフォルト値は約 0.01）
await expect(page.getByTestId('card')).toMatchScreenshot('card-hover', {
  comparatorOptions: { threshold: 0.1 },
})
```

### スクリーンショットの保存場所

スクリーンショットは `__screenshots__/<プラットフォーム>/<ブラウザ>/` に保存される。

```
__screenshots__
└── darwin          # macOS
│   └── chromium
│       └── card-default.png
└── linux           # CI 環境（Docker 等）
    └── chromium
        └── card-default.png
```

プラットフォーム・ブラウザの組み合わせごとにリファレンス画像を管理する設計のため、OS をまたいだ比較は意図的に行わない。

### ベースラインの更新

```bash
# 現在の状態をベースラインとして記録
vitest run --update
```

### フレイキーなビジュアルテストへの対策

フォント・GPU 描画の差異がスクリーンショットの不安定さの主因になる。

| 対策 | 方法 |
|------|------|
| 環境統一 | Docker または CI クラウド環境で実行（ローカル実行は開発確認のみ） |
| アニメーション無効化 | Playwright は `headless: true` 時に自動的に CSS アニメーションを無効化 |
| 動的コンテンツのマスク | `comparatorOptions.mask` で変動領域（日時・広告等）を除外 |
| ビューポート固定 | `browser.viewport: { width: 1280, height: 720 }` で統一 |

```typescript
// 動的領域のマスク例
await expect(page.getByTestId('dashboard')).toMatchScreenshot('dashboard', {
  comparatorOptions: {
    mask: [page.getByTestId('timestamp'), page.getByTestId('ads')],
  },
})
```

---

## 対応ブラウザバージョン下限

ネイティブ ESM サポートが条件。

| ブラウザ | 最小バージョン |
|---------|--------------|
| Chrome / Chromium | 87 以上 |
| Firefox | 78 以上 |
| Safari / WebKit | 15.4 以上 |
| Edge | 88 以上 |

---

## よくある設定ミスと回避策

| 問題 | 原因と対処 |
|------|-----------|
| `--browser` 指定時にエラー終了 | v3.2 以降、`browser` 設定なしで `--browser` フラグを使うと即失敗。`test.projects` 内に `browser` ブロックを必ず記述する |
| ロケーターが見つからない | DOM 更新を待機していない。`await expect.element(locator).toBeInTheDocument()` で待機してから操作する |
| CI のスクリーンショット差異 | ローカルとのフォント差。Docker イメージ（例: `mcr.microsoft.com/playwright`）で CI を統一する |

---

## クロススキル参照

- **フル E2E テスト**（シナリオ・認証フロー・クロスページ操作）→ `testing-e2e-with-playwright` スキルを参照
- **React コンポーネントの RTL ベーステスト**（`@testing-library/react`）→ `lang:developing-react` スキルを参照

---

## 関連ファイル

- [./VITEST-PROJECTS-PERFORMANCE.md](./VITEST-PROJECTS-PERFORMANCE.md) — `test.projects` の詳細設定・シャーディング・パフォーマンスチューニング
- [./VITEST-APIS.md](./VITEST-APIS.md) — `expect` マッチャー全体・`vi` API リファレンス
