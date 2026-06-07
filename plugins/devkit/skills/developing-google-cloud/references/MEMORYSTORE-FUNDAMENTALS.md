# Memorystore 基礎ガイド

Google Cloud Memorystore のアーキテクチャ、エンジン選択（Redis/Memcached）、データモデリング、キャッシュパターン、GCPサービス統合を解説する。

---

## アーキテクチャ概要

Memorystore は Google Cloud が提供するフルマネージドのインメモリデータストアサービスで、Redis と Memcached の2つのエンジンをサポートする。

### 設計原則

| 原則 | 実装 |
|------|------|
| **ネットワーク分離** | VPC内にデプロイ、プライベートIPアクセス、IAMによるきめ細かいアクセス制御 |
| **コントロール/データプレーン分離** | 管理操作（スケーリング、フェイルオーバー）とデータサービングが独立 |
| **弾力的スケーリング** | 垂直（インスタンスサイズ変更）+ 水平（シャーディング/クラスターモード） |
| **自動復旧** | ヘルスチェック、自動フェイルオーバー、インスタンス再起動 |
| **暗号化** | 転送中暗号化（TLS）、保存時暗号化（基盤レイヤー） |

### マネージドサービスの利点

- 自動パッチ適用・バージョンアップグレード
- バックアップ・ポイントインタイムリカバリ
- Cloud Monitoring / Logging との統合
- VPC・IAMによるエンタープライズセキュリティ

---

## Redis vs Memcached エンジン比較

| 比較項目 | **Redis** | **Memcached** |
|---------|-----------|---------------|
| **データモデル** | 豊富なデータ構造（Strings, Lists, Sets, Hashes, Sorted Sets, Streams, Bitmaps） | 純粋なKey-Value（文字列/バイト配列のみ） |
| **コマンド体系** | 200以上のコマンド、WATCH/MULTI/EXEC、Luaスクリプト | get/set/delete/incr/decr のシンプルなプロトコル |
| **永続化** | RDBスナップショット + AOF（Append-Only File） | なし（完全揮発性） |
| **レプリケーション** | Primary-Replica、クラスターモード | なし（クライアント側シャーディング） |
| **プロトコル** | RESP（Redis Serialization Protocol）、パイプライニング対応 | ASCII/Binary、ステートレス |
| **トランザクション** | MULTI/EXEC、楽観ロック（WATCH） | アトミック操作は incr/decr のみ |
| **Pub/Sub** | ネイティブサポート | なし |
| **マルチスレッド** | シングルスレッド（I/O多重化） | マルチスレッド |
| **ユースケース** | セッション管理、リアルタイム分析、リーダーボード、メッセージキュー | 大規模シンプルキャッシュ、DBクエリ結果キャッシュ |

### エンジン選択フロー

```
要件分析
    ├─ 複雑なデータ構造が必要？（リスト、セット、ソート済みセット等）
    │   → Redis
    ├─ データの永続化が必要？（再起動後もデータ保持）
    │   → Redis
    ├─ Pub/Subメッセージングが必要？
    │   → Redis
    ├─ トランザクション/アトミック操作が必要？
    │   → Redis
    ├─ シンプルなKey-Valueキャッシュのみ？（最大スループット重視）
    │   → Memcached
    └─ キャッシュは使い捨て可能？（再構築が容易）
        → Memcached
```

---

## Redis データ型とユースケース

### データ型一覧

| データ型 | 説明 | 主要コマンド | ユースケース |
|---------|------|------------|------------|
| **Strings** | 最大512MBのバイナリセーフ文字列 | `SET`, `GET`, `INCR`, `DECR`, `MSET`, `MGET` | カウンター、セッションID、設定値 |
| **Lists** | 挿入順序を保持するリンクリスト | `LPUSH`, `RPUSH`, `LPOP`, `RPOP`, `LRANGE` | メッセージキュー、タイムライン、最新N件 |
| **Sets** | 重複なしの文字列コレクション | `SADD`, `SMEMBERS`, `SINTER`, `SUNION`, `SDIFF` | タグ付け、ユニークユーザー追跡、共通要素抽出 |
| **Hashes** | フィールド-値ペアのマップ | `HSET`, `HGET`, `HMSET`, `HGETALL`, `HINCRBY` | ユーザープロファイル、商品情報、オブジェクトストア |
| **Sorted Sets** | スコア付きの順序集合 | `ZADD`, `ZRANGE`, `ZREVRANGE`, `ZRANK`, `ZINCRBY` | リーダーボード、レート制限、優先度キュー |
| **Streams** | 追記型のログデータ構造 | `XADD`, `XREAD`, `XREADGROUP`, `XACK` | イベントソーシング、リアルタイムログ、メッセージブローカー |
| **Bitmaps** | ビット単位の操作 | `SETBIT`, `GETBIT`, `BITCOUNT`, `BITOP` | ユーザーアクティビティ追跡、Bloom Filter |
| **HyperLogLog** | 基数推定 | `PFADD`, `PFCOUNT`, `PFMERGE` | ユニーク訪問者数の概算 |

