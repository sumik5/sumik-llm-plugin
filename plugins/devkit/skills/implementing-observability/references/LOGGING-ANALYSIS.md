# ログ検索・分析・可視化 詳細リファレンス

## grep による検索テクニック

### 基本検索

```bash
# キーワード検索
grep Error sample.log

# AND 条件（パイプで連結）
grep Error sample.log | grep Message

# NOT 条件（-v）
grep -v Error sample.log

# 大文字小文字を無視（-i）
grep -i error sample.log | grep -i message
```

### 正規表現検索（-E）

```bash
# IPv4 アドレスを含む行を抽出
grep -E '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' sample.log

# 5xx ステータスコードを含む行（単語境界で誤マッチを防ぐ）
grep -E '\b5[0-9]{2}\b' access.log

# ドメイン名での検索
grep -E 'example\.com' access.log

# 日時範囲での絞り込み（ISO8601 フォーマット）
grep '2025-07-0[1-5]' app.log
```

### フィルタリング用途での応用

```bash
# ログをフィルタして別ファイルに保存
grep "ERROR" app.log > errors.log

# 複合条件で件数を絞り込んでから確認
grep ERROR app.log | grep -v "health_check" | grep "user_id"

# 圧縮ログをそのまま検索
zcat app.log.gz | grep "ERROR"
```

---

## 高速検索のための準備

### インデックス

| 種別 | 概要 |
|------|------|
| B-tree インデックス | 構造化フィールド（日付・ログレベル・タグ等）に有効 |
| 全文検索インデックス | メッセージ文章を単語分割してインデックス化 |
| n-gram（bigram 等） | 日本語などスペース区切りでない言語に対応（2文字ずつ区切り） |
| 形態素解析 | MeCab・Janome 等で単語境界を検出してインデックス化 |

全文検索エンジンを内蔵する Elasticsearch・Splunk はログファイル全体に対して高速かつ柔軟な検索が可能。

### シャーディング

ログデータを複数のノードに分割して並列処理することで、大規模ログでも検索・集計を高速化する。データ増加時はシャードを追加してスケールアウト可能。Elasticsearch・Splunk の標準機能として実装されている。

---

## ELK Stack (Elasticsearch + Kibana)

### Elasticsearch のセットアップ（AlmaLinux 9）

```bash
# GPG キーとリポジトリを追加
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

tee /etc/yum.repos.d/elasticsearch.repo <<EOF
[elasticsearch-9.x]
name=Elasticsearch repository for 9.x packages
baseurl=https://artifacts.elastic.co/packages/9.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

# Java と Elasticsearch をインストール
dnf install -y java-21-openjdk elasticsearch

# インストール時に表示される初期パスワードをメモ
# The generated password for the elastic built-in superuser is : xxxxxxxx

# パスワードをリセットする場合
/usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
```

### Elasticsearch の設定

```yaml
# /etc/elasticsearch/elasticsearch.yml
# 検証環境では HTTPS を無効化（本番は必ず enabled: true）
xpack.security.http.ssl:
  enabled: false
```

```bash
# サービス起動・有効化
systemctl start elasticsearch
systemctl enable elasticsearch

# 外部アクセスを許可する場合（デフォルトポート: 9200）
firewall-cmd --add-port=9200/tcp --permanent
firewall-cmd --reload
```

### 動作確認・Kibana 連携用トークン取得

```bash
# Elasticsearch の起動確認（username: elastic, password: インストール時のメモ）
curl http://<server-ip>:9200 -u elastic:xxxxxxxx
# → "tagline": "You Know, for Search" が返れば OK

# Kibana 用サービスアカウントトークンを発行
curl -u elastic:xxxxxxxx -X POST \
  "http://localhost:9200/_security/service/elastic/kibana/credential/token?pretty" -k
# → token.value の値をメモ
```

### Kibana のセットアップ

```bash
# インストール（Elasticsearch のリポジトリ追加済み前提）
dnf install -y kibana
```

```yaml
# /etc/kibana/kibana.yml
server.port: 5601
server.host: "0.0.0.0"          # 全インターフェース許可
elasticsearch.hosts: ["http://localhost:9200"]
elasticsearch.serviceAccountToken: "xxxxxxxxxx"  # 上記で取得したトークン
```

```bash
systemctl start kibana
systemctl enable kibana

# 外部アクセス（デフォルトポート: 5601）
firewall-cmd --add-port=5601/tcp --permanent
firewall-cmd --reload
```

