# studying 問題収集ワークフロー

## 1. このスキルは何か / いつ使うか

studying（スタディング, `member.studying.jp`）は認証必須の資格・検定対策プラットフォーム。1 コースの
コーストップページに「基本講座」「スマート問題集」「セレクト過去問集（学科試験対策）」
「セレクト過去問集（実技試験対策）」の4セクションが並び、各セクション内に科目単位（例: 著作権法・特許法
実用新案法・意匠法・商標法…）の項目が列挙される。

このスキルは、指定されたコースレッスン一覧 URL から**「スマート問題集」「セレクト過去問集（学科試験対策）」
「セレクト過去問集（実技試験対策）」の3セクション配下の全科目**（問題文・選択肢・正解・解説）を科目単位で
取得し、1 科目 1 JSON ファイル（`<course-slug>__<category-slug>__<subject-slug>.json`）へ保存する。
「基本講座」セクションは対象外（問題集ではなく講座教材のため）。出力はそのまま `creating-flashcards`
スキルへ渡して科目ごとに Anki フラッシュカード化できる。

対応する入力 URL の形式:

- `https://member.studying.jp/course/id/<course_id>/`（コースレッスン一覧＝コーストップページ）

## 2. 人間の導線と実装方式

人間の操作は、コーストップページの各セクション内で科目の折り畳み要素をクリックして展開し、出現した
科目リンク（`https://member.studying.jp/course/practice/index/id/<practice_id>/f/0/`）を開き、
科目ページの「練習モード」「本番モード」「復習モード」いずれかで問題を解いていく、という順序を辿る。

本スキルの実装（`scripts/collect-studying.sh`）は、Whizlabs 版のような**1問ずつの SPA ナビゲーション
（番号クリック → 選択肢確認 → Show Answer → Next）は一切不要**。以下の実機調査で確定した studying 固有の
挙動を利用し、収集ロジックを大幅に単純化している。

- **🔴 科目トグルの展開（実機確認済み・コース全体スモークテスト`https://member.studying.jp/course/id/2689/`
  で再検証済み）**: 各セクション内の科目項目は `.m-ctop-course-d-list__link`（`onclick` 属性を持つdiv）で、
  初期状態では科目ページへのリンクが DOM に存在しない。クリックして展開すると、`toggle.closest('li')` で
  取得できる科目1件分の `<li>` 配下に該当科目のリンクが1件出現する（リンク先パターン:
  `course/practice/index/id/<practice_id>/f/0/`）。科目名は `toggle.querySelector('.m-ctop-course-d-list__name')`
  の textContent（`.trim()`のみでよい）から取得する（`toggle.textContent` をそのまま使うと進捗表示
  「6/6」等や大量の空白・改行が混入し不正なファイル名になる不具合があったため確定セレクタに置き換えた）。
  本スクリプトはコーストップページ上で3セクション（スマート問題集・セレクト過去問集学科・セレクト過去問集
  実技）配下の `.m-ctop-course-d-list__link` を全部 `eval`（非同期関数）でクリックし、出現したリンクから
  `practice_id` を一括収集する。
  🔴 **クリック直後の待機が必須**: クリック直後は展開アニメーションが完了しておらずDOMに未反映のため、
  各トグルクリック後に約500ms（`await new Promise(r => setTimeout(r, 500))`）待機してからリンクを探索する。
  この待機が無いと大半の科目が `practice-link-not-found-after-click` で検出漏れになる（実機スモーク
  テストで17件中16件が検出漏れになる不具合として確認済み）。agent-browser の `eval` は async 関数が返す
  Promise を正しく解決できることを実機確認済み。
  🔴 **「セレクト過去問集（実技試験対策）」も同一UI基盤であることを実機確認済み**（著作権法科目で同じ挙動
  を確認）。ただし科目ページ内部（`.list_question`/`.list_answer` 構造）そのものは実技側で未確認のまま
  （§7参照）。
