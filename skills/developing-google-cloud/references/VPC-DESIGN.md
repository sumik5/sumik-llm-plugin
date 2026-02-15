# VPC 設計・実装（ネットワークアーキテクチャ）

Google Cloud の Virtual Private Cloud (VPC) は、グローバルなソフトウェア定義ネットワーク (SDN) であり、VM インスタンス、GKE クラスター、Cloud Run 等に接続性を提供する。本リファレンスでは VPC のアーキテクチャ設計、CIDR 計画、ルーティング、Shared VPC、VPC Peering、Cloud NAT、ファイアウォール実装を包括的に扱う。

## VPC アーキテクチャ設計

### グローバル VPC の特性

| 特性 | 説明 | 設計上の意味 |
|-----|------|------------|
| **グローバルリソース** | VPC はリージョンに紐づかない | 全リージョンで同一 VPC を使用可能 |
| **リージョナルサブネット** | サブネットはリージョンに紐づく | リージョンごとにサブネット設計が必要 |
| **グローバルルーティング** | デフォルトで全サブネット間ルーティング | 追加ルート設定不要（同一VPC内） |
| **リージョナルファイアウォール** | ルールは VPC 全体に適用 | タグ・サービスアカウントで制御 |

### VPC モード選択

#### Auto モード vs Custom モード

| 項目 | Auto モード | Custom モード |
|-----|-----------|-------------|
| **サブネット作成** | 各リージョンに自動作成 | 手動作成必須 |
| **CIDR レンジ** | 10.128.0.0/9 から自動割り当て | 任意の RFC1918 範囲 |
| **適用場面** | クイックプロトタイプ、検証環境 | 本番環境、ハイブリッド接続 |
| **IP 重複回避** | 困難（固定レンジ） | 完全制御可能 |
| **変換可否** | Auto→Custom のみ可能（不可逆） | - |

**推奨選択基準:**

| 条件 | 推奨モード | 理由 |
|-----|----------|------|
| オンプレミス接続あり | Custom | IP 重複回避必須 |
| 複数 VPC 間ピアリング | Custom | CIDR 計画必須 |
| 本番環境 | Custom | 拡張性・制御性 |
| 開発・検証環境のみ | Auto | 構築速度優先 |

### VPC 作成

**gcloud コマンド（Custom モード）:**

```bash
# VPC ネットワーク作成
gcloud compute networks create my-vpc \
  --subnet-mode=custom \
  --bgp-routing-mode=global \
  --description="Production VPC"

# サブネット作成
gcloud compute networks subnets create us-central1-sub \
  --network=my-vpc \
  --range=10.100.0.0/24 \
  --region=us-central1 \
  --enable-private-ip-google-access

gcloud compute networks subnets create asia-northeast1-sub \
  --network=my-vpc \
  --range=10.200.0.0/24 \
  --region=asia-northeast1 \
  --enable-private-ip-google-access
```

**Auto モードから Custom モードへの変換:**

```bash
# 不可逆操作（元に戻せない）
gcloud compute networks update my-vpc \
  --switch-to-custom-subnet-mode
```

## CIDR 計画・IP アドレッシング

### プライマリ CIDR レンジ

**有効な RFC1918 レンジ:**

| レンジ | CIDR | ホスト数（理論値） | 用途例 |
|-------|------|----------------|--------|
| 10.0.0.0/8 | 10.0.0.0 - 10.255.255.255 | 16,777,216 | 大規模エンタープライズ |
| 172.16.0.0/12 | 172.16.0.0 - 172.31.255.255 | 1,048,576 | 中規模組織 |
| 192.168.0.0/16 | 192.168.0.0 - 192.168.255.255 | 65,536 | 小規模環境 |

**GCP で使用禁止の範囲:**

| レンジ | 理由 |
|-------|------|
| 169.254.0.0/16 | リンクローカル（BGP ピアリング用） |
| 224.0.0.0/4 | マルチキャスト（未サポート） |
| 240.0.0.0/4 | 予約済み |
| 0.0.0.0/8 | 予約済み |

**各サブネットの予約 IP アドレス（4 つ）:**

| 用途 | アドレス例（10.100.0.0/24） | 説明 |
|-----|---------------------------|------|
| ネットワークアドレス | 10.100.0.0 | サブネット自体の識別子 |
| デフォルトゲートウェイ | 10.100.0.1 | VPC ルーター |
| DNS サーバー | 10.100.0.2 | Google 提供 DNS（169.254.169.254） |
| ブロードキャストアドレス | 10.100.0.255 | 予約（実際には未使用） |

