# glab api・周辺グループ リファレンス

`glab api`（REST/GraphQL 呼び出し）と、鍵管理・runner・securefile・各種小グループ、および EXPERIMENTAL/BETA 群を扱う。コマンド構文は glab v1.102.0 で裏取り済み。記載のないフラグ・サブコマンドは `glab <group> <sub> --help` を参照する。

## glab api

GitLab API への認証付き HTTP リクエストを送り、レスポンスを表示する。第 1 引数に GitLab API v4 のエンドポイントパス、または `graphql` を渡す。Git ディレクトリ内ではその認証済みホストを使い、それ以外では `gitlab.com` を使う（`--hostname` で上書き）。

HTTP メソッドは、パラメータが無ければ `GET`、パラメータが付くと `POST` が既定。`--method` で上書きする。

```bash
# 現在のプロジェクト情報を取得（:id プレースホルダが展開される）
glab api projects/:id

# issue 一覧を全ページ取得し jq で整形
glab api projects/:id/issues --paginate --jq '.[].title'

# パラメータ付与で POST に切り替わる（新規 issue 作成・--raw-field は生文字列）
glab api projects/:id/issues --raw-field title="バグ報告" --raw-field description="再現手順..."

# HTTP メソッドを明示（既存 issue をクローズ・--field は型推論付き）
glab api --method PUT projects/:id/issues/42 --field state_event=close

# GraphQL を呼ぶ
glab api graphql --raw-field query='{ currentUser { username } }'

# 別ホストの API を叩く
glab api --hostname gitlab.example.org version
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--method` | `-X` | HTTP メソッド（`GET`/`POST`/`PUT`/`DELETE` 等）を明示 |
| `--field` | `-F` | `key=value` パラメータ。`true`/`false`/`null`/整数は JSON 型へ変換。`@ファイル名`/`@-`（標準入力）でファイル読込も可 |
| `--raw-field` | `-f` | `key=value` パラメータを生文字列としてそのまま付与（型変換しない） |
| `--paginate` |  | 結果が尽きるまで全ページを順次取得 |
| `--hostname` |  | 対象ホストを上書き |
| `--input` |  | 生のリクエストボディをファイルから渡す（`-` で標準入力） |
| `--form` |  | `multipart/form-data` で送信（ファイルアップロード用・`@ファイル名` で添付） |
| `--output` |  | 出力形式（`json`=既定の整形 JSON / `ndjson`=改行区切り JSON・大規模データ向け） |

### プレースホルダ展開

エンドポイント引数中で、現在ディレクトリのリポジトリ情報に置換されるプレースホルダ:

| プレースホルダ | 展開値 |
|----------------|--------|
| `:id` | プロジェクト ID |
| `:fullpath` | フルパス |
| `:branch` | 現在のブランチ |
| `:namespace` | namespace |
| `:repo` | リポジトリ名 |
| `:user` | ユーザー |

> `--paginate` を GraphQL で使う場合、クエリは `$endCursor: String` 変数を受け取り、`pageInfo { hasNextPage, endCursor }` を取得する必要がある。

> **🔴 インジェクション・破壊的操作の注意**: 値はシェルで文字列連結して組み立てず、必ず `--field key=value` / `--raw-field key=value` 形式で glab に値として渡す。外部・AI 由来の入力を埋め込む場合はクォートし、意図しないシェル展開を防ぐ。`--method DELETE` / `PUT` / `POST` を伴う書込・削除呼び出しは破壊的操作（鉄則④）に準じて、対象エンドポイント・影響範囲をユーザーに提示し承認を得てから実行する。

## glab ssh-key / gpg-key / deploy-key

アカウント（ssh-key / gpg-key）またはプロジェクト（deploy-key）の鍵を管理する。3 グループとも `add` / `get` / `list` / `delete` を持つ。

```bash
# SSH 公開鍵をアカウントに追加（鍵ファイルを渡す）
glab ssh-key add ~/.ssh/id_ed25519.pub

# 自分の SSH 鍵一覧
glab ssh-key list

# GPG 鍵の詳細を ID で取得
glab gpg-key get <key-id>

# プロジェクトの deploy key 一覧
glab deploy-key list -R OWNER/REPO
```

| サブコマンド | 引数 | 説明 |
|--------------|------|------|
| `add` | `[key-file]` | 鍵を追加（deploy-key はプロジェクトに追加） |
| `get` | `<key-id>` | ID 指定で 1 件取得 |
| `list` |  | 鍵一覧 |
| `delete` | `<key-id>` | **🔴 破壊的**: ID 指定で削除（不可逆・自動承認しない） |

