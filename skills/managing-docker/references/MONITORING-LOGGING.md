# Docker監視とログ管理リファレンス

## 監視すべき主要メトリクス

| メトリクス | 監視目的 |
|-----------|---------|
| **CPU使用率** | 過負荷・バグによる過剰計算の検出 |
| **メモリ使用量** | メモリリーク・リソース不足の検出 |
| **ネットワークI/O** | ボトルネック・セキュリティ問題の検出 |
| **ディスクI/O** | 頻繁な読み書き操作のパフォーマンス最適化 |
| **コンテナヘルス** | 稼働時間・再起動回数・終了コード |
| **アプリケーション固有** | リクエストレイテンシ・エラー率・キュー長 |

---

## Docker標準監視コマンド

### docker stats

リアルタイムでコンテナのリソース使用状況をストリーム表示:

```bash
$ docker stats

CONTAINER ID   NAME    CPU %   MEM USAGE / LIMIT   MEM %   NET I/O       BLOCK I/O   PIDS
7c2a6b57f67e   nginx   0.00%   1.148MiB / 7.772GiB 0.01%   656B / 656B   0B / 0B     2
9d3e4f8f0bcd   redis   0.07%   7.164MiB / 7.772GiB 0.09%   656B / 656B   0B / 0B     4
```

特定コンテナのみ監視:

```bash
$ docker stats nginx redis
```

フォーマット指定:

```bash
$ docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### docker events

Dockerデーモンからリアルタイムイベントストリームを取得:

```bash
# すべてのイベントをリアルタイム監視
$ docker events

# 特定イベントタイプのみフィルタ
$ docker events --filter 'event=start'
$ docker events --filter 'type=container'

# 特定期間のイベント取得
$ docker events --since '2023-01-01T00:00:00' --until '2023-01-02T00:00:00'
```

### docker inspect

コンテナの詳細情報をJSON形式で取得:

```bash
$ docker inspect <container_id>
```

特定フィールドのみ抽出:

```bash
# コンテナの状態のみ取得
$ docker inspect -f '{{.State.Status}}' <container_id>

# IPアドレス取得
$ docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container_id>

# 環境変数取得
$ docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' <container_id>
```

---

## Dockerログドライバー

### ログドライバー一覧

| ドライバー | 送信先 | 用途 |
|-----------|-------|------|
| **json-file** | ローカルJSONファイル | デフォルト・開発環境 |
| **syslog** | syslogデーモン | UNIX系システムログ統合 |
| **journald** | systemd journal | systemd環境 |
| **gelf** | Graylog | GELF対応ログ管理システム |
| **fluentd** | Fluentd | 柔軟なログ転送 |
| **awslogs** | AWS CloudWatch Logs | AWS環境 |
| **splunk** | Splunk HTTP Event Collector | エンタープライズログ分析 |

### ログドライバー設定

#### コンテナ起動時に指定

```bash
$ docker run --log-driver=syslog nginx
```

#### デーモン設定でデフォルト変更

`/etc/docker/daemon.json`:

```json
{
  "log-driver": "syslog",
  "log-opts": {
    "syslog-address": "udp://1.2.3.4:1111"
  }
}
```

#### json-fileドライバーのログローテーション

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

docker-compose.yml:

```yaml
services:
  web:
    image: nginx
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

---

## ログ閲覧コマンド

### docker logs

```bash
# 基本
$ docker logs <container_id>

# 最新100行のみ表示
$ docker logs --tail 100 <container_id>

# リアルタイム追跡（tail -f相当）
$ docker logs --follow <container_id>

# タイムスタンプ付き
$ docker logs --timestamps <container_id>

# 特定時刻以降のログ
$ docker logs --since '2023-06-15T10:30:00' <container_id>

# 組み合わせ
$ docker logs --tail 100 --follow --timestamps <container_id>
```

---

## Prometheus監視

### 基本構成

#### prometheus.yml設定

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'docker'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'mysql'
    static_configs:
      - targets: ['mysqld-exporter:9104']
```

#### Prometheusコンテナ起動

```bash
$ docker run -d \
  --name prometheus \
  -p 9090:9090 \
  -v /path/to/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus
```

### cAdvisor統合（コンテナメトリクス収集）

```bash
$ docker run \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --volume=/dev/disk/:/dev/disk:ro \
  --publish=8080:8080 \
  --detach=true \
  --name=cadvisor \
  google/cadvisor:latest
```

### PostgreSQL Exporter

```bash
$ docker run -d \
  --name postgres-exporter \
  -e DATA_SOURCE_NAME="postgresql://user:password@postgres:5432/dbname?sslmode=disable" \
  -p 9187:9187 \
  prometheuscommunity/postgres-exporter
```

### MySQL Exporter

```bash
$ docker run -d \
  --name mysqld-exporter \
  -e DATA_SOURCE_NAME="user:password@(mysql:3306)/dbname" \
  -p 9104:9104 \
  prom/mysqld-exporter
```

---

## Grafana可視化

### Grafanaコンテナ起動

```bash
$ docker run -d \
  --name grafana \
  -p 3000:3000 \
  grafana/grafana
```

### データソース追加（Prometheus）

1. Grafana UI（http://localhost:3000）にアクセス
2. Configuration → Data Sources → Add data source
3. Prometheusを選択
4. URL: `http://prometheus:9090`（同一Dockerネットワーク内の場合）
5. Save & Test

### Docker監視用ダッシュボード

Grafana公式ダッシュボードをインポート:

- **Dashboard ID 893**: Docker Dashboard
- **Dashboard ID 179**: Docker Prometheus Monitoring
- **Dashboard ID 395**: Docker containers monitoring

インポート手順:
1. + → Import → Dashboard IDを入力
2. データソースにPrometheusを選択
3. Import

