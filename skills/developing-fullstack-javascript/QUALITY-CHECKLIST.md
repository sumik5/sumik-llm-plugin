# 品質・セキュリティ・デバッグチェックリスト

> O'Reilly書籍「Full Stack JavaScript Strategies: The Hidden Parts Every Mid-Level Developer Needs to Know」(2025, Milecia McGregor著) に基づく、フルスタックJavaScriptアプリケーションの品質保証チェックリスト。レビュー時に直接使用できる実践的なフォーマットで構成。

## 目次

1. [バックエンド品質チェック](#1-バックエンド品質チェック)
2. [フロントエンド品質チェック](#2-フロントエンド品質チェック)
3. [セキュリティチェック](#3-セキュリティチェック)
4. [パフォーマンスチェック](#4-パフォーマンスチェック)
5. [デバッグ体系的アプローチ](#5-デバッグ体系的アプローチ)

---

## 1. バックエンド品質チェック

> バックエンドの品質は、API設計の一貫性、データベースの健全性、環境管理の厳密さ、バックグラウンド処理の信頼性、そして認証・認可の堅牢性によって決まる。

### 1.1 API設計レビュー

#### RESTful規約

- [ ] リソースは複数形の名詞で命名されている（`/users`、`/orders`）
- [ ] HTTPメソッドが正しく使い分けられている（GET=取得、POST=作成、PUT=全体更新、PATCH=部分更新、DELETE=削除）
- [ ] ネストしたリソースは2階層以内に収まっている（`/users/:id/orders` まで）
- [ ] フィルタリング・ソート・ページネーションはクエリパラメータで実装されている
- [ ] レスポンスに適切なHTTPステータスコードが使用されている

```typescript
// ステータスコード対応表
const HTTP_STATUS = {
  200: 'OK - 取得・更新成功',
  201: 'Created - リソース作成成功',
  204: 'No Content - 削除成功',
  400: 'Bad Request - リクエスト不正',
  401: 'Unauthorized - 認証が必要',
  403: 'Forbidden - 権限不足',
  404: 'Not Found - リソースが存在しない',
  409: 'Conflict - リソースの競合',
  422: 'Unprocessable Entity - バリデーションエラー',
  429: 'Too Many Requests - レート制限超過',
  500: 'Internal Server Error - サーバーエラー',
} as const;
```

#### APIバージョニング

- [ ] バージョニング戦略が統一されている（URLパス `/v1/` またはヘッダー `Accept: application/vnd.api+json;version=1`）
- [ ] 旧バージョンの廃止ポリシーが定義されている
- [ ] バージョン間の互換性が明記されている

```typescript
// URLパス方式（推奨）
// GET /api/v1/users
// GET /api/v2/users

// NestJSでのバージョニング
import { VersioningType } from '@nestjs/common';

app.enableVersioning({
  type: VersioningType.URI,
  defaultVersion: '1',
});

@Controller('users')
export class UsersController {
  @Version('1')
  @Get()
  findAllV1(): UserV1[] { /* v1の実装 */ }

  @Version('2')
  @Get()
  findAllV2(): UserV2[] { /* v2の実装 */ }
}
```

#### エラーレスポンス形式の統一

- [ ] エラーレスポンスの構造が全エンドポイントで統一されている
- [ ] エラーコード体系が定義されている（アプリケーション固有のコード）
- [ ] クライアントが解析できる構造化されたエラー情報を返している
- [ ] スタックトレースが本番環境で露出していない

```typescript
// 統一エラーレスポンス型
interface ApiError {
  status: number;
  code: string;           // アプリケーション固有のエラーコード
  message: string;        // 人間が読めるメッセージ
  details?: ErrorDetail[]; // バリデーションエラーの詳細
  timestamp: string;
  path: string;
}

interface ErrorDetail {
  field: string;
  message: string;
  value?: unknown;
}

// NestJS グローバル例外フィルター
import { ExceptionFilter, Catch, ArgumentsHost, HttpException } from '@nestjs/common';
import { Request, Response } from 'express';

@Catch(HttpException)
export class GlobalExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const status = exception.getStatus();

    const errorResponse: ApiError = {
      status,
      code: this.mapStatusToCode(status),
      message: exception.message,
      timestamp: new Date().toISOString(),
      path: request.url,
    };

    response.status(status).json(errorResponse);
  }

  private mapStatusToCode(status: number): string {
    const codeMap: Record<number, string> = {
      400: 'BAD_REQUEST',
      401: 'UNAUTHORIZED',
      403: 'FORBIDDEN',
      404: 'NOT_FOUND',
      409: 'CONFLICT',
      422: 'VALIDATION_ERROR',
      429: 'RATE_LIMIT_EXCEEDED',
      500: 'INTERNAL_ERROR',
    };
    return codeMap[status] ?? 'UNKNOWN_ERROR';
  }
}
```

### 1.2 データベース接続・設計

#### コネクションプール設定

- [ ] コネクションプールサイズが適切に設定されている（デフォルト値を使用していない）
- [ ] コネクションのタイムアウトが設定されている
- [ ] アイドルコネクションの回収が設定されている
- [ ] コネクションリーク検知が有効になっている

```typescript
// TypeORM コネクションプール設定
import { DataSource } from 'typeorm';

const dataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  username: process.env.DB_USERNAME,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  // コネクションプール設定
  extra: {
    max: 20,                    // 最大コネクション数
    min: 5,                     // 最小コネクション数
    idleTimeoutMillis: 30000,   // アイドルタイムアウト（30秒）
    connectionTimeoutMillis: 5000, // 接続タイムアウト（5秒）
  },
});

// Prisma コネクションプール設定
// schema.prisma
// datasource db {
//   provider = "postgresql"
//   url      = env("DATABASE_URL")
//   // connection_limit = 20
// }
```

#### マイグレーション状態

- [ ] すべてのマイグレーションが適用されている（ペンディングがない）
- [ ] マイグレーションファイルがバージョン管理されている
- [ ] ロールバックマイグレーションが用意されている
- [ ] 本番データベースへのマイグレーション手順が文書化されている
- [ ] データ破壊的マイグレーション（カラム削除、型変更）にセーフティネットがある

#### インデックス最適化

- [ ] WHERE句で頻繁に使用されるカラムにインデックスが設定されている
- [ ] 複合インデックスのカラム順序が最適化されている（カーディナリティの高い順）
- [ ] 未使用のインデックスが特定・削除されている
- [ ] EXPLAIN/EXPLAIN ANALYZEで主要クエリの実行計画が確認されている

```sql
-- インデックス使用状況の確認（PostgreSQL）
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,      -- インデックスが使用された回数
  idx_tup_read,  -- インデックスから読まれた行数
  idx_tup_fetch  -- テーブルから取得された行数
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC; -- 使用頻度が低い順

-- 実行計画の確認
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';
```

### 1.3 環境変数管理

- [ ] 環境変数がハードコードされていない
- [ ] `.env`ファイルが`.gitignore`に含まれている
- [ ] 環境ごとに`.env`ファイルが分離されている（`.env.development`、`.env.test`、`.env.production`）
- [ ] 必須環境変数のバリデーションが起動時に実行される
- [ ] 本番環境の機密情報はSecretsマネージャーで管理されている

```typescript
// 環境変数バリデーション（zod使用）
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  JWT_EXPIRES_IN: z.string().default('15m'),
  REDIS_URL: z.string().url().optional(),
  AWS_REGION: z.string().optional(),
  SENTRY_DSN: z.string().url().optional(),
});

type Env = z.infer<typeof envSchema>;

function validateEnv(): Env {
  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    console.error('環境変数バリデーションエラー:');
    for (const issue of result.error.issues) {
      console.error(`  ${issue.path.join('.')}: ${issue.message}`);
    }
    process.exit(1);
  }
  return result.data;
}

export const env = validateEnv();
```

#### Secretsマネージャー活用

| 環境 | 推奨ツール |
|------|-----------|
| AWS | AWS Secrets Manager、Parameter Store |
| GCP | Secret Manager |
| Azure | Key Vault |
| Kubernetes | Kubernetes Secrets + External Secrets Operator |
| ローカル開発 | `.env`ファイル + dotenv |

### 1.4 バックグラウンドジョブ動作確認

- [ ] ジョブキューシステムが導入されている（BullMQ、Agenda等）
- [ ] ジョブのリトライ回数と間隔が設定されている
- [ ] デッドレターキュー（DLQ）が設定されている
- [ ] ジョブの実行状態がモニタリング可能である
- [ ] ジョブの冪等性が保証されている（同じジョブが複数回実行されても安全）
- [ ] ジョブのタイムアウトが設定されている

```typescript
// BullMQ ジョブキュー設定
import { Queue, Worker, QueueEvents } from 'bullmq';
import IORedis from 'ioredis';

const connection = new IORedis(process.env.REDIS_URL);

// キュー作成
const emailQueue = new Queue('email', {
  connection,
  defaultJobOptions: {
    attempts: 3,                // 最大3回リトライ
    backoff: {
      type: 'exponential',     // 指数バックオフ
      delay: 2000,             // 初回2秒
    },
    removeOnComplete: {
      age: 24 * 3600,          // 完了ジョブは24時間後に削除
      count: 1000,             // 最大1000件保持
    },
    removeOnFail: {
      age: 7 * 24 * 3600,     // 失敗ジョブは7日後に削除
    },
  },
});

// ワーカー作成
const emailWorker = new Worker('email', async (job) => {
  const { to, subject, body } = job.data;
  // 冪等性キーで重複実行を防止
  const idempotencyKey = `email:${job.id}`;
  const alreadySent = await checkIdempotency(idempotencyKey);
  if (alreadySent) {
    return { status: 'skipped', reason: 'already_sent' };
  }
  await sendEmail(to, subject, body);
  await markAsProcessed(idempotencyKey);
  return { status: 'sent' };
}, {
  connection,
  concurrency: 5,             // 同時実行数
  limiter: {
    max: 100,                 // 最大100件/分
    duration: 60000,
  },
});

// デッドレターキュー監視
const queueEvents = new QueueEvents('email', { connection });
queueEvents.on('failed', ({ jobId, failedReason }) => {
  console.error(`ジョブ失敗 [${jobId}]: ${failedReason}`);
  // アラート通知
});
```

### 1.5 認証・認可の実装確認

- [ ] JWT有効期限が適切に設定されている（アクセストークン: 15分以内、リフレッシュトークン: 7日以内）
- [ ] トークンリフレッシュフローが実装されている
- [ ] リフレッシュトークンのローテーションが実装されている
- [ ] トークン失効（ブラックリスト）メカニズムがある
- [ ] RBAC（Role-Based Access Control）またはABAC（Attribute-Based Access Control）が実装されている
- [ ] パスワードは安全なアルゴリズムでハッシュ化されている（bcrypt、Argon2）
- [ ] ブルートフォース攻撃対策（レート制限、アカウントロック）が実装されている

```typescript
// JWT トークン管理
import { sign, verify, JwtPayload } from 'jsonwebtoken';

interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

interface TokenPayload {
  userId: string;
  role: string;
}

function generateTokenPair(payload: TokenPayload): TokenPair {
  const accessToken = sign(payload, process.env.JWT_SECRET, {
    expiresIn: '15m',         // アクセストークン: 15分
    issuer: 'your-app',
    audience: 'your-app-client',
  });

  const refreshToken = sign(
    { userId: payload.userId, type: 'refresh' },
    process.env.JWT_REFRESH_SECRET,
    {
      expiresIn: '7d',        // リフレッシュトークン: 7日
      issuer: 'your-app',
    },
  );

  return { accessToken, refreshToken };
}

// リフレッシュトークンローテーション
async function refreshAccessToken(oldRefreshToken: string): Promise<TokenPair> {
  // 旧リフレッシュトークンを検証
  const decoded = verify(
    oldRefreshToken,
    process.env.JWT_REFRESH_SECRET,
  ) as JwtPayload & { userId: string };

  // 旧トークンをブラックリストに追加（再利用防止）
  await blacklistToken(oldRefreshToken);

  // ユーザー情報を取得して新しいトークンペアを生成
  const user = await findUserById(decoded.userId);
  return generateTokenPair({ userId: user.id, role: user.role });
}

// RBAC ガード（NestJS）
import { CanActivate, ExecutionContext, Injectable, SetMetadata } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredRoles) return true;

    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.includes(user.role);
  }
}

// 使用例
@Controller('admin')
@UseGuards(AuthGuard, RolesGuard)
export class AdminController {
  @Roles('admin')
  @Get('dashboard')
  getDashboard() { /* 管理者のみアクセス可能 */ }
}
```

---

## 2. フロントエンド品質チェック

> フロントエンドの品質は、ユーザー体験に直結する。フォームの操作感、ブラウザ互換性、レスポンシブ対応、コンポーネントの堅牢性、そして状態管理の最適化がすべて揃って初めて高品質と言える。

### 2.1 フォーム動作チェック

- [ ] クライアントサイドバリデーションが実装されている
- [ ] バリデーションエラーがフィールドごとに表示される
- [ ] サーバーサイドバリデーションエラーが適切にマッピングされている
- [ ] サブミット中の二重送信防止が実装されている
- [ ] サブミット後のフォーム状態がリセットされる（または適切な状態に遷移する）
- [ ] フォーム入力値が意図せず消失しない（ページ離脱時の確認ダイアログ等）
- [ ] キーボード操作（Tab移動、Enterサブミット）が正常に機能する

```typescript
// React Hook Form + Zod によるフォーム実装
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const userSchema = z.object({
  name: z.string().min(1, '名前は必須です').max(100, '100文字以内で入力してください'),
  email: z.string().email('有効なメールアドレスを入力してください'),
  password: z
    .string()
    .min(8, '8文字以上で入力してください')
    .regex(/[A-Z]/, '大文字を1文字以上含めてください')
    .regex(/[0-9]/, '数字を1文字以上含めてください'),
});

type UserFormData = z.infer<typeof userSchema>;

function UserForm() {
  const {
    register,
    handleSubmit,
    reset,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<UserFormData>({
    resolver: zodResolver(userSchema),
  });

  const onSubmit = async (data: UserFormData) => {
    try {
      await createUser(data);
      reset(); // サブミット後にリセット
    } catch (error) {
      if (error instanceof ApiError && error.details) {
        // サーバーサイドバリデーションエラーのマッピング
        for (const detail of error.details) {
          setError(detail.field as keyof UserFormData, {
            message: detail.message,
          });
        }
      }
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <div>
        <label htmlFor="name">名前</label>
        <input id="name" {...register('name')} aria-invalid={!!errors.name} />
        {errors.name && <span role="alert">{errors.name.message}</span>}
      </div>

      <div>
        <label htmlFor="email">メールアドレス</label>
        <input id="email" type="email" {...register('email')} aria-invalid={!!errors.email} />
        {errors.email && <span role="alert">{errors.email.message}</span>}
      </div>

      <div>
        <label htmlFor="password">パスワード</label>
        <input id="password" type="password" {...register('password')} aria-invalid={!!errors.password} />
        {errors.password && <span role="alert">{errors.password.message}</span>}
      </div>

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? '送信中...' : '登録'}
      </button>
    </form>
  );
}
```

### 2.2 ブラウザ互換性

- [ ] 対応ブラウザリストが定義されている（`.browserslistrc`または`package.json`）
- [ ] 必要なポリフィルが導入されている（`core-js`等）
- [ ] CSS Autoprefixer が設定されている
- [ ] 主要ブラウザ（Chrome、Firefox、Safari、Edge）でテスト済み
- [ ] モバイルブラウザ（iOS Safari、Android Chrome）でテスト済み

```json
// package.json
{
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
```

```javascript
// postcss.config.js
module.exports = {
  plugins: {
    autoprefixer: {},
    'postcss-preset-env': {
      stage: 2,
      features: {
        'nesting-rules': true,
      },
    },
  },
};
```

### 2.3 レスポンシブデザイン

- [ ] ブレークポイントが体系的に定義されている
- [ ] モバイルファーストで設計されている
- [ ] タッチデバイス対応（最小タッチターゲットサイズ 44x44px）
- [ ] ビューポートメタタグが設定されている
- [ ] 画像がレスポンシブ対応している（`srcset`、`sizes`、または`next/image`）
- [ ] テキストが極端に小さくならない（最小フォントサイズ 14px）

| ブレークポイント | 幅 | 対応デバイス |
|-----------------|-----|-------------|
| `sm` | 640px | モバイル（横向き） |
| `md` | 768px | タブレット |
| `lg` | 1024px | ノートPC |
| `xl` | 1280px | デスクトップ |
| `2xl` | 1536px | 大画面モニター |

```css
/* モバイルファースト設計 */
.container {
  padding: 1rem;
  width: 100%;
}

/* タブレット以上 */
@media (min-width: 768px) {
  .container {
    padding: 2rem;
    max-width: 768px;
    margin: 0 auto;
  }
}

/* デスクトップ以上 */
@media (min-width: 1024px) {
  .container {
    max-width: 1024px;
  }
}
```

### 2.4 コンポーネント品質

- [ ] props の型定義が明確で、必須/任意が適切に設定されている
- [ ] デフォルトpropsが適切に設定されている
- [ ] Error Boundary が重要なコンポーネントツリーに配置されている
- [ ] ローディング状態とエラー状態のUIが実装されている
- [ ] アクセシビリティ属性（`aria-*`、`role`、セマンティックHTML）が適用されている
- [ ] コンポーネントが単一責任の原則に従っている

```typescript
// Error Boundary 実装
import { Component, ErrorInfo, ReactNode } from 'react';

interface ErrorBoundaryProps {
  children: ReactNode;
  fallback: ReactNode | ((error: Error) => ReactNode);
  onError?: (error: Error, errorInfo: ErrorInfo) => void;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    this.props.onError?.(error, errorInfo);
    // エラーレポートサービスに送信
    reportError(error, errorInfo);
  }

  render(): ReactNode {
    if (this.state.hasError && this.state.error) {
      const { fallback } = this.props;
      return typeof fallback === 'function'
        ? fallback(this.state.error)
        : fallback;
    }
    return this.props.children;
  }
}

// 使用例
function App() {
  return (
    <ErrorBoundary
      fallback={(error) => (
        <div role="alert">
          <h2>エラーが発生しました</h2>
          <p>{error.message}</p>
          <button onClick={() => window.location.reload()}>
            ページをリロード
          </button>
        </div>
      )}
      onError={(error) => console.error('Caught:', error)}
    >
      <MainContent />
    </ErrorBoundary>
  );
}
```

### 2.5 状態管理確認

- [ ] 不要なre-renderが発生していない（React DevToolsのHighlight updatesで確認）
- [ ] `useMemo`、`useCallback`が適切に使用されている（過剰使用していない）
- [ ] メモリリークが発生していない（useEffectのクリーンアップ関数が実装されている）
- [ ] グローバルストアが適切に設計されている（不要なデータがグローバルに保持されていない）
- [ ] サーバー状態（API応答）とクライアント状態（UI状態）が分離されている

```typescript
// メモリリーク防止パターン
import { useEffect, useState } from 'react';

function useSubscription(channelId: string) {
  const [messages, setMessages] = useState<Message[]>([]);

  useEffect(() => {
    const ws = new WebSocket(`wss://api.example.com/channels/${channelId}`);

    ws.onmessage = (event) => {
      const message: Message = JSON.parse(event.data);
      setMessages((prev) => [...prev, message]);
    };

    // クリーンアップ関数で必ずWebSocketを閉じる
    return () => {
      ws.close();
    };
  }, [channelId]);

  return messages;
}

// 不要なre-render防止
import { memo, useCallback, useMemo } from 'react';

interface ItemListProps {
  items: Item[];
  onSelect: (id: string) => void;
}

const ItemList = memo(function ItemList({ items, onSelect }: ItemListProps) {
  const sortedItems = useMemo(
    () => [...items].sort((a, b) => a.name.localeCompare(b.name)),
    [items],
  );

  return (
    <ul>
      {sortedItems.map((item) => (
        <li key={item.id}>
          <button onClick={() => onSelect(item.id)}>{item.name}</button>
        </li>
      ))}
    </ul>
  );
});

// 親コンポーネント
function Parent() {
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const handleSelect = useCallback((id: string) => {
    setSelectedId(id);
  }, []);

  return <ItemList items={items} onSelect={handleSelect} />;
}
```

---

## 3. セキュリティチェック

> セキュリティは後付けではなく、設計段階から組み込むもの。OWASP Top 10を基準とした体系的なチェックを、開発サイクルのすべてのフェーズで実施する。

### 3.1 OWASP Top 10 対策チェックリスト（2021年版）

#### A01:2021 - Broken Access Control（アクセス制御の不備）

- [ ] 最小権限の原則が適用されている（デフォルトで全拒否）
- [ ] サーバーサイドでアクセス制御を実施している（クライアントサイドのみに依存していない）
- [ ] CORS設定が最小限に制限されている
- [ ] ディレクトリリスティングが無効化されている
- [ ] JWT等のトークンがログアウト時に無効化される
- [ ] レート制限が実装されている

```typescript
// CORS設定（NestJS）
import { NestFactory } from '@nestjs/core';

const app = await NestFactory.create(AppModule);
app.enableCors({
  origin: ['https://your-domain.com'],  // ワイルドカード '*' は避ける
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
  maxAge: 86400, // preflight キャッシュ: 24時間
});
```

#### A02:2021 - Cryptographic Failures（暗号化の失敗）

- [ ] 通信がTLS 1.2以上で暗号化されている（HTTPS必須）
- [ ] パスワードが安全なアルゴリズムでハッシュ化されている（bcrypt: cost 10以上、Argon2推奨）
- [ ] 機密データが平文で保存されていない
- [ ] 暗号化キーが安全に管理されている（ハードコードされていない）
- [ ] 廃止された暗号化アルゴリズム（MD5、SHA-1）を使用していない

#### A03:2021 - Injection（インジェクション）

- [ ] SQLクエリにプリペアドステートメント/パラメータバインディングを使用している
- [ ] ORM/クエリビルダーを使用している（生のSQLを避ける）
- [ ] ユーザー入力がHTMLに出力される際にエスケープされている
- [ ] NoSQLインジェクション対策が実装されている
- [ ] OSコマンドインジェクション対策が実装されている

```typescript
// SQLインジェクション対策
// ❌ 危険: 文字列連結
const query = `SELECT * FROM users WHERE email = '${email}'`;

// ✅ 安全: プリペアドステートメント
const query = 'SELECT * FROM users WHERE email = $1';
const result = await pool.query(query, [email]);

// ✅ 安全: ORM使用（Prisma）
const user = await prisma.user.findUnique({
  where: { email },
});

// NoSQLインジェクション対策（MongoDB）
// ❌ 危険: オブジェクトが直接渡される
const user = await User.findOne({ email: req.body.email });

// ✅ 安全: 型チェック + サニタイズ
import mongoSanitize from 'express-mongo-sanitize';
app.use(mongoSanitize()); // $gt, $lt 等の演算子を除去

const email = typeof req.body.email === 'string' ? req.body.email : '';
const user = await User.findOne({ email });
```

#### A04:2021 - Insecure Design（安全でない設計）

- [ ] 脅威モデリングが実施されている
- [ ] セキュリティ要件がユーザーストーリーに含まれている
- [ ] ビジネスロジックに適切な制限が設けられている（送金上限、API呼び出し上限等）
- [ ] 機密操作に再認証が必要とされている

#### A05:2021 - Security Misconfiguration（セキュリティ設定ミス）

- [ ] デフォルトのアカウント・パスワードが変更されている
- [ ] 不要な機能・サービスが無効化されている
- [ ] セキュリティヘッダーが設定されている
- [ ] エラーメッセージがスタックトレース等の内部情報を露出していない
- [ ] 最新のセキュリティパッチが適用されている

```typescript
// セキュリティヘッダー設定（helmet）
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://api.your-domain.com"],
    },
  },
  crossOriginEmbedderPolicy: true,
  crossOriginOpenerPolicy: true,
  crossOriginResourcePolicy: { policy: 'same-site' },
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
  noSniff: true,
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
}));
```

#### A06:2021 - Vulnerable and Outdated Components（脆弱で古いコンポーネント）

- [ ] `npm audit`を定期的に実行している
- [ ] 重大な脆弱性が0件である（`npm audit --audit-level=critical`）
- [ ] Dependabot/Renovate/Snykが設定されている
- [ ] 使用していないパッケージが削除されている
- [ ] パッケージのライセンスが確認されている

```bash
# 脆弱性チェックコマンド
npm audit                          # 脆弱性の一覧表示
npm audit --audit-level=critical   # criticalのみ表示
npm audit fix                      # 自動修正（可能な場合）
npx npm-check-updates -u           # パッケージ更新確認
```

#### A07:2021 - Identification and Authentication Failures（認証の失敗）

- [ ] パスワード強度ポリシーが実装されている（最小8文字、大文字・数字・記号を含む）
- [ ] ブルートフォース攻撃対策（アカウントロックアウト、レート制限）が実装されている
- [ ] MFA（多要素認証）がサポートされている
- [ ] セッション管理が安全に実装されている（セッション固定攻撃対策）
- [ ] パスワードリセットフローが安全に実装されている

```typescript
// レート制限（express-rate-limit）
import rateLimit from 'express-rate-limit';

