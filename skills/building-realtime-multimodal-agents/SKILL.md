---
name: building-realtime-multimodal-agents
description: >-
  Real-time multimodal AI agent architecture with WebSocket streaming, Web Audio API, and Gemini Live API.
  Use when building live voice/video AI applications with bidirectional streaming.
  Covers proxy server design, AudioWorklet processing, VAD, interruption handling,
  video frame capture, real-time function calling, Cloud Run deployment, and mobile-first UI.
---

# リアルタイムマルチモーダルAgentの構築

このスキルは、WebSocket双方向ストリーミング・Web Audio API・Gemini Live APIを組み合わせた、リアルタイムマルチモーダルAIエージェントの設計・実装をガイドする。

## 詳細ガイド

実装の詳細は [INSTRUCTIONS.md](./INSTRUCTIONS.md) を参照。

## リファレンス一覧

| ファイル | 内容 |
|---------|------|
| [ARCHITECTURE.md](./references/ARCHITECTURE.md) | Two-Server Skeleton・プロキシ設計パターン |
| [WEB-AUDIO-API.md](./references/WEB-AUDIO-API.md) | AudioWorklet・AudioRecorder・AudioStreamer・AEC |
| [GEMINI-LIVE-API.md](./references/GEMINI-LIVE-API.md) | Live API接続・VAD・割り込み・セッション管理 |
| [VIDEO-INTEGRATION.md](./references/VIDEO-INTEGRATION.md) | MediaHandler・フレームキャプチャ・マルチモーダル入力 |
| [FUNCTION-CALLING.md](./references/FUNCTION-CALLING.md) | リアルタイムFunction Calling・ツール実行ループ |
| [DEPLOYMENT.md](./references/DEPLOYMENT.md) | Cloud Run・Docker・モバイルUI設計 |
