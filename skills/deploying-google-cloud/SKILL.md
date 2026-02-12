---
description: >-
  Google Cloud Run serverless container deployment covering architecture, containerization, CI/CD pipelines, auto-scaling, load balancing, security, monitoring, and cost optimization.
  MUST load when Dockerfile is detected alongside google-cloud or @google-cloud packages, or when cloudbuild.yaml is present.
  For Docker-specific patterns, use managing-docker instead. For general monitoring design, use designing-monitoring instead.
---

# Google Cloud Run サーバーレスコンテナデプロイ

このスキルは、Google Cloud Run を使用したサーバーレスコンテナアプリケーションのデプロイ、スケーリング、運用管理の包括的なガイドです。

## Cloud Run の位置づけ

Cloud Run は Google Cloud のサーバーレスコンピューティングプラットフォームで、コンテナベースのアプリケーションをインフラ管理なしでデプロイできます。

### Google Cloud コンピューティングサービス選択ガイド

| サービス | 最適なワークロード | コンテナ制御 | スケーリング | 管理オーバーヘッド |
|---------|------------------|------------|------------|----------------|
| **Cloud Run** | ステートレスHTTP/gRPC、可変トラフィック | 標準コンテナ、カスタムランタイム可 | 自動（ゼロスケール可） | **最小** |
| **Google Kubernetes Engine (GKE)** | ステートフル、マルチテナント、複雑なオーケストレーション | 完全制御 | 手動+自動 | **高** |
| **App Engine** | Web アプリケーション、PaaS環境 | 抽象化（コンテナ設定不可） | 自動 | 低 |
| **Cloud Functions** | イベント駆動、短時間処理（<9分） | 関数単位（コンテナ不要） | 自動 | 最小 |
| **Compute Engine** | カスタムOS、フル制御、レガシー移行 | VM単位（任意のコンテナランタイム） | 手動 | **非常に高** |

**Cloud Run を選ぶべきケース:**
- Dockerfileで定義されたカスタムランタイムが必要
- トラフィックが不定期または急激な増減がある
- ステートレスアーキテクチャを採用している
- インフラ管理を最小化したい

**他のサービスを選ぶべきケース:**
- GKE: Kubernetesマニフェストによる細かい制御、StatefulSet、CronJobが必要
- App Engine: 単純なWebアプリで、コンテナカスタマイズ不要
- Cloud Functions: 単一機能の実行（関数単位）で、コンテナ化不要

---

## Cloud Run アーキテクチャ概要

### コアコンポーネント

| コンポーネント | 説明 | 特徴 |
|--------------|------|------|
| **Service** | デプロイ単位の論理的なエンドポイント | 一意のHTTPS URLを持つ |
| **Revision** | Service の特定バージョン（イミュータブル） | トラフィック分割、ロールバックに使用 |
| **Configuration** | 最新の Revision 設定 | 新規デプロイで自動更新 |
| **Container Instance** | 実行中のコンテナ | リクエスト駆動で自動スケール |

### リクエスト駆動型スケーリングの仕組み

```
ユーザーリクエスト
    ↓
Cloud Run Load Balancer
    ↓
[Container Instance 1] ← 既存インスタンス（リクエスト処理中）
[Container Instance 2] ← 負荷に応じて自動追加
[Container Instance N] ← 最大インスタンス数まで拡張
    ↓ アイドル状態が続くと...
[スケールダウン → 0インスタンス]（コスト削減）
```

**重要な制約:**
- **リクエストタイムアウト**: デフォルト5分、最大60分
- **メモリ制限**: 最小128MiB、最大32GiB（第2世代）
- **CPU割り当て**: リクエスト処理時のみ（CPU-on-request）または常時（CPU-always）
- **ステートレス要件**: インスタンス間で状態を共有しない設計が必須

---

## gcloud CLI クイックリファレンス

### 初期セットアップ

