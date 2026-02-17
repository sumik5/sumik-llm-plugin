# CI/CDとDocker統合ガイド

PlaywrightをCI/CD環境で実行する際の設定・Docker統合・並列実行戦略を解説します。

---

## CI環境での基本設定

### playwright.config.ts のCI検出

```typescript
import { defineConfig } from "@playwright/test";

export default defineConfig({
  // CI環境でのみ有効な設定
  forbidOnly: !!process.env.CI,           // test.only() を禁止
  retries: process.env.CI ? 2 : 1,        // CI環境ではリトライ回数を増やす
  workers: process.env.CI ? 4 : 2,        // CI環境では並列度を上げる
  reporter: process.env.CI
    ? [["html", { open: "never" }], ["github"]]  // CI: HTML + GitHub Actions
    : [["html", { open: "on-failure" }]],        // Local: 失敗時にHTMLレポート自動表示
  use: {
    screenshot: "only-on-failure",
    trace: "on-first-retry",
    video: { mode: process.env.CI ? "retain-on-failure" : "on" },
  },
});
```

**ポイント**:
- `process.env.CI` でCI環境を検出
- CI環境ではリトライ回数・並列度を増やす
- ローカルでは失敗時にHTMLレポートを自動表示

---

## GitHub Actions での実行

### ワークフロー定義

```yaml
# .github/workflows/e2e.yml
name: E2E Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  e2e:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright Browsers
        run: npx playwright install --with-deps

      - name: Run E2E tests
        run: npx playwright test

      - name: Upload test results
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 7
```

**ポイント**:
- `npx playwright install --with-deps` でブラウザと依存パッケージをインストール
- 失敗時にレポートをアーティファクトとしてアップロード

---

## Docker環境でのPlaywright実行

### Dockerfile

```dockerfile
FROM mcr.microsoft.com/playwright:v1.40.0-jammy

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

# Playwrightテスト実行
CMD ["npx", "playwright", "test"]
```

---

### docker-compose.yml

```yaml
version: "3.9"

services:
  playwright:
    build:
      context: ./e2e
      dockerfile: Dockerfile
    environment:
      - BASE_URL=http://frontend:3000
      - TEST_USER_EMAIL=test-user@example.com
      - TEST_USER_PASSWORD=Test1234!@
    volumes:
      - ./e2e:/app:cached
      - ./e2e/test-results:/app/test-results
    depends_on:
      - frontend
      - backend
    networks:
      - app-network

  frontend:
    image: my-frontend:latest
    ports:
      - "3000:3000"
    networks:
      - app-network

  backend:
    image: my-backend:latest
    ports:
      - "8080:8080"
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
```

**ポイント**:
- `volumes` でソースコードをマウント（コード変更が即座に反映）
- `depends_on` でフロントエンド・バックエンドの起動を待つ
- `networks` でサービス間通信を可能にする

---

### Docker Compose での実行

```bash
# 環境起動 + テスト実行
docker compose -f docker-compose.yml -f docker-compose.e2e.yml up --abort-on-container-exit

# テストのみ実行（環境はすでに起動済み）
docker compose run --rm playwright npx playwright test

# 個別テスト実行
docker compose run --rm playwright npx playwright test tests/order.spec.ts

# デバッグモード
docker compose run --rm playwright npx playwright test --debug
```

---

## 並列実行戦略

### workers 設定

```typescript
// playwright.config.ts
export default defineConfig({
  workers: process.env.CI ? 4 : 2,  // CI: 4並列、ローカル: 2並列
  fullyParallel: true,               // テストファイル単位で並列実行
});
```

**注意**:
- テストデータの分離が必須
- 同じデータを複数のテストで変更すると競合する

---

### シャーディング（大規模テストスイート向け）

```bash
# テストを4つのシャードに分割して実行
npx playwright test --shard=1/4  # シャード1
npx playwright test --shard=2/4  # シャード2
npx playwright test --shard=3/4  # シャード3
npx playwright test --shard=4/4  # シャード4
```

**GitHub Actions での並列実行**:
```yaml
jobs:
  e2e:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        shard: [1, 2, 3, 4]
    steps:
      - run: npx playwright test --shard=${{ matrix.shard }}/4
```

---

