# GCP ネットワークセキュリティリファレンス

GCPネットワークセキュリティの実践的設計判断・構成パターン・セキュリティベストプラクティス。

---

## VPC基礎

### Global VPC（Andromeda SDN）

| 特性 | 説明 |
|------|------|
| スコープ | グローバルリソース（routes、firewall rulesも含む） |
| サブネット | リージョナルリソース（ゾーンをまたぐ） |
| SDN実装 | Andromeda（Google内製SDN） |
| IPv6 | カスタムサブネットで有効化可能（auto modeはdual-stack非対応） |
| 内部通信 | VPC内のIPv4リソースは追加ルールなしで通信可能 |

### ネットワークティア選択

| ティア | トラフィック経路 | 使用ケース |
|--------|----------------|-----------|
| **Premium** | Googleプライベートネットワーク経由（最寄りPoP→暗号化専用線） | グローバル展開、低レイテンシ、高信頼性要求 |
| **Standard** | インターネット経由（hot potato routing） | コスト最適化、リージョナル展開 |

**判断基準**: Premium Tierはグローバルロードバランサー必須。Standard Tierはリージョナルのみ対応。

---

## サブネット設計

### CIDR範囲タイプ

```
VPC (Global)
├── Region A
│   ├── Subnet 1 (Primary CIDR: 10.1.0.0/24)    # VM/LB用
│   │   └── Secondary CIDR: 10.1.128.0/24       # コンテナ/GKE Pod用
│   └── Subnet 2 (Primary CIDR: 10.2.0.0/24)
└── Region B
    └── Subnet 3 (Primary CIDR: 10.3.0.0/24)
```

| CIDR種別 | 用途 | 拡張 |
|---------|------|------|
| **Primary** | VM、ロードバランサー | 拡張可能（縮小不可） |
| **Secondary** | コンテナ、GKE Pods、マイクロサービス | **拡張不可（固定）** |

**ベストプラクティス**:
- VPCモードは**カスタムモード**推奨（IPレンジ制御、ピアリング対応）
- Auto modeは全リージョンで`10.128.0.0/9`固定（IP重複リスク）
- 類似アプリは少数の大きなサブネットに集約（管理簡素化）

---

## ファイアウォールルール

### 基本特性

| 特性 | 説明 |
|------|------|
| ステートフル | ingress denyを設定すれば対応するegress deny不要 |
| 適用レベル | VMインターフェース（ホストレベル実装） |
| デフォルト | ingress全拒否、egress全許可（削除不可） |
| 例外 | egress port 25（SMTP）常時拒否、metadataサーバー（169.254.169.254）常時許可 |

### ルール評価ロジック

```
リクエスト受信
    ↓
Priority順（0-65535、小さいほど優先）でマッチ検索
    ↓
最初にマッチしたルール適用（allow/deny）
    ↓
マッチなし → デフォルトルール（priority 2147483647）
```

### ルール設定パターン

#### 5-tuple（基本）
```bash
gcloud compute firewall-rules create allow-ssh \
  --network=my-vpc \
  --allow=tcp:22 \
  --source-ranges=10.0.0.0/8 \
  --direction=INGRESS \
  --priority=1000
```

#### ネットワークタグベース（推奨）
```bash
gcloud compute firewall-rules create allow-web \
  --network=my-vpc \
  --allow=tcp:80,tcp:443 \
  --target-tags=web-server \
  --source-tags=lb-frontend \
  --direction=INGRESS
```

**注意**: タグは任意属性。Instance Admin権限を持つユーザーは自由にタグ変更可能。

#### サービスアカウントベース（最も安全）
```bash
gcloud compute firewall-rules create allow-db \
  --network=my-vpc \
  --allow=tcp:5432 \
  --target-service-accounts=db-sa@project.iam.gserviceaccount.com \
  --source-service-accounts=app-sa@project.iam.gserviceaccount.com \
  --direction=INGRESS
```

**セキュリティ比較**:
| 方式 | セキュリティ | 管理容易性 | 使用ケース |
|------|------------|-----------|-----------|
| 5-tuple | 低 | 高 | テスト環境、単純な構成 |
| ネットワークタグ | 中 | 中 | 開発環境、動的構成 |
| サービスアカウント | **高** | 低 | 本番環境、厳格なアクセス制御 |

### ログ有効化（監査用）

```bash
gcloud compute firewall-rules update my-rule \
  --enable-logging \
  --logging-metadata=include-all
```

