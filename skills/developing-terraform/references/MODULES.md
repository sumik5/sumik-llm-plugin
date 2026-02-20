# Terraformモジュール設計パターン

モジュールの設計原則と実践的な構築例。

## 📋 目次

1. [モジュールの基本概念](#モジュールの基本概念)
2. [ディレクトリ構成パターン](#ディレクトリ構成パターン)
3. [VPCモジュール設計](#vpcモジュール設計)
4. [サブネットモジュール設計](#サブネットモジュール設計)
5. [ゲートウェイ・ルートテーブル](#ゲートウェイルートテーブル)
6. [モジュール設計の判断基準](#モジュール設計の判断基準)
7. [セキュリティグループのモジュール化](#セキュリティグループのモジュール化)
8. [モジュールのベストプラクティス](#モジュールのベストプラクティス)

---

## モジュールの基本概念

### ルートモジュールとチャイルドモジュール

**ルートモジュール:**
- 実行するディレクトリのコード
- `terraform apply`を実行する場所

**チャイルドモジュール:**
- 再利用可能なコンポーネント
- `module`ブロックで呼び出す

```hcl
# ルートモジュール（main.tf）
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr_block = "10.0.0.0/16"
  service_name   = "myapp"
  env            = "dev"
}

# チャイルドモジュール（modules/vpc/vpc.tf）
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  # ...
}
```

---

### source指定

モジュールの参照方法:

#### 1. ローカルパス

```hcl
module "vpc" {
  source = "./modules/vpc"
}
```

#### 2. Terraform Registry

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
}
```

#### 3. GitHub

```hcl
module "vpc" {
  source = "github.com/myorg/terraform-modules//vpc?ref=v1.0.0"
}
```

#### 4. Git（SSH）

```hcl
module "vpc" {
  source = "git::ssh://git@github.com/myorg/terraform-modules.git//vpc?ref=v1.0.0"
}
```

#### 5. HTTP（S）

```hcl
module "vpc" {
  source = "https://example.com/terraform-modules/vpc.zip"
}
```

---

### outputによるモジュール間連携

チャイルドモジュールの出力を参照:

```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPCのID"
}

output "vpc_cidr_block" {
  value       = aws_vpc.main.cidr_block
  description = "VPCのCIDRブロック"
}

# ルートモジュール
module "vpc" {
  source = "./modules/vpc"
  # ...
}

module "subnet" {
  source = "./modules/subnet"

  vpc_id         = module.vpc.vpc_id
  vpc_cidr_block = module.vpc.vpc_cidr_block
}
```

---

## ディレクトリ構成パターン

### 基本パターン

```
.
├── main.tf              # ルートモジュールのメイン
├── variables.tf         # ルートモジュールの変数
├── outputs.tf           # ルートモジュールの出力
├── terraform.tfvars     # 変数値（デフォルト）
├── backend.tf           # バックエンド設定
├── modules/             # チャイルドモジュール
│   ├── vpc/
│   │   ├── variables.tf
│   │   ├── vpc.tf
│   │   └── outputs.tf
│   ├── subnet/
│   │   ├── variables.tf
│   │   ├── subnet.tf
│   │   └── outputs.tf
│   └── security-group/
│       ├── variables.tf
│       ├── security-group.tf
│       └── outputs.tf
└── env/                 # 環境別変数
    ├── dev.tfvars
    ├── staging.tfvars
    └── prod.tfvars
```

---

### 環境分離パターン

#### パターンA: ワークスペース

```
.
├── main.tf
├── variables.tf
├── outputs.tf
└── modules/
    └── ...
```

```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

terraform workspace select dev
terraform apply
```

#### パターンB: ディレクトリ分離

```
.
├── modules/             # 共有モジュール
│   ├── vpc/
│   └── subnet/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── backend.tf
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── backend.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       └── backend.tf
```

---

## VPCモジュール設計

### ディレクトリ構成

```
modules/vpc/
├── variables.tf
├── vpc.tf
└── outputs.tf
```

---

### variables.tf

変数の定義とvalidation:

```hcl
variable "vpc_cidr_block" {
  type        = string
  description = "VPCのCIDRブロック"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr_block))
    error_message = "CIDR形式で入力してください（例: 10.0.0.0/16）"
  }
}

variable "service_name" {
  type        = string
  description = "サービス名（リソース名のプレフィックス）"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.service_name))
    error_message = "小文字英数字とハイフンのみ使用可能です"
  }
}

