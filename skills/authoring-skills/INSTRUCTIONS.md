# Claude Skills Authoring Guide

## Overview

スキルの作成・変換・レビューを統合的にガイドするメタスキル。

3つの柱:
- **Create**: 新規スキルの設計・実装（本ファイル + サブファイル群）
- **Convert**: 既存ソース → スキル変換（[CONVERTING.md](references/CONVERTING.md)）
- **Review**: 利用状況分析・ライフサイクル管理（[USAGE-REVIEW.md](references/USAGE-REVIEW.md)）

> **注意**: `.claude/commands/` と `skills/` は現在統合されており、コマンドもスキルも同じ仕組みで動作する。本ガイドの原則は双方に適用される。

## 🔴 デフォルト動作規則（毎回自動適用）

以下のルールはauthoring-skillsを使用するすべてのタスクで**自動的に適用**される。ユーザーからの個別指示は不要。

### 情報の保存方針

| 条件 | 行動 |
|------|------|
| 既に重複する内容がある場合 | 省略してよい |
| 情報量が多い場合 | **過度に圧縮しない**。適切なサイズで `references/` にファイルを分割して保存する |
| INSTRUCTIONS.md が500行に近づく場合 | Progressive Disclosure に従い references/ へ分離 |

### 並列実行

| 条件 | 行動 |
|------|------|
| 複数ファイルの作成・変更を伴う場合 | `orchestrating-teams` スキルを使って並列実行する |
| 単一ファイルの軽微修正 | 並列実行不要（直接実行） |

### 関連設定の整合性維持

スキルの作成・変更・削除時に、以下の関連ファイルに訂正が必要かを**自動的にチェック**し、必要であれば合わせて修正する:

- `$HOME/.claude` 配下の設定ファイル（`rules/skill-triggers.md` 等）
- `hooks/detect-project-skills.sh`（自動検出対象の場合）
- `README.md`（CLAUDE.mdのREADME自動同期ルールに従う）

### 自己改善の自動実行

authoring-skills 自身に改善すべき点を発見した場合、**タスク完了時に自動的に修正・追記を行う**（ユーザーの個別指示は不要）。詳細は後述の「自己改善プロトコル」セクションを参照。

### 公式ドキュメントとの同期

ユーザーが公式ドキュメントの確認を指示した場合、または新しいClaude Code機能がスキル作成に関連すると判断した場合、Claude Code公式スキルドキュメント（`https://code.claude.com/docs/en/skills`）をWebFetchで取得し、authoring-skillsの記載内容と差分を分析する。未反映の新機能・仕様変更があれば、自己改善プロトコルに従い改善提案を行う。

## When to Use

- **Creating new skills**: Before writing a new SKILL.md
- **Improving existing skills**: When refactoring or enhancing skills
- **Converting source material**: Transforming Markdown, PDF, EPUB, URLs into skills → 詳細は [CONVERTING.md](references/CONVERTING.md) 参照
- **Reviewing skill portfolio**: Analyzing usage patterns and maintaining skill health → 詳細は [USAGE-REVIEW.md](references/USAGE-REVIEW.md) 参照
- **Reviewing skill quality**: For code review of skill files

## Core Principles

### 1. Concise is Key

The context window is a shared resource. Challenge each piece of information:
- "Does Claude really need this explanation?"
- "Can I assume Claude knows this?"
- "Does this paragraph justify its token cost?"

**Default assumption**: Claude is already very smart. Only add context Claude doesn't already have.

> **注意**: スキルのコンテキスト占有量はコンテキストウィンドウの**2%**（フォールバック: 16,000文字）で動的に算出される。環境変数 `SLASH_COMMAND_TOOL_CHAR_BUDGET` で上書き可能。多くのスキルを使用している場合、`/context` コマンドで除外されたスキルの警告を確認できる。

### 2. Two-Stage Loading（二段階ロード） 🔴 必須パターン

**SKILL.md はフロントマター + ポインターのみ。本文は INSTRUCTIONS.md に分離する。**

```
Stage 1: SKILL.md 自動注入（200〜500バイト）
  → フロントマター（description）のみがコンテキストに入る
Stage 2: Claude が必要と判断した時のみ Read ツールで INSTRUCTIONS.md を読む
  → 詳細な手順・ガイドラインがオンデマンドで読み込まれる
```

