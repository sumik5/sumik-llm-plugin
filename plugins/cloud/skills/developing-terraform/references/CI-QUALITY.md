# Terraform CI・品質管理

継続的インテグレーション（CI）実践と品質管理ツールを活用し、高品質なTerraformコードを維持する。

---

## 目次

1. [CI実践の基礎](#ci実践の基礎)
2. [ローカル開発環境](#ローカル開発環境)
3. [品質維持ツール](#品質維持ツール)
4. [セキュリティ検証](#セキュリティ検証)
5. [カスタムポリシー強制](#カスタムポリシー強制)
6. [自動化（Chores）](#自動化chores)
7. [CIシステムとの統合](#ciシステムとの統合)

---

## CI実践の基礎

### CIとは

継続的インテグレーション（CI）は、チームが定期的にメインラインにコードをマージできるようにするソフトウェア開発実践。高パフォーマンスチームは1日に複数回の統合を実施する。

**CIの目的:**
- メインブランチを常に動作可能な状態に保つ
- 早期にバグを検出
- コードレビューの負荷を軽減
- デプロイメントの安全性向上

### SCM（ソースコード管理）

- **推奨**: GitHub、GitLab
- **機能**: コード管理、Issue管理、セキュリティスキャン、Action/Pipeline実行
- TerraformはSCMの存在を前提に設計されている（モジュールレジストリ等）

### ブランチとPull Request

**ブランチ戦略:**
- メインブランチ（main/master）を基準とする
- 開発は個別ブランチで行う
- Pull Request（PR）でメインブランチにマージ

**PRワークフロー:**
1. ブランチ作成
2. ローカル開発・テスト
3. PR作成
4. 自動テスト実行
5. コードレビュー
6. マージ

### コードレビュー観点

**レビューすべき項目:**
- **セキュリティ**: インフラの誤設定、認証情報漏洩
- **ベストプラクティス**: 命名規則、チーム内スタイルの一貫性
- **ドキュメント**: コメント、変数説明の完備

**自動化できるものはレビューしない:**
- フォーマット → `terraform fmt`
- 構文チェック → `terraform validate`
- セキュリティスキャン → Checkov/Trivy

> **重要**: 自動化できるチェックは自動化し、人間は本質的な判断に集中する。

---

## ローカル開発環境

### ソフトウェアテンプレート（Boilerplate）

**目的:**
- 新規プロジェクトの迅速な立ち上げ
- 品質管理ツールの設定を標準化
- チーム間の一貫性確保

**ツール: Cookiecutter**
- Python製のテンプレート生成ツール
- 動的な設定ファイル生成が可能
- プロバイダに応じた設定を自動生成

```bash
# Cookiecutterでプロジェクト作成
cookiecutter gh:組織名/terraform-module-template

# 質問に回答
[1/6] name: terraform-aws-example
[2/6] Select license: 2 - MIT license
[3/6] author: Your Name
[4/6] primary_provider: hashicorp/aws
[5/6] provider_min_version: 5.0
[6/6] private_registry_url:
```

**生成されるファイル例:**
```
.github/workflows/     # CI設定
.gitignore
.tflint.hcl           # TFlint設定
.terraform-docs.yml   # ドキュメント自動生成設定
.checkov.yml          # Checkov設定
makefile              # 共通コマンド
main.tf
variables.tf
outputs.tf
providers.tf
```

### Makefileによるコマンド標準化

**目的:**
- 複雑なコマンドを簡潔に
- 開発者がツールの詳細を覚える必要をなくす
- CI/CDと同じコマンドをローカルで実行

**基本構造:**

```makefile
# Terraformバイナリ切り替え（OpenTofu/Terraform）
TF_BINARY ?= tofu

# terraform init（バックエンド無効化）
.terraform:
	$(TF_BINARY) init -backend=false

# 検証
.PHONY: test_validation
test_validation: .terraform
	$(TF_BINARY) validate

# 全テスト実行
.PHONY: test
test: test_validation test_tflint test_checkov test_trivy
```

**使用例:**

```bash
make test_validation
make test
```

### バージョン管理

**推奨設定:**

```hcl
# providers.tf
terraform {
  required_version = ">= 1.6.0"  # 最小バージョン指定

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # マイナーバージョン自動更新
    }
  }
}
```

**Semantic Versioning制約:**
- `~> 1.1` → 1.1.x〜1.x.x（マイナー・パッチ更新可）
- `~> 1.1.0` → 1.1.x（パッチのみ更新可）
- `>= 1.1.0, < 2.0.0` → 1.x.x（メジャーバージョンアップ禁止）

---

## 品質維持ツール

### terraform validate

**用途:** 基本的な構文チェック、命名エラー検出

```bash
# バックエンド無しで初期化
terraform init -backend=false

# 検証実行
terraform validate
```

**検出するエラー:**
- HCL構文エラー
- リソース/変数名の誤り
- 関数名の誤り

**makefile統合:**

```makefile
.terraform:
	$(TF_BINARY) init -backend=false

.PHONY: test_validation
test_validation: .terraform
	$(TF_BINARY) validate
```

### TFlint

**用途:** 静的解析によるコード品質・ベストプラクティス強制

#### 基本設定 (`.tflint.hcl`)

```hcl
# Terraformプラグイン（汎用ルール）
plugin "terraform" {
  enabled = true
  preset  = "recommended"  # または "all"
}

# AWSプラグイン
plugin "aws" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# GCPプラグイン
plugin "google" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

# Azureプラグイン
plugin "azurerm" {
  enabled = true
  version = "0.25.1"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
```

#### カスタムルール設定

```hcl
plugin "terraform" {
  enabled = true
  preset  = "all"
}

# 特定ルールを無効化
rule "terraform_comment_syntax" {
  enabled = false
}

# 特定ルールを有効化
rule "terraform_comment_syntax" {
  enabled = true
}
```

#### インライン例外

```hcl
resource "aws_instance" "beta" {
  ami = "ami-867166b8518f055af"

  # tflint-ignore: aws_instance_invalid_type
  instance_type = "p8.48xlarge"  # ベータアクセス
}
```

#### makefile統合

```makefile
.PHONY: test_tflint
test_tflint:
	tflint --init
	tflint

.PHONY: tflint_fix
tflint_fix:
	tflint --init
	tflint --fix
```

**使用例:**

```bash
make test_tflint
make tflint_fix  # 自動修正（レビュー推奨）
```

---

## セキュリティ検証

### Checkov

**特徴:**
- オープンソース
- ローカル完結（中央サービス不要）
- Terraform/CloudFormation/Helm対応
- カスタムポリシー対応

#### 基本使用

```makefile
.PHONY: test_checkov
test_checkov:
	checkov --directory .
```

#### 例外設定

```hcl
resource "aws_instance" "public" {
  ami           = "ami-867166b8518f055af"
  instance_type = "t3.large"

  # checkov:skip=CKV_AWS_88:This instance is meant to be publicly accessible.
  associate_public_ip_address = true
}
```

### Trivy（旧TFSec）

**特徴:**
- オープンソース
- 広範なプロバイダ対応
- Checkovと補完的に使用推奨

#### 基本使用

```makefile
.PHONY: test_trivy
test_trivy:
	trivy config .
```

#### 例外設定（`.trivyignore`）

```text
# パブリックIPアドレスの使用を許可
AVD-AWS-0009
```

#### インライン例外

```hcl
resource "aws_instance" "public" {
  ami           = "ami-867166b8518f055af"
  instance_type = "t3.large"

  # Trivy: Ignore Public IP address rule.
  # trivy:ignore:AVD-AWS-0009
  associate_public_ip_address = true
}
```

### 統合makefile

```makefile
.PHONY: security
security: test_checkov test_trivy
```

### 商用ツール

- **Snyk**: Software Bill of Materials対応
- **Checkmarx**: エンタープライズ向け
- **Mend**: 高度な脆弱性検出

> **推奨**: Checkov/Trivyで基本的なセキュリティ要件は満たせる。商用ツールは組織がすでにライセンスを持っている場合に検討。

---

## カスタムポリシー強制

### Open Policy Agent (OPA) with TFlint

**用途:** Rego言語でカスタムポリシーを定義

**設定:**

```hcl
# .tflint.hcl
plugin "opa" {
  enabled = true
  version = "0.6.0"
  source  = "github.com/terraform-linters/tflint-ruleset-opa"
}
```

**ポリシー例** (`.tflint.d/policies/s3_bucket_name.rego`):

```rego
package tflint

import rego.v1

deny_invalid_s3_bucket_name contains issue if {
    buckets := terraform.resources("aws_s3_bucket", {"bucket": "string"}, {})
    name := buckets[_].config.bucket
    not startswith(name.value, "example-com-")

    issue := tflint.issue(`Bucket names should always start with "example-com-"`, name.range)
}
```

### Sentinel Policy-as-Code（TFC/TFE専用）

**用途:** Terraform Cloud/Enterprise組み込みのポリシーエンジン。プラン・apply前に組織ポリシーを自動評価する。

#### 基本構文

```sentinel
# enforce_tags.sentinel
import "tfplan/v2" as tfplan

# すべてのリソース変更に "Environment" タグが存在することを要求
tag_rule = rule {
  all tfplan.resource_changes as resource {
    resource.change.after.tags is not null and
    "Environment" in resource.change.after.tags.keys()
  }
}

main = rule {
  tag_rule
}
```

#### インスタンスタイプ制限ポリシー例

```sentinel
# restrict_instance_types.sentinel
import "tfplan/v2" as tfplan

allowed_types = ["t3.micro", "t3.small", "t3.medium"]

main = rule {
  all tfplan.resource_changes as r {
    r.type is not "aws_instance" or
    r.change.after.instance_type in allowed_types
  }
}
```

#### Sentinel主要インポート

| インポート | 用途 |
|----------|------|
| `tfplan/v2` | planで予定される変更を評価 |
| `tfconfig/v2` | HCL設定値を評価 |
| `tfstate/v2` | 現在のstateを評価 |

#### 実施モード

| モード | 動作 |
|-------|------|
| Advisory | 違反を警告するが実行を継続 |
| Soft-Mandatory | 実行をブロック（管理者が手動オーバーライド可） |
| Hard-Mandatory | 実行をブロック（オーバーライド不可） |

#### ローカルテスト

```bash
# Sentinel CLIでポリシーをテスト
sentinel test enforce_tags.sentinel
sentinel test -verbose enforce_tags.sentinel

# モックデータを使ったデバッグ
sentinel mock tfplan=mock-tfplan.json enforce_tags.sentinel
```

#### OPAとの使い分け

| 観点 | Sentinel | OPA (Rego) |
|-----|---------|-----------|
| ライセンス | 有料（TFC/TFE必須） | OSS |
| 対応環境 | Terraform Cloud/Enterprise のみ | CI/CD全般に統合可能 |
| 学習コスト | 中（専用言語） | 高（Rego言語） |
| 推奨場面 | TFC/TFE利用組織 | OSS Terraform + 既存OPA環境 |

> **選択指針**: TFC/TFEを使用している場合はSentinelを第一選択とする。OSS Terraform環境ではCheckov YAMLカスタムルールまたはOPA/TFlintを使用する。

---

### Checkov カスタムルール（YAML）

**利点:**
- YAMLで定義可能（Rego/Go不要）
- 学習コストが低い
- Gitリポジトリから直接読み込み可能

**ポリシー例** (`.checkov/policies/aws_instance_family.yaml`):

```yaml
---
metadata:
  name: "Disable the P and G families of AWS Instances."
  id: "CKV2_CUSTOM_AWS_1"
  category: "COST_SAVINGS"
definition:
  and:
    - cond_type: "attribute"
      resource_types:
        - "aws_instance"
      attribute: "instance_type"
      operator: "not_regex_match"
      value: '^p\d\..*$'
    - cond_type: "attribute"
      resource_types:
        - "aws_instance"
      attribute: "instance_type"
      operator: "not_regex_match"
      value: '^g\d\..*$'
```

**リモートポリシー読み込み:**

```makefile
CHECKOV_OPTIONS := --external-checks-git https://github.com/YOUR_ORG/custom_policies.git

.PHONY: test_checkov
test_checkov:
	checkov --directory . $(CHECKOV_OPTIONS)
```

---

## 自動化（Chores）

### terraform-docs

**用途:** 変数・出力の自動ドキュメント生成

#### 設定 (`.terraform-docs.yml`)

```yaml
formatter: "markdown table"

output:
  file: "README.md"
  mode: inject

sort:
  enabled: true
  by: required  # required変数を優先表示
```

#### README.mdテンプレート

```markdown
# My Module

モジュールの説明

## Usage

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
```

#### makefile統合

```makefile
.PHONY: documentation
documentation:
	terraform-docs -c .terraform-docs.yml .

.PHONY: test_documentation
test_documentation:
	terraform-docs -c .terraform-docs.yml --output-check .
```

### terraform fmt

**用途:** コードフォーマット標準化

```makefile
.PHONY: format
format:
	$(TF_BINARY) fmt -recursive .

.PHONY: test_format
test_format:
	$(TF_BINARY) fmt -check -recursive .
```

### choresターゲット

```makefile
.PHONY: chores
chores: documentation format
```

**使用:**

```bash
make chores  # ドキュメント生成 + フォーマット
```

---

## CIシステムとの統合

### CI選定基準

**優先順位:**
1. **SCM統合CI**: GitHub Actions、GitLab Pipelines
2. **既存CI**: 組織で使用中のCI（Jenkins、CircleCI等）
3. **セルフホスト**: 大規模組織のみ検討

### GitHub Actions基本構造

**ワークフローファイル** (`.github/workflows/lint.yml`):

```yaml
name: Lint

on:
  push:
  pull_request:

jobs:
  tflint:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout source code
        uses: actions/checkout@v4

      - name: Setup TFLint
        uses: terraform-linters/setup-tflint@v4

      - name: Run TFLint
        run: make test_tflint
```

### 複数バージョンテスト（Matrix Strategy）

```yaml
name: Validation

on:
  push:
    branches:
      - main
  pull_request:

jobs:
  validation:
    strategy:
      fail-fast: false
      matrix:
        tf_engine:
          - terraform
          - tofu
        tf_version:
          - "1.6"
          - "1.7"
          - "1.8"

    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        if: matrix.tf_engine == 'terraform'
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ matrix.tf_version }}

      - name: Setup OpenTofu
        if: matrix.tf_engine == 'tofu'
        uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: ${{ matrix.tf_version }}

      - name: Run Validation
        run: make test_validation TF_BINARY=${{ matrix.tf_engine }}
```

### ブランチ保護

**GitHub設定:**
1. Settings → Branches
2. Branch protection rules → Add rule
3. Required status checks:
   - `lint`
   - `validation`
   - `security`

**効果:**
- テスト失敗時はマージ禁止
- PRレビューに自動テスト結果が表示

### Dependabot統合

**設定** (`.github/dependabot.yml`):

```yaml
version: 2
updates:
  - package-ecosystem: "terraform"
    directory: "/"
    schedule:
      interval: "weekly"
```

---

## チームワークフロー

### ロール定義

チームでTerraformを運用する際の責任分担:

| ロール | 主な責任 | 権限 |
|-------|---------|------|
| Developer | tfファイルの作成・更新 | 設定編集、plan実行 |
| Reviewer | PRレビュー・承認 | plan確認、マージ承認 |
| Operator | applyの実行、インフラ管理 | apply実行、workspace管理 |
| Admin | バックエンド管理、アクセス制御、ポリシー管理 | 全権限、state操作 |

**RBAC設計の原則:**
- DeveloperはapplyできないCI経由でのみapply可能）
- 本番環境のapplyはOperator/AdminのみCIまたは手動承認フロー経由）
- stateの直接操作はAdmin限定

### PRベースTerraformワークフロー

```
feature branch
  ↓ push
PR作成
  ↓ CI自動実行
  ├── terraform fmt -check
  ├── terraform validate
  ├── tflint
  ├── checkov / trivy
  └── terraform plan（結果をPRにコメント）
  ↓ Reviewerによるコードレビュー + plan確認
  ↓ 承認後マージ
main branch
  ↓ CI自動実行
  └── terraform apply（または手動承認フロー）
```

**GitHub Actionsでのplan結果コメント例:**

```yaml
- name: Terraform Plan
  id: plan
  run: terraform plan -no-color 2>&1 | tee plan.txt

- name: Comment Plan on PR
  uses: actions/github-script@v7
  with:
    script: |
      const plan = require('fs').readFileSync('plan.txt', 'utf8');
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `\`\`\`\n${plan}\n\`\`\``
      });
```

### pre-commit hooks設定

コミット前に自動チェックを実行することでCIへの負荷を軽減する。

**インストール:**

```bash
pip install pre-commit
pre-commit install
```

**設定ファイル** (`.pre-commit-config.yaml`):

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.0  # 最新バージョンを確認して指定
    hooks:
      - id: terraform_fmt          # フォーマット自動修正
      - id: terraform_validate     # 構文検証
      - id: terraform_tflint       # 静的解析
      - id: terraform_docs         # ドキュメント自動更新
      - id: checkov                # セキュリティチェック
```

**主要hook ID一覧:**

| hook ID | 用途 |
|---------|------|
| `terraform_fmt` | `terraform fmt`自動実行 |
| `terraform_validate` | `terraform validate`実行 |
| `terraform_tflint` | TFlint静的解析 |
| `terraform_docs` | terraform-docsでREADME更新 |
| `checkov` | Checkovセキュリティスキャン |
| `terraform_trivy` | Trivyセキュリティスキャン |

**全ファイルに対して手動実行:**

```bash
pre-commit run --all-files
```

> **重要**: pre-commit hooksは開発者の手元で早期検知するためのもの。CIでの同等チェックは省略せず二重に実行する。

---

## 判断基準テーブル

### ツール選択

| 用途 | 推奨ツール | 代替 |
|-----|----------|-----|
| 構文検証 | terraform validate | - |
| 静的解析 | TFlint | - |
| セキュリティスキャン | Checkov + Trivy | Snyk/Checkmarx（商用） |
| カスタムポリシー | Checkov YAML | OPA/Rego（複雑な場合） |
| ドキュメント生成 | terraform-docs | - |
| フォーマット | terraform fmt | - |

### CI戦略

| 規模 | 推奨CI | 理由 |
|-----|--------|------|
| 小規模チーム | GitHub Actions | SCM統合、簡単、無料枠 |
| 中規模チーム | GitLab CI | セルフホスト可、SCM統合 |
| 大規模組織 | 既存CI | 統一管理、セキュリティ要件 |

---

## ベストプラクティス

1. **テンプレート化**: Cookiecutterで標準プロジェクト構造を維持
2. **Makefile活用**: チーム間で共通コマンドを使用
3. **セキュリティ多層防御**: Checkov + Trivy の両方を実行
4. **自動化優先**: レビュアーの負荷を減らすため自動化できるものは全て自動化
5. **CIとローカルの一致**: makeターゲットをCI/ローカルで共通化
6. **継続的改善**: CIワークフローもテンプレートに含める

---

## トラブルシューティング

### TFlint plugin not found

```bash
tflint --init  # プラグインを再インストール
```

### Checkov false positive

```hcl
# 正当な理由がある場合のみ例外設定
# checkov:skip=CKV_AWS_XX:理由を記載
```

### GitHub Actions timeout

```yaml
jobs:
  test:
    timeout-minutes: 30  # デフォルト360分から短縮
```
