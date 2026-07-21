---
name: recommending-automations
description: >-
  コードベースを解析し、Claude Code と Codex CLI 双方の自動化（hooks / subagents / skills /
  MCP servers / plugins）を推奨する読み取り専用スキル。検出したプラットフォーム
  （.claude/・CLAUDE.md / .codex/・AGENTS.md）を優先しつつ、各レコメンドに両クライアントの
  セットアップ手順を併記する。Use when the user asks for automation recommendations, wants to
  set up or optimize Claude Code or Codex for a project, asks what hooks / subagents / skills /
  MCP servers they should use, or mentions improving their AI coding assistant workflow.
  For authoring a specific plugin / skill / agent, use authoring-plugins instead.
  For converting an existing Claude agent to Codex, use converting-agents-to-codex.
license: Apache-2.0
compatibility: Designed for Claude Code and Codex CLI (Agent Skills standard)
metadata:
  version: "1.0"
  derived-from: "anthropics/claude-plugins-official (Apache-2.0)"
allowed-tools: Read Glob Grep Bash
---

本スキルは anthropics/claude-plugins-official の claude-automation-recommender（Apache-2.0）を
Claude Code＋Codex 両対応へ翻案したものです。

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。

## 最新仕様の鮮度確認

| 項目 | 内容 |
|-----|------|
| 最終確認日 | 2026-06-28 |
| Codex 設定リファレンス | https://learn.chatgpt.com/docs/config-file/config-reference |
| Codex サブエージェント仕様 | https://learn.chatgpt.com/docs/agent-configuration/subagents |
| Agent Skills 標準 | https://agentskills.io/specification |

このスキルを使って作業を始める前に、上記 URL で Codex 側の最新仕様を確認すること。
Codex はフィールド名・パスが進化中のため、変更を検出した場合は `references/platform-matrix.md`
を更新してから作業に入る（特に hooks イベント名・subagent TOML フィールド・skills パスは要確認）。
