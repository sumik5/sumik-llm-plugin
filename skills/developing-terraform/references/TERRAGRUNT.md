# Terragruntリファレンス

## Terragruntとは

Terragruntは**TerraformのDRYラッパーツール**で、以下の課題を解決する:

- **設定の重複を排除**: 複数のTerraformモジュール間で共通設定（backend、provider等）を再利用
- **依存関係の自動解決**: モジュール間の依存順序を宣言的に管理し、`run --all`で自動実行
- **環境分離の簡素化**: 環境固有の変数を分離し、同一コードベースで複数環境を管理

**基本構造**:
- `root.hcl`: プロジェクト全体の共通設定（backend、provider、共通inputs）
- `terragrunt.hcl`: 各モジュール固有の設定（依存関係、追加inputs、プロバイダー拡張）
- `_env/*.hcl`: 環境固有変数（dev/staging/prod等）

---

## コア概念

### include ブロック

親の設定ファイル（通常は`root.hcl`）を継承する。

```hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true  # include.root.locals でアクセス可能にする
}
```

**関数**:
- `find_in_parent_folders("root.hcl")`: 親ディレクトリを上方向に探索してroot.hclを検索

**expose オプション**:
- `expose = true`: 親の`locals`ブロックを`include.root.locals.*`でアクセス可能に
- 用途: 環境変数（`include.root.locals.env_vars.project_id`）や共通定数の参照

**複数includeパターン**:
```hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

# 複数の親設定を include.root.*, include.region.* で参照可能
```

---

### dependency ブロック

**他のモジュールのoutputを依存として宣言し、自動的に順序実行を保証**。

```hcl
dependency "infra" {
  config_path = "../1-infra"

  # init/plan時に1-infraがまだ適用されていない場合のモック値
  mock_outputs = {
    vpc_network_name = "mock-vpc"
    region           = "asia-northeast1"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

inputs = {
  vpc_network_name = dependency.infra.outputs.vpc_network_name
  region           = dependency.infra.outputs.region
}
```

**重要な属性**:
- `config_path`: 依存先のterragrunt.hclがあるディレクトリの相対パス
- `mock_outputs`: 依存モジュールが未適用の場合に使用するダミー値
- `mock_outputs_allowed_terraform_commands`: モック値を使用可能なコマンドのリスト
- `mock_outputs_merge_strategy_with_state`: 実際のstateとモックのマージ戦略（`shallow`または`deep`）

**複数依存の例**（5a-webappから抜粋）:
```hcl
dependency "infra" {
  config_path = "../1-infra"
  mock_outputs = {
    project_id = "mock-project-id"
    region     = "asia-northeast1"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "base_services" {
  config_path = "../2-base-services"
  mock_outputs = {
    cloudsql_instance_connection_name = "mock:connection:name"
    serverless_connector_id           = "mock-connector"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

inputs = {
  project_id                        = dependency.infra.outputs.project_id
  region                            = dependency.infra.outputs.region
  cloudsql_instance_connection_name = dependency.base_services.outputs.cloudsql_instance_connection_name
  serverless_connector_id           = dependency.base_services.outputs.serverless_connector_id
}
```

---

### generate ブロック

**Terraform設定ファイルを動的生成**し、各モジュールに自動配置する。

**基本構文**:
```hcl
generate "<ラベル>" {
  path      = "_<filename>.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    # Terraform HCL content here
  EOF
}
```

**よくある生成パターン**:

#### 1. Provider自動生成（root.hclで一元管理）

```hcl
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
```

#### 2. Backend自動生成（remote_stateと併用）

```hcl
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
```

#### 3. Versions自動生成（モジュール固有のプロバイダー要件）

```hcl
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
        random = {
          source  = "hashicorp/random"
          version = "3.7.2"
        }
      }
    }
  EOF
}
```

#### 4. 追加プロバイダー生成（google-beta、keycloak等）

```hcl
generate "google_beta_provider" {
  path      = "_google_beta_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google-beta" {
      project               = var.project_id
      region                = var.region
      user_project_override = true
      billing_project       = var.project_id
    }
  EOF
}

generate "keycloak_provider" {
  path      = "_keycloak_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "keycloak" {
      client_id      = "admin-cli"
      username       = "admin"
      password       = data.google_secret_manager_secret_version.keycloak_admin_password.secret_data
      url            = var.keycloak_cloud_run_url
      client_timeout = 60
    }

    data "google_secret_manager_secret_version" "keycloak_admin_password" {
      project = var.project_id
      secret  = var.keycloak_admin_secret_id
      version = "latest"
    }
  EOF
}
```

