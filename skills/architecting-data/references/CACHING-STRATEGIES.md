# Caching Strategies for Enterprise Data Systems

エンタープライズデータシステムにおけるキャッシュ戦略の詳細リファレンス。配置パターン、実装スタイル、モデリング手法を体系化します。

---

## 1. キャッシュ要件定義フレームワーク

キャッシュ設計前に、以下の4つの要件を明確化してください。

### Data Freshness and Consistency

**考慮事項**:
- キャッシュデータはどれほど新鮮である必要があるか？
- staleデータになっても許容されるか？
- 有効期限ポリシー（TTL）は必要か？
- キャッシュ無効化の仕組みは必要か？

**判断基準**:
| データ種別 | Freshness要件 | 戦略 |
|-----------|--------------|------|
| 商品カタログ | 数分〜数時間のstaleness許容 | TTLベース自動無効化 |
| 価格情報 | リアルタイム〜数分 | Write-Through or 明示的無効化 |
| 在庫状況 | リアルタイム | キャッシュ回避 or Write-Through |
| ユーザー設定 | 数分〜数時間 | Cache-Aside with TTL |

### Fault Tolerance

**考慮事項**:
- キャッシュ障害時もシステムは機能するか？
- フェイルオーバーメカニズムは必要か？
- キャッシュダウン時の縮退運転は可能か？

**アーキテクチャパターン**:
```
Application → Cache (Primary)
           ↓ (Fallback on failure)
           → Database (Source of Truth)
```

**実装ポイント**:
- リトライロジック実装
- サーキットブレーカーパターン
- ソースへのフォールバック

### Scalability

**考慮事項**:
- キャッシュは負荷増加に応じてスケールできるか？
- パーティショニング（シャーディング）は必要か？
- キャッシュクラスタリングは必要か？

**スケーリング戦略**:
| 戦略 | 説明 | 適用場面 |
|------|------|----------|
| **Vertical** | メモリ・CPUリソース増強 | 初期段階、シンプルなワークロード |
| **Horizontal (Sharding)** | キャッシュノード追加、データ分散 | 高スループット、大容量データ |
| **Read Replicas** | キャッシュのレプリカ追加 | Read-heavy、地理的分散 |

### Cost

**考慮事項**:
- 実装コストは妥当か？
- 運用コストは負荷に応じて増加するか？
- キャッシュ投資でシステム運用コストが削減されるか？

**コスト削減効果**:
- データベースクエリコスト削減（特にPay-per-queryモデル）
- 垂直スケーリング不要化
- ネットワーク帯域幅削減
- レスポンスタイム改善によるビジネス価値向上

---

## 2. キャッシュ対象の判断基準

### ✅ キャッシュすべきデータ

#### Read-heavy, Slowly Changing

**特徴**:
- 読込み頻度が書込み頻度を大幅に上回る
- データ変更が低頻度

**例**:
- 商品カタログ
- ユーザー設定
- ルックアップテーブル（税率、為替レート）
- 翻訳文字列
- 地域マッピング

#### Expensive to Compute

**特徴**:
- データ取得・計算コストが高い
- 繰返し実行される

**例**:
- アナリティクスデータ（売上トレンド、コンバージョン率）
- ユーザープロファイル（複雑なJOIN、集計）
- 複雑クエリ結果
- レコメンデーション結果
- 集計データ（カテゴリ別売上、地域別パフォーマンス）

#### Low Entropy Data

**定義**: 時間経過しても安定・予測可能なデータ

**例**:
- 為替レート（日次更新）
- 税率（年次更新）
- リージョン⇔倉庫マッピング
- ユーザー⇔リージョンマッピング
- 設定値・フィーチャーフラグ

#### Unreliable or Slow Upstream Dependencies

**特徴**:
- 上流サービスが不安定・遅い
- キャッシュがバッファとして機能

**例**:
- 上流システムのトランザクション状態
- 倉庫の注文ステータス
- サードパーティAPIレスポンス

### ❌ キャッシュすべきでないデータ

**特徴**:
- 急速に変化するデータ
- 高度に動的なデータ
- 本質的に揮発性のデータ

**例**:
- リアルタイム在庫（Write-Through除く）
- 高頻度トランザクションデータ
- リアルタイム価格（オークション、動的価格）
- セキュリティトークン
- ワンタイムパスワード

