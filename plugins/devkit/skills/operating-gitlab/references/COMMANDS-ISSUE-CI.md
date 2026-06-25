# COMMANDS-ISSUE-CI — issue / incident / ci / job / schedule / variable 早見

issue・インシデント・CI/CD パイプライン・ジョブ・スケジュール・CI/CD 変数のコマンド早見。対象プロジェクトは `-R OWNER/REPO` で明示できる。

> 🔴 破壊的操作（`issue close`・`issue delete`・`schedule delete`・`variable delete`・`ci delete` 等）は `-y`/`--yes` で自動承認しない。実行前に対象（ID・キー名・リポジトリ・影響範囲）を提示し、ユーザー（本体経由）の承認を得てから実行する。

## issue

### issue create

issue を起票する。

```bash
# タイトル・説明・ラベル・担当者・マイルストーンを指定して起票（作成系は -y 許可）
glab issue create -t "ログイン失敗時のエラー表示" -d "再現手順は..." -l bug -a alice -m "v1.2" -y

# 機密 issue として起票し、関連 MR・期限を指定
glab issue create -t "脆弱性対応" -c --due-date 2026-07-01 --linked-mr 42
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--title` | `-t` | タイトル |
| `--description` | `-d` | 説明 |
| `--label` | `-l` | ラベルを付与 |
| `--assignee` | `-a` | 担当者を指定 |
| `--milestone` | `-m` | マイルストーンを指定 |
| `--confidential` | `-c` | 機密 issue として作成 |
| `--due-date` | | 期限日 |
| `--epic` | | 紐づける epic |
| `--linked-mr` | | 関連 MR を指定 |
| `--template` | | issue テンプレートを指定 |
| `--yes` | `-y` | 確認プロンプトを省略 |

### issue list

issue を一覧する（参照系・非破壊）。

```bash
# 自分が担当のオープン issue を一覧
glab issue list -a @me

# 特定ラベルの issue を JSON 出力
glab issue list -l bug -F json
```

詳細なフィルタは `glab issue list --help` を参照。

### issue view

issue の詳細を表示する。`<id>` は issue の IID。

```bash
# issue の詳細を表示
glab issue view <id>

# ブラウザで開く
glab issue view <id> --web
```

### issue note

issue にコメント（ノート）を追加する。

```bash
# issue にコメントを追加
glab issue note <id> --message "調査の結果、原因は...でした"
```

### issue update

issue のタイトル・説明・ラベル・状態等を更新する。

```bash
# ラベルと担当者を更新
glab issue update <id> --label in-progress --assignee bob
```

詳細なフラグは `glab issue update --help` を参照。

### issue close

issue をクローズする。🔴 破壊的操作。実行前に対象を提示し承認を得る。

```bash
# issue をクローズ（実行前に対象を提示し承認を得る）
glab issue close <id>
```

### issue reopen

クローズ済み issue を再オープンする。

```bash
# クローズ済み issue を再オープン
glab issue reopen <id>
```

### issue delete

issue を削除する。🔴 破壊的・不可逆。実行前に対象を提示し承認を得る。

```bash
# issue を削除（実行前に対象を提示し承認を得る）
glab issue delete <id>
```

### issue subscribe

issue の通知を購読する。

```bash
# issue の通知を購読
glab issue subscribe <id>
```

### issue board

issue ボードを表示する。

```bash
# issue ボードを表示
glab issue board
```

## incident

インシデントの参照・コメント・状態変更を扱う。インシデントは issue 種別の一つ。

### incident list

インシデントを一覧する。

```bash
# インシデントを一覧
glab incident list
```

### incident view

インシデントの詳細を表示する。

```bash
# インシデントの詳細を表示
glab incident view <id>
```

### incident note

インシデントにコメントを追加する。

```bash
# インシデントにコメントを追加
glab incident note <id> --message "一次対応完了"
```

### incident close

インシデントをクローズする。🔴 破壊的操作。実行前に対象を提示し承認を得る。

```bash
# インシデントをクローズ（実行前に対象を提示し承認を得る）
glab incident close <id>
```

### incident reopen

クローズ済みインシデントを再オープンする。

```bash
# クローズ済みインシデントを再オープン
glab incident reopen <id>
```

### incident subscribe

インシデントの通知を購読する。

```bash
# インシデントの通知を購読
glab incident subscribe <id>
```

## ci

CI/CD パイプライン・ジョブを扱う。`pipe` / `pipeline` エイリアスは deprecated のため `ci` に統一する。

### ci run

パイプラインを起動する。変数の投入方法が複数ある。

```bash
# ブランチを指定してパイプラインを起動
glab ci run -b main

# 変数を key:value で渡して起動（複数指定可）
glab ci run -b release --variables DEPLOY_ENV:staging --variables DRY_RUN:true

# 変数ファイルから読み込んで起動
glab ci run -b main --variables-file ci-vars.env

# MR コンテキストでパイプラインを起動
glab ci run --mr
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--branch` | `-b` | 起動対象ブランチ |
| `--variables` | | 変数を `key:value` で指定（複数指定可） |
| `--variables-env` | | 環境変数型の変数を指定 |
| `--variables-file` | | 変数をファイルから読み込み |
| `--variables-from` | `-f` | 変数を指定ファイルから読み込み |
| `--input` | `-i` | パイプライン入力（input）を指定 |
| `--mr` | | MR コンテキストでパイプラインを起動 |
| `--web` | `-w` | ブラウザでパイプライン画面を開く |

