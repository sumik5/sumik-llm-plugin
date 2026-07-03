# Naming Conventions and Descriptions

## Skill Name Requirements

> **省略可能**: `name` フィールドは省略できる。省略時はディレクトリ名がスキル名として使用される。明示的に指定する場合は以下の制約に従う。

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

> **省略可能**: `description` フィールドは省略できる。省略時はSKILL.md本文の最初の段落がdescriptionとして使用される。ただし、スキルの発見性を高めるため明示的な記述を**強く推奨**する。

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
# Pair: Theory ↔ Implementation（実在例: design:designing-ux ↔ web:designing-frontend）
# designing-ux (theory・design プラグイン)
description: "...Use when designing user experiences or referencing UI/graphic design principles. For actual frontend code generation, use web:designing-frontend instead."

# designing-frontend (implementation・web プラグイン)
description: "...Use when implementing web components that need creative, polished UI code. For theoretical UI/UX design principles, use design:designing-ux instead."
```

```yaml
# Unified: All-in-one CLI tool（実在例: web:automating-browser）
# automating-browser (unified)
description: "agent-browser CLI によるブラウザ操作自動化（スクレイピング・UI操作フロー・認証永続化・フォーム送信・データ抽出）。Use when アプリの web 操作・ブラウザ自動化を行うとき。..."
```

| Differentiation Type | Pattern | Example |
|---------------------|---------|---------|
| Theory ↔ Implementation | "For actual X, use Y instead" | design:designing-ux ↔ web:designing-frontend |
| Unified Tool | "All-in-one for X" | web:automating-browser（agent-browser CLI に統合） |
| General ↔ Specific | "For X-specific details, use Y" | devkit:testing-code（方法論全般） ↔ web:testing-with-vitest（Vitest 4.x特化） |
| Code-level ↔ Architecture-level | "Complements X with Y-level focus" | devkit:writing-clean-code ↔ devkit:applying-clean-architecture |
| Foundation ↔ Advanced | "For advanced X, use Y" | mastering-typescript (統合済み: 言語機能+実装判断基準) |

#### クロスプラグイン参照の修飾規則（マルチプラグイン構成・🔴 必須）

差別化参照（Part 3）や when_to_use で他スキルを指すときの表記規則:

| 参照先 | 表記 | 例（cloud プラグイン内の description から） |
|--------|------|------|
| 同一プラグイン内のスキル | bare 名 | `use practicing-devops instead` |
| 他プラグインのスキル | `plugin:skill` 修飾 | `use devkit:securing-code instead` |

- 実在しないスキル名への参照（ダングリング）は禁止。書く前に `plugins/*/skills/*/` で実在を確認する
- **同一ターゲットへの差別化文は 1 文に統合**する（"For DDD, use X. For Clean Architecture, use X." のような同一スキルへの重複参照は冗長）
- description に自スキルの内部ファイル名（`references/FOO.md` 等）を書かない — ルーティングに寄与せず、ファイルリネームで陳腐化する（本文中の参照は可）

#### description の内容ドリフト監査

スキル本文（INSTRUCTIONS.md / references/）を増強・削減したら、**description の機能列挙も同期**する。放置すると description が本文の実体から乖離し、ルーティング精度が落ちる（実測: 84 スキル監査で最多の問題群）。

- references/ に新ファイルを追加した時: その主要トピックが description に現れているか確認
- 本文からトピックを削除した時: description の該当語も除去
- 定期棚卸しは [USAGE-REVIEW.md](USAGE-REVIEW.md)、単発改善は [IMPROVEMENT-INTAKE.md](IMPROVEMENT-INTAKE.md) に従う

#### 日本語 description の記法

- `>-`（folded block scalar）では行の折返しが半角スペースに変換される。日本語文の途中で折り返すと文中に不自然な空白が混入するため、**折返しは文境界（。の直後）か既存の半角スペース位置のみ**で行う
- 言語は既存 description の主要言語（日本語/英語）を維持する（改修時に勝手に翻訳しない）。1 つの description 内では主要言語を統一する

#### when_to_use の使い分け（Claude Code 拡張）

- description が 1,024 字上限に迫る場合のみ、差別化参照群を `when_to_use` へ退避する（合算 1,536 字まで）
- ⚠️ `when_to_use` は Claude Code 固有拡張。Codex 等の他クライアントでは無視されるため、**クロスクライアント配布スキルでは最重要のルーティング情報を description 側に残す**

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
# Unified skill (cloud:implementing-observability)
description: "Unified observability guide covering monitoring system design, OpenTelemetry implementation, logging design, and observability engineering practices. ... Replaces: designing-monitoring, implementing-opentelemetry, implementing-logging."

# Result: 3 skills are integrated into implementing-observability; all other skills'
# descriptions that referenced the old names are rewritten to point to the unified skill
```

