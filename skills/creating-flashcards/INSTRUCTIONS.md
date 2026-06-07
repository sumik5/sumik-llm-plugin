# creating-flashcards

## 概要

EPUB/PDFファイルからAnkiフラッシュカードを一括作成するワークフロースキル。ファイルをMarkdownに変換後、AIがコンテンツ構造を自動分析して問題と解答のペアを抽出し、Anki MCPまたはAnkiConnect APIを通じてフラッシュカードとして登録する。

**対応形式:**

| 形式 | 変換方法 |
|------|---------|
| EPUB | `pandoc` CLIでMarkdown変換 |
| PDF | `pdf-to-markdown` スクリプトでMarkdown変換 |
| JSON | 構造化済みデータとして直接処理（変換不要） |

**前提条件:**

- Ankiアプリケーションが起動中であること
- AnkiConnect（ポート8765）またはAnki MCP Serverが接続済みであること（後述のセットアップ参照）
- EPUB変換: `pandoc` がインストール済みであること
- PDF変換: `${CLAUDE_PLUGIN_ROOT}/scripts/` の依存関係がインストール済みであること

---

## Anki MCPセットアップ

### アドオンインストール

**AnkiWebコード**: `124672614`

1. Ankiを起動 → **ツール** → **アドオン** → **アドオンを入手**
2. コード `124672614` を入力してインストール
3. Ankiを再起動

**要件:** Anki 25.07以降（Python 3.13）

### Claude Code接続設定

プロジェクトの `.mcp.json` に以下を追加:

```json
{
  "mcpServers": {
    "anki": {
      "url": "http://127.0.0.1:3141/"
    }
  }
}
```

デフォルト設定: HTTPモード、ポート `3141`、ホスト `127.0.0.1`

### 接続確認

```bash
curl http://127.0.0.1:3141/
```

応答があれば接続成功。失敗する場合はAnkiが起動しているか、アドオン設定（ツール→アドオン→Anki MCP Server→設定）を確認。

詳細なツールリファレンスは `references/ANKI-MCP-TOOLS.md`、完全なセットアップ・活用ガイドは `references/ANKI-MCP-GUIDE.md` を参照。

---

## ワークフロー

### 投入インフラの利用（毎回の作業の前提）

このスキルは `skills/creating-flashcards/scripts/` に**2層構成の Python**を常備している。投入・整形・冪等性のインフラは毎回 /tmp に書き起こさず、これらを再利用する。

| ファイル | 性質 | 役割 |
|---------|------|------|
| `scripts/anki_toolkit.py` | 🔴 **不変・育てる側** | ソースに依らず毎回同じ部分（AnkiConnect クライアント・`addNotes` バッチ投入・冪等性・HTML整形・タグ生成・`QAPair` 中間表現契約・翻訳スキップ判定・品質検証）を全格納する。投入時に書き換えない。発見した不変バグはここを1箇所修正する |
| `scripts/parser_scaffold.py` | **雛形・コピーして使う側** | ソース固有の `parse()` だけを毎回埋める使い捨てパーサーの雛形。共通前処理ヘルパ（pandocアーティファクト除去・NFKC正規化・smart_join・ページ番号抽出・セクションマーカーgrep・画像抽出）に加え、OCR残存フォールバック用の `collapse_repeated_lines(text, max_repeat=3)`（反復崩壊圧縮・消費側閾値3）・`strip_thinking_logs(text)`（メタ思考ログ除去・○×単独行保護）を「素材」として持つ。呼ぶ/呼ばない/regexの差し替えは毎回ソースを見て判断する（一括統合関数にはしない） |

**毎回の作業フロー:**

1. `parser_scaffold.py` を /tmp にソース固有名でコピーする（例: `cp skills/creating-flashcards/scripts/parser_scaffold.py /tmp/parse-<descriptive-name>.py`）
2. ソース Markdown を目視し、Step 3 のコンテンツ構造分析を実施する（過去のパーサーを再利用しない前提）
3. scaffold の共通ヘルパは必要なものだけ呼び、regex をソースに合わせて差し替える
4. `parse()` の TODO ブロックにソース固有の抽出ロジックを手書きし `list[QAPair]` を返す
5. `main()` が `anki_toolkit` を import して投入する（投入インフラは二度と書かない）

> ⚠️ scaffold が toolkit を import するため、コピー先で `CLAUDE_PLUGIN_ROOT` 環境変数を設定する（`export CLAUDE_PLUGIN_ROOT=<プラグインルート>`）か、scaffold 冒頭の `<CLAUDE_PLUGIN_ROOT>` プレースホルダを実パスへ置換する。

> 🔴 **toolkit があっても parse は使い捨て**: 共通化したのは「ソースに依らない投入インフラ」だけ。`parse()` 本体をジェネリック化してはならない（Step 3 の警告参照: 同シリーズ・同一級でも pandoc 後の構造は変異し、汎用パーサーはサイレント抽出漏れを起こす）。toolkit 導入で parse が楽になったと誤解しないこと。

`scripts/` ディレクトリの詳細な契約（`QAPair` フィールド・公開API シグネチャ・機械可読の CONTRACT ブロック）は本ファイル末尾の「scripts ディレクトリ（投入インフラの契約）」節を参照。

### Step 1: ファイル形式の検出と変換

引数として受け取ったファイルパスの拡張子を判定し、Markdownに変換する。

**EPUB → Markdown:**

```bash
# ⚠️ ファイル名はソースに基づくユニーク名にする（他セッションとの衝突回避）
pandoc -t markdown -o /tmp/<descriptive-name>.md <input.epub>
# 例: pandoc -t markdown -o /tmp/gcp-network-engineer.md input.epub
```

**PDF → Markdown:**

> ⚠️ PDFファイルをReadツールで直接読み取ってはならない。必ず専用スクリプトを使用すること。

```bash
scripts/pdf-to-markdown <input.pdf> /tmp/flashcard-source.md
```

