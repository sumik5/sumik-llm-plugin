# CLAUDE.md - sumik-claude-plugin

sumik Claude Code Plugin のプロジェクト固有開発ルール。

---

## ディレクトリ構成

このリポジトリは `plugins/` 配下に **13 個の兄弟プラグイン** を持つ。**devkit**（開発ワークフロー特化・agents/commands/hooks/MCP を含む本体・ユニバーサルコア＋オーケストレーション＋ワークフロー＋設計/レビュー practices 系 31 スキル）と、スキル/MCP 特化の 12 プラグイン: **studio**（コンテンツ制作・10）・**lang**（言語: Python/Go/R/Bash/DB/MCP/アルゴリズム・7 スキル）・**web**（Web/フロントエンド実装: Next.js/React/フルスタックJS/Web API/Tailwind/Figma実装/ブラウザ自動化/Vitest/Playwright E2E/APIスタイル選定/Node.jsサービス構築・13 スキル）・**cloud**（クラウド/インフラ/IaC/認可/セキュリティアーキテクチャ/クラウドセキュリティ知識体系・13 スキル）・**ai**（GenAI設計/AIエージェント/Web AI統合/LLM評価/AI支援開発/AI開発セキュリティ・6 スキル）・**design**（UX/デザイン思考/AI体験/データ可視化/デザインシステム・6 スキル）・**product**（プロダクトマネジメント/要件定義・2 スキル）・**university**（大学で使う Processing (Java Mode) 開発・1 スキル `developing-processing`）・**mobile**（Apple HIG と iPhone/iPad/Mac アプリ開発・Flutter/Dart クロスプラットフォーム開発・5 スキル `applying-apple-hig` / `developing-ios-apps` / `auditing-app-store-compliance` / `developing-dart` / `developing-flutter-apps`）、そして **exam**（生成AI活用試験の問題画像を解く・1 スキル `answering-genai-exam` ＋ 1 agent `exam-solver`）、さらに **google**（Google サービス連携: Google Analytics GA4 公式 MCP サーバー `analytics-mcp` を `pipx run` で同梱・1 スキル `analyzing-with-google-analytics`。MCP を持つため studio と同型の subdirectory + MCP 方式）、そして **certificate**（資格・検定の学習支援: kentei-lab.com 問題巡回取得・Anki フラッシュカード作成・教材 OCR/翻訳変換・3 スキル `collecting-kentei-lab-exams` / `creating-flashcards` / `converting-content` ＋ 1 コマンド `improve-creating-flashcards`）。lang/web/cloud/ai/design/product/university/mobile は **skills-only**（agents/commands/hooks/MCP/bin を持たず `.claude-plugin/plugin.json`・`.codex-plugin/plugin.json`・README.md・skills/ のみ。university は検証ヘルパー `scripts/verify-sketch.sh` をスキル内に bundle するが plugin レベルの bin は持たない）で、Codex 配布は **studio と同じ subdirectory-root 方式**。exam は **agent 入りだが commands/hooks/MCP/bin を持たない subdirectory 方式**（agent は Claude Code 専用で、Codex には skills のみ配布する）。certificate は **commands 入りだが agents/hooks/MCP/bin を持たない subdirectory 方式**（コマンド `improve-creating-flashcards` は Claude Code 専用で、Codex には skills のみ配布する）。全プラグインは同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から配布され、常にセットでインストールされる前提（devkit の agent が `studio:<skill>`・`lang:<skill>`・`web:<skill>`・`cloud:<skill>`・`ai:<skill>`・`design:<skill>`・`product:<skill>`・`certificate:<skill>` の修飾名でクロスプラグイン preload するため）。Claude Code プラグイン本体を `plugins/` 配下へ隔離しているのは、claude.ai の marketplace 同期が repo 丸ごとを取り込む際に Codex 異物が混入しないようにするため。ルートには claude.ai / Codex が最初に読む marketplace 定義と Codex 用マニフェストのみを残す。

