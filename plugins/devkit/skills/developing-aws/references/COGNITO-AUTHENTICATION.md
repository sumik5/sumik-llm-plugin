# Amazon Cognito 認証・認可ガイド

Cognitoを利用したユーザー認証・認可の設計・実装リファレンス。User Pools・Federated Identities（Identity Pool）・API Gateway統合・Google OAuth連携をカバーします。

> **SECURITY.md との役割分担**
> - IAMポリシー/ロールの詳細 → `SECURITY.md`
> - VPC/ネットワークセキュリティ → `SECURITY-ADVANCED.md`
> - **本ファイル** → Cognito認証に特化した設計・実装パターン

---

## 1. Amazon Cognito 概要

### 1.1 なぜ Cognito が必要か

モバイルアプリ・ブラウザJavaScriptからAWSリソースを直接操作する場合、アクセスキーをアプリに埋め込むことはセキュリティ上できません。EC2のようにIAMロールを直接付与することも不特定多数の端末では不可能です。

Cognitoはこの問題を解決します。認証に成功したユーザーに **一時的な認証情報（Temporary Credentials）** を払い出し、AWSリソースの操作権限を与えます。

### 1.2 Cognito のサービス構成

| サービス | 役割 |
|---------|------|
| **Cognito Identity** | 認証・認可の統合サービス |
| ↳ **User Pools** | 独自のIdentity Provider（ユーザーディレクトリ）を提供 |
| ↳ **Federated Identities（Identity Pool）** | 認証済みユーザーにAWSリソース操作の一時キーを付与 |
| **Cognito Sync** | 同じアカウントを持つ複数デバイス間でデータを同期 |

```
【認証担当】         【認可担当】
User Pools     →   Federated Identities   →   AWS リソース
（誰であるか）       （何ができるか）            （S3, DynamoDB等）
```

### 1.3 主要な認証フロー（3ステップモデル）

1. **Identity Providerによる認証** — Facebook/Google/User Pools等で本人確認
2. **CognitoによるCredentialトークン発行** — 認証成功時に信頼済みトークンを発行
3. **IAMロールによる権限付与** — トークンをもとに一時的なAWS操作権限を付与

---

## 2. User Pools（ユーザープール）

### 2.1 User Pools とは

User Poolsは、フルマネージドなIdentity Providerサービスです。ユーザーのサインアップ・サインイン・サインアウトなどの認証機構を提供します。

**提供される標準機能：**

- ユーザーディレクトリ管理（メールアドレス・カスタム属性）
- 電話番号/メールアドレスの有効性確認
- SMSベースの多要素認証（MFA）
- パスワード紛失時のリセット機能
- 認証イベントトリガー（Lambda連携）

### 2.2 User Pool の CloudFormation 定義

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

      # MFA設定（OPTIONAL / ON / OFF）
      MfaConfiguration: OPTIONAL
      EnabledMfas:
        - SOFTWARE_TOKEN_MFA

      # アカウント復旧
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
      # トークン有効期限
      AccessTokenValidity: 1
      IdTokenValidity: 1
      RefreshTokenValidity: 30
      TokenValidityUnits:
        AccessToken: hours
        IdToken: hours
        RefreshToken: days
```

### 2.3 Lambda トリガー（認証イベント連携）

User Poolsは認証ライフサイクルイベントでLambdaを呼び出せます。

| トリガーイベント | ユースケース例 |
|----------------|--------------|
| Pre sign-up | カスタムバリデーション（メールドメイン制限等） |
| Post confirmation | サインアップ完了後のDB初期化処理 |
| Pre authentication | 追加の認証ロジック |
| Post authentication | ログイン時のサードパーティ通知 |
| Define auth challenge | カスタム認証チャレンジ |

### 2.4 User Pools でできること・できないこと

| 機能 | User Pools | 独自実装 |
|------|-----------|---------|
| ユーザー登録/ログイン | ✅ フルマネージド | 要実装 |
| メール/SMS確認 | ✅ 標準提供 | 要実装 |
| パスワードリセット | ✅ 標準提供 | 要実装 |
| MFA | ✅ SMS/TOTP対応 | 要実装 |
| ユーザー細粒度認可 | ❌ IAMロールレベル | Lambda等で実装 |
| AWSリソース直接アクセス | ❌ Federated Identities必要 | — |

---

## 3. Federated Identities（Identity Pool）

### 3.1 Federated Identities とは

Federated IdentitiesはAWSリソースを操作するための **一時キー（Temporary Credentials）** を払い出す役割を持ちます。**User Poolsが認証担当、Federated Identitiesが認可担当** と理解してください。

### 3.2 対応するIdentity Provider

| カテゴリ | プロバイダ |
|---------|----------|
| Cognito User Pools | 自前のUser Pool |
| パブリックプロバイダ | Facebook / Google / Twitter(Digits) / Login with Amazon |
| OpenID Connect | カスタムOIDCプロバイダ |
| SAML | 企業内IDPとのフェデレーション |
| 未認証（ゲスト） | 匿名ユーザー（オプション） |

### 3.3 認証・認可フロー詳細

```
①サインイン
[利用者] ──→ [Identity Provider] ──→ [認証トークン返却]

