# 高可用性・スケーラビリティ設計パターン

## 概要

マイクロサービスアーキテクチャにおける高可用性（High Availability）とスケーラビリティは、システムの成長と信頼性を支える基盤技術です。このドキュメントでは、段階的なスケーリング戦略、楽観的ロック、CQRSベースの高可用性パターンを解説します。

---

## スケーリングテンプレートの進化

マイクロサービスのスケーリングは、システムの成長段階に応じて段階的に進化します。以下は、各段階の特徴と適用条件を示すテーブルです。

### スケーリングテンプレート比較

| テンプレート | 特徴 | 適用条件 | 制約・課題 |
|------------|------|----------|-----------|
| **Inception** | 単一アプリケーションインスタンス + 単一DBインスタンス | 個人利用・スタートアップ初期 | スケーラビリティがハードウェア容量に完全依存 |
| **Scale-Out** | 複数アプリケーションインスタンス（Auto-Scaling Group） + ELB + 単一DBインスタンス | ユーザー数増加、トラフィック増加 | DBが単一障害点（SPOF）として残る |
| **Database HA** | 複数アプリケーションインスタンス + Database Cluster（RAC等） | DBがボトルネックになる場合 | クラスタ構成の複雑性、コスト増加 |
| **Read/Write分離** | 複数アプリケーションインスタンス + Primary/Standby DB構成 | Read >> Write の比率が高い場合（Look-to-Book比率が高い） | 読み書きの独立スケーリングが可能になる |
| **Sharding** | 複数アプリケーションインスタンス + データ・サービス分割 | グローバル規模、Web Scale要件 | 設計複雑性、クロスシャードクエリの制約 |

---

## 読み書き独立スケーリング（Read/Write Separation）

多くのビジネスアプリケーションでは、**Read（読み取り）トランザクション >> Write（書き込み）トランザクション**の比率が圧倒的に高い（Look-to-Book比率）。この特性を活用して、読み書きを独立してスケールさせます。

### Primary/Standby構成

```
[Application Tier - Multiple Instances]
          |
          +--- Write Requests --> [Primary DB Instance]
          |                            |
          |                            v (Replication)
          +--- Read Requests -----> [Standby DB Instance(s)]
```

**特徴：**
- **Primary**: すべての書き込み操作を処理
- **Standby**: 読み取り専用（Read Replica）として機能
- **Active Data Guard Replication**: 同期・非同期レプリケーションの選択可能
- **Failover**: Primary障害時、Standbyが自動昇格

**メリット：**
- Readスケーラビリティが向上
- Primaryの負荷軽減
- データの高可用性（複数コピー保持）

---

## 楽観的ロックと競合解決パターン

### 楽観的ロックの原則

楽観的ロック（Optimistic Locking）は、複数のトランザクションが互いに干渉しないと仮定し、**ロックを取得せずに並行処理を許可**するアプローチです。

**動作原理：**
1. エンティティに**バージョン番号**または**タイムスタンプ**を保持
2. トランザクション開始時にバージョンを読み取り
3. コミット前に、他のトランザクションがデータを変更していないかを検証
4. 競合検出時は、後続トランザクションをロールバック

### バージョンベースの楽観的ロック

**エンティティ設計例（擬似コード）：**

```
Entity: User
- id: Long (Primary Key)
- userName: String
- age: Integer
- version: Long  ← バージョン番号（楽観的ロック用）

Constructor(id, userName, age):
    this.id = id
    this.userName = userName
    this.age = age
    this.version = 0  // 初期バージョン

Update(newUserName, newAge):
    this.userName = newUserName
    this.age = newAge
    // バージョンは自動インクリメント（Repository層が実施）
```

**楽観的ロックの実行フロー：**

```
[Transaction 1]
1. User entity をロード (id=1, version=0)
2. userName を "User01" → "User02" に変更
3. 60秒スリープ（シミュレーション）
4. コミット試行
   → UPDATE user SET userName='User02', version=1 WHERE id=1 AND version=0
   → 成功（versionが一致）

[Transaction 2]（並行実行）
1. User entity をロード (id=1, version=0)
2. userName を "User01" → "User03" に変更
3. 60秒スリープ（シミュレーション）
4. コミット試行
   → UPDATE user SET userName='User03', version=1 WHERE id=1 AND version=0
   → 失敗（Transaction 1がversionを1に更新済み）
   → OptimisticLockException 発生
```

### 競合検出と解決戦略

**競合検出：**
- エンティティの期待バージョンと実際のバージョンを比較
- 不一致の場合、競合と判定

**解決戦略：**

