---
name: authoring-skills
description: >-
  Creates effective Claude Code Skills with proper structure, naming, and evaluation.
  Use when creating new skills, converting source material (Markdown/PDF/EPUB/URL) into skills,
  or reviewing skill usage analytics.
  Covers naming conventions, progressive disclosure, source conversion, and lifecycle management.
---

# Claude Skills Authoring Guide

## Overview

スキルの作成・変換・レビューを統合的にガイドするメタスキル。

3つの柱:
- **Create**: 新規スキルの設計・実装（本ファイル + サブファイル群）
- **Convert**: 既存ソース → スキル変換（[CONVERTING.md](references/CONVERTING.md)）
- **Review**: 利用状況分析・ライフサイクル管理（[USAGE-REVIEW.md](references/USAGE-REVIEW.md)）

> **注意**: `.claude/commands/` と `skills/` は現在統合されており、コマンドもスキルも同じ仕組みで動作する。本ガイドの原則は双方に適用される。

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

> **注意**: スキルのコンテキスト占有量は環境変数 `SLASH_COMMAND_TOOL_CHAR_BUDGET`（デフォルト15,000文字）で制御される。多数のスキルを使用する場合、この上限を意識してスキルを簡潔に保つ。

### 2. Progressive Disclosure

SKILL.md serves as an overview that points to detailed materials as needed:
- Keep SKILL.md body under **500 lines**
- Split content into separate files when approaching this limit
- Claude loads additional files only when needed

### 3. Appropriate Degrees of Freedom

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
name: skill-name                      # 省略可（ディレクトリ名を使用）
description: >-                        # 推奨（省略時は本文最初の段落）
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
| `name` | いいえ | 表示名。省略時はディレクトリ名を使用 |
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

See [NAMING.md](references/NAMING.md) for detailed naming guidelines.

### 文字列置換

スキル本文で以下の変数が使用可能:

| 変数 | 説明 | 使用例 |
|------|------|--------|
| `$ARGUMENTS` | `/skill-name arg1 arg2` の引数部分 | `Review PR $ARGUMENTS` |
| `${CLAUDE_SESSION_ID}` | 現在のセッションID | ログファイル名に使用 |

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

| パターン | `disable-model-invocation` | `user-invocable` | 挙動 |
|---------|--------------------------|------------------|------|
| **自動+手動** | `false`（デフォルト） | `true`（デフォルト） | Claudeが自動ロード + `/name`で手動呼出し可能 |
| **手動のみ** | `true` | `true` | `/name`でのみ呼出し可能。自動ロード禁止 |
| **バックグラウンド** | `false` | `false` | Claudeが必要時に自動ロード。`/`メニュー非表示 |

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
| ALWAYS_SKILLS | 常時 | writing-clean-code, enforcing-type-safety, testing-code, securing-code, removing-ai-smell |
| COMMON_DEV_SKILLS | 言語プロジェクト検出時 | researching-libraries, architecting-microservices, modernizing-architecture |
| 個別検出 | ファイル・依存関係 | developing-nextjs, developing-go 等（ファイルベースで1対1検出） |
| WRITING_SKILLS | .tex 検出時 | writing-latex, writing-technical-docs, writing-academic-papers, searching-web |
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
├── SKILL.md              # Main instructions (loaded when triggered)
├── references/           # Detailed docs (loaded as needed)
│   ├── REFERENCE.md      # API reference
│   └── EXAMPLES.md       # Usage examples
└── scripts/
    └── utility.py        # Executed, not loaded into context
```

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

### Step 3: Write Minimal Instructions

Create just enough content to address the gaps:
```markdown
---
name: my-skill
description: [What it does]. Use when [trigger conditions].
---

# [Skill Title]

## Quick Start
[Minimal working example]

## Advanced Features
See [REFERENCE.md](references/REFERENCE.md) for details.
```

### Step 4: Test and Iterate

1. Test with real usage scenarios
2. Observe Claude's navigation patterns
3. Refine based on failures

See [WORKFLOWS.md](references/WORKFLOWS.md) for detailed development workflow.

## Source Conversion Workflow

既存のMarkdown、PDF、EPUB、URLからスキルを作成する場合:

1. ソース形式を特定（MD/PDF/EPUB/URL/フォルダ）
2. 必要に応じてスクリプトでMarkdown変換（`scripts/`配下）
3. 6フェーズの変換ワークフローを実行

詳細は [CONVERTING.md](references/CONVERTING.md) を参照。

命名戦略の自動推定については [NAMING-STRATEGY.md](references/NAMING-STRATEGY.md) を参照。
テンプレート集については [TEMPLATES.md](references/TEMPLATES.md) を参照。

## Skill Usage Review

スキルポートフォリオの健全性を維持するため、定期的なレビューを実施:

1. `scripts/analyze-skill-usage.sh` でログ分析
2. 判断基準テーブルに基づき棚卸し
3. 維持 / description改善 / 統合 / 廃止 を決定

詳細は [USAGE-REVIEW.md](references/USAGE-REVIEW.md) を参照。

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

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Too verbose | Wastes context tokens | Assume Claude's intelligence |
| Time-sensitive info | Becomes outdated | Use "old patterns" section |
| Inconsistent terms | Confuses Claude | Pick one term, use consistently |
| Too many options | Decision paralysis | Provide default with escape hatch |
| Deep nesting | Partial file reads | Keep references one level deep |
| Windows paths | Cross-platform errors | Use forward slashes only |

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
- **[CONVERTING.md](references/CONVERTING.md)**: ソース → スキル変換ワークフロー（6フェーズ）
- **[NAMING-STRATEGY.md](references/NAMING-STRATEGY.md)**: 命名自動推定ロジック
- **[TEMPLATES.md](references/TEMPLATES.md)**: テンプレート集

### 利用状況レビュー
- **[USAGE-REVIEW.md](references/USAGE-REVIEW.md)**: スキル利用状況レビュー・棚卸しガイド

## オープンスタンダード

スキルのフォーマットは [Agent Skills](https://agentskills.io) オープンスタンダードに準拠しており、Claude Code以外のツールからも利用可能な互換性を持つ。

## Related Skills

- **writing-technical-docs**: 一般的なドキュメント原則
- **writing-clean-code**: ユーティリティスクリプトのコード品質
