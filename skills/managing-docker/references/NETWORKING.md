---
name: managing-docker
description: Docker networking guide covering CNM, bridge, overlay, macvlan drivers, and service discovery.
---

# Docker ネットワーキング

Dockerネットワーキングの基礎から、コンテナ間通信、外部ネットワーク接続、サービスディスカバリまでを解説します。

---

## アーキテクチャ

Dockerネットワーキングは以下の3つのコンポーネントで構成されています：

### Container Network Model (CNM)

CNMはDockerネットワークの設計仕様であり、3つの基本要素を定義します：

- **Sandbox**: コンテナ内の隔離されたネットワークスタック（Ethernetインターフェース、ポート、ルーティングテーブル、DNS設定を含む）
- **Endpoint**: 仮想ネットワークインターフェース（通常のネットワークインターフェースと同様に動作）。SandboxとNetworkを接続
- **Network**: 仮想スイッチ（通常は802.1dブリッジのソフトウェア実装）。通信が必要な複数のEndpointをグループ化し隔離

**重要な原則:**
- 各コンテナは独自のSandboxを持つ
- EndpointはSandboxをNetworkに接続する
- 1つのEndpointは1つのNetworkにのみ接続可能
- コンテナが複数のネットワークに接続するには複数のEndpointが必要

### Libnetwork

- CNMのリファレンス実装（オープンソース、クロスプラットフォーム）
- Mobyプロジェクトでメンテナンス
- コントロールプレーンを実装（管理API、サービスディスカバリ、Ingressロードバランシング）

### ドライバー

データプレーンの実装を担当し、ネットワークの作成と隔離・接続を保証します。

**ビルトインドライバー（ネイティブ/ローカルドライバー）:**
- **bridge**: 単一ホストブリッジネットワーク
- **overlay**: マルチホストオーバーレイネットワーク
- **macvlan**: 既存のVLANへの接続
- **host**: コンテナをホストのネットワークスタックに直接接続
- **none**: ネットワーク接続なし

**サードパーティドライバー:**
- より高度なネットワークトポロジーや外部ストレージシステムとの統合が可能

---

## 単一ホストブリッジネットワーク

### 基本概念

- **単一ホスト**: ネットワークは1つのDockerホストにのみ存在
- **ブリッジ**: 802.1dブリッジ（レイヤー2スイッチ）の実装
- **Linuxベース**: 20年以上の歴史を持つLinux bridgeテクノロジーを使用

### デフォルトブリッジネットワーク

すべてのDockerホストには `bridge` という名前のデフォルトブリッジネットワークが存在します。

```bash
# ネットワーク一覧表示
docker network ls

# デフォルトブリッジの詳細確認
docker network inspect bridge
```

デフォルトの `bridge` ネットワークはホストカーネル内の `docker0` Linuxブリッジにマッピングされます。

### カスタムブリッジネットワークの作成

```bash
# 新しいブリッジネットワーク作成
docker network create -d bridge localnet

# ネットワーク詳細確認
docker network inspect localnet

# Linuxブリッジ確認
brctl show
ip link show
```

### コンテナの接続

```bash
# ネットワークを指定してコンテナ作成
docker run -d --name c1 \
  --network localnet \
  alpine sleep 1d

# コンテナがネットワークに接続されているか確認
docker network inspect localnet --format '{{json .Containers}}' | jq
```

### 名前解決（DNS）

同じネットワーク上のコンテナは名前で相互に通信できます。

```bash
# 2つ目のコンテナを作成
docker run -it --name c2 \
  --network localnet \
  alpine sh

# 最初のコンテナに名前でping
ping c1
```

**仕組み:**
1. コンテナ内のDNSリゾルバがキャッシュをチェック
2. キャッシュミスの場合、DockerのembeddedDNSサーバーに再帰クエリ
3. Docker DNSサーバーがname-to-IPマッピングを返す（同じネットワーク上のコンテナのみ）
4. コンテナがIPアドレスを使って通信

**注意事項:**
- デフォルトの `bridge` ネットワークはDNS解決をサポートしない
- `--name` または `--net-alias` フラグで作成したコンテナのみDNSに登録される
- 名前解決はネットワークスコープ（同じネットワーク上のみ有効）

---

## 外部アクセス: ポートマッピング

ブリッジネットワーク上のコンテナをDockerホストのポートにマッピングして外部公開できます。

### ポートマッピングの作成

```bash
# ポート5005（ホスト）→ポート80（コンテナ）のマッピング
docker run -d --name web \
  --network localnet \
  --publish 5005:80 \
  nginx

# ポートマッピング確認
docker port web
```

### 制限事項

- ホストの1つのポートを複数コンテナで共有不可
- スケーラビリティに欠ける
- ローカル開発や小規模アプリケーション向け

