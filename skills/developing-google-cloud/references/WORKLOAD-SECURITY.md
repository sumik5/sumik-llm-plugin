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
    # GOOGLE_APPLICATION_credentials不要！
```

#### Workload Identity vs. サービスアカウントキー（決定判断基準）

| 評価項目 | Workload Identity（推奨） | サービスアカウントJSON鍵 |
|---------|-------------------------|----------------------|
| **認証方式** | 短命トークン（1時間、自動ローテーション） | 長命静的鍵（無期限、手動管理） |
| **鍵流出リスク** | ✅ トークンのみ（短命）| ❌ JSON鍵永続化、Git誤コミットリスク |
| **ローテーション** | ✅ 自動（GKE管理） | ❌ 手動（90日推奨だが忘れやすい） |
| **権限スコープ** | ✅ Pod単位で細分化可能 | ⚠ プロジェクト全体で共有されがち |
| **監査ログ** | ✅ Pod identityでトレース可能 | ⚠ SA全体で集約、Pod特定困難 |
| **初期設定複雑度** | ⚠ KSA↔GSAバインディング必要 | ✅ 単純（JSON鍵ダウンロードのみ） |
| **GKE Autopilot** | ✅ デフォルト有効 | ❌ 非対応 |
| **コンプライアンス** | ✅ PCI-DSS/HIPAAで推奨 | ❌ 静的鍵は要追加統制 |

**移行パターン（レガシー→Workload Identity）**:

```bash
# ステップ1: 既存JSON鍵使用Podの特定
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.volumes[]?.secret?.secretName // false) |
  "\(.metadata.namespace)/\(.metadata.name)"
'

# ステップ2: Workload Identity有効化（既存クラスタ）
gcloud container clusters update CLUSTER_NAME \
  --workload-pool=PROJECT_ID.svc.id.goog

# ステップ3: ノードプール再作成（Workload Identity metadata有効化）
gcloud container node-pools update NODE_POOL_NAME \
  --cluster=CLUSTER_NAME \
  --workload-metadata=GKE_METADATA

# ステップ4: KSA→GSAバインディング（上記手順参照）

# ステップ5: Pod manifestからGOOGLE_APPLICATION_CREDENTIALS削除
# PodをWorkload Identity対応に移行後、K8s Secretのjson鍵削除
kubectl delete secret SERVICE_ACCOUNT_KEY_SECRET -n NAMESPACE
```

**セキュリティ監査チェックリスト**:
| 監査項目 | コマンド例 |
|---------|-----------|
| JSON鍵使用Pod検出 | `kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.volumes[*].secret.secretName}{"\n"}{end}' \| grep -i key` |
| Workload Identity未設定Pod検出 | `kubectl get sa -A -o json \| jq -r '.items[] \| select(.metadata.annotations["iam.gke.io/gcp-service-account"] == null) \| "\(.metadata.namespace)/\(.metadata.name)"'` |
| GSA過剰権限チェック | `gcloud projects get-iam-policy PROJECT_ID --flatten="bindings[].members" --filter="bindings.members:serviceAccount:*" --format="table(bindings.role,bindings.members)"` |

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

### GKEクラスタセキュリティレイヤー（ノード・Podレベル詳細）

#### セキュリティ防御の階層構造

```
┌─────────────────────────────────────────────────────┐
│  Layer 5: アプリケーション/Pod                        │
│  ├─ Pod Security Standards (Restricted)            │
│  ├─ Resource Limits (CPU/Memory)                   │
│  ├─ Read-only root filesystem                      │
│  ├─ runAsNonRoot: true (UID ≠ 0)                   │
│  └─ securityContext.capabilities.drop: [ALL]       │
├─────────────────────────────────────────────────────┤
│  Layer 4: ネットワークポリシー                         │
│  ├─ Default-deny ingress/egress                    │
│  ├─ NetworkPolicy (Pod→Pod制御)                    │
│  ├─ mTLS (Istio/Anthos Service Mesh)               │
│  └─ AuthorizationPolicy (L7 RBAC)                  │
├─────────────────────────────────────────────────────┤
│  Layer 3: クラスタ制御                                │
│  ├─ Workload Identity (Pod→GCP SA binding)         │
│  ├─ Kubernetes RBAC (Role/RoleBinding)             │
│  ├─ Binary Authorization (署名済みイメージのみ)        │
│  └─ Admission Controllers (OPA Gatekeeper)         │
├─────────────────────────────────────────────────────┤
│  Layer 2: ノードセキュリティ                          │
│  ├─ Shielded GKE Nodes (Secure Boot + vTPM)        │
│  ├─ Node Auto-Upgrade (CVE自動パッチ)               │
│  ├─ COS/Container-Optimized OS (最小攻撃面)         │
│  └─ Private nodes (外部IP無し)                      │
├─────────────────────────────────────────────────────┤
│  Layer 1: コントロールプレーン                         │
│  ├─ Private endpoint (API server内部IP)            │
│  ├─ Master Authorized Networks (IP制限)            │
│  ├─ Certificate-based authentication              │
│  └─ Audit Logging (K8s API全操作記録)              │
└─────────────────────────────────────────────────────┘
```

