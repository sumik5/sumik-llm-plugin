# テナント分離

## 核心原則

### デプロイ ≠ 分離

#### 誤った認識
```
「テナントAとテナントBに別々のデータベースを用意した。
 これでテナント分離が完了した。」
```

#### 正しい認識
```
「別々のデータベースを用意したのは『デプロイモデル』の選択。
 テナント分離は、アプリケーションレベルで
 テナント境界を越えたアクセスを防止するメカニズムが必要。」
```

#### デプロイ: リソースの配置方法
- **物理的な配置**: サーバー、データベース、ストレージの配置
- **論理的な配置**: スキーマ、テーブル、バケットの構成
- **インフラレベルの決定**: AWSアカウント、VPC、サブネット

#### 分離: テナント間のアクセス防止メカニズム
- **アクセス制御**: 誰が何にアクセスできるかを制御
- **ポリシーベース**: テナントコンテキストに基づく動的な制限
- **実行時の検証**: リクエストごとにテナント境界をチェック

#### 両者は独立した概念
| 観点 | デプロイ | 分離 |
|------|---------|------|
| **レイヤー** | インフラ | アプリケーション |
| **タイミング** | プロビジョニング時 | 実行時 |
| **目的** | リソース配置 | アクセス制御 |
| **変更頻度** | 低（設計時） | 高（リクエストごと） |

---

### なぜ分離が必須か

#### 開発者のコードを「信頼」してはいけない
```typescript
// 危険な例: テナントIDの検証なし
async function getOrder(orderId: string) {
  // 誰のorderIdでも取得できてしまう
  return await database.query(
    'SELECT * FROM orders WHERE id = ?',
    [orderId]
  );
}

// 安全な例: テナント分離を適用
async function getOrder(orderId: string, tenantContext: TenantContext) {
  // テナントIDでフィルタリング
  return await database.query(
    'SELECT * FROM orders WHERE id = ? AND tenant_id = ?',
    [orderId, tenantContext.tenantId]
  );
}
```

#### 意図しないテナント境界越えは必ず発生しうる
- **人的ミス**: コードレビューをすり抜けるバグ
- **設計ミス**: テナントコンテキストの伝播漏れ
- **ライブラリのバグ**: サードパーティコードの問題
- **設定ミス**: 環境変数やポリシーの誤設定

#### 1件のテナント間アクセス = SaaSビジネスへの大きな後退
- **信頼の喪失**: 顧客はデータ漏洩を深刻に受け止める
- **法的責任**: GDPR、CCPA等の規制違反
- **ビジネスへの影響**: 顧客離れ、評判の悪化
- **復旧コスト**: インシデント対応、監査、補償

#### テナントから見ればすべてのリソースは分離されているべき
- テナントは自分のデータのみにアクセス可能
- 他テナントの存在を意識する必要なし
- 専用環境と同等のセキュリティ体験
- 透明性のある分離

---

### 分離の実装

#### リソースアクセスの前にテナントコンテキストを検証
```typescript
async function accessResource<T>(
  resourceId: string,
  tenantContext: TenantContext,
  accessor: (scopedCredentials: Credentials) => Promise<T>
): Promise<T> {
  // 1. テナントコンテキストの検証
  validateTenantContext(tenantContext);

  // 2. スコープ付きクレデンシャルの生成
  const scopedCredentials = await generateScopedCredentials(tenantContext);

  // 3. リソースアクセス（自動的に分離が適用される）
  return await accessor(scopedCredentials);
}
```

#### ゲートキーパーとして機能する分離レイヤー
```typescript
class IsolationGatekeeper {
  async checkAccess(
    tenantContext: TenantContext,
    resource: Resource
  ): Promise<boolean> {
    // テナントIDの一致確認
    if (resource.tenantId !== tenantContext.tenantId) {
      await logSecurityEvent('ISOLATION_VIOLATION', {
        tenantContext,
        resource
      });
      return false;
    }

    // ティアベースの制限チェック
    if (!this.checkTierPermissions(tenantContext.tier, resource)) {
      return false;
    }

    return true;
  }
}
```