変換後、Markdownの内容をReadツールで**全文読み込む**。

> 🔵 **OCR汚染の二層防衛**: ソースが `recognize-image-to-markdown` 経由のOCR出力なら、思考ログ除去・反復崩壊検出・自動再OCRはコマンド側で一次対処済み。本スキルでは**コマンドをすり抜けた残存ケース／コマンド未経由の他ツールOCR出力のサルベージ**に注力する。残存対処は `parser_scaffold.py` の `collapse_repeated_lines`（反復崩壊圧縮・消費側閾値3）・`strip_thinking_logs`（メタ思考ログ除去）を素材として使い、高度サルベージは [CONTENT-BY-TYPE.md](references/CONTENT-BY-TYPE.md) の「OCR汚染対策」を参照する。

**JSON（構造化済みQ&Aデータ）:**

JSON形式の場合はMarkdown変換不要。ファイルを読み込み、問題と解答の構造を直接解析する。Step 3のコンテンツ構造分析でJSONスキーマ（フィールド名、ネスト構造）を自動判定し、各問題のフィールドをHTMLフォーマットルールに従ってマッピングする。

> ⚠️ **JSON には2系統ある（構造化Q&A vs ページ単位OCR）**: JSON ソースには (a) 問題・解答がフィールドとして構造化済みの Q&A JSON と、(b) VLM/`recognize` 系 OCR が出力する**ページ単位 JSON**（`[{"index","filename","text"}, ...]` で各ページの生テキストを保持）の2系統がある。(b) は「構造化済み」ではなく、各ページの `text` を Markdown 同様にパースする必要がある（科目見出しページ・問題ページ・解答ページの分類が要る）。実装は **JSON パスを `md_path` として渡し、`parse()` 冒頭で `json.loads(markdown_text)` してページ列を得る**と scaffold の `main()` をそのまま再利用できる。画像主体 EPUB を VLM で逐次OCRしたケースで観測。

> ⚠️ **pandocアーティファクト**: pandocはEPUB変換時にCSSクラスマーカー（`{.class_sXXX}`）、ページマーカー（`[]{#cXXX.xhtml}`）、divマーカー（`:::`）、ゼロ幅スペース付きリストマーカー等を生成する。これらはStep 6で除去する。

> ⚠️ **同一シリーズでも構造が異なる**: 同じ書籍シリーズのVOL.1とVOL.2でも、pandoc変換後のMarkdown構造は大きく異なることがある（例: VOL.1は`質問 1`のプレーンテキスト行、VOL.2は`## 質問1 {.heading_s6F}`のMarkdownヘッダー）。前回のスクリプトをそのまま再利用できない前提でコンテンツ分析を行うこと。
>
> **年版エディション間の差異も同様**: 同一資格対策書の前年版と当年版でも、セクション境界マーカーが微妙に変化する。実観測ケース: 前年版は `# 最重要項目100の一問一答` （長形式）、当年版は `# 最重要項目100`（短形式・後続行に `## の` `## 一問一答` が分離）／前年版は `第1部` 単独行、当年版は `第1部 分野別問題`（タイトル併記）／前年版は `第2部`、当年版は `第 2 部`（数字前後にスペース）。前年版で動いた regex がそのまま失敗するため、最初に各セクション境界マーカーをファイル内 grep で実物確認し、`\s*` 許容の柔軟な regex に書き換えること（例: `^第\s*[12]\s*部(\s+[^\s].*)?\s*$`）。

> ⚠️ **改訂版書籍の章単位問題数変動**: 同一資格試験対策書籍でも前年版と当年版で章単位の問題数が増減することがある（例: 前年版 第3章 12問 → 当年版 10問 で -2問削減）。差分判定スクリプトで大幅に「既存扱い」件数が増えた場合、OCR抽出漏れと混同しやすい。**判別手順**: `grep -c "^第\s*\d\+\s*問\|^\*\*問" <markdown_file>` でチャプターエリアの問題マーカー数を実数カウントし、「期待件数 - 実カウント = 削減件数」が書籍改訂として妥当な範囲（数問程度）か確認する。削減件数が多すぎる場合はパーサーの検出漏れを疑う。

### Step 2: 言語検出

変換されたMarkdownの内容から**ソース言語を自動判定**する。

- **日本語**: そのまま処理
- **英語（またはその他の外国語）**: `converting-content` スキルのワークフローを使用してLM Studioで日本語に翻訳し、カードを作成する。原文は折りたたみセクションとして保持する（詳細は [MULTILINGUAL.md](references/MULTILINGUAL.md) 参照）。セッション内初回の翻訳時はモデル選択が必要。

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
| **テーマ単位ページ分離型** | テーマ毎に「問題N群ページ」→「解答N群ページ」が `---` 区切りで対を成し、それがテーマの数だけ繰り返される（資格試験対策書籍などで採用される見開き設計に由来） |
| **その他** | 上記に当てはまらない独自構造 |
| **混在型** | 1つのEPUB内に複数の構造パターンが共存（例: Assessment Testは同一セクション型、Practice Examは前半後半分離型） |

詳細な検出ヒューリスティクスは [CONTENT-DETECTION.md](references/CONTENT-DETECTION.md) を参照（書籍タイプの判別マトリクス・マーカー検出ルール）。判別後の具体的なパース戦略は [CONTENT-BY-TYPE.md](references/CONTENT-BY-TYPE.md) を、全タイプ共通の前処理・後処理は [CONTENT-COMMON.md](references/CONTENT-COMMON.md) を参照。

5. **問題と解答のペアを全件抽出**する

> ⚠️ **pandoc行折り返しの結合**: pandocは長い行を任意の位置で改行する。選択肢・段落・不正解解説等の複数行にわたるテキストは、セマンティックな単位ごとに1行に結合すること。