## glab runner

CI/CD ランナーを管理する。

```bash
# ランナー一覧
glab runner list

# ランナーが処理したジョブ一覧
glab runner jobs <runner-id>

# ランナーマネージャー一覧
glab runner managers <runner-id>

# ランナーをプロジェクトに割り当て / 解除
glab runner assign <runner-id> -R OWNER/REPO
glab runner unassign <runner-id> -R OWNER/REPO
```

| サブコマンド | 引数 | 説明 |
|--------------|------|------|
| `list` |  | ランナー一覧 |
| `assign` | `<runner-id>` | ランナーをプロジェクトに割り当て |
| `unassign` | `<runner-id>` | ランナーの割り当てを解除 |
| `update` | `<runner-id>` | ランナー設定を更新 |
| `jobs` | `<runner-id>` | ランナーが処理したジョブ一覧 |
| `managers` | `<runner-id>` | ランナーマネージャー一覧 |
| `delete` | `<runner-id>` | **🔴 破壊的**: ランナーを削除（不可逆・自動承認しない） |

## glab securefile

プロジェクトのセキュアファイル（CI で使う証明書・鍵などの機密ファイル）を管理する。

```bash
# セキュアファイルをアップロード
glab securefile create mycert.p12 ./certs/mycert.p12 -R OWNER/REPO

# セキュアファイル一覧
glab securefile list -R OWNER/REPO

# ID 指定でダウンロード
glab securefile download <id> -R OWNER/REPO
```

| サブコマンド | 引数 | 説明 |
|--------------|------|------|
| `create` | `<name> <path>` | セキュアファイルをアップロード |
| `download` | `[<id>]` | セキュアファイルをダウンロード |
| `get` | `<id>` | ID 指定で詳細取得 |
| `list` |  | セキュアファイル一覧 |
| `remove` | `<id>` | **🔴 破壊的**: ID 指定で削除（不可逆・自動承認しない） |

> **機密取り扱い**: `securefile download` は証明書・鍵などの機密ファイルを平文でローカルに保存する。使用後は速やかにファイルを削除し、ログ・コミット・チャット・共有ファイルに内容を残さない。

## glab iteration

```bash
# プロジェクトのイテレーション一覧
glab iteration list -R OWNER/REPO
```

`iteration` は `list` のみ。

## glab todo

自分の To-Do リストを操作する。

```bash
# To-Do 一覧
glab todo list

# To-Do を完了にする（ID 省略で全件）
glab todo done <id>
```

## glab user

```bash
# ユーザーのイベント（アクティビティ）を表示
glab user events
```

## glab changelog generate

現在のプロジェクトのチェンジログを生成する。

```bash
# チェンジログを生成
glab changelog generate -R OWNER/REPO
```

## glab alias

長いコマンドにエイリアスを設定する。

```bash
# エイリアスを設定（クォートで囲んだコマンドを登録）
glab alias set mrs 'mr list --reviewer=@me'

# エイリアス一覧
glab alias list

# エイリアスを削除
glab alias delete mrs
```

| サブコマンド | 引数 | 説明 |
|--------------|------|------|
| `set` | `<alias name> '<command>'` | エイリアスを設定 |
| `list` |  | エイリアス一覧 |
| `delete` | `<alias name>` | エイリアスを削除 |

## EXPERIMENTAL / BETA 群

以下は実験的・ベータのため、フラグ・挙動が version で変わりやすい。利用前に必ず `glab <group> --help` で実機の最新仕様を再確認する。

### glab work-items（EXPERIMENTAL）

ワークアイテムの作成・一覧・更新・削除（`create` / `list` / `update` / `delete`）。issue を包含する新しいオブジェクトモデルを扱う。

### glab stack（EXPERIMENTAL）

スタックドディフ（複数の依存 MR を積み重ねて管理する）。サブコマンド構成は version で変わるため `--help` を確認する。

### glab cluster graph（EXPERIMENTAL）

Kubernetes 向け GitLab Agent のクラスタグラフ表示（`glab cluster graph`）。`glab cluster agent` は安定。

### glab search（BETA）

自然言語によるセマンティックコード検索（semantic search）。

### glab duo cli（Beta）

GitLab Duo（AI アシスタント）の CLI 連携（`glab duo cli`）。

### glab mcp serve（EXPERIMENTAL）

glab を MCP（Model Context Protocol）サーバーとして起動する（`glab mcp serve`）。
