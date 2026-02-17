# SRE Automation on AWS

AWS上でのSite Reliability Engineering (SRE)自動化の実践ガイド。Infrastructure as Code (IaC)、インフラメンテナンス自動化、リリース自動化、および自動化ツールチェーンをカバーします。

---

## 1. Infrastructure as Code (IaC)

### 1.1 IaCの利点

インフラをコードとして管理することで以下のメリットを得られます:

| 利点 | 説明 |
|------|------|
| **一貫性** | コードによる定義で環境間の差異を排除 |
| **バージョン管理** | Gitなどで変更履歴を追跡可能 |
| **再現性** | 同一の構成を何度でも再作成可能 |
| **自動化** | インフラのプロビジョニングを完全自動化 |
| **ドキュメント** | コード自体がインフラのドキュメント |
| **レビュー** | Pull Requestで変更をレビュー可能 |

### 1.2 AWS IaC ツール比較

| ツール | 記述形式 | 用途 | 学習曲線 | AWS統合度 |
|--------|---------|------|---------|-----------|
| **CloudFormation** | YAML/JSON | AWS汎用IaC | 中 | ★★★★★ |
| **CDK** | TypeScript/Python/Java/Go/.NET | プログラマブルIaC | 高 | ★★★★★ |
| **SAM** | YAML | サーバーレス特化 | 低 | ★★★★☆ |
| **Terraform** | HCL | マルチクラウドIaC | 中 | ★★★★☆ |

**選定基準:**

```
AWS専用 & 宣言的 → CloudFormation
AWS専用 & プログラム的 → CDK
サーバーレス中心 → SAM
マルチクラウド → Terraform
```

---

## 2. AWS CloudFormation

### 2.1 基本概念

- **Template**: YAML/JSONでインフラを定義
- **Stack**: Templateから作成されるリソースの集合
- **Change Set**: 変更を適用前にプレビュー

### 2.2 Template構造

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'サンプルインフラ定義'

# パラメータ（再利用可能な値）
Parameters:
  EnvironmentType:
    Type: String
    Default: dev
    AllowedValues: [dev, staging, prod]
    Description: 環境タイプ

# マッピング（環境ごとの設定）
Mappings:
  EnvironmentConfig:
    dev:
      InstanceType: t3.micro
    prod:
      InstanceType: t3.large

# 条件（リソース作成の制御）
Conditions:
  IsProduction: !Equals [!Ref EnvironmentType, prod]

# リソース（必須セクション）
Resources:
  MyEC2Instance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: !FindInMap [EnvironmentConfig, !Ref EnvironmentType, InstanceType]
      ImageId: ami-0abcdef1234567890
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentType

  MyS3Bucket:
    Type: AWS::S3::Bucket
    Condition: IsProduction
    Properties:
      BucketName: !Sub '${AWS::StackName}-data-bucket'
      VersioningConfiguration:
        Status: Enabled

# 出力（他Stackで参照可能な値）
Outputs:
  InstanceId:
    Description: 'EC2インスタンスID'
    Value: !Ref MyEC2Instance
    Export:
      Name: !Sub '${AWS::StackName}-InstanceId'

  BucketName:
    Description: 'S3バケット名'
    Value: !Ref MyS3Bucket
    Condition: IsProduction
```

### 2.3 主要な組み込み関数

| 関数 | 用途 | 例 |
|------|------|-----|
| `!Ref` | リソース参照・パラメータ取得 | `!Ref MyBucket` |
| `!GetAtt` | リソース属性取得 | `!GetAtt MyInstance.PublicIp` |
| `!Sub` | 文字列置換 | `!Sub '${AWS::StackName}-bucket'` |
| `!Join` | 文字列結合 | `!Join ['-', [prefix, !Ref Name]]` |
| `!FindInMap` | マッピング値取得 | `!FindInMap [EnvMap, !Ref Env, Size]` |
| `!If` | 条件分岐 | `!If [IsProd, t3.large, t3.micro]` |

### 2.4 Stack操作

```bash
# Stack作成
aws cloudformation create-stack \
  --stack-name my-infrastructure \
  --template-body file://template.yaml \
  --parameters ParameterKey=EnvironmentType,ParameterValue=prod

# Stack更新（Change Set使用）
aws cloudformation create-change-set \
  --stack-name my-infrastructure \
  --change-set-name update-2024-01 \
  --template-body file://template-v2.yaml

# Change Setプレビュー
aws cloudformation describe-change-set \
  --stack-name my-infrastructure \
  --change-set-name update-2024-01

