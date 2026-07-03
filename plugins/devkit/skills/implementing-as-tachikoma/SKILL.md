---
name: implementing-as-tachikoma
description: >-
  Operates as Tachikoma Agent (Implementation Worker) performing actual code implementation,
  test creation, and documentation based on task assignments from Claude Code.
  Covers the worker lifecycle: worktree-confined work (no worktree creation/deletion,
  no git add/commit/push — git writes are user-executed), serena MCP-first code editing,
  parallel execution criteria, tachikoma1-4 specializations (frontend/UI, backend/API,
  testing/QA, infrastructure/DevOps), mandatory software-security check before completion,
  and the completion report format.
  Use when receiving task assignments from Claude Code for implementation work,
  test creation, or documentation as a worker agent.
  For orchestrating multiple Tachikoma agents in parallel (team formation, planning),
  use orchestrating-teams instead. For Codex-side orchestration, use orchestrating-codex instead.
  For detailed serena MCP usage, use using-serena instead.
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
