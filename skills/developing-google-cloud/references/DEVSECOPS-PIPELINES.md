# GCP DevSecOps パイプライン リファレンス

DevOpsパイプラインへのセキュリティ自動化統合。Infrastructure as Code（Terraform）、CI/CDセキュリティゲート、シークレット管理、コンプライアンス強制の実践ガイド。

---

## DevSecOpsとシフトレフトの原則

### DevSecOps概要

DevSecOpsは開発（Dev）・運用（Ops）・セキュリティ（Sec）を単一の継続的ワークフローに統合し、セキュリティ制御を各コミットに付随するコードとして扱う。

GCPでは以下のネイティブサービスがオープンソースツール（Terraform、tfsec、Trivy）とシームレスに統合:
- Cloud Build
- Artifact Registry
- Secret Manager

**メリット:**
- ヒューマンエラー削減（自動リント・静的解析・Policy as Code）
- 一貫したコンプライアンス（CIS Benchmark、PCI-DSS自動検証）
- 迅速な修復（PRやビルドログで即座に問題発見）
- スケーラビリティ（数百リポジトリ・プロジェクトで一貫したセキュリティ）

### シフトレフト（Shift Left）

従来のリリースサイクルでは、ペネトレーションテストやコンプライアンスレビューが開発後に実施され、大規模な手戻りが発生していた。

**シフトレフトの実践:**
- セキュリティチェックをIDE・最初のPRの段階で実施
- GCPでの実装例:
  - ビルド時に毎回イメージスキャン
  - Terraform planを組織ポリシーに対して検証
  - 無制限ファイアウォールルール開放時に自動デプロイ失敗

| フェーズ | 従来のアプローチ | シフトレフトアプローチ |
|---------|----------------|----------------------|
| 計画段階 | セキュリティレビューなし | 脅威モデリング実施 |
| コード段階 | 開発者に委任 | IDE内リント・SAST |
| ビルド段階 | ビルドのみ | 脆弱性スキャン・IaCチェック |
| テスト段階 | 機能テストのみ | セキュリティテスト統合 |
| デプロイ段階 | 手動承認 | Policy as Code自動ゲート |
| 運用段階 | 事後対応 | 継続的監視・自動修復 |

**効果:**
- バグ修正コスト削減
- 最終段階での驚き排除
- 開発者がセキュリティ成果にオーナーシップ

---

## Terraform IaC for GCP Security

### Terraform概要

TerraformはGCPセキュリティポスチャを「設定して祈る」アプローチから「定義され実証された戦略」に転換。

**3つのコア概念:**
1. **宣言的構文**: `.tf`ファイルでVMs、サブネット、ファイアウォールルールを定義
2. **ステート管理**: ステートファイルでリソースの現状を追跡、各実行時に変更を調整
3. **モジュラー構成**: インフラを再利用可能モジュールに分割、大規模デプロイを簡素化

### セキュリティリソースの自動化

全てのファイアウォールルール、IAMバインディング、KMS鍵を`.tf`ファイルで宣言的に表現することで、単一の監査可能な信頼できるソースを作成。

**適用例:**

```hcl
# VPC with restricted inbound rules and enforced encryption
resource "google_compute_network" "secure_vpc" {
  name                    = "secure-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_firewall" "deny_all_ingress" {
  name    = "deny-all-ingress"
  network = google_compute_network.secure_vpc.name

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  priority      = 1000
}

resource "google_kms_key_ring" "secure_keyring" {
  name     = "secure-keyring"
  location = "us-central1"
}
```

### セキュリティベースライン自動化

| ユースケース | 実装 |
|------------|------|
| リソース定義 | ファイアウォールルール、IAMポリシー、ネットワーク構成をTerraformリソースとしてコード化 |
| 自動セキュリティベースライン | 必須設定（外部IP禁止、SSL強制）の一貫した適用 |
| 環境別変数 | 変数ファイルでdev、staging、prodのセキュリティ構成を差別化 |

### 高度なテクニック

**Policy as Codeツール:**
- **OPA (Open Policy Agent)**: Terraform とOPAを組み合わせて適用前にセキュリティコンプライアンスを評価
- **HashiCorp Sentinel**: Terraform Cloud内で実行、ルール違反plan（例: サブネットCIDRは/24以下）をブロック

