# EKS FUNDAMENTALS

Amazon Elastic Kubernetes Service (EKS)の基礎知識と環境構築、クラスタ運用の実践ガイド。

## EKS概要

### マネージドコントロールプレーン

EKSはKubernetesコントロールプレーンを完全マネージドで提供:

**AWSが管理する要素**:
- **API Server**: Kubernetes APIへのエントリーポイント
- **etcd**: クラスタ状態を保存する分散KVストア
- **Controller Manager**: ReplicaSet、Deployment等のコントローラー実行
- **Scheduler**: Podを適切なノードに配置

**ユーザーが管理する要素**:
- **ワーカーノード**: EC2インスタンスまたはFargate
- **アプリケーションワークロード**: Pod、Service、Ingress等

**コントロールプレーンの特徴**:
- マルチAZ配置（3つのAZで冗長化）
- 自動スケーリングとパッチ適用
- SLA 99.95%の可用性保証
- AWS PrivateLinkによるプライベート接続

### ノードグループのタイプ

| タイプ | 概要 | ユースケース | 管理レベル |
|--------|------|--------------|-----------|
| **Managed Node Groups** | AWSが完全管理 | 標準的なワークロード | 低 |
| **Self-managed Nodes** | ユーザーがEC2管理 | カスタマイズが必要 | 高 |
| **AWS Fargate** | サーバーレスコンテナ | バッチ処理・短期タスク | 最低 |

**Managed Node Groups**:
```bash
# eksctlで作成
eksctl create nodegroup \
  --cluster=my-cluster \
  --name=managed-ng \
  --node-type=t3.medium \
  --nodes=3 \
  --nodes-min=2 \
  --nodes-max=5 \
  --managed
```

**Self-managed Nodes**:
```bash
# Launch Templateを使用
aws ec2 create-launch-template \
  --launch-template-name eks-node-template \
  --launch-template-data '{
    "ImageId": "ami-xxxxx",
    "InstanceType": "t3.medium",
    "UserData": "<base64-encoded-bootstrap-script>"
  }'

# Auto Scaling Groupで管理
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name eks-nodes \
  --launch-template LaunchTemplateName=eks-node-template \
  --min-size 2 \
  --max-size 5 \
  --desired-capacity 3
```

**AWS Fargate**:
```yaml
# Fargate Profile定義
apiVersion: v1
kind: FargateProfile
metadata:
  name: my-fargate-profile
spec:
  clusterName: my-cluster
  podExecutionRoleArn: arn:aws:iam::123456789012:role/EKSFargatePodExecutionRole
  selectors:
    - namespace: production
      labels:
        app: web
```

### ノードグループ比較テーブル

| 項目 | Managed | Self-managed | Fargate |
|------|---------|--------------|---------|
| 初期設定 | 簡単 | 複雑 | 最も簡単 |
| カスタマイズ性 | 中 | 高 | 低 |
| アップグレード | 自動 | 手動 | 自動 |
| コスト | 標準 | 最安 | 最高 |
| 起動時間 | 分単位 | 分単位 | 秒単位 |
| GPU対応 | ✅ | ✅ | ❌ |
| DaemonSet | ✅ | ✅ | ❌ |

---

## 環境構築

### 前提条件

**必要なツール**:
- AWS CLI v2.x以降
- kubectl 1.28以降
- eksctl 0.150以降
- Docker（コンテナビルド用）

**IAM権限**:
- `eks:*`
- `ec2:*`（VPC、Security Group作成）
- `iam:CreateRole`、`iam:AttachRolePolicy`
- `cloudformation:*`（eksctl使用時）

### eksctlによるクラスタ作成

**基本的なクラスタ**:
```bash
eksctl create cluster \
  --name my-cluster \
  --region us-east-1 \
  --version 1.28 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --managed
```

**YAML設定ファイルを使用**:
```yaml
# cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: my-cluster
  region: us-east-1
  version: "1.28"

# VPC設定
vpc:
  cidr: 10.0.0.0/16
  nat:
    gateway: Single # HighlyAvailable, Single, Disable

# Managed Node Groups
managedNodeGroups:
  - name: ng-1
    instanceType: t3.medium
    desiredCapacity: 3
    minSize: 2
    maxSize: 5
    volumeSize: 80
    ssh:
      allow: true
      publicKeyName: my-key
    labels:
      role: worker
    tags:
      Environment: dev
    iam:
      withAddonPolicies:
        imageBuilder: true
        autoScaler: true
        ebs: true
        efs: true
        albIngress: true
        cloudWatch: true

# Fargate Profiles
fargateProfiles:
  - name: fp-default
    selectors:
      - namespace: default
      - namespace: kube-system

# Add-ons
addons:
  - name: vpc-cni
    version: latest
  - name: coredns
    version: latest
  - name: kube-proxy
    version: latest
```

