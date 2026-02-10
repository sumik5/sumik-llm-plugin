# データ所有権と分散データアクセス

マイクロサービスアーキテクチャにおける**データ所有権（Data Ownership）**と**データアクセスパターン**の設計指針を体系化します。

---

## 📋 目次

- [再利用パターン](#再利用パターン)
- [データ所有権モデル](#データ所有権モデル)
- [分散データアクセスパターン](#分散データアクセスパターン)
- [トレードオフ分析](#トレードオフ分析)
- [意思決定フレームワーク](#意思決定フレームワーク)

---

## 再利用パターン

マイクロサービスにおけるコード・データの再利用には4つの主要パターンがあります。

### パターン比較表

| パターン | 結合度 | 変更容易性 | スケーラビリティ | 適用場面 |
|---------|-------|-----------|---------------|---------|
| **コード複製** | 最低 | 高 | 最高 | 静的ロジック、頻繁変更不要 |
| **共有ライブラリ** | 中 | 低 | 高 | ユーティリティ、安定インターフェース |
| **共有サービス** | 低 | 高 | 中 | 動的ロジック、頻繁変更 |
| **サイドカー** | 最低 | 最高 | 高 | 横断的関心事（ログ、監視、認証） |

---

### 1. Code Replication（コード複製）

**原則**: Don't Repeat Yourself (DRY) の反対 → Accept Some Duplication (ASD)

**適用場面**:
- 静的ユーティリティ（日付フォーマット、文字列処理）
- 頻繁に変更されないビジネスルール
- サービス間の独立性が最優先

**メリット**:
- ゼロネットワークレイテンシ
- デプロイ独立性100%
- 障害分離

**デメリット**:
- コード保守コスト（複数箇所の同期）
- バグ修正の伝播遅延

**判断基準**:

```
コード複製許容度 = (変更頻度の逆数) × 独立性重要度

変更頻度: 年1回以下 = 10, 月1回 = 5, 週1回 = 1
独立性重要度: 1〜10

スコア > 50 → 複製推奨
スコア < 20 → 共有ライブラリ/サービス検討
```

---

### 2. Shared Library（共有ライブラリ）

**実装形式**: NPM package, Maven artifact, Go module, Python package

**適用場面**:
- 安定したユーティリティ関数
- 共通データモデル（DTO）
- 標準化されたエラーハンドリング

**メリット**:
- コード重複排除
- 一箇所での修正が全体に適用
- 型安全性（静的言語の場合）

**デメリット**:
- **バージョン地獄**: サービスAはv1.0、サービスBはv2.0を使用 → 互換性問題
- **デプロイ連鎖**: ライブラリ更新 → 全依存サービスの再デプロイ必要
- **密結合**: ライブラリの破壊的変更がサービスに波及

**ベストプラクティス**:

| プラクティス | 理由 |
|------------|------|
| **Semantic Versioning厳守** | 破壊的変更を明示（MAJOR version up） |
| **後方互換性維持** | 既存サービスを壊さない |
| **小さく保つ** | 単一責任原則、依存ライブラリ最小化 |
| **インターフェース安定化** | public APIの頻繁な変更を避ける |

**バージョン管理戦略**:

```
v1.x → v2.0（破壊的変更）の移行

Stage 1: v2.0リリース、v1.x並行保守
Stage 2: 全サービスにv2.0移行期間（3〜6ヶ月）
Stage 3: v1.x非推奨警告
Stage 4: v1.x廃止
```

---

### 3. Shared Service（共有サービス）

**定義**: 複数サービスから利用される独立したマイクロサービス

**適用場面**:
- 動的ビジネスロジック（価格計算、在庫確認）
- 状態を持つ共通機能（キャッシュ、セッション管理）
- 外部システム統合（決済ゲートウェイ、メール送信）

**メリット**:
- デプロイ独立性（共有ライブラリより優位）
- 動的な変更が即座に全体に反映
- スケーラビリティ（独立してスケール可能）

**デメリット**:
- **ネットワークレイテンシ**
- **SPOF（Single Point of Failure）**: 共有サービスダウン → 全体影響
- **運用コスト**: 監視・デプロイ・障害対応

**SPOF対策**:

| 対策 | 実装 |
|-----|------|
| **Circuit Breaker** | Hystrix, Resilience4j |
| **Fallback** | デフォルト値返却、キャッシュ利用 |
| **冗長化** | 複数インスタンス + ロードバランサ |
| **非同期化** | イベント駆動で可用性向上 |

**共有サービス設計原則**:

```
1. Stateless化: セッション状態は外部（Redis等）に保存
2. 冪等性: 同一リクエストを複数回実行しても結果が同じ
3. タイムアウト設定: 呼び出し側でタイムアウト必須
4. レート制限: 過負荷防止
```

---

### 4. Sidecar and Service Mesh（サイドカーとサービスメッシュ）

**定義**: アプリケーションと同じPod/VMで動作する補助プロセス

**適用場面**:
- ログ集約（Fluentd, Filebeat）
- メトリクス収集（Prometheus exporter）
- セキュリティ（mTLS、認証プロキシ）
- トラフィック管理（Envoy, Linkerd）

**サービスメッシュアーキテクチャ**:

```
┌─────────────────────┐
│  Application Pod    │
│  ┌───────┐ ┌──────┐│
│  │ App   │ │Sidecar││ ← Envoy Proxy
│  └───────┘ └──────┘│
└─────────────────────┘
         ↓
    Control Plane
   （Istio, Linkerd）
```

**サービスメッシュのメリット**:

| 機能 | アプリケーション実装なし |
|-----|----------------------|
| **mTLS** | 自動証明書管理・暗号化 |
| **Retry/Timeout** | 宣言的設定 |
| **Circuit Breaking** | コード変更不要 |
| **可観測性** | 分散トレーシング自動 |

**トレードオフ**:

| メリット | デメリット |
|---------|---------|
| アプリケーション軽量化 | インフラ複雑性増加 |
| 言語非依存 | レイテンシ増加（プロキシオーバーヘッド） |
| 統一されたポリシー | 学習曲線 |

**採用判断**:

```
サービスメッシュ採用スコア =
    (サービス数 / 10) +
    (セキュリティ要求 × 3) +
    (可観測性要求 × 2)

スコア > 10: 採用推奨
スコア < 5: オーバーエンジニアリング
```

---

## データ所有権モデル

### 基本原則

**Single Service Database Ownership**: 各サービスが自身のデータベースを所有・管理

```
❌ 共有データベース（アンチパターン）
Service A ──┐
            ├──→ Shared DB
Service B ──┘

✅ データベースパーサービス
Service A ──→ DB A
Service B ──→ DB B
```

---

### データ所有権の4パターン

#### 1. Single Ownership（単一所有権）

**定義**: 1つのテーブルを1つのサービスのみが所有

**例**: `orders` テーブル → Order Service のみがCRUD可能

**適用場面**: 理想的なパターン、可能な限りこれを目指す

**実装**:

```sql
-- Order Service のみがアクセス
CREATE TABLE orders (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL,
    total_amount DECIMAL(10,2),
    status VARCHAR(20)
);

-- 他サービスはREST APIで取得
GET /orders/{id}
```

**メリット**:
- 明確な責任境界
- データ整合性保証が容易
- スキーマ変更の影響範囲が限定的

---

#### 2. Common Ownership（共通所有権）

**定義**: 複数サービスが同一テーブルを読み書き

**問題**: 結合度が高い、スキーマ変更が困難、データ競合リスク

**適用場面**: **避けるべき**、レガシーシステムからの移行過渡期のみ

**リスク**:

| リスク | 例 |
|-------|---|
| **スキーマ変更の影響拡大** | カラム追加 → 全サービス修正必要 |
| **データ競合** | サービスA,Bが同一行を同時更新 |
| **責任の曖昧さ** | データ不整合時の原因特定困難 |

**移行戦略**:

```
Phase 1: 所有サービスを明確化（例: Order Service）
Phase 2: 他サービスは読取専用に制限
Phase 3: 他サービスをAPI経由アクセスに変更
Phase 4: 共通所有を単一所有に移行
```

---

#### 3. Joint Ownership（共同所有権）

**定義**: テーブルの異なる部分を異なるサービスが所有

**実装パターン**:

| パターン | 実装 | 例 |
|---------|-----|---|
| **カラム分離** | サービスごとに専用カラム群 | `users`: Identity Service（name, email）+ Profile Service（bio, avatar） |
| **行分離** | サービスごとに専用行（partitioning key） | `events`: Service Aはtype='A'、Service Bはtype='B'のみ |

**カラム分離の例**:

```sql
-- Identity Service管理カラム
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) NOT NULL,  -- Identity管理
    password_hash VARCHAR(255),   -- Identity管理

    -- Profile Service管理カラム
    display_name VARCHAR(100),    -- Profile管理
    avatar_url VARCHAR(500),      -- Profile管理
    bio TEXT                      -- Profile管理
);

-- アクセス制約
-- Identity Service: email, password_hashのみ更新可
-- Profile Service: display_name, avatar_url, bioのみ更新可
```

**課題**:
- スキーマ変更の調整コスト
- アクセス制御の複雑性
- データ整合性の責任分界点が不明確

**推奨**: 可能なら単一所有権に分離（別テーブル化）

---

#### 4. Service Consolidation（サービス統合）

**定義**: データ所有権の複雑さを理由にサービスを統合

**適用判断**:

```
統合スコア =
    (共有テーブル数 × 5) +
    (トランザクション境界重複度 × 10) +
    (スキーマ変更調整コスト × 3)

スコア > 50: 統合を強く推奨
スコア < 20: 分離維持
```

**例**: User Service + Profile Service → Account Service

**統合前の問題**:
- ユーザー登録: User Service（基本情報）+ Profile Service（詳細情報） → 2フェーズコミット
- データ整合性: email変更時にProfileも更新必要 → 複雑な調整

**統合後**:
- 単一サービス内でローカルトランザクション
- スキーマ変更が内部実装の問題に

---

## 分散データアクセスパターン

サービス間でデータを共有する4つのパターン:

### パターン比較表

| パターン | 一貫性 | レイテンシ | 複雑性 | 適用場面 |
|---------|-------|-----------|-------|---------|
| **Inter-Service Communication** | 強 | 高 | 低 | リアルタイム、低頻度アクセス |
| **Column Schema Replication** | 弱 | 低 | 中 | 参照データ、静的マスタ |
| **Replicated Caching** | 最弱 | 最低 | 中 | 読取頻度高、更新頻度低 |
| **Data Domain** | 中 | 中 | 高 | 複雑JOIN、分析クエリ |

---

### 1. Inter-Service Communication（サービス間通信）

**定義**: REST API/gRPC経由でリアルタイムにデータ取得

**実装例**:

```
Order Service: 注文作成時に顧客情報が必要
  ↓
GET https://customer-service/api/customers/{id}
  ↓
Customer Service: 顧客データ返却
```

**メリット**:
- 常に最新データ
- 実装がシンプル

**デメリット**:
- **ネットワークレイテンシ**: 1リクエストあたり5〜50ms
- **可用性依存**: Customer Service停止 → Order作成不可
- **カスケード障害**: 呼び出しチェーンで障害伝播

**最適化テクニック**:

| テクニック | 実装 |
|----------|------|
| **バッチ取得** | GET /customers?ids=1,2,3（複数IDを一度に取得） |
| **GraphQL** | 必要フィールドのみ取得 |
| **Circuit Breaker** | 障害時はFallback値返却 |
| **非同期化** | イベント駆動で即時応答不要に |

**適用判断**:

```
アクセス頻度: 秒間10回未満
データ鮮度要求: 1秒以内
可用性要求: 99%（3 nines）

→ Inter-Service Communication適用
```

---

### 2. Column Schema Replication（カラムスキーマ複製）

**定義**: 他サービスの必要なカラムだけを自サービスのDBに複製

**実装例**:

```sql
-- Customer Service（正）
CREATE TABLE customers (
    id UUID PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(255),
    address TEXT,
    created_at TIMESTAMP
);

-- Order Service（複製）
CREATE TABLE customer_replicas (
    customer_id UUID PRIMARY KEY,
    name VARCHAR(100),          -- 複製カラム
    email VARCHAR(255),         -- 複製カラム
    last_synced_at TIMESTAMP
);
```

**同期方法**:

| 方法 | 一貫性 | 実装複雑性 |
|-----|-------|-----------|
| **CDC（Change Data Capture）** | 高（秒単位） | 高（Debezium, Maxwell等） |
| **イベント駆動** | 中（数秒） | 中（Kafka, RabbitMQ） |
| **定期バッチ同期** | 低（分〜時間） | 低（Cron + API呼び出し） |

**メリット**:
- ゼロレイテンシ（ローカルDB読取）
- 可用性向上（Customer Service停止でもOrder作成可）

**デメリット**:
- **結果整合性**: データが古い可能性
- **ストレージコスト**: データ重複
- **同期ロジック**: 複雑性増加

**適用場面**:

```
データ種別: 参照データ（顧客名、商品名）
更新頻度: 低（日次〜週次）
読取頻度: 高（秒間100回以上）

→ Column Schema Replication適用
```

---

### 3. Replicated Caching（複製キャッシュ）

**定義**: 頻繁アクセスデータをRedis等の分散キャッシュに複製

**アーキテクチャ**:

```
Customer Service
  ↓ 書込時
Redis Cluster（複製キャッシュ）
  ↑ 読取
Order Service, Invoice Service, etc.
```

**実装パターン**:

| パターン | 説明 | 一貫性 |
|---------|-----|-------|
| **Write-Through** | 書込時にDBとキャッシュ同時更新 | 強 |
| **Write-Behind** | 先にキャッシュ更新、後でDB同期 | 弱 |
| **Cache-Aside** | 読取時にキャッシュミスならDB取得 | 中 |

**TTL（Time To Live）戦略**:

```
データ鮮度要求 → TTL設定

リアルタイム（1秒以内）: TTL = 1秒
準リアルタイム（数秒）: TTL = 10秒
バッチ更新（分単位）: TTL = 5分
静的マスタ（滅多に変わらない）: TTL = 1時間
```

**メリット**:
- 超低レイテンシ（1ms未満）
- 高スループット
- データソースの負荷軽減

**デメリット**:
- **キャッシュ無効化**: 更新時の同期が複雑
- **メモリコスト**: 大量データは高コスト
- **Thundering Herd**: キャッシュ期限切れ時の同時アクセス

**キャッシュ無効化戦略**:

```
1. TTLベース: 一定時間で自動失効
2. イベントベース: 更新イベント受信で即時削除
3. バージョニング: キャッシュキーにバージョン含める
```

---

### 4. Data Domain（データドメイン）

**定義**: 分析・レポート用に複数サービスのデータを集約した読取専用DB

**アーキテクチャ**:

```
Customer Service ──┐
Order Service ─────┤ ETL/CDC
Payment Service ───┤──→ Data Warehouse / Data Lake
Inventory Service ─┘      （読取専用）
                            ↓
                    Analytics Service, BI Tools
```

**実装アプローチ**:

| アプローチ | ツール | 更新頻度 |
|----------|-------|---------|
| **ETL（Extract-Transform-Load）** | Apache Airflow, Talend | バッチ（時間〜日） |
| **CDC（Change Data Capture）** | Debezium, Maxwell | ストリーミング（秒〜分） |
| **Event Sourcing** | Kafka + KSQL | リアルタイム |

**メリット**:
- 複雑JOIN・集計クエリが可能
- トランザクションDBに負荷をかけない
- 履歴データ保持・分析

**デメリット**:
- **データ鮮度**: リアルタイム性なし
- **インフラコスト**: DWH・ETLパイプライン
- **スキーマ管理**: 複数ソースの統合が複雑

**適用場面**:

```
用途: レポート、ダッシュボード、機械学習
データ鮮度要求: 1時間〜1日遅延許容
クエリ複雑度: 多テーブルJOIN、時系列集計

→ Data Domain適用
```

---

## トレードオフ分析

### データアクセスパターンの選択マトリクス

| 要件 | Inter-Service | Column Replication | Replicated Cache | Data Domain |
|-----|--------------|-------------------|------------------|-------------|
| **データ鮮度: リアルタイム** | ✅ | ❌ | ⚠️ | ❌ |
| **低レイテンシ（<10ms）** | ❌ | ✅ | ✅ | ❌ |
| **高可用性（99.9%+）** | ❌ | ✅ | ✅ | ✅ |
| **複雑JOIN** | ❌ | ❌ | ❌ | ✅ |
| **実装シンプル** | ✅ | ⚠️ | ⚠️ | ❌ |
| **ストレージコスト低** | ✅ | ⚠️ | ⚠️ | ❌ |

### 所有権モデルの選択フローチャート

```
データは単一サービスの責任範囲？
  ├─ Yes → Single Ownership（推奨）
  └─ No
      ├─ 複数サービスが書き込む？
      │   ├─ Yes → Common Ownership（避ける）→ 所有サービス明確化
      │   └─ No → 読取のみ共有？
      │       ├─ Yes → アクセスパターン選択
      │       │   ├─ リアルタイム必須 → Inter-Service Communication
      │       │   ├─ 高頻度読取 → Column Replication or Cache
      │       │   └─ 分析・レポート → Data Domain
      │       └─ No → Joint Ownership → できれば分離
      │
      └─ 分離困難？ → Service Consolidation検討
```

---

## 意思決定フレームワーク

### ステップ1: データアクセス要件の定量化

```python
class DataAccessRequirement:
    read_qps: int           # 読取クエリ/秒
    write_qps: int          # 書込クエリ/秒
    latency_p99: int        # 99パーセンタイルレイテンシ（ms）
    freshness_required: int # データ鮮度要求（秒）
    availability_target: float  # 可用性目標（%）

    def recommend_pattern(self):
        if self.freshness_required <= 1:
            return "Inter-Service Communication"
        elif self.read_qps > 100 and self.freshness_required <= 60:
            return "Replicated Caching"
        elif self.read_qps > 50 and self.freshness_required <= 300:
            return "Column Schema Replication"
        else:
            return "Data Domain"
```

### ステップ2: 所有権モデルの評価

```python
ownership_complexity = (
    (共有書込サービス数 × 10) +
    (スキーマ変更頻度（年間回数）× 5) +
    (データ競合リスク × 8)
)

if ownership_complexity > 50:
    # Service Consolidation検討
elif ownership_complexity > 20:
    # Joint Ownership → Single Ownership移行計画
else:
    # Single Ownership維持
```

### ステップ3: 実装コストの見積もり

| パターン | 初期実装 | 運用コスト | インフラコスト |
|---------|---------|-----------|--------------|
| Inter-Service | 低 | 低 | 低 |
| Column Replication | 中 | 中 | 中（CDC or イベント） |
| Replicated Cache | 中 | 中 | 中（Redis cluster） |
| Data Domain | 高 | 高 | 高（DWH + ETL） |

---

## 実装ガイドライン

### 1. Single Ownershipの実現

```
原則: データベースパーサービス

実装:
1. 各サービスに専用DBスキーマ/データベース割り当て
2. IAMロール/DB権限で物理的に分離
3. APIを通じた間接アクセスのみ許可
```

### 2. 結果整合性の許容

```
ACID → BASE への移行

BASE特性:
- Basically Available: 部分的な障害でも動作
- Soft state: 状態は時間とともに変化
- Eventually consistent: 最終的には一貫

実装: Sagaパターン（詳細は DISTRIBUTED-TRANSACTIONS.md）
```

### 3. データ同期の監視

```
監視メトリクス:
- レプリケーション遅延（Replication Lag）
- 同期エラー率
- データ不整合検出（定期的な突合）

アラート閾値:
- 遅延 > 1分: Warning
- 遅延 > 10分: Critical
- 不整合検出: Immediate escalation
```

---

## 関連ファイル

- **[GRANULARITY-DECISIONS.md](GRANULARITY-DECISIONS.md)**: サービス粒度決定（統合ドライバー含む）
- **[DISTRIBUTED-TRANSACTIONS.md](DISTRIBUTED-TRANSACTIONS.md)**: 分散トランザクション戦略
- **[WORKFLOW-CONTRACTS.md](WORKFLOW-CONTRACTS.md)**: サービス間ワークフロー
- **[MESSAGING-PATTERNS.md](MESSAGING-PATTERNS.md)**: イベント駆動メッセージング
- **[CQRS-EVENT-SOURCING.md](CQRS-EVENT-SOURCING.md)**: CQRS実装パターン

---

**次のステップ**: データ所有権を決定したら、[DISTRIBUTED-TRANSACTIONS.md](DISTRIBUTED-TRANSACTIONS.md)でトランザクション戦略を、[WORKFLOW-CONTRACTS.md](WORKFLOW-CONTRACTS.md)でサービス間連携を確認してください。
