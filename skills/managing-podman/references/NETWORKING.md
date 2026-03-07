---
description: |
  Podman ネットワークスタック（Netavark）、コンテナ間通信、DNS 解決（aardvark-dns）、ポート公開、Pod ネットワーク、Rootless ネットワーキング（pasta/slirp4netns）の実践ガイド。
  Use when configuring container networking, troubleshooting DNS resolution, publishing ports, setting up multi-container communication, or understanding rootless network behavior.
  Supplements SKILL.md with detailed network architecture and configuration procedures.
---

# ネットワーキングリファレンス

## 1. Netavark ネットワークスタック

Podman 4 から採用された Rust 製ネットワークバックエンド。Podman 5 で CNI は deprecated、Podman 6 で完全削除。

### ネットワーク設定ファイル

| 実行モード | 設定ファイルの場所 |
|-----------|-----------------|
| Rootful | `/etc/containers/networks/` |
| Rootless | `~/.local/share/containers/storage/networks/` |

設定ファイルは JSON 形式。主要フィールド:

```json
{
  "name": "mynet",
  "id": "<sha256>",
  "driver": "bridge",
  "network_interface": "podman1",
  "subnets": [{"subnet": "10.89.0.0/24", "gateway": "10.89.0.1"}],
  "ipv6_enabled": false,
  "internal": false,
  "dns_enabled": true,
  "ipam_options": {"driver": "host-local"}
}
```

### 内部アーキテクチャ

| コンポーネント | 役割 |
|-------------|------|
| **veth pair** | コンテナ NS とホスト bridge を接続する仮想 NIC ペア |
| **bridge** | `podman0`, `podman1` ... の命名。コンテナ間通信を中継 |
| **IPAM** | BoltDB で管理 → `/run/containers/networks/ipam.db` |
| **Firewall** | nftables で管理。確認: `nft list table inet netavark` |

```bash
# Rootful: Network Namespace の確認
ls /var/run/netns/

# Rootless: Network Namespace の確認
ls /run/user/$UID/netns/
```

---

## 2. ネットワーク管理コマンド

### 基本操作

```bash
# カスタムネットワーク作成
podman network create mynet

# サブネット・ゲートウェイを指定して作成
podman network create \
  --subnet 192.168.100.0/24 \
  --gateway 192.168.100.1 \
  mynet

# コンテナ起動時にネットワーク指定
podman run -d --net mynet --name webapp nginx

# 既存コンテナをネットワークに接続
podman network connect mynet mycontainer

# ネットワークから切断
podman network disconnect mynet mycontainer

# ネットワーク詳細確認
podman network inspect mynet

# 未使用ネットワークを削除
podman network prune

# ネットワーク削除
podman network rm mynet

# ネットワーク一覧
podman network ls
```

### ネットワーク設定の確認

```bash
# nftables ルール（Netavark の firewall 設定）
nft list table inet netavark

# IPAM データベース確認（BoltDB）
ls /run/containers/networks/ipam.db
```

---

## 3. コンテナ間通信

### 同一ネットワーク内

同じネットワークに接続されたコンテナは**コンテナ名で名前解決**して直接通信できる。

```bash
podman network create backend-net
podman run -d --net backend-net --name db postgres
podman run -d --net backend-net --name app myapp

# app コンテナから db コンテナへの疎通確認
podman exec app ping -c1 db
```

### 異なるネットワーク間

ネットワークが異なるコンテナ同士はデフォルトで隔離される（Podman 6 以降はデフォルトで `isolate=true`）。

```bash
# Podman 6+: ネットワーク間隔離を無効化して相互通信を許可
podman network create --opt isolate=false shared-net
```

Gateway 経由のルーティングが有効な場合は、ホスト OS レベルの IP フォワーディングが必要:

```bash
# IP フォワーディングを有効化
sudo sysctl -w net.ipv4.ip_forward=1
```

---

## 4. aardvark-dns による DNS 解決

Netavark に付属する Rust 製 DNS サーバー。コンテナ名・エイリアスを IP アドレスに解決する。

### 動作ルール

| 状況 | DNS 解決 |
|------|---------|
| デフォルト `podman` ネットワーク | **無効**（コンテナ名で解決不可） |
| ユーザー作成ネットワーク | **有効**（コンテナ名で解決可） |
| 異なるネットワーク間 | **不可**（同一ネットワーク内のみ） |

### 設定ファイルの確認

```bash
# Rootful
cat /run/containers/networks/aardvark-dns/<network_name>
# 例: 10.89.0.1
#     <container_id>  10.89.0.2  webapp,<short_id>
#     <container_id>  10.89.0.3  db,<short_id>

# Rootless
cat /run/user/$UID/containers/networks/aardvark-dns/<network_name>
```

### コンテナエイリアスの設定

```bash
# コンテナにエイリアスを設定（DNS 解決で別名使用可）
podman run -d \
  --net mynet \
  --network-alias primary-db \
  --name postgres postgres
```

---

## 5. Pod ネットワーク

Pod は Kubernetes Pod を模倣した概念。**infra コンテナ（podman-pause）が 1 つの IP アドレスを保持**し、Pod 内のすべてのコンテナが Network/UTS/IPC Namespace を共有する。

### Pod の動作

```bash
# Pod 作成（infra コンテナが自動起動）
podman pod create --name mypod -p 8080:80

# Pod にコンテナを追加
podman run -d --pod mypod --name web nginx
podman run -d --pod mypod --name sidecar busybox sleep 3600

# Pod 内コンテナ間通信 → localhost で相互アクセス可
podman exec web curl http://localhost:8080

# Pod の状態確認
podman pod ps
podman pod inspect mypod
```

