# インフラ・データストレージ実践ガイド

Part3（第8〜13章）の実装パターンと運用ノウハウ。サービス選定は `DATABASE-SERVICES.md` を参照。

---

## S3 / Glacier（第8章）

### CLI バックアップ・同期

```bash
# ローカル → S3 同期
aws s3 sync /var/www/html s3://my-backup-bucket/

# S3 → ローカル リストア
aws s3 sync s3://my-backup-bucket/ /var/www/html

# --delete: 同期元にない削除済みオブジェクトを宛先からも削除
aws s3 sync /var/www/html s3://my-backup-bucket/ --delete

# 特定ファイルのアップロード
aws s3 cp /path/to/file.tar.gz s3://my-bucket/backups/
```

### オブジェクトバージョニング

```bash
# バージョニング有効化
aws s3api put-bucket-versioning \
  --bucket my-bucket \
  --versioning-configuration Status=Enabled

# バージョン一覧確認
aws s3api list-object-versions --bucket my-bucket --prefix data/

# 特定バージョンの取得
aws s3api get-object \
  --bucket my-bucket \
  --key data/file.csv \
  --version-id <version-id> \
  output.csv
```

### Glacier ライフサイクルルール

```json
{
  "Rules": [
    {
      "ID": "archive-old-logs",
      "Status": "Enabled",
      "Filter": { "Prefix": "logs/" },
      "Transitions": [
        { "Days": 30, "StorageClass": "STANDARD_IA" },
        { "Days": 90, "StorageClass": "GLACIER" }
      ],
      "Expiration": { "Days": 365 }
    }
  ]
}
```

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-bucket \
  --lifecycle-configuration file://lifecycle.json
```

### Glacier 取り出しオプション

| 取り出し方法 | 所要時間 | 用途 |
|------------|---------|------|
| 一括（Bulk） | 5〜12時間 | 費用最安、急がないバッチ処理 |
| 標準（Standard） | 3〜5時間 | 通常のアーカイブ取り出し |
| 迅速（Expedited） | 1〜5分 | 緊急時、費用最高 |

```bash
# Glacier からオブジェクト取り出しリクエスト
aws s3api restore-object \
  --bucket my-bucket \
  --key archived/data.csv \
  --restore-request '{"Days":3,"GlacierJobParameters":{"Tier":"Standard"}}'
```

### SDK 統合（Node.js）

```javascript
const { S3Client, PutObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');

const client = new S3Client({ region: 'ap-northeast-1' });

// オブジェクトアップロード
async function uploadFile(bucket, key, body) {
  await client.send(new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: body,
    ServerSideEncryption: 'AES256',
  }));
}

// オブジェクト一覧取得
async function listObjects(bucket, prefix) {
  const response = await client.send(new ListObjectsV2Command({
    Bucket: bucket,
    Prefix: prefix,
    MaxKeys: 1000,
  }));
  return response.Contents;
}
```

### 静的ウェブホスティング

```bash
# バケットポリシー設定（パブリック読み取り）
aws s3api put-bucket-policy \
  --bucket my-static-site \
  --policy file://policy.json

# ウェブサイト設定
aws s3 website s3://my-static-site/ \
  --index-document index.html \
  --error-document error.html

# エンドポイント: http://<bucket>.s3-website-ap-northeast-1.amazonaws.com
```

### ベストプラクティス

| 項目 | 推奨 | 理由 |
|------|------|------|
| キー命名 | ハッシュプレフィックス付与（例: `abc123/data.csv`） | パーティション分散でスロットリング回避 |
| 大容量アップロード | マルチパートアップロード（>100MB） | 信頼性向上・並列化 |
| 結果整合性 | 書き込み直後の読み取りに注意 | PUTは強整合、DELETEは結果整合 |
| 暗号化 | SSE-S3 or SSE-KMS を必ず指定 | 保存データの保護 |

---

## EBS（第9章）

### CloudFormation でのボリューム作成・アタッチ

```yaml
Resources:
  DataVolume:
    Type: AWS::EC2::Volume
    Properties:
      AvailabilityZone: !GetAtt MyInstance.AvailabilityZone
      Size: 100
      VolumeType: gp2
      Encrypted: true

  VolumeAttachment:
    Type: AWS::EC2::VolumeAttachment
    Properties:
      Device: /dev/sdf
      InstanceId: !Ref MyInstance
      VolumeId: !Ref DataVolume
