# Reactアプリケーション プロダクションアーキテクチャ

---

## このファイルの対象範囲

React固有の**プロジェクト構造化・ESLintによる構造強制・環境変数管理・進化設計パターン**を扱う。

DUPLICATE除外: Clean Architectureの一般原則（依存性ルール・DI・同心円モデル）は `CLEAN-ARCHITECTURE.md` が担当。本ファイルはReactアプリ固有の実装パターンに限定する。

---

## ユーザー確認の原則（AskUserQuestion）

**以下の判断分岐は推測で進めず、必ずAskUserQuestionツールでユーザーに確認する。**

| 確認すべき場面 | 確認例 |
|---|---|
| アーキテクチャ方式（monolith vs microfrontend） | 現在のチーム規模・デプロイ独立性要件はあるか |
| feature flag ツール採用 | 環境変数ベースの簡易実装で十分か、専用ツール（LaunchDarkly等）が必要か |
| BFF 採用 | 複数クライアント（web / mobile / 外部API）が同一バックエンドを使うか |
| monorepo 移行 | 複数アプリ・共有パッケージが既に存在するか |

確認不要（一義的ベストプラクティス）: feature-based構造の採用、ESLintによる構造強制、Zod＋型安全な環境変数管理。

---

## アーキテクチャ判断フレーム

Reactはファイル構造に関して公式な制約を持たない。そのため「適切かどうか」を判断するフレームが必要となる。

### よくある反パターン

| 反パターン | 問題点 |
|---|---|
| フラットなコンポーネントフォルダ | 50個を超えると発見困難、100個で破綻 |
| 1つの巨大コンポーネント | テスト設定コスト増・再利用不可・AI の文脈窓を圧迫 |
| すべてをグローバル状態に集約 | データフロー追跡不能・変更の影響範囲が不明確 |
| 専用ツールを使わない | サーバー状態管理を自前実装するとキャッシュ/再バリデーション/楽観的更新をすべて再実装する羽目になる |

### 推奨パターンの選択基準

| 判断軸 | 推奨アプローチ |
|---|---|
| 機能の独立性 | feature-based構造（同一機能の関連ファイルを同一フォルダに集約） |
| 状態の適用範囲 | co-located状態（必要なコンポーネントに近いほど良い） |
| 問題の専門性 | 専用ツールを使う（React Query → サーバー状態、React Hook Form → フォーム状態） |
| セキュリティ | 多層防御（httpOnly cookie + 入力検証 + コンテンツサニタイズ + TypeScript） |
| 規模拡大性 | ESLintによる自動強制で「アーキテクチャドリフト」を防ぐ |

---

## feature-based プロジェクト構造

### 構造の比較

**ファイルタイプ別構造（スケールしない）:**

```
src/
├── components/   # 全コンポーネントが混在
├── pages/
├── hooks/
├── utils/
└── types/
```

問題点: 機能追加のたびに複数フォルダを横断・機能削除が困難・コードレビューが広範囲に及ぶ。

**feature-based構造（推奨）:**

```
src/
├── app/            # アプリコア・ルート設定・エントリポイント
├── components/     # 機能横断の再利用可能UIコンポーネント
├── config/         # アプリ設定
├── features/       # 機能モジュール群
│   ├── auth/       # 認証機能
│   ├── ideas/      # アイデア管理機能
│   ├── profile/    # ユーザープロファイル機能
│   └── reviews/    # レビュー機能
├── hooks/          # 機能横断のカスタムフック
├── lib/            # ユーティリティ・サードパーティ統合
├── stores/         # グローバル状態管理
└── types/          # TypeScript型定義
```

各 `features/{name}/` の内部構造:

```
features/ideas/
├── api/          # この機能のAPIコール
├── components/   # 機能固有コンポーネント
├── config/       # クエリキー等の設定
├── hooks/        # 機能固有カスタムフック
└── locales/      # 国際化リソース
```

### コードフローの方向性（単方向）

| 層 | インポート可能な対象 | インポート不可 |
|---|---|---|
| `app/`（最上位） | features / components / hooks / lib / stores / types | — |
| `features/`（中間） | 共有ユーティリティ全般 + 明示的に許可されたfeature | `app/` / 許可外のfeature |
| 共有ユーティリティ（最下位） | 同レベルの他共有ユーティリティ | `features/` / `app/` |

