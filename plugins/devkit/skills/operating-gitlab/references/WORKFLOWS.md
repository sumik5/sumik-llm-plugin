# glab エンドツーエンドワークフロー集

代表的な GitLab 作業を glab だけで完結させる手順集。各ワークフローは番号付き手順と bash コード例で示す。個別サブコマンドのフラグ詳細は `COMMANDS-MR.md`・`COMMANDS-ISSUE-CI.md`・`COMMANDS-REPO-RELEASE.md`・`COMMANDS-API-MISC.md`・`AUTH-SETUP.md` を参照する。

> **🔴 破壊的操作の鉄則**: `mr merge`・`mr delete`・`issue close/delete`・`repo delete`・`release delete`・`variable delete` などの不可逆・影響大の操作には `-y`/`--yes` を自動付与しない。実行前に対象（ID・リポジトリ・影響範囲）を提示し、ユーザー（本体経由）の明示承認を得てから実行する。

## MR ライフサイクル

ブランチ作成からマージまでの一連の流れ。マージ直前のみユーザー承認を挟む。

1. 作業ブランチを作成して push する。
2. コミット情報からドラフト MR を作成する。
3. 作業完了後にドラフトを解除する。
4. レビュー承認を得る。
5. （🔴 破壊的）マージ対象とフラグの影響を提示し、承認後にマージする。

```bash
# 1. ブランチを作成して push（ローカル git 操作）
git switch -c feature/login
git push -u origin feature/login

# 2. コミット情報からドラフト MR を作成（タイトル・本文を自動補完）
glab mr create --fill --draft

# 3. ドラフトを解除（レビュー可能状態へ）
glab mr update <id> --ready

# 4. レビュー承認
glab mr approve <id>
```

マージは破壊的操作のため、対象 MR・squash/ソースブランチ削除の影響をユーザーに提示し、明示承認を得てから実行する。承認後に実行するコマンド構文は次のとおり（`-y` は付けない）:

```bash
# 5. 承認を得た後にマージ（squash + ソースブランチ削除）
glab mr merge <id> --squash --remove-source-branch
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--squash` | `-s` | コミットを 1 つに squash してマージ |
| `--remove-source-branch` | `-d` | マージ後にソースブランチを削除 |
| `--auto-merge` | | パイプライン成功時に自動マージ |

## CI 実行 → トレース

パイプラインを起動し、ジョブログを追跡して失敗を切り分ける。

1. ブランチを指定してパイプラインを起動する（必要なら変数を渡す）。
2. パイプラインの状態を確認する。
3. 対象ジョブのログをリアルタイムに追跡する。
4. 失敗した場合はジョブを再試行するか、アーティファクトを取得して原因を調べる。

```bash
# 1. ブランチを指定してパイプラインを起動
glab ci run -b <branch>

# 変数を渡してパイプラインを起動（key:value 形式）
glab ci run -b <branch> --variables DEPLOY_ENV:staging

# 2. パイプラインの状態を確認
glab ci status

# 3. 対象ジョブのログをリアルタイム追跡
glab ci trace <job>

# 4a. 失敗したジョブを再試行
glab ci retry <job>

# 4b. 最新パイプラインのアーティファクトを取得して原因調査
glab ci artifact <branch> <job>
```

## issue 起票 → クローズ

issue を起票し、進捗をノートで残し、完了時にクローズする。MR 側でクローズ参照を使う方法も併記する。

1. ラベルと担当者を付けて issue を起票する（`-y` で非対話作成可）。
2. 進捗をノートとして追記する。
3. （🔴 破壊的）完了時に issue をクローズする。または MR 本文の `Closes #<n>` でマージ時に自動クローズさせる。

```bash
# 1. ラベル・担当者付きで issue を起票（非対話）
glab issue create -t "ログイン不具合" -l bug -a @me -y

# 2. 進捗をノートで追記
glab issue note <id> -m "原因を特定。修正 MR を作成予定"
```

issue のクローズは破壊的操作のため、対象 issue 番号を提示し承認後に実行する:

```bash
# 3a. issue をクローズ（承認後）
glab issue close <id>
```

MR 経由で自動クローズする場合は、MR 本文にクローズ参照を含める。マージ時に対象 issue が自動でクローズされる:

```bash
# 3b. MR 本文に Closes 参照を含めて作成（マージ時に issue を自動クローズ）
glab mr create --fill -m "ログイン不具合を修正。Closes #<n>"
```

## release 作成

タグを前提にリリースを発行し、アセットを添付して内容を確認する。

1. リリース対象のタグが存在することを前提にする（無い場合は `--ref` から作成される）。
2. リリースノートとアセットを付けてリリースを作成する。
3. 作成したリリースを確認する。

```bash
# 2. ディレクトリ内の全ファイルをアセットに添付し、ノート付きでリリース
glab release create v1.2.0 ./dist/* --notes "v1.2.0 リリース。新機能と修正を含む"

# リリースノートをファイルから読み込む場合
glab release create v1.2.0 ./dist/* -F CHANGELOG.md

# 3. 作成したリリースを確認
glab release view v1.2.0
```

## CI 変数投入 → パイプライン

CI/CD 変数を設定してからパイプラインを起動する。秘匿値はマスク・保護を付ける。

1. masked / protected を付けて変数を設定する。
2. パイプラインを起動する。

```bash
# 1. マスク済み・保護付きで変数を設定
glab variable set DEPLOY_TOKEN <value> --masked --protected

# 2. パイプラインを起動
glab ci run -b <branch>
```

| フラグ | 説明 |
|--------|------|
| `--masked` | ジョブログ上で値をマスク |
| `--protected` | 保護ブランチ・タグでのみ展開 |
| `--group` | プロジェクトではなくグループ変数として設定 |

## CI 設定検証

`.gitlab-ci.yml` の構文と include 解決を、パイプラインを流す前に検証する。

1. CI 設定ファイルの構文を検証する。
2. include を解決した最終設定を確認する。

```bash
# 1. .gitlab-ci.yml の構文を検証
glab ci lint

# 2. include を解決した最終設定を表示
glab ci config compile
```

## self-managed / CI 認証

gitlab.com 以外のインスタンスや CI ジョブ内での認証分岐。詳細は `AUTH-SETUP.md` を参照。

self-managed / Dedicated インスタンスへは `--hostname` でホストを指定してログインする:

```bash
# self-managed インスタンスへ対話ログイン
glab auth login --hostname <host>

# 非対話ログイン（トークンを渡す）
glab auth login --hostname <host> --token <token>
```

CI パイプライン内では `CI_JOB_TOKEN` による自動ログインが利用できる。環境変数 `GLAB_ENABLE_CI_AUTOLOGIN=true` を設定するか、`--job-token` でジョブトークンを渡す:

```bash
# CI 内でジョブトークンを使ってログイン
glab auth login --hostname <host> --job-token "$CI_JOB_TOKEN"
```

> 環境変数 `GITLAB_TOKEN` / `GITLAB_ACCESS_TOKEN` / `OAUTH_TOKEN` は保存済み資格情報より優先される。トークンはログ・コミットに残さず、環境変数または keyring 経由で扱う。
