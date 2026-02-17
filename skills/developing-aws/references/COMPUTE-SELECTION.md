# AWSコンピュートサービス選定ガイド

AWSのコンピュートサービスを適切に選定し、効率的なアプリケーション実行環境を構築するための実践的なガイドです。

---

## 1. コンテナ化の基礎

### 1.1 コンテナとは

**概要**:
アプリケーションとその依存関係を1つのパッケージにまとめた軽量な実行環境。

**仮想マシンとの比較**:

| 特性 | 仮想マシン (VM) | コンテナ |
|------|---------------|---------|
| **起動時間** | 数分 | 数秒 |
| **リソース効率** | 低 (ゲストOSのオーバーヘッド) | 高 (ホストOSカーネル共有) |
| **分離レベル** | 完全分離 | プロセスレベル分離 |
| **ポータビリティ** | 中 (ハイパーバイザー依存) | 高 (Docker Engineがあればどこでも実行可能) |
| **イメージサイズ** | GB単位 | MB単位 |

### 1.2 Docker の基本概念

**主要コンポーネント**:

| コンポーネント | 説明 | 例 |
|-------------|------|---|
| **Dockerfile** | コンテナイメージのビルド手順を定義 | `FROM node:18 \n COPY . /app \n CMD ["node", "server.js"]` |
| **イメージ** | 実行可能なパッケージ (読み取り専用) | `nginx:latest`, `node:18-alpine` |
| **コンテナ** | イメージの実行インスタンス | `docker run -p 80:80 nginx` |
| **レジストリ** | イメージの保存場所 | Docker Hub, Amazon ECR |

**Dockerfile例**:

```dockerfile
# ベースイメージ
FROM node:18-alpine

# 作業ディレクトリ設定
WORKDIR /app

# 依存関係ファイルをコピー
COPY package*.json ./

# 依存関係インストール
RUN npm ci --only=production

# アプリケーションコードをコピー
COPY . .

# ポート公開
EXPOSE 3000

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s \
  CMD node healthcheck.js

# 起動コマンド
CMD ["node", "server.js"]
```

### 1.3 Kubernetes の基本概念

**主要コンポーネント**:

```
Kubernetes クラスター
├── コントロールプレーン
│   ├── API Server (すべての操作のエントリポイント)
│   ├── Scheduler (Podの配置先決定)
│   ├── Controller Manager (リソース状態管理)
│   └── etcd (クラスター設定データストア)
└── ワーカーノード
    ├── kubelet (コンテナ実行管理)
    ├── kube-proxy (ネットワークルール管理)
    └── Container Runtime (Docker, containerd)
```

**主要リソース**:

| リソース | 説明 | 用途 |
|---------|------|------|
| **Pod** | 1つ以上のコンテナの集合 (最小デプロイ単位) | アプリケーション実行 |
| **Deployment** | Podのレプリカセット管理、ローリングアップデート | ステートレスアプリ |
| **Service** | Podへの安定したネットワークエンドポイント提供 | ロードバランシング、サービスディスカバリ |
| **ConfigMap** | 設定データの外部化 | 環境変数、設定ファイル |
| **Secret** | 機密情報の外部化 | パスワード、APIキー、証明書 |
| **Ingress** | HTTP(S)ルーティング | 外部からのアクセス制御 |

---

## 2. Amazon EC2 (Elastic Compute Cloud)

### 2.1 インスタンスタイプの選定

**ファミリー別分類**:

| ファミリー | 最適化 | vCPU:メモリ比 | ユースケース |
|----------|-------|-------------|-------------|
| **T3/T4g** | バーストパフォーマンス | 1:2〜1:4 | 開発環境、低トラフィックWebサーバー |
| **M5/M6i** | 汎用バランス | 1:4 | 中規模アプリケーション、マイクロサービス |
| **C5/C6i** | コンピュート最適化 | 1:2 | バッチ処理、動画エンコーディング、機械学習推論 |
| **R5/R6i** | メモリ最適化 | 1:8 | インメモリデータベース、ビッグデータ分析 |
| **X1/X2** | メモリ最適化 (超大容量) | 1:16〜1:31 | SAP HANA、大規模インメモリDB |
| **P3/P4** | GPU最適化 | - | 機械学習トレーニング、HPC |
| **I3/I4i** | ストレージ最適化 | - | NoSQL DB、データウェアハウス、検索エンジン |

