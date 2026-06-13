# データパーティショニング

## 基礎概念

### データパーティショニングとは
- **定義**: テナントデータの分割・管理戦略
- **目的**: 効率的なデータ管理、分離、スケーラビリティの実現
- **適用範囲**: すべてのデータストレージ技術に共通

### サイロ vs プール

#### サイロ（テナントごとのストレージ）
- **特徴**: 各テナントが専用のストレージリソースを持つ
- **メリット**:
  - 強力な分離
  - テナント別の最適化
  - Blast Radiusの限定
  - 独立したスケーリング
- **デメリット**:
  - 運用コストの増加
  - リソース管理の複雑化
  - 非効率なリソース利用

#### プール（共有ストレージ）
- **特徴**: 複数テナントがストレージリソースを共有
- **メリット**:
  - コスト効率
  - シンプルな運用
  - リソースの効率的利用
- **デメリット**:
  - ノイジーネイバー問題
  - 分離の実装が必要
  - スケーリングの複雑さ

### 技術に依存しない普遍的概念
- パーティショニングの原則はどのストレージ技術にも適用可能
- リレーショナル、NoSQL、オブジェクトストレージすべてに共通
- 技術選択後に適用する戦略ではなく、設計段階で考慮すべき要素

---

## 設計時の考慮事項

### ワークロードとSLA

#### テナント利用パターンの多様性
- **読み込み重視**: レポート、分析
- **書き込み重視**: データ収集、ログ記録
- **バランス型**: 一般的なCRUD操作
- **バースト型**: 不定期な大量処理

#### ティアに応じたSLA要件
| ティア | SLA例 | パーティショニング戦略 |
|--------|-------|---------------------|
| Free | 99.0%、ベストエフォート | プール |
| Standard | 99.5%、通常レスポンス | プール（優先度付き） |
| Premium | 99.9%、高速レスポンス | プール or 混合 |
| Enterprise | 99.95%、専用リソース | サイロ |

#### ストレージ飽和の検出と対処
- **検出方法**:
  - スループットの監視
  - レイテンシーの追跡
  - エラー率の監視
  - リソース使用率の追跡
- **対処方法**:
  - スロットリング
  - スケールアウト
  - サイロへの移行
  - ホットパーティションの解消

---

### Blast Radius

#### 障害影響範囲の制御
- **Blast Radius**: 単一障害が影響を及ぼす範囲
- **最小化の重要性**: 障害の影響を限定し、ビジネスへの影響を最小化

#### サイロ化による障害範囲の限定
```
プール構成:
└─ 1つのDB障害 → 全テナントに影響

サイロ構成:
├─ テナントA専用DB
├─ テナントB専用DB
└─ テナントC専用DB
  → 1つのDB障害 → 該当テナントのみ影響
```

#### デプロイ影響範囲の縮小
- サイロ化により、テナント別のデプロイが可能
- カナリアデプロイメント
- ブルー/グリーンデプロイメント
- 段階的ロールアウト

---

### テナント分離との関連

#### データパーティショニング ≠ テナント分離
- **パーティショニング**: データの物理的配置
- **分離**: アクセス制御とセキュリティ
- 両者は補完的だが異なる概念

#### 別々のDBでも分離ポリシーは必要
```typescript
// 誤った認識:
// 「テナントAのDBとテナントBのDBが別なら、
//  分離ポリシーは不要」

// 正しい認識:
// 「別々のDBでも、アプリケーションレベルで
//  テナント境界を越えないメカニズムが必要」

async function getOrder(orderId: string, tenantContext: TenantContext) {
  // 接続先DBの選択
  const db = selectDatabaseForTenant(tenantContext.tenantId);

  // 分離ポリシーの適用（依然として必要）
  const credentials = await getScopedCredentials(tenantContext);

  // テナントIDの検証
  const order = await db.getOrder(orderId, {
    tenantId: tenantContext.tenantId,
    credentials
  });

  return order;
}
```

#### 分離はデータストレージの上位レイヤー
- ストレージの物理的配置に依存しない
- アプリケーションレベルでの実装
- ポリシーベースのアクセス制御
- 監査とロギング

