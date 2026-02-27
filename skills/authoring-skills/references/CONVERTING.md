# ソースファイル → スキル変換ガイド

ソースファイル（Markdown、PDF、EPUB）、URL、またはフォルダを読み込み、Claude Code Skill形式に変換するメタスキル。

---

## 対応形式

| 形式 | 拡張子 | 前処理 |
|------|--------|--------|
| Markdown | `.md` | なし（直接処理） |
| PDF | `.pdf` | 専用スクリプト (`pdf-to-markdown.mjs`) でMarkdown変換 |
| EPUB | `.epub` | `pandoc` CLIコマンドでMarkdown変換 |
| DOCX | `.docx` | `pandoc` CLIコマンドでMarkdown変換 |
| ODT | `.odt` | `pandoc` CLIコマンドでMarkdown変換 |
| RST | `.rst` | `pandoc` CLIコマンドでMarkdown変換 |
| LaTeX | `.tex` | `pandoc` CLIコマンドでMarkdown変換 |
| HTML | `.html` | `pandoc` CLIコマンドでMarkdown変換 |
| Org | `.org` | `pandoc` CLIコマンドでMarkdown変換 |
| AsciiDoc | `.adoc` | `pandoc` CLIコマンドでMarkdown変換 |
| RTF | `.rtf` | `pandoc` CLIコマンドでMarkdown変換 |
| PPTX | `.pptx` | `pandoc` CLIコマンドでMarkdown変換 |
| URL | `https://...` | curl + pandoc + filter.lua でMarkdown変換 |
| フォルダ | ディレクトリ | 上記形式のファイルを再帰的に列挙 |

### 複数ファイル入力のサポート

複数のファイル・URL・フォルダを同時に入力することが可能:

| 入力パターン | 例 |
|-------------|-----|
| 複数ファイルパス | `/path/to/file1.md /path/to/file2.pdf /path/to/file3.epub` |
| 複数URL | `https://url1.com https://url2.com` |
| フォルダ | `/path/to/folder/` |
| 混在入力 | `/path/to/file1.md https://url2.com /path/to/folder/` |

複数ファイルが入力された場合、Phase A（Plannerタチコマ）でグルーピング分析を実施する。

---

## 使用タイミング

- 既存Markdownからスキルを作成するとき
- 技術書（PDF/EPUB）の要約をスキル化するとき
- 社内ドキュメント、技術ノートをスキル化するとき
- Web上の技術記事・ブログ記事をスキル化するとき
- 公式ドキュメントのページをスキル化するとき
- フォルダ内の複数ファイルを一括でスキル化するとき
- 引数としてソースファイルパス、URL、またはフォルダパスを受け取る

---

## 変換ワークフロー（5フェーズ）

```
Phase 0: 入力判定（Claude Code本体）- 最小限の処理
    ↓
Phase A: 計画策定（Plannerタチコマ・Opus）- ファイル変換〜構造設計をすべて委譲
    ↓
Phase B: ユーザー確認（Claude Code本体）- docs/読み込み → AskUserQuestion → docs/保存
    ↓
Phase C: 実装（Implementerタチコマ × N・Sonnet）- スキルファイル生成
    ↓
Phase D: 品質チェック（Claude Code本体）- 最終検証 → TeamDelete
```

---

### Phase 0: 入力判定（Claude Code本体）

**Claude Code本体が行う最小限の処理。変換・分析・設計はすべて Phase A（Plannerタチコマ）に委譲する。**

#### 0.1 入力判定

| 入力タイプ | 判定方法 | 次のステップ |
|-----------|---------|-------------|
| 単一Markdownファイル | `.md`拡張子 | ファイル変換不要（Plannerが直接読み込む） |
| 単一PDFファイル | `.pdf`拡張子 | Plannerが変換 |
| pandoc対応形式 | `.epub`,`.docx`,`.odt`,`.rst`,`.tex`,`.html`,`.org`,`.adoc`,`.rtf`,`.pptx` | Plannerが変換 |
| URL | `http://` or `https://` で始まる | Plannerが変換 |
| フォルダ | ディレクトリパス | Plannerがファイル列挙・変換 |

#### 0.2 作業ディレクトリ作成・TeamCreate

入力ファイル名（または複数ファイルの場合は代表名）から `{skill-provisional-name}` を決定し、作業ディレクトリとチームを作成する:

```bash
# 作業ディレクトリ作成（Plannerが docs/ ファイルを書き込むために必要）
mkdir -p docs/conversion-{skill-provisional-name}
```

```json
TeamCreate({
  "team_name": "{skill-provisional-name}-conversion",
  "description": "{skill-provisional-name} スキル変換"
})
```

> **`{skill-provisional-name}` の決め方**: 入力ファイル名（拡張子除去）をケバブケースに変換。複数ファイルの場合は代表的なファイル名やフォルダ名を使用。実際のスキル名は Phase A の分析で確定する。

---

### Compaction耐性: docs/conversion-{skill-name}/ ファイル構成

すべての中間結果は `docs/conversion-{skill-name}/` に保存する。各フェーズの完了ごとにファイルへ書き込み、compaction後も作業状態を復元できるようにする。

```
docs/conversion-{skill-name}/
├── 00-input-files.md          # 入力ファイル一覧・変換済みMDパス
├── 01-grouping-analysis.md    # 概要テーブル・グルーピング提案（複数ファイル時）
├── 02-content-analysis.md     # 内容構造分析・スコープ比較・スキル名候補
├── 03-design-plan.md          # 構造設計・Frontmatter・ファイル構成・トリガー設定
├── 04-mutual-updates.md       # 類似スキルdescription相互更新計画
├── 05-implementation-tasks.md # implementer用タスク分割（ファイル所有権・ソース範囲）
├── 06-user-decisions.md       # ユーザー確認結果（Phase B後にClaude Code本体が作成）
└── 99-progress.md             # 進捗状況（各Phase完了ステータス・復旧用）
```

#### 99-progress.md フォーマット

```markdown
# Conversion Progress: {skill-name}

## Phase Status
- [ ] Phase 0: 入力判定
- [ ] Phase A: 計画策定（Planner）
- [ ] Phase B: ユーザー確認
- [ ] Phase C: 実装（Implementer）
- [ ] Phase D: 品質チェック

## 変換済みMDファイル
（Phase A完了後に記録）

## 確定スキル名
（Phase B完了後に記録）

## 作成ファイル
（Phase C完了後に記録）
```

#### compaction発生時の復旧手順

```
compaction 発生時:
1. docs/conversion-*/ ディレクトリを検索
2. 99-progress.md を読み込み → 最後に完了したPhaseを特定
3. 未完了Phaseから再開:
   - Phase A 未完了 → Planner再起動（変換済みMDファイルがあれば変換ステップをスキップ）
   - Phase B 未完了 → 03-design-plan.md を読み込み → ユーザー確認再実行
   - Phase C 未完了 → Implementer再起動（生成済みファイルをスキップ）
   - Phase D 未完了 → 品質チェック再実行
```

---

### Phase A: 計画策定（Planner タチコマ・Opus）

Claude Code本体は TeamCreate 後、Planner タチコマを起動してファイル変換から構造設計まですべてを委譲する。**Planner の完了通知を受けてから Phase B に進む。**

#### A.1 Planner起動（Task tool呼び出し）

