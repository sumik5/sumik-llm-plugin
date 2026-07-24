# certificate

**資格・検定の学習支援（URL問題収集内蔵・Ankiフラッシュカード作成・教材OCR/翻訳変換）プラグイン**

---

## 概要

certificate は devkit と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。資格・検定の学習を支援する2つのスキルを提供します: 教材（EPUB/PDF/スキャン本）または certificate-exam サイトの URL（kentei-lab.com・studying/member.studying.jp・Whizlabs・shikaku-drill.com）から Anki フラッシュカードを一括作成する `creating-flashcards`、画像ベース EPUB のテキスト OCR 変換とローカル翻訳を行う `converting-content` です。`creating-flashcards` は URL 引数を渡すとホスト名から対象サイトを自動判定し、内蔵の収集ロジック（`scripts/collect-kentei-lab.sh`・`collect-studying.sh`・`collect-whizlabs.sh`・`collect-shikaku-drill.sh`）でブラウザ操作から問題文・選択肢・正解・解説を巡回取得して JSON を生成したうえで、専用ブリッジ（`kentei_lab_import.py`・`whizlabs_import.py`・`studying_import.py`・`shikaku_drill_import.py`）へそのまま渡します。AI による構造推測を省いて `検定試験::<検定名>::<級>::kentei-lab`（級を検出できない試験は `検定試験::<検定名>::kentei-lab`）・`資格試験::<コース名>::<クイズ名>::whizlabs`・`検定試験::<検定名>::<級>::studying::<カテゴリ名>::<科目名>`（級を検出できないコースは `検定試験::<検定名>::studying::<カテゴリ名>::<科目名>`）・`検定試験::<検定名>::<級>::shikaku-drill::<カテゴリ名>`（級を検出できない試験は `検定試験::<検定名>::shikaku-drill::<カテゴリ名>`。問題単位でカテゴリ別デッキへ自動振り分け）デッキへ直接一括登録できます（URL指定からAnki登録までを単一スキルの入り口で完結）。

スキルに加えて、`creating-flashcards` の自己改善コマンド `improve-creating-flashcards` を持ちます。Codex 配布は skills のみ（commands は Codex マニフェストに宣言しません）で、studio などと同じ subdirectory 方式です。

---

## インストール

### Claude Code

```bash
/plugin install certificate@sumik
```

### Codex

```bash
codex plugin add certificate@sumik-marketplace
```

---

## ディレクトリ構成

```
plugins/certificate/
├── .claude-plugin/
│   └── plugin.json          # Claude Code 用 manifest（plugin 名 certificate / version 同期必須）
├── .codex-plugin/
│   └── plugin.json          # Codex CLI 用 manifest（skills "./skills/"・MCP なし）
├── README.md
├── commands/
│   └── improve-creating-flashcards.md   # creating-flashcards の自己改善コマンド（Claude Code 専用）
└── skills/
    ├── creating-flashcards/             # Anki フラッシュカード一括作成スキル（ファイルパス/URL両対応。pdf-to-markdown・OCR系・4サイト分の収集スクリプト（collect-kentei-lab.sh/collect-studying.sh/collect-studying-choices.sh/collect-whizlabs.sh/collect-shikaku-drill.sh）・kentei-lab JSONブリッジ kentei_lab_import.py・whizlabs JSONブリッジ whizlabs_import.py・studying JSONブリッジ studying_import.py・shikaku-drill JSONブリッジ shikaku_drill_import.py を bundle）
    └── converting-content/              # 画像ベースEPUB→テキストOCR変換・LM Studio翻訳スキル
```

---

## コンポーネント一覧

### Skills (2個)

| スキル | 説明 |
|--------|------|
| `creating-flashcards` | EPUB/PDF/スキャン本、または certificate-exam サイトの URL（kentei-lab.com・studying/member.studying.jp・Whizlabs・shikaku-drill.com）、あるいは収集済み JSON から Anki フラッシュカードを Anki MCP Server または AnkiConnect API 経由で一括作成する（MCP設定・画像ベース教材の OCR: Apple Vision 優先/ローカル VLM フォールバック・デッキ/ノートタイプ管理・コンテンツ構造分析・HTML整形の一括インポート）。URL 引数はホスト名で自動判定され、内蔵の収集スクリプト（`scripts/collect-kentei-lab.sh`・`collect-studying.sh`・`collect-whizlabs.sh`・`collect-shikaku-drill.sh`）がブラウザ操作で JSON を生成したうえで、専用ブリッジ（`scripts/kentei_lab_import.py`・`scripts/whizlabs_import.py`・`scripts/studying_import.py`・`scripts/shikaku_drill_import.py`）が AI による構造推測（言語検出・構造分析・サンプル確認）をスキップして `検定試験::<検定名>::<級>::kentei-lab`（級を検出できない試験は `検定試験::<検定名>::kentei-lab`）・`資格試験::<コース名>::<クイズ名>::whizlabs`・`検定試験::<検定名>::<級>::studying::<カテゴリ名>::<科目名>`（級を検出できないコースは `検定試験::<検定名>::studying::<カテゴリ名>::<科目名>`）・`検定試験::<検定名>::<級>::shikaku-drill::<カテゴリ名>`（級を検出できない試験は `検定試験::<検定名>::shikaku-drill::<カテゴリ名>`。問題単位で自動振り分け）デッキへ直接一括登録する。詳細なサイト別の収集手順（前提ツール・認証・resume・トラブルシュート）は同スキルの `references/URL-COLLECTION.md` を参照。 |
| `converting-content` | 画像ベース EPUB をテキストへ OCR 変換し、LM Studio によるローカル英日翻訳を行う（pandoc・OCR ワークフローを含む）。 |

