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
- **Convert**: 既存ソース → スキル変換（[CONVERTING.md](CONVERTING.md)）
- **Review**: 利用状況分析・ライフサイクル管理（[USAGE-REVIEW.md](USAGE-REVIEW.md)）

## When to Use

- **Creating new skills**: Before writing a new SKILL.md
- **Improving existing skills**: When refactoring or enhancing skills
- **Converting source material**: Transforming Markdown, PDF, EPUB, URLs into skills → 詳細は [CONVERTING.md](CONVERTING.md) 参照
- **Reviewing skill portfolio**: Analyzing usage patterns and maintaining skill health → 詳細は [USAGE-REVIEW.md](USAGE-REVIEW.md) 参照
- **Reviewing skill quality**: For code review of skill files

## Core Principles

### 1. Concise is Key

The context window is a shared resource. Challenge each piece of information:
- "Does Claude really need this explanation?"
- "Can I assume Claude knows this?"
- "Does this paragraph justify its token cost?"

**Default assumption**: Claude is already very smart. Only add context Claude doesn't already have.

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
name: skill-name        # lowercase, hyphens, max 64 chars
description: Describes what it does and when to use it.  # max 1024 chars
---
```

**Naming convention**: Use gerund form (verb + -ing)
- Good: `processing-pdfs`, `analyzing-data`, `testing-code`
- Avoid: `helper`, `utils`, `tools`

**Description rules** (Three-Part Formula):
- Always write in **third person**
- Include what the skill does AND when to use it
- Add differentiation when similar skills exist (e.g., "For X, use Y instead.")
- Be specific and include key terms for discovery

See [NAMING.md](NAMING.md) for detailed naming guidelines.

## スキルトリガー機構

スキルは以下の3つの方法でトリガーされる:

### 1. REQUIRED/MUST パターン（強制ロード）
descriptionに「REQUIRED」「MUST」を含むスキルは、該当タスク実行前に必ずロードされる。

例: `researching-libraries` → "Required before writing any new functionality"

### 2. SessionStart Hook（自動検出）
`hooks/detect-project-skills.sh` がプロジェクトのファイル構成を解析し、関連スキルを自動推奨する。

検出条件例:
- `package.json` に `next` → `developing-nextjs` を推奨
- `go.mod` 存在 → `developing-go` を推奨
- `tsconfig.json` 存在 → `mastering-typescript` を推奨

**新スキル追加時、自動検出対象にすべきか検討し、必要なら `detect-project-skills.sh` にも追加する。**

### 3. Use when パターン（条件トリガー）
descriptionの「Use when ...」条件に該当する場合に明示的にロードされる。

例: `securing-code` → "Use after all code implementations to verify security"

## File Structure

```
my-skill/
├── SKILL.md              # Main instructions (loaded when triggered)
├── REFERENCE.md          # API reference (loaded as needed)
├── EXAMPLES.md           # Usage examples (loaded as needed)
└── scripts/
    └── utility.py        # Executed, not loaded into context
```

See [STRUCTURE.md](STRUCTURE.md) for progressive disclosure patterns.

## Skill Creation Workflow

### Use Case Categories

スキルは大きく3つのカテゴリに分類される:

| カテゴリ | 用途 | キーテクニック |
|---------|------|--------------|
| **Document & Asset Creation** | 一貫した高品質の出力物を生成（文書、プレゼン、アプリ、デザイン、コード等） | スタイルガイド埋め込み、テンプレート、品質チェック |
| **Workflow Automation** | 一貫した方法論でマルチステッププロセスを自動化（複数MCPサーバー連携含む） | ステップバイステップワークフロー、バリデーションゲート |
| **MCP Enhancement** | MCPサーバーのツールアクセスにワークフロー知識を付加 | ドメイン専門知識、エラーハンドリング、コンテキスト補完 |

詳細は [TESTING.md](TESTING.md) を参照。

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
4. If creating new: plan description updates for **both** new and existing similar skills (see [NAMING.md](NAMING.md) Mutual Update Requirement)

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
See [REFERENCE.md](REFERENCE.md) for details.
```

### Step 4: Test and Iterate

1. Test with real usage scenarios
2. Observe Claude's navigation patterns
3. Refine based on failures

See [WORKFLOWS.md](WORKFLOWS.md) for detailed development workflow.

## Source Conversion Workflow

既存のMarkdown、PDF、EPUB、URLからスキルを作成する場合:

1. ソース形式を特定（MD/PDF/EPUB/URL/フォルダ）
2. 必要に応じてスクリプトでMarkdown変換（`scripts/`配下）
3. 6フェーズの変換ワークフローを実行

詳細は [CONVERTING.md](CONVERTING.md) を参照。

命名戦略の自動推定については [NAMING-STRATEGY.md](NAMING-STRATEGY.md) を参照。
テンプレート集については [TEMPLATES.md](TEMPLATES.md) を参照。

## Skill Usage Review

スキルポートフォリオの健全性を維持するため、定期的なレビューを実施:

1. `scripts/analyze-skill-usage.sh` でログ分析
2. 判断基準テーブルに基づき棚卸し
3. 維持 / description改善 / 統合 / 廃止 を決定

詳細は [USAGE-REVIEW.md](USAGE-REVIEW.md) を参照。

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
- **[NAMING.md](NAMING.md)**: 命名規則、description三部構成、統一ネーミングルール
- **[STRUCTURE.md](STRUCTURE.md)**: ファイル構造と Progressive Disclosure
- **[WORKFLOWS.md](WORKFLOWS.md)**: 開発ワークフローとイテレーション
- **[CHECKLIST.md](CHECKLIST.md)**: 品質チェックリスト
- **[PATTERNS.md](PATTERNS.md)**: ワークフローパターン集
- **[TESTING.md](TESTING.md)**: テスト・評価フレームワーク
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)**: トラブルシューティング

### ソース変換
- **[CONVERTING.md](CONVERTING.md)**: ソース → スキル変換ワークフロー（6フェーズ）
- **[NAMING-STRATEGY.md](NAMING-STRATEGY.md)**: 命名自動推定ロジック
- **[TEMPLATES.md](TEMPLATES.md)**: テンプレート集

### 利用状況レビュー
- **[USAGE-REVIEW.md](USAGE-REVIEW.md)**: スキル利用状況レビュー・棚卸しガイド

## Related Skills

- **writing-technical-docs**: 一般的なドキュメント原則
- **writing-clean-code**: ユーティリティスクリプトのコード品質
