# AWS Cloud Design Pattern (CDP) カタログ

AWS Cloud Design Pattern は、AWSのクラウド特性を最大限に活用した設計パターン集。オンプレミスからの移行やクラウドネイティブ設計において、再利用可能なアーキテクチャの知見を提供する。

> **関連**: システム設計基礎は [SYSTEM-DESIGN.md](./SYSTEM-DESIGN.md)、VPC設計は [VPC-ARCHITECTURE.md](./VPC-ARCHITECTURE.md) を参照

---

## パターン一覧（全57パターン）

### 1. 基本パターン

| パターン | 問題 | 解決策 | 主要サービス |
|---------|------|--------|------------|
| **Snapshot** | バックアップの自動化が困難 | EBSスナップショットで瞬間的バックアップを自動取得 | EBS, S3 |
| **Stamp** | 環境構築に手間・時間がかかる | 設定済みAMIを「スタンプ」として大量複製 | EC2, AMI |
| **Scale Up** | 負荷増加に伴うリソース不足 | インスタンスタイプを上位に変更（垂直スケーリング） | EC2 |
| **Scale Out** | 単一サーバーのリソース上限 | 複数サーバー並列配置＋ロードバランサーで負荷分散 | EC2, ELB, Auto Scaling |
| **Ondemand Disk** | EBS容量の拡張困難 | スナップショット経由で大容量EBSを作成・マウント切替 | EBS, EC2 |

#### Snapshot パターン実装ポイント
- EBSスナップショットは差分バックアップ → 高頻度取得が低コスト
- リージョン間コピーでDR対応（例: 東京→シンガポール）
- RPO（復旧目標時点）に合わせたスケジュール設計
- 99.9999999999% の耐久性（S3基盤）
- 定期的なリストア検証が必須

#### Stamp vs Bootstrap のトレードオフ
| 観点 | Stamp (AMI) | Bootstrap (User Data) |
|------|-------------|----------------------|
| 起動速度 | 高速（AMIからそのまま起動） | 低速（起動後にスクリプト実行） |
| 柔軟性 | 低い（AMI再生成が必要） | 高い（スクリプト変更のみ） |
| 管理負荷 | AMIのバージョニングが必要 | スクリプトのコード管理 |
| 適用場面 | 環境固定のスケールアウト | 動的構成のデプロイ |

---

### 2. 可用性向上パターン

| パターン | 問題 | 解決策 | 主要サービス |
|---------|------|--------|------------|
| **Multi-Server** | 単一サーバー障害が全体障害に | ELBヘルスチェック＋複数サーバー冗長配置 | EC2, ELB, Auto Scaling |
| **Multi-Datacenter** | データセンター全体障害への対応がない | 複数AZ/リージョンにサーバー分散配置 | EC2, ELB, Route 53, RDS |
| **Floating IP** | サーバー置換時のIP変更による接続断 | Elastic IPの論理的な付け替え | EC2, Elastic IP, ENI |
| **Deep Health Check** | 標準ヘルスチェックではアプリ層障害を検知不可 | 依存サービス（DB等）を実際に確認するエンドポイント実装 | ELB, EC2 |
| **Routing-Based HA** | DNSレベルでの冗長化が必要 | Route 53の高度なルーティングでフェイルオーバー | Route 53, CloudWatch |

#### Deep Health Check 実装例
```
GET /health → アプリが以下をチェック:
  1. DB SELECT クエリ実行 → OK/NG
  2. キャッシュサーバー ping → OK/NG
  3. 外部API疎通確認 → OK/NG
→ 全OK: 200 OK / いずれかNG: 503 Service Unavailable
```

**注意**: ヘルスチェック自体のDB負荷に注意。頻繁なチェックで過負荷化しないようタイムアウト・間隔を慎重に設計。

#### Route 53 ルーティング戦略

| 戦略 | 用途 | 特徴 |
|------|------|------|
| **フェイルオーバー** | Primary/Secondary冗長化 | Primary障害時にSecondaryへ自動切替 |
| **レイテンシーベース** | グローバル配信最適化 | クライアント地域で最速リージョンへルーティング |
| **ジオロケーション** | 地域限定配信 | IP地域情報で地理的ルーティング（GDPR対応等） |
| **加重ルーティング** | カナリアリリース/A-Bテスト | A:70%, B:30% の比率分散 |

---

### 3. 動的コンテンツ処理パターン

