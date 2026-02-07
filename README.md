# sumik-claude-plugin

**Claude Codeの開発ワークフローを強化する包括的なプラグインシステム**

---

## 概要

Claude Codeの開発効率を最大化するためのプラグイン。Agent、コマンド、スキル、フック、MCPサーバー統合を含み、並列実行モデル、トークン効率化、型安全性、セキュリティファーストのアプローチを実現します。

---

## インストール

```bash
claude plugin add sumik5/sumik-claude-plugin
```

---

## ディレクトリ構成

```
sumik-claude-plugin/
├── .claude-plugin/     # プラグインマニフェスト
│   ├── plugin.json     # プラグインメタデータ
│   └── marketplace.json
├── .mcp.json           # MCPサーバー設定
├── agents/             # Agent定義 (2体)
├── commands/           # スラッシュコマンド (8個)
├── hooks/              # イベントフック (3個)
├── scripts/            # ヘルパースクリプト
└── skills/             # ナレッジスキル (29個)
```

---

## コンポーネント一覧

### Agents (2体)

| Agent | モデル | 説明 |
|-------|--------|------|
| **タチコマ** (tachikoma) | Sonnet | 実装・実行Agent。フロント/バック/テスト等に適応。並列実行対応(1-4体) |
| **Serena Expert** (serena-expert) | Sonnet | /serenaコマンドを活用したトークン効率重視の開発Agent |

### Commands (8個)

| コマンド | 説明 |
|---------|------|
| `/serena` | トークン効率的な構造化開発 |
| `/serena-refresh` | Serena MCPデータ最新化 |
| `/reload` | CLAUDE.md再読み込み（compaction後のコンテキスト復元） |
| `/pull-request` | PR説明文の自動生成 |
| `/git-tag` | アノテーション付きGitタグ作成 |
| `/changelog` | CHANGELOG自動生成（Keep a Changelog形式） |
| `/generate-user-story` | ユーザーストーリー＋E2Eテストドキュメント生成 |
| `/e2e-chrome-devtools-mcp` | Chrome DevTools MCPによるE2Eテスト実行 |

### Skills (29個)

#### コア開発

| スキル | 説明 |
|--------|------|
| `implementing-as-tachikoma` | タチコマAgent運用ガイド |
| `using-serena` | Serena MCP活用 |
| `applying-solid-principles` | SOLID原則（全実装で必須） |
| `enforcing-type-safety` | 型安全性強制（any禁止） |
| `testing` | テストファースト（Vitest/RTL/Playwright） |
| `researching-libraries` | ライブラリ調査（車輪の再発明禁止） |
| `securing-code` | セキュアコーディング |

#### フレームワーク

| スキル | 説明 |
|--------|------|
| `developing-nextjs` | Next.js 16 / React 19 |
| `developing-go` | Go開発 |
| `developing-python` | Python 3.13開発 |
| `developing-fullstack-javascript` | フルスタックJS |
| `react-best-practices` | React性能最適化 |

#### フロントエンド・デザイン

| スキル | 説明 |
|--------|------|
| `design-guidelines` | UI/UXデザイン設計 |
| `designing-frontend` | フロントエンド実装 |
| `implement-design` | Figmaデザイン→コード |
| `storybook-guidelines` | Storybook story作成 |
| `using-shadcn` | shadcn/ui管理 |

#### ブラウザ自動化

| スキル | 説明 |
|--------|------|
| `agent-browser` | 高度なブラウザ自動化 |
| `playwright` | Playwright MCP |

#### インフラ・ツール

| スキル | 説明 |
|--------|------|
| `managing-docker` | Docker環境管理 |
| `writing-dockerfiles` | Dockerfile作成 |
| `using-next-devtools` | Next.js DevTools |
| `managing-git-worktrees` | Git Worktree管理 |

#### ドキュメント・品質

| スキル | 説明 |
|--------|------|
| `writing-technical-docs` | 技術ドキュメント（7つのC原則） |
| `writing-latex` | LaTeX文書作成 |
| `authoring-skills` | スキル作成ガイド |
| `converting-markdown-to-skill` | Markdown→スキル変換 |
| `searching-web` | Web検索（gemini） |
| `coderabbit` | CodeRabbitコードレビュー |

### Hooks (3個)

| フック | トリガー | 説明 |
|-------|---------|------|
| `format-on-save` | PostToolUse | ファイル保存時の自動フォーマット（TypeScript/JSON/Terraform等） |
| `notify-complete` | Stop | タスク完了時のデスクトップ通知 |
| `notify-waiting` | Stop | 待機状態の通知 |

### MCP Servers (10個)

| サーバー | 用途 |
|---------|------|
| serena | コード分析・編集・メモリ管理 |
| next-devtools | Next.js開発ツール |
| deepwiki | GitHub Wiki検索 |
| puppeteer | ブラウザ自動化 |
| chrome-devtools | Chrome DevTools統合 |
| mcp-pandoc | ドキュメント形式変換 |
| shadcn | shadcn/uiコンポーネント管理 |
| docker | Dockerコンテナ管理 |
| terraform | Terraformインフラ管理 |
| sequentialthinking | 複雑な問題の構造化思考 |

---

## 主な特徴

- **並列実行モデル**: タチコマ4体同時起動で独立タスクを並列処理
- **トークン効率化**: /serenaコマンドによる構造化開発
- **型安全性**: any/Any型の使用を厳格に禁止
- **セキュリティファースト**: 実装後のCodeGuard検証を必須化
- **自動フォーマット**: PostToolUseフックによるコード整形
- **Progressive Disclosure**: スキルをSKILL.md + 詳細ファイルに分離

---
