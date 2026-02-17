# AWSシステム設計ケーススタディ

実践的なシステム設計パターンとAWSサービス選定の事例集。要件定義からアーキテクチャ設計、スケーリング戦略まで体系的に解説します。

---

## Case Study 1: URL Shortener Service

長いURLを短いURLに変換し、リダイレクト機能を提供するサービスの設計。

### 1.1 要件定義

#### 機能要件
- 長いURLから短いURLを生成
- 短いURLから長いURLへのリダイレクト
- カスタムURL作成サポート
- URLアクセスパターンの分析
- URL有効期限設定
- 拡張可能なプラグインアーキテクチャ
- サードパーティAPI公開

#### 非機能要件
- セキュリティ: 悪意のある利用からの保護
- 高可用性: 年間99.99%以上のアップタイム
- オブザーバビリティ: メトリクス・アラート配置
- 低レイテンシー: URL生成・リダイレクトの高速化
- データ永続性: 有効期限までデータ保持
- 耐障害性: リトライハンドリング
- 相互運用性: マイクロサービス間通信の設計

### 1.2 スケール見積もり

#### トラフィック想定
| 指標 | 値 |
|-----|---|
| 短URL生成 | 1,000 RPS |
| リダイレクト | 20,000 RPS |
| URL平均保持期間 | 1年 |

#### ストレージ計算
```
年間URL生成数 = 1,000 RPS × 60 × 60 × 24 × 365 ≈ 31.5億
```

#### 短URL長の決定
| 長さ | 62進数での組み合わせ数 |
|-----|---------------------|
| 6文字 | 62^6 = 56.8億 |
| 7文字 | 62^7 = 3.5兆 |
| 8文字 | 62^8 = 218.3兆 |

**選択**: 7文字（将来のスケールを考慮）

#### ストレージ容量
```
1エントリあたり:
- 短URL (7文字): 7 bytes
- 平均長URL (100文字): 100 bytes
- 有効期限 (long型): 8 bytes
- メタデータ (IP、設定等): 1 KB

合計: 約1 KB/エントリ
年間ストレージ: 31.5億 × 1 KB = 29.37 TB
```

### 1.3 URL短縮アルゴリズム

#### Option 1: ハッシング
```
長URL → MD5ハッシュ → 最初の7文字を抽出
```

**問題点**:
- コリジョン（衝突）の発生
- DB参照による追加レイテンシー

#### Option 2: ユニークID生成（推奨）

**Base62エンコーディング**:
```
0-9, a-z, A-Z の62文字
カウンター値をBase62変換 → 7文字固定長に調整
```

**例**:
```
Base62(1) = 1
Base62(10) = A
Base62(1000001) = 4C93
```

**グローバルカウンター管理**: Key Generation Service (KGS)で集中管理

### 1.4 システムアーキテクチャ

#### コア・コンポーネント

| コンポーネント | 責務 |
|-------------|------|
| **URL Shortener Service** | URL生成・リダイレクト処理 |
| **Key Generation Service (KGS)** | ユニークID事前生成・提供 |
| **Data Management Service** | CRUD API層（DynamoDB・ElastiCache間） |
| **Frontend Service** | クライアントトラフィック受付 |
| **Analytics Pipeline** | ユーザーアクティビティ分析 |

#### Key Generation Service詳細

**Ticket Serverアプローチ**（Flickr参考）:
```sql
CREATE TABLE `Tickets64` (
  `id` bigint(20) unsigned NOT NULL auto_increment,
  `stub` char(1) NOT NULL default '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `stub` (`stub`)
) ENGINE=InnoDB

REPLACE INTO Tickets64 (stub) VALUES ('a');
SELECT LAST_INSERT_ID();
```

**高可用性設定**:
```
TicketServer1:
  auto-increment-increment = 2
  auto-increment-offset = 1  # 奇数ID生成

TicketServer2:
  auto-increment-increment = 2
  auto-increment-offset = 2  # 偶数ID生成
```

**利点**: 単一障害点の回避、スナップショットによる災害復旧

### 1.5 API設計

