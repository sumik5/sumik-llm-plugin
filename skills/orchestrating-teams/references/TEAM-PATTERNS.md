# チーム編成パターン

Agent Team編成の4つのパターンとモデル戦略を提供します。

---

## チーム編成パターン（4種）

### パターン1: feature-dev（機能開発）

**構成:** planner → architect → implementer + tester（並列）

```
使用場面: 新機能の設計から実装まで一貫して開発
- planner: 要件分析・ユーザーストーリー作成
- architect: 技術設計・API仕様・データモデル
- implementer: コード実装（architectの設計に基づく）
- tester: テストケース作成・E2E検証（implementerと並列）

ファイル所有権:
- planner: docs/requirements/*.md
- architect: docs/design/*.md
- implementer: src/**/*.ts (実装コード)
- tester: tests/**/*.test.ts

メンバー数: 4体
依存関係: planner → architect → (implementer + tester 並列)
```

**例: ユーザー管理機能開発**
1. planner: ユーザーストーリー・要件定義
2. architect: DBスキーマ・API設計・コンポーネント設計
3. implementer: フロントエンド・バックエンド実装（architectの設計に基づく）
4. tester: E2Eテストシナリオ作成（implementerと同時並行）

---

### パターン2: investigation（調査・デバッグ）

**構成:** researcher1 + researcher2（並列、異なる観点）

```
使用場面: バグ原因の特定、複数アプローチの検証
- researcher1: フロントエンド視点で調査（ブラウザDevTools、React状態、UI動作）
- researcher2: バックエンド視点で調査（ログ、DB、API通信）
- 各自が異なる仮説を検証し、結果を共有

重要: 同じ視点の並列化は避ける（重複した結果になるため）

ファイル所有権:
- researcher1: 調査結果を docs/investigation/frontend-findings.md に記録
- researcher2: 調査結果を docs/investigation/backend-findings.md に記録

メンバー数: 2体
依存関係: 完全並列（依存なし）
```

**例: パフォーマンス低下の原因調査**
1. researcher1: フロントエンドのレンダリング・状態管理・ネットワークリクエストを調査
2. researcher2: バックエンドのクエリ実行時間・サーバーリソース・キャッシュ効率を調査

---

### パターン3: refactoring（リファクタリング）

**構成:** analyzer → implementer + tester（並列）

```
使用場面: レガシーコードの改善、アーキテクチャ変更
- analyzer: 現状分析・リスク評価・移行計画策定
- implementer: 段階的なコード変更（analyzerの計画に基づく）
- tester: 回帰テスト・動作検証（implementerと並列）

ファイル所有権:
- analyzer: docs/refactoring-plan.md
- implementer: src/**/*.ts (リファクタリング対象コード)
- tester: tests/**/*.test.ts (回帰テスト)

メンバー数: 3体
依存関係: analyzer → (implementer + tester 並列)
```

**例: モノリスからマイクロサービスへの段階的移行**
1. analyzer: 依存関係分析・境界定義・移行優先順位策定
2. implementer: サービス分離・API変更（analyzerの計画に基づく）
3. tester: 既存機能の動作検証・統合テスト（implementerと同時並行）

---

### パターン4: full-stack（フルスタック開発）

**構成:** frontend + backend + tester（完全並列）

```
使用場面: UI、API、テストが独立して開発可能な場合
- frontend: React/Next.jsコンポーネント実装
- backend: REST/GraphQL API実装
- tester: E2Eテスト作成

ファイル所有権:
- frontend: src/components/**, src/pages/**
- backend: src/api/**, src/services/**, src/models/**
- tester: tests/e2e/**

メンバー数: 3体
依存関係: 完全並列（API仕様が事前に決まっている前提）
```

**例: ダッシュボード機能追加**
1. frontend: React Dashboardコンポーネント・グラフ表示・状態管理
2. backend: /api/dashboard エンドポイント・データ集計・認可
3. tester: Playwrightによるダッシュボード表示・インタラクションE2Eテスト

---

### パターン5: scale-out（同一エージェント並列）

**構成:** 同一 subagent_type × N体（完全並列）

```
使用場面: 同一ドメインの独立したサブタスクを高速化したい場合
- 同じ専門タチコマを複数インスタンス起動
- 各インスタンスに異なるファイル/コンポーネントを割り当て
- ファイル所有権パターンが最重要（同一ファイルへの同時書き込み禁止）

ファイル所有権:
- tachikoma-nextjs-1: src/app/dashboard/**
- tachikoma-nextjs-2: src/app/settings/**
- tachikoma-nextjs-3: src/app/profile/**

メンバー数: 2-4体（同一subagent_type）
依存関係: 完全並列（各インスタンスが独立したファイルセットを担当）
```

**例: 複数ページの同時実装**
```
TeamCreate → Task tool × 3（1メッセージで同時発行）:
  1. sumik:タチコマ（Next.js）, name: "page-dashboard", prompt: "ダッシュボードページ実装"
  2. sumik:タチコマ（Next.js）, name: "page-settings", prompt: "設定ページ実装"
  3. sumik:タチコマ（Next.js）, name: "page-profile", prompt: "プロフィールページ実装"
→ 3つのtmux paneで同時進行
```