> ⚠️ **生テキスト境界検出（高度な戦略）**: pandoc変換後のMarkdownで問題番号と質問内容中の番号付きリスト等が混同される場合、**クリーニング前の生テキスト**でpandoc固有のフォーマットパターン（例: `{style="font:7.0pt 'Times New Roman'"}`）を質問境界の目印にし、ブロック単位で切り出してから個別にクリーニング・パースする方法が有効。詳細は [CONTENT-COMMON.md](references/CONTENT-COMMON.md) の「`{style="..."}` 形式EPUBの生テキスト境界検出」を参照。

> ⚠️ **「解答・解説マーカー先行型」サブパターン**: 過去問題集の解答編では `**問N 解答・解説**` または `問N 解答・解説` がカード境界マーカーとして使われ、問題文本体はマーカー後の解説テキスト内に「ア × 適切ではありません。〜」のように選択肢ごとの判定とともに散在することがある。問題編（問題文だけが並ぶページ）と解答編（解答・解説が並ぶページ）が別場所に配置される「前半後半分離型」と組み合わさるケースが多く、**過去問では解答編のマーカー数で問題数を数える**のが信頼性が高い。問題編側はOCR汚染を受けやすい一方、解答編側は規則的な「正解：X」表記を含むため抽出の起点として安定する。実装: 解答編の `**問N 解答・解説**` を起点に分割 → 各ブロックから正解・解説を抽出 → 対応する問題文は問題編側の `^問\s*N` で起点同期させる、の二段抽出を推奨する。

> ⚠️ **EPUB タイトルの合成表記揺れ（全角＋半角混在、「回」省略）と事前ガード対応**: Kindle EPUB 内のタイトル組版は時として `第４3知的財産管理技能検定`（全角「４」＋ 半角「3」＋ 「回」なし）のような合成表記になる。これはファイル取り違えではなく、書籍タイトル組版の都合による正規でない表記。事前ガードで「ユーザー指定の試験回数」と内部表記を grep 照合する際、`第\s*43\s*回` のような単純パターンは 0 ヒットで「ファイル不一致」と誤判定してフローを停止させる。**対策**: 事前ガード grep は (1) 全角・半角混在許容、(2) 「回」省略許容、(3) `unicodedata.normalize('NFKC', text)` で正規化してから比較、の3段階対応にする。デッキ名や Knowledge Area の **literal**「第N回」は人間可読の正規表記をそのまま採用してよい。

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

> ⚠️ デッキの命名戦略（シリーズ階層・年版差分・併存サフィックス・欠落差分判定）の詳細は [DECK-STRATEGY.md](references/DECK-STRATEGY.md) を参照。

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

> ⚠️ ノートタイプのフィールド名がデフォルト（`Front`/`Back`）と異なる場合がある。

> ⚠️ **`Knowledge Area` 等の補助フィールドの用法**: 資格試験対策向けのカスタムノートタイプは `Front`/`Back` の2フィールド構成ではなく、`Question` / `Answer` / `Knowledge Area`（または `Note` / `Knowledge Area` 等の補助フィールド）の3フィールド構成を持つことが多い。補助フィールドは**カードテンプレートでは直接表示されない隠しメタフィールド**として実装されているケースがあり、検索・タグ的なフィルタリングに使われる。投入時は `第40回 学科試験 問1` のような**短い識別子**（試験回・試験種別・問題番号）を入れるのが典型。長い解説文を補助フィールドに入れるとテンプレートで参照されず死蔵される。`modelFieldNames` で全フィールドを取得した後、既存カードを `notesInfo` で数枚サンプリングして用法を観察し、設計を踏襲すること。

> ⚠️ **カスタムJSテンプレートとの干渉チェック**: ノートタイプ選択後、`modelTemplates` APIでテンプレートHTMLを取得し、jQueryセレクター（例: `$('.question ol').find("li")`）がカード内の全`<li>`を対象にしていないか確認する。該当する場合、`<details>` 内の選択肢には `<ol><li>` を使わず `<br>` 区切りのプレーンテキストを使用すること（修正理由: JSがdetails内のliも取得し、選択肢が倍増して表示される）。必ず `modelFieldNames` で確認したフィールド名を `addNotes` のフィールドキーとして使用すること。

> ⚠️ **シャッフルJS の積極活用パターン**: 「干渉チェック」の裏返しとして、Front テンプレートに選択肢シャッフル JS（`$('.question ol').find("li")` を `prependTo` でランダム並べ替える等）が組み込まれているノートタイプは、これを**積極活用するカード設計**が可能。具体的には: (1) Question フィールドの選択肢は `<ol style="list-style-type: none; padding-left: 0;"><li>ア. ...</li>...</ol>` 形式にしてシャッフル対象とする（資格試験対策として「正解の位置で覚える」癖を排除）、(2) Answer フィールドには `<ol><li>` を一切使わず `<b>ア:</b> ...<br><b>イ:</b> ...` の形式で全選択肢の解説を展開する（Back 側で再シャッフルされても意味が崩れない）。「ア・イ・ウ」「①・②・③」のように内容と一緒に動かせるレターを選択肢頭に付与すれば、シャッフル後もユーザーは内容で正解判定できる。

> ⚠️ **既存デッキで使われているノートタイプを最優先する原則**: 新規デッキを作成して既存サブデッキ群と並列配置する場合、**ノートタイプを既存と揃える**ことが学習UX上極めて重要。Anki ではノートタイプごとに CSS テンプレートが異なり、同じ親デッキ内で `資格試験` と `資格試験(ランダム)` のような近似モデルが混在すると、`<li>` の箱化スタイルや `<details>` 内インデント等の見た目が変わって視覚ノイズになる。**手順**: (1) 既存サブデッキの代表ノートを `findNotes deck:"<既存サブデッキ>"` で1件取得、(2) `notesInfo` で `modelName` を確認、(3) その modelName を新規デッキでも使用、(4) `modelFieldNames` で field 名（Question/Answer/Knowledge Area 等）を確認してパース結果のマッピングを合わせる。**Anki既定の `Basic` を選んではいけない**: 既定の `Basic` は Front/Back 2フィールドのみで、既存デッキの `Question/Answer/Knowledge Area` 等のフィールド構造と互換性がなく、後から統合できない。実観測: 既存「過去問題第45回」が `資格試験(ランダム)` を使っていたので、新規「過去問題第46-49回」も同じ modelName を採用し、視覚的一貫性と将来の再編成可能性を確保した。複数モデルが混在する場合は AskUserQuestion で「既存と揃える / 別モデルで進む」を確認する。

