# Resilience on AWS

AWS上でのレジリエンス（回復力）実践ガイド。レジリエンスパターン、AWS Fault Injection Service、マルチAZ/マルチリージョン設計、インシデント対応、およびバックアップ・リカバリ戦略をカバーします。

---

## 1. レジリエンスパターン

### 1.1 基本パターン

| パターン | 説明 | 実装方法 | 用途 |
|---------|------|---------|------|
| **Retry（リトライ）** | 失敗時に再試行 | 指数バックオフ + ジッター | 一時的なネットワークエラー |
| **Circuit Breaker（サーキットブレーカー）** | 連続失敗時に一時的に呼び出しを停止 | 状態機械（Closed/Open/Half-Open） | 下流サービス障害の影響最小化 |
| **Bulkhead（バルクヘッド）** | リソースを隔離して障害の波及を防ぐ | スレッドプール分離、リージョン分離 | 特定機能の障害が全体に影響しないようにする |
| **Timeout（タイムアウト）** | 応答待ちの上限時間を設定 | 接続・読み取りタイムアウト | 無限待機の防止 |
| **Fallback（フォールバック）** | 障害時に代替動作を実行 | キャッシュ返却、デフォルト値 | サービス低下時の最小限の機能提供 |

### 1.2 Retry実装（Python）

```python
import time
import random
from functools import wraps

def retry_with_exponential_backoff(
    max_retries=3,
    base_delay=1,
    max_delay=32,
    exponential_base=2,
    jitter=True
):
    """指数バックオフ + ジッター付きリトライデコレータ"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            retries = 0
            while retries < max_retries:
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    retries += 1
                    if retries >= max_retries:
                        raise

                    # 指数バックオフ計算
                    delay = min(base_delay * (exponential_base ** retries), max_delay)

                    # ジッター追加（サンダリングハード問題回避）
                    if jitter:
                        delay = delay * (0.5 + random.random())

                    print(f"リトライ {retries}/{max_retries}: {delay:.2f}秒後に再試行")
                    time.sleep(delay)

        return wrapper
    return decorator

# 使用例
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Orders')

@retry_with_exponential_backoff(max_retries=5)
def put_item_with_retry(item):
    """DynamoDBへの書き込み（リトライ付き）"""
    try:
        table.put_item(Item=item)
        print("書き込み成功")
    except ClientError as e:
        if e.response['Error']['Code'] == 'ProvisionedThroughputExceededException':
            print("スロットリング発生、リトライします")
            raise
        else:
            # リトライ不可能なエラー
            raise
```

### 1.3 Circuit Breaker実装

```python
import time
from enum import Enum
from threading import Lock

class CircuitState(Enum):
    CLOSED = "closed"       # 正常動作
    OPEN = "open"           # 障害検知、呼び出しブロック
    HALF_OPEN = "half_open" # 回復試行中

class CircuitBreaker:
    def __init__(
        self,
        failure_threshold=5,
        recovery_timeout=60,
        expected_exception=Exception
    ):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.expected_exception = expected_exception

        self.failure_count = 0
        self.last_failure_time = None
        self.state = CircuitState.CLOSED
        self.lock = Lock()

    def call(self, func, *args, **kwargs):
        with self.lock:
            if self.state == CircuitState.OPEN:
                # Open状態: recovery_timeout経過後にHalf-Openへ遷移
                if time.time() - self.last_failure_time >= self.recovery_timeout:
                    self.state = CircuitState.HALF_OPEN
                    print("Circuit Breaker: OPEN -> HALF_OPEN（回復試行）")
                else:
                    raise Exception("Circuit Breaker is OPEN（呼び出しブロック中）")

        try:
            result = func(*args, **kwargs)

            # 成功時の処理
            with self.lock:
                if self.state == CircuitState.HALF_OPEN:
                    # Half-Open状態で成功 → Closedへ
                    self.state = CircuitState.CLOSED
                    self.failure_count = 0
                    print("Circuit Breaker: HALF_OPEN -> CLOSED（回復完了）")

            return result

        except self.expected_exception as e:
            # 失敗時の処理
            with self.lock:
                self.failure_count += 1
                self.last_failure_time = time.time()

                if self.state == CircuitState.HALF_OPEN:
                    # Half-Open状態で失敗 → 再びOpenへ
                    self.state = CircuitState.OPEN
                    print("Circuit Breaker: HALF_OPEN -> OPEN（回復失敗）")

                elif self.failure_count >= self.failure_threshold:
                    # Closed状態で閾値超過 → Openへ
                    self.state = CircuitState.OPEN
                    print(f"Circuit Breaker: CLOSED -> OPEN（失敗回数: {self.failure_count}）")

            raise

# 使用例
import requests

circuit_breaker = CircuitBreaker(
    failure_threshold=3,
    recovery_timeout=30,
    expected_exception=requests.RequestException
)

def call_external_api():
    response = requests.get('https://api.example.com/data', timeout=5)
    response.raise_for_status()
    return response.json()

# Circuit Breaker経由で呼び出し
try:
    data = circuit_breaker.call(call_external_api)
except Exception as e:
    print(f"API呼び出し失敗: {e}")
```