**if_existsオプション**:
- `overwrite`: 常に上書き
- `overwrite_terragrunt`: Terragruntが生成したファイルのみ上書き（手動作成ファイルは保護）
- `skip`: 既存ファイルがあれば生成をスキップ
- `error`: 既存ファイルがあればエラー

---

### inputs ブロック

**Terraformモジュールに渡す変数を定義**。root.hclの共通inputsとマージされる。

**root.hclでの共通inputs**:
```hcl
inputs = {
  project_id      = local.env_vars.project_id
  organization_id = local.env_vars.organization_id
  billing_account = local.env_vars.billing_account
  region          = local.env_vars.region
  domain          = local.env_vars.domain
}
```

**モジュール固有のinputs（dependencyの出力を参照）**:
```hcl
dependency "infra" {
  config_path = "../1-infra"
  mock_outputs = {
    vpc_network_name = "mock-vpc"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

inputs = {
  # root.hclのinputsが自動的にマージされる
  vpc_network_name = dependency.infra.outputs.vpc_network_name
}
```

**環境固有変数の参照**:
```hcl
inputs = {
  smtp_password   = include.root.locals.env_vars.smtp_password
  nextauth_secret = include.root.locals.env_vars.nextauth_secret
}
```

**マージ順序**:
1. root.hclの`inputs`ブロック（共通変数）
2. モジュールの`terragrunt.hcl`の`inputs`ブロック（モジュール固有変数）
3. 同じキーがあれば、モジュール固有が優先

---

## root.hcl テンプレート

### GCSバックエンド版（Google Cloud Storage）

```hcl
# =============================================================================
# Terragrunt ルート設定
# =============================================================================

locals {
  # 環境設定ファイルを読み込み（デフォルト: dev）
  # 環境切り替え: TG_ENV=prod terragrunt run --all apply
  env_name = get_env("TG_ENV", "dev")

  # ルートディレクトリのパスを取得
  root_dir = get_parent_terragrunt_dir()

  # 環境設定ファイルを読み込み
  env_vars = read_terragrunt_config("${local.root_dir}/_env/${local.env_name}.hcl").locals

  # モジュール名を相対パスから取得（例: "1-infra"）
  module_name = basename(get_terragrunt_dir())
}

# -----------------------------------------------------------------------------
# リモートステート設定
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
# Provider 設定を自動生成
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
# Terragrunt 実行設定
# -----------------------------------------------------------------------------
terraform {
  # auto-init を無効化（initは明示的に実行）
  extra_arguments "no_auto_init" {
    commands = ["plan", "apply", "destroy", "output", "validate", "refresh"]
    env_vars = {
      TERRAGRUNT_AUTO_INIT = "false"
    }
  }

  # 並列実行数を制限（デフォルト: 無制限）
  extra_arguments "parallelism" {
    commands = ["apply", "plan", "destroy"]
    arguments = ["-parallelism=10"]
  }
}

# -----------------------------------------------------------------------------
# 共通 inputs
# -----------------------------------------------------------------------------
inputs = {
  project_id      = local.env_vars.project_id
  organization_id = local.env_vars.organization_id
  billing_account = local.env_vars.billing_account
  region          = local.env_vars.region
  environment     = local.env_vars.environment
}
```

---

### S3バックエンド版（AWS）

