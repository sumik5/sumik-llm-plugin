# VPC アーキテクチャ設計ガイド

Amazon VPC（Virtual Private Cloud）の設計パターン、サブネット構成、CIDR計画、マルチAZデプロイ、ハイブリッド接続、およびセキュリティ制御の包括的ガイド。

> **関連**: ロードバランシングは [NETWORKING.md](./NETWORKING.md)、CDPネットワークパターンは [CLOUD-DESIGN-PATTERNS.md](./CLOUD-DESIGN-PATTERNS.md) を参照

---

## 1. VPC設計の基本原則

### 1.1 VPC構成要素

| 要素 | 説明 | 設計上の意味 |
|------|------|------------|
| **VPC** | 論理的に分離されたネットワーク空間 | CIDRブロックで定義、リージョン単位 |
| **Subnet** | VPC内のCIDRサブセット | AZ単位、Public/Private分離 |
| **Route Table** | トラフィックの経路制御 | サブネットに関連付け |
| **Internet Gateway (IGW)** | VPCとインターネットの接続点 | VPCに1つ、Public Subnetのルートに設定 |
| **NAT Gateway** | Private SubnetからのOutbound通信 | AZ単位で配置（冗長化） |
| **Security Group (SG)** | インスタンスレベルのファイアウォール | ステートフル、許可ルールのみ |
| **Network ACL (NACL)** | サブネットレベルのファイアウォール | ステートレス、許可/拒否ルール |
| **VPC Endpoint** | AWSサービスへのプライベート接続 | インターネット経由なしでS3/DynamoDB等にアクセス |

### 1.2 CIDRブロック設計

#### CIDR選定のベストプラクティス

| 原則 | 説明 | 例 |
|------|------|-----|
| **十分なアドレス空間** | 将来の拡張を考慮して大きめに確保 | `/16`（65,536 IP）推奨 |
| **重複回避** | VPC Peering/Transit GW接続時にCIDRが重複すると通信不可 | オンプレミスのCIDRと重複しないように |
| **RFC 1918準拠** | プライベートIPアドレス範囲を使用 | `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` |
| **サブネット分割** | AZ数 × レイヤー数で分割 | 3AZ × 3レイヤー = 9サブネット |

#### CIDR設計例（3AZ構成）

```
VPC: 10.0.0.0/16（65,536 IP）

├── Public Subnet（Web/ALB層）
│   ├── AZ-a: 10.0.0.0/24   (256 IP)
│   ├── AZ-c: 10.0.1.0/24   (256 IP)
│   └── AZ-d: 10.0.2.0/24   (256 IP)
│
├── Private Subnet（App層）
│   ├── AZ-a: 10.0.10.0/24  (256 IP)
│   ├── AZ-c: 10.0.11.0/24  (256 IP)
│   └── AZ-d: 10.0.12.0/24  (256 IP)
│
├── Private Subnet（DB層）
│   ├── AZ-a: 10.0.20.0/24  (256 IP)
│   ├── AZ-c: 10.0.21.0/24  (256 IP)
│   └── AZ-d: 10.0.22.0/24  (256 IP)
│
└── 予約済み: 10.0.100.0/22 以降（将来拡張用）
```

**注意**: 各サブネットで5つのIPアドレスがAWS予約（ネットワークアドレス、VPCルーター、DNS、将来用、ブロードキャスト）。

---

## 2. サブネットアーキテクチャ

### 2.1 3層アーキテクチャ（推奨）

```
┌─────────────────────────────────────────────┐
│                  Internet                     │
│                     │                         │
│              Internet Gateway                 │
│                     │                         │
│  ┌──────────────────┼──────────────────┐     │
│  │  Public Subnet    │                  │     │
│  │  (ALB, NAT GW,   │  Bastion Host)   │     │
│  │       AZ-a       AZ-c       AZ-d    │     │
│  └──────────────────┼──────────────────┘     │
│                     │                         │
│  ┌──────────────────┼──────────────────┐     │
│  │  Private Subnet (App)                │     │
│  │  (EC2, ECS, Lambda)                  │     │
│  │       AZ-a       AZ-c       AZ-d    │     │
│  └──────────────────┼──────────────────┘     │
│                     │                         │
│  ┌──────────────────┼──────────────────┐     │
│  │  Private Subnet (Data)               │     │
│  │  (RDS, ElastiCache, DynamoDB)        │     │
│  │       AZ-a       AZ-c       AZ-d    │     │
│  └──────────────────────────────────────┘     │
└─────────────────────────────────────────────┘
```

