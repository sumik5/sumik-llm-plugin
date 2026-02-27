# Cost Optimization on AWS

AWS上でのコスト最適化実践ガイド。コスト管理原則、EC2 rightsizing、購入モデル、ストレージコスト最適化、リソース弾力性、AWSコストツール、EKSコスト最適化、およびサーバーレスコストをカバーします。

---

## 1. コスト管理原則（FinOps）

### 1.1 Cloud Financial Management (CFM)

| 柱 | 説明 | 実践 |
|---|------|------|
| **See（可視化）** | コストを可視化して理解する | Cost Explorer、タグ付け、コスト配分 |
| **Save（節約）** | 無駄を削減して効率化 | Rightsizing、Reserved Instances、Spot |
| **Plan（計画）** | 将来のコストを予測・予算化 | Budgets、予測、ガバナンス |

### 1.2 コスト最適化フライホイール

```
1. 可視化（Cost Explorer）
   ↓
2. 分析（Cost Anomaly Detection）
   ↓
3. 最適化（Rightsizing / RI / Spot）
   ↓
4. 継続的改善（定期レビュー）
   ↓
（繰り返し）
```

### 1.3 責任共有モデル

| レイヤー | AWS責任 | 顧客責任 |
|---------|--------|---------|
| **インフラ** | データセンター効率化 | - |
| **プラットフォーム** | サービス価格設定 | サービス選択 |
| **アプリケーション** | - | アーキテクチャ設計、リソース使用 |

---

## 2. EC2 Rightsizing

### 2.1 Compute Optimizer

**推奨事項の取得:**

```bash
# Compute Optimizer推奨取得
aws compute-optimizer get-ec2-instance-recommendations \
  --instance-arns arn:aws:ec2:us-east-1:123456789012:instance/i-1234567890abcdef0

# 推奨サマリー
aws compute-optimizer get-recommendation-summaries \
  --resource-type Ec2Instance
```

**推奨例:**

```json
{
  "instanceRecommendations": [
    {
      "instanceArn": "arn:aws:ec2:us-east-1:123456789012:instance/i-1234567890abcdef0",
      "currentInstanceType": "m5.2xlarge",
      "finding": "Overprovisioned",
      "recommendationOptions": [
        {
          "instanceType": "m5.xlarge",
          "projectedUtilizationMetrics": [
            {
              "name": "CPU",
              "statistic": "MAXIMUM",
              "value": 42.5
            },
            {
              "name": "MEMORY",
              "statistic": "MAXIMUM",
              "value": 38.2
            }
          ],
          "performanceRisk": 1.0,
          "rank": 1,
          "savingsOpportunity": {
            "estimatedMonthlySavings": {
              "currency": "USD",
              "value": 120.50
            },
            "savingsOpportunityPercentage": 50.0
          }
        }
      ]
    }
  ]
}
```

### 2.2 インスタンスタイプ選定基準

| ワークロード | 推奨ファミリー | 理由 |
|------------|--------------|------|
| **汎用** | t3, t4g, m5, m6g, m7g | バランスの取れたリソース |
| **コンピューティング最適化** | c5, c6g, c7g | CPU集約的 |
| **メモリ最適化** | r5, r6g, x2gd | メモリ集約的 |
| **高速I/O** | i3, i4i | データベース、ストレージ |
| **GPU** | p3, p4, g4dn | ML推論、グラフィック処理 |
| **Arm (Graviton)** | t4g, m6g, c6g, r6g | コストパフォーマンス最高 |

**Graviton移行によるコスト削減:**

| インスタンスタイプ | x86 (Intel/AMD) | Graviton2 | コスト削減 |
|------------------|----------------|-----------|----------|
| 汎用 | m5.xlarge | m6g.xlarge | 20% |
| コンピューティング | c5.xlarge | c6g.xlarge | 20% |
| メモリ | r5.xlarge | r6g.xlarge | 20% |

### 2.3 自動Rightsizingスクリプト（Lambda）