```

### ボリュームタイプ比較（表9-2）

| タイプ | サイズ | 最大スループット | 最大IOPS | バーストIOPS |
|--------|--------|----------------|---------|------------|
| gp2（汎用SSD） | 1GB〜16TiB | 160 MiB/s | 3IOPS/GiB（最大10,000） | 3,000 |
| io1（プロビジョンドSSD） | 4GiB〜16TiB | 500 MiB/s | 最大50IOPS/GiB or 32,000 | なし |
| st1（スループット最適化HDD） | 500GiB〜16TiB | 最大500 MiB/s | 500 | 40MiB/TiB（最大500） |
| sc1（コールドHDD） | 500GiB〜16TiB | 最大250 MiB/s | 250 | 12MiB/TiB（最大250） |
| Magnetic（旧世代） | 1GiB〜1TiB | 約40〜90 MiB/s | 約100 | なし |

### パフォーマンス計測（dd コマンド）

```bash
# 書き込みテスト（1GBファイルを512KBブロックで）
dd if=/dev/zero of=/mnt/ebs/testfile bs=512k count=2048 oflag=direct

# 読み取りテスト
dd if=/mnt/ebs/testfile of=/dev/null bs=512k

# ioping でレイテンシ計測
ioping -c 10 /mnt/ebs/
```

**実測値の目安**（gp2, 100GB）:
- シーケンシャル書き込み: ~128 MiB/s
- シーケンシャル読み取り: ~128 MiB/s
- IOPS: ~300（バースト時3,000）

### スナップショットバックアップ

```bash
# スナップショット作成
aws ec2 create-snapshot \
  --volume-id vol-xxxx \
  --description "Daily backup $(date +%Y-%m-%d)"

# スナップショット一覧
aws ec2 describe-snapshots --owner-ids self

# スナップショットから新ボリューム作成
aws ec2 create-volume \
  --snapshot-id snap-xxxx \
  --availability-zone ap-northeast-1a \
  --volume-type gp2
```

### EBS 最適化の選択

- `EbsOptimized: true` をインスタンスに設定すると、EBS専用帯域が割り当てられる
- m4, c4, r4 系などは追加料金なし。t2系は別途料金発生

---

## インスタンスストア（第10章）

### 特性

| 項目 | 内容 |
|------|------|
| データ永続性 | インスタンス停止・終了で消失 |
| 速度（書き込み） | 約430 MB/s（gp2 EBSの約6倍） |
| 速度（読み取り） | 約3.9 GB/s（gp2 EBSの約60倍） |
| 費用 | インスタンス料金に含まれる（無料） |
| 用途 | 一時ファイル・キャッシュ・バッファ・スクラッチ領域 |

### CloudFormation でのアタッチ

```yaml
Resources:
  MyInstance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: m3.medium  # インスタンスストア搭載モデル
      BlockDeviceMappings:
        - DeviceName: /dev/sdb
          VirtualName: ephemeral0
        - DeviceName: /dev/sdc
          VirtualName: ephemeral1
```

### パフォーマンス計測

```bash
# マウント確認
lsblk
df -h

# 書き込み速度計測
dd if=/dev/zero of=/mnt/instancestore/testfile bs=1M count=1024 oflag=direct
# 結果例: 430 MB/s