// ログインエンドポイント用: 厳しいレート制限
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 5,                    // 5回まで
  message: {
    status: 429,
    code: 'RATE_LIMIT_EXCEEDED',
    message: 'ログイン試行回数が上限に達しました。15分後に再試行してください。',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.post('/api/auth/login', loginLimiter, loginController);

// 一般API用: 緩やかなレート制限
const apiLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1分
  max: 100,                 // 100回まで
});

app.use('/api/', apiLimiter);
```

#### A08:2021 - Software and Data Integrity Failures（ソフトウェアとデータの整合性の失敗）

- [ ] CI/CDパイプラインのアクセス制御が適切に設定されている
- [ ] 依存関係のロックファイル（`package-lock.json`、`pnpm-lock.yaml`）がバージョン管理されている
- [ ] サブリソース完全性（SRI）がCDNリソースに適用されている
- [ ] デシリアライゼーション時に入力検証を実施している

#### A09:2021 - Security Logging and Monitoring Failures（セキュリティログと監視の失敗）

- [ ] 認証の成功/失敗がログに記録されている
- [ ] アクセス制御の失敗がログに記録されている
- [ ] ログにユーザーID、IPアドレス、タイムスタンプが含まれている
- [ ] ログに機密情報（パスワード、トークン）が含まれていない
- [ ] 異常検知アラートが設定されている（短時間の大量失敗等）
- [ ] ログの改ざん防止策が実施されている

```typescript
// 構造化ログ（pino）
import pino from 'pino';