#### 短URL生成API
```http
POST /v1/createShortUrl
Content-Type: application/json

{
  "longUrl": "https://example.com/very/long/url",
  "customUrl": "custom-alias",  # Optional
  "expiry": "2025-12-31T23:59:59Z",  # Optional
  "userMetadata": {
    "ip": "192.168.1.1",
    "location": "US-East",
    "browser": "Chrome"
  }
}
```

**成功レスポンス**:
```http
HTTP/1.1 200 OK
{
  "shortUrl": "https://short.ly/abc1234"
}
```

**失敗レスポンス**:
```http
HTTP/1.1 500 Internal Server Error
{
  "error": "An error occurred while processing your request"
}
```

#### リダイレクトAPI
```http
GET /v1/getLongUrl
Content-Type: application/json

{
  "shortUrl": "abc1234",
  "userMetadata": {...}
}
```

**成功レスポンス（302リダイレクト）**:
```http
HTTP/1.1 302 Found
Location: https://example.com/very/long/url
```

**失敗レスポンス**:
```http
HTTP/1.1 404 Not Found
{
  "error": "short url doesn't exist"
}
```

### 1.6 データベース選定

#### URL Shortener Service用DB

**選択**: Amazon DynamoDB

| 判断基準 | 評価 |
|---------|------|
| データ型 | 構造化 |
| クエリパターン | - 短URL→長URL<br>- ユーザーID→URL一覧 |
| スケーラビリティ | 水平スケーリング自動 |
| 運用負荷 | マネージド（レプリカ管理不要） |
| 追加機能 | TTL、DynamoDB Streams |

**DynamoDBスキーマ**:
```
Primary Key:
  Partition Key = {shortUrl}
  Sort Key = "SU"  # 定数

GSI (Global Secondary Index):
  Partition Key = {userId}
  Sort Key = "u#{timestamp}"
```

**容量モード選択**:
1. 初期: On-Demand（トラフィックパターン把握）
2. 成熟期: Provisioned with Auto-Scaling（コスト最適化）

**スロットリング対策**:
- Provisioned: キャパシティ事前計画
- On-Demand: アカウント上限（40,000 RCU/WCU）に注意

#### KGS用DB

**選択**: Amazon ElastiCache (Redis)

| 判断基準 | 理由 |
|---------|------|
| データ構造 | Redis Listsで10,000個のID保持 |
| パフォーマンス | インメモリで高速アクセス |
| 永続化 | 不要（再生成可能） |

### 1.7 Day 0 アーキテクチャ

#### Lambda + API Gateway構成

**コンポーネント**:
- Amazon API Gateway: エンドポイント
- AWS Lambda: ビジネスロジック（API毎に分離）
- Amazon DynamoDB: データストレージ
- Amazon ElastiCache: キャッシュ層
- Amazon CloudWatch: 監視
- Amazon Cognito + AWS IAM: 認証・認可
- AWS Certificate Manager: SSL/TLS証明書

**メリット**:
- インフラ管理不要
- 自動スケーリング
- 従量課金

#### App Runner構成

**コンポーネント**:
- AWS App Runner: コンテナデプロイ自動化
- Amazon NLB: L4ロードバランサー
- Amazon ECS Fargate: コンテナ実行
- Amazon ECR: コンテナイメージ保存

**メリット**:
- GitHub/ECRから自動デプロイ
- ECS Fargate + ALB + Auto Scaling統合
- VPC設定不要（AWSマネージド）

**サポート言語**: Python, Node.js, Java, Go, Rails, PHP, .NET

### 1.8 Day N アーキテクチャ（スケーリング）

#### 観測性強化
- AWS X-Ray: 分散トレーシング
- CloudWatch Alarms例:
  - `LONG_URL_REDIRECTION_ERRORS`: エラー率 > 10/min × 5分継続
  - `SHORT_URL_CREATION_FAILURE`: 失敗率閾値超過

#### ストレージ層最適化

**DynamoDB Global Tables**:
- マルチリージョンレプリケーション
- レプリケーションラグ: 約1秒
- **新機能（re:Invent 2024）**: Strong Consistency Reads対応

**キャッシュ層**:
| 選択肢 | 用途 | レイテンシー |
|-------|------|------------|
| Amazon DAX | DynamoDB専用 | マイクロ秒 |
| Amazon ElastiCache | 汎用 | マイクロ秒 |
| DynamoDB直接 | ベースライン | 単一桁ミリ秒 |