| パターン | 問題 | 解決策 | 主要サービス |
|---------|------|--------|------------|
| **Clone Server** | スケールアウト時のファイル複製の手間 | Stamp + Auto Scalingでクローン自動生成 | EC2, AMI, Auto Scaling |
| **NFS Sharing** | 複数サーバー間のリアルタイムファイル共有 | EFS (NFS v4.1) でスケーラブルな共有ストレージ | EFS, EC2 |
| **NFS Replica** | NFS Sharingのマスター参照性能低下 | 各サーバーにレプリカ保管（読み取り専用） | EBS, EC2 |
| **State Sharing** | ステートフルアプリの複数サーバー共有 | ElastiCache (Redis/Memcached) でセッション外部化 | ElastiCache, DynamoDB |
| **URL Rewriting** | URLパターンでのリクエスト分岐 | ALBのPath-based/Host-based routing | ALB |
| **Rewrite Proxy** | バックエンドURL隠蔽 | リバースプロキシでURL書き換え | EC2 (Nginx), ALB |
| **Cache Proxy** | バックエンドへの過多リクエスト | リバースプロキシにキャッシュ機能付与 | CloudFront, ElastiCache |
| **Scheduled Scale Out** | トラフィック予測可能時のスケーリング遅延 | CloudWatch Events + Lambda で計画的スケーリング | CloudWatch Events, Lambda, Auto Scaling |
| **IP Pooling** | 複数Elastic IP管理の煩雑さ | IPプールとして事前割当、Lambda で自動アタッチ | EC2, Elastic IP, Lambda |

#### State Sharing: セッションストア設計

```python
# Cache-Aside パターン（推奨）
def get_session(user_id):
    # 1. キャッシュから検索
    session = redis.get(f"session:{user_id}")
    if session:
        return session  # キャッシュヒット

    # 2. キャッシュミス → DB検索 → キャッシュ保存
    session = db.query(f"SELECT * FROM sessions WHERE user_id = '{user_id}'")
    redis.setex(f"session:{user_id}", ttl=1800, value=session)  # TTL 30分
    return session
```

- **スティッキーセッション不要** → サーバー追加削除が容易
- **ElastiCache クラスター化で冗長化** → SPOF回避

---

### 4. 静的コンテンツ処理パターン

| パターン | 問題 | 解決策 | 主要サービス |
|---------|------|--------|------------|
| **Web Storage** | EC2での大容量ファイル配布がリソース圧迫 | S3に直接配置、クライアントがS3から直接DL | S3 |
| **Direct Hosting** | 静的サイトにEC2を使うのは非効率 | S3のWebホスティング機能でサーバーレス配信 | S3, Route 53 |
| **Private Distribution** | S3ファイルを認証ユーザー限定で配布 | CloudFront + OAI + 署名付きURL | CloudFront, S3, IAM |
| **Cache Distribution** | グローバル配信のレイテンシー | CloudFront CDN で世界中のエッジにキャッシュ | CloudFront, S3 |
| **Rename Distribution** | CDNキャッシュ更新遅延 | ファイル名にバージョン付与して更新を強制 | CloudFront, S3 |
| **Private Cache Distribution** | 認証＋キャッシュの両立 | CloudFront + OAI + 署名付きCookie | CloudFront, S3, Lambda@Edge |
| **Latency Based Origin** | グローバル配信で最速オリジン自動選択 | Route 53 レイテンシーベースルーティング | Route 53, CloudFront, S3 |

#### キャッシュ無効化戦略

| 方式 | コスト | 即時反映 | 運用負荷 |
|------|--------|---------|---------|
| **Rename Distribution** | なし（ファイル名変更のみ） | ✅ | ビルドツールで自動化推奨 |
| **CloudFront Invalidation** | API課金あり | ✅ | API呼び出し管理 |
| **TTL短縮** | なし | ❌（TTL経過後） | 設定管理 |

---

### 5. データアップロード処理パターン

| パターン | 問題 | 解決策 | 主要サービス |
|---------|------|--------|------------|
| **Write Proxy** | 大量PUT/POSTの集中によるボトルネック | リバースプロキシで複数バックエンドに分散 | EC2 (Nginx), Route 53 |
| **Storage Index** | S3ファイルの検索・管理困難 | S3イベント → Lambda → DynamoDBにメタデータ記録 | S3, DynamoDB, Lambda |
| **Direct Object Upload** | 大容量ファイルのサーバー中継コスト | S3 Pre-signed URLでクライアント→S3直接アップロード | S3, Lambda, IAM |

#### Direct Object Upload フロー
```
1. クライアント → Webサーバー: 署名付きURL要求
2. Webサーバー → IAM: 権限確認
3. Webサーバー → クライアント: 署名付きURL返却（有効期限15分）
4. クライアント → S3: PUT リクエスト（直接アップロード）
5. S3 → トークン検証 → ファイル受入
```
- Webサーバー負荷ゼロ、帯域幅コスト削減（EC2データ転送料不要）