```typescript
// ALLOWED: appがfeatureをインポート
import { IdeaList } from '@/features/ideas/components/idea-list';

// ALLOWED: featureが許可済みfeatureをインポート
import { useUser } from '@/features/auth/hooks/use-user';

// ALLOWED: featureが共有ユーティリティをインポート
import { Button } from '@/components/ui/button';

// FORBIDDEN: featureがappをインポート（ESLintエラー）
import { loader } from '@/app/routes/dashboard/ideas/ideas';

// FORBIDDEN: 許可されていないfeature間の依存（ESLintエラー）
import { ProfileCard } from '@/features/profile/components/profile-card';

// FORBIDDEN: 共有ユーティリティがfeatureをインポート（ESLintエラー）
import { useUser } from '@/features/auth/hooks/use-user';
```

---

## ESLintによる構造強制

feature-based構造は「ルールを知っている人が守る」では維持できない。ESLintで自動検出する。

### 設定の全体像

```javascript
// eslint.config.js
import { importRules } from './infra/eslint-import-rules.js';

export default [
  {
    rules: {
      'import/no-restricted-paths': [
        'error',
        { zones: importRules },
      ],
    },
  },
];
```

### 制約1: 共有ユーティリティはfeaturesとappに依存しない

```javascript
// infra/eslint-import-rules.js
zones.push({
  target: [
    './src/components/**',
    './src/config/**',
    './src/hooks/**',
    './src/lib/**',
    './src/stores/**',
    './src/types/**',
  ],
  from: ['./src/features/**', './src/app/**'],
  message: '共有ユーティリティはfeaturesまたはappからインポートしてはいけません。',
});
```

### 制約2: featuresはappからインポートしない

```javascript
zones.push({
  target: './src/features/**/**',
  from: './src/app/**/**',
  message: 'featuresはappディレクトリからインポートしてはいけません。',
});
```

### 制約3: feature間依存は明示的に制御

```javascript
const features = [
  { name: 'auth',    allowedFeatures: [] },       // authは他featureに依存しない
  { name: 'ideas',   allowedFeatures: ['auth'] }, // ideasはauthのみに依存可
  { name: 'profile', allowedFeatures: ['auth'] },
  { name: 'reviews', allowedFeatures: ['auth'] },
];
// 上記設定からESLintルールを自動生成
```

### 違反時の解決方針

| 状況 | 対処 |
|---|---|
| 複数featureで同じコンポーネントが必要 | `src/components/` または `src/lib/` に移動 |
| featureがデータをやり取りする必要 | propsで渡す（featureをインポートしない） |
| 設計上の正当な依存が必要 | `allowedFeatures` に追加（慎重に判断） |

### ESLint強制の恩恵

- 循環依存の物理的な防止
- アーキテクチャドリフトをCIで即座に検出
- オンボーディングの高速化（ESLint設定が構造の自己文書化になる）
- feature単位の独立テストが可能

---

## 環境変数管理

### 問題: ハードコーディングの危険

```typescript
// ❌ 絶対にやらない
const API_URL = "https://api.production.com";
const API_KEY = "secret_key_12345";
```

機密情報がリポジトリに混入・環境切り替えにコード変更が必要・ランタイムエラーの発見が遅れる。

### Zodによる型安全な環境変数バリデーション

```typescript
// src/config/env.ts
import { z } from 'zod';

// Viteプレフィックスを内部名にマッピング
const envMapping = {
  API_URL: 'VITE_API_URL',
} as const;

export const envSchema = z.object({
  API_URL: z.url('API_URLは有効なURLである必要があります'),
});

const parseEnv = () => {
  const rawEnv: Record<string, string | undefined> = {};
  for (const [cleanKey, viteKey] of Object.entries(envMapping)) {
    rawEnv[cleanKey] = import.meta.env[viteKey];
  }
  return envSchema.parse(rawEnv);
};

export const env = parseEnv();
```

```typescript
// 使用側
import { env } from '@/config/env';
console.log(env.API_URL); // 型付き・バリデーション済み
```

### 環境変数が欠落した場合のエラー例

```
Environment validation failed:
API_URL (VITE_API_URL): API_URLは有効なURLである必要があります
Please check your .env file.
```

### セットアップ手順

