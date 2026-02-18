# GCP Cloud Storage セキュリティ

Cloud Storage バケットの設定ミス（misconfiguration）は、クラウドにおけるデータ侵害の主要な原因の一つです。このリファレンスでは、Google Cloud Storage（GCS）バケットに対する攻撃パターンと防御策を解説します。

---

## Cloud Storage セキュリティ概要

### GCS バケットの脅威

サーバーレスアプリケーションは、短命なコンピュートリソースと永続化されたデータストレージを分離します。その結果、Cloud Storage バケットには以下のようなセンシティブなデータが保存されます：

- **ユーザーアップロードファイル**: パスポートスキャン、身分証明書、医療記録
- **アプリケーションログ**: 認証トークン、API キー、内部 IP アドレス
- **静的アセット**: 設定ファイル、環境変数、データベース接続情報
- **バックアップデータ**: データベースダンプ、アーカイブファイル

これらのデータが公開アクセス可能になると、攻撃者は認証なしでファイルをダウンロードし、情報漏洩やアイデンティティ盗難、さらなる攻撃の足がかりを得ることができます。

---

## バケット設定の誤り（Misconfiguration）

### 公開アクセスの設定ミス

GCS バケットのアクセス制御は、**IAM ポリシー**と**ACL（Access Control Lists）**の2つの仕組みで管理されます。設定ミスが発生しやすいのは以下のケースです：

#### allUsers / allAuthenticatedUsers の危険性

- **`allUsers`**: インターネット上の誰でもアクセス可能（匿名アクセス）
- **`allAuthenticatedUsers`**: Google アカウントを持つすべてのユーザーがアクセス可能

これらのプリンシパルを付与すると、意図せずバケットが公開されます。

#### 攻撃パターン: 公開バケットの列挙とダウンロード

**ステップ1: 公開バケットの発見**

```bash
# gcloud CLI で組織内のバケット一覧を取得
gcloud storage buckets list

# 特定のバケットの IAM ポリシーを確認
gcloud storage buckets get-iam-policy gs://my-bucket

# allUsers または allAuthenticatedUsers が含まれているか検索
gcloud storage buckets get-iam-policy gs://my-bucket | grep -E 'allUsers|allAuthenticatedUsers'
```

**ステップ2: オブジェクトの列挙**

```bash
# バケット内のファイル一覧を取得（匿名アクセス）
curl "https://storage.googleapis.com/storage/v1/b/my-bucket/o" | jq

# gcloud CLI での列挙
gcloud storage ls gs://my-bucket --recursive
```

**ステップ3: ファイルのダウンロード**

```bash
# 単一ファイルのダウンロード
curl -O "https://storage.googleapis.com/my-bucket/sensitive-data.txt"

# gcloud CLI でのダウンロード
gcloud storage cp gs://my-bucket/sensitive-data.txt .

# バケット全体のダウンロード（再帰的）
gcloud storage cp -r gs://my-bucket/* ./local-backup/
```

### 防御策: バケットポリシーの監査

#### 公開アクセスの検出

```bash
# 組織内の全バケットをスキャン
for bucket in $(gcloud storage buckets list --format="value(name)"); do
  policy=$(gcloud storage buckets get-iam-policy gs://$bucket --format=json)
  if echo "$policy" | grep -qE 'allUsers|allAuthenticatedUsers'; then
    echo "警告: gs://$bucket は公開アクセス可能"
  fi
done
```

#### Public Access Prevention の有効化

```bash
# バケット作成時に公開アクセスを防止
gcloud storage buckets create gs://my-secure-bucket \
  --public-access-prevention \
  --uniform-bucket-level-access

# 既存バケットに適用
gcloud storage buckets update gs://my-bucket \
  --public-access-prevention
```

#### Uniform Bucket-Level Access（UBLA）の強制

ACL を無効化し、IAM のみでアクセス制御を統一します：

