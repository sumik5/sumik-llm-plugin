# Terragrunt プロジェクト構造設計ガイド

大規模Terraformプロジェクトの構造化パターンとTerragruntベストプラクティス。

---

## 1. 機能別ディレクトリ分割パターン

### 基本原則

- **番号付きプレフィックス**: 依存順序を視覚的に表現（0-, 1-, 2-...）
- **命名規則**: 機能・責務を表す短い名前（ケバブケース）
- **`_` プレフィックス**: 非デプロイディレクトリ（環境設定等、Terragrunt実行対象外）
- **サブディレクトリ分割**: 同一レイヤーで異なる関心事を分離（4a-/4b-等）

### ディレクトリ構成テンプレート

#### GCPベース例

```
terraform/
├── root.hcl                    # 共通設定（全モジュールで継承）
├── .mise.toml                  # Terragruntタスク定義
├── _env/                       # 環境設定（⚠️ Git除外推奨）
│   ├── prod.hcl
│   ├── dev.hcl
│   └── prod.hcl.example        # サンプル（✅ Git管理）
├── 0-services/                 # API有効化・初期設定
│   ├── terragrunt.hcl
│   ├── main.tf
│   └── ...
├── 1-network/                  # ネットワーク基盤
│   ├── terragrunt.hcl          # 依存: 0-services
│   ├── vpc.tf
│   ├── dns.tf
│   └── ...
├── 2-database/                 # データベース層
│   ├── terragrunt.hcl          # 依存: 1-network
│   ├── cloudsql.tf
│   └── ...
├── 3-registry/                 # コンテナレジストリ
│   ├── terragrunt.hcl          # 依存: 0-services
│   └── ...
├── 4a-app-infra/               # アプリケーション基盤
│   ├── terragrunt.hcl          # 依存: 1-network, 2-database, 3-registry
│   ├── cloud-run.tf
│   └── ...
├── 4b-app-config/              # アプリケーション設定
│   ├── terragrunt.hcl          # 依存: 4a-app-infra
│   └── ...
└── 5-monitoring/               # 監視・ロギング
    ├── terragrunt.hcl          # 依存: 4a-app-infra
    ├── alerting.tf
    └── ...
```

#### 汎用版（AWSでも使える形）

```
terraform/
├── root.hcl
├── .mise.toml
├── _env/
│   ├── prod.hcl
│   └── prod.hcl.example
├── 0-foundation/               # アカウント初期化・API有効化
├── 1-network/                  # VPC/Subnet/RouteTable
├── 2-security/                 # IAM/SecurityGroup/Secrets
├── 3-data/                     # RDS/DynamoDB/S3
├── 4-compute/                  # EC2/ECS/Lambda
└── 5-observability/            # CloudWatch/X-Ray
```

### 命名規則の意図

| プレフィックス | 意図 | 例 |
|--------------|------|-----|
| `0-` | 最初に実行（依存関係なし） | 0-services, 0-foundation |
| `1-` | 基盤レイヤー（ネットワーク） | 1-network, 1-infra |
| `2-` | データ層・セキュリティ | 2-database, 2-security |
| `3-` | 共有サービス | 3-registry, 3-data |
| `4-` | アプリケーション層 | 4-application, 4-compute |
| `4a-`, `4b-` | 同一レイヤー内の関心分離 | 4a-app-infra, 4b-app-config |
| `5-` | 運用・監視 | 5-monitoring, 5-observability |
| `_` | 非デプロイディレクトリ | _env, _modules |

---

## 2. モジュール内ファイル構成

### 標準ファイルレイアウト

```
<module>/
├── terragrunt.hcl       # ⭐ Terragrunt設定（必須）
├── variables.tf         # 入力変数定義
├── locals.tf            # ローカル変数
├── outputs.tf           # 出力値
├── main.tf              # メインリソース定義
├── <resource>.tf        # リソース別ファイル（vpc.tf, dns.tf等）
└── versions.tf          # バージョン制約（⚠️ generateしない場合のみ）
```

### Terragrunt自動生成ファイル（⚠️ Git除外対象）

root.hclまたは各モジュールのterragrunt.hclで`generate`ブロックにより自動生成されるファイル:

```
<module>/
├── _backend.tf          # バックエンド設定（GCS/S3）
├── _provider.tf         # プロバイダー設定
├── _versions.tf         # バージョン制約
├── _<custom>.tf         # カスタム生成ファイル
└── .terragrunt-cache/   # Terragrunt実行時キャッシュ
```

