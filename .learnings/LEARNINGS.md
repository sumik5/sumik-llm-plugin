# LEARNINGS — sumik-claude-plugin

作業中に得た非自明な学び・調査結果の記録（capturing-learnings 形式）。

---

## [LRN-20260625-001] Codex CLI プラグイン hook の仕様（Claude Code との差分）

**種別**: knowledge_gap（一次ソース＋実プラグインで検証済み）

**背景**: dotfiles の hook を devkit に取り込み Claude Code / Codex 両対応にする際、Codex の
プラグイン hook 仕様を一次ソース（developers.openai.com/codex の hooks / plugins/build /
config-reference）＋ローカル実プラグイン（figma・replayio の `hooks.json`）で確認した結果。

**判明した非自明な事実**:

1. **配布方式**: Codex プラグインは **plugin root 直下の `hooks.json`** で hook を配布する。
   スキーマは Claude Code の plugin.json `hooks` ブロックと**同一**（event → `[{matcher, hooks:[{type:"command", command, timeout}]}]`）。
   - **自動発見される**（figma の `.codex-plugin/plugin.json` に `hooks` キーが無いのに `hooks.json` が動く＝全181プラグイン manifest をスキャンしても `hooks` キーは皆無）。
   - ただし `.codex-plugin/plugin.json` に `"hooks": "./<path>"` で**明示宣言も可能**（宣言が自動発見を上書き）。**ドキュメントは既定パスを `./hooks/hooks.json` と記すが、実出荷プラグインは root 直下 `hooks.json`**＝ドキュメントと実態に乖離。曖昧さを避けるなら明示宣言が安全。

2. **対応イベントは Claude Code の部分集合**。Codex 対応 = SessionStart / SubagentStart /
   PreToolUse / PermissionRequest / PostToolUse / PreCompact / PostCompact / UserPromptSubmit /
   SubagentStop / Stop の10種。**非対応 = Notification / SessionEnd / TeammateIdle**（公式が「not documented」と明示）。
   → これらに紐づく hook（通知系の一部・retrospective 等）は Codex 側に登録できない。

3. **`${CLAUDE_PLUGIN_ROOT}` を command パス文字列内で展開しない**（MCP の `os error 2` と同根）。
   実プラグインは `./scripts/...` の**相対パス**を使う（plugin root 基準で解決）。
   devkit は plugin root = repo root のため `bash ./plugins/devkit/hooks/X.sh`（`.mcp-codex.json` と同規約）。
   - **ただし hook プロセスの環境変数としては `CLAUDE_PLUGIN_ROOT`（＝`PLUGIN_ROOT` の互換 alias）が set される**。「env var が set される」と「`${...}` を manifest/パス文字列で展開する」は別物。

4. **stdin JSON のフィールド名は Claude Code と一致**（replayio の実スクリプトが `.tool_input.command` を読む）。
   Stop/SubagentStop は `stop_hook_active` / `last_assistant_message`、SubagentStop は加えて `agent_type`/`agent_id`/`agent_transcript_path`。
   出力も同形（exit 0 + JSON `hookSpecificOutput.additionalContext` / exit 2 で block・stderr が理由）。

5. **実験的・opt-in・trust gate**: `config.toml` の `[features] hooks = true` が正（`codex_hooks` は**deprecated alias**）。
   プラグイン同梱 hook は「non-managed」扱いで、**ユーザーが明示的に review & trust するまで Codex はスキップ**する
   （install/enable だけでは自動信頼されない）。Windows は無効。

**この repo での適用**: Claude は `plugins/devkit/.claude-plugin/plugin.json` の hooks ブロック（全イベント・`${CLAUDE_PLUGIN_ROOT}`）。
Codex は repo root `hooks-codex.json`（対応イベントのみ・`./plugins/devkit/hooks/...` 相対）＋ `.codex-plugin/plugin.json` の `"hooks": "./hooks-codex.json"` 宣言。

**昇格候補**: 反復（他の Codex プラグイン作業で再利用）が確認できれば `authoring-plugins` の
`MANAGING-MULTI-PLUGIN.md` か CLAUDE.md「Codex プラグイン配布の注意点」表へ hook 配布規約として昇格。
