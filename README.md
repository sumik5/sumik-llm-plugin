# sumik-llm-plugin

**Claude Code / Codex の開発ワークフローを強化する包括的なプラグインシステム**

---

## 概要

LLMの開発効率を最大化するためのプラグイン。Agent、コマンド、スキル、フック、MCPサーバー統合を含み、並列実行モデル、トークン効率化、型安全性、セキュリティファーストのアプローチを実現します。

---

## インストール

### Claude Code


```bash
/plugin install devkit@sumik
/plugin install studio@sumik
/plugin install lang@sumik
/plugin install web@sumik
/plugin install cloud@sumik
/plugin install ai@sumik
/plugin install design@sumik
/plugin install product@sumik
/plugin install exam@sumik
/plugin install university@sumik
/plugin install google@sumik
/plugin install mobile@sumik
/plugin install certificate@sumik
```

### Codex

```bash
codex plugin marketplace add https://github.com/sumik5/sumik-llm-plugin.git --ref main
codex plugin add devkit@sumik-marketplace
codex plugin add studio@sumik-marketplace
codex plugin add lang@sumik-marketplace
codex plugin add web@sumik-marketplace
codex plugin add cloud@sumik-marketplace
codex plugin add ai@sumik-marketplace
codex plugin add design@sumik-marketplace
codex plugin add product@sumik-marketplace
codex plugin add exam@sumik-marketplace
codex plugin add university@sumik-marketplace
codex plugin add google@sumik-marketplace
codex plugin add mobile@sumik-marketplace
codex plugin add certificate@sumik-marketplace
```

---

## ディレクトリ構成