---

### ライトサイジングの課題

#### ストレージのコンピューティングリソースサイジング
- **プール構成の課題**:
  - 全テナントのワークロードに対応する必要
  - ピーク時のリソース要件
  - 非効率なリソース利用
- **サイロ構成の課題**:
  - テナントごとの適切なサイズ決定
  - 成長予測
  - リソースの過剰プロビジョニング

#### スループットとスロットリング
- **スループット制限**:
  - IOPS（I/O Operations Per Second）
  - スループット（MB/s）
  - 同時接続数
- **スロットリング戦略**:
  - テナント別の制限
  - ティアベースの制限
  - 動的な制限調整

#### サーバーレスストレージの活用
- **メリット**:
  - 自動スケーリング
  - 従量課金
  - 運用負荷の削減
- **例**:
  - Amazon DynamoDB（オンデマンドモード）
  - Azure Cosmos DB（サーバーレス）
  - Google Cloud Firestore

---

## ストレージ技術別パーティショニング

### リレーショナルデータベース

| モデル | 構造 | 適用場面 | 実装例 |
|--------|------|---------|--------|
| **プール** | 共有DB + tenant_id列 | コスト効率重視 | PostgreSQL単一DB |
| **スキーマ分離** | テナントごとのスキーマ | 中程度の分離 | PostgreSQL Schemas |
| **DB分離** | テナントごとのDB | 厳格な分離要件 | テナント専用DBインスタンス |

#### プールモデルの実装
```sql
-- テーブル設計
CREATE TABLE orders (
  id UUID PRIMARY KEY,
  tenant_id VARCHAR(50) NOT NULL,
  user_id VARCHAR(50) NOT NULL,
  status VARCHAR(20),
  created_at TIMESTAMP,

  INDEX idx_tenant_id (tenant_id),
  INDEX idx_tenant_user (tenant_id, user_id)
);

-- クエリ（必ずtenantIdでフィルタ）
SELECT * FROM orders
WHERE tenant_id = :tenantId
  AND status = 'pending';
```

#### スキーマ分離の実装
```sql
-- テナントごとのスキーマ作成
CREATE SCHEMA tenant_12345;
CREATE SCHEMA tenant_67890;

-- スキーマごとにテーブルを作成
CREATE TABLE tenant_12345.orders (
  id UUID PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL,
  status VARCHAR(20),
  created_at TIMESTAMP
);

-- 接続時にスキーマを指定
SET search_path TO tenant_12345;
SELECT * FROM orders WHERE status = 'pending';
```

#### DB分離の実装
```typescript
// テナントごとのDB接続を管理
class TenantDatabaseManager {
  private connections: Map<string, Connection> = new Map();

  getConnection(tenantId: string): Connection {
    if (!this.connections.has(tenantId)) {
      const config = this.getConfigForTenant(tenantId);
      this.connections.set(tenantId, createConnection(config));
    }
    return this.connections.get(tenantId)!;
  }

  private getConfigForTenant(tenantId: string): ConnectionConfig {
    return {
      host: `db-${tenantId}.example.com`,
      database: `tenant_${tenantId}`,
      // ...
    };
  }
}
```

---

### NoSQLデータベース

| モデル | 構造 | 適用場面 | 実装例 |
|--------|------|---------|--------|
| **プール** | パーティションキーにtenantId | コスト効率、高スケーラビリティ | DynamoDB単一テーブル |
| **テーブル分離** | テナントごとのテーブル | 分離要件、ティアリング | テナント専用テーブル |

#### プールモデルの実装（DynamoDB例）
```typescript
// テーブル設計
// パーティションキー: tenant_id
// ソートキー: entity_type#entity_id

interface Item {
  tenant_id: string;        // パーティションキー
  entity_key: string;       // ソートキー（例: "ORDER#12345"）
  data: Record<string, unknown>;
}

// クエリ
const result = await dynamodb.query({
  TableName: 'pooled_table',
  KeyConditionExpression: 'tenant_id = :tenantId AND begins_with(entity_key, :prefix)',
  ExpressionAttributeValues: {
    ':tenantId': 'tenant-12345',
    ':prefix': 'ORDER#'
  }
});
```

