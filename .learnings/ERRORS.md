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

## [ERR-20260721-001] bash-triple-backtick-in-echo

**記録日時**: 2026-07-21T00:00:00+09:00
**優先度**: low
**ステータス**: resolved
**領域**: Bashツール実行（zsh環境）

### 要約
`echo "=== ```python コードブロック数 ... ==="` のように、ダブルクォート文字列内に Markdown コードフェンス（3連続バッククォート）を含めて出力しようとしたところ、シェルがバッククォートをコマンド置換として解釈し、直後の `python` を独立コマンドとして実行しようとして `can't open file '.../コードブロック数'` エラーになった。ダブルクォートはバッククォートのコマンド置換を無効化しない（シングルクォートのみが無効化する）という基本挙動を踏まえていなかった。

### 影響
- 後続の `grep` コマンド自体は独立して正常実行され、必要な集計結果（コードブロック開始/終了タグ数の一致確認）は得られた。実害はなし、単に1つの `echo` 見出し行が失敗しノイズになった。

### 対処
- Markdown のコードフェンス文字列をログ見出しに含めたい場合は、シングルクォートで囲む（`echo '=== ```python ... ==='`）か、バッククォートをエスケープする（`` \`\`\` ``）、または見出し文言自体に3連続バッククォートを含めない。
- 今後、grep/wc 等の集計結果をラベル付きで出す際は、ラベル文字列にバッククォートを含めず「python code blocks」等のプレーンな表現にする方が安全（多言語混在ラベルでも罠を踏みにくい）。

## [ERR-20260719-001] collecting-whizlabs-exams

**記録日時**: 2026-07-19T14:35:00+09:00
**優先度**: low
**ステータス**: pending
**領域**: scripts/collect-whizlabs.sh(正解抽出)

### 要約
CCSP コース全205問収集で204問は正常、1問（Practice Test 1 第118問, choice_type=single）のみ `correct` が空配列になった。原因は "Correct Answer: X" の HTML 表記ゆれ。通常は `<strong>Correct Answer: X</strong>`（単一 strong タグ内）だが、この1問だけ `<strong>Correct</strong>&nbsp;<strong>Answer: A</strong>`（"Correct" と "Answer: A" が別々の strong タグに分割され間に `&nbsp;` が挟まる）という構造だった。スクリプトの正解抽出正規表現は単一 strong タグ内完結パターンを前提にしており、分割パターンにマッチしなかった。

### 影響
- `explanation_html` 自体には情報が無傷で残っている（Anki化時も解説文からは読める）ため実害は軽微。`correct` フィールドのみ空。
- 205問中1問(0.5%)のみで発生、頻度は低い。

### 対処
- 今回は手動で正解=A と確認済み（該当JSONは未修正のまま運用側で許容）。
- スキル側の恒久対応（正規表現を "Correct" と "Answer: X" が別タグに分かれるケースにも対応させる）は certificate:collecting-whizlabs-exams の改善提案として別途起票要（本エントリはその根拠ログとして保持）。

## [ERR-20260716-001] collecting-kentei-lab-exams

**記録日時**: 2026-07-16T20:10:00+09:00
**優先度**: medium
**ステータス**: pending
**領域**: tests

### 要約
日本語テキストの重複検出で `sort | uniq -c`（デフォルトロケール）を使うと、バイト非一致の別問題文を「338件同一」と誤集計する偽陽性が発生した。

### エラー
```
$ jq -r '.questions[].question' hogoshi.json | sort | uniq -c | sort -rn | head -1
    338 「個人識別符号」に該当しないものはどれか。
```
しかし `grep -F -x`・`jq 'select(.question=="...")'`・Python の `==` 比較ではいずれも一致件数は1件のみ（`number=22`）。

### 状況
kentei-lab.com から収集した `hogoshi.json`（個人情報保護士・全453問）の品質検証で、収集スクリプトが同一問題を大量に取りこぼして重複保存したのではと疑い、`sort | uniq -c` で重複問題文を数えたところ338件という異常値が出た。バイト厳密比較（`grep -F -x`, Python `==`）で再検証したところ1件しかヒットせず、値が矛盾した。`LC_ALL=C` を明示して同じ `sort | uniq -c` を再実行すると、最大重複数は3件（重複種類18件・余剰27件）という妥当な値になった。環境は macOS・`LANG=en_US.UTF-8`・`LC_ALL`/`LC_COLLATE` 未設定（`LANG` にフォールバック）。

### 推奨修正
日本語（または非ASCII全般）テキストの重複検出・完全一致比較に `sort`/`uniq` を使う際は、必ず `LC_ALL=C` を前置してバイト厳密比較を強制する（`LC_ALL=C sort file | LC_ALL=C uniq -c`）。en_US.UTF-8 等のロケール下では ICU ベースの照合順序により、異なる記号・カナ表記・句読点バリアントを持つ別文字列が「同一」と畳み込まれることがある（本件の具体的な畳み込み原因文字は特定していないが、現象は再現性あり）。より確実なのは `jq`/Python の文字列 `==`（常にコードポイント厳密一致）で重複判定し、`sort | uniq` は最終手段にとどめること。なお本件の実データは正常（kentei-lab側の出題プールが total_questions より小さく一部問題が複数nに再利用される仕様と推測。Anki投入時の `duplicateScope="deck"` による重複スキップで実害なし）。

