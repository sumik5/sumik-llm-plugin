# プラットフォームエンジニアリング

ネットワーク設計、セキュリティ、マルチ環境管理、マルチチーム協調のベストプラクティスをカバーします。セキュリティ対策の詳細は `securing-code` スキルを、認可の詳細は `implementing-dynamic-authorization` スキルを、それぞれ参照してください。

---

## 1. ネットワーク設計

### VPC設計パターン（AWS例）

```
┌─────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)             │
│                                                  │
│  ┌────────────────────┐  ┌─────────────────────┐│
│  │ Public Subnet AZ-A │  │ Public Subnet AZ-B  ││
│  │ 10.0.1.0/24        │  │ 10.0.2.0/24         ││
│  │ [ALB, NAT Gateway] │  │ [ALB, NAT Gateway]  ││
│  └────────────────────┘  └─────────────────────┘│
│                                                  │
│  ┌────────────────────┐  ┌─────────────────────┐│
│  │ Private Subnet AZ-A│  │ Private Subnet AZ-B ││
│  │ 10.0.11.0/24       │  │ 10.0.12.0/24        ││
│  │ [App Servers, ECS] │  │ [App Servers, ECS]  ││
│  └────────────────────┘  └─────────────────────┘│
│                                                  │
│  ┌────────────────────┐  ┌─────────────────────┐│
│  │ Data Subnet AZ-A   │  │ Data Subnet AZ-B    ││
│  │ 10.0.21.0/24       │  │ 10.0.22.0/24        ││
│  │ [RDS, ElastiCache] │  │ [RDS, ElastiCache]  ││
│  └────────────────────┘  └─────────────────────┘│
└─────────────────────────────────────────────────┘
```

#### サブネット設計の原則

| 層 | 目的 | インターネット接続 | ルーティング |
|----|------|-------------------|-------------|
| **Public Subnet** | ロードバランサー、NAT Gateway | Internet Gateway経由で双方向 | IGW → Public Subnet |
| **Private Subnet** | アプリケーションサーバー、コンテナ | NAT Gateway経由で送信のみ | NAT → IGW |
| **Data Subnet** | データベース、キャッシュ | なし | VPC内部のみ |

#### マルチAZ設計

- **可用性**: 各サブネットを複数のAvailability Zoneに配置
- **冗長性**: NAT Gateway, ALBを複数AZに配置
- **自動フェイルオーバー**: RDS Multi-AZ, ElastiCache Cluster Mode

### DNS設計とサービスディスカバリ

| 手法 | ユースケース | ツール例 |
|------|------------|---------|
| **外部DNS** | パブリックアクセスのエンドポイント | Route 53, CloudFlare |
| **内部DNS** | VPC内部のサービス名前解決 | Route 53 Private Hosted Zone, CoreDNS |
| **サービスディスカバリ** | マイクロサービス間の動的エンドポイント発見 | AWS Cloud Map, Consul, Kubernetes Service Discovery |

### ロードバランサー選定

| タイプ | レイヤー | ユースケース | プロトコル | 特徴 |
|-------|---------|------------|-----------|------|
| **ALB** (Application Load Balancer) | L7（HTTP/HTTPS） | Webアプリケーション、マイクロサービス | HTTP, HTTPS, WebSocket | パスベースルーティング、ホストベースルーティング |
| **NLB** (Network Load Balancer) | L4（TCP/UDP） | 低レイテンシ、静的IP必要 | TCP, UDP, TLS | 高スループット、静的IP |
| **CLB** (Classic Load Balancer) | L4/L7 | レガシー（非推奨） | HTTP, HTTPS, TCP, SSL | 非推奨（ALB/NLBを使用） |

### VPN / PrivateLink / Transit Gateway

