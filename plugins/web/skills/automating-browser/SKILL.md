---
name: automating-browser
description: |
  agent-browser CLI（Vercel Labs 製・Rust ネイティブ・CDP で Chrome を直接制御・デーモンに Node.js/Playwright 不要）によるブラウザ操作自動化。snapshot→ref ワークフロー、read（Chrome 起動なしで URL を markdown 取得）/chat（自然言語操作）/batch（連続実行）/mcp（MCP サーバー化）、セマンティックロケーター・状態永続化（storageState 互換 JSON）・認証 Vault・ネットワーク傍受に対応。
  Use when アプリの web 操作・ブラウザ自動化（スクレイピング、UI 操作フロー、認証永続化、フォーム送信、データ抽出）を行うとき。これらは本スキル（agent-browser CLI）を第一選択にする。
  住み分け: E2E テストスイートの設計・実装は web:testing-e2e-with-playwright、パフォーマンス計測/Lighthouse/詳細トレース等の診断は chrome-devtools MCP、ユーザーの既存 Chrome タブ/ログイン済みセッション操作は claude-in-chrome を使う。
context: fork
agent: general-purpose
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