**ステートロックと暗号化:**
```bash
# Cloud Storageバケットにステート保存（暗号化有効）
terraform {
  backend "gcs" {
    bucket = "terraform-state-bucket"
    prefix = "prod/terraform.tfstate"
  }
}
```

### ベストプラクティス

| 項目 | 実践 |
|------|------|
| バージョン管理 | TerraformコードをGitに保存、セキュリティ変更のコードレビュー実施 |
| ステート分離 | ロックされた暗号化された場所（GCS bucket with SSE）にTerraformステート保管 |
| モジュラーアプローチ | IAM、VPC、GCPセキュリティポリシーの個別モジュール作成、明確性と再利用性の確保 |

---

## CI/CDパイプラインへのセキュリティ統合

### セキュリティゲート実装

最新のパイプラインはコンパイルと単体テストだけでなく、自動セキュリティゲートとして機能する必要がある。

**統合するチェック:**
- 静的コード解析
- シークレット検出
- IaCリント

**パイプライン例（Cloud Build with Trivy）:**

```yaml
steps:
  - name: aquasec/trivy
    entrypoint: trivy
    args:
      - "--exit-code"
      - "1"
      - "--severity"
      - "HIGH,CRITICAL"
      - "gcr.io/$PROJECT_ID/app:${SHORT_SHA}"
```

### セキュリティパイプラインステージ

| ステージ | ツール | 目的 |
|---------|--------|------|
| 静的解析（SAST） | SonarQube、Snyk | 安全でないパターン・露出シークレットのリント |
| IaCスキャン | tfsec、Checkov | Terraform/YAML定義のミス設定チェック（開放ポート、公開バケット等） |
| ポリシー強制 | OPA | 各コミット・マージリクエストをコンプライアンスベースライン（CIS、内部標準）に対して評価 |
| イメージビルド | Docker | コンテナイメージ作成 |
| 脆弱性スキャン | Trivy、Container Analysis | コンテナイメージの既知脆弱性検出 |
| ポリシーチェック | Binary Authorization | イメージがポリシー要件を満たすか検証 |
| デプロイ | Cloud Deploy、kubectl | 承認済みイメージを本番環境にデプロイ |

### 承認ワークフロー

**手動ゲート:**
- `iam.tf`変更または/24より広いファイアウォールルール追加時、2名レビュー必須

**自動ロールバック:**
- デプロイ後テスト失敗またはランタイムスキャンでクリティカルCVE検出時、`kubectl rollout undo`やCloud Deploy rollbackをパイプラインがトリガー

### 主要ツールと統合

| カテゴリ | ツール例 | 重要性 |
|---------|---------|--------|
| ビルドエンジン | Jenkins、GitLab CI、Cloud Build | マルチステージセキュリティパイプライン編成 |
| スキャン | Snyk、Trivy、SonarQube、Checkov | コード・イメージ・IaC脆弱性の早期検出 |
| Policy as Code | OPA、HashiCorp Sentinel | コンプライアンスゲート自動強制 |
| 通知 | Slack、Teams、PagerDuty | 失敗を適切な人材に即座に通知 |

---

## 設定エラー自動スキャン

### ミス設定リスク

クラウド侵害の主要原因は、開放ファイアウォールルール、公開バケット、過剰権限サービスアカウント等のミス設定。

**リスク種別:**

| リスク | 説明 | 検出方法 |
|-------|------|---------|
| 開放ファイアウォール | `0.0.0.0/0`または過度に広いポート範囲許可 | tfsec、Checkov |
| 公開Storage | `allUsers`/`allAuthenticatedUsers`に読取権限 | Cloud Asset Inventory、Forseti |
| 過剰IAM | `roles/owner`や`roles/editor`の広範な付与 | IAM Policy Analyzer |
| 暗号化未適用 | デフォルト鍵使用、CMEK/CSEK未設定 | Security Command Center |

### リント・ポリシーチェック

**Linting（軽量チェック）:**

```bash
# tfsec で Terraform スキャン
tfsec terraform/

# Checkov で IaC スキャン
steps:
  - name: bridgecrew/checkov
    entrypoint: checkov
    args:
      - "--directory"
      - "."
      - "--soft-fail"
      - "false"
      - "--quiet"
```

**ポリシーチェック（Policy as Code）:**

