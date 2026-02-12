# セキュリティ

Cloud Run アプリケーションのセキュリティを確保するための包括的なガイド。IAM、コンテナセキュリティ、ネットワークセキュリティ、シークレット管理を網羅。

## IAM（Identity and Access Management）

### サービスアカウント設定

**専用サービスアカウントの作成:**
```bash
# デプロイ用サービスアカウント作成
gcloud iam service-accounts create cloud-run-deployer \
  --display-name="Cloud Run Deployer"

# 必要な権限を付与
gcloud projects add-iam-policy-binding my-project \
  --member="serviceAccount:cloud-run-deployer@my-project.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding my-project \
  --member="serviceAccount:cloud-run-deployer@my-project.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

### 最小権限の原則

| ロール | 権限 | 用途 |
|-------|------|------|
| `roles/run.admin` | 完全な管理権限 | デプロイ・更新・削除 |
| `roles/run.developer` | サービス作成・更新 | 開発者向け |
| `roles/run.invoker` | サービス呼び出しのみ | API呼び出し、他サービスからのアクセス |
| `roles/run.viewer` | 読み取り専用 | 監視・運用チーム |

**推奨プラクティス:**
- 開発者には `roles/run.developer` を付与（admin権限不要）
- CI/CDパイプラインには専用サービスアカウント使用
- 長期的なサービスアカウントキーは避け、サービスアカウント偽装を活用

### Cloud Run Invoker / Developer / Admin ロール

**リソースレベル IAM ポリシー:**
```bash
# 特定サービスへの invoker 権限付与
gcloud run services add-iam-policy-binding my-app \
  --member="user:alice@example.com" \
  --role="roles/run.invoker" \
  --region us-central1
```

**サービスアカウント偽装:**
```bash
# 一時的に別のサービスアカウントで認証
gcloud auth print-access-token \
  --impersonate-service-account=cloud-run-deployer@my-project.iam.gserviceaccount.com
```

## コンテナセキュリティ

### ベースイメージの選択（distroless推奨）

**推奨: distroless イメージ**
```dockerfile
# Node.js distroless イメージ
FROM gcr.io/distroless/nodejs:18

WORKDIR /app
COPY package*.json ./
COPY node_modules ./node_modules
COPY . .

CMD ["server.js"]
```

**メリット:**
- シェルやパッケージマネージャーを含まない（攻撃対象面の削減）
- イメージサイズが小さい
- 既知の脆弱性が少ない

**代替案: Alpine / Slim 変種**
```dockerfile
FROM python:3.9-slim

WORKDIR /app

# 非rootユーザー作成
RUN addgroup --system appgroup && adduser --system --group appuser

# 依存関係インストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードコピー
COPY . .
RUN chown -R appuser:appgroup /app

# 非rootユーザーに切り替え
USER appuser

EXPOSE 8080
CMD ["python", "app.py"]
```

### 脆弱性スキャン（Container Analysis）

**Trivy による自動スキャン:**
```bash
# イメージの脆弱性スキャン
trivy image gcr.io/my-project/my-app:latest
```

**CI/CDパイプラインへの統合:**
```yaml
# Cloud Build 例
steps:
  # イメージビルド
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:latest', '.']

  # 脆弱性スキャン
  - name: 'aquasec/trivy'
    args: ['image', 'gcr.io/$PROJECT_ID/my-app:latest']

  # プッシュ
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:latest']

  # デプロイ
  - name: 'gcr.io/cloud-builders/gcloud'
    args: ['run', 'deploy', 'my-app', '--image', 'gcr.io/$PROJECT_ID/my-app:latest']
```

### Binary Authorization

イメージ署名と検証:
```bash
# イメージに署名（Cosign使用）
cosign sign --key cosign.key gcr.io/my-project/my-app:latest

# デプロイ前に署名検証
cosign verify --key cosign.pub gcr.io/my-project/my-app:latest
```

## ネットワークセキュリティ

### VPC コネクタ（Serverless VPC Access）

**VPCコネクタ作成:**
```bash
gcloud compute networks vpc-access connectors create my-vpc-connector \
  --region=us-central1 \
  --network=default \
  --range=10.8.0.0/28
```

**Cloud Run サービスに VPCコネクタを接続:**
```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --vpc-connector=my-vpc-connector \
  --allow-unauthenticated
```

**用途:**
- プライベートデータベース（Cloud SQL、Memorystore）への接続
- 内部APIへの安全なアクセス
- VPN経由のオンプレミスリソースへの接続

### Ingress 設定（internal / internal-and-cloud-load-balancing / all）

| 設定 | アクセス範囲 | 用途 |
|-----|-------------|------|
| `all` | 公開インターネット | 通常のWebアプリケーション |
| `internal-and-cloud-load-balancing` | 内部 + Load Balancer経由 | 社内アプリ、制限付きアクセス |
| `internal` | 同一プロジェクト・VPC内のみ | マイクロサービス間通信 |

```bash
# 内部アクセスのみに制限
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --ingress internal \
  --no-allow-unauthenticated