---

## ELKスタック

### docker-compose.yml構成

```yaml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.10.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:8.10.0
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    ports:
      - "5000:5000"
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.10.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch

volumes:
  elasticsearch-data:
    driver: local
```

### Logstash設定

#### logstash.conf（基本）

```conf
input {
  # Dockerログをstdinから受信
  stdin { }
}

filter {
  # JSON形式でパース
  json {
    source => "message"
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "docker-logs-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
```

#### PostgreSQLログ収集

```conf
input {
  file {
    path => "/var/lib/postgresql/data/pg_log/*.log"
    type => "postgres"
    start_position => "beginning"
  }
}

filter {
  if [type] == "postgres" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{WORD:log_level}: %{GREEDYDATA:message}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "postgres-logs-%{+YYYY.MM.dd}"
  }
}
```

#### Nginxアクセスログ収集

```conf
input {
  file {
    path => "/var/log/nginx/access.log"
    type => "nginx-access"
    start_position => "beginning"
  }
}

filter {
  if [type] == "nginx-access" {
    grok {
      match => { "message" => "%{COMBINEDAPACHELOG}" }
    }
    date {
      match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "nginx-access-%{+YYYY.MM.dd}"
  }
}
```

---

## Fluentd統合

### fluent.conf設定

```conf
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<match *.*>
  @type file
  path /fluentd/log/docker.*.log
  append true
  <buffer>
    timekey 1d
    timekey_wait 10m
    timekey_use_utc true
  </buffer>
</match>
```

Elasticsearch出力:

```conf
<match docker.**>
  @type elasticsearch
  host elasticsearch
  port 9200
  logstash_format true
  logstash_prefix docker
  <buffer>
    flush_interval 10s
  </buffer>
</match>
```

### Fluentdコンテナ起動

```bash
$ docker run -d \
  --name fluentd \
  -p 24224:24224 \
  -v /path/to/fluent.conf:/fluentd/etc/fluent.conf \
  -v /path/to/log:/fluentd/log \
  fluent/fluentd:v1.16-1
```

### アプリケーションコンテナ側設定

```bash
$ docker run \
  --log-driver=fluentd \
  --log-opt fluentd-address=localhost:24224 \
  --log-opt tag="docker.{{.Name}}" \
  nginx
```

docker-compose.yml:

```yaml
services:
  web:
    image: nginx
    logging:
      driver: "fluentd"
      options:
        fluentd-address: "localhost:24224"
        tag: "docker.nginx"
```

---

## 統合監視スタック（Prometheus + Grafana + ELK）

### docker-compose.yml

```yaml
version: '3.8'

services:
  # === 監視 ===
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
    networks:
      - monitoring

  # === ログ管理 ===
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.10.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
    networks:
      - monitoring

  logstash:
    image: docker.elastic.co/logstash/logstash:8.10.0
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    ports:
      - "5000:5000"
    depends_on:
      - elasticsearch
    networks:
      - monitoring

  kibana:
    image: docker.elastic.co/kibana/kibana:8.10.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - monitoring

  # === DB監視 ===
  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    environment:
      - DATA_SOURCE_NAME=postgresql://user:password@postgres:5432/dbname?sslmode=disable
    ports:
      - "9187:9187"
    networks:
      - monitoring

volumes:
  prometheus-data:
  grafana-data:
  elasticsearch-data:

networks:
  monitoring:
    driver: bridge
```

---

## ヘルスチェック監視

### Dockerfileでヘルスチェック定義

```dockerfile
FROM nginx

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1
```

### docker-compose.ymlでヘルスチェック定義

```yaml
services:
  web:
    image: nginx
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 3s
      start_period: 5s
      retries: 3

  db:
    image: postgres
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### ヘルスチェック状態確認

```bash
# コンテナのヘルス状態確認
$ docker ps
CONTAINER ID   IMAGE     STATUS                    PORTS
abc123         nginx     Up 2 minutes (healthy)    80/tcp

# 詳細確認
$ docker inspect --format='{{json .State.Health}}' <container_id> | jq
```

---

## アラート設定（Alertmanager）

### alertmanager.yml

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'slack-notifications'

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        title: 'Docker Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ end }}'
```

### Prometheusアラートルール

```yaml
groups:
  - name: docker_alerts
    interval: 10s
    rules:
      - alert: ContainerDown
        expr: up{job="docker"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.instance }} is down"

      - alert: HighMemoryUsage
        expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} memory usage > 90%"

      - alert: HighCpuUsage
        expr: rate(container_cpu_usage_seconds_total[5m]) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} CPU usage > 80%"
```

---

## ベストプラクティス

### ログ管理

| 項目 | 推奨事項 |
|-----|---------|
| **ログローテーション** | max-size/max-fileで自動ローテーション設定 |
| **構造化ログ** | JSON形式でログ出力（検索・集約が容易） |
| **ログレベル** | 環境変数で制御可能にする（開発/本番で切替） |
| **機密情報** | ログに認証情報・個人情報を出力しない |
| **stdout/stderr** | アプリケーションログはstdout/stderrに出力 |

### 監視設定

| 項目 | 推奨事項 |
|-----|---------|
| **メトリクス保持期間** | Prometheusで15日〜1ヶ月を標準設定 |
| **スクレイプ間隔** | 10〜30秒（負荷とのバランス） |
| **アラート閾値** | 段階的アラート（warning/critical） |
| **ラベル/タグ** | 環境・サービス・バージョンでタグ付け |

### セキュリティ

| 項目 | 推奨事項 |
|-----|---------|
| **アクセス制御** | Grafana/Kibanaに認証設定 |
| **ネットワーク分離** | 監視スタックを専用ネットワークに配置 |
| **ログの暗号化** | 転送時TLS、保存時暗号化 |
