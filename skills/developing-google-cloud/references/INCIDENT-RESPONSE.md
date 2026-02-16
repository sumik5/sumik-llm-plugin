# Incident Response & Forensics in GCP

GCPにおけるインシデント対応・フォレンジック分析の実践的リファレンス。クラウドネイティブ環境での迅速な検出・封じ込め・証拠保全・復旧を実現するGCPネイティブツールとワークフローを体系的にカバー。

---

## インシデント対応の6フェーズ

### IRライフサイクル

| フェーズ | 目的 | GCPツール・アクション |
|---------|------|---------------------|
| **1. 準備 (Preparation)** | IR計画策定、ロール定義、ツール準備 | IAM設定、ログ有効化、SCC設定、Runbookドキュメント |
| **2. 検出 (Detection)** | 脅威・異常の検出、アラート生成 | SCC、Cloud Monitoring、Chronicle、Log Analytics |
| **3. 封じ込め (Containment)** | 被害拡大防止、リソース分離 | ファイアウォールルール、IAM停止、VM/インスタンス停止 |
| **4. 根絶 (Eradication)** | 脅威の根本原因除去 | 不正アカウント削除、マルウェア駆除、脆弱性パッチ |
| **5. 復旧 (Recovery)** | サービス正常化、監視強化 | クリーンスナップショットからの復元、段階的トラフィック復旧 |
| **6. 事後分析 (Lessons Learned)** | ポストモーテム、改善策実施 | Runbook更新、予防措置の実装、チーム振り返り |

---

## 共有責任モデルとIR範囲

### 責任分界点

| レイヤー | Google責任 | 顧客責任 |
|---------|----------|---------|
| **物理インフラ** | ✅ データセンターセキュリティ、物理破壊対策 | ❌ |
| **ネットワークインフラ** | ✅ DDoS防御（Googleレベル）、物理ネットワーク | ❌ |
| **コンピュートサービス** | ✅ ホストOS、ハイパーバイザー | ❌ |
| **ゲストOS・ワークロード** | ❌ | ✅ パッチ、設定、アプリケーションセキュリティ |
| **IAM・認証** | ❌ | ✅ ユーザー管理、ロール割り当て、MFA設定 |
| **データ保護** | ✅ 暗号化基盤（DEK） | ✅ CMEK管理、データ分類、アクセス制御 |
| **監査ログ** | ✅ ログ基盤提供 | ✅ ログ有効化、保持期間設定、分析 |

**重要**: 顧客責任範囲内のインシデント（IAM侵害、設定ミス、アプリ脆弱性）は顧客が主体的に対応。Google Supportは助言のみ。

---

## インシデント対応計画の策定

### 必須コンポーネント

| コンポーネント | 内容 |
|-------------|------|
| **ロールと責任** | IR Lead、Analyst、Communicator、Technical Lead、Legal/Compliance |
| **エスカレーションパス** | 低/中/高/Critical重大度別の通知先・承認フロー |
| **通信チャネル** | Slack/PagerDuty/email、戦争部屋（War Room）設定 |
| **Runbook** | シナリオ別対応手順（IAM侵害、データ流出、ランサムウェア等） |
| **Break-glass手順** | 緊急時の特権アクセス手順（承認プロセスバイパス） |
| **証拠保全ポリシー** | スナップショット取得、ログエクスポート、Chain of Custody |

### エスカレーションマトリクス

| 重大度 | 定義 | 対応時間 | 通知先 |
|-------|------|---------|--------|
| **Critical** | 本番障害、データ流出、ランサムウェア | 15分以内 | CISO、CTO、IR Lead、全エンジニア、PR |
| **High** | 広範囲な設定ミス、特権アカウント侵害 | 1時間以内 | Security Team、Platform Lead、IR Analyst |
| **Medium** | 限定的な設定ミス、低権限アカウント侵害 | 4時間以内 | Security Analyst、担当チーム |
| **Low** | 軽微な設定ミス、情報収集活動 | 24時間以内 | Security Analyst |

### IAM条件付きポリシーでのIR準備