---

## 既存ネットワークとVLANへの接続

### MACVLANドライバー

MACVLANは各コンテナに外部物理ネットワーク上の独自のIPとMACアドレスを付与します。

**利点:**
- 高いパフォーマンス（ポートマッピング不要）
- コンテナが物理サーバーやVMのように見える

**制約:**
- ホストNICをpromiscuousモードで実行する必要がある
- 多くの企業ネットワークやパブリッククラウドでは許可されない

### MACVLANネットワークの作成

```bash
# MACVLAN100ネットワークを作成（VLAN 100用）
docker network create -d macvlan \
  --subnet=10.0.0.0/24 \
  --ip-range=10.0.0.0/25 \
  --gateway=10.0.0.1 \
  -o parent=eth0.100 \
  macvlan100

# ネットワーク詳細確認
docker network inspect macvlan100

# コンテナを接続
docker run -d --name mactainer1 \
  --network macvlan100 \
  alpine sleep 1d
```

**重要な設定項目:**
- `--subnet`: サブネット情報
- `--gateway`: ゲートウェイ
- `--ip-range`: コンテナに割り当て可能なIPアドレス範囲（重複を避けるため予約必須）
- `-o parent`: ホストの親インターフェースまたはサブインターフェース

### VLANトランキング

Docker MACVLANドライバーはVLANトランキングをサポートし、異なるVLANに接続する複数のMACVLANネットワークを作成できます。

---

## サービスディスカバリ

Libnetworkはすべてのコンテナとswarmサービスが名前で相互に検索できるサービスディスカバリを提供します。

### 要件

- コンテナが同じネットワーク上にあること
- `--name` または `--net-alias` フラグで作成されていること

### 動作の仕組み

1. コンテナがDNSクエリを発行
2. ローカルDNSリゾルバがキャッシュをチェック
3. キャッシュミスの場合、DockerのembeddedDNSサーバーに再帰クエリ
4. Docker DNSサーバーが名前とIPのマッピングを返す
5. コンテナがIPアドレスを使って通信

### カスタムDNS設定

```bash
# カスタムDNSサーバーと検索ドメインを指定
docker run -it --name custom-dns \
  --dns=8.8.8.8 \
  --dns-search=example.com \
  alpine sh

# /etc/resolv.confの確認
cat /etc/resolv.conf
```

---

## Ingressロードバランシング（Swarm専用）

Docker Swarmは2つのサービス公開方法を提供します：

### Ingressモード（デフォルト）

- どのswarmノードからでもサービスにアクセス可能（レプリカを実行していないノードでも）
- レイヤー4ルーティングメッシュ（service mesh/swarm-mode service mesh）を使用

```bash
# Ingressモードでサービス公開（デフォルト）
docker service create -d --name svc1 \
  --publish 5005:80 \
  nginx
```

### Hostモード

- レプリカを実行しているノードからのみアクセス可能
- long form syntaxを使用

```bash
# Hostモードでサービス公開
docker service create -d --name svc1 \
  --publish published=5005,target=80,mode=host \
  nginx
```

**Long form syntaxオプション:**
- `published`: 外部クライアントに公開するポート
- `target`: サービスレプリカ内のポート
- `mode`: `ingress`（デフォルト）または `host`

### Ingressモードの動作

1. 外部クライアントが任意のノードのポート5005にリクエスト送信
2. ノードがIngressネットワークにトラフィック転送
3. Ingressネットワークがレプリカを実行しているノードに転送
4. ノードがレプリカにリクエスト渡す

複数レプリカがある場合、Swarmは自動的にリクエストを分散します。

---

## Dockerオーバーレイネットワーク

オーバーレイネットワークは複数のホストにまたがるフラットでセキュアなレイヤー2ネットワークを提供します。

### 前提条件

- Docker Swarmクラスタが必要
- Swarmのkey-valueストアとセキュリティ機能を活用

### 基本概念

- 複数ホスト上のコンテナが同じオーバーレイネットワークに接続して直接通信可能
- VXLANトンネリングテクノロジーを使用
- デフォルトで暗号化可能

### オーバーレイネットワークの作成

```bash
# Swarm初期化（マネージャーノード）
docker swarm init --advertise-addr <MANAGER-IP>

# ワーカーノードを追加（ワーカーノード上で実行）
docker swarm join --token <TOKEN> <MANAGER-IP>:2377

# オーバーレイネットワーク作成
docker network create -d overlay overnet

# ネットワーク確認
docker network ls
```

### スタンドアロンコンテナ用オーバーレイ

```bash
# スタンドアロンコンテナもアタッチ可能なオーバーレイ作成
docker network create -d overlay --attachable overnet-standalone
```