**重要**: `_`で始まるファイルは全て`.gitignore`に追加すること。

---

## 3. .mise.toml テンプレート

miseタスクランナーでTerragruntワークフローを効率化。

### 全モジュール一括タスク

```toml
# ツール管理
[tools]
terraform = "1.14.4"
terragrunt = "latest"
tflint = "latest"

[settings]
experimental = true

# 初期化（全モジュール）
[tasks."tg:init-all"]
description = "全モジュールの terragrunt init を実行"
run = "terragrunt run --all init"

# 再設定付き初期化
[tasks."tg:init-all:reconfigure"]
description = "全モジュールを再設定してinit"
run = "terragrunt run --all init -- -reconfigure"

# プラン（依存順序自動解決）
[tasks."tg:plan-all"]
description = "全モジュールの terragrunt plan を実行（依存順序を自動解決）"
run = "terragrunt run --all plan"

# 適用（依存順序自動解決）
[tasks."tg:apply-all"]
description = "全モジュールの terragrunt apply を実行（依存順序を自動解決）"
run = "terragrunt run --all apply"

# 削除（依存順序自動解決）
[tasks."tg:destroy-all"]
description = "全モジュールの terragrunt destroy を実行（依存順序を自動解決）"
run = "terragrunt run --all destroy"

# 検証
[tasks."tg:validate-all"]
description = "全モジュールの terragrunt validate を実行"
run = "terragrunt run --all validate"

# 依存関係グラフ表示
[tasks."tg:graph"]
description = "Terragruntの依存関係グラフを表示"
run = "terragrunt dag graph"

# モジュール一覧
[tasks."tg:list"]
description = "全モジュールの一覧をツリー表示"
run = "terragrunt list --dag --tree"

# 出力値表示
[tasks."tg:output"]
description = "全モジュールの出力値を表示"
run = "terragrunt run --all output"

# キャッシュクリア
[tasks."tg:clean"]
description = "Terragruntキャッシュを削除"
run = '''
echo "Cleaning Terragrunt cache..."
find . -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
echo "✅ Cache cleaned!"
'''
```

### 単一モジュールタスク（モジュールディレクトリ内で実行）

```toml
# 現在のモジュールのみ実行
[tasks.init]
description = "現在のモジュールを初期化"
run = "terragrunt init"

[tasks.plan]
description = "現在のモジュールをプラン"
run = "terragrunt plan"

[tasks.apply]
description = "現在のモジュールを適用"
run = "terragrunt apply"

[tasks.destroy]
description = "現在のモジュールを削除"
run = "terragrunt destroy"

[tasks.output]
description = "現在のモジュールの出力値を表示"
run = "terragrunt output"
```

### モジュール別ショートカットタスク

```toml
# 親ディレクトリから特定モジュールを実行
# 使用例: mise run tg:run -- 0-services init
[tasks."tg:run"]
description = "指定モジュールでterragruntコマンドを実行"
run = '''
MODULE="${1:-}"
COMMAND="${2:-}"

if [ -z "$MODULE" ] || [ -z "$COMMAND" ]; then
  echo "Usage: mise run tg:run -- <module> <command>"
  echo ""
  echo "Available modules:"
  for dir in */; do
    if [ -f "${dir}terragrunt.hcl" ]; then
      echo "  - ${dir%/}"
    fi
  done
  echo ""
  echo "Available commands: init, plan, apply, destroy, output, validate"
  exit 1
fi

if [ ! -d "$MODULE" ] || [ ! -f "$MODULE/terragrunt.hcl" ]; then
  echo "❌ Error: Module '$MODULE' not found or missing terragrunt.hcl"
  exit 1
fi

echo "→ Running 'terragrunt $COMMAND' in $MODULE"
cd "$MODULE" && terragrunt "$COMMAND"
'''

# モジュール別ショートカット（usageフィールドで引数定義）
# 使用例: mise run tg:0-services plan
[tasks."tg:0-services"]
description = "0-services モジュールでterragruntコマンドを実行"
usage = 'arg "<command>" help="Terragrunt command" default="plan"'
run = 'cd 0-services && terragrunt ${usage_command}'

[tasks."tg:1-network"]
description = "1-network モジュールでterragruntコマンドを実行"
usage = 'arg "<command>" help="Terragrunt command" default="plan"'
run = 'cd 1-network && terragrunt ${usage_command}'

# ... 他のモジュールも同様に定義
```