ブラウザで `http://<server-ip>:5601` にアクセスし、username: `elastic`、password: インストール時のメモで認証する。

**注意:** Kibana と Elasticsearch はバージョンを必ず合わせる。本番環境ではセキュリティ設定（TLS 暗号化・認証）が必須。

### KQL クエリ例

Kibana Discover の検索バーで使用する Kibana Query Language（KQL）:

```
# フィールドの完全一致
status: 500

# AND 条件
status: 500 AND method: POST

# フィールドに値を含む（全文検索）
message: "connection refused"

# 範囲指定
response_time > 1.0

# ワイルドカード
url: /api/*

# NOT 条件
NOT status: 200

# 複合条件
(status >= 500 AND status < 600) AND NOT url: /health
```

### Aggregation クエリ例

Elasticsearch の Aggregation API を使った集計:

```json
// ステータスコード別の件数集計（Terms Aggregation）
POST /app-logs-*/_search
{
  "size": 0,
  "aggs": {
    "status_counts": {
      "terms": {
        "field": "status",
        "size": 10
      }
    }
  }
}

// 1時間ごとのリクエスト数推移（Date Histogram Aggregation）
POST /app-logs-*/_search
{
  "size": 0,
  "aggs": {
    "requests_per_hour": {
      "date_histogram": {
        "field": "@timestamp",
        "calendar_interval": "1h"
      }
    }
  }
}

// エラーログの平均応答時間（Avg Aggregation）
POST /app-logs-*/_search
{
  "query": {
    "range": { "status": { "gte": 500 } }
  },
  "size": 0,
  "aggs": {
    "avg_response_time": {
      "avg": { "field": "request_time" }
    }
  }
}
```

---

## Grafana

### 特徴

| 特徴 | 内容 |
|------|------|
| マルチデータソース | Elasticsearch・Prometheus・MySQL・Loki 等を統合可視化 |
| ダッシュボード | ドラッグ＆ドロップで折れ線・棒・円・ヒートマップ等を配置 |
| アラート | メール・Slack 等への通知機能を内蔵 |
| プラグイン | コミュニティ製プラグインが豊富、独自開発も可能 |
| Kibana との差別化 | Elastic Stack に限らず複数データソースを横断したい場合に有利 |

### セットアップ（AlmaLinux 9）

```bash
# リポジトリを追加
tee /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=Grafana Repository
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
EOF

dnf install -y grafana

systemctl start grafana-server
systemctl enable grafana-server

# 外部アクセス（デフォルトポート: 3000）
firewall-cmd --add-port=3000/tcp --permanent
firewall-cmd --reload
```

ブラウザで `http://<server-ip>:3000` にアクセス。初回ログインは username/password ともに `admin`。ログイン後にパスワード変更が求められる。

### データソース接続

1. 左メニュー「Connections」→「Data Sources」→「Add data source」
2. 使用するデータソース（Elasticsearch・Prometheus 等）を選択
3. 接続情報（URL・認証情報）を入力
4. 「Save & Test」で接続確認

ダッシュボード作成: 左メニュー「+」→「Dashboard」→「Add new panel」でクエリと表示形式を設定。

---

## Splunk

### 特徴

| 特徴 | 内容 |
|------|------|
| GUI 操作 | 検索・集計・アラート設定を GUI で完結 |
| 全文検索 | 自動インデックス化・シャーディングを標準搭載 |
| 検索クエリ（SPL） | `search`・`stats`・`timechart` 等の専用言語 |
| アラート | 検索条件ヒット時に通知・アクション実行 |
| ライセンス | データ取り込み量に応じた課金（GB/日） |

### セットアップ（Linux）

```bash
# 公式サイトから tgz を取得後
tar -xvzf splunk-<version>-<build>-Linux-amd64.tgz -C /opt

# 外部アクセス（デフォルトポート: 8000）
firewall-cmd --add-port=8000/tcp --permanent
firewall-cmd --reload

# 初回起動（管理者 username/password を設定）
cd /opt/splunk/bin
./splunk start

# 自動起動設定
./splunk enable boot-start
```

ブラウザで `http://<server-ip>:8000` にアクセスして管理コンソールを操作する。

### 主な操作フロー

1. 「設定」→「データの追加」でログファイル・ネットワーク等のデータソースを追加
2. 「設定」→「インデックス」でインデックスを作成
3. 検索バーで SPL（Search Processing Language）を使って検索・集計

