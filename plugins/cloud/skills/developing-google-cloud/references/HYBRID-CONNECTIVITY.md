# ハイブリッド接続（オンプレミスとGCPの相互接続）

Google Cloud VPCとオンプレミスネットワークを接続するためのハイブリッド接続ソリューション。本リファレンスでは、Cloud Interconnect（Dedicated/Partner）、IPsec VPN（Classic/HA）、Cloud Routerによる動的ルーティング、フェイルオーバー/DR設計を含む包括的なガイドを提供する。

## ハイブリッド接続オプション比較

| 接続方式 | 帯域幅 | SLA | 用途 | レイテンシ | 価格 |
|---------|--------|-----|------|----------|------|
| **Dedicated Interconnect** | 10Gbps/100Gbps（最大8本/2本） | 提供あり | ミッションクリティカル、高帯域 | 最低（<5ms可能） | 高（固定費+従量） |
| **Partner Interconnect** | 50Mbps～50Gbps | 提供あり | 柔軟な帯域、コロケーション不可 | 低～中 | 中（従量+SP費用） |
| **HA VPN** | 最大3Gbps/トンネル | 99.99%（2トンネル構成） | 高可用性要件 | 中（インターネット経由） | 低（従量のみ） |
| **Classic VPN** | 最大3Gbps/トンネル | なし | 開発環境、低コスト優先 | 中（インターネット経由） | 低（従量のみ） |
| **Direct Peering** | 10Gbps～（制限なし） | なし | Google APIアクセス、パブリック接続 | 低 | 無料（Egress課金のみ） |
| **Carrier Peering** | SP依存 | なし | Google APIアクセス、SP経由 | 中 | SP費用+Egress課金 |

### 選択基準

| 要件 | 推奨ソリューション |
|------|-------------------|
| 99.99% SLA必須 | Dedicated/Partner Interconnect（4接続構成）、HA VPN（2トンネル） |
| 10Gbps以上の帯域 | Dedicated Interconnect |
| コロケーション不可 | Partner Interconnect、HA VPN |
| 柔軟な帯域（50Mbps～50Gbps） | Partner Interconnect |
| 低コスト優先 | HA VPN、Classic VPN |
| Google APIのみアクセス | Direct Peering、Carrier Peering |
| RFC 1918プライベートIP交換 | Interconnect、VPN（Peeringは不可） |

## Cloud Interconnect 設計

### Dedicated Interconnect

**概要:**
オンプレミスルーターをGoogleエッジデバイスに物理的に直接接続する。コロケーション施設でVLAN attachmentを構成し、最高のパフォーマンスと信頼性を実現。

**技術要件:**
- 10GBASE-LR（1310nm）/ 100GBASE-LR4 シングルモード光ファイバー
- IPv4 link-local addressing（169.254.0.0/16）
- LACP（1回線でも必須）
- EBGP-4 with multi-hop
- IEEE 802.1Q VLAN

**帯域オプション:**
- 10Gbps Ethernet: 1～8リンク
- 100Gbps Ethernet: 1～2リンク

**コロケーション施設の確認:**

```bash
# 利用可能な施設リスト
# https://cloud.google.com/network-connectivity/docs/interconnect/concepts/choosing-colocation-facilities#locations-table

# 低レイテンシ保証施設（<5ms RTT）
# https://cloud.google.com/network-connectivity/docs/interconnect/concepts/choosing-colocation-facilities-low-latency#locations-table
```

**接続作成:**

```bash
# Dedicated Interconnect接続の注文
gcloud compute interconnects create my-interconnect \
  --customer-name="Company Name" \
  --interconnect-type=DEDICATED \
  --link-type=LINK_TYPE_ETHERNET_10G_LR \
  --location=las-zone1-770 \
  --requested-link-count=2 \
  --admin-enabled

# 接続ステータス確認
gcloud compute interconnects describe my-interconnect

# VLAN attachment作成（接続確立後）
gcloud compute interconnects attachments create my-vlan-attachment \
  --region=us-central1 \
  --router=my-cloud-router \
  --interconnect=my-interconnect \
  --vlan=100
```

**BGP設定例（Cloud Router側）:**

