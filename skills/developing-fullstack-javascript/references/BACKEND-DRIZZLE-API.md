# Express 5 + Drizzle ORM による動的 CRUD API

Express 5 + Node.js + PostgreSQL + Drizzle ORM を使い、データベーススキーマを単一の真実の源泉として CRUD エンドポイントを自動生成する実装パターン。

> **DUPLICATE 除外対象**: NestJS セットアップ・REST/GraphQL 一般設計論は `BACKEND-STRATEGIES` を参照。本ファイルは Express 5 + Drizzle 固有のワークフローに限定する。

---

## ユーザー確認の原則（AskUserQuestion）

**以下の判断分岐は推測せず、必ず AskUserQuestion でユーザーに確認すること。**

| 確認すべき場面 | 選択肢の例 |
|---|---|
| ORM 選択 | Drizzle ORM / Prisma / 生 SQL |
| キャッシュ層採用 | in-memory / Redis / キャッシュなし |
| 認証方式 | JWT / セッション / OAuth2 |
| レート制限要否 | express-rate-limit / クラウド側制御 / なし |

確認不要な場面（ベストプラクティスとして固定）:
- 全外部入力の Zod 検証（セキュリティ必須）
- Helmet・CORS 設定（セキュリティ必須）
- マイグレーションのバージョン管理

---

## Express 5 セットアップ

### 依存パッケージ

```bash
npm install express@^5.1.0 dotenv cors helmet compression zod
npm install -D @types/express @types/cors @types/compression typescript tsx
```

### サーバー初期化（src/server.ts）

ミドルウェアの順序が重要: セキュリティ → パース → ルート → エラーハンドラー。

```typescript
import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import dotenv from 'dotenv';
dotenv.config();

const app: Express = express();

app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || 'http://localhost:5173',
  credentials: true
}));
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('Server error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

app.listen(process.env.PORT || 3000);
export default app;
```

### 環境変数バリデーション（src/config.ts）

起動時に Zod で検証し、不正な設定は即時終了する。

```typescript
import { z } from 'zod';

const envSchema = z.object({
  PORT: z.string().default('3000'),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  DATABASE_URL: z.string().url(),
  ALLOWED_ORIGINS: z.string().default('http://localhost:5173'),
  CACHE_TTL: z.string().transform(Number).default('3600')
});

export const config = (() => {
  try { return envSchema.parse(process.env); }
  catch (e) { console.error('Invalid env vars:', e); process.exit(1); }
})()!;
```

### 統一レスポンスユーティリティ（src/utils/responses.ts）

```typescript
import { Response } from 'express';

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  meta?: { total?: number; page?: number; limit?: number; totalPages?: number };
}

export const sendSuccess = <T>(
  res: Response, data: T, statusCode = 200, meta?: ApiResponse['meta']
): Response => res.status(statusCode).json({ success: true, data, ...(meta && { meta }) });

export const sendError = (res: Response, message: string, statusCode = 400): Response =>
  res.status(statusCode).json({ success: false, error: message });

export const sendNotFound = (res: Response, resource = 'Resource'): Response =>
  sendError(res, `${resource} not found`, 404);
```

---

## Drizzle ORM + PostgreSQL 統合

### 開発環境（docker-compose.yml）

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: development
      POSTGRES_DB: myapp_dev
    ports: ["5432:5432"]
    volumes: [postgres_data:/var/lib/postgresql/data]
volumes:
  postgres_data:
```

```bash
# 起動: docker compose up -d
# DATABASE_URL=postgresql://myapp:development@localhost:5432/myapp_dev
```

### インストール・設定

```bash
npm install drizzle-orm postgres
npm install -D drizzle-kit
```

```typescript
// drizzle.config.ts
import type { Config } from 'drizzle-kit';
import { config } from './src/config';
export default {
  schema: './src/db/schema.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: { url: config.DATABASE_URL }
} satisfies Config;

// src/db/index.ts
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { config } from '../config';
import * as schema from './schema';

export const db = drizzle(postgres(config.DATABASE_URL), { schema });
export type Database = typeof db;
```

---

## スキーマ定義とリレーション（src/db/schema.ts）

```typescript
import { pgTable, serial, varchar, text, timestamp, integer, boolean, index } from 'drizzle-orm/pg-core';
import { relations } from 'drizzle-orm';