```json
Task({
  "description": "計画策定",
  "prompt": "## タスク: スキル変換計画の策定\n\n**作業ディレクトリ:** docs/conversion-{skill-name}/\n（存在しない場合はまず作成: `mkdir -p docs/conversion-{skill-name}/`）\n\n**入力ファイル・URL:**\n- {入力ファイルパス1 or URL1}\n- {入力ファイルパス2 or URL2（あれば）}\n\n## 実行ステップ\n\n### Step 1: ファイル変換（Markdown化）\n各入力ファイルを以下の方法でMarkdown変換する。変換済みMDパスを `docs/conversion-{skill-name}/00-input-files.md` に記録すること。\n\n**PDF変換:**\n> ⚠️ PDFファイルをReadツールで直接読み取ってはならない。APIの画像制限を超えるため専用スクリプトを使用すること。\n```bash\ncd skills/authoring-skills/scripts && npm install  # 初回のみ\nnode skills/authoring-skills/scripts/pdf-to-markdown.mjs <input.pdf> /tmp/output.md\n```\n\n**pandoc対応形式（EPUB/DOCX/ODT/RST/LaTeX/HTML/Org/AsciiDoc/RTF/PPTX）:**\n```bash\nif ! command -v pandoc &> /dev/null; then brew install pandoc; fi\npandoc -t markdown -o /tmp/<output>.md <input-file>\n```\n\n**URL変換:**\n```bash\ncurl -o /tmp/page.html '<URL>'\npandoc /tmp/page.html -f html -t gfm -L skills/authoring-skills/scripts/filter.lua -o /tmp/page.md\n```\n\n**変換結果の検証:**\n```bash\nnode skills/authoring-skills/scripts/validate-conversion.mjs <output.md> --type pdf --pages N\nnode skills/authoring-skills/scripts/validate-conversion.mjs <output.md> --type epub --chapters N\n```\nその他形式・URLは目視確認（本文が適切に抽出されているか確認）。\n\n### Step 2: グルーピング分析（複数ファイル時）\n複数ファイルの場合、全Markdownファイルを読み込み、以下を `docs/conversion-{skill-name}/01-grouping-analysis.md` に保存:\n- 各ファイルの概要テーブル（ファイル名・タイトル・主要トピック・推定行数・ドメイン）\n- 意味的グルーピング提案（同一技術・スコープ → 1スキル、異なる技術 → 別スキル）\n- 既存 `skills/` との一括重複チェック結果（既存スキルのfrontmatterと比較）\n- 判断が必要なケースはその理由と候補を記録（Claude Code本体がPhase BでAskUserQuestion実施）\n\n### Step 3: 内容構造分析\n変換済みMarkdownを読み込み、以下を `docs/conversion-{skill-name}/02-content-analysis.md` に保存:\n- セクション数とトピック一覧\n- コード例の有無・言語\n- 判断基準テーブルの有無\n- 推定総行数（全ファイル合計）\n- 既存スキルとのスコープ比較（`skills/` 内の既存スキルdescriptionと照合）\n- スキル名候補2-3個（gerund形式、`skills/authoring-skills/references/NAMING-STRATEGY.md` 参照）\n- 相互description更新が必要な類似スキルリスト\n\n### Step 4: 構造設計\n以下を設計して `docs/conversion-{skill-name}/03-design-plan.md` に保存:\n- Frontmatter設計（英語description・三部構成: What + When + 差別化）\n- SKILL.md + サブファイル構成（500行以下を目標。超過時はユーザー確認が必要と記録）\n- 判断分岐箇所（AskUserQuestion指示を配置する箇所の特定）\n- トリガー設定（REQUIRED/SessionStart hook/Use when パターン、`skills/authoring-skills/references/TEMPLATES.md` 参照）\n\n### Step 5: 相互更新設計\n類似スキルのdescription更新案を `docs/conversion-{skill-name}/04-mutual-updates.md` に保存:\n- 新規スキル → 既存スキルへの差別化参照\n- 既存スキル → 新規スキルへの差別化参照\n- 双方向の差別化文言案\n\n### Step 6: implementer用タスク分割\n生成する各ファイルの担当範囲を `docs/conversion-{skill-name}/05-implementation-tasks.md` に保存:\n- 各ファイルの所有権（target-file-path）\n- 対応するソースMarkdownのパス・対象セクション\n- 推定行数・複雑度\n\n### Step 7: 進捗更新\n`docs/conversion-{skill-name}/99-progress.md` のPhase Aを完了マーク。変換済みMDファイルのパスも記録する。\n\n## Compaction耐性規則\n- 各Stepの完了ごとに該当 docs/ ファイルに書き込む（まとめて後から書かない）\n- 大きなソースファイル分析時は、セクション単位で中間結果を保存\n- `skills/` 実装ファイルは変更しない（読み取り + `docs/` 作成のみ）\n\n## 参照\n- 変換コマンド詳細: `skills/authoring-skills/references/CONVERTING.md` の「A.2 変換コマンドリファレンス」\n- 命名戦略: `skills/authoring-skills/references/NAMING-STRATEGY.md`\n- テンプレート集: `skills/authoring-skills/references/TEMPLATES.md`",
  "subagent_type": "sumik:タチコマ（アーキテクチャ）",
  "model": "opus",
  "team_name": "{skill-name}-conversion",
  "name": "planner",
  "run_in_background": true,
  "mode": "bypassPermissions"
})
```

#### A.2 変換コマンドリファレンス（Plannerが使用）

**PDF変換（pdfjs-dist スクリプト）:**

> **⚠️ PDFファイルをReadツールで直接読み取ってはならない。** Claude APIには1リクエストあたり画像+ドキュメント合計100個の制限があり、PDFの各ページが画像としてレンダリングされるため、画像を多く含むPDFでは制限を超えてエラーになる。PDFのテキスト抽出は必ず以下の専用スクリプトを使用すること。画像コンテンツは抽出対象外（テキストのみ抽出）。

専用スクリプトを使用してPDFからMarkdownに変換する（MCP Pandocでは見出し・リスト等のレイアウト解析精度が不十分なため）:

```bash
# 依存関係のインストール（初回のみ）
cd skills/authoring-skills/scripts && npm install

