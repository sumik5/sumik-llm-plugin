# デプロイ（Cloud Runへの展開戦略）

Cloud Runへのデプロイは、gcloud CLI、Cloud Console、ソースベースデプロイなど複数の方法がある。本リファレンスではデプロイ戦略の選択、トラフィック分割、ロールバック手順を含む包括的なデプロイガイドを提供する。

## デプロイ戦略

### デプロイ方式の選択

| 方式 | 特徴 | 適用場面 | メリット | デメリット |
|-----|------|---------|---------|---------|
| gcloud CLI | コマンドライン | CI/CD、自動化 | スクリプト化可能、細かい制御 | GUIなし |
| Cloud Console | Web UI | 手動デプロイ、初心者 | 視覚的、設定が簡単 | 自動化困難 |
| ソースベース | ソースコードから直接 | Dockerfileなし | Buildpack自動選択 | カスタマイズ制限 |
| Terraform | IaC | インフラコード管理 | バージョン管理可能 | 学習コスト高 |

### デプロイ戦略の種類

#### 1. 直接デプロイ

新しいリビジョンを即座に100%トラフィックに適用する。

**用途:**
- 開発環境
- 内部ツール
- 影響範囲が小さい変更

**gcloud コマンド:**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:v2.0.0 \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

#### 2. Blue-Green デプロイ

2つの環境を用意し、トラフィックを一度に切り替える。

**用途:**
- ミッションクリティカルなアプリケーション
- 大規模な変更
- 即座にロールバック可能にしたい場合

**手順:**

```bash
# Green環境をデプロイ（トラフィックは受け取らない）
gcloud run deploy my-app-green \
  --image gcr.io/my-project/my-app:v2.0.0 \
  --platform managed \
  --region us-central1 \
  --no-traffic

# 動作確認後、トラフィックを100%切り替え
gcloud run services update-traffic my-app \
  --to-revisions=my-app-green=100
```

#### 3. Canary デプロイ

新バージョンに段階的にトラフィックを移行する。

**用途:**
- 本番環境での段階的検証
- リスク最小化
- パフォーマンステストを兼ねる

**手順:**

```bash
# 新リビジョンをデプロイ（トラフィックは受け取らない）
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:v2.0.0 \
  --platform managed \
  --region us-central1 \
  --no-traffic

# 20%のトラフィックを新リビジョンに割り当て
gcloud run services update-traffic my-app \
  --to-revisions=v1=80,v2=20

# 問題なければ50%に増やす
gcloud run services update-traffic my-app \
  --to-revisions=v1=50,v2=50

# 最終的に100%に移行
gcloud run services update-traffic my-app \
  --to-revisions=v2=100
```

## gcloud CLI デプロイ

### 基本コマンド

**最小限のデプロイ:**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1
```

**全オプション指定:**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:v1.0.0 \
  --platform managed \
  --region us-central1 \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 10 \
  --min-instances 1 \
  --concurrency 80 \
  --timeout 300s \
  --set-env-vars "PORT=8080,DEBUG=false,API_ENDPOINT=https://api.example.com" \
  --vpc-connector my-vpc-connector \
  --allow-unauthenticated
```

### 主要オプション解説

| オプション | 説明 | デフォルト値 | 推奨設定 |
|----------|------|------------|---------|
| `--image` | コンテナイメージURL | 必須 | タグ付きイメージ（`:latest`避ける） |
| `--platform` | `managed` 固定 | managed | - |
| `--region` | デプロイリージョン | 必須 | ユーザーに近いリージョン |
| `--memory` | メモリ割り当て | 256Mi | 512Mi～1Gi |
| `--cpu` | CPU数 | 1 | 1（軽量）～2（高負荷） |
| `--max-instances` | 最大インスタンス数 | 100 | コスト制限に応じて設定 |
| `--min-instances` | 最小インスタンス数 | 0 | 0（コールドスタート許容）～1（常時起動） |
| `--concurrency` | 同時リクエスト数/インスタンス | 80 | 50～100（アプリ特性による） |
| `--timeout` | リクエストタイムアウト | 300s | 60s～3600s |
| `--allow-unauthenticated` | 認証なしアクセス許可 | 認証必須 | 公開APIは指定 |

### リージョン選択ガイド

