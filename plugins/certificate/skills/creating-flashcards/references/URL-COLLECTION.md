# URL収集（certificate-exam サイト）

`creating-flashcards` の Step 0（URL判定・ディスパッチ）から参照されるサイト別の詳細リファレンス。
引数に certificate-exam サイトの URL が渡された場合、この文書の該当サイト節に従って
`${CLAUDE_SKILL_DIR}/scripts/collect-<site>.sh` を実行し、生成された JSON を Step 1 の
「〜収集済み JSON のファストパス」節（既存・変更なし）へ渡す。

## サイト判定表

| サイト | URL形式 | 判定パターン | 認証 |
|---|---|---|---|
| kentei-lab | `https://kentei-lab.com/exams/<slug>`（`/start`・`/quiz/<slug>/<n>` も可） | ホスト名に `kentei-lab.com` | 不要 |
| studying | `https://member.studying.jp/course/id/<course_id>/` | ホスト名に `studying.jp`（`member.studying.jp`） | 必須（メール+PW、Auth Vault優先） |
| whizlabs | `https://www.whizlabs.com/learn/course/<slug>/<course-id>/pt` | ホスト名に `whizlabs.com` | 必須（メール+PW、state save/load固定） |
| shikaku-drill | `https://shikaku-drill.com/<slug>.html`（slug単体も可） | ホスト名に `shikaku-drill.com` | 不要 |

どのパターンにも一致しない URL は未対応サイトとして扱い、収集を試みずユーザーへ報告する
（汎用スクレイピングへのフォールバックはしない）。

---

## kentei-lab.com

### 概要

kentei-lab.com は認証不要・全問無料公開の資格・検定問題集サイト（147 資格・58,950 問収録）。人間は
概要ページの「問題を解く →」から開始ページの「全問題を始める N問」を選び、問題ページを 1 問ずつ進める。

この収集ロジック（`scripts/collect-kentei-lab.sh`）は、この人間の導線と同じ問題集合を
**`/quiz/<slug>/<n>`（n=1..N）への直接 URL 反復**で決定的に取得する。同一 n は常に同一問題であり
（ランダム出題設定は提示順序のみに影響）、「全問題を始める」ボタンや「次の問題へ」リンクのクリックには
一切依存しない。そのため中断・再開に強く、1 資格分（最大 1015 問）を長時間の `run_in_background`
ジョブとして安全に走らせられる。

このサイト特性の内訳:

- `/quiz/<slug>/<n>` は認証・セッション状態に関わらず直接アクセスでき、**同一 n は常に同一問題**を返す
  （ランダム出題設定の影響は問題の「提示順序」のみで、URL→問題内容の対応は固定）
- 問題ページで任意の選択肢ボタンを 1 つクリックすると、追加のネットワークリクエストなしに
  正誤・正解・解説がクライアント側で開示される。不正解を選んでも「正解は …」の行に正答が出るため、
  **正解を当てるロジックは不要**で、1 つ押して開示するだけでよい

したがって「全問題を始める」ボタンや「次の問題へ」リンクを一切クリックせず、n を 1 から N まで単純に
ループするだけで、全問題を確定的・再開可能に収集できる。

出力は 1 資格 1 JSON ファイル（`<slug>.json`）で、`creating-flashcards` の `kentei_lab_import.py`
ファストパスにそのまま渡して `検定試験::<検定名>::<級>::kentei-lab`（級を検出できない試験は
`検定試験::<検定名>::kentei-lab`）デッキへ一括登録できる。

### 前提ツール

- **agent-browser**（Vercel Labs 製・Rust ネイティブ・CDP 直結のブラウザ自動化 CLI）。未導入なら
  `web:automating-browser` スキルの `scripts/install.sh` で導入する（内部で `agent-browser install` を実行し
  Chrome for Testing を取得する。これは省略できない）。
- **jq**（JSON 整形・検証）。

導入確認:

```bash
which agent-browser && agent-browser --version
which jq
```

### 実行方法

```bash
${CLAUDE_SKILL_DIR}/scripts/collect-kentei-lab.sh <input-url> [output-dir]
```

| 引数/環境変数 | 説明 |
|---|---|
| `<input-url>`（必須） | kentei-lab の URL（`/exams/<slug>` ・ `/exams/<slug>/start` ・ `/quiz/<slug>/<n>` のいずれか） |
| `[output-dir]`（任意） | 出力先ディレクトリ。省略時 `./kentei-lab-output` |
| `KENTEI_LAB_WAIT_MS` | 問題間の待機ミリ秒（既定 300） |
| `KENTEI_LAB_MAX_N` | 取得上限（スモークテスト/部分取得用・既定 0=全件） |
| `AGENT_BROWSER` | agent-browser バイナリパス上書き（既定: `which agent-browser`） |

```bash
# 例: 世界遺産検定2級を全問取得
${CLAUDE_SKILL_DIR}/scripts/collect-kentei-lab.sh https://kentei-lab.com/exams/sekai2kyu/start ./kentei-lab-output

# 例: 最初の10問だけ試しに取得（スモークテスト）
KENTEI_LAB_MAX_N=10 ${CLAUDE_SKILL_DIR}/scripts/collect-kentei-lab.sh https://kentei-lab.com/exams/sake3/start /tmp/sake3-test
```

大規模資格（数百〜1015 問）は取得に時間がかかる。**`run_in_background: true` での実行を推奨する**。
中断しても resume（後述）により安全に再開できる。

### 出力フォーマット（JSON）

- 1 資格 = 1 最終成果物: `<output-dir>/<slug>.json`
- 加えて内部の進捗（resume）用サイドカー（JSON Lines・1 問 1 行）: `<output-dir>/<slug>.jsonl`

最終成果物 `<slug>.json` のスキーマ:

```json
{
  "exam_title": "<試験名>",
  "slug": "<slug>",
  "source_url": "https://kentei-lab.com/exams/<slug>",
  "collected_at": "<ISO8601 UTC>",
  "total_questions": 30,
  "questions": [
    {
      "number": 1,
      "question": "<問題文>",
      "choices": ["A. <選択肢A>", "B. <選択肢B>", "C. <選択肢C>", "D. <選択肢D>"],
      "answer": "C. 1972年",
      "explanation": "<解説文>"
    }
  ]
}
```

- `choices` は取得できた数だけ格納する（A–D 決め打ちではなく試験により可変）。各要素はサイト表示のレター付き
  文字列をそのまま保持する。
- `answer` はサイトの「正解は…」から接頭辞「正解は」と先頭空白を除去した残り（レター＋本文の結合文字列）。
- `total_questions` は試験の総問題数 N。`KENTEI_LAB_MAX_N` で部分取得した場合、`questions` の要素数は N より少なくなる。
- この JSON はそのまま `creating-flashcards` の Step 1（`scripts/kentei_lab_import.py`）で
  構造推測をスキップして Anki に一括登録できる。Anki デッキは既定で
  `検定試験::<検定名>::<級>::kentei-lab`（級を検出できない試験は `検定試験::<検定名>::kentei-lab`）に登録される。
- ⚠️ 同一会話内で直接ブリッジする場合の実務上の注意（`disable-model-invocation` によるSkillツール不可・
  `${CLAUDE_PLUGIN_ROOT}` 未設定・デッキ名衝突確認等）は `INSTRUCTIONS.md` の
  「kentei-lab 収集済み JSON のファストパス」節を参照。

### 中断・再開（resume）

進捗用サイドカー `<output-dir>/<slug>.jsonl` が唯一の真実源（single source of truth）。1 問 1 行の JSON Lines で、
各問題の読み取り・開示・検証が完了した時点で 1 行を追記する。

- 起動時、`<slug>.jsonl` があればその中の `number` の最大値 +1 から再開する。
- 破損した末尾行（プロセス強制終了などによる書き込み途中の行）は、起動時に末尾行の JSON 妥当性を検証し、
  無効なら 1 行だけ除去してから再開する（append-only のため破損しうるのは末尾行のみ）。
- `<slug>.jsonl` が無ければ第 1 問から開始する。
- 各問題を追記した後、スクリプト末尾（および全問取得済みでの早期終了時）に `<slug>.jsonl` 全行から最終成果物
  `<slug>.json` を再構築する。したがって任意のタイミングで中断しても次回実行時にその続きから安全に再開でき、
  最終 JSON も常に最新の全収集分を反映する（同一問題の重複保存は起きない）。

### サイトへの配慮