```hcl
# =============================================================================
# Terragrunt ルート設定（AWS版）
# =============================================================================

locals {
  env_name = get_env("TG_ENV", "dev")
  root_dir = get_parent_terragrunt_dir()
  env_vars = read_terragrunt_config("${local.root_dir}/_env/${local.env_name}.hcl").locals
  module_name = basename(get_terragrunt_dir())
}

# -----------------------------------------------------------------------------
# リモートステート設定（S3 + DynamoDB）
# -----------------------------------------------------------------------------
remote_state {
  backend = "s3"
  generate = {
    path      = "_backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = local.env_vars.terraform_state_bucket
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.env_vars.region
    encrypt        = true
    dynamodb_table = local.env_vars.terraform_lock_table
  }
}

# -----------------------------------------------------------------------------
# Provider 設定を自動生成
# -----------------------------------------------------------------------------
generate "provider" {
  path      = "_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.env_vars.region}"

      default_tags {
        tags = {
          Environment = "${local.env_vars.environment}"
          ManagedBy   = "Terragrunt"
          Module      = "${local.module_name}"
        }
      }
    }
  EOF
}

# -----------------------------------------------------------------------------
# Terragrunt 実行設定
# -----------------------------------------------------------------------------
terraform {
  extra_arguments "no_auto_init" {
    commands = ["plan", "apply", "destroy", "output", "validate", "refresh"]
    env_vars = {
      TERRAGRUNT_AUTO_INIT = "false"
    }
  }

  extra_arguments "parallelism" {
    commands = ["apply", "plan", "destroy"]
    arguments = ["-parallelism=10"]
  }
}

# -----------------------------------------------------------------------------
# 共通 inputs
# -----------------------------------------------------------------------------
inputs = {
  region      = local.env_vars.region
  environment = local.env_vars.environment
  vpc_id      = local.env_vars.vpc_id
}
```

---

## terragrunt.hcl パターン集

### パターン1: 基本（依存なし）

**用途**: 最初に実行するモジュール（例: API有効化、IAMロール作成等）

```hcl
# 0-services/terragrunt.hcl
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

# 依存関係なし（最初に実行）
```

---

### パターン2: 単一依存

**用途**: 1つのモジュールに依存する場合（例: VPCを作成するインフラモジュール）

```hcl
# 1-infra/terragrunt.hcl
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

dependency "services" {
  config_path = "../0-services"

  # init/plan時のモック値
  mock_outputs = {
    project_id = "mock-project-id"
    region     = "asia-northeast1"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

inputs = {
  # 依存モジュールの出力を使用（実際は0-servicesはoutputを返さないが例示）
}
```

---

### パターン3: 複数依存

**用途**: 複数モジュールの出力を必要とする場合（例: Cloud RunがVPC、DB、レジストリに依存）

```hcl
# 5a-webapp/terragrunt.hcl
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

dependency "infra" {
  config_path = "../1-infra"
  mock_outputs = {
    vpc_network_name = "mock-vpc"
    region           = "asia-northeast1"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "base_services" {
  config_path = "../2-base-services"
  mock_outputs = {
    cloudsql_instance_connection_name = "mock:connection:name"
    serverless_connector_id           = "mock-connector"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "registry" {
  config_path = "../3-registry"
  mock_outputs = {
    artifact_repo_id = "mock-repo"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

inputs = {
  vpc_network_name                  = dependency.infra.outputs.vpc_network_name
  region                            = dependency.infra.outputs.region
  cloudsql_instance_connection_name = dependency.base_services.outputs.cloudsql_instance_connection_name
  serverless_connector_id           = dependency.base_services.outputs.serverless_connector_id
  artifact_repo_id                  = dependency.registry.outputs.artifact_repo_id
}
```

---

### パターン4: カスタムプロバイダー

**用途**: 追加プロバイダーが必要な場合（google-beta、random、null、keycloak等）

```hcl
# 2-base-services/terragrunt.hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# random プロバイダーを追加
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
        random = {
          source  = "hashicorp/random"
          version = "3.7.2"
        }
      }
    }
  EOF
}

dependency "infra" {
  config_path = "../1-infra"
  mock_outputs = {
    vpc_network_name = "mock-vpc"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

inputs = {
  vpc_network_name = dependency.infra.outputs.vpc_network_name
}
```

**複数カスタムプロバイダー + provider設定生成**:
```hcl
# 5a-webapp/terragrunt.hcl（抜粋）
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
        google-beta = {
          source  = "hashicorp/google-beta"
          version = "7.19.0"
        }
        keycloak = {
          source  = "keycloak/keycloak"
          version = "5.5.0"
        }
        random = {
          source  = "hashicorp/random"
          version = "3.7.2"
        }
        null = {
          source  = "hashicorp/null"
          version = "3.2.3"
        }
      }
    }
  EOF
}

generate "google_beta_provider" {
  path      = "_google_beta_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google-beta" {
      project               = var.project_id
      region                = var.region
      user_project_override = true
      billing_project       = var.project_id
    }
  EOF
}

generate "keycloak_provider" {
  path      = "_keycloak_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "keycloak" {
      client_id      = "admin-cli"
      username       = "admin"
      password       = data.google_secret_manager_secret_version.keycloak_admin_password.secret_data
      url            = var.keycloak_cloud_run_url
      client_timeout = 60
    }

    data "google_secret_manager_secret_version" "keycloak_admin_password" {
      project = var.project_id
      secret  = var.keycloak_admin_secret_id
      version = "latest"
    }
  EOF
}
```