| リージョン | 場所 | 用途 |
|----------|------|------|
| `us-central1` | アイオワ | 北米ユーザー |
| `us-east1` | サウスカロライナ | 北米東海岸 |
| `us-west1` | オレゴン | 北米西海岸 |
| `asia-northeast1` | 東京 | 日本ユーザー |
| `asia-northeast2` | 大阪 | 日本（東京障害時の冗長化） |
| `europe-west1` | ベルギー | 欧州ユーザー |

**マルチリージョン戦略:**

```bash
# 複数リージョンにデプロイ
for region in us-central1 asia-northeast1 europe-west1; do
  gcloud run deploy my-app \
    --image gcr.io/my-project/my-app:latest \
    --platform managed \
    --region $region \
    --allow-unauthenticated
done
```

## Cloud Console デプロイ

### 手順

1. **Cloud Console にアクセス**
   - https://console.cloud.google.com/
   - プロジェクトセレクター（画面上部）から対象プロジェクトを選択

2. **Cloud Run ページに移動**
   - 左側ナビゲーションメニュー → Cloud Run
   - 既存サービス一覧と新規作成オプションが表示される

3. **サービス作成**
   - 「サービスを作成」（Create Service）ボタンをクリック
   - デプロイウィザードが起動

4. **コンテナイメージの指定**
   - コンテナイメージURL: `gcr.io/my-project/my-app:latest`
   - 「コンテナイメージを選択」からGoogle Container RegistryまたはArtifact Registryを参照可能
   - イメージプレビューと基本メタデータが表示される

5. **サービス設定**
   - サービス名: `my-app`（公開URLの一部となる）
   - リージョン: `us-central1`（ユーザーベースに近いリージョンを選択）

6. **リソース設定**
   - メモリ割り当て: 512 MiB（ドロップダウンまたはスライダーで選択）
   - CPU: 1 vCPU
   - 同時実行リクエスト数: 80（各インスタンスが処理できる同時リクエスト数）
   - 最大インスタンス数: 10（コスト制限に応じて設定）

7. **環境変数設定**
   - 環境変数パネルで「変数を追加」をクリック
   - キーと値のペアを入力:
     - `PORT=8080`
     - `DEBUG=false`
     - `API_ENDPOINT=https://api.example.com`

8. **ネットワーク設定**
   - 認証: 「未認証の呼び出しを許可」を選択（公開APIの場合）
   - 内部通信の場合はVPCコネクタを設定可能

9. **詳細設定（オプション）**
   - タイムアウト値の設定
   - 最小インスタンス数（常時起動インスタンス）
   - Cloud SQL接続設定

10. **デプロイ実行**
    - 設定サマリーページで全項目を確認
    - 「作成」（Create）ボタンをクリック
    - リアルタイムの進捗インジケーターが表示される
    - デプロイ完了後、サービスURLが表示される

### デプロイ後の管理

**リビジョン管理:**
- サービス詳細ページで「リビジョン」タブを表示
- 各リビジョンの履歴、デプロイ時刻、イメージタグを確認
- ワンクリックで以前のリビジョンにロールバック可能

**トラフィック分割設定（GUI）:**
- 「リビジョン」タブで「トラフィックを編集」をクリック
- スライダーコントロールで各リビジョンへのトラフィック割合を調整:
  - v1: 80%
  - v2: 20%
- パーセンテージフィールドで直接数値入力も可能
- 設定適用後、数秒～数十秒で反映

**パフォーマンス監視:**
- 「メトリクス」タブでリクエスト数、レイテンシ、エラー率を可視化
- 「ログ」タブでリアルタイムログストリームを表示
- アラート設定も可能

### GUI のメリット・デメリット

| メリット | デメリット |
|---------|----------|
| 視覚的で理解しやすい | 自動化困難 |
| 設定ミスが少ない | 大量のサービスには不向き |
| 初心者に優しい | バージョン管理できない |
| トラフィック分割がスライダーで直感的 | 大規模チームでの並行作業に不向き |
| リアルタイムログ・メトリクス確認が簡単 | スクリプト化・再現性が低い |

## ソースベースデプロイ（Buildpack）

Dockerfileなしでソースコードから直接デプロイする。

### 対応言語