```bash
# Google Cloud SDK インストール（公式サイトからダウンロード後）
gcloud init

# プロジェクト作成
gcloud projects create my-cloud-run-project --name="Cloud Run Project"

# デフォルトプロジェクト設定
gcloud config set project my-cloud-run-project

# Cloud Run API 有効化
gcloud services enable run.googleapis.com

# 認証（対話式）
gcloud auth login

# サービスアカウント認証（CI/CD用）
gcloud auth activate-service-account --key-file=key.json
```

### デプロイ・管理コマンド

| コマンド | 説明 | 主要フラグ |
|---------|------|----------|
| `gcloud run deploy SERVICE` | サービスをデプロイ | `--image`, `--region`, `--platform managed`, `--allow-unauthenticated` |
| `gcloud run services list` | サービス一覧表示 | `--region`, `--platform managed` |
| `gcloud run services describe SERVICE` | サービス詳細表示 | `--region` |
| `gcloud run services delete SERVICE` | サービス削除 | `--region` |
| `gcloud run revisions list` | Revision 一覧表示 | `--service SERVICE`, `--region` |
| `gcloud run services update-traffic SERVICE` | トラフィック分割設定 | `--to-revisions REVISION=PERCENT` |
| `gcloud logging read "resource.type=cloud_run_revision"` | ログ取得 | `--limit`, `--format` |

### デプロイ例

```bash
# 基本デプロイ（コンテナイメージから）
gcloud run deploy my-service \
  --image gcr.io/my-project/my-container:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated

# カスタム設定でデプロイ
gcloud run deploy my-service \
  --image gcr.io/my-project/my-container:latest \
  --platform managed \
  --region us-central1 \
  --memory 2Gi \
  --cpu 2 \
  --max-instances 100 \
  --concurrency 80 \
  --timeout 3600 \
  --set-env-vars "DB_HOST=10.0.0.1,DB_PORT=5432" \
  --no-allow-unauthenticated

# トラフィック分割（カナリアデプロイ）
gcloud run services update-traffic my-service \
  --to-revisions my-service-v2=10,my-service-v1=90 \
  --region us-central1

# ロールバック（全トラフィックを前バージョンに）
gcloud run services update-traffic my-service \
  --to-revisions my-service-v1=100 \
  --region us-central1
```

---

## デプロイ判断テーブル

### デプロイ方式の選択

| デプロイ方式 | 最適なケース | メリット | デメリット |
|------------|------------|---------|---------|
| **gcloud CLI** | 手動デプロイ、検証環境、学習目的 | シンプル、即座に実行可能 | 手動実行、再現性低い |
| **Cloud Build + cloudbuild.yaml** | CI/CDパイプライン、チーム開発 | 自動化、ビルド・テスト・デプロイ一体化 | 初期設定コスト |
| **Terraform** | IaC、複数環境管理、監査要件 | バージョン管理、再現性、差分管理 | 学習コスト、ステート管理必要 |
| **Cloud Console（UI）** | 一時的な設定変更、初心者 | 視覚的、設定項目が明示的 | スクリプト化不可、属人化リスク |

**推奨アプローチ:**
- **開発環境**: gcloud CLI（手動確認重視）
- **ステージング・本番**: Cloud Build（自動化、再現性）
- **マルチクラウド・複雑構成**: Terraform（IaC）

### 環境別設定差分テーブル

| 設定項目 | 開発環境 | ステージング環境 | 本番環境 |
|---------|---------|---------------|---------|
| **min-instances** | 0（コスト削減） | 1-2（コールドスタート回避） | 5-10（高可用性） |
| **max-instances** | 10 | 50 | 100-1000 |
| **concurrency** | 80（デフォルト） | 80 | 50-100（負荷テスト後調整） |
| **memory** | 512MiB | 1GiB | 2GiB-4GiB |
| **cpu** | 1（デフォルト） | 1-2 | 2-4 |
| **timeout** | 300秒（デフォルト） | 600秒 | 900-3600秒 |
| **CPU割り当て** | CPU-on-request（コスト削減） | CPU-on-request | **CPU-always**（WebSocket、バックグラウンド処理） |
| **認証** | `--allow-unauthenticated` | IAM認証推奨 | **IAM認証必須** |

---

## スケーリング設定ガイド

### 主要パラメータ