# Change Set実行
aws cloudformation execute-change-set \
  --stack-name my-infrastructure \
  --change-set-name update-2024-01

# Stack削除
aws cloudformation delete-stack \
  --stack-name my-infrastructure

# Stackイベント監視
aws cloudformation describe-stack-events \
  --stack-name my-infrastructure
```

---

## 3. AWS CDK (Cloud Development Kit)

### 3.1 CDKの特徴

プログラミング言語でインフラを定義:

- **型安全性**: コンパイル時に型チェック
- **IDE補完**: IntelliSenseでプロパティ補完
- **再利用**: 関数・クラスでロジックを抽象化
- **テスト**: ユニットテストでインフラコードを検証

### 3.2 CDK vs CloudFormation

| 項目 | CDK | CloudFormation |
|------|-----|----------------|
| 記述方法 | プログラム的 | 宣言的 |
| ループ・条件 | ネイティブ言語機能 | 限定的な組み込み関数 |
| 再利用性 | 高（クラス・関数） | 中（Nested Stack） |
| 抽象化レベル | 高レベルConstructs | 低レベルリソース定義 |
| 最終出力 | CloudFormation Template | Template自体 |

### 3.3 CDK実装例（TypeScript）

```typescript
import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ecs_patterns from 'aws-cdk-lib/aws-ecs-patterns';

export class MyInfraStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // VPC作成（高レベルConstruct）
    const vpc = new ec2.Vpc(this, 'MyVPC', {
      maxAzs: 2,
      natGateways: 1
    });

    // ECSクラスタ
    const cluster = new ecs.Cluster(this, 'MyCluster', {
      vpc: vpc
    });

    // Fargateサービス + ALB（パターンConstruct）
    const fargateService = new ecs_patterns.ApplicationLoadBalancedFargateService(
      this, 'MyFargateService', {
        cluster: cluster,
        cpu: 512,
        memoryLimitMiB: 1024,
        desiredCount: 2,
        taskImageOptions: {
          image: ecs.ContainerImage.fromRegistry('nginx:latest'),
          containerPort: 80
        }
      }
    );

    // Auto Scaling設定
    const scaling = fargateService.service.autoScaleTaskCount({
      minCapacity: 2,
      maxCapacity: 10
    });

    scaling.scaleOnCpuUtilization('CpuScaling', {
      targetUtilizationPercent: 70
    });

    // 出力
    new cdk.CfnOutput(this, 'LoadBalancerDNS', {
      value: fargateService.loadBalancer.loadBalancerDnsName
    });
  }
}
```

### 3.4 CDK CLI コマンド

```bash
# CDKプロジェクト初期化
cdk init app --language typescript

# CloudFormation Templateを合成
cdk synth

# デプロイ前のdiff確認
cdk diff

# デプロイ
cdk deploy

# 複数Stackを同時デプロイ
cdk deploy --all

# Stack削除
cdk destroy

# アプリケーション内の全Stackリスト
cdk list
```

---

## 4. Terraform (AWS連携)

### 4.1 Terraform on AWS

HashiCorp Terraformは宣言的IaCツールで、マルチクラウド対応:

- **State管理**: S3 + DynamoDB でリモートState
- **モジュール**: 再利用可能なインフラコンポーネント
- **Plan/Apply**: 変更プレビュー後に適用

### 4.2 Terraform実装例

```hcl
# Provider設定
terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# Subnet
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.environment}-public-${count.index + 1}"
  }
}

# EC2インスタンス
resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.environment}-app-server"
  }
}

# Output
output "instance_public_ip" {
  description = "EC2のPublic IP"
  value       = aws_instance.app.public_ip
}
```

---

## 5. インフラメンテナンス自動化

### 5.1 AWS Systems Manager概要

Systems Managerは統合運用管理サービス:

| カテゴリ | 機能 | 用途 |
|---------|------|------|
| **Operations Management** | OpsCenter, Explorer | インシデント管理、運用可視化 |
| **Application Management** | Parameter Store, AppConfig | 設定管理、機能フラグ |
| **Change Management** | Change Manager, Maintenance Windows | 変更承認、メンテナンス実行 |
| **Node Management** | Fleet Manager, Patch Manager, Run Command | サーバー管理、パッチ適用 |

### 5.2 Patch Manager（パッチ自動化）

**Patch Baseline**: パッチ適用ルール

```json
{
  "PatchBaseline": {
    "Name": "Production-Linux-Baseline",
    "OperatingSystem": "AMAZON_LINUX_2",
    "ApprovalRules": {
      "PatchRules": [
        {
          "PatchFilterGroup": {
            "PatchFilters": [
              {
                "Key": "CLASSIFICATION",
                "Values": ["Security", "Bugfix"]
              },
              {
                "Key": "SEVERITY",
                "Values": ["Critical", "Important"]
              }
            ]
          },
          "ApproveAfterDays": 7,
          "EnableNonSecurity": false
        }
      ]
    }
  }
}
```

**Maintenance Window設定:**

```bash
# Maintenance Window作成
aws ssm create-maintenance-window \
  --name "Production-Patching" \
  --schedule "cron(0 2 ? * SUN *)" \
  --duration 4 \
  --cutoff 1 \
  --allow-unassociated-targets

