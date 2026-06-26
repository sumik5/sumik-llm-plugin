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