const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  redact: {
    paths: ['password', 'token', 'authorization', '*.password', '*.token'],
    censor: '[REDACTED]',
  },
  serializers: {
    req: (req) => ({
      method: req.method,
      url: req.url,
      userId: req.user?.id,
      ip: req.ip,
    }),
  },
});

// 認証ログ
function logAuthEvent(event: 'login_success' | 'login_failure' | 'logout', userId: string, ip: string): void {
  logger.info({
    event,
    userId,
    ip,
    timestamp: new Date().toISOString(),
  }, `認証イベント: ${event}`);
}
```

#### A10:2021 - Server-Side Request Forgery (SSRF)

- [ ] ユーザー入力のURLを直接フェッチしていない
- [ ] 許可するURLのホワイトリストが設定されている
- [ ] 内部ネットワーク（`127.0.0.1`、`10.0.0.0/8`、`172.16.0.0/12`、`192.168.0.0/16`）へのアクセスがブロックされている
- [ ] リダイレクトの追従が制限されている
- [ ] DNS再バインディング攻撃対策が実施されている

```typescript
// SSRF対策: URLバリデーション
import { URL } from 'url';
import { isIP } from 'net';

const BLOCKED_HOSTS = [
  '127.0.0.1', 'localhost', '0.0.0.0',
  '169.254.169.254', // AWS メタデータエンドポイント
  'metadata.google.internal', // GCP メタデータ
];