```
sumik-llm-plugin/                      # GitHub repo（Codex はここを git clone）
├── .agents/
│   └── plugins/
│       └── marketplace.json              # Codex marketplace manifest（marketplace 名 sumik-marketplace / plugin 名 devkit + studio + lang + web + cloud + ai + design + product + exam + university + google + mobile + certificate）
├── .cache/
│   └── sumik-marketplace/
│       ├── devkit -> ../..               # Codex marketplace から repo root の plugin を指す symlink
│       ├── studio -> ../../plugins/studio  # Codex marketplace から studio plugin を指す symlink
│       ├── lang -> ../../plugins/lang      # Codex marketplace から lang plugin を指す symlink
│       ├── web -> ../../plugins/web        # Codex marketplace から web plugin を指す symlink
│       ├── cloud -> ../../plugins/cloud    # Codex marketplace から cloud plugin を指す symlink
│       ├── ai -> ../../plugins/ai          # Codex marketplace から ai plugin を指す symlink
│       ├── design -> ../../plugins/design  # Codex marketplace から design plugin を指す symlink
│       ├── product -> ../../plugins/product  # Codex marketplace から product plugin を指す symlink
│       ├── exam -> ../../plugins/exam       # Codex marketplace から exam plugin を指す symlink
│       ├── university -> ../../plugins/university  # Codex marketplace から university plugin を指す symlink
│       ├── google -> ../../plugins/google   # Codex marketplace から google plugin を指す symlink
│       ├── mobile -> ../../plugins/mobile   # Codex marketplace から mobile plugin を指す symlink
│       └── certificate -> ../../plugins/certificate  # Codex marketplace から certificate plugin を指す symlink
├── .claude-plugin/
│   └── marketplace.json                  # claude.ai が読む（marketplace 名 sumik / plugin 名 devkit + studio + lang + web + cloud + ai + design + product + exam + university + google + mobile + certificate / source ./plugins/<p>）
├── .codex-plugin/
│   └── plugin.json                       # Codex CLI プラグインマニフェスト（plugin 名 devkit / skills ./plugins/devkit/skills/ / version 同期必須）
├── .mcp-codex.json                       # Codex 用 MCPサーバー設定（command ./plugins/devkit/bin/... / cwd "."）
├── README.md
├── CLAUDE.md
└── plugins/
    ├── devkit/                           # Claude Code プラグイン本体（claude.ai が取り込む清潔な範囲）
    │   ├── .claude-plugin/
    │   │   └── plugin.json               # プラグインメタデータ（plugin 名 devkit / .codex-plugin/ と version 同期必須）
    │   ├── .mcp.json                     # Claude 用 MCPサーバー設定（${CLAUDE_PLUGIN_ROOT}/bin/...）
    │   ├── agents/                       # Agent定義 (29体、カテゴリ別プレフィックス: core/lang/fw/fe/cloud/qa/data/doc/str/mobile)
    │   ├── commands/                     # スラッシュコマンド (13個)
    │   ├── hooks/                        # イベントフック (12個)
    │   ├── bin/                          # MCPサーバー起動ラッパー (npx-mise.sh, uvx-mise.sh)
    │   ├── scripts/                      # ヘルパースクリプト (4個)
    │   └── skills/                       # ナレッジスキル (31個)
    ├── studio/                           # コンテンツ制作プラグイン（slides/diagrams/EPUB圧縮/LaTeX 等）
    │   ├── .claude-plugin/
    │   │   └── plugin.json               # プラグインメタデータ（plugin 名 studio / version 同期必須）
    │   ├── .mcp.json                     # Claude 用 MCPサーバー設定（drawio・${CLAUDE_PLUGIN_ROOT}/bin/...）
    │   ├── .codex-plugin/
    │   │   └── plugin.json               # Codex CLI プラグインマニフェスト（plugin 名 studio / skills ./skills/）
    │   ├── .mcp-codex.json               # Codex 用 MCPサーバー設定（drawio・command ./bin/... / cwd "."）
    │   ├── README.md
    │   ├── bin/                          # MCPサーバー起動ラッパー (npx-mise.sh)
    │   ├── commands/                     # スラッシュコマンド (2個)
    │   ├── scripts/                      # ヘルパースクリプト (pdf-to-markdown, epub-fix-cover.sh)
    │   └── skills/                       # ナレッジスキル (12個)
    ├── lang/                             # 言語・データベース実装プラグイン（skills-only）
    │   ├── .claude-plugin/
    │   │   └── plugin.json               # プラグインメタデータ（plugin 名 lang / version 同期必須）
    │   ├── .codex-plugin/
    │   │   └── plugin.json               # Codex CLI プラグインマニフェスト（plugin 名 lang / skills ./skills/ / mcpServers なし）
    │   ├── README.md
    │   └── skills/                       # ナレッジスキル (7個)
    ├── web/                              # Web フロントエンド・フレームワーク実装プラグイン（skills-only）
    │   ├── .claude-plugin/
    │   │   └── plugin.json               # プラグインメタデータ（plugin 名 web / version 同期必須）
    │   ├── .codex-plugin/
    │   │   └── plugin.json               # Codex CLI プラグインマニフェスト（plugin 名 web / skills ./skills/ / mcpServers なし）
    │   ├── README.md
    │   └── skills/                       # ナレッジスキル (13個)
    ├── cloud/                            # クラウド・インフラ・アーキテクチャプラグイン（skills-only）
    │   ├── .claude-plugin/
    │   │   └── plugin.json               # プラグインメタデータ（plugin 名 cloud / version 同期必須）
    │   ├── .codex-plugin/
    │   │   └── plugin.json               # Codex CLI プラグインマニフェスト（plugin 名 cloud / skills ./skills/ / mcpServers なし）
    │   ├── README.md
    │   └── skills/                       # ナレッジスキル (13個)
    ├── ai/                               # AI/LLM/エージェント開発プラグイン（skills-only）
    │   ├── .claude-plugin/
    │   │   └── plugin.json               # プラグインメタデータ（plugin 名 ai / version 同期必須）
    │   ├── .codex-plugin/
    │   │   └── plugin.json               # Codex CLI プラグインマニフェスト（plugin 名 ai / skills ./skills/ / mcpServers なし）
    │   ├── README.md
    │   └── skills/                       # ナレッジスキル (6個)
    ├── design/                           # UX/デザイン戦略プラグイン（skills-only）
    │   ├── .claude-plugin/
    │   │   └── plugin.json               # プラグインメタデータ（plugin 名 design / version 同期必須）
    │   ├── .codex-plugin/
    │   │   └── plugin.json               # Codex CLI プラグインマニフェスト（plugin 名 design / skills ./skills/ / mcpServers なし）
    │   ├── README.md
    │   └── skills/                       # ナレッジスキル (6個)
    ├── product/                          # プロダクトマネジメント・ユーザーストーリープラグイン（skills-only）
    │   ├── .claude-plugin/
    │   │   └── plugin.json               # プラグインメタデータ（plugin 名 product / version 同期必須）
    │   ├── .codex-plugin/
    │   │   └── plugin.json               # Codex CLI プラグインマニフェスト（plugin 名 product / skills ./skills/ / mcpServers なし）
    │   ├── README.md
    │   └── skills/                       # ナレッジスキル (2個)
    ├── exam/                             # 生成AI活用試験 解答生成プラグイン（agent入り・subdirectory方式）
    │   ├── .claude-plugin/
    │   │   └── plugin.json               # プラグインメタデータ（plugin 名 exam / version 同期必須）
    │   ├── .codex-plugin/
    │   │   └── plugin.json               # Codex CLI プラグインマニフェスト（plugin 名 exam / skills ./skills/ / mcpServers なし）
    │   ├── agents/                       # Agent定義 (exam-solver・1体・Claude専用)
    │   ├── README.md
    │   └── skills/                       # ナレッジスキル (1個)
    ├── university/                       # 大学用 Processing 開発プラグイン（skills-only）
    │   ├── .claude-plugin/
    │   │   └── plugin.json               # プラグインメタデータ（plugin 名 university / version 同期必須）
    │   ├── .codex-plugin/
    │   │   └── plugin.json               # Codex CLI プラグインマニフェスト（plugin 名 university / skills ./skills/ / mcpServers なし）
    │   ├── README.md
    │   └── skills/                       # ナレッジスキル (1個: developing-processing)
    ├── google/                           # Google サービス連携プラグイン（GA4公式MCP）
    │   ├── .claude-plugin/
    │   │   └── plugin.json               # プラグインメタデータ（plugin 名 google / version 同期必須）
    │   ├── .mcp.json                     # Claude 用 MCPサーバー設定（analytics-mcp）
    │   ├── .codex-plugin/
    │   │   └── plugin.json               # Codex CLI プラグインマニフェスト（plugin 名 google / skills ./skills/ + mcpServers）
    │   ├── .mcp-codex.json               # Codex 用 MCPサーバー設定（analytics-mcp）
    │   ├── README.md
    │   ├── bin/                          # MCPサーバー起動ラッパー
    │   └── skills/                       # ナレッジスキル (1個: analyzing-with-google-analytics)
    ├── mobile/                           # iPhone/iPad アプリ開発プラグイン（skills-only）
    │   ├── .claude-plugin/
    │   │   └── plugin.json               # プラグインメタデータ（plugin 名 mobile / version 同期必須）
    │   ├── .codex-plugin/
    │   │   └── plugin.json               # Codex CLI プラグインマニフェスト（plugin 名 mobile / skills ./skills/ / mcpServers なし）
    │   ├── README.md
    │   └── skills/                       # ナレッジスキル (2個: applying-apple-hig, developing-ios-apps)
    └── certificate/                      # 資格・検定学習支援プラグイン（kentei-lab問題収集/Ankiフラッシュカード/教材変換）
        ├── .claude-plugin/
        │   └── plugin.json               # プラグインメタデータ（plugin 名 certificate / version 同期必須）
        ├── .codex-plugin/
        │   └── plugin.json               # Codex CLI プラグインマニフェスト（plugin 名 certificate / skills ./skills/ / mcpServers なし）
        ├── README.md
        ├── commands/                     # スラッシュコマンド (1個: improve-creating-flashcards・Claude Code専用)
        └── skills/                       # ナレッジスキル (3個: collecting-kentei-lab-exams, creating-flashcards, converting-content)
```

