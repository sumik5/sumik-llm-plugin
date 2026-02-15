# GCPワークロードセキュリティ実践ガイド

GCPにおけるワークロードセキュリティの実践的なベストプラクティスとアーキテクチャパターン。Compute Engine、コンテナ、GKEのセキュリティ強化を網羅。

---

## Compute Engineセキュリティ

### Shielded VM

**概要**: ルートキット・ブートキット攻撃からVMを保護する3層防御機構。

| 機能 | 役割 | 実装方式 |
|-----|------|---------|
| **Secure Boot** | デジタル署名検証で不正ブートコンポーネントをブロック | UEFI 2.3.1ファームウェアで証明書管理 |
| **vTPM (Virtual Trusted Platform Module)** | 認証資産（鍵・証明書）を保護 | BoringSSL（FIPS 140-2準拠）、TCG 2.0仕様 |
| **Integrity Monitoring** | ブート整合性の検証（ベースラインと比較） | PCR（Platform Configuration Registers）利用 |

**Secure Bootの動作フロー**:
1. UEFI firmware が各ブートコンポーネントの署名を検証
2. 署名失敗時は起動中断、シリアルコンソールに `UEFI: Failed to load image Status: Security Violation` 記録
3. Google Certificate Authority Serviceで署名された信頼済みソフトウェアのみ起動

**Measured Bootの仕組み**:
- **Early Boot**: UEFI firmware → bootloader（PCRで測定）
- **Late Boot**: bootloader → OS kernel（PCRで測定）
- 両方の測定値が整合性ポリシーベースラインと一致しない場合、整合性検証失敗として検出

**IAM権限**:
```bash
# Shielded VM設定変更
compute.instances.updateShieldedInstanceConfig

# 整合性ポリシーベースライン更新
compute.instances.setShieldedInstanceIntegrityPolicy

# vTPM情報取得
compute.instances.getShieldedInstanceIdentity
```

**組織ポリシー制約**:
```bash
# Shielded VM必須化
gcloud resource-manager org-policies set-policy \
  --organization=ORG_ID \
  constraints/compute.requireShieldedVm=true
```

---

### Confidential VM

**概要**: メモリ暗号化でデータ処理中も保護（AMD SEV利用）。

| 特徴 | 詳細 |
|-----|------|
| **暗号化対象** | VM全メモリ（処理中データ含む） |
| **鍵管理** | AMD Secure Processor（SP）でVM起動時に生成、SOC内で保護 |
| **attestation** | vTPM使用、起動時にlaunch attestation reportイベント生成 |
| **性能影響** | ほぼゼロ～6%（ほとんどのアプリケーション） |

**適用対象**:
- Compute Engine VM
- GKEノード（Confidential GKE nodes）
- Dataproc Confidential Computeクラスター

**3つの暗号化レイヤー**:
1. **Encryption at rest**: ストレージデータ保護
2. **Encryption in transit**: ネットワーク転送中保護
3. **Encryption in use**: メモリ処理中保護（Confidential Computing）

---

### OS Patch Management

**戦略**: パッチ適用自動化とイメージ更新の組み合わせ。

| 手法 | 概要 | 自動化レベル |
|-----|------|-------------|
| **VM Manager Patch Management** | 実行中VMへのパッチ適用 | スケジュール自動実行可能 |
| **OS Login** | SSH鍵管理をIAMに統合 | IAM権限で制御 |
| **Node Auto-Upgrade（GKE）** | ノードイメージ自動更新 | Google管理のイメージ提供 |

**OS Loginの利点**:
- SSH公開鍵をIAMで一元管理
- ユーザー単位でVM接続権限制御（`compute.osLogin`権限）
- 短命SSH証明書（有効期限付き）
- Cloud Audit Logsで接続監査

---

## イメージ管理

### カスタムイメージ

**3つの作成方法**:

| 方法 | ユースケース | 特徴 |
|-----|-------------|------|
| **手動ベイキング** | 少数イメージ管理 | 既存VMから手動でイメージ作成 |
| **自動ベイキング** | 多数イメージ管理・再現性重視 | HashiCorp Packer + Cloud Build |
| **既存イメージインポート** | オンプレミスからの移行 | Migrate for Compute Engine |

