# product

**プロダクトマネジメント・要件定義スキルのためのプラグイン**

---

## 概要

product は devkit と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。PRD・ロードマップ・優先順位付け・AARRR 海賊指標・A/B テスト・PLG（プロダクトレッドグロース）といったプロダクトマネジメント実践と、ユーザーストーリー作成・受入基準・ストーリー分割といった要件定義スキルを集約します。devkit のタチコマ Agent がこれらのスキルを `product:<skill>` 修飾名で preload するため、devkit と常にセットでインストールされる前提です。

---

## インストール

### Claude Code

```bash
/plugin install product@sumik
```

### Codex

```bash
codex plugin marketplace add https://github.com/sumik5/sumik-llm-plugin.git --ref main
codex plugin add product@sumik-marketplace
```

---

## ディレクトリ構成

```
sumik-llm-plugin/                      # GitHub repo（Codex はここを git clone）
├── .agents/
│   └── plugins/
│       └── marketplace.json              # Codex marketplace manifest（product エントリを含む）
├── .cache/
│   └── sumik-marketplace/
│       └── product -> ../../plugins/product  # Codex marketplace から product plugin を指す symlink
└── plugins/
    └── product/                       # Claude Code プラグイン本体（skills-only）
        ├── .claude-plugin/
        │   └── plugin.json              # プラグインメタデータ（plugin 名 product / version 同期必須）
        ├── .codex-plugin/
        │   └── plugin.json              # Codex CLI プラグインマニフェスト（skills ./skills/・MCP なし）
        ├── README.md
        └── skills/                      # ナレッジスキル (2個)
```

---

## コンポーネント一覧

### Skills (2個)

| スキル | 説明 |
|--------|------|
| `practicing-product-management` | プロダクトマネジメント総合ガイド（基礎・AIプロダクト・A/Bテスト・成長戦略・GPM・PLG・カスタマーサクセス・Claude Code PM活用）。AARRR海賊指標、AIプロダクトライフサイクル、MLプロダクト化、AI統合戦略、オンライン実験設計、PM調査パターン、GPM実践、リテンション戦略、拡張収益を含む |
| `writing-user-stories` | ソフトウェアプロジェクト向けの効果的なユーザーストーリー作成ガイド（ストーリーテンプレート As a.../I want.../So that...・よくある失敗・技術要求からストーリーへの変換・受入基準の書き方・ストーリー分割テクニック）。ユーザーストーリー作成・技術要求のストーリー化・バックログ品質改善時に使用 |

---

## 依存関係メモ

devkit のプロダクトマネジメント系タチコマ（tachikoma-str-product-mgr）が product 提供スキルを `product:<skill>` 修飾名で preload します。このクロスプラグイン参照を成立させるため、product は devkit と**常に併設インストールされること**が前提です。product 単体ではこのタチコマのスキル preload が解決されません。
