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

本スキルの主収集（`scripts/collect-studying.sh`）は、Whizlabs 版のような**1問ずつの SPA ナビゲーション
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
  - **🔴 選択肢（choices）の後付け取得（`scripts/collect-studying-choices.sh`・実機確認済み）**:
    「解説一覧表示」ページ（本スクリプトの収集元）には`multi_blank`・`fill_in_single`双方の選択肢
    情報が一切含まれない（`.list_question`全件を実機確認し「語群」という文字列が0件であることを
    確認済み）。選択肢は個別の出題ページ（練習モード、
    `course/question/index/q/<question_id>/`。`question_id`は動的に決まり事前列挙できない）に
    のみ存在するため、別スクリプト`scripts/collect-studying-choices.sh`（`collect-studying.sh`が
    生成済みのJSONを入力に取り、科目トップページ→練習モード開始→個別出題ページを1問ずつ
    「次の問題へ」で辿って選択肢を取得し、同じJSONへ上書き保存する）で事後的に埋める。
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
    🔴 **Anki投入側（`creating-flashcards`スキルの`studying_import.py`/`anki_toolkit.py`）は変更不要**:
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
    構造そのもの）は実技側で未確認のまま。`.list_question`/`.list_answer` 構造が異なる場合は §7
    トラブルシュートを参照して調整する。
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
  ⑤どれにも当てはまらない場合のみ`"unknown"`、の優先順で行う（`kanalist`の有無だけで判定すると
  矛盾データが生じる不具合・`"boolean"`条件が厳しすぎて○×以外の一問一答が`"unknown"`に落ちる不具合が
  それぞれあったため修正済み）。
  - `"single"`: 4択等。`choices`に選択肢テキスト配列が入る。通常の`ol.kanalist > li`形式は
    `"ア. <選択肢テキスト>"`（マーカー文字はDOMのテキストノードに含まれないため出現順に機械的に
    割り当てる）。`table.transtable`形式（空欄補充の組み合わせ選択等）は各行の全`td`テキストを結合した
    ものがそのまま選択肢文になる（レターは`td`内テキストに既に含まれるため追加のレター割り当ては無い）。
  - `"multi_blank"`: 複数空欄穴埋め形式（実機確認済み: 「判例ビジュアルチェック200」の全211問中
    約73%を占める）。`choices`は4択ではないため空配列。`correct`に`.question_multi table tbody tr`
    の各行から`"<ラベル>. <正解テキストHTML>"`形式の文字列が行ごとに1要素として入る
    （例: `["Ａ. <正解テキスト>", "Ｂ. <正解テキスト>"]`。行数は2〜3行以上まで変動）。
  - `"boolean"`: ○×形式。`choices`は空配列。
  - `"fill_in_single"`: 単一空欄穴埋め形式（一問一答）。`kanalist`/`transtable`/`.question_multi`の
    いずれも持たず、`.notosans-mark`の値が○×以外の単語・フレーズの場合に該当する。`correct`には
    `.notosans-mark`の値がそのまま`[correctMark]`として入る。`choices`は空配列。
  - `"unknown"`: `ol.kanalist`・`table.transtable`・`.question_multi`のいずれも持たず、`.notosans-mark`
    自体に値が無い特殊設問（実機確認済み: 通常の4択・穴埋め形式とDOM構造が異なる設問が稀に存在する）。
    `correct`は空配列のまま。`creating-flashcards`の`studying_import.py`は`"unknown"`を
    `qtype="basic"` + `needs_fix=True`にマッピングし手動確認を促す。
- `correct`: `choice_type`により由来が異なる。`"boolean"`/`"single"`/`"fill_in_single"`/`"unknown"`は
  `.list_answer`側の`h4 .notosans-mark`から直接取得した単一の正解（○×形式は`["○"]`/`["×"]`、選択式は
  正解のレター例`["エ"]`、単一空欄穴埋めは正解の単語・フレーズそのまま。取得できなかった場合は空配列。
  §7参照）。`"multi_blank"`は`.question_multi`の各行から取得した複数空欄の正解一覧（上記参照）。
