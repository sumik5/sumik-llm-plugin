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

## モデル戦略（4種）

チームのコスト効率と品質バランスを最適化するため、以下の4戦略から選択します。

| 戦略 | リーダー | メンバー | 用途 | コスト | トークン比率 |
|------|---------|---------|------|--------|------------|
| **Deep** | Opus | Opus | 複雑な問題解決・研究開発・アーキテクチャ設計 | 最高 | 1.0 |
| **Adaptive** 🌟 | Opus | Sonnet | 標準的な機能開発・リファクタリング・調査タスク | バランス最良 | 0.4 |
| **Fast** | Sonnet | Sonnet | 明確な要件の迅速な実装・バグ修正 | 低 | 0.15 |
| **Budget** | Sonnet | Haiku | 定型作業・ドキュメント生成・単純なテスト作成 | 最低 | 0.05 |

**デフォルト推奨: Adaptive** - リーダーの高い推論能力とメンバーの実行効率を両立

### 戦略選択の判断基準

| 状況 | 推奨戦略 | 理由 |
|------|---------|------|
| 要件が曖昧・設計判断が多い | Deep | Opus×Opusで高度な推論能力を維持 |
| 標準的な機能開発 | Adaptive | リーダーが全体設計、メンバーが効率実装 |
| 要件明確・納期重視 | Fast | Sonnet×Sonnetで高速実装 |
| ドキュメント生成・定型作業 | Budget | Sonnet×Haikuでコスト最小化 |

---

## 既存Agent/スキルとの統合

### タチコマ（Tachikoma）の活用

**タチコマをワーカーメンバーとして並列起動します。**

```json
{
  "subagent_type": "sumik:タチコマ",
  "team_name": "user-management",
  "name": "frontend",
  "run_in_background": true
}
```

- タスクベース分散方式: 各タチコマに具体的なタスクを割り当て
- 報告フォーマット: タチコマは完了報告でファイル一覧と品質チェック結果を返す

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
`rules/skill-triggers.md` の「自動検出（ファイル・プロジェクト構成で発動）」セクションを参照し、プロジェクト構成に基づいて適切なスキルをメンバーに割り当てる。

**例:**
- `package.json` に `next` → frontendメンバーに `developing-nextjs` スキルを参照させる
- `package.json` に `@playwright/test` → testerメンバーに `testing-e2e-with-playwright` スキルを参照させる
