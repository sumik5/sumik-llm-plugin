# テスト・ツール・ドキュメンテーション

Terraformコードの品質管理とドキュメント化。

## 📋 目次

1. [terraform test](#terraform-test)
2. [LocalStack](#localstack)
3. [terraform-docs](#terraform-docs)
4. [tflint](#tflint)
5. [その他のツール](#その他のツール)

---

## terraform test

### 基本的な書き方

Terraform 1.6.0以降で利用可能な組み込みテストフレームワーク:

```hcl
# tests/vpc.tftest.hcl
run "vpc_creation" {
  command = plan

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR should be 10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_support == true
    error_message = "DNS support should be enabled"
  }

  assert {
    condition     = aws_vpc.main.tags["Name"] == "myapp-dev-vpc"
    error_message = "VPC name tag is incorrect"
  }
}

run "subnet_count" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Should create 2 public subnets"
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Should create 2 private subnets"
  }
}
```

---

### テストの実行

```bash
# 全テストを実行
terraform test

# 特定のテストファイルのみ実行
terraform test tests/vpc.tftest.hcl

# 詳細出力
terraform test -verbose

# JSON形式で出力
terraform test -json
```

---

### 注意点

**現時点での制約:**
- モックやスタブの機能が限定的
- 実際のリソース作成を伴う場合、コストとクリーンアップが必要
- LocalStackとの組み合わせが推奨

**代替手段:**
- Terratest（Go言語）
- Kitchen-Terraform（Ruby）
- pytest-terraform（Python）

---

## LocalStack

### ローカルテスト環境

LocalStackはAWSサービスをローカルでエミュレート:

**サポートサービス（主要なもの）:**
- S3, DynamoDB, Lambda, SQS, SNS, CloudWatch
- EC2（一部）, ECS（一部）, RDS（限定的）

**公式サイト:**
- https://localstack.cloud/

---

### コマンド準備

#### Docker Composeで起動

```yaml
# docker-compose.yml
version: '3.8'

services:
  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"
    environment:
      - SERVICES=s3,dynamodb,lambda,sqs,sns
      - DEBUG=1
      - DATA_DIR=/tmp/localstack/data
    volumes:
      - "./localstack-data:/tmp/localstack"
      - "/var/run/docker.sock:/var/run/docker.sock"
```

```bash
docker-compose up -d
```

---

#### tflocal（Terraformラッパー）

LocalStack用のTerraformラッパー:

```bash
# インストール
pip install terraform-local

# 使用
tflocal init
tflocal plan
tflocal apply
```

**tflocal の内部動作:**
- AWS エンドポイントを自動的に `http://localhost:4566` に変更
- 認証情報をダミー値に設定

---

### ソースコードのプロバイダー設定

LocalStack用のプロバイダー設定:

```hcl
# provider.tf
provider "aws" {
  region                      = "ap-northeast-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    sns            = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    cloudwatchlogs = "http://localhost:4566"
  }
}
```

**環境変数での切り替え:**

```hcl
# locals.tf
locals {
  use_localstack = var.environment == "local"

  aws_endpoints = local.use_localstack ? {
    s3       = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
    # ...
  } : {}
}

# provider.tf
provider "aws" {
  region = var.aws_region

  dynamic "endpoints" {
    for_each = length(local.aws_endpoints) > 0 ? [local.aws_endpoints] : []
    content {
      s3       = lookup(endpoints.value, "s3", null)
      dynamodb = lookup(endpoints.value, "dynamodb", null)
      # ...
    }
  }

  skip_credentials_validation = local.use_localstack
  skip_metadata_api_check     = local.use_localstack
  skip_requesting_account_id  = local.use_localstack
}
```

---

### モックリソースの作成例（DynamoDB）

```hcl
# dynamodb.tf
resource "aws_dynamodb_table" "example" {
  name           = "example-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key      = "timestamp"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  tags = {
    Name        = "example-table"
    Environment = var.environment
  }
}
```

**LocalStackでのテスト:**

```bash
# LocalStack起動
docker-compose up -d

# Terraform実行
tflocal init
tflocal apply

# 動作確認（AWS CLI）
aws --endpoint-url=http://localhost:4566 dynamodb list-tables

# データ挿入
aws --endpoint-url=http://localhost:4566 dynamodb put-item \
  --table-name example-table \
  --item '{"id": {"S": "test-id"}, "timestamp": {"N": "1234567890"}}'

# データ取得
aws --endpoint-url=http://localhost:4566 dynamodb get-item \
  --table-name example-table \
  --key '{"id": {"S": "test-id"}, "timestamp": {"N": "1234567890"}}'
```

---

## terraform-docs

### 基本コマンド

モジュールのドキュメントを自動生成:

```bash
# README.mdを生成
terraform-docs markdown table . > README.md

# 標準出力
terraform-docs markdown table .

# 特定のディレクトリ
terraform-docs markdown table modules/vpc/
```

---

### テンプレートファイルの活用

`.terraform-docs.yml`で出力をカスタマイズ:

```yaml
# .terraform-docs.yml
formatter: markdown table

version: ""

header-from: main.tf

sections:
  show:
    - header
    - requirements
    - providers
    - inputs
    - outputs
    - resources

content: |-
  {{ .Header }}

  ## 概要

  このモジュールは...（カスタム説明）

  ## 使用例

  ```hcl
  module "vpc" {
    source = "./modules/vpc"

    vpc_cidr_block = "10.0.0.0/16"
    service_name   = "myapp"
    env            = "dev"
  }
  ```

  {{ .Requirements }}

  {{ .Providers }}

  {{ .Inputs }}

  {{ .Outputs }}

  {{ .Resources }}

output:
  file: README.md
  mode: inject
  template: |-
    <!-- BEGIN_TF_DOCS -->
    {{ .Content }}
    <!-- END_TF_DOCS -->

sort:
  enabled: true
  by: required

settings:
  indent: 2
  required: true
  sensitive: true
  type: true
```

**実行:**

```bash
terraform-docs .
```

**出力例（README.md）:**

```markdown
<!-- BEGIN_TF_DOCS -->
# VPCモジュール

## 概要

このモジュールは...

## 使用例

...

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc_cidr_block | VPCのCIDRブロック | `string` | n/a | yes |
| service_name | サービス名 | `string` | n/a | yes |
| env | 環境名 | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPCのID |
| vpc_cidr_block | VPCのCIDRブロック |

<!-- END_TF_DOCS -->
```

---

### CI自動化

GitHub Actionsで自動更新:

```yaml
# .github/workflows/terraform-docs.yml
name: Generate Terraform Docs

on:
  pull_request:
    paths:
      - '**.tf'

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          ref: ${{ github.event.pull_request.head.ref }}

      - name: Render terraform docs
        uses: terraform-docs/gh-actions@v1
        with:
          working-dir: .
          output-file: README.md
          output-method: inject
          git-push: true
```

---

## tflint

### Linterの活用

Terraformコードの静的解析:

```bash
# インストール（macOS）
brew install tflint

# インストール（Linux）
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# 初期化
tflint --init

# 実行
tflint

# 特定のディレクトリ
tflint modules/vpc/

# 再帰的にチェック
tflint --recursive

# ルールの無効化
tflint --disable-rule=terraform_unused_declarations
```

---

### 設定ファイル

`.tflint.hcl`でルールをカスタマイズ:

```hcl
# .tflint.hcl
config {
  module = true
  force  = false
}

plugin "aws" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_naming_convention" {
  enabled = true

  variable {
    format = "snake_case"
  }

  locals {
    format = "snake_case"
  }

  output {
    format = "snake_case"
  }

  resource {
    format = "snake_case"
  }

  module {
    format = "snake_case"
  }

  data {
    format = "snake_case"
  }
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

# AWS固有のルール
rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_s3_bucket_invalid_region" {
  enabled = true
}
```

---

### カスタムルール

独自のルールを定義:

```hcl
rule "enforce_resource_tags" {
  enabled = true
}
```

**Goでルール実装（例）:**

```go
package rules

import (
	"github.com/terraform-linters/tflint-plugin-sdk/tflint"
)

type EnforceResourceTagsRule struct{}

func (r *EnforceResourceTagsRule) Name() string {
	return "enforce_resource_tags"
}

func (r *EnforceResourceTagsRule) Check(runner tflint.Runner) error {
	// 実装...
	return nil
}
```

---

### CI統合

```yaml
# .github/workflows/tflint.yml
name: TFLint

on:
  pull_request:
    paths:
      - '**.tf'

jobs:
  tflint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: terraform-linters/setup-tflint@v3
        with:
          tflint_version: latest

      - name: Init TFLint
        run: tflint --init

      - name: Run TFLint
        run: tflint --recursive --format compact
```

---

## その他のツール

### Terratest

Go言語によるインテグレーションテスト:

```go
// test/vpc_test.go
package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVPCCreation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../modules/vpc",
		Vars: map[string]interface{}{
			"vpc_cidr_block": "10.0.0.0/16",
			"service_name":   "test-app",
			"env":            "test",
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcID)
}
```

**実行:**

```bash
cd test
go test -v -timeout 30m
```

---

### terraform console

対話的にTerraform式を評価:

```bash
terraform console
```

**使用例:**

```hcl
# 変数の確認
> var.vpc_cidr_block
"10.0.0.0/16"

# cidrsubnet関数のテスト
> cidrsubnet("10.0.0.0/16", 8, 0)
"10.0.0.0/24"

> cidrsubnet("10.0.0.0/16", 8, 1)
"10.0.1.0/24"

# for式のテスト
> [for i in range(3) : cidrsubnet("10.0.0.0/16", 8, i)]
[
  "10.0.0.0/24",
  "10.0.1.0/24",
  "10.0.2.0/24",
]

# マップの生成
> {for i in range(3) : "subnet-${i}" => cidrsubnet("10.0.0.0/16", 8, i)}
{
  "subnet-0" = "10.0.0.0/24"
  "subnet-1" = "10.0.1.0/24"
  "subnet-2" = "10.0.2.0/24"
}

# リソース参照
> aws_vpc.main.id
"vpc-12345678"

# 終了
> exit
```

---

### checkov

セキュリティとコンプライアンスのチェック:

```bash
# インストール
pip install checkov

# 実行
checkov -d .

# 特定のファイル
checkov -f main.tf

# JSON形式で出力
checkov -d . -o json

# 特定のチェックをスキップ
checkov -d . --skip-check CKV_AWS_19
```

**出力例:**

```
Check: CKV_AWS_19: "Ensure all data stored in S3 is encrypted"
	FAILED for resource: aws_s3_bucket.example
	File: /main.tf:10-15

Check: CKV_AWS_144: "Ensure S3 bucket has versioning enabled"
	PASSED for resource: aws_s3_bucket.example
```

---

### infracost

コスト見積もり:

```bash
# インストール
brew install infracost

# 初期設定
infracost configure

# コスト見積もり
infracost breakdown --path .

# 差分表示（PR用）
infracost diff --path .
```

**出力例:**

```
Project: myapp-dev

 Name                              Monthly Qty  Unit         Monthly Cost

 aws_instance.example
 ├─ Instance usage (Linux/UNIX)            730  hours              $7.30
 └─ EBS volume (gp3, 30 GB)                 30  GB                 $2.40

 aws_lb.main
 ├─ Application Load Balancer              730  hours             $18.40
 └─ Load Balancer Capacity Units            10  LCU-hours          $0.80

 OVERALL TOTAL                                                    $28.90
```

---

### terraform-compliance

BDD（振る舞い駆動開発）スタイルのコンプライアンステスト:

```bash
# インストール
pip install terraform-compliance

# 実行
terraform-compliance -f compliance/ -p plan.out
```

**テスト例:**

```gherkin
# compliance/security.feature
Feature: Security Compliance

  Scenario: S3 buckets must be encrypted
    Given I have aws_s3_bucket defined
    Then it must have server_side_encryption_configuration

  Scenario: EC2 instances must not have public IPs
    Given I have aws_instance defined
    Then it must not have associate_public_ip_address
    Or associate_public_ip_address must be false
```

---

## まとめ

このガイドでは以下をカバーしました:

1. **terraform test**: 組み込みテストフレームワーク
2. **LocalStack**: ローカルでのAWSエミュレーション
3. **terraform-docs**: ドキュメント自動生成
4. **tflint**: 静的解析とコードレビュー
5. **その他のツール**:
   - Terratest: Goによるインテグレーションテスト
   - terraform console: 対話的な式評価
   - checkov: セキュリティチェック
   - infracost: コスト見積もり
   - terraform-compliance: コンプライアンステスト

これらのツールを組み合わせることで、高品質なTerraformコードを維持できます。

**推奨ワークフロー:**

1. **開発時**: terraform console、LocalStack
2. **コミット前**: terraform fmt、tflint
3. **PR作成時**: terraform-docs（自動更新）、infracost diff
4. **マージ前**: terraform test、checkov、terraform-compliance
5. **デプロイ前**: terraform plan（レビュー）

詳細な実装は[SKILL.md](../SKILL.md)、[COMMANDS.md](./COMMANDS.md)、[MODULES.md](./MODULES.md)、[AWS-PRACTICE.md](./AWS-PRACTICE.md)を参照してください。
