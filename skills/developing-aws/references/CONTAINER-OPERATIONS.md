# コンテナ運用リファレンス

コンテナCI/CD・レジストリ運用・ログ収集・セキュリティ・アクセス制御の実装パターン。

> **関連**: コンテナ設計は [CONTAINER-DESIGN.md](./CONTAINER-DESIGN.md)、CI/CD汎用は [DEVELOPER-TOOLS.md](./DEVELOPER-TOOLS.md)、ログ全般は [OBSERVABILITY.md](./OBSERVABILITY.md) を参照

---

## 目次

1. [コンテナCI/CDパイプライン](#コンテナcicdパイプライン)
2. [Blue/Greenデプロイメント](#bluegreen-デプロイメント)
3. [ECRリポジトリ管理](#ecr-リポジトリ管理)
4. [FireLensログルーティング](#firelens-ログルーティング)
5. [コンテナセキュリティスキャン](#コンテナセキュリティスキャン)
6. [Fargate Bastion](#fargate-bastion)
7. [WAFによるアプリケーション保護](#waf-によるアプリケーション保護)

---

## コンテナCI/CDパイプライン

### パイプライン構成

ECSコンテナのCI/CDはCodeシリーズ4サービスを組み合わせる。

```
CodeCommit → CodeBuild → CodeDeploy → ECS (Blue/Green)
(ソース)     (ビルド)    (デプロイ)
```

| ステージ | サービス | 役割 |
|---------|---------|------|
| Source | CodeCommit | ソースコード管理・変更検知（CloudWatch Events） |
| Build | CodeBuild | アプリビルド・コンテナイメージ作成・ECRプッシュ |
| Deploy | CodeDeploy (ECS) | Blue/Greenデプロイ・トラフィック切り替え |

### buildspec.yml（ECSコンテナ向け）

```yaml
version: 0.2

env:
  variables:
    AWS_REGION_NAME: ap-northeast-1
    ECR_REPOSITORY_NAME: my-app-backend
    DOCKER_BUILDKIT: "1"

phases:
  install:
    runtime-versions:
      docker: 19

  pre_build:
    commands:
      - AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
      - aws ecr --region ap-northeast-1 get-login-password | docker login --username AWS --password-stdin https://${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/${ECR_REPOSITORY_NAME}
      - REPOSITORY_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION_NAME}.amazonaws.com/${ECR_REPOSITORY_NAME}
      # タグ名にGitコミットハッシュ（先頭7文字）を利用
      - IMAGE_TAG=$(echo ${CODEBUILD_RESOLVED_SOURCE_VERSION} | cut -c 1-7)

  build:
    commands:
      - docker image build -t ${REPOSITORY_URI}:${IMAGE_TAG} .

  post_build:
    commands:
      - docker image push ${REPOSITORY_URI}:${IMAGE_TAG}
      # CodePipelineへ渡すイメージ情報JSON
      - printf '{"name":"%s","ImageURI":"%s"}' $ECR_REPOSITORY_NAME $REPOSITORY_URI:$IMAGE_TAG > imageDetail.json

artifacts:
  files:
    - imageDetail.json
    - appspec.yaml
    - taskdef.json
```

**フェーズ別役割**

| フェーズ | 処理内容 |
|---------|---------|
| install | ランタイム・ツールインストール（`runtime-versions`必須） |
| pre_build | ECRログイン、変数設定、依存解決 |
| build | Dockerビルド・テスト実行 |
| post_build | ECRプッシュ、アーティファクト生成 |

### appspec.yaml（ECS Blue/Green用）

```yaml
version: 1
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>   # パイプラインが自動置換
        LoadBalancerInfo:
          ContainerName: app
          ContainerPort: 80
```

> **ポイント**: `<TASK_DEFINITION>` はCodeDeployがデプロイ実行時に自動置換するプレースホルダー。ARNは記載しない。

### taskdef.json（タスク定義ファイル）

```json
{
  "executionRoleArn": "arn:aws:iam::[ACCOUNT_ID]:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "app",
      "image": "<IMAGE1_NAME>",
      "essential": true,
      "readonlyRootFilesystem": true,
      "cpu": 256,
      "memoryReservation": 512,
      "portMappings": [
        { "hostPort": 80, "protocol": "tcp", "containerPort": 80 }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/my-app-backend-def",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "secrets": [
        {
          "name": "DB_HOST",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:[ACCOUNT_ID]:secret:[SECRET_NAME]:host::"
        }
      ]
    }
  ],
  "family": "my-app-backend-def",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024"
}
```

> **ポイント**: `<IMAGE1_NAME>` はCodePipelineのデプロイステージが `imageDetail.json` の内容で自動置換。`readonlyRootFilesystem: true` でルートFSへの書き込みを禁止（セキュリティ強化）。

### IAM権限設定

**CodeBuild用IAMロールへ追加が必要なポリシー**

| アクセス先 | 必要な権限 |
|-----------|---------|
| ECR | `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, `ecr:PutImage` 等 |
| CloudWatch Logs | `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` |

### Docker Hub レート制限対策

CodeBuildがDocker Hubからイメージ取得時に `Too Many Requests` が発生する場合の対策。

| 対策 | 説明 | 推奨 |
|------|------|------|
| Docker Hub認証 | `docker login` で1ユーザー200回/6h | 小規模組織向け |
| ECRにベースイメージ格納 | Docker Hubを経由しない | 組織規模問わず推奨 |
| VPC内でCodeBuild起動 | 専用IP使用でIP競合を回避 | 大規模組織向け |

**ECRへのベースイメージ格納例**

```bash
# Docker Hubからイメージ取得
docker image pull golang:1.16.8-alpine3.13

# ECRへ格納（sbcntr-baseリポジトリを事前作成）
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
docker image tag golang:1.16.8-alpine3.13 \
  ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/base:golang1.16.8-alpine3.13
docker image push \
  ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/base:golang1.16.8-alpine3.13
```

Dockerfile内でECRのイメージを参照：

```dockerfile
# Before（Docker Hub経由）
FROM golang:1.16.8-alpine3.13 AS build-env

# After（ECR経由）
FROM [ACCOUNT_ID].dkr.ecr.ap-northeast-1.amazonaws.com/base:golang1.16.8-alpine3.13 AS build-env
```

---

## Blue/Green デプロイメント

### ECS + CodeDeploy連携の仕組み

```
ECSサービス作成時にCodeDeployアプリ・デプロイグループが自動生成される
                                      ↓
コード変更 → CodePipeline実行 → CodeBuild → ECRプッシュ
                                      ↓
                              CodeDeploy (Blue/Green)
                              ├── Blue（現行タスクセット）
                              └── Green（新タスクセット）
                                         ↓
                              テストリスナー(10080)で検証
                                         ↓
                              本番トラフィック(80)を切り替え
                                         ↓
                              Blue（旧タスク）を終了
```

### ALBリスナー設定

| リスナー | ポート | 用途 |
|---------|------|------|
| プロダクションリスナー | 80 (HTTP) | 本番トラフィック |
| テストリスナー | 10080 (HTTP) | 切り替え前の内部テスト |

ターゲットグループは2つ（Blue/Green）必要：

| ターゲットグループ | 役割 |
|----------------|------|
| `my-tg-blue` | 現行タスクセット |
| `my-tg-green` | 新タスクセット（切り替え先） |

### デプロイ設定

| 設定項目 | 設定値 | 説明 |
|---------|--------|------|
| デプロイメント設定 | `CodeDeployDefault.ECSAllAtOnce` | 一括切り替え（Canary/Linearも選択可） |
| トラフィック再ルーティング | 10分待機 | 切り替え前に猶予時間を設ける |
| 元タスクセット終了待機 | 1時間 | ロールバック可能な猶予時間 |

### デプロイフロー（CodeDeploy画面）

```
ステップ1: 置換タスクセットのデプロイ  → Green起動
ステップ2: テストトラフィックルーティング → テストリスナーへ接続
ステップ3: 待機（N分）               → 内部テスト実施可能
ステップ4: 本番トラフィック再ルーティング → Greenへ切り替え
ステップ5: 待機（1時間）             → ロールバック可能期間
ステップ6: 元タスクセットの終了       → Blue削除
```

**ロールバック**: ステップ5完了前に「デプロイを停止してロールバック」で即時復旧可能。

### ECSサービス更新時の注意点

```bash
# 強制デプロイフラグが必要
# （同じタスク定義でも新しいデプロイを実行する場合）
aws ecs update-service \
  --cluster my-cluster \
  --service my-service \
  --force-new-deployment
```

---

## ECR リポジトリ管理

### イメージプッシュ・プル

```bash
# ECR認証（トークン有効期限: 12時間）
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin \
    https://${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com

# タグ付け（コミットハッシュを使用）
IMAGE_TAG=$(git rev-parse --short HEAD)
docker image tag myapp:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/myapp:${IMAGE_TAG}

# プッシュ
docker image push \
  ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/myapp:${IMAGE_TAG}
```

### ECRリポジトリ設定（セキュリティ強化）

| 設定 | 推奨値 | 効果 |
|------|------|------|
| タグのイミュータビリティ | 有効 | 同一タグでの上書きを禁止。デプロイの一貫性を保証 |
| プッシュ時スキャン | 有効 | プッシュ直後に脆弱性スキャン自動実行（追加費用なし） |
| 暗号化 | SSE-KMS or SSE-S3 | 保存イメージの暗号化 |

**AWS CLIで設定**

```bash
aws ecr put-image-scanning-configuration \
  --repository-name myapp \
  --image-scanning-configuration scanOnPush=true

aws ecr put-image-tag-mutability \
  --repository-name myapp \
  --image-tag-mutability IMMUTABLE
```

### ライフサイクルポリシー

イメージの自動削除で保存コストを最適化する。

**基本パターン（世代数ベース）**

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "古い世代のイメージを削除",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": { "type": "expire" }
    }
  ]
}
```

**マルチ環境での設計（タグプレフィックス分離）**

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "prod環境は過去10世代を保持",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["prod-"],
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 2,
      "description": "staging環境は過去5世代を保持",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["stg-"],
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": { "type": "expire" }
    }
  ]
}
```

> **設計ポイント**: 環境ごとにタグプレフィックスを分離しないと、stgのライフサイクルポリシーがprodイメージを巻き込んで削除するリスクがある。

### VPCエンドポイント（プライベートサブネット環境）

| エンドポイント名 | サービス名 | 用途 |
|--------------|---------|------|
| vpce-ecr-api | `com.amazonaws.<region>.ecr.api` | ECR API操作 |
| vpce-ecr-dkr | `com.amazonaws.<region>.ecr.dkr` | Dockerイメージ転送 |
| vpce-s3 | `com.amazonaws.<region>.s3` | イメージレイヤーのS3転送 |

---

## FireLens ログルーティング

### アーキテクチャ

FireLensはFluent Bit（または Fluentd）をサイドカーコンテナとして動作させ、ECSタスクのログをルーティングする。

```
ECSタスク
├── app コンテナ
│   └── stdout → (awsfirelens ドライバー)
└── log_router コンテナ（FireLens）
    ├── [FILTER] ログパース
    ├── [STREAM_TASK] タグ付与
    ├── [OUTPUT] → CloudWatch Logs
    └── [OUTPUT] → S3
```

### Fluent Bit設定ファイル群

**myparsers.conf（パーサ定義）**

```conf
[PARSER]
Name json
Format json
```

**stream_processor.conf（ストリームタスク定義）**

```conf
[STREAM_TASK]
Name access
Exec CREATE STREAM access WITH (tag='access-log') AS
     SELECT * FROM TAG:'*-firelens-*'
     WHERE status >= 200 AND uri <> '/healthcheck';

[STREAM_TASK]
Name error
Exec CREATE STREAM error WITH (tag='error-log') AS
     SELECT * FROM TAG:'*-firelens-*'
     WHERE status >= 400 and status < 600;
```

**fluent-bit-custom.conf（メイン設定）**

```conf
[SERVICE]
    Parsers_File /fluent-bit/myparsers.conf
    Streams_File /fluent-bit/stream_processor.conf

[FILTER]
    Name parser
    Match *-firelens-*
    Key_Name log
    Parser json
    Reserve_Data true

[OUTPUT]
    Name cloudwatch
    Match access-log
    region ${AWS_REGION}
    log_group_name ${LOG_GROUP_NAME}
    log_stream_prefix from-fluentbit/
    auto_create_group true

[OUTPUT]
    Name cloudwatch
    Match error-log
    region ${AWS_REGION}
    log_group_name ${LOG_GROUP_NAME}
    log_stream_prefix from-fluentbit/
    auto_create_group true

[OUTPUT]
    Name s3
    Match access-log
    region ${AWS_REGION}
    bucket ${LOG_BUCKET_NAME}
    total_file_size 1M
    upload_timeout 1m
```

**Dockerfile（カスタムFluent Bitイメージ）**

```dockerfile
FROM amazon/aws-for-fluent-bit:2.16.1

COPY ./fluent-bit-custom.conf /fluent-bit/custom.conf
COPY ./myparsers.conf /fluent-bit/myparsers.conf
COPY ./stream_processor.conf /fluent-bit/stream_processor.conf

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
```

### ECSタスク定義への組み込み

**FireLens設定（taskdef.json に追記）**

```json
{
  "containerDefinitions": [
    {
      "name": "app",
      "logConfiguration": {
        "logDriver": "awsfirelens"
      }
    },
    {
      "name": "log_router",
      "image": "[ACCOUNT_ID].dkr.ecr.ap-northeast-1.amazonaws.com/base:log-router",
      "essential": true,
      "cpu": 64,
      "memoryReservation": 128,
      "environment": [
        { "name": "APP_ID", "value": "my-app" },
        { "name": "AWS_REGION", "value": "ap-northeast-1" },
        { "name": "LOG_BUCKET_NAME", "value": "my-log-bucket" },
        { "name": "LOG_GROUP_NAME", "value": "/aws/ecs/my-app-def" }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/aws/ecs/firelens-container",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "firelens"
        }
      },
      "firelensConfiguration": {
        "type": "fluentbit",
        "options": {
          "config-file-type": "file",
          "config-file-value": "/fluent-bit/custom.conf"
        }
      }
    }
  ]
}
```

### タスクロール（IAMポリシー）

FireLensがS3とCloudWatch Logsへ書き込むためにタスクロールへアタッチ。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::my-log-bucket",
        "arn:aws:s3:::my-log-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

### S3出力のディレクトリ構造

```
my-log-bucket/
└── fluent-bit-logs/
    └── access-log/
        └── 2024/01/15/11/40/
            └── {ランダムなファイル名}  ← JSONログ
```

### Fluent Bit vs CloudWatch Logs Agent 比較

| 観点 | Fluent Bit (FireLens) | CloudWatch Logs Agent |
|------|---------------------|----------------------|
| ルーティング先 | 複数（CW Logs, S3, OpenSearch等） | CloudWatch Logs のみ |
| フィルタリング | ストリームタスクで柔軟に設定 | 限定的 |
| オーバーヘッド | 小（Go製軽量コンテナ） | 中 |
| 設定複雑度 | 高（confファイル） | 低 |

---

## コンテナセキュリティスキャン

### スキャンツールの役割分担

| ツール | 対象 | 検出内容 |
|-------|------|---------|
| **ECR組み込みスキャン（Clair）** | ECRへのプッシュ | OSパッケージの脆弱性（CVE） |
| **Trivy** | ビルド済みイメージ | OSパッケージ + アプリ依存ライブラリの脆弱性 |
| **Dockle** | ビルド済みイメージ | Dockerベストプラクティス違反（CIS Benchmark） |

### Trivyの特長

- スキャン対象が広い: OS + pip/gem/npm/yarn の依存関係もカバー
- 対応OS: Alpine, RHEL, CentOS, Debian, Ubuntu, Amazon Linux 等
- CI/CD組み込みが容易（コマンド1行）
- JSON出力でSecurity Hubへの連携が可能

### buildspec.yml へのTrivy/Dockle統合

```yaml
phases:
  pre_build:
    commands:
      # Trivy インストール
      - TRIVY_VERSION=$(curl -sS https://api.github.com/repos/aquasecurity/trivy/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
      - rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.rpm
      # Dockle インストール
      - DOCKLE_VERSION=$(curl -sS https://api.github.com/repos/goodwithtech/dockle/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
      - rpm -ivh https://github.com/goodwithtech/dockle/releases/download/v${DOCKLE_VERSION}/dockle_${DOCKLE_VERSION}_Linux-64bit.rpm

  build:
    commands:
      - docker image build -t ${REPOSITORY_URI}:${IMAGE_TAG} .

  post_build:
    commands:
      # Trivy 1回目: 全脆弱性を記録（exit-code 0 = ビルド継続）
      - trivy --no-progress -f json -o trivy_results.json --exit-code 0 ${REPOSITORY_URI}:${IMAGE_TAG}

      # Trivy 2回目: CRITICAL検出でビルド中止（1回目のキャッシュ利用で高速）
      - trivy --no-progress --exit-code 1 --severity CRITICAL ${REPOSITORY_URI}:${IMAGE_TAG}
      - exit `echo $?`

      # Dockle: FATALレベルの問題がある場合はビルド中止
      - dockle --format json -o dockle_results.json --exit-code 1 --exit-level "FATAL" ${REPOSITORY_URI}:${IMAGE_TAG}
      - exit `echo $?`

      # チェック通過後にECRへプッシュ
      - docker image push ${REPOSITORY_URI}:${IMAGE_TAG}
      - printf '{"name":"%s","ImageURI":"%s"}' $ECR_REPOSITORY_NAME $REPOSITORY_URI:$IMAGE_TAG > imageDetail.json

artifacts:
  files:
    - imageDetail.json
    - trivy_results.json
    - dockle_results.json
```

### 深刻度レベルと対応方針

**Trivy 深刻度**

| レベル | 対応方針（例） |
|-------|-------------|
| CRITICAL | ビルド中止・即時対応必須 |
| HIGH | 次スプリントまでに対応 |
| MEDIUM | 計画的に対応 |
| LOW | 許容またはリスク受容 |

**Dockle 深刻度**

| レベル | 対応方針（例） |
|-------|-------------|
| FATAL | ビルド中止・即時修正 |
| WARN | 改善推奨 |
| INFO | 情報として記録 |

### ECRプッシュ時スキャン（Clair）

```bash
# スキャン結果確認
aws ecr describe-image-scan-findings \
  --repository-name myapp \
  --image-id imageTag=v1.0.0

# 特定イメージの手動スキャン開始（1日1回まで）
aws ecr start-image-scan \
  --repository-name myapp \
  --image-id imageTag=v1.0.0
```

### 継続的スキャンの設計

CI/CDパイプライン実行時のみのスキャンでは、脆弱性情報の日々の更新に追従できない。

```
定期スキャン構成（推奨）:
CloudWatch Events (EventBridge) → Lambda → aws ecr start-image-scan → 結果をSNS通知
```

### Security Hub連携

TrivyとDockleはJSONで結果出力 → ASFF（Amazon Security Finding Format）に変換 → Security Hubへインポート。

---

## Fargate Bastion

### 従来型 vs Fargate Bastion

| 観点 | 従来型Bastion（EC2） | Fargate Bastion |
|------|------------------|----------------|
| 維持コスト | 常時稼働（24時間課金） | 必要時のみ起動（短時間課金） |
| パッチ適用 | 定期的なOSパッチ必要 | コンテナイメージ更新のみ |
| 公開ポート | SSH 22番ポート開放が必要 | ポート不要（Session Manager） |
| ログ | 別途設定 | Session Managerで自動記録 |
| セキュリティグループ | インバウンド許可必要 | インバウンド不要 |

### 構成図

```
運用者端末（マネジメントコンソール / AWS CLI）
       ↓ Session Manager
Systems Manager (ssm / ssmmessages)
       ↓ VPCエンドポイント経由
ECSタスク（Fargate Bastion コンテナ）
       ↓
Aurora / RDS など（プライベートサブネット）
```

### Fargate Bastion コンテナイメージ

```dockerfile
FROM amazonlinux:2
RUN yum install -y sudo jq awscli shadow-utils htop lsof telnet bind-utils yum-utils && \
    yum install -y https://s3.ap-northeast-1.amazonaws.com/amazon-ssm-ap-northeast-1/latest/linux_amd64/amazon-ssm-agent.rpm && \
    yum install -y mysql-community-client && \
    adduser ssm-user && \
    echo "ssm-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ssm-agent-users && \
    mv /etc/amazon/ssm/amazon-ssm-agent.json.template /etc/amazon/ssm/amazon-ssm-agent.json && \
    mv /etc/amazon/ssm/ssm-seelog.xml.template /etc/amazon/ssm/seelog.xml
COPY run.sh /run.sh
CMD ["sh", "/run.sh"]
```

**起動シェル（run.sh）の処理フロー**

```bash
#!/bin/sh
SSM_SERVICE_ROLE_NAME="my-SSMServiceRole"
AWS_REGION="ap-northeast-1"

# 1. SSMアクティベーションコードを発行
aws ssm create-activation \
  --description "Activation Code for Fargate Bastion" \
  --default-instance-name bastion \
  --iam-role ${SSM_SERVICE_ROLE_NAME} \
  --registration-limit 1 \
  --region ${AWS_REGION} | tee code.json

# 2. アクティベーションコードでSSMエージェントを登録
SSM_ACTIVATION_ID=$(cat code.json | jq -r .ActivationId)
SSM_ACTIVATION_CODE=$(cat code.json | jq -r .ActivationCode)
amazon-ssm-agent -register -code "${SSM_ACTIVATION_CODE}" -id "${SSM_ACTIVATION_ID}" -region ${AWS_REGION}

# 3. アクティベーションコードを削除（使い捨て）
aws ssm delete-activation --activation-id ${SSM_ACTIVATION_ID}

# 4. SSMエージェントを起動（常駐）
amazon-ssm-agent
```

### IAM設定

**ECSタスクロールへアタッチするポリシー**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "*",
      "Condition": {
        "StringEquals": { "iam:PassedToService": "ssm.amazonaws.com" }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:DeleteActivation",
        "ssm:CreateActivation",
        "ssm:AddTagsToResource",
        "ssm:RemoveTagsFromResource"
      ],
      "Resource": "*"
    }
  ]
}
```

**Systems Manager用サービスロール**

| 設定項目 | 値 |
|---------|--|
| 信頼エンティティ | Systems Manager |
| アタッチポリシー | `AmazonSSMManagedInstanceCore` |
| ロール名 | `my-SSMServiceRole`（run.sh内で参照） |

### VPCエンドポイント

| エンドポイント名 | サービス名 | 用途 |
|--------------|---------|------|
| vpce-ssm | `com.amazonaws.<region>.ssm` | SSM API（アクティベーション作成等） |
| vpce-ssm-messages | `com.amazonaws.<region>.ssmmessages` | Session Managerのセッション確立 |

> **注意**: Fargate v1.4.0以降ではタスクENIを使用するため、VPCエンドポイントが必須。

### アドバンスドインスタンスティア

Session Managerでオンプレミス/非EC2インスタンスに接続するにはアドバンスドティアへの変更が必要。

```
Systems Manager > フリートマネージャー > 設定 > インスタンスティア → アドバンスド
```

### 接続手順

```bash
# AWS CLIからSession Managerで接続
aws ssm start-session --target mi-<managed-instance-id>

# マネジメントコンソール:
# Systems Manager > セッションマネージャー > セッションを開始
```

---

## WAF によるアプリケーション保護

### WAFの構成要素

| コンポーネント | 説明 |
|------------|------|
| **ルール** | 個別の検査条件定義（IPアドレス、ヘッダー、パラメータ等） |
| **ルールグループ** | ルールの集合。WCU上限(1500)内で設定 |
| **ウェブACL** | ルールグループとAWSリソース（ALB/CloudFront/API GW）の紐付け |

**WCU（WAF Capacity Unit）の注意点**

- ルールグループのWCU上限は作成後に変更不可
- ウェブACL全体のWCU上限は1500
- Global（CloudFront用）とRegional（ALB/API GW用）を混在させると紐付け不可

### AWSマネージドルールグループ（推奨5種）

| マネージドルール | WCU | 保護対象 |
|--------------|-----|---------|
| `AWSManagedRulesCommonRuleSet` | 700 | XSS, 不審なUser-Agent等のWebアプリ一般攻撃 |
| `AWSManagedRulesAmazonIpReputationList` | 25 | 脅威IPリスト（AWSが管理）からのアクセス |
| `AWSManagedRulesAnonymousIpList` | 50 | Tor/VPN/プロキシ等の匿名化IP |
| `AWSManagedRulesKnownBadInputsRuleSet` | 200 | 不正な入力（localhostヘッダー等） |
| `AWSManagedRulesSQLiRuleSet` | 200 | SQLインジェクション |
| **合計** | **1175** | 1500WCU以内 |

### ルール適用優先順位（推奨）

```
1. AWSManagedRulesCommonRuleSet       （XSS等の基本攻撃）
2. AWSManagedRulesAmazonIpReputationList （脅威IP）
3. AWSManagedRulesAnonymousIpList    （匿名化IP）
4. AWSManagedRulesKnownBadInputsRuleSet （不正インプット）
5. AWSManagedRulesSQLiRuleSet        （SQLi）
デフォルトアクション: Allow（全ルール非該当のリクエストを許可）
```

### ウェブACL設定のポイント

| 設定項目 | 値 | 理由 |
|---------|--|------|
| リソースタイプ | Regional | ALB/API GW用。CloudFrontはGlobal |
| 紐付け先 | インターネット向けALB | 内部ALBには不要 |
| デフォルトアクション | Allow | ルール非該当を通過させる |

### 保護確認テスト

```bash
# 通常リクエスト（通過すること）
curl http://[ALB_DNS]/api/v1/items

# SQLインジェクション（403 Forbidden になること）
curl "http://[ALB_DNS]/api?id='foo' or 'A'='A'"

# XSS（403 Forbidden になること）
curl "http://[ALB_DNS]/api?name=<script>alert(document.cookie)</script>"
```

ブロックされたリクエストはWAFダッシュボードの「サンプルリクエスト」で確認可能。

### CloudFront + WAF 構成との違い

| 観点 | ALB + WAF | CloudFront + WAF |
|------|----------|----------------|
| スコープ | Regional | Global |
| レイテンシ改善 | なし | あり（エッジキャッシュ） |
| 設定の簡易さ | 高 | 中 |
| 適用対象 | 特定リージョンのALB | グローバルCDN |

---

## 関連リファレンス

- [CONTAINER-DESIGN.md](./CONTAINER-DESIGN.md) - ECS/Fargateアーキテクチャ設計
- [DEVELOPER-TOOLS.md](./DEVELOPER-TOOLS.md) - CodePipeline/CodeBuild/CodeDeploy汎用設定
- [OBSERVABILITY.md](./OBSERVABILITY.md) - CloudWatch Container Insights、X-Ray
- [SECURITY.md](./SECURITY.md) - IAM・KMS・GuardDuty・Security Hub
- [SERVERLESS-PATTERNS.md](./SERVERLESS-PATTERNS.md) - Lambda活用パターン（定期スキャンLambda等）
