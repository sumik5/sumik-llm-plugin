---
name: testing-with-vitest
description: >-
  Vitest 4.x specialized testing guide covering the test runner core: v3 to v4 migration and breaking changes (maxWorkers, test.projects, module runner, coverage overhaul), configuration (environments, coverage v8/istanbul, reporters), CLI and test filtering/tags, parallelism and performance (pools, sharding), Browser Mode (stable in v4, visual regression), fixtures and test context (test.extend), lifecycle hooks (aroundEach/aroundAll, globalSetup), mocking (vi API, modules, timers, MSW), matchers, type testing, and in-source testing. Use when package.json contains vitest or vitest.config.* is present, or when configuring, migrating, or optimizing Vitest. For framework-agnostic test methodology (TDD, AAA, test pyramid, four pillars, anti-patterns), use testing-code. For React Testing Library and React component testing, use developing-react. For Playwright E2E, use testing-e2e-with-playwright.
---

# testing-with-vitest

Vitest 4.x（v4.1.7）の設定・移行・最適化に特化したガイド。
Node.js >= 20、Vite >= 6 を要件とする v4 の全領域を網羅する。

## 詳細ガイド

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。

## 主要リファレンス

| リファレンス | 内容 |
|---|---|
| [VITEST-V4-MIGRATION.md](./references/VITEST-V4-MIGRATION.md) | v3 → v4 の破壊的変更・移行手順（maxWorkers、test.projects、module runner など） |
| [VITEST-CONFIG.md](./references/VITEST-CONFIG.md) | 設定オプション詳細（coverage、environments、reporters、matchers、in-source testing） |
| [VITEST-CLI.md](./references/VITEST-CLI.md) | CLI フラグ・フィルタリング・デバッグワークフロー |
| [VITEST-PROJECTS-PERFORMANCE.md](./references/VITEST-PROJECTS-PERFORMANCE.md) | test.projects / モノレポ構成・parallelism・sharding |
| [VITEST-BROWSER-MODE.md](./references/VITEST-BROWSER-MODE.md) | Browser Mode（v4 で stable）・ビジュアルリグレッション |
| [VITEST-FIXTURES.md](./references/VITEST-FIXTURES.md) | fixtures と test context（test.extend builder、スコープ、test.override） |
| [VITEST-LIFECYCLE.md](./references/VITEST-LIFECYCLE.md) | ライフサイクルフック（aroundEach/aroundAll、globalSetup、provide/inject） |
| [VITEST-APIS.md](./references/VITEST-APIS.md) | expect / matchers API リファレンス |
| [MOCKING.md](./references/MOCKING.md) | モック戦略（vi API、モジュール、タイマー、MSW）v4 セマンティクス対応 |

## 関連スキル

- **testing-code** — TDD・AAA パターン・テスト設計方法論など、フレームワーク非依存のテスト基礎
- **developing-react** — React Testing Library・React コンポーネントテスト
- **testing-e2e-with-playwright** — Playwright による E2E テスト
