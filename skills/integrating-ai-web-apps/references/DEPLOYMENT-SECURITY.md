# DEPLOYMENT-SECURITY.md — AIアプリのデプロイ・セキュリティ設計

本番環境へのデプロイ前に参照する。AIアプリ固有のセキュリティリスク（プロンプトインジェクション、APIクレジット枯渇、PII漏洩）への対処法をまとめる。

---

## 1. 入力バリデーション

**いつ使うか**: AIへのユーザー入力を受け付けるエンドポイントを実装するとき。

AIアプリの入力バリデーションは、脅威モデルの作成から始める。

### 脅威モデルの3要素

| 要素 | 確認内容 | AIアプリ固有の懸念 |
|------|---------|-----------------|
| パブリックエンドポイント | 外部公開されているURLをすべて列挙 | `/api/chat` などのLLM連携エンドポイント |
| ユーザー入力ポイント | フォーム・APIリクエストの受付箇所 | プロンプト入力欄、チャット送信 |
| データ感度 | PII・金融情報・医療情報の有無 | メール、パスワード、IPアドレス、識別子 |

### サーバーサイド vs クライアントサイドバリデーション

| 種別 | 実行タイミング | 重要度 | 備考 |
|------|-------------|-------|------|
| **サーバーサイド** | データ送信後 | **必須**（真実の源） | クライアント検証を突破されても防御できる |
| クライアントサイド | 送信前（ブラウザ） | 補助的 | UXのフィードバック改善が目的。単独では信頼できない |

> **原則**: クライアントからのデータは必ず改ざんされている前提でサーバーサイドバリデーションを実施する。

### Zodによる実装パターン

```typescript
import { z } from 'zod';

const promptSchema = z.object({
  prompt: z.string().min(1).max(1000), // 1,000文字上限
});

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const validatedData = promptSchema.parse(body); // バリデーション失敗時は例外
    const response = await process(validatedData.prompt);
    return Response.json({ response });
  } catch (error) {
    return Response.json({ error: 'Invalid input' }, { status: 400 });
  }
}
```

UIでも同様の制限を設定してUXを改善する（サーバー側検証の代替にはならない）:

```tsx
<textarea maxLength={1000} placeholder="メッセージを入力..." />
```

---

## 2. セキュリティミドルウェア

**いつ使うか**: リクエストがAPIロジックに到達する前に複数のセキュリティチェックを適用するとき。

Next.jsのミドルウェアをリクエスト処理パイプラインの先頭に配置することで、悪意あるリクエストをAIモデルへの到達前にブロックする。Vercel等のエッジネットワーク上で実行するとユーザーに近い場所でセキュリティチェックが行われ、パフォーマンスと安全性が向上する。

### ミドルウェアの責務

| 機能 | 説明 |
|------|------|
| リクエストパターン分析 | ブルートフォース・DoS攻撃の検出 |
| 既知の攻撃シグネチャチェック | SQLインジェクション・XSSパターンの検出 |
| 認証トークン検証 | JWT等の正当性確認 |
| リクエストヘッダー検査 | 異常なUser-AgentやIPの検出 |
| レート制限 | バックエンドへの過剰リクエストのブロック |

### Composableミドルウェアパターン

```typescript
import { NextResponse, NextRequest } from 'next/server';

type MiddlewareResult = {
  response?: NextResponse;
  continue?: boolean;
};

type MiddlewareFn = (
  req: NextRequest,
  res: NextResponse
) => Promise<MiddlewareResult>;

const composeMiddleware = (middlewares: MiddlewareFn[]) => {
  return async (request: NextRequest) => {
    let response = NextResponse.next();
    for (const middleware of middlewares) {
      try {
        const result = await middleware(request, response);
        if (result.response) return result.response;
        if (result.continue === false) break;
      } catch (error) {
        console.error('Middleware error:', error);
        return NextResponse.json(
          { error: 'Internal Server Error' },
          { status: 500 }
        );
      }
    }
    return response;
  };
};

// ミドルウェアチェーンの構成
const middlewareChain = composeMiddleware([
  handleCORS,
  rateLimit,
  authenticate,
  securityHeaders,
]);

export async function middleware(request: NextRequest) {
  return await middlewareChain(request);
}

export const config = {
  matcher: '/api/:path*', // APIルートにのみ適用
};
```