kentei-lab.com は無料公開・認証不要の教育目的サイトである。既定で問題間に 300ms の待機を挟み、
サーバへの負荷を抑える（`KENTEI_LAB_WAIT_MS` で調整可）。大量取得を行う際も、教育・個人利用目的での
節度ある利用に留めること。

### トラブルシュート

| 症状 | 対処 |
|---|---|
| 総問題数(N)が取得できずエラー終了する | サイトのボタン文言が変わった可能性がある。`agent-browser open <slug>/start` してボタン文言を目視確認し、スクリプトの `get-n.js` の正規表現を調整する |
| 問題文/選択肢/正解/解説が取得できずエラー終了する | DOM 構造が変わった可能性がある。`agent-browser eval --stdin` で `read-before-click.js`/`read-after-click.js` 相当を手動実行し、セレクタを調整する |
| agent-browser デーモンが不調（接続エラー等） | `agent-browser doctor --fix` で診断・修復し、必要なら `agent-browser close --all` してから再実行する |
| 選択肢の数が資格により異なる | 想定内。スクリプトは選択肢数を決め打ちせず、取得できた分だけ列挙する |

### やってはいけないこと

kentei-lab の全問題データはクライアント側の巨大 JS バンドル（数十 MB）に埋め込まれている。**この
バンドルを直接パースして問題データを抜き出す実装は行わない**。サイト更新で容易に壊れる上、意図された
表示範囲を超えてデータへアクセスすることになるため、常にレンダリング後の DOM を読む方式のみを採用する。

### 補足: agent-browser eval の呼び出し方

`agent-browser` の一部バージョン（導入検証時点: 0.31.1）には、外部ドキュメントに記載のある
`eval --file <path>` オプションが実装されておらず指定すると構文エラーになる。JS を渡す際は
`agent-browser eval --stdin < script.js`（またはヒアドキュメント）を使う。`scripts/collect-kentei-lab.sh`
はこの方式で実装済み。

---

## studying（member.studying.jp）

### 概要

studying は認証必須の資格・検定対策プラットフォーム。人間はコーストップページから「基本講座」
「スマート問題集」「セレクト過去問集（学科試験対策）」「セレクト過去問集（実技試験対策）」の各セクション内で
科目を1つずつクリックして展開し、科目ページへ進んで「解説一覧表示」を開いて問題・正解・解説を確認する。

**利用上の注意（必読）**: studying は認証必須の有料コンテンツを含むプラットフォームであり、著作権について
の注意書きが明記されている。ユーザー自身が正規に受講権限を持つコースの個人学習目的（Anki個人
利用）でのみ使用する前提とする。収集した問題文・解説の実例をスキル本文・コミットメッセージ・会話記録に
引用しない。

出力は 1 科目 1 JSON ファイル（`<course-slug>__<category-slug>__<subject-slug>.json`）で、
`creating-flashcards` の `studying_import.py` ファストパスにそのまま渡して Anki へ一括登録できる。

### 実装方式の詳細（実機確認済み知見）

主収集（`scripts/collect-studying.sh`）は、Whizlabs 版のような**1問ずつの SPA ナビゲーション
（番号クリック → 選択肢確認 → Show Answer → Next）は一切不要**。以下の実機調査で確定した studying 固有の
挙動を利用し、収集ロジックを大幅に単純化している（🔴 ただし`multi_blank`/`fill_in_single`形式の選択肢
〈語群〉を取得する場合のみ例外があり、後述「選択肢（choices）の後付け取得」節の通り別スクリプト
`scripts/collect-studying-choices.sh`で1問ずつのナビゲーションが必要になる）。

- **🔴 科目トグルの展開（実機確認済み・コース全体スモークテスト`https://member.studying.jp/course/id/2689/`
  で再検証済み）**: 各セクション内の科目項目は `.m-ctop-course-d-list__link`（`onclick` 属性を持つdiv）で、
  初期状態では科目ページへのリンクが DOM に存在しない。クリックして展開すると、`toggle.closest('li')` で
  取得できる科目1件分の `<li>` 配下に該当科目のリンクが1件出現する（リンク先パターン:
  `course/practice/index/id/<practice_id>/f/0/`）。科目名は `toggle.querySelector('.m-ctop-course-d-list__name')`
  の textContent（`.trim()`のみでよい）から取得する（`toggle.textContent` をそのまま使うと進捗表示
  「6/6」等や大量の空白・改行が混入し不正なファイル名になる不具合があったため確定セレクタに置き換えた）。
  収集ロジックはコーストップページ上で3セクション（スマート問題集・セレクト過去問集学科・セレクト過去問集
  実技）配下の `.m-ctop-course-d-list__link` を全部 `eval`（非同期関数）でクリックし、出現したリンクから
  `practice_id` を一括収集する。
  🔴 **クリック直後の待機が必須**: クリック直後は展開アニメーションが完了しておらずDOMに未反映のため、
  各トグルクリック後に約500ms（`await new Promise(r => setTimeout(r, 500))`）待機してからリンクを探索する。
  この待機が無いと大半の科目が `practice-link-not-found-after-click` で検出漏れになる（実機スモーク
  テストで17件中16件が検出漏れになる不具合として確認済み）。agent-browser の `eval` は async 関数が返す
  Promise を正しく解決できることを実機確認済み。
  🔴 **「セレクト過去問集（実技試験対策）」も同一UI基盤であることを実機確認済み**（著作権法科目で同じ挙動
  を確認）。ただし科目ページ内部（`.list_question`/`.list_answer` 構造）そのものは実技側で未確認のまま
  （トラブルシュート参照）。
- **🔴 nosubcat二重クラス見出し（lessonタイプ）の除外漏れとCDPエラー（実機確認済み・2026-07-23: 社会保険
  労務士 合格コース `course/id/2301` で2回連続再現）**: 「今日のまとめのまとめ」等の見出しは
  `h2.m-ctop-course-d-list__title m-ctop-course-d-list__title--nosubcat` という2クラス併記で、配下トグルが
  `onclick="open_detail('lesson', ...)"` という**lessonタイプ**（動画/音声講座）を持つ。`practice`タイプと
  異なりクリックで実際にページ遷移するため、誤って収集対象に含めると agent-browser の CDP 接続が
  「Inspected target navigated or closed」で落ちる。`EXCLUDE_HEADING_SUBSTR` に「今日のまとめ」を追加して
  対処済み。
  🔴 **境界計算がフィルタ後配列基準だと除外が末尾連続時に無効化される罠（併発して発覚・修正済み）**:
  `nextHeadingEl` を EXCLUDE 後のフィルタ済み配列（`headings[i+1]`）基準で計算していたため、除外対象の
  見出しが末尾に連続する構成（総まとめ講座→今日のまとめのまとめ、等）ではフィルタ後配列の最後に残る
  見出しの境界が消失し、除外したはずのセクション配下まで誤って収集対象化していた（本来9件のところ27件
  検出）。境界計算はフィルタ前の全見出し配列（`allHeadings`）でのDOM上の隣接関係を使うよう修正した
  （除外判定と境界計算を同じフィルタ後配列で行わないこと）。
- **🔴 TOGGLE_SELECTORのaタグ誤マッチとページ遷移によるCDPエラー（実機確認済み・2026-07-23: 「【無料/2026年度
  試験直前応援】白書統計厳選チェックテスト」コース `course/id/2797` で再現）**: 見出しが1件のみの
  nosubcat構造（`headings.length === 0` にならずメインループで処理される）で、`TOGGLE_SELECTOR`
  （`.m-ctop-course-d-list__link`）が div型トグル自体だけでなく、`isAfter` の境界判定でdivトグルが
  除外され残った**展開済みの`<a>`リンク要素自体**にも同じクラス名が付与されているケースがあることが
  判明した。この`<a>`要素は `is-open` クラスを持たないため `wasOpen` 判定が `false` になり
  `toggle.click()` が実行されるが、`<a href="...">` 要素のクリックは実際にブラウザをそのリンク先へ
  ページ遷移させ、agent-browser の CDP 接続が「Inspected target navigated or closed」で落ちる
  （lessonタイプのトグル誤クリックと症状は同じだが、原因は見出しクラス混入ではなく
  `TOGGLE_SELECTOR` 自体がdivとaの両方にマッチすることだった）。対処として、メインループの `toggle`
  走査冒頭に `toggle.tagName === 'A'` の早期分岐を追加し、`<a>` 要素で既に
  `course/practice/index/id/<practice_id>` 形式の `href` を持つ場合はクリックせず、そのhrefから直接
  `practice_id` を抽出して結果へ追加するようにした（div型トグルの既存ロジック・ポーリング処理は
  変更なし）。