#### テナントコンテキストに基づくアクセス範囲の制限
```typescript
async function getScopedCredentials(
  tenantContext: TenantContext
): Promise<Credentials> {
  // IAMポリシーの動的生成
  const policy = {
    Version: '2012-10-17',
    Statement: [
      {
        Effect: 'Allow',
        Action: ['dynamodb:GetItem', 'dynamodb:Query'],
        Resource: `arn:aws:dynamodb:*:*:table/orders`,
        Condition: {
          'ForAllValues:StringEquals': {
            'dynamodb:LeadingKeys': [tenantContext.tenantId]
          }
        }
      }
    ]
  };

  // 一時クレデンシャルの発行
  return await sts.assumeRole({
    RoleArn: 'arn:aws:iam::123456789012:role/TenantRole',
    Policy: JSON.stringify(policy),
    DurationSeconds: 3600
  });
}
```

---

## 分離モデルの分類

| レベル | 説明 | 実装例 | 分離強度 | コスト |
|--------|------|--------|---------|--------|
| **フルスタック分離** | テナントごとに完全なインフラ分離 | VPC/ネットワーク分離 | ◎◎◎ | 高 |
| **リソースレベル分離** | 個別リソースを分離 | DB/キュー等のリソースポリシー | ◎◎ | 中 |
| **アイテムレベル分離** | 共有リソース内でのアクセス制御 | IAMポリシー、行レベルセキュリティ | ◎ | 低 |

---

### フルスタック分離

#### テナントごとに完全なインフラ分離
```
テナントA環境:
├─ VPC-A
│  ├─ Subnet-A1
│  ├─ Subnet-A2
│  ├─ Security-Group-A
│  ├─ Application-A
│  └─ Database-A

テナントB環境:
├─ VPC-B
│  ├─ Subnet-B1
│  ├─ Subnet-B2
│  ├─ Security-Group-B
│  ├─ Application-B
│  └─ Database-B
```

#### 特徴
- **最高レベルの分離**: ネットワークレベルで完全に分離
- **独立した運用**: テナントごとの独立したデプロイ
- **高コスト**: インフラリソースの重複
- **適用場面**: Enterprise顧客、規制要件の厳しい業界

---

### リソースレベル分離

#### 個別リソースを分離
```typescript
// テナントごとのデータベース
const databases = {
  'tenant-12345': 'db-tenant-12345.example.com',
  'tenant-67890': 'db-tenant-67890.example.com'
};

// テナントごとのキュー
const queues = {
  'tenant-12345': 'https://sqs.amazonaws.com/123456789012/tenant-12345',
  'tenant-67890': 'https://sqs.amazonaws.com/123456789012/tenant-67890'
};

async function getDatabase(tenantId: string): Promise<Database> {
  const connectionString = databases[tenantId];
  return await connectToDatabase(connectionString);
}
```

#### DB/キュー等のリソースポリシー
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TenantIsolation",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/ApplicationRole"
      },
      "Action": "sqs:*",
      "Resource": "arn:aws:sqs:*:*:tenant-${tenantId}",
      "Condition": {
        "StringEquals": {
          "aws:PrincipalTag/TenantId": "${tenantId}"
        }
      }
    }
  ]
}
```

---

### アイテムレベル分離

#### 共有リソース内でのアクセス制御
```sql
-- PostgreSQLの行レベルセキュリティ
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON orders
  USING (tenant_id = current_setting('app.current_tenant_id'));

-- セッション開始時にテナントIDを設定
SET app.current_tenant_id = 'tenant-12345';