# PDF → Markdown 変換
node skills/authoring-skills/scripts/pdf-to-markdown.mjs <input.pdf> /tmp/output.md
```

スクリプトの機能:
- `pdfjs-dist` によるテキスト抽出
- フォントサイズ・太字判定による見出し検出（H1-H3）
- 箇条書き・番号付きリストの自動検出
- インデントレベルの推定
- PDFメタデータ（タイトル、著者等）の抽出
- アウトライン（目次）の抽出
- 画像コンテンツのスキップ（テキストのみ抽出）

**pandoc対応形式の変換（EPUB/DOCX/ODT/RST/LaTeX/HTML/Org/AsciiDoc/RTF/PPTX）:**

`pandoc` コマンドを使用して各形式からMarkdownに変換する。

```bash
# pandocの存在確認 → なければインストール試行
if ! command -v pandoc &> /dev/null; then
  echo "pandoc が見つかりません。インストールを試みます..."
  if [[ "$(uname)" == "Darwin" ]] && command -v brew &> /dev/null; then
    brew install pandoc
  else
    echo "pandoc をインストールしてください: https://pandoc.org/installing.html"
    exit 1
  fi
fi

# EPUB → Markdown 変換例（出力は /tmp/ に）
pandoc -t markdown -o /tmp/変換後ファイル名.md "元ファイル名.epub"

# その他の形式（pandocが入力形式を自動判定）
pandoc -t markdown -o /tmp/output.md <input-file>
```

pandocの入力形式自動判定は拡張子に基づくため、明示的に指定する必要はない。必要な場合は `-f` オプションで指定可能:

| 拡張子 | pandoc形式名 | 備考 |
|--------|-------------|------|
| `.epub` | `epub` | 電子書籍 |
| `.docx` | `docx` | Microsoft Word |
| `.odt` | `odt` | OpenDocument Text |
| `.rst` | `rst` | reStructuredText（Python系ドキュメント） |
| `.tex` | `latex` | LaTeX文書 |
| `.html` | `html` | ローカルHTMLファイル |
| `.org` | `org` | Emacs Org mode |
| `.adoc` | asciidoc | AsciiDoc |
| `.rtf` | `rtf` | Rich Text Format |
| `.pptx` | `pptx` | PowerPoint（スライドノート含む） |

**ポイント:**
- `pandoc` コマンドが存在すればそのまま使用
- macOS で `brew` が利用可能なら `brew install pandoc` で自動インストール
- いずれも不可の場合、ユーザーにインストールを案内して処理を中断
- PDFはpandocのレイアウト解析精度が不十分なため、専用スクリプト（`pdf-to-markdown.mjs`）を使用
- URLはcurl + pandoc + filter.luaで変換（WebFetchはfallback。pandocはURL直接取得に非対応）

**URL変換（curl + pandoc + filter.lua）:**

1. まず `curl` でHTMLをダウンロード
2. `pandoc` + `filter.lua` でMarkdown変換
3. 指示があればURLの下の階層も含めてダウンロード（`wget --recursive` 等を使用）

```bash
# 単一ページ
curl -o /tmp/page.html "https://example.com/docs"
pandoc /tmp/page.html -f html -t gfm -L skills/authoring-skills/scripts/filter.lua -o /tmp/page.md

# 階層的ダウンロード（ユーザーの指示がある場合のみ）
wget --recursive --no-parent --convert-links -P /tmp/site/ "https://example.com/docs/"
# 各HTMLファイルに対してpandoc変換を適用
for f in /tmp/site/**/*.html; do
  pandoc "$f" -f html -t gfm -L skills/authoring-skills/scripts/filter.lua -o "${f%.html}.md"