```bash
# UBLA を有効化
gcloud storage buckets update gs://my-bucket \
  --uniform-bucket-level-access
```

#### 組織ポリシーでの制約

```yaml
# org-policy.yaml
constraint: constraints/storage.publicAccessPrevention
listPolicy:
  deniedValues:
    - "inherited"
  enforcedValue: "enforced"
```

```bash
# 組織レベルで適用
gcloud org-policies set-policy org-policy.yaml --organization=YOUR_ORG_ID
```

---

## Dangling Bucket Takeover 攻撃

### 攻撃シナリオ

Dangling Bucket Takeover は、削除されたバケットへの参照が残っている状態を悪用する攻撃です：

1. **アプリケーションがバケットを参照**: `gs://company-app-assets`
2. **開発者がバケットを削除**: コスト削減やリソース整理
3. **攻撃者が同名バケットを作成**: `gs://company-app-assets`
4. **攻撃者が悪意あるコンテンツを配置**: マルウェア、フィッシングページ
5. **アプリケーションが攻撃者のバケットからコンテンツを読み込む**

### 攻撃手法: Dangling バケットの発見

#### ステップ1: 削除されたバケット参照の探索

```bash
# GitHub Code Search API で組織のリポジトリをスキャン
curl -H "Authorization: token YOUR_GITHUB_TOKEN" \
  "https://api.github.com/search/code?q=org:target-company+gs://+extension:yaml" \
  | jq '.items[].html_url'

# ソースコード内のバケット参照を検索
grep -r "gs://" ./source-code/ | grep -oP 'gs://[a-z0-9\-]+'
```

#### ステップ2: バケットの存在確認

```bash
# バケットが存在するか確認（存在しない場合は 404）
curl -I "https://storage.googleapis.com/storage/v1/b/potential-dangling-bucket"

# gcloud CLI での確認
gcloud storage buckets describe gs://potential-dangling-bucket 2>&1 | grep -q "NotFound"
```

#### ステップ3: 同名バケットの作成

```bash
# 攻撃者が同名バケットを作成
gcloud storage buckets create gs://potential-dangling-bucket \
  --project=attacker-project \
  --location=us-central1

# 悪意あるファイルをアップロード
echo "<script>alert('XSS')</script>" > malicious.js
gcloud storage cp malicious.js gs://potential-dangling-bucket/assets/script.js
```

### 防御策: Dangling Bucket の防止

#### バケット削除前のチェック

```bash
# バケット参照をソースコードから検索
git grep "gs://my-bucket" $(git rev-parse --show-toplevel)

# 依存関係ファイルのスキャン
grep -r "gs://my-bucket" .github/workflows/ infrastructure/ config/
```

#### バケット名の予約（Soft Delete）

GCS はバケット削除後も一定期間名前を予約しません。組織ポリシーで制約を設定：

```bash
# 削除されたバケット名の再利用を制限（組織レベル）
# 注: GCS には組織ポリシーでのバケット名予約機能は存在しないため、
# 命名規則とモニタリングで対応する必要があります

# 代替策: 削除フラグを設定し、実際の削除は遅延させる
gcloud storage buckets update gs://my-bucket \
  --retention-period=30d
```

#### 命名規則の強制

組織固有のプレフィックスを使用してバケット名の衝突を防ぐ：

```bash
# 良い例: 組織ドメインを含む
gs://mycompany-com-app-assets

# 悪い例: 汎用的な名前
gs://app-assets
```

#### 削除前の通知とレビュー

```bash
# Cloud Functions でバケット削除イベントを監視
gcloud functions deploy bucket-delete-monitor \
  --runtime=python39 \
  --trigger-event=google.cloud.audit.log.v1.written \
  --trigger-resource=projects/my-project/logs/cloudaudit.googleapis.com%2Factivity

# 通知を Slack や Email に送信
# (関数内で Cloud Audit Logs を解析し、storage.buckets.delete イベントを検出)
```

---

## IaC によるバケットセキュリティ管理

