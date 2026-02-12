# Terraform 高度なパターンと実践

本ドキュメントでは、命名規則、ネットワーク管理、Provisioner、External Provider、Local Provider、バリデーション、Terraformが適切でないケース、代替インターフェース（CDKTF、JSON設定）など、Terraformの高度なトピックを解説する。

---

## 目次

1. [命名とドメイン](#命名とドメイン)
2. [ネットワーク管理](#ネットワーク管理)
3. [Provisioner](#provisioner)
4. [External Provider](#external-provider)
5. [Local Provider](#local-provider)
6. [ChecksとConditions](#checksとconditions)
7. [Terraformが適切でない場合](#terraformが適切でない場合)
8. [代替インターフェース](#代替インターフェース)

---

## 命名とドメイン

### 命名規則の考慮事項

適切な命名規則は、リソース検索・メタデータ理解・運用効率を向上させる。良い命名規則の条件：

- **一意性（Unique）**: 技術的制約・人為ミス防止
- **可読性（Human Readable）**: 開発者が理解しやすい
- **識別可能性（Identifiable）**: 名前からリソース種別・用途が分かる
- **ソート可能性（Sortable）**: 名前でソートした際に関連リソースがグループ化される

**例**:

- ✅ `prod-api-lb`, `dev-backend-db` （一意・可読・識別可能・ソート可能）
- ❌ `abd236a`, `6d8a900` （一意だが可読性・識別性なし）
- ❌ `large-finch`, `current-walrus` （可読だが識別性なし）

### 階層的命名スキーム

Terraformリソース自体がモジュールパスで階層構造を持つ：

```
module.service.aws_ecs_cluster.main
module.lb.module.logs.aws_s3_bucket.main
```

この構造をリソース名にも適用する。

**トップレベルモジュール**:

```hcl
variable "environment" {
  description = "環境名（dev/staging/prod）"
  type        = string
}

locals {
  application = "acme"
  base_name   = "${local.application}-${var.environment}"
}

module "api" {
  source = "./service"
  name   = "${local.base_name}-api"
}

module "database" {
  source = "./db"
  name   = "${local.base_name}-db"
}
```

**サービスモジュール**:

```hcl
variable "name" {
  description = "サービス名（プレフィックス）"
  type        = string
}

module "load_balancer" {
  source = "./alb"
  name   = "${var.name}-lb"
}

module "log_bucket" {
  source = "./bucket"
  name   = "${var.name}-logs"
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name}-cluster"
}

resource "aws_ecs_service" "main" {
  name            = "${var.name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = file("${path.module}/task_definition.json")
  desired_count   = 1
}
```

**結果**:

```
acme-dev-api-lb-cluster
acme-dev-api-lb-service
acme-dev-api-logs
acme-dev-db-instance
```

### リソース固有の命名制約

一部リソースは削除後に同名再作成ができない（例: AWS Secrets Manager は7日間待機必要）。

**対策**: モジュール内部でランダム文字列を付与。

```hcl
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_secretsmanager_secret" "main" {
  name = "${var.name}-${random_string.suffix.result}"
}
```

**注意**: S3バケットもS3 namespace squatting 対策でランダム性推奨。

### ドメイン

ドメインも階層的命名スキームを適用。トップレベルドメインをユーザーから受け取り、アプリケーション名・環境を追加。

```hcl
variable "environment" {
  description = "環境名"
  type        = string
}

variable "domain" {
  description = "ベースドメイン"
  type        = string
}

variable "dns_zone" {
  description = "Route 53ゾーンID"
  type        = string
}

locals {
  application = "acme"
  base_domain = "${var.environment}.${local.application}.${var.domain}"
}

module "api" {
  source = "./service"
  name   = "${local.application}-${var.environment}-api"
  domain = "api.${local.base_domain}"
}
```

**結果**: `api.dev.acme.example.net`

**TIP**: 公開用は `.com`、内部用は `.net` でセグメント化。

---

## ネットワーク管理

### CIDR とサブネット計算

Classless Inter-Domain Routing (CIDR) はネットワークをサブネットに分割する標準。

**CIDR表記**: `192.168.0.0/16`

- `/16`: 先頭16ビットがネットワークID
- 残り16ビット: ホストまたはサブネット用

**サブネット分割**:

元ネットワーク: `192.168.0.0/16` (65,534アドレス)

2ビット追加（4サブネット）:

- `192.168.0.0/18` (16,382アドレス)
- `192.168.64.0/18`
- `192.168.128.0/18`
- `192.168.192.0/18`

**Terraform関数**:

```hcl
cidrsubnet("192.168.0.0/16", 2, 0)  # => "192.168.0.0/18"
cidrsubnet("192.168.0.0/16", 2, 1)  # => "192.168.64.0/18"
cidrsubnet("192.168.0.0/16", 2, 2)  # => "192.168.128.0/18"
cidrsubnet("192.168.0.0/16", 2, 3)  # => "192.168.192.0/18"

cidrnetmask("192.168.0.0/18")       # => "255.255.192.0"
```

### 一般的なネットワークトポロジ

**設計考慮事項**:

1. **サービスのセグメント化**: セキュリティ向上（侵害時の横展開防止）
2. **高可用性**: 複数ロケーション（AZ/Region）に分散
3. **ネットワークサイズ**: 成長余地を確保しつつIP浪費を避ける

**2セグメントネットワーク**:

- **Public Subnet**: インターネットからアクセス可能（ロードバランサー）
- **Private Subnet**: 内部のみアクセス可能（API、DB、キャッシュ）
- Private → Internet: NAT Gateway経由

**3セグメントネットワーク**:

- Public Subnet
- Private Subnet
- **Isolated Subnet**: インターネット接続なし、明示的ブリッジのみ（機密データ用）

**高可用性**:

各ロケーション（AZ）ごとに同じトポロジを複製（通常3ロケーション）。

### Locationモジュール（2セグメント例）

```hcl
variable "cidr_block" {
  description = "ネットワークのCIDRブロック"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone"
  type        = string
}

locals {
  private_subnet_cidr_block = cidrsubnet(var.cidr_block, 1, 0)
  public_subnet_cidr_block  = cidrsubnet(var.cidr_block, 1, 1)
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = var.vpc_id
  cidr_block              = local.public_subnet_cidr_block
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone
  tags = {
    Network = "Public"
  }
}

resource "aws_eip" "nat" {
  tags = {}
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags          = {}
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = var.vpc_id
  cidr_block        = local.private_subnet_cidr_block
  availability_zone = var.availability_zone
  tags = {
    Network = "Private"
  }
}

resource "aws_route_table" "private" {
  vpc_id = var.vpc_id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route" "private_internet" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}
```

### 高レベルモジュール

トップレベルモジュールでVPC作成し、各AZ用にLocationモジュールを呼び出す。

```hcl
variable "cidr_block" {
  description = "VPCのCIDRブロック"
  type        = string
}

variable "availability_zones" {
  description = "使用するAZリスト"
  type        = list(string)
}

resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

module "location" {
  source = "./location"
  count  = length(var.availability_zones)

  cidr_block        = cidrsubnet(var.cidr_block, 2, count.index)
  vpc_id            = aws_vpc.main.id
  availability_zone = var.availability_zones[count.index]
}
```

---

## Provisioner

Provisioner は Terraform の管理外操作を実行する仕組みだが、**最終手段**として使用すべき。

### 接続設定

```hcl
resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx"
    ]
  }
}
```

### Commandプロビジョナー

**local-exec**: ローカルマシンでコマンド実行

```hcl
resource "null_resource" "example" {
  provisioner "local-exec" {
    command = "echo ${aws_instance.example.public_ip} > ip_address.txt"
  }
}
```

**remote-exec**: リモートマシンでコマンド実行

```hcl
provisioner "remote-exec" {
  inline = [
    "curl -O https://example.com/script.sh",
    "chmod +x script.sh",
    "./script.sh"
  ]
}
```

### Fileプロビジョナー

```hcl
provisioner "file" {
  source      = "local/path/config.txt"
  destination = "/etc/myapp/config.txt"
}
```

### terraform_data リソース

`null_resource` の代替。

```hcl
resource "terraform_data" "example" {
  input = aws_instance.example.id

  provisioner "local-exec" {
    command = "echo Instance ${self.output} created"
  }
}
```

### Provisioner の代替手段

| ユースケース | 推奨代替手段 |
|-------------|-------------|
| ソフトウェアインストール | Packer（マシンイメージ作成） |
| 構成管理 | Ansible、Chef、Puppet |
| コンテナ起動 | Docker、Kubernetes |
| スクリプト実行 | AWS Systems Manager、cloud-init |

---

## External Provider

外部プログラムをデータソースとして呼び出し、JSON出力を取得。

### 外部データソース

```hcl
data "external" "example" {
  program = ["python3", "${path.module}/script.py"]

  query = {
    key1 = "value1"
    key2 = "value2"
  }
}

output "result" {
  value = data.external.example.result
}
```

**script.py**:

```python
#!/usr/bin/env python3
import json
import sys

input_data = json.load(sys.stdin)
output_data = {
    "result_key": input_data["key1"] + "_processed"
}
print(json.dumps(output_data))
```

### ラッパープログラム言語

- **Python**: 広く使われ、JSON処理が簡単
- **Bash**: シンプルなスクリプト向け
- **Go**: パフォーマンス重視

### 代替手段

- **カスタムProvider開発**: 複雑なロジックはProviderとして実装
- **既存Provider活用**: HTTP Provider、Cloud APIなど

---

## Local Provider

ローカル環境での操作に特化。

### 関数的データソース

```hcl
data "local_file" "example" {
  filename = "${path.module}/data.txt"
}

output "content" {
  value = data.local_file.example.content
}
```

### リソース

**local_file**: ローカルファイル作成

```hcl
resource "local_file" "example" {
  content  = "Hello, Terraform!"
  filename = "${path.module}/output.txt"
}
```

**local_sensitive_file**: センシティブなファイル作成

```hcl
resource "local_sensitive_file" "secret" {
  content  = var.secret_value
  filename = "${path.module}/secret.txt"
}
```

---

## Checks と Conditions

### Precondition と Postcondition

**Precondition**: リソース作成前にバリデーション

```hcl
variable "instance_type" {
  type = string
}

resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = var.instance_type

  lifecycle {
    precondition {
      condition     = contains(["t3.micro", "t3.small"], var.instance_type)
      error_message = "Instance type must be t3.micro or t3.small"
    }
  }
}
```

**Postcondition**: リソース作成後に検証

```hcl
resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"

  lifecycle {
    postcondition {
      condition     = self.public_ip != ""
      error_message = "Instance must have a public IP address"
    }
  }
}
```

### Check ブロック

継続的なバリデーション（plan時に警告、apply時にエラーとしない）。

```hcl
check "health_check" {
  data "http" "example" {
    url = "https://${aws_instance.example.public_ip}/health"
  }

  assert {
    condition     = data.http.example.status_code == 200
    error_message = "Health check failed"
  }
}
```

---

## Terraform が適切でない場合

### Kubernetes

**問題**: Kubernetes APIは頻繁に変更され、宣言的管理はHelm/Kustomizeが適している。

**推奨**: Terraformでクラスター作成、Helm/Kustomizeでアプリケーション管理。

### コンテナイメージビルド

**問題**: Dockerイメージビルドは`docker build`が最適。

**推奨**: CI/CDパイプラインでビルド、TerraformはECR/レジストリ管理のみ。

### マシンイメージビルド

**問題**: AMI/VMイメージはPackerが専用ツール。

**推奨**: PackerでAMI作成、TerraformはAMI IDを参照。

### アーティファクト管理

**問題**: バイナリ・ライブラリはMaven/npm/PyPIなど専用ツールが最適。

**推奨**: TerraformはS3バケット作成のみ、アップロードは専用ツール。

---

## 代替インターフェース

### Terraformラッピング

Terraform CLIをプログラムから呼び出し、JSON出力を解析。

**Go例**:

```go
package main

import (
    "encoding/json"
    "os/exec"
)

type TerraformOutput struct {
    Value     interface{} `json:"value"`
    Sensitive bool        `json:"sensitive"`
}

func GetOutputs() (map[string]TerraformOutput, error) {
    cmd := exec.Command("terraform", "output", "-json")
    output, err := cmd.Output()
    if err != nil {
        return nil, err
    }

    var result map[string]TerraformOutput
    err = json.Unmarshal(output, &result)
    return result, err
}
```

### JSON設定

TerraformはJSON形式での設定もサポート（`.tf.json`）。

**HCL**:

```hcl
resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
}
```

**JSON**:

```json
{
  "resource": {
    "aws_instance": {
      "example": {
        "ami": "ami-12345678",
        "instance_type": "t3.micro"
      }
    }
  }
}
```

**式とキーワード**: JSON内では文字列として記述。

```json
{
  "resource": {
    "aws_instance": {
      "example": {
        "ami": "${var.ami_id}",
        "instance_type": "${var.instance_type}"
      }
    }
  }
}
```

**コメント**: JSONはコメント非対応（代替: `//` フィールド）。

```json
{
  "//": "This is a pseudo-comment",
  "resource": {
    "aws_instance": {
      "example": {
        "ami": "ami-12345678"
      }
    }
  }
}
```

### Cloud Development Kit for Terraform (CDKTF)

プログラミング言語（TypeScript、Python、Go、Java、C#）でTerraform設定を生成。

**使うべきか？**

| ユースケース | 推奨 |
|-------------|------|
| 複雑な条件分岐 | ✅ |
| 大規模な繰り返し | ✅ |
| 既存コードベースと統合 | ✅ |
| シンプルなインフラ | ❌ HCL推奨 |
| Terraform初学者 | ❌ HCL推奨 |

**CDKTF セットアップ**:

```bash
npm install -g cdktf-cli
cdktf init --template typescript --local
```

**TypeScript例**:

```typescript
import { Construct } from "constructs";
import { App, TerraformStack } from "cdktf";
import { AwsProvider } from "@cdktf/provider-aws/lib/provider";
import { Instance } from "@cdktf/provider-aws/lib/instance";

class MyStack extends TerraformStack {
  constructor(scope: Construct, id: string) {
    super(scope, id);

    new AwsProvider(this, "aws", {
      region: "us-east-1",
    });

    new Instance(this, "example", {
      ami: "ami-12345678",
      instanceType: "t3.micro",
    });
  }
}

const app = new App();
new MyStack(app, "my-stack");
app.synth();
```

**実行**:

```bash
cdktf deploy
```

---

## まとめ

- **命名規則**: 階層的スキームで一意性・可読性・識別性・ソート可能性を確保
- **ネットワーク**: CIDR関数で柔軟なサブネット分割、トポロジ標準化
- **Provisioner**: 最終手段。代替手段（Packer、Ansible、cloud-init）を優先
- **External Provider**: 外部プログラム統合、カスタムProvider検討
- **Local Provider**: ローカルファイル操作
- **Checks/Conditions**: Precondition/Postcondition/Checkでバリデーション強化
- **適切でないケース**: Kubernetes、イメージビルド、アーティファクト管理は専用ツール推奨
- **代替インターフェース**: JSON設定、CDKTF（複雑なケース向け）
