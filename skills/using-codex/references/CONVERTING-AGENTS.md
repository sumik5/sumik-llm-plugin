# Converting Agents to Codex

Claude Code Agent 定義ファイル（`.md`）を Codex の subagent 定義（`config.toml` + `agents/*.toml`）へ変換するための実践ガイド。

このガイドは、実際の変換作業で発生した失敗を踏まえて更新している。特に以下は重要:

- `developer_instructions` を短く要約しすぎない
- `[[skills.config]]` は複数定義でき、`enabled = true` を明示する
- `mcp_servers` は配列で雑に埋めない
- 変換後は TOML パースと Codex 実ランタイムの読み込みを必ず確認する

参考:
- Codex subagents docs: `https://developers.openai.com/codex/subagents`

---

## 前提条件

- Codex CLI がインストール済み
- `~/.codex/config.toml` または運用中の Codex 設定ファイルが存在する
- `~/.codex/agents/` または運用中の agent ディレクトリが存在する
- 元の Claude Code agent 定義（`.md`）が取得できる

---

## 変換方針

### 最重要原則

1. **Claude Code agent の本文を `developer_instructions` の主ソースとする**
2. **frontmatter の `skills:` は Codex の `[[skills.config]]` に展開する**
3. **Codex で未確認のフィールドを推測で追加しない**
4. **変換後に TOML とランタイムの両方で検証する**

### 変換後ファイルの責務分離

- `config.toml`
  - agent の登録
  - `description`
  - `config_file`
- `agents/<agent>.toml`
  - agent 本体定義
  - `developer_instructions`
  - `skills.config`
  - 必要最小限の追加設定

---

## Codex agent file の基本構造

Codex agent file では、まず以下を中心に構成する。

```toml
name = "tachikoma_nextjs"
description = "Next.js/React specialized Tachikoma execution agent. ..."
model = "openai/gpt-5.3-codex"
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
nickname_candidates = ["Route", "Server", "Cache"]

developer_instructions = """
<元 agent 本文をベースにした instructions>
"""

[skills]

[[skills.config]]
path = "~/.codex/skills/developing-nextjs/SKILL.md"
enabled = true

[[skills.config]]
path = "~/.codex/skills/testing-code/SKILL.md"
enabled = true
```

### 安全な必須/推奨フィールド

| フィールド | 扱い |
|-----------|------|
| `name` | 必須。ASCII の安定名を推奨 |
| `description` | 必須。`config.toml` と整合させる |
| `developer_instructions` | 必須。元 agent 本文を主に使う |
| `model` | 任意。運用方針に合わせて固定可 |
| `model_reasoning_effort` | 任意。必要なら `"high"` |
| `sandbox_mode` | 任意。`workspace-write` / `read-only` など |
| `nickname_candidates` | 任意。複数起動時の識別に有用 |
| `[[skills.config]]` | 任意。複数定義可能 |

### 変換時に注意するフィールド

| フィールド | ルール |
|-----------|--------|
| `mcp_servers` | **推測で追加しない。配列で入れない。** 実運用で確認できた形式のみ使う |
| `skills` | Claude Code の `skills:` frontmatter をそのまま移植せず、`[[skills.config]]` に変換 |
| `tools` / `permissionMode` | Claude Code の frontmatter をそのまま写経しない。Codex で必要性を確認してから採用 |

---

## フィールドマッピング

### `config.toml`

Claude Code agent 1つに対して、Codex の `config.toml` には 1 エントリ作る。

```toml
[agents.tachikoma_nextjs]
description = "Next.js/React specialized Tachikoma execution agent. Handles ..."
config_file = "agents/tachikoma-nextjs.toml"
```

#### マッピングルール

| 元 | 先 | ルール |
|----|----|--------|
| ファイル名 `tachikoma-nextjs.md` | `[agents.tachikoma_nextjs]` | ハイフンをアンダースコアへ |
| frontmatter `description` | `description` | 原則そのまま |
| ファイル名 `.md` | `config_file` | `.toml` に変換 |