```
plugins/devkit/              # ★ Claude Code プラグイン本体（開発ワークフロー特化・${CLAUDE_PLUGIN_ROOT}）
├── agents/                  # Agent定義（.md）
├── commands/                # スラッシュコマンド（.md）
├── hooks/                   # イベントフック（.sh）
├── bin/                     # MCPサーバー起動ラッパー（Claude/Codex 双方が参照）
├── scripts/                 # ヘルパースクリプト
├── skills/                  # ナレッジスキル（ディレクトリ/SKILL.md）
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 devkit・version 同期必須）
├── .mcp.json                # MCPサーバー設定（Claude Code 用・${CLAUDE_PLUGIN_ROOT}/bin/... 使用）
├── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 devkit）※実体は root の同名概念ではなく devkit 配下にも存在
└── .mcp-codex.json          # ※ devkit の Codex MCP は root の .mcp-codex.json を共有（plugin root = repo root のため）

plugins/studio/              # ★ Claude Code プラグイン（コンテンツ制作特化・agents/・hooks/ なし）
├── commands/                # スラッシュコマンド（.md）— epub-fix-cover
├── bin/                     # MCPサーバー起動ラッパー（npx-mise.sh・devkit から複製）
├── scripts/                 # ヘルパースクリプト（epub-fix-cover.sh）
├── skills/                  # ナレッジスキル（10個・ディレクトリ/SKILL.md）
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 studio・version 独立同期）
├── .mcp.json                # MCPサーバー設定（Claude Code 用・${CLAUDE_PLUGIN_ROOT}/bin/... 使用・drawio のみ）
├── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 studio・skills ./skills/）
└── .mcp-codex.json          # MCPサーバー設定（Codex 用・command "./bin/..." + cwd "."・drawio のみ）

plugins/lang/                # ★ skills-only プラグイン（言語: Python/Go/R/Bash/DB/MCP/アルゴリズム・subdirectory-root 方式）
├── skills/                  # ナレッジスキル（7個・ディレクトリ/SKILL.md。Web/フロントエンド実装は web プラグインへ分離）
├── README.md                # lang プラグインの README
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 lang・version 独立同期）
└── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 lang・skills ./skills/）※MCP/bin/agents/hooks なし → .mcp* なし

plugins/web/                 # ★ skills-only プラグイン（Web/フロントエンド実装・subdirectory 方式・lang から切出）
├── skills/                  # ナレッジスキル（11個・Next.js/React/フルスタックJS/Web API/フロントエンド設計/Tailwind/Figma実装/ブラウザ自動化/next-devtools/Vitest/Playwright E2E）
├── README.md                # web プラグインの README
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 web・version 独立同期）
└── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 web・skills ./skills/）※MCP/bin/agents/hooks なし → .mcp* なし

plugins/cloud/               # ★ skills-only プラグイン（クラウド/インフラ/IaC/認可/クラウドセキュリティ・subdirectory-root 方式）
├── skills/                  # ナレッジスキル（13個・ディレクトリ/SKILL.md）
├── README.md                # cloud プラグインの README
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 cloud・version 独立同期）
└── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 cloud・skills ./skills/）※MCP/bin/agents/hooks なし → .mcp* なし

plugins/ai/                  # ★ skills-only プラグイン（GenAI設計/AIエージェント/Web AI統合/LLM評価/AI支援開発/AI開発セキュリティ・subdirectory-root 方式）
├── skills/                  # ナレッジスキル（6個・ディレクトリ/SKILL.md）
├── README.md                # ai プラグインの README
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 ai・version 独立同期）
└── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 ai・skills ./skills/）※MCP/bin/agents/hooks なし → .mcp* なし

plugins/design/              # ★ skills-only プラグイン（UX/デザイン思考/AI体験/データ可視化/デザインシステム・subdirectory-root 方式）
├── skills/                  # ナレッジスキル（6個・ディレクトリ/SKILL.md）
├── README.md                # design プラグインの README
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 design・version 独立同期）
└── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 design・skills ./skills/）※MCP/bin/agents/hooks なし → .mcp* なし

plugins/product/             # ★ skills-only プラグイン（プロダクトマネジメント/要件定義・subdirectory 方式・devkit から切出）
├── skills/                  # ナレッジスキル（2個・practicing-product-management/writing-user-stories）
├── README.md                # product プラグインの README
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 product・version 独立同期）
└── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 product・skills ./skills/）※MCP/bin/agents/hooks なし → .mcp* なし

plugins/exam/                # ★ agent入りプラグイン（生成AI活用試験の解答生成・subdirectory 方式・commands/hooks/MCP/bin なし）
├── agents/                  # Agent定義（exam-solver.md・1体・Claude Code 専用）
├── skills/                  # ナレッジスキル（1個・answering-genai-exam）
├── README.md                # exam プラグインの README
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 exam・version 独立同期）
└── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 exam・skills ./skills/）※MCP/bin/hooks なし・agent は Claude 専用で Codex 非配布 → .mcp* なし

plugins/university/          # ★ 大学用 Processing 開発プラグイン（skills-only・subdirectory 方式・commands/hooks/MCP/bin/agents なし）
├── skills/                  # ナレッジスキル（1個・developing-processing。検証ヘルパー scripts/verify-sketch.sh をスキル内に bundle）
├── README.md                # university プラグインの README
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 university・version 独立同期）
└── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 university・skills ./skills/）※MCP/bin/agents/hooks なし → .mcp* なし

plugins/google/              # ★ Google サービス連携プラグイン（Google Analytics GA4 公式 MCP・subdirectory + MCP 方式・studio 同型）
├── bin/                     # MCPサーバー起動ラッパー（pipx-mise.sh・mise→pipx フォールバック）
├── skills/                  # ナレッジスキル（1個・analyzing-with-google-analytics）
├── README.md                # google プラグインの README
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 google・version 独立同期）
├── .mcp.json                # MCPサーバー設定（Claude Code 用・${CLAUDE_PLUGIN_ROOT}/bin/... 使用・analytics-mcp・env ブロックなし＝シェル継承）
├── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 google・skills ./skills/ ＋ mcpServers）
└── .mcp-codex.json          # MCPサーバー設定（Codex 用・command "./bin/pipx-mise.sh" + cwd "."・env はシェル継承）

plugins/mobile/              # ★ iPhone/iPad/Mac アプリ開発 + Flutter/Dart クロスプラットフォーム開発プラグイン（skills-only・subdirectory 方式）
├── skills/                  # ナレッジスキル（5個・applying-apple-hig / developing-ios-apps / auditing-app-store-compliance / developing-dart / developing-flutter-apps）
├── README.md                # mobile プラグインの README
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 mobile・version 独立同期）
└── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 mobile・skills ./skills/）※MCP/bin/agents/hooks なし → .mcp* なし

plugins/certificate/         # ★ 資格・検定学習支援プラグイン（commands 入り・subdirectory 方式・agents/hooks/MCP/bin なし）
├── commands/                # スラッシュコマンド（.md）— improve-creating-flashcards（creating-flashcards の自己改善・Claude Code 専用）
├── skills/                  # ナレッジスキル（3個・collecting-kentei-lab-exams / creating-flashcards / converting-content）
├── README.md                # certificate プラグインの README
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 certificate・version 独立同期）
└── .codex-plugin/plugin.json   # プラグインマニフェスト（Codex CLI 用・plugin名 certificate・skills ./skills/）※commands/MCP/bin/agents/hooks なし → .mcp* なし

.claude-plugin/marketplace.json   # claude.ai が読む marketplace（marketplace名 sumik・13 プラグイン devkit / studio / lang / web / cloud / ai / design / product / exam / university / google / mobile / certificate を列挙）
.codex-plugin/plugin.json         # プラグインマニフェスト（Codex CLI 用・devkit・skills ./plugins/devkit/skills/・version 同期必須）
.agents/plugins/marketplace.json  # Codex marketplace マニフェスト（marketplace名 sumik-marketplace・13 エントリ devkit / studio / lang / web / cloud / ai / design / product / exam / university / google / mobile / certificate・version）
.cache/sumik-marketplace/devkit  -> ../..                  # devkit の source.path symlink（repo root を指す・mode 120000・git 同梱）
.cache/sumik-marketplace/studio  -> ../../plugins/studio   # studio の source.path symlink（studio root を指す・mode 120000・git 同梱）
.cache/sumik-marketplace/lang    -> ../../plugins/lang     # lang の source.path symlink（lang root を指す・mode 120000・git 同梱）
.cache/sumik-marketplace/web     -> ../../plugins/web      # web の source.path symlink（web root を指す・mode 120000・git 同梱）
.cache/sumik-marketplace/cloud   -> ../../plugins/cloud    # cloud の source.path symlink（cloud root を指す・mode 120000・git 同梱）
.cache/sumik-marketplace/ai      -> ../../plugins/ai       # ai の source.path symlink（ai root を指す・mode 120000・git 同梱）
.cache/sumik-marketplace/design  -> ../../plugins/design   # design の source.path symlink（design root を指す・mode 120000・git 同梱）
.cache/sumik-marketplace/product -> ../../plugins/product  # product の source.path symlink（product root を指す・mode 120000・git 同梱）
.cache/sumik-marketplace/exam    -> ../../plugins/exam     # exam の source.path symlink（exam root を指す・mode 120000・git 同梱）
.cache/sumik-marketplace/university -> ../../plugins/university  # university の source.path symlink（university root を指す・mode 120000・git 同梱）
.cache/sumik-marketplace/google  -> ../../plugins/google   # google の source.path symlink（google root を指す・mode 120000・git 同梱）
.cache/sumik-marketplace/mobile  -> ../../plugins/mobile   # mobile の source.path symlink（mobile root を指す・mode 120000・git 同梱）
.cache/sumik-marketplace/certificate -> ../../plugins/certificate  # certificate の source.path symlink（certificate root を指す・mode 120000・git 同梱）
.mcp-codex.json                   # MCPサーバー設定（Codex 用・devkit・command "./plugins/devkit/bin/..." + cwd "."）
```

