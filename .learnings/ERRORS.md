# ERRORS — sumik-claude-plugin

作業中に調査・解決した非自明なエラーの記録（capturing-learnings 形式）。

> 2026-07-13: 蓄積エントリ（ERR-20260625-001 〜 ERR-20260711-001）を全消費・削除済み。
> 恒久化先: authoring-plugins（HOOK-GUIDE.md / MANAGING-MULTI-PLUGIN.md / CONVERTING.md / INSTRUCTIONS.md）・
> repo CLAUDE.md（git 罠表・Codex 配布表）・RTK.md・Claude Code memory
> （workflow-journal-identity / background-task-dies-across-session / no-unsolicited-claude-md-edits）。
> hook 実装系（notify-complete / learnings-error-detector / rtk-rewrite / hooks-codex.json）は修正適用済みを実ファイルで確認。
>
> 2026-07-15: 蓄積エントリ（ERR-20260713-001・ERR-20260713-002・ERR-20260715-001）を全消費・削除済み。
> ERR-20260713-001（pane_id 誤認）は operating-herdr/INSTRUCTIONS.md に既に反映済みを確認（削除のみ）。
> ERR-20260713-002（Codex確認UI停止）は operating-herdr/INSTRUCTIONS.md へ新規恒久化。
> ERR-20260715-001（model移行の未適用矛盾）は plugins/devkit/agents/*.md 24件 + plugins/exam/agents/exam-solver.md 1件（実測25件）へ
> `model: claude-sonnet-5` を実適用して解消（grep実証済み・LRN-20260714-001と同時消費）。

> 2026-07-22: 蓄積エントリ（ERR-20260721-001・ERR-20260719-001×2件・ERR-20260716-001・ERR-20260719-002）を
> 全消費・削除済み。恒久化先: repo CLAUDE.md（194/233/305/308行目のversion期待値をdevkit 14.12.2・
> lang 2.3.0・web 1.4.0・certificate 1.4.2へ実修正・同期チェックスクリプトでALL OK確認済み）・
> RTK.md「環境の罠と回避策」表（ロケール依存sort/uniq偽陽性を追記）。collecting-whizlabs-exams（strong分割
> パターン）・operating-herdr（permission-mode auto統一）は既に反映済みを実ファイルで確認。
> bash-triple-backtick-in-echo は一過性の学びのため恒久化不要と判断。
>
> 2026-07-23: 蓄積エントリ（ERR-20260723-001・ERR-20260723-002・ERR-20260723-003）を全消費・削除済み。
> 恒久化先: `collecting-studying-exams` スキル本体（`scripts/collect-studying.sh`・`INSTRUCTIONS.md`）。
> ERR-001（固定3セクション名・1科目=1practice_id前提）は `collect-practice-links.js` の見出し検出を
> `h2.m-ctop-course-d-list__title` 全走査＋「講座」除外方式に、リンク収集を単数から複数取得（1科目=複数
> レッスン対応）に、展開待機を固定500msからポーリング方式に変更して解消。ERR-002（`.redactor-editor`
> 複数存在での選択肢欠落）・ERR-003（無印`<ol>`の番号マーカー欠落）は `read-practice-page.js` に
> `extractQuestionHtml()`・`numberOlChoices()` を追加して解消（`devkit:tachikoma-lang-bash` 実装・
> 本体が差分とグレップ検証で確認済み）。certificate version 1.4.3→1.4.4（PATCH）。
> CLAUDE.md inbox の対応 PROPOSAL エントリも削除済み。

## [ERR-20260723-004] collecting-studying-exams: nosubcat見出し(lessonタイプ)混入によるCDPエラー

社労士コース（`https://member.studying.jp/course/id/2301/`）収集時、`collect-studying.sh`
（certificate 1.4.5、キャッシュ版）の`collect-practice-links.js`が`✗ CDP error (Runtime.evaluate):
Inspected target navigated or closed`で2回連続失敗した。

原因: コーストップページに「今日のまとめのまとめ」という見出しがあり、これは
`h2.m-ctop-course-d-list__title m-ctop-course-d-list__title--nosubcat is-marked`という
**2つのクラスを同時に持つ**要素だった。`HEADING_SELECTOR = 'h2.m-ctop-course-d-list__title'`は
このクラス併記を想定しておらず、`EXCLUDE_HEADING_SUBSTR = ['講座']`の文字列除外もすり抜けるため、
通常の問題集セクションとして扱われてしまう。この見出し配下のトグルは
`onclick="open_detail('lesson', <id>, event)"`という**lessonタイプ**（動画/音声講座）であり、
`practice`タイプの科目トグルと異なりクリックで実際のページ遷移を起こす。これがCDPエラーの直接原因。

解決: `EXCLUDE_HEADING_SUBSTR`に見出しラベルの文字列マッチで除外を追加する方式が有効
（`--nosubcat`クラスでの構造的除外は別の設計欠陥[ERR-20260723-005]を誘発するため非推奨）。

汎用性: studyingの無料公開コンテンツ・特別企画コンテンツには通常の3セクション以外に
`--nosubcat`クラス付きの見出しが混在しうる（「今日のまとめのまとめ」のように「講座」を
含まないラベルもある）。見出し文字列だけでなく、配下トグルの`onclick`属性が`practice`か
`lesson`かで判定する方がより堅牢（`EXCLUDE_HEADING_SUBSTR`のような固定文字列リストは
新しいコースパターンで再度すり抜ける可能性がある）。

## [ERR-20260723-005] collecting-studying-exams: 境界計算がフィルタ後配列基準で末尾セクションの境界喪失

ERR-004の一次対策として`HEADING_SELECTOR`から`--nosubcat`要素を除外したところ、別の収集漏れ
（かつ再度のCDPエラー）が発生した。

原因: `collect-practice-links.js`のメインループは`nextHeadingEl = headings[i+1].el`で「次の
見出し」を計算するが、`headings`は**EXCLUDE後のフィルタ済み配列**。除外対象の見出しが末尾に
連続する構成（今回: スマート問題集→セレクト過去問集→選択式ポイント問題集→総まとめ講座(除外)→
今日のまとめのまとめ(除外)）では、フィルタ後配列で最後に残る対象見出し「選択式ポイント問題集」の
`nextHeadingEl`が`null`になる。`nextHeadingEl`が`null`だと`isAfter`による範囲フィルタが
「見出し以降」だけになり、**ページ末尾までの全トグル**（除外したはずの「総まとめ講座」
「今日のまとめのまとめ」配下のlessonタイプトグルも含む）を誤って対象化してしまう
（実機確認: 本来9件のはずが27件検出）。

解決: `nextHeadingEl`計算を、フィルタ前の全見出し配列（`allHeadings`）基準にする
（`allHeadings.indexOf(headingEl) + 1`）。フィルタ後配列上のインデックスではなく、
DOM上の実際の隣接関係を使う。

汎用性: 「対象外要素を除外してから、除外後配列で次要素/境界を計算する」という2段階処理は、
除外対象が配列の末尾に連続する場合に境界が消失する典型的な設計バグパターン。除外判定と
境界計算は別々の配列基準で行う必要がある（フィルタ前配列で隣接関係を確定してから、
フィルタ後の要素だけをループ対象にする）。同種のロジック（見出しでセクション分割する
スクレイピングコード全般）に波及しうる。

## [ERR-20260723-007] collecting-studying-exams: TOGGLE_SELECTORのaタグ誤マッチとページ遷移によるCDPエラー

社労士系無料公開コース（`https://member.studying.jp/course/id/2797/`「白書統計厳選チェックテスト」）
を収集しようとした際、ERR-004/005修正後の版でも別の構造が原因で同種のCDPエラーが起きうることが判明した
（実行前に事前シミュレーションで検出・実収集は未発生）。

原因: このコースは見出しが1件のみの nosubcat 構造（`headings.length === 0` にならないためメイン
ループで処理される）。`TOGGLE_SELECTOR = '.m-ctop-course-d-list__link'` は div型トグル自体
（`onclick="open_detail('practice', ...)"`・`is-open`クラス付き）だけでなく、**既に展開済みの
`<a href="course/practice/index/id/<id>/...">`要素自体にも同じクラス名が付与されている**。今回の
コースでは`isAfter`の境界判定でdivトグル（見出しh2を内包する祖先要素のため境界外）が除外され、
`<a>`要素だけが`toggles`に残る。`<a>`要素は`is-open`クラスを持たないため`wasOpen`判定が`false`に
なり`toggle.click()`が実行されるが、`<a href="...">`要素のクリックは実際にページ遷移を起こし
agent-browserのCDP接続を落とす（ERR-004のlessonタイプ混入と症状は同じだが原因は別:
今回は`TOGGLE_SELECTOR`自体がdivとaの両方にマッチすることが原因）。

解決: メインループの`toggle`走査冒頭に`toggle.tagName === 'A'`の早期分岐を追加し、`<a>`要素で
既に`course/practice/index/id/<id>`形式の`href`を持つ場合はクリックせず、hrefから直接
`practice_id`を抽出して結果へ追加するよう修正した（div型トグルの既存ロジックは変更なし）。

汎用性: 「同じクラス名がトグル(div)と展開済みリンク(a)の両方に付与されている」というパターンは
studyingのnosubcat構造で複数回観測されている（nosubcatフォールバック側の既存教訓と同型のバグが
メインループ側にも潜んでいた）。DOM要素をセレクタで一括取得してから`click()`する設計では、
「クリック不要なリンク要素が同じセレクタに紛れ込んでいないか」を`tagName`で必ず確認すること。
実行前に軽量な事前シミュレーション（実際にクリックせず、対象要素のtagName/onclick/hrefを一覧化
するevalクエリ）を挟むと、実収集を汚さずに構造の異常を検出できる。

## [ERR-20260723-006] AnkiConnect大量連続リクエストでのConnection refused/reset

`studying_import.py`を264ファイル分ループ実行（間隔なし）した際、82件が
`ConnectionResetError: [Errno 54]`または`URLError: <urlopen error [Errno 61] Connection refused>`
で失敗した。Anki本体プロセスは生存しており（`curl`での`version`アクション確認済み）、
AnkiConnect側の一時的な過負荷・キューあふれが原因と推測される。

解決: 失敗ファイルのみ抽出し、各リクエスト間に`sleep 0.5`を挟んで再実行したところ全件成功
（82/82）。

汎用性: AnkiConnect経由での大量一括投入（100件超）では、リクエスト間隔を空ける
（0.5秒程度）か、初回失敗分を後段でリトライする設計を前提にすること。exit code非0の
ファイルだけ抽出して再実行する運用パターンは他のバッチ投入作業にも流用できる。