> 🔴 **`modelTemplates` 確認結果を `RenderOptions` に反映する**: 上記のJS干渉チェック／シャッフルJS活用の判断結果は、scaffold の `main()` で `RenderOptions(...)` を組み立てて `upload(..., render=...)` に渡すことで toolkit の HTML 整形に反映する。判断と設定の対応は次のとおり:
>
> | `modelTemplates` の所見 | `RenderOptions` の設定 |
> |------------------------|----------------------|
> | `$('.question ol').find("li")` 等で `<ol><li>` をシャッフルする JS がある | `choice_list_style="ol"`（既定。メイン選択肢を `<ol style="list-style-type:none"><li>` で出力しシャッフルJSを活用） |
> | JS が全 `<li>` を取得して選択肢を倍増させるテンプレ | `choice_list_style="br"`（メイン選択肢を `<br>` 区切りプレーンテキストで出力） |
> | （常に固定） | `details_choice_style="br"`（`<details>` 原文内の選択肢は常に `<br>` 区切り。`<ol><li>` を入れると倍増・再シャッフルする既知の致命罠のため toolkit 側でも固定） |
>
> `<details>` 内に `<ol><li>` を置くと選択肢が倍増・再シャッフルされる罠（上記「カスタムJSテンプレートとの干渉チェック」）は、toolkit が `details_choice_style` を `"br"` 固定にすることで踏み抜かない。メイン選択肢の `choice_list_style` だけをテンプレに合わせて選ぶ。

#### 5c: 出典情報の取得（任意）

カード生成時に解答末尾へ出典情報（書籍名・ページ番号）を付与する場合は、以下の手順で情報を取得する。

1. AskUserQuestion でユーザーに以下を確認:
   - 書籍名（取得可能な場合のみ。ファイル名から自動推測した値を選択肢に含める）
   - 出典付与方針（全カード付与 / 付与しない）
2. 取得した書籍名はセッション変数として保持し、Step 6 のフォーマットで利用する
3. ページ番号はソース Markdown 内の `^\d{1,4}$` パターン（OCR/pandoc 変換時に保持されるページ番号行）を各問題ブロック直前または直後から抽出する

> ⚠️ **出典情報の例示は汎用プレースホルダーで記述する**: スキル本文内で書籍名を例示する際は固有名を使わず `[書名]` `[ページ番号]` のようなプレースホルダーで記述すること（実行時にユーザーから取得する変数として扱う）。

### Step 6: コンテンツのフォーマットとフラッシュカード一括作成

#### 問題形式の判定

カード作成前に、ソースが **選択肢型（Multiple Choice）** か **○×型（True/False）** かを判定する:

| 判定基準 | 選択肢型 | ○×型 | 組み合わせ正解型 |
|---------|---------|------|----------------|
| 解答マーカー | `Correct Answer: B`, `正解: A` 等のレター・番号 | `○` / `✕` / `×` / `True` / `False` | `**問N 正解：①**` 等の丸数字インライン |
| 問題文直後 | A./B./C./D. の選択肢が並ぶ | 平叙文1つのみ（選択肢なし） | 小問ア〜エ + 組み合わせ選択肢 ①〜⑥ 等 |
| 推奨ノートタイプ | Multiple Choice 系（フィールド: Question, OptionA-E, Answer 等） | Basic 系（フィールド: Front, Back） | Basic 系（Front に小問・選択肢、Back に正解番号・小問判定・解説） |

判定結果に応じて以下のHTMLフォーマットを使い分ける。

#### HTMLフォーマットルール（選択肢型）

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

- **比較テーブル**: 解説に含まれるプレーンテキストの比較テーブルは、HTMLテーブル（`<table>`）に変換してAnkiで見やすく表示する。🔴 この変換は **scaffold の `parse()` がソース固有に行い**、組み立てた `<table>` を `QAPair.back` に注入する。`anki_toolkit.build_back_html()` は `back` 本文を **raw HTML として素通し**（escape しない）するだけで、プレーンテキスト→`<table>` の自動変換は行わない（表構造の検出はソース依存のため toolkit の責務にしない）
- **出典付与（Step 5c で情報を取得した場合）**: Back フィールド末尾に以下の出典 div を付与する:

  ```html
  <div style="text-align:right;font-size:0.8em;color:#888;margin-top:1em;">
    📖 [書名] p.[ページ番号]
  </div>
  ```

  | 取得状況 | 出力形式 |
  |---------|---------|
  | 書籍名・ページ番号ともに取得済み | `📖 [書名] p.[ページ番号]` |
  | 書籍名のみ取得（ページ番号不明） | `📖 [書名]` |
  | ページ番号のみ取得（書籍名不明） | `📖 p.[ページ番号]` |
  | 両方不明 | 出典 div を出力しない |

#### HTMLフォーマットルール（○×型 / True/False型）

**Frontフィールド（問題）:**

- 問題番号ヘッダー（「問題 N」「問 N」等）は**含めない**。問題文（平叙文）のみ
- 末尾に判定指示を補助表示するため `<br><br><i>（○か✕で答えよ）</i>` を付与する
- `**重要!**` `**重要！**` バッジが付いている問題は、Frontの末尾（判定指示の前）に `<br><span style="color:#c00;font-weight:bold;">⭐ 重要</span>` を追加して視認性を高める

