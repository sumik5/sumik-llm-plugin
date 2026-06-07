# ビルド&デプロイ戦略

マイクロフロントエンドの成功には、強固な自動化戦略が不可欠です。このドキュメントでは、CI/CD、テスト、デプロイ戦略のベストプラクティスを解説します。

---

## 自動化の5原則

### 1. フィードバックループの高速化

**目標**: CI実行時間を10分以内に保つ。

**施策**:

| 施策 | 効果 | 実装方法 |
|------|------|---------|
| **並列実行** | 実行時間を1/N | マイクロフロントエンドごとに独立したジョブ |
| **インクリメンタルビルド** | 変更箇所のみビルド | Turborepo, Nx の利用 |
| **キャッシュ活用** | 依存関係インストール高速化 | Docker layer cache, npm cache |
| **テストの並列化** | テスト時間短縮 | Jest `--maxWorkers`, Playwright sharding |

**GitHub Actions例**:

```yaml
name: CI

on: [push, pull_request]

jobs:
  test-home:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
          cache: 'npm'
      - run: npm ci
      - run: npm test --workspace=home
      - run: npm run build --workspace=home

  test-products:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
          cache: 'npm'
      - run: npm ci
      - run: npm test --workspace=products
      - run: npm run build --workspace=products
```

### 2. 頻繁な反復

**目標**: 1日に複数回デプロイ可能な状態を維持。

**プラクティス**:
- 小さな変更を頻繁にマージ（Trunk-Based Development）
- Feature Flagで未完成機能を隠蔽
- 自動デプロイをデフォルト化

### 3. チームの強化

**目標**: 各チームが自律的にデプロイ可能。

**施策**:
- デプロイ権限の委譲
- セルフサービス型のCI/CD
- 失敗時の自動ロールバック機能

### 4. ガードレールの定義

**目標**: 品質基準を自動チェックし、問題を早期発見。

**チェック項目**:

| 項目 | ツール | 失敗時のアクション |
|------|--------|------------------|
| **Linting** | ESLint, Prettier | PRブロック |
| **Type Check** | TypeScript `tsc --noEmit` | PRブロック |
| **Unit Test** | Jest, Vitest | PRブロック |
| **Code Coverage** | Jest Coverage | 閾値未満で警告 |
| **Bundle Size** | bundlesize, size-limit | 増加で警告 |
| **Security Scan** | npm audit, Snyk | Critical脆弱性でPRブロック |
| **License Check** | license-checker | 非許可ライセンスでPRブロック |

### 5. テスト戦略の定義

テストピラミッドに従い、適切なバランスでテストを実装します（後述）。

---

## バージョン管理戦略

### Monorepo vs Polyrepo

#### Monorepo（単一リポジトリ）

**構成例**:

```
my-app/
├── packages/
│   ├── app-shell/
│   ├── home/
│   ├── products/
│   ├── checkout/
│   └── design-system/
├── package.json
└── lerna.json
```

**メリット**:
- 一貫性（共有設定、ツールバージョン統一）
- コード共有が容易（共通ライブラリ、型定義）
- アトミックなコミット（複数パッケージを一度に更新）
- リファクタリングが容易

**デメリット**:
- ビルド時間増大（大規模化で顕著）
- アクセス制御が困難（リポジトリ全体へのアクセス必要）
- Git履歴が混在

**推奨ツール**:

| ツール | 特徴 | 適用規模 |
|--------|------|---------|
| **Lerna** | 老舗、シンプル | 小〜中規模 |
| **Nx** | 高度なキャッシュ、並列実行 | 中〜大規模 |
| **Turborepo** | 高速ビルド、シンプルな設定 | 中〜大規模 |

#### Polyrepo（複数リポジトリ）

**構成例**:

```
org/app-shell
org/home-mfe
org/products-mfe
org/checkout-mfe
org/design-system
```

**メリット**:
- 完全な独立性（技術スタック、デプロイサイクル）
- アクセス制御が容易
- Git履歴がクリーン
- 小規模なCI実行時間

**デメリット**:
- コード共有が複雑（npm package化必須）
- 一貫性の維持が困難
- 横断的な変更が困難（複数PRが必要）
- 依存関係管理の複雑化