---

### 6. リレーショナルDB処理パターン

| パターン | 問題 | 解決策 | 主要サービス |
|---------|------|--------|------------|
| **DB Replication** | DB単一障害で全システム停止 | RDS Multi-AZで自動レプリケーション＋フェイルオーバー | RDS |
| **Read Replica** | DB読み取り処理のCPU/メモリ不足 | RDS Read Replicaで読み取り専用レプリカ分散 | RDS |
| **Inmemory DB Cache** | ディスクI/Oボトルネック | ElastiCacheで頻出データをメモリキャッシュ | ElastiCache, RDS |
| **Sharding Write** | DB書き込みスループット限界 | シャードキーでDBを分割、分散書き込み | RDS (複数), アプリロジック |

#### キャッシュパターン比較

| パターン | 一貫性 | 読み取り性能 | 書き込み性能 | 適用場面 |
|---------|--------|------------|------------|---------|
| **Cache-Aside** (Lazy Loading) | 結果整合 | ◎ | ○ | 読み取り重視 |
| **Write-Through** | 強い一貫性 | ◎ | △（遅い） | 一貫性重視 |
| **Write-Behind** | 結果整合 | ◎ | ◎ | 書き込み重視 |

#### Sharding Write 注意点
- **シャードキー選定**: 分散度の高い属性（ユーザーID、テナントID等）
- **ホットスポット対策**: シャードキーの分布を事前確認
- **クロスシャード検索**: 複数DB同時クエリ→マージが必要で困難
- **再分散**: シャード数増加時の大規模データ移行（ダウンタイムor段階的移行）

---

### 7. 非同期処理・バッチ処理パターン

| パターン | 問題 | 解決策 | 主要サービス |
|---------|------|--------|------------|
| **Queuing Chain** | 長時間処理のサーバー負荷 | SQSキューで非同期化、Worker別プロセスで処理 | SQS, EC2/Lambda |
| **Priority Queue** | SQS FIFOのみで優先度付き処理不可 | 優先度別の複数SQSキューで順次処理 | SQS, Lambda, SNS |
| **Job Observer** | バッチジョブの進捗不明 | DynamoDBにジョブ状態記録、進捗監視ダッシュボード | DynamoDB, Lambda, CloudWatch |
| **Fanout** | 1イベントを複数後続処理に分散 | SNS Topicで複数SQSキューにFan-out | SNS, SQS, Lambda |

#### Queuing Chain 必須設計要件
- **べき等性**: メッセージ重複実行に耐性を持たせる
- **Dead Letter Queue (DLQ)**: 処理失敗メッセージの隔離
- **可視性タイムアウト**: 処理中メッセージの再配信防止
- **メッセージ有効期限**: デフォルト4日、要件に応じて調整

---

### 8. 運用保守パターン

| パターン | 問題 | 解決策 | 主要サービス |
|---------|------|--------|------------|
| **Bootstrap** | AMIより柔軟なサーバー初期化 | User Dataスクリプトで起動時に動的初期化 | EC2, S3, Systems Manager |
| **Cloud DI** | 設定のハードコード化で環境管理複雑 | Parameter Store / Secrets Managerで設定外部管理 | Systems Manager, Secrets Manager |
| **Stack Deployment** | インフラのコード化・バージョン管理 | CloudFormation / Terraform でテンプレート化 | CloudFormation, Terraform |
| **Server Swapping** | 本番サーバー置換時のダウンタイム | Floating IP / Route 53 DNS切替で無停止置換 | Elastic IP, Route 53, ALB |
| **Monitoring Integration** | EC2ログの集約・検索 | CloudWatch Logs Agent でログ収集・分析 | CloudWatch Logs |
| **Weighted Transition** | 新バージョンの不具合をいきなり全ユーザーに露出 | Route 53 / ALB 加重ルーティングで段階的切替 | Route 53, ALB, CloudWatch |
| **Log Aggregation** | 複数インスタンスのログ分散 | CloudWatch Logs / ELK / Kinesis Firehoseで中央集約 | CloudWatch Logs, Kinesis, Elasticsearch |
| **Ondemand Activation** | リソース常時起動のコスト膨大 | Lambda + CloudWatch Eventsでスケジュール起動/停止 | Lambda, CloudWatch Events |

#### Cloud DI: 設定管理の使い分け

| サービス | 用途 | 例 |
|---------|------|-----|
| **Parameter Store** | 非機密設定 | APIエンドポイント、設定フラグ |
| **Secrets Manager** | 機密情報 | DBパスワード、APIキー |
| **AppConfig** | 動的設定変更 | 機能フラグ、ランタイム設定 |

