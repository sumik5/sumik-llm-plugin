# ERRORS — sumik-claude-plugin

作業中に調査・解決した非自明なエラーの記録（capturing-learnings 形式）。

---

## [ERR-20260625-001] git commit / tag が GPG 署名失敗で不発（非tty・Bashツール）

**症状**: Claude Code の Bash ツールから `git commit` / `git tag -a` を実行すると
`gpg: signing failed: No such file or directory` ＋ `PINENTRY_LAUNCHED ... not a tty` で
fatal になり、commit object / tag が書き込まれない。`git tag` 実行直後の `echo rc=$?` が
コマンド連結の都合で `0` を返すため一見成功に見えるが、`git tag --points-at HEAD` で
実体確認するとタグは作成されていない（HEAD も旧コミットのまま）。

**原因**: このリポジトリは `commit.gpgsign=true`（コミット/タグ署名が有効）。Claude Code の
Bash 実行は非tty で pinentry を起動できず GPG 署名に失敗する。`dangerouslyDisableSandbox: true`
でも解消しない（サンドボックスの問題ではなく tty/pinentry の問題）。

**対処**:
- ユーザー自身の tty（ターミナル / `! ` でも pinentry が効けば可）で署名付き
  `git commit -F <msgファイル>` / `git tag -a vX.Y.Z -m "..."` を実行する。
- 署名不要なら `git commit --no-gpg-sign` / lightweight `git tag`（署名なし）で回避し、
  必要時に `git commit --amend -S` 等で後から署名する。
- 検証は exit code を信じず `git log -1 --format='%H %s'` / `git tag --points-at HEAD` /
  `git status --porcelain` で実体を見る。
- commit 失敗後もステージ（index）は保持される。明示パススペックで staged したものは再 add 不要。

**昇格候補**: CLAUDE.md「git コミット/タグ/push 時の注意（環境依存の罠）」表。
反復（Recurrence ≥ 3・2タスク以上・30日内）が確認できれば CLAUDE.md / memory へ予防ルールとして昇格する。

---

## [ERR-20260626-001] PostToolUse:Bash hook が hookSpecificOutput.hookEventName 欠落でJSON検証失敗

**症状**: `Hook JSON output validation failed — hookSpecificOutput is missing required field "hookEventName"`
が散発的に出る。`plugins/devkit/hooks/learnings-error-detector.sh`（PostToolUse × Bash matcher）が
出力する JSON の `hookSpecificOutput` に `hookEventName` が無いため。Bash 出力にエラーパターン
（`error:` 等）が混じった時だけ JSON を吐く設計なので、正常系（エラー未検出は `exit 0` で無出力）
では沈黙し、再現性が低く見えるのが厄介。

**原因**: Claude Code の hook JSON 契約では、`hookSpecificOutput` を返す場合その中の
`hookEventName`（イベント名の discriminator）が**必須**。欠けると `additionalContext` が
読まれる前にスキーマ検証で JSON 全体が弾かれる。公式仕様（code.claude.com/docs/en/hooks）で
PostToolUse は `"hookEventName": "PostToolUse"` 必須＋ `additionalContext` 対応を確認済み。

**対処**: `hookSpecificOutput` 直下に `"hookEventName": "PostToolUse",` を1行追加。
一般化: hook が `hookSpecificOutput` を返すなら、当該イベント名を必ず `hookEventName` に入れる
（SessionStart / PreToolUse / PostToolUse / UserPromptSubmit 等）。`plain stdout` 出力型
（learnings-reminder.sh 等）は対象外。同リポジトリの正しい先例: `detect-project-skills.sh`
（"SessionStart"）・`rtk-rewrite.sh`（"PreToolUse"）。

**反映上の注意**: 編集はソースリポジトリのみ。稼働中の hook は `~/.claude/plugins/cache/...`
（git スナップショットの読取専用コピー）なので、push + プラグイン再インストールまで反映されない。

**昇格候補**: hook 新規作成・改修時の予防ルール。「`hookSpecificOutput` を出すなら `hookEventName` 必須」。
authoring-plugins スキルの Hook ガイド（hook JSON 出力スキーマ）への追記候補 → CLAUDE.md inbox の
[PROPOSAL] として捕捉する。

---

## [ERR-20260626-002] learnings-error-detector が成功した読み取り系コマンド出力をエラー誤検知