---

### パターン5: mock_outputs設計のベストプラクティス

**原則**:
1. **型の一致**: 実際のoutputと同じ型を使用（string, number, map, list等）
2. **命名規則**: `mock-*` プレフィックスで一目で識別可能に
3. **構造の再現**: 複雑なオブジェクトは同じ構造を維持
4. **allowed_terraform_commands**: `["init", "validate", "plan", "destroy"]` を基本セット

**例1: プリミティブ型**
```hcl
mock_outputs = {
  project_id      = "mock-project-id"       # string
  region          = "asia-northeast1"       # string
  port            = 5432                    # number
  enable_feature  = false                   # bool
}
```

**例2: 複雑な型（map、list）**
```hcl
mock_outputs = {
  # map(string)
  labels = {
    environment = "mock"
    managed_by  = "terragrunt"
  }

  # list(string)
  availability_zones = ["mock-zone-a", "mock-zone-b"]

  # list(object)
  subnets = [
    {
      name       = "mock-subnet-1"
      cidr_range = "10.0.1.0/24"
    },
    {
      name       = "mock-subnet-2"
      cidr_range = "10.0.2.0/24"
    }
  ]
}
```

**例3: GCPリソース固有のパターン**
```hcl
mock_outputs = {
  # Cloud SQL接続名（<project>:<region>:<instance>形式）
  cloudsql_instance_connection_name = "mock-project:mock-region:mock-instance"

  # VPCネットワーク（完全修飾パス）
  vpc_network = "projects/mock-project-id/global/networks/mock-vpc"

  # サブネット（完全修飾パス）
  vpc_subnetwork = "projects/mock-project-id/regions/asia-northeast1/subnetworks/mock-subnet"

  # Secret Manager参照
  secret_id = "projects/123456789012/secrets/mock-secret/versions/latest"
}
```

**例4: mock_outputs_merge_strategy_with_state**

依存モジュールが既に適用済みでstateが存在する場合、モック値とstateの値をどうマージするか制御:

```hcl
dependency "infra" {
  config_path = "../1-infra"

  mock_outputs = {
    vpc_network_name = "mock-vpc"
  }

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]

  # shallow: stateの値が優先され、存在しないキーのみmock_outputsを使用（デフォルト）
  # deep: 深くマージし、ネストされたオブジェクトでもstateとモックを統合
  mock_outputs_merge_strategy_with_state = "shallow"
}
```

---

### パターン6: 環境固有inputs

**用途**: 環境ごとに異なる値（機密情報、環境固有のリソースID等）を`_env/*.hcl`から読み込む

```hcl
# 5a-webapp/terragrunt.hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

inputs = {
  # root.hclの共通inputsが自動マージされる

  # 環境固有の機密情報（_env/prod.hclから読み込み）
  smtp_password   = include.root.locals.env_vars.smtp_password
  nextauth_secret = include.root.locals.env_vars.nextauth_secret

  # 依存モジュールの出力
  project_id = dependency.infra.outputs.project_id
}
```

**対応する_env/prod.hcl**:
```hcl
locals {
  # 環境識別
  environment = "prod"

  # 機密情報（gitignoreで除外）
  smtp_password   = "actual-smtp-password-here"
  nextauth_secret = "actual-nextauth-secret-here"

  # その他の環境固有設定
  project_id             = "prod-project-id"
  terraform_state_bucket = "prod-project-id-tfstate"
}
```

---

### パターン7: remote_stateのカスタマイズ

**用途**: 特定のモジュールで異なるstate prefixを使用（ディレクトリリネーム後の互換性維持等）

```hcl
# 5a-webapp/terragrunt.hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# State prefix を固定（旧ディレクトリ名の state を継続使用）
remote_state {
  backend = "gcs"
  generate = {
    path      = "_backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket   = include.root.locals.env_vars.terraform_state_bucket
    prefix   = "5-webapp-state"  # 固定値（root.hclの動的生成を上書き）
    project  = include.root.locals.env_vars.project_id
    location = include.root.locals.env_vars.region
  }
}

# 以降は通常通りのdependency、inputs等
```

