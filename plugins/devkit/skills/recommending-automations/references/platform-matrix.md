# プラットフォームマッピング表: Claude Code ↔ Codex CLI

クロスプラットフォーム自動化の全サーフェスを対比する。

---

## 1. 自動化サーフェス全体マップ

| 自動化サーフェス | Claude Code | Codex CLI |
|-----------------|-------------|-----------|
| **Hooks** | `.claude/settings.json` の `hooks` キー（JSON）。プラグインは `plugin.json` の `hooks` セクション | `~/.codex/config.toml` の `[hooks.<Event>]` または `hooks.json`（同一スキーマ）。プラグインは `.codex-plugin/plugin.json` の `hooks`。有効化に `[features] hooks = true`。**コマンドハンドラのみ実行**（prompt/agent ハンドラは無効） |
| **Subagents** | `.claude/agents/<name>.md`（YAML frontmatter＋Markdown 本文）。`model: sonnet/opus/haiku`、`tools:`、`description` | `.codex/agents/<name>.toml`（プロジェクト）/ `~/.codex/agents/<name>.toml`（個人）。`name`/`description`/`developer_instructions` 必須。`model`/`model_reasoning_effort`/`sandbox_mode`/`nickname_candidates` 任意。`[features] multi_agent = true` で有効。**明示依頼時のみ spawn**（自動選択されない） |
| **Skills** | `.claude/skills/<name>/SKILL.md`。`disable-model-invocation`/`user-invocable`/`context: fork` 等の拡張可 | `.agents/skills/<name>/SKILL.md`（repo スコープ）/ `$HOME/.agents/skills/<name>/`（user スコープ）。Agent Skills 標準準拠。`$skill-name` で明示呼出 or description による暗黙ロード。※一部ビルドは `~/.codex/skills/` にシステムスキルを持つ |
| **MCP servers** | `claude mcp add <name>` / プロジェクト `.mcp.json` / グローバル `~/.claude.json`。`--mcp-debug` で診断 | `codex mcp add` / `~/.codex/config.toml` の `[mcp_servers.<id>]`（**map 形式必須**・配列は `invalid type: sequence` エラー）。`command`/`args`/`url`/`env`/`enabled`/`startup_timeout_sec` フィールド。プラグインは `.mcp-codex.json` |
| **Plugins / Marketplace** | `/plugin install <name>` / `/plugin marketplace add` | `codex plugin add <plugin>@<marketplace>` / `.codex-plugin/plugin.json` |
| **メモリ・規約** | `CLAUDE.md`（プロジェクト / `~/.claude/CLAUDE.md`） | `AGENTS.md`（プロジェクト / `~/.codex/AGENTS.md`） |
| **Output style / 振る舞い** | Output Styles（`/output-style`）＋ `CLAUDE.md` | `AGENTS.md` ＋ personality/profiles（直接等価物なし＝AGENTS.md で代替） |
| **Slash commands / 定型タスク** | `.claude/commands/<name>.md`（`/name`） | スキル（`$skill-name`）＋ custom prompts で代替 |

---

## 2. Hooks イベント名対応表

| イベント | Claude Code | Codex CLI | 備考 |
|---------|-------------|-----------|------|
| `PreToolUse` | ✅ | ✅ | |
| `PostToolUse` | ✅ | ✅ | 最頻用 |
| `UserPromptSubmit` | ✅ | ✅ | |
| `Stop` | ✅ | ✅ | |
| `PreCompact` | ✅ | ✅ | |
| `PostCompact` | ✅ | ✅ | |
| `SessionStart` | ✅ | ✅ | |
| `SubagentStart` | ✅ | ✅ | |
| `SubagentStop` | ✅ | ✅ | |
| `PermissionRequest` | — | ✅ | Codex 独自 |

Codex の有効化: `~/.codex/config.toml` に `[features] hooks = true` が必要。
**コマンドハンドラのみ動作**（prompt/agent ハンドラは解析されるが実行されない）。

---

## 3. 同じ自動化を両プラットフォームに展開する手順

1. **SKILL.md を共通基盤にする**: Agent Skills 標準の SKILL.md は Claude/Codex 両方で読み込まれる。Claude 専用拡張（`context: fork`・`disable-model-invocation`）は Claude のみ有効だが、Codex は無視するので共存できる。
2. **Hook は設定ファイルを分ける**: Claude は `.claude/settings.json`、Codex は `~/.codex/config.toml`（または `hooks.json`）。イベント名は共通なのでスクリプト本体は流用可能。
3. **MCP は設定形式が異なる**: Claude は JSON（`.mcp.json`）、Codex は TOML map 形式（`.mcp-codex.json` / `config.toml`）。サーバー本体（`command`/`args`）は同じ。
4. **Subagent は形式変換が必要**: Claude `.md` → Codex `.toml`。詳細は `converting-agents-to-codex` スキル参照。

---

## 4. プラットフォーム差異の落とし穴

| 項目 | 落とし穴 |
|------|---------|
| `context: fork` | Claude 専用拡張。Codex では無視される（エラーにはならない） |
| `disable-model-invocation` | Claude 専用。Codex では無視 |
| `user-invocable: false` | Claude 専用フィールド。Codex の暗黙ロード制御は `agents/openai.yaml` の `policy.allow_implicit_invocation` で行う |
| Codex subagent 自動選択 | **Codex は自動で subagent を選ばない**。明示的な spawn 依頼が必要（Claude の description 自動ルーティングと異なる） |
| Codex MCP 配列形式 | **`[[mcp_servers]]` の配列形式はエラー**。`[mcp_servers.<id>]` の map 形式のみ有効 |
| Codex hooks | `[features] hooks = true` が必須。**コマンドハンドラのみ**実行される |
| Codex skills パス | `.agents/skills/`（新標準）と `~/.codex/skills/`（一部ビルドの system 用）が併存し得る。鮮度確認を推奨 |
| Codex hooks 旧フラグ | `codex_hooks = true`（旧称）は廃止予定。`[features] hooks = true` を使うこと |