**イメージベイキングのメリット**:
- ブート時間短縮（事前インストール済み）
- 環境安定性向上（起動時の外部依存削減）
- バージョン管理容易（ロールバック可能）
- スケーリング効率化（同一バージョン保証）

---

### イメージファミリー

**概念**: 同系統イメージをグループ化、常に最新版を自動参照。

```bash
# イメージファミリーから最新イメージでVM作成
gcloud compute instances create INSTANCE_NAME \
  --image-family=my-application \
  --image-project=my-project

# イメージをファミリーに追加
gcloud compute images create my-app-v4-20230201 \
  --family=my-application \
  --source-disk=SOURCE_DISK
```

**パブリックイメージファミリー**: Google・OSSコミュニティ・サードパーティー提供、ゾーンごとに段階リリース。

**カスタムイメージファミリー**: プロジェクト内独自管理、最新イメージ自動リンク。

---

### イメージライフサイクル管理

**3つの廃止ステージ**:

| ステージ | 動作 | ユースケース |
|---------|-----|------------|
| **DEPRECATED** | 使用可能だが警告、新規リンク禁止、ファミリーから除外 | 徐々に利用停止 |
| **OBSOLETE** | 使用不可、エラー返却、既存リンクは有効 | 使用禁止だがリンク保持 |
| **DELETED** | 完全削除、すべて使用不可 | 完全撤廃 |

**廃止コマンド**:
```bash
# イメージを非推奨化（ファミリーから除外）
gcloud compute images deprecate nginx-v3-20230101 \
  --state DEPRECATED

# 自動削除スケジュール（7日後）
gcloud compute images deprecate my-app-v1 \
  --state DEPRECATED \
  --delete-in 7d

# 自動obsolete化（30日後）
gcloud compute images deprecate my-app-v1 \
  --state DEPRECATED \
  --obsolete-on 2023-12-31
```

**廃止イメージの表示**:
```bash
gcloud compute images list --show-deprecated
```

---

### イメージ共有（プロジェクト間）

**アクセス制御パターン**:

```
[Image Creation Project]
  ├─ compute.imageUser → Image User Group（他プロジェクトユーザー）
  ├─ compute.instanceAdmin → Image Creation User
  └─ compute.storageAdmin → Image Creation User

[Consuming Project]
  └─ compute.imageUser権限で共有イメージ参照
```

**IAMロール設定例**:
```bash
# イメージプロジェクトでユーザーグループに使用権限付与
gcloud projects add-iam-policy-binding IMAGE_PROJECT_ID \
  --member=group:image-users@example.com \
  --role=roles/compute.imageUser
```

---

### 暗号化

**2つの鍵管理オプション**:

| 方式 | 鍵管理 | 利用シーン |
|-----|--------|----------|
| **Google-managed encryption keys** | Google自動管理（デフォルト） | 標準的な保護 |
| **Customer-managed encryption keys (CMEK)** | Cloud KMSで顧客管理 | コンプライアンス要件 |

```bash
# CMEKでイメージ作成
gcloud compute images create my-secure-image \
  --source-disk=my-disk \
  --kms-key=projects/KMS_PROJECT/locations/LOCATION/keyRings/RING/cryptoKeys/KEY
```

---

## CI/CDセキュリティ

### セキュリティスキャン統合

**パイプライン内配置**:

| フェーズ | ツール | 検出対象 |
|---------|--------|---------|
| **ソースコード段階** | SCA (Source Composition Analysis) | 依存ライブラリ脆弱性、ライセンス問題 |
| **ビルド前** | SAST (Static Application Security Testing) | コード脆弱性（SQL injection、XSS等） |
| **イメージビルド後** | Container Vulnerability Scanning | OS・パッケージ脆弱性 |
| **デプロイ前** | Binary Authorization | 信頼済み署名検証 |
| **ランタイム** | Container Threat Detection | 異常動作検出 |

---

### Cloud Buildパイプライン設計

**自動化イメージファクトリー構成**:

```
[Cloud Source Repository]
    ↓ (git tag push)
[Cloud Build Trigger]
    ↓
[Packer Image Build]
    ├─ Base image取得
    ├─ Software install
    ├─ Security hardening
    └─ Compliance check (Chef InSpec)
    ↓
[Container Analysis Scan]
    ↓ (脆弱性OK)
[Attestation署名]
    ↓
[Artifact Registryへpush]
    ↓
[Binary Authorization Policy Check]
    ↓ (署名・ポリシーOK)
[GKE Deployment]
```

**cloudbuild.yaml例**:
```yaml
steps:
  # Packer build
  - name: gcr.io/cloud-builders/packer
    args:
      - build
      - -var-file=variables.json
      - packer-template.json

  # Compliance check
  - name: chef/inspec
    args:
      - exec
      - compliance-profile
      - --target=gce://INSTANCE

  # Vulnerability scan
  - name: gcr.io/cloud-builders/gcloud
    args:
      - container
      - images
      - scan
      - $_IMAGE_NAME
```

---

### Binary Authorization

**概要**: 信頼済みコンテナイメージのみデプロイ許可する証明ベース制御。

**コンポーネント**:

| 要素 | 役割 |
|-----|------|
| **Policy** | デプロイ許可ルール定義 |
| **Attestation** | 成功ステージの署名済み証明 |
| **Attestor** | デプロイ時に証明を検証（公開鍵使用） |
| **Signer** | ビルド時に証明作成（秘密鍵使用） |

**信頼構築フロー**:
```
[Code Commit] (implicit trust)
    ↓
[Security Tools Run] → [Attestation署名] (explicit trust)
    ↓
[DEV Approval] (implicit trust)
    ↓
[QA Test Pass] → [Attestation署名] (explicit trust)
    ↓
[Staging Approval] → [Attestation署名] (explicit trust)
    ↓
[Binary Authorization Check] → [GKE Admission Controller]
    ↓ (全attestation揃う)
[Production Deploy]
```

**Policy設定例**:
```bash
# Binary Authorizationポリシー作成
gcloud container binauthz policy import policy.yaml

# Attestor作成
gcloud container binauthz attestors create qa-attestor \
  --attestation-authority-note=projects/PROJECT/notes/qa-note \
  --attestation-authority-note-project=PROJECT

# GKEクラスタでBinary Authorization有効化
gcloud container clusters update CLUSTER_NAME \
  --enable-binauthz
```

---

### SLSA (Supply Chain Levels for Software Artifacts)

**セキュリティレベル**:

| Level | 要件 | 実現方法 |
|-------|-----|---------|
| **SLSA 1** | ビルドプロセス文書化 | Cloud Buildログ保存 |
| **SLSA 2** | 署名付きprovenance | Binary Authorization attestation |
| **SLSA 3** | 監査可能ビルド環境 | Cloud Build専用worker、IAM制御 |
| **SLSA 4** | 2人レビュー・密閉環境 | 承認フロー + hermetic build |

---

### Secrets Management

**ベストプラクティス**:

| アンチパターン | 推奨手法 |
|--------------|---------|
| ❌ ハードコード（IaC/config内） | ✅ Secret Manager変数参照 |
| ❌ 環境変数平文保存 | ✅ GKE Workload Identity + Secret Manager |
| ❌ サービスアカウント鍵ファイル | ✅ Workload Identity連携 |

**Cloud BuildでSecret Manager使用**:
```yaml
availableSecrets:
  secretManager:
    - versionName: projects/PROJECT/secrets/db-password/versions/latest
      env: DB_PASSWORD

steps:
  - name: gcr.io/cloud-builders/gcloud
    entrypoint: bash
    args:
      - -c
      - |
        echo "Connecting to database..."
        # $DB_PASSWORDで参照
    secretEnv: ['DB_PASSWORD']
```

---

## GKEセキュリティ

### GKE共有責任モデル

**Googleの責任範囲**:
- インフラ（HW/FW/kernel/OS/ストレージ/ネットワーク）
- ノードOS（COS/Ubuntu）: セキュリティパッチ提供
- Kubernetes（control plane）: アップグレード・スケーリング・修復
- コントロールプレーンHA（etcd、API server、scheduler等）
- GCP統合（IAM、Cloud Logging、Cloud KMS、SCC）

