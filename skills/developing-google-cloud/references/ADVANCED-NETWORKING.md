# 高度なネットワーキング（Traffic Director・Service Mesh・Service Directory・NCC）

マイクロサービスアーキテクチャの分散ネットワーク管理のための高度なGCPネットワーキングサービス。Traffic Directorによるサービスメッシュ制御、Service Directoryによる一元的なサービス登録・検索、Network Connectivity Centerによるハイブリッドクラウドのハブアンドスポーク接続を実現する。

## Traffic Director

Traffic Directorは、GCPフルマネージドのサービスメッシュ制御プレーン。Kubernetes、Compute Engine、オンプレミス、他クラウドにまたがるマイクロサービス間のトラフィック管理・ロードバランシング・セキュリティを統一的に制御する。

### Istioとサービスメッシュの基礎

**Istioアーキテクチャ:**

| コンポーネント | 役割 | 実装技術 |
|--------------|------|---------|
| **Control Plane (istiod)** | サービスディスカバリ、設定配布、証明書管理 | Pilot + Citadel + Galley統合 |
| **Data Plane (Envoy)** | トラフィック管理、暗号化、メトリクス収集 | サイドカープロキシ |

**Istioの3つの柱:**

1. **Traffic Management**: A/Bテスト、カナリアデプロイ、Circuit Breaker、Timeout、Retry
2. **Security**: mTLS暗号化、マイクロサービス間認証、デジタル証明書、ゼロトラスト
3. **Observability**: ゴールデンシグナル（Latency、Error、Traffic、Saturation）、分散トレース、アクセスログ

**サービスメッシュの課題とTraffic Directorの解決:**

| 課題 | Istioのみの場合 | Traffic Director |
|------|--------------|----------------|
| マルチクラスタ管理 | 各クラスタにistiod必要 | GCPで一元管理 |
| VM環境対応 | Envoy手動インストール | ネイティブサポート |
| gRPCプロキシレス | 非対応 | xDS APIで直接制御 |
| 運用負荷 | istiod保守が必要 | フルマネージド |

### Traffic Directorの特徴

**xDS API統合:**

Traffic DirectorはxDS API（Envoy Discovery Service）をサポートし、以下の柔軟性を提供:

- **プロキシベース**: Envoyサイドカーでトラフィック制御
- **プロキシレス**: gRPCアプリが直接xDS APIを呼び出し、サイドカー不要

**対応環境:**

| 環境 | 統合方法 | ユースケース |
|-----|---------|-------------|
| GKE | Envoyサイドカー自動インジェクション | Kubernetesネイティブ |
| Compute Engine | Envoyインストール + 設定 | VMベースサービス |
| オンプレミス | Cloud VPN/Interconnect経由 | ハイブリッドクラウド |
| 他クラウド | VPN接続 + Envoy | マルチクラウド戦略 |

### Traffic Directorの設定

#### 1. APIの有効化

```bash
# Traffic Director APIを有効化
gcloud services enable trafficdirector.googleapis.com
```

**GUIでの有効化:**
1. Cloud Console → APIs & Services → Library
2. "Traffic Director API" を検索
3. 「ENABLE」をクリック

#### 2. サービスの作成

**サービスプロトコル選択:**

| プロトコル | 用途 | 設定タイムアウト |
|----------|------|---------------|
| HTTP | RESTful API | 30秒 |
| HTTP/2 | gRPC、ストリーミング | 60秒 |
| gRPC | マイクロサービス間通信 | 30秒 |
| TCP | データベース、カスタムプロトコル | 300秒 |

**gcloud コマンド例（HTTP）:**

```bash
# HTTPサービスを作成
gcloud compute backend-services create my-backend \
  --protocol HTTP \
  --health-checks my-health-check \
  --global \
  --load-balancing-scheme INTERNAL_SELF_MANAGED
```

#### 3. バックエンド設定

**バックエンドタイプの選択:**

| タイプ | 説明 | 適用場面 |
|-------|------|---------|
| Instance Group | Compute Engineのマネージドインスタンスグループ | VM環境 |
| Network Endpoint Group (NEG) | GKE Pod、外部エンドポイント | Kubernetes、ハイブリッド |

**Instance Group バックエンド:**

```bash
# インスタンスグループをバックエンドに追加
gcloud compute backend-services add-backend my-backend \
  --instance-group my-instance-group \
  --instance-group-zone us-central1-a \
  --balancing-mode UTILIZATION \
  --max-utilization 0.8 \
  --capacity-scaler 1.0 \
  --global
```

