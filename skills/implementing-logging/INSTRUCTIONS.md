# Implementing Logging

ログは「いつ・どこで・誰が・何を・なぜ・どのように」という5W1Hで設計する。実装・収集・分析・セキュリティ・ビジネス活用のすべてを網羅したガイド。

## ログ設計原則

### 5W1H 設計チェックリスト

```
When  （いつ）   : タイムスタンプ（ISO 8601 / Unix時間）
Where （どこで）  : サーバーID・サービス名・コンポーネント名
Who   （誰が）   : ユーザーID・セッションID・IPアドレス
What  （何を）   : 操作内容・リソース名・変更前後の値
Why   （なぜ）   : エラーコード・原因区分
How   （どのように）: 処理結果・レスポンスコード・実行時間
```

### ログに記録してはいけない情報（必須遵守）

```
❌ パスワード・秘密鍵・APIキー
❌ クレジットカード番号（PCI DSS）
❌ 氏名・住所・電話番号（個人情報保護法・GDPR）
❌ マイナンバー・パスポート番号
❌ 医療情報（医療情報ガイドライン）
```

マスキング例（Python）:
```python
import re

def mask_sensitive(message: str) -> str:
    # クレジットカード番号をマスク
    message = re.sub(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',
                     '****-****-****-****', message)
    # メールアドレスをマスク
    message = re.sub(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
                     '***@***.***', message)
    return message
```

## ログレベル設計

### syslog 標準レベル（重要度順）

| レベル | 数値 | 使用場面 |
|--------|------|----------|
| emerg  | 0    | システム全体が使用不能（OS クラッシュ等） |
| alert  | 1    | 即座に手動対応が必要 |
| crit   | 2    | ハードウェア障害など深刻な障害 |
| err    | 3    | エラー（処理続行は可能） |
| warning| 4    | 警告（注意が必要だが処理は継続） |
| notice | 5    | 正常だが特記すべきイベント |
| info   | 6    | 一般的な情報 |
| debug  | 7    | デバッグ用詳細情報（本番では無効化） |

### アプリケーションでの使い分け

```python
import logging

logger = logging.getLogger(__name__)

# 本番: WARNING以上のみ出力
# 開発: DEBUG以上を出力
logging.basicConfig(level=logging.WARNING)

logger.debug("DB クエリ実行: %s", query)          # 開発専用
logger.info("ユーザーログイン: user_id=%s", uid)  # 通常操作
logger.warning("API レート制限まで残り %d回", n)  # 閾値接近
logger.error("DB 接続失敗: %s", str(e))           # 回復可能なエラー
logger.critical("外部決済サービス応答なし")        # 業務停止級
```

## 構造化ログ実装

### JSON 形式（推奨）

```python
import json
import logging
from datetime import datetime, timezone

class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "service": "payment-api",
            "message": record.getMessage(),
            "logger": record.name,
        }
        # 追加フィールド（コンテキスト情報）
        if hasattr(record, "user_id"):
            log_entry["user_id"] = record.user_id
        if hasattr(record, "request_id"):
            log_entry["request_id"] = record.request_id
        return json.dumps(log_entry, ensure_ascii=False)
```

出力例:
```json
{
  "timestamp": "2025-07-10T09:00:00+00:00",
  "level": "ERROR",
  "service": "payment-api",
  "message": "決済処理失敗: タイムアウト",
  "user_id": "u123",
  "request_id": "req-abc-456"
}
```

### ログ粒度の判断基準

```
粗すぎる: エラーが発生した
適切:     PaymentService.process(): user_id=u123 amount=1000 error=timeout after 30s
細かすぎる: ループ内の各イテレーション全記録（パフォーマンス劣化）
```

相関分析には粒度が重要。複数サービスのログを時系列で照合する際、情報が粗すぎると因果関係を特定できない。

## ログ種別と用途