---

### 9. ネットワークパターン

| パターン | 問題 | 解決策 | 主要サービス |
|---------|------|--------|------------|
| **Backnet** | プライベートLAN通信の必要性 | VPC Private Subnetで外部非公開通信 | VPC, Subnet, Route Table |
| **Functional Firewall** | アプリケーション層のアクセス制御 | WAFでSQL Injection/XSS等をブロック | AWS WAF, ALB, CloudFront |
| **Operational Firewall** | インフラ層のネットワーク制御 | Security Group + Network ACL + VPC Flow Logs | VPC, SG, NACL |
| **Multi Load Balancer** | 複数LB運用の複雑さ | Route 53 + 複数ALBで地理的/レイテンシーベース分散 | Route 53, ALB |
| **WAF Proxy** | CloudFront前段のWAF必要性 | CloudFront → AWS WAF統合 | AWS WAF, CloudFront |
| **CloudHub** | 複数VPC間プライベート通信 | VPC Peering / Transit Gatewayで接続 | VPC Peering, Transit Gateway |
| **Sorry Page** | サイト障害時のメンテナンスページ | CloudFront Custom Error Responseで返却 | CloudFront, S3 |
| **Self Registration** | 新サーバーのLB手動登録 | Auto Scaling + Target Groupで自動登録/解除 | Auto Scaling, ALB, Target Group |
| **RDP Proxy** | EC2への安全なRDP/SSHアクセス | Bastion Host（踏み台）をPublic Subnetに配置 | EC2, VPC, Security Groups |
| **Floating Gateway** | NAT Gateway障害時の外部通信不能 | 複数AZにNAT Gateway配置で冗長化 | VPC, NAT Gateway |
| **Shared Service** | 複数VPCでの共通リソース共有 | 一元化VPCに共有リソース配置、Peering/Transit GW経由 | VPC Peering, Transit Gateway, Route 53 |

---

## パターン選定ガイド

### 高可用性が最優先の場合

```
1. Multi-Datacenter + Multi-Server（複数AZ冗長化）
2. DB Replication（RDS Multi-AZ）
3. Read Replica（読み取り負荷分散）
4. Cache Distribution + CloudFront（静的キャッシュ）
5. Routing-Based HA（DNSフェイルオーバー）
6. Floating Gateway（NAT冗長化）
```

### スケーラビリティ重視の場合

```
1. Scale Out + Clone Server + Auto Scaling（水平スケーリング）
2. State Sharing + ElastiCache（状態管理）
3. Sharding Write（DB書き込み分散）
4. CloudFront + Web Storage（コンテンツ配信最適化）
5. Queuing Chain + Fanout（非同期タスク処理）
```

### コスト最適化の場合

```
1. Scheduled Scale Out（非営業時間にスケールダウン）
2. Ondemand Activation（不要時は停止）
3. Web Storage + Direct Hosting（EC2削減）
4. Inmemory DB Cache（DB負荷削減→RDS tier低下可能）
5. Log Aggregation → S3/Glacier（ログ保存コスト削減）
```

### セキュリティ重視の場合

```
1. Backnet + Operational Firewall（Private Subnet + SG）
2. RDP Proxy（踏み台経由アクセス）
3. WAF Proxy（アプリケーション層攻撃対策）
4. Cloud DI（機密情報安全管理）
5. Private Distribution + Floating IP（認証・暗号化）
```

---

## 実装チェックリスト

新規システム構築時の参照リスト:

- [ ] **バックアップ**: Snapshot でEBSバックアップ自動化
- [ ] **環境テンプレート**: Stamp (AMI) or Bootstrap (User Data) でサーバー構成管理
- [ ] **スケーリング**: Scale Out + Auto Scaling + Clone Server で水平スケーリング
- [ ] **可用性**: Multi-Server + Multi-Datacenter で複数AZ冗長化
- [ ] **DB冗長化**: DB Replication (Multi-AZ) + Read Replica で読み書き分離
- [ ] **キャッシュ**: Cache Distribution + Inmemory DB Cache で性能最適化
- [ ] **非同期処理**: Queuing Chain + Fanout でデカップリング
- [ ] **ネットワーク**: Backnet + Operational Firewall でセキュアネットワーク
- [ ] **監視**: Monitoring Integration + Log Aggregation でログ一元管理
- [ ] **デプロイ**: Weighted Transition で段階的リリース
- [ ] **設定管理**: Cloud DI で環境設定の外部化
- [ ] **コスト**: Ondemand Activation + Scheduled Scale Out でコスト削減