**記録日時**: 2026-06-26T18:00:00+09:00
**優先度**: high
**ステータス**: resolved
**領域**: config

### 要約
`PostToolUse:Bash` の `learnings-error-detector.sh` が、成功した `sed` / `git diff` などの出力本文に含まれる `Error:` / `failed` / `exit code` などへ反応し、多量の `.learnings/ERRORS.md` リマインダーを出していた。

### エラー
```
PostToolUse hook (completed)
hook context: エラーが検出されました。想定外・非自明・再発しうる・将来セッションに有益なエラーであれば .learnings/ERRORS.md に [ERR-20260626-XXX] 形式で記録してください（capturing-learnings スキル参照）。
```

### 状況
`plugins/devkit/hooks/learnings-error-detector.sh` は `.tool_response` 全文を固定文字列でスキャンしていた。Codex の hook payload では Bash の exit code が明示フィールドとして取れないケースがあり、成功したファイル閲覧・diff 出力中の hook 仕様例やコードコメントに反応した。

### 推奨修正
明示的な `exit_code` / `exitCode` / `Process exited with code N` が取れる場合はそれを優先し、成功時は本文スキャンしない。exit code が取れない場合も、`sed` / `cat` / `rg` / `grep` / `git diff` / `rtk git diff` / `git status` などの読み取り系コマンドは本文スキャン対象外にする。残すフォールバックパターンは `Traceback (most recent call last):` や `Process exited with code [1-9]` など、実行失敗に近いシグナルへ絞る。

### メタデータ
- 再現可否: yes
- 関連ファイル: plugins/devkit/hooks/learnings-error-detector.sh
- 関連(See Also): ERR-20260626-001

---

## [ERR-20260626-003] rtk find が find の複合predicateと -exec をサポートせず失敗

**記録日時**: 2026-06-26T17:34:07+09:00
**優先度**: medium
**ステータス**: resolved
**領域**: config

### 要約
Codex のBash実行で `find . -maxdepth 2 -type f \( -name 'plugin.json' -o -name 'marketplace.json' \) -print -exec ...` を実行したところ、rtk rewrite後の `rtk find` が複合predicateと `-exec` を扱えず失敗した。

### エラー
```
rtk: rtk find does not support compound predicates or actions (e.g. -not, -exec). Use `find` directly.
```

### 状況
devkit の `rtk-rewrite.sh` hook がBashコマンドをrtk系に書き換える環境で、標準 `find` 前提の複合条件・action付きコマンドを実行した。単純なファイル探索ならrtkで問題ないが、`-o`、括弧、`-exec`、`-not` を含むコマンドでは互換性が足りない。

### 推奨修正
複合predicateやactionが必要な場合は `/usr/bin/find` を明示してrtk rewriteを回避する。出力後の処理は `xargs` や別コマンドに分け、検証ログを読みやすく保つ。

### メタデータ
- 再現可否: yes
- 関連ファイル: plugins/devkit/hooks/rtk-rewrite.sh
- 関連(See Also): ERR-20260626-002

---

## [ERR-20260626-004] devkit の `.cache` symlink が repo root を指し Serena が File name too long で起動失敗

**記録日時**: 2026-06-26T18:10:00+09:00
**優先度**: medium
**ステータス**: resolved
**領域**: config

### 要約
`mcp__serena.activate_project("/Users/sumik/repo/shivase/sumik-claude-plugin")` が、`.cache/sumik-marketplace/devkit -> ../..` による自己再帰パスを追って `File name too long` で失敗した。

### エラー
```
OSError: [Errno 63] File name too long: '/Users/sumik/repo/shivase/sumik-claude-plugin/.cache/sumik-marketplace/devkit/.cache/sumik-marketplace/devkit/...'
```

### 状況
Codex 用 devkit plugin は repo root の `.codex-plugin/plugin.json` を使う構造のため、`.cache/sumik-marketplace/devkit` が repo root を指している。symlink を追うツールでは `.cache/sumik-marketplace/devkit/.cache/sumik-marketplace/devkit/...` と無限に潜れる。`find` の既定動作では symlink を追わないため見落としやすい。

### 推奨修正
devkit の Codex 配布構造を見直し、可能なら他プラグイン同様 `.cache/sumik-marketplace/devkit -> ../../plugins/devkit` に寄せる。その場合は `plugins/devkit/.codex-plugin/plugin.json` と `hooks-codex.json` の配置も合わせて調整する。構造変更が重い場合は、Serena 等の symlink 追跡ツールに `.cache/` 除外を設定する。