**説明**: root.hclでは`prefix = "${path_relative_to_include()}-state"`で動的生成されるが、このモジュールでは`remote_state`ブロックを再定義して固定値を使用。

---

## 環境分離パターン

### _env/ディレクトリ構造

```
terraform/
├── root.hcl
├── _env/
│   ├── dev.hcl
│   ├── staging.hcl
│   ├── prod.hcl
│   └── prod.hcl.example  # テンプレート（gitにコミット）
├── 0-services/
│   └── terragrunt.hcl
├── 1-infra/
│   └── terragrunt.hcl
└── ...
```

**.gitignoreの設定**:
```gitignore
# 環境固有設定（機密情報含む）
_env/*.hcl

# .exampleファイルはコミット
!_env/*.hcl.example
```

---

### _env/*.hcl の設計

**_env/prod.hcl.example**（テンプレート）:
```hcl
# =============================================================================
# 環境設定サンプル
# =============================================================================
# このファイルをコピーして prod.hcl を作成してください
#
# 使用方法:
#   cp prod.hcl.example prod.hcl
#   # prod.hcl を編集して実際の値を設定
#
# 環境切り替え:
#   TG_ENV=prod terragrunt run --all apply
# =============================================================================

locals {
  # 環境識別
  environment = "prod"

  # GCP プロジェクト基本設定
  project_id             = "your-project-id"
  organization_id        = "your-organization-id"
  billing_account        = "your-billing-account-id"
  terraform_state_bucket = "your-project-id-tfstate"
  region                 = "asia-northeast1"

  # ドメイン設定
  domain = "example.com"

  # 機密情報（sensitive）
  smtp_password   = "your-smtp-password"  # sensitive
  nextauth_secret = "your-nextauth-secret-32-chars-or-more"  # sensitive: openssl rand -base64 32

  # その他の環境固有設定
  enable_monitoring = true
  log_level         = "INFO"
}
```

**_env/dev.hcl**（開発環境）:
```hcl
locals {
  environment = "dev"

  project_id             = "dev-project-id"
  organization_id        = "123456789012"
  billing_account        = "XXXXXX-XXXXXX-XXXXXX"
  terraform_state_bucket = "dev-project-id-tfstate"
  region                 = "asia-northeast1"

  domain = "dev.example.com"

  smtp_password   = "dev-smtp-password"
  nextauth_secret = "dev-nextauth-secret"

  enable_monitoring = false
  log_level         = "DEBUG"
}
```

---

### TG_ENV環境変数による切り替え

**root.hclでの読み込み**:
```hcl
locals {
  # 環境設定ファイルを読み込み（デフォルト: dev）
  env_name = get_env("TG_ENV", "dev")

  # 環境設定を読み込み
  env_vars = read_terragrunt_config("${local.root_dir}/_env/${local.env_name}.hcl").locals
}
```

**使用例**:
```bash
# dev環境（デフォルト）
terragrunt run --all plan

# prod環境
TG_ENV=prod terragrunt run --all plan
TG_ENV=prod terragrunt run --all apply

# staging環境
TG_ENV=staging terragrunt run --all plan
```

**CI/CDでの活用**:
```yaml
# GitHub Actions例
- name: Terragrunt Apply (Prod)
  run: |
    export TG_ENV=prod
    terragrunt run --all apply --terragrunt-non-interactive
  working-directory: terraform/
```

---

## run --all による一括実行

### 基本コマンド

Terragruntは**依存関係を解析して自動的に正しい順序で実行**する。

```bash
# すべてのモジュールを初期化
terragrunt run --all init

# すべてのモジュールをplan（依存順序を自動解決）
terragrunt run --all plan

# すべてのモジュールをapply（依存順序を自動解決）
terragrunt run --all apply

# すべてのモジュールを破棄
terragrunt run --all destroy
```

---

### 実行順序の自動解決

**ディレクトリ構造**:
```
terraform/
├── 0-services/      # 依存なし → 最初
├── 1-infra/         # 0-services に依存 → 2番目
├── 2-base-services/ # 1-infra に依存 → 3番目
└── 5a-webapp/       # 1-infra, 2-base-services, 3-registry, 4a-keycloak-infra, 4b-keycloak-config に依存 → 最後
```