1. `.env.example` にすべての変数を列挙（値なしでコミット）
2. `cp .env.example .env` でローカル環境を初期化
3. `.env` を `.gitignore` に追加（機密情報を保護）
4. `envSchema` に追加したすべての変数を `envMapping` に登録

---

## 進化設計パターン

### AIツールを使ったアーキテクチャ強制

AIコーディングツールは「優秀だが入社したばかりの開発者」と同じで、プロジェクト固有の制約を知らない。コンテキストファイル（`CLAUDE.md` / `.cursorrules` / `.github/copilot-instructions.md`）でアーキテクチャを明示する。

**効果の薄いルール（曖昧な指示）:**

```
APIコールを抽象化せよ。コンポーネントから直接呼ばないこと。
```

**効果的なルール（具体的な制約＋理由）:**

```
APIコールの抽象化ルール:
- 禁止: コンポーネントやhookからfetch()を直接呼ぶ
- 必須: src/lib/api.ts のHTTPメソッド（api.get, api.post等）経由で呼ぶ
- 各 src/features/<name>/api/ ファイルは必ず3つをエクスポートする:
  1. Zodで入出力を検証するfetcher関数
  2. ローダーとテスト用のquery optionsファクトリ
  3. useQuery/useMutationをラップするカスタムフック
- 理由: API層を統一することでモック・テスト・型安全性を一元管理できる
```

ルールの構成要素: **何をすべきか（場所含む）** + **何を禁止するか** + **理由**。

コンテキストファイルはアーキテクチャ変更のPRと同時に更新する（陳腐化したルールは有害）。

---

### feature flags と A/B テスト

> **AskUserQuestion**: 簡易実装（環境変数）で十分か、専用ツールが必要かをユーザーに確認すること。

**ユースケース**: デプロイとリリースの分離・即時ロールバック・段階的公開。

**段階1: 環境変数ベース（少数フラグに適切）**

```typescript
// src/lib/flags.ts
export const flags = {
  newDashboard: import.meta.env.VITE_FLAG_NEW_DASHBOARD === 'true',
};

// 使用側
import { flags } from '@/lib/flags';
function Dashboard() {
  if (!flags.newDashboard) return <LegacyDashboard />;
  return <NewDashboard />;
}
```

**段階2: 専用ツール（フラグが増えたとき・ユーザーセグメント制御が必要なとき）**

```typescript
// 専用ライブラリを使った例
import { useFlags } from 'flagsmith/react';

function Dashboard() {
  const { new_dashboard } = useFlags(['new_dashboard']);
  if (!new_dashboard.enabled) return <LegacyDashboard />;
  return <NewDashboard />;
}
```

**A/Bテスト（feature flagsの延長）:**

```typescript
function Dashboard() {
  const { new_dashboard } = useFlags(['new_dashboard']);
  if (!new_dashboard.enabled) return <LegacyDashboard />;
  if (new_dashboard.value === 'A') return <NewDashboardA />;
  if (new_dashboard.value === 'B') return <NewDashboardB />;
}
```

| 判断基準 | 環境変数ベース | 専用ツール |
|---|---|---|
| フラグ数 | 少数（5個未満） | 多数 |
| ユーザーセグメント制御 | 不要 | 必要 |
| 再デプロイなしのトグル | 不要 | 必要 |
| 変更の監査ログ | 不要 | 必要 |

---

### アプリケーション監視（エラートラッキング）

本番環境では「ユーザーが報告する前に問題を知る」仕組みが必須。

**エラートラッキングの設定:**

```typescript
// src/app/entry.client.tsx
import * as Sentry from '@sentry/react-router';
import { startTransition, StrictMode } from 'react';
import { hydrateRoot } from 'react-dom/client';
import { HydratedRouter } from 'react-router/dom';

Sentry.init({
  dsn: env.SENTRY_DSN, // 環境変数から取得
  sendDefaultPii: true,
});

startTransition(() => {
  hydrateRoot(
    document,
    <StrictMode><HydratedRouter /></StrictMode>,
  );
});
```

**構造化ログ（検索・アラート可能）:**

```typescript
// ❌ 検索不可能なログ
console.error('Something went wrong');

// ✅ フィールド別にインデックスされるログ
console.error('Something went wrong', {
  route: '/dashboard',
  componentName: 'Dashboard',
  userId: userId,
});
```

