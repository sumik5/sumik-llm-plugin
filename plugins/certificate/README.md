# certificate

**資格・検定の学習支援（kentei-lab問題収集・Ankiフラッシュカード作成・教材OCR/翻訳変換）プラグイン**

---

## 概要

certificate は devkit と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。資格・検定の学習を支援する5つのスキルを提供します: kentei-lab.com の資格・検定 URL から全問題（問題文・選択肢・正解・解説）を巡回取得して 1 資格 1 JSON ファイルへ保存する `collecting-kentei-lab-exams`、Whizlabs のコース practice test 一覧 URL から配下の全クイズ（問題文・選択肢・正解・解説・参考資料）を practice mode で巡回取得して 1 クイズ 1 JSON ファイルへ保存する `collecting-whizlabs-exams`、studying（スタディング）のコースレッスン一覧 URL から配下の「スマート問題集」「セレクト過去問集（学科試験対策・実技試験対策）」の全問題（問題文・選択肢・正解・解説）を科目単位で取得して 1 科目 1 JSON ファイルへ保存する `collecting-studying-exams`、教材（EPUB/PDF/スキャン本）から Anki フラッシュカードを一括作成する `creating-flashcards`、画像ベース EPUB のテキスト OCR 変換とローカル翻訳を行う `converting-content` です。`collecting-kentei-lab-exams` の JSON 出力は `creating-flashcards` の専用ブリッジ `kentei_lab_import.py` に、`collecting-whizlabs-exams` の JSON 出力は専用ブリッジ `whizlabs_import.py` に、`collecting-studying-exams` の JSON 出力は専用ブリッジ `studying_import.py` にそれぞれそのまま渡せ、AI による構造推測を省いて `検定試験::<検定名>::<級>::kentei-lab`（級を検出できない試験は `検定試験::<検定名>::kentei-lab`）・`資格試験::<コース名>::<クイズ名>::whizlabs`・`資格試験::<コース名>::<カテゴリ名>::<科目名>::studying` デッキへ直接一括登録できます（収集から Anki 登録までの連携強化）。

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
    ├── collecting-kentei-lab-exams/     # kentei-lab 問題収集スキル（JSON出力の収集スクリプトを bundle）
    ├── collecting-whizlabs-exams/       # Whizlabs 問題収集スキル（JSON出力の収集スクリプト + agent-browser state save/load 連携を bundle）
    ├── collecting-studying-exams/       # studying 問題収集スキル（科目単位一括表示ページの収集スクリプト + agent-browser Auth Vault/state save/load 連携を bundle）
    ├── creating-flashcards/             # Anki フラッシュカード一括作成スキル（pdf-to-markdown・OCR系・kentei-lab JSONブリッジ kentei_lab_import.py・whizlabs JSONブリッジ whizlabs_import.py・studying JSONブリッジ studying_import.py を bundle）
    └── converting-content/              # 画像ベースEPUB→テキストOCR変換・LM Studio翻訳スキル
```

---

## コンポーネント一覧

### Skills (5個)

| スキル | 説明 |
|--------|------|
| `collecting-kentei-lab-exams` | kentei-lab.com の資格・検定 URL（概要ページ/開始ページ/問題ページのいずれでも可）を渡すと、その資格の全問題（問題文・選択肢・正解・解説）を巡回取得し、1 資格 1 JSON ファイル（Anki 登録に適した構造化データ）に保存する。出力はそのまま `creating-flashcards` へ渡して試験名ごとに Anki フラッシュカード化できる。 |
| `collecting-whizlabs-exams` | Whizlabs のコース practice test 一覧 URL（`/learn/course/<slug>/<course-id>/pt` 形式）を渡すと、配下の全クイズ（Free Test・Practice Test 1〜N 等）を practice mode で巡回し、各問題（問題文・選択肢・正解・解説・参考資料）を取得して 1 クイズ 1 JSON ファイルに保存する。ログイン必須のため agent-browser の state save/load でセッションを永続化する。出力はそのまま `creating-flashcards` へ渡してクイズごとに Anki フラッシュカード化できる。 |
| `collecting-studying-exams` | studying（スタディング）のコースレッスン一覧 URL（`https://member.studying.jp/course/id/<course_id>/` 形式）を渡すと、配下の「スマート問題集」「セレクト過去問集（学科試験対策・実技試験対策）」の全問題（問題文・選択肢・正解・解説）を科目単位で取得し、1 科目 1 JSON ファイルに保存する。ログイン必須のため agent-browser の Auth Vault を第一候補に試行し、機能しない場合は state save/load にフォールバックする。出力はそのまま `creating-flashcards` へ渡して科目ごとに Anki フラッシュカード化できる。 |
| `creating-flashcards` | EPUB/PDF/スキャン本から Anki フラッシュカードを Anki MCP Server または AnkiConnect API 経由で一括作成する（MCP設定・画像ベース教材の OCR: Apple Vision 優先/ローカル VLM フォールバック・デッキ/ノートタイプ管理・コンテンツ構造分析・HTML整形の一括インポート）。`collecting-kentei-lab-exams` が収集した JSON（exam_title/slug/questions スキーマ）は専用ブリッジ `scripts/kentei_lab_import.py` で、`collecting-whizlabs-exams` が収集した JSON（course_title/quiz_title/quiz_id/questions スキーマ）は専用ブリッジ `scripts/whizlabs_import.py` で、`collecting-studying-exams` が収集した JSON（course_title/category/subject_title/practice_id/questions スキーマ）は専用ブリッジ `scripts/studying_import.py` でそれぞれファストパス投入でき、AI による構造推測（言語検出・構造分析・サンプル確認）をスキップして `検定試験::<検定名>::<級>::kentei-lab`（級を検出できない試験は `検定試験::<検定名>::kentei-lab`）・`資格試験::<コース名>::<クイズ名>::whizlabs`・`資格試験::<コース名>::<カテゴリ名>::<科目名>::studying` デッキへ直接一括登録する。 |
| `converting-content` | 画像ベース EPUB をテキストへ OCR 変換し、LM Studio によるローカル英日翻訳を行う（pandoc・OCR ワークフローを含む）。 |