- **🔴 最重要（科目単位の一括表示ページ方式）**: 科目ページ内の「解説一覧表示」リンク
  `https://member.studying.jp/course/practice/list/id/<practice_id>/a/on/` に**直接アクセスするだけで、
  その科目に含まれる全問題・全選択肢・正解・解説・学習のポイントが1回のページ読み込みで一括表示される**。
  したがって `practice_id` さえ判明すれば「開く → 読み取る」の2コマンドで科目1件分の全データを取得できる。
  Whizlabs のような Exit Quiz の3段階フロー・`window.confirm()` 処理は一切不要。
- **🔴 問題ブロックの DOM 構造（実機確認済み・practice_id=223147〈スマート問題集・○×形式〉/
  223168〈セレクト過去問集・4択形式〉で agent-browser により再検証済み）**: 問題ブロックは
  `.list_question`、解答ブロックは `.list_answer` が同数でインデックス対応するペアとして存在し、
  `document.querySelectorAll('.list_question')`/`.list_answer` で直接取得できる（件数一致探索は不要）。
  - **メタ情報**: 科目ページ上部のメタ情報のテキスト出現順は「N分 → N問 → 合格ライン...」（時間が先・
    問題数が後）。例:「41分」「27問」「合格ライン 22点（27点満点）」がこの順で近接して出現する。
  - **問題文**: `.list_question .redactor-editor` のテキスト。
  - **4択形式の選択肢**: `.list_question ol.kanalist > li` が4件存在し、各 `li` のテキストがそのまま
    選択肢1つ分（マーカー文字「ア/イ/ウ/エ」はCSS側で付与されテキストノードには含まれないため、
    出現順に機械的に割り当てる）。
  - **○×形式との判定**: `ol.kanalist` の有無で判定する。○×形式では `ol.kanalist` 自体が存在しない
    （`.list_question` は `<div class="redactor-editor"><p>...</p></div>` のみ）。
  - **正解**: `.list_answer` 側の `h4 .notosans-mark` の textContent がそのまま正解（4択なら例 "ウ"・
    ○×形式なら "○"/"×"）。「適切。」「不適切。」等の文字列マッチングによる推定は不要
    （当初はこの文字列マッチング方式で実装していたが、問題文自体に「ア〜エを比較して」等「ア」「エ」
    が偶然含まれるケースがあり選択肢境界を誤検出する不具合があったため、確定した DOM 構造ベースの
    抽出に置き換えた）。
  - **各選択肢の解説**: `.list_answer ol.kanalist > li`（`.list_question`側と同じ4件構造）のテキストを、
    選択肢と同じ順序で解説として保持する。
  - **学習のポイント**: `.list_answer table.gakusyu` のテキスト。解説文の末尾に結合する。
  - **🔴 表形式の選択肢（`table.transtable`・実機確認済み: `practice_id=223168`の5問目）**: `ol.kanalist`
    を持たない設問の一部は、空欄補充の組み合わせを選ぶタイプの設問で `table.transtable` という表要素で
    選択肢を表現する。`kanalist`形式と異なり、この表は**各行（`tr`）の最初の`td`に「ア.」「イ.」「ウ.」
    「エ.」というレター文字列が本物のテキストノードとして含まれる**ため、各`tr`の全`td`テキストを結合
    すればレター込みの選択肢文になる（`LETTERS`配列によるレター割り当ては不要）。この形式の設問は
    `.list_answer`側も`ol.kanalist`・`table.gakusyu`のどちらも持たず、`.redactor-editor`直下の`<p>`に
    解説がまとまっている（選択肢ごとの個別解説には分かれていない）。正解マーク（`h4 .notosans-mark`）は
    通常どおり取得できる。
  - **choice_type判定の優先順位（実機確認済み）**: ①`kanalist`または`table.transtable`のいずれかが
    あれば`"single"`、②どちらも無くても正解マークが`"○"`/`"×"`なら`"boolean"`、③どちらにも当てはまら
    ない場合のみ`"unknown"`。`kanalist`の有無だけで判定すると、`kanalist`を持たない特殊設問で
    「正解は4択レターなのに`choice_type: "boolean"`」という矛盾データが生成される不具合があったため
    この優先順位に修正した。
  - **解説抽出の優先順位（実機確認済み）**: ①`ol.kanalist`があればその内容（`table.gakusyu`があれば
    末尾に結合）、②無ければ`table.gakusyu`のみ、③どちらも無ければ`.redactor-editor`の全文をフォール
    バックとして使う（`table.transtable`形式はこのケースに該当する）。
  - **セレクト過去問集（実技試験対策）は科目トグルの展開までは同一UI基盤であることを実機確認済み**
    （著作権法科目で確認）。ただし科目ページ内部（`.list_question`/`.list_answer`/`table.transtable`
    構造そのもの）は実技側で未確認のまま。`.list_question`/`.list_answer` 構造が異なる場合は §7
    トラブルシュートを参照して調整する。

