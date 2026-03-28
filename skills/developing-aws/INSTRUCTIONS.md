# AWS 開発・アーキテクチャ・運用ガイド

AWS上でのアプリケーション設計・構築・運用を包括的にカバーするスキル。**システム設計**、**サーバーレス**、**CDK (IaC)**、**EKS (Kubernetes)**、**SRE運用**、**コスト最適化**、**セキュリティ**、**Generative AI (Bedrock)** の8つの柱で構成。

---

## AWSグローバルインフラストラクチャ

| 概念 | 説明 | 設計上の意味 |
|------|------|------------|
| **Region** | 地理的に独立したデータセンター群（例: `us-east-1`, `ap-northeast-1`） | レイテンシ要件・コンプライアンス・サービス可用性で選定 |
| **Availability Zone (AZ)** | Region内の物理的に分離されたデータセンター群 | マルチAZデプロイでフォールトトレランスを確保 |
| **Local Zone** | 特定の都市圏に近接した低レイテンシ拠点 | 単桁ミリ秒レイテンシが必要な場合に検討 |
| **Edge Location** | CloudFront/Route 53のPoP | CDNキャッシュ、DNS解決の高速化 |

### アカウント戦略

| パターン | 用途 | メリット |
|---------|------|---------|
| アプリ別分離 | 各アプリを独立アカウントで運用 | 完全な分離、コスト管理が容易 |
| ビジネスドメイン別 | ドメインごとにアカウント分離 | 関連サービスの集約、レイテンシ最適化 |
| 機能別（推奨） | ネットワーク/監視/セキュリティ別 | 運用チーム単位の責務分離 |

→ AWS Control Tower + Landing Zone でマルチアカウント環境を構築

---

## AWSサービスマップ

### コンピュート

| サービス | 用途 | 選定基準 |
|---------|------|---------|
| **EC2** | 汎用仮想マシン | フルコントロールが必要、特殊なOS/ランタイム |
| **Lambda** | イベント駆動サーバーレス関数 | 短時間実行（最大15分）、スパイク対応 |
| **ECS (Fargate)** | マネージドコンテナ実行 | コンテナベース、サーバー管理不要 |
| **EKS** | マネージドKubernetes | K8sエコシステム活用、マルチクラウド |
| **App Runner** | コンテナ/ソースの自動デプロイ | 最小構成でWebアプリ起動 |

### ストレージ

| サービス | タイプ | 選定基準 |
|---------|--------|---------|
| **S3** | オブジェクト | 非構造化データ、静的ホスティング、データレイク |
| **EBS** | ブロック | EC2永続ボリューム、高IOPS |
| **EFS** | ファイル | 複数インスタンス共有、Lambda統合 |
| **RDS/Aurora** | リレーショナルDB | ACID準拠、複雑なクエリ |
| **DynamoDB** | NoSQL (Key-Value/Document) | 単桁msレイテンシ、無制限スケール |
| **ElastiCache** | インメモリ | セッション管理、キャッシュ（Redis/Memcached） |
| **DocumentDB** | ドキュメントDB | MongoDB互換 |
| **Neptune** | グラフDB | ソーシャルネットワーク、推薦エンジン |
| **Keyspaces** | ワイドカラム | Cassandra互換 |
| **Timestream** | 時系列DB | IoTデータ、メトリクス |
| **Redshift** | DWH | 大規模分析クエリ |

### ネットワーク

| サービス | 用途 | 選定基準 |
|---------|------|---------|
| **VPC** | 仮想プライベートネットワーク | 全AWS環境の基盤 |
| **ALB** | L7ロードバランサー | HTTP/HTTPS、パスベースルーティング |
| **NLB** | L4ロードバランサー | TCP/UDP、超低レイテンシ |
| **CloudFront** | CDN | グローバル配信、エッジキャッシュ |
| **Route 53** | DNS | ドメイン管理、ヘルスチェック、フェイルオーバー |
| **API Gateway** | API管理 | REST/HTTP/WebSocket API |
| **PrivateLink** | プライベート接続 | VPCエンドポイント経由のサービスアクセス |

### メッセージング・統合

| サービス | パターン | 選定基準 |
|---------|---------|---------|
| **SQS** | キューイング | デカップリング、非同期処理 |
| **SNS** | Pub/Sub | ファンアウト、通知 |
| **EventBridge** | イベントバス | イベント駆動アーキテクチャ、ルールベースルーティング |
| **Step Functions** | ワークフロー | 複数ステップのオーケストレーション |
| **Kinesis** | ストリーミング | リアルタイムデータ処理 |
| **MSK** | Apache Kafka | 大規模ストリーミング、Kafka互換 |
| **AppSync** | GraphQL | リアルタイムサブスクリプション |

