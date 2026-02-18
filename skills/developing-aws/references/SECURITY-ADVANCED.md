# AWS Advanced Security リファレンス

エンタープライズ向けAWSセキュリティの包括的ガイド。

> **関連**: 基本的なIAMセキュリティは [SECURITY.md](./SECURITY.md)、ネットワークセキュリティは [NETWORKING.md](./NETWORKING.md) を参照

---

## 目次

1. [セキュリティフレームワーク](#セキュリティフレームワーク)
2. [高度なIAM設計](#高度なiam設計)
3. [暗号化と鍵管理](#暗号化と鍵管理)
4. [ネットワークセキュリティ](#ネットワークセキュリティ)
5. [脅威検出と監視](#脅威検出と監視)
6. [インシデント対応](#インシデント対応)
7. [コンプライアンスとガバナンス](#コンプライアンスとガバナンス)
8. [DevSecOps](#devsecops)

---

## セキュリティフレームワーク

### AWS共有責任モデル

| 責任主体 | 範囲 |
|---------|------|
| AWS | 物理セキュリティ、ハードウェア、グローバルインフラ |
| 顧客 | データ、IAM設定、ネットワーク設定、暗号化 |

**サービスタイプ別責任**

| サービスタイプ | AWS責任 | 顧客責任 |
|--------------|--------|---------|
| IaaS (EC2) | ハードウェア、仮想化 | OS、パッチ、アプリケーション |
| コンテナ (ECS, EKS) | インフラ、コンテナランタイム | タスク定義、Pod設定 |
| 抽象 (Lambda, S3) | ほぼ全て | 関数コード、バケットポリシー |

### AWS Well-Architected セキュリティピラー

**7つの設計原則**
1. 強力なアイデンティティ基盤
2. トレーサビリティの有効化
3. 全レイヤーでのセキュリティ適用
4. セキュリティベストプラクティスの自動化
5. 転送時・保存時のデータ保護
6. データへの人的アクセス最小化
7. セキュリティイベントへの備え

### コアセキュリティサービス

| サービス | 機能 | 用途 |
|---------|------|------|
| IAM | ID・アクセス管理 | 認証・認可 |
| KMS | 鍵管理 | 暗号化 |
| Security Hub | セキュリティ統合管理 | 一元的可視化 |
| GuardDuty | 脅威検出 | 異常検知 |
| WAF | Webアプリ保護 | L7防御 |
| Shield | DDoS防御 | L3/L4防御 |
| CloudTrail | API監査 | ログ記録 |
| Macie | データ分類 | PII検出 |
| Config | 設定管理 | コンプライアンス |
| Detective | セキュリティ調査 | フォレンジック |
| Inspector | 脆弱性スキャン | EC2/Lambda/ECR |

---

## 高度なIAM設計

### ポリシー評価ロジック

**評価順序**
1. 明示的Deny → 即時拒否
2. Organizations SCP → 境界設定
3. リソースベースポリシー → クロスアカウント許可
4. アイデンティティベースポリシー → ユーザー/ロール許可
5. Permissions Boundary → 最大許可範囲
6. セッションポリシー → 一時的な制限

**有効な権限 = (アイデンティティ ∩ Boundary ∩ SCP) - 明示的Deny**

### Permissions Boundary

**用途**
- 委任された管理者が作成するロールの権限上限
- 開発者セルフサービスの制限
- サンドボックス環境の制御

**設計パターン**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "dynamodb:*",
        "lambda:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "iam:*",
        "organizations:*",
        "account:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### クロスアカウントアクセス

**信頼関係の設定**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "unique-external-id"
        }
      }
    }
  ]
}
```

**ベストプラクティス**
- ExternalId による Confused Deputy 対策
- MFA 条件の追加
- 最小権限の適用

### フェデレーション

**SAML 2.0 フェデレーション**
- 企業IdP との統合
- AWS IAM Identity Center 推奨
- AssumeRoleWithSAML API

**Web ID フェデレーション**
- Amazon Cognito 経由
- ソーシャルプロバイダー連携
- AssumeRoleWithWebIdentity API

### MFA（多要素認証）

**MFAタイプ**

| タイプ | 説明 |
|--------|------|
| 仮想MFA | 認証アプリ（Authenticator等） |
| ハードウェアMFA | 物理トークン |
| FIDO2 | セキュリティキー |
| SMS MFA | テキストメッセージ（非推奨） |

**MFA条件付きポリシー**

```json
{
  "Condition": {
    "Bool": {
      "aws:MultiFactorAuthPresent": "true"
    }
  }
}
```

---

## 暗号化と鍵管理

### AWS KMS

**鍵の種類**

| 種類 | 管理者 | ローテーション | コスト |
|------|--------|--------------|--------|
| AWS管理キー | AWS | 自動（3年） | 無料 |
| カスタマー管理キー | 顧客 | 自動（1年）/手動 | 有料 |
| 外部キーストア | 顧客（外部HSM） | 手動 | 有料 |

**Envelope Encryption**

```
1. データキー生成リクエスト → KMS
2. KMS がプレーンテキストキーと暗号化キーを返却
3. プレーンテキストキーでデータを暗号化
4. 暗号化キーをデータと共に保存
5. プレーンテキストキーをメモリから削除
```

**キーポリシー構造**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Key Administrators",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::111122223333:role/KeyAdmin"},
      "Action": [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Key Users",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::111122223333:role/KeyUser"},
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
```

### AWS CloudHSM

**KMS vs CloudHSM**

| 項目 | KMS | CloudHSM |
|------|-----|----------|
| 管理 | フルマネージド | 共有責任 |
| 鍵の所有権 | AWS（共有テナント） | 顧客（専用HSM） |
| 暗号化標準 | AES-256, RSA | FIPS 140-2 Level 3 |
| 統合 | AWSサービス自動統合 | 手動統合 |
| 用途 | 一般的な暗号化 | 規制要件（PCI DSS等） |

### サービス別暗号化

**S3暗号化オプション**

| オプション | 説明 |
|----------|------|
| SSE-S3 | S3管理キー（デフォルト） |
| SSE-KMS | KMS管理キー |
| SSE-C | 顧客提供キー |
| CSE | クライアント側暗号化 |

**RDS暗号化**
- 保存時暗号化: EBS暗号化（KMS）
- 転送時暗号化: TLS接続
- TDE: Oracle/SQL Server（データベースレベル）

**EBS暗号化**
- デフォルト暗号化設定推奨
- スナップショットも自動暗号化
- 暗号化ボリューム間でのみコピー可能

### 転送時の暗号化

**ACM（AWS Certificate Manager）**
- パブリック証明書: 無料、自動更新
- プライベートCA: 内部証明書発行
- 対応サービス: CloudFront, ALB, API Gateway

**VPNとPrivateLink**
- Site-to-Site VPN: IPsec暗号化
- Client VPN: OpenVPN暗号化
- PrivateLink: VPC内プライベート接続

---

## ネットワークセキュリティ

### VPCセキュリティ設計

**多層防御アーキテクチャ**

```
Internet
    │
    ↓
[CloudFront + WAF]
    │
    ↓
[ALB - Public Subnet]
    │
    ↓
[Security Groups]
    │
    ↓
[App Servers - Private Subnet]
    │
    ↓
[NACLs + Security Groups]
    │
    ↓
[Database - Isolated Subnet]
```

### Security Groups vs NACLs

| 項目 | Security Groups | NACLs |
|------|----------------|-------|
| レベル | インスタンス | サブネット |
| ステート | ステートフル | ステートレス |
| ルール | 許可のみ | 許可/拒否 |
| 評価 | 全ルール評価 | 番号順評価 |
| デフォルト | 全拒否 | 全許可 |

**使い分け**
- Security Groups: マイクロセグメンテーション、アプリケーション制御
- NACLs: サブネットレベルの防御、明示的ブロック

### AWS WAF

**コンポーネント**

| コンポーネント | 説明 |
|--------------|------|
| Web ACL | ルールのコンテナ |
| Rule | 検査条件と動作の定義 |
| Rule Group | ルールの再利用可能なセット |
| Managed Rules | AWS/パートナー提供のルールセット |

**統合ポイント**
- Amazon CloudFront
- Application Load Balancer
- API Gateway
- AWS AppSync
- Amazon Cognito User Pool

**Managed Rules例**
- AWS Managed Rules for Common Threats
- SQL Injection対策
- XSS対策
- Known Bad Inputs

### AWS Shield

**Standard vs Advanced**

| 項目 | Standard | Advanced |
|------|----------|----------|
| コスト | 無料 | 月額 $3,000 |
| 保護対象 | L3/L4 | L3/L4/L7 |
| DRTサポート | なし | 24/7 |
| コスト保護 | なし | DDoS起因のスケーリング費用 |
| 可視性 | 基本 | 詳細メトリクス |

### AWS Network Firewall

**機能**
- ステートフルインスペクション
- IPSルール（Suricata互換）
- ドメインリストフィルタリング
- TLSインスペクション

**ルールグループタイプ**

| タイプ | 説明 |
|--------|------|
| Stateless | 5-tupleベースのフィルタリング |
| Stateful | IPS、ドメイン、プロトコル検査 |

### VPCエンドポイント

**エンドポイントタイプ**

| タイプ | 対象 | 料金 |
|--------|------|------|
| Gateway | S3, DynamoDB | 無料 |
| Interface | 他のAWSサービス | 時間/データ量課金 |

**セキュリティベストプラクティス**
- VPCエンドポイントポリシーで最小権限
- プライベートサブネットからのアクセス
- インターネットゲートウェイ不要化

---

## 脅威検出と監視

### Amazon GuardDuty

**データソース**

| ソース | 検出対象 |
|--------|---------|
| CloudTrail管理イベント | 異常なAPI呼び出し |
| CloudTrail S3データイベント | S3への不正アクセス |
| VPC Flow Logs | ネットワーク異常 |
| DNS Logs | 悪意あるドメイン通信 |
| Kubernetes監査ログ | EKS脅威 |
| マルウェア保護 | EC2/EBS上のマルウェア |

**脅威タイプ例**
- UnauthorizedAccess: 不正アクセス試行
- Recon: 偵察活動
- Trojan: マルウェア通信
- CryptoCurrency: マイニング活動

**自動修復パターン**

```
GuardDuty Finding
    ↓
EventBridge Rule
    ↓
Lambda Function
    ↓
修復アクション（SG変更、インスタンス隔離等）
```

### AWS Security Hub

**機能**
- セキュリティアラートの集約
- コンプライアンススコアの可視化
- 自動修復ワークフロー

**セキュリティ標準**
- AWS Foundational Security Best Practices
- CIS AWS Foundations Benchmark
- PCI DSS
- NIST 800-53

**Finding形式**: ASFF（AWS Security Finding Format）

### Amazon Detective

**機能**
- GuardDuty Finding の詳細調査
- 関係性の可視化
- 時系列分析
- 影響範囲の特定

**データソース**
- VPC Flow Logs
- CloudTrail Logs
- GuardDuty Findings
- EKS監査ログ

### Amazon Macie

**機能**
- S3バケットの自動検出
- 機密データ分類
- PIIの検出
- ポリシー違反アラート

**データ識別子**
- 管理データ識別子: AWSが提供（クレジットカード番号等）
- カスタムデータ識別子: 正規表現ベースで定義

### CloudWatch Logs Insights

**セキュリティクエリ例**

```
# 失敗したログイン試行
fields @timestamp, @message
| filter eventName = 'ConsoleLogin' and errorCode = 'Failed'
| sort @timestamp desc
| limit 100
```

```
# ルートアカウント使用
fields @timestamp, userIdentity.type, eventName
| filter userIdentity.type = 'Root'
| sort @timestamp desc
```

---

## インシデント対応

### インシデント対応ライフサイクル

**フェーズ**
1. **準備**: ランブック、ロール、ツール整備
2. **検出・分析**: アラート確認、影響範囲特定
3. **封じ込め・根絶・復旧**: 隔離、修復、サービス復旧
4. **事後活動**: 根本原因分析、改善

### AWS環境でのベストプラクティス

**準備**
- フォレンジックアカウントの準備
- CloudTrail全リージョン有効化
- VPC Flow Logs有効化
- GuardDuty/Security Hub有効化

**検出・分析**
- CloudTrail Lake でクエリ
- Athena でログ分析
- Detective で関係性調査

**封じ込め**

| 対象 | アクション |
|------|----------|
| IAM認証情報漏洩 | キー無効化、ポリシー変更 |
| EC2侵害 | SG隔離、スナップショット取得 |
| S3データ流出 | パブリックアクセスブロック |

### EC2隔離手順

```
1. フォレンジック用SGを作成（全通信拒否）
2. 対象EC2のSGを隔離SGに変更
3. メモリダンプ取得（SSM Run Command）
4. EBSスナップショット作成
5. フォレンジックアカウントでボリューム復元・調査
```

### 自動対応パターン

**Systems Manager Incident Manager**
- 対応計画の定義
- エスカレーション設定
- ランブック自動実行

**Step Functions活用**
- 複雑な対応ワークフロー
- 人的承認ステップ
- 並列処理

---

## コンプライアンスとガバナンス

### AWS Config

**機能**
- 設定変更の記録
- コンプライアンス評価
- 自動修復

**Config vs CloudTrail**

| 観点 | Config | CloudTrail |
|------|--------|-----------|
| 記録対象 | WHAT changed | WHO changed, WHEN |
| 用途 | 設定ドリフト検出 | 監査証跡 |
| データ | 構成スナップショット | APIイベント |

**Conformance Packs**
- 事前定義されたルールセット
- HIPAA、PCI DSS等の標準対応
- マルチアカウント展開可能

### AWS Organizations

**Service Control Policies (SCP)**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLeaveOrganization",
      "Effect": "Deny",
      "Action": "organizations:LeaveOrganization",
      "Resource": "*"
    },
    {
      "Sid": "DenyDisableSecurityServices",
      "Effect": "Deny",
      "Action": [
        "guardduty:DeleteDetector",
        "securityhub:DisableSecurityHub",
        "cloudtrail:DeleteTrail"
      ],
      "Resource": "*"
    }
  ]
}
```

### AWS Artifact

**コンプライアンスレポート**
- SOC 1/2/3 レポート
- PCI DSS証明書
- ISO 27001証明書
- その他のコンプライアンス文書

### 規制フレームワーク対応

| 規制 | 対象業界 | 主要AWS対応サービス |
|------|---------|-------------------|
| GDPR | 全般（EU） | Macie, KMS, CloudTrail |
| HIPAA | 医療 | Config, CloudTrail, KMS |
| PCI DSS | 決済 | WAF, Shield, Config |
| FedRAMP | 政府（米国） | GovCloud |
| SOX | 上場企業 | CloudTrail, Config |

---

## DevSecOps

### CI/CDパイプラインセキュリティ

**シフトレフト戦略**

```
Plan → Code → Build → Test → Deploy → Operate
         ↑      ↑       ↑        ↑
      SAST   SCA   DAST   Runtime
