# Anthos マルチクラウドセキュリティ

Anthosは、GCP、AWS、Azure、オンプレミス環境にわたるKubernetesクラスタの統一運用プラットフォーム。Policy as Code、Service Mesh、中央集約型クラスタ管理により、ハイブリッド・マルチクラウド環境でのセキュリティとコンプライアンスの一貫性を実現する。

---

## Anthosアーキテクチャ概要

| コンポーネント | 役割 | 主な機能 |
|--------------|------|---------|
| **Anthos Config Management (ACM)** | GitOps駆動の設定管理 | Kubernetes設定・RBAC・ネットワークポリシーの自動同期 |
| **Anthos Service Mesh (ASM)** | Istioベースのサービスメッシュ | mTLS、トラフィック制御、テレメトリ、ゼロトラスト |
| **Multi-cluster Management** | 中央集約型コンソール・API | クラスタの健全性・ステータス・コンプライアンスの可視化 |
| **Connect Agent** | 非GCPクラスタ登録 | AWS/Azure/オンプレミスクラスタをAnthos制御プレーンに接続 |

### Anthos vs 他マルチクラウドツール

| 機能 | Anthos (Google Cloud) | EKS Anywhere (AWS) | Azure Arc |
|------|----------------------|-------------------|-----------|
| **Policy as Code** | ACM + Gatekeeper（全環境標準） | OPA Gatekeeper（手動統合） | Azure Policy拡張 |
| **Service Mesh** | ASM（Istio統合）標準搭載 | 個別Istio/App Mesh構築 | 初期段階 |
| **マルチクラスタセキュリティ** | IAM・ネットワーク・ワークロードポリシーをGitOpsで統一 | サードパーティ統合必須 | Arc Kubernetes（移植性制限） |
| **GKE統合** | シームレスなライフサイクル管理 | EKS限定 | AKS限定 |
| **コンプライアンス・ドリフト検出** | Cloud SCC・Config Sync・ポリシーライブラリ統合 | 手動構築 | Azure Defender（非Azure環境制限） |
| **クロスクラウド移植性** | GCP/AWS/Azure間で統一API | AWS特化 | Azure中心 |

---

## Anthos Config Management (ACM)

### 概要

ACMはGitOpsベースでKubernetes設定を中央管理し、全登録クラスタに自動同期。ドリフト防止と変更の監査証跡を実現。

### 主要機能

| 機能 | 説明 |
|------|------|
| **Config Sync** | Git Repoを監視し、クラスタの実際の状態と宣言された設定を調整。ドリフトは自動修正 |
| **Hierarchy Controller** | 親子ネームスペース階層でポリシー・リソースを自動伝播。マルチテナント対応 |
| **Multi-repo対応** | 単一共有Repoまたは環境別（staging/production）Repo構成 |

### 実装手順

```bash
# 1. ACM有効化
gcloud beta container hub config-management apply \
  --membership=prod-cluster \
  --config=acm-config.yaml

# 2. Constraint Template適用
kubectl apply -f template-no-privileged-containers.yaml

# 3. Constraint適用
kubectl apply -f constraint-no-privileged-containers.yaml

# 4. CI検証（自動化）
# Gitコミット前に、テストクラスタが同期リソースを拒否しないことを検証
```

### ベストプラクティス

| 項目 | 推奨事項 |
|------|---------|
| **Repo構造** | グローバル制約（全クラスタ）と環境固有設定をフォルダ/Repo分離 |
| **ステージング** | feature branchでポリシーを非本番環境に導入 → CI検証 → PR承認 |
| **CI統合** | OPAテストフレームワーク・`conftest`でRegoポリシーをマージ前にテスト |

---

## Gatekeeper（OPAベースのPolicy as Code）

### 概要

GatekeeperはKubernetes admission controlをOPAで拡張。ConstraintTemplate（Rego）でポリシーロジックを定義し、リソース作成前に検証。

### 主要機能

| 機能 | 説明 |
|------|------|
| **ConstraintTemplate** | Regoベースの検証ロジック定義（特権コンテナ禁止、TLS必須、ラベル強制等） |
| **Admission Webhook** | リソース永続化前に制約をチェック。違反は拒否（検出ツールより強力） |

### Regoポリシー例：rootコンテナブロック

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredrunasnonroot
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredRunAsNonRoot
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredrunasnonroot
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.runAsNonRoot
          msg := "Containers must set securityContext.runAsNonRoot to true"
        }
