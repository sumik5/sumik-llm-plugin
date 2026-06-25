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

---

## [LRN-20260625-002] Codex プラグインの「実アクティブパス」は `codex plugin list` の PATH 列で見る

**種別**: knowledge_gap（デバッグで判明）

**症状**: devkit を 14.2.0 へ更新後、`~/.codex/plugins/cache/sumik-marketplace/devkit/` を見ると最新が
`14.1.1` 止まりで hooks-codex.json も無く、「Codex 未更新」と誤判断した。

**真相**: `~/.codex/plugins/cache/...` は**陳腐化した別キャッシュ**で、Codex が実際に読むのは
`codex plugin list` の PATH 列が示すパス——本件では
`/Users/sumik/.codex/.tmp/marketplaces/sumik-marketplace/.cache/sumik-marketplace/devkit`
（= marketplace チェックアウト内の `.cache/<mp>/devkit → ../..` symlink = git チェックアウト root）。
これは push 済み main を直接指すため 14.2.0＋hooks-codex.json が即反映されていた。

**対処**: Codex プラグインの版・内容を確認する時は `~/.codex/plugins/cache` を信用せず、
`codex plugin list`（STATUS=installed,enabled / VERSION / **PATH**）で実体パスを特定し、
そのパスの `.codex-plugin/plugin.json`・`hooks-codex.json` を読む。関連: [[mcp-availability-from-session-not-just-config]]（config 単独で断定しない）。

**Codex で plugin hook を発火させる3条件**（本件で確立）:
1. プラグインが hooks-codex.json 同梱版（marketplace 経由で push 済み main が反映）
2. `~/.codex/config.toml` の `[features] hooks = true`（旧 `codex_hooks` は deprecated alias）
3. **trust 承認**（plugin 同梱 hook = 非管理 hook。次回 `codex` 起動時にプロンプト。自動化は
   `codex --dangerously-bypass-hook-trust` だが常用非推奨）
