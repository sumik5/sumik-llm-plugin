# Security on AWS

AWS上でのセキュリティ実践ガイド。IAM、VPCセキュリティ、データ保護、認証・認可、EKSセキュリティ、およびコンプライアンスをカバーします。

---

## 1. IAM (Identity and Access Management)

### 1.1 最小権限の原則

**悪い例（過剰な権限）:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
```

**良い例（必要最小限の権限）:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowDynamoDBReadWrite",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/Orders"
    },
    {
      "Sid": "AllowS3ReadOnly",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-app-assets",
        "arn:aws:s3:::my-app-assets/*"
      ]
    }
  ]
}
```

### 1.2 IAM Role（EC2/Lambda）

**Lambda実行ロール:**

```yaml
Resources:
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: OrderProcessorRole
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: OrderProcessorPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - dynamodb:GetItem
                  - dynamodb:PutItem
                Resource: !GetAtt OrdersTable.Arn
              - Effect: Allow
                Action:
                  - sqs:SendMessage
                Resource: !GetAtt NotificationQueue.Arn
              - Effect: Allow
                Action:
                  - secretsmanager:GetSecretValue
                Resource: !Ref APIKeySecret
```

### 1.3 条件キー（Condition Keys）

**特定VPCからのみアクセス許可:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::my-secure-bucket/*",
      "Condition": {
        "StringEquals": {
          "aws:SourceVpc": "vpc-12345678"
        }
      }
    }
  ]
}
```

**MFA必須:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:StopInstances",
      "Resource": "*",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
```

**特定時間帯のみアクセス許可:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "dynamodb:*",
      "Resource": "*",
      "Condition": {
        "DateGreaterThan": {
          "aws:CurrentTime": "2024-01-01T09:00:00Z"
        },
        "DateLessThan": {
          "aws:CurrentTime": "2024-01-01T18:00:00Z"
        }
      }
    }
  ]
}
```

**特定IPからのみアクセス許可:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "NotIpAddress": {
          "aws:SourceIp": [
            "203.0.113.0/24",
            "198.51.100.0/24"
          ]
        }
      }
    }
  ]
}
```

### 1.4 AWS Organizations SCP (Service Control Policy)

組織レベルでの権限制限:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllOutsideApprovedRegions",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "us-east-1",
            "us-west-2",
            "ap-northeast-1"
          ]
        }
      }
    },
    {
      "Sid": "DenyRootAccountUsage",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:root"
        }
      }
    },
    {
      "Sid": "RequireMFAForHighRiskActions",
      "Effect": "Deny",
      "Action": [
        "ec2:TerminateInstances",
        "rds:DeleteDBInstance",
        "s3:DeleteBucket"
      ],
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
```

---

## 2. VPC セキュリティ

### 2.1 セキュリティグループ vs NACL

| 項目 | セキュリティグループ | NACL |
|------|-------------------|------|
| **レベル** | インスタンス（ENI） | サブネット |
| **ステート** | ステートフル（戻りトラフィック自動許可） | ステートレス（明示的に許可が必要） |
| **ルール** | 許可のみ | 許可 + 拒否 |
| **評価順序** | 全ルール評価 | ルール番号順に評価 |
| **変更反映** | 即座 | 即座 |

### 2.2 セキュリティグループ設計

**Web層（ALB）:**

```yaml
Resources:
  ALBSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: alb-security-group
      GroupDescription: 'ALB security group'
      VpcId: !Ref VPC
      SecurityGroupIngress:
        # HTTPSのみ許可
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
          Description: 'HTTPS from internet'
      SecurityGroupEgress:
        # アプリケーション層へのアウトバウンドのみ
        - IpProtocol: tcp
          FromPort: 8080
          ToPort: 8080
          DestinationSecurityGroupId: !Ref AppSecurityGroup
          Description: 'To application layer'
```

**アプリケーション層（EC2/ECS）:**

```yaml
  AppSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: app-security-group
      GroupDescription: 'Application security group'
      VpcId: !Ref VPC
      SecurityGroupIngress:
        # ALBからのみ許可
        - IpProtocol: tcp
          FromPort: 8080
          ToPort: 8080
          SourceSecurityGroupId: !Ref ALBSecurityGroup
          Description: 'From ALB'
      SecurityGroupEgress:
        # データベースへのアクセス
        - IpProtocol: tcp
          FromPort: 5432
          ToPort: 5432
          DestinationSecurityGroupId: !Ref DBSecurityGroup
          Description: 'To PostgreSQL'
        # 外部APIへのHTTPS
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
          Description: 'To external APIs'
```

**データベース層（RDS）:**

```yaml
  DBSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: db-security-group
      GroupDescription: 'Database security group'
      VpcId: !Ref VPC
      SecurityGroupIngress:
        # アプリケーション層からのみ許可
        - IpProtocol: tcp
          FromPort: 5432
          ToPort: 5432
          SourceSecurityGroupId: !Ref AppSecurityGroup
          Description: 'From application layer'
      SecurityGroupEgress:
        # 外部への通信は不要（デフォルトで全拒否）
        - IpProtocol: -1
          CidrIp: 127.0.0.1/32
          Description: 'Block all outbound'
```

### 2.3 VPCエンドポイント（PrivateLink）

外部インターネットを経由せずにAWSサービスにアクセス:

```yaml
Resources:
  # S3用ゲートウェイエンドポイント
  S3Endpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub 'com.amazonaws.${AWS::Region}.s3'
      VpcEndpointType: Gateway
      RouteTableIds:
        - !Ref PrivateRouteTable

  # DynamoDB用ゲートウェイエンドポイント
  DynamoDBEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub 'com.amazonaws.${AWS::Region}.dynamodb'
      VpcEndpointType: Gateway
      RouteTableIds:
        - !Ref PrivateRouteTable

  # Secrets Manager用インターフェースエンドポイント
  SecretsManagerEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub 'com.amazonaws.${AWS::Region}.secretsmanager'
      VpcEndpointType: Interface
      SubnetIds:
        - !Ref PrivateSubnet1
        - !Ref PrivateSubnet2
      SecurityGroupIds:
        - !Ref VPCEndpointSecurityGroup
      PrivateDnsEnabled: true
```

---

## 3. データ保護

### 3.1 AWS KMS（暗号化キー管理）

**CMK（Customer Master Key）作成:**

```yaml
Resources:
  EncryptionKey:
    Type: AWS::KMS::Key
    Properties:
      Description: 'Application data encryption key'
      KeyPolicy:
        Version: '2012-10-17'
        Statement:
          # アカウントルートユーザーに管理権限
          - Sid: Enable IAM policies
            Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: 'kms:*'
            Resource: '*'

          # Lambda実行ロールに暗号化・復号権限
          - Sid: Allow use of key
            Effect: Allow
            Principal:
              AWS: !GetAtt LambdaExecutionRole.Arn
            Action:
              - 'kms:Decrypt'
              - 'kms:DescribeKey'
              - 'kms:GenerateDataKey'
            Resource: '*'

  EncryptionKeyAlias:
    Type: AWS::KMS::Alias
    Properties:
      AliasName: alias/my-app-encryption-key
      TargetKeyId: !Ref EncryptionKey
```

### 3.2 S3暗号化

**バケット暗号化設定:**

```yaml
Resources:
  SecureDataBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: my-secure-data-bucket
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: aws:kms
              KMSMasterKeyID: !Ref EncryptionKey
            BucketKeyEnabled: true  # コスト削減

      # バージョニング有効化
      VersioningConfiguration:
        Status: Enabled

      # パブリックアクセスブロック（必須）
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

      # アクセスログ
      LoggingConfiguration:
        DestinationBucketName: !Ref LogBucket
        LogFilePrefix: s3-access-logs/
```

**バケットポリシー（HTTPS必須）:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::my-secure-data-bucket",
        "arn:aws:s3:::my-secure-data-bucket/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

### 3.3 RDS暗号化

```yaml
Resources:
  EncryptedDB:
    Type: AWS::RDS::DBInstance
    Properties:
      Engine: postgres
      EngineVersion: '15.3'
      DBInstanceClass: db.t3.medium
      AllocatedStorage: 100
      StorageEncrypted: true  # ストレージ暗号化
      KmsKeyId: !Ref EncryptionKey
      EnableCloudwatchLogsExports:
        - postgresql
      BackupRetentionPeriod: 7
      PreferredBackupWindow: '03:00-04:00'
      DeletionProtection: true  # 削除保護
```

---

## 4. 認証・認可

### 4.1 Amazon Cognito User Pool

```yaml
Resources:
  UserPool:
    Type: AWS::Cognito::UserPool
    Properties:
      UserPoolName: MyAppUserPool
      AutoVerifiedAttributes:
        - email
      UsernameAttributes:
        - email
      Schema:
        - Name: email
          Required: true
          Mutable: false
        - Name: name
          Required: true
          Mutable: true

      # パスワードポリシー
      Policies:
        PasswordPolicy:
          MinimumLength: 12
          RequireUppercase: true
          RequireLowercase: true
          RequireNumbers: true
          RequireSymbols: true
          TemporaryPasswordValidityDays: 3

      # MFA設定
      MfaConfiguration: OPTIONAL
      EnabledMfas:
        - SOFTWARE_TOKEN_MFA

      # アカウント復旧設定
      AccountRecoverySetting:
        RecoveryMechanisms:
          - Name: verified_email
            Priority: 1

  UserPoolClient:
    Type: AWS::Cognito::UserPoolClient
    Properties:
      ClientName: web-client
      UserPoolId: !Ref UserPool
      GenerateSecret: false
      ExplicitAuthFlows:
        - ALLOW_USER_SRP_AUTH
        - ALLOW_REFRESH_TOKEN_AUTH
      PreventUserExistenceErrors: ENABLED
      AccessTokenValidity: 1
      IdTokenValidity: 1
      RefreshTokenValidity: 30
      TokenValidityUnits:
        AccessToken: hours
        IdToken: hours
        RefreshToken: days
```

### 4.2 Cognito Identity Pool（AWS リソースアクセス）

```yaml
Resources:
  IdentityPool:
    Type: AWS::Cognito::IdentityPool
    Properties:
      IdentityPoolName: MyAppIdentityPool
      AllowUnauthenticatedIdentities: false
      CognitoIdentityProviders:
        - ClientId: !Ref UserPoolClient
          ProviderName: !GetAtt UserPool.ProviderName

  # 認証済みユーザーロール
  AuthenticatedRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Federated: cognito-identity.amazonaws.com
            Action: sts:AssumeRoleWithWebIdentity
            Condition:
              StringEquals:
                'cognito-identity.amazonaws.com:aud': !Ref IdentityPool
              'ForAnyValue:StringLike':
                'cognito-identity.amazonaws.com:amr': authenticated
      Policies:
        - PolicyName: UserS3Access
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              # ユーザー固有のS3プレフィックスにのみアクセス可能
              - Effect: Allow
                Action:
                  - 's3:GetObject'
                  - 's3:PutObject'
                Resource: !Sub 'arn:aws:s3:::my-user-data-bucket/users/${cognito-identity.amazonaws.com:sub}/*'

  IdentityPoolRoleAttachment:
    Type: AWS::Cognito::IdentityPoolRoleAttachment
    Properties:
      IdentityPoolId: !Ref IdentityPool
      Roles:
        authenticated: !GetAtt AuthenticatedRole.Arn
```

### 4.3 API Gateway認証

**Cognito Authorizer:**

```yaml
Resources:
  CognitoAuthorizer:
    Type: AWS::ApiGateway::Authorizer
    Properties:
      Name: CognitoAuthorizer
      Type: COGNITO_USER_POOLS
      RestApiId: !Ref MyApi
      ProviderARNs:
        - !GetAtt UserPool.Arn
      IdentitySource: method.request.header.Authorization

  # 保護されたAPIリソース
  ProtectedResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref MyApi
      ParentId: !GetAtt MyApi.RootResourceId
      PathPart: protected

  ProtectedMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref MyApi
      ResourceId: !Ref ProtectedResource
      HttpMethod: GET
      AuthorizationType: COGNITO_USER_POOLS
      AuthorizerId: !Ref CognitoAuthorizer
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${MyFunction.Arn}/invocations'
```

**Lambda Authorizer（カスタム認証）:**

```python
import json
import jwt
from jwt import PyJWKClient

COGNITO_REGION = 'us-east-1'
COGNITO_USER_POOL_ID = 'us-east-1_XXXXXXXXX'
COGNITO_APP_CLIENT_ID = 'xxxxxxxxxxxxxxxxxxxxxxxxxx'

jwks_url = f'https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json'
jwks_client = PyJWKClient(jwks_url)

def lambda_handler(event, context):
    token = event['authorizationToken'].replace('Bearer ', '')

    try:
        # JWTトークン検証
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=['RS256'],
            audience=COGNITO_APP_CLIENT_ID
        )

        # カスタムロジック（例: ロールベースアクセス制御）
        user_role = payload.get('custom:role', 'user')

        # IAMポリシー生成
        policy = generate_policy(
            principal_id=payload['sub'],
            effect='Allow' if user_role in ['admin', 'user'] else 'Deny',
            resource=event['methodArn'],
            context={
                'userId': payload['sub'],
                'email': payload['email'],
                'role': user_role
            }
        )

        return policy

    except Exception as e:
        print(f'Authorization failed: {e}')
        raise Exception('Unauthorized')

def generate_policy(principal_id, effect, resource, context=None):
    return {
        'principalId': principal_id,
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [
                {
                    'Action': 'execute-api:Invoke',
                    'Effect': effect,
                    'Resource': resource
                }
            ]
        },
        'context': context or {}
    }
```

---

## 5. EKS セキュリティ

### 5.1 IRSA (IAM Roles for Service Accounts)

**ServiceAccount作成:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/MyAppRole
```

**IAM Role + Trust Policy:**

```yaml
Resources:
  EKSServiceAccountRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: MyAppRole
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Federated: !Sub 'arn:aws:iam::${AWS::AccountId}:oidc-provider/${EKSClusterOIDCProvider}'
            Action: sts:AssumeRoleWithWebIdentity
            Condition:
              StringEquals:
                '${EKSClusterOIDCProvider}:sub': 'system:serviceaccount:default:my-app-sa'
      Policies:
        - PolicyName: S3Access
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:GetObject'
                  - 's3:PutObject'
                Resource: 'arn:aws:s3:::my-app-bucket/*'
```

### 5.2 Pod Security Standards

**Restricted ポリシー適用:**

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

**SecurityContext設定:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault

  containers:
    - name: app
      image: my-app:latest
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL

      volumeMounts:
        - name: tmp
          mountPath: /tmp

  volumes:
    - name: tmp
      emptyDir: {}
```

### 5.3 Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
    - Ingress
    - Egress

  # Ingressルール（入力トラフィック）
  ingress:
    # ALB Ingress Controllerからのみ許可
    - from:
        - namespaceSelector:
            matchLabels:
              name: kube-system
          podSelector:
            matchLabels:
              app.kubernetes.io/name: aws-load-balancer-controller
      ports:
        - protocol: TCP
          port: 8080

  # Egressルール（出力トラフィック）
  egress:
    # DNS解決許可
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53

    # データベースへのアクセス許可
    - to:
        - podSelector:
            matchLabels:
              app: postgresql
      ports:
        - protocol: TCP
          port: 5432

    # 外部APIへのHTTPS許可
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

### 5.4 Secrets Manager統合

**External Secrets Operator:**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
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
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore

  target:
    name: app-secrets
    creationPolicy: Owner

  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: prod/database
        property: url
    - secretKey: API_KEY
      remoteRef:
        key: prod/api
        property: key
```

---

## 6. コンプライアンス

### 6.1 AWS Config Rules

```yaml
Resources:
  # S3バケット暗号化必須
  S3EncryptionRule:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: s3-bucket-encryption-enabled
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED

  # EBS暗号化必須
  EBSEncryptionRule:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: ec2-ebs-encryption-by-default
      Source:
        Owner: AWS
        SourceIdentifier: EC2_EBS_ENCRYPTION_BY_DEFAULT

  # RDSパブリックアクセス禁止
  RDSPublicAccessRule:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: rds-instance-public-access-check
      Source:
        Owner: AWS
        SourceIdentifier: RDS_INSTANCE_PUBLIC_ACCESS_CHECK

  # IAMルートユーザーMFA必須
  RootMFARule:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: root-account-mfa-enabled
      Source:
        Owner: AWS
        SourceIdentifier: ROOT_ACCOUNT_MFA_ENABLED
```

### 6.2 AWS GuardDuty

```yaml
Resources:
  GuardDutyDetector:
    Type: AWS::GuardDuty::Detector
    Properties:
      Enable: true
      FindingPublishingFrequency: FIFTEEN_MINUTES

  # GuardDuty検出結果をEventBridgeへ
  GuardDutyEventRule:
    Type: AWS::Events::Rule
    Properties:
      Name: guardduty-findings
      Description: 'GuardDuty脅威検出時に通知'
      EventPattern:
        source:
          - aws.guardduty
        detail-type:
          - GuardDuty Finding
        detail:
          severity:
            - 4.0
            - 4.1
            - 4.2
            - 4.3
            - 4.4
            - 4.5
            - 4.6
            - 4.7
            - 4.8
            - 4.9
            - 5.0
            - 5.1
            - 5.2
            - 5.3
            - 5.4
            - 5.5
            - 5.6
            - 5.7
            - 5.8
            - 5.9
            - 6.0
            - 6.1
            - 6.2
            - 6.3
            - 6.4
            - 6.5
            - 6.6
            - 6.7
            - 6.8
            - 6.9
            - 7.0
            - 7.1
            - 7.2
            - 7.3
            - 7.4
            - 7.5
            - 7.6
            - 7.7
            - 7.8
            - 7.9
            - 8.0
            - 8.1
            - 8.2
            - 8.3
            - 8.4
            - 8.5
            - 8.6
            - 8.7
            - 8.8
            - 8.9
      State: ENABLED
      Targets:
        - Arn: !Ref SecurityAlertTopic
          Id: SecurityTeamNotification
```

### 6.3 AWS Security Hub

```yaml
Resources:
  SecurityHub:
    Type: AWS::SecurityHub::Hub
    Properties:
      Tags:
        Environment: production

  # CIS AWS Foundations Benchmark有効化
  CISStandard:
    Type: AWS::SecurityHub::Standard
    Properties:
      StandardsArn: !Sub 'arn:aws:securityhub:${AWS::Region}::standards/cis-aws-foundations-benchmark/v/1.2.0'

  # AWS Foundational Security Best Practices有効化
  BestPracticesStandard:
    Type: AWS::SecurityHub::Standard
    Properties:
      StandardsArn: !Sub 'arn:aws:securityhub:${AWS::Region}::standards/aws-foundational-security-best-practices/v/1.0.0'
```

---

## 7. ベストプラクティス

### 7.1 セキュリティチェックリスト

```markdown
## IAM

- [ ] ルートアカウントにMFA設定
- [ ] ルートアカウントのアクセスキーを削除
- [ ] IAMユーザーに最小権限ポリシー適用
- [ ] IAM Roleでサービス間認証（アクセスキー禁止）
- [ ] パスワードポリシーを強化

## ネットワーク

- [ ] VPCエンドポイントで内部通信
- [ ] セキュリティグループで最小ポート開放
- [ ] NACLで追加の境界防御
- [ ] パブリックサブネットは必要最小限

## データ保護

- [ ] 保存データは全てKMS暗号化
- [ ] 通信はHTTPS/TLS必須
- [ ] S3バケットのパブリックアクセスブロック
- [ ] データベースのバックアップ暗号化

## モニタリング

- [ ] CloudTrail全リージョンで有効化
- [ ] GuardDuty脅威検出有効化
- [ ] Config Rules でコンプライアンス自動チェック
- [ ] Security Hub で統合ダッシュボード

## コンテナ

- [] ECRイメージスキャン有効化
- [ ] EKS Pod Security Standards適用
- [ ] IRSA でPodにIAM Role割り当て
- [] Network Policy で通信制限
```

### 7.2 セキュリティ自動化

**Lambda関数でS3バケットのパブリック公開を自動修正:**

```python
import boto3

s3 = boto3.client('s3')

def lambda_handler(event, context):
    """Config Rules違反時に自動修正"""
    bucket_name = event['configRuleNames'][0]['resourceId']

    # パブリックアクセスブロック設定
    s3.put_public_access_block(
        Bucket=bucket_name,
        PublicAccessBlockConfiguration={
            'BlockPublicAcls': True,
            'IgnorePublicAcls': True,
            'BlockPublicPolicy': True,
            'RestrictPublicBuckets': True
        }
    )

    print(f'Bucket {bucket_name} のパブリックアクセスをブロックしました')

    return {'statusCode': 200}
```

---

## 参考リソース

### AWS公式ドキュメント

- [AWS IAM User Guide](https://docs.aws.amazon.com/iam/)
- [AWS VPC Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/security-best-practices.html)
- [AWS KMS Developer Guide](https://docs.aws.amazon.com/kms/)
- [Amazon Cognito Developer Guide](https://docs.aws.amazon.com/cognito/)
- [EKS Security Best Practices](https://docs.aws.amazon.com/eks/latest/best-practices/security.html)

### セキュリティツール

- [AWS Security Hub](https://aws.amazon.com/security-hub/)
- [AWS GuardDuty](https://aws.amazon.com/guardduty/)
- [AWS Config](https://aws.amazon.com/config/)
- [AWS CloudTrail](https://aws.amazon.com/cloudtrail/)