```python
import boto3
from datetime import datetime, timedelta

cloudwatch = boto3.client('cloudwatch')
ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    """CPU使用率低いインスタンスを検出して推奨を生成"""
    instances = ec2.describe_instances(
        Filters=[
            {'Name': 'instance-state-name', 'Values': ['running']},
            {'Name': 'tag:Environment', 'Values': ['production']}
        ]
    )

    recommendations = []

    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            instance_type = instance['InstanceType']

            # 過去7日間のCPU使用率を取得
            cpu_stats = cloudwatch.get_metric_statistics(
                Namespace='AWS/EC2',
                MetricName='CPUUtilization',
                Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
                StartTime=datetime.utcnow() - timedelta(days=7),
                EndTime=datetime.utcnow(),
                Period=3600,
                Statistics=['Average', 'Maximum']
            )

            if not cpu_stats['Datapoints']:
                continue

            avg_cpu = sum(dp['Average'] for dp in cpu_stats['Datapoints']) / len(cpu_stats['Datapoints'])
            max_cpu = max(dp['Maximum'] for dp in cpu_stats['Datapoints'])

            # CPU使用率が平均20%未満、最大40%未満 → ダウンサイジング推奨
            if avg_cpu < 20 and max_cpu < 40:
                current_size = instance_type.split('.')[1]
                recommended_type = suggest_smaller_instance(instance_type)

                recommendations.append({
                    'instanceId': instance_id,
                    'currentType': instance_type,
                    'recommendedType': recommended_type,
                    'avgCPU': round(avg_cpu, 2),
                    'maxCPU': round(max_cpu, 2),
                    'estimatedSavings': calculate_savings(instance_type, recommended_type)
                })

    # SNS通知
    if recommendations:
        send_sns_notification(recommendations)

    return {'recommendations': recommendations}

def suggest_smaller_instance(instance_type):
    """1サイズ小さいインスタンスタイプを推奨"""
    family, size = instance_type.rsplit('.', 1)
    size_map = {
        '4xlarge': '2xlarge',
        '2xlarge': 'xlarge',
        'xlarge': 'large',
        'large': 'medium',
        'medium': 'small'
    }
    return f"{family}.{size_map.get(size, size)}"

def calculate_savings(current, recommended):
    """簡易的な節約額計算（実際はPricing APIを使用）"""
    # 仮の価格データ
    prices = {
        'm5.xlarge': 0.192,
        'm5.large': 0.096,
        'm5.2xlarge': 0.384
    }
    current_price = prices.get(current, 0)
    recommended_price = prices.get(recommended, 0)
    monthly_savings = (current_price - recommended_price) * 730
    return round(monthly_savings, 2)
```

---

## 3. 購入モデル

### 3.1 購入モデル比較

| モデル | 割引率 | コミットメント | 用途 | 柔軟性 |
|--------|-------|-------------|------|--------|
| **On-Demand** | 0% | なし | スパイク、短期、開発環境 | 最高 |
| **Savings Plans** | 最大72% | 1年 or 3年 | 安定したコンピューティング利用 | 高 |
| **Reserved Instances** | 最大75% | 1年 or 3年 | 特定インスタンスタイプの長期利用 | 中 |
| **Spot Instances** | 最大90% | なし（中断可能） | バッチ処理、ステートレスワークロード | 低 |

### 3.2 Savings Plans vs Reserved Instances

| 項目 | Savings Plans | Reserved Instances |
|------|--------------|-------------------|
| **適用範囲** | EC2、Lambda、Fargate | EC2のみ |
| **柔軟性** | インスタンスファミリー、サイズ、OS、リージョン変更可 | 固定（Convertibleは一部変更可） |
| **割引率** | 最大72% | 最大75% |
| **推奨** | ✅ 汎用的な利用に最適 | 特定構成の固定利用のみ |

**Savings Plans購入:**

```bash
# Compute Savings Plans購入推奨を取得
aws ce get-savings-plans-purchase-recommendation \
  --savings-plans-type COMPUTE_SP \
  --term-in-years ONE_YEAR \
  --payment-option NO_UPFRONT \
  --lookback-period-in-days SIXTY_DAYS

# Savings Plans購入
aws savingsplans create-savings-plan \
  --savings-plan-type COMPUTE_SP \
  --commitment 100 \
  --upfront-payment-amount 0 \
  --savings-plan-offering-id "offer-1234567890abcdef0"
```

### 3.3 Spot Instances活用

**Spot Fleet設定（CloudFormation）:**