### メタデータ
- 再現可否: yes
- 関連ファイル: .cache/sumik-marketplace/devkit, .codex-plugin/plugin.json, .agents/plugins/marketplace.json
- 関連(See Also): ERR-20260626-002

---

## [ERR-20260626-005] Stop hook が plain stdout を返して invalid stop hook JSON output になる

**記録日時**: 2026-06-26T18:25:00+09:00
**優先度**: high
**ステータス**: pending
**領域**: config

### 要約
`Stop` hook に登録された `notify-complete.sh` が通知処理後に `echo "通知完了: ${PROJECT_NAME}"` を stdout に出しており、Codex がその stdout を Stop hook JSON として解釈して `invalid stop hook JSON output` になった。

### エラー
```
Stop hook (failed)
error: hook returned invalid stop hook JSON output
```

### 状況
`hooks-codex.json` と `plugins/devkit/.claude-plugin/plugin.json` の `Stop` は `plugins/devkit/hooks/notify-complete.sh` を実行する。`SessionStart` / `UserPromptSubmit` と違い、`Stop` の stdout は自由テキストではなく JSON 契約で解釈される。通知だけが目的の hook は stdout を出さず `exit 0` で終える必要がある。

### 推奨修正
`notify-complete.sh` の最後の `echo "通知完了: ${PROJECT_NAME}"` を削除するか stderr に逃がす。最も安全なのは stdout を完全に無出力にすること。将来の通知系 Stop / SubagentStop / Notification / TeammateIdle hook では、ログを出す場合も `>&2` またはファイルログに限定する。

### メタデータ
- 再現可否: yes
- 関連ファイル: plugins/devkit/hooks/notify-complete.sh, hooks-codex.json, plugins/devkit/.claude-plugin/plugin.json
- 関連(See Also): ERR-20260626-001

---

## [ERR-20260626-006] rtk-rewrite が `updatedInput` を `permissionDecision: allow` なしで返して PreToolUse 検証失敗

**記録日時**: 2026-06-26T18:35:00+09:00
**優先度**: high
**ステータス**: resolved
**領域**: config

### 要約
`plugins/devkit/hooks/rtk-rewrite.sh` の `rtk rewrite` exit code 3（ask rule）分岐が、`updatedInput` を返しつつ `permissionDecision` を省略していたため、Codex の PreToolUse hook validator に拒否された。

### エラー
```
PreToolUse hook (failed)
error: PreToolUse hook returned updatedInput without permissionDecision:allow
```

### 状況
旧実装は「書き換え後のコマンドを提示し、permissionDecision を省略して通常のユーザー確認に流す」意図だった。しかし Codex hook runtime では `updatedInput` を返す JSON は `permissionDecision: "allow"` を伴わないと invalid 扱いになる。`permissionDecision: "ask"` と `updatedInput` の組み合わせは Claude Code 公式 docs では説明されているが、この環境の Codex validator では少なくとも省略形は受理されない。

### 推奨修正
`updatedInput` を返す分岐では必ず `permissionDecision: "allow"` を付ける。ask rule に該当した場合は安全側として JSON を返さず `exit 0` し、元コマンドを通常の permission flow に通す。これにより hook 検証失敗を避けつつ、ask 対象コマンドの自動承認も避けられる。

### メタデータ
- 再現可否: yes
- 関連ファイル: plugins/devkit/hooks/rtk-rewrite.sh
- 関連(See Also): ERR-20260626-005

---

## [ERR-20260627-001] Codex plugin hook の相対パスが cwd 依存で code 127 になる

**記録日時**: 2026-06-27T09:40:12+09:00
**優先度**: high
**ステータス**: resolved
**領域**: config

### 要約
`hooks-codex.json` の hook command が `bash ./plugins/devkit/hooks/*.sh` 形式の cwd 相対パスになっており、Codex が plugin root 以外の cwd で hook を実行すると `No such file or directory` で `exit 127` になる。

### エラー
```
SessionStart hook (failed)
error: hook exited with code 127

UserPromptSubmit hook (failed)
error: hook exited with code 127
```

