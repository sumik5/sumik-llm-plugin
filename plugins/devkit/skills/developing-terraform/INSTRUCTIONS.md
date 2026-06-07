# Terraform IaC開発ガイド

## 概要

TerraformはHCL（HashiCorp Configuration Language）による宣言的IaCツール。マルチクラウド対応、ステート管理、モジュール化により、再利用可能なインフラを実現します。

**主な特徴:**
- **マルチクラウド対応**: AWS、GCP、Azure等
- **宣言的記述**: あるべき状態を定義、差分は自動計算
- **ステート管理**: 現在のインフラ状態を追跡
- **モジュール化**: 再利用可能なコンポーネント

**ライセンス注記 (v1.5.5以降):** 2023年8月、TerraformのライセンスがMPL 2.0からBusiness Source License (BSL 1.1)に変更された。競合サービス事業者による商用利用は制限されるため、該当する環境ではOSSフォークの[OpenTofu](https://opentofu.org/)の採用を検討すること。

---

## ツール選択（AskUserQuestion）

新規プロジェクト構築時、以下をAskUserQuestionで確認:

### Terraform vs Terragrunt

| 選択肢 | 説明 |
|--------|------|
| **素のTerraform（推奨: 小規模）** | 単一環境、モジュール数5未満 |
| **Terragrunt（推奨: 中〜大規模）** | 複数環境、モジュール間依存、DRY原則 |

Terragrunt選択時の追加確認:
- **mise使用有無**: タスクランナーとしてmiseを使うか
- **クラウドプロバイダ**: AWS / GCP / Azure / マルチクラウド

→ Terragrunt詳細: [TERRAGRUNT.md](./references/TERRAGRUNT.md)
→ ディレクトリ構成・mise: [TERRAGRUNT-STRUCTURE.md](./references/TERRAGRUNT-STRUCTURE.md)

---

## IaC化の判断基準

| 判断軸 | 閾値 | 理由 |
|--------|------|------|
| **繰り返し回数** | 3回以上 | 手作業の効率悪化・ミス増加 |
| **更新頻度** | 週1回以上 | 変更履歴の管理が重要 |
| **環境数** | 2環境以上 | dev/staging/prod等の複製 |
| **チーム規模** | 2名以上 | 属人化リスク |
| **リソース数** | 10個以上 | 手動管理の限界 |

**IaC化しない方が良い場合:** 一度限り、検証目的、プロバイダー非対応

---

## IaCツール比較

### 手続き型 vs 宣言型

| 分類 | 説明 | ツール例 |
|------|------|---------|
| **手続き型** | 手順を記述 | スクリプト、Ansible（一部） |
| **宣言型** | 状態を記述 | Terraform, CloudFormation, Pulumi |

**宣言型の利点:** 冪等性、差分管理自動、状態可視化

### 適用範囲

| カテゴリ | ツール例 |
|---------|---------|
| **プロビジョニング** | Terraform, Pulumi, CloudFormation, Bicep |
| **構成管理** | Ansible, Chef, Puppet |
| **コンテナ** | Docker, Cloud Native Buildpacks, Packer |

**使い分け:**
- **Terraform**: マルチクラウド、モジュール再利用
- **CloudFormation/Bicep**: 単一クラウド特化
- **Ansible**: OSレイヤー構成管理
- **Pulumi**: プログラミング言語で記述

---

## Terraform vs Terragrunt

| 観点 | 素のTerraform | Terragrunt |
|------|-------------|------------|
| **設定の共通化** | モジュール + 変数ファイル | root.hcl による一元管理 |
| **環境分離** | workspace / ディレクトリ / tfvars | _env/ + include による自動注入 |
| **依存管理** | data.terraform_remote_state | dependency ブロック + mock_outputs |
| **一括実行** | 手動で順次実行 | `run --all` で依存順に自動実行 |
| **Provider/Backend生成** | 各モジュールに手動配置 | generate ブロックで自動生成 |
| **学習コスト** | 低 | 中（Terraform + Terragrunt両方） |

**選択基準:**
- **素のTerraform**: モジュール5未満、単一環境、シンプル構成
- **Terragrunt**: モジュール5以上、複数環境、DRY重視、チーム開発

---

## HCL基本文法

### 主要ブロック

詳細は[COMMANDS.md](./references/COMMANDS.md)参照。

```hcl
# provider
provider "aws" {
  region = "ap-northeast-1"
}

# resource
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "main-vpc" }
}

# data（既存リソース参照）
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
}

# variable
variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

# local
locals {
  common_tags = {
    Environment = var.env
  }
}

# module
module "vpc" {
  source = "./modules/vpc"
  vpc_cidr_block = var.vpc_cidr_block
}

# output
output "vpc_id" {
  value = aws_vpc.main.id
}
```

### 繰り返し・条件

```hcl
# count
resource "aws_subnet" "example" {
  count = 3
  cidr_block = "10.0.${count.index}.0/24"
}

# for_each
resource "aws_subnet" "example" {
  for_each = toset(["public-a", "public-b"])
  cidr_block = "10.0.0.0/24"
}

# for式
locals {
  uppercase_names = [for name in var.names : upper(name)]
}

# 条件分岐
resource "aws_instance" "example" {
  instance_type = var.env == "prod" ? "t3.large" : "t3.micro"
}
```

---

## 変数制御

### 型システム

```hcl
variable "vpc_cidr_block" { type = string }
variable "subnet_count" { type = number }
variable "enable_dns" { type = bool }
variable "azs" { type = list(string) }
variable "tags" { type = map(string) }
variable "config" {
  type = object({
    cidr_block = string
    az         = string
  })
}
```

### validation（検証）

```hcl
variable "vpc_cidr_block" {
  type = string
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr_block))
    error_message = "CIDR形式で入力してください"
  }
}

variable "env" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "envはdev, staging, prodのいずれか"
  }
}
```

### よく使う関数

```hcl
locals {
  # 文字列結合
  resource_name = "${var.service_name}-${var.env}-vpc"

  # リスト操作
  first_az = element(data.aws_availability_zones.available.names, 0)

  # マップ結合
  all_tags = merge(var.common_tags, { Name = local.resource_name })

  # CIDR計算
  subnet_cidr = cidrsubnet(var.vpc_cidr_block, 8, 0)
}
```

---

## 繰り返し構文の選択基準

### count vs for_each 判断テーブル（重要）

| 観点 | count | for_each |
|------|-------|----------|
| **キーの型** | 数値インデックス（0, 1, 2...） | マップキーまたはset要素（名前付き） |
| **要素削除時** | インデックスずれで意図しない再作成 | 該当キーのみ削除、他に影響なし |
| **推奨用途** | bool的な条件分岐（0 or 1） | 名前付きリソースの動的生成 |

### 実践例

```hcl
# ❌ count（非推奨）
variable "services" { default = ["web", "api", "db"] }
resource "aws_instance" "example" {
  count = length(var.services)
  tags = { Name = var.services[count.index] }
}
# "api"削除 → services[1]="db"が繰り上がり再作成

# ✅ for_each（推奨）
resource "aws_instance" "example" {
  for_each = toset(var.services)
  tags = { Name = each.key }
}
# "api"削除 → example["api"]のみ削除、他は変更なし
```

**選択基準:**
- **count**: リソースの有無を条件分岐（`count = var.enabled ? 1 : 0`）
- **for_each**: 名前付きリソースの動的生成（推奨）

---

## メンテナンスしやすいコード

### dynamicブロック

```hcl
resource "aws_security_group" "example" {
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

**注意:** 3つ以上の繰り返しで使用。単純な繰り返しは明示的記述が分かりやすい。

### リソース移動・削除

```hcl
# movedブロック（リソース名変更）
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}

