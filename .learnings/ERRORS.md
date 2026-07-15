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

---

## [ERR-20260715-001] agent-config

**記録日時**: 2026-07-15T00:00:00+09:00
**優先度**: medium
**ステータス**: open（要・LEARNINGS.md側の記載修正）
**領域**: agent-config

### 要約

`.learnings/LEARNINGS.md` の `[LRN-20260714-001]` は「対象24ファイル（`plugins/devkit/agents/*.md` 中 `model: sonnet` 指定の23件 + `plugins/exam/agents/exam-solver.md`）は `model: claude-sonnet-5` に統一済み（2026-07-14）」と記載しているが、2026-07-15 に実ファイルを `grep -n "^model:" plugins/devkit/agents/*.md` で確認したところ、**全25体の sonnet 系エージェントが依然として `model: sonnet`（エイリアス表記）のまま**であり、記載された移行は適用されていなかった。

### 状況

新規Agent `tachikoma-mobile-ios` を追加する作業で、model フィールドの表記規則を確認するために memory/LEARNINGS.md を参照 → 実ファイルと突き合わせたところ矛盾を検出。おそらく移行作業自体は別セッションで検討・記録だけされ、実際の一括置換コミットが行われなかった（またはその後の何らかの変更で巻き戻った）と推測される。

### 推奨修正

- `.learnings/LEARNINGS.md` の `[LRN-20260714-001]` のステータスを `resolved` から `open`（未適用）に訂正するか、実際に24ファイルへ `model: claude-sonnet-5` を適用してから `resolved` に戻す。
- 今後 memory・LEARNINGS.md 由来の「〜済み」という記載を実装の根拠にする際は、**必ず対象ファイルを実際に `grep`/`Read` して現状を検証してから使う**（本エントリはその実践example）。
- 本件は次回の `.learnings/` 消化（`/consume-learnings`）時に本体または担当タチコマが判断すること（本エントリ自体はその場しのぎの実装回避〈`model: sonnet` のまま新規作成〉で対応済み）。

### メタデータ

- 再現可否: yes（`/usr/bin/grep -n "^model:" plugins/devkit/agents/*.md` で即再現）
- 関連ファイル: .learnings/LEARNINGS.md（LRN-20260714-001）, plugins/devkit/agents/*.md
- タグ: model-alias, learnings-integrity, agent-config
