---
name: authoring-plugins
description: >-
  Claude Code and Codex plugin authoring guide for Agent, Skill, Command, and Hook
  components. Covers the Agent Skills standard (agentskills.io), Codex skill
  packaging (.agents/skills, .codex-plugin manifests, agents/openai.yaml),
  Claude Code extensions (context: fork, when_to_use, disable-model-invocation),
  name/description validation, spec-freshness checks, source-to-skill conversion,
  multi-plugin management, version sync, agent impact analysis, cross-reference
  integrity, and skill-improvement loops.
  Use when creating, modifying, or reviewing plugin components, auditing Codex
  skill compatibility, splitting or adding plugins in a multi-plugin repo, or
  processing skill-improvement proposals.
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