# importブロック（既存リソース取り込み）
import {
  to = aws_instance.example
  id = "i-1234567890abcdef0"
}

# removedブロック（ステートから削除、実リソース保持）
removed {
  from = aws_instance.example
  lifecycle { destroy = false }
}
```

詳細は[COMMANDS.md](./references/COMMANDS.md)参照。

---

## ステート管理の基本

### ステートとは

`terraform.tfstate`で現在のインフラ状態を管理。実リソースとコードの対応付け、差分計算の基準。

### バックエンド設定（推奨）

```hcl
# S3 バックエンド（AWS）
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# GCS バックエンド（GCP）
terraform {
  backend "gcs" {
    bucket = "my-terraform-state"
    prefix = "prod/terraform.tfstate"
  }
}
```

**主要バックエンド:**
- **S3 + DynamoDB**: AWS標準（ロック機能付き）
- **GCS**: Google Cloud（ロック機能内蔵）
- **Azure Blob Storage**: Azure
- **Terraform Cloud**: HashiCorp公式SaaS

### ステート操作

```bash
# 一覧
terraform state list

# 詳細表示
terraform state show aws_instance.example

# リソース移動
terraform state mv aws_instance.old_name aws_instance.new_name

# ステートから削除（実リソース保持）
terraform state rm aws_instance.example
```

詳細は[COMMANDS.md](./references/COMMANDS.md)参照。

---

## ワークスペース

同一コードで複数環境（ステート）を管理:

```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

terraform workspace list
terraform workspace select dev
```

### terraform.workspaceの活用

```hcl
locals {
  resource_name = "${var.service_name}-${terraform.workspace}-vpc"
}