**推奨**: DAX（DynamoDB統合）またはElastiCache（既存利用時）

**Redis Cluster Mode**:
- ワークロード分散
- スループット向上

#### コンピュート層最適化

**AWS Lambda**:
- **課題**: Cold Start（p100レイテンシー増加）
- **対策**: Provisioned Concurrency

**AWS App Runner**:
- **制約**:
  - 最大25インスタンス/サービス
  - 200並行リクエスト/インスタンス
  - 合計5,000並行リクエスト/サービス
- **対策**:
  - ECS EC2への移行（大規模時）
  - Auto-Scaling Group（ASG）設定
  - マルチAZ配置

#### ネットワーク最適化

**Amazon CloudFront**:
- エッジロケーションでのキャッシュ
- 静的コンテンツ配信（CSS、JS、画像）
- レイテンシー削減

**VPC設計**:
- マイクロサービス毎に専用VPC
- AWS Transit Gateway: VPC間双方向通信
- AWS PrivateLink: VPC間単方向通信
- VPC Endpoint: AWSサービス接続（インターネット経由せず）

### 1.9 マルチテナント対応

#### セル・ベース・アーキテクチャ

**概念**: テナントをセル（独立ユニット）にグループ化

**DynamoDBスキーマ（単一テーブル）**:
```
Primary Key:
  Partition Key = {shortUrl}
  Sort Key = {tenantId}
```

**利点**:
- 障害隔離（1セルの障害が他セルに影響しない）
- 独立スケーリング
- 柔軟なリソース割り当て

**課題**: セル間のロードバランシング（テナント数とスケールの不均衡）

### 1.10 スケーリングロードマップ

| ユーザー数 | アクション | 理由 |
|----------|----------|------|
| ~10,000 | マルチAZ DB + Read Replica | 可用性・読取性能向上 |
| ~100,000 | Caching (ElastiCache/DAX) | DB負荷軽減、レイテンシー削減 |
| ~1M | Auto-Scaling + CDN | トラフィック急増対応、グローバル配信 |
| 1M+ | Managed Services移行<br>IaC導入<br>Microservices化 | 運用効率化<br>一貫性・自動化<br>独立スケーリング |

---

## Case Study 2: Web Crawler & Search Engine

（概要レベルの記述）

### 2.1 要件定義

#### 機能要件
- ユーザー検索クエリに対するトップ結果返却
- コンテンツ鮮度の識別

#### 非機能要件
- 高可用性・高信頼性・高スケーラビリティ
- 低レイテンシー（ミリ秒単位）
- データ鮮度維持

### 2.2 スケール見積もり

**Web Crawler**:
- アクティブWebサイト: 2億
- 平均ページ数/サイト: 50
- 総ページ数: 100億
- ストレージ: 約5 PB（テキストのみ）

**Search Engine**:
- 検索クエリ: 85億/日（99,000 RPS）（Google規模）

### 2.3 アーキテクチャコンポーネント

#### Web Crawlerコンポーネント
| コンポーネント | 機能 |
|-------------|------|
| URL Server | Seed URLリスト提供 |
| Crawler | ページ取得・DNS Cache |
| Store Server | HTML圧縮・Repository保存 |
| Indexer | コンテンツ解析・Doc ID割当 |
| URL Resolver | 相対URL→絶対URL変換 |
| URL Frontier | 優先度・ポリトネス管理 |

**URL Frontier詳細**:
- **Prioritizer + Front Queues**: 優先度（1～n）で振り分け
- **Back Queue Router**: ドメイン→キュー割当（ポリトネス確保）
- **Back Queues**: ホスト毎にリクエスト制限
- **Priority Queue (Min-Heap)**: 次回接触可能時刻管理

#### Search Engineコンポーネント
| コンポーネント | 機能 |
|-------------|------|
| Document Parser & Encoder | パース・不要データ除去 |
| Forward Index | Doc ID → Words |
| Inverted Index | Words → Doc ID |
| Content Relevance (PageRank) | ランキング計算 |

**インデックス戦略（Elasticsearch/OpenSearch）**:
- Index → Shards → Segments構造
- Refresh Interval: メモリ→ディスク同期頻度
- Segment Merge: 小セグメントを大セグメントに統合