```yaml
Resources:
  SpotFleet:
    Type: AWS::EC2::SpotFleet
    Properties:
      SpotFleetRequestConfigData:
        IamFleetRole: !GetAtt SpotFleetRole.Arn
        TargetCapacity: 10
        AllocationStrategy: lowestPrice
        InstanceInterruptionBehavior: terminate
        SpotPrice: '0.05'

        LaunchSpecifications:
          # 複数のインスタンスタイプを指定（可用性向上）
          - InstanceType: m5.large
            ImageId: ami-0abcdef1234567890
            KeyName: my-key
            SubnetId: !Ref Subnet1
            WeightedCapacity: 1

          - InstanceType: m5a.large
            ImageId: ami-0abcdef1234567890
            KeyName: my-key
            SubnetId: !Ref Subnet1
            WeightedCapacity: 1

          - InstanceType: m5n.large
            ImageId: ami-0abcdef1234567890
            KeyName: my-key
            SubnetId: !Ref Subnet1
            WeightedCapacity: 1
```

**Spot中断ハンドリング（Python）:**

```python
import boto3
import requests
from datetime import datetime

# Spotインスタンス中断通知をポーリング
def check_spot_termination():
    """EC2メタデータからSpot中断通知を確認"""
    try:
        response = requests.get(
            'http://169.254.169.254/latest/meta-data/spot/instance-action',
            timeout=1
        )

        if response.status_code == 200:
            action = response.json()
            print(f"⚠️ Spot中断通知: {action}")

            # 2分以内にグレースフルシャットダウン
            graceful_shutdown()
            return True

    except requests.exceptions.RequestException:
        # 通知なし（正常）
        pass

    return False

def graceful_shutdown():
    """グレースフルシャットダウン処理"""
    print("グレースフルシャットダウン開始")

    # 1. ロードバランサーから切り離し
    deregister_from_lb()

    # 2. 進行中の処理を完了
    wait_for_tasks_to_complete()

    # 3. ログをS3にフラッシュ
    flush_logs_to_s3()

    print("シャットダウン準備完了")
```

---

## 4. ストレージコスト最適化

### 4.1 S3ストレージクラス選定

| ストレージクラス | 用途 | コスト（GB/月） | 取り出し料金 | 最小保存期間 |
|----------------|------|---------------|------------|------------|
| **S3 Standard** | 頻繁アクセス | $0.023 | なし | なし |
| **S3 Intelligent-Tiering** | アクセスパターン不明 | $0.023 + モニタリング料金 | なし | なし |
| **S3 Standard-IA** | 低頻度アクセス | $0.0125 | $0.01/GB | 30日 |
| **S3 One Zone-IA** | 低頻度・単一AZ許容 | $0.01 | $0.01/GB | 30日 |
| **S3 Glacier Instant Retrieval** | アーカイブ・即座取り出し | $0.004 | $0.03/GB | 90日 |
| **S3 Glacier Flexible Retrieval** | アーカイブ・数分〜数時間 | $0.0036 | $0.01-0.03/GB | 90日 |
| **S3 Glacier Deep Archive** | 長期アーカイブ・12時間取り出し | $0.00099 | $0.02/GB | 180日 |

**ライフサイクルポリシー設定:**

```yaml
Resources:
  DataBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: my-data-bucket
      LifecycleConfiguration:
        Rules:
          # 30日後にStandard-IAへ
          - Id: MoveToIA
            Status: Enabled
            Transitions:
              - TransitionInDays: 30
                StorageClass: STANDARD_IA

          # 90日後にGlacier Flexible Retrievalへ
          - Id: MoveToGlacier
            Status: Enabled
            Transitions:
              - TransitionInDays: 90
                StorageClass: GLACIER

          # 365日後にDeep Archiveへ
          - Id: MoveToDeepArchive
            Status: Enabled
            Transitions:
              - TransitionInDays: 365
                StorageClass: DEEP_ARCHIVE

          # 7年後に削除
          - Id: DeleteOldData
            Status: Enabled
            ExpirationInDays: 2555

          # 不完全マルチパートアップロードを7日後に削除
          - Id: CleanupIncompleteUploads
            Status: Enabled
            AbortIncompleteMultipartUpload:
              DaysAfterInitiation: 7
```

### 4.2 EBS ボリュームタイプ選定

| ボリュームタイプ | 用途 | IOPS | スループット | コスト（GB/月） |
|----------------|------|------|-------------|---------------|
| **gp3** | 汎用SSD（推奨） | 3,000〜16,000 | 125〜1,000 MB/s | $0.08 |
| **gp2** | 汎用SSD（レガシー） | 3〜16,000 | 128〜250 MB/s | $0.10 |
| **io2** | プロビジョンドIOPS SSD | 100〜64,000 | 1,000 MB/s | $0.125 + IOPS料金 |
| **st1** | スループット最適化HDD | - | 500 MB/s | $0.045 |
| **sc1** | コールドHDD | - | 250 MB/s | $0.015 |

