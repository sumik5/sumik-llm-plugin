# Terraform CD・デプロイメント

継続的デリバリー（CD）とデプロイメント戦略、GitOps実践、CDプラットフォーム比較。

---

## 目次

1. [モジュール配信](#モジュール配信)
2. [インフラデプロイメント](#インフラデプロイメント)
3. [GitOps](#gitops)
4. [プロジェクト構造パターン](#プロジェクト構造パターン)
5. [シークレット管理](#シークレット管理)
6. [CDプラットフォーム機能](#cdプラットフォーム機能)
7. [CDプラットフォーム概要](#cdプラットフォーム概要)

---

## モジュール配信

### Semantic Versioning

**必須**: すべてのモジュールはSemantic Versioning 2.0に従う

**バージョンフォーマット: `vMAJOR.MINOR.PATCH`**

| フィールド | 変更内容 | 例 |
|----------|---------|-----|
| MAJOR | 後方互換性を破る変更 | 変数名変更、リソース削除 |
| MINOR | 後方互換性のある新機能追加 | 新しい変数・出力追加 |
| PATCH | バグ修正 | ドキュメント改善、検証修正 |

**変更例とバージョン:**

| 変更内容 | 更新フィールド | バージョン |
|---------|-------------|----------|
| 初回安定リリース | - | v1.0.0 |
| 変数検証エラー修正 | PATCH | v1.0.1 |
| ドキュメント改善 | PATCH | v1.0.2 |
| 新しいリソースパラメータ公開 | MINOR | v1.1.0 |
| TFlintルール違反修正 | PATCH | v1.1.1 |
| 入力変数名リファクタリング | MAJOR | v2.0.0 |

### バージョン制約

**制約演算子:**

| 制約 | 許可バージョン |
|-----|-------------|
| `= 1.1.1` | v1.1.1のみ |
| `>= 1.1.0, < 2.0.0` | v1.1.0〜v1.x.x（メジャーアップ禁止） |
| `>= 1.1.0, < 2.0.0, != 1.3.2` | 上記 + v1.3.2を除外 |
| `~> 1.1.0` | v1.1.x（パッチのみ更新） |
| `~> 1.1` | v1.x.x（マイナー・パッチ更新可） |

**推奨: Pessimistic Constraint Operator (`~>`)**

```hcl
module "example" {
  source  = "registry.example.com/org/module"
  version = "~> 1.1"  # v1.1.0〜v1.x.x
}
```

**モジュール開発者向け推奨:**
- 最小バージョンを指定
- マイナー・パッチ更新を許可（`~> 1.1`）
- メジャーバージョンアップは制限（後方互換性ブレーク）

### SCMベース配信

**GitHub Shortcut:**

```hcl
module "lambda" {
  source = "github.com/tedivm/terraform-aws-lambda"
}
```

**Generic Git:**

```hcl
module "lambda" {
  source = "git@github.com:tedivm/terraform-aws-lambda.git?ref=v1.0.1"
}
```

**制限:**
- `version`フィールド非対応
- `ref`で特定バージョン指定可能だが、範囲指定不可

**トレードオフ:**
- デフォルトブランチから取得 → 予期しない破壊的変更リスク
- `ref`でピン留め → バグ修正の自動適用不可

**推奨用途:**
- 開発ブランチのテスト
- 小規模チーム
- 本番環境は避ける

### 公開レジストリ

**主要レジストリ:**
- **OpenTofu Registry**: OpenTofu公式（オープンソース）
- **HashiCorp Terraform Registry**: Terraform公式（利用制限あり）

**登録手順:**

1. **前提条件:**
   - GitHubパブリックリポジトリ
   - Semantic Versioningタグ

2. **OpenTofu Registry:**
   - [OpenTofu.org](https://opentofu.org/)の登録フォーム経由

3. **HashiCorp Registry:**
   - [registry.terraform.io](https://registry.terraform.io/)にログイン
   - Publish → Module → GitHubリポジトリ選択

**自動更新:**
- Gitタグ作成時に自動的にレジストリに反映

### プライベートレジストリ

**利点:**
- 社内専用モジュール管理
- アクセス制御
- バージョン制約のフル活用

**ログイン:**

```bash
terraform login registry.example.com
```

**認証フロー:**
1. ブラウザでトークンページを開く
2. トークン生成
3. トークンをCLIに貼り付け
4. `~/.terraform.d/credentials.tfrc.json`に保存

**オープンソース選択肢:**
- **Terrareg**: セルフホスト可能なプライベートレジストリ

**商用選択肢:**
- HCP Terraform、Spacelift、Env0等のCDプラットフォームに統合

### Artifactory

**特徴:**
- JFrog製商用レジストリ
- 多言語対応（Terraform、npm、PyPI等）
- エンタープライズ向け

**推奨:**
- すでにArtifactoryライセンスがある場合
- 統一されたアーティファクト管理が必要な場合

---

## インフラデプロイメント

### デプロイメントとは

**定義:**
`terraform apply`を実行するたびにデプロイメントが発生。

**デプロイメント構成要素:**
- Terraformコード
- 変数
- 新しいステートバージョン
- 実際のインフラストラクチャ

**ローカルデプロイメントの問題:**
- 複数開発者が同時に異なる変更を適用
- ステートロックは同時実行を防ぐが、上書きは防げない
- 誰がどの変更を適用したか追跡困難

**解決策: 中央集約化**
- 単一の信頼できる情報源（SCM）
- 自動デプロイメント
- GitOps実践

### 環境

**環境の種類:**

| 環境タイプ | 用途 | 特徴 |
|----------|-----|------|
| Feature環境 | 開発者個人のテスト | 一時的、ローカルバックエンド |
| Staging環境 | 統合テスト、手動テスト | 本番環境に近い構成 |
| Production環境 | 実運用 | 厳格なアクセス制御 |

**環境分離パターン:**

1. **Staging → Production**

```
Developer → Staging → Production
```

2. **リージョン別**

```
Production (Asia)
Production (Europe)
Production (North America)
```

3. **顧客別**

```
Customer A (Production)
Customer B (Production)
Customer C (Production)
```

**環境分離要件:**
- 独立したアカウント/ネットワーク
- 独立したステート
- 独立した変数
- 相互依存なし

### CD（継続的デリバリー）

**原則:**
1. **CI基盤**: 高品質な自動テスト
2. **自動化**: 人手を介さないデプロイメント
3. **小さく頻繁に**: 1日複数回の小規模デプロイ

**メリット:**
- 変更によるリスク低減
- 問題の原因特定が容易
- デプロイ時間短縮

### デプロイメント要件

**必須要件:**
1. **アクセス**: プラットフォームへの認証・ネットワークアクセス
2. **時間**: 長時間実行ジョブ（DB作成等）への対応
3. **一貫性**: 同一環境への同時デプロイ防止

**中央集約システムの利点:**
- ネットワークアクセス管理
- ジョブキューイング
- 高可用性
- ラップトップスリープによる失敗回避

---

## GitOps

### GitOps 4原則（CNCF定義）

1. **宣言的**: 望ましい状態を宣言的に表現
2. **バージョン管理・不変**: Git等でバージョン管理、完全な履歴保持
3. **自動プル**: ソフトウェアエージェントが自動的に状態宣言を取得
4. **継続的調整**: 実際のシステム状態と望ましい状態を継続的に調整

### GitOpsとTerraform

**Terraformの適合性:**
- ✅ 宣言的言語
- ✅ ステートのバージョン管理・不変性
- ✅ 継続的調整（ドリフト検出・修正）
- ❌ 自動プル機能なし → CDプラットフォームで補完

**GitOpsが追加する要素:**
1. **SCMを信頼できる情報源として使用**
   - Gitリポジトリ = 実行中インフラの設定
   - 変更履歴 = 監査ログ

2. **自動プル**
   - CDプラットフォームがGitからコードを取得
   - Terraformに渡して実行

### GitOps開発ワークフロー

**標準フロー:**

1. 開発者がGitリポジトリから最新変更をチェックアウト、ブランチ作成
2. ローカル開発（一時環境でテスト）
3. Pull Request作成:
   - a. 自動テスト実行
   - b. Speculative Plan実行（変更内容プレビュー）
   - c. コードレビュー
4. メインブランチにマージ
5. **自動デプロイメント**

```
Branch → PR (Tests + Plan) → Review → Merge → Deploy
```

### 継続的調整

**ドリフト対策:**
- 定期的なPlan実行（例: 1時間ごと）
- ドリフト検出時のSlack通知
- 自動修正（オプション）

**CI vs CD:**
- **CI**: PRベースの品質チェック
- **CD**: 定期実行によるドリフト検出・修正

---

## プロジェクト構造パターン

### パターン1: アプリケーションasルートモジュール

**構造:**
```
app/
├── main.tf          # 再利用可能モジュールを呼び出し
├── variables.tf     # 環境固有の変数
├── outputs.tf
└── environments/
    ├── staging.tfvars
    └── production.tfvars
```

**特徴:**
- 1つのルートモジュールで全環境を管理
- 変数ファイルで環境を区別
- シンプルだが環境差分が大きい場合は複雑化

### パターン2: 環境asルートモジュール

**構造:**
```
environments/
├── staging/
│   ├── main.tf
│   ├── variables.tf
│   └── backend.tf
└── production/
    ├── main.tf
    ├── variables.tf
    └── backend.tf
```

**特徴:**
- 環境ごとに独立したルートモジュール
- 環境間の差異を明示的に管理
- ステート分離が容易

### パターン3: Terragrunt

**特徴:**
- DRY（Don't Repeat Yourself）原則
- 階層的な設定管理
- 複数モジュール間の依存関係管理

**構造例:**
```
infrastructure/
├── terragrunt.hcl     # グローバル設定
├── staging/
│   ├── terragrunt.hcl
│   ├── vpc/
│   │   └── terragrunt.hcl
│   └── app/
│       └── terragrunt.hcl
└── production/
    ├── terragrunt.hcl
    ├── vpc/
    │   └── terragrunt.hcl
    └── app/
        └── terragrunt.hcl
```

**利点:**
- 設定の重複排除
- 依存関係の自動解決
- バックエンド設定の一元管理

**トレードオフ:**
- 追加の抽象化レイヤー
- 学習コスト

---

## シークレット管理

### 絶対ルール

❌ **Gitにシークレットを保存しない**
- 認証情報
- APIキー
- パスワード
- 証明書

### OpenID Connect (OIDC)

**利点:**
- シークレット不要（最良の選択）
- サービスユーザー不要
- 認証情報ローテーション不要

**セットアップ手順:**

1. **IdP URLを取得**

| プラットフォーム | OIDC Token URL |
|---------------|---------------|
| GitHub Actions | `https://token.actions.githubusercontent.com` |
| Spacelift | プラットフォーム固有 |

2. **ベンダー側でIdPを登録**

```hcl
# AWS例
locals {
  gh_actions_token_url = "https://token.actions.githubusercontent.com"
}

data "tls_certificate" "gh_actions" {
  url = local.gh_actions_token_url
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = local.gh_actions_token_url
  thumbprint_list = data.tls_certificate.gh_actions.certificates[*].sha1_fingerprint
  client_id_list  = ["sts.amazonaws.com"]
}
```

3. **ロール/サービスプリンシパルを作成**

```hcl
# AWS IAM Role
resource "aws_iam_role" "github_actions" {
  name = "github-actions-${var.repository}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.repository}:ref:refs/heads/main"
        }
      }
    }]
  })
}
```

4. **ワークフローで使用**

```yaml
# GitHub Actions
jobs:
  terraform:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::999999999999:role/github-actions-repo
          region: us-west-2
```

```hcl
# Spacelift Provider設定
provider "aws" {
  assume_role_with_web_identity {
    role_arn                = var.aws_role_arn
    web_identity_token_file = "/mnt/workspace/spacelift.oidc"
  }
}
```

### シークレットマネージャー

**用途:** OIDC非対応サービスの認証情報

**主要サービス:**
- AWS Secrets Manager
- Azure Key Vault
- Google Secret Manager
- HashiCorp Vault（セルフホスト可）

**使用例:**

```hcl
# AWS
data "aws_secretsmanager_secret" "example" {
  arn = var.secret_arn
}

data "aws_secretsmanager_secret_version" "latest" {
  secret_id = data.aws_secretsmanager_secret.example.id
}

output "secret_value" {
  value     = data.aws_secretsmanager_secret_version.latest.secret_string
  sensitive = true
}
```

```hcl
# HashiCorp Vault
data "vault_generic_secret" "example" {
  path = "secret/data/myapp"
}

output "api_key" {
  value     = data.vault_generic_secret.example.data["api_key"]
  sensitive = true
}
```

```hcl
# Azure
data "azurerm_key_vault" "example" {
  name                = var.vault_name
  resource_group_name = var.resource_group
}

data "azurerm_key_vault_secret" "example" {
  name         = "api-key"
  key_vault_id = data.azurerm_key_vault.example.id
}
```

**注意:** ステートファイルにシークレットが含まれる可能性 → ステートアクセス制御を厳格に

### オーケストレータ設定

**最終手段:** CDプラットフォームのシークレット機能

**利点:**
- シンプル
- すぐに使える

**欠点:**
- スケールしない（500プロジェクトで同じAPIキーを更新）
- ベンダーロックイン
- セキュリティインシデントリスク（Travis CI 2021事例）

**推奨:**
1. OIDC（最優先）
2. シークレットマネージャー
3. オーケストレータ設定（小規模プロジェクトのみ）

---

## CDプラットフォーム機能

### 共通機能

すべてのTerraform CD Platformが提供:
- GitOpsワークフロー
- ロールベースアクセス制御（RBAC）
- OIDC対応
- シークレット管理
- Speculative Plan（PRでの事前確認）

### ステート管理・プライベートレジストリ

**TACOS (Terraform Automation and Collaboration Software):**
- ステート管理
- プライベートレジストリ
- デリバリー
- これらを一体化したプラットフォーム

**ステート管理:**
- 透過的なバックエンド設定
- WebUIでバージョン履歴閲覧
- 外部バックアップ推奨

### ドリフト検出・修正

**機能:**
- 定期的なPlan実行
- ドリフト検出時の通知（Slack等）
- 自動修正（オプション）

**推奨:**
- ドリフト検出: 有効
- 自動修正: 慎重に検討（ヒューマンレビュー推奨）

### IaCフレームワーク対応

**Terraform専用 vs マルチIaC:**

| プラットフォーム | 対応フレームワーク |
|----------------|------------------|
| HCP Terraform | Terraform/OpenTofu |
| Env0 | Terraform/OpenTofu/Pulumi/CloudFormation/Kubernetes |
| Spacelift | Terraform/OpenTofu/Pulumi/CloudFormation/Ansible/Kubernetes |

**推奨:** 将来の拡張性を考慮し、マルチIaC対応プラットフォームを優先検討

### ポリシー強制

**適用タイミング:**
- **CI時**: モジュールコード
- **CD時**: Plan結果（変数適用後）

**手法:**
- OPA/Rego
- Sentinel（HashiCorp）
- プラットフォーム固有のポリシーエンジン

**推奨:** CD時のポリシー強制で実際の変更内容を検証

### コスト見積

**機能:**
- Plan結果から予想コストを算出
- PR内でコスト変化を表示
- 予算超過時のアラート

**対応プラットフォーム:**
- Infracost（オープンソース統合）
- Spacelift
- Env0

---

## CDプラットフォーム概要

### HCP Terraform（HashiCorp）

**特徴:**
- HashiCorp公式
- Terraform専用
- TACOS機能完備

**制限:**
- Business Source License
- 他社CDプラットフォームとの競合により利用制限

**推奨:**
- HashiCorp Terraform継続利用
- 他CDプラットフォーム不使用

### Env0

**特徴:**
- マルチIaC対応
- コスト管理機能
- 柔軟なワークフロー

**対応フレームワーク:**
- Terraform/OpenTofu
- Pulumi
- CloudFormation
- Kubernetes (Helm)

**利点:**
- エコシステム選択の自由度
- OpenTofu対応

### Spacelift

**特徴:**
- 強力なポリシーエンジン
- ドリフト検出・修正
- マルチIaC対応

**対応フレームワーク:**
- Terraform/OpenTofu
- Pulumi
- CloudFormation
- Ansible
- Kubernetes

**利点:**
- 高度なカスタマイズ性
- エンタープライズ向け機能

### Scalr

**特徴:**
- HCP Terraformクローン（互換性重視）
- セルフホスト可
- TACOS機能

### Digger

**特徴:**
- オープンソース
- 既存CIに統合（GitHub Actions等）
- コスト効率

**制限:**
- CI依存（専用プラットフォームなし）

### Atlantis

**特徴:**
- オープンソース
- PRベースワークフロー
- セルフホスト

**制限:**
- 基本機能のみ
- エンタープライズ機能なし
- 継続的調整機能なし

---

## 判断基準テーブル

### プラットフォーム選定

| 要件 | 推奨プラットフォーム |
|-----|------------------|
| HashiCorp Terraform継続 | HCP Terraform |
| OpenTofu採用 | Env0, Spacelift |
| マルチIaC対応必須 | Env0, Spacelift |
| コスト重視 | Digger, Atlantis（セルフホスト） |
| エンタープライズ | Spacelift, Env0 |
| セルフホスト | Scalr, Atlantis, Digger |

### シークレット管理

| 優先度 | 手法 | 用途 |
|-------|-----|------|
| 1 | OIDC | クラウドプロバイダ、主要SaaS |
| 2 | シークレットマネージャー | OIDC非対応API |
| 3 | オーケストレータ設定 | 小規模・一時的用途 |

### 環境分離

| パターン | 推奨ケース |
|---------|----------|
| アプリケーションasルートモジュール | 環境差分が小さい |
| 環境asルートモジュール | 環境差分が大きい |
| Terragrunt | 大規模・複雑な依存関係 |

---

## ベストプラクティス

1. **Semantic Versioning厳守**: モジュール配信の基盤
2. **プライベートレジストリ活用**: バージョン制約のフル活用
3. **GitOps原則**: SCMを信頼できる情報源として使用
4. **環境完全分離**: ステート・変数・ネットワークを独立
5. **OIDC最優先**: シークレットを持たない認証
6. **ドリフト検出有効化**: 継続的調整の実装
7. **小さく頻繁にデプロイ**: リスク低減と迅速なフィードバック
8. **Speculative Plan活用**: PR段階で変更内容を確認

---

## トラブルシューティング

### モジュールバージョン競合

```
Error: Could not satisfy module version constraints
```

**解決策:**
- `~> 1.1`のようなPessimistic Constraintで柔軟性を確保
- 競合するモジュールのバージョン範囲を調整

### ドリフト検出false positive

**原因:**
- プロバイダAPI変更
- タイムスタンプフィールド

**対策:**
- `lifecycle { ignore_changes = [...] }` で特定フィールドを除外

### OIDC認証失敗

**確認項目:**
1. IdP URLの正確性
2. ロールの`Condition`設定（リポジトリ・ブランチ制限）
3. 権限設定（GitHub Actionsの`permissions`）

### デプロイメント競合

```
Error: Error acquiring the state lock
```

**原因:**
- 同一環境への同時デプロイ

**対策:**
- CDプラットフォームのジョブキューイング機能を使用
- ローカル実行を避ける