| 接続手法 | ユースケース | コスト | セキュリティ |
|---------|------------|-------|-------------|
| **Site-to-Site VPN** | オンプレミス ↔ クラウド接続 | 低 | IPsec暗号化 |
| **Client VPN** | リモートワーカー ↔ VPC | 中 | OpenVPN |
| **PrivateLink** | サービス間プライベート接続（インターネット非経由） | 中 | VPC内部通信 |
| **Transit Gateway** | 複数VPC、VPNの集約ハブ | 高 | 中央集権的ルーティング |

---

## 2. セキュリティ

### ゼロトラスト原則

**「境界防御」から「常時検証」へのパラダイムシフト**

| 従来（境界防御） | ゼロトラスト |
|----------------|-------------|
| VPN内部は信頼 | VPN内部も検証 |
| 一度認証すれば継続アクセス | 継続的な認証・認可 |
| ネットワークレベル制御 | アプリケーションレベル制御 |

**ゼロトラスト実装要素**:
1. **Identity-Based Access**: IAM, OIDC, SAML
2. **Device Trust**: デバイス証明書、MDM
3. **Continuous Verification**: セッション再検証、リスクベース認証
4. **Least Privilege**: 最小権限の原則
5. **Microsegmentation**: ネットワークを細かく分割

### IAMベストプラクティス

#### 最小権限の原則 (Principle of Least Privilege)

```json
// ❌ 悪い例: 過剰な権限
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "*"
}

// ✅ 良い例: 必要な権限のみ
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "arn:aws:s3:::my-bucket/app-data/*"
}
```

#### IAM設計チェックリスト

- [ ] ルートアカウントの使用禁止（管理者はIAMユーザー/ロールを使用）
- [ ] MFA有効化（特に管理者アカウント）
- [ ] 個人アカウントの使用（共有アカウント禁止）
- [ ] ポリシーのバージョン管理（IaCで管理）
- [ ] 定期的な権限監査（AWS IAM Access Analyzer等）
- [ ] サービスアカウントにはロール使用（長期認証情報を避ける）

### 認証と認可

#### 認証 (Authentication)

| 手法 | ユースケース | 特徴 |
|-----|------------|------|
| **OIDC** (OpenID Connect) | モダンなWebアプリ、SPA | OAuth 2.0拡張、IDトークン |
| **SAML 2.0** | エンタープライズSSO | XML署名、複雑 |
| **OAuth 2.0** | API認可、サードパーティ連携 | アクセストークンベース |
| **MFA** (Multi-Factor Authentication) | 追加セキュリティレイヤー | TOTP, SMS, Biometrics |

#### 認可 (Authorization)

| モデル | 説明 | ユースケース |
|-------|-----|------------|
| **RBAC** (Role-Based Access Control) | ロール（例: Admin, User, Guest）に権限を割当 | 組織構造が明確 |
| **ABAC** (Attribute-Based Access Control) | 属性（例: 部署、場所、時間）で動的判定 | 複雑なポリシー |
| **ReBAC** (Relationship-Based Access Control) | リソース間の関係（例: 所有者、共有者）で判定 | コラボレーションツール |

**詳細は `implementing-dynamic-authorization` スキル参照。**

### シークレット管理

#### 環境変数の危険性

| 保存場所 | リスク | 対策 |
|---------|-------|------|
| `.env` ファイル | Git誤コミット、平文保存 | `.gitignore` 登録、絶対にコミットしない |
| 環境変数（コンテナ） | プロセス一覧から読み取り可能 | シークレット管理ツール使用 |
| ハードコード | ソースコード漏洩時に露出 | 絶対に禁止 |

#### シークレット管理ツール

| ツール | 特徴 | ユースケース |
|-------|-----|------------|
| **HashiCorp Vault** | 動的シークレット生成、暗号化API | エンタープライズ、マルチクラウド |
| **AWS Secrets Manager** | AWS統合、自動ローテーション | AWS環境 |
| **AWS Systems Manager Parameter Store** | 無料、KMS統合 | 軽量ユースケース |
| **Google Secret Manager** | GCP統合 | GCP環境 |
| **Kubernetes Secrets** | K8s統合、Base64エンコード（暗号化なし） | 追加でSealed Secrets, External Secrets Operator使用 |

