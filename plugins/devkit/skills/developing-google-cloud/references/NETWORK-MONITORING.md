# GCP ネットワーク監視・可観測性リファレンス

GCPネットワークの監視・トラブルシューティング・フォレンジック分析のためのサービスと設定パターン。

---

## Operations Suite 概要

GCP Operations Suite（旧 Stackdriver）はネットワーク監視の中核サービス群。

| サービス | 用途 | 主な対象 |
|---------|------|---------|
| **Cloud Logging** | ログ管理・検索・エクスポート | VPC Flow Logs、Firewall Logs、Audit Logs |
| **Cloud Monitoring** | メトリクス収集・アラート | ヒットカウント、帯域使用量、レイテンシ |
| **Cloud Trace** | アプリケーションレイテンシ分析 | リクエストトレース、依存関係マッピング |

---

## VPC Flow Logs

### 概要

VPC Flow Logsはサブネット単位で有効化し、Compute EngineインスタンスやGKEノードのネットワークトラフィックサンプルを収集する。

**主なユースケース:**
- アプリケーションへのアクセス元調査
- Cloud Armor ブラックリスト用IP収集
- ネットワークフォレンジック・セキュリティ分析
- トラフィックパターン分析・キャパシティプランニング

### 有効化

```bash
# サブネット作成時に有効化
gcloud compute networks subnets create my-subnet \
  --network=my-vpc \
  --region=us-central1 \
  --range=10.128.0.0/24 \
  --enable-flow-logs

# 既存サブネットで有効化
gcloud compute networks subnets update my-subnet \
  --region=us-central1 \
  --enable-flow-logs
```

### Flow Logフィールド（jsonPayload.connection）

| フィールド | 説明 |
|-----------|------|
| `src_ip` | 送信元IPアドレス |
| `dest_ip` | 宛先IPアドレス |
| `src_port` | 送信元ポート |
| `dest_port` | 宛先ポート |
| `protocol` | トランスポートプロトコル（TCP/UDP/ICMP） |

### Logs Explorerクエリ例

```
# リソースタイプ + ログ名でフィルタ
resource.type="gce_subnetwork"
logName="projects/PROJECT_ID/logs/compute.googleapis.com%2Fvpc_flows"

# 特定の送信元IPでフィルタ
jsonPayload.connection.src_ip="203.0.113.10"

# 特定のVMへのトラフィック
jsonPayload.dest_instance.vm_name="web-server-1"
```

### コスト・パフォーマンスの注意

- VPC Flow Logsはパフォーマンスに影響しない（サンプリングベース）
- 大量のログが生成されるため、コスト増加に注意
- 必要なサブネットのみ有効化し、不要時は無効化

---

## ログエクスポート（Logs Router）

Cloud Loggingのログを外部サービスにエクスポートするにはLogs Routerの **Sink** を設定する。

### Sink宛先

| 宛先 | ユースケース |
|------|------------|
| **BigQuery** | SQL分析・レポーティング・ML予測 |
| **Cloud Storage** | 長期アーカイブ・コンプライアンス |
| **Pub/Sub** | リアルタイムストリーミング・Splunk等外部連携 |
| **Logging バケット** | ログ保持期間のカスタマイズ |

### BigQueryへのエクスポート設定

```bash
# Sink作成（VPC Flow LogsをBigQueryにエクスポート）
gcloud logging sinks create vpc-flow-sink \
  bigquery.googleapis.com/projects/PROJECT_ID/datasets/bq_vpcflows \
  --log-filter='resource.type="gce_subnetwork" AND logName="projects/PROJECT_ID/logs/compute.googleapis.com%2Fvpc_flows"'
```

**ベストプラクティス:** BigQueryではパーティションテーブルを使用し、クエリパフォーマンス向上とコスト削減を実現する。

---

## Firewall Rules Logging

### 有効化

ファイアウォールルール単位でログを有効化する。

```bash
# 既存ルールでログ有効化
gcloud compute firewall-rules update allow-http \
  --enable-logging

# メタデータ付きで有効化（詳細情報取得）
gcloud compute firewall-rules update allow-http \
  --enable-logging \
  --logging-metadata=INCLUDE_ALL_METADATA
```

### ログフィールド

**基本フィールド（常に記録）:**

| フィールド | 説明 |
|-----------|------|
| connection | 送信元/宛先IP・ポート・プロトコル（5タプル） |
| disposition | ALLOWED / DENIED |
| rule_details.reference | ルール参照名 |

**メタデータフィールド（INCLUDE_ALL_METADATA時）:**

| カテゴリ | フィールド | 説明 |
|---------|-----------|------|
| **rule_details** | priority, action, direction, source_range[], destination_range[], source_tag[], target_tag[] | ルール定義の詳細 |
| **instance** | project_id, vm_name, region, zone | 対象VMの情報 |
| **vpc** | project_id, vpc_name, subnetwork_name | ネットワーク情報 |
| **remote_instance** | （instanceと同構造） | リモートVMの情報 |
| **remote_location** | continent, country, region, city | 外部エンドポイントの地理情報 |

### Cleanupルール（推奨パターン）

明示的に許可されていない全トラフィックをログ付きで拒否する「Cleanupルール」を最低優先度で設定する。