**注意**: Write-Through、Write-Aroundパターンを使用すれば、一部の急速変化データもキャッシュ可能。

---

## 3. キャッシュ配置パターン

### In-Process (Private) Cache

**特徴**:
```
┌─────────────────────┐
│  Application        │
│  ┌───────────────┐  │
│  │ Private Cache │  │
│  └───────────────┘  │
└─────────────────────┘
```

- アプリケーション/サービスインスタンス内のメモリに存在
- ネットワークホップなし
- 超高速アクセス

**メリット**:
- 極めて低レイテンシ
- ネットワーク不要
- シリアライゼーション不要

**デメリット**:
- インスタンス間で共有不可
- データ重複
- キャッシュ無効化が複雑（全インスタンスに伝播必要）

**適用場面**:
- フィーチャーフラグ
- 設定値
- 通貨換算テーブル
- 翻訳文字列
- 頻繁にアクセスされる参照データ

**実装例**:
- ローカルメモリマップ（HashMap、Dictionary）
- Caffeine（Java）
- LRU Cache

### Shared (Distributed) Cache

**特徴**:
```
┌──────────┐  ┌──────────┐
│  App 1   │  │  App 2   │
└────┬─────┘  └────┬─────┘
     │             │
     └──────┬──────┘
            ↓
    ┌───────────────┐
    │ Shared Cache  │
    └───────────────┘
```

- アプリケーションプロセス外に存在
- 複数サービスからアクセス可能
- ネットワーク経由

**メリット**:
- インスタンス間で整合性・調整可能
- 新規キャッシュデータ追加が容易
- サービス再起動不要でリフレッシュ可能

**デメリット**:
- ネットワークレイテンシ
- シリアライゼーション/デシリアライゼーションコスト
- 運用複雑性増加（可用性、フェイルオーバー）

**適用場面**:
- ショッピングカートデータ
- ユーザーセッション
- 最近クエリされた商品詳細
- APIレスポンスキャッシュ

**実装例**:
- Redis
- Memcached
- AWS ElastiCache
- Hazelcast

---

## 4. 実装パターン

### Cache-Aside (Lazy Loading)

**特徴**: アプリケーションがキャッシュ管理の責任を持つ

**フロー**:
```
Read:
  Application → Cache: Get(key)
  Cache Hit → Return data
  Cache Miss → Database: Query
             → Cache: Set(key, data, TTL)
             → Return data

Write:
  Application → Database: Update
             → Cache: Invalidate(key)
```

**メリット**:
- 実際にアクセスされたデータのみキャッシュ（効率的）
- 実装がシンプル
- キャッシュ障害時もシステム機能（DBフォールバック）

**デメリット**:
- staleデータリスク（無効化失敗時）
- Cache Miss時のレイテンシ（DBラウンドトリップ）
- Write時の無効化ロジック実装が煩雑

**適用タイミング**:
- Read-heavyワークロード
- 頻繁に変更されないデータ
- staleness許容可能
- 商品カタログ、ユーザープロファイル、参照データ

**実装例（擬似コード）**:
```python
def get_product(product_id):
    # Try cache first
    product = cache.get(f"product:{product_id}")
    if product:
        return product

    # Cache miss - fetch from DB
    product = database.query(f"SELECT * FROM products WHERE id = {product_id}")

    # Populate cache with TTL
    cache.set(f"product:{product_id}", product, ttl=3600)

    return product

def update_product(product_id, data):
    # Update database
    database.update(f"UPDATE products SET ... WHERE id = {product_id}", data)

    # Invalidate cache
    cache.delete(f"product:{product_id}")
```

---

### Read-Through Cache

**特徴**: キャッシュがDB取得責任を持つ

**フロー**:
```
Application → Cache: Get(key)
Cache Hit → Return data
Cache Miss → Cache fetches from Database
          → Cache stores data
          → Return data
```

**メリット**:
- アプリケーションロジックとキャッシュ動作分離
- アプリケーションコードがクリーン
- Polyglotアーキテクチャで一貫したキャッシュロジック

**デメリット**:
- Cold Cache時の高初期レイテンシ
- Cache Stampede（同一キー同時Miss）リスク
- Data Staleness（外部変更が即座に反映されない）
- キャッシュレイヤーの複雑性増加

