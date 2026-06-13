# OS別インストール・環境構築

## 目次

1. [OS選択の考え方](#1-os選択の考え方)
2. [Linux ディストリビューション別インストール](#2-linux-ディストリビューション別インストール)
3. [macOS での利用](#3-macos-での利用)
4. [Windows での利用](#4-windows-での利用)
5. [インストール後の確認](#5-インストール後の確認)
6. [重要な設定ファイル](#6-重要な設定ファイル)

---

## 1. OS選択の考え方

Podman はLinux カーネルの機能（namespaces・cgroups）を使用するため、**Linuxネイティブ動作** が本質である。macOS・Windows では Linux VM が介在する。

### セキュリティサブシステムの違い

| ディストリビューション系 | MACシステム | 特徴 |
|----------------------|-----------|------|
| Fedora / CentOS / RHEL系 | **SELinux** | 強制アクセス制御・コンテキストラベル |
| Debian / Ubuntu系 | **AppArmor** | プロファイルベースのアクセス制御 |

Podman は両方と統合し、コンテナの追加的な分離を提供する。ただし、インターフェースが異なるため、SELinux環境でのトラブルシュートはAppArmor環境と異なる手順になる。

---

## 2. Linux ディストリビューション別インストール

### Fedora（推奨環境）

```bash
# Podman をインストール（rootで実行）
# dnf install -y podman
```

インストール内容:
- Podman バイナリ・依存ライブラリ
- 設定ファイル（`/etc/containers/` 以下）
- systemd unit ファイル（REST APIサービス・自動更新用）

### CentOS Stream

```bash
# AppStream リポジトリから直接インストール可能
# dnf install -y podman
```

### RHEL（Red Hat Enterprise Linux）

**RHEL 8の場合:**

```bash
# container-tools モジュールで一括インストール（推奨）
# yum module enable -y container-tools:rhel8
# yum module install -y container-tools:rhel8

# または Podman のみ
# yum install -y podman
```

`container-tools` モジュールに含まれるツール:
- **Skopeo**: OCI イメージ・レジストリ管理ツール
- **Buildah**: カスタムOCIイメージビルドツール
- **CRIU**: チェックポイント/リストア機能
- **Udica**: コンテナ用SELinuxセキュリティプロファイル生成ツール

**RHEL 9/10の場合:**

```bash
# container-tools メタパッケージ（モジュール廃止）
# dnf install -y container-tools

# または Podman のみ
# dnf install -y podman
```

### Rocky Linux / AlmaLinux

RHEL互換のコミュニティディストリビューション。RHELと同様のコマンドでインストール:

```bash
# dnf install -y podman
```

### Fedora CoreOS / Fedora Silverblue

**インストール不要**: どちらもPodmanがプリインストール済み。

- **Fedora CoreOS**: サーバー・クラウド向け不変（immutable）OS。Red Hat OpenShift（OKD）のアップストリームでもある
- **Fedora Silverblue**: デスクトップ向け不変OS。コンテナワークフローを前提に設計

### Debian（11 Bullseye 以降）

```bash
# apt-get -y install podman
```

### Ubuntu（20.10 以降）

```bash
# apt-get -y update
# apt-get -y install podman
```

### openSUSE（TumbleweedおよびLeap）

```bash
# zypper install podman
```

### Gentoo

```bash
# emerge app-emulation/podman
```

Portage パッケージマネージャーがソースからビルドする。

### Arch Linux

```bash
# pacman -S podman
```

**注意**: Arch Linuxのデフォルトインストールではrootlessコンテナが無効。有効にするには Arch wiki の手順に従う。

### Raspberry Pi OS

Debian ベースのため、Debianと同じ手順でインストール可能（arm64対応）:

```bash
# apt-get -y install podman
```

---

## 3. macOS での利用

macOSはLinuxカーネルを持たないため（XNUカーネル）、Linuxコンテナをネイティブ実行できない。Podmanは **Podman Machine** という仕組みで軽量Linux VMを透過的に管理する。

### インストール方法

**公式インストーラー（推奨）**: podman.io からダウンロード

**Homebrew（非推奨だが動作する）:**

```bash
$ brew install podman
```

### Podman Machine セットアップ

```bash
# VM を初期化して起動（2ステップ）
$ podman machine init
$ podman machine start

# または一括実行
$ podman machine init --now
```

起動後は `podman` コマンドが自動的にVM経由でコンテナを操作する。

### Podman Machine 管理コマンド

```bash
$ podman machine list         # Machine 一覧
$ podman machine stop         # Machine 停止
$ podman machine rm           # Machine 削除
$ podman machine ssh          # Machine へのSSHアクセス
$ podman machine inspect      # Machine 詳細情報
```

---

## 4. Windows での利用

### WSL 2 経由（推奨）

Windows Subsystem for Linux（WSL）2は、Hyper-V仮想化を使ってLinuxカーネルインターフェースを提供する:

1. WSL 2 をインストール（`wsl --install`）
2. WSL 2 内でLinuxディストリビューションをインストール
3. WSL 2内でPodmanをインストール（ディストリビューションに応じた手順）

### Podman Desktop（GUI）

WindowsおよびmacOS向けのグラフィカルUIを提供するPodman Desktopも利用可能。CLIとGUIを統合した開発環境を提供する。

---

## 5. インストール後の確認

### 基本動作確認

```bash
# バージョン確認
$ podman version

# システム情報
$ podman info

# 最初のコンテナ実行（Podmanが正常動作することを確認）
$ podman run hello-world
```

### rootless 動作確認

```bash
# 一般ユーザーとしてコンテナを実行（rootが不要）
$ podman run --rm alpine echo "rootless container works"

# User Namespace のマッピング確認
$ podman unshare cat /proc/self/uid_map
```

### REST API サービス（オプション）

```bash
# REST API ソケットサービスを起動（一時的）
$ podman system service --time 0 unix:///tmp/podman.sock &

# API テスト
$ curl --unix-socket /tmp/podman.sock http://d/v3.0.0/libpod/info | jq .

# systemd 経由で常時起動（rootless）
$ systemctl --user enable --now podman.socket
```

---

## 6. 重要な設定ファイル

インストール後に自動配置される設定ファイル:

| ファイル/ディレクトリ | 用途 |
|--------------------|------|
| `/etc/containers/registries.conf` | コンテナレジストリの検索順序・設定（システム全体） |
| `/etc/containers/storage.conf` | ストレージドライバー設定（システム全体） |
| `/etc/containers/policy.json` | イメージ署名ポリシー |
| `~/.config/containers/registries.conf` | ユーザー固有のレジストリ設定（rootless） |
| `~/.config/containers/storage.conf` | ユーザー固有のストレージ設定（rootless） |
| `~/.local/share/containers/` | rootlessコンテナのデータ保存先 |

### registries.conf の例

```toml
# デフォルトレジストリの検索順序
[registries.search]
registries = ['docker.io', 'registry.fedoraproject.org', 'quay.io']

# 安全でないレジストリ（HTTP）の許可
[registries.insecure]
registries = []
```

### Podman インストール状態の包括的確認

```bash
# システム情報（インストール状態・ストレージドライバー・rootless設定を含む）
$ podman info --format json | jq '{
    version: .version.Version,
    storage_driver: .store.graphDriverName,
    rootless: .host.security.rootless,
    cgroups_version: .host.cgroupsVersion
  }'
```

---

## 関連参照

| トピック | 参照先 |
|---------|--------|
| アーキテクチャ理解 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| コンテナ操作コマンド | [CONTAINERS.md](CONTAINERS.md) |
| ストレージ設定 | [STORAGE.md](STORAGE.md) |
| セキュリティ・rootless設定 | [INSTRUCTIONS.md](../INSTRUCTIONS.md) |
