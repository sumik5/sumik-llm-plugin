# ストレージ（volumes/bind mounts/tmpfs）

## 目次

1. [ストレージ種別の概要](#1-ストレージ種別の概要)
2. [Underlying storage（COW/overlayfs）](#2-underlying-storagecowoverlayfs)
3. [ファイルシステムへのアクセス](#3-ファイルシステムへのアクセス)
4. [Bind mounts](#4-bind-mounts)
5. [Volumes（Podman管理）](#5-volumespodman管理)
6. [その他のマウント種別](#6-その他のマウント種別)
7. [SELinuxとストレージ](#7-selinuxとストレージ)

---

## 1. ストレージ種別の概要

Podmanのストレージは2種類に大別される:

| 種別 | 説明 |
|------|------|
| **Underlying storage** | イメージのCOW（Copy-on-Write）ファイルシステム。重ね合わさったレイヤー構造 |
| **External storage** | コンテナに付属する永続ストレージ。Bind mounts・Volumes・tmpfsなど |

---

## 2. Underlying storage（COW/overlayfs）

### COWドライバーの種類

| ドライバー | 説明 |
|-----------|------|
| **overlay** | デフォルト。Linux overlayfsを使用 |
| **vfs** | ファイルをコピー（COWなし）。テスト目的 |
| **btrfs** | Btrfsファイルシステム上で動作 |
| **zfs** | ZFSファイルシステム上で動作 |

### ストレージパス

| パス | 用途 |
|------|------|
| `/var/lib/containers/storage/` | rootful: graphRoot（永続データ） |
| `~/.local/share/containers/storage/` | rootless: graphRoot（永続データ） |
| `/run/containers/storage/` | runroot（一時データ、tmpfsベース） |
| `/var/lib/containers/storage/volumes/` | rootful: Volumeデータ |
| `~/.local/share/containers/storage/volumes/` | rootless: Volumeデータ |

### ディレクトリ構造（overlay）

```
storage/
├── overlay-images/    # イメージメタデータ
├── overlay-layers/    # レイヤーアーカイブ
└── overlay/           # 展開済みレイヤー（各レイヤーディレクトリ）
    └── <layer-id>/
        ├── diff/      # このレイヤーの変更分
        ├── lower      # 下位レイヤーの一覧（最初のレイヤーには存在しない）
        ├── merged/    # マウントポイント（すべてのレイヤーを統合した仮想view）
        ├── work/      # overlayfsの内部操作用
        └── link       # 短縮シンボリックリンク
```

**最初のレイヤー（ベースイメージ）**: `lower`ファイルなし、代わりに`empty`ディレクトリ

### overlay mountのパス確認

```bash
# コンテナストレージの詳細確認（graphDriverName・rootless設定含む）
$ podman info --format json | jq '{
    version: .version.Version,
    storage_driver: .store.graphDriverName,
    rootless: .host.security.rootless,
    graph_root: .store.graphRoot
  }'
```

---

## 3. ファイルシステムへのアクセス

### コンテナとのファイルコピー

```bash
# コンテナ → ホスト
$ podman cp <container>:/etc/nginx/nginx.conf ./nginx.conf

# ホスト → コンテナ
$ podman cp ./nginx.conf <container>:/etc/nginx/nginx.conf
```

### コンテナのファイルシステムをマウント（rootful）

```bash
# コンテナをマウント（mergedDirのパスを返す）
$ podman mount <container>
/var/lib/containers/storage/overlay/<id>/merged

# マウント解除
$ podman unmount <container>
```

### rootlessでのコンテナマウント（User Namespace内）

rootlessコンテナのoverlay mountはUser Namespace内に存在するため、ホストから直接アクセスできない。`podman unshare`でUser Namespace内のシェルを起動してからアクセスする:

```bash
# User Namespace内のシェルを起動
$ podman unshare

# シェル内でマウント・操作
$ podman mount <container>
$ ls /var/lib/containers/storage/overlay/<id>/merged

# または1ステップで
$ podman unshare --mount <container>
```

### コンテナの変更を新イメージとして保存

実行中または停止済みのコンテナのルートfsをイメージとして永続化する:

```bash
# -p: コミット前にコンテナを一時停止（ファイルシステムの一貫性確保）
$ podman commit -p <container> <image-name>

# メッセージ・ラベル付き
$ podman commit -m "added custom config" --label version=2.0 <container> myimage:v2

# タグ付きで直接プッシュ先を指定
$ podman commit <container> quay.io/<user>/myimage:latest
```

---

## 4. Bind mounts

ホストのディレクトリ・ファイルをコンテナに直接マウントする。

### -v（--volume）構文

```bash
# 基本構文: -v <HOST_PATH>:<CONTAINER_PATH>[:<OPTIONS>]
$ podman run -v /host/data:/app/data nginx

# 読み取り専用
$ podman run -v /host/config:/etc/nginx/conf.d:ro nginx

# SELinux relabeling（後述）
$ podman run -v /host/data:/app/data:Z nginx
```

### --mount構文（より明示的）

```bash
# 基本bind mount
$ podman run --mount type=bind,src=/host/data,dst=/app/data nginx

# 読み取り専用
$ podman run --mount type=bind,src=/host/config,dst=/etc/nginx/conf.d,ro=true nginx
```

---

## 5. Volumes（Podman管理）

Podmanが管理する名前付きディレクトリ。ホストパスを直接指定しなくてよい。

### Volumeの作成・管理

```bash
# Volume作成
$ podman volume create mydata

# Volume一覧
$ podman volume ls

# Volume詳細
$ podman volume inspect mydata

# Volume削除
$ podman volume rm mydata

# 未使用Volumeを一括削除
$ podman volume prune

# rootlessのVolume実体パス例:
# ~/.local/share/containers/storage/volumes/mydata/_data
```

### Volumeのマウント

```bash
# -v 構文（名前付きVolume）
$ podman run -v mydata:/app/data nginx

# --mount 構文
$ podman run --mount type=volume,src=mydata,dst=/app/data nginx

# 読み取り専用
$ podman run -v mydata:/app/data:ro nginx
```

### Volumeのマウント・アンマウント（ホストから操作）

```bash
# rootfulでVolumeをホストにマウント
$ podman volume mount mydata
/var/lib/containers/storage/volumes/mydata/_data

$ podman volume unmount mydata
```

### NFS Volume（rootfulのみ）

```bash
$ podman volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=192.168.1.10,rw \
  --opt device=:/exports/mydata \
  mynfsvolume

$ podman run -v mynfsvolume:/data nginx
```

### Containerfile内でのVOLUME宣言

`VOLUME` 命令があるイメージを実行すると、その宣言パスにanonymous volume（無名Volume）が自動作成される:

```dockerfile
VOLUME /var/lib/mysql
```

```bash
# 実行時に自動anonymous volume作成
$ podman run -d mysql

# Volumeを明示的に指定すれば上書き
$ podman run -d -v mydata:/var/lib/mysql mysql
```

### 他コンテナのVolumeを共有

```bash
# 既存コンテナのVolumeをマウント（同一パス・同一設定で継承）
$ podman run --volumes-from=<source-container> nginx

# 読み取り専用で継承
$ podman run --volumes-from=<source-container>:ro nginx
```

---

## 6. その他のマウント種別

### tmpfs（メモリ上の一時ファイルシステム）

```bash
# --mount構文
$ podman run --mount type=tmpfs,tmpfs-size=512M,destination=/tmp nginx

# --tmpfs構文（簡略形）
$ podman run --tmpfs /tmp:rw,size=524288k nginx
```

用途: 機密データ（パスワード・セッションデータ）の一時保存。コンテナ停止でデータが消える。

### イメージマウント

別のコンテナイメージをボリュームとしてマウントする（事前pullが必要）:

```bash
$ podman pull mytools:latest
$ podman run --mount type=image,src=mytools:latest,dst=/mnt nginx

# 読み書き可能（デフォルトはro）
$ podman run --mount type=image,src=mytools:latest,dst=/mnt,rw=true nginx
```

### devpts（疑似端末）

```bash
$ podman run --mount type=devpts,destination=/dev/pts mycontainer
```

---

## 7. SELinuxとストレージ

SELinux環境（Fedora/RHEL系）では、ホストのファイルシステムをコンテナにbind mountする際、SELinuxラベルの再設定が必要になる場合がある。

### SELinuxラベルのオプション

| オプション | 効果 | セキュリティ |
|-----------|------|------------|
| `:z` または `relabel=shared` | 共有ラベル（`s0`）を付与。複数コンテナからアクセス可 | 低 |
| `:Z` または `relabel=private` | 専有ラベル（MCSカテゴリ）を付与。1コンテナ専用 | 高 |

```bash
# 複数コンテナで共有するデータ
$ podman run -v /shared/data:/app/data:z nginx

# 単一コンテナ専用データ（推奨）
$ podman run -v /private/data:/app/data:Z nginx
```

### MLS vs MCS

- **MLS（Multi-Level Security）**: `:z`指定時に付与されるラベル（例: `s0`）
- **MCS（Multi-Category Security）**: `:Z`指定時に付与されるランダムカテゴリ（例: `s0:c16,c898`）。他のコンテナから分離される

```bash
# SELinuxラベルを確認
$ ls -Z /host/data
unconfined_u:object_r:container_file_t:s0:c16,c898 /host/data

# SELinuxラベルを無効化（開発環境のみ）
$ podman run --security-opt label=disable -v /host/data:/app/data nginx
```

---

## 関連参照

| トピック | 参照先 |
|---------|--------|
| コンテナ操作コマンド | [CONTAINERS.md](CONTAINERS.md) |
| アーキテクチャ・COW詳細 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Buildah（イメージビルドとストレージ） | [BUILDAH.md](BUILDAH.md) |
| セキュリティ・rootless設定 | [INSTRUCTIONS.md](../INSTRUCTIONS.md) |