---

## コンポーネント一覧

### Agents (29体)

| Agent | モデル | 説明 |
|-------|--------|------|
| **タチコマ** (tachikoma) | Sonnet | 汎用実行Agent。専門タチコマでカバーされないタスクや複数ドメイン横断タスクを担当。並列実行対応(1-4体) |
| **Serena Expert** (serena-expert) | Sonnet | /serenaコマンドを活用したトークン効率重視の開発Agent |
| **タチコマ（Python）** (tachikoma-lang-python) | Sonnet | Python専門。Python 3.13+・uv/ruff/mypy・FastAPI/FastMCP・Google ADKエージェント構築 |
| **タチコマ（Go）** (tachikoma-lang-go) | Sonnet | Go専門。concurrencyパターン・インターフェース設計・エラーハンドリング・GoFパターン・Go内部構造 |
| **タチコマ（Bash）** (tachikoma-lang-bash) | Sonnet | Bashシェルスクリプト専門。strict mode・I/Oパイプライン・プロセス制御・セキュリティ・ShellCheck |
| **タチコマ（TypeScript）** (tachikoma-lang-typescript) | Sonnet | TypeScript型システム専門。高度な型パターン・ジェネリクス・条件型・GoFデザインパターン |
| **タチコマ（モバイル/iOS）** (tachikoma-mobile-ios) | Sonnet | iOS/iPadOS/macOS専門。SwiftUI/UIKit実装・Apple HIG準拠UI・App Store審査対応監査（StoreKit 2 IAP実装・macOS/Mac App Store固有要件） |
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

