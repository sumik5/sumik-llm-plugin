# デプロイと運用

Google ADK Agentのデプロイ方式、CI/CD、パフォーマンス最適化、コスト管理、オブザーバビリティの包括的リファレンス。

---

## 1. デプロイ方式の選択

### 1.1 デプロイ環境選択基準テーブル

| 要素 | ローカル | Cloud Run | Vertex AI Agent Engine | GKE Autopilot |
|------|---------|----------|----------------------|---------------|
| **セットアップ時間** | 最速（数分） | 速い（数時間） | 中（半日） | 最遅（数日） |
| **スケーリング** | 手動（プロセス起動） | 自動（0→N、サーバーレス） | 自動（フルマネージド） | 自動（K8s HPA） |
| **コストモデル** | 無料（開発マシン） | 従量課金（リクエスト） | 従量課金（リクエスト） | インフラ課金（常時） |
| **カスタマイズ** | 最大（任意設定） | 高（Dockerコンテナ） | 制限的（ADKプロトコル） | 最大（K8sマニフェスト） |
| **ネットワーク制御** | なし（localhost） | VPC Connector | マネージドVPC | 完全制御 |
| **最大同時実行** | CPUコア数依存 | 1000（デフォルト） | 自動最適化 | クラスタサイズ依存 |
| **セッション永続化** | SQLite（開発用） | CloudSQL推奨 | マネージド | CloudSQL必須 |
| **バージョン管理** | なし | イメージタグ | ネイティブサポート | イメージタグ |
| **ロールバック** | コード差し戻し | イメージ切り替え | バージョン切り替え | イメージ切り替え |
| **適用場面** | 開発・テスト | 汎用本番 | エンタープライズ（GCP） | 大規模分散 |

### 1.2 デプロイ方式の選択フローチャート

```
開発フェーズ？
├─ Yes → ローカル（adk web / adk run）
└─ No（本番）
    ↓
トラフィックが予測不能（スパイキー）？
├─ Yes → Cloud Run（サーバーレス）
└─ No（予測可能）
    ↓
VPC統合・ネットワーク完全制御が必要？
├─ Yes → GKE Autopilot
└─ No
    ↓
エンタープライズ（完全マネージドが望ましい）？
├─ Yes → Vertex AI Agent Engine
└─ No → Cloud Run
```

### 1.3 必須ファイル構成

```
my_adk_app/
├── agent.py              # root_agent定義
├── requirements.txt      # 依存関係（google-adk含む）
├── Dockerfile            # コンテナ化デプロイ用
├── .env.example          # 環境変数テンプレート（.envは.gitignoreへ）
└── tools/
    ├── __init__.py
    └── custom_tool.py
```

**requirements.txt 最小構成:**

```txt
google-adk>=1.0.0
google-cloud-aiplatform>=1.60.0
```

---

## 2. Cloud Runへのデプロイ

### 2.1 基本デプロイコマンド

**ADK CLIを使用:**

```bash
adk deploy cloud_run \
  --project=$PROJECT_ID \
  --region=$REGION \
  --service_name=$SERVICE_NAME \
  --app_name=$APP_NAME \
  --with_ui \           # Web UI同時デプロイ（開発・テスト専用）
  --session_db_url="postgresql+asyncpg://user:pass@host/db" \
  --artifact_storage_uri="gs://my-bucket/artifacts" \
  --trace_to_cloud \    # Cloud Trace有効化
  my_agent_dir
```

**重要オプション:**
- `--with_ui`: Web UI同時デプロイ（**開発・テスト専用、本番は除外**）
- `--session_db_url`: セッション永続化（本番はCloudSQL推奨）
- `--artifact_storage_uri`: Artifact保存先（本番はGCS推奨）
- `--trace_to_cloud`: Cloud Traceへのトレース送信

### 2.2 Cloud Run APIの呼び出し

```bash
export TOKEN=$(gcloud auth print-identity-token)
export APP_URL="https://service-name.run.app"

# SSEストリーミングでメッセージ送信
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  $APP_URL/run_sse \
  -d '{
    "app_name": "my_app",
    "user_id": "user1",
    "session_id": "session1",
    "new_message": {
      "role": "user",
      "parts": [{"text": "質問内容"}]
    }
  }'
```

### 2.3 CORS設定（フロントエンド分離時）

フロントエンド（React/Vue等）とバックエンドを分離する場合、`--allow_origins`が必須:

```bash
# 開発環境
adk api_server ./my_agents \
  --host 0.0.0.0 \
  --port 8000 \
  --allow_origins "http://localhost:3000" \
  --session_db_url "sqlite:///./sessions.db"

# 本番環境
adk api_server ./my_agents \
  --allow_origins "https://my-frontend-app.com" \
  --session_db_url "postgresql+asyncpg://user:pass@host/db"
```

**注意:** `--allow_origins`がないとブラウザがCORS違反でリクエストをブロックする。

---

## 3. Vertex AI Agent Engineへのデプロイ

### 3.1 Vertex AI Agent Engineの特徴

Vertex AI Agent Engineは**フルマネージドの本番グレードランタイム環境**で、多エージェントシステムに特化した以下の機能を提供する:

| 機能 | 説明 |
|------|------|
| **マネージドランタイム** | コンテナ管理・スケーリング・セキュリティポリシーを自動処理 |
| **バージョン管理** | エージェントの各バージョンを独立エンティティとして管理 |
| **セッション管理** | 短期セッションと永続メモリの両方をネイティブサポート |
| **セキュアAPI** | デプロイ後に安定したエンドポイントを自動提供 |
| **オブザーバビリティ** | 実行履歴・ツール呼び出し・メモリ更新を詳細に記録 |
| **障害耐性** | フォールトトレラントな実行環境とロールバック機能 |

**適用場面:** コンテナ管理不要、サーバーレス志向、完全GCPエコシステム利用時

### 3.2 デプロイコマンド

**ADK CLIを使用:**

```bash
adk deploy agent_engine \
  --project="project-id" \
  --region="us-central1" \
  --staging_bucket="gs://staging-bucket" \
  --adk_app="agent_engine_app" \
  --trace_to_cloud \
  my_agent_dir
```

**Vertex AI SDK（Python）を使用:**