#### テーブル分離の実装
```typescript
function getTableName(tenantId: string, tier: string): string {
  if (tier === 'enterprise') {
    return `orders_${tenantId}`;
  }
  return `orders_${tier}`;
}

async function getOrders(tenantContext: TenantContext) {
  const tableName = getTableName(
    tenantContext.tenantId,
    tenantContext.tier
  );

  return await dynamodb.scan({
    TableName: tableName
  });
}
```

#### NoSQLのチューニング: キャパシティ管理、パーティション設計

##### キャパシティ管理
- **プロビジョンドモード**: 固定のRCU/WCU
- **オンデマンドモード**: 自動スケーリング、従量課金
- **Auto Scaling**: ワークロードに応じた自動調整

##### パーティション設計
```typescript
// 悪い例: ホットパーティション発生
{
  partition_key: 'tenant-12345',  // 大規模テナントで集中
  sort_key: 'ORDER#12345'
}

// 良い例: シャーディング
{
  partition_key: 'tenant-12345#shard-3',  // シャード番号を付与
  sort_key: 'ORDER#12345'
}

function getShardedPartitionKey(tenantId: string, itemId: string): string {
  const shardCount = getShardCountForTenant(tenantId);
  const shardNumber = hashCode(itemId) % shardCount;
  return `${tenantId}#shard-${shardNumber}`;
}
```

#### プール時のホットパーティション回避
- シャーディングキーの追加
- 複合パーティションキーの使用
- ワークロードの分散
- 時間ベースのパーティショニング

---

### オブジェクトストレージ

| モデル | 構造 | 適用場面 | 実装例 |
|--------|------|---------|--------|
| **プール** | 共有バケット + テナントプレフィックス | シンプル、コスト効率 | S3単一バケット |
| **バケット分離** | テナントごとのバケット | 分離、アクセス制御 | テナント専用バケット |

#### プールモデルの実装
```typescript
// オブジェクトキー構造
// tenant-{tenantId}/user-{userId}/file-{fileId}

function getObjectKey(tenantId: string, userId: string, fileId: string): string {
  return `tenant-${tenantId}/user-${userId}/file-${fileId}`;
}

// アップロード
await s3.putObject({
  Bucket: 'shared-bucket',
  Key: getObjectKey(tenantContext.tenantId, userId, fileId),
  Body: fileData
});

// ダウンロード（テナント検証必須）
const object = await s3.getObject({
  Bucket: 'shared-bucket',
  Key: getObjectKey(tenantContext.tenantId, userId, fileId)
});
```

#### バケット分離の実装
```typescript
function getBucketName(tenantId: string, tier: string): string {
  if (tier === 'enterprise') {
    return `tenant-${tenantId}`;
  }
  return `shared-${tier}`;
}

// アップロード
await s3.putObject({
  Bucket: getBucketName(tenantContext.tenantId, tenantContext.tier),
  Key: `user-${userId}/file-${fileId}`,
  Body: fileData
});
```

#### マネージドアクセスポリシーによるテナント分離
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::shared-bucket/tenant-${aws:PrincipalTag/TenantId}/*",
      "Condition": {
        "StringEquals": {
          "s3:ExistingObjectTag/tenant_id": "${aws:PrincipalTag/TenantId}"
        }
      }
    }
  ]
}
```

---

### 全文検索/分析エンジン

| モデル | 構造 | 適用場面 | 実装例 |
|--------|------|---------|--------|
| **プール** | 共有インデックス + テナントフィールド | コスト効率 | Elasticsearch単一インデックス |
| **インデックス分離** | テナントごとのインデックス | 分離、パフォーマンス | テナント専用インデックス |
| **混合モード** | ティア別にプール/サイロ | ティアリング対応 | Free/Standard→プール、Enterprise→専用 |

#### プールモデルの実装（Elasticsearch例）
```typescript
// インデックス設計
interface Document {
  tenant_id: string;
  user_id: string;
  title: string;
  content: string;
  created_at: string;
}

// 検索（必ずテナントフィルター付与）
const result = await elasticsearch.search({
  index: 'documents',
  body: {
    query: {
      bool: {
        must: [
          { term: { tenant_id: tenantContext.tenantId } },
          { match: { content: searchQuery } }
        ]
      }
    }
  }
});
```

