# コンテナ基礎 + Podman vs Docker アーキテクチャ

## 目次

1. [コンテナとは何か](#1-コンテナとは何か)
2. [Linux namespaces](#2-linux-namespaces)
3. [cgroups（コントロールグループ）](#3-cgroupsコントロールグループ)
4. [Docker daemon-centric アーキテクチャ](#4-docker-daemon-centric-アーキテクチャ)
5. [Podman daemonless アーキテクチャ](#5-podman-daemonless-アーキテクチャ)
6. [Podman building blocks 詳細](#6-podman-building-blocks-詳細)
7. [Docker vs Podman 比較](#7-docker-vs-podman-比較)

---

## 1. コンテナとは何か

コンテナは **「プロセス分離の実装」** である。仮想マシン（VM）が独自カーネルを持つゲストOSを起動するのとは異なり、コンテナはホストカーネルを共有しつつ、プロセスに「分離された環境」を提供する。

### コンテナとVMの違い

| 観点 | VM | コンテナ |
|------|----|----|
| カーネル | ゲストOS固有 | ホストと共有 |
| 起動時間 | 数十秒〜数分 | 数ミリ秒〜数秒 |
| リソース消費 | 大（RAM/CPU/ストレージ） | 小 |
| セキュリティ分離 | 強（完全な分離） | 中（namespace + cgroup） |
| ユースケース | 強い隔離が必要な場合 | 軽量・高密度デプロイ |

### コンテナが提供する分離レベル

- **ファイルシステム分離**: コンテナ化されたプロセスは独立したファイルシステムビューを持つ
- **プロセスID（PID）分離**: 独立したPID空間。コンテナ内のプロセスはホストのPID空間を見えない
- **ユーザー分離**: UID/GIDがコンテナ内で独立。コンテナ内でroot権限を持ちながら、ホストでは非特権ユーザーとして動作可能
- **ネットワーク分離**: ネットワークデバイス・ルーティングテーブル・ポート番号が独立
- **IPC分離**: POSIX メッセージキュー・System V IPC オブジェクトが分離
- **リソース使用量の分離**: cgroupsによってCPU・メモリ・I/Oを制限・監視

---

## 2. Linux namespaces

Linux namespaces はコンテナ実装の **最重要技術的基盤** である。namespaces はシステムリソースを抽象化し、分離されたプロセスに対してユニークなリソースビューを提供する。プロセスはホストリソース（例: ホストのファイルシステム）と対話しているように見えるが、実際は分離されたビューが提供されている。

### 8種類のnamespace

| namespace | 分離対象 | 説明 |
|-----------|---------|------|
| **mount** | マウントポイント | プロセスから見えるファイルシステムのマウントポイントリストを分離 |
| **PID** | プロセスID | プロセスIDを独立した空間に分離。異なるPID namespace内で同じPIDを持つことが可能 |
| **user** | UID/GID | ユーザーIDとグループIDを分離。コンテナ内でroot権限を持ちながら、ホストでは非特権で動作 |
| **UTS** | ホスト名 | ホスト名とNISドメイン名を分離。コンテナが独自のホスト名を持てる |
| **network** | ネットワーク | ネットワークデバイス・IPv4/v6スタック・ルーティングテーブル・ファイアウォールルール・ポート番号を分離 |
| **IPC** | プロセス間通信 | System V IPCオブジェクトとPOSIXメッセージキューを分離。IPC名前空間のメンバーのみがオブジェクトにアクセス可能 |
| **cgroup** | cgroupディレクトリ | cgroupディレクトリを分離し、プロセスのcgroupの仮想ビューを提供 |
| **time** | システム時間 | 独立したシステム時間ビューを提供。名前空間内のプロセスがホスト時間に対するオフセットで動作可能（Linux 5.6+） |

### veth pairによるネットワーク接続

network namespaceを使用する際、ホストとコンテナ間のネットワーク接続には **veth（Virtual Ethernet）pair** が使われる。一対の仮想ネットワークデバイスで、片方をホスト側・もう片方をコンテナ側に配置してトンネルを構築する。

---

## 3. cgroups（コントロールグループ）

cgroups（control groups）は Linux カーネルのネイティブ機能で、プロセスを **階層ツリーで組織化** し、リソース使用量を制限・監視する。

### インターフェース

`cgroupfs` 疑似ファイルシステムとして公開され、通常 `/sys/fs/cgroup` にマウントされる。

### コントローラー（サブシステム）

cgroups は様々なコントローラーを提供する:
- **cpu**: CPUタイムシェアを制限（クォータ・シェア）
- **memory**: メモリ使用量を制限
- **io**: ストレージデバイスの読み書きレートを制限
- **blkio**: ブロックデバイスI/Oを制御
- **pids**: プロセス数を制限

### v1 vs v2

| | cgroups v1 | cgroups v2 |
|-|-----------|-----------|
| 階層構造 | 異なるコントローラーを異なる階層にマウント可能 | 単一の統一階層（プロセスはリーフノードに配置） |
| 状態 | deprecated方向 | 現代的なディストリビューションで標準 |
| Podman対応 | 互換性のために限定的にサポート | 推奨 |

---

## 4. Docker daemon-centric アーキテクチャ

Dockerは2013年に登場し、コンテナ技術を広く普及させた。そのアーキテクチャは **デーモン中心型** である。

### 3つの基本柱

```
Docker CLI ──HTTP──> Docker daemon (dockerd)
                          │
                          └──> containerd ──> containerd-shim ──> runc
```

#### Docker daemon（dockerd）

常時バックグラウンドで動作し、以下を担当する:
- Docker API リクエストのリスニング（`/var/run/docker.sock`）
- コンテナの管理・チェック
- Docker images・networks・storage volumes の管理
- 外部コンテナレジストリとの通信（push/pull）

#### Docker REST API

ソケット経由でHTTPリクエストを受け付ける。daemon が起動していれば `curl --unix-socket /var/run/docker.sock` で直接呼び出し可能。機械間通信・CI/CD連携に使われる。

#### Docker CLI（クライアント）

30以上のコマンドを提供。`docker run`・`docker ps`・`docker build` などのコマンドはCLIがdaemonに指示を送る。

#### containerd

Dockerdaemon とrunc の間に位置するコンテナ管理レイヤー:
- OCI標準に準拠（`runc` を使用）
- Bundle service（ディスクイメージからbundleを展開）と Runtime service（bundleを実行）で構成
- `containerd-shim-runc-v2` がコンテナプロセスを監視

### Docker アーキテクチャの問題点

- **Single point of failure**: daemonが停止するとすべてのコンテナが影響を受ける
- **rootが必要**: daemonはroot権限で動作し、`/var/run/docker.sock` はrootが所有
- **セキュリティリスク**: ソケットへのアクセスは事実上のrootアクセスと同等

---

## 5. Podman daemonless アーキテクチャ

Podman（POD MANager）は **デーモンレス** コンテナエンジンである。インストール後にサービスを起動する必要がなく、バックグラウンドデーモンなしでコンテナを実行できる。

### 根本的な違い

```
# Docker（daemon必須）
docker run nginx
  → Docker CLI → dockerd → containerd → runc

# Podman（daemonless）
podman run nginx
  → podman binary ──┬── libpod (container lifecycle)
                    ├── crun/runc (OCI runtime)
                    ├── Conmon (monitoring)
                    └── Netavark (networking)
```

### Podman binary の役割

インストールされた単一のPodmanバイナリが **CLI と コンテナエンジン** の両方として機能する。コマンドを実行するたびに、必要なプロセスを直接フォークする（常駐デーモンなし）。

### オプションのREST API

デーモンは不要だが、API連携のためにソケットサービスを起動することも可能:

```bash
# ソケットサービスを起動（オプション）
$ podman system service --time 0 unix:///tmp/podman.sock

# デフォルトソケット
# rootful:   /run/podman/podman.sock
# rootless:  /run/user/<UID>/podman/podman.sock
```

---

## 6. Podman building blocks 詳細

Podmanはオープン標準に強くコミットし、各コンポーネントにコミュニティライブラリを採用している。

### コンポーネント一覧

| コンポーネント | 役割 | 言語 |
|--------------|------|------|
| **libpod** | コンテナライフサイクル管理の中核ライブラリ | Go |
| **crun** | デフォルトOCIコンテナランタイム | C（高速・軽量） |
| **runc** | 代替OCIコンテナランタイム | Go |
| **Conmon** | OCIランタイムのモニタリング・通信 | C |
| **Buildah** | OCI imageビルド（バイナリ + ライブラリ） | Go |
| **Netavark** | コンテナネットワークスタック | Rust |
| **containers/image** | イメージ管理ライブラリ | Go |
| **containers/storage** | ストレージ（レイヤー・ボリューム）管理 | Go |

### libpod ライブラリの機能範囲

`libpod` はPodmanプロジェクトの核心であり、以下をすべて担当する:
- OCI/Docker両形式のイメージライフサイクル（認証・pull・ローカルストレージ・build・push）
- コンテナライフサイクル（create・run・stop・kill・resume・delete・exec・logging）
- コンテナおよびPodの管理（UTS・IPC・networkをnamespace共有）
- rootlessコンテナ・Podのサポート（特権昇格不要）
- cgroupsを通じたリソース分離（CLI オプションでメモリ・CPU・I/O制御）
- Docker互換CLI・REST API

### runc vs crun

| | runc | crun |
|-|------|------|
| 言語 | Go | C |
| 歴史 | Docker 2015年にOSSリリース | 後発・軽量実装 |
| OCI準拠 | 完全準拠 | 完全準拠 |
| Podmanデフォルト | Fedora等は長らくデフォルト | 現在のデフォルト |
| パフォーマンス | 標準 | 高速（メモリ消費少） |

### Conmon（CONtainer MONitor）

コンテナプロセスとPodmanエンジン間の仲介役:
- OCI runtimeのライフサイクルイベントを監視
- 標準入出力の処理・ログ記録
- コンテナの終了コードをlibpodに報告
- PodmanとCRI-O（Kubernetes向けコンテナランタイム）の両方で使用

### Netavark（ネットワーキング）

Podman 4.0で CNI（Container Network Interface）を置き換えてデフォルトになったRust製のネットワークスタック:

```
Podman 4.0: CNI → Netavark（デフォルト変更）
Podman 5.0: CNI deprecated
```

サポートされるドライバ:
- **bridge**: デフォルト。ホストのbridgeネットワーク経由
- **macvlan**: ホストネットワークインターフェースを直接コンテナに割り当て
- **ipvlan**: L2/L3モードでの仮想NIC

---

## 7. Docker vs Podman 比較

### アーキテクチャ比較

| 観点 | Docker | Podman |
|------|--------|--------|
| デーモン | 必須（dockerd常駐） | 不要（daemonless） |
| 権限 | root必須（daemon） | rootless対応 |
| Single point of failure | あり（daemon停止でコンテナ影響） | なし |
| CLI互換性 | Docker CLI | Docker CLI互換（ほぼ同一） |
| イメージ形式 | OCI互換（独自実装から移行） | OCI標準 |
| Pods | なし（Compose/Swarmで代替） | ネイティブサポート |
| systemd統合 | 限定的 | Quadletでネイティブ統合 |
| Kubernetes YAML生成 | なし | `podman generate kube` |
| ネットワーク | libnetwork | Netavark（Rust製） |
| ビルドツール | Dockerfile + `docker build` | Containerfile + Buildah |

### セキュリティモデルの違い

**Docker のセキュリティ課題:**
- `docker` グループへの追加 = 事実上のroot権限付与
- `/var/run/docker.sock` はパスワードなしroot同等

**Podman のセキュリティ優位性:**
- **rootless-first**: 非特権ユーザーがコンテナを実行
- **User Namespaces**: コンテナ内のUID/GIDをホストの別UID/GIDにマッピング
- **デーモンレス**: 攻撃対象のサービスが存在しない

### コマンド対応早見表

| 操作 | Docker | Podman |
|------|--------|--------|
| コンテナ実行 | `docker run` | `podman run` |
| コンテナ一覧 | `docker ps` | `podman ps` |
| イメージビルド | `docker build` | `podman build` |
| Pod管理 | （なし） | `podman pod` |
| Kubernetes YAML生成 | （なし） | `podman generate kube` |
| systemd unit生成 | （なし） | `podman generate systemd` |
| デーモン起動確認 | `systemctl status docker` | 不要（デーモンなし） |

---

## 関連参照

| トピック | 参照先 |
|---------|--------|
| インストール手順 | [INSTALLATION.md](INSTALLATION.md) |
| コンテナ操作コマンド | [CONTAINERS.md](CONTAINERS.md) |
| ストレージ（COW・volumes） | [STORAGE.md](STORAGE.md) |
| Buildahによるイメージビルド | [BUILDAH.md](BUILDAH.md) |
| セキュリティ詳細・rootless運用 | [INSTRUCTIONS.md](../INSTRUCTIONS.md) |