```python
import vertexai
from vertexai.preview import reasoning_engines

vertexai.init(project="my-project", location="us-central1")

# AdkAppでエージェントをラップ
from google.adk.reasoning_engines import AdkApp

adk_app = AdkApp(
    agent=root_agent,
    enable_tracing=True,
)

# Vertex AI Agent Engineにデプロイ
remote_app = reasoning_engines.ReasoningEngine.create(
    adk_app,
    requirements=["google-adk>=1.0.0", "google-cloud-aiplatform"],
    display_name="My ADK Agent",
    description="本番エージェント",
)

print(f"Agent Engine resource name: {remote_app.resource_name}")
```

### 3.3 バージョン管理とロールバック

```python
# バージョン指定でデプロイ
remote_app = reasoning_engines.ReasoningEngine.create(
    adk_app,
    display_name="Event Planner Agent",
    # version_id は内部的に管理される
)

# バージョン一覧確認（gcloud CLI）
# gcloud ai reasoning-engines list --location=us-central1

# 特定バージョンにトラフィックを切り替え
# gcloud ai agent-engine agents set-active-version \
#   --agent=event_planner_agent \
#   --version=1.1 \
#   --location=us-central1

# ロールバック（前バージョンに戻す）
# gcloud ai agent-engine agents set-active-version \
#   --agent=event_planner_agent \
#   --version=1.0

# セッション開始（特定バージョンをテスト）
# gcloud ai agent-engine sessions start \
#   --agent=event_planner_agent \
#   --location=us-central1 \
#   --version=1.1 \
#   --input='{"event_type":"hackathon","date":"2025-10-30"}'
```

### 3.4 Vertex AIでのモニタリング

**Google Cloud Console経由:**
1. `console.cloud.google.com` にアクセス
2. `Vertex AI → Agent Engine → Agents` に移動
3. デプロイ済みエージェントを選択
4. `Sessions`、`Logs`、`Monitor` タブで確認

**確認可能な情報:**
- ツール呼び出し履歴と実行時間
- プロンプト実行ログ
- セッションごとの入出力
- メモリ状態の変化

**Python SDKからのモニタリング:**

```python
from google.adk.app import AdkApp

app = AdkApp(agent_path="event_planner_agent.yaml")
session = app.start_session(enable_trace=True)

response = session.send_message({
    "event_type": "product launch",
    "date": "2025-12-10"
})

# トレース情報取得
print(response["output"])
print(response.get("trace", {}))

# ログ出力例
import logging
logger = logging.getLogger(__name__)
logger.info("session_trace", extra={
    "user_id": "u42",
    "tokens_used": response["trace"]["total_tokens"],
    "duration": response["trace"]["duration"],
    "steps": response["trace"]["steps"]
})
```

---

## 4. GKEへのデプロイ

### 4.1 プロジェクト構成

```
project/
├── agent/
│   ├── __init__.py
│   └── agent.py          # LlmAgent実装（root_agent定義）
├── main.py               # FastAPIエントリポイント
├── requirements.txt      # 依存関係
└── Dockerfile            # コンテナイメージ定義
```

### 4.2 FastAPIエントリポイント

```python
# main.py
from google.adk.cli.fast_api import get_fast_api_app

# ADKのFastAPIアプリケーションを取得
app = get_fast_api_app(
    agent_dir="./agent",                                    # root_agentが定義されたディレクトリ
    session_service_uri="postgresql+asyncpg://user:pass@host/db",  # 本番はCloudSQL
)
```

### 4.3 Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# 依存関係をコピー・インストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードをコピー
COPY . .

# ヘルスチェック（Kubernetes連携用）
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# FastAPIサーバーを起動
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

**注意:**
- コンテナポートは`8080`（GKE推奨）
- `.dockerignore`に`sessions.db`を追加（read-onlyエラー回避）

### 4.4 GKEクラスタ作成

```bash
# 環境変数設定
export GOOGLE_CLOUD_PROJECT="your-project-id"
export GOOGLE_CLOUD_LOCATION="us-central1"

# GKE Autopilotクラスタ作成（ノード管理自動化・セキュリティベストプラクティス自動適用）
gcloud container clusters create-auto adk-cluster \
    --location=$GOOGLE_CLOUD_LOCATION \
    --project=$GOOGLE_CLOUD_PROJECT

# Artifact Registryリポジトリ作成（初回のみ）
gcloud artifacts repositories create adk-repo \
    --repository-format=docker \
    --location=$GOOGLE_CLOUD_LOCATION

# Cloud Buildでイメージをビルド・プッシュ
gcloud builds submit \
    --tag $GOOGLE_CLOUD_LOCATION-docker.pkg.dev/$GOOGLE_CLOUD_PROJECT/adk-repo/adk-agent:latest
```

### 4.5 Workload Identity設定

```bash
# Kubernetesサービスアカウント作成
kubectl create serviceaccount adk-sa

# GCPサービスアカウント作成
gcloud iam service-accounts create adk-gcp-sa \
    --project=$GOOGLE_CLOUD_PROJECT

# Vertex AI権限付与
gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT \
    --member="serviceAccount:adk-gcp-sa@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com" \
    --role="roles/aiplatform.user"

# Workload Identityバインディング
gcloud iam service-accounts add-iam-policy-binding \
    adk-gcp-sa@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:$GOOGLE_CLOUD_PROJECT.svc.id.goog[default/adk-sa]"

# KubernetesサービスアカウントにWorkload Identity注釈
kubectl annotate serviceaccount adk-sa \
    iam.gke.io/gcp-service-account=adk-gcp-sa@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com
```

### 4.6 Kubernetesマニフェスト（本番構成）

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adk-agent
spec:
  replicas: 2
  selector:
    matchLabels:
      app: adk-agent
  template:
    metadata:
      labels:
        app: adk-agent
    spec:
      serviceAccountName: adk-sa  # Workload Identity用
      containers:
      - name: adk-agent
        image: us-central1-docker.pkg.dev/PROJECT_ID/adk-repo/adk-agent:latest
        ports:
        - containerPort: 8080
        env:
        - name: GOOGLE_CLOUD_PROJECT
          value: "PROJECT_ID"
        - name: GOOGLE_CLOUD_LOCATION
          value: "us-central1"
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        # ヘルスチェック
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: adk-agent-service
spec:
  type: LoadBalancer
  selector:
    app: adk-agent
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
---
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: adk-agent-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: adk-agent
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### 4.7 ADK CLIによる自動デプロイ

