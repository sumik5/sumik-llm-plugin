---
name: operating-herdr
description: >-
  herdr operations via the herdr CLI — a terminal-native agent multiplexer controlled over a local unix socket. Manage workspaces (project contexts), tabs (subcontexts), and panes (terminal splits); split, move, resize, and navigate panes and run commands; read another pane's output (visible / recent / recent-unwrapped); wait for output text (literal or regex) or an agent status (idle / working / blocked / done); spawn agents with `herdr agent start` and coordinate them (read / send / wait / attach); install lifecycle integration (`integration install claude|codex`) for authoritative agent status. Use when running inside herdr (HERDR_ENV=1) to orchestrate agents, dev servers, tests, or log streams across panes from the terminal. Guarded: if HERDR_ENV is not 1, do not control herdr panes — stop. For parallel Tachikoma team orchestration inside Claude Code, use orchestrating-teams instead. For generic tmux multiplexing outside herdr this skill does not apply.
compatibility: >-
  Requires the herdr CLI in PATH and HERDR_ENV=1 (running inside a herdr-managed pane).
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
