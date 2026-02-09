---
name: building-nextjs-saas
description: Builds full-stack AI SaaS applications with Next.js App Router. Use when implementing SaaS features like authentication, payment integration, credit-based billing, or AI API integration. For Next.js fundamentals, use developing-nextjs; for enterprise multi-tenancy, use building-multi-tenant-saas instead.
---

# building-nextjs-saas

## 概要

Next.js App Routerをベースとした、フルスタックAI SaaSアプリケーションの構築パターンを提供します。認証、決済統合、クレジットベース課金、AI API統合、クラウドデプロイメントといったSaaS固有の機能実装を網羅します。

このスキルは、モダンなSaaSアプリケーションに必要な以下の要素を統合的に扱います：

- **認証・認可**: ソーシャルログイン、セッション管理、ルート保護
- **決済・課金**: サブスクリプション、クレジット制課金、料金プラン管理
- **AI統合**: 外部AI APIとの連携、画像処理パイプライン、非同期ジョブ処理
- **データ管理**: ORM設計、トランザクション処理、ファイルストレージ
- **本番運用**: 環境変数管理、スケーラブルなデプロイメント、監視

---

## 使用タイミング

以下のいずれかの実装時にこのスキルを参照してください：

- **SaaS機能実装**: ユーザー登録、ダッシュボード、プロフィール管理
- **クレジット課金システム**: 使用量ベースの課金、クレジット消費ロジック、残高管理
- **外部AI API統合**: Replicate、OpenAI等のAPI連携、非同期処理、結果保存
- **決済ゲートウェイ統合**: PayPal、Stripe等の決済フロー、Webhook処理
- **ファイルストレージ**: ユーザー生成コンテンツの保存・配信
- **フルスタックデプロイ**: Vercelへのデプロイ、環境変数設定、本番最適化

**このスキルを使わないケース:**
- Next.jsの基本機能のみ必要な場合 → `developing-nextjs`
- エンタープライズマルチテナンシー → `building-multi-tenant-saas`
- REST API設計のみ → `designing-web-apis`

---

## 対象技術スタック

| カテゴリ | 技術 | 用途 |
|---|---|---|
| **フルスタックフレームワーク** | Next.js App Router | サーバー・クライアント統合、ルーティング、API Routes |
| **データベース** | Drizzle ORM + Neon PostgreSQL | 型安全なORM、サーバーレスPostgreSQL |
| **認証** | Clerk | ソーシャルログイン、セッション管理、ミドルウェア保護 |
| **ファイルストレージ** | Firebase Storage | 画像・動画等のユーザー生成コンテンツ保存 |
| **AI API** | Replicate API | 画像生成、モデル推論、非同期処理 |
| **決済** | PayPal | 決済処理、サブスクリプション、Webhook |
| **デプロイ** | Vercel | CI/CD、エッジランタイム、プレビューデプロイ |
| **UI** | DaisyUI + TailwindCSS | コンポーネントライブラリ、ユーティリティファースト |

**代替技術の判断基準:**
- **認証**: Clerk（推奨）、Auth.js（自前制御重視）、Supabase Auth（データベース統合）
- **決済**: PayPal（簡易統合）、Stripe（高機能）、Paddle（SaaS特化）
- **AI**: Replicate（汎用）、OpenAI（GPT系）、自前モデル（コスト最適化）
- **データベース**: Neon（サーバーレス）、Supabase（統合サービス）、PlanetScale（スケール重視）
- **ストレージ**: Firebase（簡易）、S3（スケール）、Cloudflare R2（コスト）

---

## SaaSアーキテクチャ概要

フルスタックAI SaaSアプリケーションの典型的なデータフローを以下に示します：

```
ユーザー
  ↓
[認証レイヤー: Clerk Middleware]
  ↓
ダッシュボード (Server Component)
  ↓
クレジット残高確認 (DB読取)
  ↓
AI生成リクエスト (Client → Server Action)
  ↓
[トランザクション開始]
  ├─ クレジット消費 (DB更新)
  ├─ AI API呼出 (Replicate)
  ├─ 結果保存 (Firebase Storage)
  └─ 履歴記録 (DB書込)
[トランザクション完了]
  ↓
結果表示 (Dynamic Route)
  ↓
[決済トリガー: クレジット不足]
  ↓
PayPal Checkout (外部リダイレクト)
  ↓
Webhook処理 (API Route)
  ↓
クレジット付与 (DB更新)
```