### セキュリティ・ID

| サービス | 用途 |
|---------|------|
| **IAM** | アクセス制御（ユーザー、ロール、ポリシー） |
| **Cognito** | ユーザー認証（User Pool + Identity Pool） |
| **KMS** | 暗号鍵管理 |
| **Secrets Manager** | シークレット管理 |
| **GuardDuty** | 脅威検出 |
| **Security Hub** | セキュリティポスチャ管理 |
| **WAF / Shield** | Web アプリファイアウォール / DDoS防御 |

### 監視・運用

| サービス | 用途 |
|---------|------|
| **CloudWatch** | メトリクス、ログ、アラーム、ダッシュボード |
| **X-Ray** | 分散トレーシング |
| **Systems Manager** | パッチ管理、パラメータストア、自動化 |
| **Config** | リソース構成追跡、コンプライアンス |
| **CloudTrail** | API操作の監査ログ |

### AI/ML

| サービス | 用途 |
|---------|------|
| **Bedrock** | Foundation Models のマネージドアクセス |
| **SageMaker** | ML モデルの構築・トレーニング・デプロイ |
| **Amazon Q** | AI アシスタント（Business / Developer） |
| **Comprehend** | 自然言語処理 |
| **Rekognition** | 画像・動画分析 |
| **Transcribe** | 音声→テキスト |
| **Textract** | ドキュメントからのデータ抽出 |

---

## Well-Architected Framework（6つの柱）

| 柱 | 焦点 | 主要実践 |
|----|------|---------|
| **Operational Excellence** | 自動化・継続改善 | IaC（CloudFormation/CDK）、CloudWatch監視、自動インシデント対応 |
| **Security** | データ・リスク保護 | IAM最小権限、KMS暗号化、GuardDuty脅威検出 |
| **Reliability** | フォールトトレランス | マルチAZデプロイ、DLQエラー処理、ELBヘルスチェック |
| **Performance Efficiency** | リソース効率 | 適切なサービス選定、Auto Scaling、CloudFront活用 |
| **Cost Optimization** | コスト効率 | Savings Plans、rightsizing、Spot Instances、Cost Explorer |
| **Sustainability** | 環境影響最小化 | 効率的リソース利用、Gravitonプロセッサ、マネージドサービス活用 |

### Well-Architected レビュープロセス

```
ワークロード定義 → 柱別評価 → リスク特定 → 改善計画 → 実施 → 継続レビュー
                                    ↑                              ↓
                                    └──────── フィードバックループ ──┘
```

→ **Well-Architected Tool**（AWS Console内）で自動評価・レポート生成が可能

---

## サービス選定フレームワーク

### コンピュート選定

```
要件分析
    ↓
【実行時間】
    ├─ <15分・イベント駆動 → Lambda
    ├─ 常時稼働・コンテナ化済み
    │   ├─ K8sエコシステム必要 → EKS
    │   └─ シンプルなコンテナ実行 → ECS/Fargate
    ├─ フルOS制御が必要 → EC2
    └─ 最小構成でWeb公開 → App Runner
```

### ストレージ選定

```
データ特性
    ├─ 構造化データ + ACID
    │   ├─ 高可用性・Aurora互換 → Aurora
    │   └─ 標準的RDB → RDS (MySQL/PostgreSQL)
    ├─ Key-Valueアクセス + 無制限スケール → DynamoDB
    ├─ 非構造化データ（ファイル・画像・動画） → S3
    ├─ 低レイテンシキャッシュ → ElastiCache
    ├─ グラフ関係 → Neptune
    └─ 時系列データ → Timestream
```

### メッセージング選定

| 要件 | 推奨サービス |
|------|------------|
| 1:1 非同期処理（順序保証なし） | SQS Standard |
| 1:1 非同期処理（順序保証あり） | SQS FIFO |
| 1:N ファンアウト | SNS + SQS |
| イベント駆動ルーティング | EventBridge |
| 複数ステップの調整 | Step Functions |
| 大規模ストリーミング | Kinesis / MSK |
| リアルタイム双方向通信 | AppSync / API Gateway WebSocket |

---

## 共有責任モデル