**選定フローチャート**:

```
ワークロード特性は？
├─ CPU集約的
│   ├─ 一定負荷 → C5/C6i
│   └─ バースト → T3/T4g
├─ メモリ集約的
│   ├─ 中規模 (〜512GB) → R5/R6i
│   └─ 大規模 (>512GB) → X1/X2
├─ GPU必要 → P3/P4
├─ 高IOPS必要 → I3/I4i
└─ 汎用バランス → M5/M6i
```

### 2.2 AMI (Amazon Machine Image)

**AMIタイプ**:

| タイプ | 説明 | ユースケース |
|-------|------|-------------|
| **Amazon Linux 2023** | AWS最適化Linux | 汎用、最新機能 |
| **Ubuntu** | 人気のDebianベースディストリビューション | 開発、コミュニティサポート重視 |
| **Red Hat Enterprise Linux** | エンタープライズ向け商用Linux | エンタープライズアプリケーション |
| **Windows Server** | Microsoftワークロード | .NETアプリ、Active Directory |
| **カスタムAMI** | 独自設定を含むイメージ | 標準化された環境の迅速なデプロイ |

**コード例 - EC2 インスタンス起動 (AWS CLI)**:

```bash
# キーペア作成
aws ec2 create-key-pair \
    --key-name my-key \
    --query 'KeyMaterial' \
    --output text > my-key.pem
chmod 400 my-key.pem

# セキュリティグループ作成
aws ec2 create-security-group \
    --group-name my-sg \
    --description "My security group" \
    --vpc-id vpc-12345678

# SSHアクセス許可
aws ec2 authorize-security-group-ingress \
    --group-id sg-12345678 \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

# EC2インスタンス起動
aws ec2 run-instances \
    --image-id ami-0c55b159cbfafe1f0 \
    --count 1 \
    --instance-type t3.micro \
    --key-name my-key \
    --security-group-ids sg-12345678 \
    --subnet-id subnet-12345678 \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=my-server}]' \
    --user-data file://user-data.sh
```

**ユーザーデータスクリプト例** (`user-data.sh`):

```bash
#!/bin/bash
# 初回起動時に実行されるスクリプト

# システムアップデート
yum update -y

# Webサーバーインストール
yum install -y httpd

# 自動起動設定
systemctl start httpd
systemctl enable httpd

# サンプルページ作成
echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
```

### 2.3 Auto Scaling

**コンポーネント**:

| コンポーネント | 説明 | 設定例 |
|-------------|------|-------|
| **起動テンプレート** | インスタンスの設定 (AMI, インスタンスタイプ等) | t3.micro, Amazon Linux 2023 |
| **Auto Scaling グループ** | インスタンス数の管理 | 最小2, 希望2, 最大10 |
| **スケーリングポリシー** | スケールイン/アウトのトリガー | CPU使用率 > 70% で +1, < 30% で -1 |

**スケーリングポリシータイプ**:

| タイプ | 説明 | ユースケース |
|-------|------|-------------|
| **Target Tracking** | 目標メトリクス値を維持 | CPU使用率を70%に保つ |
| **Step Scaling** | メトリクス閾値に応じて段階的にスケール | 軽度な負荷 +1, 重度な負荷 +3 |
| **Simple Scaling** | 単一アクションでスケール | アラーム発火時に +1 (レガシー、非推奨) |
| **Scheduled Scaling** | 時刻ベースのスケール | 平日9-18時は最小5、それ以外は最小2 |

**コード例 - Auto Scaling 設定 (AWS CLI)**:

```bash
# 起動テンプレート作成
aws ec2 create-launch-template \
    --launch-template-name my-template \
    --version-description "v1" \
    --launch-template-data '{
        "ImageId": "ami-0c55b159cbfafe1f0",
        "InstanceType": "t3.micro",
        "KeyName": "my-key",
        "SecurityGroupIds": ["sg-12345678"],
        "UserData": "'"$(base64 user-data.sh)"'"
    }'

# Auto Scaling グループ作成
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name my-asg \
    --launch-template LaunchTemplateName=my-template,Version='$Latest' \
    --min-size 2 \
    --max-size 10 \
    --desired-capacity 2 \
    --vpc-zone-identifier "subnet-12345678,subnet-87654321" \
    --target-group-arns arn:aws:elasticloadbalancing:... \
    --health-check-type ELB \
    --health-check-grace-period 300

# Target Tracking スケーリングポリシー
aws autoscaling put-scaling-policy \
    --auto-scaling-group-name my-asg \
    --policy-name cpu-target-tracking \
    --policy-type TargetTrackingScaling \
    --target-tracking-configuration '{
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ASGAverageCPUUtilization"
        },
        "TargetValue": 70.0
    }'
```

---

## 3. AWS Lambda

### 3.1 概要

**AWS Lambda**は、サーバーレスコンピュートサービス。インフラ管理不要でコードを実行可能。

**主要特徴**:
- イベント駆動実行
- 自動スケーリング
- ミリ秒単位の課金
- 多言語サポート (Python, Node.js, Java, Go, Ruby, .NET, カスタムランタイム)

### 3.2 Lambda 実行環境

**実行モデル**:

```
リクエスト → イベントソース → Lambda関数 → 実行環境
                                    ├── コールドスタート (初回)
                                    │   ├── 実行環境初期化 (数百ms〜数秒)
                                    │   ├── ランタイム起動
                                    │   └── 関数コード初期化
                                    └── ウォームスタート (2回目以降)
                                        └── 既存実行環境を再利用 (数ms)
```

**コールドスタート最適化**:

| 手法 | 説明 | 効果 |
|------|------|------|
| **Provisioned Concurrency** | 事前にウォーム状態の実行環境を確保 | コールドスタート完全回避 (コスト増) |
| **小さなデプロイパッケージ** | 依存関係を最小化 | 初期化時間短縮 |
| **Lambda Layers** | 共通ライブラリを分離 | デプロイパッケージサイズ削減 |
| **SnapStart** (Java限定) | JVM初期化スナップショット | Java起動時間を最大90%削減 |

### 3.3 Lambda 関数の設定

**主要設定**:

| 設定 | 説明 | 推奨値 |
|------|------|-------|
| **メモリ** | 128MB〜10,240MB (64MB刻み) | パフォーマンステストで最適値を決定 |
| **タイムアウト** | 最大15分 | 長時間処理はStep Functions検討 |
| **同時実行数** | アカウントレベルで1,000 (デフォルト) | 予約同時実行数で制限可能 |
| **環境変数** | 設定情報の外部化 | 機密情報はSecrets Manager/Parameter Store使用 |

**コード例 - Lambda 関数作成とデプロイ (AWS CLI)**:

```bash
# Lambda実行ロール作成
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
    --role-name lambda-execution-role \
    --assume-role-policy-document file://trust-policy.json

# 基本実行ポリシーをアタッチ
aws iam attach-role-policy \
    --role-name lambda-execution-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Lambda関数コード (index.py)
cat > index.py <<EOF
import json

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    # イベントからパラメータ取得
    name = event.get('name', 'World')

    # レスポンス返却
    return {
        'statusCode': 200,
        'body': json.dumps({'message': f'Hello, {name}!'})
    }
EOF

# デプロイパッケージ作成
zip function.zip index.py

# Lambda関数作成
aws lambda create-function \
    --function-name my-function \
    --runtime python3.11 \
    --role arn:aws:iam::123456789012:role/lambda-execution-role \
    --handler index.lambda_handler \
    --zip-file fileb://function.zip \
    --timeout 30 \
    --memory-size 256 \
    --environment Variables="{ENV=production,DEBUG=false}"

# 関数呼び出しテスト
aws lambda invoke \
    --function-name my-function \
    --payload '{"name": "Alice"}' \
    response.json

cat response.json
```

