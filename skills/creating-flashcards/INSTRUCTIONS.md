# creating-flashcards

## 概要

EPUB/PDFファイルからAnkiフラッシュカードを一括作成するワークフロースキル。ファイルをMarkdownに変換後、AIがコンテンツ構造を自動分析して問題と解答のペアを抽出し、Anki MCPまたはAnkiConnect APIを通じてフラッシュカードとして登録する。

**対応形式:**

| 形式 | 変換方法 |
|------|---------|
| EPUB | `pandoc` CLIでMarkdown変換 |
| PDF | `pdf-to-markdown.mjs` スクリプトでMarkdown変換 |

**前提条件:**

- Ankiアプリケーションが起動中であること
- AnkiConnect（ポート8765）またはAnki MCP Serverが接続済みであること（`using-anki-mcp` 参照）
- EPUB変換: `pandoc` がインストール済みであること
- PDF変換: `${CLAUDE_PLUGIN_ROOT}/skills/authoring-skills/scripts/` の依存関係がインストール済みであること

---

## ワークフロー

### Step 1: ファイル形式の検出と変換

引数として受け取ったファイルパスの拡張子を判定し、Markdownに変換する。

**EPUB → Markdown:**

```bash
pandoc -t markdown -o /tmp/flashcard-source.md <input.epub>
```

**PDF → Markdown:**

> ⚠️ PDFファイルをReadツールで直接読み取ってはならない。必ず専用スクリプトを使用すること。

```bash
cd ${CLAUDE_PLUGIN_ROOT}/skills/authoring-skills/scripts && npm install
node ${CLAUDE_PLUGIN_ROOT}/skills/authoring-skills/scripts/pdf-to-markdown.mjs <input.pdf> /tmp/flashcard-source.md
```

変換後、Markdownの内容をReadツールで**全文読み込む**。

> ⚠️ **pandocアーティファクト**: pandocはEPUB変換時にCSSクラスマーカー（`{.class_sXXX}`）、ページマーカー（`[]{#cXXX.xhtml}`）、divマーカー（`:::`）、ゼロ幅スペース付きリストマーカー等を生成する。これらはStep 6で除去する。

> ⚠️ **同一シリーズでも構造が異なる**: 同じ書籍シリーズのVOL.1とVOL.2でも、pandoc変換後のMarkdown構造は大きく異なることがある（例: VOL.1は`質問 1`のプレーンテキスト行、VOL.2は`## 質問1 {.heading_s6F}`のMarkdownヘッダー）。前回のスクリプトをそのまま再利用できない前提でコンテンツ分析を行うこと。

### Step 2: 言語検出

変換されたMarkdownの内容から**ソース言語を自動判定**する。

- **日本語**: そのまま処理
- **英語（またはその他の外国語）**: `translating-with-lmstudio` スキルのワークフローを使用してLM Studioで日本語に翻訳し、カードを作成する。原文は折りたたみセクションとして保持する（詳細は後述の「多言語対応」セクション参照）。セッション内初回の翻訳時はモデル選択が必要。

### Step 3: コンテンツ構造の自動分析

**変換されたMarkdownを注意深く読み、問題と解答の構造を自分で判断する。ユーザーには聞かない。**

以下の手順で分析する:

1. **全文を読み込み**、ファイル全体の構造を俯瞰する
2. **問題のマーカーを特定**: 問題番号（問1、Q1、第1問、(1) 等）、見出し（問題文が見出しに埋め込まれるパターンもある: `##### 問題 N. [問題文]`）、ページ区切りなど
3. **解答のマーカーを特定**: 「解答」「答え」「Answer」「正解」「解説」等のキーワード、解答番号。正解が数字で示される場合もある（例: `Correct Response: 4` → D（4番目の選択肢））
4. **構造パターンを判定**: 以下のいずれかに分類

| パターン | 特徴 |
|---------|------|
| **同一セクション型** | 1つのセクション内に問題と解答が両方ある |
| **交互配置型** | 問題→解答→問題→解答…と交互に出現する |
| **前半後半分離型** | 前半に問題がまとまり、後半に解答がまとまっている |
| **章末解答型** | 各章の末尾に解答セクションがある |
| **その他** | 上記に当てはまらない独自構造 |
| **混在型** | 1つのEPUB内に複数の構造パターンが共存（例: Assessment Testは同一セクション型、Practice Examは前半後半分離型） |

