# AWSネットワーキングガイド

AWSのネットワークサービスを活用し、セキュアで高可用性なネットワークアーキテクチャを構築するための実践的なガイドです。

---

## 1. ロードバランシングの基礎

### 1.1 ロードバランサーの種類

| 種類 | 動作レイヤー | ユースケース | 特徴 |
|------|------------|-------------|------|
| **GSLB** (Global Server Load Balancing) | DNS (レイヤー7) | グローバルトラフィック分散 | 地理的ルーティング、ヘルスチェック、フェイルオーバー |
| **ALB** (Application Load Balancer) | HTTP/HTTPS (レイヤー7) | Webアプリケーション | パスベース/ホストベースルーティング、WebSocket、HTTP/2 |
| **NLB** (Network Load Balancer) | TCP/UDP (レイヤー4) | 超低レイテンシ要求 | 秒間数百万リクエスト、静的IP、Elastic IPサポート |
| **CLB** (Classic Load Balancer) | レイヤー4/7 | レガシーアプリケーション | 非推奨 (新規ではALB/NLB使用を推奨) |

### 1.2 セッション永続性 (Session Persistence)

**概要**:
クライアントのリクエストを同じバックエンドサーバーに転送する仕組み。

**実装方法**:

| 方式 | 仕組み | メリット | デメリット |
|------|-------|---------|----------|
| **Cookie-based** | LBがCookieを発行し、セッション情報を保持 | 実装が簡単 | Cookie改ざんリスク |
| **Source IP** | クライアントIPアドレスでルーティング | 状態保持不要 | NAT環境で同じサーバーに集中 |
| **URL Rewriting** | セッションIDをURLに埋め込む | Cookieレスブラウザ対応 | SEO影響、セキュリティリスク |

### 1.3 Elastic Load Balancing (ELB) の選定

**選定フローチャート**:

```
プロトコルは？
├─ HTTP/HTTPS → ALB
│   └─ コンテナ/Lambda対応、パスルーティング必要
├─ TCP/UDP/TLS → NLB
│   └─ 超低レイテンシ、静的IP必要
└─ EC2-Classic (レガシー) → CLB (非推奨)
```

**コード例 - ALB 作成 (AWS CLI)**:

```bash
# セキュリティグループ作成
aws ec2 create-security-group \
    --group-name alb-sg \
    --description "ALB security group" \
    --vpc-id vpc-12345678

aws ec2 authorize-security-group-ingress \
    --group-id sg-12345678 \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Application Load Balancer作成
aws elbv2 create-load-balancer \
    --name my-alb \
    --subnets subnet-12345678 subnet-87654321 \
    --security-groups sg-12345678 \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4

# ターゲットグループ作成
aws elbv2 create-target-group \
    --name my-targets \
    --protocol HTTP \
    --port 80 \
    --vpc-id vpc-12345678 \
    --health-check-protocol HTTP \
    --health-check-path /health \
    --health-check-interval-seconds 30 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2

# リスナー作成
aws elbv2 create-listener \
    --load-balancer-arn arn:aws:elasticloadbalancing:... \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:...

# ターゲット登録
aws elbv2 register-targets \
    --target-group-arn arn:aws:elasticloadbalancing:... \
    --targets Id=i-12345678 Id=i-87654321
```

**コード例 - ALB パスベースルーティング (Python SDK)**:

```python
import boto3

elbv2 = boto3.client('elbv2')

# リスナールール追加 (パスベースルーティング)
elbv2.create_rule(
    ListenerArn='arn:aws:elasticloadbalancing:...',
    Conditions=[
        {
            'Field': 'path-pattern',
            'Values': ['/api/*']
        }
    ],
    Priority=1,
    Actions=[
        {
            'Type': 'forward',
            'TargetGroupArn': 'arn:aws:elasticloadbalancing:...'
        }
    ]
)

# ホストベースルーティング
elbv2.create_rule(
    ListenerArn='arn:aws:elasticloadbalancing:...',
    Conditions=[
        {
            'Field': 'host-header',
            'Values': ['api.example.com']
        }
    ],
    Priority=2,
    Actions=[
        {
            'Type': 'forward',
            'TargetGroupArn': 'arn:aws:elasticloadbalancing:...'
        }
    ]
)
```

