# studio

**コンテンツ制作・資料/スライド/図表/EPUB/LaTeX 生成のためのプラグイン**

---

## 概要

studio は devkit と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。スライド・PPTX・図表・フラッシュカード・LaTeX・コンテンツ生成・EPUB 圧縮/変換・カウントダウンアイコン・研修設計といったコンテンツ制作系スキルを集約し、開発ワークフロー特化の devkit と役割を分離します。両プラグインは常にセットでインストールされる前提です。

---

## インストール

### Claude Code

```bash
/plugin install studio@sumik
```

### Codex

```bash
codex plugin marketplace add https://github.com/sumik5/sumik-llm-plugin.git --ref main
codex plugin add studio@sumik-marketplace
```

---

## ディレクトリ構成

```
sumik-llm-plugin/                      # GitHub repo（Codex はここを git clone）
├── .agents/
│   └── plugins/
│       └── marketplace.json              # Codex marketplace manifest（studio エントリを含む）
├── .cache/
│   └── sumik-marketplace/
│       └── studio -> ../../plugins/studio # Codex marketplace から studio plugin を指す symlink
└── plugins/
    └── studio/                          # Claude Code プラグイン本体（コンテンツ制作）
        ├── .claude-plugin/
        │   └── plugin.json              # プラグインメタデータ（plugin 名 studio / version 同期必須）
        ├── .mcp.json                    # Claude 用 MCPサーバー設定（${CLAUDE_PLUGIN_ROOT}/bin/...）
        ├── .codex-plugin/
        │   └── plugin.json              # Codex CLI プラグインマニフェスト（skills ./skills/）
        ├── .mcp-codex.json              # Codex 用 MCPサーバー設定（command ./bin/... / cwd "."）
        ├── README.md
        ├── bin/                         # MCPサーバー起動ラッパー (npx-mise.sh)
        ├── commands/                    # スラッシュコマンド (2個)
        ├── scripts/                     # ヘルパースクリプト (pdf-to-markdown, epub-fix-cover.sh)
        └── skills/                      # ナレッジスキル (11個)
```

---

## コンポーネント一覧

### Skills (11個)

| スキル | 説明 |
|--------|------|
| `creating-slides` | HTMLスライド作成（slides repo 3層分離モデル: Engine/Theme/Content・16:9デッキ・テーマカスタマイズ・ソース素材変換。認知科学・ロジック構築・ストーリーテリング・聴衆分析・提案書構成術・デリバリーの9リファレンス＋国際学会/学術発表向け6リファレンスで品質担保） |
| `creating-pptx` | 箇条書き・メモ・素朴なスライドを「6つの構造」で組み直し、So What まで届くコンサル品質の1枚スライドを編集可能な PowerPoint（.pptx）とプレビュー画像（.png）で生成（手動呼び出し専用） |
| `gws-slides` | Google Slides 読み書き（gws CLI 経由でプレゼンテーション作成・編集・batchUpdate） |
| `creating-diagrams` | ダイアグラム作成ガイド（Mermaid 24種類: C4モデル/ER図/シーケンス図/フローチャート/ガントチャート ＋ draw.io MCP統合） |
| `creating-flashcards` | EPUB/PDF から Anki フラッシュカードを Anki MCP Server 経由で一括作成（MCP設定・デッキ/ノートタイプ管理・コンテンツ構造分析・HTML整形の一括インポート） |
| `compressing-epub-images` | EPUB 内画像（主にスキャン本の JPEG）を再エンコード・リサイズしてサイズ削減。実測サンプリングで予測サイズを算出し AskUserQuestion で圧縮レベルをユーザーに選ばせる対話型ワークフロー |
| `converting-content` | コンテンツ変換ガイド（画像ベース EPUB→テキスト OCR 変換・LM Studio 英日翻訳・pandoc・OCR ワークフロー） |
| `writing-latex` | LaTeX 文書作成（upLaTeX + dvipdfmx・minted コードハイライト日本語対応・数式・図表・表紙）。日本語学術レポート向け |
| `creating-content` | コンテンツ制作統合スキル（AIコピーライティング: 15テクニック・心理的トリガー ＋ AIデザインクリエイティブ: バナー/SNS/ポスター等の広告ビジュアル制作プロンプト設計） |
| `creating-countdown-icons` | カウントダウンアプリ用アプリアイコン（512×512 PNG）を絵文字・背景パレット選択の対話フローで生成。clean版とプレビュー版（白数字重ね）の2枚を出力 |
| `designing-training` | 研修設計・ファシリテーション方法論（ニーズ分析・KSA・ADDIE/Gagné・90/20/8法則・EATフレームワーク・脳科学原則・オンライン/ハイブリッド・スキルマップ・研修資料作成） |

### Commands (2個)

| コマンド | 説明 |
|---------|------|
| `/improve-creating-flashcards` | creating-flashcards セッション後の知見（パーサー罠・OCRアーティファクト・構造パターン）を自動抽出し CONTENT-DETECTION.md / CONTENT-BY-TYPE.md / CONTENT-COMMON.md / INSTRUCTIONS.md へ追記してスキルを自己進化させる |
| `/epub-fix-cover` | フォルダ/ファイル配下の EPUB/PDF を走査し表紙サムネイルが出ない原因を是正（EPUB:固定レイアウトを reflowable 化＋表紙正規化／PDF:Title メタ付与）。`--pdf-to-epub` でスキャン画像 PDF を「1ページ=1画面」EPUB へ、`--pdf-spread` で見開き EPUB3 fixed-layout へ再構成。是正済みはスキップ |

### Scripts (2個)

| スクリプト | 説明 |
|----------|------|
| `pdf-to-markdown` | PDF→Markdown 変換バイナリ（creating-flashcards の PDF 入力変換で使用・devkit からの複製） |
| `epub-fix-cover.sh` | EPUB/PDF の表紙是正・PDF→EPUB 再構成スクリプト（`/epub-fix-cover` コマンドから呼び出し） |

### MCP Servers (1個)

| サーバー | 用途 |
|---------|------|
| drawio | draw.io ダイアグラム作成・表示（creating-diagrams が利用） |

---

## 依存関係メモ

devkit のドキュメント系タチコマ 3 体（tachikoma-doc-slide / tachikoma-doc-training / tachikoma-doc-document）が studio 提供スキルを `studio:<skill>` 修飾名で preload します。このクロスプラグイン参照を成立させるため、studio は devkit と**常に併設インストールされること**が前提です。studio 単体ではこれらのタチコマのスキル preload が解決されません。
