# CDK

AWS CDKを使用したインフラストラクチャ as Codeの実践的なガイド。TypeScriptとPythonでのクラウドネイティブアプリケーション構築。

## CDK基礎

### App/Stack/Construct階層

AWS CDKアプリケーションは3つのレイヤーで構成される:

**Application (App)**
- CDKアプリケーションのエントリーポイント
- 1つ以上のStackを含む
- デプロイメント全体を統括
- 通常 `app.ts` または `main.ts` で定義

```typescript
// bin/app.ts
#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { MyStack } from '../lib/my-stack';

const app = new cdk.App();
new MyStack(app, 'MyStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION
  },
});
```

**Stack**
- CloudFormationスタックに対応するデプロイメント単位
- 関連するリソースを論理的にグループ化
- 独立してデプロイ可能
- 他のStackと参照関係を持てる

```typescript
// lib/my-stack.ts
import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';

export class MyStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // リソース定義をここに記述
  }
}
```

**Construct**
- AWSリソースまたは高レベル抽象化を表すコンポーネント
- 再利用可能な設計
- 階層的に組み合わせ可能（Composition）
- L1/L2/L3の3レベルが存在

### cdk.json設定

CDKアプリケーションの動作を制御する設定ファイル:

```json
{
  "app": "npx ts-node --prefer-ts-exts bin/app.ts",
  "context": {
    "@aws-cdk/core:enableStackNameDuplicates": "true",
    "aws-cdk:enableDiffNoFail": "true",
    "@aws-cdk/core:stackRelativeExports": "true"
  },
  "toolkitStackName": "CDKToolkit",
  "versionReporting": false
}
```

**重要な設定項目**:
- `app`: CDKアプリケーションの実行コマンド
- `context`: Feature flagsやランタイム設定
- `toolkitStackName`: Bootstrap stackの名前
- `versionReporting`: バージョン情報の送信可否

### プロジェクト構造

```
my-cdk-app/
├── bin/
│   └── app.ts              # エントリーポイント
├── lib/
│   ├── stacks/             # Stackクラス群
│   ├── constructs/         # カスタムConstruct
│   └── lambda/             # Lambda関数コード
├── test/
│   └── *.test.ts           # テストコード
├── cdk.json                # CDK設定
├── package.json            # npm依存関係
└── tsconfig.json           # TypeScript設定
```

---

## Constructレベル

### L1 Construct（CfnXxx）

CloudFormationリソースの1:1マッピング。最も低レベルで柔軟性が高い。

```typescript
import { aws_s3 as s3 } from 'aws-cdk-lib';

const cfnBucket = new s3.CfnBucket(this, 'MyCfnBucket', {
  bucketName: 'my-cfn-bucket-12345',
  versioningConfiguration: {
    status: 'Enabled'
  },
  publicAccessBlockConfiguration: {
    blockPublicAcls: true,
    blockPublicPolicy: true,
    ignorePublicAcls: true,
    restrictPublicBuckets: true
  }
});
```

**特徴**:
- CloudFormationプロパティを直接指定
- 全てのCloudFormation機能にアクセス可能
- 冗長な記述が必要
- 型安全性は保証されるが開発効率は低い

### L2 Construct（高レベルAPI）

AWS CDKが提供する高レベルAPI。デフォルト値とベストプラクティスを内包。

```typescript
import { aws_s3 as s3 } from 'aws-cdk-lib';

const bucket = new s3.Bucket(this, 'MyBucket', {
  versioned: true,
  encryption: s3.BucketEncryption.S3_MANAGED,
  blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
  removalPolicy: cdk.RemovalPolicy.RETAIN,
  autoDeleteObjects: false
});
```

**特徴**:
- セキュアなデフォルト値が設定済み
- メソッドチェーンで関連リソースを追加可能
- 冗長なプロパティ指定を削減
- ほとんどのユースケースで推奨

### L3 Construct（パターン）

複数のリソースを組み合わせた高レベルパターン。特定のアーキテクチャを実装。

```typescript
import * as patterns from 'aws-cdk-lib/aws-patterns';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';

// API Gateway + Lambda + DynamoDB を一括構築
const api = new patterns.LambdaRestApi(this, 'MyApi', {
  handler: new lambda.Function(this, 'Handler', {
    runtime: lambda.Runtime.NODEJS_20_X,
    code: lambda.Code.fromAsset('lambda'),
    handler: 'index.handler',
    environment: {
      TABLE_NAME: table.tableName
    }
  }),
  proxy: false
});

// ALB + Fargate を一括構築
const fargateService = new patterns.ApplicationLoadBalancedFargateService(
  this, 'MyFargateService', {
    taskImageOptions: {
      image: ecs.ContainerImage.fromRegistry('amazon/amazon-ecs-sample')
    },
    desiredCount: 2,
    cpu: 512,
    memoryLimitMiB: 1024
  }
);
```

