# Cloud Logging & Security Monitoring

GCPのログ管理とセキュリティモニタリングの実践的リファレンス。Cloud LoggingとSecurity Command Center (SCC) を活用したセキュリティ運用の実装ガイド。

---

## Cloud Logging 概要

### Operations Suite の構成

Cloud Loggingは以下の4コンポーネントで構成される操作スイート:

| コンポーネント | 役割 |
|--------------|------|
| Cloud Logging | ログ収集・検索・フィルタリング・エクスポート |
| Cloud Monitoring | メトリクス収集・ダッシュボード・アラート |
| APM | Trace/Debugger/Profiler統合 |
| Multi-Cloud | AWS/オンプレミス統合 |

### 基本用語

| 用語 | 説明 |
|------|------|
| Log Entries | ログの個別レコード（timestamp、resource、payload） |
| Logs | プロジェクト内の名前付きログエントリコレクション |
| Retention Period | ログタイプごとの保持期間（デフォルト値あり） |
| Log Router | 全ログが通過する中央ルーター（ingestion/routing判定） |
| Sinks | フィルタ + 保存先の組み合わせ |
| Log-based Metrics | ログからメトリクスを定義 |

---

## ログカテゴリ

### Security Logs

| ログタイプ | 内容 | 保持期間 | デフォルト有効 |
|----------|------|---------|--------------|
| Admin Activity | API呼び出し、設定変更 | 400日 | ✅ |
| Data Access | データアクセス記録 | 30日 | ❌ (BigQueryのみ✅) |
| System Event | システム生成イベント | N/A | ✅ |
| Policy Denied | VPC Service Controls拒否 | N/A | ✅（除外可能） |
| Access Transparency | Google社員アクセス記録 | N/A | Premium機能 |

**重要**: Admin Activity/System Event logsは無効化不可（常時記録）。

### Platform Logs

| ログタイプ | 用途 | サンプリング | 保持期間 |
|----------|------|------------|---------|
| VPC Flow Logs | ネットワークトラフィック | 約1/10パケット | 30日 |
| Firewall Logs | ファイアウォールルール適用 | TCP/UDPのみ | 30日 |
| NAT Logs | NAT接続/ドロップパケット | TCP/UDPのみ | 30日 |

### User Logs

**Cloud Logging Agent**: Fluentdベース。事前設定で以下をストリーム:
- syslogd
- MySQL/PostgreSQL/MongoDB/Cassandra/Apache

---

## Log Router とログフロー

### Log Router の動作

```
ログソース → Cloud Logging API → Log Router → [Sinks] → 保存先
                                    ↓
                                フィルタ評価（include/exclude）
                                    ↓
                                Ingestion判定（保存/破棄）
```

### Sinks 設定

**利用可能な保存先**:

| 保存先 | 用途 | フォーマット |
|--------|------|------------|
| Cloud Storage | アーカイブ | JSON |
| BigQuery | 分析 | テーブル |
| Pub/Sub | 連携/ストリーミング | JSON (Splunk等対応) |
| Cloud Logging Buckets | リージョン指定保持 | ログバケット |

---

## ログエクスポート実践

### Log Bucket作成

```bash
# 1. ログバケット作成（リージョン指定・保持期間設定）
gcloud logging buckets create my-regional-bucket \
  --location=australia-southeast1 \
  --retention-days=1825  # 5年

# 2. ログバケットロック（削除防止）
gcloud logging buckets update my-regional-bucket \
  --location=australia-southeast1 \
  --locked
```

**保持期間**: 最大100年（秒/日/年で指定可能）

### Sink作成とフィルタ設定

```bash
# 監査ログ + リソースログをCloud Storageへエクスポート
gcloud logging sinks create gcp_logging_sink_gcs \
  storage.googleapis.com/my-log-bucket-for-demo \
  --log-filter='logName:"/logs/cloudaudit.googleapis.com" OR
                resource.type:"gce" OR
                resource.type="gcs_bucket" OR
                resource.type="cloudsql_database" OR
                resource.type="bigquery_resource"' \
  --include-children \
  --organization=324989855333
```

