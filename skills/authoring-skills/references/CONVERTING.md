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
| URL | `https://...` | WebFetch ツールでMarkdown変換 |
| フォルダ | ディレクトリ | 上記形式のファイルを再帰的に列挙 |

### 複数ファイル入力のサポート

複数のファイル・URL・フォルダを同時に入力することが可能:

| 入力パターン | 例 |
|-------------|-----|
| 複数ファイルパス | `/path/to/file1.md /path/to/file2.pdf /path/to/file3.epub` |
| 複数URL | `https://url1.com https://url2.com` |
| フォルダ | `/path/to/folder/` |
| 混在入力 | `/path/to/file1.md https://url2.com /path/to/folder/` |

複数ファイルが入力された場合、Phase 0.5で全ファイルの概要分析とグルーピングを実施する。

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

## 変換ワークフロー（6フェーズ）

### Phase 0: 前処理（PDF/EPUB/フォルダ対応）

**Markdownファイル1つの場合はこのPhaseをスキップしてPhase 1へ進む。**

#### 0.1 入力判定

| 入力タイプ | 判定方法 | 次のステップ |
|-----------|---------|-------------|
| 単一Markdownファイル | `.md`拡張子 | Phase 1へスキップ |
| 単一PDFファイル | `.pdf`拡張子 | 0.2 PDF変換 |
| pandoc対応形式 | `.epub`,`.docx`,`.odt`,`.rst`,`.tex`,`.html`,`.org`,`.adoc`,`.rtf`,`.pptx` | 0.2 pandoc変換 |
| URL | `http://` or `https://` で始まる | 0.2 URL変換 |
| フォルダ | ディレクトリパス | 0.1.1 ファイル列挙 |

#### 0.1.1 フォルダ・複数ファイル処理

1. 指定フォルダ内の `.md`, `.pdf`, `.epub`, `.docx`, `.odt`, `.rst`, `.tex`, `.html`, `.org`, `.adoc`, `.rtf`, `.pptx` ファイルを再帰的に列挙（フォルダ入力の場合）
2. 複数ファイルパス・URL が直接指定された場合はそのリストを使用
3. 対象ファイルリストと作業計画を `docs/` に保存
4. 各ファイルに対して以下を順次適用（Markdown変換の準備）:
   - PDF → Phase 0.2 PDF変換
   - pandoc対応形式（EPUB/DOCX/ODT/RST/LaTeX/HTML/Org/AsciiDoc/RTF/PPTX）→ Phase 0.2 pandoc変換
   - URL → Phase 0.2 URL変換
   - Markdown → そのまま次へ
5. 全ファイルをMarkdown化した後、**Phase 0.5（全ファイル概要分析 & グルーピング）**へ進む

**注意**: 単一ファイル入力の場合はPhase 0.5をスキップしてPhase 1へ直行する（既存ワークフローとの互換性維持）。

#### 0.2 PDF/pandoc対応形式/URL → Markdown変換

**PDF変換（pdfjs-dist スクリプト）:**

> **⚠️ PDFファイルをReadツールで直接読み取ってはならない。** Claude APIには1リクエストあたり画像+ドキュメント合計100個の制限があり、PDFの各ページが画像としてレンダリングされるため、画像を多く含むPDFでは制限を超えてエラーになる。PDFのテキスト抽出は必ず以下の専用スクリプトを使用すること。画像コンテンツは抽出対象外（テキストのみ抽出）。

専用スクリプトを使用してPDFからMarkdownに変換する（MCP Pandocでは見出し・リスト等のレイアウト解析精度が不十分なため）:

