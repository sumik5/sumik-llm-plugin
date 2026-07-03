# LEARNINGS — sumik-claude-plugin

作業中に得た非自明な学び・調査結果の記録（capturing-learnings 形式）。

---

## [LRN-20260625-001] Codex CLI プラグイン hook の仕様（Claude Code との差分）

**種別**: knowledge_gap（一次ソース＋実プラグインで検証済み）

**背景**: dotfiles の hook を devkit に取り込み Claude Code / Codex 両対応にする際、Codex の
プラグイン hook 仕様を一次ソース（developers.openai.com/codex の hooks / plugins/build /
config-reference）＋ローカル実プラグイン（figma・replayio の `hooks.json`）で確認した結果。

**判明した非自明な事実**:

1. **配布方式**: Codex プラグインは **plugin root 直下の `hooks.json`** で hook を配布する。
   スキーマは Claude Code の plugin.json `hooks` ブロックと**同一**（event → `[{matcher, hooks:[{type:"command", command, timeout}]}]`）。
   - **自動発見される**（figma の `.codex-plugin/plugin.json` に `hooks` キーが無いのに `hooks.json` が動く＝全181プラグイン manifest をスキャンしても `hooks` キーは皆無）。
   - ただし `.codex-plugin/plugin.json` に `"hooks": "./<path>"` で**明示宣言も可能**（宣言が自動発見を上書き）。**ドキュメントは既定パスを `./hooks/hooks.json` と記すが、実出荷プラグインは root 直下 `hooks.json`**＝ドキュメントと実態に乖離。曖昧さを避けるなら明示宣言が安全。

2. **対応イベントは Claude Code の部分集合**。Codex 対応 = SessionStart / SubagentStart /
   PreToolUse / PermissionRequest / PostToolUse / PreCompact / PostCompact / UserPromptSubmit /
   SubagentStop / Stop の10種。**非対応 = Notification / SessionEnd / TeammateIdle**（公式が「not documented」と明示）。
   → これらに紐づく hook（通知系の一部・retrospective 等）は Codex 側に登録できない。

3. **Codex hook command は cwd 相対パスではなく `PLUGIN_ROOT` / `CLAUDE_PLUGIN_ROOT` 環境変数で解決する**。
   `./scripts/...` や `./plugins/devkit/hooks/...` のような相対パスは、hook 実行時 cwd が plugin root でない場合に `exit 127` になる。
   devkit は plugin root = repo root のため、Codex 側では `bash "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:?}}/plugins/devkit/hooks/X.sh"` 形式にする。
   - MCP 設定の `command` で `${CLAUDE_PLUGIN_ROOT}` が展開されない問題とは別に、hook では実行時環境変数として `PLUGIN_ROOT` と互換 alias `CLAUDE_PLUGIN_ROOT` が使える。

4. **stdin JSON のフィールド名は Claude Code と一致**（replayio の実スクリプトが `.tool_input.command` を読む）。
   Stop/SubagentStop は `stop_hook_active` / `last_assistant_message`、SubagentStop は加えて `agent_type`/`agent_id`/`agent_transcript_path`。
   出力も同形（exit 0 + JSON `hookSpecificOutput.additionalContext` / exit 2 で block・stderr が理由）。

5. **実験的・opt-in・trust gate**: `config.toml` の `[features] hooks = true` が正（`codex_hooks` は**deprecated alias**）。
   プラグイン同梱 hook は「non-managed」扱いで、**ユーザーが明示的に review & trust するまで Codex はスキップ**する
   （install/enable だけでは自動信頼されない）。Windows は無効。

**この repo での適用**: Claude は `plugins/devkit/.claude-plugin/plugin.json` の hooks ブロック（全イベント・`${CLAUDE_PLUGIN_ROOT}/hooks/...`）。
Codex は repo root `hooks-codex.json`（対応イベントのみ・`${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:?}}/plugins/devkit/hooks/...`）＋ `.codex-plugin/plugin.json` の `"hooks": "./hooks-codex.json"` 宣言。

**昇格候補**: 反復（他の Codex プラグイン作業で再利用）が確認できれば `authoring-plugins` の
`MANAGING-MULTI-PLUGIN.md` か CLAUDE.md「Codex プラグイン配布の注意点」表へ hook 配布規約として昇格。

---

## [LRN-20260625-002] Codex プラグインの「実アクティブパス」は `codex plugin list` の PATH 列で見る

**種別**: knowledge_gap（デバッグで判明）

**症状**: devkit を 14.2.0 へ更新後、`~/.codex/plugins/cache/sumik-marketplace/devkit/` を見ると最新が
`14.1.1` 止まりで hooks-codex.json も無く、「Codex 未更新」と誤判断した。