```bash
# 上記の手順を自動化するコマンド
adk deploy gke \
  --project <project-id> \
  --cluster_name <cluster-name> \
  --region <region> \
  --with_ui \
  AGENT_PATH
```

**自動実行される内容:**
1. GKEクラスタ作成（存在しない場合）
2. Dockerイメージビルド・プッシュ
3. Workload Identity設定
4. Kubernetesマニフェスト適用
5. LoadBalancerのIPアドレス取得

### 4.8 GKEトラブルシューティング

| 問題 | 原因 | 解決策 |
|------|------|--------|
| **403 Forbidden** | Workload Identity未設定 | Workload Identity設定手順を再実行 |
| **Read-only database** | sessions.dbがコンテナに含まれている | `.dockerignore`に`sessions.db`追加 |
| **ビルドログストリーム失敗** | Cloud Buildタイムアウト | Cloud ConsoleのCloud Build履歴で詳細確認 |
| **Podが起動しない** | イメージプル失敗 | `kubectl describe pod`でイベント確認 |
| **502 Bad Gateway** | アプリケーション起動失敗 | `kubectl logs`でアプリログ確認 |

```bash
# デバッグコマンド
kubectl get pods -l=app=adk-agent         # Pod状態確認
kubectl logs -l app=adk-agent --tail=50 -f  # ログ確認（ライブ）
kubectl describe pod <pod-name>           # Pod詳細情報
kubectl exec -it <pod-name> -- /bin/bash  # コンテナ内シェル
kubectl top pods                          # リソース使用状況
kubectl get events --sort-by='.lastTimestamp'  # イベント確認
kubectl get service adk-agent-service     # LoadBalancer IP確認
```

---

## 5. CI/CDパイプライン

### 5.1 CI/CDを導入する理由

ADKエージェントのCI/CDは従来のソフトウェア以上に重要である:

- **プロンプト変更**により動作が根本的に変わる
- **ツール変更**が予期しない動作を引き起こす可能性がある
- **LLMの非決定性**により、回帰テストが必要
- **デプロイの監査証跡**がコンプライアンス要件になる場合がある

CI/CDによるメリット:
- 繰り返し可能なビルドとリリース
- プロンプト回帰テストの自動化
- バージョン管理とロールバック機能
- デプロイ時間の大幅短縮（手動30分 → 自動2分）

### 5.2 GitHub Actions + Vertex AI Agent Engine

```yaml
# .github/workflows/deploy-agent.yml
name: ADK Agent CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: us-central1
  AGENT_NAME: my-adk-agent

jobs:
  # CI: テストと検証
  test-and-validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install google-adk google-cloud-aiplatform
          pip install -r requirements.txt
          pip install pytest pytest-asyncio black ruff

      # コード品質チェック
      - name: Lint with ruff
        run: ruff check .

      - name: Format check with black
        run: black . --check

      # ユニットテスト
      - name: Run unit tests
        run: pytest tests/unit/ -v

      # ツール定義の検証
      - name: Validate ADK agent config
        run: adk validate .

      # 統合テスト（モック使用）
      - name: Run integration tests
        run: pytest tests/integration/ -v
        env:
          GOOGLE_GENAI_USE_VERTEXAI: "false"
          GOOGLE_API_KEY: ${{ secrets.GOOGLE_API_KEY_TEST }}

  # CD: Vertex AI Agent Engineへのデプロイ（mainブランチのみ）
  deploy-to-vertex-ai:
    runs-on: ubuntu-latest
    needs: test-and-validate
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install google-adk google-cloud-aiplatform
          pip install -r requirements.txt

      # Workload Identity Federationで認証（サービスアカウントキーより安全）
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up gcloud CLI
        uses: google-github-actions/setup-gcloud@v2

      # エージェントのデプロイ
      - name: Deploy Agent to Vertex AI
        run: |
          python deploy.py \
            --project=$PROJECT_ID \
            --location=$REGION \
            --agent-name=$AGENT_NAME \
            --version-tag=${{ github.sha }}

      # デプロイ後のヘルスチェック
      - name: Post-deployment health check
        run: |
          python scripts/health_check.py \
            --agent-name=$AGENT_NAME \
            --region=$REGION

      # デプロイ記録
      - name: Record deployment
        run: |
          echo "Deployed $AGENT_NAME at $(date)" \
            "Commit: ${{ github.sha }}" >> deployments.log
```

### 5.3 GitHub Actions + Cloud Run

```yaml
# .github/workflows/deploy-cloud-run.yml
name: Deploy ADK Agent to Cloud Run

on:
  push:
    branches: [main]

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: us-central1
  SERVICE_NAME: adk-agent-service
  IMAGE: gcr.io/${{ secrets.GCP_PROJECT_ID }}/adk-agent

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Configure Docker for GCR
        run: gcloud auth configure-docker gcr.io

      - name: Build and push Docker image
        run: |
          docker build -t $IMAGE:${{ github.sha }} -t $IMAGE:latest .
          docker push $IMAGE:${{ github.sha }}
          docker push $IMAGE:latest

      - name: Run tests
        run: |
          pip install pytest google-adk
          pytest tests/ -v

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy $SERVICE_NAME \
            --image=$IMAGE:${{ github.sha }} \
            --platform=managed \
            --region=$REGION \
            --allow-unauthenticated \
            --set-env-vars="GOOGLE_CLOUD_PROJECT=$PROJECT_ID" \
            --set-secrets="API_KEY=api-key:latest"

      - name: Verify deployment
        run: |
          SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
            --region=$REGION \
            --format='value(status.url)')
          curl -f $SERVICE_URL/health || exit 1
```

### 5.4 Cloud Buildを使用したCI/CD

```yaml
# cloudbuild.yaml
steps:
  # テスト
  - name: 'python:3.11'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        pip install google-adk pytest -r requirements.txt
        pytest tests/ -v
        adk validate .

  # Dockerイメージビルド
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - 'gcr.io/$PROJECT_ID/adk-agent:$COMMIT_SHA'
      - '-t'
      - 'gcr.io/$PROJECT_ID/adk-agent:latest'
      - '.'

  # イメージをプッシュ
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/adk-agent:$COMMIT_SHA']

  # Vertex AI Agent Engineへのデプロイ（カナリアロールアウト）
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'ai'
      - 'agents'
      - 'deploy'
      - '--project=$PROJECT_ID'
      - '--source=gs://agents/my-agent.yaml'
      - '--canary-percent=10'   # 最初は10%のトラフィック

timeout: '900s'

options:
  logging: CLOUD_LOGGING_ONLY
```