### セカンダリ CIDR レンジ（Alias IP）

**用途:**

| 用途 | 説明 | 例 |
|-----|------|-----|
| **GKE Pod レンジ** | Pod に別 CIDR を割り当て | プライマリ: 10.100.0.0/24（Node）<br>セカンダリ: 10.101.0.0/16（Pod） |
| **GKE Service レンジ** | Kubernetes Service 用 | セカンダリ: 10.102.0.0/20（Service） |
| **マルチサービス VM** | 1 VM に複数 IP | Web: 10.100.0.10, DB: 10.103.0.10 |

**セカンダリレンジ追加:**

```bash
# サブネット作成時にセカンダリレンジを追加
gcloud compute networks subnets create gke-subnet \
  --network=my-vpc \
  --range=10.100.0.0/24 \
  --region=us-central1 \
  --secondary-range pods=10.101.0.0/16,services=10.102.0.0/20
```

### IP アドレス種別

| 種別 | スコープ | 用途 | 課金 |
|-----|---------|------|------|
| **内部 IP（エフェメラル）** | リージョン | VM デフォルト | 無料 |
| **内部 IP（静的）** | リージョン | 永続的な内部アドレス | 無料 |
| **外部 IP（エフェメラル）** | グローバル | 一時的な公開アクセス | 使用時のみ課金 |
| **外部 IP（静的）** | グローバル/リージョン | 永続的な公開アドレス | 未使用時も課金 |

**静的 IP 予約・割り当て:**

```bash
# 外部静的 IP を予約
gcloud compute addresses create web-ip \
  --region=us-central1

# VM に割り当て
gcloud compute instances create web-vm \
  --zone=us-central1-a \
  --subnet=us-central1-sub \
  --address=web-ip

# 内部静的 IP を予約
gcloud compute addresses create db-ip \
  --region=us-central1 \
  --subnet=us-central1-sub \
  --addresses=10.100.0.50
```

### Private Google Access

**概要:**
プライベート IP のみの VM が Google API（Cloud Storage、BigQuery 等）にアクセス可能にする機能。

**有効化:**

```bash
# サブネット作成時に有効化
gcloud compute networks subnets create private-sub \
  --network=my-vpc \
  --range=10.100.0.0/24 \
  --region=us-central1 \
  --enable-private-ip-google-access

# 既存サブネットで有効化
gcloud compute networks subnets update private-sub \
  --region=us-central1 \
  --enable-private-ip-google-access
```

**注意事項:**
- VM にパブリック IP がない場合でも Google API にアクセス可能
- インターネット一般へのアクセスには Cloud NAT が必要

## ルーティング

### ルーティングテーブルの種類

| ルート種別 | 優先度 | 作成タイミング | 用途 |
|----------|-------|-------------|------|
| **サブネットルート** | 0（最高） | サブネット作成時に自動 | VPC 内通信 |
| **デフォルトルート** | 1000 | VPC 作成時に自動 | インターネットへの出口 |
| **静的ルート** | 0-65535（設定可能） | 手動作成 | オンプレミス接続 |
| **動的ルート（BGP）** | 0-65535 | Cloud Router で自動 | ハイブリッド接続 |
| **ピアリングルート** | 0 | VPC Peering 時に自動 | VPC 間通信 |

### 動的ルーティングモード

| モード | スコープ | 用途 | 適用場面 |
|-------|---------|------|---------|
| **Regional** | Cloud Router と同一リージョンのみ | リージョン内限定 | 単一リージョン構成 |
| **Global** | VPC 全体 | 全リージョンでルート共有 | マルチリージョン構成 |

**動的ルーティングモード変更:**

```bash
# VPC 作成時に指定
gcloud compute networks create my-vpc \
  --bgp-routing-mode=global \
  --subnet-mode=custom

# 既存 VPC の変更
gcloud compute networks update my-vpc \
  --bgp-routing-mode=global
```

### 静的ルート設定

**用途:** オンプレミスネットワークへの固定ルート（Cloud VPN 経由）

**ルート作成:**

