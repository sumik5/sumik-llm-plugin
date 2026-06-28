# Hooks パターン集（Claude Code / Codex 両対応）

---

## 検出シグナル → Hook レコメンド表

| 検出パターン | 推奨 Hook | イベント | マッチャー |
|------------|---------|---------|----------|
| `"prettier"` in devDependencies | Prettier 自動フォーマット | `PostToolUse` | `Edit\|Write\|MultiEdit` |
| `.eslintrc*` / `eslint.config.*` | ESLint 自動実行 | `PostToolUse` | `Edit\|Write` |
| `[tool.black]` in pyproject.toml | Black 自動フォーマット | `PostToolUse` | `Edit\|Write` |
| `[tool.ruff]` in pyproject.toml | Ruff linter 自動実行 | `PostToolUse` | `Edit\|Write` |
| `go.mod` 存在 | gofmt 自動フォーマット | `PostToolUse` | `Edit\|Write` |
| `Cargo.toml` 存在 | rustfmt 自動フォーマット | `PostToolUse` | `Edit\|Write` |
| `tsconfig.json` 存在 | tsc 型チェック | `PostToolUse` | `Edit\|Write` |
| `[tool.mypy]` / `mypy.ini` | mypy 型チェック | `PostToolUse` | `Edit\|Write` |
| `.env` ファイル存在 | `.env` 誤コミット保護 | `PreToolUse` | `Bash` |
| `package-lock.json` / `yarn.lock` | lockfile 保護（直接編集禁止） | `PreToolUse` | `Edit\|Write` |
| `jest.config.*` / `vitest.config.*` | テスト自動実行 | `PostToolUse` | `Edit\|Write` |
| `pytest.ini` / `pyproject.toml[tool.pytest]` | pytest 自動実行 | `PostToolUse` | `Edit\|Write` |
| ターミナル通知が有用なプロジェクト | 処理完了通知（macOS 通知センター等） | `Stop` | — |

---

## セットアップ手順

### Claude Code 版

`.claude/settings.json` の `hooks` キーに JSON で記述する。

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "npx prettier --write $FILE"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'if echo \"$COMMAND\" | grep -q \"\\.env\"; then echo \"ERROR: .env への直接操作は禁止\"; exit 1; fi'"
          }
        ]
      }
    ]
  }
}
```

プラグイン経由で配布する場合は `plugin.json` の `hooks` セクションに記述する。

### Codex 版

まず `~/.codex/config.toml` で hooks 機能を有効化したうえで、`hooks.json`（Claude の
`settings.json` の `hooks` と**同一スキーマ**＝ `matcher` + `hooks` 配列）で定義するのが確実。

```toml
# ~/.codex/config.toml — まず hooks 機能を有効化（必須）
[features]
hooks = true
```

```json
// hooks.json（Claude の settings.json の hooks と同一スキーマ）
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": "npx prettier --write $FILE" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash -c 'if echo \"$COMMAND\" | grep -q \"\\.env\"; then echo \"ERROR: .env への直接操作は禁止\"; exit 1; fi'" }
        ]
      }
    ]
  }
}
```

> **Codex 重要**: `~/.codex/config.toml` に `[features] hooks = true` が無いと hook は一切動作しない
> （旧称 `codex_hooks = true` は廃止予定）。**コマンドハンドラ（`type: "command"`）のみ有効**で、
> prompt/agent ハンドラは解析されるが実行されない。config.toml へのインライン記述
> （`[hooks.<Event>]`）も可能だが、Claude と同一スキーマの `hooks.json` を使うと
> hook スクリプト本体を両プラットフォームで流用しやすい。

---

## Hook スクリプトテンプレート

### フォーマッタ系（PostToolUse）

```bash
#!/usr/bin/env bash
# PostToolUse: ファイル保存後に自動フォーマット
# $FILE 環境変数に対象ファイルパスが渡される

set -euo pipefail

case "${FILE##*.}" in
  js|ts|jsx|tsx|css|json|md) npx prettier --write "$FILE" ;;
  py) python -m black "$FILE" ;;
  go) gofmt -w "$FILE" ;;
  rs) rustfmt "$FILE" ;;
esac
```

### 保護系（PreToolUse）

```bash
#!/usr/bin/env bash
# PreToolUse: 誤操作防止チェック
# $COMMAND に実行しようとしたコマンドが渡される

# .env 直接操作を禁止
if echo "$COMMAND" | grep -E '\.env($|[^.]|\.local|\.test)' > /dev/null 2>&1; then
  echo "ERROR: .env ファイルへの直接操作は禁止されています。環境変数マネージャを使用してください。"
  exit 1
fi

# lockfile 直接編集を禁止
if echo "$COMMAND" | grep -E 'package-lock\.json|yarn\.lock|pnpm-lock\.yaml' > /dev/null 2>&1; then
  echo "ERROR: lockfile の直接編集は禁止されています。パッケージマネージャ経由で更新してください。"
  exit 1
fi
```

---

## イベント別活用例

| イベント | 典型的な用途 |
|---------|------------|
| `PreToolUse` | 危険操作の事前ブロック、`.env` 保護、本番環境誤実行防止 |
| `PostToolUse` | フォーマット、lint、テスト実行、ファイル生成後処理 |
| `UserPromptSubmit` | プロンプト前処理、コンテキスト自動注入 |
| `Stop` | 完了通知（デスクトップ通知・Slack 通知等） |
| `SessionStart` | 環境チェック、依存ツールの存在確認 |
| `PreCompact` | コンパクション前の状態保存 |

詳細なイベント名対応は `platform-matrix.md` のイベント対応表を参照。