| 言語 | Buildpack | デプロイコマンド |
|-----|-----------|----------------|
| Node.js | Google Cloud Buildpacks | `gcloud run deploy --source .` |
| Python | Google Cloud Buildpacks | `gcloud run deploy --source .` |
| Go | Google Cloud Buildpacks | `gcloud run deploy --source .` |
| Java | Google Cloud Buildpacks | `gcloud run deploy --source .` |

### デプロイ手順

```bash
# ソースコードのディレクトリに移動
cd my-app/

# ソースベースデプロイ
gcloud run deploy my-app \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

**実行内容:**

1. Cloud Buildがソースコードを検出
2. 言語に応じたBuildpackを自動選択
3. コンテナイメージをビルド
4. Artifact Registryにプッシュ
5. Cloud Runにデプロイ

### Buildpack のカスタマイズ

**プロジェクト.toml で設定:**

```toml
[build]
builder = "gcr.io/buildpacks/builder:v1"

[[build.env]]
name = "GOOGLE_RUNTIME_VERSION"
value = "3.9"

[[build.env]]
name = "GOOGLE_ENTRYPOINT"
value = "python app.py"
```

## 環境変数・シークレット設定

### 環境変数の設定

**デプロイ時に指定:**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --set-env-vars "PORT=8080,DEBUG=false,API_ENDPOINT=https://api.example.com"
```

**既存サービスの更新:**

```bash
gcloud run services update my-app \
  --set-env-vars "NEW_VAR=value"
```

**環境変数の削除:**

```bash
gcloud run services update my-app \
  --remove-env-vars "OLD_VAR"
```

### Secret Manager 連携

**シークレットの作成:**

```bash
# シークレット作成
echo -n "mysecretpassword" | gcloud secrets create db-password --data-file=-

# シークレットの確認
gcloud secrets versions access latest --secret=db-password
```

**Cloud Run にシークレットをマウント:**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --update-secrets "DATABASE_PASSWORD=db-password:latest"
```

**複数シークレットの設定:**

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --update-secrets "DATABASE_PASSWORD=db-password:latest,API_KEY=api-key:latest"
```

**アプリケーションでの読み取り:**

```python
import os

# 環境変数として読み取り可能
database_password = os.environ.get('DATABASE_PASSWORD')
api_key = os.environ.get('API_KEY')
```

## Traffic Splitting（トラフィック分割）

### トラフィック割り当て

**リビジョン一覧確認:**

```bash
gcloud run revisions list --service my-app --region us-central1
```

**トラフィック分割設定:**

```bash
# 80:20 の分割
gcloud run services update-traffic my-app \
  --to-revisions=v1=80,v2=20

# 複数リビジョンへの分割
gcloud run services update-traffic my-app \
  --to-revisions=v1=50,v2=30,v3=20
```

### Canary デプロイの段階的割り当て手順

Canaryデプロイは、新バージョンに段階的にトラフィックを移行し、本番環境でリスクを最小化しながら検証する手法です。

#### ステップ1: 新リビジョンをデプロイ（トラフィックなし）

```bash
# トラフィックを受け取らない新リビジョンをデプロイ
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:v2.0.0 \
  --platform managed \
  --region us-central1 \
  --no-traffic
```

**確認:**

```bash
# リビジョン一覧とトラフィック割り当てを確認
gcloud run revisions list --service my-app --region us-central1

# 現在のトラフィック設定を確認
gcloud run services describe my-app --region us-central1 \
  --format="value(status.traffic)"
```

#### ステップ2: 初期Canaryトラフィック（10%）割り当て

```bash
# 10%のトラフィックを新リビジョンに割り当て
gcloud run services update-traffic my-app \
  --to-revisions=v1=90,v2=10 \
  --region us-central1
```

**初期フェーズの監視（10分間）:**

```bash
# エラーレート確認
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.revision_name=v2 AND severity=ERROR" \
  --limit 50

# レイテンシ確認（Cloud Monitoringで視覚化推奨）
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_latencies"'
```

**判定基準:**
- エラーレート < 1%
- P95レイテンシが旧バージョンの±20%以内
- 致命的なログが存在しない

#### ステップ3: 中間Canaryトラフィック（20% → 50%）

問題が検出されなければ、段階的に割合を増やします。

