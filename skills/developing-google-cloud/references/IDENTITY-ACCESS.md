# Identity & Access Management (IAM)

Google CloudのID・アクセス管理（IAM）の実践ガイド。Resource Hierarchy、Organization Policy、Cloud Identity、IAM、Service Account、Workload Identity Federationの設計・運用ベストプラクティスを包括的に解説。

---

## Resource Hierarchy（リソース階層）

### 階層構造の基本

```
Organization（組織）
 └── Folder（フォルダ）
      └── Project（プロジェクト）
           └── Resources（リソース）
```

| 要素 | 説明 | 用途 |
|------|------|------|
| **Organization** | 最上位ノード。Cloud Identity/Workspaceアカウントに1対1対応 | 組織全体のポリシー適用、中央管理 |
| **Folder** | プロジェクトをグループ化（最大10階層） | 部門・チーム・製品ごとのポリシー境界設定 |
| **Project** | リソースの基本単位。完全に分離された環境 | ワークロード配置、課金単位、IAM適用ポイント |

### 主要な設計パターン

| 分離軸 | フォルダ構造例 | 適用場面 |
|--------|--------------|----------|
| **環境別** | `production/`, `staging/`, `development/` | 本番環境の厳格な分離が必要 |
| **部門別** | `engineering/`, `finance/`, `marketing/` | 組織構造に沿ったアクセス制御 |
| **製品別** | `product-a/`, `product-b/` | プロダクトチーム単位の権限委譲 |
| **データ分類別** | `pci-compliant/`, `hipaa-compliant/` | コンプライアンス要件による分離 |

### Project設計の判断基準

| 観点 | Projectを分ける場合 | Projectを統合する場合 |
|------|---------------------|----------------------|
| **Blast Radius** | ミスや侵害の影響範囲を最小化したい | 管理オーバーヘッドを減らしたい |
| **Quota管理** | 環境・チームごとに独立したQuotaが必要 | Quotaを共有して効率化したい |
| **IAM管理** | 最小権限原則を細かく適用したい | IAM管理を簡素化したい |
| **課金追跡** | 環境・製品単位で課金を分けたい | 課金を統合管理したい |
| **職務分離** | ネットワーク管理者と開発者を分けたい | 権限を集約したい |

### 複数Organizationの検討（原則非推奨）

**使用すべき場合:**
- 相互排他的なコンプライアンス要件（例: HIPAAデータとPCIデータの完全分離）

**デメリット:**
- 各OrganizationにCloud Identityアカウントが必要
- ユーザー・グループ・ドメインの独立管理が必要
- Organization-levelポリシーの重複管理
- Shared VPCが使用不可
- 組織横断機能が制限される

---

## Policy Inheritance（ポリシー継承）

### IAM Policy継承の仕組み

```
Organization Policy
    ↓（継承）
Folder Policy
    ↓（継承）
Project Policy
    ↓（継承）
Resource Policy
```

**有効ポリシー = リソースのポリシー ∪ 親のポリシー（トップダウン）**

### 継承の原則

| ルール | 説明 | 例 |
|--------|------|-----|
| **Union（和集合）** | リソースは親のポリシーをすべて継承 | Folderでアクセス許可 → 配下Project全体に適用 |
| **Additive（追加）** | 下位レベルで権限を追加可能 | Project固有の権限を追加 |
| **Non-revocable** | 下位レベルで親の権限を取り消せない | 上位で付与した権限は削除不可 |

### 実践例：Compute Engine IAMポリシー

```
Organization: Alice = compute.networkAdmin → instance_a, instance_b に適用
    Project_1: Bob = compute.instanceAdmin → instance_a のみ適用
    Project_2: Alice = compute.instanceAdmin → instance_b に適用（累積）
```

**結果:**
- Bob: `instance_a` へのcompute.instance.insert可能、`instance_b` へは不可
- Alice: 全instanceへのネットワーク管理権限 + `instance_b` へのインスタンス管理権限

---

## Organization Policy Service

### 概要

IAMが「誰が何にアクセスできるか」を制御するのに対し、Organization Policyは「リソースをどう構成できるか」を制約。

| 項目 | IAM | Organization Policy |
|------|-----|---------------------|
| 対象 | Who（誰） | What（何を制約） |
| 用途 | 認可・アクセス制御 | ガードレール・構成制約 |
| 適用方法 | Role binding | Constraint適用 |