- **🔴 コース・科目構造の多様性への対応（実機確認済み・2026-07-23: 弁理士 基礎・短答合格コースで検証）**:
  studying のコースはコースごとにセクション見出し名・科目内部の入れ子構造が異なりうるため、収集ロジックは
  以下の点に対応している。
  - セクション見出し名の固定リストとの完全一致決め打ちをやめ、`h2.m-ctop-course-d-list__title` を
    全て走査したうえで、見出しテキストに「講座」を含むものだけを動画/音声講座セクションとして除外する
    方式にした（固定3カテゴリ名との完全一致では、見出し名がコースにより異なる場合〈例:
    「セレクト過去問集」に学科/実技の区別が無く「短答解法講座セレクト過去問」という未知カテゴリを
    持つコース〉に検出漏れが起きるため）。
  - 1科目に複数レッスン（複数 `practice_id`、最大72件）が存在する入れ子アコーディオン構造のコースが
    あるため、科目トグル展開後に出現する `practice_id` リンクは1件に限定せず全件収集し、レッスン単位で
    `subject_title` を割り当てる設計にした（従来の1科目=1リンク決め打ちでは2件目以降のレッスンが
    検出漏れになっていたため）。
  - 科目トグル展開後の Ajax 読み込み待機を固定500msからポーリング方式（300ms間隔・最大5秒）に変更した
    （問題数の多い科目〈72問等〉で読み込みに2秒以上かかるケースに対応するため）。
  - `.list_question` 内に `.redactor-editor` が複数存在するケース（「〜いくつあるか」形式で問題文用と
    末尾の個数選択肢「１つ／２つ…」用の2つに分離）があり、単数形の抽出では2つ目が欠落するため、
    全件を連結する設計にした。
  - クラス名の無い `<ol>` + `<li class="checkable_list_item">`（肢自体が `<ol><li>` で番号自体が
    正解値になる単一選択形式）は、番号マーカーが元々DOM上に存在せずAnkiノートタイプ側CSSで番号表示が
    消えるため、全角数字マーカー（「１　」「２　」…）を機械的に前置する処理を追加した
    （`ol.kanalist` 以外の `<ol>` が対象。既存の `kanalist` 用マーカー付与ロジックとは独立）。
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
  - **問題文**: `.list_question .redactor-editor`（無ければ `.list_question` 自体）から抽出する。
    🔴 **HTML保持（許可リスト方式でサニタイズ済み）で抽出する**（実機確認済み: 判例学習系コンテンツ
    「判例ビジュアルチェック200」で `<p>`/`<br>`/`<span class="span-bold">`〈重要語句の太字強調〉/
    `<span class="span-square">`〈空欄穴埋めマーカー〉等の意味を持つHTML書式を確認したため、
    textContentでの平坦化は書式・強調・空欄情報の欠落を招く）。クライアントサイドWebセキュリティ
    レビューの指摘に基づき、タグ・属性ともに**厳格な許可リスト（allowlist）方式**でサニタイズして
    から `innerHTML` を使う（詳細は後述「HTML保持抽出とAnki連携」参照）。
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
  - **各選択肢の解説**: `.list_answer ol.kanalist > li`（`.list_question`側と同じ4件構造）を、
    選択肢と同じ順序で解説として保持する（🔴 HTML保持で抽出・後述）。
  - **学習のポイント**: `.list_answer table.gakusyu`。解説文の末尾に結合する（🔴 HTML保持で抽出・後述）。
  - **🔴 表形式の選択肢（`table.transtable`・実機確認済み: `practice_id=223168`の5問目）**: `ol.kanalist`
    を持たない設問の一部は、空欄補充の組み合わせを選ぶタイプの設問で `table.transtable` という表要素で
    選択肢を表現する。`kanalist`形式と異なり、この表は**各行（`tr`）の最初の`td`に「ア.」「イ.」「ウ.」
    「エ.」というレター文字列が本物のテキストノードとして含まれる**ため、各`tr`の全`td`テキストを結合
    すればレター込みの選択肢文になる（`LETTERS`配列によるレター割り当ては不要）。この形式の設問は
    `.list_answer`側も`ol.kanalist`・`table.gakusyu`のどちらも持たず、`.redactor-editor`直下の`<p>`に
    解説がまとまっている（選択肢ごとの個別解説には分かれていない）。正解マーク（`h4 .notosans-mark`）は
    通常どおり取得できる。
  - **choice_type判定の優先順位（実機確認済み）**: ①`kanalist`または`table.transtable`のいずれかが
    あれば`"single"`、②`.question_multi`があれば`"multi_blank"`（後述）、③`.notosans-mark`に値があり
    その値が`"○"`/`"×"`なら`"boolean"`、④`.notosans-mark`に値があり（○×以外の任意の単語・フレーズ）
    なら`"fill_in_single"`（単一空欄穴埋め形式・後述）、⑤どれにも当てはまらない場合のみ`"unknown"`。
    `kanalist`の有無だけで判定すると、`kanalist`を持たない特殊設問で「正解は4択レターなのに
    `choice_type: "boolean"`」という矛盾データが生成される不具合があったためこの優先順位に修正した。
  - **🔴 複数空欄穴埋め形式（`.question_multi`・実機確認済み: 「判例ビジュアルチェック200」の
    全211問中約73%を占める形式として確認）**: `.list_answer` 側に`h4 .notosans-mark`が存在せず
    （単一の正解ではないため）、代わりに`.list_answer`配下の`.question_multi`要素に、複数の空欄
    （「Ａ」「Ｂ」「Ｃ」…）それぞれに対応する正解が`table tbody tr`の各行（`th`=ラベル・`td`=正解
    テキスト）として並ぶ。行数は問題により2〜3行以上まで変動する（実機確認済み）。この形式は
    `.notosans-mark`が存在しないのが正常であるため、`correct-mark-not-detected`警告の対象からは
    除外する。抽出方法: `questionMulti.querySelectorAll('table tbody tr')`を全走査し、各行の`th`
    （ラベル、`normWS`でテキスト取得）と`td`（正解テキスト、`sanitizeHtml()`でHTML保持抽出——正解
    テキストにも太字強調等の書式が含まれうるため`question`/`explanation`と同じ扱い）から
    `"<ラベル>. <正解テキスト>"`形式の文字列を1行1要素として`correct`配列に格納する。`choices`は
    4択ではないため空配列のまま。この形式が正しく認識された場合は`choice-structure-not-recognized`
    警告を出さない（従来通りどの形式にも当てはまらない場合のみ出す）。
  - **🔴 単一空欄穴埋め形式（`"fill_in_single"`・実機再調査で判明: practice_id=223631の7・8問目等）**:
    `kanalist`/`transtable`/`.question_multi`のいずれも持たず、`.notosans-mark`に値はあるが
    その値が`"○"`/`"×"`以外の単語・フレーズ（実機確認例: 法律用語1語や短いフレーズ）である一問一答
    形式。当初はこの形式を「第3の未知形式」と誤認していたが、実際には既存の`"boolean"`判定条件
    （`.notosans-mark`の値が○/×の場合のみ）が厳しすぎたことが原因で、○×以外の単語が来ると
    `"unknown"`に落ちていた設計上の抜けだった。`correct`には`.notosans-mark`の値がそのまま
    `[correctMark]`として入る（`"boolean"`/`"single"`/`"unknown"`と同じ取得元・組み立て方）。
    `choices`は元々4択構造を持たないため空配列のまま。
  - **解説抽出の優先順位（実機確認済み）**: ①`ol.kanalist`があればその内容（`table.gakusyu`があれば
    末尾に結合）、②無ければ`table.gakusyu`のみ、③どちらも無ければ`.redactor-editor`の全文をフォール
    バックとして使う（`table.transtable`形式はこのケースに該当する）。
  - **🔴 HTML保持抽出とAnki連携（実機確認済み・ユーザー要望反映）**: `question`・`explanation`は
    ともに `textContent` ではなく `sanitizeHtml()`（サニタイズ済み `innerHTML`）で抽出する。
    複数セグメントを結合する箇所（`ol.kanalist`の各`li`＋`table.gakusyu`）は、テキスト版で使っていた
    `'\n'`結合の代わりに `'<br>'` 結合を使う（HTML上で改行として機能させるため）。
    🔴 **`sanitizeHtml()` は厳格な許可リスト（allowlist）方式**（クライアントサイドWebセキュリティ
    レビューの指摘に基づき、ブラックリスト方式〈危険タグ列挙〉から書き換え済み）:
    - **危険タグの完全除去**（unwrapではなく中身ごと削除）: `script`/`style`/`iframe`/`object`/
      `embed`/`svg`/`math`/`form`/`input`/`button`/`textarea`/`select`/`link`/`meta`。
    - **許可タグリスト**（`p`/`br`/`span`/`strong`/`em`/`b`/`i`/`u`/`del`/`div`/`table`/`thead`/
      `tbody`/`tr`/`td`/`th`/`ol`/`ul`/`li`/`img`/`a`）に無いタグは、子要素・テキストは保持したまま
      タグ自体だけ除去する（unwrap。深い子孫要素から浅い祖先要素の順で処理する）。
    - **属性の許可リスト**（要素ごと）: 全要素共通で`class`のみ許可（値は英数字・ハイフン・
      アンダースコア・空白のみの正規表現`^[A-Za-z0-9_\- ]+$`に一致する場合だけ保持、それ以外は
      属性ごと除去）。`img`は`src`（絶対URL化は維持・後述）・`alt`のみ、`a`は`href`（`http:`/
      `https:`スキームのみ。`javascript:`/`data:`/`vbscript:`等は除去）のみ許可。これら以外の属性
      （`style`含む）は全要素で除去する。
    🔴 **Anki投入側（`creating-flashcards`の`studying_import.py`/`anki_toolkit.py`）は変更不要**:
    `anki_toolkit.py`の`build_front_html`/`build_back_html`は元々「front(問題文)/back(解説)は raw HTML
    を素通し（HTML-escapeしない）」という設計になっているため、`question`/`explanation`フィールドの
    値がHTML文字列になるだけでAnkiフィールドへそのまま反映される。
    `choices`（4択の選択肢テキスト）は今回HTML化の対象外（プレーンテキストのまま、レター「ア. 」等の
    手動割り当てロジックも従来通り）。選択肢側にも同種の書式保持が必要になった場合は本節の
    `sanitizeHtml()`パターンを流用して拡張する。
    🔴 **画像（`<img>`）の絶対URL化（実機確認済み: 判例学習系コンテンツで確認）**: 解説内には
    `skin/common/image/doc/...`のような**相対パス画像**（UIアイコン等）と
    `https://common.studying.jp/var/image/...`のような**絶対URL画像**（判例の図解等、コンテンツの
    核心部分）の両方が混在する。相対パスのまま保存すると、収集元ページのURLを離れるAnki上ではリンク
    切れになるため、`sanitizeHtml()`は`document.baseURI`を基準に相対パス画像を絶対URL化してから
    HTML化する（`data:`スキームの画像はそのまま。`javascript:`/`vbscript:`スキームの`src`は
    属性除去段階で拒否済み）。
  - **セレクト過去問集（実技試験対策）は科目トグルの展開までは同一UI基盤であることを実機確認済み**
    （著作権法科目で確認）。ただし科目ページ内部（`.list_question`/`.list_answer`/`table.transtable`
    構造そのもの）は実技側で未確認のまま。`.list_question`/`.list_answer` 構造が異なる場合はトラブル
    シュートを参照して調整する。
  - **🔴 nosubcat構造フォールバック（実機確認済み・再検証済み: コースID 2722「判例ビジュアルチェック
    200」等の無料公開特別コンテンツ）**: 通常の資格対策コースは「スマート問題集」「セレクト過去問集
    （学科試験対策）」「セレクト過去問集（実技試験対策）」の3セクション見出しの下に科目が列挙される
    構造だが、無料公開の特別企画コンテンツ等の一部コースにはこの3セクション見出し自体が存在せず、
    代わりに `h2.m-ctop-course-d-list__title--nosubcat` というカテゴリ見出し（例:「労働基準法」
    「労災保険法」「労働一般常識」）が直接列挙される「nosubcat」構造になっていることを実機確認済み。
    この場合、`collect-practice-links.js` は3セクション見出しの探索（`headings.length === 0`）に
    失敗した時点で即エラーにせず、以下のフォールバック探索を行う。
    - 🔴 **当初実装の誤り（再検証で修正済み）**: 見出し `h2` の祖先である
      `.m-ctop-course-d-list__link`（div要素・`onclick="open_detail('practice', <id>, event)"`）の
      `<id>` を `practice_id` とみなして抽出していたが、これは誤りだった。実機再検証の結果、この
      `<id>` は「カテゴリ全体を開閉するUI用の集約ID」であり、この ID で解説一覧表示ページ
      （`course/practice/list/id/<id>/a/on/`）を開くと **404**（タイトル「エラー - スタディング
      会員ページ」）になることを確認した。
    - **正しい抽出方法**: `h2.m-ctop-course-d-list__title--nosubcat`（カテゴリ見出し）の
      `closest('.m-ctop-course-d-list')` 配下に存在する
      `ul.m-ctop-course-d-list__list--nosubcat` 内の各 `li` に、科目個別ページへの
      `a[href*="course/practice/index/id/"]` リンクが**最初からDOM上に存在する**（クリック・展開
      待機は一切不要。むしろ通常コースよりシンプル）。この `a` タグの `href` から `id\/(\d+)` で
      `practice_id` を、textContent（trim）から `subject_title` を取得する
      （例: `223631` / `"判例ビジュアルチェック200-労働基準法（労働者、強行法規）"`）。
    - 🔴 **誤検出防止の注意**: 見出しdivとカテゴリ内の科目リンクの両方に同じクラス名
      `m-ctop-course-d-list__link` が付与されている（前者は `div` 要素、後者は `a` 要素）。
      `querySelectorAll` では必ず `a[href*="course/practice/index/id/"]` のようにタグ名で限定し、
      div要素（誤った集約ID）を拾わないようにする。
    - `category` フィールドは各カテゴリ見出し（`h2.m-ctop-course-d-list__title--nosubcat`）の
      textContent（trim）をそのまま使う（例:「労働基準法」「労災保険法」「労働一般常識」）。
    - 実機確認済みの件数内訳（コースID 2722）: 「労働基準法」8件（`223631`〜`223638`）・
      「労災保険法」7件（`223639`〜`223645`）・「労働一般常識」10件（`225932`〜`225941`）。
    - このフォールバック探索でも1件も見つからなければ、従来通り
      `{ error: 'no-category-headings-found' }` を返す。戻り値の形式は通常コースと同一
      （`{ items, errors: [], headingsFound }`）。

