# サーバーレスデプロイメント

## 概要

このドキュメントでは、AWSにおけるサーバーレスアプリケーションのデプロイメント戦略について解説する。Infrastructure as Code (IaC)ツール（CloudFormation、CDK、SAM）、CI/CDパイプライン、監視、コスト最適化、テスト戦略を網羅する。

---

## デプロイメント自動化の必要性

### 手動デプロイメントの課題

| 課題 | 影響 | 解決策 |
|------|------|--------|
| **ヒューマンエラー** | ミスコンフィグレーション、ダウンタイム、セキュリティ脆弱性 | 自動化、IaC |
| **時間消費** | 反復作業による開発遅延 | CI/CDパイプライン |
| **環境間の不整合** | Dev/Staging/Prodの設定差異 | IaC、環境パラメータ化 |
| **スケーラビリティボトルネック** | 複数リージョン・環境管理の困難 | マルチリージョンスタック、自動化 |

### 自動化のメリット

**主要メリット:**
- **一貫性**: すべての環境で同一の構成をデプロイ
- **エラー削減**: 手動ステップの排除による信頼性向上
- **高速反復**: 迅速な機能リリース・修正
- **スケーラビリティ**: 増加するワークロードへの容易な対応
- **コラボレーション向上**: バージョン管理によるチーム協業

### サーバーレス特有の自動化要件

サーバーレスアーキテクチャは動的な性質により、特に自動化が重要:
- イベントトリガー（S3、DynamoDB Streams、SQS等）の設定
- マネージドサービス統合（API Gateway、DynamoDB、RDS等）
- IAMロール・ポリシーの適切な権限設定
- 複数コンポーネント間の依存関係管理

---

## Infrastructure as Code (IaC)

### IaCの原則

| 原則 | 説明 | メリット |
|------|------|---------|
| **宣言的構成** | リソースの望ましい状態を定義 | ツールが実装詳細を処理 |
| **再現性** | 全環境で一貫したセットアップ | 環境差異の排除 |
| **バージョン管理** | Gitでテンプレート/コード管理 | コラボレーション、監査、ロールバック |

### AWS IaCツール比較

#### CloudFormation vs CDK vs SAM

| 項目 | CloudFormation | CDK | SAM |
|------|---------------|-----|-----|
| **記述形式** | YAML/JSON | プログラミング言語 | YAML（CFn拡張） |
| **言語サポート** | - | Python, TypeScript, Java, C#, Go | - |
| **学習曲線** | 中 | 高（プログラミング必須） | 低（サーバーレス専用） |
| **動的ロジック** | 制限あり | ✓ ループ、条件、変数 | 制限あり |
| **サーバーレス特化** | - | - | ✓ |
| **ローカルテスト** | - | - | ✓ SAM CLI |
| **ドリフト検出** | ✓ | ✓（CFn経由） | ✓（CFn経由） |
| **適用場面** | 標準化、予測可能な構成 | 動的ロジック、再利用性 | サーバーレス専用 |

**選択ガイド:**
```
プログラミング言語で動的ロジック → CDK
サーバーレス専用 + ローカルテスト → SAM
標準化、チーム全体で統一 → CloudFormation
```

---

## CloudFormation

### 主要機能

**1. ドリフト検出:**
IaC外での変更を検知し、構成の一貫性を維持。

```bash
# ドリフト検出実行
aws cloudformation detect-stack-drift --stack-name my-stack

# ドリフト状態確認
aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id <id>
```

**2. リソース依存関係の自動管理:**
CloudFormationが依存関係を自動解決し、適切な順序でリソースを作成・削除。

**3. クロスリージョンデプロイ（StackSets）:**
複数リージョン・複数アカウントに同一構成をデプロイ。

```yaml
# StackSet例
AWSTemplateFormatVersion: '2010-09-09'
Description: Multi-region S3 bucket deployment

Parameters:
  BucketPrefix:
    Type: String
    Default: my-app-logs

Resources:
  LogBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${BucketPrefix}-${AWS::Region}'
      VersioningConfiguration:
        Status: Enabled
```

### CloudFormationテンプレート例

**サーバーレスAPIスタック:**
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: Serverless API with Lambda and API Gateway

Parameters:
  StageName:
    Type: String
    Default: prod
    AllowedValues:
      - dev
      - staging
      - prod

Resources:
  # Lambda関数
  ApiFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${AWS::StackName}-api-function'
      Runtime: python3.11
      Handler: index.lambda_handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        ZipFile: |
          import json
          def lambda_handler(event, context):
              return {
                  'statusCode': 200,
                  'body': json.dumps({'message': 'Hello from Lambda!'})
              }
      Environment:
        Variables:
          STAGE: !Ref StageName

  # Lambda実行ロール
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  # API Gateway REST API
  ApiGateway:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: !Sub '${AWS::StackName}-api'
      Description: Serverless API

  # API Gatewayリソース
  ApiResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref ApiGateway
      ParentId: !GetAtt ApiGateway.RootResourceId
      PathPart: hello

  # API Gatewayメソッド
  ApiMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref ApiGateway
      ResourceId: !Ref ApiResource
      HttpMethod: GET
      AuthorizationType: NONE
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${ApiFunction.Arn}/invocations'

  # Lambda権限（API Gateway実行許可）
  LambdaApiPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref ApiFunction
      Action: lambda:InvokeFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub 'arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${ApiGateway}/*'

  # API Gatewayデプロイメント
  ApiDeployment:
    Type: AWS::ApiGateway::Deployment
    DependsOn: ApiMethod
    Properties:
      RestApiId: !Ref ApiGateway
      StageName: !Ref StageName

