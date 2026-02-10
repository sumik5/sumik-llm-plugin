# レイヤー別監視戦略

このドキュメントでは、6つのレイヤーに分けた監視戦略と、監視アセスメント実施ガイドを提供します。

---

## 1. ビジネス監視

### ビジネスKPI（Key Performance Indicator）

ビジネスKPIは、ビジネスの健全性を測る指標です。技術指標（CPU使用率、レスポンスタイム等）だけでなく、ビジネスKPIを監視することで、技術的な問題がビジネスに与える影響を理解できます。

**主なビジネスKPI:**

| KPI | 説明 | 業種 |
|-----|------|------|
| **Monthly Recurring Revenue (MRR)** | 月次経常収益 | SaaS、サブスクリプション |
| **Revenue per Customer** | 顧客あたり収益 | SaaS、EC |
| **Number of Paying Customers** | 有料顧客数 | SaaS、サブスクリプション |
| **Net Promoter Score (NPS)** | 顧客推奨度。「この製品を友人に勧めますか？」を1-10で評価 | 全業種 |
| **Conversion Rate** | コンバージョン率。訪問者のうち購入/登録に至った割合 | EC、SaaS |
| **Churn Rate** | 解約率 | SaaS、サブスクリプション |

### 技術指標との紐付け

**KPIが下がったら技術指標を見る:**

1. **KPIの異常を検知** — 例: コンバージョン率が通常5%から2%に低下
2. **技術指標を確認** — 同時刻のレスポンスタイム、エラー率、サーバ負荷を確認
3. **根本原因を特定** — 技術的な問題（遅いページ読み込み、エラー増加等）がビジネスに影響していることを証明
4. **優先順位を決定** — ビジネスインパクトが大きい問題から修正

**事例:**

| 企業 | KPI | 技術指標 | インサイト |
|------|-----|---------|-----------|
| **Yelp** | ユーザーエンゲージメント | ページ読み込み時間 | ページが遅いとユーザーの検索回数が減る |
| **Reddit** | ページビュー | サーバレスポンスタイム | レスポンスタイムが100ms増えるごとにページビューが1%減少 |

### KPIの見つけ方

**マネジメントへの質問テンプレート:**

1. 「今月のビジネス目標は何ですか？」
2. 「どの指標が最も重要ですか？」
3. 「その指標はどこで確認できますか？」（ダッシュボード、レポート等）
4. 「その指標を技術チームが追跡できますか？」

**注意点:**
- KPIは経営層が定義するもの。技術チームが勝手に決めない
- KPIは少数に絞る（3-5個程度）
- KPIは測定可能で、具体的な数値目標がある

### メトリクスがない場合の対処法

**カスタムメトリクスを計測:**

アプリケーションにビジネスメトリクスがない場合、StatsD等のライブラリを使用してカスタムメトリクスを送信します。

**例: Python + StatsD**
```python
import statsd

c = statsd.StatsClient('localhost', 8125)

def process_purchase(user_id, amount):
    # ビジネスロジック
    save_to_database(user_id, amount)

    # カスタムメトリクス送信
    c.incr('purchases.count')  # 購入数をカウント
    c.gauge('purchases.amount', amount)  # 購入金額をゲージとして記録
```

**例: Node.js + StatsD**
```javascript
const StatsD = require('node-statsd');
const client = new StatsD();

function processPurchase(userId, amount) {
    // ビジネスロジック
    saveToDatabase(userId, amount);

    // カスタムメトリクス送信
    client.increment('purchases.count');  // 購入数をカウント
    client.gauge('purchases.amount', amount);  // 購入金額をゲージとして記録
}
```

---

## 2. フロントエンド監視

### 遅いアプリケーションのコスト

**ビジネスインパクト:**
- Amazonの調査: ページ読み込みが100ms遅くなると売上が1%減少
- Googleの調査: 検索結果表示が400ms遅くなるとトラフィックが0.6%減少
- ユーザーはページ読み込みに3秒以上かかると離脱する傾向

### フロントエンド監視の2つのアプローチ

