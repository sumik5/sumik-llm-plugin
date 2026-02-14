# コスト最適化

Cloud Run の料金モデルを理解し、リソース最適化とコスト管理戦略を実装するための実践ガイド。

## 料金モデル

### CPU allocation: always-on vs request-based 詳細比較

| モード | 課金対象 | 用途 | コスト影響 |
|-------|---------|------|----------|
| **Request-based** | リクエスト処理中のみ | I/O待機が多いワークロード | 低コスト（推奨） |
| **Always-on** | インスタンスが起動している間常時 | CPU集約的な処理 | 高コスト |

```bash
# Request-based CPU（デフォルト、推奨）
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --cpu-throttling \
  --allow-unauthenticated

# Always-on CPU
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --no-cpu-throttling \
  --allow-unauthenticated
```

**詳細比較表:**

| 項目 | Request-based | Always-on |
|------|---------------|-----------|
| **課金モデル** | リクエスト処理時間のみ | インスタンス起動中常時（アイドル時も課金） |
| **適用ケース** | REST API、軽量Webアプリ | WebSocket、バックグラウンドタスク、ストリーミング |
| **コスト差** | 低コスト（推奨） | 約2-3倍のコスト |
| **アイドル時のCPU** | 0%（スロットリング） | 利用可能（常時割り当て） |
| **コールドスタート影響** | やや長い（CPU割り当て待機） | 短い（常時CPU利用可能） |

**選択基準:**
- **Request-based**: ステートレスなリクエスト駆動型アプリケーション（99%のケースで推奨）
- **Always-on**: リクエスト外でもCPU処理が必要な場合（例: WebSocketのハートビート、定期的なバックグラウンド処理）

**コスト削減のポイント:**
- アイドル時間が多いアプリケーションでは Request-based の方が圧倒的に有利
- Always-on が必要な場合も、concurrency を高めてインスタンス数を削減

### メモリ・CPU・ネットワーク課金

**課金要素:**

| 要素 | 単位 | 課金方法 |
|------|-----|---------|
| **CPU** | vCPU-秒 | リクエスト処理時間 × 割り当てvCPU |
| **メモリ** | GiB-秒 | リクエスト処理時間 × 割り当てメモリ |
| **リクエスト** | 回数 | 処理されたリクエスト数 |
| **ネットワーク Egress** | GB | 外部への送信データ量 |

**計算例:**
- リクエスト: 10,000件/日
- 平均処理時間: 0.2秒
- CPU: 1 vCPU
- メモリ: 512Mi

```
CPU時間 = 10,000 × 0.2 = 2,000 vCPU-秒
メモリ時間 = 10,000 × 0.2 × 0.5 = 1,000 GiB-秒
リクエスト課金 = 10,000 リクエスト
```

### 無料枠の活用

**Cloud Run 無料枠（月次）:**

| リソース | 月次無料枠 |
|---------|-----------|
| **CPU時間** | 180,000 vCPU-秒 |
| **メモリ** | 360,000 GiB-秒 |
| **リクエスト** | 2,000,000回 |
| **ネットワーク Egress** | 1 GB（北米内） |

**具体的な使用可能量の例:**
- 1 vCPU、512MiB、平均200msのリクエストの場合
  - CPU: 180,000 vCPU-秒 ÷ 0.2秒 = 900,000リクエスト/月
  - メモリ: 360,000 GiB-秒 ÷ (0.5 GiB × 0.2秒) = 3,600,000リクエスト/月
  - リクエスト数: 2,000,000リクエスト/月
  - **実質的な上限**: 900,000リクエスト/月（CPU時間が先に枯渇）

**活用戦略:**
- 小規模プロジェクトは完全無料で運用可能
- 開発・ステージング環境を無料枠内に収める
- 複数の小規模サービスを無料枠内で並行運用

## コスト最適化戦略

### min-instances を最小限に

**問題**: min-instances を設定するとアイドル時も課金
**推奨**: Cloud Run のゼロスケール機能を活用