### 1.4 Timeout設定（boto3）

```python
import boto3
from botocore.config import Config

# タイムアウト設定
config = Config(
    connect_timeout=5,  # 接続タイムアウト（秒）
    read_timeout=10,    # 読み取りタイムアウト（秒）
    retries={
        'max_attempts': 3,
        'mode': 'adaptive'  # adaptive / standard / legacy
    }
)

dynamodb = boto3.resource('dynamodb', config=config)

# Lambda関数でのタイムアウト設定
import os
os.environ['AWS_SDK_LOAD_CONFIG'] = '1'  # ~/.aws/config を読み込み
```

---

## 2. AWS Fault Injection Service (FIS)

### 2.1 FISの概念

Chaos Engineering を AWS上で実践するためのマネージドサービス:

- **Experiment Template**: 障害注入シナリオの定義
- **Action**: 実際の障害操作（EC2停止、ネットワーク遅延など）
- **Target**: 障害を注入するリソース
- **Stop Condition**: 実験を自動停止する条件（CloudWatch Alarm）

### 2.2 実験テンプレート例（EC2インスタンス停止）

```yaml
Resources:
  EC2StopExperiment:
    Type: AWS::FIS::ExperimentTemplate
    Properties:
      Description: 'ランダムなEC2インスタンスを停止して自動回復を検証'
      RoleArn: !GetAtt FISRole.Arn

      # Stop Condition（CloudWatch Alarm連携）
      StopConditions:
        - Source: aws:cloudwatch:alarm
          Value: !GetAtt HighErrorRateAlarm.Arn

      # Action定義
      Actions:
        StopRandomInstances:
          ActionId: aws:ec2:stop-instances
          Description: 'ランダムに選択したインスタンスを停止'
          Parameters:
            startInstancesAfterDuration: PT5M  # 5分後に再起動
          Targets:
            Instances: tagged-instances

      # Target定義（タグベースで選択）
      Targets:
        tagged-instances:
          ResourceType: aws:ec2:instance
          SelectionMode: COUNT(1)  # 1インスタンスを選択
          ResourceTags:
            Environment: staging
            ChaosTest: enabled

  # FIS実行ロール
  FISRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Statement:
          - Effect: Allow
            Principal:
              Service: fis.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess
      Policies:
        - PolicyName: FISActions
          PolicyDocument:
            Statement:
              - Effect: Allow
                Action:
                  - ec2:StopInstances
                  - ec2:StartInstances
                  - ec2:DescribeInstances
                Resource: '*'
```

### 2.3 ネットワーク遅延注入

```yaml
Actions:
  InjectNetworkLatency:
    ActionId: aws:ec2:inject-api-throttle-error
    Description: 'API呼び出しに遅延を注入'
    Parameters:
      duration: PT10M
      percentage: '50'  # 50%のリクエストに影響
      operations: 'ec2:DescribeInstances,ec2:DescribeVolumes'
    Targets:
      Roles: target-role

Targets:
  target-role:
    ResourceType: aws:iam:role
    SelectionMode: ALL
    ResourceArns:
      - !GetAtt ApplicationRole.Arn
```