### `agents/*.toml`

| Claude Code agent | Codex agent |
|-------------------|-------------|
| frontmatter `name` | `name` だが ASCII 安定名へ正規化推奨 |
| frontmatter `description` | `description` |
| frontmatter `skills:` | `[[skills.config]]` 群 |
| Markdown body | `developer_instructions` |

---

## `developer_instructions` の変換ルール

### 正しい方針

**元の Markdown body を主にそのまま使う。**

やること:

- `Claude Code` → `Codex` に置換
- `Claude Code本体` → `Codex本体` に置換
- 明らかに存在しないツール名だけ実情に合わせて補正
- 変換後も元 agent の専門性・チェックリスト・報告フォーマットを維持

やってはいけないこと:

- 4行程度の短い一般文に要約する
- 専門領域、品質基準、報告フォーマットを消す
- skills 情報を本文から完全に失わせる

### `AskUserQuestion` の扱い

Claude Code agent 本文に `AskUserQuestion` の言及がある場合は、Codex 環境に合わせて次のように置換する。

```text
ユーザーへのテキスト出力で質問・確認を行い、次の入力を待つ
```

### 文字列形式

`developer_instructions` は三重引用符で囲む。

```toml
developer_instructions = """
<長文本文>
"""
```

Markdown の見出し、表、コードブロックはそのまま入れてよい。

---

## `skills.config` の変換ルール

### 基本

Claude Code agent の frontmatter にある:

```yaml
skills:
  - developing-nextjs
  - testing-code
  - securing-code
```

を、Codex では次のように変換する。

```toml
[skills]

[[skills.config]]
path = "~/.codex/skills/developing-nextjs/SKILL.md"
enabled = true

[[skills.config]]
path = "~/.codex/skills/testing-code/SKILL.md"
enabled = true

[[skills.config]]
path = "~/.codex/skills/securing-code/SKILL.md"
enabled = true
```

### 重要事項

- `[[skills.config]]` は **複数定義できる**
- `enabled = true` を **毎回明示する**
- `path` は **`~/.codex/skills/<skill>/SKILL.md` 形式** に統一する
- 参照先 skill が存在しない場合は、その skill だけ除外して理由を報告する

### 変換前にやる確認

各 skill について:

```bash
test -f ~/.codex/skills/<skill>/SKILL.md
```

存在しない skill は以下のいずれかで扱う:

1. 変換対象から除外
2. 代替 skill を採用
3. ユーザーに確認

**推測で存在しない path を書かない。**

---

## `mcp_servers` の扱い

### 原則

**このフィールドは慎重に扱う。**

実変換で確認された失敗:

- `mcp_servers = ["serena", "context7"]` のような配列を入れる
- Codex が `invalid type: sequence, expected a map` として agent を無視する

### ルール

- 公式 docs と実ランタイムの両方で形式を確認できない限り、agent file に `mcp_servers` を書かない
- 不確かな場合は **親セッションの MCP 設定継承に任せる**
- 変換ガイドや自動スクリプトで、`mcp_servers` を配列で自動挿入しない

---

## 推奨ワークフロー

### 単一 agent 変換

1. 公式 subagents docs を確認
2. 元 `.md` の frontmatter と本文を読む
3. `config.toml` エントリを作る
4. `agents/*.toml` を作る
5. `developer_instructions` に本文を戻す
6. `skills:` を `[[skills.config]]` に展開する
7. TOML パース確認
8. Codex 再起動または再読み込みで警告有無を確認

### 複数 agent 一括変換

1. まず 1 ファイルで変換ルールを確定
2. 確定したルールで残りを一括変換
3. 生成後に全件を機械検証
4. 実ランタイムで警告を確認

### 並列化について

複数ファイル変換は並列化してよいが、共有リソースは分離する。