```
┌──────────────────────────────────────────┐
│              顧客の責任                    │
│  ("Security IN the Cloud")                │
│  ・データの暗号化                          │
│  ・IAMポリシー設計                         │
│  ・OS/アプリのパッチ管理                   │
│  ・ネットワーク設定（SG/NACL）             │
│  ・アプリケーションコードのセキュリティ     │
├──────────────────────────────────────────┤
│              AWSの責任                     │
│  ("Security OF the Cloud")                │
│  ・物理インフラ                            │
│  ・ハイパーバイザー                        │
│  ・マネージドサービスのパッチ              │
│  ・グローバルネットワーク                  │
│  ・ハードウェアセキュリティ                │
└──────────────────────────────────────────┘
```

---

## 詳細リファレンス

### システム設計
- [SYSTEM-DESIGN.md](references/SYSTEM-DESIGN.md) — 設計トレードオフ、分散システムの誤謬、アーキテクチャパターン
- [CLOUD-DESIGN-PATTERNS.md](references/CLOUD-DESIGN-PATTERNS.md) — AWS CDP全57パターン（可用性、スケーリング、キャッシュ、非同期処理、運用保守、ネットワーク）
- [ENTERPRISE-ARCHITECTURE.md](references/ENTERPRISE-ARCHITECTURE.md) — マルチアカウント戦略、Landing Zone、非機能要求グレード、14業務システムパターン
- [VPC-ARCHITECTURE.md](references/VPC-ARCHITECTURE.md) — VPC/サブネット/CIDR設計、NAT/IGW、Transit Gateway、Security Group/NACL
- [STORAGE-SELECTION.md](references/STORAGE-SELECTION.md) — RDS/DynamoDB/S3/ElastiCache選定ガイド
- [NETWORKING.md](references/NETWORKING.md) — ロードバランシング、CDN、Route 53設計、ネットワーク監視・トラブルシューティング
- [COMPUTE-SELECTION.md](references/COMPUTE-SELECTION.md) — EC2/Lambda/ECS/EKS/Fargate選定
- [MESSAGING-INTEGRATION.md](references/MESSAGING-INTEGRATION.md) — SQS/SNS/EventBridge/Step Functions
- [DESIGN-CASE-STUDIES.md](references/DESIGN-CASE-STUDIES.md) — 8つの実践的システム設計ケーススタディ
- [MIGRATION-STRATEGIES.md](references/MIGRATION-STRATEGIES.md) — 7R移行戦略、AWS MGN、DB移行、大規模データ移行、移行後最適化

### サーバーレス
- [SERVERLESS-PATTERNS.md](references/SERVERLESS-PATTERNS.md) — Lambda/API Gateway/DynamoDB/S3パターン
- [SERVERLESS-DEPLOYMENT.md](references/SERVERLESS-DEPLOYMENT.md) — SAM/CDKデプロイ、監視、Well-Architected実践

### インフラストラクチャ
- [CDK.md](references/CDK.md) — AWS CDK Constructs、マルチスタック、テスト、DevSecOps
- [EKS-FUNDAMENTALS.md](references/EKS-FUNDAMENTALS.md) — EKS基礎、クラスタ管理、ネットワーキング
- [EKS-OPERATIONS.md](references/EKS-OPERATIONS.md) — EKSセキュリティ、デプロイ戦略、HA/DR、スケーリング

### データベース・データエンジニアリング
- [DATABASE-SERVICES.md](references/DATABASE-SERVICES.md) — RDS/Aurora/DynamoDB/ElastiCache/その他DBサービス詳細
- [DATABASE-MIGRATION.md](references/DATABASE-MIGRATION.md) — DMS、SCT、移行パターン、Zero-ETL統合
- [DATA-ENGINEERING.md](references/DATA-ENGINEERING.md) — Kinesis/Firehose/MSK/Glue/EMR、データパイプライン設計

### 開発者ツール
- [DEVELOPER-TOOLS.md](references/DEVELOPER-TOOLS.md) — CodeCommit/CodeBuild/CodeDeploy/CodePipeline、CI/CD、デプロイ戦略