**重要な設計原則:**
1. **認証優先**: すべての保護ルートでミドルウェア認証を適用
2. **クレジット制**: AI生成等の高コスト操作は事前にクレジット確認
3. **非同期処理**: 長時間AI処理はServer Actionで非同期実行
4. **トランザクション**: クレジット消費とコンテンツ生成はアトミックに処理
5. **環境変数**: すべてのシークレット（API Key等）は環境変数で管理

---

## 判断基準テーブル

実装フェーズごとに参照すべきサブファイルと主要パターンを示します：

| 実装フェーズ | 参照先 | 主要パターン |
|---|---|---|
| **認証・ユーザー管理** | `AUTH-PATTERNS.md` | Clerk統合、Middleware保護、ソーシャルログイン、セッション取得、ユーザープロフィール |
| **決済・課金** | `PAYMENTS.md` | PayPal統合、クレジットシステム設計、料金プラン実装、Webhook検証、サブスクリプション管理 |
| **AI API統合** | `AI-INTEGRATION.md` | Replicate API呼出、画像処理パイプライン、Base64エンコーディング、非同期ジョブ、エラーハンドリング |
| **データベース設計** | `DB-PATTERNS.md` | Drizzle ORMスキーマ定義、リレーション設計、CRUD操作、トランザクション、マイグレーション |
| **ファイルストレージ** | `STORAGE.md` | Firebase Storage統合、ファイルアップロード、署名付きURL、権限管理、削除処理 |
| **デプロイ** | `DEPLOYMENT.md` | Vercel設定、環境変数登録、ビルド最適化、プレビューデプロイ、本番監視 |
| **UI/UX設計** | `UI-PATTERNS.md` | DaisyUI活用、フォームバリデーション、ローディング状態、エラー表示、レスポンシブ対応 |

**段階的実装の推奨順序:**
1. **基礎**: プロジェクトセットアップ → 認証 → データベーススキーマ
2. **コア機能**: ダッシュボード → AI生成機能 → ファイル保存
3. **課金**: クレジットシステム → 決済統合 → Webhook処理
4. **本番化**: 環境変数整理 → デプロイ → 監視設定

---

## ユーザー確認の原則（AskUserQuestion）

以下の判断分岐が発生した場合、`AskUserQuestion`ツールで必ずユーザーに選択肢を提示してください：

### 必須確認事項

#### 1. 認証プロバイダの選択

```
質問: 「認証プロバイダを選択してください」
選択肢:
- Clerk（推奨）: ソーシャルログイン統合、管理UI付き、Next.js最適化
- Auth.js: 自前制御重視、オープンソース、カスタマイズ性高
- Supabase Auth: データベース統合、RLS活用、リアルタイム機能
```

#### 2. 決済ゲートウェイの選択

```
質問: 「決済ゲートウェイを選択してください」
選択肢:
- PayPal: 簡易統合、グローバル対応、サブスクリプション対応
- Stripe: 高機能、詳細な決済ロジック、豊富なAPI
- Paddle: SaaS特化、税務処理自動化、MoR（Merchant of Record）
```

#### 3. AI APIプロバイダの選択

```
質問: 「AI APIプロバイダを選択してください」
選択肢:
- Replicate: 汎用、多様なモデル、従量課金
- OpenAI: GPT系特化、高精度、APIシンプル
- 自前モデル: コスト最適化、データプライバシー、推論速度制御
```

#### 4. データベースの選択

```
質問: 「データベースを選択してください」
選択肢:
- Neon: サーバーレスPostgreSQL、ブランチング機能、無料枠大
- Supabase: 統合サービス、RLS、リアルタイム対応
- PlanetScale: MySQL互換、スケーラビリティ高、自動シャーディング
```

#### 5. ファイルストレージの選択

