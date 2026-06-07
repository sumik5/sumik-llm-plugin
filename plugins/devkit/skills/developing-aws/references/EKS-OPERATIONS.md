# EKS OPERATIONS

EKSクラスタの運用管理、セキュリティ、デプロイ戦略、監視、ストレージ、HA/DR、コスト最適化、パフォーマンスチューニングの実践ガイド。

## セキュリティ

### IAM Roles for Service Accounts (IRSA)

PodにAWS IAMロールを安全に割り当てる仕組み。

**OIDC Providerの設定**:
```bash
# OIDCプロバイダーの作成
eksctl utils associate-iam-oidc-provider \
  --region=us-east-1 \
  --cluster=my-cluster \
  --approve
```

**IAMロールとポリシーの作成**:
```bash
# Trust Policy作成
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/XXXXX"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/XXXXX:sub": "system:serviceaccount:default:my-sa",
          "oidc.eks.us-east-1.amazonaws.com/id/XXXXX:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# IAMロール作成
aws iam create-role \
  --role-name my-pod-role \
  --assume-role-policy-document file://trust-policy.json

# ポリシーアタッチ
aws iam attach-role-policy \
  --role-name my-pod-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

**ServiceAccountとPodの設定**:
```yaml
# ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-pod-role
---
# Pod
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  namespace: default
spec:
  serviceAccountName: my-sa
  containers:
    - name: app
      image: myapp:latest
      env:
        - name: AWS_ROLE_ARN
          value: arn:aws:iam::123456789012:role/my-pod-role
        - name: AWS_WEB_IDENTITY_TOKEN_FILE
          value: /var/run/secrets/eks.amazonaws.com/serviceaccount/token
```

**eksctlで一括作成**:
```bash
eksctl create iamserviceaccount \
  --name my-sa \
  --namespace default \
  --cluster my-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve \
  --override-existing-serviceaccounts
```

### Pod Security Standards

Pod実行時のセキュリティ制約。

**Pod Security Admission設定**:
```yaml
# Namespace に Pod Security Standard を適用
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**3つのレベル**:

| レベル | 制約 | ユースケース |
|--------|------|--------------|
| **Privileged** | 制約なし | 信頼できるワークロード |
| **Baseline** | 基本的な制約 | 一般的なアプリケーション |
| **Restricted** | 厳格な制約 | セキュリティ重視 |

**Restricted レベルのPod例**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: production
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: myapp:latest
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
        readOnlyRootFilesystem: true
      volumeMounts:
        - name: tmp
          mountPath: /tmp
  volumes:
    - name: tmp
      emptyDir: {}
```

### Secrets Management

機密情報の安全な管理。

**Kubernetes Secrets**:
```bash
# Secretの作成
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=secret123

# Secretの使用
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
    - name: app
      image: myapp:latest
      env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
```

**AWS Secrets Manager統合**:
```yaml
# External Secrets Operatorインストール
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  annotations:
    secret-manager: aws
spec:
  type: Opaque
  data:
    username: <base64-encoded>
    password: <base64-encoded>
```

```bash
# External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace
```

```yaml
# SecretStore（AWS Secrets Manager）
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
  namespace: default
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
---
# ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-secret
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: db-credentials
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: prod/db/credentials
        property: username
    - secretKey: password
      remoteRef:
        key: prod/db/credentials
        property: password
```

---

## デプロイ戦略

### ローリングアップデート

デフォルトのデプロイ戦略。段階的にPodを更新。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # 同時に作成できる追加Pod数
      maxUnavailable: 1  # 同時に利用不可にできるPod数
  template:
    metadata:
      labels:
        app: myapp
        version: v2
    spec:
      containers:
        - name: app
          image: myapp:v2
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
```

**デプロイコマンド**:
```bash
# イメージ更新
kubectl set image deployment/app app=myapp:v2

# ロールアウト状況監視
kubectl rollout status deployment/app

# ロールバック
kubectl rollout undo deployment/app

# 特定のリビジョンにロールバック
kubectl rollout undo deployment/app --to-revision=3
```

### Blue/Green デプロイ

新旧環境を並行稼働させ、一瞬で切り替え。