### 5.5 デプロイ戦略

| 戦略 | 説明 | 適用場面 |
|------|------|---------|
| **Blue-Green** | 旧バージョン（Blue）と新バージョン（Green）を並行稼働 | 即時切り替え・ゼロダウンタイム |
| **カナリアリリース** | 新バージョンに少量（5-10%）トラフィックを先行 | リスクの高い変更 |
| **ローリングアップデート** | Pod を順次更新 | GKE環境の標準的な更新 |
| **ステージング→本番** | ステージング環境での検証後に本番昇格 | 全般的なベストプラクティス |

```python
# deploy.py - バージョン管理付きデプロイスクリプト例
import vertexai
from vertexai.preview import reasoning_engines
import argparse
import logging

def deploy_agent(project: str, location: str, agent_name: str, version_tag: str):
    vertexai.init(project=project, location=location)

    logger = logging.getLogger(__name__)
    logger.info(f"Deploying {agent_name} version {version_tag}")

    # エージェント定義を読み込む
    from agent import root_agent
    from google.adk.reasoning_engines import AdkApp

    adk_app = AdkApp(
        agent=root_agent,
        enable_tracing=True,
    )

    remote_app = reasoning_engines.ReasoningEngine.create(
        adk_app,
        requirements=["google-adk>=1.0.0"],
        display_name=f"{agent_name}-{version_tag}",
        description=f"Deployed at commit {version_tag}",
    )

    logger.info(f"Successfully deployed: {remote_app.resource_name}")
    return remote_app.resource_name

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--location", required=True)
    parser.add_argument("--agent-name", required=True)
    parser.add_argument("--version-tag", required=True)
    args = parser.parse_args()

    deploy_agent(args.project, args.location, args.agent_name, args.version_tag)
```

---

## 6. パフォーマンス最適化

### 6.1 レイテンシの発生源分析

エージェントのレイテンシは以下から発生する:

| 発生源 | 説明 | 削減策 |
|--------|------|--------|
| **LLM推論時間** | モデルが出力を生成する時間 | 小モデル採用、プロンプト削減 |
| **ツール呼び出し** | 外部API・DBアクセス時間 | キャッシング、並列実行 |
| **チェーン間オーバーヘッド** | 順次推論・ツール使用の遅延 | 並列化、バッチ処理 |
| **ネットワーク・ミドルウェア** | 転送・オーケストレーション遅延 | リージョン最適化、CDN活用 |
| **コンテキストウィンドウ** | 大きなコンテキストがモデルを遅くする | サマリーキャッシング |

**計測から始める（最重要原則）:**

```python
from google.adk.app import AdkApp
import time

app = AdkApp(agent_path="event_planner.yaml")
session = app.start_session(enable_trace=True)

start = time.time()
result = session.send_message({"event_type": "conference"})
end = time.time()

# トレースで詳細分析
print(result["trace"])  # ステップごとのタイミングとトークン数
print(f"Total latency: {(end - start) * 1000:.0f}ms")
```

### 6.2 並列ツール実行

ADK 1.10.0以降、並列ツール実行をネイティブサポート。3ツール×2秒 = 順次6秒 → 並列2秒（3倍高速化）。

```python
import asyncio
from google.adk.agents import LlmAgent

# 並列実行を促すInstruction
agent = LlmAgent(
    name="parallel_agent",
    model="gemini-2.0-flash",
    instruction="""複数の情報が必要な場合、必ず並列で関数を呼び出してください。

例:
- "LondonとNYの天気を教えて" → get_weather(London)とget_weather(NY)を同時呼び出し
- "USD/EURレートと天気を教えて" → 両方を同時呼び出し
- "A社とB社を比較して" → 各社の情報を並列取得

常に複数の単純な関数呼び出しを、1つの複雑な呼び出しより優先してください。""",
    tools=[get_weather, get_currency_rate, get_population]
)

# 非同期バッチ処理（複数クエリの並行処理）
async def process_batch(queries: list[str]) -> list[str]:
    """複数クエリを並行処理"""
    tasks = [agent.run_async(q) for q in queries]
    results = await asyncio.gather(*tasks)
    return results

# パフォーマンス比較:
# - 逐次処理: 3 × 1.5s = 4.5s
# - 並行処理: max(1.5s, 1.5s, 1.5s) = 1.5s → 3倍高速化
```

```python
# 非同期ツール定義（並列実行対応）
import aiohttp

async def get_weather(city: str) -> dict:
    """単一都市の天気を取得。並列実行最適化済み。"""
    async with aiohttp.ClientSession() as session:
        async with session.get(f"http://api.weather.com/{city}") as response:
            data = await response.json()
            return {"status": "success", "city": city, "temperature": data["temp"]}

async def run_with_timeout(tool_func, *args, timeout: int = 5):
    """タイムアウト付きツール実行"""
    try:
        return await asyncio.wait_for(tool_func(*args), timeout=timeout)
    except asyncio.TimeoutError:
        return {"error": "Tool timeout", "tool": tool_func.__name__}
```

### 6.3 キャッシング戦略

```python
import hashlib
import time
from typing import Any, Optional
from collections import OrderedDict

class TTLCache:
    """TTL（有効期限）付きキャッシュ"""
    def __init__(self, maxsize: int = 1000, ttl_seconds: int = 300):
        self.maxsize = maxsize
        self.ttl_seconds = ttl_seconds
        self._cache: OrderedDict[str, tuple[Any, float]] = OrderedDict()

    def _make_key(self, *args, **kwargs) -> str:
        key = str(args) + str(sorted(kwargs.items()))
        return hashlib.sha256(key.encode()).hexdigest()

    def get(self, key: str) -> Optional[Any]:
        if key in self._cache:
            value, timestamp = self._cache[key]
            if time.time() - timestamp < self.ttl_seconds:
                self._cache.move_to_end(key)  # LRU更新
                return value
            del self._cache[key]
        return None

    def set(self, key: str, value: Any):
        if len(self._cache) >= self.maxsize:
            self._cache.popitem(last=False)  # 古いエントリを削除
        self._cache[key] = (value, time.time())

# ツールへのキャッシュ適用
_exchange_cache = TTLCache(ttl_seconds=300)  # 5分キャッシュ

def fetch_exchange_rate(base: str, target: str) -> dict:
    """為替レートを取得（5分キャッシュ）"""
    cache_key = f"exchange-{base}-{target}"
    cached = _exchange_cache.get(cache_key)
    if cached:
        return cached

    # 実際のAPI呼び出し
    result = call_exchange_api(base, target)
    _exchange_cache.set(cache_key, result)
    return result
```

