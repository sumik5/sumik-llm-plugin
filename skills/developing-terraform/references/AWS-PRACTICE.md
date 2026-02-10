# AWS実践構築ガイド

TerraformによるAWSインフラの実践的な構築方法。

## 📋 目次

1. [事前準備](#事前準備)
2. [命名規則](#命名規則)
3. [ECSクラスター構築](#ecsクラスター構築)
4. [ECRリポジトリ管理](#ecrリポジトリ管理)
5. [ECSタスク定義](#ecsタスク定義)
6. [ECSサービス](#ecsサービス)
7. [CD（継続的デプロイ）](#cd継続的デプロイ)
8. [IAMガードレール設計](#iamガードレール設計)

---

## 事前準備

### IAMユーザー作成

Terraform操作用のIAMユーザーを作成:

```hcl
# iam-user.tf
resource "aws_iam_user" "terraform" {
  name = "terraform-operator"
  path = "/system/"

  tags = {
    Name        = "terraform-operator"
    Description = "Terraform操作用ユーザー"
  }
}

resource "aws_iam_user_policy_attachment" "terraform_admin" {
  user       = aws_iam_user.terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# アクセスキー作成（初回のみ）
resource "aws_iam_access_key" "terraform" {
  user = aws_iam_user.terraform.name
}

output "terraform_access_key_id" {
  value       = aws_iam_access_key.terraform.id
  description = "TerraformユーザーのAccess Key ID"
  sensitive   = true
}

output "terraform_secret_access_key" {
  value       = aws_iam_access_key.terraform.secret
  description = "TerraformユーザーのSecret Access Key"
  sensitive   = true
}
```

**注意:**
- アクセスキーは初回作成後、安全に保管
- 本番環境ではSCPやOIDCを推奨

---

### S3バックエンドの設定

ステート管理用のS3バケットとDynamoDBテーブルを作成:

```hcl
# backend-resources.tf
resource "aws_s3_bucket" "terraform_state" {
  bucket = "myapp-terraform-state"

  tags = {
    Name        = "myapp-terraform-state"
    Description = "Terraformステート管理用バケット"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "terraform-state-lock"
    Description = "Terraformステートロック管理用テーブル"
  }
}
```

**backend.tf の設定:**

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "myapp-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

---

### AWS認証情報の設定

#### パターンA: AWS CLI

```bash
aws configure
# AWS Access Key ID: (入力)
# AWS Secret Access Key: (入力)
# Default region name: ap-northeast-1
# Default output format: json
```

#### パターンB: 環境変数

```bash
export AWS_ACCESS_KEY_ID="AKIAXXXXXXXXXXXXXXXX"
export AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export AWS_DEFAULT_REGION="ap-northeast-1"
```

#### パターンC: プロファイル

```bash
# ~/.aws/credentials
[myapp-prod]
aws_access_key_id = AKIAXXXXXXXXXXXXXXXX
aws_secret_access_key = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

```hcl
# provider.tf
provider "aws" {
  region  = "ap-northeast-1"
  profile = "myapp-prod"
}
```

---

## 命名規則

### リソース命名パターン

```
${service_name}-${env}-${resource}
```

**例:**
- VPC: `myapp-dev-vpc`
- サブネット: `myapp-dev-public-a`
- ECSクラスター: `myapp-dev-cluster`

---

### terraform.workspaceの活用

```hcl
# variables.tf
variable "service_name" {
  type        = string
  description = "サービス名"
}

# locals.tf
locals {
  env           = terraform.workspace
  resource_name = "${var.service_name}-${local.env}"

  common_tags = {
    Service     = var.service_name
    Environment = local.env
    ManagedBy   = "Terraform"
  }
}

# vpc.tf
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_name}-vpc"
    }
  )
}
```

---

## ECSクラスター構築

### Fargateベースのクラスター

```hcl
# ecs-cluster.tf
resource "aws_ecs_cluster" "main" {
  name = "${var.service_name}-${var.env}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.service_name}-${var.env}-cluster"
    }
  )
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }
}
```

**ポイント:**
- `containerInsights`: CloudWatch Container Insightsを有効化
- FARGATE + FARGATE_SPOT: コスト最適化（base 1はFARGATE、残りはSPOT）

---

## ECRリポジトリ管理

### ECRリポジトリ作成

```hcl
# ecr.tf
resource "aws_ecr_repository" "app" {
  name                 = "${var.service_name}-${var.env}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.service_name}-${var.env}"
    }
  )
}
```

---

### ライフサイクルポリシー

未タグイメージを30日で削除:

```hcl
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "未タグイメージを30日で削除"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "タグ付きイメージを10個まで保持"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
```

---

### IAMポリシー（イメージプッシュ権限）

```hcl
# ecr-policy.tf
data "aws_iam_policy_document" "ecr_push" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_policy" "ecr_push" {
  name        = "${var.service_name}-${var.env}-ecr-push"
  description = "ECRイメージプッシュ権限"
  policy      = data.aws_iam_policy_document.ecr_push.json
}
```

---

## ECSタスク定義

### CPU/メモリ割り当て

Fargateの制約:

| vCPU | メモリ (GB) |
|------|------------|
| 0.25 | 0.5, 1, 2 |
| 0.5  | 1, 2, 3, 4 |
| 1    | 2, 3, 4, 5, 6, 7, 8 |
| 2    | 4 〜 16 (1GB刻み) |
| 4    | 8 〜 30 (1GB刻み) |

---

### タスクロール / 実行ロール

```hcl
# ecs-task-role.tf