```bash
# 20%に増加
gcloud run services update-traffic my-app \
  --to-revisions=v1=80,v2=20 \
  --region us-central1

# 15分間監視後、問題なければ50%に増加
gcloud run services update-traffic my-app \
  --to-revisions=v1=50,v2=50 \
  --region us-central1
```

**50%フェーズの監視（30分間）:**

```bash
# 両リビジョンのメトリクス比較
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count"' \
  --interval-start-time="30 minutes ago"

# 特定エンドポイントのエラー確認
gcloud logging read \
  "resource.type=cloud_run_revision AND httpRequest.requestUrl=~'/api/critical'" \
  --limit 100
```

**A/Bテスト機会:**
- 50%割り当て時は、新旧バージョンのパフォーマンス比較に最適
- ビジネスメトリクス（コンバージョン率、セッション時間）も確認

#### ステップ4: 最終Canaryトラフィック（100%）

全監視基準をクリアしたら、100%に移行します。

```bash
# 全トラフィックを新リビジョンに移行
gcloud run services update-traffic my-app \
  --to-revisions=v2=100 \
  --region us-central1
```

**完全移行後の監視（24時間）:**

```bash
# 日次エラーサマリー
gcloud logging read \
  "resource.type=cloud_run_revision AND severity>=ERROR" \
  --limit 200 \
  --format="table(timestamp,severity,jsonPayload.message)"
```

#### Canary中の問題検出とロールバック

**問題を検知した場合の即座対応:**

```bash
# 新リビジョンへのトラフィックを停止
gcloud run services update-traffic my-app \
  --to-revisions=v1=100 \
  --region us-central1
```

**段階的ロールバック（推奨）:**

```bash
# 段階的にトラフィックを減少
gcloud run services update-traffic my-app \
  --to-revisions=v1=80,v2=20  # まず80:20に戻す

# 問題が継続する場合は完全にロールバック
gcloud run services update-traffic my-app \
  --to-revisions=v1=100
```

#### Canaryデプロイの推奨タイムライン

| フェーズ | トラフィック割合 | 監視時間 | 判定基準 |
|---------|---------------|---------|---------|
| **初期** | v1:90, v2:10 | 10分 | エラー率<1%, レイテンシ安定 |
| **拡大1** | v1:80, v2:20 | 15分 | エラー率<2%, CPU/メモリ正常 |
| **拡大2** | v1:50, v2:50 | 30分 | パフォーマンスが旧版と同等 |
| **最終** | v2:100 | 24時間 | ビジネスメトリクス正常 |

#### 自動Canaryスクリプト例

```bash
#!/bin/bash
# Automated Canary Deployment Script

SERVICE="my-app"
REGION="us-central1"
NEW_REVISION="v2"
OLD_REVISION="v1"

# Phase 1: 10%
gcloud run services update-traffic $SERVICE \
  --to-revisions=$OLD_REVISION=90,$NEW_REVISION=10 \
  --region $REGION

echo "Phase 1: 10% deployed. Monitoring for 10 minutes..."
sleep 600

# Check error rate (simplified)
ERROR_COUNT=$(gcloud logging read \
  "resource.labels.revision_name=$NEW_REVISION AND severity=ERROR" \
  --limit 1000 --format="value(timestamp)" | wc -l)

if [ $ERROR_COUNT -gt 10 ]; then
  echo "Error threshold exceeded. Rolling back..."
  gcloud run services update-traffic $SERVICE \
    --to-revisions=$OLD_REVISION=100 \
    --region $REGION
  exit 1
fi

# Phase 2: 50%
gcloud run services update-traffic $SERVICE \
  --to-revisions=$OLD_REVISION=50,$NEW_REVISION=50 \
  --region $REGION

echo "Phase 2: 50% deployed. Monitoring for 30 minutes..."
sleep 1800

# Phase 3: 100%
gcloud run services update-traffic $SERVICE \
  --to-revisions=$NEW_REVISION=100 \
  --region $REGION

echo "Canary deployment complete. Full traffic on $NEW_REVISION."
```

### Blue-Green デプロイの詳細実装ステップ

Blue-Greenデプロイは、2つの完全な環境（BlueとGreen）を維持し、トラフィックを一度に切り替えることでリスクを最小化する手法です。

**前提条件:**
- 現在の本番環境（Blue）: リビジョン `v1` がトラフィック100%を受信中
- 新バージョン（Green）: イメージ `v2.0.0` をデプロイ予定

