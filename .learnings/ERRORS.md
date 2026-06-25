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
