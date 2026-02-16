# GCPデータ保護リファレンス

Cloud KMS、Cloud DLP、Secret Managerを用いたGCPデータ保護の実践ガイド。暗号化オプション選択、鍵管理、機密データ検出・非識別化、シークレット管理のベストプラクティス。

---

## Cloud KMS概要

**FIPS 140-2準拠:** SOFTWARE (L1) / HSM (L3)

**鍵階層:**
```
Root KMS Master Key (Google内部)
  └─ KMS Master Key
      └─ KEK (顧客管理可能)
          └─ DEK (Google管理)
```

## 暗号化オプション選択

| オプション | 鍵管理 | 適用範囲 | ユースケース |
|----------|-------|---------|------------|
| **GMEK** | Google自動 | 全サービス | デフォルト暗号化 |
| **CMEK** | 顧客管理 | CMEK統合サービス | コンプライアンス要件、鍵無効化 |
| **CSEK** | 顧客提供 | Cloud Storage, Compute Engine | 鍵をGoogle側で保存したくない |
| **EKM** | 外部パートナー | 限定サービス | 鍵をCloud外で管理 |

### 暗号化オプション詳細比較

#### CSEK (Customer-Supplied Encryption Keys) 深掘り

**アーキテクチャ:**
```
User → AES-256鍵生成 → Base64エンコード → GCS/GCE API送信（TLS） → Google暗号化 → DEK破棄（メモリのみ）
```

**利点:**
- 鍵をGoogle側で保存しない（完全な鍵制御）
- Cloud KMS不要（コスト削減）
- 追加費用なし

**制約:**
| 制約項目 | 詳細 |
|---------|------|
| **対応サービス** | Cloud Storage、Compute Engine（Persistent Disk）のみ |
| **既存リソース適用** | 不可（新規作成時のみ） |
| **Console操作** | 不可（API/gcloud/gsutil必須） |
| **Transfer Service** | 非対応 |
| **Dataflow** | 非対応 |
| **鍵ローテーション** | 手動（全オブジェクト再暗号化必要） |
| **鍵紛失** | データ復旧不可（完全喪失） |

**実装例（Cloud Storage）:**
```bash
# AES-256鍵生成（32バイト = 256ビット）
openssl rand -base64 32 > aes-key.txt

# gsutil設定（.boto）
cat >> ~/.boto <<EOF
[GSUtil]
encryption_key = $(cat aes-key.txt)
EOF

# オブジェクトアップロード（CSEKで暗号化）
gsutil cp sensitive-file.txt gs://BUCKET_NAME/

# 鍵ローテーション（再暗号化）
gsutil rewrite -k gs://BUCKET_NAME/sensitive-file.txt
```

**実装例（Compute Engine Disk）:**
```bash
# ディスク作成時にCSEK指定
gcloud compute disks create my-encrypted-disk \
  --size=100GB \
  --csek-key-file=disk-key.json \
  --zone=us-central1-a

# disk-key.jsonフォーマット
cat > disk-key.json <<EOF
[
  {
    "uri": "https://www.googleapis.com/compute/v1/projects/PROJECT_ID/zones/us-central1-a/disks/my-encrypted-disk",
    "key": "$(openssl rand -base64 32)",
    "key-type": "raw"
  }
]
EOF
```

#### Cloud HSM 深掘り

**FIPS 140-2 Level 3準拠の物理セキュリティ:**
- タンパー検知・応答（物理侵入で自動鍵破壊）
- Googleデータセンター内の専用ハードウェア
- 地域バインド（鍵が物理的に特定地域に固定）

**Cloud KMS HSMとの統合:**
```bash
# HSM保護レベルでKMS鍵作成
gcloud kms keys create my-hsm-key \
  --keyring=my-keyring \
  --location=us-central1 \
  --purpose=encryption \
  --protection-level=HSM

# 既存鍵をHSMに移行（インポート）
gcloud kms keys versions import \
  --import-job=my-import-job \
  --location=us-central1 \
  --keyring=my-keyring \
  --key=my-hsm-key \
  --algorithm=google-symmetric-encryption \
  --target-key-file=wrapped-key.bin \
  --public-key-file=import-job-pub.pem
```