---

## 階層型ファイアウォールポリシー

| レベル | スコープ | 優先度 | 使用ケース |
|--------|---------|-------|-----------|
| **Organization** | 全組織 | 最高 | 組織全体のセキュリティベースライン |
| **Folder** | フォルダ配下 | 中 | 部門・環境別ポリシー |
| **Project（VPC）** | プロジェクト | 最低 | プロジェクト固有ルール |

**評価順序**: Organization → Folder → VPC（上位で拒否されたら下位ルールは無視）

```bash
# Organization Policy作成例
gcloud compute firewall-policies create org-baseline \
  --organization=123456789

gcloud compute firewall-policies rules create 1000 \
  --firewall-policy=org-baseline \
  --action=deny \
  --direction=INGRESS \
  --src-ip-ranges=0.0.0.0/0 \
  --layer4-configs=tcp:22 \
  --description="組織全体でSSH公開アクセス拒否"
```

---

## VPCデプロイメントモデル

### Shared VPC（推奨）

```
Organization
└── Host Project（ネットワーク集約管理）
    ├── VPC Network（共有）
    │   ├── Subnet A (us-central1)
    │   └── Subnet B (us-east1)
    ├── Service Project 1（アプリA）
    ├── Service Project 2（アプリB）
    └── Service Project 3（アプリC）
```

**IAMロール**:
| ロール | 権限 | 付与先 |
|--------|------|-------|
| `compute.xpnAdmin` + `resourcemanager.projectIAMAdmin` | Shared VPC管理 | 組織管理者 → ネットワーク管理者 |
| `compute.networkUser` | サブネット使用権 | Shared VPC Admin → Service Project Admin |

**権限付与スコープ**:
- **全サブネット共有**: プロジェクトレベル権限
- **特定サブネット共有**: サブネットレベル権限（細かい制御）

**制限事項**:
- 1 Service Project = 1 Host Projectのみ
- 最大100 Service Projects per Host Project

**設定例**:
```bash
# Host Project有効化
gcloud compute shared-vpc enable HOST_PROJECT_ID

# Service Project紐付け
gcloud compute shared-vpc associated-projects add SERVICE_PROJECT_ID \
  --host-project=HOST_PROJECT_ID

# サービスアカウントに権限付与（全サブネット）
gcloud projects add-iam-policy-binding HOST_PROJECT_ID \
  --member=serviceAccount:SA_NAME@SERVICE_PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/compute.networkUser
```

### VPC Peering

```
Project A (VPC-A: 10.1.0.0/16) ←→ Project B (VPC-B: 10.2.0.0/16)
                                Peering
```

**使用ケース**:
- 組織間接続
- SaaSプロバイダーのプライベートサービス公開

**特性**:
| 項目 | 説明 |
|------|------|
| 管理 | 各VPCは独立（firewall、routes、subnetsは個別管理） |
| 設定 | 双方向設定必須（両側で承認が必要） |
| ルート交換 | 静的・動的ルート両対応 |
| トランジティブ | **非対応**（直接ピアのみ通信可能） |

**制約**:
- IP重複不可
- サブネットルート選択不可（全ルート自動交換）
- タグ・サービスアカウント跨ぎ使用不可
- 内部DNS名前解決不可

**設定例**:
```bash
# VPC-A側（Project A）
gcloud compute networks peerings create peer-to-b \
  --network=vpc-a \
  --peer-project=PROJECT_B_ID \
  --peer-network=vpc-b \
  --auto-create-routes

# VPC-B側（Project B）
gcloud compute networks peerings create peer-to-a \
  --network=vpc-b \
  --peer-project=PROJECT_A_ID \
  --peer-network=vpc-a \
  --auto-create-routes
```

**カスタムルート交換**:
```bash
# エクスポート有効化
gcloud compute networks peerings update peer-to-b \
  --network=vpc-a \
  --export-custom-routes

# インポート有効化
gcloud compute networks peerings update peer-to-a \
  --network=vpc-b \
  --import-custom-routes
```

### クロスプロジェクト通信比較

| | Shared VPC | VPC Peering | 外部IP経由 |
|---|-----------|------------|-----------|
| 管理 | 集中管理 | 分散管理 | 分散管理 |
| スケール | 高（最大100 projects） | 中（ピア数制限） | 低 |
| コスト | 内部料金 | 内部料金 | egress課金 |
| パフォーマンス | 最高 | 高 | 中 |
| セキュリティ | 最高（集中制御） | 高（個別制御） | 低（インターネット経由） |

