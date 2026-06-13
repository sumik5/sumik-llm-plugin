# design

**UX・デザイン戦略スキルのためのプラグイン**

---

## 概要

design は devkit と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。UX デザイン・AI エクスペリエンス設計・デザイン思考プロセス・データビジュアライゼーション・デザインシステム構築・行動変容デザインといった UX/デザイン戦略系スキルを集約します。devkit のタチコマ Agent がこれらのスキルを `design:<skill>` 修飾名で preload するため、devkit と常にセットでインストールされる前提です。

---

## インストール

### Claude Code

```bash
/plugin install design@sumik
```

### Codex

```bash
codex plugin marketplace add https://github.com/sumik5/sumik-llm-plugin.git --ref main
codex plugin add design@sumik-marketplace
```

---

## ディレクトリ構成

```
sumik-llm-plugin/                      # GitHub repo（Codex はここを git clone）
├── .agents/
│   └── plugins/
│       └── marketplace.json              # Codex marketplace manifest（design エントリを含む）
├── .cache/
│   └── sumik-marketplace/
│       └── design -> ../../plugins/design  # Codex marketplace から design plugin を指す symlink
└── plugins/
    └── design/                         # Claude Code プラグイン本体（skills-only）
        ├── .claude-plugin/
        │   └── plugin.json              # プラグインメタデータ（plugin 名 design / version 同期必須）
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
| `designing-ux` | UI/UX・グラフィックデザイン・インターフェイス哲学・認知心理学基盤・UXエレメント5段階モデルを統合したデザイン総合スキル（UIデザインガイドライン・認知心理学基盤: 知覚バイアス/ゲシュタルト/記憶/フィッツの法則・グラフィック基礎: 造形/色彩/タイポグラフィ/レイアウト・Fluid Interfaces・モーション理論・5段階フレームワーク・Webデザイン機能性7軸/情緒性6軸・デザインコンセプト立案）。デザイン思考プロセスは`practicing-design-thinking`、AI体験設計は`designing-ai-experiences`参照 |
| `designing-ai-experiences` | AI体験（AIX）設計ガイド（Agentic UX・Copilotパターン・メンタルモデル・AIファーストインターフェース・Input/Computation/Output設計・フレーミング手法・倫理）。AI駆動プロダクトのUX・人間-AIインタラクション設計に使用。`designing-ux`から分離 |
| `practicing-design-thinking` | デザイン思考プロセス・UXリサーチ方法論（共感/定義/発想/プロトタイプ/テスト・ユーザーリサーチ・カスタマージャーニーマップ・ユーザビリティ評価・組織導入戦略・クリエイティブプロセスパターン）。`designing-ux`から分離 |
| `designing-data-visualizations` | データビジュアライゼーション原則（チャート選択・カラースケール・デザインベストプラクティス・ストーリーテリング） |
| `building-design-systems` | デザインシステム構築・運用・立ち上げ・浸透・Figma実装方法論（DS基礎・パターン分類（CEV命名）・組織戦略（合意形成・提案テンプレート）・UIパターンカタログ20+・Figmaバリアブル/デザイントークン階層・立ち上げ3ステップ・浸透3ステップ・更新通知フレームワーク・コンテンツ策定ガイド） |
| `applying-behavior-design` | 行動変容デザイン（CREATEファネル: Cue/Reaction/Evaluation/Ability/Timing・3戦略: チート/習慣/意識的行動）。ユーザー習慣の変容・エンゲージメント向上・有益な行動への誘導を目的とするプロダクト機能設計に使用 |

---

## 依存関係メモ

devkit のデザイン系タチコマ（tachikoma-fe-ux-design、tachikoma-fe-design-system、tachikoma-fe-frontend、tachikoma-str-product-mgr、tachikoma-doc-training ほか）が design 提供スキルを `design:<skill>` 修飾名で preload します。このクロスプラグイン参照を成立させるため、design は devkit と**常に併設インストールされること**が前提です。design 単体ではこれらのタチコマのスキル preload が解決されません。