```bash
# Cleanupファイアウォールルール
gcloud compute firewall-rules create cleanup-rule \
  --network=my-vpc \
  --action=DENY \
  --direction=INGRESS \
  --rules=all \
  --source-ranges=0.0.0.0/0 \
  --target-tags=web-server \
  --priority=65534 \
  --enable-logging
```

**用途:** 潜在的な攻撃者のIP検出 → Cloud Armorセキュリティポリシーのブラックリストに追加

### Logs Explorerクエリ構文

```
# 特定のファイアウォールルールのログを検索
jsonPayload.rule_details.reference:("network:VPC_NAME/firewall:RULE_NAME")

# 例: allow-httpルールのログ
jsonPayload.rule_details.reference:("network:my-vpc/firewall:allow-http")
```

### メタデータ有効化の判断

| 状況 | 推奨 |
|------|------|
| 基本的なトラフィック監視 | 基本フィールドのみ（ストレージ節約） |
| セキュリティ分析・インシデント調査 | メタデータ含む（全フィールド） |
| 初期構築時 | 基本のみ → 必要に応じてメタデータ追加 |

---

## VPC Audit Logs

Google Cloud Audit Logsの一部として、VPC操作の監査ログが記録される。

### 監査ログタイプ

| ログタイプ | デフォルト有効 | 記録内容 | 例 |
|-----------|-------------|---------|-----|
| **Admin Activity** | 常時有効 | 構成・メタデータの変更操作 | サブネット作成、ファイアウォールルール変更 |
| **System Event** | 常時有効 | GCPによる自動管理操作 | MIGオートスケーリング |
| **Data Access** | デフォルト無効 | メタデータ読み取り・ユーザーデータ操作 | ファイアウォールルール一覧取得 |
| **Policy Denied** | 常時有効 | セキュリティポリシー違反によるアクセス拒否 | IAM権限不足によるVPC操作拒否 |

### 監査ログ閲覧に必要なIAMロール

| ログタイプ | 必要なロール |
|-----------|-------------|
| Admin Activity | `roles/viewer` または `roles/logging.viewer` |
| Data Access | `roles/logging.privateLogViewer`（プロジェクトオーナー） |

---

## Packet Mirroring

### 概要

Packet MirroringはVPC Flow Logsとは異なり、**全パケットのペイロードとヘッダーを完全にコピー**する。ネットワークタップやSPANセッションに相当する機能。

### VPC Flow Logs vs Packet Mirroring

| 特性 | VPC Flow Logs | Packet Mirroring |
|------|--------------|-----------------|
| データ | サンプリングベースのフローメタデータ | 全パケットの完全コピー（ペイロード含む） |
| パフォーマンス影響 | なし | **帯域幅・レイテンシに影響あり** |
| ユースケース | 一般的なモニタリング・分析 | IDS/IPS、深層パケット解析、トラブルシューティング |
| コスト | 低（ログストレージのみ） | 高（帯域幅課金、特にゾーン間） |
| 推奨 | 常時有効化可能 | **必要時のみ有効化** |

### Packet Mirroringポリシーの構成要素

| 要素 | 説明 | 制約 |
|------|------|------|
| **Region** | ポリシー適用リージョン | - |
| **VPC network** | 対象VPCネットワーク | - |
| **Mirrored source** | ミラーリング対象（サブネット/インスタンス/タグ） | - |
| **Collector** | ミラートラフィックの送信先（内部LB + バックエンドVM） | ソースと同一リージョン必須 |
| **Filter** | ミラー対象のトラフィックフィルタ | TCP/UDP/ICMPのみ |

### 設定例

```bash
# Packet Mirroringポリシー作成
gcloud compute packet-mirrorings create my-mirroring-policy \
  --region=us-west4 \
  --network=gcp-net \
  --mirrored-subnets=web-subnet \
  --collector-ilb=ids-forwarding-rule \
  --filter-cidr-ranges=172.21.0.0/24 \
  --filter-protocols=tcp,icmp

# IDS VM上でトラフィックキャプチャ
sudo tcpdump -i ens4 -n "(icmp or port 80) and net 172.21.0.0/24"
```

### ベストプラクティス

- **常時有効にしない** - 帯域幅コストとレイテンシ影響のため、調査・トラブルシューティング時のみ有効化
- **フィルタを活用** - 必要なトラフィックのみミラーリングしてコストを抑制
- **コレクターは同一リージョン** - ゾーン間通信は許可されるがコスト増加
- **IDS/IPSとの統合** - コレクターとしてIDS VM群を内部LB配下に配置

---

## ユーザー確認の原則（AskUserQuestion）

以下の判断が必要な場合はAskUserQuestionツールで確認すること。

### 確認すべき場面

- **VPC Flow Logs vs Packet Mirroring**: ユースケースに応じた選択（一般監視 vs 深層分析）
- **ログエクスポート先**: BigQuery（分析）vs Cloud Storage（アーカイブ）vs Pub/Sub（リアルタイム）
- **メタデータ有効化**: Firewall Logsのメタデータ含有の要否
- **Packet Mirroringフィルタ**: ミラー対象のトラフィック範囲

### 確認不要な場面

- Cleanupファイアウォールルールの設定（セキュリティベストプラクティス）
- Admin Activity監査ログの有効化（常時有効、変更不可）
- VPC Flow LogsのLogs Explorerでの閲覧（標準操作）