---

## VPC Service Controls

### Service Perimeter（サービス境界）

```
Organization
└── Access Policy
    └── Service Perimeter
        ├── Protected Projects
        │   ├── Project A（BigQuery）
        │   └── Project B（Cloud Storage）
        ├── Restricted Services
        │   ├── bigquery.googleapis.com
        │   └── storage.googleapis.com
        └── Access Levels
            ├── Corporate IP範囲: 203.0.113.0/24
            ├── Device Policy: OS patch適用済み
            └── User Identity: @example.com
```

**使用ケース**:
- データ流出防止（GCS、BigQueryなど機密データを含むサービス保護）
- コンプライアンス要件（GDPR、HIPAA等）
- インサイダー脅威対策

**設定例**:
```bash
# Access Policy作成
gcloud access-context-manager policies create \
  --organization=ORG_ID \
  --title="My Policy"

# Access Level作成（IP制限）
gcloud access-context-manager levels create corporate_network \
  --policy=POLICY_ID \
  --basic-level-spec=ip_subnetworks=203.0.113.0/24

# Service Perimeter作成
gcloud access-context-manager perimeters create my_perimeter \
  --policy=POLICY_ID \
  --resources=projects/PROJECT_A,projects/PROJECT_B \
  --restricted-services=bigquery.googleapis.com,storage.googleapis.com \
  --access-levels=corporate_network
```

---

## Private Google Access / Private Service Connect

### Private Google Access（サブネット設定）

**目的**: 外部IPなしVMからGoogle APIs（storage.googleapis.com等）へのプライベートアクセス

**設定要件**:
| 要件 | 説明 |
|------|------|
| VM | プライマリ内部IPまたはエイリアスIP使用 |
| サブネット | Private Google Access有効化 |
| DNS | `private.googleapis.com`または`restricted.googleapis.com`解決設定 |
| ルート | `0.0.0.0/0` → default-internet-gateway（Google内部ルーティング） |
| Firewall | Google APIレンジへのegress許可 |

**DNS設定（Cloud DNS）**:
```bash
# プライベートゾーン作成
gcloud dns managed-zones create googleapis \
  --dns-name=googleapis.com \
  --networks=my-vpc \
  --visibility=private

# Aレコード作成（private.googleapis.com）
gcloud dns record-sets create private.googleapis.com. \
  --zone=googleapis \
  --type=A \
  --ttl=300 \
  --rrdatas=199.36.153.8,199.36.153.9,199.36.153.10,199.36.153.11

# CNAMEレコード作成
gcloud dns record-sets create *.googleapis.com. \
  --zone=googleapis \
  --type=CNAME \
  --ttl=300 \
  --rrdatas=private.googleapis.com.
```

**サブネット設定**:
```bash
gcloud compute networks subnets update SUBNET_NAME \
  --region=REGION \
  --enable-private-ip-google-access
```

### Private Service Connect（エンドポイント作成）

**目的**: 特定サービス（Cloud SQL、Memorystore等）へのプライベート接続

```bash
# 内部IPアドレス予約
gcloud compute addresses create psc-endpoint \
  --region=us-central1 \
  --subnet=my-subnet \
  --purpose=PRIVATE_SERVICE_CONNECT

# PSC Endpoint作成
gcloud compute forwarding-rules create my-psc-endpoint \
  --region=us-central1 \
  --network=my-vpc \
  --address=psc-endpoint \
  --target-service-attachment=projects/SERVICE_PROJECT/regions/REGION/serviceAttachments/SERVICE_NAME
```

---

## Cloud DNS / DNSSEC

### DNS設定パターン

| ゾーンタイプ | 使用ケース | 設定例 |
|------------|-----------|--------|
| **Public** | 外部公開ドメイン | example.com → 外部IP |
| **Private** | VPC内部名前解決 | internal.example.com → 10.1.0.5 |
| **Forwarding** | オンプレミス連携 | corp.local → オンプレDNS（10.0.0.53） |
| **Peering** | VPC間DNS共有 | VPC-A ←→ VPC-B（transitive 2-hop対応） |

**DNSSEC有効化**:
```bash
gcloud dns managed-zones create secure-zone \
  --dns-name=example.com \
  --dnssec-state=on
```

**重要**: レジストラとレジストリがDNSSEC対応必須。DSレコード追加不可の場合、DNSSEC無効。