const BLOCKED_CIDRS = [
  '10.0.0.0/8',
  '172.16.0.0/12',
  '192.168.0.0/16',
  '127.0.0.0/8',
];

function isUrlSafe(urlString: string): boolean {
  try {
    const url = new URL(urlString);

    // プロトコル制限
    if (!['http:', 'https:'].includes(url.protocol)) return false;

    // ブロックされたホスト名
    if (BLOCKED_HOSTS.includes(url.hostname)) return false;

    // IPアドレスの場合、プライベートレンジをチェック
    if (isIP(url.hostname)) {
      return !isPrivateIP(url.hostname);
    }

    return true;
  } catch {
    return false;
  }
}
```

### 3.2 入力検証

- [ ] サーバーサイドで全ユーザー入力をバリデーションしている（クライアントサイドだけでは不十分）
- [ ] バリデーションスキーマが定義されている（zod、Joi、class-validator等）
- [ ] ファイルアップロードの型・サイズ・内容がバリデーションされている
- [ ] HTMLサニタイズ（DOMPurify）が適用されている
- [ ] パスの正規化とトラバーサル防止が実施されている

```typescript
// リクエストバリデーション（zod + Express）
import { z } from 'zod';
import { Request, Response, NextFunction } from 'express';

const createUserSchema = z.object({
  body: z.object({
    name: z.string().min(1).max(100).trim(),
    email: z.string().email().toLowerCase(),
    age: z.number().int().min(0).max(150).optional(),
  }),
  params: z.object({}),
  query: z.object({}),
});