Outputs:
  ApiEndpoint:
    Description: API Gateway endpoint URL
    Value: !Sub 'https://${ApiGateway}.execute-api.${AWS::Region}.amazonaws.com/${StageName}/hello'
    Export:
      Name: !Sub '${AWS::StackName}-ApiEndpoint'
```

**デプロイコマンド:**
```bash
# スタック作成
aws cloudformation create-stack \
  --stack-name my-serverless-api \
  --template-body file://template.yaml \
  --parameters ParameterKey=StageName,ParameterValue=prod \
  --capabilities CAPABILITY_IAM

# スタック更新
aws cloudformation update-stack \
  --stack-name my-serverless-api \
  --template-body file://template.yaml \
  --parameters ParameterKey=StageName,ParameterValue=prod \
  --capabilities CAPABILITY_IAM

# スタック削除
aws cloudformation delete-stack --stack-name my-serverless-api
```

### CloudFormationの制限

| 制限項目 | 制限値 | 回避策 |
|---------|--------|--------|
| **テンプレートサイズ** | アップロード: 1MB、埋め込みSAM: 51KB | S3経由アップロード、ネストスタック |
| **スタックあたりリソース数** | 500（サービスクォータ申請で拡張可） | ネストスタック、複数スタック分割 |
| **ネストスタック深度** | 5レベル | スタック設計の最適化 |

### CloudFormationアンチパターン

| アンチパターン | 問題 | 解決策 |
|--------------|------|--------|
| **シークレットのハードコード** | セキュリティリスク | Secrets Manager、Parameter Store使用 |
| **モノリシックテンプレート** | 保守性・デプロイ効率低下 | モジュール化、ネストスタック |
| **ドリフト検出無視** | 構成の不整合 | 定期的なドリフト検出実行 |

---

## AWS CDK

### CDKの特徴

**開発者フレンドリーなコードファースト:**
- 慣れたプログラミング言語（Python、TypeScript、Java等）でインフラ定義
- 動的ロジック（ループ、条件分岐、関数）の活用
- 再利用可能なコンストラクト（Construct Library）

**CDK → CloudFormation変換:**
CDKコードはコンパイル時にCloudFormationテンプレートに変換され、CFnエンジンで実行される。

### CDK実装例（TypeScript）

**Lambda + API Gatewayスタック:**
```typescript
import * as cdk from 'aws-cdk-lib';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import { Construct } from 'constructs';

export class ServerlessApiStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Lambda関数
    const apiFunction = new lambda.Function(this, 'ApiFunction', {
      runtime: lambda.Runtime.PYTHON_3_11,
      code: lambda.Code.fromInline(`
import json

def handler(event, context):
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Hello from CDK Lambda!'})
    }
      `),
      handler: 'index.handler',
      timeout: cdk.Duration.seconds(30),
      memorySize: 256,
    });

    // API Gateway REST API
    const api = new apigateway.LambdaRestApi(this, 'ServerlessApi', {
      handler: apiFunction,
      restApiName: 'Serverless API',
      description: 'API powered by CDK',
      deployOptions: {
        stageName: 'prod',
        throttlingRateLimit: 100,
        throttlingBurstLimit: 200,
      },
    });

    // Outputs
    new cdk.CfnOutput(this, 'ApiEndpoint', {
      value: api.url,
      description: 'API Gateway endpoint',
    });
  }
}
```

**デプロイコマンド:**
```bash
# CDKアプリ初期化
cdk init app --language typescript

# 依存関係インストール
npm install

# CloudFormationテンプレート生成（確認用）
cdk synth

# デプロイ
cdk deploy

# スタック削除
cdk destroy
```

### CDKの動的ロジック例

**環境ごとの条件分岐:**
```typescript
import * as cdk from 'aws-cdk-lib';
import * as lambda from 'aws-cdk-lib/aws-lambda';

export class ConditionalStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const stage = this.node.tryGetContext('stage') || 'dev';

    // 環境に応じたメモリ設定
    const memorySize = stage === 'prod' ? 1024 : 256;
    const timeout = stage === 'prod' ? 300 : 30;

    const func = new lambda.Function(this, 'MyFunction', {
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: 'index.handler',
      code: lambda.Code.fromAsset('lambda'),
      memorySize: memorySize,
      timeout: cdk.Duration.seconds(timeout),
    });

    // 本番環境のみProvisioned Concurrency設定
    if (stage === 'prod') {
      const version = func.currentVersion;
      const alias = new lambda.Alias(this, 'ProdAlias', {
        aliasName: 'prod',
        version: version,
        provisionedConcurrentExecutions: 10,
      });
    }
  }
}
```

**デプロイ:**
```bash
# 開発環境
cdk deploy -c stage=dev