`terragrunt run --all apply` を実行すると:
1. `0-services` を実行
2. `0-services` 完了後、`1-infra` を実行
3. `1-infra` 完了後、`2-base-services` を実行
4. 依存がすべて満たされた時点で `5a-webapp` を実行

**依存関係のグラフ表示**:
```bash
terragrunt graph-dependencies
```

**出力例**:
```
digraph {
  "0-services" ;
  "1-infra"  -> "0-services";
  "2-base-services"  -> "1-infra";
  "5a-webapp"  -> "1-infra";
  "5a-webapp"  -> "2-base-services";
}
```

---

### --exclude-dir オプション

特定のディレクトリを除外して実行:

```bash
# 5a-webapp を除外してplan
terragrunt run --all plan --terragrunt-exclude-dir 5a-webapp

# 複数ディレクトリを除外
terragrunt run --all apply \
  --terragrunt-exclude-dir 5a-webapp \
  --terragrunt-exclude-dir 4b-keycloak-config
```

---

### 並列実行と安全性

**並列実行の制御**:
```bash
# 並列実行数を制限（デフォルト: 無制限）
terragrunt run --all apply --terragrunt-parallelism 3
```

**root.hclでの設定**:
```hcl
terraform {
  extra_arguments "parallelism" {
    commands = ["apply", "plan", "destroy"]
    arguments = ["-parallelism=10"]
  }
}
```

**注意事項**:
- `run --all apply` は **依存関係が解決された時点で並列実行される**
- `--terragrunt-parallelism` で同時実行数を制限可能
- **state lockによる競合回避**: GCSバックエンドやS3+DynamoDBが自動的にロック管理

---

### 非対話モード

CI/CDでの自動実行時に確認プロンプトをスキップ:

```bash
# plan: 確認不要（常に非破壊）
terragrunt run --all plan --terragrunt-non-interactive

# apply: 自動承認（注意！）
terragrunt run --all apply --terragrunt-non-interactive

# destroy: 自動承認（危険！本番環境では絶対に使わない）
terragrunt run --all destroy --terragrunt-non-interactive
```

---

## コマンドリファレンス

### 基本コマンド

| コマンド | 説明 | 使用例 |
|---------|------|--------|
| `terragrunt init` | 現在のモジュールを初期化 | `cd 1-infra && terragrunt init` |
| `terragrunt plan` | 現在のモジュールをplan | `cd 1-infra && terragrunt plan` |
| `terragrunt apply` | 現在のモジュールをapply | `cd 1-infra && terragrunt apply` |
| `terragrunt destroy` | 現在のモジュールを破棄 | `cd 1-infra && terragrunt destroy` |
| `terragrunt output` | 現在のモジュールのoutputを表示 | `terragrunt output vpc_network_name` |
| `terragrunt validate` | 現在のモジュールを検証 | `terragrunt validate` |

---

### run --all コマンド

| コマンド | 説明 | 使用例 |
|---------|------|--------|
| `terragrunt run --all init` | すべてのモジュールを初期化 | `terragrunt run --all init` |
| `terragrunt run --all plan` | すべてのモジュールをplan（依存順序を自動解決） | `terragrunt run --all plan` |
| `terragrunt run --all apply` | すべてのモジュールをapply（依存順序を自動解決） | `terragrunt run --all apply` |
| `terragrunt run --all destroy` | すべてのモジュールを破棄（依存の逆順） | `terragrunt run --all destroy` |
| `terragrunt run --all output` | すべてのモジュールのoutputを表示 | `terragrunt run --all output` |
| `terragrunt run --all validate` | すべてのモジュールを検証 | `terragrunt run --all validate` |

---

### グラフ・デバッグコマンド

| コマンド | 説明 | 使用例 |
|---------|------|--------|
| `terragrunt graph-dependencies` | 依存関係のグラフを生成（DOT形式） | `terragrunt graph-dependencies \| dot -Tpng > deps.png` |
| `terragrunt render-json` | terragrunt.hclをJSON形式で表示 | `terragrunt render-json` |
| `terragrunt validate-inputs` | inputsの妥当性を検証 | `terragrunt validate-inputs` |
| `terragrunt output-module-groups` | モジュールグループを表示 | `terragrunt output-module-groups` |

---

### オプション