**特徴**:
- ベストプラクティスに基づくアーキテクチャ
- 複数のリソースを一度に構築
- 設定項目を最小化
- 柔軟性は低いが開発速度が速い

### 使い分けガイドライン

| 状況 | 推奨レベル | 理由 |
|------|-----------|------|
| 標準的なリソース作成 | **L2** | セキュアなデフォルト + 高い生産性 |
| CDKで未サポートの新機能 | **L1** | CloudFormationの全機能にアクセス可能 |
| 特定のアーキテクチャパターン | **L3** | ベストプラクティスを自動適用 |
| 細かいプロパティ制御が必要 | **L1** | 完全な制御が可能 |
| プロトタイピング・PoC | **L3 → L2** | 迅速な検証後にカスタマイズ |

---

## スタック設計

### マルチスタック構成

関心事の分離とデプロイメントの柔軟性のために、複数のStackに分割する。

```typescript
// lib/network-stack.ts
export class NetworkStack extends cdk.Stack {
  public readonly vpc: ec2.Vpc;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    this.vpc = new ec2.Vpc(this, 'Vpc', {
      maxAzs: 2,
      natGateways: 1
    });
  }
}

// lib/database-stack.ts
export interface DatabaseStackProps extends cdk.StackProps {
  vpc: ec2.IVpc;
}

export class DatabaseStack extends cdk.Stack {
  public readonly database: rds.DatabaseInstance;

  constructor(scope: Construct, id: string, props: DatabaseStackProps) {
    super(scope, id, props);

    this.database = new rds.DatabaseInstance(this, 'Database', {
      engine: rds.DatabaseInstanceEngine.postgres({ version: rds.PostgresEngineVersion.VER_15 }),
      vpc: props.vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED }
    });
  }
}

// lib/application-stack.ts
export interface ApplicationStackProps extends cdk.StackProps {
  vpc: ec2.IVpc;
  database: rds.IDatabaseInstance;
}

export class ApplicationStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: ApplicationStackProps) {
    super(scope, id, props);

    const cluster = new ecs.Cluster(this, 'Cluster', { vpc: props.vpc });

    // ECS ServiceがDBに接続
    const taskDef = new ecs.FargateTaskDefinition(this, 'TaskDef');
    taskDef.addContainer('App', {
      image: ecs.ContainerImage.fromRegistry('myapp:latest'),
      environment: {
        DB_HOST: props.database.dbInstanceEndpointAddress
      }
    });
  }
}

// bin/app.ts
const app = new cdk.App();

const networkStack = new NetworkStack(app, 'NetworkStack');
const dbStack = new DatabaseStack(app, 'DatabaseStack', {
  vpc: networkStack.vpc
});
const appStack = new ApplicationStack(app, 'ApplicationStack', {
  vpc: networkStack.vpc,
  database: dbStack.database
});

// 依存関係を明示的に定義
appStack.addDependency(dbStack);
dbStack.addDependency(networkStack);
```

**マルチスタックのベストプラクティス**:
- ライフサイクルが異なるリソースは別Stackに分離
- 共有リソース（VPC等）は専用Stackに配置
- 依存関係は `addDependency()` で明示
- 循環参照を避ける設計

### クロススタック参照

CloudFormation Exportsを使用してStack間でリソースを共有:

```typescript
// 提供側Stack
export class SharedStack extends cdk.Stack {
  public readonly vpc: ec2.Vpc;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    this.vpc = new ec2.Vpc(this, 'SharedVpc', { maxAzs: 2 });

    // Export値として公開
    new cdk.CfnOutput(this, 'VpcId', {
      value: this.vpc.vpcId,
      exportName: 'SharedVpcId'
    });
  }
}

// 利用側Stack
export class ConsumerStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Import値を参照
    const vpcId = cdk.Fn.importValue('SharedVpcId');

    // 既存VPCを参照
    const vpc = ec2.Vpc.fromLookup(this, 'ImportedVpc', {
      vpcId: vpcId
    });
  }
}
```

**クロススタック参照の注意点**:
- Export名は一意である必要がある
- Export値を変更するとデプロイエラーが発生
- 参照元Stackを削除できなくなる場合がある
- できる限りコンストラクタ引数での受け渡しを推奨