**本番でのキャッシング推奨スタック:**

| キャッシュ種別 | 実装 | 適用場面 |
|-------------|------|---------|
| **インメモリ** | `functools.lru_cache` / `TTLCache` | 単一インスタンス、開発環境 |
| **分散キャッシュ** | Redis / Memcached | 複数インスタンス、本番環境 |
| **セマンティックキャッシュ** | Embedding類似度マッチング | LLM呼び出しのキャッシュ |
| **セッションローカル** | `ToolContext.state` | タスク内での重複呼び出し防止 |

### 6.4 モデルティアリング（コスト最適化）

```python
from google.adk.agents import LlmAgent

class TieredAgentRouter:
    """クエリ複雑度に応じてモデルを動的選択"""

    def __init__(self):
        # Lite: 分類・短文生成（最安）
        self.lite_agent = LlmAgent(model="gemini-2.0-flash-lite")
        # Standard: 一般的な推論・回答（標準）
        self.standard_agent = LlmAgent(model="gemini-2.0-flash")
        # Pro: 複雑な分析・長文生成（高精度）
        self.pro_agent = LlmAgent(model="gemini-2.0-flash-thinking")

    async def route(self, query: str) -> str:
        complexity = self._analyze_complexity(query)

        if complexity == "simple":
            return await self.lite_agent.run_async(query)
        elif complexity == "complex":
            return await self.pro_agent.run_async(query)
        else:
            return await self.standard_agent.run_async(query)

    def _analyze_complexity(self, query: str) -> str:
        word_count = len(query.split())
        complex_keywords = {"analyze", "compare", "evaluate", "design", "策略", "分析", "比較"}

        if word_count < 10 and not any(k in query.lower() for k in complex_keywords):
            return "simple"
        elif word_count > 50 or any(k in query.lower() for k in complex_keywords):
            return "complex"
        else:
            return "standard"

# コスト削減効果:
# - Lite使用率40% → コスト約30%削減
# - Pro使用率10%（必要時のみ） → 過剰スペック回避
```

### 6.5 プロンプト最適化

```python
# 悪い例: 冗長で構造化されていない（237トークン）
bad_instruction = """
You are a helpful assistant. You should always be polite and respectful.
When users ask questions, you should try your best to answer them accurately.
If you don't know something, you should say so. Also, remember to be concise.
You have access to various tools that you can use to help answer questions.
Make sure to use them when appropriate. Don't forget to format your responses nicely.
Always double-check your work before responding. Be friendly and professional.
"""

# 良い例: 簡潔で構造化（71トークン、約70%削減）
good_instruction = """
Role: Technical support assistant

Rules:
1. Answer accurately; admit unknowns
2. Use tools when needed
3. Be concise and professional

Format: Markdown
"""
```

### 6.6 コンテキストウィンドウ管理

```python
from google.adk.agents import LlmAgent

def manage_context_window(agent: LlmAgent, max_messages: int = 20):
    """コンテキストウィンドウの自動プルーニング"""
    history = agent.state.history

    if len(history) > max_messages:
        # システムメッセージを保持
        system_messages = [m for m in history if m.get("role") == "system"]
        recent_messages = history[-max_messages:]
        agent.state.history = system_messages + recent_messages

# 会話要約によるコンテキスト節約
class SessionManager:
    def __init__(self, max_history: int = 10):
        self.max_history = max_history

    async def summarize_and_prune(self, agent: LlmAgent):
        """古い履歴を要約してから削除（コンテキスト保持）"""
        if len(agent.state.history) > self.max_history:
            old_history = agent.state.history[:-self.max_history]
            # 要約エージェントで要約生成
            summary = await self._summarize(old_history)
            agent.state.history = [
                {"role": "system", "content": f"過去の会話の要約: {summary}"},
                *agent.state.history[-self.max_history:]
            ]
```

### 6.7 Agentインスタンスキャッシュ

```python
from functools import lru_cache
from google.adk.agents import LlmAgent
from fastapi import FastAPI

@lru_cache(maxsize=1)
def get_agent() -> LlmAgent:
    """Agentシングルトン（初期化コスト削減）"""
    return LlmAgent(
        model="gemini-2.0-flash",
        instruction="..."
    )

# FastAPIでの活用
app = FastAPI()

@app.post("/chat")
async def chat(query: str):
    agent = get_agent()  # 初回のみ初期化（以降はキャッシュ）
    return await agent.run_async(query)
```

---

## 7. コスト管理

### 7.1 コストの発生源

| コストバケット | 詳細 | 管理策 |
|-------------|------|--------|
| **LLM呼び出し** | 入力トークン（プロンプト）+ 出力トークン（補完） | モデルティアリング、プロンプト削減 |
| **ツール使用** | 外部API呼び出し・データ処理 | キャッシング、呼び出し回数制限 |
| **メモリ・ベクターストア** | Firestore/BigQuery/Vertex Vector Search | 保存サイズ最適化、TTL設定 |
| **コンピュート** | Cloud Functions/Run/Vertex Pipelinesの実行料金 | スケーリング設定、コールドスタート削減 |
| **ネットワーク** | サービス間通信・外部エンドポイントへのEgress | リージョン最適化、データ転送削減 |

### 7.2 Quotaと制限の管理

GCPのQuotaは安全弁とボトルネックの両面を持つ:

| Quota種別 | 内容 | 対応 |
|---------|------|------|
| **LLMトークンQuota** | モデルごとの日次・分次制限 | 必要に応じて引き上げ申請 |
| **Vertex AI APIレート制限** | 並行セッション数・ツール呼び出し数 | 指数バックオフで対応 |
| **Cloud Run制限** | 実行タイムアウト・最大同時リクエスト | タイムアウト設定、キューイング |
| **課金Quota** | ソフトキャップ（予算アラート）とハードキャップ | 予算アラートで異常検知 |

**Quotaの確認:** `console.cloud.google.com/iam-admin/quotas`