### 2.4 実験実行（CLI）

```bash
# 実験開始
aws fis start-experiment \
  --experiment-template-id EXT1234567890abcdef \
  --tags key=Team,value=SRE

# 実験状態確認
aws fis get-experiment --id EX1234567890abcdef

# 実験停止（緊急時）
aws fis stop-experiment --id EX1234567890abcdef
```

---

## 3. マルチAZ / マルチリージョン設計

### 3.1 マルチAZ（高可用性）

| サービス | マルチAZ対応 | 自動フェイルオーバー |
|---------|-------------|---------------------|
| **RDS** | マルチAZ配置 | 自動（1-2分） |
| **ELB** | デフォルトでマルチAZ | 自動 |
| **ECS/EKS** | タスク/Podを複数AZ配置 | 自動（Health Check） |
| **Lambda** | AWSが自動で複数AZ配置 | 自動 |
| **DynamoDB** | デフォルトで3AZ | 自動 |

**VPC設計例（3AZ構成）:**

```yaml
Resources:
  # VPC
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsHostnames: true
      EnableDnsSupport: true

  # Public Subnets（各AZ）
  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.1.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      MapPublicIpOnLaunch: true

  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.2.0/24
      AvailabilityZone: !Select [1, !GetAZs '']
      MapPublicIpOnLaunch: true

  PublicSubnet3:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.3.0/24
      AvailabilityZone: !Select [2, !GetAZs '']
      MapPublicIpOnLaunch: true

  # Private Subnets（各AZ）
  PrivateSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.11.0/24
      AvailabilityZone: !Select [0, !GetAZs '']

  PrivateSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.12.0/24
      AvailabilityZone: !Select [1, !GetAZs '']

  PrivateSubnet3:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.13.0/24
      AvailabilityZone: !Select [2, !GetAZs '']

  # RDS Multi-AZ
  DBInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      Engine: postgres
      EngineVersion: '15.3'
      DBInstanceClass: db.t3.medium
      AllocatedStorage: 100
      MultiAZ: true  # マルチAZ有効化
      DBSubnetGroupName: !Ref DBSubnetGroup

  DBSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      DBSubnetGroupDescription: 'Subnet group for RDS'
      SubnetIds:
        - !Ref PrivateSubnet1
        - !Ref PrivateSubnet2
        - !Ref PrivateSubnet3
```

### 3.2 Route 53 ヘルスチェック

```yaml
Resources:
  HealthCheck:
    Type: AWS::Route53::HealthCheck
    Properties:
      HealthCheckConfig:
        Type: HTTPS
        ResourcePath: /health
        FullyQualifiedDomainName: api.example.com
        Port: 443
        RequestInterval: 30
        FailureThreshold: 3
      HealthCheckTags:
        - Key: Name
          Value: API Health Check

  # CloudWatch Alarm連携
  HealthCheckAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: 'Route53-HealthCheck-Failed'
      MetricName: HealthCheckStatus
      Namespace: AWS/Route53
      Statistic: Minimum
      Period: 60
      EvaluationPeriods: 2
      Threshold: 1
      ComparisonOperator: LessThanThreshold
      Dimensions:
        - Name: HealthCheckId
          Value: !Ref HealthCheck
      AlarmActions:
        - !Ref SNSAlertTopic
```

### 3.3 マルチリージョンDR戦略

| 戦略 | RPO | RTO | コスト | 複雑度 | 用途 |
|-----|-----|-----|--------|--------|------|
| **Backup & Restore** | 時間単位 | 時間〜日単位 | 低 | 低 | 非クリティカルなシステム |
| **Pilot Light** | 分単位 | 10分〜1時間 | 中 | 中 | ミッションクリティカル |
| **Warm Standby** | 秒単位 | 数分 | 高 | 高 | ビジネスクリティカル |
| **Multi-Site Active/Active** | ゼロ | ゼロ | 最高 | 最高 | ダウンタイム許容不可 |

**Pilot Light実装例:**