```bash
# ❌ 避けるべき設定（常時コスト発生）
# Cloud Run は min-instances パラメータを直接サポートしていない
# concurrency と max-instances で制御

# ✅ 推奨設定（ゼロスケール活用）
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --concurrency 100 \
  --max-instances 60 \
  --allow-unauthenticated
```

**コールドスタート対策（min-instances不要）:**
- concurrency を高めに設定
- コンテナイメージを軽量化
- Cloud Run の CPU Boost を活用（自動）

### concurrency を最大化

高い concurrency = 必要インスタンス数削減 = コスト削減

**最適化手順:**
1. 負荷テストで上限を特定
2. エラー率が上昇しない範囲で段階的に増加
3. レイテンシとのトレードオフを評価

```bash
# concurrency を段階的に増加
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --concurrency 100 \
  --allow-unauthenticated
```

**ワークロード別推奨値:**
- 軽量API: 80-100
- データ処理: 10-20
- CPU集約的: 1-10

### CPU-on-request モード活用

```bash
# CPU throttling 有効（request-based、デフォルト）
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --cpu-throttling \
  --allow-unauthenticated
```

**効果:**
- アイドル時のCPU課金ゼロ
- リクエスト処理時のみ課金

### Committed Use Discounts (CUD)

長期利用でコスト削減（1年/3年契約）:

| 契約期間 | 割引率 |
|---------|--------|
| **1年** | 約37% |
| **3年** | 最大57% |

**対象リソース:**
- Cloud Run の CPU・メモリ使用量
- 予測可能な定常トラフィックに適用

**設定手順:**
1. Google Cloud Console の Billing セクションにアクセス
2. "Commitments" → "Purchase a commitment" を選択
3. リソースタイプ（CPU・メモリ）と契約期間を選定
4. 予測使用量に基づいてコミットメント量を設定

**適用基準:**
- 月次のベースライン使用量を分析
- 変動の少ない定常トラフィックに対して CUD を適用
- ピークトラフィック分は従量課金のままにしてコスト変動を吸収

**例: 月次平均10,000 vCPU-時間の場合**
- CUD で8,000 vCPU-時間をカバー（80%）
- 残り2,000 vCPU-時間は従量課金（ピーク対応）

**注意事項:**
- コミットメント未達でも課金される（契約量が最低課金額）
- トラフィック予測が困難な場合は従量課金のまま運用推奨

## モニタリングと予算管理

### Cloud Billing アラート

**予算アラート設定:**
```bash
# 月額$100予算、80%到達でアラート
gcloud billing budgets create \
  --billing-account=BILLING_ACCOUNT_ID \
  --display-name="Cloud Run Monthly Budget" \
  --budget-amount=100.00 \
  --threshold-rule=percent=80 \
  --threshold-rule=percent=100
```

**通知チャネル追加:**
```bash
# メール通知
gcloud billing budgets update BUDGET_ID \
  --add-notifications-rule=pubsub-topic=projects/my-project/topics/budget-alerts
```

### コスト分析ダッシュボード

**BigQuery でコスト分析（SQLクエリテンプレート）:**

