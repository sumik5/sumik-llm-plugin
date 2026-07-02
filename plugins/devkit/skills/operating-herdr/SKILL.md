---
name: operating-herdr
description: >-
  herdr operations via the herdr CLI — a terminal-native agent multiplexer controlled over a local unix socket. Manage workspaces (project contexts), tabs (subcontexts), and panes (terminal splits); split panes and run commands; read another pane's output (visible / recent / recent-unwrapped); wait for output text (literal or regex) or for an agent to reach a status (idle / working / blocked / done); spawn and coordinate sibling agents; send text and keys. Use when running inside herdr (HERDR_ENV=1) to orchestrate multiple agents, dev servers, tests, or log streams across panes from the terminal, or to inspect and coordinate with neighbor panes. Guarded: if HERDR_ENV is not 1, do not control herdr panes — stop. For parallel Tachikoma team orchestration inside Claude Code, use orchestrating-teams instead. For generic tmux multiplexing outside herdr this skill does not apply.
compatibility: >-
  Requires the herdr CLI in PATH and HERDR_ENV=1 (running inside a herdr-managed pane).
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