```

```yaml
# Constraint適用
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredRunAsNonRoot
metadata:
  name: no-root-containers
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
```

### Regoポリシー：Whitelist付きroot禁止

```rego
# 特権コンテナ禁止（Whitelist対応）
violation[{
  "msg": sprintf("Privileged container usage is not allowed in namespace: %v", [input.review.object.metadata.namespace]),
}] {
  input.review.object.spec.securityContext.runAsNonRoot == false
  not input.review.object.metadata.namespace == whitelist_ns[_]
}

whitelist_ns := ["kube-system", "monitoring"]
```

---

## GKEクラスタのマルチクラウド管理

### 概要

Anthosは、GKE on AWS・GKE on Azureにより、外部クラウドにGKE相当の運用体験を提供。VPCネットワーキング・IAM・ストレージ設定はクラウド固有機能と統合。

### GCP vs 外部クラウドの差異

| 項目 | GKE on GCP | GKE on AWS/Azure |
|------|-----------|------------------|
| **Auto-upgrade** | ✅ 標準搭載 | ⚠️ 手動管理 |
| **Autopilot** | ✅ 利用可能 | ❌ 未対応 |
| **バージョン追従** | 最新リリース即対応 | 数バージョン遅延 |
| **Node Auto-scaling** | Cluster Autoscaler緊密統合 | EC2 Auto Scaling/VMSS依存 |
| **ロードバランサ** | Cloud Load Balancing | AWS ALB/Azure Load Balancer |
| **可観測性** | Cloud Operations Suite統合 | OpenTelemetry/Prometheus手動構築 |
| **IAM** | Cloud IAM標準 | OIDC/Workload Identity Federation連携 |

### セットアップ手順

```bash
# 1. Service Account作成（GCP側）
# 必要なロール：GKE Hub Admin、GKE Multi-Cloud Admin、Service Account Token Creator

# 2. GKE on AWSクラスタ作成
gcloud container aws clusters create aws-test-cluster \
  --region=us-west-2 \
  --cluster-version=1.27 \
  --vpc-id=vpc-123456 \
  --subnet-ids=subnet-a,subnet-b \
  --iam-instance-profile=gke-node-role

# 3. Connect Agent登録
connect-register \
  --project=acme-hybrid \
  --location=us-central1 \
  --gke-uri=https://CLUSTER_ENDPOINT \
  --service-account-key-file=connect-agent-key.json

# 4. GKE Hubに登録
gcloud container hub memberships register aws-test-cluster \
  --gke-uri=... \
  --enable-workload-identity
```

### ベストプラクティス

| 項目 | 推奨事項 |
|------|---------|
| **ネットワークトポロジ** | VPN/Interconnectでクラスタ間レイテンシ最小化。CIDR重複回避 |
| **Identity統合** | AWS IRSA/Azure Workload Identity Federationでトークン短命化 + CI自動ローテーション |
| **Hybrid Egress** | NAT Gateway/Egress Proxyで暗号化・露出削減 |

---

## Service Meshセキュリティ（ASM）

### 概要

ASMはIstioベースで、mTLS・トラフィック制御・テレメトリを提供。ゼロトラスト原則をマイクロサービス間通信に適用。

### 主要機能

| 機能 | 説明 |
|------|------|
| **mTLS** | デフォルトでワークロード間通信を暗号化。Istio組み込みCAで証明書自動ローテーション |
| **RBAC & Auth** | サービス間通信をnamespace・service account・リクエスト属性で制限 |
| **Cross-cluster Routing** | クラスタ間サービスディスカバリ・グローバルロードバランシング |
| **Observability** | Prometheus・Grafana・Cloud Operations Suiteでリクエストレベルのメトリクス・トレース |

### トラフィック制御例：A/Bテスト

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: payment-service
spec:
  hosts:
    - payment.example.com
  http:
    - route:
        - destination:
            host: payment-v1
          weight: 90
        - destination:
            host: payment-v2
          weight: 10
```

### ハイブリッド接続戦略

| アプローチ | 説明 |
|---------|------|
| **VPN/Interconnect** | オンプレミス⇔GCP間の低レイテンシ接続。Dedicated/Partner Interconnect推奨 |
| **Anthos Attached Clusters** | Connect AgentでオンプレミスクラスタをAnthos制御プレーンに登録 |
| **Service Discovery** | ASMがattached/native cluster間でサービスレジストリを連携 |

---

## クロスクラウドIDとガバナンス

### Identity統合