**設定パラメータ:**

| パラメータ | 説明 | 推奨値 |
|----------|------|-------|
| `--balancing-mode` | UTILIZATION（CPU使用率）/ RATE（RPS） | UTILIZATION |
| `--max-utilization` | 最大CPU使用率（0.0～1.0） | 0.8 |
| `--capacity-scaler` | 容量調整（0.0～1.0）、50%なら0.5 | 1.0 |
| `--max-rate-per-instance` | インスタンスあたりの最大RPS | 100 |

**Network Endpoint Group バックエンド:**

```bash
# NEGをバックエンドに追加
gcloud compute backend-services add-backend my-backend \
  --network-endpoint-group my-neg \
  --network-endpoint-group-zone us-central1-a \
  --balancing-mode RATE \
  --max-rate-per-endpoint 50 \
  --global
```

#### 4. ヘルスチェック設定

```bash
# ヘルスチェックを作成
gcloud compute health-checks create http my-health-check \
  --port 8080 \
  --request-path /healthz \
  --check-interval 10s \
  --timeout 5s \
  --unhealthy-threshold 3 \
  --healthy-threshold 2
```

**ヘルスチェックパラメータ:**

| パラメータ | 説明 | デフォルト | 推奨値 |
|----------|------|----------|-------|
| `--check-interval` | チェック間隔 | 10s | 10s～30s |
| `--timeout` | タイムアウト | 5s | 5s（check-intervalより短く） |
| `--unhealthy-threshold` | Unhealthy判定までの連続失敗回数 | 3 | 2～3 |
| `--healthy-threshold` | Healthy復帰までの連続成功回数 | 2 | 2 |

#### 5. 高度な設定オプション

**Session Affinity（セッション維持）:**

| オプション | 説明 | 用途 |
|----------|------|------|
| None | セッション維持なし（ランダム） | ステートレスAPI |
| Client IP | 同一クライアントIPを同じインスタンスへ | ステートフルセッション |
| Generated Cookie | LBが生成したCookieでルーティング | Webアプリケーション |
| Header field | HTTPヘッダーでルーティング | カスタムロジック |
| HTTP cookie | アプリが生成したCookieでルーティング | 既存Cookieベース認証 |

```bash
# Client IPアフィニティを設定
gcloud compute backend-services update my-backend \
  --session-affinity CLIENT_IP \
  --global
```

**Circuit Breaker（過負荷保護）:**

```bash
# Circuit Breakerを設定
gcloud compute backend-services update my-backend \
  --global \
  --circuit-breakers-max-requests 1000 \
  --circuit-breakers-max-connections 500 \
  --circuit-breakers-max-pending-requests 100 \
  --circuit-breakers-max-retries 3
```

**Circuit Breakerパラメータ:**

| パラメータ | 説明 | 推奨値 |
|----------|------|-------|
| `--circuit-breakers-max-requests` | 最大並列リクエスト数 | 1000 |
| `--circuit-breakers-max-connections` | 最大接続数 | 500 |
| `--circuit-breakers-max-pending-requests` | 最大ペンディングリクエスト数 | 100 |
| `--circuit-breakers-max-retries` | 最大並列リトライ数 | 3 |

**Outlier Detection（異常検知・自動排除）:**

```bash
# Outlier Detectionを設定
gcloud compute backend-services update my-backend \
  --global \
  --outlier-detection-consecutive-errors 5 \
  --outlier-detection-interval 10s \
  --outlier-detection-base-ejection-time 30s \
  --outlier-detection-max-ejection-percent 50
```

**Outlier Detection パラメータ:**

| パラメータ | 説明 | 推奨値 |
|----------|------|-------|
| `--outlier-detection-consecutive-errors` | 連続エラー回数で排除判定 | 5 |
| `--outlier-detection-interval` | 検知スイープ間隔 | 10s |
| `--outlier-detection-base-ejection-time` | 最小排除時間 | 30s |
| `--outlier-detection-max-ejection-percent` | 最大排除ホスト割合 | 50% |

**Locality Load Balancing Policy（ロケーション優先ルーティング）:**

| ポリシー | 説明 | 用途 |
|---------|------|------|
| Round Robin | ラウンドロビン | 均等分散 |
| Least Request | 最小リクエスト数のインスタンス優先 | 負荷均等化 |
| Ring Hash | 1/N影響範囲のコンシステントハッシュ | セッション維持 |
| Random | ランダム選択 | シンプルな負荷分散 |
| Maglev | Ring Hashより高速なハッシュ | 大規模環境 |

