---
name: authoring-plugins
disable-model-invocation: false
description: >-
  Claude Code Plugin (Agent / Skill / Command / Hook) authoring guide covering
  the Agent Skills standard (agentskills.io) + Claude Code extensions,
  context: fork applicability matrix, name/description constraint validation,
  spec-freshness checks, source-to-skill conversion (Markdown/PDF/EPUB/URL),
  multi-plugin repository management (marketplace, Codex distribution, version sync),
  skill-change impact analysis on agents, cross-reference integrity,
  and the skill-improvement loop (IMPROVEMENT-INTAKE, USAGE-REVIEW).
  Use when creating, modifying, or reviewing plugin components,
  splitting or adding plugins in a multi-plugin repo,
  or processing skill-improvement proposals.
  For discovering and installing existing skills, use find-skills instead.
  For MCP protocol/server development, use lang:developing-mcp.
  For converting Claude Code agents to Codex, use converting-agents-to-codex.
  For codebase-wide automation recommendations, use recommending-automations.
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。

## 最新仕様の鮮度確認

- 確認日: 2026-07-02
- Agent Skills 標準: <https://agentskills.io/specification>
- Claude Code 拡張: <https://code.claude.com/docs/en/skills>

**作業開始時は必ず INSTRUCTIONS.md の Step 0「最新仕様確認」を実施し、仕様変更を検出した場合は判定マトリクスへの影響を評価してください。**
