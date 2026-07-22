# ERRORS — sumik-claude-plugin

作業中に調査・解決した非自明なエラーの記録（capturing-learnings 形式）。

> 2026-07-13: 蓄積エントリ（ERR-20260625-001 〜 ERR-20260711-001）を全消費・削除済み。
> 恒久化先: authoring-plugins（HOOK-GUIDE.md / MANAGING-MULTI-PLUGIN.md / CONVERTING.md / INSTRUCTIONS.md）・
> repo CLAUDE.md（git 罠表・Codex 配布表）・RTK.md・Claude Code memory
> （workflow-journal-identity / background-task-dies-across-session / no-unsolicited-claude-md-edits）。
> hook 実装系（notify-complete / learnings-error-detector / rtk-rewrite / hooks-codex.json）は修正適用済みを実ファイルで確認。
>
> 2026-07-15: 蓄積エントリ（ERR-20260713-001・ERR-20260713-002・ERR-20260715-001）を全消費・削除済み。
> ERR-20260713-001（pane_id 誤認）は operating-herdr/INSTRUCTIONS.md に既に反映済みを確認（削除のみ）。
> ERR-20260713-002（Codex確認UI停止）は operating-herdr/INSTRUCTIONS.md へ新規恒久化。
> ERR-20260715-001（model移行の未適用矛盾）は plugins/devkit/agents/*.md 24件 + plugins/exam/agents/exam-solver.md 1件（実測25件）へ
> `model: claude-sonnet-5` を実適用して解消（grep実証済み・LRN-20260714-001と同時消費）。

> 2026-07-22: 蓄積エントリ（ERR-20260721-001・ERR-20260719-001×2件・ERR-20260716-001・ERR-20260719-002）を
> 全消費・削除済み。恒久化先: repo CLAUDE.md（194/233/305/308行目のversion期待値をdevkit 14.12.2・
> lang 2.3.0・web 1.4.0・certificate 1.4.2へ実修正・同期チェックスクリプトでALL OK確認済み）・
> RTK.md「環境の罠と回避策」表（ロケール依存sort/uniq偽陽性を追記）。collecting-whizlabs-exams（strong分割
> パターン）・operating-herdr（permission-mode auto統一）は既に反映済みを実ファイルで確認。
> bash-triple-backtick-in-echo は一過性の学びのため恒久化不要と判断。