# 読み取り速度計測
dd if=/mnt/instancestore/testfile of=/dev/null bs=1M
# 結果例: 3.9 GB/s
```

### 重要データのバックアップ

インスタンスストアのデータは定期的に S3 へ同期する:

```bash
# cronで定期同期
*/10 * * * * aws s3 sync /mnt/instancestore/work s3://backup-bucket/instancestore/
```

---

## EFS（第10章）

### CloudFormation 定義

```yaml
Resources:
  MyEFS:
    Type: AWS::EFS::FileSystem
    Properties:
      PerformanceMode: generalPurpose  # or maxIO
      Encrypted: true
      ThroughputMode: bursting  # or provisioned
      LifecyclePolicies:
        - TransitionToIA: AFTER_30_DAYS

  MountTarget1:
    Type: AWS::EFS::MountTarget
    Properties:
      FileSystemId: !Ref MyEFS
      SubnetId: !Ref PrivateSubnet1
      SecurityGroups:
        - !Ref EFSSecurityGroup

  EFSSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: EFS mount target
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 2049  # NFSv4.1
          ToPort: 2049
          SourceSecurityGroupId: !Ref EC2SecurityGroup
```

### EC2 からのマウント

```bash
# amazon-efs-utils インストール（Amazon Linux 2）
sudo yum install -y amazon-efs-utils

# マウント（NFSv4.1）
sudo mount -t efs \
  -o tls,iam \
  fs-xxxx:/ \
  /mnt/efs

# /etc/fstab へ永続化
echo "fs-xxxx:/ /mnt/efs efs _netdev,tls,iam 0 0" | sudo tee -a /etc/fstab

# マウント確認
df -h /mnt/efs
```

### パフォーマンスモード

| モード | 用途 | レイテンシ | スループット |
|--------|------|----------|------------|
| General Purpose | Webサーバー・CMS・一般ファイル共有 | 低レイテンシ | 最大7,000 ops/s |
| Max I/O | ビッグデータ・並列処理・機械学習 | やや高いレイテンシ | 実質無制限 |

### バースト容量

- **バースト速度**: 最低100 MiB/s、またはファイルシステムサイズ × 0.3 MiB/s（大きい方）
- **バーストクレジット**: 1TB未満では蓄積が重要
- クレジット枯渇時: ベースライン（50KB/s per GiB）まで低下

### CloudWatch 監視メトリクス

| メトリクス | 説明 | アラート基準 |
|-----------|------|------------|
| BurstCreditBalance | バーストクレジット残量 | 残量が減少傾向なら要対応 |
| PercentIOLimit | I/O制限使用率（General Purposeのみ） | 80%超でMax I/O移行を検討 |
| TotalIOBytes | 総I/Oバイト数 | スループット傾向把握 |
| StorageBytes | 使用容量 | コスト管理 |

---

## RDS（第11章）

### CloudFormation でのMySQL起動

```yaml
Resources:
  MyDB:
    Type: AWS::RDS::DBInstance
    Properties:
      DBInstanceIdentifier: mydb
      DBInstanceClass: db.t3.micro
      Engine: mysql
      EngineVersion: "8.0"
      MasterUsername: admin
      MasterUserPassword: !Ref DBPassword
      DBName: myapp
      AllocatedStorage: 20
      StorageType: gp2
      MultiAZ: false
      BackupRetentionPeriod: 7
      PreferredBackupWindow: "03:00-04:00"
      PreferredMaintenanceWindow: "Mon:04:00-Mon:05:00"
      VPCSecurityGroups:
        - !Ref DBSecurityGroup
      DBSubnetGroupName: !Ref DBSubnetGroup
      DeletionProtection: true
```

### データインポート（mysqldump）

```bash
# エクスポート
mysqldump -h old-host -u admin -p myapp > dump.sql

# RDS にインポート
mysql -h mydb.xxxx.ap-northeast-1.rds.amazonaws.com \
  -u admin -p myapp < dump.sql

# 大容量の場合（並列・圧縮）
mysqldump --single-transaction -h old-host -u admin -p myapp | \
  gzip > dump.sql.gz

zcat dump.sql.gz | \
  mysql -h mydb.xxxx.rds.amazonaws.com -u admin -p myapp