**推奨ツール**:
- **Bit**: コンポーネント共有プラットフォーム
- **Backstage**: 開発者ポータル（リポジトリカタログ）

#### 比較テーブル

| 観点 | Monorepo | Polyrepo |
|------|----------|----------|
| **コード共有** | ★★★★★容易 | ★★★npm経由 |
| **独立性** | ★★★制限あり | ★★★★★完全 |
| **ビルド時間** | ★★大規模で遅延 | ★★★★★高速 |
| **一貫性** | ★★★★★高い | ★★★工夫必要 |
| **リファクタリング** | ★★★★★容易 | ★★困難 |
| **アクセス制御** | ★困難 | ★★★★★容易 |
| **推奨組織規模** | 中規模 | 大規模 |

#### 選択ガイド

**Monorepoを選ぶべき状況**:
- チーム間の調整コストが低い（同一組織、近い場所）
- 共有ライブラリが多い
- 一貫性を重視

**Polyrepoを選ぶべき状況**:
- チームが地理的・組織的に分散
- 完全な独立性が必要
- アクセス制御が重要

---

## 継続的インテグレーション戦略

### テストピラミッド

テストの種類と比率を適切にバランスさせます。

```
       /\
      /E2E\      10% - 遅い、壊れやすい、高コスト
     /------\
    /Integr \   20% - 中速、API/DB連携
   /----------\
  /   Unit     \ 70% - 高速、安定、低コスト
 /--------------\
```

#### 1. Unit Test（70%）

**対象**: 単一関数・コンポーネントのロジック。

**ツール**: Jest, Vitest, React Testing Library

**例**:

```typescript
// utils/formatPrice.test.ts
import { formatPrice } from './formatPrice';

describe('formatPrice', () => {
  it('正の数値を通貨形式で表示', () => {
    expect(formatPrice(1234.56)).toBe('¥1,235');
  });

  it('0を正しく表示', () => {
    expect(formatPrice(0)).toBe('¥0');
  });

  it('負の数値を正しく表示', () => {
    expect(formatPrice(-500)).toBe('-¥500');
  });
});
```

#### 2. Integration Test（20%）

**対象**: 複数コンポーネントの連携、API通信。

**ツール**: React Testing Library, MSW (Mock Service Worker)

**例**:

```typescript
// components/ProductList.integration.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import { setupServer } from 'msw/node';
import { rest } from 'msw';
import { ProductList } from './ProductList';

const server = setupServer(
  rest.get('/api/products', (req, res, ctx) => {
    return res(ctx.json([
      { id: 1, name: 'Product A', price: 100 },
      { id: 2, name: 'Product B', price: 200 },
    ]));
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

test('API経由で商品一覧を表示', async () => {
  render(<ProductList />);

  await waitFor(() => {
    expect(screen.getByText('Product A')).toBeInTheDocument();
    expect(screen.getByText('Product B')).toBeInTheDocument();
  });
});
```

#### 3. E2E Test（10%）

**対象**: ユーザーシナリオ全体（複数マイクロフロントエンド横断）。

**ツール**: Playwright, Cypress

**例**:

```typescript
// e2e/checkout-flow.spec.ts
import { test, expect } from '@playwright/test';

test('商品購入フロー', async ({ page }) => {
  // 商品一覧ページ
  await page.goto('/products');
  await page.click('text=Product A');

  // 商品詳細ページ（productsマイクロフロントエンド）
  await expect(page).toHaveURL(/\/products\/\d+/);
  await page.click('text=カートに追加');

  // カートページ（cartマイクロフロントエンド）
  await page.goto('/cart');
  await expect(page.locator('.cart-item')).toHaveCount(1);

  // チェックアウトページ（checkoutマイクロフロントエンド）
  await page.click('text=購入手続きへ');
  await page.fill('[name="email"]', 'test@example.com');
  await page.fill('[name="cardNumber"]', '4242424242424242');
  await page.click('text=注文確定');

  // 完了ページ
  await expect(page.locator('text=ご注文ありがとうございました')).toBeVisible();
});
```

### 適応度関数（Fitness Functions）

**概念**: アーキテクチャ品質を自動検証する関数。

**例**:

| 関数名 | 検証内容 | 実装方法 |
|--------|---------|---------|
| **循環依存検出** | マイクロフロントエンド間の不適切な依存 | madge, dependency-cruiser |
| **バンドルサイズ制限** | 各マイクロフロントエンドの最大サイズ | bundlesize, size-limit |
| **API契約遵守** | OpenAPI/GraphQL schema準拠 | Pact, GraphQL Code Generator |
| **アクセシビリティ** | WCAG 2.1 AA準拠 | axe-core, pa11y |
| **パフォーマンス** | Lighthouse score閾値 | Lighthouse CI |

**実装例（bundlesize）**:

```json
// package.json
{
  "bundlesize": [
    {
      "path": "./dist/home/main.*.js",
      "maxSize": "200 kB"
    },
    {
      "path": "./dist/products/main.*.js",
      "maxSize": "250 kB"
    }
  ]
}
```

```yaml
# .github/workflows/ci.yml
- name: Check bundle size
  run: npx bundlesize
```

### マイクロフロントエンド固有の運用

#### 1. 契約テスト（Contract Testing）

**目的**: マイクロフロントエンド間のインターフェース互換性を保証。

**ツール**: Pact

**例**:

```typescript
// products/tests/contract.spec.ts (Consumer側)
import { pactWith } from 'jest-pact';

pactWith({ consumer: 'ProductsMFE', provider: 'ProductsAPI' }, (interaction) => {
  interaction('商品一覧取得', ({ provider, execute }) => {
    provider
      .given('商品が存在する')
      .uponReceiving('商品一覧リクエスト')
      .withRequest({ method: 'GET', path: '/api/products' })
      .willRespondWith({
        status: 200,
        body: [
          { id: 1, name: 'Product A', price: 100 },
        ],
      });

    return execute(async (mockServer) => {
      const response = await fetch(`${mockServer.url}/api/products`);
      const products = await response.json();
      expect(products).toHaveLength(1);
    });
  });
});
```

#### 2. 互換性マトリックス

各マイクロフロントエンドのバージョン互換性を管理します。

| App Shell | Home | Products | Checkout |
|-----------|------|----------|----------|
| 1.0.0 | 1.0.x | 1.0.x | 1.0.x |
| 1.1.0 | 1.0.x, 1.1.x | 1.0.x, 1.1.x | 1.0.x |
| 2.0.0 | 2.0.x | 2.0.x | 1.1.x, 2.0.x |

**実装**: Module Federationのバージョン指定で制御。

---

## デプロイ戦略

### ブルーグリーンデプロイ vs カナリアリリース

#### ブルーグリーンデプロイ

**仕組み**: 本番環境（Blue）と同一の新環境（Green）を用意し、一度にトラフィックを切り替え。

**流れ**:

```
1. Blue環境（現行）が稼働中
2. Green環境（新版）をデプロイ
3. Green環境でテスト
4. ロードバランサーをGreenに切り替え
5. 問題があればBlueに即座にロールバック
```

**メリット**:
- ゼロダウンタイム
- 即座のロールバック
- 本番同等環境でのテスト

**デメリット**:
- インフラコスト2倍
- 全ユーザーに一度に影響

#### カナリアリリース（推奨）

**仕組み**: 新バージョンを一部ユーザーにのみ段階的に公開。

**流れ**:

```
1. 新版を5%のユーザーにデプロイ
2. メトリクス監視（エラー率、レスポンス時間）
3. 問題なければ25% → 50% → 100%と段階的に拡大
4. 問題があれば即座にロールバック
```

**実装例（AWS ALB）**:

```yaml
# ターゲットグループの重み付け
TargetGroups:
  - Name: products-v1
    Weight: 95  # 旧版
  - Name: products-v2
    Weight: 5   # 新版（カナリア）
```

**メリット**:
- リスク最小化（一部ユーザーのみ影響）
- 本番データで検証
- 段階的な問題発見

**デメリット**:
- 複雑な実装
- 長期間のバージョン併存

#### 比較テーブル

| 観点 | ブルーグリーン | カナリアリリース |
|------|-------------|----------------|
| **リスク** | 中（全体に一度に影響） | 低（段階的） |
| **ロールバック** | 瞬時 | 瞬時 |
| **インフラコスト** | 高（2倍） | 低（同時稼働最小） |
| **複雑度** | 低 | 高 |
| **推奨用途** | 小規模変更 | 大規模変更、新機能 |

