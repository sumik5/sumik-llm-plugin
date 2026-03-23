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

### 3. skill path実在確認

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
- 不確かな形式では書かない

### 失敗3: `skills.config` に `enabled = true` を入れ忘れる

症状:
- skillが無効として扱われうる

対策:
- すべての `[[skills.config]]` に `enabled = true`

### 失敗4: `~/.codex/skills/...` に存在しないskillを参照する

症状:
- 読み込み失敗、または期待したskillが効かない

対策:
- 事前に `SKILL.md` の存在確認を行う

### 失敗5: runtime側とrepo側が別物だと思い込む

症状:
- 片方だけ直しても実行結果が変わらない

対策:
- `samefile()` やシンボリックリンクを確認し、実際の読み込み先を特定する

---

## 最終チェックリスト

- [ ] `agents/*.toml` に `name` / `description` / `developer_instructions` がある
- [ ] `developer_instructions` は元agent本文ベース
- [ ] `[[skills.config]]` がskill分だけ並んでいる
- [ ] 各 `[[skills.config]]` に `enabled = true` がある
- [ ] skill pathが `~/.codex/skills/<skill>/SKILL.md` 形式
- [ ] `mcp_servers` を推測で追加していない
- [ ] 全 `.toml` が機械パースできる
- [ ] Codex起動時に警告が出ない
