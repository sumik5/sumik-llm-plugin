# テンプレート集

> SKILL.mdから参照される補助ファイル。スキル作成の各フェーズで使用する出力テンプレートを提供する。

---

## 1. Frontmatterテンプレート

スキルのfrontmatterはClaude Agentがスキルを発見・選択する際の最重要要素。descriptionの品質がスキルの利用頻度を決定する。

### 1.1 基本型（汎用）

あらゆるスキルに適用可能な基本構造。

```yaml
---
name: [gerund]-[topic]
description: >-
  [What: 三人称で能力を明記].
  [When: トリガー条件（Use when...）].
  [差別化: 類似スキルとの区別（For X, use Y instead.）（任意）].
---
```

**構成要素の解説:**

| 要素 | 必須 | 説明 | 例 |
|------|------|------|----|
| What | 必須 | 三人称現在形で能力を記述 | `Guides...`, `Enforces...`, `Researches...` |
| When | 必須 | `Use when` で始まるトリガー条件 | `Use when go.mod is detected` |
| 差別化 | 任意 | 類似スキルとの使い分け | `For X, use Y instead.` |

---

### 1.2 フレームワーク・言語型

技術スタック固有のスキルに使用する。検出条件（ファイル名、設定ファイル）を明示するのが特徴。

**パターン:** `Guides [技術] development. Use when [検出条件]. Supports/Covers [主要機能].`

**既存スキルの実例:**

```yaml
# developing-nextjs
---
name: developing-nextjs
description: >-
  Guides Next.js 16 / React 19 development.
  Use when package.json contains 'next' or next.config.* is detected.
  Supports App Router, Server Components, Cache Components,
  strict TypeScript, Tailwind CSS（最新版）, Prisma ORM, and Vitest.
---
```

```yaml
# developing-go
---
name: developing-go
description: >-
  Guides Go development with best practices from Google Style Guide and Effective Go.
  Use when go.mod is detected or Go code is being written.
  Covers naming, error handling, concurrency, testing, and project structure.
---
```

```yaml
# developing-python
---
name: developing-python
description: >-
  Guides modern Python project development.
  Use when pyproject.toml or requirements.txt is detected.
  Supports Python 3.13 + uv + ruff + mypy environment,
  FastAPI/FastMCP implementation, pytest, and Docker configuration.
---
```

**チェックリスト:**
- [ ] `Guides` で始まる
- [ ] 検出条件が具体的（ファイル名、パッケージ名）
- [ ] `Supports` / `Covers` でカバー範囲を列挙
- [ ] バージョン情報を含む（該当する場合）

---

### 1.3 ツール・プラクティス型

開発プラクティスやツール使用を強制するスキルに使用する。動作動詞（`Enforces`, `Researches`）で始まるのが特徴。

**パターン:** `[動詞]s [対象]. [強制条件/必須条件]. Use when/Use after/Required [トリガー].`

**既存スキルの実例:**

```yaml
# enforcing-type-safety
---
name: enforcing-type-safety
description: >-
  Enforces type safety in TypeScript/Python implementations.
  Any/any types strictly prohibited.
  Use when processing API responses, integrating external libraries,
  or implementing data validation.
  Supports strict mode configuration and type guard implementation.
---
```

```yaml
# securing-code
---
name: securing-code
description: >-
  Enforces secure coding practices and runs CodeGuard security check.
  Use after all code implementations to verify security.
  Covers input validation, secrets management,
  OWASP top 10 countermeasures, and authentication/authorization patterns.
---
```

```yaml
# researching-libraries
---
name: researching-libraries
description: >-
  Researches existing libraries before implementation.
  Required before writing any new functionality.
  Use when evaluating npm packages, pip packages, Go modules,
  or any third-party libraries.
  Prevents reinventing the wheel by finding and evaluating existing solutions.
---
```