---

## ロードバランシング

### タイプ別使用ケース

| LB種別 | OSI Layer | スコープ | プロトコル | 使用ケース |
|--------|----------|---------|-----------|-----------|
| **External HTTP(S)** | L7 | Global（Premium）/Regional（Standard） | HTTP/HTTPS/HTTP2 | Webアプリ、API Gateway |
| **External TCP/UDP** | L4 | Regional | TCP/UDP | 任意TCPアプリ、ゲームサーバー |
| **SSL Proxy** | L4 | Global/Regional | SSL/TLS | SSL終端、非HTTP SSL通信 |
| **TCP Proxy** | L4 | Global/Regional | TCP | TCP終端、グローバル負荷分散 |
| **Internal HTTP(S)** | L7 | Regional | HTTP/HTTPS | マイクロサービス間通信（Envoy） |
| **Internal TCP/UDP** | L4 | Regional | TCP/UDP | 3-tier構成（Web→App→DB） |

### 決定ツリー

```
トラフィック元は？
├─ インターネット → External LB
│   ├─ HTTP(S)? → External HTTP(S) LB
│   ├─ SSL? → SSL Proxy LB
│   └─ TCP/UDP? → TCP Proxy LB or Regional TCP/UDP LB
└─ VPC内部 → Internal LB
    ├─ HTTP(S)? → Internal HTTP(S) LB
    └─ TCP/UDP? → Internal TCP/UDP LB

グローバル展開？
├─ Yes → Premium Tier + Global LB
└─ No → Standard Tier + Regional LB
```

### TLS設定（HTTP(S) LB）

```bash
# Google管理証明書
gcloud compute ssl-certificates create my-cert \
  --domains=example.com

# 自己管理証明書
gcloud compute ssl-certificates create my-cert \
  --certificate=cert.pem \
  --private-key=key.pem

# Target HTTPS Proxy設定
gcloud compute target-https-proxies create my-proxy \
  --ssl-certificates=my-cert \
  --url-map=my-url-map
```

---

## Cloud Armor（WAF / DDoS Protection）

### 保護レイヤー

| レイヤー | 自動保護 | カスタム設定 |
|---------|---------|------------|
| **L3/L4** | ✅ DNS amplification, SYN flood, Slowloris | - |
| **L7** | - | ✅ WAFルール、IP allow/deny、geo-blocking、rate limiting |

### セキュリティポリシータイプ

| ポリシー | 適用先 | 機能 |
|---------|-------|------|
| **Backend** | Instance groups、NEGs | WAFルール、rate limiting、reCAPTCHA、adaptive protection |
| **Edge** | Cloud CDN | IP/geo filtering（キャッシュコンテンツ保護） |

**優先順位**: Edge Policy → IAP → Backend Policy

### 事前定義WAFルール（OWASP ModSecurity CRS 3.0ベース）

```bash
# SQLインジェクション保護
gcloud compute security-policies rules create 1000 \
  --security-policy=my-policy \
  --expression="evaluatePreconfiguredExpr('sqli-v33-stable')" \
  --action=deny-403

# XSS保護
gcloud compute security-policies rules create 1100 \
  --security-policy=my-policy \
  --expression="evaluatePreconfiguredExpr('xss-v33-stable')" \
  --action=deny-403

# 複数脅威統合
gcloud compute security-policies rules create 1200 \
  --security-policy=my-policy \
  --expression="evaluatePreconfiguredExpr('owasp-crs-v030301-id942251-sqli', ['owasp-crs-v030301-id941330-xss'])" \
  --action=deny-403
```

### カスタムルール（CEL式）

```bash
# IPレンジ + User-Agent制限
gcloud compute security-policies rules create 2000 \
  --security-policy=my-policy \
  --expression="inIpRange(origin.ip, '192.0.2.0/24') && \
                has(request.headers['user-agent']) && \
                request.headers['user-agent'].contains('WordPress')" \
  --action=deny-403

# Geo-blocking（AU以外拒否）
gcloud compute security-policies rules create 3000 \
  --security-policy=my-policy \
  --expression="origin.region_code != 'AU'" \
  --action=deny-403
```

### Rate Limiting

```bash
gcloud compute security-policies rules create 4000 \
  --security-policy=my-policy \
  --expression="true" \
  --action=rate-based-ban \
  --rate-limit-threshold-count=100 \
  --rate-limit-threshold-interval-sec=60 \
  --ban-duration-sec=600 \
  --conform-action=allow \
  --exceed-action=deny-429
```

