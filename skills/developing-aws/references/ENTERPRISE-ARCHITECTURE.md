# AWSエンタープライズアーキテクチャ設計ガイド

AWSにおけるエンタープライズ基盤設計、マルチアカウント戦略、Landing Zone構築、および14種類の定番業務システムパターンを解説する。

> **関連**: VPC設計は [VPC-ARCHITECTURE.md](./VPC-ARCHITECTURE.md)、セキュリティは [SECURITY-ADVANCED.md](./SECURITY-ADVANCED.md) を参照

---

## 1. マルチアカウント戦略

### 1.1 AWS Organizations

| 概念 | 説明 | 設計上の意味 |
|------|------|------------|
| **Organization** | アカウント群の論理的なグループ | 一括請求、SCP適用 |
| **OU (Organizational Unit)** | アカウントの論理グループ | 階層構造でポリシー継承 |
| **SCP (Service Control Policy)** | OUに適用するアクセス制御 | IAMに優先する制限（ガードレール） |
| **AWS SSO / IAM Identity Center** | 一元的なアクセス管理 | 各アカウントへのSSO |

### 1.2 推奨OU構造

| OU | 用途 | 主要アカウント | SCP例 |
|----|------|--------------|-------|
| **Security** | セキュリティ監視・ログ集約 | Log Archive, Security Tooling | リージョン制限 |
| **Infrastructure** | 共有インフラ（ネットワーク、DNS） | Network, Shared Services | 指定サービスのみ許可 |
| **Workloads** | 本番/ステージング/開発ワークロード | Prod, Stg, Dev | 環境別権限制御 |
| **Sandbox** | 実験・学習・PoC | 個人アカウント | コスト上限設定 |
| **Suspended** | 凍結アカウント（退職者等） | - | 全アクション拒否 |

### 1.3 SCP設計パターン

```json
// リージョン制限SCP（東京/大阪のみ許可）
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["ap-northeast-1", "ap-northeast-3"]
        },
        "ArnNotLike": {
          "aws:PrincipalARN": "arn:aws:iam::*:role/OrganizationAdmin"
        }
      }
    }
  ]
}
```

---

## 2. AWS Control Tower / Landing Zone

### 2.1 Control Tower 概要

| コンポーネント | 説明 |
|--------------|------|
| **Landing Zone** | マルチアカウント環境のベースライン構成 |
| **ガードレール** | 予防的（SCP）＋発見的（Config Rules）なコントロール |
| **Account Factory** | 新アカウントの標準テンプレートによるプロビジョニング |
| **ダッシュボード** | コンプライアンス状態の一元監視 |

### 2.2 ガードレールの種類

| タイプ | 実装 | 動作 | 例 |
|--------|------|------|-----|
| **予防的（Preventive）** | SCP | 禁止アクションをブロック | S3パブリックアクセスブロック |
| **発見的（Detective）** | AWS Config Rules | 違反を検出・通知 | CloudTrail無効化の検出 |
| **プロアクティブ** | CloudFormation Guard | デプロイ前にテンプレート検証 | 暗号化なしリソースの拒否 |

### 2.3 Landing Zone 構築チェックリスト

- [ ] Organizations有効化、OU構造設計
- [ ] Management Account → 最小限のリソースのみ
- [ ] Log Archive Account → CloudTrail、Config、VPC Flow Logs集約
- [ ] Security Tooling Account → GuardDuty、Security Hub委任
- [ ] Network Account → Transit Gateway、Direct Connect管理
- [ ] IAM Identity Center → SSO設定、権限セット定義
- [ ] Account Factory → アカウントテンプレート作成
- [ ] ガードレール → 予防的＋発見的コントロール有効化
- [ ] コスト管理 → AWS Budgets、Cost Anomaly Detection設定

---

## 3. 非機能要求グレード

### 3.1 非機能要求の分類

AWS設計において考慮すべき非機能要求を体系的に整理する。

| カテゴリ | 評価項目 | AWSでの実現手段 |
|---------|---------|----------------|
| **可用性** | 稼働率（99.9%/99.99%/99.999%） | Multi-AZ, Multi-Region, Auto Scaling |
| **性能** | レスポンスタイム、スループット | インスタンスタイプ選定, CloudFront, ElastiCache |
| **拡張性** | ピーク時対応、将来の成長 | Auto Scaling, サーバーレス |
| **運用保守性** | 監視、バックアップ、パッチ管理 | CloudWatch, AWS Backup, Systems Manager |
| **移行性** | オンプレミス→クラウド移行の容易さ | AWS MGN, DMS, DataSync |
| **セキュリティ** | 認証、暗号化、監査 | IAM, KMS, CloudTrail, GuardDuty |
| **コスト** | 初期/運用コスト最適化 | Savings Plans, Spot, rightsizing |

