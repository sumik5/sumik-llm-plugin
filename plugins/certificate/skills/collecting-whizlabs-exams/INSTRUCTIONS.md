# Whizlabs 問題収集ワークフロー

## 1. このスキルは何か / いつ使うか

Whizlabs は認証必須の資格・検定対策プラットフォーム。1 コースに複数のクイズ（Free Test・Practice Test 1〜N
等、それぞれ別 quiz-id）が紐づき、コース一覧ページ（`/pt`）から各クイズを個別に開始する。

このスキルは、指定されたコース practice test 一覧 URL から**そのコース配下の全クイズ**（問題文・選択肢・
正解・解説・参考資料）を practice mode で巡回取得し、1 クイズ 1 JSON ファイル
（`<course-slug>__<quiz-slug>.json`）へ保存する。出力はそのまま `creating-flashcards` スキルへ渡して
クイズごとに Anki フラッシュカード化できる。

対応する入力 URL の形式:

- `https://www.whizlabs.com/learn/course/<slug>/<course-id>/pt`（コース practice test 一覧ページ）

## 2. 人間の導線と実装方式

人間の操作は、コース一覧ページの各クイズ行の「Start」（または Free Test は「Free」）ボタン → 「Start Quiz」
→ モーダルで「Start quiz as practice mode」をチェック → 「Start」→ 問題ページを 1 問ずつ進める、という
順序を辿る。

本スキルの実装（`scripts/collect-whizlabs.sh`）は、kentei-lab 版のような**直接 URL 反復では取得できない**。
以下の実機調査で確定した Whizlabs 固有の挙動を利用する。

- **コース一覧からのクイズ検出（インデックス順クリック方式）**: 一覧ページの各クイズ行（`.box-item`）は
  クリック可能な `<a href>` を一切持たない。quiz-id は一覧ページの DOM には一切埋め込まれておらず、
  `.box-item .name`（React のイベントハンドラでクリックされる div。onclick 属性は DOM に出ない）を
  クリックして初めてクイズ詳細ページ（例: `/learn/course/<slug>/<id>/quiz/54753/ft/?section_heading=...`）
  へ遷移し、その遷移後 URL から quiz-id を読み取れる。したがって本スキルの実装は、一覧ページで
  `.box-item .name` の**タイトル一覧のみ**をインデックス順に取得し、各インデックス `i` について
  「コース一覧を開き直す → インデックス `i` の `.name` をクリック → 遷移後の URL（`agent-browser get url`）
  を取得 → 正規表現 `/quiz/([A-Za-z0-9_-]+)/` で quiz-id を抽出」という手順を繰り返して全クイズの
  quiz-id を確定する。1 クイズの処理ごとに一覧ページを開き直すのは、前のクイズ処理でページが詳細ページ側へ
  遷移済みのため。
- **URL は固定される**: `/learn/course/<slug>/<course-id>/quiz/<quiz-id>/practice/start/?section_heading=...`
  のまま変わらない。問題送りは SPA 内部状態で管理されるため、URL 遷移では問題を切り替えられない。
- **問題間ナビゲーション**: 画面下部の問題番号 `li`（"1","2",...,"N"）を `eval` で
  `document.querySelectorAll('li')` から `textContent` 一致要素を `.click()` して任意の番号へジャンプする
  （`snapshot -i` の ref 経由は可視範囲外の要素で不安定なため使わない）。「Next」リンクでも 1 問ずつ進められ、
  番号 `li` が画面に載らない場合のフォールバックとして使う。最終問題では「Next」の代わりに「Submit」が出るが
  **Submit は絶対に押さない**（§9 参照）。
- **選択肢クリック不要**: `show Answer` ボタン（`.content button.btn-showAnswer`）をクリックするだけで
  正解・解説・参考資料が全開示される（kentei-lab とは逆で選択肢を選ぶ必要がない）。
- **DOM 構造**（実測 outerHTML から確定）:
  - `.que-category`: `<strong>Domain:</strong> <ドメイン名>`
  - `.total-questions`: `Question N of M`（総問題数 M の取得元）
  - `.content > div > p`: 問題文
  - `.content fieldset.Questions-list .radio-ans`: 選択肢 1 件の div。`input[type=radio]`（単一選択=MCSR）
    または `input[type=checkbox]`（複数選択=MCMR）＋ `span` 内にレター文字（"A. " 等）＋
    `div.dangerouslySetInnerHTML > p` に選択肢テキスト
  - `.content .explanation-block`: 解答ブロック（生 HTML）。`<p><strong>Correct Answer: X</strong></p>` に
    続き `<p>`/`<ul><li>`（各選択肢の正誤理由）、末尾に `<p><strong>Reference:</strong></p>` と参考 URL の
    `<ul><li><a href="...">` が続くことがある（無い問題もある）
