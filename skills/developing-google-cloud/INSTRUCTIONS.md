# Google Cloud 開発・セキュリティ・データエンジニアリング・ネットワーク・キャッシングガイド

このスキルは、Google Cloud Platform（GCP）でのアプリケーション開発・デプロイ・プラットフォームセキュリティ・データエンジニアリング・ネットワークエンジニアリング・インメモリキャッシングを包括的にカバーします。**Cloud Run中心のサーバーレスデプロイメント**、**GCPセキュリティサービス活用**、**データエンジニアリング**、**ネットワークエンジニアリング（VPC設計・ハイブリッド接続・LB・CDN・監視・高度なネットワーキング）**、**Memorystore（マネージドRedis/Memcachedキャッシング）**、**エンタープライズアーキテクチャ（アカウント設計・移行戦略）**、**コンピューティング選択（GCE/GKE/GAE/Run/Functions）**、**コンテナオーケストレーション（GKE/Kubernetes）**、**監視・運用設計**、**BigQuery分析** の10本柱で構成されています。

---

## GCPセキュリティサービスマップ

GCPのセキュリティは6つの柱で構成され、各柱に対応するサービス群が存在します。適切なサービスを判断するための全体マップです。

### カテゴリ別主要サービス

| カテゴリ | サービス | 用途 |
|---------|---------|------|
| **Identity & Access** | Cloud Identity | 組織の中央ID管理、SSO、MFA |
| | Cloud IAM | リソースへのきめ細かいアクセス制御 |
| | Workload Identity Federation | 外部IDプロバイダーとの連携（AWS、Azure、GitHub等） |
| **Network Security** | VPC | プライベートネットワーク、サブネット分離 |
| | Cloud Armor | DDoS防御、WAF、カスタムセキュリティポリシー |
| | VPC Service Controls | サービス境界の設定、データ流出防止 |
| | Cloud NAT | プライベートインスタンスの外部通信 |
| **Zero Trust** | BeyondCorp Enterprise | コンテキストアウェアアクセス |
| | Identity-Aware Proxy (IAP) | 内部アプリケーション保護 |
| **Data Protection** | Cloud KMS | 暗号鍵管理（CMEK：顧客管理暗号鍵） |
| | Cloud DLP | 機密データ検出・匿名化（PII、クレジットカード等） |
| | Secret Manager | APIキー、パスワード、証明書の安全な保管 |
| **Monitoring & Logging** | Cloud Logging | 統合ログ管理、監査ログ |
| | Cloud Monitoring | メトリクス収集、アラート |
| | Security Command Center (SCC) | 包括的なセキュリティポスチャ管理、脆弱性検出 |
| **Threat Detection** | Chronicle | 脅威ハンティング、SIEM/SOAR |
| **Workload Security** | Shielded VM | 検証済みブート、vTPM、整合性監視 |
| | Binary Authorization | コンテナイメージの署名検証 |
| | GKE Security | Pod Security Policy、Workload Identity、ネットワークポリシー |
| | Artifact Registry | コンテナイメージの脆弱性スキャン |
| **DevSecOps** | Cloud Build + Binary Authorization | セキュアCI/CDパイプライン |
| **Multi-Cloud** | Anthos | マルチクラウドセキュリティ管理 |
| | Anthos Config Management | ポリシー一貫性 |
| **Compliance & Governance** | Resource Manager | 組織階層、プロジェクト管理、ポリシー継承 |
| | Cloud Asset Inventory | リソース棚卸、変更履歴追跡 |
| | Policy Intelligence | IAMポリシー分析、推奨事項 |

### サービス選択フロー

```
セキュリティ要件
    ↓
【カテゴリ判定】
    ├─ ユーザー認証・認可？ → Cloud Identity + IAM + Workload Identity Federation
    ├─ Zero Trust導入？ → BeyondCorp Enterprise + IAP
    ├─ ネットワーク境界防御？ → VPC + Cloud Armor + VPC Service Controls
    ├─ データ保護？ → Cloud KMS + Cloud DLP + Secret Manager
    ├─ 監視・検出？ → Cloud Logging + SCC + Cloud Monitoring
    ├─ 脅威ハンティング？ → Chronicle
    ├─ ワークロード保護？ → Binary Authorization + Artifact Registry + Shielded VM
    ├─ DevSecOps CI/CD？ → Cloud Build + Binary Authorization
    ├─ マルチクラウド？ → Anthos + Anthos Config Management
    ├─ インシデント対応？ → VPC Flow Logs + Cloud Logging + Chronicle
    └─ コンプライアンス？ → Resource Manager + Cloud Asset Inventory + Policy Intelligence
```

---

## GCPセキュリティの6つの柱

Google Cloudのセキュリティは、以下の6つの柱で体系化されています。各柱の概要と対応サービスを理解してください。