### Named IP Lists（サードパーティIP管理）

```bash
# CloudFlare CDN IP許可
gcloud compute security-policies rules create 5000 \
  --security-policy=my-policy \
  --expression="evaluatePreconfiguredExpr('cloudflare-ip-list')" \
  --action=allow
```

---

## Cloud NAT

### 基本特性

| 項目 | 説明 |
|------|------|
| スコープ | リージョナル |
| アーキテクチャ | 分散SDN（中間Proxyなし、ホストレベル実装） |
| 制約 | Outbound専用（Inbound不可、応答のみ許可） |
| 依存 | デフォルトインターネットルート（0.0.0.0/0 → default-internet-gateway） |

**NAT不実施ケース**:
- VM外部IP保有
- デフォルトルート変更済み
- LBプロキシ ↔ バックエンドVM通信
- Private Google Access使用時

### 設定例

```bash
# Cloud Router作成
gcloud compute routers create my-router \
  --network=my-vpc \
  --region=us-central1

# NAT Gateway作成
gcloud compute routers nats create my-nat \
  --router=my-router \
  --region=us-central1 \
  --nat-all-subnet-ip-ranges \
  --auto-allocate-nat-external-ips
```

**IP割り当て戦略**:
| 方式 | 使用ケース |
|------|-----------|
| `--auto-allocate-nat-external-ips` | Google自動割り当て（推奨） |
| `--nat-external-ip-pool=IP1,IP2` | 特定IP固定（ホワイトリスト要求時） |

---

## ハイブリッド接続

### Cloud VPN（IPSec）

**仕様**:
- 帯域: 1.5-3 Gbps/tunnel（peer locationで変動）
- マルチトンネル対応
- プロトコル: IPSec/IKE
- HA構成: 2インターフェースゲートウェイ

**設定例**:
```bash
# HA VPN Gateway作成
gcloud compute vpn-gateways create my-vpn-gateway \
  --network=my-vpc \
  --region=us-central1

# Cloud Router作成
gcloud compute routers create my-router \
  --network=my-vpc \
  --region=us-central1 \
  --asn=65001

# VPNトンネル作成
gcloud compute vpn-tunnels create tunnel-1 \
  --peer-gcp-gateway=PEER_GATEWAY \
  --region=us-central1 \
  --ike-version=2 \
  --shared-secret=SECRET \
  --router=my-router \
  --vpn-gateway=my-vpn-gateway \
  --interface=0

# BGP Peer設定
gcloud compute routers add-bgp-peer my-router \
  --peer-name=bgp-peer-1 \
  --peer-asn=65002 \
  --interface=tunnel-1 \
  --region=us-central1
```

### Cloud Interconnect（専用線）

**仕様**:
- 帯域: 10 Gbps x8 or 100 Gbps x2
- レイテンシ: 低（専用線）
- コスト: egress削減
- 暗号化: なし（VPN over Interconnect非対応、自己管理VPN可）

**構成要素**:
```
オンプレミス
├── Router 1 ─┬─ Colo 1 (Metro Area)
│             │   └── VLAN Attachment 1 → Cloud Router 1 (us-west1)
└── Router 2 ─┴─ Colo 2 (Metro Area)
                  └── VLAN Attachment 2 → Cloud Router 2 (us-west1)
```

**設定例**:
```bash
# Interconnect Attachment作成
gcloud compute interconnects attachments dedicated create my-attachment \
  --region=us-central1 \
  --router=my-router \
  --interconnect=my-interconnect \
  --vlan=100

# BGP設定（VPN同様）
gcloud compute routers add-bgp-peer my-router \
  --peer-name=onprem-peer \
  --peer-asn=65002 \
  --interface=my-attachment \
  --region=us-central1
```

**動的ルーティングモード**:
| モード | ルート共有範囲 |
|--------|--------------|
| **Regional** | Cloud Routerと同一リージョンのサブネットのみ |
| **Global** | VPC全体（全リージョン）のサブネット |

---

## Identity-Aware Proxy（IAP）

### 概要

**目的**: VPNレス・アプリケーションレベルアクセス制御（ネットワークベースではない）

**対応サービス**:
- GCE（SSH/RDP）
- App Engine
- GKE
- オンプレミス（IAP Connector経由）

### TCP Forwarding（SSH/RDP）

