---
description: >-
  Comprehensive AI-assisted development methodology covering prompt engineering,
  context engineering, code generation workflows, quality assurance, collaborative
  debugging, and agent collaboration patterns. MUST load when working with AI coding
  tools or discussing AI-assisted development practices. Use when crafting prompts
  for code generation, managing AI context, reviewing AI-generated code, or
  coordinating multi-agent development workflows. For AI copywriting techniques,
  use crafting-ai-copywriting instead.
---

# developing-with-ai

AI支援開発の体系的メソドロジー。プロンプト駆動開発（Prompt-Driven Development）として知られるこのアプローチは、AIコーディングツールとの効果的な協調作業を可能にする構造化された実践手法です。

## 概要

AI支援開発は、開発者がAIツールと「協働するパートナー」として作業する新しいパラダイムです。単なるコード補完ツールではなく、要件分析・設計・実装・テスト・デバッグ・ドキュメンテーションの全ライフサイクルにわたってAIを統合します。

**重要な前提：** AIツールは「高度に有能なジュニア開発者」として扱うべきです。パターン認識・コード生成・論理的推論に優れますが、暗黙の要件を推測する能力や文脈的理解力には限界があります。明示的な指示と十分な文脈提供が成功の鍵です。

**詳細は以下のリファレンスファイルを参照：**
- `references/PROMPT-ENGINEERING.md`: プロンプト設計の詳細手法
- `references/CONTEXT-ENGINEERING.md`: コンテキスト設計の詳細手法
- `references/DESIGN-AND-GENERATION.md`: 設計・コード生成ワークフロー
- `references/QUALITY-AND-DEBUGGING.md`: 品質保証・デバッグ手法
- `references/AGENT-AND-PROJECT.md`: エージェント協調・プロジェクト管理
- `references/FOUNDATIONS.md`: AI支援開発の基礎知識

---

## プロンプトエンジニアリング5原則

AIツールへの指示（プロンプト）の品質が、生成されるコードの品質を直接決定します。

| 原則 | 説明 | Bad例 | Good例 |
|------|------|-------|--------|
| **Clarity（明確性）** | 曖昧さを排除し、具体的で実行可能な指示を提供 | "Refactor this code" | "Remove the nested if statements in this JavaScript function and replace them with early returns to improve readability" |
| **Context（文脈）** | 技術仕様・プロジェクト要件・既存コードベースのパターンを提供 | "Create a sort function" | "Create a TypeScript function that sorts an array of product objects by price in ascending order" |
| **Constraints（制約）** | 技術的制約（ライブラリ・パフォーマンス要件・セキュリティ標準）を明示 | "Write an authentication function" | "Create a Node.js function that validates JWT tokens for user authentication in a microservices architecture" |
| **Examples（例示）** | 望ましいパターン・コーディングスタイル・実装アプローチを具体例で示す | （例なし） | （APIエンドポイントの既存実装例を提示） |
| **Feedback Loops（フィードバックループ）** | 生成結果を評価し、不足要素を指摘して段階的に改善 | （1回の試行で諦める） | 「前回の実装に加えて、`+`記号を含むメールアドレスも処理してください」 |

**詳細：** `references/PROMPT-ENGINEERING.md` 参照

---

## プロンプトテンプレート

以下は一般的な開発タスクに対応する再利用可能なプロンプトテンプレートです。

| テンプレート | 構造 | 用途 |
|------------|------|------|
| **コード生成** | `Create a [language] [component type] that [primary functionality] with [specific features], handling [edge cases]. It should integrate with [existing system] and follow [coding standards]` | 新規コンポーネント・機能の実装 |
| **コードレビュー** | `Review this [language] code for [quality attributes]. Check for [specific concerns] and suggest improvements aligned with [project standards]` | AI支援コードレビュー |
| **デバッグ** | `Help fix this [language] code that [error description]. The current behavior is [observation], but the expected behavior is [expectation]. Error message: [exact error text]` | バグ修正・トラブルシューティング |
| **リファクタリング** | `Improve this [language] code by [improvement goals]. Focus on [primary concerns] while maintaining [requirements]. Consider applying [patterns/techniques]` | コード品質改善 |
| **ドキュメント** | `Create [documentation type] for this [language] code following [documentation standard]. Include [required sections] and focus on [target audience] needs` | ドキュメント作成・更新 |

**詳細：** `references/PROMPT-ENGINEERING.md` 参照

---

## コンテキストエンジニアリング4原則

プロンプトレベルの文脈管理を超えた、プロジェクト・組織レベルの体系的な文脈設計手法です。

