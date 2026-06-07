# 変換の検証・トラブルシューティング

変換後のagent定義の検証手順とよくある失敗パターン。

---

## 検証手順

### 1. TOMLパース

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

期待値: 何も出ない、または意図した例外だけ。

### 3. description自動ロード方式の確認

`skills.config` は使わず、developer_instructions内に活用スキルを名前列挙する方式を採用している。以下を確認する。

```bash
# skills.config の残存チェック（0件であること）
rg 'skills\.config' agents/
```

```bash
# 活用スキル節の存在チェック（各ファイルに「活用スキル」があること）
rg -l '活用スキル' agents/
```

```bash
# 実在しないpathの混入チェック（0件であること）
rg 'path = "~/.codex/skills/' agents/
```

### 4. Codex実ランタイム確認

Codex起動時に以下のような警告がないことを確認する:

- `unknown field ...`
- `invalid type: sequence, expected a map`
- `TOML parse error ...`

---

## よくある失敗

### 失敗1: `developer_instructions` を短文化しすぎる

症状:
- agentの専門性が消える
- 元の運用ルール、報告形式、品質基準が失われる

対策:
- 元 `.md` 本文をそのままベースにする

### 失敗2: `mcp_servers` を配列で入れる

症状:
- `invalid type: sequence, expected a map`

対策:
- map形式 `[mcp_servers.<id>]` で記述するか、書かずに親セッションから継承させる

### 失敗3: `skills.config` に実在しないpathを書く

症状:
- 読み込み失敗、または期待したskillが効かない

対策:
- `skills.config` は使わない（description自動ロード方式を採用）
- どうしても使う場合は実在するpathのみ記述する

### 失敗4: 存在しないagentファイル名をAGENTS.mdに記載する

症状:
- Codexがagentを見つけられずspawnに失敗する

対策:
- AGENTS.mdには実在する `.toml` の `name` フィールド値のみ記載する

### 失敗5: runtime側とrepo側が別物だと思い込む

症状:
- 片方だけ直しても実行結果が変わらない

対策:
- `samefile()` やシンボリックリンクを確認し、実際の読み込み先を特定する

---

## 最終チェックリスト

- [ ] `agents/*.toml` に `name` / `description` / `developer_instructions` がある
- [ ] `developer_instructions` は元agent本文ベース
- [ ] `developer_instructions` 末尾に「## 活用スキル」節があり、スキル名が列挙されている
- [ ] `skills.config` を使っていない（または実在するpathのみ使用）
- [ ] `rg 'skills\.config' agents/` が0件
- [ ] `model` と `model_reasoning_effort` がtier-mapに従っている（xhigh: 設計・監査系、high: 実装系）
- [ ] `mcp_servers` を推測で追加していない（map形式 or 親継承）
- [ ] 存在しないagentファイル名をAGENTS.md等に書いていない
- [ ] 全 `.toml` が機械パースできる
- [ ] Codex起動時に警告が出ない