### 2.2 ルーティングテーブル設計

#### Public Subnet ルートテーブル

| 宛先 | ターゲット | 備考 |
|------|----------|------|
| `10.0.0.0/16` | local | VPC内通信 |
| `0.0.0.0/0` | igw-xxx | インターネット向け |

#### Private Subnet ルートテーブル

| 宛先 | ターゲット | 備考 |
|------|----------|------|
| `10.0.0.0/16` | local | VPC内通信 |
| `0.0.0.0/0` | nat-xxx | NAT Gateway経由 |

#### Data Subnet ルートテーブル

| 宛先 | ターゲット | 備考 |
|------|----------|------|
| `10.0.0.0/16` | local | VPC内通信のみ |

---

## 3. NAT Gateway / Internet Gateway 設計

### 3.1 IGW vs NAT Gateway

| 要素 | Internet Gateway | NAT Gateway |
|------|-----------------|-------------|
| 方向 | 双方向（Inbound/Outbound） | Outboundのみ |
| 配置 | VPCに1つ | AZ単位で配置推奨 |
| コスト | 無料（データ転送量課金のみ） | 時間課金 + データ処理量課金 |
| 可用性 | AWS管理、高可用性 | AZ障害で影響、複数AZ配置推奨 |
| 適用 | Public Subnet | Private Subnet |

### 3.2 NAT Gateway 冗長化パターン

```
┌───────── AZ-a ─────────┐  ┌───────── AZ-c ─────────┐
│  Public: NAT GW (a)    │  │  Public: NAT GW (c)    │
│           ↑             │  │           ↑             │
│  Private: App (a)       │  │  Private: App (c)       │
│  Route: 0.0.0.0/0      │  │  Route: 0.0.0.0/0      │
│    → NAT GW (a)        │  │    → NAT GW (c)        │
└─────────────────────────┘  └─────────────────────────┘
```

- 各AZのPrivate SubnetはそのAZのNAT Gatewayを参照
- AZ障害時、他AZのNAT GWは影響なし
- コスト vs 可用性のトレードオフ（全AZに配置するとコスト倍増）

### 3.3 NAT Gateway vs NAT Instance

| 比較 | NAT Gateway | NAT Instance |
|------|-------------|-------------|
| 可用性 | AWS管理、AZ内で冗長 | 自分で冗長化が必要 |
| 帯域幅 | 最大100 Gbps | インスタンスタイプに依存 |
| メンテナンス | 不要 | パッチ適用が必要 |
| コスト | 高め（時間+データ） | 安め（小インスタンスなら） |
| 推奨 | 本番環境 | 開発・検証環境（コスト削減目的） |

---

## 4. VPC間接続パターン

### 4.1 接続方式比較

| 方式 | 接続数 | レイテンシー | 帯域幅 | コスト | 適用場面 |
|------|--------|------------|--------|--------|---------|
| **VPC Peering** | 1対1 | 最低 | 制限なし | 低 | 少数VPC間の直接接続 |
| **Transit Gateway** | N対N（Hub-Spoke） | やや高い | 最大50 Gbps | 中 | 多数VPC/オンプレミスの集約 |
| **PrivateLink** | サービス単位 | 低 | 制限なし | 中 | 特定サービスの公開 |

### 4.2 Transit Gateway アーキテクチャ

```
┌──────────┐    ┌──────────┐    ┌──────────┐
│ VPC-Prod │    │ VPC-Dev  │    │ VPC-Stg  │
└────┬─────┘    └────┬─────┘    └────┬─────┘
     │               │               │
     └───────────────┼───────────────┘
                     │
              ┌──────┴──────┐
              │ Transit GW  │
              └──────┬──────┘
                     │
              ┌──────┴──────┐
              │   VPN/DX    │
              └──────┬──────┘
                     │
              ┌──────┴──────┐
              │ オンプレミス │
              └─────────────┘
```

- **ルートテーブル分離**: Transit GW内でルートテーブルを分割し、VPC間通信を制御
- **共有サービスVPC**: DNS、監視、セキュリティを一元化VPCに配置
- **スケーラビリティ**: VPC追加時はTGWアタッチメント追加のみ

### 4.3 VPN / Direct Connect