**チェックリスト:**
- [ ] 動作動詞で始まる（`Enforces`, `Researches`, `Validates`）
- [ ] 強制条件が明確（`strictly prohibited`, `Required before`）
- [ ] トリガーが具体的（`Use when`, `Use after`, `Required`）

---

### 1.4 差別化パターン（相互参照）

類似スキルが存在する場合、descriptionの末尾で相互参照を設けて誤選択を防ぐ。

**パターン:** `...For [別の用途], use [別のスキル名] instead.`

**既存スキルの実例:**

```yaml
# applying-design-guidelines（理論寄り）
---
name: applying-design-guidelines
description: >-
  Comprehensive UI/UX design principles covering visual design
  (typography, color, motion) and user experience
  (cognitive psychology, interaction patterns, mental models).
  Use when making design decisions, evaluating existing interfaces,
  or needing theoretical design guidance.
  For actual frontend code generation, use designing-frontend instead.
---
```

```yaml
# designing-frontend（実装寄り）
---
name: designing-frontend
description: >-
  Creates distinctive, production-grade frontend code with Storybook and shadcn/ui integration.
  Use when implementing web components, pages, or applications
  that need creative, polished UI code.
  Focuses on actual code generation (HTML/CSS/JS) with component management.
  For theoretical UI/UX design principles and guidelines,
  use applying-design-guidelines instead.
---
```

```yaml
# automating-browser（統合）
---
name: automating-browser
description: >-
  Unified browser automation covering Playwright MCP (lightweight automation),
  CLI agent (advanced scenarios), and E2E testing with Playwright Test.
  Use for any browser automation needs - from simple navigation to complex
  testing workflows.
  Integrates three approaches: MCP for quick scripts, CLI agent for
  professional automation, and E2E testing for comprehensive test suites.
---
```

**差別化の設計ルール:**

| 関係性 | パターン | 例 |
|--------|----------|----|
| 理論 vs 実装 | 理論側: `For actual [実装], use [実装スキル]` | applying-design-guidelines / designing-frontend |
| 統合ツール | `Unified [機能] covering [3つの柱]` | automating-browser |
| 汎用 vs 特化 | 汎用側: `For [特化ドメイン], use [特化スキル]` | - |

---

### トリガーパターン（descriptionテンプレート）

新規スキルの description は以下の3パターンのいずれかに従う:

#### パターン1: 常時適用（REQUIRED）
```
REQUIRED for [scope]. Automatically load when [condition].
[Key concepts covered]. [Distinction from similar skills].
```
例: writing-clean-code, enforcing-type-safety, testing, securing-code

#### パターン2: 自動検出（MUST load）
```
[Action verb] [target] development.
MUST load when [specific file/config] is detected in project.
Covers [key features]. For [alternative scope], use [other-skill] instead.
```
例: developing-nextjs, developing-go, managing-docker

#### パターン3: オンデマンド（Use when）
```
[Action verb] [target].
Use when [specific user action or scenario].
[Key features]. [Distinction].
```
例: その他全スキル

---

### argument-hint の使用例

`argument-hint` はオートコンプリート時にユーザーに引数のヒントを表示する。

```yaml
# PR番号を引数に取るスキル
---
name: reviewing-pull-requests
argument-hint: "[PR番号 or URL]"
---

# ファイルパスを引数に取るスキル
---
name: analyzing-code
argument-hint: "[ファイルパス]"
---

# 複数引数を取るスキル
---
name: comparing-branches
argument-hint: "[base-branch] [target-branch]"
---
```

---

### 1.1b 拡張型（全フィールド）

全フロントマターフィールドを含むテンプレート。必要なフィールドのみ使用する。