| 原則 | 説明 | 実装方法 |
|------|------|---------|
| **Persistence（永続性）** | 文脈は個別セッションを超えて永続化され、時間とともに蓄積される価値を持つ | リポジトリ内`contexts/`ディレクトリ、外部Wiki、コード内埋め込み |
| **Clarity（明確性）** | 構造化されたコミュニケーションパターンで混乱を排除 | 標準化されたテンプレート・用語統一 |
| **Evolution（進化）** | プロジェクト理解の深化とともに文脈システムも適応・改善 | 定期レビュー・バージョン管理 |
| **Efficiency（効率性）** | 投資対効果を最適化し、測定可能な生産性向上を実現 | コンテキスト再利用・チーム標準化 |

### コンテキスト管理戦略

**プログレッシブコンテキスト構築（3フェーズ）：**
1. **Foundation（基盤）**: プロジェクトの技術スタック・主要制約を確立
2. **Expansion（拡張）**: 機能要件・技術仕様を追加
3. **Refinement（洗練）**: エッジケース・最適化・高度な考慮事項を組み込む

**コンテキストスタック（保存場所）：**
- **リポジトリ内**: `contexts/` ディレクトリに Markdown ファイルとして保存（コードとバージョン同期）
- **外部 Wiki**: 規制要件・ネットワーク図など組織横断的な知識
- **ソースコード埋め込み**: ファイル内コメントで文脈参照を直接記述

**コンテキスト要約テクニック：**
- 優先度ベースフィルタリング
- 時系列フィルタリング（最近の議論を強調）
- スコープベースフィルタリング（詳細を削除して高レベル情報を保持）

**詳細：** `references/CONTEXT-ENGINEERING.md` 参照

---

## AI支援開発ライフサイクル

AI支援開発は全工程でAIを統合します。

| フェーズ | AI活用方法 | 主要成果物 |
|---------|-----------|----------|
| **要件分析** | 自然言語要件の構造化・ユーザーストーリー生成 | 要件仕様書・ユーザーストーリー |
| **アーキテクチャ設計** | システム設計の提案・デザインパターン適用・トレードオフ分析 | アーキテクチャ図・API仕様（OpenAPI） |
| **コード生成** | スキャフォールディング・機能実装・テストコード生成 | 動作するコード・ユニットテスト |
| **品質保証（QA）** | Three-pass review・Self-critique・Multi-perspective review | レビューレポート・改善提案 |
| **デバッグ** | エラー診断・修正提案・テストケース生成 | バグ修正・デバッグログ |
| **ドキュメント** | API ドキュメント・README・コメント生成 | ドキュメント一式 |

**詳細：** `references/DESIGN-AND-GENERATION.md` 参照

---

## コード生成ワークフロー4パターン

| パターン | 用途 | 主要ステップ |
|---------|------|------------|
| **Feature Implementation（機能実装）** | 新規機能の段階的実装 | 1. 要件確認 → 2. 設計提案 → 3. スキャフォールド → 4. ロジック実装 → 5. テスト生成 |
| **Scaffolding Solution（スキャフォールディング）** | プロジェクト初期化・ディレクトリ構造作成 | 1. 技術スタック選定 → 2. ディレクトリ構造生成 → 3. 設定ファイル配置 → 4. 基本テンプレート配置 |
| **Legacy Integration（レガシー統合）** | 既存システムへの新規コード統合 | 1. 既存コード分析 → 2. 統合ポイント特定 → 3. アダプタ層設計 → 4. 段階的移行 |
| **Specification-First（仕様先行）** | OpenAPI等の仕様書からコード生成 | 1. 仕様書作成 → 2. スタブ生成 → 3. ビジネスロジック実装 → 4. 統合テスト |

**Feature Implementation の詳細例（To-Do アプリ）：**
1. **Ideation**: 「シンプルなTo-Do機能を設計してください。タスク追加・完了マーク・削除が可能です」
2. **Development**: 「React コンポーネントを作成。Material-UI使用、ステート管理はuseState」
3. **Testing**: 「Jest + React Testing Library でテストスイート作成」

**詳細：** `references/DESIGN-AND-GENERATION.md` 参照

---

## 品質保証フレームワーク

AI生成コードの品質を体系的に保証する4つの手法。

| 手法 | 説明 | 適用場面 |
|------|------|---------|
| **Three-pass review（3パスレビュー）** | 1. 機能性チェック → 2. 統合性チェック → 3. エッジケース検証 | 全コード生成後の標準レビュー |
| **Self-critique（自己批評）** | AIに生成コードを自己評価させ、改善点を指摘させる | 複雑なロジック・セキュリティが重要な箇所 |
| **Multi-perspective（多視点レビュー）** | 「セキュリティ専門家」「パフォーマンスエンジニア」等の異なるペルソナでレビュー | ミッションクリティカルなコード |
| **Continuous quality dialogue（継続的品質対話）** | コード生成中にリアルタイムで品質基準を確認・修正 | 長時間の実装セッション |