| アプローチ | 説明 | メリット | デメリット |
|-----------|------|---------|-----------|
| **Real User Monitoring (RUM)** | 実際のユーザーのブラウザからパフォーマンスデータを収集 | 実ユーザーの体験を正確に測定、地域別/デバイス別の分析が可能 | プライバシー懸念、サンプリングが必要（全ユーザーのデータは送信しない） |
| **Synthetic Monitoring** | ボットを使って定期的にサイトにアクセスし、パフォーマンスを測定 | 24時間監視可能、トラフィックが少ない時間帯も監視、リグレッション検知 | 実ユーザーの体験とは異なる可能性 |

**推奨: 両方を併用**
- RUMで実ユーザーの体験を測定
- Synthetic Monitoringで継続的なパフォーマンス監視とアラート

### DOM（Document Object Model）とパフォーマンスメトリクス

**Navigation Timing API:**

ブラウザが提供する標準APIで、ページ読み込みの各フェーズの時間を取得できます。

```javascript
// Navigation Timing API の取得
const perfData = window.performance.timing;

// 主要メトリクスの計算
const metrics = {
    // DNS解決時間
    dnsTime: perfData.domainLookupEnd - perfData.domainLookupStart,

    // TCP接続時間
    tcpTime: perfData.connectEnd - perfData.connectStart,

    // Time to First Byte (TTFB)
    ttfb: perfData.responseStart - perfData.navigationStart,

    // DOMContentLoaded
    domContentLoaded: perfData.domContentLoadedEventEnd - perfData.navigationStart,

    // Load（全リソース読み込み完了）
    loadComplete: perfData.loadEventEnd - perfData.navigationStart
};

// メトリクスを監視サーバーに送信
sendMetrics(metrics);
```

**フロントエンドパフォーマンスメトリクス:**

| メトリクス | 説明 | 目標値 |
|-----------|------|--------|
| **Time to First Byte (TTFB)** | サーバーが最初のバイトを返すまでの時間 | < 200ms |
| **DOMContentLoaded** | HTML解析完了、DOMツリー構築完了の時間 | < 1秒 |
| **Load** | すべてのリソース（画像、CSS、JS等）読み込み完了の時間 | < 3秒 |
| **First Contentful Paint (FCP)** | 最初のコンテンツが画面に描画された時間 | < 1秒 |
| **Largest Contentful Paint (LCP)** | 最大のコンテンツが画面に描画された時間 | < 2.5秒 |
| **Cumulative Layout Shift (CLS)** | レイアウトのずれの累積（低いほど良い） | < 0.1 |

### ブラウザログ集約

**ブラウザのコンソールエラーを収集:**

```javascript
// グローバルエラーハンドラ
window.addEventListener('error', function(event) {
    const errorData = {
        message: event.message,
        source: event.filename,
        lineno: event.lineno,
        colno: event.colno,
        error: event.error ? event.error.stack : null,
        userAgent: navigator.userAgent,
        url: window.location.href
    };

    // ログ収集サーバーに送信
    sendErrorLog(errorData);
});
```

---

## 3. アプリケーション監視

### メトリクスによるアプリケーション計測

**StatsD等のライブラリを使用:**

アプリケーションコード内にカスタムメトリクスを埋め込み、ビジネスロジックやパフォーマンスを追跡します。

**例: Webアプリケーションのメトリクス**
```python
import statsd
import time

c = statsd.StatsClient('localhost', 8125)

def handle_request(request):
    start_time = time.time()

    try:
        # ビジネスロジック
        response = process_request(request)

        # 成功カウント
        c.incr('requests.success')

        return response
    except Exception as e:
        # エラーカウント
        c.incr('requests.error')
        raise
    finally:
        # レスポンスタイム記録
        elapsed = (time.time() - start_time) * 1000  # ミリ秒
        c.timing('requests.response_time', elapsed)
```

### ビルド・リリースパイプラインの監視

**CI/CDパイプラインを監視:**
- ビルド成功率
- テスト実行時間
- デプロイ頻度
- デプロイ失敗率

**メトリクス例:**
- `builds.success` — ビルド成功数
- `builds.failure` — ビルド失敗数
- `builds.duration` — ビルド時間
- `deployments.count` — デプロイ回数
- `deployments.rollback` — ロールバック回数

### healthエンドポイントパターン

**`/health` エンドポイントの実装:**

アプリケーションの健全性を確認するためのHTTPエンドポイントを提供します。