### タスク実行例

```bash
# 全モジュール初期化
mise run tg:init-all

# 依存関係グラフ表示
mise run tg:graph

# 全モジュールプラン
mise run tg:plan-all

# 特定モジュールのみ実行
mise run tg:1-network plan
mise run tg:run -- 2-database apply

# モジュールディレクトリ内で
cd 3-registry
mise run plan
```

---

## 4. root.hcl 設計パターン

全モジュールで共通の設定を定義。

```hcl
# =============================================================================
# Terragrunt ルート設定
# =============================================================================
# すべてのモジュールで共通の設定を定義
# 各モジュールは include "root" でこのファイルを継承
# =============================================================================

locals {
  # 環境設定ファイルを読み込み（デフォルト: prod）
  # 環境切り替え: TG_ENV=dev terragrunt run --all apply
  env_name = get_env("TG_ENV", "prod")

  # ルートディレクトリのパスを取得
  root_dir = get_parent_terragrunt_dir()

  # 環境設定ファイルを読み込み
  env_vars = read_terragrunt_config("${local.root_dir}/_env/${local.env_name}.hcl").locals

  # モジュール名を相対パスから取得（例: "1-network"）
  module_name = basename(get_terragrunt_dir())
}

# -----------------------------------------------------------------------------
# リモートステート設定（GCSバックエンド例）
# -----------------------------------------------------------------------------
remote_state {
  backend = "gcs"
  generate = {
    path      = "_backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket   = local.env_vars.terraform_state_bucket
    prefix   = "${path_relative_to_include()}-state"
    project  = local.env_vars.project_id
    location = local.env_vars.region
  }
}

# -----------------------------------------------------------------------------
# リモートステート設定（S3バックエンド例 - AWS）
# -----------------------------------------------------------------------------
# remote_state {
#   backend = "s3"
#   generate = {
#     path      = "_backend.tf"
#     if_exists = "overwrite_terragrunt"
#   }
#   config = {
#     bucket         = local.env_vars.terraform_state_bucket
#     key            = "${path_relative_to_include()}/terraform.tfstate"
#     region         = local.env_vars.region
#     encrypt        = true
#     dynamodb_table = local.env_vars.dynamodb_lock_table
#   }
# }

# -----------------------------------------------------------------------------
# Provider 設定を自動生成（GCP例）
# -----------------------------------------------------------------------------
generate "provider" {
  path      = "_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      project = "${local.env_vars.project_id}"
      region  = "${local.env_vars.region}"
    }
  EOF
}

# -----------------------------------------------------------------------------
# Provider 設定を自動生成（AWS例）
# -----------------------------------------------------------------------------
# generate "provider" {
#   path      = "_provider.tf"
#   if_exists = "overwrite_terragrunt"
#   contents  = <<-EOF
#     provider "aws" {
#       region = "${local.env_vars.region}"
#     }
#   EOF
# }

# -----------------------------------------------------------------------------
# Terraform バージョン設定
# -----------------------------------------------------------------------------
# Note: 各モジュールで独自のプロバイダー要件がある場合があるため、
# generate "versions" は各モジュールのterragrunt.hclで定義することを推奨
# 共通のバージョン定数のみ提供:
#   - terraform_version: "= 1.14.4"
#   - google_provider_version: "7.19.0"

# -----------------------------------------------------------------------------
# Terragrunt 実行設定
# -----------------------------------------------------------------------------
terraform {
  # auto-init を無効化（initは明示的に実行）
  # Note: 初回実行時は必ず `mise run tg:init-all` を実行すること
  extra_arguments "no_auto_init" {
    commands = ["plan", "apply", "destroy", "output", "validate", "refresh"]
    env_vars = {
      TERRAGRUNT_AUTO_INIT = "false"
    }
  }
}

# -----------------------------------------------------------------------------
# 共通 inputs
# -----------------------------------------------------------------------------
# すべてのモジュールに渡す共通変数
# 各モジュールの terragrunt.hcl で追加の inputs を定義可能
inputs = {
  project_id      = local.env_vars.project_id
  region          = local.env_vars.region
  environment     = local.env_vars.environment
  # AWS例:
  # account_id      = local.env_vars.account_id
  # vpc_cidr        = local.env_vars.vpc_cidr
}
```

---

## 5. モジュール terragrunt.hcl パターン

### 依存関係なし（最初のモジュール）