**インシデント中に外部IP作成を禁止**:
```json
{
  "bindings": [
    {
      "role": "roles/compute.instanceAdmin.v1",
      "members": ["group:developers@company.com"],
      "condition": {
        "title": "Block external IP during incident",
        "expression": "!has(request.resource.networkInterfaces[0].accessConfigs)"
      }
    }
  ]
}
```

**特定IPレンジからのサービスアカウント利用制限**:
```json
{
  "condition": {
    "title": "Restrict SA usage to corporate IP",
    "expression": "origin.ip in ['203.0.113.0/24', '198.51.100.0/24']"
  }
}
```

---

## GCPログによるフォレンジック分析

### 主要ログタイプ

| ログタイプ | 用途 | 保持期間（デフォルト） |
|----------|------|---------------------|
| **Admin Activity Logs** | API呼び出し、設定変更、権限変更 | 400日（無効化不可） |
| **Data Access Logs** | データ読み取り・書き込み（BigQuery/GCS/Cloud SQL） | 30日（要有効化） |
| **System Event Logs** | システム生成イベント（VMメンテナンス等） | 400日 |
| **VPC Flow Logs** | ネットワークトラフィック（5-tuple + バイト数） | 30日 |
| **Firewall Rules Logs** | ファイアウォールルール適用結果 | 30日 |
| **Cloud DNS Logs** | DNS クエリ/レスポンス | 30日 |

### フォレンジック分析クエリ

**不正なIAM権限変更検出**:
```
resource.type="project"
protoPayload.methodName=~"SetIamPolicy"
protoPayload.authenticationInfo.principalEmail !~ "@company\.com$"
```

**外部IPからのCompute Engine SSH接続**:
```
resource.type="gce_instance"
protoPayload.methodName="compute.instances.start"
protoPayload.request.networkInterfaces[0].accessConfigs[0].natIP != null
```

**BigQueryデータエクスフィルトレーション**:
```
resource.type="bigquery_resource"
protoPayload.methodName="jobservice.insert"
protoPayload.serviceData.jobInsertRequest.resource.jobConfiguration.extract.destinationUris !~ "gs://company-bucket"
severity="NOTICE"
```

### VPC Flow Logsフォレンジック分析

**特定IPへの大量データ転送検出**（BigQuery）:
```sql
SELECT
  jsonPayload.connection.src_ip,
  jsonPayload.connection.dest_ip,
  SUM(CAST(jsonPayload.bytes_sent AS INT64)) AS total_bytes
FROM `PROJECT_ID.DATASET.vpc_flows_*`
WHERE
  DATE(_PARTITIONTIME) = CURRENT_DATE()
  AND jsonPayload.connection.dest_ip NOT IN (
    -- 内部IPレンジ
    SELECT ip FROM UNNEST(['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']) AS ip
  )
GROUP BY 1, 2
HAVING total_bytes > 10737418240  -- 10GB以上
ORDER BY total_bytes DESC;
```

**異常なポートスキャン検出**:
```sql
SELECT
  jsonPayload.connection.src_ip,
  COUNT(DISTINCT jsonPayload.connection.dest_port) AS unique_ports,
  COUNT(*) AS connection_attempts
FROM `PROJECT_ID.DATASET.vpc_flows_*`
WHERE
  DATE(_PARTITIONTIME) = CURRENT_DATE()
  AND jsonPayload.reporter = 'DEST'
GROUP BY 1
HAVING unique_ports > 100 AND connection_attempts > 500
ORDER BY unique_ports DESC;
```

---

## リソース分離と影響範囲制限

### 迅速な封じ込め戦略

| リソース | 封じ込めアクション | gcloud CLIコマンド |
|---------|-----------------|------------------|
| **Compute Engine VM** | インスタンス停止 | `gcloud compute instances stop` |
| **GKE Pod** | Pod削除/Namespace隔離 | `kubectl delete pod` or `kubectl patch namespace` |
| **Cloud Function** | 関数無効化 | `gcloud functions delete` or IAM権限削除 |
| **Cloud Run** | サービス削除/トラフィック0% | `gcloud run services delete` |
| **Service Account** | キー削除、IAM権限削除 | `gcloud iam service-accounts keys delete` |
| **Cloud Storage** | バケットACL削除 | `gsutil iam ch -d allUsers:objectViewer` |