### 状況
`hooks-codex.json` は `.codex-plugin/plugin.json` の `"hooks": "./hooks-codex.json"` から配布されるが、各 command は `bash ./plugins/devkit/hooks/detect-project-skills.sh` などの相対パスを使う。repo root で単体実行すると成功する一方、`cwd=/Users/sumik` や `/tmp` で実行すると `bash: ./plugins/devkit/hooks/learnings-reminder.sh: No such file or directory` となり `exit=127` を再現した。hook 本体の権限や JSON/stdout 契約の問題ではなく、起動時 cwd と相対パス解決の問題。

### 推奨修正
Codex plugin hook command は `PLUGIN_ROOT` / `CLAUDE_PLUGIN_ROOT` 環境変数から hook 実体を絶対パスで呼び出す。devkit では `hooks-codex.json` を `"bash \"${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:?}}/plugins/devkit/hooks/<name>.sh\""` 形式に変更し、repo root 以外の cwd から `SessionStart` / `UserPromptSubmit` の sample payload を流して `exit 0` を確認する。

### メタデータ
- 再現可否: yes
- 関連ファイル: hooks-codex.json, .codex-plugin/plugin.json, plugins/devkit/hooks/learnings-reminder.sh
- 関連(See Also): LRN-20260625-001, ERR-20260626-005

---

## [ERR-20260627-002] Codex に存在しない CodeGuard 専用コマンドをタチコマが要求する

**記録日時**: 2026-06-27T10:04:19+09:00
**優先度**: high
**ステータス**: resolved
**領域**: config

### 要約
タチコマ定義と `securing-code` が Codex 環境に存在しない CodeGuard 専用コマンドの実行を必須扱いしており、実装完了報告で「専用コマンド/ツールが見つからない」という不要なエラー説明が出る。

### エラー
```
CodeGuard 専用コマンド/ツールはこの環境では見つかりませんでした。
```

### 状況
Codex の `devkit@sumik-marketplace` には Project CodeGuard 由来のルール集である `software-security` スキルは存在するが、旧プロンプトが想定していた専用コマンドは存在しない。source repo の `plugins/devkit/agents/*.md`、`securing-code`、タチコマ関連テンプレート、`~/dotfiles/codex/agents/*.toml`、および稼働中の `~/.codex` plugin cache に古い呼び出し名が残っていた。

### 推奨修正
CodeGuard を「実行コマンド」ではなく `software-security` スキルに基づくセキュリティ確認として扱う。タチコマの DoD、`securing-code`、`implementing-as-tachikoma`、orchestration 系テンプレート、dotfiles の実行用 agent 定義、稼働中 plugin cache を同じ表現に揃える。専用コマンド名をプロンプト本文へ残さない。