```bash
eksctl create cluster -f cluster.yaml
```

### AWS CLIによるクラスタ作成

**Step 1: Cluster Role作成**:
```bash
aws iam create-role \
  --role-name EKSClusterRole \
  --assume-role-policy-document file://eks-cluster-trust-policy.json

aws iam attach-role-policy \
  --role-name EKSClusterRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

**Step 2: VPC作成**:
```bash
aws cloudformation create-stack \
  --stack-name eks-vpc \
  --template-url https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-private-subnets.yaml
```

**Step 3: クラスタ作成**:
```bash
aws eks create-cluster \
  --name my-cluster \
  --role-arn arn:aws:iam::123456789012:role/EKSClusterRole \
  --resources-vpc-config subnetIds=subnet-xxx,subnet-yyy,securityGroupIds=sg-xxx \
  --kubernetes-version 1.28
```

**Step 4: kubeconfig更新**:
```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name my-cluster
```

### CDKによるクラスタ作成

```typescript
import * as eks from 'aws-cdk-lib/aws-eks';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';

export class EksStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // VPC
    const vpc = new ec2.Vpc(this, 'EksVpc', {
      maxAzs: 2,
      natGateways: 1
    });

    // EKSクラスタ
    const cluster = new eks.Cluster(this, 'Cluster', {
      version: eks.KubernetesVersion.V1_28,
      vpc: vpc,
      defaultCapacity: 0, // Managed Node Groupを手動で追加
      clusterLogging: [
        eks.ClusterLoggingTypes.API,
        eks.ClusterLoggingTypes.AUDIT,
        eks.ClusterLoggingTypes.AUTHENTICATOR
      ]
    });

    // Managed Node Group
    cluster.addNodegroupCapacity('ManagedNodeGroup', {
      instanceTypes: [new ec2.InstanceType('t3.medium')],
      minSize: 2,
      maxSize: 5,
      desiredSize: 3,
      diskSize: 100,
      labels: {
        role: 'worker'
      },
      tags: {
        Environment: 'dev'
      }
    });

    // Fargate Profile
    cluster.addFargateProfile('FargateProfile', {
      selectors: [
        { namespace: 'default' },
        { namespace: 'production' }
      ]
    });

    // Output
    new cdk.CfnOutput(this, 'ClusterEndpoint', {
      value: cluster.clusterEndpoint
    });

    new cdk.CfnOutput(this, 'ClusterName', {
      value: cluster.clusterName
    });
  }
}
```

---

## Kubernetes基礎

### Pod

最小のデプロイ単位。1つ以上のコンテナをグループ化。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: nginx:1.21
      ports:
        - containerPort: 80
      resources:
        requests:
          memory: "64Mi"
          cpu: "250m"
        limits:
          memory: "128Mi"
          cpu: "500m"
      livenessProbe:
        httpGet:
          path: /healthz
          port: 80
        initialDelaySeconds: 30
        periodSeconds: 10
      readinessProbe:
        httpGet:
          path: /ready
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 5
```

**マルチコンテナPod**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
    - name: app
      image: myapp:latest
      ports:
        - containerPort: 8080
    - name: sidecar-logger
      image: busybox
      command: ['sh', '-c', 'tail -f /var/log/app.log']
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log
  volumes:
    - name: shared-logs
      emptyDir: {}
```

### Service

Podへの安定したネットワークアクセスを提供。

**ClusterIP（クラスタ内部のみ）**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

**NodePort（ノードのポート公開）**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080 # 30000-32767の範囲
```

**LoadBalancer（外部ロードバランサー）**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-loadbalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

### Deployment

Podのレプリカ管理とローリングアップデート。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.21
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "250m"
            limits:
              memory: "128Mi"
              cpu: "500m"
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # 同時に作成できる追加Pod数
      maxUnavailable: 0  # 更新中に利用不可にできるPod数
```

**デプロイコマンド**:
```bash
# 適用
kubectl apply -f deployment.yaml

# スケーリング
kubectl scale deployment/nginx-deployment --replicas=5

# イメージ更新
kubectl set image deployment/nginx-deployment nginx=nginx:1.22

# ロールバック
kubectl rollout undo deployment/nginx-deployment

# ステータス確認
kubectl rollout status deployment/nginx-deployment

# 履歴確認
kubectl rollout history deployment/nginx-deployment
```

### StatefulSet

ステートフルなアプリケーション（データベース等）の管理。

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          ports:
            - containerPort: 3306
              name: mysql
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: password
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: gp3
        resources:
          requests:
            storage: 20Gi
```