**AI生成コードの一般的エラーパターン：**
- 幻覚ライブラリ/API（存在しないライブラリや非推奨APIの使用）
- 非推奨パターンの適用
- セキュリティ脆弱性（SQL インジェクション・XSS 対策不足）
- パフォーマンス最適化の欠如
- エッジケース処理の不足

**詳細：** `references/QUALITY-AND-DEBUGGING.md` 参照

---

## エージェント協調スペクトラム

AIツールとの協調レベルは段階的に進化します。

| レベル | 特徴 | 適用場面 | 例 |
|--------|------|---------|-----|
| **Chat-based assistant（チャット型アシスタント）** | 1回限りの質問・回答型 | 簡単な質問・コードスニペット生成 | ChatGPT・Claude での単発プロンプト |
| **Workflow-based system（ワークフロー型システム）** | 構造化されたタスクフローに沿った複数ステップの作業 | 機能実装・リファクタリング | Claude Code でのタスク分解・段階的実装 |
| **Autonomous agent（自律エージェント）** | 目標設定後、AIが自律的にタスク分解・実行・エラー修正 | 大規模プロジェクト・継続的統合 | Agent Mode（端末出力監視・自動エラー修正） |

**タチコマシステム（マルチエージェント並列実行）との統合：**
- Claude Code 本体が計画・設計を担当
- 複数のタチコマ Agent が並列実装を実行
- 各タチコマは `docs/plan-xxx.md` から担当範囲・要件を取得
- 完了報告ごとに Claude Code が進捗を統合

**詳細：** `references/AGENT-AND-PROJECT.md` 参照

---

## ユーザー確認の原則（AskUserQuestion）

AIツールは推測ではなく明示的な確認を求めるべき場面があります。

### 確認すべき場面

| 状況 | 理由 | 確認方法 |
|------|------|---------|
| **複数のアプローチが可能** | ユーザーのニーズに最適なアプローチを選択するため | AskUserQuestion で選択肢を提示 |
| **アーキテクチャ決定が必要** | プロジェクト全体に影響する重要な設計判断 | 設計案を複数提示して選択を求める |
| **コンテキスト戦略の選択** | リポジトリ内・外部Wiki・コード埋め込みのどれを使うか | チーム状況に応じた最適解を確認 |

### 確認不要な場面

| 状況 | 理由 |
|------|------|
| **プロンプト5原則の適用** | 基本原則は常に適用すべき標準ルール |
| **基本テンプレートの選択** | コード生成・デバッグ等の標準テンプレートは自明 |
| **明示的な指示がある場合** | ユーザーが既に具体的な要求を明示している |

---

## プロンプトエンジニアリング高度テクニック

### AUTOMATフレームワーク

構造化されたプロンプト構築フレームワーク：

- **A**: Act as（役割設定）: "Senior backend developer with authentication expertise"
- **U**: User persona（対象ユーザー）: "Mobile app users accessing financial data"
- **T**: Targeted action（具体的タスク）: "Implement a secure login endpoint with JWT"
- **O**: Output definition（期待する出力）: "Provide routes, middleware, error handling, unit tests"
- **M**: Mode/Tonality/Style（スタイル）: "Use async/await, descriptive names, JSDoc comments"
- **A**: Atypical cases（エッジケース）: "Handle brute force detection and account lockout"
- **T**: Topic Whitelisting（技術制約）: "Use Express.js, MongoDB, JWT, bcrypt"

### CO-STARフレームワーク

チーム協働重視のフレームワーク：

- **C**: Context（プロジェクト背景）
- **O**: Objective（開発目標）
- **S**: Style & Tone（コーディング規約）
- **T**: Technical Constraints（技術制約）
- **A**: Audience（チームメンバー・エンドユーザー）
- **R**: Response Format（期待するコード構造）

### Chain of Thought（思考の連鎖）

段階的な推論を明示的に要求する手法：

```
"Implement user authentication. Let's approach this systematically:
1. First, design the database schema
2. Then, create the authentication middleware
3. Finally, implement the login/logout endpoints
Walk through each step and explain your reasoning."
```

### Few-shot Learning（少数例学習）

既存コード例を提示してパターンを学習させる：

```
"I need to create a new API endpoint based on the following examples:

Example 1:
[既存エンドポイントのコード]

Example 2:
[別の既存エンドポイントのコード]

Create a similar endpoint for [新機能]."
```

