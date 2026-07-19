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

## [LRN-20260719-001] Whizlabs 問題集の巡回方式は kentei-lab と根本的に異なる（URL直接反復不可・SPA内番号ジャンプ＋ネイティブconfirmダイアログ）

- **type**: knowledge_gap / best_practice
- **発見経緯**: certificate プラグインへ `collecting-whizlabs-exams` スキルを新設するため、agent-browser でログイン済み実ブラウザから `https://www.whizlabs.com/learn/course/certified-cloud-security-professional/199/pt`（CCSP Free Test・Practice Test 1）を実機調査。
- **知見**:
  a. **URL は固定**。kentei-lab の `/quiz/<slug>/<n>` 直接反復は使えない。SPA内の問題番号 `li`（"1","2",...,"N"）を直接クリックすることで任意問題へジャンプできる（`agent-browser click` のref経由でも、`eval`でDOM直接クリックでも可）。
  b. **選択肢クリック不要**。`show Answer` ボタン（`.content button.btn-showAnswer`）をクリックするだけで正解・解説・参考資料まで全開示される（kentei-lab は選択肢を1つクリックする必要があった＝真逆）。
  c. **DOM構造**: `.que-category`=ドメイン/カテゴリ表示（"Domain: ..."）／`.content > div > p`=問題文／`fieldset .radio-ans input[type=radio|checkbox]`+隣接`.dangerouslySetInnerHTML p`=選択肢（Exam Instructions に "MCSR"（単一）と "MCMR"（複数）の2形式が明記されており、input type で判別する実装が必要。実機サンプリング150問では全部 radio だったため checkbox の実物は未確認）／`.explanation-block`=解答ブロック（`<p><strong>Correct Answer: X</strong></p>` + 生HTMLの解説（`<ul><li>`形式で各選択肢の正誤理由）+ `Reference:` 見出し＋外部参考URLの `<a href>`）。
  d. **リロード・タブクローズで進捗が失われる**。ページ `reload` すると `/quiz/<id>/practice/start/` → `/quiz/<id>`（テスト詳細ページ）に戻り「Start Quiz」からやり直しになる。「Resume Later」ボタンは存在するが実効性なし（実測: Free Testで20問目までジャンプ→Resume Later→コース一覧に戻ると「Your Previous Attempts」は「No Attempts Found」のまま＝サーバー側に保存されない）。**resume は同一ブラウザプロセス・同一クイズ試行内でのみ可能**（スクリプト側JSONLの最大取得済み番号+1へジャンプして続行する擬似resumeに留まる。ブラウザ/agent-browserデーモンが死んだら最初から）。
  e. **Exit Quiz の離脱確認はブラウザネイティブ `window.confirm()`**。通常の `click` 待ちだけだと `agent-browser` コマンドがダイアログでブロックされ120秒タイムアウトでバックグラウンド送りになる（"A JavaScript confirm dialog is blocking the page" 警告）。`agent-browser dialog accept` で解消する。**Submit ボタン（最終問題でのみ出現）は絶対に押さない**——受験履歴に本番受験として記録される可能性があるため、収集は必ず Exit Quiz + dialog accept で離脱する（実測: この手順なら「No Attempts Found」のまま履歴を汚さず離脱できる）。
  f. ログインは通常のメール+パスワードフォーム（`textbox "Email ID"` / `textbox "Password"` / `button "Sign In"`）。agent-browser の Auth Vault（`auth save --password-stdin` / `auth login`）でセッション永続化するのが望ましい（パスワードをコマンド引数に残さないため）。
  g. 1コースに複数クイズ（CCSPは Free Test・Practice Test 1-7 の8個）が存在し、それぞれ別 quiz ID（例: Free Test=54753, Practice Test 1=56436）を持つ。「開始→practice mode チェック→Start」の導線を毎回踏む必要がある（URL直接構築での起動は未検証）。
  h. 🔴 **【実装フェーズで追加判明】コース一覧ページのクイズ行は `<a href>` を一切持たない**。`.box-item > .box-head > .name`（div要素・Reactのイベントハンドラでクリックされる）で、quiz-id は一覧ページのDOMに一切埋め込まれていない。当初の実装は `a[href*="/quiz/"]` セレクタで一括抽出しようとして0件ヒットし必ずエラー終了した。正しい実装は「`.box-item .name` のインデックス順クリック→遷移後に `ab get url` で現在URLを取得→ `/quiz/([A-Za-z0-9_-]+)/` で quiz-id を抽出→処理後は毎回コース一覧を開き直す」というループ。一覧ページ調査を「クイズ詳細ページのURL構造」だけで済ませ「一覧ページ自体のDOM」を見ていなかったのが原因＝**同じ調査でも「対象ページ」を一段階広く取るべきだった**。
  i. 🔴 **【実装フェーズで追加判明】Exit Quiz は3段階フロー**（当初 e. で「ネイティブconfirmのみ」と記載していたのは不正確）。①「Exit Quiz」リンクをクリック→**カスタムモーダル**が開く（`Submit`/`Resume Later`/`"You'll lose your progress, are you sure you want to leave?"`という長文ボタンの3つ）→②この長文ボタン（"lose your progress" を含む部分一致で判定するのが安全。Submit/Resume Laterの文言と重複しない固有部分文字列を使う）をクリック→③ここでようやくネイティブ `window.confirm()` が発生し `dialog accept` で解消できる。①のみで即 `dialog accept` を呼ぶ実装は「まだダイアログが出ていない」状態でエラーになるか、モーダルが開いたまま次の処理に進んでしまう。**Submit と Resume Later はどちらも押してはいけない**（Resume Laterは実効性がないだけで実害はないが、離脱手順を妨げるため避ける）。