### ファイアウォールルールによるネットワーク分離

**侵害されたVMからの全外部通信をブロック**:
```bash
# 特定インスタンスタグを持つVMからのEgressを拒否
gcloud compute firewall-rules create block-compromised-egress \
  --direction=EGRESS \
  --priority=100 \
  --network=default \
  --action=DENY \
  --rules=all \
  --destination-ranges=0.0.0.0/0 \
  --target-tags=compromised-instance
```

**侵害されたVMへのIngressをブロック**（IR担当者のIPのみ許可）:
```bash
gcloud compute firewall-rules create block-compromised-ingress \
  --direction=INGRESS \
  --priority=100 \
  --network=default \
  --action=DENY \
  --rules=all \
  --source-ranges=0.0.0.0/0 \
  --target-tags=compromised-instance

# IR担当者のIPのみ許可（優先度を高く）
gcloud compute firewall-rules create allow-ir-access \
  --direction=INGRESS \
  --priority=50 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=203.0.113.10/32 \
  --target-tags=compromised-instance
```

### 組織ポリシーによる動的制限

**インシデント中に外部IP作成を組織全体で禁止**:
```bash
# 組織ポリシー（compute.vmExternalIpAccess）で外部IP禁止
gcloud org-policies set-policy /tmp/deny-external-ip.yaml \
  --organization=ORGANIZATION_ID
```

`/tmp/deny-external-ip.yaml`:
```yaml
constraint: constraints/compute.vmExternalIpAccess
listPolicy:
  deniedValues:
    - "*"
```

---

## 検疫と証拠保全

### 証拠保全の原則

| 原則 | 説明 | GCP実装 |
|------|------|---------|
| **不変性（Immutability）** | 証拠の改ざん防止 | スナップショット取得、Object Versioning有効化 |
| **Chain of Custody** | 証拠の取り扱い記録 | Cloud Audit Logs、タイムスタンプ |
| **完全性（Integrity）** | ハッシュ検証 | Checksum記録（`gsutil hash`） |
| **隔離（Isolation）** | 証拠環境の分離 | 専用プロジェクト/VPCへの移動 |

### Compute Engine VMの証拠保全

**1. ディスクスナップショット取得**:
```bash
# 侵害されたVMのディスクスナップショット作成
gcloud compute disks snapshot DISK_NAME \
  --snapshot-names=forensic-snapshot-$(date +%Y%m%d-%H%M%S) \
  --zone=us-central1-a \
  --description="Forensic evidence for incident INC-2024-001"
```

**2. スナップショットからディスク作成（フォレンジック用）**:
```bash
gcloud compute disks create forensic-disk-readonly \
  --source-snapshot=forensic-snapshot-20240215-143000 \
  --zone=us-central1-a \
  --type=pd-standard
```

**3. フォレンジック分析用VMにアタッチ**:
```bash
# Read-onlyでアタッチ
gcloud compute instances attach-disk forensic-vm \
  --disk=forensic-disk-readonly \
  --mode=ro \
  --zone=us-central1-a
```

**4. ディスクイメージのハッシュ取得**:
```bash
# VMにSSHしてディスクイメージのSHA256ハッシュ取得
sudo dd if=/dev/sdb bs=4M | sha256sum > /tmp/disk-evidence.sha256
```

### Cloud Storageバケットの証拠保全

**1. バケット全体をアーカイブプロジェクトにコピー**:
```bash
gsutil -m cp -r gs://compromised-bucket gs://forensic-archive-bucket/incident-INC-2024-001/
```

**2. Object Versioningで削除されたオブジェクトを保全**:
```bash
# バージョニング有効化
gsutil versioning set on gs://compromised-bucket

# 削除されたオブジェクトを含む全バージョンをリスト
gsutil ls -a gs://compromised-bucket
```

**3. Bucket Lockで証拠改ざん防止**:
```bash
gsutil retention set 7d gs://forensic-archive-bucket
gsutil retention lock gs://forensic-archive-bucket
```

---

## 検疫 vs ライブデバッグ

### 判断基準