### ストラングラーフィグパターン

**目的**: レガシーアプリケーションを段階的に置換。

**仕組み**:

```
       [ユーザー]
           ↓
     [Proxy/Gateway]
      ↙           ↘
[新MFE]         [レガシー]
 (10%)            (90%)
    ↓ 段階的に拡大
[新MFE]         [レガシー]
 (50%)            (50%)
    ↓
[新MFE]         [レガシー]
 (100%)           (廃止)
```

**実装例（NGINX）**:

```nginx
location /products {
  # 10%を新マイクロフロントエンドへ
  split_clients $request_id $variant {
    10% new;
    * legacy;
  }

  if ($variant = "new") {
    proxy_pass http://products-mfe:3000;
  }

  proxy_pass http://legacy-app:8080;
}
```

**段階**:

1. **Phase 1**: 新機能のみ新MFEで実装
2. **Phase 2**: 既存機能を段階的に移行
3. **Phase 3**: レガシーシステム廃止

---

## 可観測性

### 主要ツール

| ツール | 機能 | マイクロフロントエンドでの用途 |
|--------|------|-------------------------|
| **Sentry** | エラートラッキング | 各MFEのJavaScriptエラー収集 |
| **New Relic** | APM、トレーシング | パフォーマンス監視、ボトルネック特定 |
| **LogRocket** | セッションリプレイ | ユーザー行動の可視化、バグ再現 |
| **Datadog** | 統合監視 | メトリクス、ログ、トレース統合 |
| **OpenTelemetry** | トレーシング標準 | 分散トレーシング、クロスMFE追跡 |

### メトリクス収集

**重要指標**:

| 指標 | 説明 | 目標値 |
|------|------|-------|
| **FCP (First Contentful Paint)** | 最初のコンテンツ表示 | < 1.8秒 |
| **LCP (Largest Contentful Paint)** | 最大コンテンツ表示 | < 2.5秒 |
| **FID (First Input Delay)** | 初回入力遅延 | < 100ms |
| **CLS (Cumulative Layout Shift)** | レイアウトシフト累積 | < 0.1 |
| **Error Rate** | エラー発生率 | < 0.1% |

**実装例（Web Vitals）**:

```typescript
import { onCLS, onFID, onLCP } from 'web-vitals';

function sendToAnalytics(metric) {
  fetch('/analytics', {
    method: 'POST',
    body: JSON.stringify({
      name: metric.name,
      value: metric.value,
      mfe: 'products',
    }),
  });
}

onCLS(sendToAnalytics);
onFID(sendToAnalytics);
onLCP(sendToAnalytics);
```

---

## 環境戦略

### 推奨環境構成

| 環境 | 用途 | デプロイタイミング |
|------|------|------------------|
| **DEV** | 開発者個人の動作確認 | Feature branch push |
| **STAGE** | QA、統合テスト | Main branch merge |
| **PROD** | 本番環境 | Release tag作成時 |

### 環境別設定管理

**環境変数例**:

```bash
# .env.development
REACT_APP_API_URL=http://localhost:4000
REACT_APP_AUTH_URL=http://localhost:4001

# .env.production
REACT_APP_API_URL=https://api.example.com
REACT_APP_AUTH_URL=https://auth.example.com
```

**動的設定（推奨）**:

```typescript
// config/runtime-config.ts
export async function loadConfig() {
  const response = await fetch('/config.json');
  return response.json();
}

// public/config.json（環境ごとに差し替え）
{
  "apiUrl": "https://api.example.com",
  "authUrl": "https://auth.example.com"
}
```

---

## 次のステップ

1. **リポジトリ戦略の決定**: Monorepo vs Polyrepo の選択
2. **CI/CDパイプラインの構築**: テストピラミッド + 適応度関数の実装
3. **デプロイ戦略の選択**: カナリアリリース推奨
4. **可観測性の実装**: Sentry, New Relic 等のセットアップ
5. **バックエンド統合の確認**: [BACKEND-PATTERNS.md](./BACKEND-PATTERNS.md) 参照