> **各プラグインの Codex plugin root の違い**: devkit は歴史的経緯で plugin root = **repo root**（symlink ターゲット `../..`・manifest は root の `.codex-plugin/plugin.json`・`.mcp-codex.json`）。studio / lang / web / cloud / ai / design / product / exam / university / google / mobile / certificate は **subdirectory 方式** で plugin root = `plugins/<p>/` 自体（symlink ターゲット `../../plugins/<p>`・manifest は `plugins/<p>/` 内・各 plugin root 基準の相対パス）。skills-only の lang/web/cloud/ai/design/product/university/mobile と exam（agent入りだが MCP/bin なし）・certificate（commands 入りだが MCP/bin なし）は MCP を持たないため `.mcp-codex.json` も存在しない（studio は drawio MCP・google は analytics-mcp を持つため `.mcp-codex.json` あり）。exam は agent（exam-solver）を持つが Codex には skills のみ配布する（agent は Claude Code 専用）。certificate は command（improve-creating-flashcards）を持つが Codex には skills のみ配布する（command は Claude Code 専用）。詳細は「Codex プラグイン配布の注意点」参照。

---

## 🔴 絶対ルール

### 書籍名・著者名・出版社名の禁止（最重要）

**このリポジトリ配下のスキル本文・参考資料・コミットメッセージ・ドキュメント・コード・コメントに、書籍名・著者名・出版社名を一切含めてはいけない。**

このリポジトリは公開Claude Codeプラグインであり、スキル本文・コミット履歴は全て公開対象になる。固有の書籍・著者への参照は著作権・第三者の権利・中立性の観点で不適切。スキルはあくまで汎用的なパターンとして記述する。

#### 対象範囲

| 場所 | 禁止例 | 推奨表現 |
|------|--------|---------|
| スキル本文（SKILL.md / INSTRUCTIONS.md / references/） | 「TAC ビジネス実務法務検定試験®一問一答エクスプレス」「Wallwork『国際学会プレゼン戦略』」「オライリー『〜』」 | 「資格試験対策書籍」「専門書」「学術論文向けガイド」など汎用記述 |
| コミットメッセージ | `feat(skill): Wallwork『〜』を反映` `書籍5冊の知見で〜` | `feat(skill): 国際学会発表向けのリファレンスを追加` |
| README / docs | 著者名・書名・ISBN・出版社名 | 「公開済みベストプラクティス」「業界標準パターン」など汎用記述 |
| コードコメント | `# 田中『〜』より` | `# 一般的な実装パターン` または出典記述なし |

#### チェックポイント

