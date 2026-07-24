# shikaku-drill 問題収集ワークフロー

## 1. このスキルは何か / いつ使うか

shikaku-drill.com（資格ドリル）は認証不要・全問無料公開の資格・検定問題集サイト（59資格対応・教育目的）。
このスキルは、指定された資格の URL から**その資格の全問題**（問題文・カテゴリ・選択肢・正解・解説）を
巡回取得し、1 資格 1 JSON ファイル（`<slug>.json`）へ保存する。出力はそのまま `creating-flashcards`
スキルへ渡してカテゴリ別に Anki フラッシュカード化できる。

対応する入力 URL の形式:

- `https://shikaku-drill.com/<slug>.html`（資格ページ。例: `https://shikaku-drill.com/mental1.html`）
- `<slug>` 単体（例: `mental1`）でも可

全資格の slug は、トップページ `https://shikaku-drill.com/` の `<a href="*.html">` 一覧から取得できる
（`about.html`/`privacy.html`/`terms.html`/`contact.html` は資格ページではないため対象外）。

## 2. 人間の導線と実装方式

人間の操作は、資格ページの「学習スタート」ボタン（既存進捗があれば「修行開始」＋「▶ 続きから学習 N問目
...」ボタンが追加出現）から開始し、問題ページで選択肢を1つ選ぶと正解・解説が開示され、「次の問題」ボタンで
次へ進む、という順序を辿る。

本スキルの実装（`scripts/collect-shikaku-drill.sh`）は、kentei-lab（`collecting-kentei-lab-exams`）が
採用する「`/quiz/<slug>/<n>` への直接URL反復」方式が**使えない**点が根本的に異なる。shikaku-drill は
SPA 構造で URL が変化しないため、本スクリプトは以下の手順でボタン操作を模倣する。

1. 資格ページ（`https://shikaku-drill.com/<slug>.html`）を開く
2. 「全て」（絞り込み解除）→「なし」（タイマー設定解除）→「🔀 順番通り」（シャッフル無効化）の順に
   ボタンをクリックし、既定状態に統一する
3. `button` 要素のテキスト `📚 全問 N問`（正規表現 `全問\s*(\d+)問`）から総問題数 N を取得する
4. `続きから学習` を含むボタンがあればそれをクリックして resume、無ければ `学習スタート`/`修行開始`
   のテキストを含むボタンをクリックして新規開始する
5. 問題ページで `.quiz-nav`（`"N/Total..."` 形式）から現在番号を読み取り、`.q-card` 配下の
   カテゴリ・問題文・選択肢を読み取ってから選択肢を1つクリックする（正誤に関わらず解説が開示される。
   正解を当てるロジックは不要）
6. `.exp-card` 配下の正解・解説を読み取り、`<slug>.jsonl` へ1行追記する
7. 「次の問題」ボタンをクリックして次へ進む（存在しなければ最終問題に到達したとみなし終了する）

サイト自体が localStorage ベースの「続きから学習」resume 機構を持つが、これとは独立に本スキルは
進捗サイドカー `<slug>.jsonl` による二重の resume 防御を行う（§6 参照）。

## 3. 前提ツール

- **agent-browser**（Vercel Labs 製・Rust ネイティブ・CDP 直結のブラウザ自動化 CLI）。未導入なら
  `web:automating-browser` スキルの `scripts/install.sh` で導入する。
- **jq**（JSON 整形・検証）。

導入確認:

```bash
which agent-browser && agent-browser --version
which jq
```

## 4. 実行方法

```bash
scripts/collect-shikaku-drill.sh <input-url-or-slug> [output-dir]
```

| 引数/環境変数 | 説明 |
|---|---|
| `<input-url-or-slug>`（必須） | shikaku-drill.com の URL（`https://shikaku-drill.com/<slug>.html`）または slug 単体 |
| `[output-dir]`（任意） | 出力先ディレクトリ。省略時 `./shikaku-drill-output` |
| `SHIKAKU_DRILL_WAIT_MS` | 問題間の待機ミリ秒（既定 300） |
| `SHIKAKU_DRILL_MAX_N` | 取得上限（スモークテスト/部分取得用・既定 0=全件） |
| `AGENT_BROWSER` | agent-browser バイナリパス上書き（既定: `which agent-browser`） |

