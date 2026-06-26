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