### コード例: Cache-Aside パターン（Python redis-py）

```python
import redis
import json

client = redis.StrictRedis(
    host='10.0.0.5',  # Memorystore プライベートIP
    port=6379,
    decode_responses=True
)

def get_user(user_id: str) -> dict:
    """Cache-Aside パターン: キャッシュ優先、ミス時にDBフォールバック"""
    cache_key = f"user:{user_id}"

    # 1. キャッシュチェック
    cached = client.get(cache_key)
    if cached:
        return json.loads(cached)

    # 2. キャッシュミス → DB取得
    user = fetch_from_database(user_id)

    # 3. キャッシュに保存（TTL 300秒）
    client.setex(cache_key, 300, json.dumps(user))
    return user
```

---

## キャッシュパターン

### パターン比較

| パターン | 読取 | 書込 | 整合性 | 複雑度 | ユースケース |
|---------|------|------|--------|--------|------------|
| **Cache-Aside（遅延読込）** | キャッシュ優先→ミス時DB | アプリが明示的にキャッシュ更新 | 結果整合性 | 低 | 読取ヘビーなワークロード |
| **Read-Through** | キャッシュが自動でDB取得 | - | 結果整合性 | 中 | 透過キャッシュが必要な場合 |
| **Write-Through** | - | キャッシュとDBを同期書込 | 強整合性 | 中 | データ損失不可のケース |
| **Write-Behind（Write-Back）** | - | キャッシュに書込→非同期DB反映 | 結果整合性 | 高 | 書込ヘビー、レイテンシ重視 |
| **事前ウォーミング** | 起動時に一括ロード | - | 起動時のみ | 低 | 予測可能なアクセスパターン |

### Cache-Aside 実装フロー

```
リクエスト
    ↓
【キャッシュ確認】
    ├─ ヒット → キャッシュからレスポンス返却
    └─ ミス → DB取得 → キャッシュ保存（TTL付き）→ レスポンス返却
```

### Write-Through 実装例

```python
def update_user(user_id: str, data: dict):
    """Write-Through: キャッシュとDBを同期更新"""
    cache_key = f"user:{user_id}"

    # 1. DB更新
    update_database(user_id, data)

    # 2. キャッシュ更新（TTL 300秒）
    client.setex(cache_key, 300, json.dumps(data))
```

---

## キャッシュ無効化戦略

### 戦略比較

| 戦略 | 仕組み | 利点 | 欠点 | 適用場面 |
|------|--------|------|------|---------|
| **TTL（Time-To-Live）** | 一定時間後に自動削除 | シンプル、実装容易 | TTL期間中のstaleデータ | 頻度が低い更新 |
| **イベントドリブン** | DB変更時にキャッシュ削除/更新 | リアルタイム整合性 | イベント配信の複雑性 | 強整合性が必要 |
| **バージョニング** | キーにバージョン番号を含む | 一括無効化が容易 | キー管理の複雑さ | 大規模な一括更新 |
| **Pub/Subベース** | Redis Pub/Subで無効化通知 | 分散環境で効率的 | メッセージ損失の可能性 | マイクロサービス間連携 |

### TTL設定のベストプラクティス

```python
# ユースケース別TTL推奨値
TTL_CONFIG = {
    "session": 1800,       # セッション: 30分
    "user_profile": 300,   # ユーザープロファイル: 5分
    "product_catalog": 3600,  # 商品カタログ: 1時間
    "feature_flags": 60,   # 機能フラグ: 1分
    "api_response": 120,   # API レスポンス: 2分
}
```

---

## エビクションポリシー

メモリが上限に達した場合のキー削除戦略。`maxmemory-policy` で設定する。

