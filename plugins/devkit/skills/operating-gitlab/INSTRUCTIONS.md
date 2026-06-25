# operating-gitlab 実装ガイド

`glab`（GitLab 公式 CLI）でターミナルから GitLab を操作するための権威ある早見表とワークフロー集。コマンド構文はすべて glab v1.102.0 で裏取り済み。推測でコマンドを組まず、本スキルの早見表と `references/` に従う。

## 1. glab とは / 前提確認

`glab` は GitLab が公式に提供するコマンドラインツール。マージリクエスト・issue・CI/CD パイプライン・release・REST/GraphQL API など、GitLab のほぼ全機能をターミナルから操作できる。

導入確認は次のコマンドで行う。

```bash
# glab が導入済みか・バージョンを確認
glab version
```

未導入の場合は OS に応じて導入する。

| OS / 環境 | 導入コマンド |
|-----------|-------------|
| macOS（Homebrew） | `brew install glab` |
| Linux（Homebrew） | `brew install glab` |
| Windows（winget） | `winget install -e --id GitLab.GLab` |
| Windows（Scoop） | `scoop install glab` |
| その他 | パッケージマネージャ未対応なら GitLab 公式の配布バイナリを取得 |

導入後は認証が必要。認証手順は本書 3 章および `references/AUTH-SETUP.md` を参照。

## 2. コマンド実行の鉄則

1. **構文を推測しない**。コマンド・サブコマンド・フラグは必ず本スキルの早見表 / `references/` どおりに組む。記載のないフラグやサブコマンドが必要なときは `glab <group> <sub> --help` で実機確認してから使う。
2. **対象を明示する**。可能な限り `-R OWNER/REPO` を付け、操作対象のプロジェクトを曖昧にしない。カレントディレクトリの Git remote から自動検出させるより、明示したほうが事故が起きにくい。
3. **参照系・作成系は非対話フラグで自動化してよい**。非破壊・冪等な参照系（`list` / `view` / `diff` / `status` / `get` / `lint` 等）と、新規作成系（`mr create` / `issue create` 等）は、`-y` / `--yes` / `--fill` などの非対話フラグで人手プロンプトを省略してよい。
4. **破壊的・不可逆な操作で `-y` / `--yes` を使ってはならない**。鉄則③とは別ルールとして厳守する。破壊的操作は実行前に対象（ID・リポジトリ・影響範囲）を明示提示し、ユーザー（本体経由）の明示承認を得てから実行する。タチコマは破壊的操作を独断で実行しない。破壊的操作の例: `mr merge`・`mr delete`・`mr close`・`issue close`・`issue delete`・`repo delete`・`release delete`・`token revoke`・`token rotate`・`variable delete`・`schedule delete`・`runner delete`・`securefile remove`・`ssh-key` / `gpg-key` / `deploy-key` の `delete`・破壊的な `glab api`（`--method DELETE` / `PUT` / `POST` 等の書込・削除呼び出し）。
5. **副作用を伴う即時実行系はユーザー承認を得てから実行する**。`ci run` / `ci trigger` / `schedule run` は参照系ではなく副作用（パイプライン起動・外部トリガー）を伴う。本番・protected 環境やデプロイ変数を伴う場合は、鉄則③の自動化（`-y`）対象から除外し、対象環境・ブランチ・変数の内容をユーザーに提示して承認を得てから実行する。

## 3. 認証早見

接続先により認証フローが分岐する。詳細・全フラグは `references/AUTH-SETUP.md` を参照。

| 接続先 | 主なコマンド / 設定 | 要点 |
|--------|--------------------|------|
| gitlab.com | `glab auth login` | Git remote から GitLab インスタンスを自動検出して対話ログイン |
| self-managed / Dedicated | `glab auth login --hostname <host>` | 自前ホストを明示。`--api-host` / `--api-protocol` も指定可 |
| CI 環境 | `CI_JOB_TOKEN` を利用 | `GLAB_ENABLE_CI_AUTOLOGIN=true` で自動ログイン、または `--job-token $CI_JOB_TOKEN` |

環境変数 `GITLAB_TOKEN` は保存済み資格情報より優先される。トークンはログ・コミットに残さず、環境変数または keyring 経由で扱う。

## 4. コマンドグループ早見表

glab v1.102.0 の全コマンドグループ。EXPERIMENTAL / BETA は将来仕様変更があり得るため明示する。