```bash
# Least Requestポリシーを設定
gcloud compute backend-services update my-backend \
  --global \
  --locality-lb-policy LEAST_REQUEST
```

## Service Directory

Service Directoryは、マルチクラウド・ハイブリッド環境のサービス登録・検索のためのフルマネージドディレクトリサービス。GCP、AWS、オンプレミスのサービスを一元管理し、DNS統合によりVPC内からの名前解決を可能にする。

### Service Directoryアーキテクチャ

**コンポーネント階層:**

```
Namespace (リージョン単位)
  └─ Service (サービス名)
      └─ Endpoint (IP:Port + メタデータ)
```

**コンポーネント詳細:**

| コンポーネント | 説明 | スコープ |
|--------------|------|---------|
| **Namespace** | サービスのグループ。GCPリージョン＋プロジェクト内で一意 | リージョン |
| **Service** | 複数のエンドポイントを束ねる論理的なサービス | Namespace内 |
| **Endpoint** | IP:Port + メタデータ。実際のトラフィック受信点 | Service内 |

**API連携方法:**

| 方法 | プロトコル | 用途 |
|-----|-----------|------|
| Client Libraries (SDK) | gRPC/HTTP | プログラムからのAPI呼び出し |
| REST API | HTTP | Curl、外部システム連携 |
| RPC API | gRPC | 低レイテンシ、大量呼び出し |
| DNS（Cloud DNS統合） | DNS | VPC内の名前解決 |

### Service Directory設定

#### 1. APIの有効化

```bash
# Service Directory APIを有効化
gcloud services enable servicedirectory.googleapis.com
```

#### 2. Namespace作成

```bash
# Namespaceを作成
gcloud service-directory namespaces create mycompany \
  --location us-central1
```

**Namespace設計ガイダンス:**

| 組織タイプ | Namespace分割戦略 | 例 |
|-----------|----------------|-----|
| 小規模スタートアップ | 1つのNamespace | `company` |
| 中規模企業 | 環境ごと | `production`, `staging`, `dev` |
| 大規模企業 | チーム＋環境 | `team-a-prod`, `team-b-prod` |
| マルチリージョン | リージョン＋環境 | `us-prod`, `asia-prod` |

#### 3. Service登録

**Standard Service（一般的なサービス）:**

```bash
# Serviceを登録
gcloud service-directory services create frontend \
  --namespace mycompany \
  --location us-central1
```

**Private Service Connect Service（PSC統合）:**

Private Service Connect経由でアクセスするサービスを登録する場合:

```bash
# PSC Service登録
gcloud service-directory services create psc-service \
  --namespace mycompany \
  --location us-central1 \
  --annotations type=private-service-connect
```

#### 4. Endpoint登録

```bash
# Endpointを登録
gcloud service-directory endpoints create instance1 \
  --service frontend \
  --namespace mycompany \
  --location us-central1 \
  --address 35.202.126.17 \
  --port 80 \
  --metadata instance_type=web,zone=us-central1-a
```

**複数Endpoint一括登録:**

```bash
# Endpoint 2を登録
gcloud service-directory endpoints create instance2 \
  --service frontend \
  --namespace mycompany \
  --location us-central1 \
  --address 35.223.98.45 \
  --port 80 \
  --metadata instance_type=web,zone=us-central1-b
```

#### 5. Service解決（ルックアップ）

**gcloud CLI経由:**

```bash
# Serviceを解決してEndpoint一覧を取得
gcloud service-directory services resolve frontend \
  --namespace mycompany \
  --location us-central1
```

**出力例:**

```yaml
service:
  endpoints:
  - address: 35.202.126.17
    name: projects/my-project/locations/us-central1/namespaces/mycompany/services/frontend/endpoints/instance1
    port: 80
    metadata:
      instance_type: web
      zone: us-central1-a
  - address: 35.223.98.45
    name: projects/my-project/locations/us-central1/namespaces/mycompany/services/frontend/endpoints/instance2
    port: 80
    metadata:
      instance_type: web
      zone: us-central1-b
  name: projects/my-project/locations/us-central1/namespaces/mycompany/services/frontend
```

### DNS統合（Cloud DNS Private Zone）

Service DirectoryをCloud DNS Private Zoneと統合し、VPC内からDNS名でサービスを解決可能にする。

#### DNS統合手順

**1. Cloud DNS Private Zone作成:**