| パラメータ | 説明 | デフォルト | 推奨範囲 |
|----------|------|----------|---------|
| **concurrency** | 1インスタンスが同時処理するリクエスト数 | 80 | 10-1000 |
| **min-instances** | 最小インスタンス数（コールドスタート回避） | 0 | 本番: 1-10 |
| **max-instances** | 最大インスタンス数（コスト上限制御） | 100 | 本番: 100-1000 |
| **cpu** | CPU コア数 | 1 | 1-8 |
| **memory** | メモリ容量 | 512MiB | 128MiB-32GiB |

### ワークロード別推奨設定

| ワークロード | concurrency | min-instances | max-instances | CPU割り当て | 説明 |
|------------|------------|--------------|--------------|-----------|------|
| **REST API（軽量）** | 80-100 | 1（本番）、0（開発） | 100-1000 | CPU-on-request | 一般的なHTTPリクエスト |
| **REST API（重い処理）** | 10-20 | 2-5 | 100-500 | CPU-on-request | データベースクエリ、外部API呼び出し多用 |
| **gRPC API** | 50-100 | 2-10 | 100-1000 | CPU-on-request | ストリーミング、高速通信 |
| **WebSocket** | 10-50 | 5-10 | 100-500 | **CPU-always** | 長時間接続、リアルタイム通信 |
| **バッチ処理** | 1-5 | 0 | 10-50 | **CPU-always** | 非同期ジョブ、データ変換 |
| **イベント駆動（Pub/Sub）** | 10-50 | 0 | 100-1000 | CPU-on-request | 非同期メッセージ処理 |

### concurrency 設定の判断基準

**高い concurrency（80-100）を設定すべき:**
- リクエスト処理が軽量（<100ms）
- I/O待ちが少ない
- メモリ使用量が少ない

**低い concurrency（10-20）を設定すべき:**
- CPU集約的な処理（画像処理、暗号化等）
- データベース接続プールを使用（コネクション数制限）
- メモリ使用量が多い

**設定例:**

```bash
# 軽量API（高concurrency）
gcloud run deploy lightweight-api \
  --image gcr.io/my-project/api:latest \
  --concurrency 100 \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 1000

# 重い処理API（低concurrency、高リソース）
gcloud run deploy heavy-api \
  --image gcr.io/my-project/heavy-api:latest \
  --concurrency 10 \
  --memory 4Gi \
  --cpu 4 \
  --min-instances 2 \
  --max-instances 100

# WebSocket（CPU-always）
gcloud run deploy websocket-server \
  --image gcr.io/my-project/ws:latest \
  --concurrency 50 \
  --memory 2Gi \
  --cpu 2 \
  --min-instances 5 \
  --max-instances 500 \
  --cpu-throttling=false  # CPU-always の指定
```

---

## セキュリティチェックリスト

### IAM認証

- [ ] **本番環境では `--no-allow-unauthenticated` を設定**（デフォルトはpublic）
- [ ] サービスアカウントに最小権限の原則を適用（`roles/run.invoker` のみ）
- [ ] Cloud Run Invoker 権限を適切なユーザー・サービスに付与

```bash
# サービスアカウント作成
gcloud iam service-accounts create cloud-run-invoker

# Invoker 権限付与
gcloud run services add-iam-policy-binding my-service \
  --member="serviceAccount:cloud-run-invoker@my-project.iam.gserviceaccount.com" \
  --role="roles/run.invoker" \
  --region us-central1

# 認証付きリクエスト
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://my-service-xxxxx.run.app
```

### コンテナセキュリティ

- [ ] **脆弱性スキャン**: Artifact Registry の脆弱性スキャンを有効化
- [ ] **最小イメージ**: `distroless` や `alpine` ベースイメージを使用
- [ ] **非rootユーザー**: Dockerfile で `USER` ディレクティブを指定
- [ ] **シークレット管理**: 環境変数ではなく Secret Manager を使用

```bash
# Secret Manager からシークレットを取得
gcloud run deploy my-service \
  --image gcr.io/my-project/app:latest \
  --update-secrets DB_PASSWORD=db-password:latest
```