②認証トークン提示
[利用者] ──→ [Federated Identities（Identity Pool）]

③有効性確認
[Federated Identities] ──→ [Identity Provider] ──→ [有効性確認結果]

④一時キー返却
[Federated Identities] ──→ [AWS STS] ──→ [Temporary Credentials]
[Temporary Credentials] ──→ [利用者]

⑤AWSリソース操作
[利用者] ──（一時キーを使用）──→ [S3 / DynamoDB / 等]
```

**ポイント：**
- 一時キーには有効期限あり（数分〜数時間）→ 期限切れで自動失効
- どのリソースにアクセスできるかはIAMロールの定義次第
- アプリにキーペアをハードコーディング不要

### 3.4 Federated Identities の CloudFormation 定義

```yaml
Resources:
  IdentityPool:
    Type: AWS::Cognito::IdentityPool
    Properties:
      IdentityPoolName: MyAppIdentityPool
      AllowUnauthenticatedIdentities: false  # ゲストアクセス
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
              # ユーザー固有のS3プレフィックスにのみアクセス許可
              - Effect: Allow
                Action:
                  - 's3:GetObject'
                  - 's3:PutObject'
                Resource: !Sub
                  - 'arn:aws:s3:::${BucketName}/users/${!sub}/*'
                  - BucketName: my-user-data-bucket

  # 未認証ユーザーロール（ゲスト）
  UnauthenticatedRole:
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
                'cognito-identity.amazonaws.com:amr': unauthenticated
      Policies:
        - PolicyName: GuestReadOnly
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:GetObject'
                Resource: 'arn:aws:s3:::my-public-bucket/*'

  IdentityPoolRoleAttachment:
    Type: AWS::Cognito::IdentityPoolRoleAttachment
    Properties:
      IdentityPoolId: !Ref IdentityPool
      Roles:
        authenticated: !GetAtt AuthenticatedRole.Arn
        unauthenticated: !GetAtt UnauthenticatedRole.Arn
```

---

## 4. API Gateway + Cognito 統合パターン

### 4.1 Cognito Authorizer（推奨パターン）

API GatewayにCognito User Poolsを直接統合します。Bearerトークン（IdToken）を検証します。

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

**リクエスト例：**

```bash
curl -H "Authorization: Bearer <CognitoIdToken>" \
     https://api-id.execute-api.region.amazonaws.com/prod/resource
```

### 4.2 Lambda Authorizer（カスタム認証ロジック）

より細粒度な認可ロジックが必要な場合にLambda Authorizerを使います。

```python
import json
import jwt
from jwt import PyJWKClient

COGNITO_REGION = 'ap-northeast-1'
COGNITO_USER_POOL_ID = 'ap-northeast-1_XXXXXXXXX'
COGNITO_APP_CLIENT_ID = 'xxxxxxxxxxxxxxxxxxxxxxxxxx'

jwks_url = f'https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json'
jwks_client = PyJWKClient(jwks_url)

def lambda_handler(event, context):
    token = event['authorizationToken'].replace('Bearer ', '')

    try:
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=['RS256'],
            audience=COGNITO_APP_CLIENT_ID
        )

        # カスタムロジック（例: ロールベースアクセス制御）
        user_role = payload.get('custom:role', 'user')

        return generate_policy(
            principal_id=payload['sub'],
            effect='Allow' if user_role in ['admin', 'user'] else 'Deny',
            resource=event['methodArn'],
            context={
                'userId': payload['sub'],
                'email': payload['email'],
                'role': user_role
            }
        )

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

### 4.3 API Gateway + Lambda + Cognito 統合アーキテクチャ

```
                   ①認証（Google等）
[モバイル/JS]  ─────────────────→  [Identity Provider]
     │                                      │
     │  ②認証トークン取得                   │
     ←──────────────────────────────────────
     │
     │  ③トークンをAPIに渡す
     ↓
[API Gateway]  ← Authorization: Bearer <token>
     │
     │  ④トークン検証
     ↓
[Cognito Authorizer or Lambda Authorizer]
     │
     │  ⑤有効なら実行許可
     ↓
[Lambda Function]
     │  ⑥IAMロール権限でAWSリソースを操作
     ↓
[DynamoDB / S3 / 等]
```

**パターン比較：**