```bash
# Cloud Router作成
gcloud compute routers create my-cloud-router \
  --network=my-vpc \
  --region=us-central1 \
  --asn=65001

# BGPインターフェース追加
gcloud compute routers add-interface my-cloud-router \
  --interface-name=bgp-interface-0 \
  --interconnect-attachment=my-vlan-attachment \
  --ip-address=169.254.0.1 \
  --mask-length=30 \
  --region=us-central1

# BGPピア追加
gcloud compute routers add-bgp-peer my-cloud-router \
  --peer-name=on-prem-peer \
  --interface=bgp-interface-0 \
  --peer-ip-address=169.254.0.2 \
  --peer-asn=65002 \
  --region=us-central1
```

### Partner Interconnect

**概要:**
コロケーション不可の場合、サービスプロバイダー（SP）経由でGCPに接続。Layer 2（仮想Ethernet）またはLayer 3（IP接続）を選択可能。

**SP選定:**

```bash
# 利用可能なSPリスト
# https://cloud.google.com/network-connectivity/docs/interconnect/concepts/service-providers#by-provider

# SPに以下を確認:
# - Layer 2 / Layer 3対応
# - 帯域オプション（50Mbps～50Gbps）
# - ロケーション
# - SLA条件
# - 料金体系
```

**Layer 2 Partner Interconnect:**

オンプレミスルーターとCloud Router間で直接BGPピアリングを確立。

```bash
# Partner VLAN attachment作成
gcloud compute interconnects attachments partner create my-partner-attachment \
  --region=us-central1 \
  --router=my-cloud-router \
  --edge-availability-domain=AVAILABILITY_DOMAIN_1

# ペアリングキー取得（SPに提供）
gcloud compute interconnects attachments describe my-partner-attachment \
  --region=us-central1 \
  --format="value(pairingKey)"

# SP設定完了後、BGPピア設定（Dedicatedと同様）
gcloud compute routers add-bgp-peer my-cloud-router \
  --peer-name=partner-peer \
  --interface=partner-interface \
  --peer-ip-address=169.254.0.2 \
  --peer-asn=65002 \
  --region=us-central1
```

**Layer 3 Partner Interconnect:**

SPがCloud RouterとのBGPピアリングを管理。オンプレミス側はSPルーターとのみ接続。

```bash
# Layer 3 VLAN attachment作成
gcloud compute interconnects attachments partner create my-l3-attachment \
  --region=us-central1 \
  --router=my-cloud-router \
  --edge-availability-domain=AVAILABILITY_DOMAIN_1

# BGP設定はSPが実施
# オンプレミス側はSPルーターとのルーティング設定（BGP/OSPF/EIGRP/IS-IS等）
```

## IPsec VPN 設計・実装

### VPNオプション比較

| 項目 | Classic VPN | HA VPN |
|------|-------------|--------|
| ゲートウェイIP数 | 1 | 2（99.99% SLA用） |
| トンネル数 | 1～ | 2～（冗長化必須） |
| ルーティング | Static、Policy-based、Dynamic（BGP） | Dynamic（BGP）必須 |
| SLA | なし | 99.99%（2トンネル+BGP構成） |
| 推奨状況 | 廃止予定（非推奨） | 全環境で推奨 |

### HA VPN 設計

**99.99% SLA達成構成:**
- 2つのHA VPN gateway（各2 IP）
- 4つのIPsecトンネル（冗長構成）
- BGP動的ルーティング（Cloud Router必須）
- オンプレミス側も2つのVPNゲートウェイ

**HA VPN gateway作成:**

```bash
# HA VPN gateway作成（自動的に2つのIPアドレス割り当て）
gcloud compute vpn-gateways create my-ha-vpn-gateway \
  --network=my-vpc \
  --region=us-central1

# ゲートウェイ情報確認（2つのIP取得）
gcloud compute vpn-gateways describe my-ha-vpn-gateway \
  --region=us-central1 \
  --format="value(vpnInterfaces[0].ipAddress,vpnInterfaces[1].ipAddress)"
```

**Peer VPN gateway設定:**

```bash
# オンプレミス側VPN gateway登録（2インターフェース）
gcloud compute vpn-gateways create external-vpn-gateway my-peer-gateway \
  --peer-external-gateway-interface=0,ip-address=203.0.113.1 \
  --peer-external-gateway-interface=1,ip-address=203.0.113.2
```