- スキル**および `agents/`（Claude `.md`・Codex `.toml`）・README** 編集後、変更ファイルに対して `grep -nE "『|』|著|出版|TAC|オライリー|オーム社|技術評論|翔泳社|日経BP|インプレス|Effective [A-Z]|Programming [A-Z]"` で残存固有名を機械チェックする。**掃討対象は `skills/` だけでなく `agents/`・README も含む**（過去 agents/ 本文に英字書名・「〜著」表記の著者名が残存していた）。`『』` 偏重では**英字書名・著者フルネーム・「〜著」**を取りこぼすため多角的パターンで確認する
- コミット前にメッセージから書籍名・著者名・出版社名を除去する
- 既存の過去コミットに固有名が含まれていても、それを参考に新規コミットを書かないこと（過去分は遡及修正しない）
- 知見の出典が必要な場合は「業界標準」「広く知られたパターン」「公開資料」等の汎用表現に置き換える

### README.md の自動同期（最重要）

**コンポーネントの追加・変更・削除を行った場合、同一タスク内でREADME.mdも必ず更新する。**

#### 自動同期ルール

Claude Code本体がタチコマにタスクを振る際、以下のいずれかに該当する変更が含まれる場合、**README.md更新をタチコマの作業スコープに自動的に含める**こと（ユーザーからの個別指示は不要）:

- Agent の追加・削除・名称変更
- Command の追加・削除・名称変更
- Skill の追加・削除・名称変更
- Hook の追加・削除
- MCP Server の追加・削除
- プラグインバージョンの更新（plugin.json）
- ディレクトリ構成の変更
- **スキル/コマンドがプラグイン間（devkit / studio / lang / web / cloud / ai / design / product / google のいずれか ↔ いずれか）を移動した場合は、関係する両プラグインの README を同時更新する**。README パスは devkit が repo root の `README.md`、その他は `plugins/<plugin>/README.md`（`plugins/studio/README.md`・`plugins/lang/README.md`・`plugins/web/README.md`・`plugins/cloud/README.md`・`plugins/ai/README.md`・`plugins/design/README.md`・`plugins/product/README.md`・`plugins/google/README.md`）。移動元のカウント・テーブル行削除と移動先のカウント・テーブル行追加を 1 タスク内で整合させる

> **⚠️ 注意**: `.claude-plugin/plugin.json` の修正はREADME.md自動同期の対象外とする。バージョン更新等はユーザーが明示的に指示した場合のみ行うこと。

#### 更新手順

タチコマは以下の手順でREADME.mdを更新する:

1. **カウント更新**: ディレクトリ構成セクションとコンポーネント一覧見出しの個数を実数と一致させる
2. **テーブル追加/削除**: 該当カテゴリのテーブルにコンポーネント行を追加・削除
3. **カテゴリ判定**: 新規スキルは以下のカテゴリに分類
   | カテゴリ | 対象 |
   |---------|------|
   | コア開発 | Agent運用、型安全、テスト、セキュリティ等 |
   | アーキテクチャ | 設計原則、モダナイゼーション |
   | フレームワーク | 言語・フレームワーク固有 |
   | フロントエンド・デザイン | UI/UX、デザインツール |
   | ブラウザ自動化 | ブラウザ操作・テスト |
   | インフラ・ツール | Docker、Git、DevTools |
   | ドキュメント・品質 | 文書作成、コードレビュー |

#### 並列実行時の扱い

複数タチコマ並列実行時は、README.md更新を**最後に実行するタチコマ1体に集約**するか、**全タチコマ完了後にClaude Code本体が別タチコマを起動**して一括更新する。競合を避けるため、複数タチコマが同時にREADME.mdを編集しないこと。

### バージョン管理

- **13 プラグイン（devkit / studio / lang / web / cloud / ai / design / product / exam / university / google / mobile / certificate）はそれぞれ独立した version を持つ**（別プラグインのため別系列で進める。現状: devkit 14.9.2・studio 2.0.0・lang 2.2.1・web 1.2.0・cloud 1.2.0・ai 1.2.3・design 1.0.2・product 1.0.2・exam 1.2.2・university / google は 1.0.0・mobile は 1.3.0・certificate は 1.0.0）
- devkit の version は `plugins/devkit/.claude-plugin/plugin.json` の `version` フィールドで管理（**devkit の 3 ファイルを必ず同期**→下記参照）
- studio の version は `plugins/studio/.claude-plugin/plugin.json` の `version` フィールドで管理（**studio の 3 ファイルを必ず同期**→下記参照）
- lang / web / cloud / ai / design / product / exam / university / google / mobile / certificate の version は各 `plugins/<plugin>/.claude-plugin/plugin.json` の `version` フィールドで管理（**各プラグインの 3 ファイルを必ず同期**→下記参照）
- Semantic Versioning (semver) に従う:
  - **MAJOR**: 破壊的変更（スキルの大幅な構成変更等。プラグインからのコンポーネント削除も該当）
  - **MINOR**: 新規コンポーネント追加（新スキル、新コマンド等）
  - **PATCH**: 既存コンポーネントの修正・改善

### バージョンファイルの同期（🔴 重要）

各プラグインの `version` を更新する際は、必ずそのプラグインの **3ファイルすべてを同じ値に同期**すること。Claude Code / Codex CLI / Codex marketplace カタログがそれぞれ別ファイルを参照するため、一部だけ更新すると配布物の整合性が崩れる（過去 marketplace.json の version が取り残された実績あり）。**13 プラグインは別系列のため、互いの version を揃える必要はない**（それぞれ自分の 3 ファイル内で一致させる）。

**devkit の 3 ファイル**

| ファイル | 役割 |
|---------|------|
| `plugins/devkit/.claude-plugin/plugin.json` の `version` | Claude Code の参照 version |
| `.codex-plugin/plugin.json` の `version` | Codex CLI の参照 version |
| `.agents/plugins/marketplace.json` の devkit エントリ `version` | Codex marketplace カタログ version（**更新漏れしやすい**） |

**studio の 3 ファイル**