```bash
# Service Directory統合のPrivate Zoneを作成
gcloud dns managed-zones create mycompany-zone \
  --description="Service Directory DNS zone" \
  --dns-name=mycompany \
  --networks=mynetwork \
  --visibility=private \
  --service-directory-namespace=https://servicedirectory.googleapis.com/v1/projects/my-project/locations/us-central1/namespaces/mycompany
```

**重要パラメータ:**

| パラメータ | 説明 | 例 |
|----------|------|-----|
| `--dns-name` | DNSゾーン名（Namespace名と一致推奨） | `mycompany` |
| `--networks` | DNS Zoneが有効なVPC | `mynetwork` |
| `--service-directory-namespace` | 統合するNamespaceのフルパス | `https://...` |

**2. DNS解決テスト:**

```bash
# Compute EngineインスタンスからDNS解決
gcloud compute ssh my-instance --zone us-central1-a --command="nslookup frontend.mycompany"
```

**期待される出力:**

```
Server:    169.254.169.254
Address:   169.254.169.254#53

Name:      frontend.mycompany
Address:   35.202.126.17
Name:      frontend.mycompany
Address:   35.223.98.45
```

**DNS統合のメリット:**

| メリット | 説明 |
|---------|------|
| 透過的アクセス | アプリケーションはDNS名で接続（`frontend.mycompany`） |
| 動的更新 | Endpoint追加・削除が自動でDNSに反映 |
| VPC統合 | VPC内の全リソースから解決可能 |
| マルチクラウド対応 | VPN経由でオンプレミス・他クラウドからも解決 |

### Service DirectoryとCloud Runの統合

Cloud RunサービスをService Directoryに登録し、内部ロードバランサー経由でアクセスする構成。

**1. Cloud Run内部ロードバランサーの作成:**

```bash
# 内部ロードバランサーを作成
gcloud compute backend-services create my-cloudrun-backend \
  --load-balancing-scheme INTERNAL_MANAGED \
  --protocol HTTP \
  --region us-central1

# Cloud Runネットワークエンドポイントグループをバックエンドに追加
gcloud compute backend-services add-backend my-cloudrun-backend \
  --network-endpoint-group my-cloudrun-neg \
  --network-endpoint-group-region us-central1 \
  --region us-central1
```

**2. Service Directoryに登録:**

```bash
# 内部LBのIPをEndpointとして登録
gcloud service-directory endpoints create cloudrun-endpoint \
  --service my-cloudrun-service \
  --namespace mycompany \
  --location us-central1 \
  --address 10.128.0.50 \
  --port 80
```

### Service DirectoryとGKEの統合

**GKE Service自動登録:**

GKE 1.20以降では、Service Directoryコントローラーが自動でKubernetes ServiceをService Directoryに登録可能。

```bash
# GKEクラスタでService Directory連携を有効化
gcloud container clusters update my-cluster \
  --enable-service-directory \
  --service-directory-namespace mycompany \
  --zone us-central1-a
```

**Kubernetes Serviceマニフェスト例:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    cloud.google.com/service-directory: "enabled"
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```

**自動登録確認:**

```bash
# Service Directoryに登録されたことを確認
gcloud service-directory services resolve my-service \
  --namespace mycompany \
  --location us-central1