```yaml
# Primary Region (us-east-1)
Resources:
  # 本番環境（フルスペック）
  PrimaryDB:
    Type: AWS::RDS::DBInstance
    Properties:
      Engine: postgres
      DBInstanceClass: db.r5.xlarge
      MultiAZ: true
      BackupRetentionPeriod: 7

  # DR Regionへのレプリケーション
  ReadReplica:
    Type: AWS::RDS::DBInstance
    Properties:
      SourceDBInstanceIdentifier: !Ref PrimaryDB
      SourceRegion: us-east-1
      DBInstanceClass: db.t3.small  # 最小構成で待機
      PubliclyAccessible: false

# DR Region (us-west-2)
Resources:
  # Lambda + API Gatewayは定義のみ（未デプロイ）
  # フェイルオーバー時にデプロイ
  DRFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: api-handler-dr
      Runtime: python3.11
      Handler: index.handler
      Code: ...
      # 初期状態は無効
      State: Inactive

  # Route 53 Failover Routing
  DNSRecord:
    Type: AWS::Route53::RecordSet
    Properties:
      HostedZoneId: Z1234567890ABC
      Name: api.example.com
      Type: A
      SetIdentifier: DR-Region
      Failover: SECONDARY  # セカンダリとして設定
      AliasTarget:
        HostedZoneId: !GetAtt DRLoadBalancer.CanonicalHostedZoneID
        DNSName: !GetAtt DRLoadBalancer.DNSName
      HealthCheckId: !Ref PrimaryHealthCheck
```

---

## 4. インシデント対応

### 4.1 AWS Systems Manager Incident Manager

```yaml
Resources:
  # Response Plan（対応計画）
  ResponsePlan:
    Type: AWS::SSMIncidents::ResponsePlan
    Properties:
      Name: critical-api-outage
      DisplayName: 'API障害対応プラン'
      IncidentTemplate:
        Title: 'API完全停止'
        Impact: 1  # 1=Critical, 5=Low
        Summary: 'APIが全リージョンで応答停止'
        DedupeString: 'api-outage-{{ incident.start_time }}'

      # エスカレーション計画
      Engagements:
        - !Ref OnCallEngineer
        - !Ref EngineeringManager

      # 自動実行アクション
      Actions:
        - SsmAutomation:
            DocumentName: AWS-PublishSNSNotification
            RoleArn: !GetAtt AutomationRole.Arn
            Parameters:
              TopicArn:
                - !Ref IncidentNotificationTopic
              Message:
                - 'Critical incident detected: API Outage'

      # チャットチャンネル自動作成
      ChatChannel:
        ChatbotSns:
          - !Ref SlackIntegrationTopic

  # Replication Set（リージョン間でデータ同期）
  ReplicationSet:
    Type: AWS::SSMIncidents::ReplicationSet
    Properties:
      Regions:
        - RegionName: us-east-1
        - RegionName: us-west-2
          RegionConfiguration:
            SseKmsKeyId: !Ref KMSKey
```

### 4.2 Runbook自動化（Systems Manager Automation）

```yaml
schemaVersion: '0.3'
description: 'API障害時の自動診断・復旧'
parameters:
  LoadBalancerName:
    type: String
    description: 'ロードバランサー名'

mainSteps:
  # 1. Health Check確認
  - name: checkTargetHealth
    action: 'aws:executeAwsApi'
    inputs:
      Service: elbv2
      Api: DescribeTargetHealth
      TargetGroupArn: '{{ TargetGroupArn }}'
    outputs:
      - Name: UnhealthyTargets
        Selector: '$.TargetHealthDescriptions[?State.Code==`unhealthy`].Target.Id'
        Type: StringList

  # 2. Unhealthyターゲットをログ記録
  - name: logUnhealthyTargets
    action: 'aws:executeAwsApi'
    inputs:
      Service: cloudwatch
      Api: PutMetricData
      Namespace: CustomMetrics/TargetHealth
      MetricData:
        - MetricName: UnhealthyCount
          Value: '{{ checkTargetHealth.UnhealthyTargets.length }}'
          Unit: Count

  # 3. Auto Scalingで新インスタンス起動
  - name: scaleOut
    action: 'aws:executeAwsApi'
    inputs:
      Service: autoscaling
      Api: SetDesiredCapacity
      AutoScalingGroupName: '{{ AutoScalingGroup }}'
      DesiredCapacity: '{{ DesiredCapacity + 2 }}'

  # 4. 5分待機（新インスタンス起動待ち）
  - name: waitForNewInstances
    action: 'aws:sleep'
    inputs:
      Duration: PT5M

  # 5. Health Check再確認
  - name: recheckHealth
    action: 'aws:executeAwsApi'
    inputs:
      Service: elbv2
      Api: DescribeTargetHealth
      TargetGroupArn: '{{ TargetGroupArn }}'

  # 6. SNS通知
  - name: notifyTeam
    action: 'aws:executeAwsApi'
    inputs:
      Service: sns
      Api: Publish
      TopicArn: '{{ SNSTopicArn }}'
      Subject: 'Auto-recovery completed'
      Message: 'Unhealthy targets replaced. New capacity: {{ DesiredCapacity + 2 }}'
```