### 選択肢（choices）の後付け取得（`scripts/collect-studying-choices.sh`）

🔴 **選択肢（choices）の後付け取得（実機確認済み）**: 「解説一覧表示」ページ（`collect-studying.sh`の
収集元）には`multi_blank`・`fill_in_single`双方の選択肢情報が一切含まれない（`.list_question`全件を
実機確認し「語群」という文字列が0件であることを確認済み）。選択肢は個別の出題ページ（練習モード、
`course/question/index/q/<question_id>/`。`question_id`は動的に決まり事前列挙できない）にのみ存在する
ため、別スクリプト`scripts/collect-studying-choices.sh`（`collect-studying.sh`が生成済みのJSONを入力に
取り、科目トップページ→練習モード開始→個別出題ページを1問ずつ「次の問題へ」で辿って選択肢を取得し、
同じJSONへ上書き保存する）で事後的に埋める。**Step 0 の自動ディスパッチ対象は `collect-studying.sh`
のみであり、`collect-studying-choices.sh` は `choice_type: "multi_blank"`/`"fill_in_single"` 問題が
含まれる場合の追加手順として案内に留める（自動連鎖実行はしない）。**

- `multi_blank`用: `h3`（textContentに「語群」を含む。例:「[Ａの語群]」）＋その直後の兄弟`ul`
  （`li`が選択肢）から、ラベル別の構造化辞書`{"Ａ": ["選択肢1","選択肢2",...], "Ｂ": [...]}`を
  `choices`に格納する。
- `fill_in_single`用（実機確認済み: practice_id=223631の問題7「江東ダイハツ自動車事件」で確認）:
  `h3+ul`とは別のマークアップ`ul.ipt-button > li.notosans-mark`の各`li`の`data-item`属性
  （無ければtextContentへフォールバック）から、単純な文字列配列（例:
  `["平均賃金","付加金","割増賃金"]`）を`choices`に格納する（`multi_blank`のような複数ラベルは
  無く単一空欄用のため配列のまま）。1問につき`h3+ul`・`ul.ipt-button`のどちらか一方のみ存在する
  想定だが、両方存在する場合は`multi_blank`側を優先する。