```

## Service Mesh選択ガイド

マイクロサービスのサービスメッシュ実装方式を選択する際の判断基準。

| 基準 | Traffic Director | Istio (self-managed) | Anthos Service Mesh | 自前実装 |
|-----|-----------------|---------------------|---------------------|---------|
| **管理負荷** | ◎ フルマネージド | × istiod保守必要 | ○ GKE統合 | × 全て自前 |
| **マルチクラスタ** | ◎ ネイティブ | △ Federation必要 | ○ Anthos統合 | × 実装困難 |
| **VM対応** | ◎ ネイティブ | △ 手動セットアップ | △ 限定的 | △ カスタム |
| **gRPCプロキシレス** | ◎ xDS API | × 非対応 | × 非対応 | - |
| **コスト** | 従量課金 | 無料（運用コストあり） | GKE Enterprise必須 | 開発コスト高 |
| **学習曲線** | △ GCP固有 | × Istio複雑 | △ Anthos知識必要 | × 設計から |
| **エコシステム** | ○ GCP統合 | ◎ CNCF標準 | ○ GCP＋Istio | - |

**推奨構成:**

| ユースケース | 推奨ソリューション | 理由 |
|------------|------------------|------|
| GKEのみ | Anthos Service Mesh | GKE統合、Istio互換性 |
| GKE + VM | Traffic Director | マルチ環境ネイティブサポート |
| マルチクラスタ | Traffic Director | 一元管理、運用負荷最小 |
| オンプレミス連携 | Traffic Director | ハイブリッドクラウド対応 |
| Istio経験者 | Self-managed Istio | コミュニティサポート、柔軟性 |
| 小規模・シンプル | なし（直接通信） | オーバーヘッド回避 |

## Network Connectivity Center (NCC)

Network Connectivity Centerは、オンプレミス・マルチクラウドをGCPに接続するハブアンドスポークネットワークのフルマネージドサービス。Cloud VPN、Dedicated Interconnect、Partner Interconnectを統合し、全拠点間のフルメッシュ接続を自動構築する。

### NCCアーキテクチャ

**Hub and Spokeモデル:**

```
                     ┌─────────────┐
                     │     Hub     │ (GCP Managed)
                     │  (Global)   │
                     └──────┬──────┘
           ┌────────────────┼────────────────┐
           │                │                │
       ┌───▼───┐       ┌───▼───┐       ┌───▼───┐
       │Spoke A│       │Spoke B│       │Spoke C│
       │ VPN   │       │ VLAN  │       │ VPN   │
       └───┬───┘       └───┬───┘       └───┬───┘
           │               │               │
    ┌──────▼──────┐ ┌─────▼─────┐ ┌──────▼──────┐
    │On-premises A│ │On-prem B  │ │   AWS VPC   │
    │10.20.10.0/24│ │10.20.20/24│ │10.30.0.0/24 │
    └─────────────┘ └───────────┘ └─────────────┘
```

**Hubの役割:**
- 全Spokes間のルート交換（BGP Multi Exit Discriminator）
- フルメッシュ接続の自動構築
- グローバルリーチャビリティ

**Spokeタイプ:**

| Spokeタイプ | 接続先 | 用途 |
|-----------|-------|------|
| **HA VPN Spoke** | Cloud VPN HA VPNトンネル | オンプレミス、他クラウド |
| **VLAN Attachment Spoke** | Dedicated/Partner Interconnect | オンプレミス専用線 |
| **Router Appliance Spoke** | サードパーティSD-WAN | Cisco、Palo Alto等 |
| **VPC Spoke** | VPC Network | VPC間接続（Preview） |

### NCC設計要件

| 要件 | 説明 | 注意点 |
|-----|------|-------|
| **動的ルーティング必須** | BGPでルート交換 | 静的ルートは非対応 |
| **VPC動的ルーティングモード** | Global推奨 | リージョン跨ぎルーティング必須 |
| **1 VPC = 1 Hub** | VPCごとに1つのHub | 複数Hubは作成不可 |
| **HA VPNのみ対応** | Classic VPNは非対応 | HA VPN使用必須 |
| **VPC Peering互換** | PeeringしたVPCもHub利用可 | ルート広告は独立 |
| **Shared VPC対応** | Host ProjectでHub作成 | Service Projectでは作成不可 |

### NCC設定手順（Transit Hubシナリオ）

以下では、2つのVPC（VPC-A、VPC-B）をTransit VPC経由で接続するシナリオを構築する。

**構成図:**

```
VPC-A (us-east4)          Transit VPC          VPC-B (us-west2)
10.20.10.0/24            (Global Routing)      10.20.20.0/24
      │                        │                     │
      │ HA VPN Tunnels         │ HA VPN Tunnels      │
      ├────────────────────────┤────────────────────┤
      │                        │                     │
  Cloud Router           Cloud Router          Cloud Router
  (BGP 65001)           (BGP 65000)           (BGP 65002)
      │                        │                     │
    Spoke A        ┌───────────▼───────────┐       Spoke B
    (bo1)          │       NCC Hub         │       (bo2)
                   └───────────────────────┘
```

#### 1. APIの有効化

```bash
# Network Connectivity APIを有効化
gcloud services enable networkconnectivity.googleapis.com
```

#### 2. VPCとサブネットの作成

```bash
# VPC-A作成
gcloud compute networks create vpc-a --subnet-mode custom
gcloud compute networks subnets create vpc-a-sub1-use4 \
  --network vpc-a \
  --region us-east4 \
  --range 10.20.10.0/24

# Transit VPC作成（サブネットなし・グローバルルーティング）
gcloud compute networks create vpc-transit \
  --subnet-mode custom \
  --bgp-routing-mode GLOBAL

# VPC-B作成
gcloud compute networks create vpc-b --subnet-mode custom
gcloud compute networks subnets create vpc-b-sub1-usw2 \
  --network vpc-b \
  --region us-west2 \
  --range 10.20.20.0/24