### Terraform でのセキュアなバケット設定

#### 基本的なセキュアバケット

```hcl
# main.tf
resource "google_storage_bucket" "secure_bucket" {
  name          = "my-secure-bucket-${var.project_id}"
  location      = "US"
  force_destroy = false

  # Public Access Prevention を強制
  public_access_prevention = "enforced"

  # Uniform Bucket-Level Access を有効化
  uniform_bucket_level_access = true

  # バージョニングを有効化（削除保護）
  versioning {
    enabled = true
  }

  # ライフサイクルルール（古いバージョンの自動削除）
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
  }

  # 暗号化（Customer-Managed Encryption Key）
  encryption {
    default_kms_key_name = google_kms_crypto_key.bucket_key.id
  }

  # ログ記録を有効化
  logging {
    log_bucket        = google_storage_bucket.log_bucket.name
    log_object_prefix = "bucket-logs/"
  }
}

# IAM バインディング（最小権限の原則）
resource "google_storage_bucket_iam_binding" "app_access" {
  bucket = google_storage_bucket.secure_bucket.name
  role   = "roles/storage.objectViewer"

  members = [
    "serviceAccount:app-service-account@${var.project_id}.iam.gserviceaccount.com",
  ]
}

# 公開アクセスの明示的な拒否
resource "google_storage_bucket_iam_binding" "public_deny" {
  bucket = google_storage_bucket.secure_bucket.name
  role   = "roles/storage.objectViewer"

  members = []  # allUsers / allAuthenticatedUsers を含めない
}
```

#### 機密データ用の高度な設定

```hcl
resource "google_storage_bucket" "sensitive_data" {
  name     = "sensitive-data-${var.project_id}"
  location = "US"

  # Retention Policy（削除防止期間）
  retention_policy {
    retention_period = 2592000  # 30日間
    is_locked        = true     # ロック後は削除不可
  }

  # Object Lock（オブジェクトの上書き・削除を防止）
  # 注: GCS には S3 の Object Lock に相当する機能はないため、
  # Retention Policy と IAM で代替

  # CORS 設定（必要な場合のみ）
  cors {
    origin          = ["https://app.example.com"]
    method          = ["GET"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }

  # Website 設定を無効化（静的ホスティング不要）
  # website {
  #   main_page_suffix = ""
  #   not_found_page   = ""
  # }
}
```

### Checkov によるセキュリティスキャン

Checkov は IaC ファイルの静的解析ツールで、セキュリティベストプラクティスをチェックします。

#### インストールと実行

```bash
# Checkov のインストール
pip install checkov

# Terraform ファイルのスキャン
checkov -d ./infrastructure/ --framework terraform

# 特定のチェックのみ実行
checkov -d . --check CKV_GCP_62,CKV_GCP_78

# JSON 形式で結果を出力
checkov -d . -o json > checkov-report.json
```

#### GCS 関連の主要チェック

| チェックID | 内容 |
|-----------|------|
| `CKV_GCP_62` | バケットで Uniform Bucket-Level Access が有効か |
| `CKV_GCP_78` | バケットで Public Access Prevention が有効か |
| `CKV_GCP_29` | バケットでバージョニングが有効か |
| `CKV_GCP_5`  | バケットでログ記録が有効か |
| `CKV_GCP_114`| バケットで暗号化が有効か |

#### CI/CD パイプラインへの統合

```yaml
# .github/workflows/security-scan.yml
name: IaC Security Scan

on:
  pull_request:
    paths:
      - 'infrastructure/**'

jobs:
  checkov:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: infrastructure/
          framework: terraform
          soft_fail: false  # チェック失敗時に CI を失敗させる
          output_format: sarif
          output_file_path: checkov-results.sarif

      - name: Upload SARIF results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: checkov-results.sarif
```

### Infrastructure as Code でのドリフト検知

#### Terraform State との差分検出