詳細な検出ヒューリスティクスは [CONTENT-PROCESSING.md](references/CONTENT-PROCESSING.md) を参照。

5. **問題と解答のペアを全件抽出**する

> ⚠️ **pandoc行折り返しの結合**: pandocは長い行を任意の位置で改行する。選択肢・段落・不正解解説等の複数行にわたるテキストは、セマンティックな単位ごとに1行に結合すること。

### Step 4: サンプル確認

**抽出した最初の1件をサンプルとしてユーザーに提示し、正しく抽出できているか確認する。**

以下の形式で提示する:

```
【サンプル確認】

検出したコンテンツ構造: [判定したパターン名]
抽出した問題・解答ペア数: [N] 件

--- サンプル（1件目）---

■ 問題（Front）:
[整形済みの問題文をそのまま表示]

■ 解答（Back）:
[整形済みの解答文をそのまま表示]

--- サンプルここまで ---
```

その後、AskUserQuestionで確認:

```python
AskUserQuestion(
    questions=[{
        "question": "上記のサンプルは正しく問題と解答を抽出できていますか？",
        "header": "サンプル確認",
        "options": [
            {"label": "正しい、このまま続行", "description": "問題と解答の抽出が正確。全件の作成に進む"},
            {"label": "問題と解答が逆", "description": "FrontとBackの内容を入れ替えて再抽出する"},
            {"label": "抽出がずれている", "description": "問題や解答の範囲が正しくない。構造を再分析する"},
            {"label": "全く違う", "description": "構造の解釈が根本的に間違っている。詳細を説明する"}
        ],
        "multiSelect": False
    }]
)
```

### Step 5: デッキとノートタイプの選択

#### 5a: デッキの選択

**必ずAskUserQuestionでデッキを確認する。ファイル名や内容から推測可能な場合はその推測も選択肢に含める。**

1. `list_decks` ツールでAnki内の既存デッキ一覧を取得
2. ファイル名と問題内容を分析し、既存デッキとの関連性を推測
3. 推測結果を「推奨」として選択肢の先頭に配置

#### 5b: ノートタイプ（プリセット）の選択

**必ずAskUserQuestionでノートタイプを確認する。推測で決定してはならない。**

1. `modelNames` ツールで現在Ankiに登録されているノートタイプ一覧を取得
2. `modelFieldNames` で各ノートタイプのフィールド構成を確認し、選択肢の説明に含める
3. AskUserQuestionで使用するノートタイプをユーザーに確認する

```python
# 取得したノートタイプ一覧とフィールド情報を選択肢として提示
AskUserQuestion(
    questions=[{
        "question": "使用するノートタイプ（プリセット）を選択してください。",
        "header": "ノートタイプ",
        "options": [
            # modelNames + modelFieldNames の結果から動的に生成
            {"label": "[ノートタイプ名]", "description": "フィールド: [フィールド一覧]"},
            # ... 取得した全ノートタイプを列挙
        ],
        "multiSelect": False
    }]
)
```

4. 選択されたノートタイプのフィールド名に合わせてStep 6のカード作成時の `modelName` と フィールドマッピングを設定する

> ⚠️ ノートタイプのフィールド名がデフォルト（`Front`/`Back`）と異なる場合がある。必ず `modelFieldNames` で確認したフィールド名を `addNotes` のフィールドキーとして使用すること。

### Step 6: コンテンツのフォーマットとフラッシュカード一括作成

#### HTMLフォーマットルール

**Frontフィールド（問題）:**

- 問題番号ヘッダー（「問 N」等）は**含めない**。問題の内容のみ
- 選択肢は以下の形式:

```html
<ol style="list-style-type: none; padding-left: 0;">
  <li>A. 選択肢テキスト</li>
  <li>B. 選択肢テキスト</li>
  <li>C. 選択肢テキスト</li>
  <li>D. 選択肢テキスト</li>
</ol>
```

