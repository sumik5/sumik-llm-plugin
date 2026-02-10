# sumik-claude-plugin

**Claude Codeの開発ワークフローを強化する包括的なプラグインシステム**

---

## 概要

Claude Codeの開発効率を最大化するためのプラグイン。Agent、コマンド、スキル、フック、MCPサーバー統合を含み、並列実行モデル、トークン効率化、型安全性、セキュリティファーストのアプローチを実現します。

---

## インストール

```bash
claude plugin add sumik5/sumik-claude-plugin
```

---

## ディレクトリ構成

```
sumik-claude-plugin/
├── .claude-plugin/     # プラグインマニフェスト
│   ├── plugin.json     # プラグインメタデータ
│   └── marketplace.json
├── .mcp.json           # MCPサーバー設定
├── agents/             # Agent定義 (2体)
├── commands/           # スラッシュコマンド (8個)
├── hooks/              # イベントフック (4個)
├── scripts/            # ヘルパースクリプト (1個)
└── skills/             # ナレッジスキル (41個)
```

---

## コンポーネント一覧

### Agents (2体)

| Agent | モデル | 説明 |
|-------|--------|------|
| **タチコマ** (tachikoma) | Sonnet | 実装・実行Agent。フロント/バック/テスト等に適応。並列実行対応(1-4体) |
| **Serena Expert** (serena-expert) | Sonnet | /serenaコマンドを活用したトークン効率重視の開発Agent |

### Commands (8個)

| コマンド | 説明 |
|---------|------|
| `/serena` | トークン効率的な構造化開発 |
| `/serena-refresh` | Serena MCPデータ最新化 |
| `/reload` | CLAUDE.md再読み込み（compaction後のコンテキスト復元） |
| `/pull-request` | PR説明文の自動生成 |
| `/git-tag` | アノテーション付きGitタグ作成 |
| `/changelog` | CHANGELOG自動生成（Keep a Changelog形式） |
| `/generate-user-story` | ユーザーストーリー＋E2Eテストドキュメント生成 |
| `/e2e-chrome-devtools-mcp` | Chrome DevTools MCPによるE2Eテスト実行 |

### Skills (41個)

#### コア開発

| スキル | 説明 |
|--------|------|
| `implementing-as-tachikoma` | タチコマAgent運用ガイド |
| `using-serena` | Serena MCP活用 |
| `writing-clean-code` | 言語非依存のクリーンコードレシピ（SOLID原則・ソフトウェアデザインの法則含む25カテゴリのコードスメル検出・リファクタリング） |
| `enforcing-type-safety` | 型安全性強制（any禁止） |
| `testing-code` | テストファースト（Vitest/RTL/Playwright） |
| `researching-libraries` | ライブラリ調査（車輪の再発明禁止） |
| `securing-code` | セキュアコーディング |

#### アーキテクチャ

| スキル | 説明 |
|--------|------|
| `applying-domain-driven-design` | DDD実践ガイド（戦略的設計・戦術的パターン・イベントストーミング・業務データ分解・ポリグロットDB選択） |
| `modernizing-architecture` | Socio-technicalアーキテクチャモダナイゼーション（戦略・ドメイン設計・チーム組織・トレードオフ分析方法論） |
| `designing-web-apis` | Web API設計ベストプラクティス |
| `building-multi-tenant-saas` | マルチテナントSaaSアーキテクチャ設計ガイド |
| `building-nextjs-saas` | Next.js AI SaaSアプリ構築パターン（認証・決済・AI API・クレジット課金） |
| `implementing-dynamic-authorization` | 動的認可設計（ABAC/ReBAC/PBAC、Cedar、認可アーキテクチャ） |
| `architecting-microservices` | マイクロサービスアーキテクチャパターン設計（CQRS・Event Sourcing・8種のSaga・分散トランザクション・サービス粒度・データ所有権・ワークフロー・コントラクト・メッセージング・レジリエンス・セキュリティ） |
| `understanding-database-internals` | データベース内部構造の包括的リファレンス。ストレージエンジン（Bツリー、LSMツリー、トランザクション）、分散システム（合意アルゴリズム、レプリケーション、一貫性モデル）、DB選択・設計ガイドをカバー |
| `avoiding-sql-antipatterns` | SQLアンチパターン回避（論理設計・物理設計・クエリ・アプリ開発の25パターン） |
| `applying-behavior-design` | 行動変容デザイン（CREATEファネル、3戦略）|

#### フレームワーク

