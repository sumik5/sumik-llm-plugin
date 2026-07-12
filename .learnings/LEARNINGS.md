# LEARNINGS — sumik-claude-plugin

作業中に得た非自明な学び・調査結果の記録（capturing-learnings 形式）。

> 2026-07-13: 蓄積エントリ（LRN-20260625-001 〜 LRN-20260703-002）を全消費・削除済み。
> 恒久化先: authoring-plugins（HOOK-GUIDE.md / MANAGING-MULTI-PLUGIN.md / CONVERTING.md / INSTRUCTIONS.md）・
> repo CLAUDE.md（git 罠表・Codex 配布表）・RTK.md・Claude Code memory。

---

## [LRN-20260713-001] dotfiles の RTK.md は ~/.claude/RTK.md への symlink（通常と逆向き）で Edit ツールが拒否する

**種別**: knowledge_gap（実作業で判明）

**症状**: `/Users/sumik/dotfiles/claude-code/RTK.md` を Edit ツールで編集しようとすると
`Refusing to write through symlink` で拒否される。

**真相**: dotfiles の多くは「dotfiles が実体・`~/.claude` が symlink」だが、RTK.md は**逆向き**
（実体 = `~/.claude/RTK.md`・dotfiles 側が symlink）。Edit/Write ツールは symlink 越しの書込を
拒否するため、`readlink -f` で実体パスを解決してから編集する。

**対処**: `readlink -f /Users/sumik/dotfiles/claude-code/RTK.md` → `/Users/sumik/.claude/RTK.md` を編集。
なお実体が `~/.claude` 側にあるため、**dotfiles の on-change 自動 commit は RTK.md の内容変更を追跡しない**
（symlink 自体のみ追跡）。内容の永続化・同期は別途確認が必要。

### メタデータ
- 再現可否: yes
- 関連ファイル: /Users/sumik/dotfiles/claude-code/RTK.md, /Users/sumik/.claude/RTK.md
- Pattern-Key: dotfiles-symlink-direction
- Recurrence-Count: 1 / First-Seen: 2026-07-13 / Last-Seen: 2026-07-13
