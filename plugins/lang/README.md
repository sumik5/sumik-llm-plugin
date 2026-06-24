# lang

**言語スキル（Python・Go・Bash・データベース・MCP・アルゴリズム）のためのプラグイン**

---

## 概要

lang は devkit と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。Python・Go・Bash・データベース・MCP・アルゴリズムといった言語系スキルを集約します。Web・フロントエンド実装系スキル（React・Next.js・フルスタック JavaScript・Web API・next-devtools・フロントエンド設計・Figma 実装・Tailwind・ブラウザ自動化）は web プラグインへ分離されました。devkit のタチコマ Agent がこれらのスキルを `lang:<skill>` 修飾名で preload するため、devkit と常にセットでインストールされる前提です。

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
        └── skills/                      # ナレッジスキル (6個)
```

---

## コンポーネント一覧

### Skills (6個)

| スキル | 説明 |
|--------|------|
| `developing-python` | Python 3.13開発（Pythonベストプラクティス125項目・実践パターン50問・SEプロセス・Clean Architecture実践・Architecture Patterns: Repository/UoW/Aggregates/Domain Events/CQRS・DDD Tactical Patterns: Entity/Value Object/Aggregate Root） |
| `developing-go` | Go開発包括ガイド（クリーンコード・デザインパターン・並行処理詳細パターン・内部構造・スケジューラー・実践パターン7分野・nilハンドリング・テンプレートエンジン・34リファレンスファイル） |
| `developing-bash` | Bashシェルスクリプティング・自動化ガイド（基礎、制御構造、I/O、プロセス制御、テスト、セキュリティ、パターン） |
| `developing-databases` | DB設計・SQLアンチパターン・DB内部構造・PostgreSQL実践運用を統合した包括的データベース開発ガイド（リレーショナルDB設計・正規化・25のSQLアンチパターン・Bツリー/LSMストレージエンジン・分散システム・合意アルゴリズム・クエリチューニング・MVCC/VACUUM・バックアップ/PITR・レプリケーション/HA・監視） |
| `developing-mcp` | MCP (Model Context Protocol) サーバー/クライアント開発・アーキテクチャパターン・セキュリティ強化（脅威モデル・OIDC認証・LLM攻撃対策・エコシステム脅威・実装チェックリスト） |
| `solving-algorithms` | 競技プログラミング向けアルゴリズム・データ構造解法リファレンス（ソート・探索・木・グラフ・動的計画法・計算幾何・整数論を計算量解析と言語非依存実装で網羅）。問題タイプと入力サイズから最適アルゴリズムを選定し、古典的データ構造（スタック・キュー・ヒープ・BST・Union-Find）を実装。DB固有のデータ構造（Bツリー・LSM）は`developing-databases`参照 |

---

## 依存関係メモ

devkit の言語系タチコマ（tachikoma-lang-*、tachikoma-data-database ほか）が lang 提供スキルを `lang:<skill>` 修飾名で preload します。なお tachikoma-lang-go は web プラグインの `web:developing-web-apis` もクロスプラグインで preload します。このクロスプラグイン参照を成立させるため、lang は devkit と**常に併設インストールされること**が前提です。lang 単体ではこれらのタチコマのスキル preload が解決されません。