**詳細：** `references/PROMPT-ENGINEERING.md` 参照

---

## ドメイン別プロンプト戦略

### フロントエンド開発

- **アーティファクト駆動**: ワイヤーフレーム・Figma URL を直接プロンプトに含める
- **デザインシステム参照**: 既存コンポーネントライブラリの URL を文脈に追加
- **プログレッシブエンハンスメント**: コンポーネント単位で段階的に構築

### バックエンド開発

- **仕様先行（Specification-First）**: OpenAPI 仕様を添付してから実装生成
- **パフォーマンスメトリクス明示**: リクエスト量・レイテンシ要件を数値で指定
- **ERD 参照**: データベーススキーマ図を文脈に含める

### データサイエンス・分析

- **サンプルデータ提供**: 実データの一部またはモックデータを提示
- **分析目標の明確化**: 統計的手法・機械学習モデルの選択基準を事前に定義

**詳細：** `references/PROMPT-ENGINEERING.md` 参照

---

## プロンプト効果測定

体系的な評価で継続的改善を実現：

| メトリクス | 測定方法 | 目標 |
|----------|---------|------|
| **Time to Solution（解決までの時間）** | 最初のプロンプトから満足解に至るまでの時間 | 短縮 |
| **Iteration Count（反復回数）** | 許容可能な結果を得るまでのプロンプト修正回数 | 6回未満 |
| **Solution Accuracy（解の正確性）** | デプロイ前に必要な手動修正の程度 | 80%以上 |
| **Code Quality Metrics（コード品質）** | 循環的複雑度・Lint エラー・ドキュメント品質 | プロジェクト基準準拠 |

チームダッシュボードで可視化し、プロンプト技術の継続的改善を促進します。

**詳細：** `references/PROMPT-ENGINEERING.md` 参照

---

## コンテキスト品質フレームワーク

コンテキストの健全性を体系的に評価する4次元：

| 次元 | 定義 | 測定方法 |
|------|------|---------|
| **Consistency（一貫性）** | 用語・構造・詳細レベルが統一されている | 用語の分散・テンプレート準拠率 |
| **Completeness（完全性）** | 必要な情報がすべて含まれている | AI が追加情報を要求する回数 |
| **Accuracy（正確性）** | 現在のプロジェクト状態を正しく反映 | 手動修正が必要なAI生成コードの割合 |
| **Relevance（関連性）** | 開発目標に直接影響する情報のみを含む | AI支援コミット数 / 全コミット数 |

**コンテキスト劣化パターンの早期検出：**
- **Drift（ドリフト）**: 文脈がプロジェクト現状から乖離
- **Fragmentation（断片化）**: 情報が複数箇所に分散
- **Staleness（陳腐化）**: プロジェクト進化に追従していない

**詳細：** `references/CONTEXT-ENGINEERING.md` 参照

---

## リファレンスファイル一覧

| ファイル | 内容 |
|---------|------|
| [`PROMPT-ENGINEERING.md`](references/PROMPT-ENGINEERING.md) | プロンプト設計の詳細（テンプレート集・フレームワーク・ドメイン別戦略・測定手法） |
| [`CONTEXT-ENGINEERING.md`](references/CONTEXT-ENGINEERING.md) | コンテキスト設計の詳細（保存方法・品質フレームワーク・劣化パターン・階層化戦略） |
| [`DESIGN-AND-GENERATION.md`](references/DESIGN-AND-GENERATION.md) | 設計・コード生成の詳細（アーキテクチャ決定・4つのワークフロー・仕様先行開発） |
| [`QUALITY-AND-DEBUGGING.md`](references/QUALITY-AND-DEBUGGING.md) | QA・デバッグの詳細（レビュー手法・テスト戦略・エラーパターン・デバッグ対話） |
| [`AGENT-AND-PROJECT.md`](references/AGENT-AND-PROJECT.md) | エージェント協調・PM の詳細（ペアプログラミング・マルチエージェント・プロジェクトスケール） |
| [`FOUNDATIONS.md`](references/FOUNDATIONS.md) | 基礎知識（AI-human協働の進化・AIツール能力・環境セットアップ・人間の役割） |

---

## 関連スキル

- `implementing-as-tachikoma`: タチコマ Agent としての実装手法（マルチエージェント並列実行）
- `using-serena`: Serena MCP によるトークン効率的なコード編集
- `crafting-ai-copywriting`: AI ライティング技術（マーケティング・コンテンツ制作）
- `researching-libraries`: ライブラリ調査（AI支援開発前の事前調査必須）