done
```

WebFetchはpandocが利用できない場合のfallback手段として使用可能:
- `url`: 対象URL
- `prompt`: `"この記事の本文をMarkdown形式で全文抽出してください"`

#### A.3 変換結果の検証（Plannerが実行）

```bash
# PDF（ページ数を指定）
node skills/authoring-skills/scripts/validate-conversion.mjs <output.md> --type pdf --pages N

# EPUB（チャプター数を指定）
node skills/authoring-skills/scripts/validate-conversion.mjs <output.md> --type epub --chapters N

# その他のpandoc対応形式（目視確認）
# DOCX/ODT/RST/LaTeX/HTML/Org/AsciiDoc/RTF/PPTX は
# 変換後のMarkdownが元ファイルの内容を適切に含んでいるか目視確認する
```

検証基準:
| 元形式 | 最小期待文字数 | 警告条件 |
|--------|-------------|---------|
| PDF | ページ数 × 500 | 下回ったら警告 |
| EPUB | チャプター数 × 1000 | 下回ったら警告 |
| その他pandoc形式 | - | 目視確認（見出し構造・本文が適切に変換されているか） |
| URL | - | 目視確認（本文が適切に抽出されているか） |

**URL変換の場合**: Readabilityによる本文抽出が行われるため、変換後のMarkdownが元ページの本文を適切に含んでいるか目視確認する。

**警告が出た場合**: 変換結果を目視確認し、問題があれば手動でMarkdownを修正してから次のステップに進む。

---

### Phase B: ユーザー確認（Claude Code本体）

Planner 完了後、Claude Code本体が docs/ を読み込み AskUserQuestion で確認し、結果を `06-user-decisions.md` に保存する。

#### B.1 docs/ 読み込み

```bash
# Planner完了通知受信後に以下を読み込む
# - docs/conversion-{skill-name}/01-grouping-analysis.md（複数ファイル時）
# - docs/conversion-{skill-name}/02-content-analysis.md
# - docs/conversion-{skill-name}/03-design-plan.md
```

#### B.2 AskUserQuestion

**Phase A の分析結果をもとに、必ずAskUserQuestionで以下を確認する。**

確認項目:
1. **新規作成 or 既存追記**: 既存スキルとの比較結果に基づき推奨を提示
   - 既存スキルとの重複が検出された場合、該当スキル名と重複箇所を明示
2. **スキル名**: ファイル名・コンテンツ分析から生成した具体的な候補を2-3個提示（gerund形式）
   - 命名ロジックの詳細は [NAMING-STRATEGY.md](NAMING-STRATEGY.md) 参照
3. **ファイル分割方針**: SKILL.md単体 or サブファイル分割
4. **対象読者・使用場面**: descriptionに反映
5. **除外内容**: ソース出典情報の除去可否、その他除外項目
6. **既存スキルとの差別化方針**

AskUserQuestionの実装例:

```python
# 例: docker-best-practices.md を入力した場合
AskUserQuestion(
    questions=[
        {
            "question": "既存スキルとの重複が検出されました。新規作成しますか、既存に追記しますか？",
            "header": "作成方針",
            "options": [
                {"label": "既存 managing-docker に追記（推奨）", "description": "Docker運用ガイドとしてスコープが重複。サブファイルとして追加"},
                {"label": "既存 writing-dockerfiles に追記", "description": "Dockerfile作成に特化した内容の場合"},
                {"label": "新規スキルとして作成", "description": "既存スキルとは異なる独立したスコープの場合"}
            ],
            "multiSelect": False
        },
        {
            "question": "スキル名を決めてください（ファイル名・内容から自動推定）。",
            "header": "スキル名",
            "options": [
                {"label": "optimizing-docker", "description": "Docker最適化に焦点を当てたスキル"},
                {"label": "deploying-containers", "description": "コンテナデプロイに焦点を当てたスキル"},
                {"label": "managing-docker", "description": "既存スキルに追記する場合"}
            ],
            "multiSelect": False
        },
        {
            "question": "ファイル構成をどうしますか？",
            "header": "ファイル構成",
            "options": [
                {"label": "SKILL.md単体", "description": "内容が500行以下に収まる場合（推奨）"},
                {"label": "複数ファイル分割", "description": "内容が多くトピック別分割が必要な場合"}
            ],
            "multiSelect": False
        }
    ]
)
```

**複数ファイル・グルーピング確認が必要な場合は以下も追加:**

```python
AskUserQuestion(
    questions=[
        {
            "question": "以下のグルーピング提案を確認してください。",
            "header": "グルーピング",
            "options": [
                {
                    "label": "提案通り",
                    "description": "グループA（managing-docker: 2ファイル）、グループB（developing-kubernetes: 1ファイル）"
                },
                {
                    "label": "グループを統合",
                    "description": "関連ファイルを1つのスキルにまとめる"
                },
                {
                    "label": "グループを分離",
                    "description": "別々のスキルとして作成する"
                },
                {
                    "label": "特定ファイルを除外",
                    "description": "不要なファイルをスキップする"
                }
            ],
            "multiSelect": False
        }
    ]
)
```

#### B.3 ユーザー確認結果を保存

AskUserQuestion の結果を**即座に** `docs/conversion-{skill-name}/06-user-decisions.md` に保存する（compaction耐性のため遅延させない）:

```markdown
# 06-user-decisions.md