| 柱 | 概要 | 主要サービス |
|----|------|------------|
| **運用セキュリティ** | 脅威検出・インシデント対応・継続的監視 | SCC、Cloud Logging、Cloud Monitoring、Chronicle |
| **ネットワークセキュリティ** | 境界防御・トラフィック制御・DDoS対策 | VPC、Cloud Armor、VPC Service Controls、Cloud NAT |
| **データセキュリティ** | 暗号化・機密データ保護・データ主権 | Cloud KMS、Cloud DLP、Secret Manager |
| **サービス&ID** | 認証・認可・最小権限の原則・アクセス制御 | Cloud Identity、Cloud IAM、Workload Identity Federation |
| **物理&ハードウェア** | データセンターセキュリティ・ハードウェア暗号化（Google管理） | Titan Security Chip、Shielded VM |
| **脅威管理** | 脆弱性管理・脅威インテリジェンス・自動修復 | Artifact Registry脆弱性スキャン、SCC、reCAPTCHA Enterprise |

詳細な実装ガイドは **リファレンスファイル** を参照してください。

---

## Cloud Run デプロイ概要

Cloud Runは、Dockerコンテナをインフラ管理なしでデプロイできるサーバーレスプラットフォームです。ステートレスHTTP/gRPCワークロードに最適化されています。

### サービス選択テーブル

| サービス | 最適なワークロード | スケーリング | 管理オーバーヘッド |
|---------|------------------|------------|----------------|
| **Cloud Run** | ステートレスHTTP/gRPC、可変トラフィック | 自動（ゼロスケール可） | **最小** |
| **GKE** | ステートフル、マルチテナント、複雑なオーケストレーション | 手動+自動 | **高** |
| **App Engine** | Webアプリケーション、PaaS環境 | 自動 | 低 |
| **Cloud Functions** | イベント駆動、短時間処理（<9分） | 自動 | 最小 |
| **Compute Engine** | カスタムOS、フル制御、レガシー移行 | 手動 | **非常に高** |

**Cloud Runを選ぶべきケース:**
- Dockerfileで定義されたカスタムランタイムが必要
- トラフィックが不定期または急激な増減がある
- ステートレスアーキテクチャを採用している

### gcloud CLIクイックリファレンス

```bash
# 初期セットアップ
gcloud init
gcloud projects create my-project --name="Project"
gcloud config set project my-project
gcloud services enable run.googleapis.com

# 基本デプロイ
gcloud run deploy my-service \
  --image gcr.io/my-project/app:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated

# カスタム設定でデプロイ
gcloud run deploy my-service \
  --image gcr.io/my-project/app:latest \
  --platform managed \
  --region us-central1 \
  --memory 2Gi \
  --cpu 2 \
  --max-instances 100 \
  --concurrency 80 \
  --timeout 3600 \
  --set-env-vars "DB_HOST=10.0.0.1" \
  --no-allow-unauthenticated

# トラフィック分割（カナリアデプロイ）
gcloud run services update-traffic my-service \
  --to-revisions my-service-v2=10,my-service-v1=90 \
  --region us-central1
```

### デプロイ判断テーブル

| デプロイ方式 | 最適なケース | メリット | デメリット |
|------------|------------|---------|---------|
| **gcloud CLI** | 手動デプロイ、検証環境 | シンプル、即座に実行可能 | 手動実行、再現性低い |
| **Cloud Build** | CI/CDパイプライン、チーム開発 | 自動化、ビルド・テスト・デプロイ一体化 | 初期設定コスト |
| **Terraform** | IaC、複数環境管理、監査要件 | バージョン管理、再現性、差分管理 | 学習コスト、ステート管理必要 |

**推奨アプローチ:**
- 開発環境: gcloud CLI（手動確認重視）
- ステージング・本番: Cloud Build（自動化、再現性）
- マルチクラウド・複雑構成: Terraform（IaC）

### スケーリング設定ガイド

| パラメータ | 説明 | デフォルト | 推奨範囲 |
|----------|------|----------|---------|
| **concurrency** | 1インスタンスが同時処理するリクエスト数 | 80 | 10-1000 |
| **min-instances** | 最小インスタンス数（コールドスタート回避） | 0 | 本番: 1-10 |
| **max-instances** | 最大インスタンス数（コスト上限制御） | 100 | 本番: 100-1000 |
| **cpu** | CPUコア数 | 1 | 1-8 |
| **memory** | メモリ容量 | 512MiB | 128MiB-32GiB |

**ワークロード別推奨設定:**

| ワークロード | concurrency | min-instances | CPU割り当て |
|------------|------------|--------------|-----------|
| REST API（軽量） | 80-100 | 0-1 | CPU-on-request |
| REST API（重い処理） | 10-20 | 2-5 | CPU-on-request |
| WebSocket | 10-50 | 5-10 | **CPU-always** |
| バッチ処理 | 1-5 | 0 | **CPU-always** |
| イベント駆動（Pub/Sub） | 10-50 | 0 | CPU-on-request |