# Patch適用タスク登録
aws ssm register-task-with-maintenance-window \
  --window-id mw-0123456789abcdef0 \
  --task-arn "AWS-RunPatchBaseline" \
  --task-type "RUN_COMMAND" \
  --targets "Key=tag:Environment,Values=production"
```

### 5.3 AMI自動構築

**Systems Manager Automation + Image Builder:**

```yaml
# Automation Document例
schemaVersion: '0.3'
description: 'AMI作成・テスト・承認ワークフロー'
parameters:
  SourceAmiId:
    type: String
    description: 'ベースAMI'
  InstanceType:
    type: String
    default: 't3.medium'

mainSteps:
  - name: launchInstance
    action: 'aws:runInstances'
    inputs:
      ImageId: '{{ SourceAmiId }}'
      InstanceType: '{{ InstanceType }}'

  - name: configureInstance
    action: 'aws:runCommand'
    inputs:
      DocumentName: 'AWS-RunShellScript'
      InstanceIds:
        - '{{ launchInstance.InstanceIds }}'
      Parameters:
        commands:
          - 'yum update -y'
          - 'yum install -y nginx'

  - name: createImage
    action: 'aws:createImage'
    inputs:
      InstanceId: '{{ launchInstance.InstanceIds }}'
      ImageName: 'App-AMI-{{ global:DATE_TIME }}'
      NoReboot: true

  - name: terminateInstance
    action: 'aws:changeInstanceState'
    inputs:
      InstanceIds:
        - '{{ launchInstance.InstanceIds }}'
      DesiredState: 'terminated'
```

### 5.4 Run Command（リモートコマンド実行）

```bash
# 複数インスタンスで同時実行
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Role,Values=webserver" \
  --parameters 'commands=["systemctl restart nginx"]' \
  --output-s3-bucket-name "ssm-command-logs"

# コマンド実行状態確認
aws ssm list-command-invocations \
  --command-id "abcd1234-5678-90ef-ghij-klmnopqrstuv"
```

---

## 6. リリース自動化

### 6.1 CI/CD パイプライン構成

| ステージ | AWSサービス | 役割 |
|---------|------------|------|
| **Source** | CodeCommit, GitHub | ソースコード管理 |
| **Build** | CodeBuild | ビルド・テスト実行 |
| **Deploy** | CodeDeploy, ECS, Lambda | デプロイ |
| **Orchestration** | CodePipeline | パイプライン全体の制御 |

### 6.2 CodePipeline定義（CloudFormation）

```yaml
Resources:
  Pipeline:
    Type: AWS::CodePipeline::Pipeline
    Properties:
      Name: MyApplicationPipeline
      RoleArn: !GetAtt PipelineRole.Arn
      ArtifactStore:
        Type: S3
        Location: !Ref ArtifactBucket

      Stages:
        # Source Stage
        - Name: Source
          Actions:
            - Name: SourceAction
              ActionTypeId:
                Category: Source
                Owner: ThirdParty
                Provider: GitHub
                Version: '1'
              Configuration:
                Owner: !Ref GitHubOwner
                Repo: !Ref GitHubRepo
                Branch: main
                OAuthToken: !Ref GitHubToken
              OutputArtifacts:
                - Name: SourceOutput

        # Build Stage
        - Name: Build
          Actions:
            - Name: BuildAction
              ActionTypeId:
                Category: Build
                Owner: AWS
                Provider: CodeBuild
                Version: '1'
              Configuration:
                ProjectName: !Ref CodeBuildProject
              InputArtifacts:
                - Name: SourceOutput
              OutputArtifacts:
                - Name: BuildOutput

        # Deploy to Staging
        - Name: DeployStaging
          Actions:
            - Name: DeployToStaging
              ActionTypeId:
                Category: Deploy
                Owner: AWS
                Provider: ECS
                Version: '1'
              Configuration:
                ClusterName: !Ref StagingCluster
                ServiceName: !Ref StagingService
                FileName: imagedefinitions.json
              InputArtifacts:
                - Name: BuildOutput

        # Manual Approval
        - Name: Approval
          Actions:
            - Name: ManualApproval
              ActionTypeId:
                Category: Approval
                Owner: AWS
                Provider: Manual
                Version: '1'
              Configuration:
                CustomData: 'Staging環境の検証完了後に承認してください'

        # Deploy to Production
        - Name: DeployProduction
          Actions:
            - Name: DeployToProduction
              ActionTypeId:
                Category: Deploy
                Owner: AWS
                Provider: ECS
                Version: '1'
              Configuration:
                ClusterName: !Ref ProductionCluster
                ServiceName: !Ref ProductionService
                FileName: imagedefinitions.json
              InputArtifacts:
                - Name: BuildOutput