---

## 2. 通信プロトコルの基礎

### 2.1 OSI 7層モデル

| レイヤー | 名称 | 機能 | プロトコル例 |
|---------|------|------|------------|
| **7** | アプリケーション層 | ユーザーアプリケーションへのネットワークサービス提供 | HTTP, HTTPS, FTP, SMTP, DNS |
| **6** | プレゼンテーション層 | データの暗号化、圧縮、変換 | SSL/TLS, JPEG, MPEG |
| **5** | セッション層 | セッション確立、維持、終了 | NetBIOS, RPC |
| **4** | トランスポート層 | エンドツーエンドの通信制御、信頼性確保 | TCP, UDP |
| **3** | ネットワーク層 | ルーティング、IPアドレッシング | IP, ICMP, IPsec |
| **2** | データリンク層 | 物理アドレッシング、エラー検出 | Ethernet, Wi-Fi (802.11), PPP |
| **1** | 物理層 | ビット伝送、物理媒体 | イーサネットケーブル、光ファイバー |

### 2.2 TCP vs UDP

| 特性 | TCP | UDP |
|------|-----|-----|
| **接続** | コネクション型 (3-way handshake) | コネクションレス |
| **信頼性** | 保証 (再送、順序保証、エラー検出) | 非保証 |
| **速度** | 遅い (オーバーヘッドあり) | 高速 |
| **用途** | Webブラウジング、ファイル転送、メール | 動画ストリーミング、VoIP、DNS |
| **ヘッダーサイズ** | 20-60バイト | 8バイト |

### 2.3 HTTP メソッドとステータスコード

**HTTPメソッド**:

| メソッド | 用途 | 冪等性 | 安全性 |
|---------|------|-------|-------|
| **GET** | リソース取得 | ✓ | ✓ |
| **POST** | リソース作成、データ送信 | × | × |
| **PUT** | リソース更新/作成 (完全置換) | ✓ | × |
| **PATCH** | リソース部分更新 | × | × |
| **DELETE** | リソース削除 | ✓ | × |
| **HEAD** | ヘッダー情報のみ取得 | ✓ | ✓ |
| **OPTIONS** | 利用可能なメソッド確認 | ✓ | ✓ |

**HTTPステータスコード**:

| コード | カテゴリ | 例 | 意味 |
|-------|---------|---|------|
| **1xx** | 情報 | 100 Continue | リクエスト継続可能 |
| **2xx** | 成功 | 200 OK, 201 Created, 204 No Content | リクエスト成功 |
| **3xx** | リダイレクト | 301 Moved Permanently, 302 Found, 304 Not Modified | リソース移動 |
| **4xx** | クライアントエラー | 400 Bad Request, 401 Unauthorized, 404 Not Found | クライアント側エラー |
| **5xx** | サーバーエラー | 500 Internal Server Error, 502 Bad Gateway, 503 Service Unavailable | サーバー側エラー |

### 2.4 HTTP/2 と HTTP/3

| 特性 | HTTP/1.1 | HTTP/2 | HTTP/3 |
|------|---------|--------|--------|
| **多重化** | 非対応 (Head-of-line blocking) | 対応 (単一TCP接続で多重化) | 対応 (QUIC over UDP) |
| **ヘッダー圧縮** | なし | HPACK | QPACK |
| **サーバープッシュ** | なし | 対応 | 対応 |
| **トランスポート** | TCP | TCP | UDP (QUIC) |
| **パフォーマンス** | 低 | 中 | 高 |

