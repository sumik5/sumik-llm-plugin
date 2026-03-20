# GKE コンテナオーケストレーション（Kubernetes マネージドサービス）

Google Kubernetes Engine（GKE）は、Google が Borg システムの 10 年以上の知見をもとに開発した Kubernetes を、フルマネージドサービスとして提供するプロダクトである。コンテナ化アプリケーションの大規模自動スケーリング・高可用性・ノーダウンタイムアップグレードを提供し、エンタープライズシステムのマイクロサービス基盤として広く活用される。本リファレンスではコンテナ・Kubernetes の基礎から GKE 固有の設計パターン・セキュリティまでを包括的に扱う。

## Kubernetes 基礎

### Docker とコンテナの役割

Docker は「アプリケーション実行モジュール + ミドルウェア + OS/ネットワーク設定」を 1 つのコンテナイメージにまとめる技術。これにより「開発環境では動くが本番では動かない」問題を解消し、Immutable Infrastructure（不変インフラ）を実現する。

**Docker が解決する 3 つの課題:**

| 課題 | Docker による解決 |
|------|----------------|
| 継続的インテグレーション環境の維持 | 全メンバーが同一 Dockerfile から同一環境を再現 |
| 継続的デリバリーのデプロイ効率化 | テスト済みイメージをそのまま本番にデプロイ |
| Immutable Infrastructure による構成管理 | 変更はイメージビルドし直し（直接変更禁止） |

### Kubernetes の基本オブジェクト

| オブジェクト | 役割 | 特徴 |
|------------|------|------|
| **Pod** | コンテナの実行単位（1〜複数コンテナをグループ化） | スケジューリングの最小単位 |
| **ReplicaSet** | 指定した数の Pod 複製を維持 | Pod 障害時に自動復旧 |
| **Deployment** | ReplicaSet を管理し、ローリングアップデートを担当 | バージョン管理・ロールバック対応 |
| **Service** | Pod 群へのネットワークアクセスを抽象化 | ロードバランシング・DNS 解決 |
| **Namespace** | クラスタ内のリソースを論理的に分離 | チーム・環境の分離管理 |
| **ConfigMap / Secret** | 設定値・機密情報の分離管理 | 環境変数・ボリュームマウント |
| **PersistentVolume** | ステートフルアプリのストレージ | Pod が削除されてもデータ保持 |
| **NetworkPolicy** | Pod 間通信の制御ルール | マイクロサービス間の通信制御 |

### Kubernetes クラスタアーキテクチャ

```
[ コントロールプレーン（GKE が管理） ]
  API Server ← kubectl / CI/CD パイプライン
  Scheduler  → ノードへの Pod 配置を決定
  etcd       → クラスタ状態の永続化

[ ワーカーノード（ユーザー管理）]
  kubelet    → ノード上で Pod を起動・管理
  kube-proxy → Pod へのネットワーク転送
  Container Runtime（containerd）
```

**GKE の特徴:** コントロールプレーン（kube-apiserver, etcd）は Google が完全管理。ユーザーはノードの設定・スペック選択のみに集中できる。Autopilot モードではノード管理も Google に委任できる。

## GKE クラスタ構築・管理

### クラスタタイプの選択

| クラスタタイプ | コントロールプレーン | ノード配置 | 可用性 | 推奨場面 |
|--------------|-------------------|----------|--------|---------|
| **シングルゾーン** | 1 ゾーン | 1 ゾーン | ✕（ゾーン障害でクラスタ全体停止） | 開発・検証環境 |
| **マルチゾーン** | 1 ゾーン | 3 ゾーン | △（コントロールプレーンは単一ゾーン） | 準本番環境 |
| **リージョンクラスタ** | 3 ゾーン | 3 ゾーン | ◎（アップグレード中も完全可用性） | 本番環境 |

