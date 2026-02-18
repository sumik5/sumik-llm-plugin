# AWS Developer Tools リファレンス

アプリケーション開発者向けのAWS開発ツールとサービス。

> **関連**: サーバーレスは [SERVERLESS-PATTERNS.md](./SERVERLESS-PATTERNS.md)、IaCは [CDK.md](./CDK.md) を参照

---

## 目次

1. [CI/CDサービス](#cicdサービス)
2. [デプロイメント戦略](#デプロイメント戦略)
3. [設定管理とシークレット](#設定管理とシークレット)
4. [コンテナサービス](#コンテナサービス)
5. [アプリケーションサービス](#アプリケーションサービス)
6. [監視とデバッグ](#監視とデバッグ)
7. [SDK・CLIツール](#sdkcliツール)

---

## CI/CDサービス

### AWS CodeCommit

**特徴**
- フルマネージドGitリポジトリ
- IAM統合認証
- 暗号化（保存時・転送時）
- CodePipeline連携

**接続方法**

| 方式 | 認証 |
|------|------|
| HTTPS | IAM認証情報ヘルパー |
| SSH | IAMユーザーにSSHキー登録 |
| HTTPS (GRC) | Git Credential Helper |

### AWS CodeBuild

**特徴**
- サーバーレスビルドサービス
- Docker環境でのビルド
- buildspec.ymlによる定義
- 分単位課金

**buildspec.yml構造**

```yaml
version: 0.2
phases:
  install:
    runtime-versions:
      nodejs: 18
    commands:
      - npm install
  pre_build:
    commands:
      - npm run lint
  build:
    commands:
      - npm run build
  post_build:
    commands:
      - npm run test
artifacts:
  files:
    - '**/*'
  base-directory: dist
cache:
  paths:
    - node_modules/**/*
```

**環境変数**

| ソース | 説明 |
|--------|------|
| Plaintext | 平文（非推奨） |
| Parameter Store | SSMパラメータ参照 |
| Secrets Manager | シークレット参照 |

### AWS CodeDeploy

**デプロイ先**

| プラットフォーム | 説明 |
|----------------|------|
| EC2/On-premises | インスタンスへのデプロイ |
| Lambda | 関数のエイリアス更新 |
| ECS | タスク定義更新 |

**appspec.yml（EC2）**

```yaml
version: 0.0
os: linux
files:
  - source: /
    destination: /var/www/html
hooks:
  BeforeInstall:
    - location: scripts/before_install.sh
      timeout: 300
  AfterInstall:
    - location: scripts/after_install.sh
      timeout: 300
  ApplicationStart:
    - location: scripts/start_server.sh
      timeout: 300
  ValidateService:
    - location: scripts/validate_service.sh
      timeout: 300
```

**ライフサイクルフック（EC2）**
1. ApplicationStop
2. DownloadBundle
3. BeforeInstall
4. Install
5. AfterInstall
6. ApplicationStart
7. ValidateService

### AWS CodePipeline

**特徴**
- CI/CDオーケストレーション
- ステージベースのパイプライン
- 他AWSサービス統合
- サードパーティ統合（GitHub、Jenkins等）

**パイプライン構造**
```
Source → Build → Test → Deploy
```

**アクションカテゴリ**

| カテゴリ | サービス例 |
|---------|----------|
| Source | CodeCommit, GitHub, S3 |
| Build | CodeBuild, Jenkins |
| Test | CodeBuild, Device Farm |
| Deploy | CodeDeploy, ECS, Lambda |
| Approval | Manual Approval |
| Invoke | Lambda, Step Functions |

### AWS CodeArtifact

**特徴**
- パッケージリポジトリ
- npm, pip, Maven, NuGet対応
- アップストリームリポジトリ連携
- IAM認証

---

## デプロイメント戦略

### 比較

| 戦略 | ダウンタイム | ロールバック | リソース |
|------|------------|------------|---------|
| In-place | あり | 手動 | 既存 |
| Rolling | 最小 | 手動 | 既存 |
| Rolling with batch | 最小 | 手動 | 既存 |
| Blue/Green | なし | 即時 | 2倍 |
| Canary | なし | 即時 | 追加 |
| Linear | なし | 即時 | 追加 |

### Blue/Green

**特徴**
- 2つの同一環境
- トラフィック切り替え
- 即時ロールバック可能
- EC2, ECS, Lambda対応

**Route 53との連携**
- 加重ルーティングで段階移行
- フェイルオーバーで自動切り替え

### Canary

**Lambda/ECSでの設定例**
- `Canary10Percent5Minutes`: 10%→5分後100%
- `Canary10Percent10Minutes`: 10%→10分後100%
- `Canary10Percent15Minutes`: 10%→15分後100%

### Linear

**Lambda/ECSでの設定例**
- `Linear10PercentEvery1Minute`: 毎分10%追加
- `Linear10PercentEvery3Minutes`: 3分ごと10%追加

---

## 設定管理とシークレット

### AWS Systems Manager Parameter Store

**特徴**
- 階層的パラメータ管理
- 暗号化（SecureString）
- バージョン管理
- IAMによるアクセス制御

**パラメータタイプ**

| タイプ | 説明 | 最大サイズ |
|--------|------|----------|
| String | 平文文字列 | 4KB (Standard) |
| StringList | カンマ区切り | 4KB |
| SecureString | KMS暗号化 | 4KB/8KB |

**階層構造**
```
/myapp/
  ├── prod/
  │   ├── db/connection-string
  │   └── api/key
  └── dev/
      ├── db/connection-string
      └── api/key
```

**ティア比較**

| 項目 | Standard | Advanced |
|------|----------|----------|
| 最大サイズ | 4KB | 8KB |
| パラメータ数上限 | 10,000 | 100,000 |
| パラメータポリシー | なし | あり |
| 料金 | 無料 | 有料 |

### AWS Secrets Manager

**特徴**
- 自動ローテーション
- RDS/Redshift/DocumentDB統合
- クロスアカウント共有
- CloudFormation統合

**Parameter Store vs Secrets Manager**

| 観点 | Parameter Store | Secrets Manager |
|------|-----------------|-----------------|
| 自動ローテーション | なし | あり |
| DB認証情報統合 | なし | あり |
| 料金 | Standard無料 | シークレット数課金 |
| 用途 | 設定値全般 | 認証情報 |

### AWS AppConfig

**特徴**
- アプリケーション設定のデプロイ
- 機能フラグ
- 段階的ロールアウト
- バリデーション

---

## コンテナサービス

### Amazon ECS

**起動タイプ**

| タイプ | 説明 |
|--------|------|
| EC2 | EC2インスタンス上で実行 |
| Fargate | サーバーレスコンテナ |
| External | オンプレミス |

**コンポーネント**

| コンポーネント | 説明 |
|--------------|------|
| Cluster | コンテナの論理グループ |
| Task Definition | コンテナ定義（イメージ、CPU、メモリ等） |
| Task | Task Definitionの実行インスタンス |
| Service | タスクの常時実行を保証 |

**タスク定義の主要設定**
- containerDefinitions: コンテナ設定
- cpu / memory: リソース割り当て
- executionRoleArn: タスク実行ロール
- taskRoleArn: タスクロール

### Amazon EKS

**特徴**
- Kubernetes完全互換
- コントロールプレーンはマネージド
- EC2 / Fargate ノード
- IAMとKubernetes RBACの統合

**ノードタイプ**

| タイプ | 説明 |
|--------|------|
| Managed Node Groups | AWSがノード管理 |
| Self-Managed Nodes | ユーザーがノード管理 |
| Fargate | サーバーレスPod |

### AWS Copilot

**特徴**
- ECS用CLIツール
- アプリケーション抽象化
- 環境管理（dev/prod）
- パイプライン自動生成

### Amazon ECR

**特徴**
- コンテナイメージレジストリ
- 脆弱性スキャン
- イメージ署名
- ライフサイクルポリシー

---

## アプリケーションサービス

### AWS Elastic Beanstalk

**特徴**
- PaaS（プラットフォーム即サービス）
- 自動プロビジョニング
- 複数言語/プラットフォーム対応
- カスタマイズ可能（.ebextensions）

**デプロイ戦略**

| 戦略 | 説明 | ダウンタイム |
|------|------|------------|
| All at once | 一括更新 | あり |
| Rolling | 順次更新 | 最小 |
| Rolling with additional batch | 追加バッチ付き | なし |
| Immutable | 新インスタンス作成 | なし |
| Traffic splitting | Canary的 | なし |

**環境タイプ**
- Web Server Environment: HTTPリクエスト処理
- Worker Environment: バックグラウンド処理（SQS）

### AWS Amplify

**特徴**
- フルスタック開発フレームワーク
- Hosting: 静的サイト/SSR
- Studio: ビジュアル開発
- Backend: 認証、API、ストレージ

**Amplify Hosting**
- Git連携の自動デプロイ
- プレビュー環境
- カスタムドメイン
- CI/CDパイプライン

### AWS App Runner

**特徴**
- ソースからデプロイ
- 自動スケーリング
- VPC接続
- カスタムドメイン

---

## 監視とデバッグ

### Amazon CloudWatch

**コンポーネント**

| コンポーネント | 説明 |
|--------------|------|
| Metrics | メトリクス収集・可視化 |
| Logs | ログ収集・分析 |
| Alarms | アラート通知 |
| Dashboards | ダッシュボード |
| Logs Insights | ログクエリ |
| Container Insights | コンテナ監視 |
| Lambda Insights | Lambda詳細監視 |

**カスタムメトリクス**
- PutMetricData API
- CloudWatch Agent
- EMF（Embedded Metric Format）

**メトリクス解像度**

| 解像度 | 間隔 | 保持期間 |
|--------|------|---------|
| Standard | 1分 | 15日 |
| High | 1秒 | 3時間 |

**アラーム状態**
- OK: しきい値以下
- ALARM: しきい値超過
- INSUFFICIENT_DATA: データ不足

### AWS X-Ray

**特徴**
- 分散トレーシング
- サービスマップ
- レイテンシ分析
- エラー分析

**コンポーネント**

| コンポーネント | 説明 |
|--------------|------|
| Segments | サービスの処理単位 |
| Subsegments | 外部呼び出し詳細 |
| Traces | リクエストの完全な経路 |
| Service Map | サービス間関係図 |

**サンプリングルール**
- Reservoir: 毎秒の固定サンプル数
- Rate: 超過分のサンプリング率

### CloudWatch Logs Insights

**クエリ例**
```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20
```

**主要コマンド**
- fields: 表示フィールド選択
- filter: フィルタリング
- stats: 集計
- sort: ソート
- limit: 結果数制限

---

## SDK・CLIツール

### AWS SDK

**主要言語**
- JavaScript/TypeScript (v3)
- Python (Boto3)
- Java (v2)
- Go (v2)
- .NET
- Ruby

**認証情報チェーン**
1. 環境変数
2. 共有認証情報ファイル
3. IAMロール（EC2/ECS/Lambda）

### AWS CLI

**設定ファイル**
- `~/.aws/credentials`: 認証情報
- `~/.aws/config`: 設定（リージョン等）

**プロファイル使用**
```bash
aws s3 ls --profile production
```

**出力形式**
- json（デフォルト）
- text
- table
- yaml

### AWS Cloud Development Kit (CDK)

**特徴**
- プログラミング言語でIaC
- L1/L2/L3コンストラクト
- CloudFormation生成

**詳細**: [CDK.md](./CDK.md) を参照

### AWS SAM

**特徴**
- サーバーレス特化のIaC
- ローカル開発/テスト
- sam build / sam deploy

**詳細**: [SERVERLESS-PATTERNS.md](./SERVERLESS-PATTERNS.md) を参照

---

## 開発ベストプラクティス

### 12-Factor App原則

| 原則 | AWSでの実装 |
|------|------------|
| コードベース | CodeCommit/GitHub |
| 依存関係 | CodeArtifact |
| 設定 | Parameter Store/Secrets Manager |
| バックエンドサービス | RDS, ElastiCache等 |
| ビルド/リリース/実行 | CodePipeline |
| プロセス | ECS/Lambda（ステートレス） |
| ポートバインディング | ALB, API Gateway |
| 並行性 | Auto Scaling |
| 廃棄容易性 | Fargate, Lambda |
| 開発/本番一致 | 同一CloudFormation/CDK |
| ログ | CloudWatch Logs |
| 管理プロセス | Lambda, ECS Task |

### セキュリティ

- IAMロールの使用（長期認証情報避ける）
- Secrets Managerでのシークレット管理
- VPC内でのリソース配置
- 暗号化（保存時・転送時）

---

## 関連リファレンス

- [SERVERLESS-PATTERNS.md](./SERVERLESS-PATTERNS.md) - Lambda、API Gateway等
- [CDK.md](./CDK.md) - CDKパターン
- [SYSTEM-DESIGN.md](./SYSTEM-DESIGN.md) - システム設計
- [SECURITY.md](./SECURITY.md) - セキュリティ