# 本番環境
cdk deploy -c stage=prod
```

### CDK Construct Library

**L1 (CFn Resources)**: CloudFormationリソースの直接マッピング
**L2 (AWS Constructs)**: 高レベルの抽象化、ベストプラクティス組み込み
**L3 (Patterns)**: よくあるアーキテクチャパターンの実装

**L3パターン例（ECS on Fargate）:**
```typescript
import * as ecsPatterns from 'aws-cdk-lib/aws-ecs-patterns';

const fargateService = new ecsPatterns.ApplicationLoadBalancedFargateService(
  this,
  'MyFargateService',
  {
    taskImageOptions: {
      image: ecs.ContainerImage.fromRegistry('my-app'),
    },
    desiredCount: 2,
  }
);
```

---

## AWS SAM

### SAMの特徴

**サーバーレス専用:**
- CloudFormationの拡張
- サーバーレスリソース（Lambda、API Gateway、DynamoDB等）の簡潔な記述
- SAM CLIによるローカルテスト・デバッグ

**SAM変換プロセス:**
SAMテンプレート → CloudFormation変換 → CFnスタック作成

### SAMテンプレート例

**基本的なサーバーレスAPI:**
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: SAM serverless application

Globals:
  Function:
    Timeout: 30
    Runtime: python3.11
    Environment:
      Variables:
        TABLE_NAME: !Ref UsersTable

Resources:
  # Lambda関数
  GetUsersFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: app.get_users
      CodeUri: src/
      Policies:
        - DynamoDBReadPolicy:
            TableName: !Ref UsersTable
      Events:
        GetUsers:
          Type: Api
          Properties:
            Path: /users
            Method: get

  CreateUserFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: app.create_user
      CodeUri: src/
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref UsersTable
      Events:
        CreateUser:
          Type: Api
          Properties:
            Path: /users
            Method: post

  # DynamoDBテーブル
  UsersTable:
    Type: AWS::Serverless::SimpleTable
    Properties:
      PrimaryKey:
        Name: userId
        Type: String
      ProvisionedThroughput:
        ReadCapacityUnits: 5
        WriteCapacityUnits: 5

Outputs:
  ApiEndpoint:
    Description: API Gateway endpoint URL
    Value: !Sub 'https://${ServerlessRestApi}.execute-api.${AWS::Region}.amazonaws.com/Prod/'
```

**Lambda関数コード（src/app.py）:**
```python
import json
import boto3
import os
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def get_users(event, context):
    response = table.scan()
    return {
        'statusCode': 200,
        'body': json.dumps(response['Items'], default=decimal_default)
    }

def create_user(event, context):
    body = json.loads(event['body'])
    table.put_item(Item={
        'userId': body['userId'],
        'name': body['name'],
        'email': body['email']
    })
    return {
        'statusCode': 201,
        'body': json.dumps({'message': 'User created successfully'})
    }

def decimal_default(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError
```

### SAM CLIコマンド

**ローカルテスト:**
```bash
# Lambda関数をローカルで実行
sam local invoke GetUsersFunction

# API Gatewayをローカルで起動
sam local start-api

# テストイベントで実行
sam local invoke GetUsersFunction -e events/get_users.json
```

**デプロイ:**
```bash
# ビルド（依存関係解決）
sam build

# ガイド付きデプロイ（初回）
sam deploy --guided

# 以降のデプロイ（samconfig.toml使用）
sam deploy

# スタック削除
sam delete
```

**samconfig.toml例:**
```toml
version = 0.1

[default.deploy.parameters]
stack_name = "my-sam-app"
s3_bucket = "my-deployment-bucket"
s3_prefix = "my-sam-app"
region = "us-west-2"
capabilities = "CAPABILITY_IAM"
parameter_overrides = "Stage=prod"
```

### SAMポリシーテンプレート

SAMは一般的なユースケース向けのポリシーテンプレートを提供。

**主要テンプレート:**
```yaml
# DynamoDB読み取り
Policies:
  - DynamoDBReadPolicy:
      TableName: !Ref MyTable

# DynamoDB CRUD
Policies:
  - DynamoDBCrudPolicy:
      TableName: !Ref MyTable

# S3読み取り
Policies:
  - S3ReadPolicy:
      BucketName: !Ref MyBucket

# SQS送信
Policies:
  - SQSSendMessagePolicy:
      QueueName: !GetAtt MyQueue.QueueName
```

---

## CI/CD

### AWS Code Suite

**CodePipeline**: パイプラインオーケストレーション
**CodeBuild**: ビルド・テスト実行
**CodeDeploy**: デプロイメント管理

### CodePipeline構成例