### セキュリティチェックリスト

**IAM認証:**
- [ ] 本番環境では `--no-allow-unauthenticated` を設定
- [ ] サービスアカウントに最小権限（`roles/run.invoker` のみ）

```bash
# サービスアカウント作成
gcloud iam service-accounts create cloud-run-invoker

# Invoker権限付与
gcloud run services add-iam-policy-binding my-service \
  --member="serviceAccount:cloud-run-invoker@my-project.iam.gserviceaccount.com" \
  --role="roles/run.invoker" \
  --region us-central1
```

**コンテナセキュリティ:**
- [ ] Artifact Registryの脆弱性スキャンを有効化
- [ ] `distroless` または `alpine` ベースイメージを使用
- [ ] Dockerfileで非rootユーザーを指定（`USER`）
- [ ] シークレットはSecret Manager経由で取得

```bash
# Secret Managerからシークレットを取得
gcloud run deploy my-service \
  --image gcr.io/my-project/app:latest \
  --update-secrets DB_PASSWORD=db-password:latest
```

**ネットワークセキュリティ:**
- [ ] 内部リソース（Cloud SQL等）へのアクセスはVPC経由
- [ ] 内部トラフィックのみ許可する場合は `--ingress internal`

```bash
# VPCコネクタ作成
gcloud compute networks vpc-access connectors create my-connector \
  --region us-central1 \
  --range 10.8.0.0/28

# Cloud RunにVPCコネクタを設定
gcloud run deploy my-service \
  --image gcr.io/my-project/app:latest \
  --vpc-connector my-connector \
  --vpc-egress all-traffic
```

### コスト最適化チェックリスト

**料金モデル理解:**

| 課金要素 | 料金（米国、概算） |
|---------|----------------|
| CPU時間 | vCPU-秒あたり $0.00002400 |
| メモリ時間 | GiB-秒あたり $0.00000250 |
| リクエスト数 | 100万リクエストあたり $0.40 |
| Egress | GBあたり $0.12 |

**ベストプラクティス:**
- [ ] 開発環境では `min-instances=0`（完全スケールダウン）
- [ ] concurrencyを高める（インスタンス数削減）
- [ ] WebSocket以外は CPU-on-request を使用
- [ ] 負荷テストでメモリ・CPUを最適化
- [ ] 低価格リージョン選択（us-central1等）
- [ ] CDN（Cloud CDN）で静的コンテンツをキャッシュ

```bash
# コスト最適化設定例
gcloud run deploy cost-optimized-api \
  --image gcr.io/my-project/api:latest \
  --region us-central1 \
  --memory 512Mi \
  --cpu 1 \
  --concurrency 100 \
  --min-instances 0 \
  --max-instances 100 \
  --cpu-throttling  # CPU-on-request
```

---

## ユーザー確認の原則（AskUserQuestion）

以下の判断が必要な場合は AskUserQuestion ツールで確認すること。

### 確認すべき場面

**デプロイ方式の選択:**
- 手動デプロイ（gcloud CLI）、自動CI/CD（Cloud Build）、IaC（Terraform）のどれか
- 理由: プロジェクトのフェーズや運用体制によって最適解が異なる

**リージョン選択:**
- ユーザー基盤の地理的位置、コンプライアンス要件、コストを考慮
- 例: 日本ユーザー向けなら `asia-northeast1`（東京）

**認証方式:**
- Public（`--allow-unauthenticated`）か、IAM認証（`--no-allow-unauthenticated`）か
- 理由: セキュリティ要件によって決定

**CPU割り当て方式:**
- CPU-on-request（デフォルト）か、CPU-always か
- 理由: WebSocket・バックグラウンド処理以外は CPU-on-request が推奨だが、ワークロード特性を確認

**min-instances設定:**
- 0（コスト削減）か、1以上（コールドスタート回避）か
- 理由: 本番環境では SLA 要件により決定

**セキュリティアーキテクチャ設計:**
- VPC Service Controls、CMEK（Cloud KMS）、Binary Authorizationの要否
- 理由: コンプライアンス要件（HIPAA、PCI DSS等）により決定

### 確認不要な場面（ベストプラクティスに従う）

- コンテナポート 8080（Cloud Runのデフォルト）
- ステートレス設計（Cloud Runの前提）
- IAM最小権限（`roles/run.invoker` のみ付与）
- シークレット管理（Secret Manager使用、環境変数禁止）
- 脆弱性スキャン（Artifact Registryで自動有効化）

---

## リファレンスファイル一覧

詳細な実装ガイドは以下のファイルを参照してください。

### Cloud Run デプロイメント（9ファイル）