---

## 5. バックアップ・リカバリ

### 5.1 AWS Backup

```yaml
Resources:
  # Backup Plan
  BackupPlan:
    Type: AWS::Backup::BackupPlan
    Properties:
      BackupPlan:
        BackupPlanName: DailyBackupPlan
        BackupPlanRule:
          - RuleName: DailyBackup
            TargetBackupVault: !Ref BackupVault
            ScheduleExpression: 'cron(0 5 ? * * *)'  # 毎日午前5時
            StartWindowMinutes: 60
            CompletionWindowMinutes: 120
            Lifecycle:
              DeleteAfterDays: 30
              MoveToColdStorageAfterDays: 7

          - RuleName: WeeklyBackup
            TargetBackupVault: !Ref BackupVault
            ScheduleExpression: 'cron(0 3 ? * 1 *)'  # 毎週月曜午前3時
            Lifecycle:
              DeleteAfterDays: 90

  # Backup Vault
  BackupVault:
    Type: AWS::Backup::BackupVault
    Properties:
      BackupVaultName: PrimaryBackupVault
      EncryptionKeyArn: !GetAtt KMSKey.Arn

  # Backup Selection（タグベース）
  BackupSelection:
    Type: AWS::Backup::BackupSelection
    Properties:
      BackupPlanId: !Ref BackupPlan
      BackupSelection:
        SelectionName: TagBasedBackup
        IamRoleArn: !GetAtt BackupRole.Arn
        ListOfTags:
          - ConditionType: STRINGEQUALS
            ConditionKey: Backup
            ConditionValue: 'true'
        Resources:
          - '*'
```

### 5.2 RPO / RTO 設計

**RPO (Recovery Point Objective)**: データ損失許容時間

| バックアップ頻度 | RPO | 用途 |
|----------------|-----|------|
| リアルタイムレプリケーション | ほぼゼロ | ミッションクリティカル |
| 1時間ごと | 1時間 | ビジネスクリティカル |
| 1日1回 | 24時間 | 一般的なシステム |
| 週1回 | 1週間 | アーカイブデータ |

**RTO (Recovery Time Objective)**: 復旧目標時間

| DR戦略 | RTO | 実装 |
|--------|-----|------|
| Multi-Site Active/Active | 数秒 | Route 53 + マルチリージョン本番環境 |
| Warm Standby | 数分 | スケールダウンした環境を常時稼働 |
| Pilot Light | 10分〜1時間 | 最小構成 + 自動スケールアウト |
| Backup & Restore | 数時間〜数日 | AWS Backupからリストア |

### 5.3 クロスリージョンバックアップ

```yaml
Resources:
  # Primary Region Backup Vault
  PrimaryVault:
    Type: AWS::Backup::BackupVault
    Properties:
      BackupVaultName: Primary-us-east-1

  # DR Region Backup Vault
  DRVault:
    Type: AWS::Backup::BackupVault
    Properties:
      BackupVaultName: DR-us-west-2

  # Copy Action（Primary → DR）
  BackupPlan:
    Type: AWS::Backup::BackupPlan
    Properties:
      BackupPlan:
        BackupPlanName: CrossRegionBackup
        BackupPlanRule:
          - RuleName: DailyWithCopy
            TargetBackupVault: !Ref PrimaryVault
            ScheduleExpression: 'cron(0 5 ? * * *)'
            Lifecycle:
              DeleteAfterDays: 30
            CopyActions:
              - DestinationBackupVaultArn: !Sub 'arn:aws:backup:us-west-2:${AWS::AccountId}:backup-vault:DR-us-west-2'
                Lifecycle:
                  DeleteAfterDays: 30
```