**サーバーレスアプリCI/CDパイプライン:**
```yaml
# buildspec.yml（CodeBuildビルド仕様）
version: 0.2

phases:
  install:
    runtime-versions:
      python: 3.11
    commands:
      - pip install aws-sam-cli
      - sam --version

  pre_build:
    commands:
      - echo Running tests...
      - pytest tests/ -v

  build:
    commands:
      - echo Build started on `date`
      - sam build
      - sam package --output-template-file packaged.yaml --s3-bucket $S3_BUCKET

artifacts:
  files:
    - packaged.yaml
```

**CloudFormationパイプライン定義:**
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: CI/CD Pipeline for Serverless Application

Parameters:
  GitHubRepo:
    Type: String
  GitHubBranch:
    Type: String
    Default: main
  GitHubToken:
    Type: String
    NoEcho: true

Resources:
  # S3バケット（アーティファクト保存）
  ArtifactBucket:
    Type: AWS::S3::Bucket
    Properties:
      VersioningConfiguration:
        Status: Enabled

  # CodeBuildプロジェクト
  BuildProject:
    Type: AWS::CodeBuild::Project
    Properties:
      Name: !Sub '${AWS::StackName}-build'
      ServiceRole: !GetAtt CodeBuildRole.Arn
      Artifacts:
        Type: CODEPIPELINE
      Environment:
        Type: LINUX_CONTAINER
        ComputeType: BUILD_GENERAL1_SMALL
        Image: aws/codebuild/standard:7.0
        EnvironmentVariables:
          - Name: S3_BUCKET
            Value: !Ref ArtifactBucket
      Source:
        Type: CODEPIPELINE
        BuildSpec: buildspec.yml

  # CodePipeline
  Pipeline:
    Type: AWS::CodePipeline::Pipeline
    Properties:
      Name: !Sub '${AWS::StackName}-pipeline'
      RoleArn: !GetAtt PipelineRole.Arn
      ArtifactStore:
        Type: S3
        Location: !Ref ArtifactBucket
      Stages:
        # ソースステージ
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
                Branch: !Ref GitHubBranch
                OAuthToken: !Ref GitHubToken
              OutputArtifacts:
                - Name: SourceOutput

        # ビルドステージ
        - Name: Build
          Actions:
            - Name: BuildAction
              ActionTypeId:
                Category: Build
                Owner: AWS
                Provider: CodeBuild
                Version: '1'
              Configuration:
                ProjectName: !Ref BuildProject
              InputArtifacts:
                - Name: SourceOutput
              OutputArtifacts:
                - Name: BuildOutput

        # デプロイステージ
        - Name: Deploy
          Actions:
            - Name: DeployAction
              ActionTypeId:
                Category: Deploy
                Owner: AWS
                Provider: CloudFormation
                Version: '1'
              Configuration:
                ActionMode: CREATE_UPDATE
                StackName: my-serverless-app
                TemplatePath: BuildOutput::packaged.yaml
                Capabilities: CAPABILITY_IAM
                RoleArn: !GetAtt CloudFormationRole.Arn
              InputArtifacts:
                - Name: BuildOutput

  # IAMロール（CodeBuild）
  CodeBuildRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: codebuild.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AdministratorAccess

  # IAMロール（CodePipeline）
  PipelineRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: codepipeline.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AdministratorAccess

  # IAMロール（CloudFormation）
  CloudFormationRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: cloudformation.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AdministratorAccess
```

### デプロイ戦略

#### 1. All-at-once（一括デプロイ）

**特徴:**
- すべてのトラフィックを即座に新バージョンに切り替え
- 最も高速
- ロールバックが手動

**用途:**
- 開発環境
- 低リスクの変更

**SAM設定:**
```yaml
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      # ...
      AutoPublishAlias: live
      DeploymentPreference:
        Type: AllAtOnce
```

#### 2. Canary（カナリアデプロイ）

**特徴:**
- トラフィックの一部を新バージョンにルーティング
- 段階的に増加
- 自動ロールバック（CloudWatch Alarmsトリガー）

**カナリアパターン:**
- **Canary10Percent5Minutes**: 10%で5分、その後100%
- **Canary10Percent10Minutes**: 10%で10分、その後100%
- **Canary10Percent30Minutes**: 10%で30分、その後100%

**SAM設定:**
```yaml
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      # ...
      AutoPublishAlias: live
      DeploymentPreference:
        Type: Canary10Percent10Minutes
        Alarms:
          - !Ref FunctionErrorsAlarm
        Hooks:
          PreTraffic: !Ref PreTrafficHook
          PostTraffic: !Ref PostTrafficHook

  # エラーアラーム
  FunctionErrorsAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmDescription: Lambda function errors
      MetricName: Errors
      Namespace: AWS/Lambda
      Statistic: Sum
      Period: 60
      EvaluationPeriods: 1
      Threshold: 1
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: FunctionName
          Value: !Ref MyFunction
