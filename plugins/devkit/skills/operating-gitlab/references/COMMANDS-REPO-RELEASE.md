# glab コマンドリファレンス: repo / release / snippet / label / milestone

プロジェクト管理・リリース発行・スニペット・ラベル・マイルストーンのサブコマンドとフラグ早見表。構文は glab v1.102.0 で裏取り済み。プレースホルダは `<id>`・`<tag>`・`<branch>`・`OWNER/REPO` 等の山括弧表記で統一する。各サブコマンドは `-R OWNER/REPO` で対象リポジトリを明示できる。

> **🔴 破壊的操作の注意**: `repo delete`・`repo transfer`・`repo archive`・`release delete` は不可逆または影響が大きい。`-y`/`--yes` での自動承認を禁止する。実行前に対象（ID・リポジトリ・影響範囲）を提示し、明示承認を得てから実行すること。

## repo

GitLab プロジェクトの作成・複製・フォーク・閲覧・設定管理。

### repo clone

```bash
# 単一リポジトリを複製
glab repo clone OWNER/REPO

# 複製先ディレクトリを指定
glab repo clone OWNER/REPO ./local-dir

# グループ配下の全プロジェクトを複製
glab repo clone -g <group>

# git のフラグを `--` 以降に渡す（例: 浅いクローン）
glab repo clone OWNER/REPO -- --depth 1
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--group` | `-g` | グループ配下の全プロジェクトを複製 |
| `--repo` | `-R` | 対象リポジトリを明示 |

### repo create

```bash
# 現在のユーザー名前空間に private プロジェクトを作成
glab repo create -n my-project --private

# グループ配下に README 付きで作成
glab repo create -n my-project -g <group> --readme --description "説明文"
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--name` | `-n` | プロジェクト名 |
| `--group` | `-g` | 作成先の名前空間・グループ |
| `--private` | `-p` | private（メンバーのみ可視） |
| `--public` | `-P` | public（認証不要で可視）。未認証者に公開する不可逆な転換点のため、明示的な要件があるときのみ使用する。 |
| `--internal` | | internal（認証ユーザーに可視・既定） |
| `--description` | `-d` | プロジェクトの説明 |
| `--readme` | | `README.md` で初期化し作成後にローカル複製 |
| `--defaultBranch` | | 既定ブランチ名を上書き |
| `--tag` | `-t` | プロジェクトのタグ一覧 |

### repo fork

```bash
# リポジトリをフォーク
glab repo fork OWNER/REPO
```

### repo view

```bash
# プロジェクト概要を表示
glab repo view OWNER/REPO

# 現在のリポジトリを表示
glab repo view
```

### repo list

```bash
# 自分がアクセスできるプロジェクト一覧
glab repo list
```

### repo search

```bash
# 名前でプロジェクトを検索
glab repo search <query>
```

### repo contributors

```bash
# コントリビューター一覧を取得
glab repo contributors -R OWNER/REPO
```

### repo archive（🔴 影響大）

リポジトリのアーカイブ（読み取り専用化）またはソースアーカイブ取得を扱う。詳細なサブコマンドは `glab repo archive --help` を参照。アーカイブはプロジェクトを読み取り専用にするため、実行前に対象を提示し承認を得る。

### repo mirror

```bash
# 既存プロジェクトにミラーリングを設定
glab repo mirror <id|url|path>
```

### repo transfer（🔴 不可逆）

```bash
# プロジェクトを別の名前空間へ移管（確認後に実行）
glab repo transfer <repo> --target-namespace <namespace>
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--target-namespace` | `-t` | 移管先の名前空間 |
| `--yes` | `-y` | 確認プロンプトをスキップ（移管は取り消し不可・🔴 自動付与禁止） |

### repo update

```bash
# プロジェクト設定を更新
glab repo update -R OWNER/REPO --description "新しい説明"
```

設定可能な項目は `glab repo update --help` を参照。

### repo delete（🔴 不可逆）

```bash
# プロジェクトを削除（確認後に実行）
glab repo delete <NAME>
```

削除は取り消せない。対象プロジェクトを明示提示し、ユーザー承認後にのみ実行する。`-y` は自動付与しない。

### repo prune

```bash
# マージ済み MR に対応するローカルブランチを削除
glab repo prune
```

### repo members

```bash
# プロジェクトメンバーを管理（サブコマンドは --help 参照）
glab repo members -R OWNER/REPO
```

### repo remote

```bash
# GitLab プロジェクトの Git リモートを管理
glab repo remote
```

### repo publish catalog

```bash
# プロジェクトのリソースを CI/CD カタログへ公開
glab repo publish catalog
```

詳細は `glab repo publish catalog --help` を参照。

## release

GitLab リリースの作成・閲覧・アセット添付。Developer ロール以上が必要。

### release create

```bash
# タグからリリースを作成し、リリースノートを付与
glab release create v1.0.1 --notes "バグ修正リリース"

# リリースノートをファイルから読み込む
glab release create v1.0.1 -F changelog.md

# ディレクトリ内の全ファイルをアセットとして添付
glab release create v1.0.1 ./dist/*

# アセットに表示名と種別を付ける（パス#表示名#種別）
glab release create v1.0.1 '/path/to/asset.png#リリース成果物#image'

# タグが存在しない場合、ref からタグを作成してリリース
glab release create v1.0.1 ./dist/* --ref main --notes "初回リリース"
```

