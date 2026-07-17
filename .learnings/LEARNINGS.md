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

## [LRN-20260717-001] herdr の Claude Code/Codex `integration install` は lifecycle authority にならず、常に screen-manifest 依存のまま

- **type**: knowledge_gap / best_practice
- **発見経緯**: 「親 herdr が子 pane の終了を検知できない」報告を受け、herdr 公式ドキュメント（https://herdr.dev/docs/agents/ ）を WebFetch で直接調査。原文引用: "Claude Code, Codex, GitHub Copilot CLI, Droid, Qoder CLI, and Cursor Agent CLI integrations are intentionally not lifecycle authorities. They provide native session identity for restore, but their hooks do not cover the whole lifecycle."。実機の `~/.claude/hooks/herdr-agent-state.sh`（herdr integration install が生成）を読み、`case "$action" in session) ;; *) exit 0 ;; esac` かつ `settings.json` の hook 登録が `SessionStart` のみであることを確認し、Stop/完了系イベントへの報告が一切ないことを裏取りした。二次情報（ブログ等のWebSearch要約）には「Claude Code integration が completion state を報告する」という逆の記述があったが、公式ドキュメントの原文引用と実機のスクリプト実体の両方で反証済み。二次情報より一次情報（公式docs + 実機ファイル）を優先すべき好例。
- **対処**: devkit プラグインの Stop hook `plugins/devkit/hooks/notify-complete.sh`（Claude Code/Codex 共通で実行される）に、`HERDR_ENV=1` かつ `HERDR_PANE_ID` がある場合のみ `herdr pane report-agent` で能動的に完了報告するロジックを追加（v14.11.0）。screen-manifest の受動的推測を待たず親が即座に検知できるようになった。
- **恒久化先**: `plugins/devkit/skills/operating-herdr/INSTRUCTIONS.md`（Step 0 新設・herdr integration 節訂正・「検知遅延への対処」節新設）・`plugins/devkit/hooks/notify-complete.sh`・`README.md` に反映済み（コミット 6cc3526）。
- **Recurrence-Count**: 1（新規）

## [LRN-20260717-002] dotfiles管理下のファイルは外部ツール(herdr integration install等)によってsymlinkから実体ファイルへ静かに置き換わることがある

- **type**: knowledge_gap
- **発見経緯**: `~/.claude/settings.json` と `~/.claude/hooks/` を編集しようとして `readlink` で確認したところ、symlink ではなく実体ファイル/実ディレクトリになっていた。dotfiles 側の `settings.json` は `hooks: {}` で内容も 20 項目以上古く（enabledPlugins・theme・editorMode・defaultMode 等）、実体ファイルとの乖離が大きかった。他の項目（CLAUDE.md・rules・statusline.*）は正しく symlink のまま維持されていた。原因は特定できていないが、`herdr integration install` や Claude Code 自体の設定書き込み（atomic write でsymlinkを実ファイルに置換するツールがある）が疑われる。
- **対処**: 実体ファイルの内容を dotfiles 側へコピーしてから symlink を復元（バックアップを取った上で実施）。`~/.claude/hooks/` は herdr が直接管理・上書きするファイル(`herdr-agent-state.sh`)を含むため、symlink 化せずそのまま残す方針とし、`symlink.sh` にコメントで理由を明記した。
- **予防策**: dotfiles 配下のファイルを編集する前は必ず `readlink` で symlink であることを確認する習慣が必要（実体化に気づかず dotfiles 側だけ編集すると、変更が反映されないまま気づかない）。
- **恒久化先**: `~/dotfiles/claude-code/settings.json`・`~/dotfiles/claude-code/symlink.sh`（コミット e4f790b）。`RTK.md`「環境の罠と回避策」表への追記は未実施（ユーザー確認事項として完了報告で提案）。
- **Recurrence-Count**: 1（新規）
