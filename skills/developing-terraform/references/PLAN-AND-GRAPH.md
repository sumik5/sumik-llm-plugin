# Terraform Plan と Graph

TerraformのPlanフェーズとリソースグラフの仕組みを理解するためのガイド。

---

## 目次

1. [DAG（有向非巡回グラフ）](#dag有向非巡回グラフ)
2. [Terraformリソースグラフ](#terraformリソースグラフ)
3. [Planフェーズ](#planフェーズ)
4. [ルートモジュール入力変数](#ルートモジュール入力変数)
5. [Applyフェーズ](#applyフェーズ)
6. [よくある落とし穴](#よくある落とし穴)

---

## DAG（有向非巡回グラフ）

### グラフ理論の基礎

グラフは**ノード（node）**と**エッジ（edge）**で構成されるデータ構造。インフラストラクチャの依存関係を表現するのに最適。

| 用語 | 説明 |
|------|------|
| **ノード（node）** | リソース・サービスなどの実体 |
| **エッジ（edge）** | ノード間の関係・依存性 |
| **有向（directed）** | エッジに方向性がある（A → B） |
| **非巡回（acyclic）** | 循環参照が存在しない |

### DAGの特性

- **方向性**: 依存関係の順序を定義（A が B に依存 → B を先に作成）
- **非巡回性**: A → B → C → A のような循環を禁止
- **決定性**: 実行順序が一意に決定される

### TerraformにおけるDAG

Terraformは内部的にすべてのリソースをDAGとして表現する。コード内で属性参照を使うことで、自動的に依存関係を検出。

```hcl
resource "tls_private_key" "ca_key" {
  algorithm = "ED25519"
}

resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_key.private_key_pem  # 依存関係を自動検出
  # ...
}
```

---

## Terraformリソースグラフ

### ノードの種類

| ノードタイプ | 説明 |
|-------------|------|
| **Resource** | 個別のリソースインスタンス（`count`/`for_each`で複数生成可能） |
| **Provider Configuration Node** | プロバイダ設定ごとに1つ（複数リージョン対応可能） |
| **Resource Meta Node** | `count` > 1のときのグループ表現 |

### terraform graphコマンド

リソースグラフを可視化するためのコマンド。GraphViz（dotコマンド）と組み合わせて使用。

#### 基本的な使い方

```bash
# DOTファイルとして出力
terraform graph > graph.dot

# SVG画像として出力
terraform graph | dot -Tsvg > graph.svg

# PNG画像として出力
terraform graph | dot -Tpng > graph.png
```

#### グラフの種類

| タイプ | コマンド | 用途 |
|--------|---------|------|
| plan | `terraform graph` | 計画段階のグラフ（デフォルト） |
| apply | `terraform graph -type=apply -plan=<file>` | 適用段階の詳細グラフ |
| plan-destroy | `terraform graph -type=plan-destroy` | 削除計画のグラフ |

**注意**: `apply`グラフは保存済みplanファイルが必要。

### モジュールとグラフ

**重要な仕様**: モジュール境界はグラフ上に存在しない。

- モジュールBがモジュールAに依存しても、モジュールB内のリソースがモジュールA内のリソースより先に作成される可能性がある
- Terraformはモジュール単位ではなく、リソース単位で依存関係を解決する

---

## Planフェーズ

### Planの基本

```bash
# 基本的なplan実行
terraform plan

# planを保存（推奨）
terraform plan -out=example.tfplan

# 保存したplanを表示
terraform show example.tfplan
```

**Speculative Plan**: 適用を前提としないplan（開発・テスト時）。

### Planning Modes

| モード | フラグ | 用途 |
|--------|--------|------|
| **default** | （なし） | 通常の変更計画 |
| **destroy** | `-destroy` | 全リソースの削除計画 |
| **refresh-only** | `-refresh-only` | ステート更新のみ（リソース変更なし） |

#### destroyモード

```bash
terraform plan -destroy -out=destroy.tfplan
```

- すべてのリソースを削除する計画を生成
- リソースは作成時の逆順で削除される（依存関係を考慮）

#### refresh-onlyモード

```bash
terraform plan -refresh-only
```

- 手動変更の検出やドリフト確認に使用
- コード変更は無視される

### Replace（旧taint）

特定リソースを強制的に再作成する機能。

```bash
terraform plan -replace 'tls_private_key.child_key["example.com"]'
```

**注意事項**:
- 単一リソースの置換でも、依存する複数リソースが連鎖的に再作成される可能性がある
- `-replace`フラグは複数回指定可能
- 旧`terraform taint`コマンドは非推奨（ステートを即座に変更するため）

### Resource Targeting

**⚠️ 使用は最小限に**

```bash
terraform plan -target=<resource_address>
```

- 特定リソースのみを対象に計画を生成
- デバッグや緊急対応時のみ使用
- 通常運用での依存は強いアンチパターン

### Refreshの無効化

```bash
terraform plan -refresh=false
```

**危険**: ステート更新をスキップするため、plan が不正確になる可能性が高い。

### terraform refreshコマンド（非推奨）

```bash
# 非推奨（危険）
terraform refresh

# 代わりにこちらを使用
terraform apply -refresh-only
```

**理由**: 認証エラー時にリソースが「削除された」と誤認識される可能性がある。

---

## ルートモジュール入力変数

### 変数設定の優先順位（高→低）

1. **`-var`フラグ** （コマンドライン）
2. **`-var-file`フラグ** （明示的なファイル指定）
3. **`*.auto.tfvars`** （自動ロード、アルファベット順）
4. **`terraform.tfvars.json`** （自動ロード）
5. **`terraform.tfvars`** （自動ロード）
6. **環境変数** （`TF_VAR_*`）
7. **対話式入力** （デフォルト値がない場合）

### 1. 対話式入力

```bash
terraform plan
# 未定義変数があれば対話的に入力を求められる
```

**推奨**: `-input=false`で無効化し、自動化環境ではエラーにする。

### 2. -varフラグ

```bash
terraform plan -var 'vpc=vpc-01234567890abcdef' -var 'num_instances=2'
```

**欠点**:
- シェル履歴に残る
- 複雑なデータ型の扱いが困難
- エスケープ処理が必要

### 3. Variable Files

#### HCL形式（推奨）

```hcl
# production.tfvars
vpc           = "vpc-01234567890abcdef"
num_instances = 2
```

```bash
terraform plan -var-file=production.tfvars
```

#### JSON形式

```json
{
  "vpc": "vpc-01234567890abcdef",
  "num_instances": 2
}
```

#### ファイル名パターン

| 拡張子 | フォーマット | 自動ロード |
|--------|-------------|-----------|
| `*.tfvars` | HCL | ❌（`-var-file`必須） |
| `*.auto.tfvars` | HCL | ✅ |
| `terraform.tfvars` | HCL | ✅ |
| `*.tfvars.json` | JSON | ❌ |
| `*.auto.tfvars.json` | JSON | ✅ |
| `terraform.tfvars.json` | JSON | ✅ |

### 4. 環境変数

```bash
export TF_VAR_num_instances=2
terraform plan
```

- 変数名は大文字・小文字を区別する
- プロバイダ認証情報の設定に適している
- 通常の設定値には他の方法を推奨

### シークレット管理のベストプラクティス

| 方法 | リスク | 推奨度 |
|------|-------|--------|
| `-var`フラグ | シェル履歴に残る | ❌ |
| Variable Files | バージョン管理に残る | ❌ |
| 環境変数 | ログ漏洩の可能性 | ⚠️ |
| **CI/CDシークレット機能** | 専用マスキング機能あり | ✅ |
| **シークレットマネージャー** | Vault, AWS Secrets Manager等 | ✅✅ |

---

## Applyフェーズ

### Planファイルを使用

```bash
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

- Applyは承認なしで即座に実行される（planファイル使用時）
- CI/CDパイプラインで推奨される方法

### Plan + Applyを一度に実行

```bash
# 承認プロンプトあり
terraform apply

# 自動承認（慎重に使用）
terraform apply -auto-approve
```

**注意**: `-auto-approve`は開発環境以外では避けるべき。

### Destroyコマンド

```bash
# 承認プロンプトあり
terraform destroy

# 自動承認（⚠️ 危険）
terraform destroy -auto-approve
```

**重要**: `terraform destroy`は `terraform apply -destroy`のエイリアス。

### Apply/Planオプション

#### Parallelism

```bash
# デフォルトは10
terraform apply -parallelism=5

# デバッグ時は1に設定
TF_LOG=debug terraform plan -parallelism=1
```

**考慮事項**:
- 依存関係がボトルネックになる
- APIレートリミットの影響を受ける
- デバッグ時は並列度を下げる

#### Locking

```bash
# ロックを無効化（⚠️ 通常は非推奨）
terraform plan -lock=false
```

**許容されるケース**: Speculative Planのみ（実際にapplyしない場合）。

#### JSONフォーマット

```bash
terraform plan -json
```

- 自動化ツールでのパース用
- 詳細は後の章で解説

---

## よくある落とし穴

### 1. 循環依存（Circular Dependencies）

#### 問題

```hcl
resource "null_resource" "alpha" {
  triggers = {
    rebuild = null_resource.charlie.id  # charlie に依存
  }
}

resource "null_resource" "bravo" {
  triggers = {
    rebuild = null_resource.alpha.id  # alpha に依存
  }
}

resource "null_resource" "charlie" {
  triggers = {
    rebuild = null_resource.bravo.id  # bravo に依存 → 循環！
  }
}
```

```
Error: Cycle: null_resource.alpha, null_resource.bravo, null_resource.charlie
```

#### 解決策: 変数による抽象化

```hcl
variable "build_id" {
  default = null
  type    = string
}

resource "null_resource" "alpha" {
  triggers = {
    rebuild = var.build_id  # 変数を参照（循環なし）
  }
}

resource "null_resource" "bravo" {
  triggers = {
    rebuild = var.build_id
  }
}

resource "null_resource" "charlie" {
  triggers = {
    rebuild = var.build_id
  }
}
```

### 2. カスケード変更（Cascading Changes）

#### 問題の特定

```
# forces replacement
```

Planに`forces replacement`が表示された場合、そのリソースと依存リソースが再作成される。

#### 対策

1. **Planのレビュー**: 置換されるリソースに注意
2. **ignore_changes**: 特定属性の変更を無視

```hcl
resource "example_resource" "foo" {
  # ...

  lifecycle {
    ignore_changes = [
      algorithm,  # この属性変更では再作成しない
    ]
  }
}
```

3. **依存関係の簡素化**: アーキテクチャの見直し

### 3. 隠れた依存関係（Hidden Dependencies）

#### 問題

コード上で属性参照がないため、Terraformが依存関係を検出できない。

例: NAT GatewayがInternet Gatewayの存在を暗黙的に前提とする場合。

#### 解決策: `depends_on`

```hcl
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

resource "aws_nat_gateway" "example" {
  # ...

  depends_on = [aws_internet_gateway.example]  # 明示的な依存宣言
}
```

### 4. 常時検出される変更（Always Detected Changes）

#### 原因

プロバイダがAPI応答を正しく変換できていない。

| 例 | 問題 |
|----|------|
| `45` → `45.0` | 整数が浮動小数点数に変換される |
| `true` → `"true"` | ブール値が文字列に変換される |
| `["a", "b"]` → `["b", "a"]` | リストの順序が変わる |
| `"Example"` → `"example"` | 大文字小文字が変わる |

#### 対策

1. 入力をAPI応答に合わせる（小文字、ソート済みリスト等）
2. プロバイダのIssue Trackerに報告

### 5. 計算値とイテレーション（Calculated Values and Iterations）

#### 問題

`count`や`for_each`の値は**Plantime**に確定している必要がある。リソース属性（Apply後に確定する値）は使用不可。

```hcl
# ❌ NG: DNS recordのnameはApply後に確定
locals {
  use_eip = endswith("example.com", aws_route53_record.name)
}

resource "aws_eip" "example" {
  count = local.use_eip ? 1 : 0  # エラー！
}
```

#### 解決策: 変数を使用

```hcl
variable "domain" {
  type = string
}

# ✅ OK: 変数はPlantime確定
locals {
  use_eip = endswith("example.com", var.domain)
}

resource "aws_eip" "example" {
  count = local.use_eip ? 1 : 0  # 問題なし
}
```

---

---

## パフォーマンス最適化

大規模インフラでは plan/apply の実行時間が問題になることがある。原因と対策を理解しておく。

### `-parallelism` フラグによる並列度制御

Terraformは依存関係のないリソースをDAGに基づいて並列作成する。デフォルトの並列数は **10**。

```bash
# デフォルト（10並列）
terraform apply

# 並列数を増やす（API rate limitに余裕がある場合）
terraform apply -parallelism=20

# 並列数を減らす（APIスロットリングが発生する場合）
terraform apply -parallelism=5

# デバッグ時は直列実行（ログが読みやすくなる）
TF_LOG=debug terraform plan -parallelism=1
```

**調整指針**:

| 状況 | 推奨値 | 理由 |
|------|-------|------|
| APIスロットリングエラーが発生 | 5以下に削減 | プロバイダーのRate Limitを超えている |
| 依存関係が少なく独立リソースが多い | 20〜30に増加 | 並列化の恩恵を最大化できる |
| デバッグ・障害調査 | 1（直列） | ログの前後関係が追いやすい |
| デフォルト | 10 | ほとんどの場合で適切 |

**注意**: 並列数を増やしても依存関係がボトルネックになる場合は改善しない。独立リソースを増やすアーキテクチャの見直しが有効。

### 大規模stateの影響と対策

stateファイルが肥大化すると plan/apply の実行時間が増大する。

**原因**:
- 1つのstate内のリソース数が増えるほど、Terraformが差分計算するコストが上がる
- 全リソースのRefresh（APIへの問い合わせ）が並列実行されるが、その総量も増加する

**対策**: ステート分割によるリソース数の上限管理

```
# 分割前（1つのstateに全リソース）
environments/prod/
└── main.tf  ← 200リソース → plan が遅い

# 分割後（レイヤー別に分離）
environments/prod/
├── 01-network/    ← 30リソース（VPC, サブネット, NAT GW等）
├── 02-database/   ← 20リソース（RDS, ElastiCache等）
└── 03-application/ ← 50リソース（ECS, ALB, Lambda等）
```

**目安**: 1つのstateで管理するリソース数は **100〜150以内** に収めることを推奨。それ以上になったらレイヤー分割を検討する。

分割後のstate間連携は `terraform_remote_state` で行う（MODULES.mdのステート分割戦略も参照）。

---

## まとめ

| フェーズ | 主な役割 | 重要コマンド |
|---------|---------|-------------|
| **Graph** | 依存関係の可視化 | `terraform graph \| dot -Tpng > graph.png` |
| **Plan** | 変更計画の生成 | `terraform plan -out=plan.tfplan` |
| **Apply** | 実際の変更適用 | `terraform apply plan.tfplan` |

**ベストプラクティス**:
- 常にplanを保存してレビュー
- `forces replacement`に注意
- 循環依存を避ける設計
- Speculative Plan時のみlockを無効化
- APIスロットリングが発生したら `-parallelism` を削減
- stateが肥大化したらレイヤー別分割を検討
