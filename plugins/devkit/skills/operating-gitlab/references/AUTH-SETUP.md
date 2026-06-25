# glab 認証・接続・設定リファレンス

GitLab インスタンスへの認証（gitlab.com / self-managed / CI）、glab 設定、アクセストークン管理を扱う。コマンド構文は glab v1.102.0 で裏取り済み。記載のないフラグ・サブコマンドが必要なときは `glab <group> <sub> --help` を参照する。

## glab auth login

GitLab インスタンスに認証する。資格情報は既定で `~/.config/glab-cli/config.yml` に保存される。Git リポジトリ内で対話実行すると、glab が Git remote から GitLab インスタンスを自動検出して候補に出すため、ホスト名を手入力しなくてよい。

```bash
# 対話セットアップ（Git remote から GitLab インスタンスを自動検出）
glab auth login

# GitLab Self-Managed / Dedicated に認証（ホスト名を明示）
glab auth login --hostname salsa.debian.org

# API が Git remote と別ホストの場合（hostname:port も可）
glab auth login --hostname gitlab.example.org --api-host gitlab.example.org:3443 --api-protocol https
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--hostname` |  | 認証先 GitLab インスタンスのホスト名 |
| `--api-host` | `-a` | API エンドポイントが `--hostname` と異なる場合のホスト名（`hostname:port` 可） |
| `--api-protocol` | `-p` | API プロトコル（`https` / `http`） |
| `--git-protocol` | `-g` | Git プロトコル（`ssh` / `https` / `http`） |
| `--ssh-hostname` |  | SSH エンドポイントが別ホストの場合の SSH ホスト名（ポート不要・remote URL のポートを使用） |

### 非対話・headless ログイン

CI やスクリプトなど人手プロンプトを介さない環境向け。

```bash
# トークンを環境変数から渡す（推奨・シェル履歴に残らない）
glab auth login --hostname gitlab.example.org --token "$GITLAB_TOKEN" --api-protocol https --git-protocol ssh

# トークンをファイルの標準入力から渡す（推奨）
glab auth login --stdin < myaccesstoken.txt

# コマンドラインへのトークン直書き（非推奨）: シェル履歴・プロセス一覧・CI ログに残るため避けること（構文上は可能）
# glab auth login --hostname gitlab.example.org --token glpat-xxx ...

# OAuth device authorization flow（ローカルブラウザの無い headless 環境向け・GitLab 17.9 以降）
# glab がワンタイムコードと検証 URL を表示し、ブラウザのある別端末で承認する
glab auth login --hostname gitlab.com --device

# ログイン種別プロンプトを省略して web/OAuth ログイン
glab auth login --hostname gitlab.com --web --git-protocol ssh
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--token` | `-t` | GitLab アクセストークンを直接渡す |
| `--stdin` |  | トークンを標準入力から読む |
| `--device` |  | OAuth 2.0 device authorization flow（headless 向け・GitLab 17.9 以降） |
| `--web` |  | ログイン種別プロンプトを省略し web/OAuth ログイン |
| `--use-keyring` |  | トークンを OS のキーチェーン（keyring）に保存する |
| `--job-token` | `-j` | CI ジョブトークンを使う |

> トークンを `--token` で直接渡すとシェル履歴・プロセス一覧・CI ログに残りやすい。`--stdin`（ファイル経由）または環境変数・keyring を優先する。

## glab auth status / logout

```bash
# 認証状態を確認（保存済みインスタンス・トークンの有効性）
glab auth status

# インスタンスからログアウト（資格情報を削除）
glab auth logout --hostname gitlab.example.org
```

## glab auth configure-docker / docker-helper

コンテナレジストリ操作のための Docker 資格情報ヘルパー。**`container-registry` というトップレベルコマンドは存在しない**。コンテナレジストリの認証はこの 2 コマンドで扱う。

```bash
# glab を Docker 資格情報ヘルパーとして登録（~/.docker/config.json に登録）
glab auth configure-docker

# Docker 資格情報ヘルパー本体（Docker が内部的に呼び出す。通常は直接実行しない）
glab auth docker-helper
```

