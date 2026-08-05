# CLAUDE.md - sumik-claude-plugin

sumik Claude Code Plugin のプロジェクト固有開発ルール。

---

## ディレクトリ構成

このリポジトリは `plugins/` 配下に **13 個の兄弟プラグイン** を持つ。**devkit**（開発ワークフロー特化・agents/commands/hooks/MCP を含む本体・ユニバーサルコア＋オーケストレーション＋ワークフロー＋設計/レビュー practices 系 31 スキル）と、スキル/MCP 特化の 12 プラグイン: **studio**（コンテンツ制作・10）・**lang**（言語: Python/Go/R/Bash/DB/SQLクエリ実践/MCP/アルゴリズム・8 スキル）・**web**（Web/フロントエンド実装: Next.js/React/フルスタックJS/Web API/APIセキュリティ/Tailwind/Figma実装/ブラウザ自動化/Vitest/Playwright E2E/APIスタイル選定/Node.jsサービス構築・14 スキル）・**cloud**（クラウド/インフラ/IaC/認可/セキュリティアーキテクチャ/クラウドセキュリティ知識体系・13 スキル）・**ai**（GenAI設計/AIエージェント/Web AI統合/LLM評価/AI支援開発/AI開発セキュリティ・6 スキル）・**design**（UX/デザイン思考/AI体験/データ可視化/デザインシステム・6 スキル）・**product**（プロダクトマネジメント/要件定義・2 スキル）・**university**（大学で使う Processing (Java Mode) 開発・1 スキル `developing-processing`）・**mobile**（Apple HIG と iPhone/iPad/Mac アプリ開発・Flutter/Dart クロスプラットフォーム開発・5 スキル `applying-apple-hig` / `developing-ios-apps` / `auditing-app-store-compliance` / `developing-dart` / `developing-flutter-apps`）、そして **exam**（生成AI活用試験の問題画像を解く・1 スキル `answering-genai-exam` ＋ 1 agent `exam-solver`）、さらに **google**（Google サービス連携: Google Analytics GA4 公式 MCP サーバー `analytics-mcp` を `pipx run` で同梱・1 スキル `analyzing-with-google-analytics`。MCP を持つため studio と同型の subdirectory + MCP 方式）、そして **certificate**（資格・検定の学習支援: URL問題収集内蔵の Anki フラッシュカード作成・教材 OCR/翻訳変換・2 スキル `creating-flashcards` / `converting-content` ＋ 1 コマンド `improve-creating-flashcards`）。lang/web/cloud/ai/design/product/university/mobile は **skills-only**（agents/commands/hooks/MCP/bin を持たず `.claude-plugin/plugin.json`・`.codex-plugin/plugin.json`・README.md・skills/ のみ。university は検証ヘルパー `scripts/verify-sketch.sh` をスキル内に bundle するが plugin レベルの bin は持たない）で、Codex 配布は **studio と同じ subdirectory-root 方式**。exam は **agent 入りだが commands/hooks/MCP/bin を持たない subdirectory 方式**（agent は Claude Code 専用で、Codex には skills のみ配布する）。certificate は **commands 入りだが agents/hooks/MCP/bin を持たない subdirectory 方式**（コマンド `improve-creating-flashcards` は Claude Code 専用で、Codex には skills のみ配布する）。全プラグインは同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から配布され、常にセットでインストールされる前提（devkit の agent が `studio:<skill>`・`lang:<skill>`・`web:<skill>`・`cloud:<skill>`・`ai:<skill>`・`design:<skill>`・`product:<skill>`・`certificate:<skill>` の修飾名でクロスプラグイン preload するため）。Claude Code プラグイン本体を `plugins/` 配下へ隔離しているのは、claude.ai の marketplace 同期が repo 丸ごとを取り込む際に Codex 異物が混入しないようにするため。ルートには claude.ai / Codex が最初に読む marketplace 定義と Codex 用マニフェストのみを残す。

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
├── skills/                  # ナレッジスキル（14個・Next.js/React/フルスタックJS/Web API/APIセキュリティ/フロントエンド設計/Tailwind/Figma実装/ブラウザ自動化/next-devtools/Vitest/Playwright E2E）
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
├── skills/                  # ナレッジスキル（2個・creating-flashcards / converting-content）
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
4. **実数表現の突合（🔴 見落としやすい）**: README.md本体だけでなく、`.claude-plugin/plugin.json`・`.codex-plugin/plugin.json`・`.agents/plugins/marketplace.json` の `description` 内に「Nコマンド」「Nスキル」等の自由文中の実数表現が紛れていないか `grep` で洗い出し、実数と食い違っていれば更新する（`scripts/check-version-sync.py` は3ファイルの `version` フィールド一致のみを検証し、description内の実数表現までは見ない。過去に並列タチコマがそれぞれ担当ファイル本体を正確に仕上げたのに、この境界線上の実数だけ誰の担当にも入らず抜け落ちた実績あり）