```bash
# 依存関係のインストール（初回のみ）
cd skills/authoring-skills/scripts && npm install

# PDF → Markdown 変換
node skills/authoring-skills/scripts/pdf-to-markdown.mjs <input.pdf> <output.md>
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

# 各形式 → Markdown 変換（pandocが入力形式を自動判定）
pandoc -t markdown -o <output.md> <input-file>
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
- URLはWebFetchツールを使用（pandocはURL直接取得に非対応）

**URL変換（WebFetch）:**

Claude Code の WebFetch ツールを使用:
- `url`: 対象URL
- `prompt`: `"この記事の本文をMarkdown形式で全文抽出してください"`
- WebFetchの結果をMarkdownファイルとして保存

#### 0.3 変換結果の検証

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

**警告が出た場合**: 変換結果を目視確認し、問題があれば手動でMarkdownを修正してからPhase 0.5（複数ファイル）またはPhase 1（単一ファイル）に進む。

### Phase 0.5: 全ファイル概要分析 & グルーピング（複数ファイル入力時のみ）

**このPhaseは複数のファイル・URLが入力された場合にのみ実行する。単一ファイル入力の場合はスキップしてPhase 1へ進む。**

Phase 0で全ファイルをMarkdown化した後、各ファイルの内容を俯瞰し、意味的にまとまるファイル群をグループ化する。グループごとに1つのスキルを作成する。

#### ステップ1: 全ファイル読み込み & 概要テーブル作成

全Markdownファイルを読み込み、各ファイルの概要情報を一覧化する:

| ファイル名 | タイトル/主要見出し | 主要トピック | 推定行数 | ドメイン |
|-----------|-------------------|------------|---------|---------|
| docker-basics.md | Docker入門 | コンテナ基礎、イメージ、実行 | 800 | Docker |
| docker-networking.md | Dockerネットワーク設計 | ブリッジ、オーバーレイ、DNS | 600 | Docker |
| kubernetes-intro.md | Kubernetes概要 | Pod、Service、Deployment | 1000 | Kubernetes |

**抽出項目:**
- **タイトル/主要見出し**: ファイル先頭のH1、H2見出し
- **主要トピック**: 頻出キーワード、セクション名から抽出
- **推定行数**: Markdownファイルの行数
- **ドメイン**: 技術領域・スコープの推定

このテーブルをユーザーに提示し、次のステップへ進む。

#### ステップ2: 意味的グルーピング分析

トピック類似度・技術スコープ・内容の関連性に基づき、「同一スキルにまとめるべきファイル群」を提案する。

**グルーピング判断基準:**

| 条件 | 判断 | 例 |
|------|------|-----|
| 同一技術・同一スコープ | **1スキルにまとめる**（自動グルーピング） | `docker-basics.md` + `docker-networking.md` → `managing-docker` |
| 同一技術・異なるレイヤー | **AskUserQuestionで確認** | `frontend-design.md` + `backend-api.md` → 分割 or 統合を確認 |
| 異なる技術・関連トピック | **AskUserQuestionで確認** | `docker-guide.md` + `kubernetes-guide.md` → コンテナスキル統合 or 別スキル |
| 完全に独立したドメイン | **別スキルとして作成**（自動分離） | `react-hooks.md` + `terraform-gcp.md` → 別々のスキル |

**グルーピング提案の出力形式:**

```
グループA: managing-docker（推奨スキル名）
  - docker-basics.md（コンテナ基礎）
  - docker-networking.md（ネットワーク設計）

グループB: developing-kubernetes（推奨スキル名）
  - kubernetes-intro.md（基礎概念）

グループC: 確認が必要
  - docker-guide.md（Docker包括ガイド）
  - kubernetes-guide.md（Kubernetes包括ガイド）
  → 統合して1つの「コンテナオーケストレーション」スキルにするか、別々にするか？
```

#### ステップ3: 既存スキルとの一括重複チェック

全グループを `skills/` ディレクトリ内の既存スキルと照合し、重複度を判定する。

**重複度判定基準:**

| 重複度 | 判断 | 例 |
|--------|------|-----|
| 完全一致（ドメイン・スコープが同じ） | **既存スキルに追記**推奨 | グループA: Docker運用 → 既存 `managing-docker` に追加 |
| 部分一致（サブトピックとして独立性あり） | **既存スキルにサブファイルとして追加**推奨 | グループB: Docker最適化 → `managing-docker/references/OPTIMIZATION.md` |
| 軽微な重複（独立性が高い） | **新規作成 + 相互参照**推奨 | グループC: Dockerセキュリティ → 新規 `securing-docker` + `managing-docker` に相互参照 |
| 重複なし | **新規作成** | グループD: Terraform GCP → 新規 `deploying-terraform-gcp` |

**重複度テーブルの出力形式:**

| グループ | 既存スキルとの重複 | 推奨アクション |
|---------|------------------|--------------|
| グループA: managing-docker | `managing-docker`（完全一致） | 既存スキルに追記 |
| グループB: developing-kubernetes | 重複なし | 新規作成 |
| グループC: docker+kubernetes統合 | `managing-docker`, `developing-kubernetes`（部分一致） | AskUserQuestionで確認 |

#### ステップ4: AskUserQuestion で確認

グルーピング提案・既存スキル重複判定の結果をもとに、AskUserQuestionで最終的なグループ構成とスキル作成方針を確認する。

**AskUserQuestion テンプレート例:**

```python
AskUserQuestion(
    questions=[
        {
            "question": "以下のグルーピング提案を確認してください。変更が必要な場合は修正してください。",
            "header": "グルーピング",
            "options": [
                {
                    "label": "提案通り",
                    "description": "グループA（managing-docker: 2ファイル）、グループB（developing-kubernetes: 1ファイル）"
                },
                {
                    "label": "グループCを統合",
                    "description": "docker-guide.md + kubernetes-guide.md を1つの「コンテナオーケストレーション」スキルにまとめる"
                },
                {
                    "label": "グループCを分離",
                    "description": "docker-guide.md と kubernetes-guide.md を別々のスキルにする"
                },
                {
                    "label": "特定ファイルを除外",
                    "description": "不要なファイルをスキップする"
                }
            ],
            "multiSelect": False
        },
        {
            "question": "既存スキルとの統合方針を確認してください。",
            "header": "既存スキル統合",
            "options": [
                {
                    "label": "グループAを既存 managing-docker に追記（推奨）",
                    "description": "Docker運用スキルとして統合"
                },
                {
                    "label": "グループAを新規スキルとして作成",
                    "description": "既存スキルと独立させる"
                }
            ],
            "multiSelect": False
        }
    ]
)
```

**確認項目:**
1. **グルーピングの承認/修正**: 自動提案されたグループ構成が妥当か、ファイルの移動・分割・統合が必要か
2. **既存スキルとの統合/新規作成の判断**: 既存スキルに追記するか、新規作成するか
3. **ファイル除外の選択**: 不要なファイルをスキップするか

確認後、最終的な「スキルグループリスト」を確定する。

**確定グループの出力形式:**

```
確定グループ:
- Group 1: managing-docker（既存スキルに追記）
  - docker-basics.md
  - docker-networking.md

