# Docker → Podman 移行ガイド

Docker から Podman への移行に必要なコマンド対応表、互換性の注意点、Compose連携を提供する。

---

## CLI互換性の活用

PodmanはDockerのCLIと完全互換を目指して設計されている。最も手軽な移行方法は `alias` を設定することだ。

```bash
# シェルエイリアスで即座にDockerコマンドをPodmanに転送
alias docker=podman
```

より恒久的な方法として、`podman-docker` パッケージのインストールがある。これは `/usr/bin/docker` スクリプトをインストールし、`man docker` の参照先もPodmanのmanページに向ける：

```bash
# Fedora/RHEL系
sudo dnf install podman-docker

# インストールされるスクリプトの内容
$ cat /usr/bin/docker
#!/usr/bin/sh
[ -e /etc/containers/nodocker ] || \
  [ -e "${XDG_CONFIG_HOME-$HOME/.config}/containers/nodocker" ] || \
  echo "Emulate Docker CLI using podman. ..." >&2
exec /usr/bin/podman "$@"
```

エミュレーションメッセージを抑制したい場合は以下のいずれかを作成する：
- `/etc/containers/nodocker`（システム全体）
- `~/.config/containers/nodocker`（ユーザー単位）

---

## イメージ・コンテナの移行

Docker から Podman へのコンテナ直接移行はサポートされていない。推奨手順：

| 状況 | 手順 |
|------|------|
| コンテナレジストリ使用中 | `podman pull` で再取得（移行不要） |
| ローカルイメージのみ | `docker export` → tarball → `podman import` |
| データ永続化 | ボリュームを再アタッチしてコンテナを再作成 |

```bash
# Dockerからイメージをエクスポート
docker export <container_id> > myapp.tar

# Podmanにインポート
podman import myapp.tar myapp:latest
```

---

## コマンド対応表

### 互換コマンド（直接置換可能）

| Docker コマンド | Podman コマンド |
|----------------|----------------|
| `docker` | `podman` |
| `docker ps` | `podman ps` |
| `docker pull` | `podman pull` |
| `docker push` | `podman push` |
| `docker run` | `podman run` |
| `docker rm` | `podman rm` |
| `docker rmi` | `podman rmi` |
| `docker rename` | `podman rename` |
| `docker restart` | `podman restart` |
| `docker images` | `podman images` |
| `docker build` | `podman build`（Buildah経由） |
| `docker exec` | `podman exec` |
| `docker inspect` | `podman inspect` |
| `docker logs` | `podman logs` |
| `docker stop` | `podman stop` |
| `docker network` | `podman network` |
| `docker volume` | `podman volume` |

---

## 挙動の差異（要注意）

DockerとPodmanではアーキテクチャの違いから、同名コマンドでも挙動が異なる場合がある：

| コマンド | Docker の挙動 | Podman の挙動 |
|---------|--------------|--------------|
| `volume create`（既存名） | 冪等（スキップ） | エラー終了 |
| `run -v /tmp/noexist:/tmp` | ホスト側ディレクトリを自動作成 | エラー終了（パスが存在しない） |
| `run --restart always` | デーモンがOS起動後も管理 | `podman-restart.service` が必要 |

### `--restart` の永続化

rootlessコンテナでのrestart後の自動起動には systemd サービスを有効化する：

```bash
# rootful（システム全体）
sudo systemctl enable --now podman-restart.service

# rootless（ユーザー単位）
systemctl --user enable --now podman-restart.service
```

---

## Podmanにない Docker コマンド

| コマンド | 状況・代替手段 |
|---------|--------------|
| `docker plugin` | Podmanはプラグイン非対応。OCI runtimeフックで代替 |
| `docker swarm` | Podmanは非対応。Kubernetesへの移行を推奨 |
| `docker trust` | `podman image trust` に対応機能あり |

---

## PodmanにはないDockerコマンド（Podman固有機能）

