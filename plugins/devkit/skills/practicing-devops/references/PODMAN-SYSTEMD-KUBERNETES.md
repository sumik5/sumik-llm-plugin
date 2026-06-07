# systemd統合とKubernetes連携

Podmanとsystemdの統合（Quadlet）、Kubernetes YAMLの生成と実行について解説する。

---

## systemd統合の基本

systemdはLinuxの標準サービスマネージャー（PID 1）。コンテナをsystemdサービスとして管理することで：

- OS起動時の自動起動
- `systemctl start/stop/restart` による統一管理
- ヘルスチェック・依存関係の自動制御
- `journald` によるログ集約

```bash
# systemd状態確認
systemctl is-system-running
# → running

# サービス一覧確認
systemctl list-units --type=service | head
```

---

## Quadlet：推奨のsystemd統合方法

### 非推奨になったアプローチ

`podman generate systemd` コマンドは**非推奨（deprecated）**。静的なunit fileを生成する方式は、Podmanのバージョンアップに追従できない問題があったため廃止された。

### Quadletとは

Quadletは宣言的な設定ファイル（`.container`、`.volume`等）を定義すると、systemdのgeneratorが起動時に自動でunit fileを生成する仕組み。

**ファイル配置場所：**

| スコープ | ディレクトリ |
|---------|------------|
| システム全体（root） | `/etc/containers/systemd/` |
| ユーザー単位（rootless） | `~/.config/containers/systemd/` |

**Quadletファイルの拡張子：**

| 拡張子 | 対象 |
|--------|------|
| `.container` | コンテナ定義 |
| `.volume` | Podmanボリューム |
| `.network` | Podmanネットワーク |
| `.pod` | Podmanポッド |
| `.kube` | Kubernetes YAMLファイル |

---

## Quadletファイルの作成

### podlet ツール（推奨）

`podlet` は `podman run` コマンドを Quadlet 形式に変換する便利ツール：

```bash
# インストール（Fedora）
dnf install -y podlet

# 変換例：podman run コマンドの先頭に podlet を追加するだけ
podlet podman run -d \
  --network host \
  --name mariadb \
  -v /opt/var/lib/mariadb:/var/lib/mysql:Z \
  -e MARIADB_DATABASE=myapp \
  -e MARIADB_USER=myapp \
  --secret=MARIADB_PASSWORD,type=env \
  docker.io/mariadb:latest
```

出力例：

```ini
# mariadb.container
[Container]
ContainerName=mariadb
Environment=MARIADB_DATABASE=myapp MARIADB_USER=myapp
Image=docker.io/mariadb:latest
Network=host
Secret=MARIADB_PASSWORD,type=env
Volume=/opt/var/lib/mariadb:/var/lib/mysql:Z
```

### .container ファイルの構造

```ini
# gitea.container（依存関係あり）
[Unit]
Description=Gitea Git Service
Requires=mariadb.service

[Container]
ContainerName=gitea
Image=docker.io/gitea/gitea:latest-rootless
Network=host
Volume=/opt/var/lib/gitea/data:/data:Z

[Install]
# OS起動時に自動起動
WantedBy=multi-user.target default.target
```

**主要なセクション：**

| セクション | 役割 |
|-----------|------|
| `[Unit]` | 標準systemdメタデータ（Description, Requires, After等） |
| `[Container]` | Podman固有の設定 |
| `[Install]` | 有効化ターゲット |

**`[Container]` の主要キー：**

| キー | 説明 | 対応する `podman run` オプション |
|------|------|--------------------------------|
| `Image` | コンテナイメージ | image引数 |
| `ContainerName` | コンテナ名 | `--name` |
| `Network` | ネットワーク | `--network` |
| `Volume` | ボリュームマウント | `-v` |
| `Environment` | 環境変数 | `-e` |
| `Secret` | シークレット | `--secret` |
| `PublishPort` | ポート公開 | `-p` |
| `User` | 実行ユーザー | `--user` |

---

## シークレット管理

Podmanにはシークレット管理機能がある：

```bash
# 環境変数からシークレットを作成
export MARIADB_PASSWORD=my-secret-pw
podman secret create MARIADB_PASSWORD --env MARIADB_PASSWORD

# シークレット一覧
podman secret ls

# シークレットの詳細（値はBase64エンコードで保存）
podman secret inspect <secret-id>
```