### 7.3 コスト削減戦略

```python
# 戦略1: max_output_tokensの設定
from google.adk.agents import LlmAgent
from google.genai.types import GenerateContentConfig

agent = LlmAgent(
    model="gemini-2.0-flash",
    generate_content_config=GenerateContentConfig(
        max_output_tokens=256,  # 必要最小限に制限
        temperature=0.7,
    )
)

# 戦略2: コスト認識型ツール設計（安価な選択肢を優先）
# ADKのtool_choice設定でコストを考慮したルーティング
# tools:
#   - name: summarize_text_fast
#     cost_per_call: 0.005  # より安価
#     fallback_for: summarize_text
#   - name: summarize_text
#     cost_per_call: 0.01

# 戦略3: 早期終了（確信度が高い場合はスキップ）
async def cost_aware_processing(query: str, confidence_threshold: float = 0.9):
    # 安価なモデルで先行判定
    lite_result = await lite_agent.run_async(query)

    if lite_result.confidence > confidence_threshold:
        return lite_result.answer  # 高コストモデルをスキップ

    # 確信度が低い場合のみ高精度モデルを使用
    return await pro_agent.run_async(query)
```

### 7.4 予算アラートの設定

```bash
# Cloud Billing で予算とアラートを設定
# 1. console.cloud.google.com/billing/budgets にアクセス
# 2. 新規予算を作成
# 3. GCPプロジェクトにリンクして閾値設定（例: 50%, 90%, 100%）
# 4. 通知先をメールまたはPub/Subトピックに設定

# Pub/Sub経由でのプログラム的なアラート処理
# 予算超過時にエージェントのスケーリングを自動制限するなど
```

### 7.5 コスト可視化とモニタリング

```bash
# Cloud Billing Reports でのフィルタリング
# Service: Vertex AI API
# SKU: Input/output tokens
# Time: Daily/Weekly trends

# BigQueryへのログエクスポート（詳細分析用）
# gcloud logging sinks create billing-export \
#   bigquery.googleapis.com/projects/PROJECT/datasets/billing_logs \
#   --log-filter='resource.type="aiplatform.googleapis.com/Endpoint"'
```

---

## 8. テレメトリとオブザーバビリティ

### 8.1 OpenTelemetry統合

ADKはOpenTelemetryで計装済み。トレース対象:
- Invocation（全体の呼び出し）
- Agent Run（エージェント実行）
- LLM Call（モデル呼び出し）
- Tool Call / Tool Response（ツール実行）

**Cloud Traceへの送信:**

```bash
# Cloud Runデプロイ時
adk deploy cloud_run \
  --agent_file agent.py \
  --trace_to_cloud

# Agent Engineデプロイ時
adk deploy agent_engine \
  --agent_file agent.py \
  --trace_to_cloud

# ローカルWebサーバー（開発時）
adk web \
  --agent_file agent.py \
  --trace_to_cloud
```

**Cloud Traceでの確認:**
1. Google Cloud Console → Trace → Trace List
2. リクエストごとのスパン詳細を確認
3. ツール呼び出し・モデル呼び出しの時間分布を可視化

### 8.2 ロギング戦略

```python
import logging

# モジュール別ロガー設定（ベストプラクティス）
logger = logging.getLogger(__name__)

def my_tool(param: str, tool_context) -> dict:
    logger.info(f"Tool called: {param}")
    result = process(param)
    logger.debug(f"Result: {result}")
    return {"output": result}

# ADK内部ログ制御
logging.getLogger('google_adk').setLevel(logging.INFO)

# 構造化ログ（Cloud Loggingとの親和性が高い）
import json

def structured_log(level: str, message: str, **kwargs):
    log_entry = {
        "severity": level.upper(),
        "message": message,
        **kwargs
    }
    print(json.dumps(log_entry, ensure_ascii=False))
```

**ロギングのベストプラクティス:**
- モジュール別ロガー使用: `logging.getLogger(__name__)`
- 適切なログレベル: `DEBUG`（開発）、`INFO`（通常）、`WARNING`（注意）、`ERROR`（障害）
- **機密情報ログ出力禁止**（PII、APIキー）
- 構造化ログ（JSON形式）でCloud Loggingとの連携強化

### 8.3 メトリクス収集Plugin

```python
from google.adk.plugins import Plugin
from collections import defaultdict
import time
import statistics

class MetricsCollectorPlugin(Plugin):
    def __init__(self):
        self.request_count = 0
        self.success_count = 0
        self.failure_count = 0
        self.latencies: list[float] = []
        self.token_usage = defaultdict(int)
        self.tool_calls = defaultdict(int)

    def before_agent_callback(self, context):
        context.custom_data["start_time"] = time.time()
        self.request_count += 1

    def after_agent_callback(self, context):
        elapsed = time.time() - context.custom_data["start_time"]
        self.latencies.append(elapsed)

        if context.error:
            self.failure_count += 1
        else:
            self.success_count += 1

    def after_model_callback(self, context):
        if hasattr(context, 'usage_metadata'):
            self.token_usage['input'] += context.usage_metadata.prompt_token_count
            self.token_usage['output'] += context.usage_metadata.candidates_token_count

    def after_tool_callback(self, context):
        self.tool_calls[context.tool_call.name] += 1

    def get_summary(self) -> dict:
        return {
            "total_requests": self.request_count,
            "success_rate": self.success_count / self.request_count if self.request_count > 0 else 0,
            "latency": {
                "mean_ms": statistics.mean(self.latencies) * 1000 if self.latencies else 0,
                "p50_ms": statistics.median(self.latencies) * 1000 if self.latencies else 0,
                "p95_ms": statistics.quantiles(self.latencies, n=20)[18] * 1000 if len(self.latencies) > 20 else 0,
                "p99_ms": statistics.quantiles(self.latencies, n=100)[98] * 1000 if len(self.latencies) > 100 else 0,
            },
            "tokens": dict(self.token_usage),
            "tool_calls": dict(self.tool_calls),
        }

# 使用例
metrics = MetricsCollectorPlugin()
agent = LlmAgent(model="gemini-2.0-flash", plugins=[metrics])
# リクエスト処理後
print(metrics.get_summary())
```

### 8.4 アラート設定

