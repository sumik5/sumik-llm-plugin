# Terraform テストとリファクタリング（詳細）

Infrastructure as Code (IaC) のテストは、自動化されたテストスイートを通じて、コードの品質向上・心理的安全性の確保・リファクタリングの促進を実現する。本ドキュメントでは、テスト理論、実践的パターン、Terratest、Terraform Testing Framework、リファクタリング手法を解説する。

---

## 目次

1. [IaCテストの理論](#iacテストの理論)
2. [IaCテスト実践](#iacテスト実践)
3. [Terratest](#terratest)
4. [Terraform Testing Framework](#terraform-testing-framework)
5. [リファクタリング](#リファクタリング)
6. [外部リファクタリング（互換性破壊管理）](#外部リファクタリング互換性破壊管理)

---

## IaCテストの理論

### 自動テストの利点

自動テストはプロジェクトのライフサイクル全体で以下を提供する：

1. **品質向上**: バグの早期発見、リグレッション防止
2. **レビュー負担軽減**: PRレビュー時に手動テストが不要
3. **後方互換性維持**: 破壊的変更の検出が容易
4. **心理的安全性**: デプロイ不安の軽減、脆弱なコードベースの緊張解消

特に心理的安全性は重要である。インシデント・障害・セキュリティ侵害はストレスを伴い、本番環境での破壊は士気を低下させる。テストスイートはチームの信頼感を高め、変更に対する不安を取り除く。

### テストすべきもの（すべきでないもの）

**テストすべき対象**:

- **データ変換**: 変数・属性を変換する独自ロジック
- **文字列生成**: データソース・属性から構築される文字列の正確性
- **正規表現**: 複数パターンでのテスト
- **Dynamic Blocks**: ゼロ個・1個・複数個のケース
- **システム機能**: HTTPエンドポイントの到達性、生成された認証情報の動作確認

**テスト不要な対象**:

- Providerが既にテストしている単純なパラメータパススルー
- 変数をリソースに渡すだけの単純リソース（独自ロジックがない場合）

**例**:

```hcl
# テスト不要（単なるパススルー）
resource "aws_route53_record" "main" {
  zone_id = var.zone_id
  name    = var.name
  records = var.records
  type    = "A"
  ttl     = "300"
}

# テストすべき（動的名前生成ロジック）
data "aws_region" "current" {}

resource "aws_route53_record" "main" {
  zone_id = var.zone_id
  name    = "${var.name}.${data.aws_region.current.name}.${var.domain}"
  records = var.records
  type    = "A"
  ttl     = "300"
}
```

### IaCテストとソフトウェアテストの違い

**時間**: 標準ソフトウェアテストは数秒〜分で完了するが、IaCテストは数分〜30分以上かかる場合がある（VM起動は数分、データベースは30分超）。

**コスト**: ソフトウェアテストはローカル実行時に追加費用がかからないが、IaCテストは実際のインフラを起動するため、リソース実行時間に応じた課金が発生する。適切に設計すればコストは丸め誤差程度に抑えられるが、必ずテスト後にリソースを削除する仕組みが必須。

**重要**: テストのコストを考慮しつつも、テストしないことのコスト（障害・ダウンタイム）も同時に評価すべき。

### Terraformテストフレームワーク比較

| 項目 | Terratest | Terraform Testing Framework |
|------|-----------|------------------------------|
| 言語 | Go | HCL |
| リリース年 | 2018 | 2023 |
| ネイティブ | No | Yes |
| バージョン柔軟性 | 複数バージョン対応可 | 新バージョンのみ |
| Copilot対応 | No | Yes |
| コミュニティ貢献 | Yes | No |
| サードパーティライブラリ | Yes | No |

**推奨**:

- **新規プロジェクト**: Terraform Testing Framework（HCLのみで記述可能、学習コスト低）
- **既存Terratest採用チーム**: Terratest継続（成熟・豊富なヘルパー関数）
- **広範囲バージョンサポート**: Terratest（古いTerraformバージョンにも対応）

### ユニットテスト vs 統合テスト

**ユニットテスト**: 単一の独立したコンポーネントをテスト。外部依存はモックで置き換え。

**統合テスト**: 複数コンポーネントが連携して動作することをテスト。実際のシステムと対話。

TerraformではProviderがすでに各リソース・データソースを単体でテスト済み（準ユニットテスト相当）。開発者が書くテストの大半は**統合テスト**であり、複数リソースが正しく連携することを確認する。データ変換ロジックのテストも、リソース作成後に確認する形が一般的。

---

## IaCテスト実践

### 基本テストフロー

1. **構成選択**: テストしたい変数・オプションを選択
2. **リソース起動**: Terraform apply
3. **テスト実行**: インフラに対して各種検証
4. **リソース削除**: Terraform destroy（クリーンアップ）

1つのテストに複数のテストケースをグループ化することで、インフラ起動時間を削減できる。

**TIP**: テストもコードである。コメントを充実させ、シンプルに保ち、将来のメンテナンスを考慮する。

### examplesディレクトリで開発・テストを統合

**推奨パターン**: モジュールの `examples/` ディレクトリに完全に動作する使用例を配置。

**利点**:

- **ユーザー**: 実例から学べる
- **開発者**: ローカルで簡単にモジュールを起動・反復開発可能
- **テスト**: examplesをそのままテスト対象として活用（テスト用コードの重複排除）

**ディレクトリ構造例**:

```
examples/
  - basic/main.tf       # 最も単純な例
  - lambda/main.tf      # Lambda統合
  - ecs/main.tf         # ECS統合
  - ec2/main.tf         # EC2統合
```

新機能追加時は既存exampleを拡張するか新規example追加し、テストスイートに直結させる。

### 並行テスト・名前の一意性

複数のPRやテストジョブが同時実行される場合、同じ名前のリソースを作成しようとして衝突する。

**解決策**: `random` Providerでランダム文字列を生成し、名前に付与。

```hcl
resource "random_string" "random" {
  length  = 8
  special = false
  upper   = false
}

module "alb_example" {
  source = "../"
  name   = "testing_${random_string.random.result}"
}
```

**注意**: AWS Secrets Managerなど、削除後一定期間名前を再利用できないリソースの場合、モジュール内部でランダム性を追加することを検討。

### タイムアウト

IaCテストは長時間実行される可能性がある。タイムアウト設定が低すぎると、テスト途中で強制終了され、リソースが孤立したまま残る（状態ファイルが保存されず手動クリーンアップが必要になる）。

**対策**:

- テストフレームワーク側のタイムアウト設定を高めに設定
- CIシステム（GitHub Actions、Jenkins等）のタイムアウト確認・調整

**例**: GitHub Actionsのデフォルトタイムアウトは360分（十分だが、他のCIシステムは要確認）。

### 自動クリーンアップ

テスト失敗時、リソースがクリーンアップされずに残ることがある（コスト増加）。

**推奨**:

- 専用テストアカウントを用意
- 定期的に全リソースを削除する自動化（例: AWS Nuke、Azure Nuke）
- スケジュール実行（例: 毎日深夜に実行）

**AWS Nuke GitHub Actions例**:

```yaml
name: AWS Nuke Job

on:
  schedule:
    - cron: "0 0 * * *" # 毎日深夜

env:
  AWS_ROLE_ARN: arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME
  AWS_DEFAULT_REGION: us-east-1
  AWS_NUKE_VERSION: 2.25.0

jobs:
  aws-nuke:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Setup AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ env.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_DEFAULT_REGION }}
      - name: Install AWS Nuke
        run: |
          curl -L https://github.com/rebuy-de/aws-nuke/releases/download/v${AWS_NUKE_VERSION}/aws-nuke-v${AWS_NUKE_VERSION}-linux-amd64.tar.gz --output aws_nuke.tar.gz
          tar -xvf aws_nuke.tar.gz
          sudo mv aws-nuke-v${AWS_NUKE_VERSION}-linux-amd64 /usr/local/bin/aws-nuke
      - name: Run AWS Nuke
        run: aws-nuke --config nuke-config.yml
```

**重要**: 本番環境では絶対に実行しない。

### 認証とシークレット

テスト実行時も本番同様に認証が必要。OpenID Connect (OIDC) をCIシステムで活用し、長期トークンを避ける。

### テストもコードである

テストスイート自体もソフトウェアとして扱う：

- 分かりやすい変数名
- コメント（テストの意図を記述）
- PRレビュー時にテストコードもレビュー
- 必要に応じてリファクタリング

---

## Terratest

Terratest は Gruntwork が開発した Go ベースのテストフレームワーク。Go testing パッケージ上に構築され、豊富なヘルパー関数を提供。

### Goの基礎

Terratest を使うには最小限の Go 知識が必要。

**基本構造**:

```go
package test

import (
    "testing"
)

func TestExample(t *testing.T) {
    // テストロジック
}
```

- `package test`: テストコードのパッケージ名
- `import`: 必要なライブラリをインポート
- `func TestXxx(t *testing.T)`: テスト関数（`Test`プレフィックス必須）

### Terratest Hello World

```go
package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestHelloWorld(t *testing.T) {
    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../examples/hello-world",
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    output := terraform.Output(t, terraformOptions, "message")
    assert.Equal(t, "Hello, World!", output)
}
```

**説明**:

- `terraformOptions`: Terraformの実行ディレクトリ指定
- `defer terraform.Destroy`: テスト終了時に必ず削除
- `terraform.InitAndApply`: init → apply 実行
- `terraform.Output`: Terraform output 取得
- `assert.Equal`: 値の一致を検証

### examplesの活用

Terratest は examples ディレクトリをそのままテスト対象として利用可能。

**ディレクトリ構造**:

```
module/
  main.tf
  variables.tf
  outputs.tf
  examples/
    basic/
      main.tf
    lambda/
      main.tf
  test/
    basic_test.go
    lambda_test.go
```

**テスト例**:

```go
func TestBasicExample(t *testing.T) {
    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../examples/basic",
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    albArn := terraform.Output(t, terraformOptions, "alb_arn")
    assert.NotEmpty(t, albArn)
}
```

### Terratest ヘルパー関数

Terratest は AWS、Azure、GCP など各種プロバイダー向けヘルパー関数を提供。

**AWS例**:

```go
import (
    "github.com/gruntwork-io/terratest/modules/aws"
)

func TestALB(t *testing.T) {
    // ... terraform apply

    albArn := terraform.Output(t, terraformOptions, "alb_arn")
    alb := aws.GetApplicationLoadBalancer(t, albArn, "us-east-1")
    assert.Equal(t, "internet-facing", *alb.Scheme)
}
```

### Makefile連携

Makefileでテスト実行を簡略化。

```makefile
.PHONY: test
test:
	cd test && go test -v -timeout 30m
```

実行: `make test`

### CI統合

```yaml
name: Terratest

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      - name: Run Terratest
        run: |
          cd test
          go test -v -timeout 30m
```

### Copilot連携

GitHub Copilot はGoコード生成に対応しているが、TerratestのようなドメインSpecificライブラリには対応が限定的。既存テストをコンテキストに含めることで精度向上。

---

## Terraform Testing Framework

Terraform v1.6（OpenTofu v1.6）から導入されたネイティブテストフレームワーク。HCLでテストを記述可能。

### Hello World

**ディレクトリ構造**:

```
module/
  main.tf
  variables.tf
  outputs.tf
  tests/
    hello.tftest.hcl
```

**tests/hello.tftest.hcl**:

```hcl
run "hello_world" {
  command = apply

  assert {
    condition     = output.message == "Hello, World!"
    error_message = "Expected 'Hello, World!', got '${output.message}'"
  }
}
```

**実行**:

```bash
terraform test
```

### Named Values（テスト内変数）

```hcl
variables {
  environment = "test"
  name        = "example"
}

run "test_alb" {
  command = apply

  assert {
    condition     = output.alb_name == "example-test-alb"
    error_message = "ALB name mismatch"
  }
}
```

### Mocks（モックプロバイダー）

外部APIを呼ばずにテスト実行。

```hcl
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }
}

run "mock_test" {
  command = plan

  assert {
    condition     = aws_s3_bucket.main.region == "us-east-1"
    error_message = "Region mismatch"
  }
}
```

### examplesの活用

```
module/
  main.tf
  examples/
    basic/
      main.tf
  tests/
    basic.tftest.hcl
```

**tests/basic.tftest.hcl**:

```hcl
run "basic_example" {
  command = apply

  module {
    source = "../examples/basic"
  }

  assert {
    condition     = output.alb_arn != ""
    error_message = "ALB ARN should not be empty"
  }
}
```

### バージョン管理

Terraform Testing Framework は Terraform v1.6+ でのみ動作。古いバージョンをサポートするモジュールではTerratestを推奨。

### CI統合

```yaml
name: Terraform Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0
      - name: Run Tests
        run: terraform test
```

### Copilot連携

Terraform Testing Framework は HCL ベースのため、Copilot が標準 Terraform コードと同様に補完可能。学習データが少ないため精度は限定的だが、既存テストをコンテキストに含めることで向上。

---

## リファクタリング

### リファクタリング vs 開発

**開発**: 新機能追加・バグ修正で、外部動作を変更。

**リファクタリング**: 外部動作を変えずに内部構造を改善（可読性向上、保守性向上）。

**重要**: リファクタリング中は新機能追加とバグ修正を同時に行わない。

### 内部リファクタリング vs 外部リファクタリング

**内部リファクタリング**: モジュール利用者に影響しない変更（内部ロジック改善、リソース名変更）。

**外部リファクタリング**: 利用者に影響する変更（変数名変更、output名変更、破壊的変更）。

### プロジェクトの再構成

**moved ブロック**: リソースを移動しても状態を保持。

```hcl
# 旧
resource "aws_s3_bucket" "main" {}

# 新（モジュール化）
module "bucket" {
  source = "./modules/bucket"
}

moved {
  from = aws_s3_bucket.main
  to   = module.bucket.aws_s3_bucket.main
}
```

**removed ブロック**: リソースを削除するがインフラは残す。

```hcl
removed {
  from = aws_s3_bucket.old

  lifecycle {
    destroy = false
  }
}
```

### リソース・モジュールのリネーム

```hcl
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}
```

### 変数のリネーム

変数名変更は外部リファクタリング（利用者に影響）。

**段階的移行**:

1. 新変数を追加、旧変数を `deprecated` とマーク
2. 内部で新変数優先ロジック実装
3. 数ヶ月後に旧変数削除

```hcl
variable "old_name" {
  description = "(DEPRECATED) Use new_name instead."
  type        = string
  default     = null
}

variable "new_name" {
  description = "New variable name."
  type        = string
  default     = null
}

locals {
  name = coalesce(var.new_name, var.old_name)
}
```

---

## 外部リファクタリング（互換性破壊管理）

### 互換性を破壊すべきタイミング

**破壊すべき時**:

- 重大なセキュリティ問題の修正
- 使いにくいインターフェースの大幅改善
- 技術的負債の解消

**避けるべき時**:

- 単なる好みの変更
- 利用者数が多く影響範囲が大きい
- 代替手段で解決可能

### 次期メジャーバージョンの計画

Semantic Versioning (semver) に従う:

- **MAJOR**: 破壊的変更
- **MINOR**: 後方互換の機能追加
- **PATCH**: 後方互換のバグ修正

**計画フェーズ**:

1. 破壊的変更リストを作成
2. 移行パスを設計
3. ドキュメント準備

### 次期メジャーバージョンの構築

1. 新ブランチ作成（例: `v2.x`）
2. 破壊的変更を実装
3. テストスイート更新
4. CHANGELOGに移行ガイド記載

### 旧メジャーバージョンの保守

旧バージョンはセキュリティ修正のみ継続。機能追加は新バージョンのみ。

**推奨保守期間**: 6ヶ月〜1年

---

## まとめ

- **テストはIaCの強力な利点**: 品質向上・心理的安全性・リファクタリング促進
- **Terratest**: 成熟・豊富な機能・Go言語
- **Terraform Testing Framework**: HCLネイティブ・新規推奨
- **examplesベースのテスト**: 開発・ドキュメント・テストを統合
- **リファクタリング**: 内部/外部を区別し、慎重に計画
- **破壊的変更**: semverに従い、移行パスを明示
