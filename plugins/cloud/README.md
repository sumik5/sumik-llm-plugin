# cloud

**クラウド・インフラ・アーキテクチャスキルのためのプラグイン**

---

## 概要

cloud は devkit と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。AWS・Google Cloud・Terraform・Firebase・DevOps・オブザーバビリティ・動的認可・Keycloak・インフラ設計・データ設計・マルチテナント SaaS といったクラウド/インフラ/アーキテクチャ系スキルを集約します。devkit のタチコマ Agent がこれらのスキルを `cloud:<skill>` 修飾名で preload するため、devkit と常にセットでインストールされる前提です。

---

## インストール

### Claude Code

```bash
/plugin install cloud@sumik
```

### Codex

```bash
codex plugin marketplace add https://github.com/sumik5/sumik-llm-plugin.git --ref main
codex plugin add cloud@sumik-marketplace
```

---

## ディレクトリ構成

```
sumik-llm-plugin/                      # GitHub repo（Codex はここを git clone）
├── .agents/
│   └── plugins/
│       └── marketplace.json              # Codex marketplace manifest（cloud エントリを含む）
├── .cache/
│   └── sumik-marketplace/
│       └── cloud -> ../../plugins/cloud    # Codex marketplace から cloud plugin を指す symlink
└── plugins/
    └── cloud/                          # Claude Code プラグイン本体（skills-only）
        ├── .claude-plugin/
        │   └── plugin.json              # プラグインメタデータ（plugin 名 cloud / version 同期必須）
        ├── .codex-plugin/
        │   └── plugin.json              # Codex CLI プラグインマニフェスト（skills ./skills/・MCP なし）
        ├── README.md
        └── skills/                      # ナレッジスキル (11個)
```

---

## コンポーネント一覧

### Skills (11個)

| スキル | 説明 |
|--------|------|
| `developing-aws` | AWS開発包括ガイド（システム設計・CDP57パターン・VPCアーキテクチャ・エンタープライズ基盤・移行戦略・サーバーレス・CDK・EKS・ECS/Fargate・SRE運用・FinOps/CCoE・セキュリティ（IAM/VPC/KMS/GuardDuty）・Bedrock GenAI・Cognito認証・HA/耐障害性） |
| `developing-google-cloud` | Google Cloud 開発・セキュリティ・データエンジニアリング・ネットワーク・キャッシング・エンタープライズアーキテクチャ包括ガイド（Cloud Run・IAM/VPC/KMS/Zero Trust・BigQuery分析/高度運用/ML・Dataflow・Looker・コンピューティング選択（GCE/GKE/GAE/Run/Functions）・GKE・SLO/SLI監視・レイクハウス・リアルタイム分析） |
| `developing-terraform` | Terraform/Terragrunt IaC開発（HCL・モジュール・ステート・Terragrunt・mise・AWS/GCP） |
| `developing-firebase` | Firebaseプラットフォーム開発ガイド（Authentication, Firestore, RTDB, Storage, Functions, Hosting, Analytics, FCM, Remote Config等） |
| `practicing-devops` | DevOps方法論・IaCツール選定・オーケストレーション比較・CI/CD・プラットフォームエンジニアリング・Docker/Podman管理 |
| `implementing-observability` | オブザーバビリティ統合ガイド（監視設計: アンチパターン・6層戦略・SLO・テレメトリーパイプライン・成熟度モデル ＋ OpenTelemetry実装: トレース/メトリクス/ログAPI・Collector・セマンティック規則 ＋ ログ設計: 構造化ログ・収集パイプライン・分析・セキュリティ ＋ オブザーバビリティエンジニアリング実践: コア分析ループ・デバッグ・ROI分析・CI/CD計装・高カーディナリティデータ） |
| `implementing-dynamic-authorization` | 動的認可設計（ABAC/ReBAC/PBAC、Cedar、認可アーキテクチャ） |
| `managing-keycloak` | Keycloak IAM包括ガイド（OIDC/SAML・SSO・Realm/Client/User管理・認証フロー・MFA・認可ポリシー・JWT Token管理・アプリ統合・Docker/K8sデプロイ・SPI拡張） |
| `architecting-infrastructure` | インフラデザインパターン127種 + アーキテクチャモダナイゼーション（トレードオフ分析） + マイクロサービスパターン（CQRS・Saga・粒度決定・データ所有権）。ベンダー非依存の設計方式選定・非機能要求分析 |
| `architecting-data` | データアーキテクチャパターン（Read-Side最適化、CQRS、CDC、Event Sourcing、キャッシュ戦略） |
| `building-multi-tenant-saas` | マルチテナントSaaSアーキテクチャ設計ガイド（デプロイモデル・テナント分離・データパーティショニング・silo/pool戦略・アイデンティティ・オンボーディング・ティアリング） |

---

## 依存関係メモ

devkit のクラウド/インフラ/アーキテクチャ系タチコマ（tachikoma-cloud-aws/gcp/infra/terraform、tachikoma-qa-observability/security、tachikoma-str-architecture/product-mgr、tachikoma-fw-fullstack-js ほか）が cloud 提供スキルを `cloud:<skill>` 修飾名で preload します。このクロスプラグイン参照を成立させるため、cloud は devkit と**常に併設インストールされること**が前提です。cloud 単体ではこれらのタチコマのスキル preload が解決されません。