| ファイル | 役割 |
|---------|------|
| `plugins/studio/.claude-plugin/plugin.json` の `version` | Claude Code の参照 version |
| `plugins/studio/.codex-plugin/plugin.json` の `version` | Codex CLI の参照 version |
| `.agents/plugins/marketplace.json` の studio エントリ `version` | Codex marketplace カタログ version（**更新漏れしやすい**） |

**lang / web / cloud / ai / design / product / exam / university / google / mobile / certificate の 3 ファイル**（`<plugin>` を該当プラグイン名に置換）

| ファイル | 役割 |
|---------|------|
| `plugins/<plugin>/.claude-plugin/plugin.json` の `version` | Claude Code の参照 version |
| `plugins/<plugin>/.codex-plugin/plugin.json` の `version` | Codex CLI の参照 version |
| `.agents/plugins/marketplace.json` の `<plugin>` エントリ `version` | Codex marketplace カタログ version（**更新漏れしやすい**） |

#### 同期チェック

コミット前に 13 プラグインの version 一致を確認すること（`.agents/plugins/marketplace.json` の `plugins[]` 配列は順序依存しないよう name で引く）。期待値: devkit 14.9.2・studio 2.0.0・lang 2.2.1・web 1.2.0・cloud 1.2.0・ai 1.2.3・design 1.0.2・product 1.0.2・exam 1.2.2・university / google は 1.0.0・mobile は 1.3.0・certificate は 1.0.0:

```bash
python3 - <<'PY'
import json
checks = {
    "devkit": [
        ("plugins/devkit/.claude-plugin/plugin.json", lambda d: d["version"]),
        (".codex-plugin/plugin.json",                 lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="devkit")),
    ],
    "studio": [
        ("plugins/studio/.claude-plugin/plugin.json", lambda d: d["version"]),
        ("plugins/studio/.codex-plugin/plugin.json",  lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="studio")),
    ],
    "lang": [
        ("plugins/lang/.claude-plugin/plugin.json",   lambda d: d["version"]),
        ("plugins/lang/.codex-plugin/plugin.json",    lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="lang")),
    ],
    "web": [
        ("plugins/web/.claude-plugin/plugin.json",    lambda d: d["version"]),
        ("plugins/web/.codex-plugin/plugin.json",     lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="web")),
    ],
    "cloud": [
        ("plugins/cloud/.claude-plugin/plugin.json",  lambda d: d["version"]),
        ("plugins/cloud/.codex-plugin/plugin.json",   lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="cloud")),
    ],
    "ai": [
        ("plugins/ai/.claude-plugin/plugin.json",     lambda d: d["version"]),
        ("plugins/ai/.codex-plugin/plugin.json",      lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="ai")),
    ],
    "design": [
        ("plugins/design/.claude-plugin/plugin.json", lambda d: d["version"]),
        ("plugins/design/.codex-plugin/plugin.json",  lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="design")),
    ],
    "product": [
        ("plugins/product/.claude-plugin/plugin.json", lambda d: d["version"]),
        ("plugins/product/.codex-plugin/plugin.json",  lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="product")),
    ],
    "exam": [
        ("plugins/exam/.claude-plugin/plugin.json",   lambda d: d["version"]),
        ("plugins/exam/.codex-plugin/plugin.json",    lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="exam")),
    ],
    "university": [
        ("plugins/university/.claude-plugin/plugin.json", lambda d: d["version"]),
        ("plugins/university/.codex-plugin/plugin.json",  lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="university")),
    ],
    "google": [
        ("plugins/google/.claude-plugin/plugin.json", lambda d: d["version"]),
        ("plugins/google/.codex-plugin/plugin.json",  lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="google")),
    ],
    "mobile": [
        ("plugins/mobile/.claude-plugin/plugin.json", lambda d: d["version"]),
        ("plugins/mobile/.codex-plugin/plugin.json",  lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="mobile")),
    ],
    "certificate": [
        ("plugins/certificate/.claude-plugin/plugin.json", lambda d: d["version"]),
        ("plugins/certificate/.codex-plugin/plugin.json",  lambda d: d["version"]),
        (".agents/plugins/marketplace.json",          lambda d: next(p["version"] for p in d["plugins"] if p["name"]=="certificate")),
    ],
}
expected = {"devkit": "14.9.2", "studio": "2.0.0", "lang": "2.2.1", "web": "1.2.0",
            "cloud": "1.2.0", "ai": "1.2.3", "design": "1.0.2",
            "product": "1.0.2", "exam": "1.2.2", "university": "1.0.0",
            "google": "1.0.0", "mobile": "1.3.0", "certificate": "1.0.0"}
all_ok = True
for plugin, files in checks.items():
    vals = [getter(json.load(open(path))) for path, getter in files]
    ok = len(set(vals)) == 1 and vals[0] == expected[plugin]
    all_ok &= ok
    print(f"{plugin:8} {'OK ' if ok else 'MISMATCH'} {vals}  (expected {expected[plugin]})")
print("ALL OK" if all_ok else "FAILED")
PY
```

### Codex プラグイン配布の注意点

Codex CLI への配布（marketplace / plugin / MCP）固有の罠。

> **配布方式①（devkit・確定）**: Claude プラグイン本体を `plugins/devkit/` へ隔離後も、Codex の plugin root は **repo root のまま**にする。`.cache/sumik-marketplace/devkit` symlink のターゲットは `../..`（= repo root）を**据え置く**。これにより Codex は git clone した repo root を plugin ディレクトリとして読み、ルートの `.codex-plugin/plugin.json`・`.mcp-codex.json` が確実に解決される。実体（skills/bin/scripts）は `plugins/devkit/` の1箇所に集約し、Codex はルートのマニフェストから `./plugins/devkit/...` で共有参照する（重複コピーを作らない）。