- 出題順序が「解説一覧表示」ページの`number`と一致する保証がない（練習開始前に出題順序を選べる
  設定がある）ため、`number`には依存せず個別ページの問題文と既存JSON側の`question`の部分一致
  （先頭60文字の`contains`）でマッチングする。一意にマッチしない場合（0件・複数件）は安全側に
  倒し`choices`を更新しない（既存の空配列のまま据え置く）。
  🔴 **マッチング精度改善（実機で判明した課題への対応）**: 個別ページ側の問題文（`question_text`）は当初
  `normWS(textContent)`によるプレーンテキストだったが、`collect-studying.sh`と同一の厳格な
  許可リスト方式`sanitizeHtml()`によるHTML保持抽出に変更した。既存JSON側`question`（HTML）・
  収集側`question_text`（HTML）の両方に対し比較直前で同じ`plain_text`（タグ除去）関数を適用
  してから先頭60文字を比較するようにし、両者を同じ正規化経路に統一した。これは、一部の問題
  （問題文冒頭がリスト`<ol><li>`や強調`<strong>`等の複雑なHTML構造を持つケース）で、
  textContent由来の空白パターンの違いによりマッチ0件になっていた事象への対応。
- サイトへの配慮のため、各問題処理後に10〜15秒のランダム待機（固定間隔ではなくばらつきを持たせる）
  を挟む。既に「未完了の問題」が残っている状態で練習モードを開始すると確認モーダルが出るため、
  モーダル内の「問題を開始」リンクを追加でクリックして1問目から開始する。

### 前提ツール

- **agent-browser**（Vercel Labs 製・Rust ネイティブ・CDP 直結のブラウザ自動化 CLI）。未導入なら
  `web:automating-browser` スキルの `scripts/install.sh` で導入する。
- **jq**（JSON 整形・検証）。
- **ログイン認証情報**: studying はメール＋パスワードでのログインが必須。**収集を開始したら最初に
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
機能するかは未検証のため、`collect-studying.sh` は以下の優先順で認証を行う。

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

### 実行方法

```bash
${CLAUDE_SKILL_DIR}/scripts/collect-studying.sh <course-list-url> [output-dir]
```

| 引数/環境変数 | 説明 |
|---|---|
| `<course-list-url>`（必須） | studying のコースレッスン一覧URL（`https://member.studying.jp/course/id/<course_id>/`） |
| `[output-dir]`（任意） | 出力先ディレクトリ。省略時 `./studying-output` |
| `STUDYING_USERNAME` | ログイン用メールアドレス（state/Auth Vault未確立時に必須） |
| `STUDYING_PASSWORD` | ログイン用パスワード（state/Auth Vault未確立時に必須。**ログ・シェルトレースへは出力しない**。`agent-browser fill` の仕様上コマンド引数として渡る点に留意する） |
| `STUDYING_STATE_FILE` | agent-browser state ファイルパス（既定 `<output-dir>/.studying-state.json`。秘匿情報のためコミット対象にしない） |
| `STUDYING_AUTH_PROFILE` | Auth Vault のプロファイル名（既定 `studying`。事前に `agent-browser auth save` で登録済みの場合のみ有効） |
| `STUDYING_WAIT_MIN_MS` | 科目間の待機ミリ秒の下限（既定 `15000`。サイトへの配慮強化のため固定値からランダム化済み） |
| `STUDYING_WAIT_MAX_MS` | 科目間の待機ミリ秒の上限（既定 `30000`） |
| `STUDYING_WAIT_MS` | 科目間の待機ミリ秒（後方互換用の固定値。既定 `300`。`STUDYING_WAIT_MIN_MS`/`STUDYING_WAIT_MAX_MS` が未指定かつ本変数のみ明示指定された場合のみ固定待機として使われる） |
| `STUDYING_MAX_N` | スモークテスト用の処理科目数上限（全カテゴリ合計・既定 0=全件） |
| `AGENT_BROWSER` | agent-browser バイナリパス上書き（既定: `which agent-browser`） |

```bash
# 例: 知的財産管理技能検定コースの全科目を収集
STUDYING_USERNAME="user@example.com" STUDYING_PASSWORD="********" \
  ${CLAUDE_SKILL_DIR}/scripts/collect-studying.sh \
  https://member.studying.jp/course/id/2689/ \
  ./studying-output

# 例: 最初の2科目だけ試しに取得（スモークテスト）
STUDYING_MAX_N=2 ${CLAUDE_SKILL_DIR}/scripts/collect-studying.sh <course-list-url> /tmp/studying-test
```

1 コースに科目数×3カテゴリ（スマート問題集・セレクト過去問集学科・実技）の科目が含まれ、科目数が多い
コースでは全体時間が伸びうる。ただし**科目単位の一括表示ページ方式のため、Whizlabsより大幅に高速**
（1科目=開く→読み取るの2コマンドで完結）。科目数が多い場合は `run_in_background: true` での実行を
推奨する。