```html
[問題文（平叙文）]<br><br>
<span style="color:#c00;font-weight:bold;">⭐ 重要</span><br><br>
<i>（○か✕で答えよ）</i>
```

**Backフィールド（解答）:**

```html
<div style="font-size:2em;font-weight:bold;text-align:center;">[○ または ✕]</div>
<br>
<b>解説:</b><br>
[解説テキスト]
```

- 先頭に判定結果（`○` or `✕`）を大きく表示して即座に確認できるようにする
- ソースの `×` は表記揺れがあるため `✕`（U+2715 MULTIPLICATION X）に正規化する
- 解説が複数段落にわたる場合は段落間を `<br><br>` で分離する
- 解説中に条文参照（例: `民法90条`）が含まれる場合はそのまま保持する
- **出典付与（Step 5c で情報を取得した場合）**: 選択肢型と同様に Back フィールド末尾に出典 div を付与する（書籍名・ページ番号の取得状況に応じた出力形式は選択肢型の規則に準ずる）

**タグ生成（○×型・選択肢型共通の補足）:**

ソースのメタ情報をAnkiタグとして自動付与する。タグはAnkiで検索・絞り込みに利用される:

| メタ情報 | タグ例 |
|---------|--------|
| 章 | `章:第1章-私法の基本原則と法律の基礎知識` |
| 節 | `節:第1節-コンプライアンスと私法の基本原則` |
| テーマ | `テーマ:契約と約束の違い` |
| 難易度 | `難易度:★` `難易度:★★` `難易度:★★★` |
| 重要マーカー | `重要` （`**重要!**` が付与された問題のみ） |

> ⚠️ Ankiタグは空白を含めず、`-` でつなぐ。スラッシュ `/` は階層タグになる（必要に応じて活用）。

詳細なフォーマットルールは [CONTENT-COMMON.md](references/CONTENT-COMMON.md) の「フォーマット変換ルール」を参照。書籍タイプ別のパース戦略は [CONTENT-BY-TYPE.md](references/CONTENT-BY-TYPE.md)、判別マトリクスは [CONTENT-DETECTION.md](references/CONTENT-DETECTION.md) を参照。

#### 一括作成（バッチAPI推奨）

大量のカード作成（50件以上）でも、`anki_request` や `addNotes` のバッチ処理を**手書きしない**。`scripts/anki_toolkit.py` がこれらの投入インフラ（AnkiConnect クライアント・`addNotes` バッチ投入・冪等性・HTML整形）を不変ライブラリとして提供する。scaffold の `main()` から `upload()` を呼ぶだけでよい。

```python
# /tmp/parse-<descriptive-name>.py（parser_scaffold.py をコピーしたもの）の main()
from anki_toolkit import QAPair, RenderOptions, upload

# parse() がソース固有に構築した QAPair のリスト
qas = parse(md, ctx)

# field_map はノートタイプに合わせる（Step5b で modelFieldNames 確認後）
#   2フィールド: {"front": "Front", "back": "Back"}
#   資格試験系3フィールド: {"front": "Question", "back": "Answer", "extra": "Knowledge Area"}
field_map = {"front": "Question", "back": "Answer", "extra": "Knowledge Area"}

# render はノートタイプの modelTemplates に合わせる（Step5b の表参照）
#   <ol><li> シャッフルJSがある → choice_list_style="ol"（既定）
#   JSが <li> を倍増させる → choice_list_style="br"
render = RenderOptions(choice_list_style="ol")

result = upload(qas, deck_name=deck, model_name=model,
                field_map=field_map, render=render, skip_existing=True)
# result = {"added": int, "skipped_existing": int, "media_stored": int, "errors": list}
```

> 🔴 **toolkit を import しても parse は使い捨て**: 共通化したのは投入インフラだけ。`parse()` は今回のソース1冊専用に手書きし、過去のコピーを再利用しない（Step 3「同シリーズでも構造変異する前提」「ジェネリックパーサー禁止」の鉄則は不変）。toolkit が楽になったのは投入であってパースではない。

> ⚠️ **`RenderOptions` の選び方**: `upload()` / `build_note()` / `build_front_html()` / `build_back_html()` はいずれも `render: RenderOptions = RenderOptions()` を任意引数で受ける。Step5b の `modelTemplates` 確認結果に従い、メイン選択肢の `choice_list_style` を `"ol"`（シャッフルJS活用）か `"br"`（li倍増テンプレ向け）から選ぶ。`details_choice_style` は常に `"br"` 固定（変更不可のガード）。

> ⚠️ **`addNotes` のエラーレスポンス形式（toolkit が内部処理する）**: 重複カードが含まれるバッチでは、AnkiConnect が `error` フィールドを文字列ではなく**配列**（per-note errors）で返す場合がある。この場合 `result` は `null` となり、バッチ全体が失敗する。`anki_toolkit.anki_request()` はこのケースを `isinstance(error, list)` で検出して `{"per_note_errors": [...]}` を返し、`upload()` が戻り値の `errors` に集約する（この罠の根拠として記載を残す）。

> 🔴 **以下の `duplicateScope` / `allowDuplicate` / 事前フィルタ / dedup は `anki_toolkit.py` が内部で処理する**: `build_note()` が `options` に `allowDuplicate: True` + `duplicateScope: "deck"` を自動付与し、`upload(..., skip_existing=True)` が `filter_new()` で既存 Front 集合との差分を取って投入する。`dedup_deck()` は事後 dedup の保険として提供される。**したがって投入時にこれらを手書きする必要はない**。以下の散文は toolkit がなぜこの設計を採るのかの根拠であり、不変バグ発見時の参照価値があるため残す。