- **リロード・タブクローズで進捗が失われる**: `/quiz/<id>/practice/start/` からリロードすると
  `/quiz/<id>`（テスト詳細ページ）に戻り「Start Quiz」からやり直しになる。「Resume Later」ボタンは実効性が
  ない（§6 参照）。
- **Exit Quiz は3段階フロー**: ①「Exit Quiz」リンクをクリックすると**カスタムモーダル**が開く。中身は
  3ボタン（`Submit` / `Resume Later` / 離脱確認ボタン）で、`Submit`・`Resume Later` は絶対に押さない
  （§9 参照）。②離脱確認ボタン（🔴 実機確認済み: `textContent` は `"Quit"`・`class` に `btn-quit` を持つ。
  長い確認文 `"You'll lose your progress, are you sure you want to leave?"` は `textContent` ではなく
  `aria-label` 属性の値。`agent-browser snapshot` は accessibility tree 表示のため `aria-label` を優先して
  見せており、これを `textContent` と誤認していたのが当初の実装ミス）をクリックすると、
  **ブラウザネイティブの `window.confirm()`** が発生し、`agent-browser` コマンドがブロックされる
  （"A JavaScript confirm dialog is blocking the page" 警告）。③`agent-browser dialog accept` でこれに
  応答して初めてテスト詳細ページへ離脱できる（§8 参照）。カスタムモーダルのクリックを飛ばして
  `dialog accept` だけ呼ぶと、ダイアログがまだ出ていない状態で応答することになり "No dialog is showing"
  相当のエラーになるか、モーダルが開いたまま次の処理に進んでしまう。
  🔴 **重要（実機確認済み）**: 離脱確認ボタン（"Quit"）のクリックは `agent-browser eval` 内で同期的に
  `window.confirm()` を発火させるため、その `eval` コマンド自体が「confirm dialog にブロックされている」
  エラーで返ってくる（応答が返せなかっただけで、クリック＝`confirm()` の発火自体は成功している）。
  したがって `eval` の成否（`.ok` の有無）で `dialog accept` を呼ぶかどうかを分岐してはならない。
  **`eval` の成否に関わらず必ず `dialog accept` を呼ぶ**（本当に離脱確認ボタンが見つからなかった場合は
  `dialog accept` も "No dialog is showing" で失敗するだけで、どちらのケースも許容し後続処理を止めない）。
  この分岐を誤ると、`dialog accept` が一度も呼ばれずダイアログが残留し、以降の全ての `open`/`eval` が
  ブロックされ続けて後続クイズが総崩れになる（confirm() が発火するのは「Quit」ボタンクリック時のみで、
  ①「Exit Quiz」リンククリックはカスタムモーダルを開くだけでネイティブダイアログは発生しないため対象外）。

## 3. 前提ツール

- **agent-browser**（Vercel Labs 製・Rust ネイティブ・CDP 直結のブラウザ自動化 CLI）。未導入なら
  `web:automating-browser` スキルの `scripts/install.sh` で導入する。
- **jq**（JSON 整形・検証）。
- **ログイン認証情報**: Whizlabs はメール＋パスワードでのログインが必須。**このスキルを起動したら最初に
  ユーザーへユーザー名・パスワードを尋ねる**（AskUserQuestion または通常の対話で確認する。ハードコード・
  恒久保存はしない）。

導入確認:

```bash
which agent-browser && agent-browser --version
which jq
```

### state save/load によるセッション永続化

🔴 実機確認済み: Whizlabs に専用ログインページ（`/login`）は存在しない（404）。ログインフォームは
トップページ（またはどのページからでも）右上の「Sign In」ボタンをクリックして初めて開く**モーダル型**で、
クリック前は `input[type=email]` 等のフォーム要素自体が DOM に一切存在しない
（実機確認: `document.querySelectorAll('input[type=email]').length === 0`）。agent-browser の
`auth save`/`auth login`（Auth Vault）は「ページを開けばフォームが見えている」ことを前提にフィールドを
自動検出する仕様のため、モーダルを開くための事前クリックを行う手段がなく使用できない（`--url` にトップ
ページを指定しても `input[type=email]` 系セレクタのタイムアウトで失敗する）。