| ファイル | 内容 |
|---------|------|
| **[CLOUDRUN-SETUP.md](references/CLOUDRUN-SETUP.md)** | 開発環境セットアップ、SDK インストール、認証設定、複数環境管理 |
| **[CLOUDRUN-CONTAINERIZATION.md](references/CLOUDRUN-CONTAINERIZATION.md)** | Dockerfile 最適化、マルチステージビルド、Cloud Run 向けベストプラクティス |
| **[CLOUDRUN-DEPLOYMENT.md](references/CLOUDRUN-DEPLOYMENT.md)** | デプロイ戦略（Blue/Green、カナリア）、トラフィック分割、ロールバック |
| **[CLOUDRUN-CI-CD.md](references/CLOUDRUN-CI-CD.md)** | Cloud Build パイプライン、cloudbuild.yaml、自動テスト・デプロイ |
| **[CLOUDRUN-SCALING.md](references/CLOUDRUN-SCALING.md)** | オートスケーリング詳細、負荷テスト、パフォーマンスチューニング |
| **[CLOUDRUN-SECURITY.md](references/CLOUDRUN-SECURITY.md)** | IAM詳細、VPC、Secret Manager、Binary Authorization |
| **[CLOUDRUN-MONITORING.md](references/CLOUDRUN-MONITORING.md)** | Cloud Monitoring、Logging、Trace、アラート設定 |
| **[CLOUDRUN-COST-OPTIMIZATION.md](references/CLOUDRUN-COST-OPTIMIZATION.md)** | 料金計算、コスト分析、最適化テクニック |
| **[CLOUDRUN-ADVANCED-TOPICS.md](references/CLOUDRUN-ADVANCED-TOPICS.md)** | 将来トレンド、エコシステム統合、マルチクラウド、エッジ、AI/ML |

### GCP プラットフォームセキュリティ（10ファイル）

| ファイル | 内容 |
|---------|------|
| **[COMPLIANCE-GOVERNANCE.md](references/COMPLIANCE-GOVERNANCE.md)** | セキュリティ基盤、コンプライアンス要件（HIPAA、PCI DSS等）、ガバナンス |
| **[IDENTITY-ACCESS.md](references/IDENTITY-ACCESS.md)** | Resource Manager、Cloud Identity、IAM、Workload Identity Federation |
| **[NETWORK-SECURITY.md](references/NETWORK-SECURITY.md)** | VPC、Cloud Armor、VPC Service Controls、ハイブリッド接続 |
| **[DATA-PROTECTION.md](references/DATA-PROTECTION.md)** | Cloud KMS、Cloud DLP、Secret Manager、暗号化戦略 |
| **[LOGGING-MONITORING.md](references/LOGGING-MONITORING.md)** | Cloud Logging、Security Command Center、監査ログ、アラート |
| **[WORKLOAD-SECURITY.md](references/WORKLOAD-SECURITY.md)** | Image Hardening、Container Security、Binary Authorization、Shielded VM |
| **[DEVSECOPS-PIPELINES.md](references/DEVSECOPS-PIPELINES.md)** | DevSecOps CI/CD、Terraform IaCセキュリティ、設定スキャン、シークレット管理 |
| **[ANTHOS-SECURITY.md](references/ANTHOS-SECURITY.md)** | Anthosマルチクラウドセキュリティ、ACM/Gatekeeper、Service Mesh |
| **[ZERO-TRUST-BEYONDCORP.md](references/ZERO-TRUST-BEYONDCORP.md)** | Zero Trust原則、BeyondCorp Enterprise、IAP、デバイスポスチャ |
| **[INCIDENT-RESPONSE.md](references/INCIDENT-RESPONSE.md)** | インシデント対応計画、フォレンジック分析、VPC Flow Logs、証拠保全 |

### データエンジニアリング（5ファイル）

| ファイル | 内容 |
|---------|------|
| **[DATA-STORAGE-SELECTION.md](references/DATA-STORAGE-SELECTION.md)** | GCPストレージサービス選択フレームワーク、決定木、アクセスパターン、ライフサイクル管理 |
| **[DATA-WAREHOUSING.md](references/DATA-WAREHOUSING.md)** | BigQuery設計（テーブル種別・パーティショニング・クラスタリング・BigQuery ML・コスト最適化） |
| **[DATA-PIPELINES.md](references/DATA-PIPELINES.md)** | EL/ELT/ETLパターン、バッチ/ストリーミング、Dataflow/Dataproc/Cloud Composer |
| **[DATA-MIGRATION.md](references/DATA-MIGRATION.md)** | ネットワーク接続（VPN/Interconnect）、マイグレーションツール、Database Migration Service |
| **[DATA-GOVERNANCE.md](references/DATA-GOVERNANCE.md)** | Dataplex Catalog、メタデータ管理、データリネージ、マルチクラウド設計 |

### ネットワークエンジニアリング（6ファイル）

