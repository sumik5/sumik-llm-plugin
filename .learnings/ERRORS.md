# ERRORS — sumik-claude-plugin

作業中に調査・解決した非自明なエラーの記録（capturing-learnings 形式）。

> 2026-07-13: 蓄積エントリ（ERR-20260625-001 〜 ERR-20260711-001）を全消費・削除済み。
> 恒久化先: authoring-plugins（HOOK-GUIDE.md / MANAGING-MULTI-PLUGIN.md / CONVERTING.md / INSTRUCTIONS.md）・
> repo CLAUDE.md（git 罠表・Codex 配布表）・RTK.md・Claude Code memory
> （workflow-journal-identity / background-task-dies-across-session / no-unsolicited-claude-md-edits）。
> hook 実装系（notify-complete / learnings-error-detector / rtk-rewrite / hooks-codex.json）は修正適用済みを実ファイルで確認。

---

## [ERR-20260713-001] operating-herdr

**記録日時**: 2026-07-13T11:30:24+09:00
**優先度**: medium
**ステータス**: resolved
**領域**: docs

### 要約

`herdr agent start` の新規pane IDを `result.pane.pane_id` と誤認し、検証paneの自動終了に失敗した。

### エラー

```text
KeyError: 'pane'
pane_not_found: pane  not found
```

### 状況

herdr 0.7.3、`HERDR_ENV=1` で `herdr agent start herdr-doc-probe ...` のJSON応答を解析した。`pane split` と同じ階層を仮定したが、実際の応答は `result.agent.pane_id` だった。

### 推奨修正

`agent start` は `result.agent.pane_id`、`pane split` は `result.pane.pane_id` を読む。失敗後は `herdr agent get <name>` から現在のpane IDを取得し、`herdr pane close <pane_id>` で回収する。`operating-herdr` の応答解析例にも両者の差を明記した。

### メタデータ

- 再現可否: yes
- 関連ファイル: plugins/devkit/skills/operating-herdr/INSTRUCTIONS.md

---

## [ERR-20260713-002] operating-herdr

**記録日時**: 2026-07-13T14:31:00+09:00
**優先度**: medium
**ステータス**: resolved
**領域**: workflow

### 要約

作業中の Codex ペインへ `herdr agent send` と Enter を続けて送ったところ、通常のプロンプト送信ではなく Codex の「Create a plan?」確認UIで停止し、agent status が `done` になったまま計画ファイルが生成されなかった。

### 症状

```text
Create a plan?  shift + tab use Plan mode   esc dismiss
```

### 状況

長時間動作中の Codex を Escape で中断した直後、計画作成を指示するテキストを `herdr agent send` で送り、`herdr pane send-keys ... Enter` を実行した。Codex の対話UIが計画モード確認を表示し、入力が通常ターンとして確定しなかった。

### 推奨修正

長時間ターンを打ち切って別指示へ切り替える場合は、Escape 後に `herdr agent read` で現在のUI状態を確認する。確認ダイアログが表示された場合はそのUIを明示的に解決してからプロンプトを送る。新しい独立タスクなら、既存ペインへ多段送信するより Codex の新規ペインを起動する。成果物が作成されたかは agent status だけで判断せず、対象ファイルの存在と終端マーカーを検証する。

### メタデータ

- 再現可否: yes
- 関連ファイル: plugins/devkit/skills/operating-herdr/INSTRUCTIONS.md