```

#### 3. Cloud Router作成

```bash
# VPC-A用Cloud Router（BGP AS 65001）
gcloud compute routers create cr-vpc-a-use4-1 \
  --network vpc-a \
  --region us-east4 \
  --asn 65001

# Transit VPC用Cloud Router 1（BGP AS 65000）
gcloud compute routers create cr-vpc-transit-use4-1 \
  --network vpc-transit \
  --region us-east4 \
  --asn 65000

# Transit VPC用Cloud Router 2（BGP AS 65000）
gcloud compute routers create cr-vpc-transit-usw2-1 \
  --network vpc-transit \
  --region us-west2 \
  --asn 65000

# VPC-B用Cloud Router（BGP AS 65002）
gcloud compute routers create cr-vpc-b-usw2-1 \
  --network vpc-b \
  --region us-west2 \
  --asn 65002
```

#### 4. HA VPN Gatewayの作成

```bash
# VPC-A用VPNゲートウェイ
gcloud compute vpn-gateways create vpc-a-gw1-use4 \
  --network vpc-a \
  --region us-east4

# Transit VPC用VPNゲートウェイ（us-east4）
gcloud compute vpn-gateways create vpc-transit-gw1-use4 \
  --network vpc-transit \
  --region us-east4

# Transit VPC用VPNゲートウェイ（us-west2）
gcloud compute vpn-gateways create vpc-transit-gw1-usw2 \
  --network vpc-transit \
  --region us-west2

# VPC-B用VPNゲートウェイ
gcloud compute vpn-gateways create vpc-b-gw1-usw2 \
  --network vpc-b \
  --region us-west2
```

#### 5. HA VPN Tunnelの作成

**VPC-AとTransit VPC間のトンネル（us-east4）:**

```bash
# トンネル1（Transit → VPC-A）
gcloud compute vpn-tunnels create transit-to-vpc-a-tu1 \
  --vpn-gateway vpc-transit-gw1-use4 \
  --peer-gcp-gateway vpc-a-gw1-use4 \
  --region us-east4 \
  --ike-version 2 \
  --shared-secret Google123! \
  --router cr-vpc-transit-use4-1 \
  --interface 0

# トンネル2（Transit → VPC-A）
gcloud compute vpn-tunnels create transit-to-vpc-a-tu2 \
  --vpn-gateway vpc-transit-gw1-use4 \
  --peer-gcp-gateway vpc-a-gw1-use4 \
  --region us-east4 \
  --ike-version 2 \
  --shared-secret Google123! \
  --router cr-vpc-transit-use4-1 \
  --interface 1

# トンネル1（VPC-A → Transit）
gcloud compute vpn-tunnels create vpc-a-to-transit-tu1 \
  --vpn-gateway vpc-a-gw1-use4 \
  --peer-gcp-gateway vpc-transit-gw1-use4 \
  --region us-east4 \
  --ike-version 2 \
  --shared-secret Google123! \
  --router cr-vpc-a-use4-1 \
  --interface 0

# トンネル2（VPC-A → Transit）
gcloud compute vpn-tunnels create vpc-a-to-transit-tu2 \
  --vpn-gateway vpc-a-gw1-use4 \
  --peer-gcp-gateway vpc-transit-gw1-use4 \
  --region us-east4 \
  --ike-version 2 \
  --shared-secret Google123! \
  --router cr-vpc-a-use4-1 \
  --interface 1
```

**VPC-BとTransit VPC間のトンネル（us-west2）:**

```bash
# トンネル1（Transit → VPC-B）
gcloud compute vpn-tunnels create transit-to-vpc-b-tu1 \
  --vpn-gateway vpc-transit-gw1-usw2 \
  --peer-gcp-gateway vpc-b-gw1-usw2 \
  --region us-west2 \
  --ike-version 2 \
  --shared-secret Google123! \
  --router cr-vpc-transit-usw2-1 \
  --interface 0

# トンネル2（Transit → VPC-B）
gcloud compute vpn-tunnels create transit-to-vpc-b-tu2 \
  --vpn-gateway vpc-transit-gw1-usw2 \
  --peer-gcp-gateway vpc-b-gw1-usw2 \
  --region us-west2 \
  --ike-version 2 \
  --shared-secret Google123! \
  --router cr-vpc-transit-usw2-1 \
  --interface 1