**必要ファイアウォールルール**:
```bash
gcloud compute firewall-rules create allow-iap-ingress \
  --network=my-vpc \
  --allow=tcp:22,tcp:3389 \
  --source-ranges=35.235.240.0/20 \
  --direction=INGRESS
```

**IAM権限付与**:
```bash
# プロジェクトレベル
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=user:alice@example.com \
  --role=roles/iap.tunnelResourceAccessor

# 特定VM
gcloud compute instances add-iam-policy-binding INSTANCE_NAME \
  --member=user:bob@example.com \
  --role=roles/iap.tunnelResourceAccessor \
  --zone=us-central1-a
```

**SSH接続**:
```bash
# 自動IAP Tunnel使用
gcloud compute ssh INSTANCE_NAME --tunnel-through-iap

# 強制IAP使用（外部IP保有VMでも）
gcloud compute ssh INSTANCE_NAME --tunnel-through-iap --zone=us-central1-a
```

### オンプレミス対応（IAP Connector）

**アーキテクチャ**:
```
User → Google Cloud Load Balancer → IAP → IAP Connector (GKE + Ambassador Proxy) → Cloud Interconnect → オンプレアプリ
```

**Routing設定例（Ambassador）**:
```yaml
routing:
  - name: crm
    mapping:
      - name: host
        source: www.crm-domain.com
        destination: crm-internal.domain.com
```

---

## ベストプラクティス

### VPC設計

| 原則 | 実装 |
|------|------|
| IP重複回避 | カスタムモードVPC、RFC1918計画的割り当て |
| 管理簡素化 | Shared VPC採用（ネットワーク集中管理） |
| セグメンテーション | サブネット数削減（類似アプリ集約） |
| スケーラビリティ | 制限事項事前確認（VPC Peering最大数等） |

### Organization Policy適用

```bash
# デフォルトネットワーク作成禁止
gcloud org-policies set-policy - <<EOF
constraint: compute.skipDefaultNetworkCreation
booleanPolicy:
  enforced: true
EOF

# Shared VPC Host Project制限
gcloud org-policies set-policy - <<EOF
constraint: compute.restrictSharedVpcHostProjects
listPolicy:
  allowedValues:
    - projects/HOST_PROJECT_ID
EOF
```

### セキュリティ原則

| レイヤー | 対策 |
|---------|------|
| **境界防御** | Cloud Armor（L3-L7）、階層型FWポリシー |
| **内部セグメンテーション** | Shared VPC、サブネット分離、サービスアカウントベースFW |
| **データ保護** | VPC Service Controls、Private Google Access |
| **ID管理** | IAP、サービスアカウント最小権限 |
| **監査** | VPC Flow Logs、Firewall Logs、Cloud Armor Logs |

### gcloud主要コマンド

```bash
# VPC作成
gcloud compute networks create my-vpc --subnet-mode=custom

# サブネット作成
gcloud compute networks subnets create my-subnet \
  --network=my-vpc \
  --region=us-central1 \
  --range=10.1.0.0/24

# FWルール作成
gcloud compute firewall-rules create allow-internal \
  --network=my-vpc \
  --allow=tcp,udp,icmp \
  --source-ranges=10.0.0.0/8

# ルート作成
gcloud compute routes create vpn-route \
  --network=my-vpc \
  --destination-range=192.168.0.0/16 \
  --next-hop-vpn-tunnel=my-tunnel \
  --next-hop-vpn-tunnel-region=us-central1

# Cloud Armor Policy作成
gcloud compute security-policies create my-policy

# LB Backend Serviceに適用
gcloud compute backend-services update my-backend \
  --security-policy=my-policy \
  --global
```

---

## IAMネットワーク権限

### Compute Engine IAMロール

| ロール | 権限レベル | 主要権限 | 使用ケース |
|--------|----------|---------|-----------|
| `compute.networkAdmin` | フル管理 | VPC/subnet/firewall/route全操作 | ネットワーク管理者 |
| `compute.securityAdmin` | セキュリティ特化 | Firewall/SSL証明書/Security Policy管理 | セキュリティチーム |
| `compute.networkViewer` | 読み取り専用 | ネットワーク設定・メトリクス閲覧 | 監査・レポート |
| `compute.instanceAdmin.v1` | VM管理 | VM作成・削除、ネットワークタグ設定 | 開発者 |

