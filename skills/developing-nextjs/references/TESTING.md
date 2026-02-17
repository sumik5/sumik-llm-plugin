# Vitest + MSW + Playwright テストガイド

## 概要

Next.jsプロジェクトのテスト戦略。Vitest（ユニット/統合テスト）、MSW（APIモック）、Playwright（E2Eテスト）の三層構成。

## テスト配置戦略

| テスト種別 | ツール | 配置場所 | 例 |
|-----------|--------|---------|-----|
| ユニット/統合 | Vitest | `src/` 内コロケーション | `src/lib/utils.test.ts` |
| コンポーネント | Vitest + Testing Library | `src/` 内コロケーション | `src/components/button.test.tsx` |
| E2E | Playwright | `test/e2e/` （プロジェクトルート直下） | `test/e2e/login.spec.ts` |

**使い分けガイド:**
- **Vitest（ユニット/統合）**: 関数のロジック、Server Action、コンポーネントの振る舞いをテスト。MSWでAPIモック
- **Playwright（E2E）**: ユーザーフローの検証。ログイン→操作→結果確認のような画面横断テスト

## セットアップ

### Vitestインストール

```bash
pnpm add -D vitest @vitejs/plugin-react vite-tsconfig-paths jsdom
pnpm add -D @testing-library/react @testing-library/jest-dom @testing-library/user-event
pnpm add -D @vitest/coverage-istanbul
pnpm add -D msw
```

### Vitest設定

```typescript
// vitest.config.mts
/// <reference types="vitest" />
import { defineConfig } from "vitest/config";
import { configDefaults } from "vitest/config";
import react from "@vitejs/plugin-react";
import tsconfigPaths from "vite-tsconfig-paths";
import { resolve } from "path";

export default defineConfig({
  plugins: [react(), tsconfigPaths()] as any,
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/test/setup.ts"],
    include: ["src/**/*.{test,spec}.{ts,tsx}"],
    exclude: [
      ...configDefaults.exclude,
      "src/components/ui/**/*.test.{ts,tsx}", // shadcn自動生成ファイル除外
    ],
    coverage: {
      provider: "istanbul",
      reporter: ["text", "json", "html", "json-summary"],
      include: ["src/**/*.{ts,tsx}"],
      exclude: [
        "src/**/*.d.ts",
        "src/**/*.test.{ts,tsx}",
        "src/test/**/*",
        "src/components/ui/**/*",
        "src/types/**",
        "src/mocks/**",
      ],
    },
    testTimeout: 10000,
    hookTimeout: 10000,
    teardownTimeout: 10000,
    fileParallelism: false,
    pool: "threads",
    poolOptions: {
      threads: {
        singleThread: true,
        isolate: false,
      },
    },
    environmentMatchGlobs: [
      ["src/**/*.test.ts", "node"],
      ["src/**/*.test.tsx", "jsdom"],
    ],
  },
  resolve: {
    alias: {
      "@": resolve(__dirname, "./src"),
    },
  },
});
```

**設定のポイント:**
- `pool: "threads"`: ワーカースレッドを使用（forksよりメモリ効率が良い）
- `singleThread: true` + `isolate: false`: メモリ消費を最小化
- `fileParallelism: false`: ファイルレベルの並列実行を無効化（メモリ不足対策）
- `environmentMatchGlobs`: `.test.ts` → `node`（高速）、`.test.tsx` → `jsdom`（DOM必要時のみ）
- `coverage.provider: "istanbul"`: 安定したカバレッジ計測

### テストセットアップ

```typescript
// src/test/setup.ts
import "@testing-library/jest-dom";
import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

afterEach(() => {
  cleanup();
});
```

## MSW（Mock Service Worker）

### セットアップ

```bash
npx msw init public/ --save
```

### ハンドラー定義

```typescript
// src/mocks/handlers/users.ts
import { http, HttpResponse } from "msw";

export const usersHandlers = [
  http.get("/api/users", () => {
    return HttpResponse.json([
      { id: "1", name: "John Doe", email: "john@example.com" },
      { id: "2", name: "Jane Doe", email: "jane@example.com" },
    ]);
  }),

  http.post("/api/users", async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json(
      { id: "3", ...body },
      { status: 201 }
    );
  }),

  http.get("/api/users/:id", ({ params }) => {
    const { id } = params;
    return HttpResponse.json({
      id,
      name: "John Doe",
      email: "john@example.com",
    });
  }),
];
```