type ValidatedRequest<T extends z.ZodType> = Request & {
  validated: z.infer<T>;
};

function validate<T extends z.ZodType>(schema: T) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse({
      body: req.body,
      params: req.params,
      query: req.query,
    });

    if (!result.success) {
      res.status(422).json({
        status: 422,
        code: 'VALIDATION_ERROR',
        message: 'バリデーションエラー',
        details: result.error.issues.map((issue) => ({
          field: issue.path.join('.'),
          message: issue.message,
        })),
      });
      return;
    }

    (req as ValidatedRequest<T>).validated = result.data;
    next();
  };
}

// ファイルアップロードバリデーション
const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

function validateFile(file: Express.Multer.File): boolean {
  if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) return false;
  if (file.size > MAX_FILE_SIZE) return false;
  return true;
}
```

### 3.3 依存関係セキュリティ

- [ ] `npm audit`の結果がCI/CDパイプラインでチェックされている
- [ ] Dependabot/Renovateが有効化されている
- [ ] ロックファイルのintegrity hashが検証されている
- [ ] プライベートレジストリを使用している場合、認証が適切に設定されている

```yaml
# GitHub Actions: 依存関係セキュリティチェック
name: Security Audit
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 0 * * 1' # 毎週月曜日

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm audit --audit-level=high
      - name: Snyk Security Check
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

---

## 4. パフォーマンスチェック

> パフォーマンスはユーザー体験の基盤である。Core Web Vitalsの達成、効果的なキャッシュ戦略、最適なバンドルサイズ、効率的なクエリ実行、そして迅速なAPI応答がすべて一体となって優れたパフォーマンスを実現する。

### 4.1 Core Web Vitals メトリクス

| メトリクス | 閾値（良好） | 閾値（要改善） | 測定対象 |
|-----------|-------------|---------------|---------|
| **LCP** (Largest Contentful Paint) | < 2.5秒 | < 4.0秒 | 最大コンテンツの表示時間 |
| **FID** (First Input Delay) | < 100ms | < 300ms | 初回入力の応答遅延 |
| **CLS** (Cumulative Layout Shift) | < 0.1 | < 0.25 | レイアウトの視覚的安定性 |
| **INP** (Interaction to Next Paint) | < 200ms | < 500ms | インタラクション応答性（FIDの後継） |
| **TTFB** (Time to First Byte) | < 800ms | < 1800ms | サーバー応答時間 |

- [ ] LCPが2.5秒以内に収まっている
- [ ] FID/INPが200ms以内に収まっている
- [ ] CLSが0.1以内に収まっている
- [ ] TTFBが800ms以内に収まっている
- [ ] Lighthouseスコアが90以上である（Performance）
- [ ] 画像が最適化されている（WebP/AVIF、適切なサイズ、lazy loading）
- [ ] フォントの読み込みが最適化されている（`font-display: swap`、プリロード）

```typescript
// Core Web Vitals の測定（web-vitals ライブラリ）
import { onLCP, onFID, onCLS, onINP, onTTFB, type Metric } from 'web-vitals';

function reportMetric(metric: Metric): void {
  // アナリティクスに送信
  const body = JSON.stringify({
    name: metric.name,
    value: metric.value,
    rating: metric.rating, // 'good' | 'needs-improvement' | 'poor'
    delta: metric.delta,
    id: metric.id,
    navigationType: metric.navigationType,
  });

  // Beacon API で非同期送信（ページ離脱時もデータを送信可能）
  if (navigator.sendBeacon) {
    navigator.sendBeacon('/api/analytics/web-vitals', body);
  }
}

onLCP(reportMetric);
onFID(reportMetric);
onCLS(reportMetric);
onINP(reportMetric);
onTTFB(reportMetric);
```

### 4.2 キャッシュ設定

#### ブラウザキャッシュ

