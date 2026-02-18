---
description: >-
  Comprehensive serverless security guide covering threat models, attack techniques, and defense patterns across AWS, Azure, and Google Cloud.
  Covers IAM credential abuse, storage misconfiguration, code injection, privilege escalation, and supply chain attacks with practical attack/defense examples.
  Use when developing or securing serverless applications (Lambda, Cloud Run, Azure Functions).
  For code-level security (OWASP, CodeGuard), use securing-code instead. For AWS development patterns, use developing-aws instead. For GCP development, use developing-google-cloud instead.
---

# Serverless Security

サーバーレスアプリケーション固有のセキュリティ脅威を理解し、AWS Lambda、Azure Functions、Google Cloud Run等のサーバーレス環境を防御するための包括的ガイド。

---

## サーバーレスセキュリティの特性

### 従来アーキテクチャとの違い

サーバーレスアーキテクチャは以下の特性により、従来とは異なるセキュリティアプローチが必要:

- **短命な実行環境**: 関数は数秒〜数分で終了し、状態を保持しない
- **イベント駆動**: ストレージ、API、メッセージキュー等の複数トリガーが攻撃経路になる
- **自動スケーリング**: 意図しない大量実行がコスト暴走（Denial of Wallet）を引き起こす
- **管理境界の分散**: IAM、ストレージ、ネットワーク、関数コード、CI/CDパイプライン全体が攻撃対象

### サーバーレス固有のリスク

| リスク領域 | 従来アーキテクチャ | サーバーレス |
|-----------|-----------------|------------|
| **IAM権限** | サーバー単位で付与 | 関数単位で付与（粒度が細かく、設定ミスが頻発） |
| **ストレージ** | アプリケーション内部 | 外部ストレージサービス依存（公開設定ミス多発） |
| **コード実行** | 長期稼働プロセス | 短命実行（ログ・トレース設計が不十分だと追跡困難） |
| **ネットワーク** | 固定インフラ | 動的リソース（VPC設定ミス、公開endpoint放置） |

---

## 脅威モデル概要

サーバーレスアプリケーションで頻出する17種類の脅威体系。各脅威の詳細な攻撃シナリオ・防御策は [THREATS.md](references/THREATS.md) 参照。

| # | 脅威カテゴリ | 影響範囲 | 主な攻撃ベクター |
|---|------------|---------|----------------|
| 1 | **公開された関数** | 認証なしでバックエンドロジックへ直接アクセス | Function URL、API Gateway設定ミス |
| 2 | **ストレージ設定ミス** | 機密データ漏洩 | S3/GCS/Azure Blob公開設定 |
| 3 | **IAM認証情報漏洩** | 全リソースへの不正アクセス | Gitコミット、環境変数、ログ出力 |
| 4 | **シークレット管理不備** | API Key/DBパスワード窃取 | ハードコード、環境変数平文保存 |
| 5 | **Injection攻撃** | RCE、データ改ざん | SQL/NoSQL/Command/Code Injection |
| 6 | **過剰権限** | 水平・垂直権限昇格 | 最小権限原則違反 |
| 7 | **ビジネスロジック脆弱性** | レート制限なし、検証不足 | 実装ミス |
| 8 | **ネットワーク設定ミス** | 内部リソース露出 | VPC設定不備、SG設定ミス |
| 9 | **ログ・監視不足** | インシデント検知遅延 | トレーシング未実装 |
| 10 | **セキュリティ機構の限界** | WAF回避、スキャナ検知漏れ | ツール過信 |
| 11 | **CI/CD侵害** | バックドア混入、Supply Chain攻撃 | パイプライン認証不備 |
| 12 | **認証破れ** | セッション乗っ取り | JWT検証不備、セッション管理ミス |
| 13 | **脆弱なライブラリ** | 既知脆弱性悪用 | 依存関係更新漏れ |
| 14 | **DoS / Denial of Wallet** | サービス停止、コスト暴走 | レート制限なし、無限ループ |
| 15 | **XSS** | クライアント攻撃 | 入力サニタイズ不足 |
| 16 | **API Gateway設定ミス** | 認証バイパス | CORS、認証設定不備 |
| 17 | **Supply Chain攻撃** | 依存パッケージ経由の侵害 | typosquatting、悪意あるパッケージ |

---

## クラウド横断セキュリティ原則

### 1. 最小権限の原則（Principle of Least Privilege）

**全クラウドプロバイダー共通のベストプラクティス:**

- 関数には必要最小限の権限のみ付与
- ワイルドカード（`*`）の使用禁止（例: `s3:*`、`storage.objects.*`）
- リソース単位でスコープを制限（例: 特定バケット、特定テーブルのみアクセス可）
- 定期的な権限監査（未使用権限の削除）

**判断分岐時の対応:**

広範な権限が本当に必要かどうか判断に迷う場合、`AskUserQuestion` で以下を確認:

```markdown
関数に必要な権限を確認してください:
- [ ] 読み取り専用で十分（`s3:GetObject`、`storage.objects.get`）
- [ ] 書き込みも必要（`s3:PutObject`、`storage.objects.create`）
- [ ] 削除権限も必要（`s3:DeleteObject`、`storage.objects.delete`）
- [ ] 全リソースへのアクセスが必要（要明確な理由）
```