```bash
# 例: メンタルヘルス・マネジメント検定Ⅰ種を全問取得
scripts/collect-shikaku-drill.sh https://shikaku-drill.com/mental1.html ./shikaku-drill-output

# 例: 最初の5問だけ試しに取得（スモークテスト）
SHIKAKU_DRILL_MAX_N=5 scripts/collect-shikaku-drill.sh mental1 /tmp/mental1-test
```

大規模資格（数百問）は取得に時間がかかる。**`run_in_background: true` での実行を推奨する**。
中断しても resume（§6）により安全に再開できる。

## 5. 出力フォーマット（JSON）

- 1 資格 = 1 最終成果物: `<output-dir>/<slug>.json`
- 加えて内部の進捗（resume）用サイドカー（JSON Lines・1 問 1 行）: `<output-dir>/<slug>.jsonl`

最終成果物 `<slug>.json` のスキーマ（kentei-lab のスキーマに `category` を追加した拡張形）:

```json
{
  "exam_title": "<試験名>",
  "slug": "<slug>",
  "source_url": "https://shikaku-drill.com/<slug>.html",
  "collected_at": "<ISO8601 UTC>",
  "total_questions": 300,
  "questions": [
    {
      "number": 1,
      "category": "<カテゴリ名（絵文字除去済み）>",
      "question": "<問題文>",
      "choices": ["A. <選択肢A>", "B. <選択肢B>", "C. <選択肢C>", "D. <選択肢D>"],
      "answer": "B. <正解本文>",
      "explanation": "<解説文>"
    }
  ]
}
```

- `exam_title` はページの `document.title` から取得する（`<h1>` 要素は存在しない。実機確認済み）。
  `"<試験名> | 資格ドリル"` という形式のため、サイト名サフィックス `" | 資格ドリル"` を除去したものを使う。
- `category` は `.q-card .q-cat-badge` の `textContent` から先頭の絵文字＋半角スペースを除去したもの。
- `choices` は取得できた数だけ格納する（4択決め打ちではない）。各要素は `.ch-alpha`（レター）＋
  `.ch-body`（本文）を `"<レター>. <本文>"` 形式で結合したもの。
- `answer` は `.exp-card .exp-correct-bar.ok .exp-correct-text` の `textContent` をそのまま使う
  （kentei-lab と異なり "正解は" 等の接頭辞除去は不要。既にレター＋本文の結合文字列で取得できる）。
- `total_questions` は試験の総問題数 N。`SHIKAKU_DRILL_MAX_N` で部分取得した場合、`questions` の
  要素数は N より少なくなる。
- この JSON はそのまま `creating-flashcards` スキルへ渡せる（同スキルが `scripts/shikaku_drill_import.py`
  で構造推測をスキップして Anki に一括登録する）。kentei-lab と異なり、Anki デッキは**問題単位**で
  `検定試験::<検定名>::<級>::shikaku-drill::<カテゴリ名>`（級を検出できない試験は
  `検定試験::<検定名>::shikaku-drill::<カテゴリ名>`）へ自動振り分けされる（1ファイルに複数カテゴリの
  問題が混在するため）。
- ⚠️ 同一会話内で直接ブリッジする場合の実務上の注意（`disable-model-invocation` によるSkillツール不可・
  `${CLAUDE_PLUGIN_ROOT}` 未設定・デッキ名衝突確認等）は `creating-flashcards` の INSTRUCTIONS.md
  「shikaku-drill 収集済み JSON のファストパス」節を参照。

## 6. 中断・再開（resume）

サイト自体が localStorage ベースの「続きから学習」resume 機構を持ち、`▶ 続きから学習 N問目 ...`
ボタンから正確な位置に復帰できる（実地検証済み）。ただし、この localStorage は agent-browser の
ブラウザプロセスが起動し直されると引き継がれない場合がある（実機確認: 別プロセスでの再実行では
毎回「学習スタート」から開始した）。

そのため本スキルは、サイト側resumeとは独立に**進捗サイドカー `<slug>.jsonl` による二重の防御**を行う。