> **配布方式②（studio・確定）**: studio は devkit のようなレガシーがないため、Codex の plugin root = **`plugins/studio/` 自体**（subdirectory 方式）。`.cache/sumik-marketplace/studio` symlink のターゲットは `../../plugins/studio`（= studio root を指す。**devkit の `../..` とは異なる**）。manifest は `plugins/studio/` 内に置き（`.codex-plugin/plugin.json`・`.mcp-codex.json`）、studio root 基準の相対パスで自己完結させる（`skills: "./skills/"`・MCP `command: "./bin/npx-mise.sh"` + `cwd: "."`）。**devkit の symlink・manifest は一切変更しない**。

> **配布方式③（lang/web/cloud/ai/design/product/mobile・確定）**: studio と同じ **subdirectory 方式**。各 plugin root = `plugins/<p>/` 自体、`.cache/sumik-marketplace/<p>` symlink のターゲットは `../../plugins/<p>`（= 各 plugin root を指す）。manifest は `plugins/<p>/.codex-plugin/plugin.json` に置き、plugin root 基準の相対パス `skills: "./skills/"` で自己完結させる。**これら 7 プラグインは MCP/bin を持たない skills-only のため `.mcp-codex.json` を持たず**（studio と異なる点）、`.codex-plugin/plugin.json` に `mcpServers` キーも記述しない。web/product は lang/devkit からのスキル切り出しで新設（web=lang から 9＋devkit から 2(Vitest/Playwright)＝11 スキル、product=devkit から 2 スキル）。reviewing-code・applying-clean-architecture は devkit に留置／復帰、securing-ai-development は ai へ統合（qa プラグインは新設せず）。**devkit・studio の symlink・manifest は一切変更しない**。

> **配布方式④（exam・確定）**: ③ と同じ **subdirectory 方式**（symlink ターゲット `../../plugins/exam`・manifest は `plugins/exam/.codex-plugin/plugin.json`・`skills: "./skills/"`）。exam は **agent（exam-solver）を持つが Codex には skills のみ配布**し、`.codex-plugin/plugin.json` に `agents`/`mcpServers` キーを記述しない（agent は Claude Code 専用。複数画像の並列求解が必要な状況は Claude Code 側でのみ機能し、Codex では本体が逐次処理する）。MCP/bin/hooks を持たないため `.mcp-codex.json` も持たない。**devkit・studio・他 skills-only の symlink・manifest は一切変更しない**。

> **配布方式⑤（university・確定）**: ③ と同じ **subdirectory 方式**（symlink ターゲット `../../plugins/university`・manifest は `plugins/university/.codex-plugin/plugin.json`・`skills: "./skills/"`）。university は **skills-only**（plugin レベルの agents/MCP/bin/commands/hooks なし）で、`.codex-plugin/plugin.json` に `agents`/`mcpServers` キーを記述せず、MCP を持たないため `.mcp-codex.json` も持たない。検証ヘルパー `scripts/verify-sketch.sh` はスキル `developing-processing` 配下に bundle され（plugin レベルの bin ではない）、Claude/Codex 双方で skill と共に配布される。**devkit・studio・他 skills-only の symlink・manifest は一切変更しない**。

> **配布方式⑥（google・確定）**: ② と同じ **subdirectory + MCP 方式**（studio 同型）。symlink ターゲット `../../plugins/google`・manifest は `plugins/google/.codex-plugin/plugin.json`・`skills: "./skills/"`。google は **MCP（analytics-mcp）を持つ**ため `.mcp-codex.json` を持ち（`command: "./bin/pipx-mise.sh"` + `cwd: "."`・`pipx run analytics-mcp` で起動）、`.codex-plugin/plugin.json` に `mcpServers: "./.mcp-codex.json"` を記述する。認証情報（`GOOGLE_APPLICATION_CREDENTIALS` / `GOOGLE_PROJECT_ID`）は Claude/Codex とも **`env` ブロックを持たず**（devkit/studio と同じ慣習）、シェルで `export` した値を MCP サーバーが親プロセス環境として継承する（秘匿値はコミットしない・空文字で ADC を壊す罠も回避）。**devkit・studio・他プラグインの symlink・manifest は一切変更しない**。

> **配布方式⑦（certificate・確定）**: ③ と同じ **subdirectory 方式**（symlink ターゲット `../../plugins/certificate`・manifest は `plugins/certificate/.codex-plugin/plugin.json`・`skills: "./skills/"`）。certificate は **command（improve-creating-flashcards）を持つが Codex には skills のみ配布**し、`.codex-plugin/plugin.json` に `commands`/`mcpServers` キーを記述しない（コマンドは Claude Code 専用の自己改善コマンドで、creating-flashcards スキル自身を編集・version bump する）。MCP/bin/hooks/agents を持たないため `.mcp-codex.json` も持たない。studio の `creating-flashcards`・`converting-content` スキルと `improve-creating-flashcards` コマンドを移動して新設（studio は MAJOR bump 1.2.2→2.0.0）。**devkit・studio・他 skills-only の symlink・manifest は一切変更しない**。