**選択指針:** 本番システムではリージョンクラスタを選択し、コントロールプレーンの単一障害点を排除する。ただしゾーン間通信コスト・ノード数増加によるコスト増に留意。

### クラスタ作成（gcloud コマンド）

```bash
# リージョンクラスタ作成（本番推奨）
gcloud container clusters create my-cluster \
  --region=asia-northeast1 \
  --num-nodes=3 \
  --machine-type=n2-standard-4 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=10 \
  --workload-pool=PROJECT_ID.svc.id.goog  # Workload Identity 有効化

# Autopilot クラスタ作成（ノード管理不要）
gcloud container clusters create-auto my-autopilot-cluster \
  --region=asia-northeast1

# クラスタの認証情報を取得
gcloud container clusters get-credentials my-cluster \
  --region=asia-northeast1
```

### ノードプール管理

```bash
# 異なるマシンタイプのノードプール追加（GPU ノードなど）
gcloud container node-pools create gpu-pool \
  --cluster=my-cluster \
  --region=asia-northeast1 \
  --machine-type=n1-standard-4 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --num-nodes=2

# プリエンプティブルノードプール（コスト削減）
gcloud container node-pools create batch-pool \
  --cluster=my-cluster \
  --region=asia-northeast1 \
  --machine-type=n2-standard-4 \
  --preemptible \
  --num-nodes=0 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=20
```

## スケーリング戦略

### 多段自動スケーリング構成

GKE はクラスタレベル・Pod レベルの 2 段階でスケーリングを組み合わせることで、さまざまな性能要求に対応する。

| スケーリング機能 | 対象 | スケールの方向 | トリガー |
|--------------|------|-------------|---------|
| **クラスタオートスケーラー** | ノードプール | 水平（ノード数） | Pod のリソース要求が満たせない場合 |
| **ノード自動プロビジョニング** | ノードプール | 水平（プール作成/削除） | 既存プールでは対応できない Pod 要求 |
| **水平 Pod 自動スケーリング（HPA）** | Pod 数 | 水平（Pod 数） | CPU/メモリ使用率・カスタム指標 |
| **垂直 Pod 自動スケーリング（VPA）** | Pod リソース | 垂直（CPU/メモリ割当） | 過去の使用状況に基づく推奨値 |

```yaml
# HPA 設定例（CPU 使用率 50% をターゲット）
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 50
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

## ローリングアップデートとデプロイ戦略

### ローリングアップデート

サービスを停止せずにアプリケーションをバージョンアップできる。コンテナ環境ならではの最大のメリット。

```yaml
# Deployment によるローリングアップデート設定
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # 一時的に追加できる Pod 数
      maxUnavailable: 1  # 同時に停止できる Pod 数
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: asia-northeast1-docker.pkg.dev/PROJECT/REPO/my-app:v2
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "500m"
            memory: "1Gi"
```

```bash
# アップデートの適用
kubectl set image deployment/my-app my-app=IMAGE:v2

# ロールアウト状況確認
kubectl rollout status deployment/my-app

# ロールバック
kubectl rollout undo deployment/my-app
```

### デプロイ戦略比較

| 戦略 | 概要 | メリット | デメリット |
|------|------|---------|----------|
| **Rolling Update** | Pod を段階的に入れ替え | ゼロダウンタイム・追加リソース最小 | 旧新バージョンが同時存在 |
| **Blue/Green** | 全 Pod を一度に切替 | 即座なロールバック可 | 2倍のリソースが一時的に必要 |
| **Canary** | 一部 Pod のみ新バージョン | リスク最小・段階的検証 | 設定が複雑 |

## Workload Identity（IAMとの統合）

### Workload Identity の概要

GKE の Pod から GCP サービス（Cloud Storage、BigQuery 等）にアクセスする際、サービスアカウントキーのファイルをコンテナに配置するのではなく、Kubernetes サービスアカウントと Google Cloud サービスアカウントをバインドして認証する仕組み。

**なぜ重要か:** キーファイルをコンテナイメージやボリュームに配置すると漏洩リスクが高い。Workload Identity ではキーが存在せず、動的に認証トークンを取得する。

```bash
# 1. Google Cloud サービスアカウント作成
gcloud iam service-accounts create my-app-sa \
  --display-name="My App Service Account"