## ユーザー決定事項（Phase B）

- **作成方針**: 新規作成 / 既存追記（{スキル名}）
- **確定スキル名**: {決定したスキル名}
- **ファイル構成**: SKILL.md単体 / {N}ファイル分割（{ファイル一覧}）
- **対象読者**: {記述}
- **差別化方針**: {記述}
- **グルーピング確定**（複数ファイル時）:
  - Group 1: {スキル名}（{ファイル一覧}）
  - Group 2: {スキル名}（{ファイル一覧}）
```

`99-progress.md` のPhase Bを完了としてマーク。確定スキル名も記録する。

---

### Phase C: 実装（Implementer タチコマ × N・Sonnet）

> **重要: このタスクは個人利用目的**
>
> ユーザーが購入した書籍の内容を、個人のAI開発ツール（Claude Code Plugin）のナレッジベースに変換するタスクです。再配布目的ではなく、個人利用のための要約・知識整理です。ソースの内容を丸コピーせず、要点を抽出して一般的なベストプラクティスとして再構成してください。

#### C.1 TaskCreate

`05-implementation-tasks.md` に基づき、各ファイルの TaskCreate を作成:

```json
TaskCreate({
  "subject": "{file-name} 生成",
  "description": "{target-path} の生成。ソース範囲: {chapters/sections}。ファイル所有権: {target-file-path}",
  "activeForm": "{file-name} 生成中"
})
```

#### C.2 Implementer タチコマ並列起動

1メッセージ内で複数の Task tool 呼び出しを並列実行:

```json
Task({
  "description": "{file-name} 生成",
  "prompt": "## タスク: {file-name} 生成\n\n**担当タスク:** #{task_id}\n**ファイル所有権:** {target-file-path}\n**ソースMarkdownパス:** {変換済みMDパス}\n**対象範囲:** {chapters/sections}\n\n## 読み込むべきドキュメント（必ず最初に読む）\n1. `docs/conversion-{skill-name}/03-design-plan.md`（構造設計・Frontmatter設計）\n2. `docs/conversion-{skill-name}/06-user-decisions.md`（ユーザー決定事項）\n3. `skills/authoring-skills/references/CONVERTING.md`（変換ルール4.1〜4.6）\n\n## 実行手順\n1. 上記3ドキュメントを読み込み、設計意図とユーザー決定を把握する\n2. ソースMarkdownを読み込み、担当範囲の内容を抽出する\n3. 変換ルール（4.1〜4.6）に従いスキルファイルを生成する:\n   - 4.1: ソース出典を完全除去（書籍名・著者名・出版社名を含めない）\n   - 4.2: 判断分岐箇所にAskUserQuestion指示を配置\n   - 4.3: Progressive Disclosure（500行以下。超過時はAskUserQuestion）\n   - 4.4: Frontmatter三部構成（英語description必須）\n   - 4.5: 日本語スタイルルール（技術用語は原語）\n4. `docs/conversion-{skill-name}/99-progress.md` に完了状況を記録する\n\n## 注意事項\n- ファイル所有権範囲外のファイルを絶対に編集しない\n- ソース出典情報（書籍名・著者名等）を一切含めない\n- 英語ソースの場合は直接日本語で生成する（翻訳ツール不要）\n- 生成するファイルが大きい場合はセクション単位で書き込む（compaction耐性）",
  "subagent_type": "sumik:タチコマ（ドキュメント）",
  "model": "sonnet",
  "team_name": "{skill-name}-conversion",
  "name": "implementer-{n}",
  "run_in_background": true,
  "mode": "bypassPermissions"
})
```

**複数スキルグループがある場合**: グループごとに上記Implementerを並列起動する（異なる `team_name` を使用するか、同一チーム内で `implementer-1`〜`implementer-N` として並列起動）。

**Implementerの動作規則（Compaction耐性）:**
- 生成するスキルファイルが大きい場合、セクション単位で書き込む
- 完了後に `99-progress.md` の担当タスクを完了としてマーク
- ファイル所有権の厳守（担当ファイルのみ生成・編集）

---

### Phase D: 品質チェック（Claude Code本体）

全 Implementer 完了後、品質チェックリストを適用して TeamDelete を実行する。

#### D.1 類似スキルの description 相互更新

`04-mutual-updates.md` に基づき、既存類似スキルの SKILL.md frontmatter description を Claude Code本体が直接更新する:
- 新規スキル → 既存スキルへの参照と、既存スキル → 新規スキルへの参照の**双方向**を確実に設定
- 既存スキルの「What」「When」部分は変更しない（差別化文言の追加のみ）

#### D.2 品質チェックリスト適用

後述の「品質チェックリスト」セクションを全項目確認する。

#### D.3 TeamDelete + リリース

```json
// 全メンバーにシャットダウン要求
SendMessage({
  "type": "shutdown_request",
  "recipient": "planner",
  "content": "変換作業が完了しました。シャットダウンしてください。"
})
// 各 implementer にも同様に送信

