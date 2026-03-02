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

### Step 1.5: 入力タイプ判定

`$ARGUMENTS` がファイルパスかディレクトリパスかを判定する。

- **ファイルの場合**: そのまま Step 2 へ進む（単一ファイル処理）
- **ディレクトリの場合**: Glob ツールで `<directory>/*.md` を列挙し、各 `.md` ファイルに対して Step 2〜6 を繰り返し適用するバッチ処理モードに入る

バッチ処理モードでは、以下のカウンターを初期化して処理全体を通じて管理する:
- `created`: 新規作成したAgent数（初期値 0）
- `updated`: 差分があり更新したAgent数（初期値 0）
- `skipped`: 差分なし、またはユーザーが更新を拒否したAgent数（初期値 0）

### Step 2: Claude Code Agent 解析

`$ARGUMENTS` で指定されたファイル（バッチ処理時は列挙した各ファイル）を Read ツールで読み込み、以下を抽出する:

| 抽出対象 | ソース | 用途 |
|---------|--------|------|
| `name` | フロントマター | Codex agent 識別名 |
| `description` | フロントマター | config.toml の description |
| `model` | フロントマター | 参考情報のみ（Codex では固定値を使用） |
| `tools` | フロントマター | sandbox_mode 判定の参考 |
| `skills` | フロントマター | 参照スキルテーブル生成 |
| `permissionMode` | フロントマター | sandbox_mode 判定の参考 |
| Body 全文 | フロントマター以降 | developer_instructions のベース |

### Step 2.5: プラットフォーム固有用語の置換

Step 2 で抽出した **Body 全文** と **`description` フロントマター値** に含まれるプラットフォーム固有用語を Codex 向けに置換する。

#### 置換ルール

以下の置換を **description と Body 全文の両方** に適用する:

| 置換前 | 置換後 |
|-------|-------|
| `Claude Code` | `Codex` |

**適用例**:
- `Claude Code本体から指示を受信` → `Codex本体から指示を受信`
- `完了報告はClaude Code本体に送信` → `完了報告はCodex本体に送信`
- `Claude Codeから受けた元のタスク指示` → `Codexから受けた元のタスク指示`
- `Claude Code用に最適化済み` → `Codex用に最適化済み`
- `You are Claude Code's premier specialist` → `You are Codex's premier specialist`
- `PARALLEL EXECUTION: Claude Code can launch` → `PARALLEL EXECUTION: Codex can launch`

> **注意**: この置換は Step 3 以降のすべてのフィールド生成（config.toml の `description`、agent .toml の `developer_instructions`）に先立って適用する。置換後のテキストを以降のステップで使用すること。

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

1. Grep ツールで `~/dotfiles/codex/config.toml` 内に `[agents.<agent_key>]` が存在するか確認する。

   ```
   Grep(pattern: "\\[agents\\.<agent_key>\\]", path: "~/dotfiles/codex/config.toml")
   ```

2. **存在しない場合**: 以下のエントリを末尾に追記する（skipped ではなく created 扱い）:

   ```toml
   [agents.<agent_key>]
   description = "<description フロントマターの値>"
   config_file = "agents/<agent-filename>.toml"
   ```

3. **存在する場合**: Read ツールで現在の `description` と `config_file` の値を取得し、生成内容と比較する。
   - **差分なし**: スキップし「config.toml: <agent_key> は最新です（スキップ）」と通知する。`skipped` を +1。
   - **差分あり**: 差分を表示し、AskUserQuestion で更新するか確認する。
     - 承諾した場合: Edit ツールで該当エントリを更新し、`updated` を +1。
     - 拒否した場合: スキップし、`skipped` を +1。

- `<agent_key>`: ファイル名（拡張子なし）のハイフンをアンダースコアに変換
- `<agent-filename>`: ファイル名（拡張子なし）のまま（ハイフン維持）

### Step 6: Agent .toml 作成・更新

1. `~/dotfiles/codex/agents/<agent-filename>.toml` が既に存在するか Read ツールで確認する（存在しない場合はエラーではなく「新規作成」フローへ）。

2. **存在しない場合**: Write ツールでファイルを新規作成する。`created` を +1。

3. **存在する場合**: 現在のファイル内容と生成内容を比較する。
   - **差分なし**: スキップし「<agent-filename>.toml は最新です（スキップ）」と通知する。`skipped` を +1。
   - **差分あり**: 差分を表示し、AskUserQuestion で更新するか確認する。
     - 承諾した場合: Write ツールで上書きし、`updated` を +1。
     - 拒否した場合: スキップし、`skipped` を +1。

---

## テンプレート

### config.toml エントリ

```toml
[agents.<agent_key>]
description = "<Claude Code Agent の description（Step 2.5 の置換適用済み）>"
config_file = "agents/<agent-filename>.toml"
```

### Agent .toml ファイル

```toml
model = "gpt-5.2-codex"
model_reasoning_effort = "high"
sandbox_mode = "<判定結果>"
developer_instructions = """
<Claude Code Agent の Body 全文（フロントマター以降のMarkdown、Step 2.5 の置換適用済み）>

## 参照すべき Skill

| Skill 名 | 説明 |
|----------|------|
| <skill-1> | <skill-1 の説明> |
| <skill-2> | <skill-2 の説明> |
...
"""
```

---

## バッチ処理サマリー

フォルダ一括処理（バッチ処理モード）の場合、全ファイルの処理が完了した後に以下の形式でサマリーを表示する:

```
=== 変換サマリー ===
処理対象: <N> ファイル
  作成: <created> 件
  更新: <updated> 件
  スキップ: <skipped> 件
```

単一ファイル処理の場合はサマリー表示は不要。

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
- **プラットフォーム用語の置換忘れ防止**: 生成した `.toml` ファイルに `Claude Code` が残っていないか最終確認する。残っている場合は Step 2.5 の置換漏れとして修正する