# 2. 必要な権限付与
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:my-app-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# 3. Kubernetes SA と GCP SA のバインド
gcloud iam service-accounts add-iam-policy-binding \
  my-app-sa@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:PROJECT_ID.svc.id.goog[NAMESPACE/KSA_NAME]"
```

```yaml
# Kubernetes ServiceAccount に GCP SA をアノテーション
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-ksa
  namespace: default
  annotations:
    iam.gke.io/gcp-service-account: my-app-sa@PROJECT_ID.iam.gserviceaccount.com
```

## ネットワークポリシー

### ネットワークポリシーによる Pod 間通信制御

デフォルトでは同一クラスタ内の全 Pod が通信可能。ネットワークポリシーで必要な通信のみを許可するゼロトラスト構成を実現する。

```yaml
# backend Pod へのアクセスを frontend namespace からのみ許可
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
      podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
  policyTypes:
  - Ingress
```

## GKE のセキュリティ設計

### セキュリティの多層構造

| セキュリティ層 | 対策 | GKE の機能 |
|-------------|------|-----------|
| **クラスタレベル** | 非公開クラスタ・限定公開エンドポイント | Private Cluster |
| **ノードレベル** | OS 脆弱性対策・シールドノード | Shielded GKE Nodes |
| **Pod レベル** | Pod 間通信制御・信頼できないコードの隔離 | NetworkPolicy / GKE Sandbox |
| **コンテナイメージ** | 脆弱性スキャン・イメージ署名検証 | Artifact Registry / Binary Authorization |
| **アクセス制御** | K8s RBAC + Cloud IAM | GKE 用 IAM ロール |

### GKE Sandbox（gVisor）

第三者提供の信頼できないコードを実行する場合、GKE Sandbox（gVisor）を有効にするとカーネルを保護。有効化したノードプール内の Pod はホストカーネルにアクセスできなくなる。

```bash
# GKE Sandbox 有効なノードプール作成
gcloud container node-pools create sandbox-pool \
  --cluster=my-cluster \
  --region=asia-northeast1 \
  --sandbox="type=gvisor" \
  --machine-type=n2-standard-4
```

### Autopilot モード vs Standard モード

| 比較軸 | Standard モード | Autopilot モード |
|--------|--------------|----------------|
| **ノード管理** | ユーザーが管理 | Google が完全管理 |
| **課金単位** | ノード単位（使用率によらず） | Pod のリソースリクエスト単位 |
| **ノードプール** | 手動設定 | 自動プロビジョニング |
| **セキュリティデフォルト** | ユーザー設定 | Hardened Pod（自動適用） |
| **利用可能な機能** | すべての K8s 機能 | 一部制限あり（DaemonSet など） |
| **適した用途** | 高度なカスタマイズが必要 | シンプルな運用・コスト最適化 |

## 非機能要件設計ポイント

### 可用性・スケーラビリティ

- 本番環境は必ずリージョンクラスタを選択（コントロールプレーンの HA）
- 水平 Pod 自動スケーリング + クラスタオートスケーラーを組み合わせる
- Pod に Readiness Probe / Liveness Probe を設定し、不健全な Pod への流量を防止
- PodDisruptionBudget を設定してアップグレード時の最低稼働 Pod 数を保証

### コスト最適化

- バッチワークロードはプリエンプティブルノードプールを活用（最大 91% 割引）
- Autopilot モードでは使用したリソース（CPU/メモリ）分のみ課金
- ノード自動プロビジョニングで不要なノードプールを自動削除
- Recommender を活用してリソースリクエストの過剰設定を検出