### 2.4 AWSサービス選定

#### Web Crawler
| AWS Service | 用途 |
|------------|------|
| Amazon EC2 / ECS | Crawler実行 |
| Amazon ElastiCache (Redis) | URL重複検出 |
| Amazon S3 | Repository（圧縮HTML保存） |
| Amazon DynamoDB | Seed URLデータベース |

#### Search Engine
| AWS Service | 用途 |
|------------|------|
| Amazon OpenSearch | Inverted Index構築・検索 |
| Amazon S3 | Document Store |
| Amazon CloudFront | 検索結果キャッシュ配信 |
| Amazon API Gateway | 検索APIエンドポイント |

### 2.5 スケーリング戦略

**Distributed Caching**:
- Redis Cluster Mode: URL重複検出の分散化
- Bloom Filters: 確率的重複検出（省メモリ）

**Multi-Region Deployment**:
- 地理的近接性: Crawler配置最適化
- Content Freshness: 地域ごとのクローリング頻度調整

**Elasticsearch Scaling**:
- Primary Shard + Replica Shards: 読取スケーリング
- マルチAZ配置: 高可用性確保

---

## Case Study 3: Social Network（概要）

### 3.1 要件定義
- ユーザープロフィール管理
- フォロー・フォロワー関係
- ニュースフィード生成・配信
- 投稿・いいね・コメント

### 3.2 スケール考慮事項
- ユーザー数: 数億～数十億
- 投稿数: 数千億
- ニュースフィード生成: リアルタイム性 vs 計算コスト

### 3.3 AWSサービス選定
| 要件 | AWS Service |
|-----|------------|
| ユーザープロフィール | Amazon DynamoDB |
| グラフ関係（フォロー） | Amazon Neptune (Graph DB) |
| ニュースフィード配信 | Amazon ElastiCache + DynamoDB |
| メディア保存 | Amazon S3 + CloudFront |
| リアルタイム更新 | Amazon Kinesis + Lambda |

---

## Case Study 4: Online Game Leaderboard（概要）

### 4.1 要件定義
- グローバル・地域別ランキング
- リアルタイム更新
- 高速読取（上位N件）

### 4.2 AWSサービス選定
| 要件 | AWS Service |
|-----|------------|
| リアルタイムランキング | Amazon ElastiCache (Redis Sorted Sets) |
| 永続化 | Amazon DynamoDB |
| スコア更新イベント処理 | Amazon Kinesis + Lambda |

**Redis Sorted Sets**:
```
ZADD leaderboard {score} {userId}
ZREVRANGE leaderboard 0 9  # トップ10取得
```

---

## Case Study 5: Hotel Reservation System（概要）

### 5.1 要件定義
- 在庫管理（部屋の空き状況）
- トランザクション整合性（同時予約の競合回避）
- 検索（価格・場所・日付フィルター）

### 5.2 AWSサービス選定
| 要件 | AWS Service | 理由 |
|-----|------------|------|
| トランザクション | Amazon RDS (PostgreSQL) | ACID保証 |
| 検索インデックス | Amazon OpenSearch | 複雑フィルター対応 |
| 在庫管理 | DynamoDB Transactions | 楽観的ロック |
| イベント処理 | Amazon SQS + Lambda | 予約確認・請求処理 |

**予約フロー（Saga Pattern）**:
1. 在庫確認 → 仮予約
2. 決済処理
3. 成功 → 予約確定 / 失敗 → 仮予約ロールバック

---

## Case Study 6: Chat Application（概要）

### 6.1 要件定義
- リアルタイムメッセージ配信
- メッセージ履歴保存
- オンライン状態管理

### 6.2 AWSサービス選定
| 要件 | AWS Service |
|-----|------------|
| WebSocket接続 | AWS AppSync (GraphQL Subscriptions) |
| メッセージ配信 | Amazon API Gateway WebSocket API + Lambda |
| メッセージ保存 | Amazon DynamoDB |
| プレゼンス管理 | Amazon ElastiCache (Redis) |

