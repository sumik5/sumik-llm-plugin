# Codex プランレビュー

スキル同梱の固定ラッパースクリプト `scripts/codex-plan-review.sh` を使用して Markdown プランファイルの致命的問題をレビューする。

## 2つのモード

| モード | 用途 | コマンド |
|-------|------|---------|
| **初回レビュー** (デフォルト) | 新規プランの致命的問題を指摘 | `scripts/codex-plan-review.sh "<plan_file_fullpath>"` |
| **再レビュー** (`--resume`) | 更新済みプランの再確認 | `scripts/codex-plan-review.sh "<plan_file_fullpath>" --resume` |

## 実行手順

### 1. Codex 存在確認

```bash
which codex
```

codex が見つからない、または実行エラーになった場合:

> codex CLIが見つかりません。`npm install -g @openai/codex` でインストールしてください。

上記メッセージを返して**終了**する。以降の手順は実行しない。

### 2. 引数解析

`$ARGUMENTS` から以下を取得:

| 引数 | 必須 | 説明 |
|------|------|------|
| `plan_file_path` | Yes | プランファイルのフルパス |
| `--resume` | No | 再レビューモード指定 |

引数なしの場合、AskUserQuestion でプランファイルパスとモードを確認:

```
AskUserQuestion(questions=[
  {
    "question": "レビュー対象のプランファイルのパスを入力してください",
    "header": "プランファイル"
  },
  {
    "question": "レビューモードを選択してください",
    "header": "モード",
    "options": [
      {"label": "初回レビュー", "description": "新規プランの初回レビュー"},
      {"label": "再レビュー (resume)", "description": "更新済みプランの再レビュー"}
    ],
    "multiSelect": false
  }
])
```

### 3. ファイル存在確認

指定パスのファイルが存在することを Read ツールで確認。存在しない場合:

> 指定されたファイルが見つかりません: `{path}`

### 4. コマンド実行

#### 初回レビュー（デフォルト）

```bash
scripts/codex-plan-review.sh "{plan_file_fullpath}"
```

`{plan_file_fullpath}` はプランファイルの**フルパス（絶対パス）**に置換する。

#### 再レビュー（`--resume` 指定時）

```bash
scripts/codex-plan-review.sh "{plan_file_fullpath}" --resume
```

### 5. エラーハンドリング

| エラー | 対応 |
|-------|------|
| codex 未インストール | インストール手順を案内して終了 |
| codex 実行エラー | エラー内容をそのまま報告し、考えられる原因を提示 |
| ファイル不存在 | パスの確認を促す |
| `--resume` で前回セッションなし | 初回レビューモードでの実行を提案 |

### 6. 結果報告

Codex の出力をそのままユーザーに報告する。
