# COMMANDS-MR — マージリクエスト（mr）コマンド早見

`glab mr` はマージリクエストの作成・参照・レビュー・マージを扱う。対象プロジェクトは `-R OWNER/REPO` で明示できる（省略時はカレントの Git remote から推定）。

> 🔴 破壊的操作（`mr merge`・`mr close`・`mr delete`）は `-y`/`--yes` で自動承認しない。実行前に対象 MR の ID・リポジトリ・影響（squash / ソースブランチ削除の有無）を提示し、ユーザー（本体経由）の承認を得てから実行する。

## mr

### mr create

ブランチからマージリクエストを作成する。`--fill` でコミット情報からタイトル・説明を自動補完できる。

```bash
# コミット情報から自動補完してドラフト MR を作成（レビュー前段）
glab mr create --fill --draft --reviewer alice --label RFC

# ターゲット/ソースブランチとマイルストーンを指定して作成
glab mr create -b main -s feature/login -m "v1.2" -a bob --remove-source-branch

# テンプレートと関連 issue を指定し、対話せず作成（作成系は -y 許可）
glab mr create --template default -i 42 --squash-before-merge -y
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--fill` | `-f` | コミットのタイトル・説明・ブランチ名から MR 情報を自動補完 |
| `--draft` | | ドラフト MR として作成（旧 `--wip`） |
| `--assignee` | `-a` | 担当者を指定 |
| `--reviewer` | | レビュアーを指定 |
| `--label` | `-l` | ラベルを付与 |
| `--milestone` | `-m` | マイルストーンを指定 |
| `--target-branch` | `-b` | マージ先ブランチ |
| `--source-branch` | `-s` | マージ元ブランチ |
| `--template` | | MR テンプレートを指定 |
| `--related-issue` | `-i` | 関連 issue を指定（クローズ連携） |
| `--squash-before-merge` | | マージ時に squash する設定を付与 |
| `--remove-source-branch` | | マージ後にソースブランチを削除する設定を付与 |
| `--push` | | 作成前にローカルブランチを push |
| `--yes` | `-y` | 確認プロンプトを省略 |
| `--web` | `-w` | ブラウザで作成画面を開く |

### mr list

MR を一覧する。参照系のため非破壊。フィルタ・出力整形フラグを組み合わせる。

```bash
# 自分が担当の未マージ MR を一覧
glab mr list -a @me

# ドラフト以外のオープン MR を作成日でソートし JSON 出力 → jq で抽出
glab mr list -o created_at -F json --jq '.[].iid'

# 特定ラベルかつ指定期間に作成された MR をグループ横断で一覧
glab mr list -l backend --created-after 2026-01-01 -g my-group
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--all` | `-A` | 全状態（open/closed/merged）を対象 |
| `--assignee` | `-a` | 担当者で絞り込み（`@me` で自分） |
| `--author` | | 作成者で絞り込み |
| `--closed` | `-c` | クローズ済みのみ |
| `--merged` | `-M` | マージ済みのみ |
| `--draft` | `-d` | ドラフトのみ |
| `--label` | `-l` | ラベルで絞り込み |
| `--milestone` | `-m` | マイルストーンで絞り込み |
| `--created-after` | | 指定日時より後に作成 |
| `--created-before` | | 指定日時より前に作成 |
| `--order` | `-o` | ソート基準（例: `created_at`） |
| `--output` | `-F` | 出力形式（`json` 等） |
| `--jq` | | JSON 出力に jq 式を適用 |
| `--group` | `-g` | グループ横断で一覧 |

### mr view

MR の詳細（説明・状態・パイプライン・ノート）を表示する。`<id>` は MR の IID。

```bash
# MR の詳細を表示
glab mr view <id>

# コメント（ノート）込みでブラウザで開く
glab mr view <id> --web
```

### mr diff

MR の差分を表示する。

```bash
# MR の差分を表示
glab mr diff <id>
```

### mr checkout

MR のソースブランチをローカルにチェックアウトする。手元で動作確認・追従に使う。

```bash
# MR <id> のブランチをチェックアウト
glab mr checkout <id>
```

### mr update

既存 MR のタイトル・説明・状態（ドラフト解除等）を更新する。

```bash
# タイトルとラベルを更新
glab mr update <id> --title "新しいタイトル" --label ready-for-review
```

ドラフト解除を含む状態変更や利用可能なフラグの詳細は `glab mr update --help` を参照。

### mr note

MR にコメント（ノート）を追加する。

```bash
# MR にコメントを追加
glab mr note <id> --message "レビュー指摘に対応しました"
```

### mr approve

MR を承認する。承認ルールが設定されたプロジェクトでマージ条件を満たすために使う。

```bash
# MR を承認
glab mr approve <id>
```

### mr revoke

自分の承認を取り消す。

```bash
# 承認を取り消す
glab mr revoke <id>
```

### mr approvers

MR の承認者・承認状況を表示する。

```bash
# 承認者と承認状況を確認
glab mr approvers <id>
```

### mr merge

MR をマージする。🔴 破壊的操作。`-y` で自動承認せず、squash / rebase / ソースブランチ削除の影響を提示し承認後に実行する。

```bash
# squash してソースブランチを削除（実行前に対象と影響を提示し承認を得る）
glab mr merge <id> --squash --remove-source-branch -m "feat: ログイン機能"

# パイプライン成功時に自動マージ（auto-merge）
glab mr merge <id> --auto-merge
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--squash` | `-s` | コミットを squash してマージ |
| `--rebase` | `-r` | マージ前に rebase |
| `--remove-source-branch` | `-d` | マージ後にソースブランチを削除 |
| `--auto-merge` | | パイプライン成功時に自動マージ |
| `--sha` | | 指定 SHA がヘッドの場合のみマージ |
| `--message` | `-m` | マージコミットメッセージ |
| `--yes` | `-y` | 確認プロンプトを省略（🔴 破壊的操作のため使用しない） |

### mr rebase

MR のソースブランチをターゲットブランチに対して rebase する。

```bash
# MR を rebase
glab mr rebase <id>
```

### mr close

MR をクローズする。🔴 破壊的操作。実行前に対象を提示し承認を得る。

```bash
# MR をクローズ（実行前に対象を提示し承認を得る）
glab mr close <id>
```

### mr reopen

クローズ済み MR を再オープンする。

```bash
# クローズ済み MR を再オープン
glab mr reopen <id>
```

### mr delete

MR を削除する。🔴 破壊的・不可逆。実行前に対象を提示し承認を得る。`-y` で自動承認しない。

```bash
# MR を削除（実行前に対象を提示し承認を得る）
glab mr delete <id>
```

### mr subscribe

MR の通知を購読する。

```bash
# MR の通知を購読
glab mr subscribe <id>
```

### mr todo

MR を自分の To-Do リストに追加する。

```bash
# MR を To-Do に追加
glab mr todo <id>
```

### mr for

現在のブランチに対応する MR を表示する（ブランチからの逆引き）。

```bash
# カレントブランチに紐づく MR を表示
glab mr for
```

### mr issues

MR がクローズする issue の一覧を表示する。

```bash
# MR <id> がクローズする issue を一覧
glab mr issues <id>
```