**WebSocket vs Long Polling**:
| 方式 | レイテンシー | サーバー負荷 |
|-----|------------|------------|
| WebSocket | 低 | 低（双方向接続維持） |
| Long Polling | 高 | 高（頻繁な再接続） |

---

## Case Study 7: Video-Processing Pipeline（概要）

### 7.1 要件定義
- 動画アップロード受付
- トランスコーディング（複数解像度）
- サムネイル生成
- CDN配信

### 7.2 AWSサービス選定
| 処理ステージ | AWS Service |
|------------|------------|
| アップロード | Amazon S3 (Multipart Upload) |
| オーケストレーション | AWS Step Functions |
| トランスコーディング | AWS Elemental MediaConvert |
| サムネイル生成 | AWS Lambda (FFmpeg) |
| 配信 | Amazon CloudFront + S3 |

**Step Functionsワークフロー**:
```
1. Validate Video
2. Parallel:
   - Transcode 1080p
   - Transcode 720p
   - Transcode 480p
   - Generate Thumbnail
3. Aggregate Results
4. Distribute to CDN
```

---

## Case Study 8: Online Stock-Trading Platform（概要）

### 8.1 要件定義
- 超低レイテンシー（マイクロ秒単位）
- 高スループット（数百万TPS）
- トランザクション整合性

### 8.2 AWSサービス選定
| 要件 | AWS Service | 考慮事項 |
|-----|------------|---------|
| 注文処理 | Amazon Aurora (MySQL互換) | ACID保証 |
| リアルタイム価格 | Amazon ElastiCache (Redis) | インメモリ処理 |
| イベントストリーミング | Amazon MSK (Kafka) | 高スループット |
| コンピュート | EC2 (I3インスタンス) | 最低レイテンシー |

**レイテンシー最適化**:
- Placement Groups (Cluster): EC2インスタンス間低レイテンシー
- Enhanced Networking: SR-IOV有効化
- In-Memory Databases: ElastiCache Redis

---

## 共通設計パターン

### 1. Database Selection Matrix

| ユースケース | 推奨DB | 理由 |
|------------|-------|------|
| 単純Key-Value | DynamoDB | 水平スケーリング、低レイテンシー |
| 複雑トランザクション | Amazon RDS/Aurora | ACID保証 |
| グラフ関係 | Amazon Neptune | 関係トラバーサル最適化 |
| 全文検索 | Amazon OpenSearch | Inverted Index、分析 |
| 時系列データ | Amazon Timestream | 自動データライフサイクル |

### 2. Caching Strategy

| レイヤー | 技術 | 適用場面 |
|---------|------|---------|
| Client-Side | Browser Cache | 静的コンテンツ |
| CDN | CloudFront | グローバル配信 |
| Application | ElastiCache/DAX | ホットデータ |
| Database | Query Result Cache | 頻繁なクエリ |

### 3. Asynchronous Processing

| パターン | AWS Service | ユースケース |
|---------|------------|-------------|
| Simple Queue | Amazon SQS | タスクバッファリング |
| Pub/Sub | Amazon SNS | イベントブロードキャスト |
| Stream Processing | Amazon Kinesis | リアルタイム分析 |
| Orchestration | AWS Step Functions | 複雑ワークフロー |

### 4. High Availability Patterns

| パターン | 実装 | RTO/RPO |
|---------|------|---------|
| Multi-AZ | RDS Multi-AZ | RTO: 分単位、RPO: 0 |
| Multi-Region | DynamoDB Global Tables | RTO: 秒単位、RPO: 秒単位 |
| Active-Active | Route 53 + ALB | RTO: 秒単位、RPO: 0 |

---

## 結論

実際のシステム設計では、以下のプロセスを繰り返します:

1. **要件定義**: 機能要件・非機能要件・スケール見積もり
2. **サービス選定**: トレードオフを評価して最適なAWSサービスを選択
3. **Day 0アーキテクチャ**: 迅速な市場投入を優先
4. **Day N最適化**: メトリクス・オブザーバビリティに基づいてスケーリング
5. **継続的改善**: ユーザーフィードバックとビジネス要件に適応

**重要な原則**:
- Start small, scale smart（小さく始めて賢くスケール）
- Measure, then optimize（測定してから最適化）
- Design for failure（障害を前提に設計）
- Automate everything（すべてを自動化）