export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  name: varchar('name', { length: 255 }).notNull(),
  bio: text('bio'),
  isActive: boolean('is_active').default(true).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull()
}, (t) => ({
  emailIdx: index('email_idx').on(t.email),
  activeIdx: index('active_idx').on(t.isActive)
}));

export const posts = pgTable('posts', {
  id: serial('id').primaryKey(),
  title: varchar('title', { length: 255 }).notNull(),
  content: text('content').notNull(),
  published: boolean('published').default(false).notNull(),
  authorId: integer('author_id').references(() => users.id).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull()
}, (t) => ({
  authorIdx: index('author_idx').on(t.authorId),
  authorPublishedIdx: index('author_published_idx').on(t.authorId, t.published)
}));

// リレーション定義（with: オプションで結合クエリが可能になる）
export const usersRelations = relations(users, ({ many }) => ({ posts: many(posts) }));
export const postsRelations = relations(posts, ({ one }) => ({
  author: one(users, { fields: [posts.authorId], references: [users.id] })
}));
```

---

## マイグレーション

```bash
npx drizzle-kit generate   # スキーマ差分から SQL ファイルを生成
npx drizzle-kit migrate    # データベースへ適用
```

起動時に自動実行する場合（本番デプロイパイプラインに組み込む）:

```typescript
// src/db/migrate.ts
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { config } from '../config';

if (require.main === module) {
  const client = postgres(config.DATABASE_URL, { max: 1 });
  migrate(drizzle(client), { migrationsFolder: './drizzle' })
    .then(() => { console.log('Migrations done'); return client.end(); })
    .then(() => process.exit(0))
    .catch(err => { console.error('Migration failed:', err); process.exit(1); });
}
```

```bash
tsx src/db/migrate.ts
```

---

## 動的 CRUD API 生成

### ルートファクトリ（src/api/factory.ts）

スキーマをイントロスペクトし、テーブルごとに CRUD エンドポイントを自動生成する。

```typescript
import { Express, Request, Response } from 'express';
import { db } from '../db';
import * as schema from '../db/schema';
import { eq, and } from 'drizzle-orm';
import { sendSuccess, sendError, sendNotFound } from '../utils/responses';
import { parsePaginationParams, buildPaginationMeta } from '../utils/pagination';

export const registerDynamicRoutes = (app: Express) => {
  const tables = Object.keys(schema).filter(
    k => !k.includes('Relations') && typeof (schema as any)[k] === 'object'
  );

  tables.forEach(tableName => {
    const table = (schema as any)[tableName];
    const base = `/${tableName}`;

    // GET 一覧（ページネーション + フィールドフィルタ）
    app.get(base, async (req: Request, res: Response) => {
      try {
        const { page, limit, offset } = parsePaginationParams(req);
        const { page: _p, limit: _l, ...filters } = req.query;
        const conds = Object.entries(filters).map(([k, v]) => eq(table[k], v));
        const records = await db.select().from(table)
          .where(conds.length ? and(...conds) : undefined)
          .limit(limit).offset(offset);
        sendSuccess(res, records, 200, buildPaginationMeta(records.length, { page, limit, offset }));
      } catch { sendError(res, 'Failed to fetch records', 500); }
    });

    // GET 単一・POST 新規・PUT 更新・DELETE 削除
    app.get(`${base}/:id`, async (req: Request, res: Response) => {
      try {
        const [r] = await db.select().from(table).where(eq(table.id, +req.params.id)).limit(1);
        r ? sendSuccess(res, r) : sendNotFound(res, tableName);
      } catch { sendError(res, 'Failed to fetch record', 500); }
    });

    app.post(base, async (req: Request, res: Response) => {
      try {
        const [r] = await db.insert(table).values(req.body).returning();
        sendSuccess(res, r, 201);
      } catch { sendError(res, 'Failed to create record', 400); }
    });

    app.put(`${base}/:id`, async (req: Request, res: Response) => {
      try {
        const [r] = await db.update(table).set(req.body)
          .where(eq(table.id, +req.params.id)).returning();
        r ? sendSuccess(res, r) : sendNotFound(res, tableName);
      } catch { sendError(res, 'Failed to update record', 400); }
    });

    app.delete(`${base}/:id`, async (req: Request, res: Response) => {
      try {
        await db.delete(table).where(eq(table.id, +req.params.id));
        sendSuccess(res, { deleted: true });
      } catch { sendError(res, 'Failed to delete record', 500); }
    });
  });
};
```

### リレーション対応（src/api/relational-factory.ts）

`*Relations` キーを持つスキーマ定義を自動検出し、`GET /{table}/:id/with-{relation}` を生成する。

```typescript
import { Express, Request, Response } from 'express';
import { db } from '../db';
import * as schema from '../db/schema';
import { eq } from 'drizzle-orm';
import { sendSuccess, sendNotFound } from '../utils/responses';