```

### バックアップと復元

```bash
# 手動スナップショット作成
aws rds create-db-snapshot \
  --db-instance-identifier mydb \
  --db-snapshot-identifier mydb-snapshot-$(date +%Y%m%d)

# スナップショット一覧
aws rds describe-db-snapshots \
  --db-instance-identifier mydb

# スナップショットからリストア
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier mydb-restored \
  --db-snapshot-identifier mydb-snapshot-20240101

# クロスリージョンコピー
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:ap-northeast-1:xxxx:snapshot:mydb-snap \
  --target-db-snapshot-identifier mydb-snap-us-west-2 \
  --region us-west-2
```

### Multi-AZ 高可用性

| 構成 | RTO | RPO | 用途 |
|------|-----|-----|------|
| Single-AZ | 分〜時間 | 数分 | 開発・テスト |
| Multi-AZ | 1〜2分 | 0（同期レプリケーション） | 本番 |
| Multi-AZ + Read Replica | 同上 | 0 | 読み取り性能重視 |

```bash
# Multi-AZ に変更（停止なしで適用可能）
aws rds modify-db-instance \
  --db-instance-identifier mydb \
  --multi-az \
  --apply-immediately
```

### リードレプリカ

```bash
# リードレプリカ作成
aws rds create-db-instance-read-replica \
  --db-instance-identifier mydb-replica \
  --source-db-instance-identifier mydb \
  --db-instance-class db.t3.small

# レプリカをスタンドアロンに昇格（DR用途）
aws rds promote-read-replica \
  --db-instance-identifier mydb-replica
```

### パフォーマンス調整

| パラメータ | 用途 | 変更方法 |
|-----------|------|---------|
| innodb_buffer_pool_size | クエリキャッシュ（総メモリの70〜80%目安） | パラメータグループ |
| max_connections | 同時接続数上限 | パラメータグループ |
| slow_query_log | スロークエリログ有効化 | パラメータグループ |
| Performance Insights | クエリ・待機状況の可視化 | コンソールから有効化 |

---

## ElastiCache（第12章）

### デプロイメントオプション（表12-2）

| 機能 | Memcached | Redis（単一ノード） | Redis（レプリケーション無効） | Redis（レプリケーション有効） |
|------|-----------|-------------------|------------------------|------------------------|
| バックアップ/復元 | 不可 | 可 | 可 | 可 |
| レプリケーション | 不可 | 不可 | 可 | 可 |
| シャーディング | 可 | 不可 | 不可 | 可 |
| マルチAZ | 可 | 不可 | 可 | 可 |
| データ型 | シンプル | 豊富（List/Set/Hash等） | 豊富 | 豊富 |

### CloudFormation 定義（Redis クラスター）

```yaml
Resources:
  RedisCluster:
    Type: AWS::ElastiCache::ReplicationGroup
    Properties:
      ReplicationGroupDescription: "Redis cluster"
      NumCacheClusters: 2
      CacheNodeType: cache.r6g.large
      Engine: redis
      EngineVersion: "7.0"
      AtRestEncryptionEnabled: true
      TransitEncryptionEnabled: true
      AuthToken: !Ref RedisAuthToken
      AutomaticFailoverEnabled: true
      MultiAZEnabled: true
      CacheSubnetGroupName: !Ref CacheSubnetGroup
      SecurityGroupIds:
        - !Ref CacheSecurityGroup

  CacheSubnetGroup:
    Type: AWS::ElastiCache::SubnetGroup
    Properties:
      Description: "Cache subnet group"
      SubnetIds:
        - !Ref PrivateSubnet1
        - !Ref PrivateSubnet2