**顧客の責任範囲**:
- ノード管理: 追加ソフトウェア、設定変更、アップグレード適用
- ワークロード: アプリコード、Dockerfile、イメージ、RBAC/IAM、実行コンテナ
- ノード自動アップグレード有効化の判断
- セキュリティツール適用（Container Threat Detection、サードパーティ）

---

### GKEクラスタ強化

**コアセキュリティ設定**:

| 機能 | 効果 | gcloud設定 |
|-----|------|-----------|
| **Private Cluster** | ノードに内部IPのみ割当 | `--enable-private-nodes` |
| **Authorized Networks** | control plane API接続元制限 | `--enable-master-authorized-networks` |
| **Shielded GKE Nodes** | ノードにShielded VM適用 | `--shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring` |
| **Workload Identity** | Pod→GCPサービス認証（鍵不要） | `--workload-pool=PROJECT.svc.id.goog` |
| **Binary Authorization** | 署名済みイメージのみデプロイ | `--enable-binauthz` |
| **Node Auto-Upgrade** | ノードOS自動更新 | `--enable-autoupgrade` |
| **Network Policy** | Pod間通信制御 | `--enable-network-policy` |

**クラスタ作成例**:
```bash
gcloud container clusters create secure-cluster \
  --zone=us-central1-a \
  --enable-private-nodes \
  --enable-private-endpoint \
  --master-ipv4-cidr=172.16.0.0/28 \
  --enable-ip-alias \
  --enable-master-authorized-networks \
  --master-authorized-networks=203.0.113.0/24 \
  --enable-shielded-nodes \
  --shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --workload-pool=my-project.svc.id.goog \
  --enable-binauthz \
  --enable-autoupgrade \
  --enable-autorepair \
  --enable-network-policy \
  --addons=HttpLoadBalancing,HorizontalPodAutoscaling \
  --maintenance-window-start=2023-01-01T00:00:00Z \
  --maintenance-window-duration=4h
```

---

### Workload Identity（GKE）

**概要**: Kubernetesサービスアカウント（KSA）とIAMサービスアカウントをバインドし、Pod認証を鍵不要で実現。

**従来方式（アンチパターン）**:
```
IAMサービスアカウント作成
  ↓
JSON鍵ダウンロード
  ↓
K8s Secretとして登録
  ↓
Pod内でGOOGLE_APPLICATION_CREDENTIALS環境変数設定
```

**Workload Identity方式**:
```bash
# 1. GKEでWorkload Identity有効化（クラスタ作成時）
gcloud container clusters create CLUSTER \
  --workload-pool=PROJECT.svc.id.goog

# 2. K8s Service Account作成
kubectl create serviceaccount KSA_NAME -n NAMESPACE

# 3. IAMサービスアカウント作成
gcloud iam service-accounts create GSA_NAME

# 4. KSA→GSAバインディング
gcloud iam service-accounts add-iam-policy-binding \
  GSA_NAME@PROJECT.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:PROJECT.svc.id.goog[NAMESPACE/KSA_NAME]"

# 5. KSAにannotation追加
kubectl annotate serviceaccount KSA_NAME \
  iam.gke.io/gcp-service-account=GSA_NAME@PROJECT.iam.gserviceaccount.com \
  -n NAMESPACE
```

**Pod manifest**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: KSA_NAME  # Workload Identity連携
  containers:
  - name: app
    image: gcr.io/my-project/my-app:latest
    # GOOGLE_APPLICATION_CREDENTIALS不要！