```bash
# デフォルトゲートウェイ経由のルート
gcloud compute routes create to-onprem-route \
  --network=my-vpc \
  --destination-range=10.0.10.0/24 \
  --next-hop-vpn-tunnel=vpn-tunnel-1 \
  --priority=1000

# インスタンス経由のルート
gcloud compute routes create via-nva-route \
  --network=my-vpc \
  --destination-range=192.168.0.0/16 \
  --next-hop-instance=nva-vm \
  --next-hop-instance-zone=us-central1-a
```

**優先度の制御:**

```bash
# プライマリルート（優先度高）
gcloud compute routes create primary-route \
  --network=my-vpc \
  --destination-range=10.0.10.0/24 \
  --next-hop-vpn-tunnel=dedicated-interconnect \
  --priority=100

# バックアップルート（優先度低）
gcloud compute routes create backup-route \
  --network=my-vpc \
  --destination-range=10.0.10.0/24 \
  --next-hop-vpn-tunnel=cloud-vpn \
  --priority=200
```

### Cloud Router と動的ルーティング（BGP）

**Cloud Router の役割:**
- Cloud VPN、Dedicated Interconnect、Partner Interconnect で BGP セッション確立
- オンプレミスルーターと IP プレフィックスを動的交換

**Cloud Router 作成:**

```bash
gcloud compute routers create my-router \
  --network=my-vpc \
  --region=us-central1 \
  --asn=65470
```

**BGP ピアリング設定（Cloud VPN 作成時）:**

```bash
# VPN ゲートウェイ作成
gcloud compute vpn-gateways create my-vpn-gw \
  --network=my-vpc \
  --region=us-central1

# BGP セッション設定付き VPN トンネル作成
gcloud compute vpn-tunnels create tunnel-to-onprem \
  --peer-address=203.0.113.10 \
  --region=us-central1 \
  --ike-version=2 \
  --shared-secret=mysecretkey \
  --router=my-router \
  --interface=0

# BGP ピアリング追加
gcloud compute routers add-bgp-peer my-router \
  --peer-name=onprem-peer \
  --peer-asn=65503 \
  --interface=0 \
  --peer-ip-address=169.254.0.2 \
  --ip-address=169.254.0.1 \
  --region=us-central1
```

**ASN 選択ガイド:**

| ASN 範囲 | 種別 | 用途 |
|---------|------|------|
| 64512-65534 | プライベート（16bit） | 小規模組織 |
| 4200000000-4294967294 | プライベート（32bit） | 大規模組織 |
| 1-64511, 65535-4199999999 | パブリック | インターネットルーティング（不使用） |

### Policy-Based Routing

**用途:** 特定の VM のみに異なるルートを適用

**タグベースルーティング:**

```bash
# タグ付き VM 用のルート作成
gcloud compute routes create tagged-route \
  --network=my-vpc \
  --destination-range=0.0.0.0/0 \
  --next-hop-instance=proxy-vm \
  --next-hop-instance-zone=us-central1-a \
  --tags=use-proxy

# VM 作成時にタグを付与
gcloud compute instances create app-vm \
  --zone=us-central1-a \
  --subnet=us-central1-sub \
  --tags=use-proxy
```

## Shared VPC vs VPC Peering

### 判断基準テーブル

| 基準 | Shared VPC | VPC Peering |
|-----|-----------|------------|
| **組織構造** | 同一組織内の複数プロジェクト | 任意（異なる組織でも可） |
| **ネットワーク管理** | 中央集約（ホストプロジェクト） | 分散管理（各プロジェクト独立） |
| **サブネット管理** | ホストプロジェクトのみ | 各 VPC で独立管理 |
| **ファイアウォール管理** | ホストプロジェクトで一元管理 | 各 VPC で独立管理 |
| **IP レンジ** | ホストが決定 | 重複不可（要調整） |
| **トランジティブピアリング** | 不要（全サブネット共有） | 不可（直接ピアリング必要） |
| **推奨用途** | 大規模エンタープライズ、マルチプロジェクト | 異なる組織間連携、部分的接続 |

### Shared VPC 実装

**前提条件:**
- 組織リソース必須
- ホストプロジェクトとサービスプロジェクトが必要

**ホストプロジェクト設定:**

```bash
# 組織レベルで Shared VPC 管理者を設定（組織管理者が実行）
gcloud organizations add-iam-policy-binding ORGANIZATION_ID \
  --member=user:admin@example.com \
  --role=roles/compute.xpnAdmin

# ホストプロジェクトを有効化
gcloud compute shared-vpc enable HOST_PROJECT_ID

# サービスプロジェクトをアタッチ
gcloud compute shared-vpc associated-projects add SERVICE_PROJECT_ID \
  --host-project=HOST_PROJECT_ID
```

