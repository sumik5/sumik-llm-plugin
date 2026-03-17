---
name: building-ai-agents
disable-model-invocation: false
description: |
  AIエージェント構築ガイド（LangChain/LangGraph・Google ADK・リアルタイムマルチモーダル）。
  Use when building AI agents with LangChain, LangGraph, Google ADK, or Gemini Live API.
  フレームワーク選択、ツール定義、マルチエージェント、A2A、リアルタイム音声/動画を含む。
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。

## サブファイル一覧

### LangChain/LangGraph（`LC-` プレフィックス）

| ファイル | 内容 |
|---------|------|
| `references/LC-GUIDE.md` | LangChain/LangGraph 詳細ガイド（エコシステムマップ・判断フロー・モデル選択） |
| `references/LC-LANGCHAIN-CORE.md` | LCEL・PromptTemplate・Chain合成の基礎 |
| `references/LC-SUMMARIZATION.md` | MapReduce/Refine要約・LangGraphへの移行 |
| `references/LC-RAG-PIPELINE.md` | RAGパイプライン全体（ChromaDB〜高度RAG） |
| `references/LC-LANGGRAPH-AGENTS.md` | Tool calling・ReAct・マルチエージェント |
| `references/LC-MCP-INTEGRATION.md` | MCPサーバー構築・LangGraphからの消費 |
| `references/LC-PRODUCTION.md` | Memory・Guardrails・LangSmith・デプロイ |

### Google ADK（`ADK-` プレフィックス）

| ファイル | 内容 |
|---------|------|
| `references/ADK-GUIDE.md` | Google ADK 詳細ガイド（アーキテクチャ・判断基準・開発ワークフロー） |
| `references/ADK-AGENT-AND-TOOLS.md` | Agent分類体系・Tool設計・YAML Config・ベストプラクティス |
| `references/ADK-MULTI-AGENT-AND-A2A.md` | マルチAgent設計・A2Aプロトコル・Human-in-the-Loop |
| `references/ADK-RUNTIME-AND-STATE.md` | Runner・Session・State（4スコープ）・Artifact・Memory |
| `references/ADK-RAG-AND-GROUNDING.md` | RAGパイプライン・Corpus管理・Grounding 3方式 |
| `references/ADK-CODE-EXECUTION-AND-MODELS.md` | コード実行（4種）・LLMモデル・Flows & Planners |
| `references/ADK-GUARDRAILS-AND-STREAMING.md` | Callback 6種・ガードレール・SSEストリーミング |
| `references/ADK-UI-INTEGRATION.md` | AG-UI・CopilotKit・Streamlit・Dialogflow CX |
| `references/ADK-DEPLOYMENT-AND-OPERATIONS.md` | Cloud Run/Vertex AI/GKEデプロイ・CI/CD・コスト管理 |
| `references/ADK-SECURITY-AND-GOVERNANCE.md` | 脅威モデル・認証認可・Workload Identity・40項目チェックリスト |
| `references/ADK-LIVE-AGENT.md` | Live Agent API・LiveRunner・音声処理 |

### リアルタイムマルチモーダル（`RTM-` プレフィックス）

| ファイル | 内容 |
|---------|------|
| `references/RTM-GUIDE.md` | リアルタイムマルチモーダルAgent 詳細ガイド |
| `references/RTM-ARCHITECTURE.md` | Two-Server Skeleton・プロキシ設計パターン |
| `references/RTM-WEB-AUDIO-API.md` | AudioWorklet・AudioRecorder・AudioStreamer・AEC |
| `references/RTM-GEMINI-LIVE-API.md` | Live API接続・VAD・割り込み・セッション管理 |
| `references/RTM-VIDEO-INTEGRATION.md` | MediaHandler・フレームキャプチャ・マルチモーダル入力 |
| `references/RTM-FUNCTION-CALLING.md` | リアルタイムFunction Calling・ツール実行ループ |
| `references/RTM-DEPLOYMENT.md` | Cloud Run・Docker・モバイルUI設計 |