```

#### 3. Linear（線形デプロイ）

**特徴:**
- 一定間隔で段階的にトラフィックを増加
- 予測可能な展開
- 自動ロールバック

**線形パターン:**
- **Linear10PercentEvery1Minute**: 1分ごとに10%増加（10分で完了）
- **Linear10PercentEvery2Minutes**: 2分ごとに10%増加（20分で完了）
- **Linear10PercentEvery3Minutes**: 3分ごとに10%増加（30分で完了）

**SAM設定:**
```yaml
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      # ...
      AutoPublishAlias: live
      DeploymentPreference:
        Type: Linear10PercentEvery2Minutes
        Alarms:
          - !Ref FunctionErrorsAlarm
          - !Ref FunctionThrottlesAlarm
```

#### デプロイ戦略比較

| 戦略 | リスク | 速度 | 用途 |
|------|--------|------|------|
| **All-at-once** | 高 | 最速 | 開発環境、低リスク変更 |
| **Canary** | 低 | 中 | 本番環境、段階的検証 |
| **Linear** | 低 | 遅 | 本番環境、予測可能な展開 |

### デプロイフック

**PreTrafficフック:**
新バージョンへのトラフィック転送前に検証。

**PostTrafficフック:**
デプロイ完了後の検証。

**フック実装例:**
```python
import boto3
import json

lambda_client = boto3.client('lambda')
codedeploy_client = boto3.client('codedeploy')

def lambda_handler(event, context):
    deployment_id = event['DeploymentId']
    lifecycle_event_hook_execution_id = event['LifecycleEventHookExecutionId']

    # 新バージョンのテスト
    try:
        # Lambda関数を呼び出してテスト
        test_result = test_new_version(event['FunctionName'])

        if test_result['success']:
            # 成功を通知
            codedeploy_client.put_lifecycle_event_hook_execution_status(
                deploymentId=deployment_id,
                lifecycleEventHookExecutionId=lifecycle_event_hook_execution_id,
                status='Succeeded'
            )
        else:
            # 失敗を通知（ロールバック）
            codedeploy_client.put_lifecycle_event_hook_execution_status(
                deploymentId=deployment_id,
                lifecycleEventHookExecutionId=lifecycle_event_hook_execution_id,
                status='Failed'
            )
    except Exception as e:
        # エラー発生時はロールバック
        codedeploy_client.put_lifecycle_event_hook_execution_status(
            deploymentId=deployment_id,
            lifecycleEventHookExecutionId=lifecycle_event_hook_execution_id,
            status='Failed'
        )

def test_new_version(function_name):
    # テストロジック
    response = lambda_client.invoke(
        FunctionName=function_name,
        Payload=json.dumps({'test': True})
    )
    payload = json.loads(response['Payload'].read())
    return {'success': payload.get('statusCode') == 200}
```

---

## 監視・オブザーバビリティ

### CloudWatch

#### 1. CloudWatch Logs

**Lambda自動統合:**
Lambdaは自動的にCloudWatch Logsにログを送信。

**構造化ロギング例:**
```python
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(json.dumps({
        'event': 'request_received',
        'requestId': context.request_id,
        'userId': event.get('userId'),
        'path': event.get('path')
    }))

    # 処理ロジック

    logger.info(json.dumps({
        'event': 'request_completed',
        'requestId': context.request_id,
        'duration_ms': context.get_remaining_time_in_millis()
    }))

    return {'statusCode': 200, 'body': 'Success'}
```

**Logs Insights クエリ例:**
```sql
# エラーログを抽出
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20

# リクエスト期間の統計
fields @duration
| stats avg(@duration), max(@duration), min(@duration)
```

#### 2. CloudWatch Metrics

**カスタムメトリクス発行:**
```python
import boto3

cloudwatch = boto3.client('cloudwatch')

def lambda_handler(event, context):
    # ビジネスメトリクス発行
    cloudwatch.put_metric_data(
        Namespace='MyApp',
        MetricData=[
            {
                'MetricName': 'OrdersProcessed',
                'Value': 1,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'Environment', 'Value': 'prod'}
                ]
            }
        ]
    )

    return {'statusCode': 200}
```

**主要Lambdaメトリクス:**
- **Invocations**: 実行回数
- **Errors**: エラー回数
- **Duration**: 実行時間
- **Throttles**: スロットル回数
- **ConcurrentExecutions**: 同時実行数
- **IteratorAge**: ストリーム処理の遅延（Kinesis/DynamoDB Streams）

#### 3. CloudWatch Alarms

**アラーム設定例:**
```yaml
Resources:
  # エラー率アラーム
  HighErrorRateAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${FunctionName}-high-error-rate'
      AlarmDescription: Alert when error rate exceeds 5%
      MetricName: Errors
      Namespace: AWS/Lambda
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 5
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: FunctionName
          Value: !Ref MyFunction
      AlarmActions:
        - !Ref AlertTopic

  # 期間アラーム
  HighDurationAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${FunctionName}-high-duration'
      MetricName: Duration
      Namespace: AWS/Lambda
      Statistic: Average
      Period: 60
      EvaluationPeriods: 2
      Threshold: 5000  # 5秒
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: FunctionName
          Value: !Ref MyFunction
      AlarmActions:
        - !Ref AlertTopic