### 環境分離

複数環境（dev/staging/prod）で異なる設定を適用:

```typescript
// bin/app.ts
import { getConfig } from '../config';

const app = new cdk.App();
const env = app.node.tryGetContext('env') || 'dev';
const config = getConfig(env);

new MyStack(app, `MyStack-${env}`, {
  env: {
    account: config.account,
    region: config.region
  },
  stackName: `my-app-${env}`,
  tags: {
    Environment: env,
    Project: 'MyApp'
  },
  // 環境別パラメータ
  instanceType: config.instanceType,
  minCapacity: config.minCapacity,
  maxCapacity: config.maxCapacity
});
```

```typescript
// config/index.ts
interface EnvironmentConfig {
  account: string;
  region: string;
  instanceType: string;
  minCapacity: number;
  maxCapacity: number;
}

export function getConfig(env: string): EnvironmentConfig {
  const configs: Record<string, EnvironmentConfig> = {
    dev: {
      account: '111111111111',
      region: 'us-east-1',
      instanceType: 't3.small',
      minCapacity: 1,
      maxCapacity: 2
    },
    prod: {
      account: '222222222222',
      region: 'us-west-2',
      instanceType: 't3.large',
      minCapacity: 3,
      maxCapacity: 10
    }
  };

  return configs[env] || configs.dev;
}
```

**デプロイコマンド**:
```bash
# dev環境にデプロイ
cdk deploy --context env=dev

# prod環境にデプロイ
cdk deploy --context env=prod
```

---

## Lambda統合

### 基本的なLambda関数デプロイ

```typescript
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as path from 'path';

const myFunction = new lambda.Function(this, 'MyFunction', {
  runtime: lambda.Runtime.NODEJS_20_X,
  handler: 'index.handler',
  code: lambda.Code.fromAsset(path.join(__dirname, '../lambda/my-function')),
  environment: {
    TABLE_NAME: table.tableName,
    API_ENDPOINT: 'https://api.example.com'
  },
  timeout: cdk.Duration.seconds(30),
  memorySize: 256,
  reservedConcurrentExecutions: 10
});

// IAM権限を付与
table.grantReadWriteData(myFunction);
```

### TypeScript/Python Bundling

**TypeScript Lambda (esbuild)**:

```typescript
import * as lambdaNodejs from 'aws-cdk-lib/aws-lambda-nodejs';

const tsFunction = new lambdaNodejs.NodejsFunction(this, 'TsFunction', {
  entry: path.join(__dirname, '../lambda/handler.ts'),
  handler: 'handler',
  runtime: lambda.Runtime.NODEJS_20_X,
  bundling: {
    minify: true,
    sourceMap: true,
    target: 'es2022',
    externalModules: ['@aws-sdk/*'], // AWS SDKはランタイムに含まれる
    loader: {
      '.graphql': 'text'
    }
  }
});
```

**Python Lambda**:

```typescript
import * as lambdaPython from '@aws-cdk/aws-lambda-python-alpha';

const pyFunction = new lambdaPython.PythonFunction(this, 'PyFunction', {
  entry: path.join(__dirname, '../lambda'),
  runtime: lambda.Runtime.PYTHON_3_12,
  index: 'handler.py',
  handler: 'lambda_handler',
  bundling: {
    assetExcludes: ['.venv', '__pycache__', '*.pyc']
  }
});
```

### Lambda Layers

共通ライブラリやランタイム依存関係をLayerとして分離:

```typescript
// Layerの作成
const sharedLayer = new lambda.LayerVersion(this, 'SharedLayer', {
  code: lambda.Code.fromAsset(path.join(__dirname, '../layers/shared')),
  compatibleRuntimes: [lambda.Runtime.NODEJS_20_X],
  description: '共通ユーティリティライブラリ',
  license: 'MIT'
});

// Lambdaに適用
const func1 = new lambda.Function(this, 'Function1', {
  runtime: lambda.Runtime.NODEJS_20_X,
  handler: 'index.handler',
  code: lambda.Code.fromAsset('lambda/func1'),
  layers: [sharedLayer]
});

const func2 = new lambda.Function(this, 'Function2', {
  runtime: lambda.Runtime.NODEJS_20_X,
  handler: 'index.handler',
  code: lambda.Code.fromAsset('lambda/func2'),
  layers: [sharedLayer]
});
```

**Layer構造**:
```
layers/shared/
└── nodejs/
    ├── node_modules/
    │   ├── lodash/
    │   └── aws-xray-sdk/
    └── package.json
```

