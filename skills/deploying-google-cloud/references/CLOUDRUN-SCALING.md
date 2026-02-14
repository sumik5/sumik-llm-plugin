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

**トレードオフ分析:**

高い concurrency 設定は必要インスタンス数を削減しコストを抑えるが、アプリケーションが並列処理に最適化されていない場合、リソース競合によりレイテンシが増加する可能性がある。逆に低い concurrency はリクエストを隔離しレスポンスタイムを改善するが、インスタンス数増加によりコストが増大する。

**パフォーマンステストによる最適化:**

実際の負荷条件で concurrency を段階的にテストし、以下の指標を確認する:
- CPU使用率が80%を超えないこと
- 平均レスポンス時間が目標値（例: 200ms）を維持
- エラー率が増加しないこと

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

**External HTTP(S) Load Balancer 統合の詳細:**

External HTTP(S) Load Balancer を使用することで、複数リージョンにまたがる Cloud Run サービスへのトラフィックを自動的に分散し、ユーザーに最も近いリージョンにルーティングできる。これにより、グローバルスケーリングとリージョン障害時の自動フェイルオーバーを実現する。

**設定手順の概要:**
1. Cloud Run サービスを複数リージョンにデプロイ
2. Cloud Console から External HTTP(S) Load Balancer を作成
3. Backend として各リージョンの Cloud Run サービスを追加
4. ロードバランサーの URL が全リージョンへのトラフィックを分散

### CDN / Cloud Armor 連携

**Cloud CDN**: 静的コンテンツのキャッシング
- レスポンス速度向上
- ネットワークエグレスコスト削減

**Cloud Armor**: WAF（Web Application Firewall）機能
- DDoS攻撃対策
- IPアドレス・地域ベースのフィルタリング
- カスタムセキュリティルール

**Cloud CDN + Cloud Armor 連携設定:**

External HTTP(S) Load Balancer を通じて Cloud Run に Cloud CDN と Cloud Armor を統合できる。

```bash
# Cloud CDN を有効化（Cloud Console または gcloud CLI で設定）
# Backend Service に対して CDN を有効にする
gcloud compute backend-services update my-backend \
  --enable-cdn \
  --cache-mode=CACHE_ALL_STATIC

# Cloud Armor セキュリティポリシーの適用
gcloud compute backend-services update my-backend \
  --security-policy my-security-policy
```

**Cloud CDN のベストプラクティス:**
- `Cache-Control` ヘッダーを適切に設定してキャッシュ可能なレスポンスを定義
- 静的アセット（画像、CSS、JS）にはキャッシュTTLを長めに設定（例: 1日以上）
- 動的コンテンツには短いTTLまたはキャッシュ無効化

**Cloud Armor のルール例:**
- SQLインジェクション・XSS攻撃パターンの検出
- 特定国からのトラフィックをブロック
- レート制限（例: 同一IPから100リクエスト/分超でブロック）

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

### CPU allocation モード

`--cpu-throttling` フラグで制御:

```bash
# CPUを常に割り当て（レイテンシ重視）
gcloud run deploy my-service \
  --cpu-throttling=false \
  --region us-central1

# リクエスト時のみ割り当て（コスト重視、デフォルト）
gcloud run deploy my-service \
  --cpu-throttling=true \
  --region us-central1
```

**CPU Boost（起動時CPU割り当て増加）:**

Cloud Run はインスタンス起動時に追加CPUリソースを一時的に割り当てることで、コールドスタートのレイテンシを軽減する。この機能は自動的に有効化され、コンテナの初期化処理が高速化される。起動完了後はリクエスト処理用に標準のCPU割り当てに戻る。

**選択基準:**
- `--cpu-throttling=false`: WebSocket、ストリーミング、バックグラウンドタスク実行時に推奨
- `--cpu-throttling=true`: リクエスト駆動型のステートレスAPIに最適（コスト最小化）

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

**負荷テストツールの選択と使用例:**

```bash
# Apache Bench (ab) - シンプルなHTTPベンチマーク
ab -n 1000 -c 50 https://my-app-abcdefg-uc.a.run.app/

# wrk - 高性能HTTPベンチマーク（マルチスレッド）
wrk -t4 -c50 -d30s https://my-app-abcdefg-uc.a.run.app/

# hey - Goベースの負荷生成ツール
hey -n 1000 -c 50 https://my-app-abcdefg-uc.a.run.app/

# k6 - スクリプト可能な負荷テストツール（複雑なシナリオ対応）
k6 run loadtest.js
```

**k6 スクリプト例（loadtest.js）:**
```javascript
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 50 },  // 2分かけて50ユーザーまで増加
    { duration: '5m', target: 100 }, // 5分間100ユーザーを維持
    { duration: '2m', target: 0 },   // 2分かけて0に減少
  ],
};

export default function () {
  let response = http.get('https://my-app-abcdefg-uc.a.run.app/');
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
}
```

**負荷テストの観点:**
- **レイテンシ**: 平均・P50・P95・P99レスポンス時間を測定
- **スループット**: 秒間リクエスト数（RPS）を評価
- **エラー率**: 4xx/5xxエラーの発生率を監視
- **リソース使用率**: CPU・メモリ使用率をCloud Monitoringで確認

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
