---
name: operating-herdr
description: >-
  herdr operations via the herdr CLI — a terminal-native agent multiplexer over a local unix socket. Manage workspaces/tabs/panes; split, move, resize, navigate, and run commands; read pane/agent output (visible/recent/recent-unwrapped/detection); wait for output text (`pane wait-output`) or agent status (`agent wait --until` idle/working/blocked/done/unknown); spawn agents via `pane split` + `agent start --kind <kind> --pane <id>` and coordinate them (read/prompt/send-keys/wait/attach); manage Git worktrees (`herdr worktree`) and raw terminal streams (`herdr terminal`); install lifecycle integration for authoritative status where supported (Claude Code/Codex stay screen-manifest-based). Use when running inside herdr (HERDR_ENV=1) to orchestrate agents, dev servers, tests, or log streams across panes. Guarded: stop if HERDR_ENV is not 1. For parallel Tachikoma team orchestration inside Claude Code, use orchestrating-teams instead. For generic tmux multiplexing outside herdr this skill does not apply.
compatibility: >-
  Requires the herdr CLI in PATH and HERDR_ENV=1 (running inside a herdr-managed pane).
metadata:
  herdr-version: "0.8.0"
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。

## herdr 公式ドキュメントの鮮度確認

- 確認日: 2026-08-06
- herdr 公式ドキュメント: <https://herdr.dev/docs/>
- 🔴 herdr 0.7.4→0.7.5（2026-07-21リリース）で `agent start` / `agent wait` / `agent send` の体系が破壊的に変更されたことを実機の `--help` 出力で確認済み。詳細は INSTRUCTIONS.md 参照。
- 🔴 herdr 0.7.5→0.8.0で `herdr worktree`（Git worktree 連動 workspace 管理）・`herdr terminal`（raw terminal ストリーム直結）の2名前空間が新規追加。`pane read`/`agent read` の `--source` は両方とも `detection` 対応で統一（従来の「pane read は detection 非対応」という記載は誤りだったため訂正）。`pane move` に `--target-pane`/`--tab-label` が追加。詳細は INSTRUCTIONS.md 参照。

**herdr の調査・トラブルシューティングを行う前は必ず INSTRUCTIONS.md の Step 0「herdr 公式ドキュメント確認」を実施してください。**
