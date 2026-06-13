# Memorystore 運用ガイド

Google Cloud Memorystore インスタンスのプロビジョニング、構成、パフォーマンスエンジニアリング、セキュリティ運用を解説する。

---

## プロビジョニング

Memorystore インスタンスは複数のインターフェースで作成可能。ワークフロー、スケール、自動化要件に応じて選択する。

### Cloud Console（GUI）

**用途**: 探索的タスク、低頻度のプロビジョニング

**主要パラメータ**:
| パラメータ | 説明 |
|-----------|------|
| **Instance ID** | プロジェクト・リージョン内で一意の識別子 |
| **Region / Zone** | 地理的位置（レイテンシ・コンプライアンス最適化） |
| **Instance Tier** | Basic（単一ノード） / Standard（HA: プライマリ+レプリカ） |
| **Memory Size** | プロビジョニングメモリ容量（GB単位） |
| **Authorized Networks** | 接続許可するVPCネットワーク |

**制約**:
- 手動操作のため、バルク/反復デプロイには不向き
- 自動化・バージョン管理が困難

---

### gcloud CLI

**用途**: スクリプト化・反復可能なプロビジョニング、CI/CDパイプライン統合

**基本コマンド**:
```bash
gcloud redis instances create redis-instance-1 \
    --size=4 \
    --region=us-central1 \
    --zone=us-central1-c \
    --tier=STANDARD_HA \
    --redis-version=redis_6_x \
    --authorized-network=projects/my-project/global/networks/default
```

**主要フラグ**:
| フラグ | 説明 |
|-------|------|
| `--size` | メモリ容量（GB） |
| `--region` / `--zone` | 物理配置 |
| `--tier` | `BASIC`（単一ノード）/ `STANDARD_HA`（プライマリ+レプリカ） |
| `--redis-version` | Redisサーバーバージョン（`redis_6_x`、`redis_7_x` 等） |
| `--authorized-network` | VPCネットワークアクセス制御 |

**利点**:
- 詳細な進捗フィードバック・エラー報告
- バッチスクリプト・CI/CD統合が容易
- パラメータのバージョン管理が可能

---

### REST API

**用途**: カスタムクライアント・自動化フレームワーク統合

**エンドポイント**: `redis.projects.locations.instances`

**プロビジョニング例（POST リクエスト）**:
```json
{
  "instanceId": "redis-instance-api",
  "tier": "STANDARD_HA",
  "memorySizeGb": 4,
  "redisVersion": "REDIS_6_X",
  "authorizedNetwork": "projects/my-project/global/networks/default"
}
```

---

### Terraform（Infrastructure as Code）

**用途**: 宣言的インフラ管理、環境再現性、複数リソース統合

**基本構成例**:
```hcl
resource "google_redis_instance" "cache" {
  name           = "memorystore-instance"
  tier           = "STANDARD_HA"
  memory_size_gb = 4
  region         = "us-central1"
  redis_version  = "REDIS_6_X"

  authorized_network = data.google_compute_network.default.id

  redis_configs = {
    maxmemory-policy = "allkeys-lru"
  }
}
```

**利点**:
- インフラ構成をコードとしてバージョン管理
- 環境間（dev/staging/prod）の一貫性保証
- 依存リソース（VPC、Firewall等）を統合管理

---

### Cloud Build CI/CD統合

**用途**: 自動デプロイメント、継続的インテグレーション

**cloudbuild.yaml例**:
```yaml
steps:
  # Memorystore インスタンス作成
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'redis'
      - 'instances'
      - 'create'
      - 'redis-${_ENV}'
      - '--size=4'
      - '--region=${_REGION}'
      - '--tier=STANDARD_HA'

  # Terraform適用
  - name: 'hashicorp/terraform:latest'
    args:
      - 'apply'
      - '-auto-approve'
    dir: 'infrastructure/'

substitutions:
  _ENV: 'prod'
  _REGION: 'us-central1'
```

---

## インスタンス構成

### Tier選択

| Tier | 構成 | 可用性 | ユースケース |
|------|------|--------|-------------|
| **Basic** | 単一ノード | SLA保証なし | 開発・テスト環境、非クリティカルキャッシュ |
| **Standard（HA）** | プライマリ+レプリカ | 99.9% SLA | 本番環境、高可用性要件 |

**選択基準**:
- **Basic**: コスト重視、データ損失許容
- **Standard**: 可用性・自動フェイルオーバー必須

---

### メモリサイジング

**考慮事項**:
| 要素 | 推奨アプローチ |
|------|---------------|
| **ワーキングセット** | 頻繁にアクセスするデータ量を見積もる |
| **エビクション率** | メモリ枯渇時のキー削除頻度を監視 |
| **メモリ使用率** | 80%以下を維持（バッファ確保） |