| 状況 | 推奨アプローチ | 理由 |
|------|-------------|------|
| 攻撃者がアクティブ | **検疫（Quarantine）** | 証拠改ざんリスク、被害拡大防止 |
| 本番サービス影響大 | **ライブデバッグ** | サービス継続優先、平行して証拠保全 |
| 法的訴訟の可能性 | **検疫** | Chain of Custody確保、証拠完全性保持 |
| 根本原因不明 | **ライブデバッグ** | 動的解析で原因特定後に検疫 |

### 検疫（Quarantine）手順

```bash
# 1. ファイアウォールで完全隔離
gcloud compute firewall-rules create quarantine-complete-isolation \
  --direction=INGRESS \
  --priority=1 \
  --network=default \
  --action=DENY \
  --rules=all \
  --target-tags=quarantine

gcloud compute firewall-rules create quarantine-egress-block \
  --direction=EGRESS \
  --priority=1 \
  --network=default \
  --action=DENY \
  --rules=all \
  --destination-ranges=0.0.0.0/0 \
  --target-tags=quarantine

# 2. インスタンスにquarantineタグを付与
gcloud compute instances add-tags INSTANCE_NAME \
  --tags=quarantine \
  --zone=us-central1-a

# 3. スナップショット取得後、インスタンス停止
gcloud compute disks snapshot DISK_NAME --snapshot-names=quarantine-snapshot
gcloud compute instances stop INSTANCE_NAME --zone=us-central1-a
```

---

## GCPフォレンジックツール活用

### Forseti Security（廃止 → SCC移行）

**注意**: Forseti Securityは2021年に廃止。機能はSCC Premiumに統合済み。

### Cloud Asset Inventory（CAI）でのタイムトラベル

**特定時点のIAMポリシー状態を取得**:
```bash
# 2024年2月15日時点のIAMポリシーを取得
gcloud asset search-all-iam-policies \
  --scope=projects/PROJECT_ID \
  --read-time=2024-02-15T14:00:00Z \
  --format=json > iam-policy-snapshot-20240215.json
```

### Packet Mirroring（一時的フォレンジック）

**深層パケット解析が必要な場合のみ有効化**:
```bash
# Packet Mirroringポリシー作成（コスト注意）
gcloud compute packet-mirrorings create forensic-mirror \
  --region=us-central1 \
  --network=default \
  --mirrored-subnets=suspicious-subnet \
  --collector-ilb=forensic-collector-ilb
```

**注意**: 長期間の有効化は高コスト。インシデント調査時のみ一時的に使用。

---

## 実際のインシデント対応ケーススタディ

### ケース1: IAM侵害（サービスアカウントキー漏洩）

**検出**:
- SCC ETDが `Leaked Service Account Key` Findingを生成
- Cloud Monitoring Alertが発火

**封じ込め**:
```bash
# 1. 侵害されたサービスアカウントキーを即座に削除
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=SA_EMAIL

# 2. サービスアカウントのIAM権限を一時停止
gcloud projects remove-iam-policy-binding PROJECT_ID \
  --member=serviceAccount:SA_EMAIL \
  --role=roles/editor
```

**根絶**:
- GitHub/GitLabリポジトリから漏洩キーを削除
- Secret Scannerで他の漏洩を確認

**復旧**:
- 新しいサービスアカウントキーを作成し、Secret Managerに保存
- アプリケーションを新しいキーで再デプロイ

**事後分析**:
- Runbook更新: Secret Manager必須化、キーのローテーション自動化

---

### ケース2: 不正なデータエクスフィルトレーション

**検出**:
- SCC ETDが `BigQuery Data Exfiltration` Findingを検出
- 外部ドメインへの大量データエクスポート

**封じ込め**:
```bash
# 1. 侵害されたユーザーアカウントのBigQueryアクセスを削除
gcloud projects remove-iam-policy-binding PROJECT_ID \
  --member=user:compromised-user@example.com \
  --role=roles/bigquery.dataViewer

# 2. VPC Service Controls境界を適用（外部エクスポート禁止）
gcloud access-context-manager perimeters create forensic-perimeter \
  --title="Incident Response Perimeter" \
  --resources=projects/PROJECT_NUMBER \
  --restricted-services=bigquery.googleapis.com \
  --policy=POLICY_ID
```