**基本的な実装例（Node.js + Express）:**
```javascript
const express = require('express');
const app = express();

app.get('/health', async (req, res) => {
    const health = {
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        checks: {}
    };

    try {
        // データベース接続チェック
        await database.ping();
        health.checks.database = { status: 'ok' };
    } catch (error) {
        health.status = 'degraded';
        health.checks.database = { status: 'error', message: error.message };
    }

    try {
        // Redis接続チェック
        await redis.ping();
        health.checks.redis = { status: 'ok' };
    } catch (error) {
        health.status = 'degraded';
        health.checks.redis = { status: 'error', message: error.message };
    }

    // ステータスコードを設定
    const statusCode = health.status === 'ok' ? 200 : 503;
    res.status(statusCode).json(health);
});
```

**応答形式例:**
```json
{
    "status": "ok",
    "timestamp": "2025-02-10T12:34:56.789Z",
    "uptime": 3600,
    "checks": {
        "database": {
            "status": "ok"
        },
        "redis": {
            "status": "ok"
        }
    }
}
```

**依存サービスチェックのベストプラクティス:**
- データベース接続のpingを実行
- 外部API（決済、認証等）の接続確認
- ディスク容量、メモリ使用率のチェック
- タイムアウトを短く設定（1-2秒）
- 503 Service Unavailableを返す場合、ロードバランサが自動的にトラフィックを別のインスタンスに振り分ける

### アプリケーションロギング

#### メトリクスにすべきか、ログにすべきか

| 用途 | メトリクス | ログ |
|------|-----------|------|
| **数値の追跡** | ✅ | ❌ |
| **トレンド分析** | ✅ | ❌ |
| **アラート** | ✅ | ❌ |
| **詳細な調査** | ❌ | ✅ |
| **スタックトレース** | ❌ | ✅ |
| **ユーザーアクション** | ❌ | ✅ |
| **コスト** | 低 | 高 |

**基本原則:**
- **メトリクス**: 数値、カウント、ゲージ（例: リクエスト数、レスポンスタイム）
- **ログ**: 詳細な文脈情報、エラーメッセージ、スタックトレース

#### 何のログを取るべきか

**取るべきログ:**
- エラー、例外（スタックトレース含む）
- ユーザーアクションの監査ログ（誰が何をしたか）
- セキュリティイベント（ログイン失敗、権限エラー等）
- 外部API呼び出しの成功/失敗

**取るべきでないログ:**
- デバッグログをプロダクションで有効にする（パフォーマンス低下、ストレージコスト増）
- PII（個人情報）、PHI（医療情報）、パスワード、APIキー
- 1秒間に1000件以上のログ（代わりにメトリクスを使用）

### サーバレス / Function-as-a-Service (FaaS) 監視の特殊性

**課題:**
- 関数は短命（数秒〜数分）のため、従来のエージェントベース監視が使えない
- コールドスタート時間がパフォーマンスに影響
- ログが分散している

**対策:**
- **クラウドプロバイダーの監視サービスを使用** — AWS CloudWatch, Azure Monitor, Google Cloud Logging
- **X-Rayやトレーシングを有効化** — 分散トレーシングで関数呼び出しを追跡
- **構造化ログを必ず使用** — JSON形式でログを出力し、ログ集約サービスに送信
- **コールドスタート時間を監視** — 関数の初期化時間を最小化

### マイクロサービスアーキテクチャの監視

**課題:**
- サービス間の依存関係が複雑
- リクエストが複数のサービスを横断する
- どのサービスが遅延の原因か特定が困難

**分散トレーシング（Distributed Tracing）:**

各リクエストに一意のTrace IDを付与し、すべてのサービスでそのTrace IDを伝播させます。

**OpenTelemetry実装例（Node.js）:**
```javascript
const { trace } = require('@opentelemetry/api');

async function handleRequest(req, res) {
    const tracer = trace.getTracer('my-service');
    const span = tracer.startSpan('handleRequest');

    try {
        // ビジネスロジック
        const result = await processRequest(req);
        span.setStatus({ code: SpanStatusCode.OK });
        res.json(result);
    } catch (error) {
        span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
        span.recordException(error);
        res.status(500).json({ error: error.message });
    } finally {
        span.end();
    }
}
```

**サービスメッシュ（Istio, Linkerd）:**
- サービス間通信を自動的に監視
- トレーシング、メトリクス、ログを統一的に収集
- サービスディスカバリ、負荷分散、リトライを自動化