### 出力フォーマット（JSON）

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
      "question": "<問題文HTML（出典情報含む・サニタイズ済みinnerHTML。<p>/<br>/<span class=\"span-bold\">等を保持）>",
      "choice_type": "boolean",
      "choices": [],
      "correct": ["○"],
      "explanation": "<解説文HTML（サニタイズ済みinnerHTML）>"
    }
  ]
}
```

- `choice_type`: 判定は①`ol.kanalist`または`table.transtable`のいずれかがあれば`"single"`、
  ②`.question_multi`があれば`"multi_blank"`、③`.notosans-mark`に値がありその値が`"○"`/`"×"`なら
  `"boolean"`、④`.notosans-mark`に値があり（○×以外の任意の単語・フレーズ）なら`"fill_in_single"`、
  ⑤どれにも当てはまらない場合のみ`"unknown"`、の優先順で行う。
  - `"single"`: 4択等。`choices`に選択肢テキスト配列が入る。
  - `"multi_blank"`: 複数空欄穴埋め形式。`choices`は空配列。`correct`に複数行が入る。
  - `"boolean"`: ○×形式。`choices`は空配列。
  - `"fill_in_single"`: 単一空欄穴埋め形式（一問一答）。`choices`は空配列。
  - `"unknown"`: 想定外の設問構造。`correct`は空配列のまま。`creating-flashcards`の
    `studying_import.py`は`"unknown"`を`qtype="basic"` + `needs_fix=True`にマッピングし手動確認を促す。
- `correct`: `choice_type`により由来が異なる（詳細は上記「実装方式の詳細」参照）。
- `explanation`: 優先順で汎用フォールバックする。①`ol.kanalist`があればその内容（`table.gakusyu`が
  あれば末尾に結合）、②無ければ`table.gakusyu`のみ、③どちらも無ければ`.redactor-editor`の全文。
- 🔴 `question`・`explanation` は**厳格な許可リスト方式でサニタイズ済みのHTML文字列**として保存される
  （`textContent`ではない）。`creating-flashcards`の`studying_import.py`/`anki_toolkit.py`はfront/backを
  raw HTML として素通しする設計のため、このJSONをそのままAnki登録に使える（追加のエスケープ処理は不要）。
- `warnings`（収集時のみ。最終成果物の科目単位JSONには含めない）: メタ情報の総問題数取得失敗
  （`total-questions-metadata-not-found`）・`.list_question` 件数とメタ情報の総問題数の不一致
  （`question-count-mismatch`）・正解マーカー取得失敗（`correct-mark-not-detected`）・想定外の設問構造
  （`choice-structure-not-recognized`）をスクリプトの標準エラー出力に記録する。

この JSON はそのまま `creating-flashcards` の Step 1（`scripts/studying_import.py`）で構造推測をスキップ
して Anki に一括登録できる。デッキ名は既定で `course_title` を「検定名」「級」に分解したうえで
`検定試験::<検定名>::<級>::studying::<category>::<subject_title>`（級を検出できないコースは
`検定試験::<検定名>::studying::<category>::<subject_title>`）に登録される（詳細は `INSTRUCTIONS.md`
「studying 収集済み JSON のファストパス」節を参照）。

### サイトへの配慮

studying は認証必須の有料コンテンツを含むプラットフォームである。既定で科目間に 15〜30秒の
ランダムな待機を挟み（固定間隔ではなくばらつきを持たせる。`scripts/collect-studying-choices.sh` の
問題単位待機と同種の設計）、サーバへの負荷を抑える（`STUDYING_WAIT_MIN_MS`/`STUDYING_WAIT_MAX_MS` で
範囲調整可。後方互換の固定待機 `STUDYING_WAIT_MS` も残しており、これのみ明示指定した場合は固定値になる）。
ユーザー自身が正規に受講権限を持つコースの個人学習目的でのみ使用する前提とする。第三者への再配布・
商用利用は対象外。

### トラブルシュート

| 症状 | 対処 |
|---|---|
| ログインページから「メールアドレス」「パスワード」の入力欄が見つからずエラー終了する | フォーム構造が変わった可能性がある。`agent-browser open https://member.studying.jp/login/` して DOM を目視確認し、スクリプトの入力欄セレクタを調整する |
| コース一覧から科目トグル（`.m-ctop-course-d-list__link`）が見つからない/展開してもリンクが出現しない（「科目を検出できませんでした」でエラー終了する） | セクション見出しの文言または `.m-ctop-course-d-list__link`/`.m-ctop-course-d-list__name`/科目1件分の`<li>` の DOM 構造が変わった可能性がある。`agent-browser open <course-list-url>` して DOM を目視確認し、`collect-studying.sh` 内の `collect-practice-links.js`（`TOGGLE_SELECTOR`/`NAME_SELECTOR`/`toggle.closest('li')`）を調整する |
| 3セクション見出しが存在しないコース（例: 無料公開特別コンテンツ）で「科目を検出できませんでした」になる | nosubcat構造（`h2.m-ctop-course-d-list__title--nosubcat`がカテゴリ見出しとして列挙される構造）の可能性が高い。`collect-practice-links.js`はこの場合、見出しの`closest('.m-ctop-course-d-list')`配下`ul.m-ctop-course-d-list__list--nosubcat`内の`a[href*="course/practice/index/id/"]`から`practice_id`を抽出するフォールバックを実装済みのため通常は自動対応される。**🔴 見出しdivと科目リンクaタグの両方に同じクラス名`m-ctop-course-d-list__link`が付与されており、divのonclick属性`open_detail('practice', <id>, event)`の`<id>`はカテゴリ全体の集約ID（誤って抽出すると解説一覧表示ページが404になる）であり真の`practice_id`ではない**（過去に一度この誤りで実装した実績あり）。それでも0件の場合はDOM構造が変わった可能性があるため、`agent-browser open <course-list-url>`してDOMを目視確認し`NOSUBCAT_HEADING_SELECTOR`/`NOSUBCAT_LIST_SELECTOR`を調整する |
| 多くの科目が `practice-link-not-found-after-click` で検出漏れになる（一部しか収集できない） | 展開アニメーションの待機時間が不足している可能性がある（実機確認済みの既定値は500ms）。`collect-practice-links.js` の `EXPAND_WAIT_MS` を延長する。回線・端末が遅い環境では500msでも不足することがある |
| コースタイトルが「スタディング マイページ」等の共通ヘッダー文言になってしまう | `get-course-title.js` は `document.title` から `" - スタディング 会員ページ"` サフィックスを除去して使う設計になっている。サフィックス表記が変わった場合はこの正規表現を調整する |
| 科目ページの `.list_question`/`.list_answer` が0件で「問題データを抽出できませんでした」でスキップされる | DOM 構造（クラス名）が変わった可能性がある。`agent-browser open <practice-list-url>` して DOM を目視確認し、`read-practice-page.js` 相当のセレクタ（`.list_question`/`.list_answer`/`ol.kanalist`/`h4 .notosans-mark`/`table.gakusyu`）を調整する |
| メタ情報の総問題数が取得できず `total-questions-metadata-not-found` 警告が出る（収集自体は `.list_question` の実件数で継続する） | メタ情報の表記順序またはワードが変わった可能性がある。`agent-browser open <practice-list-url>` してテキストを目視確認し、`read-practice-page.js` のメタ情報正規表現（`N分 → N問 → 合格ライン` の順序）を調整する。収集自体は `.list_question` 件数を `total_questions` として継続するため致命的ではない |
| セレクト過去問集（実技試験対策）の科目だけ抽出に失敗する | 科目トグルの展開自体は学科試験対策と同一UI基盤であることを実機確認済み（著作権法科目で確認）。ただし科目ページ内部（`.list_question`/`.list_answer` 構造）は実技側で未確認のため、これが異なる可能性がある。1件サンプルをブラウザで開いて構造を確認し、必要ならパースロジックの分岐を追加する |
| 4択問題の正解（`correct`）が空配列になる | `.list_answer h4 .notosans-mark` が見つからなかった可能性がある（`correct-mark-not-detected` 警告で検知できる）。該当科目の解答ページを開いて実際のDOM構造を確認し、セレクタを調整する |
| `choice_type` が `"unknown"` になる問題がある（`choices`/選択肢解説が空になる） | `ol.kanalist`・`table.transtable`・`.question_multi` のいずれも持たず、かつ `.notosans-mark` 自体に値が無い特殊設問（例: 未知の新しい設問形式）。空欄補充の組み合わせ選択タイプは `table.transtable`、複数空欄穴埋めタイプは `.question_multi`、単一空欄穴埋め（一問一答）タイプは `choice_type: "fill_in_single"` で対応済みのため、これでも `"unknown"` になる場合はさらに別の未対応DOM構造の可能性が高い。`choice-structure-not-recognized` 警告で検知できる。無理に○×/4択へ押し込めず `"unknown"` のまま出力する設計のため、Anki投入時は `studying_import.py` が `needs_fix=True` でマークする。該当科目ページを開いて実際の設問形式を確認し、必要なら専用の抽出分岐を追加する |
| 多くの問題で `correct` が空配列のまま・`choice_type` が `"unknown"` に偏る（判例学習系コンテンツ等） | `.notosans-mark` による単一正解ではなく、`.question_multi table tbody tr`（複数空欄穴埋め・`choice_type: "multi_blank"`）形式である可能性が高い。実機確認済み: 「判例ビジュアルチェック200」では全211問中約73%がこの形式だった。`collect-studying.sh` は `.question_multi` の有無で自動判定し `correct` に`"<ラベル>. <正解テキスト>"`形式で複数行を格納するフォールバックを実装済みのため通常は自動対応される。それでも検出漏れがある場合は `agent-browser open <practice-list-url>` してDOMを目視確認し `.question_multi` 配下の `table`/`tbody`/`tr`/`th`/`td` 構造を確認する |
| `choice_type` が `"unknown"` に多数分類されるが `correct` 自体は非空（`.notosans-mark` の値は取得できている） | `.notosans-mark` の値が○×以外の単語・フレーズ（単一空欄の一問一答形式）である可能性が高い。`collect-studying.sh` は `choice_type: "fill_in_single"` で対応済みのため通常は自動対応される。それでも `"unknown"` になる場合は該当科目ページを開いて `.notosans-mark` の実際の値を確認する |
| `table.transtable` 形式の設問で `choices` が意図した行分割にならない | `table.transtable` のDOM構造（`tbody > tr > td`）が想定と異なる可能性がある。該当科目の問題ページを開いて実際の `table.transtable` 構造を確認し、`read-practice-page.js` の行・セル抽出セレクタを調整する |
| 収集した問題のQuestionフィールドに選択肢の記述はあるが末尾の個数選択肢（１つ／２つ…）が無い | `.list_question` 内に `.redactor-editor` が複数存在するケース（問題文用と個数選択肢用の2つに分離）である可能性が高い。`read-practice-page.js` の `extractQuestionHtml()` が `querySelectorAll('.redactor-editor')` で全件連結する設計になっているか確認する |
| 選択肢が並んでいるのに番号（１・２・３…）が一切表示されず正解と対応が取れない | クラス名の無い `<ol>` + `<li class="checkable_list_item">`（肢自体が正解値になる単一選択形式）である可能性が高い。`read-practice-page.js` の `numberOlChoices()` が `ol.kanalist` 以外の `<ol>` にも全角数字マーカーを前置しているか確認する |
| 出力ファイル名に改行や不正な空白が混入する | 通常は `.m-ctop-course-d-list__name` から科目名を取得するため発生しないはずだが、`sanitize_jp` は防御として改行・タブを事前にスペースへ変換してから安全化する設計になっている。万一再発する場合は該当科目の科目名取得元（`.m-ctop-course-d-list__name`）のDOM構造を確認する |
| ログインに失敗する | `STUDYING_STATE_FILE` の state が期限切れの可能性がある。ファイルを削除して再実行し、Auth Vault → 通常フォーム入力の順で再認証させる |
| agent-browser デーモンが不調（接続エラー等） | `agent-browser doctor --fix` で診断・修復し、必要なら `agent-browser close --all` してから再実行する |