```

### Cloud Armor WAF

DDoS攻撃対策とカスタムルール:
- IPアドレスベースのフィルタリング
- 地域ベースのアクセス制限
- SQLインジェクション、XSS対策ルール

**設定手順:**
1. External HTTP(S) Load Balancer を作成
2. Cloud Armor セキュリティポリシーを定義
3. Load Balancer にポリシーをアタッチ
4. Cloud Run サービスをバックエンドに追加

## Secret Manager 連携

### シークレットの管理

**シークレット作成:**
```bash
# APIキーを保存
echo -n "my-secret-api-key" | gcloud secrets create API_KEY --data-file=-

# データベースパスワードを保存
echo -n "db-password" | gcloud secrets create DB_PASSWORD --data-file=-
```

**Cloud Run でシークレットを取得:**
```bash
# ランタイムでシークレット取得
gcloud secrets versions access latest --secret="API_KEY"
```

**環境変数として注入（推奨）:**
```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --set-secrets=API_KEY=API_KEY:latest,DB_PASSWORD=DB_PASSWORD:latest \
  --allow-unauthenticated
```

**アプリケーションコード例（Node.js）:**
```javascript
// 環境変数からシークレット取得
const apiKey = process.env.API_KEY;
const dbPassword = process.env.DB_PASSWORD;

// Secret Manager クライアント使用（代替案）
const {SecretManagerServiceClient} = require('@google-cloud/secret-manager');
const client = new SecretManagerServiceClient();

async function getSecret(secretName) {
  const [version] = await client.accessSecretVersion({
    name: `projects/my-project/secrets/${secretName}/versions/latest`,
  });
  return version.payload.data.toString();
}
```

### .dockerignore でシークレット除外

```
# .dockerignore
.env
.git
.gitignore
credentials.json
*.key
*.pem
node_modules
```

## セキュリティチェックリスト

### コンテナイメージ

- [ ] 最小限のベースイメージ（distroless / alpine / slim）使用
- [ ] 非rootユーザーでアプリケーション実行
- [ ] マルチステージビルドでビルドツールを除外
- [ ] .dockerignore でシークレット・不要ファイル除外
- [ ] 脆弱性スキャン（Trivy / Container Analysis）統合
- [ ] イメージ署名と検証（Binary Authorization / Cosign）

### IAM・認証

- [ ] 専用サービスアカウントを作成
- [ ] 最小権限の原則に従ったロール付与
- [ ] 長期キーを避けサービスアカウント偽装を使用
- [ ] リソースレベル IAM ポリシーでアクセス制限
- [ ] 未認証アクセスが必要か検証（`--no-allow-unauthenticated`）
- [ ] Cloud Audit Logs で変更履歴を追跡

### ネットワーク

- [ ] HTTPS強制（Cloud Run デフォルト）
- [ ] VPCコネクタで内部リソースに安全接続
- [ ] Ingress 設定で公開範囲を制限
- [ ] Cloud Armor でDDoS対策・WAF設定
- [ ] カスタムドメインのSSL/TLS証明書管理

### シークレット管理

- [ ] Secret Manager でパスワード・APIキー管理
- [ ] シークレットをコードやDockerイメージに埋め込まない
- [ ] 環境変数でシークレットを注入
- [ ] 定期的なシークレットローテーション
- [ ] ログにシークレットが含まれないか確認

### 監視・インシデント対応

- [ ] Cloud Audit Logs で管理操作を記録
- [ ] Cloud Logging で異常なアクセスを検知
- [ ] アラート設定（エラー率、不正アクセス試行）
- [ ] セキュリティインシデント対応手順の文書化
- [ ] 定期的なセキュリティ監査・ペネトレーションテスト

## セキュアなデプロイ例

```bash
#!/bin/bash
# セキュアなデプロイスクリプト

# 1. イメージビルド
docker build -t gcr.io/my-project/my-app:latest .

# 2. 脆弱性スキャン
trivy image gcr.io/my-project/my-app:latest

# 3. イメージ署名
cosign sign --key cosign.key gcr.io/my-project/my-app:latest

# 4. プッシュ
docker push gcr.io/my-project/my-app:latest

# 5. デプロイ（セキュア設定）
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --vpc-connector=my-vpc-connector \
  --ingress internal-and-cloud-load-balancing \
  --no-allow-unauthenticated \
  --set-secrets=API_KEY=API_KEY:latest \
  --service-account=my-app-sa@my-project.iam.gserviceaccount.com \
  --cpu 1 \
  --memory 512Mi \
  --concurrency 80 \
  --max-instances 60
```

## トラブルシューティング

### 認証エラー
```bash
# IAM ポリシー確認
gcloud run services get-iam-policy my-app --region us-central1

# サービスアカウント権限確認
gcloud projects get-iam-policy my-project \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:my-app-sa@my-project.iam.gserviceaccount.com"
```

### ネットワーク接続エラー
```bash
# VPCコネクタ一覧
gcloud compute networks vpc-access connectors list --region us-central1

# VPCコネクタ状態確認
gcloud compute networks vpc-access connectors describe my-vpc-connector --region us-central1
```

### Secret Manager アクセスエラー
```bash
# シークレットアクセス権限付与
gcloud secrets add-iam-policy-binding API_KEY \
  --member="serviceAccount:my-app-sa@my-project.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

## 参考リソース

- **Google Cloud IAM**: 最小権限ベストプラクティス
- **OWASP Top 10**: Webアプリケーションセキュリティリスク
- **CIS Benchmarks**: コンテナセキュリティ標準
- **Cloud Run セキュリティドキュメント**: 公式ガイド