```yaml
---
name: [gerund]-[topic]
description: >-
  [What: 三人称で能力を明記].
  [When: トリガー条件（Use when...）].
  [差別化: 類似スキルとの区別（任意）].
argument-hint: "[引数の説明]"           # /skill-name のオートコンプリートヒント
disable-model-invocation: true          # true: 手動呼出しのみ（自動ロード禁止）
user-invocable: true                    # false: /メニュー非表示（バックグラウンド知識用）
allowed-tools: Read, Grep, Glob         # 許可ツール制限（省略時は全ツール）
model: sonnet                           # 使用モデル（省略時はデフォルト）
context: fork                           # fork: サブエージェント実行
agent: Explore                          # context: fork時のエージェントタイプ
hooks:                                  # スキルスコープのライフサイクルフック
  PreToolUse:
    - matcher: Write
      hooks:
        - command: "validate.sh"
---
```

**フィールド解説:**

| フィールド | デフォルト | 用途 |
|-----------|----------|------|
| `argument-hint` | なし | `/skill-name` 時のオートコンプリートで表示されるヒントテキスト |
| `disable-model-invocation` | `false` | `true`にするとClaude が自動判断でロードしなくなる。手動`/name`のみ |
| `user-invocable` | `true` | `false`にすると`/`メニューに表示されない。自動ロード専用 |
| `allowed-tools` | 全ツール | カンマ区切りで使用可能ツールを制限 |
| `model` | 継承 | スキル実行時のモデルを明示的に指定 |
| `context` | なし | `fork`でサブエージェントとして別コンテキストで実行 |
| `agent` | なし | `context: fork`時のエージェントタイプを指定 |
| `hooks` | なし | スキルスコープのフック定義（PreToolUse, PostToolUse等） |

---

## 2. SKILL.mdセクション構造テンプレート

### 2.1 標準構造（単一ファイル）

推定行数が500行以下、セクション数が4以下の場合に使用する。

````markdown
---
name: [skill-name]
description: >-
  [What: 三人称で能力を明記].
  [When: トリガー条件].
  [差別化（任意）].
---

# [スキルタイトル]

[1-2行の概要。このスキルが何をするか、誰のためのものか。]

---

## 1. 使用タイミング

- **[場面1]**: [説明]
- **[場面2]**: [説明]
- **[場面3]**: [説明]

---

## 2. コアプリンシプル

### 2.1 [原則1]

**[太字キーメッセージ]**

- [詳細1]
- [詳細2]

```typescript
// コード例（必要に応じて）
```

### 2.2 [原則2]

**[太字キーメッセージ]**

- [詳細1]
- [詳細2]

### 2.N ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

- **確認すべき場面**: [判断分岐の列挙]
- **確認不要な場面**: [ベストプラクティスが明確な場合]

**AskUserQuestion使用例:**

```python
AskUserQuestion(
    questions=[{
        "question": "[確認内容]",
        "header": "[短いラベル]",
        "options": [
            {"label": "[選択肢1]", "description": "[説明]"},
            {"label": "[選択肢2]", "description": "[説明]"}
        ],
        "multiSelect": False
    }]
)
```

---

## 3. クイックリファレンス

[判断基準テーブルまたはチートシート形式で、頻繁に参照される情報をまとめる。]

| 条件 | 推奨アプローチ | 理由 |
|------|---------------|------|
| [条件1] | [アプローチ1] | [理由1] |
| [条件2] | [アプローチ2] | [理由2] |

---

## 4. [トピック別セクション]

[スキル固有の詳細内容。コード例、パターン集、設定例など。]

---

## 5. まとめ

**優先順位:**

1. [最重要事項]
2. [重要事項]
3. [推奨事項]
````

---

### 2.2 複数ファイル構造

推定行数が500行超、または独立したトピックが2つ以上ある場合に使用する。

#### SKILL.md（メインファイル・500行以下に収める）

````markdown
---
name: [skill-name]
description: >-
  [What: 三人称で能力を明記].
  [When: トリガー条件].
  [差別化（任意）].
---

# [スキルタイトル]

[1-2行の概要]

---

## 1. 使用タイミング

- **[場面1]**: [説明]
- **[場面2]**: [説明]

---

## 2. コアプリンシプル（要約）

### 2.1 [原則1の要約]

