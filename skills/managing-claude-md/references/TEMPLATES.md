# CLAUDE.md テンプレート集

このドキュメントでは、さまざまなプロジェクト規模・用途に応じたCLAUDE.mdのテンプレートを提供します。

---

## 1. ミニマルテンプレート（新規プロジェクト用）

**対象**: 個人開発、小規模プロジェクト、PoC

**特徴**:
- 20-30行程度の最小構成
- プロジェクト説明、コマンド、1-2個の罠のみ
- 拡張可能な基礎構造

**テンプレート**:

```markdown
# プロジェクト名

[プロジェクトの一行説明: 何を解決するのか、主な技術スタックは何か]

## 技術スタック
- [主要言語・フレームワーク]
- [主要ライブラリ]
- [主要ツール]

## コマンド
- 開発サーバー: `npm run dev`
- テスト: `npm test`
- Lint: `npm run lint`
- ビルド: `npm run build`

## プロジェクト固有の注意事項
- **API呼び出し時 → 環境変数 `API_KEY` が設定されていることを確認**
- **データベースマイグレーション実行時 → 必ず `npm run db:migrate:dry` で事前確認**
```

**使用例**:
- 新しいライブラリのプロトタイプ
- 学習用プロジェクト
- 1-2週間の短期開発

---

## 2. スタンダードテンプレート（チーム開発用）

**対象**: チーム開発、中規模プロジェクト

**特徴**:
- 50-100行程度
- 必須3要素 + コーディング規約参照 + 段階的開示
- チームメンバーのオンボーディングに最適

**テンプレート**:

```markdown
# プロジェクト名

[プロジェクトの一行説明]

---

## 🚨 CRITICAL

- **マージ前 → 必ず `npm run test && npm run lint` 実行**
- **機密情報 → 環境変数に格納し、コミット前に `.env` を `.gitignore` で除外済み確認**
- **API変更 → `docs/api-design.md` を先に更新してからPR作成**

---

## 技術スタック
- **フロントエンド**: Next.js 15, React 19, TailwindCSS
- **バックエンド**: NestJS, Prisma, PostgreSQL
- **テスト**: Vitest, Playwright
- **インフラ**: Docker, Google Cloud Run

## コマンド

### 開発
- `npm run dev` — 開発サーバー起動 (http://localhost:3000)
- `npm run dev:docker` — Docker Compose で全サービス起動

### テスト
- `npm test` — ユニットテスト実行
- `npm run test:e2e` — E2Eテスト実行
- `npm run test:watch` — テストウォッチモード

### データベース
- `npm run db:migrate` — マイグレーション実行
- `npm run db:seed` — 開発用データ投入
- `npm run db:studio` — Prisma Studio 起動

### ビルド・デプロイ
- `npm run build` — プロダクションビルド
- `npm run deploy:staging` — ステージング環境デプロイ

## プロジェクト固有の注意事項

- **新しいAPIエンドポイント追加時 → `docs/api-design.md` にOpenAPI仕様を先に記述**
- **Prismaスキーマ変更時 → `npm run db:migrate:dry` で影響範囲を確認後、チームに通知**
- **環境変数追加時 → `.env.example` に説明付きで追記**
- **UI コンポーネント作成時 → Storybook にストーリーを作成**
- **認証が必要なエンドポイント → `@UseGuards(AuthGuard)` デコレーターを使用**

## アーキテクチャ

詳細は以下を参照:
- [アーキテクチャ設計](docs/architecture.md)
- [APIドキュメント](docs/api-design.md)
- [データベース設計](docs/database-design.md)
- [コーディング規約](docs/coding-guidelines.md)

## トラブルシューティング

- **ビルドエラー**: `rm -rf node_modules && npm install` で依存関係を再構築
- **E2Eテスト失敗**: Docker コンテナが起動していることを確認
- **マイグレーションエラー**: `npm run db:reset` でデータベースをリセット
```

**使用例**:
- チーム開発プロジェクト（3-10人）
- 中規模SaaSアプリケーション
- 3ヶ月以上の継続開発

---

## 3. モノレポテンプレート

**対象**: マイクロサービス、モノレポ構成

**特徴**:
- ルート CLAUDE.md + サービス固有 CLAUDE.md
- 共通設定とサービス固有設定の分離
- パッケージ間の依存関係を明示

**ルート CLAUDE.md**:

