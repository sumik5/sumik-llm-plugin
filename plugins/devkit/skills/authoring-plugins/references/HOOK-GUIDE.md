# Hook 作成ガイド

Claude Code プラグインの第4コンポーネント「Hook」の登録・stdin 契約・JSON 出力契約・Codex 差分を解説する。

---

## 1. Hook 概要と登録

Hook はプラグインの **第4コンポーネント**。Agent / Skill / Command が Claude への知識注入や実行単位を担うのに対し、Hook は **Claude Code のライフサイクルイベントに反応して自動実行されるシェルスクリプト**である。

### plugin.json への登録形式

`plugins/devkit/.claude-plugin/plugin.json` の `hooks` ブロックで登録する。形式は以下の通り。

```json
{
  "hooks": {
    "<イベント名>": [
      {
        "matcher": "<ツール名またはワイルドカード>",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh",
            "timeout": 10,
            "description": "説明"
          }
        ]
      }
    ]
  }
}
```

- `command` は `bash ${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh` 形式で記述する
- `timeout` は秒単位（推奨 10〜30）
- `matcher` はツール名またはパターン（`*` でワイルドカード・`Bash`・`Edit|Write` 等）
- 各スクリプトに **実行権限が必要**（`chmod +x` 必須）

### 対応イベント一覧

plugin.json 実例（`plugins/devkit/.claude-plugin/plugin.json`）が使用するイベントと、Claude Code が公式にサポートするイベントを以下に示す。

| イベント名 | 発火タイミング | matcher 利用 |
|-----------|-------------|------------|
| `SessionStart` | セッション開始時 | ○（`*` 等） |
| `UserPromptSubmit` | ユーザープロンプト送信時 | ○ |
| `PreToolUse` | ツール実行前 | ○（`Bash` 等） |
| `PostToolUse` | ツール実行後 | ○（`Bash`・`Edit\|Write` 等） |
| `Notification` | ユーザー入力待ち通知時 | △（matcher 省略可） |
| `Stop` | Claude の応答完了時 | △ |
| `SubagentStop` | サブエージェント完了時 | △ |
| `PreCompact` | コンパクション前 | △ |
| `SessionEnd` | セッション終了時 | △ |
| `TeammateIdle` | teammate がアイドル状態になった時 | △ |

---

## 2. stdin 契約

Hook スクリプトは起動時に **stdin から JSON を受け取る**。イベント別の主要フィールドを示す。

### 共通フィールド

| フィールド | 説明 |
|----------|------|
| `session_id` | 現在のセッション ID |
| `hook_event_name` | イベント名（`"PostToolUse"` 等） |

### PreToolUse / PostToolUse 固有フィールド

| フィールド | 説明 |
|----------|------|
| `tool_name` | 実行ツール名（`"Bash"` / `"Edit"` / `"Write"` 等） |
| `tool_input` | ツール入力（`PreToolUse`）。Bash の場合 `.tool_input.command` にコマンド文字列 |
| `tool_response` | ツール出力（`PostToolUse`）。Bash の場合 stdout/stderr の文字列 |

### SessionStart / UserPromptSubmit 固有フィールド

| フィールド | 説明 |
|----------|------|
| `prompt` | ユーザーが送信したプロンプトテキスト（`UserPromptSubmit`） |

### Stop / SubagentStop 固有フィールド

| フィールド | 説明 |
|----------|------|
| `stop_hook_active` | 停止フックが既に活性化中かのフラグ |
| `last_assistant_message` | 直前のアシスタントメッセージ |
| `agent_type` / `agent_id` / `agent_transcript_path` | SubagentStop のみ（サブエージェント情報） |

---

## 3. 出力契約（最重要）

### 出力の2形式

Hook の出力には2つの形式がある。**どちらを使うかはイベントと目的によって異なる**。取り違えると情報が届かない。

#### (a) plain stdout 型

`UserPromptSubmit` と `SessionStart` では、stdout に出力したテキストがそのまま Claude のコンテキストに注入される。

