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

---

## 関連スキル

- **developing-google-cloud** — GCP固有の開発・セキュリティ・データエンジニアリング
- **developing-terraform** — Terraform HCL/モジュール設計（AWSプロバイダー含む）
- **managing-docker** — Docker固有のコンテナパターン
- **designing-monitoring** — クラウド非依存の監視・オブザーバビリティ設計
- **practicing-devops** — DevOps方法論・CI/CDパイプライン設計
- **building-rag-systems** — クラウド非依存のRAGシステム構築
- **practicing-llmops** — LLMアプリケーション運用フレームワーク