- Group 2: developing-kubernetes（新規作成）
  - kubernetes-intro.md
```

### Phase 1: 分析（Analysis）

**Phase 0.5で確定した各スキルグループに対して、Phase 1→2→3→3.5→4→5を順番に実行する。**

**単一ファイル入力の場合は、Phase 0.5をスキップしてこのPhaseから開始する。**

#### 1.1 ソース読み込み

- ソースMarkdownを読み込む（PDF/EPUB/その他形式の場合はPhase 0で変換済み）
- **複数ファイルグループの場合**: グループ内の全ファイルを対象とする

#### 1.2 内容構造分析

グループ内の全ファイル（単一ファイルの場合は1ファイルのみ）について以下を分析:

- セクション数とトピック
- コード例の有無・言語
- 判断基準テーブルの有無
- 推定総行数（全ファイル合計）

#### 1.3 スキルスコープ特定

グループ内のファイルが共通してカバーする領域を特定する。

#### 1.4 キーワード抽出

- **単一ファイルの場合**: ファイル名から拡張子除去、区切り文字分割（ハイフン、アンダースコア、スペース）
- **URL入力の場合**: ファイル名からのキーワード抽出は行わず、URLのパス部分とコンテンツ分析からドメイン・トピックを特定
- **複数ファイルグループの場合**: グループ内全ファイルの共通キーワードを抽出し、ドメイン・トピックを特定

#### 1.5 アクションタイプ特定とスキル名候補生成

コンテンツからアクションタイプを特定:
- 詳細は [NAMING-STRATEGY.md](NAMING-STRATEGY.md) のマッピング表参照
- ドメインキーワード + アクション動詞 → gerund形式のスキル名候補2-3個を生成

#### 1.6 既存スキルとのスコープ比較

**Phase 0.5で既存スキル重複チェックを実施済みの場合、この手順はスキップ可能。**

`skills/` ディレクトリ内の既存スキル一覧を取得し、各スキルのfrontmatter descriptionと、ソースMarkdownの主要トピックを比較:

| 状況 | 判断 | 理由 |
|------|------|------|
| 既存スキルと完全に同じドメイン・スコープ | **既存に追記**推奨 | 重複を避け、情報を集約 |
| 既存スキルのサブトピック | **既存にサブファイルとして追加**推奨 | 関連情報の集約 |
| 既存スキルと部分的に重複するが独立性あり | AskUserQuestionで確認 | ユーザー判断が必要 |
| 完全に新しいドメイン | **新規作成**推奨 | 独立したスキルとして価値がある |

#### 1.7 相互description更新の必要性判定

- 「既存スキルと部分的に重複するが独立性あり」→ 新規作成の場合: **双方のdescriptionに相互参照を追加**
- 「完全に新しいドメイン」→ 近接ドメインのスキルがあれば: **差別化文言を追加**
- 更新が必要な既存スキルのリストを作成し、Phase 2で確認、Phase 4で実行
- 比較結果と推奨をPhase 2のAskUserQuestionに反映

### Phase 1-5 のループ実行（複数スキルグループの場合）

Phase 0.5で確定した各スキルグループに対して、以下のフェーズを**順番に**実行する:

```
確定グループ: [Group 1, Group 2, Group 3]