### Commands (13個)

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
| `/update-software-security` | software-security スキルを上流 cosai-oasis/project-codeguard と同期（gh compareで差分検知→変更ルールのみ同一CONTRACTで再翻訳→version bump・commit）。`--check` で差分確認のみ |
| `/consume-learnings` | `.learnings/` の蓄積知見を恒久化先へ消費し処理済みエントリを削除（実ファイル裏取り→ルーティング→機械検証→リリース）。恒久化先は実行コンテキストで決まる: 一般プロジェクトはプロジェクトCLAUDE.md・`.claude/`配下・`~/.claude`/`~/.codex`のグローバル設定・memory、sumik-claude-plugin repo では加えて authoring-plugins スキルに従いAgent/Skill/Command/Hook/plugin.json/READMEを整合修正しversion bump |

### Skills (31個)

#### コア開発

| スキル | 説明 |
|--------|------|
| `implementing-as-tachikoma` | タチコマAgent運用ガイド |
| `using-serena` | Serena MCP活用 |
| `writing-clean-code` | 言語非依存のクリーンコードレシピ（SOLID原則・Simple Designの4ルール・66のコードスメルヒューリスティクス・ソフトウェアデザインの法則含む27カテゴリのコードスメル検出・リファクタリング・フォーマット・境界管理・20リファレンスファイル） |
| `testing-code` | テスト方法論(TDD/AAA・テストピラミッド・4本の柱・3つの手法・コード分類・アンチパターン・テスト管理・AI活用戦略)。フレームワーク非依存(16リファレンス)。Vitest固有は`web:testing-with-vitest`、RTL固有は`web:developing-react`、フルスタック戦略は`testing-strategies`参照 |
| `testing-strategies` | フルスタックテスト戦略ガイド（10次元: 探索的テスト8フレームワーク・機能自動化戦略/契約テスト・継続的テスト/DORA・データ層テスト/Testcontainers・ビジュアルテスト・セキュリティテスト/STRIDE・性能テスト/JMeter/Gatling/RAIL・アクセシビリティ/WCAG・CFR/カオスエンジニアリング・モバイルテスト・AI活用テスト、10リファレンスファイル）。TDD/単体テスト方法論は`testing-code`、Playwright実装は`web:testing-e2e-with-playwright`参照 |
| `researching-libraries` | ライブラリ調査（車輪の再発明禁止） |
| `securing-code` | セキュアコーディング（OWASP Top 10、インジェクション対策、認証・認可、Web penetration testing knowledge含む） |
| `software-security` | Project CodeGuard ベースのセキュアバイデフォルト・コーディングルール集（日本語訳・全23ルール: インジェクション/認証MFA/暗号/シークレット/認可/セッション/クラウド・K8s/IaC/サプライチェーン/MCP/モバイル/ロギング/プライバシー、25+言語対応のタグ・言語別ルーティング）。cosai-oasis/project-codeguard (CC-BY-4.0) の日本語翻案 |
| `applying-semantic-versioning` | SemVer 2.0.0仕様準拠バージョン判断ガイド（MAJOR/MINOR/PATCH判定・プレリリース・範囲指定・よくある誤り） |
| `writing-conventional-commits` | Conventional Commits 1.0.0準拠コミットメッセージガイド（type/scope/BREAKING CHANGE判定・SemVer連携） |
| `managing-claude-md` | CLAUDE.md管理（8原則、プログレッシブ・ディスクロージャー、生きたドキュメント運用） |
| `authoring-plugins` | Claude Code Plugin開発ガイド（Agent・Skill・コマンド定義の作成・最適化・フロントマター仕様・Progressive Disclosure・ツール制限）。Agent Skills標準 vs Claude Code拡張の分離原則・fork判定5軸マトリクス・FORK-GUIDE.md含む |
| `capturing-learnings` | 作業中の学び・エラー・ユーザー訂正・機能要望を .learnings/ に構造化記録し継続的改善につなげるスキル（LRN/ERR/FEAT エントリ・反復パターン検出・CLAUDE.md/memory/AGENTS.md/新スキルへの昇格・devkit hookで自動リマインド）。プラグイン自身のスキル改善は authoring-plugins、定期棚卸しは USAGE-REVIEW を参照 |
| `practicing-software-engineering` | SW開発プラクティス包括ガイド（プロジェクト基盤: Fast Feedback・DORA計測 ＋ チーム組織: Team Topologies・4チームタイプ ＋ ペアプログラミング: 4パターン ＋ 開発者習慣: GREAT Habits ＋ IC効果性マインドセット: アウトカム思考・戦略的優先順位付け ＋ キャリア成長: Junior→Staff・IC/Management パス ＋ 影響力: PM/デザイナー協働・権限なきリーダーシップ ＋ 20アンチパターン: 個人15+チーム5 ＋ 持続可能パフォーマンス: バーンアウト防止・リモートワーク ＋ AI活用ワークフロー: 日常AI統合・90日チーム採用計画、10リファレンスファイル） |
| `pursuing-simplicity` | シンプリシティ（自己誘発の複雑化への抵抗）実践ガイド（Orient-Step-Learn ループ・S vs C 評価ルーブリック ＋ 技術ミニマリズム: 依存の意思決定チェーン/最小・安定フレームワーク選定/機能=負債の抑制/増分価値提供/保守的技術採用 ＋ 個人の自動化と環境習熟: Automate First/Day Zero デプロイ/端末・シェル・エディタ・ワークスペース/マシンプロビジョニング ＋ 協働とソフトスキル: 非同期・時間的結合の除去/会議の作法・DWP/スキル拡散/弁証法的思考/共感/コードへの直感/アナロジー ＋ データ駆動の簡素化とエラーを見つけるコードレイアウト、5リファレンスファイル） |
| `find-skills` | スキル発見・インストールガイド（agent skills エコシステム検索・"how do I do X" / "find a skill for X" クエリへの応答・能力拡張サポート） |