**gp2 → gp3 移行によるコスト削減:**

```bash
# gp2ボリューム検出
aws ec2 describe-volumes \
  --filters "Name=volume-type,Values=gp2" \
  --query "Volumes[*].[VolumeId,Size,VolumeType]" \
  --output table

# gp3へ変更
aws ec2 modify-volume \
  --volume-id vol-1234567890abcdef0 \
  --volume-type gp3 \
  --iops 3000 \
  --throughput 125
```

**コスト試算:**

```
gp2 (1TB):    $0.10/GB × 1000GB = $100/月
gp3 (1TB):    $0.08/GB × 1000GB = $80/月

削減額: $20/月（20%削減）
```

---

## 5. リソース弾力性（Elasticity）

### 5.1 Auto Scaling設定

```yaml
Resources:
  AutoScalingGroup:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      AutoScalingGroupName: my-asg
      MinSize: 2
      MaxSize: 10
      DesiredCapacity: 2
      HealthCheckType: ELB
      HealthCheckGracePeriod: 300
      VPCZoneIdentifier:
        - !Ref Subnet1
        - !Ref Subnet2
      TargetGroupARNs:
        - !Ref TargetGroup
      LaunchTemplate:
        LaunchTemplateId: !Ref LaunchTemplate
        Version: !GetAtt LaunchTemplate.LatestVersionNumber

  # CPU使用率ベースのスケーリング
  ScaleUpPolicy:
    Type: AWS::AutoScaling::ScalingPolicy
    Properties:
      AutoScalingGroupName: !Ref AutoScalingGroup
      PolicyType: TargetTrackingScaling
      TargetTrackingConfiguration:
        PredefinedMetricSpecification:
          PredefinedMetricType: ASGAverageCPUUtilization
        TargetValue: 70.0

  # スケジュールベースのスケーリング
  ScaleUpSchedule:
    Type: AWS::AutoScaling::ScheduledAction
    Properties:
      AutoScalingGroupName: !Ref AutoScalingGroup
      DesiredCapacity: 10
      MinSize: 5
      Recurrence: '0 8 * * MON-FRI'  # 平日午前8時にスケールアップ

  ScaleDownSchedule:
    Type: AWS::AutoScaling::ScheduledAction
    Properties:
      AutoScalingGroupName: !Ref AutoScalingGroup
      DesiredCapacity: 2
      MinSize: 2
      Recurrence: '0 18 * * *'  # 毎日午後6時にスケールダウン
```

### 5.2 Lambda Provisioned Concurrency vs On-Demand

| 項目 | On-Demand | Provisioned Concurrency |
|------|-----------|------------------------|
| **コールドスタート** | あり | なし |
| **レイテンシ** | 初回のみ高い | 常に低い |
| **コスト** | 実行時のみ | プロビジョン時間 + 実行時間 |
| **用途** | 低頻度・レイテンシ許容 | 高頻度・レイテンシ重視 |

**Provisioned Concurrency設定:**

```yaml
Resources:
  MyFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: my-api-function
      Runtime: python3.11
      Handler: index.handler
      Code: ...

  FunctionVersion:
    Type: AWS::Lambda::Version
    Properties:
      FunctionName: !Ref MyFunction

  ProvisionedConcurrencyConfig:
    Type: AWS::Lambda::EventInvokeConfig
    Properties:
      FunctionName: !Ref MyFunction
      Qualifier: !GetAtt FunctionVersion.Version
      # ピーク時のみProvisioned Concurrency使用
      DestinationConfig:
        OnSuccess:
          Destination: !GetAtt SuccessQueue.Arn

  # Application Auto Scalingで動的調整
  ScalableTarget:
    Type: AWS::ApplicationAutoScaling::ScalableTarget
    Properties:
      ServiceNamespace: lambda
      ResourceId: !Sub 'function:${MyFunction}:${FunctionVersion.Version}'
      ScalableDimension: lambda:function:ProvisionedConcurrentExecutions
      MinCapacity: 1
      MaxCapacity: 100

  ScalingPolicy:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Properties:
      PolicyName: lambda-provisioned-concurrency-scaling
      ServiceNamespace: lambda
      ResourceId: !Sub 'function:${MyFunction}:${FunctionVersion.Version}'
      ScalableDimension: lambda:function:ProvisionedConcurrentExecutions
      PolicyType: TargetTrackingScaling
      TargetTrackingScalingPolicyConfiguration:
        TargetValue: 0.7
        PredefinedMetricSpecification:
          PredefinedMetricType: LambdaProvisionedConcurrencyUtilization
```