### 2. シークレット管理

**禁止事項:**
- ❌ ソースコードへのハードコード
- ❌ 環境変数への平文保存
- ❌ `.env` ファイルのリポジトリコミット

**推奨アプローチ:**

| クラウド | シークレット管理サービス |
|---------|------------------------|
| **AWS** | AWS Secrets Manager / Systems Manager Parameter Store（暗号化必須） |
| **Google Cloud** | Secret Manager |
| **Azure** | Azure Key Vault |

**実装パターン:**

```python
# 悪い例
DATABASE_PASSWORD = "MyP@ssw0rd123"  # ハードコード

# 良い例（AWS）
import boto3
secrets_client = boto3.client('secretsmanager')
secret = secrets_client.get_secret_value(SecretId='prod/db/password')
DATABASE_PASSWORD = secret['SecretString']
```

### 3. ネットワーク分離

**デフォルト設定の危険性:**

- Lambda関数・Cloud Run・Azure Functionsはデフォルトでインターネット接続可能
- 内部リソース（RDS、Cloud SQL、Cosmos DB）への直接接続は推奨されない

**推奨構成:**

```
[関数] → [VPC/VNet] → [Private Subnet] → [DB/内部サービス]
         └─ [NAT Gateway/Cloud NAT] → [インターネット]
```

- 関数をVPC/VNet内に配置
- データベースはプライベートサブネットに配置
- インターネットアクセスが必要な場合のみNAT Gateway経由

### 4. ロギング・監視

**最低限必須の監視項目:**

- [ ] 関数の実行ログ（CloudWatch Logs / Cloud Logging / Application Insights）
- [ ] IAM認証ログ（CloudTrail / Cloud Audit Logs / Azure Activity Log）
- [ ] API Gatewayアクセスログ
- [ ] ストレージアクセスログ（S3 / GCS / Blob Storage）
- [ ] 異常な権限昇格の検知（GuardDuty / Security Command Center / Defender for Cloud）

**分散トレーシング推奨:**

OpenTelemetry実装は `implementing-opentelemetry` スキル参照。

### 5. Infrastructure as Code（IaC）によるセキュリティ管理

**IaC テンプレートでのセキュリティ設定必須項目:**

- IAM Role定義（最小権限）
- VPC/Subnet/Security Group設定
- ストレージバケットのアクセス制御（Block Public Access有効化）
- 暗号化設定（保存時・転送時）
- ログ保存先の設定

**詳細は `developing-aws`（AWS）、`developing-google-cloud`（GCP）、`developing-terraform`（Terraform）スキル参照。**

---

## クラウドプロバイダー別ガイド

各クラウドプロバイダー固有の攻撃手法・防御策・ツールは専用リファレンスを参照:

| クラウド | 参照ファイル | 主要トピック |
|---------|-------------|-------------|
| **AWS IAM** | [AWS-IAM.md](references/AWS-IAM.md) | IAM認証情報悪用、IAM Role権限昇格、AssumeRole攻撃チェーン |
| **AWS Lambda** | [AWS-LAMBDA.md](references/AWS-LAMBDA.md) | Lambda Function URL攻撃、コードインジェクション、VPC保護、Secrets Manager窃取 |
| **GCP Storage** | [GCP-STORAGE.md](references/GCP-STORAGE.md) | GCSバケット攻撃、Dangling Bucket Takeover、IaCによる保護 |
| **GCP Compute** | [GCP-COMPUTE.md](references/GCP-COMPUTE.md) | Cloud Run/Functions権限昇格、Event Trigger悪用、Workload Identity |
| **Azure** | [AZURE-FUNCTIONS.md](references/AZURE-FUNCTIONS.md) | Azure Functions攻撃、Managed Identity悪用、RBAC権限昇格 |
| **コード分析** | [CODE-ANALYSIS.md](references/CODE-ANALYSIS.md) | Semgrep/OSV-Scanner、依存関係スキャン、セキュアコーディング |

---

## サーバーレスセキュリティチェックリスト

### IAM / 認証認可

- [ ] 全関数に最小権限のIAM Role/Service Account/Managed Identityを付与
- [ ] ワイルドカード権限（`*`）を使用していない
- [ ] リソースベースポリシーで許可対象を明示的に指定
- [ ] 一時認証情報を使用（長期認証情報を避ける）
- [ ] クロスアカウントアクセスは明示的な信頼関係が必要
- [ ] 定期的な権限監査（IAM Access Analyzer / GCP Policy Analyzer / Azure Advisor使用）

### ストレージセキュリティ

- [ ] S3 Block Public Access / GCS Uniform Bucket-Level Access有効化
- [ ] バケットポリシーで公開アクセスを明示的に拒否
- [ ] 保存時暗号化を有効化（SSE-S3/KMS / CMEK / Azure Storage Service Encryption）
- [ ] バージョニング有効化（誤削除・ランサムウェア対策）
- [ ] アクセスログを有効化し、定期的に監査
- [ ] 署名付きURL使用時は有効期限を短く設定（数分〜数時間）
- [ ] CORS設定を最小限に制限