```

#### 4. Lambda Insights

**有効化:**
```yaml
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      # ...
      Layers:
        - !Sub 'arn:aws:lambda:${AWS::Region}:580247275435:layer:LambdaInsightsExtension:21'
      Policies:
        - CloudWatchLambdaInsightsExecutionRolePolicy
```

**提供メトリクス:**
- CPU使用率
- メモリ使用率
- ネットワークI/O
- コールドスタート頻度

### AWS X-Ray

**分散トレーシング:**
マイクロサービス間のリクエストフローを可視化。

**有効化:**
```yaml
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      # ...
      Tracing: Active
      Policies:
        - AWSXRayDaemonWriteAccess
```

**カスタムトレース（Python）:**
```python
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all
import boto3

# AWS SDKを自動計装
patch_all()

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Users')

def lambda_handler(event, context):
    # カスタムサブセグメント
    with xray_recorder.capture('get_user_from_db'):
        response = table.get_item(Key={'userId': event['userId']})

    with xray_recorder.capture('process_user_data'):
        user = response['Item']
        # 処理ロジック

    return {'statusCode': 200, 'body': user}
```

**X-Rayで確認できる情報:**
- サービスマップ（依存関係の可視化）
- レイテンシ分布
- エラー率
- スロットリング

---

## コスト最適化

### Lambda料金モデル

**課金要素:**
1. **リクエスト数**: $0.20 / 100万リクエスト
2. **実行時間**: $0.0000166667 / GB-秒（us-east-1）

**料金計算例:**
```
関数: 512MB、平均実行時間200ms、月間100万リクエスト

リクエスト料金: $0.20
実行時間料金: 1,000,000 * 0.2秒 * 0.5GB * $0.0000166667 = $1.67

合計: $1.87/月
```

### メモリ最適化

**AWS Lambda Power Tuningツール:**
メモリ設定とコストのトレードオフを測定。

```bash
# Power Tuning State Machineを実行
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:region:account:stateMachine:powerTuningStateMachine \
  --input '{
    "lambdaARN": "arn:aws:lambda:region:account:function:my-function",
    "powerValues": [128, 256, 512, 1024, 1536, 2048, 3008],
    "num": 10,
    "payload": {}
  }'
```

**結果の解釈:**
- **最速**: 最も高速な実行時間を提供するメモリ設定
- **最安**: 最もコスト効率的なメモリ設定
- **バランス**: 速度とコストのバランス

### Provisioned Concurrency判断

| 要件 | On-Demand | Provisioned Concurrency |
|------|-----------|------------------------|
| **コールドスタート許容** | ✓ | - |
| **レイテンシ重視** | - | ✓ |
| **予測可能な負荷** | - | ✓ |
| **スパイキーなトラフィック** | ✓ | - |
| **コスト** | 低 | 高（常時稼働分） |

**料金:**
- Provisioned Concurrency: $0.0000041667 / GB-秒（us-east-1）
- 実行時のリクエスト・期間料金は通常と同じ

### コスト削減戦略

| 戦略 | 実装 | 削減効果 |
|------|------|---------|
| **メモリ最適化** | Power Tuningで最適値特定 | 10-30% |
| **タイムアウト短縮** | 必要最小限に設定 | 失敗時のコスト削減 |
| **非アクティブ関数削除** | 定期的な監査 | 不要コスト排除 |
| **ARM64アーキテクチャ** | Graviton2使用 | 最大20% |
| **バッチ処理** | SQS/Kinesisバッチサイズ最適化 | 実行回数削減 |

---

## AWS Well-Architected Framework

### 6つの柱（サーバーレス視点）

#### 1. 運用性 (Operational Excellence)

**原則:**
- IaCによる自動化
- 監視・ロギング
- 迅速な問題対応

**サーバーレス実装:**
- CloudWatch Logs/Metrics/Alarms
- X-Ray分散トレーシング
- Lambda Insights
- Infrastructure as Code (SAM/CDK/CFn)

#### 2. セキュリティ (Security)

**原則:**
- 最小権限の原則
- データ暗号化
- 監査・ログ記録

**サーバーレス実装:**
- IAMロール（関数ごとに最小権限）
- Secrets Manager/Parameter Store
- VPC統合（プライベートリソースアクセス）
- 暗号化（保存時・転送時）

**IAMベストプラクティス:**
```yaml
# 悪い例: 過剰な権限
Policies:
  - AmazonDynamoDBFullAccess

# 良い例: 最小権限
Policies:
  - Version: '2012-10-17'
    Statement:
      - Effect: Allow
        Action:
          - dynamodb:GetItem
          - dynamodb:Query
        Resource: !GetAtt UsersTable.Arn
