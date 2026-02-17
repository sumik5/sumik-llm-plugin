---
description: |
  Browser Agent CLIによるブラウザ操作自動化（セマンティックロケーター、状態永続化、ネットワーク傍受）。
  Use when automating browser interactions via agent-browser CLI (NOT for E2E testing).
  E2Eテストは testing-e2e-with-playwright スキルを参照。
---

# Browser Agent CLI

Browser Agent CLIによるブラウザ操作自動化。セマンティックロケーター、状態永続化、ネットワーク傍受、デバイスエミュレーションをサポート。

## 使い分け

| ユースケース | 推奨スキル | 説明 |
|------------|----------|------|
| ブラウザ操作自動化 | `automating-browser` (このスキル) | Browser Agent CLIによる高度なブラウザ操作（スクレイピング、UI操作フロー、認証永続化） |
| E2Eテスト設計・実装 | `testing-e2e-with-playwright` | Playwright Testによるテストスイート設計（ロケーター、フィクスチャ、CI/CD） |

## Browser Agent

高度なブラウザ自動化エージェント。セマンティックロケーター、状態永続化、デバイスエミュレーション。

| ファイル | 内容 |
|---------|------|
| [BROWSER-AGENT.md](./references/BROWSER-AGENT.md) | エージェント概要と機能 |
| [AGENT-COMMANDS.md](./references/AGENT-COMMANDS.md) | コマンドリファレンス |
| [AGENT-EXAMPLES.md](./references/AGENT-EXAMPLES.md) | 使用例 |
