# Converting Agents to Codex

Claude Code Agent 定義ファイル（.md）を Codex マルチエージェント形式に変換する。

---

## 前提条件

- Codex CLI がインストール済み
- `~/dotfiles/codex/config.toml` が存在する
- `~/dotfiles/codex/agents/` ディレクトリが存在する

---

## ワークフロー

### 🔴 並列処理アーキテクチャ（バッチ処理時）

フォルダ一括処理では **Agent Teams API** を使い、最大5体のタチコマを並列起動して変換を行う。

```
┌─────────────────────────────────────────────────┐
│  Leader（Claude Code 本体）                       │
│  ・Codex 仕様取得                                 │
│  ・ファイルリスト作成 → バッチ分割（MAX 5）       │
│  ・TeamCreate → Worker 起動 → 結果収集            │
│  ・config.toml 一括更新（共有リソース）            │
│  ・サマリー表示 → TeamDelete                      │
└──────┬──────┬──────┬──────┬──────┬────────────────┘
       │      │      │      │      │
     ┌─▼─┐ ┌─▼─┐ ┌─▼─┐ ┌─▼─┐ ┌─▼─┐
     │ W1 │ │ W2 │ │ W3 │ │ W4 │ │ W5 │  ← タチコマ
     └─┬──┘ └─┬──┘ └─┬──┘ └─┬──┘ └─┬──┘
       │      │      │      │      │
       ▼      ▼      ▼      ▼      ▼
     .toml  .toml  .toml  .toml  .toml   ← 独立ファイル
```

| 責務 | Leader | Worker |
|------|--------|--------|
| Codex 仕様取得 | ✅ | - |
| Agent .md 読み込み・解析 | - | ✅（1体1ファイル） |
| プラットフォーム用語置換 | - | ✅ |
| スキル description 取得 | - | ✅（limit: 15） |
| Agent .toml 書き込み | - | ✅（各自の担当ファイルのみ） |
| config.toml 更新 | ✅（共有リソース） | ❌ |
| サマリー表示 | ✅ | - |

---

### Phase 0: 準備

#### Step 1: Codex 仕様の最新取得（🔴 毎回必須）

**必ず WebFetch で最新仕様を確認する。キャッシュされた知識に頼らない。**

```
WebFetch(
  url: "https://developers.openai.com/codex/multi-agent",
  prompt: "Extract the complete agent config file format: all available fields, their types, defaults, and any new features. Focus on the agent .toml file structure."
)
```

取得した仕様情報から、以下の**仕様サマリー**を作成し保持する（Worker プロンプトに埋め込むため）:
- 利用可能なフィールド一覧
- 各フィールドのデフォルト値
- 新機能・変更点

#### Step 1.5: 入力タイプ判定

`$ARGUMENTS` がファイルパスかディレクトリパスかを判定する。