**サブネット IAM 設定:**

```bash
# 特定サブネットへのアクセス権付与
gcloud compute networks subnets add-iam-policy-binding dev-subnet \
  --region=us-central1 \
  --member=serviceAccount:service-project-sa@SERVICE_PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/compute.networkUser
```

**アーキテクチャ例:**

```
ホストプロジェクト (host-project)
  └ Shared VPC (shared-vpc)
      ├ dev-subnet (10.100.0.0/24)  ← 開発プロジェクトが使用
      └ prod-subnet (10.200.0.0/24) ← 本番プロジェクトが使用

サービスプロジェクト 1 (dev-project)
  └ VM インスタンス → dev-subnet に配置

サービスプロジェクト 2 (prod-project)
  └ VM インスタンス → prod-subnet に配置
```

### VPC Peering 実装

**双方向ピアリング設定:**

```bash
# VPC-A 側からピアリング作成
gcloud compute networks peerings create peering-a-to-b \
  --network=vpc-a \
  --peer-network=vpc-b \
  --peer-project=project-b

# VPC-B 側からピアリング作成（必須）
gcloud compute networks peerings create peering-b-to-a \
  --network=vpc-b \
  --peer-network=vpc-a \
  --peer-project=project-a
```

**カスタムルートのエクスポート/インポート:**

```bash
# カスタムルートをエクスポート
gcloud compute networks peerings update peering-a-to-b \
  --network=vpc-a \
  --export-custom-routes

# ピア側でカスタムルートをインポート
gcloud compute networks peerings update peering-b-to-a \
  --network=vpc-b \
  --import-custom-routes
```

**制限事項:**
- トランジティブピアリング不可（A-B, B-C がピアリングされても A-C は通信不可）
- IP レンジの重複は不可
- 最大 25 ピアリング/VPC

## Cloud NAT

### 概要

Cloud NAT は、プライベート IP のみの VM がインターネットにアクセスするための SNAT (Source NAT) サービス。リージョナルサービスであり、Cloud Router に統合される。

### 用途

| 用途 | 説明 |
|-----|------|
| **OS パッケージ更新** | apt/yum リポジトリへのアクセス |
| **外部 API 呼び出し** | サードパーティサービスへのリクエスト |
| **セキュリティ強化** | 外部 IP 非公開による攻撃面縮小 |

### Cloud NAT 設定

**前提条件:**
- Cloud Router が必要（NAT ゲートウェイとして機能）

**Cloud NAT 作成:**

```bash
# Cloud Router 作成
gcloud compute routers create nat-router \
  --network=my-vpc \
  --region=us-central1

# Cloud NAT 作成
gcloud compute routers nats create my-nat \
  --router=nat-router \
  --region=us-central1 \
  --nat-all-subnet-ip-ranges \
  --auto-allocate-nat-external-ips
```

**高度な設定例:**

```bash
# 静的 IP を手動割り当て
gcloud compute addresses create nat-ip-1 nat-ip-2 \
  --region=us-central1

gcloud compute routers nats create my-nat \
  --router=nat-router \
  --region=us-central1 \
  --nat-all-subnet-ip-ranges \
  --nat-external-ip-pool=nat-ip-1,nat-ip-2 \
  --min-ports-per-vm=128 \
  --enable-logging \
  --log-filter=TRANSLATIONS_ONLY
```

### NAT 設定パラメータ

| パラメータ | デフォルト | 説明 | 推奨設定 |
|----------|----------|------|---------|
| **Minimum ports per VM** | 64 | VM ごとの最小ポート数 | 64-1024（同時接続数に応じて） |
| **Endpoint-Independent Mapping** | 無効 | 同一内部 IP+ポートを常に同一外部 IP+ポートにマップ | 有効推奨（ポート効率化） |
| **Logging** | 無効 | NAT ログを Cloud Logging に送信 | Translations のみ有効 |
| **UDP timeout** | 30s | UDP アイドルタイムアウト | 30-600s |
| **TCP established timeout** | 1200s | TCP 確立済みタイムアウト | 1200-7200s |
| **ICMP timeout** | 30s | ICMP タイムアウト | 30-60s |

### NAT ログ確認

```bash
# NAT トランスレーションログ確認
gcloud logging read \
  "resource.type=nat_gateway AND jsonPayload.connection.nat_ip!=''" \
  --limit 50 \
  --format json
```