---

## トラブルシューティング

### ログの確認

**Dockerデーモンログ:**
- systemd環境: `journalctl -u docker.service`
- Ubuntu（upstart）: `/var/log/upstart/docker.log`
- RHEL系: `/var/log/messages`
- Debian: `/var/log/daemon.log`
- Windows: `~\AppData\Local\Docker` またはイベントビューアー

**デーモンログレベル設定（`/etc/docker/daemon.json`）:**
```json
{
  "debug": true,
  "log-level": "debug"
}
```

ログレベル（詳細度順）:
- `debug`: 最も詳細
- `info`: デフォルト
- `warn`
- `error`
- `fatal`: 最も簡潔

**コンテナログ:**
```bash
# コンテナログ表示
docker logs <container-name>

# Swarmサービスログ
docker service logs <service-name>
```

**ログドライバー設定:**
```json
{
  "log-driver": "journald"
}
```

または起動時に指定:
```bash
docker run --log-driver journald --log-opts <options> <image>
```

### ログドライバー

- `json-file`: デフォルト、`docker logs`で表示可能
- `journald`: systemd環境で推奨、`docker logs`で表示可能
- その他: プラットフォーム固有のツールで表示

---

## 主要コマンド一覧

### ネットワーク管理

```bash
# ネットワーク一覧表示
docker network ls

# ネットワーク作成
docker network create -d <driver> <network-name>

# ネットワーク詳細確認
docker network inspect <network-name>

# 未使用ネットワーク削除
docker network prune

# ネットワーク削除
docker network rm <network-name>

# コンテナをネットワークに接続
docker network connect <network-name> <container-name>

# コンテナをネットワークから切断
docker network disconnect <network-name> <container-name>
```

### Linux固有コマンド

```bash
# ホスト上のブリッジ一覧表示
brctl show

# ブリッジ設定表示
ip link show <bridge-name>
```

---

## ベストプラクティス

### ネットワーク設計

| シナリオ | 推奨ドライバー | 理由 |
|---------|--------------|------|
| ローカル開発 | bridge | シンプル、単一ホスト |
| 本番マルチホスト | overlay | セキュア、スケーラブル |
| 既存VLANとの統合 | macvlan | 既存インフラとの互換性 |
| レガシー統合 | macvlan | 物理ネットワーク上で可視化 |

### セキュリティ

- **カスタムネットワーク使用**: デフォルトの `bridge` ネットワークは使用しない（DNS解決なし）
- **ネットワーク分離**: マイクロサービスを論理グループごとに分離
- **暗号化**: オーバーレイネットワークで `--opt encrypted` を使用
- **最小権限**: 必要なコンテナのみを接続

### パフォーマンス

- **ポートマッピング最小化**: 可能な限りコンテナ間通信を使用
- **オーバーレイ最適化**: MTU設定を適切に調整
- **MACVLAN検討**: 低レイテンシが必要な場合

### 運用

- **名前付きネットワーク**: 常に明示的な名前を使用
- **ラベル活用**: メタデータでネットワークを整理
- **監視**: ネットワークメトリクスを定期的に確認
- **ドキュメント化**: ネットワーク構成をCompose fileやIaCで管理

---

## チェックリスト

### デプロイ前

- [ ] ネットワーク要件を明確化（単一ホスト vs マルチホスト）
- [ ] 適切なドライバーを選択
- [ ] IPアドレス範囲を計画（MACVLANの場合は予約）
- [ ] セキュリティ要件を確認（暗号化、分離）

### デプロイ後

- [ ] コンテナが正しいネットワークに接続されているか確認
- [ ] サービスディスカバリが動作しているか検証
- [ ] 外部アクセスが必要な場合はポートマッピングを確認
- [ ] ネットワークパフォーマンスを測定

### トラブルシューティング

- [ ] `docker network inspect` でネットワーク状態確認
- [ ] `docker logs` でコンテナログ確認
- [ ] デーモンログでエラーメッセージ確認
- [ ] ping/curl等でコンテナ間通信テスト

---

## 判断フローチャート

### ネットワークドライバー選択

```
Q: 単一ホストか複数ホストか？
├─ 単一ホスト
│  └─ → bridge ドライバー
│
└─ 複数ホスト
   ├─ Q: Docker Swarmを使用するか？
   │  ├─ Yes → overlay ドライバー
   │  └─ No → サードパーティドライバーまたはSwarm導入を検討
   │
   └─ Q: 既存物理ネットワークと統合するか？
      ├─ Yes → macvlan ドライバー（promiscuous mode必須）
      └─ No → overlay ドライバー
```

---

このガイドは標準的なDockerネットワーキングのベストプラクティスをまとめたものです。具体的な環境に応じて設定を調整してください。