---

## カスタムConstruct

### 再利用可能なConstructの作成

```typescript
// lib/constructs/monitored-lambda.ts
import { Construct } from 'constructs';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';
import * as sns from 'aws-cdk-lib/aws-sns';
import * as actions from 'aws-cdk-lib/aws-cloudwatch-actions';

export interface MonitoredLambdaProps {
  functionName: string;
  code: lambda.Code;
  handler: string;
  runtime: lambda.Runtime;
  alarmTopic: sns.ITopic;
  errorThreshold?: number;
  durationThreshold?: number;
}

/**
 * Lambda関数とそれに対する監視アラームを一括作成するConstruct
 */
export class MonitoredLambda extends Construct {
  public readonly function: lambda.Function;
  public readonly errorAlarm: cloudwatch.Alarm;
  public readonly durationAlarm: cloudwatch.Alarm;

  constructor(scope: Construct, id: string, props: MonitoredLambdaProps) {
    super(scope, id);

    // Lambda関数を作成
    this.function = new lambda.Function(this, 'Function', {
      functionName: props.functionName,
      code: props.code,
      handler: props.handler,
      runtime: props.runtime,
      timeout: cdk.Duration.seconds(30),
      memorySize: 256,
      tracing: lambda.Tracing.ACTIVE
    });

    // エラー率アラーム
    this.errorAlarm = new cloudwatch.Alarm(this, 'ErrorAlarm', {
      metric: this.function.metricErrors({
        statistic: 'Sum',
        period: cdk.Duration.minutes(5)
      }),
      threshold: props.errorThreshold || 5,
      evaluationPeriods: 1,
      alarmDescription: `${props.functionName} error rate exceeded`,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING
    });
    this.errorAlarm.addAlarmAction(new actions.SnsAction(props.alarmTopic));

    // 実行時間アラーム
    this.durationAlarm = new cloudwatch.Alarm(this, 'DurationAlarm', {
      metric: this.function.metricDuration({
        statistic: 'Average',
        period: cdk.Duration.minutes(5)
      }),
      threshold: props.durationThreshold || 10000,
      evaluationPeriods: 2,
      alarmDescription: `${props.functionName} duration exceeded`,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING
    });
    this.durationAlarm.addAlarmAction(new actions.SnsAction(props.alarmTopic));
  }
}
```

**使用例**:

```typescript
const alarmTopic = new sns.Topic(this, 'AlarmTopic');

const monitoredFunc = new MonitoredLambda(this, 'ApiHandler', {
  functionName: 'api-handler',
  code: lambda.Code.fromAsset('lambda'),
  handler: 'index.handler',
  runtime: lambda.Runtime.NODEJS_20_X,
  alarmTopic: alarmTopic,
  errorThreshold: 10,
  durationThreshold: 5000
});

// Lambda関数にアクセス
monitoredFunc.function.grantInvoke(apiGateway);
```

### Publishパターン

カスタムConstructをnpmパッケージとして公開:

```json
// package.json
{
  "name": "@mycompany/cdk-constructs",
  "version": "1.0.0",
  "main": "lib/index.js",
  "types": "lib/index.d.ts",
  "peerDependencies": {
    "aws-cdk-lib": "^2.0.0",
    "constructs": "^10.0.0"
  },
  "publishConfig": {
    "access": "public"
  }
}
```

```typescript
// lib/index.ts
export * from './monitored-lambda';
export * from './secure-bucket';
export * from './vpc-with-endpoints';
```

**インストールと使用**:
```bash
npm install @mycompany/cdk-constructs
```

```typescript
import { MonitoredLambda } from '@mycompany/cdk-constructs';
```

---

## カスタムResource

### CloudFormation Custom Resource

CDKで直接サポートされていないリソースやAPIを操作:

```typescript
import * as cr from 'aws-cdk-lib/custom-resources';
import * as logs from 'aws-cdk-lib/aws-logs';

// AWS APIを呼び出すCustom Resource
const describeImages = new cr.AwsCustomResource(this, 'DescribeImages', {
  onUpdate: {
    service: 'EC2',
    action: 'describeImages',
    parameters: {
      Owners: ['self'],
      Filters: [
        { Name: 'name', Values: ['my-ami-*'] }
      ]
    },
    physicalResourceId: cr.PhysicalResourceId.of(Date.now().toString())
  },
  policy: cr.AwsCustomResourcePolicy.fromSdkCalls({
    resources: cr.AwsCustomResourcePolicy.ANY_RESOURCE
  }),
  logRetention: logs.RetentionDays.ONE_DAY
});

// 結果を取得
const latestAmiId = describeImages.getResponseField('Images.0.ImageId');

// EC2インスタンスで使用
new ec2.Instance(this, 'Instance', {
  instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MICRO),
  machineImage: ec2.MachineImage.genericLinux({
    'us-east-1': latestAmiId
  }),
  vpc: vpc
});
```