---

## 3. 認証と認可

**いつ使うか**: AIリソース（LLM APIコール）へのアクセス制御が必要なとき。

AIアプリではAPIコストが直接コストに直結するため、認証・認可による利用制限が重要。未認証ユーザーの自由なアクセスはAPIクレジットを枯渇させる可能性がある。

### 認証方式の選定

| 方式 | 推奨シーン | 利点 | 注意点 |
|------|-----------|------|-------|
| ユーザー名/パスワード | 小規模・シンプルなアプリ | 実装が単純 | パスワード管理の複雑さ。現代では非推奨傾向 |
| **OAuth 2.0 / ソーシャルログイン** | 一般向けWebアプリ | 既存認証基盤を流用、UX良好 | 過剰な権限要求を避けること |
| パスワードレス | モバイル・メール認証中心 | パスワード管理不要 | SMS/メール送信インフラが必要 |
| **MFA（多要素認証）** | 決済・機密情報扱いのアプリ | 最高レベルのセキュリティ | 設定の複雑さ。サードパーティプロバイダー推奨 |

### Clerk.js + Next.js による認証実装

```typescript
// middleware.ts
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";

const isProtectedRoute = createRouteMatcher(["/chat(.*)"]);

export default clerkMiddleware(async (auth, req) => {
  // /chat以下の全ルートを保護
  if (isProtectedRoute(req)) await auth.protect();

  const corsResponse = handleCORS(req);
  if (corsResponse instanceof NextResponse) return corsResponse;

  const rateLimitResponse = await rateLimit(req);
  if (rateLimitResponse instanceof NextResponse) return rateLimitResponse;

  return NextResponse.next();
});

export const config = {
  matcher: [
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    '/(api|trpc)(.*)',
  ]
};
```

```tsx
// app/page.tsx — 認証状態に応じたリダイレクト
'use client';
import { useUser } from "@clerk/nextjs";
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

export default function IndexPage() {
  const { isSignedIn } = useUser();
  const router = useRouter();

  useEffect(() => {
    if (!isSignedIn) {
      router.push('/sign-in');
    } else {
      router.push('/chat');
    }
  }, [isSignedIn, router]);

  return <div>Loading...</div>;
}
```

### レート制限の実装（Upstash Redis）

```typescript
import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});

// スライディングウィンドウアルゴリズム: 10秒間に5リクエスト
const ratelimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(5, "10 s"),
});

const rateLimit = async (request: NextRequest) => {
  const identifier = request.ip ?? '127.0.0.1';
  try {
    const { success } = await ratelimit.limit(identifier);
    if (!success) {
      return {
        response: NextResponse.json(
          { message: "Too many requests" },
          { status: 429 }
        ),
        continue: false,
      };
    }
    return { continue: true };
  } catch (error) {
    console.error("Rate limiting error:", error);
    return {
      response: NextResponse.json(
        { error: "Internal Server Error" },
        { status: 500 }
      ),
      continue: false,
    };
  }
};
```

### メッセージクォータ実装（ユーザー単位の日次制限）

```typescript
import { getAuth } from '@clerk/nextjs/server';

const checkMessageQuota = async (userId: string): Promise<boolean> => {
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  const key = `message_count:${userId}:${today}`;

  const count = await redis.incr(key);
  if (count === 1) {
    // 初回アクセス時は24時間のTTLを設定
    await redis.expire(key, 24 * 60 * 60);
  }

  return count <= 10; // 1日10メッセージまで
};

export async function POST(req: Request) {
  const { userId } = getAuth(req as never);
  if (!userId) {
    return new Response('Unauthorized', { status: 401 });
  }

  const quotaAvailable = await checkMessageQuota(userId);
  if (!quotaAvailable) {
    return new Response(
      JSON.stringify({ error: '1日のメッセージ上限（10件）に達しました。明日また試してください。' }),
      { status: 429, headers: { 'Content-Type': 'application/json' } }
    );
  }

  // 以降のAPIロジック...
}
```

> **⚠️ 注意**: 招待制登録や使い捨てメールアドレス対策（CAPTCHA、ビジネスメール必須化）を組み合わせることでクォータ回避を防ぐ。