**一般的なベストプラクティス**:
- 新規アプリケーションではHTTP/2以上を使用
- 多数の小さいリソースを配信する場合はHTTP/2の多重化を活用
- パケットロスが多い環境ではHTTP/3を検討

---

## 3. Amazon VPC (Virtual Private Cloud)

### 3.1 VPC アーキテクチャ

**基本構成要素**:

```
AWS Cloud
└── リージョン (e.g., ap-northeast-1)
    └── VPC (10.0.0.0/16)
        ├── Availability Zone 1a
        │   ├── パブリックサブネット (10.0.1.0/24)
        │   │   ├── Internet Gateway経由で外部アクセス可能
        │   │   └── ELB, NAT Gateway配置
        │   └── プライベートサブネット (10.0.11.0/24)
        │       └── RDS, EC2 (アプリサーバー)
        └── Availability Zone 1c
            ├── パブリックサブネット (10.0.2.0/24)
            └── プライベートサブネット (10.0.12.0/24)
```

### 3.2 サブネット設計のベストプラクティス

**CIDR計算例**:

| 要件 | CIDRブロック | 利用可能IPアドレス数 | 用途 |
|------|------------|-------------------|------|
| VPC | 10.0.0.0/16 | 65,536 | 全体の範囲 |
| パブリックサブネット (AZ-1a) | 10.0.1.0/24 | 256 (実質251*) | ELB, NAT Gateway |
| プライベートサブネット (AZ-1a) | 10.0.11.0/24 | 256 (実質251*) | アプリサーバー |
| データベースサブネット (AZ-1a) | 10.0.21.0/24 | 256 (実質251*) | RDS, ElastiCache |

*AWSは各サブネットで5つのIPアドレスを予約: ネットワークアドレス、VPCルーター、DNS、将来の使用、ブロードキャストアドレス

**コード例 - VPC 作成 (AWS CLI)**:

```bash
# VPC作成
aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=my-vpc}]'

# DNS解決有効化
aws ec2 modify-vpc-attribute \
    --vpc-id vpc-12345678 \
    --enable-dns-support

aws ec2 modify-vpc-attribute \
    --vpc-id vpc-12345678 \
    --enable-dns-hostnames

# パブリックサブネット作成
aws ec2 create-subnet \
    --vpc-id vpc-12345678 \
    --cidr-block 10.0.1.0/24 \
    --availability-zone ap-northeast-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-subnet-1a}]'

# プライベートサブネット作成
aws ec2 create-subnet \
    --vpc-id vpc-12345678 \
    --cidr-block 10.0.11.0/24 \
    --availability-zone ap-northeast-1a \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-subnet-1a}]'

# Internet Gateway作成とアタッチ
aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=my-igw}]'

aws ec2 attach-internet-gateway \
    --internet-gateway-id igw-12345678 \
    --vpc-id vpc-12345678

# ルートテーブル作成とルート追加
aws ec2 create-route-table \
    --vpc-id vpc-12345678 \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=public-rt}]'

aws ec2 create-route \
    --route-table-id rtb-12345678 \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id igw-12345678

# サブネットをルートテーブルに関連付け
aws ec2 associate-route-table \
    --route-table-id rtb-12345678 \
    --subnet-id subnet-12345678
```

### 3.3 NAT Gateway vs NAT Instance

| 特性 | NAT Gateway | NAT Instance |
|------|-------------|-------------|
| **管理** | マネージド (AWSが管理) | 自己管理 (EC2インスタンス) |
| **可用性** | 高可用性 (AZ内で自動冗長化) | 単一障害点 (Multi-AZ構成が必要) |
| **パフォーマンス** | 最大45 Gbps | インスタンスタイプに依存 |
| **コスト** | 時間課金 + データ転送課金 | EC2課金のみ |
| **セキュリティグループ** | 非対応 | 対応 |
| **推奨** | ✓ | × (レガシー) |