| ファイル | 内容 |
|---------|------|
| **[VPC-DESIGN.md](references/VPC-DESIGN.md)** | VPCアーキテクチャ設計、CIDR計画、IPアドレッシング、ルーティング（静的/動的/Cloud Router）、Shared VPC vs VPC Peering、NAT、ファイアウォール実装 |
| **[HYBRID-CONNECTIVITY.md](references/HYBRID-CONNECTIVITY.md)** | Cloud Interconnect（Dedicated/Partner）、IPsec VPN（Route-based/HA）、Cloud Router/BGP、フェイルオーバー/DR戦略 |
| **[LOAD-BALANCING-CDN.md](references/LOAD-BALANCING-CDN.md)** | ロードバランサー選択（External/Internal、L4/L7）、HTTP(S) Global LB、Internal TCP/UDP LB、Cloud CDN、レイテンシ最適化 |
| **[NETWORK-SECURITY.md](references/NETWORK-SECURITY.md)** | VPC基礎、サブネット設計、ファイアウォール戦略、Cloud Armor、VPC Service Controls、Private Google Access、IAMネットワーク権限、NGFWインサーション |
| **[NETWORK-MONITORING.md](references/NETWORK-MONITORING.md)** | VPC Flow Logs、Firewall Rules Logging、VPC Audit Logs、Packet Mirroring、ログエクスポート（Logs Router） |
| **[ADVANCED-NETWORKING.md](references/ADVANCED-NETWORKING.md)** | Traffic Director、Istio/Service Mesh、Service Directory、Network Connectivity Center（Hub and Spoke） |

### Memorystore キャッシング（3ファイル）

| ファイル | 内容 |
|---------|------|
| **[MEMORYSTORE-FUNDAMENTALS.md](references/MEMORYSTORE-FUNDAMENTALS.md)** | アーキテクチャ概要、Redis vs Memcached比較、データ型・ユースケース、キャッシュパターン（Cache-Aside/Write-Through/Write-Behind）、無効化戦略、エビクションポリシー、GCPサービス統合 |
| **[MEMORYSTORE-OPERATIONS.md](references/MEMORYSTORE-OPERATIONS.md)** | プロビジョニング（gcloud/Terraform/Cloud Build）、インスタンス構成（Basic/Standard ティア）、VPCネットワーキング、パフォーマンスエンジニアリング（ベンチマーク・レイテンシ最適化）、スケーリング、セキュリティ（暗号化・IAM・監査） |
| **[MEMORYSTORE-RESILIENCE.md](references/MEMORYSTORE-RESILIENCE.md)** | 高可用性（SLA 99.9%・マルチゾーン・自動フェイルオーバー）、DR（バックアップ・RPO/RTO設計）、監視（Cloud Monitoring・Prometheus・SLOアラート）、インシデント管理、クラウドネイティブ統合（マイクロサービス・サーバーレス） |

### エンタープライズアーキテクチャ（3ファイル）

| ファイル | 内容 |
|---------|------|
| **[ENTERPRISE-ACCOUNT-DESIGN.md](references/ENTERPRISE-ACCOUNT-DESIGN.md)** | リソースコンテナ階層設計（組織・フォルダ・プロジェクト）、Cloud Billing管理、IAMユーザー権限設計、組織ポリシー適用 |
| **[ENTERPRISE-MIGRATION.md](references/ENTERPRISE-MIGRATION.md)** | 移行パターン選択（4パターン: Lift & Shift / Improve & Move / Remove & Replace / Retain）、4ステップ移行プロセス、サーバー・データ・DB移行方法、クラウドネイティブモダナイゼーション戦略 |
| **[ENTERPRISE-SECURITY-DESIGN.md](references/ENTERPRISE-SECURITY-DESIGN.md)** | 責任共有モデル、Googleインフラセキュリティ、従来型セキュリティ対策（ファイアウォール・WAF・暗号化）、クラウド時代のセキュリティ対策（ゼロトラスト・VPC SC・SCC） |

### コンピューティング・オーケストレーション（4ファイル）

| ファイル | 内容 |
|---------|------|
| **[COMPUTE-SELECTION.md](references/COMPUTE-SELECTION.md)** | GCE/GKE/GAE/Cloud Run/Cloud Functionsの横断比較（サービスモデル・管理範囲・ライフサイクル）、ワークロード別選択フロー、コスト比較、マイグレーションパス |
| **[GKE-CONTAINER-ORCHESTRATION.md](references/GKE-CONTAINER-ORCHESTRATION.md)** | Docker・Kubernetes基礎、GKEクラスター設計（Node Pool・オートスケーリング）、Deployment/Service/Ingress、Workload Identity、ネットワークポリシー、セキュリティ設計 |
| **[GAE-PAAS-DEVELOPMENT.md](references/GAE-PAAS-DEVELOPMENT.md)** | GAE Standard/Flexible環境比較、デプロイ・バージョン管理、トラフィック分割、セキュリティ設計、Cloud Vision API連携、サーバーレスアーキテクチャ |
| **[GCE-OPERATIONS.md](references/GCE-OPERATIONS.md)** | マシンタイプ選択（ファミリー別）、ディスク・ネットワーク設計、MIG（マネージドインスタンスグループ）、ライブマイグレーション、起動スクリプト、運用自動化 |

