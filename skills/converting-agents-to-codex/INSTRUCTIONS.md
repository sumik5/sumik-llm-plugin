# Converting Agents to Codex

Claude Code Agent 定義ファイル（.md）を Codex マルチエージェント形式に変換する。

---

## 前提条件

- Codex CLI がインストール済み
- `~/dotfiles/codex/config.toml` が存在する
- `~/dotfiles/codex/agents/` ディレクトリが存在する

---

## ワークフロー

### Step 1: Codex 仕様の最新取得（🔴 毎回必須）

**必ず WebFetch で最新仕様を確認する。キャッシュされた知識に頼らない。**

```
WebFetch(
  url: "https://developers.openai.com/codex/multi-agent",
  prompt: "Extract the complete agent config file format: all available fields, their types, defaults, and any new features. Focus on the agent .toml file structure."
)
```

仕様に変更があった場合、以下のテンプレートを最新仕様に合わせて調整すること。

### Step 2: Claude Code Agent 解析

`$ARGUMENTS` で指定されたファイルを Read ツールで読み込み、以下を抽出する:

| 抽出対象 | ソース | 用途 |
|---------|--------|------|
| `name` | フロントマター | Codex agent 識別名 |
| `description` | フロントマター | config.toml の description |
| `model` | フロントマター | 参考情報のみ（Codex では固定値を使用） |
| `tools` | フロントマター | sandbox_mode 判定の参考 |
| `skills` | フロントマター | 参照スキルテーブル生成 |
| `permissionMode` | フロントマター | sandbox_mode 判定の参考 |
| Body 全文 | フロントマター以降 | developer_instructions のベース |

### Step 3: フィールドマッピング

| Claude Code | Codex | 変換ルール |
|------------|-------|-----------|
| ファイル名（拡張子なし） | `[agents.<key>]` | ハイフン → アンダースコア（例: `tachikoma-nextjs` → `tachikoma_nextjs`） |
| `description` | `description` | そのまま転記 |
| `name` | 参考情報 | developer_instructions 冒頭のコメントに含める |
| 固定値 | `model` | `"gpt-5.2-codex"` |
| 固定値 | `model_reasoning_effort` | `"high"` |
| `tools` / `permissionMode` | `sandbox_mode` | 下記判定表参照 |
| Body + skills テーブル | `developer_instructions` | 下記テンプレート参照 |

#### sandbox_mode 判定

| 条件 | sandbox_mode |
|------|-------------|
| `permissionMode: plan` または tools に Write/Edit がない | `"read-only"` |
| tools に Write/Edit/Bash がある | `"workspace-write"` |

### Step 4: スキル参照テーブル生成

Claude Code Agent の `skills` フロントマターに列挙された各スキルについて:

1. `skills/<skill-name>/SKILL.md` を Read ツールで読み込む
2. フロントマターの `description` を抽出
3. 以下のテーブル行を生成:

```
| <skill-name> | <description の1行目（Use when... の前まで）> |
```

### Step 5: config.toml 更新

`~/dotfiles/codex/config.toml` に以下のセクションを **追記** する（既存内容は保持）:

```toml
[agents.<agent_key>]
description = "<description フロントマターの値>"
config_file = "agents/<agent-filename>.toml"
```

- `<agent_key>`: ファイル名（拡張子なし）のハイフンをアンダースコアに変換
- `<agent-filename>`: ファイル名（拡張子なし）のまま（ハイフン維持）

**注意**: 同名の `[agents.<key>]` が既に存在する場合は、上書きするか確認する（AskUserQuestion）。

### Step 6: Agent .toml 作成

`~/dotfiles/codex/agents/<agent-filename>.toml` を作成する。

---

## テンプレート

### config.toml エントリ

```toml
[agents.<agent_key>]
description = "<Claude Code Agent の description>"
config_file = "agents/<agent-filename>.toml"
```

### Agent .toml ファイル

```toml
model = "gpt-5.2-codex"
model_reasoning_effort = "high"
sandbox_mode = "<判定結果>"
developer_instructions = """
<Claude Code Agent の Body 全文（フロントマター以降のMarkdown）>

## 参照すべき Skill

| Skill 名 | 説明 |
|----------|------|
| <skill-1> | <skill-1 の説明> |
| <skill-2> | <skill-2 の説明> |
...
"""
```

---

## 変換例

### 入力: `tachikoma-nextjs.md`

フロントマター:
```yaml
name: タチコマ（Next.js）
description: "Next.js/React specialized Tachikoma execution agent..."
model: sonnet
tools: Read, Grep, Glob, Edit, Write, Bash
skills:
  - developing-nextjs
  - developing-react
  - using-next-devtools
  - writing-clean-code
  - enforcing-type-safety
  - testing-code
  - testing-e2e-with-playwright
  - securing-code
```

### 出力 1: config.toml への追記

```toml
[agents.tachikoma_nextjs]
description = "Next.js/React specialized Tachikoma execution agent. Handles Next.js 16 App Router, Server Components, React 19 features, Turbopack, Cache Components, and next-devtools MCP integration."
config_file = "agents/tachikoma-nextjs.toml"
```

### 出力 2: `agents/tachikoma-nextjs.toml`

```toml
model = "gpt-5.2-codex"
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
developer_instructions = """
# 言語設定（最優先・絶対遵守）
...（Body 全文）...

## 参照すべき Skill

| Skill 名 | 説明 |
|----------|------|
| developing-nextjs | Next.js 16.x development guide covering App Router, Server Components, Turbopack... |
| developing-react | React 19.x development guide covering internals, performance optimization... |
| using-next-devtools | Next.js development integration tools via next-devtools MCP |
| writing-clean-code | REQUIRED for all code implementations |
| enforcing-type-safety | REQUIRED for all TypeScript/Python code |
| testing-code | REQUIRED for all feature implementations |
| testing-e2e-with-playwright | Playwright E2E test design and implementation guide |
| securing-code | REQUIRED after all code implementations |
"""
```

---

## 注意事項

- **TOML文字列のエスケープ**: `developer_instructions` は三重引用符（`"""`）で囲む。本文中に `"""` が含まれる場合はエスケープが必要
- **description の長さ**: Codex 側の制限は確認していないが、簡潔に保つことを推奨
- **日本語の扱い**: TOML は UTF-8 をサポートするため、日本語テキストはそのまま含めてよい
- **既存エントリの重複チェック**: config.toml への追記前に、同名キーが存在しないか Grep で確認する