```

---

### GKE RBAC（Role-Based Access Control）

**2つのアクセス制御**:

| 機能 | スコープ | 用途 |
|-----|---------|-----|
| **Cloud IAM** | GCPリソース（クラスタ、ノード） | プロジェクト/フォルダレベル権限 |
| **Kubernetes RBAC** | K8sオブジェクト（Pod、Deployment） | namespace/clusterレベル権限 |

**両方の権限が必要**: GKE操作にはIAMとRBAC両方の適切な権限が必要。

**K8s RBACオブジェクト**:

| リソース | スコープ |
|---------|---------|
| **Role** | namespace内権限定義 |
| **ClusterRole** | クラスタ全体権限定義 |
| **RoleBinding** | Role→ユーザー/グループ紐付け |
| **ClusterRoleBinding** | ClusterRole→ユーザー/グループ紐付け |

**最小権限Roleの例**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: production
subjects:
- kind: User
  name: developer@example.com
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

---

### Network Policy

**概要**: Pod間通信をIPアドレス・ポート（L3/L4）で制御するファイアウォール。

**使用シーン**:
- マルチティアアプリケーション（frontend→backend分離）
- マルチテナンシー（namespace間通信遮断）
- 侵害拡大防止（defense in depth）

**GKE有効化**:
```bash
# 既存クラスタで有効化
gcloud container clusters update CLUSTER_NAME \
  --enable-network-policy
```

**Network Policy例（Ingress制御）**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      role: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend  # frontendからのみ許可
    ports:
    - protocol: TCP
      port: 8080
```

**デフォルト拒否ポリシー**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}  # 全Podに適用
  policyTypes:
  - Ingress
  - Egress
```

---

### GKE Private Cluster

**構成要素**:

| 要素 | 設定 |
|-----|------|
| **Worker nodes** | 内部IPのみ（外部IP無し） |
| **Control plane** | 内部IP + 公開IP（オプションで公開IP無効化） |
| **内部LB** | private endpointアクセス用 |

**メリット**:
- ノードがインターネット露出なし
- 不正アクセスリスク低減
- Authorized Networks併用でmaster API制御

**作成**:
```bash
gcloud container clusters create private-cluster \
  --enable-private-nodes \
  --enable-private-endpoint \
  --master-ipv4-cidr=172.16.0.0/28 \
  --enable-ip-alias
```

---

### Pod Security Standards

**3つのセキュリティレベル**:

| Level | 説明 | ユースケース |
|-------|-----|-------------|
| **Privileged** | 制限なし | 信頼されたワークロード |
| **Baseline** | 既知の特権昇格防止 | 一般的なアプリケーション |
| **Restricted** | 最小権限・セキュリティ強化 | セキュリティ重視環境 |

**PodSecurityPolicy代替**（Kubernetes 1.25+）:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

---

### GKE Autopilot

**セキュリティメリット**:

| 機能 | Autopilot | Standard GKE |
|-----|-----------|-------------|
| **Shielded GKE Nodes** | 常時有効 | 手動設定 |
| **Workload Identity** | デフォルト有効 | 手動設定 |
| **Binary Authorization** | 設定可能 | 設定可能 |
| **Pod Security Standards** | Baseline強制 | 手動設定 |
| **Node管理** | Google完全管理 | 顧客責任 |

**Autopilot作成**:
```bash
gcloud container clusters create-auto autopilot-cluster \
  --region=us-central1 \
  --enable-binauthz
```

---

### Container Threat Detection

**概要**: GKE実行中コンテナの異常動作をリアルタイム検出（Security Command Center統合）。

**検出脅威例**:
- コンテナエスケープ試行
- リバースシェル実行
- 悪意あるバイナリ実行
- ライブラリインジェクション

**有効化**:
```bash
# Security Command Center PremiumでContainer Threat Detection有効化
gcloud services enable containerthreatdetection.googleapis.com
```

---

### Container Vulnerability Scanning

**2つのスキャンモード**:

| モード | タイミング | 対象 |
|-------|----------|-----|
| **Automated Scanning** | Artifact/Container Registryへpush時 | 全イメージ自動 |
| **On-Demand Scanning** | gcloud CLI実行時 | ローカル/レジストリ任意イメージ |

**自動スキャン動作**:
1. イメージpush時、Container Analysisがパッケージ情報抽出
2. digest基準でスキャン（tag変更のみでは再スキャンなし）
3. 脆弱性DB更新時、過去30日以内のイメージ metadata更新
4. 30日以降のイメージはアーカイブ（再push/pullで再スキャン）

**重大度レベル**:
- Critical / High / Medium / Low / Minimal

**2つの severity**:
1. **Effective severity**: Linux distributionが指定
2. **CVSS score**: CVSS 2.0 / 3.1スコア

**スキャン結果確認**:
```bash
# イメージ脆弱性一覧
gcloud container images describe \
  gcr.io/PROJECT/IMAGE:TAG \
  --show-package-vulnerability