**コード例 - NAT Gateway 作成 (AWS CLI)**:

```bash
# Elastic IP割り当て
aws ec2 allocate-address --domain vpc

# NAT Gateway作成 (パブリックサブネットに配置)
aws ec2 create-nat-gateway \
    --subnet-id subnet-12345678 \
    --allocation-id eipalloc-12345678 \
    --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=my-nat-gw}]'

# プライベートサブネット用ルートテーブル作成
aws ec2 create-route-table \
    --vpc-id vpc-12345678 \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=private-rt}]'

# NAT Gateway経由でインターネットへのルート追加
aws ec2 create-route \
    --route-table-id rtb-87654321 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id nat-12345678

# プライベートサブネットを関連付け
aws ec2 associate-route-table \
    --route-table-id rtb-87654321 \
    --subnet-id subnet-87654321
```

### 3.4 セキュリティグループ vs ネットワークACL

| 特性 | セキュリティグループ | ネットワークACL |
|------|-------------------|--------------|
| **レベル** | インスタンスレベル | サブネットレベル |
| **ステートフル/ステートレス** | ステートフル (戻りトラフィック自動許可) | ステートレス (戻りトラフィックのルール必要) |
| **ルール** | 許可ルールのみ | 許可/拒否ルール |
| **ルール評価** | すべてのルールを評価 | 番号順に評価 (最初にマッチで停止) |
| **適用対象** | ENI (Elastic Network Interface) | サブネット内のすべてのリソース |
| **ユースケース** | きめ細かいアクセス制御 | サブネットレベルの防御 |

**一般的なベストプラクティス**:
- セキュリティグループで主要なアクセス制御を実装
- ネットワークACLは追加の防御層として使用
- セキュリティグループは最小権限の原則に従う

**コード例 - セキュリティグループ設定 (AWS CLI)**:

```bash
# Webサーバー用セキュリティグループ
aws ec2 create-security-group \
    --group-name web-sg \
    --description "Web server security group" \
    --vpc-id vpc-12345678

# HTTPアクセス許可
aws ec2 authorize-security-group-ingress \
    --group-id sg-12345678 \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# HTTPSアクセス許可
aws ec2 authorize-security-group-ingress \
    --group-id sg-12345678 \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# SSHアクセス許可 (管理用IPのみ)
aws ec2 authorize-security-group-ingress \
    --group-id sg-12345678 \
    --protocol tcp \
    --port 22 \
    --cidr 203.0.113.0/24

# データベース用セキュリティグループ
aws ec2 create-security-group \
    --group-name db-sg \
    --description "Database security group" \
    --vpc-id vpc-12345678

# Webサーバーからのアクセスのみ許可
aws ec2 authorize-security-group-ingress \
    --group-id sg-87654321 \
    --protocol tcp \
    --port 3306 \
    --source-group sg-12345678
```

**コード例 - ネットワークACL設定 (Python SDK)**:

```python
import boto3

ec2 = boto3.client('ec2')

# ネットワークACL作成
response = ec2.create_network_acl(VpcId='vpc-12345678')
acl_id = response['NetworkAcl']['NetworkAclId']

# インバウンドルール追加 (HTTP許可)
ec2.create_network_acl_entry(
    NetworkAclId=acl_id,
    RuleNumber=100,
    Protocol='6',  # TCP
    RuleAction='allow',
    Egress=False,
    CidrBlock='0.0.0.0/0',
    PortRange={'From': 80, 'To': 80}
)

# インバウンドルール追加 (HTTPS許可)
ec2.create_network_acl_entry(
    NetworkAclId=acl_id,
    RuleNumber=110,
    Protocol='6',
    RuleAction='allow',
    Egress=False,
    CidrBlock='0.0.0.0/0',
    PortRange={'From': 443, 'To': 443}
)

# アウトバウンドルール追加 (すべて許可)
ec2.create_network_acl_entry(
    NetworkAclId=acl_id,
    RuleNumber=100,
    Protocol='-1',  # すべてのプロトコル
    RuleAction='allow',
    Egress=True,
    CidrBlock='0.0.0.0/0'
)

# サブネットに関連付け
ec2.replace_network_acl_association(
    AssociationId='aclassoc-12345678',
    NetworkAclId=acl_id
)
```