### Commands (1個)

| コマンド | 説明 |
|---------|------|
| `/improve-creating-flashcards` | `creating-flashcards` セッション後の知見（パーサー罠・OCRアーティファクト・構造パターン・判定マーカー表記揺れ等）を自動抽出し、スキル配下の参照ファイルへ追記してスキルを自己進化させる（Claude Code 専用）。 |

---

## 依存関係メモ

- **agent-browser CLI**（Rust ネイティブ・CDP 直結のブラウザ自動化 CLI）が必要です（`creating-flashcards` の URL 入力・4サイト共通）。未導入の場合は `web:automating-browser` スキル同梱の `scripts/install.sh` で導入してください。
- **agent-browser state save/load によるセッション永続化**が必要です（studying・Whizlabs の URL 入力）。Whizlabs はログイン必須かつログインフォームがモーダル型（専用ログインページなし）のプラットフォームで agent-browser の Auth Vault（`auth save`/`auth login`）が使用できないため、ログイン後のブラウザセッションを `agent-browser state save`/`state load` で保存・復元します。studying は通常のフォームページ（専用ログインページ `/login/`）のため Auth Vault を第一候補として試行し、機能しない場合に state save/load へフォールバックします。state ファイルはいずれもセッショントークンを含む秘匿情報のため、出力ディレクトリ配下に置きコミット対象にしません。shikaku-drill・kentei-lab は認証不要のためこの永続化は不要です。
- **jq**（JSON 整形・検証・最終成果物の組み立て）が必要です（`creating-flashcards` の URL 入力・4サイト共通）。収集結果は kentei-lab では `<slug>.json`（最終成果物）と `<slug>.jsonl`（進捗・resume の真実源）、whizlabs では `<course-slug>__<quiz-slug>.json`（最終成果物）と同名 `.jsonl`（進捗）の2ファイル、studying では `<course-slug>__<category-slug>__<subject-slug>.json`（最終成果物のみ・単一ページ読み取りで科目データが完結するため進捗サイドカーは出力しません）、shikaku-drill では `<slug>.json`（最終成果物）と `<slug>.jsonl`（進捗・サイト側resumeとのズレに対する防御）の2ファイルで出力されます。
- **Anki MCP Server または AnkiConnect API**（`creating-flashcards`）が必要です。Anki 本体とのカード一括インポートに使用します。
- **pdf-to-markdown バイナリ・4サイト分の収集スクリプト・JSONブリッジ**は `creating-flashcards/scripts/` に skill-bundled 済みです（plugin レベルの `scripts/` には依存しません）。同ディレクトリには URL 収集用の `collect-kentei-lab.sh`・`collect-studying.sh`・`collect-studying-choices.sh`・`collect-whizlabs.sh`・`collect-shikaku-drill.sh`、および収集済み JSON を Anki へ直接投入する専用ブリッジ `kentei_lab_import.py`・`whizlabs_import.py`・`studying_import.py`・`shikaku_drill_import.py` が常設されています。
- **ローカル OCR**: Apple Vision（`ocr-apple-vision`）を優先し、利用不可時はローカル VLM（`recognize-image-to-markdown` / `recognize-image.py`）にフォールバックします（`creating-flashcards`・`converting-content`）。
- **LM Studio**（ローカル LLM 翻訳）が必要です（`converting-content`）。
- kentei-lab.com は認証不要の公開無料サイトです。教育目的の節度ある利用（既定のリクエスト間隔・レート配慮）を前提としています。大規模な資格（問題数が多い試験）は取得に時間がかかるため、長時間実行を想定した運用（バックグラウンド実行・中断再開）に対応しています。
- Whizlabs は認証必須の有料コンテンツを含むプラットフォームです。ユーザー自身が正規に受講権限を持つコースの個人学習目的でのみ使用する前提です。resume は同一ブラウザプロセス内でのみ有効な弱い resume のため、クイズ単位での分割実行（長時間実行時は `run_in_background`）を推奨します。
- studying（スタディング）は認証必須の有料コンテンツを含むプラットフォームです。ユーザー自身が正規に受講権限を持つコースの個人学習目的でのみ使用する前提です。科目単位の一括表示ページ方式のため Whizlabs より大幅に高速に収集できますが、科目数が多いコースでは長時間実行を想定した運用（`run_in_background`）を推奨します。
- shikaku-drill.com は認証不要の公開無料サイトです（59資格対応）。教育目的の節度ある利用（既定のリクエスト間隔・レート配慮）を前提としています。SPA構造のため kentei-lab のような直接URL反復は使えず、ボタン操作の巡回＋進捗サイドカーによる二重resume防御（サイト側のlocalStorage resumeと自スキルのjsonlのズレを防御）で長時間実行（`run_in_background`・中断再開）に対応しています。