> ⚠️ **`addNotes` の `duplicateScope` 既定値による cross-deck バッチ全件失敗**: AnkiConnect `addNotes` の `options.duplicateScope` は既定で **collection 全体** (`"collection"`) を対象に重複判定する。そのため、別デッキ（他資格・他書籍）に同一 Front テキストのカードが1枚でも存在すると、対象デッキが全く違うにもかかわらず**バッチ全体が per-note errors で失敗**する。資格試験のような汎用的な問題文（「次の記述は正しいか」等の短い設問）で発生しやすい。**対策**: `notes` 配列の各要素で `options.duplicateScope: "deck"` を明示し、deck-local の重複チェックに切り替える。さらに `options.allowDuplicate: true` を併用すると、deck 内重複も許容できる（ただし冪等性は別途確保が必要 → 後段の dedup 知見参照）。`anki_toolkit.build_note()` がこの `options` を全 note に自動付与する。
>
> ```python
> note = {
>     "deckName": deck, "modelName": model, "fields": {...}, "tags": [...],
>     "options": {"allowDuplicate": True, "duplicateScope": "deck"},
> }
> ```

> ⚠️ **`allowDuplicate: true` 設定時の冪等性確保（再実行時 dedup）**: 知見6の `allowDuplicate: true` + `duplicateScope: "deck"` 設定はバッチ失敗を回避できるが、副作用として**スクリプトを2回実行すると deck 内に同じカードが重複追加される**。`createDeck` のような自然な冪等性は得られない。**対策**: スクリプト末尾または別ユーティリティとして以下の dedup を実装する: (1) `findNotes "deck:<deck-name>"` で全ノート ID を取得、(2) `notesInfo` で各ノートの Front を取得、(3) Front 文字列をキーに辞書化し、**最古の noteId のみ残して残りを `deleteNotes`**。これにより N 回実行しても deck 内に重複が残らない。`addNotes` 投入直前にこの dedup を走らせれば事実上の冪等化が可能。この dedup は `anki_toolkit.dedup_deck(deck_name, front_field)` として実装されており、`front_field` には AnkiConnect 上の実フィールド名（例 `"Question"`）を渡す。

> ⚠️ **既投入 Front 事前フィルタによる冪等性向上**: `addNotes` 投入前に `findNotes` + `notesInfo` で対象デッキの既存 Front 集合を Set として取得し、投入候補リストとの差分（`new_fronts - existing_fronts`）のみを投入対象にする事前フィルタを実装すると、`allowDuplicate: true` + dedup の後処理に頼らず投入前の段階で冪等性を確保できる。**利点**: (1) 重複カードが一切作成されないため `deleteNotes` コストが発生しない、(2) スクリプト再実行時に新規カードのみ追加される差分更新として機能する。**注意**: `findNotes` は Anki MCP の `find_notes` ツールまたは AnkiConnect `findNotes` アクションどちらでも利用可能。デッキ名が完全一致していることを確認すること（サブデッキは `deck:"親デッキ名::子デッキ名"` のようにクォートで囲む）。この事前フィルタは `anki_toolkit.filter_new()`（および `upload(..., skip_existing=True)` 内部）が担い、🔴 **実フィールド名**（`field_map["front"]` で決まる名前。`Front` 固定にしない。`Question/Answer/Knowledge Area` 等が普通に出る）で `build_note()` 生成後の note と既存集合を突き合わせる。

> ⚠️ **差分判定スキップ（全件投入）シナリオでの冪等性確保**: 差分判定をスキップして全件投入するシナリオ（年度版独立リソース投入等）では、以下の組み合わせで冪等性と cross-deck 衝突防止を両立させる: (1) `options.duplicateScope: "deck"` を明示して別デッキの同一Front問題と衝突しない、(2) 事前フィルタで投入対象デッキの既存Front集合をSet差分して重複を排除（再実行時の追加投入を防ぐ）、(3) `options.allowDuplicate: true` は事前フィルタがある場合は不要だが、フィルタ実装が困難なシナリオでは保険として使用可。年度版ごとに別サブデッキに配置する設計にすると、(1)だけで大半の衝突を防げる。

50件ずつのバッチ投入は `anki_toolkit.upload()` が内部で実施する（`BATCH_SIZE = 50` はモジュール定数）。手書きの投入ループは不要。

**進捗表示:**

- `upload()` が 50 件ごとに `[upload] N/total processed` を stderr へ出力する
- per-note エラーは `upload()` の戻り値 `errors` リストに集約され、最後にまとめて確認できる

#### 画像取り込み（EPUB 埋め込み画像）の責務分担

EPUB の埋め込み画像をカードに取り込む場合、**抽出と投入で責務を分ける**:

| 工程 | 担当 | 内容 |
|------|------|------|
| 画像の抽出・`<img>` 化・base64 化 | 🔴 **scaffold の `extract_images(text, ctx)`**（ソース固有） | 本文中の `![...](image_rsrcXXX...)` を `<img src="<prefix>...">` に置換し、`unzip` で EPUB から実体を取り出して base64 化する。画像参照の regex・prefix 命名はソース依存のため毎回手書きする。escape 順序の罠（プレースホルダ退避→escape→復元）に注意 |
| 画像の投入 | **toolkit の `store_media()`**（不変） | `QAPair.media`（`[{"filename","data_b64"}]`）に載せた実体を AnkiConnect `storeMediaFile` で登録する。`upload()` 内で `addNotes` 前に自動実行される（同名は上書き=冪等） |

scaffold が `extract_images()` で返した `[{"filename","data_b64"}]` を `QAPair.media` に載せ、本文には `<img src="<filename>">` を埋め込む。投入は `upload()` に任せる。

> 🔴 **`media_prefix` は必須**: filename に接頭辞を付けない汎用名（pandoc 由来の `image_rsrc001.jpg` 等）は、Anki のメディアフォルダ全体で**別ソースの既存画像を静かに上書きする**（メディアは collection 共有でデッキ分離されない）。`store_media()` は `MEDIA_PREFIX_RE`（接頭辞付きパターン）に一致しない filename を `ValueError` で拒否する。scaffold の `SourceContext.media_prefix`（例 `"<識別子>_"`）を必ず設定し、`extract_images()` が `epub_path` 指定時に `media_prefix` 未設定なら `ValueError` を出す（汎用名衝突によるデータ破壊の事前防止）。