## ファイアウォールルール

### ファイアウォールの基本概念

| 概念 | 説明 |
|-----|------|
| **ステートフル** | 戻りトラフィック用のルール不要 |
| **Egress 暗黙許可** | アウトバウンドはデフォルト許可 |
| **Ingress デフォルト拒否** | インバウンドは明示的許可必要 |
| **優先度制御** | 0-65535（小さいほど優先） |

### ファイアウォールルール作成

**基本的な Ingress ルール:**

```bash
# SSH 許可（特定 IP から）
gcloud compute firewall-rules create allow-ssh \
  --network=my-vpc \
  --allow=tcp:22 \
  --source-ranges=203.0.113.0/24 \
  --target-tags=ssh-enabled \
  --description="Allow SSH from corporate network"

# HTTPS 許可（全インターネットから）
gcloud compute firewall-rules create allow-https \
  --network=my-vpc \
  --allow=tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=web-server

# 内部通信許可
gcloud compute firewall-rules create allow-internal \
  --network=my-vpc \
  --allow=tcp,udp,icmp \
  --source-ranges=10.100.0.0/16
```

**Egress ルール（制限例）:**

```bash
# 特定 IP へのアクセスのみ許可
gcloud compute firewall-rules create deny-all-egress \
  --network=my-vpc \
  --action=deny \
  --rules=all \
  --destination-ranges=0.0.0.0/0 \
  --priority=65534 \
  --direction=EGRESS

gcloud compute firewall-rules create allow-specific-egress \
  --network=my-vpc \
  --action=allow \
  --rules=tcp:443 \
  --destination-ranges=203.0.113.50/32 \
  --priority=1000 \
  --direction=EGRESS \
  --target-tags=restricted-vm
```

### ターゲット指定方法

| 方法 | 用途 | 例 |
|-----|------|-----|
| **全インスタンス** | VPC 全体に適用 | デフォルト動作 |
| **ネットワークタグ** | 特定ロール VM に適用 | `--target-tags=web-server` |
| **サービスアカウント** | 特定 SA の VM に適用 | `--target-service-accounts=web-sa@project.iam.gserviceaccount.com` |

### 階層型ファイアウォールポリシー

**組織レベルのポリシー:**

```bash
# 組織ポリシー作成
gcloud compute firewall-policies create org-policy \
  --organization=ORGANIZATION_ID \
  --description="Organization-wide security policy"

# ルール追加
gcloud compute firewall-policies rules create 1000 \
  --firewall-policy=org-policy \
  --action=deny \
  --direction=INGRESS \
  --src-ip-ranges=192.0.2.0/24 \
  --layer4-configs=all \
  --organization=ORGANIZATION_ID

# フォルダにアタッチ
gcloud compute firewall-policies associations create \
  --firewall-policy=org-policy \
  --folder=FOLDER_ID \
  --organization=ORGANIZATION_ID
```

### ファイアウォールログ

```bash
# ログ有効化
gcloud compute firewall-rules update allow-ssh \
  --enable-logging

# ログ確認
gcloud logging read \
  "resource.type=gce_subnetwork AND jsonPayload.rule_details.reference='network:my-vpc/firewall:allow-ssh'" \
  --limit 50 \
  --format json
```

## GKE ネットワーク設計

### VPC-Native クラスタ（推奨）

**概要:**
Pod と Service に専用の CIDR レンジを割り当て、VPC ルーティングを活用する方式。

**メリット:**
- VPC Firewall で Pod レベル制御可能
- Cloud NAT、Private Google Access 使用可能
- オンプレミスから Pod に直接アクセス可能

**CIDR 計画例:**

| 用途 | CIDR | 割り当て数 | 備考 |
|-----|------|----------|------|
| **Node（プライマリ）** | 10.100.0.0/24 | 256 | VM 用 |
| **Pod（セカンダリ）** | 10.101.0.0/16 | 65,536 | /24 ごとに 256 Pod |
| **Service（セカンダリ）** | 10.102.0.0/20 | 4,096 | ClusterIP 用 |

**GKE クラスタ作成:**