**権限分離原則**:
```bash
# ネットワーク管理者（VPC設計・変更）
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=user:network-admin@example.com \
  --role=roles/compute.networkAdmin

# セキュリティ管理者（Firewall管理のみ）
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=user:security-admin@example.com \
  --role=roles/compute.securityAdmin

# 開発者（VM作成・タグ設定）
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=user:developer@example.com \
  --role=roles/compute.instanceAdmin.v1
```

### サービスアカウント最小権限設定

**VM起動用サービスアカウント:**
```bash
# カスタムロール作成（VM起動のみ）
gcloud iam roles create vmStarter --project=PROJECT_ID \
  --title="VM Starter" \
  --description="Start/stop VMs only" \
  --permissions=compute.instances.start,compute.instances.stop,compute.instances.get

# サービスアカウントに付与
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=serviceAccount:vm-operator@PROJECT_ID.iam.gserviceaccount.com \
  --role=projects/PROJECT_ID/roles/vmStarter
```

---

## Cloud Armor 実装詳細

### セキュリティポリシー作成

**基本ポリシー作成:**
```bash
# ポリシー作成
gcloud compute security-policies create my-policy \
  --description="Basic WAF policy"

# デフォルトルール設定（全許可）
gcloud compute security-policies rules update 2147483647 \
  --security-policy=my-policy \
  --action=allow
```

### WAFルール実装パターン

#### 1. SQLインジェクション保護

```bash
# SQLi検出・拒否ルール
gcloud compute security-policies rules create 1000 \
  --security-policy=my-policy \
  --expression="evaluatePreconfiguredExpr('sqli-v33-stable')" \
  --action=deny-403 \
  --description="Block SQL injection attacks"

# 感度調整（誤検知軽減）
gcloud compute security-policies rules create 1001 \
  --security-policy=my-policy \
  --expression="evaluatePreconfiguredExpr('sqli-v33-stable', ['owasp-crs-v030301-id942251-sqli'])" \
  --action=deny-403
```

#### 2. XSS保護

```bash
gcloud compute security-policies rules create 1100 \
  --security-policy=my-policy \
  --expression="evaluatePreconfiguredExpr('xss-v33-stable')" \
  --action=deny-403 \
  --description="Block cross-site scripting"
```

#### 3. IPベースアクセス制御

```bash
# 特定IP範囲拒否
gcloud compute security-policies rules create 2000 \
  --security-policy=my-policy \
  --expression="inIpRange(origin.ip, '203.0.113.0/24')" \
  --action=deny-403 \
  --description="Block suspicious IP range"

# 複数IP範囲
gcloud compute security-policies rules create 2001 \
  --security-policy=my-policy \
  --expression="inIpRange(origin.ip, '203.0.113.0/24') || inIpRange(origin.ip, '198.51.100.0/24')" \
  --action=deny-403
```

#### 4. Geo-blocking（国単位制限）

```bash
# 特定国からのアクセス拒否
gcloud compute security-policies rules create 3000 \
  --security-policy=my-policy \
  --expression="origin.region_code == 'CN' || origin.region_code == 'RU'" \
  --action=deny-403 \
  --description="Block traffic from specific countries"
```

### Rate Limiting

**DDoS防御用レート制限:**
```bash
gcloud compute security-policies rules create 4000 \
  --security-policy=my-policy \
  --expression="true" \
  --action=rate-based-ban \
  --rate-limit-threshold-count=100 \
  --rate-limit-threshold-interval-sec=60 \
  --ban-duration-sec=600 \
  --conform-action=allow \
  --exceed-action=deny-429 \
  --description="Rate limit: 100 req/min per IP"
```

**APIエンドポイント保護:**
```bash
gcloud compute security-policies rules create 4001 \
  --security-policy=my-policy \
  --expression="request.path.matches('/api/login')" \
  --action=throttle \
  --rate-limit-threshold-count=10 \
  --rate-limit-threshold-interval-sec=60 \
  --conform-action=allow \
  --exceed-action=deny-429
```

### Adaptive Protection（ML自動防御）

**有効化（Managed Protection Plus必須）:**
```bash
gcloud compute security-policies update my-policy \
  --enable-layer7-ddos-defense \
  --layer7-ddos-defense-rule-visibility=STANDARD
```

**検出基準:**
| 指標 | 閾値 | 動作 |
|------|------|------|
| リクエストレート | ベースライン+3σ | アラート生成 |
| エラーレート | 5%超過 | 自動ルール提案 |
| レイテンシ異常 | P95が2倍 | トラフィック分析 |