**コード例 - Lambda 関数 (Python SDK)**:

```python
import boto3
import json

lambda_client = boto3.client('lambda')

# Lambda関数を同期的に呼び出し
response = lambda_client.invoke(
    FunctionName='my-function',
    InvocationType='RequestResponse',  # 同期
    Payload=json.dumps({'name': 'Bob'})
)

result = json.loads(response['Payload'].read())
print(result)

# Lambda関数を非同期的に呼び出し
response = lambda_client.invoke(
    FunctionName='my-function',
    InvocationType='Event',  # 非同期
    Payload=json.dumps({'name': 'Charlie'})
)

# Lambda関数更新
with open('function.zip', 'rb') as f:
    lambda_client.update_function_code(
        FunctionName='my-function',
        ZipFile=f.read()
    )
```

---

## 4. Amazon ECS (Elastic Container Service)

### 4.1 概要

**Amazon ECS**は、Dockerコンテナのオーケストレーションサービス。

**主要コンポーネント**:

| コンポーネント | 説明 |
|-------------|------|
| **クラスター** | コンテナインスタンスの論理グループ |
| **タスク定義** | コンテナイメージ、CPU、メモリ、ネットワーク設定 |
| **タスク** | タスク定義のインスタンス (1つ以上のコンテナ) |
| **サービス** | 指定数のタスクを維持、ロードバランサー統合 |

### 4.2 起動タイプ: EC2 vs Fargate

| 特性 | EC2起動タイプ | Fargate起動タイプ |
|------|-------------|-----------------|
| **インフラ管理** | ユーザーがEC2インスタンス管理 | AWSが完全管理 (サーバーレス) |
| **柔軟性** | 高 (インスタンスタイプ、OS選択可能) | 中 (vCPU/メモリの組み合わせのみ) |
| **コスト** | 予約インスタンスで削減可能 | オンデマンド課金 (一般的に割高) |
| **スケーリング** | Auto Scaling Group | 自動 (タスク単位) |
| **セキュリティ** | ユーザーがOS/ネットワーク管理 | AWSが管理、タスクレベル分離 |
| **ユースケース** | 長時間稼働、コスト最適化重視 | 短期バースト、運用簡素化重視 |

### 4.3 タスク定義

**タスク定義JSON例**:

```json
{
  "family": "my-app",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "app",
      "image": "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-app:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "NODE_ENV", "value": "production"}
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:db-password"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/my-app",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

**コード例 - ECS サービス作成 (AWS CLI)**:

```bash
# ECRリポジトリ作成
aws ecr create-repository --repository-name my-app

# Dockerイメージビルド&プッシュ
aws ecr get-login-password | docker login --username AWS --password-stdin 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com
docker build -t my-app .
docker tag my-app:latest 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-app:latest
docker push 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-app:latest

# ECSクラスター作成
aws ecs create-cluster --cluster-name my-cluster

# タスク定義登録
aws ecs register-task-definition --cli-input-json file://task-definition.json

# ECSサービス作成 (Fargate + ALB統合)
aws ecs create-service \
    --cluster my-cluster \
    --service-name my-service \
    --task-definition my-app:1 \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-12345678,subnet-87654321],securityGroups=[sg-12345678],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=app,containerPort=3000"