**監視の三層構成:**

| 層 | 目的 | ツール例 |
|---|---|---|
| エラートラッキング | 未処理例外・スタックトレース・ユーザー情報 | Sentry |
| パフォーマンス監視 | Web Vitals（LCP / CLS / INP）・リアルユーザー体験 | Sentry Performance / Lighthouse CI |
| 構造化ログ | ルート・コンポーネント・ユーザー別の検索とアラート | Datadog / New Relic |

---

### BFF（Backend for Frontend）パターン

> **AskUserQuestion**: 複数クライアント（web / mobile / 外部API）が同一バックエンドを使うかをユーザーに確認すること。

**問題**: REST APIは特定クライアントに最適化されていないため「1画面に複数リクエスト（under-fetching）」や「不要データの大量取得（over-fetching）」が発生する。

**解決**: BFFはクライアントとバックエンドの間に薄いAPIレイヤーを挟み、クライアント固有のデータ形式を返す。

```
Webアプリ → Web BFF → バックエンドサービス群
モバイルアプリ → Mobile BFF → バックエンドサービス群
```

| 観点 | BFF採用が適切 | BFF不要 |
|---|---|---|
| クライアント数 | Web + mobile + 外部API など複数 | 1クライアントのみ |
| データ形状 | クライアントごとに大きく異なる | ほぼ共通 |
| API呼び出し数 | 1画面で複数エンドポイントを叩く | 少ない |
| バックエンド所有 | 変更困難な外部サービス | 自由に変更可能 |

---

### monorepo

> 複数アプリ・共有パッケージが既にあるかをユーザーに確認してから判断する。

**問題**: アプリ・ダッシュボード・コンポーネントライブラリ・共有型定義が別リポジトリに分散すると同期コストが増大する。

**解決**: 単一リポジトリに複数アプリ・パッケージを収容（monorepo）。

```
monorepo/
├── apps/
│   ├── web/        # Webアプリ
│   └── dashboard/  # 管理画面
└── packages/
    ├── ui/         # 共有UIコンポーネント
    ├── types/      # 共有TypeScript型
    └── utils/      # 共有ユーティリティ
```

共有パッケージへの変更は即座に全アプリに反映される（publish-and-installサイクル不要）。

ツール: Turborepo / Nx / pnpm workspaces。

---

### microfrontends

> **AskUserQuestion**: チーム規模・デプロイ独立性の要件をユーザーに確認すること。過度な早期採用に注意。

**前提**: 1チームが全フロントエンドをship可能なら、monolithの方がシンプル。

**採用を検討する条件:**

| 条件 | 説明 |
|---|---|
| 複数の大規模チームが独立デプロイを必要とする | リリース調整の負荷が高い |
| フロントエンドの部分ごとに技術要件が異なる | フレームワークバージョンを分ける必要がある |
| ビルド時間・コードナビゲーションが開発速度を妨げている | モノリスが大きすぎる |

**コスト（理解してから採用）:**

| コスト | 内容 |
|---|---|
| 運用複雑性 | 各microfrontendが独立したパイプライン・バージョン管理・監視を持つ |
| 共有依存管理 | バージョン不一致によるバグやバンドル肥大化 |
| UX一貫性 | 共有デザインシステムなしではUI崩壊 |
| パフォーマンス | 複数バンドルの同時ロードによるオーバーヘッド |

成功するチームはfrontend分割の**前に**共有基盤（デザインシステム・デプロイツール・コントラクトテスト）を整備する。

---

## まとめ: 選択基準テーブル

| トピック | 小規模（1-3人） | 中規模（4-10人） | 大規模（10人以上） |
|---|---|---|---|
| プロジェクト構造 | feature-based（必須） | feature-based | feature-based |
| ESLint強制 | 推奨 | 必須 | 必須 |
| feature flags | 環境変数で十分 | 専用ツール検討 | 専用ツール必須 |
| 監視 | Sentryのみ | Sentry + Web Vitals | 三層監視フル構成 |
| BFF | 不要が多い | 複数クライアント時に検討 | 要件次第 |
| monorepo | 不要 | 2アプリ以上で検討 | 推奨 |
| microfrontends | 過剰 | 過剰が多い | 特定条件下のみ |
