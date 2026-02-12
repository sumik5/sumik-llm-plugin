# スケーリングとロードバランシング

Cloud Run のオートスケーリングとロードバランシング機能を活用した、動的なワークロード対応の実践ガイド。

## オートスケーリングの仕組み

### リクエスト駆動型スケーリング

Cloud Run はリクエストに応じてコンテナインスタンスを自動的にプロビジョニング・デコミッション:

- **イベント駆動型**: リクエスト到着時に新しいインスタンスを即座に起動
- **ゼロスケール**: アイドル時はインスタンスを0に縮小してコストを削減
- **イミュータブルリビジョン**: 各デプロイが不変のリビジョンとして管理される

```bash
# 基本デプロイ（自動スケーリング有効）
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

### concurrency 設定の影響

concurrency はインスタンスが同時処理できるリクエスト数を定義:

| concurrency | 影響 | 適用ケース |
|------------|------|----------|
| 低い値（1-20） | インスタンス数増加、レイテンシ低減 | CPU集約的な処理、長時間実行タスク |
| 中程度（40-80） | バランス型 | 一般的なWeb API |
| 高い値（80-100） | インスタンス数削減、コスト削減 | I/O待機が多い軽量リクエスト |

```bash
# concurrency 設定例（80リクエスト/インスタンス）
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --concurrency 80 \
  --allow-unauthenticated
```

**最適値の決定方法:**
1. パフォーマンステストで応答時間を計測
2. CPUとメモリ使用率をモニタリング
3. エラー率が増加しない範囲で調整

### min-instances / max-instances 設定

**min-instances** (最小インスタンス数):
- コールドスタートを軽減（ただしコスト増）
- 現在のCloud Runでは直接サポートされていないが、concurrency調整で類似効果を実現

**max-instances** (最大インスタンス数):
- コスト暴走を防止
- 予期しないトラフィックスパイクに対するセーフガード

```bash
# 最大インスタンス数を制限
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --max-instances 100 \
  --allow-unauthenticated
```

**推奨プラクティス:**
- 過去のピークトラフィックデータを基に上限を設定
- 10-20%のバッファを追加（例：50インスタンスが必要なら60に設定）

## ロードバランシング

### Cloud Run の内部ロードバランサー

自動的な負荷分散機能:
- **リクエストベースルーティング**: 各インスタンスの現在の負荷に基づいて配分
- **グローバル分散**: Google のグローバルネットワークを活用
- **リージョンベースルーティング**: ユーザーに最も近いリージョンに自動ルーティング

### External HTTP(S) Load Balancer 連携

複数リージョンへのトラフィック分散:

```bash
# 複数リージョンにデプロイ
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --concurrency 80 \
  --allow-unauthenticated

gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region europe-west1 \
  --concurrency 80 \
  --allow-unauthenticated
```

**メリット:**
- レイテンシの削減
- リージョン障害に対する冗長性
- グローバルユーザーベースへの最適化

### CDN / Cloud Armor 連携

**Cloud CDN**: 静的コンテンツのキャッシング
- レスポンス速度向上
- ネットワークエグレスコスト削減

**Cloud Armor**: WAF（Web Application Firewall）機能
- DDoS攻撃対策
- IPアドレス・地域ベースのフィルタリング
- カスタムセキュリティルール

## パフォーマンスチューニング

### コールドスタート対策

**問題**: 新しいインスタンス起動時の遅延（0.5-2秒）

**対策1: concurrency 調整で既存インスタンスを活用**
```bash
# concurrency を高めに設定
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --concurrency 100 \
  --allow-unauthenticated
```

**対策2: CPU Boost（起動時CPU割り当て増加）**
- Cloud Run がデフォルトで提供（明示的設定不要）
- 起動プロセスが高速化

**対策3: コンテナイメージ最適化**
```dockerfile
# 軽量ベースイメージを使用
FROM python:3.9-slim

# 不要な依存関係を削除
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
CMD ["python", "app.py"]
```

### CPU / メモリ割り当て最適化

| リソース | 低負荷 | 中負荷 | 高負荷 |
|---------|--------|--------|--------|
| CPU | 0.5 vCPU | 1 vCPU | 2 vCPU |
| メモリ | 512Mi | 1024Mi | 2048Mi |
| 適用ケース | 軽量API | 通常のWeb アプリ | データ処理、画像変換 |

```bash
# リソース割り当ての調整
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --cpu 1 \
  --memory 512Mi \
  --allow-unauthenticated