**Attestation検証（鍵がHSM内で生成されたことの証明）:**
```python
from google.cloud import kms

client = kms.KeyManagementServiceClient()
key_version_name = "projects/PROJECT_ID/locations/us-central1/keyRings/my-keyring/cryptoKeys/my-hsm-key/cryptoKeyVersions/1"

attestation = client.get_crypto_key_version(name=key_version_name).attestation
print(f"Attestation format: {attestation.format}")
print(f"Attestation content: {attestation.content}")
# 公開鍵で署名検証してHSM生成を確認
```

**ユースケース比較:**
| シナリオ | CMEK (SOFTWARE) | Cloud HSM | 理由 |
|---------|----------------|----------|------|
| **一般的コンプライアンス（GDPR、HIPAA）** | ✅ 推奨 | 過剰 | Software保護で十分 |
| **金融（PCI-DSS Level 1）** | ⚠️ | ✅ 推奨 | 物理セキュリティ要件 |
| **政府・防衛** | ❌ | ✅ 必須 | FIPS 140-2 Level 3要求 |
| **コスト重視** | ✅ | ❌ | HSMは追加費用 |
| **鍵生成証明必要** | ❌ | ✅ | Attestation機能 |

### CMEKセットアップ

```bash
gcloud kms keyrings create KEY_RING --location=LOCATION
gcloud kms keys create KEY --keyring=KEY_RING --location=LOCATION --purpose=encryption
# roles/cloudkms.cryptoKeyEncrypterDecrypter付与
```

**注意:** 鍵無効化/破棄前にデータ再暗号化確認

### CSEKコンフィグ (gsutil)

```ini
[GSUtil]
encryption_key = <Base64エンコードAES-256鍵>
decryption_key1 = <旧鍵>
```

**制限:** Transfer Service/Dataflow未対応、Console未対応、既存ディスク適用不可

---

## 対称/非対称暗号化

**対称 (AES-256 GCM):**
```bash
gcloud kms keys create KEY --keyring=RING --location=LOC --purpose=encryption --rotation-period=30d
gcloud kms encrypt --key=KEY --keyring=RING --location=LOC --plaintext-file=in --ciphertext-file=out
gcloud kms decrypt --key=KEY --keyring=RING --location=LOC --ciphertext-file=out --plaintext-file=dec
```

**非対称 (RSA/ECC):**
```bash
# 復号鍵
gcloud kms keys create KEY --keyring=RING --location=LOC --purpose=asymmetric-encryption --default-algorithm=rsa-decrypt-oaep-2048-sha256

# 署名鍵
gcloud kms keys create KEY --keyring=RING --location=LOC --purpose=asymmetric-signing --default-algorithm=rsa-sign-pkcs1-2048-sha256

# 公開鍵取得→OpenSSL暗号化→復号化
gcloud kms keys versions get-public-key VER --key=KEY --keyring=RING --location=LOC --output-file=pub.pem
openssl pkeyutl -in plain.txt -encrypt -pubin -inkey pub.pem -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 > enc.bin
gcloud kms asymmetric-decrypt --version=VER --key=KEY --keyring=RING --location=LOC --ciphertext-file=enc.bin --plaintext-file=dec.txt
```

---

## 鍵ライフサイクル

**状態:** Pending Generation → Enabled ↔ Disabled → Scheduled for Destruction → Destroyed

**鍵インポート (BYOK):**
```bash
export CLOUDSDK_PYTHON_SITEPACKAGES=1
gcloud kms keys create KEY --location=LOC --keyring=RING --purpose=encryption --skip-initial-version-creation
gcloud kms keys versions import --import-job=JOB --location=LOC --keyring=RING --key=KEY --algorithm=google-symmetric-encryption --target-key-file=key.bin --public-key-file=wrap.pub
gcloud kms keys set-primary-version KEY --version=1 --keyring=RING --location=LOC
```

## Cloud HSM

- **FIPS 140-2 Level 3認証、Google管理、地域バインド**
- **API互換:** Cloud KMS APIで透過アクセス
- **Attestation検証:** https://github.com/GoogleCloudPlatform/kms-integrations

## Cloud EKM

**パートナー:** Fortanix/Futurex/Thales/Virtu

**制約:** 自動ローテーション未対応、外部障害時アクセス不可

---

## 各ストレージサービス別暗号化オプション

### Cloud Storage