`glab release create <tag> [<files>...]` の形式。タグが存在しない場合、指定 `ref`（既定はデフォルトブランチ最新）からタグを作成する。

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--notes` | `-N` | リリースノート本文（Markdown 可） |
| `--notes-file` | `-F` | リリースノートをファイルから読み込む（`-` で標準入力） |
| `--name` | `-n` | リリース名・タイトル |
| `--ref` | `-r` | タグ未存在時に基にする commit SHA・タグ名・ブランチ名 |
| `--milestone` | `-m` | 紐づけるマイルストーンのタイトル（カンマ区切り可） |
| `--assets-links` | `-a` | アセットリンクの JSON 文字列 |
| `--released-at` | `-D` | リリース日時（ISO 8601） |
| `--tag-message` | `-T` | 注釈付きタグ新規作成時のメッセージ |
| `--no-update` | | 既存リリースの更新を抑止 |
| `--repo` | `-R` | 対象リポジトリを明示 |

### release list

```bash
# リリース一覧を表示
glab release list -R OWNER/REPO
```

### release view

```bash
# 特定タグのリリース詳細を表示
glab release view v1.0.1
```

### release upload

```bash
# 既存リリースにアセットを追加アップロード
glab release upload v1.0.1 ./dist/app.zip
```

`glab release upload <tag> [<files>...]` の形式。

### release download

```bash
# リリースのアセットをダウンロード
glab release download v1.0.1
```

`glab release download <tag>` の形式。

### release delete（🔴 破壊的）

```bash
# リリースを削除（確認後に実行）
glab release delete v1.0.1
```

削除は取り消せない。対象タグを明示提示し承認後にのみ実行する。`-y` は自動付与しない。

## snippet

### snippet create

```bash
# ファイルからプロジェクトスニペットを作成
glab snippet create script.py --title "スニペットのタイトル"

# 標準入力から作成（--filename でファイル名を指定）
echo "package main" | glab snippet create -t "サンプル" -f "main.go"

# 個人スニペットとして作成
glab snippet create --personal --title "個人メモ" script.py
```

1つ以上のファイルパスを渡すか、`--filename` を指定して標準入力から内容をパイプする。

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--title` | `-t` | スニペットのタイトル（必須） |
| `--filename` | `-f` | GitLab 上のファイル名（標準入力時に使用） |
| `--description` | `-d` | スニペットの説明（`-` でエディタを開く） |
| `--personal` | `-p` | 個人スニペットとして作成（既定はプロジェクト） |
| `--visibility` | `-v` | 可視性（`public` / `internal` / `private`・既定 `private`）。`public` は未認証者に公開するため、明示的な要件があるときのみ指定する。 |
| `--repo` | `-R` | 対象リポジトリを明示 |

## label

プロジェクト・グループのラベル管理。サブコマンド: `create` / `list` / `edit` / `delete` / `get`。

### label create

```bash
# 現在のリポジトリにラベルを作成
glab label create --name bug --color "#FF0000" --description "不具合"

# 別プロジェクトにラベルを作成
glab label create --name bug -R OWNER/REPO
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--name` | `-n` | ラベル名 |
| `--color` | `-c` | ラベル色（プレーンまたは HEX・既定 `#428BCA`） |
| `--description` | `-d` | ラベルの説明 |
| `--priority` | `-p` | ラベルの優先度 |
| `--repo` | `-R` | 対象リポジトリを明示 |

### label list

```bash
# プロジェクトまたはグループのラベル一覧
glab label list -R OWNER/REPO
```

### label edit

```bash
# ラベルを編集
glab label edit -R OWNER/REPO
```

設定可能な項目は `glab label edit --help` を参照。

### label get

```bash
# ラベル ID で単一ラベルの情報を取得
glab label get <label-id>
```

### label delete（🔴 破壊的）

```bash
# ラベルを削除（確認後に実行）
glab label delete <name>
```

## milestone

プロジェクト・グループのマイルストーン管理。サブコマンド: `create` / `list` / `edit` / `delete` / `get`。`--project` と `--group` は排他で、既定はカレントプロジェクト。

### milestone create

```bash
# 現在のプロジェクトにマイルストーンを作成
glab milestone create --title='リリース計画' --due-date='2025-12-16'

# グループレベルのマイルストーンを作成
glab milestone create --title='FY26 計画' --due-date='2026-01-31' --group <group-id>
```

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--title` | | マイルストーンのタイトル |
| `--description` | | マイルストーンの説明 |
| `--due-date` | | 期限（ISO 8601 形式） |
| `--start-date` | | 開始日（ISO 8601 形式） |
| `--group` | | グループの ID または URL エンコードパス |
| `--project` | | プロジェクトの ID または URL エンコードパス |
| `--repo` | `-R` | 対象リポジトリを明示 |

### milestone list

```bash
# プロジェクトまたはグループのマイルストーン一覧
glab milestone list -R OWNER/REPO
```

### milestone edit

```bash
# マイルストーンを編集
glab milestone edit <id>
```

### milestone get

```bash
# マイルストーン ID で情報を取得
glab milestone get <id>
```

### milestone delete（🔴 破壊的）

```bash
# マイルストーンを削除（確認後に実行）
glab milestone delete <id>
```