### 運用・分析・業界別アーキテクチャ（3ファイル）

| ファイル | 内容 |
|---------|------|
| **[MONITORING-OPERATIONS-DESIGN.md](references/MONITORING-OPERATIONS-DESIGN.md)** | SLO/SLI定義と逆算設計、Cloud Monitoring・Cloud Logging・Cloud Trace、アラート戦略、ダッシュボード設計、Stackdriver実践、Cloud Operations Suite統合 |
| **[BIGQUERY-ANALYTICS.md](references/BIGQUERY-ANALYTICS.md)** | ゲーム分析基盤構築（Aiming社事例）、ログ収集パイプライン・fluentd設定、ゲーム固有KPI設計（DAU/ARPU/リテンション）、実践的BigQuery SQL、コスト管理事例 |
| **[GAME-INFRASTRUCTURE.md](references/GAME-INFRASTRUCTURE.md)** | モバイル/オンライン/コンソールゲームバックエンド設計、スパイクトラフィック対策、常時接続型アーキテクチャ（WebSocket/gRPC）、グローバル展開、移行事例（Aiming/grasys/シリコンスタジオ） |

---

## データエンジニアリング概要

GCPのデータエンジニアリングは、データの取り込み・保存・変換・分析・ガバナンスを統合的にカバーします。

### ストレージサービス選択テーブル

| サービス | データモデル | 最適なユースケース | スケーリング |
|---------|------------|------------------|------------|
| **Cloud Storage** | オブジェクト（非構造化） | メディア、バックアップ、データレイク | 自動（無制限） |
| **Cloud SQL** | リレーショナル | OLTP、小〜中規模アプリケーション | 垂直（最大128 vCPU） |
| **Cloud Spanner** | リレーショナル（分散） | グローバルトランザクション、金融 | 水平（自動） |
| **Bigtable** | ワイドカラム | IoT、時系列、大規模分析 | 水平（ノード追加） |
| **BigQuery** | カラムナー（分析） | OLAP、データウェアハウス、BI | 自動（サーバーレス） |
| **Firestore** | ドキュメント | モバイル/Web、リアルタイム同期 | 自動 |
| **Memorystore** | Key-Value（インメモリ） | キャッシュ、セッション管理 | 垂直/水平 |
| **AlloyDB** | リレーショナル（PostgreSQL互換） | 高性能OLTP+分析ハイブリッド | 垂直+読み取りレプリカ |

### データウェアハウス設計の要点

- BigQueryはサーバーレスのカラムナーストレージで、ペタバイト規模のOLAPに最適
- **料金モデル**: オンデマンド（クエリデータ量課金）/ 定額（スロット予約）
- **テーブル設計**: ネイティブテーブル、外部テーブル、マテリアライズドビュー
- **パーティショニング**: 時間ベース（日/月/年）、整数範囲、取り込み時間
- **クラスタリング**: 最大4カラム、パーティション内のデータ再編成
- **BigQuery ML**: SQL内で機械学習モデルの作成・評価・予測が可能

### データパイプラインパターン

| パターン | 処理方式 | GCPサービス | ユースケース |
|---------|---------|------------|------------|
| **EL (Extract-Load)** | バッチ | BigQuery Data Transfer | 定期的データ取り込み |
| **ELT (Extract-Load-Transform)** | バッチ | BigQuery + dbt | 変換をDWH内で実行 |
| **ETL (Extract-Transform-Load)** | バッチ | Dataflow / Dataproc | 複雑な変換が必要 |
| **ストリーミング** | リアルタイム | Pub/Sub + Dataflow | IoT、ログ、イベント |
| **オーケストレーション** | ワークフロー | Cloud Composer (Airflow) | 複雑な依存関係管理 |

### ユーザー確認の原則（データエンジニアリング）

以下の判断が必要な場合は AskUserQuestion ツールで確認すること:

- **BigQuery料金モデル**: オンデマンド vs 定額（ワークロード特性による）
- **パイプラインツール選択**: Dataflow vs Dataproc（既存スキルセット・ワークロードによる）
- **ストレージサービス選択**: 上記テーブルの複数候補が該当する場合
- **マイグレーション方式**: オンライン vs オフライン（ダウンタイム許容度による）

---

## ネットワークエンジニアリング概要

GCPのネットワークエンジニアリングは、VPC設計・ハイブリッド接続・ロードバランシング・セキュリティ・監視・高度なネットワーキングの6領域で構成されます。

### ネットワーク設計の判断フロー