```
# SPL 例: ERROR を含むイベントを時系列で集計
index=app sourcetype=app_log "ERROR"
| timechart count by host

# 特定ユーザーの不審なアクセスを検索してアラート設定
index=access_log user=admin
| stats count by src_ip
| where count > 100
```

### オープンソース vs 商用の判断基準

| 観点 | Elastic Stack / Grafana（OSS） | Splunk（商用） |
|------|-------------------------------|----------------|
| ライセンス費用 | 無償（自己運用） | データ取り込み量課金 |
| カスタマイズ性 | 高い | 制限あり |
| 運用・保守 | 自社対応 | ベンダーサポートあり |
| 専門知識 | 要求水準が高い | 比較的低い |
| 向いているケース | 柔軟な運用・コスト抑制・独自分析ルール | 短期導入・安定運用・サポート重視 |

---

## 分析手法

### 集計

#### 集計の軸

| 軸 | 概要 |
|----|------|
| 時間軸 | 1時間・1日・1週間・曜日ごとの発生件数推移 |
| グループ | エラーコード・IP アドレス・タグ等でグループ化して件数比較 |
| 環境別 | サーバー別・アプリ別のログ発生件数比較 |

#### 基本統計量

件数合計だけでなく、平均・中央値・最大値・最小値を継続的に計測することで、異常の兆候検知・ピーク時間の把握・リソース負荷の計測が可能。

#### PowerShell での集計（Windows）

```powershell
# システムログからエラーイベント最新100件を取得
Get-EventLog -LogName System -EntryType Error -Newest 100

# 特定の EventID を抽出
Get-WinEvent -LogName Application | Where-Object { $_.Id -eq 1000 }

# CSV にエクスポート
Get-EventLog -LogName System -EntryType Error -Newest 100 |
    Export-Csv -Path C:\Logs\SystemErrors.csv -NoTypeInformation

# グルーピングと統計処理
Get-Content C:\Logs\app.log | Select-String "Error" |
    Group-Object | Measure-Object -Property Count -Sum
```

### フィルタリング

#### コマンドでのフィルタリング

```bash
# grep でフィルタリング結果をファイルに保存
grep "ERROR" app.log > errors_filtered.log

# 複数条件の組み合わせ
grep "ERROR" app.log | grep -v "healthcheck" > real_errors.log
```

```powershell
# PowerShell でフィルタリング
Get-Content C:\Logs\app.log | Select-String "Error" | Out-File filtered.log
```

専用ツール（Kibana・Splunk）では GUI でフィールド値を指定するだけでリアルタイムフィルタリングが可能。

### 可視化

| グラフ種別 | 用途 |
|-----------|------|
| 折れ線グラフ | 時系列のトレンド・ピーク・異常値の把握 |
| 棒グラフ | 分類別の件数分布の把握 |
| 円グラフ | 全体に占めるエラーコード別割合の把握 |
| ヒートマップ | 日時×サーバー等の複数要素を組み合わせた局所的な異常の把握 |

KibanaやGrafanaはドラッグ＆ドロップでこれらのグラフを配置してダッシュボードを構成できる。表計算ソフトとの違いはリアルタイム更新が可能な点。

### 複合分析（障害対応フロー）

1. **事前検知**: 折れ線グラフ + アラート閾値設定でアクセス数急増を検知
2. **フィルタリング**: エラーメッセージ・対象 IP でログを絞り込む
3. **可視化**: 時系列グラフで異常の発生タイミング・継続時間を確認
4. **原因特定**: ボトルネック（Webサーバー/アプリ/DB）を特定して対処

### 統計処理との組み合わせ

| 手法 | 用途 |
|------|------|
| 移動平均 | 短期的な変動を平滑化してトレンドを把握 |
| 外れ値検知 | 平均±N標準偏差を超えるログを異常として検出 |
| 相関分析 | アクセス数と応答時間の相関関係を把握 |
| 機械学習（異常検知） | 従来の閾値では見落とすパターンを自動検出 |

---

## アクセスログ解析指標

### Apache Combined Log 形式

```
203.0.113.1 - - [01/Jul/2025:12:34:56 +0900] "GET /test.html HTTP/1.1" 200 219 "http://example.com/" "Mozilla/5.0 ..."
```