```python
from dataclasses import dataclass
from typing import Callable
import time

@dataclass
class AlertConfig:
    latency_threshold_ms: int = 3000
    error_threshold: int = 5
    critical_error_threshold: int = 10
    on_alert: Callable[[str], None] = lambda msg: print(f"ALERT: {msg}")

class AlertingPlugin(Plugin):
    def __init__(self, config: AlertConfig = AlertConfig()):
        self.config = config
        self.consecutive_errors = 0

    def before_agent_callback(self, context):
        context.custom_data["request_start"] = time.time()

    def after_agent_callback(self, context):
        elapsed_ms = (time.time() - context.custom_data["request_start"]) * 1000

        if elapsed_ms > self.config.latency_threshold_ms:
            self.config.on_alert(
                f"高レイテンシ: {elapsed_ms:.0f}ms (閾値: {self.config.latency_threshold_ms}ms)"
            )

        if context.error:
            self.consecutive_errors += 1
            if self.consecutive_errors >= self.config.critical_error_threshold:
                self.config.on_alert(f"CRITICAL: {self.consecutive_errors}連続エラー")
            elif self.consecutive_errors >= self.config.error_threshold:
                self.config.on_alert(f"WARNING: {self.consecutive_errors}連続エラー")
        else:
            self.consecutive_errors = 0

# Pub/Sub経由でのアラート送信例（本番環境）
from google.cloud import pubsub_v1

def send_alert_to_pubsub(message: str, topic_path: str):
    publisher = pubsub_v1.PublisherClient()
    publisher.publish(topic_path, message.encode("utf-8"))
```

### 8.5 SLI監視

```python
from dataclasses import dataclass
from typing import List

@dataclass
class SLI:
    """Service Level Indicator"""
    name: str
    current_value: float
    target: float
    unit: str

    @property
    def is_meeting_target(self) -> bool:
        return self.current_value <= self.target

class SLIMonitor:
    """SLI追跡と違反検出"""

    def __init__(self):
        self.slis: List[SLI] = []

    def track(self, name: str, value: float, target: float, unit: str):
        sli = SLI(name, value, target, unit)
        self.slis.append(sli)

        if not sli.is_meeting_target:
            print(f"SLI違反: {name} = {value}{unit} (目標: {target}{unit})")

    def report(self):
        print("\n=== SLIレポート ===")
        for sli in self.slis:
            status = "OK" if sli.is_meeting_target else "NG"
            print(f"[{status}] {sli.name}: {sli.current_value}{sli.unit} (目標: {sli.target}{sli.unit})")

# 標準的なSLI設定例
monitor = SLIMonitor()
monitor.track("p50_latency", 850, 1000, "ms")
monitor.track("p95_latency", 2100, 2000, "ms")  # 違反
monitor.track("p99_latency", 3200, 3000, "ms")  # 違反
monitor.track("error_rate", 0.02, 0.05, "%")
monitor.track("tool_success_rate", 0.98, 0.95, "%")
monitor.report()
```

---

## 9. 本番運用パターン

### 9.1 エラーハンドリングとリトライ

```python
from enum import Enum
import asyncio

class ErrorCategory(Enum):
    RETRYABLE = "retryable"
    PERMANENT = "permanent"
    RATE_LIMIT = "rate_limit"

def classify_error(error: Exception) -> ErrorCategory:
    """エラーをカテゴリ分類"""
    error_msg = str(error).lower()

    if "rate limit" in error_msg or "quota" in error_msg:
        return ErrorCategory.RATE_LIMIT  # Quota超過: 長めのバックオフ

    if any(keyword in error_msg for keyword in [
        "timeout", "connection", "temporary", "503", "429"
    ]):
        return ErrorCategory.RETRYABLE  # 一時的エラー: 短いバックオフ

    return ErrorCategory.PERMANENT  # 永続的エラー: リトライ不可

async def retry_with_backoff(func, max_retries: int = 3):
    """エラーカテゴリに応じたリトライ戦略"""
    for attempt in range(max_retries):
        try:
            return await func()
        except Exception as e:
            category = classify_error(e)

            if category == ErrorCategory.PERMANENT:
                raise  # リトライしない

            elif category == ErrorCategory.RATE_LIMIT:
                wait_time = 60 * (2 ** attempt)  # 60秒, 120秒, 240秒
                print(f"レート制限: {wait_time}秒待機...")
                await asyncio.sleep(wait_time)

            elif category == ErrorCategory.RETRYABLE:
                wait_time = 2 ** attempt  # 1秒, 2秒, 4秒
                print(f"リトライ可能エラー: {wait_time}秒待機...")
                await asyncio.sleep(wait_time)

    raise Exception(f"{max_retries}回リトライ後も失敗")
```

### 9.2 サーキットブレーカー

```python
from enum import Enum
from dataclasses import dataclass
import time

class CircuitState(Enum):
    CLOSED = "closed"        # 正常動作
    OPEN = "open"            # 遮断（リクエスト拒否）
    HALF_OPEN = "half_open"  # 回復テスト中

@dataclass
class CircuitBreakerConfig:
    failure_threshold: int = 5
    timeout_seconds: int = 60
    success_threshold: int = 2

class CircuitBreaker:
    """外部サービスへの過負荷防止"""

    def __init__(self, config: CircuitBreakerConfig = CircuitBreakerConfig()):
        self.config = config
        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.success_count = 0
        self.last_failure_time: float | None = None

    async def call(self, func):
        if self.state == CircuitState.OPEN:
            if self._should_attempt_reset():
                self.state = CircuitState.HALF_OPEN
                print("サーキット HALF_OPEN: 回復テスト中")
            else:
                raise Exception("Circuit breaker is OPEN - サービス一時停止中")

        try:
            result = await func()
            self._on_success()
            return result
        except Exception:
            self._on_failure()
            raise

    def _on_success(self):
        self.failure_count = 0
        if self.state == CircuitState.HALF_OPEN:
            self.success_count += 1
            if self.success_count >= self.config.success_threshold:
                self.state = CircuitState.CLOSED
                self.success_count = 0
                print("サーキット CLOSED: 回復完了")

    def _on_failure(self):
        self.failure_count += 1
        self.last_failure_time = time.time()
        if self.failure_count >= self.config.failure_threshold:
            self.state = CircuitState.OPEN
            print(f"サーキット OPEN: {self.failure_count}連続失敗")

    def _should_attempt_reset(self) -> bool:
        if self.last_failure_time is None:
            return False
        return (time.time() - self.last_failure_time) >= self.config.timeout_seconds
```