// 全メンバーシャットダウン確認後
TeamDelete()
```

リリースは INSTRUCTIONS.md の「Release Workflow」に従い、バージョン更新 → コミット → bookmark移動 → プッシュを実行する。

---

## 変換ルール

### 4.1 ソース出典の除去ルール

**書籍タイトル、著者名、出版社名、ISBN等を絶対に含めない。**

- 「~に基づく」「~を参考に」「~によると」等の出典参照フレーズを除去
- 引用ブロック (`>`) は出典を示さず、核心メッセージとして記述
- 内容は一般的なベストプラクティス・業界知識として記述

| 除去対象 | 変換後の記述 |
|---------|------------|
| 「Clean Code第3章によると...」 | 「関数設計のベストプラクティスとして...」 |
| `> -- Robert C. Martin` | `> 関数は一つのことだけを行うべきである` |
| 「ISBN 978-xxx」 | （完全に除去） |

### 4.2 AskUserQuestion配置基準

判断分岐のある箇所には、スキル内にAskUserQuestion使用を指示する文を配置する。

**配置すべき箇所:**
- アーキテクチャ選択（モノリス vs マイクロサービス等）
- ライブラリ・フレームワーク選択
- テスト戦略（範囲、ツール、対象）
- デプロイ戦略
- プロジェクト固有の要件に依存する判断

**配置不要な箇所:**
- ベストプラクティスが一義的に決まる場合（例: SQLインジェクション対策）
- セキュリティ必須対策（例: パスワードハッシュ化）
- スキル内で明確に推奨している場合

生成するスキル内に記述する指示文の例:

```markdown
### ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

確認すべき場面:
- [このスキル固有の判断分岐を列挙]