- `list-style-type: none` でデフォルト番号を非表示にし、`A.` `B.` 等のプレフィックスを `<li>` 内に保持
- 問題文と選択肢の間は `<br><br>` で分離
- **選択肢形式の正規化**: ソースの選択肢がバレットポイント（`-`）形式の場合、A./B./C./D./E. のレターを自動付与する
- **複数正解対応**: 「二つ選択」等の問題では、正解の選択肢を全てBackフィールドに表示する

**Backフィールド（解答）:**

```html
<b>正解の選択肢:</b><br><br>
[正解テキスト]<br><br>
<b>解説:</b><br><br>
[解説テキスト]<br><br>
<b>不正解の選択肢の解説:</b><br><br>
<b>B:</b> [不正解解説テキスト]<br><br>
<b>C:</b> [不正解解説テキスト]
```

- **比較テーブル**: 解説に含まれるプレーンテキストの比較テーブルは、HTMLテーブル（`<table>`）に変換してAnkiで見やすく表示する

詳細なフォーマットルールは [CONTENT-PROCESSING.md](references/CONTENT-PROCESSING.md) を参照。

#### 一括作成（バッチAPI推奨）

大量のカード作成（50件以上）には、MCP `add_note` の個別呼び出しではなく、**AnkiConnect の `addNotes` バッチAPI**を直接使用する。

```python
import json, urllib.request

def anki_request(action, params=None):
    payload = {"action": action, "version": 6}
    if params:
        payload["params"] = params
    req = urllib.request.Request(
        "http://127.0.0.1:8765",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))["result"]

# 50件ずつバッチ投入
BATCH_SIZE = 50
for start in range(0, len(notes), BATCH_SIZE):
    batch = notes[start:start + BATCH_SIZE]
    result = anki_request("addNotes", {"notes": batch})
```

**進捗表示:**

- 50件ごとに進捗を報告
- エラー発生時はスキップし、最後にエラー一覧を表示

### Step 7: 品質検証

作成完了後、**必ず以下の品質検証を実施する**（最初の実行時およびスクリプト修正後）:

1. **サンプルチェック**: `findNotes` + `notesInfo` で先頭5件・中盤5件のカードを取得し、以下を確認:
   - コードブロック（`<pre><code>`）の中身が空でないか
   - pandocアーティファクト（`[]`、`{.class_sXXX}`）が残っていないか
   - pandoc行折り返しが`<br>`として残っていないか（例: `AWS<br>コンソール`→`AWS コンソール`）
   - 「正解の選択肢」セクションが空でないか（特に複数正解問題）
   - 選択肢内のエスケープ文字（`\[`, `\]`, `\"`）が正しく復元されているか

2. **問題発見時**: スクリプトを修正し、既存カードを全削除→再作成する

### Step 8: 完了報告

作成完了後、以下を報告する:

- 作成したカード数
- 対象デッキ名
- スキップしたカード数（エラーがあった場合）

### Step 9: スキル自己改善

**作業中に発見した新たな知見（パーサーのバグ修正、新しいpandocアーティファクトパターン、構造の変異等）があった場合、完了報告後に以下を実施する。**

1. 現在のスキルファイルを読み込む:
   - `skills/creating-flashcards/SKILL.md`
   - `skills/creating-flashcards/references/CONTENT-PROCESSING.md`
2. 今回の作業で発見した知見を整理する:
   - 新しいpandocアーティファクトパターン
   - パーサーで発生したバグとその修正方法
   - 構造分析の改善点（新しい検出パターン等）
   - 品質検証で発見した問題パターン
3. 該当するスキルファイルに知見を追記する（具体例とともに）
4. 追記内容をユーザーに提示し、AskUserQuestionで確認を得てから適用する

> ⚠️ この自己改善ステップにより、スキルは使うたびに賢くなる。発見のない場合はスキップしてよい。

---

## 多言語対応

### 英語（外国語）コンテンツの処理

ソースが英語等の外国語の場合、以下の方針で処理する:

1. **`translating-with-lmstudio` スキルのワークフローで翻訳**する（LM Studioのローカル LLMを使用）。セッション内初回の翻訳時はモデル選択が必要。
2. **問題文・選択肢・解答・解説を日本語に翻訳**してカードのメインコンテンツとする
3. **原文は折りたたみセクション（`<details>`）として保持**する
4. 折りたたみはデフォルトで閉じており、タップ/クリックで展開できる