| パターン | 向いているケース | 欠点 |
|---------|----------------|------|
| **Cognito Authorizer** | シンプルな認証のみ必要。User Pool標準トークン検証 | 認可ロジックはLambda内で実装必要 |
| **Lambda Authorizer** | カスタム認可（ロールベース等）。複数IdP対応 | 実装コスト高、レイテンシ追加 |
| **IAM認可** | AWS内部サービス間。SigV4署名必要 | フロントエンドからの利用が複雑 |

---

## 5. Google OAuth 連携実装フロー

### 5.1 全体フロー

```
[Google Developers Console]
  1. プロジェクト作成
  2. Google+ API（OAuth 2.0）有効化
  3. OAuthクライアントID取得（クライアントID・クライアントシークレット）

[AWS IAM]
  4. IDプロバイダ登録（OpenID Connect）
     - プロバイダURL: https://accounts.google.com
     - 対象者: <GoogleクライアントID>.apps.googleusercontent.com

[AWS Cognito]
  5. Identity Pool作成
     - Authentication providers → OpenID タブ → accounts.google.com を指定
     - Unauthenticated identities: 必要に応じて有効化

[AWS Lambda]
  6. Google IDトークンを受け取り、CognitoでAWS一時キーを取得するLambda作成

[AWS API Gateway]
  7. LambdaをバックエンドとしたAPIを構築
```

### 5.2 Google OAuthクライアントID登録設定

| 項目 | 値 |
|------|----|
| アプリケーションの種類 | ウェブアプリケーション（Web） |
| 承認済みJavaScript生成元 | `http://localhost:4567`（テスト時）/ 本番ドメイン |
| リダイレクトURI | コールバック先URL |

### 5.3 IAM IDプロバイダ登録（OpenID Connect）

```yaml
Resources:
  GoogleOIDCProvider:
    Type: AWS::IAM::OIDCProvider
    Properties:
      Url: https://accounts.google.com
      ClientIdList:
        - <YOUR_GOOGLE_CLIENT_ID>.apps.googleusercontent.com
      ThumbprintList:
        - <Googleのサムプリント>  # 公式ドキュメントから取得
```

**注意点：** Google認証をCognitoで利用する場合、同じGoogleアカウントでも IAMのIDプロバイダにGoogleを登録しないとCognitoのIdentity IDが別になってしまいます。Identity IDが異なるとCognito Sync利用時に意図しない挙動になります。

### 5.4 Lambda での Cognito 一時キー取得（Python）

```python
import boto3

cognito_identity = boto3.client('cognito-identity', region_name='ap-northeast-1')

def get_aws_credentials(google_id_token: str, identity_pool_id: str) -> dict:
    """Google IDトークンからAWS一時認証情報を取得する"""

    # Identity IDを取得
    identity_response = cognito_identity.get_id(
        IdentityPoolId=identity_pool_id,
        Logins={
            'accounts.google.com': google_id_token
        }
    )
    identity_id = identity_response['IdentityId']

    # 一時認証情報を取得
    credentials_response = cognito_identity.get_credentials_for_identity(
        IdentityId=identity_id,
        Logins={
            'accounts.google.com': google_id_token
        }
    )

    credentials = credentials_response['Credentials']
    return {
        'access_key_id': credentials['AccessKeyId'],
        'secret_key': credentials['SecretKey'],
        'session_token': credentials['SessionToken'],
        'expiration': credentials['Expiration'].isoformat()
    }
```

---

## 6. Cognito Sync

### 6.1 Cognito Sync とは

Cognitoによって認証されたアプリケーションのデータをクラウドに保存し、同じ認証情報を持つデバイス間でデータ同期する機能です。

**ユースケース：**
- スマートフォンとタブレット間でアプリ設定を共有
- オフライン時に変更したデータを次回オンライン時に同期
- プッシュ通知との連携（SNS経由）

### 6.2 Cognito Sync vs AWS AppSync

| 比較軸 | Cognito Sync | AWS AppSync |
|--------|-------------|------------|
| データモデル | Key-Valueペア | GraphQL スキーマ |
| リアルタイム同期 | プッシュ通知連携 | WebSocket対応 |
| 複雑なクエリ | ❌ | ✅ |
| 現在の推奨 | 既存システムのみ | ✅ 新規開発推奨 |

> 新規開発では **AWS AppSync** の利用を推奨します。

---

## 7. 権限管理のベストプラクティス

### 7.1 IAMグループによる権限管理

個別IAMユーザーへの権限付与ではなく、**役割単位のIAMグループ** で管理します。

```
推奨グループ構成:

┌─────────────────────────────────────────────────┐
│  IAM グループ構成                                │
│                                                   │
│  [インフラチーム]       → AdministratorAccess    │
│  [アプリ開発チーム]     → ReadOnlyAccess +        │
│                           EC2 Start/Stop等         │
│  [経理担当者]          → Billingのみ              │
└─────────────────────────────────────────────────┘
```