### 3.2 可用性グレード

| グレード | 稼働率 | 年間ダウンタイム | AWSアーキテクチャ |
|---------|--------|----------------|------------------|
| **レベル1** | 99% | 約3.65日 | Single AZ |
| **レベル2** | 99.9% | 約8.76時間 | Multi-AZ (Active-Standby) |
| **レベル3** | 99.99% | 約52.6分 | Multi-AZ (Active-Active) |
| **レベル4** | 99.999% | 約5.26分 | Multi-Region (Active-Active) |

---

## 4. 定番業務システム14パターン

### パターン1: キャンペーンサイト

| 要素 | 設計 |
|------|------|
| **特性** | 短期間・アクセス集中型、一時的な大量トラフィック |
| **構成** | CloudFront + S3（静的）+ Auto Scaling（動的） |
| **ポイント** | Scheduled Scale Outで事前準備、終了後即削除でコスト最適化 |
| **適用CDP** | Cache Distribution, Scheduled Scale Out, Ondemand Activation |

### パターン2: コーポレートサイト

| 要素 | 設計 |
|------|------|
| **特性** | 高可用性重視、適度なアクセス量、静的コンテンツ中心 |
| **構成** | CloudFront + S3 + ALB + EC2 (Multi-AZ) + RDS (Multi-AZ) |
| **ポイント** | WAFでセキュリティ確保、CloudFrontでグローバル配信 |
| **適用CDP** | Direct Hosting, Cache Distribution, Multi-Datacenter, WAF Proxy |

### パターン3: パフォーマンス重視イントラ

| 要素 | 設計 |
|------|------|
| **特性** | 社内利用、レスポンス重視、同時接続数は限定的 |
| **構成** | ALB + EC2 (高性能インスタンス) + ElastiCache + RDS |
| **ポイント** | Inmemory DB Cacheで応答速度最適化、VPN/Direct Connectで社内接続 |
| **適用CDP** | Inmemory DB Cache, Scale Up, State Sharing |

### パターン4: 高可用性イントラ

| 要素 | 設計 |
|------|------|
| **特性** | 業務停止が許されない基幹系、24/365運用 |
| **構成** | Multi-AZ全レイヤー + RDS Multi-AZ + Auto Scaling + Route 53 Health Check |
| **ポイント** | Deep Health Checkで障害の早期検知、Weighted Transitionでリリース |
| **適用CDP** | Multi-Datacenter, Deep Health Check, DB Replication, Routing-Based HA |

### パターン5: バックアップシステム

| 要素 | 設計 |
|------|------|
| **特性** | データ保全重視、RPO/RTO要件に基づく設計 |
| **構成** | AWS Backup + S3 Glacier + クロスリージョンレプリケーション |
| **ポイント** | Snapshotパターンの自動化、ライフサイクルポリシーでコスト最適化 |
| **適用CDP** | Snapshot, Multi-Datacenter |

### パターン6: ファイルサーバー

| 要素 | 設計 |
|------|------|
| **特性** | 大容量ファイル共有、同時アクセス、アクセス権管理 |
| **構成** | Amazon FSx for Windows File Server / EFS + VPN/Direct Connect |
| **ポイント** | NFS Sharingパターン、AD統合、バックアップの自動化 |
| **適用CDP** | NFS Sharing, NFS Replica, Backnet |

### パターン7: 構造化データ分析

| 要素 | 設計 |
|------|------|
| **特性** | RDBベースの分析ワークロード、SQLクエリ重視 |
| **構成** | Redshift + Glue (ETL) + QuickSight (可視化) |
| **ポイント** | Read Replicaで本番DB負荷回避、Glueでデータパイプライン自動化 |
| **適用CDP** | Read Replica, Queuing Chain |

### パターン8: 非構造化データ分析

| 要素 | 設計 |
|------|------|
| **特性** | ログ・テキスト・画像等の大量非構造化データ処理 |
| **構成** | S3 (Data Lake) + EMR/Athena + Glue + QuickSight |
| **ポイント** | S3を中心としたデータレイク構成、Athenaでサーバーレス分析 |
| **適用CDP** | Web Storage, Storage Index |

### パターン9: サーバーレスアプリケーション