### ci list

パイプラインを一覧する（参照系・非破壊）。

```bash
# パイプラインを一覧
glab ci list
```

### ci get

特定パイプラインの詳細を取得する。

```bash
# パイプラインの詳細を取得
glab ci get <id>
```

### ci status

パイプラインの実行状況を表示する。

```bash
# 最新パイプラインの状況を表示
glab ci status
```

### ci view

パイプラインのジョブ構成を TUI で表示する。

```bash
# パイプラインのジョブ構成を表示
glab ci view
```

### ci trace

ジョブのログをリアルタイムに追跡する。実行中ジョブの進行を追える。

```bash
# ジョブのログをリアルタイムに追跡
glab ci trace <job>
```

### ci lint

`.gitlab-ci.yml` の構文を検証する。

```bash
# CI 設定ファイルを検証
glab ci lint
```

### ci config compile

`include` を解決した最終的な CI 設定を表示する。マージ後の実効設定を確認できる。

```bash
# include 解決済みの CI 設定を表示
glab ci config compile
```

### ci retry

失敗したジョブを再実行する。

```bash
# ジョブを再実行
glab ci retry <job>
```

### ci cancel

実行中のジョブをキャンセルする。

```bash
# ジョブをキャンセル
glab ci cancel <job>
```

### ci trigger

トリガートークンでパイプライン（ジョブ）を起動する。

```bash
# ジョブをトリガー
glab ci trigger <job>
```

### ci artifact

パイプラインのアーティファクトをダウンロードする。

```bash
# 指定ブランチ・ジョブのアーティファクトを取得
glab ci artifact <branch> <job-name>
```

### ci delete

パイプラインを削除する。🔴 破壊的・不可逆。実行前に対象を提示し承認を得る。

```bash
# パイプラインを削除（実行前に対象を提示し承認を得る）
glab ci delete <id>
```

## job

### job artifact

最新パイプラインのアーティファクトをダウンロードする。ジョブ名を指定して取得する。

```bash
# 最新パイプラインの指定ジョブのアーティファクトを取得
glab job artifact <job-name>
```

## schedule

パイプラインスケジュール（定期実行）を扱う。

### schedule create

スケジュールを作成する。

```bash
# 毎日実行するスケジュールを作成
glab schedule create --description "nightly build" --ref main --cron "0 2 * * *"
```

詳細なフラグは `glab schedule create --help` を参照。

### schedule list

スケジュールを一覧する。

```bash
# スケジュールを一覧
glab schedule list
```

### schedule update

既存スケジュールを更新する。

```bash
# スケジュールを更新
glab schedule update <id> --cron "0 3 * * *"
```

### schedule delete

スケジュールを削除する。🔴 破壊的・不可逆。実行前に対象を提示し承認を得る。

```bash
# スケジュールを削除（実行前に対象を提示し承認を得る）
glab schedule delete <id>
```

### schedule run

スケジュールを即時実行する。

```bash
# スケジュールを即時実行
glab schedule run <id>
```

## variable

CI/CD 変数を扱う。`--group` でグループ変数を、省略時はプロジェクト変数を操作する。masked / protected / 環境スコープを指定できる。

### variable set

変数を作成する。

```bash
# masked かつ protected な変数を設定（値は環境変数経由で渡す）
glab variable set DEPLOY_TOKEN "$DEPLOY_TOKEN" --masked --protected

# 環境スコープを指定して設定
glab variable set API_URL https://staging.example.org --scope staging

# グループ変数として設定
glab variable set SHARED_KEY value --group my-group
```

| フラグ | 説明 |
|--------|------|
| `--group` | プロジェクト変数ではなくグループ変数を操作 |
| `--masked` | ジョブログでマスクする |
| `--protected` | 保護ブランチ/タグでのみ利用可能にする |
| `--scope` | 環境スコープを指定 |

### variable get

変数の値を取得する。

```bash
# 変数の値を取得
glab variable get DEPLOY_TOKEN
```

> **注意**: マスクされていない変数は平文値を標準出力に出す。出力をログ・チャット・コミット・共有ファイルへ転記しない。

### variable list

変数を一覧する。

```bash
# プロジェクト変数を一覧
glab variable list

# グループ変数を一覧
glab variable list --group my-group
```

### variable update

既存変数を更新する。

```bash
# 変数の値を更新
glab variable update API_URL https://prod.example.org
```

### variable delete

変数を削除する。🔴 破壊的・不可逆。実行前に対象を提示し承認を得る。

```bash
# 変数を削除（実行前に対象を提示し承認を得る）
glab variable delete DEPLOY_TOKEN
```

### variable export

変数をまとめてエクスポートする。

```bash
# 変数をエクスポート
glab variable export
```

> **注意**: マスクされていない平文値を標準出力に出す。出力をログ・チャット・コミット・共有ファイルへ転記しない。