| 対象 | 並列可否 |
|------|----------|
| 各 `agents/<name>.toml` | 並列可 |
| `config.toml` | 並列不可。最後に 1 回で更新 |

Team API や特定プラットフォーム固有 API に依存する手順は前提にしない。現在の Codex 実行環境で使えるツールだけで完結すること。

---

## 変換テンプレート

### `config.toml`

```toml
[agents.<agent_key>]
description = "<元 frontmatter の description>"
config_file = "agents/<agent-file>.toml"
```

### `agents/<agent-file>.toml`

```toml
name = "<ascii_agent_name>"
description = "<元 frontmatter の description>"
model = "openai/gpt-5.3-codex"
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
nickname_candidates = ["Alpha", "Beta", "Gamma"]

developer_instructions = """
<元 Markdown body を Codex 向けに軽微補正したもの>
"""

[skills]

[[skills.config]]
path = "~/.codex/skills/<skill-1>/SKILL.md"
enabled = true

[[skills.config]]
path = "~/.codex/skills/<skill-2>/SKILL.md"
enabled = true
```

---

## 検証手順

### 1. TOML パース

```bash
python - <<'PY'
from pathlib import Path
import tomllib

base = Path("agents")
for path in sorted(base.glob("*.toml")):
    with path.open("rb") as f:
        tomllib.load(f)
print("ok")
PY
```

### 2. 危険パターン検査

```bash
rg -n 'agent_key|^\[agent\]|^\[metadata\]|^\[config\]|^\[developer_instructions\]|mcp_servers = \[' agents
```

期待値:

- 何も出ない、または意図した例外だけ

### 3. skill path 実在確認

```bash
python - <<'PY'
from pathlib import Path
import re

for path in Path("agents").glob("*.toml"):
    text = path.read_text()
    for match in re.finditer(r'path = "~/.codex/skills/([^/]+)/SKILL.md"', text):
        skill = match.group(1)
        full = Path.home() / ".codex" / "skills" / skill / "SKILL.md"
        if not full.exists():
            print(path.name, "missing", skill)
PY
```

### 4. Codex 実ランタイム確認

Codex 起動時に以下のような警告がないことを確認する:

- `unknown field ...`
- `invalid type: sequence, expected a map`
- `TOML parse error ...`

---

## よくある失敗

### 失敗 1: `developer_instructions` を短文化しすぎる

症状:

- agent の専門性が消える
- 元の運用ルール、報告形式、品質基準が失われる

対策:

- 元 `.md` 本文をそのままベースにする

### 失敗 2: `mcp_servers` を配列で入れる

症状:

- `invalid type: sequence, expected a map`

対策:

- 不確かな形式では書かない

### 失敗 3: `skills.config` に `enabled = true` を入れ忘れる

症状:

- skill が無効として扱われうる

対策:

- すべての `[[skills.config]]` に `enabled = true`

### 失敗 4: `~/.codex/skills/...` に存在しない skill を参照する

症状:

- 読み込み失敗、または期待した skill が効かない

対策:

- 事前に `SKILL.md` の存在確認を行う

### 失敗 5: runtime 側と repo 側が別物だと思い込む

症状:

- 片方だけ直しても実行結果が変わらない

対策:

- `samefile()` やシンボリックリンクを確認し、実際の読み込み先を特定する

---

## 最終チェックリスト

- [ ] 公式 subagents docs を確認した
- [ ] `config.toml` の `[agents.<key>]` を作成した
- [ ] `agents/*.toml` に `name` / `description` / `developer_instructions` がある
- [ ] `developer_instructions` は元 agent 本文ベース
- [ ] `[[skills.config]]` が skill 分だけ並んでいる
- [ ] 各 `[[skills.config]]` に `enabled = true` がある
- [ ] skill path が `~/.codex/skills/<skill>/SKILL.md` 形式
- [ ] `mcp_servers` を推測で追加していない
- [ ] 全 `.toml` が機械パースできる
- [ ] Codex 起動時に警告が出ない