これらはPodmanの追加価値となるコマンド群：

| コマンド | 説明 |
|---------|------|
| `podman generate` | コンテナ/Pod/VolumeのYAML等を生成 |
| `podman healthcheck` | ヘルスチェックのサブコマンド群 |
| `podman machine` | macOS/Windows用仮想マシン管理 |
| `podman mount` | コンテナのrootファイルシステムをホストにマウント |
| `podman play` | YAML（Kubernetes形式）からコンテナ/Podを起動 |
| `podman pod` | Podの管理サブコマンド群 |
| `podman unmount` | マウント解除 |
| `podman unshare` | ユーザーnamespace内でプロセスを起動（rootless用） |
| `podman untag` | イメージのタグ削除 |
| `podman kube` | Kubernetes YAML生成/実行 |
| `podman volume export/import` | ボリューム内容のtarball出力/入力 |

---

## Docker Compose との連携

### 選択肢の整理

Docker Compose との連携には2つのアプローチがある：

| アプローチ | 推奨度 | 説明 |
|-----------|--------|------|
| **公式docker-compose（Go版）** | 推奨 | Podman 3.0+のUnixソケット経由で動作 |
| **podman-compose** | 代替 | コミュニティ管理のPython製ツール |

### 公式 docker-compose + Podman ソケット（推奨）

Podman 3.0以降、DockerのUnixソケット互換APIが搭載されたため、公式の `docker-compose`（Go版）がPodmanに直接対話できるようになった。

**rootless 環境でのセットアップ：**

```bash
# Podman のユーザーソケットを起動
systemctl --user enable --now podman.socket

# ソケットパスを環境変数に設定
export DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock

# 通常通り docker-compose を実行
docker-compose up -d
```

**rootful 環境でのセットアップ：**

```bash
# システムソケットを起動
sudo systemctl enable --now podman.socket

# docker-compose を実行（ソケットが /run/podman/podman.sock）
sudo docker-compose up -d
```

### podman-compose（代替手段）

コミュニティ管理のPython製ツール。Podman APIに直接呼び出す：

```bash
pip install podman-compose

# 使用方法
podman-compose up -d
podman-compose down
```

> **注意**: podman-composeはPodman開発チームが公式にメンテナンスしているツールではない。

### Compose ファイルの例

```yaml
# docker-compose.yaml の基本例
services:
  db:
    image: docker.io/library/mysql:latest
    volumes:
      - db_data:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=secret
      - MYSQL_DATABASE=myapp
  web:
    image: docker.io/library/wordpress:latest
    ports:
      - "8080:80"
    depends_on:
      - db
volumes:
  db_data:
```

### 主要な Compose ファイルオプション

| キー | 説明 |
|------|------|
| `image` | 使用するコンテナイメージ |
| `build` | ビルドコンテキスト（Dockerfileパス） |
| `ports` | ホスト:コンテナのポートマッピング |
| `volumes` | ボリュームのマウント設定 |
| `environment` | 環境変数リスト |
| `depends_on` | サービス起動順序の依存関係 |
| `restart` | 再起動ポリシー |
| `expose` | コンテナ内部で公開するポート |

---

## 判断フロー：アプローチの選択

```
Docker から Podman への移行を検討？
    ↓
既存の docker-compose.yml があるか？
    │
    ├── ある → Podman 3.0+ のソケットで docker-compose を使用（推奨）
    │          環境変数 DOCKER_HOST でソケットを指定
    │
    └── ない → Quadlet（systemd統合）を検討
               → [SYSTEMD-KUBERNETES.md] 参照
```

### ユーザー確認（AskUserQuestion）

移行方針を決定する前に確認すべき事項：

- 本番環境で Docker Swarm を使用しているか？（→ Kubernetes移行が必要）
- rootless コンテナが要件か？（→ ソケット設定手順が異なる）
- 既存の docker-compose.yml の互換性テストを実施したか？