## 3. 前提ツール

- **agent-browser**（Vercel Labs 製・Rust ネイティブ・CDP 直結のブラウザ自動化 CLI）。未導入なら
  `web:automating-browser` スキルの `scripts/install.sh` で導入する。
- **jq**（JSON 整形・検証）。
- **ログイン認証情報**: studying はメール＋パスワードでのログインが必須。**このスキルを起動したら最初に
  ユーザーへメールアドレス・パスワードを尋ねる**（AskUserQuestion または通常の対話で確認する。ハード
  コード・恒久保存はしない）。

導入確認:

```bash
which agent-browser && agent-browser --version
which jq
```

### 認証: Auth Vault を第一候補、state save/load へフォールバック

🔴 実機確認済み: studying に専用ログインページ `https://member.studying.jp/login/` が存在し（Whizlabsと
異なりモーダル型ではない）、ページを開けば `textbox "メールアドレス"` / `textbox "パスワード"` /
`link "ログインする"` が可視状態で即座に DOM に存在する。agent-browser の `auth save`/`auth login`
（Auth Vault）は「ページを開けばフォームが見えている」ことを前提にフィールドを自動検出する仕様のため、
studying はこの条件を満たしている可能性が高い。ただし実際に Auth Vault が studying のフォーム構成で
機能するかは未検証のため、本スクリプトは以下の優先順で認証を行う。

1. `STUDYING_STATE_FILE` が存在すれば `--state` 付きでコース URL を開き、ログイン済みか確認する
   （ヘッダー等の「ログイン」リンクの有無で判定）。ログイン済みなら以降の処理へ進む。
2. 未ログインなら `agent-browser auth login <profile>`（Auth Vault）を試行する。成功しログイン確認も
   取れれば、以降の処理へ進みつつ `state save` でも保存しておく（次回実行の高速化）。
3. Auth Vault が失敗・機能しない場合、通常フォーム入力にフォールバックする: ログインページを開き
   `textbox "メールアドレス"` に `STUDYING_USERNAME`、`textbox "パスワード"` に `STUDYING_PASSWORD` を
   入力し、`link "ログインする"` をクリックする。ログイン確認後 `state save` でセッションを保存する。

```bash
# Auth Vault を使う場合（事前に1度だけ暗号鍵を用意し、プロファイルを保存しておく運用を推奨）
export AGENT_BROWSER_ENCRYPTION_KEY="$(openssl rand -hex 32)"
agent-browser auth save studying --url https://member.studying.jp/login/
agent-browser auth login studying

# state save/load によるフォールバック（Auth Vaultが機能しない場合）
agent-browser open https://member.studying.jp/login/
agent-browser wait --load networkidle
# textbox "メールアドレス" / "パスワード" への入力、"ログインする" リンクのクリックはスクリプトが行う
agent-browser state save <path>.json
agent-browser --state <path>.json open <course-list-url>
```

🔴 **state ファイルはセッショントークンを含む秘匿情報**であり、コミット対象にしてはならない。
`STUDYING_STATE_FILE` の既定値は `<output-dir>` 配下（リポジトリ外の作業ディレクトリ）に置かれる設計に
しており、明示的に別パスを指定する場合もリポジトリ配下は避けること。

## 4. 実行方法

```bash
scripts/collect-studying.sh <course-list-url> [output-dir]
```