| オプション | 説明 | 使用例 |
|-----------|------|--------|
| `--terragrunt-non-interactive` | 確認プロンプトをスキップ | `terragrunt apply --terragrunt-non-interactive` |
| `--terragrunt-exclude-dir <dir>` | 特定のディレクトリを除外 | `terragrunt run --all apply --terragrunt-exclude-dir 5a-webapp` |
| `--terragrunt-include-dir <dir>` | 特定のディレクトリのみ実行 | `terragrunt run --all plan --terragrunt-include-dir 1-infra` |
| `--terragrunt-parallelism <N>` | 並列実行数を制限 | `terragrunt run --all apply --terragrunt-parallelism 3` |
| `--terragrunt-working-dir <dir>` | 作業ディレクトリを指定 | `terragrunt plan --terragrunt-working-dir ../1-infra` |
| `--terragrunt-log-level <level>` | ログレベル（trace/debug/info/warn/error） | `terragrunt apply --terragrunt-log-level debug` |

---

## ベストプラクティス

### 1. ディレクトリ命名規則

**番号プレフィックスで実行順序を明示**:
```
0-services/         # 最初（GCP API有効化等）
1-infra/            # インフラ基盤（VPC、DNS等）
2-base-services/    # 基礎サービス（DB、Secret Manager等）
3-registry/         # コンテナレジストリ
4a-keycloak-infra/  # Keycloakインフラ
4b-keycloak-config/ # Keycloak設定
5a-webapp/          # Webアプリケーション
```

**サブステップは英字サフィックス**（`4a`, `4b`）:
- 同じ依存レベルで並列実行可能なモジュール

---

### 2. 環境固有変数の管理

**原則**:
- **機密情報は`_env/*.hcl`に集約**し、`.gitignore`で除外
- **`.hcl.example`をテンプレートとしてコミット**
- **環境変数`TG_ENV`で切り替え**

**チェックリスト**:
- [ ] `_env/*.hcl` は`.gitignore`に追加済み
- [ ] `_env/*.hcl.example` をコミット済み
- [ ] `.hcl.example` にコメントでセットアップ手順を記載

---

### 3. mock_outputsの設計

**原則**:
- **型を実際のoutputと一致させる**
- **`mock-*` プレフィックスで識別可能にする**
- **GCPリソースは完全修飾パスを再現**（例: `projects/.../networks/...`）
- **`mock_outputs_allowed_terraform_commands`は基本セット**を使用:
  ```hcl
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
  ```

---

### 4. generateブロックの一貫性

**原則**:
- **`if_exists = "overwrite_terragrunt"`を使用**（手動作成ファイルを保護）
- **ファイル名は`_`プレフィックス**を付ける（例: `_provider.tf`, `_backend.tf`）
- **versionsは各モジュールで定義**（モジュール固有のプロバイダー要件に対応）

---

### 5. 依存関係の最小化

**原則**:
- **本当に必要なoutputのみdependencyで参照**
- **過度な依存は並列実行を阻害**

**悪い例**:
```hcl
# 5a-webappが0-servicesに直接依存（不要）
dependency "services" {
  config_path = "../0-services"
}
```

**良い例**:
```hcl
# 5a-webappは1-infraに依存（1-infraが0-servicesに依存しているので間接的に順序保証される）
dependency "infra" {
  config_path = "../1-infra"
}
```

---

### 6. 初回実行フロー

**推奨手順**:
```bash
# 1. 環境設定ファイルを作成
cd terraform/_env
cp prod.hcl.example prod.hcl
# prod.hcl を編集して実際の値を設定

# 2. 環境変数を設定
export TG_ENV=prod

# 3. すべてのモジュールを初期化
terragrunt run --all init

# 4. すべてのモジュールをplan
terragrunt run --all plan

# 5. 問題なければapply
terragrunt run --all apply
```

---

### 7. CI/CDでの活用

**GitHub Actions例**:
```yaml
name: Terragrunt CI/CD

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'

jobs:
  terragrunt-plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terragrunt
        run: |
          wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.69.16/terragrunt_linux_amd64
          chmod +x terragrunt_linux_amd64
          sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.14.4

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Terragrunt Init
        run: terragrunt run --all init --terragrunt-non-interactive
        working-directory: terraform/
        env:
          TG_ENV: prod

      - name: Terragrunt Plan
        run: terragrunt run --all plan --terragrunt-non-interactive
        working-directory: terraform/
        env:
          TG_ENV: prod

  terragrunt-apply:
    needs: terragrunt-plan
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terragrunt
        run: |
          wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.69.16/terragrunt_linux_amd64
          chmod +x terragrunt_linux_amd64
          sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.14.4

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Terragrunt Apply
        run: terragrunt run --all apply --terragrunt-non-interactive
        working-directory: terraform/
        env:
          TG_ENV: prod
```