### 推奨Constraint例

| Constraint | 説明 | セキュリティ効果 |
|------------|------|------------------|
| `compute.disableSerialPortAccess` | シリアルポートアクセス無効化 | 不正アクセス防止 |
| `compute.vmExternalIpAccess` | 外部IP割当制限 | 攻撃面縮小 |
| `storage.uniformBucketLevelAccess` | Bucket統一アクセス制御強制 | ACL複雑性回避 |
| `iam.disableServiceAccountKeyCreation` | Service Accountキー作成禁止 | キー漏洩リスク削減 |

### Policy継承ルール

| シナリオ | 動作 |
|----------|------|
| **ポリシー未定義** | Constraintのデフォルト動作を強制 |
| **inheritFromParent = true** | 親ポリシーとマージして評価 |
| **inheritFromParent = false** | ノードレベルポリシーのみ適用 |
| **競合（Allow vs Deny）** | **DENY優先** |
| **Boolean constraint** | マージせず、最も具体的なポリシーを適用 |

### gcloud CLI例

```bash
# Organization Policyの表示
gcloud resource-manager org-policies describe \
  constraints/compute.disableSerialPortAccess \
  --project=PROJECT_ID

# Policyの設定
gcloud resource-manager org-policies set-policy policy.yaml \
  --project=PROJECT_ID
```

---

## Cloud Asset Inventory

### 主要機能

| 機能 | 説明 | 用途 |
|------|------|------|
| **Asset Search** | IAM Policy・リソースのクエリ検索 | 権限監査、リソース棚卸し |
| **Asset Export** | Cloud Storage/BigQueryへのエクスポート | 長期保管、分析 |
| **Asset Monitoring** | Cloud Pub/Subでリアルタイム通知 | 変更検知、アラート |
| **Policy Analyzer** | 「誰が何にアクセスできるか」の分析 | アクセス影響評価 |

### 実践クエリ例

```bash
# 組織内の全IAM Policyを検索
gcloud asset search-all-iam-policies \
  --scope=organizations/123456

# Owner権限を持つService Accountを検出（リスク検出）
gcloud asset search-all-iam-policies \
  --scope=organizations/123456 \
  --query='policy:roles/owner serviceAccount' \
  --flatten='policy.bindings[].members' \
  | grep serviceAccount

# allUsersを含むリソースを検出（公開設定検出）
gcloud asset search-all-iam-policies \
  --query='allUsers'

# gmail.comユーザーを検出（外部アクセス検出）
gcloud asset search-all-iam-policies \
  --query='gmail.com \*setIamPolicy'
```

### 5週間履歴の活用

- 過去5週間の変更履歴を参照可能
- 誤削除・誤変更の復旧に有効
- コンプライアンス監査の証跡として活用

---

## Cloud Identity

### 概要

Google CloudのIDaaS（Identity as a Service）。認証（Authentication）を提供し、認可（Authorization）はCloud IAMが担当。

| 項目 | Cloud Identity | Cloud IAM |
|------|----------------|-----------|
| 機能 | 認証・ユーザー管理 | 認可・アクセス制御 |
| 管理URL | admin.google.com | console.cloud.google.com |
| 対象 | ユーザー・グループ・デバイス | Role・Permission・Policy |

### Free vs Premium

| 機能 | Free | Premium |
|------|------|---------|
| ユーザー数 | 50（要申請で増加可） | 無制限 |
| Secure LDAP | ❌ | ✅ |
| Security Center | ❌ | ✅ |
| MDM | ❌ | ✅ |
| BigQuery監査ログ自動エクスポート | ❌ | ✅ |
| Session Length管理 | ❌ | ✅ |
| SLA | なし | 99.9% |

### Super Administrator Best Practices

| ルール | 理由 |
|--------|------|
| **2SV/MFA必須** | アカウント保護 |
| **バックアップセキュリティキー保管** | 復旧手段確保 |
| **Device Trust無効化** | 信頼端末への依存回避 |
| **Webセッション長短縮** | セッションハイジャック防止 |
| **最大4アカウント** | 単一障害点回避 |
| **リカバリー電話・メール設定** | アクセス喪失対策 |
| **Break-glass専用アカウント作成** | 緊急時対応 |
| **Cloud Identity管理役割の委譲** | 職務分離 |
| **console.cloud.google.comへの直接アクセス禁止** | 権限分離 |