**Cloud Router作成:**

```bash
# BGP用Cloud Router作成（プライベートASN使用）
gcloud compute routers create my-vpn-router \
  --network=my-vpc \
  --region=us-central1 \
  --asn=65001
```

**IPsecトンネル作成（4本）:**

```bash
# トンネル1: HA VPN interface0 → Peer interface0
gcloud compute vpn-tunnels create tunnel-1 \
  --peer-external-gateway=my-peer-gateway \
  --peer-external-gateway-interface=0 \
  --region=us-central1 \
  --ike-version=2 \
  --shared-secret=STRONG_PRE_SHARED_KEY_1 \
  --router=my-vpn-router \
  --vpn-gateway=my-ha-vpn-gateway \
  --interface=0

# トンネル2: HA VPN interface0 → Peer interface1
gcloud compute vpn-tunnels create tunnel-2 \
  --peer-external-gateway=my-peer-gateway \
  --peer-external-gateway-interface=1 \
  --region=us-central1 \
  --ike-version=2 \
  --shared-secret=STRONG_PRE_SHARED_KEY_2 \
  --router=my-vpn-router \
  --vpn-gateway=my-ha-vpn-gateway \
  --interface=0

# トンネル3: HA VPN interface1 → Peer interface0
gcloud compute vpn-tunnels create tunnel-3 \
  --peer-external-gateway=my-peer-gateway \
  --peer-external-gateway-interface=0 \
  --region=us-central1 \
  --ike-version=2 \
  --shared-secret=STRONG_PRE_SHARED_KEY_3 \
  --router=my-vpn-router \
  --vpn-gateway=my-ha-vpn-gateway \
  --interface=1

# トンネル4: HA VPN interface1 → Peer interface1
gcloud compute vpn-tunnels create tunnel-4 \
  --peer-external-gateway=my-peer-gateway \
  --peer-external-gateway-interface=1 \
  --region=us-central1 \
  --ike-version=2 \
  --shared-secret=STRONG_PRE_SHARED_KEY_4 \
  --router=my-vpn-router \
  --vpn-gateway=my-ha-vpn-gateway \
  --interface=1
```

**BGPセッション設定（4セッション）:**

```bash
# BGPセッション1（トンネル1）
gcloud compute routers add-interface my-vpn-router \
  --interface-name=bgp-tunnel-1 \
  --ip-address=169.254.0.1 \
  --mask-length=30 \
  --vpn-tunnel=tunnel-1 \
  --region=us-central1

gcloud compute routers add-bgp-peer my-vpn-router \
  --peer-name=bgp-peer-1 \
  --interface=bgp-tunnel-1 \
  --peer-ip-address=169.254.0.2 \
  --peer-asn=65002 \
  --region=us-central1

# BGPセッション2～4も同様に設定
# （各トンネルに対してインターフェース+ピア設定）
```

### Classic VPN（Route-based）

**注意:** Classic VPNは廃止予定。新規構築ではHA VPNを使用すること。

**Route-based VPN設定例:**

```bash
# 静的外部IPアドレス予約
gcloud compute addresses create vpn-gateway-ip \
  --region=us-central1

# Classic VPN gateway作成
gcloud compute target-vpn-gateways create classic-vpn-gateway \
  --network=my-vpc \
  --region=us-central1

# Forwarding rules作成（ESP、UDP 500、UDP 4500）
gcloud compute forwarding-rules create classic-vpn-rule-esp \
  --region=us-central1 \
  --ip-protocol=ESP \
  --address=vpn-gateway-ip \
  --target-vpn-gateway=classic-vpn-gateway

gcloud compute forwarding-rules create classic-vpn-rule-udp500 \
  --region=us-central1 \
  --ip-protocol=UDP \
  --ports=500 \
  --address=vpn-gateway-ip \
  --target-vpn-gateway=classic-vpn-gateway

gcloud compute forwarding-rules create classic-vpn-rule-udp4500 \
  --region=us-central1 \
  --ip-protocol=UDP \
  --ports=4500 \
  --address=vpn-gateway-ip \
  --target-vpn-gateway=classic-vpn-gateway

# VPNトンネル作成
gcloud compute vpn-tunnels create classic-vpn-tunnel \
  --region=us-central1 \
  --peer-address=203.0.113.1 \
  --shared-secret=STRONG_PRE_SHARED_KEY \
  --ike-version=2 \
  --target-vpn-gateway=classic-vpn-gateway \
  --local-traffic-selector=0.0.0.0/0 \
  --remote-traffic-selector=0.0.0.0/0

# 静的ルート追加（Route-based）
gcloud compute routes create vpn-route-to-onprem \
  --network=my-vpc \
  --destination-range=192.168.0.0/16 \
  --next-hop-vpn-tunnel=classic-vpn-tunnel \
  --next-hop-vpn-tunnel-region=us-central1
```

