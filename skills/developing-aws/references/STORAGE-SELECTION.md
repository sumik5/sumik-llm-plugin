# AWSストレージサービス選定ガイド

AWSのストレージサービスを適切に選定し、効率的なデータ管理を実現するための実践的なガイドです。

---

## 1. ストレージタイプの基礎

### 1.1 ファイルベースストレージ

**特徴**:
- 階層的なディレクトリ構造でデータを整理
- ファイルパスを使用したアクセス
- 複数のユーザーやアプリケーションから共有可能

**適用場面**:
- 共有ファイルシステム
- コンテンツ管理システム
- ホームディレクトリ

**AWSサービス**: Amazon EFS (Elastic File System)

### 1.2 ブロックベースストレージ

**特徴**:
- 固定サイズのブロック単位でデータを管理
- 低レイテンシ、高スループット
- ファイルシステムやデータベース向け

**適用場面**:
- データベースストレージ
- 仮想マシンのルートボリューム
- 高性能アプリケーション

**AWSサービス**: Amazon EBS (Elastic Block Store)

### 1.3 オブジェクトベースストレージ

**特徴**:
- フラットな構造でオブジェクトとして保存
- メタデータを含む
- HTTP/HTTPSでアクセス可能

**適用場面**:
- 静的コンテンツ配信
- バックアップとアーカイブ
- ビッグデータ分析

**AWSサービス**: Amazon S3 (Simple Storage Service)

---

## 2. リレーショナルデータベース

### 2.1 ACID特性

リレーショナルデータベースはACID特性を保証します:

| 特性 | 説明 | 実現方法 |
|------|------|---------|
| **Atomicity (原子性)** | トランザクション内のすべての操作が成功または全て失敗 | Write-Ahead Logging (WAL) |
| **Consistency (一貫性)** | データベースが常に整合性のある状態を維持 | 制約、トリガー、外部キー |
| **Isolation (分離性)** | 並行トランザクションが互いに干渉しない | ロック、MVCC (Multi-Version Concurrency Control) |
| **Durability (永続性)** | コミット後のデータは永続化される | トランザクションログ、レプリケーション |

### 2.2 Amazon RDS

**概要**:
マネージド型リレーショナルデータベースサービス。6つのデータベースエンジンをサポート。

**サポートエンジン**:
- MySQL
- PostgreSQL
- MariaDB
- Oracle Database
- SQL Server
- Amazon Aurora

**選定基準**:

| ユースケース | 推奨エンジン | 理由 |
|-------------|-------------|------|
| 汎用OLTP | MySQL, PostgreSQL | コスト効率、成熟したエコシステム |
| エンタープライズアプリ | Oracle Database, SQL Server | 既存アプリとの互換性、エンタープライズ機能 |
| 高パフォーマンス要求 | Amazon Aurora | MySQL/PostgreSQLの5倍のスループット |
| マルチリージョン | Amazon Aurora Global Database | 1秒未満のクロスリージョンレプリケーション |

**コード例 - RDS インスタンス作成 (AWS CLI)**:

```bash
# MySQL RDSインスタンスの作成
aws rds create-db-instance \
    --db-instance-identifier mydb \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --master-username admin \
    --master-user-password MyPassword123 \
    --allocated-storage 20 \
    --backup-retention-period 7 \
    --multi-az \
    --storage-encrypted
```

**コード例 - RDS接続 (Python SDK)**:

```python
import boto3
import pymysql

# RDSエンドポイント取得
rds = boto3.client('rds')
response = rds.describe_db_instances(DBInstanceIdentifier='mydb')
endpoint = response['DBInstances'][0]['Endpoint']['Address']
port = response['DBInstances'][0]['Endpoint']['Port']

# データベース接続
connection = pymysql.connect(
    host=endpoint,
    port=port,
    user='admin',
    password='MyPassword123',
    database='myappdb'
)

try:
    with connection.cursor() as cursor:
        cursor.execute("SELECT VERSION()")
        version = cursor.fetchone()
        print(f"Database version: {version[0]}")
finally:
    connection.close()
```

### 2.3 Amazon Aurora

**特徴**:
- MySQL/PostgreSQL互換
- クラウドネイティブアーキテクチャ
- 自動スケーリングストレージ (最大128TB)
- 最大15個のリードレプリカ

**アーキテクチャ**:
- ストレージと計算の分離
- 3つのAvailability Zoneに6つのコピーを自動レプリケーション
- 継続的バックアップをAmazon S3に保存