**例: 複数テストスイートの同時作成**
```
  1. sumik:タチコマ（テスト）, name: "test-auth", prompt: "認証モジュールのテスト作成"
  2. sumik:タチコマ（テスト）, name: "test-api", prompt: "APIエンドポイントのテスト作成"
```

**scale-outの判断基準:**
- 同一ドメインで3つ以上の独立サブタスクがある
- 各サブタスクが異なるファイルセットを操作する
- サブタスク間に依存関係がない
- 効果: N体並列 → 理論上N倍速（ファイル競合がない前提）
- コスト: N体 × トークン消費（scale-outはコスト増になるため、速度優先の場面で使用）

---

## モデル戦略（4種）

チームのコスト効率と品質バランスを最適化するため、以下の4戦略から選択します。

| 戦略 | リーダー | planner | implementer | 用途 | コスト |
|------|---------|---------|-------------|------|--------|
| **Deep** | Opus | Opus | Opus | 複雑な問題解決・研究開発・アーキテクチャ設計 | 最高 |
| **Adaptive** 🌟 | Opus | Opus | Sonnet | 標準的な機能開発・リファクタリング・調査タスク | バランス最良 |
| **Fast** | Sonnet | Sonnet | Sonnet | 明確な要件の迅速な実装・バグ修正 | 低 |
| **Budget** | Sonnet | Sonnet | Haiku | 定型作業・ドキュメント生成・単純なテスト作成 | 最低 |

**デフォルト推奨: Adaptive** - planner は Opus で高い分析・設計能力を維持し、implementer は Sonnet で効率実装

### 戦略選択の判断基準

| 状況 | 推奨戦略 | 理由 |
|------|---------|------|
| 要件が曖昧・設計判断が多い | Deep | 全員Opusで高度な推論能力を維持 |
| 標準的な機能開発 | Adaptive | planner=Opusで分析・設計、implementer=Sonnetで効率実装 |
| 要件明確・納期重視 | Fast | 全員Sonnetで高速実装 |
| ドキュメント生成・定型作業 | Budget | implementer=Haikuでコスト最小化 |

---

## 既存Agent/スキルとの統合

### タチコマ（Tachikoma）の活用

**タチコマをワーカーメンバーとして並列起動します。**

```json
{
  "subagent_type": "sumik:タチコマ（Next.js）",  // ドメインに応じた専門タチコマを選択
  "team_name": "user-management",
  "name": "frontend",
  "run_in_background": true
}
```

- タスクベース分散方式: 各タチコマに具体的なタスクを割り当て
- 報告フォーマット: タチコマは完了報告でファイル一覧と品質チェック結果を返す

### 専門タチコマ選択ガイド

チーム編成時、各メンバーの役割に応じて適切な専門タチコマを選択する:

| 役割 | 推奨 subagent_type | 用途 |
|------|-------------------|------|
| planner | `sumik:タチコマ（アーキテクチャ）` | 設計・計画策定（model: opus） |
| frontend | `sumik:タチコマ（Next.js）` / `sumik:タチコマ（フロントエンド）` | React/UI実装 |
| backend | `sumik:タチコマ（フルスタックJS）` / `sumik:タチコマ（Python）` / `sumik:タチコマ（Go）` | API/ビジネスロジック |
| tester | `sumik:タチコマ（テスト）` / `sumik:タチコマ（E2Eテスト）` | テスト作成 |
| infra | `sumik:タチコマ（インフラ）` / `sumik:タチコマ（Terraform）` / `sumik:タチコマ（AWS）` | インフラ構築 |
| researcher | `sumik:タチコマ（アーキテクチャ）` / `sumik:タチコマ（セキュリティ）` | 調査・分析（読取専用） |
| documenter | `sumik:タチコマ（ドキュメント）` | 技術文書作成 |

**選択判断の基準:**
- プロジェクトの技術スタック（package.json, go.mod等）から判定
- `rules/skill-triggers.md` のルーティング表を参照
- 複数候補がある場合はより専門的な方を優先

### Serena Expertの活用

**トークン効率が重要なタスクにSerena Expertを起動します。**

```json
{
  "subagent_type": "sumik:serena-expert",
  "team_name": "user-management",
  "name": "optimizer",
  "run_in_background": true
}
```

- `/serena` コマンドで構造化された実装
- 適用場面: コンポーネント開発、API実装、テスト作成

### プロジェクト検出スキルとの連携

**チーム編成前に以下のスキルを参照してプロジェクト特性を把握:**

- `developing-nextjs`: Next.js/React検出 → frontend/backendメンバー構成を調整
- `developing-go`: Go検出 → backend実装にGo専門知識を提供
- `testing-code`: テストツール検出 → testerメンバーのツールチェーン設定
- `designing-frontend`: UIライブラリ検出 → frontendメンバーのコンポーネント戦略

**自動検出の活用:**
`rules/skill-triggers.md` のサブエージェントルーティング表を参照し、プロジェクト構成に基づいて適切な**専門タチコマ**をメンバーとして割り当てる。各専門タチコマにはドメインスキルがプリロード済みのため、追加のスキルロード指示は不要。

**例:**
- `package.json` に `next` → メンバーに `sumik:タチコマ（Next.js）` を起用
- `package.json` に `@playwright/test` → テスターに `sumik:タチコマ（E2Eテスト）` を起用
- `.tf` ファイル → インフラに `sumik:タチコマ（Terraform）` を起用
