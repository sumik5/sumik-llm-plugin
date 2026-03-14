# File Structure and Progressive Disclosure

## スキルの本質

スキルを設計する前に、スキルというものの本質的な特性を理解しておくことが重要。

### Composability（組み合わせ可能性）

Claudeは複数のスキルを同時にロードできる。スキルは他のスキルと共存することを前提に設計し、唯一の機能として振る舞わないこと。

**設計の含意:**
- 他のスキルが同時にロードされていることを前提にした指示を書く
- 「私だけが唯一の正解」という書き方を避ける
- スコープを明確にし、他のスキルの領域に踏み込まない

### Portability（移植性）

スキルはClaude.ai、Claude Code、APIで同一に動作する。環境依存のない限り、一度作成すれば全サーフェスで修正なしで動作する。

**設計の含意:**
- 特定UIへの依存（「左上のボタンをクリック」など）を避ける
- 環境固有の前提条件は `compatibility` フィールドで明記する
- CLI/GUI両方で意味をなす指示を書く

### MCP + Skills の関係（Kitchen Analogy）

| 概念 | 役割 | 例 |
|------|------|-----|
| **MCP** (Connectivity) | プロフェッショナルキッチン — ツール・食材・機器へのアクセスを提供 | Notion, Linear, Figma等のサービス接続 |
| **Skills** (Knowledge) | レシピ — ツールを使って価値ある成果を生み出す手順 | プロジェクト計画ワークフロー、デザインハンドオフ手順 |

- **MCPなしのスキル**: ユーザーは接続したが何をすべきか分からない
- **スキルなしのMCP**: 毎回ユーザーが手順を説明し直す必要がある
- **両者を組み合わせることで**: 複雑なタスクをユーザーが各ステップを理解せずとも完了できる

---

## How Skills are Loaded

Understanding the loading mechanism helps you structure skills efficiently:

1. **At startup**: Only `name` and `description` from all skills are pre-loaded
2. **When triggered**: Claude reads SKILL.md
3. **As needed**: Claude reads additional referenced files
4. **Script execution**: Scripts are executed, not loaded into context

This means large reference files have **zero context cost** until actually read.

## Recommended Directory Structure

### Simple Skill (Single File)

For straightforward skills under 200 lines:

```
my-skill/
└── SKILL.md
```

### Standard Skill (Multiple Files)

For skills with detailed documentation:

```
my-skill/
├── SKILL.md              # Overview and quick start (~100-300 lines)
└── references/           # Detailed documentation
    ├── REFERENCE.md      # API reference / detailed docs
    ├── EXAMPLES.md       # Usage examples
    └── ANTI-PATTERNS.md  # Common mistakes to avoid
```

### Complex Skill (Domain-Organized)

For skills covering multiple domains:

```
bigquery-skill/
├── SKILL.md              # Overview with navigation
└── references/
    ├── finance.md        # Revenue, billing metrics
    ├── sales.md          # Pipeline, opportunities
    ├── product.md        # API usage, features
    └── marketing.md      # Campaigns, attribution
```

### Nested Directory Auto-Discovery（ネスト自動検出）

モノレポやサブパッケージ構成のプロジェクトでは、各パッケージ内の `.claude/skills/` ディレクトリからスキルが自動発見される:

```
monorepo/
├── packages/
│   ├── frontend/
│   │   └── .claude/
│   │       └── skills/
│   │           └── frontend-patterns/
│   │               └── SKILL.md     # 自動検出される
│   └── backend/
│       └── .claude/
│           └── skills/
│               └── api-guidelines/
│                   └── SKILL.md     # 自動検出される
└── .claude/
    └── skills/
        └── shared-conventions/
            └── SKILL.md             # ルートレベルも検出
```

**ポイント:**
- 各 `.claude/skills/` ディレクトリが独立してスキャンされる
- パッケージ固有のスキルとプロジェクト共通スキルを分離可能
- スキルの発見順序: ルート → サブパッケージ（深さ優先）

### Subagent Skill（サブエージェント実行型）

`context: fork` を使用してサブエージェントとして実行されるスキル:

```
investigating-codebase/
├── SKILL.md              # context: fork + agent: Explore
└── TEMPLATES.md          # 分析テンプレート（任意）
```

サブエージェント型スキルの特徴:
- メインコンテキストと分離して実行される
- `allowed-tools` でツール使用を制限可能
- 結果のみがメインコンテキストに返される
- `$ARGUMENTS` で引数を受け取れる

### Skill with Scripts

For skills that include utility scripts:

```
pdf-processing/
├── SKILL.md              # Instructions and workflow
├── references/
│   ├── FORMS.md          # Form-filling guide
│   └── REFERENCE.md      # API reference
└── scripts/
    ├── analyze_form.py   # Extract form fields
    ├── fill_form.py      # Fill form values
    └── validate.py       # Validate output
```

## Progressive Disclosure Patterns

### Pattern 1: High-Level Guide with References

SKILL.md provides overview, links to details:

````markdown
# PDF Processing

## Quick Start

```python
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```

## Advanced Features

- **Form filling**: See [FORMS.md](references/FORMS.md)
- **API reference**: See [REFERENCE.md](references/REFERENCE.md)
- **Examples**: See [EXAMPLES.md](references/EXAMPLES.md)
````

### Pattern 2: Domain-Specific Organization

Navigate users to relevant domain files:

````markdown
# BigQuery Analysis

## Available Datasets

| Domain | Description | Reference |
|--------|-------------|-----------|
| Finance | Revenue, ARR, billing | [finance.md](references/finance.md) |
| Sales | Opportunities, pipeline | [references/sales.md](references/sales.md) |
| Product | API usage, features | [references/product.md](references/product.md) |

## Quick Search

```bash
grep -i "revenue" references/finance.md
grep -i "pipeline" references/sales.md
```
````

### Pattern 3: Conditional Details

Basic content inline, advanced in separate files:

```markdown
# Document Processing

## Creating Documents

Use docx-js for new documents. See [DOCX-JS.md](references/DOCX-JS.md).

## Editing Documents

For simple edits, modify XML directly.

- **For tracked changes**: See [REDLINING.md](references/REDLINING.md)
- **For OOXML details**: See [OOXML.md](references/OOXML.md)
```

## Reference File Best Practices

### Keep References One Level Deep

Claude may partially read deeply nested files. Keep all references directly accessible from SKILL.md.

```
# Bad - Too deep
SKILL.md → advanced.md → details.md → actual-info.md

# Good - One level
SKILL.md → advanced.md
SKILL.md → reference.md
SKILL.md → examples.md
```

### Add Table of Contents for Long Files

For files over 100 lines, include a TOC at the top:

```markdown
# API Reference

## Contents

- [Authentication](#authentication)
- [Core Methods](#core-methods)
- [Error Handling](#error-handling)
- [Examples](#examples)

## Authentication
...
```

### Use Descriptive File Names

Names should indicate content:

```
# Good - Self-documenting
form_validation_rules.md
api_authentication.md
error_handling_patterns.md

# Bad - Unclear
doc1.md
notes.md
stuff.md
```

## SKILL.md Body Guidelines

### Target Length

| Complexity | Recommended Lines |
|-----------|------------------|
| Simple | 50-150 |
| Standard | 150-300 |
| Complex | 300-500 |
| Maximum | 500 (目安。超過時はAskUserQuestionでユーザーに確認) |

### Essential Sections

Every SKILL.md should include:

1. **Overview**: What the skill does (1-2 paragraphs)
2. **Quick Start**: Minimal working example
3. **Navigation**: Links to detailed docs
4. **Related Skills**: Cross-references

### Optional Sections

Include if relevant:

- **Prerequisites**: Required tools or setup
- **Common Patterns**: Frequently used approaches
- **Anti-Patterns**: What to avoid
- **Troubleshooting**: Common issues
- **AskUserQuestion / User Confirmation**: When skill has decision points with multiple valid approaches, include a section guiding users to confirm via AskUserQuestion before proceeding

## Scripts Organization

### When to Use Scripts

- **Deterministic operations**: Validation, formatting
- **Complex calculations**: Better than generated code
- **Repeated tasks**: Consistency across uses

### Script Documentation

````markdown
## Utility Scripts

### analyze_form.py

Extract form fields from PDF:

```bash
python scripts/analyze_form.py input.pdf > fields.json
```

**Output format**:
```json
{
  "field_name": {"type": "text", "x": 100, "y": 200}
}
```

### validate_fields.py

Check field mappings:

```bash
python scripts/validate_fields.py fields.json
# Returns: "OK" or lists errors
```
````

### Execution vs Reading

Make intent clear:

```markdown
# Execute the script (most common)
Run `analyze_form.py` to extract fields

# Read as reference (for understanding logic)
See `analyze_form.py` for the extraction algorithm
```

## File Size Guidelines

| File Type | Recommended Size |
|-----------|-----------------|
| SKILL.md | < 500 lines |
| Reference files | < 300 lines each |
| Example files | < 200 lines each |
| Script files | As needed |

ファイルがこれらの目安を超える場合、AskUserQuestionでユーザーに対応方針（ファイル分割/内容圧縮/超過許容）を確認する。