代わりに **`agent-browser state save`/`state load`** でブラウザセッションそのものを保存・復元する。

```bash
# 初回ログイン（実機確認済みの手順）
agent-browser open https://www.whizlabs.com/
agent-browser wait --load networkidle
# "Sign In" ボタンをクリックしてモーダルを開く（textContent完全一致 "Sign In" のうち
# ヘッダー側のボタン。クリック後 input[type=email] の出現を待てばよい）
agent-browser eval --stdin <<'JS'
(() => {
  const buttons = Array.from(document.querySelectorAll('button'));
  const btn = buttons.find((b) => (b.textContent || '').trim() === 'Sign In');
  if (!btn) return { error: 'sign-in-button-not-found' };
  btn.click();
  return { ok: true };
})()
JS
agent-browser wait "input[type=email]"
agent-browser fill "input[type=email]" "${WHIZLABS_USERNAME}"
agent-browser fill "input[type=password]" "${WHIZLABS_PASSWORD}"
# モーダル内の Sign In ボタン（フォーム送信用。ヘッダーのボタンとは別要素。
# input[type=password] の近傍にあるボタンを選ぶ）をクリック
agent-browser wait --load networkidle
# ログイン確認: ヘッダーに textContent 完全一致 "Sign In" の button が0件になることで判定できる
# （実機確認済み: "Hello, " 文言はハンバーガーメニュー展開時のみ現れ、通常表示のDOMには
#   含まれないため判定に使えない）

# セッション保存（ログイン確認後）
agent-browser state save <path>.json

# 以降の実行（同一実行内・次回実行とも）
agent-browser --state <path>.json open <course-list-url>
```

`scripts/collect-whizlabs.sh` は起動時に環境変数 `WHIZLABS_STATE_FILE`（既定
`<output-dir>/.whizlabs-state.json`）が存在すれば `--state` 付きでコース一覧を開いてログイン済みか確認し
（Sign In ボタンが見える＝期限切れとみなし、上記手順で再ログインして state を再保存する）、存在しなければ
新規にログインして state を保存する。**ログイン確立後は同一ブラウザプロセス内でログイン状態が保持される
ため、以降のクイズ処理では再認証は不要**（実機確認済み: 一度ログインすれば `state save`/`load` を都度
行わなくてもログイン状態は保持され続ける）。

🔴 **state ファイルはセッショントークンを含む秘匿情報**であり、コミット対象にしてはならない。
`WHIZLABS_STATE_FILE` の既定値は `<output-dir>` 配下（リポジトリ外の作業ディレクトリ）に置かれる設計に
しており、明示的に別パスを指定する場合もリポジトリ配下は避けること。

## 4. 実行方法

```bash
scripts/collect-whizlabs.sh <course-list-url> [output-dir]
```

| 引数/環境変数 | 説明 |
|---|---|
| `<course-list-url>`（必須） | Whizlabs のコース practice test 一覧 URL（`/learn/course/<slug>/<course-id>/pt`） |
| `[output-dir]`（任意） | 出力先ディレクトリ。省略時 `./whizlabs-output` |
| `WHIZLABS_USERNAME` | ログイン用メールアドレス（state 未保存時に必須） |
| `WHIZLABS_PASSWORD` | ログイン用パスワード（state 未保存時に必須。**ログ・シェルトレースへは出力しない**。`agent-browser fill` の仕様上コマンド引数として渡る点に留意する） |
| `WHIZLABS_STATE_FILE` | agent-browser state ファイルパス（既定 `<output-dir>/.whizlabs-state.json`。秘匿情報のためコミット対象にしない） |
| `WHIZLABS_WAIT_MS` | 問題間の待機ミリ秒（既定 300） |
| `WHIZLABS_MAX_N` | 1 クイズあたりの取得上限（スモークテスト/部分取得用・既定 0=全件） |
| `AGENT_BROWSER` | agent-browser バイナリパス上書き（既定: `which agent-browser`） |