| ログ種別 | 主な用途 | 保存場所の例 |
|----------|---------|------------|
| システムログ | OS・デーモンの稼働状況 | /var/log/syslog, /var/log/messages |
| アプリケーションログ | ビジネスロジックの追跡 | /var/log/app/*.log |
| アクセスログ | リクエスト・レスポンス記録 | /var/log/nginx/access.log |
| エラーログ | 例外・障害の記録 | /var/log/nginx/error.log |
| DBログ | クエリ・トランザクション | /var/log/mysql/error.log |
| セキュリティログ | 認証・認可・監査 | /var/log/auth.log |
| クラッシュログ | 異常終了の詳細 | /var/log/crash/ |

## ログ収集アーキテクチャ

### 小規模: rsyslog / journald

```bash
# rsyslog: アプリログをリモートに転送
# /etc/rsyslog.d/50-app.conf
if $programname == 'myapp' then {
    action(type="omfwd" target="log-server.internal" port="514" protocol="tcp")
}
```

```bash
# journald: systemdサービスのログ確認
journalctl -u myapp.service -f --since "1 hour ago"
journalctl -p err -n 100  # エラーレベル以上の直近100件
```

### 中・大規模: Fluentd パイプライン

```
アプリケーション → Fluentd（収集・変換）→ Elasticsearch（蓄積）
                                         → S3（バックアップ）
```

```xml
# /etc/fluent/fluentd.conf
<source>
  @type tail
  path /var/log/app/*.log
  pos_file /var/log/td-agent/app.log.pos
  tag app.log
  <parse>
    @type json
  </parse>
</source>

<filter app.**>
  @type record_transformer
  <record>
    hostname "#{Socket.gethostname}"
  </record>
</filter>

<match app.**>
  @type elasticsearch
  host elasticsearch.internal
  port 9200
  index_name app-logs
</match>
```

詳細: [COLLECTION.md](references/COLLECTION.md)

## ログ分析・検索

### grep による即時調査

```bash
# エラーログのみ抽出（大文字小文字区別なし）
grep -i "error\|exception\|fatal" /var/log/app/app.log

# 特定時刻範囲のログ
grep "2025-07-10 09:[0-5]" /var/log/app/app.log

# 前後5行のコンテキストを表示
grep -B 5 -A 5 "PaymentFailed" /var/log/app/app.log

# 件数集計
grep "ERROR" /var/log/app/app.log | wc -l
```

### ELK Stack クエリ（Kibana）

```
# Kibana KQL: エラーが多いエンドポイントを特定
level: "ERROR" AND service: "payment-api"

# Elasticsearch Aggregation: 時間帯別エラー数
GET app-logs/_search
{
  "aggs": {
    "errors_per_hour": {
      "date_histogram": {
        "field": "@timestamp",
        "calendar_interval": "1h"
      },
      "aggs": {
        "error_count": { "filter": { "term": { "level": "ERROR" } } }
      }
    }
  }
}
```

### 可視化手法

| グラフ種別 | 用途 |
|-----------|------|
| 折れ線グラフ | 時系列のトレンド・ピーク・異常値の把握 |
| 棒グラフ | ログ種別ごとの件数分布 |
| ヒートマップ | 日時×サーバー等の複合的な異常把握 |
| 円グラフ | エラーコード別の割合 |

詳細: [ANALYSIS.md](references/ANALYSIS.md)

## 異常検知

### 閾値ベース（ルールベース）

```python
# 5分間で10回以上のログイン失敗を検知
from collections import defaultdict
from datetime import datetime, timedelta

class BruteForceDetector:
    def __init__(self, threshold: int = 10, window_minutes: int = 5):
        self.threshold = threshold
        self.window = timedelta(minutes=window_minutes)
        self.failures: dict[str, list[datetime]] = defaultdict(list)

    def record_failure(self, user_id: str, timestamp: datetime) -> bool:
        """True: 閾値超過でアラート"""
        failures = self.failures[user_id]
        cutoff = timestamp - self.window
        # ウィンドウ外の古いエントリを削除
        self.failures[user_id] = [t for t in failures if t > cutoff]
        self.failures[user_id].append(timestamp)
        return len(self.failures[user_id]) >= self.threshold
```

### 異常検知の真陽性・偽陽性

```
真陽性  : 異常を正しく検知 → 対応が必要
真陰性  : 正常を正しく判断 → 対応不要
偽陽性  : 正常なのに異常と判定 → 「アラート疲れ」を招く
偽陰性  : 異常なのに見逃す → セキュリティ事故につながる
```

閾値は「低すぎるとアラート疲れ」「高すぎると見逃し」のバランスで定期的に調整する。

詳細（ML手法含む）: [AI-ANALYSIS.md](references/AI-ANALYSIS.md)

## モニタリングとアラート

### アラート設計原則

```
緊急（電話・警告音）: サービス完全停止、セキュリティ侵害
中度（チャット通知）: 応答時間 > 3秒、エラー率 > 5%
低度（メール）      : ストレージ残量 < 20%、証明書期限 30日前
```

### Prometheus + Grafana 連携

```yaml
# prometheus.yml のアラートルール
groups:
  - name: app_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(app_errors_total[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "エラー率が高い: {{ $value }}/秒"
```

### 連鎖障害の相関分析

複数サービスのログを時系列で照合し因果関係を推定する手法。NTP による時刻同期が前提。
```
DB 書き込み失敗 → API タイムアウト → モバイルアプリ強制終了
（時系列の前後関係から連鎖を推定、ただし相関 ≠ 因果に注意）
```

## セキュリティ・コンプライアンス

### 改ざん防止

```bash
# ハッシュ値で完全性を検証
sha256sum /var/log/app/app.log > app.log.sha256

# 後日の検証
sha256sum -c app.log.sha256
# app.log: OK  → 改ざんなし
# app.log: FAILED  → 改ざんを検知
```

### ログ保管ポリシー（主要規制）

| 規制・標準 | 保管期間 | 対象 |
|-----------|---------|------|
| PCI DSS   | 1年（直近3ヶ月はオンライン） | カード決済関連 |
| FISC      | 3〜7年 | 金融機関 |
| GDPR      | 目的達成後速やかに削除 | EU居住者の個人データ |
| 医療情報  | 最低5年 | 医療機関 |

### 3-2-1 バックアップルール

```
3 : データのコピーを3つ保持
2 : 異なる2種類のメディアに保存（HDD + テープ等）
1 : 1つはオフサイト（別拠点・クラウド）に保管
```

詳細: [SECURITY-COMPLIANCE.md](references/SECURITY-COMPLIANCE.md)

## フォレンジック対応

### インシデント発生時の手順

```
1. 証拠保全: ログファイルをコピーし元ファイルは変更しない
2. ハッシュ値計算: データの完全性を証明
3. タイムライン構築: 複数ログを時系列に並べ異常を特定
4. 根本原因分析（RCA）: なぜなぜ分析・フィッシュボーン図
5. 報告書作成: 影響範囲・原因・対策を客観的に記述
6. 再発防止策実施: 脆弱性修正・ルール見直し
```

### なぜなぜ分析のテンプレート

```
問題: Webサービスが停止した
なぜ1: APIサーバーが応答しなくなった
なぜ2: DBへの接続プールが枯渇した
なぜ3: スロークエリが大量に発生した
なぜ4: インデックスが削除されていた
なぜ5: マイグレーションスクリプトに誤りがあった
根本原因: レビューなしでマイグレーションを本番適用した
```

## ビジネス活用

### Webアクセスログの主要指標

| 指標 | 計算方法 | 活用場面 |
|------|---------|---------|
| PV（ページビュー） | リクエスト数の合計 | コンテンツ人気度 |
| UU（ユニークユーザー） | Cookie / ログイン情報で重複除外 | リーチの計測 |
| 直帰率 | 1ページのみで離脱 / 全訪問 | LP品質の評価 |
| CVR（コンバージョン率） | CV数 / 訪問者数 × 100 | 施策効果の測定 |
| 平均セッション時間 | セッション継続時間の平均 | エンゲージメント |

### パフォーマンス計測

```nginx
# Nginx のアクセスログに応答時間を追加
log_format main '$remote_addr - $remote_user [$time_local] '
                '"$request" $status $body_bytes_sent '
                '$request_time';  # 応答時間（秒）を記録

access_log /var/log/nginx/access.log main;
```

```python
# Python Flask での応答時間ログ
import time
from flask import Flask, g, request
import logging

app = Flask(__name__)

@app.before_request
def start_timer():
    g.start = time.perf_counter()

@app.after_request
def log_response_time(response):
    elapsed = time.perf_counter() - g.start
    logging.info(
        "method=%s path=%s status=%d duration=%.3fs",
        request.method, request.path, response.status_code, elapsed
    )
    return response
```

## logrotate 設定

```
# /etc/logrotate.d/myapp
/var/log/myapp/*.log {
    daily           # 毎日ローテーション
    rotate 30       # 30世代保持
    compress        # gzip 圧縮
    delaycompress   # 1世代前から圧縮（書き込み中のファイルを守る）
    missingok       # ファイルがなくてもエラーにしない
    notifempty      # 空ファイルはローテーションしない
    postrotate
        systemctl reload myapp   # アプリに新しいファイルを使わせる
    endscript
}
```

## 実装チェックリスト

### 開発時
- [ ] 5W1H を含む構造化ログ（JSON）を実装した
- [ ] 機密情報（パスワード・カード番号等）をマスクしている
- [ ] ログレベルを環境変数で切り替えられるようにした
- [ ] エラーハンドラでスタックトレースをログに出力している
- [ ] request_id / correlation_id でリクエストを追跡できる

### 運用時
- [ ] logrotate でローテーションを設定した
- [ ] ストレージ使用量の閾値アラートを設定した
- [ ] 改ざん防止のためハッシュ値を定期記録している
- [ ] 保管ポリシー（規制要件）を満たしている
- [ ] 異常検知ルールの閾値を定期的に見直している

## 関連リファレンス

| ファイル | 内容 |
|---------|------|
| [COLLECTION.md](references/COLLECTION.md) | syslog/rsyslog/Fluentd/Logstash/logrotate の詳細設定 |
| [ANALYSIS.md](references/ANALYSIS.md) | ELK Stack/Grafana/Splunk/grep の詳細と可視化手法 |
| [SECURITY-COMPLIANCE.md](references/SECURITY-COMPLIANCE.md) | 攻撃検知・Tripwire・コンプライアンス詳細 |
| [AI-ANALYSIS.md](references/AI-ANALYSIS.md) | ML異常検知（RandomForest/LSTM/BERT/Isolation Forest）|
