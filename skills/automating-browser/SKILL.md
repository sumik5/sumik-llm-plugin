---
description: |
  Browser automation covering Playwright MCP, CLI agent, and E2E testing.
  Use when automating browser interactions, running E2E tests, or building browser-based workflows.
  Covers lightweight MCP automation, advanced agent scenarios (semantic locators, state persistence, network interception), and Playwright Test E2E suite design.
---

# Browser Automation

ブラウザ自動化の3つの柱: MCP軽量自動化、CLIエージェント、E2Eテスト。

## 使い分け

| ユースケース | 参照ファイル | 説明 |
|------------|------------|------|
| 基本的なブラウザ操作 | [PLAYWRIGHT-MCP.md](./PLAYWRIGHT-MCP.md) | Playwright MCPによる軽量自動化（ナビゲーション、フォーム入力、スクリーンショット） |
| 複雑なブラウザシナリオ | [BROWSER-AGENT.md](./BROWSER-AGENT.md) | CLIエージェントによる高度な自動化（セマンティックロケーター、認証永続化、ネットワーク傍受） |
| E2Eテスト設計・実装 | [E2E-TESTING.md](./E2E-TESTING.md) | Playwright Testによるテストスイート設計（ロケーター、フィクスチャ、CI/CD） |

## Playwright MCP

Microsoft Playwright MCPを使った軽量ブラウザ自動化。

| ファイル | 内容 |
|---------|------|
| [PLAYWRIGHT-MCP.md](./PLAYWRIGHT-MCP.md) | MCPツール概要と使い方 |
| [PLAYWRIGHT-COMMANDS.md](./PLAYWRIGHT-COMMANDS.md) | コマンドリファレンス |
| [PLAYWRIGHT-EXAMPLES.md](./PLAYWRIGHT-EXAMPLES.md) | 使用例 |

## Browser Agent

高度なブラウザ自動化エージェント。セマンティックロケーター、状態永続化、デバイスエミュレーション。

| ファイル | 内容 |
|---------|------|
| [BROWSER-AGENT.md](./BROWSER-AGENT.md) | エージェント概要と機能 |
| [AGENT-COMMANDS.md](./AGENT-COMMANDS.md) | コマンドリファレンス |
| [AGENT-EXAMPLES.md](./AGENT-EXAMPLES.md) | 使用例 |

## E2E Testing

Playwright TestによるE2Eテスト設計・実装ガイド。

| ファイル | 内容 |
|---------|------|
| [E2E-TESTING.md](./E2E-TESTING.md) | E2Eテスト概要とベストプラクティス |
| [E2E-FUNDAMENTALS.md](./E2E-FUNDAMENTALS.md) | 基礎概念 |
| [E2E-LOCATORS.md](./E2E-LOCATORS.md) | ロケーター戦略 |
| [E2E-FIXTURES-AND-POM.md](./E2E-FIXTURES-AND-POM.md) | フィクスチャとPage Object Model |
| [E2E-MOCKING-AND-EMULATION.md](./E2E-MOCKING-AND-EMULATION.md) | モッキングとエミュレーション |
| [E2E-RELIABILITY.md](./E2E-RELIABILITY.md) | テストの信頼性 |
| [E2E-CI-AND-PERFORMANCE.md](./E2E-CI-AND-PERFORMANCE.md) | CI/CDとパフォーマンス |
| [E2E-EXTENDING.md](./E2E-EXTENDING.md) | 拡張機能 |
| [E2E-BEYOND-E2E.md](./E2E-BEYOND-E2E.md) | E2E以外の活用 |