### 9.3 デバッグ手順

**優先順位付きデバッグフロー:**

| 優先度 | 方法 | 対象 |
|--------|------|------|
| 1位 | **ADK Dev UI Trace View** | `adk web .` → トレースタブ | エージェント動作全般 |
| 2位 | **ログ分析** | Cloud Logging / `kubectl logs` | 本番環境の問題 |
| 3位 | **Pythonデバッガ (pdb)** | ツール単体テスト | ツール実装の問題 |

```python
# Dev UIトレースで確認する情報
# - InvocationContext（全体の実行コンテキスト）
# - LLMプロンプト（実際に送られたプロンプト）
# - Tool引数・応答（ツールの入出力）
# - state delta（状態変化）

# よくある問題と解決法
# 問題: LLMがツールを呼ばない
# → トレースでtool宣言の有無を確認、tool descriptionとinstructionを改善

# 問題: ツールの引数が誤り
# → LLMから渡された引数を確認、型ヒントとパラメータ説明を明確化

# デバッガを使ったツールテスト
def my_tool(param: str, tool_context) -> dict:
    import pdb; pdb.set_trace()  # ブレークポイント（開発時のみ）
    result = process(param)
    return {"output": result}
```

### 9.4 スケーリング設定

**Cloud Runのスケーリング設定:**

```bash
gcloud run services update $SERVICE_NAME \
  --region=$REGION \
  --min-instances=1 \          # コールドスタート防止（最低1インスタンス常時稼働）
  --max-instances=100 \        # 最大インスタンス数
  --concurrency=80 \           # インスタンスあたりの最大同時リクエスト数
  --cpu=2 \                    # CPU（コア数）
  --memory=2Gi \               # メモリ
  --timeout=300                # タイムアウト（秒）
```

**GKEのHPA（Horizontal Pod Autoscaler）:**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: adk-agent-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: adk-agent
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60    # スケールアップの安定化ウィンドウ
    scaleDown:
      stabilizationWindowSeconds: 300   # スケールダウンの安定化ウィンドウ
```

---

## 10. ADK CLIリファレンス

### 10.1 主要コマンド

| コマンド | 説明 | 用途 |
|---------|------|------|
| `adk create APP` | 新規Agentプロジェクト作成 | 初期セットアップ |
| `adk run AGENT` | 対話型CLI実行 | ローカル開発・テスト |
| `adk web [DIR]` | Dev UI起動（ポート8000） | 開発・デバッグ |
| `adk api_server [DIR]` | API専用バックエンド起動 | バックエンド分離時 |
| `adk eval AGENT EVAL_SET` | Agent評価（eval.jsonl使用） | 品質評価 |
| `adk validate .` | プロジェクト設定検証 | CI/CDパイプライン |
| `adk deploy cloud_run` | Cloud Runへのデプロイ | クラウドデプロイ |
| `adk deploy agent_engine` | Vertex AI Agent Engineへのデプロイ | エンタープライズデプロイ |
| `adk deploy gke` | GKEへのデプロイ | 大規模Kubernetesデプロイ |

### 10.2 重要オプション

**`adk web` / `adk api_server`共通オプション:**

| オプション | デフォルト | 説明 |
|---------|---------|------|
| `--host` | `0.0.0.0` | バインドアドレス |
| `--port` | `8000` | リッスンポート |
| `--session_db_url` | インメモリ | セッション永続化DB |
| `--artifact_storage_uri` | ローカル | Artifact保存先 |
| `--allow_origins` | なし | CORS許可オリジン（`api_server`で重要） |
| `--trace_to_cloud` | 無効 | Google Cloud Traceへの送信 |

**`adk deploy cloud_run`専用オプション:**

| オプション | 説明 |
|---------|------|
| `--with_ui` | Web UI同時デプロイ（**開発・テスト専用**） |
| `--project` | GCPプロジェクトID |
| `--region` | デプロイリージョン |
| `--service_name` | Cloud Runサービス名 |
| `--app_name` | ADKアプリ名 |

---

## 11. 本番運用チェックリスト

### フェーズ別チェックリスト

**プロトタイプ段階:**
- [ ] `adk run` / `adk web` でローカル動作確認
- [ ] `adk validate .` でプロジェクト設定検証
- [ ] ユニットテスト実装
- [ ] 基本的なエラーハンドリング

**ステージング段階:**
- [ ] Cloud Run / Agent Engineへのデプロイ確認
- [ ] CloudSQLでのセッション永続化
- [ ] MetricsCollectorPlugin追加
- [ ] 統合テスト実装
- [ ] CI/CDパイプライン構築（GitHub Actions / Cloud Build）

**本番移行時:**
- [ ] `--with_ui` を除外（本番はAPI専用）
- [ ] PerformanceProfilerPlugin追加
- [ ] AlertingPlugin設定（PagerDuty等への通知）
- [ ] Cloud Trace有効化（`--trace_to_cloud`）
- [ ] サーキットブレーカー実装
- [ ] SLI監視ダッシュボード構築
- [ ] 予算アラート設定
- [ ] Evaluation Test（品質評価）実装

**継続的運用:**
- [ ] 週次でログレビュー（応答時間増加・ツール失敗・ユーザー離脱）
- [ ] 月次でコスト分析（Billing Reports確認）
- [ ] バージョン履歴管理とロールバック手順の確認
- [ ] 依存関係の脆弱性スキャン（`pip-audit`）

---

## まとめ：本番グレードADKエージェントの要点

| 領域 | 重要ポイント |
|------|------------|
| **デプロイ選択** | トラフィック予測可能性・VPC要件・管理コストで選択。Cloud Runは汎用、Agent Engineはエンタープライズ向け |
| **CI/CD** | GitHub Actions + Workload Identity Federationを基本構成に。カナリアリリースでリスク低減 |
| **パフォーマンス** | 計測→並列化→キャッシング→モデルティアリングの順で最適化 |
| **コスト管理** | 小モデル優先、Quotaの適切な設定、予算アラートの早期設定 |
| **オブザーバビリティ** | OpenTelemetry（Cloud Trace）+ MetricsCollectorPlugin + SLI監視の三層構成 |
| **障害対応** | エラー分類（リトライ可否判断）+ サーキットブレーカー + ロールバック戦略 |