**サイジング計算例**:
```
想定データサイズ: 3GB
バッファ（20%）: 0.6GB
推奨メモリ: 4GB（最小構成）
```

**Cloud Monitoring メトリクス**:
- `redis.googleapis.com/stats/memory/usage_ratio`
- `redis.googleapis.com/stats/evicted_keys`

---

### Redisバージョン選択

| バージョン | 主要機能 | 推奨用途 |
|-----------|---------|---------|
| **Redis 6.x** | ACL、SSL/TLS、RESP3 | 本番安定版 |
| **Redis 7.x** | Redis Functions、Sharded Pub/Sub | 最新機能活用 |

**アップグレード戦略**:
```bash
# インスタンスのバージョン確認
gcloud redis instances describe INSTANCE_ID --region=REGION

# アップグレード（ダウンタイムあり）
gcloud redis instances upgrade INSTANCE_ID \
    --redis-version=redis_7_x \
    --region=REGION
```

---

## VPCネットワーキング

### Private Service Access

**概念**: Memorystore インスタンスを VPC 内のプライベート IP アドレス空間に配置

**設定手順**:
```bash
# Private Service Connection作成
gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=google-managed-services-default \
    --network=default

# Memorystore作成（自動的にPrivate IPを取得）
gcloud redis instances create redis-private \
    --size=4 \
    --region=us-central1 \
    --authorized-network=projects/my-project/global/networks/default
```

**利点**:
- パブリックインターネットを経由しない
- レイテンシ削減（同一リージョン内通信）
- セキュリティ強化（VPCファイアウォール適用可能）

---

### Authorized Networks

**用途**: 特定のVPCネットワークのみに接続を制限

**設定例**:
```bash
# 既存インスタンスにAuthorized Network追加
gcloud redis instances update INSTANCE_ID \
    --region=REGION \
    --authorized-network=projects/PROJECT_ID/global/networks/VPC_NAME
```

**注意事項**:
- VPCピアリングが必要
- Shared VPC環境ではプロジェクト間の権限設定が必要

---

## パフォーマンスエンジニアリング

### ベンチマーク指標

| 指標 | 説明 | 目標値例 |
|------|------|---------|
| **レイテンシ（P50）** | 50%のリクエストの応答時間 | < 1ms |
| **レイテンシ（P99）** | 99%のリクエストの応答時間 | < 5ms |
| **スループット** | 秒間オペレーション数（OPS） | > 100,000 OPS |
| **キャッシュヒット率** | キャッシュから直接応答した割合 | > 95% |

---

### memtier_benchmark

**用途**: Memorystore パフォーマンステスト（Redisプロトコル対応）

**基本コマンド**:
```bash
memtier_benchmark --server=your-memorystore-host --port=6379 \
                  --protocol=redis --clients=50 --threads=4 \
                  --test-time=60 --pipeline=10
```

**主要オプション**:
| オプション | 説明 |
|-----------|------|
| `--server` | Memorystore ホストアドレス |
| `--port` | ポート番号（デフォルト: 6379） |
| `--clients` | 同時接続クライアント数 |
| `--threads` | ワーカースレッド数 |
| `--test-time` | テスト実行時間（秒） |
| `--pipeline` | パイプライン深度（コマンドバッチング） |

**出力例**:
```
ALL STATS
========================================================================
Type         Ops/sec     Hits/sec   Misses/sec    Avg. Latency     P50 Latency     P99 Latency
------------------------------------------------------------------------
Gets       120000.00    114000.00      6000.00        0.82ms          0.70ms          4.20ms
Sets        30000.00         ---         ---          0.91ms          0.80ms          4.50ms
```

---

### レイテンシ分析

**パーセンタイル重視**:
- **平均レイテンシ**: 全体傾向を把握
- **P99レイテンシ**: 最悪ケース分析（ユーザー体験に直結）

**レイテンシ悪化の原因**:
| 原因 | 対策 |
|------|------|
| ネットワークジッター | VPC配置最適化、リージョン選択 |
| メモリ枯渇・エビクション | メモリサイジング拡大、TTL調整 |
| 接続プール枯渇 | 接続プールサイズ拡大、接続再利用 |
| クライアントGC停止 | クライアント側JVM/GC調整 |

---

### スループット最適化

**飽和点の特定**:
```
クライアント数を段階的に増加
→ スループット線形増加
→ 変曲点（レイテンシ急増開始）
→ 飽和点 = 最大持続可能スループット
```

**最適化手法**:
| 手法 | 効果 |
|------|------|
| **パイプライニング** | ネットワークRTT削減、スループット向上 |
| **接続プーリング** | 接続確立コスト削減 |
| **Read Replicas** | 読み取り負荷分散（Standard HA利用） |
| **垂直スケーリング** | メモリ・CPU増強 |
| **水平スケーリング** | 複数インスタンス・シャーディング |

