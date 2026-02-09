# Naming Conventions and Descriptions

## Skill Name Requirements

### Technical Constraints

| Constraint | Requirement |
|-----------|-------------|
| Max length | 64 characters |
| Allowed chars | lowercase letters, numbers, hyphens |
| Forbidden | XML tags, spaces, underscores |
| Reserved words | "anthropic", "claude" |

### Naming Style: Gerund Form (Recommended)

Use verb + -ing form to clearly describe the activity:

| Good (Gerund) | Acceptable Alternative | Avoid |
|--------------|----------------------|-------|
| `processing-pdfs` | `pdf-processing` | `pdf-helper` |
| `analyzing-data` | `data-analysis` | `data-utils` |
| `testing-code` | `code-testing` | `test-tools` |
| `managing-databases` | `database-management` | `db` |
| `writing-documentation` | `doc-generator` | `docs` |

### Why Gerund Form?

1. **Action-oriented**: Clearly indicates what the skill does
2. **Consistent**: Easy to maintain naming pattern across skills
3. **Discoverable**: Search-friendly ("analyzing" matches "analyze")
4. **Self-documenting**: Name explains the capability

### Names to Avoid

```
# Too vague
helper, utils, tools, common, misc

# Too generic
documents, data, files, stuff

# Reserved words
anthropic-tools, claude-helper

# Technical violations
PDF_Processing    # underscores, uppercase
my skill          # spaces
processing.pdfs   # periods
```

## Writing Effective Descriptions

### Format Requirements

| Field | Constraint |
|-------|-----------|
| Max length | 1024 characters |
| Required | Non-empty |
| Forbidden | XML tags |

### The Three-Part Formula

Every description must answer:
1. **What does it do?** (capability) — Third person, present tense
2. **When to use it?** (trigger conditions) — "Use when", "Use for", "Required"
3. **How to differentiate?** (**mandatory** when similar skills exist, mutual reference) — "For X, use Y instead."

```yaml
# Template
description: [What it does]. [Use when trigger conditions]. [For X, use Y instead (optional)].

# Basic example
description: Extracts text and tables from PDF files. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

#### Differentiation Pattern (Part 3)

When similar skills exist, add mutual references to prevent confusion:

```yaml
# Pair: Theory ↔ Implementation
# applying-design-guidelines (theory)
description: "...Use when making design decisions or evaluating existing interfaces. For actual frontend code generation, use designing-frontend instead."

# designing-frontend (implementation)
description: "...Use when implementing web components that need creative, polished UI code. For theoretical UI/UX design principles, use applying-design-guidelines instead."
```

```yaml
# Unified: All-in-one browser automation
# automating-browser (unified)
description: "...Covers Playwright MCP (lightweight automation), CLI agent (advanced scenarios), and E2E testing. Use for any browser automation needs."
```

| Differentiation Type | Pattern | Example |
|---------------------|---------|---------|
| Theory ↔ Implementation | "For actual X, use Y instead" | applying-design-guidelines ↔ designing-frontend |
| Unified Tool | "All-in-one for X" | automating-browser (統合: Playwright MCP + CLIエージェント + E2Eテスト) |
| General ↔ Specific | "Reference Y for general X" | convert-to-skill → authoring-skills |
| Parent ↔ Child | "For specific use case, see Y" | authoring-skills → convert-to-skill |
| Language-level ↔ Architecture-level | "Complements X with Y-level focus" | writing-clean-code ↔ modernizing-architecture |
| Foundation ↔ Advanced | "For advanced X, use Y" | mastering-typescript (統合済み: 言語機能+実装判断基準) |

#### Mutual Update Requirement

When creating a new skill with similar existing skills, **both sides must be updated**. Updating only the new skill's description is incomplete — Claude Code reads all skill descriptions to decide which to activate.

**Workflow:**
1. Identify similar existing skills by scanning `skills/` directory descriptions
2. Design differentiation text for BOTH new and existing skills
3. Update new skill's description with Part 3 differentiation
4. Update each similar existing skill's description with mutual reference to new skill

**Implementation Example:**

When consolidating related skills, update all references:

```yaml
# Unified skill (developing-nextjs)
description: "Next.js 16 / React 19 development guide covering App Router, Server Components, React performance optimization, and React internals. Use when package.json contains 'next'."

# Result: react-best-practices and mastering-react-internals are integrated into developing-nextjs
```

**Critical Rules:**
- Do NOT modify existing skills' "What" (Part 1) or "When" (Part 2) — only ADD differentiation text (Part 3)
- If existing skill already has Part 3, append or replace with more accurate text
- A single skill may reference multiple similar skills (e.g., `mastering-typescript` references `enforcing-type-safety` for type safety rules)

### Point of View: Always Third Person

**Critical**: Descriptions are injected into the system prompt. Inconsistent point-of-view causes discovery problems.

| Good (Third Person) | Avoid |
|--------------------|-------|
| "Processes Excel files and generates reports" | "I can help you process Excel files" |
| "Analyzes code for security vulnerabilities" | "You can use this to analyze code" |
| "Generates test cases from specifications" | "Use me to generate test cases" |

### Be Specific with Key Terms

Include terms users might search for:

```yaml
# Too vague
description: Helps with documents

# Better - includes key terms
description: Extracts text and tables from PDF files, fills forms, merges documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

### Include Trigger Conditions

Help Claude know when to activate the skill:

```yaml
# Without triggers - Claude may miss activation
description: Analyzes Excel spreadsheets

# With triggers - clear activation signals
description: Analyzes Excel spreadsheets, creates pivot tables, generates charts. Use when analyzing Excel files, spreadsheets, tabular data, or .xlsx files.
```