### メタデータ
- 再現可否: yes
- 関連ファイル: plugins/devkit/skills/securing-code/INSTRUCTIONS.md, plugins/devkit/agents/*.md, /Users/sumik/dotfiles/codex/agents/*.toml
- 関連(See Also): ERR-20260627-001, ERR-20260626-003

---

## [ERR-20260628-001] agent-browser の --headed がウィンドウ不可視／headless→headed 切替で "Failed to connect (os error 2)"

### 症状
`agent-browser --headed open <url>` を Claude Code の Bash から実行すると、(1) コマンド自体は成功（exit 0・ページロード・snapshot も取れる）するのに **ブラウザウィンドウが画面に見えない**。さらに (2) 一度 headless で `open` した後に `--headed` で開き直すと `✗ Could not configure browser: Failed to connect: No such file or directory (os error 2)` が出てブラウザが起動しない。

### 原因
- (1) Claude Code の Bash サブプロセスは macOS の GUI(Aqua)セッションに属さないため、Chrome は起動してもウィンドウが画面に描画されない（headless では顕在化しない）。
- (2) agent-browser はデーモンを最初のコマンドで起動し常駐させる。`close` はブラウザを閉じるが **デーモンは残る** ため、headless で起動したデーモンに `--headed` 要求が食い違って接続に失敗する。

### 対処
- デーモンのリセット: `agent-browser close --all` → `agent-browser doctor --fix`（stale なソケットを掃除。`doctor` は CLI/Chrome/デーモン/プロバイダの健全性を一覧）。
- 「見える」操作（CDP 接続）: `open -na "Google Chrome" --args --remote-debugging-port=9222 --user-data-dir=/tmp/abrowser-chrome-debug about:blank` で GUI セッションに前面起動 → `curl --retry ... http://127.0.0.1:9222/json/version` でポート開通を待つ → `agent-browser --cdp 9222 <cmd>` で接続操作。`--auto-connect` でも実行中 Chrome に接続可。
- 検証実績(2026-06-28): 上記で見える Chrome 上の Google 検索（`find role combobox fill "楽天市場"` → `press Enter` → `read` で結果取得）に成功。

### メタデータ
- 再現可否: yes
- 関連ファイル: plugins/web/skills/automating-browser/INSTRUCTIONS.md（「ヘッドフル（可視）操作とデーモン管理」節）, references/AGENT-COMMANDS.md（「接続・デーモン管理・診断」節）
- 昇格候補: web:automating-browser スキルへ追記済み。汎用反復が出れば CLAUDE.md のブラウザ操作ルールへ。

## [ERR-20260702-001] 84体並列 Workflow がセッション使用量上限で途中死亡／journal.jsonl の result に label が無く帰属不能

### 症状
description 一括監査の Workflow（analyze 84 + verify/apply、計122 agents）実行中、45 agents が `You've hit your session limit · resets 2am` で連続死亡。pipeline は生き残った分だけで完走し、25件適用・14件現状合格・13件は「分析完了・適用前」の中間状態で停止した。復旧のため journal.jsonl から未適用13件の提案を回収しようとしたが、`{"type":"result"}` レコードには `key`（プロンプトハッシュ）と `agentId` しかなく **label が記録されない** ため、どの result がどのスキルの提案か直接は判別できなかった。

### 原因
- 大規模並列（各 agent が effort:high で SKILL.md+INSTRUCTIONS を精読）で 5h ローリング上限を消費し尽くした（subagent 7.6M tokens）。
- StructuredOutput の schema から「対象スキル名」フィールドを省いたため、journal の result が自己記述的でなくなった。

### 対処
- 帰属復元: 「改訂版は旧文と n-gram を共有する」性質を使い、`difflib.SequenceMatcher` で各提案と全スキルの旧 description の類似度を取り最良マッチに割当。適用済み分の除外は「PENDING 以外のスキルの現ファイルと 0.90 超一致」で判定（保留スキルは現ファイル＝旧文なので除外基準に含めると自壊する罠あり）。12/13 が高信頼で紐付き、残り1件は全単射（13提案↔13スキル）の消去法で確定。
- 適用は本体が機械的スクリプトで実施し、YAML 検証・字数・参照実在・禁止語・言語維持・本文不変を機械ゲートで全件再検証した。

### 再発防止
- 🔴 Workflow の StructuredOutput schema には**対象アイテムの識別子フィールド（skill/plugin 等）を必ず含める**。journal からの復旧が identity 照合なしで可能になる。
- 大規模並列（50体超×高effort）は上限予算を先に見積もり、フェーズ間にチェックポイント（提案のファイル書き出し等）を挟む。

### メタデータ
- 再現可否: yes（上限到達時）
- 関連ファイル: ~/.claude/projects/<project>/<session>/subagents/workflows/<runId>/journal.jsonl
- 昇格候補: memory（workflow-journal-identity）

## [ERR-20260703-001] Workflow resume は並列 pipeline でキャッシュがほぼ効かず、上限を再び食い潰した

### 症状
ERR-20260702-001 の続き。`resumeFromRunId` で再開すれば完了済み 77 agents はキャッシュ再生され未処理分だけ走る想定だったが、実際には run 1 で成功していた verify+apply エージェント 25 体を含む大量のエージェントが**ライブ再実行**され、4.8M subagent tokens を消費して再びセッション上限（5h ローリング）に到達。2 回目の中断が発生した。

### 原因
resume のキャッシュはドキュメント記載どおり「**agent() 呼び出し列の unchanged prefix**」に対して効く。並列 pipeline は完了順が非決定的なため、run 2 の呼び出し順が run 1 の journal 記録順と早期に食い違い、以降が全てライブ実行になる。実測では analyze の一部（journal 順と一致した prefix 分）だけ再生され、verify は全滅だった。副作用として、改善適用済みファイルへのライブ再分析が needs_change=false を返し「独立再確認」になる怪我の功名もあった。

### 対処
- run 2 で得られた新規 25 提案を journal から回収（旧 description との difflib 類似度＋全単射消去法で帰属）し、本体が機械適用。字数超過 3 件（1093/1107/1054字）は verify 不在のため本体がトリム（重複差別化文の統合・周縁ルーティング行の削除・括弧内圧縮）。
- 残 1 件（analyze 未実行の creating-slides）は本体がインライン監査で完遂。

### 再発防止
- 並列 pipeline の Workflow を「resume すれば安い」と見積もらない。**resume はほぼ全再実行と想定**して上限予算を確保するか、フェーズごとに独立した小 Workflow に分割して各フェーズ完了時に成果をファイルへ確定させる。
- 大規模監査は analyze 結果を中間成果物（JSONファイル）として書き出す設計にし、apply は本体の機械スクリプトで行うと、上限死しても再開コストがゼロに近い。

### メタデータ
- 再現可否: yes
- 関連(See Also): ERR-20260702-001

## [ERR-20260703-002] git tag が "fatal: no tag message?" で失敗する（tag.gpgsign=true 環境）

### 症状
リリース時に `git tag v14.4.1` 等の軽量タグ作成が全件 `fatal: no tag message?` で失敗した（commit・push は成功）。

### 原因
この環境の git config に `tag.gpgsign = true` が設定されており、タグは常に署名付き（annotated）として作成される。annotated タグはメッセージ必須のため、`-m` なしの `git tag <name>` は editor 起動不能な非対話実行下で即失敗する。

### 対処
`git tag -m "<短い要約>" <name>` とメッセージを明示すれば成功（署名も通る）。加えて `cd <repo> && for ...` 複合コマンドはパーミッション拒否されるため、`git -C <repo>` 形式で実行する（CLAUDE.md 既知の罠と同根）。

### メタデータ
- 再現可否: yes
- 関連ファイル: ~/.gitconfig（tag.gpgsign）
- 昇格候補: CLAUDE.md「git コミット/タグ/push 時の注意」表へ `git tag は -m 必須（tag.gpgsign=true）` 行の追記

## [ERR-20260703-003] 書籍→スキル変換の抽出フェーズ: pandoc の偽成功と画像PDFの空抽出

### 症状
6冊（EPUB/PDF）をスキル素材化するためテキスト抽出した際、2つの落とし穴に遭遇した。
1. 巨大 EPUB（33MB）を `pandoc ... -o src.md 2>&1 | head -3 && echo "done"` で変換したら "done" が出たのに出力ファイルが存在しなかった（偽成功）。
2. あるPDF（112ページ・24MB）が `pdftotext -layout` で 0 行、PyMuPDF の `get_text("text")` でも 112ページから 111 文字しか取れなかった。

### 原因
1. `cmd | head && echo done` の `&&` はパイプ**末尾コマンド（head）の終了コード**で分岐する。pandoc 本体が（初回は一時的に）失敗しても head は exit 0 を返すため "done" が印字される。パイプが本体の失敗を握り潰す典型。
2. 当該PDFはテキストレイヤーの無いスキャン画像PDF。各ページを調べると `text_chars=0 / images=1`。24MB÷112p≈220KB/page もスキャン画像と整合。テキスト抽出器を変えても（pdftotext→PyMuPDF）画像には効かない。

### 対処
1. パイプを介さず単体で実行し `rc=$?` を取得、stderr はファイルへ、出力の実在を `ls`/`wc -l` で検証。再実行で pandoc は exit 0・2.45MB・29140行を正常出力（初回失敗は巨大ファイルの一過性と判断）。
2. `fitz.open(pdf)` で先頭数ページの `len(page.get_text().strip())` と `len(page.get_images())` を確認し画像PDFと確定。OCR（tesseract 112ページ）は費用対効果が悪く、他の良質ソースが同ドメインを網羅していたため**当該ソースを除外**する判断。

### 再発防止
- 変換系コマンドの成否は「パイプ末尾の exit」でなく**本体の rc と出力実体（サイズ/行数）**で判定する。`cmd | head && echo done` を成功判定に使わない。
- PDF素材は着手時に「先頭数ページの text_chars と images 数」で**テキストレイヤーの有無を先に判定**。0文字＝画像PDF→OCRの要否を費用対効果で判断（代替ソースがあれば除外）。
- 素材抽出物は書名を含まないジェネリック名（src-01…）で出力し、固有名の混入経路を最初から断つ。抽出物本文には著者名/出版社/ISBN/メール/ページヘッダ/コード行番号が残るため、下流の抽出プロンプトで除去を厳命し、完成物は本体 grep で最終サニタイズする。

### メタデータ
- 再現可否: yes（画像PDF判定・パイプ握り潰しとも一般的に再現）
- 関連: capturing-learnings / authoring-plugins（source→skill 変換）

---

## [ERR-20260710-001] org 月次スペンド上限が Workflow を途中死させ部分編集状態を残す（resume 戦略の続報）

### 症状
86スキル一括改善の Workflow（35 agents）実行中に org 月次スペンド上限へ到達し、intake/fix/verify 18 体が failed。「failed」報告のエージェントの一部は死亡直前までファイル編集を進めており、working tree に部分編集状態（flashcards 分割の途中・INTERNALS 校正の一部ファイルのみ等）が残った。resume でも上限へ再度到達し二段階の中断が発生。

### 原因
1. スペンド上限はエージェント個々の API 呼び出しで発火するため、編集途中のエージェントが「作業痕跡を残して」死ぬ。failed = 未着手ではない。
2. ERR-20260703-001 と同根: resumeFromRunId のキャッシュは並列分岐の呼び出し順序が変わると prefix 一致が崩れ、完了済み監査13体もライブ再実行された（ただし再監査は修正適用済みの現状を見て所見ほぼゼロを返し、結果的に冪等収束）。

### 対処
1. fixer/intake プロンプトに「所見が実ファイルと食い違う場合は実ファイルを正として再判定し no_change_needed とする」再判定権限と冪等性を最初から組み込んでいたため、部分編集状態からの再実行が安全に収束した。
2. 2度目の中断後は巨大 run の resume をやめ、**残タスク（校正3+検証4）だけの新規小型 Workflow** を書き下ろし依存順（校正→DB検証）を明示 chain。無駄な再実行ゼロで7体全完走。

### 再発防止
- 大型 Workflow のエージェントプロンプトには常に冪等性条項（実ファイルが正・二重適用禁止・部分適用済みの可能性を明記）を入れる。中断は上限・ネットワークでいつでも起きる前提で書く。
- 中断復旧は「resume で全再生」より**残タスク特定→新規 remainder workflow** が確実で安価（キャッシュ prefix 崩れの影響を受けない）。
- 部分編集の検出は `git status --porcelain` と「標準イディオム文の出現回数 grep」（二重追記検出）で機械化する。

### メタデータ
- 再現可否: yes（上限到達時に一般に再現）
- 関連(See Also): ERR-20260702-001, ERR-20260703-001

---

## [ERR-20260710-002] background teammate の failed idle_notification は最終状態ではない（リトライ完走がある）

### 症状
書籍→スキル変換で 6 体の Planner（Agent・run_in_background）を並列起動したところ、スペンド上限到達で 6 体全てから `idleReason: failed`（monthly spend limit）の idle_notification を受信。しかし約 2.5 時間後、5 体は docs/ 成果物一式を完成させ完了報告まで送ってきた（ファイル mtime で裏取り済み）。真に死亡していたのは 1 体のみ（成果物 1/5 ファイルで停止）。

### 原因
スペンド上限による failed 通知はその時点の API 呼び出し失敗を示すだけで、teammate プロセス自体は生存しリトライで再開しうる。「failed 通知 = エージェント死亡・未完了」と解釈すると誤って全員を再起動し、二重実行・ファイル競合を招く。

### 対処
1. failed 通知を受けても**即再起動しない**。各エージェントの出力先ディレクトリを `ls -la`（mtime 付き）で確認し、「failed 通知時刻より新しい成果物があるか」で生存/死亡を判定。
2. 真に死んだ 1 体のみ、新 Planner を「中断からの再開」プロンプト（前任成果物の検証+続行）で起動 → 完走。

### 再発防止
- 判定基準: 「failed 通知時刻 < 成果物 mtime」なら生存扱いで完了通知を待つ。全成果物が failed 通知より古く更新が止まって数十分経つなら死亡と判定し、再開型プロンプト（前任の成果物を必読に含め冪等続行）で 1 体だけ差し替える。
- 並列バッチはどのみち中断される前提で、各エージェントにステップ単位のファイル保存（compaction/中断耐性）を義務付ける——今回これが効いて 5 体分の成果が無傷だった。

### メタデータ
- 再現可否: yes（上限到達時に一般に再現）
- 関連(See Also): ERR-20260710-001（Workflow 版・remainder 戦略）, memory: background-task-dies-across-session