# トンネル1（VPC-B → Transit）
gcloud compute vpn-tunnels create vpc-b-to-transit-tu1 \
  --vpn-gateway vpc-b-gw1-usw2 \
  --peer-gcp-gateway vpc-transit-gw1-usw2 \
  --region us-west2 \
  --ike-version 2 \
  --shared-secret Google123! \
  --router cr-vpc-b-usw2-1 \
  --interface 0

# トンネル2（VPC-B → Transit）
gcloud compute vpn-tunnels create vpc-b-to-transit-tu2 \
  --vpn-gateway vpc-b-gw1-usw2 \
  --peer-gcp-gateway vpc-transit-gw1-usw2 \
  --region us-west2 \
  --ike-version 2 \
  --shared-secret Google123! \
  --router cr-vpc-b-usw2-1 \
  --interface 1
```

#### 6. BGPセッションの設定

**Transit → VPC-A（us-east4）:**

```bash
# BGPセッション1
gcloud compute routers add-interface cr-vpc-transit-use4-1 \
  --interface-name if-tunnel1-to-vpc-a \
  --vpn-tunnel transit-to-vpc-a-tu1 \
  --region us-east4

gcloud compute routers add-bgp-peer cr-vpc-transit-use4-1 \
  --peer-name bgp-peer-tunnel1-to-vpc-a \
  --peer-asn 65001 \
  --interface if-tunnel1-to-vpc-a \
  --region us-east4

# BGPセッション2
gcloud compute routers add-interface cr-vpc-transit-use4-1 \
  --interface-name if-tunnel2-to-vpc-a \
  --vpn-tunnel transit-to-vpc-a-tu2 \
  --region us-east4

gcloud compute routers add-bgp-peer cr-vpc-transit-use4-1 \
  --peer-name bgp-peer-tunnel2-to-vpc-a \
  --peer-asn 65001 \
  --interface if-tunnel2-to-vpc-a \
  --region us-east4
```

**VPC-A → Transit（us-east4）:**

```bash
# BGPセッション1
gcloud compute routers add-interface cr-vpc-a-use4-1 \
  --interface-name if-tunnel1-to-transit \
  --vpn-tunnel vpc-a-to-transit-tu1 \
  --region us-east4

gcloud compute routers add-bgp-peer cr-vpc-a-use4-1 \
  --peer-name bgp-peer-tunnel1-to-transit \
  --peer-asn 65000 \
  --interface if-tunnel1-to-transit \
  --region us-east4

# BGPセッション2
gcloud compute routers add-interface cr-vpc-a-use4-1 \
  --interface-name if-tunnel2-to-transit \
  --vpn-tunnel vpc-a-to-transit-tu2 \
  --region us-east4

gcloud compute routers add-bgp-peer cr-vpc-a-use4-1 \
  --peer-name bgp-peer-tunnel2-to-transit \
  --peer-asn 65000 \
  --interface if-tunnel2-to-transit \
  --region us-east4
```

同様にTransit ↔ VPC-B（us-west2）のBGPセッションも設定する。

#### 7. Network Connectivity Center Hub作成

```bash
# Hubを作成
gcloud network-connectivity hubs create transit-hub \
  --description="Transit hub for VPC-A and VPC-B"
```

#### 8. Spokeの作成

**Spoke A（VPC-A → Transit）:**

```bash
# Spoke Aを作成（VPNトンネルをアタッチ）
gcloud network-connectivity spokes create bo1 \
  --hub transit-hub \
  --description="Branch Office 1 (VPC-A)" \
  --vpn-tunnel transit-to-vpc-a-tu1,transit-to-vpc-a-tu2 \
  --region us-east4
```

**Spoke B（VPC-B → Transit）:**

```bash
# Spoke Bを作成（VPNトンネルをアタッチ）
gcloud network-connectivity spokes create bo2 \
  --hub transit-hub \
  --description="Branch Office 2 (VPC-B)" \
  --vpn-tunnel transit-to-vpc-b-tu1,transit-to-vpc-b-tu2 \
  --region us-west2
```

#### 9. 接続確認

**Compute Engineインスタンスをデプロイ:**

```bash
# VPC-A用インスタンス
gcloud compute instances create vpc-a-vm-1 \
  --zone us-east4-a \
  --subnet vpc-a-sub1-use4 \
  --machine-type e2-micro

# VPC-B用インスタンス
gcloud compute instances create vpc-b-vm-1 \
  --zone us-west2-a \
  --subnet vpc-b-sub1-usw2 \
  --machine-type e2-micro