## Examples by Category

### Data Processing Skills

```yaml
name: processing-pdfs
description: Extracts text and tables from PDF files, fills forms, merges documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

```yaml
name: analyzing-spreadsheets
description: Analyzes Excel and CSV files, creates pivot tables, generates charts. Use when analyzing Excel files, spreadsheets, tabular data, or .xlsx/.csv files.
```

### Development Skills

```yaml
name: testing-code
description: Generates unit tests and integration tests from code. Use when the user asks to create tests, improve test coverage, or validate functionality.
```

```yaml
name: reviewing-pull-requests
description: Reviews code changes for bugs, style issues, and best practices. Use when reviewing PRs, code diffs, or when asked to check code quality.
```

### Documentation Skills

```yaml
name: writing-api-docs
description: Generates API documentation from code and OpenAPI specs. Use when creating API docs, documenting endpoints, or generating SDK references.
```

### Infrastructure Skills

```yaml
name: managing-containers
description: Manages Docker containers and Compose stacks. Use when working with Docker, containers, or containerized deployments.
```

## Common Mistakes

### Mistake 1: No Trigger Conditions

```yaml
# Bad - no triggers
description: Processes images

# Good - clear triggers
description: Resizes, crops, and converts image files. Use when processing images, resizing photos, or converting image formats like PNG, JPG, WEBP.
```

### Mistake 2: Wrong Point of View

```yaml
# Bad - first/second person
description: I help you analyze data and create visualizations

# Good - third person
description: Analyzes data and creates visualizations. Use when exploring datasets or generating charts.
```

### Mistake 3: Too Long and Verbose

```yaml
# Bad - verbose explanation
description: This skill is designed to help with the process of analyzing various types of data files including but not limited to CSV, Excel, and JSON formats. It can perform statistical analysis, generate visualizations, and create reports. The skill is particularly useful when...

# Good - concise
description: Analyzes CSV, Excel, and JSON data with statistics and visualizations. Use when exploring data or generating analytical reports.
```

## Checklist

Before finalizing your skill name and description:

- [ ] Name uses gerund form (verb + -ing)
- [ ] Name is lowercase with hyphens only
- [ ] Name is under 64 characters
- [ ] Name avoids reserved words
- [ ] Description uses third person
- [ ] Description explains what it does
- [ ] Description includes trigger conditions
- [ ] Description includes differentiation (if similar skills exist)
- [ ] Description includes key search terms
- [ ] Description is under 1024 characters

---

## Unified Naming Rules

### Prefix 標準一覧

スキル名は以下のgerund prefix のいずれかで始めること:

| Prefix | 用途 | 例 |
|--------|------|-----|
| `developing-` | 言語・フレームワーク開発ガイド | `developing-nextjs`, `developing-go` |
| `writing-` | ドキュメント・コード記述 | `writing-clean-code`, `writing-latex` |
| `designing-` | UI/UX・API設計 | `designing-frontend`, `designing-web-apis` |
| `implementing-` | 実装手順・ワークフロー | `implementing-opentelemetry` |
| `enforcing-` | ルール・制約の強制 | `enforcing-type-safety` |
| `managing-` | 運用・インフラ管理 | `managing-docker` |
| `using-` | ツール・ライブラリ活用 | `using-serena`, `using-next-devtools` |
| `testing-` | テスト戦略・手法 | `testing-code` |
| `securing-` | セキュリティ対策 | `securing-code` |
| `researching-` | 調査・評価 | `researching-libraries` |
| `building-` | システム・アプリ構築 | `building-multi-tenant-saas` |
| `mastering-` | 内部構造・上級者向け深掘り | `mastering-typescript` |
| `applying-` | パターン・ガイドライン適用 | `applying-design-guidelines` |
| `automating-` | ブラウザ・プロセス自動化 | `automating-browser` |
| `reviewing-` | レビュー・分析 | `reviewing-code` |
| `converting-` | 変換・処理 | `converting-documents` |
| `crafting-` | コンテンツ制作 | `crafting-ai-copywriting` |
| `generating-` | 成果物自動生成 | `generating-google-slides` |
| `removing-` | 特定要素の除去 | `removing-ai-smell` |
| `searching-` | 検索・情報収集 | `searching-web` |
| `modernizing-` | レガシー刷新 | `modernizing-architecture` |
| `architecting-` | アーキテクチャ設計 | `architecting-microservices` |
| `authoring-` | スキル・コンテンツ作成 | `authoring-skills` |

### 命名規則チェックフロー

```
新スキル名を決める際:
1. gerund形式（動詞-ing + 目的語）であること → 必須
2. 上記 prefix 一覧のいずれかで始まること → 推奨
3. 目的語が具体的であること（vague な名前を避ける）
4. 64文字以内であること
5. 既存スキルと重複しないこと
```

### 1言語/1ライブラリ = 1スキルの原則

同一の言語・ライブラリ・トピックに対して複数スキルを作成しない。関連コンテンツはサブファイルとして Progressive Disclosure で管理する。

| 原則 | 説明 |
|------|------|
| 1言語 = 1スキル | Go開発ガイド + Goデザインパターン + Go内部構造 → `developing-go/` に統合 |
| 1ツール = 1スキル | ツール活用 + ツール設定 → `using-[tool]/` に統合 |
| 1トピック = 1スキル | スキル作成 + スキル変換 + スキルレビュー → `authoring-skills/` に統合 |

例外: 明確に異なる対象読者・使用タイミングを持つ場合（例: `enforcing-type-safety` は全コード共通、`mastering-typescript` はTS深掘り）