```bash
# Terraform プランを実行（差分を確認）
terraform plan -out=tfplan

# 差分がある場合は警告
if terraform show -json tfplan | jq -e '.resource_changes | length > 0' > /dev/null; then
  echo "警告: インフラストラクチャにドリフトが検出されました"
  terraform show tfplan
fi
```

#### Cloud Asset Inventory での監査

```bash
# 全バケットの現在の設定をエクスポート
gcloud asset search-all-resources \
  --scope=projects/my-project \
  --asset-types=storage.googleapis.com/Bucket \
  --format=json > current-buckets.json

# Public Access Prevention が無効なバケットを検出
jq -r '.[] | select(.additionalAttributes.publicAccessPrevention != "enforced") | .name' \
  current-buckets.json
```

#### 自動修復スクリプト

```bash
#!/bin/bash
# auto-remediate-buckets.sh

BUCKETS=$(gcloud storage buckets list --format="value(name)")

for bucket in $BUCKETS; do
  # Public Access Prevention をチェック
  prevention=$(gcloud storage buckets describe gs://$bucket \
    --format="value(iamConfiguration.publicAccessPrevention)")

  if [ "$prevention" != "enforced" ]; then
    echo "修復中: gs://$bucket"
    gcloud storage buckets update gs://$bucket \
      --public-access-prevention
  fi

  # Uniform Bucket-Level Access をチェック
  ubla=$(gcloud storage buckets describe gs://$bucket \
    --format="value(iamConfiguration.uniformBucketLevelAccess.enabled)")

  if [ "$ubla" != "True" ]; then
    echo "修復中: gs://$bucket - UBLA を有効化"
    gcloud storage buckets update gs://$bucket \
      --uniform-bucket-level-access
  fi
done
```

---

## GCS セキュリティチェックリスト

### 設計段階

- [ ] バケット命名規則に組織プレフィックスを含める
- [ ] 公開アクセスが必要なバケットとプライベートバケットを分離
- [ ] データ分類に基づいて暗号化要件を定義
- [ ] ライフサイクルポリシーでデータ保持期間を設計

### 実装段階

- [ ] Public Access Prevention を有効化（`--public-access-prevention`）
- [ ] Uniform Bucket-Level Access を有効化（`--uniform-bucket-level-access`）
- [ ] バージョニングを有効化（削除保護）
- [ ] Cloud KMS による暗号化を設定
- [ ] IAM ポリシーで最小権限の原則を適用
- [ ] `allUsers` と `allAuthenticatedUsers` を使用しない
- [ ] ログ記録を有効化（Cloud Audit Logs）
- [ ] CORS 設定を最小限に制限

### 運用段階

- [ ] 定期的な IAM ポリシー監査（週次）
- [ ] Cloud Asset Inventory で設定ドリフトを検知
- [ ] Checkov による IaC スキャンを CI/CD に統合
- [ ] バケット削除前にソースコード参照をチェック
- [ ] 削除されたバケット名を監視（Dangling Bucket 対策）
- [ ] Security Command Center でアラートを設定
- [ ] VPC Service Controls でネットワーク境界を設定

### インシデント対応

- [ ] 公開アクセスが検出された場合の対応手順を文書化
- [ ] 不正アクセスログの分析手順を整備
- [ ] バケット侵害時のフォレンジック手順を準備
- [ ] インシデント後のポストモーテムとポリシー改善

---

## まとめ

Cloud Storage バケットのセキュリティは、設定の正確性と継続的な監視が鍵です：

1. **設計時**: 公開アクセスを必要最小限に制限し、命名規則と分類を明確にする
2. **実装時**: IaC で設定を標準化し、Checkov でスキャンを自動化する
3. **運用時**: ドリフト検知と定期監査で設定の逸脱を早期に発見する
4. **削除時**: Dangling Bucket 攻撃を防ぐため、参照を事前に確認する

これらのプラクティスを組み合わせることで、GCS バケットの設定ミスによるデータ侵害リスクを大幅に削減できます。