### ハンドラー統合

```typescript
// src/mocks/handlers/index.ts
import { usersHandlers } from "./users";
import { projectsHandlers } from "./projects";

export const handlers = [
  ...usersHandlers,
  ...projectsHandlers,
];
```

### ブラウザMSW設定

```typescript
// src/mocks/browser.ts
import { setupWorker } from "msw/browser";
import { handlers } from "./handlers";

export const worker = setupWorker(...handlers);
```

### テストでのMSW使用

```typescript
// src/test/setup.ts
import { afterAll, afterEach, beforeAll } from "vitest";
import { setupServer } from "msw/node";
import { handlers } from "@/mocks/handlers";

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

## テスト戦略

### ユニットテスト

**ユーティリティ関数のテスト:**
```typescript
// src/lib/utils.test.ts
import { describe, it, expect } from "vitest";
import { cn } from "./utils";

describe("cn", () => {
  it("should merge class names", () => {
    const result = cn("px-4", "py-2");
    expect(result).toBe("px-4 py-2");
  });

  it("should handle conditional classes", () => {
    const result = cn("px-4", false && "hidden", "py-2");
    expect(result).toBe("px-4 py-2");
  });
});
```

### コンポーネントテスト

**Buttonコンポーネントのテスト:**
```typescript
// src/components/ui/button.test.tsx
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Button } from "./button";