| 暗号化方式 | 設定方法 | 鍵管理 | 備考 |
|-----------|---------|-------|------|
| **GMEK** | デフォルト | Google | 追加操作不要 |
| **CMEK** | `--kms-key=projects/PROJECT/locations/LOCATION/keyRings/RING/cryptoKeys/KEY` | Cloud KMS | Bucket/Object単位 |
| **CSEK** | `gsutil -o "GSUtil:encryption_key=..."` | 顧客保管 | API/gcloud必須 |

**設定例:**
```bash
# CMEK Bucket作成
gcloud storage buckets create gs://my-cmek-bucket \
  --default-encryption-key=projects/PROJECT/locations/us/keyRings/my-keyring/cryptoKeys/my-key

# CSEK Object暗号化（gsutil）
echo "encryption_key = $(openssl rand -base64 32)" >> ~/.boto
gsutil cp sensitive.txt gs://my-bucket/
```

### BigQuery

| 暗号化方式 | 対象 | 設定 |
|-----------|------|------|
| **GMEK** | 全Dataset | デフォルト（Table/Query結果含む） |
| **CMEK** | Dataset単位 | `bq mk --default_kms_key=KMS_KEY_PATH` |

**CMEK設定例:**
```bash
# CMEK Dataset作成
bq mk --dataset \
  --default_kms_key=projects/PROJECT/locations/us/keyRings/my-keyring/cryptoKeys/my-key \
  PROJECT:my_dataset

# 既存Datasetに適用
bq update --default_kms_key=KMS_KEY_PATH PROJECT:existing_dataset
```

**制約:**
- CMEKはDataset単位（Table単位不可）
- Streaming Insert時もCMEK適用
- Query結果もCMEK暗号化

### Cloud SQL

| エディション | 暗号化方式 | 鍵管理 |
|------------|-----------|-------|
| **All** | GMEK（デフォルト） | Google |
| **Enterprise/Enterprise Plus** | CMEK | Cloud KMS（地域制約あり） |

**CMEK設定例:**
```bash
# CMEK有効化（新規インスタンス）
gcloud sql instances create my-cmek-instance \
  --database-version=MYSQL_8_0 \
  --tier=db-n1-standard-1 \
  --region=us-central1 \
  --disk-encryption-key=projects/PROJECT/locations/us-central1/keyRings/my-keyring/cryptoKeys/my-key

# 既存インスタンスはCMEK適用不可（要マイグレーション）
```

**制約:**
- Enterprise/Enterprise Plusのみ
- 鍵とインスタンスは同一地域必須
- バックアップもCMEK暗号化

### Compute Engine (Persistent Disk)

| 暗号化方式 | 適用タイミング | 鍵管理 |
|-----------|--------------|-------|
| **GMEK** | 常時 | Google |
| **CMEK** | Disk作成時 | Cloud KMS |
| **CSEK** | Disk作成時 | 顧客保管（API経由） |

**CMEK設定例:**
```bash
# CMEK Disk作成
gcloud compute disks create my-cmek-disk \
  --size=100GB \
  --type=pd-ssd \
  --kms-key=projects/PROJECT/locations/us-central1/keyRings/my-keyring/cryptoKeys/my-key \
  --zone=us-central1-a

# VMインスタンス作成時にCMEK Boot Disk指定
gcloud compute instances create my-vm \
  --boot-disk-kms-key=KMS_KEY_PATH \
  --zone=us-central1-a
```

### Cloud Spanner

| 暗号化方式 | 適用範囲 | 設定 |
|-----------|---------|------|
| **GMEK** | 全Instance | デフォルト |
| **CMEK** | Instance単位 | `gcloud spanner instances create --kms-key-name=...` |

**CMEK設定例:**
```bash
# CMEK Instance作成
gcloud spanner instances create my-cmek-instance \
  --config=regional-us-central1 \
  --nodes=1 \
  --kms-key-name=projects/PROJECT/locations/us-central1/keyRings/my-keyring/cryptoKeys/my-key
```

## コンプライアンス規制対応

### GDPR（General Data Protection Regulation）

| 要件 | GCP実装 | 証跡 |
|------|---------|------|
| **データ主権（特定地域保管）** | Regional Resource（`us-central1`, `europe-west1`等） + Organization Policy `gcp.resourceLocations` | Cloud Asset Inventory |
| **暗号化（転送時・保管時）** | TLS 1.2+、GMEK/CMEK | Cloud KMS Logs |
| **アクセス制御** | IAM最小権限、MFA強制 | Cloud Audit Logs |
| **データ削除権（Right to Erasure）** | Cloud Storage Object Lifecycle、BigQuery DELETE | Admin Activity Logs |
| **データポータビリティ** | Cloud Storage Transfer、BigQuery Export | - |