### メタデータ
- 再現可否: yes（`LC_ALL` 未指定時は毎回再現）
- 関連ファイル: なし（bash組み込み `sort`/`uniq` の挙動・特定スキルファイルへの罠ではない）
- 関連(See Also): なし
- Pattern-Key: locale-aware-sort-uniq-false-duplicate
- Recurrence-Count: 1 / First-Seen: 2026-07-16 / Last-Seen: 2026-07-16

## [ERR-20260719-001] operating-herdr

**記録日時**: 2026-07-19T00:00:00+09:00
**優先度**: medium
**ステータス**: resolved
**領域**: docs

### 要約
herdr で `claude` を spawn するコマンド例が `--permission-mode acceptEdits` になり「auto mode on」表示にならなかった。原因はリポジトリ内 `operating-herdr`/`orchestrating-teams` スキルが既に `--permission-mode auto` へ統一済み（2026-07-16 コミット 3165760）だったのに対し、リポジトリ外のグローバル個人設定 `~/dotfiles/claude-code/rules/tachikoma-system.md`（`~/.claude/rules/tachikoma-system.md` はこのディレクトリ全体への symlink）40行目だけが旧来の「`acceptEdits` を明示する」という指示のまま取り残されていたこと。

### エラー
```
herdr agent start whizlabs-impl ... -- claude --agent devkit:tachikoma-lang-bash --permission-mode acceptEdits --name whizlabs-impl
```
`agent_started` は返るが、Claude Code 側のステータス表示は「auto mode on」にならない。

### 状況
同一のベストプラクティス（herdr 起動時の permission-mode 明示）が「プロジェクトスキル（operating-herdr/INSTRUCTIONS.md）」と「グローバル dotfiles rules（tachikoma-system.md）」の2箇所に重複記述されており、片方（スキル側）だけを `acceptEdits`→`auto` に更新した際にもう片方（dotfiles rules側）の更新が漏れていた。本体はこのセッションで dotfiles rules の古い指示に従ってコマンドを組み立てたため、スキル自体は正しいのに実際の挙動は古いままという食い違いが起きた。

### 推奨修正
dotfiles rules 側 40行目を `--permission-mode auto` 推奨に修正し、`auto`（内蔵classifierが安全操作のみ自動承認・危険操作は引き続きブロック）と `acceptEdits`（Edit/Write系のみ自動承認）/`bypassPermissions`（全許可）の違いを明記して operating-herdr スキルの記述と整合させた。**同一内容がプロジェクトスキルとグローバル dotfiles rules の2箇所に重複記述されている場合、片方を修正したら必ずもう片方も grep で確認する**（`grep -rn "acceptEdits\|permission-mode" ~/dotfiles/claude-code/rules/*.md` で今回発見）。

### メタデータ
- 再現可否: yes（dotfiles rules 側が未修正の間は毎回再現）
- 関連ファイル: `~/dotfiles/claude-code/rules/tachikoma-system.md`（40行目）, `plugins/devkit/skills/operating-herdr/INSTRUCTIONS.md`（228-241行目・修正不要、正）
- 関連(See Also): なし
- Pattern-Key: dual-source-doc-drift-skill-vs-dotfiles-rules
- Recurrence-Count: 1 / First-Seen: 2026-07-19 / Last-Seen: 2026-07-19

## [ERR-20260719-002] devkit version期待値のCLAUDE.md記載漏れ

**記録日時**: 2026-07-19T00:00:00+09:00
**優先度**: low
**ステータス**: open（今回のタスクスコープ外のため未修正・報告のみ）
**領域**: version管理

### 要約
studio スキル改善タスクの完了検証として CLAUDE.md 記載の同期チェックPythonスニペットを実行したところ、devkit が `MISMATCH` になった。実ファイル3点（`plugins/devkit/.claude-plugin/plugin.json` 等）は `14.11.1` で一致しているが、CLAUDE.md 側の期待値表記（194行目・233行目・305行目の `expected` 辞書）が `14.10.0` のまま更新されていなかった。

### エラー
```
devkit   MISMATCH ['14.11.1', '14.11.1', '14.11.1']  (expected 14.10.0)
studio   OK  ['2.1.0', '2.1.0', '2.1.0']  (expected 2.1.0)
```

### 状況
`git log -1 -- plugins/devkit/.claude-plugin/plugin.json` で確認すると、直近コミット `63f6653 fix(devkit): agentのmodel/permissionModeを実運用に合わせて調整` で devkit の version が bump されていた（別セッションの作業）。その際、CLAUDE.md の「バージョンファイルの同期」節にある期待値表記3箇所の更新が漏れていた。実ファイル自体は3ファイルとも一致しており矛盾はないため、実害はない（CLAUDE.md の期待値記載が古いドキュメントとして残っただけ）。

### 推奨修正
CLAUDE.md 194/233/305行目の `devkit 14.10.0` → `devkit 14.11.1` へ修正する。version bump作業では、変更対象プラグインの3ファイル同期だけでなく、CLAUDE.md 内の同期チェックスニペットの `expected` 辞書・地の文表記も同時に更新する運用を徹底する。

### メタデータ
- 再現可否: yes（CLAUDE.md 側を修正するまで毎回 MISMATCH で再現）
- 関連ファイル: `CLAUDE.md`（194/233/305行目）, `plugins/devkit/.claude-plugin/plugin.json`
- 関連(See Also): なし
- Pattern-Key: version-bump-forgets-claude-md-expected-value
- Recurrence-Count: 1 / First-Seen: 2026-07-19 / Last-Seen: 2026-07-19
