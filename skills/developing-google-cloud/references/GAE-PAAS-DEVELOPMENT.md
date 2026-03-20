# GAE（App Engine）PaaS 開発ガイド

Google App Engine（GAE）は 2008 年に GCP の起源として公開された PaaS サービスで、「インフラを意識しない」アプリケーション開発環境を提供する。負荷分散・ヘルスチェック・ロギング・スケーリングを Google が完全管理し、開発者はコードのデプロイだけに集中できる。本リファレンスでは GAE の Standard/Flexible 環境比較、デプロイ・バージョン管理、セキュリティ設計、Cloud Vision API 連携を含むサーバーレスアーキテクチャを解説する。

## GAE の歴史と位置付け

### GCP コンピューティングの進化

```
2008年: Google App Engine（GAE）公開
         └── PaaS として最初のクラウドサービス
         └── コンテナをベースとした独自実行環境（現 Standard）
         └── Snapchat（1億人以上利用）を25人のエンジニアで開発・運用

2013年: Google Compute Engine（GCE）公開
         └── IaaS 追加でオンプレ移行が容易に

2015年: Google Kubernetes Engine（GKE）公開
         └── GCE（仮想マシン）と GAE（PaaS）の中間
         └── コンテナオーケストレーション

2018年: Cloud Run 公開
         └── GAE Flexible のサーバーレスコンテナ版
         └── 任意言語 + ゼロスケール
```

GAE はオンプレミスからの移行用途ではなく「新規クラウドネイティブ開発」に適した選択肢として位置付けられる。既存システムの移行なら GCE、コンテナ化ならGKEや Cloud Run が適切。

## Standard 環境 vs Flexible 環境

### 詳細比較表

| 比較軸 | Standard 環境 | Flexible 環境 |
|--------|--------------|--------------|
| **実行基盤** | Google 独自のコンテナインフラ | Compute Engine 上の Docker コンテナ |
| **対応言語** | Python 3.x / Java 11+ / Go 1.x / Node.js / PHP / Ruby（指定バージョンのみ） | 任意の言語・ランタイム |
| **カスタムライブラリ** | △（制約あり / C 拡張ライブラリ不可） | ◎（Dockerfile で任意設定） |
| **スケールアウト速度** | ◎ 秒単位（非常に高速） | △ 分単位（VM 起動が必要） |
| **ゼロスケール** | ◎ 対応（0 インスタンスまで縮小） | ✕ 最低 1 インスタンス常時稼働 |
| **ローカルファイルシステム** | /tmp のみ（メモリ上） | ◎ 永続ディスク接続可 |
| **バックグラウンド処理** | △（リクエスト終了後に強制終了） | ◎ 継続実行可能 |
| **SSH アクセス** | ✕ | ◎ インスタンスへのアクセス可 |
| **コスト** | インスタンス時間ベース（低コスト） | GCE ベース（Standard より割高） |
| **推奨用途** | トラフィック変動大・Web フロントエンド | 任意ランタイム・長時間バックグラウンド処理 |

### 選択指針

```
アプリケーションの要件は？
│
├── 対応言語（Python/Java/Go/Node.js/PHP/Ruby）に制約なし
│   └── Standard 環境を第一選択（コスト・速度で有利）
│
├── C 拡張ライブラリが必要 / 任意の Docker イメージを使いたい
│   ├── サーバーレスを維持したい → Cloud Run
│   └── App Engine での管理を統一したい → Flexible 環境
│
└── 長時間バックグラウンド処理が必要
    └── Flexible 環境 or Cloud Tasks + Cloud Run
```

## デプロイとバージョン管理

### app.yaml の構成

```yaml
# Standard 環境の app.yaml 例
runtime: python311  # ランタイムバージョン指定

# スケーリング設定
automatic_scaling:
  target_cpu_utilization: 0.65
  min_instances: 1          # コールドスタート防止
  max_instances: 100        # 最大インスタンス数
  min_pending_latency: 30ms
  max_pending_latency: automatic
  max_concurrent_requests: 10

# 環境変数
env_variables:
  ENVIRONMENT: production
  DATABASE_URL: "mysql://..."

# ハンドラー設定（静的ファイル）
handlers:
- url: /static
  static_dir: static
  secure: always
- url: /.*
  script: auto
  secure: always
```

### デプロイとバージョン管理

```bash
# デプロイ（新バージョン作成）
gcloud app deploy app.yaml --version=v2 --no-promote

# バージョン一覧確認
gcloud app versions list

# トラフィック分割（カナリアデプロイ）
gcloud app services set-traffic default \
  --splits=v1=90,v2=10 \
  --split-by=ip

# 全トラフィックを v2 に切り替え
gcloud app services set-traffic default --splits=v2=100

# 古いバージョンの停止（コスト節約）
gcloud app versions stop v1
```

**バージョン管理の利点:**
- 複数バージョンを同時稼働させてトラフィック分割（A/B テスト・カナリアデプロイ）
- ロールバックはトラフィック切り戻しで即座に完了
- ステージング環境を本番と同一のプロジェクト内で管理できる

## スケーリング設定

### 3 種類のスケーリングオプション

| スケーリング種別 | 動作 | 推奨場面 |
|--------------|------|---------|
| **自動スケーリング** | リクエスト数・CPU 使用率に応じて自動調整 | 通常の Web アプリケーション |
| **基本スケーリング** | アイドル時はインスタンスを停止、リクエスト時に起動 | バッチ的なワークロード |
| **手動スケーリング** | インスタンス数を固定 | 常時一定数が必要な場合 |

