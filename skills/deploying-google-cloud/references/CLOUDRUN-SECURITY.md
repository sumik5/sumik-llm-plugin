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
| `roles/run.admin` | 完全な管理権限（すべての操作可能） | デプロイ・更新・削除・IAM変更 |
| `roles/run.developer` | サービス作成・更新・削除（IAM変更不可） | 開発者向けデプロイ |
| `roles/run.invoker` | サービス呼び出しのみ | API呼び出し、他サービスからのアクセス |
| `roles/run.viewer` | 読み取り専用（設定・ログ閲覧可能） | 監視・運用チーム |

**IAM ロール詳細権限範囲:**

**`roles/run.admin`:**
- サービスの作成・更新・削除
- IAMポリシーの変更
- トラフィック分割の設定
- リビジョン管理

**`roles/run.developer`:**
- サービスの作成・更新・削除
- 新リビジョンのデプロイ
- IAMポリシーの変更は**不可**

**`roles/run.invoker`:**
- 認証済みHTTPリクエストの送信
- サービス設定の閲覧・変更は**不可**

**`roles/run.viewer`:**
- サービス設定の閲覧
- ログ・メトリクスの閲覧
- 変更操作は一切**不可**

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

**サービスアカウント偽装（impersonation）:**

サービスアカウントキーをダウンロードせず、一時的に別のサービスアカウント権限で操作できる:

```bash
# 一時的に別のサービスアカウントで認証
gcloud auth print-access-token \
  --impersonate-service-account=cloud-run-deployer@my-project.iam.gserviceaccount.com

# サービスアカウントを偽装してCloud Runをデプロイ
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --impersonate-service-account=cloud-run-deployer@my-project.iam.gserviceaccount.com
```

**偽装の利点:**
- サービスアカウントキーのローカル保存が不要（キー漏洩リスクゼロ）
- IAM監査ログに実際のユーザーと偽装先サービスアカウントの両方が記録される
- 一時的なトークンのみ発行され、セキュリティが向上

**偽装権限の付与:**
```bash
# ユーザーにサービスアカウント偽装権限を付与
gcloud iam service-accounts add-iam-policy-binding \
  cloud-run-deployer@my-project.iam.gserviceaccount.com \
  --member="user:alice@example.com" \
  --role="roles/iam.serviceAccountTokenCreator"
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

Binary Authorization はコンテナイメージが信頼できるソースから署名されたことを検証し、未承認イメージのデプロイを防止する。

**Cosign を使用したイメージ署名と検証:**

```bash
# 1. Cosign 鍵ペアを生成
cosign generate-key-pair

# 2. イメージに署名
cosign sign --key cosign.key gcr.io/my-project/my-app:latest

# 3. デプロイ前に署名検証
cosign verify --key cosign.pub gcr.io/my-project/my-app:latest
```

**Binary Authorization ポリシーの設定:**

```bash
# Binary Authorization を有効化
gcloud services enable binaryauthorization.googleapis.com

# デフォルトポリシーを設定（すべてのイメージで署名を要求）
gcloud container binauthz policy import policy.yaml
```

**policy.yaml 例:**
```yaml
admissionWhitelistPatterns:
- namePattern: gcr.io/my-project/*
defaultAdmissionRule:
  requireAttestationsBy:
  - projects/my-project/attestors/my-attestor
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
```

**実装手順の概要:**
1. Cosign または Google Cloud KMS で署名鍵を生成
2. CI/CDパイプラインでイメージビルド後に署名
3. Binary Authorization ポリシーで署名済みイメージのみデプロイ許可
4. Cloud Run に Binary Authorization を適用

**メリット:**
- サプライチェーン攻撃の防止
- 未承認イメージの自動ブロック
- 監査ログによるコンプライアンス対応

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

**Ingress 制御モード詳細:**

**`all`（デフォルト）:**
- インターネット経由の公開アクセス許可
- IAM認証と組み合わせることで未認証アクセスを防止可能

**`internal-and-cloud-load-balancing`:**
- 同一プロジェクト内のCloud Run/Cloud Functions/App Engineからのアクセス許可
- Cloud Load Balancer経由の外部アクセス許可
- パブリックインターネットからの直接アクセスはブロック

**`internal`:**
- 同一プロジェクト・VPC内のリソースからのみアクセス可能
- Load Balancer経由も含めた外部アクセスを完全にブロック
- マイクロサービス間の内部通信に最適

**選択基準:**
- 公開APIエンドポイント → `all`
- 社内ツール・管理画面 → `internal-and-cloud-load-balancing`
- バックエンドマイクロサービス → `internal`

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

**Cloud Armor WAF ルール設定詳細:**

```bash
# セキュリティポリシーの作成
gcloud compute security-policies create my-policy \
  --description "Cloud Run protection policy"

# SQLインジェクション対策ルール追加
gcloud compute security-policies rules create 1000 \
  --security-policy my-policy \
  --expression "evaluatePreconfiguredExpr('sqli-stable')" \
  --action "deny-403" \
  --description "Block SQL injection attacks"

# XSS（クロスサイトスクリプティング）対策ルール追加
gcloud compute security-policies rules create 1001 \
  --security-policy my-policy \
  --expression "evaluatePreconfiguredExpr('xss-stable')" \
  --action "deny-403" \
  --description "Block XSS attacks"

# 特定国からのアクセスをブロック
gcloud compute security-policies rules create 2000 \
  --security-policy my-policy \
  --expression "origin.region_code == 'CN' || origin.region_code == 'KP'" \
  --action "deny-403" \
  --description "Block access from specific countries"

# レート制限（同一IPから100リクエスト/分超でブロック）
gcloud compute security-policies rules create 3000 \
  --security-policy my-policy \
  --expression "true" \
  --action "rate-based-ban" \
  --rate-limit-threshold-count 100 \
  --rate-limit-threshold-interval-sec 60 \
  --description "Rate limiting rule"

# Backend Service にポリシーをアタッチ
gcloud compute backend-services update my-backend \
  --security-policy my-policy
```

**事前設定済みルールのカテゴリ:**
- `sqli-stable`: SQLインジェクション攻撃検出
- `xss-stable`: XSS攻撃検出
- `lfi-stable`: ローカルファイルインクルージョン攻撃検出
- `rfi-stable`: リモートファイルインクルージョン攻撃検出
- `rce-stable`: リモートコード実行攻撃検出
- `methodenforcement-stable`: 許可されたHTTPメソッドのみ許可
- `scannerdetection-stable`: セキュリティスキャナーの検出

**カスタムルールの例（特定パスへのアクセス制御）:**
```bash
# /admin パスへのアクセスを特定IPのみ許可
gcloud compute security-policies rules create 4000 \
  --security-policy my-policy \
  --expression "request.path.matches('/admin.*') && !inIpRange(origin.ip, '203.0.113.0/24')" \
  --action "deny-403" \
  --description "Restrict admin access to specific IP range"
```

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