**効果**: 76スキル全体で **984KB → 51KB（94.8%削減）** のコンテキスト節約を実現。

**SKILL.md テンプレート**:
```yaml
---
name: my-skill
description: >-
  What it does. Use when [trigger]. For X, use Y instead.
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
```

**INSTRUCTIONS.md**: SKILL.md から移動した本文全体（見出し・手順・例・参照リンク等）

### 3. Progressive Disclosure（段階的開示）

INSTRUCTIONS.md が大きくなった場合、さらに references/ へ詳細を分離する:
- INSTRUCTIONS.md body は **500行以下** を目安とする
- 500行に近づいた場合や超える場合、**AskUserQuestionツールでユーザーに対応方針を確認**:
  - **ファイル分割**: references/ へ詳細を分離
  - **内容の圧縮・要約**: 冗長な箇所を削減
  - **500行超を許容**: 内容が不可分で分割すると品質が下がる場合
- Claude loads additional files only when needed

### 4. Appropriate Degrees of Freedom

Match specificity to task fragility:

| Freedom Level | Use When | Example |
|--------------|----------|---------|
| **High** (text instructions) | Multiple approaches valid | Code review guidelines |
| **Medium** (pseudocode) | Preferred pattern exists | Report templates |
| **Low** (specific scripts) | Operations are fragile | Database migrations |

## Quick Reference

### YAML Frontmatter Requirements

```yaml
---
name: skill-name                      # 推奨（省略時はディレクトリ名を使用）
description: >-                        # 🔴 必ず >- を使用（インライン文字列はコロンでYAMLエラー）
  What it does. Use when trigger.
argument-hint: "[issue-number]"        # オートコンプリートで表示
disable-model-invocation: true         # Claudeの自動ロードを禁止
user-invocable: false                  # /メニューから非表示
allowed-tools: Read, Grep, Glob        # 許可ツールの制限
model: sonnet                          # 使用モデル指定
context: fork                          # サブエージェント実行
agent: Explore                         # context: fork時のエージェントタイプ
hooks:                                 # スキルスコープのライフサイクルフック
  PreToolUse:
    - matcher: Write
      hooks:
        - command: "validate.sh"
---
```

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `name` | 推奨 | 表示名。省略時はディレクトリ名を使用。明示的な記載を推奨 |
| `description` | 推奨 | 機能説明+トリガー条件。省略時は本文最初の段落 |
| `argument-hint` | いいえ | オートコンプリートで表示される引数ヒント |
| `disable-model-invocation` | いいえ | `true`でClaude自動ロードを禁止。手動`/name`のみ |
| `user-invocable` | いいえ | `false`で`/`メニューから非表示（バックグラウンド知識用） |
| `allowed-tools` | いいえ | 許可ツールの制限（カンマ区切り） |
| `model` | いいえ | 使用モデル指定（例: `sonnet`, `opus`, `haiku`） |
| `context` | いいえ | `fork`でサブエージェント実行 |
| `agent` | いいえ | `context: fork`時のエージェントタイプ（`Explore`, `Plan`等） |
| `hooks` | いいえ | スキルスコープのライフサイクルフック |

**Naming convention**: Use gerund form (verb + -ing)
- Good: `processing-pdfs`, `analyzing-data`, `testing-code`
- Avoid: `helper`, `utils`, `tools`