---

## 6. AWS コストツール

### 6.1 Cost Explorer

**主要なフィルタリング:**

```python
import boto3
from datetime import datetime, timedelta

ce = boto3.client('ce')

def get_monthly_cost_by_service():
    """サービス別月間コスト取得"""
    end_date = datetime.utcnow().date()
    start_date = (end_date.replace(day=1) - timedelta(days=1)).replace(day=1)

    response = ce.get_cost_and_usage(
        TimePeriod={
            'Start': start_date.isoformat(),
            'End': end_date.isoformat()
        },
        Granularity='MONTHLY',
        Metrics=['UnblendedCost'],
        GroupBy=[
            {'Type': 'DIMENSION', 'Key': 'SERVICE'}
        ]
    )

    costs = {}
    for result in response['ResultsByTime']:
        for group in result['Groups']:
            service = group['Keys'][0]
            cost = float(group['Metrics']['UnblendedCost']['Amount'])
            costs[service] = cost

    return dict(sorted(costs.items(), key=lambda x: x[1], reverse=True))

# 使用例
costs = get_monthly_cost_by_service()
for service, cost in list(costs.items())[:10]:
    print(f"{service}: ${cost:.2f}")
```

### 6.2 Budgets（予算アラート）

```yaml
Resources:
  MonthlyBudget:
    Type: AWS::Budgets::Budget
    Properties:
      Budget:
        BudgetName: MonthlyAWSBudget
        BudgetType: COST
        TimeUnit: MONTHLY
        BudgetLimit:
          Amount: 1000
          Unit: USD

        # 予測コスト含む
        CostTypes:
          IncludeTax: true
          IncludeSubscription: true
          UseBlended: false

      NotificationsWithSubscribers:
        # 80%到達時にアラート
        - Notification:
            NotificationType: ACTUAL
            ComparisonOperator: GREATER_THAN
            Threshold: 80
            ThresholdType: PERCENTAGE
          Subscribers:
            - SubscriptionType: EMAIL
              Address: finance-team@example.com

        # 予測が100%超過時にアラート
        - Notification:
            NotificationType: FORECASTED
            ComparisonOperator: GREATER_THAN
            Threshold: 100
            ThresholdType: PERCENTAGE
          Subscribers:
            - SubscriptionType: EMAIL
              Address: engineering-lead@example.com
            - SubscriptionType: SNS
              Address: !Ref BudgetAlertTopic
```

### 6.3 Cost Anomaly Detection

```yaml
Resources:
  AnomalyMonitor:
    Type: AWS::CE::AnomalyMonitor
    Properties:
      MonitorName: ServiceAnomalyMonitor
      MonitorType: DIMENSIONAL
      MonitorDimension: SERVICE

  AnomalySubscription:
    Type: AWS::CE::AnomalySubscription
    Properties:
      SubscriptionName: CostAnomalyAlert
      Frequency: IMMEDIATE
      MonitorArnList:
        - !GetAtt AnomalyMonitor.MonitorArn
      Subscribers:
        - Type: EMAIL
          Address: cost-team@example.com
      Threshold: 100  # $100以上の異常を検知
```

### 6.4 Trusted Advisor

**コスト最適化チェック項目:**

| チェック | 説明 |
|---------|------|
| **低使用率のEC2インスタンス** | CPU使用率10%未満が14日間継続 |
| **アイドル状態のELB** | リクエスト数100未満/日 |
| **未使用のEBSボリューム** | アタッチされていないボリューム |
| **古いEBSスナップショット** | 30日以上経過したスナップショット |
| **RI使用率低下** | Reserved Instances利用率80%未満 |

---

## 7. EKS コスト最適化

### 7.1 Karpenter（動的ノードプロビジョニング）

Cluster Autoscalerの代替として、より効率的なノード管理:

**Karpenter Provisioner設定:**

```yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  # ノード要件
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["spot", "on-demand"]  # Spot優先
    - key: kubernetes.io/arch
      operator: In
      values: ["amd64", "arm64"]  # Graviton含む
    - key: node.kubernetes.io/instance-type
      operator: In
      values: ["m5.large", "m6g.large", "c5.large", "c6g.large"]

  # リソース制限
  limits:
    resources:
      cpu: 1000
      memory: 1000Gi

  # ノード削除戦略
  ttlSecondsAfterEmpty: 30  # 空ノードは30秒後に削除
  ttlSecondsUntilExpired: 604800  # 7日後に強制再作成

  # Spot中断処理
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h

  providerRef:
    name: default

---
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: default
spec:
  subnetSelector:
    karpenter.sh/discovery: my-cluster
  securityGroupSelector:
    karpenter.sh/discovery: my-cluster

  # Spot中断ハンドリング
  instanceProfile: KarpenterNodeInstanceProfile
  tags:
    karpenter.sh/discovery: my-cluster
```

### 7.2 Spot on EKS

**Spot Interrupt Handler（DaemonSet）:**

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: aws-node-termination-handler
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: aws-node-termination-handler
  template:
    metadata:
      labels:
        app: aws-node-termination-handler
    spec:
      serviceAccountName: aws-node-termination-handler
      containers:
        - name: aws-node-termination-handler
          image: public.ecr.aws/aws-ec2/aws-node-termination-handler:latest
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: ENABLE_SPOT_INTERRUPTION_DRAINING
              value: "true"
            - name: ENABLE_SCHEDULED_EVENT_DRAINING
              value: "true"
          securityContext:
            privileged: true
```

### 7.3 リソースクォータ

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: production
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    persistentvolumeclaims: "10"

---
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: production
spec:
  limits:
    - max:
        cpu: "4"
        memory: 8Gi
      min:
        cpu: "100m"
        memory: 128Mi
      default:
        cpu: "500m"
        memory: 512Mi
      defaultRequest:
        cpu: "200m"
        memory: 256Mi
      type: Container
```

---

## 8. サーバーレスコスト最適化

### 8.1 Lambda料金モデル

**料金要素:**

```
Lambda料金 = リクエスト数料金 + 実行時間料金

リクエスト数: $0.20 / 100万リクエスト
実行時間: $0.0000166667 / GB秒
```

**最適化ポイント:**

| 項目 | 推奨 | 理由 |
|------|------|------|
| **メモリ設定** | Power Tuning で最適化 | メモリ↑ → CPU↑ → 実行時間↓ |
| **コールドスタート** | ビジネスロジックの最適化 | 初期化コードを最小化 |
| **Provisioned Concurrency** | ピーク時のみ | 常時使用はコスト高 |
| **Lambda Layers** | 共通ライブラリを分離 | デプロイサイズ削減 |

### 8.2 Lambda Power Tuning

AWS Lambda Power Tuningツール（State Machine）:

```bash
# デプロイ
sam deploy --guided \
  --template-file template.yml \
  --stack-name lambda-power-tuning

# 実行
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:123456789012:stateMachine:lambdaPowerTuning \
  --input '{
    "lambdaARN": "arn:aws:lambda:us-east-1:123456789012:function:my-function",
    "powerValues": [128, 256, 512, 1024, 2048, 3008],
    "num": 50,
    "payload": {}
  }'
```

**最適化結果例:**

```
128MB: 実行時間 1000ms, コスト $0.002083
256MB: 実行時間 600ms, コスト $0.002500
512MB: 実行時間 350ms, コスト $0.002917
1024MB: 実行時間 200ms, コスト $0.003333 ← 最適
2048MB: 実行時間 150ms, コスト $0.005000
```

### 8.3 DynamoDB On-Demand vs Provisioned

| モード | 用途 | 料金 |
|--------|------|------|
| **On-Demand** | 予測不可能なトラフィック | リクエストごと課金 |
| **Provisioned** | 予測可能なトラフィック | キャパシティユニット課金 |

**判断基準:**

```python
def should_use_on_demand(daily_requests, peak_to_avg_ratio):
    """
    On-Demandが適しているかを判定

    Args:
        daily_requests: 1日あたりのリクエスト数
        peak_to_avg_ratio: ピーク時と平均時のリクエスト比率
    """
    # On-Demand料金（読み取り）
    on_demand_cost_per_million = 0.25
    on_demand_monthly_cost = (daily_requests * 30 / 1_000_000) * on_demand_cost_per_million

    # Provisioned料金（読み取り）
    provisioned_cost_per_rcu = 0.00013 * 730  # $0.00013/時間 × 730時間/月
    avg_rcu_needed = (daily_requests / 86400) / 2  # 2リクエスト/RCU
    peak_rcu_needed = avg_rcu_needed * peak_to_avg_ratio
    provisioned_monthly_cost = peak_rcu_needed * provisioned_cost_per_rcu

    print(f"On-Demand: ${on_demand_monthly_cost:.2f}/月")
    print(f"Provisioned: ${provisioned_monthly_cost:.2f}/月")

    # ピーク比率が高い、または絶対数が少ない場合はOn-Demand推奨
    return peak_to_avg_ratio > 3 or daily_requests < 1_000_000

# 例
should_use_on_demand(daily_requests=5_000_000, peak_to_avg_ratio=5)
```