#### ノードレベルセキュリティ設定

**ノードプール分離戦略**:

| パターン | 設定 | 使用ケース |
|---------|------|-----------|
| **テナント専用ノードプール** | `node-taints=tenant=A:NoSchedule`, `node-labels=tenant=A` | SaaSマルチテナンシー |
| **セキュリティゾーン分離** | `node-taints=zone=dmz:NoSchedule`, `node-labels=zone=dmz` | PCI-DSS準拠DMZ分離 |
| **ワークロード種別分離** | `node-taints=workload=gpu:NoSchedule` | GPU/バッチ処理分離 |

**Terraform実装例（セキュアノードプール）**:
```hcl
resource "google_container_node_pool" "secure_pool" {
  name       = "secure-prod-pool"
  cluster    = google_container_cluster.primary.id
  node_count = 3

  node_config {
    machine_type = "n2-standard-4"
    image_type   = "COS_CONTAINERD"

    # Shielded VM有効化
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Workload Identity有効化
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # ノードラベル・Taints設定
    labels = {
      environment = "production"
      compliance  = "pci-dss"
    }

    taints {
      key    = "compliance"
      value  = "pci-dss"
      effect = "NO_SCHEDULE"
    }

    # サービスアカウント（最小権限）
    service_account = google_service_account.gke_node_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    # ノードメタデータセキュリティ
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}
```

#### Podレベルセキュリティ強化

**Restricted Pod Security Policy（ベストプラクティス）**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: production
spec:
  serviceAccountName: app-ksa  # Workload Identity
  automountServiceAccountToken: false  # トークン自動マウント無効

  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault  # syscallフィルタリング

  containers:
  - name: app
    image: gcr.io/my-project/app:v1.2.3  # ダイジェスト指定推奨
    imagePullPolicy: Always

    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL  # 全capability削除

    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"

    volumeMounts:
    - name: tmp
      mountPath: /tmp
      readOnly: false

  volumes:
  - name: tmp
    emptyDir: {}
```

**セキュリティコンテキスト判断基準**:

| 設定 | 値 | セキュリティ影響 | トレードオフ |
|------|----|--------------|-----------  |
| `runAsNonRoot` | `true` | ✅ root実行禁止（特権昇格防止） | 一部レガシーアプリ非互換 |
| `readOnlyRootFilesystem` | `true` | ✅ ファイル改ざん防止 | `/tmp`, `/var`等emptyDirマウント必要 |
| `allowPrivilegeEscalation` | `false` | ✅ setuid/setgid無効化 | デバッグツール制限 |
| `capabilities.drop: [ALL]` | `true` | ✅ Linux capabilities全削除 | ネットワーク操作不可 |
| `seccompProfile: RuntimeDefault` | `true` | ✅ 危険syscall制限 | ごく一部カーネル機能使用不可 |

---

### セキュアコンテナビルドパイプライン実装

#### エンドツーエンドセキュリティゲート

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Source    │      │    Build    │      │    Scan     │      │   Deploy    │
│   Control   │─────>│   Image     │─────>│  & Sign     │─────>│   to GKE    │
└─────────────┘      └─────────────┘      └─────────────┘      └─────────────┘
      │                     │                     │                     │
      ▼                     ▼                     ▼                     ▼
Git commit ──────> Cloud Build ──────> Trivy scan ──────> Binary Auth
（署名済み）      （SLSA L2+）       （CRITICAL:0）      （Attestation）
```

#### Cloud Build パイプライン実装