```

**ファイアウォールルール設定:**

```bash
# ICMP許可（VPC-A）
gcloud compute firewall-rules create allow-icmp-vpc-a \
  --network vpc-a \
  --allow icmp \
  --source-ranges 10.20.0.0/16

# ICMP許可（VPC-B）
gcloud compute firewall-rules create allow-icmp-vpc-b \
  --network vpc-b \
  --allow icmp \
  --source-ranges 10.20.0.0/16
```

**接続テスト:**

```bash
# VPC-A-VM-1からVPC-B-VM-1へPing
gcloud compute ssh vpc-a-vm-1 --zone us-east4-a --command="ping -c 4 10.20.20.2"
```

**期待される出力:**

```
PING 10.20.20.2 (10.20.20.2) 56(84) bytes of data.
64 bytes from 10.20.20.2: icmp_seq=1 ttl=62 time=45.2 ms
64 bytes from 10.20.20.2: icmp_seq=2 ttl=62 time=44.8 ms
64 bytes from 10.20.20.2: icmp_seq=3 ttl=62 time=44.9 ms
64 bytes from 10.20.20.2: icmp_seq=4 ttl=62 time=45.1 ms
```

### NCC Hubとスポークの管理

**Hub一覧確認:**

```bash
gcloud network-connectivity hubs list
```

**Spoke一覧確認:**

```bash
# 全Spokeを表示
gcloud network-connectivity spokes list

# 特定Hub配下のSpokeのみ表示
gcloud network-connectivity spokes list --hub transit-hub
```

**Spoke詳細確認:**

```bash
gcloud network-connectivity spokes describe bo1 \
  --region us-east4
```

**Spoke削除:**

```bash
gcloud network-connectivity spokes delete bo1 \
  --region us-east4
```

**Hub削除:**

```bash
# 全Spoke削除後にHubを削除可能
gcloud network-connectivity hubs delete transit-hub
```

## Private Service Connect

Private Service Connectは、内部IPアドレスでGoogleサービスやサードパーティサービスにプライベート接続する機能。

### Private Service Connect構成要素

| コンポーネント | 役割 | 例 |
|--------------|------|-----|
| **Service Attachment** | サービス提供側が公開するエンドポイント | プロデューサー側 |
| **Endpoint** | サービス消費側が作成するVPC内部IP | コンシューマー側 |

### Private Service Connect設定例

**1. Service Attachment作成（プロデューサー側）:**

```bash
# 内部ロードバランサーのバックエンドサービスをService Attachmentとして公開
gcloud compute service-attachments create my-service-attachment \
  --region us-central1 \
  --producer-forwarding-rule my-forwarding-rule \
  --connection-preference ACCEPT_AUTOMATIC \
  --nat-subnets my-nat-subnet
```

**2. Endpoint作成（コンシューマー側）:**

```bash
# Private Service Connect Endpointを作成
gcloud compute addresses create psc-endpoint \
  --region us-central1 \
  --subnet my-subnet \
  --addresses 10.128.0.100

gcloud compute forwarding-rules create my-psc-endpoint \
  --region us-central1 \
  --network my-vpc \
  --address psc-endpoint \
  --target-service-attachment projects/producer-project/regions/us-central1/serviceAttachments/my-service-attachment
```

**3. Endpoint経由でアクセス:**

```bash
# コンシューマー側から内部IPでアクセス
curl http://10.128.0.100
```

### Private Service Connect + Service Directory統合

Private Service ConnectエンドポイントをService Directoryに登録し、DNS名でアクセス可能にする。

```bash
# PSC EndpointをService Directoryに登録
gcloud service-directory endpoints create psc-endpoint \
  --service my-psc-service \
  --namespace mycompany \
  --location us-central1 \
  --address 10.128.0.100 \
  --port 80 \
  --metadata service_type=private-service-connect
```

## まとめ

**高度なネットワーキングサービスの使い分け:**

| サービス | 用途 | 主要機能 |
|---------|------|---------|
| **Traffic Director** | サービスメッシュ制御プレーン | トラフィック管理、mTLS、マルチクラスタ |
| **Service Directory** | サービス登録・検索 | DNS統合、マルチクラウドディレクトリ |
| **Network Connectivity Center** | ハイブリッドクラウド接続 | Hub and Spoke、ルート交換 |
| **Private Service Connect** | プライベートサービス接続 | 内部IP、サービス公開 |

これらのサービスを組み合わせることで、マイクロサービス・ハイブリッドクラウド・マルチクラウド環境の複雑なネットワーキング要件に対応できる。