**適用タイミング**:
- アプリケーションロジックとキャッシュ動作を分離したい
- 外部でキャッシュ無効化管理（TTL、イベント駆動）
- 不変または低頻度変更データ（商品属性、設定値、フィーチャーフラグ）
- Lazy Loading動作希望（使用時に段階的にキャッシュ充填）

**緩和策**:
- Cache Warming（事前にホットデータをロード）
- Single-Flight機構（キーごとに1回のみフェッチ）
- TTL調整

---

### Write-Through Cache

**特徴**: 書込み時にキャッシュとDB両方を更新

**フロー**:
```
Write:
  Application → Cache: Set(key, data)
             → Cache writes to Database (synchronous)
             → Database ACK
             → Cache ACK
             → Application ACK

Read:
  Application → Cache: Get(key)
             → Return data (always fresh)
```

**メリット**:
- 強い整合性（キャッシュとDBが常に同期）
- 高いCache Hit率（書込みデータが即座にキャッシュ可能）
- 追加の無効化ロジック不要

**デメリット**:
- Write Latency増加（キャッシュ+DB両方への書込み）
- Write Amplification（毎回2回の操作）
- キャッシュ可用性がクリティカル（Write pathの一部）
- ネットワークパーティション時の不整合リスク

**適用タイミング**:
- Read整合性が高優先度
- Read-after-Write一貫性必要
- ユーザープロファイル更新、設定管理、価格調整
- Write頻度が中程度、Write Latency許容可能

**実装例（擬似コード）**:
```python
def update_product(product_id, data):
    # Write-through: Cache first, then DB
    cache.set(f"product:{product_id}", data)
    database.update(f"UPDATE products SET ... WHERE id = {product_id}", data)

    return data

def get_product(product_id):
    # Cache always has latest data
    return cache.get(f"product:{product_id}")
```

---

### Write-Around Cache

**特徴**: 書込みはDBのみ、読込み時にキャッシュ

**フロー**:
```
Write:
  Application → Database: Update
             → (Cache bypassed)

Read:
  Application → Cache: Get(key)
  Cache Hit → Return data
  Cache Miss → Database: Query
             → Cache: Set(key, data, TTL)
             → Return data
```

**メリット**:
- キャッシュ効率化（ホットデータのみ保持）
- Write Amplification回避
- メモリ節約（コールドデータがキャッシュ汚染しない）

**デメリット**:
- Read整合性課題（書込み後の最初の読込みは必ずCache Miss）
- Write後の読込みレイテンシ増加
- staleデータリスク（古いキーがキャッシュ残存）

**適用タイミング**:
- 高Write頻度、低Read-after-Write頻度
- 新規書込みデータが即座にキャッシュ不要
- 大量取込みワークフロー（カタログ更新、ユーザーアクティビティログ、バッチインポート設定）
- キャッシュ汚染回避

**実装例（擬似コード）**:
```python
def bulk_upload_products(products):
    # Write-around: Direct to DB, bypass cache
    for product in products:
        database.insert("INSERT INTO products ...", product)
    # Cache remains clean, will populate on demand

def get_product(product_id):
    # Cache-aside read logic
    product = cache.get(f"product:{product_id}")
    if not product:
        product = database.query(f"SELECT * FROM products WHERE id = {product_id}")
        cache.set(f"product:{product_id}", product, ttl=3600)
    return product
```

---

## 5. パターン比較テーブル

| パターン | 整合性 | Write Latency | Cache Hit率 | 複雑性 | 適用場面 |
|---------|--------|---------------|-------------|--------|----------|
| **Cache-Aside** | Eventual | 低 | 中 | 低 | Read-heavy、staleness許容 |
| **Read-Through** | Eventual | 低 | 中〜高 | 中 | ロジック分離、Lazy Loading |
| **Write-Through** | Strong | 高 | 高 | 中 | Read-after-Write一貫性 |
| **Write-Around** | Eventual | 低 | 低〜中 | 中 | 高Write、低Read-after-Write |

---

## 6. モデリングと保存

### Aggregate指向モデリング

**定義**: Domain-Driven Design（Eric Evans）のAggregateパターン。関連データを複雑なデータ構造としてまとめて操作。

