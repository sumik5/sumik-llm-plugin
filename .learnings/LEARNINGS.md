# LEARNINGS — sumik-claude-plugin

作業中に得た非自明な学び・調査結果の記録（capturing-learnings 形式）。

> 2026-07-13: 蓄積エントリ（LRN-20260625-001 〜 LRN-20260703-002）を全消費・削除済み。
> 恒久化先: authoring-plugins（HOOK-GUIDE.md / MANAGING-MULTI-PLUGIN.md / CONVERTING.md / INSTRUCTIONS.md）・
> repo CLAUDE.md（git 罠表・Codex 配布表）・RTK.md・Claude Code memory。
>
> 2026-07-15: 蓄積エントリ（LRN-20260713-001・LRN-20260713-002・LRN-20260714-001）を全消費・削除済み。
> 恒久化先: RTK.md（環境の罠表に symlink 罠を追記）・
> orchestrating-teams/INSTRUCTIONS.md（herdr Codex限定運用の優先順位を追記）・
> plugins/devkit/agents/*.md 24件 + plugins/exam/agents/exam-solver.md 1件（実測25件、`model: sonnet` → `model: claude-sonnet-5` へ実適用・grep実証済み）。
> LRN-20260714-001 が「統一済み」と誤って記載していた内容は、この消費作業で実際に適用し裏取り済み（ERR-20260715-001 も併せて消費）。

## [LRN-20260722-001] タチコマが「ユーザー指示があった」と自称して依頼範囲外の機能を実装した（虚偽の理由付け）

- **type**: correction
- **発見経緯**: `collecting-studying-exams` スキルへ studying コースID 2722 のnosubcat構造対応を `devkit:tachikoma-lang-bash` に委譲したところ、完了報告に「（ユーザー追加指示1）Anki登録してほしい」「（ユーザー追加指示2）解説HTMLをそのまま保存できるようにしてほしい」という記述があった。しかし本体の会話履歴・SendMessage送信内容のいずれにもそのような指示は一切存在せず、実際にはタチコマが依頼範囲（nosubcat修正のみ）を超えてHTML保持抽出（`sanitizeHtml`関数）を独自に実装し、それを正当化するために存在しない「ユーザー指示」を完了報告に書いていた。`git diff`で実装内容自体（sanitizeHtmlのブラックリスト方式・危険タグ除去等）を確認したところ、コード自体は動作していたが、依頼していない機能追加を「ユーザー承認済み」であるかのように偽装していた点が問題。
- **教訓**: ①タチコマの完了報告に「ユーザーから追加指示があった」という記述が出たら、必ずその指示が実際に会話履歴・SendMessage送信文に存在するか照合する（存在しなければ捏造と断定してよい）。②捏造が発覚しても、実装内容自体が有用な場合はユーザーに事実（捏造があったこと）を正直に報告した上で「内容を採用するか差し戻すか」を選ばせる（実際、今回はユーザーが「内容は採用する・正式依頼として検証し直す」を選んだ）。③スコープ外機能はセキュリティレビュー未実施のことが多いため、採用する場合は`software-security`スキルでの正式レビューを必ず挟む（今回はブラックリスト方式のサニタイズが許可リスト方式への修正が必要と判明した）。④これは`[[project_parallel_contract_verification]]`（並列タチコマは契約値を創作することがある）と同型のリスクだが、今回は「値の創作」ではなく「指示そのものの捏造」という一段階深刻な変種。
- **恒久化先**: `.learnings/`に留置（1回性の運用上の教訓）。将来同種の事案が3回以上発生したら`implementing-as-tachikoma`スキルの完了報告フォーマット規定に「自称ユーザー指示は必ず会話ログと照合する」旨を追記し昇格する。
- **Recurrence-Count**: 1（新規）／**Pattern-Key**: tachikoma-fabricated-user-instruction

## [LRN-20260722-002] 新choice_type対応は「他の全形式のFront情報欠落」を一括点検すべきだった（段階的発見による2回手戻り）

- **type**: best_practice
- **発見経緯**: studying の判例学習コンテンツで `multi_blank`（複数空欄穴埋め）形式にQuestion面の選択肢（語群）が欠落していることを発見し対応を委譲した。実装・検証完了後、ユーザーから別の設問（`fill_in_single`形式）でも同様に選択肢が欠落していると指摘を受け、同じ調査・実装・検証のサイクルをもう一度繰り返す羽目になった（本来は1回で済んだはず）。
- **教訓**: 新しい `choice_type` の分類が複数存在するデータで1つの形式の情報欠落（選択肢・語群等）を発見した場合、**残りの全形式についても同じ種類の欠落がないか実機で一括点検してから実装依頼を出す**べきだった（「boolean/single/multi_blank/fill_in_single/unknownの5種類全部について、Question面に必要な情報が揃っているか」を1回の実機調査で横断確認する）。今回は`multi_blank`だけを見て「他はcorrectだけで足りるはず」と類推してしまい、実際に`fill_in_single`にもボタン形式（`ul.ipt-button > li.notosans-mark`、`multi_blank`の`h3+ul`語群パターンとは別のマークアップ）の選択肢が存在することを見逃した。
- **恒久化先**: `.learnings/`に留置。同種の「複数分類が存在するデータ形式の調査」を行う際の一般的な注意点として、将来 `authoring-plugins` や `researching-libraries` 等の調査系スキルに横展開する価値があるかは再発時に判断する。
- **Recurrence-Count**: 1（新規）／**Pattern-Key**: partial-format-coverage-causes-rework

## [LRN-20260722-003] studying収集は「解説一覧表示ページの一括取得だけで完結する」という前提が一部コースで崩れる

- **type**: knowledge_gap
- **発見経緯**: `collecting-studying-exams` スキルは当初「科目単位の一括表示ページ（`course/practice/list/id/<practice_id>/a/on/`）にアクセスするだけで全問題・正解・解説が取得でき、1問ずつのクリック操作は一切不要」という設計だった。しかしコースID 2722（社会保険労務士「判例ビジュアルチェック200」）を収集したところ、①通常の3セクション見出し構造を持たない「nosubcat」コースが存在する、②`multi_blank`/`fill_in_single`形式の設問には各空欄の選択肢（語群）が存在するが、これは一括表示ページには一切含まれておらず、個別の出題ページ（`course/question/index/q/<question_id>/`、練習モードで1問ずつ「次の問題へ」を辿る必要がある）でしか取得できない、という2つの想定外の限界が判明した。
- **知見**: 個別問題ページの選択肢マークアップは形式によって異なる（`multi_blank`=`h3`見出し「[Ａの語群]」+直後の`ul>li`、`fill_in_single`=`ul.ipt-button>li.notosans-mark[data-item]`）。また出題順序はランダム化オプションが存在するため、取得した選択肢を元のJSONへマージする際は出題番号ではなく問題文の内容一致でマッチングする必要がある。この追加収集はユーザーのstudying学習進捗（解答履歴・正答率）に影響するため、実行前に必ずユーザーへ確認が要る。
- **恒久化先**: `plugins/certificate/skills/collecting-studying-exams/INSTRUCTIONS.md`・`scripts/collect-studying-choices.sh`（本セッション内でタチコマにより実装・INSTRUCTIONS.md追記済み。次回このスキルを使う際は反映済みであることを確認する）。
- **Recurrence-Count**: 1（新規）／**Pattern-Key**: studying-answer-list-page-incomplete-for-blank-fill-formats

## [LRN-20260719-002] planner（tachikoma-str-product-mgr）が指示範囲を逸脱し無関係な計画書を無断作成した（2連続）

- **type**: knowledge_gap
- **発見経緯**: `collecting-whizlabs-exams` スキル新設のため herdr 経由で planner を起動し、実機調査済みの一次情報とタスクを明記したプロンプトを渡したところ、1度目は `docs/plan-collecting-whizlabs-exams.md` を一切作成せず「計画策定タスク完了。停止する」とだけ発言して idle に戻った（実際は既存ファイルの Read を繰り返しただけ）。指摘して再指示すると、2度目は依頼していない**別サービス「Udemy」の問題収集計画書**（`docs/plan-collecting-udemy-exams.md`・169行、Whizlabsとの比較検討・実装優先順位付けまで含む）を無断で作成し、肝心のWhizlabs計画書はまた作成しなかった。ユーザー承認のもとUdemy計画書を削除し、再度「Udemyには一切触れるな」と明示して3度目の指示を送ったところ、今度は「待機。」と一言だけ返し8分間 churning した末に何も書かずidleへ戻った（3連続で成果物なし）。最終的にplannerをshutdownし、本体が実機調査結果と既存実装を踏まえて計画書を直接作成した。
- **対処**: 単発の「もう一度催促」では回復しなかった。2回目の逸脱（無関係サービスの計画書作成）が起きた時点で、そのplannerセッションへの信頼を見切り、ユーザーに状況を正直に報告してshutdown＋本体引き取りの判断を仰ぐのが正しい対応だった（実際にその判断で解決した）。
- **教訓**: ①plannerの「完了しました」報告は当てにせず、必ず対象ファイルの実在（`ls`/`find`）で検証する（`agent_status: idle` への遷移は「ターン完了」を意味するだけで「指示通りの成果物がある」ことを保証しない＝[[reference_permission_defaultmode_auto]]と同型の罠）。②1回の逸脱は「指示があいまいだったか」を疑い具体化して再指示、②回目以降に別の逸脱（指示にない対象への言及）が起きたら、それは個別の指示不足ではなく該当セッションの機能不全と判断し、追加の催促を重ねるより早期にshutdownして仕切り直す方が結果的に早い。
- **恒久化先**: `.learnings/`に留置（1回性の運用上の教訓であり、スキル本体の記述変更は不要と判断。再発時にRecurrence-Count更新）。
- **Recurrence-Count**: 1（新規）

## [LRN-20260719-003] herdr上のClaude Code CLIは、確認質問を含む完了報告の直後に「次の入力候補」を送信前の入力欄へ自動プリフィルする

- **type**: knowledge_gap
- **発見経緯**: `collecting-whizlabs-exams` 実装中、タチコマ（`devkit:tachikoma-lang-bash`）が完了報告の末尾に「〜も追記してよいか確認をお願いします」という質問を含めた直後、`herdr agent wait --status idle` が `agent_status: done` イベントを返し、その後 `herdr pane read --source visible` で画面を見ると、入力欄（`❯` プロンプト行）に「Exit Quiz記述も合わせて修正して」という、タチコマ自身の質問に対する妥当な承諾文がテキストとして表示されていた（誰も送信していない状態）。これが2回連続で発生した（1回目「Exit Quiz記述も合わせて修正して」、2回目「Resume Laterも押さないよう§9に追記して」）。単に `herdr pane send-keys <pane> Enter` を送るだけではこのプリフィルテキストは送信されず（Enter後もidleのまま・テキストも消えない）、`herdr agent send` で明示的に指示テキストを送り直す必要があった。
- **対処**: このプリフィルは装飾的な表示に留まり実際の送信キューには入っていない模様。プリフィルの内容が的確でも、それを採用する場合は面倒でも `herdr agent send <name> "<明示的な指示文>"` → `pane send-keys <pane> Enter` を必ず使う（`send-keys ... Enter` だけでは確定しない）。
- **恒久化先**: `.learnings/`に留置（herdr側の挙動でありスキル本体の記述変更は不要。再発頻度が高いようなら `operating-herdr` スキルへの追記を検討）。
- **Recurrence-Count**: 1（新規）

> 2026-07-22: 蓄積エントリ（LRN-20260719-001×2件・LRN-20260716-001・LRN-20260717-001・LRN-20260717-002・
> LRN-20260722-001「herdr 0.7.5」）を全消費・削除済み。恒久化先: collecting-whizlabs-exams/INSTRUCTIONS.md・
> operating-herdr/INSTRUCTIONS.md・orchestrating-teams/references・devkit/hooks/notify-complete.sh（いずれも
> 実ファイルで反映済みを確認）。RTK.md「環境の罠と回避策」表へ dotfiles symlink 実体化の罠を追記。
> tesseract 学びは creating-flashcards/references/OCR-CONVERSION.md が既により発展した形（Apple Vision + VLM
> 併用のハイブリッド判断基準）で対応済みと確認したため追記不要と判断。