#### インデックス分離の実装
```typescript
function getIndexName(tenantId: string): string {
  return `documents_${tenantId}`;
}

// インデックス作成（テナントオンボーディング時）
await elasticsearch.indices.create({
  index: getIndexName(tenantId),
  body: {
    mappings: {
      properties: {
        title: { type: 'text' },
        content: { type: 'text' }
      }
    }
  }
});

// 検索
const result = await elasticsearch.search({
  index: getIndexName(tenantContext.tenantId),
  body: {
    query: {
      match: { content: searchQuery }
    }
  }
});
```

#### 混合モードの実装
```typescript
function getIndexName(tenantContext: TenantContext): string {
  if (tenantContext.tier === 'enterprise') {
    return `documents_${tenantContext.tenantId}`;
  }
  return `documents_${tenantContext.tier}`;
}
```

---

## テナントデータのシャーディング

### 大規模テナントへの対応
- 単一テナントのデータが単一ストレージの限界を超える場合
- 水平スケーリングが必要
- シャーディング戦略の適用

### シャーディング戦略の設計

#### ハッシュベースシャーディング
```typescript
function getShardId(key: string, shardCount: number): number {
  return hashCode(key) % shardCount;
}

function getShardedTableName(tenantId: string, itemId: string): string {
  const shardCount = getShardCountForTenant(tenantId);
  const shardId = getShardId(itemId, shardCount);
  return `orders_${tenantId}_shard_${shardId}`;
}
```

#### レンジベースシャーディング
```typescript
// 時間ベースのシャーディング
function getShardedTableName(tenantId: string, timestamp: Date): string {
  const yearMonth = timestamp.toISOString().substring(0, 7); // "2025-01"
  return `orders_${tenantId}_${yearMonth}`;
}
```

### テナントIDベースの分散
- テナント単位でのシャード配置
- クロステナントクエリの最小化
- テナント別の独立したスケーリング

---

## データライフサイクル

### テナント廃止時のデータ保持・削除ポリシー
- **即時削除**: テナント廃止と同時にデータ削除
- **猶予期間**: 一定期間アーカイブ後に削除
- **永久保持**: 法規制要件による永久保存

### アーカイブ戦略
- **コールドストレージへの移行**: 使用頻度の低いデータ
- **圧縮**: ストレージコストの削減
- **検索可能なアーカイブ**: 必要時に復元可能

### 法規制への対応
- **GDPR**: データ削除権（Right to Erasure）
- **データ残存期間**: 規制に応じた保持期間
- **監査ログ**: データアクセスと削除の記録

---

## マルチテナントデータのセキュリティ

### データ暗号化（保存時・転送時）
- **保存時**: AES-256等の強力な暗号化
- **転送時**: TLS 1.3以上の使用
- **キー管理**: 安全なキー保管

### テナント別の暗号化キー管理
```typescript
async function encryptData(data: string, tenantId: string): Promise<string> {
  const key = await getEncryptionKeyForTenant(tenantId);
  return encrypt(data, key);
}

async function decryptData(encrypted: string, tenantId: string): Promise<string> {
  const key = await getEncryptionKeyForTenant(tenantId);
  return decrypt(encrypted, key);
}
```

### アクセスログの記録
```json
{
  "timestamp": "2025-01-01T12:00:00Z",
  "tenant_id": "tenant-12345",
  "user_id": "user-67890",
  "action": "READ",
  "resource": "orders/order-999",
  "ip_address": "192.168.1.1",
  "user_agent": "Mozilla/5.0..."
}
```

---

## パフォーマンス最適化

### インデックス戦略
- テナントIDを含む複合インデックス
- クエリパターンに基づくインデックス設計
- インデックスのメンテナンス

### キャッシュ戦略
- テナント別のキャッシュ
- キャッシュ無効化のタイミング
- 分散キャッシュの活用

### クエリ最適化
- テナントフィルターの最適化
- N+1問題の回避
- バッチ処理の活用