### 運用・セキュリティ
- [SRE-AUTOMATION.md](references/SRE-AUTOMATION.md) — IaC自動化、リリース自動化、インフラメンテナンス
- [OBSERVABILITY.md](references/OBSERVABILITY.md) — CloudWatch/X-Ray、SLI/SLO、ログ分析
- [RESILIENCE.md](references/RESILIENCE.md) — レジリエンスパターン、Fault Injection Service、DR戦略
- [SECURITY.md](references/SECURITY.md) — IAM/VPC Security/KMS/Cognito/EKSセキュリティ
- [SECURITY-ADVANCED.md](references/SECURITY-ADVANCED.md) — GuardDuty/Macie/Inspector/Security Hub、高度なセキュリティサービス
- [SYSOPS-OPERATIONS.md](references/SYSOPS-OPERATIONS.md) — Systems Manager、Auto Scaling、コスト管理、バックアップ、トラブルシューティング
- [COST-OPTIMIZATION.md](references/COST-OPTIMIZATION.md) — FinOps、CCoE組織、rightsizing、Savings Plans、タギングガバナンス、ネットワークコスト最適化

### AI/ML
- [BEDROCK-API.md](references/BEDROCK-API.md) — Bedrock API、モデル選定、プロンプトエンジニアリング
- [RAG-AGENTS.md](references/RAG-AGENTS.md) — Knowledge Bases、RAG構築、Bedrock Agents
- [GENAI-ARCHITECTURE.md](references/GENAI-ARCHITECTURE.md) — GenAIセキュリティ、パフォーマンス、スケーリング
- [SAGEMAKER-ML.md](references/SAGEMAKER-ML.md) — SageMaker Studio、データ準備、モデル開発・トレーニング・デプロイ・監視、MLOps
- [GUARDRAILS.md](references/GUARDRAILS.md) — Bedrock Guardrails、コンテンツフィルタリング、PII検出、クロスアカウント保護
- [BEDROCK-SCALING.md](references/BEDROCK-SCALING.md) — GenAIスケーリング5柱（Reliability/Performance/Cost/Observability/DR）
- [BEDROCK-INTEGRATION.md](references/BEDROCK-INTEGRATION.md) — Bedrock AWS統合パターン（Lambda/Step Functions/EventBridge/SageMaker）
- [BEDROCK-INDUSTRY-CASES.md](references/BEDROCK-INDUSTRY-CASES.md) — 業界別Bedrockアーキテクチャ（E-commerce/Finance/Media）

---

## 関連スキル

- **developing-google-cloud** — GCP固有の開発・セキュリティ・データエンジニアリング
- **developing-terraform** — Terraform HCL/モジュール設計（AWSプロバイダー含む）
- **managing-docker** — Docker固有のコンテナパターン
- **designing-monitoring** — クラウド非依存の監視・オブザーバビリティ設計
- **practicing-devops** — DevOps方法論・CI/CDパイプライン設計
- **building-rag-systems** — クラウド非依存のRAGシステム構築
- **practicing-llmops** — LLMアプリケーション運用フレームワーク

---

## Bedrock 入門・SDK開発

Bedrockの基礎的な使い方からSDK開発、Embedding活用まで。

| トピック | リファレンス | 概要 |
|---------|-----------|------|
| コンソール・プレイグラウンド | [BEDROCK-GETTING-STARTED.md](references/BEDROCK-GETTING-STARTED.md) | モデル有効化、テキスト/イメージプレイグラウンド、パラメータ調整 |
| SDK開発（Python/JS/curl） | [BEDROCK-SDK-DEVELOPMENT.md](references/BEDROCK-SDK-DEVELOPMENT.md) | Boto3 invoke_model、LangChain連携、ストリーム、JS SDK |
| Embedding・セマンティック検索 | [BEDROCK-EMBEDDING-SEARCH.md](references/BEDROCK-EMBEDDING-SEARCH.md) | Titan Embeddings、コサイン類似度、マルチモーダル検索 |

> 本番アーキテクチャ（API仕様・Guardrails・RAG・スケーリング）は既存Bedrockリファレンス群を参照。

---

## クラウドネイティブアプリケーション

AWSサービスを活用したクラウドネイティブなアプリケーション設計・実装パターン。

| トピック | リファレンス | 概要 |
|---------|-----------|------|
| アーキテクチャパターン | [CLOUD-NATIVE-ARCHITECTURE.md](references/CLOUD-NATIVE-ARCHITECTURE.md) | 2-Tier/3-Tier、モバイル/IoT構成、REST API設計 |
| Cognito認証 | [COGNITO-AUTHENTICATION.md](references/COGNITO-AUTHENTICATION.md) | User Pools/Federated Identities、OAuth連携、API Gateway統合 |
| 実践アプリパターン11種 | [CLOUD-NATIVE-APP-PATTERNS.md](references/CLOUD-NATIVE-APP-PATTERNS.md) | 写真共有/勤怠管理/IoT/リアルタイム収集等 |