### ネットワークセキュリティ

- [ ] **VPC コネクタ**: 内部リソース（Cloud SQL、Memorystore等）へのアクセスは VPC 経由
- [ ] **Ingress 制御**: 内部トラフィックのみ許可する場合は `--ingress internal`
- [ ] **Egress 制御**: VPC Service Controls で外部通信を制限

```bash
# VPC コネクタ作成
gcloud compute networks vpc-access connectors create my-connector \
  --region us-central1 \
  --range 10.8.0.0/28

# Cloud Run に VPC コネクタを設定
gcloud run deploy my-service \
  --image gcr.io/my-project/app:latest \
  --vpc-connector my-connector \
  --vpc-egress all-traffic
```

### コンプライアンス

- [ ] **監査ログ**: Cloud Audit Logs を有効化（デフォルトで有効）
- [ ] **CMEK**: 顧客管理暗号鍵（Cloud KMS）を使用
- [ ] **Binary Authorization**: コンテナイメージの署名検証

---

## コスト最適化チェックリスト

### 料金モデル理解

Cloud Run の料金は以下の要素で決定:

| 課金要素 | 説明 | 料金（米国、概算） |
|---------|------|----------------|
| **CPU時間** | リクエスト処理時のCPU使用時間 | vCPU-秒あたり $0.00002400 |
| **メモリ時間** | リクエスト処理時のメモリ使用時間 | GiB-秒あたり $0.00000250 |
| **リクエスト数** | 受信リクエスト数 | 100万リクエストあたり $0.40 |
| **ネットワーク** | Egress（外部への送信） | GBあたり $0.12（地域により異なる） |

**CPU割り当てモード:**
- **CPU-on-request**（デフォルト）: リクエスト処理時のみCPU課金
- **CPU-always**: アイドル時もCPU課金（WebSocket、バックグラウンド処理用）

### コスト削減のベストプラクティス

- [ ] **min-instances=0（開発環境）**: トラフィックがない時は完全スケールダウン
- [ ] **concurrency を高める**: インスタンス数を減らし、CPU・メモリ時間を削減
- [ ] **CPU-on-request を使用**: WebSocket以外は CPU-on-request を選択
- [ ] **メモリ・CPU を最適化**: 過剰なリソース割り当てを避ける（負荷テストで調整）
- [ ] **リージョン選択**: コスト重視なら us-central1、us-east1 等の低価格リージョン
- [ ] **トラフィック削減**: CDN（Cloud CDN）で静的コンテンツをキャッシュ
- [ ] **Artifact Registry の圧縮**: イメージサイズを小さくし、プル時間とストレージコストを削減

```bash
# コスト最適化設定例
gcloud run deploy cost-optimized-api \
  --image gcr.io/my-project/api:latest \
  --region us-central1 \
  --memory 512Mi \
  --cpu 1 \
  --concurrency 100 \
  --min-instances 0 \
  --max-instances 100 \
  --cpu-throttling  # CPU-on-request（デフォルト）
```

---

## ユーザー確認の原則（AskUserQuestion）

Cloud Run のデプロイ時、以下の判断が必要な場合は AskUserQuestion ツールで確認すること。

### 確認すべき場面

**デプロイ方式の選択:**
- 手動デプロイ（gcloud CLI）か、自動CI/CD（Cloud Build）か、IaC（Terraform）か
- 理由: プロジェクトのフェーズや運用体制によって最適解が異なる

**リージョン選択:**
- ユーザー基盤の地理的位置、コンプライアンス要件、コストを考慮
- 例: 日本ユーザー向けなら `asia-northeast1`（東京）

**認証方式:**
- Public（`--allow-unauthenticated`）か、IAM認証（`--no-allow-unauthenticated`）か
- 理由: セキュリティ要件によって決定

**CPU割り当て方式:**
- CPU-on-request（デフォルト）か、CPU-always か
- 理由: WebSocket・バックグラウンド処理以外は CPU-on-request が推奨だが、ワークロード特性を確認