export const registerDynamicRelationalRoutes = (app: Express) => {
  Object.keys(schema).filter(k => k.includes('Relations')).forEach(relKey => {
    const tableName = relKey.replace('Relations', '');
    const table = (schema as any)[tableName];
    if (!table) return;

    Object.keys((schema as any)[relKey]).forEach(relName => {
      app.get(`/${tableName}/:id/with-${relName}`, async (req: Request, res: Response) => {
        try {
          const record = await (db.query as any)[tableName].findFirst({
            where: eq(table.id, +req.params.id),
            with: { [relName]: true }
          });
          record ? sendSuccess(res, record) : sendNotFound(res, tableName);
        } catch { sendNotFound(res, tableName); }
      });
    });
  });
};
```

### サーバーへの登録

```typescript
import { registerDynamicRoutes } from './api/factory';
import { registerDynamicRelationalRoutes } from './api/relational-factory';
import { registerCachedRoutes } from './api/cached-factory';
import { registerSearchRoutes } from './api/search';

registerDynamicRoutes(app);
registerDynamicRelationalRoutes(app);
registerCachedRoutes(app);
registerSearchRoutes(app);
```

---

## パフォーマンス最適化

### キャッシュ層（src/utils/cache.ts）

> ⚠️ **AskUserQuestion**: 本番環境のキャッシュ層（in-memory / Redis / なし）は要件次第。スケールアウト時は in-memory は使えないため Redis が必要になる。実プロジェクトでは必ずユーザーに確認すること。

```typescript
interface CacheEntry<T> { data: T; timestamp: number; ttl: number; }

class SimpleCache {
  private store = new Map<string, CacheEntry<unknown>>();

  set<T>(key: string, data: T, ttl = 3600) {
    this.store.set(key, { data, timestamp: Date.now(), ttl: ttl * 1000 });
  }

  get<T>(key: string): T | null {
    const e = this.store.get(key);
    if (!e) return null;
    if (Date.now() - e.timestamp > e.ttl) { this.store.delete(key); return null; }
    return e.data as T;
  }

  delete(key: string) { this.store.delete(key); }

  invalidatePattern(pattern: string) {
    const re = new RegExp(pattern);
    for (const k of this.store.keys()) { if (re.test(k)) this.store.delete(k); }
  }
}

export const cache = new SimpleCache();
```

キャッシュ統合パターン（GET でヒット確認 → PUT で無効化）:

```typescript
// GET: キャッシュ確認 → DB → キャッシュ保存
const cached = cache.get(cacheKey);
if (cached) return sendSuccess(res, cached);
// ...DB クエリ後...
cache.set(cacheKey, record, config.CACHE_TTL);

// PUT: DB 更新後にキャッシュ無効化
cache.delete(`${tableName}:${id}`);
cache.invalidatePattern(`${tableName}:.*with.*`); // リレーション結合クエリも無効化
```

### ページネーション（src/utils/pagination.ts）

```typescript
import { Request } from 'express';

export interface PaginationParams { page: number; limit: number; offset: number; }
export interface PaginationMeta {
  page: number; limit: number; total: number;
  totalPages: number; hasNext: boolean; hasPrev: boolean;
}

export const parsePaginationParams = (req: Request): PaginationParams => {
  const page = Math.max(1, parseInt(req.query.page as string) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit as string) || 10));
  return { page, limit, offset: (page - 1) * limit };
};

export const buildPaginationMeta = (total: number, p: PaginationParams): PaginationMeta => {
  const totalPages = Math.ceil(total / p.limit);
  return { page: p.page, limit: p.limit, total, totalPages,
    hasNext: p.page < totalPages, hasPrev: p.page > 1 };
};
```

### 全文検索（PostgreSQL FTS + GIN インデックス）

生成列で `tsvector` を自動管理し、GIN インデックスで高速化する。

```typescript
// src/db/schema.ts に追加
import { sql } from 'drizzle-orm';