### 暗号化

| 暗号化タイプ | 説明 | 実装例 |
|------------|-----|-------|
| **At Rest** | ストレージの暗号化 | RDS暗号化、S3 SSE, EBS暗号化 |
| **In Transit** | 通信路の暗号化 | TLS/HTTPS, VPN |
| **End-to-End** | クライアント ↔ サーバー間の暗号化 | Signal Protocol, PGP |

#### TLS証明書管理

- **認証局 (CA)**: Let's Encrypt（無料、自動更新）、ACM（AWS Certificate Manager）
- **自動更新**: Cert-Manager（Kubernetes）、certbot
- **証明書有効期限監視**: Prometheus Exporter, Datadog

---

## 3. マルチ環境管理

### 環境分離パターン

```yaml
AskUserQuestion:
  質問: "環境分離戦略を選択してください"
  選択肢:
    - label: "アカウント分離（推奨）"
      特徴:
        - AWS/GCP/Azureの異なるアカウントで環境を分離
        - リソースの完全分離（IAM、ネットワーク）
        - 本番環境への誤操作防止
      推奨: "エンタープライズ、本番環境の厳格な分離"
    - label: "VPC分離"
      特徴:
        - 同一アカウント内で異なるVPCを使用
        - コスト削減、中程度の分離
        - IAMポリシーでリソースアクセス制御
      推奨: "中小規模、コスト重視"
    - label: "名前空間分離（Kubernetes）"
      特徴:
        - 同一クラスタ内でNamespaceを分離
        - リソースクォータ、RBAC
        - 軽量、開発環境向け
      推奨: "開発/ステージング環境のみ"
```

### 環境間の差異管理

| 差異要素 | 管理方法 | ツール |
|---------|---------|-------|
| **インフラパラメータ** | Terraform変数ファイル（`dev.tfvars`, `prod.tfvars`） | Terraform Workspaces, Terragrunt |
| **アプリケーション設定** | 環境変数、ConfigMap（K8s） | dotenv, AWS AppConfig |
| **シークレット** | 環境ごとに異なるシークレット | Vault, Secrets Manager |
| **リソースサイズ** | dev（小）、staging（中）、prod（大） | IaC変数 |

### Infrastructure as Codeによる環境再現性

**原則**: すべての環境をコードで定義し、差分を変数で管理

```hcl
# Terraform例
module "app" {
  source = "./modules/app"

  environment = var.environment  # dev/staging/prod
  instance_type = var.instance_type[var.environment]
  replicas = var.replicas[var.environment]
}
```

### 環境昇格フロー

```
┌─────────┐      ┌──────────┐      ┌──────────┐
│   Dev   │  →   │ Staging  │  →   │   Prod   │
└─────────┘      └──────────┘      └──────────┘
  自動デプロイ      手動承認          手動承認
  (PR merge)      (Smoke Test)     (最終確認)
```

| 環境 | デプロイタイミング | 承認 | テスト |
|-----|-------------------|-----|-------|
| **Dev** | PRマージ時 | 不要 | Unit/Integration |
| **Staging** | Dev成功後 | Tech Lead承認 | E2E, Performance |
| **Prod** | Staging成功後 | Product Owner承認 | Smoke Test, Canary |

---

## 4. マルチチーム協調

### コードオーナーシップモデル

| モデル | 説明 | メリット | デメリット |
|-------|-----|---------|----------|
| **Strong Ownership** | 各チームが特定のコンポーネントを完全所有 | 責任明確、深い専門知識 | サイロ化、他チームへの依存 |
| **Weak Ownership** | すべてのチームがすべてのコードを変更可能 | 柔軟性、ボトルネック解消 | 責任曖昧、知識分散 |
| **Collective Ownership** | コード所有者なし、全員が変更可能（XP） | 知識共有、迅速な修正 | 大規模組織では困難 |

