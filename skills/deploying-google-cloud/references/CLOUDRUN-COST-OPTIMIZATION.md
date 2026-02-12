# コスト最適化

Cloud Run の料金モデルを理解し、リソース最適化とコスト管理戦略を実装するための実践ガイド。

## 料金モデル

### CPU allocation: always-on vs request-based

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

**推奨**: 99%のケースで request-based を使用

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
- CPU時間: 180,000 vCPU-秒
- メモリ: 360,000 GiB-秒
- リクエスト: 2,000,000回
- ネットワーク Egress: 1 GB（北米内）

**活用戦略:**
- 小規模プロジェクトは完全無料で運用可能
- 開発・ステージング環境を無料枠内に収める

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

### Committed Use Discounts

長期利用でコスト削減（1年/3年契約）:
- **割引率**: 最大57%
- **対象**: 予測可能な定常トラフィック
- **設定**: Google Cloud Console の Billing セクション

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

**BigQuery でコスト分析:**
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