**Organization Policy例（EU限定）:**
```yaml
constraint: constraints/gcp.resourceLocations
listPolicy:
  allowedValues:
    - in:eu-locations
```

### HIPAA（Health Insurance Portability and Accountability Act）

| 要件 | GCP実装 | 補足 |
|------|---------|------|
| **BAA（Business Associate Agreement）** | Google Cloud BAA署名 | Google営業経由 |
| **暗号化** | CMEK推奨（監査証跡） | Cloud KMS + Cloud HSM |
| **アクセスログ** | Data Access Logs有効化（全サービス） | BigQuery Logging Sink |
| **監査証跡** | Cloud Audit Logs 7年保管 | Cloud Storage Nearline |
| **災害復旧** | Multi-region Replication | Cloud SQL HA、GCS Dual-region |

**Data Access Logs有効化（BigQuery）:**
```bash
# Organization-level Data Access Logs有効化
gcloud logging sinks create hipaa-audit-sink \
  bigquery.googleapis.com/projects/AUDIT_PROJECT/datasets/hipaa_audit \
  --organization=ORG_ID \
  --log-filter='protoPayload.serviceName="bigquery.googleapis.com"' \
  --include-children
```

### PCI-DSS（Payment Card Industry Data Security Standard）

| 要件 | GCP実装 | Level |
|------|---------|-------|
| **ネットワーク分離** | VPC Service Controls境界 | Requirement 1 |
| **暗号化** | CMEK/Cloud HSM（カード情報） | Requirement 3 |
| **アクセス制御** | IAM最小権限 + MFA | Requirement 7-8 |
| **ログ監視** | Cloud Logging + SIEM統合 | Requirement 10 |
| **脆弱性管理** | Security Command Center | Requirement 11 |

**VPC Service Controls設定例:**
```bash
# Perimeter作成（PCI-DSSスコープ）
gcloud access-context-manager perimeters create pci_perimeter \
  --title="PCI-DSS Perimeter" \
  --resources=projects/12345 \
  --restricted-services=bigquery.googleapis.com,storage.googleapis.com \
  --vpc-allowed-services=ALL_SERVICES \
  --policy=POLICY_ID
```

## Cloud DLP

### アーキテクチャ

| Method | ユースケース | 特徴 |
|--------|------------|------|
| **Content** | リアルタイムパイプライン | 同期API、ストリーミング |
| **Storage** | BigQuery/GCS定期スキャン | バッチジョブ、結果保存 |
| **Hybrid** | オンプレミス/他クラウド | カスタムクローラー、API送信 |

### InfoTypes

**主要:** CREDIT_CARD_NUMBER, EMAIL_ADDRESS, US_SOCIAL_SECURITY_NUMBER, PERSON_NAME, DATE_OF_BIRTH

**カスタム:** Words/Phrases (少数), Dictionary Path (数万語), Regex, Stored InfoType (数百万語)

**ルールセット:** Exclusion Rule (誤検知除外), Hotword Rule (信頼度調整)

### Cloud DLP高度な設定

#### Hotword Rule（文脈認識検出）

特定キーワード近傍でのみ検出感度を調整。

**設定例（クレジットカード番号誤検知削減）:**
```json
{
  "inspectConfig": {
    "infoTypes": [{"name": "CREDIT_CARD_NUMBER"}],
    "ruleSet": [{
      "infoTypes": [{"name": "CREDIT_CARD_NUMBER"}],
      "rules": [{
        "hotwordRule": {
          "hotwordRegex": {"pattern": "card\\s*number"},
          "proximity": {"windowBefore": 50},
          "likelihoodAdjustment": {"fixedLikelihood": "VERY_LIKELY"}
        }
      }]
    }]
  }
}
```

**効果:**
- "card number: 4111-1111-1111-1111" → `VERY_LIKELY`（検出）
- "4111-1111-1111-1111"（文脈なし） → `POSSIBLE`（スキップ）

#### Exclusion Rule（既知の安全データ除外）

テストデータ・サンプル値を検出から除外。

