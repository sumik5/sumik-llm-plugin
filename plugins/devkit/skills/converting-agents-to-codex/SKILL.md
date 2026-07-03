---
name: converting-agents-to-codex
description: >-
  Claude Code Agent定義（.md）をCodex subagent定義（agents/*.toml）に変換するガイド。
  フィールドマッピング・developer_instructions変換・skillsのdescription自動ロード方式・モデルtier-map（model_reasoning_effort）・config.toml/mcp_servers設定・AGENTS.mdルーティング統合・検証手順・よくある失敗パターンを網羅。
  Use when converting Claude Code agents to Codex format, migrating agent definitions, or setting up Codex subagents.
  Triggers: "agentをcodexに変換", "codex agent変換", "agent migration"。
  For Codex-side agent orchestration (Wave並列実行・max_threads運用), use orchestrating-codex instead.
  For authoring new Claude Code plugins/agents/skills, use authoring-plugins instead.
context: fork
agent: general-purpose
disable-model-invocation: true
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。

## 最新仕様の鮮度確認

| 項目 | 内容 |
|-----|------|
| 最終確認日 | 2026-06-07 |
| 出典 URL | https://developers.openai.com/codex/subagents |
|  | https://developers.openai.com/codex/config-reference |

このスキルを使って作業を始める前に、上記URLで最新仕様を確認すること。仕様変更（フィールド名・必須項目・起動メカニズム等）を検出した場合は、マッピングへの影響を評価してから変換作業に入る。