```yaml
# Blue環境（現行）
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
  labels:
    app: myapp
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
        - name: app
          image: myapp:v1
---
# Green環境（新規）
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  labels:
    app: myapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
        - name: app
          image: myapp:v2
---
# Service（切り替え可能）
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp
    version: blue  # blueからgreenに切り替える
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

**切り替えコマンド**:
```bash
# Serviceのセレクタを変更
kubectl patch service app-service -p '{"spec":{"selector":{"version":"green"}}}'

# 問題があればロールバック
kubectl patch service app-service -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Canary デプロイ

新バージョンに段階的にトラフィックを流す。

```yaml
# 現行バージョン（90%）
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: myapp
      track: stable
  template:
    metadata:
      labels:
        app: myapp
        track: stable
    spec:
      containers:
        - name: app
          image: myapp:v1
---
# Canaryバージョン（10%）
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      track: canary
  template:
    metadata:
      labels:
        app: myapp
        track: canary
    spec:
      containers:
        - name: app
          image: myapp:v2
---
# Service（両方のPodにルーティング）
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: myapp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

### Argo Rollouts

高度なデプロイ戦略を自動化。

**インストール**:
```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

**Rollout定義（Canary）**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: app-rollout
spec:
  replicas: 10
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 5m}
        - setWeight: 40
        - pause: {duration: 5m}
        - setWeight: 60
        - pause: {duration: 5m}
        - setWeight: 80
        - pause: {duration: 5m}
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: app
          image: myapp:v2
          ports:
            - containerPort: 8080
```

**Rolloutコマンド**:
```bash
# Rollout開始
kubectl argo rollouts promote app-rollout

# ロールバック
kubectl argo rollouts abort app-rollout

# ステータス確認
kubectl argo rollouts status app-rollout

# 履歴表示
kubectl argo rollouts history app-rollout
```

---

## 監視

### CloudWatch Container Insights

EKSクラスタとコンテナのメトリクス・ログを収集。

**有効化**:
```bash
# Container Insights有効化
eksctl utils update-cluster-logging \
  --enable-types=all \
  --region=us-east-1 \
  --cluster=my-cluster \
  --approve
```

**CloudWatch Agentインストール**:
```bash
# FluentBit for logs
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml

# CloudWatch Agent for metrics
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-daemonset.yaml
```

**カスタムメトリクス**:
```yaml
# アプリケーションからのメトリクス送信
apiVersion: v1
kind: ConfigMap
metadata:
  name: cwagent-config
  namespace: amazon-cloudwatch
data:
  cwagentconfig.json: |
    {
      "metrics": {
        "namespace": "EKS/CustomMetrics",
        "metrics_collected": {
          "statsd": {
            "service_address": ":8125",
            "metrics_collection_interval": 60
          }
        }
      }
    }
```

### Prometheus & Grafana

オープンソースの監視スタック。

**Prometheus Operatorインストール**:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

**ServiceMonitor（カスタムメトリクス）**:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: app-monitor
  namespace: default
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

**アプリケーション側のメトリクス公開（Node.js例）**:
```javascript
const express = require('express');
const promClient = require('prom-client');

const app = express();
const register = new promClient.Registry();

// デフォルトメトリクス
promClient.collectDefaultMetrics({ register });

// カスタムメトリクス
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(3000);
```

**Grafana Dashboard**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  eks-cluster.json: |
    {
      "dashboard": {
        "title": "EKS Cluster Overview",
        "panels": [
          {
            "title": "CPU Usage",
            "targets": [
              {
                "expr": "sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)"
              }
            ]
          }
        ]
      }
    }
```

### Fluent Bit / Fluentd

ログ収集と転送。

**Fluent Bit DaemonSet**:
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: logging
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      serviceAccountName: fluent-bit
      containers:
        - name: fluent-bit
          image: fluent/fluent-bit:2.0
          volumeMounts:
            - name: varlog
              mountPath: /var/log
            - name: varlibdockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
            - name: fluent-bit-config
              mountPath: /fluent-bit/etc/
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
        - name: fluent-bit-config
          configMap:
            name: fluent-bit-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: logging
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Daemon        off
        Log_Level     info

    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5

    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token

    [OUTPUT]
        Name  cloudwatch_logs
        Match *
        region us-east-1
        log_group_name /aws/eks/my-cluster/logs
        auto_create_group true