```rego
# OPA Gatekeeper constraint: GCE外部IP禁止
package gcp.compute

deny[msg] {
  input.resource_type == "google_compute_instance"
  input.access_config
  msg := "External IP on GCE instance is prohibited"
}
```

### SDLC統合チェック

| フェーズ | 統合方法 |
|---------|---------|
| 継続的統合 | 全コミットでリント・ポリシーチェックをトリガー、クリティカル発見時にビルド失敗 |
| プルリクエストレビュー | スキャン結果をインライン表示、レビュアーが承認/修正依頼を判断 |
| 本番ドリフト検出 | 夜間ジョブで本番GCPリソースとTerraformステートを比較、コード外での手動変更を警告 |

---

## パイプラインでのシークレット管理

### Secret Manager統合

GCP Secret Managerでパスワード・トークンをバージョン管理されたアーティファクトとして扱う。

**ライフサイクル:**
1. Secret Manager APIでシークレット取得
2. ビルドステップで使用
3. コンテナ終了時に破棄

**Cloud Buildでのシークレット取得例:**

```yaml
- name: gcr.io/google.com/cloudsdktool/cloud-sdk
  entrypoint: bash
  args:
    - "-c"
    - |
      DB_PASS=$(gcloud secrets versions access latest --secret=db-prod-password)
      export DB_PASS
      ./gradlew test
```

### エンドツーエンドのシークレット保護

| フェーズ | 実践 |
|---------|------|
| ビルド前 | Pre-commitフック（GitLeaks）でシークレットのGit push防止 |
| ビルド中 | Workload Identity短命トークンでSecret ManagerからクレデンシャルSS取得、環境変数として注入、stdoutに非表示 |
| デプロイ後 | アクセスログ・アラートポリシーで異常なシークレット利用を監視、Cloud Functionsで鍵・証明書を定期ローテーション |

### シークレット注入

**環境変数:**
```bash
# Secret Manager から取得して環境変数として設定
DB_PASS=$(gcloud secrets versions access latest --secret=db-prod-password)
export DB_PASS
```

**オンザフライ復号化:**
- エフェメラルコンテナ内でシークレット復号化
- ディスクや標準出力に書き込まない

**短命トークン:**
- IAM Credentials APIで時間制限付きトークン発行
- ログが漏洩してもクレデンシャルは速やかに失効

### コミット回避策

**Git hooks:**
```bash
#!/usr/bin/env bash
gitleaks protect --staged --exit-code 1
```

**サードパーティスキャナー:**
- GitLeaksやTruffleHogをCIで実行、履歴から漏洩クレデンシャル検索、ブロッキングPRコメント

**暗号化コミット:**
- シークレット値ではなく参照（例: `projects/123/secrets/db-pass`）のみをコード保存

### ベストプラクティス

| 項目 | 実践 |
|------|------|
| 最小アクセス権限付与 | パイプライン・ランタイム専用のサービスアカウント作成、`roles/secretmanager.secretAccessor`を必要なシークレットのみに付与 |
| 定期ローテーション | Cloud SchedulerとCloud Functionsで自動ローテーション、90日ごとまたはインシデント対応時にコード変更不要で新バージョン展開 |
| デフォルト暗号化 | Secret ManagerはGoogle管理鍵でデフォルト暗号化、規制業界はCMEK有効化で鍵ローテーションスケジュール・地理的居住・失効を完全制御 |
| ハードコーディング回避 | クレデンシャルをGitやTerraformに埋め込まない、リソースID参照またはランタイム環境変数注入 |

---

## DevSecOps実装ベストプラクティス

### SDLC全体へのセキュリティ組込

DevSecOps文化の構築は、セキュリティ制御をアプリケーションコードと同じバックログ・スプリント・PRで扱うこと。

**シフトレフト:**

```bash
# Pre-commit hook でシークレットブロック
#!/usr/bin/env bash
gitleaks protect --staged --exit-code 1
```

**実装:**
- インラインフィードバック: pre-commit、git-secrets、tfsecでSAST・IaCリント実行
- フェイルファストパイプライン: Cloud BuildやGitLab CIで高重大度発見時にマージブロック
- 開発者ダッシュボード: PR UIでスキャン結果公開、トリガー行を正確に表示

### 統合ログ・監視

**ログ集約:**
- Cloud BuildログtfsecレポートとランタイムイベントをCloud LoggingまたはBigQuery（Splunk/ELK）に転送

