# Hook 詳細設定ガイド

`capturing-learnings` スキルが提供する2つのhookの役割・設定方法・トラブルシュートをまとめる。

---

## 1. hookの役割一覧

| スクリプト名 | イベント | matcher | 何をするか |
|---|---|---|---|
| `learnings-reminder.sh` | `UserPromptSubmit` | `*`（全プロンプト） | タスク終了後に学び記録を促す日本語リマインダーを stdout に出力し、モデルコンテキストに注入する |
| `learnings-error-detector.sh` | `PostToolUse` | `Bash` | Bash ツール実行結果にエラーパターンを検出し、`.learnings/ERRORS.md` への記録を促す `additionalContext` JSON を出力する |

### learnings-reminder.sh の詳細

`UserPromptSubmit` イベントで毎プロンプト前に発火する。stdout に出力した内容はモデルのコンテキストに `<learning-reminder>…</learning-reminder>` ブロックとして注入される。トークン消費は ~50–80 トークンに収め、非ブロッキング動作を維持する。

出力例:

```xml
<learning-reminder>
このタスクで気づいた訂正・知識ギャップ・エラーは .learnings/ に記録してください。
詳細は capturing-learnings スキルを参照。
</learning-reminder>
```

### learnings-error-detector.sh の詳細

`PostToolUse` イベント（Bash ツール限定）で発火する。stdin に届く JSON ペイロードからツール出力を抽出し、以下のエラーパターンに一致した場合のみ出力を行う（一致ゼロなら何も出力しない）:

```
error: / Error: / failed / command not found / No such file or directory /
Permission denied / fatal: / Exception / Traceback / npm ERR! /
ModuleNotFoundError / SyntaxError / TypeError / exit code / non-zero
```

`PostToolUse` では plain stdout はモデルに渡らない。そのため `hookSpecificOutput.additionalContext` 形式の JSON で出力する:

```json
{
  "hookSpecificOutput": {
    "additionalContext": "[エラー検出] .learnings/ERRORS.md に [ERR-YYYYMMDD-XXX] 形式で記録してください。"
  }
}
```

---

## 2. Claude Code での設定

### 2-1. devkit プラグインに登録済み（自動発火）

本スキルが属する **devkit プラグインの `plugin.json` にはこの2つの hook が登録済み**である。devkit をインストールしているすべてのユーザーで自動的に発火するため、個別の設定は不要。

登録済みエントリのイメージ（実際のファイルは `plugins/devkit/.claude-plugin/plugin.json`）:

```json
"UserPromptSubmit": [
  {
    "matcher": "*",
    "hooks": [
      {
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/learnings-reminder.sh",
        "timeout": 10,
        "description": "Remind to capture learnings after each task"
      }
    ]
  }
],
"PostToolUse": [
  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/learnings-error-detector.sh",
        "timeout": 10,
        "description": "Detect errors in Bash tool output and suggest ERRORS.md entry"
      }
    ]
  }
]
```

### 2-2. プロジェクト固有設定（補助的）

プロジェクト固有の `.claude/settings.json` に追加登録したい場合の JSON 例を示す。`${CLAUDE_PLUGIN_ROOT}` を使うか、プロジェクト相対パスを指定する:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/learnings-reminder.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/learnings-error-detector.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

プロジェクト相対パスを使う場合は `${CLAUDE_PLUGIN_ROOT}` を `.claude/plugins/devkit/hooks` に置き換える。

---

## 3. Codex CLI での設定

Codex CLI の hook 機能は **experimental** である。利用には以下の2ステップが必要:

### 3-1. config.toml で機能を有効化

```toml
# ~/.codex/config.toml
codex_hooks = true
```

### 3-2. hooks.json を作成

```json
// .codex/hooks.json（プロジェクトルートまたは ~/.codex/）
{
  "UserPromptSubmit": [
    {
      "matcher": "*",
      "command": "bash path/to/learnings-reminder.sh",
      "timeout": 10
    }
  ],
  "PostToolUse": [
    {
      "matcher": "Bash",
      "command": "bash path/to/learnings-error-detector.sh",
      "timeout": 10
    }
  ]
}
```

スクリプト本体は同一ファイルを使用する。stdin JSON・`additionalContext` 出力の仕様は Claude Code と共通設計のため、両エージェントで同じスクリプトが動作する。

### 3-3. hook が使えない場合のフォールバック

Codex で hook が experimental であるか、設定不可な環境では、`AGENTS.md` に学びキャプチャのガイドを追記することでフォールバックする:

```markdown
## 学びのキャプチャ（capturing-learnings）

タスク完了後・エラー発生後には以下を確認する:
- 訂正・知識ギャップ → `.learnings/LEARNINGS.md` に [LRN-YYYYMMDD-XXX] 形式で追記
- エラー → `.learnings/ERRORS.md` に [ERR-YYYYMMDD-XXX] 形式で追記
- 機能要望 → `.learnings/FEATURE_REQUESTS.md` に [FEAT-YYYYMMDD-XXX] 形式で追記
```

---

## 4. ペイロード・出力チャネルの違い

| エージェント / イベント | stdin ペイロード | モデルへの出力方法 |
|---|---|---|
| Claude Code – UserPromptSubmit | なし（プロンプト前に発火） | plain stdout がそのままコンテキストに注入される |
| Claude Code – PostToolUse | JSON `{ "tool_response": "..." }` | `hookSpecificOutput.additionalContext` JSON が必要 |
| Codex – UserPromptSubmit | なし | plain stdout がコンテキストに注入される（experimental） |
| Codex – PostToolUse | JSON `{ "tool_response": "..." }` または `{ "toolResult": { "textResultForLlm": "..." } }` | `hookSpecificOutput.additionalContext` JSON |
| GitHub Copilot | 仕様非公開 | hook 経由のコンテキスト注入は現状不可・ログ出力のみ |

`learnings-error-detector.sh` は stdin の JSON 構造に関してエージェント非依存な設計にする。優先順位は `.tool_response` → `.toolResult.textResultForLlm` の順でフォールバックする。

---

## 5. トラブルシュート

### jq が見つからない環境

`learnings-error-detector.sh` は jq がある場合は jq を使い、ない場合は python3 でフォールバックしてペイロードを抽出する。python3 も使えない場合は何も出力せず静かに終了する（エラー検出が無効になるだけで他への影響はない）。

### スクリプトに実行権限がない

```bash
chmod 755 plugins/devkit/hooks/learnings-reminder.sh
chmod 755 plugins/devkit/hooks/learnings-error-detector.sh
```

### command not found エラー

hook の `command` フィールドに指定したパスが正しいか確認する。devkit プラグインインストール後は `${CLAUDE_PLUGIN_ROOT}` が展開されたパスを `echo ${CLAUDE_PLUGIN_ROOT}` で確認できる。

### hook が発火しない・出力が見えない

- Claude Code: `/plugins` コマンドで devkit が有効か確認。セッションを再起動する。
- Codex: `config.toml` の `codex_hooks = true` 設定と、`.codex/hooks.json` の存在を確認する。

### オーバーヘッドが大きい

`UserPromptSubmit` のリマインダーは ~50–100 トークンに設計されている。長いプロジェクトでコンテキストが逼迫する場合は、`.claude/settings.json` から `UserPromptSubmit` フックのエントリを一時的に削除してオーバーヘッドを省ける（`PostToolUse` のエラー検出は維持を推奨）。