-- 以降のクエリは自動的にフィルタリングされる
SELECT * FROM orders; -- WHERE tenant_id = 'tenant-12345' が自動付与
```

#### IAMポリシー、行レベルセキュリティ
```typescript
// DynamoDBの条件付きアクセス
async function queryOrders(tenantId: string): Promise<Order[]> {
  const credentials = await getScopedCredentials({
    tenantId,
    policy: {
      Version: '2012-10-17',
      Statement: [
        {
          Effect: 'Allow',
          Action: 'dynamodb:Query',
          Resource: 'arn:aws:dynamodb:*:*:table/orders',
          Condition: {
            'ForAllValues:StringEquals': {
              'dynamodb:LeadingKeys': [tenantId]
            }
          }
        }
      ]
    }
  });

  // このクレデンシャルでは指定テナントのデータのみアクセス可能
  return await dynamodb.query({
    TableName: 'orders',
    KeyConditionExpression: 'tenant_id = :tenantId',
    ExpressionAttributeValues: {
      ':tenantId': tenantId
    }
  }, credentials);
}
```

---

## デプロイ時 vs ランタイムでの分離

### デプロイ時の分離

#### インフラプロビジョニング時にリソースを分離
```typescript
// Terraformでのテナント専用リソース作成例
resource "aws_dynamodb_table" "tenant_table" {
  for_each = var.enterprise_tenants

  name           = "orders-${each.key}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "order_id"

  tags = {
    TenantId = each.key
    Tier     = "enterprise"
  }
}
```

#### ネットワーク境界、セキュリティグループ
```typescript
// VPC分離の例
resource "aws_vpc" "tenant_vpc" {
  for_each = var.enterprise_tenants

  cidr_block = each.value.cidr_block

  tags = {
    Name     = "vpc-${each.key}"
    TenantId = each.key
  }
}

resource "aws_security_group" "tenant_sg" {
  for_each = var.enterprise_tenants

  name        = "sg-${each.key}"
  description = "Security group for tenant ${each.key}"
  vpc_id      = aws_vpc.tenant_vpc[each.key].id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [each.value.allowed_cidr]
  }
}
```

#### テナントごとのリソース作成
- オンボーディング時に実行
- Infrastructure as Code（IaC）による自動化
- 時間がかかる（数分〜数十分）
- 変更が困難（再プロビジョニング必要）

---

### ランタイムでの分離

#### リクエスト処理時に動的にアクセス範囲を制限
```typescript
async function handleRequest(
  request: Request,
  tenantContext: TenantContext
): Promise<Response> {
  // 1. テナントコンテキストの検証
  validateTenantContext(tenantContext);

  // 2. スコープ付きクレデンシャルの生成（リクエストごと）
  const credentials = await generateScopedCredentials(tenantContext);

  // 3. 処理実行（自動的にテナントスコープが適用される）
  const result = await processRequest(request, credentials);

  return result;
}
```

#### テナントコンテキストに基づくスコープ付きクレデンシャルの生成
```typescript
async function generateScopedCredentials(
  tenantContext: TenantContext
): Promise<Credentials> {
  const policy = generateTenantPolicy(tenantContext);

  return await sts.assumeRole({
    RoleArn: getTenantRoleArn(tenantContext.tier),
    Policy: JSON.stringify(policy),
    DurationSeconds: 900, // 15分
    RoleSessionName: `tenant-${tenantContext.tenantId}-${Date.now()}`
  });
}

function generateTenantPolicy(tenantContext: TenantContext): IAMPolicy {
  return {
    Version: '2012-10-17',
    Statement: [
      {
        Effect: 'Allow',
        Action: ['dynamodb:*', 's3:*'],
        Resource: [
          `arn:aws:dynamodb:*:*:table/*/tenant-${tenantContext.tenantId}/*`,
          `arn:aws:s3:::*/tenant-${tenantContext.tenantId}/*`
        ]
      }
    ]
  };
}
```

#### 各リクエストで分離ポリシーを適用
- 即座に適用（ミリ秒単位）
- 柔軟な制御（テナントごとに異なるポリシー）
- ステートレス（リクエスト間で状態を持たない）
- 動的な変更に対応

---

### 傍受による分離

#### サービスコードの外部で分離を適用
```typescript
// サイドカーパターン
// メインアプリケーションコンテナとは別のコンテナで分離を適用