**フィルタ構文**: Logging query language（AND/OR/比較演算子サポート）

### オブジェクトライフサイクル管理

```json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 60}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {"age": 120}
      }
    ]
  }
}
```

---

## ログ分析パイプライン

### BigQueryエクスポート

**直接エクスポート**:
```bash
# Sinkで直接BigQueryをターゲット指定
bigquery.googleapis.com/projects/PROJECT_ID/datasets/DATASET_ID
```

**DLP統合ストリーミング**:
```
Cloud Logging → Pub/Sub → Dataflow (DLP処理) → BigQuery
```

**利点**: PII除去後に分析可能

### Log Analytics

**ユースケース**:

| カテゴリ | 用途 |
|---------|------|
| DevOps | パターン発見、サービス間相関分析、デバッグ時間削減 |
| Security | 大規模時間範囲での調査、脅威分析 |
| IT Operations | フリート全体のトレンド分析、パフォーマンス追跡 |

---

## ログ集約とコンプライアンス

### 組織レベル集約

```
Organization
├── Folder A
│   ├── Project 1 → Aggregate Export
│   └── Project 2 → Aggregate Export
└── Folder B
    └── Project 3 → Aggregate Export
            ↓
    Centralized Log Bucket
```

**メリット**: 新規/既存すべてのプロジェクトで自動エクスポート

### コンプライアンス要件

**Separation of Duties（職務分離）**:
- 別チーム所有プロジェクトへのaggregated exports
- Cloud Storageでの長期保管

**Least Privilege（最小権限）**:
- Bucket Policy Only有効化（オブジェクトレベル権限無効）
- `roles/logging.viewer` 等の最小権限付与

**Non-Repudiation（否認防止）**:
- Bucket Lock（保持期間内削除防止）
- オブジェクトバージョニング有効化

### 監査ログ全有効化

```json
{
  "auditConfigs": [
    {
      "service": "allServices",
      "auditLogConfigs": [
        { "logType": "ADMIN_READ" },
        { "logType": "DATA_READ"  },
        { "logType": "DATA_WRITE" }
      ]
    }
  ]
}
```

---

## Security Command Center (SCC)

### 概要

| Tier | 機能 |
|------|------|
| Standard | 基本検出（SHA一部、Anomaly Detection） |
| Premium | 全脅威検出（ETD/KTD/VMTD）、コンプライアンス |

**通知速度**: 6-12分以内

### コアサービス

| サービス | 機能 |
|---------|------|
| Cloud Asset Inventory (CAI) | 全アセット・IAMポリシー可視化 |
| Security Health Analytics (SHA) | 設定ミス検出 |
| Event Threat Detection (ETD) | ログベース脅威検出 |
| Container Threat Detection (KTD) | GKEランタイム脅威検出 |
| VM Threat Detection (VMTD) | ハイパーバイザーレベル検出 |
| Web Security Scanner (WSS) | Webアプリ脆弱性スキャン |
| VM Manager | OS脆弱性管理 |

---

## Security Health Analytics (SHA)

### スキャンモード

| モード | 頻度 | 説明 |
|--------|------|------|
| Batch Scan | 6-12時間ごと | 全リソース定期スキャン |
| Real-time Scan | 設定変更時即時 | CAI変更イベント駆動 |
| Mixed Mode | 組み合わせ | 一部リアルタイム、一部バッチ |

### Standard Tier検出項目（抜粋）

| 検出タイプ | 説明 |
|-----------|------|
| OPEN_FIREWALL | 0.0.0.0/0からのアクセス許可 |
| PUBLIC_SQL_INSTANCE | パブリックIPのCloud SQL |
| MFA_NOT_ENFORCED | MFA未適用 |
| PUBLIC_BUCKET_ACL | パブリックアクセス可能なバケット |
| SSL_NOT_ENFORCED | SSL未強制 |