for each group in groups:
    ── orchestrating-teams Phase 1（計画策定）──
    Step A: TeamCreate（Claude Code本体）
    Step B: planner タチコマ起動（model: opus）
            → Phase 1: 分析 + Phase 3: 構造設計 + Phase 3.5: トリガー設定 + docs/plan作成
    Step C: Claude Code本体がplannerの計画をレビュー
    Step D: Phase 2: ユーザー確認（AskUserQuestion）

    ── orchestrating-teams Phase 2（実装）──
    Step E: TaskCreate（Claude Code本体がplannerの計画に基づき作成）
    Step F: implementer タチコマ並列起動（model: sonnet）→ Phase 4: ファイル生成
    Step G: Phase 5: 品質チェック（Claude Code本体）

    ── クリーンアップ ──
    Step H: SendMessage shutdown_request → TeamDelete
```

**注意**: 各グループの処理結果（作成されたスキル名、ファイル構成、成果物パス）を記録し、全グループ完了後に最終レポートを作成する。

### Phase 2: ユーザー確認（AskUserQuestion 必須）

**Phase 1の分析結果をもとに、必ずAskUserQuestionで以下を確認する。**

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

### Phase 3: 構造設計（Design）

1. **Frontmatter設計** -- 三部構成の公式に従う（後述 4.4）。**descriptionは必ず英語で記述**（スキル本文は日本語）
2. **SKILL.mdのセクション構成決定**（500行以下を目安。超える場合はAskUserQuestionでユーザーに対応方針を確認）
3. **サブファイルの構成決定**（必要な場合、命名は UPPER-CASE-HYPHEN.md）
4. **判断分岐箇所の特定** -- AskUserQuestion指示を配置する箇所を決定
5. **類似スキルのdescription相互更新設計**
   - Phase 1で特定した類似スキルそれぞれについて、description更新案を作成
   - 相互参照パターン（後述 4.6）に従い、「For X, use Y instead.」形式の差別化文言を設計
   - 新規スキル側と既存スキル側の両方のdescription案を用意

### Phase 3.5: トリガー設定

スキルの発見可能性を高めるため、descriptionのトリガーパターンを決定:

1. **REQUIRED/MUST**: 必須スキルの場合、descriptionに明記
2. **SessionStart hook**: 自動検出対象にする場合、`detect-project-skills.sh` への追加を検討
3. **Use when**: 条件トリガーの場合、具体的な条件を列挙

詳細は [TEMPLATES.md](TEMPLATES.md) の「トリガーパターン」セクション参照。

### Phase 4: 生成（Generate）

> **重要: このタスクは個人利用目的**
>
> ユーザーが購入した書籍の内容を、個人のAI開発ツール（Claude Code Plugin）のナレッジベースに変換するタスクです。再配布目的ではなく、個人利用のための要約・知識整理です。ソースの内容を丸コピーせず、要点を抽出して一般的なベストプラクティスとして再構成してください。

#### 4.0 実行戦略の選択

生成フェーズは `orchestrating-teams` スキルの2フェーズ方式に従い、スキルの複雑度とファイル数に応じて実行する:

| 条件 | 実行戦略 | 理由 |
|------|---------|------|
| 単一スキル・SKILL.md単体 | タチコマ1体を直接起動（チーム不要） | シンプルなタスク |
| 単一スキル・複数ファイル分割 | orchestrating-teams 2フェーズ方式（planner + implementers並列） | 並列化による効率化 |
| 複数スキルグループ（2つ以上） | orchestrating-teams 2フェーズ方式（グループごとにPhase 1-2実行） | 大規模変換の効率化 |

**デフォルト推奨**: 複数ファイル分割や複数スキル生成の場合は **orchestrating-teams を使用**する。

#### 4.0.1 orchestrating-teams 実行フロー

##### Step A: TeamCreate

```json
TeamCreate({
  "team_name": "{skill-name}-conversion",
  "description": "{skill-name} スキル変換"
})
```

##### Step B: planner タチコマ起動

planner は Phase 0 で変換済みのMarkdownを読み込み、Phase 1（分析）+ Phase 3（構造設計）+ Phase 3.5（トリガー設定）を実行する。

```json
Task({
  "description": "計画策定",
  "prompt": "## タスク: スキル変換計画の策定\n\n**ユーザー要求:** {変換元ファイルパスと変換指示}\n**変換済みMarkdown:** {Phase 0で生成したMDファイルパス}\n\n以下を実行:\n1. ソースMarkdown分析（内容構造、トピック、コード例、推定行数）\n2. 既存スキルとのスコープ比較\n3. スキル名候補生成（gerund形式2-3個）\n4. ファイル構成設計（SKILL.md + サブファイル構成）\n5. Frontmatter設計（英語description、三部構成）\n6. トリガー設定（REQUIRED/SessionStart/Use when）\n7. 類似スキルのdescription相互更新設計\n8. docs/plan-{skill-name}.md を作成\n\n参照: authoring-skills（CONVERTING.mdの変換ルール4.1〜4.6）",
  "subagent_type": "sumik:タチコマ",
  "model": "opus",
  "team_name": "{skill-name}-conversion",
  "name": "planner",
  "run_in_background": true,
  "mode": "bypassPermissions"
})
```

**planner の責務:**
- ソースMarkdownの読み込み・内容構造分析（Phase 1）
- 既存スキルとのスコープ比較・スキル名候補生成（Phase 1）
- ファイル構成・Frontmatter・セクション設計（Phase 3）
- トリガー設定（Phase 3.5）
- `docs/plan-{skill-name}.md` の作成（PLAN-TEMPLATE.md形式）
- **注意**: planner は実装ファイルを変更しない（読み取り + docs/ 作成のみ）

##### Step C: 計画レビュー

Claude Code本体が planner の `docs/plan-{skill-name}.md` をレビューし、Phase 2（AskUserQuestion）でユーザー確認を取得。

##### Step D: TaskCreate

planner が作成した計画に基づき、各ファイルのTaskを作成:

```json
TaskCreate({
  "subject": "SD-PRINCIPLES.md 生成",
  "description": "Ch 5-7 の設計原則をPython向け参照ファイルとして生成。ファイル所有権: references/SD-PRINCIPLES.md",
  "activeForm": "SD-PRINCIPLES.md 生成中"
})
```

##### Step E: implementer タチコマ並列起動

1メッセージ内で複数のTask tool呼び出しを並列実行:

```json
Task({
  "description": "{file-name}生成",
  "prompt": "## タスク: {file-name} 生成\n\n**担当タスク:** #{task_id}\n**ファイル所有権:** {target-file-path}\n**ソースファイル:** {source-chapter-paths}\n**変換ルール:** authoring-skills CONVERTING.md 4.1〜4.6 に従う\n\n禁止事項:\n- 所有権範囲外のファイルを編集しない\n- ソース出典を含めない\n- 500行を超えない",
  "subagent_type": "sumik:タチコマ",
  "model": "sonnet",
  "team_name": "{skill-name}-conversion",
  "name": "implementer-{n}",
  "run_in_background": true,
  "mode": "bypassPermissions"
})
```

##### Step F: 品質チェック + クリーンアップ

1. 全implementer完了後、Phase 5品質チェックリストを適用
2. SendMessage で各メンバーにshutdown_request
3. 全メンバーシャットダウン確認後にTeamDelete

> **英語ソースの場合**: Phase 0でMarkdownに変換 → Phase 1で言語を自動検出 → Phase 4で日本語スキルとして直接生成（Claude Codeが英語ソースを読み取り、日本語で出力） → 出典除去ルール（4.1）は生成時に適用

#### 4.1 SKILL.md生成

**frontmatter descriptionは必ず英語で記述**（Claudeのスキルマッチングは英語descriptionで最も高精度に動作するため）

#### 4.2 サブファイル生成

必要な場合、Phase 3の設計に従いサブファイルを生成

#### 4.3 ソース出典情報の除去

後述 4.1 参照:
- 書籍タイトル、著者名、出版社名、ISBN
- 「~に基づく」「~を参考に」等の出典参照フレーズ
- 内容は一般的なベストプラクティスとして記述し直す

#### 4.4 類似スキルのdescription相互更新

Phase 3で設計した更新案に基づき、既存類似スキルのSKILL.md frontmatter descriptionを更新:
- 新規スキル → 既存スキルへの参照と、既存スキル → 新規スキルへの参照の**双方向**を確実に設定
- 更新対象ファイル一覧:
  - 新規スキルのSKILL.md（frontmatter description）
  - 各類似スキルのSKILL.md（frontmatter description）
- **注意**: 既存スキルのdescription更新は差別化文言の追加のみ。既存の「What」「When」部分は変更しない

### Phase 5: 品質チェック（Validate）

後述のセクション「品質チェックリスト」を適用し、全項目を確認する。

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

ソース言語が英語の場合、Claude Codeが英語ソースを読み取り、Phase 4の生成時に**直接日本語で**スキルを記述する。外部翻訳ツールは使用しない。

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