```

### アクセス制御（セキュリティ4層）

| 層 | 手段 | 内容 |
|----|------|------|
| ネットワーク | Security Group | ポート6379へのアクセス元を制限 |
| 認証 | AUTH トークン | `requirepass` に相当、Redis専用 |
| 通信暗号化 | TLS（in-transit） | `TransitEncryptionEnabled: true` |
| 保存暗号化 | AES-256（at-rest） | `AtRestEncryptionEnabled: true` |

### Discourse との統合例

```yaml
# Discourse の redis.yml
production:
  host: redis-cluster.xxxx.cache.amazonaws.com
  port: 6379
  password: <%= ENV['REDIS_AUTH_TOKEN'] %>
  ssl: true
  db: 0
```

### CloudWatch 監視メトリクス

| メトリクス | 説明 | アラート基準 |
|-----------|------|------------|
| CPUUtilization | CPU使用率 | 90%超 |
| SwapUsage | スワップ使用量 | 50MB超（Memcached/Redis共通） |
| Evictions | キャッシュ追い出し数 | 急増時はメモリ不足を疑う |
| ReplicationLag | レプリカの遅延（秒） | 数秒超で調査 |
| CacheMisses | キャッシュミス数 | ヒット率低下の検知 |
| CurrConnections | 現在の接続数 | 上限に近づいたら拡張 |

### パフォーマンス調整

```bash
# ノードタイプ変更（オンラインスケーリング）
aws elasticache modify-replication-group \
  --replication-group-id my-redis \
  --cache-node-type cache.r6g.xlarge \
  --apply-immediately

# シャード追加（Redis クラスターモード）
aws elasticache modify-replication-group-shard-configuration \
  --replication-group-id my-redis \
  --node-group-count 4 \
  --resharding-configuration ...
```

| 調整項目 | 対処法 |
|---------|-------|
| メモリ不足（Eviction多発） | ノードタイプアップ or シャード追加 |
| CPU高負荷 | 読み取り専用をレプリカへ誘導 |
| レプリカ遅延 | 書き込み量削減・ネットワーク帯域確認 |
| バリュー圧縮 | アプリ側で gzip 圧縮して保存 |

---

## DynamoDB（第13章）

### テーブル設計モデル

| 要素 | 説明 | 例 |
|------|------|-----|
| テーブル | データの集合 | `users`, `orders` |
| アイテム | 行に相当（最大400KB） | 1ユーザーのデータ |
| 属性 | 列に相当 | `userId`, `email` |
| パーティションキー | 必須の主キー | `userId` |
| ソートキー | 複合主キーの第2要素 | `orderId` |

### DynamoDB Local（開発環境）

```bash
# Docker で起動
docker run -p 8000:8000 amazon/dynamodb-local

# ローカル向け AWS CLI
aws dynamodb list-tables \
  --endpoint-url http://localhost:8000 \
  --region ap-northeast-1

# テーブル作成
aws dynamodb create-table \
  --endpoint-url http://localhost:8000 \
  --table-name users \
  --attribute-definitions \
    AttributeName=userId,AttributeType=S \
    AttributeName=email,AttributeType=S \
  --key-schema \
    AttributeName=userId,KeyType=HASH \
    AttributeName=email,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
```

### CRUD 操作（CLI）

```bash
# Put（追加/上書き）
aws dynamodb put-item \
  --table-name users \
  --item '{"userId":{"S":"u001"},"email":{"S":"alice@example.com"},"age":{"N":"30"}}'

# Get（主キーで取得）
aws dynamodb get-item \
  --table-name users \
  --key '{"userId":{"S":"u001"},"email":{"S":"alice@example.com"}}'

# Update（特定属性のみ更新）
aws dynamodb update-item \
  --table-name users \
  --key '{"userId":{"S":"u001"},"email":{"S":"alice@example.com"}}' \
  --update-expression "SET age = :newAge" \
  --expression-attribute-values '{":newAge":{"N":"31"}}'

# Delete
aws dynamodb delete-item \
  --table-name users \
  --key '{"userId":{"S":"u001"},"email":{"S":"alice@example.com"}}'