### 2-Step Verification (2SV)

| 方式 | 説明 | セキュリティレベル |
|------|------|-------------------|
| **Security Keys** | 物理キー（Titan Key, YubiKey） | 最高（Phishing耐性） |
| **Google Prompt** | モバイル端末への通知 | 高 |
| **Code Generators** | TOTP（Google Authenticator, Authy） | 中 |
| **Backup Codes** | 印刷コード | 低（オフライン用） |
| **SMS/Call** | ワンタイムパスワード | 低（SIM Swap脆弱） |

**推奨設定:**
```
Enforcement: On（即座適用）
Trust Device: Off（Cookie依存回避）
Methods: Only security key（最高セキュリティ）
```

### Session Length Control

```bash
# Google Cloud専用セッション制御
Security → Access and Data Control → Google Cloud session control

# 設定項目
Reauthentication policy: Require reauthentication
Reauthentication frequency: 1-24時間
Reauthentication method: Password / Security Keys（推奨）
```

**適用対象:**
- Google Cloud Console
- gcloud CLI
- Google Cloud SDK
- サードパーティアプリ（Google Cloud Scopes利用）

**対象外:**
- Google Cloud Mobile App

---

## SAML-based SSO

### 設定フロー

```
1. ACS URLとEntity IDを取得
2. Cloud Identityでカスタム SAML App追加
3. IdP Metadata（SSO URL, Entity, Certificate）をダウンロード
4. Service ProviderにIdP情報を設定
5. Service Provider情報（ACS URL, Entity ID）をCloud Identityに登録
6. 属性マッピング設定（オプション）
```

### 設定コマンド

```bash
# admin.google.comから実行
Apps → Web and mobile apps → Add app → Add custom SAML app

# 必須情報
ACS URL: サービスプロバイダーのエンドポイント
Entity ID: サービスプロバイダーから提供
Name ID: デフォルトはPrimary Email（カスタム属性可）
Signed response: 全体署名（デフォルトはAssertion署名）
```

---

## Google Cloud Directory Sync (GCDS)

### 概要

Active Directory/LDAPとCloud Identityを一方向同期（AD/LDAP → Cloud Identity）。

### 同期対象

| 項目 | 説明 |
|------|------|
| **Users** | ユーザーアカウント・属性 |
| **Groups** | グループ・メンバーシップ |
| **Organizational Units** | 組織単位 |
| **Extended Attributes** | 拡張属性（選択可） |

### 設定フロー

```
1. GCDSダウンロード・インストール（専用サーバー推奨）
2. LDAP構造調査（Base DN, Security Groups）
3. OAuth token生成（admin.google.com）
4. Configuration Manager起動
   ├── Google Domain Configuration（OAuth認証）
   ├── LDAP Configuration（接続情報）
   ├── User/Group Sync設定（包含・除外ルール）
   └── Notification/Logging設定
5. シミュレーション実行
6. 同期開始（自動スケジュール推奨）
```

### ベストプラクティス

| 項目 | 推奨 |
|------|------|
| **インストール先** | 専用サーバー（共有環境避ける） |
| **接続方式** | Secure LDAP（TLS） |
| **スケジュール** | 自動化（cron/Task Scheduler） |
| **監視** | 同期失敗アラート設定 |
| **Single Source of Truth** | 単一LDAP（複数統合避ける） |

---

## User Provisioning

### プロビジョニング方式の比較

| 方式 | 工数 | スケーラビリティ | セキュリティ | 推奨場面 |
|------|------|------------------|------------|----------|
| **手動追加** | 低 | ❌ | 中 | 5-10ユーザー |
| **CSV一括アップロード** | 中 | ⚠️ | 低（パスワード平文） | 初期セットアップ |
| **GCDS** | 高（初期） | ✅ | 高 | **推奨：100+ユーザー** |
| **サードパーティIdP** | 高（初期） | ✅ | 高 | 商用IdP利用組織 |

### GCDS vs サードパーティIdP

```
【GCDS】
Active Directory → GCDS → Cloud Identity → Google Cloud

【サードパーティIdP（Okta/Ping Identity）】
Active Directory → Okta → Cloud Identity → Google Cloud
                     ↓
               SAML/OIDC Federation
```