### Commands (1個)

| コマンド | 説明 |
|---------|------|
| `/improve-creating-flashcards` | `creating-flashcards` セッション後の知見（パーサー罠・OCRアーティファクト・構造パターン・判定マーカー表記揺れ等）を自動抽出し、スキル配下の参照ファイルへ追記してスキルを自己進化させる（Claude Code 専用）。 |

---

## 依存関係メモ

- **agent-browser CLI**（Rust ネイティブ・CDP 直結のブラウザ自動化 CLI）が必要です（`collecting-kentei-lab-exams`・`collecting-whizlabs-exams`・`collecting-studying-exams`）。未導入の場合は `web:automating-browser` スキル同梱の `scripts/install.sh` で導入してください。
- **agent-browser state save/load によるセッション永続化**が必要です（`collecting-whizlabs-exams`・`collecting-studying-exams`）。Whizlabs はログイン必須かつログインフォームがモーダル型（専用ログインページなし）のプラットフォームで agent-browser の Auth Vault（`auth save`/`auth login`）が使用できないため、ログイン後のブラウザセッションを `agent-browser state save`/`state load` で保存・復元します。studying は通常のフォームページ（専用ログインページ `/login/`）のため Auth Vault を第一候補として試行し、機能しない場合に state save/load へフォールバックします。state ファイルはいずれもセッショントークンを含む秘匿情報のため、出力ディレクトリ配下に置きコミット対象にしません。
- **jq**（JSON 整形・検証・最終成果物の組み立て）が必要です（`collecting-kentei-lab-exams`・`collecting-whizlabs-exams`・`collecting-studying-exams`）。収集結果は kentei-lab では `<slug>.json`（最終成果物）と `<slug>.jsonl`（進捗・resume の真実源）、whizlabs では `<course-slug>__<quiz-slug>.json`（最終成果物）と同名 `.jsonl`（進捗）の2ファイル、studying では `<course-slug>__<category-slug>__<subject-slug>.json`（最終成果物のみ・単一ページ読み取りで科目データが完結するため進捗サイドカーは出力しません）で出力されます。
- **Anki MCP Server または AnkiConnect API**（`creating-flashcards`）が必要です。Anki 本体とのカード一括インポートに使用します。
- **pdf-to-markdown バイナリ**は `creating-flashcards/scripts/` に skill-bundled 済みです（plugin レベルの `scripts/` には依存しません）。同ディレクトリには `collecting-kentei-lab-exams` の JSON 出力を Anki へ直接投入する専用ブリッジ `kentei_lab_import.py`、`collecting-whizlabs-exams` の JSON 出力を投入する専用ブリッジ `whizlabs_import.py`、`collecting-studying-exams` の JSON 出力を投入する専用ブリッジ `studying_import.py` も常設されています。
- **ローカル OCR**: Apple Vision（`ocr-apple-vision`）を優先し、利用不可時はローカル VLM（`recognize-image-to-markdown` / `recognize-image.py`）にフォールバックします（`creating-flashcards`・`converting-content`）。
- **LM Studio**（ローカル LLM 翻訳）が必要です（`converting-content`）。
- kentei-lab.com は認証不要の公開無料サイトです。`collecting-kentei-lab-exams` は教育目的の節度ある利用（既定のリクエスト間隔・レート配慮）を前提としています。大規模な資格（問題数が多い試験）は取得に時間がかかるため、長時間実行を想定した運用（バックグラウンド実行・中断再開）に対応しています。
- Whizlabs は認証必須の有料コンテンツを含むプラットフォームです。`collecting-whizlabs-exams` はユーザー自身が正規に受講権限を持つコースの個人学習目的でのみ使用する前提です。resume は同一ブラウザプロセス内でのみ有効な弱い resume のため、クイズ単位での分割実行（長時間実行時は `run_in_background`）を推奨します。
- studying（スタディング）は認証必須の有料コンテンツを含むプラットフォームです。`collecting-studying-exams` はユーザー自身が正規に受講権限を持つコースの個人学習目的でのみ使用する前提です。科目単位の一括表示ページ方式のため Whizlabs より大幅に高速に収集できますが、科目数が多いコースでは長時間実行を想定した運用（`run_in_background`）を推奨します。