```
質問: 「ファイルストレージを選択してください」
選択肢:
- Firebase Storage: 簡易統合、セキュリティルール、CDN内蔵
- AWS S3: スケーラブル、豊富な統合先、ライフサイクル管理
- Cloudflare R2: S3互換、エグレス無料、低コスト
```

### 確認不要な事項

以下はセキュリティ・ベストプラクティスとして常に適用するため、確認不要です：

- **HTTPS必須**: 本番環境では常にHTTPS
- **入力バリデーション**: すべてのユーザー入力を検証
- **環境変数でのシークレット管理**: API Key等は環境変数に格納
- **認証ルート保護**: ダッシュボード等は常にMiddlewareで保護
- **トランザクション処理**: クレジット消費は必ずトランザクション内
- **エラーハンドリング**: すべての外部API呼出でtry-catch実装

---

## プロジェクト構成

推奨ディレクトリ構造を以下に示します：

```
app/
├── (auth)/                    # 認証グループ
│   ├── sign-in/[[...sign-in]]/page.tsx
│   └── sign-up/[[...sign-up]]/page.tsx
├── (dashboard)/               # 保護されたルート
│   ├── layout.tsx             # 認証レイアウト
│   ├── page.tsx               # ダッシュボード
│   ├── generate/page.tsx      # AI生成UI
│   ├── history/page.tsx       # 生成履歴
│   └── credits/page.tsx       # クレジット購入
├── api/
│   ├── webhooks/
│   │   └── paypal/route.ts    # PayPal Webhook
│   ├── generate/route.ts      # AI生成API
│   └── credits/route.ts       # クレジット操作
├── actions/                   # Server Actions
│   ├── auth.ts
│   ├── generate.ts
│   └── payments.ts
├── middleware.ts              # Clerk認証Middleware
└── layout.tsx                 # ルートレイアウト

lib/
├── db/
│   ├── index.ts               # Drizzle設定
│   ├── schema.ts              # テーブル定義
│   └── migrations/            # マイグレーションファイル
├── ai/
│   ├── replicate.ts           # Replicate API
│   └── processors.ts          # 画像処理ロジック
├── payments/
│   ├── paypal.ts              # PayPal SDK
│   └── credits.ts             # クレジット管理
├── storage/
│   └── firebase.ts            # Firebase Storage
└── utils/
    ├── validation.ts          # Zod schemas
    └── errors.ts              # カスタムエラー

components/
├── ui/                        # DaisyUI拡張
├── forms/                     # フォームコンポーネント
├── dashboard/                 # ダッシュボード固有
└── shared/                    # 共通コンポーネント

types/
├── auth.ts
├── database.ts
└── api.ts

public/
└── images/

.env.local                     # 環境変数（Git除外）
.env.example                   # 環境変数テンプレート
drizzle.config.ts              # Drizzle設定
middleware.ts                  # Clerk Middleware
next.config.js
package.json
tsconfig.json
tailwind.config.ts
```

**ディレクトリ命名規則:**
- `(auth)`, `(dashboard)`: Route Groups（URLに影響しない）
- `api/`: API Routes（REST エンドポイント）
- `actions/`: Server Actions（フォーム送信等）
- `lib/`: ビジネスロジック・ユーティリティ
- `components/`: 再利用可能なReactコンポーネント
- `types/`: TypeScript型定義

---

## クイックスタートチェックリスト

新規プロジェクト立ち上げ時の手順を示します：

### 1. プロジェクトセットアップ

- [ ] Next.js App Routerプロジェクト作成（`npx create-next-app@latest`）
- [ ] TypeScript + ESLint + TailwindCSS有効化
- [ ] DaisyUIインストール（`npm install daisyui`）
- [ ] `.env.local`作成（`.env.example`からコピー）

### 2. 認証セットアップ

- [ ] Clerkアカウント作成
- [ ] Clerk APIキー取得（`NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`）
- [ ] `middleware.ts`でルート保護設定
- [ ] サインイン・サインアップページ作成

### 3. データベースセットアップ

- [ ] Neonアカウント作成、データベース作成
- [ ] Drizzle ORMインストール（`npm install drizzle-orm`）
- [ ] `lib/db/schema.ts`でテーブル定義
- [ ] 初期マイグレーション実行（`npm run db:push`）