### Directory API（プログラマティック管理）

```bash
# User lifecycle操作
POST /admin/directory/v1/users          # ユーザー作成
PUT /admin/directory/v1/users/{userId}  # ユーザー更新
DELETE /admin/directory/v1/users/{userId} # ユーザー削除
POST /admin/directory/v1/users/{userId}/makeAdmin # 管理者権限付与

# Group lifecycle操作
POST /admin/directory/v1/groups         # グループ作成
POST /admin/directory/v1/groups/{groupId}/members # メンバー追加
GET /admin/directory/v1/groups?userKey={userId} # ユーザーの所属グループ取得
```

---

## IAM（Identity and Access Management）

### IAM基本原則

```
Who（Principal） + What（Role） + Which（Resource） = Access
```

| 要素 | 説明 | 例 |
|------|------|-----|
| **Principal** | アクセス主体 | user, serviceAccount, group |
| **Role** | 権限の集合 | roles/bigquery.dataViewer |
| **Resource** | アクセス対象 | BigQuery Dataset, Cloud Storage Bucket |

### Principal（プリンシパル）の種類

| タイプ | 識別子 | 用途 |
|--------|--------|------|
| **Google Account** | user:alice@example.com | 個人ユーザー |
| **Service Account** | serviceAccount:my-app@project.iam.gserviceaccount.com | アプリケーション |
| **Google Group** | group:developers@example.com | ユーザーグループ |
| **Workspace Domain** | domain:example.com | 組織全体 |
| **Cloud Identity Domain** | domain:example.com | 組織全体（Workspace機能なし） |
| **allAuthenticatedUsers** | allAuthenticatedUsers | 認証済みGoogle Identity全員 |
| **allUsers** | allUsers | インターネット上の全員（匿名含む） |

---

## IAM Roles

### Basic Roles（レガシー・非推奨）

| Role | 権限範囲 | 推奨 |
|------|---------|------|
| **Viewer** | 読み取り専用 | ⚠️ 開発環境のみ |
| **Editor** | Viewer + 変更権限 | ❌ 本番環境非推奨 |
| **Owner** | Editor + Role管理 | ❌ 個人付与禁止 |

### Predefined Roles（推奨）

```
例：BigQuery Roles
├── BigQuery Admin: 完全管理
├── BigQuery Data Owner: データセット所有
├── BigQuery Data Editor: データ編集
├── BigQuery Data Viewer: データ参照
├── BigQuery Job User: ジョブ実行
└── BigQuery Resource Viewer: メタデータ参照
```

### Predefined Role選択フロー

```
1. 必要な権限（Permission）を特定
2. Permissionを含むRoleを検索
3. 最小権限の原則（Least Privilege）でRole選択
4. 適用レベル（Resource/Project/Folder/Organization）決定
5. IAM Conditions適用（必要に応じて）
```

### Custom Roles

| 作成理由 | 例 |
|---------|-----|
| **権限削減** | Predefined Roleから不要な権限を除外 |
| **組み合わせ** | 複数Predefined Roleの特定Permissionのみ組み合わせ |
| **組織固有要件** | 独自の職務に合わせたRole |

**制約:**
- Project-level Custom Roleは、Organization/Folder-level Permissionを含められない
- Custom Roleは作成元Project/Organization内でのみ使用可能
- `TESTING`/`NOT_SUPPORTED` Permissionは使用不可

### 強力なPermissionの識別

| 強力（High-risk） | 弱い（Low-risk） |
|------------------|-----------------|
| リソース作成・削除 | リソース一覧表示 |
| 暗号鍵・PII情報アクセス | 非機密データ参照 |
| IAM Policy設定 | 設定参照 |
| 組織構造変更 | メタデータ参照 |

---

## Service Accounts

### 概要

アプリケーション・ワークロード用のID。人間のユーザーとは異なる特性を持つ。

| 特性 | Service Account | User Account |
|------|-----------------|--------------|
| Console ログイン | ❌ | ✅ |
| 認証方式 | RSA鍵ペア/WIF | パスワード/2SV |
| Impersonation | 可能 | 不可 |
| Cloud Identity | 非表示 | 表示 |
| 管理場所 | console.cloud.google.com | admin.google.com |