**cloudbuild.yaml（SLSA準拠ビルド）**:
```yaml
steps:
  # ステップ1: イメージビルド
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - 'gcr.io/$PROJECT_ID/app:$SHORT_SHA'
      - '-t'
      - 'gcr.io/$PROJECT_ID/app:latest'
      - '--build-arg'
      - 'BUILDKIT_INLINE_CACHE=1'
      - '.'
    id: 'build-image'

  # ステップ2: イメージプッシュ（Artifact Registryで自動スキャン開始）
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/app:$SHORT_SHA']
    id: 'push-image'
    waitFor: ['build-image']

  # ステップ3: Trivyスキャン（CRITICAL脆弱性検出時にfail）
  - name: 'aquasec/trivy'
    args:
      - 'image'
      - '--exit-code'
      - '1'  # CRITICAL検出時にfail
      - '--severity'
      - 'CRITICAL,HIGH'
      - '--format'
      - 'json'
      - '--output'
      - 'trivy-results.json'
      - 'gcr.io/$PROJECT_ID/app:$SHORT_SHA'
    id: 'trivy-scan'
    waitFor: ['push-image']

  # ステップ4: SBOM生成（Software Bill of Materials）
  - name: 'aquasec/trivy'
    args:
      - 'image'
      - '--format'
      - 'cyclonedx'
      - '--output'
      - 'sbom.json'
      - 'gcr.io/$PROJECT_ID/app:$SHORT_SHA'
    id: 'generate-sbom'
    waitFor: ['trivy-scan']

  # ステップ5: cosignでイメージ署名
  - name: 'gcr.io/projectsigstore/cosign'
    env:
      - 'COSIGN_EXPERIMENTAL=1'  # keyless署名（Fulcio CA）
    args:
      - 'sign'
      - '--yes'
      - 'gcr.io/$PROJECT_ID/app:$SHORT_SHA'
    id: 'sign-image'
    waitFor: ['generate-sbom']

  # ステップ6: Binary Authorization Attestation作成
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        DIGEST=$(gcloud container images describe gcr.io/$PROJECT_ID/app:$SHORT_SHA \
          --format='get(image_summary.digest)')
        gcloud container binauthz attestations create \
          --artifact-url="gcr.io/$PROJECT_ID/app@$${DIGEST}" \
          --attestor=projects/$PROJECT_ID/attestors/build-attestor \
          --signature-file=signature.sig \
          --public-key-id=projects/$PROJECT_ID/locations/global/keyRings/binauthz/cryptoKeys/attestor-key/cryptoKeyVersions/1
    id: 'create-attestation'
    waitFor: ['sign-image']

images:
  - 'gcr.io/$PROJECT_ID/app:$SHORT_SHA'
  - 'gcr.io/$PROJECT_ID/app:latest'

options:
  logging: CLOUD_LOGGING_ONLY
  machineType: 'N1_HIGHCPU_8'
```

#### Binary Authorization Policy（厳格版）

**policy.yaml（本番環境）**:
```yaml
admissionWhitelistPatterns:
  - namePattern: "gcr.io/my-project/*"

defaultAdmissionRule:
  evaluationMode: REQUIRE_ATTESTATION
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  requireAttestationsBy:
    - projects/my-project/attestors/build-attestor
    - projects/my-project/attestors/security-attestor

globalPolicyEvaluationMode: ENABLE

clusterAdmissionRules:
  us-central1.prod-cluster:
    evaluationMode: REQUIRE_ATTESTATION
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    requireAttestationsBy:
      - projects/my-project/attestors/build-attestor
      - projects/my-project/attestors/security-attestor

  # 開発環境は緩和（スピード優先）
  us-central1.dev-cluster:
    evaluationMode: ALWAYS_ALLOW
    enforcementMode: DRYRUN_AUDIT_LOG_ONLY
```

#### セキュアビルド監視クエリ（BigQuery）

**脆弱性検出率トラッキング**:
```sql
-- CI/CDパイプラインの脆弱性ブロック率
SELECT
  DATE(timestamp) as build_date,
  COUNT(*) as total_builds,
  COUNTIF(status = 'FAILURE' AND
    REGEXP_CONTAINS(logName, 'trivy-scan')) as blocked_builds,
  ROUND(COUNTIF(status = 'FAILURE' AND
    REGEXP_CONTAINS(logName, 'trivy-scan')) / COUNT(*) * 100, 2) as block_rate_pct
FROM `project.dataset.cloudbuild_logs`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY build_date
ORDER BY build_date DESC
```

---

### マイクロサービス間ネットワークポリシー実装パターン

#### 3層アプリケーション分離（デフォルト拒否 + 明示的許可）

```yaml
# ステップ1: 全通信拒否（ベースライン）
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress

---
# ステップ2: Frontend → Backend通信許可
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              tier: frontend
      ports:
        - protocol: TCP
          port: 8080

---
# ステップ3: Backend → Database通信許可
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              tier: backend
      ports:
        - protocol: TCP
          port: 5432

---
# ステップ4: 全サービス → DNS解決許可（egress）
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53

---
# ステップ5: Backend → 外部API通信許可（HTTPS egress）
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-external-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
              - 172.16.0.0/12
              - 192.168.0.0/16
      ports:
        - protocol: TCP
          port: 443
```