```

### GSI（グローバルセカンダリインデックス）

```bash
# GSI を持つテーブル作成
aws dynamodb create-table \
  --table-name orders \
  --attribute-definitions \
    AttributeName=orderId,AttributeType=S \
    AttributeName=userId,AttributeType=S \
    AttributeName=createdAt,AttributeType=S \
  --key-schema AttributeName=orderId,KeyType=HASH \
  --global-secondary-indexes '[
    {
      "IndexName": "userId-createdAt-index",
      "KeySchema": [
        {"AttributeName":"userId","KeyType":"HASH"},
        {"AttributeName":"createdAt","KeyType":"RANGE"}
      ],
      "Projection": {"ProjectionType":"ALL"},
      "ProvisionedThroughput": {"ReadCapacityUnits":5,"WriteCapacityUnits":5}
    }
  ]' \
  --billing-mode PROVISIONED \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

# GSI を使ったクエリ（結果整合性）
aws dynamodb query \
  --table-name orders \
  --index-name userId-createdAt-index \
  --key-condition-expression "userId = :uid" \
  --expression-attribute-values '{":uid":{"S":"u001"}}'
```

### LSI（ローカルセカンダリインデックス）

- テーブル作成時のみ定義可能（後から追加不可）
- パーティションキーはテーブルと同じ、ソートキーのみ変更可能
- 強整合性読み取りが可能（GSIは結果整合のみ）

### スキャンとフィルタ

```bash
# 全件スキャン（コスト高・本番環境では非推奨）
aws dynamodb scan --table-name users

# FilterExpression でのフィルタ（スキャン後にフィルタリング）
aws dynamodb scan \
  --table-name users \
  --filter-expression "age >= :minAge" \
  --expression-attribute-values '{":minAge":{"N":"20"}}'
```

> **注意**: Scan は全データを読み取り後にフィルタするため、RCUを大量消費。大規模テーブルでは Query + GSI を使用すること。

### 整合性モデル

| 読み取り種別 | ConsistentRead | RCU消費 | ユースケース |
|------------|---------------|--------|------------|
| 結果整合性（デフォルト） | false | 0.5 RCU per 4KB | 一般的な読み取り |
| 強整合性 | true | 1.0 RCU per 4KB | 直前書き込みの即時確認 |
| トランザクション読み取り | - | 2.0 RCU per 4KB | ACID保証が必要な場合 |

### キャパシティユニットの計算

**RCU（読み取り）**:
- 結果整合: `ceil(アイテムサイズ / 4KB) × 0.5`
- 強整合: `ceil(アイテムサイズ / 4KB) × 1.0`

**WCU（書き込み）**:
- `ceil(アイテムサイズ / 1KB) × 1.0`

**例**: 3.5KBのアイテムを強整合で読み取り → `ceil(3.5/4) = 1 RCU`

### Application Auto Scaling

```yaml
Resources:
  WriteScalingTarget:
    Type: AWS::ApplicationAutoScaling::ScalableTarget
    Properties:
      MaxCapacity: 100
      MinCapacity: 5
      ResourceId: !Sub "table/${UsersTable}"
      RoleARN: !Sub "arn:aws:iam::${AWS::AccountId}:role/AWSServiceRoleForApplicationAutoScaling_DynamoDBTable"
      ScalableDimension: dynamodb:table:WriteCapacityUnits
      ServiceNamespace: dynamodb

  WriteScalingPolicy:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Properties:
      PolicyName: WriteAutoScaling
      PolicyType: TargetTrackingScaling
      ScalingTargetId: !Ref WriteScalingTarget
      TargetTrackingScalingPolicyConfiguration:
        TargetValue: 50.0  # 50%使用率をターゲット
        PredefinedMetricSpecification:
          PredefinedMetricType: DynamoDBWriteCapacityUtilization
```

> **関連**: サービス選定・設計パターンの詳細は [`DATABASE-SERVICES.md`](DATABASE-SERVICES.md) を参照。コスト最適化・FinOps は [`BEDROCK-GETTING-STARTED.md`](BEDROCK-GETTING-STARTED.md) の FinOps セクションを参照。