```bash
# UserPromptSubmit / SessionStart の plain stdout 例
echo "## セッション情報 ..."
```

- JSON を返す必要はない
- stdout の内容が `additionalContext` として機能する
- `detect-project-skills.sh`（SessionStart）は **jq を使って JSON を生成**しているが、その JSON の `hookSpecificOutput.additionalContext` の値がコンテキスト注入される（後述）

#### (b) JSON 型（hookSpecificOutput を返す場合）

`PreToolUse`・`PostToolUse` 等、**ツール制御やコンテキスト注入を JSON で行う場合**の形式。

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "注入するテキスト..."
  }
}
```

### 🔴 hookSpecificOutput を返す場合の必須フィールド

**`hookSpecificOutput` を返す JSON には、必ず `hookEventName` を含めなければならない。**

`hookEventName` は「この JSON がどのイベント契約で解釈されるか」を示す discriminator（識別子）である。これが欠落した場合、`additionalContext` が読まれる前にスキーマ検証が失敗し、以下のエラーが発生する:

```
Hook JSON output validation failed — hookSpecificOutput is missing required field "hookEventName"
```

#### hookEventName の値（イベント名そのものを使う）

| イベント | hookEventName の値 |
|---------|------------------|
| `SessionStart` | `"SessionStart"` |
| `UserPromptSubmit` | `"UserPromptSubmit"` |
| `PreToolUse` | `"PreToolUse"` |
| `PostToolUse` | `"PostToolUse"` |
| `Stop` | `"Stop"` |
| `SubagentStop` | `"SubagentStop"` |

値はイベント名と完全に一致させる（大文字・小文字も含めて）。

### イベント別の hookSpecificOutput フィールド

| イベント | 利用可能なフィールド |
|---------|-------------------|
| `SessionStart` | `hookEventName`・`additionalContext` |
| `UserPromptSubmit` | `hookEventName`・`additionalContext` |
| `PreToolUse` | `hookEventName`・`permissionDecision`（`"allow"`/`"deny"`）・`permissionDecisionReason`・`updatedInput`・`additionalContext` |
| `PostToolUse` | `hookEventName`・`additionalContext` |
| `Stop` | `hookEventName`・`decision`（`"block"` 等）・`reason` |

> Codex 実装では `PreToolUse` の `updatedInput` を返す場合、`permissionDecision: "allow"` が必須。
> `updatedInput` だけを返すと `PreToolUse hook returned updatedInput without permissionDecision:allow`
> で検証失敗する。ユーザー確認に回したい場合は `updatedInput` を返さず `exit 0` で元入力を通す。

### 最小例：PostToolUse で additionalContext を注入する

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "エラーが検出されました。.learnings/ERRORS.md に記録してください。"
  }
}
```

### exit code の補足

| exit code | 動作 |
|-----------|------|
| `0` | 正常終了。JSON があれば内容を処理する |
| `2` | ブロック。stderr の内容が理由として Claude に渡る |
| その他 | hook エラーとして扱われる場合がある |

- `exit 0` と JSON 出力を組み合わせてコンテキスト注入・ツール書き換えを行う
- `exit 2` + stderr でツール実行をブロックする

### 実例：先例3本の hookEventName 付与パターン

| ファイル | イベント | hookEventName 値 | 出力型 |
|---------|---------|----------------|-------|
| `hooks/detect-project-skills.sh` | SessionStart | `"SessionStart"` | JSON 型（jq で生成） |
| `hooks/rtk-rewrite.sh` | PreToolUse | `"PreToolUse"` | JSON 型（コマンド書き換え・auto-allow） |
| `hooks/learnings-error-detector.sh` | PostToolUse | `"PostToolUse"` | JSON 型（additionalContext 注入） |

これら3本はいずれも `hookSpecificOutput.hookEventName` を正しく付与している正例である。

---

## 4. Codex 差分