| 戦略 | 説明 | 適用シーン |
|-----|------|-----------|
| **Last Write Wins** | 最後のコミットが優先される（自動リトライ） | 競合が稀、データの重要度が低い場合 |
| **First Write Wins** | 最初のコミットが優先、後続はリジェクト | 在庫管理、予約システム（本ドキュメントの例） |
| **Merge** | 変更内容を自動/手動でマージ | 非競合フィールドの更新、複雑なビジネスロジック |
| **User Intervention** | ユーザーに競合を提示し、手動解決を要求 | 重要な意思決定、クリティカルなデータ |

---

## CQRS高可用性パターン

CQRSアーキテクチャでは、Command（書き込み）とQuery（読み取り）を独立してスケールアウトできます。

### CQRS スケールアウトアーキテクチャ

```
[Load Balancer]
      |
      +---> [Command Handler Instance 1] ---+
      +---> [Command Handler Instance 2] ---+
      +---> [Command Handler Instance 3] ---+---> [Event Store (Primary)]
                                                        |
                                                        v (Event Publishing)
                                                   [Event Bus]
                                                        |
      +----------------------------------------------+------+
      |                                              |      |
[Event Handler 1]  [Event Handler 2]  [Event Handler 3]  [Event Handler N]
      |                    |                |               |
      v                    v                v               v
[Materialized View 1] [Materialized View 2] [Materialized View 3] [Materialized View N]
```

### 複数Command Handler インスタンスの管理

**課題：**
- 複数のCommand Handlerインスタンスが同じAggregateを同時に変更する可能性
- 例：最後の1席を2人のユーザーが同時に予約しようとする

**解決策：楽観的ロック + 分散Command Bus**

1. **分散Command Bus**:
   - Routing Key（例：Aggregate ID）を使用してCommandをルーティング
   - 同じAggregate IDのCommandは常に同じインスタンスにルーティング（Sticky Session）
   - これにより、同じエンティティへの並行アクセスを最小化

2. **楽観的ロック**:
   - Aggregate Rootに`version`フィールドを保持
   - 変更時にバージョン検証を実施
   - 競合検出時は`OptimisticLockException`をスロー

**Command Handler 実装例（擬似コード）：**

```
Component: OrderCommandHandler
    Repository: orderRepository
    Repository: productRepository

    CommandHandler: NewOrderCommand
        // Productをロードして在庫を減らす
        productRepository.load(command.productId)
            .execute(product -> product.decrementStock(command.quantity))

        // 新しいOrderを作成
        orderRepository.newInstance(() ->
            new Order(UUID, command.price, command.quantity, OrderStatus.NEW, command.productId)
        )
```

### Event Handlerの並列処理

**Event Handlerのスケールアウトは比較的容易：**
- すべてのEvent Handlerインスタンスに同じEventを配信
- 各インスタンスがMaterialized Viewやキャッシュを独立して更新
- 競合は発生しない（Eventは不変、追記のみ）

---

## Auto-Scaling設計パターン

### Auto-Scaling Group構成

```
[Region: us-east-1]
   |
   +--- [Availability Zone A]
   |       |
   |       +--- [Auto-Scaling Group: Microservice-X]
   |               |
   |               +--- [Instance 1]
   |               +--- [Instance 2]
   |               +--- [Instance N]
   |
   +--- [Availability Zone B]
   |       |
   |       +--- [Auto-Scaling Group: Microservice-X]
   |               |
   |               +--- [Instance 1]
   |               +--- [Instance 2]
   |
   +--- [Availability Zone C]
           |
           +--- [Auto-Scaling Group: Microservice-X]
                   |
                   +--- [Instance 1]
                   +--- [Instance 2]
```

**Auto-Scaling Groupの設定：**
- **Minimum Size**: 常に稼働する最小インスタンス数
- **Desired Capacity**: 通常時の目標インスタンス数
- **Maximum Size**: スケールアウトの上限
- **Scaling Policy**: CPU使用率、リクエスト数、カスタムメトリクスに基づく動的スケーリング

### リージョン・アベイラビリティゾーン分散

**Availability Zone（AZ）分散の目的：**
- **高可用性**: 単一AZ障害時の継続稼働
- **低レイテンシ**: ユーザーに近いAZへのルーティング
- **ディザスタリカバリ**: 地理的に分散したデータセンター

**AWS Route 53を活用したトラフィックルーティング：**
- **Latency-based Routing**: 最低レイテンシのリージョンへルーティング
- **Geo DNS**: ユーザーの地理的位置に基づくルーティング
- **Weighted Round Robin**: 重み付けによる負荷分散

---

## シャーディング戦略（Sharding）

### シャーディングの概念