**設定例（テストカード番号除外）:**
```json
{
  "inspectConfig": {
    "infoTypes": [{"name": "CREDIT_CARD_NUMBER"}],
    "ruleSet": [{
      "infoTypes": [{"name": "CREDIT_CARD_NUMBER"}],
      "rules": [{
        "exclusionRule": {
          "matchingType": "MATCHING_TYPE_FULL_MATCH",
          "dictionary": {
            "wordList": {
              "words": ["4111111111111111", "5555555555554444"]
            }
          }
        }
      }]
    }]
  }
}
```

#### カスタムInfoType（正規表現）

組織固有のPIIパターン定義。

**設定例（従業員ID検出）:**
```json
{
  "inspectConfig": {
    "customInfoTypes": [{
      "infoType": {"name": "EMPLOYEE_ID"},
      "regex": {"pattern": "EMP-[0-9]{6}"},
      "likelihood": "LIKELY"
    }]
  }
}
```

#### Data Catalog連携（Policy Tag制御）

DLP検出結果をBigQuery Policy Tagに自動適用。

**実装フロー:**
```
1. DLP Inspection Job実行（BigQuery Dataset全体スキャン）
2. DLP結果をCloud Functions処理
3. 検出されたカラムにPolicy Tag自動付与
4. BigQuery IAMでPolicy Tag単位のアクセス制御
```

**Cloud Function例（Python）:**
```python
from google.cloud import dlp_v2, datacatalog_v1

def apply_policy_tags(event, context):
    dlp_client = dlp_v2.DlpServiceClient()
    catalog_client = datacatalog_v1.PolicyTagManagerClient()

    # DLP Job結果取得
    job_name = event['attributes']['jobName']
    job = dlp_client.get_dlp_job(request={'name': job_name})

    for finding in job.inspect_details.result.info_type_stats:
        if finding.info_type.name == 'CREDIT_CARD_NUMBER':
            # Policy Tag適用（PII_SENSITIVE）
            table = finding.table_reference
            column = finding.column
            apply_tag(catalog_client, table, column, 'PII_SENSITIVE')
```

---

## データ非識別化

| 手法 | 可逆 | ユースケース |
|------|-----|------------|
| Masking | ❌ | 表示マスキング |
| Replacement | ❌ | ログ出力 |
| Date Shifting | ❌ | タイムライン分析 |
| Bucketing | ❌ | 統計分析 |
| Crypto Hashing | ❌ | 参照整合性のみ |
| AES-SIV | ✅ | 結合・分析トークン |
| FPE-FFX | ✅ | レガシー互換 (長さ保持) |

**方式選択:** レガシー互換→FPE-FFX、厳密フォーマット不要→AES-SIV、逆化不要→Hashing

### DLPトークン化 (AES-SIV + KMS)

```bash
# 1. KMS鍵
gcloud kms keyrings create dlp-keyring --location=global
gcloud kms keys create dlp-key --location=global --keyring=dlp-keyring --purpose=encryption

# 2. AES鍵生成・エンコード
openssl rand -out aes_key.bin 32 && base64 -i aes_key.bin

# 3. KMSでラップ
curl "https://cloudkms.googleapis.com/v1/projects/PID/locations/global/keyRings/dlp-keyring/cryptoKeys/dlp-key:encrypt" \
  -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -H "content-type: application/json" -d '{"plaintext": "BASE64_AES_KEY"}'

# 4. DLP非識別化 (JSON: cryptoKey.kmsWrapped{cryptoKeyName,wrappedKey}, surrogateInfoType)
# 5. 再識別化 (dlp.googleapis.com/v2/projects/PID/locations/global/content:reidentify)
```

## DLPベストプラクティス

**検査:** 高リスクデータ優先、サンプリング有効、InfoType明示 (PERSON_NAME/DATE/DATE_OF_BIRTH/LOCATION無効化)
**プロファイリング:** BigQuery大規模 (25k+テーブル) → 自動化
**検査ジョブ:** 詳細調査 (非構造化)、カスタムワークフロー
**イベントベース:** Eventarc Trigger → Cloud Function → DLP Scan
**Data Catalog:** スキャン結果→タグ→Policy Tag制御

---

## VPC Service Controls

**サービス境界保護:** インターネット/VPC/リソース間の3インターフェース

**Access Context Manager:** IP Subnetworks, Regions, Principals, Device Policy (BeyondCorp Enterprise)

**Ingress/Egress Rule:** 境界外↔境界内アクセス許可 (Perimeter Bridge非推奨)

