# Terraform State の詳細

Terraformステートの構造、保存方法、操作手法、ドリフト対応、プロジェクト間連携を網羅するガイド。

---

## 目次

1. [ステートの目的](#ステートの目的)
2. [重要な考慮事項](#重要な考慮事項)
3. [ステートの内部構造](#ステートの内部構造)
4. [ステートの保存](#ステートの保存)
5. [ステートの操作](#ステートの操作)
6. [ステートドリフト](#ステートドリフト)
7. [プロジェクト間ステートアクセス](#プロジェクト間ステートアクセス)
8. [ステートのみのリソース](#ステートのみのリソース)

---

## ステートの目的

### 1. 実世界とのリンク（Real-world Linkage）

ステートがないと、Terraformはリソースの識別が困難になる。

| 問題 | ステートなしの場合 | ステートありの場合 |
|------|------------------|------------------|
| リソース識別 | タグやメタデータに依存（不安定） | リソースIDで確実に識別 |
| プロバイダ差異 | 各プロバイダ独自の実装が必要 | 統一的なインターフェース |
| 手動変更対応 | リソースを見失う可能性 | ステートで追跡可能 |

**AWS例**: Amazon Resource Name（ARN）でリソースを一意に識別。

### 2. 複雑性の削減（Reduced Complexity）

ステートを使うことで、Terraform本体とプロバイダ開発が簡素化される。

**メリット**:
- プロバイダ開発が容易
- バグ発生箇所が少ない
- エコシステムの成長を促進

### 3. パフォーマンス（Performance）

- リソースIDで直接参照（自動検出より高速）
- `terraform graph`等のサブコマンドが高速化
- 開発サイクルの高速化

### 4. ステートのみのリソース（State-only Resources）

TLS、Random、Time、Nullプロバイダ等、ステートにのみ存在するリソース。

```hcl
resource "random_password" "db_pass" {
  length  = 16
  special = true
}

resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```

---

## 重要な考慮事項

### 1. 回復力（Resiliency）

#### リスク

ステートが失われると、Terraformは機能しなくなる。復旧には以下が必要:
- 手動でのリソース削除
- または `terraform import` で全リソースを再インポート

#### 対策

| 対策 | 説明 |
|------|------|
| **信頼性の高いバックエンド** | AWS S3の耐久性: 99.999999999%（イレブンナイン） |
| **バックアップ** | 定期的なバックアップと復旧テスト |
| **バージョニング** | 複数バージョンのステート保持 |

**重要**: バックアップは定期的にテストすること（テストなしのバックアップは無価値）。

### 2. セキュリティ（Security）

#### リスク

ステートには**すべての属性**（sensitive指定含む）が平文で保存される。

| 脅威 | 対策 |
|------|------|
| 認証情報漏洩 | 多要素認証（MFA）の強制 |
| 設定ミス | 公開アクセスの無効化 |
| 内部犯 | アクセスログの監視 |

#### 軽減策

1. **シークレットマネージャー使用**: Vault、AWS Secrets Manager等
2. **CI/CDシークレット機能**: GitHub Actions Secrets等
3. **パスを変数化**: ステートに直接書かない

### 3. 可用性（Availability）

#### 目標値

| レベル | 稼働率 | 月間ダウンタイム | 推奨 |
|--------|--------|----------------|------|
| Three Nines | 99.9% | 43分30秒 | ⚠️ 最低限 |
| **Four Nines** | **99.99%** | **4分30秒** | ✅ **推奨** |
| Five Nines | 99.999% | 26秒 | ✅ 理想的 |

**重要**: ステートが利用不可 = デプロイ不可。

---

## ステートの内部構造

### JSON形式

ステートはJSON形式で保存される（localバックエンド使用時）。

#### トップレベルフィールド

| フィールド | 説明 |
|-----------|------|
| `version` | ステートデータ構造のバージョン |
| `terraform_version` | ステート生成時のTerraformバージョン |
| `serial` | ステートのシリアル番号（変更ごとに+1） |
| `lineage` | プロジェクト固有のUUID（初回`terraform init`時に生成、不変） |
| `resources` | 管理中リソースのリスト |
| `outputs` | ルートモジュールのoutputリスト |
| `check_results` | アサーションチェックの結果 |

#### リソースエントリ

```json
{
  "module": "module.my_password",
  "mode": "managed",
  "type": "random_password",
  "name": "new_password",
  "provider": "provider[\"registry.terraform.io/hashicorp/random\"]",
  "instances": [
    {
      "schema_version": 3,
      "attributes": {
        "length": 12,
        "result": "[-Cz>m@XQnZc",
        "special": true
      },
      "sensitive_attributes": [],
      "dependencies": []
    }
  ]
}
```

**注意**: 手動編集は最終手段（通常はCLIツールを使用）。

---

## ステートの保存

### バックエンドの選択

#### 主要バックエンド

| バックエンド | 用途 | 特徴 |
|------------|------|------|
| **local** | 開発・テスト | ローカルファイルシステム |
| **S3** | AWS環境 | DynamoDBでロック、バージョニング対応 |
| **GCS** | GCP環境 | バージョニング対応 |
| **AzureRM** | Azure環境 | ストレージアカウント利用 |
| **Consul** | 自己管理 | KVストア、HA対応 |
| **Terraform Cloud** | 管理サービス | 統合CI/CD、RBAC |

#### バックエンド設定の基本要件

```
┌─────────────────────────────────────┐
│  Backend Configuration Checklist   │
├─────────────────────────────────────┤
│ ✓ アクセス制限（最小権限の原則）      │
│ ✓ ログ記録（すべてのアクセス）        │
│ ✓ バックアップ（定期的＋テスト）      │
│ ✓ 暗号化（保存時・転送時）           │
│ ✓ ロック機能（同時変更防止）          │
└─────────────────────────────────────┘
```

### Backendブロック

#### 基本形式

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

#### 部分設定（Partial Configuration）

```hcl
terraform {
  backend "s3" {
    encrypt = true  # 強制設定のみ
  }
}
```

```bash
# 残りの設定をtfvarsで渡す
terraform init -backend-config=backend.tfvars
```

**backend.tfvars**:
```hcl
bucket         = "my-terraform-state"
key            = "prod/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "terraform-locks"
```

#### 認証方法

| 方法 | 推奨度 | 用途 |
|------|--------|------|
| ハードコード | ❌ | 使用禁止 |
| 設定ファイル | ⚠️ | ローカル開発（`~/.aws/credentials`等） |
| **環境変数** | ✅ | **CI/CD推奨** |
| **Cloud Block** | ✅ | **Terraform Cloud/Scalr等** |

### Cloudブロック

Terraform Cloud/Scalr/Env0等のリモート実行環境用。

#### タグベース

```hcl
terraform {
  cloud {
    organization = "acme-org"
    hostname     = "app.terraform.io"  # OpenTofuでは必須

    workspaces {
      tags = ["acme_application", "production"]
    }
  }
}
```

```bash
# workspace切替可能
terraform workspace select dev
terraform workspace select prod
```

#### 名前ベース

```hcl
terraform {
  cloud {
    organization = "acme-org"
    hostname     = "acme.scalr.io"

    workspaces {
      name = "acme_production"  # 固定workspace
    }
  }
}
```

```bash
# ログイン
terraform login acme.scalr.io
```

### バックエンド移行

```bash
# バックエンド設定変更後
terraform init -migrate-state

# または新規状態で開始（⚠️ 既存ステートは破棄）
terraform init -reconfigure
```

**注意**: 最新ステートのみ移行される。履歴が必要な場合は手動バックアップ。

### Workspaces

同一コードで複数環境を管理する機能。

```bash
# workspace管理
terraform workspace list
terraform workspace new dev
terraform workspace select dev
terraform workspace delete staging
```

#### コード内でworkspace参照

```hcl
locals {
  env_config = {
    production = {
      instance_count = 10
      instance_type  = "t3.large"
    }
    dev = {
      instance_count = 1
      instance_type  = "t3.micro"
    }
  }

  config = local.env_config[terraform.workspace]
}

resource "aws_instance" "app" {
  count         = local.config.instance_count
  instance_type = local.config.instance_type
}
```

**⚠️ Cloud Block使用時の注意**: `terraform workspace`コマンドの挙動が変わる（Terraform Cloudのworkspaceと統合される）。

---

## ステートの操作

### コード駆動の変更

#### 1. `moved`ブロック（リソース名変更）

```hcl
# 旧
# resource "aws_instance" "example" { ... }

# 新
resource "aws_instance" "web_server" {
  # ... 同じ設定 ...
}

moved {
  from = aws_instance.example
  to   = aws_instance.web_server
}
```

**効果**: リソース削除・再作成を回避。

#### 2. `import`ブロック（既存リソース取り込み）

```hcl
import {
  to = aws_instance.imported_vm
  id = "i-0123456789abcdef0"
}

resource "aws_instance" "imported_vm" {
  # 既存リソースと一致する設定
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
}
```

```bash
terraform plan -generate-config-out=imported.tf
```

#### 3. `removed`ブロック（Terraform管理から除外）

```hcl
removed {
  from = aws_s3_bucket.legacy

  lifecycle {
    destroy = false  # リソースは削除しない
  }
}
```

### CLI駆動の変更

#### terraform state コマンド

| コマンド | 用途 |
|---------|------|
| `terraform state list` | 管理中リソース一覧 |
| `terraform state show <address>` | リソース詳細表示 |
| `terraform state mv <src> <dst>` | リソース移動・リネーム |
| `terraform state rm <address>` | ステートから削除（リソースは保持） |
| `terraform state pull` | リモートステート取得 |
| `terraform state push` | ローカルステートをリモートに送信 |

**例**:

```bash
# リソース名変更
terraform state mv aws_instance.old aws_instance.new

# 管理から除外
terraform state rm aws_s3_bucket.legacy

# 既存リソース取り込み（レガシー方式）
terraform import aws_instance.new i-0123456789abcdef0
```

### 手動編集（最終手段）

**⚠️ 推奨されない**。以下の順で実施:

1. `terraform state pull > backup.tfstate`
2. `backup.tfstate`を編集
3. `terraform state push backup.tfstate`

**リスク**: lineage/serialの不整合、JSON構文エラー、依存関係破壊。

---

## ステートドリフト

### ドリフトの種類

| 種類 | 原因 | 対処 |
|------|------|------|
| **偶発的手動変更** | 手作業での設定変更 | `terraform apply` で修正 |
| **意図的手動変更** | 緊急対応等 | `ignore_changes`または承認 |
| **競合する自動化** | 他ツールとの衝突 | プロセス統一 |
| **Terraformエラー** | クラッシュ・ネットワーク断 | ログ確認＋`import`/削除 |

### 偶発的手動変更

#### 検出

```bash
terraform plan -refresh-only
```

#### 修正

```bash
# コードの状態に戻す
terraform apply
```

### 意図的手動変更

#### 無視する場合

```hcl
resource "aws_instance" "main" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  tags = {
    Name = "managed-by-terraform"
  }

  lifecycle {
    ignore_changes = [
      tags,  # タグ変更を無視
    ]
  }
}
```

#### 承認する場合

```bash
# ステート更新のみ
terraform apply -refresh-only
```

### Terraformエラー

#### 症状

- ステート保存失敗
- リソース作成後のクラッシュ
- 認証切れ

#### 対処

1. **ログ確認**: どのリソースが作成されたか特定
2. **選択肢**:
   - `terraform import <address> <id>` でステートに追加
   - または手動削除してTerraformに再作成させる
3. **ステート破損時**: バックアップから復元

---

## プロジェクト間ステートアクセス

### ユースケース

- 大規模プロジェクトの分割（パフォーマンス向上）
- チーム分離（ネットワーク、DB、アプリ等）
- Conway's Law: 組織構造がシステム構造に反映される

### terraform_remote_state データソース

```hcl
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "terraform-state-bucket"
    key    = "network/terraform.tfstate"
    region = "us-west-2"
  }
}

module "app" {
  source = "./modules/app"

  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.subnet_ids
}
```

**前提**: リモートプロジェクトが`output`を定義していること。

#### defaultsで柔軟性向上

```hcl
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "database/terraform.tfstate"
    region = var.region
  }

  defaults = {
    db_endpoint = null  # DB未作成時でもエラーにならない
  }
}
```

### 構造化パターン

#### パターン1: ルートモジュールに集約

```hcl
# root main.tf
data "terraform_remote_state" "network" { ... }
data "terraform_remote_state" "database" { ... }

module "app" {
  source = "./modules/app"

  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  db_endpoint = data.terraform_remote_state.database.outputs.endpoint
}
```

**メリット**: モジュールの再利用性向上。

#### パターン2: 専用モジュール

```hcl
# modules/network-state/main.tf
variable "network_name" {
  type = string
}

data "terraform_remote_state" "network" {
  backend = "consul"

  config = {
    address = "consul.internal"
    scheme  = "https"
    path    = "terraform/networks/${var.network_name}"
  }
}

output "vpc_id" {
  value = data.terraform_remote_state.network.outputs.vpc_id
}
```

```hcl
# 使用側
module "network_data" {
  source       = "./modules/network-state"
  network_name = "production"
}

module "app" {
  source = "./modules/app"
  vpc_id = module.network_data.vpc_id
}
```

### 代替手段

| 手段 | メリット | デメリット |
|------|---------|----------|
| **Data Sources** | セキュア、ステート不要 | 検索が困難な場合がある |
| **Input Variables** | セキュア | 手動メンテナンス必要 |
| **Remote State** | 自動更新 | セキュリティリスク（全属性公開） |

**推奨順**: Data Sources → Variables → Remote State。

---

## ステートのみのリソース

外部APIを使わず、ステート内でのみ存在するリソース。

### Random Provider

#### 基本リソース

| リソース | 用途 |
|---------|------|
| `random_integer` | 整数生成 |
| `random_uuid` | UUID生成 |
| `random_pet` | 人間可読な名前（例: "sage-longhorn"） |
| `random_password` | パスワード生成（暗号学的に安全） |

#### 例: ランダムパスワード

```hcl
resource "random_password" "db_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true

  min_special = 2
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2

  override_special = "!@#$%^&*()-_=+[]{}:?"
}

resource "aws_db_instance" "main" {
  # ...
  password = random_password.db_password.result
}
```

**注意**: `result`属性は`sensitive`マーク済み（ログに出力されない）。

#### keepers（再生成トリガー）

```hcl
resource "random_uuid" "suffix" {
  keepers = {
    name = var.app_name  # app_name変更時にUUID再生成
  }
}

output "unique_id" {
  value = random_uuid.suffix.result
}
```

### Time Provider

タイムスタンプを記録（`timestamp()`関数の問題を解決）。

| リソース | 用途 |
|---------|------|
| `time_static` | 作成時刻を記録 |
| `time_offset` | 相対時刻（例: 2時間後） |
| `time_rotating` | 定期的に更新（例: 2日ごと） |

#### 例: 定期ローテーション

```hcl
resource "time_rotating" "daily" {
  rotation_days = 1
}

resource "aws_instance" "daily_refresh" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  lifecycle {
    replace_triggered_by = [time_rotating.daily.id]
  }
}
```

#### 例: タイムスタンプ記録

```hcl
resource "time_static" "deployment_time" {
  triggers = {
    deployment_id = var.deployment_id
  }
}

resource "aws_s3_object" "metadata" {
  bucket  = aws_s3_bucket.logs.id
  key     = "deployments/${var.deployment_id}.json"
  content = jsonencode({
    deployed_at = time_static.deployment_time.rfc3339
    version     = var.app_version
  })
}
```

---

## まとめ

| テーマ | 重要ポイント |
|--------|------------|
| **ステートの目的** | リソース識別、複雑性削減、パフォーマンス、ステート専用リソース |
| **考慮事項** | 回復力（バックアップ）、セキュリティ（暗号化・アクセス制御）、可用性（99.99%以上） |
| **内部構造** | JSON形式、lineage（プロジェクトUUID）、serial（バージョン番号） |
| **保存** | Backend選択、部分設定、認証、Cloud Block、移行 |
| **操作** | `moved`/`import`/`removed`ブロック、`terraform state`コマンド、手動編集（最終手段） |
| **ドリフト** | 手動変更（修正 or 無視）、競合自動化、Terraformエラー（import or 削除） |
| **プロジェクト間連携** | `terraform_remote_state`、Data Sourcesが優先、Variables代替 |
| **ステート専用リソース** | Random（UUID・パスワード）、Time（タイムスタンプ・ローテーション） |

**ベストプラクティス**:
- Four Nines以上のバックエンドを選択
- 定期的なバックアップとテスト
- `ignore_changes`で意図的ドリフトを許容
- `moved`ブロックで破壊的変更を回避
- Remote State使用前にData Sourcesを検討