### Sidecar パターン

Pod 内コンテナは `localhost` で通信するため、サイドカーパターンの実装に最適:

```
[web コンテナ :80] ←── localhost ──→ [log-agent コンテナ]
       └── 共有 Network Namespace ──┘
```

---

## 6. ポート公開

### 基本的な `-p` 構文

```bash
# 書式: -p [ip:]hostPort:containerPort[/protocol]
# デフォルトプロトコル: TCP

# 単一ポート公開
podman run -d -p 8080:80 nginx

# ループバックのみに公開（外部からアクセス不可）
podman run -d -p 127.0.0.1:8080:80 nginx

# UDP ポート公開
podman run -d -p 53:53/udp mydns

# EXPOSE 済みポートをすべてランダム公開
podman run -d -P nginx

# 公開ポートの確認
podman port <container>
```

### `--network=host`（ホストネットワーク共有）

```bash
# ホストの Network Namespace をそのまま使用
# ポート公開不要だが、セキュリティリスクあり
podman run --network=host nginx
```

**注意**: `--network=host` はコンテナの Network 隔離を完全に解除する。本番環境での使用は非推奨。

### firewalld との統合

```bash
# Rootful の場合: Podman が firewalld ルールを自動設定
# 手動設定は不要（Podman が管理）

# 設定確認
firewall-cmd --list-all
```

---

## 7. Rootless ネットワーキング

### pasta（Podman 5+ デフォルト）

Pack A Subtle Tap Abstraction。ユーザー空間で動作する高性能ネットワーキングエンジン。

| 特性 | 説明 |
|------|------|
| **動作原理** | Layer-2 tap interface を Layer-4 sockets に変換 |
| **NAT なし** | ホストの IP アドレス・ルーティングをコンテナにコピー |
| **権限不要** | `CAP_NET_RAW` / `CAP_NET_ADMIN` 不要 |
| **パフォーマンス** | slirp4netns より大幅に高速（rootful veth pair に近い速度） |

```bash
# Rootless コンテナのネットワーク確認（ホストの IP と同じ IP が見える）
podman run -i busybox sh -c 'ip addr show'
# → eth0 がホストプライマリ NIC と同じ IP/インターフェース名を持つ
```

### slirp4netns（旧来の方式）

Podman 4.3 未満でのデフォルト。pasta 移行前の後方互換性が必要な場合:

```bash
# pasta で slirp4netns 互換の設定を使用
podman run \
  --network=pasta:--ipv4-only,-a,10.0.2.0,-n,24,-g,10.0.2.2,--dns-forward,10.0.2.3,-m,1500,--no-ndp,--no-dhcpv6,--no-dhcp \
  --rm -d busybox sleep 1000

# カスタム MTU のみ変更（それ以外はデフォルト）
podman run --network=pasta:-m,1500 --rm -d busybox sleep 1000
```

### Rootless ネットワークの制約と回避策

**制約 1: ホストからコンテナの内部 IP に直接アクセスできない**

コンテナは独自 IP を持つが、それはユーザー専用のプライベート NS 内に存在する。外部からは見えない「バブル」の中。

```bash
# Rootless NS 内の veth/bridge を確認（ホストの ip link では見えない）
podman unshare --rootless-netns ip link | grep 'podman'
# → podman3: bridge インターフェースが見える
```

**3 つの通信戦略**:

1. **Pod を使用**: 同一 Pod 内のコンテナは `localhost` で通信
2. **カスタム bridge ネットワーク**: 同一ネットワーク内でコンテナ名を使って通信
3. **ポートマッピング（`-p`）**: ホストのポートを経由してアクセス

**制約 2: 特権ポート（1024 未満）は使用不可**

```bash
# ❌ Rootless では失敗（ポート 80 は特権ポート）
podman run -p 80:80 nginx

# ✅ 1024 以上のポートを使用
podman run -p 8080:80 nginx
```

**制約 3: ping が失敗する場合がある**

```bash
# 修正: カーネルパラメータで ping を許可
sudo sysctl -w net.ipv4.ping_group_range="0 2000000"
# → 永続化する場合は /etc/sysctl.d/ に追記
```

### pasta によるポート公開の仕組み

```bash
# コンテナ起動
podman run -d --rm -p 8000:8000 registry.access.redhat.com/ubi9/python-312 python -m http.server

# pasta プロセスがポートフォワーディングを担当
ps aux | grep pasta
# → pasta --config-net -t 8000-8000:8000-8000 --dns-forward 169.254.1.1 ...
# -t オプション: TCP ポートフォワーディングの設定
```

**Rootless のポート公開時の注意**: 非 root ユーザーはファイアウォールルールを変更できないため、必要に応じて手動で firewall ルールを追加する。

---

## 8. ネットワーク診断コマンド早見表

```bash
# ネットワーク一覧と詳細
podman network ls
podman network inspect <name>

# コンテナのネットワーク情報確認
podman inspect <container> --format '{{.NetworkSettings}}'

# コンテナ内ネットワーク確認（exec で実行）
podman exec <container> ip addr show
podman exec <container> ip route
podman exec <container> ss -atunp

# DNS 解決テスト
podman exec <container> nslookup <hostname>
podman exec <container> dig <hostname>

# Rootless NS 内のインターフェース確認
podman unshare --rootless-netns ip link
podman unshare --rootless-netns ip addr

# nftables ルール確認（Netavark 管理の firewall）
nft list table inet netavark

# aardvark-dns 設定確認
cat /run/containers/networks/aardvark-dns/<network_name>        # Rootful
cat /run/user/$UID/containers/networks/aardvark-dns/<network_name>  # Rootless
```