| 方式 | 概要 |
|------|------|
| **Workload Identity Federation** | AWS/AzureワークロードがGCP IAMを一時利用。静的キー不要 |
| **SSO & Federation** | 単一IdP（Okta、Active Directory）をSAML/OIDCでGCP/AWS/Azureに連携 |
| **Gatekeeper IAM Policy** | cluster-admin特権制限・未認証Service Account拒否を全クラスタ統一 |

### データガバナンス

| 項目 | 実装 |
|------|------|
| **暗号化** | CMEK（Customer-Managed Encryption Keys）で保存時・転送時暗号化 |
| **ラベル・タグ** | `env=prod`、`compliance=HIPAA`等でポリシーチェックをトリガー |
| **監査ログ集約** | Cloud Audit Logs（GCP）・CloudTrail（AWS）・Azure MonitorをSIEMに統合 |

### GCP Policy Intelligence

| ツール | 機能 |
|--------|------|
| **Policy Analyzer** | 全プロジェクトのIAM権限を一覧化。過剰アクセス検出 |
| **Policy Troubleshooter** | 権限チェックシミュレーション |
| **Access Approval Logs** | 機密リソースへのアクセス承認履歴 |

---

## 課題と軽減策

### マルチクラウド共通課題

| 課題 | 説明 | 軽減策 |
|------|------|--------|
| **IAM不整合** | クラウドごとに異なるIAMモデル（GCP IAM、AWS IAM、Azure AD）でロール重複・攻撃面拡大 | SAML/OIDC連携で中央IdP統合。Workload Identity Federation活用 |
| **ネットワークポリシー不一致** | Security Groups・Firewall・Ingressルールが異なり、一貫性確保困難 | ACM + Gatekeeperで宣言的ポリシー統一。CI検証 |
| **高複雑性** | GKE・ACM・Gatekeeper・ASMの誤設定でポリシー競合・パフォーマンス悪化 | モジュール設計。ステージング環境で検証 |

### 自動化・スキャンツール

| ツール | 用途 |
|--------|------|
| `kubeval`・`conftest`・`OPA Gatekeeper` | Kubernetes設定・カスタムポリシーのクラスタ横断検証 |
| **Policy Controller** | 事前定義ConstraintTemplateでリアルタイム監査 |
| `terratest`・`checkov` | IaC（Terraform/CloudFormation）のコンプライアンス検証 |
| **GitOps CI Pipeline** | Cloud Build/GitHub ActionsでPR時に自動ポリシーチェック |

### 実運用考慮事項

| トピック | ベストプラクティス |
|---------|-------------------|
| **データレジデンシー** | 規制要件でクラスタをリージョン内に配置。Anthosはポリシーコンプライアンス維持 |
| **レイテンシ** | クロスクラウドService Meshでレイテンシ増大。地理的ルーティング推奨 |
| **コスト管理** | Egress料金・Interconnect料金・可観測性ツールライセンスを設計段階で考慮 |

---

## コンプライアンスチェックリスト

- [ ] クラウド横断でSSO統合（SAML/OIDC）
- [ ] IAMポリシー継承・最小権限ロール設定
- [ ] Gatekeeperで保存時・転送時暗号化を強制
- [ ] ACM経由で一貫したRBACポリシー適用
- [ ] 監査ログをChronicle/SCC/SIEMに集約
- [ ] Git管理ポリシー変更の定期的なドリフト検証

---

## gcloud CLIコマンド集

```bash
# Anthos Multi-cloud操作
gcloud container aws clusters create <cluster-name> \
  --region=<aws-region> \
  --cluster-version=<version> \
  --vpc-id=<vpc-id> \
  --subnet-ids=<subnet-list>

# Connect Agent登録
connect-register \
  --project=<project-id> \
  --location=<location> \
  --gke-uri=<cluster-endpoint> \
  --service-account-key-file=<key-file>

# ACM有効化
gcloud beta container hub config-management apply \
  --membership=<cluster-name> \
  --config=<acm-config-file>

# GKE Hub登録
gcloud container hub memberships register <cluster-name> \
  --gke-uri=<cluster-endpoint> \
  --enable-workload-identity

# Policy Intelligence（IAM分析）
gcloud asset analyze-iam-policy \
  --organization=<org-id> \
  --full-resource-name=//cloudresourcemanager.googleapis.com/projects/<project-id>

# Constraint違反確認
kubectl get constraintviolations
```

---

## まとめ

Anthosは、ハイブリッド・マルチクラウド環境のセキュリティとガバナンスを統一する制御プレーン。ACM（GitOps）、Gatekeeper（Policy as Code）、ASM（Service Mesh）により、クラウド間の差異を抽象化し、一貫したポリシー適用・監査を実現する。