```hcl
# =============================================================================
# 0-services - GCP API 有効化
# =============================================================================
# 最初に実行するモジュール（依存関係なし）
# =============================================================================

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# -----------------------------------------------------------------------------
# Terraform バージョン設定
# -----------------------------------------------------------------------------
generate "versions" {
  path      = "_versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = "= 1.14.4"
      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "7.19.0"
        }
      }
    }
  EOF
}

# このモジュールには依存関係がない（最初に実行）
```

### 単一依存関係

```hcl
# =============================================================================
# 1-network - VPC、DNS
# =============================================================================
# 0-services に依存
# =============================================================================

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# -----------------------------------------------------------------------------
# Terraform バージョン設定
# -----------------------------------------------------------------------------
generate "versions" {
  path      = "_versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = "= 1.14.4"
      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "7.19.0"
        }
      }
    }
  EOF
}

# -----------------------------------------------------------------------------
# 依存関係定義
# -----------------------------------------------------------------------------
dependency "services" {
  config_path = "../0-services"

  # run --all plan/init 時に依存モジュールがまだ適用されていない場合のモック値
  mock_outputs = {
    project_id = "mock-project-id"
    region     = "asia-northeast1"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

# 依存モジュールの出力を使用
inputs = {
  # 0-services の出力を参照
  # services_enabled = dependency.services.outputs.enabled_services
}
```

### 複数依存関係

```hcl
# =============================================================================
# 4a-application - アプリケーション基盤
# =============================================================================
# 1-network, 2-database, 3-registry に依存
# =============================================================================

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# -----------------------------------------------------------------------------
# カスタムプロバイダー追加（Dockerプロバイダー例）
# -----------------------------------------------------------------------------
generate "versions" {
  path      = "_versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = "= 1.14.4"
      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "7.19.0"
        }
        docker = {
          source  = "kreuzwerker/docker"
          version = "3.6.2"
        }
      }
    }
  EOF
}

generate "docker_provider" {
  path      = "_docker_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "docker" {
      registry_auth {
        address     = "${include.root.locals.env_vars.region}-docker.pkg.dev"
        config_file = pathexpand("~/.docker/config.json")
      }
    }
  EOF
}

# -----------------------------------------------------------------------------
# 複数依存関係定義
# -----------------------------------------------------------------------------
dependency "network" {
  config_path = "../1-network"

  mock_outputs = {
    vpc_id        = "mock-vpc-id"
    subnet_id     = "mock-subnet-id"
    dns_zone_name = "mock-zone"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "database" {
  config_path = "../2-database"

  mock_outputs = {
    db_connection_name = "mock:connection:name"
    db_name            = "mock-db"
    db_user            = "mock-user"
    db_password_secret = "mock-secret"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "registry" {
  config_path = "../3-registry"

  mock_outputs = {
    repository_id = "mock-repo"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

# -----------------------------------------------------------------------------
# 依存モジュールの出力を inputs に渡す
# -----------------------------------------------------------------------------
inputs = {
  vpc_id                = dependency.network.outputs.vpc_id
  subnet_id             = dependency.network.outputs.subnet_id
  dns_zone_name         = dependency.network.outputs.dns_zone_name
  db_connection_name    = dependency.database.outputs.db_connection_name
  db_name               = dependency.database.outputs.db_name
  db_user               = dependency.database.outputs.db_user
  db_password_secret_id = dependency.database.outputs.db_password_secret
  repository_id         = dependency.registry.outputs.repository_id

  # root.hcl の env_vars にアクセス
  app_admin_username    = include.root.locals.env_vars.app_admin_username
  app_admin_password    = include.root.locals.env_vars.app_admin_password
}
```

---

## 6. 環境設定ファイル（_env/）

### prod.hcl.example（サンプル - Git管理）

