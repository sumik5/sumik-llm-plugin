# Claude Code Agent → Codex Agent 変換ガイド

Claude Code Agent定義ファイル（`.md`）をCodexのsubagent定義（`agents/*.toml`）に変換する。

---

## 最重要原則

1. **Claude Code agentの本文を `developer_instructions` の主ソースとする**（短く要約しない）
2. **frontmatterの `skills:` は developer_instructions 内に「活用スキル」として名前列挙する**（`skills.config` は使わず、Codexのdescription自動ロードに委ねる）
3. **Codexで未確認のフィールドを推測で追加しない**
4. **変換後にTOMLとランタイムの両方で検証する**

---

## 前提条件

- Codex CLIがインストール済み
- `~/.codex/agents/`（個人）または `.codex/agents/`（プロジェクト）にagent定義ファイルを配置可能
- 元のClaude Code agent定義（`.md`）が取得できる

---

## Codex Agent定義の基本構造

カスタムagentは `~/.codex/agents/<name>.toml` または `.codex/agents/<name>.toml` に配置する。**`config.toml`への登録は不要**（`~/.codex/agents/` 配下のファイルは自動検出される）。

`name` フィールドが source of truth。ファイル名との一致は推奨慣例だが必須ではない。ハイフン・アンダースコアどちらも使用可。

```toml
name = "tachikoma-nextjs"
description = "Next.js/React specialized Tachikoma execution agent. ..."
model = "gpt-5.5"
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
nickname_candidates = ["Route", "Server", "Cache"]

developer_instructions = """
<元agent本文をベースにしたinstructions>

## 活用スキル
本エージェントは次のスキル群を活用する（Codexがdescriptionで自動ロード）:
developing-nextjs, testing-code, securing-code
"""
```

### フィールド一覧

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `name` | 必須 | source of truth。ハイフン/アンダースコア可 |
| `description` | 必須 | 元agent descriptionを基にする。Codexがagent選択判断に使用 |
| `developer_instructions` | 必須 | 元agent本文を主ソースとする。末尾に活用スキル名を列挙 |
| `model` | 任意 | 運用方針に合わせて固定可（下記tier-map参照） |
| `model_reasoning_effort` | 任意 | `"minimal"` / `"low"` / `"medium"` / `"high"` / `"xhigh"` |
| `sandbox_mode` | 任意 | `"read-only"` / `"workspace-write"` / `"danger-full-access"` |
| `nickname_candidates` | 任意 | 表示専用（presentation-only）。識別には使われない |
| `[[skills.config]]` | 任意 | 実在するローカルpathがある場合のみ。既定では使わない |

---

## フィールドマッピング

| Claude Code agent | Codex agent |
|-------------------|-------------|
| frontmatter `name` | `name`（ASCII安定名へ正規化推奨） |
| frontmatter `description` | `description` |
| frontmatter `skills:` | `developer_instructions` 末尾の「活用スキル」名前列挙 |
| Markdown body | `developer_instructions` |
| frontmatter `tools` / `permissionMode` | 直接対応なし（`sandbox_mode`で制御） |

---

## `developer_instructions` の変換ルール

**元のMarkdown bodyを主にそのまま使う。**

やること:
- `Claude Code` → `Codex` に置換
- `Claude Code本体` → `Codex本体` に置換
- 明らかに存在しないツール名だけ実情に合わせて補正
- 変換後も元agentの専門性・チェックリスト・報告フォーマットを維持
- 末尾に「## 活用スキル」節を追加し、元frontmatterの `skills:` 一覧をスキル名で列挙

やってはいけないこと:
- 4行程度の短い一般文に要約する
- 専門領域、品質基準、報告フォーマットを消す
- skills情報を本文から完全に失わせる

### 活用スキル節の形式

```toml
developer_instructions = """
（本文）

## 活用スキル
本エージェントは次のスキル群を活用する（Codexがdescriptionで自動ロード）:
developing-nextjs, testing-code, securing-code
"""
```

### `AskUserQuestion` の扱い