- ループの各問題で、現在番号（`.quiz-nav` から取得）が既に `<slug>.jsonl` に記録済みかを判定する。
- **記録済みなら**: 問題文・選択肢等の再抽出・再記録はせず、選択肢を1つクリックして解説を開示させ
  「次の問題」をクリックするだけの軽量パス（スキップ）を通る（実機確認済み: 新しいブラウザプロセスで
  「学習スタート」から再開しても、既収集分は数百ms程度のクリック連打で正しい位置まで追従できる）。
- **未記録なら**: 通常どおり抽出・記録する。
- 破損した末尾行（プロセス強制終了などによる書き込み途中の行）への対処は行っていない（kentei-lab と
  異なり単純な `>>` 追記のみ。破損を検出した場合は該当行を手動で除去してから再実行すること）。
- 各問題を追記した後、スクリプト末尾（および全問取得済みでの早期終了時）に `<slug>.jsonl` 全行から
  最終成果物 `<slug>.json` を再構築する。したがって任意のタイミングで中断しても次回実行時にその続きから
  安全に再開でき、最終 JSON も常に最新の全収集分を反映する（同一問題の重複保存は起きない）。

## 7. サイトへの配慮

shikaku-drill.com は無料公開・認証不要の教育目的サイトである。本スクリプトは既定で問題間に 300ms の
待機を挟み、サーバへの負荷を抑える（`SHIKAKU_DRILL_WAIT_MS` で調整可）。大量取得を行う際も、教育・個人
利用目的での節度ある利用に留めること。

## 8. トラブルシュート

| 症状 | 対処 |
|---|---|
| 総問題数(N)が取得できずエラー終了する | サイトのボタン文言（`📚 全問 N問`）が変わった可能性がある。`agent-browser open https://shikaku-drill.com/<slug>.html` してボタン文言を目視確認し、スクリプトの `get-n.js` の正規表現を調整する |
| 開始/続きボタンが見つからずエラー終了する | 「続きから学習」「学習スタート」「修行開始」のボタン文言が変わった可能性がある。`click_first_matching` へ渡す候補文字列を調整する |
| 問題ページの読み込みを検出できない（`.quiz-nav が出現しません`） | DOM 構造が変わった可能性がある。`agent-browser open` して DOM を目視確認し、`.quiz-nav` セレクタを調整する |
| 問題文/選択肢/正解/解説が取得できずエラー終了する | `.q-card`/`.q-cat-badge`/`.q-text`/`.choices .choice`/`.ch-alpha`/`.ch-body`/`.exp-card`/`.exp-correct-bar.ok .exp-correct-text`/`.exp-body` のいずれかの DOM 構造が変わった可能性がある。`agent-browser eval --stdin` で該当 JS を手動実行し、セレクタを調整する |
| 選択肢の数が資格により異なる | 想定内。スクリプトは選択肢数を決め打ちせず、取得できた分だけ列挙する |
| exam_title に想定外のサイト名サフィックスが残る | `document.title` の形式（`"<試験名> | 資格ドリル"`）が変わった可能性がある。`get-title.js` の除去用正規表現を調整する |
| agent-browser デーモンが不調（接続エラー等） | `agent-browser doctor --fix` で診断・修復し、必要なら `agent-browser close --all` してから再実行する |

## 9. やってはいけないこと

shikaku-drill の全問題データはクライアント側の JS/localStorage に埋め込まれている可能性が高いが、
**これを直接パースして問題データを抜き出す実装は行わない**（kentei-lab と同じ方針）。サイト更新で容易に
壊れる上、意図された表示範囲を超えてデータへアクセスすることになるため、本スキルは常にレンダリング後の
DOM を読む方式のみを採用する。

## 補足: agent-browser eval の呼び出し方

`agent-browser` の一部バージョン（導入検証時点: 0.33.0）には、外部ドキュメントに記載のある
`eval --file <path>` オプションが実装されていないことがある。JS を渡す際は
`agent-browser eval --stdin < script.js`（またはヒアドキュメント）を使う。`scripts/collect-shikaku-drill.sh`
はこの方式で実装済み。