確認不要な場面:
- [明確なベストプラクティスがある場合を列挙]
```

### 4.3 Progressive Disclosure

- SKILL.md本体は **500行以下** を目安とする
- 500行に近づいた場合や超える場合、**AskUserQuestionでユーザーに対応方針を確認**（ファイル分割/内容圧縮/500行超許容から選択）
- セクション数5つ以上 or 推定行数500行超 --> サブファイル分割を推奨（ただしユーザー確認必須）
- サブファイル命名: `UPPER-CASE-HYPHEN.md`（例: `BACKEND-STRATEGIES.md`）
- SKILL.mdからサブファイルへのリンクを配置

詳細は [SKILL.md](../SKILL.md) の Progressive Disclosure セクション参照。

### 4.4 Frontmatter 三部構成の公式

```
[What: 三人称で能力を明記]. [When: トリガー条件]. [差別化: 類似スキルとの区別（類似スキル存在時は必須）].
```

例:
- `"Guides Next.js 16 / React 19 development. Use when package.json contains 'next'."`
- `"Enforces type safety in TypeScript/Python. Any/any types strictly prohibited. Use when processing API responses."`
- `"Converts markdown files into well-structured Claude Code Skills. Use when creating new skills from existing markdown source material. Reference authoring-skills for general skill creation guidelines."`

**注意**: 類似スキルが存在する場合、第三部の差別化文言は必須。4.6の相互description更新パターンを参照すること。

### 4.5 日本語・スタイルルール

- スキル本文は **日本語** で記述（技術用語は原語のまま）
- Frontmatterのdescriptionは **英語**
- セクション数が多い場合は目次にアンカーリンク付き
- 判断基準テーブル（`| 要素 | 値 |` 形式）を活用
- コード例はソース内容に準じた言語で記述
- チェックリストは `- [ ]` 形式

#### 英語ソースの日本語化

ソース言語が英語の場合、Claude Codeが英語ソースを読み取り、Phase Cの生成時に**直接日本語で**スキルを記述する。外部翻訳ツールは使用しない。

**日本語化のルール:**

| 対象 | 日本語化する | 例 |
|------|------------|-----|
| セクションタイトル | ✅ | 「Best Practices」→「ベストプラクティス」 |
| 説明文・本文 | ✅ | 英語の解説文 → 日本語の解説文 |
| テーブル内容 | ✅ | 判断基準テーブルのセル内テキスト |
| コード例 | ❌ | Python/Go/TypeScript等のコードはそのまま |
| コマンド名 | ❌ | `kubectl`, `docker` 等はそのまま |
| 技術用語・プロダクト名 | ❌ | Cloud Run, Binary Authorization 等はそのまま |
| Frontmatter description | ❌ | 英語のまま維持（Claudeのスキルマッチング精度のため） |

### 4.6 相互description更新パターン

類似スキルが存在する場合、**新規スキルと既存スキルの双方のdescription**に差別化文言を追加する。片方だけの更新は不完全であり、Claude Codeがスキル選択を誤る原因となる。

差別化タイプ別パターン、相互更新の実装例、更新時の注意事項の詳細は [NAMING.md](NAMING.md) の「Mutual Update Requirement」セクションを参照。

**要点:**
- 既存スキルの「What」（Part 1）と「When」（Part 2）は変更しない
- 追加するのは差別化文言（Part 3）のみ
- 1つのスキルに対して複数の差別化参照を持つことは可能

---

## 品質チェックリスト

作成したスキルに対して以下を全項目確認する。

### Frontmatter
- [ ] name: gerund形式、小文字ハイフン区切り
- [ ] description: What（三人称）+ When（トリガー）含む
- [ ] description: 英語で記述されている（日本語混入なし）
- [ ] description: 差別化（類似スキルとの区別）含む（該当する場合）

### 相互description更新
- [ ] 類似スキルが存在する場合、新規スキルのdescriptionに差別化文言が含まれている
- [ ] 類似スキル側のdescriptionにも新規スキルへの相互参照が追加されている
- [ ] [NAMING.md](NAMING.md) の差別化パターンに従っている
- [ ] 既存スキルの「What」「When」部分が変更されていない（差別化文言の追加のみ）

### 構造
- [ ] SKILL.md本体が500行以下（超過時はユーザーに対応方針を確認済み）
- [ ] サブファイルへの適切な分割（必要な場合）
- [ ] 目次/ナビゲーションあり（サブファイルがある場合）

### AskUserQuestion
- [ ] 判断分岐箇所にAskUserQuestion使用指示が配置されている
- [ ] 確認すべき場面と確認不要な場面が明記されている
- [ ] AskUserQuestionのコード例が含まれている

### ソース出典
- [ ] 書籍タイトル・著者名・出版社名が含まれていない
- [ ] 「~に基づく」等の出典参照フレーズがない
- [ ] 内容が一般的なベストプラクティスとして記述されている

### コンテンツ品質
- [ ] 日本語で記述されている（技術用語は原語）
- [ ] コード例が含まれている（該当する場合）
- [ ] 判断基準テーブルが含まれている（該当する場合）
- [ ] 自己完結している（他スキルを参照しなくても理解可能）

### 自動検出連携
- [ ] detect-project-skills.sh への追加が必要か判断済み
- [ ] 追加した場合、get_skill_description() にスキル説明が登録済み
- [ ] 追加した場合、skill-triggers.md の自動検出テーブルが同期更新済み
