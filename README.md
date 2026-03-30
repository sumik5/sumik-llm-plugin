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
├── agents/             # Agent定義 (28体、カテゴリ別プレフィックス: core/lang/fw/fe/cloud/qa/data/doc/str)
├── commands/           # スラッシュコマンド (11個)
├── hooks/              # イベントフック (4個)
├── scripts/            # ヘルパースクリプト (3個)
└── skills/             # ナレッジスキル (62個)
```

---

## コンポーネント一覧

### Agents (28体)

| Agent | モデル | 説明 |
|-------|--------|------|
| **タチコマ** (tachikoma) | Sonnet | 汎用実行Agent。専門タチコマでカバーされないタスクや複数ドメイン横断タスクを担当。並列実行対応(1-4体) |
| **Serena Expert** (serena-expert) | Sonnet | /serenaコマンドを活用したトークン効率重視の開発Agent |
| **タチコマ（Python）** (tachikoma-lang-python) | Sonnet | Python専門。Python 3.13+・uv/ruff/mypy・FastAPI/FastMCP・Google ADKエージェント構築 |
| **タチコマ（Go）** (tachikoma-lang-go) | Sonnet | Go専門。concurrencyパターン・インターフェース設計・エラーハンドリング・GoFパターン・Go内部構造 |
| **タチコマ（Bash）** (tachikoma-lang-bash) | Sonnet | Bashシェルスクリプト専門。strict mode・I/Oパイプライン・プロセス制御・セキュリティ・ShellCheck |
| **タチコマ（TypeScript）** (tachikoma-lang-typescript) | Sonnet | TypeScript型システム専門。高度な型パターン・ジェネリクス・条件型・GoFデザインパターン |
| **タチコマ（Next.js）** (tachikoma-fw-nextjs) | Sonnet | Next.js 16/React 19専門。App Router・Server Components・Turbopack・next-devtools統合 |
| **タチコマ（フルスタックJS）** (tachikoma-fw-fullstack-js) | Sonnet | フルスタックJS専門。NestJS/Express・REST API設計・構造化ログ |
| **タチコマ（フロントエンド）** (tachikoma-fe-frontend) | Sonnet | フロントエンドコンポーネント実装専門。shadcn/ui・Storybook（CSF3・インタラクションテスト・a11y）・データビジュアライゼーション |
| **タチコマ（Figma実装）** (tachikoma-fe-figma-impl) | Sonnet | Figma→コード変換専門。Figma MCP全13ツール・Code Connect・デザイントークン同期・Tailwind CSSスタイリング・ビジュアル検証 |
| **タチコマ（デザインシステム）** (tachikoma-fe-design-system) | Sonnet | デザインシステム構築・運用専門。DS3層アーキテクチャ・パターンライブラリ・Figma変数/トークン管理・ガバナンス・組織導入戦略 |
| **タチコマ（UXデザイン）** (tachikoma-fe-ux-design) | Sonnet | UX戦略・ビジュアルデザイン・クリエイティブ専門。UI/UX哲学・デザイン思考・グラフィックデザイン基礎・AIエクスペリエンス設計。コード実装なし |
| **タチコマ（AWS）** (tachikoma-cloud-aws) | Sonnet | AWS専門。Lambda・API Gateway・DynamoDB・CDK・EKS・Bedrock・セキュリティ・FinOps |
| **タチコマ（Google Cloud）** (tachikoma-cloud-gcp) | Sonnet | Google Cloud専門。Cloud Run・BigQuery・VPC・Memorystore・Zero Trust・データエンジニアリング |
| **タチコマ（Terraform）** (tachikoma-cloud-terraform) | Sonnet | Terraform IaC専門。HCL・モジュール設計・state管理・Terragruntパターン・Terraform MCP活用 |
| **タチコマ（インフラ）** (tachikoma-cloud-infra) | Sonnet | インフラ/DevOps専門。Docker・Compose・CI/CDパイプライン・Blue-Green/Canaryデプロイ |
| **タチコマ（テスト）** (tachikoma-qa-test) | Sonnet | ユニット/インテグレーションテスト専門。TDD・Vitest/Jest・React Testing Library・モック戦略 |
| **タチコマ（E2Eテスト）** (tachikoma-qa-e2e-test) | Sonnet | E2Eテスト・ブラウザ自動化専門。Playwright Test・POM・ビジュアルテスト・アクセシビリティ・CI/CD統合 |
| **タチコマ（セキュリティ）** (tachikoma-qa-security) | Opus | セキュリティレビュー専門（読み取り専用）。OWASP・サーバーレスセキュリティ・IAM・動的認可。レポート作成のみ |
| **タチコマ（オブザーバビリティ）** (tachikoma-qa-observability) | Sonnet | オブザーバビリティ専門。OpenTelemetry計装・SLO/SLI設計・アラート・ログパイプライン |
| **タチコマ（コードレビュー）** (tachikoma-qa-code-reviewer) | Opus | コードレビュー専門（読み取り専用）。バグ・ロジックエラー・セキュリティ脆弱性・コード品質・プロジェクト規約の確認。信頼度フィルタリングで高優先度の問題のみ報告 |
| **タチコマ（データベース）** (tachikoma-data-database) | Sonnet | データベース専門。リレーショナルDB設計・正規化・SQLアンチパターン回避・クエリ最適化・DB内部構造 |
| **タチコマ（AI/ML）** (tachikoma-data-ai-ml) | Sonnet | AI/ML開発専門。Vercel AI SDK・LangChain.js・RAGシステム・MCP開発・LLMOps運用 |
| **タチコマ（ドキュメント）** (tachikoma-doc-document) | Sonnet | ドキュメント作成専門。技術文書・LaTeX・Zenn記事・AIコピーライティング。コード実装なし |
| **タチコマ（スライド）** (tachikoma-doc-slide) | Sonnet | HTMLスライド作成専門。slides repo 3層分離モデル（Engine/Theme/Content）・ソース素材変換3ルール・テーマカスタマイズ・プロジェクト初期化 |
| **タチコマ（研修・プレゼン）** (tachikoma-doc-training) | Sonnet | 研修設計・プレゼンテーション改善専門（自己進化型）。研修ニーズ分析・カリキュラム設計・プレゼン構成改善・デリバリー技法・文章品質向上 |
| **タチコマ（アーキテクチャ）** (tachikoma-str-architecture) | Opus | アーキテクチャ設計専門（読み取り専用）。DDD・マイクロサービス・トレードオフ分析。設計ドキュメント作成のみ |
| **タチコマ（プロダクトマネジメント）** (tachikoma-str-product-mgr) | Opus | プロダクトマネジメント専門（読み取り専用）。PRD作成・ロードマップ策定・優先順位付け・A/Bテスト設計・成長メトリクス分析・AIプロダクト成熟度評価・技術トレードオフ分析。ドキュメント作成のみ |

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
| `/viewing-diffs` | GitHub風差分ビューア（difit）でコードdiff表示。staged/working/commit/ブランチ間比較・PR レビュー対応 |
| `/react-doctor` | React コード品質診断（react-doctor CLI、0-100スコア、セキュリティ・パフォーマンス・正確性） |

### Skills (62個)

#### コア開発

| スキル | 説明 |
|--------|------|
| `implementing-as-tachikoma` | タチコマAgent運用ガイド |
| `using-serena` | Serena MCP活用 |
| `writing-clean-code` | 言語非依存のクリーンコードレシピ（SOLID原則・Kent Beck 4 Rules・Uncle Bob 66ヒューリスティクス・ソフトウェアデザインの法則含む27カテゴリのコードスメル検出・リファクタリング・フォーマット・境界管理・20リファレンスファイル） |
| `testing-code` | テストファースト（Vitest/Playwright）・Khorikovの4本の柱フレームワーク（16リファレンス）。RTL固有は`developing-react`参照 |
| `researching-libraries` | ライブラリ調査（車輪の再発明禁止） |
| `securing-code` | セキュアコーディング（OWASP Top 10、インジェクション対策、認証・認可、Web penetration testing knowledge含む） |
| `securing-ai-development` | AI開発セキュリティ戦略（信頼フレームワーク、適応型ガードレール、AI-BOM、AI-SPM、ガバナンス、クロスファンクショナル所有権） |
| `developing-with-ai` | AI支援開発メソドロジー（プロンプトエンジニアリング・コンテキストエンジニアリング・コード生成・QA・デバッグ・エージェント協調） |
| `practicing-product-management` | プロダクトマネジメント実践ガイド（PM定義・アジャイルケイデンス・AARRR・PMF/GTM・収益モデル・ロードマップ・優先順位付け・PM-UX協働・AI時代PM進化・AI成熟度評価・AIケーススタディ・AI/ML基礎リテラシー・AI PM専門化ロール×3・AI機会評価/ROI算出・MLOps・責任あるAI・GPM/PLG: PLGモデル4戦略・freemium比較・B2B/B2Cペルソナ・ペインポイント分析・PLG文化・バリュープロポジション・カスタマーサクセス・オンボーディング・CS組織スケーリング・9つのリテンション戦略・CRR/NPS/CLV・拡張収益・ARPU/ARR/NRR・価格戦略・GPMの未来と倫理・失敗ケーススタディ・キャリアパス・7リファレンスファイル） |
| `applying-semantic-versioning` | SemVer 2.0.0仕様準拠バージョン判断ガイド（MAJOR/MINOR/PATCH判定・プレリリース・範囲指定・よくある誤り） |
| `writing-conventional-commits` | Conventional Commits 1.0.0準拠コミットメッセージガイド（type/scope/BREAKING CHANGE判定・SemVer連携） |
| `managing-claude-md` | CLAUDE.md管理（8原則、プログレッシブ・ディスクロージャー、生きたドキュメント運用） |
| `reviewing-code` | コードレビュー方法論（PRの構成・効果的なコメント技法・TWA・アンチパターン対策） |
| `developing-databases` | DB設計・SQLアンチパターン・DB内部構造・PostgreSQL実践運用を統合した包括的データベース開発ガイド（リレーショナルDB設計・正規化・PostgreSQL・25のSQLアンチパターン・Bツリー/LSMストレージエンジン・分散システム・合意アルゴリズム・クエリチューニング・MVCC/VACUUM・バックアップ/PITR・レプリケーション/HA・監視） |
| `authoring-plugins` | Claude Code Plugin開発ガイド（Agent・Skill・コマンド定義の作成・最適化・フロントマター仕様・Progressive Disclosure・ツール制限） |
| `practicing-software-engineering` | SW開発プラクティス包括ガイド（プロジェクト基盤: Fast Feedback・DORA計測 ＋ チーム組織: Team Topologies・4チームタイプ ＋ ペアプログラミング: 4パターン ＋ 開発者習慣: GREAT Habits ＋ IC効果性マインドセット: アウトカム思考・戦略的優先順位付け ＋ キャリア成長: Junior→Staff・IC/Management パス ＋ 影響力: PM/デザイナー協働・権限なきリーダーシップ ＋ 20アンチパターン: 個人15+チーム5 ＋ 持続可能パフォーマンス: バーンアウト防止・リモートワーク ＋ AI活用ワークフロー: 日常AI統合・90日チーム採用計画、10リファレンスファイル） |
| `writing-user-stories` | ユーザーストーリー作成ガイド（テンプレート・よくある間違い・技術要件変換・受入条件・分割テクニック） |

#### アーキテクチャ

| スキル | 説明 |
|--------|------|
| `developing-web-apis` | Web API開発統合ガイド（API設計ベストプラクティス・Spec First開発方法論・APIテスト戦略）。エンドポイント設計・HTTPスペック・バージョニング・セキュリティ・コントラクトテスト・自動化を網羅 |
| `building-multi-tenant-saas` | マルチテナントSaaSアーキテクチャ設計ガイド |
| `implementing-dynamic-authorization` | 動的認可設計（ABAC/ReBAC/PBAC、Cedar、認可アーキテクチャ） |
| `applying-behavior-design` | 行動変容デザイン（CREATEファネル、3戦略）|
| `applying-clean-architecture` | Clean Architecture原則（依存性ルール・同心円モデル・コンポーネント原則・境界設計・アンチパターン） |
| `architecting-infrastructure` | インフラデザインパターン127種 + アーキテクチャモダナイゼーション（トレードオフ分析） + マイクロサービスパターン（CQRS・Saga・粒度決定・データ所有権）。ベンダー非依存の設計方式選定・非機能要求分析 |
| `architecting-data` | データアーキテクチャパターン（Read-Side最適化、CQRS、CDC、Event Sourcing、キャッシュ戦略） |
| `evaluating-with-promptfoo` | promptfooによるLLM評価・レッドチーミング（promptfooconfig.yaml設定・40+アサーション・プロバイダー・134+レッドチームプラグイン・CI/CD統合） |
| `designing-genai-patterns` | 32のGenAIデザインパターン（コンテンツ制御・RAG・モデル能力拡張・信頼性・エージェント・デプロイ最適化・安全ガードレール）＋RAGシステム実装（11種データソース・5種チャンキング戦略）＋AIシステム性能最適化（GPU/CUDA・分散訓練・LLM推論、175+項目チェックリスト） |

#### フレームワーク

| スキル | 説明 |
|--------|------|
| `developing-react` | React 19.x 開発ガイド（Internals・パフォーマンスルール47+・デザインパターン（Container/Presenter・HOC・Render Props・Headless等）・エラーハンドリング（ErrorBoundary・react-error-boundary・React 19 error APIs）・アクセシビリティ（ARIA・フォーカス管理・キーボードナビゲーション）・2025年状態管理推奨（nuqs・Jotai・React Compiler）・アニメーション・RTLテスト・8リファレンスファイル） |
| `developing-nextjs` | Next.js 16.x開発ガイド（App Router・Server Components・Cache Components・Turbopack・実践パターン集）。Route Segment・Parallel/Intercepting Routes・Prisma・NextAuth.js・Server Actions・4種キャッシュ戦略を含む10リファレンスファイル。React固有は`developing-react`参照 |
| `developing-go` | Go開発包括ガイド（クリーンコード・デザインパターン・並行処理詳細パターン・内部構造・スケジューラー・実践パターン7分野・nilハンドリング・テンプレートエンジン・34リファレンスファイル） |
| `developing-python` | Python 3.13開発（Effective Python 125項目・実践パターン50問・SEプロセス・Clean Architecture実践・Architecture Patterns: Repository/UoW/Aggregates/Domain Events/CQRS・DDD Tactical Patterns: Entity/Value Object/Aggregate Root） |
| `developing-bash` | Bashシェルスクリプティング・自動化ガイド（基礎、制御構造、I/O、プロセス制御、テスト、セキュリティ、パターン） |
| `developing-fullstack-javascript` | フルスタックJS開発（NestJS/Express・React・CI/CD・品質）＋JavaScript言語基礎（型・クロージャ・プロトタイプ・async/await・モジュール・メタプログラミング）を包括カバー。SOLID原則・セキュリティ・テスト戦略に加え、JS言語仕様の6リファレンスファイルを含む |
| `mastering-typescript` | TypeScript包括ガイド（83項目の実装判断基準 + 型システム・関数・クラス・高度な型・非同期・モジュール・ビルド + Total TypeScript: satisfies・余剰プロパティ・コンパイラ振る舞い + TS5デコレータ完全ガイド + 型関係論・型推論パターン・型安全テクニック） |
| `developing-mcp` | MCP (Model Context Protocol) サーバー/クライアント開発・アーキテクチャパターン・セキュリティ強化（脅威モデル・コード硬化・OIDC認証・LLM攻撃対策・エコシステム脅威・実装チェックリスト） |
| `integrating-ai-web-apps` | Vercel AI SDK + LangChain.js + MCPによるWebアプリAI統合 |
| `building-ai-agents` | AIエージェント構築統合ガイド（LangChain/LangGraph: LCEL・ReAct・マルチエージェント・MCP統合・LangSmith評価 ＋ Google ADK: Agent分類・ツール設計・A2A・RAG・セキュリティ ＋ リアルタイムマルチモーダル: WebSocket・Web Audio API・Gemini Live API） |

#### フロントエンド・デザイン

| スキル | 説明 |
|--------|------|
| `building-design-systems` | デザインシステム構築・運用・立ち上げ・浸透・Figma実装方法論（DS基礎・パターン分類・組織戦略・UIパターンカタログ20+・Figmaバリアブル/デザイントークン3層階層・カラーシステム・タイポグラフィ・Style Dictionary/Storybook連携・立ち上げ3ステップ・浸透3ステップ・コンテンツ策定ガイド・多組織パターン集） |
| `designing-ux` | UI/UX・グラフィックデザイン・インターフェイス哲学・認知心理学基盤・UXエレメント5段階モデルを統合したデザイン総合スキル（UIデザインガイドライン101ルール・認知心理学基盤: 知覚バイアス/ゲシュタルト/色覚/記憶/フィッツの法則/応答性・グラフィック基礎: 造形/色彩/タイポグラフィ/レイアウト・Fluid Interfaces・モーション理論・Experiencability・5段階フレームワーク: Strategy→Scope→Structure→Skeleton→Surface・Webデザイン機能性7軸・情緒性6軸イコライザーモデル・8要素×機能性/情緒性マトリクス・デザインコンセプト立案4プロセス・レイアウト実践パターン・イメージワードシステム・クリエイティブプロセスパターン） |
| `designing-frontend` | フロントエンド実装（shadcn/ui統合・オブジェクト指向UI設計（OOUI）：オブジェクト抽出・ビュー/ナビゲーション・レイアウトパターン） |
| `implementing-design` | デザイン→コード変換総合スキル（汎用原則: デザインシステム統合・視覚的整合性・レスポンシブ・a11y ＋ Figma MCP: 全13ツール・基本/高度ワークフロー・Code Connect・デザイントークン同期・ビジュアル検証） |
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
| `implementing-observability` | オブザーバビリティ統合ガイド（監視設計: アンチパターン・6層戦略・SLO・テレメトリーパイプライン・成熟度モデル ＋ OpenTelemetry実装: トレース/メトリクス/ログAPI・Collector・セマンティック規則 ＋ ログ設計: 構造化ログ・収集パイプライン・AI/ML分析・セキュリティ ＋ オブザーバビリティエンジニアリング実践: コア分析ループ・ファーストプリンシプルデバッグ・ROI分析・CI/CDパイプライン計装・高カーディナリティデータストア設計・サンプリング実装パターン） |
| `developing-aws` | AWS開発包括ガイド（システム設計・CDP57パターン・VPCアーキテクチャ（Transit Gateway/VPCピアリング/Site-to-Site VPN/PrivateLink/ENI）・エンタープライズ基盤・14業務システム・移行戦略・サーバーレス・CDK・EKS・ECS/Fargate（コンテナ設計/Well-Architected/Blue-Green/FireLens/Trivy）・SRE運用・FinOps/CCoE・セキュリティ（IAM/VPC/KMS/GuardDuty/セキュリティガバナンス/NIST CSF/ISO27001/リスクアセスメント/インシデントレスポンス/フォレンジック/Detective）・Bedrock GenAI（Embedding・セマンティック検索）・Cognito認証・cloud-nativeパターン・インフラ自動化・HA/耐障害性・51リファレンスファイル） |
| `developing-google-cloud` | Google Cloud 開発・セキュリティ・データエンジニアリング・ネットワーク・キャッシング・エンタープライズアーキテクチャ包括ガイド（Cloud Runデプロイ + GCPプラットフォームセキュリティ深掘り: IAM・VPC・KMS・DLP・SCC・DevSecOps CI/CD・Zero Trust/BeyondCorp・Anthos・Incident Response + データエンジニアリング + ネットワークエンジニアリング: VPC設計・ハイブリッド接続・LB/CDN・ネットワーク監視・Traffic Director/Service Mesh + Memorystore: マネージドRedis/Memcachedキャッシング・パフォーマンスエンジニアリング・レジリエンス + エンタープライズアーキテクチャ: アカウント設計・組織階層・移行戦略・モダナイゼーション + コンピューティング選択: GCE/GKE/GAE/Cloud Run/Functions比較 + GKEコンテナオーケストレーション + 監視・運用設計: SLO/SLI・Cloud Operations Suite + BigQuery分析: KPI計算・SQL実践・fluentdパイプライン + BigQuery高度運用: エディション・HA/DR・スロット管理・チューニング + レイクハウス: BigLake・Dataplex・データカタログ・品質チェック + ワークフロー管理: Cloud Composer・Data Fusion・Dataform + BI・データ可視化: Looker・Looker Studio・BI Engine + データ集約: BigQuery DTS・Datastream CDC・GA4/Firebase + リアルタイム分析: Pub/Sub・Dataflowストリーミング + ML高度分析: BigQuery ML・Vertex AI・GIS・Gemini・50リファレンスファイル） |
| `using-next-devtools` | Next.js DevTools |
| `developing-terraform` | Terraform/Terragrunt IaC開発（HCL・モジュール・ステート・Terragrunt・mise・AWS/GCP） |
| `managing-keycloak` | Keycloak IAM包括ガイド（OIDC/SAML・SSO・Realm/Client/User管理・認証フロー・MFA・認可ポリシー・JWT Token管理・アプリ統合・Docker/K8sデプロイ・SPI拡張） |
| `practicing-devops` | DevOps方法論・IaCツール選定・オーケストレーション比較・CI/CD・プラットフォームエンジニアリング |
| `creating-flashcards` | EPUB/PDFからAnkiフラッシュカード一括作成（コンテンツ構造分析・選択肢リスト化・一括インポート） |
| `orchestrating-teams` | Agent Teamオーケストレーション（チーム編成・タチコマ並列起動・進捗管理・docs先行開発） |
| `converting-content` | コンテンツ変換ガイド（画像ベースEPUB→テキストOCR変換・LM Studio英日翻訳・pandoc・recognize-image.py） |

#### ドキュメント・品質

| スキル | 説明 |
|--------|------|
| `writing-latex` | LaTeX文書作成 |
| `searching-web` | Web検索統合スキル（Exa MCP第一優先: 7カテゴリ検索/企業・コード・人物・財務・学術・個人サイト・Tweet/X ＋ gemini CLIフォールバック） |
| `designing-training` | 研修設計・ファシリテーション方法論（ニーズ分析・カリキュラム設計・90/20/8法則・EATフレームワーク・参加者主体技法・オンライン/ハイブリッド・スキルマップ・研修資料作成・12リファレンスファイル） |
| `writing-effective-prose` | 統合文章術スキル（論理構成・AI臭除去・技術文書7Cs・学術文書・大学レポート/論文（卒論・実験レポート・引用・剽窃防止）・技術ブログ・README作成・Zenn記事作成・投稿ワークフロー・ナタリー式文章メソッド（完読概念/主眼と骨子/構造シート）・文書の構造設計（5要素階層/辞書形式vs読み物形式/認知心理学的基盤）・54リファレンスファイル） |
| `creating-diagrams` | ダイアグラム作成ガイド（Mermaid: 24種類・C4モデル/ER図/シーケンス図/フローチャート ＋ draw.io MCP統合） |
| `creating-content` | コンテンツ制作統合スキル（AIコピーライティング: 15テクニック・心理的トリガー ＋ AIデザインクリエイティブ: バナー/SNS/ポスター） |
| `creating-slides` | HTMLスライド作成（slides repo 3層分離モデル: Engine/Theme/Content、16:9デッキ、テーマカスタマイズ・ソース素材変換をガイド。認知科学・ロジック構築・ストーリーテリング・聴衆分析・スライドデザイン・ビジュアルデザイン実践・提案書構成術・デリバリー・準備プロセスの9リファレンスで品質担保） |

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