---

## 4. APIキー管理

**いつ使うか**: 外部LLMプロバイダーのAPIキーを扱うとき。

### Next.js環境変数の種別

| 種別 | プレフィックス | 公開範囲 | 用途 |
|------|-------------|---------|------|
| プライベート | プレフィックスなし（または `NEXT_PRIVATE_`） | サーバーのみ | APIキー、DBクレデンシャル、シークレット |
| パブリック | `NEXT_PUBLIC_` | ブラウザにも露出 | フォントURL、公開設定値など |

> **⚠️ 危険**: `NEXT_PUBLIC_OPENAI_API_KEY` のような命名は絶対に避ける。ブラウザのソースコードから丸見えになる。

### APIキー管理戦略の比較

| 戦略 | 説明 | 推奨度 | 注意点 |
|------|------|-------|-------|
| **アプリレベルキー** | 組織のAPIキーをサーバー環境変数に保存 | **推奨** | `use server` ディレクティブで確実にサーバー実行 |
| **ユーザー提供キー（サーバー保存）** | 暗号化してDBに保存、サーバーが代理呼び出し | 可 | 実装コスト高。パスワードと同等の管理が必要 |
| ユーザー提供キー（クライアント保存） | クライアントから直接API呼び出し | ❌ 非推奨 | DevToolsで露出、OpenAIなどは検出して自動無効化する |

### サーバーサイドAPIキーの使用例

```typescript
'use server'; // このファイルはサーバーでのみ実行

import { Redis } from '@upstash/redis';

// クライアントには一切のクレデンシャルが漏れない
const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});
```

### APIキー管理のベストプラクティス

- Vercelダッシュボードでランタイム注入（`.env` ファイルをリポジトリにコミットしない）
- 定期的なキーローテーション
- OpenAI・Google Cloud等のプロバイダーダッシュボードでAPI使用量を監視
- ステージング環境とプロダクション環境でキーを分離する

---

## 5. データ保護とコンプライアンス

**いつ使うか**: ユーザーのPIIを扱うアプリや、GDPR/CCPA対応が必要なとき。

### データ保護の設計チェックポイント

| 観点 | 確認内容 |
|------|---------|
| チャットデータの感度 | PII・金融情報・医療情報が含まれるか |
| 暗号化 | 保存時はAES等、転送時はHTTPS |
| アクセス制御 | 最小権限原則、なりすましアクセスのログ記録 |
| データ保持ポリシー | 法的要件に基づいた保持期間と削除手順 |
| 匿名化/仮名化 | モデル学習・分析利用前に必須 |
| ログと監査 | アクセス記録による不正アクセス検出 |

### PIIの匿名化実装

LLMに送信する前にPIIを除去することで、個人情報がモデルに渡るのを防ぐ。

```typescript
import { SyncRedactor } from 'redact-pii';

const redactor = new SyncRedactor();

function anonymizeText(text: string): string {
  return redactor.redact(text);
  // 例: "田中太郎 (tanaka@example.com)" → "PERSON_NAME (EMAIL_ADDRESS)"
}

export async function POST(req: Request) {
  const body = await req.json();
  const validatedData = promptSchema.parse(body);
  const { userId } = await auth();

  if (!userId) {
    return new Response('Unauthorized', { status: 401 });
  }

  // LLMには匿名化済みテキストのみを渡す
  const anonymizedInput = anonymizeText(validatedData.text);
  // ...LLM呼び出し
}
```

> **本番環境の推奨**: より包括的なPII検出（非英語データ含む）には `@google-cloud/dlp` を使用する。また、匿名化ロジックはミドルウェア層に組み込むとパフォーマンスが最適化される。

---

## 6. デプロイ戦略

**いつ使うか**: AIアプリを本番環境に展開する方法を選定するとき。

### AIアプリ固有のデプロイ考慮事項

| 考慮事項 | 詳細 |
|---------|------|
| コスト管理 | LLMプロバイダーの料金モデルを理解し、APIコール数を最適化 |
| データプライバシー | LLMプロバイダーのプライバシーポリシー確認、GDPR/HIPAAコンプライアンス |
| レイテンシ | ネットワーク遅延の影響評価、ローカルキャッシュの実装 |
| スケーラビリティ | CI/CDパイプライン、冗長性とフェイルオーバー戦略 |
| 外部サービス設定 | 認証（Clerk）、レート制限（Upstash）等を本番用に再設定 |