class IsolationSidecar {
  async interceptRequest(request: Request): Promise<Request> {
    // 1. JWTからテナントコンテキスト抽出
    const tenantContext = extractTenantContext(request);

    // 2. スコープ付きクレデンシャル生成
    const credentials = await generateScopedCredentials(tenantContext);

    // 3. リクエストにクレデンシャル注入
    request.headers['X-Tenant-Credentials'] = credentials;

    // 4. メインアプリケーションに転送
    return request;
  }
}
```

#### サイドカー、ミドルウェア、関数レイヤー

##### サイドカー（Kubernetes）
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: order-service
spec:
  containers:
  - name: app
    image: order-service:latest
    env:
    - name: CREDENTIALS_SOURCE
      value: "sidecar"
  - name: isolation-sidecar
    image: isolation-sidecar:latest
    ports:
    - containerPort: 8080
```

##### ミドルウェア（Express）
```typescript
function isolationMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const tenantContext = extractTenantContext(req);

  getScopedCredentials(tenantContext)
    .then(credentials => {
      req.tenantContext = tenantContext;
      req.scopedCredentials = credentials;
      next();
    })
    .catch(next);
}

app.use(isolationMiddleware);

app.get('/orders', async (req, res) => {
  // req.scopedCredentials が自動的に利用可能
  const orders = await getOrders(req.scopedCredentials);
  res.json(orders);
});
```

##### 関数レイヤー（AWS Lambda）
```typescript
// Lambda Layerでの分離適用
export const isolationLayer = async (
  event: APIGatewayEvent
): Promise<APIGatewayEvent> => {
  // 1. JWTからテナントコンテキスト抽出
  const token = event.headers.Authorization;
  const tenantContext = decodeJWT(token);

  // 2. スコープ付きクレデンシャル生成
  const credentials = await generateScopedCredentials(tenantContext);

  // 3. 環境変数に設定
  process.env.AWS_ACCESS_KEY_ID = credentials.AccessKeyId;
  process.env.AWS_SECRET_ACCESS_KEY = credentials.SecretAccessKey;
  process.env.AWS_SESSION_TOKEN = credentials.SessionToken;
  process.env.TENANT_ID = tenantContext.tenantId;

  return event;
};
```

#### 開発者が意識しない分離の実現
```typescript
// 開発者が書くコード（分離を意識しない）
export const handler = async (event: APIGatewayEvent) => {
  // process.env.TENANT_ID が自動的に設定されている
  // AWS SDK は自動的にスコープ付きクレデンシャルを使用

  const orders = await dynamodb.query({
    TableName: 'orders',
    KeyConditionExpression: 'tenant_id = :tenantId',
    ExpressionAttributeValues: {
      ':tenantId': process.env.TENANT_ID
    }
  });

  return {
    statusCode: 200,
    body: JSON.stringify(orders)
  };
};
```

---

## 実装パターン

### フルスタック分離の例

#### テナントごとのネットワーク境界
```typescript
// Terraformでのフルスタック分離
module "tenant_infrastructure" {
  for_each = var.enterprise_tenants
  source   = "./modules/tenant-infrastructure"

  tenant_id = each.key

  vpc_cidr           = each.value.vpc_cidr
  availability_zones = var.availability_zones

  database_config = {
    instance_class = "db.r5.large"
    storage_type   = "io1"
    iops           = 10000
  }

  application_config = {
    instance_type     = "t3.large"
    desired_count     = 3
    max_count         = 10
  }
}
```

#### 専用のコンピューティングリソース
- テナントごとのECS/EKSクラスター
- 専用のAuto Scalingグループ
- 独立したロードバランサー
- 専用のキャッシュクラスター

#### 分離されたストレージ
- テナント専用のデータベースインスタンス
- 専用のS3バケット
- 専用のファイルシステム
- 独立したバックアップ