**特徴**:
- 安定したネットワークID（`mysql-0`, `mysql-1`, `mysql-2`）
- 安定したストレージ（PersistentVolumeClaim）
- 順序付きデプロイとスケーリング
- 順序付き削除

### DaemonSet

全ノード（または特定ノード）で必ず1つのPodを実行。

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: fluentd
  template:
    metadata:
      labels:
        name: fluentd
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      containers:
        - name: fluentd
          image: fluent/fluentd:v1.15
          resources:
            limits:
              memory: 200Mi
            requests:
              cpu: 100m
              memory: 200Mi
          volumeMounts:
            - name: varlog
              mountPath: /var/log
      terminationGracePeriodSeconds: 30
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
```

**ユースケース**:
- ログ収集（Fluentd、Fluent Bit）
- 監視エージェント（Prometheus Node Exporter）
- ネットワークプラグイン（Calico、Cilium）

---

## コンテナ管理

### ECR（Elastic Container Registry）

プライベートDockerレジストリ。

**リポジトリ作成**:
```bash
aws ecr create-repository \
  --repository-name myapp \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256
```

**イメージプッシュ**:
```bash
# ECRにログイン
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

# イメージビルド
docker build -t myapp:latest .

# タグ付け
docker tag myapp:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:latest

# プッシュ
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:latest
```

**EKSからのプル**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:latest
          ports:
            - containerPort: 8080
```

### Dockerマルチステージビルド

イメージサイズを最小化:

```dockerfile
# Stage 1: Build
FROM node:18 AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

# Stage 2: Runtime
FROM node:18-alpine

WORKDIR /app

# ビルドステージから成果物のみコピー
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

# 非rootユーザーで実行
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

USER nodejs

EXPOSE 3000

CMD ["node", "dist/main.js"]
```

**Go言語の例**:
```dockerfile
# Stage 1: Build
FROM golang:1.21 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Stage 2: Runtime
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
```

---

## クラスタ運用

### ノードグループ管理

**Managed Node Groupの追加**:
```bash
eksctl create nodegroup \
  --cluster=my-cluster \
  --name=new-ng \
  --node-type=t3.large \
  --nodes=3 \
  --nodes-min=2 \
  --nodes-max=5 \
  --node-labels="workload=compute-intensive" \
  --node-taints="dedicated=compute:NoSchedule"
```

**ノードのドレイン（安全な退避）**:
```bash
# ノード上のPodを他ノードに移動
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force

# ノードを再度スケジュール可能にする
kubectl uncordon <node-name>
```

**ノードグループの削除**:
```bash
eksctl delete nodegroup \
  --cluster=my-cluster \
  --name=old-ng \
  --drain
```

### アップグレード戦略

**コントロールプレーンのアップグレード**:
```bash
# 現在のバージョン確認
aws eks describe-cluster --name my-cluster --query 'cluster.version'

# アップグレード
aws eks update-cluster-version \
  --name my-cluster \
  --kubernetes-version 1.28

# ステータス確認
aws eks describe-update \
  --name my-cluster \
  --update-id <update-id>
```

**ノードグループのアップグレード（Blue/Green方式）**:
```bash
# 新しいNode Groupを作成
eksctl create nodegroup \
  --cluster=my-cluster \
  --name=ng-1-28 \
  --node-ami-family=AmazonLinux2 \
  --kubernetes-version=1.28 \
  --nodes=3

# 古いNode Groupをドレイン
kubectl drain <old-node> --ignore-daemonsets --delete-emptydir-data

# 古いNode Groupを削除
eksctl delete nodegroup \
  --cluster=my-cluster \
  --name=ng-1-27
```

### Karpenter

ノードの自動プロビジョニングとスケーリング。Cluster Autoscalerより高速で柔軟。

**インストール**:
```bash
# Helm Chart追加
helm repo add karpenter https://charts.karpenter.sh
helm repo update

# Karpenterインストール
helm upgrade --install karpenter karpenter/karpenter \
  --namespace karpenter \
  --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::123456789012:role/KarpenterController \
  --set clusterName=my-cluster \
  --set clusterEndpoint=$(aws eks describe-cluster --name my-cluster --query "cluster.endpoint" --output text)
```

