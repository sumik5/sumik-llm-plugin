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