### 4. AI API統合

- [ ] Replicateアカウント作成、APIキー取得
- [ ] `lib/ai/replicate.ts`でクライアント初期化
- [ ] 使用するモデルIDを環境変数に設定

### 5. ファイルストレージ

- [ ] Firebaseプロジェクト作成
- [ ] Firebase Storage有効化、セキュリティルール設定
- [ ] サービスアカウントキー取得、環境変数設定

### 6. 決済統合

- [ ] PayPalアカウント作成（SandboxとProduction）
- [ ] Client ID、Secretキー取得
- [ ] Webhook URL設定（`/api/webhooks/paypal`）

### 7. デプロイ

- [ ] Vercelにプロジェクト接続
- [ ] 環境変数を本番環境に登録
- [ ] ビルド・デプロイ確認

---

## 関連スキル

このスキルは以下のスキルと組み合わせて使用します：

### 前提スキル

- **`developing-nextjs`**: Next.js App Routerの基礎、Server Components、Server Actions等のフレームワーク基礎を習得してから本スキルを使用してください。

### 補完スキル

- **`building-multi-tenant-saas`**: エンタープライズ向けマルチテナント機能（組織管理、RBAC、テナント分離）が必要な場合に併用
- **`designing-web-apis`**: 外部APIを提供する場合（SaaS自体がプラットフォームとなる場合）のAPI設計
- **`developing-fullstack-javascript`**: バックエンドをNestJS等の別フレームワークで構築する場合の統合パターン
- **`writing-clean-code`**: SOLID原則・クリーンコード実践。ビジネスロジックの複雑化に伴うリファクタリング時の設計原則
- **`testing`**: AI生成機能、決済フロー、クレジットシステムのテスト戦略

### 使い分け

| 要件 | 推奨スキル |
|---|---|
| 個人・小規模SaaS、AI機能中心 | `building-nextjs-saas`（本スキル） |
| エンタープライズB2B SaaS、組織管理 | `building-multi-tenant-saas` |
| Next.jsの基本機能のみ | `developing-nextjs` |
| API提供がメイン | `designing-web-apis` |
| フロントエンドとバックエンド分離 | `developing-fullstack-javascript` |

---

## 実装時の注意事項

### セキュリティ

1. **環境変数**: すべてのAPIキー・シークレットは環境変数で管理
2. **入力バリデーション**: Zodスキーマで全入力を検証
3. **認証**: すべての保護ルートでMiddleware認証を適用
4. **CSRF対策**: Server Actionsはデフォルトで保護されている
5. **Webhook検証**: PayPal等のWebhookは署名検証必須

### パフォーマンス

1. **Server Components優先**: デフォルトはServer Component、必要な箇所のみ`'use client'`
2. **データベースクエリ最適化**: N+1問題回避、適切なインデックス
3. **画像最適化**: Next.js Imageコンポーネント使用
4. **キャッシング**: Server Componentsで`cache()`活用
5. **非同期処理**: AI生成等の重い処理はServer Actionで非同期実行

### 開発効率

1. **型安全**: Drizzle ORMでデータベース型を自動生成
2. **環境変数管理**: `.env.example`をテンプレートとして提供
3. **エラーハンドリング**: カスタムエラークラスで一貫したエラー処理
4. **ログ**: 本番環境では構造化ログ（JSON）を使用
5. **テスト**: 決済・AI統合はモックを活用

---

## まとめ

このスキルは、Next.js App Routerを使用したAI SaaSアプリケーションの構築に必要なパターンを網羅しています。認証、決済、AI統合、データ管理、デプロイまでの一連の流れを理解し、各フェーズで適切なサブファイルを参照しながら実装を進めてください。

**重要な原則:**
- **セキュリティファースト**: 認証・認可を最初に実装
- **トランザクション管理**: クレジット操作は必ずアトミックに
- **環境変数管理**: すべてのシークレットを環境変数で管理
- **段階的実装**: 基礎→コア機能→課金→本番化の順に進める
- **ユーザー確認**: 技術選択時は必ずAskUserQuestionで確認

各実装フェーズで詳細が必要な場合は、判断基準テーブルを参照して適切なサブファイルを確認してください。