### 5.4 Point-in-Time Recovery (PITR)

**DynamoDB PITR:**

```python
import boto3

dynamodb = boto3.client('dynamodb')

# PITR有効化
dynamodb.update_continuous_backups(
    TableName='Orders',
    PointInTimeRecoverySpecification={
        'PointInTimeRecoveryEnabled': True
    }
)

# 特定時点へリストア
from datetime import datetime, timedelta

restore_time = datetime.utcnow() - timedelta(hours=2)

dynamodb.restore_table_to_point_in_time(
    SourceTableName='Orders',
    TargetTableName='Orders-Restored',
    RestoreDateTime=restore_time,
    UseLatestRestorableTime=False
)
```

**RDS PITR:**

```bash
# 特定時点へリストア
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier mydb-prod \
  --target-db-instance-identifier mydb-restored \
  --restore-time 2024-01-15T10:30:00Z

# または最新の復元可能時点へ
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier mydb-prod \
  --target-db-instance-identifier mydb-restored \
  --use-latest-restorable-time
```

---

## 6. ベストプラクティス

### 6.1 レジリエンス設計原則

| 原則 | 説明 |
|------|------|
| **Design for Failure** | すべてのコンポーネントは失敗すると想定して設計 |
| **Decouple Components** | サービス間を疎結合にして障害の波及を防ぐ |
| **Implement Health Checks** | すべてのサービスでヘルスチェックエンドポイントを提供 |
| **Automate Recovery** | 人手介入なしで自動復旧する仕組みを構築 |
| **Test Failure Scenarios** | 定期的にChaos Engineeringで障害訓練 |

### 6.2 Chaos Engineering実践

```
1. 仮説を立てる
   「EC2インスタンスが1台停止しても、Auto Scalingで自動回復する」

2. 実験を設計
   FISでランダムなインスタンスを停止

3. Stop Conditionを設定
   エラー率が5%を超えたら実験を自動停止

4. 本番環境で実施
   ※最初はStaging環境で検証

5. 結果を分析
   自動回復にかかった時間、ユーザー影響を測定

6. 改善を実施
   回復時間短縮、アラート精度向上
```

### 6.3 障害対応チェックリスト

```markdown
## インシデント発生時

- [ ] Incident Manager でインシデント作成
- [ ] CloudWatch ダッシュボードで影響範囲確認
- [ ] X-Ray で障害発生箇所を特定
- [ ] Runbook に従って初期対応
- [ ] 関係者に通知（Slack/PagerDuty）

## 復旧作業

- [ ] Runbook実行（自動 or 手動）
- [ ] Health Check で回復確認
- [ ] ログで根本原因を調査
- [ ] 一時的な回避策を適用

## 事後対応

- [ ] Postmortem（ポストモーテム）作成
- [ ] 根本原因の恒久対策を実施
- [ ] Runbook を更新
- [ ] 再発防止策をバックログに追加
```

---

## 参考リソース

### AWS公式ドキュメント

- [AWS Well-Architected Framework - Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/)
- [AWS Fault Injection Simulator User Guide](https://docs.aws.amazon.com/fis/)
- [AWS Backup Developer Guide](https://docs.aws.amazon.com/aws-backup/)
- [AWS Systems Manager Incident Manager](https://docs.aws.amazon.com/incident-manager/)
- [Disaster Recovery Strategies](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/)

### 関連リソース

- [AWS Architecture Blog - Resilience](https://aws.amazon.com/blogs/architecture/category/best-practices/resilience/)
- [Chaos Engineering on AWS](https://aws.amazon.com/blogs/architecture/chaos-engineering-on-aws/)