```hcl
# =============================================================================
# 環境設定サンプル
# =============================================================================
# このファイルをコピーして prod.hcl（または dev.hcl など）を作成してください
#
# 使用方法:
#   cp prod.hcl.example prod.hcl
#   # prod.hcl を編集して実際の値を設定
#
# 環境切り替え:
#   TG_ENV=prod terragrunt run --all apply
#   TG_ENV=dev terragrunt run --all plan
# =============================================================================

locals {
  # -------------------------------------------------------------------------
  # 環境識別
  # -------------------------------------------------------------------------
  environment = "prod"

  # -------------------------------------------------------------------------
  # GCP プロジェクト基本設定
  # -------------------------------------------------------------------------
  project_id             = "your-project-id"
  organization_id        = "your-organization-id"
  billing_account        = "your-billing-account"
  terraform_state_bucket = "your-project-id-tfstate"
  region                 = "asia-northeast1"

  # -------------------------------------------------------------------------
  # AWS アカウント基本設定（AWS使用時）
  # -------------------------------------------------------------------------
  # account_id             = "123456789012"
  # terraform_state_bucket = "your-org-terraform-state"
  # dynamodb_lock_table    = "terraform-state-lock"
  # region                 = "ap-northeast-1"

  # -------------------------------------------------------------------------
  # ドメイン設定
  # -------------------------------------------------------------------------
  domain = "your-domain.example.com"

  # -------------------------------------------------------------------------
  # アプリケーション固有設定（必要に応じて追加）
  # -------------------------------------------------------------------------
  app_admin_username = "admin"
  app_admin_password = "CHANGE_ME_STRONG_PASSWORD"  # sensitive

  # データベース設定
  db_name     = "myapp"
  db_username = "myapp_user"
  db_password = "CHANGE_ME_DB_PASSWORD"  # sensitive
}
```

### セキュリティのベストプラクティス

1. **センシティブ情報の管理**
   - `_env/*.hcl` は `.gitignore` に追加（サンプルファイル以外）
   - パスワード等は Secret Manager / AWS Secrets Manager で管理することを推奨
   - Terragruntの環境変数ファイルはあくまで設定の参照先を定義

2. **環境別ファイルの推奨構成**
   ```
   _env/
   ├── prod.hcl             # ⚠️ Git除外
   ├── dev.hcl              # ⚠️ Git除外
   ├── prod.hcl.example     # ✅ Git管理（サンプル）
   └── dev.hcl.example      # ✅ Git管理（サンプル）
   ```

---

## 7. .gitignore テンプレート

Terragrunt自動生成ファイルの除外。

```gitignore
# Terraform
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.*
*.tfvars
!*.tfvars.example

# Terragrunt自動生成ファイル（_で始まるファイル）
terraform/**/_backend.tf
terraform/**/_provider.tf
terraform/**/_versions.tf
terraform/**/_*_provider.tf
.terragrunt-cache/

# 環境固有の設定（サンプルは除外）
terraform/_env/*.hcl
!terraform/_env/*.hcl.example

# tflint
.tflint.hcl

# IDEファイル
.vscode/
.idea/
```

---

## 8. 依存関係DAG設計指針

### 基本原則

1. **循環依存の回避**
   - 依存グラフは有向非巡回グラフ（DAG）である必要がある
   - 循環依存が発生した場合、モジュール分割を見直す

2. **適切な粒度の決め方**
   - 1モジュール = 1つの責務
   - 同時にデプロイされるリソースをグループ化
   - 変更頻度が異なるリソースは分離

3. **依存の深さ制限**
   - 推奨: 最大5層程度
   - 深すぎる依存は実行時間増加の原因
   - 並列化可能な部分は同一レイヤーに配置

4. **モック出力の設計ガイドライン**
   - 依存モジュール未適用時でも `plan` が実行可能にする
   - モック値は型と構造を実際の出力と一致させる
   - 必ず `mock_outputs_allowed_terraform_commands` を設定

### 依存関係の可視化

```bash
# 依存関係グラフ（DAG）を確認
mise run tg:graph

# モジュール一覧をツリー表示
mise run tg:list
```

### アンチパターン

❌ **避けるべき設計**:
- 双方向依存（A → B → A）
- すべてのモジュールが相互依存
- 深すぎる依存チェーン（10層以上）
- モック値の不足（planが失敗する）

✅ **推奨パターン**:
- レイヤー化された依存（0 → 1 → 2 → ...）
- 並列実行可能なモジュールは同一レイヤー
- 出力値の明確な定義（outputs.tf）
- 最小限の依存関係

---

## 9. クイックスタート手順

新プロジェクトでTerragrunt構成を初期構築する手順。

### ステップ1: ディレクトリ構成作成

```bash
mkdir -p terraform/{_env,0-foundation,1-network,2-security}
cd terraform
```

### ステップ2: root.hcl 作成