**Provisioner設定**:
```yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  # 要件に基づいてインスタンスタイプを自動選択
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["on-demand", "spot"]
    - key: node.kubernetes.io/instance-type
      operator: In
      values: ["t3.medium", "t3.large", "m5.large"]
    - key: topology.kubernetes.io/zone
      operator: In
      values: ["us-east-1a", "us-east-1b"]

  # リソース制限
  limits:
    resources:
      cpu: 1000
      memory: 1000Gi

  # プロバイダー設定
  provider:
    subnetSelector:
      karpenter.sh/discovery: my-cluster
    securityGroupSelector:
      karpenter.sh/discovery: my-cluster
    instanceProfile: KarpenterNodeInstanceProfile
    launchTemplate: my-launch-template

  # ノードの統合設定（未使用ノードを削除）
  ttlSecondsAfterEmpty: 30
  ttlSecondsUntilExpired: 2592000 # 30日
```

**Cluster Autoscaler vs Karpenter**:

| 項目 | Cluster Autoscaler | Karpenter |
|------|-------------------|-----------|
| スケールアップ速度 | 遅い（数分） | 速い（数秒） |
| インスタンスタイプ | 固定 | 動的選択 |
| Spot対応 | 限定的 | ネイティブサポート |
| 設定の複雑さ | 中 | 低 |
| ノードグループ依存 | 必要 | 不要 |

---

## ネットワーキング

### VPC CNIプラグイン

AWSネイティブなPodネットワーキング。Pod IP = ENI Secondary IP。

**VPC CNIの仕組み**:
- 各ノードに複数のENI（Elastic Network Interface）をアタッチ
- ENIのセカンダリIPアドレスをPodに割り当て
- PodはVPCのIPアドレスを直接使用

**VPC CNI設定**:
```yaml
# ConfigMap: aws-node
apiVersion: v1
kind: ConfigMap
metadata:
  name: amazon-vpc-cni
  namespace: kube-system
data:
  # Prefix Delegation（IPアドレス数を増やす）
  enable-prefix-delegation: "true"
  # ウォームプール設定
  warm-prefix-target: "1"
  # ネットワークポリシー対応
  enable-network-policy-controller: "true"
```

**IPアドレス管理**:
```bash
# ノードごとの最大Pod数
# t3.medium: 17 Pods
# t3.large: 35 Pods
# m5.large: 29 Pods

# ノードのENI数を確認
kubectl get nodes -o json | jq '.items[].status.allocatable."vpc.amazonaws.com/pod-eni"'
```

### Pod Networking

**Pod間通信**:
```yaml
# アプリケーションPod
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
    - name: app
      image: myapp:latest
      env:
        - name: DATABASE_URL
          value: "postgresql://db-service:5432/mydb"
---
# データベースService
apiVersion: v1
kind: Service
metadata:
  name: db-service
spec:
  selector:
    app: database
  ports:
    - protocol: TCP
      port: 5432
      targetPort: 5432
```

**Network Policy（トラフィック制御）**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

### Service Mesh（AWS App Mesh）

マイクロサービス間の通信管理。

**App Mesh Controller インストール**:
```bash
helm repo add eks https://aws.github.io/eks-charts
helm install appmesh-controller eks/appmesh-controller \
  --namespace appmesh-system \
  --set region=us-east-1 \
  --set serviceAccount.create=false \
  --set serviceAccount.name=appmesh-controller
```

**Mesh定義**:
```yaml
apiVersion: appmesh.k8s.aws/v1beta2
kind: Mesh
metadata:
  name: my-mesh
spec:
  namespaceSelector:
    matchLabels:
      mesh: my-mesh
  egressFilter:
    type: ALLOW_ALL
```

**Virtual Node定義**:
```yaml
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: backend
  namespace: production
spec:
  awsName: backend-vn
  podSelector:
    matchLabels:
      app: backend
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      healthCheck:
        protocol: http
        path: /healthz
        healthyThreshold: 2
        unhealthyThreshold: 3
        timeoutMillis: 2000
        intervalMillis: 5000
  serviceDiscovery:
    dns:
      hostname: backend.production.svc.cluster.local
```

### Ingress Controller

外部トラフィックをServiceにルーティング。

**AWS Load Balancer Controller インストール**:
```bash
# Helm Chart追加
helm repo add eks https://aws.github.io/eks-charts

# インストール
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=my-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

**ALB Ingress**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /healthz
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/xxxxx
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  ingressClassName: alb
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp-service
                port:
                  number: 80
```

**NLB Service**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nlb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

**ALB vs NLB 比較**:

| 項目 | ALB | NLB |
|------|-----|-----|
| レイヤー | L7（HTTP/HTTPS） | L4（TCP/UDP） |
| パフォーマンス | 中 | 高 |
| レイテンシ | ~ms | ~μs |
| 固定IP | ❌ | ✅ |
| WebSocket | ✅ | ✅ |
| gRPC | ✅ | ✅ |
| パスベースルーティング | ✅ | ❌ |
| コスト | 高 | 中 |
