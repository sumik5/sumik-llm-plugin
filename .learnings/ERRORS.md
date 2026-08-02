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
>
> 2026-07-24: 蓄積エントリ（ERR-20260723-004・ERR-20260723-005・ERR-20260723-006・ERR-20260723-007・
> ERR-20260724-007）を全消費・削除済み。恒久化先: `creating-flashcards` スキル本体（旧
> `collecting-studying-exams` から統合移動済み）。ERR-004（nosubcat見出し混入によるCDPエラー）・
> ERR-005（フィルタ後配列基準の境界計算バグ）・ERR-007（TOGGLE_SELECTORのaタグ誤マッチ）は
> `scripts/collect-studying.sh` に修正が既に反映済みであることを実grepで確認（`toggle.tagName === 'A'`・
> `EXCLUDE_HEADING_SUBSTR`・`allHeadings`基準の境界計算、いずれも実在）。ERR-006（AnkiConnect大量連続
> リクエストでのConnection refused/reset）は `references/SCRIPTS-CONTRACT.md` の「大量投入時の
> リクエスト間隔」節へ新規恒久化。ERR-20260724-007（herdr agent paneの未送信入力欄プリフィルの誤送信
> リスク）はLRN-20260719-003（同型の初回発生）と統合し `operating-herdr/INSTRUCTIONS.md` の
> 「Escape で中断した直後の多段送信は要注意」ブロック直後へ新規恒久化。

> 2026-07-31: 蓄積エントリ（ERR-20260730-001）を全消費・削除済み。ネストbackground孤児化パターンは
> Claude Code memory `background-task-dies-across-session` へ派生パターン（サブエージェント自身が
> ネストした`run_in_background`を開始した場合も同型の孤児化が起きる）として追記・実ファイルで反映確認済み
> （`MEMORY.md`索引も同時更新）。同一書籍のOCRパイプライン自体は本セッション内で座標マッチング方式へ
> 発展させ最終的に1988件全件を解決済み（LRN-20260730-001として記録・同時消費）。

> 2026-07-29: 蓄積エントリ（ERR-20260725-001・ERR-20260727-001）を全消費・削除済み。
> ERR-20260725-001（agent-browser open直後のAJAX生成DOM未挿入・レッスン0件誤判定）は
> `plugins/web/skills/automating-browser/references/AGENT-EXAMPLES.md` の実践Tipsリスト末尾（11番目）へ
> 「動的挿入要素はeval内でポーリング」として新規恒久化。ERR-20260727-001（disable-model-invocation:true
> スキルは別agentへの引き継ぎ時にSkillツール経由でロードできない）は
> `plugins/devkit/skills/authoring-plugins/references/FORK-GUIDE.md` の「7.1 disable-model-invocationとの
> 関係」節208行目直後へ新規恒久化。両ファイルとも`git diff`で追加行のみ・禁止語なし・
> `.learnings`参照残存なしを実機検証済み。web 1.4.0→1.4.1・devkit 14.12.4→14.12.5（いずれもPATCH）。

> 2026-08-02: 蓄積エントリ（ERR-20260802-001）を消費・削除済み。
> 恒久化先: `plugins/devkit/commands/refactor-agent-instructions.md`の「## 注意点」表末尾へ
> 「カテゴリDで新規に外部ファイルを作成する前」行として新規恒久化（`git check-ignore -v`での
> 事前確認・`docs/**`等の広いignoreパターンへの注意）。`git diff`で追加2行のみ・対象ファイル
> 以外への差分なし・禁止語なし・`.learnings`参照残存なしを実機検証済み。