### Premium専用検出（CMEK系）

デフォルト無効（明示的有効化必要）:
- DISK_CMEK_DISABLED
- BUCKET_CMEK_DISABLED
- SQL_CMEK_DISABLED

**有効化**:
```bash
gcloud alpha scc settings services modules enable \
  --organization=ORGANIZATION_ID \
  --service=SECURITY_HEALTH_ANALYTICS \
  --module=DISK_CMEK_DISABLED
```

---

## Event Threat Detection (ETD)

### 必須ログ（自動有効）

- Admin Activity Logs（Cloud Audit Logs）
- VPC Service Controls Audit Logs

### 推奨追加ログ

| ログタイプ | 用途 |
|----------|------|
| SSH/syslog | ブルートフォース検出 |
| Data Access Logs | データエクスフィルトレーション検出 |
| VPC Flow Logs | マルウェア/フィッシング通信検出 |
| Cloud DNS Logs | DNS based attacks |
| Firewall Rules Logs | 不正アクセス検出 |
| GKE Data Access Logs | コンテナ脅威検出 |

**重要**: サンプリングレートを高く、集約期間を短く設定することで検出遅延を最小化。

### 検出カテゴリ（抜粋）

| カテゴリ | 例 |
|---------|---|
| Exfiltration | BigQuery Data Exfiltration |
| Credential Access | External Member Added To Privileged Group |
| Persistence | IAM Anomalous Grant, New Geography |
| Initial Access | Log4j Compromise Attempt |
| Crypto Mining | 仮想通貨マイニング検出 |
| Malware | マルウェア通信検出 |

---

## Container Threat Detection (KTD)

**対象**: GKEクラスタ（バージョン確認必須）

| 検出タイプ | 説明 |
|-----------|------|
| Added Binary Executed | イメージ外バイナリ実行 |
| Added Library Loaded | イメージ外ライブラリロード |
| Malicious Script Executed | 機械学習による悪意あるBashスクリプト検出 |
| Reverse Shell | リバースシェル検出 |

**技術**: ゲストカーネルレベルの低レベル観測

---

## VM Threat Detection (VMTD)

**特徴**:
- ハイパーバイザーレベルスキャン（ゲストエージェント不要）
- ライブメモリ分析（VM停止不要）
- CPU使用量ゼロ（ゲスト側）

**検出対象**:
- 仮想通貨マイニングソフトウェア
- メモリハッシュマッチング
- YARAルールマッチング

**制約**: Confidential Computingでは動作不可

---

## Rapid Vulnerability Detection

**検出カテゴリ**:

| カテゴリ | 例 |
|---------|---|
| Weak Credentials | デフォルトパスワード等 |
| Exposed Interface | EXPOSED_GRAFANA_ENDPOINT, JUPYTER_NOTEBOOK_EXPOSED_UI |
| RCE Vulnerabilities | LOG4J_RCE, JENKINS_RCE, DRUPAL_RCE |

**自動検出対象**:
- ネットワークエンドポイント
- オープンポート
- インストールソフトウェアパッケージ

---

## Web Security Scanner (WSS)

### スキャンタイプ

| タイプ | 実行頻度 | 認証 | 用途 |
|--------|---------|------|------|
| Managed Scan | 週1回 | なし | 全プロジェクト自動スキャン |
| Custom Scan | 手動 | あり | 詳細スキャン（フォーム送信含む） |

**対応プラットフォーム**: App Engine、GKE、Compute Engine

### 検出項目（OWASP Top 10準拠）

- SQL_INJECTION
- XSS (Cross-Site Scripting)
- OUTDATED_LIBRARY
- CLEAR_TEXT_PASSWORD
- MIXED_CONTENT
- SERVER_SIDE_REQUEST_FORGERY

### ベストプラクティス