### Provider Framework

複雑なCustom Resourceロジックを実装:

```typescript
import * as customResources from 'aws-cdk-lib/custom-resources';

// Custom Resource Providerの定義
const onEventHandler = new lambda.Function(this, 'OnEventHandler', {
  runtime: lambda.Runtime.NODEJS_20_X,
  handler: 'index.onEvent',
  code: lambda.Code.fromAsset('lambda/custom-resource')
});

const isCompleteHandler = new lambda.Function(this, 'IsCompleteHandler', {
  runtime: lambda.Runtime.NODEJS_20_X,
  handler: 'index.isComplete',
  code: lambda.Code.fromAsset('lambda/custom-resource')
});

const provider = new customResources.Provider(this, 'Provider', {
  onEventHandler: onEventHandler,
  isCompleteHandler: isCompleteHandler,
  logRetention: logs.RetentionDays.ONE_DAY,
  totalTimeout: cdk.Duration.minutes(30)
});

// Custom Resourceを使用
const customResource = new cdk.CustomResource(this, 'CustomResource', {
  serviceToken: provider.serviceToken,
  properties: {
    ClusterName: eksCluster.clusterName,
    Namespace: 'production',
    ServiceAccountName: 'app-sa'
  }
});
```

**Lambda Handler実装例**:

```typescript
// lambda/custom-resource/index.ts
import { IsCompleteResponse, OnEventResponse } from 'aws-cdk-lib/custom-resources/lib/provider-framework/types';

export async function onEvent(event: any): Promise<OnEventResponse> {
  console.log('Event:', JSON.stringify(event, null, 2));

  const requestType = event.RequestType;
  const properties = event.ResourceProperties;

  switch (requestType) {
    case 'Create':
      return onCreate(properties);
    case 'Update':
      return onUpdate(event.PhysicalResourceId, properties);
    case 'Delete':
      return onDelete(event.PhysicalResourceId);
  }

  throw new Error(`Invalid request type: ${requestType}`);
}

async function onCreate(props: any): Promise<OnEventResponse> {
  // リソース作成ロジック
  const physicalResourceId = `custom-${Date.now()}`;

  // 非同期処理の場合はIsCompleteハンドラーで完了を確認
  return {
    PhysicalResourceId: physicalResourceId,
    Data: {
      ResourceId: physicalResourceId
    }
  };
}

export async function isComplete(event: any): Promise<IsCompleteResponse> {
  const physicalResourceId = event.PhysicalResourceId;

  // リソースの状態を確認
  const isComplete = await checkResourceStatus(physicalResourceId);

  return {
    IsComplete: isComplete
  };
}

async function checkResourceStatus(id: string): Promise<boolean> {
  // 実際のステータスチェックロジック
  return true;
}
```

---

## テスト

### Fine-grained Assertions

特定のリソースプロパティを詳細に検証:

```typescript
import { Template, Match } from 'aws-cdk-lib/assertions';

describe('MyStack', () => {
  test('S3 Bucket has encryption enabled', () => {
    const app = new cdk.App();
    const stack = new MyStack(app, 'TestStack');
    const template = Template.fromStack(stack);

    template.hasResourceProperties('AWS::S3::Bucket', {
      BucketEncryption: {
        ServerSideEncryptionConfiguration: [{
          ServerSideEncryptionByDefault: {
            SSEAlgorithm: 'AES256'
          }
        }]
      },
      PublicAccessBlockConfiguration: {
        BlockPublicAcls: true,
        BlockPublicPolicy: true,
        IgnorePublicAcls: true,
        RestrictPublicBuckets: true
      }
    });
  });

  test('Lambda has correct environment variables', () => {
    const app = new cdk.App();
    const stack = new MyStack(app, 'TestStack');
    const template = Template.fromStack(stack);

    template.hasResourceProperties('AWS::Lambda::Function', {
      Environment: {
        Variables: {
          TABLE_NAME: Match.stringLikeRegexp('.*Table.*'),
          LOG_LEVEL: 'INFO'
        }
      }
    });
  });

  test('IAM Role has least privilege policy', () => {
    const app = new cdk.App();
    const stack = new MyStack(app, 'TestStack');
    const template = Template.fromStack(stack);

    template.hasResourceProperties('AWS::IAM::Role', {
      Policies: Match.arrayWith([{
        PolicyDocument: {
          Statement: Match.arrayWith([{
            Effect: 'Allow',
            Action: ['dynamodb:GetItem', 'dynamodb:PutItem'],
            Resource: Match.anyValue()
          }])
        }
      }])
    });
  });
});
```