variable "env" {
  type        = string
  description = "環境名（dev/staging/prod）"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "envはdev, staging, prodのいずれかを指定してください"
  }
}

variable "vpc_additional_tags" {
  type        = map(string)
  description = "VPCに追加するタグ"
  default     = {}

  validation {
    condition = alltrue([
      for key in keys(var.vpc_additional_tags) :
      !contains(["Name", "Service", "Environment"], key)
    ])
    error_message = "Name, Service, Environmentは予約キーです"
  }
}

variable "enable_dns_support" {
  type        = bool
  description = "DNS解決を有効化"
  default     = true
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "DNSホスト名を有効化"
  default     = true
}
```

**validationのポイント:**
- CIDR形式の検証（正規表現）
- 環境名の制約（列挙型）
- 予約キーの検証（Name等の上書き防止）

---

### vpc.tf

VPCリソースの定義:

```hcl
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block

  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(
    {
      Name        = "${var.service_name}-${var.env}-vpc"
      Service     = var.service_name
      Environment = var.env
    },
    var.vpc_additional_tags
  )
}
```

**merge関数の活用:**
- 標準タグ（Name, Service, Environment）を自動設定
- 追加タグを`vpc_additional_tags`で柔軟に追加
- 予約キーの上書きを防止（validationで保証）

---

### outputs.tf

出力値の定義:

```hcl
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPCのID"
}

output "vpc_name" {
  value       = aws_vpc.main.tags["Name"]
  description = "VPCの名前"
}

output "vpc_cidr_block" {
  value       = aws_vpc.main.cidr_block
  description = "VPCのCIDRブロック"
}