# タスクロール（アプリケーションがAWSリソースにアクセス）
resource "aws_iam_role" "ecs_task" {
  name = "${var.service_name}-${var.env}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.service_name}-${var.env}-ecs-task-role"
    }
  )
}

# タスク実行ロール（ECS Agentがリソースにアクセス）
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.service_name}-${var.env}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.service_name}-${var.env}-ecs-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```

---

### タスク定義

```hcl
# ecs-task-definition.tf
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.service_name}-${var.env}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  task_role_arn      = aws_iam_role.ecs_task.arn
  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ENV"
          value = var.env
        },
        {
          name  = "SERVICE_NAME"
          value = var.service_name
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.service_name}-${var.env}"
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(
    local.common_tags,
    {
      Name = "${var.service_name}-${var.env}-task"
    }
  )
}

# CloudWatch Logsグループ
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.service_name}-${var.env}"
  retention_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "/ecs/${var.service_name}-${var.env}"
    }
  )
}
```

---

### lifecycle ignore_changes パターン

CI/CDでイメージタグが更新される場合:

```hcl
resource "aws_ecs_task_definition" "app" {
  # ... 省略 ...

  container_definitions = jsonencode([
    {
      name  = var.service_name
      image = "${aws_ecr_repository.app.repository_url}:latest"
      # ... 省略 ...
    }
  ])

  lifecycle {
    ignore_changes = [
      container_definitions  # CI/CDでの更新を無視
    ]
  }
}
```

---

## ECSサービス

### ALB（ロードバランサー）

```hcl
# alb.tf
resource "aws_lb" "main" {
  name               = "${var.service_name}-${var.env}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.env == "prod" ? true : false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.service_name}-${var.env}-alb"
    }
  )
}

resource "aws_lb_target_group" "app" {
  name        = "${var.service_name}-${var.env}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    local.common_tags,
    {
      Name = "${var.service_name}-${var.env}-tg"
    }
  )
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
```

---

### セキュリティグループ

```hcl
# security-group.tf

# ALBセキュリティグループ
resource "aws_security_group" "alb" {
  name        = "${var.service_name}-${var.env}-alb-sg"
  description = "ALBセキュリティグループ"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.service_name}-${var.env}-alb-sg"
    }
  )
}

# ECSセキュリティグループ
resource "aws_security_group" "ecs" {
  name        = "${var.service_name}-${var.env}-ecs-sg"
  description = "ECSセキュリティグループ"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "App port from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.service_name}-${var.env}-ecs-sg"
    }
  )
}
```

---

### ECSサービス

```hcl
# ecs-service.tf
resource "aws_ecs_service" "app" {
  name            = "${var.service_name}-${var.env}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.service_name
    container_port   = 8080
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  depends_on = [aws_lb_listener.http]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.service_name}-${var.env}-service"
    }
  )
}
```

---

## CD（継続的デプロイ）

### GitHub Actions + OIDC連携

#### OIDC Provider作成

```hcl
# github-oidc.tf
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "github-actions-oidc"
    }
  )
}
```

---

#### IAMロール（GitHub Actions用）

```hcl
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:myorg/${var.service_name}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.service_name}-${var.env}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.service_name}-${var.env}-github-actions-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