### Snapshot Test

CloudFormationテンプレート全体をスナップショットとして保存:

```typescript
import { App } from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';

test('Stack snapshot', () => {
  const app = new App();
  const stack = new MyStack(app, 'TestStack');
  const template = Template.fromStack(stack);

  expect(template.toJSON()).toMatchSnapshot();
});
```

**注意**: Snapshotテストは変更検出に有効だが、意図した変更かどうかは人間が判断する必要がある。

### 統合テスト

実際にAWS環境にデプロイして動作を検証:

```typescript
import * as AWS from 'aws-sdk';
import { execFileSync } from 'child_process';

describe('Integration Tests', () => {
  let stackName: string;
  let cfn: AWS.CloudFormation;

  beforeAll(async () => {
    stackName = `IntegTest-${Date.now()}`;

    // CDKデプロイ（execFileを使用して安全に実行）
    execFileSync('npx', ['cdk', 'deploy', stackName, '--require-approval', 'never'], {
      stdio: 'inherit'
    });

    cfn = new AWS.CloudFormation();
  });

  afterAll(async () => {
    // スタック削除
    await cfn.deleteStack({ StackName: stackName }).promise();
  });

  test('Lambda function is invocable', async () => {
    const lambda = new AWS.Lambda();

    // Lambda関数名を取得
    const outputs = await getStackOutputs(stackName);
    const functionName = outputs.LambdaFunctionName;

    // Lambda呼び出し
    const result = await lambda.invoke({
      FunctionName: functionName,
      InvocationType: 'RequestResponse',
      Payload: JSON.stringify({ key: 'value' })
    }).promise();

    const payload = JSON.parse(result.Payload as string);
    expect(payload.statusCode).toBe(200);
  });
});

async function getStackOutputs(stackName: string): Promise<Record<string, string>> {
  const cfn = new AWS.CloudFormation();
  const result = await cfn.describeStacks({ StackName: stackName }).promise();

  const outputs: Record<string, string> = {};
  result.Stacks?.[0].Outputs?.forEach(output => {
    if (output.OutputKey && output.OutputValue) {
      outputs[output.OutputKey] = output.OutputValue;
    }
  });

  return outputs;
}
```

---

## DevSecOps

### cdk-nag

セキュリティとコンプライアンスのベストプラクティスを検証:

```typescript
import { Aspects } from 'aws-cdk-lib';
import { AwsSolutionsChecks, NagSuppressions } from 'cdk-nag';

const app = new cdk.App();
const stack = new MyStack(app, 'MyStack');

// cdk-nagをアプリケーション全体に適用
Aspects.of(app).add(new AwsSolutionsChecks({ verbose: true }));

// 特定のルールを抑制
NagSuppressions.addResourceSuppressionsByPath(
  stack,
  '/MyStack/MyBucket/Resource',
  [
    {
      id: 'AwsSolutions-S1',
      reason: 'This is a logging bucket, so server access logging is not required'
    }
  ]
);

// スタック全体でルールを抑制
NagSuppressions.addStackSuppressions(stack, [
  {
    id: 'AwsSolutions-IAM4',
    reason: 'Using AWS managed policies for simplicity in this demo'
  }
]);
```

**主要なcdk-nagルール**:
- `AwsSolutions-S1`: S3バケットのサーバーアクセスログ
- `AwsSolutions-S2`: S3バケットのパブリックアクセスブロック
- `AwsSolutions-IAM4`: AWS管理ポリシーの使用
- `AwsSolutions-L1`: Lambda最新ランタイムの使用
- `AwsSolutions-RDS2`: RDSの暗号化

### CDK Pipelines

セルフミューテーティングなCI/CDパイプライン:

```typescript
import { pipelines } from 'aws-cdk-lib';
import * as codepipeline from 'aws-cdk-lib/aws-codepipeline';
import * as codepipeline_actions from 'aws-cdk-lib/aws-codepipeline-actions';

export class PipelineStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const pipeline = new pipelines.CodePipeline(this, 'Pipeline', {
      pipelineName: 'MyAppPipeline',
      synth: new pipelines.ShellStep('Synth', {
        input: pipelines.CodePipelineSource.gitHub('owner/repo', 'main'),
        commands: [
          'npm ci',
          'npm run build',
          'npx cdk synth'
        ]
      }),
      selfMutation: true,
      dockerEnabledForSynth: true
    });

    // テストステージ
    const testStage = new MyAppStage(this, 'Test', {
      env: { account: '111111111111', region: 'us-east-1' }
    });

    pipeline.addStage(testStage, {
      pre: [
        new pipelines.ShellStep('UnitTests', {
          commands: ['npm test']
        })
      ],
      post: [
        new pipelines.ShellStep('IntegrationTests', {
          commands: ['npm run test:integration'],
          envFromCfnOutputs: {
            API_URL: testStage.apiUrl
          }
        })
      ]
    });

    // 本番ステージ（手動承認付き）
    const prodStage = new MyAppStage(this, 'Prod', {
      env: { account: '222222222222', region: 'us-west-2' }
    });

    pipeline.addStage(prodStage, {
      pre: [
        new pipelines.ManualApprovalStep('PromoteToProd')
      ]
    });
  }
}

// アプリケーションステージ
class MyAppStage extends cdk.Stage {
  public readonly apiUrl: cdk.CfnOutput;

  constructor(scope: Construct, id: string, props?: cdk.StageProps) {
    super(scope, id, props);

    const stack = new MyAppStack(this, 'MyAppStack');

    this.apiUrl = stack.apiUrl;
  }
}
```

### セキュリティスキャン

CodeBuildでセキュリティツールを実行:

```typescript
import * as codebuild from 'aws-cdk-lib/aws-codebuild';

const securityScanProject = new codebuild.Project(this, 'SecurityScan', {
  buildSpec: codebuild.BuildSpec.fromObject({
    version: '0.2',
    phases: {
      install: {
        commands: [
          'npm install -g snyk',
          'pip install checkov'
        ]
      },
      build: {
        commands: [
          // 依存関係の脆弱性スキャン
          'snyk test --severity-threshold=high',
          // IaCのセキュリティスキャン
          'checkov -d . --framework cloudformation',
          // cdk-nag実行
          'npm run cdk:nag'
        ]
      }
    },
    reports: {
      securityReport: {
        files: ['**/*'],
        'file-format': 'JUNITXML'
      }
    }
  })
});

// Pipelineに統合
pipeline.addStage(testStage, {
  pre: [
    new pipelines.CodeBuildStep('SecurityScan', {
      project: securityScanProject
    })
  ]
});
```

---

## コード例

### TypeScript完全なサンプル

```typescript
#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ecs_patterns from 'aws-cdk-lib/aws-ecs-patterns';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import { Construct } from 'constructs';

/**
 * フルスタックWebアプリケーション
 * - ALB + Fargate + RDS Aurora
 */
class WebAppStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // VPC
    const vpc = new ec2.Vpc(this, 'Vpc', {
      maxAzs: 2,
      natGateways: 1,
      subnetConfiguration: [
        {
          name: 'Public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24
        },
        {
          name: 'Private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
          cidrMask: 24
        },
        {
          name: 'Isolated',
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24
        }
      ]
    });

    // データベース認証情報
    const dbSecret = new secretsmanager.Secret(this, 'DbSecret', {
      generateSecretString: {
        secretStringTemplate: JSON.stringify({ username: 'admin' }),
        generateStringKey: 'password',
        excludePunctuation: true
      }
    });

    // Aurora Serverless v2
    const dbCluster = new rds.DatabaseCluster(this, 'Database', {
      engine: rds.DatabaseClusterEngine.auroraPostgres({
        version: rds.AuroraPostgresEngineVersion.VER_15_3
      }),
      writer: rds.ClusterInstance.serverlessV2('Writer'),
      readers: [
        rds.ClusterInstance.serverlessV2('Reader', { scaleWithWriter: true })
      ],
      vpc: vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      credentials: rds.Credentials.fromSecret(dbSecret),
      serverlessV2MinCapacity: 0.5,
      serverlessV2MaxCapacity: 2
    });

    // Fargateサービス
    const fargateService = new ecs_patterns.ApplicationLoadBalancedFargateService(
      this, 'WebApp', {
        vpc: vpc,
        taskImageOptions: {
          image: ecs.ContainerImage.fromRegistry('myapp:latest'),
          containerPort: 3000,
          environment: {
            NODE_ENV: 'production',
            DB_HOST: dbCluster.clusterEndpoint.hostname
          },
          secrets: {
            DB_PASSWORD: ecs.Secret.fromSecretsManager(dbSecret, 'password')
          }
        },
        desiredCount: 2,
        cpu: 512,
        memoryLimitMiB: 1024,
        publicLoadBalancer: true,
        healthCheckGracePeriod: cdk.Duration.seconds(60)
      }
    );

    // データベース接続を許可
    dbCluster.connections.allowDefaultPortFrom(fargateService.service);

    // オートスケーリング
    const scaling = fargateService.service.autoScaleTaskCount({
      minCapacity: 2,
      maxCapacity: 10
    });

    scaling.scaleOnCpuUtilization('CpuScaling', {
      targetUtilizationPercent: 70,
      scaleInCooldown: cdk.Duration.seconds(60),
      scaleOutCooldown: cdk.Duration.seconds(60)
    });

    // Outputs
    new cdk.CfnOutput(this, 'LoadBalancerDNS', {
      value: fargateService.loadBalancer.loadBalancerDnsName,
      description: 'ALB DNS name'
    });

    new cdk.CfnOutput(this, 'DatabaseEndpoint', {
      value: dbCluster.clusterEndpoint.hostname,
      description: 'Database cluster endpoint'
    });
  }
}

const app = new cdk.App();
new WebAppStack(app, 'WebAppStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION
  }
});
```