**例**:
```json
{
  "product_id": "P12345",
  "name": "Wireless Headphones",
  "price": 99.99,
  "inventory_hints": {
    "region_us": 150,
    "region_eu": 80
  },
  "media": [
    {"type": "image", "url": "https://..."},
    {"type": "video", "url": "https://..."}
  ],
  "reviews_summary": {
    "average_rating": 4.5,
    "total_reviews": 342
  }
}
```

**メリット**:
- 1回のキャッシュルックアップで完全情報取得
- マイクロサービス間の複数ラウンドトリップ回避
- 非正規化によるJOIN不要

**トレードオフ**:
- データ重複
- 部分更新困難
- バージョニング必要

### Key Design

**重要性**: キー設計はキャッシュ効率、トレーサビリティ、無効化ロジックに直接影響。

**ベストプラクティス**:

| パターン | 例 | 用途 |
|---------|---|------|
| **Composite Keys** | `user:123:cart` | エンティティとサブリソース分離 |
| **Shard-aware Prefixes** | `region:eu-east:product:P12345` | 地理的分散、シャーディング |
| **Versioned Keys** | `product:P12345:v2` | スキーマ進化 |
| **Namespace Separation** | `prod:user:123` vs `dev:user:123` | 環境分離 |

**一貫性**: プロジェクト全体で予測可能なキー命名規則を維持。

---

### Durable Memory（永続化キャッシュ）

**定義**: キャッシュエントリが再起動、再デプロイ、一部ノード障害を生き延びる戦略。

**技術例**:
- Redis with AOF (Append-Only File)
- AWS MemoryDB
- RocksDB-backed caches
- Apache Ignite
- Memcached with extstore

**適用場面**:
- 低接続性環境のエッジキャッシュ（地方リージョン）
- 基本的な商品ルックアップ、価格ルール、カートデータをネットワーク断続中も利用可能に
- Write-Throughでキャッシュが非同期DBフラッシュ前のバッファとなる場合

**トレードオフ**:
- 起動時間増加
- スナップショットサイズ管理
- チェックポイント間隔調整
- ディスクI/O競合
- リカバリセマンティクス定義（スナップショット破損時の動作）

---

### Calculated Results（計算結果のキャッシュ）

**概念**: 事前計算または派生値の保存。計算コストが高く、頻繁に繰返される場合に有効。

**例**:

#### パーソナライズドレコメンデーション
- MLモデルで夜間またはニアリアルタイムパイプライン実行
- エフェメラルな計算成果物
- キャッシュでCPU/GPU使用量削減、UX向上

#### 集計アナリティクス
- 地域別注文ダッシュボード
- 売上KPI
- 販売者パフォーマンスメトリクス
- Data Warehouseでロールアップ、APIエッジでキャッシュ

**キー課題: 無効化**:
- ソースデータ変更時、派生キャッシュエントリを更新・期限切れにする必要
- **イベント駆動無効化**: システム変更がキャッシュ削除/更新トリガー
- **短いTTL**: 自然な減衰と鮮度保証（更新サイクル間のstaleness許容）

---

## 7. キャッシュ戦略選択フローチャート

```
データ特性分析
  ↓
Read-heavy & Slowly Changing?
  Yes → Cache-Aside or Read-Through
  No  → ↓
High Write Frequency?
  Yes → Write-Around（Read-after-Write低頻度）
       → Write-Through（Read-after-Write高頻度）
  No  → ↓
Strong Consistency Required?
  Yes → Write-Through
  No  → Cache-Aside

配置選択
  ↓
Shared across instances?
  Yes → Shared Cache (Redis, Memcached)
  No  → Private Cache (In-Process)

モデリング
  ↓
Aggregate-oriented JSON
Key Design: Composite, Shard-aware, Versioned
Durable Memory: 必要に応じて永続化
Calculated Results: 派生値キャッシュ
```

---

## Related Skills

- **architecting-microservices**: サービス間キャッシュ戦略、分散キャッシュ
- **understanding-database-internals**: クエリプランナー、インデックス最適化（キャッシュ前の最適化）
- **implementing-opentelemetry**: キャッシュHit/Miss率監視、レイテンシトレーシング
- **designing-monitoring**: キャッシュパフォーマンスメトリクス、SLO設計