```bash
# 例: CCSP コースの全クイズを収集
WHIZLABS_USERNAME="user@example.com" WHIZLABS_PASSWORD="********" \
  scripts/collect-whizlabs.sh \
  https://www.whizlabs.com/learn/course/certified-cloud-security-professional/199/pt \
  ./whizlabs-output

# 例: 最初の5問だけ試しに取得（スモークテスト）
WHIZLABS_MAX_N=5 scripts/collect-whizlabs.sh <course-list-url> /tmp/whizlabs-test
```

1 コースに複数クイズ（Free Test・Practice Test 1〜7 等、計 100 問超級が複数含まれることが多い）が含まれ、
全クイズ収集は長時間になる。**`run_in_background: true` での実行を推奨する**。1 クイズを 1 回の実行単位と
みなし、100 問超クイズ（Practice Test 等）はクイズ単位で分割実行することを推奨する（§6 参照）。

## 5. 出力フォーマット（JSON）

- 1 クイズ = 1 最終成果物: `<output-dir>/<course-slug>__<quiz-slug>.json`
- 加えて内部の進捗（resume）用サイドカー（JSON Lines・1 問 1 行）:
  `<output-dir>/<course-slug>__<quiz-slug>.jsonl`

最終成果物のスキーマ:

```json
{
  "course_title": "<コース名>",
  "course_url": "<引数で渡された一覧ページURL>",
  "quiz_title": "<クイズ名（例: Free Test, Practice Test 1）>",
  "quiz_id": "<Whizlabs内部のquiz識別子>",
  "collected_at": "<ISO8601 UTC>",
  "total_questions": 25,
  "questions": [
    {
      "number": 1,
      "domain": "<Domain: の後続テキスト>",
      "question": "<問題文>",
      "choices": ["A. Management Plane", "B. Control Plane", "C. Data Plane", "D. Logic Plane"],
      "choice_type": "single",
      "correct": ["B"],
      "explanation_html": "<Correct Answer行を除く解説HTML（Reference含む）>"
    }
  ]
}
```

- `choice_type`: `"single"`（radio）/ `"multiple"`（checkbox）。DOM の input type から自動判定。
- `correct`: レターの配列（MCMR なら複数要素）。`explanation_html` 直前の "Correct Answer: X" から抽出する。
  MCMR（複数選択）は実例未確認のため、実装・運用時に見つかった表記パターンに応じて抽出ロジックを調整する
  可能性がある。
- `explanation_html` は Reference（参考 URL リスト）を含む生 HTML をそのまま保持する（`creating-flashcards`
  の `back` フィールドが raw HTML 素通し仕様のため、情報を落とさない）。
- 進捗サイドカー `<course-slug>__<quiz-slug>.jsonl` は kentei-lab と同じ 1 問 1 行 JSON Lines 方式。

この JSON はそのまま `creating-flashcards` スキルへ渡せる（同スキルが `scripts/whizlabs_import.py` で
構造推測をスキップして Anki に一括登録する）。デッキ名は既定で `資格試験::<course_title>::<quiz_title>::whizlabs`
に登録される（詳細は `creating-flashcards` の INSTRUCTIONS.md「whizlabs 収集済み JSON のファストパス」節を
参照）。

## 6. 中断・再開（resume）

🔴 kentei-lab と異なり、**resume は同一ブラウザプロセス内でのみ有効**。進捗用サイドカー
`<course-slug>__<quiz-slug>.jsonl` へ 1 問ごとに逐次追記するが、これは「同一クイズ試行内で取得済みの
問題番号までスキャンし、続きの番号へジャンプして再開する」という擬似 resume に留まる
（実測: リロードすると `/quiz/<id>` のテスト詳細ページに戻り「Start Quiz」からやり直しになる。
「Resume Later」ボタンは実効性なし——「Your Previous Attempts」は「No Attempts Found」のまま）。

- agent-browser デーモン・ブラウザプロセスが生きている間は、`.jsonl` の最大取得済み番号 +1 へ SPA 内
  ジャンプして続行できる。
- ブラウザ/agent-browser デーモンが死んだ場合、そのクイズは「Start Quiz」から最初からやり直しになる
  （kentei-lab の「プロセスが落ちても `/quiz/<slug>/<n>` へ直接アクセスすれば続きから取得できる」resume
  とは強度が異なる）。
- そのため **1 クイズを 1 回の `run_in_background` 実行単位にすることを推奨する**。100 問超クイズ
  （Practice Test 等）は特に、途中で失敗したら該当クイズのみ再実行する運用でカバーする。