### Step 7: 品質検証

作成完了後、**必ず以下の品質検証を実施する**（最初の実行時およびスクリプト修正後）:

1. **サンプルチェック**: `anki_toolkit.sample_cards(deck_name, head=5, mid=5)` で先頭5件・中盤5件のカードを取得し（内部で `findNotes` + `notesInfo` を実行）、以下を確認:
   - コードブロック（`<pre><code>`）の中身が空でないか
   - pandocアーティファクト（`[]`、`{.class_sXXX}`）が残っていないか
   - pandoc行折り返しが`<br>`として残っていないか（例: `AWS<br>コンソール`→`AWS コンソール`）
   - 「正解の選択肢」セクションが空でないか（特に複数正解問題）
   - 選択肢内のエスケープ文字（`\[`, `\]`, `\"`）が正しく復元されているか

   ```python
   from anki_toolkit import sample_cards
   for note in sample_cards(deck_name, head=5, mid=5):
       print(note["fields"])  # Front/Back（または Question/Answer）の整形結果を目視
   ```

2. **問題発見時**: スクリプトを修正し、既存カードを全削除→再作成する

### Step 8: 完了報告

作成完了後、以下を報告する:

- 作成したカード数
- 対象デッキ名
- スキップしたカード数（エラーがあった場合）
- 判定マーカー欠落件数（○×型のみ。タグ `判定マーカー欠落` で集計）
- 重複デダプ件数（冒頭プレビュー問題の除外件数）
- 難易度マーク別件数（`難易度::★` / `難易度::★★` / `難易度::★★★`）
- 重要マーカー付き件数（任意）
- 出典付きカード件数（Step 5c で出典付与を選択した場合）: 書籍名付き件数 / ページ番号付き件数 / 両方付き件数 / 出典なし件数

### Step 9: スキル自己改善

**作業中に発見した新たな知見（パーサーのバグ修正、新しいpandocアーティファクトパターン、構造の変異等）があった場合、完了報告後に以下を実施する。**

1. 現在のスキルファイルを読み込む:
   - `skills/creating-flashcards/SKILL.md`
   - `skills/creating-flashcards/references/CONTENT-DETECTION.md`（書籍タイプ判別・マーカー検出）
   - `skills/creating-flashcards/references/CONTENT-BY-TYPE.md`（タイプ別パース戦略・サブパターン）
   - `skills/creating-flashcards/references/CONTENT-COMMON.md`（共通処理・HTMLフォーマット・品質チェック）
2. 今回の作業で発見した知見を整理する:
   - 新しいpandocアーティファクトパターン
   - パーサーで発生したバグとその修正方法
   - 構造分析の改善点（新しい検出パターン等）
   - 品質検証で発見した問題パターン
3. 🔴 **発見知見を性質で振り分ける**（toolkit 導入後の重要ルール）。知見が「ソース非依存・不変」なら toolkit コードを修正し、「ソース固有・パース時判断」なら references の散文に追記する:

   | 発見した知見 | 性質 | 振り分け先 | バンプ |
   |------------|------|-----------|--------|
   | `addNotes` の新しいエラー形式 / 冪等性の穴 / HTML整形の出力バグ | ソース非依存・不変 | `scripts/anki_toolkit.py` をコード修正 | PATCH |
   | 新しい pandocアーティファクト / 構造パターン / 判定マーカー表記揺れ / 章見出し変異 | ソース固有・パース時判断 | references に散文追記（従来どおり） | PATCH |
   | `QAPair` に新フィールドが必要（例: 新しい問題種別） | 契約変更 | 🔴 3箇所同時更新（toolkit / scaffold / INSTRUCTIONS の CONTRACT ブロック）。本体に相談 | PATCH or MINOR |

   > 🔴 scaffold の `parse()` TODO や共通ヘルパ（`clean_pandoc` 等）の regex は**自動修正しない**（ソース固有のため）。scaffold に普遍的に効く改善（新しい共通クリーニングヘルパの追加等）のみ scaffold を編集対象に含めてよいが、`parse()` 本体は触らない。

4. 該当するスキルファイル（または toolkit コード）に知見を反映する（具体例とともに）
5. 反映内容をユーザーに提示し、AskUserQuestionで確認を得てから適用する

> ⚠️ この自己改善ステップにより、スキルは使うたびに賢くなる。発見のない場合はスキップしてよい。`/improve-creating-flashcards` コマンドがこの振り分けを自動エントリポイントとして実行する。

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

## scripts ディレクトリ（投入インフラの契約）