describe("Button", () => {
  it("should render correctly", () => {
    render(<Button>Click me</Button>);
    expect(screen.getByRole("button")).toHaveTextContent("Click me");
  });

  it("should call onClick when clicked", async () => {
    const handleClick = vi.fn();
    render(<Button onClick={handleClick}>Click me</Button>);

    const user = userEvent.setup();
    await user.click(screen.getByRole("button"));

    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it("should be disabled", () => {
    render(<Button disabled>Click me</Button>);
    expect(screen.getByRole("button")).toBeDisabled();
  });
});
```

### Server Actionのテスト

```typescript
// src/actions/users/create.test.ts
import { describe, it, expect, vi } from "vitest";
import { createUser } from "./create";

vi.mock("@/lib/prisma", () => ({
  prisma: {
    user: {
      create: vi.fn().mockResolvedValue({
        id: "1",
        email: "test@example.com",
        name: "Test User",
      }),
    },
  },
}));

describe("createUser", () => {
  it("should create a user", async () => {
    const formData = new FormData();
    formData.append("email", "test@example.com");
    formData.append("name", "Test User");

    const result = await createUser(formData);

    expect(result.success).toBe(true);
    expect(result.data?.email).toBe("test@example.com");
  });

  it("should return error for invalid email", async () => {
    const formData = new FormData();
    formData.append("email", "invalid-email");
    formData.append("name", "Test User");

    const result = await createUser(formData);

    expect(result.success).toBe(false);
    expect(result.error).toBeDefined();
  });
});
```

### ページコンポーネントのテスト（MSW使用）

```typescript
// src/app/users/page.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import UsersPage from "./page";

describe("UsersPage", () => {
  it("should render users list", async () => {
    render(await UsersPage());

    await waitFor(() => {
      expect(screen.getByText("John Doe")).toBeInTheDocument();
      expect(screen.getByText("Jane Doe")).toBeInTheDocument();
    });
  });
});
```

## Playwright E2Eテスト

### セットアップ

```bash
pnpm add -D @playwright/test
npx playwright install chromium
```

### Playwright設定

```typescript
// playwright.config.ts
import { defineConfig, devices } from "@playwright/test";

const E2E_PORT = process.env.E2E_PORT ?? "13000";

export default defineConfig({
  testDir: "./test/e2e",

  // CI環境は遅いため60秒に延長
  timeout: 60 * 1000,

  expect: {
    timeout: 15000,
  },

  fullyParallel: true,
  forbidOnly: !!process.env.CI,

  // 失敗時の再試行回数（フレーキーテスト対策）
  retries: process.env.CI ? 2 : 1,

  // CI環境ではワーカーを1に制限して安定性向上
  ...(process.env.CI ? { workers: 1 } : {}),

  reporter: [
    ["html", { outputFolder: "playwright-report" }],
    ["junit", { outputFile: "test-results/junit.xml" }],
    ["list"],
  ],

  use: {
    baseURL: process.env.BASE_URL ?? `http://localhost:${E2E_PORT}`,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",

    // テスト用認証スキップヘッダー
    extraHTTPHeaders: {
      "x-skip-auth": "true",
    },
  },

  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
    // 必要に応じて追加
    // {
    //   name: "firefox",
    //   use: { ...devices["Desktop Firefox"] },
    // },
    // {
    //   name: "webkit",
    //   use: { ...devices["Desktop Safari"] },
    // },
  ],

  // テスト実行時に開発サーバーを自動起動
  webServer: {
    command: `NODE_ENV=test pnpm dev -p ${E2E_PORT}`,
    url: `http://localhost:${E2E_PORT}`,
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
});
```

**設定のポイント:**
- `testDir: "./test/e2e"`: プロジェクトルート直下に配置（Vitestのsrc内コロケーションと分離）
- `E2E_PORT = 13000`: 開発サーバー（3000）との競合回避
- `extraHTTPHeaders`: テスト用認証スキップパターン（proxy.tsで検査）
- `webServer`: テスト実行時に開発サーバーを自動起動。CI環境では毎回新規起動
- `retries`: CI環境で2回リトライ（フレーキーテスト対策）

### E2Eテスト実行コマンド

```bash
# E2Eテスト実行
pnpm test:e2e

# UIモード（対話的にテストを実行）
pnpm test:e2e:ui

# ブラウザ表示ありで実行
pnpm test:e2e:headed
```

### package.json設定

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:headed": "playwright test --headed"
  }
}
```

## テスト実行

### 基本的なコマンド

```bash
# すべてのユニットテストを実行
pnpm test

# UIモード（推奨）
pnpm test:ui

# カバレッジレポート生成
pnpm coverage

# ウォッチモード
pnpm test:watch
```

### package.json設定（Vitest）

```json
{
  "scripts": {
    "test": "NODE_OPTIONS='--max-old-space-size=4096' vitest run",
    "test:ui": "vitest --ui",
    "coverage": "vitest run --coverage",
    "test:watch": "vitest --watch"
  }
}
```

## カバレッジ目標

**目標: 100%カバレッジ（`testing`スキル参照）**

```bash
# カバレッジレポート生成
pnpm coverage

# カバレッジレポート表示（ブラウザ）
open coverage/index.html
```

## AI生成テストコードの注意点

AIが生成したテストコードは網羅的ですが、以下の観点でレビューが必要です。

### 主要な注意点

1. **テストケースの肥大化**: 分岐網羅・境界値を全部入りで生成 → 責務分離・優先度付けで絞り込む
2. **マジックナンバー/ストリング**: Enum/定数を無視して直書き → リファクタリング時の修正漏れの原因
3. **Fixture未使用**: 各テストでダミーデータ重複生成 → ファクトリー関数で共通化
4. **責務混在**: テスト対象外のケース（バリデーション等）まで含む → レイヤー分離
5. **重複テスト**: 同じ仕様を複数レイヤーでテスト → レイヤー間の重複排除

**詳細は `testing` スキルの [AI-REVIEW-GUIDELINES.md](../../../testing-code/references/AI-REVIEW-GUIDELINES.md) を参照してください。**

### AIへの指示例

```
【テスト生成時のプロンプト】
- 網羅率を上げる目的での境界値テストは禁止
- 各テストケースに「何の仕様を守るためか」を1行コメントで記述
- マジックナンバー/ストリングは禁止（Enum/定数を使用）
- Fixture/ファクトリー関数を活用
- テスト対象の責務外のケースは削除
- DB制約で保証される条件はテスト対象外
```

---

## ベストプラクティス

### 1. AAAパターン（Arrange-Act-Assert）

```typescript
it("should create a user", async () => {
  // Arrange（準備）
  const formData = new FormData();
  formData.append("email", "test@example.com");

  // Act（実行）
  const result = await createUser(formData);

  // Assert（検証）
  expect(result.success).toBe(true);
});
```

### 2. テストの独立性

**各テストは独立して実行可能:**
```typescript
beforeEach(() => {
  localStorage.clear();
});

afterEach(() => {
  cleanup();
});
```

### 3. 意味のあるテスト名

```typescript
// 良い例
it("should return error when email is invalid", () => {});

// 悪い例
it("test1", () => {});
```

### 4. Fixtureパターン（Next.js版）

#### Prismaシードとファクトリー関数

Next.jsプロジェクトでは、Prismaを使用する場合、テストデータの準備にファクトリー関数を活用します。

##### Fixtureファイルの配置

```
src/
├── test/
│   ├── fixtures/
│   │   ├── user.fixture.ts
│   │   ├── organization.fixture.ts
│   │   └── index.ts
│   └── setup.ts
```

##### ファクトリー関数の実装

```typescript
// src/test/fixtures/user.fixture.ts
import { User, UserRole, UserStatus } from '@/types/user'

export function createUserFixture(overrides?: Partial<User>): User {
  return {
    id: 'user_1',
    email: 'john@example.com',
    name: 'John Doe',
    role: UserRole.User,
    status: UserStatus.Active,
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date('2024-01-01'),
    ...overrides,
  }
}

export function createAdminUserFixture(overrides?: Partial<User>): User {
  return createUserFixture({
    role: UserRole.Admin,
    ...overrides,
  })
}
```

```typescript
// src/test/fixtures/organization.fixture.ts
import { Organization, OrganizationStatus } from '@/types/organization'

export function createOrganizationFixture(
  overrides?: Partial<Organization>
): Organization {
  return {
    id: 'org_1',
    name: 'ACME Corp',
    status: OrganizationStatus.Active,
    ownerId: 'user_1',
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date('2024-01-01'),
    ...overrides,
  }
}
```

```typescript
// src/test/fixtures/index.ts
export * from './user.fixture'
export * from './organization.fixture'
```

##### Server Actionでの使用例

```typescript
// src/actions/users/create.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createUser } from './create'
import { createUserFixture } from '@/test/fixtures'
import { UserRole, UserStatus } from '@/types/user'

vi.mock('@/lib/prisma', () => ({
  prisma: {
    user: {
      create: vi.fn(),
      findUnique: vi.fn(),
    },
  },
}))

describe('createUser', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // 仕様: 有効なデータでユーザーを作成
  it('should create user with valid data', async () => {
    const userData = createUserFixture({ email: 'test@example.com' })

    const { prisma } = await import('@/lib/prisma')
    vi.mocked(prisma.user.create).mockResolvedValue(userData)

    const formData = new FormData()
    formData.append('email', userData.email)
    formData.append('name', userData.name)

    const result = await createUser(formData)

    expect(result.success).toBe(true)
    expect(result.data?.email).toBe('test@example.com')
  })

  // 仕様: 管理者ユーザーを作成
  it('should create admin user', async () => {
    const adminData = createUserFixture({
      email: 'admin@example.com',
      role: UserRole.Admin,
    })

    const { prisma } = await import('@/lib/prisma')
    vi.mocked(prisma.user.create).mockResolvedValue(adminData)

    const formData = new FormData()
    formData.append('email', adminData.email)
    formData.append('name', adminData.name)
    formData.append('role', UserRole.Admin)

    const result = await createUser(formData)

    expect(result.success).toBe(true)
    expect(result.data?.role).toBe(UserRole.Admin)
  })
})
```

##### React Server Componentでの使用例

```typescript
// src/app/users/page.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import UsersPage from './page'
import { createUserFixture } from '@/test/fixtures'
import { UserRole } from '@/types/user'

vi.mock('@/lib/prisma', () => ({
  prisma: {
    user: {
      findMany: vi.fn(),
    },
  },
}))

describe('UsersPage', () => {
  // 仕様: ユーザー一覧を表示
  it('should render users list', async () => {
    const users = [
      createUserFixture({ id: 'user_1', name: 'John Doe' }),
      createUserFixture({ id: 'user_2', name: 'Jane Doe', email: 'jane@example.com' }),
    ]

    const { prisma } = await import('@/lib/prisma')
    vi.mocked(prisma.user.findMany).mockResolvedValue(users)

    render(await UsersPage())

    expect(screen.getByText('John Doe')).toBeInTheDocument()
    expect(screen.getByText('Jane Doe')).toBeInTheDocument()
  })

  // 仕様: 管理者には管理者バッジを表示
  it('should display admin badge for admin users', async () => {
    const users = [
      createUserFixture({ id: 'user_1', name: 'Admin User', role: UserRole.Admin }),
    ]

    const { prisma } = await import('@/lib/prisma')
    vi.mocked(prisma.user.findMany).mockResolvedValue(users)

    render(await UsersPage())

    expect(screen.getByText('Admin')).toBeInTheDocument()
  })
})
```

##### リレーションを持つエンティティのFixture

```typescript
// src/test/fixtures/project.fixture.ts
import { Project, ProjectStatus } from '@/types/project'
import { createOrganizationFixture } from './organization.fixture'

export function createProjectFixture(
  overrides?: Partial<Project>,
  organization?: Organization
): Project {
  const org = organization ?? createOrganizationFixture()

  return {
    id: 'proj_1',
    name: 'Project Alpha',
    organizationId: org.id,
    organization: org,
    status: ProjectStatus.Active,
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date('2024-01-01'),
    ...overrides,
  }
}
```

```typescript
// src/actions/projects/create.test.ts
import { describe, it, expect } from 'vitest'
import { createProject } from './create'
import { createProjectFixture, createOrganizationFixture } from '@/test/fixtures'

describe('createProject', () => {
  // 仕様: 組織配下にプロジェクトを作成
  it('should create project under organization', async () => {
    const org = createOrganizationFixture({ name: 'Custom Org' })
    const projectData = createProjectFixture({ name: 'Custom Project' }, org)

    const result = await createProject(projectData)

    expect(result.success).toBe(true)
    expect(result.data?.organization.name).toBe('Custom Org')
  })
})
```

#### Fixtureパターンのメリット（Next.js版）

1. **型安全性**: Prismaの型定義と同期
2. **DRY原則**: テストデータの重複排除
3. **メンテナンス性**: Prismaスキーマ変更時の修正が容易
4. **可読性**: テストの意図が明確
5. **Server Componentとの相性**: async/awaitとの組み合わせが自然

---

## トラブルシューティング

### メモリ不足エラー

**vitest.config.mtsで以下を設定:**
```typescript
{
  fileParallelism: false,
  pool: "threads",
  poolOptions: {
    threads: {
      singleThread: true,
      isolate: false,
    },
  },
}
```

**NODE_OPTIONSでヒープサイズを拡大:**
```json
{
  "scripts": {
    "test": "NODE_OPTIONS='--max-old-space-size=4096' vitest run"
  }
}
```

### MSWが動作しない

```bash
# MSWワーカー再初期化
npx msw init public/ --save
```

### Playwright E2Eテストが不安定

- `retries: 2`（CI環境）でフレーキーテスト対策
- `timeout: 60 * 1000` でCI環境のタイムアウトを延長
- `workers: 1`（CI環境）でリソース競合を回避

---

## AskUserQuestion（テスト構成の確認）

プロジェクト初期設定時に確認する項目:

| 確認項目 | 選択肢 | デフォルト |
|---------|--------|----------|
| E2Eフレームワーク | Playwright / Cypress | Playwright（推奨） |
| カバレッジプロバイダ | istanbul / v8 | istanbul（推奨） |

## 参考資料

- **Vitest公式**: https://vitest.dev
- **MSW公式**: https://mswjs.io
- **Playwright公式**: https://playwright.dev
- **Testing Library**: https://testing-library.com

---

**関連ドキュメント:**
- [EXAMPLES.md](./EXAMPLES.md) - テスト実装例
- **`testing`スキル**: TDD、カバレッジ100%目標