```

**セキュリティツール統合**

| フェーズ | ツール/サービス |
|---------|---------------|
| コード分析 | CodeGuru Reviewer, SonarQube |
| 依存関係スキャン | Snyk, OWASP Dependency Check |
| コンテナスキャン | ECR Image Scanning, Trivy |
| IaC検証 | cfn-lint, tfsec, Checkov |
| 動的テスト | OWASP ZAP |

### シークレット管理

**Secrets Manager vs Parameter Store**

| 項目 | Secrets Manager | Parameter Store |
|------|----------------|-----------------|
| 自動ローテーション | あり | なし |
| RDS統合 | あり | なし |
| 料金 | シークレット/API課金 | Standard無料 |
| 用途 | DB認証情報、APIキー | 設定値全般 |

### IaCセキュリティ

**CloudFormation ガードレール**
- cfn-guard でポリシー検証
- CloudFormation StackSetsでマルチアカウント展開
- ドリフト検出で設定変更監視

**Terraform セキュリティ**
- tfsec でセキュリティスキャン
- Sentinel でポリシー適用（Enterprise）
- 状態ファイルのS3暗号化保存

### コンテナセキュリティ

**ECRイメージスキャン**
- 基本スキャン: CVEベース
- 拡張スキャン: Amazon Inspector統合

**ECS/EKSセキュリティ**
- タスクロール/Pod IAMの最小権限
- ネットワークポリシー
- シークレット注入（Secrets Manager統合）

---

## セキュリティベストプラクティスサマリー

### 必須設定チェックリスト

- [ ] 全リージョンでCloudTrail有効化
- [ ] S3バケットのパブリックアクセスブロック
- [ ] GuardDuty有効化
- [ ] Security Hub有効化
- [ ] Config有効化（必須ルール適用）
- [ ] ルートアカウントMFA有効化
- [ ] デフォルトVPC削除
- [ ] EBSデフォルト暗号化有効化

### 継続的改善

- 定期的なIAM Access Analyzer実行
- Trusted Advisorレビュー
- Security Hubスコア改善
- ペネトレーションテスト

---

## 関連リファレンス

- [SECURITY.md](./SECURITY.md) - IAM基本設計
- [NETWORKING.md](./NETWORKING.md) - ネットワークアーキテクチャ
- [SERVERLESS-PATTERNS.md](./SERVERLESS-PATTERNS.md) - サーバーレスセキュリティ
- [CDK.md](./CDK.md) - IaCセキュリティパターン