#### 翻訳コマンド

各テキストブロックを以下のコマンドで翻訳する:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/translating-with-lmstudio/scripts/lmstudio-translate.py translate --model <選択済みモデル> --text "翻訳対象テキスト"
```

#### エラーハンドリング

LM Studio APIがエラーを返した場合、フォールバックなしでユーザーに通知する:

> 「LM StudioのAPIがエラーを返しています。LM Studioが起動しモデルがロードされていることを確認してください。準備完了まで待ちます。」

#### Frontフィールド（英語ソースの場合）

```html
[日本語に翻訳された問題文]<br><br>
<ol style="list-style-type: none; padding-left: 0;">
  <li>A. [日本語の選択肢]</li>
  <li>B. [日本語の選択肢]</li>
  <li>C. [日本語の選択肢]</li>
  <li>D. [日本語の選択肢]</li>
</ol>
<br>
<details>
<summary>📄 原文（English）</summary>
<br>
[Original English question text]<br><br>
<ol style="list-style-type: none; padding-left: 0;">
  <li>A. [Original English choice]</li>
  <li>B. [Original English choice]</li>
  <li>C. [Original English choice]</li>
  <li>D. [Original English choice]</li>
</ol>
</details>
```

#### Backフィールド（英語ソースの場合）

```html
<b>正解の選択肢:</b><br><br>
[日本語の正解テキスト]<br><br>
<b>解説:</b><br><br>
[日本語の解説]<br><br>
<b>不正解の選択肢の解説:</b><br><br>
<b>B:</b> [日本語の不正解解説]<br><br>
<b>C:</b> [日本語の不正解解説]<br><br>
<details>
<summary>📄 原文（English）</summary>
<br>
<b>Correct Answer:</b><br><br>
[Original English answer]<br><br>
<b>Explanation:</b><br><br>
[Original English explanation]
</details>
```

#### 翻訳時の注意事項

- **技術用語**: サービス名、プロダクト名、コマンド名等はそのまま英語で保持（例: Cloud Run, kubectl, Binary Authorization）
- **翻訳品質**: 直訳ではなく、自然な日本語にする。ただし原文の意味を変えない
- **選択肢の対応**: 翻訳後の選択肢と原文の選択肢の順序を一致させる

#### 大規模翻訳の処理

100問以上の英語コンテンツを翻訳する場合も、LM Studioスクリプトを逐次呼び出しで処理する（ローカルLLMのため高速）:

1. **パース**: 全Q&AペアをJSON（英語）に抽出
2. **翻訳**: 各Q&AペアについてLM Studioスクリプトを呼び出す
   - 問題文、各選択肢、解答、解説を個別にスクリプトで翻訳する
   ```bash
   python3 ${CLAUDE_PLUGIN_ROOT}/skills/translating-with-lmstudio/scripts/lmstudio-translate.py translate --model <選択済みモデル> --text "翻訳対象テキスト"
   ```
3. **一括投入**: AnkiConnect `addNotes` バッチAPIで投入

---

## ユーザー確認の原則（AskUserQuestion）

**このスキルでは、コンテンツ構造の分析はAIが自律的に行い、ユーザーには結果の検証のみを求める。**

**確認すべき場面:**

- サンプルQ&Aペアの正確性（Step 4: 必須）
- デッキの選択（Step 5a: 必須）
- ノートタイプ（プリセット）の選択（Step 5b: 必須）
- 大量カード作成前の確認（50件超の場合）

**確認不要な場面（AIが自動判断）:**

- ファイル形式の判定（拡張子から自動判定）
- Markdown変換方法（形式ごとに固定）
- コンテンツ構造の分析（AIが全文を読んで判断）
- 言語の判定（内容から自動判定）
- 選択肢のリスト化フォーマット（常に `<ol>` + `list-style-type: none`）
- 無駄な改行の除去（常に実施）

---

## 関連スキル

- **using-anki-mcp**: Anki MCPサーバーのセットアップ・直接操作
- **authoring-skills**: PDF→Markdown変換スクリプトの提供元