#### Istio AuthorizationPolicy統合（L7制御）

**HTTPメソッド・パスレベル制御**:
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: payment-api-authz
  namespace: production
spec:
  selector:
    matchLabels:
      app: payment-service
  action: ALLOW
  rules:
    # ルール1: frontend-service から GET /api/v1/payments/* のみ許可
    - from:
        - source:
            principals: ["cluster.local/ns/production/sa/frontend-sa"]
      to:
        - operation:
            methods: ["GET"]
            paths: ["/api/v1/payments/*"]
    # ルール2: backend-service から POST /api/v1/payments のみ許可
    - from:
        - source:
            principals: ["cluster.local/ns/production/sa/backend-sa"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/api/v1/payments"]
```

#### ネットワークポリシー検証スクリプト

```bash
#!/bin/bash
# network-policy-test.sh: ネットワークポリシー動作確認

# テスト1: frontend → backend 通信（許可されるべき）
kubectl run test-frontend --image=busybox --labels=tier=frontend -n production \
  --restart=Never --rm -it -- wget -qO- http://backend-service:8080/health

# テスト2: frontend → database 直接通信（拒否されるべき）
kubectl run test-frontend --image=busybox --labels=tier=frontend -n production \
  --restart=Never --rm -it -- nc -zv database-service 5432

# テスト3: backend → database 通信（許可されるべき）
kubectl run test-backend --image=busybox --labels=tier=backend -n production \
  --restart=Never --rm -it -- nc -zv database-service 5432

# テスト4: 不正ラベルPod → backend 通信（拒否されるべき）
kubectl run test-attacker --image=busybox --labels=tier=attacker -n production \
  --restart=Never --rm -it -- wget -qO- --timeout=5 http://backend-service:8080/health
```

---

### マルチテナントGKEセキュリティ境界設計

#### テナント分離アーキテクチャ比較

| アーキテクチャ | 分離レベル | コスト | 管理複雑度 | 使用ケース |
|--------------|----------|-------|-----------|-----------|
| **クラスタ分離** | ✅✅✅ 最高（物理分離） | 高 | 高 | 規制産業、エンタープライズ |
| **Namespace分離 + Network Policy** | ✅✅ 高（論理分離） | 中 | 中 | SaaS、中規模マルチテナント |
| **ノードプール分離** | ✅✅ 高（ノードレベル） | 中 | 中 | セキュリティゾーン分離 |
| **Pod Security Policy** | ✅ 中（Pod制約） | 低 | 低 | 開発環境、軽量分離 |

#### Namespace分離 + Network Policy実装

**テナントA/B分離設定**:
```yaml
# Tenant A Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a
  labels:
    tenant: a
    pod-security.kubernetes.io/enforce: restricted

---
# Tenant A: default-deny-all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: tenant-a
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress

---
# Tenant A: 共有サービスへのegress許可
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-shared-services
  namespace: tenant-a
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: shared-services
      ports:
        - protocol: TCP
          port: 443

---
# Shared Services Namespace: Tenant A/B両方からアクセス許可
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-tenants
  namespace: shared-services
spec:
  podSelector:
    matchLabels:
      app: auth-service
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchExpressions:
              - key: tenant
                operator: In
                values: ["a", "b"]
      ports:
        - protocol: TCP
          port: 443
```

#### Resource Quota強制（テナント別リソース制限）

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-a-quota
  namespace: tenant-a
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    requests.storage: 500Gi
    persistentvolumeclaims: "50"
    pods: "100"
    services.loadbalancers: "5"
```

#### Hierarchical Namespace Controller（HNC）導入

**テナント階層構造管理**:
```yaml
apiVersion: hnc.x-k8s.io/v1alpha2
kind: HierarchyConfiguration
metadata:
  name: hierarchy
  namespace: tenant-a
spec:
  parent: root-org

---
apiVersion: hnc.x-k8s.io/v1alpha2
kind: SubnamespaceAnchor
metadata:
  name: tenant-a-dev
  namespace: tenant-a
```

**セキュリティ監査チェックリスト（マルチテナント）**:
| チェック項目 | 検証コマンド |
|------------|-------------|
| Namespace分離確認 | `kubectl get ns --show-labels` |
| Network Policy適用確認 | `kubectl get networkpolicies -A` |
| Resource Quota設定確認 | `kubectl get resourcequotas -A` |
| クロステナント通信検証 | `kubectl run test-pod -n tenant-a --image=busybox --rm -it -- wget -qO- http://service.tenant-b:80` （失敗すべき） |
| Pod Security Standards強制確認 | `kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.pod-security\.kubernetes\.io/enforce}{"\n"}{end}'` |

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
