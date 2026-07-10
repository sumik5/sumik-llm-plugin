# web

**Web・フロントエンド実装スキルのためのプラグイン**

---

## 概要

web は devkit と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。Next.js・React・フルスタック JavaScript・Web API・フロントエンド設計・Tailwind・Figma 実装・ブラウザ自動化・next-devtools・Vitest テスト・Playwright E2E テストといった Web/フロントエンド実装系スキルを集約します。devkit のタチコマ Agent がこれらのスキルを `web:<skill>` 修飾名で preload するため、devkit と常にセットでインストールされる前提です。

---

## インストール

### Claude Code

```bash
/plugin install web@sumik
```

### Codex

```bash
codex plugin marketplace add https://github.com/sumik5/sumik-llm-plugin.git --ref main
codex plugin add web@sumik-marketplace
```

---

## ディレクトリ構成

```
sumik-llm-plugin/                      # GitHub repo（Codex はここを git clone）
├── .agents/
│   └── plugins/
│       └── marketplace.json              # Codex marketplace manifest（web エントリを含む）
├── .cache/
│   └── sumik-marketplace/
│       └── web -> ../../plugins/web        # Codex marketplace から web plugin を指す symlink
└── plugins/
    └── web/                            # Claude Code プラグイン本体（skills-only）
        ├── .claude-plugin/
        │   └── plugin.json              # プラグインメタデータ（plugin 名 web / version 同期必須）
        ├── .codex-plugin/
        │   └── plugin.json              # Codex CLI プラグインマニフェスト（skills ./skills/・MCP なし）
        ├── README.md
        └── skills/                      # ナレッジスキル (13個)
```

---

## コンポーネント一覧

### Skills (13個)

| スキル | 説明 |
|--------|------|
| `developing-nextjs` | Next.js 16.x開発ガイド（App Router・Server Components・Cache Components・Turbopack・実践パターン集）。Route Segment・Parallel/Intercepting Routes・Prisma・Server Actions・キャッシュ戦略を含む。React固有は`developing-react`参照 |
| `developing-react` | React 19.x 開発ガイド（Internals・パフォーマンスルール・デザインパターン（Container/Presenter・HOC・Render Props・Headless等）・エラーハンドリング・アクセシビリティ（ARIA・フォーカス管理・キーボードナビゲーション）・状態管理（nuqs・Jotai・React Compiler）・アニメーション・RTLテスト・Storybook） |
| `developing-fullstack-javascript` | フルスタックJS開発（NestJS/Express・React・CI/CD・品質）＋JavaScript言語基礎（型・クロージャ・プロトタイプ・async/await・モジュール・メタプログラミング）を包括カバー。V8内部・イベントループ・Express 5 + Drizzle ORM CRUDも収録 |
| `developing-web-apis` | Web API開発統合ガイド（API設計ベストプラクティス・Spec First開発方法論・APIテスト戦略）。エンドポイント設計・HTTPスペック・バージョニング・セキュリティ・コントラクトテスト・自動化を網羅 |
| `choosing-api-styles` | APIスタイル選定・比較の意思決定ガイド（REST/GraphQL/gRPC/Webhook/WebSocket/メッセージング/Webフィードの7スタイル）。通信モード・プロトコル基盤(HTTP/1.1/2/3・QUIC)・スタイル別トレードオフ・6次元選定マトリクスと決定木を収録 |
| `building-nodejs-services` | Fastify による Node.js サービス/CLI/実プロジェクト構築（Fastifyコア: ルーティング/フック/プラグイン/スキーマ検証・Nodeランタイム内部: イベントループ/libuv/streams/clustering・REST実装・永続化: Mongoose/Sequelize/SQLite/Redis・認証フロー・SSR・メッセージング: RabbitMQ・CLIツール・外部データ統合/スクレイピング・メール/生成AI統合・scaffolding・品質チェックリスト、12リファレンスファイル） |
| `designing-frontend` | フロントエンド実装（shadcn/ui統合・オブジェクト指向UI設計（OOUI）：オブジェクト抽出・ビュー/ナビゲーション・レイアウトパターン・マイクロフロントエンドアーキテクチャ） |
| `styling-with-tailwind` | Tailwind CSSスタイリング方法論（v4プライマリ・ユーティリティファースト思想・セットアップ・モディファイア・コンポーネント設計・カスタマイズ・デザインシステム構築） |
| `implementing-design` | デザイン→コード変換総合スキル（汎用原則: デザインシステム統合・視覚的整合性・レスポンシブ・a11y ＋ Figma MCP: 全13ツール・基本/高度ワークフロー・Code Connect・デザイントークン同期・ビジュアル検証 ＋ Figma UIデザイン: ワイヤーフレーム→ハンドオフ・8ptグリッド・UIStack） |
| `automating-browser` | agent-browser CLI（Vercel Labs製・Rustネイティブ・CDP直結でChrome制御、デーモンにNode/Playwright不要）によるブラウザ操作自動化。snapshot→ref・セマンティックロケーター・状態永続化（state/auth vault）・ネットワーク傍受・read（Chrome起動なしURL→markdown）・chat（自然言語操作）・batch・mcp。アプリのweb操作の第一選択（E2Eは`testing-e2e-with-playwright`） |
| `using-next-devtools` | next-devtools MCP経由のNext.js開発統合ツール（診断・バージョンアップグレード・Cache Components最適化・自動エラー修正） |
| `testing-with-vitest` | Vitest 4.x特化の設定・移行・最適化ガイド（v3→v4破壊的変更・maxWorkers・test.projects・module runner・coverage刷新・Browser Mode・fixtures/test.extend・ライフサイクルフック・vi モック・型テスト・in-source testing）。テスト方法論全般は`devkit:testing-code`参照 |
| `testing-e2e-with-playwright` | Playwright E2Eテストの設計・実装・運用ガイド（`@playwright/test`・`playwright.config.*`検出時に自動ロード）。Playwright E2E固有のパターンに特化 |

---

## 依存関係メモ

devkit の Web/フロントエンド系タチコマ（tachikoma-fw-nextjs、tachikoma-fw-fullstack-js、tachikoma-fe-frontend、tachikoma-fe-figma-impl、tachikoma-qa-e2e-test、tachikoma-lang-go ほか）が web 提供スキルを `web:<skill>` 修飾名で preload します。とくに `web:testing-with-vitest` は tachikoma-qa-test が、`web:testing-e2e-with-playwright` は tachikoma-qa-e2e-test・tachikoma-fw-nextjs・tachikoma-fw-fullstack-js が preload します。このクロスプラグイン参照を成立させるため、web は devkit と**常に併設インストールされること**が前提です。web 単体ではこれらのタチコマのスキル preload が解決されません。