### IPsec VPN仕様

| 項目 | 対応仕様 |
|------|---------|
| **IKEバージョン** | IKEv1、IKEv2（推奨） |
| **認証方式** | Pre-shared key（PSK）のみ（RSA非対応） |
| **暗号化モード** | ESP in Tunnel mode（Transport mode非対応） |
| **NAT-T** | 対応（UDP 4500） |
| **MTU** | 1460 bytes（MSS調整推奨） |
| **帯域幅** | 最大3Gbps/トンネル |

## Cloud Router / BGP 設定

### Cloud Routerの役割

Cloud RouterはGCP上の完全マネージド型ルーティングサービス。物理デバイスではなくサービスとして提供され、BGP動的ルーティングにより以下を実現:
- オンプレミス↔VPC間のルート自動交換
- フェイルオーバー・DR自動化
- スケーラブルなルート管理

**必須となる場面:**
- Dedicated Interconnect VLAN attachment
- Partner Interconnect VLAN attachment
- HA VPN
- Cloud NAT

### 動的ルーティングモード

| モード | 動作 | 用途 |
|--------|------|------|
| **Regional** | Cloud Routerが所属するリージョンのサブネットのみ通知・学習 | 単一リージョン環境 |
| **Global** | VPC内の全リージョンのサブネットを通知・学習 | マルチリージョン環境 |

**VPCルーティングモード設定:**

```bash
# VPCをGlobal動的ルーティングに変更
gcloud compute networks update my-vpc \
  --bgp-routing-mode=GLOBAL

# 現在の設定確認
gcloud compute networks describe my-vpc \
  --format="value(routingConfig.routingMode)"
```

### BGP設定パラメータ

**プライベートASN範囲（RFC 6996）:**
- 64512～65534（16-bit）
- 4200000000～4294967294（32-bit）

**Cloud Router作成例:**

```bash
# 基本設定
gcloud compute routers create my-router \
  --network=my-vpc \
  --region=us-central1 \
  --asn=65001

# カスタムルートアドバタイズ設定
gcloud compute routers update my-router \
  --region=us-central1 \
  --advertisement-mode=CUSTOM \
  --set-advertisement-ranges=10.0.0.0/8,172.16.0.0/12
```

**BGPピア設定（MED値指定）:**

```bash
# BGPピア追加（Base Priority指定）
gcloud compute routers add-bgp-peer my-router \
  --peer-name=on-prem-peer \
  --interface=bgp-interface-0 \
  --peer-ip-address=169.254.0.2 \
  --peer-asn=65002 \
  --advertised-route-priority=100 \
  --region=us-central1
```

### BGP属性設定

| 属性 | 用途 | 設定方法 | 注意事項 |
|------|------|---------|---------|
| **MED（Multi-Exit Discriminator）** | ルート優先度制御 | `--advertised-route-priority` | 低い値が優先（Base Priority: 0-200） |
| **AS_PATH prepend** | パス長変更 | 単一Cloud Router内のみ | 複数Cloud Router間では無効 |
| **Regional Cost** | リージョン間コスト | 自動設定（201-9999） | ユーザー変更不可 |

**MED計算式:**
```
MED = Base Priority + Regional Cost（他リージョンのサブネット）
MED = Base Priority（ローカルサブネット）
```

**カスタムルートアドバタイズ例:**

```bash
# 特定プレフィックスのみ通知
gcloud compute routers update my-router \
  --region=us-central1 \
  --advertisement-mode=CUSTOM \
  --set-advertisement-ranges=10.128.0.0/20 \
  --set-advertisement-groups=ALL_SUBNETS
```

### BFD（Bidirectional Forwarding Detection）