`skills/creating-flashcards/scripts/` の2層構成（[投入インフラの利用](#投入インフラの利用毎回の作業の前提)節の概説を参照）の**契約定義**をここに集約する。`anki_toolkit.py` の実コード・`parser_scaffold.py` の雛形・本節の3者で、`QAPair` フィールド名と公開API名は**完全一致**させる（ズレると投入が壊れる）。

### `QAPair` 中間表現（IR）スキーマ

`parse()` が返す問題1件の中間表現。`anki_toolkit.py` に `@dataclass` で定義されている。

| フィールド | 型 | 既定 | 用途 |
|-----------|-----|------|------|
| `front` | `str` | （必須・非空） | 整形前の問題本文。問題番号ヘッダー（「問N」等）は含めない |
| `back` | `str` | `""` | 整形前の解答/解説本文。🔴 raw HTML 素通し（toolkit は escape しない。`<table>` 等は parse 側が注入） |
| `qtype` | `str` | `"basic"` | `"choice"` / `"truefalse"` / `"basic"` のいずれか（他は `ValueError`） |
| `choices` | `list[str]` | `[]` | 選択肢型用。`["A. テキスト", "B. テキスト", ...]`（レター付き） |
| `correct` | `list[str]` | `[]` | 正解レター（`["A"]` / 複数正解 `["A","C"]`） |
| `wrong_explanations` | `dict` | `{}` | `{"B": "不正解解説", ...}`（レター→解説） |
| `verdict` | `str` | `""` | ○×型用。`"○"` / `"✕"` / `""`（空=判定マーカー欠落。`×→✕` / `〇→○` は toolkit が正規化） |
| `tags` | `list[str]` | `[]` | Anki タグ（階層は `::`、空白は `-`） |
| `knowledge_area` | `str` | `""` | 補助フィールド（`field_map["extra"]` の投入先） |
| `source_book` | `str` | `""` | 出典書籍名（Step5c）。空なら出典div出力しない |
| `source_page` | `str` | `""` | 出典ページ番号（Step5c）。空可 |
| `important` | `bool` | `False` | 重要マーカー（⭐重要表示 + タグ「重要」） |
| `needs_fix` | `bool` | `False` | 不完全カード（`_要手修正` タグ + 警告div） |
| `original_front` | `str` | `""` | 多言語用・原文問題（`<details>` 折りたたみ） |
| `original_back` | `str` | `""` | 多言語用・原文解答（`<details>` 折りたたみ） |
| `media` | `list[dict]` | `[]` | `[{"filename","data_b64"}]`。本文に `<img src="<filename>">` を埋めた上で実体を載せる。空なら `storeMediaFile` を呼ばない |

`RenderOptions`（HTMLレンダリング方針。Step5b の `modelTemplates` 確認結果を反映）:

| フィールド | 型 | 既定 | 用途 |
|-----------|-----|------|------|
| `choice_list_style` | `str` | `"ol"` | メイン選択肢の出力。`"ol"`=`<ol style="list-style-type:none"><li>`（シャッフルJS活用） / `"br"`=`<br>`区切り（li倍増テンプレ向け） |
| `details_choice_style` | `str` | `"br"` | `<details>` 原文内の選択肢。常に `"br"`（`<ol><li>` 倍増回避の固定ガード） |
| `front_field_is_choice_shuffle` | `bool` | `True` | 選択肢頭にレター（「ア.」「A.」等）を付与し、シャッフル後も内容で正解判定可能にする |

### `anki_toolkit.py` 公開API（サマリ）

| 関数 | シグネチャ（要点） | 役割 |
|------|------------------|------|
| `anki_request` | `(action, params=None) -> object` | AnkiConnect へ POST。error が配列なら `{"per_note_errors":[...]}`、文字列なら `RuntimeError` |
| `ensure_deck` | `(deck_name) -> None` | `createDeck`（冪等）。`addNotes` 前に必須 |
| `existing_fronts` | `(deck_name, front_field) -> set[str]` | 既存 Front 集合を実フィールド名で取得 |
| `filter_new` | `(notes, deck_name, front_field) -> (list, int)` | 既存と重複しない note のみ返す（実フィールド名で差分） |
| `dedup_deck` | `(deck_name, front_field) -> int` | 最古 noteId 残しで重複削除（事後 dedup の保険） |
| `build_note` | `(qa, deck_name, model_name, field_map, render=RenderOptions()) -> dict` | `QAPair` を addNotes 用 note に変換。`options` に `allowDuplicate:True`+`duplicateScope:"deck"` 自動付与 |
| `store_media` | `(qas) -> int` | `QAPair.media` を `storeMediaFile` で投入（同名上書き=冪等）。🔴 接頭辞なし filename は `ValueError` |
| `upload` | `(qas, deck_name, model_name, field_map, render=RenderOptions(), skip_existing=True) -> dict` | ensure_deck→store_media→build_note(全件)→filter_new→addNotes(50件ずつ)。戻り値 `{added, skipped_existing, media_stored, errors}` |
| `build_front_html` | `(qa, render=RenderOptions()) -> str` | Front HTML 生成（純関数） |
| `build_back_html` | `(qa, render=RenderOptions()) -> str` | Back HTML 生成（純関数・back は raw HTML 素通し） |
| `build_tags` | `(qa) -> list[str]` | `important→"重要"` / `needs_fix→"_要手修正"` を補完 |
| `is_code_like` | `(text) -> bool` | 翻訳スキップ判定 |
| `sample_cards` | `(deck_name, head=5, mid=5) -> list[dict]` | 先頭/中盤サンプル取得（Step7 用） |

モジュール定数: `BATCH_SIZE = 50`（投入バッチ件数）／ `MEDIA_PREFIX_RE = ^(?!image_rsrc)[A-Za-z0-9][A-Za-z0-9_-]*_`（メディア接頭辞の許可パターン。接頭辞なし汎用名 `image_rsrcXXX` を拒否し別ソースとのメディア衝突を防ぐ）。`field_map` のキーは `"front"`・`"back"` が必須、`"extra"`（`knowledge_area` の投入先）は任意。

### 🔴 機械可読 CONTRACT ブロック

以下のブロックは `QAPair` フィールド・`RenderOptions` フィールド・公開API名の**単一の真実**であり、`anki_toolkit.py` の実コードと完全一致する（検証コマンドがこのブロックを抽出して実コードと突き合わせる）。契約変更時はこのブロックと実コードを同時に更新する。

<!-- CONTRACT:BEGIN -->
QAPAIR_FIELDS: front,back,qtype,choices,correct,wrong_explanations,verdict,tags,knowledge_area,source_book,source_page,important,needs_fix,original_front,original_back,media
RENDEROPTIONS_FIELDS: choice_list_style,details_choice_style,front_field_is_choice_shuffle
PUBLIC_API: anki_request,ensure_deck,existing_fronts,filter_new,dedup_deck,build_note,store_media,upload,build_front_html,build_back_html,build_tags,is_code_like,sample_cards
<!-- CONTRACT:END -->

---

## 関連スキル

- プラグイン同梱の `scripts/` ディレクトリ（PDF→Markdown変換スクリプトの提供元）