### Lifecycle管理

| 操作 | コマンド | 注意点 |
|------|---------|--------|
| **作成** | `gcloud iam service-accounts create SA_NAME` | roles/iam.serviceAccountAdmin必要 |
| **無効化** | `gcloud iam service-accounts disable SA_EMAIL` | リソースがアクセス不可になる |
| **削除** | `gcloud iam service-accounts delete SA_EMAIL` | Role bindingは60日後自動削除 |
| **復元** | `gcloud iam service-accounts undelete SA_NUMERIC_ID` | 30日以内、同名SAがない場合のみ |

### Service Account Keys

#### ⚠️ キー使用回避の決定木

```
キーが必要か？
├─ No → Workload Identity / Workload Identity Federation使用 ✅
└─ Yes → 以下を確認
    ├─ Google Cloud内？
    │   ├─ Compute Engine/GKE → Metadata Server認証 ✅
    │   └─ Cloud Run/Functions → デフォルトSA ✅
    ├─ オンプレミス/他クラウド？
    │   ├─ AWS/Azure → Workload Identity Federation ✅
    │   └─ 独自IdP → Workload Identity Federation ✅
    └─ レガシーシステム？
        └─ Service Account Key（最終手段）⚠️
```

#### キー管理ベストプラクティス

| ルール | 推奨値 | 理由 |
|--------|-------|------|
| **キーローテーション** | 毎日（開発）、1週間以内（本番） | 漏洩リスク最小化 |
| **キー数制限** | 最小限（上限10） | 管理負荷軽減 |
| **開発環境分離** | 本番リソースアクセス禁止 | Blast Radius削減 |
| **キー監査** | serviceAccount.keys.list() API使用 | 不正使用検出 |
| **Git コミット防止** | git secretsツール導入 | 漏洩防止 |
| **定期スキャン** | Trufflehog等で検出 | 漏洩検知 |

#### キーローテーション実装

```bash
# keyrotatorツール使用（Python CLI）
# cron設定例
0 0 * * * /usr/local/bin/keyrotator \
  --project=PROJECT_ID \
  --sa=SA_EMAIL \
  --bucket=gs://keys-bucket

# 手動ローテーション
gcloud iam service-accounts keys create new-key.json \
  --iam-account=SA_EMAIL
# 古いキーを削除
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=SA_EMAIL
```

#### Git Secrets防止

```bash
# git secretsインストール
git secrets --install
git secrets --register-aws  # AWS用パターン

# GCP Service Account Key検出パターン追加
git secrets --add 'private_key'
git secrets --add 'private_key_id'
git secrets --add 'iam.gserviceaccount.com'

# スキャン実行
git secrets --scan

# Trufflehog使用（GitHub等リポジトリ全体スキャン）
trufflehog git https://github.com/myorg/myrepo
```

---

## Service Account Impersonation

### 概要

他のユーザー・リソースがService Accountとして動作する仕組み。

| Role | Permission | 用途 |
|------|-----------|------|
| **Service Account User** | iam.serviceAccounts.actAs | リソースへのSA紐付け |
| **Service Account Token Creator** | iam.serviceAccounts.getAccessToken | OAuth Token生成、JWT署名 |
| **Workload Identity User** | iam.serviceAccounts.getOpenIdToken | GKE/外部ワークロード認証 |

### 権限付与レベルの考慮

| 付与レベル | 影響範囲 | 推奨 |
|-----------|---------|------|
| **Organization/Folder/Project** | 配下全SA | ❌ 非推奨（過剰権限） |
| **特定SA** | 単一SA | ✅ 推奨（最小権限） |

---

## Cross-Project Service Account Access

### 設計パターン

```
Project A（SA専用管理Project）
    └── my-sa@project-a.iam.gserviceaccount.com
            ↓ actAs
Project B（アプリケーションProject）
    └── Compute Engine Instance（SA: my-sa）
```

### Organization Policy設定

```bash
# Project Aで設定（SA所在地）
iam.disableCrossProjectServiceAccountUsage: false（デフォルト）
iam.restrictCrossProjectServiceAccountLienRemoval: true（推奨）

# Project Lienの確認
gcloud resource-manager liens list --project=PROJECT_A
# origin: iam.googleapis.com/cross-project-service-accounts
```