高速な接続障害検出（デフォルトBGP keepalive: 60秒 → BFD: 1秒未満）。

```bash
# BFD有効化（BGPピア設定時）
gcloud compute routers add-bgp-peer my-router \
  --peer-name=on-prem-peer \
  --interface=bgp-interface-0 \
  --peer-ip-address=169.254.0.2 \
  --peer-asn=65002 \
  --enable-bfd \
  --bfd-session-initialization-mode=ACTIVE \
  --bfd-min-transmit-interval=1000 \
  --bfd-min-receive-interval=1000 \
  --bfd-multiplier=5 \
  --region=us-central1
```

## フェイルオーバー・DR戦略

### 99.99% SLA構成（Dedicated Interconnect）

**必須要件:**
- 4本のDedicated Interconnect接続（2都市圏×2接続）
- 各都市圏で異なるGoogle Edge可用性ドメイン使用
- 4つのCloud Router（2リージョン×2ルーター）
- Global動的ルーティングモード
- オンプレミス側も2ゲートウェイ/リージョン

**設計例（us-central1 / us-east1）:**

```bash
# us-central1 Cloud Router 1
gcloud compute routers create us-central1-router-1 \
  --network=my-vpc \
  --region=us-central1 \
  --asn=65001

# us-central1 Cloud Router 2
gcloud compute routers create us-central1-router-2 \
  --network=my-vpc \
  --region=us-central1 \
  --asn=65001

# us-east1 Cloud Router 1
gcloud compute routers create us-east1-router-1 \
  --network=my-vpc \
  --region=us-east1 \
  --asn=65001

# us-east1 Cloud Router 2
gcloud compute routers create us-east1-router-2 \
  --network=my-vpc \
  --region=us-east1 \
  --asn=65001

# BGPピア設定（各ルーターに対してBase Priority調整）
# us-central1: Base Priority 100（Active）
# us-east1: Base Priority 100 + Regional Cost（Backup）
```

**トラフィック制御（MED使用）:**

| 送信元 | 宛先サブネット | 優先ルート | MED値 | 役割 |
|--------|--------------|-----------|-------|------|
| オンプレミス | us-central1サブネット | us-central1-router | 100 | Active |
| オンプレミス | us-central1サブネット | us-east1-router | 100 + Regional Cost | Backup |
| オンプレミス | us-east1サブネット | us-east1-router | 100 | Active |
| オンプレミス | us-east1サブネット | us-central1-router | 100 + Regional Cost | Backup |

### マルチリージョンHA VPN構成

**アーキテクチャ:**
- 2リージョン×HA VPN gateway（各2 IP）
- 4つのCloud Router
- Global動的ルーティング
- アクティブ/アクティブ構成（地域トラフィックは地域ゲートウェイ経由）

**設定例（us-central1 / europe-west1）:**

```bash
# Global動的ルーティング有効化
gcloud compute networks update my-vpc \
  --bgp-routing-mode=GLOBAL

# us-central1 HA VPN
gcloud compute vpn-gateways create us-vpn-gateway \
  --network=my-vpc \
  --region=us-central1

gcloud compute routers create us-vpn-router \
  --network=my-vpc \
  --region=us-central1 \
  --asn=65001

# europe-west1 HA VPN
gcloud compute vpn-gateways create eu-vpn-gateway \
  --network=my-vpc \
  --region=europe-west1

gcloud compute routers create eu-vpn-router \
  --network=my-vpc \
  --region=europe-west1 \
  --asn=65001

# BGPピア設定（Base Priority調整）
# 各ルーターはローカルサブネットに対してMED=100
# リモートサブネットに対してMED=100+Regional Cost
```

### Partner Interconnect DR設計

**Layer 2冗長構成:**
- 4つのVLAN attachment（各SP peering edge）
- 4つのCloud Router
- Global動的ルーティング
- SP MPLS L2ネットワーク経由の仮想Ethernet

**Layer 3冗長構成:**
- SP側でCloud RouterとのBGPピアリング管理
- オンプレミス↔SPルーター間は任意のルーティングプロトコル可（BGP/OSPF/EIGRP/IS-IS）
- MEDベースのフェイルオーバー制御

## DNS連携（Cloud DNS）

### DNS forwarding（オンプレミス→GCP）