## 7. サイトへの配慮

Whizlabs は認証必須の有料コンテンツを含むプラットフォームである。本スクリプトは既定で問題間に 300ms の
待機を挟み、サーバへの負荷を抑える（`WHIZLABS_WAIT_MS` で調整可）。**本スキルはユーザー自身が正規に
受講権限を持つコースの個人学習目的でのみ使用する前提**とする。第三者への再配布・商用利用は対象外。

## 8. トラブルシュート

| 症状 | 対処 |
|---|---|
| コース一覧からクイズを検出できない（「クイズを検出できませんでした」でエラー終了する） | `.box-item .name` のセレクタが変わった可能性がある。`agent-browser open <course-list-url>` して DOM を目視確認し、`get-quiz-titles.js`/`click-quiz-index.js` のセレクタを調整する |
| 総問題数(N)が取得できずエラー終了する | `.total-questions` の文言が変わった可能性がある。`agent-browser open <quiz-url>` してテキストを目視確認し、スクリプトの正規表現を調整する |
| 問題文/選択肢/正解/解説が取得できずエラー終了する | DOM 構造が変わった可能性がある。`agent-browser eval --stdin` で読み取りスクリプト相当を手動実行し、セレクタを調整する |
| 「A JavaScript confirm dialog is blocking the page」警告でコマンドが 120 秒タイムアウトする | 🔴 この警告自体は「Quit」ボタンクリック時に `window.confirm()` が同期発火するため正常に発生する（`eval` コマンドが応答を返せずエラー扱いになるだけで、クリック自体は成功している）。本スクリプトは `eval` の成否に関わらず必ず直後に `agent-browser dialog accept` を呼ぶ設計にしているため通常は自動解消する（§2 参照）。以降も `open`/`eval` が延々ブロックされ続ける場合は、`eval` の成否で `dialog accept` の呼び出しを分岐する実装に退行していないか（旧実装のバグ）スクリプトを確認する |
| Exit Quiz 後もページがテスト詳細ページへ遷移せず後続クイズが軒並み失敗する | `dialog accept` が一度も呼ばれずダイアログが残留した可能性が高い（`eval` の `.ok` 判定で `dialog accept` 呼び出しを分岐している実装は confirm() 発火時に必ず失敗する。§2 参照）。`agent-browser eval --stdin < click-leave-confirm.js` の成否を無視し、直後に無条件で `agent-browser dialog accept` を呼ぶ実装になっているか確認する。手動復旧は `agent-browser dialog accept` を単発実行するか、`agent-browser close --all` してから再実行する |
| 問題番号 `li` が画面に見当たらない/クリックできない | 番号がページング/仮想化されている可能性がある。「Next」リンクを 1 問ずつクリックするフォールバックに切り替える |
| agent-browser デーモンが不調（接続エラー等） | `agent-browser doctor --fix` で診断・修復し、必要なら `agent-browser close --all` してから再実行する |
| MCMR（複数選択）問題で `correct` が正しく抽出できない | "Correct Answer:" の表記パターンを実測し、抽出ロジック（正規表現）を調整する。実例が見つかるまでは `choice_type: "multiple"` のみ設定し `correct` は空配列で許容する |
| ログインに失敗する | `WHIZLABS_STATE_FILE` の state が期限切れの可能性がある。ファイルを削除して再実行し、新規ログイン→ state 再保存のフローを踏ませる |

## 9. やってはいけないこと

- **Submit ボタンを絶対に押さない**: 最終問題でのみ出現し、押すと本番受験として履歴に記録される可能性が
  ある。収集は必ず Exit Quiz + `agent-browser dialog accept` で離脱する。
- **Resume Later ボタンも押さない**: 効果がなく、離脱手順を妨げるだけ。
- **Free Test 以外は自分がアクセス権を持つコースのみを対象にする**: Whizlabs は有料コンテンツを含む
  プラットフォームであり、受講権限のないコースへのアクセスは対象外とする。
- **パスワードをログ・コマンド履歴・出力ファイルに残さない**: 認証情報は環境変数経由でのみ扱い、
  `set -x` 等でシェルトレースへ出力しない。state ファイル（`WHIZLABS_STATE_FILE`）はセッショントークンを
  含む秘匿情報のため、コミット対象にせず出力ディレクトリ配下に留める。