[原則の核心を2-3行で]

### 2.N ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

---

## 3. クイックリファレンス

[判断テーブル、コード例のサマリー]

---

## 4. 詳細ガイド

トピック別の詳細ガイドは以下を参照:

- **[TOPIC1.md](references/TOPIC1.md)**: [トピック1の概要]
- **[TOPIC2.md](references/TOPIC2.md)**: [トピック2の概要]
- **[TOPIC3.md](references/TOPIC3.md)**: [トピック3の概要]

---

## 5. まとめ

**優先順位:**

1. [最重要事項]
2. [重要事項]
3. [推奨事項]
````

#### サブファイル（TOPIC.md）

````markdown
# [トピックタイトル]

> [核心メッセージ（1行で）]

## 目次

1. [セクション1](#1-セクション1)
2. [セクション2](#2-セクション2)
3. [セクション3](#3-セクション3)

---

## 1. セクション1

[詳細内容]

```typescript
// コード例
```

| 条件 | 推奨 | 理由 |
|------|------|------|
| [条件1] | [推奨1] | [理由1] |

---

## 2. セクション2

[詳細内容]

---

## 3. セクション3

[詳細内容]
````

**既存の複数ファイル構成例:**

```
# developing-fullstack-javascript（トピック別分割）
skills/developing-fullstack-javascript/
├── SKILL.md
└── references/
    ├── BACKEND-STRATEGIES.md
    ├── FRONTEND-STRATEGIES.md
    ├── DEPLOYMENT-STRATEGIES.md
    └── QUALITY-CHECKLIST.md

# authoring-skills（深度別分割）
skills/authoring-skills/
├── SKILL.md
├── references/
│   ├── NAMING.md
│   ├── STRUCTURE.md
│   ├── WORKFLOWS.md
│   └── CHECKLIST.md
└── scripts/
    └── ...
```

---

## 5. Task Content型テンプレート（サブエージェント実行）

`context: fork` を使用してサブエージェントとして実行されるタスク型スキルのテンプレート。

````yaml
---
name: [task-name]
description: >-
  [What: 実行するタスクの説明].
  [When: トリガー条件].
disable-model-invocation: true
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob
argument-hint: "[引数のヒント]"
---

# [タスクタイトル]

対象: $ARGUMENTS

## 実行手順

1. $ARGUMENTS を解析
2. [手順1]
3. [手順2]
4. 結果をユーザーに報告
````

**特徴:**
- `disable-model-invocation: true`: `/name`でのみ呼出し
- `context: fork`: メインコンテキストと分離して実行
- `agent: Explore`: 読み取り専用のサブエージェントとして実行
- `$ARGUMENTS`: コマンド引数がこの変数に展開される
- `allowed-tools`: サブエージェントが使用可能なツールを制限

---

## 3. AskUserQuestionテンプレート

スキル内で判断分岐が発生する場面で、推測を避けてユーザーに確認するためのテンプレート集。

### 3.1 選択式（複数の有効なアプローチがある場合）

ベストプラクティスが複数存在し、プロジェクトの方針によって選択が異なる場合に使用する。

```python
AskUserQuestion(
    questions=[{
        "question": "[判断が必要な質問]を確認させてください。",
        "header": "[短いラベル]",
        "options": [
            {
                "label": "[選択肢1]",
                "description": "[選択肢1の説明・メリット]"
            },
            {
                "label": "[選択肢2]",
                "description": "[選択肢2の説明・メリット]"
            },
            {
                "label": "[選択肢3（推奨）]",
                "description": "[推奨理由を含む説明]"
            }
        ],
        "multiSelect": False
    }]
)
```

---

### 3.2 確認式（Yes/Noの判断が必要な場合）

処理を進めてよいか、明示的な承認が必要な場合に使用する。

```python
AskUserQuestion(
    questions=[{
        "question": "[確認内容]を進めてよいですか？",
        "header": "[短いラベル]",
        "options": [
            {
                "label": "はい",
                "description": "[実行内容の説明]"
            },
            {
                "label": "いいえ",
                "description": "[代替案の説明]"
            }
        ],
        "multiSelect": False
    }]
)
```

---

### 3.3 複数選択式（機能選択等）

含めるセクションや機能をユーザーが複数選択する場合に使用する。

```python
AskUserQuestion(
    questions=[{
        "question": "含めるセクションを選択してください。",
        "header": "セクション選択",
        "options": [
            {"label": "[セクション1]", "description": "[内容の概要]"},
            {"label": "[セクション2]", "description": "[内容の概要]"},
            {"label": "[セクション3]", "description": "[内容の概要]"},
            {"label": "すべて含める", "description": "全セクションを含む包括的なスキル"}
        ],
        "multiSelect": True
    }]
)
```

---

### 3.4 スキル作成時の標準確認セット

スキル作成のPhase 2（設計確認）で使用する、複合的な確認テンプレート。ソース分析結果に基づいて適切なパターンを選択する。

#### パターンA: 既存スキルとの重複が検出された場合

既存スキルとのスコープ比較で重複が見つかった場合に使用する。新規作成 vs 既存追記の判断を最初に確認。

````python
# 例: terraform-patterns.md を分析し、developing-terraform に重複を検出
AskUserQuestion(
    questions=[
        {
            "question": "既存スキルとの重複が検出されました。どのように進めますか？\n\n検出結果:\n- developing-terraform: Terraform開発ガイドとしてスコープが重複",
            "header": "作成方針",
            "options": [
                {"label": "既存 developing-terraform に追記（推奨）", "description": "サブファイルとして追加。既存スキルのスコープを拡張"},
                {"label": "新規スキルとして作成", "description": "既存スキルとは異なる独立したスコープの場合"}
            ],
            "multiSelect": False
        },
        {
            "question": "新規作成の場合、スキル名を決めてください（ファイル名・内容から自動推定）。",
            "header": "スキル名",
            "options": [
                {"label": "optimizing-docker", "description": "Docker最適化に焦点（ファイル名ベース候補）"},
                {"label": "tuning-containers", "description": "コンテナチューニング全般（コンテンツベース候補）"}
            ],
            "multiSelect": False
        },
        {
            "question": "ファイル構成をどうしますか？",
            "header": "ファイル構成",
            "options": [
                {"label": "SKILL.md単体", "description": "内容が500行以下に収まる場合（推奨）"},
                {"label": "複数ファイル分割", "description": "内容が多くトピック別分割が必要な場合"}
            ],
            "multiSelect": False
        }
    ]
)
````

**注意**: ユーザーが「既存に追記」を選択した場合、スキル名・ファイル構成の質問はスキップし、追記先スキルの構造に合わせた追加方法を確認する。

---

#### パターンB: 既存スキルとの重複なし（新規作成確定）

既存スキルとのスコープ比較で重複がない場合に使用する。スキル名の選択に注力。

````python
# 例: rust-development-guide.md を分析し、重複なし
AskUserQuestion(
    questions=[
        {
            "question": "作成するスキルの名前を決めてください（ファイル名・内容から自動推定）。",
            "header": "スキル名",
            "options": [
                {"label": "developing-rust（推奨）", "description": "Rust開発ガイドスキル（ファイル名+コンテンツから推定）"},
                {"label": "writing-rust", "description": "Rustコード記述に焦点を当てたスキル"},
                {"label": "implementing-rust-patterns", "description": "Rustパターン実装に焦点を当てたスキル"}
            ],
            "multiSelect": False
        },
        {
            "question": "ファイル構成をどうしますか？",
            "header": "ファイル構成",
            "options": [
                {"label": "SKILL.md単体", "description": "内容が500行以下に収まる場合（推奨）"},
                {"label": "複数ファイル分割", "description": "内容が多くトピック別分割が必要な場合"}
            ],
            "multiSelect": False
        }
    ]
)
````

---

#### パターンC: 既存スキルへの追記が確定した場合

パターンAでユーザーが「既存に追記」を選択した後に使用する。追記方法を確認。

````python
# 例: managing-docker に追記する場合
AskUserQuestion(
    questions=[
        {
            "question": "既存スキル managing-docker への追記方法を選択してください。",
            "header": "追記方法",
            "options": [
                {"label": "新規サブファイルとして追加（推奨）", "description": "OPTIMIZATION.md 等のサブファイルを新規作成"},
                {"label": "既存ファイルに統合", "description": "既存のSKILL.mdまたはサブファイルに内容を統合"},
                {"label": "既存サブファイルを置換", "description": "既存のサブファイルを更新版で置き換え"}
            ],
            "multiSelect": False
        },
        {
            "question": "追加するサブファイル名を決めてください（UPPER-CASE-HYPHEN.md形式）。",
            "header": "ファイル名",
            "options": [
                {"label": "OPTIMIZATION.md", "description": "Docker最適化ガイド"},
                {"label": "PERFORMANCE-TUNING.md", "description": "パフォーマンスチューニング"},
                {"label": "BEST-PRACTICES.md", "description": "ベストプラクティス集"}
            ],
            "multiSelect": False
        }
    ]
)
````

---

## 4. サブファイル分割の判断基準

### 分割判断テーブル

| 判断基準 | SKILL.md単体 | 複数ファイル分割 |
|---------|-------------|----------------|
| 推定行数 | 500行以下 | 500行超 |
| セクション数 | 4以下 | 5以上 |
| コード例 | 少数（5個以下） | 多数（6個以上） |
| 独立トピック | なし | 2つ以上の独立したテーマ |
| チェックリスト | 小規模（20項目未満） | 大規模（20項目以上） |

---

### 分割パターン例

#### パターン1: トピック別（developing-fullstack-javascript型）

大きなドメインを機能領域ごとに分割する場合。各サブファイルが独立して参照可能。

```
skills/my-skill/
├── SKILL.md
└── references/
    ├── BACKEND-STRATEGIES.md
    ├── FRONTEND-STRATEGIES.md
    ├── DEPLOYMENT-STRATEGIES.md
    └── QUALITY-CHECKLIST.md
```

**適用場面:** フルスタック開発、大規模フレームワーク、複数レイヤーにまたがるガイド

---

#### パターン2: 深度別（authoring-skills型）

同一ドメイン内で詳細度を段階的に深める場合。SKILL.mdが概要、サブファイルが各観点の詳細。

```
skills/my-skill/
├── SKILL.md
└── references/
    ├── NAMING.md
    ├── STRUCTURE.md
    ├── WORKFLOWS.md
    └── CHECKLIST.md
```

**適用場面:** ベストプラクティス集、ガイドライン、メタスキル（スキル作成のためのスキル等）

---

#### パターン3: 機能別

基本機能と拡張機能を分離する場合。段階的な学習パスを提供。

```
skills/my-skill/
├── SKILL.md
└── references/
    ├── ADVANCED.md
    └── TROUBLESHOOTING.md
```

**適用場面:** ツール使用ガイド、設定・運用マニュアル、学習段階があるスキル

---

### サブファイル命名規則

| ルール | 説明 | 良い例 | 悪い例 |
|--------|------|--------|--------|
| 大文字ハイフン区切り | UPPER-CASE-HYPHEN.md | `BACKEND-STRATEGIES.md` | `backend_strategies.md` |
| 内容を端的に表す | ファイル名だけで内容が推測可能 | `QUALITY-CHECKLIST.md` | `PART2.md` |
| 最大3語 | 簡潔に保つ | `DEPLOYMENT-STRATEGIES.md` | `ADVANCED-DEPLOYMENT-CONFIGURATION-GUIDE.md` |
| 拡張子は`.md` | Markdown形式 | `REFERENCE.md` | `REFERENCE.txt` |