### トラフィック規模別のインフラ要件

| ティア | 規模 | 必要な対策 |
|--------|------|-----------|
| **Tier 1** | 〜10,000リクエスト/日 | 基本監視・アラート、シンプルな水平スケーリング、標準セキュリティ(HTTPS/バリデーション)、日次バックアップ、基本エラートラッキング |
| **Tier 2** | 10,000〜100,000リクエスト/日 | CDN（Cloudflare等）、Vercel Firewall等の拡張セキュリティ、Sentry/Datadogによる詳細ログ |
| **Tier 3** | 100,000リクエスト/日〜 | 分散ログ・オブザーバビリティ、地理的分散（マルチリージョン）、エンタープライズグレードのサービス |

---

## 7. デプロイ先の選定

**いつ使うか**: ホスティングプラットフォームを選ぶとき。

| プラットフォーム | 主な特徴 | 向いているケース | 注意点 |
|----------------|---------|----------------|-------|
| **Vercel** | Next.js最適化、CDN・監視・CI/CD付属、エッジミドルウェア | Next.jsアプリ、初期デプロイ、小〜中規模 | スケールアウト時にコスト増大、大規模では要検討 |
| **Netlify** | 静的サイト・サーバーレス最適化、Git統合 | 静的サイト中心のアプリ | Next.js専用最適化はVercelほどではない |
| **Hugging Face Spaces** | ML/AIモデル公開に特化、Gradio/Docker対応 | AIモデルのデモ・共有 | CLIなし、UI操作のみ。認証・セキュリティ機能は限定的 |
| **Docker + Kubernetes** | 最大の柔軟性、自己管理 | 大規模・複雑な要件 | 高い技術知識と運用コストが必要 |
| **セルフホスト** | 完全なコントロール | 特定のコンプライアンス要件 | インフラ管理コストが最大 |

### Vercelのデプロイで提供される機能（無料プランで利用可能）

- HTTPS（デフォルト有効）
- 詳細な監視・ログ
- Git連携CI/CDパイプライン
- 環境変数の安全な管理
- 基本的なWebアプリケーションファイアウォール（カスタムルール設定可能）

---

## 8. 本番デプロイ前チェックリスト

### セキュリティ

- [ ] 入力バリデーション（Zod等）をすべてのAPIエンドポイントに適用済み
- [ ] セキュリティミドルウェア（CORS、レート制限、認証）を設定済み
- [ ] 認証・認可（Clerk等）を設定し、保護すべきルートをカバー済み
- [ ] APIキーをすべて環境変数で管理（コードベースにハードコーディングなし）
- [ ] `NEXT_PUBLIC_` プレフィックスのついた機密情報がないことを確認
- [ ] GitリポジトリにAPIキーや `.env` ファイルをコミットしていないことを確認
- [ ] APIキーの定期ローテーション計画を策定済み

### データ保護

- [ ] 機密データを送受信するすべての経路でHTTPS使用
- [ ] チャット履歴等の保存データを暗号化済み（AES等）
- [ ] LLMに送信するユーザー入力のPII匿名化を実装済み
- [ ] データ保持ポリシーを定義し、削除手順を実装済み
- [ ] GDPR/CCPA等の適用される規制を確認・対応済み

### 可用性・コスト管理

- [ ] LLMプロバイダーの料金モデルを把握し、コスト上限を設定済み
- [ ] ユーザー単位のメッセージクォータを実装済み
- [ ] 外部サービス（認証、Redis等）を本番用に再設定済み
- [ ] ローカルビルドが成功することを確認（`npm run build`）
- [ ] モニタリング・アラートを設定済み
- [ ] CI/CDパイプラインを構築済み

### 後処理

- [ ] トラフィック監視ツールを設定済み
- [ ] ログ管理を設定済み（必要に応じてNew Relic/Datadog等の外部ツールを導入）
- [ ] ファイアウォールルールを設定済み
- [ ] エラートラッキング（Sentry等）を設定済み