- **恒久化先**: `plugins/certificate/skills/collecting-whizlabs-exams/INSTRUCTIONS.md`・`scripts/collect-whizlabs.sh`（実装済み・h/iとも反映済み）。
- **Recurrence-Count**: 1（新規）

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

## [LRN-20260716-001] herdr `agent start --split` の分割対象は「現在フォーカスされているpane」（呼び出し元でも直前作成paneでもない）

- **type**: best_practice / knowledge_gap
- **発見経緯**: ユーザーから「subagentが親paneの下にどんどん積み重なって見づらい」と報告を受け、herdr 0.7.3 実機（本セッション自身が herdr pane `w4:p2` として稼働中）で `herdr agent start <name> --split down --no-focus` を実行し `herdr pane layout --current` で分割先を確認したところ、CLIを呼び出したpane（自分自身）でも直前に作ったpaneでもなく、**その時点でフォーカスされていたpane**が分割された。`herdr api schema --json` で socket API の `AgentStartParams` を確認すると `target_pane_id` フィールドが存在しない（`PaneSplitParams` にはある＝非対称）ことも確定させた。
- **回避策（実機で動作確認済み）**: `herdr agent focus <name>` はagent名から対象paneへ実フォーカスを移せる（`pane focus` CLIは `--direction` 相対移動のみで絶対pane_id指定がないため、これが唯一の代替手段）。複数体を「親の右→その下へ縦積み」で整列させるには、1体目は `--split right --no-focus`、2体目以降は直前のagent名を `agent focus` してから `--split down --no-focus` を繰り返し、最後に `herdr pane focus --direction left --current` で親へフォーカスを戻す（親|右列の2カラム構成なら "left" で一発）。
- **恒久化先**: `plugins/devkit/skills/operating-herdr/INSTRUCTIONS.md`（新規callout・新規レシピ「複数エージェントを整列よく起動する」・notes追記）、`plugins/devkit/skills/orchestrating-teams/references/TEAM-PATTERNS.md`・`WORKFLOW-GUIDE.md`（フォーカス制御なしの `--split right` 連打サンプルを修正）、`~/dotfiles/claude-code/rules/plugins-and-commands.md`・`~/dotfiles/codex/AGENTS.md`（該当箇所に一文追記）に反映済み。
- **Recurrence-Count**: 1（新規）

## [LRN-20260717-001] herdr の Claude Code/Codex `integration install` は lifecycle authority にならず、常に screen-manifest 依存のまま

