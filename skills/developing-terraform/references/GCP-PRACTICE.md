# GCP実践構築ガイド

TerraformによるGCPインフラの実践的な構築方法。

## 📋 目次

1. [GCPプロジェクト初期設定](#gcpプロジェクト初期設定)
2. [ネットワーク構築](#ネットワーク構築)
3. [データベース](#データベース)
4. [コンテナ基盤](#コンテナ基盤)
5. [IAM設計パターン](#iam設計パターン)
6. [GCSバックエンド設定](#gcsバックエンド設定)
7. [CD（継続的デプロイ）](#cd継続的デプロイ)

---

## GCPプロジェクト初期設定

### プロジェクトサービスAPI有効化

GCPリソースを作成する前に、必要なAPIを有効化します。

```hcl
# services.tf
resource "google_project_service" "services" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "eventarc.googleapis.com",
    "eventarcpublishing.googleapis.com",
    "firebase.googleapis.com",
    "firestore.googleapis.com",
    "iam.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "vpcaccess.googleapis.com",
  ])

  service            = each.key
  project            = var.project_id
  disable_on_destroy = false
}
```

**ポイント:**
- `for_each = toset(...)` で複数APIを効率的に管理
- `disable_on_destroy = false` でAPI無効化を防ぐ（データ保護）

---

### 必要なAPIリスト

| サービス | API | 用途 |
|---------|-----|------|
| **Compute Engine** | compute.googleapis.com | VPC、サブネット、ファイアウォール |
| **Cloud Run** | run.googleapis.com | サーバーレスコンテナ実行 |
| **Cloud SQL** | sqladmin.googleapis.com | マネージドデータベース |
| **Artifact Registry** | artifactregistry.googleapis.com | Dockerイメージ保管 |
| **Secret Manager** | secretmanager.googleapis.com | パスワード・認証情報管理 |
| **VPC Access** | vpcaccess.googleapis.com | Cloud RunからVPC接続 |
| **Service Networking** | servicenetworking.googleapis.com | Private Service Access |
| **Cloud Build** | cloudbuild.googleapis.com | CI/CDパイプライン |
| **Cloud DNS** | dns.googleapis.com | ドメイン管理 |
| **Pub/Sub** | pubsub.googleapis.com | メッセージング |
| **Firestore** | firestore.googleapis.com | NoSQLデータベース |
| **Firebase** | firebase.googleapis.com | アプリケーション統合 |

---

## ネットワーク構築

### VPC作成（auto_create_subnetworks = false 推奨）

```hcl
# vpc.tf
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = false  # カスタムサブネット作成
}
```

**ポイント:**
- `auto_create_subnetworks = false` で各リージョンのサブネットを手動制御
- IPアドレス範囲を明示的に設計

---

### サブネット（Private Google Access有効）

```hcl
# vpc.tf
resource "google_compute_subnetwork" "public" {
  name          = "${var.project_id}-subnet-public"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_subnetwork" "private" {
  name          = "${var.project_id}-subnet-private"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_subnetwork" "database" {
  name          = "${var.project_id}-subnet-database"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
```

**ポイント:**
- **Private Google Access**: Private IP からGoogle APIにアクセス可能
- **Flow Logs**: ネットワークトラフィックの可視化・監査

---

### ファイアウォールルール

```hcl
# vpc.tf
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.project_id}-allow-internal"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [
    "10.0.0.0/24",  # public subnet
    "10.0.1.0/24",  # private subnet
    "10.0.2.0/24",  # database subnet
  ]
}
```

---

### Cloud DNS ゾーン作成

```hcl
# dns.tf
resource "google_dns_managed_zone" "main" {
  name        = "${var.project_id}-zone"
  dns_name    = "${var.domain}."  # 末尾のドット必須
  description = "Main DNS zone for ${var.domain}"

  dnssec_config {
    state = "on"
  }
  cloud_logging_config {
    enable_logging = true
  }
}
```

---

### Private Service Access（Cloud SQL接続用）

Cloud SQLなどのGoogle管理サービスとVPCをPrivate接続するための設定。

```hcl
# vpc.tf
resource "google_compute_global_address" "private_ip_database" {
  name          = "private-ip-database"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_database.name]
}
```

**ポイント:**
- **VPC Peering**: Cloud SQLがVPC内部からPrivate IPでアクセス可能
- **prefix_length = 16**: /16のIP範囲を予約

---

### VPC Connectorの作成

Cloud RunやCloud FunctionsからVPC内リソースへアクセスするための接続コネクタ。

```hcl
# vpc-access-connector.tf
resource "google_vpc_access_connector" "serverless_connector" {
  name          = "vpc-connector"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.8.0.0/28"

  min_instances = 2
  max_instances = 3

  project = var.project_id
}
```

**ポイント:**
- Cloud RunのVPC接続に必須
- `/28` の小さい範囲で十分（16 IPアドレス）

---

## データベース

### Cloud SQL PostgreSQL インスタンス

```hcl
# cloudsql.tf
resource "google_sql_database_instance" "main" {
  name             = "main-db"
  database_version = "POSTGRES_17"
  region           = var.region

  settings {
    tier    = "db-f1-micro"
    edition = "ENTERPRISE"

    database_flags {
      name  = "max_connections"
      value = 200
    }

    database_flags {
      name  = "log_duration"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_statement"
      value = "all"
    }

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    ip_configuration {
      ipv4_enabled       = false  # パブリックIPを無効化
      private_network    = google_compute_network.vpc.id
      allocated_ip_range = google_compute_global_address.private_ip_database.name
      ssl_mode           = "ENCRYPTED_ONLY"  # SSL接続を必須化
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"  # UTCで指定 (JST 12:00)
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }
    }
  }

  deletion_protection = true

  depends_on = [google_service_networking_connection.private_vpc_connection]

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}
```

**ポイント:**
- **Private IP接続**: セキュアなVPC Peering経由
- **PITR（Point-in-Time Recovery）**: 任意時点への復元が可能
- **pgAudit**: PostgreSQL監査ログ有効化

---

### データベース・ユーザー作成

```hcl
# cloudsql.tf
resource "google_sql_database" "app" {
  name     = "app"
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "app" {
  name     = "app"
  instance = google_sql_database_instance.main.name
  password = data.google_secret_manager_secret_version.app_db_password.secret_data

  lifecycle {
    ignore_changes = [password]
  }
}
```

---

### Secret Manager でパスワード管理

```hcl
# secret-manager.tf
resource "google_secret_manager_secret" "db_password" {
  secret_id = "app-db-password"

  replication {
    auto {}
  }
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%*()-_=+[]{}<>:?"
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result

  lifecycle {
    ignore_changes = [secret_data]
  }
}

data "google_secret_manager_secret_version" "db_password" {
  secret  = google_secret_manager_secret.db_password.id
  version = "latest"

  depends_on = [google_secret_manager_secret_version.db_password]
}
```

**ポイント:**
- **lifecycle ignore_changes**: 初回作成後、Terraformは既存パスワードを上書きしない
- **random_password**: 強固なパスワード自動生成

---

## コンテナ基盤

### Artifact Registry リポジトリ

```hcl
# artifact-registry.tf
resource "google_artifact_registry_repository" "app" {
  project       = var.project_id
  location      = var.region
  repository_id = "app-repo"
  format        = "DOCKER"
}
```

---

### Cloud Run サービス

```hcl
# cloudrun.tf
resource "google_cloud_run_v2_service" "app" {
  name     = "app"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  deletion_protection = false

  template {
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    service_account       = google_service_account.cloud_run_sa.email

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = google_compute_network.vpc.name
        subnetwork = google_compute_subnetwork.private.name
      }
    }

    containers {
      name  = "app"
      image = "${var.region}-docker.pkg.dev/${var.project_id}/app-repo/app:latest"

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
        startup_cpu_boost = true
        cpu_idle          = true
      }

      startup_probe {
        initial_delay_seconds = 10
        period_seconds        = 5
        timeout_seconds       = 3
        failure_threshold     = 3
        http_get {
          path = "/health"
          port = 8080
        }
      }

      liveness_probe {
        initial_delay_seconds = 10
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 3
        http_get {
          path = "/health"
          port = 8080
        }
      }

      ports {
        container_port = 8080
      }

      env {
        name  = "DATABASE_HOST"
        value = google_sql_database_instance.main.private_ip_address
      }

      env {
        name = "DATABASE_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.main.connection_name]
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}
```

**ポイント:**
- **VPC Connector接続**: Private IPでCloud SQLアクセス
- **Secret Manager統合**: 環境変数に機密情報を安全に注入
- **Cloud SQL Proxy**: volumesマウントで接続

---

### Cloud Run IAM（公開設定）

```hcl
# cloudrun.tf
resource "google_cloud_run_service_iam_member" "public_invoker" {
  location = var.region
  service  = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
```

---

### Cloud Build Trigger（GitHub連携）

```hcl
# cloudbuild.tf
resource "google_cloudbuild_trigger" "main" {
  name     = "deploy-to-cloud-run"
  location = var.region

  github {
    owner = "your-org"
    name  = "your-repo"
    push {
      branch = "^main$"
    }
  }

  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t", "${var.region}-docker.pkg.dev/${var.project_id}/app-repo/app:$SHORT_SHA",
        "-t", "${var.region}-docker.pkg.dev/${var.project_id}/app-repo/app:latest",
        "."
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "--all-tags",
        "${var.region}-docker.pkg.dev/${var.project_id}/app-repo/app"
      ]
    }

    step {
      name = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "gcloud"
      args = [
        "run", "deploy", "app",
        "--image", "${var.region}-docker.pkg.dev/${var.project_id}/app-repo/app:$SHORT_SHA",
        "--region", var.region,
        "--platform", "managed"
      ]
    }
  }
}
```

---

## IAM設計パターン

### サービスアカウント設計（サービスごとに分離）

```hcl
# service-accounts.tf

# Cloud Run 用サービスアカウント
resource "google_service_account" "cloud_run_sa" {
  account_id   = "app-cloud-run-sa"
  display_name = "Cloud Run Service Account for App"
}

# Cloud Build 用サービスアカウント
resource "google_service_account" "cloud_build_sa" {
  account_id   = "app-cloud-build-sa"
  display_name = "Cloud Build Service Account for App"
}
```

**ポイント:**
- サービスごとに専用サービスアカウントを作成
- 最小権限の原則に従う

---

### 最小権限の適用

```hcl
# service-accounts.tf

# Cloud Run SA に必要な権限のみ付与
resource "google_project_iam_member" "cloud_run_roles" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/logging.logWriter",
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Cloud Build SA に必要な権限のみ付与
resource "google_project_iam_member" "cloud_build_roles" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/run.developer",
    "roles/iam.serviceAccountUser",
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}
```

**ポイント:**
- `for_each` で複数ロールを効率的に付与
- 必要最小限のロールのみ指定

---

### カスタムロールの作成

特定のリソースへのアクセスをさらに制限したい場合、カスタムロールを作成。

```hcl
# custom-role.tf
resource "google_project_iam_custom_role" "custom_role" {
  role_id     = "appSpecificRole"
  title       = "App Specific Role"
  description = "Custom role for specific app permissions"
  project     = var.project_id

  permissions = [
    "storage.buckets.get",
    "storage.objects.get",
    "storage.objects.list",
  ]
}

resource "google_project_iam_member" "custom_role_binding" {
  project = var.project_id
  role    = google_project_iam_custom_role.custom_role.id
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}
```

---

## GCSバックエンド設定

### ステートバケット作成

```hcl
# backend-resources.tf
resource "google_storage_bucket" "terraform_state" {
  name          = "your-project-terraform-state"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}
```

**ポイント:**
- **versioning**: ステートファイルの世代管理
- **uniform_bucket_level_access**: IAM一元管理
- **public_access_prevention**: 公開アクセス禁止

---

### バックエンド設定例

```hcl
# backend.tf
terraform {
  backend "gcs" {
    bucket = "your-project-terraform-state"
    prefix = "prod/state"
  }
}
```

---

## CD（継続的デプロイ）

### GitHub Actions + Workload Identity連携

#### Workload Identity Pool作成

```hcl
# github-oidc.tf
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
```

---

#### サービスアカウント + IAM バインディング

```hcl
# github-oidc.tf
resource "google_service_account" "github_actions" {
  project      = var.project_id
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
}

resource "google_service_account_iam_member" "github_actions_workload_identity" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/your-org/your-repo"
}

resource "google_project_iam_member" "github_actions_roles" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/run.developer",
    "roles/iam.serviceAccountUser",
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}
```

---

### GitHub Actions ワークフロー

```yaml
# .github/workflows/deploy.yml
name: Deploy to Cloud Run

on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: 'projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
          service_account: 'github-actions-sa@your-project.iam.gserviceaccount.com'

      - uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker
        run: gcloud auth configure-docker asia-northeast1-docker.pkg.dev

      - name: Build and Push
        run: |
          docker build -t asia-northeast1-docker.pkg.dev/your-project/app-repo/app:${{ github.sha }} .
          docker push asia-northeast1-docker.pkg.dev/your-project/app-repo/app:${{ github.sha }}

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy app \
            --image asia-northeast1-docker.pkg.dev/your-project/app-repo/app:${{ github.sha }} \
            --region asia-northeast1 \
            --platform managed
```

**ポイント:**
- **Workload Identity**: 認証情報不要でGCPにアクセス
- **permissions: id-token: write**: OIDC トークン発行に必須

---

## まとめ

このガイドでは以下をカバーしました:

1. **GCPプロジェクト初期設定**: API有効化（for_each パターン）
2. **ネットワーク構築**: VPC、サブネット、Private Google Access、Private Service Access、VPC Connector
3. **データベース**: Cloud SQL PostgreSQL（Private IP、PITR、pgAudit）、Secret Manager
4. **コンテナ基盤**: Artifact Registry、Cloud Run、Cloud Build Trigger
5. **IAM設計パターン**: サービスアカウント分離、最小権限、カスタムロール
6. **GCSバックエンド設定**: ステートバケット、バージョニング
7. **CD**: GitHub Actions + Workload Identity、Cloud Runデプロイ

次は[TESTING.md](./TESTING.md)でテストとツールを学んでください。