**リアルタイムアラート:**
- `roles/owner`付与や`critical CVE detected in image gcr.io/app:latest`パターンでログベースメトリクス作成

**可視化ダッシュボード:**
- Grafanaパネルでビルド合格/不合格率、スキャン重大度、脆弱性修正時間追跡

### Immutable Infrastructure

**エフェメラルリソース:**
```bash
# Terraform と Cloud Build で毎リリース時 Cloud Run リビジョン・GKE Podを再作成
terraform apply && gcloud run deploy app --image gcr.io/app:latest
```

**ゴールデンイメージ:**
- セキュリティ更新を新コンテナイメージにベイク、実行中ノードにパッチ適用しない

**自動ロールバック:**
- デプロイ後ヘルスチェック失敗時、Cloud Deployが前リビジョンに自動復元

### DevとSecurityのコラボレーション

**共有トレーニング:**
- OWASP Top 10、tfsec、Secret Manager利用の月次ランチ&ラーン

**共同振り返り:**
- パイプラインインシデント後、開発とセキュリティが協力してアクションアイテム作成（リンター更新、テスト追加、ポリシー改善）

**脅威モデリングワークショップ:**
- スプリント計画時にSTRIDE（Spoofing、Tampering、Repudiation、Information Disclosure、Denial of Service、Elevation of Privilege）セッション実施

### 継続的改善

| 活動 | 頻度 | 目的 |
|------|------|------|
| スキャナーレビュー | 四半期ごと | ノイズの多いツール廃止、OSVスキャナー等新ツールパイロット導入 |
| ポリシー改善 | 四半期ごと | OPA決定ログで最頻度発動ルール特定、リスク選好度に基づきしきい値調整 |
| メトリクス追跡 | 継続的 | 脆弱性MTTR、セキュリティゲートでブロックされたビルド割合を監視、継続的減少を目指す |

---

## レガシーパイプライン対応

### 課題と緩和策

| 課題 | 説明 | 緩和策 |
|------|------|--------|
| 断片化ツールチェーン | 旧ビルドサーバーがモダンスキャナープラグイン欠如 | ツールのコンテナ化、GCPセキュリティAPIとのブリッジスクリプト作成 |
| 文化的抵抗 | チームは新ゲートが開発速度低下を懸念 | 早期検出のコスト削減と手戻り削減を強調、高速自動スキャンと誤検出最小化を提供 |
| 可視性制限 | ログが単一VMに存在、ビルドイベントとランタイム問題の相関不可 | GCP監視・ログ機能統合、既存システムを中央アグリゲータ（Splunk、ELK）に接続 |
| インフラリファクタリング | 手動スクリプトはポリシーチェック不可 | ステップバイステップでTerraformやIaCに移行、サブシステムの部分構成から書き直し範囲拡大 |
| セキュリティ承認遅延 | 手動承認がボトルネック | OPA/Sentinelでポリシーチェック自動化、重要変更のみ短命承認ゲート使用 |

### 段階的モダナイゼーション

**OPA導入例:**

```rego
# OPA policy: 0.0.0.0/0 ingressブロック
package gcp.firewall

deny[msg] {
  input.direction == "INGRESS"
  input.source_ranges[_] == "0.0.0.0/0"
  msg := "Ingress rule exposes resource to the internet"
}
```

**段階的アプローチ:**
1. **コンテナ化ツール**: Trivy、Checkovをコンテナ化、任意のビルドエージェントで実行可能
2. **シークレット移行**: Secret Managerに移行、短命サービスアカウントトークンでランタイムアクセス
3. **Warn-only OPA**: 最初はビルド失敗なしで違反をハイライト、開発者が価値を認識し誤検出最小化後に`fail`に切替
4. **ログストリーミング**: レガシービルドログをCloud Logging（またはSIEM）にストリーム、インシデント対応・コンプライアンス用監査証跡作成
5. **段階的Terraform化**: 手動インフラスクリプトをTerraformモジュールに徐々にリファクタ、VPC等のステートレスリソースから開始

---

## コンプライアンス強制の実践

### 規制対応パイプライン