#### ステップ1: Green環境のデプロイ（トラフィックなし）

```bash
# トラフィックを受け取らない新リビジョンをデプロイ
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:v2.0.0 \
  --no-traffic \
  --region us-central1
```

**重要ポイント:**
- `--no-traffic` フラグにより、新リビジョンはトラフィックを受け取らない
- この時点でBlue（v1）は100%のトラフィックを継続受信
- Green（v2）は本番環境にデプロイされているが、ユーザーには公開されていない

#### ステップ2: Green環境の検証

**専用URLでのテスト:**

```bash
# 新リビジョン専用のURLを取得
NEW_URL=$(gcloud run revisions describe v2 \
  --region us-central1 \
  --format="value(status.url)")

# 専用URLでヘルスチェック
curl -I $NEW_URL/health

# 機能テスト実行
curl -X POST $NEW_URL/api/test -d '{"test": "data"}'
```

**検証項目:**
- ヘルスチェックエンドポイントが200を返すか
- 主要APIエンドポイントが正常動作するか
- データベース接続が確立されるか
- レイテンシが許容範囲内か
- エラーログに異常がないか

#### ステップ3: トラフィックの一括切り替え

検証が完了したら、全トラフィックをGreenに切り替えます。

```bash
# 100%のトラフィックを新リビジョンに切り替え
gcloud run services update-traffic my-app \
  --to-revisions=v2=100 \
  --region us-central1
```

**切り替え時の挙動:**
- 数秒以内に全トラフィックがv2に切り替わる
- v1のインスタンスは即座に削除されず、既存リクエストの完了を待つ
- DNSキャッシュにより、一部ユーザーは数十秒間v1にアクセスする可能性あり

#### ステップ4: Green環境の監視

切り替え後、すぐに監視を開始します。

```bash
# リアルタイムログ確認
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=my-app AND resource.labels.revision_name=v2" \
  --limit 50 \
  --format json

# エラーレート確認
gcloud logging read \
  "resource.type=cloud_run_revision AND severity=ERROR" \
  --limit 50
```

**監視項目:**
- エラーレート（5分間で5%以下を維持）
- レイテンシ（P95が許容範囲内）
- CPU/メモリ使用率
- リクエスト成功率

#### ステップ5: 問題発生時の即座ロールバック

問題を検知したら、即座にBlueに戻します。

```bash
# 全トラフィックを安定版（v1）に戻す
gcloud run services update-traffic my-app \
  --to-revisions=v1=100 \
  --region us-central1
```

**ロールバックの利点:**
- Blue環境（v1）は削除されていないため、即座に切り戻し可能
- ダウンタイムは数秒～数十秒
- データ整合性の問題が最小化される

#### リスクプロファイル別ガイダンス

| リスクレベル | 推奨デプロイ戦略 | 理由 |
|------------|----------------|------|
| **低リスク** | 直接デプロイ | 開発環境、内部ツール |
| **中リスク** | Canaryデプロイ | 段階的検証が可能 |
| **高リスク** | Blue-Green | ミッションクリティカル、即座ロールバック必須 |
| **最高リスク** | Blue-Green + 段階的検証 | 金融、医療、大規模eコマース |

## ロールバック手順

### 即座にロールバック

**前のリビジョンに100%戻す:**

```bash
gcloud run services update-traffic my-app \
  --to-revisions=v1=100
```

### 段階的ロールバック

**80%を旧バージョンに戻す:**

```bash
gcloud run services update-traffic my-app \
  --to-revisions=v1=80,v2=20
```

### 特定のリビジョンを指定

**リビジョンIDを指定:**

```bash
# リビジョンIDを確認
gcloud run revisions list --service my-app --region us-central1

# 特定のリビジョンにロールバック
gcloud run services update-traffic my-app \
  --to-revisions=my-app-00001-abc=100
```

### イメージダイジェストでのロールバック

**正確なイメージバージョンにロールバック:**

```bash
# イメージダイジェストを確認
docker inspect --format='{{index .RepoDigests 0}}' gcr.io/my-project/my-app:v1.0.0

# ダイジェストを指定してデプロイ
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app@sha256:abc123... \
  --region us-central1
```

## Revision 管理

### リビジョン一覧

