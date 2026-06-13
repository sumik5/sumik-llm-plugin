# ai

**AI/LLM/エージェント開発スキルのためのプラグイン**

---

## 概要

ai は devkit と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。GenAI デザインパターン・AI エージェント構築・Web AI 統合・promptfoo による LLM 評価/レッドチーミングといった AI/LLM 開発系スキルを集約します。devkit のタチコマ Agent がこれらのスキルを `ai:<skill>` 修飾名で preload するため、devkit と常にセットでインストールされる前提です。

---

## インストール

### Claude Code

```bash
/plugin install ai@sumik
```

### Codex

```bash
codex plugin marketplace add https://github.com/sumik5/sumik-llm-plugin.git --ref main
codex plugin add ai@sumik-marketplace
```

---

## ディレクトリ構成

```
sumik-llm-plugin/                      # GitHub repo（Codex はここを git clone）
├── .agents/
│   └── plugins/
│       └── marketplace.json              # Codex marketplace manifest（ai エントリを含む）
├── .cache/
│   └── sumik-marketplace/
│       └── ai -> ../../plugins/ai          # Codex marketplace から ai plugin を指す symlink
└── plugins/
    └── ai/                             # Claude Code プラグイン本体（skills-only）
        ├── .claude-plugin/
        │   └── plugin.json              # プラグインメタデータ（plugin 名 ai / version 同期必須）
        ├── .codex-plugin/
        │   └── plugin.json              # Codex CLI プラグインマニフェスト（skills ./skills/・MCP なし）
        ├── README.md
        └── skills/                      # ナレッジスキル (4個)
```

---

## コンポーネント一覧

### Skills (4個)

| スキル | 説明 |
|--------|------|
| `designing-genai-patterns` | 32のGenAIデザインパターン（コンテンツ制御・RAG・モデル能力拡張・信頼性・エージェント・デプロイ最適化・安全ガードレール）＋RAGシステム実装（11種データソース・チャンキング戦略・ベクトルストア）＋LLMOps/AgentOps（成熟度L0-2・レジストリ・メモリガバナンス）＋AI性能最適化（GPU/CUDA・LLM推論） |
| `building-ai-agents` | AIエージェント構築統合ガイド（LangChain/LangGraph: LCEL・ReAct・マルチエージェント・MCP統合・LangSmith評価 ＋ Google ADK: Agent分類・ツール設計・A2A・RAG・セキュリティ ＋ リアルタイムマルチモーダル: WebSocket・Web Audio API・Gemini Live API） |
| `integrating-ai-web-apps` | Vercel AI SDK + LangChain.js + MCPによるWebアプリAI統合（ストリーミングチャット・RAG・ツール呼び出し・構造化データ生成・React/Next.js連携） |
| `evaluating-with-promptfoo` | promptfooによるLLM評価・レッドチーミング（promptfooconfig.yaml設定・40+アサーション・プロバイダー・134+レッドチームプラグイン・コンプライアンスフレームワーク・CI/CD統合） |

---

## 依存関係メモ

devkit の AI/ML 系タチコマ（tachikoma-data-ai-ml、tachikoma-lang-python ほか）が ai 提供スキルを `ai:<skill>` 修飾名で preload します。このクロスプラグイン参照を成立させるため、ai は devkit と**常に併設インストールされること**が前提です。ai 単体ではこれらのタチコマのスキル preload が解決されません。