```

**最適化手順:**
1. Cloud Monitoring で CPU・メモリ使用率を確認
2. 使用率が80%超の場合はリソース増加
3. 使用率が50%未満の場合はリソース削減を検討

## ワークロード別設定テーブル

| ワークロード | concurrency | CPU | メモリ | max-instances | 特記事項 |
|------------|-------------|-----|--------|--------------|---------|
| **REST API** | 80-100 | 1 vCPU | 512Mi | 60-100 | 標準的な設定 |
| **バッチ処理** | 1-10 | 2 vCPU | 2048Mi | 20-40 | CPU集約的、同時実行制限 |
| **WebSocket** | 20-40 | 1 vCPU | 1024Mi | 50-80 | 長時間接続、メモリ重視 |
| **gRPC** | 40-60 | 1 vCPU | 1024Mi | 60-100 | HTTP/2多重化、中程度concurrency |
| **画像処理** | 10-20 | 2 vCPU | 2048Mi | 30-50 | CPU・メモリ集約的 |
| **軽量プロキシ** | 100+ | 0.5 vCPU | 256Mi | 80-120 | I/O待機主体、高concurrency |

## gcloud コマンド例

### 設定確認
```bash
# サービスの詳細情報を取得
gcloud run services describe my-app --region us-central1
```

### スケーリング設定の更新
```bash
# concurrency と max-instances を同時更新
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --concurrency 60 \
  --max-instances 80 \
  --allow-unauthenticated
```

### 動的スケーリングスクリプト
```bash
#!/bin/bash
# 時間帯に応じた設定調整

HOUR=$(date +%H)

if [ $HOUR -ge 18 ] && [ $HOUR -le 23 ]; then
  # ピーク時間: パフォーマンス優先
  CONCURRENCY=80
  MAX_INSTANCES=100
else
  # オフピーク: コスト優先
  CONCURRENCY=100
  MAX_INSTANCES=50
fi

gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --concurrency $CONCURRENCY \
  --max-instances $MAX_INSTANCES \
  --allow-unauthenticated
```

### 負荷テスト
```bash
# Apache Bench による負荷テスト
ab -n 1000 -c 50 https://my-app-abcdefg-uc.a.run.app/

# wrk による負荷テスト
wrk -t4 -c50 -d30s https://my-app-abcdefg-uc.a.run.app/
```

## トラフィック分割（Canary / Blue-Green デプロイ）

### Canary デプロイ
```bash
# 新リビジョンに30%のトラフィックを割り当て
gcloud run services update-traffic my-app \
  --to-revisions=v1=70,v2=30
```

### Blue-Green デプロイ
```bash
# 全トラフィックを新リビジョンに切り替え
gcloud run services update-traffic my-app \
  --to-revisions=v2=100
```

### ロールバック
```bash
# 安定版リビジョンに戻す
gcloud run services update-traffic my-app \
  --to-revisions=stable=100
```

## モニタリングとアラート

### 主要メトリクス
```mql
# リクエストレイテンシ（平均）
fetch cloud_run_revision
| metric 'run.googleapis.com/request_latencies'
| filter (resource.labels.service_name == "my-app")
| align mean(1m)
| every 1m

# アクティブインスタンス数
fetch cloud_run_revision
| metric 'run.googleapis.com/instance_count'
| filter (resource.labels.service_name == "my-app")
| align sum(1m)
| every 1m

# リクエスト数（レート）
fetch cloud_run_revision
| metric 'run.googleapis.com/request_count'
| filter (resource.service_name == "my-app")
| align rate(1m)
| every 1m
```

### アラート設定例
- **高レイテンシ**: 平均応答時間が500ms超で5分継続
- **エラー率上昇**: HTTP 5xxエラーが5%超
- **リソース枯渇**: CPU使用率が80%超で10分継続

## チェックリスト: スケーリング最適化

- [ ] 負荷テストで最適な concurrency 値を決定
- [ ] 過去のトラフィックデータから max-instances を設定
- [ ] CPU・メモリ使用率を継続的にモニタリング
- [ ] コールドスタート対策（コンテナイメージ最適化）
- [ ] 複数リージョンへのデプロイ（グローバルユーザー向け）
- [ ] トラフィック分割でカナリアデプロイをテスト
- [ ] Cloud Monitoring ダッシュボードの作成
- [ ] コスト異常時のアラート設定
- [ ] 定期的な設定見直し（月次/四半期）