オンプレミスからGCP内プライベートゾーンの名前解決。

```bash
# DNS転送ポリシー作成
gcloud dns policies create on-prem-forward-policy \
  --networks=my-vpc \
  --enable-inbound-forwarding \
  --description="Allow on-prem to resolve GCP private zones"

# インバウンド転送エントリーポイント確認
gcloud compute addresses list \
  --filter="purpose:DNS_RESOLVER" \
  --format="table(address,region)"

# オンプレミスDNSサーバーに条件付き転送設定
# 例: *.gcp.internal → GCP DNS Resolver IP（35.199.192.0/19範囲）
```

### DNS peering（VPC間）

異なるVPC間でプライベートゾーンを共有。

```bash
# Peering zone作成（VPC-AからVPC-Bのゾーンを参照）
gcloud dns managed-zones create peer-zone \
  --description="Peer to VPC-B private zone" \
  --dns-name=vpc-b.internal. \
  --networks=vpc-a \
  --target-network=vpc-b \
  --visibility=private
```

## トラブルシューティング

### Interconnect接続確認

```bash
# Interconnect接続ステータス
gcloud compute interconnects describe my-interconnect \
  --format="value(operationalStatus,state)"

# VLAN attachment確認
gcloud compute interconnects attachments describe my-vlan-attachment \
  --region=us-central1 \
  --format="value(state,vlanTag8021q)"

# Cloud RouterのBGPセッション状態
gcloud compute routers get-status my-cloud-router \
  --region=us-central1 \
  --format="table(result.bgpPeerStatus[].name,result.bgpPeerStatus[].state)"
```

### VPNトンネル診断

```bash
# トンネルステータス確認
gcloud compute vpn-tunnels describe tunnel-1 \
  --region=us-central1 \
  --format="value(status,detailedStatus)"

# BGPセッション確認
gcloud compute routers get-status my-vpn-router \
  --region=us-central1 \
  --format="json" | jq '.result.bgpPeerStatus[]'

# トンネルメトリクス
gcloud monitoring time-series list \
  --filter='metric.type="compute.googleapis.com/vpn/tunnel_established"' \
  --format="table(metric.labels.tunnel_name,points[0].value.boolValue)"
```

### ルーティング確認

```bash
# VPC内有効ルート一覧
gcloud compute routes list \
  --filter="network:my-vpc" \
  --format="table(name,destRange,nextHopGateway,priority)"

# Cloud Routerが学習したルート
gcloud compute routers get-status my-cloud-router \
  --region=us-central1 \
  --format="table(result.bestRoutes[].destRange,result.bestRoutes[].nextHopIp)"

# 特定インスタンスの有効ルート
gcloud compute instances describe my-instance \
  --zone=us-central1-a \
  --format="value(networkInterfaces[0].network)" | \
  xargs -I {} gcloud compute routes list --filter="network:{}"
```

### よくある問題と対処

| 問題 | 原因 | 対処方法 |
|------|------|---------|
| BGPセッションがESTABLISHしない | ASN不一致、Link-local IP設定ミス | Cloud Router設定確認、ピアASN検証 |
| トンネルステータスがDOWN | Pre-shared key不一致、ファイアウォール | PSK再確認、UDP 500/4500許可 |
| ルートが伝播しない | Regional動的ルーティング、カスタムアドバタイズ | Global modeに変更、アドバタイズ設定確認 |
| 片方向通信のみ可能 | 非対称ルーティング、FW設定 | 双方向ルート確認、オンプレミスFW許可 |
| レイテンシが高い | 不適切なルート選択、リージョン配置 | MED調整、ピアリング場所見直し |

### パフォーマンス監視

```bash
# Interconnect帯域使用率
gcloud monitoring time-series list \
  --filter='metric.type="compute.googleapis.com/interconnect/capacity/utilization"' \
  --format="table(metric.labels.interconnect_name,points[0].value.doubleValue)"

# VPNトンネル帯域
gcloud monitoring time-series list \
  --filter='metric.type="compute.googleapis.com/vpn/tunnel_throughput"' \
  --format="table(metric.labels.tunnel_name,points[0].value.doubleValue)"

# BGPセッション数
gcloud compute routers get-status my-cloud-router \
  --region=us-central1 \
  --format="value(result.bgpPeerStatus.length())"
```