```yaml
# 手動スケーリング例（ワーカー的な用途）
manual_scaling:
  instances: 5
```

**自動スケーリングの落とし穴:**
- `min_instances: 0` だとコールドスタートが発生し、初回レスポンスが遅延する
- 本番環境で低レイテンシが要求される場合は `min_instances: 1` 以上を設定

## セキュリティ設計

### IAM によるアクセス制御

```bash
# App Engine Admin ロールの付与（デプロイ権限）
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:deployer@example.com" \
  --role="roles/appengine.deployer"

# App Engine Viewer ロール（読み取り専用）
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:reader@example.com" \
  --role="roles/appengine.appViewer"
```

### App Engine Firewall

特定 IP アドレスからのアクセスのみ許可/拒否する基本的なファイアウォール。

```bash
# 特定 IP レンジを許可（他はすべて拒否）
gcloud app firewall-rules create 100 \
  --action=allow \
  --source-range=203.0.113.0/24 \
  --description="Corporate office IP"

# デフォルトルールを deny に設定
gcloud app firewall-rules update default \
  --action=deny
```

### Cloud Armor との統合

より高度な WAF 機能が必要な場合、Cloud Armor をフロントに配置。

```
インターネット → Cloud Armor（WAF・DDoS 対策）→ Cloud Load Balancer → App Engine
```

Cloud Armor で OWASP Top 10 対策（SQLi、XSS 等）、地理ベースのアクセス制御、IP レート制限が可能。

### Web Security Scanner

```bash
# App Engine アプリの脆弱性スキャン
gcloud beta web-security-scanner scan-configs create \
  --display-name="My App Scan" \
  --starting-urls="https://PROJECT_ID.appspot.com"
```

OWASP Top 10 の自動スキャン。XSS、混合コンテンツ、Flash インジェクション等を検出。

## Cloud Vision API 連携（機械学習サービス活用）

### App Engine + Cloud Vision API のアーキテクチャ例

GAE の強みの一つは、Cloud Vision API などの GCP マネージド AI サービスとシームレスに連携できる点。画像アップロード→ Vision API での分析→結果保存という典型的なパターン。

```python
# app.yaml: Standard 環境（Python 3.11）での Cloud Vision API 連携例
import os
from google.cloud import vision
from google.cloud import storage

def analyze_image(image_uri: str) -> dict:
    """
    Cloud Storage にアップロードされた画像を Vision API で分析
    """
    client = vision.ImageAnnotatorClient()

    image = vision.Image(source=vision.ImageSource(image_uri=image_uri))

    # ラベル検出
    response = client.label_detection(image=image)
    labels = [label.description for label in response.label_annotations]

    # セーフサーチ（不適切コンテンツ検出）
    safe_response = client.safe_search_detection(image=image)
    safe = safe_response.safe_search_annotation

    return {
        "labels": labels,
        "adult_content": safe.adult.name,
        "violence": safe.violence.name
    }
```

**Workload Identity の活用:** GAE から Cloud Vision API へのアクセスには、デフォルトサービスアカウントではなく専用のサービスアカウントを作成し、最小権限で設定することを推奨。

## Cloud Tasks（非同期処理）

GAE Standard では 10 分のリクエストタイムアウト制約があるため、長時間処理は Cloud Tasks でキューに積んで非同期実行する。

```python
from google.cloud import tasks_v2
import json

def enqueue_task(payload: dict) -> str:
    """長時間処理をキューに登録"""
    client = tasks_v2.CloudTasksClient()
    project = os.environ.get("GOOGLE_CLOUD_PROJECT")
    queue_path = client.queue_path(project, "asia-northeast1", "image-processing")

    task = {
        "app_engine_http_request": {
            "http_method": tasks_v2.HttpMethod.POST,
            "relative_uri": "/tasks/process-image",
            "body": json.dumps(payload).encode(),
        }
    }

    response = client.create_task(parent=queue_path, task=task)
    return response.name
```

## エンタープライズ設計ポイント

### 非機能要件の実現方法

| 非機能要件 | GAE での実現方法 |
|-----------|---------------|
| **高可用性** | リージョン内の複数ゾーンに自動複製（ユーザー設定不要） |
| **SLA** | 99.95%（Standard / Flexible 共通） |
| **スケーラビリティ** | 自動スケーリング（最大インスタンス数で上限設定） |
| **セキュリティ** | IAM + App Engine Firewall + Cloud Armor |
| **監査ログ** | Cloud Logging で自動収集（stdout/stderr への書き込みで収集） |
| **コスト管理** | 予算アラートで閾値通知 / 不要バージョンの停止 |

### ログ収集の設計

```python
# Standard 環境: stdout に JSON 形式で書き込むと Cloud Logging に自動収集
import json
import sys

def log(severity: str, message: str, **kwargs):
    entry = {
        "severity": severity,  # DEBUG/INFO/WARNING/ERROR/CRITICAL
        "message": message,
        **kwargs
    }
    print(json.dumps(entry), file=sys.stdout)

# 使用例
log("INFO", "Request processed", user_id="user123", duration_ms=42)
log("ERROR", "Database connection failed", error="timeout")
```

**ポイント:** Flexible 環境でも同様に stdout/stderr への書き込みでログが収集される。構造化ログ（JSON 形式）にすることで Cloud Logging での検索・フィルタが容易になる。