| スキル | 説明 |
|--------|------|
| `developing-nextjs` | Next.js 16 / React 19（React性能最適化・内部メカニズム含む） |
| `developing-go` | Go開発包括ガイド（クリーンコード・デザインパターン・並行処理詳細パターン・内部構造・スケジューラー・実践パターン7分野） |
| `developing-python` | Python 3.13開発（Effective Python 125項目含む） |
| `developing-fullstack-javascript` | フルスタックJS |
| `mastering-typescript` | TypeScript包括ガイド（83項目の実装判断基準 + 型システム・関数・クラス・高度な型・非同期・モジュール・ビルド） |
| `developing-mcp` | MCP (Model Context Protocol) サーバー/クライアント開発・アーキテクチャパターン・セキュリティ強化（脅威モデル・コード硬化・OIDC認証・LLM攻撃対策・エコシステム脅威・実装チェックリスト） |
| `building-adk-agents` | Google ADK (Agent Development Kit) AIエージェント開発ガイド |

#### フロントエンド・デザイン

| スキル | 説明 |
|--------|------|
| `applying-design-guidelines` | UI/UXデザイン設計（視覚デザイン・認知心理学・実践的UIルール101） |
| `designing-frontend` | フロントエンド実装（Storybook・shadcn/ui統合） |
| `implementing-design` | Figmaデザイン→コード |

#### ブラウザ自動化・E2Eテスト

| スキル | 説明 |
|--------|------|
| `automating-browser` | ブラウザ自動化統合（Playwright MCP・CLIエージェント・E2Eテスト） |

#### インフラ・ツール

| スキル | 説明 |
|--------|------|
| `designing-monitoring` | 監視・オブザーバビリティシステム設計（アンチパターン、デザインパターン、レイヤー別戦略、テレメトリーパイプライン、アラート・オンコール・インシデント管理、オブザーバビリティ概念、SLO、サンプリング戦略、成熟度モデル） |
| `managing-docker` | Docker包括的ガイド（Engine内部、ネットワーク、ボリューム、セキュリティ、AI/Wasm含む） |
| `using-next-devtools` | Next.js DevTools |
| `implementing-opentelemetry` | OpenTelemetry計装・Collector・オブザーバビリティ導入 |
| `developing-terraform` | Terraform IaC開発（HCL構文/モジュール設計/ステート管理/AWS構築） |

#### ドキュメント・品質

| スキル | 説明 |
|--------|------|
| `writing-technical-docs` | 技術ドキュメント（7つのC原則） |
| `removing-ai-smell` | AI臭除去（コード・文章の自然化） |
| `crafting-ai-copywriting` | AIコピーライティング（15の心理的プロンプト技法） |
| `writing-latex` | LaTeX文書作成 |
| `generating-google-slides` | Google Slides自動生成（GAS slideDataオブジェクト生成） |
| `authoring-skills` | スキル作成・ソース変換・利用状況レビュー統合ガイド |
| `searching-web` | Web検索（gemini） |
| `reviewing-with-coderabbit` | CodeRabbitコードレビュー |

### Scripts (1個)

| スクリプト | 説明 |
|----------|------|
| `convert-markdown-to-skill.sh` | Markdown→スキル変換スクリプト |

### Hooks (4個)

| フック | トリガー | 説明 |
|-------|---------|------|
| `detect-project-skills` | SessionStart | セッション開始時にプロジェクト構成を検出し、推奨スキルを自動提示 |
| `format-on-save` | PostToolUse | ファイル保存時の自動フォーマット（TypeScript/JSON/Terraform等） |
| `notify-complete` | Stop | タスク完了時のデスクトップ通知 |
| `notify-waiting` | Stop | 待機状態の通知 |

### MCP Servers (10個)

| サーバー | 用途 |
|---------|------|
| serena | コード分析・編集・メモリ管理 |
| next-devtools | Next.js開発ツール |
| deepwiki | GitHub Wiki検索 |
| puppeteer | ブラウザ自動化 |
| chrome-devtools | Chrome DevTools統合 |
| mcp-pandoc | ドキュメント形式変換 |
| shadcn | shadcn/uiコンポーネント管理 |
| docker | Dockerコンテナ管理 |
| terraform | Terraformインフラ管理 |
| sequentialthinking | 複雑な問題の構造化思考 |

---

## 主な特徴

- **並列実行モデル**: タチコマ4体同時起動で独立タスクを並列処理
- **トークン効率化**: /serenaコマンドによる構造化開発
- **型安全性**: any/Any型の使用を厳格に禁止
- **セキュリティファースト**: 実装後のCodeGuard検証を必須化
- **自動フォーマット**: PostToolUseフックによるコード整形
- **Progressive Disclosure**: スキルをSKILL.md + 詳細ファイルに分離

---
