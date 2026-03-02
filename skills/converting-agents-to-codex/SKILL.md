---
name: converting-agents-to-codex
description: >-
  Converts Claude Code agent definitions (.md) to Codex multi-agent format (config.toml + agent .toml).
  Use when porting Claude Code agents to Codex CLI. Accepts a single agent file path or a folder path as argument.
  When a folder is given, uses Agent Teams API to process files in parallel (MAX 5 workers) for fast batch conversion.
  Detects existing entries in config.toml and agent .toml files; auto-handles diffs in batch mode.
  Always fetches latest spec from https://developers.openai.com/codex/multi-agent.
argument-hint: "<agent-file-or-folder-path>"
disable-model-invocation: true
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。


ARGUMENTS: $ARGUMENTS