# Criticalのみフィルタ
gcloud container images describe \
  gcr.io/PROJECT/IMAGE:TAG \
  --show-package-vulnerability \
  --format="table(vulnerability.effectiveSeverity)" \
  | grep CRITICAL
```

---

### GKE Certificate Authority

**3つのCA**:

| CA | 用途 | 管理 |
|----|------|------|
| **Cluster Root CA** | API server↔kubelet相互認証 | Googleマネージド（クラスタごと独立） |
| **etcd CA** | etcd間通信 | クラスタごと独立 |
| **certificates.k8s.io API** | ワークロード用証明書 | ユーザー要求で署名 |

**証明書ローテーション**:
```bash
# 証明書手動ローテーション（5年有効期限）
gcloud container clusters update CLUSTER_NAME \
  --start-credential-rotation

# ローテーション完了
gcloud container clusters update CLUSTER_NAME \
  --complete-credential-rotation
```

---

### Service Mesh（Istio/Anthos Service Mesh）

**セキュリティ機能**:

| 機能 | 効果 |
|-----|------|
| **mTLS（相互TLS）** | Pod間通信自動暗号化 |
| **認可ポリシー** | L7レベルアクセス制御 |
| **証明書管理** | 証明書自動発行・ローテーション |

**Anthos Service Mesh（Google推奨）**:
```bash
# Anthos Service Mesh有効化
gcloud container clusters update CLUSTER_NAME \
  --update-addons=ConfigManagement \
  --enable-stackdriver-kubernetes
```

**mTLS自動有効化**:
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT  # 全通信mTLS必須
```

---

## コンテナセキュリティベストプラクティス

### ビルドフェーズ

**ソースイメージ制御**:
- ✅ 信頼できるパブリッシャーのベースイメージのみ使用
- ✅ イメージのバージョン・ビルド情報を文書化
- ✅ デジタル署名・チェックサム検証
- ✅ 最小構成（必要なソフトウェアのみ）
- ❌ 未検証・信頼できないソースコード組み込み禁止

**Google推奨ベースイメージ**:
- `gcr.io/distroless/*` (最小構成、shellなし)
- `gcr.io/google.com/cloudsdktool/cloud-sdk` (gcloud CLI)

---

### スキャン・検証

**脆弱性スキャン**:
- 定期的な自動スキャン統合
- 静的スキャン（パッケージ整合性）+ 動的スキャン（バイナリ解析）
- オープンソース（Clair）or 商用ツール

**シークレット管理**:
- ❌ イメージ内にシークレット埋め込み禁止
- ✅ Secret Manager / GKE Secret使用
- ✅ ランタイムで動的取得

---

### デプロイフェーズ

**レジストリセキュリティ**:
- 認証・認可必須
- 暗号化通信（TLS）
- データ保護機能評価
- バージョン管理ツール統合（change management、audit）

**Binary Authorization**:
- 署名済みイメージのみデプロイ許可
- 脆弱性許容リストポリシー

---

### ランタイムフェーズ

**認証・アカウント管理**:
- 組織アカウント管理システムと統合
- RBAC + 最小権限原則
- 定期監査

**攻撃面削減**:
- root権限・kernel capabilitiesは監視下でのみ有効化
- クラスタ管理権限は信頼された管理者のみ
- 最小権限アクセス

**パッチ管理**:
- アップデートフィード購読
- バージョン管理でaudit trail保持
- タイムスタンプ・詳細・既知問題を文書化

---

## CIS GKEベンチマーク主要項目