- [ ] 静的アセットに適切なCache-Controlヘッダーが設定されている
- [ ] ファイル名にコンテンツハッシュが含まれている（キャッシュバスティング）
- [ ] HTML/APIレスポンスにno-cacheまたは短いmax-ageが設定されている

| リソース | Cache-Control | 理由 |
|---------|--------------|------|
| HTML | `no-cache` | 常に最新を取得 |
| JS/CSS（ハッシュ付き） | `public, max-age=31536000, immutable` | 1年間キャッシュ |
| 画像（ハッシュ付き） | `public, max-age=31536000, immutable` | 1年間キャッシュ |
| API レスポンス | `private, no-cache` または `max-age=60` | 用途に応じて |
| フォント | `public, max-age=31536000, immutable` | 1年間キャッシュ |

#### CDNキャッシュ

- [ ] CDN（CloudFront、Cloudflare等）が静的アセット配信に使用されている
- [ ] CDNのキャッシュポリシーが適切に設定されている
- [ ] キャッシュ無効化（パージ）手順が文書化されている

#### アプリケーションキャッシュ

- [ ] Redis等のキャッシュレイヤーが頻繁にアクセスされるデータに適用されている
- [ ] キャッシュのTTL（有効期限）が適切に設定されている
- [ ] キャッシュの無効化戦略（Write-Through、Write-Behind、Cache-Aside）が明確に定義されている
- [ ] キャッシュのヒット率がモニタリングされている

```typescript
// Cache-Aside パターン（Redis）
import { Redis } from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

async function getCachedData<T>(
  key: string,
  fetchFn: () => Promise<T>,
  ttlSeconds: number = 300,
): Promise<T> {
  // 1. キャッシュを確認
  const cached = await redis.get(key);
  if (cached) {
    return JSON.parse(cached) as T;
  }

  // 2. キャッシュミス: データソースから取得
  const data = await fetchFn();

  // 3. キャッシュに保存
  await redis.setex(key, ttlSeconds, JSON.stringify(data));

  return data;
}

// 使用例
const user = await getCachedData(
  `user:${userId}`,
  () => prisma.user.findUniqueOrThrow({ where: { id: userId } }),
  600, // 10分間キャッシュ
);

// キャッシュ無効化
async function invalidateUserCache(userId: string): Promise<void> {
  await redis.del(`user:${userId}`);
  // 関連キャッシュも一括削除
  const keys = await redis.keys(`user:${userId}:*`);
  if (keys.length > 0) {
    await redis.del(...keys);
  }
}
```

### 4.3 バンドルサイズ

- [ ] Tree-shakingが有効になっている（ESモジュール使用）
- [ ] コード分割（Code Splitting）が実装されている
- [ ] 動的import（`React.lazy`、`import()`）が適切に使用されている
- [ ] 不要な依存関係が除去されている
- [ ] バンドルサイズの予算が設定されている
- [ ] Bundle Analyzerでバンドル構成が分析されている

```typescript
// コード分割と動的import（React）
import { lazy, Suspense } from 'react';

// ルートレベルのコード分割
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Settings = lazy(() => import('./pages/Settings'));
const Analytics = lazy(() => import('./pages/Analytics'));

function App() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/analytics" element={<Analytics />} />
      </Routes>
    </Suspense>
  );
}

// 重いライブラリの動的import
async function generatePDF(data: ReportData): Promise<Blob> {
  // PDFライブラリを使用時のみロード
  const { jsPDF } = await import('jspdf');
  const doc = new jsPDF();
  doc.text(data.title, 10, 10);
  return doc.output('blob');
}
```

```javascript
// バンドルサイズ予算（webpack）
// webpack.config.js
module.exports = {
  performance: {
    maxAssetSize: 250000,     // 250KB
    maxEntrypointSize: 500000, // 500KB
    hints: 'error',            // 超過時にビルドエラー
  },
};

// Next.js の場合
// next.config.js
module.exports = {
  experimental: {
    bundlePagesExternals: true,
  },
};
```

### 4.4 データベースクエリ最適化

- [ ] N+1問題が発生していない（関連データのEager/Batch Loading）
- [ ] 適切なインデックスが設定されている
- [ ] クエリプランが確認されている（EXPLAIN ANALYZE）
- [ ] 不要なカラムの取得を避けている（`SELECT *` を避ける）
- [ ] ページネーションが実装されている（大量データの一括取得を防止）
- [ ] スロークエリのログが有効になっている

```typescript
// N+1問題の検出と解決（Prisma）

// ❌ N+1問題: ユーザーごとに投稿を個別にクエリ
const users = await prisma.user.findMany();
for (const user of users) {
  const posts = await prisma.post.findMany({
    where: { authorId: user.id },
  }); // N回のクエリが発生
}

// ✅ 解決: includeでEager Loading
const users = await prisma.user.findMany({
  include: {
    posts: {
      select: {
        id: true,
        title: true,
        createdAt: true,
      },
    },
  },
});

// ✅ ページネーション（カーソルベース推奨）
const posts = await prisma.post.findMany({
  take: 20,
  skip: 1,
  cursor: { id: lastPostId },
  orderBy: { createdAt: 'desc' },
  select: {
    id: true,
    title: true,
    createdAt: true,
  },
});
```

### 4.5 API応答時間

| メトリクス | 閾値（良好） | 閾値（要注意） | 閾値（危険） |
|-----------|-------------|---------------|-------------|
| **p50** (中央値) | < 100ms | < 300ms | > 500ms |
| **p95** | < 500ms | < 1000ms | > 2000ms |
| **p99** | < 1000ms | < 3000ms | > 5000ms |
| **タイムアウト** | 30秒 | - | - |

- [ ] API応答時間のp50/p95/p99をモニタリングしている
- [ ] タイムアウト設定がクライアントとサーバーの両方に設定されている
- [ ] スロークエリアラートが設定されている
- [ ] レスポンスの圧縮（gzip/brotli）が有効になっている

```typescript
// API応答時間の測定ミドルウェア
import { Request, Response, NextFunction } from 'express';

function responseTimeMiddleware(req: Request, res: Response, next: NextFunction): void {
  const start = process.hrtime.bigint();

  res.on('finish', () => {
    const end = process.hrtime.bigint();
    const durationMs = Number(end - start) / 1_000_000;

    // メトリクス記録
    recordMetric('http_response_time_ms', durationMs, {
      method: req.method,
      path: req.route?.path ?? req.path,
      statusCode: String(res.statusCode),
    });

    // スロークエリアラート（500ms以上）
    if (durationMs > 500) {
      logger.warn({
        message: 'スローAPI検出',
        method: req.method,
        path: req.path,
        durationMs: Math.round(durationMs),
        statusCode: res.statusCode,
      });
    }
  });

  next();
}

// タイムアウト設定
import { Request, Response, NextFunction } from 'express';

function timeoutMiddleware(limitMs: number) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const timeout = setTimeout(() => {
      if (!res.headersSent) {
        res.status(504).json({
          status: 504,
          code: 'GATEWAY_TIMEOUT',
          message: `リクエストが${limitMs}ms以内に完了しませんでした`,
        });
      }
    }, limitMs);

    res.on('finish', () => clearTimeout(timeout));
    next();
  };
}

app.use(timeoutMiddleware(30000)); // 30秒タイムアウト
```