**Critical Rules:**
- Do NOT modify existing skills' "What" (Part 1) or "When" (Part 2) — only ADD differentiation text (Part 3)
- If existing skill already has Part 3, append or replace with more accurate text
- A single skill may reference multiple similar skills (e.g., `mastering-typescript` integrates type safety rules along with TypeScript-specific deep-dive content)

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
name: practicing-devops
description: Manages Docker containers and Compose stacks. Use when working with Docker, containers, or containerized deployments.
```

## Positioning Your Skill（スキルのポジショニング）

スキルの description や README がユーザーに「使ってみたい」と思わせるかどうかは、どう説明するかで決まる。

### 成果にフォーカスする（Focus on Outcomes, Not Features）

| アプローチ | 例 |
|-----------|-----|
| ✅ 成果フォーカス | 「ProjectHub スキルでプロジェクトワークスペースを数秒でセットアップ — ページ、データベース、テンプレートを含む — 手動設定の30分を節約」 |
| ❌ 機能フォーカス | 「ProjectHub スキルはYAML frontmatterとMarkdown指示を含むフォルダで、MCPサーバーツールを呼び出します」 |

**言い換えのポイント:**
- 「何をするか」より「何が変わるか・何が省けるか」を先に書く
- 時間・手間の削減、エラーの防止、品質の向上など具体的な恩恵を示す
- ユーザーが今抱えている「痛み」に直接応える表現を選ぶ

### MCP + Skills ストーリーを強調する

スキルとMCPを組み合わせている場合、その相乗効果をストーリーとして伝える:

```
「MCPサーバーでClaudeにLinearプロジェクトへのアクセスを提供。
スキルでチームのスプリント計画ワークフローを教える。
両者でAI駆動のプロジェクト管理を実現。」
```

このストーリー構造は「MCPが扉を開き、スキルが地図を渡す」という役割分担を明確にし、
ユーザーが両方のコンポーネントの価値を理解しやすくする。

---

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

| Prefix | 用途 | 実在例 |
|--------|------|-----|
| `analyzing-` | データ分析・レポート照会 | `analyzing-with-google-analytics` |
| `answering-` | 試験・質問への解答生成 | `answering-genai-exam` |
| `applying-` | パターン・ガイドライン適用 | `applying-clean-architecture`, `applying-behavior-design` |
| `architecting-` | アーキテクチャ設計 | `architecting-infrastructure`, `architecting-data` |
| `authoring-` | スキル・コンテンツ作成 | `authoring-plugins` |
| `automating-` | ブラウザ・プロセス自動化 | `automating-browser` |
| `building-` | システム・アプリ構築 | `building-multi-tenant-saas`, `building-ai-agents` |
| `capturing-` | 記録・知見キャプチャ | `capturing-learnings` |
| `compressing-` | 圧縮・サイズ最適化 | `compressing-epub-images` |
| `converting-` | 変換・処理 | `converting-content`, `converting-agents-to-codex` |
| `creating-` | 成果物制作 | `creating-slides`, `creating-flashcards`, `creating-diagrams` |
| `designing-` | UI/UX・システム設計 | `designing-ux`, `designing-genai-patterns` |
| `developing-` | 言語・フレームワーク開発ガイド | `developing-nextjs`, `developing-go` |
| `evaluating-` | 評価・テストハーネス | `evaluating-with-promptfoo` |
| `implementing-` | 実装手順・ワークフロー | `implementing-observability`, `implementing-design` |
| `integrating-` | 技術統合 | `integrating-ai-web-apps` |
| `managing-` | 運用・管理 | `managing-keycloak`, `managing-claude-md` |
| `mastering-` | 内部構造・上級者向け深掘り | `mastering-typescript` |
| `operating-` | ツール・サービスの CLI 操作 | `operating-gitlab`, `operating-herdr` |
| `optimizing-` | 最適化戦略 | `optimizing-search-visibility` |
| `orchestrating-` | エージェント編成・並列実行 | `orchestrating-teams`, `orchestrating-codex` |
| `practicing-` | 実践方法論 | `practicing-devops`, `practicing-product-management` |
| `recommending-` | 推奨・提案生成 | `recommending-automations` |
| `researching-` | 調査・評価 | `researching-libraries` |
| `reviewing-` | レビュー・分析 | `reviewing-code` |
| `searching-` | 検索・情報収集 | `searching-web`, `searching-files-with-fff` |
| `securing-` | セキュリティ対策 | `securing-code`, `securing-ai-development` |
| `solving-` | 問題解法・アルゴリズム | `solving-algorithms` |
| `styling-` | スタイリング手法 | `styling-with-tailwind` |
| `testing-` | テスト戦略・手法 | `testing-code`, `testing-with-vitest` |
| `using-` | ツール・ライブラリ活用 | `using-serena`, `using-next-devtools` |
| `writing-` | ドキュメント・コード記述 | `writing-clean-code`, `writing-latex` |

> 上記以外の gerund prefix（`enforcing-` / `generating-` / `modernizing-` 等）も規則上は許容されるが、現行コーパスに実在スキルはない。新設時は既存 prefix への統合を優先的に検討する。
>
> **例外命名**: `chronicle` / `find-skills` / `gws-slides` / `software-security` は gerund 形でない特殊スキル（バンドル由来・上流プロジェクト固有名・ツール名直結）。新規スキルでは gerund 原則を厳守し、これらを前例として引用しない。

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
| 1トピック = 1スキル | スキル作成 + スキル変換 + スキルレビュー → `authoring-plugins/` に統合 |

例外: 明確に異なる対象読者・使用タイミングを持つ場合（例: `mastering-typescript` は型安全ルールを内包しつつTypeScript固有の深掘りに特化）

### ツール固有コンテンツの抽出ルール

**If** 汎用スキル（例: `implementing-design`）にツール固有コンテンツ（例: Figma MCP手順）が含まれている **AND** 新規ツール専用スキル（例: `implementing-figma`）を作成する場合:

1. 汎用スキルからツール固有コンテンツを**抽出・移行**し、専用スキルに集約する
2. 汎用スキルの description に相互参照（Part 3 Differentiation）を追加する
3. 汎用スキルはツール非依存の一般原則のみを保持する

```yaml
# Before: 汎用スキルにツール固有コンテンツが混在
implementing-design:
  description: "Design implementation including Figma MCP workflows..."  # ❌ ツール固有

# After: 分離・相互参照
implementing-design:
  description: "General design principles... For Figma-specific workflows, use implementing-figma instead."  # ✅
implementing-figma:
  description: "Figma MCP integration... For general design principles (non-Figma), use implementing-design instead."  # ✅
```