---

## 接続管理

### 接続プーリング

**Python（redis-py）例**:
```python
import redis

# 接続プール作成
pool = redis.ConnectionPool(
    host='MEMORYSTORE_IP',
    port=6379,
    max_connections=50,
    socket_keepalive=True,
    socket_keepalive_options={
        socket.TCP_KEEPIDLE: 60,
        socket.TCP_KEEPINTVL: 10,
        socket.TCP_KEEPCNT: 3
    }
)

# クライアント作成（プールから接続取得）
client = redis.Redis(connection_pool=pool)

# 操作例
client.set('key', 'value', ex=3600)
value = client.get('key')
```

**ベストプラクティス**:
- 接続プールサイズ = 同時リクエスト数 × 1.2（バッファ）
- `socket_keepalive` 有効化（アイドル接続維持）
- タイムアウト設定（`socket_timeout`, `socket_connect_timeout`）

---

### パイプライニング

**用途**: 複数コマンドをバッチ実行（RTT削減）

**実装例**:
```python
pipe = client.pipeline()
pipe.set('key1', 'value1')
pipe.set('key2', 'value2')
pipe.set('key3', 'value3')
pipe.get('key1')
results = pipe.execute()  # 1回のRTTで実行
```

**効果**:
- ネットワークラウンドトリップ削減
- スループット向上（特に小さなコマンド連続実行時）

---

### Pub/Sub

**用途**: リアルタイムメッセージング、イベント駆動アーキテクチャ

**Publisher例**:
```python
client.publish('notifications', 'User logged in')
```

**Subscriber例**:
```python
pubsub = client.pubsub()
pubsub.subscribe('notifications')

for message in pubsub.listen():
    if message['type'] == 'message':
        print(f"Received: {message['data']}")
```

**注意事項**:
- Pub/Subは永続化なし（サブスクライバー不在時はメッセージ消失）
- 高信頼性が必要な場合は Cloud Pub/Sub を検討

---

## スケーリング戦略

### 垂直スケーリング（Scale Up）

**概念**: 単一インスタンスのメモリ・CPU増強

**実行方法**:
```bash
# メモリサイズ変更（ダウンタイムあり）
gcloud redis instances update INSTANCE_ID \
    --size=8 \
    --region=REGION
```

**メリット**:
- アーキテクチャ変更不要
- 即座にパフォーマンス向上

**デメリット**:
- 物理的限界あり（最大メモリ上限）
- 単一障害点（SPOF）

---

### 水平スケーリング（Scale Out）

**概念**: 複数インスタンス・シャーディングで負荷分散

**シャーディング戦略**:
| 戦略 | 説明 | 実装 |
|------|------|------|
| **ハッシュベース** | キーのハッシュ値でインスタンス決定 | Consistent Hashing |
| **範囲ベース** | キー範囲でインスタンス分割 | アプリケーションロジック |
| **地理的分散** | リージョン別インスタンス | マルチリージョン展開 |

**クライアント側シャーディング例**:
```python
from rediscluster import RedisCluster

startup_nodes = [
    {"host": "instance1-ip", "port": 6379},
    {"host": "instance2-ip", "port": 6379},
    {"host": "instance3-ip", "port": 6379}
]

cluster = RedisCluster(startup_nodes=startup_nodes, decode_responses=True)
cluster.set('key', 'value')  # 自動的に適切なシャードへルーティング
```

---

### Read Replicas（Standard HA）

**概念**: 読み取り専用レプリカで読み取り負荷分散

**Standard HA構成**:
```
プライマリ（書き込み + 読み取り）
    ↓ 同期レプリケーション
レプリカ（読み取り専用）
```

**接続方法**:
```python
# プライマリ（書き込み用）
primary_client = redis.Redis(host='PRIMARY_IP', port=6379)

# レプリカ（読み取り用）
replica_client = redis.Redis(host='REPLICA_IP', port=6379)

# 書き込み
primary_client.set('key', 'value')

# 読み取り（レプリカから）
value = replica_client.get('key')
```

**注意事項**:
- レプリカは最終的一貫性（数ミリ秒の遅延）
- 強一貫性が必要な場合はプライマリから読み取り

---

## セキュリティ

### 転送中の暗号化（TLS/SSL）

**有効化**:
```bash
# TLS有効化（インスタンス作成時）
gcloud redis instances create redis-tls \
    --size=4 \
    --region=us-central1 \
    --tier=STANDARD_HA \
    --transit-encryption-mode=SERVER_AUTHENTICATION
```