**詳細は implementing-opentelemetry スキルを参照してください。**

---

## 4. サーバ監視

### OSの標準的なメトリクス

| メトリクス | 説明 | 正常範囲 | 注意点 |
|-----------|------|---------|--------|
| **CPU使用率** | CPUの使用率（0-100%） | < 80% | 短期的なスパイクは正常。継続的に高い場合は調査 |
| **メモリ使用率** | 物理メモリの使用率 | < 85% | Linuxはキャッシュに空きメモリを使うため、90%以上でも正常な場合がある |
| **ネットワークトラフィック** | 受信/送信バイト数 | — | 帯域幅に対する使用率を監視。突然の増加はDDoS攻撃の可能性 |
| **ディスク使用率** | ディスクの使用率（0-100%） | < 80% | 90%を超えるとパフォーマンス低下。95%でアラート |
| **ディスクI/O** | 読み書き操作数、待ち時間 | — | I/O待ちが多いとアプリケーションが遅くなる |
| **ロードアベレージ** | 実行待ちプロセス数の平均（1分、5分、15分） | < CPUコア数 | CPUコア数の2倍を超えると過負荷 |

**注意: OSメトリクスだけでアラートを出さない**
- CPU使用率が高くても、アプリケーションが正常に動作していれば問題ない
- OSメトリクスは「参考情報」として使用し、アプリケーションレベルのメトリクス（レスポンスタイム、エラー率）でアラートを出す

### SSL証明書監視

**有効期限の監視:**
- 証明書の有効期限を毎日チェック
- 30日前、7日前にアラート
- Let's Encryptの自動更新が失敗した場合の検知

**証明書チェックスクリプト例（Bash）:**
```bash
#!/bin/bash
DOMAIN="example.com"
EXPIRY_DATE=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
CURRENT_EPOCH=$(date +%s)
DAYS_LEFT=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))

if [ $DAYS_LEFT -lt 30 ]; then
    echo "WARNING: SSL certificate for $DOMAIN expires in $DAYS_LEFT days"
fi
```

### Webサーバ（NGINX / Apache）

**監視すべきメトリクス:**
- リクエスト数（requests per second）
- レスポンスタイム（平均、95パーセンタイル）
- HTTPステータスコード別のカウント（2xx, 3xx, 4xx, 5xx）
- アクティブ接続数
- 待機中のリクエスト数

**NGINX status モジュール:**
```nginx
server {
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
```

### データベースサーバ

**監視すべきメトリクス:**

| メトリクス | 説明 | 目標値 |
|-----------|------|--------|
| **接続数** | アクティブな接続数 | 最大接続数の70%以下 |
| **クエリ実行時間** | スロークエリの検出 | 95パーセンタイル < 100ms |
| **レプリケーション遅延** | プライマリとレプリカの差 | < 5秒 |
| **ロック待ち** | ロック待ちのクエリ数 | 0に近い |
| **キャッシュヒット率** | クエリキャッシュ/バッファプールのヒット率 | > 95% |

### ロードバランサ（HAProxy / NGINX）

**監視すべきメトリクス:**
- バックエンドサーバの健全性（up/down）
- 各バックエンドへの接続数
- リクエスト分散の均等性
- 5xx エラー率

### メッセージキュー（RabbitMQ / Kafka）

**監視すべきメトリクス:**
- キュー長（未処理メッセージ数）
- メッセージ生産速度（messages/sec）
- メッセージ消費速度（messages/sec）
- 消費速度 < 生産速度の場合、キューが溜まる

### キャッシュ（Redis / Memcached）

**監視すべきメトリクス:**
- ヒット率（cache hit ratio）— 目標: > 95%
- エビクション率（eviction rate）— メモリ不足でキーが削除される頻度
- 接続数
- メモリ使用率

### DNS

**監視すべき項目:**
- DNSクエリ応答時間
- NXDOMAIN（存在しないドメイン）の割合
- ゾーン転送の成功/失敗

### NTP（Network Time Protocol）

**時刻同期の監視:**
- サーバの時刻とNTPサーバの時刻のずれ
- 1秒以上のずれはログに記録（分散システムで問題の原因になる）

### スケジュールジョブの監視