```sql
-- Cloud Run の日次コスト集計
SELECT
  DATE(usage_start_time) AS day,
  SUM(cost) AS daily_cost
FROM
  `my-project.billing_dataset.gcp_billing_export_v1_*`
WHERE
  service.description = 'Cloud Run'
GROUP BY day
ORDER BY day;

-- リソース別コスト内訳
SELECT
  sku.description AS resource_type,
  SUM(cost) AS total_cost
FROM
  `my-project.billing_dataset.gcp_billing_export_v1_*`
WHERE
  service.description = 'Cloud Run'
  AND usage_start_time BETWEEN '2024-01-01' AND '2024-01-31'
GROUP BY resource_type
ORDER BY total_cost DESC;

-- サービス別コスト分析（トップ10）
SELECT
  resource.name AS service_name,
  SUM(cost) AS total_cost,
  SUM(usage.amount) AS total_usage,
  sku.description AS resource_type
FROM
  `my-project.billing_dataset.gcp_billing_export_v1_*`
WHERE
  service.description = 'Cloud Run'
  AND usage_start_time BETWEEN TIMESTAMP('2024-01-01') AND TIMESTAMP('2024-01-31')
GROUP BY service_name, resource_type
ORDER BY total_cost DESC
LIMIT 10;

-- CPU vs メモリ コスト比較
SELECT
  DATE(usage_start_time) AS day,
  SUM(CASE WHEN sku.description LIKE '%CPU%' THEN cost ELSE 0 END) AS cpu_cost,
  SUM(CASE WHEN sku.description LIKE '%Memory%' THEN cost ELSE 0 END) AS memory_cost,
  SUM(CASE WHEN sku.description LIKE '%Request%' THEN cost ELSE 0 END) AS request_cost
FROM
  `my-project.billing_dataset.gcp_billing_export_v1_*`
WHERE
  service.description = 'Cloud Run'
  AND usage_start_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY day
ORDER BY day;

-- コスト異常検出（前週比較）
WITH weekly_cost AS (
  SELECT
    EXTRACT(WEEK FROM usage_start_time) AS week,
    EXTRACT(YEAR FROM usage_start_time) AS year,
    SUM(cost) AS total_cost
  FROM
    `my-project.billing_dataset.gcp_billing_export_v1_*`
  WHERE
    service.description = 'Cloud Run'
    AND usage_start_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 8 WEEK)
  GROUP BY week, year
)
SELECT
  week,
  year,
  total_cost,
  LAG(total_cost) OVER (ORDER BY year, week) AS prev_week_cost,
  (total_cost - LAG(total_cost) OVER (ORDER BY year, week)) / LAG(total_cost) OVER (ORDER BY year, week) * 100 AS percent_change
FROM weekly_cost
ORDER BY year DESC, week DESC;
```

**Cloud Monitoring ダッシュボード:**
```mql
# インスタンス数とコスト相関
fetch cloud_run_revision
| metric 'run.googleapis.com/instance_count'
| filter (resource.labels.service_name == "my-app")
| align sum(1m)
| every 1m
```

### ラベルベースのコスト追跡

**サービスにラベル付与:**
```bash
gcloud run services update my-app \
  --region us-central1 \
  --update-labels=team=backend,env=production,cost-center=eng
```

**ラベル別コスト分析（BigQuery）:**
```sql
SELECT
  labels.value AS team,
  SUM(cost) AS team_cost
FROM
  `my-project.billing_dataset.gcp_billing_export_v1_*`,
  UNNEST(labels) AS labels
WHERE
  service.description = 'Cloud Run'
  AND labels.key = 'team'
GROUP BY team
ORDER BY team_cost DESC;
```

## コスト判断テーブル（ワークロード別推奨設定）

### 低コスト優先

| ワークロード | CPU | メモリ | concurrency | max-instances | 月額コスト目安 |
|------------|-----|--------|-------------|--------------|-------------|
| 軽量API | 0.5 vCPU | 256Mi | 100 | 50 | $10-30 |
| 静的サイト | 0.5 vCPU | 128Mi | 100 | 20 | $5-15 |
| Webhook受信 | 0.5 vCPU | 256Mi | 80 | 30 | $8-20 |

### バランス型

| ワークロード | CPU | メモリ | concurrency | max-instances | 月額コスト目安 |
|------------|-----|--------|-------------|--------------|-------------|
| Web API | 1 vCPU | 512Mi | 80 | 60 | $50-100 |
| データ変換 | 1 vCPU | 1024Mi | 40 | 40 | $80-150 |
| 認証サービス | 1 vCPU | 512Mi | 60 | 50 | $60-120 |

### パフォーマンス優先

| ワークロード | CPU | メモリ | concurrency | max-instances | 月額コスト目安 |
|------------|-----|--------|-------------|--------------|-------------|
| 画像処理 | 2 vCPU | 2048Mi | 20 | 50 | $200-400 |
| 機械学習推論 | 2 vCPU | 4096Mi | 10 | 30 | $300-600 |
| リアルタイム分析 | 2 vCPU | 2048Mi | 30 | 60 | $250-500 |

## コスト最適化チェックリスト

### 設定最適化