### 関数セキュリティ

- [ ] 関数はVPC/VNet内に配置（外部接続が不要な場合）
- [ ] 環境変数に機密情報を平文保存しない（Secrets Manager等使用）
- [ ] タイムアウト・メモリ上限を適切に設定（DoS対策）
- [ ] 同時実行数制限（Reserved Concurrency / Max Instances）を設定
- [ ] 関数コードに入力検証・サニタイズを実装
- [ ] エラーメッセージに機密情報を含めない
- [ ] 依存ライブラリを定期的に更新（Dependabot / Renovate使用推奨）

### ネットワークセキュリティ

- [ ] Security Group / Firewall Ruleでアクセス元IPを制限
- [ ] 内部リソースはPrivate Subnetに配置
- [ ] VPC Endpoint / Private Service Connectを使用（AWSサービス間通信）
- [ ] API GatewayにWAF適用（AWS WAF / Cloud Armor / Azure WAF）
- [ ] API Gatewayに認証メカニズム実装（Lambda Authorizer / API Gateway Auth / Azure AD）
- [ ] レート制限・スロットリング設定

### CI/CD パイプライン

- [ ] パイプライン認証にOIDC使用（長期認証情報を使わない）
- [ ] デプロイ前にSAST/SCA/DAST実行
- [ ] IaCテンプレートのセキュリティスキャン（Checkov / tfsec）
- [ ] デプロイ承認プロセスを実装（本番環境）
- [ ] パイプライン実行ログを監査ログとして保存
- [ ] シークレットをCI/CD変数として暗号化保存

### コードレベルセキュリティ

- [ ] OWASP Top 10対策実装（`securing-code` スキル参照）
- [ ] SQL/NoSQLインジェクション対策（パラメータ化クエリ）
- [ ] コマンドインジェクション対策（ユーザー入力をシェルに渡さない）
- [ ] XSS対策（出力エンコーディング）
- [ ] SSRF対策（内部URLへのリクエスト禁止）
- [ ] Deserialization攻撃対策（信頼できないデータのデシリアライズ禁止）
- [ ] 実装完了後に `/codeguard-security:software-security` 実行（必須）

---

## ユーザー確認の原則（AskUserQuestion）

以下の判断分岐が発生した場合、`AskUserQuestion` ツールでユーザーに選択肢を提示すること:

### 1. ネットワーク構成の判断

```markdown
サーバーレス関数のネットワーク構成を選択してください:
- [ ] パブリックインターネット接続（外部API呼び出しが必要）
- [ ] VPC/VNet内に配置（内部リソースのみアクセス）
- [ ] VPC + NAT Gateway（内部リソース + 外部API両方必要）
```

### 2. 権限スコープの判断

```markdown
IAM権限の範囲を確認してください:
- [ ] 特定リソースのみ（推奨）: `arn:aws:s3:::my-bucket/*`
- [ ] 複数リソース: 個別に列挙
- [ ] 全リソース（要正当な理由）: `*`
```

### 3. ストレージ公開設定の判断

```markdown
ストレージバケットのアクセス設定を確認してください:
- [ ] 完全プライベート（推奨）
- [ ] 特定AWSアカウント/GCPプロジェクトのみ
- [ ] 署名付きURLで一時公開
- [ ] パブリック読み取り可能（静的サイトホスティング等）
```

### 4. ログ保存期間の判断

```markdown
ログ保存期間を設定してください:
- [ ] 7日間（開発環境）
- [ ] 30日間（ステージング環境）
- [ ] 90日間以上（本番環境・コンプライアンス要件）
```

---

## 関連スキル

| スキル | 用途 |
|--------|------|
| **securing-code** | OWASP Top 10、CodeGuard実行、コードレベルセキュリティ |
| **developing-aws** | AWSサーバーレス開発パターン、IAM設計、CDK/SAM |
| **developing-google-cloud** | Google Cloud開発、Cloud Run、Service Account設計 |
| **implementing-opentelemetry** | 分散トレーシング、セキュリティログ統合 |
| **designing-monitoring** | SLO設計、アラート設計、インシデント検知 |
| **implementing-dynamic-authorization** | ABAC/ReBAC/Cedar、動的認可システム |
| **practicing-devops** | IaC、CI/CDセキュリティ、Secret管理 |

---

## 参考リソース

- **脅威体系詳細**: [THREATS.md](references/THREATS.md)
- **AWS IAMセキュリティ**: [AWS-IAM.md](references/AWS-IAM.md)
- **AWS Lambdaセキュリティ**: [AWS-LAMBDA.md](references/AWS-LAMBDA.md)
- **GCSストレージセキュリティ**: [GCP-STORAGE.md](references/GCP-STORAGE.md)
- **GCP Computeセキュリティ**: [GCP-COMPUTE.md](references/GCP-COMPUTE.md)
- **Azureセキュリティ**: [AZURE-FUNCTIONS.md](references/AZURE-FUNCTIONS.md)
- **コード分析**: [CODE-ANALYSIS.md](references/CODE-ANALYSIS.md)
