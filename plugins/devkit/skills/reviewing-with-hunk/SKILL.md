---
name: reviewing-with-hunk
description: >-
  Drives live Hunk diff-review sessions via the `hunk session *` CLI (Hunk is an interactive terminal diff viewer controlled through a local daemon). Inspect review focus and file/hunk structure, navigate to files/hunks/lines, reload session contents (diff/show), and add inline review comments (single `comment add` or batched `comment apply`). Use when the user has a Hunk session running — or wants to review a diff/changeset interactively — and asks you to walk them through changes, steer their view, or leave review notes. The Hunk TUI itself belongs to the user: never run interactive `hunk diff`/`hunk show` directly; only `hunk session` subcommands through the daemon. For code-review methodology (PR structure, comment tone, CodeRabbit), use reviewing-code instead. For GitLab MR operations via the glab CLI, use operating-gitlab instead. For GitHub PR descriptions, use the pull-request command instead.
compatibility: >-
  Requires the `hunk` CLI in PATH and a live Hunk session (the interactive TUI launched by the user, backed by a local daemon).
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