| 引数/環境変数 | 説明 |
|---|---|
| `<course-list-url>`（必須） | studying のコースレッスン一覧URL（`https://member.studying.jp/course/id/<course_id>/`） |
| `[output-dir]`（任意） | 出力先ディレクトリ。省略時 `./studying-output` |
| `STUDYING_USERNAME` | ログイン用メールアドレス（state/Auth Vault未確立時に必須） |
| `STUDYING_PASSWORD` | ログイン用パスワード（state/Auth Vault未確立時に必須。**ログ・シェルトレースへは出力しない**。`agent-browser fill` の仕様上コマンド引数として渡る点に留意する） |
| `STUDYING_STATE_FILE` | agent-browser state ファイルパス（既定 `<output-dir>/.studying-state.json`。秘匿情報のためコミット対象にしない） |
| `STUDYING_AUTH_PROFILE` | Auth Vault のプロファイル名（既定 `studying`。事前に `agent-browser auth save` で登録済みの場合のみ有効） |
| `STUDYING_WAIT_MS` | 科目間の待機ミリ秒（既定 300） |
| `STUDYING_MAX_N` | スモークテスト用の処理科目数上限（全カテゴリ合計・既定 0=全件） |
| `AGENT_BROWSER` | agent-browser バイナリパス上書き（既定: `which agent-browser`） |

```bash
# 例: 知的財産管理技能検定コースの全科目を収集
STUDYING_USERNAME="user@example.com" STUDYING_PASSWORD="********" \
  scripts/collect-studying.sh \
  https://member.studying.jp/course/id/2689/ \
  ./studying-output

# 例: 最初の2科目だけ試しに取得（スモークテスト）
STUDYING_MAX_N=2 scripts/collect-studying.sh <course-list-url> /tmp/studying-test
```

1 コースに科目数×3カテゴリ（スマート問題集・セレクト過去問集学科・実技）の科目が含まれ、科目数が多い
コースでは全体時間が伸びうる。ただし**科目単位の一括表示ページ方式のため、Whizlabsより大幅に高速**
（1科目=開く→読み取るの2コマンドで完結）。科目数が多い場合は `run_in_background: true` での実行を
推奨する。

## 5. 出力フォーマット（JSON）

1 科目 = 1 最終成果物: `<output-dir>/<course-slug>__<category-slug>__<subject-slug>.json`
（Whizlabs・kentei-labと異なり、単一ページ読み取りで科目データが完結するため進捗サイドカー `.jsonl` は
出力しない。失敗した科目は再実行時にその科目単体を再取得すればよい）。

```json
{
  "course_title": "<コース名>",
  "course_url": "<引数で渡されたコーストップURL>",
  "category": "<スマート問題集 | セレクト過去問集（学科試験対策） | セレクト過去問集（実技試験対策）>",
  "subject_title": "<科目名（例: 著作権法）>",
  "practice_id": "<studying内部のpractice識別子>",
  "collected_at": "<ISO8601 UTC>",
  "total_questions": 27,
  "pass_line": "<合格ライン文字列（例: 22点（27点満点）そのまま保持）>",
  "questions": [
    {
      "number": 1,
      "question": "<問題文（出典情報含む）>",
      "choice_type": "boolean",
      "choices": [],
      "correct": ["○"],
      "explanation": "<解説文>"
    }
  ]
}
```

- `choice_type`: 判定は①`ol.kanalist`または`table.transtable`のいずれかがあれば`"single"`、②どちらも
  無くても正解マークが`"○"`/`"×"`なら`"boolean"`、③どちらにも当てはまらない場合のみ`"unknown"`、の
  優先順で行う（`kanalist`の有無だけで判定すると矛盾データが生じる不具合があったため修正済み）。
  - `"single"`: 4択等。`choices`に選択肢テキスト配列が入る。通常の`ol.kanalist > li`形式は
    `"ア. <選択肢テキスト>"`（マーカー文字はDOMのテキストノードに含まれないため出現順に機械的に
    割り当てる）。`table.transtable`形式（空欄補充の組み合わせ選択等）は各行の全`td`テキストを結合した
    ものがそのまま選択肢文になる（レターは`td`内テキストに既に含まれるため追加のレター割り当ては無い）。
  - `"boolean"`: ○×形式。`choices`は空配列。
  - `"unknown"`: `ol.kanalist`・`table.transtable`のどちらも持たず、正解マークも○×以外の特殊設問
    （実機確認済み: 通常の4択とDOM構造が異なる設問が稀に存在する）。`correct`はDOMから取得できた値を
    そのまま保持するが`choices`は空配列のまま。`creating-flashcards`の`studying_import.py`は`"unknown"`
    を`qtype="basic"` + `needs_fix=True`にマッピングし手動確認を促す。