---

### リソースレベル分離の例

#### クラウドIAMポリシーによるリソースアクセス制限
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TenantResourceAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": [
        "arn:aws:dynamodb:*:*:table/orders",
        "arn:aws:dynamodb:*:*:table/orders/index/*"
      ],
      "Condition": {
        "ForAllValues:StringEquals": {
          "dynamodb:LeadingKeys": ["${aws:PrincipalTag/TenantId}"]
        }
      }
    },
    {
      "Sid": "TenantS3Access",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::shared-bucket/tenant-${aws:PrincipalTag/TenantId}/*"
    }
  ]
}
```

#### テナントIDを含むリソース名/タグでのフィルタリング
```typescript
// リソースタグによる分離
async function listTenantResources(tenantId: string): Promise<Resource[]> {
  const resources = await resourceGroupsTaggingAPI.getResources({
    TagFilters: [
      {
        Key: 'TenantId',
        Values: [tenantId]
      }
    ]
  });

  return resources.ResourceTagMappingList;
}
```

#### スコープ付き一時クレデンシャルの発行
```typescript
async function issueTemporaryCredentials(
  tenantContext: TenantContext,
  duration: number = 3600
): Promise<TemporaryCredentials> {
  const policy = {
    Version: '2012-10-17',
    Statement: [
      {
        Effect: 'Allow',
        Action: ['dynamodb:*', 's3:*'],
        Resource: [
          `arn:aws:dynamodb:*:*:table/*/tenant-${tenantContext.tenantId}/*`,
          `arn:aws:s3:::*/tenant-${tenantContext.tenantId}/*`
        ]
      }
    ]
  };

  return await sts.assumeRole({
    RoleArn: `arn:aws:iam::123456789012:role/TenantRole-${tenantContext.tier}`,
    RoleSessionName: `session-${tenantContext.tenantId}-${Date.now()}`,
    Policy: JSON.stringify(policy),
    DurationSeconds: duration,
    Tags: [
      { Key: 'TenantId', Value: tenantContext.tenantId },
      { Key: 'Tier', Value: tenantContext.tier }
    ]
  });
}
```

---

### アイテムレベル分離の例

#### 行レベルセキュリティ（RDB）
```sql
-- PostgreSQL
CREATE POLICY tenant_isolation_policy ON orders
  FOR ALL
  TO application_role
  USING (tenant_id = current_setting('app.tenant_id', true));

-- 接続時にテナントIDを設定
BEGIN;
SET LOCAL app.tenant_id = 'tenant-12345';
SELECT * FROM orders; -- 自動的に tenant_id = 'tenant-12345' でフィルタリング
COMMIT;
```

#### 条件付きアクセスポリシー（NoSQL）
```typescript
// DynamoDB条件式による分離
async function getItem(
  tableName: string,
  key: DynamoDBKey,
  tenantId: string
): Promise<Item> {
  return await dynamodb.getItem({
    TableName: tableName,
    Key: key,
    ConditionExpression: 'tenant_id = :tenantId',
    ExpressionAttributeValues: {
      ':tenantId': tenantId
    }
  });
}
```

#### テナントスコープ付きクエリの強制
```typescript
class TenantScopedRepository<T> {
  constructor(
    private tableName: string,
    private tenantContext: TenantContext
  ) {}

  async query(params: QueryParams): Promise<T[]> {
    // テナントIDを自動的に付与
    const scopedParams = {
      ...params,
      KeyConditionExpression: params.KeyConditionExpression
        ? `tenant_id = :tenantId AND ${params.KeyConditionExpression}`
        : 'tenant_id = :tenantId',
      ExpressionAttributeValues: {
        ...params.ExpressionAttributeValues,
        ':tenantId': this.tenantContext.tenantId
      }
    };

    return await dynamodb.query(scopedParams);
  }
}
```

---

## 分離ポリシーの管理

### ポリシーの一元管理
```typescript
class PolicyManager {
  private policies: Map<string, IAMPolicy> = new Map();

  registerPolicy(tier: string, policy: IAMPolicy): void {
    this.policies.set(tier, policy);
  }

  getPolicy(tier: string): IAMPolicy {
    const policy = this.policies.get(tier);
    if (!policy) {
      throw new Error(`Policy not found for tier: ${tier}`);
    }
    return policy;
  }
}

// ポリシー登録
policyManager.registerPolicy('free', freePolicy);
policyManager.registerPolicy('premium', premiumPolicy);
policyManager.registerPolicy('enterprise', enterprisePolicy);
```

### テナントごとのポリシー動的生成
```typescript
function generateTenantPolicy(tenantContext: TenantContext): IAMPolicy {
  const basePolicy = policyManager.getPolicy(tenantContext.tier);

  return {
    Version: '2012-10-17',
    Statement: basePolicy.Statement.map(statement => ({
      ...statement,
      Resource: statement.Resource.map(resource =>
        resource.replace('${tenantId}', tenantContext.tenantId)
      ),
      Condition: {
        ...statement.Condition,
        'StringEquals': {
          'aws:PrincipalTag/TenantId': tenantContext.tenantId
        }
      }
    }))
  };
}
```

### ポリシーのテスト可能性
```typescript
describe('Tenant Isolation Policies', () => {
  it('should prevent cross-tenant access', async () => {
    const tenantA = { tenantId: 'tenant-a', tier: 'premium' };
    const tenantB = { tenantId: 'tenant-b', tier: 'premium' };

    const credentialsA = await generateScopedCredentials(tenantA);

    // テナントAのクレデンシャルでテナントBのデータにアクセス試行
    await expect(
      getOrder('order-from-tenant-b', credentialsA)
    ).rejects.toThrow('Access Denied');
  });
});
```

### 分離違反の検出とアラート
```typescript
class IsolationMonitor {
  async detectViolation(event: AccessEvent): Promise<void> {
    if (event.requestedTenantId !== event.authenticatedTenantId) {
      await this.logViolation(event);
      await this.sendAlert(event);
      await this.blockAccess(event);
    }
  }

  private async logViolation(event: AccessEvent): Promise<void> {
    await logger.error('ISOLATION_VIOLATION', {
      authenticatedTenant: event.authenticatedTenantId,
      requestedTenant: event.requestedTenantId,
      resource: event.resource,
      timestamp: new Date().toISOString()
    });
  }

  private async sendAlert(event: AccessEvent): Promise<void> {
    await alerting.send({
      severity: 'CRITICAL',
      title: 'Tenant Isolation Violation Detected',
      description: `Tenant ${event.authenticatedTenantId} attempted to access resources of tenant ${event.requestedTenantId}`,
      event
    });
  }
}
```

---

## 拡張性の考慮

### テナント数増加に伴うポリシー管理の複雑性
- **課題**: 10,000テナント × 複数リソースタイプ = 膨大なポリシー数
- **対策**: テンプレートベースのポリシー生成、ティアベースの集約

### ポリシーキャッシュ戦略
```typescript
class PolicyCache {
  private cache: LRUCache<string, IAMPolicy>;

  constructor(maxSize: number = 1000) {
    this.cache = new LRUCache({ max: maxSize });
  }

  async getPolicy(tenantContext: TenantContext): Promise<IAMPolicy> {
    const cacheKey = `${tenantContext.tenantId}:${tenantContext.tier}`;

    let policy = this.cache.get(cacheKey);
    if (!policy) {
      policy = await generateTenantPolicy(tenantContext);
      this.cache.set(cacheKey, policy);
    }

    return policy;
  }
}
```

### 分離チェックのパフォーマンスへの影響
- **測定**: 分離チェックのレイテンシーを監視
- **最適化**:
  - クレデンシャル生成のキャッシュ
  - 非同期処理の活用
  - バッチ処理による効率化
- **目標**: 分離チェックのオーバーヘッドは全体レイテンシーの10%以内