### やってはいけないこと

- **ユーザー自身が受講権限を持たないコースを対象にしない**: studying は有料コンテンツを含むプラット
  フォームであり、受講権限のないコースへのアクセスは対象外とする。
- **収集した問題文・解説の実例をスキル本文やコミットメッセージに引用しない**: 著作権への配慮のため、
  実データはサンプルとして残さない。
- **パスワードをログ・コマンド履歴・出力ファイルに残さない**: 認証情報は環境変数経由でのみ扱い、
  `set -x` 等でシェルトレースへ出力しない。state ファイル（`STUDYING_STATE_FILE`）はセッショントークンを
  含む秘匿情報のため、コミット対象にせず出力ディレクトリ配下に留める。

---

## Whizlabs

### 概要

Whizlabs は認証必須の資格・検定対策プラットフォーム。人間はコース一覧ページから対象クイズ（Free Test・
Practice Test 1〜N 等）の「Start」（または「Free」）ボタンを押し、「Start quiz as practice mode」を選んで
開始し、1 問ずつ回答しながら進める。

出力は 1 クイズ 1 JSON ファイル（`<course-slug>__<quiz-slug>.json`）で、`creating-flashcards` の
`whizlabs_import.py` ファストパスにそのまま渡して Anki へ一括登録できる。

kentei-lab との主な相違点:

- URL 固定・SPA 内ジャンプ方式（直接 URL 反復不可）
- 選択肢クリック不要（`show Answer` ボタンのみで全開示）
- resume は同一ブラウザプロセス内でのみ有効（ブラウザが落ちると該当クイズは最初からになる弱い resume）
- ログイン必須（Free Test も含めアカウントが必要）

### 実装方式の詳細（実機確認済み知見）

この収集ロジック（`scripts/collect-whizlabs.sh`）は、kentei-lab 版のような**直接 URL 反復では取得できない**。
以下の実機調査で確定した Whizlabs 固有の挙動を利用する。

- **コース一覧からのクイズ検出（インデックス順クリック方式）**: 一覧ページの各クイズ行（`.box-item`）は
  クリック可能な `<a href>` を一切持たない。quiz-id は一覧ページの DOM には一切埋め込まれておらず、
  `.box-item .name`（React のイベントハンドラでクリックされる div。onclick 属性は DOM に出ない）を
  クリックして初めてクイズ詳細ページ（例: `/learn/course/<slug>/<id>/quiz/54753/ft/?section_heading=...`）
  へ遷移し、その遷移後 URL から quiz-id を読み取れる。したがって収集ロジックは、一覧ページで
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
  **Submit は絶対に押さない**（後述「やってはいけないこと」参照）。
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
  ない（後述「中断・再開」参照）。
- **Exit Quiz は3段階フロー**: ①「Exit Quiz」リンクをクリックすると**カスタムモーダル**が開く。中身は
  3ボタン（`Submit` / `Resume Later` / 離脱確認ボタン）で、`Submit`・`Resume Later` は絶対に押さない
  （後述「やってはいけないこと」参照）。②離脱確認ボタン（🔴 実機確認済み: `textContent` は `"Quit"`・`class` に `btn-quit` を持つ。
  長い確認文 `"You'll lose your progress, are you sure you want to leave?"` は `textContent` ではなく
  `aria-label` 属性の値。`agent-browser snapshot` は accessibility tree 表示のため `aria-label` を優先して
  見せており、これを `textContent` と誤認していたのが当初の実装ミス）をクリックすると、
  **ブラウザネイティブの `window.confirm()`** が発生し、`agent-browser` コマンドがブロックされる
  （"A JavaScript confirm dialog is blocking the page" 警告）。③`agent-browser dialog accept` でこれに
  応答して初めてテスト詳細ページへ離脱できる（後述「トラブルシュート」参照）。カスタムモーダルのクリックを飛ばして
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

### 前提ツール

- **agent-browser**（Vercel Labs 製・Rust ネイティブ・CDP 直結のブラウザ自動化 CLI）。未導入なら
  `web:automating-browser` スキルの `scripts/install.sh` で導入する。
- **jq**（JSON 整形・検証）。
- **ログイン認証情報**: Whizlabs はメール＋パスワードでのログインが必須。**収集を開始したら最初に
  ユーザーへユーザー名・パスワードを尋ねる**（AskUserQuestion または通常の対話で確認する。ハードコード・
  恒久保存はしない）。

導入確認:

```bash
which agent-browser && agent-browser --version
which jq
```

### state save/loadによるセッション永続化

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

### 実行方法

```bash
${CLAUDE_SKILL_DIR}/scripts/collect-whizlabs.sh <course-list-url> [output-dir]
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
  ${CLAUDE_SKILL_DIR}/scripts/collect-whizlabs.sh \
  https://www.whizlabs.com/learn/course/certified-cloud-security-professional/199/pt \
  ./whizlabs-output

# 例: 最初の5問だけ試しに取得（スモークテスト）
WHIZLABS_MAX_N=5 ${CLAUDE_SKILL_DIR}/scripts/collect-whizlabs.sh <course-list-url> /tmp/whizlabs-test
```

1 コースに複数クイズ（Free Test・Practice Test 1〜7 等、計 100 問超級が複数含まれることが多い）が含まれ、
全クイズ収集は長時間になる。**`run_in_background: true` での実行を推奨する**。1 クイズを 1 回の実行単位と
みなし、100 問超クイズ（Practice Test 等）はクイズ単位で分割実行することを推奨する（中断・再開参照）。

### 出力フォーマット（JSON）

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

この JSON はそのまま `creating-flashcards` の Step 1（`scripts/whizlabs_import.py`）で構造推測をスキップ
して Anki に一括登録できる。デッキ名は既定で `資格試験::<course_title>::<quiz_title>::whizlabs`
に登録される（詳細は `INSTRUCTIONS.md`「whizlabs 収集済み JSON のファストパス」節を参照）。

### 中断・再開（resume）

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

### サイトへの配慮

Whizlabs は認証必須の有料コンテンツを含むプラットフォームである。既定で問題間に 300ms の
待機を挟み、サーバへの負荷を抑える（`WHIZLABS_WAIT_MS` で調整可）。ユーザー自身が正規に
受講権限を持つコースの個人学習目的でのみ使用する前提とする。第三者への再配布・商用利用は対象外。

### トラブルシュート

| 症状 | 対処 |
|---|---|
| コース一覧からクイズを検出できない（「クイズを検出できませんでした」でエラー終了する） | `.box-item .name` のセレクタが変わった可能性がある。`agent-browser open <course-list-url>` して DOM を目視確認し、`get-quiz-titles.js`/`click-quiz-index.js` のセレクタを調整する |
| 総問題数(N)が取得できずエラー終了する | `.total-questions` の文言が変わった可能性がある。`agent-browser open <quiz-url>` してテキストを目視確認し、スクリプトの正規表現を調整する |
| 問題文/選択肢/正解/解説が取得できずエラー終了する | DOM 構造が変わった可能性がある。`agent-browser eval --stdin` で読み取りスクリプト相当を手動実行し、セレクタを調整する |
| 「A JavaScript confirm dialog is blocking the page」警告でコマンドが 120 秒タイムアウトする | 🔴 この警告自体は「Quit」ボタンクリック時に `window.confirm()` が同期発火するため正常に発生する（`eval` コマンドが応答を返せずエラー扱いになるだけで、クリック自体は成功している）。本スクリプトは `eval` の成否に関わらず必ず直後に `agent-browser dialog accept` を呼ぶ設計にしているため通常は自動解消する（実装方式の詳細参照）。以降も `open`/`eval` が延々ブロックされ続ける場合は、`eval` の成否で `dialog accept` の呼び出しを分岐する実装に退行していないか（旧実装のバグ）スクリプトを確認する |
| Exit Quiz 後もページがテスト詳細ページへ遷移せず後続クイズが軒並み失敗する | `dialog accept` が一度も呼ばれずダイアログが残留した可能性が高い（`eval` の `.ok` 判定で `dialog accept` 呼び出しを分岐している実装は confirm() 発火時に必ず失敗する）。`agent-browser eval --stdin < click-leave-confirm.js` の成否を無視し、直後に無条件で `agent-browser dialog accept` を呼ぶ実装になっているか確認する。手動復旧は `agent-browser dialog accept` を単発実行するか、`agent-browser close --all` してから再実行する |
| 問題番号 `li` が画面に見当たらない/クリックできない | 番号がページング/仮想化されている可能性がある。「Next」リンクを 1 問ずつクリックするフォールバックに切り替える |
| agent-browser デーモンが不調（接続エラー等） | `agent-browser doctor --fix` で診断・修復し、必要なら `agent-browser close --all` してから再実行する |
| MCMR（複数選択）問題で `correct` が正しく抽出できない | "Correct Answer:" の表記パターンを実測し、抽出ロジック（正規表現）を調整する。実例が見つかるまでは `choice_type: "multiple"` のみ設定し `correct` は空配列で許容する |
| MCSR（単一選択）でも `correct` が空になることがある | 🔴 実運用で確認済み: Whizlabsサイト側のHTML表記ゆれで "Correct Answer: X" が `<strong>Correct</strong>&nbsp;<strong>Answer: X</strong>` のように "Correct" と "Answer" が別々の `strong` タグに分割され、間に `&nbsp;`（U+00A0・ノーブレークスペース）が挟まるケースがある。正規表現の "correct" と "answer" の間を `\s+`（U+00A0等の空白文字も許容）にして対応済み。再発時は同様のHTML表記ゆれを疑い、`agent-browser eval` で該当問題の `.explanation-block` の outerHTML を実測する |
| ログインに失敗する | `WHIZLABS_STATE_FILE` の state が期限切れの可能性がある。ファイルを削除して再実行し、新規ログイン→ state 再保存のフローを踏ませる |