**真相**: `~/.codex/plugins/cache/...` は**陳腐化した別キャッシュ**で、Codex が実際に読むのは
`codex plugin list` の PATH 列が示すパス——本件では
`/Users/sumik/.codex/.tmp/marketplaces/sumik-marketplace/.cache/sumik-marketplace/devkit`
（= marketplace チェックアウト内の `.cache/<mp>/devkit → ../..` symlink = git チェックアウト root）。
これは push 済み main を直接指すため 14.2.0＋hooks-codex.json が即反映されていた。

**対処**: Codex プラグインの版・内容を確認する時は `~/.codex/plugins/cache` を信用せず、
`codex plugin list`（STATUS=installed,enabled / VERSION / **PATH**）で実体パスを特定し、
そのパスの `.codex-plugin/plugin.json`・`hooks-codex.json` を読む。関連: [[mcp-availability-from-session-not-just-config]]（config 単独で断定しない）。

**Codex で plugin hook を発火させる3条件**（本件で確立）:
1. プラグインが hooks-codex.json 同梱版（marketplace 経由で push 済み main が反映）
2. `~/.codex/config.toml` の `[features] hooks = true`（旧 `codex_hooks` は deprecated alias）
3. **trust 承認**（plugin 同梱 hook = 非管理 hook。次回 `codex` 起動時にプロンプト。自動化は
   `codex --dangerously-bypass-hook-trust` だが常用非推奨）

---

## [LRN-20260626-001] CLAUDE.md（global / project）はルールが「追記せよ」と言っても無断編集しない

**種別**: correction（ユーザー訂正）

**経緯**: hook 修正タスクの副産物として、global `~/.claude/CLAUDE.md` の「📥 スキル改善提案 (inbox)」へ
`[PROPOSAL]` を**ユーザー確認なしで追記**した。根拠は CLAUDE.md 自身の「スキルを読込/使用中に改善余地を
発見した時 → 📥 へ1件追記」というルール。だがユーザーから「ユーザーへの確認なしに CLAUDE.md は編集しないで」
と訂正された。

**学び（予防ルール）**: CLAUDE.md（global `~/.claude/CLAUDE.md`・project どちらも）への書き込みは、
**たとえ CLAUDE.md 内のルールが追記/更新を促していても、事前にユーザー確認を取る**こと。
inbox `[PROPOSAL]` 追記・ルール表の更新・sessions-index 更新の類も例外ではない。
「ルールが自動編集を許可しているように読める」ことを無断編集の根拠にしない——
ユーザーの確認ゲートがルール追従の自律性に優先する。

**正しい運用**: 改善提案や CLAUDE.md 更新候補が生じたら、(1) 提案文を会話でユーザーに提示し、
(2) 「inbox に追記してよいか」を確認してから編集する。`.learnings/` への reflexive 記録は引き続き
本体が直接行ってよい（CLAUDE.md ではないため）。

**昇格候補**: 反復（CLAUDE.md 系の無断編集を再度やる）が確認されれば memory / CLAUDE.md の
予防ルールへ昇格。ただし昇格時の CLAUDE.md 編集自体もユーザー確認を取る。

---

## [LRN-20260627-001] Codex hook trust を常用回避するには wrapper で `--dangerously-bypass-hook-trust` を付ける

**記録日時**: 2026-06-27T10:25:00+09:00
**優先度**: medium
**ステータス**: resolved
**領域**: config

### 要約
Codex CLI 0.142.3 では hook の review / active 状態は `~/.codex/config.toml` の `[hooks.state]` に hook ごとの `trusted_hash` と `enabled = true` として保存される。plugin 更新や別 cwd で Review が煩わしい場合、現行 hash を有効化したうえで、PATH 先頭の wrapper から公式フラグ `--dangerously-bypass-hook-trust` を自動付与すると再発に強い。

### 詳細
`codex --help` に `--dangerously-bypass-hook-trust` があり、説明は「persisted hook trust を要求せず enabled hooks を実行する」趣旨。バイナリ文字列には `tui/src/startup_hooks_review.rs`、`HookStateToml`、`trusted_hash`、`bypass_hook_trust` があり、実際の `~/.codex/config.toml` には `devkit@sumik-marketplace:hooks-codex.json:<event>:...` ごとの `trusted_hash` が保存されていた。`/hooks` 表示上の Active 化には各 state に `enabled = true` も必要。`~/dotfiles/bin` が PATH 先頭なので、`~/dotfiles/bin/codex` から mise 管理下の実体に `--dangerously-bypass-hook-trust` を付けて委譲すれば、hash が変わった場合でもどの cwd から起動しても review 操作を省ける。