Claude Code agent本文に `AskUserQuestion` の言及がある場合:

```text
ユーザーへのテキスト出力で質問・確認を行い、次の入力を待つ
```

### 文字列形式

`developer_instructions` は三重引用符で囲む。Markdownの見出し・表・コードブロックはそのまま入れてよい。

```toml
developer_instructions = """
<長文本文>
"""
```

---

## モデル・推論effortのマッピング

元Claude Code agentの `model` フィールドから変換する際は以下のtier-mapに従う。

| 元Claude model | Codex model | model_reasoning_effort |
|---|---|---|
| opus / opus[1m]（設計・読取専用・高度推論ロール） | gpt-5.5 | xhigh |
| sonnet（実装・標準ロール） | gpt-5.5 | high |
| haiku（軽量ロール） | gpt-5.5 | low または medium |

現行モデル名の例: `gpt-5.5` / `gpt-5.4` / `gpt-5.1-codex-max`

`xhigh` はResponses APIをサポートするモデルのみ有効。対応モデルで使うこと。

---

## サブエージェント起動メカニズム

Codexのsubagent spawnは**明示的依頼時のみ**動作する。自動的にサブエージェントが選ばれることはない。

| 要素 | 説明 |
|------|------|
| `description` | Codexがagentを選択する判断基準。充実したdescriptionが重要 |
| `nickname_candidates` | **表示専用（presentation-only）**。識別・ルーティングには使われない |
| `[features] multi_agent = true` | spawn_agent / send_input / resume_agent / wait_agent / close_agent を有効化（既定で有効・安定） |

spawn_agent等のCodexツールはCodex本体が呼び出す。agent定義ファイルに記述するものではない。

---

## config.toml セットアップ

agent定義ファイル自体は `~/.codex/agents/` から自動検出されるため `config.toml` への登録は不要。`config.toml` には動作制御パラメータのみ設定する。

```toml
[features]
multi_agent = true  # subagent spawnを有効化（既定で有効）

[agents]
max_threads = 6               # 同時実行agent数（既定: 6）
max_depth = 1                 # subagentのネスト深さ（既定: 1）
job_max_runtime_seconds = 1800  # 1jobの最大実行時間（既定: 1800秒）

[shell_environment_policy]
inherit = "all"  # 親環境変数を継承
```

sandbox_modeはagent定義ファイル側で指定する（`read-only` / `workspace-write` / `danger-full-access`）。

---

## `mcp_servers` の扱い

`mcp_servers` は **map形式** で記述する。記述しない場合は親セッションの設定を継承する（推奨デフォルト）。

```toml
[mcp_servers.my_server]
command = "npx"
args = ["-y", "@some/mcp-server"]
enabled = true

[mcp_servers.my_server.tools.some_tool]
approval_mode = "auto"
```

| ルール | 理由 |
|--------|------|
| map形式 `[mcp_servers.<id>]` で記述する | 配列形式は `invalid type: sequence, expected a map` エラー |
| 不確かな場合は書かずに親継承に任せる | 安全なデフォルト |

---

## Agent マッピング表

Claude Code subagent_type → Codex agent名 と モデルtier の対応（変換時の参照用）:

| Claude Code subagent_type | Codex agent名（=ファイル名） | tier |
|--------------------------|--------------------------|------|
| `sumik:serena-expert` | `serena-expert` | high |
| `sumik:tachikoma` | `tachikoma` | high |
| `sumik:tachikoma-lang-python` | `tachikoma-python` | high |
| `sumik:tachikoma-lang-go` | `tachikoma-go` | high |
| `sumik:tachikoma-lang-bash` | `tachikoma-bash` | high |
| `sumik:tachikoma-lang-typescript` | `tachikoma-typescript` | high |
| `sumik:tachikoma-fw-nextjs` | `tachikoma-nextjs` | high |
| `sumik:tachikoma-fw-fullstack-js` | `tachikoma-fullstack-js` | high |
| `sumik:tachikoma-fe-frontend` | `tachikoma-frontend` | high |
| `sumik:tachikoma-fe-figma-impl` | `tachikoma-figma-impl` | high |
| `sumik:tachikoma-fe-design-system` | `tachikoma-design-system` | high |
| `sumik:tachikoma-fe-ux-design` | `tachikoma-ux-design` | high |
| `sumik:tachikoma-cloud-aws` | `tachikoma-aws` | high |
| `sumik:tachikoma-cloud-gcp` | `tachikoma-google-cloud` | high |
| `sumik:tachikoma-cloud-infra` | `tachikoma-infra` | high |
| `sumik:tachikoma-cloud-terraform` | `tachikoma-terraform` | high |
| `sumik:tachikoma-data-database` | `tachikoma-database` | high |
| `sumik:tachikoma-data-ai-ml` | `tachikoma-ai-ml` | high |
| `sumik:tachikoma-qa-test` | `tachikoma-test` | high |
| `sumik:tachikoma-qa-e2e-test` | `tachikoma-e2e-test` | high |
| `sumik:tachikoma-qa-observability` | `tachikoma-observability` | high |
| `sumik:tachikoma-qa-security` | `tachikoma-security` | **xhigh** |
| `sumik:tachikoma-qa-code-reviewer` | `tachikoma-code-reviewer` | **xhigh** |
| `sumik:tachikoma-str-architecture` | `tachikoma-architecture` | **xhigh** |
| `sumik:tachikoma-str-product-mgr` | `tachikoma-product-manager` | **xhigh** |
| `sumik:tachikoma-doc-document` | `tachikoma-document` | high |
| `sumik:tachikoma-doc-slide` | `tachikoma-slide` | **xhigh** |
| `sumik:tachikoma-doc-training` | `tachikoma-training-presenter` | high |

xhigh対象: 設計・監査・高度推論ロール（architecture / security / code-reviewer / product-manager / slide）

---

## AGENTS.md ルーティング統合

CodexプロジェクトにAGENTS.mdを置く場合、またはconfig.toml参照のガイドを整備する場合は以下を守る。

- 実在するagentファイル名（`.toml`のnameフィールド値）のみ列挙する
- 存在しないファイル名を載せない
- 各エントリに「ファイル名・検出条件・専門領域・description要約」を記述する
- Codexはdescriptionでagentを選択するため、descriptionの充実が重要

---

## 推奨ワークフロー

### 単一agent変換

1. 元 `.md` のfrontmatterと本文を読む
2. `agents/<name>.toml` を作る
3. `developer_instructions` に本文を戻す
4. 末尾に「## 活用スキル」節を追加し、元 `skills:` を名前列挙する
5. tier-mapでmodelとmodel_reasoning_effortを決める
6. TOMLパース確認
7. Codex再起動で警告有無を確認

### 複数agent一括変換

1. まず1ファイルで変換ルールを確定
2. 確定したルールで残りを一括変換
3. 生成後に全件を機械検証
4. 実ランタイムで警告を確認

---

## 変換テンプレート

```toml
name = "<ascii_agent_name>"
description = "<元frontmatterのdescription>"
model = "gpt-5.5"
model_reasoning_effort = "high"   # xhigh: 設計・監査系。high: 実装系。low/medium: 軽量系
sandbox_mode = "workspace-write"
nickname_candidates = ["Alpha", "Beta", "Gamma"]

developer_instructions = """
<元Markdown bodyをCodex向けに軽微補正したもの>

## 活用スキル
本エージェントは次のスキル群を活用する（Codexがdescriptionで自動ロード）:
<skill-1>, <skill-2>, <skill-3>
"""
```

---

## サブファイルナビゲーション

| ファイル | 内容 |
|---------|------|
| `references/CONVERTING-AGENTS.md` | 検証手順・よくある失敗パターン・最終チェックリスト |

---

## 関連スキル

- `orchestrating-codex` - Codex Agentオーケストレーション（Wave並列実行）
- `authoring-plugins` - Claude Code Plugin開発ガイド
- `implementing-as-tachikoma` - タチコマAgent運用ガイド