export const posts = pgTable('posts', {
  // ...既存フィールド,
  searchVector: sql`tsvector GENERATED ALWAYS AS (
    to_tsvector('english', title || ' ' || content)
  ) STORED`
}, (t) => ({
  searchIdx: index('search_idx').using('gin', t.searchVector)
}));

// src/api/search.ts
app.get('/search/posts', async (req, res) => {
  const { q } = req.query;
  if (!q || typeof q !== 'string') return sendError(res, 'q is required', 400);
  const p = parsePaginationParams(req);
  const condition = sql`${posts.searchVector} @@ plainto_tsquery('english', ${q})`;
  const results = await db.select().from(posts).where(condition).limit(p.limit).offset(p.offset);
  const [{ count }] = await db.select({ count: sql<number>`count(*)` }).from(posts).where(condition);
  sendSuccess(res, results, 200, buildPaginationMeta(count, p));
});
```

---

## セキュリティ（認証・検証・レート制限）

### 認証ミドルウェア（src/middleware/auth.ts）

> ⚠️ **AskUserQuestion**: 認証方式（JWT / セッション / OAuth2）はプロジェクト要件に依存する。実プロジェクトでは必ず確認すること。

```typescript
import { Request, Response, NextFunction } from 'express';
import { sendError } from '../utils/responses';

interface AuthRequest extends Request { userId?: number; }

export const authenticate = async (
  req: AuthRequest, res: Response, next: NextFunction
): Promise<void> => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) { sendError(res, 'Authentication required', 401); return; }
  // 実装: jsonwebtoken 等で検証し userId を抽出
  const userId = verifyToken(token); // 要実装
  if (!userId) { sendError(res, 'Invalid token', 401); return; }
  req.userId = userId;
  next();
};

// /api プレフィックス以下を保護
app.use('/api', authenticate);
```

### Zod による入力検証（全外部入力を検証すること）

クライアントからのデータは必ず検証する。`req.body` を直接 DB に渡してはならない。

```typescript
// src/validation/schemas.ts
import { z } from 'zod';

export const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(255),
  bio: z.string().max(1000).optional()
});
export const updateUserSchema = createUserSchema.partial();

export const createPostSchema = z.object({
  title: z.string().min(1).max(255),
  content: z.string().min(1),
  published: z.boolean().default(false),
  authorId: z.number().int().positive()
});
export const updatePostSchema = createPostSchema.partial();

// src/middleware/validate.ts
import { ZodSchema } from 'zod';

export const validate = (schema: ZodSchema) =>
  (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      const messages = result.error.errors.map(e => `${e.path.join('.')}: ${e.message}`).join(', ');
      sendError(res, `Validation failed: ${messages}`, 400);
      return;
    }
    req.body = result.data;
    next();
  };

// 使用例
app.post(`/${tableName}`, validate(createUserSchema), async (req, res) => { /* ... */ });
```

### レート制限（src/middleware/rateLimit.ts）

```typescript
import rateLimit from 'express-rate-limit';

// API 全体: 15分間に100リクエスト
export const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, max: 100,
  message: 'Too many requests, please try again later',
  standardHeaders: true, legacyHeaders: false
});

// 認証エンドポイント: 1分間に10リクエスト（ブルートフォース対策）
export const strictLimiter = rateLimit({ windowMs: 60 * 1000, max: 10 });

app.use('/api', apiLimiter);
app.use('/auth', strictLimiter);
```

---

## ORM 選択ガイド

> ⚠️ **AskUserQuestion**: ORM 選択はプロジェクト要件に依存する。以下の基準を参考にユーザーに確認すること。

| 観点 | Drizzle ORM | Prisma | 生 SQL |
|---|---|---|---|
| 型安全性 | スキーマ → TypeScript 型を自動推論 | `schema.prisma` → 生成 | 手動定義 |
| マイグレーション | `drizzle-kit generate/migrate` | `prisma migrate dev` | 手動 SQL |
| バンドルサイズ | 軽量（ランタイム小） | 重い（Prisma Engine 同梱） | 最小 |
| 動的クエリ | 得意（スキーマ API で構築） | 制約あり | 得意 |
| 学習コスト | 中（SQL 知識が活きる） | 低（宣言的 DSL） | 高 |
| 適用場面 | TypeScript-first・動的 API 生成 | 迅速なプロトタイプ | 極限性能 |