### Backend Service適用

```bash
# LBバックエンドに適用
gcloud compute backend-services update my-backend \
  --security-policy=my-policy \
  --global
```

---

## NGFW Enterprise インサーション

### マルチNIC環境構成

**アーキテクチャ:**
```
Internet
    ↓
External HTTP(S) LB
    ↓
Backend VMs (VPC-A)
    ↓
Internal TCP/UDP LB → NGFW VM（nic0: VPC-A, nic1: VPC-B）
    ↓
Database VMs (VPC-B)
```

### NGFW VM作成

**Palo Alto Networks VM-Series例:**
```bash
# NIC0: External（管理・untrusted）
gcloud compute instances create ngfw-vm \
  --zone=us-central1-a \
  --machine-type=n2-standard-4 \
  --network-interface=network=vpc-external,subnet=subnet-external \
  --network-interface=network=vpc-internal,subnet=subnet-internal \
  --image-project=paloaltonetworksgcp-public \
  --image-family=vmseries-flex-byol \
  --boot-disk-size=60GB \
  --boot-disk-type=pd-ssd \
  --metadata=vmseries-bootstrap-gce-storagebucket=gs://my-bucket/config
```

### ルーティング設定（内部LB next-hop）

**Static Route作成:**
```bash
# VPC-Aから内部LBへのルート
gcloud compute routes create to-ngfw \
  --network=vpc-internal \
  --destination-range=10.2.0.0/16 \
  --next-hop-ilb=projects/PROJECT_ID/regions/us-central1/forwardingRules/ngfw-ilb \
  --priority=100
```

**内部LB設定（NGFW backend）:**
```bash
# Health Check
gcloud compute health-checks create tcp ngfw-hc \
  --port=22

# Backend Service
gcloud compute backend-services create ngfw-backend \
  --load-balancing-scheme=INTERNAL \
  --protocol=TCP \
  --health-checks=ngfw-hc \
  --region=us-central1

# Instance Group追加
gcloud compute backend-services add-backend ngfw-backend \
  --instance-group=ngfw-ig \
  --instance-group-zone=us-central1-a \
  --region=us-central1

# Forwarding Rule
gcloud compute forwarding-rules create ngfw-ilb \
  --load-balancing-scheme=INTERNAL \
  --network=vpc-internal \
  --subnet=subnet-internal \
  --region=us-central1 \
  --backend-service=ngfw-backend \
  --ports=ALL
```

### IDS/IPS設定例（Palo Alto）

**脅威検出プロファイル:**
```xml
<threat>
  <vulnerability>
    <action>reset-both</action>
    <packet-capture>single-packet</packet-capture>
  </vulnerability>
  <spyware>
    <action>drop</action>
  </spyware>
</threat>
```

### TLS Inspection

**復号化ポリシー設定:**
```bash
# SSL Forward Proxy証明書インポート
set shared certificate intermediate-ca \
  certificate "-----BEGIN CERTIFICATE-----..."

# 復号化ルール
set rulebase decryption rules ssl-inbound-inspection \
  source any destination any \
  service application-default \
  action decrypt
```

### マルチNICファイアウォール注意点

| 項目 | 制約 | 対処 |
|------|------|------|
| **タグ適用** | VM全体に適用（NIC個別指定不可） | タグマッチするVPCのルートのみ影響 |
| **ルーティング** | タグマッチ+VPC内ルート両立必要 | 各VPCで個別ルート設定 |
| **Firewall Rules** | NIC所属VPCのルールが各NICに適用 | NIC単位でセキュリティ設計 |

---

## トラブルシューティング

| 症状 | 原因 | 解決策 |
|------|------|--------|
| VM間通信不可 | FWルール不足 | `gcloud compute firewall-rules list --filter="network:my-vpc"` 確認 |
| Private Google Access不可 | DNS/ルート未設定 | Cloud DNS private zone + default route確認 |
| VPC Peering失敗 | IP重複 | `gcloud compute networks subnets list` でCIDR確認 |
| IAP接続失敗 | FWルール未設定 | `35.235.240.0/20` ingress許可確認 |
| Cloud Armor非動作 | LBタイプ不適合 | External HTTP(S) LB使用確認 |
| NGFW通信不可 | 内部LB next-hopルート未設定 | `gcloud compute routes list --filter="network:my-vpc"` 確認 |
| Adaptive Protection無効 | Standard Tier使用 | Managed Protection Plus必須 |