- **ファイルの場合**: 「[単一ファイル処理](#単一ファイル処理チーム不要)」セクションに従い、チームなしで直接処理する
- **ディレクトリの場合**: Phase 1 へ進む（並列バッチ処理）

---

### Phase 1: 並列変換（Worker）

#### Step 2: チーム作成とワーカー起動

1. Glob ツールで `<directory>/*.md` を列挙し、ファイルリストを作成する
2. カウンターを初期化する:
   - `created`: 0, `updated`: 0, `skipped`: 0
3. ファイルリストを**最大5ファイルずつのバッチ**に分割する
4. `TeamCreate(team_name: "codex-convert")` でチームを作成する
5. バッチごとに以下を繰り返す:
   - バッチ内の各ファイルに対して Agent ツールで Worker を起動する
     - `subagent_type: "sumik:タチコマ"`
     - `team_name: "codex-convert"`
     - `run_in_background: true`
     - `model: "haiku"`（機械的変換のためコスト効率を優先）
     - `prompt`: 後述の「Worker プロンプトテンプレート」に従って生成
   - **1メッセージ内で最大5つの Agent ツール呼び出しを並列発行**する
   - 全 Worker の完了を待つ（SendMessage で結果を受信）
   - 次のバッチへ進む

#### Worker の内部処理

各 Worker は以下を順に実行する:

1. **Agent .md 読み込み**: 指定されたファイルを Read ツールで読み込み、フロントマターと Body を抽出する

   | 抽出対象 | ソース | 用途 |
   |---------|--------|------|
   | `name` | フロントマター | Codex agent 識別名 |
   | `description` | フロントマター | config.toml の description |
   | `tools` | フロントマター | sandbox_mode 判定 |
   | `skills` | フロントマター | スキル参照テーブル生成 |
   | `permissionMode` | フロントマター | sandbox_mode 判定 |
   | Body 全文 | フロントマター以降 | developer_instructions のベース |

2. **プラットフォーム用語置換**: Body 全文と description に以下の置換を適用する

   **テキスト置換**:
   | 置換元 | 置換先 |
   |--------|--------|
   | `Claude Code` | `Codex` |

   **Claude Code 固有ツール → Codex 向け指示への変換**:
   | Claude Code ツール | Codex での代替指示 |
   |-------------------|-------------------|
   | `AskUserQuestion` ツール呼び出し | ユーザーへのテキスト出力で質問・確認を行い、次の入力を待つ |

   > **注意**: `AskUserQuestion(...)` のようなツール呼び出し記述だけでなく、「AskUserQuestion で確認」「AskUserQuestion ツールで質問」等の自然文中の参照も変換対象とする

3. **フィールドマッピング**:

   | Claude Code | Codex | 変換ルール |
   |------------|-------|-----------|
   | ファイル名（拡張子なし） | `[agents.<key>]` | ハイフン → アンダースコア |
   | `description` | `description` | 置換済みテキストをそのまま転記 |
   | `name` | 参考情報 | developer_instructions 冒頭のコメントに含める |
   | 固定値 | `model` | `"openai/gpt-5.3-codex"` |
   | 固定値 | `model_reasoning_effort` | `"high"` |
   | 固定値 | `sandbox_mode` | `"workspace-write"`（常に固定） |
   | Body + skills テーブル | `developer_instructions` | 下記テンプレート参照 |

   **sandbox_mode**: 常に `"workspace-write"` 固定（判定不要）。

4. **スキル参照テーブル生成**: `skills` フロントマターの各スキルについて:
   - `skills/<skill-name>/SKILL.md` を **`limit: 15`** で Read（フロントマターのみ）
   - `description` の1行目（Use when... の前まで）を抽出
   - テーブル行を生成

5. **Agent .toml 書き込み**:
   - `~/dotfiles/codex/agents/<agent-filename>.toml` が既に存在するか確認
   - **存在しない場合**: Write ツールで新規作成 → `status: "created"`
   - **存在する場合**: 内容を比較
     - 差分なし → `status: "skipped"`
     - 差分あり → Write ツールで上書き → `status: "updated"`

6. **結果報告**: SendMessage で Leader に以下を報告する:
   ```
   filename: <agent-filename>
   agent_key: <agent_key>（ハイフン→アンダースコア変換済み）
   description: <置換済み description>
   config_file: agents/<agent-filename>.toml
   status: created|updated|skipped
   ```

#### Worker プロンプトテンプレート

Worker 起動時に以下のプロンプトを Agent ツールの `prompt` に設定する:

```
あなたは Claude Code Agent 定義ファイルを Codex 形式に変換する Worker です。

## 担当ファイル
<file_path>

## Codex 仕様サマリー
<Step 1 で取得した仕様サマリーをここに埋め込む>

## 変換ルール

### プラットフォーム用語置換
- Body 全文と description 中の「Claude Code」を「Codex」に一律置換する
- Claude Code 固有ツールの参照を Codex 向け指示に変換する:
  - `AskUserQuestion` ツール呼び出し・参照 → 「ユーザーへのテキスト出力で質問・確認を行い、次の入力を待つ」
  - 自然文中の「AskUserQuestion で確認」等の表現も変換対象

### フィールドマッピング
- agent_key: ファイル名（拡張子なし）のハイフンをアンダースコアに変換
- model: "gpt-5.2-codex"（固定値）
- model_reasoning_effort: "high"（固定値）
- sandbox_mode: "workspace-write"（常に固定）
- developer_instructions: 置換済み Body 全文 + スキル参照テーブル

### スキル参照テーブル
- skills フロントマターの各スキルについて skills/<skill-name>/SKILL.md を limit: 15 で Read
- description の1行目（Use when... の前まで）を抽出
- テーブル形式で developer_instructions 末尾に追加

## Agent .toml テンプレート
```toml
model = "openai/gpt-5.2-codex"
model_reasoning_effort = "high"
sandbox_mode = "<判定結果>"
developer_instructions = """
<置換済み Body 全文>

## 参照すべき Skill

| Skill 名 | 説明 |
|----------|------|
| <skill-1> | <skill-1 の説明> |
...
"""
```

## 出力先
~/dotfiles/codex/agents/<agent-filename>.toml

## 処理手順
1. Read ツールで担当ファイルを読み込む
2. フロントマターと Body を抽出する
3. Claude Code → Codex の用語置換を適用する
4. スキル参照テーブルを生成する（SKILL.md は limit: 15 で1つずつ読む）
5. Agent .toml を生成する
6. 既存ファイルがあれば比較し、差分がなければスキップ、あれば上書きする
7. 生成した .toml に「Claude Code」「AskUserQuestion」が残っていないか最終確認する
8. SendMessage で結果を報告する:
   - filename, agent_key, description, config_file, status (created/updated/skipped)

## TOML エスケープ注意
developer_instructions は三重引用符（"""）で囲む。本文中に """ が含まれる場合はエスケープが必要。
```

---

### Phase 2: 集約（Leader）

#### Step 3: config.toml 一括更新

全 Worker の処理完了後、Leader が収集した結果を基に `~/dotfiles/codex/config.toml` を更新する。

各 Worker の報告について:

1. Grep ツールで `config.toml` 内に `[agents.<agent_key>]` が存在するか確認する
2. **存在しない場合**: 以下のエントリを末尾に追記する:
   ```toml
   [agents.<agent_key>]
   description = "<Worker から報告された description>"
   config_file = "agents/<agent-filename>.toml"
   ```
3. **存在する場合**: 現在の `description` と `config_file` を比較する
   - 差分なし → スキップ
   - 差分あり → Edit ツールで更新

> **注意**: config.toml は共有リソースのため、**Leader のみが更新**する。Worker は config.toml に触れてはならない。

#### Step 4: サマリー表示とチーム解散

```
=== 変換サマリー ===
処理対象: <N> ファイル
並列度: <バッチサイズ>
  作成: <created> 件
  更新: <updated> 件
  スキップ: <skipped> 件
```

サマリー表示後、`TeamDelete` でチームを解散する。

---

### 単一ファイル処理（チーム不要）

`$ARGUMENTS` がファイルパスの場合、チームを作成せず Leader が直接処理する。

1. **Codex 仕様取得**: Step 1 と同じ
2. **Agent .md 読み込み**: Read ツールで読み込み、フロントマターと Body を抽出
3. **プラットフォーム用語置換**: `Claude Code` → `Codex` 一律置換 + Claude Code 固有ツール参照の変換（`AskUserQuestion` → ユーザーへのテキスト出力による質問・確認）
4. **フィールドマッピング**: Worker の内部処理と同じ変換ルール
5. **スキル参照テーブル生成**: 各 SKILL.md を `limit: 15` で Read
6. **Agent .toml 書き込み**:
   - 既存ファイルがあれば比較し、差分を表示して AskUserQuestion で確認
   - 新規の場合は直接作成
7. **config.toml 更新**:
   - 既存エントリがあれば比較し、差分を表示して AskUserQuestion で確認
   - 新規の場合は末尾に追記

---

## テンプレート

### config.toml エントリ

```toml
[agents.<agent_key>]
description = "<description（プラットフォーム用語置換適用済み）>"
config_file = "agents/<agent-filename>.toml"
```

### Agent .toml ファイル

```toml
model = "openai/gpt-5.2-codex"
model_reasoning_effort = "high"
sandbox_mode = "<判定結果>"
developer_instructions = """
<Body 全文（プラットフォーム用語置換適用済み）>

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
model = "openai/gpt-5.2-codex"
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
developer_instructions = """
# 言語設定（最優先・絶対遵守）
...（Body 全文、「Claude Code」→「Codex」置換済み）...

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
- **プラットフォーム用語の置換忘れ防止**: 生成した `.toml` ファイルに `Claude Code` や `AskUserQuestion` 等の Claude Code 固有ツール名が残っていないか最終確認する。残っている場合は置換漏れとして修正する
- **config.toml の排他制御**: バッチ処理時、config.toml は Leader のみが更新する。Worker が config.toml を編集してはならない（競合防止）
- **バッチサイズ**: MAX 5 を超えるファイル数の場合、5ファイルずつのバッチに分割して順次処理する。全バッチ完了後にサマリーを表示する