#### アーキテクチャ

| スキル | 説明 |
|--------|------|
| `applying-clean-architecture` | Clean Architecture と DDD の統合ガイド（依存性ルール・同心円レイヤモデル: Entities/Use Cases/Interface Adapters/Frameworks & Drivers・コンポーネント原則 REP/CCP/CRP・ADP/SDP/SAP・Screaming Architecture・Humble Object・DDD戦略/戦術パターン: 境界づけられたコンテキスト/ユビキタス言語/コンテキストマッピング/Value Object/Entity/Aggregate/Event Sourcing/CQRS/Saga） |
| `transforming-legacy-systems` | レガシーシステムのDDD変革方法論（MMI: モジュール性成熟度の3次元定量評価と変革経路セレクター ＋ 複雑性の統御 ＋ 協働モデリング: ドメインストーリーテリング/EventStorming/シナリオキャスティング ＋ 変革アプローチ選定: 段階的置換/リシェイピング ＋ 技術的安定化: Seam・契約による設計 ＋ ドメイン知識のコード注入: 貧血モデル解消 ＋ 戦略4ステップ: ドメイン再発見→モデリング→整合→実行 ＋ チーム編成 ＋ 変革向けリファクタリングカタログ20エントリ、12リファレンスファイル） |

#### フレームワーク

| スキル | 説明 |
|--------|------|
| `mastering-typescript` | TypeScript包括ガイド（83項目の実装判断基準 + 型システム・関数・クラス・高度な型・非同期・モジュール・ビルド + Total TypeScript: satisfies・余剰プロパティ・コンパイラ振る舞い + TS5デコレータ完全ガイド + 型関係論・型推論パターン・型安全テクニック） |

#### インフラ・ツール