---

## トラブルシューティング

### エラー1: `mock_outputs` の型不一致

**症状**:
```
Error: Invalid value for input variable
  on _backend.tf line 10, in variable "vpc_network_name":
  10:   type = string
Expected string, got map.
```

**原因**: mock_outputsで定義した型が実際のoutputと異なる

**解決策**:
```hcl
# 悪い例
mock_outputs = {
  vpc_network = {
    name = "mock-vpc"
  }
}

# 良い例（実際のoutputがstringの場合）
mock_outputs = {
  vpc_network_name = "mock-vpc"
}
```

---

### エラー2: 依存モジュールのoutputが見つからない

**症状**:
```
Error: Invalid index
  on terragrunt.hcl line 45:
  45:   region = dependency.infra.outputs.region
The given key does not identify an element in this collection value.
```

**原因**: 依存モジュール（1-infra）がまだ`apply`されていない

**解決策**:
1. **依存モジュールを先に適用**:
   ```bash
   cd 1-infra && terragrunt apply
   ```

2. **または`run --all`で自動解決**:
   ```bash
   terragrunt run --all apply
   ```

---

### エラー3: State lock取得失敗

**症状**:
```
Error: Error acquiring the state lock
Lock Info:
  ID:        1234abcd-5678-ef90-1234-567890abcdef
  Path:      gs://my-bucket/1-infra-state/default.tflock
  Operation: OperationTypeApply
  Who:       user@example.com
  Version:   1.14.4
  Created:   2025-02-17 12:34:56.789 UTC
```

**原因**:
- 他のユーザー/プロセスが同じモジュールを操作中
- 前回の実行が異常終了してlockが残っている

**解決策**:
1. **他のプロセスが終了するまで待つ**

2. **強制的にロックを解除**（慎重に！）:
   ```bash
   # Terragruntを使用
   cd 1-infra
   terragrunt force-unlock <LOCK_ID>

   # 例
   terragrunt force-unlock 1234abcd-5678-ef90-1234-567890abcdef
   ```

---

### エラー4: `_env/*.hcl` が見つからない

**症状**:
```
Error: Failed to read file
  on root.hcl line 17:
  17:   env_vars = read_terragrunt_config("${local.root_dir}/_env/${local.env_name}.hcl").locals
The file "_env/prod.hcl" does not exist.
```

**原因**: 環境設定ファイルが作成されていない

**解決策**:
```bash
# テンプレートをコピー
cd terraform/_env
cp prod.hcl.example prod.hcl

# 実際の値を設定
vim prod.hcl
```

---

### エラー5: プロバイダーバージョンの競合

**症状**:
```
Error: Invalid provider configuration
Provider "google" requires version 7.19.0, but version 6.0.0 is installed.
```

**原因**: 異なるモジュールで異なるプロバイダーバージョンを指定

**解決策**:
1. **すべてのモジュールで同じバージョンを使用**:
   ```hcl
   # すべてのterragrunt.hclで統一
   generate "versions" {
     # ...
     contents = <<-EOF
       terraform {
         required_providers {
           google = {
             source  = "hashicorp/google"
             version = "7.19.0"  # 統一
           }
         }
       }
     EOF
   }
   ```

2. **または`.terraform.lock.hcl`を削除して再初期化**:
   ```bash
   find . -name ".terraform.lock.hcl" -delete
   terragrunt run --all init
   ```

---

## まとめ

Terragruntは**Terraformの設定を効率化し、複雑なマルチモジュール構成を管理可能にする**ツールである。

**重要なポイント**:
1. **root.hcl**: 全モジュール共通の設定（backend、provider、共通inputs）
2. **dependency**: モジュール間の依存関係を宣言し、自動順序実行
3. **mock_outputs**: 依存モジュールが未適用でもinit/planを可能にする
4. **generate**: provider/backend/versionsファイルを自動生成し一貫性を確保
5. **_env/*.hcl**: 環境固有変数を分離し、TG_ENVで切り替え
6. **run --all**: 依存関係を自動解決して全モジュールを順序実行

このリファレンスを活用して、保守性の高いTerraform基盤を構築すること。
