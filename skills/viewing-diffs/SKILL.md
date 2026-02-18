---
name: difit
description: >-
  作業中のコードの差分を difit（GitHub風diffビューア）でブラウザ表示する。
  Use when viewing code diffs in GitHub-style browser UI or reviewing GitHub PRs.
disable-model-invocation: true
allowed-tools: Bash
argument-hint: "[. | staged | working | <commit> | <branch1> <branch2> | --pr <url>]"
---

# difit - GitHub風差分ビューア

コーディング中の差分を [difit](https://github.com/yoshiko-pg/difit) でブラウザ表示する。

## 実行手順

### 1. difit の存在確認・自動インストール

```bash
command -v difit >/dev/null 2>&1 || npm install -g difit
```

difit が未インストールの場合、`npm install -g difit` で自動インストールする。

### 2. 引数の解釈と実行

#### 引数あり → difit に直接渡す

| $ARGUMENTS | コマンド | 説明 |
|------------|---------|------|
| `.` | `difit .` | 全未コミット変更（staged + working） |
| `staged` | `difit staged` | ステージ済みの変更のみ |
| `working` | `difit working` | 未ステージの変更のみ |
| `<commit>` | `difit <commit>` | 特定コミットの差分 |
| `<branch1> <branch2>` | `difit <branch1> <branch2>` | ブランチ間比較 |
| `--pr <url>` | `difit --pr <url>` | GitHub PR のレビュー |

#### 引数なし → AskUserQuestion で表示対象を確認

引数が指定されていない場合、以下で確認する:

```
AskUserQuestion(
    questions=[{
        "question": "どの差分を表示しますか？",
        "header": "差分対象",
        "options": [
            {"label": "未コミット変更（全体）", "description": "staged + working の全変更を表示"},
            {"label": "ステージ済みのみ", "description": "git add 済みの変更を表示"},
            {"label": "直前のコミット", "description": "HEADコミットの差分を表示"},
            {"label": "GitHub PR レビュー", "description": "PR URLを指定してレビュー"}
        ],
        "multiSelect": false
    }]
)
```

選択に応じた実行:

| 選択 | コマンド |
|------|---------|
| 未コミット変更（全体） | `difit .` |
| ステージ済みのみ | `difit staged` |
| 直前のコミット | `difit`（引数なしでHEAD） |
| GitHub PR レビュー | PR URLを追加質問し `difit --pr <url>` |

### 3. 実行方法

Bash ツールの `run_in_background: true` で実行する。difit はWebサーバーとして起動し続けるため、フォアグラウンド実行するとプロセスが終了しない。

出力からURL（デフォルト: `http://127.0.0.1:4966`）を読み取りユーザーに表示する。

## オプション

必要に応じて以下のフラグを付与できる:

| フラグ | デフォルト | 説明 |
|--------|----------|------|
| `--mode unified` | split | unified差分表示に切替 |
| `--include-untracked` | off | 未追跡ファイルも含める |
| `--no-open` | off | ブラウザ自動起動を抑制 |
| `--tui` | off | ターミナルUI（ブラウザ不要） |
| `--port <n>` | 4966 | サーバーポート指定 |
| `--clean` | off | コメント・閲覧履歴をクリア |

## パイプ入力（フォールバック）

特殊な `git diff` オプションが必要な場合はパイプで渡すことも可能:

```bash
git diff --merge-base main feature | difit
jj diff --git | difit
```

## 注意事項

- ネイティブモード（`difit <target>`）を優先すること。コメント機能やファイル検出が優れている
- jj colocate 環境でも git 操作はそのまま動作する
- PR レビューモードは GitHub CLI（`gh auth login`）の認証情報を使用。未認証の場合は public リポジトリのみ対応
- ポートが使用中の場合は自動でインクリメントされる
