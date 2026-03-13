---
name: building-langchain-agents
description: >-
  Guides LangChain/LangGraph agent development in Python covering LCEL chains,
  RAG pipelines (ChromaDB, advanced indexing, query transformations, RAG Fusion),
  LangGraph StateGraph agents (tool calling, ReAct, multi-agent Router/Supervisor),
  MCP server integration, and productionization (memory, guardrails, LangSmith).
  MUST load when langchain or langgraph is detected in requirements or pyproject.toml.
  For general RAG theory, use building-rag-systems. For JavaScript/Vercel AI SDK, use integrating-ai-web-apps.
  For MCP protocol internals, use developing-mcp. For Google ADK agents, use building-adk-agents.
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。

## サブファイル一覧

| ファイル | 内容 |
|---------|------|
| `INSTRUCTIONS.md` | エコシステムマップ・判断フロー・クイックスタート・相互参照 |
| `references/LANGCHAIN-CORE.md` | LCEL・PromptTemplate・Chain合成の基礎 |
| `references/SUMMARIZATION.md` | MapReduce/Refine要約・LangGraphへの移行 |
| `references/RAG-PIPELINE.md` | RAGパイプライン全体（ChromaDB〜高度RAG） |
| `references/LANGGRAPH-AGENTS.md` | Tool calling・ReAct・マルチエージェント |
| `references/MCP-INTEGRATION.md` | MCPサーバー構築・LangGraphからの消費 |
| `references/PRODUCTION.md` | Memory・Guardrails・LangSmith・デプロイ |