**PCI-DSS準拠（eコマース）:**
- **シナリオ**: コードマージはTerraformスキャンで443以外の開放ポート禁止、平文保存シークレット禁止、最小IAM権限を確保
- **ソリューション**: JenkinsにSnyk・OPAチェック統合、ポリシー違反時ビルド失敗
- **結果**: 本番環境が継続的にコンプライアント、カード会員データ露出リスクほぼゼロ

**HIPAA準拠（ヘルスケア）:**
- **シナリオ**: 患者データ管理GCPリソースは暗号化（CMEK）強制、プライベートサブネットからの制限付きegress
- **ソリューション**: HIPAA標準リソース（VPC、サブネット、ファイアウォール）をポリシーチェック付きTerraformモジュールで定義、GitLab CIで全プッシュ時に自動スキャン
- **結果**: 各環境がHIPAAの厳格セキュリティ制御に準拠、監査オーバーヘッド劇的削減

**金融サービス:**
- **シナリオ**: 全コード変更に4-eye原則+シークレット・鍵の自動静的解析
- **ソリューション**: エフェメラルクレデンシャルにSecret Manager使用、Cloud BuildでCheckovスキャン、コンプライアンス/シークレットチェック失敗時マージゲート
- **結果**: 開発者摩擦最小化、意図しないシークレットや誤設定ネットワークルールの本番流入防止

### リリースごとのセキュリティ確保

パイプラインパターン: **Policy as Code + 自動スキャン + 最小手動ゲート** = 厳格なコンプライアンス要件とチーム速度の両立

---

## 判断基準

### IaCツール選択

| 判断基準 | Terraform | Cloud Deployment Manager | Pulumi |
|---------|----------|--------------------------|--------|
| マルチクラウド | ✅ クラウドアグノスティック | ❌ GCP専用 | ✅ マルチクラウド対応 |
| ステート管理 | ✅ 外部ステート（GCS） | ✅ GCPマネージド | ✅ 外部ステート |
| Policy as Code | ✅ OPA/Sentinel統合 | ⚠️ 制限あり | ✅ プログラマティック検証 |
| エコシステム | ✅ 最大 | ⚠️ GCP限定 | ⚠️ 成長中 |

### スキャンツール選択

| 判断基準 | tfsec | Checkov | Trivy |
|---------|-------|---------|-------|
| 対象 | Terraform | IaC全般 | コンテナイメージ |
| 速度 | ✅ 高速 | ⚠️ 中速 | ✅ 高速 |
| ルール網羅性 | ⚠️ Terraform専用 | ✅ 広範囲 | ✅ CVEデータベース統合 |
| CI統合 | ✅ 容易 | ✅ 容易 | ✅ 容易 |

### Policy as Code エンジン選択

| 判断基準 | OPA | HashiCorp Sentinel | Cloud Policy Intelligence |
|---------|-----|-------------------|---------------------------|
| 汎用性 | ✅ 汎用ポリシーエンジン | ⚠️ Terraform専用 | ⚠️ GCP専用 |
| 学習曲線 | ⚠️ Rego学習必要 | ⚠️ Sentinel学習必要 | ✅ GCPネイティブ |
| コミュニティ | ✅ 活発 | ⚠️ Terraform利用者 | ⚠️ GCP利用者 |
| ランタイム適用 | ✅ Kubernetes統合 | ❌ CI/CDのみ | ⚠️ GCP Policy Controller |

### シークレット管理ツール選択

| 判断基準 | GCP Secret Manager | HashiCorp Vault | Kubernetes Secrets |
|---------|-------------------|-----------------|-------------------|
| GCP統合 | ✅ ネイティブ | ⚠️ 要設定 | ⚠️ K8s限定 |
| 動的シークレット | ❌ | ✅ 対応 | ❌ |
| 監査ログ | ✅ Cloud Logging統合 | ✅ 独自監査ログ | ⚠️ K8s監査ログ |
| 運用複雑性 | ✅ マネージド | ⚠️ 自己管理 | ⚠️ K8s依存 |

### CI/CDプラットフォーム選択

| 判断基準 | Cloud Build | Jenkins | GitLab CI |
|---------|------------|---------|-----------|
| GCP統合 | ✅ ネイティブ | ⚠️ プラグイン | ⚠️ 設定必要 |
| セキュリティプラグイン | ✅ Container Analysis統合 | ✅ 豊富 | ✅ 組込SAST/DAST |
| 学習曲線 | ✅ シンプル | ⚠️ 複雑 | ✅ 中程度 |
| カスタマイズ性 | ⚠️ YAML制約 | ✅ 高度 | ✅ 高度 |