| If X | then Y |
|------|--------|
| devkit の Codex 用 MCP サーバーを定義する時 | **`${CLAUDE_PLUGIN_ROOT}` を使わない**（Codex は非展開で `os error 2`）。`.mcp-codex.json`（root）に `command: "./plugins/devkit/bin/..."` の**相対パス + `"cwd": "."`**（= repo root 基準）で記述し、`.codex-plugin/plugin.json` の `"mcpServers": "./.mcp-codex.json"` で宣言する。Claude Code 用 `plugins/devkit/.mcp.json`（`${CLAUDE_PLUGIN_ROOT}/bin/...` 使用）は別ファイルとして温存し両者を混ぜない |
| studio の Codex 用 MCP サーバーを定義する時 | 同じく **`${CLAUDE_PLUGIN_ROOT}` を使わない**。ただし studio は plugin root = `plugins/studio/` のため、`plugins/studio/.mcp-codex.json` に `command: "./bin/npx-mise.sh"` の**相対パス + `"cwd": "."`**（= **studio root 基準**・devkit の `./plugins/devkit/...` とは異なる）で記述し、`plugins/studio/.codex-plugin/plugin.json` の `"mcpServers": "./.mcp-codex.json"` で宣言する。Claude Code 用 `plugins/studio/.mcp.json`（`${CLAUDE_PLUGIN_ROOT}/bin/...` 使用）は温存 |
| devkit の Codex 用 `.codex-plugin/plugin.json` の skills パス | Codex plugin root = repo root のため、移動後の実体を `"skills": "./plugins/devkit/skills/"` で参照する（`mcpServers` は `"./.mcp-codex.json"` 据え置き） |
| studio の Codex 用 `.codex-plugin/plugin.json` の skills パス | Codex plugin root = `plugins/studio/` のため、`"skills": "./skills/"`（studio root 基準・devkit の `./plugins/devkit/skills/` とは異なる）。`mcpServers` は `"./.mcp-codex.json"` |
| lang/web/cloud/ai/design/product/mobile の Codex 用 `.codex-plugin/plugin.json` の skills パス | 各 plugin root = `plugins/<p>/` のため、`"skills": "./skills/"`（studio と同形）。**skills-only のため `mcpServers` キーは記述しない**（`.mcp-codex.json` も持たない） |
| google の Codex 用 MCP サーバーを定義する時 | studio と同型（**`${CLAUDE_PLUGIN_ROOT}` を使わない**）。plugin root = `plugins/google/` のため、`plugins/google/.mcp-codex.json` に `command: "./bin/pipx-mise.sh"` の**相対パス + `"cwd": "."`**（= google root 基準）で記述し、`plugins/google/.codex-plugin/plugin.json` の `"mcpServers": "./.mcp-codex.json"` で宣言する。Claude 用 `plugins/google/.mcp.json` は `command: "${CLAUDE_PLUGIN_ROOT}/bin/pipx-mise.sh"` を使う。**両者とも `env` ブロックを置かない**（devkit/studio と同じ慣習）。認証情報はシェルで `export` した `GOOGLE_APPLICATION_CREDENTIALS` / `GOOGLE_PROJECT_ID` を MCP サーバーが親プロセス環境として継承する |
| google の Codex 用 `.codex-plugin/plugin.json` の skills パス | plugin root = `plugins/google/` のため、`"skills": "./skills/"`（studio と同形）。**MCP を持つため `mcpServers: "./.mcp-codex.json"` を記述する**（skills-only との違い） |
| certificate の Codex 用 `.codex-plugin/plugin.json` の skills パス | plugin root = `plugins/certificate/` のため、`"skills": "./skills/"`（studio と同形）。**command（improve-creating-flashcards）は Claude Code 専用のため `commands` キーを記述しない・MCP も無いため `mcpServers` キーも記述しない**（`.mcp-codex.json` も持たない） |
| `.cache/` 配下のパス（marketplace の source.path symlink 等）を追加/リネームする時 | `.gitignore` の `.cache/**` を打ち消す `!` 例外行も新パスへ追加/更新する（現状は `!.cache/sumik-marketplace/devkit`・`studio`・`lang`・`web`・`cloud`・`ai`・`design`・`product`・`exam`・`university`・`google`・`mobile`・`certificate` の**13行**）。漏れると新パスが黙って ignore され commit されず、git clone に含まれず Codex の `source.path` が壊れる。**commit 後に `git ls-tree -r HEAD --name-only \| /usr/bin/grep '^.cache/'` で 13 symlink（ai / certificate / cloud / design / devkit / exam / google / lang / mobile / product / studio / university / web）全ての同梱を必ず検証**（`git check-ignore` は negation でも exit 0 を返すため判定に使わない） |
| Codex marketplace / plugin の名称 | marketplace = `sumik-marketplace`（`.agents/plugins/marketplace.json` の `name`）／ plugin = `devkit`・`studio`・`lang`・`web`・`cloud`・`ai`・`design`・`product`・`exam`・`university`・`google`・`mobile`・`certificate`（同 `plugins[].name` + 各 `.codex-plugin/plugin.json` の `name`）。インストールは `codex plugin add <plugin>@sumik-marketplace` を 13 プラグイン分実行 |
| Codex プラグインを追加/更新する時 | git 方式。**repo 変更を push 後**に `~/dotfiles/codex/install-sumik-codex-plugin.sh` を実行（marketplace add/upgrade → plugin add → agents/・AGENTS.md を `~/.codex/` へ symlink）→ Codex 再起動。**同スクリプトは devkit / studio / lang / web / cloud / ai / design / product / exam / university / google / mobile / certificate の 13 プラグインを学習する必要がある（各 `codex plugin add <plugin>@sumik-marketplace` 行の追加・studio/lang/web/cloud/ai/design/product/university/google/mobile/certificate は agent 0 体・exam は agent を Claude 専用とし Codex へ配布しないため、いずれも agent symlink 行は不要）。repo 外・dotfiles 側（`PLUGINS=(...)` 配列＋コメント）は certificate 追加時に対応済み** |
| Codex プラグインの版・hook・MCP の実体を確認する時 | `~/.codex/plugins/cache/...` を信用しない（**陳腐化した別キャッシュ**）。`codex plugin list` の **PATH 列**が示す実体パス（marketplace チェックアウト）の `.codex-plugin/plugin.json`・hooks 定義を読む。marketplace 更新直後に同梱 MCP が一斉に `No such file or directory (os error 2)` で失敗する場合は versioned cache 生成中の一時競合＝**設定を書き換えず**、cache 完成後に Codex を新規起動すれば解消する |
| symlink 追跡ツール（Serena の activate 等）が `File name too long` で失敗する時 | devkit の `.cache/sumik-marketplace/devkit -> ../..` が**自己再帰パス**（`.cache/.../devkit/.cache/.../devkit/...`）を作るため。ツール側に `.cache/` 除外を設定して回避する（subdirectory 方式の他 11 プラグインでは構造的に発生しない） |