```bash
# サブネット作成（セカンダリレンジ付き）
gcloud compute networks subnets create gke-subnet \
  --network=my-vpc \
  --range=10.100.0.0/24 \
  --region=us-central1 \
  --secondary-range=pods=10.101.0.0/16,services=10.102.0.0/20 \
  --enable-private-ip-google-access

# VPC-Native クラスタ作成
gcloud container clusters create my-cluster \
  --region=us-central1 \
  --network=my-vpc \
  --subnetwork=gke-subnet \
  --cluster-secondary-range-name=pods \
  --services-secondary-range-name=services \
  --enable-ip-alias \
  --enable-private-nodes \
  --master-ipv4-cidr=172.16.0.0/28
```

### IP アドレス消費量計算

**計算式:**

```
総 IP 数 = ノード数 × (1 + Pod/ノード)
```

**例:**

| クラスタ規模 | ノード数 | Pod/ノード | 必要 Pod CIDR | 推奨 CIDR |
|------------|---------|----------|-------------|----------|
| 小規模 | 10 | 32 | /21 (2,048 IPs) | /20 (4,096 IPs) |
| 中規模 | 50 | 64 | /17 (32,768 IPs) | /16 (65,536 IPs) |
| 大規模 | 200 | 110 | /14 (262,144 IPs) | /13 (524,288 IPs) |

### Private GKE クラスタ

**マスター承認済みネットワーク設定:**

```bash
# マスター API へのアクセス元を制限
gcloud container clusters update my-cluster \
  --region=us-central1 \
  --enable-master-authorized-networks \
  --master-authorized-networks=203.0.113.0/24,10.100.0.0/16
```

## VPC Flow Logs

### 有効化

```bash
# サブネット作成時に有効化
gcloud compute networks subnets create monitored-subnet \
  --network=my-vpc \
  --range=10.100.0.0/24 \
  --region=us-central1 \
  --enable-flow-logs \
  --logging-aggregation-interval=interval-5-sec \
  --logging-flow-sampling=0.5 \
  --logging-metadata=include-all

# 既存サブネットで有効化
gcloud compute networks subnets update monitored-subnet \
  --region=us-central1 \
  --enable-flow-logs
```

### Flow Logs 設定パラメータ

| パラメータ | オプション | 説明 | 推奨設定 |
|----------|----------|------|---------|
| **Aggregation Interval** | 5s, 30s, 1m, 5m, 10m, 15m | ログ集約間隔 | 5-30s（詳細分析）<br>5-15m（コスト削減） |
| **Sample Rate** | 0.0-1.0 | サンプリング率 | 0.5（50%）がバランス良 |
| **Metadata** | include-all, exclude-all, custom | メタデータ含有量 | include-all（分析用）<br>exclude-all（コスト削減） |

### Flow Logs 分析

```bash
# 特定 VM のトラフィック確認
gcloud logging read \
  "resource.type=gce_subnetwork AND jsonPayload.connection.src_ip='10.100.0.10'" \
  --limit 100 \
  --format json

# 外部への大量トラフィック検出
gcloud logging read \
  "resource.type=gce_subnetwork AND jsonPayload.bytes_sent>10000000" \
  --limit 50
```

## DNS 設計（ハイブリッド環境）

### DNS 名前付けパターン

| パターン | 例 | 用途 |
|---------|-----|------|
| **完全分離** | corp.example.com（オンプレ）<br>gcp.example.com（GCP） | 最も管理しやすい（推奨） |
| **GCP サブドメイン** | corp.example.com（オンプレ）<br>gcp.corp.example.com（GCP） | オンプレ資産が多い場合 |
| **オンプレサブドメイン** | corp.example.com（GCP）<br>dc.corp.example.com（オンプレ） | GCP 資産が多い場合 |

### Cloud DNS フォワーディングゾーン

**オンプレミス DNS へのフォワーディング:**

```bash
# フォワーディングゾーン作成
gcloud dns managed-zones create onprem-zone \
  --dns-name=corp.example.com \
  --description="Forward queries to on-premises DNS" \
  --networks=my-vpc \
  --forwarding-targets=192.168.1.10,192.168.1.11 \
  --visibility=private
```

### Cloud DNS インバウンドフォワーディング

**オンプレミスから GCP DNS へのクエリを受信:**

```bash
# DNS ポリシー作成
gcloud dns policies create inbound-policy \
  --description="Allow on-premises to query GCP DNS" \
  --networks=my-vpc \
  --enable-inbound-forwarding

# オンプレミス DNS サーバーの設定（例）
# 35.199.192.0/19 からのクエリを許可する firewall ルールを設定
```

**注意:**
- Cloud DNS は 35.199.192.0/19 からクエリを送信
- オンプレミスファイアウォールでこのレンジを許可必要