**min-instances 設定:**
- 0（コスト削減）か、1以上（コールドスタート回避）か
- 理由: 本番環境では SLA 要件により決定

### 確認不要な場面（ベストプラクティスに従う）

- **コンテナポート 8080**: Cloud Run のデフォルト（`PORT=8080` 環境変数で設定）
- **ステートレス設計**: Cloud Run の前提として必須
- **IAM最小権限**: `roles/run.invoker` のみ付与（当然の設定）
- **シークレット管理**: Secret Manager 使用（環境変数にシークレット直書き禁止）
- **脆弱性スキャン**: Artifact Registry で自動有効化

---

## リファレンスファイル一覧

詳細な実装ガイドは以下のファイルを参照:

| ファイル | 内容 |
|---------|------|
| **[CLOUDRUN-CONTAINERIZATION.md](references/CLOUDRUN-CONTAINERIZATION.md)** | Dockerfile 最適化、マルチステージビルド、Cloud Run 向けベストプラクティス |
| **[CLOUDRUN-DEPLOYMENT.md](references/CLOUDRUN-DEPLOYMENT.md)** | デプロイ戦略（Blue/Green、カナリア）、トラフィック分割、ロールバック |
| **[CLOUDRUN-CI-CD.md](references/CLOUDRUN-CI-CD.md)** | Cloud Build パイプライン、cloudbuild.yaml、自動テスト・デプロイ |
| **[CLOUDRUN-SCALING.md](references/CLOUDRUN-SCALING.md)** | オートスケーリング詳細、負荷テスト、パフォーマンスチューニング |
| **[CLOUDRUN-SECURITY.md](references/CLOUDRUN-SECURITY.md)** | IAM詳細、VPC、Secret Manager、Binary Authorization |
| **[CLOUDRUN-MONITORING.md](references/CLOUDRUN-MONITORING.md)** | Cloud Monitoring、Logging、Trace、アラート設定 |
| **[CLOUDRUN-COST-OPTIMIZATION.md](references/CLOUDRUN-COST-OPTIMIZATION.md)** | 料金計算、コスト分析、最適化テクニック |

---

## 参考コマンド集

### プロジェクト管理

```bash
# プロジェクト一覧
gcloud projects list

# プロジェクト切り替え
gcloud config set project my-project-id

# API 有効化状態確認
gcloud services list --enabled
```

### サービス管理

```bash
# サービス一覧（全リージョン）
gcloud run services list --platform managed

# サービス詳細（YAML形式）
gcloud run services describe my-service \
  --region us-central1 \
  --format yaml

# サービス削除
gcloud run services delete my-service --region us-central1
```

### ログ・デバッグ

```bash
# リアルタイムログ監視
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=my-service" \
  --limit 50 \
  --format "table(timestamp, textPayload)"

# エラーログのみ表示
gcloud logging read "resource.type=cloud_run_revision AND severity>=ERROR" \
  --limit 20

# Cloud Shell でポート転送（ローカルテスト）
gcloud run services proxy my-service --region us-central1
```

### Revision 管理

```bash
# Revision 一覧
gcloud run revisions list --service my-service --region us-central1

# 特定 Revision の詳細
gcloud run revisions describe my-service-v2 --region us-central1

# Revision 削除（トラフィック0%のもののみ）
gcloud run revisions delete my-service-v1 --region us-central1
```

---

## まとめ

Cloud Run は、Dockerコンテナをインフラ管理なしでデプロイできるサーバーレスプラットフォームです。以下のポイントを押さえて活用してください:

1. **適切なサービス選択**: GKE、App Engine、Cloud Functions との使い分けを判断テーブルで確認
2. **gcloud CLI 習熟**: デプロイ、スケーリング、トラフィック分割のコマンドを活用
3. **環境別設定**: 開発・ステージング・本番で min-instances、認証、CPU割り当てを調整
4. **セキュリティ**: IAM認証、Secret Manager、VPCコネクタを徹底
5. **コスト最適化**: CPU-on-request、高concurrency、適切なリソース割り当てでコスト削減

詳細な実装ガイドは `references/` ディレクトリの各ファイルを参照してください。