**注意点:**
- Project Lien削除は組織レベル権限が必要
- 設計変更後のポリシー変更は避ける（本番環境リスク）

---

## Workload Identity Federation (WIF)

### 概要

Service Account Key不要で、外部IdP（Okta, AWS, Azure）から短命Tokenでアクセス。

### Okta連携フロー

```
1. Application → Okta Authorization Server
   ├─ Client Credentials（Client ID + Secret）送信
   └─ OIDC Token取得

2. Application → Google STS (Security Token Service)
   ├─ OIDC Token送信
   └─ Google Access Token取得

3. Application → Google Cloud API
   └─ Access Tokenで認証
```

### 設定手順

```bash
# 1. Workload Identity Pool作成
gcloud iam workload-identity-pools create workload-id-pool1 \
  --location=global \
  --display-name="Okta WIF Pool"

# 2. OIDC Provider作成
gcloud iam workload-identity-pools providers create-oidc okta-provider \
  --workload-identity-pool=workload-id-pool1 \
  --issuer-uri="https://your-domain.okta.com/oauth2/default" \
  --location=global \
  --attribute-mapping="google.subject=assertion.sub" \
  --allowed-audiences="CLIENT_ID"

# 3. Service AccountにIAM Policy Binding追加
gcloud iam service-accounts add-iam-policy-binding SA_EMAIL \
  --role=roles/iam.workloadIdentityUser \
  --member="principal://iam.googleapis.com/projects/PROJECT_NUM/locations/global/workloadIdentityPools/workload-id-pool1/subject/OKTA_SUB"

# 4. 認証情報ファイルダウンロード
gcloud iam workload-identity-pools create-cred-config \
  projects/PROJECT_NUM/locations/global/workloadIdentityPools/workload-id-pool1/providers/okta-provider \
  --service-account=SA_EMAIL \
  --output-file=credentials.json
```

---

## Service Account監視

### Cloud Monitoringメトリクス

| メトリクス | 説明 | 用途 |
|-----------|------|------|
| **Service account authentication events** | SA認証イベント | 使用パターン分析 |
| **Service account key authentication events** | SAキー認証イベント | キー使用監視 |

### 監視設定

```bash
# Metrics Explorerから設定
Google Cloud Console → Monitoring → Metrics Explorer
    ├─ Resource Type: IAM Service Account
    ├─ Metric: Service account authentication events
    └─ Filter/Group By: service_account_id

# BigQueryへのエクスポート（長期分析用）
gcloud logging sinks create sa-audit-sink \
  bigquery.googleapis.com/projects/PROJECT_ID/datasets/sa_audit \
  --log-filter='resource.type="service_account"'
```

### Activity Analyzer活用

- **Service Account Insights**: 90日間未使用SAを検出
- **Recommendation Hub**: IAM最適化提案
- **未使用SA無効化**: セキュリティリスク削減

---

## IAM Policy Bindings

### Policy構造

```json
{
  "bindings": [
    {
      "role": "roles/bigquery.dataViewer",
      "members": [
        "user:alice@example.com",
        "serviceAccount:app@project.iam.gserviceaccount.com"
      ]
    }
  ],
  "etag": "BwUjMhCsZpY=",
  "version": 1
}
```