---

## コンポーネント開発ガイドライン

### Agent (.md)

- 配置: `plugins/devkit/agents/<name>.md`
- フロントマター必須: `---` で囲んだYAMLヘッダー
- 必須フィールド: model, description
- 命名: ケバブケース（例: `serena-expert.md`）

### Command (.md)

- 配置: `plugins/devkit/commands/<name>.md`
- フロントマター必須: `---` で囲んだYAMLヘッダー
- 必須フィールド: description, allowed-tools
- user-invocable: true で `/name` として呼び出し可能
- 命名: ケバブケース（例: `pull-request.md`）

### Skill (ディレクトリ)

- 配置: `plugins/devkit/skills/<skill-name>/SKILL.md`
- ディレクトリ名: 動名詞形（verb + -ing）
  - ✅ `developing-nextjs`, `writing-clean-code`
  - ❌ `nextjs-development`, `solid-principles`
- SKILL.md: 500行以内を推奨
- 詳細は別ファイルに分離（Progressive Disclosure）:
  - `REFERENCE.md`, `EXAMPLES.md`, `COMMANDS.md` 等
- フロントマター必須: description（三部構成）
  - 1行目: 機能の端的な説明
  - 2行目: 使用タイミング（Use when ...）
  - 3行目以降: 補足的なトリガー情報

### Hook (.sh)

- 配置: `plugins/devkit/hooks/<name>.sh`
- 実行可能権限必須: `chmod +x`
- イベント: PreToolUse, PostToolUse, Stop 等
- plugin.json の hooks セクションで登録

### MCP Server

- 設定: `plugins/devkit/.mcp.json`（Claude Code 用）／ `.mcp-codex.json`（Codex 用・root）に定義
- 新規追加時は動作確認を実施
- 環境変数の依存を明記

---

## 命名規則

| コンポーネント | 命名規則 | 例 |
|--------------|---------|-----|
| Agent | ケバブケース | `serena-expert.md` |
| Command | ケバブケース | `pull-request.md` |
| Skill | 動名詞 + ケバブケース | `developing-nextjs/` |
| Hook | ケバブケース | `format-on-save.sh` |

---

## 品質チェックリスト

新規コンポーネント追加時:
- [ ] フロントマターが正しく記述されている
- [ ] description が三部構成になっている（スキルの場合）
- [ ] `plugin.json` への登録が完了している（必要な場合）
- [ ] `README.md` が更新されている
- [ ] 既存コンポーネントとの整合性が取れている

---

## 開発時の注意事項

- このリポジトリはClaude Code Pluginの定義ファイル群であり、ランタイムコードは含まない
- スキルの記述言語は日本語を基本とする
- フロントマターのフィールドはClaude Codeの仕様に従うこと
- `plugins/devkit/.mcp.json` の変更はClaude Codeの再起動が必要

### git コミット/タグ/push 時の注意（環境依存の罠）

| If X | then Y |
|------|--------|
| version bump + commit + tag + push を実行する時 | `git commit`/`tag`/`push` 等の .git 書込はサンドボックス下で**偽の `exit=0` を返して不発**になることがある。**`dangerouslyDisableSandbox: true`** で実行する（git 書込はユーザー明示依頼時のみ） |
| commit/tag メッセージに全角記号（`「」（）→`）や `<...>` を含む時 | `-m` 直渡しはパース崩れで不発。**Write でメッセージファイルを作り `-F <file>`** で渡す |
| `git commit`/`git tag -a` が `gpg: signing failed`＋`PINENTRY_LAUNCHED ... not a tty` で不発になる時 | `commit.gpgsign=true` 環境で非 tty の Bash が pinentry を起動できないため（`dangerouslyDisableSandbox` でも解消しない）。ユーザー自身の tty（`! ` 実行）で署名付き実行してもらうか、`--no-gpg-sign`・lightweight で回避し必要時に `--amend -S`。失敗後も index は保持され再 add 不要 |
| `git tag <name>` が `fatal: no tag message?` で失敗する時 | `tag.gpgsign=true` のためタグは常に annotated 扱い＝メッセージ必須。**`git tag -m "<短い要約>" <name>`** で作成する（`-m` なしの軽量タグは非対話実行下で常に失敗） |
| 複合コマンドで `cd <dir> &&` を先頭に置く時 | パーミッションプロンプトを誘発しチェーン全体が不発になる。`cd` を使わず作業ディレクトリ既定のまま実行する |
| コマンドの `exit=0`/`RC=0` を見た時 | 鵜呑みにせず `git log -1 --format='%H %s'`・`git tag --points-at HEAD`・`git status --porcelain` で**実体検証**する |
| `grep -h`・`rm -f` 等のフラグが化ける／`git diff` 出力にノイズが混入する時 | rtk プロキシ起因。`/usr/bin/grep`・`/bin/rm` 等の絶対パスで呼ぶ |