resource "aws_vpc" "main" {
  tags = {
    Name        = local.resource_name
    Environment = terraform.workspace
  }
}
```

### 環境分離パターン

| パターン | メリット | デメリット |
|---------|---------|----------|
| **ワークスペース** | 同一コード、切り替え簡単 | 誤操作リスク |
| **ディレクトリ分離** | 完全分離 | コード重複 |
| **tfvarsファイル** | 変数のみ分離 | 実行時にファイル指定必要 |
| **Terragrunt** | DRY、依存自動解決 | 追加ツール学習コスト |

**推奨:** 小規模=ワークスペース、中規模=ディレクトリ分離+モジュール共有、大規模=Terragrunt + mise

---

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測せず必ずAskUserQuestionツールで確認する。**

### 確認すべき場面

1. **ツール選択**: 素のTerraform / Terragrunt
2. **mise使用有無**: タスクランナー利用
3. **Terragrunt構成パターン**: 番号付きプレフィックス / フラット構成
4. **プロバイダー選択**: AWS / GCP / Azure / マルチクラウド
5. **ステート管理方式**: S3 / GCS / Azure Blob / Terraform Cloud
6. **モジュール分割粒度**: 機能単位 / レイヤー単位 / サービス単位
7. **環境分離方式**: ワークスペース / ディレクトリ分離 / tfvarsファイル
8. **ECS起動タイプ**: Fargate / EC2
9. **CI/CDツール**: GitHub Actions / GitLab CI / CircleCI
10. **既存リソース取り込み**: importブロック / terraform import コマンド
11. **ネットワーク構成**: パブリックのみ / パブリック+プライベート
12. **命名規則**: `${service_name}-${env}-${resource}` / その他

### 確認不要（常に実行）

1. `terraform fmt` / `terraform validate` - 常に実行
2. ステートのバックエンド設定 - ローカルは非推奨
3. `terraform plan -out` - CI/CDでは必須
4. `for_each` vs `count` - 名前付きリソースは`for_each`一択
5. 変数のvalidation - 常に推奨
6. タグ付与 - Name, Environment最低限必須

---

## サブファイルリンク

詳細情報は以下参照:

- **[COMMANDS.md](./references/COMMANDS.md)** - Terraformコマンドの包括的リファレンス
- **[MODULES.md](./references/MODULES.md)** - モジュール設計パターンと実践例
- **[AWS-PRACTICE.md](./references/AWS-PRACTICE.md)** - AWS環境での実践的な構築ガイド
- **[GCP-PRACTICE.md](./references/GCP-PRACTICE.md)** - GCP環境での実践的な構築ガイド
- **[TERRAGRUNT.md](./references/TERRAGRUNT.md)** - Terragruntコア概念、root.hcl/terragrunt.hclテンプレート、パターン集
- **[TERRAGRUNT-STRUCTURE.md](./references/TERRAGRUNT-STRUCTURE.md)** - ディレクトリ構成テンプレート、miseタスク定義、依存関係設計
- **[TESTING.md](./references/TESTING.md)** - テスト、ツール、ドキュメンテーション
- **[PLAN-AND-GRAPH.md](./references/PLAN-AND-GRAPH.md)** - Plan/Applyの内部動作、DAG、リソースグラフ、落とし穴
- **[STATE-IN-DEPTH.md](./references/STATE-IN-DEPTH.md)** - ステート内部構造、バックエンド移行、ドリフト対策、プロジェクト間連携
- **[CI-QUALITY.md](./references/CI-QUALITY.md)** - CI実践、品質維持ツール、セキュリティ検証、GitHub Actions
- **[CD-DEPLOYMENT.md](./references/CD-DEPLOYMENT.md)** - モジュール配信、GitOps、プロジェクト構造、CDプラットフォーム
- **[TESTING-IN-DEPTH.md](./references/TESTING-IN-DEPTH.md)** - テスト理論、Terratest、Testing Framework、リファクタリング
- **[ADVANCED-PATTERNS.md](./references/ADVANCED-PATTERNS.md)** - 命名・ドメイン、ネットワーク、Provisioner、CDKTF
- **[PROVIDER-DEVELOPMENT.md](./references/PROVIDER-DEVELOPMENT.md)** - カスタムProvider開発（Plugin Framework）

---

## まとめ

1. **IaC化判断**: 繰り返し回数、更新頻度、環境数で判断
2. **ツール選択**: プロビジョニング、構成管理、コンテナの役割分担
3. **Terraform vs Terragrunt**: 規模・環境数・DRY要求に応じて選択
4. **HCL構文**: resource, variable, module等の基本ブロック
5. **変数制御**: 型システムとvalidationによる厳格な制御
6. **繰り返し構文**: `for_each`優先、`count`は条件分岐のみ
7. **メンテナンス**: moved/import/removedブロック活用
8. **ステート管理**: リモートバックエンド（S3/GCS）+ ロック機能
9. **ワークスペース**: 環境分離の選択肢と使い分け
10. **ユーザー確認**: 判断分岐では必ずAskUserQuestion

次のステップ: [COMMANDS.md](./references/COMMANDS.md)でコマンド詳細を学び、[MODULES.md](./references/MODULES.md)でモジュール設計を実践し、[AWS-PRACTICE.md](./references/AWS-PRACTICE.md)または[GCP-PRACTICE.md](./references/GCP-PRACTICE.md)で実際のインフラを構築してください。大規模プロジェクトでは[TERRAGRUNT.md](./references/TERRAGRUNT.md)と[TERRAGRUNT-STRUCTURE.md](./references/TERRAGRUNT-STRUCTURE.md)でTerragruntパターンを検討してください。
