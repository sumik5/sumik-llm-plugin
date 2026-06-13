# lang

**言語・フレームワーク・フロントエンド実装スキルのためのプラグイン**

---

## 概要

lang は devkit と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。Python・Go・Bash・React・Next.js・フルスタック JavaScript・データベース・Web API・MCP・next-devtools・フロントエンド設計・Figma 実装・Tailwind・ブラウザ自動化といった言語/フレームワーク/フロントエンド実装系スキルを集約します。devkit のタチコマ Agent がこれらのスキルを `lang:<skill>` 修飾名で preload するため、devkit と常にセットでインストールされる前提です。

---

## インストール

### Claude Code

```bash
/plugin install lang@sumik
```

### Codex

```bash
codex plugin marketplace add https://github.com/sumik5/sumik-llm-plugin.git --ref main
codex plugin add lang@sumik-marketplace
```

---

## ディレクトリ構成

```
sumik-llm-plugin/                      # GitHub repo（Codex はここを git clone）
├── .agents/
│   └── plugins/
│       └── marketplace.json              # Codex marketplace manifest（lang エントリを含む）
├── .cache/
│   └── sumik-marketplace/
│       └── lang -> ../../plugins/lang      # Codex marketplace から lang plugin を指す symlink
└── plugins/
    └── lang/                           # Claude Code プラグイン本体（skills-only）
        ├── .claude-plugin/
        │   └── plugin.json              # プラグインメタデータ（plugin 名 lang / version 同期必須）
        ├── .codex-plugin/
        │   └── plugin.json              # Codex CLI プラグインマニフェスト（skills ./skills/・MCP なし）
        ├── README.md
        └── skills/                      # ナレッジスキル (14個)
```

---

## コンポーネント一覧

### Skills (14個)

| スキル | 説明 |
|--------|------|
| `developing-python` | Python 3.13開発（Pythonベストプラクティス125項目・実践パターン50問・SEプロセス・Clean Architecture実践・Architecture Patterns: Repository/UoW/Aggregates/Domain Events/CQRS・DDD Tactical Patterns: Entity/Value Object/Aggregate Root） |
| `developing-go` | Go開発包括ガイド（クリーンコード・デザインパターン・並行処理詳細パターン・内部構造・スケジューラー・実践パターン7分野・nilハンドリング・テンプレートエンジン・34リファレンスファイル） |
| `developing-bash` | Bashシェルスクリプティング・自動化ガイド（基礎、制御構造、I/O、プロセス制御、テスト、セキュリティ、パターン） |
| `developing-react` | React 19.x 開発ガイド（Internals・パフォーマンスルール・デザインパターン（Container/Presenter・HOC・Render Props・Headless等）・エラーハンドリング・アクセシビリティ（ARIA・フォーカス管理・キーボードナビゲーション）・状態管理（nuqs・Jotai・React Compiler）・アニメーション・RTLテスト・Storybook） |
| `developing-nextjs` | Next.js 16.x開発ガイド（App Router・Server Components・Cache Components・Turbopack・実践パターン集）。Route Segment・Parallel/Intercepting Routes・Prisma・Server Actions・キャッシュ戦略を含む。React固有は`developing-react`参照 |
| `developing-fullstack-javascript` | フルスタックJS開発（NestJS/Express・React・CI/CD・品質）＋JavaScript言語基礎（型・クロージャ・プロトタイプ・async/await・モジュール・メタプログラミング）を包括カバー。V8内部・イベントループ・Express 5 + Drizzle ORM CRUDも収録 |
| `developing-databases` | DB設計・SQLアンチパターン・DB内部構造・PostgreSQL実践運用を統合した包括的データベース開発ガイド（リレーショナルDB設計・正規化・25のSQLアンチパターン・Bツリー/LSMストレージエンジン・分散システム・合意アルゴリズム・クエリチューニング・MVCC/VACUUM・バックアップ/PITR・レプリケーション/HA・監視） |
| `developing-web-apis` | Web API開発統合ガイド（API設計ベストプラクティス・Spec First開発方法論・APIテスト戦略）。エンドポイント設計・HTTPスペック・バージョニング・セキュリティ・コントラクトテスト・自動化を網羅 |
| `developing-mcp` | MCP (Model Context Protocol) サーバー/クライアント開発・アーキテクチャパターン・セキュリティ強化（脅威モデル・OIDC認証・LLM攻撃対策・エコシステム脅威・実装チェックリスト） |
| `using-next-devtools` | next-devtools MCP経由のNext.js開発統合ツール（診断・バージョンアップグレード・Cache Components最適化・自動エラー修正） |
| `designing-frontend` | フロントエンド実装（shadcn/ui統合・オブジェクト指向UI設計（OOUI）：オブジェクト抽出・ビュー/ナビゲーション・レイアウトパターン・マイクロフロントエンドアーキテクチャ） |
| `implementing-design` | デザイン→コード変換総合スキル（汎用原則: デザインシステム統合・視覚的整合性・レスポンシブ・a11y ＋ Figma MCP: 全13ツール・基本/高度ワークフロー・Code Connect・デザイントークン同期・ビジュアル検証 ＋ Figma UIデザイン: ワイヤーフレーム→ハンドオフ・8ptグリッド・UIStack） |
| `styling-with-tailwind` | Tailwind CSSスタイリング方法論（v4プライマリ・ユーティリティファースト思想・セットアップ・モディファイア・コンポーネント設計・カスタマイズ・デザインシステム構築） |
| `automating-browser` | Browser Agent CLIによるブラウザ操作自動化（セマンティックロケーター、状態永続化、ネットワーク傍受） |

---

## 依存関係メモ

devkit の言語/フレームワーク/フロントエンド系タチコマ（tachikoma-lang-*、tachikoma-fw-nextjs/fullstack-js、tachikoma-fe-frontend/figma-impl、tachikoma-data-database、tachikoma-qa-e2e-test、tachikoma-data-ai-ml ほか）が lang 提供スキルを `lang:<skill>` 修飾名で preload します。このクロスプラグイン参照を成立させるため、lang は devkit と**常に併設インストールされること**が前提です。lang 単体ではこれらのタチコマのスキル preload が解決されません。