---

## 5. デバッグ体系的アプローチ

> デバッグは技術というより方法論である。体系的なアプローチを持つことで、問題の再現から原因特定、修正、検証までを効率的に進められる。

### 5.1 ログ確認チェックリスト

問題発生時のログ確認は、以下の順序で体系的に行う。

**確認順序: エラーログ → ネットワーク → データベース → アプリケーション**

- [ ] **Step 1: エラーログ確認** - エラーレベル（ERROR、FATAL）のログを最初に確認
- [ ] **Step 2: ネットワークログ確認** - HTTPステータスコード、レスポンスタイム、タイムアウト
- [ ] **Step 3: データベースログ確認** - スロークエリログ、コネクションエラー、デッドロック
- [ ] **Step 4: アプリケーションログ確認** - ビジネスロジックのフロー、状態遷移、ユーザーアクション

```typescript
// ログレベルの使い分け
const LOG_LEVELS = {
  FATAL: '致命的エラー。アプリケーションが停止する場合',
  ERROR: 'エラー。機能が正常に動作しない場合',
  WARN:  '警告。正常だが注意が必要な場合（非推奨API使用、閾値接近等）',
  INFO:  '情報。通常のビジネスイベント（ユーザーログイン、注文完了等）',
  DEBUG: 'デバッグ。開発中の詳細情報（変数値、実行パス等）',
  TRACE: 'トレース。最も詳細な情報（メソッド呼び出しの入出力等）',
} as const;

// 構造化ログのベストプラクティス
import pino from 'pino';

const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
});

// ✅ 良い例: 構造化ログ
logger.error({
  err: error,
  userId: user.id,
  orderId: order.id,
  action: 'payment_processing',
}, '決済処理中にエラーが発生しました');

// ❌ 悪い例: 文字列連結ログ
logger.error(`Error processing payment for user ${userId}: ${error.message}`);
```

### 5.2 ブラウザDevToolsタブ活用

#### Console タブ

| 用途 | コマンド/操作 |
|------|-------------|
| エラーフィルタリング | `Errors` フィルタ選択 |
| ネットワークエラー | `Failed to fetch` 等のメッセージ確認 |
| カスタムログ | `console.log`、`console.table`、`console.group` |
| パフォーマンス計測 | `console.time('label')` / `console.timeEnd('label')` |
| オブジェクト検査 | `console.dir(object, { depth: null })` |

```javascript
// 効果的なconsoleデバッグ
// テーブル形式で配列/オブジェクトを表示
console.table(users);

// グループ化で見やすく
console.group('API Request');
console.log('URL:', url);
console.log('Method:', method);
console.log('Body:', body);
console.groupEnd();

// 処理時間の計測
console.time('fetchUsers');
const users = await fetchUsers();
console.timeEnd('fetchUsers'); // fetchUsers: 123.456ms

// 条件付きログ（条件がfalseの場合のみ出力）
console.assert(user.role === 'admin', 'ユーザーはadminではありません', user);

// スタックトレース付きログ
console.trace('ここに到達');
```

#### Network タブ

- [ ] **ステータスコード確認**: 4xx/5xxエラーの特定
- [ ] **レスポンスタイム確認**: Waterfall表示で遅いリクエストを特定
- [ ] **リクエスト/レスポンスボディ確認**: 送信データと返却データの検証
- [ ] **ヘッダー確認**: Cache-Control、Authorization、Content-Type等
- [ ] **CORS確認**: プリフライトリクエスト（OPTIONS）の成否

#### Performance タブ

- [ ] **レンダリングボトルネック特定**: 長いTask（Long Tasks > 50ms）の特定
- [ ] **メインスレッドのブロック確認**: JavaScript実行時間の測定
- [ ] **レイアウトシフト確認**: CLS発生箇所の特定
- [ ] **フレームレート確認**: 60fps維持の確認

#### Application タブ

- [ ] **LocalStorage/SessionStorage確認**: 保存データの検証
- [ ] **Cookie確認**: セッション情報、認証トークンの確認
- [ ] **Service Worker確認**: キャッシュ状態、更新状況の確認
- [ ] **IndexedDB確認**: ローカルデータベースの内容確認

#### Memory タブ

- [ ] **メモリリーク検出**: Heap Snapshotの比較（操作前後で増加しているオブジェクト）
- [ ] **Detached DOM要素の検出**: メモリ上に残る不要なDOM要素
- [ ] **メモリ使用量の推移**: Allocation Timeline でリアルタイム監視

### 5.3 バックエンドデバッグ

#### ログレベル活用

```typescript
// 環境ごとのログレベル設定
// development: debug
// staging:     info
// production:  warn

// リクエストトレーシング（correlation ID）
import { v4 as uuidv4 } from 'uuid';
import { Request, Response, NextFunction } from 'express';

function correlationIdMiddleware(req: Request, _res: Response, next: NextFunction): void {
  const correlationId = req.headers['x-correlation-id'] as string ?? uuidv4();
  req.headers['x-correlation-id'] = correlationId;

  // AsyncLocalStorage でリクエストコンテキストを伝播
  const context = { correlationId, userId: req.user?.id };
  asyncLocalStorage.run(context, () => next());
}
```

#### 分散トレーシング

- [ ] トレーシングツール（OpenTelemetry、Jaeger、Zipkin）が導入されている
- [ ] 各サービス間のリクエストフローが追跡可能
- [ ] スパンに適切な属性が付与されている

```typescript
// OpenTelemetry セットアップ
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

const sdk = new NodeSDK({
  serviceName: 'user-service',
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-http': { enabled: true },
      '@opentelemetry/instrumentation-express': { enabled: true },
      '@opentelemetry/instrumentation-pg': { enabled: true },
      '@opentelemetry/instrumentation-redis': { enabled: true },
    }),
  ],
});

sdk.start();
```

### 5.4 段階的デバッグ手法

体系的なデバッグは5つのステップで進める。

#### Step 1: 問題の再現

- [ ] 問題を確実に再現できる手順を確立する
- [ ] 再現に必要な前提条件を特定する（環境、データ、タイミング）
- [ ] 再現率を確認する（常に再現 / 特定条件で再現 / ランダムに発生）