シャーディングは、データとサービスを複数のノード（シャード）に**水平分割**する手法です。

**シャーディングの適用レイヤー：**
1. **データレイヤー**: データベースをシャードに分割
2. **サービスレイヤー**: マイクロサービスインスタンスをシャードに分割

### データシャーディング戦略

**シャーディングキーの選択例：**

| シャーディングキー | 例 | 適用シーン |
|------------------|---|-----------|
| **ユーザーID** | User ID % N | ユーザーごとにデータが独立 |
| **名前の頭文字** | A-H, I-Q, R-Z | ソーシャルネットワーク、連絡先管理 |
| **地理的リージョン** | NA, EU, APAC | グローバルサービス、GDPR対応 |
| **テナントID** | Tenant ID % N | マルチテナントSaaS |
| **時間ベース** | 年月（YYYYMM） | ログ、時系列データ |

**シャーディングアーキテクチャ例：**

```
[Load Balancer / API Gateway]
        |
        v (Routing by Sharding Key)
        |
        +--- [Shard 1: Users A-H]
        |       |
        |       +--- [Microservice Instances]
        |       +--- [Database: users_a_h]
        |
        +--- [Shard 2: Users I-Q]
        |       |
        |       +--- [Microservice Instances]
        |       +--- [Database: users_i_q]
        |
        +--- [Shard 3: Users R-Z]
                |
                +--- [Microservice Instances]
                +--- [Database: users_r_z]
```

**シャーディングのメリット：**
- データ量とトランザクション量を分散
- 各シャードが独立してスケール可能
- 障害の影響範囲を局所化

**シャーディングの課題：**
- クロスシャードクエリの複雑性
- シャード再分割の困難性
- 分散トランザクションの必要性

---

## ロードバランサー設計

### Elastic Load Balancer（ELB）の種類

| タイプ | レイヤー | 用途 | 特徴 |
|-------|---------|------|------|
| **Application Load Balancer (ALB)** | OSI Layer 7 (HTTP/HTTPS) | HTTP/HTTPSトラフィック | リクエストレベルのルーティング、パスベース・ホストベースルーティング |
| **Network Load Balancer (NLB)** | OSI Layer 4 (TCP/UDP) | 超高性能が必要な場合 | コネクションレベルの負荷分散、超低レイテンシ |
| **Classic Load Balancer (CLB)** | Layer 4 & 7 | EC2-Classicネットワーク（レガシー） | 基本的な負荷分散、リクエスト・コネクションレベル両対応 |

### ロードバランシング戦略

**ALBのルーティング機能：**
- **パスベースルーティング**: `/api/v1/*` → Microservice A、`/api/v2/*` → Microservice B
- **ホストベースルーティング**: `api.example.com` → API Gateway、`web.example.com` → Web Server
- **ヘッダーベースルーティング**: カスタムヘッダーに基づくルーティング
- **クエリパラメータルーティング**: URLクエリパラメータに基づくルーティング

---

## 判断基準テーブル

### スケーリングテンプレート選択

| 条件 | 推奨テンプレート |
|-----|----------------|
| ユーザー数 < 1000、単一リージョン | Inception |
| ユーザー数 1000-10000、トラフィック増加 | Scale-Out |
| DBがボトルネック、ACID要件が強い | Database HA（RAC等） |
| Read >> Write の比率（Look-to-Book > 10:1） | Read/Write分離 |
| グローバル規模、数百万ユーザー | Sharding + Multi-Region |

### 楽観的ロック vs 悲観的ロック

| 条件 | 推奨アプローチ |
|-----|--------------|
| 競合が稀（< 1%） | 楽観的ロック |
| 競合が頻繁（> 10%） | 悲観的ロック |
| 長時間トランザクション（> 1秒） | 楽観的ロック |
| 短時間トランザクション（< 100ms） | 悲観的ロック |
| Read-Often, Write-Sometimes | 楽観的ロック |
| 在庫管理、予約システム | 楽観的ロック + First Write Wins |

---

## まとめ

高可用性・スケーラビリティ設計は、以下の原則に基づきます：

1. **段階的スケーリング**: システムの成長に応じて、Inception → Scale-Out → Database HA → Sharding へ進化
2. **読み書き分離**: Look-to-Book比率に基づき、Read/Writeを独立スケール
3. **楽観的ロック**: 並行性を最大化し、競合は事後検出・解決
4. **CQRS活用**: Command/Queryの独立スケーリングと高可用性
5. **Auto-Scaling**: トラフィック変動に自動対応
6. **シャーディング**: Web Scaleへの最終手段
7. **マルチAZ/リージョン**: 地理的冗長性とディザスタリカバリ