**cron / ジョブスケジューラの監視:**
- ジョブの実行成功/失敗
- ジョブの実行時間（長時間実行はアラート）
- ジョブの実行頻度（スキップされていないか）

**Dead Man's Switch パターン:**
- ジョブが定期的に「生存確認」を送信
- 確認が来なければアラート

---

## 5. ネットワーク監視

### SNMPの仕組み

**SNMP（Simple Network Management Protocol）:**
- ネットワーク機器（ルーター、スイッチ等）の標準管理プロトコル
- MIB（Management Information Base）というデータベースから情報を取得

**2つのモード:**

| モード | 説明 | 用途 |
|-------|------|------|
| **Polling（プル型）** | 監視サーバーが定期的にSNMP GETリクエストを送信 | 定期的なメトリクス収集 |
| **Trap（プッシュ型）** | ネットワーク機器がイベント発生時にSNMP Trapを送信 | 障害検知、アラート |

**セキュリティ:**
- SNMPv1/v2cはコミュニティ文字列（パスワード）を平文で送信するため非推奨
- SNMPv3は暗号化をサポート。本番環境ではSNMPv3を使用

### インタフェースメトリクス

**監視すべきメトリクス:**
- 受信/送信バイト数（Bytes In/Out）
- 受信/送信パケット数（Packets In/Out）
- エラーパケット数（Errors In/Out）
- 破棄パケット数（Discards In/Out）
- インタフェースのステータス（up/down）

### 構成管理

**ネットワーク機器の構成変更を追跡:**
- 設定ファイルのバックアップと差分監視
- 不正な設定変更の検知
- 構成変更の監査ログ

### フロー監視

**NetFlow / sFlow:**
- ネットワークトラフィックのフローデータを収集
- どのホストがどのホストと通信しているかを可視化
- 帯域幅を最も使用しているアプリケーション/ユーザーを特定

### キャパシティプランニング

#### 逆算する

**ボトルネック基準で計算:**
1. 現在の帯域幅使用率を測定（例: 1Gbps回線の平均60%使用 = 600Mbps）
2. 成長率を計算（例: 月10%増加）
3. 100%に達する時期を逆算（例: 4ヶ月後）
4. 余裕を持って増強計画を立てる（例: 3ヶ月後に10Gbpsに増強）

#### 予測する

**統計的予測:**
- 過去のトレンドから将来の使用率を予測
- 線形回帰、移動平均等の手法を使用
- 季節性（年末商戦、イベント時期）を考慮

---

## 6. セキュリティ監視

### 監視とコンプライアンス

**外部規制への対応:**
- **GDPR** — EU一般データ保護規則。個人データの処理記録が必要
- **HIPAA** — 米国医療保険の相互運用性と説明責任に関する法律。医療情報のアクセスログが必要
- **SOC 2** — サービス組織の内部統制に関する監査基準。セキュリティ監視の証跡が必要
- **PCI DSS** — クレジットカード情報を扱う場合の基準。アクセスログ、監査ログが必要

**コンプライアンス要件を満たす監視:**
- すべてのアクセスを記録（誰が、いつ、何にアクセスしたか）
- ログの改ざん防止（書き込み専用ストレージ、デジタル署名）
- 長期保存（7年以上）

### auditd（Linux監査デーモン）

**auditdとは:**
- Linuxカーネルレベルの監査システム
- ユーザーのコマンド実行、ファイルアクセス、システムコールを記録

**auditdのセットアップ例:**
```bash
# auditdをインストール
sudo apt-get install auditd

# 監査ルールを設定（/etc/audit/rules.d/audit.rules）
# 特定のファイルへのアクセスを監査
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes

# ユーザーのsudoコマンドを監査
-a always,exit -F arch=b64 -S execve -F euid=0 -k sudo_commands

# 監査ルールを再読み込み
sudo augenrules --load
```

**auditdとリモートログ:**
- auditdのログは `/var/log/audit/audit.log` に保存
- リモートログサーバーに転送して一元管理
- rsyslog, syslog-ng等で転送可能

### ホスト型侵入検知システム（HIDS）

**HIDS（Host-based Intrusion Detection System）:**
- サーバ上で動作し、ファイルの改ざん、不正なプロセスを検知
- 代表的なツール: OSSEC, Wazuh