data "aws_iam_policy_document" "github_actions_ecs_deploy" {
  statement {
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.ecs_task.arn,
      aws_iam_role.ecs_task_execution.arn
    ]
  }
}

resource "aws_iam_policy" "github_actions_ecs_deploy" {
  name        = "${var.service_name}-${var.env}-github-actions-ecs-deploy"
  description = "GitHub ActionsからのECSデプロイ権限"
  policy      = data.aws_iam_policy_document.github_actions_ecs_deploy.json
}

resource "aws_iam_role_policy_attachment" "github_actions_ecs_deploy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecs_deploy.arn
}
```

---

### ECRイメージプッシュワークフロー

```yaml
# .github/workflows/build-push.yml
name: Build and Push to ECR

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::123456789012:role/myapp-dev-github-actions-role
          aws-region: ap-northeast-1

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build and push image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: myapp-dev
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
```

---

### ECSデプロイワークフロー

```yaml
# .github/workflows/deploy.yml
name: Deploy to ECS

on:
  workflow_run:
    workflows: ["Build and Push to ECR"]
    types: [completed]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::123456789012:role/myapp-dev-github-actions-role
          aws-region: ap-northeast-1

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster myapp-dev-cluster \
            --service myapp-dev-service \
            --force-new-deployment
```

---

## IAMガードレール設計

### 最小権限原則

**基本方針:**
- 必要最小限の権限のみ付与
- リソースレベルで制限
- 条件付きポリシーの活用

---

### OIDC + AssumeRole パターン

```hcl
# oidc-role.tf
data "aws_iam_policy_document" "oidc_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:myorg/${var.service_name}:ref:refs/heads/main",
        "repo:myorg/${var.service_name}:ref:refs/tags/*"
      ]
    }
  }
}
```

**セキュリティのポイント:**
- mainブランチとタグのみ許可
- プルリクエストからのデプロイを禁止

---

### インラインポリシー vs マネージドポリシー

| 種類 | 用途 | メリット | デメリット |
|------|------|---------|----------|
| **インラインポリシー** | 特定のロール専用 | 1対1の関係が明確 | 再利用不可 |
| **マネージドポリシー** | 複数のロールで共有 | 再利用可能、バージョン管理 | 依存関係が複雑化 |

**推奨パターン:**
- 汎用的な権限: マネージドポリシー
- ロール固有の権限: インラインポリシー

```hcl
# インラインポリシー
resource "aws_iam_role_policy" "ecs_task_inline" {
  name = "task-specific-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::${var.service_name}-${var.env}-data/*"
      }
    ]
  })
}

# マネージドポリシー
resource "aws_iam_policy" "common_s3_read" {
  name        = "common-s3-read"
  description = "S3読み取り権限（共通）"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::common-bucket",
          "arn:aws:s3:::common-bucket/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.common_s3_read.arn
}
```

---

### 条件付きポリシー

特定の条件下でのみ許可:

```hcl
data "aws_iam_policy_document" "conditional" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["ap-northeast-1"]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Environment"
      values   = [var.env]
    }
  }
}
```

---

## まとめ

このガイドでは以下をカバーしました:

1. **事前準備**: IAMユーザー、S3バックエンド、AWS認証情報
2. **命名規則**: `${service_name}-${env}-${resource}`パターン
3. **ECSクラスター**: Fargate、Container Insights、キャパシティプロバイダー
4. **ECRリポジトリ**: ライフサイクルポリシー、IAM権限
5. **ECSタスク定義**: タスクロール、実行ロール、コンテナ定義
6. **ECSサービス**: ALB、ターゲットグループ、セキュリティグループ
7. **CD**: GitHub Actions + OIDC、ECRプッシュ、ECSデプロイ
8. **IAMガードレール**: 最小権限、OIDC AssumeRole、条件付きポリシー

次は[TESTING.md](./TESTING.md)でテストとツールを学んでください。