| ポリシー | 動作 | 推奨ユースケース |
|---------|------|-----------------|
| **volatile-lru** | TTL付きキーからLRU（最近最低使用）で削除 | TTL付きキャッシュ + 永続キーの混在 |
| **allkeys-lru** | 全キーからLRUで削除 | 純粋なキャッシュ用途（**最も一般的**） |
| **volatile-lfu** | TTL付きキーからLFU（最低頻度使用）で削除 | アクセス頻度に偏りがある場合 |
| **allkeys-lfu** | 全キーからLFUで削除 | ホットキーを保持したい場合 |
| **volatile-random** | TTL付きキーからランダム削除 | 均一アクセスパターン |
| **allkeys-random** | 全キーからランダム削除 | アクセスパターンが不明 |
| **volatile-ttl** | TTL残り時間が短いキーから優先削除 | 短寿命データの優先削除 |
| **noeviction** | 削除しない（書込拒否） | データ損失不可のケース |

---

## GCPサービス統合パターン

### 主要統合先

| GCPサービス | 統合パターン | 接続方式 |
|------------|------------|---------|
| **Compute Engine** | VPC内プライベートIPで直接接続、フロントキャッシュ層 | 同一VPC/Peered VPC |
| **GKE** | Pod → Memorystore（環境変数/ConfigMapで接続文字列管理）、分散ロック | VPC-native connectivity |
| **Cloud Run** | Serverless VPC Access Connector経由 | VPC Connector |
| **Cloud Functions** | Serverless VPC Access Connector経由、レート制限・設定キャッシュ | VPC Connector |
| **App Engine** | Serverless VPC Access Connector経由 | VPC Connector |

### GKE Deployment例

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend-container
        image: gcr.io/project/frontend:latest
        env:
        - name: REDIS_HOST
          value: "10.0.0.5"  # Memorystore プライベートIP
        - name: REDIS_PORT
          value: "6379"
```

### Cloud Functions統合例（Python）

```python
import redis
import os
import json

# モジュールレベルで接続（コールドスタート時のみ初期化）
redis_host = os.getenv('REDIS_HOST', '10.0.0.8')
redis_port = int(os.getenv('REDIS_PORT', 6379))
cache_client = redis.StrictRedis(
    host=redis_host, port=redis_port, decode_responses=True
)

def process_event(event, context):
    """Cloud Functions からMemorystore にアクセス"""
    key = "event_counter"
    count = cache_client.incr(key)
    print(f"Event count: {count}")
    return f"Processed event #{count}"
```

---

## サービスティアと料金モデル

### ティア比較

| 項目 | **Basic** | **Standard** |
|------|-----------|-------------|
| **SLA** | なし | **99.9%** |
| **レプリケーション** | なし | Primary + Replica（マルチゾーン） |
| **自動フェイルオーバー** | なし | あり（約60秒以内） |
| **バックアップ** | なし | 自動バックアップ |
| **メモリ範囲** | 1GB - 300GB | 1GB - 300GB |
| **用途** | 開発/テスト、非クリティカル | 本番環境、高可用性要件 |

### 料金構造

| 課金要素 | 説明 |
|---------|------|
| **インスタンス時間** | ティア × メモリ容量 × 稼働時間で課金 |
| **ネットワーク** | 同一リージョン内は無料、クロスリージョンは課金 |
| **バックアップ** | Standard ティアは自動バックアップ含む |

**コスト最適化のポイント:**
- 開発/テストは Basic ティアを使用
- メモリサイズは実際の使用量 + 20%バッファで設定
- 確約利用割引（CUD）の適用を検討
- Cloud Monitoring で `redis.googleapis.com/stats/memory/usage_ratio` を監視し、適切にサイジング

---

## まとめ

Memorystore は、キャッシュ層・セッション管理・リアルタイムデータ処理において、GCPアプリケーションのパフォーマンスを大幅に向上させるコアサービスである。

**エンジン選択の要点:**
1. 複雑なデータ構造・永続化・Pub/Sub → **Redis**
2. シンプルなKVキャッシュ・最大スループット → **Memcached**

**キャッシュ戦略の要点:**
1. 読取ヘビー → Cache-Aside + TTL
2. 書込ヘビー → Write-Behind（レイテンシ重視）/ Write-Through（整合性重視）
3. エビクション → `allkeys-lru`（一般的）/ `allkeys-lfu`（ホットキー保持）
4. 無効化 → TTL（シンプル）+ イベントドリブン（リアルタイム）

詳細な運用設定は `MEMORYSTORE-OPERATIONS.md`、可用性・DR・監視は `MEMORYSTORE-RESILIENCE.md` を参照。