**監視内容:**
- ファイル整合性監視（File Integrity Monitoring: FIM）
- ルートキット検出
- ログ分析（認証失敗の検出等）

### rkhunter（Rootkit Hunter）

**rkhunterとは:**
- ルートキット、バックドア、既知の悪意あるファイルを検出
- 定期的にスキャンを実行

**使用例:**
```bash
# rkhunterをインストール
sudo apt-get install rkhunter

# スキャン実行
sudo rkhunter --check

# 毎日自動スキャン（cron）
echo "0 3 * * * /usr/bin/rkhunter --check --skip-keypress" | sudo crontab -
```

### ネットワーク侵入検知システム（NIDS）

**NIDS（Network-based Intrusion Detection System）:**
- ネットワークトラフィックを監視し、不正なパケットを検知
- 代表的なツール: Snort, Suricata

**監視内容:**
- ポートスキャン検知
- SQLインジェクション、XSS攻撃の検知
- C&C（Command and Control）サーバーへの通信検知

**Suricataの設置例:**
```bash
# Suricataをインストール
sudo apt-get install suricata

# ルールセットをダウンロード
sudo suricata-update

# 起動
sudo systemctl start suricata

# ログは /var/log/suricata/eve.json に出力（JSON形式）
```

---

## 7. 監視アセスメント実施ガイド

現在の監視システムを評価し、改善点を特定するためのチェックリストです。

### ビジネスKPIの評価項目

- [ ] ビジネスKPIが定義されているか？
- [ ] ビジネスKPIがダッシュボードで可視化されているか？
- [ ] ビジネスKPIと技術指標が紐付けられているか？
- [ ] ビジネスKPIが異常な値になった場合、技術チームに通知されるか？

### フロントエンド監視の評価項目

- [ ] Real User Monitoring (RUM) が導入されているか？
- [ ] Synthetic Monitoring が導入されているか？
- [ ] ページ読み込み時間（TTFB, DOMContentLoaded, Load）を測定しているか？
- [ ] フロントエンドエラー（JavaScriptエラー）を収集しているか？
- [ ] パフォーマンスが悪化した場合、アラートが出るか？

### アプリケーション・サーバ監視の評価項目

- [ ] アプリケーションのカスタムメトリクスを計測しているか？
- [ ] `/health` エンドポイントが実装されているか？
- [ ] アプリケーションログが構造化されているか（JSON形式）？
- [ ] ログが一元管理されているか（Elasticsearch, Splunk等）？
- [ ] データベースのスロークエリを監視しているか？
- [ ] キャッシュのヒット率を監視しているか？
- [ ] メッセージキューの長さを監視しているか？

### セキュリティ監視の評価項目

- [ ] auditdまたは同等の監査システムが導入されているか？
- [ ] HIDS（ホスト型侵入検知）が導入されているか？
- [ ] NIDS（ネットワーク型侵入検知）が導入されているか？
- [ ] セキュリティログが長期保存されているか（7年以上）？
- [ ] コンプライアンス要件（GDPR, HIPAA, SOC 2等）を満たしているか？

### アラートの評価項目

- [ ] アラートがメールではなく専用ツール（PagerDuty等）で送信されているか？
- [ ] すべてのアラートに手順書（Runbook）が添付されているか？
- [ ] 動的閾値（moving average, confidence band）を使用しているか？
- [ ] 過去1ヶ月で誤報は何件あったか？（目標: 0件）
- [ ] アラートを定期的にチューニング・削除しているか？
- [ ] メンテナンス期間中はアラートを停止しているか？

### 総合評価

**スコアリング:**
- すべての項目にチェックが入る: **優秀**
- 80%以上にチェックが入る: **良好**
- 50-80%: **改善が必要**
- 50%未満: **早急な改善が必要**

**改善の優先順位:**
1. ユーザー視点での監視（フロントエンド、`/health`エンドポイント）
2. ビジネスKPIの可視化
3. アラートの改善（誤報削減、手順書添付）
4. セキュリティ監視（コンプライアンス要件）
5. アプリケーション監視の強化

---

## 参考情報

- **OPERATIONS.md** — アラート設計、オンコール運用、インシデント管理の詳細
- **implementing-opentelemetry** — 分散トレーシングの実装方法
- **securing-code** — セキュリティ監視と連携するアプリケーションセキュリティ