| フィールド | 説明 |
|-----------|------|
| **bindings** | Role bindingの配列 |
| **role** | 付与するRole（roles/*） |
| **members** | Principalのリスト |
| **etag** | 並行制御用（楽観的ロック） |
| **version** | ポリシースキーマバージョン（1-3） |

### Policy制限

| 制限項目 | 値 | 注意点 |
|---------|-----|--------|
| **最大Principal数** | 1,500 | IAM Conditions使用時は削減される可能性 |
| **最大グループ数** | 250 | 個別カウント（メンバー数無関係） |
| **重複Principal** | 重複削除なし | 同一Principalが複数Bindingに存在可能 |
| **Policy反映時間** | 60秒（通常）、最大7分 | 即座反映を期待しない |

### Conditional Role Binding

```json
{
  "bindings": [
    {
      "role": "roles/appengine.deployer",
      "members": ["group:prod@example.com"],
      "condition": {
        "title": "Expires_July_1_2024",
        "description": "Time-limited access",
        "expression": "request.time < timestamp('2024-07-01T00:00:00.000Z')"
      }
    }
  ],
  "version": 3
}
```

**条件要素:**
- **Variables**: `request.time`, `resource.name`, `resource.service`
- **Operators**: `==`, `!=`, `<`, `>`, `<=`, `>=`
- **Functions**: `startsWith()`, `endsWith()`, `matches()`
- **Logical Operators**: `&&`, `||`, `!`（最大12個）

---

## IAM Conditions

### 条件文の構造

| 要素 | 必須 | 説明 |
|------|------|------|
| **title** | ✅ | 条件の名前 |
| **description** | - | 説明（推奨） |
| **expression** | ✅ | CEL（Common Expression Language）式 |

### 実践例

| ユースケース | 条件式 |
|-------------|--------|
| **時刻制限** | `request.time < timestamp('2024-12-31T23:59:59Z')` |
| **IP制限** | `request.auth.claims.iss == "https://accounts.google.com" && inIpRange(origin.ip, '203.0.113.0/24')` |
| **リソース名制限** | `resource.name.startsWith("projects/my-project/")` |
| **Service制限** | `resource.service == "compute.googleapis.com"` |

---

## Policy Intelligence（IAM最適化）

### 3つのツール

| ツール | 機能 | 用途 |
|--------|------|------|
| **IAM Recommender** | AI-powered過剰権限検出・削減提案 | 最小権限原則適用 |
| **Policy Analyzer** | セキュリティリスク・違反検出 | リスク可視化 |
| **Policy Troubleshooter** | アクセス可否診断 | 権限トラブルシューティング |

### IAM Recommenderの活用

```bash
# 推奨事項の取得
gcloud recommender recommendations list \
  --project=PROJECT_ID \
  --location=global \
  --recommender=google.iam.policy.Recommender

# 推奨事項の適用
gcloud recommender recommendations mark-claimed RECOMMENDATION_ID \
  --project=PROJECT_ID \
  --location=global \
  --recommender=google.iam.policy.Recommender
```

---

## IAM Best Practices

### 権限設計の原則

| 原則 | 実践方法 |
|------|---------|
| **最小権限** | 必要最小限のRoleのみ付与 |
| **グループ活用** | 個人ではなくGroupにRole付与 |
| **Organization-level慎重** | 全社権限は最小限（Security/Network Team等） |
| **Folder-level階層化** | 部門→チーム→製品で段階的権限設定 |
| **Project-level詳細化** | 必要に応じて個別Project権限 |
| **Conditions活用** | IP・時刻・リソース制約で細粒度制御 |

### 特権Role管理

| 施策 | 内容 |
|------|------|
| **RBAC適用** | 職務別Role定義 |
| **職務分離** | 重要機能の分割担当 |
| **Dual Control** | 重要操作の複数承認 |
| **定期監査** | 不要権限の削除 |
| **監視・ログ** | 特権操作の追跡 |
| **教育・トレーニング** | セキュリティ意識向上 |

---

## Tag-based Access Control

### Tag構造

```
Tag Key: env（Namespaced: 123456789012/env）
├─ Tag Value: prod（永続ID: tagValues/281484823856）
└─ Tag Value: dev（永続ID: tagValues/281484823857）
```

### 条件付きIAM例

```json
{
  "role": "roles/compute.instanceAdmin.v1",
  "members": ["group:prod-admins@example.com"],
  "condition": {
    "title": "prod-env-only",
    "expression": "resource.matchTag('123456789012/env', 'prod')"
  }
}
```

### ベストプラクティス

| 原則 | 実践 |
|------|------|
| **一貫性** | 組織全体で統一されたTag戦略 |
| **階層化** | リソース階層に沿ったTag構造 |
| **説明的** | 目的・所有者・属性が明確なTag |
| **Security/Compliance Tag** | セキュリティ要件・規制対応用Tag |
| **所有者Tag** | 責任者・チーム明示 |
| **自動化** | Tagging Policy自動適用 |
| **定期レビュー** | 未使用Tag削除 |

---

## Cloud Storage ACLs vs IAM

### アクセス制御方式の選択

| 方式 | 推奨 | 理由 |
|------|------|------|
| **Uniform Bucket-level Access (IAM)** | ✅ | 一貫性・シンプル・Conditions対応 |
| **Fine-grained ACLs** | ⚠️ | 複雑・レガシー・Conditions非対応 |

### ACL Permission（Concentric）

```
OWNER ⊃ WRITER ⊃ READER

OWNER: WRITER + READER + ACL管理
WRITER: READER + オブジェクト作成・削除
READER: オブジェクト読み取り
```

### Uniform Bucket-level Access有効化

```bash
# 有効化（90日以内は復元可能）
gsutil uniformbucketlevelaccess set on gs://BUCKET_NAME

# 確認
gsutil uniformbucketlevelaccess get gs://BUCKET_NAME
```

**有効化後の変更:**
- Bucket/Object ACLsが無効化
- IAMのみでアクセス制御
- IAM Conditions使用可能
- Domain Restricted Sharing対応

---

## IAM Logging

### ログタイプ

| ログ | リソースタイプ | 用途 |
|------|---------------|------|
| **Admin Activity** | iam_role, service_account | Role/SA作成・変更・削除 |
| **Data Access** | service_account | SAによるAPIアクセス |
| **System Event** | service_account | システム生成イベント |
| **Policy** | iam_role | Policy変更 |

### ログ名の形式

```
projects/PROJECT_ID/logs/cloudaudit.googleapis.com%2Factivity
projects/PROJECT_ID/logs/cloudaudit.googleapis.com%2Fdata_access
folders/FOLDER_ID/logs/cloudaudit.googleapis.com%2Factivity
organizations/ORG_ID/logs/cloudaudit.googleapis.com%2Fpolicy
```

### Service Account関連ログ

| イベント | ログ内容 |
|---------|---------|
| **SA作成** | google.iam.admin.v1.CreateServiceAccount |
| **Role付与** | google.iam.admin.v1.SetIamPolicy |
| **Key作成** | google.iam.admin.v1.CreateServiceAccountKey |
| **Key認証** | google.iam.credentials.v1.SignJwt |
| **Impersonation** | google.iam.credentials.v1.GenerateAccessToken |

### ログクエリ例

```sql
-- Owner権限を持つSAを検出
SELECT
  protoPayload.authenticationInfo.principalEmail,
  protoPayload.authorizationInfo.permission,
  timestamp
FROM `PROJECT_ID.cloudaudit_googleapis_com_data_access_*`
WHERE protoPayload.authorizationInfo.permission LIKE '%roles/owner%'
  AND protoPayload.authenticationInfo.principalEmail LIKE '%iam.gserviceaccount.com'
ORDER BY timestamp DESC
```

---

## IAM Recommender活用フロー

```
1. Cloud Console → IAM → Recommendations
2. 推奨事項レビュー
   ├─ Role削減提案
   ├─ Custom Role作成提案
   └─ 過剰権限検出
3. 影響分析（Policy Troubleshooter使用）
4. 推奨事項適用
5. 継続監視（Policy Intelligence Dashboard）
```

---

## gcloud CLI Quick Reference

```bash
# Organization Policy
gcloud resource-manager org-policies describe CONSTRAINT --project=PROJECT_ID
gcloud resource-manager org-policies set-policy policy.yaml --project=PROJECT_ID

# Cloud Asset Inventory
gcloud asset search-all-iam-policies --scope=organizations/ORG_ID
gcloud asset search-all-resources --query="name:*PATTERN*"

# IAM Policy
gcloud projects get-iam-policy PROJECT_ID
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=user:USER_EMAIL --role=ROLE

# Service Accounts
gcloud iam service-accounts create SA_NAME --display-name="Display Name"
gcloud iam service-accounts keys create key.json --iam-account=SA_EMAIL
gcloud iam service-accounts delete SA_EMAIL

# Workload Identity Federation
gcloud iam workload-identity-pools create POOL_ID --location=global
gcloud iam workload-identity-pools providers create-oidc PROVIDER_ID \
  --workload-identity-pool=POOL_ID --issuer-uri=ISSUER_URL

# IAM Recommender
gcloud recommender recommendations list \
  --project=PROJECT_ID --recommender=google.iam.policy.Recommender
```

---

**関連スキル:** `developing-google-cloud`, `securing-code`, `implementing-dynamic-authorization`
**公式ドキュメント:** https://cloud.google.com/iam/docs
**Best Practices:** https://cloud.google.com/iam/docs/best-practices
