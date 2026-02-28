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
├── agents/             # Agent定義 (22体)
├── commands/           # スラッシュコマンド (11個)
├── hooks/              # イベントフック (4個)
├── scripts/            # ヘルパースクリプト (3個)
└── skills/             # ナレッジスキル (88個)
```

---

## コンポーネント一覧

### Agents (22体)

| Agent | モデル | 説明 |
|-------|--------|------|
| **タチコマ** (tachikoma) | Sonnet | 汎用実行Agent。専門タチコマでカバーされないタスクや複数ドメイン横断タスクを担当。並列実行対応(1-4体) |
| **Serena Expert** (serena-expert) | Sonnet | /serenaコマンドを活用したトークン効率重視の開発Agent |
| **タチコマ（Next.js）** (tachikoma-nextjs) | Sonnet | Next.js 16/React 19専門。App Router・Server Components・Turbopack・next-devtools統合 |
| **タチコマ（デザイン）** (tachikoma-design) | Sonnet | Figma MCP全面活用のデザイン→コード変換専門。Figma Make統合・Code Connect・Design System Rules・デザイントークン同期 |
| **タチコマ（フロントエンド）** (tachikoma-frontend) | Sonnet | フロントエンドUI/UX専門。shadcn/ui・Storybook・Figma→コード変換・データビジュアライゼーション |
| **タチコマ（TypeScript）** (tachikoma-typescript) | Sonnet | TypeScript型システム専門。高度な型パターン・ジェネリクス・条件型・GoFデザインパターン |
| **タチコマ（フルスタックJS）** (tachikoma-fullstack-js) | Sonnet | フルスタックJS専門。NestJS/Express・REST API設計・構造化ログ |
| **タチコマ（Python）** (tachikoma-python) | Sonnet | Python専門。Python 3.13+・uv/ruff/mypy・FastAPI/FastMCP・Google ADKエージェント構築 |
| **タチコマ（Go）** (tachikoma-go) | Sonnet | Go専門。concurrencyパターン・インターフェース設計・エラーハンドリング・GoFパターン・Go内部構造 |
| **タチコマ（Bash）** (tachikoma-bash) | Sonnet | Bashシェルスクリプト専門。strict mode・I/Oパイプライン・プロセス制御・セキュリティ・ShellCheck |
| **タチコマ（アーキテクチャ）** (tachikoma-architecture) | Opus | アーキテクチャ設計専門（読み取り専用）。DDD・マイクロサービス・トレードオフ分析。設計ドキュメント作成のみ |
| **タチコマ（セキュリティ）** (tachikoma-security) | Opus | セキュリティレビュー専門（読み取り専用）。OWASP・サーバーレスセキュリティ・IAM・動的認可。レポート作成のみ |
| **タチコマ（オブザーバビリティ）** (tachikoma-observability) | Sonnet | オブザーバビリティ専門。OpenTelemetry計装・SLO/SLI設計・アラート・ログパイプライン |
| **タチコマ（ドキュメント）** (tachikoma-document) | Sonnet | ドキュメント作成専門。技術文書・LaTeX・Zenn記事・AIコピーライティング。コード実装なし |
| **タチコマ（インフラ）** (tachikoma-infra) | Sonnet | インフラ/DevOps専門。Docker・Compose・CI/CDパイプライン・Blue-Green/Canaryデプロイ |
| **タチコマ（Terraform）** (tachikoma-terraform) | Sonnet | Terraform IaC専門。HCL・モジュール設計・state管理・Terragruntパターン・Terraform MCP活用 |
| **タチコマ（AWS）** (tachikoma-aws) | Sonnet | AWS専門。Lambda・API Gateway・DynamoDB・CDK・EKS・Bedrock・セキュリティ・FinOps |
| **タチコマ（Google Cloud）** (tachikoma-google-cloud) | Sonnet | Google Cloud専門。Cloud Run・BigQuery・VPC・Memorystore・Zero Trust・データエンジニアリング |
| **タチコマ（データベース）** (tachikoma-database) | Sonnet | データベース専門。リレーショナルDB設計・正規化・SQLアンチパターン回避・クエリ最適化・DB内部構造 |
| **タチコマ（AI/ML）** (tachikoma-ai-ml) | Sonnet | AI/ML開発専門。Vercel AI SDK・LangChain.js・RAGシステム・MCP開発・LLMOps運用 |
| **タチコマ（テスト）** (tachikoma-test) | Sonnet | ユニット/インテグレーションテスト専門。TDD・Vitest/Jest・React Testing Library・モック戦略 |
| **タチコマ（E2Eテスト）** (tachikoma-e2e-test) | Sonnet | E2Eテスト・ブラウザ自動化専門。Playwright Test・POM・ビジュアルテスト・アクセシビリティ・CI/CD統合 |

### Commands (11個)

| コマンド | 説明 |
|---------|------|
| `/serena` | トークン効率的な構造化開発 |
| `/serena-refresh` | Serena MCPデータ最新化 |
| `/reload` | CLAUDE.md再読み込み（compaction後のコンテキスト復元） |
| `/pull-request` | PR説明文の自動生成 |
| `/git-tag` | アノテーション付きGitタグ作成 |
| `/changelog` | CHANGELOG自動生成（Keep a Changelog形式） |
| `/commit-msg` | 会話履歴とステージ済み変更からConventional Commitsコミットメッセージ生成 |
| `/generate-user-story` | ユーザーストーリー＋E2Eテストドキュメント生成 |
| `/e2e-chrome-devtools-mcp` | Chrome DevTools MCPによるE2Eテスト実行 |
| `/difit` | GitHub風差分ビューア（difit）でコードdiff表示 |
| `/react-doctor` | React コード品質診断（react-doctor CLI、0-100スコア、セキュリティ・パフォーマンス・正確性） |

### Skills (88個)

#### コア開発

| スキル | 説明 |
|--------|------|
| `implementing-as-tachikoma` | タチコマAgent運用ガイド |
| `using-serena` | Serena MCP活用 |
| `writing-clean-code` | 言語非依存のクリーンコードレシピ（SOLID原則・ソフトウェアデザインの法則含む25カテゴリのコードスメル検出・リファクタリング） |
| `enforcing-type-safety` | 型安全性強制（any禁止） |
| `testing-code` | テストファースト（Vitest/Playwright）。RTL固有は`developing-react`参照 |
| `testing-web-apis` | Web APIテスト戦略（設計テスト・探索テスト・コントラクトテスト・自動化・パフォーマンス・セキュリティ・本番モニタリング） |
| `conducting-ab-tests` | A/Bテスト・オンラインコントロール実験（実験設計・統計分析・OEC・信用性検証・実験プラットフォーム・実験文化） |
| `researching-libraries` | ライブラリ調査（車輪の再発明禁止） |
| `securing-code` | セキュアコーディング（OWASP Top 10、インジェクション対策、認証・認可、Web penetration testing knowledge含む） |
| `securing-serverless` | サーバーレスセキュリティ包括ガイド（AWS Lambda・Google Cloud Run・Azure Functionsの攻撃・防御パターン、コード注入・SSRF・権限昇格・シークレット窃取、IAM最小権限、認証トークン管理、計7リファレンスファイル） |
| `securing-ai-development` | AI開発セキュリティ戦略（信頼フレームワーク、適応型ガードレール、AI-BOM、AI-SPM、ガバナンス、クロスファンクショナル所有権） |
| `developing-with-ai` | AI支援開発メソドロジー（プロンプトエンジニアリング・コンテキストエンジニアリング・コード生成・QA・デバッグ・エージェント協調） |
| `using-claude-code-as-pm` | PM向けClaude Code活用ガイド（コードベース調査・バグトリアージ・競合分析・フィードバック分析・要件生成・PMワークフロー自動化） |
| `applying-semantic-versioning` | SemVer 2.0.0仕様準拠バージョン判断ガイド（MAJOR/MINOR/PATCH判定・プレリリース・範囲指定・よくある誤り） |
| `writing-conventional-commits` | Conventional Commits 1.0.0準拠コミットメッセージガイド（type/scope/BREAKING CHANGE判定・SemVer連携） |
| `managing-claude-md` | CLAUDE.md管理（8原則、プログレッシブ・ディスクロージャー、生きたドキュメント運用） |
| `using-codex` | Codex CLI（OpenAI）連携（コード相談・レビュー・設計相談・バグ調査） |
| `reviewing-plans-with-codex` | Codex CLI (gpt-5.3-codex) によるプランファイルレビュー（初回レビュー＋resume再レビュー） |
| `reviewing-code` | コードレビュー方法論（PRの構成・効果的なコメント技法・TWA・アンチパターン対策） |
| `converting-agents-to-codex` | Claude Code Agent定義（.md）をCodexマルチエージェント形式（config.toml + agent .toml）に変換 |

#### アーキテクチャ

| スキル | 説明 |
|--------|------|
| `applying-domain-driven-design` | DDD実践ガイド（戦略的設計・戦術的パターン・イベントストーミング・業務データ分解・ポリグロットDB選択） |
| `modernizing-architecture` | Socio-technicalアーキテクチャモダナイゼーション（戦略・ドメイン設計・チーム組織・トレードオフ分析方法論） |
| `designing-web-apis` | Web API設計ベストプラクティス |
| `developing-api-spec-first` | API仕様ファースト開発方法論（仕様記述・E2Eテストフレームワーク・技術的負債返済・防御的プログラミング） |
| `building-multi-tenant-saas` | マルチテナントSaaSアーキテクチャ設計ガイド |
| `building-nextjs-saas` | Next.js AI SaaSアプリ構築パターン（認証・決済・AI API・クレジット課金） |
| `implementing-dynamic-authorization` | 動的認可設計（ABAC/ReBAC/PBAC、Cedar、認可アーキテクチャ） |
| `architecting-microservices` | マイクロサービスアーキテクチャパターン設計（CQRS・Event Sourcing・8種のSaga・分散トランザクション・サービス粒度・データ所有権・ワークフロー・コントラクト・メッセージング・レジリエンス・セキュリティ） |
| `architecting-micro-frontends` | マイクロフロントエンドアーキテクチャ（垂直/水平分割、Module Federation/iframe/Web Components/SSR/ESI構成パターン、意思決定フレームワーク、組織導入） |
| `understanding-database-internals` | データベース内部構造の包括的リファレンス。ストレージエンジン（Bツリー、LSMツリー、トランザクション）、分散システム（合意アルゴリズム、レプリケーション、一貫性モデル）、DB選択・設計ガイドをカバー |
| `avoiding-sql-antipatterns` | SQLアンチパターン回避（論理設計・物理設計・クエリ・アプリ開発の25パターン） |
| `designing-relational-databases` | リレーショナルDB設計ガイド（エンティティモデリング・ER図・正規化1NF-BCNF・インデックス・非正規化・PostgreSQL実装: マイクロサービスアーキテクチャ・ACID/トランザクション・関数/プロシージャ・AAAセキュリティ） |
| `applying-behavior-design` | 行動変容デザイン（CREATEファネル、3戦略）|
| `building-green-software` | グリーンソフトウェアエンジニアリング（カーボン効率・運用効率・カーボンアウェアネス・測定方法論・GSMM・グリーンAI） |
| `building-rag-systems` | RAGシステム構築ガイド（11種データソース読み込み・5種チャンキング戦略・パイプラインアーキテクチャ・Python実装） |
| `architecting-data` | データアーキテクチャパターン（Read-Side最適化、CQRS、CDC、Event Sourcing、キャッシュ戦略） |
| `practicing-llmops` | LLMOps運用フレームワーク（データ・モデル適応・API・評価・セキュリティ・スケーリング） |
| `analyzing-software-tradeoffs` | ソフトウェア設計トレードオフ分析（コードレベル: 重複・例外処理・柔軟性・最適化、API: 使いやすさ・バージョニング、分散システム: 一貫性・配信セマンティクス、メタ判断: ライブラリ選定・トレンド評価・日時データ・12リファレンスファイル） |

#### フレームワーク

| スキル | 説明 |
|--------|------|
| `developing-react` | React 19.x 開発ガイド（Internals・パフォーマンスルール47+・アニメーション・RTLテスト） |
| `remotion-best-practices` | Remotion動画作成ベストプラクティス（React、Three.js、アニメーション、キャプション） |
| `developing-nextjs` | Next.js 16.x開発ガイド（App Router・Server Components・Cache Components・Turbopack・実践パターン集）。Route Segment・Parallel/Intercepting Routes・Prisma・NextAuth.js・Server Actions・4種キャッシュ戦略を含む10リファレンスファイル。React固有は`developing-react`参照 |
| `developing-go` | Go開発包括ガイド（クリーンコード・デザインパターン・並行処理詳細パターン・内部構造・スケジューラー・実践パターン7分野・nilハンドリング・テンプレートエンジン・34リファレンスファイル） |
| `developing-python` | Python 3.13開発（Effective Python 125項目・実践パターン50問・SEプロセス: SDLC/方法論/システムモデリング/プロジェクト実装パターン/API設計・デプロイ含む） |
| `developing-bash` | Bashシェルスクリプティング・自動化ガイド（基礎、制御構造、I/O、プロセス制御、テスト、セキュリティ、パターン） |
| `developing-fullstack-javascript` | フルスタックJS |
| `mastering-typescript` | TypeScript包括ガイド（83項目の実装判断基準 + 型システム・関数・クラス・高度な型・非同期・モジュール・ビルド） |
| `developing-mcp` | MCP (Model Context Protocol) サーバー/クライアント開発・アーキテクチャパターン・セキュリティ強化（脅威モデル・コード硬化・OIDC認証・LLM攻撃対策・エコシステム脅威・実装チェックリスト） |
| `building-adk-agents` | Google ADK (Agent Development Kit) AIエージェント開発ガイド（Agent、Tool、Runner、Session、Memory、Plugin System、Grounding、Context Management、Session Rewind/Resume、Action Confirmations、Event System、GKE Deployment含む9リファレンスファイル） |
| `integrating-ai-web-apps` | Vercel AI SDK + LangChain.js + MCPによるWebアプリAI統合 |

#### フロントエンド・デザイン

| スキル | 説明 |
|--------|------|
| `applying-design-guidelines` | UI/UXデザイン設計（視覚デザイン・認知心理学・実践的UIルール101） |
| `designing-frontend` | フロントエンド実装（Storybook・shadcn/ui統合） |
| `implementing-design` | Figmaデザイン→コード |
| `implementing-figma` | Figma MCP統合・基本/高度ワークフロー・Code Connect・デザイントークン同期 |
| `designing-data-visualizations` | データビジュアライゼーション原則（チャート選択・カラースケール・デザインベストプラクティス・ストーリーテリング） |
| `styling-with-tailwind` | Tailwind CSSスタイリング方法論（v4プライマリ・ユーティリティファースト思想・セットアップ・モディファイア・コンポーネント設計・カスタマイズ・デザインシステム構築） |

#### ブラウザ自動化・E2Eテスト

| スキル | 説明 |
|--------|------|
| `automating-browser` | Browser Agent CLIによるブラウザ操作自動化（セマンティックロケーター、状態永続化、ネットワーク傍受） |
| `testing-e2e-with-playwright` | Playwright Testによる包括的E2Eテスト（ロケーター戦略・フィクスチャ/POM・モッキング・エミュレーション・信頼性・CI/CD・拡張・アクセシビリティ・ビジュアルリグレッション・認証・フォーム・AI生成・実践パターン） |

#### インフラ・ツール

| スキル | 説明 |
|--------|------|
| `designing-monitoring` | 監視・オブザーバビリティシステム設計（アンチパターン、デザインパターン、レイヤー別戦略、テレメトリーパイプライン、アラート・オンコール・インシデント管理、オブザーバビリティ概念、SLO、サンプリング戦略、成熟度モデル） |
| `developing-aws` | AWS開発包括ガイド（システム設計・CDP57パターン・VPCアーキテクチャ・エンタープライズ基盤・14業務システム・移行戦略・サーバーレス・CDK・EKS・SRE運用・FinOps/CCoE・セキュリティ・Bedrock GenAI・32リファレンスファイル） |
| `developing-google-cloud` | Google Cloud 開発・セキュリティ・データエンジニアリング・ネットワーク・キャッシング包括ガイド（Cloud Runデプロイ + GCPプラットフォームセキュリティ深掘り: IAM・VPC・KMS・DLP・SCC・DevSecOps CI/CD・Zero Trust/BeyondCorp・Anthos・Incident Response + データエンジニアリング + ネットワークエンジニアリング: VPC設計・ハイブリッド接続・LB/CDN・ネットワーク監視・Traffic Director/Service Mesh + Memorystore: マネージドRedis/Memcachedキャッシング・パフォーマンスエンジニアリング・レジリエンス・32リファレンスファイル） |
| `managing-docker` | Docker包括的ガイド（Engine内部、ネットワーク、ボリューム、セキュリティ、AI/Wasm、開発ワークフロー、DB連携、監視/ログ、デプロイ戦略含む・14リファレンスファイル） |
| `using-next-devtools` | Next.js DevTools |
| `implementing-opentelemetry` | OpenTelemetry計装・Collector・オブザーバビリティ導入 |
| `implementing-logging` | アプリケーションログ実装ガイド（ログ設計原則・構造化ログ・収集アーキテクチャ・分析・セキュリティログ・AI/MLログ分析） |
| `developing-terraform` | Terraform/Terragrunt IaC開発（HCL・モジュール・ステート・Terragrunt・mise・AWS/GCP） |
| `managing-keycloak` | Keycloak IAM包括ガイド（OIDC/SAML・SSO・Realm/Client/User管理・認証フロー・MFA・認可ポリシー・JWT Token管理・アプリ統合・Docker/K8sデプロイ・SPI拡張） |
| `practicing-devops` | DevOps方法論・IaCツール選定・オーケストレーション比較・CI/CD・プラットフォームエンジニアリング |
| `managing-sdn-with-ai` | AI × SDN/SD-WAN管理ガイド（AIエージェントアーキテクチャ・SDN運用最適化・セキュリティ・インフラ自動化・SD-WAN・5リファレンスファイル） |
| `using-anki-mcp` | Anki MCP Server統合（デッキ管理・カードレビュー・ノートタイプ・メディア管理・GUI統合） |
| `using-drawio-mcp` | draw.io MCP Server統合（XML/CSV/Mermaid形式でダイアグラム作成・ブラウザ表示） |
| `creating-flashcards` | EPUB/PDFからAnkiフラッシュカード一括作成（コンテンツ構造分析・選択肢リスト化・一括インポート） |
| `viewing-diffs` | difit GitHub風差分ビューア（git diff のブラウザ表示・自動インストール対応） |
| `orchestrating-teams` | Agent Teamオーケストレーション（チーム編成・タチコマ並列起動・進捗管理・docs先行開発） |
| `translating-with-lmstudio` | LM Studioローカル LLM による英語→日本語翻訳（OpenAI互換API、フラッシュカード作成・スキル変換連携） |

#### ドキュメント・品質

| スキル | 説明 |
|--------|------|
| `mermaid-diagrams` | Mermaidダイアグラム作成（22+種類：構造設計・フロー・プロジェクト管理・データ可視化・バージョン管理・思考整理・専門用途、23リファレンスファイル） |
| `crafting-ai-copywriting` | AIコピーライティング（15の心理的プロンプト技法） |
| `writing-latex` | LaTeX文書作成 |
| `generating-google-slides` | Google Slides自動生成（GAS slideDataオブジェクト生成） |
| `slidekit-create` | HTMLスライドプレゼンテーション生成（1スライド=1HTML、Tailwind CSS、15レイアウトパターン、5スタイル×5テーマ） |
| `slidekit-templ` | PDFプレゼンテーション→HTMLスライドテンプレート変換（視覚再現アプローチ） |
| `authoring-agents` | エージェント定義（agents/*.md）の作成ガイド（フロントマター・スキルプリロード・テンプレート） |
| `authoring-skills` | スキル作成・ソース変換・利用状況レビュー統合ガイド |
| `searching-with-exa` | Exa MCP統合（7カテゴリ検索: 企業・コード・人物・財務・学術・個人サイト・Tweet/X、Web検索第一優先ツール） |
| `searching-web` | Web検索 fallback（gemini CLI、Exa MCP使用不可時） |
| `reviewing-with-coderabbit` | CodeRabbitコードレビュー |
| `writing-zenn-articles` | Zenn技術記事の作成・投稿ワークフロー（フロントマター仕様・命名規則・品質チェック・Lint設定） |
| `designing-training` | 研修設計・ファシリテーション方法論（ニーズ分析・カリキュラム設計・90/20/8法則・EATフレームワーク・参加者主体技法・オンライン/ハイブリッド・スキルマップ・研修資料作成・12リファレンスファイル） |
| `writing-effective-prose` | 効果的な文章術（論理構成・文レベル技術・表現・推敲・AI臭除去・技術文書・学術文書・大学レポート/論文（卒論・実験レポート・引用・剽窃防止）を統合） |

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

### MCP Servers (11個)

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
| drawio | draw.ioダイアグラム作成・表示 |

---

## 主な特徴

- **並列実行モデル**: タチコマ4体同時起動で独立タスクを並列処理
- **トークン効率化**: /serenaコマンドによる構造化開発
- **型安全性**: any/Any型の使用を厳格に禁止
- **セキュリティファースト**: 実装後のCodeGuard検証を必須化
- **自動フォーマット**: PostToolUseフックによるコード整形
- **二段階ロード**: SKILL.md（フロントマターのみ）+ INSTRUCTIONS.md（本文）でコンテキスト94.8%削減

---