| フィールド | 内容 |
|-----------|------|
| クライアント IP | アクセス元 IP アドレス |
| リクエスト時刻 | タイムゾーンに注意（UTC と JST の違い） |
| メソッド | GET・POST 等 |
| URL（パス） | PV 集計の基準 |
| ステータスコード | 2xx=成功、4xx=クライアントエラー、5xx=サーバーエラー |
| レスポンスサイズ | バイト数 |
| リファラー | 流入元 URL |
| ユーザーエージェント | ブラウザ・OS・デバイス識別 |

### 主要指標

| 指標 | 英略 | 定義 |
|------|------|------|
| ページビュー | PV | ページの閲覧回数（同一ユーザーの再読み込みもカウント） |
| ユニークユーザー | UU | 重複を除いた訪問者数（Cookie またはログイン情報で識別） |
| セッション | Session | 最初のアクセスから離脱までの一連の行動単位 |
| 平均セッション時間 | ASD | セッションの継続時間の平均 |
| 直帰率 | Bounce Rate | 最初のページのみ閲覧して離脱した割合 |
| 離脱率 | Exit Rate | 特定ページを最後に離脱した割合（ページ単位） |
| コンバージョン率 | CVR | 訪問者のうち目標達成に至った割合（CVR = CV数 ÷ 訪問者数 × 100） |
| ページ/セッション | Pages/Session | 1セッションあたりの平均閲覧ページ数 |

**PV と UU の使い分け:**
- PV: コンテンツ人気・広告収益の評価
- UU: リーチ範囲・新規顧客獲得の評価
- PV/UU が高い = リピーターが多い（または回遊性が高い）

---

## パフォーマンス計測

### Nginx での応答時間ログ設定

標準のアクセスログには応答時間が含まれない。`$request_time` を追加して計測する。

```nginx
# /etc/nginx/nginx.conf
http {
    log_format main '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    '$request_time';  # 秒単位（小数点以下含む）

    access_log /var/log/nginx/access.log main;
}
```

Apache では `%D`（マイクロ秒）または `%T`（秒）をログフォーマットに追加する。

リバースプロキシ・ロードバランサーのログに応答時間を含めると、ネットワーク遅延を含めたエンドツーエンドの応答時間を計測できる。

### Python Flask での応答時間計測

```python
import time
import logging

logger = logging.getLogger(__name__)

@app.before_request
def start_timer():
    from flask import g
    g.start_time = time.perf_counter()

@app.after_request
def log_response_time(response):
    from flask import g, request
    elapsed = time.perf_counter() - g.start_time
    logger.info(
        "request_completed",
        extra={
            "method": request.method,
            "path": request.path,
            "status_code": response.status_code,
            "response_time_sec": round(elapsed, 6),
        }
    )
    return response
```

### 応答時間の分析手順

1. ログから `request_time` フィールドを抽出
2. 平均・中央値・最大値・パーセンタイル（P95、P99）を算出
3. 時間帯別の応答時間変動を確認（特定時間帯の遅延を検出）
4. URL 単位で集計して遅いエンドポイントを特定
5. ボトルネック（Webサーバー/アプリ/DB）を特定して改善策を実施

### APM ツール（Prometheus + Grafana）

```bash
# Prometheus のセットアップ（デフォルトポート: 9090）
useradd --no-create-home --shell /bin/false prometheus
curl -OL https://github.com/prometheus/prometheus/releases/download/v3.4.2/prometheus-3.4.2.linux-amd64.tar.gz
tar xvf prometheus-3.4.2.linux-amd64.tar.gz
mv prometheus-3.4.2.linux-amd64 /usr/local/prometheus
mv /usr/local/prometheus/prometheus /usr/local/bin/
mv /usr/local/prometheus/promtool /usr/local/bin/

mkdir /etc/prometheus /var/lib/prometheus
mv /usr/local/prometheus/prometheus.yml /etc/prometheus/
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

systemctl start prometheus
systemctl enable prometheus

firewall-cmd --permanent --add-port=9090/tcp
firewall-cmd --reload
```

```ini
# /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/

[Install]
WantedBy=multi-user.target
```

Grafana からデータソースとして Prometheus を追加し（「Connections」→「Data Sources」→「Prometheus」）、URL に Prometheus のアドレスを入力して「Save & Test」で接続確認する。その後ダッシュボードを作成して CPU 使用率・メモリ使用量・応答時間をリアルタイム可視化する。