コンテナでの使用：

```bash
podman run --secret=MARIADB_PASSWORD,type=env docker.io/mariadb
```

Quadletでの使用：

```ini
[Container]
Secret=MARIADB_PASSWORD,type=env
```

---

## systemdへの登録と管理

```bash
# 1. .container ファイルを配置
podlet podman run -d ... docker.io/mariadb:latest \
  > /etc/containers/systemd/mariadb.container

# 2. systemdに変更を通知
systemctl daemon-reload

# 3. サービス起動
systemctl start mariadb

# 4. 状態確認
systemctl status mariadb
# → Loaded: /etc/containers/systemd/mariadb.container; generated
# → Active: active (running)

# 5. 自動起動を有効化（[Install] セクションが必要）
systemctl enable mariadb
```

**rootless（ユーザー単位）の場合：**

```bash
systemctl --user daemon-reload
systemctl --user start myapp
systemctl --user enable myapp
```

### Quadlet管理コマンド

```bash
# 認識済みQuadletの一覧確認（-v で詳細）
podman quadlet -v
```

---

## Kubernetes YAML生成

### podman kube generate

実行中のコンテナ、Pod、ボリュームからKubernetes準拠のYAMLを生成する：

```bash
# 構文
podman kube generate [options] {CONTAINER|POD|VOLUME}

# Nginx コンテナを起動
podman run -d -p 8080:80 --name nginx docker.io/library/nginx

# Pod YAML を生成（標準出力）
podman kube generate nginx

# ファイルに出力
podman kube generate nginx -f nginx-pod.yaml

# Service も同時生成
podman kube generate -s nginx

# Kubernetesクラスタに直接適用
podman kube generate nginx | kubectl create -f -
```

### 生成されるYAMLの構造

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx-pod
spec:
  containers:
  - name: nginx
    image: docker.io/library/nginx:latest
    args: [nginx, -g, "daemon off;"]
    ports:
    - containerPort: 80
      hostPort: 8080
```

**Kubernetes YAMLの必須フィールド：**

| フィールド | 説明 |
|-----------|------|
| `apiVersion` | APIバージョン（Pod → `v1`） |
| `kind` | リソースの種類（Pod, Service等） |
| `metadata` | 名前・ラベル・アノテーション |
| `spec` | リソース仕様（コンテナ・ボリューム・ポート） |

### `podman kube generate -s` でService付き生成

Kubernetesクラスタ内でPodを外部公開するためのServiceリソースも同時生成される。Serviceタイプ：

| タイプ | 説明 |
|--------|------|
| `ClusterIP` | クラスタ内部のみ（デフォルト） |
| `NodePort` | NATでノードのポートに公開 |
| `LoadBalancer` | クラウドプロバイダーのLBを使用（Podmanでは非対応） |

---

## Kubernetes YAML の実行（podman kube play）

生成したYAMLをPodman上でローカル実行する（Docker Composeの代替として使用可能）：

```bash
# YAMLからコンテナ/Podを起動
podman kube play nginx-pod.yaml

# 停止・削除
podman kube play --down nginx-pod.yaml
```

### Kubernetes クラスタへのデプロイ

```bash
# kubectl でクラスタに適用
kubectl create -f nginx-pod.yaml

# または
kubectl apply -f nginx-pod.yaml
```

---

## 判断フロー：サービス管理方法の選択

```
コンテナをサービスとして管理したい？
    ↓
単一ホストか？
    │
    ├── 単一ホスト → Quadlet（.container ファイル）を使用
    │                 systemctlで管理、OS起動時自動起動
    │
    └── 複数ホスト → Kubernetes を検討
                     podman kube generate でYAML生成
                     K8sクラスタ（minikube/kind/本番）で実行
```

### ユーザー確認（AskUserQuestion）

以下について確認が必要な場合がある：

- systemd 統合が必要か、それとも Docker Compose スタイルの起動で十分か？
- rootless（ユーザー単位）か rootful（システム全体）か？
- Kubernetes への移行を最終目標としているか？（→ Quadletから始めてkube generateへ）
- 本番 Kubernetes クラスタの種類は？（minikube/kind/EKS/GKE等）