- `correct`: `.list_answer` 側の `h4 .notosans-mark` から直接取得した正解（○×形式は `["○"]`/`["×"]`、
  選択式は正解のレター 例 `["エ"]`）。取得できなかった場合は空配列になる（§7参照）。
- `explanation`: 優先順で汎用フォールバックする。①`ol.kanalist`があればその内容（`table.gakusyu`が
  あれば末尾に結合）、②無ければ`table.gakusyu`のみ、③どちらも無ければ`.redactor-editor`の全文
  （`table.transtable`形式はこのケースに該当し、選択肢ごとの個別解説ではなく全文まとめての解説になる）。
- `warnings`（収集時のみ。最終成果物の科目単位JSONには含めない）: メタ情報の総問題数取得失敗
  （`total-questions-metadata-not-found`）・`.list_question` 件数とメタ情報の総問題数の不一致
  （`question-count-mismatch`）・正解マーカー取得失敗（`correct-mark-not-detected`）・想定外の設問構造
  （`choice-structure-not-recognized`）をスクリプトの
  標準エラー出力に記録する。

この JSON はそのまま `creating-flashcards` スキルへ渡せる（同スキルが `scripts/studying_import.py` で
構造推測をスキップして Anki に一括登録する）。デッキ名は既定で `course_title` を「検定名」「級」に
分解したうえで `検定試験::<検定名>::<級>::studying::<category>::<subject_title>`（級を検出できない
コースは `検定試験::<検定名>::studying::<category>::<subject_title>`）に登録される（詳細は
`creating-flashcards` の INSTRUCTIONS.md「studying 収集済み JSON のファストパス」節を参照）。

## 6. サイトへの配慮

studying は認証必須の有料コンテンツを含むプラットフォームである。本スクリプトは既定で科目間に 300ms の
待機を挟み、サーバへの負荷を抑える（`STUDYING_WAIT_MS` で調整可）。**本スキルはユーザー自身が正規に
受講権限を持つコースの個人学習目的でのみ使用する前提**とする。第三者への再配布・商用利用は対象外。

## 7. トラブルシュート