```

---

## ストレージ

### EBS CSI Driver

Elastic Block Storeを永続ボリュームとして使用。

**インストール**:
```bash
# IAMロール作成
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster my-cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

# Helm Chartインストール
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.create=false \
  --set controller.serviceAccount.name=ebs-csi-controller-sa
```

**StorageClass**:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**PersistentVolumeClaim**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
    - name: app
      image: myapp:latest
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: app-pvc
```

### EFS CSI Driver

Elastic File Systemを共有ストレージとして使用。

**EFS作成**:
```bash
# EFSファイルシステム作成
aws efs create-file-system \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --encrypted \
  --tags Key=Name,Value=eks-efs

# Mount Targetを各サブネットに作成
aws efs create-mount-target \
  --file-system-id fs-xxxxx \
  --subnet-id subnet-xxxxx \
  --security-groups sg-xxxxx
```

**EFS CSI Driverインストール**:
```bash
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver
helm install aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
  --namespace kube-system
```

**StorageClass & PVC**:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxxx
  directoryPerms: "700"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
---
# 複数Podから同時アクセス可能
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-pod-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: shared-app
  template:
    metadata:
      labels:
        app: shared-app
    spec:
      containers:
        - name: app
          image: nginx
          volumeMounts:
            - name: shared-storage
              mountPath: /usr/share/nginx/html
      volumes:
        - name: shared-storage
          persistentVolumeClaim:
            claimName: efs-pvc
```

### ストレージ比較テーブル

| 項目 | EBS | EFS | FSx for Lustre |
|------|-----|-----|----------------|
| アクセスモード | ReadWriteOnce | ReadWriteMany | ReadWriteMany |
| パフォーマンス | 高 | 中 | 非常に高 |
| スループット | 1000 MB/s | 10 GB/s | 数百 GB/s |
| IOPS | 64,000 | 500,000+ | 数百万 |
| ユースケース | DB、アプリデータ | 共有ファイル | HPC、機械学習 |
| コスト | 中 | 高 | 最高 |

---

## HA/DR

### マルチAZ設計

可用性を高めるための基本設計。

**ノードの配置**:
```yaml
# eksctl設定
managedNodeGroups:
  - name: ng-multi-az
    instanceType: t3.medium
    desiredCapacity: 6
    minSize: 3
    maxSize: 9
    availabilityZones:
      - us-east-1a
      - us-east-1b
      - us-east-1c
```

**Pod配置の制御**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 6
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      affinity:
        # 異なるAZに分散
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - myapp
              topologyKey: topology.kubernetes.io/zone
      containers:
        - name: app
          image: myapp:latest
```

### PodDisruptionBudget

メンテナンス中の可用性を保証。

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2  # 最低2つのPodを維持
  selector:
    matchLabels:
      app: myapp
---
# または
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  maxUnavailable: 1  # 同時に1つまでダウン可
  selector:
    matchLabels:
      app: myapp
```

### バックアップ戦略（Velero）

クラスタ全体のバックアップとリストア。

**インストール**:
```bash
# Veleroインストール
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket my-velero-backup \
  --backup-location-config region=us-east-1 \
  --snapshot-location-config region=us-east-1 \
  --secret-file ./credentials-velero
```

**バックアップ作成**:
```bash
# 全クラスタのバックアップ
velero backup create full-backup

# 特定のNamespaceのみ
velero backup create ns-backup --include-namespaces production

# スケジュールバックアップ
velero schedule create daily-backup --schedule="0 2 * * *"
```

**リストア**:
```bash
# バックアップ一覧
velero backup get

# リストア
velero restore create --from-backup full-backup

# 特定のリソースのみ
velero restore create --from-backup full-backup \
  --include-resources deployments,services
```

---

## コスト最適化

### Spot Instances

最大90%のコスト削減。

**Managed Node GroupでSpot使用**:
```yaml
# eksctl設定
managedNodeGroups:
  - name: spot-ng
    instanceTypes:
      - t3.medium
      - t3a.medium
      - t2.medium
    spot: true
    desiredCapacity: 3
    minSize: 2
    maxSize: 10
    labels:
      lifecycle: Ec2Spot
    taints:
      - key: spot
        value: "true"
        effect: NoSchedule