```
ネットワーク要件
    ↓
【VPC設計】
    ├─ シングルプロジェクト？ → スタンドアロンVPC
    ├─ マルチプロジェクト・中央管理？ → Shared VPC
    └─ プロジェクト間通信（分散管理）？ → VPC Peering
    ↓
【外部接続】
    ├─ 低帯域（< 300 Mbps）？ → HA VPN
    ├─ 中帯域（300 Mbps - 10 Gbps）？ → Partner Interconnect
    └─ 高帯域（10-200 Gbps）？ → Dedicated Interconnect
    ↓
【ロードバランシング】
    ├─ グローバルHTTP(S)？ → External HTTP(S) LB
    ├─ 内部L4？ → Internal TCP/UDP LB
    └─ 内部L7？ → Internal HTTP(S) LB
    ↓
【監視】
    ├─ フロー分析？ → VPC Flow Logs
    ├─ セキュリティ監視？ → Firewall Rules Logging + Cleanup Rule
    └─ 深層パケット解析？ → Packet Mirroring（一時的使用）
```

### 主要サービス一覧

| カテゴリ | サービス | 用途 |
|---------|---------|------|
| **VPC** | VPC Network | グローバルプライベートネットワーク |
| | Shared VPC | マルチプロジェクト集中管理 |
| | VPC Peering | VPC間接続（分散管理） |
| **接続** | Cloud Interconnect | 専用線接続（Dedicated/Partner） |
| | Cloud VPN | IPsec VPNトンネル（HA/Classic） |
| | Cloud Router | BGP動的ルーティング |
| | Cloud NAT | プライベートインスタンスの外部通信 |
| **LB/CDN** | HTTP(S) LB | グローバルL7ロードバランシング |
| | TCP/UDP LB | L4ロードバランシング |
| | Cloud CDN | コンテンツ配信・キャッシュ |
| **セキュリティ** | Cloud Armor | DDoS/WAF防御 |
| | VPC Service Controls | サービス境界・データ流出防止 |
| **監視** | VPC Flow Logs | ネットワークトラフィック分析 |
| | Packet Mirroring | 完全パケットキャプチャ |
| **高度** | Traffic Director | サービスメッシュ管理プレーン |
| | Service Directory | サービスレジストリ |
| | Network Connectivity Center | Hub and Spoke ネットワーク |

詳細な実装ガイドは `references/` ディレクトリの各ファイルを参照してください。

---

## エンタープライズアカウント設計概要

GCPリソースは**組織→フォルダ→プロジェクト**の3層階層で管理します。適切な階層設計がIAMポリシー継承とコスト管理の基盤となります。

### 組織階層設計の判断テーブル

| 要素 | 推奨設計 | 詳細 |
|------|---------|------|
| **組織** | 1企業1組織 | Cloud Identity / Google Workspace ドメインに紐付く |
| **フォルダ** | 部門/環境別 | 例: prod/staging/dev、または BU別 + 環境別 |
| **プロジェクト** | サービス/チーム単位 | リソース分離・課金境界・IAMスコープの最小単位 |
| **Billing** | フォルダ単位で予算アラート | 部門別コスト管理に対応 |

詳細な実装ガイドは **[ENTERPRISE-ACCOUNT-DESIGN.md](references/ENTERPRISE-ACCOUNT-DESIGN.md)** を参照してください。

---

## コンピューティング選択フロー

GCPのコンピューティングはワークロード特性と運用要件で選択します。

### ワークロード別選択テーブル

| ワークロード特性 | 推奨サービス | 理由 |
|---------------|------------|------|
| ステートレスHTTP、可変トラフィック | **Cloud Run** | ゼロスケール・最小管理オーバーヘッド |
| イベント駆動、短時間（<9分） | **Cloud Functions** | HTTPトリガー・Pub/Sub不要な軽量処理 |
| マイクロサービス、複雑オーケストレーション | **GKE** | Kubernetes・マルチテナント・ステートフル |
| Webアプリ、PaaS優先、スケーリング自動 | **App Engine** | インフラ管理不要・オートスケール |
| フル制御、カスタムOS、レガシー移行 | **Compute Engine** | IaaS・最大柔軟性 |

詳細な選択フローは **[COMPUTE-SELECTION.md](references/COMPUTE-SELECTION.md)** を参照してください。

---

## GKEコンテナオーケストレーション概要

GKEはGoogle Borgの知見を活かしたマネージドKubernetesサービスです。

### Kubernetes主要リソース

| リソース | 役割 | 典型的な設定 |
|---------|------|------------|
| **Pod** | コンテナの最小実行単位 | リソースリクエスト/リミット設定 |
| **Deployment** | Podのレプリカ管理・ローリングアップデート | replicas: 3、RollingUpdate戦略 |
| **Service** | Pod群への安定したエンドポイント提供 | ClusterIP / NodePort / LoadBalancer |
| **Ingress** | L7ルーティング・TLS終端 | HTTPS LB + Cloud Armor統合 |
| **HPA** | CPU/メモリ基準の自動スケーリング | min: 2、max: 10、CPU 70% |