```

### 6.3 CodeBuild buildspec.yml

```yaml
version: 0.2

env:
  variables:
    AWS_DEFAULT_REGION: us-east-1
    IMAGE_REPO_NAME: my-app
  parameter-store:
    DOCKER_USERNAME: /prod/dockerhub/username
    DOCKER_PASSWORD: /prod/dockerhub/password

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}

  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG

  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo Writing image definitions file...
      - printf '[{"name":"my-app","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json

      # セキュリティスキャン
      - echo Running security scan...
      - trivy image --severity HIGH,CRITICAL $REPOSITORY_URI:$IMAGE_TAG

artifacts:
  files:
    - imagedefinitions.json
    - appspec.yaml

cache:
  paths:
    - '/root/.m2/**/*'
    - '/root/.npm/**/*'
```

### 6.4 デプロイ戦略

| 戦略 | 説明 | リスク | ロールバック時間 | CodeDeploy対応 |
|------|------|--------|----------------|---------------|
| **All-at-once** | 全インスタンスを一度に更新 | 高 | 長い | ○ |
| **Rolling** | 一定数ずつ順次更新 | 中 | 中 | ○ |
| **Blue/Green** | 新環境を完全に構築後に切替 | 低 | 即座 | ○ |
| **Canary** | 一部トラフィックで検証後に全体展開 | 低 | 即座 | ○ |

**CodeDeploy Blue/Green設定例:**

```yaml
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: "my-app"
          ContainerPort: 80
        PlatformVersion: "LATEST"

Hooks:
  - BeforeInstall: "LambdaFunctionToValidateBeforeInstall"
  - AfterInstall: "LambdaFunctionToValidateAfterTrafficShift"
  - AfterAllowTestTraffic: "LambdaFunctionToRunTests"
  - BeforeAllowTraffic: "LambdaFunctionToValidateService"
  - AfterAllowTraffic: "LambdaFunctionToValidateTraffic"
```

---

## 7. 自動化ツールチェーン

### 7.1 AWS Config（構成変更追跡）

**Config Rules設定:**

```yaml
Resources:
  RequiredTagsRule:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: required-tags
      Description: 'EC2インスタンスに必須タグが設定されているか確認'
      Source:
        Owner: AWS
        SourceIdentifier: REQUIRED_TAGS
      InputParameters:
        tag1Key: Environment
        tag2Key: Owner
      Scope:
        ComplianceResourceTypes:
          - 'AWS::EC2::Instance'

  EncryptedVolumesRule:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: encrypted-volumes
      Description: 'EBSボリュームが暗号化されているか確認'
      Source:
        Owner: AWS
        SourceIdentifier: ENCRYPTED_VOLUMES
```

### 7.2 EventBridge（イベント駆動自動化）

**EC2状態変化でLambda起動:**

```yaml
Resources:
  EC2StateChangeRule:
    Type: AWS::Events::Rule
    Properties:
      Name: ec2-state-change-notification
      Description: 'EC2状態変化を検知してLambdaを起動'
      EventPattern:
        source:
          - aws.ec2
        detail-type:
          - 'EC2 Instance State-change Notification'
        detail:
          state:
            - running
            - stopped
      State: ENABLED
      Targets:
        - Arn: !GetAtt NotificationLambda.Arn
          Id: 'EC2StateChangeLambda'

  NotificationLambda:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: ec2-state-notification
      Runtime: python3.11
      Handler: index.handler
      Code:
        ZipFile: |
          import json
          import boto3

          sns = boto3.client('sns')

          def handler(event, context):
              instance_id = event['detail']['instance-id']
              state = event['detail']['state']

              message = f"EC2インスタンス {instance_id} が {state} に変化しました"

              sns.publish(
                  TopicArn=os.environ['SNS_TOPIC_ARN'],
                  Subject='EC2状態変化通知',
                  Message=message
              )

              return {'statusCode': 200}
      Environment:
        Variables:
          SNS_TOPIC_ARN: !Ref AlertTopic