**運用フロー：**
1. 入社 → IAMユーザー作成 → 役割グループに追加
2. 異動 → グループ変更のみ（個別ポリシー修正不要）
3. 退職 → IAMユーザー削除

### 7.2 最小権限の原則

```json
// ❌ 過剰な権限（やってはいけない）
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}

// ✅ 必要最小限の権限
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject"
  ],
  "Resource": "arn:aws:s3:::my-bucket/users/${cognito-identity.amazonaws.com:sub}/*"
}
```

**Cognitoと組み合わせた細粒度制御：**

```yaml
Policies:
  - PolicyName: UserIsolatedAccess
    PolicyDocument:
      Statement:
        # ユーザー自身のデータのみアクセス可能
        - Effect: Allow
          Action:
            - dynamodb:GetItem
            - dynamodb:PutItem
            - dynamodb:Query
          Resource: !GetAtt UserDataTable.Arn
          Condition:
            # Cognito Identity IDをプライマリキーとして使用
            ForAllValues:StringEquals:
              dynamodb:LeadingKeys:
                - '${cognito-identity.amazonaws.com:sub}'
```

### 7.3 定期棚卸しのチェックリスト

```markdown
## 月次棚卸し

### IAMユーザー
- [ ] 最終ログイン日から90日以上経過したユーザーを確認・無効化
- [ ] 退職・異動者のIAMユーザーが削除されているか確認
- [ ] 利用者1人につき1つのIAMユーザーが守られているか

### アクセスキー
- [ ] プログラムからAWSを操作するアクセスキーはIAMロール/Cognitoで代替できるか
- [ ] アクセスキーの最終利用日時を確認（90日未使用は削除候補）

### Cognito
- [ ] User Poolsのユーザーリストを確認（不要なアカウントの削除）
- [ ] Identity Poolに登録されたIDプロバイダが有効か確認
- [ ] IAMロールのポリシーが最小権限になっているか

### 権限レビュー
- [ ] 各IAMグループのポリシーが現在の業務要件に即しているか
- [ ] 「*」（ワイルドカード）のAction/Resourceが正当化できるか確認
```

### 7.4 プログラムからのAWSアクセスに関する指針

| 実行環境 | 推奨認証方式 |
|---------|------------|
| EC2インスタンス | IAMロール（Instance Profile） |
| Lambda関数 | IAMロール（実行ロール） |
| EKSコンテナ | IRSA（IAM Roles for Service Accounts） |
| **モバイルアプリ** | **Cognito Identity Pool（Temporary Credentials）** |
| **ブラウザJS** | **Cognito Identity Pool（Temporary Credentials）** |
| CI/CD | IAMロール（OIDC連携） or 短命のアクセスキー |
| ローカル開発 | 個人IAMユーザーのアクセスキー（本番環境に使用しない） |

> **鉄則：アクセスキーをモバイルアプリ・フロントエンドコードに埋め込まない**

---

## 8. 実装チェックリスト

### User Pools
- [ ] パスワードポリシーが要件を満たしている（最低12文字推奨）
- [ ] MFAが有効化されている（少なくともOPTIONAL）
- [ ] `PreventUserExistenceErrors: ENABLED` でユーザー存在確認を防止
- [ ] トークン有効期限がセキュリティ要件に即している

### Identity Pool（Federated Identities）
- [ ] `AllowUnauthenticatedIdentities: false`（不要なゲストアクセスを禁止）
- [ ] 認証済み/未認証ロールのポリシーが最小権限になっている
- [ ] ユーザー固有リソースには `${cognito-identity.amazonaws.com:sub}` を活用

### API Gateway統合
- [ ] Cognito Authorizerまたは Lambda Authorizerが設定されている
- [ ] 保護が必要なエンドポイントに `AuthorizationType: COGNITO_USER_POOLS` が付与されている
- [ ] 公開エンドポイント（ヘルスチェック等）は意図的に `NONE` になっている

### Google OAuth
- [ ] Google OAuthクライアントIDがIAM IDプロバイダとして登録されている
- [ ] Identity PoolのAuthentication providersにGoogleが設定されている
- [ ] クライアントシークレットはSecrets Managerで管理している

---

## 参考リソース

- [Amazon Cognito Developer Guide](https://docs.aws.amazon.com/cognito/latest/developerguide/)
- [User Pools の Lambda トリガー](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools-working-with-aws-lambda-triggers.html)
- [Identity Pool の一時認証情報](https://docs.aws.amazon.com/cognito/latest/developerguide/authentication-flow.html)
- [Cognito と API Gateway の統合](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-integrate-with-cognito.html)
- [Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect)