Codex CLI では hook の配布方式・対応イベント・パス解決規則が Claude Code と異なる。本セクションは概要のみを示す。詳細は [MANAGING-MULTI-PLUGIN.md](MANAGING-MULTI-PLUGIN.md) と `.learnings/LEARNINGS.md [LRN-20260625-001]` を参照。

### 配布方式の差異

- Codex はプラグイン root 直下の **`hooks-codex.json`**（または明示宣言したパス）で hook を配布する
- `.codex-plugin/plugin.json` に `"hooks": "./hooks-codex.json"` で明示宣言が可能
- devkit では `hooks-codex.json`（repo root）＋ `.codex-plugin/plugin.json` の `"hooks"` 宣言を使用

### 対応イベントは Claude Code の部分集合

Codex が対応するイベント（SessionStart / SubagentStart / PreToolUse / PermissionRequest / PostToolUse / PreCompact / PostCompact / UserPromptSubmit / SubagentStop / Stop）は Claude Code の部分集合。`Notification` / `SessionEnd` / `TeammateIdle` は Codex 非対応。

### パス解決の差異

- Codex の hook command はユーザーの作業ディレクトリで実行されることがあるため、`./plugins/devkit/hooks/<name>.sh` のような cwd 相対パスは使わない
- Codex では hook 実行時の環境変数として `PLUGIN_ROOT` が set される。Claude 互換の alias として `CLAUDE_PLUGIN_ROOT` も参照できる
- devkit の `hooks-codex.json` では `"bash \"${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:?}}/plugins/devkit/hooks/<name>.sh\""` 形式にして、repo root 以外の cwd でも同じ hook を呼び出す
- Claude Code 側の `plugins/devkit/.claude-plugin/plugin.json` は従来通り `"bash ${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh"` 形式を使う。Claude plugin root は `plugins/devkit` なので Codex とパス末尾が異なる

### その他

- `config.toml` の `[features] hooks = true` が必要（opt-in）
- プラグイン同梱 hook は非管理 hook 扱いで、ユーザーが明示的に trust するまでスキップされる

---

## 5. 反映上の注意

**Hook の編集はソースリポジトリのみ**に行う。

稼働中の hook は Claude では `~/.claude/plugins/cache/...`、Codex では `codex plugin list` の PATH が示す marketplace checkout にある。ソースリポジトリでの修正は、**push + プラグイン再インストール / marketplace upgrade** が完了するまで実行中のコピーに反映されない。

| 環境 | 実体パス |
|-----|---------|
| 編集対象（正） | `/Users/sumik/repo/shivase/sumik-claude-plugin/plugins/devkit/hooks/` |
| Claude 実行コピー（触らない） | `~/.claude/plugins/cache/sumik/devkit/<version>/hooks/` |
| Codex 実行コピー（触らない） | `codex plugin list` の devkit PATH（例: `~/.codex/.tmp/marketplaces/...`） |

---

## 6. Hook 作成チェックリスト

新規 hook を作成・修正する際は以下を確認する。

- [ ] `plugin.json` の `hooks` ブロックに登録されているか
- [ ] スクリプトに実行権限が付与されているか（`chmod +x hooks/<name>.sh`）
- [ ] `hookSpecificOutput` を返す場合、`hookEventName` が含まれているか（**必須**）
- [ ] plain stdout 型（SessionStart・UserPromptSubmit）と JSON 型（PreToolUse・PostToolUse 等）を取り違えていないか
- [ ] `exit 0` + JSON で正常系・`exit 2` + stderr でブロック系を使い分けているか
- [ ] stdin から必要なフィールドを正しく取得しているか（`.tool_name`・`.tool_input.command`・`.tool_response` 等）
- [ ] Codex 向けに配布する場合、`hooks-codex.json` の command が `PLUGIN_ROOT` / `CLAUDE_PLUGIN_ROOT` ベースで cwd 非依存になっているか
- [ ] Codex 非対応イベント（`Notification`・`SessionEnd`・`TeammateIdle`）を `hooks-codex.json` に誤って含めていないか
- [ ] 編集後のソースを push + プラグイン再インストールして動作確認を行ったか