| グループ | 役割 | 代表サブコマンド | status |
|---------|------|----------------|--------|
| `auth` | 認証管理 | `login` / `logout` / `status` / `configure-docker` / `docker-helper` / `dpop-gen`（EXPERIMENTAL） | 安定 |
| `mr` | マージリクエスト | `create` / `list` / `view` / `diff` / `approve` / `merge` / `rebase` / `note` / `checkout` / `update` / `close` / `reopen` | 安定 |
| `issue` | issue | `create` / `list` / `view` / `note` / `update` / `close` / `reopen` / `delete` / `subscribe` / `board` | 安定 |
| `incident` | インシデント | `list` / `view` / `note` / `close` / `reopen` / `subscribe` / `unsubscribe` | 安定 |
| `ci` | CI/CD パイプライン・ジョブ | `run` / `list` / `get` / `status` / `view` / `trace` / `lint` / `retry` / `cancel` / `trigger` / `artifact` / `config compile` / `delete` | 安定 |
| `job` | ジョブのアーティファクト取得 | `artifact`（最新パイプラインの成果物取得） | 安定 |
| `schedule` | パイプラインスケジュール | `create` / `list` / `update` / `delete` / `run` | 安定 |
| `variable` | CI/CD 変数 | `set` / `get` / `list` / `update` / `delete` / `export`（project / group・masked / protected） | 安定 |
| `repo` | プロジェクト | `clone` / `create` / `fork` / `view` / `list` / `search` / `contributors` / `archive` / `mirror` / `transfer` / `update` / `delete` / `members` | 安定 |
| `release` | リリース | `create` / `list` / `view` / `upload` / `download` / `delete` | 安定 |
| `snippet` | スニペット | `create`（project / personal） | 安定 |
| `label` | ラベル | `create` / `list` / `edit` / `delete` / `get` | 安定 |
| `milestone` | マイルストーン | `create` / `list` / `edit` / `delete` / `get` | 安定 |
| `api` | 認証付き REST / GraphQL 呼び出し | プレースホルダ展開・`--method` / `--field` / `--raw-field` / `--paginate` | 安定 |
| `ssh-key` / `gpg-key` / `deploy-key` | 鍵管理 | `add` / `get` / `list` / `delete` | 安定 |
| `runner` | CI/CD ランナー | `list` / `assign` / `unassign` / `update` / `delete` / `jobs` / `managers` | 安定 |
| `securefile` | セキュアファイル | `create` / `download` / `get` / `list` / `remove` | 安定 |
| `token` | アクセストークン | `create` / `list` / `revoke` / `rotate`（user / project / group） | 安定 |
| `iteration` | イテレーション | `list` | 安定 |
| `todo` | To-Do リスト | `list` / `done` | 安定 |
| `user` | ユーザー情報 | `events` | 安定 |
| `changelog` | チェンジログ生成 | `generate` | 安定 |
| `config` | glab 設定 | `get` / `set` / `edit`（host / token / editor / browser / glab_pager / glamour_style） | 安定 |
| `alias` | コマンドエイリアス | `set` / `list` / `delete` | 安定 |
| `cluster` | Kubernetes 向け GitLab Agent | `agent` / `graph`（graph は EXPERIMENTAL） | 一部 EXPERIMENTAL |
| `search` | コード検索（自然言語） | semantic（BETA） | BETA |
| `work-items` | ワークアイテム | `create` / `list` / `update` / `delete`（EXPERIMENTAL） | EXPERIMENTAL |
| `stack` | スタックドディフ | （EXPERIMENTAL） | EXPERIMENTAL |
| `duo` | GitLab Duo | `cli`（Beta） | Beta |
| `mcp` | MCP サーバー | `serve`（EXPERIMENTAL） | EXPERIMENTAL |

> **注意**: `container-registry` というトップレベルコマンドは存在しない。コンテナレジストリの Docker 資格情報は `glab auth configure-docker` / `glab auth docker-helper` で扱う。また `pipe` / `pipeline` エイリアスは deprecated なので `ci` に統一する。

## 5. 主要ワークフロー要約

代表的な end-to-end フロー。各コマンドの詳細フラグと完全な手順は `references/WORKFLOWS.md` を参照。

- **MR ライフサイクル**: ブランチを作成し `mr create --fill --draft` で起票 → `mr update` で draft 解除 → `mr approve` でレビュー承認 → 確認のうえ `mr merge`。`mr merge` は破壊的操作なので `-y` を付けず、対象 MR と squash / ブランチ削除フラグの影響を提示し、承認後に実行する。
- **CI 実行 → トレース**: `ci run -b <branch>`（必要なら変数を付与）でパイプライン起動 → `ci status` で状態確認 → `ci trace <job>` でジョブログをリアルタイム追跡 → 失敗時は `ci retry` で再実行、または `ci artifact` / `job artifact` で成果物を取得。
- **issue 起票 → クローズ**: `issue create -t <title> -l <label> -a <assignee>` で起票 → `issue note` で進捗を追記 → 完了後に `issue close`（または MR 本文の `Closes #N` で自動クローズ）。
- **release 作成**: タグを前提に `release create <tag> <files...> --notes "..."` でリリース発行 → `release view <tag>` で内容を確認。アセットは `release upload` で追加できる。

## 6. references ナビゲーション

知りたい内容に応じて参照ファイルを選ぶ。

| 知りたいこと | 参照ファイル |
|-------------|-------------|
| 認証・接続・glab 設定・トークン管理（self-managed / CI / 環境変数 / `config` / `token`） | `references/AUTH-SETUP.md` |
| MR のサブコマンド・フラグを見たい（`mr create` / `merge` / `approve` 等） | `references/COMMANDS-MR.md` |
| issue / incident / CI / job / schedule / variable のコマンド | `references/COMMANDS-ISSUE-CI.md` |
| repo / release / snippet / label / milestone のコマンド | `references/COMMANDS-REPO-RELEASE.md` |
| `api`（REST / GraphQL）・鍵管理・runner / securefile・その他グループ | `references/COMMANDS-API-MISC.md` |
| end-to-end ワークフローの具体手順（MR / CI / issue / release / 変数投入） | `references/WORKFLOWS.md` |

## 7. 棲み分け

- **GitHub の操作**: 本スキルは GitLab 専用。GitHub では `gh` CLI と `pull-request` コマンドを使う。
- **コミットメッセージの文言**: `writing-conventional-commits` を使う。
- **コードレビューの方法論**: `reviewing-code` を使う（本スキルはあくまで glab のコマンド操作を扱う）。