```

#### 3. 信頼性 (Reliability)

**原則:**
- 障害からの自動復旧
- スケーラビリティ
- 変更管理

**サーバーレス実装:**
- DLQ（Dead Letter Queue）
- リトライ設定
- 冪等性の確保
- 複数AZ展開（自動）

**DLQ設定:**
```yaml
Resources:
  MyFunction:
    Type: AWS::Serverless::Function
    Properties:
      # ...
      DeadLetterQueue:
        Type: SQS
        TargetArn: !GetAtt DeadLetterQueue.Arn
      EventInvokeConfig:
        MaximumRetryAttempts: 2
        MaximumEventAge: 3600
```

#### 4. パフォーマンス効率 (Performance Efficiency)

**原則:**
- 適切なリソース選択
- 新技術の活用
- グローバル展開

**サーバーレス実装:**
- Lambda Power Tuning
- ARM64アーキテクチャ（Graviton2）
- CloudFront + Lambda@Edge
- Provisioned Concurrency（レイテンシ重視）

#### 5. コスト最適化 (Cost Optimization)

**原則:**
- 従量課金の活用
- リソースの適正化
- 不要リソースの削除

**サーバーレス実装:**
- メモリ・タイムアウト最適化
- バッチ処理の活用
- On-Demand vs Provisioned判断
- コストアラート設定

**コスト監視:**
```yaml
Resources:
  CostAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: monthly-cost-alert
      MetricName: EstimatedCharges
      Namespace: AWS/Billing
      Statistic: Maximum
      Period: 21600  # 6時間
      EvaluationPeriods: 1
      Threshold: 100  # $100
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: Currency
          Value: USD
```

#### 6. 持続可能性 (Sustainability)

**原則:**
- エネルギー効率
- リソース最適化
- 不要リソース削減

**サーバーレス実装:**
- ARM64アーキテクチャ（省電力）
- 適切なメモリ設定（過剰プロビジョニング回避）
- 不要関数・リソースの削除

---

## テスト戦略

### テストピラミッド

```
        /\
       /E2E\        数: 少 / コスト: 高 / 速度: 遅
      /------\
     /統合テスト\    数: 中 / コスト: 中 / 速度: 中
    /----------\
   /ユニットテスト\  数: 多 / コスト: 低 / 速度: 速
  /--------------\
```

### 1. ユニットテスト

**Lambda関数のユニットテスト（Python/pytest）:**
```python
# lambda_function.py
import json

def lambda_handler(event, context):
    name = event.get('name', 'World')
    return {
        'statusCode': 200,
        'body': json.dumps({'message': f'Hello, {name}!'})
    }

# test_lambda_function.py
import pytest
from lambda_function import lambda_handler

def test_lambda_handler_with_name():
    event = {'name': 'Alice'}
    response = lambda_handler(event, {})

    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['message'] == 'Hello, Alice!'

def test_lambda_handler_without_name():
    event = {}
    response = lambda_handler(event, {})

    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert body['message'] == 'Hello, World!'
```

**実行:**
```bash
pytest tests/ -v
```

### 2. 統合テスト

**SAM CLIローカル統合テスト:**
```bash
# Lambda関数をローカルで実行
sam local invoke MyFunction -e events/test_event.json

# API Gatewayをローカルで起動
sam local start-api --port 3000

# curlでテスト
curl http://localhost:3000/users
```

**DynamoDBローカル統合テスト:**
```python
# test_integration.py
import boto3
import pytest
from moto import mock_dynamodb

@mock_dynamodb
def test_create_user():
    # DynamoDBモック作成
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    table = dynamodb.create_table(
        TableName='Users',
        KeySchema=[{'AttributeName': 'userId', 'KeyType': 'HASH'}],
        AttributeDefinitions=[{'AttributeName': 'userId', 'AttributeType': 'S'}],
        BillingMode='PAY_PER_REQUEST'
    )

    # テスト対象関数実行
    from lambda_function import create_user
    event = {'body': json.dumps({'userId': '123', 'name': 'Alice'})}
    response = create_user(event, {})

    # 検証
    assert response['statusCode'] == 201
    item = table.get_item(Key={'userId': '123'})
    assert item['Item']['name'] == 'Alice'
```

### 3. E2Eテスト

**Playwrightによる E2Eテスト:**
```typescript
// tests/e2e.spec.ts
import { test, expect } from '@playwright/test';

test('create and retrieve user', async ({ request }) => {
  // ユーザー作成
  const createResponse = await request.post('https://api.example.com/users', {
    data: {
      userId: '123',
      name: 'Alice',
      email: 'alice@example.com'
    }
  });
  expect(createResponse.status()).toBe(201);

  // ユーザー取得
  const getResponse = await request.get('https://api.example.com/users/123');
  expect(getResponse.status()).toBe(200);
  const user = await getResponse.json();
  expect(user.name).toBe('Alice');
});
```

**実行:**
```bash
npx playwright test
```

### 4. 負荷テスト

**Artillery負荷テスト:**
```yaml
# load-test.yml
config:
  target: 'https://api.example.com'
  phases:
    - duration: 60
      arrivalRate: 10  # 毎秒10リクエスト
    - duration: 120
      arrivalRate: 50  # 毎秒50リクエスト