```bash
# リビジョン一覧（デフォルト: 最新10件）
gcloud run revisions list --service my-app --region us-central1

# 全リビジョン表示
gcloud run revisions list --service my-app --region us-central1 --limit=999
```

### リビジョン詳細確認

```bash
gcloud run revisions describe my-app-00001-abc \
  --region us-central1
```

### 古いリビジョンの削除

```bash
# 特定リビジョンを削除
gcloud run revisions delete my-app-00001-abc --region us-central1

# トラフィックを受けていないリビジョンを一括削除
gcloud run revisions list --service my-app --region us-central1 --format="value(metadata.name)" | \
  while read revision; do
    traffic=$(gcloud run services describe my-app --region us-central1 --format="value(status.traffic[?revisionName=='$revision'].percent)")
    if [ -z "$traffic" ]; then
      echo "Deleting unused revision: $revision"
      gcloud run revisions delete $revision --region us-central1 --quiet
    fi
  done
```

## デプロイ自動化スクリプト

### シンプルなデプロイスクリプト

**deploy.sh:**

```bash
#!/bin/bash
set -e

PROJECT_ID="my-project"
SERVICE_NAME="my-app"
REGION="us-central1"
IMAGE_TAG=$(git rev-parse --short HEAD)

# イメージビルド
docker build -t gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG .

# イメージプッシュ
docker push gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG

# Cloud Runにデプロイ
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG \
  --platform managed \
  --region $REGION \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 10 \
  --set-env-vars "PORT=8080,DEBUG=false" \
  --allow-unauthenticated

echo "Deployment completed: gcr.io/$PROJECT_ID/$SERVICE_NAME:$IMAGE_TAG"
```

### Canaryデプロイスクリプト

**canary-deploy.sh:**

```bash
#!/bin/bash
set -e

SERVICE_NAME="my-app"
REGION="us-central1"
NEW_REVISION=$1
CANARY_PERCENT=${2:-20}

if [ -z "$NEW_REVISION" ]; then
  echo "Usage: $0 <new-revision> [canary-percent]"
  exit 1
fi

# 現在のリビジョンを取得
CURRENT_REVISION=$(gcloud run services describe $SERVICE_NAME --region $REGION --format="value(status.traffic[0].revisionName)")

echo "Current revision: $CURRENT_REVISION"
echo "New revision: $NEW_REVISION"
echo "Canary percent: $CANARY_PERCENT"

# Canaryトラフィック割り当て
STABLE_PERCENT=$((100 - CANARY_PERCENT))
gcloud run services update-traffic $SERVICE_NAME \
  --to-revisions=$CURRENT_REVISION=$STABLE_PERCENT,$NEW_REVISION=$CANARY_PERCENT

echo "Canary deployment complete. Monitor metrics and run:"
echo "  gcloud run services update-traffic $SERVICE_NAME --to-revisions=$NEW_REVISION=100"
echo "to complete the rollout, or:"
echo "  gcloud run services update-traffic $SERVICE_NAME --to-revisions=$CURRENT_REVISION=100"
echo "to rollback."
```

## トラブルシューティング

### デプロイが失敗する

**エラー確認:**

```bash
# デプロイログを確認
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=my-app" --limit 50
```

**よくある原因:**

| エラー | 原因 | 対処方法 |
|-------|------|---------|
| "Container failed to start" | PORTをリッスンしていない | 環境変数 `PORT` を読み取る実装を追加 |
| "Permission denied" | IAMロールが不足 | Cloud Run Admin ロールを付与 |
| "Image not found" | イメージが存在しない | イメージURLを確認、pushを実行 |
| "Quota exceeded" | リソース制限超過 | 割り当てを増やす申請 |

### リビジョンが表示されない

**原因:**
- デプロイが完了していない
- リージョンが間違っている

**確認コマンド:**

```bash
# 全リージョンのサービスを確認
gcloud run services list --platform managed
```

### トラフィック分割が反映されない

**確認コマンド:**

```bash
# 現在のトラフィック設定を確認
gcloud run services describe my-app --region us-central1 --format="value(status.traffic)"
```

**DNS伝播待ち:**
- トラフィック分割の反映には数秒～数十秒かかる
- `curl` で複数回リクエストして確認

```bash
for i in {1..10}; do
  curl -s https://my-app-xyz-uc.a.run.app | grep "version"
done
```