### Python完全なサンプル

```python
#!/usr/bin/env python3
from aws_cdk import (
    App, Stack, CfnOutput, Duration,
    aws_ec2 as ec2,
    aws_ecs as ecs,
    aws_ecs_patterns as ecs_patterns,
    aws_rds as rds,
    aws_secretsmanager as secretsmanager
)
from constructs import Construct

class WebAppStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # VPC
        vpc = ec2.Vpc(
            self, "Vpc",
            max_azs=2,
            nat_gateways=1,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="Public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="Private",
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                    cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="Isolated",
                    subnet_type=ec2.SubnetType.PRIVATE_ISOLATED,
                    cidr_mask=24
                )
            ]
        )

        # データベース認証情報
        db_secret = secretsmanager.Secret(
            self, "DbSecret",
            generate_secret_string=secretsmanager.SecretStringGenerator(
                secret_string_template='{"username": "admin"}',
                generate_string_key="password",
                exclude_punctuation=True
            )
        )

        # Aurora Serverless v2
        db_cluster = rds.DatabaseCluster(
            self, "Database",
            engine=rds.DatabaseClusterEngine.aurora_postgres(
                version=rds.AuroraPostgresEngineVersion.VER_15_3
            ),
            writer=rds.ClusterInstance.serverless_v2("Writer"),
            readers=[
                rds.ClusterInstance.serverless_v2("Reader", scale_with_writer=True)
            ],
            vpc=vpc,
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_ISOLATED),
            credentials=rds.Credentials.from_secret(db_secret),
            serverless_v2_min_capacity=0.5,
            serverless_v2_max_capacity=2
        )

        # Fargateサービス
        fargate_service = ecs_patterns.ApplicationLoadBalancedFargateService(
            self, "WebApp",
            vpc=vpc,
            task_image_options=ecs_patterns.ApplicationLoadBalancedTaskImageOptions(
                image=ecs.ContainerImage.from_registry("myapp:latest"),
                container_port=3000,
                environment={
                    "NODE_ENV": "production",
                    "DB_HOST": db_cluster.cluster_endpoint.hostname
                },
                secrets={
                    "DB_PASSWORD": ecs.Secret.from_secrets_manager(db_secret, "password")
                }
            ),
            desired_count=2,
            cpu=512,
            memory_limit_mib=1024,
            public_load_balancer=True,
            health_check_grace_period=Duration.seconds(60)
        )

        # データベース接続を許可
        db_cluster.connections.allow_default_port_from(fargate_service.service)

        # オートスケーリング
        scaling = fargate_service.service.auto_scale_task_count(
            min_capacity=2,
            max_capacity=10
        )

        scaling.scale_on_cpu_utilization(
            "CpuScaling",
            target_utilization_percent=70,
            scale_in_cooldown=Duration.seconds(60),
            scale_out_cooldown=Duration.seconds(60)
        )

        # Outputs
        CfnOutput(
            self, "LoadBalancerDNS",
            value=fargate_service.load_balancer.load_balancer_dns_name,
            description="ALB DNS name"
        )

        CfnOutput(
            self, "DatabaseEndpoint",
            value=db_cluster.cluster_endpoint.hostname,
            description="Database cluster endpoint"
        )

app = App()
WebAppStack(app, "WebAppStack")
app.synth()
```