| スキル | 説明 |
|--------|------|
| `orchestrating-teams` | Agent Teamオーケストレーション（チーム編成・タチコマ並列起動・進捗管理・docs先行開発）。`HERDR_ENV=1` では `operating-herdr` と連携し、Claude CodeのiTerm2/tmux split-paneを使わず `herdr agent start/read/send/wait` で独立エージェントをペイン管理する。非herdr環境ではAgent Teams APIを使用 |
| `chronicle` | スクリーン録画・履歴参照スキル（Rolling Bufferで過去数時間の作業コンテキストを取得・OCR解析・作業の曖昧さ解消） |
| `orchestrating-codex` | Codex CLI統合スキル（基本操作・プランレビュー・Agentオーケストレーション・Wave並列実行・max_threads制御） |
| `converting-agents-to-codex` | Claude Code Agent定義（.md）をCodex subagent定義（.toml）に変換するガイド（フィールドマッピング・developer_instructions変換・モデルtier-map・skills description自動ロード・起動メカニズム・検証）。最新Codex仕様(developers.openai.com/codex)準拠 |
| `recommending-automations` | コードベースを解析し Claude Code / Codex 双方の自動化（hooks/subagents/skills/MCP servers/plugins）を推奨する読み取り専用レコメンダー。検出プラットフォーム（.claude・CLAUDE.md / .codex・AGENTS.md）を優先しつつ各レコメンドに両クライアントのセットアップ手順を併記。references/platform-matrix でクロスプラットフォーム対応表（hooks イベント名・subagent TOML・MCP map形式・skills パス差異）を提供。anthropics/claude-plugins-official (Apache-2.0) の翻案 |
| `searching-files-with-fff` | fff MCPによる高速ファイル検索（frecency順位付け・常駐インメモリインデックス）。3ツール（grep=内容検索/find_files=ファイル名fuzzy/multi_grep=複数パターンOR）・インライン制約構文・コアルール（bare identifierで検索・regex回避・2回で打切りRead）・DB永続化・serena/Glob/ripgrepとの使い分け |
| `operating-gitlab` | glab CLI（GitLab公式CLI）によるGitLab操作の包括的リファレンス。全コマンドグループ（auth/mr/issue/ci/repo/release/api/variable/schedule/label/milestone/snippet/runner/securefile/鍵管理 他）と認証（self-managed `--hostname`・`GITLAB_TOKEN`・CI job token）・主要ワークフロー（MR/CI/issue/release）を網羅。GitHub操作は`gh`/`pull-request`、コミット文言は`writing-conventional-commits`、レビュー方法論は`reviewing-code`へ |
| `operating-herdr` | herdr CLI（terminal-native agent multiplexer）操作。`HERDR_ENV=1` 環境で workspace/tab/pane の制御・pane 分割/移動/リサイズ/ナビゲーション（neighbor/focus/swap/zoom）・コマンド実行・出力読み取り（visible/recent/recent-unwrapped）・出力待機（リテラル/正規表現）・エージェントステータス待機・`herdr agent start` によるエージェント spawn/協調・`herdr integration install`（Claude/Codex 統合フック）を行う。herdr 外部からの操作は不可（HERDR_ENV ガード）。Claude Code 内の並列タチコマ編成は `orchestrating-teams` を使用し、herdrバックエンドでは本スキルを併用 |
| `reviewing-with-hunk` | Hunk（対話型ターミナル diff ビューア）を `hunk session *` CLI 経由で操作。file/hunk 構造の検査（`review --json`・生 diff は `--include-patch` で opt-in）・file/hunk/行へのナビゲート・内容差し替え（`reload -- diff/show`）・インラインレビューコメント（単発 `comment add` / stdin バッチ `comment apply`）を行う。TUI 本体はユーザーのもので対話コマンド（`hunk diff`/`show`）は直接叩かない。レビュー方法論は `reviewing-code`、GitLab MR 操作は `operating-gitlab` を参照 |

#### ドキュメント・品質