---

## 9. ベストプラクティス

### 9.1 タグ戦略

**必須タグ:**

| タグキー | 説明 | 例 |
|---------|------|-----|
| **Environment** | 環境 | dev, staging, prod |
| **Owner** | 所有者 | team-backend, john.doe |
| **CostCenter** | コストセンター | engineering, marketing |
| **Project** | プロジェクト | mobile-app, api-v2 |
| **Application** | アプリケーション | order-service, payment-service |

**タグポリシー（Organizations）:**

```json
{
  "tags": {
    "Environment": {
      "tag_key": {
        "@@assign": "Environment"
      },
      "enforced_for": {
        "@@assign": [
          "ec2:instance",
          "rds:db",
          "s3:bucket"
        ]
      }
    }
  }
}
```

### 9.2 コスト最適化チェックリスト

```markdown
## 月次レビュー

- [ ] Cost Explorer で前月比10%以上増加したサービスを確認
- [ ] Trusted Advisor で低使用率リソースを確認
- [ ] Compute Optimizer で Rightsizing 推奨を確認
- [ ] 未使用のEBS/EIPを削除
- [ ] 古いスナップショット/AMIを削除

## 四半期レビュー

- [ ] Savings Plans / RI カバレッジを確認（目標: 70%以上）
- [ ] Savings Plans購入推奨を評価
- [ ] タグ付けカバレッジを確認（目標: 90%以上）
- [ ] 各環境のリソース棚卸し

## 年次レビュー

- [ ] アーキテクチャ見直し（サーバーレス化検討）
- [ ] 予算設定の見直し
- [ ] コスト配分タグの見直し
- [ ] FinOpsプロセスの改善
```

---

## 10. FinOps ガバナンスと組織

### 10.1 CCoE（Cloud Center of Excellence）

| 役割 | 責務 | メンバー構成 |
|------|------|------------|
| **FinOpsリード** | コスト最適化の全体推進、KPI設定 | クラウドアーキテクト/FinOps専門家 |
| **クラウドアーキテクト** | アーキテクチャ最適化提案、Savings Plans購入判断 | SA/インフラチーム |
| **ビジネスオーナー** | ROI評価、コスト配分承認、予算管理 | 事業部門リーダー |
| **エンジニアリング** | リソース最適化の実装、タグ付け遵守 | 開発/運用チーム |
| **経理/財務** | 請求管理、チャージバック運用、予算策定 | 財務部門 |

### 10.2 FinOps成熟度モデル

| レベル | 状態 | アクション |
|--------|------|----------|
| **Crawl（初期）** | コストの可視化が不十分 | Cost Explorer有効化、基本タグ設定、Budgetアラート |
| **Walk（成長）** | サービス別コストを把握 | rightsizing実施、Savings Plans導入、タグ付け強制 |
| **Run（成熟）** | FinOpsが文化として定着 | ユニットコスト管理、自動最適化、予測分析、CCoE運営 |

### 10.3 コスト配分とチャージバック

**チャージバック vs ショーバック:**

| 方式 | 説明 | 効果 |
|------|------|------|
| **チャージバック** | 実際のコストを事業部門に課金 | 直接的なコスト意識向上 |
| **ショーバック** | コスト情報の可視化のみ（課金なし） | 段階的なコスト意識醸成 |

**ユニットコスト指標:**

| 指標 | 計算式 | 用途 |
|------|--------|------|
| トランザクション単価 | AWSコスト / トランザクション数 | API、Web |
| ユーザー単価 | AWSコスト / アクティブユーザー数 | SaaS |
| 注文単価 | AWSコスト / 注文数 | EC |
| GB単価 | AWSコスト / 処理データ量 | データ処理 |

---

## 11. タギングガバナンス

### 11.1 タグ強制の仕組み