### やってはいけないこと

- **Submit ボタンを絶対に押さない**: 最終問題でのみ出現し、押すと本番受験として履歴に記録される可能性が
  ある。収集は必ず Exit Quiz + `agent-browser dialog accept` で離脱する。
- **Resume Later ボタンも押さない**: 効果がなく、離脱手順を妨げるだけ。
- **Free Test 以外は自分がアクセス権を持つコースのみを対象にする**: Whizlabs は有料コンテンツを含む
  プラットフォームであり、受講権限のないコースへのアクセスは対象外とする。
- **パスワードをログ・コマンド履歴・出力ファイルに残さない**: 認証情報は環境変数経由でのみ扱い、
  `set -x` 等でシェルトレースへ出力しない。state ファイル（`WHIZLABS_STATE_FILE`）はセッショントークンを
  含む秘匿情報のため、コミット対象にせず出力ディレクトリ配下に留める。

---

## shikaku-drill.com

### 概要

shikaku-drill.com は認証不要・全問無料公開の資格・検定問題集サイト（59資格対応）。人間は資格ページの
「学習スタート」（既存進捗があれば「修行開始」＋「続きから学習」）ボタンから開始し、問題ページを1問ずつ
進める。

出力は1試験1JSONファイル（`<slug>.json`）で、`creating-flashcards` の `shikaku_drill_import.py`
ファストパスにそのまま渡せる。kentei-lab と異なり各問題がカテゴリ（`category`）を持つため、Anki投入時は
問題単位で `検定試験::<検定名>::<級>::shikaku-drill::<カテゴリ名>`（級を検出できない試験は
`検定試験::<検定名>::shikaku-drill::<カテゴリ名>`）デッキへ自動振り分けされる。

### 実装方式の詳細

この収集ロジック（`scripts/collect-shikaku-drill.sh`）は kentei-lab の「直接URL反復」方式が使えない点が
根本的に異なる。shikaku-drill は SPA 構造で URL が変化しないため、以下の手順でボタン操作を模倣する。

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
7. 「次の問題へ」ボタンをクリックして次へ進む（存在しなければ最終問題に到達したとみなし終了する）

サイト自体が localStorage ベースの「続きから学習」resume 機構を持つが、これとは独立に本スキルは
進捗サイドカー `<slug>.jsonl` による二重の resume 防御を行う（後述）。

### 前提ツール

- **agent-browser**（Vercel Labs 製・Rust ネイティブ・CDP 直結のブラウザ自動化 CLI）。未導入なら
  `web:automating-browser` スキルの `scripts/install.sh` で導入する。
- **jq**（JSON 整形・検証）。

導入確認:

```bash
which agent-browser && agent-browser --version
which jq
```

### 実行方法

```bash
${CLAUDE_SKILL_DIR}/scripts/collect-shikaku-drill.sh <input-url-or-slug> [output-dir]
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
${CLAUDE_SKILL_DIR}/scripts/collect-shikaku-drill.sh https://shikaku-drill.com/mental1.html ./shikaku-drill-output

# 例: 最初の5問だけ試しに取得（スモークテスト）
SHIKAKU_DRILL_MAX_N=5 ${CLAUDE_SKILL_DIR}/scripts/collect-shikaku-drill.sh mental1 /tmp/mental1-test
```

大規模資格（数百問）は取得に時間がかかる。**`run_in_background: true` での実行を推奨する**。
中断しても resume（後述）により安全に再開できる。

### 出力フォーマット（JSON）

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
- この JSON はそのまま `creating-flashcards` の Step 1（`scripts/shikaku_drill_import.py`）で構造推測を
  スキップして Anki に一括登録できる。kentei-lab と異なり、Anki デッキは**問題単位**で
  `検定試験::<検定名>::<級>::shikaku-drill::<カテゴリ名>`（級を検出できない試験は
  `検定試験::<検定名>::shikaku-drill::<カテゴリ名>`）へ自動振り分けされる（1ファイルに複数カテゴリの
  問題が混在するため）。
- ⚠️ 同一会話内で直接ブリッジする場合の実務上の注意（`disable-model-invocation` によるSkillツール不可・
  `${CLAUDE_PLUGIN_ROOT}` 未設定・デッキ名衝突確認等）は `INSTRUCTIONS.md`
  「shikaku-drill 収集済み JSON のファストパス」節を参照。

### 中断・再開（resume）

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

### サイトへの配慮

shikaku-drill.com は無料公開・認証不要の教育目的サイトである。既定で問題間に 300ms の
待機を挟み、サーバへの負荷を抑える（`SHIKAKU_DRILL_WAIT_MS` で調整可）。大量取得を行う際も、教育・個人
利用目的での節度ある利用に留めること。

### トラブルシュート

| 症状 | 対処 |
|---|---|
| 総問題数(N)が取得できずエラー終了する | サイトのボタン文言（`📚 全問 N問`）が変わった可能性がある。`agent-browser open https://shikaku-drill.com/<slug>.html` してボタン文言を目視確認し、スクリプトの `get-n.js` の正規表現を調整する |
| 開始/続きボタンが見つからずエラー終了する | 「続きから学習」「学習スタート」「修行開始」のボタン文言が変わった可能性がある。`click_first_matching` へ渡す候補文字列を調整する |
| 問題ページの読み込みを検出できない（`.quiz-nav が出現しません`） | DOM 構造が変わった可能性がある。`agent-browser open` して DOM を目視確認し、`.quiz-nav` セレクタを調整する |
| 問題文/選択肢/正解/解説が取得できずエラー終了する | `.q-card`/`.q-cat-badge`/`.q-text`/`.choices .choice`/`.ch-alpha`/`.ch-body`/`.exp-card`/`.exp-correct-bar.ok .exp-correct-text`/`.exp-body` のいずれかの DOM 構造が変わった可能性がある。`agent-browser eval --stdin` で該当 JS を手動実行し、セレクタを調整する |
| 選択肢の数が資格により異なる | 想定内。スクリプトは選択肢数を決め打ちせず、取得できた分だけ列挙する |
| exam_title に想定外のサイト名サフィックスが残る | `document.title` の形式（`"<試験名> | 資格ドリル"`）が変わった可能性がある。`get-title.js` の除去用正規表現を調整する |
| agent-browser デーモンが不調（接続エラー等） | `agent-browser doctor --fix` で診断・修復し、必要なら `agent-browser close --all` してから再実行する |

### やってはいけないこと

shikaku-drill の全問題データはクライアント側の JS/localStorage に埋め込まれている可能性が高いが、
**これを直接パースして問題データを抜き出す実装は行わない**（kentei-lab と同じ方針）。サイト更新で容易に
壊れる上、意図された表示範囲を超えてデータへアクセスすることになるため、常にレンダリング後の
DOM を読む方式のみを採用する。

### 補足: agent-browser eval の呼び出し方

`agent-browser` の一部バージョン（導入検証時点: 0.33.0）には、外部ドキュメントに記載のある
`eval --file <path>` オプションが実装されていないことがある。JS を渡す際は
`agent-browser eval --stdin < script.js`（またはヒアドキュメント）を使う。`scripts/collect-shikaku-drill.sh`
はこの方式で実装済み。