詳細な実装ガイドは **[GKE-CONTAINER-ORCHESTRATION.md](references/GKE-CONTAINER-ORCHESTRATION.md)** を参照してください。

---

## 監視・運用設計概要

GCPの監視設計は「インフラメトリクス優先」ではなく「SLOから逆算する」アプローチが重要です。

### SLO/SLI設計の要約テーブル

| ステップ | 内容 | 例 |
|---------|------|-----|
| **SLO定義** | ユーザー視点の可用性・レイテンシ目標 | 可用性99.9%、p99レイテンシ < 500ms |
| **SLI特定** | SLO計測に使うメトリクス | HTTP 2xx/5xx比率、request_latencies |
| **エラーバジェット** | 許容できる障害量（1-SLO） | 月43.8分のダウンタイム |
| **アラート設計** | エラーバジェット消費速度で判断 | 1時間でバジェット2%消費 → 緊急 |
| **ダッシュボード** | SLO達成率・バジェット残量を可視化 | Cloud Monitoringカスタムダッシュ |

詳細な実装ガイドは **[MONITORING-OPERATIONS-DESIGN.md](references/MONITORING-OPERATIONS-DESIGN.md)** を参照してください。

---

## 移行戦略概要

オンプレミスからGCPへの移行は4パターンから選択し、4ステップで実施します。

### 移行パターン選択フロー

```
移行対象の特性
    ↓
【変更コスト判断】
    ├─ 変更最小・早期移行優先？     → Lift & Shift（リホスト）
    ├─ 部分最適化・クラウド機能活用？ → Improve & Move（リプラットフォーム）
    ├─ 再設計・クラウドネイティブ化？ → Remove & Replace（リファクタリング）
    └─ 移行不要・オンプレ継続？      → Retain（現状維持）
```

詳細な移行設計は **[ENTERPRISE-MIGRATION.md](references/ENTERPRISE-MIGRATION.md)** を参照してください。

---

## まとめ

Google Cloud は、**サーバーレスデプロイメント（Cloud Run）**、**包括的なセキュリティサービス**、**データエンジニアリング基盤**、**ネットワークエンジニアリング**、**Memorystore（インメモリキャッシング）**、**エンタープライズアーキテクチャ**、**コンピューティング選択**、**GKEオーケストレーション**、**監視・運用設計**、**BigQuery分析** を組み合わせることで、スケーラブルかつセキュアなデータドリブンアプリケーションを構築できます。

**Cloud Run デプロイの要点:**
1. サービス選択テーブルで適切なGCPサービスを判断
2. gcloud CLI習熟（デプロイ、スケーリング、トラフィック分割）
3. 環境別設定（開発・ステージング・本番で最適化）
4. セキュリティ（IAM認証、Secret Manager、VPC）
5. コスト最適化（CPU-on-request、高concurrency、適切なリソース割り当て）

**GCP セキュリティの要点:**
1. 6つの柱（運用・ネットワーク・データ・ID・物理・脅威）を理解
2. サービスマップで要件に応じた適切なサービスを選択
3. Zero Trust / BeyondCorp の導入でVPN依存を脱却
4. DevSecOps で CI/CD パイプラインにセキュリティを組み込む
5. Anthos でマルチクラウド環境の統一ポリシー管理
6. インシデント対応計画の事前策定とフォレンジック体制
7. 詳細な実装は各リファレンスファイルを参照

**データエンジニアリングの要点:**
1. ストレージ選択テーブルでユースケースに合ったサービスを選択
2. BigQueryのパーティショニング・クラスタリングでコストとパフォーマンスを最適化
3. パイプラインパターン（EL/ELT/ETL/ストリーミング）を要件に応じて選択
4. Dataplex Catalogでメタデータ管理・データガバナンスを実現

**ネットワークエンジニアリングの要点:**
1. VPC設計（Shared VPC vs Peering）はプロジェクト管理モデルに応じて選択
2. ハイブリッド接続は帯域要件でVPN / Partner Interconnect / Dedicated Interconnectを選択
3. ロードバランサーはトラフィックタイプ（L4/L7、External/Internal）で選択
4. VPC Flow LogsとFirewall Logsで日常監視、Packet Mirroringは調査時のみ
5. Traffic Director/Service Meshでマイクロサービス間通信を制御

**Memorystoreキャッシングの要点:**
1. エンジン選択: 複雑なデータ構造・永続化 → Redis、シンプルKVキャッシュ → Memcached
2. キャッシュパターン: 読取ヘビー → Cache-Aside + TTL、書込ヘビー → Write-Behind/Write-Through
3. ティア選択: 本番 → Standard（SLA 99.9%、自動フェイルオーバー）、開発 → Basic
4. パフォーマンス: memtier_benchmarkでベースライン測定、パイプライニングで最適化
5. 監視: `redis.googleapis.com` メトリクスでSLOベースアラート設定

詳細な実装ガイドは `references/` ディレクトリの各ファイルを参照してください。