**選定基準**:

| 要件 | 標準RDS | Aurora |
|------|---------|--------|
| コスト最適化重視 | ✓ | |
| 高可用性が必須 | | ✓ |
| 読み取り負荷が高い | | ✓ (最大15リードレプリカ) |
| 書き込み負荷が高い | | ✓ (並列クエリ) |
| グローバル展開 | | ✓ (Global Database) |

**コード例 - Aurora クラスター作成 (AWS CLI)**:

```bash
# Auroraクラスター作成
aws rds create-db-cluster \
    --db-cluster-identifier myaurora-cluster \
    --engine aurora-mysql \
    --engine-version 8.0.mysql_aurora.3.02.0 \
    --master-username admin \
    --master-user-password MyPassword123 \
    --database-name myappdb \
    --backup-retention-period 7 \
    --storage-encrypted

# プライマリインスタンス作成
aws rds create-db-instance \
    --db-instance-identifier myaurora-instance-1 \
    --db-instance-class db.r6g.large \
    --engine aurora-mysql \
    --db-cluster-identifier myaurora-cluster

# リードレプリカ作成
aws rds create-db-instance \
    --db-instance-identifier myaurora-instance-2 \
    --db-instance-class db.r6g.large \
    --engine aurora-mysql \
    --db-cluster-identifier myaurora-cluster
```

---

## 3. NoSQLデータベース

### 3.1 BASE特性

NoSQLデータベースはBASE特性に基づきます:

| 特性 | 説明 | トレードオフ |
|------|------|------------|
| **Basically Available (基本的に利用可能)** | 部分的な障害があっても応答を返す | 一部のデータが古い可能性 |
| **Soft state (柔軟な状態)** | システム状態が時間とともに変化する | 即座の整合性は保証されない |
| **Eventually consistent (結果整合性)** | 最終的にすべてのレプリカが同じ状態になる | 短期的な不整合を許容 |

### 3.2 Amazon DynamoDB

**概要**:
フルマネージド型NoSQLデータベース。キーバリュー型とドキュメント型をサポート。

**主要特徴**:
- サーバーレス
- ミリ秒未満のレイテンシ
- 自動スケーリング
- 組み込みセキュリティ
- グローバルテーブル (マルチリージョンレプリケーション)

**データモデル**:

```
テーブル
├── パーティションキー (必須)
├── ソートキー (オプション)
├── 属性 (スキーマレス)
└── インデックス
    ├── グローバルセカンダリインデックス (GSI)
    └── ローカルセカンダリインデックス (LSI)
```

**選定基準**:

| ユースケース | DynamoDB適合度 | 理由 |
|-------------|---------------|------|
| モバイル/Webアプリのバックエンド | ◎ | 低レイテンシ、スケーラビリティ |
| IoTデータストア | ◎ | 高スループット、時系列データ対応 |
| セッション管理 | ◎ | TTL機能、高速読み取り |
| ゲームリーダーボード | ◎ | 低レイテンシ、アトミック更新 |
| 複雑なJOIN処理が必要 | × | 代わりにRDSを検討 |
| トランザクション整合性が最優先 | △ | トランザクション機能はあるがコスト高 |

**コード例 - DynamoDB テーブル作成 (AWS CLI)**:

```bash
# DynamoDBテーブル作成
aws dynamodb create-table \
    --table-name Users \
    --attribute-definitions \
        AttributeName=UserId,AttributeType=S \
        AttributeName=Email,AttributeType=S \
    --key-schema \
        AttributeName=UserId,KeyType=HASH \
    --global-secondary-indexes \
        '[
            {
                "IndexName": "EmailIndex",
                "KeySchema": [{"AttributeName":"Email","KeyType":"HASH"}],
                "Projection": {"ProjectionType":"ALL"},
                "ProvisionedThroughput": {"ReadCapacityUnits":5,"WriteCapacityUnits":5}
            }
        ]' \
    --billing-mode PAY_PER_REQUEST \
    --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES
```

**コード例 - DynamoDB 操作 (Python SDK)**:

```python
import boto3
from boto3.dynamodb.conditions import Key, Attr

# DynamoDBリソース取得
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Users')

# アイテム作成
table.put_item(
    Item={
        'UserId': 'user-001',
        'Name': 'Alice',
        'Email': 'alice@example.com',
        'Age': 30,
        'Preferences': {
            'theme': 'dark',
            'notifications': True
        }
    }
)

# アイテム取得
response = table.get_item(
    Key={'UserId': 'user-001'}
)
item = response.get('Item')
print(f"User: {item['Name']}, Email: {item['Email']}")

# クエリ (GSIを使用)
response = table.query(
    IndexName='EmailIndex',
    KeyConditionExpression=Key('Email').eq('alice@example.com')
)
items = response['Items']

# スキャン (条件付き)
response = table.scan(
    FilterExpression=Attr('Age').gt(25)
)
filtered_items = response['Items']

# アイテム更新
table.update_item(
    Key={'UserId': 'user-001'},
    UpdateExpression='SET Age = :age, Preferences.#t = :theme',
    ExpressionAttributeValues={
        ':age': 31,
        ':theme': 'light'
    },
    ExpressionAttributeNames={
        '#t': 'theme'  # 予約語の回避
    }
)

# アイテム削除
table.delete_item(
    Key={'UserId': 'user-001'}
)
```

---

## 4. キャッシュ戦略

### 4.1 キャッシング戦略の比較

| 戦略 | 読み取り | 書き込み | 複雑度 | ユースケース |
|------|---------|---------|--------|-------------|
| **Cache-Aside** | アプリがキャッシュをチェック、ミス時にDBから取得 | アプリが直接DBに書き込み | 低 | 読み取り負荷が高いアプリ |
| **Read-Through** | キャッシュがDBから自動取得 | アプリが直接DBに書き込み | 中 | 一貫した読み取りパターン |
| **Write-Through** | アプリがキャッシュに書き込み、キャッシュがDBに同期書き込み | 同期書き込み | 中 | 書き込み整合性が重要 |
| **Write-Back** | アプリがキャッシュに書き込み、キャッシュが非同期でDBに書き込み | 非同期書き込み | 高 | 書き込み負荷が高い、データロスリスク許容可能 |

### 4.2 キャッシュ削除ポリシー

| ポリシー | アルゴリズム | 特徴 | 適用場面 |
|---------|------------|------|---------|
| **LRU** (Least Recently Used) | 最後にアクセスされてから最も時間が経過した項目を削除 | 実装が比較的簡単、多くの場合に有効 | 汎用キャッシュ |
| **LFU** (Least Frequently Used) | アクセス頻度が最も低い項目を削除 | 人気コンテンツを保持、頻度カウントのオーバーヘッド | コンテンツ配信 |
| **FIFO** (First-In-First-Out) | 最も古く追加された項目を削除 | シンプルな実装 | 時系列データ |
| **Belady's Algorithm** | 将来最も長く使われない項目を削除 (理論上最適) | 実装不可能 (未来を予測できない) | ベンチマーク用 |

### 4.3 Amazon ElastiCache

**概要**:
フルマネージド型インメモリキャッシュサービス。RedisとMemcachedをサポート。

**エンジン選定**:

| 要件 | Redis | Memcached |
|------|-------|-----------|
| データ構造 | 文字列、リスト、セット、ソート済みセット、ハッシュ、ビットマップ、HyperLogLog | キーバリューのみ |
| 永続化 | サポート (RDB, AOF) | 非サポート |
| レプリケーション | マスター/レプリカ構成 | 非サポート |
| トランザクション | サポート | 非サポート |
| Pub/Sub | サポート | 非サポート |
| マルチスレッド | シングルスレッド | マルチスレッド |
| 適用場面 | セッション管理、リアルタイム分析、ランキング | 単純なキャッシュ、高スループット |

**コード例 - ElastiCache Redis クラスター作成 (AWS CLI)**:

```bash
# Redisレプリケーショングループ作成
aws elasticache create-replication-group \
    --replication-group-id my-redis-cluster \
    --replication-group-description "My Redis cluster" \
    --engine redis \
    --engine-version 7.0 \
    --cache-node-type cache.r6g.large \
    --num-cache-clusters 3 \
    --automatic-failover-enabled \
    --at-rest-encryption-enabled \
    --transit-encryption-enabled \
    --auth-token MySecureToken123
```

**コード例 - ElastiCache 操作 (Python SDK + Redis)**:

```python
import boto3
import redis

# ElastiCacheエンドポイント取得
elasticache = boto3.client('elasticache')
response = elasticache.describe_replication_groups(
    ReplicationGroupId='my-redis-cluster'
)
endpoint = response['ReplicationGroups'][0]['NodeGroups'][0]['PrimaryEndpoint']['Address']
port = response['ReplicationGroups'][0]['NodeGroups'][0]['PrimaryEndpoint']['Port']

# Redis接続
r = redis.Redis(
    host=endpoint,
    port=port,
    password='MySecureToken123',
    ssl=True,
    decode_responses=True
)

# Cache-Aside パターン実装
def get_user(user_id):
    # キャッシュをチェック
    cached_user = r.get(f'user:{user_id}')
    if cached_user:
        print("Cache hit")
        return cached_user

    # キャッシュミス - DBから取得 (疑似コード)
    print("Cache miss")
    user_data = fetch_user_from_db(user_id)

    # キャッシュに保存 (TTL: 1時間)
    r.setex(f'user:{user_id}', 3600, user_data)
    return user_data

# キャッシュ無効化
def invalidate_user_cache(user_id):
    r.delete(f'user:{user_id}')

# Pub/Sub パターン
def publish_event(channel, message):
    r.publish(channel, message)

def subscribe_to_events(channel):
    pubsub = r.pubsub()
    pubsub.subscribe(channel)
    for message in pubsub.listen():
        if message['type'] == 'message':
            print(f"Received: {message['data']}")
```

---

## 5. Amazon S3 ストレージクラス選定

### 5.1 ストレージクラス比較

| クラス | 取得時間 | 最小保存期間 | ユースケース | コスト |
|--------|---------|------------|-------------|-------|
| **S3 Standard** | ミリ秒 | なし | 頻繁にアクセスされるデータ | 高 |
| **S3 Intelligent-Tiering** | ミリ秒 | なし | アクセスパターンが不明または変化する | 中 (自動最適化) |
| **S3 Standard-IA** | ミリ秒 | 30日 | 月に1回程度のアクセス | 中 |
| **S3 One Zone-IA** | ミリ秒 | 30日 | 再作成可能なデータ | 低 |
| **S3 Glacier Instant Retrieval** | ミリ秒 | 90日 | 四半期に1回のアクセス | 低 |
| **S3 Glacier Flexible Retrieval** | 数分〜数時間 | 90日 | アーカイブ、年に1-2回のアクセス | 非常に低 |
| **S3 Glacier Deep Archive** | 12時間 | 180日 | 長期保存、7-10年に1回のアクセス | 最低 |

### 5.2 選定フローチャート

```
データアクセス頻度は？
├─ 頻繁 (毎日) → S3 Standard
├─ 不明/変化 → S3 Intelligent-Tiering
├─ 月1回程度
│   ├─ 高可用性必要 → S3 Standard-IA
│   └─ 再作成可能 → S3 One Zone-IA
├─ 四半期に1回 → S3 Glacier Instant Retrieval
├─ 年に1-2回 → S3 Glacier Flexible Retrieval
└─ 7-10年に1回 → S3 Glacier Deep Archive
```

**コード例 - S3 ライフサイクルポリシー設定 (AWS CLI)**:

```bash
# ライフサイクル設定JSONファイル作成
cat > lifecycle-policy.json <<EOF
{
    "Rules": [
        {
            "Id": "Move to IA after 30 days",
            "Status": "Enabled",
            "Transitions": [
                {
                    "Days": 30,
                    "StorageClass": "STANDARD_IA"
                },
                {
                    "Days": 90,
                    "StorageClass": "GLACIER_IR"
                },
                {
                    "Days": 365,
                    "StorageClass": "DEEP_ARCHIVE"
                }
            ],
            "Expiration": {
                "Days": 2555
            }
        }
    ]
}
EOF

# ライフサイクルポリシー適用
aws s3api put-bucket-lifecycle-configuration \
    --bucket my-bucket \
    --lifecycle-configuration file://lifecycle-policy.json
```

**コード例 - S3 操作 (Python SDK)**:

```python
import boto3
from datetime import datetime, timedelta

s3 = boto3.client('s3')

# バケット作成
s3.create_bucket(
    Bucket='my-app-bucket',
    CreateBucketConfiguration={'LocationConstraint': 'ap-northeast-1'}
)

# オブジェクトアップロード (ストレージクラス指定)
s3.put_object(
    Bucket='my-app-bucket',
    Key='data/report.pdf',
    Body=open('report.pdf', 'rb'),
    StorageClass='STANDARD_IA',
    ServerSideEncryption='AES256'
)

# オブジェクトダウンロード
s3.download_file('my-app-bucket', 'data/report.pdf', 'local-report.pdf')

# プレサインドURL生成 (一時的なアクセス許可)
presigned_url = s3.generate_presigned_url(
    'get_object',
    Params={'Bucket': 'my-app-bucket', 'Key': 'data/report.pdf'},
    ExpiresIn=3600  # 1時間有効
)

# ストレージクラス変更
s3.copy_object(
    Bucket='my-app-bucket',
    Key='data/report.pdf',
    CopySource={'Bucket': 'my-app-bucket', 'Key': 'data/report.pdf'},
    StorageClass='GLACIER_IR',
    MetadataDirective='COPY'
)

# オブジェクト一覧取得
response = s3.list_objects_v2(Bucket='my-app-bucket', Prefix='data/')
for obj in response.get('Contents', []):
    print(f"Key: {obj['Key']}, Size: {obj['Size']}, StorageClass: {obj['StorageClass']}")
```

---

## 6. Amazon EBS と EFS

### 6.1 比較

| 特性 | EBS | EFS |
|------|-----|-----|
| **タイプ** | ブロックストレージ | ファイルストレージ |
| **接続** | 単一EC2インスタンス (Multi-Attach除く) | 複数EC2インスタンス同時接続 |
| **パフォーマンス** | 高IOPS、低レイテンシ | ネットワークレイテンシあり |
| **ユースケース** | データベース、ブートボリューム | 共有ファイルシステム、コンテンツ管理 |
| **スケーリング** | 手動でサイズ変更 | 自動スケーリング |

### 6.2 EBS ボリュームタイプ

| タイプ | 最大IOPS | 最大スループット | ユースケース |
|-------|---------|----------------|-------------|
| **gp3** (汎用SSD) | 16,000 | 1,000 MB/s | 汎用ワークロード (推奨) |
| **gp2** (汎用SSD) | 16,000 | 250 MB/s | 汎用ワークロード (レガシー) |
| **io2** (プロビジョンドIOPS SSD) | 64,000 | 1,000 MB/s | ミッションクリティカルなデータベース |
| **st1** (スループット最適化HDD) | 500 | 500 MB/s | ビッグデータ、データウェアハウス |
| **sc1** (コールドHDD) | 250 | 250 MB/s | アーカイブ、アクセス頻度が低いデータ |

**コード例 - EBS ボリューム作成とアタッチ (AWS CLI)**:

```bash
# EBSボリューム作成
aws ec2 create-volume \
    --volume-type gp3 \
    --size 100 \
    --iops 3000 \
    --throughput 125 \
    --availability-zone ap-northeast-1a \
    --encrypted \
    --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=my-data-volume}]'

# ボリュームをEC2インスタンスにアタッチ
aws ec2 attach-volume \
    --volume-id vol-1234567890abcdef0 \
    --instance-id i-1234567890abcdef0 \
    --device /dev/sdf

# スナップショット作成
aws ec2 create-snapshot \
    --volume-id vol-1234567890abcdef0 \
    --description "Backup before upgrade"
```

---

## 7. ストレージサービス選定決定木

```
データ特性は？
├─ 構造化データ
│   ├─ トランザクション整合性必要
│   │   ├─ 高パフォーマンス → Amazon Aurora
│   │   └─ コスト重視 → Amazon RDS
│   └─ スケーラビリティ最優先 → Amazon DynamoDB
├─ 非構造化データ
│   ├─ 頻繁アクセス
│   │   ├─ ブロックレベルアクセス → Amazon EBS
│   │   └─ ファイル共有 → Amazon EFS
│   └─ アーカイブ/バックアップ → Amazon S3 (適切なストレージクラス)
└─ キャッシュ → Amazon ElastiCache
```

---

## まとめ

AWSストレージサービスの選定は、以下の要素を総合的に評価して判断します:

1. **データ特性**: 構造化 vs 非構造化、アクセスパターン
2. **パフォーマンス要件**: レイテンシ、スループット、IOPS
3. **整合性モデル**: ACID vs BASE
4. **スケーラビリティ**: 垂直 vs 水平スケーリング
5. **コスト**: ストレージコスト、リクエストコスト、データ転送コスト
6. **可用性**: 単一AZ vs マルチAZ vs マルチリージョン

一般的なベストプラクティスとして、ワークロードの特性を正確に把握し、適切なサービスとストレージクラスを組み合わせることで、コスト効率と性能を最適化できます。
