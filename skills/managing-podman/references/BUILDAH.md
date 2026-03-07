# Buildah + マルチステージビルド + CI統合

## 目次

1. [Containerfile/Dockerfileの命令](#1-containerfiledockerfileの命令)
2. [podman buildコマンド](#2-podman-buildコマンド)
3. [Buildah概要](#3-buildah概要)
4. [Buildah CLIコマンド](#4-buildah-cliコマンド)
5. [ビルド戦略](#5-ビルド戦略)
6. [スクラッチからのビルド](#6-スクラッチからのビルド)
7. [CI/CD統合](#7-cicd統合)

---

## 1. Containerfile/Dockerfileの命令

Podmanは`Containerfile`と`Dockerfile`の両方をサポートする（同一構文）。

### レイヤーを生成する命令

`RUN`・`COPY`・`ADD` の3命令のみが新しいファイルシステムレイヤーを生成する。それ以外の命令はメタデータのみを変更し、空レイヤー（`empty_layer: true`）として記録される。

### 命令一覧

| 命令 | 説明 |
|------|------|
| `FROM <image>[:<tag>]` | ベースイメージを指定。マルチステージビルドでは複数のFROMを使用 |
| `RUN <command>` | ビルド時にコマンドを実行。新しいレイヤーを作成 |
| `COPY <src> <dst>` | ビルドコンテキストからファイル/ディレクトリをコピー。`--chown=<user>:<group>`でオーナー設定可 |
| `ADD <src> <dst>` | COPYの拡張版。URLからのダウンロード・tarアーカイブの自動展開に対応 |
| `ENTRYPOINT` | コンテナの実行コマンド（コマンドライン引数で上書き不可） |
| `CMD` | ENTRYPOINTへのデフォルト引数。`podman run`の引数で上書き可能 |
| `LABEL <key>=<value>` | イメージにメタデータラベルを付与 |
| `EXPOSE <port>[/<protocol>]` | リッスンポートの宣言（実際の公開はruntime時に行う） |
| `ENV <key>=<value>` | 環境変数を設定（ビルド時・実行時の両方で有効） |
| `VOLUME <path>` | 実行時にanonymous volumeを自動作成するパスを宣言 |
| `USER <username>[:group]` | 以降のRUN・CMD・ENTRYPOINTを実行するユーザーを設定 |
| `WORKDIR <path>` | 作業ディレクトリを設定（ビルド時・実行時で維持される） |
| `ARG <name>[=<default>]` | ビルド時変数。`--build-arg`で注入可能（実行時には残らない） |
| `ONBUILD <instruction>` | このイメージを親とする子ビルドで実行されるトリガー命令 |

### ENTRYPOINTとCMDの関係

| 設定 | 動作 |
|------|------|
| ENTRYPOINTのみ | ENTRYPOINTが直接実行される |
| CMDのみ | ENTRYPOINTのデフォルトが`bash -c`なので `bash -c "<CMD>"` として実行 |
| 両方設定 | `ENTRYPOINT CMD` の形式で実行 |
| exec形式 | `["command", "arg1"]` — シェルを介さず直接実行（推奨） |
| shell形式 | `command arg1` — `bash -c "command arg1"` として実行 |

### RUNのベストプラクティス

レイヤー数削減のため、複数コマンドを`&&`で連結して1命令にまとめる:

```dockerfile
# 推奨: 1つのRUNで複数コマンドを連結
RUN set -euo pipefail; \
    dnf upgrade -y; \
    dnf install httpd -y; \
    dnf clean all -y; \
    rm -rf /var/cache/dnf/*

# 非推奨: 複数のRUN（各行がレイヤーを生成）
RUN dnf upgrade -y
RUN dnf install httpd -y
RUN dnf clean all -y
```

`set -euo pipefail` を先頭に付けることで、コマンド失敗時にビルドを確実に停止できる。

### Containerfile実例（rootless対応Webサーバー）

```dockerfile
FROM docker.io/library/fedora

# パッケージインストールとキャッシュ削除を1レイヤーで
RUN set -euo pipefail; \
    dnf upgrade -y; \
    dnf install httpd -y; \
    dnf clean all -y; \
    rm -rf /var/cache/dnf/*

# rootless実行のためにポートとログを変更
RUN set -euo pipefail; \
    sed -i 's|Listen 80|Listen 8080|' /etc/httpd/conf/httpd.conf; \
    sed -i 's|ErrorLog "logs/error_log"|ErrorLog /dev/stderr|' \
           /etc/httpd/conf/httpd.conf; \
    sed -i 's|CustomLog "logs/access_log" combined|CustomLog /dev/stdout combined|' \
           /etc/httpd/conf/httpd.conf; \
    chown 1001 /var/run/httpd

COPY index.html /var/www/html
VOLUME /var/www/html
COPY entrypoint.sh /entrypoint.sh
EXPOSE 8080
USER 1001
ENTRYPOINT ["/entrypoint.sh"]
CMD ["httpd"]
```

---

## 2. podman buildコマンド

```bash
# 基本ビルド
$ podman build -t <image-name> .

# Containerfileを明示的に指定
$ podman build -f Containerfile -t myapp .

# タグを複数指定
$ podman build -t myapp:latest -t myapp:v1.0 .

# ビルド引数を注入
$ podman build --build-arg APP_VERSION=1.2.3 -t myapp .

# レイヤーを単一に圧縮（キャッシュなし・キャッシュ共有不可になる）
$ podman build --layers=false -t myapp .

# キャッシュを使わず強制リビルド
$ podman build --no-cache -t myapp .
```

### イメージのレイヤー確認

```bash
# レイヤー一覧
$ podman inspect myapp --format '{{ .RootFS.Layers }}'

# ツリー表示（各レイヤーのサイズ付き）
$ podman image tree myapp

# タグ付け
$ podman tag localhost/myapp quay.io/<user>/myapp:v1.0
```

---

## 3. Buildah概要

**Buildah**（"build-ah"と発音）はPodmanと同チームが開発するOCIイメージビルド専用ツール。

### PodmanとBuildahの関係

- Podmanの`podman build`はBuildahのライブラリを内包している（Goのバイナリに静的リンク）
- Buildahはスタンドアロンのバイナリとしても使用可能
- 両者は同じコンテナストレージ（`containers/storage`ライブラリ）を共有する
- `buildah images` と `podman images` は同じ結果を表示する

### Buildahの優位性

| 特徴 | 説明 |
|------|------|
| **スクリプタブル** | 各Dockerfile命令がCLIコマンドとして独立。シェルスクリプト内での条件分岐・ループが可能 |
| **rootlessビルド** | Unix socketなしでrootlessビルド可能 |
| **直接FSアクセス** | `buildah mount`でコンテナのrootfsをホストにマウントし、ホストのパッケージマネージャーで操作可能 |
| **Dockerfile互換** | `buildah build`コマンドでDockerfile/Containerfileをそのまま使用可能 |
| **CI統合** | コンテナ内でのネストビルドにも対応 |

### Buildahコンテナ vs Podmanコンテナ

| 観点 | Buildahコンテナ | Podmanコンテナ |
|------|----------------|--------------|
| 目的 | 修正してコミットするための一時的な作業コンテナ | 長時間実行するワークロード |
| `podman ps`の表示 | デフォルト非表示（`--external`が必要） | 表示される |
| ライフサイクル | ビルド完了で通常削除 | 必要な期間だけ実行 |

---

## 4. Buildah CLIコマンド

### コアコマンド

| コマンド | 説明 | 例 |
|---------|------|-----|
| `buildah from <image>` | ベースイメージから作業コンテナを作成 | `container=$(buildah from fedora)` |
| `buildah from scratch` | 空の作業コンテナを作成 | `buildah from scratch` |
| `buildah run <ctr> -- <cmd>` | 作業コンテナ内でコマンドを実行（`RUN`相当） | `buildah run $ctr -- dnf install -y nginx` |
| `buildah copy <ctr> <src> <dst>` | ホストからコンテナへファイルをコピー（`COPY`相当） | `buildah copy $ctr ./app /opt/app` |
| `buildah add <ctr> <src> <dst>` | URL・tarを含むコピー（`ADD`相当） | `buildah add $ctr app.tar.gz /opt/` |
| `buildah config [options] <ctr>` | コンテナメタデータを設定（`ENV`/`ENTRYPOINT`等相当） | `buildah config --cmd "/start.sh" $ctr` |
| `buildah commit <ctr> <image>` | 作業コンテナを最終イメージとしてコミット | `buildah commit $ctr myapp:v1.0` |
| `buildah rm <ctr>` | 作業コンテナを削除 | `buildah rm $ctr` |

### 情報・イメージ管理

| コマンド | 説明 |
|---------|------|
| `buildah containers` / `buildah ls` | アクティブな作業コンテナ一覧 |
| `buildah images` / `buildah images --json` | ローカルイメージ一覧（JSON出力対応） |
| `buildah tag <name> <new-name>` | イメージにタグを付与 |
| `buildah push <image> [dest]` | レジストリやローカルディレクトリへpush |
| `buildah pull <image>` | イメージのpull |
| `buildah build -t <name> .` | Dockerfile/Containerfileからビルド（`buildah bud`はエイリアス） |

### mountコマンド（Buildahの秘密兵器）

`buildah mount`で作業コンテナのrootfsをホストのパスにマウントし、ホスト上のツールで直接操作できる:

```bash
# マウント（マウントパスを返す）
$ buildah mount $container
/var/lib/containers/storage/overlay/<id>/merged

# パスを変数に格納してホストのdnfで操作
$ scratchmount=$(buildah mount $container)
$ dnf install --installroot $scratchmount --releasever 40 bash coreutils -y

# アンマウント
$ buildah unmount $container
```

rootlessモードでは`podman unshare`シェル内で操作する必要がある（namespace分離のため）。

### configコマンドのオプション

```bash
buildah config \
  --cmd "/usr/bin/myapp"          \  # CMD相当
  --entrypoint "/entrypoint.sh"   \  # ENTRYPOINT相当
  --env KEY=VALUE                 \  # ENV相当
  --port 8080                     \  # EXPOSE相当
  --user 1001                     \  # USER相当
  --label name=myapp              \  # LABEL相当
  --created-by "My Build System"  \  # 作成者情報
  $container
```

---

## 5. ビルド戦略

Buildahには3つのビルド戦略がある:

### 戦略1: 既存ベースイメージから

```bash
container=$(buildah from fedora)
buildah run $container -- dnf install -y httpd; dnf clean all
buildah config --cmd "httpd -DFOREGROUND" $container
buildah config --port 80 $container
buildah commit $container myhttpd
buildah tag myhttpd registry.example.com/myhttpd:v0.0.1
buildah rm $container
```

### 戦略2: スクラッチから（次セクション参照）

```bash
container=$(buildah from scratch)
# mountしてホストのパッケージマネージャーで操作...
```

### 戦略3: Dockerfileから

```bash
buildah build -f Dockerfile -t myhttpdservice .
# または
buildah bud -t myhttpdservice .
```

---

## 6. スクラッチからのビルド

スクラッチビルドは、完全に空のコンテナに必要なバイナリのみを追加することで、攻撃面を最小化した最小イメージを作成できる。

```bash
# 空のコンテナを作成
# buildah from scratch
container=$(buildah from scratch)

# buildah containers で確認（IMAGE IDなし、IMAGE NAMEは"scratch"）
# buildah containers
# af69b9547db9  *  (IMAGE ID)  scratch  working-container

# コンテナのrootfsをホストにマウント
scratchmount=$(buildah mount $container)

# ホストのdnfでコンテナのrootfsにパッケージをインストール
dnf install --installroot $scratchmount \
  --releasever 40 \
  bash coreutils \
  --setopt install_weak_deps=false -y

# アンマウント
buildah unmount $container

# ファイルをコピー
buildah copy $container ./command.sh /usr/bin/command.sh

# メタデータを設定
buildah config --cmd /usr/bin/command.sh $container
buildah config --created-by "My Build System" $container
buildah config --label name=myapp $container

# イメージとしてコミット
buildah commit $container myapp:latest

# 作業コンテナを削除
buildah rm $container
```

### スクラッチビルドの検証

```bash
# スクラッチから作ったため、IMAGE IDがない状態でbashが動く
# buildah run working-container bash
# → "executable file `bash` not found" （インストール前）
# → bash起動成功 （インストール後）

# podmanで実行確認
podman run -ti localhost/myapp:latest
```

---

## 7. CI/CD統合

### レイヤーキャッシュ戦略

| 設定 | `--layers` | メリット | デメリット |
|------|-----------|---------|----------|
| 多レイヤー維持 | `true` | 再ビルド高速・レイヤー共有でディスク節約 | FSのマージオーバーヘッド |
| 単一レイヤー | `false`（デフォルト） | シンプル・小さなFSオーバーヘッド | 毎回フルビルド |

```bash
# レイヤーキャッシュを有効化（環境変数でも設定可能）
export BUILDAH_LAYERS=true
buildah build -t myapp .

# または--layersオプションで明示
buildah build --layers -t myapp .
```

### CI環境での実行

BuildahはDockerデーモン不要でコンテナ内でも動作するため、様々なCI環境と統合できる:

| CI/CDツール | 統合方法 |
|------------|---------|
| **Jenkins** | Buildahをインストールしたエージェント or コンテナビルドステップ |
| **GitLab CI/CD** | `buildah build`をビルドステップで使用（DinD不要） |
| **Tekton** | Tekton Hub の Buildah task (`hub.tekton.dev/tekton/task/buildah`) |
| **Ansible** | Buildah connection pluginを使用した自動化ビルド |
| **Shipwright** | Kubernetes上のBuildahビルド（build.shipwright.io） |

### Tekton Hub のBuildah taskを使用する例

```yaml
# Tekton Pipeline内でBuildahを使用
apiVersion: tekton.dev/v1beta1
kind: Pipeline
spec:
  tasks:
  - name: build-image
    taskRef:
      name: buildah
      kind: Task
    params:
    - name: IMAGE
      value: quay.io/myorg/myapp:$(params.tag)
    - name: CONTEXT
      value: .
```

### rootlessビルドのセキュリティ上の利点

Dockerビルドと異なり、PodmanとBuildahはrootlessモードでビルドを実行できる:

```bash
# 非特権ユーザーとしてビルド（rootなし）
$ whoami
developer
$ podman build -t myapp .
$ buildah build -t myapp .
```

これにより:
- CIランナーをrootで動かす必要がない
- `/var/run/docker.sock`のような特権ソケットが不要
- コンテナエスケープのリスクが低減する

---

## 関連参照

| トピック | 参照先 |
|---------|--------|
| コンテナ操作コマンド | [CONTAINERS.md](CONTAINERS.md) |
| ストレージ（COW構造） | [STORAGE.md](STORAGE.md) |
| アーキテクチャ | [ARCHITECTURE.md](ARCHITECTURE.md) |
| セキュリティ・rootless | [INSTRUCTIONS.md](../INSTRUCTIONS.md) |