**推奨**: Strong Ownership + CODEOWNERSファイル

```
# .github/CODEOWNERS
/frontend/**     @frontend-team
/backend/**      @backend-team
/infra/**        @platform-team
```

### Monorepo vs Polyrepo の判断基準

```yaml
AskUserQuestion:
  質問: "リポジトリ戦略を選択してください"
  選択肢:
    - label: "Monorepo"
      特徴:
        - 単一リポジトリで複数プロジェクト管理
        - 統一されたCI/CD、共有ライブラリの容易な更新
        - ツール: Turborepo, Nx, Bazel
      推奨:
        - チーム間の密な協調が必要
        - 共有コードの頻繁な変更
        - 統一されたツールチェーン
      デメリット: 大規模化でビルド遅延、アクセス制御困難
    - label: "Polyrepo"
      特徴:
        - プロジェクトごとに独立したリポジトリ
        - 独立したリリースサイクル
        - 明確な境界
      推奨:
        - チーム間の独立性が高い
        - 異なる技術スタック
        - マイクロサービスアーキテクチャ
      デメリット: 共有コードの更新が煩雑、一貫性維持が困難
```

### 共有ライブラリ・テンプレート

| 共有資産 | 目的 | 管理方法 |
|---------|-----|---------|
| **共有ライブラリ** | 共通ロジックの再利用 | npm private registry, Maven Nexus |
| **IaCテンプレート** | 標準インフラパターン | Terraform Modules, CloudFormation StackSets |
| **CI/CDテンプレート** | 標準パイプライン | GitHub Actions Reusable Workflow |
| **開発環境テンプレート** | ローカル環境セットアップ | devcontainer, Vagrant |

### Inner Source / Platform Team

#### Inner Source

- **定義**: オープンソースの手法を社内に適用
- **実践**: 他チームのリポジトリへのPR歓迎、ドキュメント公開、Issue管理
- **メリット**: サイロ化防止、知識共有

#### Platform Team

- **役割**: 開発チームが自律的にデプロイ・運用できるプラットフォームを提供
- **提供物**:
  - セルフサービスインフラ（IaCテンプレート、CI/CDパイプライン）
  - 共通サービス（認証、ログ、メトリクス）
  - ドキュメント、サポート
- **DevOps文化**: "You build it, you run it"を支えるインフラ

---

## 5. ネットワークアーキテクチャ選定フレームワーク

| 要件 | 推奨アーキテクチャ | ツール |
|-----|-------------------|-------|
| **シンプルなWeb + DB** | VPC（Public + Private Subnet）、ALB、RDS | AWS VPC, Terraform |
| **マイクロサービス** | Kubernetes + Service Mesh | EKS, Istio, Linkerd |
| **マルチリージョン** | Transit Gateway + Route 53 | AWS Global Accelerator |
| **オンプレ接続** | Site-to-Site VPN or Direct Connect | AWS VPN, Azure ExpressRoute |
| **ゼロトラスト** | Identity-Aware Proxy, BeyondCorp | Google IAP, Cloudflare Access |

---

## 6. 関連スキルとの差別化

| トピック | このスキル（practicing-devops） | 詳細スキル |
|---------|-------------------------------|-----------|
| **セキュリティ対策** | IAM、シークレット管理、暗号化の概要 | `securing-code`: コードレベルのセキュリティ実装 |
| **認可モデル** | RBAC/ABAC/ReBACの比較、選定基準 | `implementing-dynamic-authorization`: Cedar/ABAC実装詳細 |
| **インフラ実装** | ネットワーク・セキュリティ設計原則 | `developing-terraform`: Terraform HCL実装、モジュール開発 |

---

**次のセクション**:
- [CICD-PIPELINE.md](./CICD-PIPELINE.md): CI/CDパイプライン設計
- [DATA-OBSERVABILITY.md](./DATA-OBSERVABILITY.md): データストア・監視設計