- **type**: knowledge_gap / best_practice
- **発見経緯**: 「親 herdr が子 pane の終了を検知できない」報告を受け、herdr 公式ドキュメント（https://herdr.dev/docs/agents/ ）を WebFetch で直接調査。原文引用: "Claude Code, Codex, GitHub Copilot CLI, Droid, Qoder CLI, and Cursor Agent CLI integrations are intentionally not lifecycle authorities. They provide native session identity for restore, but their hooks do not cover the whole lifecycle."。実機の `~/.claude/hooks/herdr-agent-state.sh`（herdr integration install が生成）を読み、`case "$action" in session) ;; *) exit 0 ;; esac` かつ `settings.json` の hook 登録が `SessionStart` のみであることを確認し、Stop/完了系イベントへの報告が一切ないことを裏取りした。二次情報（ブログ等のWebSearch要約）には「Claude Code integration が completion state を報告する」という逆の記述があったが、公式ドキュメントの原文引用と実機のスクリプト実体の両方で反証済み。二次情報より一次情報（公式docs + 実機ファイル）を優先すべき好例。
- **対処**: devkit プラグインの Stop hook `plugins/devkit/hooks/notify-complete.sh`（Claude Code/Codex 共通で実行される）に、`HERDR_ENV=1` かつ `HERDR_PANE_ID` がある場合のみ `herdr pane report-agent` で能動的に完了報告するロジックを追加（v14.11.0）。screen-manifest の受動的推測を待たず親が即座に検知できるようになった。
- **恒久化先**: `plugins/devkit/skills/operating-herdr/INSTRUCTIONS.md`（Step 0 新設・herdr integration 節訂正・「検知遅延への対処」節新設）・`plugins/devkit/hooks/notify-complete.sh`・`README.md` に反映済み（コミット 6cc3526）。
- **Recurrence-Count**: 1（新規）

## [LRN-20260717-002] dotfiles管理下のファイルは外部ツール(herdr integration install等)によってsymlinkから実体ファイルへ静かに置き換わることがある

- **type**: knowledge_gap
- **発見経緯**: `~/.claude/settings.json` と `~/.claude/hooks/` を編集しようとして `readlink` で確認したところ、symlink ではなく実体ファイル/実ディレクトリになっていた。dotfiles 側の `settings.json` は `hooks: {}` で内容も 20 項目以上古く（enabledPlugins・theme・editorMode・defaultMode 等）、実体ファイルとの乖離が大きかった。他の項目（CLAUDE.md・rules・statusline.*）は正しく symlink のまま維持されていた。原因は特定できていないが、`herdr integration install` や Claude Code 自体の設定書き込み（atomic write でsymlinkを実ファイルに置換するツールがある）が疑われる。
- **対処**: 実体ファイルの内容を dotfiles 側へコピーしてから symlink を復元（バックアップを取った上で実施）。`~/.claude/hooks/` は herdr が直接管理・上書きするファイル(`herdr-agent-state.sh`)を含むため、symlink 化せずそのまま残す方針とし、`symlink.sh` にコメントで理由を明記した。
- **予防策**: dotfiles 配下のファイルを編集する前は必ず `readlink` で symlink であることを確認する習慣が必要（実体化に気づかず dotfiles 側だけ編集すると、変更が反映されないまま気づかない）。
- **恒久化先**: `~/dotfiles/claude-code/settings.json`・`~/dotfiles/claude-code/symlink.sh`（コミット e4f790b）。`RTK.md`「環境の罠と回避策」表への追記は未実施（ユーザー確認事項として完了報告で提案）。
- **Recurrence-Count**: 1（新規）

## [LRN-20260719-001] 日本語スキャン本の画像OCRはtesseractでは実用不可・VLM-OCR(Claude自身の画像読解)が必須

- **type**: best_practice
- **発見経緯**: SEOスキル改善タスクで、画像スキャン形式EPUB（1800x2700px程度のページ画像、縦書き＋複雑レイアウト）3冊をテキスト化する際、まず `tesseract --lang jpn --psm 6` を試したところ、出力は完全な文字化けレベル（「\エ @ @ @ 害 わG は で ま」等）で一切実用にならなかった。解像度自体は十分（1800x2700）だが、日本語の複雑な段組み・図表混在レイアウトにtesseractの層分割が対応できていないと判断。方針転換し、Claude自身がReadツールで各ページ画像を直接読んで内容を理解する方式（VLM-OCR）に切り替えたところ、7体の並列エージェントが計212ページを問題なく読み取り、既存スキルとのギャップ分析に使える精度の要約を得られた。
- **対処**: EPUBが画像スキャン形式（xhtmlが`<img>`参照のみでpandoc変換結果がほぼ空）と判明した時点で、まずtesseractで1ページ試してから判断する（今回のように読めない場合は即座にVLM-OCR方式へ切り替える）。ページ数が多い場合はAgent並列（1体あたり40〜60ページ程度）で分担する。
- **恒久化先**: 未実施（`certificate:converting-content` スキルのOCRワークフローに「まずtesseractで1ページ試し、文字化けする場合はVLM-OCRへ切り替える」という判断基準を追記する余地があるが、本セッションでは未対応）。
- **Recurrence-Count**: 1（新規）
