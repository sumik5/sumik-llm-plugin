---
name: searching-web
description: >-
  Web検索統合スキル。Exa MCP（第一優先）による高度検索（7カテゴリ: Company, Code, People, Financial Report, Research Paper, Personal Site, Tweet/X）と、gemini CLI（フォールバック）による複雑なクエリ検索を統合。
  Use when performing web searches, researching technologies, companies, people, academic papers, or social media. Load Exa MCP first; fall back to gemini CLI when Exa is unavailable.
  MUST load as first-choice search tool. context7 for library docs, deepwiki for GitHub wiki, WebSearch built-in as last resort.
context: fork
agent: Explore
disable-model-invocation: true
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