```

### 7.3 Lambda自動化パターン

**パターン1: S3イベント駆動処理**

```python
import json
import boto3
from urllib.parse import unquote_plus

s3 = boto3.client('s3')

def lambda_handler(event, context):
    """S3にアップロードされた画像を自動リサイズ"""
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])

        # 画像取得
        response = s3.get_object(Bucket=bucket, Key=key)
        image_data = response['Body'].read()

        # リサイズ処理（PIL/Pillow使用）
        from PIL import Image
        from io import BytesIO

        img = Image.open(BytesIO(image_data))
        img.thumbnail((200, 200))

        # サムネイル保存
        buffer = BytesIO()
        img.save(buffer, 'JPEG')
        buffer.seek(0)

        thumbnail_key = f"thumbnails/{key}"
        s3.put_object(
            Bucket=bucket,
            Key=thumbnail_key,
            Body=buffer,
            ContentType='image/jpeg'
        )

    return {'statusCode': 200, 'body': json.dumps('処理完了')}
```

**パターン2: スケジュール実行（EventBridge Scheduler）**

```yaml
Resources:
  ScheduledRule:
    Type: AWS::Events::Rule
    Properties:
      Name: daily-cleanup
      Description: '毎日午前2時に古いログを削除'
      ScheduleExpression: 'cron(0 2 * * ? *)'
      State: ENABLED
      Targets:
        - Arn: !GetAtt CleanupLambda.Arn
          Id: 'DailyCleanup'

  CleanupLambda:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: log-cleanup
      Runtime: python3.11
      Handler: index.handler
      Code:
        ZipFile: |
          import boto3
          from datetime import datetime, timedelta

          s3 = boto3.client('s3')

          def handler(event, context):
              bucket = 'my-logs-bucket'
              cutoff_date = datetime.now() - timedelta(days=90)

              # 90日以前のログを削除
              paginator = s3.get_paginator('list_objects_v2')

              for page in paginator.paginate(Bucket=bucket, Prefix='logs/'):
                  if 'Contents' not in page:
                      continue

                  for obj in page['Contents']:
                      if obj['LastModified'].replace(tzinfo=None) < cutoff_date:
                          s3.delete_object(Bucket=bucket, Key=obj['Key'])
                          print(f"削除: {obj['Key']}")

              return {'statusCode': 200}
```

---

## 8. ベストプラクティス

### 8.1 IaC運用

| プラクティス | 説明 |
|-------------|------|
| **State管理** | CloudFormation Stack、Terraform State をS3 + バージョニングで管理 |
| **環境分離** | dev/staging/prod を別Stackで管理、共通部分はパラメータ化 |
| **変更管理** | Change Set / `terraform plan` で変更内容を事前確認 |
| **ドリフト検出** | `aws cloudformation detect-stack-drift` で手動変更を検知 |
| **モジュール化** | 再利用可能なコンポーネントをモジュール/Nested Stackとして抽出 |

### 8.2 自動化の優先順位

```
1. 頻度高 & 手作業エラー多 → 最優先で自動化
   例: デプロイ、パッチ適用、バックアップ

2. 頻度中 & 複雑 → 次に自動化
   例: AMI構築、ログローテーション

3. 頻度低 & 単純 → 手動でも可
   例: 年次のアーキテクチャ変更
```

### 8.3 セキュリティ

- **最小権限**: IAM RoleでCodePipeline/CodeBuild/Lambda に必要最小限の権限
- **シークレット管理**: Secrets Manager / Parameter Store でクレデンシャル管理
- **監査ログ**: CloudTrail で全API呼び出しをログ記録
- **脆弱性スキャン**: CodeBuild で `trivy` / `snyk` によるコンテナスキャン

---

## 参考リソース

### AWS公式ドキュメント

- [AWS CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/)
- [AWS CDK Developer Guide](https://docs.aws.amazon.com/cdk/)
- [AWS Systems Manager User Guide](https://docs.aws.amazon.com/systems-manager/)
- [AWS CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/)
- [AWS CodeDeploy User Guide](https://docs.aws.amazon.com/codedeploy/)

### ツール

- [CloudFormation Linter (cfn-lint)](https://github.com/aws-cloudformation/cfn-lint)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [CDK Patterns](https://cdkpatterns.com/)