| 手段 | レベル | 動作 |
|------|--------|------|
| **AWS Organizations タグポリシー** | アカウント/OU | タグキー/値の標準化を強制 |
| **IAM ポリシー条件** | リソース作成時 | タグなしリソース作成を拒否 |
| **AWS Config Rules** | 事後検出 | タグ未設定リソースを検出・通知 |
| **Service Catalog TagOptions** | テンプレート | カタログ経由のプロビジョニング時にタグ強制 |

#### IAMによるタグ強制例

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": ["ec2:RunInstances", "rds:CreateDBInstance"],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:RequestTag/Environment": "true",
          "aws:RequestTag/CostCenter": "true",
          "aws:RequestTag/Owner": "true"
        }
      }
    }
  ]
}
```

#### AWS Config Ruleによる検出

```yaml
Resources:
  RequiredTagsRule:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: required-tags
      Source:
        Owner: AWS
        SourceIdentifier: REQUIRED_TAGS
      InputParameters:
        tag1Key: Environment
        tag2Key: CostCenter
        tag3Key: Owner
      Scope:
        ComplianceResourceTypes:
          - AWS::EC2::Instance
          - AWS::RDS::DBInstance
          - AWS::S3::Bucket
```

---

## 12. ネットワークコスト最適化

### 12.1 データ転送コスト構造

| 転送パターン | コスト | 最適化方法 |
|-------------|--------|----------|
| **インターネット→AWS** | 無料 | - |
| **AWS→インターネット** | $0.09/GB～ | CloudFront使用で削減 |
| **同一AZ内** | 無料 | 同一AZに配置 |
| **AZ間** | $0.01/GB（双方向） | 通信量の多いサービスは同一AZ |
| **リージョン間** | $0.02/GB～ | リージョン間通信の最小化 |
| **VPC Peering** | AZ間と同等 | Transit GWより安価 |
| **NAT Gateway処理** | $0.045/GB | VPC Endpointで回避 |

### 12.2 データ転送コスト削減パターン

```
パターン1: VPC Endpoint活用
  Before: EC2 → NAT GW → Internet → S3 ($0.045/GB + $0.09/GB)
  After:  EC2 → VPC Endpoint → S3 (無料)

パターン2: CloudFront活用
  Before: ユーザー → EC2 ($0.09/GB)
  After:  ユーザー → CloudFront → EC2 ($0.085/GB, キャッシュでさらに削減)

パターン3: 同一AZ配置
  Before: EC2(AZ-a) ↔ RDS(AZ-c) ($0.01/GB × 双方向)
  After:  EC2(AZ-a) ↔ RDS(AZ-a) (無料)
  ※ ただし可用性とのトレードオフ
```

---

## 13. AWS追加コスト管理ツール

### 13.1 AWS Cost and Usage Reports (CUR)

| 項目 | 説明 |
|------|------|
| **用途** | 最も詳細なコストデータ（行レベル） |
| **出力先** | S3バケット → Athena/QuickSightで分析 |
| **粒度** | 時間/日/月単位 |
| **活用** | カスタムコスト分析、BIダッシュボード構築 |

### 13.2 AWS Cost Categories

- **コスト分類ルール**: サービス、タグ、アカウント等の条件でコストを業務カテゴリに分類
- **階層構造**: 複数のルールを組み合わせて多次元分析
- **Cost Explorer統合**: 分類結果をCost Explorerで直接フィルタリング

### 13.3 AWS Billing Conductor

- **カスタム請求グループ**: 複数アカウントのコストを独自のグループに集約
- **レート調整**: マークアップ/マークダウンでコスト調整（リセラー向け）
- **マルチテナント請求**: テナントごとの詳細な請求管理

---

## 参考リソース

### AWS公式ドキュメント

- [AWS Cost Management User Guide](https://docs.aws.amazon.com/cost-management/)
- [AWS Compute Optimizer User Guide](https://docs.aws.amazon.com/compute-optimizer/)
- [AWS Trusted Advisor Best Practices](https://aws.amazon.com/premiumsupport/technology/trusted-advisor/best-practice-checklist/)
- [AWS Well-Architected Framework - Cost Optimization Pillar](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/)

### ツール

- [AWS Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)
- [AWS Lambda Power Tuning](https://github.com/alexcasalboni/aws-lambda-power-tuning)
- [Karpenter](https://karpenter.sh/)
- [AWS Pricing Calculator](https://calculator.aws/)