- `explanation`: 優先順で汎用フォールバックする。①`ol.kanalist`があればその内容（`table.gakusyu`が
  あれば末尾に結合）、②無ければ`table.gakusyu`のみ、③どちらも無ければ`.redactor-editor`の全文
  （`table.transtable`形式はこのケースに該当し、選択肢ごとの個別解説ではなく全文まとめての解説になる）。
- 🔴 `question`・`explanation` は**厳格な許可リスト方式でサニタイズ済みのHTML文字列**
  （`sanitizeHtml()`で抽出した`innerHTML`）で保存される（`textContent`ではない）。`<p>`/`<br>`/
  `<span class="span-bold">`〈太字強調〉/`<span class="span-square">`〈空欄マーカー〉等の書式を
  保持する。複数セグメントの結合は`'<br>'`区切り。危険タグ（`script`/`style`/`iframe`等）は中身ごと
  完全除去、許可リスト外タグはunwrap、属性は要素ごとの許可リスト（`class`は正規表現制限付き、`img`は
  `src`/`alt`、`a`は`http(s)`スキームの`href`のみ）でフィルタ済み。`creating-flashcards`の
  `studying_import.py`/`anki_toolkit.py`はfront/backを raw HTML として素通しする設計のため、この
  JSONをそのままAnki登録に使える（追加のエスケープ処理は不要）。
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
| 3セクション見出しが存在しないコース（例: 無料公開特別コンテンツ）で「科目を検出できませんでした」になる | nosubcat構造（`h2.m-ctop-course-d-list__title--nosubcat`がカテゴリ見出しとして列挙される構造）の可能性が高い。`collect-practice-links.js`はこの場合、見出しの`closest('.m-ctop-course-d-list')`配下`ul.m-ctop-course-d-list__list--nosubcat`内の`a[href*="course/practice/index/id/"]`から`practice_id`を抽出するフォールバックを実装済みのため通常は自動対応される。**🔴 見出しdivと科目リンクaタグの両方に同じクラス名`m-ctop-course-d-list__link`が付与されており、divのonclick属性`open_detail('practice', <id>, event)`の`<id>`はカテゴリ全体の集約ID（誤って抽出すると解説一覧表示ページが404になる）であり真の`practice_id`ではない**（過去に一度この誤りで実装した実績あり）。それでも0件の場合はDOM構造が変わった可能性があるため、`agent-browser open <course-list-url>`してDOMを目視確認し`NOSUBCAT_HEADING_SELECTOR`/`NOSUBCAT_LIST_SELECTOR`を調整する |
| 多くの科目が `practice-link-not-found-after-click` で検出漏れになる（一部しか収集できない） | 展開アニメーションの待機時間が不足している可能性がある（実機確認済みの既定値は500ms）。`collect-practice-links.js` の `EXPAND_WAIT_MS` を延長する。回線・端末が遅い環境では500msでも不足することがある |
| コースタイトルが「スタディング マイページ」等の共通ヘッダー文言になってしまう | `get-course-title.js` は `document.title` から `" - スタディング 会員ページ"` サフィックスを除去して使う設計になっている。サフィックス表記が変わった場合はこの正規表現を調整する |
| 科目ページの `.list_question`/`.list_answer` が0件で「問題データを抽出できませんでした」でスキップされる | DOM 構造（クラス名）が変わった可能性がある。`agent-browser open <practice-list-url>` して DOM を目視確認し、`read-practice-page.js` 相当のセレクタ（`.list_question`/`.list_answer`/`ol.kanalist`/`h4 .notosans-mark`/`table.gakusyu`）を調整する |
| メタ情報の総問題数が取得できず `total-questions-metadata-not-found` 警告が出る（収集自体は `.list_question` の実件数で継続する） | メタ情報の表記順序またはワードが変わった可能性がある。`agent-browser open <practice-list-url>` してテキストを目視確認し、`read-practice-page.js` のメタ情報正規表現（`N分 → N問 → 合格ライン` の順序）を調整する。収集自体は `.list_question` 件数を `total_questions` として継続するため致命的ではない |
| セレクト過去問集（実技試験対策）の科目だけ抽出に失敗する | 科目トグルの展開自体は学科試験対策と同一UI基盤であることを実機確認済み（著作権法科目で確認）。ただし科目ページ内部（`.list_question`/`.list_answer` 構造）は実技側で未確認のため、これが異なる可能性がある。1件サンプルをブラウザで開いて構造を確認し、必要ならパースロジックの分岐を追加する |
| 4択問題の正解（`correct`）が空配列になる | `.list_answer h4 .notosans-mark` が見つからなかった可能性がある（`correct-mark-not-detected` 警告で検知できる）。該当科目の解答ページを開いて実際のDOM構造を確認し、セレクタを調整する |
| `choice_type` が `"unknown"` になる問題がある（`choices`/選択肢解説が空になる） | `ol.kanalist`・`table.transtable`・`.question_multi` のいずれも持たず、かつ `.notosans-mark` 自体に値が無い特殊設問（例: 未知の新しい設問形式）。空欄補充の組み合わせ選択タイプは `table.transtable`、複数空欄穴埋めタイプは `.question_multi`、単一空欄穴埋め（一問一答）タイプは `choice_type: "fill_in_single"` で対応済みのため、これでも `"unknown"` になる場合はさらに別の未対応DOM構造の可能性が高い。`choice-structure-not-recognized` 警告で検知できる。無理に○×/4択へ押し込めず `"unknown"` のまま出力する設計のため、Anki投入時は `studying_import.py` が `needs_fix=True` でマークする。該当科目ページを開いて実際の設問形式を確認し、必要なら専用の抽出分岐を追加する |
| 多くの問題で `correct` が空配列のまま・`choice_type` が `"unknown"` に偏る（判例学習系コンテンツ等） | `.notosans-mark` による単一正解ではなく、`.question_multi table tbody tr`（複数空欄穴埋め・`choice_type: "multi_blank"`）形式である可能性が高い。実機確認済み: 「判例ビジュアルチェック200」では全211問中約73%がこの形式だった。`collect-studying.sh` は `.question_multi` の有無で自動判定し `correct` に`"<ラベル>. <正解テキスト>"`形式で複数行を格納するフォールバックを実装済みのため通常は自動対応される。それでも検出漏れがある場合は `agent-browser open <practice-list-url>` してDOMを目視確認し `.question_multi` 配下の `table`/`tbody`/`tr`/`th`/`td` 構造を確認する |
| `choice_type` が `"unknown"` に多数分類されるが `correct` 自体は非空（`.notosans-mark` の値は取得できている） | `.notosans-mark` の値が○×以外の単語・フレーズ（単一空欄の一問一答形式）である可能性が高い。実機再調査で判明（practice_id=223631の7・8問目等）: 当初「第3の未知形式」と誤認していたが、実際は`"boolean"`判定条件（○/×限定）が厳しすぎたことが原因だった。`collect-studying.sh` は `choice_type: "fill_in_single"` で対応済みのため通常は自動対応される。それでも `"unknown"` になる場合は該当科目ページを開いて `.notosans-mark` の実際の値を確認する |
| `table.transtable` 形式の設問で `choices` が意図した行分割にならない | `table.transtable` のDOM構造（`tbody > tr > td`）が想定と異なる可能性がある。該当科目の問題ページを開いて実際の `table.transtable` 構造を確認し、`read-practice-page.js` の行・セル抽出セレクタを調整する |
| 収集した問題のQuestionフィールドに選択肢の記述はあるが末尾の個数選択肢（１つ／２つ…）が無い | `.list_question` 内に `.redactor-editor` が複数存在するケース（問題文用と個数選択肢用の2つに分離）である可能性が高い。`read-practice-page.js` の `extractQuestionHtml()` が `querySelectorAll('.redactor-editor')` で全件連結する設計になっているか確認する |
| 選択肢が並んでいるのに番号（１・２・３…）が一切表示されず正解と対応が取れない | クラス名の無い `<ol>` + `<li class="checkable_list_item">`（肢自体が正解値になる単一選択形式）である可能性が高い。`read-practice-page.js` の `numberOlChoices()` が `ol.kanalist` 以外の `<ol>` にも全角数字マーカーを前置しているか確認する |
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