| プラクティス | 理由 |
|------------|------|
| テスト環境でスキャン | 本番データ変更リスク回避 |
| テストアカウント作成 | 機密データアクセス権限なし |
| `no-click` CSS適用 | 特定UI要素をスキャン対象外に |
| バックアップ取得 | スキャン前のデータ保護 |
| URL除外設定 | 危険な操作のURLパターン除外 |

---

## Cloud Asset Inventory (CAI)

### アセット検索

```bash
# 組織内全アセット一覧
gcloud scc assets list $ORGANIZATION_ID

# プロジェクトタイプのみフィルタ
FILTER="security_center_properties.resource_type=\"google.cloud.resourcemanager.Project\""
gcloud scc assets list $ORGANIZATION_ID --filter="$FILTER"

# 特定オーナーのプロジェクト検索
FILTER="security_center_properties.resource_type = \"google.cloud.resourcemanager.Project\" AND security_center_properties.resource_owners : \"user:someone@domain.com\""
gcloud scc assets list $ORGANIZATION_ID --filter="$FILTER"

# HTTP許可ファイアウォールルール検索
FILTER="security_center_properties.resource_type = \"google.compute.Firewall\" AND resource_properties.name =\"default-allow-http\""
gcloud scc assets list $ORGANIZATION_ID --filter="$FILTER"
```

### 時系列分析

**特定時点のアセット状態**:
```bash
READ_TIME=2019-02-28T07:00:06.861Z
gcloud scc assets list $ORGANIZATION_ID --read-time=$READ_TIME
```

**変更追跡**:
```bash
# 過去24時間の変更検出
COMPARE_DURATION=86400s
gcloud scc assets list $ORGANIZATION_ID \
  --read-time=$READ_TIME \
  --filter="$FILTER" \
  --compare-duration=$COMPARE_DURATION
```

**stateChange属性**:
- `ADDED`: 期間中に追加
- `REMOVED`: 期間中に削除
- `ACTIVE`: 両時点で存在

---

## BigQuery Export & Analysis

### アセットエクスポート

```sql
-- アセットタイプ別カウント
SELECT asset_type, COUNT(*) AS asset_count
FROM `PROJECT_ID.DATASET_ID.TABLE_NAME`
GROUP BY asset_type
ORDER BY asset_count DESC;

-- パブリックIP許可のCloud SQL検出
SELECT name
FROM `PROJECT_ID.DATASET_ID.TABLE_NAME`
JOIN UNNEST(org_policy) AS op
WHERE op.constraint = "constraints/sql.restrictPublicIp"
  AND (op.boolean_policy IS NULL OR op.boolean_policy.enforced = FALSE);
```

### IAMポリシー分析

```sql
-- Gmailアカウントへのアクセス権検出（データエクスフィルトレーションリスク）
SELECT name, asset_type, bindings.role
FROM `PROJECT_ID.DATASET_ID.TABLE_NAME`
JOIN UNNEST(iam_policy.bindings) AS bindings
JOIN UNNEST(bindings.members) AS principals
WHERE principals LIKE '%@gmail.com';

-- ユーザー直接権限付与検出（アンチパターン）
SELECT name, asset_type, bindings.role, members
FROM `PROJECT_ID.DATASET_ID.TABLE_NAME`
JOIN UNNEST(iam_policy.bindings) AS bindings
JOIN UNNEST(bindings.members) AS members
WHERE members LIKE "%@acme.com"
ORDER BY name;

-- サービスアカウントへの特権ロール付与検出
SELECT name, asset_type, bindings.role, members
FROM `PROJECT_ID.DATASET_ID.TABLE_NAME`
JOIN UNNEST(iam_policy.bindings) AS bindings
JOIN UNNEST(bindings.members) AS members
WHERE members LIKE "serviceAccount%"
ORDER BY name;
```

---

## Findings Export & Automation

### 継続的エクスポート（Pub/Sub）