`configure-docker` 登録後は、`docker login`/`docker pull`/`docker push` 時に GitLab コンテナレジストリへの認証が glab の保存済み資格情報を介して自動で行われる。

## 環境変数とトークンの優先順位

| 環境変数 | 説明 |
|----------|------|
| `GITLAB_TOKEN` | アクセストークン。保存済み資格情報より優先 |
| `GITLAB_ACCESS_TOKEN` | 同上（別名） |
| `OAUTH_TOKEN` | OAuth トークン。保存済み資格情報より優先 |
| `CI_JOB_TOKEN` | CI ジョブトークン（GitLab CI が自動付与） |
| `GLAB_ENABLE_CI_AUTOLOGIN` | `true` で CI 自動ログインを有効化 |

`GITLAB_TOKEN` / `GITLAB_ACCESS_TOKEN` / `OAUTH_TOKEN` が設定されていると、保存済み資格情報より優先される。CI 自動ログイン有効時は、これらの変数が `CI_JOB_TOKEN` も上書きする。

```bash
# CI 自動ログイン（多くの場合は手動 login より推奨）
GLAB_ENABLE_CI_AUTOLOGIN=true glab release list -R "$CI_PROJECT_PATH"

# CI ジョブトークンを明示的に渡す
glab auth login --hostname gitlab.example.org --job-token "$CI_JOB_TOKEN"
```

## glab config get / set / edit

glab 自身の設定を読み書きする。設定ファイルは `~/.config/glab-cli/config.yml`。

```bash
# 設定値を読む
glab config get editor

# 設定値を更新する
glab config set editor "code --wait"
glab config set git_protocol ssh

# 設定ファイルをエディタで直接開く
glab config edit
```

主な設定キー: `host` / `token` / `editor` / `browser` / `glab_pager` / `glamour_style`。

> `token` を平文で `config set` すると設定ファイルに平文保存される。可能なら環境変数または `auth login --use-keyring` を使う。

## glab token create / list / revoke / rotate

user / project / group のアクセストークンを管理する。引数の有無で対象が変わる（`--user` 指定で personal、`--group` 指定で group、それ以外は対象リポジトリの project token）。

```bash
# project アクセストークンを作成（スコープ・有効期限を指定）
glab token create my-ci-token --scope read_repository,read_registry --duration 30d -R OWNER/REPO

# 現在ユーザーの personal access token を作成
glab token create my-pat --user @me --scope api --expires-at 2026-12-31

# group アクセストークンを作成
glab token create my-group-token --group --scope read_api --access-level developer

# トークン一覧
glab token list -R OWNER/REPO
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--scope` | `-S` | トークンのスコープ（カンマ区切り or フラグ反復） |
| `--access-level` | `-A` | アクセスレベル（`guest`/`reporter`/`developer`/`maintainer`/`owner`） |
| `--duration` | `-D` | トークン有効期間（例: `30d`・`4w`・`24h`／最大 `365d`） |
| `--expires-at` | `-E` | 有効期限を `YYYY-MM-DD` で指定（未指定時は `--duration` を使用） |
| `--user` | `-U` | personal access token を作成（現在ユーザーは `@me`） |
| `--group` | `-g` | group アクセストークンを作成 |
| `--description` |  | トークンの説明を設定 |
| `--output` | `-F` | 出力形式（`text`=トークン値のみ / `json`=API トークン構造） |

> **🔴 破壊的操作**: `glab token revoke <token-name|token-id>`（失効）と `glab token rotate <token-name|token-id>`（旧トークン無効化＋新トークン発行）は不可逆。`-y` による自動承認をせず、対象トークン・影響範囲をユーザーに提示し承認後に実行する。

## 機密の鉄則

- トークン・資格情報をシェル履歴・コミット・CI ログに残さない。`--token` 直渡しより `--stdin`（ファイル）・環境変数・`--use-keyring` を優先する。
- `config set token <値>` は平文保存になるため避ける。
- CI では `CI_JOB_TOKEN` / `GLAB_ENABLE_CI_AUTOLOGIN=true` を使い、長命の personal token を埋め込まない。
- 作成したトークンの出力（`token create` の戻り値）はログに残さず、必要な保管先へ直ちに移す。