**Description rules** (Three-Part Formula):
- Always write in **third person**
- Include what the skill does AND when to use it
- Add differentiation when similar skills exist (e.g., "For X, use Y instead.")
- Be specific and include key terms for discovery
- 🔴 **YAML構文安全**: description は必ず `>-`（folded block scalar）で記述する。インライン文字列（`description: text...`）はコロン（`:`）を含むとYAMLパーサーが「キー: 値」として誤解釈し、`mapping values are not allowed in this context` エラーになる
- 🔴 **Length limit**: description は **1024文字以下**（Claude Codeのフロントマター解析でこの長さを超えると切り捨てられる）
  - **必ず検証**: SKILL.md 作成・編集後に以下のコマンドで文字数を確認すること
    ```bash
    python3 -c "import yaml; d=yaml.safe_load(open('skills/<name>/SKILL.md').read().split('---')[1]); l=len(d.get('description','')); print(f'{l}/1024 chars'); assert l<=1024, f'OVER: {l}'"
    ```
  - **超過時の圧縮テクニック**（優先順）:
    1. 「Comprehensive」「covering」「and more」等の装飾語を削除
    2. 冗長な列挙を代表的なものに絞る（例: 全サービス名 → 主要3-4個 + カテゴリ名）
    3. 括弧内の詳細を削減（例: `(Lambda, API Gateway, DynamoDB, Step Functions)` → `(Lambda, DynamoDB)`）
    4. ルーティングヒントを短縮（例: `For X, use Y instead` → `For X→Y`）
  - **圧縮しても維持すべき要素**:
    - 「Use when / MUST load when」のトリガー条件
    - 「For X→Y」の差別化ルーティング
    - 主要な検出キーワード（ファイル名、パッケージ名）

See [NAMING.md](references/NAMING.md) for detailed naming guidelines.

### 文字列置換

スキル本文で以下の変数が使用可能:

| 変数 | 説明 | 使用例 |
|------|------|--------|
| `$ARGUMENTS` | `/skill-name arg1 arg2` の引数全体 | `Review PR $ARGUMENTS` |
| `$ARGUMENTS[N]` | N番目の引数（0始まり） | `/migrate SearchBar React Vue` → `$ARGUMENTS[0]` = `SearchBar` |
| `$N` | `$ARGUMENTS[N]` の短縮形 | `$0`, `$1`, `$2` |
| `${CLAUDE_SESSION_ID}` | 現在のセッションID | ログファイル名に使用 |
| `${CLAUDE_SKILL_DIR}` | スキルのSKILL.mdが存在するディレクトリパス | `${CLAUDE_SKILL_DIR}/scripts/helper.py` |

> **注意**: `$ARGUMENTS` が本文に含まれない場合、引数は自動的に `ARGUMENTS: <value>` として末尾に追加される。

### 動的コンテキスト注入（`` !`command` ``）

スキル本文で `` !`command` `` 構文を使用すると、シェルコマンドの出力がスキル内容に**前処理**で埋め込まれる。Claudeはコマンドではなく実行結果のみを受け取る。

**使用例（PRサマリースキル）**:

````yaml
---
name: pr-summary
description: PRの変更を要約
context: fork
agent: Explore
---

## PRコンテキスト
- PR差分: !`gh pr diff`
- PRコメント: !`gh pr view --comments`
- 変更ファイル: !`gh pr diff --name-only`

## タスク
このPRを要約してください...
````

**動作フロー**:
1. 各 `` !`command` `` が即座に実行される（Claudeが見る前）
2. コマンド出力がプレースホルダーを置換
3. Claudeは完全にレンダリングされたプロンプトのみ受け取る

詳細なパターンは [PATTERNS.md](references/PATTERNS.md) の「Dynamic Context Injection」を参照。

## スキルコンテンツタイプ

スキルの内容は大きく2種類に分類される:

### Reference Content（参照型）
- **特徴**: スキル発動時にシステムプロンプトに注入される知識・ガイドライン
- **用途**: コーディング規約、API仕様、ベストプラクティス集
- **設定**: `user-invocable: false`（バックグラウンド知識として自動ロード）
- **例**: `writing-clean-code`, `enforcing-type-safety`

### Task Content（タスク型）
- **特徴**: `/skill-name` で呼び出し、特定のアクションを実行する
- **用途**: コード生成、レビュー、変換ワークフロー
- **設定**: `disable-model-invocation: true` + `context: fork`（サブエージェント実行）
- **例**: スプリント計画スキル、レポート生成スキル

## 呼び出し制御

`disable-model-invocation` と `user-invocable` の組み合わせでスキルの呼び出し方法を制御する:

| パターン | `disable-model-invocation` | `user-invocable` | ユーザー呼出し | Claude呼出し | コンテキストローディング |
|---------|--------------------------|------------------|-------------|------------|---------------------|
| **自動+手動** | `false`（デフォルト） | `true`（デフォルト） | ✅ | ✅ | descriptionは常にコンテキスト内。フル内容は呼出し時にロード |
| **手動のみ** | `true` | `true` | ✅ | ❌ | descriptionはコンテキスト**外**。フル内容はユーザー呼出し時にロード |
| **バックグラウンド** | `false` | `false` | ❌ | ✅ | descriptionは常にコンテキスト内。フル内容は呼出し時にロード |

> **🔴 重要**: `disable-model-invocation: true` を設定すると、descriptionがコンテキストから**完全に除外**される。Claudeはそのスキルの存在すら認識しなくなるため、ユーザーが明示的に `/name` で呼び出した時のみ動作する。

## スキルのPermission制御

`/permissions` でClaudeのスキルアクセスを制御できる:

| 操作 | 設定 |
|------|------|
| 全スキル無効化 | deny rule に `Skill` を追加 |
| 特定スキルのみ許可 | `Skill(commit)` （完全一致）/ `Skill(review-pr *)` （前方一致） |
| 特定スキル拒否 | deny rule に `Skill(deploy *)` を追加 |

> **注意**: `user-invocable: false` はメニュー表示のみを制御し、Skillツールアクセスは制御しない。プログラム的な呼び出しをブロックするには `disable-model-invocation: true` を使用。

## スキルトリガー機構

スキルは以下の3つの方法でトリガーされる:

### 1. REQUIRED/MUST パターン（強制ロード）
descriptionに「REQUIRED」「MUST」を含むスキルは、該当タスク実行前に必ずロードされる。

例: `researching-libraries` → "Required before writing any new functionality"

### 2. SessionStart Hook（自動検出）
`hooks/detect-project-skills.sh` がプロジェクトのファイル構成を解析し、関連スキルを自動推奨する。

#### 検出グループ

detect-project-skills.sh は以下のスキルグループで構成される:

| グループ | 検出条件 | 含まれるスキル |
|---------|---------|--------------|
| ALWAYS_SKILLS | 常時 | writing-clean-code, enforcing-type-safety, testing-code, securing-code, writing-effective-prose |
| COMMON_DEV_SKILLS | 言語プロジェクト検出時 | researching-libraries, architecting-microservices, modernizing-architecture |
| 個別検出 | ファイル・依存関係 | developing-nextjs, developing-go 等（ファイルベースで1対1検出） |
| WRITING_SKILLS | .tex 検出時 | writing-latex, writing-effective-prose, searching-web |
| DESIGN_SKILLS | components.json/.stories.*/tailwind.config.* 検出時 | applying-design-guidelines, applying-behavior-design, implementing-design |
| DATABASE_SKILLS | schema.prisma/.sql/DB関連パッケージ検出時 | avoiding-sql-antipatterns, understanding-database-internals |
| OBSERVABILITY_SKILLS | @opentelemetry/*/prometheus.yml 検出時 | designing-monitoring |
| MCP_DEV_SKILLS | @modelcontextprotocol/sdk/fastmcp 検出時 | developing-mcp |

#### detect-project-skills.sh 更新の判断基準

新スキル作成時、以下の判断基準に基づいて detect-project-skills.sh を更新する:

| 条件 | アクション | 例 |
|------|----------|-----|
| **特定ファイル/依存関係で確実にトリガーすべき** | 個別検出関数を追加 | .cedar → implementing-dynamic-authorization |
| **既存のスキルグループに属する** | 該当グループの配列にスキルを追加 | DB関連スキル → DATABASE_SKILLS に追加 |
| **新しいスキルグループが必要** | グループ変数・フラグ・検出関数・出力セクションを追加 | 新ドメインのスキル群 |
| **ユーザー要求でのみ使用** | detect-project-skills.sh は変更不要 | crafting-ai-copywriting |
| **内部Agent用** | detect-project-skills.sh は変更不要 | implementing-as-tachikoma |

#### 更新時の必須手順（チェックリスト）

新スキルを detect-project-skills.sh に追加する場合:
- [ ] スキルグループの選定（既存 or 新規）
- [ ] 検出条件の定義（ファイル名、依存関係名）
- [ ] get_skill_description() にスキル説明を追加
- [ ] 個別検出の場合: 検出関数にPROJECT_SKILLS追加コードを記述
- [ ] グループ検出の場合: グループ配列にスキルを追加
- [ ] `bash -n hooks/detect-project-skills.sh` で構文チェック
- [ ] `$HOME/dotfiles/claude-code/rules/skill-triggers.md` の 🟡 自動検出セクションを同期更新

### 3. Use when パターン（条件トリガー）
descriptionの「Use when ...」条件に該当する場合に明示的にロードされる。

例: `securing-code` → "Use after all code implementations to verify security"

## File Structure

```
my-skill/
├── SKILL.md              # フロントマター + ポインターのみ（自動注入、200〜500B）
├── INSTRUCTIONS.md       # 本文全体（オンデマンド読み込み）
├── references/           # 詳細ドキュメント（必要時にのみ読み込み）
│   ├── REFERENCE.md      # API reference
│   └── EXAMPLES.md       # Usage examples
└── scripts/
    └── utility.py        # 実行用スクリプト（コンテキストには入れない）
```

**ロード順序**: SKILL.md（自動）→ INSTRUCTIONS.md（必要時）→ references/*（詳細が必要な時）

### ネストされたディレクトリの自動検出

モノレポ内のサブパッケージからもスキルは自動発見される:

```
monorepo/
├── packages/
│   └── frontend/
│       └── .claude/
│           └── skills/
│               └── my-skill/
│                   └── SKILL.md
└── .claude/
    └── skills/
        └── shared-skill/
            └── SKILL.md
```

各パッケージの `.claude/skills/` ディレクトリが自動的にスキャンされる。

### --add-dir からのスキル読み込み

`--add-dir` で追加されたディレクトリ内の `.claude/skills/` もスキルとして自動ロードされ、**ライブ変更検出**に対応する（セッション中の編集が再起動なしで反映）。

```bash
# プロジェクトスコープ外のスキルを追加する例
claude --add-dir /path/to/shared-skills
```

See [STRUCTURE.md](references/STRUCTURE.md) for progressive disclosure patterns.

## Skill Creation Workflow

### Use Case Categories

スキルは大きく3つのカテゴリに分類される:

| カテゴリ | 用途 | キーテクニック |
|---------|------|--------------|
| **Document & Asset Creation** | 一貫した高品質の出力物を生成（文書、プレゼン、アプリ、デザイン、コード等） | スタイルガイド埋め込み、テンプレート、品質チェック |
| **Workflow Automation** | 一貫した方法論でマルチステッププロセスを自動化（複数MCPサーバー連携含む） | ステップバイステップワークフロー、バリデーションゲート |
| **MCP Enhancement** | MCPサーバーのツールアクセスにワークフロー知識を付加 | ドメイン専門知識、エラーハンドリング、コンテキスト補完 |

詳細は [TESTING.md](references/TESTING.md) を参照。

### Step 1: Identify the Gap

Before writing documentation, identify what Claude struggles with:
1. Run Claude on representative tasks without a skill
2. Document specific failures or missing context
3. Create 3+ evaluation scenarios

### Step 2: Check for Similar Skills

Before writing, scan existing skills for overlap:

1. List all skills in `skills/` directory
2. Compare your skill's intended scope with existing descriptions
3. Determine relationship:
   | Overlap | Action |
   |---------|--------|
   | Full overlap | Extend existing skill instead |
   | Partial overlap | Create new skill with mutual differentiation |
   | No overlap | Create new skill |
4. If creating new: plan description updates for **both** new and existing similar skills (see [NAMING.md](references/NAMING.md) Mutual Update Requirement)

### Step 3: Write SKILL.md + INSTRUCTIONS.md

**SKILL.md**（フロントマター + ポインターのみ）:
```yaml
---
name: my-skill
description: >-
  [What it does]. Use when [trigger conditions].
  For [related task], use [other-skill] instead.
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
```

**INSTRUCTIONS.md**（本文全体）:
```markdown
# [Skill Title]

## Quick Start
[Minimal working example]

## Core Guidelines
[Essential rules and patterns]

## Advanced Features
See [REFERENCE.md](references/REFERENCE.md) for details.
```

### Step 4: Validate Description Length（🔴 必須）

SKILL.md 作成・編集直後に description が1024文字以下であることを確認する:

```bash
python3 -c "import yaml; d=yaml.safe_load(open('skills/<name>/SKILL.md').read().split('---')[1]); l=len(d.get('description','')); print(f'{l}/1024 chars'); assert l<=1024, f'OVER: {l}'"
```

超過した場合は Description rules の圧縮テクニック（優先順）を適用して1024文字以内に収める。

### Step 5: Test and Iterate

1. Test with real usage scenarios
2. Observe Claude's navigation patterns
3. Refine based on failures

See [WORKFLOWS.md](references/WORKFLOWS.md) for detailed development workflow.

## Source Conversion Workflow

既存のMarkdown、PDF、EPUB、URL、複数ファイル、またはフォルダからスキルを作成する場合:

1. **Phase 0: 入力判定**（Claude Code本体）- 入力ファイル・URL特定、作業ディレクトリ作成、TeamCreate
2. **Phase A: 計画策定**（Planner タチコマ・Opus）- ファイル変換（PDF/EPUB/URL → Markdown）〜 内容分析 〜 構造設計を一括委譲。全結果を `docs/conversion-{skill-name}/` に永続化
3. **Phase B: ユーザー確認**（Claude Code本体）- docs/ 読み込み → AskUserQuestion → 決定を `06-user-decisions.md` に保存
4. **Phase C: 実装**（Implementer タチコマ × N・Sonnet）- docs/ の計画・ユーザー決定を読み込みスキルファイルを並列生成
5. **Phase D: 品質チェック**（Claude Code本体）- 最終検証 → TeamDelete → リリース

**Compaction耐性**: 全中間結果を `docs/conversion-{skill-name}/` に保存。各ステップ完了ごとにファイル書き込み。compaction後は `99-progress.md` から状態を復元して再開可能。

詳細は [CONVERTING.md](references/CONVERTING.md) を参照。

命名戦略の自動推定については [NAMING-STRATEGY.md](references/NAMING-STRATEGY.md) を参照。
テンプレート集については [TEMPLATES.md](references/TEMPLATES.md) を参照。

## Skill Usage Review

スキルポートフォリオの健全性を維持するため、定期的なレビューを実施:

1. `scripts/analyze-skill-usage.sh` でログ分析
2. 判断基準テーブルに基づき棚卸し
3. 維持 / description改善 / 統合 / 廃止 を決定

詳細は [USAGE-REVIEW.md](references/USAGE-REVIEW.md) を参照。

---

## 自己改善プロトコル（🔴 タスク完了後必須）

スキル作成・変更タスクの完了後、このスキル自身（authoring-skills）を改善する機会を逃さない。**これはデフォルト動作規則であり、ユーザーからの個別指示がなくても毎回自動的に実行する。**

### トリガー

authoring-skills を使用してスキルの作成・変換・変更を完了した直後。

### 分析の6観点

| # | 観点 | 探すもの |
|---|------|---------|
| 1 | **ユーザーの指示・補足** | タスク中にユーザーから与えられた指示で、INSTRUCTIONS.md にまだ記載されていないもの |
| 2 | **ユーザーの訂正** | Claudeの提案をユーザーが修正した箇所（暗黙の品質基準） |
| 3 | **繰り返しパターン** | 複数のスキル作成で共通して発生した判断・構造パターン |
| 4 | **エッジケース** | 既存ガイドラインでカバーされていなかった状況・判断 |
| 5 | **アンチパターン** | 実行中に発見した「やってはいけないこと」 |
| 6 | **公式ドキュメントの変更追従** | Claude Code公式ドキュメント（https://code.claude.com/docs/en/skills）に記載されているが、authoring-skills にまだ反映されていない新機能・仕様変更・ベストプラクティス |

### 実行手順

1. タスク完了報告の後、会話中のユーザー指示・フィードバックを振り返る
2. 上記6観点で改善候補を抽出
3. **観点6（公式ドキュメント追従）については**: ユーザーから公式ドキュメントの確認指示があった場合、または新機能が話題に上った場合に、WebFetch で公式ドキュメント（https://code.claude.com/docs/en/skills）を取得し、authoring-skills の記載内容と差分を分析する
4. 既存の INSTRUCTIONS.md / references/* と照合し、**未記載のもののみ**リスト化
5. AskUserQuestion で改善提案を提示し承認を得る
6. 承認された項目を INSTRUCTIONS.md または適切な reference ファイルに追記

### 追記ルール

- **If X then Y 形式推奨**: 条件→行動の形式で記述（検索・参照しやすい）
- **適切なセクションに配置**: 既存の構造に自然に馴染む位置に追加
- **重複回避**: 既に記載されている内容の言い換えは追加しない
- **一般化**: 再利用可能な知見のみ（セッション固有の事情は CLAUDE.md に追記すべき）
- **Anti-Patterns テーブルへの追加**: アンチパターンを発見した場合は既存の Anti-Patterns テーブルに行を追加

### 追記しないもの

- 1回限りの特殊な指示（一般化できないもの）
- 既にカバーされている内容
- プロジェクト固有の事情（CLAUDE.md や auto-memory に記録すべきもの）

---

## Release Workflow（🔴 タスク完了後必須）

スキルの作成・変更・削除がすべて完了した後、以下の4ステップを**必ず全て実行**する。途中で止めないこと。

### Quick Reference

```bash
# 1. バージョン更新（Edit ツールで .claude-plugin/plugin.json を編集）
# 2. ステージング・コミット
git add -A
git commit -m "feat(skills): ..."
# 3. タグ作成
git tag <version>
# 4. プッシュ（main とタグの両方）
git push origin main
git push origin <version>
```

### 1. バージョン更新

`.claude-plugin/plugin.json` の `version` フィールドを **Edit ツール**で更新する:

| 変更内容 | バージョン | 例 |
|---------|-----------|-----|
| 新スキル・コマンド・Agent追加 | **MINOR** | `4.6.0` → `4.7.0` |
| 既存スキルの修正・改善 | **PATCH** | `4.6.0` → `4.6.1` |
| 破壊的変更（スキル統合・大幅構成変更） | **MAJOR** | `4.6.0` → `5.0.0` |

### 2. コミット

`writing-conventional-commits` スキルに従い、Conventional Commits形式でコミットメッセージを作成する。`git diff --stat` と変更内容からメッセージを判断し、`git commit -m` で直接コミットする:

```bash
# メッセージ例
git add -A
git commit -m "feat(skills): <スキル名>新設"           # 新スキル追加
git commit -m "docs(skills): <変更内容>"               # 既存スキル改善
git commit -m "feat(skills): <スキルA>新設、<スキルB>改善"  # 複数変更
```

> **⚠️ `gcauto -y` は使用禁止。** Claude Codeを内部起動するため、Claude Codeセッション内では必ずネストセッションエラーになる。本スキルは常にClaude Code内で実行されるため、`git commit -m "..."` を直接使用すること。

### 3. タグ作成（🔴 必須）

コミット後、バージョンタグを作成する:

```bash
git tag <version>
```

> **タグ命名規則**: `v` プレフィックスなし（例: `6.1.1`）。既存タグ履歴に合わせること。

### 4. プッシュ

mainとタグの**両方**をリモートにプッシュする:

```bash
git push origin main
git push origin <version>
```

> **⚠️ 罠: `git push origin main` だけではタグはプッシュされない。タグ用に別途 `git push origin <version>` が必要。**

### リリースチェックリスト

- [ ] `.claude-plugin/plugin.json` のバージョン更新済み
- [ ] コミットメッセージがConventional Commits形式
- [ ] `git tag <version>` 実行済み
- [ ] `git push origin main` 実行済み
- [ ] `git push origin <version>` 実行済み

---

## Common Patterns

### Template Pattern

Provide output format templates:

````markdown
## Report Structure

Use this template:

```markdown
# [Title]

## Summary
[One-paragraph overview]

## Key Findings
- Finding 1
- Finding 2
```
````

### Examples Pattern

Show input/output pairs:

````markdown
## Commit Message Format

**Input**: Added user authentication
**Output**:
```
feat(auth): implement authentication

Add login endpoint and token validation
```
````

### Conditional Workflow Pattern

Guide through decision points:

```markdown
## Workflow

1. Determine task type:
   - **Creating new?** → See "Creation workflow"
   - **Editing existing?** → See "Editing workflow"
```

### AskUserQuestion Pattern

Guide users through decision points with structured choices:

````markdown
### ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

- **確認すべき場面**:
  - [このスキル固有の判断分岐を列挙]
- **確認不要な場面**:
  - [ベストプラクティスが明確な場合]
  - [スキル内で明確に推奨している場合]

**AskUserQuestion使用例:**

```python
AskUserQuestion(
    questions=[{
        "question": "[判断が必要な質問]",
        "header": "[短いラベル]",
        "options": [
            {"label": "[選択肢1]", "description": "[説明]"},
            {"label": "[選択肢2]", "description": "[説明]"}
        ],
        "multiSelect": False
    }]
)
```
````

**When to include**: If your skill has sections where multiple valid approaches exist (architecture choices, library selection, deployment strategies), add an AskUserQuestion section guiding users to confirm before proceeding.

### Extended Thinking Pattern

スキル本文に `ultrathink` を含めると、**拡張思考モード**が有効化される。複雑なアーキテクチャ分析・多ファイル横断リファクタリング・セキュリティ監査等、深い推論が必要なスキルにのみ使用する。

詳細なパターンは [PATTERNS.md](references/PATTERNS.md) の「Extended Thinking」を参照。

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Too verbose | Wastes context tokens | Assume Claude's intelligence |
| Time-sensitive info | Becomes outdated | Use "old patterns" section |
| Inconsistent terms | Confuses Claude | Pick one term, use consistently |
| Too many options | Decision paralysis | Provide default with escape hatch |
| Deep nesting | Partial file reads | Keep references one level deep |
| Windows paths | Cross-platform errors | Use forward slashes only |
| Description over 1024 chars | Truncated by Claude Code parser | Compress: reduce enumerations, drop filler words |
| Inline description with colons | YAML parse error (`mapping values are not allowed`) | Always use `>-` block scalar instead of inline string |
| Missing name field | Inconsistent skill identification | Always include name matching directory name |
| Sub-feature naming | Scope expansion requires rename (e.g., `-make` → tool name) | Name after the tool itself (e.g., `implementing-figma`), manage sub-features via sections/references |
| Task content without `context: fork` | Guidelines run inline with no actionable task, wasting context | Add `context: fork` for task-type skills with explicit instructions |
| `context: fork` with reference content | Subagent receives guidelines but no task, returns without output | Use inline (no `context: fork`) for reference/convention skills |

## Detailed Documentation

### スキル作成
- **[NAMING.md](references/NAMING.md)**: 命名規則、description三部構成、統一ネーミングルール
- **[STRUCTURE.md](references/STRUCTURE.md)**: ファイル構造と Progressive Disclosure
- **[WORKFLOWS.md](references/WORKFLOWS.md)**: 開発ワークフローとイテレーション
- **[CHECKLIST.md](references/CHECKLIST.md)**: 品質チェックリスト
- **[PATTERNS.md](references/PATTERNS.md)**: ワークフローパターン集
- **[TESTING.md](references/TESTING.md)**: テスト・評価フレームワーク
- **[TROUBLESHOOTING.md](references/TROUBLESHOOTING.md)**: トラブルシューティング

### ソース変換
- **[CONVERTING.md](references/CONVERTING.md)**: ソース → スキル変換ワークフロー（5フェーズ: Phase 0→A→B→C→D）
- **[NAMING-STRATEGY.md](references/NAMING-STRATEGY.md)**: 命名自動推定ロジック
- **[TEMPLATES.md](references/TEMPLATES.md)**: テンプレート集

### 利用状況レビュー
- **[USAGE-REVIEW.md](references/USAGE-REVIEW.md)**: スキル利用状況レビュー・棚卸しガイド

## オープンスタンダード

スキルのフォーマットは [Agent Skills](https://agentskills.io) オープンスタンダードに準拠しており、Claude Code以外のツールからも利用可能な互換性を持つ。

## Related Skills

- **writing-effective-prose**: 一般的なドキュメント原則（技術文書・学術文書を統合）
- **writing-clean-code**: ユーティリティスクリプトのコード品質