---

## 4. VPCピアリングと Transit Gateway

### 4.1 VPCピアリング

**概要**:
2つのVPC間でプライベートIPアドレスを使用した通信を可能にする1対1の接続。

**制約**:
- CIDRブロックが重複してはならない
- 推移的なピアリングは不可 (VPC A ↔ VPC B ↔ VPC C の場合、A↔Cは直接接続不可)
- リージョン間、アカウント間でも可能

**コード例 - VPCピアリング接続 (AWS CLI)**:

```bash
# ピアリング接続リクエスト
aws ec2 create-vpc-peering-connection \
    --vpc-id vpc-12345678 \
    --peer-vpc-id vpc-87654321 \
    --peer-region ap-northeast-1

# ピアリング接続承認
aws ec2 accept-vpc-peering-connection \
    --vpc-peering-connection-id pcx-12345678

# ルートテーブルにピアリング接続を追加
aws ec2 create-route \
    --route-table-id rtb-12345678 \
    --destination-cidr-block 10.1.0.0/16 \
    --vpc-peering-connection-id pcx-12345678
```

### 4.2 AWS Transit Gateway

**概要**:
複数のVPCとオンプレミスネットワークを中央ハブで接続するマネージドサービス。

**VPCピアリングとの比較**:

| 特性 | VPCピアリング | Transit Gateway |
|------|-------------|----------------|
| **接続形態** | 1対1 (メッシュ型) | ハブ&スポーク型 |
| **スケーラビリティ** | VPCが増えると接続数が爆発的に増加 (N*(N-1)/2) | 中央集約で管理が容易 |
| **推移的ルーティング** | 非対応 | 対応 |
| **オンプレミス接続** | 不可 | 可能 (VPN, Direct Connect) |
| **コスト** | データ転送のみ | アタッチメント料金 + データ転送 |
| **ユースケース** | 少数VPC間の単純接続 | 大規模ネットワーク、ハイブリッドクラウド |

**コード例 - Transit Gateway 作成 (AWS CLI)**:

```bash
# Transit Gateway作成
aws ec2 create-transit-gateway \
    --description "My Transit Gateway" \
    --options AmazonSideAsn=64512,AutoAcceptSharedAttachments=enable

# VPCアタッチメント作成
aws ec2 create-transit-gateway-vpc-attachment \
    --transit-gateway-id tgw-12345678 \
    --vpc-id vpc-12345678 \
    --subnet-ids subnet-12345678 subnet-87654321

# ルートテーブル作成
aws ec2 create-transit-gateway-route-table \
    --transit-gateway-id tgw-12345678

# ルート追加
aws ec2 create-transit-gateway-route \
    --destination-cidr-block 10.1.0.0/16 \
    --transit-gateway-route-table-id tgw-rtb-12345678 \
    --transit-gateway-attachment-id tgw-attach-12345678
```

---

## 5. Amazon Route 53

### 5.1 ルーティングポリシー

| ポリシー | 用途 | 動作 |
|---------|------|------|
| **Simple** | 単一リソース | 1つのIPアドレスを返す |
| **Weighted** | トラフィック分散、A/Bテスト | 重み付けに基づいて複数リソースに分散 |
| **Latency** | レイテンシ最適化 | 最も低レイテンシのリージョンを返す |
| **Failover** | アクティブ/パッシブフェイルオーバー | プライマリ障害時にセカンダリを返す |
| **Geolocation** | 地理的ルーティング | ユーザーの地理的位置に基づいてルーティング |
| **Geoproximity** | 地理的近接性 + バイアス | 位置とバイアス値でトラフィックをシフト |
| **Multivalue Answer** | 複数の正常なリソースを返す | 最大8つのランダムな正常なレコードを返す |