## トラブルシューティング

### 接続テスト

**Connectivity Tests（診断ツール）:**

```bash
# VM 間の接続性テスト
gcloud network-management connectivity-tests create test-vm1-to-vm2 \
  --source-instance=projects/PROJECT_ID/zones/us-central1-a/instances/vm1 \
  --destination-instance=projects/PROJECT_ID/zones/us-central1-b/instances/vm2 \
  --protocol=TCP \
  --destination-port=80

# 結果確認
gcloud network-management connectivity-tests describe test-vm1-to-vm2 \
  --format=json
```

### よくある問題と対処

| 問題 | 原因 | 対処方法 |
|-----|------|---------|
| VM 間通信不可（同 VPC） | ファイアウォールルール不足 | allow-internal ルール追加 |
| Private Google Access が動かない | サブネット設定未有効化 | `--enable-private-ip-google-access` 設定 |
| VPC Peering が Active にならない | 片方向のみ設定 | 双方向ピアリング設定 |
| Cloud NAT が動かない | Cloud Router 未設定 | Cloud Router 作成・NAT 関連付け |
| オンプレミス接続不可 | BGP セッション未確立 | ASN・IP アドレス設定確認 |

### ルート確認

```bash
# 有効なルート一覧
gcloud compute routes list \
  --filter="network=my-vpc" \
  --sort-by=priority

# 特定 VM のルート確認
gcloud compute instances describe vm1 \
  --zone=us-central1-a \
  --format="get(networkInterfaces[0].networkIP)"
```

## ベストプラクティス

### セキュリティ

| 原則 | 実装方法 |
|-----|---------|
| **最小権限の原則** | ファイアウォールで必要なポートのみ許可 |
| **外部 IP 最小化** | Cloud NAT 使用、Private Google Access 有効化 |
| **Shared VPC で集中管理** | 大規模組織では Shared VPC 採用 |
| **階層型ファイアウォール** | 組織レベルのベースラインポリシー設定 |
| **VPC Service Controls** | 機密データの外部流出防止 |

### 可用性

| 原則 | 実装方法 |
|-----|---------|
| **マルチリージョン配置** | 重要サービスは複数リージョンにデプロイ |
| **HA VPN** | 99.99% SLA の HA VPN 使用 |
| **動的ルーティング** | BGP で自動フェイルオーバー |
| **Cloud Load Balancing** | グローバル LB で自動トラフィック分散 |

### コスト最適化

| 原則 | 実装方法 |
|-----|---------|
| **静的外部 IP の削減** | 未使用の静的 IP を削除（課金対象） |
| **Cloud NAT でポート効率化** | Endpoint-Independent Mapping 有効化 |
| **Flow Logs サンプリング** | 0.5（50%）でコスト削減 |
| **リージョナル設計** | 不要な地域間トラフィック回避 |

## 設計チェックリスト

### VPC 作成前

- [ ] CIDR レンジ計画（オンプレミス・既存 VPC と重複なし）
- [ ] Auto/Custom モード選択
- [ ] リージョン配置決定
- [ ] 動的ルーティングモード選択（Regional/Global）

### サブネット設計

- [ ] プライマリ CIDR 計画（VM 用）
- [ ] セカンダリ CIDR 計画（GKE Pod/Service 用）
- [ ] Private Google Access 有効化判断
- [ ] Flow Logs 有効化判断

### ルーティング設計

- [ ] 静的ルート vs 動的ルート判断
- [ ] Cloud Router 配置（ハイブリッド接続時）
- [ ] BGP ASN 計画（オンプレミスと調整）

### ファイアウォール設計

- [ ] Ingress ルール設計（最小権限）
- [ ] Egress ルール設計（必要時）
- [ ] ターゲット指定方法（タグ/SA）
- [ ] 階層型ポリシー設計（組織レベル）

### Shared VPC / Peering 判断

- [ ] 組織構造確認
- [ ] 管理体制決定（集中 vs 分散）
- [ ] IP レンジ調整（Peering 時）

### Cloud NAT 設計

- [ ] NAT 必要性判断
- [ ] ポート数設定（min-ports-per-vm）
- [ ] ログ設定

### GKE ネットワーク設計

- [ ] VPC-Native クラスタ選択
- [ ] Pod CIDR サイジング
- [ ] Service CIDR サイジング
- [ ] Private クラスタ判断
