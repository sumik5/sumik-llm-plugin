# LEARNINGS — sumik-claude-plugin

作業中に得た非自明な学び・調査結果の記録（capturing-learnings 形式）。

> 2026-07-13: 蓄積エントリ（LRN-20260625-001 〜 LRN-20260703-002）を全消費・削除済み。
> 恒久化先: authoring-plugins（HOOK-GUIDE.md / MANAGING-MULTI-PLUGIN.md / CONVERTING.md / INSTRUCTIONS.md）・
> repo CLAUDE.md（git 罠表・Codex 配布表）・RTK.md・Claude Code memory。
>
> 2026-07-15: 蓄積エントリ（LRN-20260713-001・LRN-20260713-002・LRN-20260714-001）を全消費・削除済み。
> 恒久化先: RTK.md（環境の罠表に symlink 罠を追記）・
> orchestrating-teams/INSTRUCTIONS.md（herdr Codex限定運用の優先順位を追記）・
> plugins/devkit/agents/*.md 24件 + plugins/exam/agents/exam-solver.md 1件（実測25件、`model: sonnet` → `model: claude-sonnet-5` へ実適用・grep実証済み）。
> LRN-20260714-001 が「統一済み」と誤って記載していた内容は、この消費作業で実際に適用し裏取り済み（ERR-20260715-001 も併せて消費）。

## [LRN-20260716-001] herdr `agent start --split` の分割対象は「現在フォーカスされているpane」（呼び出し元でも直前作成paneでもない）

- **type**: best_practice / knowledge_gap
- **発見経緯**: ユーザーから「subagentが親paneの下にどんどん積み重なって見づらい」と報告を受け、herdr 0.7.3 実機（本セッション自身が herdr pane `w4:p2` として稼働中）で `herdr agent start <name> --split down --no-focus` を実行し `herdr pane layout --current` で分割先を確認したところ、CLIを呼び出したpane（自分自身）でも直前に作ったpaneでもなく、**その時点でフォーカスされていたpane**が分割された。`herdr api schema --json` で socket API の `AgentStartParams` を確認すると `target_pane_id` フィールドが存在しない（`PaneSplitParams` にはある＝非対称）ことも確定させた。
- **回避策（実機で動作確認済み）**: `herdr agent focus <name>` はagent名から対象paneへ実フォーカスを移せる（`pane focus` CLIは `--direction` 相対移動のみで絶対pane_id指定がないため、これが唯一の代替手段）。複数体を「親の右→その下へ縦積み」で整列させるには、1体目は `--split right --no-focus`、2体目以降は直前のagent名を `agent focus` してから `--split down --no-focus` を繰り返し、最後に `herdr pane focus --direction left --current` で親へフォーカスを戻す（親|右列の2カラム構成なら "left" で一発）。
- **恒久化先**: `plugins/devkit/skills/operating-herdr/INSTRUCTIONS.md`（新規callout・新規レシピ「複数エージェントを整列よく起動する」・notes追記）、`plugins/devkit/skills/orchestrating-teams/references/TEAM-PATTERNS.md`・`WORKFLOW-GUIDE.md`（フォーカス制御なしの `--split right` 連打サンプルを修正）、`~/dotfiles/claude-code/rules/plugins-and-commands.md`・`~/dotfiles/codex/AGENTS.md`（該当箇所に一文追記）に反映済み。
- **Recurrence-Count**: 1（新規）