```markdown
# プロジェクト名（モノレポ）

[プロジェクト全体の一行説明]

---

## 🚨 CRITICAL（全サービス共通）

- **新規パッケージ追加時 → ルートの `package.json` の `workspaces` に追加**
- **共通ライブラリ変更時 → 影響を受けるすべてのサービスで `npm run build` 確認**
- **環境変数 → 各サービスの `.env.example` を参照**

---

## モノレポ構成

```
root/
├── packages/
│   ├── shared/          # 共通ライブラリ
│   ├── api/             # バックエンドAPI
│   ├── web/             # フロントエンド
│   └── worker/          # バックグラウンドワーカー
└── docs/                # 共通ドキュメント
```

各サービスの詳細は、サービス固有の CLAUDE.md を参照:
- [shared CLAUDE.md](packages/shared/CLAUDE.md)
- [api CLAUDE.md](packages/api/CLAUDE.md)
- [web CLAUDE.md](packages/web/CLAUDE.md)
- [worker CLAUDE.md](packages/worker/CLAUDE.md)

## 共通コマンド

### 全サービス
- `npm run dev` — 全サービスの開発サーバー起動
- `npm run test` — 全サービスのテスト実行
- `npm run build` — 全サービスのビルド

### 特定サービス
- `npm run dev --workspace=api` — API サービスのみ起動
- `npm run test --workspace=web` — Web サービスのみテスト

## パッケージ間の依存関係

- `api` → `shared` (型定義、ユーティリティ)
- `web` → `shared` (型定義、UI コンポーネント)
- `worker` → `shared` (型定義、ユーティリティ)

**注意**: `shared` を変更した場合 → 依存する全サービスで `npm run build` 実行

## プロジェクト固有の注意事項

- **新しい共通型定義追加時 → `packages/shared/src/types/` に追加し、`index.ts` でエクスポート**
- **サービス間API通信 → `packages/shared/src/api-client/` のクライアントを使用**
- **データベーススキーマ変更 → `packages/api` のマイグレーションで管理**
```

**サービス固有 CLAUDE.md (例: packages/api/CLAUDE.md)**:

```markdown
# API Service

バックエンドAPIサービス (NestJS + Prisma)

## サービス固有のコマンド
- `npm run dev` — API 開発サーバー起動 (http://localhost:4000)
- `npm run db:migrate` — データベースマイグレーション
- `npm run db:studio` — Prisma Studio 起動

## サービス固有の注意事項
- **新しいエンドポイント追加時 → `docs/api-design.md` に OpenAPI 仕様を記述**
- **認証が必要なエンドポイント → `@UseGuards(AuthGuard)` を使用**
- **データベーススキーマ変更 → `npm run db:migrate:dry` で影響確認**

## 依存関係
- `@project/shared` — 共通型定義とユーティリティ

---

共通ルールは [ルート CLAUDE.md](../../CLAUDE.md) を参照
```

---

## 4. 個人設定テンプレート（claude.local.md / ~/.claude/CLAUDE.md）

**対象**: 個人の好み・ワークフロー設定

**特徴**:
- `.gitignore` で除外
- 個人固有のエディタ設定、ショートカット、好みのライブラリ
- プロジェクト共通ルールを上書きしない

**テンプレート (`claude.local.md`)**:

```markdown
# 個人設定 (Your Name)

このファイルは `.gitignore` で除外され、個人の好みを反映します。

## エディタ設定
- **エディタ**: VSCode
- **拡張機能**: Prettier, ESLint, Prisma

## 好みのライブラリ
- **UI コンポーネント**: Radix UI, Headless UI
- **状態管理**: Zustand
- **フォーム**: React Hook Form

## 個人用ショートカット
- `npm run test:focus` — 開発中のテストのみ実行
- `npm run lint:fix` — Lint エラーを自動修正

## 好みのコーディングスタイル
- **関数宣言**: Arrow Function を優先
- **型定義**: `type` より `interface` を優先
- **テスト**: AAA パターン（Arrange, Act, Assert）を厳密に適用
```

**グローバル設定 (`~/.claude/CLAUDE.md`)**:

```markdown
# グローバル設定

すべてのプロジェクトで共通の設定

## 言語設定
- **応答言語**: 日本語（技術用語は原語）

## コーディング規約
- **SOLID原則**: すべてのコードで適用
- **型安全性**: `any` / `Any` 使用禁止
- **テスト**: TDD、カバレッジ 100% 目標

## バージョン管理
- **VCS**: Jujutsu (jj)
- **コミットメッセージ**: Conventional Commits 形式

## セキュリティ
- **実装完了後**: `/codeguard-security:software-security` 実行必須
```

---

## 5. セクション別テンプレート

### プロジェクト説明（良い例・悪い例）

**❌ 悪い例**: 曖昧で具体性がない

```markdown
# My Project

このプロジェクトは便利なツールです。
```

**✅ 良い例**: 具体的で目的が明確

```markdown
# Task Manager API

チーム向けタスク管理APIサービス。REST APIでタスクのCRUD、メンバー管理、通知機能を提供。Next.jsフロントエンドと連携。
```

---

### コマンド一覧（カテゴリ分け）

**テンプレート**:

```markdown
## コマンド

### 開発
- `npm run dev` — 開発サーバー起動
- `npm run dev:docker` — Docker Compose で全サービス起動

### テスト
- `npm test` — ユニットテスト
- `npm run test:e2e` — E2Eテスト
- `npm run test:watch` — ウォッチモード

### データベース
- `npm run db:migrate` — マイグレーション実行
- `npm run db:seed` — シードデータ投入
- `npm run db:studio` — GUI管理ツール起動

### ビルド・デプロイ
- `npm run build` — プロダクションビルド
- `npm run deploy:staging` — ステージング環境デプロイ
- `npm run deploy:production` — プロダクション環境デプロイ
```

---

### プロジェクト固有の罠（If X then Y 変換）

**変換パターン**:

| 曖昧な指示 | If X then Y 形式 |
|-----------|-----------------|
| 「テストを書いてね」 | **新しい関数を追加した場合 → 対応するユニットテストを同一PRで追加** |
| 「セキュリティに気をつけて」 | **ユーザー入力を受け取る場合 → 必ずバリデーションとサニタイズを実施** |
| 「ドキュメントを更新して」 | **API エンドポイント変更時 → `docs/api-design.md` の OpenAPI 仕様を先に更新** |
| 「環境変数を使って」 | **機密情報（API キー、DB接続文字列）を扱う場合 → 環境変数に格納し `.env.example` に追記** |
| 「エラーハンドリングを追加」 | **外部API呼び出し時 → try-catch でエラーをキャッチし、適切なHTTPステータスコードを返す** |
| 「型安全にして」 | **関数の引数・戻り値 → 明示的な型定義を追加し、`any` を使用しない** |
| 「パフォーマンスを改善」 | **データベースクエリ実行時 → `EXPLAIN` で実行計画を確認し、必要に応じてインデックスを追加** |
| 「アクセシビリティに配慮」 | **ボタン・フォーム要素作成時 → `aria-label` と適切な `role` 属性を設定** |

**テンプレート**:

```markdown
## プロジェクト固有の注意事項

- **新しいAPIエンドポイント追加時 → `docs/api-design.md` に OpenAPI 仕様を先に記述**
- **Prismaスキーマ変更時 → `npm run db:migrate:dry` で影響範囲を確認後、チームに通知**
- **環境変数追加時 → `.env.example` に説明付きで追記**
- **UI コンポーネント作成時 → Storybook にストーリーを作成**
- **認証が必要なエンドポイント → `@UseGuards(AuthGuard)` デコレーターを使用**
- **外部API呼び出し時 → リトライロジックとタイムアウト設定を実装**
- **ファイルアップロード機能 → ファイルサイズ制限（最大10MB）とMIMEタイプ検証を実装**
- **データベースクエリでページネーション → `take` と `skip` を使用し、最大100件まで**
```

---

### 段階的開示（別ファイル参照パターン）

**テンプレート**:

```markdown
## アーキテクチャ

詳細は以下のドキュメントを参照:
- [アーキテクチャ設計](docs/architecture.md) — システム全体の設計思想
- [APIドキュメント](docs/api-design.md) — REST API 仕様（OpenAPI）
- [データベース設計](docs/database-design.md) — ER図とスキーマ設計
- [コーディング規約](docs/coding-guidelines.md) — TypeScript/React コーディング規約
- [デプロイガイド](docs/deployment.md) — CI/CD パイプラインと環境設定

## トラブルシューティング

よくあるエラーと解決方法:
- **ビルドエラー** → `rm -rf node_modules && npm install` で依存関係を再構築
- **E2Eテスト失敗** → Docker コンテナが起動していることを確認
- **マイグレーションエラー** → `npm run db:reset` でデータベースをリセット

詳細は [トラブルシューティングガイド](docs/troubleshooting.md) を参照
```

---

## テンプレート選択ガイド

| プロジェクト規模 | チーム規模 | 推奨テンプレート |
|----------------|-----------|----------------|
| PoC、学習用 | 1人 | ミニマル |
| 小規模プロジェクト | 1-3人 | ミニマル |
| 中規模プロジェクト | 3-10人 | スタンダード |
| 大規模プロジェクト | 10人以上 | スタンダード + 段階的開示 |
| マイクロサービス | チーム分割 | モノレポ |
| 個人設定 | - | claude.local.md / ~/.claude/CLAUDE.md |

---

## テンプレートの拡張ガイドライン

1. **必須3要素を維持**: プロジェクト説明、コマンド、罠（If X then Y）
2. **300行以下厳守**: 超える場合は段階的開示で分離
3. **重要指示は先頭に配置**: `🚨 CRITICAL` セクション
4. **具体的な指示**: 曖昧な表現を避け、If X then Y 形式に変換
5. **定期メンテナンス**: 繰り返しミスが発生したら追記、古い情報は削除