---

## gcloud CLI例

### Secret Manager操作

```bash
# シークレット作成
gcloud secrets create db-prod-password \
  --replication-policy="automatic"

# シークレット値設定
echo -n "my-secret-value" | gcloud secrets versions add db-prod-password --data-file=-

# シークレット取得
DB_PASS=$(gcloud secrets versions access latest --secret=db-prod-password)

# サービスアカウントに読取権限付与
gcloud secrets add-iam-policy-binding db-prod-password \
  --member="serviceAccount:build-sa@project.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Cloud Build トリガー

```bash
# GitHub連携トリガー作成
gcloud builds triggers create github \
  --repo-name=my-app \
  --repo-owner=my-org \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml

# トリガー一覧
gcloud builds triggers list

# ビルドログ確認
gcloud builds log <BUILD_ID>
```

### Binary Authorization

```bash
# デフォルトポリシー作成
gcloud container binauthz policy import policy.yaml

# 証明者作成
gcloud container binauthz attestors create prod-attestor \
  --attestation-authority-note=prod-note \
  --attestation-authority-note-project=project-id

# イメージ証明
gcloud container binauthz attestations sign-and-create \
  --artifact-url="gcr.io/project-id/app:v1.0" \
  --attestor=prod-attestor \
  --attestor-project=project-id \
  --keyversion-project=project-id \
  --keyversion-location=us-central1 \
  --keyversion-keyring=binauthz-keys \
  --keyversion-key=prod-key \
  --keyversion=1
```

---

## Terraform コード例

### セキュアVPC

```hcl
resource "google_compute_network" "secure_vpc" {
  name                    = "secure-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.secure_vpc.id

  private_ip_google_access = true
}

resource "google_compute_firewall" "deny_all_ingress" {
  name    = "deny-all-ingress"
  network = google_compute_network.secure_vpc.name

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  priority      = 1000
}

resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.secure_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
  priority      = 900
}
```

### IAMロール最小権限

```hcl
resource "google_service_account" "app_sa" {
  account_id   = "app-service-account"
  display_name = "Application Service Account"
}

resource "google_project_iam_member" "app_sa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_project_iam_member" "app_sa_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "app_sa_secret_accessor" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_sa.email}"
}
```

### Cloud KMS暗号化

```hcl
resource "google_kms_key_ring" "secure_keyring" {
  name     = "secure-keyring"
  location = "us-central1"
}

resource "google_kms_crypto_key" "cmek_key" {
  name            = "cmek-key"
  key_ring        = google_kms_key_ring.secure_keyring.id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_storage_bucket" "encrypted_bucket" {
  name     = "encrypted-data-bucket"
  location = "US"

  encryption {
    default_kms_key_name = google_kms_crypto_key.cmek_key.id
  }

  uniform_bucket_level_access = true
}

resource "google_kms_crypto_key_iam_member" "storage_encrypter" {
  crypto_key_id = google_kms_crypto_key.cmek_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
}
```

---

## Cloud Build YAML例

### セキュリティパイプライン完全版

```yaml
steps:
  # 1. Terraformフォーマットチェック
  - name: hashicorp/terraform:latest
    entrypoint: terraform
    args: ['fmt', '-check', '-recursive']

  # 2. tfsec で IaC スキャン
  - name: aquasec/tfsec:latest
    args:
      - "terraform/"
      - "--exit-code"
      - "1"
      - "--minimum-severity"
      - "HIGH"

  # 3. Checkov で追加ポリシーチェック
  - name: bridgecrew/checkov:latest
    entrypoint: checkov
    args:
      - "--directory"
      - "terraform/"
      - "--soft-fail"
      - "false"
      - "--quiet"

  # 4. Docker イメージビルド
  - name: gcr.io/cloud-builders/docker
    args:
      - build
      - -t
      - gcr.io/$PROJECT_ID/app:$SHORT_SHA
      - -t
      - gcr.io/$PROJECT_ID/app:latest
      - .

  # 5. Trivy でコンテナイメージ脆弱性スキャン
  - name: aquasec/trivy:latest
    entrypoint: trivy
    args:
      - image
      - --exit-code
      - "1"
      - --severity
      - HIGH,CRITICAL
      - --no-progress
      - gcr.io/$PROJECT_ID/app:$SHORT_SHA

  # 6. Docker イメージプッシュ
  - name: gcr.io/cloud-builders/docker
    args:
      - push
      - gcr.io/$PROJECT_ID/app:$SHORT_SHA

  # 7. Secret Manager からシークレット取得・テスト実行
  - name: gcr.io/google.com/cloudsdktool/cloud-sdk
    entrypoint: bash
    args:
      - '-c'
      - |
        DB_PASS=$(gcloud secrets versions access latest --secret=db-test-password)
        export DB_PASS
        echo "Running integration tests with secure credentials..."
        # ./run_tests.sh

  # 8. Binary Authorization 証明
  - name: gcr.io/google.com/cloudsdktool/cloud-sdk
    entrypoint: bash
    args:
      - '-c'
      - |
        gcloud container binauthz attestations sign-and-create \
          --artifact-url="gcr.io/$PROJECT_ID/app:$SHORT_SHA" \
          --attestor=prod-attestor \
          --attestor-project=$PROJECT_ID \
          --keyversion-project=$PROJECT_ID \
          --keyversion-location=us-central1 \
          --keyversion-keyring=binauthz-keys \
          --keyversion-key=prod-key \
          --keyversion=1