| カテゴリ | 推奨事項 |
|---------|---------|
| **アップグレード** | タイムリーなGKEインフラ更新 |
| **ネットワーク** | control plane・ノードへのアクセス制限 |
| **RBAC** | Google Groups for RBAC使用 |
| **ノードイメージ** | containerd runtime + hardened image |
| **認証** | Basic Authentication無効化、Client Certificate無効化 |
| **Dashboard** | Kubernetes web UI無効化 |
| **ABAC** | 無効化（RBAC使用） |
| **Admission Controller** | DenyServiceExternalIPs有効維持 |
| **Logging** | Cloud Logging有効 |
| **Metadata Server** | legacy metadata API無効、GKE metadata server有効 |

---

## 参考コマンド集

### Shielded VM
```bash
# Shielded VM作成
gcloud compute instances create INSTANCE \
  --shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring

# 整合性ポリシーベースライン更新
gcloud compute instances update-shielded-instance-config INSTANCE \
  --shielded-learn-integrity-policy
```

### Confidential VM
```bash
# Confidential VM作成
gcloud compute instances create INSTANCE \
  --confidential-compute \
  --maintenance-policy=TERMINATE
```

### イメージ管理
```bash
# カスタムイメージ作成
gcloud compute images create IMAGE_NAME \
  --source-disk=SOURCE_DISK \
  --source-disk-zone=ZONE \
  --family=IMAGE_FAMILY

# イメージ共有
gcloud compute images add-iam-policy-binding IMAGE_NAME \
  --member='user:user@example.com' \
  --role='roles/compute.imageUser'
```

### GKEクラスタ管理
```bash
# クラスタ情報取得
gcloud container clusters describe CLUSTER_NAME

# Node Auto-Upgrade有効化
gcloud container clusters update CLUSTER_NAME \
  --enable-autoupgrade

# Network Policy有効化
gcloud container clusters update CLUSTER_NAME \
  --enable-network-policy

# Binary Authorization有効化
gcloud container clusters update CLUSTER_NAME \
  --enable-binauthz
```

### Container Scanning
```bash
# on-demandスキャン実行
gcloud container images scan IMAGE_URL

# 脆弱性結果取得
gcloud container images describe IMAGE_URL \
  --show-package-vulnerability
```

---

## セキュリティチェックリスト

### Compute Engine
- [ ] Shielded VM有効化
- [ ] Confidential VM検討（機密データ処理時）
- [ ] OS Login有効化
- [ ] カスタムイメージでhardening実施
- [ ] イメージファミリーで最新版管理
- [ ] 廃止イメージのライフサイクル管理

### CI/CD
- [ ] SCA（依存関係スキャン）統合
- [ ] SAST（静的解析）統合
- [ ] Container vulnerability scanning有効化
- [ ] Binary Authorization設定
- [ ] Secret Manager使用（ハードコード禁止）
- [ ] IAM最小権限設定

### GKE
- [ ] Private Cluster検討
- [ ] Shielded GKE Nodes有効化
- [ ] Workload Identity有効化
- [ ] Binary Authorization有効化
- [ ] Network Policy設定
- [ ] RBAC最小権限設定
- [ ] Node Auto-Upgrade有効化
- [ ] Cloud Logging/Monitoring有効
- [ ] Container Threat Detection有効化（SCC Premium）
- [ ] Service Mesh検討（mTLS）

---

## トラブルシューティング

### Shielded VM起動失敗
**症状**: `UEFI: Failed to load image Status: Security Violation`
**原因**: 署名検証失敗
**対処**: シリアルコンソールログで失敗コンポーネント特定、署名済みバージョンに差し替え

### Binary Authorization拒否
**症状**: Deployment作成時に `ImagePolicyWebhook` エラー
**原因**: 必要なattestation不足
**対処**:
```bash
# attestation確認
gcloud container binauthz attestations list \
  --attestor=ATTESTOR --artifact-url=IMAGE_URL

# 必要なattestor設定確認
gcloud container binauthz policy export
```

### Workload Identity認証失敗
**症状**: Pod内でGCP API呼び出し時 `403 Forbidden`
**原因**: KSA↔GSAバインディング不備
**対処**:
```bash
# annotation確認
kubectl get sa KSA_NAME -n NAMESPACE -o yaml | grep gcp-service-account

# IAMバインディング確認
gcloud iam service-accounts get-iam-policy \
  GSA_NAME@PROJECT.iam.gserviceaccount.com
```