output "vpc_arn" {
  value       = aws_vpc.main.arn
  description = "VPCのARN"
}
```

---

### 使用例

```hcl
# main.tf
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr_block = "10.0.0.0/16"
  service_name   = "myapp"
  env            = "dev"

  vpc_additional_tags = {
    Owner = "platform-team"
    Cost  = "shared"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
```

---

## サブネットモジュール設計

### 複合型変数の活用

パブリック・プライベートサブネットを一つのモジュールで管理:

```hcl
# variables.tf
variable "vpc_id" {
  type        = string
  description = "VPCのID"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPCのCIDRブロック"
}

variable "service_name" {
  type        = string
  description = "サービス名"
}

variable "env" {
  type        = string
  description = "環境名"
}

variable "availability_zones" {
  type        = list(string)
  description = "使用するAZのリスト"
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "subnet_config" {
  type = object({
    public = object({
      cidrs = list(string)
      names = list(string)
    })
    private = object({
      cidrs = list(string)
      names = list(string)
    })
  })
  description = "サブネット設定（パブリック・プライベート）"

  validation {
    condition = (
      length(var.subnet_config.public.cidrs) == length(var.subnet_config.public.names) &&
      length(var.subnet_config.private.cidrs) == length(var.subnet_config.private.names)
    )
    error_message = "cidrsとnamesの要素数が一致している必要があります"
  }
}
```

---

### for_each + tosetパターン

サブネットの動的生成:

```hcl
# subnet.tf
locals {
  public_subnets = {
    for idx, name in var.subnet_config.public.names :
    name => {
      cidr_block        = var.subnet_config.public.cidrs[idx]
      availability_zone = var.availability_zones[idx % length(var.availability_zones)]
    }
  }

  private_subnets = {
    for idx, name in var.subnet_config.private.names :
    name => {
      cidr_block        = var.subnet_config.private.cidrs[idx]
      availability_zone = var.availability_zones[idx % length(var.availability_zones)]
    }
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = var.vpc_id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.service_name}-${var.env}-${each.key}"
    Service     = var.service_name
    Environment = var.env
    Type        = "public"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = var.vpc_id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    Name        = "${var.service_name}-${var.env}-${each.key}"
    Service     = var.service_name
    Environment = var.env
    Type        = "private"
  }
}
```

**ポイント:**
- `idx % length(var.availability_zones)`: AZ数でループして均等分散
- `map_public_ip_on_launch`: パブリックサブネットのみ有効化

---

### cidrsubnet関数による自動計算

CIDR手動指定の代わりに自動計算:

```hcl
variable "subnet_newbits" {
  type        = number
  description = "サブネットのプレフィックス長の追加ビット数"
  default     = 8  # /16 → /24
}

locals {
  public_subnet_cidrs = [
    for idx in range(length(var.subnet_config.public.names)) :
    cidrsubnet(var.vpc_cidr_block, var.subnet_newbits, idx)
  ]

  private_subnet_cidrs = [
    for idx in range(length(var.subnet_config.private.names)) :
    cidrsubnet(var.vpc_cidr_block, var.subnet_newbits, idx + length(var.subnet_config.public.names))
  ]
}
```

**例:**
- VPC: `10.0.0.0/16`
- `subnet_newbits = 8`
- `cidrsubnet("10.0.0.0/16", 8, 0)` → `10.0.0.0/24`
- `cidrsubnet("10.0.0.0/16", 8, 1)` → `10.0.1.0/24`

---

### outputs.tf

```hcl
output "public_subnet_ids" {
  value       = [for subnet in aws_subnet.public : subnet.id]
  description = "パブリックサブネットのIDリスト"
}

output "private_subnet_ids" {
  value       = [for subnet in aws_subnet.private : subnet.id]
  description = "プライベートサブネットのIDリスト"
}

output "public_subnet_cidrs" {
  value       = [for subnet in aws_subnet.public : subnet.cidr_block]
  description = "パブリックサブネットのCIDRリスト"
}

output "private_subnet_cidrs" {
  value       = [for subnet in aws_subnet.private : subnet.cidr_block]
  description = "プライベートサブネットのCIDRリスト"
}
```

---

### 使用例

```hcl
module "subnet" {
  source = "./modules/subnet"

  vpc_id         = module.vpc.vpc_id
  vpc_cidr_block = module.vpc.vpc_cidr_block
  service_name   = "myapp"
  env            = "dev"

  subnet_config = {
    public = {
      cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
      names = ["public-a", "public-c"]
    }
    private = {
      cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
      names = ["private-a", "private-c"]
    }
  }
}
```

---

## ゲートウェイ・ルートテーブル

### Internet Gateway

```hcl
# modules/network/igw.tf
resource "aws_internet_gateway" "main" {
  vpc_id = var.vpc_id

  tags = {
    Name        = "${var.service_name}-${var.env}-igw"
    Service     = var.service_name
    Environment = var.env
  }
}
```

---

### NAT Gateway

AZごとにNAT Gatewayを配置:

```hcl
# modules/network/nat.tf
resource "aws_eip" "nat" {
  for_each = toset(var.public_subnet_ids)

  domain = "vpc"

  tags = {
    Name        = "${var.service_name}-${var.env}-nat-eip-${each.key}"
    Service     = var.service_name
    Environment = var.env
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  for_each = toset(var.public_subnet_ids)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.key

  tags = {
    Name        = "${var.service_name}-${var.env}-nat-${each.key}"
    Service     = var.service_name
    Environment = var.env
  }

  depends_on = [aws_internet_gateway.main]
}
```

**コスト最適化のパターン（単一NAT Gateway）:**

```hcl
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.service_name}-${var.env}-nat-eip"
    Service     = var.service_name
    Environment = var.env
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.public_subnet_ids[0]  # 最初のパブリックサブネット

  tags = {
    Name        = "${var.service_name}-${var.env}-nat"
    Service     = var.service_name
    Environment = var.env
  }
}
```

---

### ルートテーブル

パブリック・プライベート分離:

```hcl
# modules/network/route-table.tf

# パブリックルートテーブル
resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  tags = {
    Name        = "${var.service_name}-${var.env}-public-rt"
    Service     = var.service_name
    Environment = var.env
    Type        = "public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = toset(var.public_subnet_ids)

  subnet_id      = each.key
  route_table_id = aws_route_table.public.id
}

# プライベートルートテーブル（AZごと）
resource "aws_route_table" "private" {
  for_each = toset(var.private_subnet_ids)

  vpc_id = var.vpc_id

  tags = {
    Name        = "${var.service_name}-${var.env}-private-rt-${each.key}"
    Service     = var.service_name
    Environment = var.env
    Type        = "private"
  }
}