```

---

## 5. Amazon EKS (Elastic Kubernetes Service)

### 5.1 概要

**Amazon EKS**は、マネージド型Kubernetesサービス。

**主要特徴**:
- コントロールプレーンをAWSが管理
- 複数AZに分散した高可用性
- IAM統合 (RBAC)
- AWS サービス統合 (ELB, EBS, EFS, ECR)

### 5.2 ノードタイプ

| タイプ | 説明 | ユースケース | 管理 |
|-------|------|-------------|------|
| **マネージドノードグループ** | AWSが自動でEC2インスタンスをプロビジョニング | 標準的なワークロード | AWS + ユーザー |
| **セルフマネージドノード** | ユーザーが手動でEC2インスタンスを作成 | カスタム要件 | ユーザー |
| **Fargate** | サーバーレス (ノード管理不要) | バースト、隔離要件 | AWS |

### 5.3 EKS クラスター作成

**前提条件**:
- IAMロール (EKSクラスターロール、ノードグループロール)
- VPC、サブネット (最低2つのAZ)

**コード例 - EKS クラスター作成 (eksctl)**:

```bash
# eksctlインストール (Linux/Mac)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# EKSクラスター作成 (eksctl推奨)
eksctl create cluster \
    --name my-cluster \
    --region ap-northeast-1 \
    --nodegroup-name standard-workers \
    --node-type t3.medium \
    --nodes 3 \
    --nodes-min 1 \
    --nodes-max 4 \
    --managed

# kubectlでクラスター接続確認
kubectl get nodes
```

**Kubernetes Deployment例** (`deployment.yaml`):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    app: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-app:latest
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
```

**デプロイ実行**:

```bash
kubectl apply -f deployment.yaml
kubectl get pods
kubectl get svc my-app-service
```

---

## 6. コンピュートサービス選定決定木

```
ワークロード特性は？
├─ コンテナ化済み
│   ├─ Kubernetesが必要
│   │   ├─ 既存K8s資産あり → Amazon EKS
│   │   └─ K8s学習コスト許容 → Amazon EKS
│   ├─ Kubernetesは不要
│   │   ├─ インフラ管理したい → ECS (EC2起動タイプ)
│   │   └─ 完全サーバーレス希望 → ECS (Fargate) or AWS Fargate
│   └─ 短期バーストワークロード → ECS Fargate / EKS Fargate
├─ イベント駆動・短時間実行 (< 15分)
│   └─ AWS Lambda
├─ 長時間実行・カスタムOS/ソフトウェア必要
│   ├─ スケーリング自動化必要 → EC2 Auto Scaling
│   └─ 固定台数 → EC2 (予約インスタンス)
└─ バッチ処理
    ├─ ジョブキュー・依存関係管理必要 → AWS Batch
    └─ 単純実行 → Lambda or EC2
```

---

## 7. コスト最適化戦略

### 7.1 EC2 料金モデル

| モデル | 割引率 | コミットメント | ユースケース |
|-------|-------|-------------|-------------|
| **オンデマンド** | なし | なし | 短期、予測不可能 |
| **リザーブドインスタンス** | 〜72% | 1年 or 3年 | 定常ワークロード |
| **Savings Plans** | 〜72% | 1年 or 3年 (コンピュート使用量) | 柔軟性重視 |
| **スポットインスタンス** | 〜90% | なし (中断リスクあり) | フォールトトレラント、バッチ処理 |

### 7.2 Lambda 料金最適化

**最適化ポイント**:
- メモリ設定: CPU性能もメモリに比例。実行時間とのトレードオフを測定
- 実行時間短縮: 不要な処理削除、非同期処理活用
- Provisioned Concurrency: コールドスタート回避が必要な場合のみ使用 (コスト増)

---

## まとめ

AWSコンピュートサービスの選定では、以下の要素を総合的に評価します:

1. **ワークロード特性**: イベント駆動 vs 長時間実行、ステートレス vs ステートフル
2. **コンテナ化**: Docker化済み、Kubernetes必要性
3. **管理負荷**: マネージド vs 自己管理
4. **スケーラビリティ**: 自動スケーリング要件
5. **コスト**: 実行時間、リソース使用率、予測可能性
6. **パフォーマンス**: レイテンシ、コールドスタート許容度

一般的なベストプラクティスとして、新規アプリケーションではLambdaやFargateなどのサーバーレスオプションを優先的に検討し、長時間実行やカスタム要件がある場合にEC2/EKS/ECSを選択することが推奨されます。