```

**Spot対応のPod設定**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-job
spec:
  replicas: 5
  selector:
    matchLabels:
      app: batch
  template:
    metadata:
      labels:
        app: batch
    spec:
      nodeSelector:
        lifecycle: Ec2Spot
      tolerations:
        - key: spot
          operator: Equal
          value: "true"
          effect: NoSchedule
      containers:
        - name: batch
          image: batch-processor:latest
```

### Karpenter

動的なノードプロビジョニングでコスト最適化。

**Provisioner（コスト重視）**:
```yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: cost-optimized
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["spot", "on-demand"]
    - key: node.kubernetes.io/instance-type
      operator: In
      values: ["t3.medium", "t3a.medium", "t3.large", "t3a.large"]

  # コスト重視の設定
  weight: 100
  provider:
    instanceProfile: KarpenterNodeInstanceProfile
    # Spot優先
    subnetSelector:
      karpenter.sh/discovery: my-cluster
    securityGroupSelector:
      karpenter.sh/discovery: my-cluster

  # 未使用ノードを迅速に削除
  ttlSecondsAfterEmpty: 30
  ttlSecondsUntilExpired: 604800 # 7日
```

### Rightsizing

適切なリソース設定。

**Vertical Pod Autoscaler (VPA)**:
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: myapp
  updatePolicy:
    updateMode: "Auto"  # 自動でリソース調整
  resourcePolicy:
    containerPolicies:
      - containerName: app
        minAllowed:
          cpu: 100m
          memory: 128Mi
        maxAllowed:
          cpu: 2
          memory: 2Gi
```

**コスト可視化（Kubecost）**:
```bash
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  --create-namespace \
  --set kubecostToken="<your-token>"
```

### Cluster Autoscaler vs Karpenter

| 項目 | Cluster Autoscaler | Karpenter |
|------|-------------------|-----------|
| スケール速度 | 遅い（数分） | 速い（数秒） |
| インスタンスタイプ | 固定 | 動的選択 |
| コスト最適化 | 限定的 | 高度 |
| Spot統合 | 基本的 | ネイティブ |
| 設定複雑度 | 高 | 低 |
| 推奨ユースケース | シンプルな環境 | コスト重視・複雑な要件 |

---

## パフォーマンス

### Horizontal Pod Autoscaler (HPA)

負荷に応じてPod数を自動調整。

**メトリクスサーバーインストール**:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**HPA設定**:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 15
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
        - type: Pods
          value: 4
          periodSeconds: 15
      selectPolicy: Max
```

### リソースリクエスト/リミット設計

**適切な設定**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: app
          image: myapp:latest
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi
```

**リソース設定の原則**:
- **Request**: 最低限必要なリソース（スケジューリングの基準）
- **Limit**: 使用可能な最大リソース（超過するとスロットリング）
- **CPU**: 圧縮可能リソース（超過するとスロットリング）
- **Memory**: 非圧縮可能リソース（超過するとOOM Kill）

**推奨設定パターン**:

| ワークロード | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-------------|-------------|-----------|----------------|--------------|
| Web API | 250m | 1000m | 256Mi | 512Mi |
| バッチ処理 | 500m | 2000m | 512Mi | 2Gi |
| データベース | 1000m | 4000m | 2Gi | 4Gi |
| フロントエンド | 100m | 500m | 128Mi | 256Mi |

### Node Affinity

Podを特定のノードに配置。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compute-intensive-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: compute-app
  template:
    metadata:
      labels:
        app: compute-app
    spec:
      affinity:
        nodeAffinity:
          # 必須条件
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node.kubernetes.io/instance-type
                    operator: In
                    values:
                      - c5.2xlarge
                      - c5.4xlarge
          # 優先条件
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: topology.kubernetes.io/zone
                    operator: In
                    values:
                      - us-east-1a
      containers:
        - name: app
          image: compute-app:latest
```

**Pod Anti-Affinity（分散配置）**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ha-app
spec:
  replicas: 6
  selector:
    matchLabels:
      app: ha-app
  template:
    metadata:
      labels:
        app: ha-app
    spec:
      affinity:
        podAntiAffinity:
          # 必須: 同じノードに配置しない
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - ha-app
              topologyKey: kubernetes.io/hostname
          # 優先: 異なるAZに配置
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - ha-app
                topologyKey: topology.kubernetes.io/zone
      containers:
        - name: app
          image: ha-app:latest
```