resource "aws_route" "private_nat" {
  for_each = toset(var.private_subnet_ids)

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.public_subnet_ids[0]].id
}

resource "aws_route_table_association" "private" {
  for_each = toset(var.private_subnet_ids)

  subnet_id      = each.key
  route_table_id = aws_route_table.private[each.key].id
}
```

---

## モジュール設計の判断基準

### モジュール分割の基準

| 判断軸 | モジュール化する | モジュール化しない |
|--------|----------------|------------------|
| **依存関係** | 独立している | 密結合している |
| **再利用性** | 複数の場所で使用 | 1箇所のみ |
| **更新頻度** | ライフサイクルが同じ | ライフサイクルが異なる |
| **ステートサイズ** | 管理可能な範囲 | 巨大になりすぎる |

---

### ライフサイクルの例

| レイヤー | 更新頻度 | モジュール例 |
|---------|---------|------------|
| **インフラ基盤** | 月1回程度 | VPC, サブネット |
| **共有サービス** | 週1回程度 | RDS, ElastiCache |
| **アプリケーション** | 日次 | ECS タスク定義 |

**分割戦略:**
- レイヤーごとにディレクトリ分離
- ステート分離で更新の影響範囲を制限

---

### ステート分割戦略

**巨大ステートの問題:**
- `terraform plan`が遅い
- 誤操作のリスクが高い
- ロック競合が発生しやすい

**分割のパターン:**

```
environments/prod/
├── 01-network/         # VPC, サブネット
│   ├── main.tf
│   └── backend.tf
├── 02-database/        # RDS, ElastiCache
│   ├── main.tf
│   └── backend.tf
└── 03-application/     # ECS, ALB
    ├── main.tf
    └── backend.tf
```

**データソースによる連携:**

```hcl
# 03-application/main.tf
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "my-terraform-state"
    key    = "prod/01-network/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

module "ecs" {
  source = "../../modules/ecs"

  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}
```

---

## セキュリティグループのモジュール化

### 基本パターン

```hcl
# modules/security-group/variables.tf
variable "vpc_id" {
  type        = string
  description = "VPCのID"
}

variable "name" {
  type        = string
  description = "セキュリティグループ名"
}

variable "ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  description = "インバウンドルール"
  default     = []
}

variable "egress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  description = "アウトバウンドルール"
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound"
    }
  ]
}
```

---

### dynamicブロックの活用

```hcl
# modules/security-group/main.tf
resource "aws_security_group" "main" {
  name   = var.name
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
      description = egress.value.description
    }
  }

  tags = {
    Name = var.name
  }
}
```

---

### 使用例

```hcl
module "alb_sg" {
  source = "./modules/security-group"

  vpc_id = module.vpc.vpc_id
  name   = "myapp-dev-alb-sg"

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP from anywhere"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS from anywhere"
    }
  ]
}

module "ecs_sg" {
  source = "./modules/security-group"

  vpc_id = module.vpc.vpc_id
  name   = "myapp-dev-ecs-sg"

  ingress_rules = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = [module.vpc.vpc_cidr_block]
      description = "App port from VPC"
    }
  ]
}
```

---

### dynamicブロックの注意点

**使うべき場合:**
- ルール数が3つ以上
- ルールが動的に変化する
- 複数の環境で異なるルールセット

**使わない方が良い場合:**
- ルール数が2つ以下
- ルールが固定的

```hcl
# シンプルな場合はdynamicを使わない方が分かりやすい
resource "aws_security_group" "example" {
  name   = "example-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
}
```

---

## モジュールのベストプラクティス

### 1. 変数のドキュメント

すべての変数に`description`を記述:

```hcl
variable "vpc_cidr_block" {
  type        = string
  description = "VPCのCIDRブロック（例: 10.0.0.0/16）"
}
```

---

### 2. 出力値のドキュメント

すべての出力に`description`を記述:

```hcl
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPCのID"
}
```

---

### 3. デフォルト値の設定

合理的なデフォルト値を提供:

```hcl
variable "enable_dns_support" {
  type        = bool
  description = "DNS解決を有効化"
  default     = true
}
```

---

### 4. validationの活用

入力値を検証:

```hcl
variable "env" {
  type        = string
  description = "環境名"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "envはdev, staging, prodのいずれかを指定してください"
  }
}
```

---

### 5. README.md の作成

モジュールごとにREADME.mdを配置:

```markdown
# VPCモジュール