**クライアント接続（Python）**:
```python
import redis

client = redis.Redis(
    host='MEMORYSTORE_IP',
    port=6379,
    ssl=True,
    ssl_cert_reqs='required',
    ssl_ca_certs='/path/to/ca-cert.pem'
)
```

**プロトコル**: TLS 1.2+、AES-GCM暗号化、ECDH鍵交換

---

### 保存時の暗号化（At-Rest）

**自動有効化**: Memorystore スナップショット・バックアップは AES-256 で自動暗号化

**顧客管理暗号化キー（CMEK）**:
```bash
# Cloud KMS キー作成
gcloud kms keyrings create memorystore-keyring --location=us-central1
gcloud kms keys create memorystore-key \
    --location=us-central1 \
    --keyring=memorystore-keyring \
    --purpose=encryption

# CMEK使用インスタンス作成
gcloud redis instances create redis-cmek \
    --size=4 \
    --region=us-central1 \
    --tier=STANDARD_HA \
    --kms-key=projects/PROJECT_ID/locations/us-central1/keyRings/memorystore-keyring/cryptoKeys/memorystore-key
```

**キーローテーション**:
```bash
# 自動ローテーション有効化（90日周期推奨）
gcloud kms keys update memorystore-key \
    --location=us-central1 \
    --keyring=memorystore-keyring \
    --rotation-period=90d \
    --next-rotation-time=2024-04-01T00:00:00Z
```

---

### IAMポリシー

**最小権限原則（PoLP）適用**:

| ロール | 権限 | ユースケース |
|-------|------|------------|
| `roles/redis.admin` | 完全管理権限 | インフラ管理者 |
| `roles/redis.editor` | インスタンス作成・更新・削除 | DevOps |
| `roles/redis.viewer` | 読み取り専用 | 監視・監査 |

**カスタムロール例**:
```bash
# カスタムロール作成（読み取り + 接続のみ）
gcloud iam roles create memorystore_reader \
    --project=PROJECT_ID \
    --title="Memorystore Reader" \
    --permissions=redis.instances.get,redis.instances.list
```

**サービスアカウント割り当て**:
```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member=serviceAccount:app-service-account@PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/redis.viewer
```

---

### ネットワークセキュリティ

**VPCファイアウォールルール**:
```bash
# Memorystore接続許可（特定ソースIPのみ）
gcloud compute firewall-rules create allow-memorystore \
    --network=default \
    --allow=tcp:6379 \
    --source-ranges=10.0.0.0/24 \
    --target-tags=memorystore-client
```

**Private Service Connect**:
- パブリックIPアドレス不要
- VPC内部通信のみ
- Cloud VPN / Cloud Interconnect経由でオンプレミス接続可能

---

### 監査ログ

**有効化**:
```bash
# 管理アクティビティログ（デフォルト有効）
gcloud logging read "resource.type=redis_instance" --limit=50

# データアクセスログ有効化
gcloud projects get-iam-policy PROJECT_ID --flatten="bindings[].members" \
    --filter="bindings.role:roles/redis.admin" > policy.yaml

# policy.yaml編集後
gcloud projects set-iam-policy PROJECT_ID policy.yaml
```

**監査対象**:
- インスタンス作成・削除・更新
- IAMポリシー変更
- データアクセス（有効化時）

---

### コンプライアンス

**対応規格**:
| 規格 | 要件 | Memorystore対応 |
|------|------|----------------|
| **GDPR** | データ保護・暗号化 | TLS/At-Rest暗号化、CMEK |
| **HIPAA** | ヘルスケアデータ保護 | BAA締結可能、監査ログ |
| **PCI-DSS** | カード決済データ保護 | ネットワーク分離、暗号化 |
| **SOC 2** | セキュリティ管理 | 監査レポート提供 |

**コンプライアンスチェックリスト**:
- [ ] TLS/SSL有効化
- [ ] CMEK（顧客管理暗号化キー）使用
- [ ] IAM最小権限適用
- [ ] VPCファイアウォール設定
- [ ] 監査ログ有効化・定期レビュー
- [ ] 定期的脆弱性スキャン

---

## まとめ

Memorystore 運用の原則:

1. **プロビジョニング**: gcloud CLI / Terraform / CI/CD で自動化
2. **インスタンス構成**: Tier・メモリサイズ・Redisバージョンを要件に基づき選択
3. **VPCネットワーキング**: Private Service Access でセキュアな内部通信
4. **パフォーマンス**: memtier_benchmark でレイテンシ（P50/P99）・スループット測定
5. **接続管理**: 接続プーリング・パイプライニング活用
6. **スケーリング**: 垂直（メモリ増強）→ 水平（シャーディング）の順で検討
7. **セキュリティ**: TLS/At-Rest暗号化・IAM・監査ログで多層防御