**API制限:**
- **restricted.googleapis.com:** 199.36.153.4/30 (インターネット不可)
- **VPC Accessible Services:** 境界内API明示指定

**ベストプラクティス:**
- 単一大規模境界推奨
- 全保護サービス有効化
- private.googleapis.comルート禁止
- Dry Runモード→違反ログ分析→本番適用
- アクセスパターン/条件/アクター文書化

---

## Secret Manager

**基本:** Secret (メタデータ/権限), Version (実データ), Rotation (Pub/Sub通知のみ), Replication Policy (ペイロード保存場所)

**Replication:** Automatic (推奨/単一課金/高可用性) / User-Managed (地域要件/2-5リージョン/個別課金)

**CMEK:** Envelope Encryption (DEK→KEK→CMEK)、CMEK無効化→復号不可

**アクセス:**
```bash
gcloud secrets versions access VER --secret=SECRET_ID
gcloud secrets versions access latest --secret=SECRET_ID  # 本番非推奨
gcloud secrets versions access VER --secret=SECRET_ID --format='get(payload.data)' | tr '_-' '/+' | base64 -d
```

**統合:**
- **Cloud Run:** Volume Mount (`latest`可) / Env Var (固定バージョン推奨)
- **GKE:** Workload Identity + Client Libs / Secret Store CSI Driver

**ベストプラクティス:**
- シークレットレベルIAM (プロジェクト/フォルダ禁止)
- バージョン番号固定 (`latest`禁止)
- 無効化→1週間待機→削除
- Data Access Logs有効化
- VPC Service Controls境界設定
- 権限分離: secretAccessor (アプリ), secretVersionAdder (CI/CD), secretVersionManager (ローテーション)

---

## IAMベストプラクティス

**組織:** 専用KMSプロジェクト (ワークロード分離)、基本ロール禁止、Organization Admin (組織レベル)

**ロール分離:**
- **管理:** admin (セキュリティチーム/Terraform), importer (鍵インポート)
- **使用:** cryptoKeyEncrypterDecrypter, cryptoKeyDecrypter, signer, publicKeyViewer, signerVerifier

**鍵属性決定:**
- **Location:** データ近傍、CMEK=保護データ同一地域
- **Protection Level:** EXTERNAL (外部管理), HSM (FIPS L3), SOFTWARE (その他)
- **Rotation:** 対称=自動、非対称=手動 (公開鍵配布必要)
- **Destruction:** 暗号化データ不在時のみ

---

## gcloud CLIクイックリファレンス

**KMS:**
```bash
gcloud kms keyrings create RING --location=LOC
gcloud kms keys create KEY --keyring=RING --location=LOC --purpose=encryption --rotation-period=30d
gcloud kms encrypt --key=KEY --keyring=RING --location=LOC --plaintext-file=in --ciphertext-file=out
gcloud kms decrypt --key=KEY --keyring=RING --location=LOC --ciphertext-file=out --plaintext-file=dec
gcloud kms asymmetric-decrypt --version=VER --key=KEY --keyring=RING --location=LOC --ciphertext-file=enc --plaintext-file=dec
gcloud kms keys versions get-public-key VER --key=KEY --keyring=RING --location=LOC --output-file=pub.pem
```

**Secret Manager:**
```bash
gcloud secrets create SECRET_ID --data-file=secret.txt --replication-policy=automatic
gcloud secrets versions add SECRET_ID --data-file=new.txt
gcloud secrets versions access VER --secret=SECRET_ID
gcloud secrets versions disable VER --secret=SECRET_ID
gcloud secrets versions destroy VER --secret=SECRET_ID
```

**DLP:**
```bash
gcloud dlp info-types list
gcloud dlp inspect-templates create --template-file=tmpl.json
gcloud dlp inspect --content="email@example.com" --info-types=EMAIL_ADDRESS
gcloud dlp jobs create dlp-job --storage-config=storage.json --inspect-config=inspect.json
```

---

## 参考リンク

- Cloud KMS Quotas: https://cloud.google.com/kms/quotas
- InfoType Reference: https://cloud.google.com/dlp/docs/infotypes-reference
- VPC-SC Supported Services: https://cloud.google.com/vpc-service-controls/docs/supported-products
- Secret Manager Best Practices: https://cloud.google.com/secret-manager/docs/best-practices
- KMS Key Hierarchy: https://cloud.google.com/kms/docs/key-hierarchy
