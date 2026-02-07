# Terraformコマンドリファレンス

Terraformの主要コマンドとオプションの包括的なリファレンス。

## 📋 目次

1. [主要コマンド](#主要コマンド)
2. [ステート管理コマンド](#ステート管理コマンド)
3. [ワークスペースコマンド](#ワークスペースコマンド)
4. [importブロックの活用](#importブロックの活用)
5. [バージョン管理](#バージョン管理)
6. [その他の便利なコマンド](#その他の便利なコマンド)

---

## 主要コマンド

### terraform init

Terraformの初期化（最初に実行）:

```bash
# 基本
terraform init

# バックエンド設定を再構成
terraform init -reconfigure

# バックエンド設定を移行
terraform init -migrate-state

# プラグインのアップグレード
terraform init -upgrade

# 特定のプロバイダーのみアップグレード
terraform init -upgrade=true -plugin-dir=./plugins
```

**実行内容:**
- プロバイダープラグインのダウンロード
- バックエンドの初期化
- モジュールのダウンロード
- `.terraform`ディレクトリの作成

**よくあるエラーと対処:**

```bash
# プロバイダーのバージョン競合
Error: Failed to query available provider packages

# 対処: ロックファイルを削除して再初期化
rm .terraform.lock.hcl
terraform init -upgrade
```

---

### terraform fmt

コードの自動フォーマット:

```bash
# カレントディレクトリ
terraform fmt

# サブディレクトリも含める
terraform fmt -recursive

# 変更したファイルを表示
terraform fmt -diff

# 書き込まず、チェックのみ（CI用）
terraform fmt -check
```

**CI/CDでの活用:**

```yaml
# GitHub Actions例
- name: Terraform Format Check
  run: terraform fmt -check -recursive
```

---

### terraform validate

構文の検証:

```bash
# 基本
terraform validate

# JSON形式で出力
terraform validate -json
```

**validationとfmtの違い:**
- **fmt**: インデント、スペースの整形
- **validate**: 構文エラー、型エラーの検出

---

### terraform plan

実行計画の確認:

```bash
# 基本
terraform plan

# 実行計画をファイルに保存
terraform plan -out=plan-result

# 特定のリソースのみ計画
terraform plan -target=aws_instance.example

# 変数ファイルを指定
terraform plan -var-file=dev.tfvars

# 変数を直接指定
terraform plan -var="env=dev"

# 破棄計画
terraform plan -destroy

# リフレッシュをスキップ
terraform plan -refresh=false
```

**出力の読み方:**

```
Terraform will perform the following actions:

  # aws_instance.example will be created
  + resource "aws_instance" "example" {
      + ami           = "ami-12345678"
      + instance_type = "t3.micro"
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

**記号の意味:**
- `+`: 作成
- `-`: 削除
- `~`: 変更
- `-/+`: 再作成（削除してから作成）
- `<=`: 読み取り

---

### terraform apply

実行計画の適用:

```bash
# 基本（確認プロンプト表示）
terraform apply

# 保存した実行計画を適用
terraform plan -out=plan-result
terraform apply plan-result

# 自動承認（CI/CD用）
terraform apply -auto-approve

# 特定のリソースのみ適用
terraform apply -target=aws_instance.example

# 並列実行数を制限
terraform apply -parallelism=5

# 変数ファイルを指定
terraform apply -var-file=dev.tfvars
```

**plan + apply の推奨パターン（CI/CD）:**

```bash
# 1. 実行計画を保存
terraform plan -out=plan-result

# 2. 計画をレビュー
terraform show plan-result

# 3. 承認後に適用（確認プロンプトなし）
terraform apply plan-result
```

**重要: `-auto-approve`の使用は慎重に**
- 本番環境では使用禁止を推奨
- CI/CDでは`plan -out`パターンを使用

---

### terraform destroy

リソースの削除:

```bash
# 基本（確認プロンプト表示）
terraform destroy

# 自動承認
terraform destroy -auto-approve

# 特定のリソースのみ削除
terraform destroy -target=aws_instance.example

# 変数ファイルを指定
terraform destroy -var-file=dev.tfvars
```

**安全な削除手順:**

```bash
# 1. 削除対象を確認
terraform plan -destroy

# 2. 削除実行
terraform destroy
```

---

### terraform import

既存リソースをステートに取り込み:

```bash
# 基本構文
terraform import <RESOURCE_TYPE>.<NAME> <ID>

# 例: EC2インスタンス
terraform import aws_instance.example i-1234567890abcdef0

# 例: VPC
terraform import aws_vpc.main vpc-12345678

# 例: S3バケット
terraform import aws_s3_bucket.example my-bucket-name

# モジュール内のリソース
terraform import module.vpc.aws_vpc.main vpc-12345678
```

**手順:**

1. リソース定義を作成（空でもよい）:

```hcl
resource "aws_instance" "example" {
  # 最低限の必須パラメータを後で追加
}
```

2. importコマンド実行:

```bash
terraform import aws_instance.example i-1234567890abcdef0
```

3. ステートから設定を確認:

```bash
terraform state show aws_instance.example
```

4. リソース定義を完成:

```hcl
resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  # ... その他の設定
}
```

5. 差分がないことを確認:

```bash
terraform plan
# "No changes" になることを確認
```

---

## ステート管理コマンド

### terraform state list

ステート内のリソース一覧:

```bash
# 全リソースを表示
terraform state list

# フィルタリング
terraform state list aws_instance
terraform state list module.vpc
```

---

### terraform state show

リソースの詳細表示:

```bash
# 特定のリソース
terraform state show aws_instance.example

# 出力例
# aws_instance.example:
resource "aws_instance" "example" {
    ami           = "ami-12345678"
    instance_type = "t3.micro"
    # ...
}
```

---

### terraform state mv

リソースの移動（リネーム、モジュール間移動）:

```bash
# リソース名変更
terraform state mv aws_instance.old_name aws_instance.new_name

# モジュール間移動
terraform state mv aws_instance.example module.ec2.aws_instance.example

# モジュール名変更
terraform state mv module.old_module module.new_module
```

**movedブロックとの比較:**

| 方法 | タイミング | 履歴 |
|------|----------|------|
| `terraform state mv` | 即座に実行 | コードに残らない |
| `moved`ブロック | 次回apply時 | コードとして残る（推奨） |

**movedブロック例:**

```hcl
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}
```

---

### terraform state rm

ステートから削除（実リソースは保持）:

```bash
# リソースをステートから削除
terraform state rm aws_instance.example

# 複数削除
terraform state rm aws_instance.example aws_instance.another
```

**removedブロックとの比較:**

| 方法 | 実リソース | 用途 |
|------|----------|------|
| `terraform state rm` | 保持 | 緊急時の手動操作 |
| `removed`ブロック | 保持/削除を選択 | コードとして管理（推奨） |

**removedブロック例:**

```hcl
removed {
  from = aws_instance.example

  lifecycle {
    destroy = false  # 実リソースは削除しない
  }
}
```

---

### terraform state pull / push

ステートの取得・送信:

```bash
# リモートステートを取得
terraform state pull > terraform.tfstate

# ローカルステートをリモートに送信
terraform state push terraform.tfstate
```

**警告:**
- `state push`は危険な操作
- バックアップを必ず取る
- チームでの調整が必要

---

### terraform state replace-provider

プロバイダーの変更（組織名変更、フォーク等）:

```bash
# 基本構文
terraform state replace-provider <OLD_PROVIDER> <NEW_PROVIDER>

# 例: プロバイダーのソース変更
terraform state replace-provider \
  registry.terraform.io/hashicorp/aws \
  registry.terraform.io/my-org/aws
```

---

## ワークスペースコマンド

### terraform workspace

環境分離の管理:

```bash
# 新しいワークスペースを作成
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# ワークスペース一覧
terraform workspace list
# 出力:
#   default
# * dev
#   staging
#   prod

# ワークスペース切り替え
terraform workspace select dev

# 現在のワークスペースを表示
terraform workspace show

# ワークスペース削除
terraform workspace delete dev
```

**ワークスペースの活用例:**

```hcl
locals {
  env_config = {
    dev = {
      instance_type = "t3.micro"
      instance_count = 1
    }
    prod = {
      instance_type = "t3.large"
      instance_count = 3
    }
  }

  config = local.env_config[terraform.workspace]
}

resource "aws_instance" "example" {
  count         = local.config.instance_count
  instance_type = local.config.instance_type
  # ...
}
```

---

## importブロックの活用

### importブロックとは（Terraform 1.5+）

既存リソースをコードとして管理:

```hcl
import {
  to = aws_instance.example
  id = "i-1234567890abcdef0"
}

resource "aws_instance" "example" {
  # importブロックで取り込んだリソースの定義
}
```

---

### -generate-config-out による自動HCL生成

最も効率的なimport方法:

```bash
# 1. importブロックだけ記述
cat <<EOF > import.tf
import {
  to = aws_instance.example
  id = "i-1234567890abcdef0"
}
EOF

# 2. HCL自動生成
terraform plan -generate-config-out=generated.tf

# 3. generated.tfの内容を確認・調整
cat generated.tf

# 4. 本来の場所に移動
mv generated.tf main.tf

# 5. import実行
terraform apply
```

**生成されるHCL例:**

```hcl
# generated.tf
resource "aws_instance" "example" {
  ami                         = "ami-12345678"
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  availability_zone           = "ap-northeast-1a"
  # ... 全ての属性が自動生成される
}
```

---

### 実践パターン: EventBridge Scheduler

複雑なリソースのimport例:

```hcl
# 1. importブロック
import {
  to = aws_scheduler_schedule.example
  id = "default/my-schedule"
}

# 2. HCL生成
terraform plan -generate-config-out=scheduler.tf

# 3. 生成されたコード
resource "aws_scheduler_schedule" "example" {
  name       = "my-schedule"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(1 hour)"

  target {
    arn      = "arn:aws:lambda:ap-northeast-1:123456789012:function:my-function"
    role_arn = "arn:aws:iam::123456789012:role/EventBridgeSchedulerRole"
  }
}
```

---

### 複数リソースの一括import

```bash
# 1. 複数のimportブロック
cat <<EOF > imports.tf
import {
  to = aws_vpc.main
  id = "vpc-12345678"
}

import {
  to = aws_subnet.public_a
  id = "subnet-12345678"
}

import {
  to = aws_subnet.public_b
  id = "subnet-87654321"
}
EOF

# 2. 一括でHCL生成
terraform plan -generate-config-out=generated-network.tf

# 3. 適用
terraform apply
```

---

### importの制約事項

**importできないもの:**
- `terraform_remote_state`: データソースは管理対象外
- 一部のメタリソース

**importが難しいリソース:**
- 複雑なネストした構造（手動調整が必要）
- IDが複合キーのリソース（`group_name/schedule_name`形式等）

---

## バージョン管理

### required_version

Terraformバージョンの制約:

```hcl
terraform {
  required_version = ">= 1.5.0"
}
```

**演算子:**
- `=`: 完全一致
- `!=`: 不一致
- `>`, `>=`, `<`, `<=`: 比較
- `~>`: 悲観的バージョン制約（マイナーバージョン固定）

**悲観的バージョン制約の例:**

```hcl
terraform {
  # 1.5.x の最新を許可（1.6.0は不可）
  required_version = "~> 1.5.0"
}
```

---

### required_providers

プロバイダーバージョンの制約:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}
```

---

### プロバイダーのアップグレード

```bash
# ロックファイルの確認
cat .terraform.lock.hcl

# プロバイダーのアップグレード
terraform init -upgrade

# 特定のプロバイダーのみアップグレード
terraform providers lock \
  -platform=darwin_arm64 \
  -platform=linux_amd64
```

---

## その他の便利なコマンド

### terraform output

出力値の表示:

```bash
# 全ての出力
terraform output

# 特定の出力
terraform output vpc_id

# JSON形式
terraform output -json

# Raw形式（シェルスクリプトで使用）
VPC_ID=$(terraform output -raw vpc_id)
```

---

### terraform console

対話的な式の評価:

```bash
terraform console
```

**使用例:**

```hcl
> var.vpc_cidr_block
"10.0.0.0/16"

> cidrsubnet(var.vpc_cidr_block, 8, 0)
"10.0.0.0/24"

> [for i in range(3) : "subnet-${i}"]
[
  "subnet-0",
  "subnet-1",
  "subnet-2",
]

> exit
```

---

### terraform graph

依存関係のグラフ生成:

```bash
# DOT形式で出力
terraform graph > graph.dot

# Graphvizで画像化
dot -Tpng graph.dot -o graph.png
```

---

### terraform providers

使用中のプロバイダー表示:

```bash
# プロバイダー一覧
terraform providers

# プロバイダースキーマ（JSON）
terraform providers schema -json
```

---

### terraform show

ステートまたは実行計画の表示:

```bash
# ステート全体を表示
terraform show

# 実行計画を表示
terraform show plan-result

# JSON形式
terraform show -json
```

---

### terraform refresh

ステートの更新（実リソースとの同期）:

```bash
terraform refresh
```

**注意:**
- Terraform 0.15.4以降は`terraform apply -refresh-only`を推奨
- `refresh`単独での使用は非推奨

```bash
# 推奨方法
terraform apply -refresh-only
```

---

### terraform taint / untaint（非推奨）

**Terraform 0.15.2以降は非推奨、代わりに以下を使用:**

```bash
# 再作成を強制（taintの代替）
terraform apply -replace=aws_instance.example

# 計画段階で確認
terraform plan -replace=aws_instance.example
```

---

## コマンドの組み合わせパターン

### 安全な適用フロー

```bash
# 1. フォーマット
terraform fmt -recursive

# 2. 構文検証
terraform validate

# 3. 実行計画
terraform plan -out=plan-result

# 4. 計画の確認
terraform show plan-result

# 5. 適用
terraform apply plan-result
```

---

### CI/CDパイプライン例

```yaml
# GitHub Actions
name: Terraform

on:
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -out=plan-result

      - name: Comment Plan
        uses: actions/github-script@v6
        with:
          script: |
            const output = require('fs').readFileSync('plan-result', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `\`\`\`\n${output}\n\`\`\``
            })
```

---

## トラブルシューティング

### よくあるエラーと対処

**1. ステートロックエラー**

```bash
Error: Error acquiring the state lock
```

**対処:**

```bash
# ロック状態の確認（DynamoDB）
aws dynamodb scan --table-name terraform-state-lock

# 手動でロック解除（最終手段）
terraform force-unlock <LOCK_ID>
```

**2. プロバイダーのバージョン競合**

```bash
Error: Failed to query available provider packages
```

**対処:**

```bash
rm .terraform.lock.hcl
terraform init -upgrade
```

**3. ステートとコードの不整合**

```bash
Error: Resource not found
```

**対処:**

```bash
# ステートからリソースを削除
terraform state rm aws_instance.example

# または、importで再取り込み
terraform import aws_instance.example i-1234567890abcdef0
```

---

## まとめ

このリファレンスでは以下をカバーしました:

1. **主要コマンド**: init, fmt, validate, plan, apply, destroy, import
2. **ステート管理**: list, show, mv, rm, pull, push, replace-provider
3. **ワークスペース**: new, list, select, delete
4. **importブロック**: `-generate-config-out`による効率的なimport
5. **バージョン管理**: required_version, required_providers, `~>`演算子
6. **その他**: output, console, graph, show, refresh

次は[MODULES.md](./MODULES.md)でモジュール設計を学んでください。