## アーティファクト管理

### テスト結果の保存

```yaml
# GitHub Actions
- name: Upload test results
  if: always()  # 成功・失敗問わずアップロード
  uses: actions/upload-artifact@v4
  with:
    name: playwright-report
    path: |
      playwright-report/
      test-results/
    retention-days: 7
```

---

### Docker でのアーティファクト保存

```bash
# test-results をホストにコピー
docker compose run --rm playwright npx playwright test
docker cp <container_id>:/app/test-results ./test-results
```

または `volumes` でマウント:
```yaml
volumes:
  - ./e2e/test-results:/app/test-results  # ホストと同期
```

---

## 環境変数の管理

### .env ファイル

```bash
# e2e/.env
BASE_URL=http://localhost:3000
TEST_USER_EMAIL=test-user@example.com
TEST_USER_PASSWORD=Test1234!@
SLOW_MO=0
```

```typescript
// playwright.config.ts
import dotenv from "dotenv";
import path from "path";

dotenv.config({ path: path.resolve(__dirname, ".env") });

export default defineConfig({
  use: {
    baseURL: process.env.BASE_URL || "http://localhost:3000",
    launchOptions: {
      slowMo: process.env.SLOW_MO !== undefined ? Number(process.env.SLOW_MO) : 2000,
    },
  },
});
```

---

### GitHub Secrets

```yaml
# GitHub Actions
- name: Run E2E tests
  env:
    BASE_URL: ${{ secrets.BASE_URL }}
    TEST_USER_EMAIL: ${{ secrets.TEST_USER_EMAIL }}
    TEST_USER_PASSWORD: ${{ secrets.TEST_USER_PASSWORD }}
  run: npx playwright test
```

---

## CI環境での最適化

### キャッシュ活用

```yaml
# GitHub Actions
- name: Cache Playwright browsers
  uses: actions/cache@v3
  with:
    path: ~/.cache/ms-playwright
    key: playwright-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}

- name: Install Playwright Browsers
  if: steps.cache.outputs.cache-hit != 'true'
  run: npx playwright install --with-deps
```

---

### タイムアウト設定

```yaml
# GitHub Actions
jobs:
  e2e:
    timeout-minutes: 30  # ジョブ全体のタイムアウト
```

```typescript
// playwright.config.ts
export default defineConfig({
  globalTimeout: 30 * 60_000,  // 全テストで30分
  timeout: 60_000,              // 1テストあたり60秒
});
```

---

## トラブルシューティング

### 問題1: ブラウザが起動しない（Docker）

**原因**: 依存パッケージ不足

**解決策**:
```dockerfile
FROM mcr.microsoft.com/playwright:v1.40.0-jammy
# 公式イメージを使用（依存パッケージ込み）
```

---

### 問題2: ネットワークタイムアウト

**原因**: CI環境のネットワーク遅延

**解決策**:
```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    navigationTimeout: process.env.CI ? 60_000 : 30_000,  // CI環境でタイムアウト延長
  },
});
```

---

### 問題3: メモリ不足

**原因**: 並列度が高すぎる

**解決策**:
```typescript
// playwright.config.ts
export default defineConfig({
  workers: process.env.CI ? 2 : 1,  // 並列度を下げる
});
```

---

## ベストプラクティス

### ✅ Good: CI環境を明示的に検出

```typescript
const isCI = !!process.env.CI;

export default defineConfig({
  retries: isCI ? 2 : 1,
  workers: isCI ? 4 : 2,
});
```

---

### ✅ Good: アーティファクトを常にアップロード

```yaml
- name: Upload test results
  if: always()  # 成功・失敗問わず
  uses: actions/upload-artifact@v4
```

---

### ❌ Bad: ハードコードされた並列度

```typescript
// ❌ CI環境でもローカルでも同じ設定
export default defineConfig({
  workers: 4,
});
```

---

## まとめ

- **CI検出**: `process.env.CI` で環境を判定
- **Docker統合**: 公式イメージ + docker-compose
- **並列実行**: `workers` とシャーディングで高速化
- **環境変数**: `.env` とGitHub Secretsで管理
- **アーティファクト**: 失敗時のレポートを保存
- **最適化**: キャッシュとタイムアウト設定