```bash
# Pub/Sub継続エクスポート設定
gcloud scc notifications create my-notification \
  --organization=ORGANIZATION_ID \
  --pubsub-topic=projects/PROJECT_ID/topics/TOPIC_NAME \
  --filter='category="OPEN_FIREWALL"'
```

**サービスアカウント**: 自動作成
```
service-org-ORGANIZATION_ID@gcp-sa-scc-notification.iam.gserviceaccount.com
```

**役割**: `securitycenter.notificationServiceAgent`

### BigQueryエクスポート

```bash
# Findings BigQueryエクスポート設定
gcloud scc bqexports create my_export \
  --dataset=projects/PROJECT_ID/datasets/DATASET_ID \
  --organization=ORGANIZATION_ID \
  --filter='category="XSS_SCRIPTING"'

# エクスポート確認
gcloud scc bqexports get my_export \
  --organization=ORGANIZATION_ID
```

**データ遅延**: 初回15分、以降はほぼリアルタイム

---

## コンプライアンス監視

### サポート標準

| 標準 | バージョン |
|------|----------|
| CIS Benchmarks | 1.0 / 1.1 / 1.2（推奨） |
| PCI DSS | v3.2.1 |
| ISO | 27001 |
| NIST | 800-53 |
| OWASP | Top 10 |

**注意**: PCI/OWAPPマッピングは参考用。公式認証には別途監査必要。

---

## SOAR統合とレスポンス自動化

### アーキテクチャ

```
SCC Findings → Pub/Sub → SIEM/SOAR → 自動レスポンス
                             ↓
                  (Palo Alto Cortex/Splunk/Elastic/QRadar)
```

### レスポンスワークフロー

| ステップ | アクション | 自動化可否 |
|---------|----------|----------|
| 1. Export | SCC → SIEM | ✅ |
| 2. Alert | SIEM Alert生成 | ✅ |
| 3. Classification | SOC分析・分類 | 🔶（ML支援） |
| 4. Ticket | ITSM起票・割り当て | ✅ |
| 5. Remediation | 修正実施 | 🔶（承認必要） |
| 6. Prevention | ポリシー更新 | ❌ |

---

## ベストプラクティス

### ログ管理

| プラクティス | 実装 |
|------------|------|
| 適切な保存先選択 | アーカイブ→Cloud Storage、分析→BigQuery |
| アクセス制御 | 最小権限、Bucket Policy Only |
| 機密データ除去 | DLP統合（Dataflowパイプライン） |
| 定期レビュー | 監査ログの週次/月次レビュー |

### SCC運用

| プラクティス | 実装 |
|------------|------|
| Data Access Logs有効化 | 重要サービスでデータアクセス記録 |
| ETD追加ログ有効化 | VPC Flow/DNS/Firewall Logs |
| コスト監視 | 高頻度サンプリングによるIngestion料金 |
| リアルタイム検出 | SHA Real-time Scan有効化 |

### セキュリティポスチャ

| レイヤー | ツール | 対象 |
|---------|--------|------|
| Configuration | SHA | 設定ミス |
| Vulnerability | RVD, VM Manager, WSS | 脆弱性 |
| Threat | ETD, KTD, VMTD | リアルタイム脅威 |
| Compliance | CIS/PCI/ISO | 標準準拠 |

---

## 料金考慮事項

### Cloud Logging料金

| ログタイプ | 料金（$/GiB） | デフォルト保持期間 |
|----------|--------------|----------------|
| Admin Activity | $0.50 | 400日 |
| Data Access | $0.50 | 30日 |
| VPC Flow Logs | $0.50 | 30日 |
| カスタム保持 | +$0.01/GiB/月 | 設定次第 |

### SCC料金

| Tier | 料金モデル |
|------|----------|
| Standard | 無料 |
| Premium | 組織/プロジェクト単位課金 |

**注意**: ログIngestionはCloud Logging料金（SCC自体はスキャン無料）