### 推奨アクション
現行 hook は `~/.codex/config.toml` の `[hooks.state.*]` に `enabled = true` を付ける。常用時は `~/dotfiles/bin/codex` wrapper を使う。問題切り分けや安全側に戻したい場合は `CODEX_BYPASS_HOOK_TRUST=0 codex ...` で bypass を無効化する。plugin の hook 内容を変更した直後に安全確認したい場合は、wrapper を一時無効化して `/hooks` の差分を確認する。

### メタデータ
- 発生源: conversation
- 関連ファイル: /Users/sumik/dotfiles/bin/codex, /Users/sumik/.codex/config.toml
- タグ: codex, hooks, trust, dotfiles
- 関連(See Also): LRN-20260625-001, LRN-20260625-002, ERR-20260627-001
- Pattern-Key: codex-hook-trust
- Recurrence-Count: 1 / First-Seen: 2026-06-27 / Last-Seen: 2026-06-27

## [LRN-20260702-001] 一括 description 監査は analyze→敵対的verify+apply→機械検証ゲートの3段構成が有効

**記録日時**: 2026-07-02T21:35:00+09:00
**優先度**: medium
**ステータス**: resolved
**領域**: workflow
**種別**: best_practice

### 要約
84スキルの description 一括改善で、(1) 読み取り専用 analyze（本文と突き合わせて提案を生成）→ (2) 敵対的 verify+apply（別エージェントが一次ソースを読み直して検証合格分のみ Edit）→ (3) 本体の機械検証ゲート（YAML/字数/参照実在/禁止語/言語比率/本文不変を全件スクリプト検証）の3段が機能した。系統的問題の最多はクロスプラグイン参照の `plugin:skill` 修飾漏れ、次点は本文成長に伴う description の内容ドリフト。機械ゲートは「著者」（コードレビュー文脈の author 訳語）を書籍著者パターンとして誤検知したが、リポジトリ規約の grep ゲートも同様に反応する語のため「PR作成者」への言い換えで解消した。規約化した知見は authoring-plugins の NAMING.md/INSTRUCTIONS.md に焼き込み済み。

### メタデータ
- 関連ファイル: plugins/devkit/skills/authoring-plugins/references/NAMING.md, plugins/devkit/skills/authoring-plugins/INSTRUCTIONS.md
- 関連(See Also): ERR-20260702-001

## [LRN-20260703-001] Agent Skills strict validation は Claude Code 拡張 frontmatter を拒否する

**記録日時**: 2026-07-03T13:41:45+09:00
**優先度**: medium
**ステータス**: resolved
**領域**: docs
**種別**: knowledge_gap

### 要約
Codex CLI がローカルで読み込める SKILL.md でも、Agent Skills 公式の `skills-ref validate` と OpenAI API upload 相当の strict validation では `context` / `agent` / `when_to_use` / `disable-model-invocation` などの Claude Code 拡張 frontmatter が失敗する。

### 詳細
84スキルの Codex 互換性確認で、`name` / `description` / 親ディレクトリ名一致 / description 1024字以内は全件 OK だった。一方、`uvx --from 'git+https://github.com/agentskills/agentskills.git#subdirectory=skills-ref' skills-ref validate plugins/devkit/skills/authoring-plugins` は `disable-model-invocation` を unknown field として拒否した。全件集計では 40/84 スキルが strict validation では失敗し、理由は標準フィールド外の Claude Code 拡張または独自メタデータだった。Codex の暗黙呼び出し抑止は `disable-model-invocation: true` ではなく、skill 配下の `agents/openai.yaml` に `policy.allow_implicit_invocation: false` を置く。

### 推奨アクション
Codex strict / OpenAI API 配布を対象にする skill は frontmatter を `name` / `description` / `license` / `compatibility` / `metadata` / `allowed-tools` に限定する。Claude Code 専用挙動を使う場合は strict 非互換として扱い、Codex 向けの invocation policy は `agents/openai.yaml` に分離する。description 改修時は `when_to_use` にしかない重要トリガーが Codex で欠落しないか確認する。

### メタデータ
- 発生源: conversation
- 関連ファイル: plugins/devkit/skills/authoring-plugins/INSTRUCTIONS.md, plugins/devkit/skills/authoring-plugins/references/SKILL-GUIDE.md, plugins/devkit/skills/authoring-plugins/references/NAMING.md
- タグ: codex, agent-skills, skill-validation, authoring-plugins
- Pattern-Key: codex-skill-strict-validation
- Recurrence-Count: 1 / First-Seen: 2026-07-03 / Last-Seen: 2026-07-03