**コード例 - Route 53 ホストゾーン作成とレコード登録 (AWS CLI)**:

```bash
# ホストゾーン作成
aws route53 create-hosted-zone \
    --name example.com \
    --caller-reference $(date +%s)

# Aレコード作成 (Simple ルーティング)
cat > change-batch.json <<EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "www.example.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {"Value": "203.0.113.1"}
        ]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
    --hosted-zone-id Z1234567890ABC \
    --change-batch file://change-batch.json

# Weighted ルーティング (70%/30% トラフィック分散)
cat > weighted-routing.json <<EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "app.example.com",
        "Type": "A",
        "SetIdentifier": "US-East-1",
        "Weight": 70,
        "TTL": 60,
        "ResourceRecords": [{"Value": "203.0.113.10"}]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "app.example.com",
        "Type": "A",
        "SetIdentifier": "US-West-2",
        "Weight": 30,
        "TTL": 60,
        "ResourceRecords": [{"Value": "198.51.100.10"}]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
    --hosted-zone-id Z1234567890ABC \
    --change-batch file://weighted-routing.json
```

---

## 6. Amazon CloudFront (CDN)

### 6.1 概要

**Amazon CloudFront**は、グローバルに分散されたエッジロケーションを使用してコンテンツを配信するCDNサービスです。

**主要機能**:
- 低レイテンシ配信
- DDoS保護 (AWS Shield統合)
- SSL/TLS暗号化
- カスタムオリジン対応 (S3, EC2, ELB, オンプレミス)
- Lambda@Edge (エッジでのコード実行)

### 6.2 キャッシュ動作とTTL

| 設定 | 説明 | 推奨値 |
|------|------|-------|
| **最小TTL** | キャッシュの最小保持時間 | 0秒 (動的コンテンツ) |
| **最大TTL** | キャッシュの最大保持時間 | 31,536,000秒 (1年) |
| **デフォルトTTL** | オリジンがCache-Controlヘッダーを返さない場合のTTL | 86,400秒 (1日) |

**一般的なベストプラクティス**:
- 静的コンテンツ (画像、CSS、JS): 長いTTL (数日〜1年)
- 動的コンテンツ (API、ユーザー固有データ): 短いTTL (0秒〜数分) またはキャッシュ無効化

**コード例 - CloudFront ディストリビューション作成 (AWS CLI)**:

```bash
# S3オリジンのCloudFrontディストリビューション作成
cat > distribution-config.json <<EOF
{
  "CallerReference": "$(date +%s)",
  "Comment": "My CDN",
  "Enabled": true,
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-my-bucket",
        "DomainName": "my-bucket.s3.amazonaws.com",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-my-bucket",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"]
    },
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {"Forward": "none"}
    },
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000
  }
}
EOF

aws cloudfront create-distribution \
    --distribution-config file://distribution-config.json
```

---

## まとめ

AWSネットワーキングの設計では、以下の要素を総合的に考慮します:

1. **ロードバランシング**: ALB (レイヤー7) vs NLB (レイヤー4)
2. **VPCアーキテクチャ**: サブネット設計、マルチAZ構成
3. **セキュリティ**: セキュリティグループ、ネットワークACL、最小権限の原則
4. **接続性**: VPCピアリング vs Transit Gateway (スケール要件)
5. **DNS**: Route 53 ルーティングポリシー (レイテンシ、地理的、重み付け)
6. **CDN**: CloudFront でグローバル配信、キャッシュ戦略

一般的なベストプラクティスとして、高可用性のためにマルチAZ構成を採用し、セキュリティのために複数の防御層を実装し、パフォーマンスのためにCDNとキャッシュを活用することが推奨されます。