- [ ] CPU throttling 有効（request-based モード）
- [ ] concurrency を最大限に設定（負荷テスト済み）
- [ ] 不要な min-instances 設定を削除
- [ ] max-instances で上限を設定
- [ ] リソース割り当てを使用率に合わせて調整

### アプリケーション最適化

- [ ] リクエスト処理時間を最小化（200ms目標）
- [ ] 不要な依存関係を削除
- [ ] コンテナイメージを軽量化（マルチステージビルド）
- [ ] データベースクエリを最適化
- [ ] キャッシング戦略を実装

### ネットワーク最適化

- [ ] CDN でネットワーク Egress を削減
- [ ] レスポンスデータを圧縮（gzip）
- [ ] 不要なログ出力を削減
- [ ] Cloud Storage からの直接配信を検討

### 監視・管理

- [ ] 予算アラート設定
- [ ] 週次コストレビュー
- [ ] ラベルベースのコスト追跡
- [ ] BigQuery でコスト分析クエリ実行
- [ ] パフォーマンスとコストのトレードオフを定期評価

## 実践例: コスト削減シナリオ

### Before: 高コスト設定

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --cpu 2 \
  --memory 2048Mi \
  --concurrency 40 \
  --max-instances 100 \
  --no-cpu-throttling \
  --allow-unauthenticated
```

**問題点:**
- CPU 2 vCPU は過剰
- Always-on CPU でアイドル時も課金
- concurrency 40 は低い（インスタンス数増加）

**推定月額: $500-800**

### After: 最適化設定

```bash
gcloud run deploy my-app \
  --image gcr.io/my-project/my-app:latest \
  --platform managed \
  --region us-central1 \
  --cpu 1 \
  --memory 1024Mi \
  --concurrency 80 \
  --max-instances 60 \
  --cpu-throttling \
  --allow-unauthenticated
```

**改善点:**
- CPU を 1 vCPU に削減（パフォーマンステスト済み）
- Request-based CPU でアイドル時のコスト削減
- concurrency を 80 に増加（インスタンス数削減）

**推定月額: $150-250**

**コスト削減: 50-70%**

## Google Cloud Pricing Calculator 活用

**手順:**
1. [Pricing Calculator](https://cloud.google.com/products/calculator) にアクセス
2. Cloud Run を選択
3. パラメータ入力:
   - リクエスト数/月
   - 平均処理時間
   - CPU・メモリ割り当て
   - ネットワーク Egress
4. コスト見積もりを比較

**シナリオ比較例:**
- **現状**: 1 vCPU, 512Mi, concurrency 60
- **最適化**: 1 vCPU, 512Mi, concurrency 100
- **結果**: 月額$100 → $70（30%削減）

## トラブルシューティング: コスト増加

### 原因と対策

| 原因 | 対策 |
|------|------|
| リクエスト数増加 | 予想通りの成長か確認、必要なら上限設定 |
| 処理時間の長期化 | プロファイリングでボトルネック特定、コード最適化 |
| concurrency 設定不足 | 負荷テスト後に concurrency 増加 |
| ネットワーク Egress 増加 | CDN統合、レスポンス圧縮、データサイズ削減 |
| 不要なインスタンス起動 | max-instances 削減、CPU throttling 確認 |

### コスト分析クエリ

```sql
-- 日次コストトレンド
SELECT
  DATE(usage_start_time) AS day,
  SUM(cost) AS daily_cost,
  SUM(usage.amount) AS usage_amount,
  sku.description AS resource
FROM
  `my-project.billing_dataset.gcp_billing_export_v1_*`
WHERE
  service.description = 'Cloud Run'
GROUP BY day, resource
ORDER BY day DESC, daily_cost DESC;
```

## まとめ: コスト最適化の原則

1. **Right-sizing**: 実際の使用率に合わせたリソース割り当て
2. **Maximize concurrency**: インスタンス数を最小化
3. **Request-based CPU**: アイドル時の課金を回避
4. **Monitor continuously**: 週次コストレビューと予算アラート
5. **Optimize application**: コードレベルでの効率化
6. **Leverage free tier**: 開発環境を無料枠内に収める

**目標: パフォーマンスを維持しながら40-60%のコスト削減**