| 要素 | 設計 |
|------|------|
| **特性** | イベント駆動、自動スケーリング、従量課金 |
| **構成** | API Gateway + Lambda + DynamoDB + S3 + CloudFront |
| **ポイント** | サーバー管理不要、コールドスタート対策、同時実行制御 |
| **適用CDP** | Direct Hosting, Direct Object Upload, Fanout |

### パターン10: コンテナアプリケーション

| 要素 | 設計 |
|------|------|
| **特性** | マイクロサービス、ポータビリティ、CI/CD |
| **構成** | ECS/EKS (Fargate) + ALB + ECR + CodePipeline |
| **ポイント** | サービスメッシュ（App Mesh）、Blue/Greenデプロイ |
| **適用CDP** | Clone Server, Scale Out, Self Registration |

### パターン11: モバイルアプリケーション

| 要素 | 設計 |
|------|------|
| **特性** | モバイルバックエンド、プッシュ通知、オフライン対応 |
| **構成** | API Gateway + Lambda + Cognito + DynamoDB + SNS (Push) |
| **ポイント** | Cognito User Pool/Identity Poolで認証、AppSyncでリアルタイム同期 |
| **適用CDP** | Direct Object Upload, State Sharing, Fanout |

### パターン12: マイクロサービス

| 要素 | 設計 |
|------|------|
| **特性** | サービス分離、独立デプロイ、ドメイン駆動 |
| **構成** | ALB/API GW + ECS/Lambda + SQS/SNS/EventBridge + 各サービス専用DB |
| **ポイント** | サービス間通信設計（同期:REST/gRPC、非同期:イベント）、サーキットブレーカー |
| **適用CDP** | Queuing Chain, Fanout, Priority Queue, State Sharing |

### パターン13: AI/IoTシステム

| 要素 | 設計 |
|------|------|
| **特性** | 大量デバイスデータ、リアルタイム処理、ML推論 |
| **構成** | IoT Core + Kinesis + Lambda + SageMaker/Bedrock + S3 + DynamoDB |
| **ポイント** | ストリーミングパイプライン設計、エッジ推論（Greengrass） |
| **適用CDP** | Queuing Chain, Fanout, Storage Index |

### パターン14: ハイブリッドクラウド

| 要素 | 設計 |
|------|------|
| **特性** | オンプレミス＋AWS共存、段階的移行 |
| **構成** | VPN/Direct Connect + Transit Gateway + Route 53 Hybrid DNS |
| **ポイント** | AD連携、ハイブリッドDNS、段階的ワークロード移行 |
| **適用CDP** | Backnet, CloudHub, Shared Service |

---

## 5. ビジネスシステム選定フローチャート

```
ワークロード種別の判断
├── 一時的（キャンペーン等）
│   └── パターン1: キャンペーンサイト
│
├── 外部公開Webサイト
│   ├── コーポレート/ブランド → パターン2: コーポレートサイト
│   └── ECサイト/SaaS → パターン10 or 12: コンテナ/マイクロサービス
│
├── 社内システム
│   ├── レスポンス重視 → パターン3: パフォーマンス重視イントラ
│   └── 可用性重視 → パターン4: 高可用性イントラ
│
├── データ分析
│   ├── 構造化データ(SQL) → パターン7: 構造化データ分析
│   └── 非構造化データ → パターン8: 非構造化データ分析
│
├── バックエンド/API
│   ├── シンプル・イベント駆動 → パターン9: サーバーレス
│   ├── 複雑・マイクロサービス → パターン12: マイクロサービス
│   └── モバイル特化 → パターン11: モバイルアプリ
│
├── IoT/AI
│   └── パターン13: AI/IoTシステム
│
└── オンプレミス共存
    └── パターン14: ハイブリッドクラウド
```

---

## 6. Well-Architected Framework 実践チェック

各ビジネスシステムパターン設計時に確認すべき6つの柱:

| 柱 | チェック項目 |
|----|------------|
| **運用効率性** | IaC化されているか、監視・アラート設定済みか、自動復旧設計か |
| **セキュリティ** | IAM最小権限か、暗号化（転送時/保存時）か、WAF設定済みか |
| **信頼性** | Multi-AZ配置か、Auto Scaling設定か、バックアップ＋DR計画あるか |
| **パフォーマンス** | 適切なインスタンスタイプか、キャッシュ活用しているか、CDN利用か |
| **コスト最適化** | Savings Plans検討済みか、rightsizing済みか、不要リソース削除か |
| **サステナビリティ** | Graviton利用検討か、リソース効率的な設計か |