```bash
cat > root.hcl <<'EOF'
locals {
  env_name = get_env("TG_ENV", "prod")
  root_dir = get_parent_terragrunt_dir()
  env_vars = read_terragrunt_config("${local.root_dir}/_env/${local.env_name}.hcl").locals
  module_name = basename(get_terragrunt_dir())
}

remote_state {
  backend = "gcs"
  generate = {
    path      = "_backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket   = local.env_vars.terraform_state_bucket
    prefix   = "${path_relative_to_include()}-state"
    project  = local.env_vars.project_id
    location = local.env_vars.region
  }
}

generate "provider" {
  path      = "_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      project = "${local.env_vars.project_id}"
      region  = "${local.env_vars.region}"
    }
  EOF
}

terraform {
  extra_arguments "no_auto_init" {
    commands = ["plan", "apply", "destroy", "output", "validate", "refresh"]
    env_vars = {
      TERRAGRUNT_AUTO_INIT = "false"
    }
  }
}

inputs = {
  project_id  = local.env_vars.project_id
  region      = local.env_vars.region
  environment = local.env_vars.environment
}
EOF
```

### ステップ3: 環境設定作成

```bash
cat > _env/prod.hcl.example <<'EOF'
locals {
  environment            = "prod"
  project_id             = "your-project-id"
  organization_id        = "your-org-id"
  billing_account        = "your-billing-account"
  terraform_state_bucket = "your-project-id-tfstate"
  region                 = "asia-northeast1"
}
EOF

cp _env/prod.hcl.example _env/prod.hcl
# prod.hcl を編集して実際の値を設定
```

### ステップ4: .mise.toml 設定

```bash
# 前述のテンプレートを参照
```

### ステップ5: 最初のモジュール作成

```bash
cat > 0-foundation/terragrunt.hcl <<'EOF'
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

generate "versions" {
  path      = "_versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = "= 1.14.4"
      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "7.19.0"
        }
      }
    }
  EOF
}
EOF

cat > 0-foundation/main.tf <<'EOF'
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "dns.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}
EOF

cat > 0-foundation/variables.tf <<'EOF'
variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region"
}
EOF
```

### ステップ6: 初期化 → プラン → 適用

```bash
# 全モジュール初期化
mise run tg:init-all

# 依存関係確認
mise run tg:graph

# プラン
mise run tg:plan-all

# 適用
mise run tg:apply-all
```

---

## 10. トラブルシューティング

### よくある問題と解決策

#### 問題1: 依存モジュールが存在しない

```
Error: Dependency config path does not exist
```

**解決策**:
- `mock_outputs` と `mock_outputs_allowed_terraform_commands` を設定
- 依存モジュールを先に `apply` する

#### 問題2: 循環依存エラー

```
Error: Cycle detected in dependency graph
```

**解決策**:
- 依存関係を見直し、一方向の依存に変更
- 共通設定は root.hcl の inputs に移動

#### 問題3: キャッシュが原因の問題

```
Error: Inconsistent dependency lock file
```

**解決策**:
```bash
# キャッシュクリア
mise run tg:clean

# 再初期化
mise run tg:init-all:reconfigure
```

#### 問題4: 環境変数ファイルが見つからない

```
Error: Could not find _env/prod.hcl
```

**解決策**:
```bash
# サンプルファイルからコピー
cp _env/prod.hcl.example _env/prod.hcl

# 実際の値を設定
vim _env/prod.hcl
```

---

## 11. ベストプラクティスまとめ

| カテゴリ | ベストプラクティス |
|---------|------------------|
| **構造** | ・番号付きプレフィックスで依存順序を明示<br>・レイヤー化された設計（0→1→2→...）<br>・責務の明確な分離 |
| **セキュリティ** | ・`_env/*.hcl` をGit除外<br>・センシティブ情報はSecret Managerで管理<br>・サンプルファイル（.example）のみGit管理 |
| **依存関係** | ・循環依存を回避<br>・モック値を必ず設定<br>・依存の深さは5層以内 |
| **ファイル管理** | ・自動生成ファイル（`_*.tf`）をGit除外<br>・`.terragrunt-cache/` をGit除外<br>・`.gitignore` を適切に設定 |
| **実行管理** | ・miseタスクで実行を自動化<br>・`run --all` で依存順序を自動解決<br>・`dag graph` で依存関係を可視化 |
| **保守性** | ・root.hcl で共通設定を一元管理<br>・各モジュールで独自のプロバイダー設定が可能<br>・ドキュメント化（README.md） |

---

## 参考リソース

- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [mise task runner](https://mise.jdx.dev/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
