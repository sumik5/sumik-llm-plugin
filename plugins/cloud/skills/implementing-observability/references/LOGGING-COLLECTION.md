# ログ収集アーキテクチャ詳細

## syslog / rsyslog / syslog-ng / journald

### syslog の基本構造

```
ファシリティ.レベル  転送先
```

**主なファシリティ（送信元の分類）:**

| ファシリティ | 対象 |
|------------|------|
| auth / authpriv | 認証・セキュリティ |
| cron | cron デーモン |
| daemon | 汎用デーモン |
| kern | カーネル |
| mail | メールサービス |
| user | ユーザープロセス |
| local0〜local7 | カスタム用途 |

**レベル:** emerg(0) > alert(1) > crit(2) > err(3) > warning(4) > notice(5) > info(6) > debug(7)

### rsyslog 設定例

```bash
# /etc/rsyslog.conf

# 認証ログを別ファイルに保存
auth,authpriv.*   /var/log/auth.log

# エラー以上をリモートに転送（TCP）
*.err             @@log-server.internal:514

# アプリの info 以上を専用ファイルに
if $programname == 'myapp' and $syslogseverity <= 6 then {
    action(type="omfile" file="/var/log/myapp/app.log")
    stop
}
```

```bash
# rsyslog 再起動
sudo systemctl restart rsyslog

# ログ確認
tail -f /var/log/syslog
```

### journald（systemd 環境）

```bash
# サービスのログをリアルタイム追跡
journalctl -u nginx.service -f

# 過去1時間のエラー
journalctl -p err --since "1 hour ago"

# JSON 形式で出力（他ツールとの連携用）
journalctl -u myapp.service -o json --no-pager

# journald → rsyslog への転送設定
# /etc/systemd/journald.conf
[Journal]
ForwardToSyslog=yes
```

## Fluentd 詳細設定

### アーキテクチャ

```
アプリ → [in_tail] → [filter] → [out_elasticsearch / out_s3]
            ↓
        pos_file で再起動後もポジションを保持
```

### 基本設定（/etc/fluent/fluentd.conf）

```xml
# ===== ソース: ログファイルのテール =====
<source>
  @type tail
  path /var/log/app/*.log
  pos_file /var/log/td-agent/app.log.pos
  tag app.log
  read_from_head true
  <parse>
    @type json
  </parse>
</source>

# syslog ソース（UDP）
<source>
  @type syslog
  port 5140
  bind 0.0.0.0
  tag system
</source>

# ===== フィルター: フィールド追加 =====
<filter app.**>
  @type record_transformer
  <record>
    hostname "#{Socket.gethostname}"
    env "production"
  </record>
</filter>

# フィルター: 機密情報のマスク
<filter app.**>
  @type grep
  <exclude>
    key message
    pattern /password|secret|token/i
  </exclude>
</filter>

# ===== 出力: Elasticsearch =====
<match app.**>
  @type elasticsearch
  host elasticsearch.internal
  port 9200
  index_name app-logs-%Y.%m.%d
  flush_interval 5s
  <buffer>
    flush_mode interval
    flush_interval 5s
    retry_max_times 5
  </buffer>
</match>

# 出力: S3 バックアップ
<match system.**>
  @type s3
  s3_bucket my-log-bucket
  s3_region ap-northeast-1
  path logs/%Y/%m/%d/
  store_as gzip
</match>
```

### Fluentd の主要プラグイン

| プラグイン | 種別 | 用途 |
|-----------|------|------|
| in_tail | source | ファイルのテール読み込み |
| in_syslog | source | syslog 受信 |
| in_http | source | HTTP 経由でログ受信 |
| filter_grep | filter | パターンマッチフィルタ |
| filter_record_transformer | filter | フィールド追加・変換 |
| out_elasticsearch | match | Elasticsearch への出力 |
| out_s3 | match | S3 への出力 |
| out_kafka | match | Kafka への出力 |
| out_copy | match | 複数出力先への並行送信 |

## Logstash 詳細設定

### パイプライン構成

```
input（受信）→ filter（変換）→ output（送信）
```

### 設定例（/etc/logstash/conf.d/app.conf）

```
# ===== INPUT =====
input {
  file {
    path => "/var/log/app/*.log"
    start_position => "beginning"
    codec => "json"
  }
  syslog {
    port => 5044
    type => "syslog"
  }
}

# ===== FILTER =====
filter {
  # grok でテキストログをパース
  if [type] == "nginx_access" {
    grok {
      match => {
        "message" => '%{COMBINEDAPACHELOG}'
      }
    }
    # レスポンスコードを整数に変換
    mutate {
      convert => { "response" => "integer" }
    }
  }

  # エラーログの詳細パース
  if [type] == "app_error" {
    grok {
      match => {
        "message" => [
          '\[%{TIMESTAMP_ISO8601:timestamp}\] %{LOGLEVEL:level} %{GREEDYDATA:error_msg}'
        ]
      }
    }
  }

  # タイムスタンプの正規化
  date {
    match => [ "timestamp", "ISO8601" ]
    target => "@timestamp"
  }

  # 不要フィールドの削除
  mutate {
    remove_field => ["host", "path"]
  }
}

# ===== OUTPUT =====
output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "app-logs-%{+YYYY.MM.dd}"
  }
  # デバッグ用: 標準出力にも出力
  stdout {
    codec => rubydebug
  }
}
```