#### 並列実行時の扱い

複数タチコマ並列実行時は、README.md更新を**最後に実行するタチコマ1体に集約**するか、**全タチコマ完了後にClaude Code本体が別タチコマを起動**して一括更新する。競合を避けるため、複数タチコマが同時にREADME.mdを編集しないこと。

### バージョン管理

- **13 プラグイン（devkit / studio / lang / web / cloud / ai / design / product / exam / university / google / mobile / certificate）はそれぞれ独立した version を持つ**（別プラグインのため別系列で進める。現在値は各 `plugin.json` が正・`python3 scripts/check-version-sync.py` で確認する）
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

コミット前に `python3 scripts/check-version-sync.py` を実行し、13 プラグインすべてで3ファイル（`.claude-plugin/plugin.json`・`.codex-plugin/plugin.json`・`.agents/plugins/marketplace.json`）の version が一致しているか確認する。このスクリプトは3ファイル間の一致のみを見る（絶対値の期待値は持たない）ため、bump のたびにこのスクリプトや本ファイルを書き換える必要はない。

### Codex プラグイン配布の注意点

新規プラグインを追加する時・既存プラグインのCodex配布設定を変更する時は `authoring-plugins` スキルの `references/MANAGING-MULTI-PLUGIN.md`（汎用パターン＋「sumik-claude-plugin リポジトリでの確定実例」節に13プラグイン全ての plugin root・symlink ターゲット・MCP定義を記載）を参照する。

---

## コンポーネント開発ガイドライン

Agent・Command・Skill・Hook・MCP Serverの配置パス・フロントマター必須フィールド・命名規則（Skillは動名詞+ケバブケース等）・description三部構成・品質チェックリストは `authoring-plugins` スキル（`references/NAMING.md` 等）を一次情報源として参照する。配置先はいずれも `plugins/devkit/` 配下（Agent: `agents/<name>.md`、Command: `commands/<name>.md`、Skill: `skills/<skill-name>/SKILL.md`、Hook: `hooks/<name>.sh`、MCP: `.mcp.json`/`.mcp-codex.json`）。

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

### コミット時のバージョン・タグ徹底（🔴 見落とし防止）

| If X | then Y |
|------|--------|
| コンポーネント（Agent/Skill/Command/Hook/MCP）の追加・変更・削除を含むcommitを行う時 | **変更が及んだ全プラグイン**の `plugin.json` をSemVerに従いbumpする（他プラグインのファイルを1つだけ触った場合もそのプラグインはPATCH対象。「メインで作業したプラグインだけbumpする」は不可） |
| commitを作成した時 | 同一タスク内で必ず `git tag` を作成する（tagなしでcommitのみで終えない）。tag名は `<plugin>-vX.Y.Z`（devkitのみ `vX.Y.Z`）形式で、変更したプラグイン名とバージョンが一目で分かるようにする |
| 1コミットに複数プラグインの変更を含む時 | 変更したプラグインの数だけtagを作成する（例: `lang-v2.4.0` と `cloud-v1.2.1` を同一commitに対して複数付与） |
| commit前の最終確認 | `git show --stat --name-only HEAD` で変更ファイルを俯瞰し、`plugins/<plugin>/` 配下に変更があるプラグインを洗い出して、その全てのversion bumpが済んでいるか照合する（bump漏れ・タグ漏れの実例: 2026-07-31、SQLスキル追加commitでcloud・devkitのbumpを見落とした） |