> サーバーレスの詳細は [SERVERLESS-PATTERNS.md](references/SERVERLESS-PATTERNS.md) を参照。

---

## エンタープライズ運用・ガバナンス

企業内でのAWS利用における設計パターンと運用監視の実践。

| トピック | リファレンス | 概要 |
|---------|-----------|------|
| ガバナンス・運用監視 | [ENTERPRISE-GOVERNANCE-PRACTICE.md](references/ENTERPRISE-GOVERNANCE-PRACTICE.md) | Organizations/SCP、CloudWatch Logs/Events、Inspector、SSM、Config |
| 業務システム設計パターン | [ENTERPRISE-SYSTEM-PATTERNS.md](references/ENTERPRISE-SYSTEM-PATTERNS.md) | 9設計パターン、VPC設計、移行テクニック（DMS/SMS/Snowball） |

> アカウント戦略・Landing Zoneは [ENTERPRISE-ARCHITECTURE.md](references/ENTERPRISE-ARCHITECTURE.md) を参照。

---

## インフラ自動化・高可用性

CloudFormationを中心としたIaC実践と、高可用性・耐障害性の実装パターン。

| トピック | リファレンス | 概要 |
|---------|-----------|------|
| インフラ自動化 | [INFRASTRUCTURE-AUTOMATION.md](references/INFRASTRUCTURE-AUTOMATION.md) | CloudFormationテンプレート、EB/OpsWorks、CLI/SDK |
| データストア運用 | [INFRASTRUCTURE-DATA-STORAGE.md](references/INFRASTRUCTURE-DATA-STORAGE.md) | S3/EBS/EFS/RDS/ElastiCache/DynamoDB運用実践 |
| HA・耐障害性実装 | [INFRASTRUCTURE-HA-RESILIENCE.md](references/INFRASTRUCTURE-HA-RESILIENCE.md) | CloudWatch回復、デカップリング、べき等リトライ、Auto Scaling |

> CDKは [CDK.md](references/CDK.md)、レジリエンスパターン概要は [RESILIENCE.md](references/RESILIENCE.md) を参照。

---

## コンテナ設計・運用（ECS/Fargate）

AWSコンテナサービスの設計指針とCI/CD・運用実践。

| トピック | リファレンス | 概要 |
|---------|-----------|------|
| コンテナ設計 | [CONTAINER-DESIGN.md](references/CONTAINER-DESIGN.md) | ECS/Fargate設計、Well-Architected×コンテナ5本柱 |
| コンテナ運用・CI/CD | [CONTAINER-OPERATIONS.md](references/CONTAINER-OPERATIONS.md) | Blue/Green、FireLens、Trivy/Dockle、Fargate Bastion |

> EKSは [EKS-FUNDAMENTALS.md](references/EKS-FUNDAMENTALS.md)、CI/CD汎用は [DEVELOPER-TOOLS.md](references/DEVELOPER-TOOLS.md) を参照。

---

## セキュリティガバナンス・検知・対応

セキュリティの「なぜ（WHY）」と「検知→調査→対応」の統合フロー。

| トピック | リファレンス | 概要 |
|---------|-----------|------|
| セキュリティガバナンス | [SECURITY-GOVERNANCE.md](references/SECURITY-GOVERNANCE.md) | NIST CSF、ISO 27001、リスクアセスメント、ポリシー策定 |
| 検知・インシデントレスポンス | [SECURITY-DETECTION-RESPONSE.md](references/SECURITY-DETECTION-RESPONSE.md) | GuardDuty/Detective、フォレンジック、疑似攻撃演習 |

> AWS技術セキュリティは [SECURITY.md](references/SECURITY.md)、エンタープライズセキュリティは [SECURITY-ADVANCED.md](references/SECURITY-ADVANCED.md) を参照。

---

## VPC接続パターン

VPCの基礎から外部接続パターンまでの実践ガイド。

| トピック | リファレンス | 概要 |
|---------|-----------|------|
| VPC接続実践 | [NETWORK-VPC-CONNECTIVITY.md](references/NETWORK-VPC-CONNECTIVITY.md) | ENI、PrivateLink、VPCピアリング、Site-to-Site VPN |

> VPC設計ガイドは [VPC-ARCHITECTURE.md](references/VPC-ARCHITECTURE.md)、ALB/NLB/CloudFrontは [NETWORKING.md](references/NETWORKING.md) を参照。