| 症状 | 対処 |
|---|---|
| ログインページから「メールアドレス」「パスワード」の入力欄が見つからずエラー終了する | フォーム構造が変わった可能性がある。`agent-browser open https://member.studying.jp/login/` して DOM を目視確認し、スクリプトの入力欄セレクタを調整する |
| コース一覧から科目トグル（`.m-ctop-course-d-list__link`）が見つからない/展開してもリンクが出現しない（「科目を検出できませんでした」でエラー終了する） | セクション見出しの文言または `.m-ctop-course-d-list__link`/`.m-ctop-course-d-list__name`/科目1件分の`<li>` の DOM 構造が変わった可能性がある。`agent-browser open <course-list-url>` して DOM を目視確認し、`collect-studying.sh` 内の `collect-practice-links.js`（`TOGGLE_SELECTOR`/`NAME_SELECTOR`/`toggle.closest('li')`）を調整する |
| 多くの科目が `practice-link-not-found-after-click` で検出漏れになる（一部しか収集できない） | 展開アニメーションの待機時間が不足している可能性がある（実機確認済みの既定値は500ms）。`collect-practice-links.js` の `EXPAND_WAIT_MS` を延長する。回線・端末が遅い環境では500msでも不足することがある |
| コースタイトルが「スタディング マイページ」等の共通ヘッダー文言になってしまう | `get-course-title.js` は `document.title` から `" - スタディング 会員ページ"` サフィックスを除去して使う設計になっている。サフィックス表記が変わった場合はこの正規表現を調整する |
| 科目ページの `.list_question`/`.list_answer` が0件で「問題データを抽出できませんでした」でスキップされる | DOM 構造（クラス名）が変わった可能性がある。`agent-browser open <practice-list-url>` して DOM を目視確認し、`read-practice-page.js` 相当のセレクタ（`.list_question`/`.list_answer`/`ol.kanalist`/`h4 .notosans-mark`/`table.gakusyu`）を調整する |
| メタ情報の総問題数が取得できず `total-questions-metadata-not-found` 警告が出る（収集自体は `.list_question` の実件数で継続する） | メタ情報の表記順序またはワードが変わった可能性がある。`agent-browser open <practice-list-url>` してテキストを目視確認し、`read-practice-page.js` のメタ情報正規表現（`N分 → N問 → 合格ライン` の順序）を調整する。収集自体は `.list_question` 件数を `total_questions` として継続するため致命的ではない |
| セレクト過去問集（実技試験対策）の科目だけ抽出に失敗する | 科目トグルの展開自体は学科試験対策と同一UI基盤であることを実機確認済み（著作権法科目で確認）。ただし科目ページ内部（`.list_question`/`.list_answer` 構造）は実技側で未確認のため、これが異なる可能性がある。1件サンプルをブラウザで開いて構造を確認し、必要ならパースロジックの分岐を追加する |
| 4択問題の正解（`correct`）が空配列になる | `.list_answer h4 .notosans-mark` が見つからなかった可能性がある（`correct-mark-not-detected` 警告で検知できる）。該当科目の解答ページを開いて実際のDOM構造を確認し、セレクタを調整する |
| `choice_type` が `"unknown"` になる問題がある（`choices`/選択肢解説が空になる） | `ol.kanalist`・`table.transtable` のどちらも持たないのに正解マークが○×以外（例: 未知の新しい設問形式）の特殊設問。空欄補充の組み合わせ選択タイプは `table.transtable` で対応済みのため、これでも `"unknown"` になる場合はさらに別の未対応DOM構造の可能性が高い。`choice-structure-not-recognized` 警告で検知できる。無理に○×/4択へ押し込めず `"unknown"` のまま出力する設計のため、Anki投入時は `studying_import.py` が `needs_fix=True` でマークする。該当科目ページを開いて実際の設問形式を確認し、必要なら専用の抽出分岐を追加する |
| `table.transtable` 形式の設問で `choices` が意図した行分割にならない | `table.transtable` のDOM構造（`tbody > tr > td`）が想定と異なる可能性がある。該当科目の問題ページを開いて実際の `table.transtable` 構造を確認し、`read-practice-page.js` の行・セル抽出セレクタを調整する |
| 出力ファイル名に改行や不正な空白が混入する | 通常は `.m-ctop-course-d-list__name` から科目名を取得するため発生しないはずだが、`sanitize_jp` は防御として改行・タブを事前にスペースへ変換してから安全化する設計になっている。万一再発する場合は該当科目の科目名取得元（`.m-ctop-course-d-list__name`）のDOM構造を確認する |
| ログインに失敗する | `STUDYING_STATE_FILE` の state が期限切れの可能性がある。ファイルを削除して再実行し、Auth Vault → 通常フォーム入力の順で再認証させる |
| agent-browser デーモンが不調（接続エラー等） | `agent-browser doctor --fix` で診断・修復し、必要なら `agent-browser close --all` してから再実行する |

## 8. やってはいけないこと

- **ユーザー自身が受講権限を持たないコースを対象にしない**: studying は有料コンテンツを含むプラット
  フォームであり、受講権限のないコースへのアクセスは対象外とする。
- **収集した問題文・解説の実例をスキル本文やコミットメッセージに引用しない**: 著作権への配慮のため、
  実データはサンプルとして残さない。
- **パスワードをログ・コマンド履歴・出力ファイルに残さない**: 認証情報は環境変数経由でのみ扱い、
  `set -x` 等でシェルトレースへ出力しない。state ファイル（`STUDYING_STATE_FILE`）はセッショントークンを
  含む秘匿情報のため、コミット対象にせず出力ディレクトリ配下に留める。