| スキル | 説明 |
|--------|------|
| `searching-web` | Web検索統合スキル（Exa MCP第一優先: 7カテゴリ検索/企業・コード・人物・財務・学術・個人サイト・Tweet/X ＋ gemini CLIフォールバック） |
| `writing-effective-prose` | 統合文章術スキル（論理構成・自然な文体・AI文章パターン診断・根拠/引用整合・生成痕跡除去・技術文書7Cs・学術文書・大学レポート/論文（卒論・実験レポート・引用・剽窃防止）・技術ブログ・README作成・Zenn記事作成・投稿ワークフロー・Web編集メソッド（完読概念/主眼と骨子/構造シート）・文書の構造設計（5要素階層/辞書形式vs読み物形式/認知心理学的基盤）・+書く心構え・キャリア / 人を動かす文書 / UXコピー / 五感で書く / 推敲困ったら・61リファレンスファイル） |
| `reviewing-code` | コードレビューガイドライン（PR構成・効果的コメント・トーン3原則: 客観性/具体性/明確なアウトカム・CodeRabbit統合・自動修正ループ） |

### Scripts (4個)

| スクリプト | 説明 |
|----------|------|
| `file-suggestion.sh` | ファイル候補検索ヘルパー（ripgrep + fzf でクエリにマッチするファイルを提示） |
| `zip-skills.sh` | `skills/` 配下の各スキルフォルダを個別にzipアーカイブ化 |
| `pdf-to-markdown` | PDF→Markdown変換バイナリ（`authoring-plugins` のPDF入力変換で使用） |
| `fff-mcp.sh` | fff MCPサーバ起動ラッパー（fff-mcpバイナリをPATH/~/.local/binで解決→無ければ公式インストーラで自動取得、frecency/history DBをXDG準拠で永続化）。`searching-files-with-fff` スキルが利用 |

### Hooks (12個)

| フック | トリガー | 説明 |
|-------|---------|------|
| `detect-project-skills` | SessionStart | セッション開始時にプロジェクト構成を検出し、推奨スキルを自動提示 |
| `read-handover` | SessionStart | 前回セッションの引き継ぎノート（HANDOVER.md / .claude/handovers/）を読み込んで注入 |
| `format-on-save` | PostToolUse(Edit\|Write) | ファイル保存時の自動フォーマット（TypeScript/JSON/Terraform等） |
| `learnings-error-detector` | PostToolUse(Bash) | Bashコマンドのエラーを検出し .learnings/ERRORS.md への記録を提案 |
| `learnings-reminder` | UserPromptSubmit | タスク完了後に .learnings/ への学び記録を促すリマインダー |
| `rtk-rewrite` | PreToolUse(Bash) | Bashコマンドを rtk 等価形へ書き換えトークン節約（rtk未導入時はno-op） |
| `notify-waiting` | Notification | 入力待ち時のデスクトップ通知（macOS） |
| `notify-complete` | Stop | タスク完了時のデスクトップ通知（macOS・最終メッセージ要約付き） |
| `notify-subagent-stop` | SubagentStop | サブエージェント完了時のデスクトップ通知（macOS） |
| `notify-teammate-idle` | TeammateIdle | teammate 待機時のデスクトップ通知（macOS） |
| `retrospective` | SessionEnd | セッション終了時に git データをデイリーレトロスペクティブへ追記 |
| `write-handover` | SessionEnd / PreCompact | セッション終了・compaction前に引き継ぎノートを自動生成 |

> **Codex CLI 配布**: hooks-codex.json で SessionStart / UserPromptSubmit / PreToolUse / PostToolUse / Stop / SubagentStop / PreCompact を登録（`.codex-plugin/plugin.json` の `hooks` キーで宣言・`${CLAUDE_PLUGIN_ROOT}` 非展開のため `./plugins/devkit/hooks/...` 相対パス）。Codex は Notification / SessionEnd / TeammateIdle を非対応のため、`notify-waiting` / `notify-teammate-idle` / `retrospective` は Claude Code 専用、`write-handover` は Codex では PreCompact のみ発火する。

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
| fff | 高速ファイル検索（frecency順位付け・grep=内容/find_files=ファイル名/multi_grep=複数OR・devkit同梱ラッパー経由） |

---

## 主な特徴

- **並列実行モデル**: タチコマ4体同時起動で独立タスクを並列処理
- **トークン効率化**: /serenaコマンドによる構造化開発
- **型安全性**: any/Any型の使用を厳格に禁止
- **セキュリティファースト**: 実装後のCodeGuard検証を必須化
- **自動フォーマット**: PostToolUseフックによるコード整形
- **二段階ロード**: SKILL.md（フロントマターのみ）+ INSTRUCTIONS.md（本文）でコンテキスト94.8%削減

---