| 方式 | 帯域幅 | レイテンシー | コスト | セットアップ時間 | 適用場面 |
|------|--------|------------|--------|----------------|---------|
| **Site-to-Site VPN** | 最大1.25 Gbps | インターネット依存 | 低 | 数時間～数日 | 小～中規模、PoC |
| **Direct Connect** | 1/10/100 Gbps | 安定・低レイテンシー | 高 | 数週間～数ヶ月 | 大規模、安定性重視 |
| **DX + VPN (暗号化)** | DX帯域幅 | 安定 | 高 | 数週間～数ヶ月 | 暗号化＋安定性 |

---

## 5. セキュリティグループ / NACL設計

### 5.1 Security Group vs Network ACL

| 特徴 | Security Group | Network ACL |
|------|---------------|-------------|
| 適用レベル | インスタンス/ENI | サブネット |
| ステートフル | ✅（戻りトラフィック自動許可） | ❌（明示的に許可必要） |
| ルール | 許可のみ | 許可 + 拒否 |
| 評価順序 | 全ルール評価 | ルール番号順（最初にマッチで決定） |
| デフォルト | 全アウトバウンド許可 | 全トラフィック許可 |

### 5.2 Security Group 設計パターン

#### レイヤー別チェーン

```
sg-alb:     Inbound: 0.0.0.0/0:443
sg-app:     Inbound: sg-alb:8080         ← ALBからのみ許可
sg-db:      Inbound: sg-app:3306         ← Appからのみ許可
sg-bastion: Inbound: <会社IP>/32:22     ← 特定IPからのみ
sg-mgmt:    Inbound: sg-bastion:22       ← Bastionからのみ
```

- **参照ベースルール**: IPアドレスではなくSecurity GroupのIDで参照
- **最小権限**: 必要なポート・ソースのみ許可
- **分離**: レイヤーごとにSGを分割

### 5.3 NACL設計のベストプラクティス

- **サブネット境界での防御**: SGの前段としてNACLで粗いフィルタリング
- **ルール番号設計**: 100番刻みで設定（将来の挿入に対応）
- **エフェメラルポート**: NACLはステートレスのため、戻りポート（1024-65535）の許可が必須
- **拒否ルール活用**: 特定IPのブロック（DDoS対策等）

---

## 6. VPC Endpoint

### 6.1 エンドポイントタイプ

| タイプ | 対象サービス | 接続方式 | コスト |
|--------|------------|---------|--------|
| **Gateway Endpoint** | S3, DynamoDB | ルートテーブルで制御 | 無料 |
| **Interface Endpoint** | その他AWSサービス | ENI + PrivateLink | 時間課金 + データ処理量 |

### 6.2 Gateway Endpoint（S3/DynamoDB向け）

```
Private Subnet Route Table:
  宛先: pl-xxxx (S3 prefix list)
  ターゲット: vpce-xxx (Gateway Endpoint)
```

- **コスト削減**: NAT Gateway経由のデータ処理料金を回避
- **セキュリティ**: インターネットを経由しない
- **エンドポイントポリシー**: 特定バケットのみアクセス許可可能

### 6.3 Interface Endpoint（PrivateLink）

- **DNS解決**: AWSサービスのDNSがプライベートIPに解決
- **適用例**: Systems Manager, CloudWatch Logs, ECR, KMS, STS
- **コスト判断**: 大量データ転送時はNAT GW経由より安価な場合がある

---

## 7. マルチアカウントVPC設計

### 7.1 AWS Organizations + VPC構成

```
Management Account
├── Security OU
│   ├── Log Archive Account      ← CloudTrail, Config
│   └── Security Tooling Account ← GuardDuty, Security Hub
│
├── Infrastructure OU
│   └── Network Account          ← Transit Gateway, Direct Connect
│       └── Shared VPC           ← DNS, NTP, 共有サービス
│
├── Workload OU
│   ├── Production Account       ← VPC-Prod
│   ├── Staging Account          ← VPC-Stg
│   └── Development Account      ← VPC-Dev
│
└── Sandbox OU
    └── Individual Accounts      ← 実験・学習用
```

### 7.2 RAM (Resource Access Manager) によるサブネット共有

- **VPC共有**: 1つのVPCを複数アカウントで共有
- **メリット**: IP管理の一元化、コスト削減（NAT GW共有）
- **注意点**: セキュリティ境界の設計、Security Groupはアカウント単位