scenarios:
  - name: 'Get users'
    flow:
      - get:
          url: '/users'
  - name: 'Create user'
    flow:
      - post:
          url: '/users'
          json:
            userId: '{{ $randomString() }}'
            name: '{{ $randomString() }}'
```

**実行:**
```bash
artillery run load-test.yml
```

---

## ベストプラクティス

### デプロイメント

| プラクティス | 理由 | 実装 |
|------------|------|------|
| **IaC使用** | 一貫性、再現性、バージョン管理 | CloudFormation/CDK/SAM |
| **環境分離** | Dev/Staging/Prodの独立 | スタック分離、パラメータ化 |
| **段階的デプロイ** | リスク軽減 | Canary/Linear戦略 |
| **自動テスト** | 品質保証 | ユニット/統合/E2E |
| **監視・アラート** | 問題の早期検出 | CloudWatch/X-Ray |

### セキュリティ

| プラクティス | 理由 | 実装 |
|------------|------|------|
| **最小権限** | 攻撃面削減 | IAMロール個別設定 |
| **シークレット管理** | 認証情報保護 | Secrets Manager |
| **暗号化** | データ保護 | KMS、HTTPS |
| **VPC統合** | ネットワーク分離 | VPC設定 |

### コスト

| プラクティス | 理由 | 実装 |
|------------|------|------|
| **メモリ最適化** | コスト削減 | Power Tuning |
| **タイムアウト設定** | 無駄な実行削減 | 適切な値設定 |
| **不要リソース削除** | コスト排除 | 定期監査 |
| **コストアラート** | 予算超過防止 | CloudWatch Billing Alarm |

---

## トラブルシューティング

### 一般的な問題と解決策

#### 1. デプロイ失敗

**問題:**
```
CREATE_FAILED: Resource creation cancelled
```

**原因と解決策:**

| 原因 | 解決策 |
|------|--------|
| **IAM権限不足** | CloudFormation実行ロールに必要な権限を付与 |
| **リソース制限** | サービスクォータ引き上げ申請 |
| **依存関係エラー** | `DependsOn`で明示的に依存関係を指定 |
| **タイムアウト** | リソース作成時間が長い場合はスタックポリシー調整 |

#### 2. Lambda実行エラー

**問題:**
```
Task timed out after 3.00 seconds
```

**解決策:**
- タイムアウト値を増加
- 処理を最適化（不要な処理削除、並列化）
- 非同期処理の活用

**問題:**
```
Unable to import module 'lambda_function'
```

**解決策:**
- 依存関係がパッケージに含まれているか確認
- Lambda Layersの使用
- デプロイパッケージのサイズ確認（250MB制限）

#### 3. API Gateway 5xx エラー

**問題:**
```
{"message": "Internal server error"}
```

**原因と解決策:**

| 原因 | 解決策 |
|------|--------|
| **Lambda権限不足** | API GatewayにLambda実行権限を付与 |
| **統合設定ミス** | Lambda ARNが正しいか確認 |
| **タイムアウト** | API Gateway/Lambdaタイムアウト設定確認 |

#### 4. DynamoDBスロットリング

**問題:**
```
ProvisionedThroughputExceededException
```

**解決策:**
- On-Demand課金モードに変更
- Auto Scaling設定
- GSI/LSIのスループット確認
- バッチ処理の最適化

#### 5. コールドスタート遅延

**問題:**
初回実行が遅い。

**解決策:**
- Provisioned Concurrency設定
- 依存関係の削減（パッケージサイズ縮小）
- ARM64アーキテクチャ使用
- コードの最適化

---

## まとめ

### デプロイメント選択ガイド

| ユースケース | 推奨ツール | デプロイ戦略 |
|-------------|----------|------------|
| **サーバーレス専用** | SAM | Canary/Linear |
| **動的ロジック必要** | CDK | Canary/Linear |
| **標準化・チーム統一** | CloudFormation | Canary/Linear |
| **開発環境** | SAM/CDK | All-at-once |

### チェックリスト

**デプロイ前:**
- [ ] IaCテンプレート/コードをバージョン管理
- [ ] ユニット/統合テスト実行
- [ ] セキュリティスキャン（IAM権限確認）
- [ ] コスト見積もり確認

**デプロイ中:**
- [ ] 段階的デプロイ戦略適用（本番環境）
- [ ] CloudWatch Alarms設定
- [ ] X-Ray有効化

**デプロイ後:**
- [ ] メトリクス・ログ確認
- [ ] E2Eテスト実行
- [ ] ドリフト検出実行（CloudFormation）
- [ ] コスト監視

### 避けるべきアンチパターン

| アンチパターン | 問題 | 解決策 |
|--------------|------|--------|
| **手動デプロイ** | 不整合、エラー | IaC + CI/CD |
| **本番直接デプロイ** | 高リスク | Canary/Linear戦略 |
| **監視不足** | 問題検出遅延 | CloudWatch/X-Ray |
| **テスト不足** | バグの本番流入 | 自動テストスイート |
| **シークレットハードコード** | セキュリティリスク | Secrets Manager |