**フォレンジック分析**:
```sql
-- BigQuery Audit Logsでエクスポートされたデータを特定
SELECT
  timestamp,
  protopayload_auditlog.authenticationInfo.principalEmail,
  protopayload_auditlog.resourceName,
  protopayload_auditlog.servicedata_v1_bigquery.jobInsertRequest.resource.jobConfiguration.extract.destinationUris
FROM `PROJECT_ID.DATASET._AllLogs`
WHERE
  protopayload_auditlog.methodName = 'jobservice.insert'
  AND protopayload_auditlog.servicedata_v1_bigquery.jobInsertRequest.resource.jobConfiguration.extract IS NOT NULL
  AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
ORDER BY timestamp DESC;
```

---

## ポストモーテムと改善

### ポストモーテムテンプレート

```markdown
# Incident Post-Mortem: [INC-YYYY-NNNN]

## 概要
- **発生日時**: 2024-02-15 14:00 UTC
- **検出日時**: 2024-02-15 14:15 UTC
- **解決日時**: 2024-02-15 16:30 UTC
- **影響範囲**: Production Project (project-id), 10 Compute Engine VMs
- **重大度**: High

## タイムライン
| 時刻 | イベント | 担当者 |
|-----|---------|--------|
| 14:00 | 不正なIAMポリシー変更検出 | SCC |
| 14:15 | IR Teamがアラート受信 | Security Analyst |
| 14:20 | 侵害されたサービスアカウントキーを削除 | IR Lead |
| ... | ... | ... |

## 根本原因
- サービスアカウントキーがGitHubリポジトリにハードコード
- Secret Scannerが無効化されていた

## 影響
- データエクスフィルトレーション: なし（早期検出）
- サービスダウンタイム: 15分（アプリケーション再起動）

## 実施した対策
- [x] 侵害されたキーを削除
- [x] 新しいキーをSecret Managerに移行
- [x] GitHub Secret Scannerを有効化

## 今後の予防策
- [ ] Secret Manager必須化のOrg Policy適用
- [ ] サービスアカウントキーのローテーション自動化
- [ ] IR Runbookの更新
- [ ] 四半期IR訓練の実施

## 学んだ教訓
- SCC ETDの早期検出が被害を最小化
- Secret Managerへの移行が遅れていた
```

### 継続的改善プロセス

| アクティビティ | 頻度 | 目的 |
|-------------|------|------|
| **Tabletop Exercise** | 四半期 | シナリオベースのIR訓練（実環境操作なし） |
| **Red Team Exercise** | 年1回 | 攻撃シミュレーション、検出能力評価 |
| **Runbook更新** | インシデント後即座 | 新しい脅威パターンへの対応手順追加 |
| **ツールチェーン見直し** | 半年 | 新しいGCPセキュリティ機能の導入検討 |

---

## ベストプラクティス

| プラクティス | 実装 |
|------------|------|
| 事前準備の徹底 | Data Access Logs有効化、SCC Premium有効化、IAM最小権限 |
| 自動化の推進 | Pub/Sub + Cloud Functions で自動封じ込め |
| 証拠保全の標準化 | スナップショット自動取得、Chain of Custody記録 |
| コミュニケーション明確化 | Slack/PagerDutyエスカレーションパス、War Room設定 |
| 定期訓練 | 四半期Tabletop Exercise、年次Red Team |
| ポストモーテム文化 | Blame-freeな振り返り、改善策の追跡 |

---

## 料金考慮事項

| 項目 | コスト影響 |
|------|----------|
| スナップショット | 保持期間に応じた課金（圧縮率高い） |
| VPC Flow Logs | 大量トラフィック環境では高額（サンプリング推奨） |
| Packet Mirroring | **非常に高額**（調査時のみ一時的に有効化） |
| Cloud Logging | Ingestion料金（$0.50/GiB）、保持期間延長で追加料金 |
| BigQuery（ログ分析） | オンデマンドクエリ料金（定額スロット購入でコスト予測可能） |
