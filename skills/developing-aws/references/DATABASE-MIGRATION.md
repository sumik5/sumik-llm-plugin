# AWS Database Migration リファレンス

データベース移行の戦略、ツール、パターンの包括的ガイド。

> **関連**: サービス詳細は [DATABASE-SERVICES.md](./DATABASE-SERVICES.md) を参照

---

## 目次

1. [AWS Database Migration Service (DMS)](#aws-database-migration-service-dms)
2. [AWS Schema Conversion Tool (SCT)](#aws-schema-conversion-tool-sct)
3. [移行戦略](#移行戦略)
4. [バックアップとリストア](#バックアップとリストア)
5. [高可用性とディザスタリカバリ](#高可用性とディザスタリカバリ)
6. [移行パターン](#移行パターン)

---

## AWS Database Migration Service (DMS)

### アーキテクチャ

**コンポーネント**

| コンポーネント | 説明 |
|--------------|------|
| Replication Instance | 移行処理を実行するEC2インスタンス |
| Source Endpoint | ソースデータベースへの接続設定 |
| Target Endpoint | ターゲットデータベースへの接続設定 |
| Replication Task | 移行ジョブの定義 |

**Replication Instance**
- インスタンスクラス選択（dms.t3.*, dms.r5.*等）
- Multi-AZ対応
- 十分なストレージ容量

### 移行タイプ

| タイプ | 説明 | 用途 |
|--------|------|------|
| Full Load | 既存データの完全コピー | 初期移行 |
| CDC (Change Data Capture) | 変更分のみ継続的に複製 | 継続的レプリケーション |
| Full Load + CDC | 完全コピー後に変更追跡 | ダウンタイム最小化移行 |

### サポートするソース/ターゲット

**ソースエンジン**
- Oracle, SQL Server, MySQL, PostgreSQL, MariaDB
- Amazon RDS, Aurora
- SAP ASE, MongoDB, DocumentDB
- S3, Kinesis, Kafka

**ターゲットエンジン**
- Amazon RDS (全エンジン)
- Amazon Aurora
- Amazon Redshift
- Amazon DynamoDB
- Amazon S3
- Amazon OpenSearch Service
- Amazon Neptune
- Amazon Kinesis Data Streams

### CDC（Change Data Capture）

**仕組み**
1. ソースDBのトランザクションログを読み取り
2. 変更を解析してターゲットに適用
3. 継続的な同期を維持

**要件（ソース別）**

| ソース | 要件 |
|--------|------|
| Oracle | Supplemental Logging有効化 |
| SQL Server | トランザクションログ有効 |
| MySQL | binlog有効（ROW形式） |
| PostgreSQL | logical replication設定 |

### テーブルマッピング

**選択ルール**
```json
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "include-orders",
      "object-locator": {
        "schema-name": "sales",
        "table-name": "orders"
      },
      "rule-action": "include"
    }
  ]
}
```

**変換ルール**
- スキーマ名変更
- テーブル名変更
- カラム名変更
- データ型変換

### バリデーション

**データ検証**
- 行数比較
- チェックサム比較
- 不一致レポート

**有効化**
```
EnableValidation: true
```

### パフォーマンスチューニング

**Replication Instance**
- 適切なインスタンスサイズ選択
- Multi-AZは本番環境で推奨
- ストレージIOPS考慮

**タスク設定**

| 設定 | 説明 | 推奨値 |
|------|------|--------|
| MaxFullLoadSubTasks | 並列ロード数 | 8-16 |
| ParallelLoadThreads | テーブル内並列度 | 4-8 |
| BatchApplyEnabled | バッチ適用 | true |
| BatchApplyPreserveTransaction | トランザクション保持 | 状況による |

### LOBデータ処理

| モード | 説明 | パフォーマンス |
|--------|------|--------------|
| Limited LOB | 最大サイズ指定 | 高速 |
| Full LOB | サイズ無制限 | 低速 |
| Inline LOB | 小さいLOBをインライン | 中間 |

---

## AWS Schema Conversion Tool (SCT)

### 概要

**機能**
- スキーマ変換（DDL）
- コード変換（ストアドプロシージャ、関数）
- 移行アセスメント
- データ抽出エージェント

### サポートする変換

**ソース → ターゲット**

| ソース | ターゲット |
|--------|----------|
| Oracle | Aurora PostgreSQL, Aurora MySQL, RDS |
| SQL Server | Aurora PostgreSQL, Aurora MySQL, RDS |
| Teradata | Amazon Redshift |
| Oracle DW | Amazon Redshift |
| Netezza | Amazon Redshift |

### アセスメントレポート

**評価カテゴリ**

| カテゴリ | 説明 | 目安 |
|---------|------|------|
| Simple (Green) | 自動変換可能 | <1時間 |
| Medium (Amber) | 軽微な手動修正 | 1-4時間 |
| Significant (Red) | 大幅な手動修正 | >4時間 |

**レポート内容**
- 変換サマリー
- 変換不可項目一覧
- 推奨アクション
- 工数見積もり

### 変換ワークフロー

1. **プロジェクト作成**: ソース/ターゲット指定
2. **接続設定**: DB接続情報入力
3. **スキーマ抽出**: ソーススキーマ取得
4. **アセスメント実行**: 変換可能性評価
5. **スキーマ変換**: DDL/コード変換
6. **レビュー・修正**: 手動調整
7. **ターゲット適用**: 変換結果をターゲットへ

### データ抽出エージェント

**大規模データ移行用**
- オンプレミスにエージェント配置
- データをS3経由で転送
- Snowball連携可能
- 並列抽出で高速化

---

## 移行戦略

### 6Rフレームワーク

| 戦略 | 説明 | DB移行での適用 |
|------|------|--------------|
| Rehost | リフト&シフト | EC2上のDBをそのまま移行 |
| Replatform | リフト&最適化 | RDSへの移行 |
| Repurchase | SaaS移行 | マネージドサービスへ |
| Refactor | リアーキテクト | Aurora/DynamoDBへ |
| Retire | 廃止 | 不要DBの削除 |
| Retain | 維持 | オンプレミス継続 |

### 移行フェーズ

**Phase 1: 評価**
- 現行環境の棚卸し
- ワークロード分析
- 依存関係マッピング
- コスト試算

**Phase 2: 計画**
- 移行戦略選定
- タイムライン策定
- リスク評価
- ロールバック計画

**Phase 3: 準備**
- ターゲット環境構築
- ネットワーク設定
- セキュリティ設定
- テスト環境準備

**Phase 4: 移行**
- スキーマ移行
- データ移行
- アプリケーション切り替え
- 検証

**Phase 5: 最適化**
- パフォーマンスチューニング
- コスト最適化
- 監視設定
- ドキュメント化

### ダウンタイム最小化

**戦略**

| アプローチ | ダウンタイム | 複雑度 |
|-----------|------------|--------|
| オフライン移行 | 数時間〜数日 | 低 |
| ダンプ/リストア + CDC | 数分〜数時間 | 中 |
| Full Load + CDC | 数分 | 中 |
| ブルー/グリーン | 秒単位 | 高 |

---

## バックアップとリストア

### RDSバックアップ

**自動バックアップ**
- 日次フルバックアップ（バックアップウィンドウ）
- トランザクションログ（5分間隔）
- 保持期間: 1-35日
- ポイントインタイムリカバリ (PITR) 対応

**手動スナップショット**
- 任意のタイミングで取得
- 保持期間無制限
- クロスリージョンコピー可能
- 暗号化スナップショットの共有

### Aurora バックアップ

**連続バックアップ**
- S3への継続的バックアップ
- 保持期間: 1-35日
- サブ秒単位のPITR（最大過去35日）

**クラスタースナップショット**
- 手動取得
- クロスリージョンコピー
- 別アカウントへの共有

**Backtracking**
- 数秒で過去状態に戻す
- ダウンタイムなし
- 最大72時間前まで
- Aurora MySQL のみ

### DynamoDB バックアップ

**オンデマンドバックアップ**
- フルバックアップ
- 保持期間無制限
- クロスリージョンリストア可能

**ポイントインタイムリカバリ (PITR)**
- 継続的バックアップ
- 35日以内の任意時点にリストア
- 秒単位の粒度

### S3へのエクスポート

**RDS/Aurora → S3**
- Parquet形式
- スナップショットからエクスポート
- 分析用途（Athena、Redshift Spectrum）

**DynamoDB → S3**
- JSON形式
- 特定時点のエクスポート
- 分析・アーカイブ用

---

## 高可用性とディザスタリカバリ

### RDS Multi-AZ

**同期レプリケーション**
- プライマリとスタンバイ
- 同期的なストレージレプリケーション
- 自動フェイルオーバー（通常60-120秒）

**Multi-AZ DB Cluster（新機能）**
- 1 Writer + 2 Reader
- 読み取りスケーリング
- より高速なフェイルオーバー

### Aurora 高可用性

**標準構成**
- 3AZにわたる6つのストレージコピー
- 最大15 Read Replica
- 自動フェイルオーバー（通常30秒以内）

**フェイルオーバー優先度**
- Tier設定（0-15）
- 低いTierが優先

### RPO/RTOマトリクス

| 構成 | RPO | RTO | コスト |
|------|-----|-----|--------|
| 単一AZ | 最大5分 | 数分〜数時間 | 低 |
| Multi-AZ | 0 | 60-120秒 | 中 |
| Aurora標準 | 0 | 30秒以内 | 中〜高 |
| Aurora Global | 通常<1秒 | <1分 | 高 |
| クロスリージョンReplica | 数分 | 数分 | 中〜高 |

### DRパターン

**Backup and Restore**
- コスト: 低
- RPO: 時間単位
- RTO: 時間単位
- バックアップのクロスリージョンコピー

**Pilot Light**
- コスト: 中
- RPO: 分単位
- RTO: 分〜時間
- 最小構成をスタンバイ

**Warm Standby**
- コスト: 中〜高
- RPO: 秒〜分
- RTO: 分単位
- 縮小構成でアクティブ

**Multi-Site Active-Active**
- コスト: 高
- RPO: 秒以下
- RTO: 秒〜分
- 複数リージョンでアクティブ

---

## 移行パターン

### 同種移行（Homogeneous）

**例: Oracle → RDS Oracle**
- スキーマ変換不要
- ネイティブツール使用可能（Data Pump等）
- DMS でのデータ移行

**手順**
1. RDSインスタンス作成
2. スキーマ移行（エクスポート/インポート）
3. DMSでデータ移行（Full Load + CDC）
4. 検証
5. カットオーバー

### 異種移行（Heterogeneous）

**例: Oracle → Aurora PostgreSQL**
- SCTでスキーマ/コード変換
- DMSでデータ移行
- アプリケーション修正が必要

**手順**
1. SCTでアセスメント
2. Auroraクラスター作成
3. SCTでスキーマ変換・適用
4. 手動でコード修正
5. DMSでデータ移行
6. テスト・検証
7. カットオーバー

### 大規模データ移行

**10TB超の移行**
- AWS Snowball / Snowball Edge
- SCTデータ抽出エージェント
- 並列処理の最大化

**ネットワーク帯域計算**

```
転送時間(時間) = データ量(GB) * 8 / 帯域(Mbps) / 3600

例: 10TB, 1Gbps = 10000 * 8 / 1000 / 3600 ≒ 22時間
```

### アプリケーション移行考慮

**接続文字列**
- エンドポイント変更
- DNSベースの切り替え推奨

**ドライバー/クライアント**
- バージョン互換性確認
- 接続プーリング設定

**SQLの互換性**
- 方言の違い
- 日付/時刻関数
- 文字列関数

---

## 関連リファレンス

- [DATABASE-SERVICES.md](./DATABASE-SERVICES.md) - AWSデータベースサービス詳細
- [SYSTEM-DESIGN.md](./SYSTEM-DESIGN.md) - システム設計パターン
- [SERVERLESS-PATTERNS.md](./SERVERLESS-PATTERNS.md) - サーバーレスアーキテクチャ
- [CDK.md](./CDK.md) - IaCパターン