## 概要

VPCを作成するモジュール。

## 使用例

\`\`\`hcl
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr_block = "10.0.0.0/16"
  service_name   = "myapp"
  env            = "dev"
}
\`\`\`

## 入力変数

| 変数名 | 型 | 説明 | デフォルト |
|--------|-----|------|----------|
| vpc_cidr_block | string | VPCのCIDRブロック | - |
| service_name | string | サービス名 | - |
| env | string | 環境名 | - |

## 出力値

| 出力名 | 型 | 説明 |
|--------|-----|------|
| vpc_id | string | VPCのID |
| vpc_cidr_block | string | VPCのCIDRブロック |
```

---

### 6. バージョニング

モジュールのバージョン管理:

```hcl
# modules/vpc/versions.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

---

### 7. 例の提供

`examples/`ディレクトリに使用例を配置:

```
modules/vpc/
├── variables.tf
├── vpc.tf
├── outputs.tf
├── versions.tf
├── README.md
└── examples/
    ├── basic/
    │   └── main.tf
    └── advanced/
        └── main.tf
```

---

---

## モジュールネスト深度とパフォーマンス

### ネスト深度がDAGに与える影響

モジュールを深くネストするほど、Terraformが生成するリソース依存グラフ（DAG）が肥大化し、plan/apply の処理時間が増大する。

**仕組み**: Terraformはモジュール境界を透過してリソース単位でDAGを構築する。モジュールが3層・4層とネストされると、依存関係の解決に必要なグラフトラバーサルのコストが指数的に増加する。

```
# 3層ネストの例（問題になりうる）
root
└── module "app" (layer 1)
    └── module "service" (layer 2)
        └── module "container" (layer 3)
            └── module "task_definition" (layer 4)  ← パフォーマンス劣化の兆候

# 推奨: 2層以内にフラット化
root
├── module "app_service"   (layer 1: serviceとcontainerを統合)
└── module "app_database"  (layer 1)
```

### 推奨最大ネスト深度

| ネスト深度 | 評価 | 備考 |
|-----------|------|------|
| 1〜2層 | 推奨 | plan/applyが高速、依存関係が明快 |
| 3層 | 許容 | 複雑なインフラでやむを得ない場合のみ |
| 4層以上 | 非推奨 | DAG肥大化・デバッグ困難・リファクタリングが必要 |

### ネストを減らすリファクタリング指針

1. **統合**: 常に一緒に使われる小さなモジュールは1つに統合する
2. **フラット化**: ネストを除去し、ルートモジュールから直接呼び出す
3. **locals活用**: 単純な計算のためだけのモジュールは `locals` ブロックに置き換える

```hcl
# 改善前: 単純な計算のためだけのモジュール（不要なネスト）
module "name_generator" {
  source      = "./modules/name-generator"
  environment = var.environment
  service     = var.service_name
}

# 改善後: localsで代替（モジュール不要）
locals {
  base_name = "${var.service_name}-${var.environment}"
}
```

---

## まとめ

このガイドでは以下をカバーしました:

1. **モジュールの基本**: ルートモジュール、チャイルドモジュール、source指定
2. **ディレクトリ構成**: 環境分離パターン
3. **VPCモジュール**: validation、merge関数、タグ管理
4. **サブネットモジュール**: for_each、cidrsubnet、AZ分散
5. **ゲートウェイ**: IGW、NAT Gateway、ルートテーブル
6. **モジュール設計**: 依存関係、ライフサイクル、ステート分割
7. **セキュリティグループ**: dynamicブロック、ingress/egress分離
8. **ベストプラクティス**: ドキュメント、validation、バージョニング
9. **ネスト深度管理**: 2層以内を推奨、DAG肥大化を防ぐリファクタリング

次は[AWS-PRACTICE.md](./AWS-PRACTICE.md)でAWS環境の実践的な構築を学んでください。