### 主要 grok パターン

```bash
# Nginx アクセスログのパース
%{IPORHOST:clientip} %{USER:ident} %{USER:auth} \[%{HTTPDATE:timestamp}\] "%{WORD:method} %{URIPATHPARAM:request} HTTP/%{NUMBER:httpversion}" %{NUMBER:response} (?:%{NUMBER:bytes}|-)

# Apache Combined Log
%{COMBINEDAPACHELOG}

# カスタムアプリログ
\[%{TIMESTAMP_ISO8601:ts}\] %{LOGLEVEL:level} \[%{DATA:service}\] %{GREEDYDATA:msg}
```

## logrotate 詳細設定

```bash
# /etc/logrotate.d/myapp
/var/log/myapp/*.log {
    daily               # 毎日
    weekly              # 毎週（dailyより優先度低い場合に使用）
    rotate 30           # 30世代保持（daysold と組み合わせ可）
    size 100M           # 100MB を超えたらローテーション（daily と組み合わせ可）
    compress            # gzip 圧縮
    delaycompress       # 直前世代はすぐに圧縮しない（書き込み中のファイル対策）
    missingok           # ファイルが存在しなくてもエラーにしない
    notifempty          # 空ファイルはスキップ
    create 640 app app  # 新ファイルのパーミッション・オーナー
    dateext             # ファイル名に日付を付与（app.log-2025-07-10.gz）
    postrotate
        # nginx にシグナルを送り新しいログファイルを開かせる
        /bin/kill -HUP $(cat /run/nginx.pid 2>/dev/null) 2>/dev/null || true
    endscript
}
```

```bash
# 動作確認（ドライラン）
sudo logrotate -d /etc/logrotate.d/myapp

# 強制実行
sudo logrotate -f /etc/logrotate.d/myapp
```

## ログ保存・圧縮

### 圧縮方式の比較

| 方式 | 特徴 | 用途 |
|------|------|------|
| gzip (.gz) | バランス型。速度と圧縮率が両立 | 汎用 |
| bzip2 (.bz2) | 高圧縮率だが低速 | 長期保存 |
| xz | 最高圧縮率だが最低速 | アーカイブ保存 |
| zstd | 高速かつ高圧縮率（近年注目） | ストリーム処理 |

```bash
# 手動圧縮・解凍
gzip app.log          # → app.log.gz
gzip -d app.log.gz   # 解凍
zcat app.log.gz | grep "ERROR"  # 解凍せず検索
```

### 3-2-1 バックアップ実装例

```bash
#!/bin/bash
# 3-2-1 ルール実装: ローカル + リモートサーバー + S3
LOG_DIR="/var/log/myapp"
DATE=$(date +%Y%m%d)

# ローカルバックアップ（コピー1）
cp -r "$LOG_DIR" "/backup/logs/$DATE"

# リモートサーバー（コピー2: 別メディア）
rsync -az "$LOG_DIR/" "backup-server:/logs/$DATE/"

# クラウド（コピー3: オフサイト）
aws s3 sync "$LOG_DIR" "s3://my-log-bucket/logs/$DATE/" --storage-class STANDARD_IA
```

## 改ざん防止

### ハッシュ検証

```bash
# ログ作成時にハッシュ値を記録
sha256sum /var/log/app/app.log > /secure/app.log.sha256

# 定期検証（cron で毎時実行）
sha256sum -c /secure/app.log.sha256
# app.log: OK       → 改ざんなし
# app.log: FAILED   → 改ざん検知 → アラート発報

# 複数ファイルの一括チェック
find /var/log/app -name "*.log" -exec sha256sum {} \; > /secure/all.sha256
sha256sum -c /secure/all.sha256 2>&1 | grep -v "OK"
```

### タイムスタンプ認証（TSA）

信頼できる第三者機関（Timestamp Authority）がハッシュ値に時刻を認証スタンプ。法的証拠として有効。

```bash
# OpenSSL での TSA リクエスト
openssl ts -query -data app.log -no_nonce -sha256 -out app.log.tsq

# TSA サーバーに送信
curl -H "Content-Type: application/timestamp-query" \
     --data-binary @app.log.tsq \
     https://tsa.example.com/tsa > app.log.tsr

# 検証
openssl ts -verify -data app.log -in app.log.tsr -CAfile ca.crt
```

### NIST SP 800-92 ガイドライン準拠のポイント

```
1. ログの完全性: ハッシュ・デジタル署名による改ざん検知
2. ログの機密性: 機密情報の暗号化・アクセス制御
3. ログの可用性: バックアップ・冗長化
4. 時刻同期: NTP による正確なタイムスタンプ
5. ログの保管: 規制要件に応じた保管期間と安全な廃棄
```

```bash
# NTP 同期状態の確認
timedatectl status
chronyc tracking  # chrony 使用時

# NTP サーバーの設定
# /etc/chrony.conf
server ntp.nict.jp iburst  # 日本標準時サーバー
```
