---
name: searching-files-with-fff
description: >-
  High-performance file search via the fff MCP server (fff-mcp, frecency-ranked
  results with a persistent in-memory index). Covers the three fff tools — grep
  (file CONTENTS, the default), find_files (fuzzy file NAME search), multi_grep
  (OR across multiple literal patterns) — plus inline constraint syntax, core
  search rules (search bare identifiers, avoid regex, stop after 2 greps and
  read), DB persistence, and when to use fff vs serena / Glob / ripgrep. Use
  when searching code or files in a repository and the fff MCP server is
  available, or when deciding which file-search tool fits. For semantic
  symbol-level search/edit (definitions, references, rename) use serena; for
  plain path-pattern listing use Glob; for Claude Code plugin MCP configuration
  use authoring-plugins.
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