```typescript
// 再現テストの作成
describe('Issue #123: ユーザー作成時の重複エラー', () => {
  it('同時に同じメールアドレスで登録すると409を返す', async () => {
    // Arrange: 再現に必要な前提条件
    const userData = {
      name: 'テストユーザー',
      email: 'duplicate@example.com',
      password: 'SecureP@ss123',
    };

    // Act: 同時リクエストで再現
    const [result1, result2] = await Promise.allSettled([
      createUser(userData),
      createUser(userData),
    ]);

    // Assert: 一方が成功、他方が409
    const results = [result1, result2];
    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');

    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);
  });
});
```

#### Step 2: 範囲の特定

- [ ] フロントエンド vs バックエンド vs データベース vs 外部サービスのどこに問題があるか特定
- [ ] 最近の変更（deploy、コード変更、設定変更）を確認
- [ ] 影響範囲を特定（全ユーザー / 特定条件のユーザーのみ）

#### Step 3: 原因の特定

- [ ] 二分探索的アプローチ（中間地点にログを追加して範囲を絞る）
- [ ] 仮説を立てて検証する
- [ ] 関連するコードの変更履歴を確認

#### Step 4: 修正

- [ ] 修正コードを書く前にテストを書く（テストファースト）
- [ ] 修正が他の機能に影響しないことを確認
- [ ] 修正の根本原因を記録する（同様の問題の再発防止）

#### Step 5: 検証

- [ ] 修正後にテストが通ることを確認
- [ ] 本番環境相当の条件で再テスト
- [ ] 関連する機能のリグレッションテストを実行
- [ ] モニタリングで問題が解消されたことを確認

### 5.5 一般的なバグパターンと解決策

#### メモリリーク

| 原因 | 解決策 |
|------|--------|
| イベントリスナーの未解放 | `removeEventListener` / useEffectのクリーンアップ |
| タイマーの未解放 | `clearInterval` / `clearTimeout` |
| WebSocket接続の未切断 | `close()` の呼び出し |
| クロージャによる参照保持 | 不要な参照を`null`に設定 |
| Detached DOM要素 | 参照の適切な管理 |

```typescript
// メモリリークの典型的なパターンと修正
// ❌ メモリリーク: クリーンアップなし
function useWebSocket(url: string) {
  const [data, setData] = useState<string[]>([]);

  useEffect(() => {
    const ws = new WebSocket(url);
    ws.onmessage = (e) => setData((prev) => [...prev, e.data]);
    // クリーンアップがない!
  }, [url]);

  return data;
}

// ✅ 修正: クリーンアップを追加
function useWebSocket(url: string) {
  const [data, setData] = useState<string[]>([]);

  useEffect(() => {
    const ws = new WebSocket(url);
    ws.onmessage = (e) => setData((prev) => [...prev, e.data]);

    return () => {
      ws.close(); // WebSocketを確実に閉じる
    };
  }, [url]);

  return data;
}
```

#### レースコンディション

| 原因 | 解決策 |
|------|--------|
| 非同期処理の順序依存 | `AbortController` / 最新リクエストのみ反映 |
| 並行データ更新 | 楽観的ロック / バージョニング |
| 状態の競合 | `useReducer` / 状態マシン |

```typescript
// レースコンディションの防止（AbortController）
function useSearch(query: string) {
  const [results, setResults] = useState<SearchResult[]>([]);

  useEffect(() => {
    if (!query) {
      setResults([]);
      return;
    }

    const controller = new AbortController();

    async function search() {
      try {
        const response = await fetch(`/api/search?q=${query}`, {
          signal: controller.signal,
        });
        const data: SearchResult[] = await response.json();
        setResults(data); // AbortされたらsetResultsは呼ばれない
      } catch (error) {
        if (error instanceof DOMException && error.name === 'AbortError') {
          return; // Abort は正常な動作
        }
        throw error;
      }
    }

    search();

    return () => {
      controller.abort(); // 前のリクエストをキャンセル
    };
  }, [query]);

  return results;
}

// 楽観的ロック（バックエンド）
async function updateUser(id: string, data: UpdateUserDto, version: number): Promise<User> {
  const result = await prisma.user.updateMany({
    where: {
      id,
      version, // 現在のバージョンと一致する場合のみ更新
    },
    data: {
      ...data,
      version: { increment: 1 }, // バージョンをインクリメント
    },
  });

  if (result.count === 0) {
    throw new ConflictError('データが他のユーザーによって更新されています。再読み込みしてください。');
  }

  return prisma.user.findUniqueOrThrow({ where: { id } });
}
```

#### 型不整合

| 原因 | 解決策 |
|------|--------|
| APIレスポンスの型不整合 | ランタイムバリデーション（zod） |
| `null`/`undefined`の未処理 | strict null checks有効化 |
| 型アサーションの乱用 | 型ガード関数の使用 |

```typescript
// ランタイムバリデーション（zod）
import { z } from 'zod';

const UserResponseSchema = z.object({
  id: z.string(),
  name: z.string(),
  email: z.string().email(),
  role: z.enum(['admin', 'editor', 'viewer']),
  createdAt: z.string().datetime(),
});

type UserResponse = z.infer<typeof UserResponseSchema>;

async function fetchUser(userId: string): Promise<UserResponse> {
  const response = await fetch(`/api/users/${userId}`);
  const data: unknown = await response.json();

  // APIレスポンスをランタイムでバリデーション
  const result = UserResponseSchema.safeParse(data);
  if (!result.success) {
    throw new Error(
      `API応答の型が不正です: ${result.error.issues.map((i) => i.message).join(', ')}`,
    );
  }

  return result.data;
}

// 型ガード関数
function isNonNullable<T>(value: T): value is NonNullable<T> {
  return value !== null && value !== undefined;
}

// 使用例
const users: (User | null)[] = [user1, null, user2, null];
const validUsers: User[] = users.filter(isNonNullable);
```

#### 一般的なエラーパターン早見表

| エラー | よくある原因 | 確認箇所 |
|--------|------------|---------|
| `TypeError: Cannot read properties of undefined` | オプショナルチェーン未使用、非同期データの初期値 | オプショナルチェーン`?.`、初期値設定 |
| `CORS error` | サーバーサイドのCORS設定不足 | `Access-Control-Allow-Origin`ヘッダー |
| `404 Not Found` | URLパスの不一致、リソース未作成 | ルーティング設定、データ存在確認 |
| `401 Unauthorized` | トークン期限切れ、ヘッダー未設定 | トークンリフレッシュ、Authorizationヘッダー |
| `ECONNREFUSED` | サービス未起動、ポート不一致 | サービス稼働状況、ポート設定 |
| `Out of memory` | メモリリーク、大量データ処理 | ストリーミング処理、バッチ処理に変更 |
| `Deadlock detected` | 同時更新の競合 | トランザクション順序、楽観的ロック |
| `ETIMEOUT` | サーバー応答遅延、ネットワーク問題 | タイムアウト値調整、リトライロジック |