images:
  - gcr.io/$PROJECT_ID/app:$SHORT_SHA
  - gcr.io/$PROJECT_ID/app:latest

options:
  machineType: 'N1_HIGHCPU_8'
  logging: CLOUD_LOGGING_ONLY

timeout: '1800s'
```

---

## OPA Regoポリシー例

### Terraformポリシーチェック

```rego
package terraform.gcp

# 0.0.0.0/0 ingressルール禁止
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "google_compute_firewall"
  resource.change.after.direction == "INGRESS"
  resource.change.after.source_ranges[_] == "0.0.0.0/0"
  msg := sprintf("Firewall rule '%s' exposes resources to the internet (0.0.0.0/0)", [resource.address])
}

# Storage バケット公開禁止
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "google_storage_bucket_iam_member"
  resource.change.after.member == "allUsers"
  msg := sprintf("Storage bucket IAM '%s' grants public access (allUsers)", [resource.address])
}

# Owner/Editor ロール禁止
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "google_project_iam_member"
  resource.change.after.role == "roles/owner"
  msg := sprintf("IAM binding '%s' grants overly permissive role (roles/owner)", [resource.address])
}

# CMEK暗号化強制
warn[msg] {
  resource := input.resource_changes[_]
  resource.type == "google_storage_bucket"
  not resource.change.after.encryption
  msg := sprintf("Storage bucket '%s' should use CMEK encryption", [resource.address])
}
```

### Kubernetesポリシーチェック

```rego
package kubernetes.admission

# 外部IPサービス禁止
deny[msg] {
  input.request.kind.kind == "Service"
  input.request.object.spec.type == "LoadBalancer"
  input.request.object.spec.loadBalancerIP != ""
  msg := "External LoadBalancer IPs are prohibited. Use internal LoadBalancer or NodePort."
}

# 特権コンテナ禁止
deny[msg] {
  input.request.kind.kind == "Pod"
  container := input.request.object.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("Container '%s' cannot run in privileged mode", [container.name])
}

# hostNetwork禁止
deny[msg] {
  input.request.kind.kind == "Pod"
  input.request.object.spec.hostNetwork == true
  msg := "Pods cannot use hostNetwork"
}
```

---

## まとめ

DevSecOpsパイプラインへのセキュリティ自動化統合により、以下を実現:

1. **IaC（Terraform）**: セキュリティポリシーをコード化、一貫した環境構築
2. **CI/CDセキュリティゲート**: 各ステージで脆弱性スキャン・ポリシー検証を自動実行
3. **シークレット管理**: Secret Managerで集中管理、短命トークンでランタイム注入
4. **レガシー対応**: 段階的モダナイゼーション、既存パイプラインへのセキュリティレイヤー追加
5. **コンプライアンス強制**: PCI-DSS、HIPAA、金融規制に対応する自動化ゲート

**次章**では、GKEクラスタセキュリティ（ワークロード強化、ネットワークポリシー、Binary Authorization、サービス間通信）に焦点を移行。
